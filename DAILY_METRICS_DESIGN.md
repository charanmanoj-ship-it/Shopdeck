# Daily Metrics — Top-of-Funnel (Connect → GTG / NGTG)

Design conclusion, 2026-07-18. Turns the Feb/March NGTG churn retro
(`NGTG_Drop_Reasons_Feb_March.xlsx`) into a daily operating instrument.

---

## 1. First principles: what a daily metric is *for*

ShopDeck earns commission only on delivered orders, so revenue is created only
when a seller **launches**. Launch lags ticket creation by weeks — useless as a
daily signal. A daily metric therefore cannot be an *outcome* metric; it must be
a **leading** one, and it must do two jobs every morning:

1. **Detect** degradation within ~1 day (not after a cohort matures).
2. **Produce a same-day action list** — who to chase, which reason is spiking,
   which POC is behind.

Anything that doesn't change what someone does *tomorrow* is a report, not a
daily metric. The monthly xlsx is the report. This is the instrument.

## 2. Why the top gate is the right place for the daily lens

The screenshot puts the daily lens on the very first gate (Connect → GTG). That
is the correct choice, for three first-principles reasons:

- **It's the fastest gate.** GTG resolves in hours-to-days, so a creation-day
  cohort is observable the *next* day. Downstream tasks take weeks — you can't
  run a daily cohort on them.
- **It's the highest-leverage leak.** A lead that never reaches GTG can never
  launch — 100% of downstream depends on this gate. Feb→March lost **219→288
  sellers/month** here, ~25-30% of inflow, *before the 12-task funnel even
  starts.*
- **Its reasons are owner-attributable.** Docs → CAGD/ob_poc; no-show → calling
  cadence; paused → nurture. Each bucket has a different owner and a different
  fix.

## 3. The classification tree (MECE — every lead lands in exactly one bucket)

```
Lead created (day D)
├── GTG reached?  (ob_tasks type='gtg' completed)
│   ├── YES → GTG / "Good"                                    ← grow this
│   └── NO  → NGTG — classify why:
│       ├── Never connected (no CONNECTED call)   → No-show / RNR      [calling team]
│       ├── Connected, docs/KYC missing           → Docs blocked       [CAGD + seller]
│       ├── Connected, out of ShopDeck criteria   → Out of criteria    [sales quality]
│       ├── Connected, qualified, seller-deferred  → Paused / not ready [nurture]
│       └── Not resolved yet, none of the above   → In progress        [too new — DO NOT count as churn]
```

The last bucket is where the discipline lives: **a lead created today is mostly
"in progress," not NGTG.** Counting a fresh cohort's unresolved leads as churn is
the cohort-maturity trap — a fresh cohort's NGTG% is artificially high the same
way a fresh cohort's conversion% is artificially low.

Reason buckets are reused verbatim from the existing `Drop Reason Buckets` tab so
the daily metric is continuous with the monthly retro. Your a/b/c map cleanly:
`(a) no doc = No GST/license`, `(b) no show = No contact/RNR`, `(c) pause = stock
not ready + refund + out-of-criteria + generic`.

## 4. The two views (they answer different questions — keep them separate)

### View 1 — Cohort health (leading indicator, maturity-gated)
- Rows = last ~14 **creation-day** cohorts.
- Per cohort: size, **GTG-within-Xh %**, NGTG %, NGTG reason split.
- Cohorts younger than X are **not settled** — flag today/yesterday `(in progress)`.
- Compare GTG% to an **Expected / target** line (the "Exp" in the screenshot) =
  trailing median of *settled* cohorts. Green ≥ target, red below.
- Answers: *"Is the top of the funnel healthy today vs normal?"*

### View 2 — Today's flow + open queue (the action list, not a rate)
- GTGs completed today, NGTGs dispositioned today (throughput — what the team did).
- **Open queue**: every not-yet-resolved lead, bucketed by reason and **age**,
  oldest first — the literal chase-list (`no-show >48h`, `docs pending >72h`).
- Answers: *"Who do we act on today, and is anything piling up?"*

### The two headline numbers
1. **Rolling 48h GTG rate vs target** (health).
2. **Open actionable NGTG count by reason** (work).

## 5. Fix the instrument before trusting the readout

In March, **"No reason logged (blank remarks)" was the single largest bucket —
75/288 = 26%.** A daily metric cannot act on a blank reason. So the daily view
must also carry a **data-quality KPI: % of NGTG with no logged reason.** If a
quarter of churn is unexplained, the diagnosis is blind — capture must be fixed
first. Reasons today come from free-text remarks (keyword-bucketed, per the
"read both remarks columns" work), not a clean enum; the blank-reason KPI is the
guardrail against trusting a fuzzy signal.

## 6. Open decisions (defaults chosen; both verifiable with one query)

- **Settle horizon X = 48h** (default). Matches existing org "48hr" language.
  Verify against the actual gtg-completion-time distribution; drop to 24h if GTG
  is typically same-day.
- **Reason source** = free-text remarks (assumed). If a structured disposition
  field now exists, the blank-reason KPI becomes less critical. Confirm before build.

## 7. Build path

Extend the canonical Apps Script (`refresh_and_analytics_v7.gs`) with two tabs —
`Daily Cohort Health` and `Daily Open Queue` — matching its CTE/style conventions.
Cohort maturity gated per the skill's rule (`days_since_cohort_end`, daily W=1 so
offset 0). Not a new pipeline; a new tab on the existing one.
