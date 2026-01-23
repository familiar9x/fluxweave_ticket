




CREATE OR REPLACE FUNCTION sfipfdeletefilercvif ( l_inDataId TEXT 								-- データＩＤ
 ) RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * ファイル受信ＤＢＩＦガベージ処理
-- * 
-- * @author 小網　由妃子
-- * @version $Revision: 1.2 $
-- * 
-- * @param  l_inDataId   IN     TEXT						データＩＤ
-- * @return INTEGER
-- *                0:正常終了、データ無し
-- *                1:予期したエラー
-- *               99:予期せぬエラー
-- 
--==============================================================================
--                  定数定義                                                    
--==============================================================================
--==============================================================================
--                  変数定義                                                    
--==============================================================================
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 入力パラメータ（データＩＤ）のチェック
	IF LENGTH(l_inDataId) != 5 OR
	   coalesce(trim(both l_inDataId)::text, '') = '' THEN
		CALL pkLog.error('ECM501', 'IpfDeleteFileRcvIf', '＜項目名称:データＩＤ＞' || '＜項目値:' || l_inDataId || '＞');
		RETURN pkconstant.error();
	END IF;
	-- データＩＤが'99999'の場合、ファイル受信DBIFを全件削除する。
	IF l_inDataId = '99999' THEN
		DELETE FROM filercvif;
		RETURN pkconstant.success();
	ELSE
		--'99999'以外のデータIDの場合、ファイル受信DBIFのデータIDとパラメータデータIDが同一のものを削除
		DELETE FROM filercvif
		WHERE  data_id = l_inDataId;
		RETURN pkconstant.success();
	END IF;
--==============================================================================
--                  エラー処理                                                  
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'IpfDeleteFileRcvIf', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipfdeletefilercvif ( l_inDataId TEXT  ) FROM PUBLIC;