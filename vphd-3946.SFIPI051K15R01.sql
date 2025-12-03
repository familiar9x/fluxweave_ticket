




CREATE OR REPLACE FUNCTION sfipi051k15r01 () RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2017
-- * 会社名: JIP
-- *
-- * 元利金支払基金返戻通知書を作成する（バッチ用）
-- *
-- * @author AXIS
-- * @version $Id: SFIPI051K15R01.sql,v 1.0 2017/02/10 09:46:34 $
-- *
-- * @return INTEGER 0:正常、99:異常、それ以外：エラー
-- 
--==============================================================================
--                  定数定義                                                        
--==============================================================================
    C_FUNCTION_ID  CONSTANT varchar(50) := 'SFIPI051K15R01';
--==============================================================================
--                  変数定義                                                        
--==============================================================================
    gReturnCode             integer := 0;
    gSqlErrm                varchar(1000);
    gKaiinID                MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE;
    gGyomuYmd               SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;
--==============================================================================
--                  メイン処理                                                    
--==============================================================================
BEGIN
    CALL pkLog.debug('BATCH', C_FUNCTION_ID , '--------------------------------------------------Start--------------------------------------------------');
    -- 業務日付を取得
    gGyomuYmd := pkDate.getGyomuYmd();
    -- 会員IDを取得
    gKaiinID := pkConstant.getKaiinId();
    -- 元利金支払基金返戻通知書の作成
    -- Create temp table to store OUT parameters
    CREATE TEMP TABLE IF NOT EXISTS temp_spipi051_result (ret_code numeric, sql_errm text);
    TRUNCATE temp_spipi051_result;
    
    -- Use dynamic SQL to call procedure and capture OUT parameters
    EXECUTE format('
        DO $$
        DECLARE
            v_retcode numeric;
            v_sqlerrm text;
        BEGIN
            CALL SPIPI051K00R01(%L, %L, %L, %L, NULL, NULL, NULL, NULL, NULL, v_retcode, v_sqlerrm);
            INSERT INTO temp_spipi051_result VALUES (v_retcode, v_sqlerrm);
        END $$;
    ', gKaiinID, 'BATCH', '1', gGyomuYmd);
    
    -- Retrieve OUT parameters from temp table
    SELECT ret_code, sql_errm INTO gReturnCode, gSqlErrm FROM temp_spipi051_result;
    --対象データなしの場合、正常終了（但し、デバッグログを書き出す）
    IF gReturnCode = PKIPACALCTESURYO.C_NODATA() THEN
   		-- 対象データなしのレコードを削除する。(ステ管用)
		DELETE FROM SREPORT_WK
		WHERE KEY_CD = gKaiinID
		  AND USER_ID = 'BATCH'
		  AND CHOHYO_KBN = '1'
		  AND SAKUSEI_YMD = gGyomuYmd
		  AND CHOHYO_ID = 'IP030005111';
        gReturnCode := pkconstant.success();
        CALL pkLog.debug('Batch', C_FUNCTION_ID, '委託会社：' || gKaiinID || ' 対象データなし');
    END IF;
    IF gReturnCode <> pkconstant.success() THEN
        -- 異常終了
        CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'エラーコード'||SQLSTATE);
        CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'エラー内容'||SQLERRM);
        RETURN gReturnCode;
    END IF;
    CALL pkLog.debug('BATCH', C_FUNCTION_ID, '返値（正常）');
    CALL pkLog.debug('BATCH', C_FUNCTION_ID, '---------------------------------------------------End---------------------------------------------------');
    RETURN gReturnCode;
--=========< エラー処理 >==========================================================
EXCEPTION
    WHEN OTHERS THEN
        CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'SQLCODE:'||SQLSTATE);
        CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'SQLERRM:'||SQLERRM);
        RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi051k15r01 () FROM PUBLIC;
