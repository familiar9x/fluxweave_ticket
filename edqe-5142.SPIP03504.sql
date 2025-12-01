


DROP TYPE IF EXISTS spip03504_type_record;
CREATE TYPE spip03504_type_record AS (
		gItakuKaishaCd		char(4)
		,gMgrCd				varchar(13)
		,gHrkmOutFlg		char(1)
		,gHakkoTsukaCd		char(3)
		,gChokyuYmd			char(8)
		,gKozaTenCd			char(4)
		,gKozaTenCifcd		char(11)
		,gKozaFuriKbn		char(2)
		,gIsinCd			char(12)
		,gChokyuYyyyMm		varchar(6)
		,gChokyuDd			varchar(2)
	);


CREATE OR REPLACE PROCEDURE spip03504 ( l_inUserId SUSER.USER_ID%TYPE,					-- ユーザID
 l_inItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE,	-- 委託会社コード
 l_inKijunYmdFrom MGR_RBRKIJ.KKN_CHOKYU_YMD%TYPE,		-- 基準日From
 l_inKijunYmdTo MGR_RBRKIJ.KKN_CHOKYU_YMD%TYPE,		-- 基準日To
 l_inHktCd MHAKKOTAI.HKT_CD%TYPE,				-- 発行体コード
 l_inKozaTenCd MHAKKOTAI.KOZA_TEN_CD%TYPE,			-- 口座店コード
 l_inKozaTenCifcd MHAKKOTAI.KOZA_TEN_CIFCD%TYPE,		-- 口座店CIFコード
 l_inMgrCd MGR_STS.MGR_CD%TYPE,				-- 銘柄コード
 l_inIsinCd MGR_KIHON.ISIN_CD%TYPE,				-- ISINコード
 l_inTsuchiYmd text,							-- 通知日
 l_outSqlCode OUT integer,								-- リターン値
 l_outSqlErrM OUT text							-- エラーコメント
 ) AS $body$
DECLARE

--
-- * 著作権:Copyright(c)2005
-- * 会社名:JIP
-- * @version $Id: SPIP03504.SQL,v 1.14 2006/05/15 09:02:31 yamashita Exp $
-- * @version $Revision: 1.14 $
-- * 概要　:顧客宛帳票出力指示画面の入力条件により、募集受託手数料分配予定通知書を作成する。
-- * @param	l_inUserId			ユーザID
-- * @param 	l_inItakuKaishaCd	委託会社コード
-- * @param 	l_inKijunYmdFrom	基準日From
-- * @param 	l_inKijunYmdTo		基準日To
-- * @param 	l_inHktCd			発行体コード
-- * @param 	l_inKozaTenCd		口座店コード
-- * @param 	l_inKozaTenCifcd	口座店CIFコード
-- * @param 	l_inMgrCd			銘柄コード
-- * @param 	l_inIsinCd			ISINコード
-- * @param 	l_inTsuchiYmd		通知日
-- * @param 	l_outSqlCode		リターン値
-- * @param 	l_outSqlErrM		エラーコメント
-- * 返り値:なし
-- 
--==============================================================================
--					デバッグ機能													
--==============================================================================
	DEBUG	numeric(1)	:= 0;
--==============================================================================
--					定数定義													
--==============================================================================
	RTN_OK				CONSTANT integer		:= 0;				-- 正常
	RTN_NG				CONSTANT integer		:= 1;				-- 予期したエラー
	RTN_FATAL			CONSTANT integer		:= 99;				-- 予期せぬエラー
	REPORT_ID			CONSTANT char(11)		:= 'IP030003541';	-- 帳票ID
