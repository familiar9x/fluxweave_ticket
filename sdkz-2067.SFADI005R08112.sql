CREATE OR REPLACE FUNCTION sfadi005r08112 (
	l_inItakuKaishaCd SHINKIKIROKU.ITAKU_KAISHA_CD%TYPE,
	l_inKessaiNo SHINKIKIROKU.KESSAI_NO%TYPE
) RETURNS integer AS $body$
DECLARE

--
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 新規記録情報突合処理
-- *   新規募集情報ＴＢＬ突合・更新処理
-- *
-- * @author  藤江
-- * @author  西村　瞳
-- * @version $Revision: 1.19 $
-- * @param 	l_inItakuKaishaCd  	IN 	SHINKIKIROKU.ITAKU_KAISHA_CD%TYPE	委託会社コード
-- * @param  	l_inKessaiNo 		IN 	SHINKIKIROKU.KESSAI_NO%TYPE			決済番号
-- * @return 	リターンコード		INTEGER
-- *   		 pkconstant.success()				: 正常
-- *   		 pkconstant.NO_DATA_FIND()	 	: 突合相手なし
-- *   		 pkconstant.RECONCILE_ERROR()		: 突合エラー
-- *           pkconstant.FATAL() 			 	: 致命的エラー
-- 
--====================================================================
--					デバッグ機能										  
--====================================================================
	DEBUG	numeric(1)	:= 1;
--====================================================================*
--                  変数定義
-- *====================================================================
 	result			integer;			-- 本ＳＰのリターンコード
	curComp 		integer;			-- カーソルＩＤ
	gCompFlg 		integer;			-- 突合結果フラグ　0:一致  1:不一致
	gCompAllCnt		integer;			-- 検索結果の突合関連の項目数
	intCount		integer;
	gMeisaiCnt		integer;			-- 新規募集情報テーブルの明細データ数
	tMoto KK_RENKEI.ITEM001%type[];						-- 比較元
	tSaki KK_RENKEI.ITEM001%type[];						-- 比較先
	tempMoto		varchar(400);		-- 比較元の一時変数
	tempSaki		varchar(400);		-- 比較先の一時変数
	gMgrCd			SHINKIBOSHU.MGR_CD%TYPE;				-- 銘柄コード
	gMgrMeisaiNo	SHINKIBOSHU.MGR_MEISAI_NO%TYPE;			-- 銘柄明細No
	gCompRsltKbn	SHINKIKIROKU.TOTSUGO_KEKKA_KBN%TYPE;	-- 突合結果区分
	-- 突合情報取得ＳＰパラメータ 
	gInTotsugoNo 	varchar(12);				-- 突合識別番号
	gInCondition 	varchar(4000);				-- 検索条件（突合条件マスタに登録している条件以外）
	gOutSql 		varchar(20000);			-- ＳＱＬ文字列
	gOutItemCnt 	numeric(3);					-- 突合項目数
	gOutItemAtt 	PkCompare.t_ItemAtt_type;	-- 突合項目属性（条件番号、表示項目名）
	gFromSql		varchar(4000);				-- From句（突合条件マスタに登録している条件以外）
	gRtn			integer;					-- 突合情報取得ＳＰの戻り値
--====================================================================*
--					定数定義
-- *====================================================================
	-- 本SPのID
	SP_ID				CONSTANT varchar(20) := 'SFADI005R08112';
	-- ユーザID
	USER_ID				CONSTANT varchar(10) := pkconstant.BATCH_USER();
	-- 帳票ID
	REPORT_ID			CONSTANT varchar(10) := '';
	-- SELECT句 (突合条件マスタの登録値)の何番目の項目か
	-- (突合項目以外の項目の中での番号)
	POS_MGR_MEISAI_NO	CONSTANT numeric(2) := 1;
