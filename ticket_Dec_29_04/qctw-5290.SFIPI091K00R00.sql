




CREATE OR REPLACE FUNCTION sfipi091k00r00 () RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 財務代理人手数料請求書と請求一覧表データを作成する。（バッチ用）
-- * １．自行委託会社VIEW検索処理
-- * ２．財務代理人手数料請求データ作成処理
-- *
-- * @author 山下　健太(NOA)
-- * @version $Revision: 1.5 $
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
			VJIKO_ITAKU
		WHERE
			DAIKO_FLG = '0'
			OR KAIIN_ID <> pkConstant.getKaiinId();
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	CALL pkLog.debug('Batch', 'sfIpi091K00R00', '--------------------------------------------------Start--------------------------------------------------');
	FOR rec IN CUR_DATA LOOP
		gReturnCode := sfIpi091K00R00_01(rec.KAIIN_ID);
		--対象データなしの場合、正常終了（但し、デバッグログを書き出す）
		IF gReturnCode = PKIPACALCTESURYO.C_NODATA() THEN
			gReturnCode := pkconstant.success();
			CALL pkLog.debug('Batch', 'sfIpi091K00R00', '委託会社：' || rec.KAIIN_ID || ' 対象データなし');
		END IF;
		IF gReturnCode <> pkconstant.success() THEN
			--ROLLBACK;
			RETURN gReturnCode;
		END IF;
	END LOOP;
	CALL pkLog.debug('Batch', 'sfIpi091K00R00', '返値（正常）');
	CALL pkLog.debug('Batch', 'sfIpi091K00R00', '---------------------------------------------------End---------------------------------------------------');
	RETURN pkconstant.success();
--=========< エラー処理 >==========================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'sfIpi091K00R00', 'エラーコード'||SQLSTATE);
		CALL pkLog.fatal('ECM701', 'sfIpi091K00R00', 'エラー内容'||SQLERRM);
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi091k00r00 () FROM PUBLIC;