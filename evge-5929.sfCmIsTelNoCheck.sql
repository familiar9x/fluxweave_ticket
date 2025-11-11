--*
--* 著作権：Copyright(c) 2005
--* 会社名：JIP
--*
--* 概要  ：電話番号エラーチェック
--*
--* @author 渡邊　かよ
--* @version $Revision: 1.2 $
--*
--* @param l_inValue in varchar2  文字列
--* @return number      0：正常，1：異常
--






CREATE OR REPLACE FUNCTION sfcmistelnocheck (l_inValue text) RETURNS numeric AS $body$
DECLARE

	checkChars      constant varchar(13) := '0123456789()-';
	cnt		numeric;
	returnValue	numeric;

BEGIN
	returnValue := 0;
	if (l_inValue IS NOT NULL AND l_inValue::text <> '') then
                for cnt in 1..length(l_inValue) loop
	        	if (position(substr(l_inValue, cnt, 1) in checkChars)  != 0) then
		                returnValue := 0;
			ELSE
				returnValue := 1;
				exit;
			end if;
		end loop;
	end if;
	return returnValue;
    exception
	when others then
             returnValue := 1;
	     return returnValue;
    end;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfcmistelnocheck (l_inValue text) FROM PUBLIC;