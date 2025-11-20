CREATE OR REPLACE PROCEDURE spipf005k00r04 (
    l_inItakuId  TEXT,  -- 委託会社コード
    l_inDataId   VARCHAR,  -- データ種別
    l_outSqlCode OUT integer,                -- リターン値
    l_outSqlErrM OUT text                    -- エラーコメント
) AS $body$
DECLARE

/**
 * 著作権: Copyright (c) 2005
 * 会社名: JIP
 *
 * 金融機関支店情報を基に金融機関支店マスタを作成する
 * 
 * @author 戸倉　一成
 * @version $Revision: 1.10 $
 * 
 * @param l_inItakuId    IN     TEXT        委託会社コード
 *        l_inDataId     IN     TEXT        データ種別
 *        l_outSqlCode   OUT    NUMERIC      リターン値
 *        l_outSqlErrM   OUT    VARCHAR    エラーコメント
 * @return INTEGER
 *                0:正常終了
 *                1:予期したエラー
 *               40:データ無し
 *               99:予期せぬエラー
 */
--==============================================================================
--                  定数定義
--==============================================================================
    MSGID_CHECK_HANKAKU_EISU    CONSTANT varchar(6) := 'ECM039'; -- 半角英数チェックエラー
    MSGID_CHECK_ZENKAKU         CONSTANT varchar(6) := 'ECM009'; -- 全角チェックエラー
    MSGID_CHECK_CODE            CONSTANT varchar(6) := 'ECM305'; -- コード値チェックエラー
    MSGID_CHECK_NUMBER          CONSTANT varchar(6) := 'ECM002'; -- 数値チェックエラー
    MSGID_CHECK_ZENKAKU_KANA    CONSTANT varchar(6) := 'ECM058'; -- 全角カナチェックエラー
    MSGID_CHECK_KETASU          CONSTANT varchar(6) := 'ECM012'; -- 桁数チェックエラー
    MSGID_CHECK_HANKAKU         CONSTANT varchar(6) := 'ECM010'; -- 半角チェックエラー
    MSGID_CHECK_HIDUKE          CONSTANT varchar(6) := 'ECM005'; -- 日付チェックエラー
    MSGID_CHECK_HIKIOTOSHI      CONSTANT varchar(6) := 'ECM001'; -- 引落しチェックエラー
    MSGID_CHECK_FUKUSURAN       CONSTANT varchar(6) := 'ECM019'; -- 複数欄チェックエラー
    MSG_PARAM_ERROR CONSTANT varchar(30) := 'パラメーターエラー';
    MSG_NO_DATA     CONSTANT varchar(30) := 'データ無しエラー';
    MSG_DATA_ERROR  CONSTANT varchar(30) := 'データエラー';
    MSG_COMMON_ERR  CONSTANT varchar(30) := '共通関数エラー';
--==============================================================================
--                  変数定義
--==============================================================================
    nCount      numeric;                      -- 件数カウンタ
    nRtnCd      numeric;                      -- 正常処理フラグ
    nRtnCd2     integer;                      -- エラーリスト用
    cFlg        char(1) := '0';               -- エラーフラグ (0:正常,1:エラーあり)
    cRbFlg      char(1) := '0';               -- ロールバックフラグ (0:未バックアップ,1:バックアップ済)
    cMsgId      varchar(6);                      -- メッセージID
    vRtnErrMsg  text;                         -- エラーコメント (未使用だが型を拡張)
    cGyoumuDt   text;  -- 業務日付
--==============================================================================
--                  カーソル定義
--==============================================================================
    curMbank_Shiten CURSOR FOR
        SELECT
            financial_securities_kbn,
            bank_cd,
            shiten_cd,
            shiten_nm,
            shiten_rnm,
            shiten_kana_rnm,
            lin_no 
        FROM 
            mbank_shiten_trns 
        ORDER BY 
            financial_securities_kbn,
            bank_cd,
            shiten_cd;
