"""Per-POC DM delivery, plus the admin report that makes failures visible."""
from dataclasses import dataclass, field
from datetime import date

from slack_sdk.errors import SlackApiError

from .digest import StuckSeller, _seller_lines, build_poc_dm_blocks, group_by_email


@dataclass
class DeliveryReport:
    dry_run: bool
    dms_sent: list[tuple[str, int]] = field(default_factory=list)  # (poc name, seller count)
    not_in_slack: list[tuple[str, str, int]] = field(default_factory=list)  # (name, email, count)
    send_failed: list[tuple[str, str, int]] = field(default_factory=list)  # (name, slack error, count)
    unrouted: list[StuckSeller] = field(default_factory=list)  # sellers no POC received

    @property
    def sellers_delivered(self) -> int:
        return sum(n for _, n in self.dms_sent)


def _error_code(exc: SlackApiError) -> str:
    return exc.response.get("error", str(exc)) if exc.response is not None else str(exc)


def deliver_poc_dms(slack, stuck: list[StuckSeller], as_of: date, stuck_after_days: int,
                    limit: int, admin_id: str, dry_run: bool) -> DeliveryReport:
    """DM each POC their own stuck sellers. POCs with none get no message.

    dry_run: still resolves every POC in Slack (so mapping problems surface), but
    sends each would-be DM to admin_id instead of the POC.
    """
    by_email, no_email = group_by_email(stuck)
    report = DeliveryReport(dry_run=dry_run, unrouted=list(no_email))

    for email, sellers in sorted(by_email.items()):
        name = sellers[0].ob_poc
        try:
            user_id = slack.users_lookupByEmail(email=email)["user"]["id"]
        except SlackApiError as exc:
            if _error_code(exc) == "users_not_found":
                report.not_in_slack.append((name, email, len(sellers)))
            else:
                report.send_failed.append((name, _error_code(exc), len(sellers)))
            report.unrouted.extend(sellers)
            continue

        blocks = build_poc_dm_blocks(name, sellers, as_of, stuck_after_days, limit)
        text = f"{len(sellers)} of your sellers are stuck between meta_setup and fund_transfer"
        try:
            if dry_run:
                header = {"type": "context", "elements": [{"type": "mrkdwn",
                          "text": f":test_tube: *Dry run* — would DM {name} (<@{user_id}>, {email})"}]}
                slack.chat_postMessage(channel=admin_id, text=f"[dry run] {name}: {text}", blocks=[header, *blocks])
            else:
                dm_channel = slack.conversations_open(users=user_id)["channel"]["id"]
                slack.chat_postMessage(channel=dm_channel, text=text, blocks=blocks)
        except SlackApiError as exc:
            report.send_failed.append((name, _error_code(exc), len(sellers)))
            report.unrouted.extend(sellers)
            continue
        report.dms_sent.append((name, len(sellers)))

    return report


def build_admin_report_blocks(report: DeliveryReport, as_of: date, limit: int) -> list[dict]:
    """Sent every run, even when all is well, so a missing report means the bot is down."""
    mode = " (dry run — nothing sent to POCs)" if report.dry_run else ""
    total = report.sellers_delivered + len(report.unrouted)
    lines = [f"*Stuck-seller DMs for {as_of:%d %b}{mode}*",
             f"{len(report.dms_sent)} POCs messaged · {report.sellers_delivered}/{total} stuck sellers delivered"]
    if report.dms_sent:
        lines.append("Sent: " + " · ".join(f"{n} ({c})" for n, c in report.dms_sent))
    if report.not_in_slack:
        lines.append(":warning: *POC email not found in Slack:* "
                     + " · ".join(f"{n} <{e}> ({c})" for n, e, c in report.not_in_slack))
    if report.send_failed:
        lines.append(":x: *Send failed:* " + " · ".join(f"{n}: `{err}` ({c})" for n, err, c in report.send_failed))

    blocks = [{"type": "section", "text": {"type": "mrkdwn", "text": "\n".join(lines)}}]
    if report.unrouted:
        unrouted = sorted(report.unrouted, key=lambda s: -s.days_since_meta)
        blocks.append({"type": "section", "text": {"type": "mrkdwn", "text":
            f"*{len(unrouted)} sellers reached no POC — need a manual owner:*\n"
            + "\n".join(_seller_lines(unrouted, limit, True))}})
    return blocks
