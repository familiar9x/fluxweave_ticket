CREATE OR REPLACE PROCEDURE spip05501 (
    l_inUserId          SUSER.USER_ID%TYPE,
    l_inItakuKaishaCd   MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE,
    l_inKijunYmdFrom    MGR_RBRKIJ.KKN_CHOKYU_YMD%TYPE,
    l_inKijunYmdTo      MGR_RBRKIJ.KKN_CHOKYU_YMD%TYPE,
    l_inHktCd           MHAKKOTAI.HKT_CD%TYPE,
    l_inKozaTenCd       MHAKKOTAI.KOZA_TEN_CD%TYPE,
    l_inKozaTenCifcd    MHAKKOTAI.KOZA_TEN_CIFCD%TYPE,
    l_inMgrCd           MGR_STS.MGR_CD%TYPE,
    l_inIsinCd          MGR_KIHON.ISIN_CD%TYPE,
    l_inTsuchiYmd       text,
    l_inFrontFlg        text,
    l_outSqlCode OUT  integer,
    l_outSqlErrM OUT  text
)
LANGUAGE plpgsql
AS $body$
DECLARE
    -- 著作権:Copyright(c)2005
    -- 会社名:JIP
    -- @author 山下　健太(NOA)
    -- @version $Revision: 1.11 $
    -- 概要　:顧客宛帳票出力指示画面の入力条件により、期中管理手数料請求書を作成する。

    --==============================================================================
    --					デバッグ機能													
    --==============================================================================
    DEBUG               numeric(1) := 0;

    --==============================================================================
    --					定数定義													
    --==============================================================================
    RTN_OK              CONSTANT integer      := 0;
    RTN_FATAL           CONSTANT integer      := 99;
    REPORT_ID_SEIKYUSHO CONSTANT char(11)     := 'IP030005511';
    REPORT_ID_RYOSHUSHO CONSTANT char(11)     := 'IP030005521';

    --==============================================================================
    --					変数定義													
    --==============================================================================
    gRtnCd              integer := RTN_OK;
    gSeqNo              integer := 0;
    l_GyomuYmd          char(8);
    l_KjnYmdFrom        char(8);
    l_KjnYmdTo          char(8);
    l_tempSqlCode       integer;
    l_tempSqlErrM       text;
    l_extraParam        integer;

--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
    -- 業務日付取得
    l_GyomuYmd := PKDATE.getGyomuYmd();

    IF DEBUG = 1 THEN
        CALL pkLog.debug(l_inUserId, REPORT_ID_SEIKYUSHO, 'spIp05501 START');
    END IF;

    -- 入力パラメータのチェック ※期日From-Toは必須入力項目
    IF coalesce(trim(both l_inKijunYmdFrom)::text, '') = ''
    AND coalesce(trim(both l_inKijunYmdTo)::text, '') = ''
    THEN
        -- パラメータエラー
        IF DEBUG = 1 THEN
            CALL pkLog.debug(l_inUserId, REPORT_ID_SEIKYUSHO, 'param error');
        END IF;
        l_outSqlCode := pkconstant.error();
        l_outSqlErrM := '';
        CALL pkLog.error(l_inUserId, REPORT_ID_SEIKYUSHO, 'SQLERRM:'||'');
        RETURN;
    END IF;

    -- パラメータの基準日From-Toをセット
    l_KjnYmdFrom := l_inKijunYmdFrom;
    l_KjnYmdTo   := l_inKijunYmdTo;

    -- 基準日Toのみ入力されている場合はFromに最小値を、Fromのみの場合はToに最大値をセットする。
    IF coalesce(trim(both l_inKijunYmdFrom)::text, '') = '' THEN
        l_KjnYmdFrom := '00000000';
    END IF;
    IF coalesce(trim(both l_KjnYmdTo)::text, '') = '' THEN
        l_KjnYmdTo := '99999999';
    END IF;

    -- データ取得
    -- 基金請求計算処理（請求書）※リアル・請求書出力・請求書
    RAISE NOTICE 'Calling insKichuTesuryoSeikyuOut...';
    SELECT l_outsqlcode, l_outsqlerrm, extra_param
    INTO l_tempSqlCode, l_tempSqlErrM, l_extraParam
    FROM pkipakichutesuryo.insKichuTesuryoSeikyuOut(
        l_inuserid,
        l_GyomuYmd,
        l_KjnYmdFrom,
        l_KjnYmdTo,
        l_initakukaishacd,
        l_inhktcd,
        l_inkozatencd,
        l_inKozaTenCifCd,
        l_inMgrCd,
        l_inisincd,
        l_inTsuchiYmd,
        REPORT_ID_SEIKYUSHO,
        PKIPACALCTESURYO.C_REAL(),
        PKIPACALCTESURYO.C_DATA_KBN_SEIKYU(),
        PKIPACALCTESURYO.C_SI_KBN_SEIKYU(),
        l_inFrontFlg
    );
    
    gRtnCd := l_tempSqlCode;
    RAISE NOTICE 'Result: gRtnCd=%, l_tempSqlCode=%, l_tempSqlErrM=%', gRtnCd, l_tempSqlCode, COALESCE(l_tempSqlErrM, 'NULL');

    IF gRtnCd <> pkconstant.success() THEN
        RAISE NOTICE 'Error detected: setting output and returning';
        l_outSqlCode := l_tempSqlCode;
        l_outSqlErrM := l_tempSqlErrM;
        RETURN;
    END IF;

    -- 終了処理
    l_outSqlCode := gRtnCd;
    l_outSqlErrM := '';

    IF DEBUG = 1 THEN
        CALL pkLog.debug(l_inUserId, REPORT_ID_SEIKYUSHO, 'ROWCOUNT:'||gSeqNo);
    END IF;
    IF DEBUG = 1 THEN
        CALL pkLog.debug(l_inUserId, REPORT_ID_SEIKYUSHO, 'spIp05501 END');
    END IF;

-- エラー処理
EXCEPTION
    WHEN OTHERS THEN
        CALL pkLog.fatal('ECM701', REPORT_ID_SEIKYUSHO, 'SQLSTATE:'||SQLSTATE);
        CALL pkLog.fatal('ECM701', REPORT_ID_SEIKYUSHO, 'SQLERRM:'||SQLERRM);
        l_outSqlCode := RTN_FATAL;
        l_outSqlErrM := SQLERRM;
END;
$body$;