--==============================================================================
--                  メイン処理
--==============================================================================
BEGIN
    -- 入力パラメータのチェック（委託会社コード）
    IF coalesce(trim(both l_inItakuId), '') = '' THEN
        l_outSqlCode := pkconstant.error();
        l_outSqlErrM := MSG_PARAM_ERROR;
        CALL pkLog.error('ECM501', 'IPF005K00R04',
                         '＜項目名称:委託会社コード＞＜項目値:' || l_inItakuId || '＞');
        RETURN;
    END IF;

    -- 入力パラメータのチェック（データ種別）
    IF coalesce(trim(both l_inDataId), '') = '' THEN
        l_outSqlCode := pkconstant.error();
        l_outSqlErrM := MSG_PARAM_ERROR;
        CALL pkLog.error('ECM501', 'IPF005K00R04',
                         '＜項目名称:データ種別＞＜項目値:' || l_inDataId || '＞');
        RETURN;
    END IF;

    -- 委託会社コードをチェック
    nCount := 0;
    SELECT count(*) INTO STRICT nCount
      FROM vjiko_itaku 
     WHERE kaiin_id = l_inItakuId;

    -- 委託会社コードが自行・委託会社マスタに存在しない場合
    IF nCount = 0 THEN
        l_outSqlCode := pkconstant.error();
        l_outSqlErrM := MSG_DATA_ERROR;
        CALL pkLog.error('ECM501', 'IPF005K00R04',
                         '＜項目名称:委託会社コード＞＜項目値:' || l_inItakuId || '＞');
        RETURN;
    END IF;

    -- データ種別をチェック
    nCount := 0;
    SELECT count(*) INTO STRICT nCount
      FROM scode
     WHERE code_shubetsu = '191'
       AND code_value    = l_inDataId;

    -- データ種別がコードマスタに存在しない場合
    IF nCount = 0 THEN
        l_outSqlCode := pkconstant.error();
        l_outSqlErrM := MSG_PARAM_ERROR;
        CALL pkLog.error('ECM501', 'IPF005K00R04',
                         '＜項目名称:データ種別＞＜項目値:' || l_inDataId || '＞');
        RETURN;
    END IF;

    -- 業務日付を取得
    cGyoumuDt := pkDate.getGyomuYmd();

    -- 帳票ワーク削除
    DELETE FROM sreport_wk
     WHERE key_cd      = l_inItakuId 
       AND user_id     = 'BATCH' 
       AND chohyo_kbn  = '1' 
       AND sakusei_ymd = cGyoumuDt 
       AND chohyo_id   = 'IPF30000111' 
       AND item003     = l_inDataId;

    -- 金融機関支店マスタ(移行用)の件数をチェック
    nCount := 0;
    SELECT count(*) INTO STRICT nCount
      FROM mbank_shiten_trns;

    -- 金融機関支店マスタ(移行用)の件数が０件の場合
    IF nCount = 0 THEN
        l_outSqlCode := pkconstant.NO_DATA_FIND();
        l_outSqlErrM := MSG_NO_DATA;
        CALL pkLog.error('EIP505', 'IPF005K00R04', MSG_NO_DATA);
        RETURN;
    END IF;

    -- 金融機関支店マスタの件数をチェック
    nCount := 0;
    SELECT count(*) INTO STRICT nCount
      FROM mbank_shiten;

    -- 金融機関支店マスタの件数が０件でない場合、データを削除する
    IF nCount != 0 THEN
        -- バックアップ
        DELETE FROM mbank_shiten_bk;

        INSERT INTO mbank_shiten_bk(
            financial_securities_kbn,
            bank_cd,
            shiten_cd,
            shiten_nm,
            shiten_rnm,
            shiten_kana_rnm,
            shori_kbn,
            last_teisei_dt,
            last_teisei_id,
            shonin_dt,
            shonin_id,
            kousin_dt,
            kousin_id,
            sakusei_dt,
            sakusei_id
        )
        SELECT  financial_securities_kbn,
                bank_cd,
                shiten_cd,
                shiten_nm,
                shiten_rnm,
                shiten_kana_rnm,
                shori_kbn,
                last_teisei_dt,
                last_teisei_id,
                shonin_dt,
                shonin_id,
                kousin_dt,
                kousin_id,
                sakusei_dt,
                sakusei_id
          FROM  mbank_shiten;

        -- データ削除
        DELETE FROM mbank_shiten
         WHERE financial_securities_kbn = '0';

        -- 金融機関支店マスタロールバックフラグに'1'を設定
        cRbFlg := '1';
    END IF;

    -- エラーフラグ初期化（全体エラー管理用）
    cFlg := '0';

    -- チェック、更新処理
    FOR recMbank_Shiten IN curMbank_Shiten LOOP

        -- コード値チェック
        nRtnCd := spipf005k00r04_common_func(
                      recMbank_Shiten.financial_securities_kbn,
                      '金融証券区分',
                      recMbank_Shiten.lin_no,
                      1,
                      l_inItakuId,
                      cGyoumuDt,
                      l_inDataId
                  );
        IF nRtnCd = 1 THEN
            cFlg := '1';
        END IF;

        -- 金融機関コードをチェック
        nCount := 0;
        SELECT count(*) INTO STRICT nCount
          FROM mbank
         WHERE financial_securities_kbn = recMbank_Shiten.financial_securities_kbn
           AND bank_cd                  = recMbank_Shiten.bank_cd
           AND shori_kbn                = '1';

        IF nCount = 0 THEN
            nRtnCd := spipf005k00r04_common_func(
                          recMbank_Shiten.bank_cd,
                          '金融機関コード',
                          recMbank_Shiten.lin_no,
                          5,
                          l_inItakuId,
                          cGyoumuDt,
                          l_inDataId
                      );
        END IF;

        IF nRtnCd = 1 THEN
            cFlg := '1';
        END IF;

        -- 数値チェック
        nRtnCd := spipf005k00r04_common_func(
                      recMbank_Shiten.bank_cd,
                      '金融機関コード',
                      recMbank_Shiten.lin_no,
                      2,
                      l_inItakuId,
                      cGyoumuDt,
                      l_inDataId
                  );
        IF nRtnCd = 1 THEN
            cFlg := '1';
        END IF;

        -- 桁数チェック・数値チェック (支店コード)
        IF LENGTH(trim(both recMbank_Shiten.shiten_cd)) = 3 THEN
            -- 数値チェック
            nRtnCd := spipf005k00r04_common_func(
                          recMbank_Shiten.shiten_cd,
                          '支店コード',
                          recMbank_Shiten.lin_no,
                          2,
                          l_inItakuId,
                          cGyoumuDt,
                          l_inDataId
                      );
        ELSE
            -- 桁数チェックエラー
            nRtnCd := spipf005k00r04_common_func(
                          recMbank_Shiten.shiten_cd,
                          '支店コード',
                          recMbank_Shiten.lin_no,
                          9,
                          l_inItakuId,
                          cGyoumuDt,
                          l_inDataId
                      );
        END IF;

        IF nRtnCd = 1 THEN
            cFlg := '1';
        END IF;

        -- 全角チェック（支店名称）
        nRtnCd := spipf005k00r04_common_func(
                      recMbank_Shiten.shiten_nm,
                      '支店名称',
                      recMbank_Shiten.lin_no,
                      3,
                      l_inItakuId,
                      cGyoumuDt,
                      l_inDataId
                  );
        IF nRtnCd = 1 THEN
            cFlg := '1';
        END IF;

        -- 全角チェック（支店略称）
        nRtnCd := spipf005k00r04_common_func(
                      recMbank_Shiten.shiten_rnm,
                      '支店略称',
                      recMbank_Shiten.lin_no,
                      3,
                      l_inItakuId,
                      cGyoumuDt,
                      l_inDataId
                  );
        IF nRtnCd = 1 THEN
            cFlg := '1';
        END IF;

        -- 全角カナチェック（支店略称（カナ））
        nRtnCd := spipf005k00r04_common_func(
                      recMbank_Shiten.shiten_kana_rnm,
                      '支店略称（カナ）',
                      recMbank_Shiten.lin_no,
                      4,
                      l_inItakuId,
                      cGyoumuDt,
                      l_inDataId
                  );
        IF nRtnCd = 1 THEN
            cFlg := '1';
        END IF;

        -- エラーフラグが'0'の場合、金融機関支店マスタへ書き込み
        IF cFlg = '0' THEN
            INSERT INTO mbank_shiten(
                financial_securities_kbn,
                bank_cd,
                shiten_cd,
                shiten_nm,
                shiten_rnm,
                shiten_kana_rnm,
                shori_kbn,
                last_teisei_dt,
                last_teisei_id,
                shonin_dt,
                shonin_id,
                kousin_dt,
                kousin_id,
                sakusei_dt,
                sakusei_id
            ) VALUES (
                recMbank_Shiten.financial_securities_kbn,
                recMbank_Shiten.bank_cd,
                recMbank_Shiten.shiten_cd,
                recMbank_Shiten.shiten_nm,
                recMbank_Shiten.shiten_rnm,
                recMbank_Shiten.shiten_kana_rnm,
                '1',
                current_timestamp,
                'ikou',
                current_timestamp,
                'ikou',
                current_timestamp,
                'ikou',
                current_timestamp,
                'ikou'
            );
        END IF;
    END LOOP;

    -- エラーフラグが'1'の場合、リターン値に'1'を設定してロールバック
    IF cFlg = '1' THEN
        DELETE FROM mbank_shiten;

        IF cRbFlg = '1' THEN
            -- 金融機関支店マスタロールバック処理
            INSERT INTO mbank_shiten(
                financial_securities_kbn,
                bank_cd,
                shiten_cd,
                shiten_nm,
                shiten_rnm,
                shiten_kana_rnm,
                shori_kbn,
                last_teisei_dt,
                last_teisei_id,
                shonin_dt,
                shonin_id,
                kousin_dt,
                kousin_id,
                sakusei_dt,
                sakusei_id
            )
            SELECT 
                financial_securities_kbn,
                bank_cd,
                shiten_cd,
                shiten_nm,
                shiten_rnm,
                shiten_kana_rnm,
                shori_kbn,
                last_teisei_dt,
                last_teisei_id,
                shonin_dt,
                shonin_id,
                kousin_dt,
                kousin_id,
                sakusei_dt,
                sakusei_id 
              FROM mbank_shiten_bk;
        END IF;

        l_outSqlCode := pkconstant.error();
        l_outSqlErrM := MSG_DATA_ERROR;
        CALL pkLog.error('ECM502', 'IPF005K00R04', MSG_DATA_ERROR);
    ELSE
        -- エラーフラグが'0'の場合、リターン値に'0'を設定
        l_outSqlCode := pkconstant.success();
        l_outSqlErrM := '';
    END IF;

    RETURN;

