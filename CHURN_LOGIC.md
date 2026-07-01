# Seller Churn Logic — Definitions & Assumptions

Companion doc for **`seller_level_churn.sql`**. All `type` / `disposition` strings
below are **verified** against the real `ob_tasks` vocabulary (all lowercase
`snake_case`).

- **Grain:** one row per `seller_id`.
- **Cohort window:** `dos` (date of sale) in `2026-01-01 .. 2026-06-30`.
- **Evaluation time:** "till date" — state derived from *all* the seller's OB tasks
  up to today (`CURRENT_DATE('Asia/Kolkata')`).

---

## 1. Data sources

| Source | Used for |
|--------|----------|
| `{{#7100-ob-cohort-query-v2}}` (Metabase card 7100) | `dos`, `gtg_date`, `a2h_date`, `go_live_date` — one row per seller |
| `blitzscale-prod-project.nushop.ob_tasks` | all task events: `type`, `disposition`, `created_at`, `completed_at` |

---

## 2. Verified vocabulary

### Drop dispositions (appear across MANY task types)
- `seller_wants_to_drop_out` — **confirmed** drop (seen on `churn_seller_callback`, `fund_transfer`, `seller_consent`)
- `asked_to_drop_the_lead` — soft drop
- `not_in_shopdeck_criteria` — soft drop
- `photoshoot_not_available` — soft drop

### QC passed = "completed the process" *(overrides churn)*
- `type = 'qc_check'` AND `disposition = 'qc_completed_and_okay'`
- (Ignore `qc_check` / `issues_found` and `qc_check` / null — a failed or pending QC does **not** rescue.)

### `churn_seller_callback` dispositions
| Disposition | Meaning | Handling |
|-------------|---------|----------|
| `seller_wants_to_drop_out` | confirmed churn | **Churned** |
| `seller_wants_to_continue` | staying | **Retention → rescues to Active** |
| `seller_resumed` | came back | **Retention → rescues to Active** |
| `seller_wants_to_pause` | paused | **Paused** — its own status + `is_paused` column (matched on ANY task type) |
| `` (null) | opened, unworked | in-flight → At risk if recent |
| `seller_did_not_pick_up_the_call` | trying to reach | in-flight → At risk if recent |
| `seller_wants_to_call_later` | in-flight | in-flight → At risk if recent |
| `schedule_account_health_call` | in-flight | in-flight → At risk if recent |

---

## 3. Derived concepts

