
CREATE OR REPLACE FUNCTION sfipp002k00r00 () RETURNS integer AS $body$
DECLARE
--*
-- * 著作権:Copyright(c)2007
-- * 会社名:JIP
-- *
-- * 概要　:社債原簿（実質記番号方式）作成・メイン（バッチ用）
-- *
-- * 返り値: 0:正常
-- *        99:異常
-- *
-- * @author ASK
-- * @version $Id: SFIPP002K00R00.sql,v 1.2 2007/09/11 08:42:31 nakamura Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2007.05.02 中村        新規作成
-- ***************************************************************************
	/*==============================================================================
	--                  定数定義                                                    
	--==============================================================================*/
	C_PROGRAM_ID CONSTANT varchar(50) := 'SFIPP002K00R00'; -- プログラムＩＤ
	C_NO_DATA    CONSTANT integer      := 2;                -- 対象データなし
	C_OPTION_CD	 CONSTANT varchar(50) := 'IPP1003302010'; -- 実質記番号管理オプションコード
	/*==============================================================================
	--                  変数定義                                                    
	--==============================================================================*/
	gSqlCode  integer;                             -- リターン値
	gGyomuYmd   char(8); -- 業務日付
	gGetsumatsu char(8); -- 月末の営業日
	gYokuGyoYmd char(8); -- 業務日付の翌営業日付取得
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
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
--	pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '業務日付:"' || gGyomuYmd || '"');
	-- 月末の営業日取得
	gGetsumatsu := pkDate.getGetsumatsuBusinessYmd(gGyomuYmd, 0);
--	pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '月末の営業日:"' || gGetsumatsu || '"');
	-- 業務日付の翌営業日付取得
	gYokuGyoYmd := pkDate.getYokuBusinessYmd(gGyomuYmd);
--	pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '翌営業日付:"' || gYokuGyoYmd || '"');
	-- 業務日付 = 月末の営業日なら処理を実行
	IF gGyomuYmd = gGetsumatsu THEN
		-- 委託会社読込
		FOR recItaku IN curItaku
		LOOP
			-- オプションフラグチェック
			-- 実質記番号管理のオプションフラグが'1'の場合のみ処理を行う
			IF pkControl.getOPTION_FLG(recItaku.KAIIN_ID, C_OPTION_CD, '0') = '1' THEN
				-- 原簿ワーク（実質記番号）作成-------------------------------------------------------------
				gSqlCode := SFIPP002K00R01_01(
												recItaku.KAIIN_ID,       -- 委託会社コード
												gGyomuYmd,               -- 業務日付
												pkconstant.BATCH_USER(),   -- ユーザーＩＤ
												'1',                     -- 帳票区分
												NULL,                    -- 銘柄コード
												NULL,                    -- ＩＳＩＮコード
												SUBSTRING(gGyomuYmd FROM 1 FOR 6), -- 基準年月
												gSqlErrM                  -- エラーコメント
											);
--				pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '原簿ワーク（実質記番号）作成引数');
--				pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '委託会社コード:"' || recItaku.KAIIN_ID || '"');
--				pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '業務日付:"' || gGyomuYmd || '"');
--				pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, 'ユーザーＩＤ:"' || pkconstant.BATCH_USER() || '"');
--				pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '帳票区分:1');
--				pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '銘柄コード:NULL');
--				pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, 'ＩＳＩＮコード:NULL');
--				pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '基準年月:"' || SUBSTRING(gGyomuYmd FROM 1 FOR 6) || '"');
				-- エラー判定
				IF gSqlCode != pkconstant.success() THEN
					CALL pkLog.error(pkconstant.BATCH_USER(), C_PROGRAM_ID, '原簿ワーク（実質記番号）作成失敗：' || gSqlErrM);
					RETURN gSqlCode;
				END IF;
				--------------------------------------------------------------------------------------------
	
				-- 社債原簿（実質記番号方式）作成-----------------------------------------------------------
				CALL SPIPP002K00R01_02(
									recItaku.KAIIN_ID,     -- 委託会社コード
									gGyomuYmd,             -- 業務日付
									pkconstant.BATCH_USER(), -- ユーザーＩＤ
									'1',                   -- 帳票区分
									gYokuGyoYmd,           -- 通知日（業務日付の翌営業日付）
									gSqlCode,              -- リターン値
									gSqlErrM                -- エラーコメント
								);
--				pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '社債原簿（実質記番号方式）作成引数');
--				pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '委託会社コード:"' || recItaku.KAIIN_ID || '"');
--				pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '業務日付:"' || gGyomuYmd || '"');
--				pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, 'ユーザーＩＤ:"' || pkconstant.BATCH_USER() || '"');
--				pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '帳票区分:1');
--				pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '通知日:"' || gYokuGyoYmd || '"');
				-- 対象データなし判定
				IF gSqlCode = C_NO_DATA THEN
					gSqlCode := pkconstant.success();
--					pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '対象データなし');
				END IF;
				-- エラー判定
				IF gSqlCode != pkconstant.success() THEN
					CALL pkLog.error(pkconstant.BATCH_USER(), C_PROGRAM_ID, '社債原簿（実質記番号方式）作成失敗：' || gSqlErrM);
					RETURN gSqlCode;
				END IF;
				--------------------------------------------------------------------------------------------
			END IF;
		END LOOP;
--	ELSE
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '業務日付 = 月末の営業日でない為、処理を実行しないで終了');
	END IF;
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
-- REVOKE ALL ON FUNCTION sfipp002k00r00 () FROM PUBLIC;

