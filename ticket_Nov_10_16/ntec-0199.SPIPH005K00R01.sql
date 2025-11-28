


DROP TYPE IF EXISTS spiph005k00r01_type_record CASCADE;
CREATE TYPE spiph005k00r01_type_record AS (
		 gIdoYmd				char(8)					-- 異動年月日
		,gKaikeiKbn				char(2)				-- 会計区分
		,gKaikeiKbnNm			varchar(40)					-- 会計区分名称
		,gInputNum				numeric(2)						-- 出力順
		,gHktCd					char(6)							-- 発行体コード
		,gTokijoYakushokuNm		varchar(50)				-- 登記上役職名称
		,gTokijoDelegateNm		varchar(50)				-- 登記上代表者名称
		,gAdd1x1				varchar(50) 							-- 住所１−１
		,gAdd1x2				varchar(50) 							-- 住所１−２
		,gAdd1x3				varchar(50) 							-- 住所１−３
		,gBankNm				varchar(40) 						-- 銀行名称
		,gDelegateNm			varchar(100)									-- 代表者名称
		,gTsukaCd				char(3)					-- 通貨コード
		,gTsukaNm				char(3)							-- 通貨名称
		,gIsinCd				char(12)							-- ISINコード
		,gKokyakuMgrRNm			varchar(52)					-- 対顧用銘柄略称
		,gKknZndkKakuteiKbn		char(1)			-- 基金残高確定区分
		,gSzeiSeikyuKbn			char(1)			-- 消費税請求区分
		,gRbrYmd				char(8)					-- 元利払日
		,gRbrKjt				char(8)					-- 元利払期日
		,gCodeNm				varchar(40)								-- 基金請求種類略称
		,gFunitSknShrKngk		decimal(16,2)		-- 振替単位償還支払金額
		,gKakushasaiKngk		numeric(14)			-- 各社債の金額
		,gShokanPremium			numeric(14)			-- 償還プレミアム
		,gTsukarishiKngk		decimal(14,13)			-- １通貨あたりの利子金額
		,gKijunZndk				numeric(14)				-- 基準残高
		,gZndkKijunYmd			char(8)			-- 残高基準日
		,gGankin				decimal(16,2)					-- 元金
		,gRkn					decimal(14,2)						-- 利金
		,gGnknShrTesuBunbo		numeric(5)		-- 元金支払手数料率（分子）
		,gGnknShrTesuBunshi		decimal(17,14)		-- 元金支払手数料率（分母）
		,gRknShrTesuBunbo		numeric(5)		-- 利金支払手数料率（分子）
		,gRknShrTesuBunshi		decimal(17,14)		-- 利金支払手数料率（分母）
		,gGnknShrTesuKngk		decimal(14,2)		-- 元金支払手数料金額
		,gRknShrTesuKngk		decimal(14,2)			-- 利金支払手数料金額
		,gSeikyuKngk			decimal(14,2)				-- 請求金額
		,gSzeiKngk				decimal(12,2)					-- 内消費税
		,gKozaFuriKbn			char(2)					-- 口座振替区分
		,gBankRnm				varchar(20) 						-- 銀行略称
		,gNyukinShitenNm		varchar(50)							-- 振込入金_支店名
		,gKozaFrkShitenNm		varchar(50)							-- 口座振替_支店名
		,gNyukinKamokuNm		varchar(40)								-- 振込入金_口座科目名称
		,gKozaFrkKamokuNm		varchar(40)								-- 口座振替_口座科目名称
		,gKozaNo				char(7)							-- 口座番号
		,gHkoKozaNo				char(7)						-- 自動引落口座_口座番号
		,gKozameigininNm		varchar(30)					-- 口座名義人
		,gHkoKozaMeigininNm		varchar(70)				-- 自動引落口座_口座名義人
		,gTesuShuruiNm			varchar(2)										-- 手数料種類名
		,gWkKozaTenNm			varchar(50)									-- 口座店
		,gWkKozaKamokuNm		varchar(6)										-- 口座科目名
		,gWkKozaNo				char(7)											-- 口座番号
		,gWkKozaMeigininNm		varchar(70)				-- 口座名義人
);

-- Drop existing procedures with all versions
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN 
        SELECT proname, oidvectortypes(proargtypes) as argtypes
        FROM pg_proc 
        WHERE proname IN ('spiph005k00r01', 'spiph005k00r01_createsql', 'spiph005k00r01_updateinvoiceitem', 'spiph005k00r01_changezero2space')
        AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'rh_mufg_ipa')
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS rh_mufg_ipa.' || r.proname || '(' || r.argtypes || ') CASCADE';
        EXECUTE 'DROP PROCEDURE IF EXISTS rh_mufg_ipa.' || r.proname || '(' || r.argtypes || ') CASCADE';
    END LOOP;
END $$;

CREATE OR REPLACE PROCEDURE spiph005k00r01 ( l_inChohyoSakuKbn TEXT,		-- 帳票作成区分
 l_inHktCd TEXT,		-- 発行体コード
 l_inKozaTenCd TEXT,		-- 口座店コード
 l_inKozaTenCifCd TEXT,		-- 口座店CIFコード
 l_inMgrCd TEXT,		-- 銘柄コード
 l_inIsinCd TEXT,		-- ISINコード
 l_inKijyunYmdF TEXT,		-- 基準日(FROM)
 l_inKijyunYmdT TEXT,		-- 基準日(TO)
 l_inTuchiYmd TEXT,		-- 通知日
 l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inUserId text,	-- ユーザーID
 l_inChohyoKbn TEXT,		-- 帳票区分
 l_inGyomuYmd TEXT,		-- 業務日付
 l_outSqlCode OUT integer,		-- リターン値
 l_outSqlErrM OUT TEXT 		-- エラーコメント
 ) AS $body$
DECLARE

