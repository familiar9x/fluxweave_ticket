/**
 * 著作権：Copyright(c) 2005
 * 会社名：JIP
 *
 * 概要  ：半角英数チェック
 *
 * @author 倉澤健史
 * @version $Revision: 1.2 $
 *
 * @param l_inValue in varchar2  文字列
 * @return number      0：正常，1：異常
 */

CREATE OR REPLACE FUNCTION sfcmishalfalphanumeric2 (l_inValue text) 
RETURNS numeric AS $body$
DECLARE
	checkChars      constant varchar(62) := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
	cnt		numeric;
	returnValue	numeric;

BEGIN
	returnValue := 0;
	IF (l_inValue IS NOT NULL) THEN
		FOR cnt IN 1..length(l_inValue) LOOP
			IF (position(substr(l_inValue, cnt, 1) in checkChars) != 0) THEN
				returnValue := 0;
			ELSE
				returnValue := 1;
				EXIT;
			END IF;
		END LOOP;
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
