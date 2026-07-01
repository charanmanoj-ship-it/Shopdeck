-- =============================================================================
-- Seller-level churn STATE model (one row per seller), evaluated "till date".
-- Status = Live account / Active / Paused / At risk / Churned (confirmed|abandoned).
-- All type/disposition strings VERIFIED against ob_tasks vocabulary.
-- -----------------------------------------------------------------------------
-- Vocabulary (verified):
--   Soft drop (any task type) : asked_to_drop_the_lead, not_in_shopdeck_criteria,
--                               photoshoot_not_available
--   Confirmed drop (any type) : seller_wants_to_drop_out
--   Pause (any type)          : seller_wants_to_pause
--   QC passed                 : type='qc_check' AND disposition='qc_completed_and_okay'
--   Retention (churn callback): seller_wants_to_continue, seller_resumed
--   In-flight callback        : churn_seller_callback with disposition NULL /
--                               seller_did_not_pick_up_the_call / seller_wants_to_call_later /
--                               schedule_account_health_call
--   Genuine activity          : real onboarding tasks -- EXCLUDES churn_seller_callback
--                               AND the generic `callback` (a customer ask, not progress)
--                               AND drop dispositions.
--   Dormant                   : no genuine activity in the last 20 days (till today)
--
-- Status precedence (first match wins):
--   1. Live account - completed/qualified: QC passed OR go_live, on/after latest drop & pause
--   2. Active       - explicitly retained (continue/resumed) on/after latest drop & pause
--   3. Churned      - confirmed: seller_wants_to_drop_out is the latest churn signal
--   4. Paused       - seller_wants_to_pause is the latest churn signal
--   5. At risk      - drop/callback present AND (recent in-flight callback OR still active)
--   6. Churned      - abandoned: drop/callback present, nothing running, dormant
--   7. Active       - no churn signal at all (brand-new / mid-onboarding)
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

        -- pause: seller_wants_to_pause on ANY task type -> its own "Paused" state
        MAX(IF(disposition = 'seller_wants_to_pause',
               COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
               NULL))                                                       AS last_pause_date,

        -- QC passed (verified strings, lowercase snake_case) -> completion
        MAX(IF(LOWER(type) = 'qc_check' AND LOWER(disposition) = 'qc_completed_and_okay',
               COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
               NULL))                                                       AS qc_completed_date,

        -- retention: seller explicitly stayed on a churn callback -> rescues to Active
        MAX(IF(type = 'churn_seller_callback'
                 AND disposition IN ('seller_wants_to_continue','seller_resumed'),
               COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
               NULL))                                                       AS last_retained_date,

        -- any churn callback opened at all
        MAX(IF(type = 'churn_seller_callback',
               COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata')),
               NULL))                                                       AS last_churn_callback_date,

        -- a churn callback RECENTLY in-flight (unresolved) => actively being worked
        LOGICAL_OR(type = 'churn_seller_callback'
                   AND (disposition IS NULL
                        OR disposition IN ('seller_did_not_pick_up_the_call',
                                           'seller_wants_to_call_later',
                                           'schedule_account_health_call'))
                   AND COALESCE(DATE(completed_at,'Asia/Kolkata'), DATE(created_at,'Asia/Kolkata'))
                       >= DATE_SUB(CURRENT_DATE('Asia/Kolkata'), INTERVAL 20 DAY))
                                                                            AS has_recent_inflight_cb,

        -- last GENUINE onboarding activity: excludes churn callbacks, generic `callback`
        -- (a customer ask, not progress), and drop dispositions.
        MAX(IF(type NOT IN ('churn_seller_callback','callback')
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
        s.last_pause_date,
        s.qc_completed_date,
        s.last_retained_date,
        s.last_churn_callback_date,
        s.has_recent_inflight_cb,
        s.last_active_task_date,
        s.churn_reason,

        -- completion = went live OR QC passed  (=> Live account)
        (SELECT MAX(d) FROM UNNEST([cb.go_live_date, s.qc_completed_date]) AS d)
                                                    AS completion_date,

        -- dormant = no genuine onboarding activity in the last 20 days (till today)
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
            -- 1. completed/qualified (QC pass or went live) as latest state -> Live account
            WHEN completion_date IS NOT NULL
                 AND (last_drop_date  IS NULL OR completion_date >= last_drop_date)
                 AND (last_pause_date IS NULL OR completion_date >= last_pause_date)
                THEN 'Live account'
            -- 2. explicitly retained (continue/resumed) as latest state -> Active
            WHEN last_retained_date IS NOT NULL
                 AND (last_drop_date  IS NULL OR last_retained_date >= last_drop_date)
                 AND (last_pause_date IS NULL OR last_retained_date >= last_pause_date)
                THEN 'Active'
            -- 3. confirmed drop-out is the latest churn signal -> Churned
            WHEN dropout_date IS NOT NULL
                 AND (last_pause_date IS NULL OR dropout_date >= last_pause_date)
                THEN 'Churned'
            -- 4. seller_wants_to_pause is the latest churn signal -> Paused
            WHEN last_pause_date IS NOT NULL
                 AND (last_drop_date IS NULL OR last_pause_date >= last_drop_date)
                THEN 'Paused'
            -- 5. drop/callback present AND (recent in-flight callback OR still active) -> At risk
            WHEN (last_soft_drop_date IS NOT NULL OR last_churn_callback_date IS NOT NULL)
                 AND (has_recent_inflight_cb OR NOT is_dormant)
                THEN 'At risk'
            -- 6. drop/callback present, nothing running, dormant (silent) -> Churned (abandoned)
            WHEN (last_soft_drop_date IS NOT NULL OR last_churn_callback_date IS NOT NULL)
                THEN 'Churned'
            -- 7. no churn signal at all -> Active (brand-new / mid-onboarding)
            ELSE 'Active'
        END                                         AS churn_status
    FROM seller_eval
),

seller_final AS (
    SELECT
        *,
        IF(churn_status = 'Churned',      1, 0)     AS churn_flag,
        IF(churn_status = 'Paused',       1, 0)     AS is_paused,
        IF(churn_status = 'Live account', 1, 0)     AS is_live_account,
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
    is_live_account,
    churn_reason,

    last_drop_date,
    dropout_date,
    last_pause_date,
    completion_date,
    qc_completed_date,
    last_retained_date,
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
