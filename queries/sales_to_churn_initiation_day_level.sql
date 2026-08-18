-- Sales to Churn Initiation — Day Level Cohort
-- Mirrors the structure of #12680 (Sales to GTG day level)
--
-- Churn initiation is the EARLIEST date any of these fire on a seller's ticket:
--   1. Any task disposition IN ('asked_to_drop_the_lead', 'not_in_shopdeck_criteria', 'photoshoot_not_available')
--   2. A 'churn seller call back' task is created (triggered by 13+ unanswered calls)
--
-- Full churn (seller_wants_to_drop_out on a churn seller call back task) is a separate metric.

WITH first_ticket AS (
  SELECT
    seller_id,
    ticket_id,
    dos_date
  FROM (
    SELECT
      t.seller_id,
      t.id AS ticket_id,
      DATE(t.created_at, 'Asia/Kolkata') AS dos_date,
      ROW_NUMBER() OVER (PARTITION BY t.seller_id ORDER BY t.created_at ASC) AS rn
    FROM `blitzscale-prod-project.nushop.ob_tickets` t
    WHERE t.created_at >= TIMESTAMP('2026-05-01', 'Asia/Kolkata')
      AND t.created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
  )
  WHERE rn = 1
),

churn_initiation_by_ticket AS (
  SELECT
    ticket_id,
    MIN(DATE(created_at, 'Asia/Kolkata')) AS churn_initiation_date
  FROM `blitzscale-prod-project.nushop.ob_tasks`
  WHERE (
    disposition IN (
      'asked_to_drop_the_lead',
      'not_in_shopdeck_criteria',
      'photoshoot_not_available'
    )
    OR type = 'churn seller call back'
  )
  AND created_at >= TIMESTAMP('2026-05-01', 'Asia/Kolkata')
  AND created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
  GROUP BY ticket_id
),

sales_cohort AS (
  SELECT
    ft.seller_id,
    ft.dos_date,
    ci.churn_initiation_date
  FROM first_ticket ft
  LEFT JOIN churn_initiation_by_ticket ci ON ft.ticket_id = ci.ticket_id
  WHERE ft.dos_date BETWEEN {{start_date}} AND {{end_date}}
),

cohort_days AS (
  SELECT
    dos_date,
    seller_id,
    CASE
      WHEN churn_initiation_date >= dos_date
      THEN DATE_DIFF(churn_initiation_date, dos_date, DAY)
    END AS days_to_churn_init,
    DATE_DIFF(CURRENT_DATE('Asia/Kolkata'), dos_date, DAY) AS cohort_age_days
  FROM sales_cohort
),

daily_stats AS (
  SELECT
    dos_date AS sale_date,
    COUNT(*)                                                                                            AS Sales,
    IF(MAX(cohort_age_days) >= 0,  ROUND(100 * COUNTIF(days_to_churn_init = 0)  / COUNT(*), 0), NULL) AS D0,
    IF(MAX(cohort_age_days) >= 1,  ROUND(100 * COUNTIF(days_to_churn_init = 1)  / COUNT(*), 0), NULL) AS D1,
    IF(MAX(cohort_age_days) >= 2,  ROUND(100 * COUNTIF(days_to_churn_init = 2)  / COUNT(*), 0), NULL) AS D2,
    IF(MAX(cohort_age_days) >= 3,  ROUND(100 * COUNTIF(days_to_churn_init = 3)  / COUNT(*), 0), NULL) AS D3,
    IF(MAX(cohort_age_days) >= 4,  ROUND(100 * COUNTIF(days_to_churn_init = 4)  / COUNT(*), 0), NULL) AS D4,
    IF(MAX(cohort_age_days) >= 5,  ROUND(100 * COUNTIF(days_to_churn_init = 5)  / COUNT(*), 0), NULL) AS D5,
    IF(MAX(cohort_age_days) >= 6,  ROUND(100 * COUNTIF(days_to_churn_init = 6)  / COUNT(*), 0), NULL) AS D6,
    IF(MAX(cohort_age_days) >= 7,  ROUND(100 * COUNTIF(days_to_churn_init = 7)  / COUNT(*), 0), NULL) AS D7,
    IF(MAX(cohort_age_days) >= 8,  ROUND(100 * COUNTIF(days_to_churn_init = 8)  / COUNT(*), 0), NULL) AS D8,
    IF(MAX(cohort_age_days) >= 9,  ROUND(100 * COUNTIF(days_to_churn_init = 9)  / COUNT(*), 0), NULL) AS D9,
    IF(MAX(cohort_age_days) >= 10, ROUND(100 * COUNTIF(days_to_churn_init = 10) / COUNT(*), 0), NULL) AS D10,
    IF(MAX(cohort_age_days) >= 11, ROUND(100 * COUNTIF(days_to_churn_init = 11) / COUNT(*), 0), NULL) AS D11,
    IF(MAX(cohort_age_days) >= 12, ROUND(100 * COUNTIF(days_to_churn_init = 12) / COUNT(*), 0), NULL) AS D12,
    IF(MAX(cohort_age_days) >= 13, ROUND(100 * COUNTIF(days_to_churn_init = 13) / COUNT(*), 0), NULL) AS D13,
    IF(MAX(cohort_age_days) >= 14, ROUND(100 * COUNTIF(days_to_churn_init = 14) / COUNT(*), 0), NULL) AS D14,
    IF(MAX(cohort_age_days) >= 15, ROUND(100 * COUNTIF(days_to_churn_init = 15) / COUNT(*), 0), NULL) AS D15
  FROM cohort_days
  GROUP BY dos_date
)

SELECT
  *,
  IFNULL(D0,0)+IFNULL(D1,0)+IFNULL(D2,0)+IFNULL(D3,0)+IFNULL(D4,0)+IFNULL(D5,0)+
  IFNULL(D6,0)+IFNULL(D7,0)+IFNULL(D8,0)+IFNULL(D9,0)+IFNULL(D10,0)+IFNULL(D11,0)+
  IFNULL(D12,0)+IFNULL(D13,0)+IFNULL(D14,0)+IFNULL(D15,0) AS Total
FROM daily_stats
ORDER BY sale_date