--==============================================================================
--                  エラー処理
--==============================================================================
EXCEPTION
    WHEN OTHERS THEN
        CALL pkLog.fatal('ECM701', 'IPF005K00R04',
                         'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
        l_outSqlCode := pkconstant.FATAL();
        l_outSqlErrM := SQLERRM || '(' || SQLSTATE || ')';
        RETURN;
END;
$body$
LANGUAGE plpgsql;

--==============================================================================
-- Nested Function: spipf005k00r04_common_func
-- パラメータを基に各共通関数を呼び出す
--==============================================================================
CREATE OR REPLACE FUNCTION spipf005k00r04_common_func (
    l_inwk1     VARCHAR,    -- 共通関数へ引き渡す文字列
    l_inwk2     VARCHAR,    -- 項目名称
    l_inwk3     numeric, -- 行番号
    l_inwk4     numeric, -- 共通関数振り分け用数値
    p_inItakuId TEXT,    -- 委託会社コード (from parent)
    p_cGyoumuDt TEXT,    -- 業務日付 (from parent)
    p_inDataId  VARCHAR     -- データ種別 (from parent)
) RETURNS integer AS $body$
DECLARE
    MSGID_CHECK_HANKAKU_EISU CONSTANT varchar(6) := 'ECM039';
    MSGID_CHECK_ZENKAKU      CONSTANT varchar(6) := 'ECM009';
    MSGID_CHECK_CODE         CONSTANT varchar(6) := 'ECM305';
    MSGID_CHECK_NUMBER       CONSTANT varchar(6) := 'ECM002';
    MSGID_CHECK_ZENKAKU_KANA CONSTANT varchar(6) := 'ECM058';
    MSGID_CHECK_KETASU       CONSTANT varchar(6) := 'ECM012';
    
    nRtnCd      numeric;
    nRtnCd2     integer;
    vRtnErrMsg  text;
    cMsgId      varchar(6);
BEGIN
    -- リターンコードを初期化
    nRtnCd := 0;

    CASE l_inwk4
        -- コードチェック
        WHEN 1 THEN
            cMsgId := MSGID_CHECK_CODE;
            IF LENGTH(trim(both l_inwk1)) > 0 THEN
                nRtnCd := sfCmIsCodeMChek('507', l_inwk1);
            ELSE
                nRtnCd := 1;
            END IF;

        -- 数値チェック
        WHEN 2 THEN
            cMsgId := MSGID_CHECK_NUMBER;
            IF LENGTH(trim(both l_inwk1)) > 0 THEN
                nRtnCd := sfCmIsNumeric(l_inwk1);
            ELSE
                nRtnCd := 1;
            END IF;

        -- 全角チェック
        WHEN 3 THEN
            cMsgId := MSGID_CHECK_ZENKAKU;
            IF LENGTH(trim(both l_inwk1)) > 0 THEN
                nRtnCd := sfCmIsFullsizeChar(l_inwk1);
            ELSE
                nRtnCd := 1;
            END IF;

        -- 全角カナチェック
        WHEN 4 THEN
            cMsgId := MSGID_CHECK_ZENKAKU_KANA;
            IF LENGTH(trim(both l_inwk1)) > 0 THEN
                nRtnCd := sfCmIsZenKana(l_inwk1);
            ELSE
                nRtnCd := 1;
            END IF;

        -- 金融機関コードの存在をチェック (呼び出し元で実際のチェック)
        WHEN 5 THEN
            nRtnCd := 1;
            cMsgId := MSGID_CHECK_CODE;

        -- 桁数チェックエラー
        ELSE
            nRtnCd := 1;
            cMsgId := MSGID_CHECK_KETASU;
    END CASE;

    -- 共通関数からの戻り値が'1'の場合、エラーリスト（共通）作成ＳＰを呼び出す
    IF nRtnCd = 1 THEN
        CALL SPIPF001K00R01(
            p_inItakuId,
            'BATCH', 
            '1', 
            '3', 
            p_cGyoumuDt,
            p_inDataId, 
            l_inwk3,
            l_inwk2, 
            l_inwk1, 
            cMsgId, 
            nRtnCd2, 
            vRtnErrMsg
        );

        
        RETURN nRtnCd;
    END IF;

    RETURN nRtnCd;
END;
$body$
LANGUAGE plpgsql;
