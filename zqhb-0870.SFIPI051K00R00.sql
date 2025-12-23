




CREATE OR REPLACE FUNCTION sfipi051k00r00 () RETURNS integer AS $body$
DECLARE

  --*
--  * 著作権: Copyright (c) 2005
--  * 会社名: JIP
--  *
--  * 元利金支払基金返戻通知書データを作成する。（バッチ用）
--  * １．自行委託会社VIEW検索処理
--  * ２．元利金支払基金返戻通知書データ作成処理
--  *
--  * @author 高橋　知之(NOA)
--  * @version $Revision: 1.3 $
--  *
--  * @return INTEGER 0:正常、99:異常、それ以外：エラー
--  
  --==============================================================================
  --                  デバッグ機能                                                 
  --==============================================================================
  DEBUG numeric(1) := 1;
  --==============================================================================
  --                  定数定義                                                    
  --==============================================================================
  USER_ID    CONSTANT varchar(8) := pkconstant.BATCH_USER(); -- ユーザーID
  PROGRAM_ID CONSTANT varchar(14) := 'SFIPI051K00R00'; -- プログラムID
  RTN_FATAL  CONSTANT numeric := 99; -- エラー
  MSG_ID     CONSTANT char(6) := 'ECM701'; -- エラーメッセージID
  --==============================================================================
  --                  変数定義                                                    
  --==============================================================================
  gReturnCode            integer := 0; -- リターン値
  gSeqNo                 numeric := 0; -- シーケンス(デバッグ用)
  gGyomuYmd              SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE; -- 業務日付
  -- 委託会社コード取得用カーソル
  CUR_DATA CURSOR FOR
  -- システム設定分
    SELECT KAIIN_ID FROM VJIKO_ITAKU;
  -- レコード型変数
  recItaku RECORD;
  --==============================================================================
  --                  メイン処理                                                  
  --==============================================================================
BEGIN
  IF DEBUG = 1 THEN
    CALL pkLog.debug(USER_ID,
                PROGRAM_ID,
                '--------------------------------------------------Start--------------------------------------------------');
  END IF;
  -- 業務日付取得
  gGyomuYmd := pkDate.getGyomuYmd();
  -- 取得データログ
  IF DEBUG = 1 THEN
    CALL pkLog.debug(USER_ID, PROGRAM_ID, '業務日付 = ' || gGyomuYmd);
  END IF;
  FOR recItaku IN CUR_DATA LOOP
	-- 元利金支払基金返戻計算処理SPをcall
	IF DEBUG = 1 THEN
		CALL pkLog.debug(USER_ID, PROGRAM_ID, 'SFIPI051K00R01 CALL(' || recItaku.KAIIN_ID || ')');
	END IF;
	gReturnCode := SFIPI051K00R01(recItaku.KAIIN_ID, USER_ID, '1', gGyomuYmd);
    IF gReturnCode <> pkconstant.success() THEN
      --ROLLBACK;
      RETURN gReturnCode;
    END IF;
    -- カウントアップ
    gSeqNo := gSeqNo + 1;
  END LOOP;
  IF DEBUG = 1 THEN
    CALL pkLog.debug(USER_ID, PROGRAM_ID, 'ROWCOUNT:' || gSeqNo);
    CALL pkLog.debug(USER_ID, PROGRAM_ID, '返値（正常）');
    CALL pkLog.debug(USER_ID,
                PROGRAM_ID,
                '---------------------------------------------------End---------------------------------------------------');
  END IF;
  -- 終了処理
  RETURN pkconstant.success();
  -- エラー処理
EXCEPTION
  WHEN OTHERS THEN
    CALL pkLog.fatal(MSG_ID, PROGRAM_ID, 'SQLCODE:' || SQLSTATE);
    CALL pkLog.fatal(MSG_ID, PROGRAM_ID, 'SQLERRM:' || SQLERRM);
    RETURN RTN_FATAL;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi051k00r00 () FROM PUBLIC;