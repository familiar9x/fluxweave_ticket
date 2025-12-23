




CREATE OR REPLACE FUNCTION sfiph001k00r32 () RETURNS numeric AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2006
-- * 会社名:JIP
-- *
-- * 概要　:元利払手数料の非分配分の会計処理の起動をかける
-- *        （親ＳＰより、委託会社コード、委託会社略称を引数として渡す）
-- *
-- * 返り値: 0:正常
-- *        99:異常
-- *
-- * @author ASK
-- * @version $Id: SFIPH001K00R32.sql,v 1.3 2007/04/02 05:41:01 kuwabara Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2006.06.26 ASK         新規作成
-- ***************************************************************************
--
	--==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_FUNCTION_ID CONSTANT text := 'SFIPH001K00R32'; -- ファンクションＩＤ
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	gReturnCd numeric := 0; -- リターン値
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	curItaku_Kaisha CURSOR FOR
		SELECT
			KAIIN_ID,                                           -- 会員ＩＤ（委託会社コード）
			CASE WHEN JIKO_DAIKO_KBN='1' THEN ' '  ELSE BANK_RNM END  AS BANK_RNM  -- 銀行略称（委託会社略名）
		FROM
			VJIKO_ITAKU
		WHERE
			DAIKO_FLG = '0'
		OR	KAIIN_ID <> pkConstant.getKaiinId();
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	CALL pkLog.debug(pkconstant.BATCH_USER(), C_FUNCTION_ID, C_FUNCTION_ID||' START');
	-- データ取得
	FOR recMeisai IN curItaku_Kaisha
	LOOP
		CALL pkLog.debug(pkconstant.BATCH_USER(), C_FUNCTION_ID, '取得データ');
		CALL pkLog.debug(pkconstant.BATCH_USER(), C_FUNCTION_ID, '会員ＩＤ（委託会社コード）:"' || recMeisai.KAIIN_ID ||'"');
		CALL pkLog.debug(pkconstant.BATCH_USER(), C_FUNCTION_ID, '銀行略称（委託会社略名）:"' || recMeisai.BANK_RNM ||'"');
		-- 帳票作成ＳＰ（子ＳＰ）
		gReturnCd := SFIPH001K00R32_01(recMeisai.KAIIN_ID);
		-- エラーの場合
		IF gReturnCd = pkconstant.fatal() THEN
			CALL pkLog.fatal('ECM701', SUBSTR(C_FUNCTION_ID,3,12), '請求データ未入力リスト作成エラー');
			-- エラーリターン（終了）
			RETURN pkconstant.fatal();
		END IF;
	END LOOP;
	CALL pkLog.debug(pkconstant.BATCH_USER(), C_FUNCTION_ID, C_FUNCTION_ID ||' END');
	-- 終了処理
	RETURN pkconstant.success();
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SUBSTR(C_FUNCTION_ID,3,12), 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', SUBSTR(C_FUNCTION_ID,3,12), 'SQLERRM:' || SQLERRM);
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfiph001k00r32 () FROM PUBLIC;