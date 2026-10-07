"""ShopDeck onboarding digest bot.

Modes:
  python -m shopdeck_bot.app           # long-running: Socket Mode + daily scheduled post + /digest command
  python -m shopdeck_bot.app --once    # post one digest and exit (for cron / Cloud Scheduler)
"""
import argparse
import logging

from slack_sdk import WebClient

from .config import Config
from .digest import IST, build_blocks, fallback_text, fetch_digest

log = logging.getLogger("shopdeck_bot")


def post_digest(cfg: Config, slack: WebClient, channel: str) -> None:
    from google.cloud import bigquery

    data = fetch_digest(bigquery.Client(project=cfg.gcp_project), cfg.stuck_after_days)
    slack.chat_postMessage(
        channel=channel,
        text=fallback_text(data),
        blocks=build_blocks(data, cfg.stuck_after_days, cfg.stuck_list_limit),
    )
    log.info("Posted digest for %s to %s", data.report_date, channel)


def post_digest_safely(cfg: Config, slack: WebClient, channel: str) -> None:
    """Never let a failed run go silent: report the error in the channel."""
    try:
        post_digest(cfg, slack, channel)
    except Exception as exc:
        log.exception("Digest failed")
        slack.chat_postMessage(channel=channel, text=f":warning: Onboarding digest failed: `{exc}`")


def run_forever(cfg: Config) -> None:
    from apscheduler.schedulers.background import BackgroundScheduler
    from apscheduler.triggers.cron import CronTrigger
    from slack_bolt import App
    from slack_bolt.adapter.socket_mode import SocketModeHandler

    app = App(token=cfg.slack_bot_token)

    @app.command("/digest")
    def on_digest(ack, command, client):
        ack("Running the onboarding digest, give me ~30 seconds…")
        post_digest_safely(cfg, client, command["channel_id"])

    scheduler = BackgroundScheduler(timezone=IST)
    scheduler.add_job(
        post_digest_safely,
        CronTrigger(hour=cfg.digest_hour_ist, minute=cfg.digest_minute_ist, timezone=IST),
        args=[cfg, app.client, cfg.digest_channel],
        misfire_grace_time=3600,
    )
    scheduler.start()
    log.info("Scheduled daily digest at %02d:%02d IST", cfg.digest_hour_ist, cfg.digest_minute_ist)
    SocketModeHandler(app, cfg.slack_app_token).start()


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--once", action="store_true", help="post one digest and exit")
    args = parser.parse_args()

    cfg = Config.from_env(require_app_token=not args.once)
    if args.once:
        post_digest(cfg, WebClient(token=cfg.slack_bot_token), cfg.digest_channel)
    else:
        run_forever(cfg)


if __name__ == "__main__":
    main()
