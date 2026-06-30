-- =============================================================================
-- Seller-level churn STATE model (one row per seller), evaluated "till date".
-- Status = Active / At risk / Churned, with churn split into confirmed vs abandoned.
-- -----------------------------------------------------------------------------
-- CONFIRM these 4 assumptions (search for "CONFIRM"):
--   #1 QC completion  : type = 'qc'  AND disposition = 'qc_completed'
--   #2 running task    : completed_at IS NULL, excluding churn_seller_callback rows
--   #3 dormancy window : no activity in the last 21 days (till today)
--   #4 completion cols : go_live_date / gtg_date  (+ QC completed)
--
-- Resolves:
--   69da417b  drop-out w/ no completion -> Churned (was wrongly blank: a neutral
--             same-day task used to count as "positive" - removed that rule).
--   6968df90  not_in_criteria BUT QC completed         -> Active  (QC overrides)
--   6968e334  not_in_criteria BUT QC completed         -> Active
--   6968d391  open churn callback, no running tasks,    -> Churned (abandoned)
--             not_in_criteria, no recent activity
--   6968e111  asked_to_drop + final callback, no        -> Churned (abandoned)
--             running tasks after (till date)
--   677d2156  asked_to_drop but still has running tasks -> At risk
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

        -- soft drop only (the "at risk" / abandon-candidate signals)
        MAX(IF(disposition IN ('asked_to_drop_the_lead','not_in_shopdeck_criteria',
                               'photoshoot_not_available'),
               COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
               NULL))                                                       AS last_soft_drop_date,

        -- CONFIRM #1: QC completion overrides churn
        MAX(IF(LOWER(type) = 'qc' AND LOWER(disposition) = 'qc_completed',
               COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
               NULL))                                                       AS qc_completed_date,

        -- a churn callback was opened at all (regardless of disposition)
        MAX(IF(type = 'churn_seller_callback',
               COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
               NULL))                                                       AS last_churn_callback_date,

        -- CONFIRM #2: running/open operational task (churn callbacks excluded)
        COUNTIF(completed_at IS NULL AND type != 'churn_seller_callback')   AS open_tasks,

        -- last activity of any kind (for dormancy)
        MAX(DATE(created_at,'Asia/Kolkata'))                                AS last_task_date,

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
        s.open_tasks,
        s.last_task_date,
        s.churn_reason,

        -- positive/override = real completion or qualification (CONFIRM #4 + QC)
        (SELECT MAX(d) FROM UNNEST([cb.go_live_date, cb.gtg_date, s.qc_completed_date]) AS d)
                                                    AS last_positive_date,

        -- CONFIRM #2 & #3: dormant = no running task AND no recent activity (till date)
        (COALESCE(s.open_tasks, 0) = 0
         AND s.last_task_date < DATE_SUB(CURRENT_DATE('Asia/Kolkata'), INTERVAL 21 DAY))
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
            -- 3. soft drop or open churn callback, and gone dormant  -> churned (abandoned)
            WHEN (last_soft_drop_date IS NOT NULL OR last_churn_callback_date IS NOT NULL)
                 AND is_dormant
                THEN 'Churned'
            -- 4. soft drop / open callback but still active  -> at risk
            WHEN (last_soft_drop_date IS NOT NULL OR last_churn_callback_date IS NOT NULL)
                THEN 'At risk'
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
    open_tasks,
    last_task_date,
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
