-- =============================================================================
-- Monthly churn % by sale cohort (M0 / M1 / M2)
-- =============================================================================
-- Cohort key      : sale_month = calendar month of DATE OF SALE (dos)
-- Month-since-DOS  : 30-day windows from dos
--                      M0 = days   0..30
--                      M1 = days  31..60
--                      M2 = days  61..90
-- M0 day buckets   : 0-6 | 7-15 | 16-21 | 22-30   (non-overlapping, no gaps)
-- Churn definition : earliest COMPLETED churn_seller_callback whose disposition
--                    is seller_wants_to_drop_out.  Single source of truth for
--                    BOTH the churn flag and the churn date, so every bucket
--                    reconciles with the totals.
--
-- ASSUMPTIONS (flip any of these and the result set changes):
--   [1] M0/M1/M2 are 30-day windows, NOT calendar months.
--   [2] Churn = strict drop-out event only (not the broad 4-disposition signal).
--   [3] The "no OB activity in last 20 days" recency rule is dropped, so cohort
--       churn is point-in-time stable.
--   [4] churn_date = MIN(completed_at)  (earliest drop-out, not the latest).
-- =============================================================================

WITH cohort_base AS (
    -- DOS source: Metabase Query 7100. Force one row per seller (earliest dos)
    -- so the cohort denominator can't be inflated by duplicate source rows.
    SELECT
        seller_id,
        dos,
        gtg_date,
        a2h_date,
        go_live_date
    FROM (
        SELECT
            seller_id,
            DATE(dos)          AS dos,
            DATE(gtg_date)     AS gtg_date,
            DATE(a2h_date)     AS a2h_date,
            DATE(go_live_date) AS go_live_date,
            ROW_NUMBER() OVER (PARTITION BY seller_id ORDER BY DATE(dos)) AS rn
        FROM {{#7100-ob-cohort-query-v2}}
        WHERE dos IS NOT NULL
    )
    WHERE rn = 1
),

churn_event AS (
    -- One churn date per seller = earliest completed drop-out callback.
    SELECT
        seller_id,
        MIN(DATE(completed_at, 'Asia/Kolkata')) AS churn_date
    FROM `blitzscale-prod-project.nushop.ob_tasks`
    WHERE type        = 'churn_seller_callback'
      AND disposition = 'seller_wants_to_drop_out'
      AND completed_at IS NOT NULL
      AND completed_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE('Asia/Kolkata'), INTERVAL 1 DAY))
    GROUP BY seller_id
),

seller_level AS (
    SELECT
        cb.seller_id,
        cb.dos,
        FORMAT_DATE('%Y-%m', cb.dos)                       AS sale_month,
        ce.churn_date,
        IF(ce.churn_date IS NOT NULL, 1, 0)                AS churn_flag,
        DATE_DIFF(ce.churn_date, cb.dos, DAY)              AS days_to_churn
    FROM cohort_base cb
    LEFT JOIN churn_event ce USING (seller_id)
),

classified AS (
    SELECT
        *,
        -- Month-since-DOS window
        CASE
            WHEN days_to_churn IS NULL THEN NULL
            WHEN days_to_churn < 0     THEN 'pre_DOS'   -- data quality: churn before sale
            WHEN days_to_churn <= 30   THEN 'M0'
            WHEN days_to_churn <= 60   THEN 'M1'
            WHEN days_to_churn <= 90   THEN 'M2'
            ELSE 'M3_plus'
        END AS churn_window,
        -- M0 day sub-bucket (NULL unless churn fell inside M0)
        CASE
            WHEN days_to_churn BETWEEN 0  AND 6  THEN '0-6'
            WHEN days_to_churn BETWEEN 7  AND 15 THEN '7-15'
            WHEN days_to_churn BETWEEN 16 AND 21 THEN '16-21'
            WHEN days_to_churn BETWEEN 22 AND 30 THEN '22-30'
            ELSE NULL
        END AS m0_day_bucket
    FROM seller_level
)

