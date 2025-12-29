




CREATE OR REPLACE FUNCTION sfipx025k00r01 () RETURNS integer AS $body$
DECLARE

ora2pg_rowcount int;
--*
-- * 著作権:Copyright(c)2023
-- * 会社名:JIP
-- *
-- * 概要　:差込帳票出力ファイル保存データについて、システム情報マスタのCSVジャーナル保存年数によってデータガベージを行う。
-- *
-- * 引数　:なし
-- *
-- * 返り値: 0:正常
-- *
-- * @author aoki
-- * @version $Id: SFIPX025K00R01.sql,v 1.2 2023/07/14 10:09:55 kanayama Exp $
-- 
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	result		            integer;				        -- リターンコード
	gGyomuYmd               char(8);                        -- 業務日付
	g2monthAgo              char(8);                        -- 業務日付2か月前の月末日
	gJigyouYr               char(4);                        -- 業務日付を基準とした事業年度
	gCsvJournalSaveYrs      numeric;                         -- 保存年数
	gKijunYr                char(4);                        -- ガベージ対象年
	gJigyouYrLastDt         char(8);                        -- ガベージ対象となる事業年度末日
	gNextJigyouYrLastDt     char(8);                        -- ガベージ対象となる事業年度末日の翌日
	gJigyouStartDt          char(8);                        -- ガベージ対象となる事業年度開始日
--==============================================================================
--                  定数定義                                                    
--==============================================================================
	-- SPID
	SP_ID				CONSTANT varchar(20) := 'SFIPX025K00R01';
	-- ユーザID
	USER_ID				CONSTANT varchar(10) := pkconstant.BATCH_USER();
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 戻り値初期化
	result := pkconstant.success();
	-- 業務日付の取得
	gGyomuYmd := pkDate.getGyomuYmd();
	-- 差込帳票出力ファイル保存データ保存期間の取得
	SELECT
	    CSV_JOURNAL_SAVE_YEARS
	INTO STRICT
	    gCsvJournalSaveYrs
	FROM
	    SSYSTEM_INFO
	WHERE
	    KAIIN_ID = pkconstant.kaiinid();
	-- 削除対象とする処理日を算出する
	-- 『課税期間（事業年度）の末日の翌日から2月経過した日』を起算日として「CSVジャーナル保存年数」を保存期間とする。
	-- 業務日付の2か月前の月末日を取得
	g2monthAgo := pkDate.getGetsumatsuYmd(substring(gGyomuYmd from 1 for 6) || '01', -2);
	-- 業務日付の2か月前の事業年度を取得
	IF (substring(g2monthAgo from 5 for 2))::numeric  > (pkconstant.KESSAN_MONTH())::numeric  THEN
		gJigyouYr := substring(g2monthAgo from 1 for 4);
	ELSE
		gJigyouYr := TO_CHAR((substring(g2monthAgo from 1 for 4))::numeric  -1,'FM0000');
	END IF;
	-- 業務日付の2か月前の事業年度から差込帳票出力ファイル保存データ保存期間の年数分引く →削除対象の年度末日の年になる
	gKijunYr := TO_CHAR((gJigyouYr)::numeric  - gCsvJournalSaveYrs, 'FM0000');
	-- 削除対象となる事業年度末日を算出
	gJigyouYrLastDt := pkDate.getGetsumatsuYmd(gKijunYr || pkconstant.KESSAN_MONTH() || '01', 0);
	-- 事業年度末日の翌日を算出（翌年度初めを求める）
	gNextJigyouYrLastDt := pkDate.getYokuYmd(gJigyouYrLastDt);
	-- 事業年度開始日を算出（翌年度初めから12か月マイナスしたら、年度開始日になる）
	gJigyouStartDt := pkDate.calcMonth(gNextJigyouYrLastDt, -12);
	CALL pkLog.DEBUG(SP_ID,USER_ID,'差込帳票出力ファイル保存データの削除処理を行います。');
	-- 差込帳票出力ファイル保存データを削除する
	DELETE FROM
	    GREPORT_OUTPUT_FILE_SAVE
	WHERE
	    substring(trim(both OUT_DT) from 1 for 8) BETWEEN gJigyouStartDt AND gJigyouYrLastDt;
	GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;

	CALL pkLog.DEBUG(SP_ID,USER_ID,'差込帳票出力ファイル保存データ：' ||  pkcharacter.numeric_to_char(ora2pg_rowcount) || '件削除しました。');
	RETURN result;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipx025k00r01 () FROM PUBLIC;
