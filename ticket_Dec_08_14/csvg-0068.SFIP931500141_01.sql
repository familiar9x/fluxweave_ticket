


DROP TYPE IF EXISTS sfip931500141_01_type_record;
CREATE TYPE sfip931500141_01_type_record AS (
    gTsukaCd            char(3)                               -- 通貨コード
  , gTsukaNm            char(3)                               -- 通貨名称
  , gHktCd              char(6)                              -- 発行体コード
  , gMgrCd              varchar(13)                              -- 銘柄コード
  , gMgrRnm             varchar(44)                             -- 銘柄略称
  , gIsinCd             char(12)                             -- ＩＳＩＮコード
  , gGnrbaraiKjt        char(8)              -- 元利払期日
  , gFurikaeKngk        decimal(16,2)              -- 仮受金からの振替金額（税込）
  , gFurikaeZei         decimal(16,2)              -- 仮受金からの振替消費税額
  , gUkeSouteiKngk      decimal(14,2)     -- 発行体からの受入想定金額（税込）
  , gUkeSouteiZei       decimal(12,2) -- 発行体からの受入想定消費税額
  , gHktHnrKngk         numeric                                              -- 発行体への返戻金額
  , gHktHnrZei          numeric                                              -- 発行体への返戻金額（消費税）
  , gFurikaeYmd         char(8)                 -- 仮受金からの振替日
  , gIsUpfKeijo         varchar(1)                                        -- アップフロント手数料勘定計上フラグ
  , gGenFuriKbn         varchar(1)                                        -- 現登振替区分
  , gGnrKbn             varchar(1)                                        -- 元利区分
  );


CREATE OR REPLACE FUNCTION sfip931500141_01 ( l_inUserId text        -- ユーザID
 , l_inItakuKaishaCd text -- 委託会社コード
 , l_inMeigaraCode text   -- 銘柄コード
 , l_inIsinCd text        -- ＩＳＩＮコード
 , l_inKijun_Ym text      -- 基準年月
 , l_inKeijo_Ymd text     -- 収益計上日
 , l_inChohyo_Kbn text    -- 帳票区分
 , l_outErrMsg OUT text      -- エラーコメント
 , OUT extra_param numeric) RETURNS record AS $body$
DECLARE

--********************************************************************************************************************
-- * アップフロント分伝票起票シート（返戻分）
-- * アップフロント分伝票起票シート（返戻分）帳票データを設定。
-- *
-- * @author	ASK
-- *
-- * @version $Revision: 1.0 $
-- *
-- * @param	l_inUserId			  ユーザＩＤ
-- * @param	l_inItakuKaishaCd	委託会社コード
-- * @param	l_inMeigaraCode		銘柄コード
-- * @param	l_inIsinCd			ＩＳＩＮコード
-- * @param	l_inKijun_Ym			基準年月
-- * @param	l_inKeijo_Ymd			収益計上日
-- * @param	l_inChohyo_Kbn		帳票区分
-- * @param	l_outErrMsg		    エラーコメント
-- * @return	returnCd			リターンコード
-- ********************************************************************************************************************
--====================================================================
--					デバッグ機能										  
--====================================================================
  DEBUG  numeric(1)  := 1;
--==============================================================================
--          定数定義                                                            
--==============================================================================
  RTN_OK        CONSTANT integer  := 0;                       -- 正常
  RTN_NG        CONSTANT integer  := 1;                       -- 予期したエラー
  RTN_NODATA    CONSTANT integer  := 2;                       -- データなし
  RTN_FATAL     CONSTANT integer  := 99;                      -- 予期せぬエラー
  REPORT_ID     CONSTANT varchar(20) := 'IP931500141';       -- 固定値．帳票ID
  MSG_NODATA    CONSTANT varchar(20) := '対象データなし';    -- 検索結果0件
  PROGRAM_ID    CONSTANT varchar(32) := 'SFIP931500141_01';  -- プログラムＩＤ
  -- 書式フォーマット
  FMT_KNGK_J  CONSTANT char(18)  := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';   -- 金額
  FMT_SZEI_J    CONSTANT char(18)  := 'ZZZ,ZZZ,ZZZ,ZZ9'; -- 税金額
  FMT_TOTAL_J  CONSTANT char(21)  := 'Z,ZZZ,ZZZ,ZZZ,ZZZ,ZZ9';  -- 合計金額
  -- 書式フォーマット（外資）
  FMT_KNGK_F  CONSTANT char(21)  := 'ZZZ,ZZZ,ZZZ,ZZ9.99';    -- 金額
  FMT_SZEI_F    CONSTANT char(21)  := 'Z,ZZZ,ZZZ,ZZ9.99';  -- 税金額
  FMT_TOTAL_F  CONSTANT char(21)  := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';   -- 合計金額
