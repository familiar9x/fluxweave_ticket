




CREATE OR REPLACE PROCEDURE spip04604 ( 
    l_inUserId SUSER.USER_ID%TYPE,                 -- ユーザID
 l_inItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE, -- 委託会社コード
 l_inKijunYmdFrom MGR_RBRKIJ.KKN_CHOKYU_YMD%TYPE,     -- 基準日From
 l_inKijunYmdTo MGR_RBRKIJ.KKN_CHOKYU_YMD%TYPE,     -- 基準日To
 l_inKknZndkKjnYmdKbn text,							-- 基金残高基準日区分
 l_inHktCd MHAKKOTAI.HKT_CD%TYPE,              -- 発行体コード
 l_inKozaTenCd MHAKKOTAI.KOZA_TEN_CD%TYPE,         -- 口座店コード
 l_inKozaTenCifcd MHAKKOTAI.KOZA_TEN_CIFCD%TYPE,      -- 口座店CIFコード
 l_inMgrCd MGR_STS.MGR_CD%TYPE,                -- 銘柄コード
 l_inIsinCd MGR_KIHON.ISIN_CD%TYPE,             -- ISINコード
 l_inTsuchiYmd text,                           -- 通知日
 l_outSqlCode OUT integer,                             -- リターン値
 l_outSqlErrM OUT text                            -- エラーコメント
 ) AS $body$
DECLARE

--
-- * 著作権:Copyright(c)2006
-- * 会社名:JIP
-- * 概要　:顧客宛帳票出力指示画面の入力条件により、元利払基金・手数料請求明細書を作成する。
-- * @param     l_inUserId            ユーザID
-- * @param     l_inItakuKaishaCd     委託会社コード
-- * @param     l_inKijunYmdFrom      基準日From
-- * @param     l_inKijunYmdTo        基準日To
-- * @param     l_inKknZndkKjunYmdKbn 基金残高基準日区分
-- * @param     l_inHktCd             発行体コード
-- * @param     l_inKozaTenCd         口座店コード
-- * @param     l_inKozaTenCifcd      口座店CIFコード
-- * @param     l_inMgrCd             銘柄コード
-- * @param     l_inIsinCd            ISINコード
-- * @param     l_inTsuchiYmd         通知日
-- * @param     l_outSqlCode          リターン値
-- * @param     l_outSqlErrM          エラーコメント
-- *
-- * @return なし
-- *
-- * @author ASK 
-- * @version $Id: SPIP04604.sql,v 1.3 2008/09/10 02:17:10 morita Exp $ 
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付    開発者名        目的
-- * -------------------------------------------------------------------
-- *　2006.12.15    ASK                新規作成
-- *　2006.12.25    ASK                パラメータ追加：銘柄CD・ISINCD・通知日
-- *
-- ***************************************************************************
-- 
--==============================================================================
--                    デバッグ機能                                                    
--==============================================================================
    DEBUG    numeric(1)    := 0;
--==============================================================================
--                    変数定義                                                    
--==============================================================================
    gReturnCode         integer := 0;
    l_GyomuYmd          char(8);
    l_KjnYmdFrom        char(8);
    l_KjnYmdTo          char(8);
    l_ReportId          char(11);
    l_tempSqlCode       integer;
    l_tempSqlErrM       text;
    l_extraParam        integer;
