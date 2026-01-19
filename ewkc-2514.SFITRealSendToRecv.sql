




CREATE OR REPLACE FUNCTION sfitrealsendtorecv () RETURNS numeric AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * （テスト用）
-- * 勘定系リアル送信IFテーブルから勘定系リアル受信IFテーブルを作成する。
-- * 
-- * @author 小網　由妃子
-- * @version $Revision: 1.1 $
-- 
--==============================================================================
--					変数定義													
--==============================================================================
	nCount			 numeric;			-- 件数カウンタ
--==============================================================================
--					カーソル定義												
--==============================================================================
--==============================================================================
--					メイン処理													
--==============================================================================
BEGIN
	-- 勘定系リアル受信IFテーブルのデータの存在を確認する。
--	SELECT COUNT(*) INTO nCount 
--	FROM   knjrealrcvif;
	
	-- 勘定系リアル受信IFテーブルにデータが存在した場合は削除する。
--	IF nCount > '0' THEN
--		DELETE FROM knjrealrcvif;
--	END IF;
	-- 勘定系リアル送信IFテーブルのデータから勘定系リアル受信IFテーブルデータを作成する。
	INSERT INTO knjrealrcvif(
			data_id,
			make_dt,
			data_seq,
			knj4tr_uke_id,
			knj4tr_uke_tsuban,
			knj4tr_err,
			sr_stat
		)
	SELECT
		'41001',
		to_char(clock_timestamp(), 'yyyymmdd'),
		data_seq - 1,
		knj4tr_uke_id,
		knj4tr_uke_tsuban,
		'0000',
		'0'
	FROM knjrealsndif
	WHERE data_id = '14002' and sr_stat = '0'
    ORDER BY data_seq;
	UPDATE knjrealsndif
	SET sr_stat = '1'
	WHERE sr_stat = '0';
	RETURN pkconstant.success();
--==============================================================================
--					エラー処理													
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'ITRealSendToRecv', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfitrealsendtorecv () FROM PUBLIC;