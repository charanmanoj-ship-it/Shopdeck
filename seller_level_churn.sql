-- =============================================================================
-- Seller-level churn (one row per seller) with false-positive fixes
-- -----------------------------------------------------------------------------
-- Fixes vs. the original:
--   ISSUE 3  A churn_seller_callback was counted even when the seller wanted to
--            continue.  Fix: require a real DROP disposition (removed the
--            standalone `type = 'churn_seller_callback'` OR-arm).
--   ISSUE 1  Seller dispositioned not_in_shopdeck_criteria but COMPLETED the
--   & 2      process / continued (asked_to_drop_the_lead).  Fix: a drop only
--            counts as churn if it is the seller's LATEST meaningful state, i.e.
--            no positive activity happened after the last drop event.
--
-- "Positive activity" = latest of:
--     - completion milestone : go_live_date / gtg_date          [toggle #1]
--     - re-engagement        : any later ob_task whose          [toggle #2]
--                              disposition is NOT a drop disposition
-- churn_flag = 1  only when  last_drop_date > last_positive_date (or no positive)
--
-- Removed the 20-day `no_recent_ob` rule [toggle #3] - it falsely excludes
-- freshly-dropped sellers (the churn call itself is a "recent OB").
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

-- ISSUE 3 FIX: a genuine drop requires a drop DISPOSITION (not just a callback).
drop_events AS (
    SELECT
        seller_id,
        -- latest date the seller expressed/was marked a drop
        MAX(COALESCE(DATE(completed_at, 'Asia/Kolkata'),
                     DATE(created_at,  'Asia/Kolkata')))            AS last_drop_date,
        -- date used for days_to_churn: latest completed "wants to drop out"
        MAX(IF(disposition = 'seller_wants_to_drop_out' AND completed_at IS NOT NULL,
               DATE(completed_at, 'Asia/Kolkata'), NULL))          AS dropout_completed_date,
        STRING_AGG(DISTINCT disposition, ', ')                     AS churn_reason
    FROM `blitzscale-prod-project.nushop.ob_tasks`
    WHERE created_at >= TIMESTAMP('2022-01-01')
      AND created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE('Asia/Kolkata'), INTERVAL 1 DAY))
      AND disposition IN (
            'seller_wants_to_drop_out',
            'asked_to_drop_the_lead',
            'not_in_shopdeck_criteria',
            'photoshoot_not_available'
          )
    GROUP BY seller_id
),

-- ISSUE 1 & 2 FIX (toggle #2): re-engagement = latest OB task that was NOT a drop.
-- (Remove this CTE / its use to count completion milestones only.)
positive_ob AS (
    SELECT
        seller_id,
        MAX(COALESCE(DATE(completed_at, 'Asia/Kolkata'),
                     DATE(created_at,  'Asia/Kolkata')))            AS last_positive_ob_date
    FROM `blitzscale-prod-project.nushop.ob_tasks`
    WHERE created_at >= TIMESTAMP('2022-01-01')
      AND created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE('Asia/Kolkata'), INTERVAL 1 DAY))
      AND disposition IS NOT NULL
      AND disposition NOT IN (
            'seller_wants_to_drop_out',
            'asked_to_drop_the_lead',
            'not_in_shopdeck_criteria',
            'photoshoot_not_available'
          )
    GROUP BY seller_id
),

seller_level_base AS (
    SELECT
        cb.seller_id,
        cb.dos,
        FORMAT_DATE('%Y-%m', cb.dos)                               AS sale_month,
        cb.gtg_date,
        cb.a2h_date,
        cb.go_live_date,

        de.last_drop_date,
        de.dropout_completed_date,
        de.churn_reason,

        -- latest positive state: completion milestone (toggle #1) or re-engagement (toggle #2)
        (SELECT MAX(d) FROM UNNEST([cb.go_live_date,
                                    cb.gtg_date,
                                    p.last_positive_ob_date]) AS d) AS last_positive_date
    FROM cohort_base cb
    LEFT JOIN drop_events de USING (seller_id)
    LEFT JOIN positive_ob  p  USING (seller_id)
),

seller_level AS (
    SELECT
        *,
        -- churn only if the LATEST meaningful state is a drop
        CASE
            WHEN last_drop_date IS NOT NULL
                 AND (last_positive_date IS NULL OR last_drop_date > last_positive_date)
            THEN 1 ELSE 0
        END                                                        AS churn_flag
    FROM seller_level_base
),

seller_final AS (
    SELECT
        *,
        -- churn_date only meaningful when actually churned
        IF(churn_flag = 1, dropout_completed_date, NULL)           AS churn_date,
        IF(churn_flag = 1, DATE_DIFF(dropout_completed_date, dos, DAY), NULL) AS days_to_churn
    FROM seller_level
)

SELECT
    seller_id,
    dos,
    sale_month,
    gtg_date,
    a2h_date,
    go_live_date,

    churn_flag,
    churn_reason,
    last_drop_date,
    last_positive_date,
    churn_date,
    FORMAT_DATE('%Y-%m', churn_date)                               AS churn_month,
    days_to_churn,

    CASE
        WHEN days_to_churn >= 0 AND days_to_churn < 7 THEN '<7 days'
        WHEN days_to_churn BETWEEN 7  AND 15          THEN '7-15 days'
        WHEN days_to_churn BETWEEN 16 AND 21          THEN '16-21 days'
        WHEN days_to_churn < 0                        THEN 'pre-DOS churn'
        WHEN days_to_churn > 21                       THEN '>21 days'
        ELSE NULL
    END                                                            AS churn_bucket

FROM seller_final
WHERE dos >= DATE '2026-01-01'
  AND dos <  DATE '2026-07-01'
ORDER BY dos, seller_id;
