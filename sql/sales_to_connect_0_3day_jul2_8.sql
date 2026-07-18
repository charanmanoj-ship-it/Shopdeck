-- ============================================================================
-- Sales → Connect | 0–3 day connectivity | seller level
-- Cohort: tickets created 2 Jul 00:00 IST .. 9 Jul 00:00 IST (incl. all of Jul 8)
-- "Connect" = first OUTBOUND CONNECTED Exotel call on the seller's ob-tasks,
--             at/after ticket creation.
-- Window is fully mature (today >> Jul 8 + 3d), so no maturity gating needed.
-- ============================================================================

WITH sellers_in_window AS (          -- seller-level anchor = earliest ticket in window
  SELECT
    seller_id,
    MIN(created_at) AS ticket_created_at,
    ANY_VALUE(id)   AS sample_ticket_id
  FROM `blitzscale-prod-project.nushop.ob_tickets`
  WHERE created_at >= TIMESTAMP('2026-07-02 00:00:00', 'Asia/Kolkata')
    AND created_at <  TIMESTAMP('2026-07-09 00:00:00', 'Asia/Kolkata')
  GROUP BY seller_id
),

-- calls joined to tasks to recover seller_id; task partition covers window + 3d tail
seller_calls AS (
  SELECT
    t.seller_id,
    -- first connect (at/after nothing yet — we gate on ticket time in the final SELECT)
    MIN(IF(UPPER(ecd.status)='CONNECTED' AND LOWER(ecd.call_type)='outbound', ec.created_at, NULL)) AS first_outbound_connect_at,
    MIN(IF(UPPER(ecd.status)='CONNECTED',                                     ec.created_at, NULL)) AS first_any_connect_at,
    MIN(ec.created_at)                                                        AS first_call_at,
    COUNT(*)                                                                  AS total_calls,
    COUNTIF(LOWER(ecd.call_type)='outbound')                                  AS outbound_calls,
    COUNTIF(LOWER(ecd.call_type)='inbound')                                   AS inbound_calls,
    COUNTIF(UPPER(ecd.status)='CONNECTED')                                    AS connected_calls
  FROM `blitzscale-prod-project.nushop.exotel_calls` ec
  JOIN `blitzscale-prod-project.nushop.exotel_call_details` ecd
    ON ec.exotel_call_sid = ecd.sid
  JOIN `blitzscale-prod-project.nushop.ob_tasks` t
    ON ec.entity_id = t.id
  WHERE ec.entity = 'ob-task'
    AND ec.created_at  >= TIMESTAMP('2026-07-02 00:00:00', 'Asia/Kolkata')
    AND ec.created_at  <  TIMESTAMP('2026-07-12 00:00:00', 'Asia/Kolkata')
    AND ecd.created_at >= TIMESTAMP('2026-07-02 00:00:00', 'Asia/Kolkata')
    AND ecd.created_at <  TIMESTAMP('2026-07-12 00:00:00', 'Asia/Kolkata')
    AND t.created_at   >= TIMESTAMP('2026-07-01 00:00:00', 'Asia/Kolkata')
    AND t.created_at   <  TIMESTAMP('2026-07-12 00:00:00', 'Asia/Kolkata')
  GROUP BY t.seller_id
),

-- did the seller ever reach GTG? (validation: connectivity should predict this)
gtg_done AS (
  SELECT seller_id, MIN(completed_at) AS gtg_at
  FROM `blitzscale-prod-project.nushop.ob_tasks`
  WHERE type = 'gtg' AND status = 'completed'
    AND created_at >= TIMESTAMP('2026-07-01 00:00:00', 'Asia/Kolkata')
    AND created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
  GROUP BY seller_id
),

