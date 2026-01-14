CREATE OR REPLACE FUNCTION sfadi002r15211 (
	l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE,
	l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE,
	l_inJipDenbunCd KK_RENKEI.JIP_DENBUN_CD%TYPE
) RETURNS integer AS $body$
DECLARE

--
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 銘柄関連通知取込み（銘柄情報更新−ＩＳＩＮコード、銘柄突合）
-- *   ＩＳＩＮコード付番共通　 突合・更新処理
-- *
-- * @author  藤江
-- * @version $Id: SFADI002R15211.sql 7920 2017-03-16 02:52:41Z j8800053 $
-- * @param  	l_inKkSakuseiDt 	IN 	KK_RENKEI.KK_SAKUSEI_DT%TYPE	機構連携作成日時
-- * @param  	l_inDenbunMeisaiNo 	IN 	KK_RENKEI.DENBUN_MEISAI_NO%TYPE	電文明細Ｎｏ
-- * @param  	l_inJipDenbunCd 	IN 	KK_RENKEI.JIP_DENBUN_CD%TYPE	JIP電文コード
-- * @return 	リターンコード		INTEGER
-- *   		 pkconstant.success()		 		: 正常
-- *   		 pkconstant.NO_DATA_FIND()	 	: 突合相手なし
-- *   		 pkconstant.RECONCILE_ERROR()		: 突合エラー
-- *           pkconstant.FATAL() 			 	: 致命的エラー
-- 
--====================================================================
--					デバッグ機能										  
--====================================================================
	DEBUG	numeric(1)	:= 1;
	tempResult record;
	tempRtn integer;
	recKK record;
--====================================================================*
--                  変数定義
-- *====================================================================
	curComp 		integer;			-- カーソルＩＤ
	gCompFlg 		integer;			-- 突合結果フラグ　0:一致  1:不一致
	gCompAllCnt		integer;			-- 検索結果の突合関連の項目数
	intCount		integer;
	gMsg			varchar(100);		-- 確認リストに出力するエラー内容
	gGyomuYmd		SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;	-- 業務日付
	gTsuchiNm       MSG_TSUCHI.TSUCHI_NM%TYPE;          -- 通知内容
	tMoto varchar(400)[];						-- 比較元
	tSaki varchar(400)[];						-- 比較先
	v_CFlg numeric(1)[];					-- 条件フラグ
 	result			integer;						-- 本ＳＰのリターンコード
 	gResultCd	    integer;						-- リターンコード(ISIN重複)
	gItakuKaishaCd 	MGR_KIHON.ITAKU_KAISHA_CD%TYPE;	-- 委託会社コード
	gJipDenbunCd 	KK_RENKEI.JIP_DENBUN_CD%TYPE;  	-- JIP電文コード
	gItakuKaishaRnm	MITAKU_KAISHA.ITAKU_KAISHA_RNM%TYPE;	-- 委託会社略称
	gMgrCd			KK_RENKEI.ITEM001%TYPE;			-- 機構連携−受信.社内処理用項目２(銘柄コード)
	gShinkiKbn		KK_RENKEI.ITEM001%TYPE;			-- 機構連携−受信.新規訂正取消区分
	gErrCd			KK_RENKEI.ITEM001%TYPE;			-- 機構連携−受信.エラーコード／エラー理由コード
	gIsinCd			KK_RENKEI.ITEM001%TYPE;			-- 機構連携−受信.ＩＳＩＮコード
	gHakkoRnm		KK_RENKEI.ITEM001%TYPE;			-- 機構連携−受信.銘柄略称　発行者略称
	gKaigo			KK_RENKEI.ITEM001%TYPE;			-- 機構連携−受信.銘柄略称　回号等
	gBoshuKbn		KK_RENKEI.ITEM001%TYPE;			-- 機構連携−受信.銘柄略称　募集区分
	gTokureiFlg		KK_RENKEI.ITEM001%TYPE;			-- 機構連携−受信.特例社債フラグ
	gDenbunMeisai	KK_RENKEI.ITEM001%TYPE;			-- 機構連携−送信.電文明細Ｎｏ
	gMgrTaikeiKbn	MGR_STS.MGR_TAIKEI_KBN%TYPE;	-- 銘柄ステータス管理.銘柄体系区分
	gMgrRnm			MGR_KIHON.MGR_RNM%TYPE;			-- 銘柄_基本(VIEW).銘柄略称
	gKkStat			MGR_STS.KK_STAT%TYPE;			-- 銘柄ステータス管理(VIEW).機構ステータス
	gItakuKaishaCd_V	MGR_KIHON.ITAKU_KAISHA_CD%TYPE;	-- 銘柄_基本(VIEW).委託会社コード
	gPartmgrKbn		MGR_KIHON.PARTMGR_KBN%TYPE;         -- 銘柄_基本(VIEW).分割銘柄区分
	gKkSakuseiDt    KK_RENKEI.KK_SAKUSEI_DT%TYPE;   -- 機構連携-機構送信日時
	gGyomuStatCd    KK_RENKEI.GYOMU_STAT_CD%TYPE;   -- 機構連携-業務状態コード
	gSoujuMethod	KK_RENKEI.SOUJU_METHOD_CD%TYPE; -- 機構連携-送受信方法コード IP-04473
	gOutMgrCd		KK_RENKEI.ITEM001%TYPE;			-- 変更対象銘柄コード
	gOutMgrRnm		MGR_KIHON.MGR_RNM%TYPE;			-- 変更対象銘柄略称
	gOutIsinCd		MGR_KIHON.ISIN_CD%TYPE;			-- 変更後ISINコード
	gOutWhether		char(1);					-- 変更有無　0:無  1：有
	gChkKkPhase                 MGR_KIHON_VIEW.KK_PHASE%TYPE := 'M1';                       -- 機構フェーズ（チェック用）
	gChkKkStat                  MGR_KIHON_VIEW.KK_PHASE%TYPE := pkKkNotice.MGR_KKSTAT_SEND(); -- 機構ステータス（チェック用）
	-- 突合情報取得ＳＰパラメータ 
	gInCondition 	varchar(4000);		-- 検索条件（突合条件マスタに登録している条件以外）
	gOutSql 		varchar(20000);	-- ＳＱＬ文字列
	gOutItemCnt 	numeric(3);			-- 突合項目数
	gOutItemAtt 	PkCompare.t_ItemAtt_type;	-- 突合項目属性
	gRtn			integer;			-- 発行体更新SFの戻り値
	gRtnDmy			integer;			-- 突合情報取得ＳＰの戻り値
--====================================================================*
--					定数定義
-- *====================================================================
	-- 本SPのID
	SP_ID				CONSTANT varchar(20) := 'SFADI002R15211';
	-- ユーザID
	USER_ID				CONSTANT varchar(10) := pkconstant.BATCH_USER();
	-- 帳票ID
	REPORT_ID			CONSTANT varchar(10) := '';
	-- 突合条件マスタのSELECT句の何番目の項目か（突合項目以外の項目の中での番号）
	POS_MGR_CD			CONSTANT integer := 1;		-- 機構連携−受信.社内処理用項目２(銘柄コード)
	POS_SHINKI_KBN		CONSTANT integer := 2;		-- 機構連携−受信.新規訂正取消区分
	POS_ERR_CD			CONSTANT integer := 3;		-- 機構連携−受信.エラーコード／エラー理由コード
	POS_ISIN_CD			CONSTANT integer := 4;		-- 機構連携−受信.ＩＳＩＮコード
	POS_HAKKO_RNM		CONSTANT integer := 5;		-- 機構連携−受信.銘柄略称　発行者略称
	POS_KAIGO			CONSTANT integer := 6;		-- 機構連携−受信.銘柄略称　回号等
	POS_BOSHU_KBN		CONSTANT integer := 7;		-- 機構連携−受信.銘柄略称　募集区分
	POS_TOKUREI_FLG		CONSTANT integer := 8;		-- 機構連携−受信.特例社債フラグ
	POS_DENBUN_MEISAI	CONSTANT integer := 9;		-- 機構連携−送信.電文明細Ｎｏ
	POS_MGR_TAIKEI_KBN	CONSTANT integer := 10;		-- 銘柄ステータス管理.銘柄体系区分
	POS_MGR_RNM			CONSTANT integer := 11;		-- 銘柄_基本(VIEW).銘柄略称
	POS_KK_STAT			CONSTANT integer := 12;		-- 銘柄ステータス管理(VIEW).機構ステータス
	POS_ITAKU_CD_V		CONSTANT integer := 13;		-- 銘柄_基本(VIEW).委託会社コード
	POS_PARTMGR_KBN     CONSTANT integer := 14;       -- 銘柄_基本(VIEW).分割銘柄区分
	POS_KK_SAKUSEI_DT   CONSTANT integer := 15;       -- 機構連携-送信.機構送信日時
	POS_GYOMU_STAT_CD   CONSTANT integer := 16;
