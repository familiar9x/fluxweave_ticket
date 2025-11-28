-- Simple test version without insertData calls to check other logic
CREATE OR REPLACE PROCEDURE spipx015k00r01_test (
    l_inKessaiYmdF text,
    l_inKessaiYmdT text,
    l_inItakuKaishaCd text,
    l_inUserId text,
    l_inChohyoKbn text,
    l_inGyomuYmd text,
    l_outSqlCode OUT integer,
    l_outSqlErrM OUT text
) AS $$
BEGIN
    -- Just test parameters
    IF (coalesce(trim(both l_inKessaiYmdF)::text, '') = '')
        OR (coalesce(trim(both l_inKessaiYmdT)::text, '') = '')
        OR (coalesce(trim(both l_inItakuKaishaCd)::text, '') = '')
    THEN
        l_outSqlCode := pkconstant.error();
        l_outSqlErrM := 'Parameter error';
        RETURN;
    END IF;
    
    l_outSqlCode := 0;
    l_outSqlErrM := '';
END;
$$ LANGUAGE PLPGSQL;

-- Test
DO $$
DECLARE
    v_code integer;
    v_msg text;
BEGIN
    CALL spipx015k00r01_test('20250101', '20250131', '0005', 'TEST', '1', '20250131', v_code, v_msg);
    RAISE NOTICE 'Code: %, Msg: %', v_code, v_msg;
END $$;
