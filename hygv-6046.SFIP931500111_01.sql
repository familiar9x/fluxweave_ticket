


DROP TYPE IF EXISTS sfip931500111_01_type_record;
CREATE TYPE sfip931500111_01_type_record AS (
      gTsukaCd            char(3)                  -- 通貨コード
    , gTsukaNm            char(3)                  -- 通貨名称
    , gMgrCd              varchar(13)                 -- 銘柄コード
    , gMgrRnm             varchar(44)                -- 銘柄略称
    , gRbrKij             numeric(3)                 -- 銘柄利払回次
    , gRbrKjtMd1          char(4)            -- 利払期日（１）
    , gRbrKjtMd2          char(4)            -- 利払期日（２）
    , gRbrKjtMd3          char(4)            -- 利払期日（３）
    , gRbrKjtMd4          char(4)            -- 利払期日（４）
    , gRbrKjtMd5          char(4)            -- 利払期日（５）
    , gRbrKjtMd6          char(4)            -- 利払期日（６）
    , gRbrKjtMd7          char(4)            -- 利払期日（７）
    , gRbrKjtMd8          char(4)            -- 利払期日（８）
    , gRbrKjtMd9          char(4)            -- 利払期日（９）
    , gRbrKjtMd10         char(4)           -- 利払期日（１０）
    , gRbrKjtMd11         char(4)           -- 利払期日（１１）
    , gRbrKjtMd12         char(4)           -- 利払期日（１２）
    , gHakkoYmd	          char(8)              -- 発行日
    , gStRbrKjt	          char(8)	            -- 初回利払期日
    , gSaisyuCyukiRbrKjt	char(8)	              -- 最終中期利払期日
    , gFullshokanKjt	    char(8)	        -- 満期償還期日
    , gNyukinYmd	        char(8)	              -- 入金日
    , gIkkatuCyosyuKngk	  decimal(16,2)        -- 一括徴収額
    , gIkkatuCyosyuZei	  decimal(16,2)        -- 一括徴収額（内消費税）
    , gGnrbaraiKjt	      char(8) -- 元利払期日
    , gGnknShrTesuKngk	  decimal(16,2)        -- 内元金支払手数料
    , gGnknShrTesuZei	    decimal(16,2)        -- 内元金支払手数料（内消費税）
    , gRiknShrTesuKngk	  decimal(16,2)        -- 利金支払手数料
    , gRiknShrTesuZei	    decimal(16,2)        -- 利金支払手数料（内消費税）
    , gGnknShrTesuKngkSum decimal(16,2)        -- 内元金支払手数料合計
    , gGnknShrTesuZeiSum  decimal(16,2)        -- 内元金支払手数料（内消費税）合計
    , gRiknShrTesuKngkSum decimal(16,2)        -- 利金支払手数料合計
    , gRiknShrTesuZeiSum  decimal(16,2)        -- 利金支払手数料（内消費税）合計
    , gShrSumi            varchar(2)                           -- 支払済フラグ
	);


CREATE OR REPLACE FUNCTION sfip931500111_01 ( l_inUserId text		      -- ユーザID
 , l_inItakuKaishaCd text		-- 委託会社コード
 , l_inHakkoTaiCd text		  -- 発行体コード
 , l_inMeigaraCode text		  -- 銘柄コード
 , l_inIsinCd text		      -- ＩＳＩＮコード
 , l_inKijun_Ym text		    -- 基準年月
 , l_inChohyo_Kbn text		  -- 帳票区分
 , l_outErrMsg OUT text        -- エラーコメント
 , OUT extra_param numeric) RETURNS record AS $body$
DECLARE

--********************************************************************************************************************
-- * 元利金手数料一括分収益計上予定表
-- * 元利金手数料一括分収益計上予定表帳票データを設定。
-- *
-- * @author	ASK
-- *
-- * @version $Revision: 1.0 $
-- *
-- * @param	l_inUserId			  ユーザＩＤ
-- * @param	l_inItakuKaishaCd	委託会社コード
-- * @param	l_inHakkoTaiCd    発行体コード
-- * @param	l_inMeigaraCode   銘柄コード
-- * @param	l_inIsinCd        ＩＳＩＮコード
-- * @param	l_inKijun_Ym			基準年月
-- * @param	l_inChohyo_Kbn		帳票区分
-- * @param	l_outErrMsg		    エラーコメント
-- * @return	returnCd			リターンコード
-- ********************************************************************************************************************
--====================================================================
--					デバッグ機能										  
--====================================================================
	DEBUG	numeric(1)	:= 1;
--==============================================================================
--          定数定義                                                            
--==============================================================================
	RTN_OK				CONSTANT integer	:= 0;						-- 正常
	RTN_NG				CONSTANT integer	:= 1;						-- 予期したエラー
	RTN_NODATA		CONSTANT integer	:= 2;						-- データなし
  RTN_FATAL     CONSTANT integer	:= 99;					-- 予期せぬエラー
  REPORT_ID     CONSTANT varchar(20) := 'IP931500111';            --固定値．帳票ID
  MSG_NODATA    CONSTANT varchar(20) := '対象データなし'; -- 検索結果0件
  PROGRAM_ID    CONSTANT varchar(32) := 'SFIP931500111_01';  -- プログラムＩＤ
  
	-- 書式フォーマット
	FMT_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 金額
	FMT_SZEI_J		CONSTANT char(18)	:= 'ZZZ,ZZZ,ZZZ,ZZ9';	-- 税金額
	FMT_TOTAL_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 合計金額
	-- 書式フォーマット（外資）
	FMT_KNGK_F	CONSTANT char(21)	:= 'ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 金額
	FMT_SZEI_F		CONSTANT char(21)	:= 'Z,ZZZ,ZZZ,ZZ9.99';	-- 税金額
	FMT_TOTAL_F	CONSTANT char(21)	:= 'ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 合計金額