--
--/* 著作権:Copyright(c)2004
--/* 会社名:JIP
--/* 概要　:各種バッチ帳票出力指示画面および顧客宛帳票出力指示画面の入力条件により、
--/*		  公社債元利金支払基金請求書（会計区分別）を作成する。
--/* 引数　:	l_inChohyoSakuKbn	IN	TEXT		帳票作成区分
--/*			l_inHktCd			IN	TEXT		発行体コード/
--/*			l_inMgrCd			IN	TEXT		銘柄コード
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
--/* @version $Id: SPIPH005K00R01.SQL,v 1.35 2023/07/25 05:57:03 kentaro_ikeda Exp $
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
	RTN_OK				CONSTANT integer	:= 0;					-- 正常
	RTN_NG				CONSTANT integer	:= 1;					-- 予期したエラー
	RTN_NODATA			CONSTANT integer	:= 2;					-- データなし
	RTN_FATAL			CONSTANT integer	:= 99;					-- 予期せぬエラー
	REPORT_ID			CONSTANT char(11)	:= 'IPH30000511';		-- 帳票ID
	-- 書式フォーマット
	FMT_HAKKO_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	FMT_HAKKO_KNGK_J2	CONSTANT char(22)	:= 'Z,ZZZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額（インボイス項目用）
	FMT_RBR_KNGK_J		CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 利払金額
	FMT_SHOKAN_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 償還金額
	FMT_TSUKA_CD_J    	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 通貨コードフォーマット
	FMT_TESU_RITSU_BUNSHI  CONSTANT char(11)	:= 'ZZ9.9999999';	-- 通貨コードフォーマット
	TITLE_SEIKYUSHO		CONSTANT char(26)	:= '公社債元利金支払基金請求書';
	TITLE_SEIKYUHKE		CONSTANT char(30)	:= '公社債元利金支払基金請求書(控)';
--==============================================================================
--					変数定義													
--==============================================================================
	TITLE_OUTPUT		varchar(30) := NULL;					-- 帳票タイトル
	gRtnCd				integer :=	RTN_OK;						-- リターンコード
	gSeqNo				integer :=	0;							-- シーケンス
	gLopNo				integer :=	0;							-- ループ番号
	gSQL				text	:= NULL;				-- SQL編集
	-- DB取得項目
	-- 配列定義
	recMeisai spiph005k00r01_type_record[];
	tempRec spiph005k00r01_type_record;
	-- 西暦変換用
	gWrkStTuchiYmd		varchar(20) := NULL;					-- 通知日
	gWrkStSiharaiYmd	varchar(20) := NULL;					-- 支払日
	gEditZandakaYm		varchar(20) := NULL;					-- 残高基準日
	-- 宛名編集用
	gTokiDelegateNm		varchar(100) := NULL;					-- 登記上代表者名称
	-- 合計計算用
	gWrkIdoYmd			char(8) := NULL;						-- 支払日
	gWrkHktCd			varchar(6) := NULL;					-- 発行体コード
	gWrkKikiKbn			char(2) := NULL;						-- 会計区分
	gWrkTukaCd			char(3) := NULL;						-- 通貨コード
	gWrkKozaFuriKbn		char(2) := NULL;						-- 口座振替区分
	gWrkSeikyuTotal		numeric(16) := 0;						-- 請求金額合計(ワーク)
	gSeikyuTotal		numeric(16) := 0;						-- 請求金額合計
	-- 処理制御値
	gresult varchar(1) := NULL;
	-- 口座情報編集
	gKozaTenNm			varchar(100); 								-- 口座店名称
	-- 地公体請求書顧客口座出力フラグ(自行情報マスタ)
	gChikokozaPrintFlg	char(1);
	gKozaPrintFlg		char(1);
	-- カーソル
	curMeisai REFCURSOR;
	-- インボイス用
	gAryBun					varchar[];						-- インボイス文章(請求書)配列
	gInvoiceBun				varchar(400);					-- インボイス文章
	gInvoiceTourokuNo		varchar(14);	-- 適格請求書発行事業者登録番号
	gInvoiceKknTesuLabel	varchar(20);							-- 基金および手数料ラベル
	gInvoiceTesuLabel		varchar(20);							-- 手数料ラベル
	gWrkHikazeiFlg			varchar(1);			-- 非課税免税フラグ
	gWrkHikazeiNm			varchar(40);						-- 非課税免税名称
	gWrkHikazeiTotal		numeric(16) := 0;					-- 基金・手数料(非課税分)合計(ワーク)
	gWrkKazeiTotal			numeric(16) := 0;					-- 手数料(課税分)合計(ワーク)
	gInvoiceKknTesuKngkSum	numeric(16) := 0;					-- 適格請求書_基金および手数料合計
	gInvoiceTesuKngkSum		numeric(16) := 0;					-- 適格請求書_手数料合計
	gInvoiceUchiSzei		numeric(16) := 0;					-- 適格請求書_内消費税
	gSzeiRate				numeric(2);								-- 適格請求書_消費税率
	gSzeiKijunYmd			char(8);
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPH005K00R01 START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inKijyunYmdF)::text, '') = ''					-- 基準日(FROM)
	OR coalesce(trim(both l_inKijyunYmdT)::text, '') = ''					-- 基準日(TO)
	OR coalesce(trim(both l_inChohyoSakuKbn)::text, '') = ''				-- 帳票作成区分
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
	-- 処理制御値取得
	gresult := pkControl.getCtlValue( l_inItakuKaishaCd, 'ChikoList', '0');
	-- SQL編集
	CALL rh_mufg_ipa.SPIPH005K00R01_createSQL(l_inItakuKaishaCd, l_inHktCd, l_inKozaTenCd, l_inKozaTenCifCd, l_inMgrCd, l_inIsinCd, l_inKijyunYmdF, l_inKijyunYmdT, l_inChohyoKbn, l_inGyomuYmd, gresult, gSQL);
	-- 地公体請求書顧客口座出力フラグ、適格請求書発行事業者登録番号(自行情報マスタ)を取得する。
	SELECT CHIKOKOZA_PRINT_FLG, INVOICE_TOUROKU_NO
	INTO STRICT gChikokozaPrintFlg, gInvoiceTourokuNo
	FROM VJIKO_ITAKU
	WHERE KAIIN_ID = l_inItakuKaishaCd;
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
	FOR i IN 1..coalesce(cardinality(gAryBun), 0) LOOP
		IF i = 1 THEN
			gInvoiceBun := gAryBun[i];
		END IF;
	END LOOP;
	-- カーソルオープン
	OPEN curMeisai FOR EXECUTE gSQL;
	-- データ取得
	LOOP
		FETCH curMeisai INTO
									 tempRec.gIdoYmd 				-- 異動年月日
									,tempRec.gKaikeiKbn 			-- 会計区分
									,tempRec.gKaikeiKbnNm 			-- 会計区分名称
									,tempRec.gInputNum 			-- 出力順
									,tempRec.gHktCd 				-- 発行体コード
									,tempRec.gTokijoYakushokuNm 	-- 登記上役職名称
									,tempRec.gTokijoDelegateNm 	-- 登記上代表者名称
									,tempRec.gAdd1x1				-- 住所１−１
									,tempRec.gAdd1x2				-- 住所１−２
									,tempRec.gAdd1x3				-- 住所１−３
									,tempRec.gBankNm 				-- 銀行名称
									,tempRec.gDelegateNm 			-- 代表者名称
									,tempRec.gTsukaCd 				-- 通貨コード
									,tempRec.gTsukaNm 				-- 通貨名称
									,tempRec.gIsinCd 				-- ISINコード
									,tempRec.gKokyakuMgrRNm 		-- 対顧用銘柄略称
									,tempRec.gKknZndkKakuteiKbn 	-- 基金残高確定区分
									,tempRec.gSzeiSeikyuKbn 		-- 消費税請求区分
									,tempRec.gRbrYmd 				-- 元利払日
									,tempRec.gRbrKjt 				-- 元利払期日
									,tempRec.gCodeNm 				-- 基金請求種類略称
									,tempRec.gFunitSknShrKngk 		-- 振替単位償還支払金額
									,tempRec.gKakushasaiKngk 		-- 各社債の金額
									,tempRec.gShokanPremium 		-- 償還プレミアム
									,tempRec.gTsukarishiKngk 		-- １通貨あたりの利子金額
									,tempRec.gKijunZndk 			-- 基準残高
									,tempRec.gZndkKijunYmd 		-- 残高基準日
									,tempRec.gGankin 				-- 元金
									,tempRec.gRkn 					-- 利金
									,tempRec.gGnknShrTesuBunbo 	-- 元金支払手数料率（分子）
									,tempRec.gGnknShrTesuBunshi 	-- 元金支払手数料率（分母）
									,tempRec.gRknShrTesuBunbo 		-- 利金支払手数料率（分子）
									,tempRec.gRknShrTesuBunshi 	-- 利金支払手数料率（分母）
									,tempRec.gGnknShrTesuKngk 		-- 元金支払手数料金額
									,tempRec.gRknShrTesuKngk 		-- 利金支払手数料金額
									,tempRec.gSeikyuKngk 			-- 請求金額
									,tempRec.gSzeiKngk 			-- 内消費税
									,tempRec.gKozaFuriKbn 			-- 口座振替区分
									,tempRec.gBankRnm 				-- 銀行名称
									,tempRec.gNyukinShitenNm 		-- 振込入金_支店名
									,tempRec.gKozaFrkShitenNm 		-- 口座振替_支店名
									,tempRec.gNyukinKamokuNm 		-- 振込入金_口座科目名称
									,tempRec.gKozaFrkKamokuNm 		-- 口座振替_口座科目名称
									,tempRec.gKozaNo 				-- 口座番号
									,tempRec.gHkoKozaNo 			-- 自動引落口座_口座番号
									,tempRec.gKozameigininNm 		-- 口座名義人
									,tempRec.gHkoKozaMeigininNm 	-- 自動引落口座_口座名義人
									,tempRec.gTesuShuruiNm 		-- 手数料種類名
									;
		EXIT WHEN NOT FOUND;/* apply on curMeisai */
		recMeisai := array_append(recMeisai, tempRec);
		gSeqNo := gSeqNo + 1;
	END LOOP;
	-- 通知日編集（西暦変換）
	gWrkStTuchiYmd := '      年  月  日';
	-- 随時、バッチ判定
	IF trim(both l_inChohyoKbn) = '0' THEN
		-- 随時		入力通知日
		IF (trim(both l_inTuchiYmd) IS NOT NULL AND (trim(both l_inTuchiYmd))::text <> '') THEN
			gWrkStTuchiYmd := pkDate.seirekiChangeSuppressNenGappi(l_inTuchiYmd);
		END IF;
	ELSE
		-- バッチ	業務日付
		IF (trim(both l_inGyomuYmd) IS NOT NULL AND (trim(both l_inGyomuYmd))::text <> '') THEN
			gWrkStTuchiYmd := pkDate.getYokuBusinessYmd(l_inGyomuYmd);
			gWrkStTuchiYmd := pkDate.seirekiChangeSuppressNenGappi(gWrkStTuchiYmd);
		END IF;
	END IF;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	--データ取得件数判定
	IF gSeqNo = 0 THEN
		-- 対象データなしの処理
		gRtnCd := RTN_NODATA;
		-- 随時、バッチ判定
		IF trim(both l_inChohyoKbn) = '0' THEN
			-- 随時の場合のみ、対象データなしデータを帳票ワークへデータへ出力
			CALL pkPrint.insertData(
				l_inKeyCd			=>	l_inItakuKaishaCd 					-- 識別コード
				,l_inUserId			=>	l_inUserId 							-- ユーザＩＤ
				,l_inChohyoKbn		=>	l_inChohyoKbn 						-- 帳票区分
				,l_inSakuseiYmd		=>	l_inGyomuYmd 						-- 作成年月日
				,l_inChohyoId		=>	REPORT_ID 							-- 帳票ＩＤ
				,l_inSeqNo			=>	1									-- 連番
				,l_inHeaderFlg		=>	'1'									-- ヘッダフラグ
				,l_inItem001		=>	TITLE_SEIKYUSHO 						-- 帳票タイトル：請求書
				,l_inItem003		=>	gWrkStTuchiYmd 						-- 通知日
				,l_inItem038		=>	FMT_HAKKO_KNGK_J2					-- 発行金額書式フォーマット（インボイス項目用）
				,l_inItem039		=>	FMT_HAKKO_KNGK_J 					-- 発行金額書式フォーマット
				,l_inItem040		=>	FMT_RBR_KNGK_J 						-- 利払金額書式フォーマット
				,l_inItem041		=>	FMT_SHOKAN_KNGK_J 					-- 償還金額書式フォーマット
				,l_inItem042		=>	'対象データなし'
				,l_inItem043		=>	FMT_TSUKA_CD_J 						-- 通貨コードフォーマット
				,l_inItem044		=>	FMT_TESU_RITSU_BUNSHI 				-- 手数料率分子フォーマット
				,l_inKousinId		=>	l_inUserId 							-- 更新者ID
				,l_inSakuseiId		=>	l_inUserId 							-- 作成者ID
			);
		END IF;
	ELSE
		-- 対象データ有りの処理
		-- １回目のループは請求書を出力するためのもの。
		-- ２回目のループは控を出力するためのものとする
		FOR j IN 0..1 LOOP
			-- ワークエリア初期化
			gWrkSeikyuTotal	:= 0;
			gWrkHikazeiTotal	:= 0;		-- 基金・手数料(非課税分)合計(ワーク)
			gWrkKazeiTotal		:= 0;		-- 手数料(課税分)合計(ワーク)
			gWrkIdoYmd		:= NULL;
			gWrkHktCd		:= NULL;
			gWrkKikiKbn		:= NULL;
			gWrkTukaCd		:= NULL;
			gWrkKozaFuriKbn	:= NULL;
			IF j = 0 THEN
			-- *********************************
			-- * ①請求書の出力
			-- *********************************
				TITLE_OUTPUT := TITLE_SEIKYUSHO;
			ELSE
			-- *********************************
			-- * ②請求書(控)の出力
			-- *********************************
				TITLE_OUTPUT := TITLE_SEIKYUHKE;
			END IF;
			FOR i IN 1..coalesce(cardinality(recMeisai), 0) LOOP
				gLopNo := gLopNo + 1;
				-- 合計データ出力判定（通貨コード・異動年月日・発行体コード・会計区分ブレイク）
				IF i <> 1 AND (gWrkTukaCd <> recMeisai[i].gTsukaCd			OR
								gWrkIdoYmd <> recMeisai[i].gIdoYmd			OR
								gWrkHktCd <> recMeisai[i].gHktCd 			OR
								gWrkKikiKbn <> recMeisai[i].gKaikeiKbn		OR
								gWrkKozaFuriKbn <> recMeisai[i].gKozaFuriKbn)	THEN
					-- 宛名編集（殿編集はFRM側で）
					gTokiDelegateNm := recMeisai[i-1].gTokijoDelegateNm;
					-- 支払日(異動年月日)の西暦変換
					gWrkStSiharaiYmd := NULL;
					IF (trim(both recMeisai[i-1].gIdoYmd) IS NOT NULL AND (trim(both recMeisai[i-1].gIdoYmd))::text <> '') THEN
						gWrkStSiharaiYmd := pkDate.seirekiChangeSuppressNenGappi(recMeisai[i-1].gIdoYmd);
					END IF;
					-- 合計エリアに集計した値をセット
					gSeikyuTotal := gWrkSeikyuTotal;
					gInvoiceKknTesuKngkSum := gWrkHikazeiTotal;
					gInvoiceTesuKngkSum := gWrkKazeiTotal;
					-- 合計レコード出力前に、明細レコードのインボイス項目を更新
					gSzeiKijunYmd := recMeisai[i-1].gRbrYmd;
					CALL spiph005k00r01_updateinvoiceitem(recMeisai[i-1].gTsukaCd, l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID, TITLE_OUTPUT, gRtnCd, gSzeiRate, gSzeiKijunYmd, gInvoiceTesuLabel, gInvoiceTesuKngkSum, gInvoiceUchiSzei, gSeikyuTotal, gInvoiceKknTesuKngkSum, gWrkStSiharaiYmd, gWrkHktCd, gWrkKikiKbn, gWrkTukaCd, gWrkKozaFuriKbn);
					IF gRtnCd <> pkconstant.success() THEN
						l_outSqlCode := gRtnCd;
						RETURN;
					END IF;
					-- ワークエリアの初期化
					gWrkSeikyuTotal := 0;
					gWrkHikazeiTotal := 0;		-- 基金・手数料(非課税分)合計(ワーク)
					gWrkKazeiTotal := 0;		-- 手数料(課税分)合計(ワーク)
					gWrkIdoYmd := recMeisai[i].gIdoYmd;
					gWrkHktCd := recMeisai[i].gHktCd;
					gWrkKikiKbn := recMeisai[i].gKaikeiKbn;
					gWrkTukaCd := recMeisai[i].gTsukaCd;
					gWrkKozaFuriKbn := recMeisai[i].gKozaFuriKbn;
					-- 口座出力フラグをセット(現金受取の場合はセットしない)
					IF recMeisai[i-1].gKozaFuriKbn = '50' THEN
						gKozaPrintFlg := '0';
					ELSE
						gKozaPrintFlg := gChikokozaPrintFlg;
					END IF;
					-- 帳票ワークへ合計データを出力
					CALL pkPrint.insertData(
						l_inKeyCd			=>	l_inItakuKaishaCd 						-- 識別コード
						,l_inUserId			=>	l_inUserId 								-- ユーザＩＤ
						,l_inChohyoKbn		=>	l_inChohyoKbn 							-- 帳票区分
						,l_inSakuseiYmd		=>	l_inGyomuYmd 							-- 作成年月日
						,l_inChohyoId		=>	REPORT_ID 								-- 帳票ＩＤ
						,l_inSeqNo			=>	gLopNo 									-- 連番
						,l_inHeaderFlg		=>	'1'										-- ヘッダフラグ
						,l_inItem001		=>	TITLE_OUTPUT 							-- 帳票タイトル：請求書or請求書(控)
						,l_inItem002		=>	gWrkStSiharaiYmd 						-- 支払日
						,l_inItem003		=>	gWrkStTuchiYmd 							-- 通知日
						,l_inItem004		=>	recMeisai[i-1].gKaikeiKbn 				-- 会計区分
						,l_inItem005		=>	recMeisai[i-1].gKaikeiKbnNm 				-- 会計区分名称
						,l_inItem006		=>	recMeisai[i-1].gHktCd 					-- 発行体コード
						,l_inItem007		=>	recMeisai[i-1].gTokijoYakushokuNm 		-- 登記上役職名称
						,l_inItem008		=>	gTokiDelegateNm 							-- 登記上代表者名称
						,l_inItem009		=>	recMeisai[i-1].gAdd1x1					-- 住所１−１
						,l_inItem010		=>	recMeisai[i-1].gAdd1x2					-- 住所１−２
						,l_inItem011		=>	recMeisai[i-1].gAdd1x3					-- 住所１−３
						,l_inItem012		=>	recMeisai[i-1].gBankNm 					-- 銀行名称
						,l_inItem013		=>	recMeisai[i-1].gDelegateNm 				-- 代表者名称
						,l_inItem014		=>	recMeisai[i-1].gTsukaCd 					-- 通貨コード
						,l_inItem015		=>	recMeisai[i-1].gTsukaNm 					-- 通貨名称
						,l_inItem037		=>	gSeikyuTotal 							-- 請求金額合計
						,l_inItem038		=>	FMT_HAKKO_KNGK_J2						-- 発行金額書式フォーマット（インボイス項目用）
						,l_inItem039		=>	FMT_HAKKO_KNGK_J 						-- 発行金額書式フォーマット
						,l_inItem040		=>	FMT_RBR_KNGK_J 							-- 利払金額書式フォーマット
						,l_inItem041		=>	FMT_SHOKAN_KNGK_J 						-- 償還金額書式フォーマット
						,l_inItem043		=>	FMT_TSUKA_CD_J 							-- 通貨コードフォーマット
						,l_inItem044		=>	FMT_TESU_RITSU_BUNSHI 					-- 手数料率分子フォーマット
						,l_inItem045		=>	gKozaPrintFlg  							-- 地公体請求書顧客口座出力フラグ
						,l_inItem046		=>	recMeisai[i-1].gWkKozaTenNm 				-- 口座店
						,l_inItem047		=>	recMeisai[i-1].gWkKozaKamokuNm 			-- 口座科目
						,l_inItem048		=>	recMeisai[i-1].gWkKozaNo 				-- 口座番号
						--,l_inItem049		=>	recMeisai(i-1).gWkKozaMeigininNm		-- 口座名義人
						,l_inItem049		=>	recMeisai[i-1].gKozaFuriKbn 				-- 口座振替区分
						,l_inItem051		=>	gInvoiceTourokuNo 						-- 適格請求書発行事業者登録番号
						,l_inItem052		=>	gInvoiceKknTesuLabel 					-- 適格請求書_基金および手数料ラベル
						,l_inItem053		=>	gInvoiceTesuLabel 						-- 適格請求書_手数料ラベル
						,l_inItem054		=>	gSeikyuTotal 							-- 適格請求書_請求額合計
						,l_inItem055		=>	gInvoiceKknTesuKngkSum 					-- 適格請求書_基金および手数料合計
						,l_inItem056		=>	gInvoiceTesuKngkSum 						-- 適格請求書_手数料合計
						,l_inItem057		=>	gInvoiceUchiSzei 						-- 適格請求書_内消費税
						,l_inItem058 		=>	gSzeiKijunYmd 							-- 消費税基準日(ジャーナル)
						,l_inItem059 		=>	gSzeiRate 								-- 消費税率(ジャーナル)
						,l_inItem060		=>	gInvoiceBun 								-- インボイス文章
						,l_inItem061		=>	recMeisai[i-1].gTokijoYakushokuNm 		-- 登記上役職名称(ジャーナル)
						,l_inItem062		=>	gTokiDelegateNm || '　殿'				-- 登記上代表者名称(ジャーナル)
						,l_inKousinId		=>	l_inUserId 								-- 更新者ID
						,l_inSakuseiId		=>	l_inUserId 								-- 作成者ID
					);
					gLopNo := gLopNo + 1;
				ELSE
					-- １件目の場合、ブレイクキーを退避
					IF i = 0 THEN
						gWrkIdoYmd := recMeisai[i].gIdoYmd;
						gWrkHktCd := recMeisai[i].gHktCd;
						gWrkKikiKbn := recMeisai[i].gKaikeiKbn;
						gWrkTukaCd := recMeisai[i].gTsukaCd;
						gWrkKozaFuriKbn := recMeisai[i].gKozaFuriKbn;
					END IF;
					-- 口座出力フラグをセット(現金受取の場合はセットしない)
					IF recMeisai[i].gKozaFuriKbn = '50' THEN
						gKozaPrintFlg := '0';
					ELSE
						gKozaPrintFlg := gChikokozaPrintFlg;
					END IF;
				END IF;
				-- 宛名編集（殿編集はFRM側で）
				gTokiDelegateNm := recMeisai[i].gTokijoDelegateNm;
				-- 支払日(異動年月日)の西暦変換
				gWrkStSiharaiYmd := NULL;
				IF (trim(both recMeisai[i].gIdoYmd) IS NOT NULL AND (trim(both recMeisai[i].gIdoYmd))::text <> '') THEN
					gWrkStSiharaiYmd := pkDate.seirekiChangeSuppressNenGappi(recMeisai[i].gIdoYmd);
				END IF;
				--地公体請求書顧客口座出力フラグがたっている場には以下の情報をセットする
				IF gChikokozaPrintFlg = 1	THEN
					-- 口座振替区分による各値の設定
					CASE SUBSTR(recMeisai[i].gKozaFuriKbn, 1, 1)
						WHEN '1' THEN 	-- 口座振替
							-- 口座店名称の編集
							gKozaTenNm := NULL;
							gRtnCd := pkIpaName.getKozaTenNm(recMeisai[i].gBankNm,recMeisai[i].gKozaFrkShitenNm,gKozaTenNm);
							IF gRtnCd <> pkconstant.success() THEN
								l_outSqlCode := gRtnCd;
								RETURN;
							END IF;
							recMeisai[i].gWkKozaTenNm		:= gKozaTenNm;
							recMeisai[i].gWkKozaKamokuNm	:= recMeisai[i].gKozaFrkKamokuNm;
							recMeisai[i].gWkKozaNo			:= recMeisai[i].gHkoKozaNo;
							recMeisai[i].gWkKozaMeigininNm	:= recMeisai[i].gHkoKozaMeigininNm;
						WHEN '2' THEN 	-- 振込入金
							-- 口座店名称の編集
							gKozaTenNm := NULL;
							gRtnCd := pkIpaName.getKozaTenNm(recMeisai[i].gBankNm,recMeisai[i].gNyukinShitenNm,gKozaTenNm);
							IF gRtnCd <> pkconstant.success() THEN
								l_outSqlCode := gRtnCd;
								RETURN;
							END IF;
							recMeisai[i].gWkKozaTenNm		:= gKozaTenNm;
							recMeisai[i].gWkKozaKamokuNm	:= recMeisai[i].gNyukinKamokuNm;
							recMeisai[i].gWkKozaNo			:= recMeisai[i].gKozaNo;
							recMeisai[i].gWkKozaMeigininNm	:= recMeisai[i].gKozameigininNm;
						ELSE 	-- 他
							gKozaTenNm := NULL;
							recMeisai[i].gWkKozaTenNm		:= NULL;
							recMeisai[i].gWkKozaKamokuNm	:= NULL;
							recMeisai[i].gWkKozaNo			:= NULL;
							recMeisai[i].gWkKozaMeigininNm	:= NULL;
					END CASE;
				END IF;
				-- 残高基準日の編集(ZZZ9年Z9月末残高)
				IF (trim(both recMeisai[i].gZndkKijunYmd) IS NOT NULL AND (trim(both recMeisai[i].gZndkKijunYmd))::text <> '') THEN
					IF recMeisai[i].gZndkKijunYmd = PKDATE.getGetsumatsuYmd(recMeisai[i].gZndkKijunYmd,0) THEN
						gEditZandakaYm := '('||SUBSTR(recMeisai[i].gZndkKijunYmd,1,4)||'年'||SPIPH005K00R01_changeZero2Space(SUBSTR(recMeisai[i].gZndkKijunYmd,5,2))||'月末残高)';
					ELSE
						gEditZandakaYm := '('||SUBSTR(recMeisai[i].gZndkKijunYmd,1,4)||'年'||SPIPH005K00R01_changeZero2Space(SUBSTR(recMeisai[i].gZndkKijunYmd,5,2))||'月'||SPIPH005K00R01_changeZero2Space(SUBSTR(recMeisai[i].gZndkKijunYmd,7,2))||'日)';
					END IF;
				END IF;
				-- ワークエリアに合計を集計
				gWrkSeikyuTotal := gWrkSeikyuTotal + recMeisai[i].gSeikyuKngk;
				-- 適格請求書の合計を集計
				-- 元金・利金を非課税分合計に集計
				gWrkHikazeiTotal := gWrkHikazeiTotal + recMeisai[i].gGankin + recMeisai[i].gRkn;
				-- 手数料を集計
				IF recMeisai[i].gSzeiSeikyuKbn = '1' THEN
					-- 消費税請求区分：請求する の場合、課税分合計に集計
					gWrkKazeiTotal := gWrkKazeiTotal + recMeisai[i].gGnknShrTesuKngk + recMeisai[i].gRknShrTesuKngk;
				ELSE
					-- 消費税請求区分：請求しない の場合、非課税分合計に集計
					gWrkHikazeiTotal := gWrkHikazeiTotal + recMeisai[i].gGnknShrTesuKngk + recMeisai[i].gRknShrTesuKngk;
				END IF;
				-- 帳票ワークへ明細データを出力
				CALL pkPrint.insertData(
					l_inKeyCd			=>	l_inItakuKaishaCd 					-- 識別コード
					,l_inUserId			=>	l_inUserId 							-- ユーザＩＤ
					,l_inChohyoKbn		=>	l_inChohyoKbn 						-- 帳票区分
					,l_inSakuseiYmd		=>	l_inGyomuYmd 						-- 作成年月日
					,l_inChohyoId		=>	REPORT_ID 							-- 帳票ＩＤ
					,l_inSeqNo			=>	gLopNo 								-- 連番
					,l_inHeaderFlg		=>	'1'									-- ヘッダフラグ
					,l_inItem001		=>	TITLE_OUTPUT 						-- 帳票タイトル：請求書
					,l_inItem002		=>	gWrkStSiharaiYmd 					-- 支払日
					,l_inItem003		=>	gWrkStTuchiYmd 						-- 通知日
					,l_inItem004		=>	recMeisai[i].gKaikeiKbn 				-- 会計区分
					,l_inItem005		=>	recMeisai[i].gKaikeiKbnNm 			-- 会計区分名称
					,l_inItem006		=>	recMeisai[i].gHktCd 					-- 発行体コード
					,l_inItem007		=>	recMeisai[i].gTokijoYakushokuNm 		-- 登記上役職名称
					,l_inItem008		=>	gTokiDelegateNm 						-- 登記上代表者名称
					,l_inItem009		=>	recMeisai[i].gAdd1x1				-- 住所１−１
					,l_inItem010		=>	recMeisai[i].gAdd1x2				-- 住所１−２
					,l_inItem011		=>	recMeisai[i].gAdd1x3				-- 住所１−３
					,l_inItem012		=>	recMeisai[i].gBankNm 				-- 銀行名称
					,l_inItem013		=>	recMeisai[i].gDelegateNm 			-- 代表者名称	※殿
					,l_inItem014		=>	recMeisai[i].gTsukaCd 				-- 通貨コード
					,l_inItem015		=>	recMeisai[i].gTsukaNm 				-- 通貨名称
					,l_inItem016		=>	recMeisai[i].gIsinCd 				-- ISINコード
					,l_inItem017		=>	recMeisai[i].gKokyakuMgrRNm 			-- 対顧用銘柄略称
					,l_inItem018		=>	recMeisai[i].gRbrYmd 				-- 元利払日
					,l_inItem019		=>	recMeisai[i].gRbrKjt 				-- 元利払期日
					,l_inItem020		=>	recMeisai[i].gCodeNm 				-- 基金請求種類略称
					,l_inItem021		=>	recMeisai[i].gFunitSknShrKngk 		-- 振替単位償還支払金額
					,l_inItem022		=>	recMeisai[i].gKakushasaiKngk 		-- 各社債の金額
					,l_inItem023		=>	recMeisai[i].gShokanPremium 			-- 償還プレミアム
					,l_inItem024		=>	recMeisai[i].gTsukarishiKngk 		-- １通貨あたりの利子金額
					,l_inItem025		=>	recMeisai[i].gKijunZndk 				-- 基準残高
					,l_inItem026		=>	gEditZandakaYm 						-- 残高基準日
					,l_inItem027		=>	recMeisai[i].gGankin 				-- 元金
					,l_inItem028		=>	recMeisai[i].gRkn 					-- 利金
					,l_inItem029		=>	recMeisai[i].gGnknShrTesuBunbo 		-- 元金支払手数料率（分母）
					,l_inItem030		=>	recMeisai[i].gGnknShrTesuBunshi 		-- 元金支払手数料率（分子）
					,l_inItem031		=>	recMeisai[i].gRknShrTesuBunbo 		-- 利金支払手数料率（分母）
					,l_inItem032		=>	recMeisai[i].gRknShrTesuBunshi 		-- 利金支払手数料率（分子）
					,l_inItem033		=>	recMeisai[i].gGnknShrTesuKngk 		-- 元金支払手数料金額
					,l_inItem034		=>	recMeisai[i].gRknShrTesuKngk 		-- 利金支払手数料金額
					,l_inItem035		=>	recMeisai[i].gSeikyuKngk 			-- 請求金額
					,l_inItem036		=>	recMeisai[i].gSzeiKngk 				-- 内消費税
					,l_inItem038		=>	FMT_HAKKO_KNGK_J2					-- 発行金額書式フォーマット（インボイス項目用）
					,l_inItem039		=>	FMT_HAKKO_KNGK_J 					-- 発行金額書式フォーマット
					,l_inItem040		=>	FMT_RBR_KNGK_J 						-- 利払金額書式フォーマット
					,l_inItem041		=>	FMT_SHOKAN_KNGK_J 					-- 償還金額書式フォーマット
					,l_inItem043		=>	FMT_TSUKA_CD_J 						-- 通貨コードフォーマット
					,l_inItem044		=>	FMT_TESU_RITSU_BUNSHI 				-- 手数料率分子フォーマット
					,l_inItem045		=>	gKozaPrintFlg  						-- 地公体請求書顧客口座出力フラグ
					,l_inItem046		=>	recMeisai[i].gWkKozaTenNm 			-- 口座店
					,l_inItem047		=>	recMeisai[i].gWkKozaKamokuNm 		-- 口座科目
					,l_inItem048		=>	recMeisai[i].gWkKozaNo 				-- 口座番号
					--,l_inItem049		=>	recMeisai(i).gWkKozaMeigininNm		-- 口座名義人
					,l_inItem049		=>	recMeisai[i].gKozaFuriKbn 			-- 口座振替区分
					,l_inItem050		=>	recMeisai[i].gTesuShuruiNm 			-- 手数料種類名
					,l_inItem051		=>	gInvoiceTourokuNo 					-- 適格請求書発行事業者登録番号
					,l_inItem052		=>	gInvoiceKknTesuLabel 				-- 適格請求書_基金および手数料ラベル
					,l_inItem060 		=>	gInvoiceBun 							-- インボイス文章
					,l_inItem061		=>	recMeisai[i].gTokijoYakushokuNm 		-- 登記上役職名称(ジャーナル)
					,l_inItem062		=>	gTokiDelegateNm || '　殿'			-- 登記上代表者名称(ジャーナル)
					,l_inKousinId		=>	l_inUserId 							-- 更新者ID
					,l_inSakuseiId		=>	l_inUserId 							-- 作成者ID
				);
			END LOOP;
			-- 最後の合計行を出力
			gLopNo := gLopNo + 1;
			-- 合計のセット
			gSeikyuTotal := gWrkSeikyuTotal;
			gInvoiceKknTesuKngkSum := gWrkHikazeiTotal;
			gInvoiceTesuKngkSum := gWrkKazeiTotal;
			-- 最終ページの合計レコード出力前に、最終ページの明細レコードのインボイス項目を更新
			gSzeiKijunYmd := recMeisai[coalesce(cardinality(recMeisai), 0)-1].gRbrYmd;
			CALL spiph005k00r01_updateinvoiceitem(recMeisai[COALESCE(cardinality(recMeisai), 0)-1].gTsukaCd, l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID, TITLE_OUTPUT, gRtnCd, gSzeiRate, gSzeiKijunYmd, gInvoiceTesuLabel, gInvoiceTesuKngkSum, gInvoiceUchiSzei, gSeikyuTotal, gInvoiceKknTesuKngkSum, gWrkStSiharaiYmd, gWrkHktCd, gWrkKikiKbn, gWrkTukaCd, gWrkKozaFuriKbn);
			IF gRtnCd <> pkconstant.success() THEN
				l_outSqlCode := gRtnCd;
				RETURN;
			END IF;
			-- 帳票ワークへ合計データを出力
			CALL pkPrint.insertData(
				l_inKeyCd			=>	l_inItakuKaishaCd 								-- 識別コード
				,l_inUserId			=>	l_inUserId 										-- ユーザＩＤ
				,l_inChohyoKbn		=>	l_inChohyoKbn 									-- 帳票区分
				,l_inSakuseiYmd		=>	l_inGyomuYmd 									-- 作成年月日
				,l_inChohyoId		=>	REPORT_ID 										-- 帳票ＩＤ
				,l_inSeqNo			=>	gLopNo 											-- 連番
				,l_inHeaderFlg		=>	'1'												-- ヘッダフラグ
				,l_inItem001		=>	TITLE_OUTPUT 									-- 帳票タイトル：請求書
				,l_inItem002		=>	gWrkStSiharaiYmd 								-- 支払日
				,l_inItem003		=>	gWrkStTuchiYmd 									-- 通知日
				,l_inItem004		=>	recMeisai[COALESCE(cardinality(recMeisai), 0)-1].gKaikeiKbn 			-- 会計区分
				,l_inItem005		=>	recMeisai[COALESCE(cardinality(recMeisai), 0)-1].gKaikeiKbnNm 		-- 会計区分名称
				,l_inItem006		=>	recMeisai[COALESCE(cardinality(recMeisai), 0)-1].gHktCd 				-- 発行体コード
				,l_inItem007		=>	recMeisai[COALESCE(cardinality(recMeisai), 0)-1].gTokijoYakushokuNm 	-- 登記上役職名称
				,l_inItem008		=>	gTokiDelegateNm 									-- 登記上代表者名称
				,l_inItem009		=>	recMeisai[COALESCE(cardinality(recMeisai), 0)-1].gAdd1x1			-- 住所１−１
				,l_inItem010		=>	recMeisai[COALESCE(cardinality(recMeisai), 0)-1].gAdd1x2			-- 住所１−２
				,l_inItem011		=>	recMeisai[COALESCE(cardinality(recMeisai), 0)-1].gAdd1x3			-- 住所１−３
				,l_inItem012		=>	recMeisai[COALESCE(cardinality(recMeisai), 0)-1].gBankNm 			-- 銀行名称
				,l_inItem013		=>	recMeisai[COALESCE(cardinality(recMeisai), 0)-1].gDelegateNm 		-- 代表者名称
				,l_inItem014		=>	recMeisai[COALESCE(cardinality(recMeisai), 0)-1].gTsukaCd 			-- 通貨コード
				,l_inItem015		=>	recMeisai[COALESCE(cardinality(recMeisai), 0)-1].gTsukaNm 			-- 通貨名称
				,l_inItem037		=>	gSeikyuTotal 									-- 請求金額合計
				,l_inItem038		=>	FMT_HAKKO_KNGK_J2								-- 発行金額書式フォーマット（インボイス項目用）
				,l_inItem039		=>	FMT_HAKKO_KNGK_J 								-- 発行金額書式フォーマット
				,l_inItem040		=>	FMT_RBR_KNGK_J 									-- 利払金額書式フォーマット
				,l_inItem041		=>	FMT_SHOKAN_KNGK_J 								-- 償還金額書式フォーマット
				,l_inItem043		=>	FMT_TSUKA_CD_J 									-- 通貨コードフォーマット
				,l_inItem044		=>	FMT_TESU_RITSU_BUNSHI 							-- 手数料率分子フォーマット
				,l_inItem045		=>	gKozaPrintFlg  									-- 地公体請求書顧客口座出力フラグ
				,l_inItem046		=>	recMeisai[COALESCE(cardinality(recMeisai), 0)-1].gWkKozaTenNm 		-- 口座店
				,l_inItem047		=>	recMeisai[COALESCE(cardinality(recMeisai), 0)-1].gWkKozaKamokuNm 	-- 口座科目
				,l_inItem048		=>	recMeisai[COALESCE(cardinality(recMeisai), 0)-1].gWkKozaNo 			-- 口座番号
				--,l_inItem049		=>	recMeisai(COALESCE(cardinality(recMeisai), 0)-1).gWkKozaMeigininNm	-- 口座名義人
				,l_inItem049		=>	recMeisai[COALESCE(cardinality(recMeisai), 0)-1].gKozaFuriKbn 		-- 口座振替区分
				,l_inItem051		=>	gInvoiceTourokuNo 								-- 適格請求書発行事業者登録番号
				,l_inItem052		=>	gInvoiceKknTesuLabel 							-- 適格請求書_基金および手数料ラベル
				,l_inItem053		=>	gInvoiceTesuLabel 								-- 適格請求書_手数料ラベル
				,l_inItem054		=>	gSeikyuTotal 									-- 適格請求書_請求額合計
				,l_inItem055		=>	gInvoiceKknTesuKngkSum 							-- 適格請求書_基金および手数料合計
				,l_inItem056		=>	gInvoiceTesuKngkSum 								-- 適格請求書_手数料合計
				,l_inItem057		=>	gInvoiceUchiSzei 								-- 適格請求書_内消費税
				,l_inItem058 		=>	gSzeiKijunYmd 									-- 消費税基準日(ジャーナル)
				,l_inItem059 		=>	gSzeiRate 										-- 消費税率(ジャーナル)
				,l_inItem060		=>	gInvoiceBun 										-- インボイス文章
				,l_inItem061		=>	recMeisai[COALESCE(cardinality(recMeisai), 0)-1].gTokijoYakushokuNm 	-- 登記上役職名称(ジャーナル)
				,l_inItem062		=>	gTokiDelegateNm || '　殿'						-- 登記上代表者名称(ジャーナル)
				,l_inKousinId		=>	l_inUserId 										-- 更新者ID
				,l_inSakuseiId		=>	l_inUserId 										-- 作成者ID
				);
		END LOOP;
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
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gLopNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPH005K00R01 END');	END IF;
	-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
