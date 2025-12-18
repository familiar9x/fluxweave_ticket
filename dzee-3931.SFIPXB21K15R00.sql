




CREATE OR REPLACE FUNCTION sfipxb21k15r00 () RETURNS numeric AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2006
-- * 会社名:JIP
-- *
-- * 概要　:日次 送信処理で送信するCIF情報送信ファイル作成の元となるデータを作成し、CIF情報送信テーブルに格納する
-- *
-- * 返り値: 0:正常
-- *        99:異常
-- *
-- * @author ASK
-- * @version $Id:$
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2016.11.17 ASK         新規作成
-- ***************************************************************************
--
	--==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_FUNCTION_ID CONSTANT text := 'SFIPXB21K15R00'; -- ファンクションＩＤ
	C_SHONIN_ZUMI   CONSTANT MHAKKOTAI.SHORI_KBN%TYPE        := '1'; -- 処理区分(承認済)
	C_HIRENDO_DENAI CONSTANT MHAKKOTAI2.CIF_HIRENDO_FLG%TYPE := '0'; -- ＣＩＦ非連動フラグ(非連動でない)
	C_MESSAGE_ID CONSTANT MSG_KANRI.MSG_NM%TYPE := 'IIP015';
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	gReturnCd numeric := 0; -- リターン値
	gGyomuYmd SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE := NULL; -- 業務日付
	gKensu numeric := 0;
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	CALL pkLog.debug(pkconstant.BATCH_USER(), C_FUNCTION_ID, C_FUNCTION_ID||' START');
	-- 業務日付を取得する
	gGyomuYmd := pkDate.getGyomuYmd();
	-- CIF情報送信テーブルのクリア
	EXECUTE 'TRUNCATE TABLE CIF_INFO_SND';
	-- 登録処理(CIF情報送信テーブル)
	INSERT INTO CIF_INFO_SND(ITAKU_KAISHA_CD              -- 委託会社コード
	   , KOZA_TEN_CD                  -- 口座店コード
	   , KOZA_TEN_CIFCD               -- 口座店ＣＩＦコード
	   , SHORI_YMD                    -- 処理日付
	   , KOUSIN_ID                    -- 更新者
	   , SAKUSEI_ID)                 -- 作成者
	    SELECT DISTINCT
	           M01.ITAKU_KAISHA_CD    -- 発行体M.委託会社コード
	         , M01.KOZA_TEN_CD        -- 発行体M.口座店コード
	         , M01.KOZA_TEN_CIFCD     -- 発行体M.口座店ＣＩＦコード
	         , gGyomuYmd              -- 業務日付
	         , pkconstant.BATCH_USER()  -- バッチ更新のユーザID
	         , pkconstant.BATCH_USER()  -- バッチ更新のユーザID
	FROM   MHAKKOTAI M01
	     , MHAKKOTAI2 BT01
	WHERE  M01.ITAKU_KAISHA_CD = pkConstant.getKaiinId()
	AND    M01.ITAKU_KAISHA_CD = BT01.ITAKU_KAISHA_CD
	AND    M01.HKT_CD = BT01.HKT_CD
	AND    M01.SHORI_KBN = C_SHONIN_ZUMI
	AND    BT01.CIF_HIRENDO_FLG  = C_HIRENDO_DENAI;
	-- コミット処理 (PostgreSQL function does not allow COMMIT, auto-commit on function exit)
	-- COMMIT;
	-- 登録件数取得(CIF情報送信テーブル)
	SELECT COUNT(*)
	INTO STRICT   gKensu
	FROM   CIF_INFO_SND;
	-- ログ出力
	CALL pkLog.info(C_MESSAGE_ID, C_FUNCTION_ID, gKensu::text);
	CALL pkLog.debug(pkconstant.BATCH_USER(), C_FUNCTION_ID, C_FUNCTION_ID ||' END');
	-- 終了処理
	RETURN pkconstant.success();
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SUBSTR(C_FUNCTION_ID,3,12), 'CIF情報送信ファイル作成処理（データ作成部）が失敗しました。');
		CALL pkLog.fatal('ECM701', SUBSTR(C_FUNCTION_ID,3,12), 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', SUBSTR(C_FUNCTION_ID,3,12), 'SQLERRM:' || SQLERRM);
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipxb21k15r00 () FROM PUBLIC;