- **`completion_date`** — latest of `go_live_date` and QC-pass date. This is what
  makes a **Live account** (`gtg_date` is *not* completion — it's mid-onboarding).
- **Retention** — `seller_wants_to_continue` / `seller_resumed`. Rescues a seller
  (who had an earlier drop) to **Active**, but does not make them Live.
- **Genuine activity** — real onboarding tasks. EXCLUDES `churn_seller_callback`,
  the generic `callback` (a customer ask, not progress), and drop dispositions.
  `last_active_task_date` = latest such task.
- **Dormant** — `is_dormant = TRUE` when no genuine activity in the last 20 days.
- **Recently in-flight callback** — `has_recent_inflight_cb = TRUE` when a
  `churn_seller_callback` with an *unresolved* disposition (null / did-not-pick-up /
  call-later / schedule-health-call / pause) occurred in the last 20 days. This is
  now defined by **disposition**, not `completed_at` — which sidesteps the earlier
  `completed_at`-chaining problem (a task's `completed_at` = the next task's
  `created_at`, so `completed_at IS NULL` was unreliable).

---

## 4. Status model (precedence — first match wins)

| # | Status | Condition |
|---|--------|-----------|
| 1 | **Live account** | Completed/qualified — QC passed **or** went live — on/after the latest drop & pause |
| 2 | **Active** | Explicitly retained (`continue` / `resumed`) on/after the latest drop & pause |
| 3 | **Churned** *(confirmed)* | `seller_wants_to_drop_out` is the latest churn signal |
| 4 | **Paused** | `seller_wants_to_pause` (any task type) is the latest churn signal |
| 5 | **At risk** | A drop/callback exists AND (a churn callback is recently in-flight OR the seller is still recently active) → savable |
| 6 | **Churned** *(abandoned)* | A drop/callback exists, nothing running, seller is dormant (silent) |
| 7 | **Dormant** | No explicit churn signal, but no genuine activity in ≥20 days (stalled / went silent) |
| 8 | **Active** | Recent onboarding activity, no churn signal (brand-new / mid-onboarding) |

**Dormant vs Active vs Churned(abandoned):** *Active* = progressing recently. *Dormant* = silent ≥20d but never flagged (no drop, no churn callback). *Churned (abandoned)* = silent **and** had a drop/callback signal.

**Live account vs Active:** *Live account* = genuinely completed (QC pass / go-live).
*Active* = no churn signal (new / mid-onboarding) or explicitly retained but not yet live.
Output flags: `is_live_account`, `is_paused`, `churn_flag`.

`churn_flag = 1` only when `churn_status = 'Churned'`.

---

## 5. Churn date & buckets

- `churn_date` (only when Churned) = `COALESCE(dropout_date, last_soft_drop_date, last_churn_callback_date)`.
- `days_to_churn = DATE_DIFF(churn_date, dos, DAY)`.
- `churn_bucket`: `<7 days` | `7-15 days` | `16-21 days` | `>21 days` | `pre-DOS churn`.

---

## 6. Worked examples

| Seller | Situation | Result | Driver |
|--------|-----------|--------|--------|
| `6954ed68…` | soft drop (Feb/Mar), then full onboarding + QC pass (Jun) | **Live account** | QC pass dated after the drop |
| `69cb7fb…` | churn callback → `seller_wants_to_continue` | **Active** | retention rescue (not yet live) |
| `69da417b…` | `seller_wants_to_drop_out`, no completion | **Churned** | confirmed drop-out |
| `6968df90…`, `6968e334…` | `not_in_criteria` but QC passed | **Live account** | QC completion overrides |
| `677d2156…` | `asked_to_drop` + callback recently in-flight | **At risk** | `has_recent_inflight_cb` |
| `6968e111…` | `asked_to_drop`, final callback closed, silent | **Churned** | abandoned |
| `6968d391…` | callback opened but stale, no recent tasks | **Churned** | abandoned |
| `69592bef…` | no drop / no callback ever, silent since 12-Mar | **Dormant** | `is_dormant` with no churn signal |

---

## 7. Confirmed business decisions

1. **`seller_wants_to_continue` / `seller_resumed` rescue to Active** (positive/retention).
2. **`seller_wants_to_pause` (any task type) → its own `Paused` status** + `is_paused` column.
3. **Churn callbacks are targeted, not routine** — opened only for non-responsive sellers (after N attempts) or when POC marks want-to-leave / not-in-criteria. So a `churn_seller_callback`'s existence is a valid churn-risk signal and is kept as a trigger.
4. **Live account vs Active split** — completed/qualified (QC pass or go-live) = **Live account**; no churn signal / mid-onboarding = **Active**. `gtg_date` is NOT treated as completion.
5. **Generic `callback` type = customer ask, not progress** — excluded from "genuine activity" (dormancy). Main onboarding tasks (`cagd`, `poc_intro`, `website_discussion`/`web_config`, `catalogue_config`, `meta_setup`, `fund_transfer`, …) count.

---

## 8. Remaining open items

1. **Open-callback recency** — "recently in-flight" uses a 20-day window; confirm 20 is right.
2. **Completion columns** — `go_live_date` + `gtg_date` kept alongside QC pass + retention.
3. Everything else (QC strings, drop-disposition strings) is now **verified**.

---

## 9. Not yet built (original ask)

The first request was a **monthly cohort churn-% rollup** (M0 / M1 / M2, with M0
day-buckets) by `sale_month`. Current deliverable is the **seller-level** detail
that feeds it; the rollup layers on top of `churn_status` / `churn_date` once
seller-level logic is signed off.

- **M0 / M1 / M2** intended as **30-day windows** from `dos`
  (M0 = 0–30, M1 = 31–60, M2 = 61–90), not calendar months.
