




CREATE OR REPLACE FUNCTION sfipi078k00r00 (l_inItakuKaishaCd SOWN_INFO.KAIIN_ID%TYPE DEFAULT NULL) RETURNS integer AS $body$
DECLARE

--
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 締め処理帳票出力（バッチ用）
-- *
-- * 締め処理時に作成される帳票を夜間バッチで作成するためのＳＰです。
-- * 以下の帳票を作成します。
-- *
-- * 各種バッチ帳票出力指示画面から、作成区分「日次」で出力することができます。
-- * また、引数に委託会社コードを設定することによって、
-- * 指定した１つの委託会社に対して帳票を作成区分「随時」で作成します。
-- * デフォルト（夜間）は委託会社を指定せず、全委託会社分処理を行います。
-- *
-- * 当日オペ件数一覧
-- * 当日送受信件数一覧
-- * 銘柄登録事前警告リスト
-- * 銘柄情報変更警告リスト
-- * 変動利率情報送信対象リスト（オプション）
-- * 作業日管理（備忘録）リスト（オプション）
-- *
-- * @author  磯田
-- * @version $Id: SFIPI078K00R00.sql,v 1.6 2017/01/04 11:00:25 fujii Exp $
-- * @return 	リターンコード		INTEGER
-- 
--====================================================================
--					デバッグ機能										  
--====================================================================
	DEBUG	numeric(1)	:= 1;
--====================================================================*
--                    変数定義
-- *====================================================================
 
    -- 委託会社コード 
    gItakuKaishaCd      MGR_KIHON.ITAKU_KAISHA_CD%TYPE;
    -- 業務日付 
    gGyomuYmd           SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;
    -- 帳票区分 
    gChohyoKbn          SREPORT_WK.CHOHYO_KBN%TYPE;
    -- 帳票作成区分 
    gChohyoSakuseiKbn   PRT_OK.LIST_SAKUSEI_KBN%TYPE;
    -- 作表ＳＰリターン用 
    gSqlCode            numeric;
    gSqlErrM            varchar(1000);
    -- オプションフラグ 
    gOptionFlg   MOPTION_KANRI.OPTION_FLG%TYPE := '0';  -- オプションフラグ
    total_cnt 		varchar(5);
--====================================================================*
--                    定数定義
-- *====================================================================
	-- SP_ID 
	SP_ID				CONSTANT varchar(30) := 'SFIPI078K00R00';
    -- USER_ID 
	USER_ID				CONSTANT varchar(20) := pkconstant.BATCH_USER();
    -- 帳票作成区分（日次） 
    CHOHYO_SAKUSEI_KBN_DAY      CONSTANT PRT_OK.LIST_SAKUSEI_KBN%TYPE  := pkPrtOk.LIST_SAKUSEI_KBN_DAY();
    -- 帳票作成区分（随時） 
    CHOHYO_SAKUSEI_KBN_ZUIJI    CONSTANT PRT_OK.LIST_SAKUSEI_KBN%TYPE  := pkPrtOk.LIST_SAKUSEI_KBN_ZUIJI();
    -- 帳票区分（リアル）（画面） 
    CHOHYO_KBN_ZUIJI            CONSTANT SREPORT_WK.CHOHYO_KBN%TYPE  := pkKakuninList.CHOHYO_KBN_ZUIJI();
    -- 帳票区分（バッチ）（夜間） 
    CHOHYO_KBN_BATCH            CONSTANT SREPORT_WK.CHOHYO_KBN%TYPE  := pkKakuninList.CHOHYO_KBN_BATCH();
    -- リターンコード（対象データ無し） 
    RTN_NO_DATA         CONSTANT varchar(2)  := '2';
    -- 当日オペ件数一覧 
    REPORT_ID_O         CONSTANT varchar(20) := 'IP030007811';
    -- 当日送受信件数一覧 
    REPORT_ID_S         CONSTANT varchar(20) := 'IP030007821';
    -- 銘柄登録事前警告リスト 
    REPORT_ID_R         CONSTANT varchar(20) := 'IP030007831';
    -- 銘柄情報変更警告リスト 
    REPORT_ID_C         CONSTANT varchar(20) := 'IP030007841';
    -- 警告リスト（共通）リスト 
    REPORT_ID_K         CONSTANT varchar(20) := 'IP030007851';
    -- 変動利率情報送信対象リスト 
    REPORT_ID_H         CONSTANT varchar(20) := 'IPX30007811';
    -- 締め処理未承認データー一覧 
    REPORT_ID_M         CONSTANT varchar(20) := 'IP030007861';
	-- 締め処理未承認データー一覧オプション 
    MISHONIN_OP			CONSTANT varchar(15) := 'IPX010064010h';
    -- 作業日管理（備忘録）リスト 
    REPORT_ID_SAGYO     CONSTANT varchar(20) := 'IPX30001911';
	-- 作業日管理（備忘録）リストオプション 
    SAGYOBIKR_OP		CONSTANT varchar(15) := 'IPX100630504';
