# Onboarding Digest — Slack bot

Posts a daily ShopDeck seller-onboarding digest to a Slack channel, straight from BigQuery (`blitzscale-prod-project.nushop`).

**What the digest contains (for yesterday, IST calendar day):**

| Section | Source | Definition |
|---|---|---|
| Launches | `seller_journey_milestones` | Distinct tickets whose `Launch` milestone was completed (by `updated_at`) |
| Task completions | `ob_tasks` | Unique sellers completing each of the 12 funnel tasks |
| Seller lifecycle | `ob_tasks` (`churn_seller_callback`) | Dispositions set yesterday: pause / unpause / revive / drop-out |
| Stuck meta→FT | `ob_tasks`, `ob_tickets`, `users` | meta_setup done in last 30d, no later fund_transfer, > `STUCK_AFTER_DAYS` days; **excludes paused & churned** sellers; grouped by ticket-level OB POC |

If a run fails, the bot posts a ⚠️ message with the error in the channel instead of failing silently.

## 1. Create the Slack app (5 min)

1. Go to <https://api.slack.com/apps> → **Create New App** → **From an app manifest** → paste `manifest.yml`.
2. **Install to Workspace** → copy the **Bot User OAuth Token** (`xoxb-…`) → `SLACK_BOT_TOKEN`.
3. **Basic Information → App-Level Tokens** → generate one with scope `connections:write` (`xapp-…`) → `SLACK_APP_TOKEN`.
4. In Slack, `/invite @onboarding-digest` into the target channel and copy its channel ID → `DIGEST_CHANNEL_ID`.

## 2. BigQuery access

Create a service account with **BigQuery Job User** (on the project) and **BigQuery Data Viewer** (on the `nushop` dataset). Download its key and point `GOOGLE_APPLICATION_CREDENTIALS` at it. Locally, `gcloud auth application-default login` also works.

## 3. Run

```bash
cd slack_bot
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
cp .env.example .env   # fill in values
set -a && . ./.env && set +a

.venv/bin/python -m shopdeck_bot.app --once   # post one digest now (test this first)
.venv/bin/python -m shopdeck_bot.app          # long-running: daily post + /digest command
```

## 4. Deploy — pick one

- **Recommended: `--once` on a scheduler.** Cloud Run Job + Cloud Scheduler (or plain cron) at 09:30 IST. No always-on process, nothing to babysit. `/digest` won't work in this mode (it needs the Socket Mode listener).
- **Long-running.** `docker build -t onboarding-digest . && docker run --env-file .env -v /path/key.json:/key.json -e GOOGLE_APPLICATION_CREDENTIALS=/key.json onboarding-digest` on a VM. Gives you `/digest` too, but if the process dies the daily post silently stops — monitor it.

## Tests

```bash
.venv/bin/pip install -r requirements-dev.txt && .venv/bin/python -m pytest
```

Tests cover message rendering, Slack block limits, and a guard that every partitioned table in the SQL carries a `created_at` filter. They do **not** hit BigQuery: run `--once` against a test channel before relying on the numbers.

## Known limitations

- Sellers whose meta_setup completed > 30 days ago drop out of the stuck list (keeps the list actionable, but hides the oldest cases).
- The stuck rule (> 7d meta→FT) does not split pre/post Jul-8 ticket era; at > 7 days both eras are past the 48hr window, so it's treated as stuck either way.
- Daily counts swing 20–30% naturally — read trends over weeks, not single days.
- BigQuery may lag production; "yesterday" numbers can shift slightly if read very early.
