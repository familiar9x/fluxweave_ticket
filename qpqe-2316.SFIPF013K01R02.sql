




CREATE OR REPLACE FUNCTION sfipf013k01r02 () RETURNS numeric AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 当該処理は、JP1より定時間隔で起動する
-- * 勘定系接続ステータス管理の受信フラグが'1'の場合、DBIリアル受信PGをCALLする。
-- * 
-- * @author 小網　由妃子
-- * @version $Revision: 1.4 $
-- * $Id: SFIPF013K01R02.sql,v 1.4 2005/11/04 10:12:04 kubo Exp $
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
	-- 勘定系接続ステータス管理テーブルの勘定系IF受信接続フラグを取得する。
	SELECT knjif_recv INTO STRICT cInNo from knjsetuzokustatus;
	-- 勘定系接続ステータス管理テーブルの勘定IF受信接続フラグが'1'の場合,DBIFリアル受信PGをCallする。
	IF cInNo = '1' THEN
		nRtnCd := SFIPF013K01R03();
			-- 戻り値が'0'以外の場合
			IF nRtnCd != 0 THEN
			CALL pkLog.fatal('ECM701', 'IPF013K01R02', 'DBIFリアル受信エラー');
			RETURN pkconstant.fatal();
		END IF;
	-- 勘定系接続ステータス管理テーブルの勘定IF受信接続フラグが'0'の場合エラーとする。
	ELSIF cInNo = '0' THEN
		-- ログ出力用メッセージ
		vMsgLog := '閉局処理後エラー';
		-- エラーリスト用テーブル名称
		vTableName := '勘定系接続ステータス管理';
		nRtnCd := SFIPF013K01R02_COMMON_FUNC(
					'EIP523',
					vMsgLog,
					vTableName,
					cWk_kaiin,
					cGyoumuDt
				);
	-- 勘定系接続ステータス管理テーブルの勘定IF受信接続フラグが'0''1'以外の場合ログを出力する。
	ELSE
		-- ログ出力用メッセージ
		vMsgLog := '＜テーブル名：勘定系接続ステータス管理、status：' || cInNo || '＞';
		-- ログ出力
		CALL pkLog.error(
			'WIP503',
			'IPF013K01R02',
			vMsgLog
				);
		RETURN pkconstant.success();
	END IF;
	RETURN nRtnCd;
--==============================================================================
--					エラー処理													
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'IPF013K01R02', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf013k01r02 () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipf013k01r02_common_func (
	l_inMessage_id text,			-- メッセージＩＤ
	l_inMsgLog text,			-- ログ出力用メッセージ
	l_inTableName text,			-- テーブル名称
	l_inItaku_kaisha_cd text,				-- 委託会社コード
	l_inCGyoumuDt char(8)			-- 業務日付
) RETURNS integer AS $body$
DECLARE
	nRtnCd integer;
	vSqlErrM text;
	iRet integer;
BEGIN
	-- ログ出力
	CALL pkLog.error(
		l_inMessage_id,
		'IPF013K01R02',
		l_inMsgLog
	);
	-- エラーリスト出力
	CALL SPIPF001K00R01(
		l_inItaku_kaisha_cd,
		'BATCH', 
		'1', 
		'3', 
		l_inCGyoumuDt, 
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
			'IPF013K01R02',
			'メッセージ通知登録エラー'
		);
		RETURN iRet;
	END IF;
	RETURN pkconstant.error();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf013k01r02_common_func ( l_inMessage_id text, l_inMsgLog text, l_inTableName text, l_inItaku_kaisha_cd text  ) FROM PUBLIC;
