-- Clean up test data first
DELETE FROM rh_mufg_ipa.tencif_yoyaku WHERE itaku_kaisha_cd = 'TEST';
DELETE FROM rh_mufg_ipa.mhakkotai WHERE itaku_kaisha_cd = 'TEST';
DELETE FROM rh_mufg_ipa.kozajyohokoshin_list_wk WHERE itaku_kaisha_cd = 'TEST';

-- Insert test branch data (mbuten)
INSERT INTO rh_mufg_ipa.mbuten (itaku_kaisha_cd, buten_cd, buten_nm, last_teisei_dt, last_teisei_id, kousin_id, sakusei_id)
VALUES 
    ('TEST', '0001', 'Test Old Branch', CURRENT_TIMESTAMP, 'BATCH', 'BATCH', 'BATCH'),
    ('TEST', '0002', 'Test New Branch', CURRENT_TIMESTAMP, 'BATCH', 'BATCH', 'BATCH')
ON CONFLICT (itaku_kaisha_cd, buten_cd) DO NOTHING;

-- Insert test issuer (mhakkotai) with OLD account info - Status: APPROVED (1)
INSERT INTO rh_mufg_ipa.mhakkotai (
    itaku_kaisha_cd, hkt_cd, hkt_nm, 
    koza_ten_cd, koza_ten_cifcd,
    bd_koza_kamoku_cd, bd_koza_no,
    hkt_koza_kamoku_cd, hkt_koza_no,
    hko_kamoku_cd, hko_koza_no,
    shori_kbn,
    last_teisei_dt, last_teisei_id, kousin_id, sakusei_id
)
VALUES 
    ('TEST', 'HKT001', 'Test Issuer 1', 
     '0001', 'CIF00000001',
     'S', '1234567',
     '1', '2234567',
     '2', '3234567',
     '1', -- APPROVED status
     CURRENT_TIMESTAMP, 'BATCH', 'BATCH', 'BATCH')
ON CONFLICT (itaku_kaisha_cd, hkt_cd) DO UPDATE SET
    koza_ten_cd = EXCLUDED.koza_ten_cd,
    koza_ten_cifcd = EXCLUDED.koza_ten_cifcd,
    bd_koza_kamoku_cd = EXCLUDED.bd_koza_kamoku_cd,
    bd_koza_no = EXCLUDED.bd_koza_no,
    shori_kbn = EXCLUDED.shori_kbn;

-- Insert test reservation (tencif_yoyaku) - change from branch 0001 to 0002
INSERT INTO rh_mufg_ipa.tencif_yoyaku (
    itaku_kaisha_cd, tekiyost_ymd,
    old_koza_ten_cd, old_koza_ten_cifcd,
    old_koza_kamoku, old_koza_no,
    new_koza_ten_cd, new_koza_ten_cifcd,
    new_koza_kamoku, new_koza_no,
    filter_shubetu, data_recv_ymd, make_dt,
    kousin_id, sakusei_id
)
VALUES (
    'TEST', '20251104',
    '0001', 'CIF00000001',
    'S', '1234567',
    '0002', 'CIF00000002',
    'S', '9876543',
    '1 ', '20251104', '20251104',
    'BATCH', 'BATCH'
)
ON CONFLICT (itaku_kaisha_cd, tekiyost_ymd, old_koza_ten_cd, old_koza_ten_cifcd, old_koza_kamoku, old_koza_no) 
DO NOTHING;

-- Verify test data
SELECT 'tencif_yoyaku count:' as label, COUNT(*)::text as cnt FROM rh_mufg_ipa.tencif_yoyaku WHERE itaku_kaisha_cd = 'TEST'
UNION ALL
SELECT 'mhakkotai count:', COUNT(*)::text FROM rh_mufg_ipa.mhakkotai WHERE itaku_kaisha_cd = 'TEST'
UNION ALL
SELECT 'mbuten count:', COUNT(*)::text FROM rh_mufg_ipa.mbuten WHERE itaku_kaisha_cd = 'TEST'
UNION ALL
SELECT 'kozajyohokoshin_list_wk (before):', COUNT(*)::text FROM rh_mufg_ipa.kozajyohokoshin_list_wk WHERE itaku_kaisha_cd = 'TEST';