--=======================================================================================================*
-- * 変数定義
-- *=======================================================================================================
  gyomuYmd            char(8);                                -- 業務日付
  returnCd            numeric;                                 -- リターンコード
  seqNo               integer :=  0;                     -- シーケンス
  rowCount            integer :=  0;                     -- 明細SQL文の取得件数
  mgrCd               MGR_KIHON.MGR_CD%TYPE;                  -- 銘柄コード
  gnrbaraiKjt         UPFR_TESURYO_KEIJYO.GNRBARAI_KJT%TYPE;  -- 元利払期日
  tsukaCd             MTSUKA.TSUKA_CD%TYPE;                   -- 通貨コード
  tsukaNm             MTSUKA.TSUKA_NM%TYPE;                   -- 通貨名称
  mgrRnm              MGR_KIHON.MGR_RNM%TYPE;                 -- 銘柄略称
  rbrKij              MGR_RBRKIJ.KAIJI%TYPE;                  -- 銘柄利払回次
  rbrKjtMd1           MGR_KIHON.RBR_KJT_MD1%TYPE;             -- 利払期日（１）
  rbrKjtMd2           MGR_KIHON.RBR_KJT_MD2%TYPE;             -- 利払期日（２）
  rbrKjtMd3           MGR_KIHON.RBR_KJT_MD3%TYPE;             -- 利払期日（３）
  rbrKjtMd4           MGR_KIHON.RBR_KJT_MD4%TYPE;             -- 利払期日（４）
  rbrKjtMd5           MGR_KIHON.RBR_KJT_MD5%TYPE;             -- 利払期日（５）
  rbrKjtMd6           MGR_KIHON.RBR_KJT_MD6%TYPE;             -- 利払期日（６）
  rbrKjtMd7           MGR_KIHON.RBR_KJT_MD7%TYPE;             -- 利払期日（７）
  rbrKjtMd8           MGR_KIHON.RBR_KJT_MD8%TYPE;             -- 利払期日（８）
  rbrKjtMd9           MGR_KIHON.RBR_KJT_MD9%TYPE;             -- 利払期日（９）
  rbrKjtMd10          MGR_KIHON.RBR_KJT_MD10%TYPE;            -- 利払期日（１０）
  rbrKjtMd11          MGR_KIHON.RBR_KJT_MD11%TYPE;            -- 利払期日（１１）
  rbrKjtMd12          MGR_KIHON.RBR_KJT_MD12%TYPE;            -- 利払期日（１２）
  hakkoYmd            MGR_KIHON.HAKKO_YMD%TYPE;               -- 発行日
  stRbrKjt            MGR_KIHON.ST_RBR_KJT%TYPE;              -- 初回利払期日
  saisyuCyukiRbrKjt   MGR_RBRKIJ.RBR_KJT%TYPE;                -- 最終中期利払期日
  fullshokanKjt       MGR_KIHON.FULLSHOKAN_KJT%TYPE;          -- 満期償還期日
  nyukinYmd           KIKIN_IDO.IDO_YMD%TYPE;                 -- 入金日
  ikkatuCyosyuKngk    KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE;         -- 一括徴収額
  ikkatuCyosyuZei     KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE;         -- 一括徴収額（内消費税）
  gnknShrTesuKngkSum  KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE;         -- 内元金支払手数料合計
  gnknShrTesuZeiSum   KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE;         -- 内元金支払手数料（内消費税）合計
  riknShrTesuKngkSum  KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE;         -- 利金支払手数料合計
  riknShrTesuZeiSum   KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE;         -- 利金支払手数料（内消費税）合計
  gnknShrTesuKngk     numeric := 0;                       -- 元金支払手数料
  gnknShrTesuZei      numeric := 0;                       -- 元金支払手数料（内消費税）
  riknShrTesuKngk     numeric := 0;                       -- 利金支払手数料
  riknShrTesuZei      numeric := 0;                       -- 利金支払手数料（内消費税）
  shrSumi             varchar(2);                            -- 支払済
  ruikeiKngk          numeric := 0;                       -- 累計額
  ruikeiZei           numeric := 0;                       -- 累計額（消費税）
  zanzonKngk          numeric := 0;                       -- 残存額
  zanzonZei           numeric := 0;                       -- 残存額（消費税）
  gSQL		            varchar(10000) := NULL;         -- SQL編集
  gSrkHakkoYmd          varchar(14) := NULL;            -- 発行日（西暦）
  gSrkStRbrKjt          varchar(14) := NULL;            -- 初回利払期日（西暦）
  gSrkSaisyuCyukiRbrKjt varchar(14) := NULL;            -- 最終中期利払期日（西暦）
  gSrkFullshokanKjt     varchar(14) := NULL;            -- 満期償還期日（西暦）
  gSrkNyukinYmd         varchar(14) := NULL;            -- 入金日（西暦）
  gSrkGnrbaraiKjt       varchar(14) := NULL;            --元利払期日（西暦）
	-- カーソル
	curMeisai REFCURSOR;
  -- DB取得項目
	-- 配列定義
	recMeisai SFIP931500111_01_TYPE_RECORD;                -- レコード
  v_item TYPE_SREPORT_WK_ITEM;
  
  -- 書式フォーマット
  fmtKngk	  varchar(21) := NULL;  -- 金額
	fmtSzei		varchar(21) := NULL;  -- 税金額
  gInvoiceFlg           MOPTION_KANRI.OPTION_FLG%TYPE;      -- オプションフラグ取得
  gBunsho               varchar(150) := NULL;         -- インボイス文章
  gAryBun               pkIpaBun.BUN_ARRAY;
--====================================================================*
--        メイン
-- *====================================================================
BEGIN
  CALL pkLog.DEBUG(l_inUserId,PROGRAM_ID,'START');
  --	入力パラメータ必須チェック	
  IF   coalesce(trim(both l_inUserId)::text, '') = ''
		OR coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
		OR (coalesce(trim(both l_inHakkoTaiCd)::text, '') = ''
		AND coalesce(trim(both l_inMeigaraCode)::text, '') = ''
		AND coalesce(trim(both l_inIsinCd)::text, '') = ''
		AND coalesce(trim(both l_inKijun_Ym)::text, '') = '')
		OR coalesce(trim(both l_inChohyo_Kbn)::text, '') = ''
	THEN
		-- パラメータエラー
    l_outErrMsg := '入力パラメータエラー';
    CALL pkLog.error(l_inUserId, PROGRAM_ID, l_outErrMsg);
		extra_param := RTN_NG;
		RETURN;
	END IF;
    --	業務日付の取得	
    gyomuYmd := pkDate.getGyomuYmd();
    -- 帳票ワークの削除
    DELETE FROM SREPORT_WK
    WHERE    KEY_CD      = l_inItakuKaishaCd
    AND      USER_ID     = l_inUserId
    AND      CHOHYO_KBN  = l_inChohyo_Kbn
    AND      SAKUSEI_YMD = gyomuYmd
    AND      CHOHYO_ID   = REPORT_ID;
  -- オプションフラグ取得
  gInvoiceFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd, 'INVOICE_A', '0');
    -- インボイス文章取得
    IF gInvoiceFlg = '1' THEN
      gAryBun := pkIpaBun.getBun(REPORT_ID, 'L0');
      FOR i IN 0..coalesce(cardinality(gAryBun), 0) - 1 LOOP
           IF i = 0 THEN
               gBunsho := gAryBun[i];
           END IF;
      END LOOP;
    END IF;
    -- 変数初期化
    gnknShrTesuKngk := 0;
    gnknShrTesuZei := 0;
    riknShrTesuKngk := 0;
    riknShrTesuZei := 0;
    ruikeiKngk := 0;
    ruikeiZei := 0;
    zanzonKngk := 0;
    zanzonZei := 0;
    mgrCd := NULL;
    -- ヘッダーレコード出力
    CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyo_Kbn, gyomuYmd, REPORT_ID);
    -- SQL編集
    CALL SFIP931500111_01_createSQL(l_inItakuKaishaCd, l_inHakkoTaiCd, l_inMeigaraCode, l_inIsinCd, l_inKijun_Ym, gyomuYmd, gSQL);
    -- カーソルオープン
    OPEN curMeisai FOR EXECUTE gSQL;
    LOOP
      FETCH curMeisai
      INTO
          recMeisai.gTsukaCd             -- 通貨コード
        , recMeisai.gTsukaNm             -- 通貨名称
        , recMeisai.gMgrCd               -- 銘柄コード
        , recMeisai.gMgrRnm              -- 銘柄略称
        , recMeisai.gRbrKij              -- 銘柄利払回次
        , recMeisai.gRbrKjtMd1
        , recMeisai.gRbrKjtMd2
        , recMeisai.gRbrKjtMd3
        , recMeisai.gRbrKjtMd4
        , recMeisai.gRbrKjtMd5
        , recMeisai.gRbrKjtMd6
        , recMeisai.gRbrKjtMd7
        , recMeisai.gRbrKjtMd8
        , recMeisai.gRbrKjtMd9
        , recMeisai.gRbrKjtMd10
        , recMeisai.gRbrKjtMd11
        , recMeisai.gRbrKjtMd12
        , recMeisai.gHakkoYmd
        , recMeisai.gStRbrKjt 	          -- 初回利払期日
        , recMeisai.gSaisyuCyukiRbrKjt 	-- 最終中期利払期日
        , recMeisai.gFullshokanKjt 	    -- 満期償還期日
        , recMeisai.gNyukinYmd 	        -- 入金日
        , recMeisai.gIkkatuCyosyuKngk 	  -- 一括徴収額
        , recMeisai.gIkkatuCyosyuZei 	  -- 一括徴収額（内消費税）
        , recMeisai.gGnrbaraiKjt 	      -- 元利払期日
        , recMeisai.gGnknShrTesuKngk 	  -- 内元金支払手数料
        , recMeisai.gGnknShrTesuZei 	    -- 内元金支払手数料（内消費税）
        , recMeisai.gRiknShrTesuKngk 	  -- 利金支払手数料
        , recMeisai.gRiknShrTesuZei 	    -- 利金支払手数料（内消費税）
        , recMeisai.gGnknShrTesuKngkSum  -- 内元金支払手数料合計
        , recMeisai.gGnknShrTesuZeiSum   -- 内元金支払手数料（内消費税）合計
        , recMeisai.gRiknShrTesuKngkSum  -- 利金支払手数料合計
        , recMeisai.gRiknShrTesuZeiSum   -- 利金支払手数料（内消費税）合計
        , recMeisai.gShrSumi
