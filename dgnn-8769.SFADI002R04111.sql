CREATE OR REPLACE FUNCTION sfadi002r04111 (
	l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE,
	l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE,
	l_inItakuKaishaCd UPD_MGR_SHN.ITAKU_KAISHA_CD%TYPE,
	l_inMgrCd UPD_MGR_SHN.MGR_CD%TYPE,
	l_inKbn integer,
	l_inItakuKaishaRnm MITAKU_KAISHA.ITAKU_KAISHA_RNM%TYPE
) RETURNS integer AS $body$
DECLARE

--   
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 銘柄情報変更結果通知突合処理
-- *   銘柄_償還回次テーブルとの突合処理
-- *
-- * @author  藤江
-- * @version $Revision: 1.4 $
-- * @param  	l_inKkSakuseiDt 	IN 	KK_RENKEI.KK_SAKUSEI_DT%TYPE	機構連携作成日時
-- * @param  	l_inDenbunMeisaiNo 	IN 	KK_RENKEI.DENBUN_MEISAI_NO%TYPE	電文明細Ｎｏ
-- * @param 	l_inItakuKaishaCd  	IN 	UPD_MGR_SHN.ITAKU_KAISHA_CD		委託会社コード
-- * @param 	l_inMgrCd  			IN 	UPD_MGR_SHN.MGR_CD%TYPE			銘柄コード
-- * @param 	l_inKbn 			IN 	INTEGER
-- *									--  1: 銘柄情報
-- *									--  2: 利払情報
-- *									--  3: 償還情報 コールオプション（全額償還）
-- *									4: 償還情報 定時償還
-- *									5: 償還情報 コールオプション（一部償還）
-- *									--  6: 償還情報 プットオプション
-- * @param 	l_inItakuKaishaRnm 	IN 	MITAKU_KAISHA.ITAKU_KAISHA_RNM%TYPE 	委託会社略称
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
	curComp 		integer;			-- カーソルＩＤ
	gCompFlg 		integer;			-- 突合結果フラグ　0:一致  1:不一致
	gCompAllCnt		integer;			-- 検索結果の突合関連の項目数
	intCount		integer;
	gMsg			varchar(100);		-- 確認リストに出力するエラー内容
	gGyomuYmd		SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;	-- 業務日付
	tMoto KK_RENKEI.ITEM001%type[];						-- 比較元
	tSaki KK_RENKEI.ITEM001%type[];						-- 比較先
 	result			integer;			-- 本ＳＰのリターンコード
	gMgrCd					MGR_KIHON.MGR_CD%TYPE;				-- 銘柄コード
	gMgrRnm					MGR_KIHON.MGR_RNM%TYPE;				-- 銘柄略称
	gIsinCd					MGR_KIHON.ISIN_CD%TYPE;				-- ISINコード
	gItakuKaishaCd_MG3		UPD_MGR_KHN.ITAKU_KAISHA_CD%TYPE;	-- 銘柄_償還回次.委託会社コード
	-- 突合情報取得ＳＰパラメータ 
	gInTotsugoNo 	varchar(12);				-- 突合識別番号
	gInCondition 	varchar(4000);				-- 検索条件（突合条件マスタに登録している条件以外）
	gOutSql 		varchar(20000);			-- ＳＱＬ文字列
	gOutItemCnt 	numeric(3);					-- 突合項目数
	gOutItemAtt 	PkCompare.t_ItemAtt_type;	-- 突合項目属性（条件番号、表示項目名）
	gRtn			integer;					-- 突合情報取得ＳＰの戻り値	
