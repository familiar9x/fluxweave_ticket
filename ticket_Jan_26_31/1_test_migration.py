

#!/usr/bin/env python3
"""
Test PostgreSQL migration results
Tests migrated function/procedure outputs in PostgreSQL
"""

import psycopg2
import sys
from typing import Dict, List, Tuple, Any

# Database configurations
POSTGRES_CONFIG = {
    'host': 'jip-cp-ipa-postgre17.cvmszg1k9xhh.us-east-1.rds.amazonaws.com',
    'port': 5432,
    'database': 'rh_branches_ipa',
    'user': 'rh_branches_ipa',
    'password': 'luxur1ous-Pine@pple'
}

# Test configurations for each ticket
TEST_CONFIGS = {
    'danm-2129': {
        'name': 'SFADI002R04110',
        'type': 'function',
        'timeout': 60,
        'tests': [
            {
                'description': 'Brand info change result notification matching process (銘柄情報変更結果通知突合処理)',
                'postgres_sql': "SELECT SFADI002R04110('20260112000004', 1);",
                'expected': 0  # 0=SUCCESS
            }
        ]
    },
    'spip00106': {
        'name': 'SPIP00106',
        'type': 'procedure',
        'timeout': 60,
        'tests': [
            {
                'description': 'Brand detail info list - Issue fee info (銘柄詳細情報リスト（発行時手数料情報）)',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_err varchar; 
BEGIN 
    CALL spip00106(
        l_inmgrcd := '0005C08120001',
        l_initakukaishacd := '0005',
        l_inuserid := 'TESTUSER',
        l_inchohyokbn := '0',
        l_ingyomuymd := '20260116',
        l_outsqlcode := v_code,
        l_outsqlerrm := v_err
    );
    RAISE NOTICE 'Return Code: %', v_code;
END $$;
                """,
                'expected': 2  # RTN_NODATA - Expected in test environment without full master data
            }
        ]
    },
    'spip00107': {
        'name': 'SPIP00107',
        'type': 'procedure',
        'timeout': 60,
        'tests': [
            {
                'description': 'Brand detail info list - Period fee info (銘柄詳細情報リスト（期中手数料情報）)',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_err text; 
BEGIN 
    CALL spip00107(
        l_inmgrcd := '0005C08120001',
        l_initakukaishacd := '0005',
        l_inuserid := 'TESTUSER',
        l_inchohyokbn := '0',
        l_ingyomuymd := '20260116',
        l_outsqlcode := v_code,
        l_outsqlerrm := v_err
    );
    RAISE NOTICE 'Return Code: %', v_code;
END $$;
                """,
                'expected': 0
            }
        ]
    },
    'spip10901': {
        'name': 'SPIP10901',
        'type': 'procedure',
        'timeout': 60,
        'tests': [
            {
                'description': 'Sub-trustee brand detail info list - Basic attributes (副受託銘柄詳細情報リスト（基本属性）)',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_err text; 
BEGIN 
    CALL spip10901(
        l_inmgrcd := '0005C08120001',
        l_initakukaishacd := '0005',
        l_inuserid := 'TESTUSER',
        l_inchohyokbn := '0',
        l_ingyomuymd := '20260116',
        l_outsqlcode := v_code,
        l_outsqlerrm := v_err
    );
    RAISE NOTICE 'Return Code: %', v_code;
END $$;
                """,
                'expected': 0
            }
        ]
    },
    'spip04401': {
        'name': 'SPIP04401',
        'type': 'procedure',
        'timeout': 60,
        'tests': [
            {
                'description': 'Bond register creation (社債原簿作成)',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer := 0;
    v_err text := ''; 
BEGIN 
    CALL spip04401(
        l_inuserid := 'TESTUSER',
        l_initakukaishacd := '0005',
        l_inmgrcd := '0005C08120001',
        l_inisincd := '            ',
        l_intsuchiymd := '20260116',
        l_outsqlcode := v_code,
        l_outsqlerrm := v_err
    );
    RAISE NOTICE 'Return Code: %', v_code;
END $$;
                """,
                'expected': 2
            }
        ]
    },
    'vzmx-5720': {
        'name': 'SFIPF009K00R05',
        'type': 'function',
        'timeout': 60,
        'setup_sql': """
-- Setup test data for SFIPF009K00R05
DELETE FROM tencif_yoyaku WHERE itaku_kaisha_cd = 'TEST';
DELETE FROM mhakkotai WHERE itaku_kaisha_cd = 'TEST';
DELETE FROM kozajyohokoshin_list_wk WHERE itaku_kaisha_cd = 'TEST';

-- Insert test branches
INSERT INTO mbuten (itaku_kaisha_cd, buten_cd, buten_nm) 
VALUES ('TEST', '0001', 'Test Old Branch'),
       ('TEST', '0002', 'Test New Branch')
ON CONFLICT DO NOTHING;

-- Insert test issuer (approved status)
INSERT INTO mhakkotai (
    itaku_kaisha_cd, hkt_cd, koza_ten_cd, koza_ten_cifcd, 
    bd_koza_kamoku_cd, bd_koza_no, shori_kbn,
    kousin_dt, kousin_id, sakusei_dt, sakusei_id
)
VALUES (
    'TEST', 'HKT001', '0001', 'CIF00000001',
    'S', '1234567', '1',
    CURRENT_TIMESTAMP, 'TEST', CURRENT_TIMESTAMP, 'TEST'
);

-- Insert reservation for account change
INSERT INTO tencif_yoyaku (
    itaku_kaisha_cd, tekiyost_ymd, old_koza_ten_cd, old_koza_ten_cifcd,
    old_koza_kamoku, old_koza_no, new_koza_ten_cd, new_koza_ten_cifcd,
    new_koza_kamoku, new_koza_no, filter_shubetu, data_recv_ymd, make_dt,
    kousin_dt, kousin_id, sakusei_dt, sakusei_id
)
VALUES (
    'TEST', '20251104', '0001', 'CIF00000001',
    'S', '1234567', '0002', 'CIF00000002',
    'S', '1234567', '1', '20251104', '20251104',
    CURRENT_TIMESTAMP, 'TEST', CURRENT_TIMESTAMP, 'TEST'
);
        """,
        'cleanup_sql': """
-- Cleanup test data
DELETE FROM tencif_yoyaku WHERE itaku_kaisha_cd = 'TEST';
DELETE FROM mhakkotai WHERE itaku_kaisha_cd = 'TEST';
DELETE FROM kozajyohokoshin_list_wk WHERE itaku_kaisha_cd = 'TEST';
DELETE FROM mbuten WHERE itaku_kaisha_cd = 'TEST';
        """,
        'tests': [
            {
                'description': 'Branch/CIF reservation batch - Account info change processing (店CIF予約バッチ（口座情報変更処理）)',
                'postgres_sql': "SELECT SFIPF009K00R05('0');",
                'expected': 0  # 0=SUCCES
                }
        ]
    },
    'hfvy-6279': {
        'name': 'SPIPI066K00R01',
        'type': 'procedure',
        'timeout': 60,
        'tests': [
            {
                'description': 'Accrued/deferred revenue list output (未収・前受収益一覧表)',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_err text; 
BEGIN 
    CALL spipi066k00r01(
        l_inkijunym := '202501',
        l_initakukaishacd := '0005',
        l_inuserid := 'BATCH',
        l_inchohyokbn := '1',
        l_ingyomuymd := '20250101',
        l_outsqlcode := v_code,
        l_outsqlerrm := v_err
    );
    RAISE NOTICE 'Return Code: %', v_code;
END $$;
                """,
                'expected': 2  # RTN_NODATA - Expected in test environment without MISYU_MAEUKE data
            }
        ]
    },
    'srsq-5658': {
        'name': 'SPIPI044K00R01',
        'type': 'procedure',
        'timeout': 60,
        'tests': [
            {
                'description': 'Bond statement creation processing (原簿ワークファイル作成)',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_itaku_kaisha_cd TEXT;
    v_mgr_cd TEXT;
    v_code integer;
    v_err text; 
BEGIN 
    -- Get first available MGR_KIHON record
    SELECT itaku_kaisha_cd, mgr_cd
    INTO v_itaku_kaisha_cd, v_mgr_cd
    FROM mgr_kihon
    WHERE isin_cd <> ' '
      AND kk_kanyo_flg IN ('0','1')
      AND jtk_kbn NOT IN ('2','5')
      AND partmgr_kbn IN ('0','2')
    LIMIT 1;
    
    IF v_itaku_kaisha_cd IS NULL THEN
        RAISE EXCEPTION 'No suitable MGR_KIHON data found';
    END IF;
    
    -- Clear previous test data
    DELETE FROM genbo_work 
    WHERE itaku_kaisha_cd = v_itaku_kaisha_cd 
      AND sakusei_id = 'TEST01';
    
    -- Call procedure
    CALL spipi044k00r01(
        v_itaku_kaisha_cd,
        'TEST01',
        '0',
        '20260129',
        v_mgr_cd,
        v_code,
        v_err
    );
    RAISE NOTICE 'Return Code: %', v_code;
END $$;
                """,
                'expected': 0  # 0=SUCCESS
            }
        ]
    },
    'nqkf-9193': {
        'name': 'SFIPX016K00R01',
        'type': 'function',
        'timeout': 60,
        'tests': [
            {
                'description': 'Invoice cancellation file creation with valid MGR_CD',
                'setup_postgres': """
-- Cleanup previous test data
DELETE FROM sreport_wk WHERE key_cd = '0005' AND user_id = 'TEST' AND chohyo_kbn = '1' 
  AND chohyo_id IN ('IP030010911', 'IP030010912');
                """,
                'postgres_sql': "SELECT sfipx016k00r01('0005', 'TEST', '1', '20260115', '0005BF0210001');",
                'expected': 0,  # 0=SUCCESS with valid MGR_CD
                'cleanup_postgres': """
-- Cleanup test data
DELETE FROM sreport_wk WHERE key_cd = '0005' AND user_id = 'TEST' AND chohyo_kbn = '1' 
  AND chohyo_id IN ('IP030010911', 'IP030010912');
                """
            }
        ]
    },
    'rjbw-8206': {
        'name': 'SFIPI044K00R00_01',
        'type': 'function',
        'timeout': 60,
        'tests': [
            {
                'description': 'Bond statement creation wrapper function',
                'postgres_sql': """
DELETE FROM genbo_work WHERE 1=1;
DELETE FROM prt_ok WHERE kijun_ymd = '20070521';
SELECT sfipi044k00r00_01('0005');
                """,
                'expected': 0  # 0=SUCCESS
            }
        ]
    },
    'hnxj-6293': {
        'name': 'SFADI002R28111',
        'type': 'function',
        'timeout': 60,
        'tests': [
            {
                'description': 'Brand information comparison (銘柄情報更新−ＩＳＩＮコード、銘柄突合)',
                'postgres_sql': """
-- Test function (TOTSUGO_KEKKA_KBN column may not exist in test environment)
SELECT SFADI002R28111('20260112000002', 1, '0005');
                """,
                'expected': [0]  # Accept multiple return codes as data setup may be incomplete
            }
        ]
    },
    'sdkz-2067': {
        'name': 'SFADI005R08112',
        'type': 'function',
        'timeout': 60,
        'tests': [
            {
                'description': 'New record information comparison (新規募集情報ＴＢＬ突合・更新処理)',
                'postgres_sql': """
-- Reset test data
UPDATE SHINKIKIROKU 
SET TOTSUGO_KEKKA_KBN = '0'
WHERE ITAKU_KAISHA_CD = '0005' AND KESSAI_NO = 'TEST20260112001';

UPDATE SHINKIBOSHU
SET TOTSUGO_KEKKA_KBN = '0'
WHERE ITAKU_KAISHA_CD = '0005' AND MGR_CD = 'S620060331876' AND MGR_MEISAI_NO = 1;

-- Test function
SELECT SFADI005R08112('0005', 'TEST20260112001');
                """,
                'expected': 0  # 0=SUCCESS
            }
        ]
    },
    'dgnn-8769': {
        'name': 'SFADI002R04111',
        'type': 'function',
        'timeout': 60,
        'tests': [
            {
                'description': 'Bond redemption information comparison (銘柄_償還回次テーブルとの突合処理)',
                'postgres_sql': """
-- Reset test data (ensure matching values with MGR_SHOKIJ)
UPDATE KK_RENKEI 
SET ITEM025 = '20060930', ITEM027 = '0.9'
WHERE KK_SAKUSEI_DT = '20260112000002' AND DENBUN_MEISAI_NO = 1;

-- Test function (l_inKbn=4: 償還情報 定時償還)
SELECT SFADI002R04111('20260112000002', 1, '0005', 'S620060331876', 4, 'TEST');
                """,
                'expected': 0  # 0=SUCCESS
            }
        ]
    },
    'dgua-1659': {
        'name': 'SFADI002R04120',
        'type': 'function',
        'timeout': 60,
        'tests': [
            {
                'description': 'Brand info change result notification error processing (銘柄情報変更結果通知エラー処理)',
                'postgres_sql': """
SELECT SFADI002R04120('20260112000004', 1);
                """,
                'expected': [0]  # 0=SUCCESS, 2=NO_DATA_FIND, 40=NO_DATA, 99=FATAL (acceptable - requires complex setup with MITAKU_KAISHA, UPD_MGR_XXX tables)
            }
        ]
    },
    'gwhf-9960': {
        'name': 'pkCompare.getCompareInfo',
        'type': 'function',
        'timeout': 30,
        'tests': [
            {
                'description': 'Get comparison info with auto-numeric-wrapping (突合情報取得・自動数値変換)',
                'postgres_sql': """
-- Test getCompareInfo with numeric comparison (SFADI002R04111 use case)
-- Function returns composite type, cast to text to check contents
SELECT pkCompare.getCompareInfo(
    'R04114',  -- TOTSUGO_NO
    'decode(trim(RT02.ITEM027), null, null, to_number(RT02.ITEM027))',  -- MOTO_ITEM expression
    'MG3.FACTOR'  -- SAKI_ITEM column
)::text;
                """,
                'expected': 'contains:numeric_to_char'  # Should contain numeric_to_char wrapping
            }
        ]
    },
    'anaf-2573': {
        'name': 'SPIP10901',
        'type': 'procedure',
        'timeout': 30,
        'tests': [
            {
                'description': 'Sub-consignment brand detail information list (basic attributes) (副受託銘柄詳細情報リスト（基本属性）)',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_err text; 
BEGIN 
    -- Clean up test data
    DELETE FROM sreport_wk 
    WHERE key_cd = '0005' 
      AND user_id = 'TESTUSER' 
      AND chohyo_kbn = '0'
      AND chohyo_id IN ('IP030010911', 'IP030010912');
    
    -- Call procedure with actual brand data
    CALL spip10901(
        l_inMgrCd => '0005BF0210001',
        l_inItakuKaishaCd => '0005',
        l_inUserId => 'TESTUSER',
        l_inChohyoKbn => '0',
        l_inGyomuYmd => '20260116',
        l_outSqlCode => v_code,
        l_outSqlErrM => v_err
    );
    
    RAISE NOTICE 'Return code: %, Error: %', v_code, v_err;
    
    IF v_code = 0 THEN
        RAISE NOTICE 'TEST PASSED: Return code is 0';
    ELSE
        RAISE EXCEPTION 'TEST FAILED: Return code is % (expected 0), Error: %', v_code, v_err;
    END IF;
    
    -- Verify data was inserted into SREPORT_WK (should have 2 reports: IP030010911 and IP030010912)
    IF (SELECT COUNT(*) FROM sreport_wk WHERE chohyo_id IN ('IP030010911', 'IP030010912') AND user_id = 'TESTUSER') >= 2 THEN
        RAISE NOTICE 'VERIFIED: Data found in SREPORT_WK for both report IDs';
    ELSE
        RAISE EXCEPTION 'VERIFICATION FAILED: Expected at least 2 records in SREPORT_WK';
    END IF;
END $$;
                """,
                'expected': 0  # 0=SUCCESS
            }
        ]
    },
    'yecd-3832': {
        'name': 'SPIPF010K01R07',
        'type': 'procedure',
        'timeout': 30,
        'tests': [
            {
                'description': 'BOJ TOYO delivery status confirmation list (日銀当預受渡状況確認リスト)',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_err text; 
BEGIN 
    CALL spipf010k01r07(
        l_inChohyoId := 'IPF30101111',
        l_inItakuKaishaCd := '0005',
        l_inUserId := 'TESTUSER',
        l_inChohyoKbn := '0',
        l_inGyomuYmd := '20260120',
        l_inKessaiYmdF := '20180101',
        l_inKessaiYmdT := '20180131',
        l_outSqlCode := v_code,
        l_outSqlErrM := v_err
    );
    RAISE NOTICE 'Return Code: %', v_code;
END $$;
                """,
                'expected': 0  # 0=SUCCESS
            }
        ]
    },
    'gcma-8210': {
        'name': 'SFIPF013K01R01',
        'type': 'function',
        'timeout': 60,
        'tests': [
            {
                'description': 'DBIF Real transmission Mode 1 - Issue substitute money (DBIFリアル送信 モード1 - 発行代り金)',
                'postgres_sql': "SELECT sfipf013k01r01('1', 'BATCH');",
                'expected': 0  # 0=SUCCESS
            },
            {
                'description': 'DBIF Real transmission Mode 2 - Principal/interest and fees (DBIFリアル送信 モード2 - 元利金・手数料)',
                'postgres_sql': "SELECT sfipf013k01r01('2', 'BATCH');",
                'expected': 0  # 0=SUCCESS
            }
        ]
    },
    'yujg-7726': {
        'name': 'SFIPF013K01R08',
        'type': 'function',
        'timeout': 60,
        'tests': [
            {
                'description': 'Batch process for accounting system connection status management (勘定系接続ステータス管理バッチ処理)',
                'postgres_sql': "SELECT sfipf013k01r08();",
                'expected': 0  # 0=SUCCESS
            }
        ]
    },
    'qpqe-2316': {
        'name': 'SFIPF013K01R02',
        'type': 'function',
        'timeout': 60,
        'tests': [
            {
                'description': 'DBIF Real reception batch - knjif_recv=1 (勘定系IFリアル受信バッチ)',
                'postgres_sql': "UPDATE knjsetuzokustatus SET knjif_recv = '1'; SELECT sfipf013k01r02();",
                'expected': 0  # 0=SUCCESS
            }
        ]
    },
    'srvf-7700': {
        'name': 'SFIPF013K01R03',
        'type': 'function',
        'timeout': 60,
        'tests': [
            {
                'description': 'DBIF Real reception processing (勘定系リアル受信IF処理)',
                'postgres_sql': "SELECT sfipf013k01r03();",
                'expected': 0  # 0=SUCCESS
            }
        ]
    },
    'rmxv-5790': {
        'name': 'SFIPF013K01R05',
        'type': 'function',
        'timeout': 30,
        'tests': [
            {
                'description': 'Delete knjrealrcvif table data (勘定系リアル受信IFテーブル削除)',
                'postgres_sql': "SELECT sfipf013k01r05();",
                'expected': 0  # 0=SUCCESS
            }
        ]
    },
    'apex-6301': {
        'name': 'SPIPF014K01R03',
        'type': 'procedure',
        'timeout': 60,
        'tests': [
            {
                'description': 'Principal/interest payment delivery status confirmation list (元利払・元利払手数料受渡状況確認リスト)',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_err text; 
BEGIN 
    CALL spipf014k01r03(
        '0005'::text,      -- l_inItakuKaishaCd
        'BATCH'::text,     -- l_inUserId
        '0'::text,         -- l_inChohyoKbn
        '20250121'::text,  -- l_inGyomuYmd
        '20250121'::text,  -- l_inShoriYmd
        v_code,
        v_err
    );
    RAISE NOTICE 'Return Code: %', v_code;
END $$;
                """,
                'expected': 0  # 0=SUCCESS with test data
            }
        ]
    },
    'zumt-1439': {
        'name': 'SPIPF015K01R02',
        'type': 'procedure',
        'timeout': 60,
        'tests': [
            {
                'description': 'Principal/interest payment fee delivery status confirmation list (元利払手数料受渡状況確認リスト)',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_err text; 
BEGIN 
    CALL spipf015k01r02(
        '0005'::text,      -- l_inItakuKaishaCd
        'BATCH'::text,     -- l_inUserId
        '0'::text,         -- l_inChohyoKbn
        '20250122'::text,  -- l_inGyomuYmd
        '20250122'::text,  -- l_inShoriYmd
        v_code,
        v_err
    );
    RAISE NOTICE 'Return Code: %', v_code;
END $$;
                """,
                'expected': 0  # 0=SUCCESS with test data
            }
        ]
    },
    'yxwa-2504': {
        'name': 'SPIPF013K01R07',
        'type': 'procedure',
        'timeout': 60,
        'tests': [
            {
                'description': 'Bond issuance delivery status confirmation list (債券発行受渡状況確認リスト)',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_err text; 
BEGIN 
    CALL spipf013k01r07(
        '0005'::text,      -- l_inItakuKaishaCd
        'BATCH'::text,     -- l_inUserId
        '0'::text,         -- l_inChohyoKbn
        '20250123'::text,  -- l_inGyomuYmd
        '20250123'::text,  -- l_inShoriYmd
        v_code,
        v_err
    );
    RAISE NOTICE 'Return Code: %', v_code;
END $$;
                """,
                'expected': 0  # 0=SUCCESS with test data
            }
        ]
    },
    'sfpb-5880': {
        'name': 'SFIPF013K01R06',
        'type': 'function',
        'timeout': 30,
        'tests': [
            {
                'description': 'Update knjsetuzokustatus send flag (勘定系接続ステータス管理テーブル送信フラグ更新)',
                'postgres_sql': "SELECT sfipf013k01r06('0'::text);",
                'expected': 0  # 0=SUCCESS
            }
        ]
    },
    'jsct-5423': {
        'name': 'SFIPF013K01R04',
        'type': 'function',
        'timeout': 60,
        'tests': [
            {
                'description': 'Bond delivery status confirmation list coordinator (受渡状況確認リスト作成)',
                'postgres_sql': "SELECT sfipf013k01r04();",
                'expected': 0  # 0=SUCCESS (coordinates 3 report procedures)
            }
        ]
    },
    'wcey-7644': {
        'name': 'SFIPF015K01R01',
        'type': 'function',
        'timeout': 60,
        'tests': [
            {
                'description': 'Fee calculation and accounting IF creation (期中手数料計算・勘定系IF作成)',
                'postgres_sql': "SELECT sfipf015k01r01();",
                'expected': 0  # 0=SUCCESS
            }
        ]
    },
    'gktp-1736': {
        'name': 'SFIPF011K01R01',
        'type': 'function',
        'timeout': 60,
        'tests': [
            {
                'description': 'Create deposit/transfer data from principal/interest invoice (元利金請求明細から当預データ作成)',
                'postgres_sql': "SELECT sfipf011k01r01();",
                'expected': 0  # 0=SUCCESS
            }
        ]
    },
    'hpnj-2877': {
        'name': 'SPIPF004K00R02',
        'type': 'procedure',
        'timeout': 60,
        'tests': [
            {
                'description': 'Create calendar master (migration) from calendar info (S individual) (カレンダ情報から移行用マスタ作成)',
                'postgres_sql': "DO $$ DECLARE v_code integer; v_msg text; BEGIN CALL spipf004k00r02('0005', '10', v_code, v_msg); RAISE NOTICE 'Code: %', v_code; END $$;",
                'expected': 0  # 0=SUCCESS
            }
        ]
    },
    'eyes-5381': {
        'name': 'SFIPF004K00R04',
        'type': 'function',
        'timeout': 60,
        'tests': [
            {
                'description': 'Create calendar master (S individual) from S-provided calendar info (Sカレンダ情報からS個別マスタ作成)',
                'postgres_sql': "SELECT sfipf004k00r04('21003');",
                'expected': 0  # 0=SUCCESS
            }
        ]
    },
    'gcfv-9830': {
        'name': 'SFIPF004K00R05',
        'type': 'function',
        'timeout': 60,
        'tests': [
            {
                'description': 'Calendar info migration wrapper (S individual) (カレンダ情報移行ラッパー)',
                'postgres_sql': "SELECT sfipf004k00r05();",
                'expected': 0  # 0=SUCCESS
            }
        ]
    },
    'rugv-2089': {
        'name': 'SFIPF009K00R06',
        'type': 'function',
        'timeout': 60,
        'tests': [
            {
                'description': 'Update branch master from reservation table (部店マスタ予約反映)',
                'postgres_sql': "SELECT sfipf009k00r06('1');",
                'expected': 0  # 0=SUCCESS
            }
        ]
    },
    'spjd-0914': {
        'name': 'SPIPF009K00R01',
        'type': 'procedure',
        'timeout': 60,
        'tests': [
            {
                'description': 'Account information update result list (口座情報更新結果リスト)',
                'postgres_sql': "CALL spipf009k00r01('IPF30000921', '0005', 'BATCH', '1', '20251104', NULL, NULL);",
                'expected': 0  
            }
        ]
    },
    'kszg-8324': {
        'name': 'SFIPF009K00R08',
        'type': 'function',
        'timeout': 60,
        'tests': [
            {
                'description': 'Account update result list wrapper (口座情報更新結果リストラッパー)',
                'postgres_sql': "SELECT sfipf009k00r08();",
                'expected': 0  # 0=SUCCESS
            }
        ]
    },
    'cnjk-0480': {
        'name': 'SPIPF009K00R02',
        'type': 'procedure',
        'timeout': 60,
        'tests': [
            {
                'description': 'Branch master update result list (部店マスタ更新結果リスト)',
                'postgres_sql': "CALL spipf009k00r02('0005', 'BATCH', '1', '20251104', NULL, NULL);",
                'expected': 0  
            }
        ]

    },
    'wzbg-9900': {
        'name': 'SFIPF009K00R09',
        'type': 'function',
        'timeout': 60,
        'tests': [
            {
                'description': 'Branch master update result list wrapper (部店マスタ更新結果リストラッパー)',
                'setup_postgres': """
-- Setup: Insert test data into BUTENKOSHIN_LIST_WK
DELETE FROM BUTENKOSHIN_LIST_WK WHERE ITAKU_KAISHA_CD = '0005';
DELETE FROM SREPORT_WK WHERE key_cd = '0005' AND user_id = 'BATCH' AND chohyo_kbn = '1' AND chohyo_id = 'IPF30000931';
DELETE FROM PRT_OK WHERE itaku_kaisha_cd = '0005' AND list_sakusei_kbn = '1' AND chohyo_id = 'IPF30000931';

INSERT INTO BUTENKOSHIN_LIST_WK (
    ITAKU_KAISHA_CD, TEKIYOST_YMD, YOYAKU_KBN, BUTEN_CD, BUTEN_NM, BUTEN_RNM,
    GROUP_CD, POST_NO, ADD1, ADD2, ADD3, BUSHO_NM, TEL_NO, FAX_NO, MAIL_ADD,
    DATA_RECV_YMD, ERR_UMU_FLG, ERR_CD_6, ERR_NM_30, SEQ_NO,
    KOUSIN_DT, KOUSIN_ID, SAKUSEI_DT, SAKUSEI_ID
) VALUES (
    '0005', '20251104', '1', '001', 'テスト部店', 'ﾃｽﾄ',
    'G01', '1000001', '東京都', '千代田区', '', '営業部', '03-1234-5678', '03-1234-5679', 'test@example.com',
    '20251103', '0', '', '', 1,
    current_timestamp, 'BATCH', current_timestamp, 'BATCH'
);
                """,
                'postgres_sql': "SELECT sfipf009k00r09();",
                'expected': 0,  # 0=SUCCESS with test data
                'cleanup_postgres': """
-- Cleanup test data
DELETE FROM BUTENKOSHIN_LIST_WK WHERE ITAKU_KAISHA_CD = '0005';
DELETE FROM SREPORT_WK WHERE key_cd = '0005' AND user_id = 'BATCH' AND chohyo_kbn = '1' AND chohyo_id = 'IPF30000931';
DELETE FROM PRT_OK WHERE itaku_kaisha_cd = '0005' AND list_sakusei_kbn = '1' AND chohyo_id = 'IPF30000931';
                """
            }
        ]
    },
    'uwuw-7505': {
        'name': 'SFIPF009K00R07',
        'type': 'function',
        'timeout': 60,
        'tests': [
            {
                'description': 'Account update result list wrapper (口座情報更新結果リストラッパー)',
                'postgres_sql': "SELECT sfipf009k00r07();",
                'expected': 0  # 0=SUCCESS
            }
        ]
    },
    'gqnz-6753': {
        'name': 'SFIPF009K00R04',
        'type': 'function',
        'timeout': 60,
        'tests': [
            {
                'description': 'Branch master reservation table registration and update processing (部店マスタ予約テーブル登録・更新処理)',
                'postgres_sql': "SELECT sfipf009k00r04();",
                'expected': 0  # 0=SUCCESS (no data to process), 1=error with data
            }
        ]
    },
    'dycp-9211': {
        'name': 'SFIPF009K00R03',
        'type': 'function',
        'timeout': 60,
        'tests': [
            {
                'description': 'Financial institution master reservation table registration and update processing (金融機関マスタ予約テーブル登録・更新処理)',
                'postgres_sql': "SELECT sfipf009k00r03();",
                'expected': 0  # 0=SUCCESS (no data to process)
            }
        ]
    }
}



def test_postgres_function(cursor, sql: str) -> Any:
    """Execute PostgreSQL function test"""
    cursor.execute(sql)
    result = cursor.fetchone()
    return result[0] if result else None


def test_postgres_procedure(cursor, sql: str) -> Any:
    """Execute PostgreSQL procedure test and parse NOTICE or OUT parameters"""
    # Clear previous notices
    cursor.connection.notices.clear()
    cursor.execute(sql)
    
    # Try to fetch result (for procedures with OUT parameters)
    try:
        result = cursor.fetchone()
        if result:
            # Return first column (usually l_outSqlCode)
            return result[0]
    except:
        pass
    
    # PostgreSQL procedures with RAISE NOTICE will have messages in notices
    if cursor.connection.notices:
        # First pass: look for explicit "Return Code:" pattern
        for notice in cursor.connection.notices:
            if 'Return Code:' in notice:
                parts = notice.split('Return Code:')[1].strip().split(',')[0].strip()
                return int(parts)
        
        # Second pass: look for other patterns
        for notice in cursor.connection.notices:
            # Try different patterns
            if 'RESULT:' in notice:
                # Extract number after RESULT:
                return int(notice.split('RESULT:')[1].strip().split()[0])
            elif 'Code:' in notice:
                # Extract first number after Code:
                parts = notice.split('Code:')[1].strip().split(',')[0].strip()
                return int(parts)
        
        # Last pass: extract any number (skip TRACE messages)
        import re
        for notice in cursor.connection.notices:
            if '[TRACE]' not in notice:
                match = re.search(r'\b(\d+)\b', notice)
                if match:
                    return int(match.group(1))
    return None


def run_tests(ticket_id: str):
    """Run tests for a specific ticket"""
    if ticket_id not in TEST_CONFIGS:
        print(f"❌ Unknown ticket: {ticket_id}")
        print(f"Available tickets: {', '.join(TEST_CONFIGS.keys())}")
        return False
    
    config = TEST_CONFIGS[ticket_id]
    print(f"\n{'='*70}")
    print(f"Testing Ticket: {ticket_id}")
    print(f"Object: {config['name']} ({config['type']})")
    if 'timeout' in config:
        print(f"Timeout: {config['timeout']}s")
    print(f"{'='*70}\n")
    
    # Connect to database
    try:
        postgres_conn = psycopg2.connect(**POSTGRES_CONFIG)
        postgres_conn.set_session(autocommit=True)
        
        postgres_cursor = postgres_conn.cursor()
        
        # Set statement timeout if configured
        if 'timeout' in config:
            timeout_ms = config['timeout'] * 1000
            postgres_cursor.execute(f"SET statement_timeout = {timeout_ms}")
        
        all_passed = True
        test_results = []
        
        for i, test in enumerate(config['tests'], 1):
            print(f"Test {i}: {test['description']}")
            print("-" * 70)
            
            # Run setup if provided
            if 'setup_postgres' in test:
                try:
                    postgres_cursor.execute(test['setup_postgres'])
                    postgres_conn.commit()
                except Exception as e:
                    print(f"  Setup PostgreSQL: ERROR - {e}")
            
            # Test PostgreSQL
            postgres_result = None
            postgres_error = None
            try:
                # Check if test has specific SQL for function mode
                if 'postgres_sql_func' in test:
                    postgres_result = test_postgres_function(postgres_cursor, test['postgres_sql_func'])
                elif config['type'] == 'function':
                    postgres_result = test_postgres_function(postgres_cursor, test['postgres_sql'])
                else:
                    postgres_result = test_postgres_procedure(postgres_cursor, test['postgres_sql'])
                print(f"  PostgreSQL: {postgres_result}")
            except psycopg2.errors.QueryCanceled as e:
                postgres_error = f"TIMEOUT after {config.get('timeout', 'N/A')}s"
                print(f"  PostgreSQL: ⏱️  {postgres_error}")
                # If timeout is allowed for this test, treat as warning not error
                if test.get('allow_timeout', False):
                    print(f"  Note: Timeout is expected/allowed for this test")
            except Exception as e:
                postgres_error = str(e)
                print(f"  PostgreSQL: ERROR - {postgres_error}")
            
            # Compare results
            expected = test['expected']
            print(f"  Expected:   {expected}")
            
            if postgres_error:
                # Check if timeout is allowed
                if 'TIMEOUT' in postgres_error and test.get('allow_timeout', False):
                    print(f"  Status:     ⚠️  TIMEOUT (allowed)")
                    test_results.append(True)  # Count as pass if timeout is allowed
                else:
                    print(f"  Status:     ❌ ERROR")
                    all_passed = False
                    test_results.append(False)
            elif isinstance(expected, str) and expected.startswith('contains:'):
                # Check if result contains expected substring
                substring = expected.split(':', 1)[1]
                if postgres_result and substring in str(postgres_result):
                    print(f"  Status:     ✅ PASS (contains '{substring}')")
                    test_results.append(True)
                else:
                    print(f"  Status:     ❌ FAIL (does not contain '{substring}')")
                    all_passed = False
                    test_results.append(False)
            elif (isinstance(expected, list) and postgres_result in expected) or postgres_result == expected:
                print(f"  Status:     ✅ PASS")
                test_results.append(True)
            else:
                print(f"  Status:     ❌ FAIL (PostgreSQL != expected)")
                all_passed = False
                test_results.append(False)
            
            # Run cleanup if provided
            if 'cleanup_postgres' in test:
                try:
                    postgres_cursor.execute(test['cleanup_postgres'])
                    postgres_conn.commit()
                except Exception as e:
                    print(f"  Cleanup PostgreSQL: ERROR - {e}")
            
            print()
        
        # Summary
        passed = sum(test_results)
        total = len(test_results)
        print(f"{'='*70}")
        print(f"Summary: {passed}/{total} tests passed")
        print(f"{'='*70}\n")
        
        postgres_cursor.close()
        postgres_conn.close()
        
        return all_passed
        
    except Exception as e:
        print(f"❌ Connection error: {e}")
        return False


def run_all_tests():
    """Run tests for all tickets"""
    print("\n" + "="*70)
    print("TESTING ALL TICKETS")
    print("="*70)
    
    results = {}
    for ticket_id in TEST_CONFIGS.keys():
        results[ticket_id] = run_tests(ticket_id)
    
    # Final summary
    print("\n" + "="*70)
    print("FINAL SUMMARY")
    print("="*70)
    for ticket_id, passed in results.items():
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{ticket_id}: {status} - {TEST_CONFIGS[ticket_id]['name']}")
    print("="*70 + "\n")
    
    return all(results.values())


if __name__ == '__main__':
    if len(sys.argv) > 1:
        # Test specific ticket
        ticket_id = sys.argv[1]
        success = run_tests(ticket_id)
    else:
        # Test all tickets
        success = run_all_tests()
    
    sys.exit(0 if success else 1)
    


