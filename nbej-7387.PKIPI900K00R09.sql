


-- Oracle package 'pkipi900k00r09' declaration, please edit to match PostgreSQL syntax.

-- DROP SCHEMA IF EXISTS pkipi900k00r09 CASCADE;
CREATE SCHEMA IF NOT EXISTS pkipi900k00r09;


--*
--     * isSysDateBizDate
--     * 今日のSystem日付が営業日かどうか判定します
--     *
--     * @return INTEGER 0:営業日 1:非営業日
--     
CREATE OR REPLACE FUNCTION pkipi900k00r09.issysdatebizdate () RETURNS numeric AS $body$
DECLARE

        result integer := 0;

BEGIN
        select pkDate.isBusinessDay(to_char(clock_timestamp(), 'YYYYMMDD'))
            into STRICT result;
        return result;
    end;


    --*
--     * isFirstBizDateOfMonth
--     * 現在の業務日付が月初第1営業日かどうか判定する。
--     *
--     * @return INTEGER 0:月初第1営業日 1:月初第1営業日以外
--     
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipi900k00r09.issysdatebizdate () FROM PUBLIC;



CREATE OR REPLACE FUNCTION pkipi900k00r09.isfirstbizdateofmonth () RETURNS numeric AS $body$
DECLARE

        result integer := 0;

BEGIN
        select CASE WHEN pkDate.getGesshoBusinessYmd(pkDate.getGyomuYmd())=pkDate.getGyomuYmd() THEN  0  ELSE 1 END 
            into STRICT result;
        return result;
    end;

    --*
--     * isLastBizDateOfMonth
--     * 現在の業務日付が月末最終営業日かどうか判定する。
--     *
--     * @return INTEGER 0:月末最終営業日 1:月末最終営業日以外
--     
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipi900k00r09.isfirstbizdateofmonth () FROM PUBLIC;



CREATE OR REPLACE FUNCTION pkipi900k00r09.islastbizdateofmonth () RETURNS numeric AS $body$
DECLARE

        result integer := 0;

BEGIN
        select CASE WHEN pkDate.getGetsumatsuBusinessYmd(pkDate.getGyomuYmd(), 0)=pkDate.getGyomuYmd() THEN  0  ELSE 1 END 
            into STRICT result;
        return result;
    end;

    --*
--     * isMiddleBizDateOfMonth
--     * 現在の業務日付が中日営業日かどうか判定する。
--     *
--     * @return INTEGER 0:月末最終営業日 1:月末最終営業日以外
--     
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipi900k00r09.islastbizdateofmonth () FROM PUBLIC;



CREATE OR REPLACE FUNCTION pkipi900k00r09.ismiddlebizdateofmonth () RETURNS numeric AS $body$
DECLARE

        result integer := 0;

BEGIN
      --  select decode(pkDate.getGetsumatsuBusinessYmd(pkDate.getGyomuYmd, 0),
      --             pkDate.getGyomuYmd, 0,
      --                                 1)
      --      into result from dual;
        return result;
    end;

    --*
--     * isNthBizDateOfMonth
--     * 現在の業務日付が、第？営業日と同じかどうか判定する。
--     *
--     * @param  Nissu NUMBER  第？営業日を整数で指定
--     * @return INTEGER 0:同じ 1:異なる
--     
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipi900k00r09.ismiddlebizdateofmonth () FROM PUBLIC;



CREATE OR REPLACE FUNCTION pkipi900k00r09.isnthbizdateofmonth ( Nissu numeric ) RETURNS numeric AS $body$
DECLARE

        result integer := 0;
	
BEGIN
	    -- 指定されたNissu変数から1を引いた日付
        select CASE WHEN pkDate.getPlusDateBusiness(pkDate.getGesshoBusinessYmd(pkDate.getGyomuYmd()), (Nissu - 1)::integer)=pkDate.getGyomuYmd() THEN  0  ELSE 1 END
            into STRICT result;
        return result;
	end;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipi900k00r09.isnthbizdateofmonth ( Nissu numeric ) FROM PUBLIC;
-- End of Oracle package 'pkipi900k00r09' declaration