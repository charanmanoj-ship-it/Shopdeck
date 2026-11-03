-- =====================================================================
-- Ring-time analysis: are POCs hanging up too early, and does it cause DNP?
-- Table: staging.exotel_call_details (seller_id, user_id/staff_id, start_time, end_time, duration)
-- Window: calls created 2026-09-01 onwards (covers all 185 DNP sellers' cagd history).
--
-- KEY ASSUMPTION (Q0 checks it):
--   ring_sec for an unanswered call  = end_time - start_time
--   ring_sec for an answered call    = (end_time - start_time) - duration   (duration = talk time)
-- If Q0 shows duration ~= end_time - start_time for NO_ANSWER calls, then `duration`
-- is total time (ring + talk), and ring-before-answer cannot be separated -> use Q2/Q3 on
-- unanswered calls only.
-- Exotel click-to-call usually rings the POC first, then the seller. If so, end-start also
-- includes the POC leg; Q0's min/percentiles will show a floor (e.g. never below ~5s).
-- =====================================================================

-- ---------- Q0: what do the time columns mean? (run first) ----------
SELECT
  LOWER(call_type) AS call_type,
  UPPER(status)    AS status,
  COUNT(*)         AS calls,
  APPROX_QUANTILES(TIMESTAMP_DIFF(end_time, start_time, SECOND), 20) AS wall_sec_pctiles,  -- every 5%
  APPROX_QUANTILES(SAFE_CAST(duration AS INT64), 20)                 AS duration_pctiles,
  COUNTIF(SAFE_CAST(duration AS INT64) = TIMESTAMP_DIFF(end_time, start_time, SECOND)) AS duration_equals_wall
FROM `staging.exotel_call_details`
WHERE created_at >= TIMESTAMP('2026-09-01')
  AND created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
  AND start_time IS NOT NULL AND end_time IS NOT NULL
GROUP BY 1, 2
ORDER BY calls DESC;


-- ---------- Shared CTEs for Q1-Q3 (paste above each query) ----------
WITH dnp AS (
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
calls AS (
  SELECT
    e.sid, e.seller_id, COALESCE(e.user_id, e.staff_id) AS poc_id,
    LOWER(e.call_type) AS call_type,
    UPPER(e.status)    AS status,
    DATETIME(e.start_time, 'Asia/Kolkata') AS start_ist,
    TIMESTAMP_DIFF(e.end_time, e.start_time, SECOND) AS wall_sec,
    SAFE_CAST(e.duration AS INT64) AS talk_sec,
    CASE
      WHEN UPPER(e.status) = 'CONNECTED'
        THEN TIMESTAMP_DIFF(e.end_time, e.start_time, SECOND) - SAFE_CAST(e.duration AS INT64)
      ELSE TIMESTAMP_DIFF(e.end_time, e.start_time, SECOND)
    END AS ring_sec,
    IF(d.seller_id IS NOT NULL, 'DNP_185', 'other_sellers') AS seller_group
  FROM `staging.exotel_call_details` e
  LEFT JOIN dnp d USING (seller_id)
  WHERE e.created_at >= TIMESTAMP('2026-09-01')
    AND e.created_at <  TIMESTAMP(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY))
    AND LOWER(e.call_type) LIKE 'outbound%'
    AND e.start_time IS NOT NULL AND e.end_time IS NOT NULL
    AND e.seller_id IS NOT NULL
)

-- ---------- Q1: THE key test - how many answered calls were picked up AFTER 20s / 25s / 30s? ----------
-- If a big share of answers come after 20s, hanging up at ~20s is losing real connections.
SELECT
  seller_group,
  COUNTIF(status = 'CONNECTED')                                  AS answered_calls,
  APPROX_QUANTILES(IF(status = 'CONNECTED', ring_sec, NULL), 4)  AS ring_before_answer_quartiles,
  SAFE_DIVIDE(COUNTIF(status = 'CONNECTED' AND ring_sec > 20), COUNTIF(status = 'CONNECTED')) AS pct_answered_after_20s,
  SAFE_DIVIDE(COUNTIF(status = 'CONNECTED' AND ring_sec > 25), COUNTIF(status = 'CONNECTED')) AS pct_answered_after_25s,
  SAFE_DIVIDE(COUNTIF(status = 'CONNECTED' AND ring_sec > 30), COUNTIF(status = 'CONNECTED')) AS pct_answered_after_30s,
  -- how long do we let UNANSWERED calls ring?
  COUNTIF(status = 'NO_ANSWER')                                  AS unanswered_calls,
  APPROX_QUANTILES(IF(status = 'NO_ANSWER', ring_sec, NULL), 4)  AS unanswered_ring_quartiles,
  SAFE_DIVIDE(COUNTIF(status = 'NO_ANSWER' AND ring_sec < 25), COUNTIF(status = 'NO_ANSWER')) AS pct_unanswered_cut_before_25s
FROM calls
GROUP BY seller_group;


-- ---------- Q2: per POC - ring time on unanswered calls and connect rate ----------
-- (replace the final SELECT of the CTE block with this)
-- SELECT
--   COALESCE(u.first_name, c.poc_id) AS poc,
--   COUNT(*) AS outbound_calls,
--   SAFE_DIVIDE(COUNTIF(c.status = 'CONNECTED'), COUNT(*)) AS connect_rate,
--   APPROX_QUANTILES(IF(c.status = 'NO_ANSWER', c.ring_sec, NULL), 2)[OFFSET(1)] AS median_ring_unanswered_sec,
--   SAFE_DIVIDE(COUNTIF(c.status = 'NO_ANSWER' AND c.ring_sec < 25), COUNTIF(c.status = 'NO_ANSWER')) AS pct_unanswered_cut_before_25s,
--   COUNTIF(c.seller_group = 'DNP_185') AS calls_to_dnp_sellers
-- FROM calls c
-- LEFT JOIN `blitzscale-prod-project.nushop.users` u ON c.poc_id = u._id
-- GROUP BY poc
-- HAVING outbound_calls >= 50
-- ORDER BY median_ring_unanswered_sec;


-- ---------- Q3: does ringing longer actually get answered more? ----------
-- Answer rate by how long the call was allowed to ring (bucket uses ring_sec for both outcomes).
-- SELECT
--   seller_group,
--   CASE WHEN ring_sec < 15 THEN '00-14s' WHEN ring_sec < 20 THEN '15-19s'
--        WHEN ring_sec < 25 THEN '20-24s' WHEN ring_sec < 30 THEN '25-29s'
--        WHEN ring_sec < 40 THEN '30-39s' ELSE '40s+' END AS ring_bucket,
--   COUNT(*) AS calls,
--   COUNTIF(status = 'CONNECTED') AS answered
-- FROM calls
-- WHERE status IN ('CONNECTED', 'NO_ANSWER')
-- GROUP BY 1, 2 ORDER BY 1, 2;
