# Onboarding Digest: Slack bot

Every morning, DMs each ShopDeck onboarding POC **only their own** sellers stuck between `meta_setup` and `fund_transfer`, straight from BigQuery (`blitzscale-prod-project.nushop`).

## Who gets what

| Recipient | Message | When |
|---|---|---|
| Each POC with ≥1 stuck seller | Their stuck sellers, oldest first | Daily (POCs with zero get nothing) |
| `DIGEST_ADMIN_ID` (required) | Delivery report: POCs messaged, emails not found in Slack, send failures, and **every seller that reached no POC** | Daily, even when all is well. If it's missing, the bot is down. |
| `DIGEST_CHANNEL_ID` (optional) | Team summary: launches, task completions, lifecycle events, stuck counts by POC | Daily, only if set |
| Anyone running `/digest` | Their own stuck list, visible only to them | On demand |

**Stuck** = meta_setup completed in the last 30 days, no fund_transfer completed after it, more than `STUCK_AFTER_DAYS` (7) days since meta. **Paused and churned sellers are excluded.**

**Routing:** each seller goes to the `assigned_poc` on their open fund_transfer task. If there's no open FT task, it falls back to the `ob_poc` on their latest ticket. The ticket-level POC can be stale after reassignment, so the task assignee comes first. The POC's `nushop.users.email` is matched to a Slack account via `users.lookupByEmail`, so **Slack emails must match the emails in `nushop.users`**.

## 1. Create the Slack app (5 min)

1. <https://api.slack.com/apps> → **Create New App** → **From an app manifest** → paste `manifest.yml`.
2. **Install to Workspace** → copy the **Bot User OAuth Token** (`xoxb-…`) → `SLACK_BOT_TOKEN`.
3. **Basic Information → App-Level Tokens** → generate one with scope `connections:write` (`xapp-…`) → `SLACK_APP_TOKEN` (only needed for the long-running mode / `/digest`).
4. Set `DIGEST_ADMIN_ID` to your own Slack user ID (profile → ⋮ → Copy member ID).

If you change scopes later, reinstall the app or the new scopes won't apply.

## 2. BigQuery access

Service account with **BigQuery Job User** (project) + **BigQuery Data Viewer** (`nushop` dataset). Point `GOOGLE_APPLICATION_CREDENTIALS` at its key. Locally, `gcloud auth application-default login` also works.

## 3. Roll out safely

```bash
cd slack_bot
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
cp .env.example .env   # fill in values
set -a && . ./.env && set +a

.venv/bin/python -m shopdeck_bot.app --once --dry-run   # 1. every would-be DM comes to YOU, nothing to POCs
.venv/bin/python -m shopdeck_bot.app --once             # 2. real DMs, once
.venv/bin/python -m shopdeck_bot.app                    # 3. long-running: daily DMs + /digest
```

Do step 1 first and check: are the right sellers going to the right POCs? Are any POCs "not found in Slack"? How many sellers are unrouted?

## 4. Deploy (pick one)

- **Recommended: `--once` on a scheduler.** Cloud Run Job + Cloud Scheduler (or cron) at 09:30 IST. Exits non-zero on failure, so the scheduler sees it. `/digest` needs the long-running mode.
- **Long-running.** `docker build -t onboarding-digest . && docker run --env-file .env -v /path/key.json:/key.json -e GOOGLE_APPLICATION_CREDENTIALS=/key.json onboarding-digest`. Adds `/digest`. If the process dies, the daily admin report stops arriving. That's your alarm.

## Tests

```bash
.venv/bin/pip install -r requirements-dev.txt && .venv/bin/python -m pytest
```

Tests cover per-POC routing (each POC sees only their sellers), that no stuck seller is ever silently dropped, dry-run isolation, Slack error handling, message rendering, and that every partitioned table in the SQL has a `created_at` filter. They do **not** hit BigQuery or Slack.

## Known limitations

- Sellers with meta_setup > 30 days ago drop out of the stuck list.
- The stuck rule doesn't split pre/post Jul-8 ticket era; at > 7 days both eras are past the 48hr FT window.
- "Open FT task" = `status NOT IN ('completed','cancelled')`. If the CRM uses other closed statuses, routing may pick a stale assignee.
- Daily DMs with the same long list can become noise. Watch whether lists actually shrink week over week.
