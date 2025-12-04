




CREATE OR REPLACE FUNCTION sfip931500121_01 ( l_inUserId text          --	ユーザＩＤ		
 , l_inItakuKaishaCd text   --	委託会社コード	
 , l_inKijun_Ym text        --	基準年月 		 
 , l_inChohyo_Kbn text      --	帳票区分		
 , l_outErrMsg OUT text        --	エラーコメント		
 , OUT extra_param numeric) RETURNS record AS $body$
DECLARE

--********************************************************************************************************************
-- * 元利金手数料一括分仮受金明細表
-- * 元利金手数料一括分仮受金明細表帳票データを設定。
-- *
-- * @author	ASK
-- *
-- * @version $Revision: 1.0 $
-- *
-- * @param	l_inUserId			  ユーザＩＤ
-- * @param	l_inItakuKaishaCd	委託会社コード
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
  REPORT_ID     CONSTANT varchar(20) := 'IP931500121';  -- 固定値．帳票ID
  MSG_NODATA    CONSTANT varchar(20) := '対象データなし'; -- 検索結果0件
  PROGRAM_ID    CONSTANT varchar(32) := 'SFIP931500121_01';  -- プログラムＩＤ
	-- 書式フォーマット
	FMT_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 金額
	FMT_SZEI_J		CONSTANT char(18)	:= 'ZZZ,ZZZ,ZZZ,ZZ9';	-- 税金額
	FMT_TOTAL_J	CONSTANT char(21)	:= 'Z,ZZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 合計金額
	-- 書式フォーマット（外資）
	FMT_KNGK_F	CONSTANT char(21)	:= 'ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 金額
	FMT_SZEI_F		CONSTANT char(21)	:= 'Z,ZZZ,ZZZ,ZZ9.99';	-- 税金額
	FMT_TOTAL_F	CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 合計金額
--=======================================================================================================*
-- * 変数定義
-- *=======================================================================================================
  gyomuYmd  char(8);   -- 業務日付
  fmtKngk	  varchar(21) := NULL;					-- 金額
  fmtSzei		varchar(21) := NULL;					-- 税金額
  fmtTotal	varchar(21) := NULL;					-- 合計金額
  kikanYmdF char(16);              -- 対象期間（From）
  kikanYmdT char(16);              -- 対象期間（To）
  seqNo     integer :=  0;   --シーケンス
  rowCount  integer :=  0;   --明細SQL文の取得件数
  tsukaCd   MTSUKA.TSUKA_CD%TYPE;              -- 通貨コード
  tsukaNm   MTSUKA.TSUKA_NM%TYPE;             -- 通貨名称
  gInvoiceFlg   MOPTION_KANRI.OPTION_FLG%TYPE;    -- オプションフラグ取得
  gBunsho   varchar(150) := NULL;     -- インボイス文章
  gAryBun   pkIpaBun.BUN_ARRAY;             -- インボイス文章(請求書)配列
  v_item    type_sreport_wk_item;           -- composite type for pkPrint.insertData
  
