drop function if exists pkcompare.getcompareinfo;
drop domain if exists pkCompare.t_itematt_type;
drop type if exists pkCompare.rec_Att_type;

-- Oracle package 'pkcompare' declaration, please edit to match PostgreSQL syntax.

-- DROP SCHEMA IF EXISTS pkcompare CASCADE;
CREATE SCHEMA IF NOT EXISTS pkcompare;

create type pkCompare.rec_Att_type AS (
	dispNm		varchar(100), 
	condNo		numeric(3) 
);

create DOMAIN pkCompare.t_itematt_type AS pkCompare.rec_Att_type[];
--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 突合処理に関するパッケージ (BODY部）
-- * 
-- * @author 藤江
-- * @version $Revision: 1.3 $
-- 
    --   
--     * 突合項目、突合条件を取得し、SELECT文と突合項目数を返す
--     * @param 	l_inTotsugoNo 	IN 	VARCHAR2		突合識別番号
--     * @param 	l_inCondition 	IN 	VARCHAR2		検索条件（突合条件マスタの登録内容以外の条件）
--     * @param 	l_outSql 		OUT VARCHAR2　		SELECT文
--     * @param 	l_outItemCnt 	OUT NUMBER			突合項目数
--     * @param 	l_outItemAtt 	OUT t_ItemAtt_type	項目属性
--     * @return  リターンコード	INTEGER
--     *   		 正常  ：0
--     *   		 エラー：1  突合項目マスタ該当データなし
--     *   		 エラー：2  突合条件マスタ該当データなし
--     *   		 エラー：99 or SQLCODE　その他のエラー
--	 	
CREATE OR REPLACE FUNCTION pkcompare.getcompareinfo (
	l_inTotsugoNo text,
	l_inCondition text,
	l_outSql OUT text,
	l_outItemCnt OUT numeric,
	l_outItemAtt OUT pkCompare.t_itematt_type,
	l_inFrom text DEFAULT NULL,
	OUT extra_param integer
) RETURNS record AS $body$
DECLARE

--====================================================================
--					デバッグ機能										  
--====================================================================
	DEBUG	numeric(1)	:= 1;

--====================================================================*
--		カーソル定義
-- *====================================================================
	curItem CURSOR(w_TotsugoNo  SCOMPARING_ITEM.TOTSUGO_NO%TYPE) FOR
	SELECT
		MOTO_ITEM,
		SAKI_ITEM,
		coalesce(CONDITION_NO, 0)::text S_CONDITION_NO,
		ITEM_DISP_NM
	FROM
		SCOMPARING_ITEM
	WHERE
		TOTSUGO_NO = w_TotsugoNo
	ORDER BY
		SEQ;
	
	curItemIsOpen boolean := FALSE;

--====================================================================*
--                  変数定義
-- *====================================================================
 	result		integer;
	gSelect		SCOMPARING_CONDITION.SELECT_CLAUSE%TYPE;
	gFrom			SCOMPARING_CONDITION.FROM_CLAUSE%TYPE;
	gWhere		SCOMPARING_CONDITION.WHERE_CLAUSE%TYPE;
	gOrderBy	SCOMPARING_CONDITION.ORDER_BY_CLAUSE%TYPE;
	gGroupBy	SCOMPARING_CONDITION.GROUP_BY_CLAUSE%TYPE;
	gWhere2		varchar(10);

--====================================================================*
--					定数定義
-- *====================================================================
	-- リターンコード
	RTN_NODATA_ITEM CONSTANT integer := 1;			-- 突合項目マスタ該当データなし
	RTN_NODATA_COND CONSTANT integer := 2;			-- 突合条件マスタ該当データなし
	RTN_FATAL		CONSTANT integer := 99;			-- 予期せぬエラー
	-- 本SPのID
	SP_ID			CONSTANT varchar(20) := 'pkCompare';
	-- ユーザID
	USER_ID			CONSTANT varchar(10) := 'BATCH';	
	-- 帳票ID
	REPORT_ID		CONSTANT varchar(10) := '';

--====================================================================*
--   メイン
-- *====================================================================
BEGIN

	l_outSql := '';
	l_outItemCnt := 0;
	result := RTN_FATAL;

	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' START');	END IF;

	-- 入力パラメータのチェック(突合識別番号)
	IF coalesce(trim(both l_inTotsugoNo)::text, '') = '' THEN
		-- パラメータエラー
		CALL pkLog.error('ECM501', SP_ID, ' ');
		extra_param := result;
		RETURN;
	END IF;

	-- 突合項目マスタ検索 
	FOR recItem IN curItem(l_inTotsugoNo) LOOP
		curItemIsOpen := TRUE;
		-- SELECT句の突合項目リストを編集 
		IF (l_outSql IS NOT NULL AND l_outSql::text <> '') THEN
			l_outSql := l_outSql || ',';
		END IF;
		-- Convert Oracle functions to PostgreSQL equivalents, then wrap numeric results with numeric_to_char for consistent text comparison
		-- Step 1: Convert decode() -> CASE WHEN, to_number() -> ::numeric
		-- Step 2: If result contains ::numeric (from decode/to_number), wrap entire expression with pkcharacter.numeric_to_char()
		-- Step 3: Convert explicit TO_CHAR() -> pkcharacter.numeric_to_char()
		DECLARE
			moto_converted text;
			saki_converted text;
		BEGIN
			-- Convert MOTO_ITEM: decode → CASE WHEN, to_number → ::numeric, TO_CHAR(number) → numeric_to_char
			moto_converted := regexp_replace(
				regexp_replace(
					regexp_replace(recItem.MOTO_ITEM, 
						'decode\s*\(\s*trim\s*\(([^)]+)\)\s*,\s*null\s*,\s*null\s*,\s*to_number\s*\(([^)]+)\)\s*\)', 
						'CASE WHEN trim(\1) IS NULL THEN NULL ELSE (\2)::numeric END', 'gi'),
					'to_number\s*\(\s*([^)]+)\s*\)', '(\1)::numeric', 'gi'),
				'TO_CHAR\s*\(\s*([^)]+)\s*\)', 'pkcharacter.numeric_to_char(\1)', 'gi');
			
			-- If MOTO_ITEM contains ::numeric (from conversion), wrap with numeric_to_char for text comparison
			IF moto_converted ~* '::numeric' AND moto_converted !~* 'numeric_to_char' THEN
				moto_converted := 'pkcharacter.numeric_to_char(' || moto_converted || ')';
			END IF;
			
			-- Convert SAKI_ITEM: decode → CASE WHEN, to_number → ::numeric, TO_CHAR → numeric_to_char
			saki_converted := regexp_replace(
				regexp_replace(
					regexp_replace(recItem.SAKI_ITEM, 
						'decode\s*\(\s*trim\s*\(([^)]+)\)\s*,\s*null\s*,\s*null\s*,\s*to_number\s*\(([^)]+)\)\s*\)', 
						'CASE WHEN trim(\1) IS NULL THEN NULL ELSE (\2)::numeric END', 'gi'),
					'to_number\s*\(\s*([^)]+)\s*\)', '(\1)::numeric', 'gi'),
				'TO_CHAR\s*\(\s*([^)]+)\s*\)', 'pkcharacter.numeric_to_char(\1)', 'gi');
			
			-- If SAKI_ITEM is a direct numeric column reference (no operators), wrap with numeric_to_char for text comparison
			IF saki_converted ~ '^[A-Z0-9_]+\.[A-Z0-9_]+$' OR (saki_converted ~* '::numeric' AND saki_converted !~* 'numeric_to_char') THEN
				-- Check if it's a numeric column by looking for common numeric column patterns
				IF saki_converted ~* '(FACTOR|KNGK|AMT|AMOUNT|PRICE|RATE|RATIO)' OR saki_converted ~* '::numeric' THEN
					saki_converted := 'pkcharacter.numeric_to_char(' || saki_converted || ')';
				END IF;
			END IF;
			
			l_outSql := l_outSql || moto_converted || ',' || saki_converted;
		END;

		-- 突合項目数カウントアップ 
		l_outItemCnt := l_outItemCnt + 1;

		-- 条件番号と、表示項目名をレコード変数にセット  
		l_outItemAtt[l_outItemCnt].condNo := recItem.S_CONDITION_NO;
		l_outItemAtt[l_outItemCnt].dispNm := recItem.ITEM_DISP_NM;
    END LOOP;
	curItem := FALSE;

	-- データが存在しない場合エラー終了 
	IF l_outItemCnt = 0 THEN
		CALL pkLog.error('ECM3A3', SP_ID, '突合項目マスタ');
		extra_param := (RTN_NODATA_ITEM);
		RETURN;
	END IF;

	-- 突合条件マスタ検索 
	SELECT
		RTRIM(SELECT_CLAUSE),
		RTRIM(FROM_CLAUSE),
		RTRIM(WHERE_CLAUSE),
 		RTRIM(ORDER_BY_CLAUSE),
		RTRIM(GROUP_BY_CLAUSE)
	INTO STRICT
		gSelect,
		gFrom,
		gWhere,
		gOrderBy,
		gGroupBy
	FROM
		SCOMPARING_CONDITION
	WHERE
		TOTSUGO_NO = l_inTotsugoNo;

	-- SELECT文を編集 
	--   SELECT句 
    IF (gSelect IS NOT NULL AND gSelect::text <> '') THEN
    	gSelect := ',' || gSelect;
    END IF;

	--   FROM句 
    IF (RTRIM(l_inFrom) IS NOT NULL AND (RTRIM(l_inFrom))::text <> '') AND (gFrom IS NOT NULL AND gFrom::text <> '') THEN
    	gFrom := gFrom || ',';
    END IF;

	--   WHERE句 
    IF (RTRIM(l_inCondition) IS NOT NULL AND (RTRIM(l_inCondition))::text <> '') OR (gWhere IS NOT NULL AND gWhere::text <> '') THEN
    	gWhere2 := ' WHERE ';
    END IF;
    IF (RTRIM(l_inCondition) IS NOT NULL AND (RTRIM(l_inCondition))::text <> '') AND (gWhere IS NOT NULL AND gWhere::text <> '') THEN
    	gWhere := ' AND ' || gWhere;
    END IF;

	--   ORDER BY句 
    IF (gOrderBy IS NOT NULL AND gOrderBy::text <> '') THEN
    	gOrderBy := ' ORDER BY ' || gOrderBy;
    END IF;

	--   GROUP BY句 
    IF (gGroupBy IS NOT NULL AND gGroupBy::text <> '') THEN
    	gGroupBy := ' GROUP BY ' || gGroupBy;
    END IF;

    l_outSql := 'SELECT ' || coalesce(l_outSql, '') 
    	|| coalesce(gSelect, '')
    	|| ' FROM ' || coalesce(gFrom, '') || coalesce(l_inFrom, '')
    	|| coalesce(gWhere2, '') || coalesce(l_inCondition, '') || coalesce(gWhere, '')
    	|| coalesce(gGroupBy, '')
    	|| coalesce(gOrderBy, '');

    result := 0;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' END');	END IF;

	extra_param := (result);

	RETURN;