--==============================================================================
--					変数定義													
--==============================================================================
	gRtnCd				integer :=	RTN_OK;						-- リターンコード
	gRecCnt				integer := 0;							-- カウンター
	gSQL				varchar(3000) := NULL;				-- SQL編集
	pCntMgr				integer := 0;							-- 更新対象銘柄のカウンター(副受託判定用)
	l_loopcnt			integer := 0;
	l_TesuShuruiCd		char(2);
	l_GyomuYmd			char(8);
	l_KjnYmdFrom		char(8);
	l_KjnYmdTo			char(8);
	-- カーソル
	cur REFCURSOR;
	-- Array to store records
	rec spip03504_type_record[]; -- レコード
	tmpRec spip03504_type_record; -- Temporary record for FETCH
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	-- 業務日付取得
	l_GyomuYmd := pkDate.getGyomuYmd();
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp03504 START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inKijunYmdFrom)::text, '') = ''
	AND coalesce(trim(both l_inKijunYmdTo)::text, '') = ''
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '入力パラメータエラー';
		CALL pkLog.error('ECM701', REPORT_ID, 'SQLERRM:'||l_outSqlErrM);
		RETURN;
	END IF;
	-- パラメータの基準日From-Toをセット
	l_KjnYmdFrom := l_inKijunYmdFrom;
	l_KjnYmdTo   := l_inKijunYmdTo;
	-- 基準日Toのみ入力されている場合はFromに最小値を、Fromのみの場合はToに最大値をセットする。
	IF coalesce(trim(both l_inKijunYmdFrom)::text, '') = '' THEN
		l_KjnYmdFrom := '00000000';
	END IF;
	IF coalesce(trim(both l_KjnYmdTo)::text, '') = '' THEN
		l_KjnYmdTo := '99999999';
	END IF;
	-- 募集受託手数料・当初信託報酬の両方を抽出、計算するため、手数料種類コードを変えてループで2回まわす
	FOR l_loopcnt in 0..1 LOOP
		IF l_loopcnt = 0 THEN
			l_TesuShuruiCd := '01'; -- 手数料種類CD＝'01':募集受託手数料
		ELSE
			l_TesuShuruiCd := '02'; -- 手数料種類CD＝'02':当初信託報酬
		END IF;
		-- カーソルの作成
		gSQL := PKIPACALCTESURYO.createSQL(	l_inItakuKaishaCd,
											l_TesuShuruiCd , -- 手数料種類CD＝'01':募集受託手数料、'02':当初信託報酬
											l_KjnYmdFrom  ,
											l_KjnYmdTo  ,
											l_inHktCd ,
											l_inKozaTenCd  ,
											l_inKozaTenCifcd  ,
											l_inMgrCd  ,
											l_inIsinCd  );
		-- 募集受託手数料を計算し、手数料計算結果テーブルを更新する
		OPEN cur FOR EXECUTE gSQL;
		-- カウンターの初期化
		gRecCnt := 0;
		-- Initialize array
		rec := ARRAY[]::spip03504_type_record[];
		LOOP
			-- Fetch into temporary record
			FETCH cur INTO
				tmpRec.gItakuKaishaCd,
				tmpRec.gMgrCd,
				tmpRec.gHrkmOutFlg,	-- 払込金計算書出力済フラグ
				tmpRec.gHakkoTsukaCd,
				tmpRec.gChokyuYmd,
				tmpRec.gKozaTenCd,
				tmpRec.gKozaTenCifcd,
				tmpRec.gKozaFuriKbn,
				tmpRec.gIsinCd,
				tmpRec.gChokyuYyyyMm,
				tmpRec.gChokyuDd;
			EXIT WHEN NOT FOUND;/* apply on cur */
			
			-- Append the record to array
			rec := array_append(rec, tmpRec);
			gRecCnt := gRecCnt + 1;
			-- 銘柄が副受託の場合には出力対象外とするためのチェック
			pCntMgr := 0;
			SELECT COUNT(MGR_CD) INTO STRICT pCntMgr FROM MGR_KIHON_VIEW
			WHERE
				ITAKU_KAISHA_CD = rec[gRecCnt].gItakuKaishaCd 	-- 委託会社コード
			AND	MGR_CD = rec[gRecCnt].gMgrCd 					-- 銘柄コード
			AND JTK_KBN <> '2';									-- 受託区分 = 副受託以外
			IF pCntMgr > 0 THEN
				--　手数料を計算し、計算結果テーブルに格納する
				--　募集受託手数料計算
				gRtnCd := PKIPABOSHUTESURYO.updateBoshuTesuryo(	rec[gRecCnt].gItakuKaishaCd,
																rec[gRecCnt].gMgrCd,
																l_TesuShuruiCd, -- 手数料種類CD＝'01':募集受託手数料、'02':当初信託報酬
																PKIPACALCTESURYO.C_DATA_KBN_SEIKYU());
				-- 手数料計算結果テーブルへの更新の処理に成功したかどうか判定する
				IF gRtnCd <> pkconstant.success() THEN
					l_outSqlCode := gRtnCd;
					l_outSqlErrM := '手数料計算結果テーブル作成処理が失敗しました。';
					CALL pkLog.error('ECM701', 'spIp09101', 'エラーメッセージ：' ||l_outSqlErrM);
					RETURN;
				END IF;
			END IF;
		END LOOP;
		CLOSE cur;
	END LOOP;
	-- 募集受託手数料計算 請求書作票ファンクションをコールする
	CALL SPIP03504_01(l_KjnYmdFrom,
				l_KjnYmdTo,
				l_inHktCd,
				l_inKozaTenCd,
				l_inKozaTenCifcd,
				l_inMgrCd,
				l_inIsinCd,
				l_inTsuchiYmd,
				l_inItakuKaishaCd,
				l_inUserId,
				PKIPACALCTESURYO.C_REAL(),
				l_GyomuYmd,
				gRtnCd,
				l_outSqlErrM
				);
-- 請求書作成に成功したかどうか判定する
	IF gRtnCd <> pkconstant.success() THEN
		l_outSqlCode := gRtnCd;
		l_outSqlErrM := '請求書作成に失敗しました';
		CALL pkLog.error('ECM701', 'SPIP03504', 'エラーメッセージ：'||l_outSqlErrM);
		RETURN;
	END IF;
	l_outSqlCode := pkconstant.success();
	l_outSqlErrM := '';
	RETURN;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip03504 ( l_inUserId SUSER.USER_ID%TYPE, l_inItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE, l_inKijunYmdFrom MGR_RBRKIJ.KKN_CHOKYU_YMD%TYPE, l_inKijunYmdTo MGR_RBRKIJ.KKN_CHOKYU_YMD%TYPE, l_inHktCd MHAKKOTAI.HKT_CD%TYPE, l_inKozaTenCd MHAKKOTAI.KOZA_TEN_CD%TYPE, l_inKozaTenCifcd MHAKKOTAI.KOZA_TEN_CIFCD%TYPE, l_inMgrCd MGR_STS.MGR_CD%TYPE, l_inIsinCd MGR_KIHON.ISIN_CD%TYPE, l_inTsuchiYmd text, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;