--		RAISE;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spiph005k00r01 ( l_inChohyoSakuKbn TEXT, l_inHktCd TEXT, l_inKozaTenCd TEXT, l_inKozaTenCifCd TEXT, l_inMgrCd TEXT, l_inIsinCd TEXT, l_inKijyunYmdF TEXT, l_inKijyunYmdT TEXT, l_inTuchiYmd TEXT, l_inItakuKaishaCd TEXT, l_inUserId text, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT TEXT  ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spiph005k00r01_changezero2space (inChar TEXT) RETURNS text AS $body$
BEGIN
	-- 一桁目が0の場合にスペースに付け替え
	IF SUBSTR(inChar,1,1) = '0' THEN
		RETURN ' '||SUBSTR(inChar,2,1);
	ELSE
		RETURN inChar;
	END IF;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spiph005k00r01_changezero2space (inChar TEXT) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spiph005k00r01_createsql (l_inItakuKaishaCd TEXT, l_inHktCd TEXT, l_inKozaTenCd TEXT, l_inKozaTenCifCd TEXT, l_inMgrCd TEXT, l_inIsinCd TEXT, l_inKijyunYmdF TEXT, l_inKijyunYmdT TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_inGresult TEXT, OUT gSQL text) AS $body$
BEGIN
	gSQL := '';
	gSQL := 'SELECT WT02.IDO_YMD, '					-- 異動年月日
		|| '		WT02.KAIKEI_KBN, '				-- 会計区分
		|| '		WT02.KAIKEI_KBN_NM, '			-- 会計区分名称
		|| '		WT02.INPUT_NUM, '				-- 会計区分入力順
		|| '		WT01.HKT_CD, '					-- 発行体コード
		|| '		WT01.TOKIJO_YAKUSHOKU_NM, '		-- 登記上役職名称
		|| '		WT01.TOKIJO_DELEGATE_NM, '		-- 登記上代表者名称
		|| '		WT01.ADD1X1, '					-- 住所１−１
		|| '		WT01.ADD1X2, '					-- 住所１−２
		|| '		WT01.ADD1X3, '					-- 住所１−３
		|| '		WT01.BANK_NM, '					-- 銀行名称
		|| '		WT01.DELEGATE_NM, '				-- 代表者名称
		|| '		WT02.TSUKA_CD, '				-- 通貨コード
		|| '		WT02.TSUKA_NM, '				-- 通貨名称
		|| '		WT01.ISIN_CD, '					-- ISINコード
		|| '		WT01.KOKYAKU_MGR_RNM, '			-- 対顧用銘柄略称
		|| '		WT01.KKN_ZNDK_KAKUTEI_KBN, '	-- 基金残高確定区分
		|| '		WT01.SZEI_SEIKYU_KBN, '			-- 消費税請求区分
		|| '		WT02.RBR_YMD, '					-- 元利払日
		|| '		WT02.RBR_KJT, '					-- 元利払期日
		|| '		WT02.CODE_RNM, '				-- 基金請求種類略称
		|| '		CASE WHEN WT02.FUNIT_SKN_SHR_KNGK = 0 THEN NULL ELSE WT02.FUNIT_SKN_SHR_KNGK END, '	-- 振替単位償還支払金額
		|| '		CASE WHEN WT02.KAKUSHASAI_KNGK = 0 THEN NULL ELSE WT02.KAKUSHASAI_KNGK END, '			-- 各社債の金額
		|| '		CASE WHEN WT02.SHOKAN_PREMIUM = 0 THEN NULL ELSE WT02.SHOKAN_PREMIUM END, '			-- 償還プレミアム
		|| '		WT02.TSUKARISHI_KNGK, '			-- １通貨あたりの利子金額
		|| '		WT02.KIJUN_ZNDK, '				-- 基準残高
		|| '		WT02.ZNDK_KIJUN_YMD, '			-- 残高基準日
		|| '		WT02.GANKIN, '					-- 元金
		|| '		WT02.RKN, '						-- 利金
		|| '		WT02.GNKN_SHR_TESU_BUNBO, '		-- 元金支払手数料率（分子）
		|| '		WT02.GNKN_SHR_TESU_BUNSHI, '	-- 元金支払手数料率（分母）
		|| '		WT02.RKN_SHR_TESU_BUNBO, '		-- 利金支払手数料率（分子）
		|| '		WT02.RKN_SHR_TESU_BUNSHI, '		-- 利金支払手数料率（分母）
		|| '		WT02.GNKN_SHR_TESU_KNGK, '		-- 元金支払手数料金額
		|| '		WT02.RKN_SHR_TESU_KNGK, '		-- 利金支払手数料金額
		|| '		WT02.SEIKYU_KNGK, '				-- 請求金額
		|| '		WT02.SZEI_KNGK, '				-- 内消費税
		|| '		WT01.KOZA_FURI_KBN, '			-- 口座振替区分
		|| '		WT01.BANK_RNM, '				-- 銀行略称
		|| '		WT01.NyukinShitenNm, '			-- 口座振替区分情報.口座店				= 振込入金_支店名
		|| '		WT01.KozaFrkShitenNm, '			-- 発行体マスタ.口座店					= 口座振替_支店名
		|| '		WT01.NyukinKamokuNm, '			-- 口座振替区分情報.口座科目			= 振込入金_口座科目名称
		|| '		WT01.KozaFrkKamokuNm, '			-- 発行体マスタ.自動引落口座口座科目	= 口座振替_口座科目名称
		|| '		WT01.KOZA_NO, '					-- 口座振替区分情報.口座番号
		|| '		WT01.HKO_KOZA_NO, '				-- 発行体マスタ.自動引落口座口座番号
		|| '		WT01.KOZAMEIGININ_NM, '			-- 口座振替区分情報.口座名義人
		|| '		WT01.HKO_KOZA_MEIGININ_NM, '		-- 発行体マスタ.自動引落口座口座名義人
		|| '		WT02.TESU_SHURUI_NM '			-- 手数料種類名
		|| '	FROM ( '
		|| '		SELECT VMG1.ITAKU_KAISHA_CD, '
		|| '				VMG1.MGR_CD, '
		|| '				M01.HKT_CD, '
		|| '				M01.TOKIJO_YAKUSHOKU_NM, '
		|| '				M01.TOKIJO_DELEGATE_NM, '
		|| '				VJI.ADD1X1, '
		|| '				VJI.ADD1X2, '
		|| '				VJI.ADD1X3, '
		|| '				VJI.BANK_NM, '
		|| '				VJI.BANK_RNM, '
		|| '				VJI.YAKUSHOKU_NM1 || '' '' || VJI.DELEGATE_NM1 AS DELEGATE_NM, '
		|| '				VMG1.ISIN_CD, '
		|| '				VMG1.KOKYAKU_MGR_RNM, '
		|| '				VMG1.KKN_ZNDK_KAKUTEI_KBN, '
		|| '				MG8.SZEI_SEIKYU_KBN, '
		|| '				VMG1.KOZA_FURI_KBN, '
		|| '				M040.BUTEN_NM AS NyukinShitenNm, '
		|| '				M041.BUTEN_NM AS KozaFrkShitenNm, '
		|| '				SC01.CODE_NM AS NyukinKamokuNm, '
		|| '				SC02.CODE_NM AS KozaFrkKamokuNm, '
		|| '				S06.KOZA_NO, '
		|| '				M01.HKO_KOZA_NO, '
		|| '				S06.KOZAMEIGININ_NM, '
		|| '				M01.HKO_KOZA_MEIGININ_NM '
		|| '		FROM MGR_KIHON_VIEW	VMG1 ' -- 銘柄_基本VIEW
		|| '				INNER JOIN MHAKKOTAI M01 '			-- 発行体マスタ
		|| '					ON VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD '
		|| '					AND VMG1.HKT_CD = M01.HKT_CD '
		|| '				INNER JOIN VJIKO_ITAKU VJI '		-- 自行・委託VIEW
		|| '					ON 1=1 '
		|| '				INNER JOIN MGR_TESURYO_PRM	MG8 '  -- 銘柄_手数料（計算情報）
		|| '					ON VMG1.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD '
		|| '					AND VMG1.MGR_CD = MG8.MGR_CD '
		|| '				LEFT JOIN KOZA_FRK		S06 '  -- 口座振替区分情報
		|| '					ON VMG1.ITAKU_KAISHA_CD = S06.ITAKU_KAISHA_CD '
		|| '					AND VMG1.KOZA_FURI_KBN = S06.KOZA_FURI_KBN '
		|| '				LEFT JOIN MBUTEN		M040 ' -- 部店マスタ
		|| '					ON S06.KOZA_TEN_CD = M040.BUTEN_CD '
		|| '				INNER JOIN MBUTEN		M041 '
		|| '					ON M01.KOZA_TEN_CD = M041.BUTEN_CD '
		|| '				LEFT JOIN SCODE			SC01 ' -- コードマスタ
		|| '					ON S06.KOZA_KAMOKU = SC01.CODE_VALUE '
		|| '					AND SC01.CODE_SHUBETSU = ''707'' '
		|| '				LEFT JOIN SCODE			SC02 '
		|| '					ON M01.HKO_KAMOKU_CD = SC02.CODE_VALUE '
		|| '					AND SC02.CODE_SHUBETSU = ''707'' '
		|| '		WHERE VMG1.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' '
		|| '			AND VMG1.MGR_STAT_KBN = ''1'' ';
	IF (trim(both l_inHktCd) IS NOT NULL AND (trim(both l_inHktCd))::text <> '') THEN
		gSQL := gSQL || ' AND	VMG1.HKT_CD			= ''' || l_inHktCd || '''';
	END IF;
	IF (trim(both l_inKozaTenCd) IS NOT NULL AND (trim(both l_inKozaTenCd))::text <> '') THEN
		gSQL := gSQL || ' AND	M01.KOZA_TEN_CD	= ''' || l_inKozaTenCd || '''';
	END IF;
	IF (trim(both l_inKozaTenCifCd) IS NOT NULL AND (trim(both l_inKozaTenCifCd))::text <> '') THEN
		gSQL := gSQL || ' AND	M01.KOZA_TEN_CIFCD	= ''' || l_inKozaTenCifCd || '''';
	END IF;
	IF (trim(both l_inMgrCd) IS NOT NULL AND (trim(both l_inMgrCd))::text <> '') THEN
		gSQL := gSQL || ' AND	VMG1.MGR_CD			= ''' || l_inMgrCd || '''';
	END IF;
	IF (trim(both l_inIsinCd) IS NOT NULL AND (trim(both l_inIsinCd))::text <> '') THEN
		gSQL := gSQL || ' AND	VMG1.ISIN_CD		= ''' || l_inIsinCd || '''';
	END IF;
		gSQL := gSQL || '		AND VJI.KAIIN_ID = ''' || l_inItakuKaishaCd || ''' '
		|| '		)WT01, '
		|| '		( '
						--	一般会計を取得するSQL
 			|| '			SELECT ITAKU_KAISHA_CD, '
		|| '				MGR_CD, '
		|| '				HKT_CD, '
		|| '				IDO_YMD, '
		|| '				KAIKEI_KBN, '
		|| '				KAIKEI_KBN_NM, '
		|| '				INPUT_NUM, '
		|| '				TSUKA_CD, '
		|| '				TSUKA_NM, '
		|| '				RBR_YMD, '
		|| '				RBR_KJT, '
		|| '				CODE_RNM, '
		|| '				FUNIT_SKN_SHR_KNGK, '
		|| '				KAKUSHASAI_KNGK, '
		|| '				SHOKAN_PREMIUM, '
		|| '				TSUKARISHI_KNGK, '
		|| '				KIJUN_ZNDK, '
		|| '				ZNDK_KIJUN_YMD, '
		|| '				GANKIN, '
		|| '				RKN, '
		|| '				GNKN_SHR_TESU_BUNBO, '
		|| '				GNKN_SHR_TESU_BUNSHI, '
		|| '				RKN_SHR_TESU_BUNBO, '
		|| '				RKN_SHR_TESU_BUNSHI, '
		|| '				GNKN_SHR_TESU_KNGK, '
		|| '				RKN_SHR_TESU_KNGK, '
		|| '				SEIKYU_KNGK, '
		|| '				SZEI_KNGK '
		|| '				,CASE TESU_SHURUI_CD WHEN ''61'' THEN ''元'' WHEN ''82'' THEN ''利'' ELSE ''　'' END AS TESU_SHURUI_NM '-- 手数料種類名
		|| '			FROM ( '
		|| '				SELECT	VMG1.ITAKU_KAISHA_CD, '
		|| '						VMG1.MGR_CD, '
		|| '						M01.HKT_CD, '
		|| '						H04.IDO_YMD, '
		|| '						H04.KAIKEI_KBN, '
		|| '						H01.KAIKEI_KBN_NM, '
		|| '						H01.INPUT_NUM, '
		|| '						H04.TSUKA_CD, '
		|| '						M64.TSUKA_NM, '
		|| '						H04.RBR_YMD, '
		|| '						H04.RBR_KJT, '
		|| '						MCD1.CODE_RNM, '
		|| '						H04.FUNIT_SKN_SHR_KNGK, '
		|| '						H04.KAKUSHASAI_KNGK, '
		|| '						H04.SHOKAN_PREMIUM, '
		|| '						H04.TSUKARISHI_KNGK, '
		|| '						H04.KIJUN_ZNDK, '
		|| '						H04.ZNDK_KIJUN_YMD, '
		|| '						H04.GANKIN, '
		|| '						H04.RKN, '
		|| '						H04.GNKN_SHR_TESU_BUNBO, '
		|| '						H04.GNKN_SHR_TESU_BUNSHI, '
		|| '						H04.RKN_SHR_TESU_BUNBO, '
		|| '						H04.RKN_SHR_TESU_BUNSHI, '
		|| '						H04.GNKN_SHR_TESU_KNGK, '
		|| '						H04.RKN_SHR_TESU_KNGK, '
		|| '						H04.SEIKYU_KNGK, '
		|| '						H04.SZEI_KNGK '
		|| '                       ,MG7.TESU_SHURUI_CD '                  -- 手数料種類コード
		|| '				FROM MGR_KIHON_VIEW		VMG1 '		 -- 銘柄_基本VIEW
		|| '						INNER JOIN MHAKKOTAI		M01 '		 -- 発行体マスタ
		|| '							ON VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD '
		|| '							AND VMG1.HKT_CD = M01.HKT_CD '
		|| '						INNER JOIN KAIKEI_KBN		H01 '		 -- 会計区分マスタ
		|| '							ON VMG1.ITAKU_KAISHA_CD = H01.ITAKU_KAISHA_CD '
		|| '							AND VMG1.HKT_CD = H01.HKT_CD '
		|| '						INNER JOIN KIKIN_IDO_KAIKEI	H04 '		 -- 基金異動履歴（会計区分別）
		|| '							ON VMG1.ITAKU_KAISHA_CD = H04.ITAKU_KAISHA_CD '
		|| '							AND VMG1.MGR_CD = H04.MGR_CD '
		|| '							AND H01.KAIKEI_KBN = H04.KAIKEI_KBN '
		|| '						INNER JOIN MTSUKA			M64 '		 -- 通貨マスタ
		|| '							ON H04.TSUKA_CD = M64.TSUKA_CD '
		|| '						LEFT JOIN SCODE				MCD1 '		 -- コードマスタ
		|| '							ON H04.KKNBILL_SHURUI = MCD1.CODE_VALUE '
		|| '							AND MCD1.CODE_SHUBETSU = ''139'' '
		|| '						LEFT JOIN (SELECT * FROM MGR_TESURYO_CTL WHERE TESU_SHURUI_CD IN (''61'',''82'') AND CHOOSE_FLG = ''1'') MG7 '  -- 銘柄_手数料（制御情報）
		|| '							ON H04.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD '
		|| '							AND H04.MGR_CD = MG7.MGR_CD '
		|| '				WHERE VMG1.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' '
		|| '					AND VMG1.MGR_STAT_KBN = ''1'' ';
	IF (trim(both l_inHktCd) IS NOT NULL AND (trim(both l_inHktCd))::text <> '') THEN
		gSQL := gSQL || '		AND	 VMG1.HKT_CD		= ''' || l_inHktCd || '''';
	END IF;
	IF (trim(both l_inKozaTenCd) IS NOT NULL AND (trim(both l_inKozaTenCd))::text <> '') THEN
		gSQL := gSQL || '		AND	 M01.KOZA_TEN_CD	= ''' || l_inKozaTenCd || '''';
	END IF;
	IF (trim(both l_inKozaTenCifCd) IS NOT NULL AND (trim(both l_inKozaTenCifCd))::text <> '') THEN
		gSQL := gSQL || '		AND	 M01.KOZA_TEN_CIFCD	= ''' || l_inKozaTenCifCd || '''';
	END IF;
	IF (trim(both l_inMgrCd) IS NOT NULL AND (trim(both l_inMgrCd))::text <> '') THEN
		gSQL := gSQL || '		AND	 VMG1.MGR_CD		= ''' || l_inMgrCd || '''';
	END IF;
	IF (trim(both l_inIsinCd) IS NOT NULL AND (trim(both l_inIsinCd))::text <> '') THEN
		gSQL := gSQL || '		AND	 VMG1.ISIN_CD		= ''' || l_inIsinCd || '''';
	END IF;
		gSQL := gSQL || '		AND PKIPAKKNIDO.GETKAIKEIANBUNCOUNT(VMG1.ITAKU_KAISHA_CD , VMG1.MGR_CD) > 0 '
		|| '					AND H04.IDO_YMD BETWEEN ''' || l_inKijyunYmdF || ''' AND ''' || l_inKijyunYmdT || ''' '
								-- 0：Rの場合公債フラグの集約は行わない
		|| '					AND H04.KOUSAIHI_FLG <> CASE WHEN ''' || l_inGresult || ''' = ''1'' THEN ''1'' ELSE ''9'' END '
		|| '					) '
						--	公債費特別会計を取得するSQL
		|| '		UNION (SELECT DISTINCT	VMG1.ITAKU_KAISHA_CD, '
		|| '								VMG1.MGR_CD, '
		|| '								M01.HKT_CD, '
		|| '								H04.IDO_YMD, '
		|| '								''00'', '
		|| '								''公債費特別会計'', '
		|| '								0, '
		|| '								H04.TSUKA_CD, '
		|| '								M64.TSUKA_NM, '
		|| '								H04.RBR_YMD, '
		|| '								H04.RBR_KJT, '
		|| '								MCD1.CODE_RNM, '
		|| '								MAX(H04.FUNIT_SKN_SHR_KNGK), '
		|| '								MAX(H04.KAKUSHASAI_KNGK), '
		|| '								H04.SHOKAN_PREMIUM, '
		|| '								MAX(H04.TSUKARISHI_KNGK), '
		|| '								SUM(H04.KIJUN_ZNDK), '
		|| '								H04.ZNDK_KIJUN_YMD, '
		|| '								SUM(H04.GANKIN), '
		|| '								SUM(H04.RKN), '
		|| '								H04.GNKN_SHR_TESU_BUNBO, '
		|| '								H04.GNKN_SHR_TESU_BUNSHI, '
		|| '								H04.RKN_SHR_TESU_BUNBO, '
		|| '								H04.RKN_SHR_TESU_BUNSHI, '
		|| '								SUM(H04.GNKN_SHR_TESU_KNGK), '
		|| '								SUM(H04.RKN_SHR_TESU_KNGK), '
		|| '								SUM(H04.SEIKYU_KNGK), '
		|| '								SUM(H04.SZEI_KNGK) '
		|| '                               ,CASE TESU_SHURUI_CD WHEN ''61'' THEN ''元'' WHEN ''82'' THEN ''利'' ELSE ''　'' END AS TESU_SHURUI_NM ' -- 手数料種類名
		|| '				FROM MGR_KIHON_VIEW		VMG1 '	-- 銘柄_基本VIEW
		|| '					 INNER JOIN MHAKKOTAI		M01 '	-- 発行体マスタ
		|| '					 	ON VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD '
		|| '					 	AND VMG1.HKT_CD = M01.HKT_CD '
		|| '					 INNER JOIN KAIKEI_KBN		H01 '	-- 会計区分マスタ
		|| '					 	ON VMG1.ITAKU_KAISHA_CD = H01.ITAKU_KAISHA_CD '
		|| '					 	AND VMG1.HKT_CD = H01.HKT_CD '
		|| '					 INNER JOIN KIKIN_IDO_KAIKEI	H04 '	-- 基金異動履歴（会計区分別）
		|| '					 	ON VMG1.ITAKU_KAISHA_CD = H04.ITAKU_KAISHA_CD '
		|| '					 	AND VMG1.MGR_CD = H04.MGR_CD '
		|| '					 	AND H01.KAIKEI_KBN = H04.KAIKEI_KBN '
		|| '					 INNER JOIN MTSUKA			M64 '	-- 通貨マスタ
		|| '					 	ON H04.TSUKA_CD = M64.TSUKA_CD '
		|| '					 LEFT JOIN SCODE			MCD1 '	-- コードマスタ
		|| '					 	ON H04.KKNBILL_SHURUI = MCD1.CODE_VALUE '
		|| '					 	AND MCD1.CODE_SHUBETSU = ''139'' '
		|| '					 LEFT JOIN (SELECT * FROM MGR_TESURYO_CTL WHERE TESU_SHURUI_CD IN (''61'',''82'') AND CHOOSE_FLG = ''1'') MG7 '  -- 銘柄_手数料（制御情報）
		|| '					 	ON H04.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD '
		|| '					 	AND H04.MGR_CD = MG7.MGR_CD '
		|| '				WHERE VMG1.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' '
		|| '					AND VMG1.MGR_STAT_KBN = ''1'' ';
	IF (trim(both l_inHktCd) IS NOT NULL AND (trim(both l_inHktCd))::text <> '') THEN
		gSQL := gSQL || '		AND VMG1.HKT_CD			= ''' || l_inHktCd || '''';
	END IF;
	IF (trim(both l_inKozaTenCd) IS NOT NULL AND (trim(both l_inKozaTenCd))::text <> '') THEN
		gSQL := gSQL || '		AND M01.KOZA_TEN_CD		= ''' || l_inKozaTenCd || '''';
	END IF;
	IF (trim(both l_inKozaTenCifCd) IS NOT NULL AND (trim(both l_inKozaTenCifCd))::text <> '') THEN
		gSQL := gSQL || '		AND M01.KOZA_TEN_CIFCD	= ''' || l_inKozaTenCifCd || '''';
	END IF;
	IF (trim(both l_inMgrCd) IS NOT NULL AND (trim(both l_inMgrCd))::text <> '') THEN
		gSQL := gSQL || '		AND VMG1.MGR_CD			= ''' || l_inMgrCd || '''';
	END IF;
	IF (trim(both l_inIsinCd) IS NOT NULL AND (trim(both l_inIsinCd))::text <> '') THEN
		gSQL := gSQL || '		AND VMG1.ISIN_CD		= ''' || l_inIsinCd || '''';
	END IF;
		gSQL := gSQL || '		AND PKIPAKKNIDO.GETKAIKEIANBUNCOUNT(VMG1.ITAKU_KAISHA_CD , VMG1.MGR_CD) > 0 '
		|| '					AND H04.IDO_YMD BETWEEN ''' || l_inKijyunYmdF || ''' AND ''' || l_inKijyunYmdT || ''' '
								-- 0：Rの場合公債フラグの集約は行わない
		|| '					AND H04.KOUSAIHI_FLG = CASE WHEN ''' || l_inGresult || ''' = ''1'' THEN ''1'' ELSE ''9'' END '
		|| '			GROUP BY VMG1.ITAKU_KAISHA_CD, '
		|| '						VMG1.MGR_CD, '
		|| '						M01.HKT_CD, '
		|| '						H04.IDO_YMD, '
		|| '						H04.TSUKA_CD, '
		|| '						M64.TSUKA_NM, '
		|| '						H04.RBR_YMD, '
		|| '						H04.RBR_KJT, '
		|| '						MCD1.CODE_RNM, '
		|| '						H04.SHOKAN_PREMIUM, '
		|| '						H04.ZNDK_KIJUN_YMD, '
		|| '						H04.GNKN_SHR_TESU_BUNBO, '
		|| '						H04.GNKN_SHR_TESU_BUNSHI, '
		|| '						H04.RKN_SHR_TESU_BUNBO, '
		|| '						H04.RKN_SHR_TESU_BUNSHI '
		|| '						,CASE TESU_SHURUI_CD WHEN ''61'' THEN ''元'' WHEN ''82'' THEN ''利'' ELSE ''　'' END ' -- 手数料種類名
		|| '              )) WT02 ';
IF l_inChohyoKbn = '1' THEN
	gSql :=gSql || '	,SREPORT_WK SC16 			'-- 帳票ワーク
				|| '	 WHERE WT01.ITAKU_KAISHA_CD = WT02.ITAKU_KAISHA_CD '
				|| '	 AND WT02.ITAKU_KAISHA_CD = SC16.KEY_CD '
				|| '	 AND WT02.MGR_CD = SC16.ITEM001 '
				|| '	 AND WT02.IDO_YMD = SC16.ITEM002 '
				|| '     AND WT02.RBR_KJT = SC16.ITEM003 '
				|| '	 AND SC16.USER_ID = ''BATCH'' '
				|| '	 AND SC16.CHOHYO_KBN = ''1'' '
				|| '	 AND SC16.SAKUSEI_YMD = ''' || l_inGyomuYmd || ''' '
				|| '	 AND SC16.CHOHYO_ID = ''WKH30000511'' ';
ELSE
	gSql :=gSql || ' WHERE WT01.ITAKU_KAISHA_CD = WT02.ITAKU_KAISHA_CD ';
END IF;
	gSql :=gSql || 'AND WT01.HKT_CD = WT02.HKT_CD '
		|| '		AND WT01.MGR_CD = WT02.MGR_CD '
		|| '		AND TRIM(WT01.ISIN_CD) IS NOT NULL ';
IF trim(both l_inChohyoKbn) = '3' THEN
gSQL := gSQL || ' ORDER BY WT02.TSUKA_CD '
		|| '	 ,WT02.IDO_YMD '
		|| '	 ,WT01.HKT_CD '
		|| '	 ,WT02.INPUT_NUM '
		|| '	 ,WT01.ISIN_CD '
		|| '	 ,WT02.RBR_YMD ';
	ELSE
gSQL := gSQL || ' ORDER BY WT02.TSUKA_CD '
		|| '	 ,WT01.HKT_CD '
		|| '	 ,WT02.IDO_YMD '
		|| '	 ,WT02.INPUT_NUM '
		|| '	 ,WT01.ISIN_CD '
		|| '	 ,WT02.RBR_YMD ';
	END IF;
	--TEST_DEBUG_LOG('SPIPH005K00R00',gSQL);
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spiph005k00r01_createsql () FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spiph005k00r01_updateinvoiceitem (
    in_TsukaCd text,
    l_inItakuKaishaCd TEXT,
    l_inUserId VARCHAR,
    l_inChohyoKbn TEXT,
    l_inGyomuYmd TEXT,
    REPORT_ID VARCHAR,
    TITLE_OUTPUT VARCHAR,
    IN in_gRtnCd integer,
    IN in_gSzeiRate numeric,
    IN in_gSzeiKijunYmd text,
    IN in_gInvoiceTesuLabel varchar,
    IN in_gInvoiceTesuKngkSum numeric,
    IN in_gInvoiceUchiSzei numeric,
    IN in_gSeikyuTotal numeric,
    IN in_gInvoiceKknTesuKngkSum numeric,
    OUT gRtnCd integer,
    OUT gSzeiRate numeric,
    OUT gSzeiKijunYmd text,
    OUT gInvoiceTesuLabel varchar,
    OUT gInvoiceTesuKngkSum numeric,
    OUT gInvoiceUchiSzei numeric,
    OUT gSeikyuTotal numeric,
    OUT gInvoiceKknTesuKngkSum numeric,
    gWrkStSiharaiYmd text,
    gWrkHktCd varchar,
    gWrkKikiKbn text,
    gWrkTukaCd text,
    gWrkKozaFuriKbn text
) AS $body$
BEGIN
	-- Copy IN values to OUT
	gRtnCd := in_gRtnCd;
	gSzeiRate := in_gSzeiRate;
	gSzeiKijunYmd := in_gSzeiKijunYmd;
	gInvoiceTesuLabel := in_gInvoiceTesuLabel;
	gInvoiceTesuKngkSum := in_gInvoiceTesuKngkSum;
	gInvoiceUchiSzei := in_gInvoiceUchiSzei;
	gSeikyuTotal := in_gSeikyuTotal;
	gInvoiceKknTesuKngkSum := in_gInvoiceKknTesuKngkSum;
	
	gRtnCd := pkconstant.error();
	-- 適格請求書_手数料ラベル編集
	-- 改ページ単位の最終レコードの内容で編集
	gSzeiRate := pkIpaZei.getShohiZeiRate(gSzeiKijunYmd);
	gInvoiceTesuLabel := '（' || substr('　' || oracle.to_multi_byte(gSzeiRate), -2) || '％対象）';
	-- 手数料割戻消費税算出
	IF coalesce(gInvoiceTesuKngkSum, 0) = 0 THEN
		gInvoiceUchiSzei := 0;
	ELSE
		-- 合計データ（改ページ単位の最終レコード）の内容で算出
		gInvoiceUchiSzei := PKIPACALCTESUKNGK.getTesuZeiWarimodoshi(
								 gSzeiKijunYmd
								,gInvoiceTesuKngkSum
								,in_TsukaCd
							);
	END IF;
	-- 同じページのレコードのインボイス項目を更新
	UPDATE	SREPORT_WK
	SET		 ITEM053	=	gInvoiceTesuLabel 			-- 適格請求書_手数料ラベル
			,ITEM054	=	gSeikyuTotal 				-- 適格請求書_請求額合計
			,ITEM055	=	gInvoiceKknTesuKngkSum 		-- 適格請求書_基金および手数料合計
			,ITEM056	=	gInvoiceTesuKngkSum 			-- 適格請求書_手数料合計
			,ITEM057	=	gInvoiceUchiSzei 			-- 適格請求書_内消費税
			,ITEM058	=	gSzeiKijunYmd 				-- 消費税基準日(ジャーナル)
			,ITEM059	=	gSzeiRate 					-- 消費税率(ジャーナル)
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID
	AND		HEADER_FLG = '1'
	AND		coalesce(trim(both ITEM042)::text, '') = ''		-- 対象データなし でないもの
	AND		trim(both coalesce(ITEM001, '')) = trim(both coalesce(TITLE_OUTPUT, ''))		--帳票タイトル
	AND		trim(both coalesce(ITEM002, '')) = trim(both coalesce(gWrkStSiharaiYmd, ''))	--異動日
	AND		trim(both coalesce(ITEM006, '')) = trim(both coalesce(gWrkHktCd, ''))			--発行体コード
	AND		trim(both coalesce(ITEM004, '')) = trim(both coalesce(gWrkKikiKbn, ''))			--会計区分
	AND		trim(both coalesce(ITEM014, '')) = trim(both coalesce(gWrkTukaCd, ''))			--通貨コード
	AND		trim(both coalesce(ITEM049, '')) = trim(both coalesce(gWrkKozaFuriKbn, ''))		--口座振替区分
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
-- REVOKE ALL ON PROCEDURE spiph005k00r01_updateinvoiceitem (in_TsukaCd text) FROM PUBLIC;