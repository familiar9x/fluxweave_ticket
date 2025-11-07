DROP TYPE IF EXISTS spiph003k00r01_type_record CASCADE;
CREATE TYPE spiph003k00r01_type_record AS (
			 gHktCd					varchar(6)					-- 発行体コード
			,gHktNm					varchar(100)					-- 発行体名称
			,gSfskBushoNm			varchar(50)			-- 送付先担当部署名称（御中込）
			,gBankNm				varchar(50) 				-- 銀行名称
			,gBushoNm2				varchar(50) 				-- 担当部署名称２
			,gIsinCd				varchar(12)					-- ISINコード
			,gMgrNm					varchar(400)					-- 銘柄の正式名称
			,gShasaiTotal			numeric(14)				-- 発行総額
			,gHakkoYmd				varchar(8)				-- 発行年月日
			,gChokyuYmd				varchar(8)			-- 支払日
			,gHakkoKagaku			decimal(5,2)				-- 発行価額
			,gHakkoTsukaCd			varchar(3)			-- 発行通貨
			,gHakkoTsukaNm			varchar(3)					-- 発行通貨名称
			,gJutakuRate			decimal(6,5)								-- 受託手数料率
			,gHikiukeRate			decimal(6,5)								-- 引受手数料率
			,gKanjiRate				decimal(6,5)								-- 幹事手数料率
			,gKaikeiKbn				varchar(2)			-- 会計区分
			,gKaikeiKbnNm			varchar(40)			-- 会計区分名称
			,gKaikeiKbnAnbunKngk	numeric(14)	-- 会計区分別按分額
			,gWrkKaikeiKbnAnbunKngk	numeric(8)								-- 会計区分別按分額(百万単位)
			,gFurikomiKngk			numeric(14)								-- 振込額
			,gJutakuKngk			numeric(12)								-- 受託手数料（税込）
			,gHikiukeKngk			numeric(12)								-- 引受手数料（税込）
			,gKanjiKngk				numeric(12)								-- 幹事手数料（税込）
			,gShinkiKngk			numeric(12)								-- 新規手数料（税込）
			,gTesuTotal				numeric(12)								-- 手数料合計
			,gJutakuSzei			numeric(10)								-- 受託手数料消費税
			,gHikiukeSzei			numeric(10)								-- 引受手数料消費税
			,gKanjiSzei				numeric(10)								-- 幹事手数料消費税
			,gShinkiSzei			numeric(10)								-- 新規手数料消費税
			,gTesuSzeiTotal			numeric(10)								-- 手数料消費税額合計
			,gInvoiceTourokuNo		varchar(14) 		-- 適格請求書発行事業者登録番号
				);


CREATE OR REPLACE PROCEDURE spiph003k00r01 ( l_inHktCd VARCHAR,		-- 発行体コード
 l_inKozaTenCd VARCHAR,		-- 口座店コード
 l_inKozaTenCifCd VARCHAR,		-- 口座店CIFコード
 l_inMgrCd VARCHAR,		-- 銘柄コード
 l_inIsinCd VARCHAR,		-- ISINコード
 l_inKijyunYmdF VARCHAR,		-- 基準日(FROM)
 l_inKijyunYmdT VARCHAR,		-- 基準日(TO)
 l_inTuchiYmd VARCHAR,		-- 通知日
 l_inItakuKaishaCd VARCHAR,		-- 委託会社コード
 l_inUserId text,	-- ユーザーID
 l_inChohyoKbn VARCHAR,		-- 帳票区分
 l_inGyomuYmd VARCHAR,		-- 業務日付
 l_outSqlCode OUT integer,		-- リターン値
 l_outSqlErrM OUT text		-- エラーコメント
 ) AS $body$
DECLARE

