




CREATE OR REPLACE FUNCTION sfipx217k15r02 () RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2017
-- * 会社名: JIP
-- *
-- * 事務代行手数料管理用データ作成を作成する。
-- * １．自行委託会社VIEW検索処理
-- * ２．事務代行手数料管理用データ作成処理
-- *
-- * @author Y.Nagano
-- * @version $Id: SFIPX217K15R02.sql,v 1.0 2017/01/30 10:39:06 Y.Nagano Exp $
-- *
-- * @return INTEGER 0:正常、99:異常、それ以外：エラー
-- 
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	gReturnCode                      integer := 0;           -- リターン値
--==============================================================================
--                    カーソル定義                                                  
--==============================================================================
	CUR_DATA CURSOR FOR
		SELECT
			 VJ1.KAIIN_ID
			,BT02.SD_FLG
		FROM
			 VJIKO_ITAKU	VJ1
			,MITAKU_KAISHA2	BT02
		WHERE VJ1.JIKO_DAIKO_KBN = '2'
		  AND VJ1.KAIIN_ID = BT02.ITAKU_KAISHA_CD
	;
--==============================================================================
--                    関数定義                                                  
--==============================================================================
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	CALL pkLog.debug('Batch', 'SFIPX217K15R02', '--------------------------------------------------Start--------------------------------------------------');
	-- 委託会社分ループ
	FOR rec IN CUR_DATA LOOP
		-- 事務代行手数料管理用データ作成処理
		gReturnCode := SFIPX217K15R02_01(rec.KAIIN_ID, rec.SD_FLG);
		IF gReturnCode <> pkconstant.success() THEN
			--ROLLBACK;
			RETURN gReturnCode;
		END IF;
	END LOOP;
	CALL pkLog.debug('Batch', 'SFIPX217K15R02', '返値（正常）');
	CALL pkLog.debug('Batch', 'SFIPX217K15R02', '---------------------------------------------------End---------------------------------------------------');
	RETURN pkconstant.success();
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'SFIPX217K15R02', 'エラーコード'||SQLSTATE);
		CALL pkLog.fatal('ECM701', 'SFIPX217K15R02', 'エラー内容'||SQLERRM);
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipx217k15r02 () FROM PUBLIC;