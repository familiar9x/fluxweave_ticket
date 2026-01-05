




CREATE OR REPLACE FUNCTION sfipi115k00r00 () RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2010
-- * 会社名: JIP
-- *
-- * 残存額通知予定データを作成する。（バッチ用）
-- * １．自行委託会社VIEW検索処理
-- * ２．残存額通知予定データ
-- *
-- * @author JIP
-- * @version $Id: SFIPI115K00R00.sql,v 1.1 2010/08/02 10:59:29 kanayama Exp $
-- *
-- * @return INTEGER 0:正常、99:異常、それ以外：エラー
-- 
--==============================================================================
--                  定数定義                                                    
--==============================================================================
	FUNC_NAME         CONSTANT varchar(14) := 'SFIPI115K00R00';         -- ファンクション名
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	gReturnCode                      integer := 0;
--==============================================================================
--                  カーソル定義                                                
--==============================================================================
	CUR_DATA CURSOR FOR
		SELECT
			KAIIN_ID
		FROM
			VJIKO_ITAKU;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	CALL pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME, '------------------------------Start------------------------------');
	FOR rec IN CUR_DATA LOOP
		gReturnCode := SFIPI115K00R01(rec.KAIIN_ID);
		IF gReturnCode <> pkconstant.success() THEN
			--ROLLBACK;
			RETURN gReturnCode;
		END IF;
	END LOOP;
	CALL pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME, '返値（正常）');
	CALL pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME, '-------------------------------End-------------------------------');
	RETURN pkconstant.success();
--=========< エラー処理 >==========================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', FUNC_NAME, 'エラーコード'||SQLSTATE);
		CALL pkLog.fatal('ECM701', FUNC_NAME, 'エラー内容'||SQLERRM);
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi115k00r00 () FROM PUBLIC;