




CREATE OR REPLACE PROCEDURE spip07101 ( l_inUserId CHAR,		-- ユーザーID
 l_inItakuKaishaCd CHAR,		-- 委託会社コード
 l_inGnrBaraiKjtF CHAR,		-- ⑫左 元利払期日(FROM)
 l_inGnrBaraiKjtT CHAR,		-- ⑫右 元利払期日(TO)
 l_inHktCd CHAR,		-- ①   発行体コード
 l_inKozaTenCd CHAR,		-- ②   口座店店番   
 l_inKozaTenCifCd CHAR,		-- ③   口座店ＣIＦコード
 l_inMgrCd CHAR,		-- ④   銘柄コード  
 l_inIsinCd CHAR,		-- ⑤   ＩＳＩＮコード
 l_inJtkKbn CHAR,		-- ⑥   受託区分
 l_inSaikenShurui CHAR,		-- ⑦   債券種類
 l_inKkKanyoFlg CHAR,		-- ⑧   機構関与方式採用フラグ
 l_inShokanMethodCd CHAR,		-- ⑨   償還方法
 l_inTeijiShokanTsutiKbn CHAR,		-- ⑩   定時償還通知区分
 l_inJiyuu CHAR,		-- ⑪   事由
 l_outSqlCode OUT numeric,		-- リターン値
 l_outSqlErrM OUT text	-- エラーコメント
 ) AS $body$
DECLARE

--
-- * 著作権:Copyright(c)2004
-- * 会社名:JIP
-- * 概要　:業務帳票出力指示画面の入力条件により、償還予定銘柄一覧表を作成する。
-- * 引数　:  l_inUserId				IN	CHAR,		-- ユーザーID
-- *			l_inItakuKaishaCd		IN	CHAR,		-- 委託会社コード
-- *			l_inGnrBaraiKjtF		IN	CHAR,		-- ⑫ 元利払期日(FROM)
-- *			l_inGnrBaraiKjtT		IN	CHAR,		-- ⑫ 元利払期日(TO)
-- *			l_inHktCd				IN	CHAR,		-- ① 発行体コード
-- *			l_inKozaTenCd			IN	CHAR,		-- ② 口座店店番   
-- *			l_inKozaTenCifCd		IN	CHAR,		-- ③ 口座店ＣIＦコード
-- *			l_inMgrCd				IN	CHAR,		-- ④ 銘柄コード  
-- *			l_inIsinCd				IN	CHAR,		-- ⑤ ＩＳＩＮコード
-- *			l_inJtkKbn				IN	CHAR,		-- ⑥ 受託区分
-- *			l_inSaikenShurui		IN	CHAR,		-- ⑦ 債券種類
-- *			l_inKkKanyoFlg			IN	CHAR,		-- ⑧ 機構関与方式採用フラグ
-- *			l_inShokanMethodCd		IN	CHAR,		-- ⑨ 償還方法
-- *			l_inTeijiShokanTsutiKbn	IN	CHAR,		-- ⑩ 定時償還通知区分
-- *			l_inJiyuu				IN	CHAR,		-- ⑪ 事由
-- *			l_outSqlCode				OUT	INTEGER		リターン値
-- *			l_outSqlErrM				OUT	VARCHAR2	エラーコメント
-- *			返り値:なし
-- * @version $Revision: 1.7 $
-- *
-- 
--==============================================================================
--					定数定義													
--==============================================================================
	REPORT_ID			CONSTANT char(11)		:= 'IP030007111';		-- 帳票ID
--==============================================================================
--					変数定義													
--==============================================================================
	l_KjnYmdFrom		char(8) := NULL;		-- 元利払期日From					
	l_KjnYmdTo			char(8) := NULL;	    -- 元利払期日To	
	l_GyomuYmd          char(8) := NULL;		-- 業務日付
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	-- 入力パラメータのチェック
	IF  coalesce(l_inGnrBaraiKjtF::text, '') = ''
	AND coalesce(l_inGnrBaraiKjtT::text, '') = ''
	THEN
		-- パラメータエラー
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '';
		CALL pkLog.error(l_inUserId, REPORT_ID, 'SQLERRM:'||'');
		RETURN;
	END IF;
    -- 業務日付取得
    l_GyomuYmd := PKDATE.getGyomuYmd;
    -- パラメータの基準日From-Toをセット
    l_KjnYmdFrom := l_inGnrBaraiKjtF;
    l_KjnYmdTo   := l_inGnrBaraiKjtT;
    -- 基準日Toのみ入力されている場合はFromに最小値を、Fromのみの場合はToに最大値をセットする。
	IF coalesce(trim(both l_KjnYmdFrom)::text, '') = '' THEN
        l_KjnYmdFrom := '00000000';
    END IF;
	IF coalesce(trim(both l_KjnYmdTo)::text, '') = '' THEN
        l_KjnYmdTo := '99999999';
    END IF;
    CALL spIp07101_01(
    	l_KjnYmdFrom		             ,		-- 元利払期日(FROM)
    	l_KjnYmdTo		                 ,		-- 元利払期日(TO)
    	l_inHktCd				         ,		-- 発行体コード
    	l_inKozaTenCd			         ,		-- 口座店コード
    	l_inKozaTenCifCd		         ,		-- 口座店CIFコード
    	l_inMgrCd				         ,		-- 銘柄コード
    	l_inIsinCd				         ,		-- ISINコード
    	l_inJtkKbn				         ,		-- 受託区分
    	l_inSaikenShurui		         ,		-- 債券種類
    	l_inKkKanyoFlg			         ,		-- 機構関与方式採用フラグ
    	l_inShokanMethodCd		         ,		-- 償還方法
    	l_inTeijiShokanTsutiKbn	         ,		-- 定時償還通知区分
    	l_inJiyuu				         ,		-- 事由
    	l_inItakuKaishaCd		         ,		-- 委託会社コード
    	l_inUserId				         ,		-- ユーザーID
    	PKIPACALCTESURYO.C_DATA_KBN_YOTEI(),		-- 帳票区分
    	l_GyomuYmd			             ,		-- 業務日付
    	l_outSqlCode			         ,		-- リターン値
    	l_outSqlErrM 				            -- エラーコメント
    );
    RETURN;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLERRM;
--		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip07101 ( l_inUserId CHAR, l_inItakuKaishaCd CHAR, l_inGnrBaraiKjtF CHAR, l_inGnrBaraiKjtT CHAR, l_inHktCd CHAR, l_inKozaTenCd CHAR, l_inKozaTenCifCd CHAR, l_inMgrCd CHAR, l_inIsinCd CHAR, l_inJtkKbn CHAR, l_inSaikenShurui CHAR, l_inKkKanyoFlg CHAR, l_inShokanMethodCd CHAR, l_inTeijiShokanTsutiKbn CHAR, l_inJiyuu CHAR, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;