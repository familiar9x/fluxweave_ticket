




CREATE OR REPLACE FUNCTION sfipi019k15r01 () RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2017
-- * 会社名: JIP
-- *
-- * 変動利率決定通知を作成する（バッチ用）
-- *
-- * @author AXIS
-- * @version $Id: SFIPI019K15R01.sql,v 1.0 2017/02/10 09:46:34 $
-- *
-- * @return INTEGER 0:正常、99:異常、それ以外：エラー
-- 
--==============================================================================
--                  定数定義                                                        
--==============================================================================
    C_FUNCTION_ID  CONSTANT varchar(50) := 'SFIPI019K15R01';
--==============================================================================
--                  変数定義                                                        
--==============================================================================
    gReturnCode             integer := 0;
    gSqlErrm                varchar(1000);
    gKaiinID                char(4);
    gGyomuYmd               char(8);
    gYokuBusinessYmd        char(8);
--==============================================================================
--                  メイン処理                                                    
--==============================================================================
BEGIN
    CALL pkLog.debug('BATCH', C_FUNCTION_ID , '--------------------------------------------------Start--------------------------------------------------');
    -- 業務日付を取得
    gGyomuYmd := pkDate.getGyomuYmd();
    -- 会員IDを取得
    gKaiinID := pkConstant.getKaiinId();
    -- 翌営業日を取得
    gYokuBusinessYmd := pkDate.getYokuBusinessYmd(gGyomuYmd);
    -- 変動利率決定通知の作成
    SELECT sqlcode, sqlerrm INTO gReturnCode, gSqlErrm
    FROM spip01901_wrapper(
        NULL,                           -- 発行体コード
        NULL,                           -- 口座店コード
        NULL,                           -- 口座店CIFコード
        NULL,                           -- 銘柄コード
        NULL,                           -- ISINコード
        gGyomuYmd,                      -- 基準日(From)
        gGyomuYmd,                      -- 基準日(To)
        gYokuBusinessYmd,               -- 通知日
        gKaiinID,                       -- 委託会社コード
        'BATCH',                        -- ユーザID
        '1',                            -- 変動利率承認日フラグ
        '1',                            -- 帳票区分
        gGyomuYmd                       -- 業務日付
    );
    --対象データなしの場合、正常終了（但し、デバッグログを書き出す）
    IF gReturnCode = PKIPACALCTESURYO.C_NODATA() THEN
		-- 対象データなしのレコードを削除する。(ステ管用)
		DELETE FROM SREPORT_WK
		WHERE KEY_CD = gKaiinID
		  AND USER_ID = 'BATCH'
		  AND CHOHYO_KBN = '1'
		  AND SAKUSEI_YMD = gGyomuYmd
		  AND CHOHYO_ID = 'IP030001911';
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
-- REVOKE ALL ON FUNCTION sfipi019k15r01 () FROM PUBLIC;