--====================================================================*
--					カーソル定義
-- *====================================================================
    --*
--     * 委託会社一覧取得
--     *
--     * 引数に委託会社が指定されている場合は指定した委託会社のみ取得 
--     *
--     * @param   l_inItakuKaishaCd   委託会社コード（指定されている場合)
--     * @return  itakuKaishaCd       委託会社コード
--     * @return  itakuKaishaRnm      委託会社略称
--     * @return  bicCd               ＢＩＣコード
--     
    cVjikoItaku CURSOR(l_inItakuKaishaCd  VJIKO_ITAKU.KAIIN_ID%TYPE) FOR
        SELECT
            VJ1.KAIIN_ID    AS itakuKaishaCd,
            VJ1.BANK_RNM    AS itakuKaishaRnm,
            VJ1.BIC_CD      AS bicCd
        FROM
            VJIKO_ITAKU VJ1
        WHERE (VJ1.KAIIN_ID = l_inItakuKaishaCd OR coalesce(l_inItakuKaishaCd::text, '') = '');
--====================================================================*
--   メイン
-- *====================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(SP_ID, USER_ID, ' START');	END IF;
    -- 業務日付の取得
    gGyomuYmd := pkDate.getGyomuYmd();
    -- 帳票区分、帳票作成区分の設定
    gChohyoKbn := CHOHYO_KBN_BATCH;
    gChohyoSakuseiKbn := CHOHYO_SAKUSEI_KBN_DAY;
    IF (trim(both l_inItakuKaishaCd) IS NOT NULL AND (trim(both l_inItakuKaishaCd))::text <> '') THEN
        CALL pkLog.DEBUG(SP_ID,USER_ID,'引数に委託会社コードが設定されているので、１つの委託会社に対してのみ処理を行います');
        gItakuKaishaCd := l_inItakuKaishaCd;
        gChohyoKbn := CHOHYO_KBN_ZUIJI;
    END IF;
    -- 委託会社ごとに処理する    
    FOR rVjikoItaku IN cVjikoItaku(gItakuKaishaCd) LOOP
        gItakuKaishaCd := rVjikoItaku.itakuKaishaCd;
        CALL pkLog.DEBUG(SP_ID,USER_ID,'処理する委託会社コード：' || gItakuKaishaCd );
        -- 当日オペ件数一覧 
        CALL SPIP07811(gItakuKaishaCd,USER_ID,gChohyoKbn,gGyomuYmd,gSqlCode,gSqlErrM);
        -- リターンチェック
        IF gSqlCode = pkconstant.success() THEN
            -- 正常ならバッチ帳票印刷管理テーブル登録
            CALL pkPrtOk.insertPrtOk(USER_ID,gItakuKaishaCd,gGyomuYmd,gChohyoSakuseiKbn,REPORT_ID_O);
        ELSIF gSqlCode = RTN_NO_DATA THEN
            CALL pkLog.DEBUG(SP_ID,USER_ID,'当日オペ件数一覧が対象データ無しのため、PRT_OKには登録しません。');
        ELSE
            CALL pkLog.DEBUG(SP_ID,USER_ID,'当日オペ件数一覧作成に失敗しましたが、処理を続行します。');
            CALL pkLog.DEBUG(SP_ID,USER_ID,SUBSTR(gSqlErrM, 1, 100));
        END IF;
        -- 当日送受信件数一覧 
        CALL SPIP07821(gItakuKaishaCd,USER_ID,gChohyoKbn,gGyomuYmd,gSqlCode,gSqlErrM);
        IF gSqlCode = pkconstant.success() THEN
            CALL pkPrtOk.insertPrtOk(USER_ID,gItakuKaishaCd,gGyomuYmd,gChohyoSakuseiKbn,REPORT_ID_S);
        ELSIF gSqlCode = RTN_NO_DATA THEN
            CALL pkLog.DEBUG(SP_ID,USER_ID,'当日送受信件数一覧が対象データ無しのため、PRT_OKには登録しません。');
        ELSE
            CALL pkLog.DEBUG(SP_ID,USER_ID,'当日送受信件数一覧作成に失敗しましたが、処理を続行します。');
            CALL pkLog.DEBUG(SP_ID,USER_ID,SUBSTR(gSqlErrM, 1, 100));
        END IF;
        -- 銘柄登録事前警告リスト         
        CALL SPIP07831(gItakuKaishaCd,USER_ID,gChohyoKbn,gGyomuYmd,gSqlCode,gSqlErrM);
        IF gSqlCode = pkconstant.success() THEN
            CALL pkPrtOk.insertPrtOk(USER_ID,gItakuKaishaCd,gGyomuYmd,gChohyoSakuseiKbn,REPORT_ID_R);
        ELSIF gSqlCode = RTN_NO_DATA THEN
            CALL pkLog.DEBUG(SP_ID,USER_ID,'銘柄登録事前警告リストが対象データ無しのため、PRT_OKには登録しません。');
        ELSE
            CALL pkLog.DEBUG(SP_ID,USER_ID,'銘柄登録事前警告リスト作成に失敗しましたが、処理を続行します。');
            CALL pkLog.DEBUG(SP_ID,USER_ID,SUBSTR(gSqlErrM, 1, 100));
        END IF;
        -- 銘柄情報変更警告リスト 
        CALL SPIP07841(gItakuKaishaCd,USER_ID,gChohyoKbn,gGyomuYmd,gSqlCode,gSqlErrM);
        IF gSqlCode = pkconstant.success() THEN
            CALL pkPrtOk.insertPrtOk(USER_ID,gItakuKaishaCd,gGyomuYmd,gChohyoSakuseiKbn,REPORT_ID_C);
        ELSIF gSqlCode = RTN_NO_DATA THEN
            CALL pkLog.DEBUG(SP_ID,USER_ID,'銘柄情報変更警告リストが対象データ無しのため、PRT_OKには登録しません。');
        ELSE
            CALL pkLog.DEBUG(SP_ID,USER_ID,'銘柄情報変更警告リスト作成に失敗しましたが、処理を続行します。');
            CALL pkLog.DEBUG(SP_ID,USER_ID,SUBSTR(gSqlErrM, 1, 100));
        END IF;
		-- 警告リスト（共通）リスト 
		CALL SPIP07851(gItakuKaishaCd,USER_ID,gChohyoKbn,gGyomuYmd,gSqlCode,gSqlErrM);
		IF gSqlCode = pkconstant.success() THEN
			CALL pkPrtOk.insertPrtOk(USER_ID,gItakuKaishaCd,gGyomuYmd,gChohyoSakuseiKbn,REPORT_ID_K);
		ELSIF gSqlCode = RTN_NO_DATA THEN
			CALL pkLog.DEBUG(SP_ID,USER_ID,'警告リスト（共通）が対象データ無しのため、PRT_OKには登録しません。');
		ELSE
			CALL pkLog.DEBUG(SP_ID,USER_ID,'警告リスト（共通）作成に失敗しましたが、処理を続行します。');
			CALL pkLog.DEBUG(SP_ID,USER_ID,SUBSTR(gSqlErrM, 1, 100));
		END IF;
		-- 変動利率情報送信対象リスト 
		
		-- オプションフラグ取得
		gOptionFlg := pkControl.getOPTION_FLG(gItakuKaishaCd, REPORT_ID_H, '0');
		-- オプションフラグが１の場合のみ変動利率情報送信対象リストを作成する（対象データなし時も作成する）
		IF gOptionFlg = '1' THEN
            CALL SPIPX078K00R01(gItakuKaishaCd,USER_ID,gChohyoKbn,gGyomuYmd,gSqlCode,gSqlErrM);
            IF gSqlCode = pkconstant.success() THEN
                CALL pkPrtOk.insertPrtOk(USER_ID,gItakuKaishaCd,gGyomuYmd,gChohyoSakuseiKbn,REPORT_ID_H);
            ELSIF gSqlCode = pkconstant.NO_DATA_FIND() THEN
				CALL pkPrtOk.insertPrtOk(USER_ID,gItakuKaishaCd,gGyomuYmd,gChohyoSakuseiKbn,REPORT_ID_H);
            ELSE
                CALL pkLog.DEBUG(SP_ID,USER_ID,'変動利率情報送信対象リスト作成に失敗しましたが、処理を続行します。');
                CALL pkLog.DEBUG(SP_ID,USER_ID,SUBSTR(gSqlErrM, 1, 100));
            END IF;
        END IF;
        -- 未承認データ一覧 
		
		-- オプションフラグ取得
		gOptionFlg := pkControl.getOPTION_FLG(gItakuKaishaCd, MISHONIN_OP, '0');
		-- オプションフラグが１の場合のみ未承認データ一覧を作成する（対象データなし時は作成しない）
		IF gOptionFlg = '1' THEN
            CALL SPIP07861(gItakuKaishaCd, 'BATCH', '1', gGyomuYmd, '0', total_cnt, gSqlCode, gSqlErrM);
			IF gSqlCode = pkconstant.success() THEN
				CALL pkPrtOk.insertPrtOk(USER_ID,gItakuKaishaCd,gGyomuYmd,gChohyoSakuseiKbn,REPORT_ID_M);
			ELSIF gSqlCode = RTN_NO_DATA THEN
				CALL pkLog.DEBUG(SP_ID,USER_ID,'未承認データ一覧が対象データ無しのため、PRT_OKには登録しません。');
			ELSE
				CALL pkLog.DEBUG(SP_ID,USER_ID,'未承認データ一覧作成に失敗しましたが、処理を続行します。');
				CALL pkLog.DEBUG(SP_ID,USER_ID,SUBSTR(gSqlErrM, 1, 100));
			END IF;
        END IF;
        -- 作業日管理（備忘録）リスト 
		
		-- オプションフラグ取得
		gOptionFlg := pkControl.getOPTION_FLG(gItakuKaishaCd, SAGYOBIKR_OP, '0');
		-- オプションフラグが１の場合のみ作業日管理（備忘録）リストを作成する（対象データなし時は作成しない）
		IF gOptionFlg = '1' THEN
            CALL SPIPX1911(gItakuKaishaCd, 'BATCH', '1', gGyomuYmd, gSqlCode, gSqlErrM);
			IF gSqlCode = pkconstant.success() THEN
				CALL pkPrtOk.insertPrtOk(USER_ID,gItakuKaishaCd,gGyomuYmd,gChohyoSakuseiKbn,REPORT_ID_SAGYO);
			ELSIF gSqlCode = RTN_NO_DATA THEN
				CALL pkLog.DEBUG(SP_ID,USER_ID,'作業日管理（備忘録）リストが対象データ無しのため、PRT_OKには登録しません。');
			ELSE
				CALL pkLog.DEBUG(SP_ID,USER_ID,'作業日管理（備忘録）リスト作成に失敗しましたが、処理を続行します。');
				CALL pkLog.DEBUG(SP_ID,USER_ID,SUBSTR(gSqlErrM, 1, 100));
			END IF;
        END IF;
    END LOOP;
	IF DEBUG = 1 THEN	CALL pkLog.debug(SP_ID, USER_ID, ' END');	END IF;
    RETURN pkconstant.success();
--====================================================================*
--    異常終了 出口
-- *====================================================================
EXCEPTION
	-- その他・例外エラー 
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SP_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', SP_ID, 'SQLERRM:' || SQLERRM);
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi078k00r00 (l_inItakuKaishaCd SOWN_INFO.KAIIN_ID%TYPE DEFAULT NULL) FROM PUBLIC;