--==============================================================================
--    メイン処理    
--==============================================================================
BEGIN
    -- 業務日付取得
    l_GyomuYmd := PKDATE.getGyomuYmd();
    -- 帳票ID取得
    l_ReportId := pkIpaKknIdo.c_seikyu_meisai();
    IF DEBUG = 1 THEN    CALL pkLog.debug(l_inUserId, l_ReportId, 'spIp04604 START');END IF;
    -- 入力パラメータのチェック ※期日From-Toは必須入力項目
    IF  coalesce(trim(both l_inUserId)::text, '') = '' OR
        coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' OR (coalesce(trim(both l_inKijunYmdFrom)::text, '') = '' AND coalesce(trim(both l_inKijunYmdTo)::text, '') = '')
    THEN
        -- パラメータエラー
        IF DEBUG = 1 THEN    CALL pkLog.debug(l_inUserId, l_ReportId, 'param error');END IF;
        l_outSqlCode := pkconstant.FATAL();
        l_outSqlErrM := '';
        CALL pkLog.fatal('ECM501', l_ReportId, 'パラメータエラー');
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
    SELECT result.l_outsqlcode, result.l_outsqlerrm, result.extra_param
    INTO l_tempSqlCode, l_tempSqlErrM, l_extraParam
    FROM pkipakknido.insKikinIdoSeikyuOut(l_inuserid,
                                           l_GyomuYmd,
                                           l_KjnYmdFrom,
                                           l_KjnYmdTo,
                                           l_initakukaishacd,
                                           l_inKknZndkKjnYmdKbn,
                                           l_inhktcd,
                                           l_inkozatencd,
                                           l_inKozaTenCifCd,
                                           l_inMgrCd,
                                           l_inIsinCd,
                                           l_inTsuchiYmd,
                                           l_ReportId,
                                           PKIPACALCTESURYO.C_REAL(),
                                           PKIPACALCTESURYO.C_DATA_KBN_SEIKYU(),
                                           PKIPACALCTESURYO.C_SI_KBN_SEIKYU(),
                                           SPIP04604_getChikoFlg(l_initakukaishacd),
                                           '0' --フロント照会画面判別フラグ '0'(フロント照会画面以外)
                                           ) AS result;
    
    gReturnCode := l_tempSqlCode;
    --終了処理
    IF gReturnCode = pkconstant.success() THEN
        l_outSqlCode := gReturnCode;
        l_outSqlErrM := '';
    ELSE
        l_outSqlCode := l_tempSqlCode;
        l_outSqlErrM := l_tempSqlErrM;
    END IF;
    IF DEBUG = 1 THEN    CALL pkLog.debug(l_inUserId, l_ReportId, 'spIp04604 END');END IF;
-- エラー処理
EXCEPTION
    WHEN    OTHERS    THEN
        CALL pkLog.fatal('ECM701', l_ReportId, 'SQLCODE:' || SQLSTATE);
        CALL pkLog.fatal('ECM701', l_ReportId, 'SQLERRM:' || SQLERRM);
        l_outSqlCode := pkconstant.FATAL();
        l_outSqlErrM := SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip04604 ( l_inUserId SUSER.USER_ID%TYPE, l_inItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE, l_inKijunYmdFrom MGR_RBRKIJ.KKN_CHOKYU_YMD%TYPE, l_inKijunYmdTo MGR_RBRKIJ.KKN_CHOKYU_YMD%TYPE, l_inKknZndkKjnYmdKbn text, l_inHktCd MHAKKOTAI.HKT_CD%TYPE, l_inKozaTenCd MHAKKOTAI.KOZA_TEN_CD%TYPE, l_inKozaTenCifcd MHAKKOTAI.KOZA_TEN_CIFCD%TYPE, l_inMgrCd MGR_STS.MGR_CD%TYPE, l_inIsinCd MGR_KIHON.ISIN_CD%TYPE, l_inTsuchiYmd text, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spip04604_getchikoflg ( l_initakukaishacd TEXT ) RETURNS char AS $body$
DECLARE

        gChikoFlg    SOWN_INFO.CHIKO_FLG%TYPE;

BEGIN
        --地公体フラグの取得
        SELECT
            chiko_flg
        INTO STRICT
            gChikoFlg
        FROM
            vjiko_itaku
        WHERE
            kaiin_id = l_initakukaishacd;
        RETURN gChikoFlg;
    END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spip04604_getchikoflg ( l_initakukaishacd TEXT ) FROM PUBLIC;