--=======================================================================================================*
-- * 変数定義
-- *=======================================================================================================
  gyomuYmd            char(8);                      -- 業務日付
  seqNo               integer :=  0;                     -- シーケンス
  tsukaCd             MTSUKA.TSUKA_CD%TYPE;                   -- 通貨コード
  tsukaNm             MTSUKA.TSUKA_NM%TYPE;                   -- 通貨名称
  gengoYm             varchar(20);                           -- 基準年月（西暦）取得
  hktCd               MGR_KIHON.HKT_CD%TYPE;                  -- 発行体コード
  mgrCd               MGR_KIHON.MGR_CD%TYPE;                  -- 銘柄コード
  mgrRnm              MGR_KIHON.MGR_RNM%TYPE;                 -- 銘柄略称
  isinCd              MGR_KIHON.ISIN_CD%TYPE;                 -- ＩＳＩＮコード
  gnrbaraiKjt         UPFR_TESURYO_KEIJYO.GNRBARAI_KJT%TYPE;  -- 元利払期日
  -- 行単位集計変数
  furikaeKngk         numeric := 0;                       -- 仮受金からの振替金額
  furikaeZei          numeric := 0;                       -- 仮受金からの振替消費税額
  ukeSouteiKngk       numeric := 0;                       -- 発行体からの受入想定金額
  ukeSouteiZei        numeric := 0;                       -- 発行体からの受入想定金額消費税額
  hktHnrKngk          numeric := 0;                       -- 発行体への返戻金額
  hktHnrZei           numeric := 0;                       -- 発行体への返戻金額消費税額
  syuekiKeijoKngk     numeric := 0;                       -- 収益計上金額
  syuekiKeijoZei      numeric := 0;                       -- 収益計上消費税額
  -- 発行体単位集計変数
  hktKngkSum          numeric := 0;                       -- 発行体合計
  hktKngkSumStr       varchar(16);                           -- 発行体合計（表示用）
  -- ページ単位集計変数
  furikaeKngkSum      numeric := 0;                   -- 仮受金からの振替金額（合計）
  furikaeZeiSum       numeric := 0;                   -- 仮受金からの振替消費税額（合計）
  ukeSouteiKngkSum    numeric := 0;                   -- 発行体からの受入想定金額（合計）
  ukeSouteiZeiSum     numeric := 0;                   -- 発行体からの受入想定金額消費税額（合計）
  hktHnrKngkSum       numeric := 0;                   -- 発行体への返戻金額（合計）
  hktHnrZeiSum        numeric := 0;                   -- 発行体への返戻金額消費税額（合計）
  syuekiKeijoKngkSum  numeric := 0;                   -- 収益計上金額（合計）
  syuekiKeijoZeiSum   numeric := 0;                   -- 収益計上消費税額（合計）
  hktKngkSumTotal     numeric := 0;                   -- 発行体合計（合計）
  -- フッタ部変数
  furikaeYmd          UPFR_TESURYO_KEIJYO.KEIJO_YMD%TYPE; -- 仮受金からの振替日
  tesuKngk            numeric := 0;                   -- 税抜手数料
  tesuKngkSzei        numeric := 0;                   -- 税込手数料
  sZei                numeric := 0;                   -- 消費税
  tesuKngkSum         numeric := 0;                   -- 手数料合計
  tesuZeiSum          numeric := 0;                   -- 手数料消費税額合計
  fncRtn              numeric := 0;                   -- FUNCTION戻り値格納
  gSQL                varchar(10000) := NULL; -- SQL編集
  -- カーソル
  curMeisai REFCURSOR;
  -- DB取得項目
  -- 配列定義
  recMeisai SFIP931500141_01_TYPE_RECORD;                      -- レコード
  -- 書式フォーマット
  fmtKngk     varchar(21) := NULL;        -- 金額
  fmtSzei     varchar(21) := NULL;        -- 税金額
  fmtTotal    varchar(21) := NULL;        -- 合計金額
  gInvoiceFlg MOPTION_KANRI.OPTION_FLG%TYPE;    -- オプションフラグ取得
  gBunsho     varchar(150) := NULL;       -- インボイス文章
  gAryBun     pkIpaBun.BUN_ARRAY;
  v_item      TYPE_SREPORT_WK_ITEM;       -- pkPrint.insertData composite type
