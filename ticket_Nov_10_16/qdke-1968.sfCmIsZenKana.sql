--*
--* 著作権：Copyright(c) 2005
--* 会社名：JIP
--*
--* 概要  ：全角英数チェック
--*
--* @author 倉澤健史
--* @version $Revision: 1.3 $
--*
--* @param l_inValue in varchar2  文字列
--* @return number      0：正常，1：異常
--






CREATE OR REPLACE FUNCTION sfcmiszenkana (l_inValue text) RETURNS numeric AS $body$
DECLARE

	checkChars1     constant varchar(90) := 'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン';
	checkChars2     constant varchar(42) := 'ヴガギグゲゴザジズゼゾダヂヅデドバビブベボ';
	checkChars3     constant varchar(10) := 'パピプペポ';
	checkChars4     constant varchar(52) := 'ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ';
	checkChars5     constant varchar(20) := '０１２３４５６７８９';
	checkChars6     constant varchar(26) := '「」　．（¥）ー／−゛゜・';
	checkChars7     constant varchar(18) := 'ァィゥェォャュョッ';
--	checkChars8     constant varchar2(52) := 'ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ';
	cnt		numeric;
	returnValue	numeric;

BEGIN
	returnValue := 0;
	if (l_inValue IS NOT NULL AND l_inValue::text <> '') then
                for cnt in 1..length(l_inValue) loop
	       	if (position(substr(l_inValue, cnt, 1) in checkChars1)  != 0)   or (position(substr(l_inValue, cnt, 1) in checkChars2)  != 0)   or (position(substr(l_inValue, cnt, 1) in checkChars3)  != 0)   or (position(substr(l_inValue, cnt, 1) in checkChars4)  != 0)   or (position(substr(l_inValue, cnt, 1) in checkChars5)  != 0)   or (position(substr(l_inValue, cnt, 1) in checkChars6)  != 0)   or (position(substr(l_inValue, cnt, 1) in checkChars7)  != 0)   then
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
--	     pkLog.fatal(null, null, substrb(SQLERRM, 1, 100));
             returnValue := 1;
	     return returnValue;
    end;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfcmiszenkana (l_inValue text) FROM PUBLIC;