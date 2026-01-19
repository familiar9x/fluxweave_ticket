




CREATE OR REPLACE PROCEDURE spipfgetukeno ( l_inNo TEXT,				-- 種別
 l_outNo OUT TEXT,				-- 通番
 l_outSqlCode OUT integer 				-- リターン値
 ) AS $body$
DECLARE

--* 
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 受付通番採番管理テーブルより番号のみを管理する連番を取得する。
-- * 
-- * @author 小網　由妃子
-- * @version $Revision: 1.3 $
-- * 
-- * @param l_inNo 		 IN		TEXT				種別
-- *		  l_outNo		 OUT	TEXT				通番
-- *		  l_outSqlCode	 OUT	INTEGER				リターン値
-- 
--==============================================================================
--					変数定義													
--==============================================================================
	nCount			 numeric;			-- 件数カウンタ
	nMaxNo			 numeric;			-- 受付通番採番ＭＡＸ番号
--==============================================================================
--					メイン処理													
--==============================================================================
BEGIN
	-- 種別が'1','2'以外の場合
	IF l_inNo != '1' and l_inNo != '2' THEN
		l_outSqlCode := pkconstant.error();
		CALL pkLog.error('ECM501', 'IPFGETUKENO', 'パラメータエラー（種別:' || l_inNo || ')');
		RETURN;
	END IF;
	-- 種別が'1'の場合
	IF l_inNo = '1' THEN
		-- 対象データの有無をチェック
		nCount := 0;
		SELECT count(*) INTO STRICT nCount FROM knjuketuban;
		-- 受付通番採番管理テーブルに対象データが存在しない場合
		IF nCount = 0 THEN
			INSERT INTO knjuketuban(
				uke_tsuban_naibu_maxno,
				kousin_dt, 
				kousin_id, 
				sakusei_dt, 
				sakusei_id 
			)
			VALUES (
				1, 
				current_timestamp, 
				'BATCH', 
				current_timestamp, 
				'BATCH' 
			);
			l_outNo := '0000000001';
		ELSE
			-- 受付通番処理ＭＡＸ番号の取得
			nMaxNo := 0;
			SELECT uke_tsuban_naibu_maxno INTO STRICT nMaxNo
			FROM   knjuketuban FOR UPDATE;
			-- 受付通番処理ＭＡＸ番号の更新
			UPDATE knjuketuban
			SET    uke_tsuban_naibu_maxno = nMaxNo + 1,
				   kousin_dt = current_timestamp,
				   kousin_id = 'BATCH';
			-- 通番の設定
			l_outNo := lpad((nMaxNo+1)::text, 10, '0');
		END IF;
	-- 種別が'2'の場合
	ELSIF l_inNo = '2' THEN
		-- 対象データの有無をチェック
		nCount := 0;
		SELECT count(*) INTO STRICT nCount FROM knjuketuban;
		-- 受付通番採番管理テーブルに対象データが存在しない場合
		IF nCount = 0 THEN
			INSERT INTO knjuketuban(
				uke_tsuban_maxno,
				kousin_dt, 
				kousin_id, 
				sakusei_dt, 
				sakusei_id 
			)
			VALUES (
				1, 
				current_timestamp, 
				'BATCH', 
				current_timestamp, 
				'BATCH' 
			);
			l_outNo := '0000000001';
		ELSE
			-- 受付通番処理ＭＡＸ番号（勘定系）の取得
			nMaxNo := 0;
			SELECT uke_tsuban_maxno INTO STRICT nMaxNo
			FROM   knjuketuban FOR UPDATE;
			-- 受付通番処理ＭＡＸ番号（勘定系）の更新
			UPDATE knjuketuban
			SET    uke_tsuban_maxno = nMaxNo + 1,
				   kousin_dt = current_timestamp,
				   kousin_id = 'BATCH';
			-- 通番の設定
			l_outNo := lpad((nMaxNo+1)::text, 10, '0');
		END IF;
	END IF;
	l_outSqlCode := pkconstant.success();
	RETURN;
--==============================================================================
--					エラー処理													
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'IPFGETUKENO', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		l_outSqlCode := pkconstant.fatal();
		RETURN;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipfgetukeno ( l_inNo TEXT, l_outNo OUT TEXT, l_outSqlCode OUT integer  ) FROM PUBLIC;