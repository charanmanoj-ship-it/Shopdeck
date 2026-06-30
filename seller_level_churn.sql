-- =============================================================================
-- Seller-level churn detail (one row per seller)
-- Same logic as the original cohort query, emitted at seller_id grain instead
-- of the monthly rollup. Use this to audit / spot-check which sellers land in
-- which churn bucket and window.
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

churn_signals AS (
    SELECT
        seller_id,
        type,
        disposition,
        created_at,
        completed_at
    FROM `blitzscale-prod-project.nushop.ob_tasks`
    WHERE created_at >= TIMESTAMP('2022-01-01')
      AND created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE('Asia/Kolkata'), INTERVAL 1 DAY))
      AND (
            type = 'churn_seller_callback'
            OR disposition IN (
                'seller_wants_to_drop_out',
                'asked_to_drop_the_lead',
                'not_in_shopdeck_criteria',
                'photoshoot_not_available'
            )
      )
),

latest_ob_per_seller AS (
    SELECT
        seller_id,
        MAX(DATE(created_at, 'Asia/Kolkata')) AS last_ob_date
    FROM `blitzscale-prod-project.nushop.ob_tasks`
    WHERE created_at >= TIMESTAMP('2022-01-01')
      AND created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE('Asia/Kolkata'), INTERVAL 1 DAY))
    GROUP BY seller_id
),

no_recent_ob AS (
    -- No OB task/call in the last 20 days
    SELECT seller_id
    FROM latest_ob_per_seller
    WHERE last_ob_date < DATE_SUB(CURRENT_DATE('Asia/Kolkata'), INTERVAL 20 DAY)
),

final_churn AS (
    -- churn signal (OR condition) + no recent OB activity
    SELECT
        c.seller_id,
        STRING_AGG(DISTINCT COALESCE(c.disposition, c.type), ', ') AS churn_reason
    FROM churn_signals c
    INNER JOIN no_recent_ob n USING (seller_id)
    GROUP BY c.seller_id
),

churn_dates AS (
    -- churn date only from completed drop-out callback
    SELECT
        seller_id,
        MAX(DATE(completed_at, 'Asia/Kolkata')) AS churn_date
    FROM `blitzscale-prod-project.nushop.ob_tasks`
    WHERE created_at >= TIMESTAMP('2022-01-01')
      AND created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE('Asia/Kolkata'), INTERVAL 1 DAY))
      AND type        = 'churn_seller_callback'
      AND disposition = 'seller_wants_to_drop_out'
      AND completed_at IS NOT NULL
    GROUP BY seller_id
),

seller_level AS (
    SELECT
        cb.seller_id,
        cb.dos,
        FORMAT_DATE('%Y-%m', cb.dos)              AS sale_month,
        cb.gtg_date,
        cb.a2h_date,
        cb.go_live_date,

        cd.churn_date,
        FORMAT_DATE('%Y-%m', cd.churn_date)       AS churn_month,

        IF(fc.seller_id IS NOT NULL, 1, 0)        AS churn_flag,
        fc.churn_reason,

        DATE_DIFF(cd.churn_date, cb.dos, DAY)     AS days_to_churn
    FROM cohort_base cb
    LEFT JOIN final_churn fc USING (seller_id)
    LEFT JOIN churn_dates cd USING (seller_id)
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
    churn_date,
    churn_month,
    days_to_churn,

    -- M0 day bucket (0-30 days)
    CASE
        WHEN days_to_churn BETWEEN 0  AND 6  THEN '0-6 days'
        WHEN days_to_churn BETWEEN 7  AND 15 THEN '7-15 days'
        WHEN days_to_churn BETWEEN 16 AND 21 THEN '16-21 days'
        WHEN days_to_churn BETWEEN 22 AND 30 THEN '22-30 days'
        WHEN days_to_churn < 0               THEN 'pre-DOS churn'
        WHEN days_to_churn > 30              THEN '>30 days'
        ELSE NULL
    END AS churn_bucket,

    -- Month-since-DOS window (30-day based)
    CASE
        WHEN days_to_churn IS NULL THEN NULL
        WHEN days_to_churn < 0     THEN 'pre_DOS'
        WHEN days_to_churn <= 30   THEN 'M0'
        WHEN days_to_churn <= 60   THEN 'M1'
        WHEN days_to_churn <= 90   THEN 'M2'
        ELSE 'M3_plus'
    END AS churn_window,

    -- flag: counted as churned but has no drop-out date (the flag/date mismatch)
    IF(churn_flag = 1 AND churn_date IS NULL, 1, 0) AS churned_without_dropout_date

FROM seller_level
WHERE dos >= DATE '2026-01-01'
  AND dos <  DATE '2026-07-01'
ORDER BY dos, seller_id;