--====================================================================*
--    異常終了 出口
-- *====================================================================
EXCEPTION

	-- データなし（突合条件マスタ） 
	WHEN no_data_found THEN
		IF curItemIsOpen THEN
			CLOSE curItem;
		END IF;
					l_outSql := '';
					l_outItemCnt := 0;
		CALL pkLog.fatal('ECM701', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
		extra_param := RTN_NODATA_COND;
		RETURN;

	-- その他・例外エラー 
	WHEN OTHERS THEN
		IF curItemIsOpen THEN
			CLOSE curItem;
		END IF;
					l_outSql := '';
					l_outItemCnt := 0;
		CALL pkLog.fatal('ECM701', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
		extra_param := SQLSTATE;
		RETURN;
END;
$body$
LANGUAGE PLPGSQL
;

-- CREATE OR REPLACE PROCEDURE pkcompare.getcompareinfo_errhandler () AS $body$
-- BEGIN
-- 	IF curItem%ISOPEN THEN
-- 		CLOSE curItem;
-- 	END IF;
--         l_outSql := '';
--         l_outItemCnt := 0;
-- 	CALL pkLog.fatal('ECM701', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));

-- END;
-- $body$
-- LANGUAGE PLPGSQL
-- ;
-- REVOKE ALL ON PROCEDURE pkcompare.getcompareinfo_errhandler () FROM PUBLIC;
-- End of Oracle package 'pkcompare' declaration
