


DROP TYPE IF EXISTS type_record CASCADE;
CREATE TYPE type_record AS (
		gHktCd                 varchar  -- 発行体コード
		,
		gSfskPostNo            varchar  -- 送付先郵便番号
		,
		gAdd1                  varchar  -- 送付先住所１
		,
		gAdd2                  varchar  -- 送付先住所２
		,
		gAdd3                  varchar  -- 送付先住所３
		,
		gHktNm                 varchar  -- 発行体名称
		,
		gHktRnm                varchar  -- 発行体略称
		,
		gSfskBushoNm           varchar  -- 送付先担当部署名称
		,
		gBankNm                varchar  -- 銀行名称
		,
		gBushoNm1              varchar  -- 担当部署名称１
		,
		gIsinCd                varchar  -- ISINコード
		,
		gMgrRnm                varchar  -- 銘柄略称
		,
		gMgrNm                 varchar  -- 銘柄の正式名称
		,
		gGanriKbn              varchar(10) -- 元利区分
		,
		gShrYmd                char  -- 支払日
		,
		gShokanSeikyuKngk      numeric  -- 元金支払額
		,
		gShokanTsukaCd         char  -- 償還通貨コード
		,
		gGankinTsukaNm         varchar  -- 元金支払額通貨
		,
		gGzeihikiBefChokyuKngk numeric  -- 利金支払額
		,
		gRbrTsukaCd            char  -- 利払通貨コード
		,
		gRikinTsukaNm          varchar  -- 利金支払額通貨
		,
		gGzeiKngk              numeric  -- 税金額
		,
		gZeikinTsukaNm         varchar  -- 税金額通貨
		,
		gGzeihikiAftChokyuKngk numeric  -- 利金支払基金請求額
		,
		gSeikyuTsukaNm         varchar  -- 利金支払基金請求額通貨
		,
		gGnknShrTesuBunshi     numeric  -- 元金手数料率分子
		,
		gGnknShrTesuBunbo      numeric  -- 元金手数料率分母
		,
		gGnknShukinKngk        numeric  -- 元金手数料
		,
		gRknShrTesuBunshi      numeric  -- 利金手数料率分子
		,
		gRknShrTesuBunbo       numeric  -- 利金手数料率分母
		,
		gRknShukinKngk         numeric  -- 利金手数料
		,
		gTesuryoKomiFlg        char  -- 手数料税込フラグ
		,
		gMgrCd                 varchar  -- 銘柄コード
		,
		gTaxKbn				   char  -- 課税区分
		,
		gEigyotenCd			   char  -- 営業店コード
		,
		gEigyotenNm			   varchar  -- 営業店名称
		,
		gRikinHasu			   numeric  -- 利金端数
		,
		gKozaTenCd             char  -- 口座店コード
		,
		gKozaTenCifcd          char  -- 口座店ＣＩＦコード
		,
		gJtkKbn                char  -- 受託区分
		,
		gJtkKbnNm              varchar  -- 受託区分名称
		,
		gHakkoYmd              char  -- 発行年月日
		,
		gFullshokanKjt         char  -- 満期償還期日
		,
		gKkKanyoFlg            char  -- 機構関与方式採用フラグ
		,
		gKkKanyoFlgRnm         varchar  -- 機構関与方式採用フラグ略称
		,
		gGnrZndk               numeric  -- 元利払対象残高
		,
		gGnrJisshitsuZndk      numeric  -- 元利払対象実質残高
	);


CREATE OR REPLACE PROCEDURE spipx022k02r01 ( l_inChohyoId TEXT, -- 帳票ID
 l_inItakuKaishaCd TEXT, -- 委託会社コード
 l_inUserId TEXT, -- ユーザーID
 l_inChohyoKbn TEXT, -- 帳票区分
 l_inGyomuYmd TEXT, -- 業務日付
 l_inHktCd TEXT, -- 発行体コード
 l_inKozaTenCd TEXT, -- 口座店コード
 l_inKozaTenCifCd TEXT, -- 口座店CIFコード
 l_inMgrCd TEXT, -- 銘柄コード
 l_inIsinCd TEXT, -- ISINコード
 l_inKijunYm TEXT, -- 基準年月
 l_inKijunYmdFrom TEXT, -- 基準日From
 l_inKijunYmdTo TEXT, -- 基準日To
 l_inTsuchiYmd TEXT, -- 通知日
 l_outSqlCode OUT integer  -- リターン値
 ) AS $body$
DECLARE

	--
--	 * 著作権:Copyright(c)2019
--	 * 会社名:JIP
--	 * 概要　:画面から、元利金支払情報データを作成する
--	 *      元利金支払報告書作成（SPIPI047K00R01）と同期をとってください！
--	 *    
--	 *    
--	 * 引数　:l_inChohyoId    	  IN  TEXT      帳票ID
--	 * 		 l_inItakuKaishaCd    IN  TEXT      委託会社コード
--	 *       l_inUserId           IN  TEXT      ユーザーID
--	 *       l_inChohyoKbn        IN  TEXT      帳票区分
--	 *       l_inGyomuYmd         IN  TEXT      業務日付
--	 *       l_inHktCd            IN  TEXT      発行体コード
--	 *       l_inKozaTenCd        IN  TEXT      口座店コード
--	 *       l_inKozaTenCifCd     IN  TEXT      口座店CIFコード
--	 *       l_inMgrCd            IN  TEXT      銘柄コード
--	 *       l_inIsin             IN  TEXT      ISINコード
--	 *       l_inKijunYm          IN  TEXT      基準年月
--	 *       l_inKijunYmdFrom	  IN  TEXT		基準日From
--	 *		 l_inKijunYmdTo		  IN  TEXT		基準日To
--	 *       l_inTsuchiYmd        IN  TEXT      通知日
--	 *       l_outSqlCode         OUT INTEGER   リターン値
--	 * 返り値:なし
--	 * @version $Id: SPIPX022K02R01.sql,v 1.8.2.2 2025/07/30 01:48:14 taira Exp $
--     
	--==============================================================================
	--                デバッグ機能                                                   
	--==============================================================================
	--==============================================================================
	--                定数定義                                                      
	--==============================================================================
	RTN_OK     CONSTANT integer := 0; -- 正常
	RTN_NG     CONSTANT integer := 1; -- 予期したエラー
	RTN_NODATA CONSTANT integer := 2; -- データなし
	RTN_FATAL  CONSTANT integer := 99; -- 予期せぬエラー
	REPORT_ID      CONSTANT text := 'IP030004711'; -- 元利金支払報告書帳票ID
	--==============================================================================
	--                変数定義                                                      
	--==============================================================================
	gRtnCd integer := RTN_OK; -- リターンコード
	gSeqNo integer := 0; -- シーケンス
	gNo    integer := 0; -- NO
	gSQL   varchar(10000) := NULL; -- SQL編集
	-- 書式フォーマット
	gGyomuYm           char(6) := NULL; -- 業務年月(リアルと夜間で変わる)
	gKijunYm		   char(6) := NULL; -- (IP-05244)
	gOutflg            numeric := 0; -- 正常処理フラグ
	gBunsho            varchar(200) := NULL; -- 請求文章
	gGnknShrGoukei     decimal(16,2) := 0; -- 元金支払額合計
	gRknShrGoukei      decimal(16,2) := 0; -- 利金支払額合計
	gGnknShrTesuBunshi decimal(10,7) := 0; -- 元金支払手数料率_分子
	gRknShrTesuBunshi  decimal(10,7) := 0; -- 利金支払手数料率_分子
	gRknTesuTsuka      char(3)		 := '円 ';	-- 利金手数料通貨コード
	gKokuZeiRateFm		varchar(21) := NULL;					-- 国税率
	gGZeiKngkFm			varchar(21) := NULL;					-- 国税額
	gGzeihikiAftChokyuKngkFm	varchar(21) := NULL;					-- 税引後利金額
	--税区分取得用変数
	gRbrKjt            KIKIN_SEIKYU.SHR_YMD%TYPE;
	gRet			   numeric := 0;
	gTaxNm             MTAX.TAX_NM%TYPE := NULL;			--税区分名称
	gTaxRnm            MTAX.TAX_RNM%TYPE := NULL;		--税区分略称
	gKokuZeiRate       MTAX.KOKU_ZEI_RATE%TYPE := NULL;	--国税率
	gChihoZeiRate      MTAX.CHIHO_ZEI_RATE%TYPE := NULL;	--地方税率
	--  グロスアップ用ワーク変数
	GRS_OPTION_CD  				CONSTANT MOPTION_KANRI.OPTION_CD%TYPE := 'IPX1011112010'; 		--オプションID
	GRS_FMT 					CONSTANT text := 'FM99999999990.0000000000000'; 	--グロスアップ国税率用フォーマット
	TAX_FMT						CONSTANT text := 'FM90.00000';				--通常税率フォーマット
	GRS_CNT_MAX					CONSTANT integer := 5; -- グロスアップ銘柄税率設定最大値
	grsRangaiChuki              varchar(200) := NULL;	-- 欄外注記の文言
	grsKokuZeiRate				decimal(15,13)  := 0;					-- 国税率			
	grsVKokuZeiRate   			varchar(10) := NULL; 					-- 表示用国税率
	grsStrKokuZeiRate   		varchar(16) := NULL; 					-- 文字列国税率
	grsRangaiKokuZeiRateList	varchar(164) := NULL;					-- 欄外表示の国税率リスト		
	grsVRangaiKokuZeiRateList	varchar(164) := NULL;					-- 欄外表示の国税率リスト		
	grsGrossSeqNo 				integer := 0;							-- シーケンス			
	grsAst 						char(4) := NULL;						-- ※			
	grsShrYmd					KIKIN_SEIKYU.SHR_YMD%TYPE := NULL;					-- 適用利払期日
	grsTekiyoRbr				MGR_RBRKIJ.RBR_KJT%TYPE := NULL;					-- 適用利払期日
	grsPrTekiyoRbr				MGR_RBRKIJ.RBR_KJT%TYPE := NULL;					-- 前適用利払期日
	
	-- ブレイクキー
	keyHktCd  MHAKKOTAI.HKT_CD%TYPE := ''; -- 発行体コード
	keyIsinCd MGR_KIHON_VIEW.ISIN_CD%TYPE := ''; -- ISINコード
	-- DB取得項目
	-- 配列定義
	recMeisai TYPE_RECORD; -- レコード
	gChohyoSortFlg		MPROCESS_CTL.CTL_VALUE%TYPE;				-- 発行体宛帳票ソート順変更フラグ
	gRikinHasuFlg		MPROCESS_CTL.CTL_VALUE%TYPE;				-- その他基金出金 利金端数計算フラグ取得
	gTesuryoHasuFlg		MPROCESS_CTL.CTL_VALUE%TYPE;				-- その他基金出金 手数料端数計算フラグ取得
	gHasuRangaiChuki   	varchar(100) := NULL;					-- 欄外注記の文言	
	gShzKijunProcess	MPROCESS_CTL.CTL_VALUE%TYPE;				-- 消費税率適用基準日対応
	gShzKijunYmd		varchar(8);								-- 消費税率適用基準日
	gInvoiceFlg		MOPTION_KANRI.OPTION_FLG%TYPE;				-- オプションフラグ取得
	gGnrshr0outFlg		MPROCESS_CTL.CTL_VALUE%TYPE;				-- 元利金支払報告書作成制御フラグ
	-- カーソル
	
	curMeisai REFCURSOR;
