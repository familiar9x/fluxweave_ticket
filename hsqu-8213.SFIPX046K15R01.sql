




CREATE OR REPLACE FUNCTION sfipx046k15r01 () RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2017
-- * 会社名: JIP
-- *
-- * 元利払基金・手数料請求書（領収書）【単票】データを作成する（バッチ用）
-- * １．自行委託会社VIEW検索処理
-- * ２．元利払基金・手数料請求書作成処理
-- *
-- * @author Y.Nagano@Texnos
-- * @version $Id: SFIPX046K15R01.sql,v 1.0 2017/01/20 15:36:23 Y.Nagano Exp $
-- *
-- * @return INTEGER 0:正常、99:異常、それ以外：エラー
-- 
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	gReturnCode                      integer := 0;
	CUR_DATA CURSOR FOR
		-- システム設定分
		SELECT
			  KAIIN_ID
		FROM
			VJIKO_ITAKU;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	RAISE NOTICE '[DEBUG] Starting SFIPX046K15R01';
	FOR rec IN CUR_DATA LOOP
		RAISE NOTICE '[DEBUG] Processing KAIIN_ID: %', rec.KAIIN_ID;
		BEGIN
			gReturnCode := SFIPX046K15R01_01(rec.KAIIN_ID);
			RAISE NOTICE '[DEBUG] Return code: %', gReturnCode;
		EXCEPTION
			WHEN OTHERS THEN
				RAISE NOTICE '[DEBUG] Error in SFIPX046K15R01_01: SQLSTATE=%, SQLERRM=%', SQLSTATE, SQLERRM;
				RAISE;
		END;
		--対象データなしの場合、正常終了（但し、デバッグログを書き出す）
		IF gReturnCode = pkconstant.NO_DATA_FIND() THEN
			gReturnCode := pkconstant.success();
			CALL pkLog.debug('Batch', 'SFIPX046K15R01', '委託会社：' || rec.KAIIN_ID || ' 対象データなし');
		END IF;
		IF gReturnCode <> pkconstant.success() THEN
			RETURN gReturnCode;
		END IF;
	END LOOP;
	RAISE NOTICE '[DEBUG] Completed successfully';
	RETURN pkconstant.success();
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'SFIPX046K15R01', 'エラーコード'||SQLSTATE);
		CALL pkLog.fatal('ECM701', 'SFIPX046K15R01', 'エラー内容'||SQLERRM);
		RAISE NOTICE '[DEBUG] Fatal error: SQLSTATE=%, SQLERRM=%', SQLSTATE, SQLERRM;
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipx046k15r01 () FROM PUBLIC;