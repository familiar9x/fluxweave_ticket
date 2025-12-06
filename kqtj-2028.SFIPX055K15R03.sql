




CREATE OR REPLACE FUNCTION sfipx055k15r03 () RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2016
-- * 会社名: JIP
-- *
-- * 公社債関連資金受入予定表（信託報酬・期中手数料）を作成する。（バッチ用）
-- * １．自行委託会社VIEW検索処理
-- * ２．公社債関連資金受入予定表データ作成処理
-- *
-- * @author Y.Nagano
-- * @version $Id: SFIPX055K15R03.sql,v 1.0 2016/12/06 11:05:05 Y.Nagano Exp $
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
			, CASE WHEN JIKO_DAIKO_KBN='1' THEN ''  ELSE BANK_RNM END  AS BANK_RNM
		FROM
			VJIKO_ITAKU;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	FOR rec IN CUR_DATA LOOP
		gReturnCode := sfipx055k15r03_01(rec.KAIIN_ID,rec.BANK_RNM);
		--対象データなしの場合、正常終了（但し、デバッグログを書き出す）
		IF gReturnCode = pkconstant.NO_DATA_FIND() THEN
			gReturnCode := pkconstant.success();
		END IF;
		IF gReturnCode <> pkconstant.success() THEN
			RETURN gReturnCode;
		END IF;
	END LOOP;
	RETURN pkconstant.success();
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'sfIpx055K15R03', 'エラーコード'||SQLSTATE);
		CALL pkLog.fatal('ECM701', 'sfIpx055K15R03', 'エラー内容'||SQLERRM);
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipx055k15r03 () FROM PUBLIC;