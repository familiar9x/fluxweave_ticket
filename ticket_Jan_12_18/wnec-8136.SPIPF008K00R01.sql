


DROP TYPE IF EXISTS spipf008k00r01_type_record;
CREATE TYPE spipf008k00r01_type_record AS (
		gJikoDaikoKbn					char(1) 					-- 自行代行区分
		,gBankRnm						varchar(20) 						-- 銀行略称
		,gMgrCd							varchar(13)							-- 銘柄コード
		,gIsinCd						char(12)							-- ＩＳＩＮコード
		,gMgrRnm						varchar(44)							-- 銘柄略称
		,gDairiMotionFlg				char(1)				-- 代理人直接申請フラグ
		,gDairiMotionFlgNm				varchar(40)								-- 代理人直接申請フラグ名称
		,gHkukKaishaCd					char(5)											-- 引受会社コード
		,gBicCdNoshiten					char(8)				-- ＢＩＣコード(支店コードなし)
		,gHkukKaishaNm					varchar(30)								-- 引受会社名称
		,gSsiMukoFlgCd					char(1)				-- ＳＳＩ無効化フラグコード
		,gSsiMukoFlgNm					varchar(40)								-- ＳＳＩ無効化フラグコード名称
		,gHakkoTsukaCd					char(3)					-- 発行通貨
		,gRbrTsukacd					char(3)						-- 利払通貨コード
		,gShokanTsukaCd					char(3)					-- 償還通貨コード
		,gHkukKngk						numeric(14)						-- 引受金額
		,gHakkoKagaku					decimal(5,2)						-- 発行価額
		,gYakujoKngk					decimal(16,2)					-- 約定金額
		,gKokunaiTesuKngk				decimal(14,2)				-- 国内手数料金額
		,gKokunaiTesuSzeiKngk			decimal(12,2)			-- 国内手数料消費税金額
		,gKessaiKngk					decimal(16,2)					-- 決済金額
		,gAiteKkmemberFsKbn				char(1)			-- 金融証券区分(相手方機構加入者)
		,gAiteKkmemberBcd				char(4)				-- 金融機関コード(相手方機構加入者)
		,gAiteKkmemberKkbn				char(2)				-- 口座区分(相手方機構加入者)
		,gAiteKkmemberNm				varchar(30)								-- 相手方機構加入者名称
		,gShanaiKomoku					char(35)					-- 社内処理用項目
		,gMessage1						char(35)						-- メッセージ１
		,gMessage2						char(35)						-- メッセージ２
		,gSknKessaiMethodCdKyotsu		char(4)	-- 資金決済方法コード(共通)
		,gSknKessaiMethodNmKyotsu		varchar(20)								-- 資金決済方法コード(共通)名称
		,gSknShrninFsKbn				char(1)				-- 金融証券区分(資金支払人)
		,gSknShrninBcd					char(4)					-- 金融機関コード(資金支払人)
		,gSknShrniNm					varchar(30)								-- 資金支払人名称
		,gSknShrninScd					char(3)					-- 支店コード(資金支払人)
		,gSknShrninRnm					varchar(30)					-- 支店略称(資金支払人)
		,gUkeKozaFsKbn					char(1)				-- 金融証券区分(受方口座所在)
		,gUkeKozaBcd					char(4)					-- 金融機関コード(受方口座所在)
		,gUkeKozaNm						varchar(30)								-- 受方口座所在名称
		,gUkeKozaScd					char(3)					-- 支店コード(受方口座所在)
		,gUkeKozaSnm					varchar(30)					-- 支店略称(受方口座所在)
		,gUkeKozaKamoku					char(1)				-- 口座科目(受方)
		,gUkeKozaNo						char(7)					-- 口座番号(受方)
		,gUkeKozaKamokuNm				varchar(40)								-- 口座科目(受方)名称
	);


CREATE OR REPLACE PROCEDURE spipf008k00r01 ( l_inShoriCounter numeric,		-- 処理カウンタ
 l_inMgrCd TEXT,		-- 銘柄コード
 l_inMgrMeisaiNo TEXT,		-- 銘柄明細No
 l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inUserId TEXT,		-- ユーザーID
 l_inChohyoKbn TEXT,		-- 帳票区分
 l_inGyomuYmd TEXT,		-- 業務日付
 l_outSqlCode OUT integer,		-- リターン値
 l_outSqlErrM OUT text	-- エラーコメント
 ) AS $body$
