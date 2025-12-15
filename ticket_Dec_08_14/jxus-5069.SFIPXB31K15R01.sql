




CREATE OR REPLACE FUNCTION sfipxb31k15r01 ( l_inSaveSpan integer ) RETURNS integer AS $body$
DECLARE

	
	deleteBaseDate	char(8);

BEGIN
	CALL pkLog.debug(pkconstant.BATCH_USER(),  '○' || '外部IF送受信テーブルガベージ処理' ||'('|| 'SFIPXB31K15R01'||')', ' START');
	CALL pkLog.debug(pkconstant.BATCH_USER(), '引数1：' || l_inSaveSpan, '');
	IF coalesce(l_inSaveSpan::text, '') = '' THEN
		RAISE EXCEPTION 'para_error' USING ERRCODE = '50001';
	END IF;
	deleteBaseDate := pkDate.getMinusDateBusiness(pkDate.getGyomuYmd(), l_inSaveSpan);
	CALL pkLog.debug(pkconstant.BATCH_USER(), deleteBaseDate || '以前のデータ', '削除');
	delete from GAIBU_IF_KANRI where IF_MAKE_DT <= deleteBaseDate and IF_MAKE_DT <> '00000000';
	delete from GAIBU_IF_DATA where IF_MAKE_DT <= deleteBaseDate;
	--汎用ダウンロード用に更新しているテーブルも、同じタイミングでガベージを行う。
	delete from KOZA_FRK_DATA_DL_WK where DATA_RENKEI_YMD <= deleteBaseDate;
	CALL pkLog.debug(pkconstant.BATCH_USER(),  '○' || '外部IF送受信テーブルガベージ処理' ||'('|| 'SFIPXB31K15R01'||')', ' END');
	RETURN pkconstant.success();
EXCEPTION
	WHEN SQLSTATE '50001' THEN
		CALL pkLog.error('ECM501', 'SFIPXB31K15R01', '');
		RETURN pkconstant.error();
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'SFIPXB31K15R01', 'SQLERRM:'||SQLERRM);
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipxb31k15r01 ( l_inSaveSpan integer ) FROM PUBLIC;