




CREATE OR REPLACE PROCEDURE spiph008k00r01 ( 
 l_inUserId text, -- ユーザーID
 l_inItakuKaishaCd TEXT,     -- 委託会社コード
 l_inKijunYmdFrom TEXT,     -- 基準日(FROM)
 l_inKijunYmdTo TEXT,     -- 基準日(TO)
 l_inHktCd TEXT,     -- 発行体コード
 l_inKozaTenCd TEXT,     -- 口座店コード
 l_inKozaTenCifcd TEXT,     -- 口座店CIFコード
 l_inMgrCd TEXT,     -- 銘柄コード
 l_inIsinCd TEXT,     -- ISINコード
 l_inTsuchiYmd TEXT,     -- 通知日
 l_inChohyoSakuKbn TEXT,     -- 帳票作成区分
 l_inChohyoKbn TEXT,     -- 帳票区分
 l_inGyomuYmd TEXT,     -- 業務日付
 l_outSqlCode OUT integer,   -- リターン値
 l_outSqlErrM OUT text       -- エラーコメント
 ) AS $body$
DECLARE

--
--/* 著作権:Copyright(c)2006
--/* 会社名:JIP
--/* 概要　:
--/*        公社債元利金支払基金請求書（会計区分別合算表示）を作成する。
--/* 引数　:	l_inChohyoSakuKbn	IN	TEXT		帳票作成区分
--/*			l_inHktCd			IN	TEXT		発行体コード/
--/*			l_inMgrCd			IN	TEXT		銘柄コード
--/*			l_inKijunYmdFrom	IN	TEXT		基準日(FROM)
--/*			l_inKijunYmdTo		IN	TEXT		基準日(TO)
--/*			l_inTsuchiYmd		IN	TEXT		通知日
--/*			l_inItakuKaishaCd	IN	TEXT		委託会社コード
--/*			l_inUserId			IN	TEXT		ユーザーID
--/*			l_inChohyoKbn		IN	TEXT		帳票区分
--/*			l_inGyomuYmd		IN	TEXT		業務日付
--/*			l_outSqlCode		OUT	INTEGER		リターン値
--/*			l_outSqlErrM		OUT	VARCHAR	エラーコメント
--/* 返り値:なし
--/*
--/* @version $Id: SPIPH008K00R01.sql,v 1.14 2023/07/25 05:57:03 kentaro_ikeda Exp $
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.05.XX	JIP				新規作成
--/*
--/*
--***************************************************************************
--
--==============================================================================
--					デバッグ機能													
--==============================================================================
	DEBUG	numeric(1)	:= 0;
--==============================================================================
--					定数定義													
--==============================================================================
	RTN_NODATA          integer    := 2;				-- データなし
	REPORT_ID           char(11)   := 'IPH30000811';          -- 帳票ID
	-- 書式フォーマット
	FMT_HAKKO_KNGK_J    char(18)   := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';    -- 円貨
	FMT_HAKKO_KNGK_F    char(21)   := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99'; -- 外貨
	TITLE_SEIKYUSHO     char(26)   := '公社債元利金支払基金請求書';
	TITLE_SEIKYUHKE     char(30)   := '公社債元利金支払基金請求書(控)';
--==============================================================================
--					変数定義													
--==============================================================================
	gRtnCd              integer := 0;              -- リターンコード
	gSeqNo              integer := 0;              -- シーケンス
	TITLE_OUTPUT        varchar(30) := NULL;  -- 帳票タイトル
	hakkoTsukaCdFmt     varchar(21) := NULL;  -- 金額フォーマット
	-- 西暦変換用
	gWrkStTuchiYmd      varchar(20) := NULL;  -- 通知日
	gWrkStNyukinYmd     varchar(20) := NULL;  -- ご入金日
--	gEditZandakaYm      VARCHAR(20) DEFAULT NULL;  -- 残高基準日
	gAdd1x1             varchar(50) := ' ';
	gAdd1x2             varchar(50) := ' ';
	gAdd1x3             varchar(50) := ' ';
	gBankNm             varchar(40) := ' ';
	gYakushokuNm1       varchar(60) := ' ';
	gDelegateNm1        varchar(60) := ' ';
	-- 宛名編集用
--	gTokiDelegateNm     VARCHAR(100) DEFAULT NULL;             -- 登記上代表者名称
	-- 口座情報編集
--	gYmdTitle           VARCHAR(16) DEFAULT NULL;              -- 日付タイトル
	gKozaTenTitle       varchar(16) := NULL;              -- 口座店タイトル
	gKozaTenKamokuTitle varchar(16) := NULL;              -- 口座店預金種目タイトル
	gKozaNoTitle        varchar(16) := NULL;              -- 口座番号タイトル
	gKozaTenNm          varchar(100) := NULL;             -- 口座店名称
	-- 地公体請求書顧客口座出力フラグ(自行情報マスタ)
	gChikokozaPrintFlg  char(1);
	gKozaPrintFlg  char(1);
	-- 合計集計項目
	gSeikyuTotal        numeric(16) := 0;                   -- 請求額合計
	-- 画面任意指定抽出条件項目
	gKijunYmdFrom       char(8) := NULL;
	gKijunYmdTo         char(8) := NULL;
	gHktCd              char(6) := NULL;
	gKozaTenCd          char(4) := NULL;
	gKozaTenCifcd       char(7) := NULL;
	gMgrCd              char(13) := NULL;
	gIsinCd             char(12) := NULL;
	-- 改ページ条件退避用項目
	wItakuKaishaCd      char(4) := ' ';
	wHktCd              char(6) := ' ';
	wTsukaCd            char(3) := ' ';
	wChokyuYmd          char(8) := ' ';
	wKaikeiKbn          char(2) := ' ';
	wKozaFuriKbn        char(1) := ' ';
	-- 処理制御値
	gresult varchar(200) := NULL;
	-- インボイス用
	gAryBun					pkIpaBun.BUN_ARRAY;						-- インボイス文章(請求書)配列
	gInvoiceBun				text;					-- インボイス文章
	gInvoiceTourokuNo		varchar(14);	-- 適格請求書発行事業者登録番号
	gInvoiceKknTesuLabel	varchar(20);							-- 基金および手数料ラベル
	gInvoiceTesuLabel		varchar(20);							-- 手数料ラベル
	gWrkHikazeiFlg			varchar(200);			-- 非課税免税フラグ
	gWrkHikazeiNm			SCODE.CODE_NM%TYPE;						-- 非課税免税名称
	gInvoiceKknTesuKngkSum	numeric(16) := 0;					-- 適格請求書_基金および手数料合計
	gInvoiceTesuKngkSum		numeric(16) := 0;					-- 適格請求書_手数料合計
	gInvoiceUchiSzei		numeric(16) := 0;					-- 適格請求書_内消費税
	gSzeiRate				numeric(2);								-- 適格請求書_消費税率
	gSzeiKijunYmd			char(8);								-- 適格請求書_消費税基準日
	gTokiDelegateNm			varchar(100) := NULL;				-- 登記上代表者名称(ジャーナル用)
--==============================================================================
--					カーソル定義												
--==============================================================================
	mainCur CURSOR FOR
		SELECT
			H05SUM.ITAKU_KAISHA_CD,
			H05SUM.CHOKYU_YMD,
			H05SUM.KAIKEI_KBN,
			KAIKEI_KBN_RNM AS KAIKEI_KBN_NM,
			INPUT_NUM,
			H05SUM.HKT_CD,
			M01.TOKIJO_YAKUSHOKU_NM,
			M01.TOKIJO_DELEGATE_NM,
			H05SUM.TSUKA_CD,
			(SELECT TSUKA_NM FROM MTSUKA WHERE TSUKA_CD = H05SUM.TSUKA_CD) AS TSUKA_NM,
			H05SUM.ISIN_CD,
			VMG1.MGR_RNM,
			MG8.SZEI_SEIKYU_KBN,
			H05SUM.GNR_YMD,
			H05SUM.GNRBARAI_KJT,
			H05SUM.KOZA_FURI_KBN,
			(SELECT BUTEN_NM FROM MBUTEN WHERE BUTEN_CD = H05SUM.KOZA_TEN_CD) AS KOZA_TEN_NM,
			(SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '707' AND CODE_VALUE = H05SUM.KOZA_KAMOKU) AS KOZA_KAMOKU,
			H05SUM.KOZA_NO,
			H05SUM.KOZAMEIGININ_NM,
			H05SUM.GANKIN,
			H05SUM.GNKN_SHR_TESU_KNGK,
			H05SUM.RKN,
			H05SUM.RKN_SHR_TESU_KNGK,
			H05SUM.GNT_GNKN,
			H05SUM.GNT_GNKN_SHR_TESU_KNGK,
			H05SUM.GNT_RKN,
			H05SUM.GNT_RKN_SHR_TESU_KNGK,
			H05SUM.SEIKYU_KNGK,
			H05SUM.SZEI_KNGK
		FROM
			MGR_KIHON_VIEW      VMG1,
			MHAKKOTAI           M01,
			MGR_TESURYO_PRM     MG8,
			
			(SELECT H05.ITAKU_KAISHA_CD,
				H05.HKT_CD,
				H05.TSUKA_CD,
				H05.CHOKYU_YMD,
				H05.ISIN_CD,
				H05.KAIKEI_KBN,
				H01.KAIKEI_KBN_RNM,
				H01.INPUT_NUM,
				H05.GNR_YMD,
				H05.GNRBARAI_KJT,
				H05.KOZA_FURI_KBN,
				H05.KOZA_TEN_CD,
				H05.KOZA_KAMOKU,
				H05.KOZA_NO,
				H05.KOZAMEIGININ_NM,
				SUM(H05.GANKIN) AS GANKIN,
				SUM(H05.GNKN_SHR_TESU_KNGK) AS GNKN_SHR_TESU_KNGK,
				SUM(H05.RKN) AS RKN,
				SUM(H05.RKN_SHR_TESU_KNGK) AS RKN_SHR_TESU_KNGK,
				SUM(H05.GNT_GNKN) AS GNT_GNKN,
				SUM(H05.GNT_GNKN_SHR_TESU_KNGK) AS GNT_GNKN_SHR_TESU_KNGK,
				SUM(H05.GNT_RKN) AS GNT_RKN,
				SUM(H05.GNT_RKN_SHR_TESU_KNGK) AS GNT_RKN_SHR_TESU_KNGK,
				SUM(H05.SEIKYU_KNGK) AS SEIKYU_KNGK,
				SUM(H05.SZEI_KNGK) AS SZEI_KNGK
			FROM KIKIN_SEIKYU_KAIKEI H05
				,MGR_KIHON_VIEW			VMG1
				,KAIKEI_KBN				H01
			WHERE
				H05.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
			AND	H05.ISIN_CD = VMG1.ISIN_CD
			AND H05.ITAKU_KAISHA_CD = H01.ITAKU_KAISHA_CD
			AND H05.HKT_CD = H01.HKT_CD
			AND H05.KAIKEI_KBN = H01.KAIKEI_KBN
			AND VMG1.MGR_STAT_KBN = '1'
			AND (H05.HKT_CD = gHktCd OR coalesce(gHktCd::text, '') = '')
			AND (H05.KOZA_TEN_CD = gKozaTenCd OR coalesce(gKozaTenCd::text, '') = '')
			AND (H05.KOZA_TEN_CIFCD = gKozaTenCifcd OR coalesce(gKozaTenCifcd::text, '') = '')
			AND (H05.ISIN_CD = gIsinCd OR coalesce(gIsinCd::text, '') = '')
			AND H05.CHOKYU_YMD BETWEEN gKijunYmdFrom AND gKijunYmdTo
			AND H05.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND H05.KOUSAIHI_FLG != CASE WHEN gresult='1' THEN  '1'  ELSE '9' END
			-- 会計按分テーブルの承認済み銘柄のみ抽出対象にする
			AND PKIPAKKNIDO.GETKAIKEIANBUNCOUNT(VMG1.ITAKU_KAISHA_CD , VMG1.MGR_CD) > 0
			-- 画面より発行体コードが指定されたとき
 
			GROUP BY H05.ITAKU_KAISHA_CD,
					H05.HKT_CD,
					H05.TSUKA_CD,
					H05.CHOKYU_YMD,
					H05.ISIN_CD,
					H05.KAIKEI_KBN,
					H01.KAIKEI_KBN_RNM,
					H01.INPUT_NUM,
					H05.GNR_YMD,
					H05.GNRBARAI_KJT,
					H05.KOZA_FURI_KBN,
					H05.KOZA_TEN_CD,
					H05.KOZA_KAMOKU,
					H05.KOZA_NO,
					H05.KOZAMEIGININ_NM
			
UNION ALL

			-- 公債費特別会計のデータは会計区分に関わらず、合算で表示するため別集計
			SELECT H05.ITAKU_KAISHA_CD,
				H05.HKT_CD,
				H05.TSUKA_CD,
				H05.CHOKYU_YMD,
				H05.ISIN_CD,
				'00' AS KAIKEI_KBN,
				'公債費特別会計',
				0 INPUT_NUM,
				H05.GNR_YMD,
				H05.GNRBARAI_KJT,
				H05.KOZA_FURI_KBN,
				H05.KOZA_TEN_CD,
				H05.KOZA_KAMOKU,
				H05.KOZA_NO,
				H05.KOZAMEIGININ_NM,
				SUM(H05.GANKIN) AS GANKIN,
				SUM(H05.GNKN_SHR_TESU_KNGK) AS GNKN_SHR_TESU_KNGK,
				SUM(H05.RKN) AS RKN,
				SUM(H05.RKN_SHR_TESU_KNGK) AS RKN_SHR_TESU_KNGK,
				SUM(H05.GNT_GNKN) AS GNT_GNKN,
				SUM(H05.GNT_GNKN_SHR_TESU_KNGK) AS GNT_GNKN_SHR_TESU_KNGK,
				SUM(H05.GNT_RKN) AS GNT_RKN,
				SUM(H05.GNT_RKN_SHR_TESU_KNGK) AS GNT_RKN_SHR_TESU_KNGK,
				SUM(H05.SEIKYU_KNGK) AS SEIKYU_KNGK,
				SUM(H05.SZEI_KNGK) AS SZEI_KNGK
			FROM KIKIN_SEIKYU_KAIKEI	H05
				,MGR_KIHON_VIEW			VMG1
			WHERE
				H05.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
			AND	H05.ISIN_CD = VMG1.ISIN_CD
			AND VMG1.MGR_STAT_KBN = '1'
			AND (H05.HKT_CD = gHktCd OR coalesce(gHktCd::text, '') = '')
			AND (H05.KOZA_TEN_CD = gKozaTenCd OR coalesce(gKozaTenCd::text, '') = '')
			AND (H05.KOZA_TEN_CIFCD = gKozaTenCifcd OR coalesce(gKozaTenCifcd::text, '') = '')
			AND (H05.ISIN_CD = gIsinCd OR coalesce(gIsinCd::text, '') = '')
			AND H05.CHOKYU_YMD BETWEEN gKijunYmdFrom AND gKijunYmdTo
			AND H05.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND H05.KOUSAIHI_FLG = CASE WHEN gresult='1' THEN  '1'  ELSE '9' END 
			-- 会計按分テーブルの承認済み銘柄のみ抽出対象にする
			AND PKIPAKKNIDO.GETKAIKEIANBUNCOUNT(VMG1.ITAKU_KAISHA_CD , VMG1.MGR_CD) > 0 
			GROUP BY
					H05.ITAKU_KAISHA_CD,
					H05.HKT_CD,
					H05.TSUKA_CD,
					H05.CHOKYU_YMD,
					H05.ISIN_CD,
					H05.GNR_YMD,
					H05.GNRBARAI_KJT,
					H05.KOZA_FURI_KBN,
					H05.KOZA_TEN_CD,
					H05.KOZA_KAMOKU,
					H05.KOZA_NO,
					H05.KOZAMEIGININ_NM) H05SUM
		WHERE (VMG1.MGR_CD = gMgrCd OR coalesce(gMgrCd::text, '') = '')
		AND H05SUM.ISIN_CD = VMG1.ISIN_CD
		AND H05SUM.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
		AND H05SUM.HKT_CD = M01.HKT_CD
		AND H05SUM.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		AND VMG1.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG8.MGR_CD 
		ORDER BY
			H05SUM.TSUKA_CD,
			H05SUM.CHOKYU_YMD,
			H05SUM.HKT_CD,
			H05SUM.INPUT_NUM,
			H05SUM.KOZA_FURI_KBN,
			H05SUM.ISIN_CD,
			H05SUM.GNR_YMD;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPH008K00R01 START');	END IF;
	-- 入力パラメータのチェック 必須項目チェック
	IF (coalesce(trim(both l_inKijunYmdFrom)::text, '') = '' -- 基準日(FROM)
	AND coalesce(trim(both l_inKijunYmdTo)::text, '') = '')  -- 基準日(TO)
	OR coalesce(trim(both l_inChohyoSakuKbn)::text, '') = '' -- 帳票作成区分
	OR coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' -- 委託会社コード
	OR coalesce(trim(both l_inUserId)::text, '') = ''        -- ユーザID
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''     -- 帳票区分
	OR coalesce(trim(both l_inGyomuYmd)::text, '') = ''      -- 業務日付
	THEN
		-- 必須入力エラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '';
		CALL pkLog.error(l_inUserId, REPORT_ID, 'SQLERRM:'||'');
		RETURN;
	END IF;
	-- 画面指定基準日のFromのみ入力の場合ToにはALL9をセット
	-- Toのみ入力の場合はFromにALL0をセットする
	IF coalesce(trim(both l_inKijunYmdFrom)::text, '') = '' THEN
		gKijunYmdFrom := '00000000';
	ELSE
		gKijunYmdFrom := l_inKijunYmdFrom;
	END IF;
	IF coalesce(trim(both l_inKijunYmdTo)::text, '') = '' THEN
		gKijunYmdTo := '99999999';
	ELSE
		gKijunYmdTo := l_inKijunYmdTo;
	END IF;
	-- 任意項目のパラメータセット
	CALL spiph008k00r01_setparameter(l_inHktCd, l_inKozaTenCd, l_inKozaTenCifcd, l_inMgrCd, l_inIsinCd, gHktCd, gKozaTenCd, gKozaTenCifcd, gMgrCd, gIsinCd);
	-- インボイス用変数の初期化
	gInvoiceBun := NULL;
	gInvoiceTourokuNo := NULL;
	gInvoiceKknTesuLabel := NULL;	-- 基金および手数料ラベル
	gInvoiceTesuLabel := NULL;		-- 手数料ラベル
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE KEY_CD = l_inItakuKaishaCd
	AND USER_ID = l_inUserId
	AND CHOHYO_KBN = l_inChohyoKbn
	AND SAKUSEI_YMD = l_inGyomuYmd
	AND CHOHYO_ID = REPORT_ID;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	-- 地公体請求書顧客口座出力フラグ(自行情報マスタ)を取得する。
	SELECT CHIKOKOZA_PRINT_FLG
	INTO STRICT gChikokozaPrintFlg
	FROM VJIKO_ITAKU
	WHERE KAIIN_ID = l_inItakuKaishaCd;
	-- 自行情報をセットする
	CALL spiph008k00r01_setowninfo(gAdd1x1, gAdd1x2, gAdd1x3, gBankNm, gYakushokuNm1, gDelegateNm1, gInvoiceTourokuNo);
	-- 通知日編集（西暦変換）
	gWrkStTuchiYmd := '      年  月  日';
	-- 随時のときは画面入力された通知日を出力、バッチのときは業務日付の翌営業日を出力する
	IF l_inChohyoKbn = '0' THEN
		IF (trim(both l_inTsuchiYmd) IS NOT NULL AND (trim(both l_inTsuchiYmd))::text <> '') THEN
			gWrkStTuchiYmd := pkDate.seirekiChangeSuppressNenGappi(l_inTsuchiYmd);
		END IF;
	ELSE
		IF (trim(both l_inGyomuYmd) IS NOT NULL AND (trim(both l_inGyomuYmd))::text <> '') THEN
			gWrkStTuchiYmd := pkDate.getYokuBusinessYmd(l_inGyomuYmd);
			gWrkStTuchiYmd := pkDate.seirekiChangeSuppressNenGappi(gWrkStTuchiYmd);
		END IF;
	END IF;
	-- 処理制御値取得
	gresult := pkControl.getCtlValue( l_inItakuKaishaCd, 'ChikoList', '0');
	-- 基金および手数料ラベルの編集
	gWrkHikazeiFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'INVOICE_ZeiNm', '0');
	SELECT CODE_NM
	INTO STRICT gWrkHikazeiNm
	FROM SCODE
	WHERE CODE_SHUBETSU = '246'
	AND CODE_VALUE = gWrkHikazeiFlg;
	gInvoiceKknTesuLabel := '（' || gWrkHikazeiNm || '）';
	-- インボイス文章取得
	gAryBun := pkIpaBun.getBun(REPORT_ID, 'L0');
	FOR i IN 0..coalesce(cardinality(gAryBun), 0) - 1 LOOP
		IF i = 0 THEN
			gInvoiceBun := gAryBun[i];
		END IF;
	END LOOP;
	-- １回目のループは請求書を出力するためのもの。
	-- ２回目のループは控を出力するためのものとする
	FOR i IN 0..1 LOOP
		IF i = 0 THEN
			TITLE_OUTPUT := TITLE_SEIKYUSHO;
		ELSE
			TITLE_OUTPUT := TITLE_SEIKYUHKE;
		END IF;
		-- 合計値をクリア
		gSeikyuTotal := 0;
		gInvoiceKknTesuKngkSum	:= 0;		-- 適格請求書_基金および手数料合計
		gInvoiceTesuKngkSum		:= 0;		-- 適格請求書_手数料合計
		gSzeiKijunYmd := NULL;
		FOR rec IN mainCur LOOP
			gSeqNo := gSeqNo + 1;
			-- 改ページが発生したら合計値をクリアする
			IF wItakuKaishaCd = rec.ITAKU_KAISHA_CD
				AND wHktCd = rec.HKT_CD
				AND wTsukaCd = rec.TSUKA_CD
				AND wChokyuYmd = rec.CHOKYU_YMD
				AND wKozaFuriKbn = rec.KOZA_FURI_KBN
				AND wKaikeiKbn = rec.KAIKEI_KBN THEN
				-- 改ページでない時の処理 
				-- 合計値を足し込み
				gSeikyuTotal := gSeikyuTotal + rec.SEIKYU_KNGK;
				-- 適格請求書の合計を集計
				-- 元金・利金を非課税分合計に集計
				gInvoiceKknTesuKngkSum := gInvoiceKknTesuKngkSum + rec.GANKIN + rec.RKN + rec.GNT_GNKN + rec.GNT_RKN;
				-- 手数料を集計
				IF rec.SZEI_SEIKYU_KBN = '1' THEN
					-- 消費税請求区分：請求する の場合、課税分合計に集計
					gInvoiceTesuKngkSum := gInvoiceTesuKngkSum
											+ rec.GNKN_SHR_TESU_KNGK + rec.RKN_SHR_TESU_KNGK
											+ rec.GNT_GNKN_SHR_TESU_KNGK + rec.GNT_RKN_SHR_TESU_KNGK;
				ELSE
					-- 消費税請求区分：請求しない の場合、非課税分合計に集計
					gInvoiceKknTesuKngkSum := gInvoiceKknTesuKngkSum
											+ rec.GNKN_SHR_TESU_KNGK + rec.RKN_SHR_TESU_KNGK
											+ rec.GNT_GNKN_SHR_TESU_KNGK + rec.GNT_RKN_SHR_TESU_KNGK;
				END IF;
			ELSE
				-- 改ページ時の処理 
				-- カーソルの1件目（消費税基準日：NULL）の時は実施されない
				-- 現在レコード（新しいページ）の処理前に、前ページレコードのインボイス用項目を算出して更新する
				CALL spiph008k00r01_updateinvoiceitem(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID, TITLE_OUTPUT, gWrkStNyukinYmd, gSzeiKijunYmd, gRtnCd, gSzeiRate, gInvoiceTesuLabel, gInvoiceTesuKngkSum, gInvoiceUchiSzei, gSeikyuTotal, gInvoiceKknTesuKngkSum, wTsukaCd, wHktCd, wKaikeiKbn, wKozaFuriKbn);
				IF gRtnCd <> pkconstant.success() THEN
					l_outSqlCode := gRtnCd;
					RETURN;
				END IF;
				-- 現在レコードの処理を再開 
				-- 合計値をクリアして足し込み
				gSeikyuTotal := rec.SEIKYU_KNGK;
				-- 適格請求書の合計を集計
				-- 元金・利金を非課税分合計に集計
				gInvoiceKknTesuKngkSum := rec.GANKIN + rec.RKN + rec.GNT_GNKN + rec.GNT_RKN;
				-- 手数料を集計
				IF rec.SZEI_SEIKYU_KBN = '1' THEN
					-- 消費税請求区分：請求する の場合、課税分合計に集計
					gInvoiceTesuKngkSum := rec.GNKN_SHR_TESU_KNGK + rec.RKN_SHR_TESU_KNGK
											+ rec.GNT_GNKN_SHR_TESU_KNGK + rec.GNT_RKN_SHR_TESU_KNGK;
				ELSE
					-- 消費税請求区分：請求しない の場合、非課税分合計に集計
					gInvoiceKknTesuKngkSum := rec.GNKN_SHR_TESU_KNGK + rec.RKN_SHR_TESU_KNGK
											+ rec.GNT_GNKN_SHR_TESU_KNGK + rec.GNT_RKN_SHR_TESU_KNGK;
				END IF;
			END IF;
			-- ご入金日和暦変換
			IF (trim(both rec.CHOKYU_YMD) IS NOT NULL AND (trim(both rec.CHOKYU_YMD))::text <> '') THEN
				gWrkStNyukinYmd := pkDate.seirekiChangeSuppressNenGappi(rec.CHOKYU_YMD);
			END IF;
			--地公体請求書顧客口座出力フラグがたっている場には口座情報をセットする 以外は口座情報は表示しない
			IF gChikokozaPrintFlg = 1 THEN
				-- 口座店名称の編集
				gRtnCd := pkIpaName.getKozaTenNm(gBankNm, rec.KOZA_TEN_NM, gKozaTenNm);
				IF gRtnCd <> pkconstant.success() THEN
					l_outSqlCode := gRtnCd;
					RETURN;
				END IF;
					gKozaTenTitle		:= '口座店';
					gKozaTenKamokuTitle	:= '預金種目';
					gKozaNoTitle		:= '口座番号';
			END IF;
			-- 金額フォーマット編集
			IF rec.TSUKA_CD = 'JPY' THEN
				hakkoTsukaCdFmt := FMT_HAKKO_KNGK_J;
			ELSE
				hakkoTsukaCdFmt := FMT_HAKKO_KNGK_F;
			END IF;
			-- 口座出力フラグをセット(現金受取の場合はセットしない)
			IF rec.KOZA_FURI_KBN = '50' THEN
				gKozaPrintFlg := '0';
			ELSE
				gKozaPrintFlg := gChikokozaPrintFlg;
			END IF;
			-- 登記上代表者名称(ジャーナル)の編集
			gTokiDelegateNm := NULL;
			IF (trim(both rec.TOKIJO_DELEGATE_NM) IS NOT NULL AND (trim(both rec.TOKIJO_DELEGATE_NM))::text <> '') THEN
				gTokiDelegateNm := rec.TOKIJO_DELEGATE_NM || '　殿';
			END IF;
				-- 請求書データのINSERT
				CALL pkPrint.insertData(
					l_inKeyCd       => l_inItakuKaishaCd           -- 識別コード
					,l_inUserId     => l_inUserId                  -- ユーザＩＤ
					,l_inChohyoKbn  => l_inChohyoKbn               -- 帳票区分
					,l_inSakuseiYmd => l_inGyomuYmd                -- 作成年月日
					,l_inChohyoId   => REPORT_ID                   -- 帳票ＩＤ
					,l_inSeqNo      => gSeqNo                      -- 連番
					,l_inHeaderFlg  => '1'                        -- ヘッダフラグ
					,l_inItem001	=> TITLE_OUTPUT                -- 帳票タイトル：請求書
					,l_inItem002	=> gWrkStNyukinYmd             -- ご入金日
					,l_inItem003	=> gWrkStTuchiYmd              -- 通知日
					,l_inItem004	=> rec.KAIKEI_KBN              -- 会計区分
					,l_inItem005	=> rec.KAIKEI_KBN_NM           -- 会計区分名称
					,l_inItem006	=> rec.HKT_CD                  -- 発行体コード
					,l_inItem007	=> rec.TOKIJO_YAKUSHOKU_NM     -- 登記上役職名称
					,l_inItem008	=> rec.TOKIJO_DELEGATE_NM      -- 登記上代表者名称
					,l_inItem009	=> gAdd1x1                    -- 住所２−１
					,l_inItem010	=> gAdd1x2                    -- 住所２−２
					,l_inItem011	=> gAdd1x3                    -- 住所２−３
					,l_inItem012	=> gBankNm                     -- 銀行名称
					,l_inItem013	=> gYakushokuNm1 || '　' || gDelegateNm1     -- 代表者名称（役職名称１+'△'+代表者名称１）
					,l_inItem014	=> rec.TSUKA_CD                -- 通貨コード
					,l_inItem015	=> rec.TSUKA_NM                -- 通貨名称
					,l_inItem016	=> gKozaPrintFlg               -- 地公体請求書顧客口座出力フラグ
					,l_inItem017	=> gKozaTenTitle               -- 口座店タイトル
					,l_inItem018	=> gKozaTenNm                  -- 口座店名称
					,l_inItem019	=> gKozaTenKamokuTitle         -- 口座科目タイトル
					,l_inItem020	=> gKozaNoTitle                -- 口座番号タイトル
					,l_inItem021	=> rec.KOZA_NO                 -- 口座番号
					,l_inItem022	=> rec.KOZA_KAMOKU             -- 口座科目名称
					,l_inItem023	=> rec.ISIN_CD                 -- ISINコード
					,l_inItem024	=> rec.MGR_RNM                 -- 銘柄略称
					,l_inItem025	=> rec.GNR_YMD                 -- 元利払日
					,l_inItem026	=> rec.GNRBARAI_KJT            -- 元利払期日
					,l_inItem027	=> rec.GANKIN                  -- 元金
					,l_inItem028	=> rec.GNKN_SHR_TESU_KNGK      -- 元金支払手数料金額
					,l_inItem029	=> rec.RKN                     -- 利金
					,l_inItem030	=> rec.RKN_SHR_TESU_KNGK       -- 利金支払手数料
					,l_inItem031	=> rec.GNT_GNKN                -- 現登債元金
					,l_inItem032	=> rec.GNT_GNKN_SHR_TESU_KNGK  -- 現登債元金支払手数料金額
					,l_inItem033	=> rec.GNT_RKN                 -- 現登債利金
					,l_inItem034	=> rec.GNT_RKN_SHR_TESU_KNGK   -- 現登債利金支払手数料金額
					,l_inItem035	=> rec.SEIKYU_KNGK             -- 請求金額
					,l_inItem036	=> rec.SZEI_KNGK               -- 内消費税
					,l_inItem037	=> gSeikyuTotal                -- 請求金額合計
					,l_inItem038	=> gInvoiceTourokuNo           -- 適格請求書発行事業者登録番号 
					,l_inItem039	=> hakkoTsukaCdFmt             -- 発行金額書式フォーマット
					,l_inItem040	=>  ' '
					,l_inItem041	=> rec.KOZA_FURI_KBN 		  -- 口座振替区分
					,l_inItem042	=> gInvoiceKknTesuLabel 			-- 適格請求書_基金および手数料ラベル
					,l_inItem050	=> gInvoiceBun 					-- インボイス文章
					,l_inItem051	=> rec.TOKIJO_YAKUSHOKU_NM 		-- 登記上役職名称(ジャーナル)
					,l_inItem052	=> gTokiDelegateNm 				-- 登記上代表者名称(ジャーナル)
					,l_inKousinId	=> l_inUserId                  -- 更新者ID
					,l_inSakuseiId	=> l_inUserId                  -- 作成者ID
				);
			-- 改ページ条件の更新・インボイス算出用に退避
			wItakuKaishaCd := rec.ITAKU_KAISHA_CD;
			wHktCd := rec.HKT_CD;
			wTsukaCd := rec.TSUKA_CD;
			wChokyuYmd := rec.CHOKYU_YMD;
			wKaikeiKbn := rec.KAIKEI_KBN;
			wKozaFuriKbn := rec.KOZA_FURI_KBN;
			-- インボイス算出用に退避
			gSzeiKijunYmd := rec.GNR_YMD;
		END LOOP;
		-- 最終ページの処理 
		-- 対象データなしの場合は実行されない
		-- 最終レコードのページのインボイス用項目を算出して更新する
		CALL spiph008k00r01_updateinvoiceitem(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID, TITLE_OUTPUT, gWrkStNyukinYmd, gSzeiKijunYmd, gRtnCd, gSzeiRate, gInvoiceTesuLabel, gInvoiceTesuKngkSum, gInvoiceUchiSzei, gSeikyuTotal, gInvoiceKknTesuKngkSum, wTsukaCd, wHktCd, wKaikeiKbn, wKozaFuriKbn);
		IF gRtnCd <> pkconstant.success() THEN
			l_outSqlCode := gRtnCd;
			RETURN;
		END IF;
	END LOOP;
	--データ取得件数判定
	IF gSeqNo = 0 THEN
		-- 対象データなしの処理
		gRtnCd := RTN_NODATA;
		-- 随時、バッチ判定
		IF l_inChohyoKbn = '0' THEN
			-- 随時の場合のみ、対象データなしデータを帳票ワークへデータへ出力
			CALL pkPrint.insertData(
				l_inKeyCd		=> l_inItakuKaishaCd 	-- 識別コード
				,l_inUserId		=> l_inUserId 			-- ユーザＩＤ
				,l_inChohyoKbn	=> l_inChohyoKbn 		-- 帳票区分
				,l_inSakuseiYmd	=> l_inGyomuYmd 			-- 作成年月日
				,l_inChohyoId	=> REPORT_ID 			-- 帳票ＩＤ
				,l_inSeqNo		=> 1					-- 連番
				,l_inHeaderFlg	=> '1'					-- ヘッダフラグ
				,l_inItem001	=> TITLE_SEIKYUSHO 		-- 帳票タイトル：請求書
				,l_inItem003	=> gWrkStTuchiYmd 		-- 通知日
				,l_inItem039	=> hakkoTsukaCdFmt 		-- 発行金額書式フォーマット
				,l_inItem040	=> '対象データなし'
				,l_inKousinId	=> l_inUserId 			-- 更新者ID
				,l_inSakuseiId	=> l_inUserId 			-- 作成者ID
			);
		END IF;
	ELSE
		-- CSVジャーナルINSERT  
		l_outSqlCode := pkCsvJournal.insertData(
							 l_inItakuKaishaCd 			-- 委託会社コード
							,l_inUserId 					-- ユーザＩＤ
							,l_inChohyoKbn 				-- 帳票区分
							,l_inGyomuYmd 				-- 処理日付
							,REPORT_ID 					-- 帳票ＩＤ
						);
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	--IF DEBUG = 1 THEN	pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gLopNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPH008K00R01 END');	END IF;
	-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLERRM;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spiph008k00r01 ( l_inUserId text, l_inItakuKaishaCd TEXT, l_inKijunYmdFrom TEXT, l_inKijunYmdTo TEXT, l_inHktCd TEXT, l_inKozaTenCd TEXT, l_inKozaTenCifcd TEXT, l_inMgrCd TEXT, l_inIsinCd TEXT, l_inTsuchiYmd TEXT, l_inChohyoSakuKbn TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT TEXT  ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spiph008k00r01_setowninfo ( 
    INOUT gAdd1x1 varchar(50), 
    INOUT gAdd1x2 varchar(50), 
    INOUT gAdd1x3 varchar(50), 
    INOUT gBankNm varchar(40), 
    INOUT gYakushokuNm1 varchar(60), 
    INOUT gDelegateNm1 varchar(60), 
    INOUT gInvoiceTourokuNo varchar(14) 
) AS $body$
BEGIN
	-- 自行情報マスタから宛名部分を取得
	SELECT S1.ADD1X1, S1.ADD1X2, S1.ADD1X3, S1.BANK_NM, S1.YAKUSHOKU_NM1, S1.DELEGATE_NM1, S1.INVOICE_TOUROKU_NO
	INTO STRICT gAdd1x1, gAdd1x2, gAdd1x3, gBankNm, gYakushokuNm1, gDelegateNm1 ,gInvoiceTourokuNo
	FROM SOWN_INFO S1;
EXCEPTION
	WHEN no_data_found THEN
		RETURN;
	WHEN OTHERS THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spiph008k00r01_setowninfo () FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spiph008k00r01_setparameter (
    l_inHktCd TEXT,
    l_inKozaTenCd TEXT,
    l_inKozaTenCifcd TEXT,
    l_inMgrCd TEXT,
    l_inIsinCd TEXT,
    INOUT gHktCd char(6),
    INOUT gKozaTenCd char(4),
    INOUT gKozaTenCifcd char(7),
    INOUT gMgrCd char(13),
    INOUT gIsinCd char(12)
) AS $body$
BEGIN
	IF (trim(both l_inHktCd) IS NOT NULL AND (trim(both l_inHktCd))::text <> '') THEN
		gHktCd := l_inHktCd;
	END IF;
	IF (trim(both l_inKozaTenCd) IS NOT NULL AND (trim(both l_inKozaTenCd))::text <> '') THEN
		gKozaTenCd := l_inKozaTenCd;
	END IF;
	IF (trim(both l_inKozaTenCifcd) IS NOT NULL AND (trim(both l_inKozaTenCifcd))::text <> '') THEN
		gKozaTenCifcd := l_inKozaTenCifcd;
	END IF;
	IF (trim(both l_inMgrCd) IS NOT NULL AND (trim(both l_inMgrCd))::text <> '') THEN
		gMgrCd := l_inMgrCd;
	END IF;
	IF (trim(both l_inIsinCd) IS NOT NULL AND (trim(both l_inIsinCd))::text <> '') THEN
		gIsinCd := l_inIsinCd;
	END IF;
EXCEPTION
	WHEN OTHERS THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spiph008k00r01_setparameter () FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spiph008k00r01_updateinvoiceitem (
    l_inItakuKaishaCd TEXT,
    l_inUserId text,
    l_inChohyoKbn TEXT,
    l_inGyomuYmd TEXT,
    REPORT_ID char(11),
    TITLE_OUTPUT varchar(30),
    gWrkStNyukinYmd varchar(20),
    INOUT gSzeiKijunYmd char(8),
    INOUT gRtnCd integer,
    INOUT gSzeiRate numeric,
    INOUT gInvoiceTesuLabel varchar,
    INOUT gInvoiceTesuKngkSum numeric,
    INOUT gInvoiceUchiSzei numeric,
    INOUT gSeikyuTotal numeric,
    INOUT gInvoiceKknTesuKngkSum numeric,
    wTsukaCd char(3),
    wHktCd char(6),
    wKaikeiKbn char(2),
    wKozaFuriKbn char(1)
) AS $body$
BEGIN
	-- 消費税基準日が未設定（カーソルの1件目または対象データなし）の場合、何もせずに終了
	IF coalesce(trim(both gSzeiKijunYmd)::text, '') = '' THEN
		RETURN;
	END IF;
	gRtnCd := pkconstant.error();
	-- 適格請求書_手数料ラベル編集
	-- 改ページ単位の最終レコードの内容で編集
	gSzeiRate := pkIpaZei.getShohiZeiRate(gSzeiKijunYmd);
	gInvoiceTesuLabel := '（' || substr('　' || oracle.to_multi_byte(gSzeiRate), -2) || '％対象）';
	-- 手数料割戻消費税算出
	IF gInvoiceTesuKngkSum = 0 THEN
		gInvoiceUchiSzei := 0;
	ELSE
		-- 改ページ単位の最終レコードの内容で算出
		gInvoiceUchiSzei := PKIPACALCTESUKNGK.getTesuZeiWarimodoshi(
								 gSzeiKijunYmd
								,gInvoiceTesuKngkSum
								,wTsukaCd
							);
	END IF;
	-- 同じページのレコードのインボイス項目を更新
	UPDATE	SREPORT_WK
	SET		 ITEM043	=	gInvoiceTesuLabel 			-- 適格請求書_手数料ラベル
			,ITEM044	=	gSeikyuTotal 				-- 適格請求書_請求額合計
			,ITEM045	=	gInvoiceKknTesuKngkSum 		-- 適格請求書_基金および手数料合計
			,ITEM046	=	gInvoiceTesuKngkSum 			-- 適格請求書_手数料合計
			,ITEM047	=	gInvoiceUchiSzei 			-- 適格請求書_内消費税
			,ITEM048	=	gSzeiKijunYmd 				-- 消費税基準日(ジャーナル)
			,ITEM049	=	gSzeiRate 					-- 消費税率(ジャーナル)
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID
	AND		HEADER_FLG = '1'
	AND		coalesce(trim(both ITEM040)::text, '') = ''		-- 対象データなし でないもの
	AND		trim(both coalesce(ITEM001, '')) = trim(both coalesce(TITLE_OUTPUT, ''))	--帳票タイトル
	AND		trim(both coalesce(ITEM002, '')) = trim(both coalesce(gWrkStNyukinYmd, ''))	--徴求日
	AND		trim(both coalesce(ITEM006, '')) = trim(both coalesce(wHktCd, ''))			--発行体コード
	AND		trim(both coalesce(ITEM004, '')) = trim(both coalesce(wKaikeiKbn, ''))		--会計区分
	AND		trim(both coalesce(ITEM014, '')) = trim(both coalesce(wTsukaCd, ''))		--通貨コード
	AND		trim(both coalesce(ITEM041, '')) = trim(both coalesce(wKozaFuriKbn, ''))	--口座振替区分
	;
	gRtnCd := pkconstant.success();
	RETURN;
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.error('ECM701', REPORT_ID, SQLERRM);
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spiph008k00r01_updateinvoiceitem () FROM PUBLIC;