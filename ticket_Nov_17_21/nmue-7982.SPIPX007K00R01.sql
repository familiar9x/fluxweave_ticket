




CREATE OR REPLACE PROCEDURE spipx007k00r01 ( 
 l_inUserId SUSER.USER_ID%TYPE,                  -- ユーザID
 l_inItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE,  -- 委託会社コード
 l_inKessaiYmdFrom MGR_RBRKIJ.KKN_CHOKYU_YMD%TYPE,      -- 決済日From
 l_inKessaiYmdTo MGR_RBRKIJ.KKN_CHOKYU_YMD%TYPE,      -- 決済日To
 l_outSqlCode OUT integer,                              -- リターン値
 l_outSqlErrM OUT text                             -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2006
-- * 会社名:JIP
-- *
-- * 概要　:資金決済関連帳票の出力指示出力指示画面より、印刷条件の指定を受けて、元利金支払基金引落一覧表を作成する
-- *
-- * 引数　:l_inItakuKaishaCd :委託会社コード
-- *        l_inUserId        :ユーザーID
-- *        l_inChohyoKbn     :帳票区分
-- *        l_inKessaiYmdF    :決済年月日FROM
-- *        l_inKessaiYmdT    :決済年月日TO
-- *        l_outSqlCode      :リターン値
-- *        l_outSqlErrM      :エラーコメント
-- *
-- * 返り値: なし
-- *
-- * @author ASK
-- * @version $Id: SPIPX007K00R01.sql,v 1.1 2006/12/26 04:13:23 miura Exp $
-- *
--
--/*==============================================================================
--					デバッグ機能													
--==============================================================================
	DEBUG           numeric(1)               := 0;
--==============================================================================
--					定数定義													
--==============================================================================
	C_PROCEDURE_ID CONSTANT varchar(50)              := 'SPIPX007K00R01';
	C_CHOHYO_ID    CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IPX30000711';
--==============================================================================
--					変数定義													
--==============================================================================
	gReturnCode         integer := 0;
	l_GyomuYmd          char(8);
	l_KjnYmdFrom        char(8);
	l_KjnYmdTo          char(8);
  	extra_param       integer := 0;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, C_PROCEDURE_ID||' START');
	-- 業務日付取得
	l_GyomuYmd := pkDate.getGyomuYmd();
	-- 入力パラメータのチェック ※期日From-Toは必須入力項目
	IF coalesce(trim(both l_inKessaiYmdFrom)::text, '') = ''
	AND coalesce(trim(both l_inKessaiYmdTo)::text, '') = ''
	THEN
	-- ログ書込み
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID,3,12), 'パラメータエラー');
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := '';
	END IF;
	-- パラメータの決済日From-Toをセット
	l_KjnYmdFrom := l_inKessaiYmdFrom;
	l_KjnYmdTo   := l_inKessaiYmdTo;
	-- 基準日Toのみ入力されている場合はFromに最小値を、Fromのみの場合はToに最大値をセットする。
	IF coalesce(trim(both l_inKessaiYmdFrom)::text, '') = '' THEN
		l_KjnYmdFrom := '00000000';
	END IF;
	IF coalesce(trim(both l_KjnYmdTo)::text, '') = '' THEN
	l_KjnYmdTo := '99999999';
	END IF;
	-- データ取得
	-- 基金請求計算処理（請求書）※リアル・請求書出力・請求書
	SELECT * INTO l_outSqlCode, l_outSqlErrM, extra_param
	FROM pkipakknido.insKikinIdoHikiotoshiOut(l_inuserid::text,
											l_GyomuYmd::text,
											l_KjnYmdFrom::text,
											l_KjnYmdTo::text,
											l_initakukaishacd::text);
	
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, C_PROCEDURE_ID ||' END');
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID,3,12), 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID,3,12), 'SQLERRM:' || SQLERRM);
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLSTATE || SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipx007k00r01 ( l_inUserId SUSER.USER_ID%TYPE, l_inItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE, l_inKessaiYmdFrom MGR_RBRKIJ.KKN_CHOKYU_YMD%TYPE, l_inKessaiYmdTo MGR_RBRKIJ.KKN_CHOKYU_YMD%TYPE, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;