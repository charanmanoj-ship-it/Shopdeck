-- =====================================================================
-- DNP sellers: split "Marketing" into old perf vs new perf (and any other sub-source)
-- The unfit export only carries source_group / source_c / sub_source_c, and sub_source_c is
-- "Mixed Sources" for 183 of 185 rows -> it cannot separate old vs new perf.
-- So: (Q0) find where the perf/campaign field lives, (Q1) pull it for the 185 DNP leads.
--
-- FILL IN:
--   <REGION>       BigQuery region of the project, e.g. region-asia-south1 (Q0b)
--   <LEAD_TABLE>   table holding Salesforce leads (lead_id starts with 00Q...)
--   <PERF_COLS>    the columns Q0 finds (lead source / sub source / utm / campaign / funnel)
--   <PERF_RULE>    how your team defines old vs new perf (campaign name? form? date cut-over?)
-- =====================================================================

-- ---------- Q0a: search the nushop dataset for source / campaign columns ----------
SELECT table_name, column_name, data_type
FROM `blitzscale-prod-project.nushop.INFORMATION_SCHEMA.COLUMNS`
WHERE REGEXP_CONTAINS(LOWER(column_name), r'perf|utm|campaign|lead_source|leadsource|sub_source|source__c|funnel|adset|ad_id|form')
ORDER BY table_name, column_name;

-- ---------- Q0b: same search across every dataset in the project ----------
SELECT table_schema, table_name, column_name, data_type
FROM `blitzscale-prod-project`.`<REGION>`.INFORMATION_SCHEMA.COLUMNS
WHERE REGEXP_CONTAINS(LOWER(column_name), r'perf|utm|campaign|lead_source|leadsource|sub_source|source__c|funnel')
ORDER BY table_schema, table_name, column_name;