--==============================================================================
--                メイン処理                                                       
--==============================================================================
BEGIN
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inChohyoId)::text, '') = '' OR coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' OR coalesce(trim(both l_inUserId)::text, '') = '' OR
		coalesce(trim(both l_inChohyoKbn)::text, '') = '' OR coalesce(trim(both l_inGyomuYmd)::text, '') = '' THEN
			-- パラメータエラー
			l_outSqlCode := RTN_NG;
			CALL pkLog.error('ECM501', l_inChohyoId, 'SQLERRM:' || '');
			RETURN;
	END IF;
    IF (coalesce(trim(both l_inKijunYm)::text, '') = '') AND (coalesce(trim(both l_inKijunYmdFrom)::text, '') = '' OR coalesce(trim(both l_inKijunYmdTo)::text, '') = '') THEN
        	-- パラメータエラー
			l_outSqlCode := RTN_NG;
			CALL pkLog.error('ECM501', l_inChohyoId, 'SQLERRM:' || '');
			RETURN;
    END IF;
	-- 帳票区分による初期設定
	-- 業務年月
	gGyomuYm := l_inKijunYm;
	-- ⑥基準日の年月、⑦基準年月の年月どちらかが来るのでセット
	gKijunYm := trim(both l_inKijunYm);
	IF (trim(both l_inKijunYmdFrom) IS NOT NULL AND (trim(both l_inKijunYmdFrom))::text <> '') THEN
		gKijunYm := substr(l_inKijunYmdFrom, 1, 6);
	END IF;
	-- 請求文章取得
	gBunsho := SPIPX022K02R01_createBun(REPORT_ID, '00');
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK_SSKM
		WHERE KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = l_inGyomuYmd
		AND CHOHYO_ID = l_inChohyoId;
	--発行体宛帳票ソート順変更フラグ取得
	gChohyoSortFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'SeikyusyoSort', '0');
	--その他基金出金 利金端数計算フラグ取得
	gRikinHasuFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'SPIPI047K00R012', '0');
	--その他基金出金 手数料端数計算フラグ取得
	gTesuryoHasuFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'SPIPI047K00R013', '0');
	--端数欄外注記の設定
	IF gRikinHasuFlg <> '0' OR gTesuryoHasuFlg <> '0' THEN
		gHasuRangaiChuki := '※分配処理において端数金額が発生した場合は、当該金額が含まれております。';
	ELSE
		gHasuRangaiChuki := '';
	END IF;
	-- 消費税率適用基準日フラグ(1:取引日ベース, 0:徴求日ベース(デフォルト))取得
	gShzKijunProcess := pkControl.getCtlValue(l_inItakuKaishaCd, 'ShzKijun', '0');
	-- 元利金支払報告書作成制御フラグ取得
	gGnrshr0outFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'Gnrshr0out', '0');
	-- オプションフラグ取得
	gInvoiceFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd, 'INVOICE_A', '0');
	--みずほリリース対象外対応
	gInvoiceFlg := '0';
	-- SQL編集
	CALL SPIPX022K02R01_createSQL(
		l_inItakuKaishaCd,
		l_inKijunYmdFrom,
		l_inKijunYmdTo,
		l_inHktCd,
		l_inKozaTenCd,
		l_inKozaTenCifCd,
		l_inMgrCd,
		l_inIsinCd,
		gGyomuYm,
		gChohyoSortFlg,
		gRikinHasuFlg,
		gTesuryoHasuFlg,
		gGnrshr0outFlg,
		gSQL
	);
	-- カーソルオープン
	OPEN curMeisai FOR EXECUTE gSQL;
	-- データ取得
	LOOP
		FETCH curMeisai
			INTO recMeisai.gHktCd,				-- 発行体コード
			recMeisai.gSfskPostNo,				-- 送付先郵便番号
			recMeisai.gAdd1,					-- 送付先住所１
			recMeisai.gAdd2,					-- 送付先住所２
			recMeisai.gAdd3,					-- 送付先住所３
			recMeisai.gHktNm,					-- 発行体名称
			recMeisai.gHktRnm,					-- 発行体略称
			recMeisai.gSfskBushoNm,				-- 送付先担当部署名称
			recMeisai.gBankNm,					-- 銀行名称
			recMeisai.gBushoNm1,				-- 担当部署名称１
			recMeisai.gIsinCd,					-- ISINコード
			recMeisai.gMgrRnm,					-- 銘柄略称
			recMeisai.gMgrNm,					-- 銘柄の正式名称
			recMeisai.gGanriKbn,				-- 元利区分
			recMeisai.gShrYmd,					-- 支払日
			recMeisai.gShokanSeikyuKngk,		-- 元金支払額
			recMeisai.gShokanTsukaCd,			-- 償還通貨コード
			recMeisai.gGankinTsukaNm,			-- 元金支払額通貨
			recMeisai.gGzeihikiBefChokyuKngk,	-- 利金支払額
			recMeisai.gRbrTsukaCd,				-- 利払通貨コード
			recMeisai.gRikinTsukaNm,			-- 利金支払額通貨
			recMeisai.gGzeiKngk,				-- 税金額
			recMeisai.gZeikinTsukaNm,			-- 税金額通貨
			recMeisai.gGzeihikiAftChokyuKngk,	-- 利金支払基金請求額
			recMeisai.gSeikyuTsukaNm,			-- 利金支払基金請求額通貨
			recMeisai.gGnknShrTesuBunshi,		-- 元金手数料率分子
			recMeisai.gGnknShrTesuBunbo,		-- 元金手数料率分母
			recMeisai.gGnknShukinKngk,			-- 元金手数料
			recMeisai.gRknShrTesuBunshi,		-- 利金手数料率分子
			recMeisai.gRknShrTesuBunbo,			-- 利金手数料率分母
			recMeisai.gRknShukinKngk,			-- 利金手数料
			recMeisai.gTesuryoKomiFlg,			-- 手数料税込フラグ
			recMeisai.gMgrCd,					-- 銘柄コード
			recMeisai.gTaxKbn,					-- 課税区分
			recMeisai.gEigyotenCd,				-- 営業店コード
			recMeisai.gEigyotenNm,				-- 営業店名称
			recMeisai.gRikinHasu,				-- 利金端数
			recMeisai.gKozaTenCd,				-- 口座店コード
			recMeisai.gKozaTenCifcd,			-- 口座店ＣＩＦコード
			recMeisai.gJtkKbn,					-- 受託区分
			recMeisai.gJtkKbnNm,				-- 受託区分名称
			recMeisai.gHakkoYmd,				-- 発行年月日
			recMeisai.gFullshokanKjt,			-- 満期償還期日
			recMeisai.gKkKanyoFlg,				-- 機構関与方式採用フラグ
			recMeisai.gKkKanyoFlgRnm,			-- 機構関与方式採用フラグ略称
			recMeisai.gGnrZndk,					-- 元利払対象残高
			recMeisai.gGnrJisshitsuZndk 			-- 元利払対象実質残高
			;
	-- データが無くなったらループを抜ける
	EXIT WHEN NOT FOUND;/* apply on curMeisai */
	-- 手数料率分子の取得(元金支払手数料率_分子、利金支払手数料率_分子)
	gGnknShrTesuBunshi := 0;
	IF (recMeisai.gGnknShrTesuBunshi IS NOT NULL AND recMeisai.gGnknShrTesuBunshi::text <> '') THEN
		-- 消費税率適用基準日切り替え
		IF gShzKijunProcess = '1' THEN
			gShzKijunYmd := recMeisai.gShrYmd;
		ELSE
			-- 基金異動履歴から元金支払手数料徴求日を取得する
			gShzKijunYmd := PKIPACALCTESURYO.getTesuChokyuYmd(l_inItakuKaishaCd, recMeisai.gMgrCd, recMeisai.gShrYmd, '12');
		END IF;
		gGnknShrTesuBunshi := pkTesuryoRitsu.getTesuryoRitsuBunshi(	l_inItakuKaishaCd,
																	recMeisai.gGnknShrTesuBunshi,
																	gShzKijunYmd,
																	recMeisai.gMgrCd,
																	gOutflg);
	END IF;
	gRknShrTesuBunshi := 0;
	IF (recMeisai.gRknShrTesuBunshi IS NOT NULL AND recMeisai.gRknShrTesuBunshi::text <> '') THEN
		-- 消費税率適用基準日切り替え
		IF gShzKijunProcess = '1' THEN
			gShzKijunYmd := recMeisai.gShrYmd;
		ELSE
			-- 基金異動履歴から利金支払手数料徴求日を取得する
			gShzKijunYmd := PKIPACALCTESURYO.getTesuChokyuYmd(l_inItakuKaishaCd, recMeisai.gMgrCd, recMeisai.gShrYmd, '22');
		END IF;
		gRknShrTesuBunshi := pkTesuryoRitsu.getTesuryoRitsuBunshi(	l_inItakuKaishaCd,
																	recMeisai.gRknShrTesuBunshi,
																	gShzKijunYmd,
																	recMeisai.gMgrCd,
																	gOutflg);
	END IF;
	-- ブレイク処理(発行体コード、ISINコード)
	IF keyHktCd <> recMeisai.gHktCd OR keyIsinCd <> recMeisai.gIsinCd THEN
		--グロスアップ銘柄税率入力ＯＰフラグの有無
		IF pkControl.getOPTION_FLG(l_inItakuKaishaCd , GRS_OPTION_CD,'0') = '1' THEN
			--グロスアップ銘柄税率設定　ブレイク処理時処理
			--欄外表示の国税率リストの設定
			IF gSeqNo > 0 THEN
				--「グロスアップ銘柄税率入力OP」の追加処理概要④
				CALL SPIPX022K02R01_writeRangaiKokuZeiRateList(
				  	l_inItakuKaishaCd	     	,
					l_inUserId     	,
					l_inChohyoKbn  	,
					l_inGyomuYmd 	,
					l_inChohyoId		,
					gSeqNo    		,
					gNo   				,
					grsRangaiKokuZeiRateList,
					grsRangaiChuki
				);
			END IF;
			--「グロスアップ銘柄税率入力OP」の追加処理概要⑤
			--ブレイク処理時のリセット　初期化
			grsGrossSeqNo := 0;
			grsRangaiKokuZeiRateList := '';
			grsPrTekiyoRbr := '';
			grsTekiyoRbr := '';
			grsRangaiChuki := '';
		END IF;
		-- 合計変数初期化
		gGnknShrGoukei := 0;
		gRknShrGoukei  := 0;
		-- NO初期化
		gNo := 0;
	END IF;
	-- 合計算出
	gGnknShrGoukei := gGnknShrGoukei + coalesce(recMeisai.gShokanSeikyuKngk, 0);
	gRknShrGoukei  := gRknShrGoukei +
						coalesce(recMeisai.gGzeihikiBefChokyuKngk, 0);
	-- ブレイクキー設定
	keyHktCd  := recMeisai.gHktCd;
	keyIsinCd := recMeisai.gIsinCd;
	-- シーケンスアップ
	gSeqNo := gSeqNo + 1;
	-- NOアップ
	gNo := gNo + 1;
	-- 手数料率の分子がゼロの場合はブランクにする
	IF gGnknShrTesuBunshi <= 0 THEN
		gGnknShrTesuBunshi := NULL;
		recMeisai.gGnknShrTesuBunbo := NULL;
	END IF;
	IF gRknShrTesuBunshi <= 0 THEN
		gRknShrTesuBunshi := NULL;
		recMeisai.gRknShrTesuBunbo := NULL;
	END IF;
	-- 支払額の合計がゼロの場合は手数料をブランクにする
	-- 支払額の合計がゼロ以外で、手数料率がブランクの場合は、手数料をゼロにする
	IF (gGnknShrGoukei <= 0 AND recMeisai.gGnknShukinKngk = 0) THEN
		recMeisai.gGnknShukinKngk := NULL;
	ELSE
		IF coalesce(gGnknShrTesuBunshi::text, '') = '' THEN
			recMeisai.gGnknShukinKngk := 0;
		END IF;
	END IF;
	IF (gRknShrGoukei <= 0 AND recMeisai.gRknShukinKngk = 0) THEN
		recMeisai.gRknShukinKngk := NULL;
	ELSE
		IF coalesce(gRknShrTesuBunshi::text, '') = '' THEN
			recMeisai.gRknShukinKngk := 0;
		END IF;
	END IF;
	-- 手数料種類に応じて利払手数料通貨コードを取得(元金ベース=発行通貨コード、利金ベース=利払通貨コード)
	BEGIN
		SELECT (SELECT TSUKA_NM FROM MTSUKA WHERE TSUKA_CD = CASE WHEN MG7.TESU_SHURUI_CD='61' THEN MG1.HAKKO_TSUKA_CD WHEN MG7.TESU_SHURUI_CD='82' THEN MG1.RBR_TSUKA_CD END )
		INTO STRICT
			gRknTesuTsuka
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
			AND	MG1.ITAKU_KAISHA_CD		= l_inItakuKaishaCd
			AND	MG1.MGR_CD				= recMeisai.gMgrCd;
	EXCEPTION
		WHEN no_data_found THEN
			gRknTesuTsuka := '';
	END;
	-- 元金手数料のみの場合、利金手数料通貨にも元金とおなじ通貨をセット(手数料合計に表示するため)
	IF recMeisai.gRknShukinKngk = 0 OR coalesce(trim(both recMeisai.gRknShukinKngk)::text, '') = '' THEN
		gRknTesuTsuka := recMeisai.gGankinTsukaNm;
	END IF;
	--元利払期日取得
	gRbrKjt := pkIpaZei.getIpaRbrYmd(l_inItakuKaishaCd,
									 recMeisai.gMgrCd,
									 recMeisai.gShrYmd,
									 recMeisai.gTaxKbn);
	--元利払期日に該当する適用開始日の税区分を取得する
	gRet := pkIpaZei.getMTax(recMeisai.gTaxKbn,
							 gRbrKjt,
							 gTaxNm,
							 gTaxRnm,
							 gKokuZeiRate,
							 gChihoZeiRate
							);
	--グロスアップ銘柄税率入力ＯＰを使用しないくとも、以下の変数名で処理する。	
	grsKokuZeiRate		:= gKokuZeiRate;	
	grsVKokuZeiRate		:= oracle.to_char(grsKokuZeiRate,TAX_FMT);	
	--グロスアップ銘柄税率入力ＯＰフラグの有無
	IF pkControl.getOPTION_FLG(l_inItakuKaishaCd , GRS_OPTION_CD,'0') = '1' THEN
		IF recMeisai.gTaxKbn = '90' THEN   --課税区分が'90'の場合
		 --国税率欄の※を設定する
			grsVKokuZeiRate := '※';
			IF coalesce(trim(both grsRangaiChuki)::text, '') = '' THEN  --(欄外表示の注記が未設定)　最初のループであれば設定しておく
				grsRangaiChuki :='※同じ課税区分ながら異なる税率が適用されるため、税率を非表示としております。';
			END IF;
		END IF;
			--「グロスアップ銘柄税率入力OP」の追加処理概要 ②	
			CALL SPIPX022K02R01_getGrossupKokuZeiRitsu(l_inItakuKaishaCd,recMeisai.gMgrCd,recMeisai.gShrYmd,recMeisai.gTaxKbn,grsKokuZeiRate,grsTekiyoRbr);
			--抽出できれば、「grsKokuZeiRate」に設定される。
			IF (grsKokuZeiRate IS NOT NULL AND grsKokuZeiRate::text <> '') THEN									
				IF coalesce(trim(both grsRangaiKokuZeiRateList)::text, '') = '' THEN								
					grsRangaiKokuZeiRateList := 'グロスアップ銘柄の税率は次のとおりです。';						
				END IF;								
				--「グロスアップ銘柄税率入力OP」の追加処理概要 ③	
				IF  coalesce(trim(both grsPrTekiyoRbr)::text, '') = '' OR
					--前回と今回で適用利払日付に差がある
					( trim(both grsTekiyoRbr) <> trim(both grsPrTekiyoRbr) ) AND
					--グロスアップ銘柄件数の最大カウント以下
					grsGrossSeqNo < GRS_CNT_MAX
					THEN
					grsPrTekiyoRbr := grsTekiyoRbr;				
					--帳票表出力文字列として、フォーマットする
					grsStrKokuZeiRate := TO_CHAR(grsKokuZeiRate,GRS_FMT);	
					--グロスアップ適用利払数をカウントアップ
					grsGrossSeqNo := grsGrossSeqNo + 1;					
					--文字列生成　（※連番）　
					grsAst := '※' || TRANSLATE(grsGrossSeqNo::text,'12345','１２３４５');								
					grsVKokuZeiRate :=grsAst;	
					--国税率欄外リスト文字列を連結処理をする	
					grsRangaiKokuZeiRateList := grsRangaiKokuZeiRateList || '　' || grsAst || '　' || grsStrKokuZeiRate;							
				ELSE
				    --グロスアップ対象銘柄であるが適用利払日が前回と同様であるため、そのまま国税率表記を利用する。
					grsVKokuZeiRate :=grsAst;
				END IF;										
			END IF;			
	END IF;
    -- 税区分が'85'の場合、以下をセットする
		IF recMeisai.gTaxKbn = '85' THEN
		    gKokuZeiRateFm := '-';			-- 国税率
		    gGZeiKngkFm := '-';				-- 国税額
		    gGzeihikiAftChokyuKngkFm := '-';			-- 利金支払基金請求額
		ELSE
			gKokuZeiRateFm := grsVKokuZeiRate;			-- 国税率
		    gGZeiKngkFm := recMeisai.gGzeiKngk;			-- 国税額
		    gGzeihikiAftChokyuKngkFm := recMeisai.gGzeihikiAftChokyuKngk;			-- 利金支払基金請求額
		END IF;
	-- 帳票ワークへデータを追加
	CALL pkPrintSskm.insertData(l_inKeyCd      => l_inItakuKaishaCd 				-- 識別コード
					  ,l_inUserId     => l_inUserId 							-- ユーザＩＤ
					  ,l_inChohyoKbn  => l_inChohyoKbn 						-- 帳票区分
					  ,l_inSakuseiYmd => l_inGyomuYmd 						-- 作成年月日
					  ,l_inChohyoId   => l_inChohyoId 						-- 帳票ＩＤ
					  ,l_inSeqNo      => 0									-- 連番
					  ,l_inSeqNo2     => gSeqNo	- 1							-- 連番２
					  ,l_inHeaderFlg  => '1'								-- ヘッダフラグ
					  ,l_inItem001    => l_inGyomuYmd 						-- データ基準日					  
					  ,l_inItem002    => l_inTsuchiYmd 						-- 通知日
					  ,l_inItem003    => trim(both recMeisai.gHktCd)				-- 発行体コード
					  ,l_inItem004    => trim(both recMeisai.gSfskPostNo)		-- 送付先郵便番号
					  ,l_inItem005    => trim(both recMeisai.gAdd1)				-- 送付先住所１
					  ,l_inItem006    => trim(both recMeisai.gAdd2)				-- 送付先住所２
					  ,l_inItem007    => trim(both recMeisai.gAdd3)				-- 送付先住所３
					  ,l_inItem008    => trim(both recMeisai.gHktNm)				-- 発行体名称
					  ,l_inItem009    => trim(both recMeisai.gHktRnm)			-- 発行体略称
					  ,l_inItem010    => trim(both recMeisai.gSfskBushoNm)		-- 送付先担当部署名称
					  ,l_inItem011    => trim(both recMeisai.gBankNm)			-- 金融機関名称
					  ,l_inItem012    => trim(both recMeisai.gBushoNm1)			-- 担当部署名称
					  ,l_inItem013    => gBunsho 							-- 請求文章
					  ,l_inItem014    => gKijunYm 							-- 取扱年月
					  ,l_inItem015    => trim(both recMeisai.gIsinCd)			-- ISINコード
					  ,l_inItem016    => trim(both recMeisai.gMgrRnm)			-- 銘柄略称
					  ,l_inItem017    => trim(both recMeisai.gMgrNm)				-- 銘柄の正式名称
					  ,l_inItem018    => recMeisai.gGanriKbn 				-- 元利区分
					  ,l_inItem019    => trim(both recMeisai.gShrYmd)			-- 元利払日
					  ,l_inItem020    => recMeisai.gShokanSeikyuKngk 		-- 償還金請求金額
					  ,l_inItem021    => trim(both recMeisai.gShokanTsukaCd)		-- 償還通貨コード
					  ,l_inItem022    => trim(both recMeisai.gGankinTsukaNm)		-- 償還通貨名称
					  ,l_inItem023    => recMeisai.gGzeihikiBefChokyuKngk 	-- 国税引前利金請求金額
					  ,l_inItem024    => trim(both recMeisai.gRbrTsukaCd)		-- 利払通貨コード
					  ,l_inItem025    => trim(both recMeisai.gRikinTsukaNm)		-- 利払通貨名称
					  ,l_inItem026    => trim(both recMeisai.gTaxKbn)			-- 税区分
					  ,l_inItem027    => gTaxNm 								-- 課税区分
					  ,l_inItem028    => gKokuZeiRateFm 						-- 国税率
					  ,l_inItem029    => gGZeiKngkFm 						-- 国税金額
					  ,l_inItem030    => gGzeihikiAftChokyuKngkFm 			-- 国税引後利金請求金額
					  ,l_inItem031    => gGnknShrTesuBunshi 					-- 元金支払手数料率（分子）
					  ,l_inItem032    => recMeisai.gGnknShrTesuBunbo 		-- 元金支払手数料率（分母）
					  ,l_inItem033    => recMeisai.gGnknShukinKngk 			-- 元金支払手数料金額
					  ,l_inItem034    => gRknShrTesuBunshi 					-- 利金支払手数料率（分子）
					  ,l_inItem035    => recMeisai.gRknShrTesuBunbo 			-- 利金支払手数料率（分母）
					  ,l_inItem036    => recMeisai.gRknShukinKngk 			-- 利金支払手数料金額
					  ,l_inItem037    => trim(both gRknTesuTsuka)				-- 利金手数料通貨コード
					  ,l_inItem038    => trim(both recMeisai.gTesuryoKomiFlg)	-- 手数料税込フラグ
					  ,l_inItem041    => gHasuRangaiChuki 					-- 端数欄外注記
					  ,l_inItem042    => trim(both recMeisai.gEigyotenCd)		-- 営業店コード
					  ,l_inItem043    => trim(both recMeisai.gEigyotenNm)		-- 営業店名称
					  ,l_inItem044    => trim(both recMeisai.gKozaTenCd)			-- 口座店コード
					  ,l_inItem045    => trim(both recMeisai.gKozaTenCifcd)		-- 口座店ＣＩＦコード
					  ,l_inItem046    => trim(both recMeisai.gJtkKbn)			-- 受託区分
					  ,l_inItem047    => trim(both recMeisai.gJtkKbnNm)			-- 受託区分名称
					  ,l_inItem048    => trim(both recMeisai.gHakkoYmd)			-- 発行年月日
					  ,l_inItem049    => trim(both recMeisai.gFullshokanKjt)		-- 満期償還期日
					  ,l_inItem050    => trim(both recMeisai.gKkKanyoFlg)		-- 機構関与方式採用フラグ
					  ,l_inItem051    => trim(both recMeisai.gKkKanyoFlgRnm)		-- 機構関与方式採用フラグ略称
					  ,l_inItem052    => recMeisai.gGnrZndk 					-- 元利払対象残高
					  ,l_inItem053    => recMeisai.gGnrJisshitsuZndk 		-- 元利払対象実質残高
					  ,l_inItem054    => coalesce(recMeisai.gRikinHasu, 0)				-- 利金端数
					  ,l_inItem055    => gRikinHasuFlg 						-- 利金端数計算フラグ
					  ,l_inItem056    => gTesuryoHasuFlg 						-- 手数料端数計算フラグ
					  ,l_inItem057    => gInvoiceFlg 						-- インボイスオプションフラグ
					  ,l_inKousinId   => l_inUserId 							-- 更新者ID
					  ,l_inSakuseiId  => l_inUserId 							-- 作成者ID
					);
	END LOOP;
	CLOSE curMeisai;
	IF pkControl.getOPTION_FLG(l_inItakuKaishaCd , GRS_OPTION_CD,'0') = '1' THEN
	    --「グロスアップ銘柄税率入力OP」の追加処理概要④
		--グロスアップ銘柄税率設定　最終ページ・最終行の処理
		--欄外表示の国税率リストの設定
		IF gSeqNo > 0 THEN	
			CALL SPIPX022K02R01_writeRangaiKokuZeiRateList(
				l_inItakuKaishaCd		,
				l_inUserId     			,
				l_inChohyoKbn  			,
				l_inGyomuYmd 			,
				l_inChohyoId			,
				gSeqNo    				,
				gNo   					,
				grsRangaiKokuZeiRateList,
				grsRangaiChuki
			);
		END IF;
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
  -- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		BEGIN
			CLOSE curMeisai;
		EXCEPTION
			WHEN OTHERS THEN NULL;
		END;
		CALL pkLog.fatal('ECM701', l_inChohyoId, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', l_inChohyoId, 'SQLERRM:' || SQLERRM);
		l_outSqlCode := RTN_FATAL;
		--    RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipx022k02r01 ( l_inChohyoId TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_inHktCd TEXT, l_inKozaTenCd TEXT, l_inKozaTenCifCd TEXT, l_inMgrCd TEXT, l_inIsinCd TEXT, l_inKijunYm TEXT, l_inKijunYmdFrom TEXT, l_inKijunYmdTo TEXT, l_inTsuchiYmd TEXT, l_outSqlCode OUT numeric  ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spipx022k02r01_createbun ( l_in_ReportID TEXT, l_in_PatternCd BUN.BUN_PATTERN_CD%TYPE) RETURNS varchar AS $body$
DECLARE

-- 請求文章(ワーク)
aryBun pkIpaBun.BUN_ARRAY;
wkBun  varchar(200) := NULL;
BEGIN
-- 請求文章の取得
aryBun := pkIpaBun.getBun(l_in_ReportID, l_in_PatternCd);
FOR i IN 1 .. COALESCE(cardinality(aryBun), 0) LOOP
	-- 100byteまで全角スペース埋めして、請求文章を連結
	wkBun := wkBun || RPAD(aryBun[i], 100, '　');
END LOOP;
RETURN wkBun;
EXCEPTION
WHEN OTHERS THEN
	RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spipx022k02r01_createbun ( l_in_ReportID TEXT, l_in_PatternCd BUN.BUN_PATTERN_CD%TYPE) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spipx022k02r01_createsql (
	l_inItakuKaishaCd TEXT,
	l_inKijunYmdFrom TEXT,
	l_inKijunYmdTo TEXT,
	l_inHktCd TEXT,
	l_inKozaTenCd TEXT,
	l_inKozaTenCifCd TEXT,
	l_inMgrCd TEXT,
	l_inIsinCd TEXT,
	gGyomuYm char(6),
	gChohyoSortFlg TEXT,
	gRikinHasuFlg TEXT,
	gTesuryoHasuFlg TEXT,
	gGnrshr0outFlg TEXT,
	l_outSQL OUT varchar
) AS $body$
DECLARE
	gSQL varchar(10000) := '';
BEGIN
-- 変数を初期化
gSQL := '';
-- 変数にSQLクエリ文を代入
gSql :='SELECT'
	|| '		M01.HKT_CD,'
	|| '		M01.SFSK_POST_NO,'
	|| '		M01.ADD1,'
	|| '		M01.ADD2,'
	|| '		M01.ADD3,'
	|| '		M01.HKT_NM,'
	|| '		M01.HKT_RNM,'
	|| '		M01.SFSK_BUSHO_NM,'
	|| '		VJ1.BANK_NM,'
	|| '		VJ1.BUSHO_NM1,'
	|| '		VMG1.ISIN_CD,'
	|| '		VMG1.MGR_RNM,'
	|| '		VMG1.MGR_NM,'
	|| '		CASE'
	|| '			WHEN SUM(K01.GZEIHIKI_BEF_CHOKYU_KNGK) <> 0 AND'
	|| '				SUM(K01.SHOKAN_SEIKYU_KNGK) = 0 THEN'
	|| '			''利金'''
	|| '			WHEN SUM(K01.GZEIHIKI_BEF_CHOKYU_KNGK) = 0 AND'
	|| '				SUM(K01.SHOKAN_SEIKYU_KNGK) <> 0 THEN'
	|| '			''元金'''
	|| '			WHEN SUM(K01.GZEIHIKI_BEF_CHOKYU_KNGK) <> 0 AND'
	|| '				SUM(K01.SHOKAN_SEIKYU_KNGK) <> 0 THEN'
	|| '			''元利金'''
	|| '			ELSE'
	|| '				NULL'
	|| '		END AS GANRI_KBN,'
	|| '		K01.SHR_YMD,'
	|| '		SUM(K01.SHOKAN_SEIKYU_KNGK),'
	|| '		VMG1.SHOKAN_TSUKA_CD,'
	|| '		GM64.TSUKA_NM,'
	|| '		SUM(K01.GZEIHIKI_BEF_CHOKYU_KNGK),'
	|| '		VMG1.RBR_TSUKA_CD,'
	|| '		RM64.TSUKA_NM,'
	|| '		SUM(CASE WHEN K01.TAX_KBN = ''85'' THEN 0 ELSE K01.GZEI_KNGK END),'
	|| '		RM64.TSUKA_NM,'
	|| '		SUM(CASE WHEN K01.TAX_KBN = ''85'' THEN 0 ELSE K01.GZEIHIKI_AFT_CHOKYU_KNGK END),'
	|| '		RM64.TSUKA_NM,'
	|| '		CASE'
	|| '			WHEN VGK021.KKN_SHUKIN_KNGK > 0 THEN'
	|| '			MG8.GNKN_SHR_TESU_BUNSHI'
	|| '			ELSE'
	|| '			NULL'
	|| '		END AS GNKN_SHR_TESU_BUNSHI,'
	|| '		CASE'
	|| '			WHEN VGK021.KKN_SHUKIN_KNGK > 0 THEN'
	|| '			MG8.GNKN_SHR_TESU_BUNBO'
	|| '			ELSE'
	|| '			NULL'
	|| '		END AS GNKN_SHR_TESU_BUNBO,'
	|| '		VGK021.KKN_SHUKIN_KNGK,'
	|| '		CASE'
	|| '			WHEN VRK021.KKN_SHUKIN_KNGK > 0 THEN'
	|| '			MG8.RKN_SHR_TESU_BUNSHI'
	|| '			ELSE'
	|| '			NULL'
	|| '		END AS RKN_SHR_TESU_BUNSHI,'
	|| '		CASE'
	|| '			WHEN VRK021.KKN_SHUKIN_KNGK > 0 THEN'
	|| '			MG8.RKN_SHR_TESU_BUNBO'
	|| '			ELSE'
	|| '			NULL'
	|| '		END AS RKN_SHR_TESU_BUNBO,'
	|| '		VRK021.KKN_SHUKIN_KNGK,'
	|| '		VJ1.TESURYO_KOMI_FLG,'
	|| '		K01.MGR_CD,'
	|| '		K01.TAX_KBN,'
	|| '		M01.EIGYOTEN_CD,' -- IP-05983 営業店コード
	|| '		RPAD(M04.BUTEN_NM, 50, '' ''),'; -- IP-05983 営業店名称
IF gRikinHasuFlg = '0' THEN  -- 利金端数
	gSql := gSql || ' 0 AS RIKIN_HASU,   ';
ELSE
	gSql := gSql || ' VRKH021.KKN_SHUKIN_KNGK AS RIKIN_HASU,   ';
END IF;
	gSql := gSql || 'M01.KOZA_TEN_CD,'
	|| '		M01.KOZA_TEN_CIFCD,'
	|| '		VMG1.JTK_KBN,'
	|| '		(SELECT CODE_NM FROM SCODE WHERE VMG1.JTK_KBN'
	|| '		 = CODE_VALUE AND CODE_SHUBETSU = ''112'') AS JTK_KBN_NM,'
	|| '		VMG1.HAKKO_YMD,'
	|| '		VMG1.FULLSHOKAN_KJT,'
	|| '		VMG1.KK_KANYO_FLG,'
	|| '		(SELECT CODE_RNM FROM SCODE WHERE VMG1.KK_KANYO_FLG'
	|| '		 = CODE_VALUE AND CODE_SHUBETSU = ''505'') AS KK_KANYO_FLG_RNM,'
	|| '		SUM(K01.GNR_ZNDK),'
	|| '		SUM(K01.GNR_JISSHITSU_ZNDK)'
	|| '	FROM KIKIN_SEIKYU K01,'
	|| '		MGR_TESURYO_PRM MG8,'
	|| '		MHAKKOTAI M01,'
	|| '		MBUTEN M04,' -- IP-05983 部店マスタ
	|| '		VJIKO_ITAKU VJ1,'
	|| '		(SELECT *'
	|| '		  FROM MGR_KIHON_VIEW VMG12'
	|| '		 WHERE TRIM(VMG12.ISIN_CD) IS NOT NULL'
	|| '			AND VMG12.MGR_STAT_KBN = ''1'''
	|| '			AND VMG12.JTK_KBN <> ''2'''
	|| '			AND VMG12.JTK_KBN <> ''5'') VMG1,'
	|| '		MTSUKA GM64,'
	|| '		MTSUKA RM64,'
	|| '		(SELECT K021.ITAKU_KAISHA_CD,'
	|| '				K021.MGR_CD,'
	|| '				SUM(K021.KKN_SHUKIN_KNGK) AS KKN_SHUKIN_KNGK'
	|| '		  FROM KIKIN_IDO K021';
IF gTesuryoHasuFlg = '0' THEN
	gSql := gSql || '    WHERE K021.KKN_IDO_KBN IN (''32'', ''33'')';
ELSE
	gSql := gSql || '    WHERE K021.KKN_IDO_KBN IN (''32'', ''33'', ''94'')';
END IF;
  IF (trim(both l_inKijunYmdFrom) IS NOT NULL AND (trim(both l_inKijunYmdFrom))::text <> '') THEN
   gSql := gSql || '    AND K021.RBR_YMD BETWEEN '''|| l_inKijunYmdFrom || ''' AND '''|| l_inKijunYmdTo || ''' ';
  ELSE
   gSql := gSql || '    AND SUBSTR(K021.RBR_YMD, 1, 6) = '''|| gGyomuYm || '''';
  END IF;
  gSql :=  gSql || '		 GROUP BY K021.ITAKU_KAISHA_CD,'
	|| '				  K021.MGR_CD,'
	|| '				  SUBSTR(K021.RBR_YMD, 1, 6)) VGK021,'
	|| '		(SELECT K021.ITAKU_KAISHA_CD,'
	|| '				K021.MGR_CD,'
	|| '				SUM(K021.KKN_SHUKIN_KNGK) AS KKN_SHUKIN_KNGK'
	|| '		  FROM KIKIN_IDO K021';
IF gTesuryoHasuFlg = '0' THEN
	gSql :=  gSql || '		 WHERE K021.KKN_IDO_KBN IN (''42'', ''43'')';
ELSE
	gSql :=  gSql || '		 WHERE K021.KKN_IDO_KBN IN (''42'', ''43'', ''96'')';
END IF;
  IF (trim(both l_inKijunYmdFrom) IS NOT NULL AND (trim(both l_inKijunYmdFrom))::text <> '') THEN
   gSql := gSql || '    AND K021.RBR_YMD BETWEEN '''|| l_inKijunYmdFrom || ''' AND '''|| l_inKijunYmdTo || ''' ';
  ELSE
   gSql := gSql || '    AND SUBSTR(K021.RBR_YMD, 1, 6) = '''|| gGyomuYm || '''';
  END IF;
  gSql :=  gSql || '		 GROUP BY K021.ITAKU_KAISHA_CD,'
	|| '				  K021.MGR_CD,'
	|| '				  SUBSTR(K021.RBR_YMD, 1, 6)) VRK021,'
	|| '		(SELECT GK01.ITAKU_KAISHA_CD, GK01.MGR_CD'
	|| '		  FROM KIKIN_SEIKYU GK01';
  IF (trim(both l_inKijunYmdFrom) IS NOT NULL AND (trim(both l_inKijunYmdFrom))::text <> '') THEN
   gSql := gSql || ' WHERE GK01.SHR_YMD BETWEEN'''|| l_inKijunYmdFrom || ''' AND '''|| l_inKijunYmdTo || ''' ';
  ELSE
   gSql := gSql || ' WHERE SUBSTR(GK01.SHR_YMD, 1, 6) = '''|| gGyomuYm || '''';
  END IF;
  gSql :=  gSql || '		 GROUP BY GK01.ITAKU_KAISHA_CD, GK01.MGR_CD'
	|| '		HAVING SUM(GK01.SHOKAN_SEIKYU_KNGK) <> 0) VGK01,'
	|| '		(SELECT RK01.ITAKU_KAISHA_CD, RK01.MGR_CD'
	|| '		  FROM KIKIN_SEIKYU RK01';
  IF (trim(both l_inKijunYmdFrom) IS NOT NULL AND (trim(both l_inKijunYmdFrom))::text <> '') THEN
   gSql := gSql || ' WHERE RK01.SHR_YMD BETWEEN'''|| l_inKijunYmdFrom || ''' AND '''|| l_inKijunYmdTo || ''' ';
  ELSE
   gSql := gSql || ' WHERE SUBSTR(RK01.SHR_YMD, 1, 6) = '''|| gGyomuYm || '''';
  END IF;
  gSql :=  gSql	|| '		 GROUP BY RK01.ITAKU_KAISHA_CD, RK01.MGR_CD'
	|| '		HAVING SUM(RK01.GZEIHIKI_BEF_CHOKYU_KNGK) <> 0) VRK01,'
	|| '		(SELECT K021.ITAKU_KAISHA_CD,'
	|| '				K021.MGR_CD,'
	|| '				SUM(K021.KKN_SHUKIN_KNGK) AS KKN_SHUKIN_KNGK'
	|| '		  FROM KIKIN_IDO K021'
	|| '		 WHERE K021.KKN_IDO_KBN  = ''92''';
  IF (trim(both l_inKijunYmdFrom) IS NOT NULL AND (trim(both l_inKijunYmdFrom))::text <> '') THEN
   gSql := gSql || '    AND K021.RBR_YMD BETWEEN '''|| l_inKijunYmdFrom || ''' AND '''|| l_inKijunYmdTo || ''' ';
  ELSE
   gSql := gSql || '    AND SUBSTR(K021.RBR_YMD, 1, 6) = '''|| gGyomuYm || '''';
  END IF;
  gSql :=  gSql || '		 GROUP BY K021.ITAKU_KAISHA_CD,'
	|| '				  K021.MGR_CD,'
	|| '				  SUBSTR(K021.RBR_YMD, 1, 6)) VRKH021'
	|| ' WHERE K01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD'
	|| '	AND K01.MGR_CD = VMG1.MGR_CD'
	|| '	AND K01.ITAKU_KAISHA_CD = VJ1.KAIIN_ID'
--  IP-05983 営業店コード・名称表示対応
	|| '	AND M01.ITAKU_KAISHA_CD = M04.ITAKU_KAISHA_CD'
	|| '	AND M01.EIGYOTEN_CD = M04.BUTEN_CD'
-- 実質記番号方式は対象外
	|| '	AND K01.KK_KANYO_UMU_FLG <> ''2'' '
-- 機構非関与銘柄元利金請求データ(承認)で承認していない銘柄は対象外
	|| ' AND (K01.KK_KANYO_UMU_FLG = ''1'' '
	|| ' OR (K01.KK_KANYO_UMU_FLG = ''0'' AND K01.SHORI_KBN = ''1''))';
--  国税引前利金請求金額＋償還金請求金額＝０は作成対象外
IF gGnrshr0outFlg = '1' THEN
	gSql := gSql || ' AND K01.GZEIHIKI_BEF_CHOKYU_KNGK + K01.SHOKAN_SEIKYU_KNGK <> 0 ';
END IF;
-- 入力パラメータ条件
-- 委託会社コード
IF (trim(both l_inItakuKaishaCd) IS NOT NULL AND (trim(both l_inItakuKaishaCd))::text <> '') THEN
	gSql := gSql || '	AND K01.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd ||
		''' ';
END IF;
-- 業務年月
IF (trim(both l_inKijunYmdFrom) IS NOT NULL AND (trim(both l_inKijunYmdFrom))::text <> '') THEN
	gSql := gSql || '	AND K01.SHR_YMD BETWEEN '''|| l_inKijunYmdFrom || ''' AND '''|| l_inKijunYmdTo ||
		''' ';
ELSIF (trim(both gGyomuYm) IS NOT NULL AND (trim(both gGyomuYm))::text <> '') THEN
	gSql := gSql || '	AND SUBSTR(K01.SHR_YMD,1, 6) = ''' || gGyomuYm ||
		''' ';
END IF;
-- 発行体コード
IF (trim(both l_inHktCd) IS NOT NULL AND (trim(both l_inHktCd))::text <> '') THEN
	gSql := gSql || '	AND M01.HKT_CD = ''' || l_inHktCd || ''' ';
END IF;
-- 口座店コード
IF (trim(both l_inKozaTenCd) IS NOT NULL AND (trim(both l_inKozaTenCd))::text <> '') THEN
	gSql := gSql || '	AND M01.KOZA_TEN_CD = ''' || l_inKozaTenCd ||
        ''' ';
END IF;
-- 口座店CIFコード
IF (trim(both l_inKozaTenCifCd) IS NOT NULL AND (trim(both l_inKozaTenCifCd))::text <> '') THEN
	gSql := gSql || '	AND M01.KOZA_TEN_CIFCD = ''' || l_inKozaTenCifCd ||
        ''' ';
END IF;
-- 銘柄コード
IF (trim(both l_inMgrCd) IS NOT NULL AND (trim(both l_inMgrCd))::text <> '') THEN
	gSql := gSql || '	AND VMG1.MGR_CD = ''' || l_inMgrCd || ''' ';
END IF;
-- ISINコード
IF (trim(both l_inIsinCd) IS NOT NULL AND (trim(both l_inIsinCd))::text <> '') THEN
	gSql := gSql || '	AND VMG1.ISIN_CD = ''' || l_inIsinCd || ''' ';
END IF;
-- GROUP BY句
gSql := gSql	|| 'GROUP BY '
				|| '	K01.ITAKU_KAISHA_CD, '
				|| '	K01.MGR_CD, '
				|| '	K01.SHR_YMD, '
				|| '	K01.TAX_KBN, '
				|| '	M01.HKT_CD, '
				|| '	M01.SFSK_POST_NO, '
				|| '	M01.ADD1, '
				|| '	M01.ADD2, '
				|| '	M01.ADD3, '
				|| '	M01.HKT_NM, '
				|| '	M01.HKT_RNM,'
				|| '	M01.SFSK_BUSHO_NM, '
				|| '	M01.HKT_KANA_RNM, '
				|| '	M01.KOZA_TEN_CD, '
				|| '	M01.KOZA_TEN_CIFCD, '
				|| '	VJ1.BANK_NM, '
				|| '	VJ1.BUSHO_NM1, '
				|| '	VMG1.ISIN_CD, '
				|| '	VMG1.MGR_NM, '
				|| '	VMG1.MGR_RNM, '
				|| '	VMG1.SHOKAN_TSUKA_CD, '
				|| '	VMG1.RBR_TSUKA_CD, '
				|| '	VMG1.JTK_KBN, '
				|| '	VMG1.HAKKO_YMD, '
				|| '	VMG1.FULLSHOKAN_KJT, '
				|| '	VMG1.KK_KANYO_FLG, '
				|| '	VGK021.KKN_SHUKIN_KNGK, '
				|| '	VRK021.KKN_SHUKIN_KNGK, '
				|| '	VRKH021.KKN_SHUKIN_KNGK, '	-- 利金端数
				|| '	MG8.GNKN_SHR_TESU_BUNSHI, '
				|| '	MG8.GNKN_SHR_TESU_BUNBO, '
				|| '	MG8.RKN_SHR_TESU_BUNSHI, '
				|| '	MG8.RKN_SHR_TESU_BUNBO, '
				|| '	VJ1.TESURYO_KOMI_FLG, '
				|| '	GM64.TSUKA_NM, '
				|| '	RM64.TSUKA_NM, '
				|| '	M01.EIGYOTEN_CD, ' -- IP-05983 営業店コード
				|| '	M04.BUTEN_NM '; -- IP-05983 営業店名称
-- ORDER BY句
gSql := gSql || 'ORDER BY '
			 || '	K01.ITAKU_KAISHA_CD, '
			 || '	CASE WHEN ''' || gChohyoSortFlg || ''' = ''1'' THEN M01.HKT_KANA_RNM ELSE M01.HKT_CD END, '
			 || '	M01.HKT_CD, '
			 || '	CASE WHEN ''' || gChohyoSortFlg || ''' = ''1'' THEN K01.MGR_CD ELSE VMG1.ISIN_CD END, '
			 || '	K01.SHR_YMD, '
			 || '	GANRI_KBN, '
			 || '	K01.TAX_KBN ';
	-- Return the generated SQL
	l_outSQL := gSQL;
EXCEPTION
WHEN OTHERS THEN
	RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipx022k02r01_createsql () FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spipx022k02r01_getgrossupkokuzeiritsu ( l_inItakuKaishaCd TEXT , l_inMgrCd TEXT , l_inRbrYmd TEXT , l_inTaxKbn TEXT, l_outGrossKokuZeiRate OUT GROSSUP_MGR_TAX.GRS_KOKU_ZEI_RATE%TYPE , l_outGrossTekiyoRbrKjt OUT GROSSUP_MGR_TAX.TEKIYO_RBR_KJT%TYPE) AS $body$
DECLARE

ora2pg_rowcount int;
wkRbrKjt  MGR_RBRKIJ.RBR_KJT%TYPE;
wkKokuZeiRate  GROSSUP_MGR_TAX.GRS_KOKU_ZEI_RATE%TYPE	:= NULL;
wkTekiyoRbrKjt GROSSUP_MGR_TAX.TEKIYO_RBR_KJT%TYPE := NULL;

BEGIN
	--「グロスアップ銘柄税率入力OP」の追加処理概要 ①	
	IF SPIPX022K02R01_isGrossupTaxKbn(l_inTaxKbn) THEN
	  --指定銘柄の利払日から利払期日を求める
	  SELECT
	    RBR_KJT
	  INTO STRICT wkRbrKjt
	  FROM
	  	MGR_RBRKIJ
	  WHERE
	  	ITAKU_KAISHA_CD = l_inItakuKaishaCd AND
	  	MGR_CD = l_inMgrCd AND
	  	RBR_YMD	= l_inRbrYmd;
	  	--指定銘柄のグロスアップ税率情報が取得利払期日より以前に存在するかチェックする。
		--MAX指定により直近の適用利払期日を取得する。
		GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;
IF ora2pg_rowcount > 0 THEN
			--グロスアップ銘柄の指定利払日
			SELECT GRS_KOKU_ZEI_RATE, TEKIYO_RBR_KJT
			INTO STRICT  wkKokuZeiRate,wkTekiyoRbrKjt
  					FROM GROSSUP_MGR_TAX
			WHERE ITAKU_KAISHA_CD = l_inItakuKaishaCd AND MGR_CD = l_inMgrCd
   				AND TEKIYO_RBR_KJT
      				= (SELECT
          				MAX(trim(both TEKIYO_RBR_KJT))
          				FROM GROSSUP_MGR_TAX
           			WHERE ITAKU_KAISHA_CD = l_inItakuKaishaCd
             			AND MGR_CD =l_inMgrCd
             			AND TEKIYO_RBR_KJT <= wkRbrKjt
             			AND SHORI_KBN = '1'
           			GROUP BY ITAKU_KAISHA_CD, MGR_CD);
		END IF;
	END IF;
	l_outGrossKokuZeiRate := wkKokuZeiRate;
	l_outGrossTekiyoRbrKjt := wkTekiyoRbrKjt;
EXCEPTION
	WHEN no_data_found THEN
		l_outGrossKokuZeiRate := NULL;
		l_outGrossTekiyoRbrKjt := NULL;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipx022k02r01_getgrossupkokuzeiritsu ( l_inItakuKaishaCd TEXT , l_inMgrCd TEXT , l_inRbrYmd TEXT , l_inTaxKbn TEXT, l_outGrossKokuZeiRate OUT GROSSUP_MGR_TAX.GRS_KOKU_ZEI_RATE%TYPE , l_outGrossTekiyoRbrKjt OUT GROSSUP_MGR_TAX.TEKIYO_RBR_KJT%TYPE) FROM PUBLIC;



DROP TYPE IF EXISTS mTaxArray CASCADE;


CREATE OR REPLACE FUNCTION spipx022k02r01_isgrossuptaxkbn ( l_in_Taxkbn MTAX.TAX_KBN%TYPE) RETURNS boolean AS $body$
DECLARE

  mta  MTAX.TAX_KBN%TYPE[] := ARRAY['10', '20', '92','94'];

BEGIN
  FOR i IN 1 .. COALESCE(cardinality(mta), 0) LOOP
    IF l_in_TaxKbn = mta[i] THEN 
      RETURN TRUE;
    END IF;
  END LOOP;
  RETURN FALSE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spipx022k02r01_isgrossuptaxkbn ( l_in_Taxkbn MTAX.TAX_KBN%TYPE) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spipx022k02r01_updsreportwk ( l_inKeyCd SREPORT_WK_SSKM.KEY_CD%TYPE, l_inUserId SREPORT_WK_SSKM.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK_SSKM.CHOHYO_KBN%TYPE, l_inSakuseiYmd SREPORT_WK_SSKM.SAKUSEI_YMD%TYPE, l_inChohyoId SREPORT_WK_SSKM.CHOHYO_ID%TYPE, l_inSeqNo SREPORT_WK_SSKM.SEQ_NO%TYPE, l_inRangaiKokuZeiRateList text, l_inRangaiChuki text ) AS $body$
BEGIN
	UPDATE SREPORT_WK_SSKM
	SET ITEM039= l_inRangaiKokuZeiRateList
	   ,ITEM040= l_inRangaiChuki
	WHERE
		KEY_CD = l_inKeyCd AND
		USER_ID = l_inUserId AND
		CHOHYO_KBN = l_inChohyoKbn AND
		SAKUSEI_YMD = l_inSakuseiYmd AND
		CHOHYO_ID = l_inChohyoId AND
		SEQ_NO2 = l_inSeqNo - 1;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipx022k02r01_updsreportwk ( l_inKeyCd SREPORT_WK_SSKM.KEY_CD%TYPE, l_inUserId SREPORT_WK_SSKM.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK_SSKM.CHOHYO_KBN%TYPE, l_inSakuseiYmd SREPORT_WK_SSKM.SAKUSEI_YMD%TYPE, l_inChohyoId SREPORT_WK_SSKM.CHOHYO_ID%TYPE, l_inSeqNo SREPORT_WK_SSKM.SEQ_NO%TYPE, l_inRangaiKokuZeiRateList text, l_inRangaiChuki text ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spipx022k02r01_writerangaikokuzeiratelist ( l_inItakuKaishaCd SREPORT_WK_SSKM.KEY_CD%TYPE,    -- 識別コード
 l_inUserId SREPORT_WK_SSKM.USER_ID%TYPE,           -- ユーザID
 l_inChohyoKbn SREPORT_WK_SSKM.CHOHYO_KBN%TYPE,        -- 帳票区分
 l_inGyomuYmd SREPORT_WK_SSKM.SAKUSEI_YMD%TYPE,       -- 作成年月日
 l_inChohyoId SREPORT_WK_SSKM.CHOHYO_ID%TYPE,         -- 帳票ＩＤ         
 l_inSeqNo SREPORT_WK_SSKM.SEQ_NO%TYPE,            -- 連番
 l_inNo integer ,                          -- No
 l_inRangaiKokuZeiRateList text,    -- 欄外表示の国税率リスト
 l_inRangaiChuki text 			-- 欄外注記の文言
 ) AS $body$
DECLARE

  wkGrsNo    integer := 0; 						-- グロスアップ税率設定NO
BEGIN
		--元利金支払報告書帳票の欄外税率リスト設定行を導く
            --各ページのレコードに「欄外表示の国税率リスト」を更新する。
		
		--更新対象レコード連番 = 帳票ワークの連番 - ブレイク毎のカウント数 + 1
		wkGrsNo := l_inSeqNo - l_inNo + 1;
		LOOP
			--端数レコードの国税率リスト設定
			CALL updSreportWK(
				  l_inItakuKaishaCd 						-- 識別コード
				  ,l_inUserId 							-- ユーザＩＤ
				  ,l_inChohyoKbn 						-- 帳票区分
				  ,l_inGyomuYmd 							-- 作成年月日
				  ,l_inChohyoId 							-- 帳票ＩＤ
				  ,wkGrsNo  								-- 更新対象のレコード連番
				  ,grsRangaiKokuZeiRateList              -- 欄外表示の国税率リスト
				  ,grsRangaiChuki                        -- 欄外注記の文言
				);
			EXIT WHEN wkGrsNo = l_inSeqNo;
			--更新対象レコード連番
			wkGrsNo := wkGrsNo + 1;	
		END LOOP;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipx022k02r01_writerangaikokuzeiratelist ( l_inItakuKaishaCd SREPORT_WK_SSKM.KEY_CD%TYPE, l_inUserId SREPORT_WK_SSKM.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK_SSKM.CHOHYO_KBN%TYPE, l_inGyomuYmd SREPORT_WK_SSKM.SAKUSEI_YMD%TYPE, l_inChohyoId SREPORT_WK_SSKM.CHOHYO_ID%TYPE, l_inSeqNo SREPORT_WK_SSKM.SEQ_NO%TYPE, l_inNo integer , l_inRangaiKokuZeiRateList text, l_inRangaiChuki text ) FROM PUBLIC;