--====================================================================*
--   メイン
-- *====================================================================
BEGIN
	result := pkconstant.FATAL();
	RAISE NOTICE 'DEBUG: SFADI002R15211 START - KkSakuseiDt=%, DenbunMeisaiNo=%, JipDenbunCd=%', l_inKkSakuseiDt, l_inDenbunMeisaiNo, l_inJipDenbunCd;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inKkSakuseiDt::text), '') = ''
	  OR coalesce(trim(both l_inDenbunMeisaiNo::text), '') = ''
	  OR coalesce(trim(both l_inJipDenbunCd::text), '') = '' THEN
		-- パラメータエラー
		CALL pkLog.error('ECM501', SP_ID, ' ');
		RETURN result;
	END IF;
   	-- 機構連携テーブル、委託会社マスタより 委託会社コード、委託会社略称等を取得 
	CALL pkKkNotice.getKK_ItakuR(
		l_inKkSakuseiDt,
		l_inDenbunMeisaiNo,
		gItakuKaishaCd,
		gJipDenbunCd,
		gItakuKaishaRnm
	);
	RAISE NOTICE 'DEBUG: After getKK_ItakuR - ItakuKaishaCd=%, JipDenbunCd=%', gItakuKaishaCd, gJipDenbunCd;
	-- 電文コードのチェック
	IF gJipDenbunCd != l_inJipDenbunCd THEN
		-- 電文コードエラー
		CALL pkLog.error('ECM3A4', SP_ID, gJipDenbunCd);
		RETURN result;
	END IF;
    -- 突合済みかどうかを最初にチェック
    -- 下の動的ＳＱＬに関しての変更はなし（そのまま） 2006.01.16
	RAISE NOTICE 'DEBUG: Checking isTotsugozumi';
		tempResult := SFADI002R15211_isTotsugozumi(l_inKkSakuseiDt,l_inDenbunMeisaiNo, result);
	RAISE NOTICE 'DEBUG: isTotsugozumi result=%', tempResult.rtn;
    IF tempResult.rtn THEN
		-- IP-04473 start
			BEGIN
					-- 送受信方法コードを取得する。
					SELECT
							RT02.SOUJU_METHOD_CD
					INTO STRICT
							gSoujuMethod
					FROM
							KK_RENKEI RT02
					WHERE  RT02.KK_SAKUSEI_DT = l_inKkSakuseiDt
					AND    RT02.DENBUN_MEISAI_NO = l_inDenbunMeisaiNo;
			EXCEPTION
					WHEN no_data_found THEN
							CALL pkLog.DEBUG(SP_ID,USER_ID,'機構連携の送受信方法コード取得ＳＱＬでデータが取得できなかった。');
				result := pkconstant.FATAL();
							RAISE;
			END;
			RAISE NOTICE 'DEBUG: Already matched - gSoujuMethod=%', gSoujuMethod;
			-- CSVの場合は突合エラーを返す
			IF gSoujuMethod = 'C' THEN
				RAISE NOTICE 'DEBUG: Returning RECONCILE_ERROR(50) because already matched and CSV';
				RETURN pkconstant.RECONCILE_ERROR();
			-- CSV以外の場合は業務状態コードに"論理削除"を設定する
			ELSE
				RAISE NOTICE 'DEBUG: Already matched but not CSV, setting logical delete';
				--突合対象外のときは機構連携テーブル受信電文の業務状態コードに99:論理削除をセットする
						-- リターン値は通常利用しない（突合処理とは直接関係ないため）
				gRtn := SFADI002R15211_updateKkRenkeiRcv(USER_ID,
																								SP_ID,
																								l_inKkSakuseiDt,
																								l_inDenbunMeisaiNo,
																								l_inJipDenbunCd,'99');
				-- すでに突合済みなので、そのまま正常終了する。
				RETURN pkconstant.success();
			END IF;
		-- IP-04473 end
    END IF;
	RAISE NOTICE 'DEBUG: Not matched yet, proceeding with comparison';
	-- 突合情報取得ＳＰをＣＡＬＬ   
	-- ＳＱＬと突合項目数を取得する 
	-- 入力パラメータ設定
	gInCondition := 'RT02R.KK_SAKUSEI_DT = ''' || l_inKkSakuseiDt
				|| ''' AND RT02R.DENBUN_MEISAI_NO = ' || l_inDenbunMeisaiNo
				|| ' AND VMG1.ITAKU_KAISHA_CD(+) = ''' || gItakuKaishaCd || '''';
	-- ＳＰ実行
	--　（「銘柄情報登録受付通知兼ＩＳＩＮコード付番通知」、「ＩＳＩＮコード付番通知」は
	--		フォーマットが同じなので、突合項目マスタ、突合条件マスタは共通で作成している）
  	tempResult := pkCompare.getCompareInfo(pkKkNotice.DCD_ISIN(), gInCondition);
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
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, substr(gOutSql,1,200));END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, substr(gOutSql,201,200));END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, substr(gOutSql,401,200));END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, substr(gOutSql,601,200));END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, substr(gOutSql,801,200));END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, substr(gOutSql,1001,200));END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, substr(gOutSql,1201,200));END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, substr(gOutSql,1401,200));END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, substr(gOutSql,1601,200));END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, substr(gOutSql,1801,200));END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, substr(gOutSql,2001,200));END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, substr(gOutSql,2201,200));END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, substr(gOutSql,2401,200));END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, substr(gOutSql,2801,200));END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, substr(gOutSql,3001,200));END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, substr(gOutSql,3201,200));END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, substr(gOutSql,3401,200));END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, substr(gOutSql,3601,200));END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, substr(gOutSql,3801,200));END IF;
   -- 出力変数を定義 
	CALL SFADI002R15211_defineColumn(gOutItemCnt,
																	gCompAllCnt,
																	curComp,
																	POS_MGR_CD,
																	POS_SHINKI_KBN,
																	POS_ERR_CD,
																	POS_ISIN_CD,
																	POS_HAKKO_RNM,
																	POS_KAIGO,
																	POS_BOSHU_KBN,
																	POS_TOKUREI_FLG,
																	POS_DENBUN_MEISAI,
																	POS_MGR_TAIKEI_KBN,
																	POS_MGR_RNM,
																	POS_KK_STAT,
																	POS_ITAKU_CD_V,
																	POS_PARTMGR_KBN,
																	POS_KK_SAKUSEI_DT,
																	POS_GYOMU_STAT_CD,
																	gMgrCd,
																	gShinkiKbn,
																	gErrCd,
																	gIsinCd,
																	gHakkoRnm,
																	gKaigo,
																	gBoshuKbn,
																	gTokureiFlg,
																	gDenbunMeisai,
																	gMgrTaikeiKbn,
																	gMgrRnm,
																	gKkStat,
																	gItakuKaishaCd_V,
																	gPartmgrKbn,
																	gKkSakuseiDt,
																	gGyomuStatCd,
																	tMoto,
																	tSaki);
	-- 検索実行 
	intCount := DBMS_SQL.EXECUTE(curComp);
	-- FETCH 
    IF DBMS_SQL.FETCH_ROWS(curComp) = 0 THEN
    	-- 該当データがない場合は終了
		CALL DBMS_SQL.CLOSE_CURSOR(curComp);
		CALL pkLog.error('ECM3A3', SP_ID, '突合時');
		RETURN pkconstant.NO_DATA_FIND();
    END IF;
     -- 値を取り出す 
	-- 突合項目以外
	CALL SFADI002R15211_getColumnValue(gCompAllCnt,
																		curComp,
																		POS_MGR_CD,
																		POS_SHINKI_KBN,
																		POS_ERR_CD,
																		POS_ISIN_CD,
																		POS_HAKKO_RNM,
																		POS_KAIGO,
																		POS_BOSHU_KBN,
																		POS_TOKUREI_FLG,
																		POS_DENBUN_MEISAI,
																		POS_MGR_TAIKEI_KBN,
																		POS_MGR_RNM,
																		POS_KK_STAT,
																		POS_ITAKU_CD_V,
																		POS_PARTMGR_KBN,
																		POS_KK_SAKUSEI_DT,
																		POS_GYOMU_STAT_CD,
																		gMgrCd,
																		gShinkiKbn,
																		gErrCd,
																		gIsinCd,
																		gHakkoRnm,
																		gKaigo,
																		gBoshuKbn,
																		gTokureiFlg,
																		gDenbunMeisai,
																		gMgrTaikeiKbn,
																		gMgrRnm,
																		gKkStat,
																		gItakuKaishaCd_V,
																		gPartmgrKbn,
																		gKkSakuseiDt,
																		gGyomuStatCd);
	-- エラーコードが'ACPT'の場合、何も行わず正常終了でreturnする 
	IF trim(both gErrCd) = 'ACPT' THEN
		result := pkconstant.success();
		RETURN result;
	END IF;
	--機構連携テーブル送信電文の業務状態コードが10:突合済みのときは突合対象外とする
	IF gGyomuStatCd != '10' THEN
		-- 機構連携−受信にエラーがセットされていれば、終了する
--		 *   次の場合、エラーとする
--		 *    「銘柄情報登録受付通知兼ＩＳＩＮコード付番通知」の場合、エラーコードがNULL・ACPT以外
--		 *    「ＩＳＩＮコード付番」の場合、エラー理由コードがNULL以外
--		 
		IF (trim(both gErrCd) IS NOT NULL AND (trim(both gErrCd))::text <> '') THEN
			IF gJipDenbunCd != pkKkNotice.DCD_MGR_ISIN() OR trim(both gErrCd) != 'ACPT' THEN
				-- 銘柄ステータス管理．銘柄機構エラーコードを更新
				result := SFADI002R15211_updateMgrSts(gErrCd,
																							USER_ID,
																							SP_ID,
																							gItakuKaishaCd,
																							gMgrCd,
																							gChkKkStat,
																							gChkKkPhase,pkKkNotice.MGR_KKERR_ERR());
				CALL pkLog.info(USER_ID, REPORT_ID, '機構連携−受信にエラーがセットされています。');
				-- カーソル　クローズ 
				CALL DBMS_SQL.CLOSE_CURSOR(curComp);
				RETURN result;
			END IF;
		END IF;
		-- 新規訂正取消区分が「取消」の場合は終了する　
		IF gShinkiKbn = '2'  THEN
			result := pkconstant.success();
			CALL pkLog.info(USER_ID, REPORT_ID, '新規訂正取消区分が「取消」です。');
			-- カーソル　クローズ 
			CALL DBMS_SQL.CLOSE_CURSOR(curComp);
			RETURN result;
		END IF;
		-- 業務日付取得  
		gGyomuYmd := pkDate.getGyomuYmd();
		-- 機構連携−送信（銘柄情報登録）にキーが一致するデータがない場合　
		IF coalesce(trim(both gDenbunMeisai)::text, '') = '' OR gKkStat = '04' THEN
			gMsg := '突合相手がありません。';
			-- 確認リスト出力内容を帳票ワークテーブルに登録
			CALL pkKakuninList.insertKakuninData(
				gItakuKaishaCd,
				USER_ID,
				pkKakuninList.CHOHYO_KBN_BATCH(),
				gGyomuYmd,
				gMsg,
				gIsinCd,
				gMgrCd,
				gMgrRnm,
				NULL,
				NULL,
				gJipDenbunCd,
				gItakuKaishaRnm
			);
			-- カーソル　クローズ 
			CALL DBMS_SQL.CLOSE_CURSOR(curComp);
			CALL pkLog.error('ECM3A1', SP_ID, '機構連携−銘柄情報登録がありません。');
			RETURN pkconstant.NO_DATA_FIND();
		END IF;
		-- 銘柄_基本−銘柄ステータス管理VIEWにキーが一致する「送信済」のデータがない場合　
		IF coalesce(trim(both gItakuKaishaCd_V)::text, '') = '' THEN
			CALL pkLog.error('ECM3A3', SP_ID, '銘柄_基本VIEW  該当キーの「送信済」のデータがありません。');
			-- カーソル　クローズ 
			CALL DBMS_SQL.CLOSE_CURSOR(curComp);
			RETURN pkconstant.NO_DATA_FIND();
		END IF;
		-- 条件フラグ　初期化
		v_CFlg := v_CFlg_type(0,0,0);
		-- 条件チェック 　（突合対象か対象外かを判断するための条件）　
		CALL SFADI002R15211_chkJoken(gShinkiKbn,
																gTokureiFlg,
																gMgrTaikeiKbn,
																gPartmgrKbn,
																v_CFlg);
		-- 突合処理 
		tempResult := SFADI002R15211_compareData(gOutItemCnt,
																						curComp,
																						tMoto,
																						tSaki,
																						gOutItemAtt,
																						gItakuKaishaCd,
																						USER_ID,
																						gGyomuYmd,
																						gIsinCd,
																						gMgrCd,
																						gMgrRnm,
																						gJipDenbunCd,
																						gItakuKaishaRnm,
																						gMsg);
		gCompFlg := tempResult.flg;
		-- 銘柄_基本テーブル更新（ISINコード、機構発行者略称）
		IF SFADI002R15211_updateMgrKihon(gShinkiKbn,
																		gMgrTaikeiKbn,
																		gIsinCd,
																		gTokureiFlg,
																		gPartmgrKbn,
																		gHakkoRnm,
																		gKaigo,
																		gBoshuKbn,
																		USER_ID,
																		SP_ID,
																		gItakuKaishaCd,
																		gMgrCd) = pkconstant.NO_DATA_FIND() THEN
			RETURN pkconstant.NO_DATA_FIND();
		END IF;
		-- 銘柄_機構基本テーブル更新
		CALL SFADI002R15211_delInsMgrKikoKihon(gItakuKaishaCd,
																				gMgrCd,
																				USER_ID,
																				recKK,
																				tempRtn);
		IF tempRtn = pkconstant.FATAL() THEN
			RETURN pkconstant.FATAL();
		END IF;
		-- 発行体マスタ更新（機構発行体コード、機構発行者略称）
		IF gCompFlg <> 1 THEN
    		gRtn := SFADI002R15211_updateHakkotai(gItakuKaishaCd,
																							gMgrCd,
																							gGyomuYmd,
																							gIsinCd,
																							gMgrRnm,
																							gJipDenbunCd,
																							gItakuKaishaRnm,
																							l_inKkSakuseiDt,
																							l_inDenbunMeisaiNo,
																							l_inJipDenbunCd,
																							recKK,
																							USER_ID,
																							SP_ID);
    		IF gRtn = pkconstant.FATAL() THEN
    			RETURN pkconstant.FATAL();
    		END IF;
		END IF;
		-- 突合不一致の項目がある場合
		IF gCompFlg = 1 THEN
				CALL pkLog.error('ECM3A2', SP_ID, ' ');
				-- 銘柄ステータス管理テーブル更新（銘柄機構エラーコード、機構ステータス）
				result := SFADI002R15211_updateMgrSts(gErrCd,
																							USER_ID,
																							SP_ID,
																							gItakuKaishaCd,
																							gMgrCd,
																							gChkKkStat,
																							gChkKkPhase,pkKkNotice.MGR_KKERR_UNMATCH(), 1);
			IF result = pkconstant.success() THEN
				-- 新コード対応"項目不一致あり"
				result := pkconstant.NOMATCH_ERROR();
			END IF;
		-- 全項目一致した場合
		ELSE
			IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' RECONCILE  OK');	END IF;
			-- 銘柄ステータス管理テーブル更新（銘柄機構エラーコード、機構ステータス）
			result := SFADI002R15211_updateMgrSts(gErrCd,
																						USER_ID,
																						SP_ID,
																						gItakuKaishaCd,
																						gMgrCd,
																						gChkKkStat,
																						gChkKkPhase,' ', 1);
		END IF;
		-- 新規訂正取消区分が新規の時
		IF gShinkiKbn = ' ' THEN
			gResultCd := SFADI002R15212(
										gItakuKaishaCd,
										gIsinCd,gMgrCd,
										gOutMgrCd,gOutMgrRnm,
										gOutIsinCd,
										gOutWhether);
			IF gResultCd = pkconstant.FATAL() THEN
				RETURN pkconstant.FATAL();
			END IF;
			IF gOutWhether = '1' THEN
				IF gResultCd = pkconstant.success() THEN
					gTsuchiNm := pkIpaMsgKanri.getMessage('MSG010',gOutMgrCd,gIsinCd,gOutIsinCd);
					result := SFIPMSGTSUCHIUPDATE(
													gItakuKaishaCd,
													'機構連携','情報',
													'0',
													'0',
													gTsuchiNm,
													pkconstant.BATCH_USER(),
													pkconstant.BATCH_USER());
					IF result = pkconstant.FATAL() THEN
						RETURN pkconstant.FATAL();
					END IF;
					gMsg := 'ISIN重複のため自動変更しました。　　　　変更前ISINコード：　' || gIsinCd;
					CALL pkKakuninList.insertKakuninData(
													gItakuKaishaCd,
													'BATCH',
													'1',
													gGyomuYmd,
													gMsg,
													gOutIsinCd,
													gOutMgrCd,
													gOutMgrRnm,
													NULL,
													NULL,
													gJipDenbunCd,
													gItakuKaishaRnm);
				END IF;
				IF gResultCd != pkconstant.success() THEN
					gTsuchiNm := pkIpaMsgKanri.getMessage('MSG011',gOutMgrCd,gIsinCd);
					result := SFIPMSGTSUCHIUPDATE(
													gItakuKaishaCd,
													'機構連携',
													'情報',
													'0',
													'0',
													gTsuchiNm,
													pkconstant.BATCH_USER(),
													pkconstant.BATCH_USER());
					IF result = pkconstant.FATAL() THEN
						RETURN pkconstant.FATAL();
					END IF;
					gMsg := 'ISIN重複による自動変更に失敗しました。銘柄マスタ保守画面にてISINコードを変更してください。';
					CALL pkKakuninList.insertKakuninData(
													 gItakuKaishaCd,
													 'BATCH',
													 '1',
													 gGyomuYmd,
													 gMsg,
													 gIsinCd,
													 gOutMgrCd,
													 gOutMgrRnm,
													 NULL,
													 NULL,
													 gJipDenbunCd,
													 gItakuKaishaRnm);
				END IF;
				-- 機構連携テーブル受信電文の送受信エラー事由コード、電文明細ステータスを更新する。
				UPDATE KK_RENKEI
				SET
					KK_RENKEI.SOUJU_ERR_CD = '20',
					DENBUN_STAT = '23',
					KOUSIN_ID = 'BATCH'
				WHERE 
					KK_RENKEI.KK_SAKUSEI_DT = l_inKkSakuseiDt
				AND KK_RENKEI.DENBUN_MEISAI_NO = l_inDenbunMeisaiNo;
				-- リターンコードを設定
				result :='20';
			END IF;
		END IF;
		--突合処理が終了したら機構連携テーブル送信電文の業務状態コードに10:突合済みをセットする
		-- リターン値は通常利用しない（突合処理とは直接関係ないため）
		gRtnDmy := SFADI002R15211_updateKkRenkeiSnd(USER_ID,
																								SP_ID,
																								gKkSakuseiDt,
																								gDenbunMeisai,'10');
	ELSE
		--DBMS_OUTPUT.PUT_LINE('対象外');
		--突合対象外のときは機構連携テーブル受信電文の業務状態コードに99:論理削除をセットする
		-- リターン値は通常利用しない（突合処理とは直接関係ないため）
		gRtnDmy := SFADI002R15211_updateKkRenkeiRcv(USER_ID,
																								SP_ID,
																								l_inKkSakuseiDt,
																								l_inDenbunMeisaiNo,
																								l_inJipDenbunCd,'99');
		-- すでに突合済みなので、そのまま正常終了する。
		result := pkconstant.success();
	END IF;
	-- カーソル　クローズ 
	CALL DBMS_SQL.CLOSE_CURSOR(curComp);
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' END');	END IF;
	IF gRtn <> pkconstant.success() THEN
		RESULT := gRtn;
	END IF;
	RETURN(result);
--====================================================================*
--    異常終了 出口
-- *====================================================================
EXCEPTION
	-- データなし 
	WHEN no_data_found THEN
		CALL pkLog.error('ECM3A3', SP_ID, '機構連携 または VJIKO_ITAKU');
		RETURN result;
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
-- REVOKE ALL ON FUNCTION sfadi002r15211 ( l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE, l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE, l_inJipDenbunCd KK_RENKEI.JIP_DENBUN_CD%TYPE ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfadi002r15211_chkjoken (
	gShinkiKbn KK_RENKEI.ITEM001%TYPE,
	gTokureiFlg KK_RENKEI.ITEM001%TYPE,
	gMgrTaikeiKbn MGR_STS.MGR_TAIKEI_KBN%TYPE,
	gPartmgrKbn MGR_KIHON.PARTMGR_KBN%TYPE,
	v_CFlg IN OUT numeric(1)[]
) AS $body$
BEGIN
	-- 条件チェック 　（突合対象か対象外かを判断するための条件）　
	-- 条件１　新規データ、かつ（新発債、90B体系、または子銘柄）
	IF (gShinkiKbn = ' ' AND (gTokureiFlg = 'N' OR gMgrTaikeiKbn = '1' OR gPartmgrKbn = '2')) THEN
		-- 条件フラグをON
		v_CFlg[1] := 1;
	END IF;
	--   条件２　新規データ、かつ通常体系か
	IF gShinkiKbn = ' ' AND gMgrTaikeiKbn = '0' THEN
		v_CFlg[2] := 1;
	END IF;
	--   条件３　特例社債フラグ NOT= 'Y'か
	IF gTokureiFlg != 'Y' THEN
		v_CFlg[3] := 1;
	END IF;
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfadi002r15211_chkjoken () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadi002r15211_comparedata (
	gOutItemCnt numeric(3),
	curComp integer,
	tMoto varchar(400)[],
	tSaki varchar(400)[],
	gOutItemAtt PkCompare.t_ItemAtt_type,
	gItakuKaishaCd MGR_KIHON.ITAKU_KAISHA_CD%TYPE,
	USER_ID varchar(10),
	gGyomuYmd SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE,
	gIsinCd KK_RENKEI.ITEM001%TYPE,
	gMgrCd KK_RENKEI.ITEM001%TYPE,
	gMgrRnm MGR_KIHON.MGR_RNM%TYPE,
	gJipDenbunCd KK_RENKEI.JIP_DENBUN_CD%TYPE,
	gItakuKaishaRnm MITAKU_KAISHA.ITAKU_KAISHA_RNM%TYPE,
	gMsg IN OUT varchar(100),
	OUT flg integer
) RETURNS record AS $body$
BEGIN
    	flg := 0;
    	-- 突合項目
    	-- 　比較元、比較先、条件番号の組を１組ずつ取り出し、突合
    	-- 　突合項目数繰り返す
    	FOR i IN 1 .. gOutItemCnt LOOP
         	CALL DBMS_SQL.COLUMN_VALUE(curComp,i * 2 -1, tMoto[i]);
					CALL DBMS_SQL.COLUMN_VALUE(curComp,i * 2 , tSaki[i]);
					-- 条件を満たしていれば、突合対象外とする
					IF gOutItemAtt[i].condNo = 0 OR v_CFlg(gOutItemAtt[i].condNo) = 0 THEN
					-- 突合処理
			IF coalesce(trim(both tMoto[i]), ' ') != coalesce(trim(both tSaki[i]), ' ') THEN 		-- 不一致のとき
				IF DEBUG = 1 THEN
    					CALL pkLog.debug(USER_ID, REPORT_ID, 'NG');
							CALL pkLog.debug(USER_ID, REPORT_ID, 'dispNm' || i || ' = ' || gOutItemAtt[i].dispNm);
							CALL pkLog.debug(USER_ID, REPORT_ID, '受信_' || i || ' = ' || tMoto[i]);
							CALL pkLog.debug(USER_ID, REPORT_ID, '送信_' || i || ' = ' || tSaki[i]);
--                    	pkLog.debug(USER_ID, REPORT_ID, 'condNo' || i || ' = ' || gOutItemAtt[i].condNo);
				END IF;
        			flg := 1;
        			-- 確認リストのエラー内容
        			gMsg := gOutItemAtt[i].dispNm;		-- 表示項目名
        			IF (gMsg IS NOT NULL AND gMsg::text <> '') THEN
        				gMsg := gMsg || 'が';
        			END IF;
        			gMsg := gMsg || '突合エラーです。';
                    -- 確認リスト出力内容を帳票ワークテーブルに登録
                    CALL pkKakuninList.insertKakuninData(
                        	gItakuKaishaCd,
                        	USER_ID,
                        	pkKakuninList.CHOHYO_KBN_BATCH(),
                        	gGyomuYmd,
                        	gMsg,
                        	gIsinCd,
                        	gMgrCd,
                        	gMgrRnm,
													tSaki[i],
													tMoto[i],
                        	gJipDenbunCd,
                        	gItakuKaishaRnm
            		);
--        		ELSE
--					DBMS_OUTPUT.PUT_LINE('OK');
        		END IF;
    		END IF;
    	END LOOP;
	RETURN;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi002r15211_comparedata () FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfadi002r15211_definecolumn (
	gOutItemCnt numeric(3),
	gCompAllCnt integer,
	curComp integer,
	POS_MGR_CD integer,
	POS_SHINKI_KBN integer,
	POS_ERR_CD integer,
	POS_ISIN_CD integer,
	POS_HAKKO_RNM integer,
	POS_KAIGO integer,
	POS_BOSHU_KBN integer,
	POS_TOKUREI_FLG integer,
	POS_DENBUN_MEISAI integer,
	POS_MGR_TAIKEI_KBN integer,
	POS_MGR_RNM integer,
	POS_KK_STAT integer,
	POS_ITAKU_CD_V integer,
	POS_PARTMGR_KBN integer,
	POS_KK_SAKUSEI_DT integer,
	POS_GYOMU_STAT_CD integer,
	gMgrCd IN OUT KK_RENKEI.ITEM001%TYPE,
	gShinkiKbn IN OUT KK_RENKEI.ITEM001%TYPE,
	gErrCd IN OUT KK_RENKEI.ITEM001%TYPE,
	gIsinCd IN OUT KK_RENKEI.ITEM001%TYPE,
	gHakkoRnm IN OUT KK_RENKEI.ITEM001%TYPE,
	gKaigo IN OUT KK_RENKEI.ITEM001%TYPE,
	gBoshuKbn IN OUT KK_RENKEI.ITEM001%TYPE,
	gTokureiFlg IN OUT KK_RENKEI.ITEM001%TYPE,
	gDenbunMeisai IN OUT KK_RENKEI.ITEM001%TYPE,
	gMgrTaikeiKbn IN OUT MGR_STS.MGR_TAIKEI_KBN%TYPE,
	gMgrRnm IN OUT MGR_KIHON.MGR_RNM%TYPE,
	gKkStat IN OUT MGR_STS.KK_STAT%TYPE,
	gItakuKaishaCd_V IN OUT MGR_KIHON.ITAKU_KAISHA_CD%TYPE,
	gPartmgrKbn IN OUT MGR_KIHON.PARTMGR_KBN%TYPE,
	gKkSakuseiDt IN OUT KK_RENKEI.KK_SAKUSEI_DT%TYPE,
	gGyomuStatCd IN OUT KK_RENKEI.GYOMU_STAT_CD%TYPE,
	tMoto IN OUT varchar(400)[],
	tSaki IN OUT varchar(400)[]
) AS $body$
BEGIN
    	-- 配列初期化
    	FOR i IN 1 .. gOutItemCnt LOOP
    		tMoto[i] := '';
    		tSaki[i] := '';
    	END LOOP;
    	-- 突合項目以外
        CALL DBMS_SQL.DEFINE_COLUMN(curComp, gCompAllCnt + POS_MGR_CD, gMgrCd, 400);					-- 機構連携−受信.社内処理用項目２(銘柄コード)
        CALL DBMS_SQL.DEFINE_COLUMN(curComp, gCompAllCnt + POS_SHINKI_KBN, gShinkiKbn, 400);			-- 機構連携−受信.新規訂正取消区分
        CALL DBMS_SQL.DEFINE_COLUMN(curComp, gCompAllCnt + POS_ERR_CD, gErrCd, 400);					-- 機構連携−受信.エラーコード／エラー理由コード
        CALL DBMS_SQL.DEFINE_COLUMN(curComp, gCompAllCnt + POS_ISIN_CD, gIsinCd, 400);				-- 機構連携−受信.ＩＳＩＮコード
        CALL DBMS_SQL.DEFINE_COLUMN(curComp, gCompAllCnt + POS_HAKKO_RNM, gHakkoRnm, 400);			-- 機構連携−受信.銘柄略称　発行者略称
        CALL DBMS_SQL.DEFINE_COLUMN(curComp, gCompAllCnt + POS_KAIGO, gKaigo, 400);					-- 機構連携−受信.銘柄略称　回号等
        CALL DBMS_SQL.DEFINE_COLUMN(curComp, gCompAllCnt + POS_BOSHU_KBN, gBoshuKbn, 400);			-- 機構連携−受信.銘柄略称　募集区分
        CALL DBMS_SQL.DEFINE_COLUMN(curComp, gCompAllCnt + POS_TOKUREI_FLG, gTokureiFlg, 400);		-- 機構連携−受信.特例社債フラグ
        CALL DBMS_SQL.DEFINE_COLUMN(curComp, gCompAllCnt + POS_DENBUN_MEISAI, gDenbunMeisai, 400);	-- 機構連携−送信.電文明細Ｎｏ
        CALL DBMS_SQL.DEFINE_COLUMN(curComp, gCompAllCnt + POS_MGR_TAIKEI_KBN, gMgrTaikeiKbn, 400);	-- 銘柄ステータス管理.銘柄体系区分
        CALL DBMS_SQL.DEFINE_COLUMN(curComp, gCompAllCnt + POS_MGR_RNM, gMgrRnm, 400);				-- 銘柄_基本(VIEW).銘柄略称
        CALL DBMS_SQL.DEFINE_COLUMN(curComp, gCompAllCnt + POS_KK_STAT, gKkStat, 400);				-- 銘柄ステータス管理(VIEW).機構ステータス
        CALL DBMS_SQL.DEFINE_COLUMN(curComp, gCompAllCnt + POS_ITAKU_CD_V, gItakuKaishaCd_V, 400);	-- 銘柄_基本(VIEW).委託会社コード
				CALL DBMS_SQL.DEFINE_COLUMN(curComp, gCompAllCnt + POS_PARTMGR_KBN, gPartmgrKbn, 400);       -- 銘柄_基本(VIEW).分割銘柄区分
				CALL DBMS_SQL.DEFINE_COLUMN(curComp, gCompAllCnt + POS_KK_SAKUSEI_DT, gKkSakuseiDt, 400);    -- 機構連携-送信.機構送信日時
				CALL DBMS_SQL.DEFINE_COLUMN(curComp, gCompAllCnt + POS_GYOMU_STAT_CD, gGyomuStatCd, 400);    -- 機構連携-送信.業務状態コード
    	-- 突合項目
    	FOR i IN 1 .. gOutItemCnt LOOP
    	    CALL DBMS_SQL.DEFINE_COLUMN(curComp,i * 2 -1, tMoto[i], 400);
    	    CALL DBMS_SQL.DEFINE_COLUMN(curComp,i * 2 , tSaki[i], 400);
    	END LOOP;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfadi002r15211_definecolumn () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadi002r15211_delinsmgrkikokihon (
	gItakuKaishaCd MGR_KIHON.ITAKU_KAISHA_CD%TYPE,
	gMgrCd KK_RENKEI.ITEM001%TYPE,
	USER_ID varchar(10),
	OUT recKK record,
	OUT rtn integer
) AS $body$
DECLARE
	l_optionFlg		MOPTION_KANRI.OPTION_FLG%TYPE;	-- オプションフラグ
	l_sakuseiDt		MGR_KIKO_KIHON.SAKUSEI_DT%TYPE;	-- 作成日時
	outRtn			integer;
	outSqlErrM		varchar(1000);		-- SQLエラーメッセージ
BEGIN
	rtn := pkconstant.FATAL();
	l_optionFlg := pkControl.getOPTION_FLG(gItakuKaishaCd, 'REDPROJECT', '0');
	l_sakuseiDt := NULL;
	-- [REDPROJECT]作成日を引き継ぐ
	IF l_optionFlg = '1' THEN
		BEGIN
			-- 更新前レコードの作成日を取得
			SELECT SAKUSEI_DT
			INTO STRICT l_sakuseiDt
			FROM MGR_KIKO_KIHON
			WHERE ITAKU_KAISHA_CD = gItakuKaishaCd
			  AND MGR_CD = gMgrCd
			;
		EXCEPTION
			-- 新規登録のケース
			WHEN no_data_found THEN
				l_sakuseiDt := NULL;
		END;
	END IF;
	-- 履歴テーブル登録
	CALL pkRireki.rirekiInsert(
				l_inTableNm => 'MGR_KIKO_KIHON',
				l_inUserId => USER_ID,
				l_inKey1 => gItakuKaishaCd,
				l_inKey2 => gMgrCd,
				l_outSqlCode => outRtn,
				l_outSqlErrM => outSqlErrM
	);
	IF outRtn <> 0 AND outRtn <> 1 THEN
		RETURN;
	END IF;
	-- 銘柄_機構基本テーブル削除
	DELETE FROM	MGR_KIKO_KIHON
	WHERE	ITAKU_KAISHA_CD = gItakuKaishaCd
	  AND	MGR_CD = gMgrCd;
	-- 銘柄_機構基本テーブル登録
	CALL sfadi002r15211_insertmgrkikokihon(l_sakuseiDt,gItakuKaishaCd,
																				gMgrCd,
																				USER_ID,
																				recKK);
	rtn := pkconstant.success();
	RETURN;
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi002r15211_delinsmgrkikokihon () FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfadi002r15211_getcolumnvalue (
	gCompAllCnt integer,
	curComp integer,
	POS_MGR_CD integer,
	POS_SHINKI_KBN integer,
	POS_ERR_CD integer,
	POS_ISIN_CD integer,
	POS_HAKKO_RNM integer,
	POS_KAIGO integer,
	POS_BOSHU_KBN integer,
	POS_TOKUREI_FLG integer,
	POS_DENBUN_MEISAI integer,
	POS_MGR_TAIKEI_KBN integer,
	POS_MGR_RNM integer,
	POS_KK_STAT integer,
	POS_ITAKU_CD_V integer,
	POS_PARTMGR_KBN integer,
	POS_KK_SAKUSEI_DT integer,
	POS_GYOMU_STAT_CD integer,
	gMgrCd IN OUT KK_RENKEI.ITEM001%TYPE,
	gShinkiKbn IN OUT KK_RENKEI.ITEM001%TYPE,
	gErrCd IN OUT KK_RENKEI.ITEM001%TYPE,
	gIsinCd IN OUT KK_RENKEI.ITEM001%TYPE,
	gHakkoRnm IN OUT KK_RENKEI.ITEM001%TYPE,
	gKaigo IN OUT KK_RENKEI.ITEM001%TYPE,
	gBoshuKbn IN OUT KK_RENKEI.ITEM001%TYPE,
	gTokureiFlg IN OUT KK_RENKEI.ITEM001%TYPE,
	gDenbunMeisai IN OUT KK_RENKEI.ITEM001%TYPE,
	gMgrTaikeiKbn IN OUT MGR_STS.MGR_TAIKEI_KBN%TYPE,
	gMgrRnm IN OUT MGR_KIHON.MGR_RNM%TYPE,
	gKkStat IN OUT MGR_STS.KK_STAT%TYPE,
	gItakuKaishaCd_V IN OUT MGR_KIHON.ITAKU_KAISHA_CD%TYPE,
	gPartmgrKbn IN OUT MGR_KIHON.PARTMGR_KBN%TYPE,
	gKkSakuseiDt IN OUT KK_RENKEI.KK_SAKUSEI_DT%TYPE,
	gGyomuStatCd IN OUT KK_RENKEI.GYOMU_STAT_CD%TYPE
) AS $body$
BEGIN
	CALL DBMS_SQL.COLUMN_VALUE(curComp, gCompAllCnt + POS_MGR_CD, gMgrCd);				-- 機構連携−受信.社内処理用項目２(銘柄コード)
	CALL DBMS_SQL.COLUMN_VALUE(curComp, gCompAllCnt + POS_SHINKI_KBN, gShinkiKbn);		-- 機構連携−受信.新規訂正取消区分
	CALL DBMS_SQL.COLUMN_VALUE(curComp, gCompAllCnt + POS_ERR_CD, gErrCd);				-- 機構連携−受信.エラーコード／エラー理由コード
	CALL DBMS_SQL.COLUMN_VALUE(curComp, gCompAllCnt + POS_ISIN_CD, gIsinCd);				-- 機構連携−受信.ＩＳＩＮコード
	CALL DBMS_SQL.COLUMN_VALUE(curComp, gCompAllCnt + POS_HAKKO_RNM, gHakkoRnm);			-- 機構連携−受信.銘柄略称　発行者略称
	CALL DBMS_SQL.COLUMN_VALUE(curComp, gCompAllCnt + POS_KAIGO, gKaigo);				-- 機構連携−受信.銘柄略称　回号等
	CALL DBMS_SQL.COLUMN_VALUE(curComp, gCompAllCnt + POS_BOSHU_KBN, gBoshuKbn);			-- 機構連携−受信.銘柄略称　募集区分
	CALL DBMS_SQL.COLUMN_VALUE(curComp, gCompAllCnt + POS_TOKUREI_FLG, gTokureiFlg);		-- 機構連携−受信.特例社債フラグ
	CALL DBMS_SQL.COLUMN_VALUE(curComp, gCompAllCnt + POS_DENBUN_MEISAI, gDenbunMeisai);	-- 機構連携−送信.電文明細Ｎｏ
	CALL DBMS_SQL.COLUMN_VALUE(curComp, gCompAllCnt + POS_MGR_TAIKEI_KBN, gMgrTaikeiKbn);-- 銘柄ステータス管理.銘柄体系区分
	CALL DBMS_SQL.COLUMN_VALUE(curComp, gCompAllCnt + POS_MGR_RNM, gMgrRnm);				-- 銘柄_基本.銘柄略称
	CALL DBMS_SQL.COLUMN_VALUE(curComp, gCompAllCnt + POS_KK_STAT, gKkStat);				-- 銘柄ステータス管理.機構ステータス
	CALL DBMS_SQL.COLUMN_VALUE(curComp, gCompAllCnt + POS_ITAKU_CD_V, gItakuKaishaCd_V);	-- 銘柄_基本(VIEW).委託会社コード
	CALL DBMS_SQL.COLUMN_VALUE(curComp, gCompAllCnt + POS_PARTMGR_KBN, gPartmgrKbn);     -- 銘柄_基本(VIEW).分割銘柄区分
	CALL DBMS_SQL.COLUMN_VALUE(curComp, gCompAllCnt + POS_KK_SAKUSEI_DT, gKkSakuseiDt);  -- 機構連携-送信.機構送信日時
	CALL DBMS_SQL.COLUMN_VALUE(curComp, gCompAllCnt + POS_GYOMU_STAT_CD, gGyomuStatCd);  -- 機構連携-送信.業務状態コード
	gShinkiKbn := coalesce(gShinkiKbn, ' ');
	gTokureiFlg := coalesce(gTokureiFlg, ' ');
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfadi002r15211_getcolumnvalue () FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfadi002r15211_insertmgrkikokihon (
	l_inSakuseiDt MGR_KIKO_KIHON.SAKUSEI_DT%TYPE,
	gItakuKaishaCd MGR_KIHON.ITAKU_KAISHA_CD%TYPE,
	gMgrCd KK_RENKEI.ITEM001%TYPE,
	USER_ID varchar(10),
	OUT recKK RECORD
) AS $body$
BEGIN
	-- 機構連携テーブルを検索   
	SELECT  *
	INTO STRICT	recKK
    	FROM	KK_RENKEI
    	WHERE	KK_SAKUSEI_DT = l_inKkSakuseiDt
    	  AND	DENBUN_MEISAI_NO = l_inDenbunMeisaiNo;
	-- 銘柄_機構基本テーブル Insert 
	INSERT INTO MGR_KIKO_KIHON(
		ITAKU_KAISHA_CD,                                                -- 委託会社コード
		MGR_CD,                                                         -- 銘柄コード
		HAKKODAIRI_CD,                                                  -- 発行代理人コード
		KK_HAKKO_CD,                                                    -- 機構発行体コード
		ISIN_CD,                                                        -- ＩＳＩＮコード
		MGR_NM,                                                         -- 銘柄の正式名称
		KK_HAKKOSHA_RNM,                                                -- 機構発行者略称
		KAIGO_ETC,                                                      -- 回号等
		BOSHU_KBN,                                                      -- 募集区分
		HOSHO_KBN,                                                      -- 保証区分
		TANPO_KBN,                                                      -- 担保区分
		GODOHAKKO_FLG,                                                  -- 合同発行フラグ
		RETSUTOKU_UMU_FLG,                                              -- 劣後特約有無フラグ
		SKNNZISNTOKU_UMU_FLG,                                           -- 責任財産限定特約有無フラグ
		SAIKEN_SHURUI,                                                  -- 債券種類
		BOSHU_ST_YMD,                                                   -- 募集開始日
		HAKKO_YMD,                                                      -- 発行年月日
		KAKUSHASAI_KNGK,                                                -- 各社債の金額
		UCHIKIRI_HAKKO_FLG,                                             -- 打切発行フラグ
		SHASAI_TOTAL,                                                   -- 社債の総額
		SHUTOKU_SUM,                                                    -- 適格機関投資家取得総額（少人数私募カウント除外分）
		HAKKO_TSUKA_CD,                                                 -- 発行通貨
		SHRDAIRI_CD,                                                    -- 支払代理人コード
		SKN_KESSAI_CD,                                                  -- 資金決済会社コード
		KK_KANYO_FLG,                                                   -- 機構関与方式採用フラグ
		KOBETSU_SHONIN_SAIYO_FLG,                                       -- 個別承認採用フラグ
		SHASAI_KANRI_CD1,                                               -- 社債管理会社（１）
		SHASAI_KANRI_CD2,                                               -- 社債管理会社（２）
		SHASAI_KANRI_CD3,                                               -- 社債管理会社（３）
		SHASAI_KANRI_CD4,                                               -- 社債管理会社（４）
		SHASAI_KANRI_CD5,                                               -- 社債管理会社（５）
		SHASAI_KANRI_CD6,                                               -- 社債管理会社（６）
		SHASAI_KANRI_CD7,                                               -- 社債管理会社（７）
		SHASAI_KANRI_CD8,                                               -- 社債管理会社（８）
		SHASAI_KANRI_CD9,                                               -- 社債管理会社（９）
		SHASAI_KANRI_CD10,                                              -- 社債管理会社（１０）
		JUTAKU_KAISHA1,                                                 -- 受託会社（１）
		JUTAKU_KAISHA2,                                                 -- 受託会社（２）
		JUTAKU_KAISHA3,                                                 -- 受託会社（３）
		JUTAKU_KAISHA4,                                                 -- 受託会社（４）
		JUTAKU_KAISHA5,                                                 -- 受託会社（５）
		TRUST_SHOSHO_WAREKI,                                            -- 信託証書日付(和暦)
		PARTHAKKO_UMU_FLG,                                              -- 分割発行有無フラグ
		KYUJITSU_KBN,                                                   -- 休日処理区分
		KYUJITSU_LD_FLG,                                                -- 休日処理ロンドン参照フラグ
		KYUJITSU_NY_FLG,                                                -- 休日処理ニューヨーク参照フラグ
		KYUJITSU_ETC_FLG,                                               -- 休日処理その他海外参照フラグ
		RITSUKE_WARIBIKI_KBN,                                           -- 利付割引区分
		RBR_TSUKA_CD,                                                   -- 利払通貨
		RBR_KJT_MD1,                                                    -- 利払期日（MD）（１）
		RBR_KJT_MD2,                                                    -- 利払期日（MD）（２）
		RBR_KJT_MD3,                                                    -- 利払期日（MD）（３）
		RBR_KJT_MD4,                                                    -- 利払期日（MD）（４）
		RBR_KJT_MD5,                                                    -- 利払期日（MD）（５）
		RBR_KJT_MD6,                                                    -- 利払期日（MD）（６）
		RBR_KJT_MD7,                                                    -- 利払期日（MD）（７）
		RBR_KJT_MD8,                                                    -- 利払期日（MD）（８）
		RBR_KJT_MD9,                                                    -- 利払期日（MD）（９）
		RBR_KJT_MD10,                                                   -- 利払期日（MD）（１０）
		RBR_KJT_MD11,                                                   -- 利払期日（MD）（１１）
		RBR_KJT_MD12,                                                   -- 利払期日（MD）（１２）
		ST_RBR_KJT,                                                     -- 初回利払期日
		LAST_RBR_FLG,                                                   -- 最終利払有無フラグ
		RIRITSU,                                                        -- 利率
		TSUKARISHI_KNGK_FAST,                                           -- １通貨あたりの利子金額（初期）
		TSUKARISHI_KNGK_NORM,                                           -- １通貨あたりの利子金額（通常）
		TSUKARISHI_KNGK_LAST,                                           -- １通貨あたりの利子金額（終期）
		SHOKAN_TSUKA_CD,                                                -- 償還通貨
		KAWASE_RATE,                                                    -- 為替レート
		FULLSHOKAN_KJT,                                                 -- 満期償還期日
		CALLALL_UMU_FLG,                                                -- コールオプション有無フラグ（全額償還）
		TEIJI_SHOKAN_UMU_FLG,                                           -- 定時償還有無フラグ
		ST_TEIJISHOKAN_KJT,                                             -- 初回定時償還期日
		TEIJI_SHOKAN_TSUTI_KBN,                                         -- 定時償還通知区分
		TEIJI_SHOKAN_KNGK,                                              -- 定時償還金額
		CALLITIBU_UMU_FLG,                                              -- コールオプション有無フラグ（一部償還）
		PUTUMU_FLG,                                                     -- プットオプション有無フラグ
		SHANAI_KOMOKU1,                                                 -- 社内処理用項目１
		SHANAI_KOMOKU2,                                                 -- 社内処理用項目２
		TOKUREI_SHASAI_FLG,                                             -- 特例社債フラグ
		IKKATSUIKO_FLG,                                                 -- 一括移行方式フラグ
		TKTI_KOZA_CD,                                                   -- 特定口座管理機関コード
		GENISIN_CD,                                                     -- 原ＩＳＩＮコード
		PARTMGR_KBN,                                                    -- 分割銘柄区分
		TOKUTEI_KOUSHASAI_FLG,											-- 特定公社債フラグ
		LAST_TEISEI_DT,                                                 -- 最終訂正日時
		LAST_TEISEI_ID,                                                 -- 最終訂正者
		KOUSIN_ID,                                                      -- 更新者
		SAKUSEI_DT,                                                     -- 作成日時
		SAKUSEI_ID)                                                     -- 作成者
	VALUES (
		gItakuKaishaCd,                                                 -- 委託会社コード
		gMgrCd,                                                 		-- 銘柄コード
		coalesce(recKK.ITEM010, ' '),                                        -- 発行代理人コード
		coalesce(recKK.ITEM012, ' '),                                        -- 機構発行体コード
		coalesce(recKK.ITEM014, ' '),                                        -- ＩＳＩＮコード
		coalesce(ltrim(rtrim(recKK.ITEM016,'　'),'　'), ' '),                -- 銘柄の正式名称
		coalesce(ltrim(rtrim(recKK.ITEM018,'　'),'　'), ' '),                -- 機構発行者略称
		coalesce(ltrim(rtrim(recKK.ITEM019,'　'),'　'), ' '),                -- 回号等
		coalesce(recKK.ITEM020, ' '),                                        -- 募集区分
		coalesce(recKK.ITEM022, ' '),                                        -- 保証区分
		coalesce(recKK.ITEM024, ' '),                                        -- 担保区分
		coalesce(recKK.ITEM026, ' '),                                        -- 合同発行フラグ
		coalesce(recKK.ITEM028, ' '),                                        -- 劣後特約有無フラグ
		coalesce(recKK.ITEM030, ' '),                                        -- 責任財産限定特約有無フラグ
		coalesce(recKK.ITEM032, ' '),                                        -- 債券種類
		coalesce(recKK.ITEM034, ' '),                                        -- 募集開始日
		coalesce(recKK.ITEM036, ' '),                                        -- 発行年月日
		(CASE WHEN (trim(both recKK.ITEM038) IS NOT NULL AND (trim(both recKK.ITEM038))::text <> '') THEN (trim(both recKK.ITEM038))::numeric  ELSE 0 END),   -- 各社債の金額
		coalesce(recKK.ITEM040, ' '),                                        -- 打切発行フラグ
		(CASE WHEN (trim(both recKK.ITEM042) IS NOT NULL AND (trim(both recKK.ITEM042))::text <> '') THEN (trim(both recKK.ITEM042))::numeric  ELSE 0 END),   -- 社債の総額
		coalesce(recKK.ITEM044, ' '),                                        -- 適格機関投資家取得総額（少人数私募カウント除外分）
		coalesce(recKK.ITEM046, ' '),                                        -- 発行通貨
		coalesce(recKK.ITEM048, ' '),                                        -- 支払代理人コード
		coalesce(recKK.ITEM050, ' '),                                        -- 資金決済会社コード
		coalesce(recKK.ITEM052, ' '),                                        -- 機構関与方式採用フラグ
		coalesce(recKK.ITEM054, ' '),                                        -- 個別承認採用フラグ
		coalesce(recKK.ITEM056, ' '),                                        -- 社債管理会社（１）
		coalesce(recKK.ITEM057, ' '),                                        -- 社債管理会社（２）
		coalesce(recKK.ITEM058, ' '),                                        -- 社債管理会社（３）
		coalesce(recKK.ITEM059, ' '),                                        -- 社債管理会社（４）
		coalesce(recKK.ITEM060, ' '),                                        -- 社債管理会社（５）
		coalesce(recKK.ITEM061, ' '),                                        -- 社債管理会社（６）
		coalesce(recKK.ITEM062, ' '),                                        -- 社債管理会社（７）
		coalesce(recKK.ITEM063, ' '),                                        -- 社債管理会社（８）
		coalesce(recKK.ITEM064, ' '),                                        -- 社債管理会社（９）
		coalesce(recKK.ITEM065, ' '),                                        -- 社債管理会社（１０）
		coalesce(recKK.ITEM067, ' '),                                        -- 受託会社（１）
		coalesce(recKK.ITEM068, ' '),                                        -- 受託会社（２）
		coalesce(recKK.ITEM069, ' '),                                        -- 受託会社（３）
		coalesce(recKK.ITEM070, ' '),                                        -- 受託会社（４）
		coalesce(recKK.ITEM071, ' '),                                        -- 受託会社（５）
		coalesce(recKK.ITEM072, ' '),                                        -- 信託証書日付(和暦)
		coalesce(recKK.ITEM073, ' '),                                        -- 分割発行有無フラグ
		coalesce(recKK.ITEM075, ' '),                                        -- 休日処理区分
		coalesce(recKK.ITEM076, ' '),                                        -- 休日処理ロンドン参照フラグ
		coalesce(recKK.ITEM077, ' '),                                        -- 休日処理ニューヨーク参照フラグ
		coalesce(recKK.ITEM078, ' '),                                        -- 休日処理その他海外参照フラグ
		coalesce(recKK.ITEM080, ' '),                                        -- 利付割引区分
		coalesce(recKK.ITEM082, ' '),                                        -- 利払通貨
		coalesce(recKK.ITEM084, ' '),                                        -- 利払期日（MD）（１）
		coalesce(recKK.ITEM085, ' '),                                        -- 利払期日（MD）（２）
		coalesce(recKK.ITEM086, ' '),                                        -- 利払期日（MD）（３）
		coalesce(recKK.ITEM087, ' '),                                        -- 利払期日（MD）（４）
		coalesce(recKK.ITEM088, ' '),                                        -- 利払期日（MD）（５）
		coalesce(recKK.ITEM089, ' '),                                        -- 利払期日（MD）（６）
		coalesce(recKK.ITEM090, ' '),                                        -- 利払期日（MD）（７）
		coalesce(recKK.ITEM091, ' '),                                        -- 利払期日（MD）（８）
		coalesce(recKK.ITEM092, ' '),                                        -- 利払期日（MD）（９）
		coalesce(recKK.ITEM093, ' '),                                        -- 利払期日（MD）（１０）
		coalesce(recKK.ITEM094, ' '),                                        -- 利払期日（MD）（１１）
		coalesce(recKK.ITEM095, ' '),                                        -- 利払期日（MD）（１２）
		coalesce(recKK.ITEM097, ' '),                                        -- 初回利払期日
		coalesce(recKK.ITEM099, ' '),                                        -- 最終利払有無フラグ
		(CASE WHEN (trim(both recKK.ITEM101) IS NOT NULL AND (trim(both recKK.ITEM101))::text <> '') THEN (trim(both recKK.ITEM101))::numeric  ELSE 0 END),   -- 利率
		(CASE WHEN (trim(both recKK.ITEM102) IS NOT NULL AND (trim(both recKK.ITEM102))::text <> '') THEN (trim(both recKK.ITEM102))::numeric  ELSE 0 END),   -- １通貨あたりの利子金額（初期）
		(CASE WHEN (trim(both recKK.ITEM103) IS NOT NULL AND (trim(both recKK.ITEM103))::text <> '') THEN (trim(both recKK.ITEM103))::numeric  ELSE 0 END),   -- １通貨あたりの利子金額（通常）
		(CASE WHEN (trim(both recKK.ITEM104) IS NOT NULL AND (trim(both recKK.ITEM104))::text <> '') THEN (trim(both recKK.ITEM104))::numeric  ELSE 0 END),   -- １通貨あたりの利子金額（終期）
		coalesce(recKK.ITEM106, ' '),                                        -- 償還通貨
		(CASE WHEN (trim(both recKK.ITEM108) IS NOT NULL AND (trim(both recKK.ITEM108))::text <> '') THEN (trim(both recKK.ITEM108))::numeric  ELSE 0 END),   -- 為替レート
		coalesce(recKK.ITEM110, ' '),                                        -- 満期償還期日
		coalesce(recKK.ITEM112, ' '),                                        -- コールオプション有無フラグ（全額償還）
		coalesce(recKK.ITEM118, ' '),                                        -- 定時償還有無フラグ
		coalesce(recKK.ITEM119, ' '),                                        -- 初回定時償還期日
		coalesce(recKK.ITEM120, ' '),                                        -- 定時償還通知区分
		(CASE WHEN (trim(both recKK.ITEM121) IS NOT NULL AND (trim(both recKK.ITEM121))::text <> '') THEN (trim(both recKK.ITEM121))::numeric  ELSE 0 END),   -- 定時償還金額
		coalesce(recKK.ITEM124, ' '),                                        -- コールオプション有無フラグ（一部償還）
		coalesce(recKK.ITEM132, ' '),                                        -- プットオプション有無フラグ
		coalesce(trim(both recKK.ITEM138), ' '),                                  -- 社内処理用項目１
		coalesce(gMgrCd, ' '),                                               -- 社内処理用項目２
		coalesce(recKK.ITEM141, ' '),                                        -- 特例社債フラグ
		coalesce(recKK.ITEM142, ' '),                                        -- 一括移行方式フラグ
		coalesce(recKK.ITEM143, ' '),                                        -- 特定口座管理機関コード
		coalesce(recKK.ITEM144, ' '),                                        -- 原ＩＳＩＮコード
		coalesce(recKK.ITEM145, ' '),                                        -- 分割銘柄区分
		coalesce(recKK.ITEM147, ' '),                                        -- 特定公社債フラグ
		to_timestamp(pkDate.getCurrentTime(), 'YYYY-MM-DD HH24:MI:SS.US'),  -- 最終訂正日時
		USER_ID,                                                        -- 最終訂正者
		USER_ID,                                                        -- 更新者
		coalesce(l_inSakuseiDt, to_timestamp(pkDate.getCurrentTime(), 'YYYY-MM-DD HH24:MI:SS.US')), -- 作成日時（指定しない場合、業務日付＋システム時刻）
		USER_ID);                                                       -- 作成者
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfadi002r15211_insertmgrkikokihon ( l_inSakuseiDt MGR_KIKO_KIHON.SAKUSEI_DT%TYPE ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadi002r15211_istotsugozumi (
	l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE,
	l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE,
	result IN OUT integer,
	OUT rtn boolean
) RETURNS record AS $body$
DECLARE
	gyomuStatCd KK_RENKEI.GYOMU_STAT_CD%TYPE;
	TOTSUGOZUMI CONSTANT varchar(2) := '10';
	SEND_JIP_DENBUN_CD CONSTANT varchar(5) := 'S1511';

BEGIN
	rtn := FALSE;
        BEGIN
            -- 業務状態コードを取得する。
            SELECT
                RT02S.GYOMU_STAT_CD
            INTO STRICT
                gyomuStatCd
            FROM kk_renkei rt02r
						LEFT OUTER JOIN kk_renkei rt02s ON (trim(both RT02R.ITEM139) = trim(both RT02S.ITEM139) AND SEND_JIP_DENBUN_CD = RT02S.JIP_DENBUN_CD AND pkIpaName.getBicNoShitenCd(RT02R.SR_BIC_CD) = pkIpaName.getBicNoShitenCd(RT02S.SR_BIC_CD))
						WHERE RT02R.KK_SAKUSEI_DT = l_inKkSakuseiDt AND RT02R.DENBUN_MEISAI_NO = l_inDenbunMeisaiNo    AND RT02S.ITEM005 = RT02R.ITEM005 AND RT02S.KK_SAKUSEI_DT =
                   (SELECT trim(both MAX(K01.KK_SAKUSEI_DT))
                     FROM   KK_RENKEI K01
                     WHERE  K01.JIP_DENBUN_CD = SEND_JIP_DENBUN_CD
                     AND    RT02S.ITEM005 = K01.ITEM005
                     AND    RT02S.ITEM139 = K01.ITEM139
                     AND    pkIpaName.getBicNoShitenCd(RT02S.SR_BIC_CD) =
                            pkIpaName.getBicNoShitenCd(K01.SR_BIC_CD) );
        EXCEPTION
            WHEN no_data_found THEN
                CALL pkLog.DEBUG(SP_ID,USER_ID,'機構連携の突合取得ＳＱＬでデータが取得できなかった。');
    		-- IP-03595
			result := pkconstant.NO_DATA_FIND_ISIN();
                RAISE;
        END;
    	--機構連携テーブル送信電文の業務状態コードが10:突合済みのときは突合対象外とする
    	IF gyomuStatCd = TOTSUGOZUMI THEN
            rtn := TRUE;
        ELSE
            rtn := FALSE;
        END IF;
	RETURN;
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi002r15211_istotsugozumi ( l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE, l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadi002r15211_multispacetrim (
	l_inBuf text
) RETURNS varchar AS $body$
BEGIN
         RETURN ltrim(rtrim(l_inBuf,'　'),'　');
    END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi002r15211_multispacetrim ( l_inBuf text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadi002r15211_updatehakkotai (
	gItakuKaishaCd MGR_KIHON.ITAKU_KAISHA_CD%TYPE,
	gMgrCd KK_RENKEI.ITEM001%TYPE,
	gGyomuYmd SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE,
	gIsinCd KK_RENKEI.ITEM001%TYPE,
	gMgrRnm MGR_KIHON.MGR_RNM%TYPE,
	gJipDenbunCd KK_RENKEI.JIP_DENBUN_CD%TYPE,
	gItakuKaishaRnm MITAKU_KAISHA.ITAKU_KAISHA_RNM%TYPE,
	l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE,
	l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE,
	l_inJipDenbunCd KK_RENKEI.JIP_DENBUN_CD%TYPE,
	recKK record,
	USER_ID varchar(10),
	SP_ID varchar(20)
) RETURNS integer AS $body$
DECLARE

	rtn					integer := pkconstant.success();
	outRtn				integer;
	outSqlErrM			varchar(1000);		-- SQLエラーメッセージ
	l_hkt_cd					MGR_KIHON.HKT_CD%TYPE			:= '';
	l_KkHakkoCd_KK		MGR_KIHON.KK_HAKKO_CD%TYPE		:= '';
	l_KkHakkoRnm_KK		MGR_KIHON.KK_HAKKOSHA_RNM%TYPE	:= '';
	l_KkHakkoCd_HT		MGR_KIHON.KK_HAKKO_CD%TYPE		:= '';
	l_KkHakkoRnm_HT		MGR_KIHON.KK_HAKKOSHA_RNM%TYPE	:= '';
	l_KListMsg			varchar(100) := NULL;		-- 確認リスト表示メッセージ
BEGIN
-- * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
--	  2006/02/23 yamashita 既存の処理と同様に、SCOMPARING_ITEM および SCOMPARING_CONDITIONを
--	  使用すると、関連処理で障害が発生する可能性が高いので、現行保障のため独立した処理を追加
--	 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
	-- 対象銘柄の銘柄_基本.発行体コードを取得
	BEGIN
		SELECT HKT_CD INTO STRICT l_hkt_cd FROM MGR_KIHON WHERE ITAKU_KAISHA_CD = gItakuKaishaCd  AND MGR_CD = gMgrCd;
	EXCEPTION
            WHEN OTHERS THEN NULL;
	END;
	-- 機構連携テーブルの機構発行体コード＆機構発行者略称を再取得
	BEGIN
    		SELECT
    			TRIM(BOTH CHR(33088) FROM trim(both recKK.ITEM012) ), TRIM(BOTH CHR(33088) FROM trim(both recKK.ITEM018) )
    		INTO STRICT
    			l_KkHakkoCd_KK,l_KkHakkoRnm_KK
    		FROM
    			KK_RENKEI
    		WHERE
    			KK_SAKUSEI_DT    = l_inKkSakuseiDt
    		AND	DENBUN_MEISAI_NO = l_inDenbunMeisaiNo
    		AND	JIP_DENBUN_CD    = l_inJipDenbunCd;
	EXCEPTION
            WHEN OTHERS THEN NULL;
	END;
	-- 発行体マスタより、対象銘柄の発行体の機構発行体コード＆機構発行者略称を取得する。
	BEGIN
		SELECT
			KK_HAKKO_CD,KK_HAKKOSHA_RNM
    		INTO STRICT
   			l_KkHakkoCd_HT,l_KkHakkoRnm_HT
		FROM
			MHAKKOTAI
		WHERE
			ITAKU_KAISHA_CD = gItakuKaishaCd
		AND	HKT_CD = l_hkt_cd;
	EXCEPTION
		WHEN no_data_found THEN
			NULL;
		WHEN OTHERS THEN
			NULL;
	END;
	-- * * * * * * 機構発行者略称の更新チェック＆更新＆確認リスト設定 * * * * * * 
	l_KListMsg := '';
	-- ISIN付番結果通知の機構発行者略称が空白ではない場合
	-- ※返ってきた電文の機構発行者略称が空白の場合は何もしない
	IF (trim(both l_KkHakkoRnm_KK) IS NOT NULL AND (trim(both l_KkHakkoRnm_KK))::text <> '') THEN
		-- 発行体マスタと機構連携で機構発行者略称が異なる場合
		-- ※同じなら更新の必要が無いので何もしない
		IF l_KkHakkoRnm_HT <> l_KkHakkoRnm_KK THEN
			-- ①発行体マスタの機構発行者略称が空白 かつ
			--　（機構発行者コードが同じ場合
			--　　または 発行体マスタの機構発行者コードも空白
			--　　または (ISIN付番通知の機構発行者コードが空白 かつ 発行体マスタの機構発行者コードが空白でない)）
			IF coalesce(trim(both l_KkHakkoRnm_HT)::text, '') = ''
				 AND (l_KkHakkoCd_HT = l_KkHakkoCd_KK
					 OR coalesce(trim(both l_KkHakkoCd_HT)::text, '') = ''
					 OR (coalesce(trim(both l_KkHakkoCd_KK)::text, '') = '' AND (trim(both l_KkHakkoCd_HT) IS NOT NULL AND (trim(both l_KkHakkoCd_HT))::text <> ''))) THEN
				-- 発行体マスタの履歴テーブルに現在の内容を追加
				-- 履歴テーブル登録
				CALL pkRireki.rirekiInsert(
							l_inTableNm => 'MHAKKOTAI',
							l_inUserId => USER_ID,
							l_inKey1 => gItakuKaishaCd,
							l_inKey2 => l_KkHakkoCd_HT,
							l_outSqlCode => outRtn,
							l_outSqlErrM => outSqlErrM
				);
				IF outRtn <> 0 AND outRtn <> 1 THEN
					CALL pkLog.error('ECM701', SP_ID, 'RETURN：' || outRtn);
					CALL pkLog.error('ECM701', SP_ID, 'エラー内容：' || outSqlErrM);
					RETURN pkconstant.FATAL();
				END IF;
				-- 発行体マスタの機構発行者略称を更新
				UPDATE MHAKKOTAI SET KK_HAKKOSHA_RNM = l_KkHakkoRnm_KK
				WHERE
					ITAKU_KAISHA_CD = gItakuKaishaCd
				AND	HKT_CD = l_hkt_cd;
				-- 確認リストに表示するメッセージをセット
--					l_KListMsg := 'が未設定のため、受信電文の内容で更新します。';
			-- ②発行体マスタの機構発行者略称に値が存在
			ELSIF  (trim(both l_KkHakkoRnm_HT) IS NOT NULL AND (trim(both l_KkHakkoRnm_HT))::text <> '') THEN
				-- 確認リストに表示するメッセージをセット
				l_KListMsg := 'が、受信電文の内容と相違。取込処理は正常に完了しています。後続処理には影響ありません。';
			END IF;
		END IF;
		-- メッセージが設定されている場合は確認リスト内容をセット
		IF (l_KListMsg IS NOT NULL AND l_KListMsg::text <> '') THEN
			-- 確認リスト出力内容を帳票ワークテーブルに登録
			CALL pkKakuninList.insertKakuninData(
								gItakuKaishaCd,
								USER_ID,
								pkKakuninList.CHOHYO_KBN_BATCH(),
								gGyomuYmd,
								'発行体マスタの機構発行者略称' || l_KListMsg,
								gIsinCd,
								gMgrCd,
								gMgrRnm,
								l_KkHakkoRnm_HT,
								l_KkHakkoRnm_KK,
								gJipDenbunCd,
								gItakuKaishaRnm
								);
--				rtn := pkconstant.RECONCILE_ERROR();		--突合エラーにしない為コメントアウト
		END IF;
	END IF;
	-- * * * * * * 機構発行者コードの更新チェック＆更新＆確認リスト設定 * * * * * * 
	l_KListMsg := '';
	-- ISIN付番結果通知の機構発行者コードが空白ではない場合
	-- ※返ってきた電文の機構発行者コードが空白の場合は何もしない
	IF (trim(both l_KkHakkoCd_KK) IS NOT NULL AND (trim(both l_KkHakkoCd_KK))::text <> '') THEN
		-- 発行体マスタと機構連携で機構発行者コードが異なる場合
		-- ※同じなら更新の必要が無いので何もしない
		IF l_KkHakkoCd_HT <> l_KkHakkoCd_KK THEN
			-- ①発行体マスタの機構発行者コードが空白 かつ（機構発行者略称が同じ場合 または　発行体マスタの機構発行者略称も空白）
			IF coalesce(trim(both l_KkHakkoCd_HT)::text, '') = '' AND (l_KkHakkoRnm_HT = l_KkHakkoRnm_KK OR coalesce(trim(both l_KkHakkoRnm_HT)::text, '') = '') THEN
				-- 発行体マスタの履歴テーブルに現在の内容を追加
				-- 履歴テーブル登録
				CALL pkRireki.rirekiInsert(
							l_inTableNm => 'MHAKKOTAI',
							l_inUserId => USER_ID,
							l_inKey1 => gItakuKaishaCd,
							l_inKey2 => l_KkHakkoCd_HT,
							l_outSqlCode => outRtn,
							l_outSqlErrM => outSqlErrM
				);
				IF outRtn <> 0 AND outRtn <> 1 THEN
					CALL pkLog.error('ECM701', SP_ID, 'RETURN：' || outRtn);
					CALL pkLog.error('ECM701', SP_ID, 'エラー内容：' || outSqlErrM);
					RETURN pkconstant.FATAL();
				END IF;
				-- 発行体マスタの機構発行者コードを更新
				UPDATE MHAKKOTAI SET KK_HAKKO_CD = l_KkHakkoCd_KK
				WHERE
					ITAKU_KAISHA_CD = gItakuKaishaCd
				AND	HKT_CD = l_hkt_cd;
				-- 確認リストに表示するメッセージをセット
--					l_KListMsg := 'が未設定のため、受信電文の内容で更新します。';
			-- ②発行体マスタの機構発行者コードに値が存在
			ELSIF  (trim(both l_KkHakkoCd_HT) IS NOT NULL AND (trim(both l_KkHakkoCd_HT))::text <> '') THEN
				-- 確認リストに表示するメッセージをセット
				l_KListMsg := 'が、受信電文の内容と相違。取込処理は正常に完了しています。後続処理には影響ありません。';
			END IF;
		END IF;
		-- メッセージが設定されている場合は確認リスト内容をセット
		IF (l_KListMsg IS NOT NULL AND l_KListMsg::text <> '') THEN
			-- 確認リスト出力内容を帳票ワークテーブルに登録
			CALL pkKakuninList.insertKakuninData(
								gItakuKaishaCd,
								USER_ID,
								pkKakuninList.CHOHYO_KBN_BATCH(),
								gGyomuYmd,
								'発行体マスタの機構発行者コード' || l_KListMsg,
								gIsinCd,
								gMgrCd,
								gMgrRnm,
								l_KkHakkoCd_HT,
								l_KkHakkoCd_KK,
								gJipDenbunCd,
								gItakuKaishaRnm
								);
--				rtn := pkconstant.RECONCILE_ERROR();		--突合エラーにしない為コメントアウト
		END IF;
	END IF;
	RETURN rtn;
EXCEPTION
	WHEN	OTHERS	THEN
		CALL pkLog.error('ECM701', SP_ID, '発行体マスタの更新中に例外が発生しました。');
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi002r15211_updatehakkotai () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadi002r15211_updatekkrenkeircv (
	USER_ID varchar(10),
	SP_ID varchar(20),
	l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE,
	l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE,
	l_inJipDenbunCd KK_RENKEI.JIP_DENBUN_CD%TYPE,
	l_inGyomuStatCd KK_RENKEI.GYOMU_STAT_CD%TYPE DEFAULT 0
) RETURNS integer AS $body$
DECLARE

	ora2pg_rowcount int;
rtn		integer;

BEGIN
	rtn := pkconstant.FATAL();
        UPDATE KK_RENKEI
        SET GYOMU_STAT_CD = l_inGyomuStatCd
           ,KOUSIN_ID = USER_ID
        WHERE KK_SAKUSEI_DT =  l_inKkSakuseiDt
    	    AND DENBUN_MEISAI_NO = l_inDenbunMeisaiNo
    	    AND JIP_DENBUN_CD = l_inJipDenbunCd;
	GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;
IF ora2pg_rowcount = 0 THEN
		CALL pkLog.error('ECM3A3', SP_ID, '機構連携が１件も更新されませんでした。');
		rtn := pkconstant.NO_DATA_FIND();
	ELSE
		rtn := pkconstant.success();
	END IF;
	RETURN rtn;
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi002r15211_updatekkrenkeircv (l_inGyomuStatCd KK_RENKEI.GYOMU_STAT_CD%TYPE DEFAULT 0) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadi002r15211_updatekkrenkeisnd (
	USER_ID varchar(10),
	SP_ID varchar(20),
	gKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE,
	gDenbunMeisai KK_RENKEI.ITEM001%TYPE,
	l_inGyomuStatCd KK_RENKEI.GYOMU_STAT_CD%TYPE DEFAULT 0
) RETURNS integer AS $body$
DECLARE

	ora2pg_rowcount int;
rtn		integer;

BEGIN
	rtn := pkconstant.FATAL();
        UPDATE KK_RENKEI
        SET GYOMU_STAT_CD = l_inGyomuStatCd
           ,KOUSIN_ID = USER_ID
        WHERE KK_SAKUSEI_DT =  gKkSakuseiDt
    	    AND DENBUN_MEISAI_NO = gDenbunMeisai
    	    AND JIP_DENBUN_CD = 'S1511';
	GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;
IF ora2pg_rowcount = 0 THEN
		CALL pkLog.error('ECM3A3', SP_ID, '機構連携が１件も更新されませんでした。');
		rtn := pkconstant.NO_DATA_FIND();
	ELSE
		rtn := pkconstant.success();
	END IF;
	RETURN rtn;
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi002r15211_updatekkrenkeisnd (l_inGyomuStatCd KK_RENKEI.GYOMU_STAT_CD%TYPE DEFAULT 0) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadi002r15211_updatemgrkihon (
	gShinkiKbn KK_RENKEI.ITEM001%TYPE,
	gMgrTaikeiKbn MGR_STS.MGR_TAIKEI_KBN%TYPE,
	gIsinCd KK_RENKEI.ITEM001%TYPE,
	gTokureiFlg KK_RENKEI.ITEM001%TYPE,
	gPartmgrKbn MGR_KIHON.PARTMGR_KBN%TYPE,
	gHakkoRnm KK_RENKEI.ITEM001%TYPE,
	gKaigo KK_RENKEI.ITEM001%TYPE,
	gBoshuKbn KK_RENKEI.ITEM001%TYPE,
	USER_ID varchar(10),
	SP_ID varchar(20),
	gItakuKaishaCd MGR_KIHON.ITAKU_KAISHA_CD%TYPE,
	gMgrCd KK_RENKEI.ITEM001%TYPE
) RETURNS integer AS $body$
DECLARE

	ora2pg_rowcount int;
	rtn			integer;
	sSql		varchar(1000);
	sSql2		varchar(500);
	sSql3       varchar(500);
	mgrRnm		MGR_KIHON.MGR_RNM%TYPE;
	hakkoRnm	varchar(16);
	kkHakkoRnm	varchar(16);
	kaigo		varchar(20);
	boshuKbn	varchar(2);
	keiyakuFlg	char(1) := '0';	-- 自行情報マスタ.契約書システム利用フラグ
	uSql		varchar(20);			-- UPDATE文 + 更新先のテーブル名(銘柄_基本 、契約書システムの銘柄_基本)
BEGIN
	rtn := pkconstant.success();
	-- 新規データのとき
	IF gShinkiKbn = ' ' THEN
		-- 90B体系の場合
		IF gMgrTaikeiKbn = '1' AND (trim(both gIsinCd) IS NOT NULL AND (trim(both gIsinCd))::text <> '') THEN
			sSql2 := 'ISIN_CD = ''' || gIsinCd || ''',';
			-- RAISE NOTICE '90B体系%', sSql2;
			-- 特例債親銘柄の場合
			IF gTokureiFlg = 'Y' AND gPartmgrKbn = '1' THEN
				-- 原ISINコードをセット
				sSql2 := sSql2 || 'GENISIN_CD = ''' || gIsinCd || ''',';
				-- RAISE NOTICE '特例債%', sSql2;
			END IF;
		END IF;
		-- 通常体系の場合
		IF gMgrTaikeiKbn = '0' THEN
			-- 銘柄略称編集
			hakkoRnm := trim(both SFADI002R15211_multiSpaceTrim(gHakkoRnm));	-- 半角・全角トリム
			kaigo := trim(both SFADI002R15211_multiSpaceTrim(gKaigo));			-- 半角・全角トリム
			boshuKbn := pkCharacter.TO_ZENKANA(gBoshuKbn);	-- 全角変換
			hakkoRnm := RPAD(hakkoRnm,16,'　');				-- 全角スペース埋め
			kaigo := RPAD(kaigo,20,'　');					-- 全角スペース埋め
			-- 機構発行者略称(半角・全角トリムのみ)
			kkHakkoRnm := trim(both SFADI002R15211_multiSpaceTrim(gHakkoRnm));
			mgrRnm := hakkoRnm || kaigo || boshuKbn || '　ＳＢ';
			sSql2 := sSql2 || 'KK_HAKKOSHA_RNM = ''' || kkHakkoRnm || ''',';
			sSql2 := sSql2 || 'MGR_RNM = ''' || mgrRnm || ''',';
			-- 新発債、または通常体系子銘柄の場合、ISINコードを更新
			IF (gTokureiFlg = 'N' OR gPartmgrKbn = '2') THEN
				sSql2 := sSql2 || 'ISIN_CD = ''' || gIsinCd || ''',';
			END IF;
		END IF;
	END IF;
	IF (sSql2 IS NOT NULL AND sSql2::text <> '') THEN
		-- 銘柄_基本テーブル更新
		uSql := 'UPDATE MGR_KIHON ';
		sSql := 'SET '
			||  sSql2
			|| ' LAST_TEISEI_DT = TO_TIMESTAMP(''' || pkDate.getCurrentTime() || ''', ''YYYY-MM-DD HH24:MI:SS.FF6'') ,'
			|| ' KOUSIN_ID = ''' || USER_ID || ''''
			|| ' WHERE ITAKU_KAISHA_CD =  ''' || gItakuKaishaCd || ''''
			|| ' AND MGR_CD = ''' || gMgrCd || '''';
		EXECUTE uSql || sSql;
		GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;
IF ora2pg_rowcount = 0 THEN
			CALL pkLog.error('ECM3A3', SP_ID, '銘柄_基本が１件も更新されませんでした。');
			rtn := pkconstant.NO_DATA_FIND();
		END IF;
		-- RAISE NOTICE '変数% % %', gMgrTaikeiKbn, gTokureiFlg, gPartmgrKbn;
		--90B体系の特例社債親銘柄は子銘柄の原ISINコードも更新する。
		IF (gMgrTaikeiKbn = '1' AND gTokureiFlg = 'Y' AND gPartmgrKbn = '1') THEN
			uSql  :='UPDATE MGR_KIHON ';
			sSql3 :='SET '
				|| ' GENISIN_CD = ''' || gIsinCd || ''','
				|| ' LAST_TEISEI_DT = TO_TIMESTAMP(''' || pkDate.getCurrentTime() || ''', ''YYYY-MM-DD HH24:MI:SS.FF6'') ,'
				|| ' KOUSIN_ID = ''' || USER_ID || ''''
				|| ' WHERE ITAKU_KAISHA_CD =  ''' || gItakuKaishaCd || ''''
				|| ' AND TRIM(SUBSTR(YOBI3, 1, 13)) = ''' || gMgrCd || ''''
				|| ' AND PARTMGR_KBN = ''2''';
			EXECUTE uSql || sSql3;
			GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;
