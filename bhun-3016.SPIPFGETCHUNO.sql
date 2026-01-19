




CREATE OR REPLACE PROCEDURE spipfgetchuno ( l_inDate TEXT,				-- 日付
 l_outNo OUT TEXT,				-- 通番
 l_outSqlCode OUT integer 				-- リターン値
 ) AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 中継取引通番採番管理テーブルの処理日で管理する連番を取得する。
-- * 
-- * @author 小網　由妃子
-- * @version $Revision: 1.3 $
-- * 
-- * @param l_inDate		   IN	  CHAR				日付
-- * @param l_outNo		   OUT	  CHAR				通番
-- * @param l_outSqlCode	   OUT	  NUMBER			リターン値
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
	SELECT count(*) INTO STRICT nCount FROM knjchukeituban
	WHERE knj_shori_ymd = l_inDate;
	-- 中継取引通番採番管理テーブルに対象データが存在しない場合
	IF nCount = 0 THEN
		INSERT INTO knjchukeituban(
			knj_shori_ymd,
			chukei_tsuban_maxno, 
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
		l_outNo := '0001';
	ELSE
		-- 中継取引通番ＭＡＸ番号の取得
		SELECT chukei_tsuban_maxno INTO STRICT nMaxNo
		FROM   knjchukeituban
		WHERE  knj_shori_ymd = l_inDate FOR UPDATE;
		-- 中継取引通番採番管理テーブルの更新
		UPDATE knjchukeituban
		SET    chukei_tsuban_maxno= nMaxNo + 1, 
			   kousin_dt = current_timestamp, 
			   kousin_id = 'BATCH'
		WHERE  knj_shori_ymd = l_inDate;
		-- 通番の設定
		l_outNo := trim(both TO_CHAR((nMaxNo+1),'0000'));
	END IF;
	l_outSqlCode := pkconstant.success();
	RETURN;
--==============================================================================
--					エラー処理													
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'IPFGETCHUNO', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		l_outSqlCode := pkconstant.fatal();
		RETURN;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipfgetchuno ( l_inDate CHAR, l_outNo OUT CHAR, l_outSqlCode OUT numeric  ) FROM PUBLIC;