--====================================================================*
--					定数定義
-- *====================================================================
	-- 本SPのID
	SP_ID				CONSTANT varchar(20) := 'SFADI002R04111';
	-- ユーザID
	USER_ID				CONSTANT varchar(10) := pkconstant.BATCH_USER();
	-- 帳票ID
	REPORT_ID			CONSTANT varchar(10) := '';
	-- SELECT句 (突合条件マスタの登録値)の何番目の項目か
	-- (突合項目以外の項目の中での番号)
	POS_MGR_CD			CONSTANT numeric(2) := 1;		-- 銘柄_基本.銘柄コード
	POS_MGR_RNM			CONSTANT numeric(2) := 2;		-- 銘柄_基本.銘柄略称
	POS_ISIN_CD			CONSTANT numeric(2) := 3;		-- 銘柄_基本.ＩＳＩＮコード
	POS_ITAKU_MG3		CONSTANT numeric(2) := 4;

	tempResult record;
--====================================================================*
--   メイン
-- *====================================================================
BEGIN
	result := pkconstant.FATAL();
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' ' || l_inKbn || ' START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inKkSakuseiDt::text), '') = ''
	  OR coalesce(trim(both l_inDenbunMeisaiNo::text), '') = ''
	  OR coalesce(trim(both l_inItakuKaishaCd::text), '') = ''
	  OR coalesce(trim(both l_inMgrCd::text), '') = ''
	  OR coalesce(trim(both l_inKbn::text), '') = ''
	  OR coalesce(trim(both l_inItakuKaishaRnm::text), '') = '' THEN
		-- パラメータエラー
		CALL pkLog.error('ECM501', SP_ID, ' ');
		RETURN result;
	END IF;
	-- 業務日付取得  
	gGyomuYmd := pkDate.getGyomuYmd();
	-- 突合情報取得ＳＰをＣＡＬＬ   
	-- 入力パラメータ設定
	gInTotsugoNo := pkKkNotice.DCD_MGR_CHG_RSLT() || l_inKbn::text;
	gInCondition := 'RT02.KK_SAKUSEI_DT = ''' || l_inKkSakuseiDt
				|| ''' AND RT02.DENBUN_MEISAI_NO = ' || l_inDenbunMeisaiNo 
				|| ' AND VMG1.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''''
				|| ' AND VMG1.MGR_CD = ''' || l_inMgrCd || ''''
				|| ' AND MG3.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''''
				|| ' AND MG3.MGR_CD = ''' || l_inMgrCd || '''';
	-- ＳＰ実行  ＳＱＬと突合項目数を取得する
  	tempResult := pkCompare.getCompareInfo(gInTotsugoNo, gInCondition);
		gRtn := tempResult.extra_param;
		gOutSql := tempResult.l_outSql;
		gOutItemCnt := tempResult.l_outItemCnt;
		gOutItemAtt := tempResult.l_outItemAtt;
	IF gRtn != 0 THEN
		RETURN result;
	END IF;
	gCompAllCnt := gOutItemCnt * 2;
   -- 問い合わせ用のカーソルをオープンする 
   curComp := DBMS_SQL.OPEN_CURSOR();
   -- SELECT SQLを解析 
    CALL DBMS_SQL.PARSE(curComp,gOutSql);
   -- 出力変数を定義 
	CALL SFADI002R04111_defineColumn(gOutItemCnt,
																	curComp,
																	gCompAllCnt,
																	gMgrCd,
																	gMgrRnm,
																	gIsinCd,
																	POS_MGR_CD,
																	POS_MGR_RNM,
																	POS_ISIN_CD,
																	POS_ITAKU_MG3,
																	gItakuKaishaCd_MG3,
																	tMoto,
																	tSaki);
	-- 検索実行 
	intCount := DBMS_SQL.EXECUTE(curComp);
	-- FETCH 
    IF DBMS_SQL.FETCH_ROWS(curComp) = 0 THEN
    	-- 該当データがない場合 (銘柄_償還回次テーブルデータなし)
		CALL DBMS_SQL.CLOSE_CURSOR(curComp);
		CALL pkLog.error('ECM3A1', SP_ID, '銘柄_償還回次');
		result := pkconstant.NO_DATA_FIND();
		RETURN(result);
    END IF;
     -- 値を取り出す 
	-- 突合項目以外
	CALL SFADI002R04111_getColumnValue(curComp,
																		gCompAllCnt,
																		gMgrCd,
																		gMgrRnm,
																		gIsinCd,
																		POS_MGR_CD,
																		POS_MGR_RNM,
																		POS_ISIN_CD,
																		POS_ITAKU_MG3,
																		gItakuKaishaCd_MG3);
	gCompFlg := 0;
	-- 突合項目
	-- 　比較元、比較先、条件番号の組を１組ずつ取り出し、突合
	-- 　突合項目数繰り返す
	DECLARE
		tempMoto varchar(400);
		tempSaki varchar(400);
	BEGIN
		FOR i IN 1 .. gOutItemCnt LOOP
			tempMoto := '';
			tempSaki := '';
			CALL DBMS_SQL.COLUMN_VALUE(curComp, (i * 2 -1)::int, tempMoto);
			CALL DBMS_SQL.COLUMN_VALUE(curComp, (i * 2)::int, tempSaki);
			tMoto[i] := tempMoto;
			tSaki[i] := tempSaki;
--
--        DBMS_OUTPUT.PUT_LINE('項目' || i);
--        DBMS_OUTPUT.PUT_LINE('tMoto_' || [i] || ' = ' || tMoto[i]);
--        DBMS_OUTPUT.PUT_LINE('tSaki_' || [i] || ' = ' || tSaki[i]);
--
		-- 突合処理
		IF coalesce(trim(both tMoto[i]), ' ') != coalesce(trim(both tSaki[i]), ' ') THEN 		-- 不一致のとき
--			DBMS_OUTPUT.PUT_LINE('NG');
   			IF DEBUG = 1 THEN
   				CALL pkLog.debug(USER_ID, REPORT_ID, 'NG');
                CALL pkLog.debug(USER_ID, REPORT_ID, 'dispNm' || i || ' = ' || gOutItemAtt[i].dispNm);
                CALL pkLog.debug(USER_ID, REPORT_ID, 'tMoto_' || i || ' = ' || tMoto[i]);
                CALL pkLog.debug(USER_ID, REPORT_ID, 'tSaki_' || i || ' = ' || tSaki[i]);
   			END IF;
			gCompFlg := 1;
			-- 確認リストのエラー内容
			gMsg := gOutItemAtt[i].dispNm;		-- 表示項目名
			IF (gMsg IS NOT NULL AND gMsg::text <> '') THEN
				gMsg := gMsg || 'が';
			END IF;
			gMsg := gMsg || '突合エラーです。';
			-- 確認リスト出力内容を帳票ワークテーブルに登録
			CALL pkKakuninList.insertKakuninData(
					l_inItakuKaishaCd,
					USER_ID,
					pkKakuninList.CHOHYO_KBN_BATCH(),
					gGyomuYmd,
					gMsg,
					gIsinCd,
					gMgrCd,
					gMgrRnm,
					tSaki[i],
					tMoto[i],
					pkKkNotice.DCD_MGR_CHG_RSLT(),
					l_inItakuKaishaRnm
			);
--		ELSE	
--			DBMS_OUTPUT.PUT_LINE('OK');
		END IF;
	END LOOP;
	END; -- End of DECLARE block for temp variables
     -- カーソル　クローズ 
	CALL DBMS_SQL.CLOSE_CURSOR(curComp);
	IF gCompFlg = 0 THEN
    	result := pkconstant.success();
    ELSE
    	result := pkconstant.RECONCILE_ERROR();
    END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, '償還回次突合SP  result = ' || result);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' ' || l_inKbn || ' END');	END IF;
	RETURN(result);
--====================================================================*
--    異常終了 出口
-- *====================================================================
EXCEPTION
	-- その他・例外エラー 
	WHEN OTHERS THEN
		IF curComp IS NOT NULL AND DBMS_SQL.IS_OPEN(curComp) THEN
			CALL DBMS_SQL.CLOSE_CURSOR(curComp);
		END IF;
		CALL pkLog.fatal('ECM701', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
		RETURN result;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi002r04111 ( l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE, l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE, l_inItakuKaishaCd UPD_MGR_SHN.ITAKU_KAISHA_CD%TYPE, l_inMgrCd UPD_MGR_SHN.MGR_CD%TYPE, l_inKbn integer, l_inItakuKaishaRnm MITAKU_KAISHA.ITAKU_KAISHA_RNM%TYPE ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfadi002r04111_definecolumn (
	gOutItemCnt numeric(3),
	curComp integer,
	gCompAllCnt integer,
	gMgrCd MGR_KIHON.MGR_CD%TYPE,
	gMgrRnm MGR_KIHON.MGR_RNM%TYPE,
	gIsinCd MGR_KIHON.ISIN_CD%TYPE,
	POS_MGR_CD numeric(2),
	POS_MGR_RNM numeric(2),
	POS_ISIN_CD numeric(2),
	POS_ITAKU_MG3 numeric(2),
	gItakuKaishaCd_MG3 UPD_MGR_KHN.ITAKU_KAISHA_CD%TYPE,
	tMoto IN OUT varchar(400)[],
	tSaki IN OUT varchar(400)[]
) AS $body$
BEGIN
    	-- 配列初期化 
    	FOR i IN 1 .. gOutItemCnt LOOP
    		tMoto[i] := '';
    		tSaki[i] := '';
    	END LOOP;
       -- 出力変数を定義 
    	-- 突合項目以外
        CALL DBMS_SQL.DEFINE_COLUMN(curComp, (gCompAllCnt + POS_MGR_CD)::int, gMgrCd, 20);
        CALL DBMS_SQL.DEFINE_COLUMN(curComp, (gCompAllCnt + POS_MGR_RNM)::int, gMgrRnm, 100);
        CALL DBMS_SQL.DEFINE_COLUMN(curComp, (gCompAllCnt + POS_ISIN_CD)::int, gIsinCd, 20);
        CALL DBMS_SQL.DEFINE_COLUMN(curComp, (gCompAllCnt + POS_ITAKU_MG3)::int, gItakuKaishaCd_MG3, 20);
    	-- 突合項目
    	FOR i IN 1 .. gOutItemCnt LOOP
    	    CALL DBMS_SQL.DEFINE_COLUMN(curComp, (i * 2 -1)::int, tMoto[i], 400);
    	    CALL DBMS_SQL.DEFINE_COLUMN(curComp, (i * 2)::int, tSaki[i], 400);
    	END LOOP;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfadi002r04111_definecolumn () FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfadi002r04111_getcolumnvalue (
	curComp integer,
	gCompAllCnt integer,
	gMgrCd MGR_KIHON.MGR_CD%TYPE,
	gMgrRnm MGR_KIHON.MGR_RNM%TYPE,
	gIsinCd MGR_KIHON.ISIN_CD%TYPE,
	POS_MGR_CD numeric(2),
	POS_MGR_RNM numeric(2),
	POS_ISIN_CD numeric(2),
	POS_ITAKU_MG3 numeric(2),
	gItakuKaishaCd_MG3 UPD_MGR_KHN.ITAKU_KAISHA_CD%TYPE
) AS $body$
BEGIN
         -- 値を取り出す 
    	-- 突合項目以外
    	CALL DBMS_SQL.COLUMN_VALUE(curComp, (gCompAllCnt + POS_MGR_CD)::int, gMgrCd);
    	CALL DBMS_SQL.COLUMN_VALUE(curComp, (gCompAllCnt + POS_MGR_RNM)::int, gMgrRnm);
    	CALL DBMS_SQL.COLUMN_VALUE(curComp, (gCompAllCnt + POS_ISIN_CD)::int, gIsinCd);
    	CALL DBMS_SQL.COLUMN_VALUE(curComp, (gCompAllCnt + POS_ITAKU_MG3)::int, gItakuKaishaCd_MG3);
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfadi002r04111_getcolumnvalue () FROM PUBLIC;