SELECT
    sale_month,
    COUNT(DISTINCT seller_id) AS cohort_sellers,

    -- ---- Window-maturity flags (is the cohort old enough TODAY to fully
    --      observe each window?  Uses the LAST sale in the month). -------------
    DATE_DIFF(CURRENT_DATE('Asia/Kolkata'), MAX(dos), DAY) >= 30 AS m0_window_complete,
    DATE_DIFF(CURRENT_DATE('Asia/Kolkata'), MAX(dos), DAY) >= 60 AS m1_window_complete,
    DATE_DIFF(CURRENT_DATE('Asia/Kolkata'), MAX(dos), DAY) >= 90 AS m2_window_complete,

    -- ---- Total churn within the M0-M2 observation window (days 0..90) --------
    COUNT(DISTINCT IF(churn_window IN ('M0','M1','M2'), seller_id, NULL)) AS churned_0_90d,
    ROUND(SAFE_DIVIDE(
        COUNT(DISTINCT IF(churn_window IN ('M0','M1','M2'), seller_id, NULL)),
        COUNT(DISTINCT seller_id)) * 100, 2)                            AS churn_pct_0_90d,

    -- ============================ M0 ========================================
    COUNT(DISTINCT IF(churn_window = 'M0', seller_id, NULL))             AS m0_churned,
    ROUND(SAFE_DIVIDE(
        COUNT(DISTINCT IF(churn_window = 'M0', seller_id, NULL)),
        COUNT(DISTINCT seller_id)) * 100, 2)                            AS m0_churn_pct,

    -- M0 day sub-buckets (counts)
    COUNT(DISTINCT IF(m0_day_bucket = '0-6',   seller_id, NULL))         AS m0_0_6d,
    COUNT(DISTINCT IF(m0_day_bucket = '7-15',  seller_id, NULL))         AS m0_7_15d,
    COUNT(DISTINCT IF(m0_day_bucket = '16-21', seller_id, NULL))         AS m0_16_21d,
    COUNT(DISTINCT IF(m0_day_bucket = '22-30', seller_id, NULL))         AS m0_22_30d,

    -- M0 day sub-buckets (% of cohort)
    ROUND(SAFE_DIVIDE(COUNT(DISTINCT IF(m0_day_bucket = '0-6',   seller_id, NULL)),
        COUNT(DISTINCT seller_id)) * 100, 2)                            AS m0_0_6d_pct,
    ROUND(SAFE_DIVIDE(COUNT(DISTINCT IF(m0_day_bucket = '7-15',  seller_id, NULL)),
        COUNT(DISTINCT seller_id)) * 100, 2)                            AS m0_7_15d_pct,
    ROUND(SAFE_DIVIDE(COUNT(DISTINCT IF(m0_day_bucket = '16-21', seller_id, NULL)),
        COUNT(DISTINCT seller_id)) * 100, 2)                            AS m0_16_21d_pct,
    ROUND(SAFE_DIVIDE(COUNT(DISTINCT IF(m0_day_bucket = '22-30', seller_id, NULL)),
        COUNT(DISTINCT seller_id)) * 100, 2)                            AS m0_22_30d_pct,

    -- ============================ M1 ========================================
    COUNT(DISTINCT IF(churn_window = 'M1', seller_id, NULL))             AS m1_churned,
    ROUND(SAFE_DIVIDE(
        COUNT(DISTINCT IF(churn_window = 'M1', seller_id, NULL)),
        COUNT(DISTINCT seller_id)) * 100, 2)                            AS m1_churn_pct,

    -- ============================ M2 ========================================
    COUNT(DISTINCT IF(churn_window = 'M2', seller_id, NULL))             AS m2_churned,
    ROUND(SAFE_DIVIDE(
        COUNT(DISTINCT IF(churn_window = 'M2', seller_id, NULL)),
        COUNT(DISTINCT seller_id)) * 100, 2)                            AS m2_churn_pct,

    -- ---- Diagnostics (kept out of the headline %s) --------------------------
    COUNT(DISTINCT IF(churn_window = 'pre_DOS', seller_id, NULL))        AS pre_dos_churners,
    COUNT(DISTINCT IF(churn_window = 'M3_plus', seller_id, NULL))        AS churned_after_90d

FROM classified
WHERE dos >= DATE '2026-01-01'
  AND dos <  DATE '2026-07-01'
GROUP BY sale_month
ORDER BY sale_month;