;
      -- データが無くなったらループを抜ける
      EXIT WHEN NOT FOUND;/* apply on curMeisai */
      -- 1回目のループの場合、銘柄コード等を設定
      IF coalesce(mgrCd::text, '') = '' THEN
        mgrCd := trim(both recMeisai.gMgrCd);
        gnrbaraiKjt := trim(both recMeisai.gGnrbaraiKjt);
      END IF;
      --  銘柄コードまたは元利払期日が変わった場合、帳票ワークテーブルへ出力
      IF mgrCd != trim(both recMeisai.gMgrCd) OR
        gnrbaraiKjt != trim(both recMeisai.gGnrbaraiKjt) THEN
        --明細数カウントを行う
        seqNo := seqNo + 1;
        		-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := trim(both tsukaNm);	-- 通貨
		v_item.l_inItem003 := mgrCd;	-- 銘柄コード
		v_item.l_inItem004 := trim(both mgrRnm);	-- 銘柄略称
		v_item.l_inItem005 := rbrKij;	-- 回次数
		v_item.l_inItem006 := trim(both rbrKjtMd1);	-- 利払期日（１）
		v_item.l_inItem007 := trim(both rbrKjtMd2);	-- 利払期日（２）
		v_item.l_inItem008 := trim(both rbrKjtMd3);	-- 利払期日（３）
		v_item.l_inItem009 := trim(both rbrKjtMd4);	-- 利払期日（４）
		v_item.l_inItem010 := trim(both rbrKjtMd5);	-- 利払期日（５）
		v_item.l_inItem011 := trim(both rbrKjtMd6);	-- 利払期日（６）
		v_item.l_inItem012 := trim(both rbrKjtMd7);	-- 利払期日（７）
		v_item.l_inItem013 := trim(both rbrKjtMd8);	-- 利払期日（８）
		v_item.l_inItem014 := trim(both rbrKjtMd9);	-- 利払期日（９）
		v_item.l_inItem015 := trim(both rbrKjtMd10);	-- 利払期日（１０）
		v_item.l_inItem016 := trim(both rbrKjtMd11);	-- 利払期日（１１）
		v_item.l_inItem017 := trim(both rbrKjtMd12);	-- 利払期日（１２）
		v_item.l_inItem018 := pkDate.seirekiChangeSuppressNenGappi(trim(both hakkoYmd));	-- 発行日
		v_item.l_inItem019 := pkDate.seirekiChangeSuppressNenGappi(trim(both stRbrKjt));	-- 初回利払期日
		v_item.l_inItem020 := pkDate.seirekiChangeSuppressNenGappi(trim(both saisyuCyukiRbrKjt));	-- 最終中期利払期日
		v_item.l_inItem021 := pkDate.seirekiChangeSuppressNenGappi(trim(both fullshokanKjt));	-- 満期償還期日
		v_item.l_inItem022 := pkDate.seirekiChangeSuppressNenGappi(trim(both nyukinYmd));	-- 入金日
		v_item.l_inItem023 := ikkatuCyosyuKngk;	-- 一括徴収額
		v_item.l_inItem024 := ikkatuCyosyuZei;	-- 一括徴収額（内消費税）
		v_item.l_inItem025 := gnknShrTesuKngkSum;	-- 内元金支払手数料合計
		v_item.l_inItem026 := gnknShrTesuZeiSum;	-- 内元金支払手数料（内消費税）合計
		v_item.l_inItem027 := riknShrTesuKngkSum;	-- 利金支払手数料合計
		v_item.l_inItem028 := riknShrTesuZeiSum;	-- 利金支払手数料（内消費税）合計
		v_item.l_inItem029 := pkDate.seirekiChangeSuppressNenGappi(trim(both gnrbaraiKjt));	-- 元利払期日
		v_item.l_inItem030 := gnknShrTesuKngk;	-- 元金支払手数料
		v_item.l_inItem031 := gnknShrTesuZei;	-- 元金支払手数料（内消費税）
		v_item.l_inItem032 := riknShrTesuKngk;	-- 利金支払手数料
		v_item.l_inItem033 := riknShrTesuZei;	-- 利金支払手数料（内消費税）
		v_item.l_inItem034 := ruikeiKngk;	-- 累計額
		v_item.l_inItem035 := ruikeiZei;	-- 累計額（内消費税）
		v_item.l_inItem036 := zanzonKngk;	-- 残存額
		v_item.l_inItem037 := zanzonZei;	-- 残存額（内消費税）
		v_item.l_inItem038 := trim(both shrSumi);	-- 支払済
		v_item.l_inItem043 := gBunsho;	-- インボイス文章
		v_item.l_inItem044 := gInvoiceFlg;	-- インボイスオプションフラグ
		v_item.l_inItem039 := REPORT_ID;	-- 帳票ID
		v_item.l_inItem040 := fmtKngk;	-- 金額フォーマット
		v_item.l_inItem041 := fmtSzei;	-- 税金額フォーマット
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyo_Kbn,
			l_inSakuseiYmd	=> gyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> seqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
        -- 変数を初期化
        gnknShrTesuKngk := 0;
        gnknShrTesuZei := 0;
        riknShrTesuKngk := 0;
        riknShrTesuZei := 0;
      END IF;
      -- 銘柄コードが変わった場合、変数を初期化
      IF mgrCd != trim(both recMeisai.gMgrCd) THEN
        -- 各変数の初期化
        ruikeiKngk := 0;  -- 累計額
        ruikeiZei := 0;   -- 累計額（消費税）
        zanzonKngk := 0;  -- 残存額
        zanzonZei := 0;   -- 残存額（消費税）
      END IF;
      -- 各変数に値を設定
      mgrCd := trim(both recMeisai.gMgrCd);
      gnrbaraiKjt := trim(both recMeisai.gGnrbaraiKjt);
      tsukaNm := trim(both recMeisai.gTsukaNm);                      -- 通貨
      mgrRnm := trim(both recMeisai.gMgrRnm);                        -- 銘柄略称
      rbrKij := recMeisai.gRbrKij;                              -- 回次数
      rbrKjtMd1 := trim(both recMeisai.gRbrKjtMd1);                  -- 利払期日（１）
      rbrKjtMd2 := trim(both recMeisai.gRbrKjtMd2);                  -- 利払期日（２）
      rbrKjtMd3 := trim(both recMeisai.gRbrKjtMd3);                  -- 利払期日（３）
      rbrKjtMd4 := trim(both recMeisai.gRbrKjtMd4);                  -- 利払期日（４）
      rbrKjtMd5 := trim(both recMeisai.gRbrKjtMd5);                  -- 利払期日（５）
      rbrKjtMd6 := trim(both recMeisai.gRbrKjtMd6);                  -- 利払期日（６）
      rbrKjtMd7 := trim(both recMeisai.gRbrKjtMd7);                  -- 利払期日（７）
      rbrKjtMd8 := trim(both recMeisai.gRbrKjtMd8);                  -- 利払期日（８）
      rbrKjtMd9 := trim(both recMeisai.gRbrKjtMd9);                  -- 利払期日（９）
      rbrKjtMd10 := trim(both recMeisai.gRbrKjtMd10);                -- 利払期日（１０）
      rbrKjtMd11 := trim(both recMeisai.gRbrKjtMd11);                -- 利払期日（１１）
      rbrKjtMd12 := trim(both recMeisai.gRbrKjtMd12);                -- 利払期日（１２）
      hakkoYmd := trim(both recMeisai.gHakkoYmd);                    -- 発行日
      stRbrKjt := trim(both recMeisai.gStRbrKjt);                    -- 初回利払期日
      saisyuCyukiRbrKjt := trim(both recMeisai.gSaisyuCyukiRbrKjt);  -- 最終中期利払期日
      fullshokanKjt := trim(both recMeisai.gFullshokanKjt);          -- 満期償還期日
      nyukinYmd := trim(both recMeisai.gNyukinYmd);                  -- 入金日
      ikkatuCyosyuKngk := recMeisai.gIkkatuCyosyuKngk;          -- 一括徴収額
      ikkatuCyosyuZei := recMeisai.gIkkatuCyosyuZei;            -- 一括徴収額（内消費税）
      gnknShrTesuKngkSum := recMeisai.gGnknShrTesuKngkSum;      -- 内元金支払手数料合計
      gnknShrTesuZeiSum := recMeisai.gGnknShrTesuZeiSum;        -- 内元金支払手数料（内消費税）合計
      riknShrTesuKngkSum := recMeisai.gRiknShrTesuKngkSum;      -- 利金支払手数料合計
      riknShrTesuZeiSum := recMeisai.gRiknShrTesuZeiSum;        -- 利金支払手数料（内消費税）合計
      gnknShrTesuKngk := (gnknShrTesuKngk + recMeisai.gGnknShrTesuKngk);  -- 元金支払手数料
      gnknShrTesuZei := (gnknShrTesuZei + recMeisai.gGnknShrTesuZei);     -- 元金支払手数料（内消費税）
      riknShrTesuKngk := (riknShrTesuKngk + recMeisai.gRiknShrTesuKngk);  -- 利金支払手数料
      riknShrTesuZei := (riknShrTesuZei + recMeisai.gRiknShrTesuZei);     -- 利金支払手数料（内消費税）
      shrSumi := trim(both recMeisai.gShrSumi);                      -- 支払済
      -- 累計額計算（累計額＋元金支払手数料＋利金支払手数料）
      ruikeiKngk := (ruikeiKngk + recMeisai.gGnknShrTesuKngk + recMeisai.gRiknShrTesuKngk);
      -- 累計額（消費税）計算（累計額（消費税）＋元金支払手数料（消費税）＋利金支払手数料（消費税））
      ruikeiZei := (ruikeiZei + recMeisai.gGnknShrTesuZei + recMeisai.gRiknShrTesuZei);
      -- 残存額計算（一括徴収額−累計額）
      zanzonKngk := (recMeisai.gIkkatuCyosyuKngk - ruikeiKngk);
      -- 残存額（消費税）計算（一括徴収額（消費税）−累計額（消費税））
      zanzonZei := (recMeisai.gIkkatuCyosyuZei - ruikeiZei);
      -- 書式フォーマットの設定
      IF trim(both trim(both recMeisai.gTsukaCd)) = 'JPY' THEN
        -- 円
        fmtKngk := FMT_KNGK_J;    -- 金額
        fmtSzei := FMT_SZEI_J;    -- 消費税
      ELSE
        -- 外貨
        fmtKngk := FMT_KNGK_F;    -- 金額
        fmtSzei := FMT_SZEI_F;    -- 消費税
      END IF;
      -- 日付西暦編集
      -- ローカル変数．発行日（西暦）
      IF (trim(both hakkoYmd) IS NOT NULL AND (trim(both hakkoYmd))::text <> '') THEN
          gSrkHakkoYmd := pkDate.seirekiChangeSuppressNenGappi(trim(both hakkoYmd));
      END IF;
      -- ローカル変数．初回利払期日（西暦）
      IF (trim(both stRbrKjt) IS NOT NULL AND (trim(both stRbrKjt))::text <> '') THEN
          gSrkStRbrKjt := pkDate.seirekiChangeSuppressNenGappi(trim(both stRbrKjt));
      END IF;
      -- ローカル変数．最終中期利払期日（西暦）
      IF (trim(both saisyuCyukiRbrKjt) IS NOT NULL AND (trim(both saisyuCyukiRbrKjt))::text <> '') THEN
          gSrkSaisyuCyukiRbrKjt := pkDate.seirekiChangeSuppressNenGappi(trim(both saisyuCyukiRbrKjt));
      END IF;
      -- ローカル変数．満期償還期日（西暦）
      IF (trim(both fullshokanKjt) IS NOT NULL AND (trim(both fullshokanKjt))::text <> '') THEN
          gSrkFullshokanKjt := pkDate.seirekiChangeSuppressNenGappi(trim(both fullshokanKjt));
      END IF;
      -- ローカル変数．入金日（西暦）
      IF (trim(both nyukinYmd) IS NOT NULL AND (trim(both nyukinYmd))::text <> '') THEN
          gSrkNyukinYmd := pkDate.seirekiChangeSuppressNenGappi(trim(both nyukinYmd));
      END IF;
      -- ローカル変数．元利払期日（西暦）
      IF (trim(both gnrbaraiKjt) IS NOT NULL AND (trim(both gnrbaraiKjt))::text <> '') THEN
          gSrkGnrbaraiKjt := pkDate.seirekiChangeSuppressNenGappi(trim(both gnrbaraiKjt));
      END IF;
    END LOOP;
    IF coalesce(mgrCd::text, '') = '' THEN
      -- [明細データ抽出]で対象データ無しの場合、「対象データなし」を帳票ワークテーブルへ出力
      		-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem039 := REPORT_ID;	-- 帳票ID
		v_item.l_inItem042 := MSG_NODATA;	-- 対象データ無し
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyo_Kbn,
			l_inSakuseiYmd	=> gyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> 1,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
      extra_param := RTN_NODATA;
      RETURN;
    ELSE
      -- 抽出した結果を帳票ワークテーブルへ出力
      seqNo := seqNo + 1;
      		-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := trim(both tsukaNm);	-- 通貨
		v_item.l_inItem003 := mgrCd;	-- 銘柄コード
		v_item.l_inItem004 := trim(both mgrRnm);	-- 銘柄略称
		v_item.l_inItem005 := rbrKij;	-- 回次数
		v_item.l_inItem006 := trim(both rbrKjtMd1);	-- 利払期日（１）
		v_item.l_inItem007 := trim(both rbrKjtMd2);	-- 利払期日（２）
		v_item.l_inItem008 := trim(both rbrKjtMd3);	-- 利払期日（３）
		v_item.l_inItem009 := trim(both rbrKjtMd4);	-- 利払期日（４）
		v_item.l_inItem010 := trim(both rbrKjtMd5);	-- 利払期日（５）
		v_item.l_inItem011 := trim(both rbrKjtMd6);	-- 利払期日（６）
		v_item.l_inItem012 := trim(both rbrKjtMd7);	-- 利払期日（７）
		v_item.l_inItem013 := trim(both rbrKjtMd8);	-- 利払期日（８）
		v_item.l_inItem014 := trim(both rbrKjtMd9);	-- 利払期日（９）
		v_item.l_inItem015 := trim(both rbrKjtMd10);	-- 利払期日（１０）
		v_item.l_inItem016 := trim(both rbrKjtMd11);	-- 利払期日（１１）
		v_item.l_inItem017 := trim(both rbrKjtMd12);	-- 利払期日（１２）
		v_item.l_inItem018 := gSrkHakkoYmd;	-- 発行日
		v_item.l_inItem019 := gSrkStRbrKjt;	-- 初回利払期日
		v_item.l_inItem020 := gSrkSaisyuCyukiRbrKjt;	-- 最終中期利払期日
		v_item.l_inItem021 := gSrkFullshokanKjt;	-- 満期償還期日
		v_item.l_inItem022 := gSrkNyukinYmd;	-- 入金日
		v_item.l_inItem023 := ikkatuCyosyuKngk;	-- 一括徴収額
		v_item.l_inItem024 := ikkatuCyosyuZei;	-- 一括徴収額（内消費税）
		v_item.l_inItem025 := gnknShrTesuKngkSum;	-- 内元金支払手数料合計
		v_item.l_inItem026 := gnknShrTesuZeiSum;	-- 内元金支払手数料（内消費税）合計
		v_item.l_inItem027 := riknShrTesuKngkSum;	-- 利金支払手数料合計
		v_item.l_inItem028 := riknShrTesuZeiSum;	-- 利金支払手数料（内消費税）合計
		v_item.l_inItem029 := gSrkGnrbaraiKjt;	-- 元利払期日
		v_item.l_inItem030 := gnknShrTesuKngk;	-- 元金支払手数料
		v_item.l_inItem031 := gnknShrTesuZei;	-- 元金支払手数料（内消費税）
		v_item.l_inItem032 := riknShrTesuKngk;	-- 利金支払手数料
		v_item.l_inItem033 := riknShrTesuZei;	-- 利金支払手数料（内消費税）
		v_item.l_inItem034 := ruikeiKngk;	-- 累計額
		v_item.l_inItem035 := ruikeiZei;	-- 累計額（内消費税）
		v_item.l_inItem036 := zanzonKngk;	-- 残存額
		v_item.l_inItem037 := zanzonZei;	-- 残存額（内消費税）
		v_item.l_inItem038 := trim(both shrSumi);	-- 支払済
		v_item.l_inItem043 := gBunsho;	-- インボイス文章
		v_item.l_inItem044 := gInvoiceFlg;	-- インボイスオプションフラグ
		v_item.l_inItem039 := REPORT_ID;	-- 帳票ID
		v_item.l_inItem040 := fmtKngk;	-- 金額フォーマット
		v_item.l_inItem041 := fmtSzei;	-- 税金額フォーマット
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyo_Kbn,
			l_inSakuseiYmd	=> gyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> seqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
    END IF;
    extra_param := RTN_OK;
    RETURN;
  EXCEPTION
      WHEN OTHERS THEN
        CALL pkLog.fatal('ECM701', PROGRAM_ID, 'SQLCODE:' || SQLSTATE);
        CALL pkLog.fatal('ECM701', PROGRAM_ID, 'SQLERRM:' || SQLERRM);
        l_outErrMsg := SQLERRM;
        extra_param := RTN_FATAL;
        RETURN;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfip931500111_01 ( l_inUserId text , l_inItakuKaishaCd text , l_inHakkoTaiCd text , l_inMeigaraCode text , l_inIsinCd text , l_inKijun_Ym text , l_inChohyo_Kbn text , l_outErrMsg OUT text , OUT extra_param numeric) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfip931500111_01_createsql (
    IN p_inItakuKaishaCd text,
    IN p_inHakkoTaiCd text,
    IN p_inMeigaraCode text,
    IN p_inIsinCd text,
    IN p_inKijun_Ym text,
    IN p_gyomuYmd char(8),
    OUT p_gSQL varchar
) AS $body$
DECLARE
    l_inItakuKaishaCd text := p_inItakuKaishaCd;
    l_inHakkoTaiCd text := p_inHakkoTaiCd;
    l_inMeigaraCode text := p_inMeigaraCode;
    l_inIsinCd text := p_inIsinCd;
    l_inKijun_Ym text := p_inKijun_Ym;
    gyomuYmd char(8) := p_gyomuYmd;
    gSql varchar := '';
