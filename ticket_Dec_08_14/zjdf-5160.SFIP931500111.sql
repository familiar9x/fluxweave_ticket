




CREATE OR REPLACE FUNCTION sfip931500111 ( l_inUserId text		      -- ユーザID								
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
-- * 画面で指定した発行体コードまたは銘柄コードまたは基準年月について、銘柄単位で元利金支払手数料の一括徴収分を出力する。
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
  PROGRAM_ID    CONSTANT varchar(30) := 'SFIP931500111';  -- プログラムＩＤ
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
  --	元利払手数料一括分仮受金明細表を出力	
  --returnCd := SFIP931500111_SUB();
  SELECT f.l_outerrmsg, f.extra_param INTO l_outErrMsg, returnCd
  FROM SFIP931500111_01(
      l_inUserId 		      -- ユーザID								
    , l_inItakuKaishaCd 		-- 委託会社コード								
    , l_inHakkoTaiCd 		  -- 発行体コード								
    , l_inMeigaraCode 		  -- 銘柄コード								
    , l_inIsinCd 		      -- ＩＳＩＮコード								
    , l_inKijun_Ym 		    -- 基準年月								
    , l_inChohyo_Kbn 		  -- 帳票区分								
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
-- REVOKE ALL ON FUNCTION sfip931500111 ( l_inUserId text , l_inItakuKaishaCd text , l_inHakkoTaiCd text , l_inMeigaraCode text , l_inIsinCd text , l_inKijun_Ym text , l_inChohyo_Kbn text , l_outErrMsg OUT text , OUT extra_param numeric) FROM PUBLIC;
