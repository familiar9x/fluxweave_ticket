




CREATE OR REPLACE FUNCTION sfipx117k15r01 () RETURNS numeric AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2016
-- * 会社名: JIP
-- *
-- *警告連絡情報リスト、公社債関連管理リストを作成する。（バッチ用）
-- * １．SFIPX117K15R01_01呼び出し処理
-- *
-- * @author Y.Yamada
-- * @version $Id: SFIPX117K15R01.sql,v 1.0 2017/02/10 10:19:30 Y.Yamada Exp $
-- *
-- * @return INTEGER 0:正常
-- *                99:異常、それ以外：エラー
-- 
--==============================================================================
--                変数定義                                                      
--==============================================================================
	gRtnCd integer := pkconstant.success();  -- リターンコード
--==============================================================================
--                カーソル定義                                                  
--==============================================================================
	curMeisai CURSOR FOR
	SELECT
		KAIIN_ID,       --会員ID
		CASE WHEN JIKO_DAIKO_KBN='1' THEN  ' '  ELSE BANK_RNM END  AS BANK_RNM,       --委託会社略称
		JIKO_DAIKO_KBN   --自行代行区分
	FROM
		VJIKO_ITAKU VJ1
	WHERE
		VJ1.KAIIN_ID <> '9999'; --他金融機関を除外する
--==============================================================================
--                メイン処理                                                    
--==============================================================================
BEGIN
FOR recMeisai IN curMeisai LOOP
	    gRtnCd := SFIPX117K15R01_01(recMeisai.KAIIN_ID,
					recMeisai.BANK_RNM,
					recMeisai.JIKO_DAIKO_KBN
					);
END LOOP;
	RETURN gRtnCd;
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipx117k15r01 () FROM PUBLIC;