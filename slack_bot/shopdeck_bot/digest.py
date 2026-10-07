"""Fetch digest data from BigQuery and render it as Slack Block Kit."""
from collections import Counter
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from . import queries

IST = ZoneInfo("Asia/Kolkata")

STUCK_FOOTNOTE = ("Stuck = meta_setup done in last 30d, no later fund_transfer, excludes paused & churned sellers. "
                  "BigQuery may lag production.")


@dataclass
class StuckSeller:
    seller_id: str
    meta_completed_ist: datetime
    days_since_meta: int
    ob_poc: str  # POC first name, or "(unassigned)"
    poc_email: str | None = None
    poc_source: str = "ticket"  # "ft_task" (open fund_transfer assignee) or "ticket" (ticket ob_poc)


@dataclass
class DigestData:
    report_date: date  # the IST day being summarised (yesterday)
    launches: int
    completions: dict[str, int]  # task_type -> unique sellers
    lifecycle: dict[str, int]  # paused / unpaused / revived / churned
    stuck: list[StuckSeller] = field(default_factory=list)


def _run(bq_client, sql, params=()):
    from google.cloud import bigquery

    job_config = bigquery.QueryJobConfig(query_parameters=list(params))
    return list(bq_client.query(sql, job_config=job_config).result())


def fetch_stuck(bq_client, stuck_after_days: int) -> list[StuckSeller]:
    from google.cloud import bigquery

    rows = _run(bq_client, queries.STUCK_META_TO_FT,
                [bigquery.ScalarQueryParameter("stuck_after_days", "INT64", stuck_after_days)])
    return [StuckSeller(r["seller_id"], r["meta_completed_ist"], r["days_since_meta"],
                        r["ob_poc"], r["poc_email"], r["poc_source"]) for r in rows]


def fetch_digest(bq_client, stuck_after_days: int) -> DigestData:
    """Run all digest queries. bq_client is a google.cloud.bigquery.Client."""
    from google.cloud import bigquery

    completions = {
        r["task_type"]: r["sellers"]
        for r in _run(bq_client, queries.TASK_COMPLETIONS,
                      [bigquery.ArrayQueryParameter("task_types", "STRING", queries.TASK_TYPES)])
    }
    launches = _run(bq_client, queries.LAUNCHES)[0]["launches"]
    lc = _run(bq_client, queries.LIFECYCLE_EVENTS)[0]
    return DigestData(
        report_date=datetime.now(IST).date() - timedelta(days=1),
        launches=launches,
        completions=completions,
        lifecycle={k: lc[k] or 0 for k in ("paused", "unpaused", "revived", "churned")},
        stuck=fetch_stuck(bq_client, stuck_after_days),
    )


def group_by_email(stuck: list[StuckSeller]) -> tuple[dict[str, list[StuckSeller]], list[StuckSeller]]:
    """Split stuck sellers into {poc_email: sellers} and a list with no routable POC."""
    by_email: dict[str, list[StuckSeller]] = {}
    no_email: list[StuckSeller] = []
    for s in stuck:
        if s.poc_email:
            by_email.setdefault(s.poc_email.strip().lower(), []).append(s)
        else:
            no_email.append(s)
    return by_email, no_email


def _seller_lines(sellers: list[StuckSeller], limit: int, show_poc: bool) -> list[str]:
    lines = []
    for s in sellers[:limit]:
        line = f"`{s.seller_id}` — {s.days_since_meta}d since meta ({s.meta_completed_ist:%d %b})"
        lines.append(f"{line} — {s.ob_poc}" if show_poc else line)
    if len(sellers) > limit:
        lines.append(f"_…and {len(sellers) - limit} more_")
    return lines


def build_poc_dm_blocks(poc_name: str, sellers: list[StuckSeller], as_of: date,
                        stuck_after_days: int, limit: int) -> list[dict]:
    """The DM one POC receives: only their own stuck sellers, oldest first."""
    sellers = sorted(sellers, key=lambda s: -s.days_since_meta)
    return [
        {"type": "section", "text": {"type": "mrkdwn", "text":
            f"Hi {poc_name} — *{len(sellers)} of your sellers* finished meta_setup "
            f"over {stuck_after_days} days ago and haven't completed fund_transfer "
            f"(as of {as_of:%d %b}, IST)."}},
        {"type": "section", "text": {"type": "mrkdwn", "text": "\n".join(_seller_lines(sellers, limit, False))}},
        {"type": "context", "elements": [{"type": "mrkdwn", "text": STUCK_FOOTNOTE}]},
    ]


def build_blocks(data: DigestData, stuck_after_days: int, stuck_list_limit: int) -> list[dict]:
    """Team-wide summary (optional channel post). Pure function: no I/O."""
    day = data.report_date.strftime("%a %d %b %Y")
    blocks: list[dict] = [
        {"type": "header", "text": {"type": "plain_text", "text": f"Onboarding digest — {day} (IST)"}},
        {"type": "section", "fields": [
            {"type": "mrkdwn", "text": f"*Launches*\n{data.launches}"},
            {"type": "mrkdwn", "text": f"*Stuck meta→FT (>{stuck_after_days}d)*\n{len(data.stuck)}"},
        ]},
    ]

    width = max(len(t) for t in queries.TASK_TYPES)
    rows = [f"{t.ljust(width)}  {data.completions.get(t, 0):>4}" for t in queries.TASK_TYPES]
    blocks.append({"type": "section", "text": {"type": "mrkdwn",
                   "text": "*Task completions (unique sellers)*\n```" + "\n".join(rows) + "```"}})

    lc = data.lifecycle
    blocks.append({"type": "section", "text": {"type": "mrkdwn", "text":
        f"*Seller lifecycle*  paused: {lc['paused']} · unpaused: {lc['unpaused']} · "
        f"revived: {lc['revived']} · churned (drop-out): {lc['churned']}"}})

    blocks.append({"type": "divider"})
    if not data.stuck:
        blocks.append({"type": "section", "text": {"type": "mrkdwn",
                       "text": f":white_check_mark: No sellers stuck between meta_setup and fund_transfer for >{stuck_after_days} days."}})
    else:
        by_poc = Counter(s.ob_poc for s in data.stuck).most_common()
        poc_line = " · ".join(f"{poc}: {n}" for poc, n in by_poc)
        blocks.append({"type": "section", "text": {"type": "mrkdwn",
                       "text": f"*Stuck by POC:* {poc_line}"}})
        blocks.append({"type": "section", "text": {"type": "mrkdwn",
                       "text": "*Oldest first*\n" + "\n".join(_seller_lines(data.stuck, stuck_list_limit, True))}})

    blocks.append({"type": "context", "elements": [{"type": "mrkdwn", "text":
        STUCK_FOOTNOTE + " Counts are IST calendar day."}]})
    return blocks


def fallback_text(data: DigestData) -> str:
    """Plain-text summary for notifications and clients that can't render blocks."""
    return (f"Onboarding digest {data.report_date:%d %b}: {data.launches} launches, "
            f"{len(data.stuck)} sellers stuck meta→FT")