DECLARE

--
--/* 著作権:Copyright(c)2004
--/* 会社名:JIP
--/* 概要　:各種バッチ帳票出力指示画面の入力条件により、更新内容リスト（新規募集情報）を作成する。
--/* 引数　:l_inShoriCounter		IN	NUMERIC		処理カウンタ
--/* 　　　 l_inMgrCd				IN	TEXT		銘柄コード
--/* 　　　 l_inMgrMeisaiNo		IN	TEXT		銘柄明細No
--/* 　　　 l_inItakuKaishaCd		IN	TEXT		委託会社コード
--/* 　　　 l_inUserId			IN	TEXT		ユーザーID
--/* 　　　 l_inChohyoKbn			IN	TEXT		帳票区分
--/* 　　　 l_inGyomuYmd			IN	TEXT		業務日付
--/* 　　　 l_outSqlCode			OUT	INTEGER		リターン値
--/* 　　　 l_outSqlErrM			OUT	VARCHAR	エラーコメント
--/* 返り値:なし
--/* @version $Revision: 1.7 $
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.05.30	JIP				新規作成
--/*  2005.06.09	JIP 緒方			新規募集テーブルからのデータ取得方法の変更
--/*  2005.06.24	JIP 緒方			正常終了時、PrtOkテーブルにデータを作成する
--
--***************************************************************************
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
	RTN_NODATA			CONSTANT integer		:= 40;				-- データなし
	RTN_FATAL			CONSTANT integer		:= 99;				-- 予期せぬエラー
	REPORT_ID			CONSTANT char(11)		:= 'IPF30000811';		-- 帳票ID
	-- 書式フォーマット
	FMT_HAKKO_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	FMT_RBR_KNGK_J		CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 利払金額
	FMT_SHOKAN_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 償還金額
	-- 書式フォーマット（外資）
	FMT_HAKKO_KNGK_F	CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 発行金額
	FMT_RBR_KNGK_F		CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 利払金額
	FMT_SHOKAN_KNGK_F	CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 償還金額
	-- SSI無効化フラグ名称
	SSI_MUKO_FLG_Y		CONSTANT char(30)	:= 'SSIを無効にする';
	SSI_MUKO_FLG_N		CONSTANT char(30)	:= 'SSIを無効にしない';
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd				integer :=	RTN_OK;						-- リターンコード
	gSeqNo				integer := 0;							-- シーケンス
	gSQL				varchar(3000) := NULL;				-- SQL編集
	gTsukaNm		varchar(10); -- 2006/6/25 追加　緒方
	-- 書式フォーマット
	gFmtHakkoKngk		varchar(21) := NULL;					-- 発行金額
	gFmtRbrKngk			varchar(21) := NULL;					-- 利払金額
	gFmtShokanKngk		varchar(21) := NULL;					-- 償還金額
	-- DB取得項目
	recMeisai SPIPF008K00R01_TYPE_RECORD;						-- レコード
	-- カーソル
	curMeisai refcursor;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'IPF008K00R01 START');	END IF;
	-- 入力パラメタ(銘柄コードと銘柄明細Ｎｏ)のチェック
	IF coalesce(trim(both l_inMgrMeisaiNo)::text, '') = '' AND coalesce(trim(both l_inMgrCd)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF008K00R01', '＜項目名称:銘柄コード＞'||'＜項目値:'||l_inMgrMeisaiNo||'＞');
		CALL pkLog.error('ECM501', 'IPF008K00R01', '＜項目名称:銘柄明細Ｎｏ＞'||'＜項目値:'||l_inMgrCd||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(処理カウンタ)のチェック
	IF l_inShoriCounter IS NULL THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF008K00R01', '＜項目名称:処理カウンタ＞'||'＜項目値:'||l_inShoriCounter||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(委託会社コード)のチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF008K00R01', '＜項目名称:委託会社コード＞'||'＜項目値:'||l_inItakuKaishaCd||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(ユーザＩＤ)のチェック
	IF coalesce(trim(both l_inUserId)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF008K00R01', '＜項目名称:ユーザＩＤ＞'||'＜項目値:'||l_inUserId||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(帳票区分)のチェック
	IF coalesce(trim(both l_inChohyoKbn)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF008K00R01', '＜項目名称:帳票区分＞'||'＜項目値:'||l_inChohyoKbn||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(業務日付)のチェック
	IF coalesce(trim(both l_inGyomuYmd)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF008K00R01', '＜項目名称:業務日付＞'||'＜項目値:'||l_inGyomuYmd||'＞');
		RETURN;
	END IF;
	IF l_inShoriCounter = 1 THEN
		-- 帳票ワークの削除
		DELETE FROM SREPORT_WK
		WHERE	KEY_CD = l_inItakuKaishaCd
		AND		USER_ID = l_inUserId
		AND		CHOHYO_KBN = l_inChohyoKbn
		AND		SAKUSEI_YMD = l_inGyomuYmd
		AND		CHOHYO_ID = REPORT_ID;
		-- ヘッダレコードを追加
		CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	END IF;
	-- 連番取得(請求書)
	SELECT	coalesce(MAX(SEQ_NO), 0)
	INTO STRICT	gSeqNo
	FROM	SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;
	-- SQL編集
	gSQL := SPIPF008K00R01_createSQL(l_inMgrCd, l_inMgrMeisaiNo, l_inItakuKaishaCd);
	-- カーソルオープン
	OPEN curMeisai FOR EXECUTE gSQL;
	-- データ取得
	LOOP
		FETCH curMeisai INTO	recMeisai.gJikoDaikoKbn 							-- 自行代行区分
								,recMeisai.gBankRnm 							-- 銀行略称
								,recMeisai.gMgrCd 								-- 銘柄コード
								,recMeisai.gIsinCd 								-- ＩＳＩＮコード
								,recMeisai.gMgrRnm 								-- 銘柄略称
								,recMeisai.gDairiMotionFlg 						-- 代理人直接申請フラグ
								,recMeisai.gDairiMotionFlgNm 					--代理人直接申請フラグ名称
								,recMeisai.gHkukKaishaCd 						-- 引受会社コード
								,recMeisai.gBicCdNoshiten 						-- ＢＩＣコード(支店コードなし)
								,recMeisai.gHkukKaishaNm 						-- 引受会社名称
								,recMeisai.gSsiMukoFlgCd 						-- ＳＳＩ無効化フラグコード
								,recMeisai.gSsiMukoFlgNm 						-- ＳＳＩ無効化フラグコード名称
								,recMeisai.gHakkoTsukaCd 						-- 発行通貨
								,recMeisai.gRbrTsukaCd 							-- 利払通貨コード
								,recMeisai.gShokanTsukaCd 						-- 償還通貨コード
								,recMeisai.gHkukKngk 							-- 引受金額
								,recMeisai.gHakkoKagaku 						-- 発行価額
								,recMeisai.gYakujoKngk 							-- 約定金額
								,recMeisai.gKokunaiTesuKngk 						-- 国内手数料金額
								,recMeisai.gKokunaiTesuSzeiKngk 					-- 国内手数料消費税金額
								,recMeisai.gKessaiKngk 							-- 決済金額
								,recMeisai.gAiteKkmemberFsKbn 					-- 金融証券区分(相手方機構加入者)
								,recMeisai.gAiteKkmemberBcd 						-- 金融機関コード(相手方機構加入者)
								,recMeisai.gAiteKkmemberKkbn 					-- 相手方機構加入者区分
								,recMeisai.gShanaiKomoku 						-- 社内処理用項目
								,recMeisai.gMessage1							-- メッセージ１
								,recMeisai.gMessage2							-- メッセージ２
								,recMeisai.gSknKessaiMethodCdKyotsu 				-- 資金決済方法コード(共通)
								,recMeisai.gSknShrninFsKbn 						-- 金融証券区分(資金支払人)
								,recMeisai.gSknShrninBcd 						-- 金融機関コード(資金支払人)
								,recMeisai.gSknShrninScd 						-- 支店コード(資金支払人)
								,recMeisai.gUkeKozaFsKbn 						-- 金融証券区分(受方口座所在)
								,recMeisai.gUkeKozaBcd 							-- 金融機関コード(受方口座所在)
								,recMeisai.gUkeKozaScd 						-- 支店略称(受方口座所在)
								,recMeisai.gUkeKozaKamoku 						-- 口座科目(受方)
								,recMeisai.gUkeKozaNo 					-- 口座科目(受方)名称
								;
		EXIT WHEN NOT FOUND;/* apply on curMeisai */
		-- 相手方機構加入者 金融機関名称取得
		IF (trim(both recMeisai.gAiteKkmemberFskbn) IS NOT NULL AND (trim(both recMeisai.gAiteKkmemberFskbn))::text <> '') AND (trim(both recMeisai.gAiteKkmemberBcd) IS NOT NULL AND (trim(both recMeisai.gAiteKkmemberBcd))::text <> '')  THEN
			SELECT	M02.BANK_RNM
			INTO STRICT		recMeisai.gAiteKkmemberNm
			FROM		MBANK M02
			WHERE	M02.FINANCIAL_SECURITIES_KBN = recMeisai.gAiteKkmemberFskbn
			AND		M02.BANK_CD = recMeisai.gAiteKkmemberBcd;
		END IF;
		-- 資金決済方法 名称取得
		IF (trim(both recMeisai.gSknKessaiMethodCdKyotsu) IS NOT NULL AND (trim(both recMeisai.gSknKessaiMethodCdKyotsu))::text <> '') THEN
			SELECT	MCD.CODE_RNM
			INTO STRICT		recMeisai.gSknKessaiMethodNmKyotsu
			FROM		SCODE MCD
			WHERE	MCD.CODE_SHUBETSU = '743'
			AND		MCD.CODE_VALUE = recMeisai.gSknKessaiMethodCdKyotsu;
		END IF;
		-- 資金支払人 金融機関名称取得
		IF (trim(both recMeisai.gSknShrninFsKbn) IS NOT NULL AND (trim(both recMeisai.gSknShrninFsKbn))::text <> '') AND (trim(both recMeisai.gSknShrninBcd) IS NOT NULL AND (trim(both recMeisai.gSknShrninBcd))::text <> '')  THEN
			SELECT	M02.BANK_RNM
			INTO STRICT		recMeisai.gSknShrniNm
			FROM		MBANK M02
			WHERE	M02.FINANCIAL_SECURITIES_KBN = recMeisai.gSknShrninFsKbn
			AND		M02.BANK_CD = recMeisai.gSknShrninBcd;
			-- 資金支払人 金融機関支店名称取得
			IF (trim(both recMeisai.gSknShrninScd) IS NOT NULL AND (trim(both recMeisai.gSknShrninScd))::text <> '') THEN
				SELECT	M03.SHITEN_RNM
				INTO STRICT		recMeisai.gSknShrninRnm
				FROM		MBANK_SHITEN M03
				WHERE	M03.FINANCIAL_SECURITIES_KBN = recMeisai.gSknShrninFsKbn
				AND		M03.BANK_CD = recMeisai.gSknShrninBcd
				AND		M03.SHITEN_CD = recMeisai.gSknShrninScd;
			END IF;
		END IF;
		-- 受方口座所在金融機関名称取得
		IF (trim(both recMeisai.gUkeKozaFsKbn) IS NOT NULL AND (trim(both recMeisai.gUkeKozaFsKbn))::text <> '') AND (trim(both recMeisai.gUkeKozaBcd) IS NOT NULL AND (trim(both recMeisai.gUkeKozaBcd))::text <> '')  THEN
			SELECT	M02.BANK_RNM
			INTO STRICT		recMeisai.gUkeKozaNm
			FROM		MBANK M02
			WHERE	M02.FINANCIAL_SECURITIES_KBN = recMeisai.gUkeKozaFsKbn
			AND		M02.BANK_CD = recMeisai.gUkeKozaBcd;
			-- 受方口座所在金融機関支店名称取得
			IF (trim(both recMeisai.gUkeKozaScd) IS NOT NULL AND (trim(both recMeisai.gUkeKozaScd))::text <> '') THEN
				SELECT	M03.SHITEN_RNM
				INTO STRICT		recMeisai.gUkeKozaSnm
				FROM		MBANK_SHITEN M03
				WHERE	M03.FINANCIAL_SECURITIES_KBN = recMeisai.gUkeKozaFsKbn
				AND		M03.BANK_CD = recMeisai.gUkeKozaBcd
				AND		M03.SHITEN_CD = recMeisai.gUkeKozaScd;
			END IF;
		END IF;
		-- 受方資金決済口座名称取得
		IF (trim(both recMeisai.gUkeKozaKamoku) IS NOT NULL AND (trim(both recMeisai.gUkeKozaKamoku))::text <> '') THEN
			SELECT	MCD.CODE_NM
			INTO STRICT		recMeisai.gUkeKozaKamokuNm
			FROM		SCODE MCD
			WHERE	MCD.CODE_SHUBETSU = '707'
			AND		MCD.CODE_VALUE = recMeisai.gUkeKozaKamoku;
		END IF;
		gSeqNo := gSeqNo + 1;
		-- 書式フォーマットの設定
		-- 発行
		IF recMeisai.gHakkoTsukaCd = 'JPY' THEN
			gFmtHakkoKngk := FMT_HAKKO_KNGK_J;
		ELSE
			gFmtHakkoKngk := FMT_HAKKO_KNGK_F;
		END IF;
		-- 利払
		IF recMeisai.gRbrTsukaCd = 'JPY' THEN
			gFmtRbrKngk := FMT_RBR_KNGK_J;
		ELSE
			gFmtRbrKngk := FMT_RBR_KNGK_F;
		END IF;
		-- 償還
		IF recMeisai.gShokanTsukaCd = 'JPY' THEN
			gFmtShokanKngk := FMT_SHOKAN_KNGK_J;
		ELSE
			gFmtShokanKngk := FMT_SHOKAN_KNGK_F;
		END IF;
		-- 銀行略称
		IF recMeisai.gJikoDaikoKbn != '2' THEN
			-- 自行代行区分が'2'出ない場合は設定しない
			recMeisai.gBankRnm := NULL;
		END IF;
		-- 通貨名称取得
		IF (trim(both recMeisai.gHakkoTsukaCd) IS NOT NULL AND (trim(both recMeisai.gHakkoTsukaCd))::text <> '')
		THEN
			SELECT TSUKA_NM
			INTO STRICT gTsukaNm
			FROM MTSUKA
			WHERE TSUKA_CD = recMeisai.gHakkoTsukaCd;
		ELSE
			gTsukaNm := NULL;
		END IF;									--2005/6/24 追加　緒方
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := l_inGyomuYmd;	-- 入力業務日付
		v_item.l_inItem003 := recMeisai.gBankRnm;	-- 入力委託会社コード
		v_item.l_inItem004 := recMeisai.gBankRnm;	-- 銀行略称
		v_item.l_inItem005 := recMeisai.gMgrCd;	-- 銘柄コード
		v_item.l_inItem006 := recMeisai.gIsinCd;	-- ＩＳＩＮコード
		v_item.l_inItem007 := recMeisai.gMgrRnm;	-- 銘柄略称
		v_item.l_inItem008 := recMeisai.gDairiMotionFlg;	-- 代理人直接申請フラグ
		v_item.l_inItem009 := recMeisai.gDairiMotionFlgNm;	-- 代理人直接申請フラグ名称
		v_item.l_inItem010 := recMeisai.gHkukKaishaCd;	-- 引受会社コード
		v_item.l_inItem011 := recMeisai.gBicCdNoshiten;	-- ＢＩＣコード(支店コードなし)
		v_item.l_inItem012 := recMeisai.gHkukKaishaNm;	-- 引受会社名称
		v_item.l_inItem013 := recMeisai.gSsiMukoFlgCd;	-- ＳＳＩ無効化フラグコード
		v_item.l_inItem014 := recMeisai.gSsiMukoFlgNm;	-- ＳＳＩ無効化フラグコード名称
		v_item.l_inItem015 := recMeisai.gHakkoTsukaCd;	-- 発行通貨
		v_item.l_inItem016 := recMeisai.gHkukKngk;	-- 引受金額
		v_item.l_inItem017 := recMeisai.gHakkoKagaku;	-- 発行価額
		v_item.l_inItem018 := recMeisai.gYakujoKngk;	-- 約定金額
		v_item.l_inItem019 := recMeisai.gKokunaiTesuKngk;	-- 国内手数料金額
		v_item.l_inItem020 := recMeisai.gKokunaiTesuSzeiKngk;	-- 国内手数料消費税金額
		v_item.l_inItem021 := recMeisai.gKessaiKngk;	-- 決済金額
		v_item.l_inItem022 := recMeisai.gAiteKkmemberFsKbn;	-- 金融証券区分(相手方機構加入者)
		v_item.l_inItem023 := recMeisai.gAiteKkmemberBcd;	-- 金融機関コード(相手方機構加入者)
		v_item.l_inItem024 := recMeisai.gAiteKkmemberKkbn;	-- 口座区分(相手方機構加入者)
		v_item.l_inItem025 := recMeisai.gAiteKkmemberNm;	-- 相手方機構加入者名称
		v_item.l_inItem026 := recMeisai.gShanaiKomoku;	-- 社内処理用項目
		v_item.l_inItem027 := recMeisai.gMessage1;	-- メッセージ１
		v_item.l_inItem028 := recMeisai.gMessage2;	-- メッセージ２
		v_item.l_inItem029 := recMeisai.gSknKessaiMethodCdKyotsu;	-- 資金決済方法コード(共通)
		v_item.l_inItem030 := recMeisai.gSknKessaiMethodNmKyotsu;	-- 資金決済方法コード(共通)名称
		v_item.l_inItem031 := recMeisai.gSknShrninFsKbn;	-- 金融証券区分(資金支払人)
		v_item.l_inItem032 := recMeisai.gSknShrninBcd;	-- 金融機関コード(資金支払人)
		v_item.l_inItem033 := recMeisai.gSknShrniNm;	-- 資金支払人名称
		v_item.l_inItem034 := recMeisai.gSknShrninScd;	-- 支店コード(資金支払人)
		v_item.l_inItem035 := recMeisai.gSknShrninRnm;	-- 支店略称(資金支払人)
		v_item.l_inItem036 := recMeisai.gUkeKozaFsKbn;	-- 金融証券区分(受方口座所在)
		v_item.l_inItem037 := recMeisai.gUkeKozaBcd;	-- 金融機関コード(受方口座所在)
		v_item.l_inItem038 := recMeisai.gUkeKozaNm;	-- 受方口座所在名称
		v_item.l_inItem039 := recMeisai.gUkeKozaScd;	-- 支店コード(受方口座所在)
		v_item.l_inItem040 := recMeisai.gUkeKozaSnm;	-- 支店略称(受方口座所在)
		v_item.l_inItem041 := recMeisai.gUkeKozaKamoku;	-- 口座科目(受方)
		v_item.l_inItem042 := recMeisai.gUkeKozaKamokuNm;	-- 口座科目(受方)名称
		v_item.l_inItem043 := recMeisai.gUkeKozaNo;	-- 口座番号(受方)
		v_item.l_inItem044 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem045 := gFmtHakkoKngk;	-- 発行金額書式フォーマット
		v_item.l_inItem046 := gFmtRbrKngk;	-- 利払金額書式フォーマット
		v_item.l_inItem047 := gFmtShokanKngk;	-- 償還金額書式フォーマット
		v_item.l_inItem048 := gTsukaNm;	-- 償還金額書式フォーマット
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	END LOOP;
	CLOSE curMeisai;
	IF gSeqNo = 0 THEN
	-- 対象データなし
		gRtnCd := RTN_NODATA;
	END IF;
	IF gRtnCd = RTN_OK THEN
		CALL pkPrtOk.insertPrtOk(
			l_inUserId,
			l_inItakuKaishaCd,
			l_inGyomuYmd,
			pkPrtOk.LIST_SAKUSEI_KBN_ZUIJI(),
			REPORT_ID
		);
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'IPF008K00R01 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		BEGIN
			CLOSE curMeisai;
		EXCEPTION
			WHEN OTHERS THEN NULL;  -- Cursor not open
		END;
		RAISE NOTICE 'FATAL ERROR: % (%), SQL: %', SQLERRM, SQLSTATE, substring(gSQL from 1 for 200);
		CALL pkLog.fatal('ECM701', 'IPF008K00R01', 'SQLERRM:'||SQLERRM||'('||SQLSTATE||')');
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM || ' SQL:' || substring(gSQL from 1 for 100);
--		RAISE;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipf008k00r01 ( l_inShoriCounter numeric, l_inMgrCd TEXT, l_inMgrMeisaiNo TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT integer, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spipf008k00r01_createsql (
    p_l_inMgrCd TEXT,
    p_l_inMgrMeisaiNo TEXT,
    p_l_inItakuKaishaCd TEXT
) RETURNS TEXT AS $body$
DECLARE
    SSI_MUKO_FLG_Y CONSTANT char(30) := 'SSIを無効にする';
    SSI_MUKO_FLG_N CONSTANT char(30) := 'SSIを無効にしない';
    gSQL varchar(3000);
BEGIN
	gSQL := '';
	gSQL := gSQL || 'SELECT VJI.JIKO_DAIKO_KBN,';												-- 自行代行区分
	gSQL := gSQL || '		VJI.BANK_RNM,';														-- 銀行略称
	gSQL := gSQL || '		B01.MGR_CD,';														-- 銘柄コード
	gSQL := gSQL || '		MG1.ISIN_CD,';														-- ＩＳＩＮコード
	gSQL := gSQL || '		MG1.MGR_RNM,';														-- 銘柄略称
	gSQL := gSQL || '		B01.DAIRI_MOTION_FLG,';												-- 代理人直接申請フラグ
	gSQL := gSQL || '		MCD1.CODE_NM AS DAIRI_MOTION_FLG_NM,';								--	代理人直接申請フラグ名称
	gSQL := gSQL || '		B01.FINANCIAL_SECURITIES_KBN || B01.BANK_CD AS HKUK_KAISHA_CD,';	-- 引受会社コード
	gSQL := gSQL || '		M08.BIC_CD_NOSHITEN,';												-- ＢＩＣコード(支店コードなし)
	gSQL := gSQL || '		M021.BANK_RNM AS HKUK_KAISHA_NM,';									-- 引受会社名称
	gSQL := gSQL || '		B01.SSI_MUKO_FLG_CD,';												-- ＳＳＩ無効化フラグコード
	gSQL := gSQL || '		CASE WHEN B01.SSI_MUKO_FLG_CD = ''Y'' THEN ''' || SSI_MUKO_FLG_Y || ''' ';
	gSQL := gSQL || '			WHEN B01.SSI_MUKO_FLG_CD = ''N'' THEN ''' || SSI_MUKO_FLG_N || ''' END AS SSI_MUKO_FLG_NM,';			-- ＳＳＩ無効化フラグコード名称
	gSQL := gSQL || '		MG1.HAKKO_TSUKA_CD,';												-- 発行通貨
	gSQL := gSQL || '		MG1.RBR_TSUKA_CD,';													-- 利払通貨コード
	gSQL := gSQL || '		MG1.SHOKAN_TSUKA_CD,';												-- 償還通貨コード
	gSQL := gSQL || '		B01.HKUK_KNGK,';													-- 引受金額
	gSQL := gSQL || '		MG1.HAKKO_KAGAKU,';													-- 発行価額
	gSQL := gSQL || '		B01.YAKUJO_KNGK,';													-- 約定金額
	gSQL := gSQL || '		B01.KOKUNAI_TESU_KNGK,';											-- 国内手数料金額
	gSQL := gSQL || '		B01.KOKUNAI_TESU_SZEI_KNGK,';										-- 国内手数料消費税金額
	gSQL := gSQL || '		B01.KESSAI_KNGK,';													-- 決済金額
	gSQL := gSQL || '		B01.AITE_KKMEMBER_FS_KBN,';											-- 金融証券区分(相手方機構加入者)
	gSQL := gSQL || '		B01.AITE_KKMEMBER_BCD,';											-- 金融機関コード(相手方機構加入者)
	gSQL := gSQL || '		B01.AITE_KKMEMBER_KKBN,';											-- 口座区分(相手方機構加入者)
	gSQL := gSQL || '		B01.SHANAI_KOMOKU,';												-- 社内処理用項目
	gSQL := gSQL || '		B01.MESSAGE1,';														-- メッセージ１
	gSQL := gSQL || '		B01.MESSAGE2,';														-- メッセージ２
	gSQL := gSQL || '		B01.SKN_KESSAI_METHOD_CD_KYOTSU,';									-- 資金決済方法コード(共通)
	gSQL := gSQL || '		B01.SKN_SHRNIN_FS_KBN,';											-- 金融証券区分(資金支払人)
	gSQL := gSQL || '		B01.SKN_SHRNIN_BCD,';												-- 金融機関コード(資金支払人)
	gSQL := gSQL || '		B01.SKN_SHRNIN_SCD,';												-- 支店コード(資金支払人)
	gSQL := gSQL || '		B01.UKE_KOZA_FS_KBN,';												-- 金融証券区分(受方口座所在)
	gSQL := gSQL || '		B01.UKE_KOZA_BCD,';													-- 金融機関コード(受方口座所在)
	gSQL := gSQL || '		B01.UKE_KOZA_SCD,';													-- 支店コード(受方口座所在)
	gSQL := gSQL || '		B01.UKE_KOZA_KAMOKU,';												-- 口座科目(受方)
	gSQL := gSQL || '		B01.UKE_KOZA_NO ';													-- 口座番号(受方)
	gSQL := gSQL || 'FROM	SHINKIBOSHU B01,';													-- 新規募集情報
	gSQL := gSQL || '		MGR_KIHON MG1,';													-- 銘柄_基本
	gSQL := gSQL || '		VJIKO_ITAKU VJI,';													-- 自行・委託会社VIEW
	gSQL := gSQL || '		MBANK_ZOKUSEI M08,';
	gSQL := gSQL || '		MBANK M021,';														-- 金融機関マスタ
	gSQL := gSQL || '		SCODE MCD1 ';														-- コードマスタ
	gSQL := gSQL || 'WHERE 	B01.ITAKU_KAISHA_CD = ''' || p_l_inItakuKaishaCd || ''' ';
	IF (trim(both p_l_inMgrCd) IS NOT NULL AND (trim(both p_l_inMgrCd))::text <> '') THEN
		gSQL := gSQL || 'AND 	B01.MGR_CD = ''' || p_l_inMgrCd || ''' ';
	END IF;
	IF (trim(both p_l_inMgrMeisaiNo) IS NOT NULL AND (trim(both p_l_inMgrMeisaiNo))::text <> '') THEN
		gSQL := gSQL || 'AND 	B01.MGR_MEISAI_NO = ''' || p_l_inMgrMeisaiNo || ''' ';
	END IF;
	gSQL := gSQL || 'AND 	VJI.KAIIN_ID = B01.ITAKU_KAISHA_CD ';
	gSQL := gSQL || 'AND 	B01.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD ';
	gSQL := gSQL || 'AND 	B01.MGR_CD = MG1.MGR_CD ';
	gSQL := gSQL || 'AND 	B01.ITAKU_KAISHA_CD = M08.ITAKU_KAISHA_CD ';
	gSQL := gSQL || 'AND 	B01.FINANCIAL_SECURITIES_KBN = M08.FINANCIAL_SECURITIES_KBN ';
	gSQL := gSQL || 'AND 	B01.BANK_CD = M08.BANK_CD ';
	gSQL := gSQL || 'AND 	B01.FINANCIAL_SECURITIES_KBN = M021.FINANCIAL_SECURITIES_KBN ';
	gSQL := gSQL || 'AND 	B01.BANK_CD = M021.BANK_CD ';
	gSQL := gSQL || 'AND 	B01.DAIRI_MOTION_FLG = MCD1.CODE_VALUE ';
	gSQL := gSQL || 'AND 	MCD1.CODE_SHUBETSU = ''133'' ';
	gSQL := gSQL || 'ORDER BY	B01.MGR_CD,';
	gSQL := gSQL || '			B01.MGR_MEISAI_NO';
	
	RETURN gSQL;
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE NOTICE 'Error in createSQL: % (%)', SQLERRM, SQLSTATE;
		RETURN NULL;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spipf008k00r01_createsql (TEXT, TEXT, varchar, varchar, varchar) FROM PUBLIC;