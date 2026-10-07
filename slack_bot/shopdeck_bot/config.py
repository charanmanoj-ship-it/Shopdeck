"""Runtime configuration, read once from environment variables."""
import os
from dataclasses import dataclass


def _required(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


@dataclass(frozen=True)
class Config:
    slack_bot_token: str
    slack_app_token: str
    digest_channel: str
    gcp_project: str
    digest_hour_ist: int
    digest_minute_ist: int
    stuck_after_days: int
    stuck_list_limit: int

    @classmethod
    def from_env(cls, require_app_token: bool = True) -> "Config":
        return cls(
            slack_bot_token=_required("SLACK_BOT_TOKEN"),
            slack_app_token=_required("SLACK_APP_TOKEN") if require_app_token else os.environ.get("SLACK_APP_TOKEN", ""),
            digest_channel=_required("DIGEST_CHANNEL_ID"),
            gcp_project=os.environ.get("GCP_PROJECT", "blitzscale-prod-project"),
            digest_hour_ist=int(os.environ.get("DIGEST_HOUR_IST", "9")),
            digest_minute_ist=int(os.environ.get("DIGEST_MINUTE_IST", "30")),
            stuck_after_days=int(os.environ.get("STUCK_AFTER_DAYS", "7")),
            stuck_list_limit=int(os.environ.get("STUCK_LIST_LIMIT", "15")),
        )