BEGIN
-- 変数を初期化
gSql := '';
-- 変数にSQLクエリ文を代入
gSql := 'SELECT '
		||'  ViewSELECT.TSUKA_CD AS TSUKA_CD, '
		||'  ViewSELECT.TSUKA_NM AS TSUKA_NM, '
		||'  ViewSELECT.MGR_CD AS MGR_CD, '
		||'  ViewSELECT.MGR_RNM AS MGR_RNM, '
		||'  ViewSELECT.KAIJI AS KAIJI, '
		||'  ViewSELECT.RBR_KJT_MD1 AS RBR_KJT_MD1, '						-- 利払期日（MD）（１）
		||'  ViewSELECT.RBR_KJT_MD2 AS RBR_KJT_MD2, '						-- 利払期日（MD）（２）
		||'  ViewSELECT.RBR_KJT_MD3 AS RBR_KJT_MD3, '						-- 利払期日（MD）（３）
		||'  ViewSELECT.RBR_KJT_MD4 AS RBR_KJT_MD4, '						-- 利払期日（MD）（４）
		||'  ViewSELECT.RBR_KJT_MD5 AS RBR_KJT_MD5, '						-- 利払期日（MD）（５）
		||'  ViewSELECT.RBR_KJT_MD6 AS RBR_KJT_MD6, '						-- 利払期日（MD）（６）
		||'  ViewSELECT.RBR_KJT_MD7 AS RBR_KJT_MD7, '						-- 利払期日（MD）（７）
		||'  ViewSELECT.RBR_KJT_MD8 AS RBR_KJT_MD8, '						-- 利払期日（MD）（８）
		||'  ViewSELECT.RBR_KJT_MD9 AS RBR_KJT_MD9, '						-- 利払期日（MD）（９）
		||'  ViewSELECT.RBR_KJT_MD10 AS RBR_KJT_MD10, '						-- 利払期日（MD）（１０）
		||'  ViewSELECT.RBR_KJT_MD11 AS RBR_KJT_MD11, '						-- 利払期日（MD）（１１）
		||'  ViewSELECT.RBR_KJT_MD12 AS RBR_KJT_MD12, '						-- 利払期日（MD）（１２）
		||'  ViewSELECT.HAKKO_YMD AS HAKKO_YMD, '							-- 発行年月日
		||'  ViewSELECT.ST_RBR_KJT AS ST_RBR_KJT, '							-- 初回利払期日
		||'  ViewSELECT.SAISYU_CYUKI_RBR_KJT AS SAISYU_CYUKI_RBR_KJT, '		-- 最終中期利払期日
		||'  ViewSELECT.FULLSHOKAN_KJT AS FULLSHOKAN_KJT, '					-- 満期償還期日
		||'  ViewSELECT.NYUKIN_YMD AS NYUKIN_YMD, '							-- 入金日
		||'  (SELECT COALESCE(SUM(V1.KKN_NYUKIN_KNGK),0) FROM MGR_KIHON_VIEW_UPF V1 '
      ||'   WHERE ViewSELECT.ITAKU_KAISHA_CD = V1.ITAKU_KAISHA_CD '
      ||'     AND ViewSELECT.MGR_CD = V1.MGR_CD) AS IKKATU_CYOSYU_KNGK, ' -- 一括徴収額
		||'  (SELECT COALESCE(SUM(V1.KKN_NYUKIN_KNGK),0) FROM MGR_KIHON_VIEW_UPF V1 '
      ||'   WHERE ViewSELECT.ITAKU_KAISHA_CD = V1.ITAKU_KAISHA_CD '
      ||'     AND ViewSELECT.MGR_CD = V1.MGR_CD '
      ||'     AND V1.KKN_IDO_KBN IN (''13'',''23'')) AS IKKATU_CYOSYU_KNGK, ' -- 一括徴収額（内消費税）
		||'  ViewSELECT.GNRBARAI_KJT AS GNRBARAI_KJT, '                   -- 元利払期日
		||'  COALESCE(SUM(ViewSELECT.GNKN_SHR_TESU_KNGK),0) AS GNKN_SHR_TESU_KNGK, '		-- 内元金支払手数料
		||'  COALESCE(SUM(ViewSELECT.GNKN_SHR_TESU_ZEI),0) AS GNKN_SHR_TESU_ZEI, '		-- 内元金支払手数料（内消費税）
		||'  COALESCE(SUM(ViewSELECT.RIKN_SHR_TESU_KNGK),0) AS RIKN_SHR_TESU_KNGK, '		-- 利金支払手数料
		||'  COALESCE(SUM(ViewSELECT.RIKN_SHR_TESU_ZEI),0) AS RIKN_SHR_TESU_ZEI, '		-- 利金支払手数料（内消費税）
      ||'  (SELECT COALESCE(SUM(V1.KKN_NYUKIN_KNGK),0) FROM MGR_KIHON_VIEW_UPF V1 '
      ||'   WHERE ViewSELECT.ITAKU_KAISHA_CD = V1.ITAKU_KAISHA_CD '
      ||'     AND ViewSELECT.MGR_CD = V1.MGR_CD '
      ||'     AND V1.KKN_IDO_KBN IN (''12'',''13'')) AS GNKN_SHR_TESU_KNGK_SUM, ' -- 元金支払手数料合計
      ||'  (SELECT COALESCE(SUM(V1.KKN_NYUKIN_KNGK),0) FROM MGR_KIHON_VIEW_UPF V1 '
      ||'   WHERE ViewSELECT.ITAKU_KAISHA_CD = V1.ITAKU_KAISHA_CD '
      ||'     AND ViewSELECT.MGR_CD = V1.MGR_CD '
      ||'     AND V1.KKN_IDO_KBN IN (''13'')) AS GNKN_SHR_TESU_ZEI_SUM, ' -- 元金支払手数料（消費税）合計
      ||'  (SELECT COALESCE(SUM(V1.KKN_NYUKIN_KNGK),0) FROM MGR_KIHON_VIEW_UPF V1 '
      ||'   WHERE ViewSELECT.ITAKU_KAISHA_CD = V1.ITAKU_KAISHA_CD '
      ||'     AND ViewSELECT.MGR_CD = V1.MGR_CD '
      ||'     AND V1.KKN_IDO_KBN IN (''22'',''23'')) AS RIKN_SHR_TESU_KNGK_SUM, ' -- 利金支払手数料合計
      ||'  (SELECT COALESCE(SUM(V1.KKN_NYUKIN_KNGK),0) FROM MGR_KIHON_VIEW_UPF V1 '
      ||'   WHERE ViewSELECT.ITAKU_KAISHA_CD = V1.ITAKU_KAISHA_CD '
      ||'     AND ViewSELECT.MGR_CD = V1.MGR_CD '
      ||'     AND V1.KKN_IDO_KBN IN (''23'')) AS RIKN_SHR_TESU_ZEI_SUM, ' -- 利金支払手数料（消費税）合計
		||'  ViewSELECT.SHR_SUMI AS SHR_SUMI '								-- 支払済
		||' FROM '
		||'  ( '
		||'    SELECT '
		||'      VMG1.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD, '
		||'      VMG1.HKT_CD AS HKT_CD, '
		||'      VMG1.MGR_CD AS MGR_CD, '
		||'      VMG1.MGR_RNM AS MGR_RNM, '
		||'      VMG1.ISIN_CD AS ISIN_CD, '
		||'      VMG1.TSUKA_CD AS TSUKA_CD, '
		||'      VMG1.TSUKA_NM AS TSUKA_NM, '
		||'      (CASE WHEN VMG1.GEN_FURI_KBN = ''0'' AND TRIM(VMG1.ISIN_CD) IS NULL '  --（現登債）
		||'        THEN (SELECT MAX(KIJ_GT.KAIJI) FROM B_MGR_RBRKIJ KIJ_GT '
		||'             WHERE VMG1.ITAKU_KAISHA_CD = KIJ_GT.ITAKU_KAISHA_CD '
		||'               AND VMG1.MGR_CD = KIJ_GT.MGR_CD) '
		||'        WHEN VMG1.GEN_FURI_KBN = ''0'' '                                     --（現登債:並存）
		||'        THEN (SELECT MAX(KIJ_GT.KAIJI) FROM B_MGR_RBRKIJ KIJ_GT '
		||'             WHERE VMG1.ITAKU_KAISHA_CD = KIJ_GT.ITAKU_KAISHA_CD '
		||'               AND KIJ_GT.MGR_CD = ( '
		||'                 SELECT DISTINCT MG01.MGR_CD FROM B_MGR_KIHON MG01 '
		||'                 WHERE MG01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD '
		||'                    AND MG01.ISIN_CD = VMG1.ISIN_CD)) '
		||'        ELSE (SELECT MAX(KIJ_FR.KAIJI) FROM MGR_RBRKIJ KIJ_FR '              -- (振替債)
		||'             WHERE VMG1.ITAKU_KAISHA_CD = KIJ_FR.ITAKU_KAISHA_CD '
		||'               AND VMG1.MGR_CD = KIJ_FR.MGR_CD) '
		||'      END) AS KAIJI, '
		||'      VMG1.RBR_KJT_MD1 AS RBR_KJT_MD1, '	--利払期日（MD）（１）
		||'      VMG1.RBR_KJT_MD2 AS RBR_KJT_MD2, '	--利払期日（MD）（２）
		||'      VMG1.RBR_KJT_MD3 AS RBR_KJT_MD3, '	--利払期日（MD）（３）
		||'      VMG1.RBR_KJT_MD4 AS RBR_KJT_MD4, '	--利払期日（MD）（４）
		||'      VMG1.RBR_KJT_MD5 AS RBR_KJT_MD5, '	--利払期日（MD）（５）
		||'      VMG1.RBR_KJT_MD6 AS RBR_KJT_MD6, '	--利払期日（MD）（６）
		||'      VMG1.RBR_KJT_MD7 AS RBR_KJT_MD7, '	--利払期日（MD）（７）
		||'      VMG1.RBR_KJT_MD8 AS RBR_KJT_MD8, '	--利払期日（MD）（８）
		||'      VMG1.RBR_KJT_MD9 AS RBR_KJT_MD9, '	--利払期日（MD）（９）
		||'      VMG1.RBR_KJT_MD10 AS RBR_KJT_MD10, '	--利払期日（MD）（１０）
		||'      VMG1.RBR_KJT_MD11 AS RBR_KJT_MD11, '	--利払期日（MD）（１１）
		||'      VMG1.RBR_KJT_MD12 AS RBR_KJT_MD12, '	--利払期日（MD）（１２）
		||'      VMG1.HAKKO_YMD AS HAKKO_YMD, '		--発行年月日
		||'      VMG1.ST_RBR_KJT AS ST_RBR_KJT, '	--初回利払期日
		||'      (CASE WHEN VMG1.GEN_FURI_KBN = ''0'' AND TRIM(VMG1.ISIN_CD) IS NULL '	--（現登債）
		||'        THEN (SELECT RKJ_GT.RBR_KJT FROM B_MGR_RBRKIJ RKJ_GT  '
		||'               WHERE  '
		||'                   VMG1.ITAKU_KAISHA_CD = RKJ_GT.ITAKU_KAISHA_CD '
		||'               AND VMG1.MGR_CD = RKJ_GT.MGR_CD '
		||'               AND RKJ_GT.KAIJI = ( '
		||'                     SELECT MAX(B.KAIJI)-1  '
		||'                     FROM B_MGR_RBRKIJ B '
		||'                     WHERE RKJ_GT.ITAKU_KAISHA_CD = B.ITAKU_KAISHA_CD '
		||'                       AND RKJ_GT.MGR_CD = B.MGR_CD '
		||'                   )) '
		||'        WHEN VMG1.GEN_FURI_KBN = ''0'' '                                     --（現登債:並存）
		||'        THEN (SELECT RKJ_GT.RBR_KJT FROM B_MGR_RBRKIJ RKJ_GT  '
		||'               WHERE  '
		||'                   VMG1.ITAKU_KAISHA_CD = RKJ_GT.ITAKU_KAISHA_CD '
		||'               AND RKJ_GT.MGR_CD = ( '
		||'                 SELECT DISTINCT MG01.MGR_CD FROM B_MGR_KIHON MG01 '
		||'                 WHERE MG01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD '
		||'                   AND MG01.ISIN_CD = VMG1.ISIN_CD) '
		||'               AND RKJ_GT.KAIJI = ( '
		||'                     SELECT MAX(B.KAIJI)-1  '
		||'                     FROM B_MGR_RBRKIJ B '
		||'                     WHERE RKJ_GT.ITAKU_KAISHA_CD = B.ITAKU_KAISHA_CD '
		||'                       AND RKJ_GT.MGR_CD = B.MGR_CD '
		||'                   )) '
		||'        ELSE (SELECT RKJ_FR.RBR_KJT FROM MGR_RBRKIJ RKJ_FR '                 -- (振替債)
		||'               WHERE  '
		||'                     VMG1.ITAKU_KAISHA_CD = RKJ_FR.ITAKU_KAISHA_CD '
		||'                 AND VMG1.MGR_CD = RKJ_FR.MGR_CD '
		||'                 AND RKJ_FR.KAIJI = ( '
		||'                      SELECT MAX(D.KAIJI)-1  '
		||'                      FROM MGR_RBRKIJ D '
		||'                      WHERE RKJ_FR.ITAKU_KAISHA_CD = D.ITAKU_KAISHA_CD '
		||'                        AND RKJ_FR.MGR_CD = D.MGR_CD '
		||'                   )) '
		||'      END) AS SAISYU_CYUKI_RBR_KJT, '				--最終中期利払期日
		||'      VMG1.FULLSHOKAN_KJT AS FULLSHOKAN_KJT, '	--満期償還期日
		||'      VMG1.IDO_YMD AS NYUKIN_YMD, '				-- 入金日
		||'      VMG1.RBR_KJT AS GNRBARAI_KJT, '
		||'      (CASE WHEN VMG1.KKN_IDO_KBN IN (''12'',''13'') '
		||'        THEN VMG1.KKN_NYUKIN_KNGK '
		||'        ELSE 0 '
		||'      END) AS GNKN_SHR_TESU_KNGK, '	--元金支払手数料
		||'      (CASE WHEN VMG1.KKN_IDO_KBN IN (''13'') '
		||'        THEN VMG1.KKN_NYUKIN_KNGK '
		||'        ELSE 0 '
		||'      END) AS GNKN_SHR_TESU_ZEI, '		--元金支払手数料（内消費税）
		||'      (CASE WHEN VMG1.KKN_IDO_KBN IN (''22'',''23'') '
		||'        THEN VMG1.KKN_NYUKIN_KNGK '
		||'        ELSE 0 '
		||'      END) AS RIKN_SHR_TESU_KNGK, '	--利金支払手数料
		||'      (CASE WHEN VMG1.KKN_IDO_KBN IN (''23'') '
		||'        THEN VMG1.KKN_NYUKIN_KNGK '
		||'        ELSE 0 '
		||'      END) AS RIKN_SHR_TESU_ZEI, '		--利金支払手数料（内消費税）
		||'      (CASE  '
		||'        WHEN UPF.KEIJO_STS_KBN = ''1'' '	--(計上済)(コード種別:214)
		||'             AND TRIM(UPF.KEIJO_YMD) IS NOT NULL '
		||'             AND TO_DATE(UPF.KEIJO_YMD, ''YYYYMMDD'') <= TO_DATE(''' || gyomuYmd || ''', ''YYYYMMDD'') '
		||'             THEN ''＊'' '  --通常時
		||'        WHEN VMG1.GEN_FURI_KBN = ''0'' '                                     --（現登債）
		||'             AND TRIM(VMG1.ISIN_CD) IS NULL '
		||'             AND EXISTS ( '
		||'               SELECT 1 FROM B_KIKIN_HENREI HNR_GT '
		||'               WHERE VMG1.ITAKU_KAISHA_CD = HNR_GT.ITAKU_KAISHA_CD '
		||'                 AND VMG1.MGR_CD = HNR_GT.MGR_CD '
		||'                 AND VMG1.TSUKA_CD = HNR_GT.TSUKA_CD '
		||'                 AND VMG1.RBR_KJT = HNR_GT.RBR_KJT ';
IF (l_inKijun_Ym IS NOT NULL AND l_inKijun_Ym::text <> '') THEN
  gSql := gSql || '       AND TO_DATE(VMG1.RBR_KJT, ''YYYYMMDD'') <= oracle.last_day(TO_DATE(''' || l_inKijun_Ym || '01' || ''', ''YYYYMMDD'')) ';
END IF;
  gSql := gSql || ') '
		||'             THEN ''＊'' '  --返戻（現登債）時
		||'        WHEN VMG1.GEN_FURI_KBN = ''0'' '                                     --（現登債:並存）
		||'             AND EXISTS ( '
		||'               SELECT 1 FROM B_KIKIN_HENREI HNR_GT '
		||'               WHERE VMG1.ITAKU_KAISHA_CD = HNR_GT.ITAKU_KAISHA_CD '
		||'                 AND VMG1.MGR_CD = ( '
		||'                   SELECT DISTINCT MG01.MGR_CD FROM B_MGR_KIHON MG01 '
		||'                   WHERE MG01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD '
		||'                     AND MG01.ISIN_CD = VMG1.ISIN_CD) '
		||'                 AND VMG1.TSUKA_CD = HNR_GT.TSUKA_CD '
		||'                 AND VMG1.RBR_KJT = HNR_GT.RBR_KJT ';
IF (l_inKijun_Ym IS NOT NULL AND l_inKijun_Ym::text <> '') THEN
  gSql := gSql || '       AND TO_DATE(VMG1.RBR_KJT, ''YYYYMMDD'') <= oracle.last_day(TO_DATE(''' || l_inKijun_Ym || '01' || ''', ''YYYYMMDD'')) ';
END IF;
  gSql := gSql || ') '
		||'             THEN ''＊'' '  --返戻（現登債）時
		||'        WHEN VMG1.GEN_FURI_KBN = ''1'' '	                                    --（振替債）
		||'             AND EXISTS ( '
		||'               SELECT 1 FROM KIKIN_HENREI HNR_FR '
		||'               WHERE VMG1.ITAKU_KAISHA_CD = HNR_FR.ITAKU_KAISHA_CD '
		||'                 AND VMG1.MGR_CD = HNR_FR.MGR_CD '
		||'                 AND VMG1.TSUKA_CD = HNR_FR.TSUKA_CD '
		||'                 AND VMG1.RBR_KJT = HNR_FR.RBR_KJT ';
IF (l_inKijun_Ym IS NOT NULL AND l_inKijun_Ym::text <> '') THEN
  gSql := gSql || '       AND TO_DATE(VMG1.RBR_KJT, ''YYYYMMDD'') <= oracle.last_day(TO_DATE(''' || l_inKijun_Ym || '01' || ''', ''YYYYMMDD'')) ';
END IF;
  gSql := gSql || ') '
		||'             THEN ''＊'' '  --返戻（振替債）時
		||'        ELSE '''''
		||'      END) AS SHR_SUMI '	-- 支払済
		||'  FROM  '
		||'      MGR_KIHON_VIEW_UPF VMG1 '						-- 銘柄基本アップフロントView
		||'      LEFT JOIN UPFR_TESURYO_KEIJYO UPF '						-- アップフロント手数料勘定計上
		||'        ON VMG1.ITAKU_KAISHA_CD = UPF.ITAKU_KAISHA_CD '
		||'       AND VMG1.MGR_CD = UPF.MGR_CD '
		||'       AND VMG1.RBR_KJT = UPF.GNRBARAI_KJT '
		||'       AND VMG1.GEN_FURI_KBN = UPF.GEN_FURI_KBN '
		||'    WHERE  '
		||'      VMG1.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''''
		||'  ) ViewSELECT ';
  IF (l_inHakkoTaiCd IS NOT NULL AND l_inHakkoTaiCd::text <> '') OR
     (l_inMeigaraCode IS NOT NULL AND l_inMeigaraCode::text <> '') OR
     (l_inIsinCd IS NOT NULL AND l_inIsinCd::text <> '') OR
     (l_inKijun_Ym IS NOT NULL AND l_inKijun_Ym::text <> '')
  THEN
     gSql := gSql || ' WHERE 1=1 ';
     -- 入力パラメータ条件 発行体コード
     IF (l_inHakkoTaiCd IS NOT NULL AND l_inHakkoTaiCd::text <> '') THEN
       gSql := gSql || ' AND ViewSELECT.HKT_CD = ''' || l_inHakkoTaiCd || '''';
     END IF;
     -- 入力パラメータ条件 銘柄コード
     IF (l_inMeigaraCode IS NOT NULL AND l_inMeigaraCode::text <> '') THEN
       gSql := gSql || ' AND  ViewSELECT.MGR_CD = ''' || l_inMeigaraCode || '''';
     END IF;
     -- 入力パラメータ条件 ＩＳＩＮコード
     IF (l_inIsinCd IS NOT NULL AND l_inIsinCd::text <> '') THEN
       gSql := gSql || ' AND ViewSELECT.ISIN_CD =  ''' || l_inIsinCd || '''';
     END IF;
     -- 入力パラメータ条件 基準年月
     IF (l_inKijun_Ym IS NOT NULL AND l_inKijun_Ym::text <> '') THEN
       gSql := gSql || ' AND ViewSELECT.MGR_CD IN ( '
          || ' SELECT DISTINCT MGR_CD FROM MGR_KIHON_VIEW_UPF V2 '
          || ' WHERE SUBSTR(COALESCE(V2.RBR_KJT,''''),1,6) = ''' || l_inKijun_Ym || ''''
          || '   AND V2.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''') ';
     END IF;
  END IF;
  gSql := gSql || ' GROUP BY '
		||'   ViewSELECT.ITAKU_KAISHA_CD, '
		||'   ViewSELECT.HKT_CD, '
		||'   ViewSELECT.MGR_CD, '
		||'   ViewSELECT.MGR_RNM, '
		||'   ViewSELECT.ISIN_CD, '
		||'   ViewSELECT.TSUKA_CD, '
		||'   ViewSELECT.TSUKA_NM, '
		||'   ViewSELECT.KAIJI, '
		||'   ViewSELECT.RBR_KJT_MD1, '			-- 利払期日（MD）（１）
		||'   ViewSELECT.RBR_KJT_MD2, '			-- 利払期日（MD）（２）
		||'   ViewSELECT.RBR_KJT_MD3, '			-- 利払期日（MD）（３）
		||'   ViewSELECT.RBR_KJT_MD4, '			-- 利払期日（MD）（４）
		||'   ViewSELECT.RBR_KJT_MD5, '			-- 利払期日（MD）（５）
		||'   ViewSELECT.RBR_KJT_MD6, '			-- 利払期日（MD）（６）
		||'   ViewSELECT.RBR_KJT_MD7, '			-- 利払期日（MD）（７）
		||'   ViewSELECT.RBR_KJT_MD8, '			-- 利払期日（MD）（８）
		||'   ViewSELECT.RBR_KJT_MD9, '			-- 利払期日（MD）（９）
		||'   ViewSELECT.RBR_KJT_MD10, '			-- 利払期日（MD）（１０）
		||'   ViewSELECT.RBR_KJT_MD11, '			-- 利払期日（MD）（１１）
		||'   ViewSELECT.RBR_KJT_MD12, '			-- 利払期日（MD）（１２）
		||'   ViewSELECT.HAKKO_YMD, '				-- 発行年月日
		||'   ViewSELECT.ST_RBR_KJT, '			-- 初回利払期日
		||'   ViewSELECT.SAISYU_CYUKI_RBR_KJT, '	-- 最終中期利払期日
		||'   ViewSELECT.FULLSHOKAN_KJT, '		-- 満期償還期日
		||'   ViewSELECT.NYUKIN_YMD, '			-- 入金日
		||'   ViewSELECT.GNRBARAI_KJT, '			-- 元利払期日
		||'   ViewSELECT.SHR_SUMI ';				-- 支払済
  gSql := gSql || ' ORDER BY '
		||'   ViewSELECT.ITAKU_KAISHA_CD, '
		||'   ViewSELECT.MGR_CD, '
		||'   ViewSELECT.GNRBARAI_KJT ';
    p_gSQL := gSql;
 	EXCEPTION
WHEN OTHERS THEN
	RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfip931500111_01_createsql () FROM PUBLIC;
