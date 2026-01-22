




CREATE OR REPLACE FUNCTION sfipf010k01r09 () RETURNS numeric AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * リアル共有DBIF（受信）から、未処理データの存在の有無をチェックする。
-- * 
-- * @author 倉澤　健史
-- * @version $Revision: 1.11 $
-- * $Id: SFIPF010K01R09.sql,v 1.11 2005/11/04 10:12:44 kubo Exp $
-- * @param  
-- * @return INTEGER
-- *                0:正常終了、データ無し
-- *               99:予期せぬエラー
-- 
--============================================================================== 
--                  定数定義                                                    
--==============================================================================
	returnValue	numeric(02)  := 0;
	WK_STAT         TOYOKONAIIF.KONAIIF_CONNECT_STAT%type;
	WK_TOYO_REC_SU  numeric      := 0;
	WK_O_CODE       integer;
	WK_O_ERRM       text;
	vMsgLog			varchar(300);			-- ログ出力用メッセージ
	cWk_kaiin		text;				-- 会員ＩＤ 
	vTableName		varchar(300);			-- テーブル名称
	cGyoumuDt		text;				-- 業務日付
--  当預リアル受信IFテーブルより未処理データ抽出
	CUR_TOYO CURSOR FOR
	   SELECT	DATA_ID,
	  		MAKE_DT,
	  		DATA_SEQ,
	  		DATA_SECT
	   FROM		TOYOREALRCVIF
	   WHERE	SR_STAT     =   '0'
           ORDER BY	DATA_ID,
	                MAKE_DT,
			DATA_SEQ;

BEGIN
--  行内IF管理情報テーブル取得
        SELECT  KONAIIF_CONNECT_STAT  INTO  WK_STAT   FROM  TOYOKONAIIF LIMIT 1;
		IF      WK_STAT               !=    '1'   THEN                      --  処理待ち以外　
			returnValue           :=     0;
			IF WK_STAT = '0' THEN
				-- 業務日付を取得
				cGyoumuDt := pkDate.getGyomuYmd();
				-- 自行情報マスタより会員IDを取得
				SELECT kaiin_id INTO cWk_kaiin
				FROM sown_info LIMIT 1;
				-- ログ出力用メッセージ
				vMsgLog := '閉局処理後エラー';
				-- エラーリスト用テーブル名称
				vTableName := '行内IF管理情報テーブル';
				-- ログ出力
				CALL pkLog.error(
					'EIP525',
					'IPF010K01R09',
					vMsgLog
				);
				-- エラーリスト出力
				CALL SPIPF001K00R01(
					cWk_kaiin::text,
					'BATCH'::varchar, 
					'1'::text, 
					'3'::text, 
					cGyoumuDt::text, 
					'60'::varchar, 
					9999999999::numeric, 
					vTableName, 
					vMsgLog,
					'EIP525'::varchar, 
					WK_O_CODE, 
					WK_O_ERRM
				);
				-- メッセージ通知テーブルへ書き込み
				returnValue := SfIpMsgTsuchiUpdate(
					cWk_kaiin,
					'RTGS',
					'警告',
					'1',
					'0',
					vMsgLog,
					'BATCH',
					'BATCH'
				);
				RETURN pkconstant.error();
			ELSE
				-- ログ出力
				CALL pkLog.error(
				'WIP503',
				'IPF010K01R09',
				'＜テーブル名：行内IF管理情報テーブル（当預）、status：' || WK_STAT || '＞'
				);
				RETURN returnValue;
			END IF;
		END IF;
        IF      WK_STAT                =    '1'   THEN                      --  処理待ち　
        UPDATE  TOYOKONAIIF  SET  KONAIIF_CONNECT_STAT  =  '2';    --  処理待ちから処理中に(接続ステータス） 
--  COMMIT実行
        COMMIT;
-- 当預リアル受信IFテーブルの件数をチェック
	        SELECT count(*)       INTO   WK_TOYO_REC_SU     FROM	   TOYOREALRCVIF
	                              WHERE  SR_STAT     =   '0';
		    IF  WK_TOYO_REC_SU         =     0    THEN
	        UPDATE  TOYOKONAIIF  SET  KONAIIF_CONNECT_STAT  =  '1';    --  未処理データがない場合処理待ちにする(接続ステータス）
	        returnValue           :=     0;
                RETURN returnValue;
	    ELSE
	        FOR  REC_TOYO   IN   CUR_TOYO     LOOP
		     CALL SPIPF010K01R05(REC_TOYO.DATA_ID,
		                      REC_TOYO.MAKE_DT,
				      REC_TOYO.DATA_SEQ,
                                      REC_TOYO.DATA_SECT,
				      WK_O_CODE,
				      WK_O_ERRM);
                     IF  WK_O_CODE        =    99     THEN
		         RAISE EXCEPTION 'k01r05_err' USING ERRCODE = '50001';
                     END IF;
--                                                                         /*  処理済みにする(送受信ステータス）*/
		     UPDATE  TOYOREALRCVIF  SET  SR_STAT   =  '1'
		       WHERE (DATA_ID  =    REC_TOYO.DATA_ID)    AND (MAKE_DT  =    REC_TOYO.MAKE_DT)    AND (DATA_SEQ =    REC_TOYO.DATA_SEQ);
	        END LOOP;
--                                                                         /*  処理待ちにする(接続ステータス) */
		UPDATE  TOYOKONAIIF  SET    KONAIIF_CONNECT_STAT  =  1;
	        returnValue           :=     0;
                RETURN returnValue;
	    END IF;
	 END IF;
EXCEPTION
	WHEN  SQLSTATE '50001' THEN
	      returnValue             :=    99;
	      CALL pkLog.fatal('ECM701', 'IPF010K01R09', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
	      RETURN pkconstant.fatal();
	WHEN  OTHERS 		THEN
	      returnValue             :=    99;
	      CALL pkLog.fatal('ECM701', 'IPF010K01R09', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
	      RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf010k01r09 () FROM PUBLIC;
