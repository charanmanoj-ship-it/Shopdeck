---
name: shopdeck-onboarding-analytics
description: Use for ShopDeck seller-onboarding analytics — BigQuery queries, business questions, or Apps Script tooling touching ob_tickets, ob_tasks, seller_journey_milestones, seller_offers, exotel_calls, or the onboarding tasks (cagd, gtg, catalogue_config, poc_intro, web_config, website_discussion, domain_transfer, meta_setup, price_parity_check, fund_transfer, qc_check, seller_consent). Also for POC throughput, funnel conversion, cohort maturity, curve extrapolation, projecting immature cohorts, the 48hr FT policy, and stuck-seller detection. Also for seller lifecycle states — churn, pause, unpause, revive, drop-out — tracked via the churn_seller_callback task and its dispositions (seller_wants_to_pause, seller_resumed, seller_wants_to_continue, seller_wants_to_drop_out). Do NOT trigger for generic BigQuery/Apps Script help unrelated to this domain.
---

# ShopDeck Onboarding Analytics

Everything Claude needs to answer business questions, write BigQuery SQL, or build Google Apps Script tooling for the ShopDeck seller-onboarding funnel — including the schema knowledge, the join rules, and the clarifying questions Claude must ask before writing a query.

---

## What Claude does with this skill

Three modes, chosen by the user's question shape:

1. **Business question** ("what does meta_setup mean?", "who owns fund_transfer?") — answer directly from this skill.
2. **Ad-hoc query** ("how many sellers hit meta last week?") — write BigQuery SQL. Ask clarifying questions FIRST if the request is ambiguous.
3. **Recurring/automated pipeline** ("add a column to the sheet") — extend the Apps Script at `/mnt/user-data/outputs/refresh_and_analytics_v7.gs` (or the latest version). Keep the CTE structure and style.

Before writing any query, walk the clarifying-question checklist below. It exists because most bad numbers come from unstated assumptions.

---

## Business context (read this first)

### What ShopDeck is

ShopDeck is a D2C e-commerce enablement platform based in Bengaluru. It serves small, non-technical, mobile-first Indian SMB sellers (~1,000 onboarded per month). ShopDeck earns commission only on **delivered orders**, so revenue depends on sellers actually launching their store and generating deliveries — every seller who stalls in the onboarding funnel is lost revenue.

### The onboarding funnel

A seller is created → a ticket is opened → the ticket runs through 12 sequential tasks executed by different POC teams → 5 higher-level milestones are marked complete as the seller progresses. When all critical tasks complete, the seller "launches" (goes live).

**Task order** (execution sequence, ~roughly):

| # | Task type | Handled by | What it means |
|---|---|---|---|
| 1 | `cagd` | ob_poc | Collect & get documents from seller (KYC, PAN, GST, bank, etc.) |
| 2 | `gtg` | gtg_poc | Green-To-Go internal check (approver reviews) |
| 3 | `catalogue_config` | cataloging_poc | Set up catalogue structure and product data |
| 4 | `poc_intro` | ob_poc | POC intro call with seller |
| 5 | `web_config` | website_poc | Configure website settings |
| 6 | `website_discussion` | website_poc | Website design discussion with seller |
| 7 | `domain_transfer` | website_poc | Domain registration / transfer (GoDaddy partner) |
| 8 | `meta_setup` | ob_poc | Facebook OAuth + Meta ad-account setup |
| 9 | `price_parity_check` | qc_poc | Verify pricing matches across channels |
| 10 | `fund_transfer` | ob_poc | Seller funds their ad account (unlocks launch) |
| 11 | `qc_check` | qc_poc | Final quality check |
| 12 | `seller_consent` | ob_poc | Final consent to go live |

The full canonical list (used by scripts) is in the `TASK_TYPES` constant:
```
cagd, gtg, catalogue_config, poc_intro, web_config, website_discussion,
domain_transfer, meta_setup, price_parity_check, fund_transfer, qc_check, seller_consent
```

**Milestones** — higher-level stages that group tasks. Stored in `seller_journey_milestones.step_name`:

| Milestone | step_name values in DB | Corresponds roughly to |
|---|---|---|
| `document` | `Document` | cagd complete |
| `catalogue` | `Catalogue`, `Catalogue Creation`, `Catalogue Sharing` (aliases — merge them) | catalogue_config complete |
| `marketing` | `Marketing`, `Marketing & Platform setup` | meta_setup complete |
| `website` | `Website`, `Website Creation` | domain_transfer complete |
| `launch` | `Launch` | Full flow complete |

**Always alias the multi-name milestones** — filtering only on `step_name = 'Catalogue'` misses `Catalogue Creation` and `Catalogue Sharing`.

### POC types (owners of tasks)

| POC field on ticket | Owns tasks |
|---|---|
| `ob_poc` | cagd, poc_intro, meta_setup, fund_transfer, seller_consent |
| `gtg_poc` | gtg |
| `gtg_approver_poc` | (approver role, no direct task ownership) |
| `cataloging_poc` | catalogue_config |
| `website_poc` | web_config, website_discussion, domain_transfer |
| `qc_poc` | price_parity_check, qc_check |
| `creatives_poc` | (creative assets, no direct task in the 12) |

The ticket-level POC fields are user IDs. Resolve to first_name by joining to `nushop.users` on `_id`.

For per-task assignment (who actually did this specific task), use `ob_tasks.assigned_poc` — this can differ from ticket-level POC if the ticket was reassigned mid-flow.

### Key business events with dates

**Jul 1, 2026 — 48hr policy went live on-ground.** POCs told verbally to wait 48 hours between `meta_setup` completion and `fund_transfer` completion. Reason: Meta flags ad accounts that receive funding immediately after setup as suspicious; a 48hr delay reduced flagging in prior experimentation. No CRM enforcement until Jul 8.

**Jul 8, 2026, 7:52 PM IST — CRM enforcement deployed.** The system now auto-creates the `fund_transfer` task 48 hours after `meta_setup` completes. **Applies only to tickets created ON OR AFTER Jul 8 7:52 PM IST** — pre-deploy tickets are grandfathered onto the old workflow (ft task created immediately after meta).

**Consequence:** Any analysis of ft compliance must know which era the ticket belongs to. A pre-deploy ticket showing 0-second ft creation is CORRECT behavior; a post-deploy ticket doing the same is a bug.

### Offer definitions (not in a table — hardcoded)

Six defined offers. Stored in `nushop.seller_offers` with `offer_id`, but the names are NOT joined from any table — they live in the analytics script.

| offer_id | offer_name | trigger | applied_by |
|---|---|---|---|
| `XBneu1fr` | ₹5K Credit + 0% Commission Combo | hits ₹15000 | mark_ops |
| `7mZ2BUrf` | ₹5K Credit After ₹10K Spend | hits ₹10000 | mark_ops |
| `oHG3ohja` | ₹5K Credit After ₹15K Spend | hits ₹15000 | mark_ops |
| `E2LBHeyl` | ₹5K Deposit + ₹5K Marketing | go_live | mark_ops |
| `q_4WEFzQ` | ₹2K Deposit + ₹5K Marketing | go_live | mark_ops |
| `YjCrnYRz` | 0% Commission for First 30 Days | (none) | finance |

Any new offer needs to be added to the `seller_offer_map` CTE in the Apps Script.

### Seller lifecycle states: churn and pause

Sellers can exit or pause the onboarding funnel through a dedicated callback task, `churn_seller_callback`. **This is a CRM flow, not a data thing.** The task is not one of the 12 linear funnel tasks — it's a lifecycle event that can be triggered at any point. Any query filtering to the funnel `TASK_TYPES` list will miss churn/pause events unless it explicitly includes this task type.

**The mental model (read this before writing any lifecycle query):**

1. **Intent detected** (system signal, POC observation, or seller message) → a `churn_seller_callback` task is created, assigned to a POC with an SLA. Seller enters "in churn process" state.
2. **POC calls the seller** within SLA. Marks a disposition on the task. Task closes.
3. **The disposition determines what happens next.** Every task has exactly ONE disposition. There are three categories:

**Terminal (process-ending) dispositions — no new task follows:**

