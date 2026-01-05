




CREATE OR REPLACE FUNCTION sfipi900k00r09 () RETURNS integer AS $body$
DECLARE

--
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 機構連携ガベージ処理
-- *
-- * 以下のガベージ処理を行います。
-- * ガベージタイミングがあるものは、機構連携データ保存日数を過ぎたデータが対象です。
-- *
-- * 機構連携テーブル
-- * 送受信テーブル
-- * オンラインリアル用DBIF
-- * ファイル伝送用DBIF
-- * 機構連携、送受信ワークテーブル
-- * 採番管理テーブル
-- *
-- *
-- * @author  磯田
-- * @version $Id: SFIPI900K00R09.sql,v 1.1 2006/02/07 12:46:15 isoda Exp $
-- *
-- * @return 	リターンコード		INTEGER
-- *   		 pkconstant.success()				: 正常
-- *           pkconstant.error() 				: DB障害
-- 
--==============================================================================
--                  変数定義                                                    
--==============================================================================
    gRtn integer;
    gGyomuYmd character(8);
    gKkDataSaveDd       smallint;
    gSoujuDataSaveDd    smallint;
    gOnlineFlg          character(1);
    gFileDensoFlg       character(1);
--==============================================================================
--                  定数定義                                                    
--==============================================================================
	-- 本SPのID
	SP_ID				CONSTANT varchar(20) := 'SFIPI900K00R09';
	-- ユーザID
	USER_ID				CONSTANT varchar(10) := pkconstant.BATCH_USER();
    ONLINE              CONSTANT varchar(1)  := '1';
    FILE_DENSOU         CONSTANT varchar(1)  := '1';
    INIT_NUM            CONSTANT numeric       := 0;
    ERR_CD_E            CONSTANT varchar(6)  := 'ECM602';
    ERR_CD_F            CONSTANT varchar(6)  := 'ECM701';
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	gRtn := pkconstant.FATAL();
	CALL pkLog.debug(USER_ID, '', SP_ID || ' START');
    -- 業務日付の取得
    gGyomuYmd := pkDate.getGyomuYmd();
    SELECT
        KK_DATA_SAVE_DD,
        SOUJU_DATA_SAVE_DD,
        ONLINE_FLG,
        FILE_DENSO_FLG
    INTO STRICT
        gKkDataSaveDd,
        gSoujuDataSaveDd,
        gOnlineFlg,
        gFileDensoFlg
    FROM
        SOWN_INFO;
    -- 送受信テーブル
    gRtn := SFIPI900K00R09_deleteSoujusin(gGyomuYmd,gSoujuDataSaveDd);
    IF gRtn <> pkconstant.success() THEN
        CALL pkLog.DEBUG(ERR_CD_E,SP_ID,'送受信テーブルガベージ処理に失敗しましたが、処理を続行します。');
        CALL pkLog.DEBUG(SP_ID,USER_ID,SUBSTR(SQLERRM, 1, 100));
    END IF;
    -- 機構連携テーブル
    gRtn := SFIPI900K00R09_deleteKkRenkei(gGyomuYmd,gKkDataSaveDd);
    IF gRtn <> pkconstant.success() THEN
        CALL pkLog.DEBUG(ERR_CD_E,SP_ID,'機構連携テーブルガベージ処理に失敗しましたが、処理を続行します。');
        CALL pkLog.DEBUG(SP_ID,USER_ID,SUBSTR(SQLERRM, 1, 100));
    END IF;
    -- DBIFテーブル削除　オンラインリアル
    IF gOnlineFlg = ONLINE THEN
        gRtn := SFIPI900K00R09_deleteDBIFReal();
        IF gRtn <> pkconstant.success() THEN
            CALL pkLog.DEBUG(ERR_CD_E,SP_ID,'オンラインリアル用DBIFガベージ処理に失敗しましたが、処理を続行します。');
            CALL pkLog.DEBUG(SP_ID,USER_ID,SUBSTR(SQLERRM, 1, 100));
        END IF;
    END IF;
    -- DBIFテーブル削除　ファイル伝送
    IF gFileDensoFlg = FILE_DENSOU THEN
        gRtn := SFIPI900K00R09_deleteDBIFFile();
        IF gRtn <> pkconstant.success() THEN
            CALL pkLog.DEBUG(ERR_CD_E,SP_ID,'ファイル伝送用DBIFガベージ処理に失敗しましたが、処理を続行します。');
            CALL pkLog.DEBUG(SP_ID,USER_ID,SUBSTR(SQLERRM, 1, 100));
        END IF;
    END IF;
    -- 送受信テーブルワークテーブル
    -- 機構連携ワークテーブル
    gRtn := SFIPI900K00R09_deleteWork();
    IF gRtn <> pkconstant.success() THEN
        CALL pkLog.DEBUG(ERR_CD_E,SP_ID,'ワークテーブルガベージ処理に失敗しましたが、処理を続行します。');
        CALL pkLog.DEBUG(SP_ID,USER_ID,SUBSTR(SQLERRM, 1, 100));
    END IF;
    -- 採番管理テーブルのクリア
    gRtn := SFIPI900K00R09_clearSaibanKanri(INIT_NUM);
    IF gRtn <> pkconstant.success() THEN
        CALL pkLog.DEBUG(ERR_CD_E,SP_ID,'採番管理テーブル初期化処理に失敗しましたが、処理を続行します。');
        CALL pkLog.DEBUG(SP_ID,USER_ID,SUBSTR(SQLERRM, 1, 100));
    END IF;
	CALL pkLog.debug(USER_ID, '', SP_ID || ' END RETURN ' || gRtn);
    RETURN gRtn;
