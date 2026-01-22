




CREATE OR REPLACE FUNCTION sfipf013k01r06 ( l_inStNo TEXT 				-- ステータス
 ) RETURNS numeric AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 勘定系接続ステータス管理テーブルの送信の接続フラグを更新する。
-- * 
-- * @author 小網　由妃子
-- * @version $Revision: 1.4 $
-- * 
-- * @param l_inNo		   IN	  TEXT				種別
-- * @param l_inStNo		   IN	  TEXT				ステータス
-- * 
-- * @return NUMERIC
-- * 				0:正常終了、データ無し
-- * 				1:予期したエラー
-- * 				99:予期せぬエラー
-- 
--==============================================================================
--					変数定義													
--==============================================================================
	nCount			 numeric;			-- 件数カウンタ
	iRet			 integer;			-- 戻り値
--==============================================================================
--					メイン処理													
--==============================================================================
BEGIN
	-- コード値チェック
	iRet := sfCmIsCodeMChek('S17', l_inStNo);
	--ステータスが'0'〜'4'以外の場合又はNULLの場合はリターン値(1)を返す
	IF (iRet != 0) or (coalesce(trim(both l_inStNo)::text, '') = '') THEN
		CALL pkLog.error('ECM501', 'IPF013K01R06', 'パラメータエラー（ステータス:' || l_inStNo || ')');
		RETURN pkconstant.error();
	ELSE
		--対象データの有無を確認
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
				l_inStNo,
				0, 
				current_timestamp, 
				'BATCH',
				current_timestamp,
				'BATCH'
				);
		ELSE
			--データを更新する
			UPDATE knjsetuzokustatus
			SET    knjif_send = l_inStNo,
				   kousin_dt  = current_timestamp, 
				   kousin_id  = 'BATCH';
		END IF;
	END IF;
	RETURN pkconstant.success();
--==============================================================================
--					エラー処理													
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'IPF013K01R06', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf013k01r06 ( l_inStNo TEXT  ) FROM PUBLIC;