| Disposition value in `ob_tasks.disposition_reasons` | Seller state after | Meaning |
|---|---|---|
| `seller_wants_to_drop_out` | **Churned (terminal, permanent)** | POC confirmed seller wants to leave. |
| `seller_wants_to_resume` / `seller_resumed` | **Active (unpaused)** | Previously-paused seller returned. Terminal for THIS process. |
| `seller_wants_to_continue` | **Active (revived)** | Seller had exit intent but decided to stay. Terminal for THIS process. |

**State-changing (spawns follow-up task) disposition:**

| Disposition | Seller state after | What happens |
|---|---|---|
| `seller_wants_to_pause` | **Paused** | Seller wants to pause temporarily. **A new `churn_seller_callback` task is auto-created** as a follow-up, waiting for a resume disposition. The seller remains paused until that follow-up is disposed with resume/continue (unpaused) or drop_out (churned). |

**Non-terminal (retry) dispositions — spawn a follow-up task in the same process:**

| Disposition (examples) | Seller state after | What happens |
|---|---|---|
| `seller_did_not_pickup`, `line_busy`, `seller_asked_callback`, etc. | **Same as before** (in-churn-process or paused, unchanged) | Contact attempt failed or was deferred. A new task is created for retry, same process. |

**Key rules for identifying a "process":**
- A **new** `churn_seller_callback` task created AFTER a terminal disposition → **new independent process**
- A **new** `churn_seller_callback` task created AFTER a non-terminal or pause disposition → **follow-up in the same process**
- A seller can go through multiple churn processes across their lifetime.

**Worked example — Seller X:**

| Time (IST) | Event | Disposition | Task chain | Seller state |
|---|---|---|---|---|
| Jul 1, 00:00 | task_1 created (first intent) | none yet | task_1 open | in churn process |
| Jul 1, 03:00 | task_1 disposed | `seller_wants_to_pause` | task_2 auto-spawned as pause follow-up | **paused** (pause_at = 03:00) |
| Jul 2, 10:00 | task_2 disposed | `seller_wants_to_resume` | (none — terminal) | **active** (resume_at = 10:00, process 1 ends) |
| Jul 8, 12:00 | task_3 created (new intent) | none yet | task_3 open, new process | in churn process (again) |
| Jul 8, 19:00 | task_3 disposed | `seller_wants_to_drop_out` | (none — terminal) | **churned** (churn_at = 19:00, terminal forever) |

**How to detect each state from data** (the seller-level state machine):

Look at ALL `churn_seller_callback` tasks for the seller, then apply this cascade **in order**:

- **Churned** — seller has ANY task ever with `disposition_reasons = 'seller_wants_to_drop_out'`. Terminal and absolute. Stop.
- **Paused** — seller's most recent `seller_wants_to_pause` event has NO later resume/continue/drop_out event after its `updated_at`. If a later resume/continue exists, they're no longer paused. If a later drop_out exists, they're churned (caught by rule above).
- **In churn process** — most recent `churn_seller_callback` task has a NULL or non-terminal disposition (like `seller_did_not_pickup`), AND the seller isn't paused, AND isn't churned.
- **Recovered / active** — has churn tasks but latest terminal disposition is `seller_wants_to_resume` / `seller_resumed` / `seller_wants_to_continue`.
- **Never churned** — no `churn_seller_callback` tasks at all.

**Key timestamps to compute:**

| Timestamp | Detection | Field |
|---|---|---|
| `churn_process_started_at` | First task's `created_at` per process | `ob_tasks.created_at` |
| `pause_at` | `updated_at` when `disposition_reasons = 'seller_wants_to_pause'` | `ob_tasks.updated_at` |
| `resume_at` | `updated_at` when `disposition_reasons IN ('seller_wants_to_resume','seller_resumed')` | `ob_tasks.updated_at` |
| `churn_at` (terminal) | `updated_at` when `disposition_reasons = 'seller_wants_to_drop_out'` | `ob_tasks.updated_at` |

**Impact on every other analysis** (Claude MUST apply these adjustments when relevant):

- **Funnel conversion (Pattern 2):** Paused and churned sellers should typically be excluded from the "failed to convert" denominator. They didn't fail due to POC issues — they left/paused by their own intent. Compute conversion as `(converted) / (cohort_size − paused − churned)` if the question is about POC-driven progression.
- **Stuck-seller detection (Pattern 4):** A seller past 7 days without ft completion could be genuinely stuck OR simply paused. **Exclude paused sellers from stuck lists** — chasing them wastes POC time and misreads intent.
- **Cohort maturity:** When comparing cohorts on conversion, splitting by lifecycle state (`active` vs `paused` vs `churned` fractions) exposes whether a "low-converting" cohort is actually just paused-heavy.

**Do NOT mix these states in the same denominator without asking:**

- "In churn process" is a review state — seller might drop out or resume, undecided. NOT the same as churned.
- "Paused" is temporary — seller might unpause and return to the funnel. NOT the same as churned.
- "Churned" is final — only sellers with `seller_wants_to_drop_out` on any task ever.
- If asked *"how many sellers left?"* — clarify: **final churn only** (drop_out), **currently paused** (still might resume), **in churn process** (undecided), or **any non-active state** (all three)?

**Pitfall (recorded from a real mistake):** the earlier version of this section modeled a single task as capable of "transitioning through multiple dispositions" (pause → resume on the SAME task). That's wrong. Every task has exactly ONE disposition. State transitions happen across a CHAIN of tasks. If Claude ever writes a query that reads pause and resume from the same task row, it's wrong — those events are on separate task rows linked by the pause disposition spawning a follow-up.

---

## Data model

All tables live under `blitzscale-prod-project.nushop.*`.

### `nushop.ob_tickets` — the master record per seller journey

**Cardinality:** One row per (seller × journey attempt). A seller CAN have multiple tickets across time, but usually 1 per seller unless they re-onboarded.

**Partitioned on:** `created_at` (required filter)

Key columns:
- `id` — ticket ID (matches `ob_tasks.ticket_id`)
- `seller_id` — seller identifier (matches `ob_tasks.seller_id` and `seller_offers.seller_id`)
- `ob_poc`, `gtg_poc`, `gtg_approver_poc`, `cataloging_poc`, `website_poc`, `qc_poc`, `creatives_poc` — user IDs, join to `users._id` to get first_name
- `created_at` — ticket creation timestamp (UTC)
- `journey_questionnaire` — JSON with fields: `category`, `catalogue_size`, `catalogue_sharing_preference` (array), `marketing_timeline`. Extract with `JSON_VALUE(t.journey_questionnaire, '$.field_name')` or `JSON_VALUE_ARRAY` for arrays.

### `nushop.ob_tasks` — the operational task list

**Cardinality:** Many rows per ticket (up to 12+ tasks). Many rows per seller (aggregated across all their tickets). A seller can have multiple rows for the same task type if the task was re-created (rare but happens — use `MAX(completed_at)` in `MAX(IF(type=..., completed_at, NULL))` idiom).

**Partitioned on:** `created_at` (required filter)

Key columns:
- `id` — task ID (referenced by `exotel_calls.entity_id` when `entity = 'ob-task'`)
- `seller_id`, `ticket_id`
- `type` — one of the 12 funnel task types listed above, OR `churn_seller_callback` (a non-funnel lifecycle callback — see "Seller lifecycle states" above)
- `status` — typical values: `completed`, `pending`, `cancelled`, `blocked`
- `disposition_reasons` — outcome of a callback task. For `churn_seller_callback` tasks, one of the terminal values (`seller_wants_to_pause`, `seller_wants_to_resume`, `seller_resumed`, `seller_wants_to_continue`, `seller_wants_to_drop_out`) or a non-terminal contact-outcome value (like `seller_did_not_pickup`) or NULL (task not yet disposed). See "Seller lifecycle states" for state mapping. May exist on other callback task types too.
- `assigned_poc` — user ID of the person who actually worked this task (join to `users._id`)
- `completed_at` — nullable; timestamp of completion in UTC
- `updated_at` — last modification. **For `churn_seller_callback` tasks, this is the timestamp of the latest disposition change** (pause/resume/churn events).
- `created_at` — task creation timestamp (this is the partition column). **For `churn_seller_callback` tasks, this is when the churn process started.**

### `nushop.seller_journey_milestones` — coarse stage tracking

**Cardinality:** Many rows per ticket (5 milestone types + potential aliasing).

**Partitioned on:** `created_at` (required filter)

