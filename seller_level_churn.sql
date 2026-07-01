-- =============================================================================
-- Seller-level churn STATE model (one row per seller), evaluated "till date".
-- Status = Active / Paused / At risk / Churned (confirmed or abandoned).
-- All type/disposition strings VERIFIED against ob_tasks vocabulary.
-- -----------------------------------------------------------------------------
-- Vocabulary (verified):
--   Soft drop (any task type) : asked_to_drop_the_lead, not_in_shopdeck_criteria,
--                               photoshoot_not_available
--   Confirmed drop (any type) : seller_wants_to_drop_out
--   QC passed                 : type='qc_check' AND disposition='qc_completed_and_okay'
--   Retention (churn callback): seller_wants_to_continue, seller_resumed  -> rescue to Active
--   In-flight callback        : churn_seller_callback with disposition NULL /
--                               seller_did_not_pick_up_the_call / seller_wants_to_call_later /
--                               schedule_account_health_call / seller_wants_to_pause
--   Completion markers        : go_live_date / gtg_date (from cohort) + QC pass + retention
--   Genuine activity          : any task that is NOT a churn_seller_callback and NOT a drop
--   Dormant                   : no genuine activity in the last 20 days (till today)
--
-- Status precedence:
--   1. Active   - a positive signal (QC pass / go-live / gtg / seller_wants_to_continue /
--                 seller_resumed) is dated on/after the latest drop and latest pause
--   2. Churned  - confirmed: seller_wants_to_drop_out is the latest churn signal
--   3. Paused   - seller_wants_to_pause (any type) is the latest churn signal
--   4. At risk  - drop/callback present AND (a churn callback is recently in-flight OR
--                 the seller is still recently active) => savable
--   5. Churned  - abandoned: drop/callback present, nothing running, dormant (silent)
--   6. Active   - no drop / callback signal at all
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

        -- latest of ANY drop disposition (soft + confirmed), across all task types
        MAX(IF(disposition IN ('seller_wants_to_drop_out','asked_to_drop_the_lead',
                               'not_in_shopdeck_criteria','photoshoot_not_available'),
               COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
               NULL))                                                       AS last_drop_date,

        -- confirmed churn: seller_wants_to_drop_out (any task type)
        MAX(IF(disposition = 'seller_wants_to_drop_out',
               COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
               NULL))                                                       AS dropout_date,

        -- soft drop only (at-risk / abandon candidate)
        MAX(IF(disposition IN ('asked_to_drop_the_lead','not_in_shopdeck_criteria',
                               'photoshoot_not_available'),
               COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
               NULL))                                                       AS last_soft_drop_date,

        -- QC passed = "completed the process" (verified strings, lowercase snake_case)
        MAX(IF(LOWER(type) = 'qc_check' AND LOWER(disposition) = 'qc_completed_and_okay',
               COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
               NULL))                                                       AS qc_completed_date,

        -- retention: seller explicitly stayed on a churn callback -> rescues to Active
        MAX(IF(type = 'churn_seller_callback'
                 AND disposition IN ('seller_wants_to_continue','seller_resumed'),
               COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
               NULL))                                                       AS last_retained_date,

        -- pause: seller_wants_to_pause on ANY task type -> its own "Paused" state
        MAX(IF(disposition = 'seller_wants_to_pause',
               COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
               NULL))                                                       AS last_pause_date,

        -- any churn callback opened at all
        MAX(IF(type = 'churn_seller_callback',
               COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
               NULL))                                                       AS last_churn_callback_date,

        -- a churn callback that is RECENTLY in-flight (unresolved) => actively being worked
        LOGICAL_OR(type = 'churn_seller_callback'
                   AND (disposition IS NULL
                        OR disposition IN ('seller_did_not_pick_up_the_call',
                                           'seller_wants_to_call_later',
                                           'schedule_account_health_call'))
                   AND COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata'))
                       >= DATE_SUB(CURRENT_DATE('Asia/Kolkata'), INTERVAL 20 DAY))
                                                                            AS has_recent_inflight_cb,

        -- last GENUINE activity: not a churn call, not a drop disposition
        MAX(IF(type != 'churn_seller_callback'
                 AND (disposition IS NULL
                      OR disposition NOT IN ('seller_wants_to_drop_out','asked_to_drop_the_lead',
                                             'not_in_shopdeck_criteria','photoshoot_not_available')),
               DATE(created_at,'Asia/Kolkata'), NULL))                      AS last_active_task_date,

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
        s.dropout_date,
        s.last_soft_drop_date,
        s.qc_completed_date,
        s.last_retained_date,
        s.last_pause_date,
        s.last_churn_callback_date,
        s.has_recent_inflight_cb,
        s.last_active_task_date,
        s.churn_reason,

        -- positive = completion (QC/go-live/gtg) or explicit retention (continue/resumed)
        (SELECT MAX(d) FROM UNNEST([cb.go_live_date, cb.gtg_date,
                                    s.qc_completed_date, s.last_retained_date]) AS d)
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
            -- 1. positive/retention is the latest signal -> Active
            WHEN last_positive_date IS NOT NULL
                 AND (last_drop_date  IS NULL OR last_positive_date >= last_drop_date)
                 AND (last_pause_date IS NULL OR last_positive_date >= last_pause_date)
                THEN 'Active'
            -- 2. confirmed drop-out is the latest churn signal -> churned
            WHEN dropout_date IS NOT NULL
                 AND (last_pause_date IS NULL OR dropout_date >= last_pause_date)
                THEN 'Churned'
            -- 3. seller_wants_to_pause is the latest churn signal -> paused
            WHEN last_pause_date IS NOT NULL
                 AND (last_drop_date IS NULL OR last_pause_date >= last_drop_date)
                THEN 'Paused'
            -- 4. drop/callback present AND (recently in-flight callback OR still active) -> at risk
            WHEN (last_soft_drop_date IS NOT NULL OR last_churn_callback_date IS NOT NULL)
                 AND (has_recent_inflight_cb OR NOT is_dormant)
                THEN 'At risk'
            -- 5. drop/callback present, nothing running, dormant (silent) -> churned (abandoned)
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
        IF(churn_status = 'Paused',  1, 0)          AS is_paused,
        IF(churn_status = 'Churned',
           COALESCE(dropout_date, last_soft_drop_date, last_churn_callback_date),
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
    is_paused,
    churn_reason,

    last_drop_date,
    dropout_date,
    last_positive_date,
    qc_completed_date,
    last_retained_date,
    last_pause_date,
    last_churn_callback_date,
    has_recent_inflight_cb,
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
