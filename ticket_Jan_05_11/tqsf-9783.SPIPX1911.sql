




CREATE OR REPLACE PROCEDURE spipx1911 ( 
    l_inItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE, -- 委託会社コード
 l_inUserId SREPORT_WK.USER_ID%TYPE,            -- ユーザID
 l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE,         -- 帳票区分
 l_inGyomuYmd SREPORT_WK.SAKUSEI_YMD%TYPE,        -- 業務日付
 l_outSqlCode OUT integer,                             -- リターン値
 l_outSqlErrM OUT text                            -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2016
-- * 会社名: JIP
-- *
-- * 作業日管理（備忘録）リスト作成のため帳票ワークテーブルを作成する。
-- * 
-- * @author 張鋭(USI)
-- * @version $Id: SPIPX1911.sql,v 1.1 2017/01/05 03:18:49 fujii Exp $
-- * 
-- * @param l_inItakuKaishaCd 委託会社コード
-- * @param l_inUserId        ユーザID
-- * @param l_inChohyoKbn     帳票区分
-- * @param l_inGyomuYmd      業務日付
-- * @param l_outSqlCode      リターン値
-- * @param l_outSqlErrM      エラーコメント
-- 
--==============================================================================
--                  定数定義                                                    
--==============================================================================
	C_OK                    CONSTANT integer      := 0;                    -- 正常
	C_NG                    CONSTANT integer      := 1;                    -- 予期したエラー
	C_FATAL                 CONSTANT integer      := 99;                   -- 予期せぬエラー
	C_REPORT_ID             CONSTANT text     := 'IPX30001911';        -- 帳票ID
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	gSagyobiFrom                     SREPORT_WK.SAKUSEI_YMD%TYPE;          -- 業務日付翌営業日
	gSagyobiTo                       SREPORT_WK.SAKUSEI_YMD%TYPE;          -- 業務日付５営業日後
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	CALL pkLog.debug(l_inUserId, C_REPORT_ID, 'SPIPX1911 START');
	CALL pkLog.debug(l_inUserId, C_REPORT_ID, '委託会社：' || l_inItakuKaishaCd);
	CALL pkLog.debug(l_inUserId, C_REPORT_ID, 'ユーザID：' || l_inUserId);
	CALL pkLog.debug(l_inUserId, C_REPORT_ID, '帳票区分：' || l_inChohyoKbn);
	CALL pkLog.debug(l_inUserId, C_REPORT_ID, '業務日付：' || l_inGyomuYmd);
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inUserId)::text, '') = '' 
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = '' 
	OR coalesce(trim(both l_inGyomuYmd)::text, '') = '' THEN
		-- パラメータエラー
		CALL pkLog.error('ECM001', 'SPIPX1911', 'パラメータエラー(NULL)');
		l_outSqlCode := C_NG;
		l_outSqlErrM := '';
		RETURN;
	END IF;
	-- 業務日付翌営業日取得
	gSagyobiFrom := pkDate.getYokuBusinessYmd(l_inGyomuYmd);
	-- 業務日付５営業日後取得
	gSagyobiTo := pkDate.getPlusDateBusiness(l_inGyomuYmd, 5);
	-- 帳票作成
	CALL SPIPX30001911(
		l_inItakuKaishaCd,     -- 委託会社コード
		l_inUserId,            -- ユーザＩＤ
		l_inChohyoKbn,         -- 帳票区分
		gSagyobiFrom,          -- 作業日（FROM）
		gSagyobiTo,            -- 作業日（TO）
		NULL,                  -- 状況区分
		'2',                   -- 処理区分
		l_outSqlCode,          -- リターン値
		l_outSqlErrM            -- エラーコメント
	);
	CALL pkLog.debug(l_inUserId, C_REPORT_ID, 'SPIPX1911 END');
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'SPIPX1911', 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal('ECM701', 'SPIPX1911', 'SQLERRM:'||SQLERRM);
		l_outSqlCode := C_FATAL;
		l_outSqlErrM := SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipx1911 ( l_inItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE, l_inUserId SREPORT_WK.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_inGyomuYmd SREPORT_WK.SAKUSEI_YMD%TYPE, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;