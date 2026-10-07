"""BigQuery SQL for the daily onboarding digest.

Conventions (see shopdeck-onboarding-analytics skill):
- Every table except `users` is partitioned on created_at and MUST carry a
  created_at filter, including tables on the JOIN side.
- "Yesterday" means yesterday in IST (Asia/Kolkata).
- Per (seller, task type) de-dup uses MAX(completed_at).
"""

DATASET = "blitzscale-prod-project.nushop"

TASK_TYPES = [
    "cagd", "gtg", "catalogue_config", "poc_intro", "web_config",
    "website_discussion", "domain_transfer", "meta_setup",
    "price_parity_check", "fund_transfer", "qc_check", "seller_consent",
]

_YESTERDAY_IST = "DATE_SUB(CURRENT_DATE('Asia/Kolkata'), INTERVAL 1 DAY)"
_UPPER = "TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))"

# Unique sellers completing each funnel task yesterday (IST).
TASK_COMPLETIONS = f"""
SELECT
  type AS task_type,
  COUNT(DISTINCT seller_id) AS sellers
FROM `{DATASET}.ob_tasks`
WHERE status = 'completed'
  AND type IN UNNEST(@task_types)
  AND DATE(completed_at, 'Asia/Kolkata') = {_YESTERDAY_IST}
  AND created_at >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY))
  AND created_at <  {_UPPER}
GROUP BY task_type
"""

# Tickets whose Launch milestone completed yesterday (IST). Completion time is updated_at.
LAUNCHES = f"""
SELECT COUNT(DISTINCT ticket_id) AS launches
FROM `{DATASET}.seller_journey_milestones`
WHERE step_name = 'Launch'
  AND status = 'completed'
  AND DATE(updated_at, 'Asia/Kolkata') = {_YESTERDAY_IST}
  AND created_at >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY))
  AND created_at <  {_UPPER}
"""

# Lifecycle dispositions set yesterday (IST). updated_at = disposition timestamp.
LIFECYCLE_EVENTS = f"""
SELECT
  COUNTIF(disposition_reasons = 'seller_wants_to_pause') AS paused,
  COUNTIF(disposition_reasons IN ('seller_wants_to_resume', 'seller_resumed')) AS unpaused,
  COUNTIF(disposition_reasons = 'seller_wants_to_continue') AS revived,
  COUNTIF(disposition_reasons = 'seller_wants_to_drop_out') AS churned
FROM `{DATASET}.ob_tasks`
WHERE type = 'churn_seller_callback'
  AND disposition_reasons IS NOT NULL
  AND DATE(updated_at, 'Asia/Kolkata') = {_YESTERDAY_IST}
  AND created_at >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY))
  AND created_at <  {_UPPER}
"""

# Sellers who completed meta_setup in the last 30 days, have no fund_transfer
# completed after it, and are more than @stuck_after_days past meta.
# Paused and churned sellers are excluded: chasing them wastes POC time.
# Routed to the open fund_transfer assignee, else the latest ticket's ob_poc.
# Sellers whose meta completed > 30 days ago drop out of this list by design.
STUCK_META_TO_FT = f"""
WITH meta AS (
  SELECT seller_id, MAX(completed_at) AS meta_at
  FROM `{DATASET}.ob_tasks`
  WHERE type = 'meta_setup' AND status = 'completed'
    AND completed_at >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY))
    AND created_at >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY))
    AND created_at <  {_UPPER}
  GROUP BY seller_id
),
ft AS (
  SELECT seller_id, MAX(completed_at) AS ft_at
  FROM `{DATASET}.ob_tasks`
  WHERE type = 'fund_transfer' AND status = 'completed'
    AND created_at >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY))
    AND created_at <  {_UPPER}
  GROUP BY seller_id
),
lifecycle AS (
  SELECT
    seller_id,
    MAX(IF(disposition_reasons = 'seller_wants_to_drop_out', updated_at, NULL)) AS churn_at,
    MAX(IF(disposition_reasons = 'seller_wants_to_pause', updated_at, NULL)) AS last_pause_at,
    MAX(IF(disposition_reasons IN ('seller_wants_to_resume', 'seller_resumed'), updated_at, NULL)) AS last_resume_at,
    MAX(IF(disposition_reasons = 'seller_wants_to_continue', updated_at, NULL)) AS last_continue_at
  FROM `{DATASET}.ob_tasks`
  WHERE type = 'churn_seller_callback'
    AND created_at >= TIMESTAMP('2025-01-01')
    AND created_at <  {_UPPER}
  GROUP BY seller_id
),
latest_ticket AS (
  SELECT seller_id, ARRAY_AGG(ob_poc ORDER BY created_at DESC LIMIT 1)[OFFSET(0)] AS ob_poc
  FROM `{DATASET}.ob_tickets`
  WHERE created_at >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY))
    AND created_at <  {_UPPER}
  GROUP BY seller_id
),
-- Whoever holds the open fund_transfer task is the person who can act on it.
-- Ticket-level ob_poc can be stale if the task was reassigned.
open_ft AS (
  SELECT seller_id, ARRAY_AGG(assigned_poc ORDER BY created_at DESC LIMIT 1)[OFFSET(0)] AS assigned_poc
  FROM `{DATASET}.ob_tasks`
  WHERE type = 'fund_transfer'
    AND status NOT IN ('completed', 'cancelled')
    AND assigned_poc IS NOT NULL
    AND created_at >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY))
    AND created_at <  {_UPPER}
  GROUP BY seller_id
)
SELECT
  m.seller_id,
  DATETIME(m.meta_at, 'Asia/Kolkata') AS meta_completed_ist,
  DATE_DIFF(CURRENT_DATE('Asia/Kolkata'), DATE(m.meta_at, 'Asia/Kolkata'), DAY) AS days_since_meta,
  COALESCE(o.assigned_poc, t.ob_poc) AS poc_id,
  COALESCE(u.first_name, '(unassigned)') AS ob_poc,
  u.email AS poc_email,
  IF(o.assigned_poc IS NOT NULL, 'ft_task', 'ticket') AS poc_source
FROM meta m
LEFT JOIN ft f ON f.seller_id = m.seller_id AND f.ft_at >= m.meta_at
LEFT JOIN lifecycle l ON l.seller_id = m.seller_id
LEFT JOIN latest_ticket t ON t.seller_id = m.seller_id
LEFT JOIN open_ft o ON o.seller_id = m.seller_id
LEFT JOIN `{DATASET}.users` u ON u._id = COALESCE(o.assigned_poc, t.ob_poc)
WHERE f.seller_id IS NULL
  AND DATE_DIFF(CURRENT_DATE('Asia/Kolkata'), DATE(m.meta_at, 'Asia/Kolkata'), DAY) > @stuck_after_days
  AND l.churn_at IS NULL
  AND NOT COALESCE(
    l.last_pause_at IS NOT NULL
      AND (l.last_resume_at IS NULL OR l.last_resume_at < l.last_pause_at)
      AND (l.last_continue_at IS NULL OR l.last_continue_at < l.last_pause_at),
    FALSE)
ORDER BY days_since_meta DESC
"""