--====================================================================*
--        メイン
-- *====================================================================
BEGIN
  CALL pkLog.DEBUG(l_inUserId,PROGRAM_ID,'START');
  --  入力パラメータ必須チェック  
  IF   coalesce(trim(both l_inUserId)::text, '') = ''
    OR coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
    OR coalesce(trim(both l_inKijun_Ym)::text, '') = ''
    OR coalesce(trim(both l_inChohyo_Kbn)::text, '') = ''
    OR (coalesce(trim(both l_inMeigaraCode)::text, '') = '' AND
        coalesce(trim(both l_inIsinCd)::text, '') = '')
  THEN
    -- パラメータエラー
    l_outErrMsg := '入力パラメータエラー';
    CALL pkLog.error(l_inUserId, PROGRAM_ID, l_outErrMsg);
    extra_param := RTN_NG;
    RETURN;
  END IF;
  -- 業務日付の取得
  gyomuYmd := pkDate.getGyomuYmd();
  -- 基準年月（西暦）の取得
  gengoYm := pkDate.seirekiChangeSuppressNenGappi(l_inKijun_Ym || '01');
  gengoYm := SUBSTR(gengoYm,1,LENGTH(gengoYm)-3);
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
  furikaeKngk := 0;
  furikaeZei := 0;
  ukeSouteiKngk := 0;
  ukeSouteiZei := 0;
  syuekiKeijoKngk := 0;
  syuekiKeijoZei := 0;
  mgrCd := NULL;
  -- ヘッダーレコード出力
  CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyo_Kbn, gyomuYmd, REPORT_ID);
  -- SQL編集
  CALL SFIP931500141_01_createSQL(l_inKijun_Ym, l_inMeigaraCode, l_inIsinCd, gSQL);
  -- カーソルオープン
  OPEN curMeisai FOR EXECUTE gSQL;
  LOOP
    FETCH curMeisai
    INTO
        recMeisai.gTsukaCd             -- 通貨コード
      , recMeisai.gTsukaNm             -- 通貨名称
      , recMeisai.gHktCd               -- 発行体コード
      , recMeisai.gMgrCd               -- 銘柄コード
      , recMeisai.gMgrRnm              -- 銘柄略称
      , recMeisai.gIsinCd              -- ＩＳＩＮコード
      , recMeisai.gGnrbaraiKjt         -- 元利払期日
      , recMeisai.gFurikaeKngk         -- 仮受金からの振替金額（税込）
      , recMeisai.gFurikaeZei          -- 仮受金からの振替消費税額
      , recMeisai.gUkeSouteiKngk       -- 発行体からの受入想定金額（税込）
      , recMeisai.gUkeSouteiZei        -- 発行体からの受入想定消費税額
      , recMeisai.gHktHnrKngk          -- 発行体への返戻金額
      , recMeisai.gHktHnrZei           -- 発行体への返戻金額（消費税）
      , recMeisai.gFurikaeYmd          -- 仮受金からの振替日
      , recMeisai.gIsUpfKeijo          -- アップフロント手数料勘定計上フラグ
      , recMeisai.gGenFuriKbn          -- 現登振替区分
      , recMeisai.gGnrKbn              -- 元利区分