IF ora2pg_rowcount = 0 THEN
				CALL pkLog.error('ECM3A3', SP_ID, '子銘柄は１件も更新されませんでした。');
				rtn := pkconstant.NO_DATA_FIND();
			END IF;
		END IF;
		--**** 契約書システムの銘柄_基本に更新する場合 ****
		-- ※りそなカスタマイズのみの処理。自行情報マスタ.契約書システム利用フラグ = 1：利用 の場合
		BEGIN
			-- 契約書システム利用フラグ取得
			SELECT CONTRACT_SYS_FLG INTO STRICT keiyakuFlg FROM VJIKO_ITAKU WHERE KAIIN_ID = gItakuKaishaCd;
			EXCEPTION
				WHEN OTHERS THEN
					keiyakuFlg := '0'; -- 利用しない
		END;
		IF keiyakuFlg = '1' THEN
			-- 契約書システムの銘柄_基本も更新
			uSql  :='UPDATE S_MGR_KIHON ';
			EXECUTE uSql || sSql;			-- ISINコードをUPDATE
			GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;
IF ora2pg_rowcount = 0 THEN
				CALL pkLog.info('WCM001', SP_ID, '契約書システム銘柄_基本が１件も更新されませんでした。');
--					rtn := pkconstant.NO_DATA_FIND();
			END IF;
			--90B体系の特例社債親銘柄は子銘柄の原ISINコードも更新する。
			IF (gMgrTaikeiKbn = '1' AND gTokureiFlg = 'Y' AND gPartmgrKbn = '1') THEN
				EXECUTE uSql || sSql3;	-- 原ISINコードをUPDATE
				GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;
