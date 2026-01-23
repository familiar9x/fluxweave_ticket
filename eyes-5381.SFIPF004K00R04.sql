




CREATE OR REPLACE FUNCTION sfipf004k00r04 ( l_inDataId text						 -- データ種別
 ) RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * Ｓより提供されたカレンダ情報よりカレンダマスタ（Ｓ個別）を作成する。
-- * 
-- * @author 小林　弘幸
-- * @version $Revision: 1.3 $
-- * 
-- * @return INTEGER
-- *                0:正常終了、データ無し
-- *                1:予期したエラー
-- *               99:予期せぬエラー
-- 
--==============================================================================
--                  定数定義                                                    
--==============================================================================
	MSG_DATAFILE_ERR      CONSTANT varchar(30) := 'データファイル重複エラー';
	MSG_IPF001K04R05_ERR  CONSTANT varchar(50) := '文字項目編集関数エラー';
	MSG_IPF001K04R06_ERR  CONSTANT varchar(50) := '数字項目編集関数エラー';
	MSG_IPF001K04R07_ERR  CONSTANT varchar(50) := 'レコード出力関数エラー';
	MSG_IPF001K04R08_ERR  CONSTANT varchar(50) := 'エンドファイル作成関数エラー';
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	cArea_cd				 calender_s.area_cd%type;		-- 地域コード
	cAd_yyyy				 calender_s.ad_yyyy%type;		-- 年
	cMm						 calender_s.mm%type;			-- 月
	cDd_flg					 calender_s.dd_flg%type;		-- 日
	nCount					 numeric;						-- レコード数
	nRow					 numeric;						-- 行番号
--==============================================================================
--                  カーソル定義                                                
--==============================================================================
	curFileDS CURSOR FOR
		SELECT
			r.data_id data_id,
			r.make_dt make_dt,
			r.make_cnt make_cnt,
			r.data_seq data_seq,
			r.data_sect_filedbif data_sect_filedbif
		FROM filercvif r,
			 filesndrcvinfoif c
		WHERE r.data_id = l_inDataId
		AND   r.sr_stat = '0'
		AND   r.data_id = c.data_id
		AND   r.make_dt = c.make_dt
		AND   r.make_cnt = c.make_cnt
		ORDER BY
			r.data_id,
			r.make_dt,
			r.make_cnt,
			r.data_seq;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 地域コードを設定
	IF l_inDataId = '21003' THEN
		cArea_cd := '1';
	ELSIF l_inDataId = '21004' THEN
		cArea_cd := '2';
	END IF;
	-- ファイル受信ＩＦテーブルをファイル送受信保存テーブルに登録
	nCount := 0;
	SELECT count(*)
	INTO STRICT nCount
	FROM filercvif r, filesndrcvinfoif c
	WHERE r.data_id = l_inDataId
	AND r.sr_stat = '0'
	AND r.data_id = c.data_id
	AND r.make_dt = c.make_dt
	AND r.make_cnt = c.make_cnt;
	-- データが無い場合
	IF nCount = 0 THEN
		-- カレンダ情報(Ｓ個別)を抽出
		nCount := 0;
		SELECT count(*) INTO STRICT nCount FROM calender_s;
		-- データがある場合
		If nCount != 0 THEN
			-- カレンダ情報(Ｓ個別)のデータを削除
			DELETE FROM calender_s;
			RETURN pkconstant.success();
		END IF;
	-- データがある場合
	ELSE
		-- 取得したデータを保存テーブルに登録
		INSERT INTO filesave(
			data_id,
			make_dt,
			make_cnt,
			data_seq,
			data_sect_filedbif
		) SELECT
			r.data_id,
			r.make_dt,
			r.make_cnt,
			r.data_seq,
			r.data_sect_filedbif
			FROM filercvif r, filesndrcvinfoif c
			WHERE r.data_id = l_inDataId
			AND r.sr_stat = '0'
			AND r.data_id = c.data_id
			AND r.make_dt = c.make_dt
			AND r.make_cnt = c.make_cnt;
		-- カレンダ(Ｓ個別)を抽出する
		nCount := 0;
		SELECT count(*) INTO STRICT nCount FROM calender_s;
		-- データがある場合
		IF nCount != 0 THEN
			-- カレンダ(Ｓ個別)のデータを削除
			DELETE FROM calender_s;
		END IF;
		-- 設定データを初期化(行番号に'1'を設定)
		nRow := 1;
		FOR recFileDS IN curFileDS LOOP
			cAd_yyyy := '';
			cMm := '';
			cDd_flg := '';
			cAd_yyyy := SUBSTR(recFileDS.data_sect_filedbif, 1, 4);
			cMm := SUBSTR(recFileDS.data_sect_filedbif, 6, 2);
			cDd_flg := SUBSTR(recFileDS.data_sect_filedbif, 9, 31);
			-- カレンダ(Ｓ個別)へ追加
			INSERT INTO calender_s(
				area_cd,
				ad_yyyy,
				mm,
				dd_flg,
				lin_no
			)
			VALUES (
				cArea_cd,
				cAd_yyyy,
				cMm,
				cDd_flg,
				nRow
			);
			-- 行番号をインクリメント
			nRow := nRow + 1;
			-- ファイル受信ＩＦの送受信ステータスを'1'に更新
			UPDATE filercvif
			SET sr_stat = '1'
			WHERE data_id = recFileDS.data_id
			AND make_dt = recFileDS.make_dt
			AND make_cnt = recFileDS.make_cnt
			AND data_seq = recFileDS.data_seq;
		END LOOP;
	END IF;
	RETURN pkconstant.success();
--==============================================================================
--                  エラー処理                                                  
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		-- ログ出力
		CALL pkLog.fatal(
			'ECM701',
			'IPF004K00R04',
			'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')'
		);
		RETURN pkconstant.FATAL();
--		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf004k00r04 ( l_inDataId scode.code_value%type  ) FROM PUBLIC;