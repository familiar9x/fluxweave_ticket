




CREATE OR REPLACE FUNCTION sfipi037k15r01 () RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2017
-- * 会社名: JIP
-- *
-- * 償還スケジュール表を作成する。（バッチ用）
-- *
-- * @author AXIS
-- * @version $Id: SFIPI037K15R01.sql,v 1.0 2017/02/10 09:46:34 $
-- *
-- * @return INTEGER 0:正常、99:異常、それ以外：エラー
-- 
--==============================================================================
--                  定数定義                                                        
--==============================================================================
    C_FUNCTION_ID  CONSTANT varchar(50) := 'SFIPI037K15R01';
    C_CHOHYO_ID    CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IP030003711'; -- 帳票ＩＤ
--==============================================================================
--                  変数定義                                                        
--==============================================================================
    gReturnCode             integer := 0;
    gSqlErrm                varchar(1000);
    gKaiinID                MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE;
    gGyomuYmd               SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;
    gYokuBusinessYmd        SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;
    gSeqNoMax               numeric := 0;
    ----------------------------------------------------------------------
    -- カーソル定義
    ----------------------------------------------------------------------
    -- 銘柄SELECT
    curMGR_SELECT CURSOR(
        l_inGyomuYmd            SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE,
        l_inItakuKaishaCdPrm    MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE
    )FOR
        SELECT VMG1.MGR_CD
        FROM   MGR_KIHON_VIEW VMG1,
               MGR_KIKO_KIHON MG9,
               MHAKKOTAI M01,
               MHAKKOTAI2 BT01,
               MGR_TESURYO_PRM MG8
        WHERE
               VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCdPrm
        AND    VMG1.MGR_STAT_KBN = '1'              -- 承認済
        AND    VMG1.ISIN_CD <> ' '
        AND    VMG1.JTK_KBN <> '2'                  -- 副受託
        AND    VMG1.JTK_KBN <> '5'                  -- 自社発行
        AND    to_char(MG9.SAKUSEI_DT, 'YYYYMMDD')  = l_inGyomuYmd
        AND    MG8.NYUKIN_KOZA_KBN <> 'D'           -- 総合振込
        AND    VMG1.HAKKO_TSUKA_CD = 'JPY'
        AND    VMG1.SHOKAN_TSUKA_CD = 'JPY'
        AND (coalesce(trim(both VMG1.RBR_TSUKA_CD)::text, '') = '' OR VMG1.RBR_TSUKA_CD = 'JPY')   -- 割引債はNULL、それ以外は何かしら設定されている項目
        AND    VMG1.ITAKU_KAISHA_CD = MG9.ITAKU_KAISHA_CD
        AND    VMG1.MGR_CD = MG9.MGR_CD
        AND    VMG1.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD
        AND    VMG1.MGR_CD = MG8.MGR_CD
        AND    VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
        AND    VMG1.HKT_CD = M01.HKT_CD
        AND    VMG1.ITAKU_KAISHA_CD = BT01.ITAKU_KAISHA_CD
        AND    VMG1.HKT_CD = BT01.HKT_CD 
        ORDER BY M01.KOZA_TEN_CD,
                 M01.KOZA_TEN_CIFCD,
                 BT01.KYOTEN_KBN,
                 VMG1.DPT_ASSUMP_FLG,
                 VMG1.HAKKO_YMD,
                 VMG1.ISIN_CD;
    recMGR_SELECT RECORD;
--==============================================================================
--                  メイン処理                                                    
--==============================================================================
BEGIN
    CALL pkLog.debug('BATCH', C_FUNCTION_ID , '--------------------------------------------------Start--------------------------------------------------');
    -- 業務日付を取得
    gGyomuYmd := pkDate.getGyomuYmd();
    -- 会員IDを取得
    gKaiinID := pkConstant.getKaiinId();
    -- 翌営業日を取得
    gYokuBusinessYmd := pkDate.getYokuBusinessYmd(gGyomuYmd);
    DELETE FROM SREPORT_WK
            WHERE KEY_CD = gKaiinID
             AND USER_ID = 'BATCH'
              AND CHOHYO_KBN = PKIPACALCTESURYO.C_BATCH()
              AND SAKUSEI_YMD = gGyomuYmd
              AND CHOHYO_ID = C_CHOHYO_ID;
    FOR recMGR_SELECT IN curMGR_SELECT(gGyomuYmd, gKaiinID)
    LOOP
        -- 償還スケジュール表作成
        CALL SPIP03701(
            'BATCH',                        -- ユーザID
            gKaiinID,                       -- 委託会社コード
            recMGR_SELECT.MGR_CD,           -- 銘柄コード
            NULL,                           -- ISINコード
            gYokuBusinessYmd,               -- 通知日(= 発行日)
            PKIPACALCTESURYO.C_REAL(),        -- 帳票区分
            gReturnCode,
            gSqlErrm
        );
        IF gReturnCode = pkconstant.success() THEN
            -- 帳票区分、連番を更新
            UPDATE SREPORT_WK SC16
            SET
                   SC16.CHOHYO_KBN  = '1'  -- バッチ
                  ,SC16.SEQ_NO      = SC16.SEQ_NO + gSeqNoMax   -- 連番を既存の最大値の後ろにスライド
            WHERE
                   SC16.KEY_CD      = gKaiinID
            AND    SC16.USER_ID     = 'BATCH'
            AND    SC16.CHOHYO_KBN  = '0'
            AND    SC16.SAKUSEI_YMD = gGyomuYmd
            AND    SC16.CHOHYO_ID   = C_CHOHYO_ID;
            -- 現在の連番の最大値＋1を取得
            SELECT MAX(SC16.SEQ_NO) + 1
            INTO STRICT   gSeqNoMax
            FROM   SREPORT_WK SC16
            WHERE
                   SC16.KEY_CD      = gKaiinID
            AND    SC16.USER_ID     = 'BATCH'
            AND    SC16.CHOHYO_KBN  = '1'
            AND    SC16.SAKUSEI_YMD = gGyomuYmd
            AND    SC16.CHOHYO_ID   = C_CHOHYO_ID;
		ELSIF gReturnCode = PKIPACALCTESURYO.C_NODATA() THEN
			DELETE FROM SREPORT_WK
			WHERE KEY_CD = gKaiinID
			  AND USER_ID = 'BATCH'
			  AND CHOHYO_KBN = PKIPACALCTESURYO.C_REAL()
			  AND SAKUSEI_YMD = gGyomuYmd
			  AND CHOHYO_ID = C_CHOHYO_ID;
			gReturnCode := pkconstant.success();
			CALL pkLog.debug('Batch', C_FUNCTION_ID, '委託会社：' || gKaiinID || '銘柄コード：' || recMGR_SELECT.MGR_CD ||' 対象データなし');
        ELSE
            -- 異常終了
            CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'エラーコード'||SQLSTATE);
            CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'エラー内容'||SQLERRM);
            RETURN gReturnCode;
        END IF;
    END LOOP;
    CALL pkLog.debug('BATCH', C_FUNCTION_ID, '返値（正常）');
    CALL pkLog.debug('BATCH', C_FUNCTION_ID, '---------------------------------------------------End---------------------------------------------------');
    RETURN gReturnCode;
--=========< エラー処理 >==========================================================
EXCEPTION
    WHEN OTHERS THEN
        CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'SQLCODE:'||SQLSTATE);
        CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'SQLERRM:'||SQLERRM);
        RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi037k15r01 () FROM PUBLIC;
