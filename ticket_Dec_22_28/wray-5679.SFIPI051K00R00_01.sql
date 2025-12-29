




CREATE OR REPLACE FUNCTION sfipi051k00r00_01 (l_inItakuKaishaCd text) RETURNS integer AS $body$
DECLARE

  --
--  * 著作権: Copyright (c) 2005
--  * 会社名: JIP
--  *
--  * 元利金支払基金返戻通知書データを作成する。（バッチ用）
--  * １．元利金支払基金返戻通知書データ作表処理
--  * ２．バッチ帳票出力ＯＮ処理
--  *
--  * @author 高橋　知之(NOA)
--  * @version $Revision: 1.3 $
--  *
--  * @param l_initakuKaishaCd 委託会社コード
--  * @return INTEGER 0:正常、99:異常、それ以外：エラー
--  
  --==============================================================================
  --                  デバッグ機能                                                 
  --==============================================================================
  DEBUG numeric(1) := 1;
  --==============================================================================
  --                  定数定義                                                    
  --==============================================================================
  USER_ID          CONSTANT text := pkconstant.BATCH_USER(); -- ユーザーID
  PROGRAM_ID       CONSTANT text := 'SFIPI051K00R00_01'; -- プログラムID
  CHOHYO_KBN       CONSTANT text := '1'; -- 帳票区分(1：バッチ)
  RTN_FATAL        CONSTANT numeric := 99; -- エラー
  MSG_ID           CONSTANT text := 'ECM701'; -- エラーメッセージID
  --==============================================================================
  --                  変数定義                                                    
  --==============================================================================
  gGyomuYmd   text; -- 業務日付
  pOutSqlCode integer; -- 戻り値取得用
  pOutSqlErrM varchar(2000); -- 戻り値取得用
  --==============================================================================
  --                  メイン処理                                                  
  --==============================================================================
BEGIN
  IF DEBUG = 1 THEN
    CALL pkLog.debug(USER_ID,
                PROGRAM_ID,
                '--------------------------------------------------Start--------------------------------------------------');
    CALL pkLog.debug(USER_ID,
                PROGRAM_ID,
                '引数（委託会社コードD）：' || l_initakuKaishaCd);
  END IF;
  -- 入力パラメータのチェック
  IF coalesce(trim(both l_initakuKaishaCd)::text, '') = '' THEN
    -- パラメータエラー
    IF DEBUG = 1 THEN
      CALL pkLog.debug(USER_ID, PROGRAM_ID, 'param error');
    END IF;
    CALL pkLog.error('ECM501', PROGRAM_ID, 'SQLERRM:' || '');
    RETURN RTN_FATAL;
  END IF;
  -- 業務日付取得
  gGyomuYmd := pkDate.getGyomuYmd();
  IF DEBUG = 1 THEN
    CALL pkLog.debug(USER_ID, PROGRAM_ID, '業務日付 = ' || gGyomuYmd);
  END IF;
  -- 元利金支払基金返戻計算処理SPをcall
  IF DEBUG = 1 THEN
    CALL pkLog.debug(USER_ID, PROGRAM_ID, 'SFIPI051K00R01 CALL');
  END IF;
  pOutSqlCode := SFIPI051K00R01(l_inItakuKaishaCd,
                                USER_ID,
                                CHOHYO_KBN,
                                gGyomuYmd);
  IF DEBUG = 1 THEN
    CALL pkLog.debug(USER_ID, PROGRAM_ID, '返値（' || pOutSqlCode || '）');
    CALL pkLog.debug(USER_ID,
                PROGRAM_ID,
                '---------------------------------------------------End---------------------------------------------------');
  END IF;
  -- 終了処理
  RETURN pOutSqlCode;
  -- 例外処理
EXCEPTION
  WHEN OTHERS THEN
    CALL pkLog.fatal(MSG_ID, PROGRAM_ID, 'SQLCODE:' || SQLSTATE);
    CALL pkLog.fatal(MSG_ID, PROGRAM_ID, 'SQLERRM:' || SQLERRM);
    RETURN RTN_FATAL;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi051k00r00_01 (l_inItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE) FROM PUBLIC;