;
    -- データが無くなったらループを抜ける
    EXIT WHEN NOT FOUND;/* apply on curMeisai */
    -- 1回目のループの場合、発行体コード・銘柄コードを設定
    IF coalesce(mgrCd::text, '') = '' THEN
      hktCd := recMeisai.gHktCd;
      mgrCd := recMeisai.gMgrCd;
    END IF;
    -- 銘柄コードが変わった場合
    IF mgrCd != recMeisai.gMgrCd THEN
      -- 行単位変数の集計
      syuekiKeijoKngk :=
        (furikaeKngk - ukeSouteiKngk - hktHnrKngk);   -- 収益計上金額
      syuekiKeijoZei :=
        (furikaeZei - ukeSouteiZei - hktHnrZei);      -- 収益計上金額消費税額
      -- 発行体単位変数の集計
      hktKngkSum := (hktKngkSum + syuekiKeijoKngk);
      -- ページ単位集計変数の集計
      furikaeKngkSum := (furikaeKngkSum + furikaeKngk);                   -- 仮受金からの振替金額（合計）
      furikaeZeiSum := (furikaeZeiSum + furikaeZei);                      -- 仮受金からの振替消費税額（合計）
      ukeSouteiKngkSum := (ukeSouteiKngkSum + ukeSouteiKngk);             -- 発行体からの受入想定金額（合計）
      ukeSouteiZeiSum := (ukeSouteiZeiSum + ukeSouteiZei);                -- 発行体からの受入想定消費税額（合計）
      hktHnrKngkSum := (hktHnrKngkSum + hktHnrKngk);                      -- 発行体への返戻金額（合計）
      syuekiKeijoKngkSum := (syuekiKeijoKngkSum + syuekiKeijoKngk);       -- 収益計上金額（合計）
      syuekiKeijoZeiSum := (syuekiKeijoZeiSum + syuekiKeijoZei);          -- 収益計上消費税額（合計）
      hktKngkSumTotal := (hktKngkSumTotal + syuekiKeijoKngk);             -- 発行体合計（合計）
      -- 発行体単位集計変数の設定（発行体コードの切り替えまたはページ切り替え時）
      IF (hktCd != recMeisai.gHktCd) OR (tsukaCd != recMeisai.gTsukaCd) OR (coalesce(trim(both furikaeYmd)::text, '') = '' AND (trim(both recMeisai.gFurikaeYmd) IS NOT NULL AND (trim(both recMeisai.gFurikaeYmd))::text <> '')) OR ((trim(both furikaeYmd) IS NOT NULL AND (trim(both furikaeYmd))::text <> '') AND coalesce(trim(both recMeisai.gFurikaeYmd)::text, '') = '') OR (trim(both furikaeYmd) != trim(both recMeisai.gFurikaeYmd))
      THEN
        -- 発行体合計（表示用）を設定
        hktKngkSumStr := hktKngkSum::text;
        -- 発行体合計を初期化
        hktKngkSum := 0;
      ELSE
        -- 発行体合計（表示用）を初期化
        hktKngkSumStr := '';
      END IF;
      --明細数カウントを行う
      seqNo := seqNo + 1;
      -- 抽出した結果を１レコードずつ帳票ワークテーブルへ出力
      		-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := tsukaNm;	-- 通貨
		v_item.l_inItem003 := gengoYm;	-- 基本年月
		v_item.l_inItem004 := mgrCd;	-- 銘柄コード
		v_item.l_inItem005 := isinCd;	-- ISINコード
		v_item.l_inItem006 := mgrRnm;	-- 銘柄略称
		v_item.l_inItem007 := furikaeKngk;	-- 仮受金からの振替金額
		v_item.l_inItem008 := furikaeZei;	-- 仮受金からの振替消費税金額
		v_item.l_inItem009 := ukeSouteiKngk;	-- 発行体からの受入想定金額
		v_item.l_inItem010 := ukeSouteiZei;	-- 発行体からの受入想定消費税金額
		v_item.l_inItem011 := hktHnrKngk;	-- 発行体への返戻金額
		v_item.l_inItem012 := syuekiKeijoKngk;	-- 収益計上金額
		v_item.l_inItem013 := syuekiKeijoZei;	-- 収益計上消費税金額
		v_item.l_inItem014 := hktKngkSumStr;	-- 発行体合計
		v_item.l_inItem015 := furikaeKngkSum;	-- 仮受金からの振替金額（合計）
		v_item.l_inItem016 := furikaeZeiSum;	-- 仮受金からの振替消費税金額（合計）
		v_item.l_inItem017 := ukeSouteiKngkSum;	-- 発行体からの受入想定金額（合計）
		v_item.l_inItem018 := ukeSouteiZeiSum;	-- 発行体からの受入想定消費税金額（合計）
		v_item.l_inItem019 := hktHnrKngkSum;	-- 発行体への返戻金額（合計）
		v_item.l_inItem020 := syuekiKeijoKngkSum;	-- 収益計上金額（合計）
		v_item.l_inItem021 := syuekiKeijoZeiSum;	-- 収益計上消費税金額（合計）
		v_item.l_inItem022 := hktKngkSumTotal;	-- 発行体合計（合計）
		v_item.l_inItem023 := furikaeYmd;	-- 仮受金からの振替日
		v_item.l_inItem024 := furikaeKngkSum;	-- 仮受金からの金額
		v_item.l_inItem025 := trim(both l_inKeijo_Ymd);	-- 収益計上日（関与）日付
		v_item.l_inItem026 := syuekiKeijoKngkSum;	-- 収益計上日（関与）金額
		v_item.l_inItem032 := gBunsho;	-- インボイス文章
		v_item.l_inItem033 := gInvoiceFlg;	-- インボイスオプションフラグ
		v_item.l_inItem027 := REPORT_ID;	-- 帳票ID
		v_item.l_inItem028 := fmtKngk;	-- 金額フォーマット
		v_item.l_inItem029 := fmtSzei;	-- 税金額フォーマット
		v_item.l_inItem030 := fmtTotal;	-- 合計金額フォーマット
		
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
      -- 行単位集計変数の初期化
      furikaeKngk := 0;
      furikaeZei := 0;
      ukeSouteiKngk := 0;
      ukeSouteiZei := 0;
      hktHnrKngk := 0;
      hktHnrZei := 0;
      -- 通貨コード・振替日が変わった場合（改ページ条件）
      IF tsukaCd != recMeisai.gTsukaCd OR (coalesce(trim(both furikaeYmd)::text, '') = '' AND (trim(both recMeisai.gFurikaeYmd) IS NOT NULL AND (trim(both recMeisai.gFurikaeYmd))::text <> '')) OR ((trim(both furikaeYmd) IS NOT NULL AND (trim(both furikaeYmd))::text <> '') AND coalesce(trim(both recMeisai.gFurikaeYmd)::text, '') = '') OR (trim(both furikaeYmd) != trim(both recMeisai.gFurikaeYmd))
      THEN
        -- ページ単位集計変数の初期化
        furikaeKngkSum := 0;
        furikaeZeiSum := 0;
        ukeSouteiKngkSum := 0;
        ukeSouteiZeiSum := 0;
        hktHnrKngkSum := 0;
        syuekiKeijoKngkSum := 0;
        syuekiKeijoZeiSum := 0;
        hktKngkSumTotal := 0;
      END IF;
    END IF;
    -- 抽出結果を変数に設定
    hktCd := recMeisai.gHktCd;                                          -- 発行体コード
    mgrCd := recMeisai.gMgrCd;                                          -- 銘柄コード
    mgrRnm := recMeisai.gMgrRnm;                                        -- 銘柄略称
    isinCd := recMeisai.gIsinCd;                                        -- ＩＳＩＮコード
    tsukaCd := recMeisai.gTsukaCd;                                      -- 通貨コード
    tsukaNm := recMeisai.gTsukaNm;                                      -- 通貨名称
    gnrbaraiKjt := recMeisai.gGnrbaraiKjt;                              -- 元利払期日
    -- 仮受金からの振替日の設定
    IF coalesce(trim(both furikaeYmd)::text, '') = '' THEN
      furikaeYmd := trim(both recMeisai.gFurikaeYmd);
    ELSIF coalesce(trim(both recMeisai.gFurikaeYmd)::text, '') = '' THEN
      -- 1件でもレコードが取得できない場合、空白を設定
      furikaeYmd := NULL;
    ELSIF (trim(both recMeisai.gFurikaeYmd))::numeric  > trim(both furikaeYmd) THEN
      -- 複数レコードを取得した場合、直近日を設定
      furikaeYmd := trim(both recMeisai.gFurikaeYmd);
    END IF;
    -- 書式フォーマットの設定
    IF tsukaCd = 'JPY' THEN
      -- 円
      fmtKngk := FMT_KNGK_J;    -- 金額
      fmtSzei := FMT_SZEI_J;    -- 消費税
      fmtTotal := FMT_TOTAL_J;  -- 合計
    ELSE
      -- 外貨
      fmtKngk := FMT_KNGK_F;    -- 金額
      fmtSzei := FMT_SZEI_F;    -- 消費税
      fmtTotal := FMT_TOTAL_F;  -- 合計  
    END IF;
    -- 行単位集計変数の設定
    furikaeKngk := (furikaeKngk + recMeisai.gFurikaeKngk);              -- 仮受金からの振替金額（税込）
    furikaeZei := (furikaeZei + recMeisai.gFurikaeZei);                 -- 仮受金からの振替消費税額
    IF trim(both recMeisai.gGenFuriKbn) = '1' AND trim(both recMeisai.gIsUpfKeijo) = '0' THEN
      -- 現登振替区分 = '1'（振替債）且つアップフロント手数料勘定計上フラグ ＝ '0'の場合
      -- 手数料取得
      fncRtn := pkIpaCalcTesukngkUpf.getTesuZeiUpf(
        l_inItakuKaishaCd, mgrCd, gnrbaraiKjt, recMeisai.gGnrKbn, l_inUserId, tesuKngk, tesuKngkSzei, sZei);
      IF fncRtn != pkconstant.success() THEN
        extra_param := fncRtn;
        RETURN;
      END IF;
      -- 手数料合計設定
      ukeSouteiKngk := ukeSouteiKngk + tesuKngkSzei;    -- 発行体からの受入想定金額（税込）
      ukeSouteiZei := ukeSouteiZei + sZei;              -- 発行体からの受入想定消費税額
    ELSIF trim(both recMeisai.gGenFuriKbn) = '0' AND trim(both recMeisai.gIsUpfKeijo) = '0' AND coalesce(trim(both isinCd)::text, '') = '' THEN
      -- 現登振替区分 = '0'（現登債：非並存銘柄）且つアップフロント手数料勘定計上フラグ ＝ '0'の場合
      ukeSouteiKngk := 0;
      ukeSouteiZei := 0;
    END IF;
    hktHnrKngk := (hktHnrKngk + recMeisai.gHktHnrKngk); -- 発行体への返戻金額
    hktHnrZei := (hktHnrZei + recMeisai.gHktHnrZei);    -- 発行体への返戻金額（消費税）
  END LOOP;
  IF coalesce(mgrCd::text, '') = '' THEN
    -- [明細データ抽出]で対象データ無しの場合、「対象データなし」を帳票ワークテーブルへ出力
    		-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem003 := gengoYm;	-- 基本年月
		v_item.l_inItem027 := REPORT_ID;	-- 帳票ID
		v_item.l_inItem031 := MSG_NODATA;	-- 対象データ無し
		
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
  END IF;
  -- 行単位変数の集計
  syuekiKeijoKngk :=
    (furikaeKngk - ukeSouteiKngk - hktHnrKngk);   -- 収益計上金額
  syuekiKeijoZei :=
    (furikaeZei - ukeSouteiZei - hktHnrZei);      -- 収益計上金額消費税額
  -- 発行体単位変数の集計
  hktKngkSum := (hktKngkSum + syuekiKeijoKngk);
  -- ページ単位集計変数の集計
  furikaeKngkSum := (furikaeKngkSum + furikaeKngk);                   -- 仮受金からの振替金額（合計）
  furikaeZeiSum := (furikaeZeiSum + furikaeZei);                      -- 仮受金からの振替消費税額（合計）
  ukeSouteiKngkSum := (ukeSouteiKngkSum + ukeSouteiKngk);             -- 発行体からの受入想定金額（合計）
  ukeSouteiZeiSum := (ukeSouteiZeiSum + ukeSouteiZei);                -- 発行体からの受入想定消費税額（合計）
  hktHnrKngkSum := (hktHnrKngkSum + hktHnrKngk);                      -- 発行体への返戻金額（合計）
  syuekiKeijoKngkSum := (syuekiKeijoKngkSum + syuekiKeijoKngk);       -- 収益計上金額（合計）
  syuekiKeijoZeiSum := (syuekiKeijoZeiSum + syuekiKeijoZei);          -- 収益計上消費税額（合計）
  hktKngkSumTotal := (hktKngkSumTotal + syuekiKeijoKngk);             -- 発行体合計（合計）
  -- 抽出した結果を１レコードずつ帳票ワークテーブルへ出力
  --明細数カウントを行う
  seqNo := seqNo + 1;
  		-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := tsukaNm;	-- 通貨
		v_item.l_inItem003 := gengoYm;	-- 基本年月
		v_item.l_inItem004 := mgrCd;	-- 銘柄コード
		v_item.l_inItem005 := isinCd;	-- ISINコード
		v_item.l_inItem006 := mgrRnm;	-- 銘柄略称
		v_item.l_inItem007 := furikaeKngk;	-- 仮受金からの振替金額
		v_item.l_inItem008 := furikaeZei;	-- 仮受金からの振替消費税金額
		v_item.l_inItem009 := ukeSouteiKngk;	-- 発行体からの受入想定金額
		v_item.l_inItem010 := ukeSouteiZei;	-- 発行体からの受入想定消費税金額
		v_item.l_inItem011 := hktHnrKngk;	-- 発行体への返戻金額
		v_item.l_inItem012 := syuekiKeijoKngk;	-- 収益計上金額
		v_item.l_inItem013 := syuekiKeijoZei;	-- 収益計上消費税金額
		v_item.l_inItem014 := hktKngkSum;	-- 発行体合計
		v_item.l_inItem015 := furikaeKngkSum;	-- 仮受金からの振替金額（合計）
		v_item.l_inItem016 := furikaeZeiSum;	-- 仮受金からの振替消費税金額（合計）
		v_item.l_inItem017 := ukeSouteiKngkSum;	-- 発行体からの受入想定金額（合計）
		v_item.l_inItem018 := ukeSouteiZeiSum;	-- 発行体からの受入想定消費税金額（合計）
		v_item.l_inItem019 := hktHnrKngkSum;	-- 発行体への返戻金額（合計）
		v_item.l_inItem020 := syuekiKeijoKngkSum;	-- 収益計上金額（合計）
		v_item.l_inItem021 := syuekiKeijoZeiSum;	-- 収益計上消費税金額（合計）
		v_item.l_inItem022 := hktKngkSumTotal;	-- 発行体合計（合計）
		v_item.l_inItem023 := furikaeYmd;	-- 仮受金からの振替日
		v_item.l_inItem024 := furikaeKngkSum;	-- 仮受金からの金額
		v_item.l_inItem025 := trim(both l_inKeijo_Ymd);	-- 収益計上日（関与）日付
		v_item.l_inItem026 := syuekiKeijoKngkSum;	-- 収益計上日（関与）金額
		v_item.l_inItem032 := gBunsho;	-- インボイス文章
		v_item.l_inItem033 := gInvoiceFlg;	-- インボイスオプションフラグ
		v_item.l_inItem027 := REPORT_ID;	-- 帳票ID
		v_item.l_inItem028 := fmtKngk;	-- 金額フォーマット
		v_item.l_inItem029 := fmtSzei;	-- 税金額フォーマット
		v_item.l_inItem030 := fmtTotal;	-- 合計金額フォーマット
		
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
-- REVOKE ALL ON FUNCTION sfip931500141_01 ( l_inUserId text , l_inItakuKaishaCd text , l_inMeigaraCode text , l_inIsinCd text , l_inKijun_Ym text , l_inKeijo_Ymd text , l_inChohyo_Kbn text , l_outErrMsg OUT text , OUT extra_param numeric) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfip931500141_01_createsql (
    IN p_inKijun_Ym text,
    IN p_inMeigaraCode text,
    IN p_inIsinCd text,
    OUT p_gSQL varchar
) AS $body$
BEGIN
    -- 変数を初期化
    p_gSQL := '';
    -- 変数にSQLクエリ文を代入
    p_gSQL := 'SELECT '
      ||'    HENREI.TSUKA_CD, '                                                               -- 通貨コード
      ||'    HENREI.TSUKA_NM, '                                                               -- 通貨名称
      ||'    HENREI.HKT_CD, '                                                                 -- 発行体コード
      ||'    HENREI.MGR_CD, '                                                                 -- 銘柄コード
      ||'    HENREI.MGR_RNM, '                                                                -- 銘柄略称
      ||'    HENREI.ISIN_CD, '                                                                -- ＩＳＩＮコード
      ||'    HENREI.GNRBARAI_KJT, '                                                           -- 元利払期日
      ||'    (COALESCE(SUM(HENREI.SHR_TESU_KNGK),0) +  '
      ||'     COALESCE(SUM(HENREI.SHR_TESU_SZEI),0)), '                                            -- 仮受金からの振替金額(税込)
      ||'    COALESCE(SUM(HENREI.SHR_TESU_SZEI),0), '                                              -- 仮受金からの振替消費税額
      ||'    0, '                                                                             -- 発行体からの受入想定金額(税込)
      ||'    0, '                                                                             -- 発行体からの受入想定消費税額
      ||'    (COALESCE(HENREI.SHR_TESU_KNGK,0) + '
      ||'     COALESCE(HENREI.SHR_TESU_SZEI,0)), '                                                 -- 発行体への返戻金額
      ||'    COALESCE(HENREI.SHR_TESU_SZEI,0), '                                                   -- 発行体への返戻消費税金額
      ||'    CASE WHEN HENREI.IS_UPF_KEIJO = ''0'' THEN NULL ELSE MAX((TRIM(HENREI.FURIKAE_YMD))::numeric) END, ' -- 仮受金からの振替日
      ||'    HENREI.IS_UPF_KEIJO, '                                                           -- アップフロント手数料勘定計上フラグ
      ||'    HENREI.GEN_FURI_KBN, '                                                           -- 現登振替区分
      ||'    HENREI.GNR_KBN '                                                                 -- 元利区分
      ||'  FROM  '
      ||'    ( SELECT '
      ||'        ViewSELECT.TSUKA_CD AS TSUKA_CD, '                                           -- 通貨コード
      ||'        ViewSELECT.TSUKA_NM AS TSUKA_NM, '                                           -- 通貨名称
      ||'        ViewSELECT.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD, '                             -- 委託会社コード
      ||'        ViewSELECT.HKT_CD AS HKT_CD, '                                               -- 発行体コード
      ||'        ViewSELECT.MGR_CD AS MGR_CD, '                                               -- 銘柄コード
      ||'        ViewSELECT.MGR_RNM AS MGR_RNM, '                                             -- 銘柄略称
      ||'        ViewSELECT.ISIN_CD AS ISIN_CD, '                                             -- ＩＳＩＮコード
      ||'        KKN_HNR.RBR_KJT AS GNRBARAI_KJT, '                                           -- 元利払期日
      ||'        KKN_HNR.SHR_TESU_KNGK AS SHR_TESU_KNGK, '                                    -- 支払手数料
      ||'        KKN_HNR.SHR_TESU_SZEI AS SHR_TESU_SZEI, '                                    -- 支払手数料消費税
      ||'        UPF.KEIJO_YMD AS FURIKAE_YMD, '                                              -- 仮受金からの振替日
      ||'        COALESCE(UPF.KEIJO_STS_KBN,''0'') AS IS_UPF_KEIJO, '                              -- アップフロント手数料勘定計上フラグ
      ||'        ViewSELECT.GEN_FURI_KBN AS GEN_FURI_KBN, '                                   -- 現登振替区分
      ||'        ViewSELECT.GNR_KBN AS GNR_KBN '
      ||'      FROM '
      ||'        ( SELECT '
      ||'            DISTINCT'
      ||'            VMG2.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD, '
      ||'            VMG2.HKT_CD AS HKT_CD, '
      ||'            VMG2.MGR_CD AS MGR_CD, '
      ||'            VMG2.MGR_RNM AS MGR_RNM, '
      ||'            VMG2.ISIN_CD AS ISIN_CD, '
      ||'            VMG2.TSUKA_CD AS TSUKA_CD, '
      ||'            VMG2.TSUKA_NM AS TSUKA_NM, '
      ||'            VMG2.RBR_KJT AS GNRBARAI_KJT, '
      ||'            VMG2.GEN_FURI_KBN AS GEN_FURI_KBN, '
      ||'            VMG2.GNR_KBN AS GNR_KBN '
      ||'          FROM MGR_KIHON_VIEW_UPF VMG2 '
      ||'          WHERE VMG2.GEN_FURI_KBN = ''1'' '          -- （振替債）
      ||'        ) ViewSELECT '
      ||'        INNER JOIN KIKIN_HENREI KKN_HNR '
      ||'          ON ViewSELECT.ITAKU_KAISHA_CD = KKN_HNR.ITAKU_KAISHA_CD '
      ||'         AND ViewSELECT.MGR_CD = KKN_HNR.MGR_CD '
      ||'         AND ViewSELECT.TSUKA_CD = KKN_HNR.TSUKA_CD '
      ||'         AND ViewSELECT.GNRBARAI_KJT = KKN_HNR.RBR_KJT '
      ||'         AND ViewSELECT.GNR_KBN = KKN_HNR.GNR_KBN '
      ||'        LEFT JOIN UPFR_TESURYO_KEIJYO UPF '
      ||'          ON ViewSELECT.ITAKU_KAISHA_CD = UPF.ITAKU_KAISHA_CD '
      ||'         AND ViewSELECT.GEN_FURI_KBN = UPF.GEN_FURI_KBN '
      ||'         AND ViewSELECT.MGR_CD = UPF.MGR_CD '
      ||'         AND ViewSELECT.GNRBARAI_KJT = UPF.GNRBARAI_KJT ';
    p_gSQL := p_gSQL ||' UNION ALL '
      ||'      SELECT '
      ||'        ViewSELECT.TSUKA_CD AS TSUKA_CD, '
      ||'        ViewSELECT.TSUKA_NM AS TSUKA_NM, '
      ||'        ViewSELECT.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD, '
      ||'        ViewSELECT.HKT_CD AS HKT_CD, '
      ||'        ViewSELECT.MGR_CD AS MGR_CD, '
      ||'        ViewSELECT.MGR_RNM AS MGR_RNM, '
      ||'        ViewSELECT.ISIN_CD AS ISIN_CD, '
      ||'        KKN_HNR_GT.RBR_KJT AS GNRBARAI_KJT, '
      ||'        COALESCE(KKN_HNR_GT.GNKN_TESU_KNGK,0) + COALESCE(KKN_HNR_GT.RKN_TESU_KNGK,0) AS SHR_TESU_KNGK, '
      ||'        COALESCE(KKN_HNR_GT.GNKN_TESU_KNGK_ZEI,0) + COALESCE(KKN_HNR_GT.RKN_TESU_KNGK_ZEI,0) AS SHR_TESU_SZEI, '
      ||'        UPF.KEIJO_YMD AS FURIKAE_YMD, '
      ||'        CASE WHEN UPF.MGR_CD IS NOT NULL THEN ''1'' ELSE ''0'' END AS IS_UPF_KEIJO, '
      ||'        ViewSELECT.GEN_FURI_KBN AS GEN_FURI_KBN, '
      ||'        ViewSELECT.GNR_KBN AS GNR_KBN '
      ||'      FROM  '
      ||'        ( SELECT  '
      ||'            DISTINCT '
      ||'            VMG2.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD, '
      ||'            VMG2.HKT_CD AS HKT_CD, '
      ||'            VMG2.MGR_CD AS MGR_CD, '
      ||'            VMG2.MGR_RNM AS MGR_RNM, '
      ||'            VMG2.ISIN_CD AS ISIN_CD, '
      ||'            VMG2.TSUKA_CD AS TSUKA_CD, '
      ||'            VMG2.TSUKA_NM AS TSUKA_NM, '
      ||'            VMG2.RBR_KJT AS GNRBARAI_KJT, '
      ||'            VMG2.GEN_FURI_KBN AS GEN_FURI_KBN, '
      ||'            VMG2.GNR_KBN AS GNR_KBN '
      ||'          FROM MGR_KIHON_VIEW_UPF VMG2 '
      ||'          WHERE VMG2.GEN_FURI_KBN = ''0'' '     -- （現登債）
      ||'        ) ViewSELECT '
      ||'        INNER JOIN B_KIKIN_HENREI KKN_HNR_GT '
      ||'          ON ViewSELECT.ITAKU_KAISHA_CD = KKN_HNR_GT.ITAKU_KAISHA_CD '
      ||'         AND ViewSELECT.MGR_CD = KKN_HNR_GT.MGR_CD '
      ||'         AND ViewSELECT.TSUKA_CD = KKN_HNR_GT.TSUKA_CD '
      ||'         AND ViewSELECT.GNRBARAI_KJT = KKN_HNR_GT.RBR_KJT '
      ||'        LEFT JOIN UPFR_TESURYO_KEIJYO UPF '
      ||'          ON ViewSELECT.ITAKU_KAISHA_CD = UPF.ITAKU_KAISHA_CD '
      ||'         AND ViewSELECT.GEN_FURI_KBN = UPF.GEN_FURI_KBN '
      ||'         AND ViewSELECT.MGR_CD = UPF.MGR_CD '
      ||'         AND ViewSELECT.GNRBARAI_KJT = UPF.GNRBARAI_KJT ';
    p_gSQL := p_gSQL ||'  ) HENREI '
      ||' WHERE '
      ||'        SUBSTR(HENREI.GNRBARAI_KJT,1,6) = ''' || p_inKijun_Ym || '''';
    -- <<引数.銘柄コードがNULLでない場合>>
    IF (trim(both p_inMeigaraCode) IS NOT NULL AND (trim(both p_inMeigaraCode))::text <> '') THEN
      p_gSQL := p_gSQL ||' AND HENREI.MGR_CD = ''' || p_inMeigaraCode || '''';
    END IF;
    -- <<引数.ＩＳＩＮコードがNULLでない場合>>
    IF (trim(both p_inIsinCd) IS NOT NULL AND (trim(both p_inIsinCd))::text <> '') THEN
      p_gSQL := p_gSQL ||' AND HENREI.ISIN_CD = ''' || p_inIsinCd || '''';
    END IF;
    p_gSQL := p_gSQL ||' GROUP BY '
      ||'  HENREI.TSUKA_CD, '
      ||'  HENREI.TSUKA_NM, '
      ||'  HENREI.HKT_CD, '
      ||'  HENREI.MGR_CD, '
      ||'  HENREI.MGR_RNM, '
      ||'  HENREI.ISIN_CD, '
      ||'  HENREI.GNRBARAI_KJT, '  -- 元利払期日
      ||'  HENREI.IS_UPF_KEIJO, '
      ||'  HENREI.GEN_FURI_KBN, '
      ||'  HENREI.GNR_KBN, '
      ||'  HENREI.SHR_TESU_KNGK, '
      ||'  HENREI.SHR_TESU_SZEI '
      ||'ORDER BY '
      ||'  CASE WHEN HENREI.IS_UPF_KEIJO = ''0'' THEN NULL ELSE MAX((TRIM(HENREI.FURIKAE_YMD))::numeric) END, '
      ||'  HENREI.TSUKA_CD, '
      ||'  HENREI.HKT_CD, '
      ||'  HENREI.MGR_CD, '
      ||'  HENREI.GNRBARAI_KJT ';
   EXCEPTION
  WHEN OTHERS THEN
    RAISE;
  END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfip931500141_01_createsql () FROM PUBLIC;