--==============================================================================
--                  異常終了 出口                                               
--==============================================================================
EXCEPTION
	-- その他・例外エラー 
	WHEN OTHERS THEN
		CALL pkLog.fatal(ERR_CD_F, SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
		RETURN pkconstant.error();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi900k00r09 () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipi900k00r09_clearsaibankanri (l_inSeqNoMax numeric(16,0)) RETURNS integer AS $body$
DECLARE

        rtn             integer;
        updSql          varchar(200);
        SP_ID           CONSTANT varchar(20) := 'SFIPI900K00R09';
        USER_ID         CONSTANT varchar(10) := pkconstant.BATCH_USER();
        TABLE_NM        CONSTANT varchar(30) := 'SAIBAN_KANRI';

BEGIN
        rtn := pkconstant.FATAL();
        CALL pkLog.DEBUG(SP_ID,USER_ID,'採番管理テーブルの採番初期化を行います。');
        updSql := '';
        updSql :=   ' UPDATE ' || TABLE_NM
            ||      ' SET '
            ||      ' SEQ_NO_MAX = ' || l_inSeqNoMax;
        BEGIN
            EXECUTE updSql;
        EXCEPTION
            WHEN OTHERS THEN
                CALL pkLog.DEBUG(SP_ID,USER_ID,TABLE_NM || 'テーブルが存在しないため、無視します。');
        END;
        CALL pkLog.DEBUG(SP_ID,USER_ID,'採番管理テーブルの採番初期化が完了しました。');
        rtn := pkconstant.success();
        RETURN rtn;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi900k00r09_clearsaibankanri (l_inSeqNoMax numeric(16,0)) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipi900k00r09_deletedbiffile () RETURNS integer AS $body$
DECLARE

        ora2pg_rowcount int;
rtn             integer;
        delSql          varchar(200);
        SP_ID           CONSTANT varchar(20) := 'SFIPI900K00R09';
        USER_ID         CONSTANT varchar(10) := pkconstant.BATCH_USER();
        TABLE_NM        CONSTANT varchar(30) := 'FJASDECFILERCVIF';

BEGIN
        rtn := pkconstant.FATAL();
        CALL pkLog.DEBUG(SP_ID,USER_ID,'ファイル伝送受信用DBIFの削除処理を行います。');
        delSql := '';
        delSql :=   ' DELETE FROM ' || TABLE_NM;
        BEGIN
            EXECUTE delSql;
        EXCEPTION
            WHEN OTHERS THEN
                CALL pkLog.DEBUG(SP_ID,USER_ID,TABLE_NM || 'テーブルが存在しないため、無視します。');
        END;
        GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;

        CALL pkLog.DEBUG(SP_ID,USER_ID,'ファイル伝送受信用DBIF：' ||  ora2pg_rowcount || '件削除しました。');
        rtn := pkconstant.success();
        RETURN rtn;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi900k00r09_deletedbiffile () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipi900k00r09_deletedbifreal () RETURNS integer AS $body$
DECLARE

        ora2pg_rowcount int;
rtn             integer;
        delSql          varchar(200);
        SP_ID           CONSTANT varchar(20) := 'SFIPI900K00R09';
        USER_ID         CONSTANT varchar(10) := pkconstant.BATCH_USER();
        TABLE_NM        CONSTANT varchar(30) := 'FJASDECMatchRcvIF';

BEGIN
        rtn := pkconstant.FATAL();
        CALL pkLog.DEBUG(SP_ID,USER_ID,'オンラインリアル用DBIFの削除処理を行います。');
        delSql := '';
        delSql :=   ' DELETE FROM ' || TABLE_NM;
        BEGIN
            EXECUTE delSql;
        EXCEPTION
            WHEN OTHERS THEN
                CALL pkLog.DEBUG(SP_ID,USER_ID,TABLE_NM || 'テーブルが存在しないため、無視します。');
        END;
        GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;

        CALL pkLog.DEBUG(SP_ID,USER_ID,'オンラインリアル用DBIF：' ||  ora2pg_rowcount || '件削除しました。');
        rtn := pkconstant.success();
        RETURN rtn;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi900k00r09_deletedbifreal () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipi900k00r09_deletekkrenkei ( l_inGyomuYmd character(8), l_inKkDataSaveDd smallint ) RETURNS integer AS $body$
DECLARE

        ora2pg_rowcount int;
rtn             integer;
        cnt             numeric := 0;
        gDate           character(8);
        SP_ID           CONSTANT varchar(20) := 'SFIPI900K00R09';
        USER_ID         CONSTANT varchar(10) := pkconstant.BATCH_USER();

BEGIN
        rtn := pkconstant.FATAL();
        -- 業務日付 - 機構連携データ保存日数の日付を取得
        gDate := pkDate.getMinusDate(l_inGyomuYmd,l_inKkDataSaveDd);
        CALL pkLog.DEBUG(SP_ID,USER_ID,'機構連携テーブルデータの削除処理を行います。');
        -- 送信完了分
        DELETE
        FROM
            KK_RENKEI RT02
        WHERE (trim(both RT02.SOUJU_DT) IS NOT NULL AND (trim(both RT02.SOUJU_DT))::text <> '') AND SUBSTR(RT02.SOUJU_DT,1,8) <= gDate;
        GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;

        cnt := cnt +  ora2pg_rowcount;
        -- 対応完了済分・取消分
        DELETE
        FROM
            KK_RENKEI RT02
        WHERE SUBSTR(RT02.KK_SAKUSEI_DT,1,8) <= gDate AND RT02.DENBUN_STAT in ('14','19');
        GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;

        cnt := cnt +  ora2pg_rowcount;
        CALL pkLog.DEBUG(SP_ID,USER_ID,'機構連携テーブルデータ：' || cnt || '件削除しました。');
        rtn := pkconstant.success();
        RETURN rtn;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi900k00r09_deletekkrenkei ( l_inGyomuYmd character(8), l_inKkDataSaveDd smallint ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipi900k00r09_deletesoujusin ( l_inGyomuYmd character(8), l_inSoujuDataSaveDd smallint ) RETURNS integer AS $body$
DECLARE

        ora2pg_rowcount int;
rtn             integer;
        gDate           character(8);
        SP_ID           CONSTANT varchar(20) := 'SFIPI900K00R09';
        USER_ID         CONSTANT varchar(10) := pkconstant.BATCH_USER();

BEGIN
        rtn := pkconstant.FATAL();
        -- 業務日付 - 機構連携データ保存日数の日付を取得
        gDate := pkDate.getMinusDate(l_inGyomuYmd,l_inSoujuDataSaveDd);
        CALL pkLog.DEBUG(SP_ID,USER_ID,'送受信テーブルデータの削除処理を行います。');
        DELETE
        FROM
            SOUJUSIN
        WHERE
            SUBSTR(SOUJU_DT,1,8) <= gDate;
        GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;

        CALL pkLog.DEBUG(SP_ID,USER_ID,'送受信テーブルデータ：' ||  ora2pg_rowcount || '件削除しました。');
        rtn := pkconstant.success();
        RETURN rtn;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi900k00r09_deletesoujusin ( l_inGyomuYmd character(8), l_inSoujuDataSaveDd smallint ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipi900k00r09_deletework () RETURNS integer AS $body$
DECLARE

        rtn             integer;

BEGIN
        rtn := pkconstant.FATAL();
        -- ワークテーブルは無条件でクリアする
        DELETE FROM SOUJUSIN_WORK;
        DELETE FROM KK_RENKEI_WORK;
        rtn := pkconstant.success();
        RETURN rtn;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi900k00r09_deletework () FROM PUBLIC;