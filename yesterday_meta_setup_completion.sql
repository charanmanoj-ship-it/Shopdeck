-- Unique sellers who joined AND completed meta_setup yesterday
SELECT
  COUNT(DISTINCT s.seller_ref) AS unique_sellers_completed
FROM `meet_service.sessions` s
JOIN `meet_service.session_events` se
  ON se.session_id = s.id
 AND se.event = 'disposition_submitted'
 AND JSON_EXTRACT_SCALAR(se.payload, '$.family') = 'COMPLETED'
 AND se.created_at >= TIMESTAMP('2023-01-01')
 AND se.created_at < CURRENT_TIMESTAMP()
WHERE s.use_case_key = 'meta_setup'
  AND DATE(s.created_at) = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);
