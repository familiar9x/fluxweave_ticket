


DROP TYPE IF EXISTS sfipx021k00r01_01_type_record;
CREATE TYPE sfipx021k00r01_01_type_record AS (
		ITAKU_KAISHA_CD						char(4),				--委託会社コード
		MGR_CD								varchar(13),						--銘柄コード
		SHR_YMD								char(8),						--支払日
		TSUKA_CD							char(3),						--通貨コード
		FINANCIAL_SECURITIES_KBN			char(1),		--金融証券区分
		BANK_CD								char(4),						--金融機関コード
		KOZA_KBN							char(2),						--口座区分
		WAKATI_FLG							char(1),										--分かちフラグ
		TAX_KBN								char(2),						--税区分
		KK_KANYO_UMU_FLG					char(1),				--機構関与有無フラグ
		TOTAL_SHOKAN_SEIKYU_KNGK			decimal(16,2),			--償還金請求金額合計
		TOTAL_GZEIHIKI_BEF_CHOKYU_KNGK		decimal(14,2),		--国税引前利金請求金額合計
		TOTAL_GZEIHIKI_AFT_CHOKYU_KNGK		decimal(14,2),		--国税引後利金請求金額合計
		TOTAL_GZEI_KNGK						decimal(14,2),					--国税金額合計
		TOTAL_GNR_ZNDK						numeric(14),
		SZEI_SEIKYU_KBN						char(1),			--消費税請求区分
		GNKN_SHR_TESU_BUNSHI				decimal(17,14),		--元金支払手数料率(分子)
		GNKN_SHR_TESU_BUNBO					numeric(5),		--元金支払手数料率(分母)
		GNKN_SHR_TESU_CAP					decimal(14,2),			--元金支払手数料ＣＡＰ
		RKN_SHR_TESU_BUNSHI					decimal(17,14),		--利金支払手数料率(分子)
		RKN_SHR_TESU_BUNBO					numeric(5)		--利金支払手数料率(分母)
	);


CREATE OR REPLACE FUNCTION sfipx021k00r01_01 ( 
	l_inItakuKaishaCd TEXT,		-- 委託会社コード
	l_inMgrCd TEXT,		-- 銘柄コード
	l_inGnrYmd TEXT 		-- 元利払日
 ) RETURNS numeric AS $body$
DECLARE

