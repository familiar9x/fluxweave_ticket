




CREATE OR REPLACE FUNCTION sfipf013k01r08 () RETURNS numeric AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 当該処理は、JP1より定時間隔で起動する
-- * 勘定系接続ステータス管理の送信接続フラグが'1'の場合、DBIFリアル送信PGをCALLする。
-- * 勘定系発行代り金IF、勘定系元利金・手数料IFをそれぞれ処理する。
-- * 
-- * @author 小網　由妃子
-- * @version $Revision: 1.3 $
-- * $Id: SFIPF013K01R08.sql,v 1.3 2005/11/04 10:12:04 kubo Exp $
-- 
--==============================================================================
--					変数定義													
--==============================================================================
	iRet					 integer;						-- リターン値
	cInNo					 TEXT;							-- 勘定IF受信接続フラグ
	cGyoumuDt				 char(8);						-- 業務日付
	cWk_kaiin				 char(4);						-- 会員ＩＤ 
	nRtnCd					 numeric;						-- リターンコード
	vSqlErrM				 varchar(200);					-- エラーメッセージ
	vMsgLog					 varchar(300);					-- ログ出力用メッセージ
	vTableName				 varchar(300);
--==============================================================================
--					メイン処理												
--==============================================================================
BEGIN
	-- 初期化
	nRtnCd := 0;
	
	-- 業務日付を取得
	cGyoumuDt := pkDate.getGyomuYmd();
	-- 自行情報マスタより会員IDを取得
	SELECT kaiin_id INTO STRICT cWk_kaiin
	FROM sown_info;
	
	-- 勘定系接続ステータス管理テーブルの勘定系IF送信接続フラグを取得する。
	SELECT knjif_send INTO STRICT cInNo from knjsetuzokustatus;
	-- 勘定系接続ステータス管理テーブルの勘定IF送信接続フラグが'1'の場合,DBIFリアル送信PGをCallする。
	IF cInNo = '1' THEN
		nRtnCd := SFIPF013K01R01('1', 'BATCH');
			-- 戻り値が'0'以外の場合
			IF nRtnCd != 0 THEN
			CALL pkLog.fatal('ECM701', 'IPF013K01R08', 'DBIFリアル送信エラー(勘定系発行代り金IF)');
			RETURN pkconstant.fatal();
			END IF;
		nRtnCd := SFIPF013K01R01('2', 'BATCH');
			-- 戻り値が'0'以外の場合
			IF nRtnCd != 0 THEN
			CALL pkLog.fatal('ECM701', 'IPF013K01R08', 'DBIFリアル送信エラー(勘定系元利金・手数料IF)');
			RETURN pkconstant.fatal();
			END IF;
	END IF;
	-- 勘定系接続ステータス管理テーブルの勘定IF受信接続フラグが'0'の場合開局未実施。
	IF cInNo = '0' THEN
		-- ログ出力用メッセージ
		vMsgLog := '開局未実施エラー';
		-- エラーリスト用テーブル名称
		vTableName := '勘定系接続ステータス管理';
		nRtncd := SFIPF013K01R08_COMMON_FUNC(
					'EIP521',
					vMsgLog,
					vTableName,
					cWk_kaiin,
					cGyoumuDt
				);
	ELSIF cInNo = '3' THEN
		-- ログ出力用メッセージ
		vMsgLog := '締め処理後エラー';
		-- エラーリスト用テーブル名称
		vTableName := '勘定系接続ステータス管理';
		nRtncd := SFIPF013K01R08_COMMON_FUNC(
					'EIP522',
					vMsgLog,
					vTableName,
					cWk_kaiin,
					cGyoumuDt
				);
	END IF;
	RETURN nRtncd;
--==============================================================================
--					エラー処理													
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'IPF013K01R08', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf013k01r08 () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipf013k01r08_common_func ( 
	l_inMessage_id text,			-- メッセージＩＤ
	l_inMsgLog text,			-- ログ出力用メッセージ
	l_inTableName text,			-- テーブル名称
	l_inItaku_kaisha_cd text, 				-- 委託会社コード
	l_inGyoumuDt char(8)			-- 業務日付
 ) RETURNS integer AS $body$
DECLARE
	iRet					 integer;						-- リターン値
	nRtnCd					 numeric;						-- リターンコード
	vSqlErrM				 varchar(200);					-- エラーメッセージ
BEGIN
	-- ログ出力
	CALL pkLog.error(
		l_inMessage_id,
		'IPF013K01R08',
		l_inMsgLog
	);
	
	-- エラーリスト出力
	CALL SPIPF001K00R01(
		l_inItaku_kaisha_cd,
		'BATCH', 
		'1', 
		'3', 
		l_inGyoumuDt, 
		'60', 
		'9999999999', 
		l_inTableName, 
		l_inMsgLog,
		l_inMessage_id, 
		nRtnCd, 
		vSqlErrM
	);
	-- メッセージ通知テーブルへ書き込み
	iRet := SfIpMsgTsuchiUpdate(
			l_inItaku_kaisha_cd,
			'勘定系',
			'警告',
			'1',
			'0',
			l_inMsgLog,
			'BATCH',
			'BATCH'
	);
	IF iRet != 0 THEN
		CALL pkLog.fatal(
			'ECM701',
			'IPF013K01R08',
			'メッセージ通知登録エラー'
		);
		RETURN iRet;
	END IF;
	RETURN pkconstant.error();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf013k01r08_common_func ( l_inMessage_id text, l_inMsgLog text, l_inTableName text, l_inItaku_kaisha_cd text  ) FROM PUBLIC;