--==============================================================================
--                  カーソル定義                
--==============================================================================
  curMeisai CURSOR(
        inItakuKaishaCd  text,
        inKijun_Ym  text
  ) FOR
  SELECT
    ViewSelect.MGR_CD AS MGR_CD,			      -- 銘柄コード
    ViewSelect.MGR_RNM AS MGR_RNM,			    -- 銘柄略称
    ViewSelect.TSUKA_CD AS TSUKA_CD,		    -- 通貨コード
    ViewSelect.TSUKA_NM AS TSUKA_NM,		    -- 通貨
    SUM(ViewSelect.FRKE_KNGK) AS FRKE_KNGK,	-- 今月の振替額
    SUM(ViewSelect.FRKE_SZEI) AS FRKE_SZEI,	-- 今月の振替額（内消費税）
    SUM(ViewSelect.ZNDK_KNGK) AS ZNDK_KNGK,	-- 今月の仮受金残高
    SUM(ViewSelect.ZNDK_SZEI) AS ZNDK_SZEI 	-- 今月の仮受金残高（内消費税）
  FROM (
      SELECT
        VOS01.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD,
        VOS01.MGR_CD AS MGR_CD,
        VOS01.MGR_RNM AS MGR_RNM,
        VOS01.TSUKA_CD AS TSUKA_CD,
        TSUKA_NM AS TSUKA_NM,
        (CASE
          WHEN SUBSTR(VOS01.RBR_KJT,1,6) = inKijun_Ym
          THEN VOS01.KKN_NYUKIN_KNGK
          ELSE 0
        END) AS FRKE_KNGK,	-- 振替額
        (CASE 
          WHEN SUBSTR(VOS01.RBR_KJT,1,6) = inKijun_Ym
           AND VOS01.KKN_IDO_KBN IN ('13','23')
          THEN VOS01.KKN_NYUKIN_KNGK
          ELSE 0
        END) AS FRKE_SZEI,	-- 振替額（内消費税）
        (CASE 
          WHEN TO_DATE(VOS01.RBR_KJT, 'YYYYMMDD') > oracle.LAST_DAY(TO_DATE(inKijun_Ym || '01', 'YYYYMMDD'))
          THEN VOS01.KKN_NYUKIN_KNGK
          ELSE 0
        END) AS ZNDK_KNGK,	-- 仮受金残高
        (CASE 
          WHEN TO_DATE(VOS01.RBR_KJT, 'YYYYMMDD') > oracle.LAST_DAY(TO_DATE(inKijun_Ym || '01', 'YYYYMMDD'))
           AND VOS01.KKN_IDO_KBN IN ('13','23')
          THEN VOS01.KKN_NYUKIN_KNGK
          ELSE 0
        END) AS ZNDK_SZEI 	-- 仮受金残高（内消費税）
      FROM MGR_KIHON_VIEW_UPF VOS01
      WHERE
        VOS01.ITAKU_KAISHA_CD = inItakuKaishaCd
  ) ViewSelect 
  GROUP BY
    ViewSelect.ITAKU_KAISHA_CD,
    ViewSelect.MGR_CD,
    ViewSelect.MGR_RNM,
    ViewSelect.TSUKA_CD,
    ViewSelect.TSUKA_NM
  ORDER BY
    ViewSelect.ITAKU_KAISHA_CD,
    ViewSelect.TSUKA_CD,
    ViewSelect.MGR_CD;
