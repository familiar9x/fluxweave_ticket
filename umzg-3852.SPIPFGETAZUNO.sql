




CREATE OR REPLACE PROCEDURE spipfgetazuno ( l_inDate TEXT,				-- 日付
 l_outNo OUT TEXT,				-- 通番
 l_outSqlCode OUT integer 				-- リターン値
 ) AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 処理が発行代り金で科目が別段の場合、DD（処理日)＋9999の番号を取得する。
-- * 
-- * @author 小網　由妃子
-- * @version $Revision: 1.5 $
-- * 
-- * @param l_inDate		   IN	  TEXT				日付
-- * @param l_outNo		   OUT	  TEXT				通番
-- * @param l_outSqlCode	   OUT	  INTEGER			リターン値
-- 
--==============================================================================
--					変数定義													
--==============================================================================
	nCount			 numeric;			-- 件数カウンタ
	nMaxNo			 numeric;			-- 中継取引通番ＭＡＸ番号
--==============================================================================
--					メイン処理													
--==============================================================================
BEGIN
	-- 対象データの有無をチェック
	nCount := 0;
	SELECT count(*) INTO STRICT nCount FROM knjazutuban
	WHERE knj_shori_ymd = l_inDate;
	-- 預入通番採番管理テーブルに対象データが存在しない場合
	IF nCount = 0 THEN
		INSERT INTO knjazutuban(
			knj_shori_ymd,
			azuke_no_max_no, 
			kousin_dt, 
			kousin_id, 
			sakusei_dt, 
			sakusei_id
		)
		VALUES (
			l_inDate, 
			1, 
			current_timestamp, 
			'BATCH', 
			current_timestamp, 
			'BATCH'
		);
		l_outNo := '00' || SUBSTR(l_inDate,7,2) || '0001';
	ELSE
		-- 預入通番処理ＭＡＸ番号の取得
		SELECT azuke_no_max_no INTO STRICT nMaxNo
		FROM   knjazutuban
		WHERE  knj_shori_ymd = l_inDate FOR UPDATE;
		-- 預入通番採番管理テーブルの更新
		UPDATE knjazutuban
		SET    azuke_no_max_no = nMaxNo + 1,
			   kousin_dt = current_timestamp, 
			   kousin_id = 'BATCH' 
		WHERE  knj_shori_ymd = l_inDate;
		-- 通番の設定
		l_outNo := '00' || SUBSTR(l_inDate,7,2) || lpad((nMaxNo+1)::text, 4, '0');
	END IF;
	l_outSqlCode := pkconstant.success();
	RETURN;
--==============================================================================
--					エラー処理													
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'IPFGETAZUNO', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		l_outSqlCode := pkconstant.FATAL();
		RETURN;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipfgetazuno ( l_inDate TEXT, l_outNo OUT TEXT, l_outSqlCode OUT integer  ) FROM PUBLIC;