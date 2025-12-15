




CREATE OR REPLACE FUNCTION sfipxb35k15r01 () RETURNS integer AS $body$
BEGIN
	CALL pkLog.debug(pkconstant.BATCH_USER(),  '○' || '外部IF採番テーブルクリア処理' ||'('|| 'SFIPXB35K15R01'||')', ' START');
	UPDATE NO_RENKEI SET IF_NO = 0;
	UPDATE NO_RENKEI SET IF_NO = 80000 WHERE IF_NO_KBN = '04';
	CALL pkLog.debug(pkconstant.BATCH_USER(),  '○' || '外部IF採番テーブルクリア処理' ||'('|| 'SFIPXB35K15R01'||')', ' END');
	RETURN pkconstant.success();
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'SFIPXB35K15R01', 'SQLERRM:'||SQLERRM);
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipxb35k15r01 () FROM PUBLIC;