--
--/* 著作権:Copyright (c) 2013
--/* 会社名:JIP
--/* 概要　:資金支払データ変更画面の指示により、元利払基金出金データ再作成を行う
--/* 引数　:l_inItakuKaishaCd		IN	TEXT	委託会社コード
--/* 　　　 l_inMgrCd				IN	TEXT	銘柄コード
--/* 　　　 l_inGnrYmd			IN	TEXT	元利払日
--/* 返り値:NUMERIC 0:正常、99:異常、それ以外：エラー
--/* @version $Id: SFIPX021K00R01_01.sql,v 1.1 2013/12/27 02:35:28 touma Exp $
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* ------------------------------------------------------------------------
--/*　2013.11.01	IPT				新規作成
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
	RTN_NODATA			CONSTANT integer		:= 2;				-- データなし
	RTN_FATAL			CONSTANT integer		:= 99;				-- 予期せぬエラー
	C_FUNCTION_ID		CONSTANT varchar(20) := 'SFIPX021K00R01_01';	-- ファンクションＩＤ
--==============================================================================
--					変数定義													
--==============================================================================
	gRtnCd					integer :=	RTN_OK;								--リターンコード
	taihiString				varchar(50);										--退避用文字列
	string1					varchar(50);										--比較用文字列
	gShrYmdYoku10			KIKIN_SEIKYU.SHR_YMD%TYPE := NULL;				--支払日の翌月１０日
	gShrYmdYoku25			KIKIN_SEIKYU.SHR_YMD%TYPE := NULL;				--支払日の翌月２５日
	gTotalGzeiKngk			KIKIN_IDO.KKN_SHUKIN_KNGK%TYPE := 0;			--国税金額の合計額
	gTotalShokanSeikyu		KIKIN_IDO.KKN_SHUKIN_KNGK%TYPE := 0;			--償還金請求金額の合計(退避用)
	gShohizei				numeric := 0;									--消費税率
	gSzeiCalcMethod			integer := 0;									--消費税計算方法
	gTesuCapProcess			integer := 0;									--元金支払手数料ＣＡＰ判定制御
	gDataCnt				numeric := 0;									--データ件数カウンタ
	gJikoTotalHkukKbn		MGR_KIHON_VIEW.JIKO_TOTAL_HKUK_KBN%TYPE := NULL;	--自行総額引受区分
	gRbrTsukaCd				MGR_KIHON_VIEW.RBR_TSUKA_CD%TYPE := NULL;		--利払通貨コード
	gKkKanyoFlg				MGR_KIHON_VIEW.KK_KANYO_FLG%TYPE := NULL;		--機構関与方式採用フラグ
	gKyujitsuKbn			MGR_KIHON_VIEW.KYUJITSU_KBN%TYPE := NULL;		--休日区分
	gAreaCd					MGR_KIHON_VIEW.AreaCd%TYPE := NULL;			--地域コード
	gShrYmd					KIKIN_IDO.RBR_KJT%TYPE := NULL;				--支払日(編集用)
	wk_shrYmd				KIKIN_IDO.RBR_KJT%TYPE := NULL;				--支払日(退避用)
	wk_mgrCd				KIKIN_IDO.MGR_CD%TYPE := NULL;					--銘柄コード
	wk_tsukaCd				KIKIN_IDO.TSUKA_CD%TYPE := NULL;				--通貨コード
	wk_rbrKjt				KIKIN_IDO.RBR_KJT%TYPE := NULL;				--支払期日(退避用)
	gTsukaCd				KIKIN_IDO.TSUKA_CD%TYPE := NULL;				--利金手数料用通貨コード
	gScale					numeric;
	gScaleRkn				numeric;
	gZeikomiTesuKngk		numeric;
	gZndkKngk				numeric;
	gTesuShuruiCd			varchar(10);
	gCapZeinukiGaku			numeric := 0;
	gCapZeikomiGaku			numeric := 0;
	gCapZei					numeric := 0;
	--３−１〜３−７のレコードを作成するときに共通で使う変数
	gTesuChokyuYmd			MGR_SHOKIJ.TESU_CHOKYU_YMD%TYPE := NULL;		--手数料徴求日
	gSzeiSeikyuKbn			MGR_TESURYO_PRM.SZEI_SEIKYU_KBN%TYPE := NULL;	--消費税請求区分
	--3-1,3-2,3-3で使う変数
	gShokanKjt 				MGR_SHOKIJ.SHOKAN_KJT%TYPE := NULL;			--償還期日
	gGnknShrTesuBunshi		MGR_TESURYO_PRM.GNKN_SHR_TESU_BUNSHI%TYPE := 0;--元金支払手数料率(分子)
	gGnknShrTesuBunbo		MGR_TESURYO_PRM.GNKN_SHR_TESU_BUNBO%TYPE := 0;	--元金支払手数料率(分母)
	gGnknShrTesuCap			MGR_TESURYO_PRM.GNKN_SHR_TESU_CAP%TYPE := 0;	--元金支払手数料ＣＡＰ
	gKknShukinKngkCalc1		numeric := 0;									--元金支払手数料のレコードを作成する際の基金出金額
	gKknShukinKngkCalc2		numeric := 0;									--元金支払手数料消費税のレコードを作成する際の基金出金額
	--3-4,3-5,3-6で使う変数
	gRibaraiKijitsu 		MGR_RBRKIJ.RBR_KJT%TYPE := NULL;				--利払期日
	gRknShrTesuBunshi 		MGR_TESURYO_PRM.RKN_SHR_TESU_BUNSHI%TYPE := 0;	--利金支払手数料率(分子)
	gRknShrTesuBunbo 		MGR_TESURYO_PRM.RKN_SHR_TESU_BUNBO%TYPE := 0;	--利金支払手数料率(分母)
	gKknShukinKngkCalc3 	numeric := 0;									--利金支払手数料のレコードを作成する際の基金出金額
	gKknShukinKngkCalc4 	numeric := 0;									--利金支払手数料消費税のレコードを作成する際の基金出金額
	gTotalGzeihikiAftChokyuKngk		KIKIN_SEIKYU.GZEIHIKI_AFT_CHOKYU_KNGK%TYPE := 0;
	gTotalShokanSeikyuKngk			KIKIN_SEIKYU.SHOKAN_SEIKYU_KNGK%TYPE := 0;
	gTmpTotalGzeiKngk				KIKIN_IDO.KKN_SHUKIN_KNGK%TYPE := 0;			--国税金額の合計額(内側ループ時に集計する)
	gShzKijunProcess		MPROCESS_CTL.CTL_VALUE%TYPE;						-- 消費税率適用基準日対応
	gShzKijunYmd			varchar(8);										-- 消費税率適用基準日
	-- DB取得項目
	recAutoCreateKknShukin SFIPX021K00R01_01_TYPE_RECORD;						-- 退避しておく更新用レコード
	recAutoCreateKknShukinNext SFIPX021K00R01_01_TYPE_RECORD;						-- カーソルを進める合算用レコード
	
-----------------------------------------------------------------------------------------------------------
	ABND_TRACE					varchar(50); --例外発生時のデバッグ用変数
	gkeyItakuKaishaCd		KIKIN_SEIKYU.ITAKU_KAISHA_CD%TYPE := NULL;		--例外発生時のデバッグ用キー項目
	gkeyMgrCd				KIKIN_SEIKYU.MGR_CD%TYPE := NULL;				--例外発生時のデバッグ用キー項目
	gkeyShrYmd				KIKIN_SEIKYU.SHR_YMD%TYPE := NULL;				--例外発生時のデバッグ用キー項目
-----------------------------------------------------------------------------------------------------------
--==============================================================================
--					カーソル定義													
--==============================================================================
curAutoCreateKknShukin CURSOR FOR
	SELECT
		K01.ITAKU_KAISHA_CD					AS ITAKU_KAISHA_CD,							--委託会社コード
		K01.MGR_CD							AS MGR_CD,									--銘柄コード
		K01.SHR_YMD							AS SHR_YMD,									--支払日
		K01.TSUKA_CD						AS TSUKA_CD,								--通貨コード
		K01.FINANCIAL_SECURITIES_KBN		AS FINANCIAL_SECURITIES_KBN,				--金融証券区分
		K01.BANK_CD							AS BANK_CD,									--金融機関コード
		K01.KOZA_KBN						AS KOZA_KBN,								--口座区分
		'0'									AS WAKATI_FLG,								--分かちフラグ
		K01.TAX_KBN							AS TAX_KBN,									--税区分
		K01.KK_KANYO_UMU_FLG				AS KK_KANYO_UMU_FLG,						--機構関与有無フラグ
		K01.SHOKAN_SEIKYU_KNGK				AS TOTAL_SHOKAN_SEIKYU_KNGK,				--償還金請求金額合計
		K01.GZEIHIKI_BEF_CHOKYU_KNGK		AS TOTAL_GZEIHIKI_BEF_CHOKYU_KNGK,			--国税引前利金請求金額合計
		K01.GZEIHIKI_AFT_CHOKYU_KNGK		AS TOTAL_GZEIHIKI_AFT_CHOKYU_KNGK,			--国税引後利金請求金額合計
		K01.GZEI_KNGK 						AS TOTAL_GZEI_KNGK,							--国税金額合計
		CASE WHEN K01.GNR_JISSHITSU_ZNDK=0 THEN  K01.GNR_ZNDK  ELSE K01.GNR_JISSHITSU_ZNDK END 	 AS TOTAL_GNR_ZNDK,
		MG8.SZEI_SEIKYU_KBN					AS SZEI_SEIKYU_KBN,							--消費税請求区分
		MG8.GNKN_SHR_TESU_BUNSHI			AS GNKN_SHR_TESU_BUNSHI,					--元金支払手数料率(分子)
		MG8.GNKN_SHR_TESU_BUNBO				AS GNKN_SHR_TESU_BUNBO,						--元金支払手数料率(分母)
		MG8.GNKN_SHR_TESU_CAP				AS GNKN_SHR_TESU_CAP,						--元金支払手数料ＣＡＰ
		MG8.RKN_SHR_TESU_BUNSHI				AS RKN_SHR_TESU_BUNSHI,						--利金支払手数料率(分子)
		MG8.RKN_SHR_TESU_BUNBO				AS RKN_SHR_TESU_BUNBO 						--利金支払手数料率(分母)
	FROM
		KIKIN_SEIKYU K01,
		MGR_KIHON_VIEW VMG1,
		MGR_TESURYO_PRM MG8
	WHERE
		K01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
	AND	K01.MGR_CD = l_inMgrCd
	AND	K01.SHR_YMD = l_inGnrYmd
	AND	K01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
	AND	K01.MGR_CD = VMG1.MGR_CD
	AND K01.TAX_KBN NOT IN ('90', '91', '92', '93', '94', '95')
	AND	VMG1.JTK_KBN <> '2'
	AND VMG1.KK_KANYO_FLG <> '2'
	AND	VMG1.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD
	AND	VMG1.MGR_CD = MG8.MGR_CD
	
UNION ALL
(SELECT
			K01.ITAKU_KAISHA_CD					AS ITAKU_KAISHA_CD,							--委託会社コード
			K01.MGR_CD							AS MGR_CD,									--銘柄コード
			K01.SHR_YMD							AS SHR_YMD,									--支払日
			K01.TSUKA_CD						AS TSUKA_CD,								--通貨コード
			K01.FINANCIAL_SECURITIES_KBN		AS FINANCIAL_SECURITIES_KBN,				--金融証券区分
			K01.BANK_CD							AS BANK_CD,									--金融機関コード
			K01.KOZA_KBN						AS KOZA_KBN,								--口座区分
			'1' AS WAKATI_FLG,																--分かちフラグ
			CASE K01.TAX_KBN
				WHEN '90' THEN '91'
				WHEN '91' THEN '91'
				WHEN '92' THEN '93'
				WHEN '93' THEN '93'
				WHEN '94' THEN '95'
				ELSE '95'
			END AS TAX_KBN,																	--税区分
			K01.KK_KANYO_UMU_FLG,															--機構関与有無フラグ
			SUM(K01.SHOKAN_SEIKYU_KNGK) 		AS TOTAL_SHOKAN_SEIKYU_KNGK,				--償還金請求金額合計
			SUM(K01.GZEIHIKI_BEF_CHOKYU_KNGK) 	AS TOTAL_GZEIHIKI_BEF_CHOKYU_KNGK,			--国税引前利金請求金額合計
			SUM(K01.GZEIHIKI_AFT_CHOKYU_KNGK) 	AS TOTAL_GZEIHIKI_AFT_CHOKYU_KNGK,			--国税引後利金請求金額合計
			SUM(K01.GZEI_KNGK) 					AS TOTAL_GZEI_KNGK,							--国税金額合計
			SUM(CASE WHEN K01.GNR_JISSHITSU_ZNDK=0 THEN  K01.GNR_ZNDK  ELSE K01.GNR_JISSHITSU_ZNDK END ) AS TOTAL_GNR_ZNDK,
			MG8.SZEI_SEIKYU_KBN					AS SZEI_SEIKYU_KBN,							--消費税請求区分
			MG8.GNKN_SHR_TESU_BUNSHI			AS GNKN_SHR_TESU_BUNSHI,					--元金支払手数料率(分子)
			MG8.GNKN_SHR_TESU_BUNBO				AS GNKN_SHR_TESU_BUNBO,						--元金支払手数料率(分母)
			MG8.GNKN_SHR_TESU_CAP				AS GNKN_SHR_TESU_CAP,						--元金支払手数料ＣＡＰ
			MG8.RKN_SHR_TESU_BUNSHI				AS RKN_SHR_TESU_BUNSHI,						--利金支払手数料率(分子)
			MG8.RKN_SHR_TESU_BUNBO				AS RKN_SHR_TESU_BUNBO 						--利金支払手数料率(分母)
		FROM
			KIKIN_SEIKYU K01,
			MGR_KIHON_VIEW VMG1,
			MGR_TESURYO_PRM MG8
		WHERE
			K01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND	K01.MGR_CD = l_inMgrCd
		AND	K01.SHR_YMD = l_inGnrYmd
		AND	K01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
		AND	K01.MGR_CD = VMG1.MGR_CD
		AND K01.TAX_KBN IN ('90', '91', '92', '93', '94', '95')
		AND	VMG1.JTK_KBN <> '2'
		AND VMG1.KK_KANYO_FLG <> '2'
		AND	VMG1.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD
		AND	VMG1.MGR_CD = MG8.MGR_CD 
		GROUP BY
			K01.ITAKU_KAISHA_CD,
			K01.MGR_CD,
			K01.SHR_YMD,
			K01.TSUKA_CD,
			K01.FINANCIAL_SECURITIES_KBN,
			K01.BANK_CD,
			K01.KOZA_KBN,
			K01.KK_KANYO_UMU_FLG,
			CASE K01.TAX_KBN
				WHEN '90' THEN '91'
				WHEN '91' THEN '91'
				WHEN '92' THEN '93'
				WHEN '93' THEN '93'
				WHEN '94' THEN '95'
				ELSE '95'
			END,
			MG8.GNKN_SHR_TESU_BUNSHI,
			MG8.GNKN_SHR_TESU_BUNBO,
			MG8.GNKN_SHR_TESU_CAP,
			MG8.RKN_SHR_TESU_BUNSHI,
			MG8.RKN_SHR_TESU_BUNBO,
			MG8.SZEI_SEIKYU_KBN
	)
	ORDER BY
		ITAKU_KAISHA_CD,
		MGR_CD,
		SHR_YMD,
		TSUKA_CD,
		FINANCIAL_SECURITIES_KBN,
		BANK_CD,
		KOZA_KBN;
--==============================================================================
--							補足												
--==============================================================================
--	３−１		元金分基金異動履歴作成
--	３−２		元金支払手数料分異動履歴作成
--	３−３		元金支払手数料消費税分異動履歴作成
--	３−４		利金分基金異動履歴作成
--	３−５		利金支払手数料分異動履歴作成
--	３−６		利金支払手数料消費税分異動履歴作成
--	３−７		国税分基金異動履歴作成
--
--
--==============================================================================
--					 メイン処理													  
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug('BATCH', C_FUNCTION_ID, C_FUNCTION_ID || ' START');	END IF;
	--例外発生時のデバッグ用変数初期化
	ABND_TRACE := NULL;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inMgrCd)::text, '') = ''
	OR coalesce(trim(both l_inGnrYmd)::text, '') = '' THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug('BATCH', C_FUNCTION_ID, 'param error');	END IF;
		CALL pkLog.error('ECM501', C_FUNCTION_ID, 'SQLERRM:'||'');
		RETURN RTN_NG;
	END IF;
	taihiString := NULL;
	-- 処理制御マスタで消費税計算方法の端数切捨てタイミングを制御する
	gSzeiCalcMethod := pkControl.getCtlValue(l_inItakuKaishaCd, 'SFBUNPAIGNRTES0', '0');
	-- 処理制御マスタから元金支払手数料ＣＡＰ対応フラグ取得
	gTesuCapProcess := pkControl.getCtlValue(l_inItakuKaishaCd, 'TesuryoCap0', '0');
	-- 消費税率適用基準日フラグ(1:取引日ベース, 0:徴求日ベース(デフォルト))取得
	gShzKijunProcess := pkControl.getCtlValue(l_inItakuKaishaCd, 'ShzKijun', '0');
	ABND_TRACE := 'カーソル開始前';
	-- カーソルオープン
	OPEN curAutoCreateKknShukin;
	-- データ取得
	FETCH curAutoCreateKknShukin INTO recAutoCreateKknShukinNext;	-- ループに入る前に最初のフェッチ
	LOOP
		-- データが無くなったらループを抜ける
		EXIT WHEN NOT FOUND;/* apply on curAutoCreateKknShukin */
		--現在のデータを退避
		recAutoCreateKknShukin := recAutoCreateKknShukinNext;
	----------------------------------------------------------------------------------
		--変数初期化
		gkeyItakuKaishaCd := NULL;
		gkeyMgrCd := NULL;
		gkeyShrYmd := NULL;
		--例外発生時用変数にキー項目セット
		gkeyItakuKaishaCd := recAutoCreateKknShukin.ITAKU_KAISHA_CD;
		gkeyMgrCd := recAutoCreateKknShukin.MGR_CD;
		gkeyShrYmd := recAutoCreateKknShukin.SHR_YMD;
	----------------------------------------------------------------------------------
		string1 := NULL;
		string1 := string1 || recAutoCreateKknShukin.ITAKU_KAISHA_CD;
		string1 := string1 || recAutoCreateKknShukin.MGR_CD;
		string1 := string1 || recAutoCreateKknShukin.SHR_YMD;
		string1 := string1 || recAutoCreateKknShukin.TSUKA_CD;
		gSzeiSeikyuKbn		:=	recAutoCreateKknShukin.SZEI_SEIKYU_KBN;			--消費税請求区分
		gGnknShrTesuBunshi	:=	recAutoCreateKknShukin.GNKN_SHR_TESU_BUNSHI;	--元金支払手数料率(分子)
		gGnknShrTesuBunbo	:=	recAutoCreateKknShukin.GNKN_SHR_TESU_BUNBO;		--元金支払手数料率(分母)
		gGnknShrTesuCap		:=	recAutoCreateKknShukin.GNKN_SHR_TESU_CAP;		--元金支払手数料ＣＡＰ
		gRknShrTesuBunshi	:=	recAutoCreateKknShukin.RKN_SHR_TESU_BUNSHI;		--利金支払手数料率(分子)
		gRknShrTesuBunbo	:=	recAutoCreateKknShukin.RKN_SHR_TESU_BUNBO;		--利金支払手数料率(分母)
		--ループ一回目は必ずstring1をセットする
		IF coalesce(taihiString::text, '') = '' THEN
			taihiString := string1;
		END IF;
		--休日区分と地域コードを取得する
		SELECT
			VMG1.JIKO_TOTAL_HKUK_KBN,
			VMG1.RBR_TSUKA_CD,
			VMG1.KK_KANYO_FLG,
			VMG1.KYUJITSU_KBN,
			VMG1.AREACD
		INTO STRICT
			gJikoTotalHkukKbn,
			gRbrTsukaCd,
			gKkKanyoFlg,
			gKyujitsuKbn,
			gAreaCd
		FROM
			MGR_KIHON_VIEW VMG1
		WHERE
			recAutoCreateKknShukin.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
		AND	recAutoCreateKknShukin.MGR_CD = VMG1.MGR_CD;
		--支払日を強制的に２５日に変換(翌月２５を求めるため⇒営業日補正あり)
		gShrYmd := SUBSTR(recAutoCreateKknShukin.SHR_YMD,1,6) || '25';
		--支払日の翌月２５日をここで取得する
		gShrYmdYoku25 := pkdate.calcMonthKyujitsuKbn(gShrYmd,1,gKyujitsuKbn,gAreaCd);
		--集計前に変数初期化
		gShokanKjt			:=	'';
		gTesuChokyuYmd		:=	'';
		gKknShukinKngkCalc1	:=	0;
		gKknShukinKngkCalc2	:=	0;
		gKknShukinKngkCalc3	:=	0;
		gKknShukinKngkCalc4	:=	0;
		gTotalGzeihikiAftChokyuKngk	:= 0;
		gTotalShokanSeikyuKngk		:= 0;
		gTmpTotalGzeiKngk	:= 0;
		-- 切捨て単位の設定
		IF (recAutoCreateKknShukin.TSUKA_CD = 'JPY') THEN
			gScale := 0;
		ELSE
			gScale := 2;
		END IF;
		--ブレイク条件まで、手数料金額を計算して加算
		LOOP
			ABND_TRACE := '元金：手数料計算処理前';
			--償還金請求金額(集計額)が０ではない場合以下の処理を行う
			IF recAutoCreateKknShukinNext.TOTAL_SHOKAN_SEIKYU_KNGK != 0 THEN
				gTotalShokanSeikyuKngk := gTotalShokanSeikyuKngk + recAutoCreateKknShukinNext.TOTAL_SHOKAN_SEIKYU_KNGK;
				BEGIN
					SELECT
						MG3.SHOKAN_KJT,										--償還期日
						MG3.TESU_CHOKYU_YMD 									--手数料徴求日
					INTO STRICT
						gShokanKjt,
						gTesuChokyuYmd
					FROM
						MGR_SHOKIJ MG3
					WHERE MG3.ITAKU_KAISHA_CD =  recAutoCreateKknShukinNext.ITAKU_KAISHA_CD
					AND   MG3.MGR_CD		  =  recAutoCreateKknShukinNext.MGR_CD
					AND   MG3.SHOKAN_YMD	  =  recAutoCreateKknShukinNext.SHR_YMD
					AND   MG3.SHOKAN_KBN	  != '30'  LIMIT 1;
				EXCEPTION
					WHEN no_data_found THEN
						gShokanKjt := NULL;
						gTesuChokyuYmd := NULL;
				END;
				--手数料徴求日がスペースではないとき
				IF gTesuChokyuYmd != ' ' THEN
					-- 手数料計算
					IF (gGnknShrTesuBunbo > 0) THEN 	--0除算対策
						-- 消費税率適用基準日切り替え
						IF gShzKijunProcess = '1' THEN
							gShzKijunYmd := recAutoCreateKknShukinNext.SHR_YMD;
						ELSE
							gShzKijunYmd := gTesuChokyuYmd;
						END IF;
						--消費税率を関数で求める
						gShohizei := pkipazei.getShohiZei(gShzKijunYmd);
						-- 消費税請求区分が「請求なし」の場合
						IF (gSzeiSeikyuKbn = '0') THEN
							gKknShukinKngkCalc1 := gKknShukinKngkCalc1 + FLOOR(recAutoCreateKknShukinNext.TOTAL_SHOKAN_SEIKYU_KNGK * gGnknShrTesuBunshi / gGnknShrTesuBunbo::numeric * POWER(10, gScale)) / POWER(10, gScale);
							gKknShukinKngkCalc2 := 0;
						ELSE
						-- 消費税請求区分が「請求あり」の場合
							gZeikomiTesuKngk := FLOOR(recAutoCreateKknShukinNext.TOTAL_SHOKAN_SEIKYU_KNGK * gGnknShrTesuBunshi / gGnknShrTesuBunbo * (1+gShohizei) * POWER(10, gScale)) / POWER(10, gScale);
							IF gSzeiCalcMethod = 1 THEN
								-- <従来方式>
								-- 手数料（税抜）= 償還金額×手数料率　・・・端数切捨
								gKknShukinKngkCalc1 := gKknShukinKngkCalc1 + FLOOR(recAutoCreateKknShukinNext.TOTAL_SHOKAN_SEIKYU_KNGK * gGnknShrTesuBunshi / gGnknShrTesuBunbo::numeric * POWER(10, gScale)) / POWER(10, gScale);
								-- 手数料（税）= 手数料（税抜）×0.05　・・・端数切捨
								gKknShukinKngkCalc2 := gKknShukinKngkCalc2 + FLOOR(FLOOR(recAutoCreateKknShukinNext.TOTAL_SHOKAN_SEIKYU_KNGK * gGnknShrTesuBunshi / gGnknShrTesuBunbo * POWER(10, gScale)) / POWER(10, gScale) * gShohizei::numeric * POWER(10, gScale)) / POWER(10, gScale);
							ELSE
								-- <消費税総額方式>
								-- 手数料（税）= 手数料（税込）×5/105 ・・・端数切捨
							 	gKknShukinKngkCalc2 := gKknShukinKngkCalc2 + FLOOR(gZeikomiTesuKngk * gShohizei / (1 + gShohizei) * POWER(10, gScale)) / POWER(10, gScale);
								-- 手数料（税抜）= 手数料（税込）- 手数料（税）
								gKknShukinKngkCalc1 := gKknShukinKngkCalc1 + gZeikomiTesuKngk - FLOOR(gZeikomiTesuKngk * gShohizei / (1 + gShohizei) * POWER(10, gScale)) / POWER(10, gScale);
							END IF;
						END IF;
					END IF;
				END IF;
			END IF;
			ABND_TRACE := '元金：手数料計算処理後';
			ABND_TRACE := '利金：手数料計算処理前';
			gTotalGzeihikiAftChokyuKngk := gTotalGzeihikiAftChokyuKngk + recAutoCreateKknShukinNext.TOTAL_GZEIHIKI_AFT_CHOKYU_KNGK;
			BEGIN
				SELECT
					MG2.RBR_KJT,									-- 利払期日
					MG2.TESU_CHOKYU_YMD 								-- 手数料徴求日
				INTO STRICT
					gRibaraiKijitsu,
					gTesuChokyuYmd
				FROM
					MGR_RBRKIJ MG2
					WHERE MG2.ITAKU_KAISHA_CD =  recAutoCreateKknShukinNext.ITAKU_KAISHA_CD
					AND   MG2.MGR_CD		  =  recAutoCreateKknShukinNext.MGR_CD
					AND   MG2.RBR_YMD		  =  recAutoCreateKknShukinNext.SHR_YMD  LIMIT 1;
				EXCEPTION
					WHEN no_data_found THEN
						gRibaraiKijitsu := NULL;
						gTesuChokyuYmd := NULL;
			END;
			-- データが見つかったとき且つ手数料徴求日がスペースではないとき
			-- IP-05746の修正では元金の計算に合わせて徴求期日の条件を！=' 'としたが、いずれは
			-- 両方TrimをかけてIS NOT NULLで聞く用に修正する。
			IF (gRibaraiKijitsu IS NOT NULL AND gRibaraiKijitsu::text <> '') AND gTesuChokyuYmd != ' ' THEN
				-- 銘柄手数料（制御情報）から「利金支払手数料（元金）」又は「利金支払手数料（利金）」いずれかの設定内容を取得
				BEGIN
					SELECT DISTINCT
						trim(both MG7.TESU_SHURUI_CD),
						CASE WHEN MG7.TESU_SHURUI_CD='61' THEN MG1.HAKKO_TSUKA_CD WHEN MG7.TESU_SHURUI_CD='82' THEN MG1.RBR_TSUKA_CD END
					INTO STRICT
						gTesuShuruiCd,
						gTsukaCd
					FROM
							MGR_KIHON MG1,
							MGR_TESURYO_CTL MG7
					WHERE	MG7.ITAKU_KAISHA_CD = recAutoCreateKknShukinNext.ITAKU_KAISHA_CD
					AND		MG7.MGR_CD = recAutoCreateKknShukinNext.MGR_CD
					AND		MG7.TESU_SHURUI_CD IN ('61', '82')
					AND		MG7.CHOOSE_FLG = '1'
					AND		MG1.ITAKU_KAISHA_CD		= MG7.ITAKU_KAISHA_CD
					AND		MG1.MGR_CD				= MG7.MGR_CD;
				EXCEPTION
					WHEN no_data_found THEN
						gTesuShuruiCd := NULL;
						gTsukaCd := NULL;
				END;
				-- 切捨て単位の設定
				IF (gTsukaCd = 'JPY') THEN
					gScaleRkn := 0;
				ELSE
					gScaleRkn := 2;
				END IF;
				-- 初期化
				gZndkKngk := 0;
				-- 「61：利金支払手数料(元金)」の場合
				IF (gTesuShuruiCd = '61') THEN
					IF (recAutoCreateKknShukinNext.TOTAL_GZEIHIKI_AFT_CHOKYU_KNGK != 0)
					OR (recAutoCreateKknShukinNext.TOTAL_GZEIHIKI_AFT_CHOKYU_KNGK = 0 AND sfRkntesGb_CalcChk(recAutoCreateKknShukinNext.ITAKU_KAISHA_CD,
																								recAutoCreateKknShukinNext.MGR_CD, gRibaraiKijitsu) = 1) THEN		
						-- 基金請求テーブルの元利払対象残高を取得
						gZndkKngk := recAutoCreateKknShukinNext.TOTAL_GNR_ZNDK;
					END IF;
				-- 「82：利金支払手数料」の場合
				ELSE
					gZndkKngk := recAutoCreateKknShukinNext.TOTAL_GZEIHIKI_BEF_CHOKYU_KNGK;
				END IF;
				-- 手数料計算
				IF (gRknShrTesuBunbo > 0) THEN 	--0除算対策
					-- 消費税率適用基準日切り替え
					IF gShzKijunProcess = '1' THEN
						gShzKijunYmd := recAutoCreateKknShukinNext.SHR_YMD;
					ELSE
						gShzKijunYmd := gTesuChokyuYmd;
					END IF;
					--消費税率を関数で求める
					gShohizei := pkipazei.getShohiZei(gShzKijunYmd);
					-- 消費税請求区分が「請求なし」の場合
					IF (gSzeiSeikyuKbn = '0') THEN
						gKknShukinKngkCalc3 := gKknShukinKngkCalc3 + FLOOR(gZndkKngk * gRknShrTesuBunshi / gRknShrTesuBunbo::numeric * POWER(10, gScaleRkn)) / POWER(10, gScaleRkn);
						gKknShukinKngkCalc4 := 0;
					ELSE
					-- 消費税請求区分が「請求あり」の場合（通貨コードが'JPY'なら小数点以下を切り捨て。'JPY'以外なら小数点第三位以下を切り捨て）
						gZeikomiTesuKngk := FLOOR(gZndkKngk * gRknShrTesuBunshi / gRknShrTesuBunbo * (1+gShohizei) * POWER(10, gScaleRkn)) / POWER(10, gScaleRkn);
						IF gSzeiCalcMethod = 1 THEN
							-- <従来方式>
							-- 手数料（税抜）= 償還金額×手数料率　・・・端数切捨
						gKknShukinKngkCalc3 := gKknShukinKngkCalc3 + FLOOR(gZndkKngk * gRknShrTesuBunshi / gRknShrTesuBunbo::numeric * POWER(10, gScaleRkn)) / POWER(10, gScaleRkn);
								-- 手数料（税）= 手数料（税抜）×0.05　・・・端数切捨
							gKknShukinKngkCalc4 := gKknShukinKngkCalc4 + FLOOR(FLOOR(gZndkKngk * gRknShrTesuBunshi / gRknShrTesuBunbo * POWER(10, gScaleRkn)) / POWER(10, gScaleRkn) * gShohizei::numeric * POWER(10, gScaleRkn)) / POWER(10, gScaleRkn);
						ELSE
							-- <消費税総額方式>
								-- 手数料（税）= 手数料（税込）×5/105 ・・・端数切捨
						 	gKknShukinKngkCalc4 := gKknShukinKngkCalc4 + FLOOR(gZeikomiTesuKngk * gShohizei / (1 + gShohizei) * POWER(10, gScaleRkn)) / POWER(10, gScaleRkn);
								-- 手数料（税抜）= 手数料（税込）- 手数料（税）
							gKknShukinKngkCalc3 := gKknShukinKngkCalc3 + gZeikomiTesuKngk - FLOOR(gZeikomiTesuKngk * gShohizei / (1 + gShohizei) * POWER(10, gScaleRkn)) / POWER(10, gScaleRkn);
						END IF;
					END IF;
				END IF;
				ABND_TRACE := '利金：手数料計算処理後';
			END IF;
			-- 国税金額のブレイク条件でない場合、国税金額を加算する
			IF 		recAutoCreateKknShukinNext.ITAKU_KAISHA_CD			= recAutoCreateKknShukin.ITAKU_KAISHA_CD 	-- 委託会社コード
				AND	recAutoCreateKknShukinNext.MGR_CD					= recAutoCreateKknShukin.MGR_CD 				-- 銘柄コード
				AND	recAutoCreateKknShukinNext.SHR_YMD					= recAutoCreateKknShukin.SHR_YMD 			-- 支払日
				AND	recAutoCreateKknShukinNext.TSUKA_CD					= recAutoCreateKknShukin.TSUKA_CD 			-- 通貨コード
				THEN
				gTmpTotalGzeiKngk	:= gTmpTotalGzeiKngk + recAutoCreateKknShukinNext.TOTAL_GZEI_KNGK;			--国税金額を一時用合計変数に足していく
			END IF;
			-- 内側のループの中で次の行のデータ取得
			FETCH curAutoCreateKknShukin INTO recAutoCreateKknShukinNext;	-- 内側のループでフェッチ
			-- データが無くなったら内側のループを抜ける
			EXIT WHEN NOT FOUND;/* apply on curAutoCreateKknShukin */
			-- ブレイク条件に該当した場合、ループを抜ける（退避データ[一つ前のデータ]とブレイク項目を比較）
			EXIT WHEN
					recAutoCreateKknShukinNext.ITAKU_KAISHA_CD			<> recAutoCreateKknShukin.ITAKU_KAISHA_CD 			-- 委託会社コード
				OR	recAutoCreateKknShukinNext.MGR_CD					<> recAutoCreateKknShukin.MGR_CD 					-- 銘柄コード
				OR	recAutoCreateKknShukinNext.SHR_YMD					<> recAutoCreateKknShukin.SHR_YMD 					-- 支払日
				OR	recAutoCreateKknShukinNext.TSUKA_CD					<> recAutoCreateKknShukin.TSUKA_CD 					-- 通貨コード
				OR	recAutoCreateKknShukinNext.FINANCIAL_SECURITIES_KBN	<> recAutoCreateKknShukin.FINANCIAL_SECURITIES_KBN 	-- 金融証券区分
				OR	recAutoCreateKknShukinNext.BANK_CD					<> recAutoCreateKknShukin.BANK_CD 					-- 銀行コード
				OR	recAutoCreateKknShukinNext.KOZA_KBN					<> recAutoCreateKknShukin.KOZA_KBN 					-- 口座区分
				;
		END LOOP;
		ABND_TRACE := '償還期日SELECT前';
		--償還金請求金額(集計額)が０でない場合以下の処理を行う
		IF gTotalShokanSeikyuKngk != 0 THEN
			BEGIN
				SELECT
					MG3.SHOKAN_KJT,										--償還期日
					MG3.TESU_CHOKYU_YMD 									--手数料徴求日
				INTO STRICT
					gShokanKjt,
					gTesuChokyuYmd
				FROM
					MGR_SHOKIJ MG3
				WHERE MG3.ITAKU_KAISHA_CD =  recAutoCreateKknShukin.ITAKU_KAISHA_CD
				AND   MG3.MGR_CD		  =  recAutoCreateKknShukin.MGR_CD
				AND   MG3.SHOKAN_YMD	  =  recAutoCreateKknShukin.SHR_YMD
				AND   MG3.SHOKAN_KBN	  != '30'  LIMIT 1;
			EXCEPTION
				WHEN no_data_found THEN
					gShokanKjt := NULL;
					gTesuChokyuYmd := NULL;
			END;
			-- データが見つかったとき
			IF (gShokanKjt IS NOT NULL AND gShokanKjt::text <> '') THEN
				ABND_TRACE := '元金：基金異動INSERT処理前';
				--★★★★★★★★3-1をINSERT★★★★★★★★★
				CALL SFIPX021K00R01_01_insKikinIdo(	recAutoCreateKknShukin.ITAKU_KAISHA_CD,				--委託会社コード
								recAutoCreateKknShukin.MGR_CD,						--銘柄コード
								gShokanKjt,											--利払期日
								recAutoCreateKknShukin.SHR_YMD,						--利払日
								recAutoCreateKknShukin.TSUKA_CD,					--通貨コード
								recAutoCreateKknShukin.SHR_YMD,						--異動年月日
								'31',												--基金異動区分
								gTotalShokanSeikyuKngk,								--基金出金額
								recAutoCreateKknShukin.FINANCIAL_SECURITIES_KBN,	--金融証券区分(機構加入者)
								recAutoCreateKknShukin.BANK_CD,						--金融機関コード(機構加入者)
								recAutoCreateKknShukin.KOZA_KBN);					--口座区分(機構加入者)
				ABND_TRACE := '元金：基金異動INSERT処理後';
				--★★★★★★★★3-1をINSERT　END★★★★★★★★★
				--手数料徴求日がスペースではないとき
				IF gTesuChokyuYmd != ' ' THEN
					IF ((gTesuCapProcess = '1') AND (gGnknShrTesuCap > 0) AND (gJikoTotalHkukKbn = '1') AND (gKkKanyoFlg = '0')) THEN
						-- 消費税率適用基準日切り替え
						IF gShzKijunProcess = '1' THEN
							gShzKijunYmd := recAutoCreateKknShukin.SHR_YMD;
						ELSE
							gShzKijunYmd := gTesuChokyuYmd;
						END IF;
						--	元金支払手数料ＣＡＰを基に、手数料、消費税を計算する
						gRtnCd := PKIPACALCTESUKNGK.getTesuZeiTeigakuCommon(	recAutoCreateKknShukin.ITAKU_KAISHA_CD,
																				recAutoCreateKknShukin.MGR_CD,
																				gGnknShrTesuCap,
																				recAutoCreateKknShukin.TSUKA_CD,
																				gShzKijunYmd,
																				gCapZeinukiGaku,
																				gCapZeikomiGaku,
																				gCapZei
																			);
						IF (gRtnCd != pkconstant.success()) THEN
							RAISE EXCEPTION 'cap_calc_error' USING ERRCODE = '50001';
						END IF;	
						-- 元金支払手数料(税込金額) > 元金支払手数料ＣＡＰ(税込金額)の場合、ＣＡＰを採用する。
						IF (gKknShukinKngkCalc1 + gKknShukinKngkCalc2 > gCapZeikomiGaku) THEN
							gKknShukinKngkCalc1 := gCapZeinukiGaku;
							gKknShukinKngkCalc2 := gCapZei;
						END IF;
					END IF;
					--★★★★★★★★3-2をINSERT★★★★★★★★★
					CALL SFIPX021K00R01_01_insKikinIdo(	recAutoCreateKknShukin.ITAKU_KAISHA_CD,				--委託会社コード
									recAutoCreateKknShukin.MGR_CD,						--銘柄コード
									gShokanKjt,											--利払期日
									recAutoCreateKknShukin.SHR_YMD,						--利払日
									recAutoCreateKknShukin.TSUKA_CD,					--通貨コード
									gShrYmdYoku25,										--異動年月日
									'32',												--基金異動区分
									gKknShukinKngkCalc1,								--基金出金額
									recAutoCreateKknShukin.FINANCIAL_SECURITIES_KBN,	--金融証券区分(機構加入者)
									recAutoCreateKknShukin.BANK_CD,						--金融機関コード(機構加入者)
									recAutoCreateKknShukin.KOZA_KBN);					--口座区分(機構加入者)
						ABND_TRACE := '元金：手数料INSERT処理後';
					--★★★★★★★★3-2をINSERT　END★★★★★★★★★
					--消費税請求区分が「請求あり」の場合
					IF gSzeiSeikyuKbn = '1' THEN
						ABND_TRACE := '元金：手数料消費税INSERT処理前';
						--★★★★★★★★3-3をINSERT★★★★★★★★★
						CALL SFIPX021K00R01_01_insKikinIdo(	recAutoCreateKknShukin.ITAKU_KAISHA_CD,				--委託会社コード
										recAutoCreateKknShukin.MGR_CD,						--銘柄コード
										gShokanKjt,											--利払期日
										recAutoCreateKknShukin.SHR_YMD,						--利払日
										recAutoCreateKknShukin.TSUKA_CD,					--通貨コード
										gShrYmdYoku25,										--異動年月日
										'33',												--基金異動区分
										gKknShukinKngkCalc2,								--基金出金額
										recAutoCreateKknShukin.FINANCIAL_SECURITIES_KBN,	--金融証券区分(機構加入者)
										recAutoCreateKknShukin.BANK_CD,						--金融機関コード(機構加入者)
										recAutoCreateKknShukin.KOZA_KBN);					--口座区分(機構加入者)
						ABND_TRACE := '元金：手数料消費税INSERT処理後';
						--★★★★★★★★3-3をINSERT　END★★★★★★★★★
					END IF;
				END IF;
			END IF;
		END IF;
		--共通で使う変数を初期化する
		gTesuChokyuYmd := NULL;
		ABND_TRACE := '利払期日SELECT処理前';
		BEGIN
			SELECT
				MG2.RBR_KJT,
				MG2.TESU_CHOKYU_YMD 								--手数料徴求日
			INTO STRICT
				gRibaraiKijitsu,
				gTesuChokyuYmd
			FROM
				MGR_RBRKIJ MG2
				WHERE MG2.ITAKU_KAISHA_CD =  recAutoCreateKknShukin.ITAKU_KAISHA_CD
				AND   MG2.MGR_CD		  =  recAutoCreateKknShukin.MGR_CD
				AND   MG2.RBR_YMD		  =  recAutoCreateKknShukin.SHR_YMD  LIMIT 1;
			EXCEPTION
				WHEN no_data_found THEN
					gRibaraiKijitsu := NULL;
					gTesuChokyuYmd := NULL;
		END;
		-- データが見つかったとき
		IF (gRibaraiKijitsu IS NOT NULL AND gRibaraiKijitsu::text <> '') THEN
			-- ３−４、３−５、３−６
			-- 国税引後利金請求金額が０でない場合は以下の処理を行う
			IF gTotalGzeihikiAftChokyuKngk != 0 THEN
				ABND_TRACE := '利金：基金異動INSERT処理前';
				--★★★★★★★★3-4をINSERT★★★★★★★★★
				CALL SFIPX021K00R01_01_insKikinIdo(	recAutoCreateKknShukin.ITAKU_KAISHA_CD,					--委託会社コード
								recAutoCreateKknShukin.MGR_CD,							--銘柄コード
								gRibaraiKijitsu,										--利払期日
								recAutoCreateKknShukin.SHR_YMD,							--利払日
								recAutoCreateKknShukin.TSUKA_CD,						--通貨コード
								recAutoCreateKknShukin.SHR_YMD,							--異動年月日
								'41',													--基金異動区分
								gTotalGzeihikiAftChokyuKngk,							--基金出金額
								recAutoCreateKknShukin.FINANCIAL_SECURITIES_KBN,		--金融証券区分(機構加入者)
								recAutoCreateKknShukin.BANK_CD,							--金融機関コード(機構加入者)
								recAutoCreateKknShukin.KOZA_KBN);						--口座区分(機構加入者)
					ABND_TRACE := '利金：基金異動INSERT処理後';
				--★★★★★★★★3-4をINSERT　END★★★★★★★★★
			END IF;
			--手数料徴求日がスペースではないとき
			IF gTesuChokyuYmd != ' ' AND gKknShukinKngkCalc3 != 0 THEN
				-- 手数料種類に応じて利払手数料通貨コードを取得(元金ベース=発行通貨コード、利金ベース=利払通貨コード)
				BEGIN
					SELECT
						CASE WHEN MG7.TESU_SHURUI_CD='61' THEN MG1.HAKKO_TSUKA_CD WHEN MG7.TESU_SHURUI_CD='82' THEN MG1.RBR_TSUKA_CD END
					INTO STRICT
						gTsukaCd
					FROM
						MGR_KIHON MG1,
						(SELECT
							MG7.ITAKU_KAISHA_CD,
							MG7.MGR_CD,
							MG7.TESU_SHURUI_CD
						FROM	MGR_TESURYO_CTL MG7
							WHERE	MG7.TESU_SHURUI_CD IN ('61', '82')
								AND	MG7.CHOOSE_FLG = '1' ) MG7 
					WHERE	MG1.ITAKU_KAISHA_CD		= MG7.ITAKU_KAISHA_CD
						AND	MG1.MGR_CD				= MG7.MGR_CD
						AND	MG1.ITAKU_KAISHA_CD		= recAutoCreateKknShukin.ITAKU_KAISHA_CD
						AND	MG1.MGR_CD				= recAutoCreateKknShukin.MGR_CD;
				EXCEPTION
					WHEN no_data_found THEN
						gTsukaCd := NULL;
				END;
				IF (gRbrTsukaCd = recAutoCreateKknShukin.TSUKA_CD) THEN
					--★★★★★★★★3-5をINSERT★★★★★★★★★
					CALL SFIPX021K00R01_01_insKikinIdo(	recAutoCreateKknShukin.ITAKU_KAISHA_CD,					--委託会社コード
									recAutoCreateKknShukin.MGR_CD,							--銘柄コード
									gRibaraiKijitsu,										--利払期日
									recAutoCreateKknShukin.SHR_YMD,							--利払日
									gTsukaCd,												--通貨コード
									gShrYmdYoku25,											--異動年月日
									'42',													--基金異動区分
									gKknShukinKngkCalc3,									--基金出金額
									recAutoCreateKknShukin.FINANCIAL_SECURITIES_KBN,		--金融証券区分(機構加入者)
									recAutoCreateKknShukin.BANK_CD,							--金融機関コード(機構加入者)
									recAutoCreateKknShukin.KOZA_KBN);						--口座区分(機構加入者)
					ABND_TRACE := '利金：手数料INSERT処理後';
					--★★★★★★★★3-5をINSERT　END★★★★★★★★★
					--消費税請求区分が「請求あり」の場合
					IF gSzeiSeikyuKbn = '1' THEN
						ABND_TRACE := '利金：手数料消費税INSERT処理前';
						--★★★★★★★★3-6をINSERT★★★★★★★★★
						CALL SFIPX021K00R01_01_insKikinIdo(	recAutoCreateKknShukin.ITAKU_KAISHA_CD,					--委託会社コード
										recAutoCreateKknShukin.MGR_CD,							--銘柄コード
										gRibaraiKijitsu,										--利払期日
										recAutoCreateKknShukin.SHR_YMD,							--利払日
										gTsukaCd,												--通貨コード
										gShrYmdYoku25,											--異動年月日
										'43',													--基金異動区分
										gKknShukinKngkCalc4,									--基金出金額
										recAutoCreateKknShukin.FINANCIAL_SECURITIES_KBN,		--金融証券区分(機構加入者)
										recAutoCreateKknShukin.BANK_CD,							--金融機関コード(機構加入者)
										recAutoCreateKknShukin.KOZA_KBN);						--口座区分(機構加入者)
						ABND_TRACE := '利金：手数料消費税INSERT処理後';
						--★★★★★★★★3-6をINSERT　END★★★★★★★★★
					END IF;
				END IF;
			END IF;
		END IF;
		ABND_TRACE := '国税額レコード作成処理前';
		-- 利払回次にデータが見つかったとき国税額レコード作成処理
		IF (gRibaraiKijitsu IS NOT NULL AND gRibaraiKijitsu::text <> '') THEN
			--退避していた文字列とstring1が同じなら国税金額を足していく
			IF taihiString = string1 THEN
				gTotalGzeiKngk := gTotalGzeiKngk + gTmpTotalGzeiKngk;		--国税金額を足していく
			--退避していた文字列とstring1が違えばそれまで足していた国税金額を基にレコードを作成する
			ELSIF taihiString != string1 THEN
				IF (gTotalGzeiKngk > 0) THEN
					--支払日を強制的に１０日に変換(翌月１０を求めるため⇒営業日補正あり)
					gShrYmd := SUBSTR(wk_shrymd,1,6) || '10';
					--支払日の翌月１０日をここで取得する
					gShrYmdYoku10 := pkdate.calcMonthKyujitsuKbn(gShrYmd,1,gKyujitsuKbn,gAreaCd);
					ABND_TRACE := '国税額INSERT処理前';
					--★★★★★★★★3-7をINSERT★★★★★★★★★
					CALL SFIPX021K00R01_01_insKikinIdo(l_inItakuKaishaCd,					--委託会社コード
								wk_mgrCd,							--銘柄コード
								wk_rbrKjt,							--利払期日
								wk_shrymd,							--利払日
								wk_tsukaCd,							--通貨コード
								gShrYmdYoku10,						--異動年月日
								'51',								--基金異動区分
								gTotalGzeiKngk,						--基金出金額
								' ',								--金融証券区分(機構加入者)
								' ',								--金融機関コード(機構加入者)
								' ');								--口座区分(機構加入者)
					ABND_TRACE := '国税額INSERT処理後';
					--★★★★★★★★3-7をINSERT　END★★★★★★★★★
				END IF;
				-- 次のレコードで加算する国税金額をセット（既に保持してある分をセットする）
				gTotalGzeiKngk := gTmpTotalGzeiKngk;
			END IF;
			--データの退避
			wk_mgrCd   := recAutoCreateKknShukin.MGR_CD;
			wk_tsukaCd := recAutoCreateKknShukin.TSUKA_CD;
			wk_shrYmd  := recAutoCreateKknShukin.SHR_YMD;
			wk_rbrKjt  := gRibaraiKijitsu;
			gTotalShokanSeikyu := recAutoCreateKknShukin.TOTAL_SHOKAN_SEIKYU_KNGK;
			taihiString := string1;
		END IF;
		-- データが見つかったとき（償還回次か利払回次）
		IF (gShokanKjt IS NOT NULL AND gShokanKjt::text <> '') OR (gRibaraiKijitsu IS NOT NULL AND gRibaraiKijitsu::text <> '') THEN
			--データがあったのでデータカウンタを増やす
			gDataCnt := gDataCnt + 1;
		END IF;
	END LOOP;
	CLOSE curAutoCreateKknShukin;
	IF gDataCnt = 0  THEN
		-- 対象データなし
		gRtnCd := RTN_NODATA;
	-- 利払回次にデータが見つかったとき国税額レコード作成処理
	ELSIF (wk_rbrKjt IS NOT NULL AND wk_rbrKjt::text <> '') AND gTotalGzeiKngk > 0 THEN
		--支払日を強制的に１０日に変換(翌月１０を求めるため⇒営業日補正あり)
		gShrYmd := SUBSTR(wk_shrYmd,1,6) || '10';
		--支払日の翌月１０日をここで取得する
		gShrYmdYoku10 := pkdate.calcMonthKyujitsuKbn(gShrYmd,1,gKyujitsuKbn,gAreaCd);
		--ループが終わったかつ償還金請求金額合計と国税金額合計が０でない場合、３−７(国税)のレコードを作成する。
		ABND_TRACE := 'ループ終了＆国税額INSERT処理前';
		--★★★★★★★★3-7をINSERT★★★★★★★★★
		CALL SFIPX021K00R01_01_insKikinIdo(l_inItakuKaishaCd,					--委託会社コード
					wk_mgrCd,							--銘柄コード
					wk_rbrKjt,							--利払期日
					wk_shrymd,							--利払日
					wk_tsukaCd,							--通貨コード
					gShrYmdYoku10,						--異動年月日
					'51',								--基金異動区分
					gTotalGzeiKngk,						--基金出金額
					' ',								--金融証券区分(機構加入者)
					' ',								--金融機関コード(機構加入者)
					' ');								--口座区分(機構加入者)
		ABND_TRACE := 'ループ終了＆国税額INSERT処理後';
		--★★★★★★★★3-7をINSERT　END★★★★★★★★★
		gRtnCd := RTN_OK;
	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug('BATCH', C_FUNCTION_ID, C_FUNCTION_ID || ' END');	END IF;
	-- 終了処理
	RETURN gRtnCd;
