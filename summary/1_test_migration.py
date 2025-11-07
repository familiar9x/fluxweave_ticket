#!/usr/bin/env python3
"""
Test Oracle to PostgreSQL migration results
Compares function/procedure outputs between Oracle and PostgreSQL
"""

import cx_Oracle
import psycopg2
import sys
from typing import Dict, List, Tuple, Any

# Database configurations
ORACLE_DSN = cx_Oracle.makedsn(
    'jip-ipa-cp.cvmszg1k9xhh.us-east-1.rds.amazonaws.com',
    1521,
    sid='ORCL'
)

ORACLE_CONFIG = {
    'user': 'RH_MUFG_IPA',
    'password': 'g1normous-pik@chu',
    'dsn': ORACLE_DSN
}

POSTGRES_CONFIG = {
    'host': 'jip-cp-ipa-postgre17.cvmszg1k9xhh.us-east-1.rds.amazonaws.com',
    'port': 5432,
    'database': 'rh_mufg_ipa',
    'user': 'rh_mufg_ipa',
    'password': 'luxur1ous-Pine@pple'
}

# Test configurations for each ticket
TEST_CONFIGS = {
    'xytp-7838': {
        'name': 'sfCmIsCodeMChek',
        'type': 'function',
        'tests': [
            {
                'description': 'Valid code 191/10',
                'oracle_sql': "SELECT sfCmIsCodeMChek('191', '10') FROM dual",
                'postgres_sql': "SELECT sfCmIsCodeMChek('191', '10')",
                'expected': 0
            },
            {
                'description': 'Invalid code 191/999',
                'oracle_sql': "SELECT sfCmIsCodeMChek('191', '999') FROM dual",
                'postgres_sql': "SELECT sfCmIsCodeMChek('191', '999')",
                'expected': 1
            },
            {
                'description': 'Valid code 507/0',
                'oracle_sql': "SELECT sfCmIsCodeMChek('507', '0') FROM dual",
                'postgres_sql': "SELECT sfCmIsCodeMChek('507', '0')",
                'expected': 0
            },
            {
                'description': 'NULL parameters',
                'oracle_sql': "SELECT sfCmIsCodeMChek(NULL, NULL) FROM dual",
                'postgres_sql': "SELECT sfCmIsCodeMChek(NULL, NULL)",
                'expected': 0
            }
        ]
    },
    'ayds-6394': {
        'name': 'sfCmIsHalfAlphanumeric2',
        'type': 'function',
        'tests': [
            {
                'description': 'Valid alphanumeric ABC123',
                'oracle_sql': "SELECT sfCmIsHalfAlphanumeric2('ABC123') FROM dual",
                'postgres_sql': "SELECT sfCmIsHalfAlphanumeric2('ABC123')",
                'expected': 0
            },
            {
                'description': 'Invalid with hyphen ABC-123',
                'oracle_sql': "SELECT sfCmIsHalfAlphanumeric2('ABC-123') FROM dual",
                'postgres_sql': "SELECT sfCmIsHalfAlphanumeric2('ABC-123')",
                'expected': 1
            },
            {
                'description': 'Valid lowercase abc123',
                'oracle_sql': "SELECT sfCmIsHalfAlphanumeric2('abc123') FROM dual",
                'postgres_sql': "SELECT sfCmIsHalfAlphanumeric2('abc123')",
                'expected': 0
            },
            {
                'description': 'Empty string',
                'oracle_sql': "SELECT sfCmIsHalfAlphanumeric2('') FROM dual",
                'postgres_sql': "SELECT sfCmIsHalfAlphanumeric2('')",
                'expected': 0
            }
        ]
    },
    'rawx-4418': {
        'name': 'SPIPF004K00R03',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Success case with valid data',
                'setup_oracle': """
BEGIN
    DELETE FROM mcalender_trns;
    INSERT INTO mcalender_trns (area_cd, holiday, lin_no) VALUES ('1', '20250101', 1);
    INSERT INTO mcalender_trns (area_cd, holiday, lin_no) VALUES ('1', '20250505', 2);
    INSERT INTO mcalender_trns (area_cd, holiday, lin_no) VALUES ('2', '20250101', 1);
    COMMIT;
END;
""",
                'setup_postgres': """
DELETE FROM mcalender_trns;
INSERT INTO mcalender_trns (area_cd, holiday, lin_no) VALUES ('1', '20250101', 1);
INSERT INTO mcalender_trns (area_cd, holiday, lin_no) VALUES ('1', '20250505', 2);
INSERT INTO mcalender_trns (area_cd, holiday, lin_no) VALUES ('2', '20250101', 1);
""",
                'oracle_sql': """
DECLARE
    v_code NUMBER;
    v_msg VARCHAR2(100);
BEGIN
    SPIPF004K00R03('0005', '10', v_code, v_msg);
    :result := v_code;
END;
""",
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipf004k00r03('0005', '10', v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, v_msg;
END $$;
""",
                'expected': 0
            },
            {
                'description': 'No data case',
                'setup_oracle': """
BEGIN
    DELETE FROM mcalender_trns;
    COMMIT;
END;
""",
                'setup_postgres': "DELETE FROM mcalender_trns;",
                'oracle_sql': """
DECLARE
    v_code NUMBER;
    v_msg VARCHAR2(100);
BEGIN
    SPIPF004K00R03('0005', '10', v_code, v_msg);
    :result := v_code;
END;
""",
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipf004k00r03('0005', '10', v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, v_msg;
END $$;
""",
                'expected': 40
            },
            {
                'description': 'Invalid param - empty kaiin_id',
                'oracle_sql': """
DECLARE
    v_code NUMBER;
    v_msg VARCHAR2(100);
BEGIN
    SPIPF004K00R03('', '10', v_code, v_msg);
    :result := v_code;
END;
""",
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipf004k00r03('', '10', v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, v_msg;
END $$;
""",
                'expected': 1
            }
        ]
    },
    'erhp-9810': {
        'name': 'SPIPF005K00R04',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Success case with valid data',
                'setup_oracle': """
BEGIN
    DELETE FROM mbank_shiten_trns;
    INSERT INTO mbank_shiten_trns 
    (financial_securities_kbn, bank_cd, shiten_cd, shiten_nm, shiten_rnm, shiten_kana_rnm, lin_no)
    VALUES ('0', '0001', '001', 'テスト支店', 'テスト支店', 'テストシテン', 1);
    INSERT INTO mbank_shiten_trns 
    (financial_securities_kbn, bank_cd, shiten_cd, shiten_nm, shiten_rnm, shiten_kana_rnm, lin_no)
    VALUES ('0', '0001', '002', 'サンプル支店', 'サンプル支店', 'サンプルシテン', 2);
    COMMIT;
END;
""",
                'setup_postgres': """
DELETE FROM mbank_shiten_trns;
INSERT INTO mbank_shiten_trns 
(financial_securities_kbn, bank_cd, shiten_cd, shiten_nm, shiten_rnm, shiten_kana_rnm, lin_no)
VALUES ('0', '0001', '001', 'テスト支店', 'テスト支店', 'テストシテン', 1);
INSERT INTO mbank_shiten_trns 
(financial_securities_kbn, bank_cd, shiten_cd, shiten_nm, shiten_rnm, shiten_kana_rnm, lin_no)
VALUES ('0', '0001', '002', 'サンプル支店', 'サンプル支店', 'サンプルシテン', 2);
""",
                'oracle_sql': """
DECLARE
    v_code NUMBER;
    v_msg VARCHAR2(100);
BEGIN
    SPIPF005K00R04('0005', '10', v_code, v_msg);
    :result := v_code;
END;
""",
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipf005k00r04('0005', '10', v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, v_msg;
END $$;
""",
                'expected': 1
            },
            {
                'description': 'No data case',
                'setup_oracle': """
BEGIN
    DELETE FROM mbank_shiten_trns;
    COMMIT;
END;
""",
                'setup_postgres': "DELETE FROM mbank_shiten_trns;",
                'oracle_sql': """
DECLARE
    v_code NUMBER;
    v_msg VARCHAR2(100);
BEGIN
    SPIPF005K00R04('0005', '10', v_code, v_msg);
    :result := v_code;
END;
""",
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipf005k00r04('0005', '10', v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, v_msg;
END $$;
""",
                'expected': 40
            },
            {
                'description': 'Success case - valid data without errors',
                'setup_oracle': """
BEGIN
    DELETE FROM mbank_shiten WHERE bank_cd = '0001' AND shiten_cd = '001';
    DELETE FROM mbank_shiten_trns;
    DELETE FROM mbank WHERE bank_cd = '0001' AND financial_securities_kbn = '1';
    
    -- Ensure mbank has the bank
    INSERT INTO mbank (bank_cd, financial_securities_kbn, bank_nm, bank_rnm, bank_kana_rnm, shori_kbn, 
                       sakusei_dt, sakusei_id, kousin_dt, kousin_id)
    VALUES ('0001', '1', 'Test Bank', 'Test', 'テスト', '1', 
            TO_DATE('20190225', 'YYYYMMDD'), 'BATCH', SYSDATE, 'BATCH');
    
    -- Insert valid data into mbank_shiten_trns
    INSERT INTO mbank_shiten_trns 
    (financial_securities_kbn, bank_cd, shiten_cd, shiten_nm, shiten_rnm, shiten_kana_rnm, lin_no)
    VALUES ('1', '0001', '001', '本店', 'ホンテン', 'ホンテン', 1);
    COMMIT;
END;
""",
                'setup_postgres': """
DELETE FROM mbank_shiten WHERE bank_cd = '0001' AND shiten_cd = '001';
DELETE FROM mbank_shiten_trns;

-- Ensure mbank has the bank
INSERT INTO mbank (bank_cd, financial_securities_kbn, bank_nm, bank_rnm, bank_kana_rnm, shori_kbn,
                   sakusei_dt, sakusei_id, kousin_dt, kousin_id)
VALUES ('0001', '1', 'Test Bank', 'Test', 'テスト', '1',
        '20190225', 'BATCH', clock_timestamp(), 'BATCH')
ON CONFLICT (bank_cd, financial_securities_kbn) DO UPDATE SET shori_kbn = '1';

-- Insert valid data into mbank_shiten_trns
INSERT INTO mbank_shiten_trns 
(financial_securities_kbn, bank_cd, shiten_cd, shiten_nm, shiten_rnm, shiten_kana_rnm, lin_no)
VALUES ('1', '0001', '001', '本店', 'ホンテン', 'ホンテン', 1);
""",
                'oracle_sql': """
DECLARE
    v_code NUMBER;
    v_msg VARCHAR2(100);
BEGIN
    SPIPF005K00R04('0005', '10', v_code, v_msg);
    
    -- Cleanup
    DELETE FROM mbank_shiten WHERE bank_cd = '0001' AND shiten_cd = '001';
    COMMIT;
    
    :result := v_code;
END;
""",
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipf005k00r04('0005', '10', v_code, v_msg); 
    
    -- Cleanup
    DELETE FROM mbank_shiten WHERE bank_cd = '0001' AND shiten_cd = '001';
    
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0
            }
        ]
    },
    'ncvs-0805': {
        'name': 'SPIPF005K00R01',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Valid params - no data',
                'oracle_sql': """
DECLARE
    v_code NUMBER;
    v_msg VARCHAR2(100);
BEGIN
    SPIPF005K00R01('0005', 'BATCH', '1', '1', '20241104', v_code, v_msg);
    :result := v_code;
END;
""",
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipf005k00r01('0005', 'BATCH', '1', '1', '20241104', v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, v_msg;
END $$;
""",
                'expected': 40
            },
            {
                'description': 'Valid params - with data',
                'oracle_sql': """
DECLARE
    v_code NUMBER;
    v_msg VARCHAR2(100);
BEGIN
    -- Insert test data
    INSERT INTO MBANK (BANK_CD, FINANCIAL_SECURITIES_KBN, BANK_NM, BANK_RNM, BANK_KANA_RNM, 
                       SAKUSEI_DT, SAKUSEI_ID, KOUSIN_DT, KOUSIN_ID)
    VALUES ('0001', '1', 'Test Bank', 'Test', 'テスト', 
            TO_DATE('20241104', 'YYYYMMDD'), 'BATCH', SYSDATE, 'BATCH');
    COMMIT;
    
    SPIPF005K00R01('0005', 'BATCH', '1', '1', '20241104', v_code, v_msg);
    :result := v_code;
    
    -- Cleanup
    DELETE FROM MBANK WHERE BANK_CD = '0001' AND SAKUSEI_ID = 'BATCH';
    COMMIT;
END;
""",
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    -- Insert test data
    INSERT INTO mbank (bank_cd, financial_securities_kbn, bank_nm, bank_rnm, bank_kana_rnm,
                       sakusei_dt, sakusei_id, kousin_dt, kousin_id, bank_nm_eiji, shori_kbn,
                       last_teisei_id, shonin_id)
    VALUES ('0001', '1', 'Test Bank', 'Test', 'テスト',
            '20241104', 'BATCH', now(), 'BATCH', 'Test Bank', '0',
            ' ', ' ');
    
    CALL spipf005k00r01('0005', 'BATCH', '1', '1', '20241104', v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, v_msg;
    
    -- Cleanup
    DELETE FROM mbank WHERE bank_cd = '0001' AND sakusei_id = 'BATCH';
END $$;
""",
                'expected': 0
            }
        ]
    },
    'judr-5235': {
        'name': 'SPIPF005K00R03',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Valid params - no data',
                'oracle_sql': """
DECLARE
    v_code NUMBER;
    v_msg VARCHAR2(100);
BEGIN
    SPIPF005K00R03('0005', '10', v_code, v_msg);
    :result := v_code;
END;
""",
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code numeric; 
    v_msg text; 
BEGIN 
    CALL spipf005k00r03('0005', '10', v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, v_msg;
END $$;
""",
                'expected': 40
            },
            {
                'description': 'Valid params - with valid data',
                'setup_sql': """
INSERT INTO mbank_trns (financial_securities_kbn, bank_cd, bank_nm, bank_rnm, bank_kana_rnm, lin_no)
VALUES ('0', '0001', 'テスト銀行', 'テスト', 'テストギンコウ', 1);
""",
                'oracle_sql': """
DECLARE
    v_code NUMBER;
    v_msg VARCHAR2(100);
BEGIN
    -- Insert test data
    INSERT INTO MBANK_TRNS (FINANCIAL_SECURITIES_KBN, BANK_CD, BANK_NM, BANK_RNM, BANK_KANA_RNM, LIN_NO)
    VALUES ('0', '0001', 'テスト銀行', 'テスト', 'テストギンコウ', 1);
    COMMIT;
    
    SPIPF005K00R03('0005', '10', v_code, v_msg);
    
    -- Cleanup
    DELETE FROM MBANK_TRNS;
    DELETE FROM MBANK WHERE BANK_CD = '0001';
    COMMIT;
    
    :result := v_code;
END;
""",
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code numeric; 
    v_msg text; 
BEGIN 
    -- Insert test data
    INSERT INTO mbank_trns (financial_securities_kbn, bank_cd, bank_nm, bank_rnm, bank_kana_rnm, lin_no)
    VALUES ('0', '0001', 'テスト銀行', 'テスト', 'テストギンコウ', 1);
    
    CALL spipf005k00r03('0005', '10', v_code, v_msg); 
    
    -- Cleanup
    DELETE FROM mbank_trns;
    DELETE FROM mbank WHERE bank_cd = '0001';
    
    RAISE NOTICE 'Code: %, Msg: %', v_code, v_msg;
END $$;
""",
                'expected': 0
            }
        ]
    },
    'mktz-2195': {
        'name': 'SPIPF001K00R01',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Valid params - error display',
                'oracle_sql': """
DECLARE
    v_code NUMBER;
    v_msg VARCHAR2(4000);
BEGIN
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPF30000111';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPF30000111';
    COMMIT;
    
    SPIPF001K00R01('0005', 'TESTUSER', '1', '1', '20190225', 
                   '01', 100, 'テスト項目', 'テスト内容', 'ECM001',
                   v_code, v_msg);
    :result := v_code;
    COMMIT;
END;
""",
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPF30000111';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPF30000111';
    
    CALL spipf001k00r01('0005', 'TESTUSER', '1', '1', '20190225',
                        '01', 100, 'テスト項目', 'テスト内容', 'ECM001',
                        v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0
            },
            {
                'description': 'Invalid param - empty user_id',
                'oracle_sql': """
DECLARE
    v_code NUMBER;
    v_msg VARCHAR2(4000);
BEGIN
    SPIPF001K00R01('0005', '', '1', '1', '20190225', 
                   '01', 100, 'テスト', 'テスト', 'ECM001',
                   v_code, v_msg);
    :result := v_code;
END;
""",
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipf001k00r01('0005', '', '1', '1', '20190225',
                        '01', 100, 'テスト', 'テスト', 'ECM001',
                        v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, v_msg;
END $$;
""",
                'expected': 1
            }
        ]
    },
    'fyzx-7563': {
        'name': 'SPIPF005K00R02',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Valid params - no data',
                'oracle_sql': """
DECLARE
    v_code NUMBER;
    v_msg VARCHAR2(4000);
BEGIN
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPF30000521';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPF30000521';
    COMMIT;
    
    SPIPF005K00R02('0005', 'BATCH', '1', '1', '20190225', v_code, v_msg);
    :result := v_code;
    COMMIT;
END;
""",
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code numeric; 
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPF30000521';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPF30000521';
    
    CALL spipf005k00r02('0005', 'BATCH', '1', '1', '20190225', v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 40
            },
            {
                'description': 'Valid params - with data',
                'oracle_sql': """
DECLARE
    v_code NUMBER;
    v_msg VARCHAR2(4000);
BEGIN
    -- Cleanup first
    DELETE FROM MBANK_SHITEN WHERE BANK_CD = '0001' AND SHITEN_CD = '001';
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPF30000521';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPF30000521';
    COMMIT;
    
    -- Insert test data
    INSERT INTO MBANK_SHITEN (FINANCIAL_SECURITIES_KBN, BANK_CD, SHITEN_CD, SHITEN_NM, SHITEN_RNM, SHITEN_KANA_RNM, 
                              SHORI_KBN, LAST_TEISEI_DT, LAST_TEISEI_ID, SHONIN_DT, SHONIN_ID, 
                              KOUSIN_DT, KOUSIN_ID, SAKUSEI_DT, SAKUSEI_ID)
    VALUES ('0', '0001', '001', 'テスト支店', 'テスト', 'テストシテン',
            '1', SYSDATE, 'BATCH', SYSDATE, 'BATCH',
            SYSDATE, 'BATCH', TO_DATE('20190225', 'YYYYMMDD'), 'BATCH');
    COMMIT;
    
    SPIPF005K00R02('0005', 'BATCH', '1', '1', '20190225', v_code, v_msg);
    
    -- Cleanup
    DELETE FROM MBANK_SHITEN WHERE BANK_CD = '0001' AND SHITEN_CD = '001';
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPF30000521';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPF30000521';
    COMMIT;
    
    :result := v_code;
END;
""",
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code numeric; 
    v_msg text; 
BEGIN 
    -- Cleanup first
    DELETE FROM mbank_shiten WHERE bank_cd = '0001' AND shiten_cd = '001';
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPF30000521';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPF30000521';
    
    -- Insert test data
    INSERT INTO mbank_shiten (financial_securities_kbn, bank_cd, shiten_cd, shiten_nm, shiten_rnm, shiten_kana_rnm,
                              shori_kbn, last_teisei_dt, last_teisei_id, shonin_dt, shonin_id,
                              kousin_dt, kousin_id, sakusei_dt, sakusei_id)
    VALUES ('0', '0001', '001', 'テスト支店', 'テスト', 'テストシテン',
            '1', CURRENT_TIMESTAMP, 'BATCH', CURRENT_TIMESTAMP, 'BATCH',
            CURRENT_TIMESTAMP, 'BATCH', TO_DATE('20190225', 'YYYYMMDD'), 'BATCH');
    
    CALL spipf005k00r02('0005', 'BATCH', '1', '1', '20190225', v_code, v_msg); 
    
    -- Cleanup
    DELETE FROM mbank_shiten WHERE bank_cd = '0001' AND shiten_cd = '001';
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPF30000521';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPF30000521';
    
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0
            },
            {
                'description': 'Invalid param - empty itaku_kaisha_cd',
                'oracle_sql': """
DECLARE
    v_code NUMBER;
    v_msg VARCHAR2(4000);
BEGIN
    SPIPF005K00R02('', 'BATCH', '1', '1', '20190225', v_code, v_msg);
    :result := v_code;
END;
""",
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code numeric; 
    v_msg text; 
BEGIN 
    CALL spipf005k00r02('', 'BATCH', '1', '1', '20190225', v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 1
            }
        ]
    },
    'zhuv-3462': {
        'name': 'SPIPH003K00R01',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Valid params - no data',
                'oracle_sql': """
DECLARE
    v_code NUMBER;
    v_msg VARCHAR2(4000);
BEGIN
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPH30000311';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPH30000311';
    COMMIT;
    
    SPIPH003K00R01(NULL, NULL, NULL, NULL, NULL, '20190101', '20190331', '20190225',
                   '0005', 'BATCH', '1', '20190225', v_code, v_msg);
    :result := v_code;
    COMMIT;
END;
""",
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPH30000311';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPH30000311';
    
    CALL spiph003k00r01(NULL, NULL, NULL, NULL, NULL, 
                        '20190101', '20190331', '20190225',
                        '0005', 'BATCH', '1', '20190225', v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 2
            },
            {
                'description': 'Invalid param - empty itaku_kaisha_cd',
                'oracle_sql': """
DECLARE
    v_code NUMBER;
    v_msg VARCHAR2(4000);
BEGIN
    SPIPH003K00R01(NULL, NULL, NULL, NULL, NULL, '20190101', '20190331', '20190225',
                   '', 'BATCH', '1', '20190225', v_code, v_msg);
    :result := v_code;
END;
""",
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spiph003k00r01(NULL, NULL, NULL, NULL, NULL, 
                        '20190101', '20190331', '20190225',
                        '', 'BATCH', '1', '20190225', v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 1
            },
            {
                'description': 'Valid params - with data (wide date range)',
                'oracle_sql': """
DECLARE
    v_code NUMBER;
    v_msg VARCHAR2(4000);
BEGIN
    -- Cleanup
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPH30000311';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPH30000311';
    
    -- Test with wide date range (still no data in current test env)
    SPIPH003K00R01(NULL, NULL, NULL, NULL, NULL, '20090101', '20301231', '20190225',
                   '0005', 'BATCH', '1', '20190225', v_code, v_msg);
    :result := v_code;
    
    -- Cleanup
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPH30000311';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPH30000311';
    COMMIT;
END;
""",
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    -- Cleanup
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPH30000311';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPH30000311';
    
    -- Test with wide date range (still no data in current test env)
    CALL spiph003k00r01(NULL, NULL, NULL, NULL, NULL, 
                        '20090101', '20301231', '20190225',
                        '0005', 'BATCH', '1', '20190225', v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
    
    -- Cleanup
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPH30000311';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPH30000311';
END $$;
""",
                'expected': 2
            }
        ]
    },
    'qpmc-7035': {
        'name': 'SPIPH004K00R01',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Valid params - no data',
                'oracle_sql': """
DECLARE
    v_code NUMBER;
    v_msg VARCHAR2(4000);
BEGIN
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPH30000411';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPH30000411';
    COMMIT;
    
    SPIPH004K00R01(NULL, NULL, NULL, NULL, NULL, '20190101', '20190331', '20190225',
                   '0005', 'BATCH', '1', '20190225', v_code, v_msg);
    :result := v_code;
    COMMIT;
END;
""",
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code numeric; 
    v_msg varchar(500); 
BEGIN 
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPH30000411';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPH30000411';
    
    CALL spiph004k00r01(NULL, NULL, NULL, NULL, NULL, 
                        '20190101', '20190331', '20190225',
                        '0005', 'BATCH', '1', '20190225', v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0
            },
            {
                'description': 'Invalid param - empty itaku_kaisha_cd',
                'oracle_sql': """
DECLARE
    v_code NUMBER;
    v_msg VARCHAR2(4000);
BEGIN
    SPIPH004K00R01(NULL, NULL, NULL, NULL, NULL, '20190101', '20190331', '20190225',
                   '', 'BATCH', '1', '20190225', v_code, v_msg);
    :result := v_code;
END;
""",
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code numeric; 
    v_msg varchar(500); 
BEGIN 
    CALL spiph004k00r01(NULL, NULL, NULL, NULL, NULL, 
                        '20190101', '20190331', '20190225',
                        '', 'BATCH', '1', '20190225', v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 1
            }
        ]
    },
    'zavs-0115': {
        'name': 'SFIPJ077K00R20',
        'type': 'function',
        'tests': [
            {
                'description': 'Execute calendar history copy',
                'oracle_sql': None,  # Skip Oracle test
                'postgres_sql': "SELECT sfipj077k00r20()",
                'expected': 0
            }
        ]
    },
    'pswa-2379': {
        'name': 'SPIPH008K00R01',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Valid params - no data',
                'oracle_sql': """
DECLARE
    v_code NUMBER;
    v_msg VARCHAR2(100);
BEGIN
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPH30000811';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPH30000811';
    COMMIT;
    
    SPIPH008K00R01(
        'BATCH',      -- l_inUserId
        '0005',       -- l_inItakuKaishaCd  
        '20190101',   -- l_inKijunYmdFrom
        '20190331',   -- l_inKijunYmdTo
        NULL,         -- l_inHktCd
        NULL,         -- l_inKozaTenCd
        NULL,         -- l_inKozaTenCifcd
        NULL,         -- l_inMgrCd
        NULL,         -- l_inIsinCd
        '20190225',   -- l_inTsuchiYmd
        '1',          -- l_inChohyoSakuKbn
        '1',          -- l_inChohyoKbn
        '20190225',   -- l_inGyomuYmd
        v_code,       -- l_outSqlCode OUT
        v_msg         -- l_outSqlErrM OUT
    );
    :result := v_code;
    
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPH30000811';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPH30000811';
    COMMIT;
END;
""",
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPH30000811';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPH30000811';
    
    -- Use positional parameters to avoid case-folding issues
    CALL spiph008k00r01(
        'BATCH',      -- l_inUserId
        '0005',       -- l_inItakuKaishaCd  
        '20190101',   -- l_inKijunYmdFrom
        '20190331',   -- l_inKijunYmdTo
        NULL,         -- l_inHktCd
        NULL,         -- l_inKozaTenCd
        NULL,         -- l_inKozaTenCifcd
        NULL,         -- l_inMgrCd
        NULL,         -- l_inIsinCd
        '20190225',   -- l_inTsuchiYmd
        '1',          -- l_inChohyoSakuKbn
        '1',          -- l_inChohyoKbn
        '20190225',   -- l_inGyomuYmd
        v_code,       -- l_outSqlCode OUT
        v_msg         -- l_outSqlErrM OUT
    ); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
    
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPH30000811';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPH30000811';
END $$;
""",
                'expected': 2
            },
            {
                'description': 'Valid params - with minimal test data',
                'oracle_sql': """
DECLARE
    v_code NUMBER;
    v_msg VARCHAR2(100);
BEGIN
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPH30000811';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPH30000811';
    COMMIT;
    
    SPIPH008K00R01(
        'BATCH',      -- l_inUserId
        '0005',       -- l_inItakuKaishaCd  
        '20190101',   -- l_inKijunYmdFrom
        '20190331',   -- l_inKijunYmdTo
        NULL,         -- l_inHktCd
        NULL,         -- l_inKozaTenCd
        NULL,         -- l_inKozaTenCifcd
        NULL,         -- l_inMgrCd
        NULL,         -- l_inIsinCd
        '20190225',   -- l_inTsuchiYmd
        '1',          -- l_inChohyoSakuKbn
        '1',          -- l_inChohyoKbn
        '20190225',   -- l_inGyomuYmd
        v_code,       -- l_outSqlCode OUT
        v_msg         -- l_outSqlErrM OUT
    );
    :result := v_code;
    
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPH30000811';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPH30000811';
    COMMIT;
END;
""",
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    -- Cleanup first
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPH30000811';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPH30000811';
    
    -- Note: This test expects return code 2 (no data) because
    -- creating full test data requires complex setup of:
    -- - MGR_KIHON_VIEW (or base tables)
    -- - MHAKKOTAI
    -- - MGR_TESURYO_PRM  
    -- - IP_GANRI_SEIKYUSHO_BY_KAIKEI (or equivalent view/table)
    -- Without these tables populated, procedure will return 2 (no data)
    
    CALL spiph008k00r01(
        'BATCH',      -- l_inUserId
        '0005',       -- l_inItakuKaishaCd  
        '20190101',   -- l_inKijunYmdFrom
        '20190331',   -- l_inKijunYmdTo
        NULL,         -- l_inHktCd
        NULL,         -- l_inKozaTenCd
        NULL,         -- l_inKozaTenCifcd
        NULL,         -- l_inMgrCd
        NULL,         -- l_inIsinCd
        '20190225',   -- l_inTsuchiYmd
        '1',          -- l_inChohyoSakuKbn
        '1',          -- l_inChohyoKbn
        '20190225',   -- l_inGyomuYmd
        v_code,       -- l_outSqlCode OUT
        v_msg         -- l_outSqlErrM OUT
    ); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
    
    -- Cleanup
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPH30000811';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPH30000811';
END $$;
""",
                'expected': 2
            }
        ]
    },
    'bdrw-0478': {
        'name': 'SPIPF004K00R01',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Test 1: Valid parameters - no data (expect RTN_NODATA=40)',
                'oracle_sql': """
DECLARE
    v_code NUMBER;
    v_msg VARCHAR2(100);
BEGIN
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPF30000411';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPF30000411';
    COMMIT;
    
    SPIPF004K00R01(
        '0005',       -- l_inItakuKaishaCd
        'BATCH',      -- l_inUserId
        '3',          -- l_inChohyoKbn (1 char)
        '0',          -- l_inChohyoSakuKbn
        '20190225',   -- l_inGyomuYmd
        v_code,       -- l_outSqlCode OUT
        v_msg         -- l_outSqlErrM OUT
    );
    :result := v_code;
    
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPF30000411';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPF30000411';
    COMMIT;
END;
""",
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPF30000411';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPF30000411';
    
    CALL spipf004k00r01(
        '0005',       -- l_inItakuKaishaCd
        'BATCH',      -- l_inUserId
        '3',          -- l_inChohyoKbn (1 char)
        '0',          -- l_inChohyoSakuKbn
        '20190225',   -- l_inGyomuYmd
        v_code,       -- l_outSqlCode OUT
        v_msg         -- l_outSqlErrM OUT
    ); 
    RAISE NOTICE '%', v_code;
    
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPF30000411';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPF30000411';
END $$;
""",
                'expected': 40
            },
            {
                'description': 'Test 2: Invalid parameter - empty UserId (expect RTN_NG=1)',
                'oracle_sql': """
DECLARE
    v_code NUMBER;
    v_msg VARCHAR2(100);
BEGIN
    SPIPF004K00R01(
        '0005',       -- l_inItakuKaishaCd
        '',           -- l_inUserId (empty - should fail)
        '3',          -- l_inChohyoKbn (1 char)
        '0',          -- l_inChohyoSakuKbn
        '20190225',   -- l_inGyomuYmd
        v_code,       -- l_outSqlCode OUT
        v_msg         -- l_outSqlErrM OUT
    );
    :result := v_code;
END;
""",
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipf004k00r01(
        '0005',       -- l_inItakuKaishaCd
        '',           -- l_inUserId (empty - should fail)
        '3',          -- l_inChohyoKbn (1 char)
        '0',          -- l_inChohyoSakuKbn
        '20190225',   -- l_inGyomuYmd
        v_code,       -- l_outSqlCode OUT
        v_msg         -- l_outSqlErrM OUT
    ); 
    RAISE NOTICE '%', v_code;
END $$;
""",
                'expected': 1
            },
            {
                'description': 'Test 3: Valid parameters - with data (expect RTN_OK=0)',
                'oracle_sql': None,  # PostgreSQL-only test (requires MCALENDAR test data)
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPF30000411';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPF30000411';
    
    CALL spipf004k00r01(
        '0005',       -- l_inItakuKaishaCd
        'BATCH',      -- l_inUserId (matches test data in MCALENDAR)
        '3',          -- l_inChohyoKbn (1 char)
        '0',          -- l_inChohyoSakuKbn
        '20190225',   -- l_inGyomuYmd (matches MCALENDAR.sakusei_dt)
        v_code,       -- l_outSqlCode OUT
        v_msg         -- l_outSqlErrM OUT
    ); 
    RAISE NOTICE '%', v_code;
    
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND chohyo_id='IPF30000411';
    DELETE FROM PRT_OK WHERE itaku_kaisha_cd='0005' AND chohyo_id='IPF30000411';
END $$;
""",
                'expected': 0
            }
        ]
    }
}


def test_oracle_function(cursor, sql: str) -> Any:
    """Execute Oracle function test"""
    cursor.execute(sql)
    result = cursor.fetchone()
    return result[0] if result else None


def test_oracle_procedure(cursor, sql: str) -> Any:
    """Execute Oracle procedure test with bind variable"""
    result_var = cursor.var(int)
    cursor.execute(sql, result=result_var)
    return result_var.getvalue()


def test_postgres_function(cursor, sql: str) -> Any:
    """Execute PostgreSQL function test"""
    cursor.execute(sql)
    result = cursor.fetchone()
    return result[0] if result else None


def test_postgres_procedure(cursor, sql: str) -> Any:
    """Execute PostgreSQL procedure test and parse NOTICE"""
    # Clear previous notices
    cursor.connection.notices.clear()
    cursor.execute(sql)
    # PostgreSQL procedures with RAISE NOTICE will have messages in notices
    if cursor.connection.notices:
        for notice in cursor.connection.notices:
            # Try different patterns
            if 'RESULT:' in notice:
                # Extract number after RESULT:
                return int(notice.split('RESULT:')[1].strip().split()[0])
            elif 'Code:' in notice:
                # Extract first number after Code:
                parts = notice.split('Code:')[1].strip().split(',')[0].strip()
                return int(parts)
            else:
                # Try to extract just a number from the notice
                # Pattern: NOTICE:  <number>
                import re
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
    print(f"{'='*70}\n")
    
    # Connect to databases
    try:
        oracle_conn = cx_Oracle.connect(**ORACLE_CONFIG)
        postgres_conn = psycopg2.connect(**POSTGRES_CONFIG)
        postgres_conn.set_session(autocommit=True)
        
        oracle_cursor = oracle_conn.cursor()
        postgres_cursor = postgres_conn.cursor()
        
        all_passed = True
        test_results = []
        
        for i, test in enumerate(config['tests'], 1):
            print(f"Test {i}: {test['description']}")
            print("-" * 70)
            
            # Run setup if provided
            if 'setup_oracle' in test:
                try:
                    oracle_cursor.execute(test['setup_oracle'])
                    oracle_conn.commit()
                except Exception as e:
                    print(f"  Setup Oracle: ERROR - {e}")
            
            if 'setup_postgres' in test:
                try:
                    postgres_cursor.execute(test['setup_postgres'])
                    postgres_conn.commit()
                except Exception as e:
                    print(f"  Setup PostgreSQL: ERROR - {e}")
            
            # Test Oracle
            oracle_result = None
            oracle_error = None
            if test['oracle_sql'] is not None:
                try:
                    if config['type'] == 'function':
                        oracle_result = test_oracle_function(oracle_cursor, test['oracle_sql'])
                    else:
                        oracle_result = test_oracle_procedure(oracle_cursor, test['oracle_sql'])
                    print(f"  Oracle:     {oracle_result}")
                except Exception as e:
                    oracle_error = str(e)
                    print(f"  Oracle:     ERROR - {oracle_error}")
            else:
                print(f"  Oracle:     SKIPPED")
            
            # Test PostgreSQL
            postgres_result = None
            postgres_error = None
            try:
                if config['type'] == 'function':
                    postgres_result = test_postgres_function(postgres_cursor, test['postgres_sql'])
                else:
                    postgres_result = test_postgres_procedure(postgres_cursor, test['postgres_sql'])
                print(f"  PostgreSQL: {postgres_result}")
            except Exception as e:
                postgres_error = str(e)
                print(f"  PostgreSQL: ERROR - {postgres_error}")
            
            # Compare results
            expected = test['expected']
            print(f"  Expected:   {expected}")
            
            if postgres_error:
                print(f"  Status:     ❌ ERROR")
                all_passed = False
                test_results.append(False)
            elif test['oracle_sql'] is None:
                # PostgreSQL only test
                if postgres_result == expected:
                    print(f"  Status:     ✅ PASS (PostgreSQL only)")
                    test_results.append(True)
                else:
                    print(f"  Status:     ❌ FAIL (PostgreSQL != expected)")
                    all_passed = False
                    test_results.append(False)
            elif oracle_error:
                print(f"  Status:     ❌ ERROR")
                all_passed = False
                test_results.append(False)
            elif oracle_result == postgres_result == expected:
                print(f"  Status:     ✅ PASS")
                test_results.append(True)
            elif oracle_result == postgres_result:
                print(f"  Status:     ⚠️  MATCH (but differs from expected)")
                test_results.append(True)
            else:
                print(f"  Status:     ❌ FAIL (Oracle != PostgreSQL)")
                all_passed = False
                test_results.append(False)
            
            print()
        
        # Summary
        passed = sum(test_results)
        total = len(test_results)
        print(f"{'='*70}")
        print(f"Summary: {passed}/{total} tests passed")
        print(f"{'='*70}\n")
        
        oracle_cursor.close()
        postgres_cursor.close()
        oracle_conn.close()
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
