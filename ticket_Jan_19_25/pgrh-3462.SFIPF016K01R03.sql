




CREATE OR REPLACE FUNCTION sfipf016k01r03 ( l_inNo TEXT 				-- 開局閉局判別フラグ
 ) RETURNS numeric AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * パラメータにより、開局電文又は閉局電文を作成する。
-- * 
-- * @author 小網　由妃子
-- * @version $Revision: 1.2 $
-- * 
-- * @param l_inNo 		 IN		TEXT				開局閉局判別フラグ
-- 
--==============================================================================
--					変数定義													
--==============================================================================
	cSysdate			 char(8);	-- システム日付
	nMaxIfNo			 numeric;	-- 勘定系リアル送信IFテーブル連番ＭＡＸ番号
	nMaxIfSvNo			 numeric;	-- 勘定系リアル送信保存IFテーブル連番ＭＡＸ番号
	nCount				 numeric;	-- 件数カウンタ
--==============================================================================
--					メイン処理													
--==============================================================================
BEGIN
	-- 【入力パラメータ：開局閉局判別フラグ】が'1'の場合
	IF l_inNo = '1' THEN
		SELECT TO_CHAR(clock_timestamp(), 'YYYYMMDD') INTO STRICT cSysdate;
		-- 勘定系リアル送信IFテーブルにデータ登録
		INSERT INTO knjrealsndif(
			data_id,
			make_dt, 
			data_seq, 
			knj4tr_uke_id 
		)
		VALUES (
			'14001', 
			cSysdate, 
			1, 
			'0001' 
		);
		-- 勘定系リアル送信保存IFテーブルにデータ登録
		INSERT INTO knjrealsndsaveif(
			data_id,
			make_dt, 
			data_seq, 
			knj4tr_uke_id 
		)
		VALUES (
			'14001', 
			cSysdate, 
			1, 
			'0001' 
		);
	-- 【入力パラメータ：開局閉局判別フラグ】が'2'の場合
	ELSIF l_inNo = '2' THEN
		SELECT TO_CHAR(clock_timestamp(), 'YYYYMMDD') INTO STRICT cSysdate;
		-- 勘定系リアル送信IFテーブルの最大のデータ内連番を取得する。
		SELECT MAX(data_seq) INTO STRICT nMaxIfNo FROM knjrealsndif WHERE make_dt = cSysdate;
		-- 勘定系リアル送信保存IFテーブルの最大のデータ内連番を取得する。
		SELECT MAX(data_seq) INTO STRICT nMaxIfSvNo FROM knjrealsndsaveif WHERE make_dt = cSysdate;
		-- 勘定系リアル送信IFテーブルにデータ登録
		INSERT INTO knjrealsndif(
			data_id,
			make_dt, 
			data_seq, 
			knj4tr_uke_id 
		) 
		VALUES (
			'14003', 
			cSysdate, 
			nMaxIfNo + 1, 
			'0001' 
		);
		-- 勘定系リアル送信保存IFテーブルにデータ登録
		INSERT INTO knjrealsndsaveif(
			data_id,
			make_dt, 
			data_seq, 
			knj4tr_uke_id 
		) 
		VALUES (
			'14003', 
			cSysdate, 
			nMaxIfNo + 1, 
			'0001' 
		);
	END IF;
	-- 開局閉局判別フラグが'1'の場合
	IF l_inNo  = '1' THEN
		--接続ステータス管理テーブルのデータの有無を確認
		nCount := 0;
		SELECT count(*) INTO STRICT nCount
		FROM   knjsetuzokustatus;
		--対象データ数が0の場合、データを挿入する
		IF nCount = 0 THEN
			INSERT INTO knjsetuzokustatus(
				knjif_send,
				knjif_recv,
				kousin_dt,
				kousin_id,
				sakusei_dt,
				sakusei_id
			)
			VALUES (
				1,
				1, 
				current_timestamp, 
				'BATCH',
				current_timestamp,
				'BATCH'
			);
		ELSE
		--対象データがある場合、データを更新する
			UPDATE knjsetuzokustatus
			SET    knjif_send = '1', 
				   knjif_recv = '1',
				   kousin_dt = current_timestamp,
				   kousin_id = 'BATCH',
				   sakusei_dt = current_timestamp,
				   sakusei_id = 'BATCH';
		END IF;
	-- 開局閉局判別フラグが'2'の場合
	ELSIF l_inNo  = '2' THEN
		--データを更新する
		UPDATE knjsetuzokustatus
		SET    knjif_send = '0', 
			   knjif_recv = '0',
			   kousin_dt = current_timestamp,
			   kousin_id = 'BATCH';
	END IF;
	RETURN pkconstant.success();
--==============================================================================
--					エラー処理													
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'IPF016K01R03', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf016k01r03 ( l_inNo TEXT  ) FROM PUBLIC;