-- エラー処理
EXCEPTION
	-- その他・例外エラー 
	WHEN OTHERS THEN
		BEGIN
			CLOSE curAutoCreateKknShukin;
		EXCEPTION
			WHEN OTHERS THEN NULL;
		END;
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '-----------------------------------------障害発生-----------------------------------------');
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '【入力パラメータ】　委託会社コード：' || l_inItakuKaishaCd || ' 銘柄コード：' || l_inMgrCd  || ' 元利払日：' || l_inGnrYmd );
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '【エラーデータ】　委託会社:' || gkeyItakuKaishaCd || ' 銘柄コード:' || gkeyMgrCd || ' 支払日:' || gkeyShrYmd);
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '【エラートレース】：' || ABND_TRACE);
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'SQLERRM:'||SQLERRM);
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '-------------------------------------------END--------------------------------------------');
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '-----------------------------------------参考情報------------------------------------------');
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '【手数料計算用データ】　gGnknShrTesuBunshi:' || gGnknShrTesuBunshi || ' gGnknShrTesuBunbo:' || gGnknShrTesuBunbo);
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '【手数料計算用データ】　gRknShrTesuBunshi:' || gRknShrTesuBunshi || ' gRknShrTesuBunbo:' || gRknShrTesuBunbo);
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '-------------------------------------------END--------------------------------------------');
		RETURN RTN_FATAL;
