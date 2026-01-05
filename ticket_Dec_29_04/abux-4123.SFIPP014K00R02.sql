
CREATE OR REPLACE FUNCTION sfipp014k00r02 () RETURNS integer AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2007
-- * 会社名:JIP
-- *
-- * 概要　:カレンダ修正に伴う銘柄期日調整（実質記番号管理償還回次）
-- *
-- * 引数　:なし
-- *
-- * 返り値: 0:正常
-- *        99:異常
-- *
-- * @author ASK
-- * @version $Id: SFIPP014K00R02.sql,v 1.2 2008/09/10 01:20:57 harada Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2007.07.03 中村        新規作成
-- ***************************************************************************
--
	--==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_FUNCTION_ID CONSTANT varchar(50) := 'SFIPP014K00R02'; -- ファンクションＩＤ
	C_NO_DATA     CONSTANT numeric(1)    := 2;                -- 対象データなし
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	gSqlCode integer; -- リターン値
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	curItakuKaisha CURSOR FOR
		SELECT
			KAIIN_ID  -- 会員ＩＤ（委託会社コード）
		FROM
			VJIKO_ITAKU;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	FOR recItakuKaisha IN curItakuKaisha
	LOOP
		-- 実質記番号管理償還回次調整情報テーブル作成
		gSqlCode := SFIPP014K00R02_01(
										recItakuKaisha.KAIIN_ID  -- 委託会社コード
									);
--		pkLog.debug(pkconstant.BATCH_USER(), C_FUNCTION_ID, 'SFIPP014K00R02_01の引数');
--		pkLog.debug(pkconstant.BATCH_USER(), C_FUNCTION_ID, '第一引数（委託会社コード）:"' || recItakuKaisha.KAIIN_ID || '"');
		-- エラー判定
		IF gSqlCode = pkconstant.FATAL() THEN
			RETURN gSqlCode;
		END IF;
		-- カレンダー訂正履歴に未承認データが存在しない場合は、リストを作成しない
		IF gSqlCode = pkconstant.success() THEN
			-- 実質記番号管理償還回次期日調整リスト
			CALL SPIPP014K00R02_02(
							recItakuKaisha.KAIIN_ID, -- 委託会社コード
							pkconstant.BATCH_USER(),   -- ユーザーＩＤ
							'1',                     -- 帳票区分
							gSqlCode                  -- リターン値
							);
--			pkLog.debug(pkconstant.BATCH_USER(), C_FUNCTION_ID, 'SPIPP014K00R02_02の引数');
--			pkLog.debug(pkconstant.BATCH_USER(), C_FUNCTION_ID, '第一引数（委託会社コード）:"' || recItakuKaisha.KAIIN_ID || '"');
--			pkLog.debug(pkconstant.BATCH_USER(), C_FUNCTION_ID, '第二引数（ユーザーＩＤ）:"' || pkconstant.BATCH_USER() || '"');
--			pkLog.debug(pkconstant.BATCH_USER(), C_FUNCTION_ID, '第三引数（帳票区分）:"1"');
		END IF;
		-- 対象データなし判定
		IF gSqlCode = C_NO_DATA THEN
			gSqlCode := pkconstant.success();
--			pkLog.debug(pkconstant.BATCH_USER(), C_FUNCTION_ID, '委託会社コード：' || recItakuKaisha.KAIIN_ID || ' 対象データなし');
		END IF;
		-- エラー判定
		IF gSqlCode <> pkconstant.success() THEN
			RETURN gSqlCode;
		END IF;
	END LOOP;
	-- 終了処理
	RETURN gSqlCode;
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SUBSTRING(C_FUNCTION_ID FROM 1 FOR 12), 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', SUBSTRING(C_FUNCTION_ID FROM 1 FOR 12), 'SQLERRM:' || SQLERRM);
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipp014k00r02 () FROM PUBLIC;