--
--/* 著作権:Copyright(c)2004
--/* 会社名:JIP
--/* 概要　:顧客宛帳票出力指示画面の入力条件により、払込計算書（会計区分別）を作成する。
--/* 引数　:	l_inHktCd			IN	TEXT		発行体コード
--/*			l_inKozaTenCd		IN	TEXT		口座店コード
--/*			l_inKozaTenCifCd	IN	TEXT		口座店CIFコード
--/*			l_inMgrCd			IN	TEXT		銘柄コード
--/*			l_inIsinCd			IN	TEXT		ISINコード
--/*			l_inKijyunYmdF		IN	TEXT		基準日(FROM)
--/*			l_inKijyunYmdT		IN	TEXT		基準日(TO)
--/*			l_inTuchiYmd		IN	TEXT		通知日
--/*			l_inItakuKaishaCd	IN	TEXT		委託会社コード
--/*			l_inUserId			IN	TEXT		ユーザーID
--/*			l_inChohyoKbn		IN	TEXT		帳票区分
--/*			l_inGyomuYmd		IN	TEXT		業務日付
--/*			l_outSqlCode		OUT	INTEGER		リターン値
--/*			l_outSqlErrM		OUT	VARCHAR	エラーコメント
--/* 返り値:なし
--/*
--/* @version $Id: SPIPH003K00R01.SQL,v 1.18 2023/09/06 10:28:31 kentaro_ikeda Exp $
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.05.16	JIP				新規作成
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
	RTN_OK				CONSTANT integer	:= 0;						-- 正常
	RTN_NG				CONSTANT integer	:= 1;						-- 予期したエラー
	RTN_NODATA			CONSTANT integer	:= 2;						-- データなし
	RTN_FATAL			CONSTANT integer	:= 99;						-- 予期せぬエラー
	REPORT_ID			CONSTANT char(11)	:= 'IPH30000311';			-- 帳票ID
	-- 書式フォーマット
	FMT_HAKKO_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	FMT_RBR_KNGK_J		CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 利払金額
	FMT_SHOKAN_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 償還金額
	TSUCHI_YMD_DEF		CONSTANT char(16)	:= '      年  月  日';		-- 通知日（デフォルト）
--	ST_REC_KBN_FIRST	CONSTANT CHAR(1)		:= '1';					-- 初回レコード区分（初回）
--==============================================================================
--					変数定義													
--==============================================================================
	gRtnCd					integer :=	RTN_OK;						-- リターンコード
	gSeqNo					integer := 0;							-- シーケンス
	gSeqNoIni				integer := 0;							-- シーケンス
	gCurNo					integer := 0;							-- カーソルループ番号
	gSQL					varchar(32767) := NULL;				-- SQL編集
	-- DB取得項目
	-- 配列定義
	recMeisai spiph003k00r01_type_record[];
	-- 西暦変換用
	gWrkStTuchiYmd			varchar(20) := NULL;				-- 通知日
	gWrkStHakkouYmd			varchar(20) := NULL;				-- 発行年月日
	gWrkStSiharaiYmd		varchar(20) := NULL;				-- 支払日
	-- 宛名編集用
	gAtena					varchar(200) := NULL;				-- 宛名
	gOutflg					numeric := 0;						-- 正常処理フラグ
	-- 合計計算用
	gWrkHktCd				varchar(6) := NULL;				-- 発行体コード
	gWrkIsinCd				varchar(12) := NULL;				-- ISINコード
	gWrkChokyuYmd			varchar(8) := NULL;				-- 徴求日
	gWrkAnbunTotal			numeric(10) := 0;					-- 会計区分別按分額合計
	gWrkFurikomiTotal		numeric(16) := 0;					-- 振込額合計
	gWrkJtkuTesuryoTotal	numeric(14) := 0;					-- 募集受託手数料金額合計
	gWrkHkukTesuryoTotal	numeric(14) := 0;					-- 引受手数料金額合計
	gWrkShnkTesuryoTotal	numeric(14) := 0;					-- 新規記録手数料金額合計
	gWrkTesuGTotal			numeric(14) := 0;					-- 手数料合計の合計
	gAnbunTotal				numeric(10) := 0;					-- 会計区分別按分額合計
	gFurikomiTotal			numeric(16) := 0;					-- 振込額合計
	gJtkuTesuryoTotal		numeric(14) := 0;					-- 募集受託手数料金額合計
	gHkukTesuryoTotal		numeric(14) := 0;					-- 引受手数料金額合計
	gShnkTesuryoTotal		numeric(14) := 0;					-- 新規記録手数料金額合計
	gTesuGTotal				numeric(14) := 0;					-- 手数料合計の合計
	-- カーソル
	curMeisai REFCURSOR;
	-- インボイス用
	gAryBun					varchar[];						-- インボイス文章(請求書)配列
	gInvoiceBun				varchar(400);					-- インボイス文章
	gInvoiceTourokuNo		varchar(14);	-- 適格請求書発行事業者登録番号
	gInvoiceTesuLabel		varchar(20);							-- 手数料ラベル
	gInvoiceTesuKngkSum		numeric(16) := 0;					-- 適格請求書_手数料合計
	gInvoiceUchiSzei		numeric(16) := 0;					-- 適格請求書_内消費税
	gInvoiceUchiSzeiT		numeric(16) := 0;					-- 適格請求書_内消費税（立替払）
	gSzeiRate				numeric(2);								-- 適格請求書_消費税率
	gSzeiKijunYmd			char(8);								-- 適格請求書_消費税基準日
	gInvoiceTourokuNoT		varchar(14);		-- 適格請求書発行事業者登録番号（ほふり）
	gHoujinNm				varchar(100);					-- 法人名称（ほふり）
	gWrkHoujinCd			char(8);					-- 法人コード（ほふり）
	gJournalAtena1			varchar(400) := NULL;				-- 宛名1(ジャーナル)
	gJournalAtena2			varchar(400) := NULL;				-- 宛名2(ジャーナル)
	gJournalAtena3			varchar(400) := NULL;
	-- Temp record for cursor
	tempRec spiph003k00r01_type_record;
	-- Item composite type for pkPrint.insertData
	v_item type_sreport_wk_item;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPH003K00R01 START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inKijyunYmdF)::text, '') = ''					-- 基準日(FROM)
	OR coalesce(trim(both l_inKijyunYmdT)::text, '') = ''					-- 基準日(TO)
	OR coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''				-- 委託会社コード
	OR coalesce(trim(both l_inUserId)::text, '') = ''						-- ユーザID
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''					-- 帳票区分
	OR coalesce(trim(both l_inGyomuYmd)::text, '') = ''					-- 業務日付
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error(l_inUserId, REPORT_ID, 'SQLERRM:'||'');
		RETURN;
	END IF;
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	-- 連番取得
	SELECT	coalesce(MAX(SEQ_NO), 0)
	INTO STRICT	gSeqNoIni
	FROM	SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;
	gSeqNo := gSeqNoIni;
	-- インボイス対応：変数の初期化
	gInvoiceTourokuNoT	:= NULL;
	gHoujinNm			:= NULL;
	gInvoiceBun			:= NULL;
	-- 立替払先情報取得
	gWrkHoujinCd := pkControl.getCtlValue(l_inItakuKaishaCd, 'HOFURI_INFO', '0');
	SELECT	INVOICE_TOUROKU_NO,
			HOUJIN_NM
	INTO STRICT	gInvoiceTourokuNoT,
			gHoujinNm
	FROM MHOUJIN
	WHERE ITAKU_KAISHA_CD = l_inItakuKaishaCd
	AND HOUJIN_CD = gWrkHoujinCd;
	-- インボイス文章取得
	gAryBun := pkIpaBun.getBun(REPORT_ID, 'L0');
	FOR i IN 1..coalesce(cardinality(gAryBun), 0) LOOP
		IF i = 1 THEN
			gInvoiceBun := gAryBun[i];
		END IF;
	END LOOP;
	-- SQL編集
	CALL spiph003k00r01_createsql(
		l_inItakuKaishaCd,
		l_inMgrCd,
		l_inKijyunYmdF,
		l_inKijyunYmdT,
		l_inHktCd,
		l_inKozaTenCd,
		l_inKozaTenCifCd,
		l_inIsinCd,
		gSQL
	);
	-- カーソルオープン
	OPEN curMeisai FOR EXECUTE gSQL;
	-- データ取得
	LOOP
		FETCH curMeisai INTO tempRec;
		EXIT WHEN NOT FOUND;
		
		-- 会計区分別按分額(百万円単位) 算出処理
		tempRec.gWrkKaikeiKbnAnbunKngk := 0;
		IF tempRec.gKaikeiKbnAnbunKngk > 0 THEN
			tempRec.gWrkKaikeiKbnAnbunKngk := tempRec.gKaikeiKbnAnbunKngk / 1000000;
		END IF;
		
		recMeisai := array_append(recMeisai, tempRec);
		gCurNo := coalesce(cardinality(recMeisai), 0);
	END LOOP;
	CLOSE curMeisai;
	-- 西暦変換
	gWrkStTuchiYmd := TSUCHI_YMD_DEF;
	IF (trim(both l_inTuchiYmd) IS NOT NULL AND (trim(both l_inTuchiYmd))::text <> '') THEN
		gWrkStTuchiYmd := pkDate.seirekiChangeSuppressNenGappi(l_inTuchiYmd);
	END IF;
	CASE
		WHEN gCurNo = 0 THEN
		--対象データなし
			gRtnCd := RTN_NODATA;
			-- 帳票ワークへデータを追加
			v_item := ROW(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
			              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL)::type_sreport_wk_item;
			v_item.l_inItem001 := gWrkStTuchiYmd;
			v_item.l_inItem039 := '対象データなし';
			
			CALL pkPrint.insertData(
				l_inKeyCd			=>	l_inItakuKaishaCd,
				l_inUserId			=>	l_inUserId,
				l_inChohyoKbn		=>	l_inChohyoKbn,
				l_inSakuseiYmd		=>	l_inGyomuYmd,
				l_inChohyoId		=>	REPORT_ID,
				l_inSeqNo			=>	1,
				l_inHeaderFlg		=>	'1',
				l_inItem			=>	v_item,
				l_inKousinId		=>	l_inUserId,
				l_inSakuseiId		=>	l_inUserId
			);
		ELSE
		-- 対象データ有り
			FOR i IN 1..coalesce(cardinality(recMeisai), 0) LOOP
				gSeqNo := gSeqNo + 1;
				-- 合計算出処理（発行体コード ISINコード ブレイク時インサート）
				IF gSeqNo <> gSeqNoIni + 1 AND (gWrkHktCd <> recMeisai[i].gHktCd OR gWrkChokyuYmd <> recMeisai[i].gChokyuYmd OR gWrkIsinCd <> recMeisai[i].gIsinCd) THEN
					-- 合計エリアに集計した値をセット
					gAnbunTotal := gWrkAnbunTotal;									-- 会計区分別按分額合計
					gFurikomiTotal := gWrkFurikomiTotal;							-- 振込額合計
					gJtkuTesuryoTotal := gWrkJtkuTesuryoTotal;						-- 受託手数料金額合計
					gHkukTesuryoTotal := gWrkHkukTesuryoTotal;						-- 引受手数料金額合計
					gShnkTesuryoTotal := gWrkShnkTesuryoTotal;						-- 新規記録手数料金額合計
					gTesuGTotal := gWrkTesuGTotal;									-- 手数料合計の合計
					-- ワークエリア初期化
					gWrkAnbunTotal := 0;											-- 会計区分別按分額合計
					gWrkFurikomiTotal := 0;											-- 振込額合計
					gWrkJtkuTesuryoTotal := 0;										-- 受託手数料金額合計
					gWrkHkukTesuryoTotal := 0;										-- 引受手数料金額合計
				gWrkShnkTesuryoTotal := 0;										-- 新規記録手数料金額合計
				gWrkTesuGTotal := 0;											-- 手数料合計の合計
				-- 合計レコード出力前に、明細レコードのインボイス項目を更新
				gSzeiKijunYmd := recMeisai[i-1].gHakkoYmd;
				CALL spiph003k00r01_updateinvoiceitem(
					recMeisai[i-1].gHakkoTsukaCd,
					l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID,
					gRtnCd, gSzeiKijunYmd, gSzeiRate, gInvoiceTesuLabel,
					gTesuGTotal, gInvoiceUchiSzei, gShnkTesuryoTotal, gInvoiceUchiSzeiT,
					gFurikomiTotal, gWrkStSiharaiYmd, gWrkHktCd, gWrkIsinCd
				);
				IF gRtnCd <> pkconstant.success() THEN
						l_outSqlCode := gRtnCd;
						RETURN;
					END IF;
					-- 帳票ワークへ合計データを追加
					v_item := ROW(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
					              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
					              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
					              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
					              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
					              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
					              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
					              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
					              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
					              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
					              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
					              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
					              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
					              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
					              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
					              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
					              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
					              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
					              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
					              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
					              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
					              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
					              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
					              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
					              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL)::type_sreport_wk_item;
					v_item.l_inItem001 := gWrkStTuchiYmd;
					v_item.l_inItem002 := recMeisai[i-1].gHktCd;
					v_item.l_inItem003 := gAtena;
					v_item.l_inItem004 := recMeisai[i-1].gBankNm;
					v_item.l_inItem005 := recMeisai[i-1].gBushoNm2;
					v_item.l_inItem006 := recMeisai[i-1].gIsinCd;
					v_item.l_inItem007 := recMeisai[i-1].gMgrNm;
					v_item.l_inItem008 := recMeisai[i-1].gShasaiTotal;
					v_item.l_inItem009 := gWrkStHakkouYmd;
					v_item.l_inItem010 := gWrkStSiharaiYmd;
					v_item.l_inItem011 := recMeisai[i-1].gHakkoKagaku;
					v_item.l_inItem012 := (coalesce(recMeisai[i-1].gJutakuRate,0)
												* (1 + pkipazei.getShohiZei(recMeisai[i-1].gHakkoYmd)));
					v_item.l_inItem013 := (coalesce(recMeisai[i-1].gHikiukeRate,0)
												* (1 + pkipazei.getShohiZei(recMeisai[i-1].gHakkoYmd)))
											+ (coalesce(recMeisai[i-1].gKanjiRate,0)
												* (1 + pkipazei.getShohiZei(recMeisai[i-1].gHakkoYmd)));
					v_item.l_inItem026 := gAnbunTotal;
					v_item.l_inItem027 := gFurikomiTotal;
					v_item.l_inItem028 := gJtkuTesuryoTotal;
					v_item.l_inItem029 := gHkukTesuryoTotal;
					v_item.l_inItem030 := gShnkTesuryoTotal;
					v_item.l_inItem031 := gTesuGTotal;
					v_item.l_inItem032 := gInvoiceBun;
					v_item.l_inItem033 := recMeisai[i-1].gInvoiceTourokuNo;
					v_item.l_inItem034 := recMeisai[i-1].gHakkoTsukaNm;
					v_item.l_inItem035 := gFurikomiTotal;
					v_item.l_inItem036 := FMT_HAKKO_KNGK_J;
					v_item.l_inItem037 := FMT_RBR_KNGK_J;
					v_item.l_inItem038 := FMT_SHOKAN_KNGK_J;
					v_item.l_inItem040 := gInvoiceTesuLabel;
					v_item.l_inItem041 := gTesuGTotal;
					v_item.l_inItem042 := gInvoiceUchiSzei;
					v_item.l_inItem043 := gInvoiceTourokuNoT;
					v_item.l_inItem044 := gHoujinNm;
					v_item.l_inItem045 := gShnkTesuryoTotal;
					v_item.l_inItem046 := gInvoiceUchiSzeiT;
					v_item.l_inItem047 := gSzeiKijunYmd;
					v_item.l_inItem048 := gSzeiRate;
					v_item.l_inItem049 := gJournalAtena1;
					v_item.l_inItem050 := gJournalAtena2;
					v_item.l_inItem051 := gJournalAtena3;
					
					CALL pkPrint.insertData
					(
						 l_inKeyCd			=>	l_inItakuKaishaCd,
						 l_inUserId			=>	l_inUserId,
						 l_inChohyoKbn		=>	l_inChohyoKbn,
						 l_inSakuseiYmd		=>	l_inGyomuYmd,
						 l_inChohyoId		=>	REPORT_ID,
						 l_inSeqNo			=>	gSeqNo,
						 l_inHeaderFlg		=>	'1',
						 l_inItem			=>	v_item,
						 l_inKousinId		=>	l_inUserId,
						 l_inSakuseiId		=>	l_inUserId
					);
					gSeqNo := gSeqNo + 1;
					gWrkHktCd := recMeisai[i].gHktCd;
					gWrkChokyuYmd := recMeisai[i].gChokyuYmd;
					gWrkIsinCd := recMeisai[i].gIsinCd;
				ELSE
					IF gSeqNo = gSeqNoIni + 1 THEN
						gWrkHktCd := recMeisai[i].gHktCd;
						gWrkChokyuYmd := recMeisai[i].gChokyuYmd;
						gWrkIsinCd := recMeisai[i].gIsinCd;
					END IF;
				END IF;
				-- 宛名編集（御中編集）
				CALL pkIpaName.getMadoFutoAtena(recMeisai[i].gHktNm, recMeisai[i].gSfskBushoNm, gOutflg, gAtena);
				-- CSVジャーナル宛名
				CALL pkIpaName.getMadoFutoAtena_Journal(recMeisai[i].gHktNm, recMeisai[i].gSfskBushoNm, gOutflg, gJournalAtena1, gJournalAtena2, gJournalAtena3);
				-- 西暦変換
				gWrkStHakkouYmd := NULL;	-- 発行年月日
				IF (recMeisai[i].gHakkoYmd IS NOT NULL AND recMeisai[i].gHakkoYmd::text <> '') THEN
					gWrkStHakkouYmd := pkDate.seirekiChangeSuppressNenGappi(recMeisai[i].gHakkoYmd);
				END IF;
				gWrkStSiharaiYmd := NULL;	-- 支払日
				IF (recMeisai[i].gChokyuYmd IS NOT NULL AND recMeisai[i].gChokyuYmd::text <> '') THEN
					gWrkStSiharaiYmd := pkDate.seirekiChangeSuppressNenGappi(recMeisai[i].gChokyuYmd);
				END IF;
				-- ワークエリアに合計を集計
				gWrkAnbunTotal := gWrkAnbunTotal + recMeisai[i].gWrkKaikeiKbnAnbunKngk;		-- 会計区分別按分額合計
				gWrkFurikomiTotal := gWrkFurikomiTotal + recMeisai[i].gFurikomiKngk;		-- 振込額合計
				gWrkJtkuTesuryoTotal := gWrkJtkuTesuryoTotal + recMeisai[i].gJutakuKngk;	-- 受託手数料金額合計
				gWrkHkukTesuryoTotal := gWrkHkukTesuryoTotal + (recMeisai[i].gHikiukeKngk + recMeisai[i].gKanjiKngk);	-- 引受手数料金額合計
				gWrkShnkTesuryoTotal := gWrkShnkTesuryoTotal + (recMeisai[i].gShinkiKngk);	-- 新規記録手数料金額合計
				gWrkTesuGTotal := gWrkTesuGTotal + recMeisai[i].gTesuTotal;					-- 手数料合計の合計
				-- 帳票ワークへデータを追加
				v_item := ROW(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
				              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
				              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
				              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
				              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
				              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
				              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
				              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
				              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
				              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
				              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
				              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
				              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
				              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
				              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
				              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
				              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
				              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
				              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
				              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
				              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
				              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
				              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
				              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
				              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL)::type_sreport_wk_item;
				v_item.l_inItem001 := gWrkStTuchiYmd;
				v_item.l_inItem002 := recMeisai[i].gHktCd;
				v_item.l_inItem003 := gAtena;
				v_item.l_inItem004 := recMeisai[i].gBankNm;
				v_item.l_inItem005 := recMeisai[i].gBushoNm2;
				v_item.l_inItem006 := recMeisai[i].gIsinCd;
				v_item.l_inItem007 := recMeisai[i].gMgrNm;
				v_item.l_inItem008 := recMeisai[i].gShasaiTotal;
				v_item.l_inItem009 := gWrkStHakkouYmd;
				v_item.l_inItem010 := gWrkStSiharaiYmd;
				v_item.l_inItem011 := recMeisai[i].gHakkoKagaku;
				v_item.l_inItem012 := (coalesce(recMeisai[i].gJutakuRate,0)
											* (1 + pkipazei.getShohiZei(recMeisai[i].gHakkoYmd)));
				v_item.l_inItem013 := (coalesce(recMeisai[i].gHikiukeRate,0)
											* (1 + pkipazei.getShohiZei(recMeisai[i].gHakkoYmd)))
										+ (coalesce(recMeisai[i].gKanjiRate,0)
											* (1 + pkipazei.getShohiZei(recMeisai[i].gHakkoYmd)));
				v_item.l_inItem014 := recMeisai[i].gKaikeiKbn;
				v_item.l_inItem015 := recMeisai[i].gKaikeiKbnNm;
				v_item.l_inItem016 := recMeisai[i].gKaikeiKbnAnbunKngk / 1000000;
				v_item.l_inItem017 := recMeisai[i].gFurikomiKngk;
				v_item.l_inItem018 := recMeisai[i].gJutakuKngk;
				v_item.l_inItem019 := recMeisai[i].gHikiukeKngk + recMeisai[i].gKanjiKngk;
				v_item.l_inItem020 := recMeisai[i].gShinkiKngk;
				v_item.l_inItem021 := recMeisai[i].gTesuTotal;
				v_item.l_inItem022 := recMeisai[i].gJutakuSzei;
				v_item.l_inItem023 := recMeisai[i].gHikiukeSzei + recMeisai[i].gKanjiSzei;
				v_item.l_inItem024 := recMeisai[i].gShinkiSzei;
				v_item.l_inItem025 := recMeisai[i].gTesuSzeiTotal;
				v_item.l_inItem032 := gInvoiceBun;
				v_item.l_inItem033 := recMeisai[i].gInvoiceTourokuNo;
				v_item.l_inItem034 := recMeisai[i].gHakkoTsukaNm;
				v_item.l_inItem036 := FMT_HAKKO_KNGK_J;
				v_item.l_inItem037 := FMT_RBR_KNGK_J;
				v_item.l_inItem038 := FMT_SHOKAN_KNGK_J;
				v_item.l_inItem043 := gInvoiceTourokuNoT;
				v_item.l_inItem044 := gHoujinNm;
				v_item.l_inItem049 := gJournalAtena1;
				v_item.l_inItem050 := gJournalAtena2;
				v_item.l_inItem051 := gJournalAtena3;
				
				CALL pkPrint.insertData
				(
					 l_inKeyCd			=>	l_inItakuKaishaCd,
					 l_inUserId			=>	l_inUserId,
					 l_inChohyoKbn		=>	l_inChohyoKbn,
					 l_inSakuseiYmd		=>	l_inGyomuYmd,
					 l_inChohyoId		=>	REPORT_ID,
					 l_inSeqNo			=>	gSeqNo,
					 l_inHeaderFlg		=>	'1',
					 l_inItem			=>	v_item,
					 l_inKousinId		=>	l_inUserId,
					 l_inSakuseiId		=>	l_inUserId
				);
			END LOOP;
	END CASE;
	-- 最後の合計をセット
	IF gSeqNo <> gSeqNoIni THEN
		gSeqNo := gSeqNo + 1;
		-- 合計のセット
		gAnbunTotal := gWrkAnbunTotal;									-- 会計区分別按分額合計
		gFurikomiTotal := gWrkFurikomiTotal;							-- 振込額合計
		gJtkuTesuryoTotal := gWrkJtkuTesuryoTotal;						-- 受託手数料金額合計
		gHkukTesuryoTotal := gWrkHkukTesuryoTotal;						-- 引受手数料金額合計
	gShnkTesuryoTotal := gWrkShnkTesuryoTotal;						-- 新規記録手数料金額合計
	gTesuGTotal := gWrkTesuGTotal;									-- 手数料合計の合計
	-- 最後の合計レコード出力前に、明細レコードのインボイス項目を更新
	gSzeiKijunYmd := recMeisai[coalesce(cardinality(recMeisai), 0) - 1].gHakkoYmd;
	CALL spiph003k00r01_updateinvoiceitem(
		recMeisai[coalesce(cardinality(recMeisai), 0)].gHakkoTsukaCd,
		l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID,
		gRtnCd, gSzeiKijunYmd, gSzeiRate, gInvoiceTesuLabel,
		gTesuGTotal, gInvoiceUchiSzei, gShnkTesuryoTotal, gInvoiceUchiSzeiT,
		gFurikomiTotal, gWrkStSiharaiYmd, gWrkHktCd, gWrkIsinCd
	);
	IF gRtnCd <> pkconstant.success() THEN
			l_outSqlCode := gRtnCd;
			RETURN;
		END IF;
		-- 帳票ワークへ合計データを追加
		v_item := ROW(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
		              NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL)::type_sreport_wk_item;
		v_item.l_inItem001 := gWrkStTuchiYmd;
		v_item.l_inItem002 := recMeisai[COALESCE(cardinality(recMeisai), 0) - 1].gHktCd;
		v_item.l_inItem003 := gAtena;
		v_item.l_inItem004 := recMeisai[COALESCE(cardinality(recMeisai), 0) - 1].gBankNm;
		v_item.l_inItem005 := recMeisai[COALESCE(cardinality(recMeisai), 0) - 1].gBushoNm2;
		v_item.l_inItem006 := recMeisai[COALESCE(cardinality(recMeisai), 0) - 1].gIsinCd;
		v_item.l_inItem007 := recMeisai[COALESCE(cardinality(recMeisai), 0) - 1].gMgrNm;
		v_item.l_inItem008 := recMeisai[COALESCE(cardinality(recMeisai), 0) - 1].gShasaiTotal;
		v_item.l_inItem009 := gWrkStHakkouYmd;
		v_item.l_inItem010 := gWrkStSiharaiYmd;
		v_item.l_inItem011 := recMeisai[COALESCE(cardinality(recMeisai), 0) - 1].gHakkoKagaku;
		v_item.l_inItem012 := (coalesce(recMeisai[COALESCE(cardinality(recMeisai), 0) - 1].gJutakuRate,0)
									* (1 + pkipazei.getShohiZei(recMeisai[COALESCE(cardinality(recMeisai), 0) - 1].gHakkoYmd)));
		v_item.l_inItem013 := (coalesce(recMeisai[COALESCE(cardinality(recMeisai), 0) - 1].gHikiukeRate,0)
									* (1 + pkipazei.getShohiZei(recMeisai[COALESCE(cardinality(recMeisai), 0) - 1].gHakkoYmd)))
								+ (coalesce(recMeisai[COALESCE(cardinality(recMeisai), 0) - 1].gKanjiRate,0)
									* (1 + pkipazei.getShohiZei(recMeisai[COALESCE(cardinality(recMeisai), 0) - 1].gHakkoYmd)));
		v_item.l_inItem026 := gAnbunTotal;
		v_item.l_inItem027 := gFurikomiTotal;
		v_item.l_inItem028 := gJtkuTesuryoTotal;
		v_item.l_inItem029 := gHkukTesuryoTotal;
		v_item.l_inItem030 := gShnkTesuryoTotal;
		v_item.l_inItem031 := gTesuGTotal;
		v_item.l_inItem032 := gInvoiceBun;
		v_item.l_inItem033 := recMeisai[COALESCE(cardinality(recMeisai), 0) - 1].gInvoiceTourokuNo;
		v_item.l_inItem034 := recMeisai[COALESCE(cardinality(recMeisai), 0) - 1].gHakkoTsukaNm;
		v_item.l_inItem035 := gFurikomiTotal;
		v_item.l_inItem036 := FMT_HAKKO_KNGK_J;
		v_item.l_inItem037 := FMT_RBR_KNGK_J;
		v_item.l_inItem038 := FMT_SHOKAN_KNGK_J;
		v_item.l_inItem040 := gInvoiceTesuLabel;
		v_item.l_inItem041 := gTesuGTotal;
		v_item.l_inItem042 := gInvoiceUchiSzei;
		v_item.l_inItem043 := gInvoiceTourokuNoT;
		v_item.l_inItem044 := gHoujinNm;
		v_item.l_inItem045 := gShnkTesuryoTotal;
		v_item.l_inItem046 := gInvoiceUchiSzeiT;
		v_item.l_inItem047 := recMeisai[COALESCE(cardinality(recMeisai), 0) - 1].gHakkoYmd;
		v_item.l_inItem048 := gSzeiRate;
		v_item.l_inItem049 := gJournalAtena1;
		v_item.l_inItem050 := gJournalAtena2;
		v_item.l_inItem051 := gJournalAtena3;
		
		CALL pkPrint.insertData
		(
			 l_inKeyCd			=>	l_inItakuKaishaCd,
			 l_inUserId			=>	l_inUserId,
			 l_inChohyoKbn		=>	l_inChohyoKbn,
			 l_inSakuseiYmd		=>	l_inGyomuYmd,
			 l_inChohyoId		=>	REPORT_ID,
			 l_inSeqNo			=>	gSeqNo,
			 l_inHeaderFlg		=>	'1',
			 l_inItem			=>	v_item,
			 l_inKousinId		=>	l_inUserId,
			 l_inSakuseiId		=>	l_inUserId
		);
	END IF;
	-- CSVジャーナルINSERT  
	l_outSqlCode := pkCsvJournal.insertData(
						 l_inItakuKaishaCd 			-- 委託会社コード
						,l_inUserId 					-- ユーザＩＤ
						,l_inChohyoKbn 				-- 帳票区分
						,l_inGyomuYmd 				-- 処理日付
						,REPORT_ID 					-- 帳票ＩＤ
					);
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPH003K00R01 END');	END IF;
	-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
--		ROLLBACK;
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLERRM:'||SQLERRM);
	l_outSqlCode := RTN_FATAL;
	l_outSqlErrM := SQLERRM;
--		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spiph003k00r01 ( l_inHktCd TEXT, l_inKozaTenCd TEXT, l_inKozaTenCifCd TEXT, l_inMgrCd TEXT, l_inIsinCd TEXT, l_inKijyunYmdF TEXT, l_inKijyunYmdT TEXT, l_inTuchiYmd TEXT, l_inItakuKaishaCd TEXT, l_inUserId text, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT TEXT  ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spiph003k00r01_createsql (
	l_inItakuKaishaCd TEXT,
	l_inMgrCd TEXT,
	l_inKijyunYmdF TEXT,
	l_inKijyunYmdT TEXT,
	l_inHktCd TEXT,
	l_inKozaTenCd TEXT,
	l_inKozaTenCifCd TEXT,
	l_inIsinCd TEXT,
	INOUT gSQL varchar
) AS $body$
BEGIN
	gSQL := '';
	gSQL := 'SELECT AT01.HKT_CD, '			-- 発行体コード
		|| '       AT01.HKT_NM, '			-- 発行体名称
		|| '       AT01.SFSK_BUSHO_NM, '	-- 送付先担当部署名称（御中込）
		|| '       AT01.BANK_NM, '			-- 銀行名称
		|| '       AT01.BUSHO_NM2, '		-- 担当部署名称２
		|| '       AT01.ISIN_CD, '			-- ISINコード
		|| '       AT01.MGR_NM, '			-- 銘柄の正式名称
		|| '       AT01.SHASAI_TOTAL, '		-- 発行総額
		|| '       AT01.HAKKO_YMD, '		-- 発行年月日
		|| '       AT01.CHOKYU_YMD, '		-- 支払日
		|| '       AT01.HAKKO_KAGAKU, '		-- 発行価額
		|| '       AT01.HAKKO_TSUKA_CD, '	-- 発行通貨
		|| '       (SELECT M64.TSUKA_NM FROM MTSUKA M64 WHERE M64.TSUKA_CD = AT01.HAKKO_TSUKA_CD) '
		|| '         AS HAKKO_TSUKA_NM, '	-- 発行通貨名称
		|| '       AT03.JUTAKU_RATE, '		-- 受託手数料率
		|| '       AT03.HIKIUKE_RATE, '		-- 引受手数料率
		|| '       AT03.KANJI_RATE, '		-- 幹事手数料率
		|| '       AT03.KAIKEI_KBN, '		-- 会計区分
		|| '       AT02.KAIKEI_KBN_NM, '	-- 会計区分名称
		|| '       AT02.KAIKEI_KBN_ANBUN_KNGK, '	-- 会計区分別按分額
		|| '       AT02.FURIKOMI_GK, '		-- 振込額
		|| '       AT03.JUTAKU_GK, '		-- 募集受託手数料（税込）
		|| '       AT03.HIKIUKE_GK, '		-- 引受手数料（税込）
		|| '       AT03.KANJI_GK, '			-- 幹事手数料（税込）
		|| '       AT03.SHINKI_GK, '		-- 新規記録手数料（税込）
		|| '       AT03.TESU_TOTAL, '		-- 手数料合計
		|| '       AT03.JUTAKU_SZEI, '		-- 募集受託手数料消費税
		|| '       AT03.HIKIUKE_SZEI, '		-- 引受手数料消費税
		|| '       AT03.KANJI_SZEI, '		-- 幹事手数料消費税
		|| '       AT03.SHINKI_SZEI, '		-- 新規記録手数料消費税
		|| '       AT03.TESU_SZEI_TOTAL, '	-- 手数料消費税額合計
		|| '       AT01.INVOICE_TOUROKU_NO '-- 適格請求書発行事業者登録番号
		|| '  FROM (SELECT DISTINCT VMG1.ITAKU_KAISHA_CD, '
		|| '               VMG1.HKT_CD, '
		|| '               M01.HKT_NM AS HKT_NM, '
		|| '               M01.SFSK_BUSHO_NM AS SFSK_BUSHO_NM, '
		|| '               VJ1.BANK_NM AS BANK_NM, '
		|| '               VJ1.INVOICE_TOUROKU_NO AS INVOICE_TOUROKU_NO, '
		|| '               VJ1.BUSHO_NM2 AS BUSHO_NM2, '
		|| '               VMG1.ISIN_CD, '
		|| '               VMG1.MGR_CD AS MGR_CD, '
		|| '               VMG1.MGR_NM AS MGR_NM, '
		|| '               VMG1.SHASAI_TOTAL AS SHASAI_TOTAL, '
		|| '               VMG1.HAKKO_YMD AS HAKKO_YMD, '
		|| '               VMG1.HAKKO_TSUKA_CD AS HAKKO_TSUKA_CD, '
		|| '               H03.CHOKYU_YMD AS CHOKYU_YMD, '
		|| '               VMG1.HAKKO_KAGAKU AS HAKKO_KAGAKU '
		|| '          FROM MHAKKOTAI      M01, '
		|| '               VJIKO_ITAKU    VJ1, '
		|| '               MGR_KIHON_VIEW      VMG1, '
		|| '               KAIKEI_KBN     H01, '
		|| '               TESURYO_KAIKEI H03 '
		|| '         WHERE '
		|| '		    VMG1.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' '
		|| '           AND VMG1.MGR_STAT_KBN = ''1'' '
		|| '           AND VMG1.ITAKU_KAISHA_CD = VJ1.KAIIN_ID '
		|| '           AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD '
		|| '           AND VMG1.HKT_CD = M01.HKT_CD ';
		IF (trim(both l_inHktCd) IS NOT NULL AND (trim(both l_inHktCd))::text <> '') THEN
			gSQL := gSQL || '           AND VMG1.HKT_CD = ''' || l_inHktCd || ''' ';
		END IF;
		IF (trim(both l_inKozaTenCd) IS NOT NULL AND (trim(both l_inKozaTenCd))::text <> '') THEN
			gSQL := gSQL || '           AND M01.KOZA_TEN_CD = ''' || l_inKozaTenCd || ''' ';
		END IF;
		IF (trim(both l_inKozaTenCifCd) IS NOT NULL AND (trim(both l_inKozaTenCifCd))::text <> '') THEN
			gSQL := gSQL || '           AND M01.KOZA_TEN_CIFCD = ''' || l_inKozaTenCifCd || ''' ';
		END IF;
		IF (trim(both l_inMgrCd) IS NOT NULL AND (trim(both l_inMgrCd))::text <> '') THEN
			gSQL := gSQL || '	        AND VMG1.MGR_CD = ''' || l_inMgrCd || ''' ';
		END IF;
		IF (trim(both l_inIsinCd) IS NOT NULL AND (trim(both l_inIsinCd))::text <> '') THEN
			gSQL := gSQL || '	        AND VMG1.ISIN_CD = ''' || l_inIsinCd || ''' ';
		END IF;
		gSQL := gSQL || '           AND VMG1.ITAKU_KAISHA_CD = H01.ITAKU_KAISHA_CD '
		|| '           AND VMG1.HKT_CD = H01.HKT_CD '
		|| '           AND H03.CHOKYU_YMD BETWEEN ''' || l_inKijyunYmdF || ''' AND ''' || l_inKijyunYmdT || ''' '
		|| '           AND VMG1.ITAKU_KAISHA_CD = H03.ITAKU_KAISHA_CD '
		|| '           AND VMG1.MGR_CD = H03.MGR_CD '
					   -- 会計按分テーブルの承認済み銘柄のみ抽出対象にする
		|| '		   AND PKIPAKKNIDO.GETKAIKEIANBUNCOUNT(VMG1.ITAKU_KAISHA_CD , VMG1.MGR_CD) > 0 '
		|| '           AND H01.KAIKEI_KBN = H03.KAIKEI_KBN) AT01, '
		|| '       (SELECT DISTINCT VMG1.ITAKU_KAISHA_CD, '
		|| '                       VMG1.HKT_CD, '
		|| '                       VMG1.MGR_CD, '
		|| '                       H01.KAIKEI_KBN, '
		|| '                       H01.KAIKEI_KBN_NM, '
		|| '                       H02.KAIKEI_KBN_ANBUN_KNGK, '
		|| '                       (H02.KAIKEI_KBN_ANBUN_KNGK * VMG1.HAKKO_KAGAKU / 100) AS FURIKOMI_GK '
		|| '                  FROM MGR_KIHON_VIEW      VMG1, '
		|| '                       KAIKEI_KBN     H01, '
		|| '                       KAIKEI_ANBUN   H02, '
		|| '                       TESURYO_KAIKEI H03 '
		|| '                 WHERE VMG1.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' '
		|| '                 AND VMG1.MGR_STAT_KBN = ''1'' ';
		IF (trim(both l_inHktCd) IS NOT NULL AND (trim(both l_inHktCd))::text <> '') THEN
			gSQL := gSQL || '           AND VMG1.HKT_CD = ''' || l_inHktCd || ''' ';
		END IF;
		IF (trim(both l_inMgrCd) IS NOT NULL AND (trim(both l_inMgrCd))::text <> '') THEN
			gSQL := gSQL || '	        AND VMG1.MGR_CD = ''' || l_inMgrCd || ''' ';
		END IF;
		gSQL := gSQL || '                   AND VMG1.ITAKU_KAISHA_CD = H01.ITAKU_KAISHA_CD '
		|| '                   AND VMG1.HKT_CD = H01.HKT_CD '
		|| '                   AND VMG1.ITAKU_KAISHA_CD = H02.ITAKU_KAISHA_CD '
		|| '                   AND VMG1.MGR_CD = H02.MGR_CD '
		|| '                   AND H01.KAIKEI_KBN = H02.KAIKEI_KBN '
		|| '                   AND H03.CHOKYU_YMD BETWEEN ''' || l_inKijyunYmdF || ''' AND ''' || l_inKijyunYmdT || ''' '
		|| '                   AND H03.ITAKU_KAISHA_CD = H02.ITAKU_KAISHA_CD '
		|| '                   AND H03.MGR_CD = H02.MGR_CD '
		|| '                   AND H03.KAIKEI_KBN = H02.KAIKEI_KBN) AT02, '
		|| '       (SELECT WT01.ITAKU_KAISHA_CD, '
		|| '               WT01.MGR_CD, '
		|| '               WT01.KAIKEI_KBN, '
		|| '               WT01.JUTAKU_RATE, '
		|| '               WT02.HIKIUKE_RATE, '
		|| '               WT06.KANJI_RATE, '
		|| '               COALESCE(WT01.JUTAKU_GK, 0) AS JUTAKU_GK, '		-- 募集受託手数料（税込）
		|| '               COALESCE(WT02.HIKIUKE_GK, 0) AS HIKIUKE_GK, 	'	-- 引受手数料（税込）
		|| '               COALESCE(WT06.KANJI_GK, 0) AS KANJI_GK, '			-- 幹事手数料（税込）
		|| '               COALESCE(WT08.SHINKI_GK, 0) AS SHINKI_GK, '		-- 新規記録手数料（税込）
		|| '               COALESCE(WT01.JUTAKU_GK, 0) + COALESCE(WT02.HIKIUKE_GK, 0) + COALESCE(WT06.KANJI_GK, 0) AS TESU_TOTAL, '	-- 手数料合計
		|| '               COALESCE(WT01.JUTAKU_SZEI, 0) AS JUTAKU_SZEI, '	-- 募集受託手数料消費税
		|| '               COALESCE(WT02.HIKIUKE_SZEI, 0) AS HIKIUKE_SZEI, '	-- 引受手数料消費税
		|| '               COALESCE(WT06.KANJI_SZEI, 0) AS KANJI_SZEI, '		-- 幹事手数料消費税
		|| '               COALESCE(WT08.SHINKI_SZEI, 0) AS SHINKI_SZEI, '	-- 新規記録手数料消費税
		|| '               COALESCE(WT01.JUTAKU_SZEI, 0) + COALESCE(WT02.HIKIUKE_SZEI, 0) + COALESCE(WT06.KANJI_SZEI, 0) AS TESU_SZEI_TOTAL '	-- 全体消費税額
		|| '          FROM (SELECT H03.ITAKU_KAISHA_CD, '
		|| '                        H03.MGR_CD, '
		|| '                        H03.KAIKEI_KBN, '
		|| '                        COALESCE(WT03.JUTAKU_RATE,0) AS JUTAKU_RATE, '
		|| '                        SUM(H03.ANBUN_TESU_KNGK_KOMI) AS JUTAKU_GK, '
		|| '                        SUM(H03.ANBUN_TESU_SZEI) AS JUTAKU_SZEI '
		|| '                   FROM TESURYO_KAIKEI H03 '                   -- 手数料計算結果（会計区分別）
		|| '                   LEFT OUTER JOIN (SELECT H03.ITAKU_KAISHA_CD, '
		|| '                                 H03.MGR_CD, '
		|| '                                 MAX(H03.RATE_BUNSHI / H03.RATE_BUNBO * 100) AS JUTAKU_RATE '
		|| '                            FROM TESURYO_KAIKEI H03  '                            -- 手数料計算結果（会計区分別）
		|| '                          WHERE H03.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' ';
		IF (trim(both l_inMgrCd) IS NOT NULL AND (trim(both l_inMgrCd))::text <> '') THEN
			gSQL := gSQL || '                 			AND H03.MGR_CD = ''' || l_inMgrCd || ''' ';
		END IF;
		gSQL := gSQL || '  							AND H03.CHOKYU_YMD BETWEEN ''' || l_inKijyunYmdF || ''' AND ''' || l_inKijyunYmdT || ''' '
		|| '                            AND H03.TESU_SHURUI_CD = ''01'' '
		|| '                            AND H03.KAIKEI_KBN <> ''00'' '
		|| '                            AND H03.RATE_BUNBO > 0 '		-- 0除算対策
		|| '                          GROUP BY H03.ITAKU_KAISHA_CD, H03.MGR_CD) WT03 '
		|| '                   ON (H03.ITAKU_KAISHA_CD = WT03.ITAKU_KAISHA_CD '
		|| '                    AND H03.MGR_CD = WT03.MGR_CD) '
		|| '                  WHERE H03.CHOKYU_YMD BETWEEN ''' || l_inKijyunYmdF || ''' AND ''' || l_inKijyunYmdT || ''' '
		|| '                    AND H03.TESU_SHURUI_CD = ''01'' '
		|| '                    AND H03.KAIKEI_KBN <> ''00'' '
		|| '                  GROUP BY H03.ITAKU_KAISHA_CD, '
		|| '                           H03.MGR_CD, '
		|| '                           H03.KAIKEI_KBN, '
		|| '                           WT03.JUTAKU_RATE) WT01 '
		|| '                LEFT OUTER JOIN (SELECT H03.ITAKU_KAISHA_CD, '
		|| '                         H03.MGR_CD, '
		|| '                         H03.KAIKEI_KBN, '
		|| '                         COALESCE(WT04.HIKIUKE_RATE,0) AS HIKIUKE_RATE, '
		|| '                         SUM(H03.ANBUN_TESU_KNGK_KOMI) AS HIKIUKE_GK, '
		|| '                         SUM(H03.ANBUN_TESU_SZEI) AS HIKIUKE_SZEI '
		|| '                    FROM TESURYO_KAIKEI H03 '                    -- 手数料計算結果（会計区分別）
		|| '                    LEFT OUTER JOIN (SELECT H03.ITAKU_KAISHA_CD, '
		|| '                                  H03.MGR_CD, '
		|| '                                  MAX(H03.RATE_BUNSHI / H03.RATE_BUNBO * 100) AS HIKIUKE_RATE '
 			|| '                         FROM TESURYO_KAIKEI H03 ' -- 手数料計算結果（会計区分別）
		|| '                          WHERE H03.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' ';
		IF (trim(both l_inMgrCd) IS NOT NULL AND (trim(both l_inMgrCd))::text <> '') THEN
			gSQL := gSQL || '                 			AND H03.MGR_CD = ''' || l_inMgrCd || ''' ';
		END IF;
		gSQL := gSQL || ' 							AND H03.CHOKYU_YMD BETWEEN ''' || l_inKijyunYmdF || ''' AND ''' || l_inKijyunYmdT || ''' '
		|| '                            AND H03.TESU_SHURUI_CD = ''31'' '
		|| '                            AND H03.KAIKEI_KBN <> ''00'' '
		|| '                            AND H03.RATE_BUNBO > 0 '		-- 0除算対策
		|| '                         GROUP BY H03.ITAKU_KAISHA_CD, H03.MGR_CD) WT04 '
		|| '                    ON (H03.ITAKU_KAISHA_CD = WT04.ITAKU_KAISHA_CD '
		|| '                   AND H03.MGR_CD = WT04.MGR_CD) '
		|| '                 WHERE H03.CHOKYU_YMD BETWEEN ''' || l_inKijyunYmdF || ''' AND ''' || l_inKijyunYmdT || ''' '
		|| '                   AND H03.TESU_SHURUI_CD = ''31'' '
		|| '                   AND H03.KAIKEI_KBN <> ''00'' '
		|| '                 GROUP BY H03.ITAKU_KAISHA_CD, '
		|| '                          H03.MGR_CD, '
		|| '                          H03.KAIKEI_KBN, '
		|| '                          WT04.HIKIUKE_RATE) WT02 '
		|| '                    ON (WT01.ITAKU_KAISHA_CD = WT02.ITAKU_KAISHA_CD '
		|| '                   AND WT01.MGR_CD = WT02.MGR_CD '
		|| '                   AND WT01.KAIKEI_KBN = WT02.KAIKEI_KBN) '
		|| '                LEFT OUTER JOIN (SELECT H03.ITAKU_KAISHA_CD, '
		|| '                         H03.MGR_CD, '
		|| '                         H03.KAIKEI_KBN, '
		|| '                         COALESCE(WT05.KANJI_RATE,0) AS KANJI_RATE, '
		|| '                         SUM(H03.ANBUN_TESU_KNGK_KOMI) AS KANJI_GK, '
		|| '                         SUM(H03.ANBUN_TESU_SZEI) AS KANJI_SZEI '
		|| '                    FROM TESURYO_KAIKEI H03 '                    -- 手数料計算結果（会計区分別）
		|| '                    LEFT OUTER JOIN (SELECT H03.ITAKU_KAISHA_CD, '
		|| '                                  H03.MGR_CD, '
		|| '                                  MAX(H03.RATE_BUNSHI / H03.RATE_BUNBO * 100) AS KANJI_RATE '
 			|| '                         FROM TESURYO_KAIKEI H03 ' -- 手数料計算結果（会計区分別）
		|| '                          WHERE H03.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' ';
		IF (trim(both l_inMgrCd) IS NOT NULL AND (trim(both l_inMgrCd))::text <> '') THEN
			gSQL := gSQL || '                 			AND H03.MGR_CD = ''' || l_inMgrCd || ''' ';
		END IF;
		gSQL := gSQL || ' 							AND H03.CHOKYU_YMD BETWEEN ''' || l_inKijyunYmdF || ''' AND ''' || l_inKijyunYmdT || ''' '
		|| '                            AND H03.TESU_SHURUI_CD = ''32'' '
		|| '                            AND H03.KAIKEI_KBN <> ''00'' '
		|| '                            AND H03.RATE_BUNBO > 0 '		-- 0除算対策
		|| '                         GROUP BY H03.ITAKU_KAISHA_CD, H03.MGR_CD) WT05 '
		|| '                    ON (H03.ITAKU_KAISHA_CD = WT05.ITAKU_KAISHA_CD '
		|| '                   AND H03.MGR_CD = WT05.MGR_CD) '
		|| '                 WHERE H03.CHOKYU_YMD BETWEEN ''' || l_inKijyunYmdF || ''' AND ''' || l_inKijyunYmdT || ''' '
		|| '                   AND H03.TESU_SHURUI_CD = ''32'' '
		|| '                   AND H03.KAIKEI_KBN <> ''00'' '
		|| '                 GROUP BY H03.ITAKU_KAISHA_CD, '
		|| '                          H03.MGR_CD, '
		|| '                          H03.KAIKEI_KBN, '
		|| '                          WT05.KANJI_RATE) WT06 '
		|| '                    ON (WT01.ITAKU_KAISHA_CD = WT06.ITAKU_KAISHA_CD '
		|| '                   AND WT01.MGR_CD = WT06.MGR_CD '
		|| '                   AND WT01.KAIKEI_KBN = WT06.KAIKEI_KBN) '
		|| '                LEFT OUTER JOIN (SELECT H03.ITAKU_KAISHA_CD, '
		|| '                         H03.MGR_CD, '
		|| '                         H03.KAIKEI_KBN, '
		|| '                         SUM(H03.ANBUN_TESU_KNGK_KOMI) AS SHINKI_GK, '
		|| '                         SUM(H03.ANBUN_TESU_SZEI) AS SHINKI_SZEI '
		|| '                    FROM TESURYO_KAIKEI H03, '		-- 手数料計算結果（会計区分別）
		|| '                         (SELECT H03.ITAKU_KAISHA_CD, '
		|| '                                  H03.MGR_CD '
		|| '                         FROM TESURYO_KAIKEI H03 '	-- 手数料計算結果（会計区分別）
		|| '                          WHERE H03.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' ';
		IF (trim(both l_inMgrCd) IS NOT NULL AND (trim(both l_inMgrCd))::text <> '') THEN
			gSQL := gSQL || '                 			AND H03.MGR_CD = ''' || l_inMgrCd || ''' ';
		END IF;
		gSQL := gSQL || ' 							AND H03.CHOKYU_YMD BETWEEN ''' || l_inKijyunYmdF || ''' AND ''' || l_inKijyunYmdT || ''' '
		|| '                            AND H03.TESU_SHURUI_CD = ''51'' '
		|| '                            AND H03.KAIKEI_KBN <> ''00'' '
		|| '                         GROUP BY H03.ITAKU_KAISHA_CD, H03.MGR_CD) WT07 '
		|| '                 WHERE H03.ITAKU_KAISHA_CD = WT07.ITAKU_KAISHA_CD '
		|| '                   AND H03.MGR_CD = WT07.MGR_CD '
		|| '                   AND H03.CHOKYU_YMD BETWEEN ''' || l_inKijyunYmdF || ''' AND ''' || l_inKijyunYmdT || ''' '
		|| '                   AND H03.TESU_SHURUI_CD = ''51'' '
		|| '                   AND H03.KAIKEI_KBN <> ''00'' '
		|| '                 GROUP BY H03.ITAKU_KAISHA_CD, '
		|| '                          H03.MGR_CD, '
		|| '                          H03.KAIKEI_KBN) WT08 '
		|| '                    ON (WT01.ITAKU_KAISHA_CD = WT08.ITAKU_KAISHA_CD '
		|| '                   AND WT01.MGR_CD = WT08.MGR_CD '
		|| '                   AND WT01.KAIKEI_KBN = WT08.KAIKEI_KBN)) AT03 '
		|| ' WHERE AT01.ITAKU_KAISHA_CD = AT02.ITAKU_KAISHA_CD '
		|| '   AND AT02.ITAKU_KAISHA_CD = AT03.ITAKU_KAISHA_CD '
		|| '   AND AT01.MGR_CD = AT03.MGR_CD '
		|| '   AND AT02.MGR_CD = AT03.MGR_CD '
		|| '   AND TRIM(AT01.ISIN_CD) IS NOT NULL '
		|| '   AND AT02.KAIKEI_KBN = AT03.KAIKEI_KBN '
		|| ' ORDER BY AT01.HKT_CD, '
		|| '  AT01.CHOKYU_YMD, '
		|| '  AT01.ISIN_CD, '
		|| '  AT03.KAIKEI_KBN ';
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spiph003k00r01_createsql () FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spiph003k00r01_updateinvoiceitem (
	in_TsukaCd text,
	l_inItakuKaishaCd TEXT,
	l_inUserId VARCHAR,
	l_inChohyoKbn TEXT,
	l_inGyomuYmd TEXT,
	REPORT_ID TEXT,
	INOUT gRtnCd integer,
	INOUT gSzeiKijunYmd char,
	INOUT gSzeiRate varchar,
	INOUT gInvoiceTesuLabel varchar,
	INOUT gTesuGTotal numeric,
	INOUT gInvoiceUchiSzei numeric,
	INOUT gShnkTesuryoTotal numeric,
	INOUT gInvoiceUchiSzeiT numeric,
	INOUT gFurikomiTotal numeric,
	INOUT gWrkStSiharaiYmd char,
	INOUT gWrkHktCd varchar,
	INOUT gWrkIsinCd varchar
) AS $body$
BEGIN
	gRtnCd := pkconstant.error();
	-- 適格請求書_手数料ラベル編集
	gSzeiRate := pkIpaZei.getShohiZeiRate(gSzeiKijunYmd);
	gInvoiceTesuLabel := '（' || substr('　' || oracle.to_multi_byte(gSzeiRate), -2) || '％対象）';
	-- 手数料割戻消費税算出
	IF gTesuGTotal = 0 THEN
		gInvoiceUchiSzei := NULL;
	ELSE
		gInvoiceUchiSzei := PKIPACALCTESUKNGK.getTesuZeiWarimodoshi(
								 gSzeiKijunYmd
								,gTesuGTotal
								,in_TsukaCd
							);
	END IF;
	-- 手数料（立替払）割戻消費税算出
	IF gShnkTesuryoTotal = 0 THEN
		gInvoiceUchiSzeiT := NULL;
	ELSE
		gInvoiceUchiSzeiT := PKIPACALCTESUKNGK.getTesuZeiWarimodoshi(
								 gSzeiKijunYmd
								,gShnkTesuryoTotal
								,in_TsukaCd
							);
	END IF;
	-- 同じページのレコードのインボイス項目を更新
	UPDATE	SREPORT_WK
	SET		 ITEM035	=	gFurikomiTotal 			-- 適格請求書_振込額合計
			,ITEM040	=	gInvoiceTesuLabel 		-- 適格請求書_手数料ラベル
			,ITEM041	=	gTesuGTotal 				-- 適格請求書_手数料合計
			,ITEM042	=	gInvoiceUchiSzei 		-- 適格請求書_内消費税
			,ITEM045	=	gShnkTesuryoTotal 		-- 適格請求書_手数料合計（立替払）
			,ITEM046	=	gInvoiceUchiSzeiT 		-- 適格請求書_内消費税（立替払）
			,ITEM047	=	gSzeiKijunYmd 			-- 消費税基準日(ジャーナル)
			,ITEM048	=	gSzeiRate 				-- 消費税率(ジャーナル)
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID
	AND		HEADER_FLG = '1'
	AND		coalesce(trim(both ITEM039)::text, '') = ''		-- 対象データなし でないもの
	AND		trim(both coalesce(ITEM010, '')) = trim(both coalesce(gWrkStSiharaiYmd, ''))	--徴求日
	AND		trim(both coalesce(ITEM002, '')) = trim(both coalesce(gWrkHktCd, ''))			--発行体コード
	AND		trim(both coalesce(ITEM006, '')) = trim(both coalesce(gWrkIsinCd, ''))			--ISINコード
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
-- REVOKE ALL ON PROCEDURE spiph003k00r01_updateinvoiceitem (in_TsukaCd text) FROM PUBLIC;