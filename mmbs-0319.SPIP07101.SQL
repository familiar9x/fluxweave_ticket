




CREATE OR REPLACE PROCEDURE spip07101 ( l_inUserId TEXT,		-- ユーザーID
 l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inGnrBaraiKjtF TEXT,		-- ⑫左 元利払期日(FROM)
 l_inGnrBaraiKjtT TEXT,		-- ⑫右 元利払期日(TO)
 l_inHktCd TEXT,		-- ①   発行体コード
 l_inKozaTenCd TEXT,		-- ②   口座店店番   
 l_inKozaTenCifCd TEXT,		-- ③   口座店ＣIＦコード
 l_inMgrCd TEXT,		-- ④   銘柄コード  
 l_inIsinCd TEXT,		-- ⑤   ＩＳＩＮコード
 l_inJtkKbn TEXT,		-- ⑥   受託区分
 l_inSaikenShurui TEXT,		-- ⑦   債券種類
 l_inKkKanyoFlg TEXT,		-- ⑧   機構関与方式採用フラグ
 l_inShokanMethodCd TEXT,		-- ⑨   償還方法
 l_inTeijiShokanTsutiKbn TEXT,		-- ⑩   定時償還通知区分
 l_inJiyuu TEXT,		-- ⑪   事由
 l_outSqlCode OUT integer,		-- リターン値
 l_outSqlErrM OUT text	-- エラーコメント
 ) AS $body$
DECLARE

--
-- * 著作権:Copyright(c)2004
-- * 会社名:JIP
-- * 概要　:業務帳票出力指示画面の入力条件により、償還予定銘柄一覧表を作成する。
-- * 引数　:  l_inUserId				IN	TEXT,		-- ユーザーID
-- *			l_inItakuKaishaCd		IN	TEXT,		-- 委託会社コード
-- *			l_inGnrBaraiKjtF		IN	TEXT,		-- ⑫ 元利払期日(FROM)
-- *			l_inGnrBaraiKjtT		IN	TEXT,		-- ⑫ 元利払期日(TO)
-- *			l_inHktCd				IN	TEXT,		-- ① 発行体コード
-- *			l_inKozaTenCd			IN	TEXT,		-- ② 口座店店番   
-- *			l_inKozaTenCifCd		IN	TEXT,		-- ③ 口座店ＣIＦコード
-- *			l_inMgrCd				IN	TEXT,		-- ④ 銘柄コード  
-- *			l_inIsinCd				IN	TEXT,		-- ⑤ ＩＳＩＮコード
-- *			l_inJtkKbn				IN	TEXT,		-- ⑥ 受託区分
-- *			l_inSaikenShurui		IN	TEXT,		-- ⑦ 債券種類
-- *			l_inKkKanyoFlg			IN	TEXT,		-- ⑧ 機構関与方式採用フラグ
-- *			l_inShokanMethodCd		IN	TEXT,		-- ⑨ 償還方法
-- *			l_inTeijiShokanTsutiKbn	IN	TEXT,		-- ⑩ 定時償還通知区分
-- *			l_inJiyuu				IN	TEXT,		-- ⑪ 事由
-- *			l_outSqlCode				OUT	INTEGER		リターン値
-- *			l_outSqlErrM				OUT	VARCHAR	エラーコメント
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
-- REVOKE ALL ON PROCEDURE spip07101 ( l_inUserId TEXT, l_inItakuKaishaCd TEXT, l_inGnrBaraiKjtF TEXT, l_inGnrBaraiKjtT TEXT, l_inHktCd TEXT, l_inKozaTenCd TEXT, l_inKozaTenCifCd TEXT, l_inMgrCd TEXT, l_inIsinCd TEXT, l_inJtkKbn TEXT, l_inSaikenShurui TEXT, l_inKkKanyoFlg TEXT, l_inShokanMethodCd TEXT, l_inTeijiShokanTsutiKbn TEXT, l_inJiyuu TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;