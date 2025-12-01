


DROP TYPE IF EXISTS spip03504_01_type_record;
CREATE TYPE spip03504_01_type_record AS (
		gBankCd					char(4)			-- 金融機関コード
		,gPostNo				char(7)				-- 郵便番号
		,gAdd1					varchar(50)				-- 住所１
		,gAdd2					varchar(50)				-- 住所２
		,gAdd3					varchar(50)				-- 住所３
		,gSfskBankNm			varchar(70)					-- 送付先金融機関名称
		,gSfskBushoNm			varchar(50)			-- 送付先担当部署名称
		,gSfmtBankNm			varchar(60) 			-- 送付元金融機関名称
		,gSfmtBushoNm			varchar(50) 			-- 送付元担当部署名称
		,gChokyuYmd				char(8)				-- 徴求日
		,gDistriYmd				char(8)				-- 分配日
		,gMochidashiTmg			numeric(2)	-- 持出タイミング
		,gKoukanjoNm			varchar(10)		-- 交換所名称
		,gHakkoYmd				char(8)			-- 発行日
		,gHakkoTsukaCd			char(3)		-- 発行通貨コード
		,gRbrTsukaCd			char(3)			-- 利払通貨コード
		,gShokanTsukaCd			char(3)		-- 償還通貨コード
		,gTsukaCd				char(3)				-- 通貨コード
		,gTsukaNm				char(3)				-- 通貨コード名称
		,gIsinCd				char(12)				-- ＩＳＩＮコード
		,gMgrRnm				varchar(44)				-- 銘柄略称
		,gShasaiTotal			numeric(14)			-- 社債の総額
		,gTesuRitsuBunshi		decimal(7,4)							-- 手数料率分子
		,gTesuRitsuBunbo		numeric(5)		-- 手数料率分母
		,gDfBunshi				numeric(5)		-- 分配率分子
		,gDfBunbo				numeric(5)				-- 分配率分母
		,gBunpaiKngk			decimal(14,2)						-- 分配額
		,gUchiSzei 				decimal(14,2)						-- 内消費税
		,gTesuryoKomiFlg		char(1) 	-- 手数料税込フラグ
		,gMgrCd					varchar(13)				-- 銘柄コード
		,gSzeiSeikyuKbn         char(1)-- 消費税請求区分
	);
DROP TYPE IF EXISTS spip03504_01_type_key;
CREATE TYPE spip03504_01_type_key AS (
		gBankCd					char(4)	-- 金融機関コード
		,gDistriYmd				char(8)		-- 分配日
		,gTsukaCd				char(3)		-- 通貨コード
	);
DROP TYPE IF EXISTS spip03504_01_type_gokei;
CREATE TYPE spip03504_01_type_gokei AS (
		gBunpaiKngk				decimal(16,2)					-- 分配額
		,gUchiSzei 				decimal(16,2)					-- 内消費税
	);


