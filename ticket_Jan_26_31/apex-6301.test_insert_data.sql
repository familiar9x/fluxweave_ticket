-- Insert test data for apex-6301.SPIPF014K01R03.sql
-- This creates actual data to test with 0, 1, and multiple records

-- =====================================================
-- Setup: Insert base master data
-- =====================================================

-- Insert test company in mitaku (委託会社マスタ)
INSERT INTO mitaku (itaku_kaisha_cd, itaku_kaisha_nm, itaku_kaisha_rnm)
VALUES ('TST001', 'テスト委託会社001', 'テスト会社001')
ON CONFLICT (itaku_kaisha_cd) DO UPDATE 
SET itaku_kaisha_nm = 'テスト委託会社001',
    itaku_kaisha_rnm = 'テスト会社001';

-- Insert test issuer in mhakkotai (発行体マスタ)
INSERT INTO mhakkotai (itaku_kaisha_cd, hkt_cd, hkt_nm, hkt_rnm, koza_ten_cd, koza_ten_cifcd)
VALUES 
('TST001', 'HKT001', 'テスト発行体001', 'テスト発行01', 'TEN001', 'CIF001'),
('TST001', 'HKT002', 'テスト発行体002', 'テスト発行02', 'TEN002', 'CIF002')
ON CONFLICT (itaku_kaisha_cd, hkt_cd) DO UPDATE 
SET hkt_nm = EXCLUDED.hkt_nm,
    hkt_rnm = EXCLUDED.hkt_rnm,
    koza_ten_cd = EXCLUDED.koza_ten_cd,
    koza_ten_cifcd = EXCLUDED.koza_ten_cifcd;

-- Insert test department in mbuten (部店マスタ)
INSERT INTO mbuten (itaku_kaisha_cd, buten_cd, buten_nm, buten_rnm)
VALUES 
('TST001', 'BUT001', 'テスト部店001', 'テスト部01'),
('TST001', 'BUT002', 'テスト部店002', 'テスト部02')
ON CONFLICT (itaku_kaisha_cd, buten_cd) DO UPDATE 
SET buten_nm = EXCLUDED.buten_nm,
    buten_rnm = EXCLUDED.buten_rnm;

-- Insert code master data for S10 (入出金区分)
INSERT INTO scode (code_shubetsu, code_value, code_nm, code_rnm)
VALUES 
('S10', '5', '支払済', '支払済'),
('S10', '1', '未処理', '未処理')
ON CONFLICT (code_shubetsu, code_value) DO UPDATE 
SET code_nm = EXCLUDED.code_nm,
    code_rnm = EXCLUDED.code_rnm;

-- Insert code master data for S11 (口座科目)
INSERT INTO scode (code_shubetsu, code_value, code_nm, code_rnm)
VALUES 
('S11', '01', '普通預金', '普通'),
('S11', '02', '当座預金', '当座')
ON CONFLICT (code_shubetsu, code_value) DO UPDATE 
SET code_nm = EXCLUDED.code_nm,
    code_rnm = EXCLUDED.code_rnm;

-- =====================================================
-- Test Case 1: Insert data that will return 0 records
-- =====================================================
-- No data with matching criteria (different SHORI_KBN or SHORI_YMD)

DELETE FROM knjganrikichuif 
WHERE itaku_kaisha_cd = 'TST001';

-- Insert data with wrong SHORI_KBN (not '2')
INSERT INTO knjganrikichuif (
    itaku_kaisha_cd, knj_shori_ymd, knj_shori_kbn, hkt_cd,
    knj_inout_kbn, knj_err_code, knj_uke_tsuban, knj_uke_tsuban_zenkai,
    knj_gankin, knj_rkn, knj_gnkn_shr_tesu_kngk, knj_rkn_shr_tesu_kngk,
    knj_kingaku, knj_shohizei, knj_ten_no, knj_kamoku, knj_kouza_no
) VALUES (
    'TST001', '20260127', '1', 'HKT001',  -- SHORI_KBN = '1' (not '2')
    '5', '', '00001', '',
    1000000, 50000, 1000, 500,
    1051500, 51500, 'BUT001', '01', '1234567'
);

-- Insert data with wrong SHORI_YMD
INSERT INTO knjganrikichuif (
    itaku_kaisha_cd, knj_shori_ymd, knj_shori_kbn, hkt_cd,
    knj_inout_kbn, knj_err_code, knj_uke_tsuban, knj_uke_tsuban_zenkai,
    knj_gankin, knj_rkn, knj_gnkn_shr_tesu_kngk, knj_rkn_shr_tesu_kngk,
    knj_kingaku, knj_shohizei, knj_ten_no, knj_kamoku, knj_kouza_no
) VALUES (
    'TST001', '20260126', '2', 'HKT001',  -- SHORI_YMD = '20260126' (not '20260127')
    '5', '', '00002', '',
    2000000, 100000, 2000, 1000,
    2103000, 103000, 'BUT001', '01', '7654321'
);

RAISE NOTICE '=== Test Case 1: Data inserted with non-matching criteria ===';

-- =====================================================
-- Test Case 2: Insert matching data (should return records)
-- =====================================================

-- Insert matching data that should be returned
INSERT INTO knjganrikichuif (
    itaku_kaisha_cd, knj_shori_ymd, knj_shori_kbn, hkt_cd,
    knj_inout_kbn, knj_err_code, knj_uke_tsuban, knj_uke_tsuban_zenkai,
    knj_gankin, knj_rkn, knj_gnkn_shr_tesu_kngk, knj_rkn_shr_tesu_kngk,
    knj_kingaku, knj_shohizei, knj_ten_no, knj_kamoku, knj_kouza_no
) VALUES 
-- Record 1: 支払済 (KNJ_INOUT_KBN = '5')
(
    'TST001', '20260127', '2', 'HKT001',
    '5', '', '10001', '',
    1000000, 50000, 1000, 500,
    1051500, 51500, 'BUT001', '01', '1111111'
),
-- Record 2: 支払済 (KNJ_INOUT_KBN = '5')
(
    'TST001', '20260127', '2', 'HKT002',
    '5', '', '10002', '10001',
    2000000, 100000, 2000, 1000,
    2103000, 103000, 'BUT002', '02', '2222222'
),
-- Record 3: 未処理 (KNJ_INOUT_KBN = '1')
(
    'TST001', '20260127', '2', 'HKT001',
    '1', 'E001', '10003', '',
    500000, 25000, 500, 250,
    525750, 25750, 'BUT001', '01', '3333333'
)
ON CONFLICT DO NOTHING;

RAISE NOTICE '=== Test Case 2: Matching data inserted ===';

-- Verify inserted data
SELECT 
    COUNT(*) as total_records,
    COUNT(*) FILTER (WHERE knj_shori_kbn = '2' AND knj_shori_ymd = '20260127') as matching_records
FROM knjganrikichuif
WHERE itaku_kaisha_cd = 'TST001';

-- =====================================================
-- Ready to test
-- =====================================================
RAISE NOTICE '=== Test data setup completed ===';
RAISE NOTICE 'To test with 0 records: CALL spipf014k01r03(''TST001'', ''TESTUSER'', ''0'', ''20260127'', ''20260128'', NULL, NULL);';
RAISE NOTICE 'To test with 3 records: CALL spipf014k01r03(''TST001'', ''TESTUSER'', ''0'', ''20260127'', ''20260127'', NULL, NULL);';
