"""ShopDeck onboarding digest bot: DMs each POC their own stuck sellers.

Modes:
  python -m shopdeck_bot.app                    # long-running: Socket Mode + daily DMs + /digest command
  python -m shopdeck_bot.app --once             # send today's DMs and exit (for cron / Cloud Scheduler)
  python -m shopdeck_bot.app --once --dry-run   # send every would-be DM to DIGEST_ADMIN_ID instead
"""
import argparse
import logging
from datetime import datetime

from slack_sdk import WebClient
from slack_sdk.http_retry.builtin_handlers import RateLimitErrorRetryHandler

from .config import Config
from .delivery import build_admin_report_blocks, deliver_poc_dms
from .digest import IST, build_blocks, build_poc_dm_blocks, fallback_text, fetch_digest, fetch_stuck

log = logging.getLogger("shopdeck_bot")


def _bq(cfg: Config):
    from google.cloud import bigquery

    return bigquery.Client(project=cfg.gcp_project)


def run_digest(cfg: Config, slack: WebClient, dry_run: bool = False) -> None:
    as_of = datetime.now(IST).date()
    bq = _bq(cfg)

    if cfg.digest_channel:
        data = fetch_digest(bq, cfg.stuck_after_days)
        stuck = data.stuck
    else:
        stuck = fetch_stuck(bq, cfg.stuck_after_days)

    report = deliver_poc_dms(slack, stuck, as_of, cfg.stuck_after_days, cfg.stuck_list_limit,
                             cfg.admin_id, dry_run)

    if cfg.digest_channel:
        slack.chat_postMessage(
            channel=cfg.admin_id if dry_run else cfg.digest_channel,
            text=fallback_text(data),
            blocks=build_blocks(data, cfg.stuck_after_days, cfg.stuck_list_limit),
        )

    slack.chat_postMessage(
        channel=cfg.admin_id,
        text=f"Stuck-seller DMs: {len(report.dms_sent)} POCs, {len(report.unrouted)} sellers unrouted",
        blocks=build_admin_report_blocks(report, as_of, cfg.stuck_list_limit),
    )
    log.info("DMs sent=%d unrouted=%d dry_run=%s", len(report.dms_sent), len(report.unrouted), dry_run)


def run_digest_safely(cfg: Config, slack: WebClient, dry_run: bool = False, reraise: bool = False) -> None:
    """Never let a failed run go silent: report the error to the admin.

    reraise=True (for --once) also exits non-zero so the external scheduler sees the failure.
    """
    try:
        run_digest(cfg, slack, dry_run)
    except Exception as exc:
        log.exception("Digest failed")
        slack.chat_postMessage(channel=cfg.admin_id, text=f":warning: Onboarding digest failed: `{exc}`")
        if reraise:
            raise


def my_stuck_blocks(cfg: Config, slack: WebClient, slack_user_id: str) -> list[dict]:
    """/digest: the caller's own stuck list, matched by their Slack email."""
    email = (slack.users_info(user=slack_user_id)["user"]["profile"].get("email") or "").strip().lower()
    if not email:
        return [{"type": "section", "text": {"type": "mrkdwn", "text": "I can't see your Slack email, so I can't match you to a POC."}}]
    mine = [s for s in fetch_stuck(_bq(cfg), cfg.stuck_after_days) if (s.poc_email or "").strip().lower() == email]
    if not mine:
        return [{"type": "section", "text": {"type": "mrkdwn", "text":
                 f":white_check_mark: No stuck sellers routed to {email} (>{cfg.stuck_after_days}d meta→FT)."}}]
    return build_poc_dm_blocks(mine[0].ob_poc, mine, datetime.now(IST).date(),
                               cfg.stuck_after_days, cfg.stuck_list_limit)


def run_forever(cfg: Config) -> None:
    from apscheduler.schedulers.background import BackgroundScheduler
    from apscheduler.triggers.cron import CronTrigger
    from slack_bolt import App
    from slack_bolt.adapter.socket_mode import SocketModeHandler

    app = App(token=cfg.slack_bot_token)
    app.client.retry_handlers.append(RateLimitErrorRetryHandler(max_retry_count=3))

    @app.command("/digest")
    def on_digest(ack, command, client, respond):
        ack("Checking your stuck sellers, give me ~30 seconds…")
        try:
            respond(response_type="ephemeral", text="Your stuck sellers",
                    blocks=my_stuck_blocks(cfg, client, command["user_id"]))
        except Exception as exc:
            log.exception("/digest failed")
            respond(response_type="ephemeral", text=f":warning: Failed: `{exc}`")

    scheduler = BackgroundScheduler(timezone=IST)
    scheduler.add_job(
        run_digest_safely,
        CronTrigger(hour=cfg.digest_hour_ist, minute=cfg.digest_minute_ist, timezone=IST),
        args=[cfg, app.client],
        misfire_grace_time=3600,
    )
    scheduler.start()
    log.info("Scheduled daily DMs at %02d:%02d IST", cfg.digest_hour_ist, cfg.digest_minute_ist)
    SocketModeHandler(app, cfg.slack_app_token).start()


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--once", action="store_true", help="send one round of DMs and exit")
    parser.add_argument("--dry-run", action="store_true", help="with --once: send every DM to DIGEST_ADMIN_ID instead")
    args = parser.parse_args()
    if args.dry_run and not args.once:
        parser.error("--dry-run requires --once")

    cfg = Config.from_env(require_app_token=not args.once)
    if args.once:
        slack = WebClient(token=cfg.slack_bot_token)
        slack.retry_handlers.append(RateLimitErrorRetryHandler(max_retry_count=3))
        run_digest_safely(cfg, slack, dry_run=args.dry_run, reraise=True)
    else:
        run_forever(cfg)


if __name__ == "__main__":
    main()
