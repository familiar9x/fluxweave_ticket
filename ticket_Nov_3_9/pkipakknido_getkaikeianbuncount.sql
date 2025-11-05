-- Create the pkipakknido schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS pkipakknido;

-- Drop the function if it exists
DROP FUNCTION IF EXISTS pkipakknido.getkaikeianbuncount(CHARACTER, CHARACTER VARYING);

-- Create the getKaikeiAnbunCount function
CREATE OR REPLACE FUNCTION pkipakknido.getkaikeianbuncount(
    l_initakukaishacd CHARACTER,
    l_inmgrcd         CHARACTER VARYING
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    gCnt NUMERIC DEFAULT 0;
BEGIN
    SELECT
        COUNT(*)
    INTO
        gCnt
    FROM
        KAIKEI_ANBUN
    WHERE
        ITAKU_KAISHA_CD = l_initakukaishacd
    AND MGR_CD = l_inmgrcd
    AND SHORI_KBN = '1'
    ;

    RETURN gCnt;

END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION pkipakknido.getkaikeianbuncount(CHARACTER, CHARACTER VARYING) TO rh_mufg_ipa;
