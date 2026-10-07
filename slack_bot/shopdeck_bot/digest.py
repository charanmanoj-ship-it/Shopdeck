"""Fetch digest data from BigQuery and render it as Slack Block Kit."""
from collections import Counter
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from . import queries

IST = ZoneInfo("Asia/Kolkata")


@dataclass
class StuckSeller:
    seller_id: str
    meta_completed_ist: datetime
    days_since_meta: int
    ob_poc: str


@dataclass
class DigestData:
    report_date: date  # the IST day being summarised (yesterday)
    launches: int
    completions: dict[str, int]  # task_type -> unique sellers
    lifecycle: dict[str, int]  # paused / unpaused / revived / churned
    stuck: list[StuckSeller] = field(default_factory=list)


def fetch_digest(bq_client, stuck_after_days: int) -> DigestData:
    """Run all digest queries. bq_client is a google.cloud.bigquery.Client."""
    from google.cloud import bigquery

    def run(sql, params=()):
        job_config = bigquery.QueryJobConfig(query_parameters=list(params))
        return list(bq_client.query(sql, job_config=job_config).result())

    completions = {
        r["task_type"]: r["sellers"]
        for r in run(queries.TASK_COMPLETIONS,
                     [bigquery.ArrayQueryParameter("task_types", "STRING", queries.TASK_TYPES)])
    }
    launches = run(queries.LAUNCHES)[0]["launches"]
    lc = run(queries.LIFECYCLE_EVENTS)[0]
    stuck = [
        StuckSeller(r["seller_id"], r["meta_completed_ist"], r["days_since_meta"], r["ob_poc"])
        for r in run(queries.STUCK_META_TO_FT,
                     [bigquery.ScalarQueryParameter("stuck_after_days", "INT64", stuck_after_days)])
    ]
    return DigestData(
        report_date=datetime.now(IST).date() - timedelta(days=1),
        launches=launches,
        completions=completions,
        lifecycle={k: lc[k] or 0 for k in ("paused", "unpaused", "revived", "churned")},
        stuck=stuck,
    )


def build_blocks(data: DigestData, stuck_after_days: int, stuck_list_limit: int) -> list[dict]:
    """Render DigestData as Slack blocks. Pure function: no I/O."""
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
        lines = [
            f"`{s.seller_id}` — {s.days_since_meta}d since meta ({s.meta_completed_ist:%d %b}) — {s.ob_poc}"
            for s in data.stuck[:stuck_list_limit]
        ]
        more = len(data.stuck) - stuck_list_limit
        if more > 0:
            lines.append(f"_…and {more} more_")
        blocks.append({"type": "section", "text": {"type": "mrkdwn",
                       "text": f"*Stuck by OB POC:* {poc_line}"}})
        blocks.append({"type": "section", "text": {"type": "mrkdwn",
                       "text": "*Oldest first*\n" + "\n".join(lines)}})

    blocks.append({"type": "context", "elements": [{"type": "mrkdwn", "text":
        "Stuck = meta_setup done in last 30d, no later fund_transfer, excludes paused & churned sellers. "
        "Counts are IST calendar day; BigQuery may lag production."}]})
    return blocks


def fallback_text(data: DigestData) -> str:
    """Plain-text summary for notifications and clients that can't render blocks."""
    return (f"Onboarding digest {data.report_date:%d %b}: {data.launches} launches, "
            f"{len(data.stuck)} sellers stuck meta→FT")
