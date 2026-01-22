




CREATE OR REPLACE FUNCTION sfipf013k01r05 () RETURNS numeric AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 勘定系リアル受信IFテーブルのデータを削除する。
-- * 
-- * @author 小網　由妃子
-- * @version $Revision: 1.3 $
-- 
--==============================================================================
--					変数定義													
--==============================================================================
	nCount			 numeric;			-- 件数カウンタ
--==============================================================================
--					メイン処理													
--==============================================================================
BEGIN
	-- 勘定系リアル受信IFテーブルのレコード数を確認する
	SELECT COUNT(*)
	INTO STRICT nCount 
	FROM   knjrealrcvif;
	-- レコードが存在した場合
	IF nCount != 0 THEN
		DELETE FROM knjrealrcvif;
	END IF;
	RETURN pkconstant.success();
--==============================================================================
--					エラー処理													
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'IPF013K01R05', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf013k01r05 () FROM PUBLIC;