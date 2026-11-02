-- =====================================================================
-- DNP unfit deep dive: ticket -> first cagd -> calls -> connected? -> where it broke
-- Source list: 185 DNP seller_ids from seller_level_unfit_cases_2026-11-02 export
-- Grain: Q1 = one row per seller, Q2 = one row per call (with transcript)
-- All timestamps shown in IST. Partition window starts 2026-08-01
-- (earliest final_sale_date in the list is 2026-09-09).
--
-- ASSUMPTIONS TO CONFIRM (edit the params CTE):
--   * Business hours = 10:00-19:00 IST, Mon-Sat. Sundays and outside this = "off_hours".
--   * Call time = exotel_call_details.created_at (swap to start_time if that column exists).
--   * Transcript column name is UNKNOWN -> run Q0 first, then replace <TRANSCRIPT_COL>.
--   * "caci" is not in the 12 known task types; included as-is because the unfit reason cites it.
-- =====================================================================

-- ---------- Q0: schema discovery (run first) ----------
SELECT table_name, column_name, data_type
FROM `blitzscale-prod-project.nushop.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name IN ('exotel_calls', 'exotel_call_details')
   OR REGEXP_CONTAINS(LOWER(column_name), r'transcri|recording|summary|duration|start_time|end_time')
ORDER BY table_name, column_name;


-- ---------- Q1: seller-level break-point ----------
WITH params AS (
  SELECT 10 AS biz_start_hr, 19 AS biz_end_hr
),
dnp_sellers AS (
  SELECT seller_id FROM UNNEST([
  '6a32680eec6853199b6141c2',
  '6a549213ef3ebefe92eee454',
  '6a5e2b9b9d4eaaf22dd9bfe7',
  '6a7d9a3dc291e6c3f2beb881',
  '6aa106a8e3d2629f9bc3efbc',
  '6aa108ecb442516a181501e4',
  '6aa138cfe3d2629f9bc8909a',
  '6aa25d6ce3d2629f9bd8a80e',
  '6aa283b1b442516a182f2e0b',
  '6aa3ce58ae9568e2836f050d',
  '6aa3e1edabcf3087aca9431c',
  '6aa4ec0aae9568e2837b7a58',
  '6aa524f8ae9568e283811abc',
  '6aab7b4fabcf3087ac05d037',
  '6aab90dbabcf3087ac08d583',
  '6aaba9c5abcf3087ac0b122c',
  '6aabdbababcf3087ac115816',
  '6aacccc7cf824fa3e92ed246',
  '6aace4a1abcf3087ac1e8cbd',
  '6aad3982ae9568e283ef0d46',
  '6aae1f1c4e9add2ca38c8b9a',
  '6aae2a54ae9568e283f959ae',
  '6aae3770ae9568e283fb503f',
  '6aae4300ae9568e283fc7ac6',
  '6aae57beabcf3087ac387c78',
  '6ab0f629b84fed6e95075867',
  '6ab10eaf61b74afecad74d66',
  '6ab281ba27b984fa76906e22',
  '6ab54bf3f7e3e62094cffbd7',
  '6ab63b16825cd58646621e88',
  '6ab6549bc5e1761670bb3572',
  '6ab65815f152a2492730767b',
  '6ab65e28f7e3e62094de9a80',
  '6ab66ad6f152a249273181f9',
  '6ab79b46bef13dbb21819b8f',
  '6ab7c11b1a15ab8029548813',
  '6ab7cbdbbef13dbb21865b4e',
  '6ab7cdf1bef13dbb218677ab',
  '6ab7d843bef13dbb21871b16',
  '6ab8c8051a15ab80295cf48d',
  '6ab8e7f81dd5fb00ed267ef1',
  '6ab8efc1bef13dbb218edb10',
  '6aba01341a15ab80296a4e89',
  '6aba1686bef13dbb219ca804',
  '6aba2190bef13dbb219dbd71',
  '6aba35a6c022292b9511a9cc',
  '6aba4a41bef13dbb21a2c4a7',
  '6aba5bc2bef13dbb21a4d0d8',
  '6aba85f67dc4e000c21b417a',
  '6abbcf07bef13dbb21bd6b66',
  '6abbe3461a15ab80298dc203',
  '6abc9890bef13dbb21c4e7d2',
  '6abca4f81a15ab8029953f63',
  '6abccfb39d2f2be926444a17',
  '6abceb58b9bc25c915a94c20',
  '6abced9cb9bc25c915a978a4',
  '6abd03da7b8d7f542d0753d7',
  '6abdec18e87a144b4d34b7c9',
  '6abe41dc7b8d7f542d1b583e',
  '6ac0ae7c2ba23c57c6f4c7ff',
  '6ac0b364e87a144b4d63ffbb',
  '6ac0d0937b8d7f542d415e80',
  '6ac1eb8f7b8d7f542d4c99d7',
  '6ac347f27b8d7f542d5c48d6',
  '6ac357da7b8d7f542d5e365a',
  '6ac380abdde09fead4ea8d47',
  '6ac39fdbd5cc441817cf546f',
  '6ac49dc4e87a144b4d999bd4',
  '6ac4cc307b8d7f542d78a03e',
  '6ac4dd04e87a144b4da1c119',
  '6ac4f3eee87a144b4da38145',
  '6ac50900e87a144b4da4809e',
  '6ac607dce87a144b4db33870',
  '6ac60ae2e87a144b4db3758d',
  '6ac60c307b8d7f542d8cd628',
  '6ac62f067b8d7f542d913a2b',
  '6ac638b97b8d7f542d920ac6',
  '6ac65e887b8d7f542d94a693',
  '6ac729aee87a144b4dc424e0',
  '6ac73f43e87a144b4dc785df',
  '6ac757ce7b8d7f542da47bf3',
  '6ac75c18e87a144b4dcb4633',
  '6ac75e59e87a144b4dcb7b5d',
  '6ac7888be87a144b4dd162ce',
  '6ac78913e87a144b4dd168d7',
  '6ac78ea9ebec015050cce07e',
  '6ac7a2d5e87a144b4dd38ed2',
  '6ac7c093e87a144b4dd52a9a',
  '6ac87c87e87a144b4ddae5b1',
  '6ac8a3ba7b8d7f542db912d3',
  '6ac8b1b97b8d7f542dba7f5a',
  '6ac8bb9b7b8d7f542dbb8c7c',
  '6ac8c20de87a144b4de31c78',
  '6ac8d1837b8d7f542dbd9c69',
  '6ac8e80b109aaa43b9959828',
  '6ac9be88e87a144b4deec408',
  '6ac9e7657b8d7f542dce594f',
  '6ac9f2657b8d7f542dcf079b',
  '6aca0155e87a144b4df9006d',
  '6aca222e01760dab2fb2074c',
  '6aca42057b8d7f542dd766a3',
  '6aca517f7b8d7f542dd8009e',
  '6acb6240e87a144b4d061525',
  '6acc6ac7e87a144b4d0ef95e',
  '6acc97dc7b8d7f542dee4ad0',
  '6acca126e87a144b4d160a6d',
  '6accad777b8d7f542df15c12',
  '6accbb4b7fb255b9ea5eed55',
  '6accd2cee87a144b4d1b6ba4',
  '6accd57860c6a935ba001505',
  '6acddfe27b8d7f542d01cb99',
  '6acde4b07b8d7f542d024936',
  '6ace1bfcaf30bcd4b786ea28',
  '6ace20ffe26d7dce5424391a',
  '6ace24b183f23f7b25ef2105',
  '6ace2ddce26d7dce542504fa',
  '6ace30be93f783cf6122f728',
  '6ace4c43e26d7dce5426302b',
  '6ace4e1ca33cc138bec40faa',
  '6acf22a1e26d7dce542f2b5a',
  '6acf26b9683c16ed94ed7212',
  '6acf3b55e26d7dce54322a27',
  '6acf3cd5d488cd0ea42f6b9d',
  '6acf3e6bd488cd0ea42f9c82',
  '6acf4e8cd488cd0ea4316b4f',
  '6acf7525d488cd0ea4364dbf',
  '6acf7816d488cd0ea4368530',
  '6acf7d18d488cd0ea436ab7f',
  '6ad07e05847d8a8acde0c4a7',
  '6ad0a892e31636fbd7f2de53',
  '6ad0b2efd488cd0ea447f864',
  '6ad0b4fbe26d7dce544bf395',
  '6ad0bd87d488cd0ea4495e34',
  '6ad0c48ae26d7dce544d80d7',
  '6ad0d8fbe26d7dce544ed12f',
  '6ad1dff860eec5eb1b0477d7',
  '6ad1e1ba60eec5eb1b04948d',
  '6ad1e262d488cd0ea4587cb4',
  '6ad207557bcb42ad6b222cc1',
  '6ad219580be3ec46625cb338',
  '6ad223dfd488cd0ea45fd0a1',
  '6ad2279760eec5eb1b0caae9',
  '6ad31f2cd488cd0ea46a5c62',
  '6ad3252ad488cd0ea46ae267',
  '6ad33797d488cd0ea46d4ad6',
  '6ad3671460eec5eb1b1e2eee',
  '6ad3768cd488cd0ea473682b',
  '6ad37aa2d488cd0ea473a5a8',
  '6ad3b8fb60eec5eb1b20f6cd',
  '6ad4606560eec5eb1b237471',
  '6ad4847dd488cd0ea479538c',
  '6ad5d0ec89d8e8ce92b67fd2',
  '6ad5eef389d8e8ce92ba18e1',
  '6ad5f25f89d8e8ce92ba97c1',
  '6ad6005976fcbf9595db2437',
  '6ad616f189d8e8ce92bde8fe',
  '6ad7016bf7dc3d441e259882',
  '6ad73ca289d8e8ce92cac2e6',
  '6ad877b589d8e8ce92da306b',
  '6ad878b94e69bacf694c60f2',
  '6ad887c089d8e8ce92dc329b',
  '6ad89e8489d8e8ce92df16ab',
  '6ad8b89089d8e8ce92e22e5e',
  '6ad99f5d4e69bacf695c0254',
  '6ad9aae189d8e8ce92ecd5b0',
  '6ad9daa964f770c11acb3b72',
  '6ad9dbf12b67b789391b2550',
  '6ad9f11889d8e8ce92f5360a',
  '6ad9fab389d8e8ce92f60fbc',
  '6ada1e4289d8e8ce92f83e46',
  '6ada201e89d8e8ce92f84dfd',
  '6adaf8e21dd6aef556c41c9e',
  '6adb074089d8e8ce9201914e',
  '6adb409e89d8e8ce92080f9e',
  '6adb7ae74e69bacf697baa12',
  '6adc530989d8e8ce9214c831',
  '6adc62044e69bacf6985d60e',
  '6adc70d14e69bacf6987878c',
  '6adc732a4e69bacf6987bd6d',
  '6adc745789d8e8ce9219706a',
  '6adc809a89d8e8ce921ab216',
  '6ae04a7489d8e8ce924b08b2',
  '6ae062114e69bacf69ba86a8',
  '6ae071dc4e69bacf69bcca74',
  '6ae091b84e69bacf69c03395'
  ]) AS seller_id
),
tickets AS (
  SELECT t.seller_id, t.id AS ticket_id, t.created_at AS ticket_created_at, t.ob_poc,
         ROW_NUMBER() OVER (PARTITION BY t.seller_id ORDER BY t.created_at DESC) AS rn_latest,
         COUNT(*) OVER (PARTITION BY t.seller_id) AS n_tickets
  FROM `blitzscale-prod-project.nushop.ob_tickets` t
  JOIN dnp_sellers s USING (seller_id)
  WHERE t.created_at >= TIMESTAMP('2026-08-01')
    AND t.created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
),
tasks AS (
  SELECT ot.id AS task_id, ot.seller_id, ot.ticket_id, ot.type, ot.status,
         ot.created_at, ot.completed_at, ot.disposition_reasons, ot.assigned_poc
  FROM `blitzscale-prod-project.nushop.ob_tasks` ot
  JOIN dnp_sellers s USING (seller_id)
  WHERE ot.created_at >= TIMESTAMP('2026-08-01')
    AND ot.created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
),
first_cagd AS (
  SELECT * EXCEPT(rn) FROM (
    SELECT task_id, seller_id, ticket_id, status, created_at, completed_at, assigned_poc,
           ROW_NUMBER() OVER (PARTITION BY seller_id ORDER BY created_at) AS rn
    FROM tasks WHERE type = 'cagd'
  ) WHERE rn = 1
),
calls AS (
  SELECT
    tk.seller_id, tk.task_id, tk.type AS task_type,
    ecd.sid, LOWER(ecd.call_type) AS call_type, UPPER(ecd.status) AS call_status,
    ecd.created_at AS call_at,
    DATETIME(ecd.created_at, 'Asia/Kolkata') AS call_ist,
    EXTRACT(HOUR FROM DATETIME(ecd.created_at, 'Asia/Kolkata')) AS call_hr_ist,
    EXTRACT(DAYOFWEEK FROM DATETIME(ecd.created_at, 'Asia/Kolkata')) AS call_dow  -- 1 = Sunday
  FROM `blitzscale-prod-project.nushop.exotel_calls` ec
  JOIN `blitzscale-prod-project.nushop.exotel_call_details` ecd
    ON ec.exotel_call_sid = ecd.sid
   AND ecd.created_at >= TIMESTAMP('2026-08-01')
   AND ecd.created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
  JOIN tasks tk ON ec.entity_id = tk.task_id
  WHERE ec.entity = 'ob-task'
    AND ec.created_at >= TIMESTAMP('2026-08-01')
    AND ec.created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
),
calls_flagged AS (
  SELECT c.*,
         (c.call_dow = 1 OR c.call_hr_ist < p.biz_start_hr OR c.call_hr_ist >= p.biz_end_hr) AS is_off_hours
  FROM calls c CROSS JOIN params p
),
seller_calls AS (
  SELECT
    c.seller_id,
    COUNTIF(call_type = 'outbound')                                   AS outbound_calls,
    COUNTIF(call_type = 'inbound')                                    AS inbound_calls,
    COUNTIF(call_type = 'outbound' AND call_status = 'CONNECTED')     AS outbound_connected,
    COUNTIF(call_type = 'inbound'  AND call_status = 'CONNECTED')     AS inbound_connected,
    COUNTIF(call_status = 'NO_ANSWER')                                AS no_answer,
    COUNTIF(call_status = 'BUSY')                                     AS busy,
    COUNTIF(call_status = 'FAILED')                                   AS failed,
    COUNTIF(call_status NOT IN ('CONNECTED','NO_ANSWER','BUSY','FAILED')) AS other_status,
    COUNTIF(call_type = 'outbound' AND is_off_hours)                  AS outbound_off_hours,
    COUNT(DISTINCT IF(call_type = 'outbound', call_hr_ist, NULL))     AS distinct_hours_tried,
    COUNT(DISTINCT IF(call_type = 'outbound', DATE(call_ist), NULL))  AS distinct_days_tried,
    MIN(IF(call_type = 'outbound', call_at, NULL))                    AS first_outbound_at,
    MIN(IF(call_status = 'CONNECTED', call_at, NULL))                 AS first_connected_at,
    MAX(IF(call_status = 'CONNECTED', call_at, NULL))                 AS last_connected_at,
    -- calls on the first cagd task only
    COUNTIF(c.task_id = fc.task_id AND call_type = 'outbound')        AS cagd1_outbound,
    COUNTIF(c.task_id = fc.task_id AND call_status = 'CONNECTED')     AS cagd1_connected,
    COUNTIF(c.task_id = fc.task_id AND call_type = 'outbound' AND is_off_hours) AS cagd1_off_hours,
    STRING_AGG(DISTINCT IF(call_status = 'CONNECTED', task_type, NULL)) AS connected_on_tasks
  FROM calls_flagged c
  LEFT JOIN first_cagd fc USING (seller_id)
  GROUP BY c.seller_id
)
SELECT
  s.seller_id,
  t.ticket_id, t.n_tickets,
  DATETIME(t.ticket_created_at, 'Asia/Kolkata')         AS ticket_created_ist,
  u_ob.first_name                                       AS ticket_ob_poc,
  fc.task_id                                            AS first_cagd_task_id,
  DATETIME(fc.created_at, 'Asia/Kolkata')               AS first_cagd_created_ist,
  fc.status                                             AS first_cagd_status,
  u_cagd.first_name                                     AS first_cagd_assigned_poc,
  ROUND(TIMESTAMP_DIFF(fc.created_at, t.ticket_created_at, MINUTE) / 60, 1)       AS hrs_ticket_to_cagd,
  DATETIME(sc.first_outbound_at, 'Asia/Kolkata')        AS first_call_ist,
  ROUND(TIMESTAMP_DIFF(sc.first_outbound_at, fc.created_at, MINUTE) / 60, 1)      AS hrs_cagd_to_first_call,
  sc.cagd1_outbound, sc.cagd1_connected, sc.cagd1_off_hours,
  sc.outbound_calls, sc.outbound_connected, sc.inbound_calls, sc.inbound_connected,
  sc.no_answer, sc.busy, sc.failed, sc.other_status,
  sc.outbound_off_hours,
  SAFE_DIVIDE(sc.outbound_off_hours, sc.outbound_calls) AS pct_outbound_off_hours,
  sc.distinct_hours_tried, sc.distinct_days_tried,
  DATETIME(sc.first_connected_at, 'Asia/Kolkata')       AS first_connected_ist,
  DATETIME(sc.last_connected_at,  'Asia/Kolkata')       AS last_connected_ist,
  sc.connected_on_tasks,
  IF(COALESCE(sc.outbound_connected, 0) + COALESCE(sc.inbound_connected, 0) > 0,
     'ever_connected', 'never_connected')               AS connect_status,
  CASE
    WHEN t.ticket_id IS NULL                       THEN '01_no_ticket_in_window'
    WHEN fc.task_id IS NULL                        THEN '02_no_cagd_task'
    WHEN COALESCE(sc.outbound_calls, 0) = 0        THEN '03_cagd_created_but_no_calls_logged'
    WHEN COALESCE(sc.outbound_connected,0) + COALESCE(sc.inbound_connected,0) > 0
         AND sc.cagd1_connected > 0                THEN '04_connected_on_cagd_then_went_dark'
    WHEN COALESCE(sc.outbound_connected,0) + COALESCE(sc.inbound_connected,0) > 0
                                                   THEN '05_connected_on_other_task_only'
    WHEN SAFE_DIVIDE(sc.busy + sc.failed, sc.outbound_calls) >= 0.5
                                                   THEN '06_never_connected_mostly_busy_or_failed (number/network/DND)'
    WHEN SAFE_DIVIDE(sc.outbound_off_hours, sc.outbound_calls) >= 0.5
                                                   THEN '07_never_connected_mostly_off_hours'
    WHEN sc.distinct_hours_tried <= 2              THEN '08_never_connected_low_time_variety (<=2 hour slots)'
    ELSE                                                '09_never_connected_rang_out_in_business_hours'
  END AS break_point
FROM dnp_sellers s
LEFT JOIN (SELECT * FROM tickets WHERE rn_latest = 1) t USING (seller_id)
LEFT JOIN first_cagd fc USING (seller_id)
LEFT JOIN seller_calls sc USING (seller_id)
LEFT JOIN `blitzscale-prod-project.nushop.users` u_ob   ON t.ob_poc = u_ob._id
LEFT JOIN `blitzscale-prod-project.nushop.users` u_cagd ON fc.assigned_poc = u_cagd._id
ORDER BY break_point, s.seller_id;


-- ---------- Q2: call-level log with transcripts ----------
-- Reuse the CTEs above (params .. calls_flagged) and replace the final SELECT with:
--
-- SELECT
--   cf.seller_id, cf.task_type, cf.task_id, cf.sid,
--   cf.call_ist, cf.call_hr_ist,
--   FORMAT_DATETIME('%a', cf.call_ist) AS call_day,
--   cf.call_type, cf.call_status, cf.is_off_hours,
--   ROW_NUMBER() OVER (PARTITION BY cf.seller_id ORDER BY cf.call_at) AS call_seq,
--   ecd.<TRANSCRIPT_COL> AS transcript          -- fill from Q0 result
-- FROM calls_flagged cf
-- JOIN `blitzscale-prod-project.nushop.exotel_call_details` ecd
--   ON cf.sid = ecd.sid
--  AND ecd.created_at >= TIMESTAMP('2026-08-01')
--  AND ecd.created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
-- ORDER BY cf.seller_id, cf.call_at;


-- ---------- Q3: off-hours check (run on Q1/Q2 CTEs) ----------
-- Connect rate by IST hour and weekday, outbound only, for these 185 sellers.
--
-- SELECT call_hr_ist,
--        COUNT(*) AS outbound_calls,
--        COUNTIF(call_status = 'CONNECTED') AS connected,
--        SAFE_DIVIDE(COUNTIF(call_status = 'CONNECTED'), COUNT(*)) AS connect_rate
-- FROM calls_flagged
-- WHERE call_type = 'outbound'
-- GROUP BY call_hr_ist ORDER BY call_hr_ist;
