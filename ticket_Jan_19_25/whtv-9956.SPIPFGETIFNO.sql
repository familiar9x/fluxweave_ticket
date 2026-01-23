




CREATE OR REPLACE PROCEDURE spipfgetifno ( l_outSqlCode OUT integer,			-- リターン値
 l_inDate TEXT,				-- 日付
 l_outNo OUT TEXT 				-- 通番
 ) AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 入力パラメータ（日付）をキーにＩＦ通番採番管理テーブルのＩＦ通番処理MAX番号を
-- * 検索し通番を返す。
-- * 
-- * @author 戸倉　一成
-- * @version $Revision: 1.3 $
-- * 
-- * @param l_outSqlCode   OUT    INTEGER				リターン値
-- *        l_inDate       IN     TEXT				日付
-- *        l_outNo        OUT    TEXT				通番
-- * @return INTEGER
-- *                0:正常終了
-- *                1:予期したエラー
-- *               40:データ無し
-- *               99:予期せぬエラー
-- 
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	nCount           numeric;			-- 件数カウンタ
	nMaxNo           numeric;			-- ＩＦ通番処理ＭＡＸ番号
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 対象データの有無をチェック
	nCount := 0;
	SELECT count(*) INTO STRICT nCount FROM toyoiftuban
	WHERE shori_ymd = l_inDate;
	-- ＩＦ通番採番管理テーブルに対象データが存在しない場合
	IF nCount = 0 THEN
		INSERT INTO toyoiftuban(
			shori_ymd,
			iftsubanshori_max_no, 
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
		l_outNo := l_inDate || '00000001';
	ELSE
		-- ＩＦ通番処理ＭＡＸ番号の取得
		SELECT iftsubanshori_max_no INTO STRICT nMaxNo
		FROM   toyoiftuban
		WHERE  shori_ymd = l_inDate;
		-- ＩＦ通番採番管理テーブルの更新
		UPDATE toyoiftuban
		SET    iftsubanshori_max_no = nMaxNo + 1 
		WHERE  shori_ymd            = l_inDate;
		-- 通番の設定
		l_outNo := l_inDate || trim(both TO_CHAR((nMaxNo + 1),'00000000'));
	END IF;
	l_outSqlCode := pkconstant.success();
	RETURN;
--==============================================================================
--                  エラー処理                                                  
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'IPFGETIFNO', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		l_outSqlCode := pkconstant.fatal();
		RETURN;
--		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipfgetifno ( l_outSqlCode OUT integer, l_inDate TEXT, l_outNo OUT TEXT  ) FROM PUBLIC;