-- ---------- Q1: pull the perf fields for the 185 DNP leads ----------
WITH dnp AS (
  SELECT * FROM UNNEST([
    STRUCT('00Qfu00000jB8y9EAC' AS lead_id, '6adc62044e69bacf6985d60e' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu000002MzovEAC' AS lead_id, '6ab8e7f81dd5fb00ed267ef1' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000jSef1EAC' AS lead_id, '6adc732a4e69bacf6987bd6d' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000Iy4spEAB' AS lead_id, '6ab65e28f7e3e62094de9a80' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000gD0F2EAK' AS lead_id, '6ab281ba27b984fa76906e22' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000ZnhXXEAZ' AS lead_id, '6adc745789d8e8ce9219706a' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000iq4EJEAY' AS lead_id, '6ad9aae189d8e8ce92ecd5b0' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu00000j2nUGEAY' AS lead_id, '6ad7016bf7dc3d441e259882' AS seller_id, 'L1c' AS dnp_bucket),
    STRUCT('00QJ2000004CUukMAG' AS lead_id, '6ad4606560eec5eb1b237471' AS seller_id, 'L1c' AS dnp_bucket),
    STRUCT('00Qfu00000jlcJGEAY' AS lead_id, '6ae091b84e69bacf69c03395' AS seller_id, 'L3?' AS dnp_bucket),
    STRUCT('00Qfu00000FiVVjEAN' AS lead_id, '6abc9890bef13dbb21c4e7d2' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu00000V3XdVEAV' AS lead_id, '6abced9cb9bc25c915a978a4' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu00000eD6WnEAK' AS lead_id, '6adc70d14e69bacf6987878c' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000fFEz9EAG' AS lead_id, '6ae062114e69bacf69ba86a8' AS seller_id, 'L1c' AS dnp_bucket),
    STRUCT('00Qfu00000JMzRoEAL' AS lead_id, '6ae04a7489d8e8ce924b08b2' AS seller_id, 'L1c' AS dnp_bucket),
    STRUCT('00Qfu00000RyH6wEAF' AS lead_id, '6acde4b07b8d7f542d024936' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu000002MiiWEAS' AS lead_id, '6ac78913e87a144b4dd168d7' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu00000ikcVbEAI' AS lead_id, '6ad223dfd488cd0ea45fd0a1' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000jkRxnEAE' AS lead_id, '6ae071dc4e69bacf69bcca74' AS seller_id, 'L1c' AS dnp_bucket),
    STRUCT('00Qfu00000cP8ZBEA0' AS lead_id, '6aab7b4fabcf3087ac05d037' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000fnf7GEAQ' AS lead_id, '6aacccc7cf824fa3e92ed246' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000WjXBtEAN' AS lead_id, '6ad5eef389d8e8ce92ba18e1' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu00000G4DezEAF' AS lead_id, '6adc809a89d8e8ce921ab216' AS seller_id, 'L1b' AS dnp_bucket),
    STRUCT('00Qfu00000iiWkQEAU' AS lead_id, '6ad1dff860eec5eb1b0477d7' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000hj91dEAA' AS lead_id, '6adb409e89d8e8ce92080f9e' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000hmW02EAE' AS lead_id, '6ac60ae2e87a144b4db3758d' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu00000XGc6ZEAT' AS lead_id, '6ad9fab389d8e8ce92f60fbc' AS seller_id, 'L3?' AS dnp_bucket),
    STRUCT('00Qfu00000iVHckEAG' AS lead_id, '6acf3cd5d488cd0ea42f6b9d' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu00000ejjOYEAY' AS lead_id, '6aa108ecb442516a181501e4' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000gfgHfEAI' AS lead_id, '6aba1686bef13dbb219ca804' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000XNv0zEAD' AS lead_id, '6aa3e1edabcf3087aca9431c' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000hydiTEAQ' AS lead_id, '6ac78ea9ebec015050cce07e' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000fxEx0EAE' AS lead_id, '6aae57beabcf3087ac387c78' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu00000fWGyAEAW' AS lead_id, '6ab10eaf61b74afecad74d66' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu00000gtNmzEAE' AS lead_id, '6abceb58b9bc25c915a94c20' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000ioUfwEAE' AS lead_id, '6ad878b94e69bacf694c60f2' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000fqn8JEAQ' AS lead_id, '6aae4300ae9568e283fc7ac6' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu00000jHvpcEAC' AS lead_id, '6ada1e4289d8e8ce92f83e46' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu000002VmL0EAK' AS lead_id, '6acf4e8cd488cd0ea4316b4f' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu000002Z1LtEAK' AS lead_id, '6adc530989d8e8ce9214c831' AS seller_id, 'L1a' AS dnp_bucket),
    STRUCT('00Qfu000002SOKGEA4' AS lead_id, '6ac65e887b8d7f542d94a693' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000iDLGfEAO' AS lead_id, '6accd2cee87a144b4d1b6ba4' AS seller_id, 'L1c' AS dnp_bucket),
    STRUCT('00Qfu00000hi3z7EAA' AS lead_id, '6ac380abdde09fead4ea8d47' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000iQIXrEAO' AS lead_id, '6ace1bfcaf30bcd4b786ea28' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000jKTwqEAG' AS lead_id, '6adaf8e21dd6aef556c41c9e' AS seller_id, 'L1c' AS dnp_bucket),
    STRUCT('00Qfu00000jKWczEAG' AS lead_id, '6adb074089d8e8ce9201914e' AS seller_id, 'L1a' AS dnp_bucket),
    STRUCT('00QJ2000004CPdHMAW' AS lead_id, '6ac7a2d5e87a144b4dd38ed2' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000cG7qrEAC' AS lead_id, '6ab7d843bef13dbb21871b16' AS seller_id, 'L3?' AS dnp_bucket),
    STRUCT('00Qfu00000gBYMNEA4' AS lead_id, '6ada201e89d8e8ce92f84dfd' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000ic1MlEAI' AS lead_id, '6ad616f189d8e8ce92bde8fe' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu00000jAxJSEA0' AS lead_id, '6ad8b89089d8e8ce92e22e5e' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00QJ2000004CSAKMA4' AS lead_id, '6aba5bc2bef13dbb21a4d0d8' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu00000ass3aEAA' AS lead_id, '6ac75c18e87a144b4dcb4633' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000f88GxEAI' AS lead_id, '6aa4ec0aae9568e2837b7a58' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000bxVldEAE' AS lead_id, '6aab90dbabcf3087ac08d583' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000i6k5JEAQ' AS lead_id, '6ac9e7657b8d7f542dce594f' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu000002ZAHfEAO' AS lead_id, '6acf7d18d488cd0ea436ab7f' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000fY9yvEAC' AS lead_id, '6ad1e1ba60eec5eb1b04948d' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000jFqVsEAK' AS lead_id, '6ad9f11889d8e8ce92f5360a' AS seller_id, 'L1c' AS dnp_bucket),
    STRUCT('00Qfu000002EJPsEAO' AS lead_id, '6acb6240e87a144b4d061525' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000iMaQ5EAK' AS lead_id, '6acddfe27b8d7f542d01cb99' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000TCpHSEA1' AS lead_id, '6ac757ce7b8d7f542da47bf3' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu000002dOnNEAU' AS lead_id, '6ad0d8fbe26d7dce544ed12f' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu00000XzUivEAF' AS lead_id, '6a32680eec6853199b6141c2' AS seller_id, 'L1a' AS dnp_bucket),
    STRUCT('00Qfu00000jFx14EAC' AS lead_id, '6ad9daa964f770c11acb3b72' AS seller_id, 'L1c' AS dnp_bucket),
    STRUCT('00Qfu00000j4IsWEAU' AS lead_id, '6ad73ca289d8e8ce92cac2e6' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu000002Xyn7EAC' AS lead_id, '6ac60c307b8d7f542d8cd628' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000i1uzhEAA' AS lead_id, '6ac9f2657b8d7f542dcf079b' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000fgZ3NEAU' AS lead_id, '6aaba9c5abcf3087ac0b122c' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000jFleEEAS' AS lead_id, '6ad9dbf12b67b789391b2550' AS seller_id, 'L1a' AS dnp_bucket),
    STRUCT('00Qfu00000YkrLwEAJ' AS lead_id, '6aba4a41bef13dbb21a2c4a7' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000imGCQEA2' AS lead_id, '6ad3252ad488cd0ea46ae267' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000HTN5tEAH' AS lead_id, '6ac8bb9b7b8d7f542dbb8c7c' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000Kt5A1EAJ' AS lead_id, '6ab8c8051a15ab80295cf48d' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000i6SRmEAM' AS lead_id, '6ad99f5d4e69bacf695c0254' AS seller_id, 'L1c' AS dnp_bucket),
    STRUCT('00Qfu000002dQVfEAM' AS lead_id, '6ac73f43e87a144b4dc785df' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000fzFIiEAM' AS lead_id, '6ac7888be87a144b4dd162ce' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000gnmJREAY' AS lead_id, '6abbe3461a15ab80298dc203' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000IXp1OEAT' AS lead_id, '6ad89e8489d8e8ce92df16ab' AS seller_id, 'L1c' AS dnp_bucket),
    STRUCT('00Qfu000002UgFVEA0' AS lead_id, '6ac87c87e87a144b4ddae5b1' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu00000jOuvBEAS' AS lead_id, '6adb7ae74e69bacf697baa12' AS seller_id, 'L1a' AS dnp_bucket),
    STRUCT('00Qfu00000hYReZEAW' AS lead_id, '6ac0b364e87a144b4d63ffbb' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000iztJBEAY' AS lead_id, '6ad5f25f89d8e8ce92ba97c1' AS seller_id, 'L1c' AS dnp_bucket),
    STRUCT('00Qfu000002MjmbEAC' AS lead_id, '6abccfb39d2f2be926444a17' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000j9mI1EAI' AS lead_id, '6ad887c089d8e8ce92dc329b' AS seller_id, 'L1a' AS dnp_bucket),
    STRUCT('00Qfu00000eFdRtEAK' AS lead_id, '6ac50900e87a144b4da4809e' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000hcLttEAE' AS lead_id, '6ac1eb8f7b8d7f542d4c99d7' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000fY5vKEAS' AS lead_id, '6aad3982ae9568e283ef0d46' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000fj266EAA' AS lead_id, '6aae2a54ae9568e283f959ae' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000i3IjuEAE' AS lead_id, '6ad37aa2d488cd0ea473a5a8' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000g5zSUEAY' AS lead_id, '6ab0f629b84fed6e95075867' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu00000j06d1EAA' AS lead_id, '6ad6005976fcbf9595db2437' AS seller_id, 'L1c' AS dnp_bucket),
    STRUCT('00Qfu00000hXDP7EAO' AS lead_id, '6ad877b589d8e8ce92da306b' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000iRhnWEAS' AS lead_id, '6ace4e1ca33cc138bec40faa' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000i0vhhEAA' AS lead_id, '6aca0155e87a144b4df9006d' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000iic8MEAQ' AS lead_id, '6ad3b8fb60eec5eb1b20f6cd' AS seller_id, 'L1b' AS dnp_bucket),
    STRUCT('00Qfu00000iJV0PEAW' AS lead_id, '6accd57860c6a935ba001505' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu000002Mnb0EAC' AS lead_id, '6ad3768cd488cd0ea473682b' AS seller_id, 'L1a' AS dnp_bucket),
    STRUCT('00Qfu00000ciB6pEAE' AS lead_id, '6a7d9a3dc291e6c3f2beb881' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu00000hxBoIEAU' AS lead_id, '6ac75e59e87a144b4dcb7b5d' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000hYlQQEA0' AS lead_id, '6ac0d0937b8d7f542d415e80' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000giBScEAM' AS lead_id, '6aba85f67dc4e000c21b417a' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000eM7rqEAC' AS lead_id, '6ab54bf3f7e3e62094cffbd7' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000i8sJdEAI' AS lead_id, '6aca222e01760dab2fb2074c' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000VXG7NEAX' AS lead_id, '6ac8a3ba7b8d7f542db912d3' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu00000Q0pupEAB' AS lead_id, '6ac347f27b8d7f542d5c48d6' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu000002KjTFEA0' AS lead_id, '6ac8d1837b8d7f542dbd9c69' AS seller_id, 'L1c' AS dnp_bucket),
    STRUCT('00Qfu00000eIZY9EAO' AS lead_id, '6aabdbababcf3087ac115816' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu000002Y2OSEA0' AS lead_id, '6ac9be88e87a144b4deec408' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000hNqDFEA0' AS lead_id, '6ac39fdbd5cc441817cf546f' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000hsxwpEAA' AS lead_id, '6ace30be93f783cf6122f728' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000io3atEAA' AS lead_id, '6ad31f2cd488cd0ea46a5c62' AS seller_id, 'L1b' AS dnp_bucket),
    STRUCT('00Qfu00000iKiI7EAK' AS lead_id, '6ace4c43e26d7dce5426302b' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu000002Z0wSEAS' AS lead_id, '6acc97dc7b8d7f542dee4ad0' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu000002YhjjEAC' AS lead_id, '6ac8b1b97b8d7f542dba7f5a' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu000002S8p0EAC' AS lead_id, '6ad5d0ec89d8e8ce92b67fd2' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000hmvOGEAY' AS lead_id, '6ac4dd04e87a144b4da1c119' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000H3MQREA3' AS lead_id, '6ad2279760eec5eb1b0caae9' AS seller_id, 'L1c' AS dnp_bucket),
    STRUCT('00QJ2000004CBITMA4' AS lead_id, '6ad07e05847d8a8acde0c4a7' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu000002Mo8PEAS' AS lead_id, '6accad777b8d7f542df15c12' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000hOweoEAC' AS lead_id, '6abe41dc7b8d7f542d1b583e' AS seller_id, 'L3?' AS dnp_bucket),
    STRUCT('00Qfu000002MzV3EAK' AS lead_id, '6ad207557bcb42ad6b222cc1' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu00000akJSkEAM' AS lead_id, '6aba2190bef13dbb219dbd71' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu00000hsFuBEAU' AS lead_id, '6ad3671460eec5eb1b1e2eee' AS seller_id, 'L1a' AS dnp_bucket),
    STRUCT('00Qfu00000icm2NEAQ' AS lead_id, '6ad0b4fbe26d7dce544bf395' AS seller_id, 'L1b' AS dnp_bucket),
    STRUCT('00Qfu00000iRZzlEAG' AS lead_id, '6ad4847dd488cd0ea479538c' AS seller_id, 'L1b' AS dnp_bucket),
    STRUCT('00Qfu00000JJo7tEAD' AS lead_id, '6abbcf07bef13dbb21bd6b66' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00QJ2000004Cg9LMAS' AS lead_id, '6ad0a892e31636fbd7f2de53' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu00000arwsMEAQ' AS lead_id, '6a5e2b9b9d4eaaf22dd9bfe7' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000fOXL0EAO' AS lead_id, '6aa524f8ae9568e283811abc' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000RBO15EAH' AS lead_id, '6ab7c11b1a15ab8029548813' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu000002S7tEEAS' AS lead_id, '6ad33797d488cd0ea46d4ad6' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000iHmzlEAC' AS lead_id, '6accbb4b7fb255b9ea5eed55' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000fCRpdEAG' AS lead_id, '6aa3ce58ae9568e2836f050d' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000b0kbqEAA' AS lead_id, '6aba01341a15ab80296a4e89' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000f0sQdEAI' AS lead_id, '6aa283b1b442516a182f2e0b' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000hnQK2EAM' AS lead_id, '6ac4f3eee87a144b4da38145' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000gpQLHEA2' AS lead_id, '6ac4cc307b8d7f542d78a03e' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000hXpeBEAS' AS lead_id, '6ac729aee87a144b4dc424e0' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000hpeQtEAI' AS lead_id, '6ad1e262d488cd0ea4587cb4' AS seller_id, 'L1b' AS dnp_bucket),
    STRUCT('00QJ2000004CxulMAC' AS lead_id, '6abdec18e87a144b4d34b7c9' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000GKpRnEAL' AS lead_id, '6ad0c48ae26d7dce544d80d7' AS seller_id, 'L1a' AS dnp_bucket),
    STRUCT('00Qfu00000hsCY9EAM' AS lead_id, '6acf7525d488cd0ea4364dbf' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000iaOCAEA2' AS lead_id, '6ad0b2efd488cd0ea447f864' AS seller_id, 'L1a' AS dnp_bucket),
    STRUCT('00Qfu00000Pae8eEAB' AS lead_id, '6ac607dce87a144b4db33870' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000fqdldEAA' AS lead_id, '6aace4a1abcf3087ac1e8cbd' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000iVuhOEAS' AS lead_id, '6ad219580be3ec46625cb338' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000f3CmdEAE' AS lead_id, '6aa106a8e3d2629f9bc3efbc' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000hl6sTEAQ' AS lead_id, '6ac49dc4e87a144b4d999bd4' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu00000iTmsqEAC' AS lead_id, '6acf26b9683c16ed94ed7212' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000iQGSoEAO' AS lead_id, '6ace20ffe26d7dce5424391a' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000UAQMYEA5' AS lead_id, '6aa25d6ce3d2629f9bd8a80e' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000faImnEAE' AS lead_id, '6acf3b55e26d7dce54322a27' AS seller_id, 'L1b' AS dnp_bucket),
    STRUCT('00QJ2000004C9AxMAK' AS lead_id, '6ac62f067b8d7f542d913a2b' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00QJ2000004C6sPMAS' AS lead_id, '6ac7c093e87a144b4dd52a9a' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000gT7IsEAK' AS lead_id, '6ab6549bc5e1761670bb3572' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu000002aJkUEAU' AS lead_id, '6acf22a1e26d7dce542f2b5a' AS seller_id, 'L1b' AS dnp_bucket),
    STRUCT('00Qfu00000f2TvyEAE' AS lead_id, '6aae3770ae9568e283fb503f' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000iVJ9uEAG' AS lead_id, '6acf3e6bd488cd0ea42f9c82' AS seller_id, 'L1c' AS dnp_bucket),
    STRUCT('00Qfu00000elMMHEA2' AS lead_id, '6abd03da7b8d7f542d0753d7' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000hvPtlEAE' AS lead_id, '6ad0bd87d488cd0ea4495e34' AS seller_id, 'L1a' AS dnp_bucket),
    STRUCT('00Qfu00000ScTNqEAN' AS lead_id, '6ace24b183f23f7b25ef2105' AS seller_id, 'L1c' AS dnp_bucket),
    STRUCT('00Qfu000005QsUwEAK' AS lead_id, '6ace2ddce26d7dce542504fa' AS seller_id, 'L1b' AS dnp_bucket),
    STRUCT('00Qfu00000fpetSEAQ' AS lead_id, '6abca4f81a15ab8029953f63' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu00000f6U3tEAE' AS lead_id, '6aa138cfe3d2629f9bc8909a' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000g5GVSEA2' AS lead_id, '6ac0ae7c2ba23c57c6f4c7ff' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu00000gYhOwEAK' AS lead_id, '6ab7cbdbbef13dbb21865b4e' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000deLFOEA2' AS lead_id, '6acf7816d488cd0ea4368530' AS seller_id, 'L1a' AS dnp_bucket),
    STRUCT('00Qfu00000i9FzPEAU' AS lead_id, '6aca42057b8d7f542dd766a3' AS seller_id, 'L1c' AS dnp_bucket),
    STRUCT('00QJ2000004CKgUMAW' AS lead_id, '6aae1f1c4e9add2ca38c8b9a' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000fQfzBEAS' AS lead_id, '6ab63b16825cd58646621e88' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu000002a9hyEAA' AS lead_id, '6ac357da7b8d7f542d5e365a' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000exrPVEAY' AS lead_id, '6ab66ad6f152a249273181f9' AS seller_id, 'L3' AS dnp_bucket),
    STRUCT('00Qfu000002UEREEA4' AS lead_id, '6ac638b97b8d7f542d920ac6' AS seller_id, 'L1b' AS dnp_bucket),
    STRUCT('00Qfu00000gFP2lEAG' AS lead_id, '6ab65815f152a2492730767b' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000LtbZ7EAJ' AS lead_id, '6ac8c20de87a144b4de31c78' AS seller_id, 'L1a' AS dnp_bucket),
    STRUCT('00Qfu000002a6DOEAY' AS lead_id, '6a549213ef3ebefe92eee454' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000i3kElEAI' AS lead_id, '6ac8e80b109aaa43b9959828' AS seller_id, 'L1c' AS dnp_bucket),
    STRUCT('00Qfu00000i4bisEAA' AS lead_id, '6aca517f7b8d7f542dd8009e' AS seller_id, 'L1c' AS dnp_bucket),
    STRUCT('00Qfu000005umFBEAY' AS lead_id, '6acc6ac7e87a144b4d0ef95e' AS seller_id, 'L1a' AS dnp_bucket),
    STRUCT('00Qfu00000gHNMcEAO' AS lead_id, '6aba35a6c022292b9511a9cc' AS seller_id, 'L4' AS dnp_bucket),
    STRUCT('00Qfu00000gXaNtEAK' AS lead_id, '6ab79b46bef13dbb21819b8f' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu00000KQr0SEAT' AS lead_id, '6ab7cdf1bef13dbb218677ab' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu000002Ypb9EAC' AS lead_id, '6acca126e87a144b4d160a6d' AS seller_id, 'L2' AS dnp_bucket),
    STRUCT('00Qfu000002dNu5EAE' AS lead_id, '6ab8efc1bef13dbb218edb10' AS seller_id, 'L3' AS dnp_bucket)
  ])
)
SELECT
  d.dnp_bucket,               -- L1 = never really reached, L2/L3/L4 = reached
  d.lead_id, d.seller_id,
  l.<PERF_COLS>,              -- e.g. lead_source, sub_source, utm_source, utm_campaign, created_date
  CASE <PERF_RULE> END AS perf_version   -- e.g. WHEN l.utm_campaign LIKE '%v2%' THEN 'new_perf' ELSE 'old_perf'
FROM dnp d
LEFT JOIN `<LEAD_TABLE>` l
  ON l.id = d.lead_id         -- check the key name: id / lead_id / sf_lead_id
ORDER BY perf_version, d.dnp_bucket;


-- ---------- Q2: the split you asked for (wrap Q1 as a CTE named q1) ----------
-- SELECT perf_version,
--        COUNT(*)                                   AS dnp_sellers,
--        COUNTIF(dnp_bucket = 'L1')                 AS never_reached,
--        SAFE_DIVIDE(COUNTIF(dnp_bucket = 'L1'), COUNT(*)) AS pct_never_reached
-- FROM q1
-- GROUP BY perf_version;