-- first contact's task type (cagd vs poc_intro vs …) — is first touch where we expect?
first_contact_task AS (
  SELECT seller_id, task_type AS first_connect_task_type FROM (
    SELECT t.seller_id, t.type AS task_type,
           ROW_NUMBER() OVER (PARTITION BY t.seller_id ORDER BY ec.created_at) AS rn
    FROM `blitzscale-prod-project.nushop.exotel_calls` ec
    JOIN `blitzscale-prod-project.nushop.exotel_call_details` ecd ON ec.exotel_call_sid = ecd.sid
    JOIN `blitzscale-prod-project.nushop.ob_tasks` t ON ec.entity_id = t.id
    WHERE ec.entity='ob-task'
      AND UPPER(ecd.status)='CONNECTED' AND LOWER(ecd.call_type)='outbound'
      AND ec.created_at  >= TIMESTAMP('2026-07-02 00:00:00','Asia/Kolkata')
      AND ec.created_at  <  TIMESTAMP('2026-07-12 00:00:00','Asia/Kolkata')
      AND ecd.created_at >= TIMESTAMP('2026-07-02 00:00:00','Asia/Kolkata')
      AND ecd.created_at <  TIMESTAMP('2026-07-12 00:00:00','Asia/Kolkata')
      AND t.created_at   >= TIMESTAMP('2026-07-01 00:00:00','Asia/Kolkata')
      AND t.created_at   <  TIMESTAMP('2026-07-12 00:00:00','Asia/Kolkata')
  ) WHERE rn = 1
)

SELECT
  s.seller_id,
  DATETIME(s.ticket_created_at, 'Asia/Kolkata')                 AS ticket_created_ist,
  DATETIME(sc.first_outbound_connect_at, 'Asia/Kolkata')        AS first_connect_ist,
  -- days to connect (only meaningful when connect is at/after ticket creation)
  IF(sc.first_outbound_connect_at >= s.ticket_created_at,
     DATE_DIFF(DATE(sc.first_outbound_connect_at,'Asia/Kolkata'),
               DATE(s.ticket_created_at,'Asia/Kolkata'), DAY),
     NULL)                                                      AS days_to_connect,
  -- the headline flag
  (sc.first_outbound_connect_at IS NOT NULL
   AND sc.first_outbound_connect_at >= s.ticket_created_at
   AND DATE_DIFF(DATE(sc.first_outbound_connect_at,'Asia/Kolkata'),
                 DATE(s.ticket_created_at,'Asia/Kolkata'), DAY) BETWEEN 0 AND 3)
                                                                AS connected_0_3d,
  -- MECE status bucket
  CASE
    WHEN sc.seller_id IS NULL OR sc.total_calls = 0                         THEN 'never_called'
    WHEN sc.first_outbound_connect_at IS NULL                              THEN 'called_never_connected_rnr'
    WHEN sc.first_outbound_connect_at <  s.ticket_created_at               THEN 'connect_before_ticket_check'
    WHEN DATE_DIFF(DATE(sc.first_outbound_connect_at,'Asia/Kolkata'),
                   DATE(s.ticket_created_at,'Asia/Kolkata'), DAY) = 0      THEN 'connected_d0'
    WHEN DATE_DIFF(DATE(sc.first_outbound_connect_at,'Asia/Kolkata'),
                   DATE(s.ticket_created_at,'Asia/Kolkata'), DAY) = 1      THEN 'connected_d1'
    WHEN DATE_DIFF(DATE(sc.first_outbound_connect_at,'Asia/Kolkata'),
                   DATE(s.ticket_created_at,'Asia/Kolkata'), DAY) = 2      THEN 'connected_d2'
    WHEN DATE_DIFF(DATE(sc.first_outbound_connect_at,'Asia/Kolkata'),
                   DATE(s.ticket_created_at,'Asia/Kolkata'), DAY) = 3      THEN 'connected_d3'
    ELSE 'connected_after_3d'
  END                                                           AS connect_status,
  COALESCE(sc.total_calls, 0)        AS total_calls,
  COALESCE(sc.outbound_calls, 0)     AS outbound_calls,
  COALESCE(sc.inbound_calls, 0)      AS inbound_calls,
  COALESCE(sc.connected_calls, 0)    AS connected_calls,
  fct.first_connect_task_type,
  (g.gtg_at IS NOT NULL)             AS gtg_reached,
  DATETIME(g.gtg_at, 'Asia/Kolkata') AS gtg_at_ist
FROM sellers_in_window s
LEFT JOIN seller_calls       sc  ON s.seller_id = sc.seller_id
LEFT JOIN gtg_done           g   ON s.seller_id = g.seller_id
LEFT JOIN first_contact_task fct ON s.seller_id = fct.seller_id
ORDER BY connected_0_3d, days_to_connect;
