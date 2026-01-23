-- Test function sfipf009k00r05
-- Run with test data already loaded
SELECT 'Testing sfipf009k00r05...' as status;
SELECT sfipf009k00r05('0') as result;

-- Check results
SELECT 'Results in kozajyohokoshin_list_wk:' as label, COUNT(*)::text as cnt 
FROM rh_mufg_ipa.kozajyohokoshin_list_wk 
WHERE itaku_kaisha_cd = 'TEST';

-- Show data
SELECT * FROM rh_mufg_ipa.kozajyohokoshin_list_wk 
WHERE itaku_kaisha_cd = 'TEST' 
LIMIT 5;

-- Check if mhakkotai was updated
SELECT itaku_kaisha_cd, hkt_cd, koza_ten_cd, koza_ten_cifcd, bd_koza_kamoku_cd, bd_koza_no
FROM rh_mufg_ipa.mhakkotai
WHERE itaku_kaisha_cd = 'TEST';