IF ora2pg_rowcount = 0 THEN
					CALL pkLog.info('WCM001', SP_ID, '契約書システム子銘柄は１件も更新されませんでした。');
--						rtn := pkconstant.NO_DATA_FIND();
				END IF;
			END IF;
		END IF;
	END IF;
	RETURN rtn;
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi002r15211_updatemgrkihon () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadi002r15211_updatemgrsts (
	gErrCd KK_RENKEI.ITEM001%TYPE,
	USER_ID varchar(10),
	SP_ID varchar(20),
	gItakuKaishaCd MGR_KIHON.ITAKU_KAISHA_CD%TYPE,
	gMgrCd KK_RENKEI.ITEM001%TYPE,
	gChkKkStat MGR_KIHON_VIEW.KK_PHASE%TYPE,
	gChkKkPhase MGR_KIHON_VIEW.KK_PHASE%TYPE,
	l_inErrCd MGR_STS.MGR_KK_ERR_CD%TYPE,
	l_inStatFlg integer DEFAULT 0
) RETURNS integer AS $body$
DECLARE

	ora2pg_rowcount int;
	rtn		integer;
	sSql	varchar(500);
	sSql2	varchar(100);

BEGIN
	rtn := pkconstant.FATAL();
	IF l_inStatFlg = 1 AND coalesce(trim(both gErrCd),' ') != 'ACPT' THEN
		sSql2 := 'KK_STAT = ''' || pkKkNotice.MGR_KKSTAT_FIN() || ''','
        	|| ' SHONIN_KAIJO_YOKUSEI_FLG = ''0'',';
	END IF;
        sSql := 'UPDATE MGR_STS'
        || ' SET MGR_KK_ERR_CD = ''' || l_inErrCd || ''','
    	    ||  sSql2
        	|| ' LAST_TEISEI_DT = TO_TIMESTAMP(''' || pkDate.getCurrentTime() || ''', ''YYYY-MM-DD HH24:MI:SS.FF6'') ,'
        	|| ' KOUSIN_ID = ''' || USER_ID || ''''
        || ' WHERE ITAKU_KAISHA_CD =  ''' || gItakuKaishaCd || ''''
    	    || ' AND MGR_CD = ''' || gMgrCd || ''''
    	    || ' AND KK_STAT = ''' || gChkKkStat || ''''
    	    || ' AND KK_PHASE = ''' || gChkKkPhase || '''';
        EXECUTE sSql;
	GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;
IF ora2pg_rowcount = 0 THEN
		CALL pkLog.error('ECM3A3', SP_ID, '銘柄ステータス管理が１件も更新されませんでした。');
		rtn := pkconstant.NO_DATA_FIND();
	ELSE
		rtn := pkconstant.success();
	END IF;
	RETURN rtn;
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi002r15211_updatemgrsts (l_inErrCd MGR_STS.MGR_KK_ERR_CD%TYPE, l_inStatFlg integer DEFAULT 0) FROM PUBLIC;