Key columns:
- `ticket_id`
- `step_name` — see milestone aliases above; alias in queries
- `status` — filter to `'completed'` for done milestones
- `updated_at` — completion timestamp (use `updated_at` NOT `created_at` for completion timing)

### `nushop.users` — POC/user reference

**Cardinality:** One row per user.

**Partitioned on:** NOT partitioned. The only table in this schema without a partition filter requirement.

Key columns:
- `_id` — user ID (matches the POC fields on tickets/tasks)
- `first_name`, `last_name`, `email`

### `nushop.exotel_calls` — call records

**Cardinality:** Many rows per task (each phone call between POC and seller creates a row). Joined to tasks via `entity_id`.

**Partitioned on:** `created_at` (required filter)

Key columns:
- `entity` — filter to `'ob-task'` for task-related calls
- `entity_id` — the `ob_tasks.id` when entity is ob-task
- `exotel_call_sid` — joins to `exotel_call_details.sid`

### `nushop.exotel_call_details` — per-call detail

**Cardinality:** One-ish per call (roughly 1:1 with exotel_calls via sid).

**Partitioned on:** `created_at` (required filter)

Key columns:
- `sid` — matches `exotel_calls.exotel_call_sid`
- `call_type` — lowercase `inbound` or `outbound`
- `status` — uppercase `CONNECTED`, `BUSY`, `NO_ANSWER`, `FAILED`, etc. Use `UPPER()` when comparing to be safe.

### `nushop.seller_offers` — per-seller offer assignments

**Cardinality:** Many rows per seller (a seller can be assigned/reassigned offers over time).

**Partitioned on:** `created_at` (required filter)

Key columns:
- `seller_id`
- `offer_id` — matches the hardcoded offer definitions above
- `status` — `active`, `expired`, `cancelled`, etc.
- `recorded_at` — when the offer assignment was recorded
- `start_date`, `end_date` — offer validity window
- `is_zero_percentage_commission` — boolean flag

---

## Relationship map at a glance

```
users (_id)  <──── ob_tickets.ob_poc, gtg_poc, cataloging_poc, website_poc, qc_poc, creatives_poc, gtg_approver_poc
             <──── ob_tasks.assigned_poc

ob_tickets (id) 1───N ob_tasks.ticket_id
ob_tickets (id) 1───N seller_journey_milestones.ticket_id
ob_tickets (seller_id) N───1 seller (implicit)

ob_tasks (id) 1───N exotel_calls.entity_id (when entity='ob-task')
exotel_calls (exotel_call_sid) 1───1 exotel_call_details.sid

seller (implicit) 1───N seller_offers.seller_id
```

Cardinalities that catch people out:
- **A seller can have multiple tickets.** Uncommon but real. If you `SELECT seller_id FROM ob_tickets` you may get more tickets than distinct sellers.
- **A ticket can have multiple rows of the same task type.** Uncommon, but the recovery pattern for stuck tasks creates duplicates. `MAX(completed_at)` per (seller, type) idiom handles this — see the pivot CTE in the reference script.
- **A milestone step_name has aliases** (Catalogue vs Catalogue Creation etc.). Always merge them.
- **A task's assigned_poc can differ from the ticket-level POC.** If someone asks "which POC did the fund_transfer for this seller", use `ob_tasks.assigned_poc`, not `ob_tickets.ob_poc`.
- **The users table is not partitioned.** All other tables require `created_at` filters.

---

## BigQuery query conventions (non-negotiable)

### Partition filters

Every table except `users` is partitioned on `created_at` and BQ **will reject queries without a filter**. This isn't optional.

Standard filter forms:

```sql
-- Fixed lookback window
AND created_at >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY))
AND created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))

-- Aligned to start of month (used by refresh scripts)
AND created_at >= TIMESTAMP(DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 5 MONTH), MONTH))
AND created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))

-- Fixed date (for specific event analyses)
AND created_at >= TIMESTAMP('2026-07-01')
AND created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))

-- Specific timestamp (e.g., post-deploy)
AND created_at >= TIMESTAMP('2026-07-08 14:22:00 UTC')  -- Jul 8 7:52 PM IST
```

**Rule:** upper bound is `< DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY)` — this includes today's rows without ambiguity around timezone boundaries.

### Partition filter on JOIN-side tables

BigQuery evaluates the join before applying WHERE. If you join to a partitioned table without an inline filter, it fails. Two acceptable patterns:

**Pattern A (recommended):** Filter inside a CTE that becomes the join input.
```sql
WITH tickets_filtered AS (
  SELECT * FROM `blitzscale-prod-project.nushop.ob_tickets`
  WHERE created_at >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY))
    AND created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
)
SELECT ... FROM meta_done m
LEFT JOIN tickets_filtered t ON m.ticket_id = t.id
```

**Pattern B:** Filter in the JOIN ON clause.
```sql
LEFT JOIN `blitzscale-prod-project.nushop.ob_tickets` t
  ON m.ticket_id = t.id
  AND t.created_at >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY))
  AND t.created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
```

Never omit the filter and hope BQ figures it out — it will fail loudly, and worse, sometimes silently return partial data if a temporary override was set.

### Choosing the lookback window

Match the analysis timeframe:
- Task/milestone completions in last 30d → 45–60d partition window (allows for tasks created earlier that completed recently)
- Ticket funnel analysis over months → 5-month partition window on ob_tickets and ob_tasks
- Point-in-time check ("what's happening today?") → 7–14d partition window
- Call metrics tied to tasks — extend by 1 month beyond the task window to capture calls on older tasks

**Rule of thumb:** partition column filters ticket/task/call *creation date*, not completion date. A task completed today may have been created 60 days ago. Set the lookback wide enough to include creation.

### Timezone handling

- **Storage:** BigQuery timestamps are UTC.
- **Business timezone:** IST (Asia/Kolkata), UTC+5:30.
- **For display in reports:** `DATETIME(ts, 'Asia/Kolkata') AS field_ist`
- **For "today"-relative filters:** `CURRENT_DATE()` returns UTC date. When the user says "today" they usually mean IST. For most windows this doesn't matter (±5.5hr on multi-day ranges is noise), but for same-day queries close to midnight IST, be careful — mention the ambiguity.

### Cohort maturity gating (weekly, monthly, any binned cohort)

**This is subtle and easy to get wrong. Read carefully.**

A cohort is a group of tickets/sellers created within some time bin (a week, a month). "Maturity" means enough time has passed for the cohort's downstream metric (dN conversion) to be observable. The mistake most people make — and one Claude has made in this project before — is measuring maturity from the cohort's START. That's wrong for any cohort wider than a single day.

**The rule.** For a cohort of width W days:

> `days_since_cohort_end = CURRENT_DATE − (cohort_start + (W−1) days)`

Gate `>= N` on THIS value, not on days-since-cohort-start.

Concretely:
- **Daily cohort (W=1):** offset 0. `days_since_cohort_end = CURRENT_DATE − cohort_date`. The naive calculation works. This is the only case where it does.
- **Weekly cohort (W=7, Mon–Sun):** offset +6. `days_since_cohort_end = CURRENT_DATE − (cohort_week_start + 6 days)`, equivalently `CURRENT_DATE − cohort_week_end`.
- **Monthly cohort:** use `LAST_DAY(cohort_month)`. `days_since_cohort_end = CURRENT_DATE − LAST_DAY(cohort_month)`.

**Why the naive version is wrong (worked example).** Weekly cohort W28 = Jul 6–12. Today is Jul 14. If you measure `days_elapsed = CURRENT_DATE − cohort_week_start` you get 8 and label the cohort "d7-mature". But the Sunday-created tickets in W28 (Jul 12) are only 2 days old — they haven't hit their own d7 yet. The cohort as a whole becomes d7-mature only on Jul 19 (7 days after its Sunday). Gating at the wrong anchor mislabels the cohort as mature up to 6 days early, and any downstream extrapolation stops at exactly the point where it was still needed.

**Correct SQL pattern (weekly, d14 gate).** Two maturity concepts, kept separate:

```sql
WITH ticket_cohorts AS (
  SELECT
    t.id AS ticket_id,
    t.seller_id,
    DATE(t.created_at) AS ticket_date,
    DATE_TRUNC(DATE(t.created_at), WEEK(MONDAY)) AS cohort_week
  FROM `blitzscale-prod-project.nushop.ob_tickets` t
  WHERE t.created_at >= TIMESTAMP('2026-05-01')
    AND t.created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
),
task_done AS (
  SELECT seller_id, MAX(completed_at) AS done_at
  FROM `blitzscale-prod-project.nushop.ob_tasks`
  WHERE type = 'meta_setup' AND status = 'completed'
    AND created_at >= TIMESTAMP('2026-05-01')
    AND created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
  GROUP BY seller_id
)
SELECT
  c.cohort_week,
  DATE_ADD(c.cohort_week, INTERVAL 6 DAY) AS cohort_week_end,
  DATE_DIFF(CURRENT_DATE(), DATE_ADD(c.cohort_week, INTERVAL 6 DAY), DAY) AS days_since_cohort_end,
  DATE_DIFF(CURRENT_DATE(), DATE_ADD(c.cohort_week, INTERVAL 6 DAY), DAY) >= 14 AS is_d14_mature,
  COUNT(*) AS cohort_size,
  COUNTIF(td.done_at IS NOT NULL
          AND DATE_DIFF(DATE(td.done_at), c.ticket_date, DAY) <= 14) AS done_in_14d,
  SAFE_DIVIDE(
    COUNTIF(td.done_at IS NOT NULL
            AND DATE_DIFF(DATE(td.done_at), c.ticket_date, DAY) <= 14),
    COUNT(*)
  ) AS d14_conversion_rate
FROM ticket_cohorts c
LEFT JOIN task_done td ON c.seller_id = td.seller_id
GROUP BY c.cohort_week
ORDER BY c.cohort_week DESC
```

Two maturity concepts in this query, kept separate on purpose:
- **Ticket-level maturity for the metric itself** — `DATE_DIFF(done, ticket_date) <= 14` measures dN per ticket. Each ticket has its own clock.
- **Cohort-level maturity for whether to trust the cohort's aggregate rate** — `days_since_cohort_end >= 14`. This gates whether we should compare this cohort to others. In-progress cohorts have artificially low rates.

For cross-cohort comparisons, filter to `is_d14_mature = TRUE`. If in-progress cohorts must be shown, mark them clearly (`(in progress)` label) — never mix them into a table meant for cohort-to-cohort comparison.

**Naming convention (enforce this).** Call the variable `days_since_cohort_end`, `days_since_week_end`, or `days_since_month_end`. **Never** `days_elapsed`, `cohort_age`, or `elapsed_days` — those names sound singular and invite the bug because a weekly cohort doesn't have a single elapsed value.

**Mandatory sanity check before shipping cohort-maturity output.** Print the newest cohort's calendar dates alongside its maturity label. If a cohort labeled "d7-mature" contains any tickets that landed <7 calendar days ago, the label is wrong. A 5-second check that catches this bug every time.

**Provenance:** this section exists because of a specific failure in July 2026 where a weekly cohort was labeled `d7-mature` with a `days_elapsed = 8` value measured from Monday. W28 (Jul 6–12) actually didn't reach d7 maturity until Jul 19. The variable name and the missing calendar sanity-check let the bug survive multiple iterations. If Claude ever writes cohort-maturity logic that doesn't reference this section explicitly, it should stop and re-read it.

### Projecting immature cohorts (curve extrapolation)

Once a cohort is correctly identified as immature (via `days_since_cohort_end < N`), the natural next question is: can we still compare it to mature cohorts on the same horizon? Yes — with curve extrapolation, done carefully. This section covers the correct method.

**When to project.** Only when comparing an immature cohort against mature ones at the same horizon. If you're just reporting the cohort's current state, show `actual` with a maturity label — don't project. Once a cohort matures, use the actual; never overwrite it with the projection.

**Why not straight-line.** `actual × N ÷ days_elapsed` assumes conversion accrues at a constant pace across the horizon. It doesn't:
- **gtg, meta_setup** front-load in the first week — straight-line over-projects.
- **fund_transfer** has a long tail (especially post-48hr-policy) — straight-line under-projects.

Use the observed conversion curve from mature cohorts as the reference shape.

**Building the baseline curve.** Take every cohort already fully mature at your target horizon and compute `rate(step, d)` for `d = 0..N`:

```sql
baseline_curve AS (
  SELECT
    d AS day_n,
    SAFE_DIVIDE(
      COUNTIF(bp.cohort_age >= d AND bp.d_step IS NOT NULL AND bp.d_step <= d),
      COUNTIF(bp.cohort_age >= d)
    ) AS step_rate
  FROM UNNEST(GENERATE_ARRAY(0, 90)) AS d
  CROSS JOIN baseline_pool bp
  GROUP BY d
)
```

Two non-negotiable disciplines:

1. **Horizon-corrected denominators.** At day `d`, include only cohorts whose `cohort_age >= d` in the denominator — that's the `cohort_age >= d` condition on both sides of the SAFE_DIVIDE above. Without it, cohorts that haven't observed day `d` yet drag the rate down.
2. **Same-population baseline.** The cohorts feeding the baseline should resemble the ones being projected — similar seller mix, offers, POC staffing. If a major regime change happened between them (like the Jul 1 48hr policy), the baseline needs to be scoped to reflect it. Always state the baseline window explicitly in the output so the reader knows what shape is being applied.

**Applying the curve.** For a cohort at age `T` (measured from cohort end, per the maturity section above) with `actual` sellers converted so far, project to horizon `N`:

> `projected_at_dN = actual × baseline_rate(step, N) ÷ baseline_rate(step, T)`

The ratio `rate(N) / rate(T)` is the historical multiplier from age T to age N. Example: cohort is at age 8, `actual = 100` converted; baseline shows mature cohorts had achieved 45% by d8 and 60% by d30. Projection: `100 × 0.60 / 0.45 ≈ 133` at d30.

Report both projected count and projected % (`projected ÷ cohort_size`).

**The 2-day FT delay — era-split projection.** The 48hr policy shortens the fund_transfer window by 2 days for post-deploy tickets. A post-deploy cohort at age T has had only T−2 days of effective FT runway. Applying the baseline directly without adjusting overstates FT progress. Two rules:

1. **Never project a mixed-era cohort as one blob.** Split `ft_actual_pre` and `ft_actual_post` inside the cohort using `ticket.created_at >= TIMESTAMP('2026-07-08 14:22:00 UTC')`. Project each half separately.
2. **Shift the FT baseline lookup by 2 days for the post-deploy half:**

> `ft_post_projected_dN = ft_actual_post × baseline_ft_rate(N − 2) ÷ baseline_ft_rate(T − 2)`

Both numerator and denominator shift by 2 days. This makes it a like-for-like comparison against the (pre-deploy-dominated) baseline — the 2 days the post cohort "lost" waiting for the FT window shouldn't be credited toward its maturity clock.

The cohort's total FT projection is the **sum** of the two halves: `pre_projection + post_projection`. Never a blended rate applied to the whole cohort.

If `T < 2` for a post-deploy cohort, effective runway is zero and any FT projection is meaningless. Return NULL and label "too early".

**Mandatory guardrails on every projection output:**

