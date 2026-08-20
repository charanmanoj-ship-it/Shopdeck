-- ============================================================
-- meet_service — Write Queries
-- All tables live under the `meet_service` dataset in BigQuery.
-- ============================================================


-- ============================================================
-- 1. INSERT new session
--    Call this when a seller initiates a session.
--    Replace the @param_ values with actual parameters.
-- ============================================================
INSERT INTO `meet_service.sessions`
  (id, created_at, seller_ref, connected_at, status, handled_seconds, sla_breached, use_case_key)
VALUES
  (
    @param_id,           -- STRING  e.g. 'sess_abc123'
    CURRENT_TIMESTAMP(), -- TIMESTAMP
    @param_seller_ref,   -- STRING  e.g. 'seller_xyz'
    NULL,                -- not connected yet
    'pending',           -- initial status
    0,                   -- no handled time yet
    FALSE,               -- sla not breached yet
    @param_use_case_key  -- STRING  e.g. 'meta_setup'
  );


-- ============================================================
-- 2a. UPDATE — session connected (call picked up)
-- ============================================================
UPDATE `meet_service.sessions`
SET
  connected_at = CURRENT_TIMESTAMP(),
  status       = 'connected'
WHERE id = @param_id;


-- ============================================================
-- 2b. UPDATE — session ended (call finished)
--    handled_seconds  = wall-clock duration of the handled call
--    sla_breached     = TRUE if the call breached the SLA threshold
-- ============================================================
UPDATE `meet_service.sessions`
SET
  status          = 'ended',
  handled_seconds = @param_handled_seconds,   -- INT64
  sla_breached    = @param_sla_breached       -- BOOL
WHERE id = @param_id;


-- ============================================================
-- 2c. UPDATE — session expired (seller/agent abandoned)
-- ============================================================
UPDATE `meet_service.sessions`
SET
  status       = 'expired',
  sla_breached = TRUE
WHERE id = @param_id;


-- ============================================================
-- 2d. UPDATE — disposition pending (call ended, awaiting agent input)
-- ============================================================
UPDATE `meet_service.sessions`
SET
  status          = 'disposition_pending',
  handled_seconds = @param_handled_seconds
WHERE id = @param_id;


-- ============================================================
-- 3. INSERT queue entry
--    Call this when a session is enqueued for an agent.
-- ============================================================
INSERT INTO `meet_service.queue_entries`
  (session_id, enqueued_at, created_at)
VALUES
  (
    @param_session_id,    -- STRING  FK → sessions.id
    CURRENT_TIMESTAMP(), -- TIMESTAMP  when seller entered queue
    CURRENT_TIMESTAMP()  -- TIMESTAMP  row creation time
  );


-- ============================================================
-- 4. INSERT session event — disposition submitted
--    family values: 'COMPLETED' | 'PARTIALLY_DONE' | 'NOT_DONE'
-- ============================================================
INSERT INTO `meet_service.session_events`
  (session_id, event, created_at, payload)
VALUES
  (
    @param_session_id,   -- STRING  FK → sessions.id
    'disposition_submitted',
    CURRENT_TIMESTAMP(),
    JSON_OBJECT(         -- builds {"family":"COMPLETED","notes":"..."}
      'family', @param_disposition_family,  -- STRING
      'notes',  @param_notes               -- STRING  optional free-text
    )
  );


-- ============================================================
-- BONUS — MERGE: upsert a session (idempotent re-delivery)
--    Useful when the upstream event bus may deliver duplicates.
-- ============================================================
MERGE `meet_service.sessions` AS target
USING (
  SELECT
    @param_id           AS id,
    @param_seller_ref   AS seller_ref,
    @param_use_case_key AS use_case_key
) AS source
ON target.id = source.id
WHEN NOT MATCHED THEN
  INSERT (id, created_at, seller_ref, connected_at, status, handled_seconds, sla_breached, use_case_key)
  VALUES (source.id, CURRENT_TIMESTAMP(), source.seller_ref, NULL, 'pending', 0, FALSE, source.use_case_key)
WHEN MATCHED AND target.status = 'pending' THEN
  -- only update if still in initial state (avoid overwriting progress)
  UPDATE SET seller_ref = source.seller_ref;
