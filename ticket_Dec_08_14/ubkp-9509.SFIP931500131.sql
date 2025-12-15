




CREATE OR REPLACE FUNCTION sfip931500131 ( l_inUserId text          -- ユーザID
 , l_inItakuKaishaCd text   -- 委託会社コード
 , l_inKijun_Ym text        -- 基準年月
 , l_inKeijo_Ymd text       -- 収益計上日
 , l_inChohyo_Kbn text      -- 帳票区分
 , l_outErrMsg OUT text        -- エラーコメント
 , OUT extra_param numeric) RETURNS record AS $body$
DECLARE

--********************************************************************************************************************
-- * アップフロント分伝票起票シート
-- * 対象年月が元利払期日の銘柄を出力対象とする。
-- *
-- * @author	ASK
-- *
-- * @version $Revision: 1.0 $
-- *
-- * @param	l_inUserId			  ユーザＩＤ
-- * @param	l_inItakuKaishaCd	委託会社コード
-- * @param	l_inKijun_Ym			基準年月
-- * @param	l_inKeijo_Ymd			収益計上日
-- * @param	l_inChohyo_Kbn		帳票区分
-- * @param	l_outErrMsg		    エラーコメント
-- * @return	returnCd			リターンコード
-- ********************************************************************************************************************
--====================================================================
--					デバッグ機能										  
--====================================================================
  DEBUG numeric(1) := 1;
--==============================================================================
--          定数定義                                                            
--==============================================================================
  RTN_OK        CONSTANT integer  := 0;                     -- 正常
  RTN_NG        CONSTANT integer  := 1;                     -- 予期したエラー
  RTN_NODATA    CONSTANT integer  := 2;                     -- データなし
  RTN_FATAL     CONSTANT integer  := 99;                    -- 予期せぬエラー
  PROGRAM_ID    CONSTANT varchar(30) := 'SFIP931500131';   -- プログラムＩＤ
--=======================================================================================================*
-- * 変数定義
-- *=======================================================================================================
  gyomuYmd            char(8);                        -- 業務日付
  returnCd            numeric;                         -- リターンコード
--====================================================================*
--        メイン
-- *====================================================================
BEGIN
  CALL pkLog.DEBUG(l_inUserId,PROGRAM_ID,'START');
  --	業務日付の取得	
  gyomuYmd := pkDate.getGyomuYmd();
  --	入力パラメータ必須チェック	
  IF   coalesce(trim(both l_inUserId)::text, '') = ''
    OR coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
    OR coalesce(trim(both l_inKijun_Ym)::text, '') = ''
    OR coalesce(trim(both l_inChohyo_Kbn)::text, '') = ''
  THEN
    -- パラメータエラー
    l_outErrMsg := '入力パラメータエラー';
    CALL pkLog.error(l_inUserId, PROGRAM_ID, l_outErrMsg);
    extra_param := RTN_NG;
    RETURN;
  END IF;
  --	アップフロント分伝票起票シートを出力	
  SELECT f.l_outErrMsg, f.extra_param INTO l_outErrMsg, returnCd
  FROM SFIP931500131_01(
      l_inUserId           -- ユーザID
    , l_inItakuKaishaCd    -- 委託会社コード
    , l_inKijun_Ym         -- 基準年月
    , l_inKeijo_Ymd        -- 収益計上日
    , l_inChohyo_Kbn       -- 帳票区分
  ) f;
  IF returnCd IN (RTN_OK, RTN_NODATA)
  THEN
    l_outErrMsg := '';
    returnCd := RTN_OK;
  END IF;
  extra_param := returnCd;
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
-- REVOKE ALL ON FUNCTION sfip931500131 ( l_inUserId text , l_inItakuKaishaCd text , l_inKijun_Ym text , l_inKeijo_Ymd text , l_inChohyo_Kbn text , l_outErrMsg OUT text , OUT extra_param numeric) FROM PUBLIC;
