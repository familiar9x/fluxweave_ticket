
CREATE OR REPLACE FUNCTION sfipp004k00r00 () RETURNS integer AS $body$
DECLARE
--*
-- * 著作権:Copyright(c)2007
-- * 会社名:JIP
-- *
-- * 概要　:振込案内（実質記番号方式）作成・メイン（バッチ用）
-- *
-- * 返り値: 0:正常
-- *        99:異常
-- *
-- * @author ASK
-- * @version $Id: SFIPP004K00R00.sql,v 1.2 2007/09/11 05:25:45 nakamura Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2007.06.21 叶          新規作成
-- ***************************************************************************
	/*==============================================================================
	--                  定数定義                                                    
	--==============================================================================*/
	C_PROGRAM_ID CONSTANT varchar(50) := 'SFIPP004K00R00'; -- プログラムＩＤ
	C_NO_DATA    CONSTANT integer      := 2;                -- 対象データなし
	C_OPTION_CD	 CONSTANT varchar(50) := 'IPP1003302010'; -- 実質記番号管理オプションコード
	/*==============================================================================
	--                  変数定義                                                    
	--==============================================================================*/
	gSqlCode    integer;                           -- リターン値
	gGyomuYmd   char(8); -- 業務日付
	gYokuGyoYmd char(8); -- 業務日付の翌営業日付
	gRbrKjtFrom char(8);           -- バッチ用元利払期日FROM
	gRbrKjtTo   char(8);           -- バッチ用元利払期日TO
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
	CALL pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, C_PROGRAM_ID || ' START');
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
	CALL pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '業務日付:"' || gGyomuYmd || '"');
	-- 業務日付の翌営業日付取得
	gYokuGyoYmd := pkDate.getYokuBusinessYmd(gGyomuYmd);
	CALL pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '翌営業日付:"' || gYokuGyoYmd || '"');
	-- 元利払期日FROM
	gRbrKjtFrom := pkDate.getPlusDate(gGyomuYmd, 21);
	gRbrKjtFrom := pkDate.getPlusDate(gRbrKjtFrom, 1);
	CALL pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '元利払期日FROM:"' || gRbrKjtFrom || '"');
	-- 元利払期日TO
	gRbrKjtTo := pkDate.getPlusDateBusiness(gGyomuYmd, 1);
	gRbrKjtTo :=pkDate.getPlusDate(gRbrKjtTo, 21);
	CALL pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '元利払期日TO:"' || gRbrKjtTo || '"');
	-- 委託会社読込
	FOR recItaku IN curItaku
	LOOP
		CALL pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '振込案内（実質記番号）作成引数');
		CALL pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '委託会社コード:"' || recItaku.KAIIN_ID || '"');
		CALL pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, 'ユーザーＩＤ:"' || pkconstant.BATCH_USER() || '"');
		CALL pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '帳票区分:1');
		CALL pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '銘柄コード:NULL');
		CALL pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, 'ＩＳＩＮコード:NULL');
		CALL pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '基準日FROM:' || gRbrKjtFrom);
		CALL pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '基準日TO:' || gRbrKjtTo);
		CALL pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '通知日:' || gYokuGyoYmd);
		-- オプションフラグチェック
		-- 実質記番号管理のオプションフラグが'1'の場合のみ処理を行う
		IF pkControl.getOPTION_FLG(recItaku.KAIIN_ID, C_OPTION_CD, '0') = '1' THEN
			-- 振込案内（実質記番号）作成-------------------------------------------------------------
			CALL SPIPP004K00R01(
							recItaku.KAIIN_ID,     -- 委託会社コード
							pkconstant.BATCH_USER(), -- ユーザーＩＤ
							'1',                   -- 帳票区分
							NULL,                  -- 銘柄コード
							NULL,                  -- ＩＳＩＮコード
							gRbrKjtFrom,           -- 基準日FROM
							gRbrKjtTo,             -- 基準日TO
							gYokuGyoYmd,           -- 通知日
							gSqlCode,              -- リターン値
							gSqlErrM                -- エラーコメント
						);
			-- 対象データなし判定
			IF gSqlCode = C_NO_DATA THEN
				gSqlCode := pkconstant.success();
				CALL pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '対象データなし');
			END IF;
			-- エラー判定
			IF gSqlCode != pkconstant.success() THEN
				CALL pkLog.error(pkconstant.BATCH_USER(), C_PROGRAM_ID, '振込案内（実質記番号）作成失敗：' || gSqlErrM);
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
-- REVOKE ALL ON FUNCTION sfipp004k00r00 () FROM PUBLIC;

