
CREATE OR REPLACE FUNCTION sfipp005k00r00 () RETURNS integer AS $body$
DECLARE
--*
-- * 著作権:Copyright(c)2007
-- * 会社名:JIP
-- *
-- * 概要　:決済方法別元利払一覧表（実質記番号方式）作成・メイン（バッチ用）
-- *
-- * 返り値: 0:正常
-- *        99:異常
-- *
-- * @author ASK
-- * @version $Id: SFIPP005K00R00.sql,v 1.2 2007/09/11 05:26:38 nakamura Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2007.07.11 叶          新規作成
-- ***************************************************************************
	/*==============================================================================
	--                  定数定義                                                    
	--==============================================================================*/
	C_PROGRAM_ID CONSTANT varchar(50) := 'SFIPP005K00R00'; -- プログラムＩＤ
	C_NO_DATA    CONSTANT integer      := 2;                -- 対象データなし
	C_OPTION_CD	 CONSTANT varchar(50) := 'IPP1003302010'; -- 実質記番号管理オプションコード
	/*==============================================================================
	--                  変数定義                                                    
	--==============================================================================*/
	gSqlCode    integer;                           -- リターン値
	gSqlErrM    varchar(1000);                     -- エラーコメント
	/*==============================================================================
	--                  カーソル定義                                                
	--==============================================================================*/
	curItaku CURSOR FOR
		SELECT
			KAIIN_ID
		FROM
			VJIKO_ITAKU;
/*==============================================================================
--                  メイン処理                                                  
--==============================================================================*/
BEGIN
--	pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, C_PROGRAM_ID || ' START');
	-- 委託会社読込
	FOR recItaku IN curItaku
	LOOP
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '決済方法別元利払一覧表（実質記番号）作成引数');
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '委託会社コード:"' || recItaku.KAIIN_ID || '"');
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, 'ユーザーＩＤ:"' || pkconstant.BATCH_USER() || '"');
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '帳票区分:1');
		-- オプションフラグチェック
		-- 実質記番号管理のオプションフラグが'1'の場合のみ処理を行う
		IF pkControl.getOPTION_FLG(recItaku.KAIIN_ID, C_OPTION_CD, '0') = '1' THEN
			-- 決済方法別元利払一覧表（実質記番号）作成-------------------------------------------------------------
			CALL SPIPP005K00R01(
							recItaku.KAIIN_ID,     -- 委託会社コード
							pkconstant.BATCH_USER(), -- ユーザーＩＤ
							'1',                   -- 帳票区分
							NULL,                  -- 基準年月
							gSqlCode,              -- リターン値
							gSqlErrM                -- エラーコメント
						);
			-- 対象データなし判定
			IF gSqlCode = C_NO_DATA THEN
				gSqlCode := pkconstant.success();
--				pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '対象データなし');
			END IF;
			-- エラー判定
			IF gSqlCode != pkconstant.success() THEN
				CALL pkLog.error(pkconstant.BATCH_USER(), C_PROGRAM_ID, '決済方法別元利払一覧表（実質記番号）作成失敗：' || gSqlErrM);
				RETURN gSqlCode;
			END IF;
			--------------------------------------------------------------------------------------------
		END IF;
	END LOOP;
	-- 正常終了
	gSqlErrM := '';
	RETURN pkconstant.success();
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'SQLERRM:' || SQLERRM);
		gSqlErrM := SQLSTATE || SQLERRM;
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipp005k00r00 () FROM PUBLIC;

