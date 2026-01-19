




CREATE OR REPLACE FUNCTION sfipf010k01r10 () RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 当預リアル受信ＩＦテーブル　データ削除
-- *
-- * @author 渡邊　かよ
-- * @version $Revision: 1.3 $
-- *
-- * @param  なし
-- * @return INTEGER
-- *                0:正常終了、データ無し
-- *                1:予期したエラー
-- *               99:予期せぬエラー
-- 
--=============================================================================*
--    定数定義
-- *=============================================================================
        cSystemDt char(08);                                -- システム日付
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
        --データ削除
		DELETE	FROM	TOYOREALRCVIF;
        RETURN  pkconstant.success();
--==============================================================================
--                  エラー処理                                                  
--==============================================================================
    EXCEPTION
	WHEN OTHERS THEN
		-- ログ出力
		CALL pkLog.fatal(
			'ECM701',
			'IPF010K01R10',
			'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')'
		);
		RETURN pkconstant.fatal();
    END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf010k01r10 () FROM PUBLIC;