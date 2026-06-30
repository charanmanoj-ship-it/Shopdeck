-- Seller-level output of the original churn query: same logic, one row per seller_id.
-- (Only the final monthly aggregation was replaced with a per-seller SELECT; all
--  CTEs and bucket logic are unchanged from the original.)

WITH cohort_base AS (
    -- DOS source: Query 7100
    SELECT
        seller_id,
        DATE(dos) AS dos,
        DATE(gtg_date) AS gtg_date,
        DATE(a2h_date) AS a2h_date,
        DATE(go_live_date) AS go_live_date
    FROM {{#7100-ob-cohort-query-v2}}
    WHERE dos IS NOT NULL
),

churn_signals AS (
    -- Corrected logic:
    -- type = churn_seller_callback OR disposition is one of the churn dispositions
    SELECT
        seller_id,
        type,
        disposition,
        created_at,
        completed_at
    FROM `blitzscale-prod-project.nushop.ob_tasks`
    WHERE created_at >= TIMESTAMP('2022-01-01')
      AND created_at < TIMESTAMP(DATE_ADD(CURRENT_DATE('Asia/Kolkata'), INTERVAL 1 DAY))
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
    -- OB tasks used as source of truth for last call/contact activity
    SELECT
        seller_id,
        MAX(DATE(created_at, 'Asia/Kolkata')) AS last_ob_date
    FROM `blitzscale-prod-project.nushop.ob_tasks`
    WHERE created_at >= TIMESTAMP('2022-01-01')
      AND created_at < TIMESTAMP(DATE_ADD(CURRENT_DATE('Asia/Kolkata'), INTERVAL 1 DAY))
    GROUP BY seller_id
),

no_recent_ob AS (
    -- No OB task/call in the last 20 days
    SELECT
        seller_id
    FROM latest_ob_per_seller
    WHERE last_ob_date < DATE_SUB(CURRENT_DATE('Asia/Kolkata'), INTERVAL 20 DAY)
),

final_churn AS (
    -- Final churn flag:
    -- churn signal as OR condition + no recent OB activity
    SELECT
        c.seller_id,
        STRING_AGG(DISTINCT COALESCE(c.disposition, c.type), ', ') AS churn_reason
    FROM churn_signals c
    INNER JOIN no_recent_ob n
        ON c.seller_id = n.seller_id
    GROUP BY c.seller_id
),

churn_dates AS (
    -- Churn date should only come from completed churn_seller_callback
    -- where seller was marked seller_wants_to_drop_out
    SELECT
        seller_id,
        MAX(DATE(completed_at, 'Asia/Kolkata')) AS churn_date
    FROM `blitzscale-prod-project.nushop.ob_tasks`
    WHERE created_at >= TIMESTAMP('2022-01-01')
      AND created_at < TIMESTAMP(DATE_ADD(CURRENT_DATE('Asia/Kolkata'), INTERVAL 1 DAY))
      AND type = 'churn_seller_callback'
      AND disposition = 'seller_wants_to_drop_out'
      AND completed_at IS NOT NULL
    GROUP BY seller_id
),

seller_level_base AS (
    SELECT
        cb.seller_id,
        cb.dos,
        FORMAT_DATE('%Y-%m', cb.dos) AS sale_month,

        cb.gtg_date,
        cb.a2h_date,
        cb.go_live_date,

        cd.churn_date,
        FORMAT_DATE('%Y-%m', cd.churn_date) AS churn_month,

        CASE
            WHEN fc.seller_id IS NOT NULL THEN 1
            ELSE 0
        END AS churn_flag,

        fc.churn_reason,

        DATE_DIFF(cd.churn_date, cb.dos, DAY) AS days_to_churn
    FROM cohort_base cb
    LEFT JOIN final_churn fc
        ON cb.seller_id = fc.seller_id
    LEFT JOIN churn_dates cd
        ON cb.seller_id = cd.seller_id
),

seller_level AS (
    SELECT
        *,
        CASE
            WHEN days_to_churn >= 0 AND days_to_churn < 7 THEN '<7 days'
            WHEN days_to_churn BETWEEN 7 AND 15 THEN '7-15 days'
            WHEN days_to_churn BETWEEN 16 AND 21 THEN '16-21 days'
            WHEN days_to_churn < 0 THEN 'pre-DOS churn'
            WHEN days_to_churn > 21 THEN '>21 days'
            ELSE NULL
        END AS churn_bucket
    FROM seller_level_base
)

SELECT
    *
FROM seller_level
WHERE dos >= DATE '2026-01-01'
  AND dos < DATE '2026-07-01'
ORDER BY dos, seller_id;
