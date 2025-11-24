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
    'database': 'rh_mufg_ipa',
    'user': 'rh_mufg_ipa',
    'password': 'luxur1ous-Pine@pple'
}

# Test configurations for each ticket
TEST_CONFIGS = {
    'vkem-0740': {
        'name': 'SPIPI062K00R01',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Sales office fee schedule - no data',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE user_id='TESTUSER';
    CALL spipi062k00r01('202501', '', '0005', 'TESTUSER', '1', '20250119', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0  # SUCCESS (compiles and executes correctly)
            },
            {
                'description': 'Sales office fee schedule - success',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE user_id='TESTUSER';
    CALL spipi062k00r01(
        '202501',         -- l_inKijunYm (YYYYMM format)
        '',               -- l_inEigyoTenCd
        '0005',           -- l_inItakuKaishaCd
        'TESTUSER',       -- l_inUserId
        '1',              -- l_inChohyoKbn
        '20250119',       -- l_inGyomuYmd
        v_code,
        v_msg
    );
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0  # SUCCESS
            }
        ]
    },
    'gnwx-5345': {
        'name': 'SPIPI062K00R01_01',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Sales office fee schedule detail - success',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE user_id='TESTUSER';
    CALL spipi062k00r01_01(
        '202501',         -- l_inKijunYm (YYYYMM format)
        '',               -- l_inEigyoTenCd
        '0005',           -- l_inItakuKaishaCd
        'TESTUSER',       -- l_inUserId
        '1',              -- l_inChohyoKbn
        '20250119',       -- l_inGyomuYmd
        v_code,
        v_msg
    );
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0  # SUCCESS
            }
        ]
    },
    'rtfn-1141': {
        'name': 'SPIPK004K00R01',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Coexisting issue balance report - with data (SUCCESS)',
                'oracle_sql': None,
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE user_id='TESTUSER' AND chohyo_id='IPK30000411';
    CALL spipk004k00r01(
        '1',            -- p_inShasaiFlg: all special bonds
        '200812',       -- p_inKijunYm: Dec 2008 (has data)
        NULL,           -- p_inHktCd
        NULL,           -- p_inKozaTenCd
        NULL,           -- p_inKozaTenCifCd
        '0005C08120001',-- p_inMgrCd: specific bond to speed up test
        NULL,           -- p_inIsinCd
        NULL,           -- p_inJtkKbn
        '0005',         -- l_inItakuKaishaCd
        'TESTUSER',     -- l_inUserId
        '1',            -- l_inChohyoKbn
        '20081231',     -- l_inGyomuYmd
        v_code,
        v_msg
    );
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0  # SUCCESS - returns data with 2 records (1 detail + 1 summary)
            }
        ]
    },
    'bwag-4459': {
        'name': 'SPIPP001K00R01',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Redemption annual table (real record number management) - no data (SUCCESS)',
                'oracle_sql': None,
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE key_cd='0005' AND user_id='TESTUSER' AND chohyo_id='IPP30000111';
    CALL spipp001k00r01(
        '0005',      -- l_inItakuKaishaCd
        'TESTUSER',  -- l_inUserId
        '1',         -- l_inChohyoKbn
        NULL,        -- l_inMgrCd
        NULL,        -- l_inIsinCd
        '202412',    -- l_inKjnYm
        v_code,
        v_msg
    );
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0  # SUCCESS - creates 2 records (1 header + 1 "対象データなし" when no data in KBG_SHOKIJ)
            }
        ]
    },
    'jcdv-2426': {
        'name': 'SPIPP002K00R01_02',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Bond register (real record number method) - no data',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE user_id='TESTUSER';
    CALL spipp002k00r01_02('0005', '20250119', 'TESTUSER', '1', '20250119', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 2  # NODATA when no matching records
            }
        ]
    },
    'wjkw-5194': {
        'name': 'SPIPP003K00R01',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Redemption record number notification (real record number management) - success',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE user_id='TESTUSER';
    CALL spipp003k00r01('0005', 'TESTUSER', '1', '202501', '20250119', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0  # SUCCESS
            }
        ]
    },
    'tbrp-6197': {
        'name': 'SPIPP005K00R01',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Principal and interest payment list by settlement method - no data',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE user_id='TESTUSER';
    CALL spipp005k00r01('0005', 'TESTUSER', '1', '202501', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 2  # NODATA when no matching records
            }
        ]
    },
    'qcmk-4653': {
        'name': 'SPIPP006K00R01',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Counterparty principal and interest transfer list - no data',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE user_id='TESTUSER';
    CALL spipp006k00r01('0005', 'TESTUSER', '1', '202501', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 2  # NODATA when no matching records
            }
        ]
    },
    'qgej-4446': {
        'name': 'SPIPP012K00R01',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Bond denomination comparison table - success',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE user_id='TESTUSER';
    CALL spipp012k00r01('0005', 'TESTUSER', '1', '', '', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0  # SUCCESS
            }
        ]
    },
    'nvyf-5009': {
        'name': 'SPIPP017K00R01',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Bond denomination management table - success',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE user_id='TESTUSER';
    CALL spipp017k00r01('0005', 'TESTUSER', '1', '', '', '202501', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0  # SUCCESS
            }
        ]
    },
    'kvfv-2258': {
        'name': 'SPIPJ212K00R02',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Redemption schedule list - no data',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE user_id='TESTUSER';
    CALL spipj212k00r02('TESTUSER', '0005', '20250101', '20251231', 
                        NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                        v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 2  # NODATA when no matching records
            }
        ]
    },
    'nddn-4945': {
        'name': 'SPIPK004K00R02',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Coexisting issue balance change detail - success',
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer;
    v_msg text; 
BEGIN 
    DELETE FROM SREPORT_WK WHERE user_id='TESTUSER';
    CALL spipk004k00r02(
        '1',           -- l_inShasaiFlg (all special bonds)
        '',            -- l_inHktCd
        '',            -- l_inKozaTenCd
        '',            -- l_inKozaTenCifCd
        '',            -- l_inMgrCd
        '',            -- l_inIsinCd
        '',            -- l_inJtkKbn
        '20250101',    -- l_inGnrbaraiFYmd
        '20251231',    -- l_inGnrbaraiTYmd
        '0005',        -- l_inItakuKaishaCd
        'TESTUSER',    -- l_inUserId
        '1',           -- l_inChohyoKbn
        '20250119',    -- l_inGyomuYmd
        v_code,
        v_msg
    );
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 0  # SUCCESS
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
    
    # Connect to database
    try:
        postgres_conn = psycopg2.connect(**POSTGRES_CONFIG)
        postgres_conn.set_session(autocommit=True)
        
        postgres_cursor = postgres_conn.cursor()
        
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
            elif postgres_result == expected:
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
