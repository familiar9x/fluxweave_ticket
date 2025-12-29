




CREATE OR REPLACE FUNCTION sfipf010k01r02 ( 
 l_inDenbunId TEXT,								-- ＪＩＰ電文コード
 l_inItakuId TEXT,	-- 委託会社コード
 l_inKessaiNo TEXT 			-- 決済番号
 ) RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2016
-- * 会社名: JIP
-- *
-- * 資金決済予定データ（新規記録）作成処理を、ＲＴＧＳ−ＸＧ用 又は債券決済代行システム用の
-- * 処理に振り分けを行う。
-- * 
-- * @author 村木 明広
-- * @version $Id:$
-- * 
-- * @param  l_inDenbunId   IN     CHAR						ＪＩＰ電文コード
-- *         l_inItakuId    IN     CHAR						委託会社コード
-- *         l_inKessaiNo   IN     CHAR						決済番号
-- * @return INTEGER
-- *                0:正常終了
-- *               99:異常終了
-- *               それ以外：エラー
-- 
--==============================================================================
--                  定数定義                                                    
--==============================================================================
	-- ファンクションＩＤ
	C_FUNCTION_ID			CONSTANT text	:= 'SFIPF010K01R02';
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	nRtnCd			numeric;									-- リターン値
	vKaiinId		TEXT;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	CALL pkLog.debug('BATCH', C_FUNCTION_ID, '***** ' || C_FUNCTION_ID || ' START *****');
	nRtnCd := 0;
	vKaiinId := pkConstant.getKaiinId();
	IF l_inItakuId = vKaiinId THEN
		-- （ＲＴＳＧ−ＸＧ）資金決済予定データ（新規記録）
		nRtnCd := SFIPXB16K15R01('IF26-1', l_inItakuId, l_inKessaiNo);
	ELSE
		-- （債券決済代行）資金決済予定データ（新規記録）
		nRtnCd := SFIPXB09K15R01('IF24-1', l_inItakuId, l_inKessaiNo);
	END IF;
	CALL pkLog.debug('BATCH', C_FUNCTION_ID, '***** ' || C_FUNCTION_ID || ' END *****');
	RETURN nRtnCd;
--==============================================================================
--                  エラー処理                                                  
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf010k01r02 ( l_inDenbunId CHAR, l_inItakuId nyukin_yotei.itaku_kaisha_cd%type, l_inKessaiNo nyukin_yotei.kessai_no%type  ) FROM PUBLIC;