    'sbvb-6748': {
        'name': 'SPIPX011K00R01 - 基準残高報告書',
        'type': 'procedure',
        'tests': [
            {
                'description': 'Test 1: Create report with valid params',
                'oracle_sql': None,
                'postgres_sql': """
DO $$ 
DECLARE 
    v_code integer; 
    v_msg text; 
BEGIN 
    CALL spipx011k00r01('0005', 'TESTUSER', '1', '20250112', '202501', '20250112', v_code, v_msg); 
    RAISE NOTICE 'Code: %, Msg: %', v_code, COALESCE(v_msg, 'NONE');
END $$;
""",
                'expected': 1
            }
        ]
    },