- **Label each cohort's maturity** — `mature | partial | young`, with the horizon it's mature against. Never let a reader confuse a projection with an actual.
- **NULL when the ratio is undefined.** If `baseline_rate(T) = 0` (rate hasn't started accruing at this age), projection is undefined. Return NULL, not the actual, not a straight-line fallback.
- **State the baseline window explicitly** in the output: *"baseline built from cohorts W12–W22"*. When someone asks why a projection looks off, they need to see the shape being applied.
- **Sanity-cap and cross-check.** `pre_projection + post_projection <= tickets` must hold. If it's over, `baseline_rate(T)` was very small and the multiplier ran away. Cap projections at `cohort_size` and flag the row for review.
- **Never project a metric backward.** If actual has already crossed the horizon (e.g., `days_since_cohort_end >= N`), use actual — don't recompute via curve.

**Provenance:** the era-split adjustment exists because a straight application of the baseline curve to a post-Jul-8 cohort systematically overstates FT conversion. Post-deploy tickets are 2 days behind an equivalent pre-deploy ticket on the FT clock; the projection must acknowledge that or it silently inflates the number.

### Long-running queries via Apps Script

Never use `BigQuery.Jobs.query()` for anything that might take >30 seconds — it fails with "Not found" errors intermittently. Use the `Jobs.insert` + polling pattern from the reference script:

1. Insert the job with `timeoutMs: 60000`
2. Poll with `Jobs.getQueryResults(project, jobId, {location, timeoutMs: 30000})` — **pass `location` from `jobReference` on every follow-up call**, or later calls will 404
3. Retry transient "Not found" errors up to 15 times with exponential backoff
4. Paginate with `pageToken` for large result sets

See the reference implementation in the Apps Script.

---

## Clarifying-question protocol

Before writing any query, run through this checklist. If ANY of these is unclear from the user's request, ASK before writing SQL. Do not silently pick a definition and hope it's right — the wrong grain or the wrong window makes the whole result wrong.

Use `ask_user_input_v0` for multiple choice, or ask 1–2 focused questions in prose. Prefer the tool when there are 2+ ambiguities.

### The seven canonical ambiguities

**1. Unit of analysis (grain).**
> "How many sellers?" is different from "how many tickets?" is different from "how many task completions?"

Ask: *"Do you want unique sellers, unique tickets, or unique task events? A seller can have multiple tickets, and a ticket can have multiple task rows."*

**2. Time window and anchor.**
> "Last week" — calendar week (Mon–Sun) or trailing 7 days? "Since Jul 1" — inclusive? Which timezone?

Ask: *"What window — a specific date range, a trailing N days, calendar week, or since a specific event? IST or UTC?"*

**3. Cohort anchor date.**
> Bucketing sellers requires a cohort date. Is it their ticket_created_date? Meta_completed_date? Cagd_completed_date?

Ask: *"When you say 'cohort of sellers', anchored on what date — when the ticket was created, or when they completed some specific task?"*

**4. Status filter.**
> Include cancelled tickets? Include tasks with `status='blocked'`? Only completed?

Ask: *"Do you want to include cancelled/dormant tickets, or only actively-progressing ones?"*

**5. POC dimension.**
> Ticket-level POC field (assigned at ticket creation) or task-level assigned_poc (who actually did it)?

Ask: *"Which POC dimension — the ticket-level assigned POC, or the person who actually completed this specific task?"*

**6. Maturity filter for conversion metrics.**
> Comparing conversion rates across cohorts requires excluding cohorts that haven't finished maturing. A 3-day-old cohort's `ft_d14` is meaningless. AND for anything wider than daily bins, maturity must be measured from cohort END, not cohort start — see "Cohort maturity gating" above.

Ask internally, mention in the answer: *"For d14 conversion, I'll gate on `days_since_cohort_end >= 14` and only compare mature cohorts. In-progress cohorts show artificially low rates."*

**7. De-duplication rule.**
> If a seller has 3 completed meta_setup tasks (rare but happens), count all 3 or just 1?

Default to `MAX(completed_at)` per (seller, task_type) unless the user specifically wants task-level events.

### Additional questions for specific analyses

**Funnel analyses:** Ask for the completion window (d7? d14? d30?) and whether "converted" means "task completed" or "milestone reached".

**Compliance analyses (post-Jul 1):** Ask whether they want to split by pre-deploy vs post-deploy ticket era (matters for fund_transfer analysis).

**Comparison across weeks:** Confirm ISO week vs calendar week. The refresh script uses ISO weeks (Monday-start, `2026-W28`).

**Churn/pause analyses:** When users say "churned" or "left" sellers, clarify which state they mean:
- **Final churn** — `disposition_reasons = 'seller_wants_to_drop_out'` on any `churn_seller_callback` task (permanent, absolute)
- **In churn process** — most recent `churn_seller_callback` task has non-terminal disposition (NULL or a retry value like `seller_did_not_pickup`); seller isn't paused or churned
- **Currently paused** — most recent `seller_wants_to_pause` event has no later resume/continue/drop_out event (temporary, may resume)
- **Any non-active state** — union of all three above

These are NOT interchangeable. Never blend them in the same numerator without explicit direction. Also clarify: "sellers who churned in July" — does that mean the churn PROCESS started in July (`created_at`) or the churn was CONFIRMED in July (`updated_at` when `disposition_reasons = 'seller_wants_to_drop_out'`)?

### When to skip clarifying and just write

If the user gives you a fully-specified request, don't waste their time. Skip if all of:
- Explicit date range or window given
- Unit of analysis is unambiguous ("how many tickets" is clear)
- No conversion / cohort concept requiring maturity handling

**When to write anyway with an assumption:** State the assumption prominently and let them push back. E.g., *"I'm assuming you mean unique sellers, using ticket_created_date as the cohort anchor. Let me know if either is wrong."*

---

## Common analysis patterns (ready-to-adapt query templates)

### Pattern 1: Daily task/milestone completions

Question shape: "How many X did we complete each day for the last N days?"

```sql
SELECT
  DATE(completed_at) AS completion_date,
  COUNT(DISTINCT seller_id) AS unique_sellers,
  COUNT(*) AS total_events
FROM `blitzscale-prod-project.nushop.ob_tasks`
WHERE status = 'completed'
  AND type = 'meta_setup'  -- or the task type in question
  AND completed_at >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY))
  AND created_at   >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY))
  AND created_at   <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
GROUP BY completion_date
ORDER BY completion_date DESC
```

Note the 120-day partition filter on created_at even though we're filtering completed_at to 30d — tasks can be created long before they're completed.

### Pattern 2: Funnel conversion by cohort

Question shape: "Of sellers whose tickets were created week W, what % completed task T within N days?"

**Before writing this query, read the "Cohort maturity gating" section above.** The maturity gate here uses cohort END, not cohort start. Skipping that section leads directly to the bug this pattern is written to avoid.

```sql
WITH ticket_cohorts AS (
  SELECT
    t.id AS ticket_id,
    t.seller_id,
    DATE(t.created_at) AS ticket_date,
    DATE_TRUNC(DATE(t.created_at), WEEK(MONDAY)) AS cohort_week
  FROM `blitzscale-prod-project.nushop.ob_tickets` t
  WHERE t.created_at >= TIMESTAMP('2026-05-01')
    AND t.created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
),
task_done AS (
  SELECT seller_id, MAX(completed_at) AS done_at
  FROM `blitzscale-prod-project.nushop.ob_tasks`
  WHERE type = 'meta_setup' AND status = 'completed'
    AND created_at >= TIMESTAMP('2026-05-01')
    AND created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
  GROUP BY seller_id
)
SELECT
  c.cohort_week,
  DATE_ADD(c.cohort_week, INTERVAL 6 DAY) AS cohort_week_end,
  DATE_DIFF(CURRENT_DATE(), DATE_ADD(c.cohort_week, INTERVAL 6 DAY), DAY) AS days_since_cohort_end,
  DATE_DIFF(CURRENT_DATE(), DATE_ADD(c.cohort_week, INTERVAL 6 DAY), DAY) >= 14 AS is_d14_mature,
  COUNT(*) AS cohort_size,
  COUNTIF(td.done_at IS NOT NULL
          AND DATE_DIFF(DATE(td.done_at), c.ticket_date, DAY) <= 14) AS done_in_14d,
  SAFE_DIVIDE(
    COUNTIF(td.done_at IS NOT NULL
            AND DATE_DIFF(DATE(td.done_at), c.ticket_date, DAY) <= 14),
    COUNT(*)
  ) AS d14_conversion_rate
FROM ticket_cohorts c
LEFT JOIN task_done td ON c.seller_id = td.seller_id
GROUP BY c.cohort_week
ORDER BY c.cohort_week DESC
```

**How to use the output.** For cross-cohort comparisons of `d14_conversion_rate`, filter to `is_d14_mature = TRUE`. If displaying in-progress cohorts too (fine, sometimes wanted), mark them explicitly — e.g., append `(in progress — d14 clock hasn't finished)` to their label. Never let a reader compare a mature cohort's rate to an in-progress one's rate without that flag.

**Sanity-check before shipping.** Print the newest few cohorts with their `cohort_week`, `cohort_week_end`, `days_since_cohort_end`, and `is_d14_mature`. Verify by eye that anything labeled mature actually is — the newest ticket in that cohort must be ≥14 days old.

**Monthly cohorts:** replace `DATE_TRUNC(..., WEEK(MONDAY))` with `DATE_TRUNC(..., MONTH)`, and replace `DATE_ADD(c.cohort_week, INTERVAL 6 DAY)` with `LAST_DAY(c.cohort_month)`. Everything else is the same shape.

### Pattern 3: POC throughput

Question shape: "How many tasks did each POC complete last week?"

```sql
SELECT
  u.first_name AS poc,
  ot.type AS task_type,
  COUNT(*) AS tasks_completed
FROM `blitzscale-prod-project.nushop.ob_tasks` ot
JOIN `blitzscale-prod-project.nushop.users` u ON ot.assigned_poc = u._id
WHERE ot.status = 'completed'
  AND ot.completed_at >= TIMESTAMP(DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 WEEK), WEEK(MONDAY)))
  AND ot.completed_at <  TIMESTAMP(DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY)))
  AND ot.created_at   >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY))
  AND ot.created_at   <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
GROUP BY poc, task_type
ORDER BY tasks_completed DESC
```

### Pattern 4: Stuck-seller detection

Question shape: "Which sellers finished task X but haven't finished task Y even after N days?"

```sql
WITH x_done AS (
  SELECT seller_id, MAX(completed_at) AS x_at
  FROM `blitzscale-prod-project.nushop.ob_tasks`
  WHERE type = 'meta_setup' AND status = 'completed'
    AND completed_at >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY))
    AND created_at   >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY))
    AND created_at   <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
  GROUP BY seller_id
),
y_done AS (
  SELECT seller_id, MAX(completed_at) AS y_at
  FROM `blitzscale-prod-project.nushop.ob_tasks`
  WHERE type = 'fund_transfer' AND status = 'completed'
    AND created_at >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY))
    AND created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
  GROUP BY seller_id
)
SELECT
  x.seller_id,
  DATETIME(x.x_at, 'Asia/Kolkata') AS meta_completed_ist,
  DATE_DIFF(CURRENT_DATE(), DATE(x.x_at), DAY) AS days_since_meta
FROM x_done x
LEFT JOIN y_done y ON x.seller_id = y.seller_id AND y.y_at >= x.x_at
WHERE y.y_at IS NULL
  AND DATE_DIFF(CURRENT_DATE(), DATE(x.x_at), DAY) > 7
ORDER BY days_since_meta DESC
```

Important: `y.y_at >= x.x_at` ensures we're not matching a fund_transfer from an earlier ticket cycle.

### Pattern 5: Ticket-era split (pre-deploy vs post-deploy)

For fund_transfer / 48hr-policy analyses, always split by ticket era.

```sql
CASE
  WHEN t.created_at >= TIMESTAMP('2026-07-08 14:22:00 UTC') THEN 'post_deploy'
  ELSE 'pre_deploy'
END AS ticket_era
```

Include this column in any output touching fund_transfer analysis so the reader can filter.

### Pattern 6: Call metrics per task/ticket

```sql
SELECT
  ot.ticket_id,
  COUNT(*) AS total_calls,
  COUNTIF(LOWER(ecd.call_type) = 'outbound') AS outbound_calls,
  COUNTIF(LOWER(ecd.call_type) = 'inbound')  AS inbound_calls,
  SAFE_DIVIDE(
    COUNTIF(LOWER(ecd.call_type) = 'outbound' AND UPPER(ecd.status) = 'CONNECTED'),
    COUNTIF(LOWER(ecd.call_type) = 'outbound')
  ) AS outbound_connect_rate
FROM `blitzscale-prod-project.nushop.exotel_calls` ec
JOIN `blitzscale-prod-project.nushop.exotel_call_details` ecd
  ON ec.exotel_call_sid = ecd.sid
JOIN `blitzscale-prod-project.nushop.ob_tasks` ot
  ON ec.entity_id = ot.id
WHERE ec.entity = 'ob-task'
  AND ec.created_at  >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY))
  AND ec.created_at  <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
  AND ecd.created_at >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY))
  AND ecd.created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
  AND ot.created_at  >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
  AND ot.created_at  <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
GROUP BY ot.ticket_id
```

All three tables (`exotel_calls`, `exotel_call_details`, `ob_tasks`) are partitioned — every one needs a filter. Extend `ob_tasks` slightly beyond the call window since a task can pre-date its calls.

### Pattern 7: Seller with their most recent offer

```sql
WITH seller_offers_latest AS (
  SELECT seller_id, offer_id, status
  FROM (
    SELECT seller_id, offer_id, status,
      ROW_NUMBER() OVER (PARTITION BY seller_id ORDER BY recorded_at DESC) AS rn
    FROM `blitzscale-prod-project.nushop.seller_offers`
    WHERE created_at >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 5 MONTH))
      AND created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
  )
  WHERE rn = 1
)
SELECT ... FROM sellers s LEFT JOIN seller_offers_latest sol ON s.seller_id = sol.seller_id
```

For offer names, hardcode the mapping in a `seller_offer_map` CTE using `UNNEST([STRUCT(...)])` — see the Apps Script.

### Pattern 8: Churn and pause state detection

Question shapes: "How many sellers are paused / churned / in churn process right now?" or "Show me daily churn/pause events" or "When did seller X get paused?"

**Read "Seller lifecycle states" in Business context first — this pattern encodes the state machine defined there.** The key correction over any naive implementation: pause and resume events live on DIFFERENT tasks (pause spawns a follow-up; that follow-up gets the resume disposition). Looking at only the latest task will incorrectly label a paused seller whose follow-up task has no disposition yet as "in_churn_process" and a resumed seller as "active" without knowing they were paused.

**Point-in-time state per seller** (correct cascade across all churn tasks):

```sql
WITH churn_tasks AS (
  SELECT
    seller_id,
    id AS task_id,
    created_at,
    updated_at,
    disposition_reasons
  FROM `blitzscale-prod-project.nushop.ob_tasks`
  WHERE type = 'churn_seller_callback'
    AND created_at >= TIMESTAMP('2025-01-01')
    AND created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
),
seller_events AS (
  SELECT
    seller_id,
    -- Terminal event timestamps (any occurrence, ever)
    MAX(IF(disposition_reasons = 'seller_wants_to_drop_out', updated_at, NULL)) AS churn_at,
    MAX(IF(disposition_reasons = 'seller_wants_to_pause', updated_at, NULL))    AS last_pause_at,
    MAX(IF(disposition_reasons IN ('seller_wants_to_resume','seller_resumed'),
           updated_at, NULL))                                                   AS last_resume_at,
    MAX(IF(disposition_reasons = 'seller_wants_to_continue', updated_at, NULL)) AS last_continue_at,
    -- First-ever churn process start (for tenure)
    MIN(created_at) AS first_churn_process_started_at,
    -- Most recent task's disposition (to check if a process is currently open)
    ARRAY_AGG(disposition_reasons ORDER BY created_at DESC LIMIT 1)[OFFSET(0)] AS latest_task_disposition,
    MAX(created_at) AS latest_task_created_at
  FROM churn_tasks
  GROUP BY seller_id
)
SELECT
  seller_id,
  DATETIME(first_churn_process_started_at, 'Asia/Kolkata') AS first_churn_started_ist,
  DATETIME(latest_task_created_at, 'Asia/Kolkata')         AS latest_task_ist,
  DATETIME(churn_at, 'Asia/Kolkata')                       AS churn_at_ist,
  DATETIME(last_pause_at, 'Asia/Kolkata')                  AS last_pause_ist,
  DATETIME(last_resume_at, 'Asia/Kolkata')                 AS last_resume_ist,
  latest_task_disposition,
  CASE
    -- Terminal, absolute — churned wins over everything
    WHEN churn_at IS NOT NULL THEN 'churned'
    -- Paused: has pause with no later resume/continue
    WHEN last_pause_at IS NOT NULL
         AND (last_resume_at   IS NULL OR last_resume_at   < last_pause_at)
         AND (last_continue_at IS NULL OR last_continue_at < last_pause_at)
      THEN 'paused'
    -- Latest task is not terminally disposed → process still open
    WHEN latest_task_disposition IS NULL
         OR latest_task_disposition NOT IN (
              'seller_wants_to_pause','seller_wants_to_resume','seller_resumed',
              'seller_wants_to_continue','seller_wants_to_drop_out'
            )
      THEN 'in_churn_process'
    -- Latest terminal event is a recovery
    ELSE 'recovered'
  END AS lifecycle_state
FROM seller_events
```

Filter by `lifecycle_state = 'paused'`, `'churned'`, `'in_churn_process'` etc. Sellers with no `churn_seller_callback` task ever are NOT in this result — they're implicitly active/never-churned. If you need "% of all sellers who churned", LEFT JOIN this to a base seller list and treat non-matches as active.

**Daily event volume** (how many pauses / resumes / churns per day):

```sql
SELECT
  DATE(updated_at, 'Asia/Kolkata') AS event_date,
  COUNTIF(disposition_reasons = 'seller_wants_to_pause')    AS paused,
  COUNTIF(disposition_reasons IN ('seller_wants_to_resume','seller_resumed')) AS unpaused,
  COUNTIF(disposition_reasons = 'seller_wants_to_drop_out') AS churned,
  COUNTIF(disposition_reasons = 'seller_wants_to_continue') AS revived
FROM `blitzscale-prod-project.nushop.ob_tasks`
WHERE type = 'churn_seller_callback'
  AND disposition_reasons IS NOT NULL
  AND updated_at >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 45 DAY))
  AND updated_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
  AND created_at >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY))
  AND created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
GROUP BY event_date
ORDER BY event_date DESC
```

Note: `updated_at` is the disposition-set timestamp. `created_at` filter is wider because dispositions can be applied to tasks created much earlier.

**Churn processes started per day** (task creations after a prior process ended — or first-ever). Counting task creations directly overcounts because follow-up tasks (spawned by pause or non-terminal dispositions) are NOT new processes. To count actual new processes:

```sql
WITH churn_tasks AS (
  SELECT
    seller_id,
    id AS task_id,
    created_at,
    disposition_reasons,
    LAG(disposition_reasons) OVER (PARTITION BY seller_id ORDER BY created_at) AS prev_disposition
  FROM `blitzscale-prod-project.nushop.ob_tasks`
  WHERE type = 'churn_seller_callback'
    AND created_at >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY))
    AND created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
)
SELECT
  DATE(created_at, 'Asia/Kolkata') AS start_date,
  COUNT(*) AS new_processes_started,
  COUNT(DISTINCT seller_id) AS unique_sellers
FROM churn_tasks
WHERE prev_disposition IS NULL                                                    -- first-ever task
   OR prev_disposition IN ('seller_wants_to_resume', 'seller_resumed',
                           'seller_wants_to_continue', 'seller_wants_to_drop_out') -- prior process was terminal
GROUP BY start_date
ORDER BY start_date DESC
```

The `LAG()` looks at each seller's previous churn task; if that previous task ended terminally (resume/continue/drop_out), the current task is a NEW process. If the previous task was `seller_wants_to_pause` or a non-terminal disposition (like `seller_did_not_pickup`), the current task is a follow-up in the SAME process and excluded here.

**Sellers currently paused** (as of today, with duration):

```sql
WITH seller_events AS (
  SELECT
    seller_id,
    MAX(IF(disposition_reasons = 'seller_wants_to_pause', updated_at, NULL))    AS last_pause_at,
    MAX(IF(disposition_reasons IN ('seller_wants_to_resume','seller_resumed'),
           updated_at, NULL))                                                   AS last_resume_at,
    MAX(IF(disposition_reasons = 'seller_wants_to_continue', updated_at, NULL)) AS last_continue_at,
    MAX(IF(disposition_reasons = 'seller_wants_to_drop_out', updated_at, NULL)) AS churn_at
  FROM `blitzscale-prod-project.nushop.ob_tasks`
  WHERE type = 'churn_seller_callback'
    AND created_at >= TIMESTAMP('2025-01-01')
    AND created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
  GROUP BY seller_id
)
SELECT
  seller_id,
  DATETIME(last_pause_at, 'Asia/Kolkata') AS paused_at_ist,
  DATE_DIFF(CURRENT_DATE('Asia/Kolkata'), DATE(last_pause_at, 'Asia/Kolkata'), DAY) AS days_paused
FROM seller_events
WHERE churn_at IS NULL
  AND last_pause_at IS NOT NULL
  AND (last_resume_at   IS NULL OR last_resume_at   < last_pause_at)
  AND (last_continue_at IS NULL OR last_continue_at < last_pause_at)
ORDER BY days_paused DESC
```

Long-paused sellers (say, `days_paused > 30`) may be de facto churned even without an explicit `seller_wants_to_drop_out` disposition. Worth flagging separately depending on the analysis.

**Notes on this pattern:**
- Pause and resume events live on DIFFERENT tasks (pause spawns a follow-up; that follow-up gets the resume). The MAX-per-disposition-across-all-tasks approach above is the correct way to derive state — never look at only the latest task's disposition.
- `churned` is absolute: once a seller has `seller_wants_to_drop_out` in their history, they're churned regardless of anything later. That's the CRM semantics.
- Non-terminal dispositions (`seller_did_not_pickup` etc) don't change state; they just mean the current process is still open with a retry pending. State detection treats them as "process not yet closed".
- Sellers with NO `churn_seller_callback` task ever don't appear here. Join to a base seller list if you need "% of all sellers churned".

---

## Output modes

### Ad-hoc query (one-off analysis)

Use when the user asks a specific question that doesn't need to repeat. Write the SQL, run it (if tools available), show results, offer to save as a template if the pattern feels repeatable.

Format: SQL in a code block, results in a markdown table or as a summary of counts. Include the exact partition filters and cohort definitions used, so the user can verify.

### Apps Script (recurring pipeline)

Use when the answer needs to refresh regularly, feed a Sheet, or produce multiple analytical tabs. Extend the reference script at `/mnt/user-data/outputs/refresh_and_analytics_v7.gs` (or the latest version).

Key patterns from the reference script:
- Every query goes into the `SQL` template literal — one big query, all CTEs
- Style tokens live in `STYLE = {...}` — respect them for new tabs
- New analytical tabs get added via `writeTab(spreadsheet, tabName, values, opts)`
- Percentage columns get formatted via `opts.pctCols`
- Freeze rows/cols, banded rows, and filters are applied automatically
- Never use `BigQuery.Jobs.query()` — use the polling pattern
- Pass `location` from `jobReference` on every `Jobs.getQueryResults` call

### Ad-hoc vs pipeline decision

- One-off answer to a Slack question → SQL
- Same question weekly → Apps Script that writes a tab
- Analysis where the user says "I want to look at this every day" → Apps Script
- Analysis where the answer is a specific list of tickets/sellers to action → SQL, then export to Excel/Sheet manually. Don't over-engineer a pipeline for a bounded action list.

---

## Common pitfalls to warn users about

When Claude writes an analysis, it should proactively flag these if they apply:

**1. Aggregation grain mistakes.** "Number of completed tasks" ≠ "number of unique sellers who completed a task". A seller with 3 completed meta_setup rows counts as 3 events but 1 seller.

**2. Maturity artifacts in cohort comparisons.** Two distinct failure modes here, both fatal to any cross-cohort comparison:
   - (a) Comparing recent cohorts' dN conversion to older cohorts' when the recent ones aren't N days old yet — they look artificially low.
   - (b) For weekly/monthly cohorts, measuring maturity from cohort START instead of cohort END. A weekly cohort labeled "d7-mature" needs `days_since_cohort_end >= 7` — measuring from Monday instead of Sunday mislabels it mature up to 6 days early. This bug survived multiple iterations in Jul 2026 because the variable was called `days_elapsed` (sounds singular but isn't for binned cohorts).
   
   **See "Cohort maturity gating" for the canonical rule and correct SQL.** Always call the variable `days_since_cohort_end` (never `days_elapsed`), and sanity-check the newest cohort's label against its calendar dates before shipping.

**3. Batching side-effects.** When one task in a pipeline slows down, adjacent tasks may look like they're also slowing (POCs process work in batches). Before concluding "task Y is broken", check whether task X shifted and Y is just following.

**4. Grandfathering / pre-post deploy.** For any fund_transfer analysis, the ticket_era matters. A pre-deploy ticket completing ft immediately is normal. A post-deploy ticket doing the same is a bug.

**5. Weekly volume noise.** Weekly aggregates fluctuate 20–30% naturally. A single week's dip is noise; a sustained 4-week trend is signal. Say so.

**6. Time-of-day cutoffs.** Filtering to "today" via `DATE(completed_at) = CURRENT_DATE()` on partial days makes today look artificially low. Compare full days, or annotate the partial day.

**7. Duplicate rows in source data.** Some tickets have multiple meta_setup rows. Filter to `MAX(completed_at) per (seller, task_type)` unless task events specifically matter.

**8. Missing joins to users.** POC field values are user IDs, not names. Failing to join to `nushop.users` produces unreadable output.

**9. Silent data staleness.** BigQuery views may lag production by minutes to hours. If the user is asking about "right now", note the potential lag.

**10. Absence of a row is meaningful.** A seller with no fund_transfer row is not the same as one with `status='cancelled'`. LEFT JOIN and `IS NULL` are how you catch "task never happened", not `!= 'completed'`.

**11. Curve projection failure modes.** Extrapolating an immature cohort has its own trap zoo:
   - Straight-line (`actual × N / days`) is wrong for every task except boringly linear ones — over-projects front-loaded steps (gtg, meta_setup), under-projects tail-heavy ones (ft). Use the curve method.
   - `baseline_rate(T) = 0` blows up the multiplier. Return NULL, don't fall back to straight-line.
   - Mixed-era cohorts must be projected era-by-era for FT (2-day shift on the post-deploy half). Blended-rate projection systematically overstates post-deploy FT progress.
   - Projections above `cohort_size` are always wrong — cap and flag them.
   - See "Projecting immature cohorts" for the canonical approach.

**12. Mixing seller-lifecycle states.** *In churn process* is NOT *churned*. *Paused* is NOT *churned*. A seller under churn review might still continue; a paused seller might unpause any day. Only `disposition_reasons = 'seller_wants_to_drop_out'` on ANY `churn_seller_callback` task means permanent churn. And never look at only the "latest task" to detect pause state — pause and resume live on DIFFERENT tasks (pause spawns a follow-up; the follow-up carries the resume disposition). See Pattern 8 and "Seller lifecycle states" for the correct multi-task detection. When asked "how many sellers churned?", always clarify:
   - final drop-out only? (churn confirmed)
   - currently paused too? (temporary but currently not active)
   - in-churn-process too? (under review, undecided)
   
   Also: "churned in July" is ambiguous — process started in July (`created_at`) vs churn confirmed in July (`updated_at` with drop_out disposition). These are different populations. See "Seller lifecycle states" for the full state machine.

---

## Common business questions answered (canonical answers)

**Q: What's the funnel order?**
A: cagd → gtg → catalogue_config → poc_intro → web_config → website_discussion → domain_transfer → meta_setup → price_parity_check → fund_transfer → qc_check → seller_consent. Then launch.

**Q: Who owns meta_setup / fund_transfer?**
A: Both are `ob_poc` tasks.

**Q: What's the 48hr policy?**
A: Post-Jul 1, POCs are required to wait 48 hours between completing `meta_setup` and `fund_transfer` for a seller. Purpose: prevent Meta from flagging seller ad accounts. Enforced via CRM auto-task-creation on tickets created ≥Jul 8 7:52 PM IST; pre-deploy tickets are on manual compliance.

**Q: What's the difference between milestones and tasks?**
A: Tasks are the 12 granular operational steps. Milestones are 5 coarse stages (document, catalogue, marketing, website, launch) tracked separately in `seller_journey_milestones`. A milestone is usually the "outcome" of one or more tasks completing.

**Q: How many tickets per seller usually?**
A: Almost always 1. Occasional edge cases have 2+ (re-onboarding, ticket recreation). Any analysis grouping by seller should account for possible duplicates.

**Q: Which POC is which team?**
A: See the POC table above.

**Q: Is a ticket with all tasks completed but no launch milestone launched?**
A: No. Launch is signaled by the `Launch` milestone being marked `completed` in `seller_journey_milestones`. Task completion is necessary but not sufficient.

**Q: What does "stuck" mean?**
A: A seller who completed task X but hasn't completed the next task Y after >N days, where N is more than the baseline distribution would suggest. For meta_setup → fund_transfer post-Jul 1, "stuck" is >7 days.

**Q: What does "funnel loss" vs "delay" mean?**
A: Funnel loss = seller likely to never complete the funnel (permanent revenue impact). Delay = seller will complete, just later than usual (timing shift only). Distinguishing these requires context: a truly-stuck seller past baseline is likely loss; a seller in an active queue is likely delay. See the RCA docs and Excel workbook in the outputs directory for the specific classification schema used.

**Q: What's the difference between churn and pause?**
A: Both are non-active seller states tracked via `churn_seller_callback` tasks. **Pause** is temporary — `disposition_reasons = 'seller_wants_to_pause'` on some task in the seller's history, with no later resume/continue on a subsequent task. Seller might unpause any day (funds arrive, personal issue resolves, product back in stock). **Churn** is permanent — `disposition_reasons = 'seller_wants_to_drop_out'` on any task ever, final drop-out. A third distinct state: a `churn_seller_callback` task with NULL or non-terminal disposition (like `seller_did_not_pickup`) with no later terminal event means the seller is IN the review process — they haven't committed either way. Never conflate these three in one number.

**Q: When did a seller start churning vs actually churn?**
A: Two different events on two different fields. Churn process **started** = `churn_seller_callback` task `created_at` (may still be undecided). Churn **confirmed** = same task's `updated_at` when `disposition_reasons = 'seller_wants_to_drop_out'` was applied. A seller can be "in churn process" for days before dropping out — or can be revived from that process with `seller_wants_to_continue` disposition and never actually churn.

**Q: Is `churn_seller_callback` in the 12 funnel tasks?**
A: No. It's a non-funnel lifecycle callback. Any query using the funnel `TASK_TYPES` list will miss it unless you explicitly add it. See "Seller lifecycle states" and Pattern 8.

---

## Style and voice for outputs

When Claude produces analytical documents from this domain:
- **Prose flow over bulleted sludge.** Novel-like narrative with data inline.
- **Every claim stress-tested.** For non-trivial findings, use the "But why this and not X?" pattern — state the alternative hypothesis explicitly and answer with data.
- **Provenance markers** for numbers — cite the query or filter that produced them.
- **Design tokens:** navy accent `#1F3864`, `Inter Tight` headings, `Inter` body, `JetBrains Mono` for IDs and code. Off-white background (`#FAFAF7`), not cream.
- **Claim honesty:** if Claude reversed a claim during the analysis, note the reversal explicitly. Silent corrections destroy trust.
- **Recommendations ranked by impact.** Don't dump a laundry list — top 3-5, in priority order.

For Excel:
- Arial font throughout (per xlsx skill requirement).
- Navy `#1F3864` header fill, white text.
- Color-code risk cells: critical `#B23A48`, high `#E85D75`, medium `#F4A261`, low `#FFE5B4`, none `#B7E4C7`.
- Freeze first row (and often first 2 columns).
- Include a Data Dictionary tab explaining every category and column.

---

## When to escalate to the human

Do not silently guess when any of these apply. Ask instead:
- The user's question could be interpreted 2+ ways at any of the seven canonical ambiguities, AND both interpretations yield materially different numbers.
- The user asks a business question whose answer isn't in this skill and Claude has no data source that would answer it.
- The query would touch tables not listed here (schema unknown; ask for schema before writing).
- The user asks about a task/milestone/POC type not in the enumerations above (either the data has drifted or this skill is stale — flag it).
- The user's stated business rule contradicts something in this skill (this skill may be outdated — confirm before proceeding).

---

## Related files in the workspace

- `/mnt/user-data/outputs/refresh_and_analytics_v7.gs` — canonical Apps Script for BQ → Sheets refresh with 11 analytical tabs. Extend this for new pipelines.
- `/mnt/user-data/outputs/rca_fund_transfer_analytical.html` — reference for how to write forensic analytical docs in this domain (challenge/answer pattern, provenance markers).
- `/mnt/user-data/outputs/rca_fund_transfer_leadership.html` — condensed leadership version of the same.
- `/mnt/user-data/outputs/rca_fund_transfer_sellers.xlsx` — reference for how to structure operational action-list Excels (categorized sellers, POC accountability, priority intervention tabs).

When creating similar deliverables, match the design tokens and structural patterns in these references.
