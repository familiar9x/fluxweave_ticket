--==============================================================================*
--    カレンダ情報の移行（Ｓ個別）用
-- *==============================================================================





CREATE OR REPLACE FUNCTION sfipf004k00r05 () RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * カレンダ情報の移行（Ｓ個別）を呼び出し、リターンコードを返す
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
	wk_kaiin        SOWN_INFO.KAIIN_ID%type;
	return_r02	integer;
	return_r05	integer;
        return_Sql      text;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
        -- 会員ＩＤ取得
        SELECT KAIIN_ID INTO STRICT wk_kaiin FROM SOWN_INFO;
        -- カレンダ情報の移行（Ｓ個別）実行 
        CALL SPIPF004K00R02(wk_kaiin, '30', return_r02, return_Sql);
        -- カレンダ情報の移行（Ｓ個別）実行結果により、リターンコードを付与 
	IF      return_r02   =    pkconstant.success()      THEN
                return_r05   :=   0;
        ELSIF   return_r02   =    pkconstant.error()        THEN
                return_r05   :=   1;
        ELSIF   return_r02   =    pkconstant.NO_DATA_FIND() THEN
                return_r05   :=   0;
        ELSIF   return_r02   =    pkconstant.FATAL()        THEN
                return_r05   :=   99;
        END IF;
        -- コミット・ロールバック処理 (PostgreSQL: Cannot use in function context)
        -- IF  return_r05  =  99  THEN
        --     rollback;
        -- ELSE
        --     commit;
        -- END IF;
        RETURN  return_r05;
--==============================================================================
--                  エラー処理                                                  
--==============================================================================
    EXCEPTION
	WHEN OTHERS THEN
		-- ログ出力
		CALL pkLog.fatal(
			'ECM701',
			'IPF004K00R05',
			'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')'
		);
      	        return_r05 := 99;
                RETURN return_r05;
    END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf004k00r05 () FROM PUBLIC;