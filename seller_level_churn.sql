-- =============================================================================
-- Seller-level churn STATE model (one row per seller), evaluated "till date".
-- Status = Active / At risk / Churned (confirmed or abandoned).
-- -----------------------------------------------------------------------------
-- Definitions (confirmed with stakeholder):
--   QC passed     : type='qc_check' AND disposition='qc_completed_and_okay'
--                   (verified against ob_tasks); "completed the process";
--                   overrides any earlier drop signal.
--   completion    : QC passed (above) + go_live_date / gtg_date as extra markers
--   genuine activity : any task that is NOT a churn_seller_callback and NOT a
--                   drop disposition. (A churn call doesn't mean the seller is alive.)
--   dormant       : no genuine activity in the last 20 days (till today).
--
-- Status precedence:
--   1. Active   - completed/qualified (QC pass / go-live) after the latest drop
--   2. Churned  - confirmed: completed 'seller_wants_to_drop_out'
--   3. At risk  - drop/callback present AND a churn_seller_callback is still RUNNING
--                 (not yet a drop-out), or seller still recently active => savable
--   4. Churned  - abandoned: drop/callback present, nothing running, dormant (silent)
--   5. Active   - no drop signal at all
-- =============================================================================

WITH cohort_base AS (
    -- DOS source: Query 7100
    SELECT
        seller_id,
        DATE(dos)          AS dos,
        DATE(gtg_date)     AS gtg_date,
        DATE(a2h_date)     AS a2h_date,
        DATE(go_live_date) AS go_live_date
    FROM {{#7100-ob-cohort-query-v2}}
    WHERE dos IS NOT NULL
),

-- One pass over all of a seller's tasks (till date) to derive their current state.
seller_signals AS (
    SELECT
        seller_id,

        -- latest of ANY drop disposition
        MAX(IF(disposition IN ('seller_wants_to_drop_out','asked_to_drop_the_lead',
                               'not_in_shopdeck_criteria','photoshoot_not_available'),
               COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
               NULL))                                                       AS last_drop_date,

        -- confirmed churn: completed "seller_wants_to_drop_out"
        MAX(IF(disposition = 'seller_wants_to_drop_out' AND completed_at IS NOT NULL,
               DATE(completed_at,'Asia/Kolkata'), NULL))                    AS dropout_completed_date,

        -- soft drop only (at-risk / abandon candidate)
        MAX(IF(disposition IN ('asked_to_drop_the_lead','not_in_shopdeck_criteria',
                               'photoshoot_not_available'),
               COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
               NULL))                                                       AS last_soft_drop_date,

        -- QC passed = "completed the process" (overrides churn).
        -- Verified against real ob_tasks data: values are lowercase snake_case.
        MAX(IF(LOWER(type) = 'qc_check' AND LOWER(disposition) = 'qc_completed_and_okay',
               COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
               NULL))                                                       AS qc_completed_date,

        -- a churn callback was opened at all (regardless of disposition)
        MAX(IF(type = 'churn_seller_callback',
               COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
               NULL))                                                       AS last_churn_callback_date,

        -- last GENUINE activity: not a churn call, not a drop disposition (type IS checked)
        MAX(IF(type != 'churn_seller_callback'
                 AND (disposition IS NULL
                      OR disposition NOT IN ('seller_wants_to_drop_out','asked_to_drop_the_lead',
                                             'not_in_shopdeck_criteria','photoshoot_not_available')),
               DATE(created_at,'Asia/Kolkata'), NULL))                      AS last_active_task_date,

        -- a churn_seller_callback that is still RUNNING (open) and NOT yet concluded as a
        -- drop-out -> churn investigation in-flight => At risk, not abandoned.
        -- ASSUMPTION: "open" = completed_at IS NULL (swap for a status column if you have one).
        LOGICAL_OR(type = 'churn_seller_callback'
                   AND completed_at IS NULL
                   AND (disposition IS NULL OR disposition != 'seller_wants_to_drop_out'))
                                                                            AS has_open_churn_callback,

        STRING_AGG(DISTINCT IF(disposition IN ('seller_wants_to_drop_out','asked_to_drop_the_lead',
                                               'not_in_shopdeck_criteria','photoshoot_not_available'),
                               disposition, NULL), ', ')                    AS churn_reason
    FROM `blitzscale-prod-project.nushop.ob_tasks`
    WHERE created_at >= TIMESTAMP('2022-01-01')
      AND created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE('Asia/Kolkata'), INTERVAL 1 DAY))
    GROUP BY seller_id
),

seller_eval AS (
    SELECT
        cb.seller_id,
        cb.dos,
        FORMAT_DATE('%Y-%m', cb.dos)                AS sale_month,
        cb.gtg_date,
        cb.a2h_date,
        cb.go_live_date,

        s.last_drop_date,
        s.dropout_completed_date,
        s.last_soft_drop_date,
        s.qc_completed_date,
        s.last_churn_callback_date,
        s.has_open_churn_callback,
        s.last_active_task_date,
        s.churn_reason,

        -- positive/override = real completion or QC qualification
        (SELECT MAX(d) FROM UNNEST([cb.go_live_date, cb.gtg_date, s.qc_completed_date]) AS d)
                                                    AS last_positive_date,

        -- dormant = no genuine activity in the last 20 days (till today)
        (s.last_active_task_date IS NULL
         OR s.last_active_task_date < DATE_SUB(CURRENT_DATE('Asia/Kolkata'), INTERVAL 20 DAY))
                                                    AS is_dormant
    FROM cohort_base cb
    LEFT JOIN seller_signals s USING (seller_id)
),

seller_status AS (
    SELECT
        *,
        CASE
            -- 1. completed/qualified after the latest drop  -> retained
            WHEN last_positive_date IS NOT NULL
                 AND (last_drop_date           IS NULL OR last_positive_date >= last_drop_date)
                 AND (last_churn_callback_date IS NULL OR last_positive_date >= last_churn_callback_date)
                THEN 'Active'
            -- 2. confirmed drop-out  -> churned
            WHEN dropout_completed_date IS NOT NULL
                THEN 'Churned'
            -- 3. drop/callback present AND a churn callback is still RUNNING (not yet a
            --    drop-out), or the seller is still recently active -> at risk (savable)
            WHEN (last_soft_drop_date IS NOT NULL OR last_churn_callback_date IS NOT NULL)
                 AND (has_open_churn_callback OR NOT is_dormant)
                THEN 'At risk'
            -- 4. drop/callback present, nothing running, gone silent (dormant) -> churned (abandoned)
            WHEN (last_soft_drop_date IS NOT NULL OR last_churn_callback_date IS NOT NULL)
                THEN 'Churned'
            ELSE 'Active'
        END                                         AS churn_status
    FROM seller_eval
),

seller_final AS (
    SELECT
        *,
        IF(churn_status = 'Churned', 1, 0)          AS churn_flag,
        IF(churn_status = 'Churned',
           COALESCE(dropout_completed_date, last_soft_drop_date, last_churn_callback_date),
           NULL)                                    AS churn_date
    FROM seller_status
)

SELECT
    seller_id,
    dos,
    sale_month,
    gtg_date,
    a2h_date,
    go_live_date,

    churn_status,
    churn_flag,
    churn_reason,

    last_drop_date,
    last_positive_date,
    qc_completed_date,
    last_churn_callback_date,
    has_open_churn_callback,
    last_active_task_date,
    is_dormant,

    churn_date,
    FORMAT_DATE('%Y-%m', churn_date)                AS churn_month,
    IF(churn_flag = 1, DATE_DIFF(churn_date, dos, DAY), NULL) AS days_to_churn,

    CASE
        WHEN churn_flag = 0                                              THEN NULL
        WHEN DATE_DIFF(churn_date, dos, DAY) >= 0
             AND DATE_DIFF(churn_date, dos, DAY) < 7                     THEN '<7 days'
        WHEN DATE_DIFF(churn_date, dos, DAY) BETWEEN 7  AND 15           THEN '7-15 days'
        WHEN DATE_DIFF(churn_date, dos, DAY) BETWEEN 16 AND 21           THEN '16-21 days'
        WHEN DATE_DIFF(churn_date, dos, DAY) < 0                         THEN 'pre-DOS churn'
        WHEN DATE_DIFF(churn_date, dos, DAY) > 21                        THEN '>21 days'
        ELSE NULL
    END                                             AS churn_bucket

FROM seller_final
WHERE dos >= DATE '2026-01-01'
  AND dos <  DATE '2026-07-01'
ORDER BY dos, seller_id;