CREATE OR REPLACE PROCEDURE spip03504_01 ( l_inKijunYmdF TEXT,		-- 基準日(From)
 l_inKijunYmdT TEXT,		-- 基準日(To)
 l_inHktCd TEXT,		-- 発行体コード
 l_inKozaTenCd TEXT,		-- 口座店コード
 l_inKozaTenCifCd TEXT,		-- 口座店CIFコード
 l_inMgrCd TEXT,		-- 銘柄コード
 l_inIsinCd TEXT,		-- ISINコード
 l_inTsuchiYmd TEXT,		-- 通知日
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
-- * @version $Id: SPIP03504_01.SQL,v 1.29 2023/06/01 02:13:15 sudo Exp $
--/* 概要	:顧客宛帳票出力指示画面の入力条件により、募集受託手数料分配予定通知書を作成する。
--/* 引数	:	l_inKijunYmdF			IN	TEXT		基準日(From)
--/*			l_inKijunYmdT			IN	TEXT		基準日(To)
--/*			l_inHktCd				IN	TEXT		発行体コード
--/*			l_inKozaTenCd			IN	TEXT		口座店コード
--/*			l_inKozaTenCifCd		IN	TEXT		口座店CIFコード
--/*			l_inMgrCd				IN	TEXT		銘柄コード
--/*			l_inIsinCd				IN	TEXT		ISINコード
--/*			l_inTsuchiYmd			IN	TEXT		通知日
--/*			l_inItakuKaishaCd		IN	TEXT		委託会社コード
--/*			l_inUserId				IN	TEXT		ユーザーID
--/*			l_inChohyoKbn			IN	TEXT		帳票区分
--/*			l_inGyomuYmd			IN	TEXT		業務日付
--/*			l_inStRecKbn			IN	TEXT,		初回レコード区分
--/*			l_outSqlCode			OUT	INTEGER		リターン値
--/*			l_outSqlErrM			OUT	VARCHAR	エラーコメント
--/* 返り値:なし
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.02.24	JIP				新規作成
--/*　2005.08.26  JIP				引数に初回レコード区分を追加。初回のみ帳票WKを削除するように変更
--/*　2005.08.30  JIP				帳票WKの連番を1から振っていたのをMAX+1からに変更
--/*								対象データなしレコード作成処理を削除
--/*　2022.10.21  池田（幸）		#26986_電子交換所開設に伴う帳票文言の変更対応
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
	RTN_OK				CONSTANT integer		:= 0;				-- 正常
	RTN_NG				CONSTANT integer		:= 1;				-- 予期したエラー
--	RTN_NODATA			CONSTANT INTEGER		:= 2;				-- データなし
	RTN_FATAL			CONSTANT integer		:= 99;				-- 予期せぬエラー
	REPORT_ID			CONSTANT char(11)		:= 'IP030003541';	-- 帳票ID
	-- 書式フォーマット
	FMT_HAKKO_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	FMT_RBR_KNGK_J		CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 利払金額
	FMT_SHOKAN_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 償還金額
	-- 書式フォーマット（外資）
	FMT_HAKKO_KNGK_F	CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 発行金額
	FMT_RBR_KNGK_F		CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 利払金額
	FMT_SHOKAN_KNGK_F	CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 償還金額
	FMT_ZEI_KOMI		CONSTANT char(8)	:= 'ZZ9.9999';				-- 税込フォーマット
	FMT_ZEI_NUKI		CONSTANT char(6)	:= 'ZZ9.99';				-- 税抜きフォーマット
	TSUCHI_YMD_DEF		CONSTANT char(16)	:= '      年  月  日';		-- 通知日（デフォルト）
	KOUKAN_TOKYO		CONSTANT MBANK_ZOKUSEI.KOUKANJO_NM%TYPE	:= '東京';
	KOUKAN_MSG1			CONSTANT char(14)	:= '交換（貴行持出';
	KOUKAN_MSG2			CONSTANT char(48)	:= '）にてご請求くださいますようお願い申しあげます。';
--	ST_REC_KBN_FIRST	CONSTANT CHAR(1)		:= '1';					-- 初回レコード区分（初回）
    INVOICE_OPTION_FLG  CONSTANT char(1)		:= '1';	                -- インボイスオプションフラグ(オン)
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
--	gRtnCd				INTEGER DEFAULT	RTN_OK;						-- リターンコード
	gSeqNo				integer := 0;							-- シーケンス
	gSeqNoIni			integer := 0;							-- シーケンス
	gBunpaiRtnCd		integer := 0;							-- リターンコード
	-- 書式フォーマット
	gFmtHakkoKngk		varchar(21)	:= NULL;				-- 発行金額
	gFmtRbrKngk			varchar(21)	:= NULL;				-- 利払金額
	gFmtShokanKngk		varchar(21)	:= NULL;				-- 償還金額
	gFmtZei				varchar(8)		:= NULL;				-- 税込税抜きフォーマット
	-- DB取得項目
	recMeisai spIp03504_01_TYPE_RECORD;						-- レコード
	gWrkTsuchiYmd				varchar(16) := NULL;			-- 通知日(西暦)
	gWrkMotidashiYmd			char(8) := '';					-- 持出日
	gKoukanMsg					varchar(82)	:= '';			-- 交換メッセージ
	-- 宛名編集
	gAtena					varchar(200) := NULL;				-- 宛名1行目
	gOutflg					numeric := 0;						-- 正常処理フラグ
	gAtenaName1				varchar(200) := NULL;				-- 宛名用名称１
	gAtenaName2				varchar(200) := NULL;				-- 宛名用名称２
	gAtenaName3				varchar(200) := NULL;				-- 宛名用名称３
	-- キー
	-- 合計
	key spIp03504_01_TYPE_KEY;							-- キー
	gokei spIp03504_01_TYPE_GOKEI;							-- 合計
	recPrevMeisai spIp03504_01_TYPE_RECORD;						-- 前レコード
	gShzKijunProcess			MPROCESS_CTL.CTL_VALUE%TYPE;		-- 消費税率適用基準日対応
	gShzKijunYmd				varchar(8);						-- 消費税率適用基準日
	gBunBunpaiBun1				varchar(100) := '';			-- 分配予定通知書文章(分配予定通知書)１行目
	gBunBunpaiBun2				varchar(100) := '';			-- 分配予定通知書文章(分配予定通知書)２行目
	gInvoiceFlg                 MOPTION_KANRI.OPTION_FLG%TYPE;      -- インボイスオプションフラグ
	gInvoiceTaxKbnFlg           MPROCESS_CTL.CTL_VALUE%TYPE;        -- インボイス税区分フラグ
	gInvoiceTourokuNo           varchar(14) := NULL;          -- 適格請求書発行事業者登録番号
	gInvoiceTaxKbnNm            varchar(40) := NULL;          -- インボイス税区分名称
	gTesuSzeiLabel              varchar(10) := NULL;          -- 内消費税ラベル
	gBunsho                     varchar(150) := NULL;         -- インボイス文章
	gTsukaNm                    varchar(3) := NULL;           -- 適格請求書_通貨コード名称
	gInvoiceTesuKngkSum         decimal(16,2);                       -- 適格請求書_分配額合計
	gInvoiceTesuSzei            decimal(14,2);                       -- 適格請求書_内消費税
	gBunpaiKngkLabel            varchar(200) := NULL;         -- 分配額ラベル
	gShohiZeiRate               numeric;                             -- 消費税率
	gAryBun				        pkIpaBun.BUN_ARRAY;					-- インボイス文章(請求書)配列
	gSeqNoSta				integer;						-- シーケンス開始
	gInvoiceShzKijunYmd			TESURYO.CHOKYU_YMD%TYPE;				-- 適格請求書_内消費税算出　消費税率適用基準日
--==============================================================================
--					カーソル定義												
--==============================================================================
	curMeisai CURSOR FOR
		SELECT T02.BANK_CD,									-- 金融機関コード
				M091.POST_NO,								-- 郵便番号
				M091.ADD1,									-- 住所１
				M091.ADD2,									-- 住所２
				M091.ADD3,									-- 住所３
				M021.BANK_NM AS SFSK_BANK_NM,				-- 送付先金融機関名称
				M091.BUSHO_NM AS SFSK_BUSHO_NM,				-- 送付先担当部署名称
				VJ1.BANK_NM AS SFMT_BANK_NM,				-- 送付元金融機関名称
				VJ1.BUSHO_NM1 AS SFMT_BUSHO_NM,				-- 送付元担当部署名称
				T01.CHOKYU_YMD,								-- 徴求日
				T01.CHOKYU_YMD,								-- ※徴求日(1.2次仮対応で分配日の代用)
				M08.MOCHIDASHI_TMG,							-- 持出タイミング
				coalesce(TRIM((SELECT M08J.KOUKANJO_NM FROM MBANK_ZOKUSEI M08J
							WHERE	M08J.ITAKU_KAISHA_CD = VJ1.KAIIN_ID
							AND	M08J.FINANCIAL_SECURITIES_KBN = VJ1.OWN_FINANCIAL_SECURITIES_KBN
							AND	M08J.BANK_CD = VJ1.OWN_BANK_CD))
					,KOUKAN_TOKYO) AS KOUKANJO_NM,			-- 交換所名称	※自行の交換所名称　未設定の場合デフォルトは東京
				VMG1.HAKKO_YMD,								-- 発行日
				VMG1.HAKKO_TSUKA_CD,						-- 発行通貨コード
				VMG1.RBR_TSUKA_CD,							-- 利払通貨コード
				VMG1.SHOKAN_TSUKA_CD,						-- 償還通貨コード
				T01.TSUKA_CD,								-- 通貨コード
				M64.TSUKA_NM,								-- 通貨コード名称
				VMG1.ISIN_CD,								-- ＩＳＩＮコード
				VMG1.MGR_RNM,								-- 銘柄略称
				VMG1.SHASAI_TOTAL,							-- 社債の総額
				T01.TESU_RITSU_BUNSHI,						-- 手数料率分子
				T01.TESU_RITSU_BUNBO,						-- 手数料率分母
				T02.DF_BUNSHI,								-- 分配率分子
				T01.DF_BUNBO,								-- 分配率分母
				-- 分配額税込に補正額を反映させるか判断する関数を使用
				PKIPACALCTESURYO.getHoseiKasanKngk(
					 T02.DF_TESU_KNGK + T02.DF_TESU_SZEI  				 -- 全体分配額税込
					,T02.HOSEI_DF_TESU_KNGK + T02.HOSEI_DF_TESU_SZEI  	 -- 補正分配額
					,T01.DATA_SAKUSEI_KBN
					,T01.SHORI_KBN) AS BUNPAI_KNGK,			-- 分配額
				-- 全体消費税額に補正額を反映させるか判断する関数を使用
				PKIPACALCTESURYO.getHoseiKasanKngk(
					 T02.DF_TESU_SZEI  						-- 分配消費税額
					,T02.HOSEI_DF_TESU_SZEI  				-- 補正消費税額
					,T01.DATA_SAKUSEI_KBN 
					,T01.SHORI_KBN) AS UCHI_SZEI,			-- 内消費税
				VJ1.TESURYO_KOMI_FLG,						-- 手数料税込フラグ
				VMG1.MGR_CD, 								-- 銘柄コード
				MG8.SZEI_SEIKYU_KBN                          -- 消費税請求区分
		FROM 	TESURYO T01,
				TESURYO_BUNPAI T02,
				MGR_KIHON_VIEW VMG1,
				MHAKKOTAI M01,
				MBANK M021,
				MBANK_SFSK M091,
				MBANK_ZOKUSEI M08,
				MTSUKA M64,
				VJIKO_ITAKU VJ1,
				MGR_TESURYO_PRM	MG8
		WHERE	T01.ITAKU_KAISHA_CD = 	l_inItakuKaishaCd
		AND 	T01.CHOKYU_YMD BETWEEN	l_inKijunYmdF
								   AND	l_inKijunYmdT
		AND 	T01.ITAKU_KAISHA_CD = T02.ITAKU_KAISHA_CD 
		AND 	T01.MGR_CD = T02.MGR_CD 
		AND 	T01.TESU_SHURUI_CD = T02.TESU_SHURUI_CD 
		AND 	T01.CHOKYU_KJT = T02.CHOKYU_KJT 
		AND 	T02.TESU_SHURUI_CD IN ('01','02') 
		AND 	T02.JTK_KBN = '2' 
		AND 	T01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD 
		AND 	T01.MGR_CD = VMG1.MGR_CD 
		AND 	VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD 
		AND 	VMG1.HKT_CD = M01.HKT_CD 
		AND 	T02.FINANCIAL_SECURITIES_KBN = M021.FINANCIAL_SECURITIES_KBN 
		AND 	T02.BANK_CD = M021.BANK_CD 
		AND 	T02.ITAKU_KAISHA_CD = M091.ITAKU_KAISHA_CD 
		AND 	T02.FINANCIAL_SECURITIES_KBN = M091.FINANCIAL_SECURITIES_KBN 
		AND 	T02.BANK_CD = M091.BANK_CD 
		AND 	T02.ITAKU_KAISHA_CD = M08.ITAKU_KAISHA_CD 
		AND 	T02.FINANCIAL_SECURITIES_KBN = M08.FINANCIAL_SECURITIES_KBN 
		AND 	T02.BANK_CD = M08.BANK_CD 
		AND 	M091.SFSK_SHURUI = '1' 
		AND 	VJ1.KAIIN_ID =	VMG1.ITAKU_KAISHA_CD
		AND 	T01.TSUKA_CD = M64.TSUKA_CD 
		AND 	(trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '') 
		AND 	VMG1.MGR_STAT_KBN = '1'
		AND 	VMG1.JTK_KBN <> '2' 		-- 銘柄_基本の受託区分は副受託以外のものに限る
		AND (VMG1.HKT_CD		= l_inHktCd			OR coalesce(l_inHktCd::text, '') = '')
		AND (M01.KOZA_TEN_CD	= l_inKozaTenCd		OR coalesce(l_inKozaTenCd::text, '') = '')
		AND (M01.KOZA_TEN_CIFCD	= l_inKozaTenCifCd	OR coalesce(l_inKozaTenCifCd::text, '') = '')
		AND (VMG1.MGR_CD		= l_inMgrCd			OR coalesce(l_inMgrCd::text, '') = '')
		AND (VMG1.ISIN_CD		= l_inIsinCd		OR coalesce(l_inIsinCd::text, '') = '')
		AND     T02.MGR_CD = MG8.MGR_CD
		AND     T02.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD 
		ORDER BY 	T02.BANK_CD,
					T01.DISTRI_YMD,
					T01.TSUKA_CD,
					VMG1.ISIN_CD 
		;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp03504_01 START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inKijunYmdF)::text, '') = ''
	OR coalesce(trim(both l_inKijunYmdT)::text, '') = ''
	OR coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inUserId)::text, '') = ''
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''
	OR coalesce(trim(both l_inGyomuYmd)::text, '') = ''
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error(l_inUserId, REPORT_ID, 'SQLERRM:'||'');
		RETURN;
	END IF;
	-- 初回レコードの場合
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;
	-- 消費税率適用基準日フラグ(1:取引日ベース, 0:徴求日ベース(デフォルト))取得
	gShzKijunProcess := pkControl.getCtlValue(l_inItakuKaishaCd, 'ShzKijun', '0');
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	-- インボイスオプションフラグを取得する
	gInvoiceFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd,'INVOICE_E','0');
	-- ローカル変数．インボイスオプションフラグが"1"の場合
	IF gInvoiceFlg = INVOICE_OPTION_FLG THEN
	    -- インボイス税区分フラグを取得する
	    gInvoiceTaxKbnFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'INVOICE_ZeiNm', '0');
	     -- 適格請求書発行事業者登録番号を取得する
	    SELECT INVOICE_TOUROKU_NO
	    INTO STRICT gInvoiceTourokuNo
	    FROM VJIKO_ITAKU
	    WHERE KAIIN_ID = l_inItakuKaishaCd;
	    -- インボイス税区分名称を取得する
	    BEGIN
	        SELECT CODE_NM
	        INTO STRICT gInvoiceTaxKbnNm
	        FROM SCODE
	        WHERE CODE_SHUBETSU = '246'
	        AND CODE_VALUE = gInvoiceTaxKbnFlg;
	    EXCEPTION
	        WHEN OTHERS THEN
	            gInvoiceTaxKbnNm := '';
	    END;
	    -- 内消費税ラベル
	    gTesuSzeiLabel := '内消費税';
	    -- インボイス文章取得
	    gAryBun := pkIpaBun.getBun(REPORT_ID, 'L0');
	    FOR i IN 0..coalesce(cardinality(gAryBun), 0) - 1 LOOP
	         IF i = 0 THEN
	             gBunsho := gAryBun[i];
	         END IF;
	    END LOOP;
	END IF;
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
	gSeqNoSta  := gSeqNoIni + 1;	-- 合計更新時の最初の連番
	-- 通知日の西暦変換
	gWrkTsuchiYmd := TSUCHI_YMD_DEF;
	IF (trim(both l_inTsuchiYmd) IS NOT NULL AND (trim(both l_inTsuchiYmd))::text <> '') THEN
		gWrkTsuchiYmd := pkDate.seirekiChangeSuppressNenGappi(l_inTsuchiYmd);
	END IF;
	-- カーソルオープン
	OPEN curMeisai;
	LOOP
	-- データ取得
		FETCH curMeisai INTO recMeisai;
		EXIT WHEN NOT FOUND;/* apply on curMeisai */
		-- 【1.2次仮対応】START
--		 * 1.2次時点でTESURYO.DISTRI_YMD(分配日)がブランクのため
--		 * recMeisai.gDistriYmdとして徴求日を取得し、
--		 * 徴求日＋３営業日を分配日とする。
--		 * 正式対応時の修正はcurMeisaiのSQL(SELECT句)と下記仮対応ロジックの削除
--		 
		recMeisai.gDistriYmd := pkDate.getPlusDateBusiness(recMeisai.gDistriYmd, 3, 1);
		--【1.2次仮対応】END
		-- 持出日計算
		gWrkMotidashiYmd := NULL;
		-- 分配日と持出タイミングが両方入っている場合に計算する（分配日−持出タイミング日数営業日前）
		IF (trim(both recPrevMeisai.gDistriYmd) IS NOT NULL AND (trim(both recPrevMeisai.gDistriYmd))::text <> '') AND
			(trim(both recPrevMeisai.gMochidashiTmg) IS NOT NULL AND (trim(both recPrevMeisai.gMochidashiTmg))::text <> '') THEN
			gWrkMotidashiYmd := PKDATE.getMinusDateBusiness(recPrevMeisai.gDistriYmd,recPrevMeisai.gMochidashiTmg);
		END IF;
		-- 交換メッセージのセット
		IF (gWrkMotidashiYmd IS NOT NULL AND gWrkMotidashiYmd::text <> '') THEN
			gKoukanMsg := 'の' || recPrevMeisai.gKoukanjoNm || KOUKAN_MSG1 || substr(PKDATE.seirekiChangeSuppressNenGappi(gWrkMotidashiYmd),7) || KOUKAN_MSG2;
		ELSE
			gKoukanMsg := 'の' || recPrevMeisai.gKoukanjoNm || KOUKAN_MSG1 || '　  　  ' || KOUKAN_MSG2;
		END IF;
		-- 分配予定通知書文書取得
		SELECT * FROM spIp03504_01_getBunpaiBun(recPrevMeisai.gDistriYmd, '00') INTO STRICT gBunBunpaiBun1, gBunBunpaiBun2;
		IF key.gBankCd != recMeisai.gBankCd
		OR key.gDistriYmd != recMeisai.gDistriYmd
		OR key.gTsukaCd != recMeisai.gTsukaCd
		THEN
		-- キーブレイク、合計出力
			IF gSeqNo > gSeqNoIni THEN
				gSeqNo := gSeqNo + 1;
				-- インボイスオプションフラグが"1"の場合
				IF gInvoiceFlg = INVOICE_OPTION_FLG THEN
					-- 適格請求書_分配額合計
					gInvoiceTesuKngkSum := gokei.gBunpaiKngk;
					-- ローカル変数．前レコード．消費税請求区分　が「0」の場合
					IF recPrevMeisai.gSzeiSeikyuKbn = '0' THEN
					    -- 適格請求書_内消費税
					    gInvoiceTesuSzei := 0;
					-- ローカル変数．前レコード．消費税請求区分　が「1」の場合
					ELSIF recPrevMeisai.gSzeiSeikyuKbn = '1' THEN
					    -- 適格請求書_内消費税　手数料消費税額計算（割戻用）を行う
					    gInvoiceTesuSzei := PKIPACALCTESUKNGK.getTesuZeiWarimodoshi(gInvoiceShzKijunYmd, gInvoiceTesuKngkSum, recPrevMeisai.gHakkoTsukaCd);
					END IF;
					-- 合計更新処理
					UPDATE SREPORT_WK SET
						ITEM034 = gInvoiceTesuKngkSum,
						ITEM036 = gInvoiceTesuSzei
					WHERE KEY_CD = l_inItakuKaishaCd
					AND USER_ID = l_inUserId
					AND CHOHYO_KBN = l_inChohyoKbn
					AND SAKUSEI_YMD = l_inGyomuYmd
					AND CHOHYO_ID = REPORT_ID
					AND (SEQ_NO >= gSeqNoSta AND SEQ_NO < gSeqNo);
				END IF;
				-- 帳票ワークへデータを追加
						-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gWrkTsuchiYmd;	-- 通知日
		v_item.l_inItem002 := recPrevMeisai.gPostNo;	-- 郵便番号
		v_item.l_inItem003 := recPrevMeisai.gAdd1;	-- 住所１
		v_item.l_inItem004 := recPrevMeisai.gAdd2;	-- 住所２
		v_item.l_inItem005 := recPrevMeisai.gAdd3;	-- 住所３
		v_item.l_inItem006 := gAtena;	-- 送付先金融機関名称
		v_item.l_inItem007 := recPrevMeisai.gSfmtBankNm;	-- 送付元金融機関名称
		v_item.l_inItem008 := recPrevMeisai.gSfmtBushoNm;	-- 送付元担当部署名称
		v_item.l_inItem009 := recPrevMeisai.gDistriYmd;	-- 分配日
		v_item.l_inItem010 := gKoukanMsg;	-- 交換メッセージ（持出日込み）
		v_item.l_inItem011 := recPrevMeisai.gTsukaNm;	-- 通貨コード名称
		v_item.l_inItem021 := gFmtHakkoKngk;	-- 発行金額書式フォーマット
		v_item.l_inItem022 := gFmtRbrKngk;	-- 利払金額書式フォーマット
		v_item.l_inItem023 := gFmtShokanKngk;	-- 償還金額書式フォーマット
		v_item.l_inItem025 := gFmtZei;	-- 税込税抜きフォーマット
		v_item.l_inItem026 := gokei.gBunpaiKngk;	-- 分配額
		v_item.l_inItem027 := gokei.gUchiSzei;	-- 内消費税
		v_item.l_inItem028 := recPrevMeisai.gBankCd;	-- 金融機関コード
		v_item.l_inItem029 := gBunBunpaiBun1;	-- 分配予定通知書文書１
		v_item.l_inItem030 := gBunBunpaiBun2;	-- 分配予定通知書文書２
		v_item.l_inItem031 := gInvoiceTourokuNo;	-- 適格請求書発行事業者登録番号
		v_item.l_inItem032 := gBunpaiKngkLabel;	-- 適格請求書_分配額合計ラベル
		v_item.l_inItem033 := gTesuSzeiLabel;	-- 適格請求書_内消費税ラベル
		v_item.l_inItem034 := gInvoiceTesuKngkSum;	-- 適格請求書_分配額合計
		v_item.l_inItem035 := gTsukaNm;	-- 通貨コード
		v_item.l_inItem036 := gInvoiceTesuSzei;	-- 適格請求書_内消費税
		v_item.l_inItem037 := gTsukaNm;	-- 通貨コード
		v_item.l_inItem038 := gInvoiceFlg;	-- インボイスオプションフラグ
		v_item.l_inItem039 := gBunsho;	-- インボイス文章
		v_item.l_inItem040 := gAtenaName1;	-- 宛名用名称１
		v_item.l_inItem041 := gAtenaName2;	-- 宛名用名称２
		v_item.l_inItem042 := gAtenaName3;	-- 宛名用名称３
		v_item.l_inItem043 := gShohiZeiRate;	-- 適格請求書_消費税率
		v_item.l_inItem044 := recPrevMeisai.gDistriYmd;	-- 交換日
		
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
			END IF;
			-- キーと現在のレコード退避
			key.gBankCd		:= recMeisai.gBankCd;
			key.gDistriYmd	:= recMeisai.gDistriYmd;
			key.gTsukaCd	:= recMeisai.gTsukaCd;
			recPrevMeisai	:= recMeisai;
			-- 合計クリア
			gokei.gBunpaiKngk := 0;
			gokei.gUchiSzei := 0;
			 -- インボイスオプションフラグが"1"の場合
			IF gInvoiceFlg = INVOICE_OPTION_FLG THEN
				gSeqNoSta  := gSeqNo + 1;	-- 合計更新時の最初の連番
				-- 適格請求書_通貨コード名称
				gTsukaNm := recMeisai.gTsukaNm;
				-- 適格請求書_分配額合計
				gInvoiceTesuKngkSum := gokei.gBunpaiKngk;
				-- 消費税率取得の徴求日
				-- 消費税率適用基準日切り替え
				IF gShzKijunProcess = '1' THEN
					gInvoiceShzKijunYmd := recMeisai.gHakkoYmd;
				ELSE
					gInvoiceShzKijunYmd := recMeisai.gChokyuYmd;
				END IF;
				-- レコード.消費税請求区分　が「0」の場合
				IF recMeisai.gSzeiSeikyuKbn = '0' THEN
					-- 適格請求書_消費税率
					gShohiZeiRate := NULL;
					-- 分配額ラベル
					gBunpaiKngkLabel := gInvoiceTaxKbnNm;
				-- ローカル変数．前レコード．消費税請求区分　が「1」の場合
				ELSIF recMeisai.gSzeiSeikyuKbn = '1' THEN
					-- 適格請求書_消費税率
					gShohiZeiRate := pkIpaZei.getShohiZeiRate(gInvoiceShzKijunYmd);
					-- 分配額ラベル
					gBunpaiKngkLabel := pkCharacter.TO_ZENKANA(gShohiZeiRate) || '％対象';
				END IF;
			END IF;
		END IF;
		-- 分配額、消費税の合計
		gokei.gBunpaiKngk := gokei.gBunpaiKngk + recMeisai.gBunpaiKngk;
		gokei.gUchiSzei := gokei.gUchiSzei + recMeisai.gUchiSzei;
		-- 税込税抜きフォーマット
		IF recMeisai.gTesuryoKomiFlg = '1' THEN
			gFmtZei := FMT_ZEI_KOMI;
		ELSE
			gFmtZei := FMT_ZEI_NUKI;
		END IF;
		-- 書式フォーマットの設定
		-- 発行
		IF recMeisai.gTsukaCd = 'JPY' THEN
			gFmtHakkoKngk := FMT_HAKKO_KNGK_J;
			gFmtRbrKngk := FMT_RBR_KNGK_J;
			gFmtShokanKngk := FMT_SHOKAN_KNGK_J;
		ELSE
			gFmtHakkoKngk := FMT_HAKKO_KNGK_F;
			gFmtRbrKngk := FMT_RBR_KNGK_F;
			gFmtShokanKngk := FMT_SHOKAN_KNGK_F;
		END IF;
		-- 宛名編集
		CALL pkIpaName.getMadoFutoAtena(recMeisai.gSfskBankNm, recMeisai.gSfskBushoNm, gOutflg, gAtena);
		-- 宛名編集（csvJournal）
		CALL pkIpaName.getMadoFutoAtena_Journal(recMeisai.gSfskBankNm, recMeisai.gSfskBushoNm, gOutflg, gAtenaName1, gAtenaName2, gAtenaName3);
		-- 消費税率適用基準日切り替え
		IF gShzKijunProcess = '1' THEN
			gShzKijunYmd := recMeisai.gHakkoYmd;
		ELSE
			gShzKijunYmd := recMeisai.gChokyuYmd;
		END IF;
		-- 手数料率分子の取得
		recMeisai.gTesuRitsuBunshi :=
			pkTesuryoRitsu.getTesuryoRitsuBunshi(l_inItakuKaishaCd, recMeisai.gTesuRitsuBunshi, gShzKijunYmd, recMeisai.gMgrCd, gOutflg);
		-- 持出日計算
		gWrkMotidashiYmd := NULL;
		-- 分配日と持出タイミングが両方入っている場合に計算する（分配日−持出タイミング日数営業日前）
		IF (trim(both recMeisai.gDistriYmd) IS NOT NULL AND (trim(both recMeisai.gDistriYmd))::text <> '') AND
			(trim(both recMeisai.gMochidashiTmg) IS NOT NULL AND (trim(both recMeisai.gMochidashiTmg))::text <> '') THEN
			gWrkMotidashiYmd := PKDATE.getMinusDateBusiness(recMeisai.gDistriYmd,recMeisai.gMochidashiTmg);
		END IF;
		-- 交換メッセージのセット
		IF (gWrkMotidashiYmd IS NOT NULL AND gWrkMotidashiYmd::text <> '') THEN
			gKoukanMsg := 'の' || recMeisai.gKoukanjoNm || KOUKAN_MSG1 || substr(PKDATE.seirekiChangeSuppressNenGappi(gWrkMotidashiYmd),7) || KOUKAN_MSG2;
		ELSE
			gKoukanMsg := 'の' || recMeisai.gKoukanjoNm || KOUKAN_MSG1 || '　  　  ' || KOUKAN_MSG2;
		END IF;
		-- 分配予定通知書文書取得
		SELECT * FROM spIp03504_01_getBunpaiBun(recMeisai.gDistriYmd, '00') INTO STRICT gBunBunpaiBun1, gBunBunpaiBun2;
		gSeqNo := gSeqNo + 1;
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gWrkTsuchiYmd;	-- 通知日
		v_item.l_inItem002 := recMeisai.gPostNo;	-- 郵便番号
		v_item.l_inItem003 := recMeisai.gAdd1;	-- 住所１
		v_item.l_inItem004 := recMeisai.gAdd2;	-- 住所２
		v_item.l_inItem005 := recMeisai.gAdd3;	-- 住所３
		v_item.l_inItem006 := gAtena;	-- 送付先金融機関名称
		v_item.l_inItem007 := recMeisai.gSfmtBankNm;	-- 送付元金融機関名称
		v_item.l_inItem008 := recMeisai.gSfmtBushoNm;	-- 送付元担当部署名称
		v_item.l_inItem009 := recMeisai.gDistriYmd;	-- 分配日
		v_item.l_inItem010 := gKoukanMsg;	-- 交換メッセージ（持出日込み）
		v_item.l_inItem011 := recMeisai.gTsukaNm;	-- 通貨コード名称
		v_item.l_inItem012 := recMeisai.gIsinCd;	-- ＩＳＩＮコード
		v_item.l_inItem013 := recMeisai.gMgrRnm;	-- 銘柄略称
		v_item.l_inItem014 := recMeisai.gShasaiTotal;	-- 社債の総額
		v_item.l_inItem015 := recMeisai.gTesuRitsuBunshi;	-- 手数料率分子
		v_item.l_inItem016 := recMeisai.gTesuRitsuBunbo;	-- 手数料率分母
		v_item.l_inItem017 := recMeisai.gDfBunshi;	-- 分配率分子
		v_item.l_inItem018 := recMeisai.gDfBunbo;	-- 分配率分母
		v_item.l_inItem019 := recMeisai.gBunpaiKngk;	-- 分配額
		v_item.l_inItem020 := recMeisai.gUchiSzei;	-- 内消費税
		v_item.l_inItem021 := gFmtHakkoKngk;	-- 発行金額書式フォーマット
		v_item.l_inItem022 := gFmtRbrKngk;	-- 利払金額書式フォーマット
		v_item.l_inItem023 := gFmtShokanKngk;	-- 償還金額書式フォーマット
		v_item.l_inItem025 := gFmtZei;	-- 税込税抜きフォーマット
		v_item.l_inItem028 := recMeisai.gBankCd;	-- 金融機関コード
		v_item.l_inItem029 := gBunBunpaiBun1;	-- 分配予定通知書文書１
		v_item.l_inItem030 := gBunBunpaiBun2;	-- 分配予定通知書文書２
		v_item.l_inItem031 := gInvoiceTourokuNo;	-- 適格請求書発行事業者登録番号
		v_item.l_inItem032 := gBunpaiKngkLabel;	-- 適格請求書_分配額合計ラベル
		v_item.l_inItem033 := gTesuSzeiLabel;	-- 適格請求書_内消費税ラベル
		v_item.l_inItem034 := gInvoiceTesuKngkSum;	-- 適格請求書_分配額合計
		v_item.l_inItem035 := gTsukaNm;	-- 通貨コード
		v_item.l_inItem036 := gInvoiceTesuSzei;	-- 適格請求書_内消費税
		v_item.l_inItem037 := gTsukaNm;	-- 通貨コード
		v_item.l_inItem038 := gInvoiceFlg;	-- インボイスオプションフラグ
		v_item.l_inItem039 := gBunsho;	-- インボイス文章
		v_item.l_inItem040 := gAtenaName1;	-- 宛名用名称１
		v_item.l_inItem041 := gAtenaName2;	-- 宛名用名称２
		v_item.l_inItem042 := gAtenaName3;	-- 宛名用名称３
		v_item.l_inItem043 := gShohiZeiRate;	-- 適格請求書_消費税率
		v_item.l_inItem044 := recMeisai.gDistriYmd;	-- 交換日
		
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
	IF gSeqNo = gSeqNoIni THEN
		-- 対象データなし
		-- 帳票ワークへデータを追加(請求書)
		l_outSqlCode := PKIPACALCTESURYO.setNoDataPrint(l_inItakuKaishaCd,
														l_inUserId,
														l_inGyomuYmd,
														REPORT_ID,
														l_inChohyoKbn,
														24,
														gWrkTsuchiYmd,
														1,
                                                        gInvoiceFlg,        -- セットするアイテムその２
                                                        38,                 -- セットするアイテムその２のItem番号
                                                        gBunsho,            -- セットするアイテムその３
                                                        39,                 -- セットするアイテムその３のItem番号
														'',
														0,
														'',
														0
														);
	ELSE
	-- データが存在する場合、合計行出力
		gSeqNo := gSeqNo + 1;
		-- 持出日計算
		gWrkMotidashiYmd := NULL;
		-- 分配日と持出タイミングが両方入っている場合に計算する（分配日−持出タイミング日数営業日前）
		IF (trim(both recPrevMeisai.gDistriYmd) IS NOT NULL AND (trim(both recPrevMeisai.gDistriYmd))::text <> '') AND
			(trim(both recPrevMeisai.gMochidashiTmg) IS NOT NULL AND (trim(both recPrevMeisai.gMochidashiTmg))::text <> '') THEN
			gWrkMotidashiYmd := PKDATE.getMinusDateBusiness(recPrevMeisai.gDistriYmd,recPrevMeisai.gMochidashiTmg);
		END IF;
		-- 交換メッセージのセット
		IF (gWrkMotidashiYmd IS NOT NULL AND gWrkMotidashiYmd::text <> '') THEN
			gKoukanMsg := 'の' || recPrevMeisai.gKoukanjoNm || KOUKAN_MSG1 || substr(PKDATE.seirekiChangeSuppressNenGappi(gWrkMotidashiYmd),7) || KOUKAN_MSG2;
		ELSE
			gKoukanMsg := 'の' || recPrevMeisai.gKoukanjoNm || KOUKAN_MSG1 || '　  　  ' || KOUKAN_MSG2;
		END IF;
		-- 分配予定通知書文書取得
		SELECT * FROM spIp03504_01_getBunpaiBun(recPrevMeisai.gDistriYmd, '00') INTO STRICT gBunBunpaiBun1, gBunBunpaiBun2;
		-- インボイスオプションフラグが"1"の場合
		IF gInvoiceFlg = INVOICE_OPTION_FLG THEN
			-- 適格請求書_分配額合計
			gInvoiceTesuKngkSum := gokei.gBunpaiKngk;
			-- ローカル変数．前レコード．消費税請求区分　が「0」の場合
			IF recPrevMeisai.gSzeiSeikyuKbn = '0' THEN
			    -- 適格請求書_内消費税
			    gInvoiceTesuSzei := 0;
			-- ローカル変数．前レコード．消費税請求区分　が「1」の場合
			ELSIF recPrevMeisai.gSzeiSeikyuKbn = '1' THEN
			    -- 適格請求書_内消費税　手数料消費税額計算（割戻用）を行う
			    gInvoiceTesuSzei := PKIPACALCTESUKNGK.getTesuZeiWarimodoshi(gInvoiceShzKijunYmd, gInvoiceTesuKngkSum, recPrevMeisai.gHakkoTsukaCd);
			END IF;
			-- 合計更新処理
			UPDATE SREPORT_WK SET
				ITEM034 = gInvoiceTesuKngkSum,
				ITEM036 = gInvoiceTesuSzei
			WHERE KEY_CD = l_inItakuKaishaCd
			AND USER_ID = l_inUserId
			AND CHOHYO_KBN = l_inChohyoKbn
			AND SAKUSEI_YMD = l_inGyomuYmd
			AND CHOHYO_ID = REPORT_ID
			AND (SEQ_NO >= gSeqNoSta AND SEQ_NO < gSeqNo);
		END IF;
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gWrkTsuchiYmd;	-- 通知日
		v_item.l_inItem002 := recPrevMeisai.gPostNo;	-- 郵便番号
		v_item.l_inItem003 := recPrevMeisai.gAdd1;	-- 住所１
		v_item.l_inItem004 := recPrevMeisai.gAdd2;	-- 住所２
		v_item.l_inItem005 := recPrevMeisai.gAdd3;	-- 住所３
		v_item.l_inItem006 := gAtena;	-- 送付先金融機関名称
		v_item.l_inItem007 := recPrevMeisai.gSfmtBankNm;	-- 送付元金融機関名称
		v_item.l_inItem008 := recPrevMeisai.gSfmtBushoNm;	-- 送付元担当部署名称
		v_item.l_inItem009 := recPrevMeisai.gDistriYmd;	-- 分配日
		v_item.l_inItem010 := gKoukanMsg;	-- 交換メッセージ（持出日込み）
		v_item.l_inItem011 := recPrevMeisai.gTsukaNm;	-- 通貨コード名称
		v_item.l_inItem021 := gFmtHakkoKngk;	-- 発行金額書式フォーマット
		v_item.l_inItem022 := gFmtRbrKngk;	-- 利払金額書式フォーマット
		v_item.l_inItem023 := gFmtShokanKngk;	-- 償還金額書式フォーマット
		v_item.l_inItem025 := gFmtZei;	-- 税込税抜きフォーマット
		v_item.l_inItem026 := gokei.gBunpaiKngk;	-- 分配額
		v_item.l_inItem027 := gokei.gUchiSzei;	-- 内消費税
		v_item.l_inItem028 := recPrevMeisai.gBankCd;	-- 金融機関コード
		v_item.l_inItem029 := gBunBunpaiBun1;	-- 分配予定通知書文書１
		v_item.l_inItem030 := gBunBunpaiBun2;	-- 分配予定通知書文書２
		v_item.l_inItem031 := gInvoiceTourokuNo;	-- 適格請求書発行事業者登録番号
		v_item.l_inItem032 := gBunpaiKngkLabel;	-- 適格請求書_分配額合計ラベル
		v_item.l_inItem033 := gTesuSzeiLabel;	-- 適格請求書_内消費税ラベル
		v_item.l_inItem034 := gInvoiceTesuKngkSum;	-- 適格請求書_分配額合計
		v_item.l_inItem035 := gTsukaNm;	-- 通貨コード
		v_item.l_inItem036 := gInvoiceTesuSzei;	-- 適格請求書_内消費税
		v_item.l_inItem037 := gTsukaNm;	-- 通貨コード
		v_item.l_inItem038 := gInvoiceFlg;	-- インボイスオプションフラグ
		v_item.l_inItem039 := gBunsho;	-- インボイス文章
		v_item.l_inItem040 := gAtenaName1;	-- 宛名用名称１
		v_item.l_inItem041 := gAtenaName2;	-- 宛名用名称２
		v_item.l_inItem042 := gAtenaName3;	-- 宛名用名称３
		v_item.l_inItem043 := gShohiZeiRate;	-- 適格請求書_消費税率
		v_item.l_inItem044 := recPrevMeisai.gDistriYmd;	-- 交換日
		
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
		-- インボイスオプションフラグが"1"の場合
		IF gInvoiceFlg = INVOICE_OPTION_FLG THEN
			-- CSVジャーナル登録
			l_outSqlCode := pkCsvJournal.insertData(l_inItakuKaishaCd,l_inUserId,l_inChohyoKbn,l_inGyomuYmd,REPORT_ID);
		END IF;
	END IF;
	CLOSE curMeisai;
	-- 終了処理
	l_outSqlCode := RTN_OK;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp03504_01 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		IF curMeisai%ISOPEN THEN
			CLOSE curMeisai;
		END IF;
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip03504_01 ( l_inKijunYmdF TEXT, l_inKijunYmdT TEXT, l_inHktCd TEXT, l_inKozaTenCd TEXT, l_inKozaTenCifCd TEXT, l_inMgrCd TEXT, l_inIsinCd TEXT, l_inTsuchiYmd TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT integer, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spip03504_01_createbun (l_in_ReportID TEXT, l_in_PatternCd TEXT) RETURNS PKIPABUN.BUN_ARRAY AS $body$
DECLARE

-- 分配予定通知書文章(ワーク)
	aryBun    pkIpaBun.BUN_ARRAY;
	patternCd BUN.BUN_PATTERN_CD%TYPE;

BEGIN
-- 文章パターンコードの設定
	patternCd := SUBSTR(l_in_PatternCd, 1, 1) || '0';
-- 分配予定通知書文章の取得
	aryBun := pkIpaBun.getBun(l_in_ReportID, patternCd);
	RETURN aryBun;
EXCEPTION
	WHEN OTHERS THEN
	RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spip03504_01_createbun (l_in_ReportID TEXT, l_in_PatternCd TEXT) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spip03504_01_getbunpaibun (l_inDistry_YMD TEXT, l_inPattern_Cd TEXT, l_outBunBunpai1 OUT TEXT, l_outBunBunpai2 OUT TEXT, OUT extra_param char) RETURNS record AS $body$
DECLARE

	wAryBun pkIpaBun.BUN_ARRAY;
	wRtnCd integer := 1;
BEGIN
	-- 分配予定通知書取得(分配予定通知書)
	wAryBun        := spIp03504_01_createBun(REPORT_ID, l_inPattern_Cd);
	l_outBunBunpai1 := NULL;
	l_outBunBunpai2 := NULL;
	FOR i IN 0 .. coalesce(cardinality(wAryBun), 0) - 1 LOOP
		IF i = 0 THEN
			l_outBunBunpai1 := wAryBun[i];
			wAryBun[i] := NULL;
		ELSE
			IF (trim(both l_inDistry_YMD) IS NOT NULL AND (trim(both l_inDistry_YMD))::text <> '') THEN
				l_outBunBunpai2 := substr(PKDATE.seirekiChangeSuppressNenGappi(l_inDistry_YMD),7) || wAryBun[i];
			ELSE
				l_outBunBunpai2 := '　  　  ' || wAryBun[i];
			END IF;
			wAryBun[i] := NULL;
		END IF;
		wRtnCd := 0;
	END LOOP;
	extra_param := wRtnCd;
	RETURN;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spip03504_01_getbunpaibun (l_inDistry_YMD TEXT, l_inPattern_Cd TEXT, l_outBunBunpai1 OUT TEXT, l_outBunBunpai2 OUT TEXT, OUT extra_param char) FROM PUBLIC;