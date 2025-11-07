/**
 * 著作権：Copyright(c) 2005
 * 会社名：JIP
 *
 * 概要  ：コード値チェック
 *
 * @author 倉澤健史
 * @version $Revision: 1.2 $
 *
 * @param l_code_shubetsu  in char   コード種別
 *        l_code_value in varchar2   コード値
 * @return number      0：正常，1：異常
 */

CREATE OR REPLACE FUNCTION sfCmIsCodeMChek (
	l_code_shubetsu text,
	l_code_value text
) RETURNS numeric AS $body$
DECLARE
	cnt numeric;
	returnValue numeric;
BEGIN
	returnValue := 0;
	
	IF (l_code_shubetsu IS NOT NULL AND l_code_shubetsu::text <> '') 
	   AND (l_code_value IS NOT NULL AND l_code_value::text <> '') THEN
		SELECT COUNT(*) INTO STRICT cnt
		FROM scode
		WHERE code_shubetsu = l_code_shubetsu
		  AND code_value = l_code_value;
		  
		IF cnt = 0 THEN
			returnValue := 1;
		END IF;
	END IF;
	
	RETURN returnValue;
	
EXCEPTION
	WHEN OTHERS THEN
		-- pkLog.fatal(null, null, substr(SQLERRM, 1, 100));
		returnValue := 1;
		RETURN returnValue;
END;
$body$
LANGUAGE PLPGSQL;