--		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipx021k00r01_01 ( l_inItakuKaishaCd TEXT, l_inMgrCd TEXT, l_inGnrYmd TEXT  ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfipx021k00r01_01_inskikinido ( 
	l_inItakuKaishaCD KIKIN_IDO.ITAKU_KAISHA_CD%TYPE, 
	l_inMgrCd KIKIN_IDO.MGR_CD%TYPE, 
	l_inRbrKjt KIKIN_IDO.RBR_KJT%TYPE, 
	l_inRbrYmd KIKIN_IDO.RBR_YMD%TYPE, 
	l_inTsukaCd KIKIN_IDO.TSUKA_CD%TYPE, 
	l_inIdoYmd KIKIN_IDO.IDO_YMD%TYPE, 
	l_inKknIdoKbn KIKIN_IDO.KKN_IDO_KBN%TYPE, 
	l_inTotalShokanSeikyuKngk KIKIN_IDO.KKN_SHUKIN_KNGK%TYPE, 
	l_inFinancialSecuritiesKbn KIKIN_IDO.KKMEMBER_FS_KBN%TYPE, 
	l_inBankCd KIKIN_IDO.KKMEMBER_BCD%TYPE, 
	l_inKozaKbn KIKIN_IDO.KKMEMBER_KKBN%TYPE ) AS $body$
BEGIN
	INSERT INTO
		KIKIN_IDO(	ITAKU_KAISHA_CD,						--委託会社コード
					MGR_CD,									--銘柄コード
					RBR_KJT,								--利払期日
					RBR_YMD,								--利払日
					TSUKA_CD,								--通貨コード
					IDO_YMD,								--異動年月日
					KKN_IDO_KBN,							--基金異動区分
					KKNBILL_SHURUI,							--基金請求種類
					KKN_NYUKIN_KNGK,						--基金入金額
					KKN_SHUKIN_KNGK,						--基金出金額
					KKMEMBER_FS_KBN,						--金融証券区分(機構加入者)
					KKMEMBER_BCD,							--金融機関コード(機構加入者)
					KKMEMBER_KKBN,							--口座区分(機構加入者)
					NYUKIN_KAKUNIN_YMD,						--入金確認日
					NYUKIN_STS_KBN,							--入金状況区分
					DATA_SAKUSEI_KBN,						--データ作成区分
					ZNDK_KIJUN_YMD,							--残高基準日
					KIJUN_ZNDK,								--基準残高
					EB_MAKE_YMD,							--EB作成年月日
					EB_SEND_YMD,							--EB送信年月日
					GROUP_ID,								--グループID
					SHORI_KBN,								--処理区分
					SAKUSEI_ID,								--作成者
					KOUSIN_ID)								--更新者
			VALUES (	l_inItakuKaishaCD,
					l_inMgrCd,
					l_inRbrKjt,
					l_inRbrYmd,
					l_inTsukaCd,
					l_inIdoYmd,
					l_inKknIdoKbn,
					' ',
					0,
					l_inTotalShokanSeikyuKngk,
					l_inFinancialSecuritiesKbn,
					l_inBankCd,
					l_inKozaKbn,
					' ',
					'0',
					' ',
					' ',
					0,
					' ',
					' ',
					' ',
					'0',
					'BATCH',
					'BATCH');
RETURN;
EXCEPTION
	WHEN OTHERS THEN
		-- 呼出元の例外処理へ遷移
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfipx021k00r01_01_inskikinido ( l_inItakuKaishaCD KIKIN_IDO.ITAKU_KAISHA_CD%TYPE, l_inMgrCd KIKIN_IDO.MGR_CD%TYPE, l_inRbrKjt KIKIN_IDO.RBR_KJT%TYPE, l_inRbrYmd KIKIN_IDO.RBR_YMD%TYPE, l_inTsukaCd KIKIN_IDO.TSUKA_CD%TYPE, l_inIdoYmd KIKIN_IDO.IDO_YMD%TYPE, l_inKknIdoKbn KIKIN_IDO.KKN_IDO_KBN%TYPE, l_inTotalShokanSeikyuKngk KIKIN_IDO.KKN_SHUKIN_KNGK%TYPE, l_inFinancialSecuritiesKbn KIKIN_IDO.KKMEMBER_FS_KBN%TYPE, l_inBankCd KIKIN_IDO.KKMEMBER_BCD%TYPE, l_inKozaKbn KIKIN_IDO.KKMEMBER_KKBN%TYPE ) FROM PUBLIC;