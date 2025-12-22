




CREATE OR REPLACE FUNCTION sfipx016k00r02 () RETURNS integer AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2008
-- * 会社名:JIP
-- *
-- * 概要　:業務データガベージ（親ＳＰ）
-- *
-- * 返り値: 0:正常
-- *        99:異常
-- *
-- * @author ASK
-- * @version $Id: SFIPX016K00R02.sql,v 1.1 2008/11/07 10:41:49 nishimura Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2008.09.05 ASK 新規作成
-- ***************************************************************************
-- 
	--==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_PROGRAM_ID CONSTANT text := 'SFIPX016K00R02'; -- プログラムＩＤ
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	gReturnCd integer := 0;                 -- リターン値
	gGyomuYmd SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE; -- 業務日付
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	curItakuKaisha CURSOR FOR
		SELECT
			KAIIN_ID  -- 会員ＩＤ（委託会社コード）
		FROM
			VJIKO_ITAKU
		WHERE
			DAIKO_FLG = '0'
			OR KAIIN_ID != pkConstant.getKaiinId();
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
--	pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, C_PROGRAM_ID || ' START');
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
--	pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '業務日付：' || gGyomuYmd);
	-- データ取得
	FOR recItakuKaisha IN curItakuKaisha LOOP
		-- 業務データガベージ実行
		gReturnCd := SFIPX016K00R02_01(recItakuKaisha.KAIIN_ID, pkconstant.BATCH_USER(), '1', gGyomuYmd);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '業務データガベージ（SFIPX016K00R02_01）コール');
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第１引数（委託会社コード）：' || recItakuKaisha.KAIIN_ID);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第２引数（ユーザーＩＤ）：' || pkconstant.BATCH_USER());
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第３引数（帳票区分）：1');
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第４引数（業務日付）：' || gGyomuYmd);
		-- 返値が正常でない場合
		IF gReturnCd != pkconstant.success() THEN
--			pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '業務データガベージ（SFIPX016K00R02_01）失敗');
			-- リターン
			RETURN gReturnCd;
		END IF;
	END LOOP;
--	pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, C_PROGRAM_ID || ' END');
	-- 正常終了
	RETURN pkconstant.success();
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'SQLERRM:' || SQLERRM);
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipx016k00r02 () FROM PUBLIC;