--====================================================================*
--   メイン
-- *====================================================================
BEGIN
	result := pkconstant.FATAL();
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inItakuKaishaCd::text), '') = ''
	  OR coalesce(trim(both l_inKessaiNo::text), '') = '' THEN
		-- パラメータエラー
		CALL pkLog.error('ECM501', SP_ID, ' ');
		RETURN result;
	END IF;
	BEGIN
		-- 新規記録情報、銘柄基本より銘柄コード取得（兼有無チェック） 
		-- ファンクション'editFromSql'でgMgrCdを、下のエラー判定でgCompRsltKbnを使用している
		SELECT 	VMG1.MGR_CD,
				B04.TOTSUGO_KEKKA_KBN
		INTO STRICT	gMgrCd,
				gCompRsltKbn
		FROM shinkikiroku b04
LEFT OUTER JOIN mgr_kihon_view vmg1 ON (B04.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD AND B04.ISIN_CD = VMG1.ISIN_CD AND '1' = VMG1.SHORI_KBN)
WHERE B04.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND B04.KESSAI_NO = l_inKessaiNo AND B04.TOTSUGO_KEKKA_KBN <> '1';
    EXCEPTION
		-- データなし 
		WHEN no_data_found THEN
		-- 2重取込の場合
			result := pkconstant.RECONCILE_ERROR();
			RETURN result;
		-- その他・例外エラー 
		WHEN OTHERS THEN
			RAISE;
	END;
    -- 取得した結果に銘柄コードが入っているかどうか調べておく(これが銘柄が存在しているチェックになる)
    IF coalesce(trim(both gMgrCd )::text, '') = ''
    THEN
        -- 新規記録情報の突合結果区分が「突合相手なし」でなければ、「突合相手なし」に更新
        IF gCompRsltKbn != pkKkNotice.TOTSUGO_KEKKA_NOTARGET() THEN
        	CALL SFADI005R08112_updateShinkiKiroku(pkKkNotice.TOTSUGO_KEKKA_NOTARGET(), USER_ID,
																								l_inItakuKaishaCd,
																								l_inKessaiNo);
        END IF;
		CALL pkLog.error('ECM3A1', SP_ID, '新規募集情報（銘柄未承認またはＩＳＩＮコード未付番）'
			|| ' kessaiNo = [' || l_inKessaiNo || ']');
		RETURN pkconstant.NO_DATA_FIND();
    END IF;
 	-- 突合情報取得ＳＰ   
	--  入力パラメータ設定
	gInTotsugoNo := pkKkNotice.DCD_SHINKI_KIROKU_INFO();
	gInCondition := 'B04.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd
				|| ''' AND B04.KESSAI_NO = ''' || l_inKessaiNo || '''';
	--  SELECT文のFROM句編集（インラインビューの部分）  新規募集情報テーブルよりISIN,BIC変換して項目取得
	gFromSql := SFADI005R08112_editFromSql(l_inItakuKaishaCd, gMgrCd);
	--  突合情報取得ＳＰをＣＡＬＬ   ＳＱＬと突合項目数を取得する
	SELECT * INTO gOutSql, gOutItemCnt, gOutItemAtt, gRtn
	FROM pkCompare.getCompareInfo(gInTotsugoNo, gInCondition, gFromSql);
	IF gRtn != 0 THEN
		RETURN result;
	END IF;
	gCompAllCnt := gOutItemCnt * 2;
   -- 問い合わせ用のカーソルをオープンする 
   curComp := DBMS_SQL.OPEN_CURSOR();
   -- SELECT SQLを解析 
    CALL DBMS_SQL.PARSE(curComp,gOutSql);
	-- 配列初期化 
	FOR i IN 1 .. gOutItemCnt LOOP
		tMoto[i] := '';
		tSaki[i] := '';
	END LOOP;
   -- 出力変数を定義 
	-- 突合項目以外
    CALL DBMS_SQL.DEFINE_COLUMN(curComp, (gCompAllCnt + POS_MGR_MEISAI_NO)::int, gMgrMeisaiNo);
	-- 突合項目
	FOR i IN 1 .. gOutItemCnt LOOP
	    CALL DBMS_SQL.DEFINE_COLUMN(curComp, (i * 2 - 1)::int, tMoto[i], 400);
	    CALL DBMS_SQL.DEFINE_COLUMN(curComp, (i * 2)::int, tSaki[i], 400);
	END LOOP;
	-- 検索実行 
	intCount := DBMS_SQL.EXECUTE(curComp);
	gMeisaiCnt := 0;
	LOOP
		-- FETCH  
		-- 新規募集情報テーブルに該当データがない場合は終了*/
        IF DBMS_SQL.FETCH_ROWS(curComp) = 0 THEN
			EXIT;
		END IF;
         -- 値を取り出す 
    	-- 突合項目以外
    	CALL DBMS_SQL.COLUMN_VALUE(curComp, (gCompAllCnt + POS_MGR_MEISAI_NO)::int, gMgrMeisaiNo);
		-- 	明細データ数カウントアップ
		gMeisaiCnt := gMeisaiCnt + 1;
    	gCompFlg := 0;
    	-- 突合項目
    	-- 　比較元、比較先、条件番号の組を１組ずつ取り出し、突合
    	-- 　突合項目数繰り返す
    	FOR i IN 1 .. gOutItemCnt LOOP
			IF gMeisaiCnt = 1 THEN 	-- 新規記録情報データは１件目のみ取り出し
				tempMoto := '';
	         	CALL DBMS_SQL.COLUMN_VALUE(curComp, (i * 2 - 1)::int, tempMoto);
				tMoto[i] := tempMoto;
			END IF;
			tempSaki := '';
          	CALL DBMS_SQL.COLUMN_VALUE(curComp, (i * 2)::int, tempSaki);
			tSaki[i] := tempSaki;
    		-- 突合処理
			IF coalesce(trim(both tMoto[i]), ' ') != coalesce(trim(both tSaki[i]), ' ') THEN 		-- 不一致のとき
    			gCompFlg := 1;
--            DBMS_OUTPUT.PUT_LINE('項目' || i);
--            DBMS_OUTPUT.PUT_LINE('tMoto_' || (i) || ' = ' || tMoto[i]);
--            DBMS_OUTPUT.PUT_LINE('tSaki_' || (i) || ' = ' || tSaki[i]);
--
    		END IF;
    	END LOOP;
		-- 一致した場合 ループを抜ける
		IF gCompFlg = 0 THEN
			EXIT;
		END IF;
	END LOOP;
     -- カーソル　クローズ 
	CALL DBMS_SQL.CLOSE_CURSOR(curComp);
    -- 該当データがない場合は終了
	IF gMeisaiCnt = 0 THEN
        -- 新規記録情報の突合結果区分が「突合相手なし」でなければ、「突合相手なし」に更新
        IF gCompRsltKbn != pkKkNotice.TOTSUGO_KEKKA_NOTARGET() THEN
        	CALL SFADI005R08112_updateShinkiKiroku(pkKkNotice.TOTSUGO_KEKKA_NOTARGET(), USER_ID,
																								l_inItakuKaishaCd,
																								l_inKessaiNo);
        END IF;
		CALL pkLog.error('ECM3A1', SP_ID, '新規募集情報（新規募集情報未登録または未承認）'
			|| ' kessaiNo = [' || l_inKessaiNo || ']');
		RETURN pkconstant.NO_DATA_FIND();
	END IF;
	-- 一致した場合 
	IF gCompFlg = 0 THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' RECONCILE  OK');	END IF;
		-- 新規募集情報テーブルの突合結果区分と決済番号を更新
		CALL SFADI005R08112_updateShinkiBoshu(pkKkNotice.TOTSUGO_KEKKA_MATCH(), l_inKessaiNo,
																					USER_ID,
																					l_inItakuKaishaCd,
																					gMgrCd,
																					gMgrMeisaiNo, 1);
		-- 新規記録情報テーブルの突合結果区分を更新
		CALL SFADI005R08112_updateShinkiKiroku(pkKkNotice.TOTSUGO_KEKKA_MATCH(), USER_ID,
																								l_inItakuKaishaCd,
																								l_inKessaiNo);
		result := pkconstant.success();
	-- 不一致の項目がある場合 
	ELSE
		CALL pkLog.error('ECM3A2', SP_ID, ' ');
		-- 新規募集情報の明細データ数 = １のとき
		IF gMeisaiCnt >= 1 THEN
			-- 新規募集情報テーブルの突合結果区分と決済番号を更新
			CALL SFADI005R08112_updateShinkiBoshu(pkKkNotice.TOTSUGO_KEKKA_UNMATCH(), l_inKessaiNo,
																						USER_ID,
																						l_inItakuKaishaCd,
																						gMgrCd,
																						gMgrMeisaiNo, 1);
			-- 新規記録情報テーブルの突合結果区分を更新
			CALL SFADI005R08112_updateShinkiKiroku(pkKkNotice.TOTSUGO_KEKKA_UNMATCH(), USER_ID,
																								l_inItakuKaishaCd,
																								l_inKessaiNo);
			-- 新コード対応
			result := pkconstant.NOMATCH_ERROR();
		ELSE
			-- 新規記録情報の突合結果区分が「突合相手なし」でなければ、「突合相手なし」に更新
			IF gCompRsltKbn != pkKkNotice.TOTSUGO_KEKKA_NOTARGET() THEN
				CALL SFADI005R08112_updateShinkiKiroku(pkKkNotice.TOTSUGO_KEKKA_NOTARGET(), USER_ID,
																								l_inItakuKaishaCd,
																								l_inKessaiNo);
			END IF;
			result := pkconstant.NO_DATA_FIND();
		END IF;
	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' END');	END IF;
	RETURN(result);
--====================================================================*
--    異常終了 出口
-- *====================================================================
EXCEPTION
	-- データなし 
	WHEN no_data_found THEN
		CALL pkLog.error('ECM3A3', SP_ID, '新規記録情報または銘柄基本VIEW　該当データがありません。');
		RETURN pkconstant.FATAL();
	-- その他・例外エラー 
	WHEN OTHERS THEN
		IF DBMS_SQL.IS_OPEN(curComp) THEN
			CALL DBMS_SQL.CLOSE_CURSOR(curComp);
		END IF;
		CALL pkLog.fatal('ECM701', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
		RETURN result;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi005r08112 ( l_inItakuKaishaCd SHINKIKIROKU.ITAKU_KAISHA_CD%TYPE, l_inKessaiNo SHINKIKIROKU.KESSAI_NO%TYPE ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadi005r08112_editfromsql (
	l_inItakuKaishaCd SHINKIKIROKU.ITAKU_KAISHA_CD%TYPE,
	gMgrCd SHINKIBOSHU.MGR_CD%TYPE
) RETURNS varchar AS $body$
DECLARE

	sSql	varchar(4000);

BEGIN
        -- 変数にSQLクエリ文を代入
        sSql := 	   '(SELECT '
        			|| '    B01.ITAKU_KAISHA_CD, '
        			|| '    B01.MGR_MEISAI_NO, '
        			|| '    B01.HKUK_KNGK, '
        			|| '    B01.KESSAI_KNGK, '
        			|| '    B01.SSI_MUKO_FLG_CD, '
        			|| '    B01.KOKUNAI_TESU_KNGK, '
        			|| '    B01.KOKUNAI_TESU_SZEI_KNGK, '
        			|| '    B01.YAKUJO_KNGK, '
        			|| '    B01.FUND_CD, '
        			|| '    VMG1.ISIN_CD, '
        			|| '    VMG1.HAKKO_YMD, '
        			|| '    VMG1.HAKKO_KAGAKU, '
        			|| '    M081.BIC_CD_NOSHITEN AS KAI_BANKID_CD_BIC, '
        			|| '    M082.BIC_CD_NOSHITEN AS URI_BANKID_CD_BIC, '
        			|| '    SC18.OWN_FINANCIAL_SECURITIES_KBN || SC18.OWN_BANK_CD AS URI_BANKID_CD_K '
        			|| 'FROM '
        			|| '    SHINKIBOSHU B01 '
        			|| 'JOIN MGR_KIHON_VIEW VMG1 ON (B01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD AND B01.MGR_CD = VMG1.MGR_CD)'
        			|| 'LEFT OUTER JOIN MBANK_ZOKUSEI M081 ON (B01.ITAKU_KAISHA_CD = M081.ITAKU_KAISHA_CD AND B01.FINANCIAL_SECURITIES_KBN = M081.FINANCIAL_SECURITIES_KBN AND B01.BANK_CD = M081.BANK_CD)'
        			|| 'LEFT OUTER JOIN VJIKO_ITAKU SC18 ON (B01.ITAKU_KAISHA_CD = SC18.KAIIN_ID)'
							|| 'LEFT OUTER JOIN MBANK_ZOKUSEI M082 ON (SC18.KAIIN_ID = M082.ITAKU_KAISHA_CD AND SC18.OWN_FINANCIAL_SECURITIES_KBN = M082.FINANCIAL_SECURITIES_KBN AND SC18.OWN_BANK_CD = M082.BANK_CD)'
        			|| 'WHERE '
        			|| '    B01.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' '
        			|| '    AND VMG1.MGR_CD = ''' || gMgrCd || ''' '
        			|| '    AND B01.MASSHO_FLG = ''0'' '
        			|| '    AND B01.TOTSUGO_KEKKA_KBN <> ''1'' '
        			|| '    AND B01.DAIRI_MOTION_FLG = ''0'' '
        			|| '    AND B01.SHORI_KBN = ''1'' ' -- IP-02723 新規募集の処理区分を見てから突合させるようにする。
        			|| ') B01W ';
	RETURN sSql;
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi005r08112_editfromsql () FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfadi005r08112_updateshinkiboshu (
	inKbn SHINKIBOSHU.TOTSUGO_KEKKA_KBN%TYPE,
	l_inKessaiNo SHINKIKIROKU.KESSAI_NO%TYPE,
	USER_ID varchar(10),
	l_inItakuKaishaCd SHINKIKIROKU.ITAKU_KAISHA_CD%TYPE,
	gMgrCd SHINKIBOSHU.MGR_CD%TYPE,
	gMgrMeisaiNo SHINKIBOSHU.MGR_MEISAI_NO%TYPE,
	inKessaiFlg integer DEFAULT 0
) AS $body$
DECLARE

	sSql	varchar(400);
	sSql2	varchar(100);

BEGIN
	IF  inKessaiFlg = 1 THEN
		sSql2 := 'KESSAI_NO = ''' || l_inKessaiNo || ''',';
	END IF;
       sSql := 'UPDATE SHINKIBOSHU'
            || ' SET TOTSUGO_KEKKA_KBN = ''' || inKbn || ''','
                ||  sSql2
                || ' LAST_TEISEI_DT = TO_TIMESTAMP(''' || pkDate.getCurrentTime() || ''', ''YYYY-MM-DD HH24:MI:SS.FF6'') ,'
                || ' KOUSIN_ID = ''' || USER_ID || ''''
            || ' WHERE ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''''
            || '   AND MGR_CD = ''' || gMgrCd || ''''
            || '   AND MGR_MEISAI_NO = ' || gMgrMeisaiNo;
   		EXECUTE sSql;
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfadi005r08112_updateshinkiboshu (inKbn SHINKIBOSHU.TOTSUGO_KEKKA_KBN%TYPE, inKessaiFlg integer DEFAULT 0) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfadi005r08112_updateshinkikiroku (
	inKbn SHINKIKIROKU.TOTSUGO_KEKKA_KBN%TYPE,
	USER_ID varchar(10),
	l_inItakuKaishaCd SHINKIKIROKU.ITAKU_KAISHA_CD%TYPE,
	l_inKessaiNo SHINKIKIROKU.KESSAI_NO%TYPE
) AS $body$
BEGIN
	UPDATE 	SHINKIKIROKU
	SET		TOTSUGO_KEKKA_KBN = inKbn,
				KK_STAT = pkKkNotice.MGR_KKSTAT_SEND(),
				LAST_TEISEI_DT = to_timestamp(pkDate.getCurrentTime(), 'YYYY-MM-DD HH24:MI:SS.US'),
				KOUSIN_ID = USER_ID
	WHERE	ITAKU_KAISHA_CD = l_inItakuKaishaCd
	  AND	KESSAI_NO = l_inKessaiNo;
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfadi005r08112_updateshinkikiroku (inKbn SHINKIKIROKU.TOTSUGO_KEKKA_KBN%TYPE) FROM PUBLIC;
