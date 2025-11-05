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
                'description': 'Valid params - no data',
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
                'description': 'Valid params - no data',
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
    v_code numeric; 
    v_msg text; 
BEGIN 
    CALL spipf005k00r01('0005', 'BATCH', '1', '1', '20241104', v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, v_msg;
END $$;
""",
                'expected': 40
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
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipf005k00r03('0005', '10', v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, v_msg;
END $$;
""",
                'expected': 40
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
    v_msg varchar; 
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
            
            # Test Oracle
            oracle_result = None
            oracle_error = None
            try:
                if config['type'] == 'function':
                    oracle_result = test_oracle_function(oracle_cursor, test['oracle_sql'])
                else:
                    oracle_result = test_oracle_procedure(oracle_cursor, test['oracle_sql'])
                print(f"  Oracle:     {oracle_result}")
            except Exception as e:
                oracle_error = str(e)
                print(f"  Oracle:     ERROR - {oracle_error}")
            
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
            
            if oracle_error or postgres_error:
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