--====================================================================*
--        メイン
-- *====================================================================
BEGIN
    CALL pkLog.DEBUG(l_inUserId,PROGRAM_ID,'START');
    --	入力パラメータ必須チェック	
	IF   coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
		OR coalesce(trim(both l_inKijun_Ym)::text, '') = ''
		OR coalesce(trim(both l_inUserId)::text, '') = ''
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
    -- 対象期間From,Toの取得
    kikanYmdF := l_inKijun_Ym || '01';
    kikanYmdT := pkdate.getGetsumatsuYmd(kikanYmdF,0);
    -- 西暦の取得
    kikanYmdF := pkDate.seirekiChangeSuppressNenGappi(kikanYmdF);
    kikanYmdT := pkDate.seirekiChangeSuppressNenGappi(kikanYmdT);
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
      FOR i IN 1..coalesce(cardinality(gAryBun), 0) LOOP
           IF i = 1 THEN
               gBunsho := gAryBun[i];
           END IF;
      END LOOP;
    END IF;
    -- ヘッダーレコード出力
    CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyo_Kbn, gyomuYmd, REPORT_ID);
    -- カーソルオープン  
    FOR recMeisai IN curMeisai(l_inItakuKaishaCd,l_inKijun_Ym) LOOP
      IF recMeisai.FRKE_KNGK != 0 OR 	    -- 今月の振替額
         recMeisai.FRKE_SZEI != 0 OR 	    -- 今月の振替額（内消費税）
         recMeisai.ZNDK_KNGK != 0 OR 	    -- 今月の仮受金残高
         recMeisai.ZNDK_SZEI != 0 	      -- 今月の仮受金残高（内消費税）
      THEN
        --明細数カウントを行う
        seqNo := seqNo + 1;
        -- 1回目のループの場合、通貨コードを設定
        IF seqNo = 1 THEN
          tsukaCd := recMeisai.TSUKA_CD;
          tsukaNm := recMeisai.TSUKA_NM;
        END IF;
        -- 通貨コードが変わった場合
        IF tsukaCd != recMeisai.TSUKA_CD THEN
          -- 変数の初期化
          tsukaCd := recMeisai.TSUKA_CD;    -- 通貨コード
          tsukaNm := recMeisai.TSUKA_NM;    -- 通貨名称
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
        -- 抽出した結果を１レコードずつ帳票ワークテーブルへ出力
        -- Clear composite type
        v_item := ROW();
        v_item.l_inItem001 := l_inUserId;             -- ユーザＩＤ
        v_item.l_inItem002 := kikanYmdF;              -- 対象期間（From）
        v_item.l_inItem003 := kikanYmdT;              -- 対象期間（To）
        v_item.l_inItem004 := tsukaNm;                -- 通貨
        v_item.l_inItem005 := recMeisai.MGR_CD;       -- 銘柄コード
        v_item.l_inItem006 := recMeisai.MGR_RNM;      -- 銘柄略称
        v_item.l_inItem007 := recMeisai.FRKE_KNGK;    -- 今月の振替額
        v_item.l_inItem008 := recMeisai.FRKE_SZEI;    -- 今月の振替額（内消費税）
        v_item.l_inItem009 := recMeisai.ZNDK_KNGK;    -- 今月の仮受金残高
        v_item.l_inItem010 := recMeisai.ZNDK_SZEI;    -- 今月の仮受金残高（内消費税）
        v_item.l_inItem011 := REPORT_ID;              -- 帳票ＩＤ
        v_item.l_inItem012 := fmtKngk;                -- 金額フォーマット
        v_item.l_inItem013 := fmtSzei;                -- 税金額フォーマット
        v_item.l_inItem014 := fmtTotal;               -- 合計金額フォーマット
        v_item.l_inItem016 := gBunsho;                -- インボイス文章
        v_item.l_inItem017 := gInvoiceFlg;            -- インボイスオプションフラグ
        
        CALL pkPrint.insertData(
             l_inKeyCd          =>  l_inItakuKaishaCd::varchar      -- 識別コード      
            ,l_inUserId         =>  l_inUserId::varchar             -- ユーザＩＤ
            ,l_inChohyoKbn      =>  l_inChohyo_Kbn::char            -- 帳票区分
            ,l_inSakuseiYmd     =>  gyomuYmd::char                  -- 作成年月日
            ,l_inChohyoId       =>  REPORT_ID::char                 -- 帳票ＩＤ
            ,l_inSeqNo          =>  seqNo::integer                  -- 連番
            ,l_inHeaderFlg      =>  1::integer                      -- ヘッダフラグ
            ,l_inItem           =>  v_item                          -- アイテム
            ,l_inKousinId       =>  l_inUserId::varchar             -- 更新者ID
            ,l_inSakuseiId      =>  l_inUserId::varchar             -- 作成者ID
        );
      END IF;
    END LOOP;
    IF seqNo = 0 THEN
      -- [明細データ抽出]で対象データ無しの場合、「対象データなし」を帳票ワークテーブルへ出力
      -- Clear composite type
      v_item := ROW();
      v_item.l_inItem001 := l_inUserId;                       -- ユーザＩＤ
      v_item.l_inItem002 := kikanYmdF;                        -- 引数．対象期間（From）
      v_item.l_inItem003 := kikanYmdT;                        -- 引数．対象期間（To）
      v_item.l_inItem011 := REPORT_ID;                        -- 帳票ＩＤ
      v_item.l_inItem015 := MSG_NODATA;                       -- 対象データ無し
      
      CALL pkPrint.insertData(
         l_inKeyCd          =>  l_inItakuKaishaCd::varchar           -- 識別コード
        ,l_inUserId         =>  l_inUserId::varchar                  -- ユーザＩＤ
        ,l_inChohyoKbn      =>  l_inChohyo_Kbn::char                 -- 帳票区分
        ,l_inSakuseiYmd     =>  gyomuYmd::char                       -- 作成年月日
        ,l_inChohyoId       =>  REPORT_ID::char                      -- 帳票ＩＤ
        ,l_inSeqNo          =>  1::integer                           -- 連番
        ,l_inHeaderFlg      =>  1::integer                           -- ヘッダフラグ
        ,l_inItem           =>  v_item                               -- アイテム
        ,l_inKousinId       =>  l_inUserId::varchar                  -- 更新者ID
        ,l_inSakuseiId      =>  l_inUserId::varchar                  -- 作成者ID
      );
      extra_param := RTN_NODATA;
      RETURN;
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
-- REVOKE ALL ON FUNCTION sfip931500121_01 ( l_inUserId text , l_inItakuKaishaCd text , l_inKijun_Ym text , l_inChohyo_Kbn text , l_outErrMsg OUT text , OUT extra_param numeric) FROM PUBLIC;
