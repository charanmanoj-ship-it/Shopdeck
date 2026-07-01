# Seller Churn Logic — Definitions & Assumptions

Companion doc for **`seller_level_churn.sql`**. Captures every rule and assumption
we agreed on while debugging the original monthly-churn query, so the logic is
auditable and easy to hand off.

- **Grain:** one row per `seller_id`.
- **Cohort window:** `dos` (date of sale) in `2026-01-01 .. 2026-06-30`.
- **Evaluation time:** "till date" — a seller's state is derived from *all* their
  OB tasks up to today (`CURRENT_DATE('Asia/Kolkata')`).

---

## 1. Data sources

| Source | Used for |
|--------|----------|
| `{{#7100-ob-cohort-query-v2}}` (Metabase card 7100) | `dos`, `gtg_date`, `a2h_date`, `go_live_date` — one row per seller |
| `blitzscale-prod-project.nushop.ob_tasks` | all task events: `type`, `disposition`, `created_at`, `completed_at` |

Task scan window: `created_at` from `2022-01-01` up to **tomorrow** (so today's
tasks are included).

---

## 2. Key concepts

### Drop dispositions
A task disposition that signals the seller may leave:
- `seller_wants_to_drop_out`  ← the only **confirmed** drop
- `asked_to_drop_the_lead`    ← soft drop
- `not_in_shopdeck_criteria`  ← soft drop
- `photoshoot_not_available`  ← soft drop

### QC passed = "completed the process"  *(overrides churn)*
Matched (case-insensitive) on the **verified** value-pair:
- `type = 'qc_check'` AND `disposition = 'qc_completed_and_okay'`

> ✅ **VERIFIED** against real `ob_tasks` rows for seller `6954ed68…`. Note: all
> `type` / `disposition` values in this table are **lowercase `snake_case`** — the
> earlier guesses (`QC_type` / `QC COMPLETED AND OKAY`) never matched, which is why
> that seller's QC date wasn't picked up. If there are *other* passing QC
> dispositions (e.g. a plain `qc_completed`), add them here.

### Completion / positive signal
`last_positive_date` = the latest of: **QC passed date**, `go_live_date`,
`gtg_date`. A positive signal dated **on/after** the latest drop rescues the
seller to **Active** (a drop that happened *after* going live still churns).

### Genuine activity
Any task that is **NOT** a `churn_seller_callback` **and NOT** a drop disposition.
(A churn call does not mean the seller is alive.) `last_active_task_date` = latest
such task's `created_at`.

### Dormant
`is_dormant = TRUE` when there is **no genuine activity in the last 20 days**
(or none ever). Means the seller has gone silent.

### Open / running churn callback
`has_open_churn_callback = TRUE` when a `churn_seller_callback` task is still
**open** and **not yet** concluded as `seller_wants_to_drop_out`.
> **ASSUMPTION:** "open" = `completed_at IS NULL`. If open/closed is tracked by a
> dedicated status column instead, that column should be used here.
> **DATA CAVEAT:** in the sample rows, `completed_at` is *chained* — a task's
> `completed_at` equals the next task's `created_at` (it's a state-transition log),
> and some superseded rows keep `completed_at = NULL` even though they're stale
> (e.g. duplicate `website_reconfig` `in_progress` rows). So `completed_at IS NULL`
> can over-count "open". Needs a real `churn_seller_callback` example to confirm the
> open-callback test doesn't over-trigger At-risk.

---

## 3. Status model (precedence — first match wins)

| # | Status | Condition |
|---|--------|-----------|
| 1 | **Active** | A positive/QC-completion signal is dated on/after the latest drop and latest callback → retained / qualified |
| 2 | **Churned** *(confirmed)* | Completed `seller_wants_to_drop_out` exists |
| 3 | **At risk** | A drop/callback exists **AND** (a churn callback is still running **OR** the seller is still recently active) → churn process in-flight, savable |
| 4 | **Churned** *(abandoned)* | A drop/callback exists, nothing running, seller is dormant (silent) |
| 5 | **Active** | No drop signal at all |

`churn_flag = 1` only when `churn_status = 'Churned'`.

---

## 4. Churn date & buckets

- `churn_date` (only when Churned) = `COALESCE(dropout_completed_date,
  last_soft_drop_date, last_churn_callback_date)`.
- `days_to_churn = DATE_DIFF(churn_date, dos, DAY)`.
- `churn_bucket` (days since sale):
  `<7 days` | `7-15 days` | `16-21 days` | `>21 days` | `pre-DOS churn` (negative).

---

## 5. Worked examples (how each flagged seller resolves)

| Seller | Situation | Result | Driver |
|--------|-----------|--------|--------|
| `69cb7fb…` | callback raised, "wants to continue" | not churned | only a real drop disposition counts (callback type alone removed) |
| `69538a2…`, `695799e…` | soft drop but later completed | Active | positive signal dated after the drop |
| `69da417b…` | drop-out completed, no completion | Churned | confirmed drop-out (fixed earlier same-day tie bug) |
| `6968df90…`, `6968e334…` | `not_in_criteria` but QC passed | Active | QC override |
| `677d2156…` | `asked_to_drop` + callback still running | At risk | `has_open_churn_callback = TRUE` |
| `6968e111…` | `asked_to_drop`, final callback closed, silent | Churned | abandoned (dormant, nothing running) |
| `6968d391…` | callback opened but not running, no recent tasks | Churned | abandoned |

---

## 6. Open items to confirm

1. ✅ **QC strings** — RESOLVED: `type='qc_check'`, `disposition='qc_completed_and_okay'`.
2. **Open callback** — is `completed_at IS NULL` the right "still running" test? (See data caveat: `completed_at` is chained; may over-count open. Needs a churn-callback example.)
3. **Dormancy window** — 20 days (we settled on 20/21).
4. **Completion columns** — `go_live_date` + `gtg_date` kept as extra completion markers alongside QC pass.
5. **Other vocabulary** — verify the exact strings for `seller_wants_to_drop_out`, `not_in_shopdeck_criteria`, `photoshoot_not_available`, and `churn_seller_callback` against the real distinct values (all lowercase snake_case). `asked_to_drop_the_lead` is confirmed present.

---

## 7. Not yet built (original ask)

The very first request was a **monthly cohort churn-% rollup** (M0 / M1 / M2,
with M0 day-buckets) by `sale_month`. The current deliverable is the
**seller-level** detail that feeds it. The monthly rollup can be layered on top of
`churn_status` / `churn_date` once the seller-level logic is signed off.

- **M0 / M1 / M2** intended as **30-day windows** from `dos`
  (M0 = 0–30, M1 = 31–60, M2 = 61–90), not calendar months.
