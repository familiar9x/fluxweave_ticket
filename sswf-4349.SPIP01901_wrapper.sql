-- Wrapper function for SPIP01901 procedure to allow calling from functions
-- This is needed because PostgreSQL functions cannot directly capture OUT parameters from procedures

DROP TYPE IF EXISTS spip01901_result CASCADE;
CREATE TYPE spip01901_result AS (
    sqlcode integer,
    sqlerrm text
);

CREATE OR REPLACE FUNCTION spip01901_wrapper(
    p_hktcd TEXT,
    p_kozatencd TEXT,
    p_kozatencifcd TEXT,
    p_mgrcd TEXT,
    p_isincd TEXT,
    p_kijunymdf TEXT,
    p_kijunymdt TEXT,
    p_tsuchiymd TEXT,
    p_itakukaishacd TEXT,
    p_userid TEXT,
    p_hendoriritsuShonindtflg TEXT,
    p_chohyokbn TEXT,
    p_gyomuymd TEXT
) RETURNS spip01901_result AS $$
DECLARE
    v_sqlcode integer;
    v_sqlerrm text;
BEGIN
    RAISE NOTICE 'WRAPPER: About to call SPIP01901';
    CALL spip01901(
        p_hktcd,
        p_kozatencd,
        p_kozatencifcd,
        p_mgrcd,
        p_isincd,
        p_kijunymdf,
        p_kijunymdt,
        p_tsuchiymd,
        p_itakukaishacd,
        p_userid,
        p_hendoriritsuShonindtflg,
        p_chohyokbn,
        p_gyomuymd,
        v_sqlcode,
        v_sqlerrm
    );
    RAISE NOTICE 'WRAPPER: After CALL, sqlcode=%, sqlerrm=%', v_sqlcode, v_sqlerrm;
    
    RETURN (v_sqlcode, v_sqlerrm)::spip01901_result;
END;
$$ LANGUAGE plpgsql;
