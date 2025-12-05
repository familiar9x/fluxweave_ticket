


DROP TYPE IF EXISTS sfipx046k15r01_01_type_record;
CREATE TYPE sfipx046k15r01_01_type_record AS (
		ITAKU_KAISHA_CD		char(4),				-- 委託会社コード
		MGR_CD			varchar(13),					-- 銘柄コード
		RBR_KJT			char(8),				-- 利払期日
		CHOKYU_YMD		char(8)				-- 徴求日
	);


CREATE OR REPLACE FUNCTION sfipx046k15r01_01 ( l_initakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE ) RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2016
-- * 会社名: JIP
-- *
-- * 元利払基金・手数料請求書（領収書）【単票】データを作成する（バッチ用）
-- * １．請求データ検索処理
-- * ２．元利払基金・手数料請求書（領収書）【単票】作表処理
-- * ３．バッチ帳票出力ＯＮ処理
-- *
-- * @author Y.Nagano
-- * @version $Id: SFIPX046K15R01_01.sql,v 1.0 2016/12/20 10:19:30 Y.Nagano Exp $
-- *
-- * @param l_initakuKaishaCd 委託会社コード
-- * @return INTEGER 0:正常
-- *                99:異常、それ以外：エラー
-- 
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gReturnCode			integer := 0;
	gCur REFCURSOR;	--システム設定分と個別設定分を取得するカーソル
	gGyomuYmd			SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;
	gKjtFrom			MGR_TESKIJ.CHOKYU_KJT%TYPE;
	gKjtTo				MGR_TESKIJ.CHOKYU_KJT%TYPE;
	gSeqNo				integer := 0;
	gSeqNo2				integer := 0;
	gMaxSeqNo			integer := 0;
	gSQL				varchar(10000) := NULL;		-- SQL格納用変数
	gREPORT_ID			CONSTANT char(11) := 'IP931504651';	-- レポートＩＤ
	wkChohyoId			SREPORT_WK.CHOHYO_ID%TYPE;		-- ワーク帳票ＩＤ
	wkChohyoId2			SREPORT_WK.CHOHYO_ID%TYPE;		-- ワーク帳票ＩＤ２
	gOutSqlErrM			varchar(5000) := NULL;		-- エラーコメント
	pRbrYmdFrom 		char(8) := '00000000';          -- 徴求日 From
	pRbrYmdTo     		char(8) := '99999999';          -- 徴求日 To
	gOptionFlg	MOPTION_KANRI.OPTION_FLG%TYPE;			 -- オプションフラグ
	gSqlErrm                varchar(1000);          -- エラーメッセージ
	-- レコードタイプ宣言
	-- レコード
	rec sfipx046k15r01_01_type_record[];
	tempRec sfipx046k15r01_01_type_record;
--==============================================================================
--					メイン処理													
--==============================================================================
BEGIN
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
	-- 請求書出力設定テーブルから、出力期間を取得する（業務日付が出力日ではない場合、From-Toは'99999999'で返る）
	CALL PKIPACALCTESURYO.GETBATCHSEIKYUOUTFROMTO(l_initakukaishacd,		-- 委託会社コード
						 '1',				-- 請求書区分（１：元利金、２：手数料）
						 gKjtFrom,			-- 戻り値１：期間From
						 gKjtTo);
	-- システム設定分と個別設定分の請求書作成データを取得するためのカーソル文を作成する
	gSQL := pkIpaKknIdo.createSQL(gGyomuYmd, gKjtFrom, gKjtTo, l_initakukaishacd, '', '', '', '', '', '1','','');
  -- カウントの初期化
	gSeqNo := 0;
	-- カーソルオープン
	OPEN gCur FOR EXECUTE gSQL;
	LOOP
		-- Fetch into temporary record
		FETCH gCur INTO
			tempRec.ITAKU_KAISHA_CD,
			tempRec.MGR_CD,
			tempRec.RBR_KJT,
			tempRec.CHOKYU_YMD;
		-- データが無くなったらループを抜ける
		EXIT WHEN NOT FOUND;/* apply on gCur */
		-- Append temp record to array
		rec := array_append(rec, tempRec);
		-- シーケンスナンバーをカウントアップしておく
		gSeqNo := gSeqNo + 1;
	-- レコード数分ループの終了
	END LOOP;
	-- カーソルクローズ
	CLOSE gCur;
	-- ワーク帳票ＩＤ取得 (IPをWKに置き換え)
	wkChohyoId := REPLACE(gREPORT_ID, 'IP', 'WK');
	-- ワーク帳票ＩＤ２取得 (IPをWKに置き換え)
	wkChohyoId2 := REPLACE(gREPORT_ID, 'IP', 'KW');
	-- 作票を開始するためワークに残っているかもしれないデータをDELETE
	DELETE FROM SREPORT_WK WHERE CHOHYO_ID = wkChohyoId;
  DELETE FROM SREPORT_WK
  WHERE KEY_CD = l_initakuKaishaCd
  AND USER_ID = pkconstant.BATCH_USER()
  AND SAKUSEI_YMD = gGyomuYmd
  AND CHOHYO_ID = wkChohyoId2;
	-- 公社債関連資金受入予定表出力対象をワークに格納
	-- 最大値を保持してカウンタを初期化
	gMaxSeqNo := gSeqNo;
	gSeqNo := 1;
	FOR gSeqNo IN 1..gMaxSeqNo LOOP
		-- 請求書作票処理をおこなう
		-- ワークデータ作成
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := rec[gSeqNo].MGR_CD;	-- 銘柄コード
		v_item.l_inItem002 := rec[gSeqNo].RBR_KJT;	-- 利払期日
		v_item.l_inItem003 := rec[gSeqNo].CHOKYU_YMD;	-- 徴求日
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> rec[gSeqNo].ITAKU_KAISHA_CD,
			l_inUserId		=> pkconstant.BATCH_USER(),
			l_inChohyoKbn	=> '1',
			l_inSakuseiYmd	=> gGyomuYmd,
			l_inChohyoId	=> wkChohyoId,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> pkconstant.BATCH_USER(),
			l_inSakuseiId	=> pkconstant.BATCH_USER()
		);
		-- 警告リスト用のデータ登録をおこなう
		-- ワークデータ作成
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := rec[gSeqNo].MGR_CD;	-- 銘柄コード
		v_item.l_inItem002 := rec[gSeqNo].RBR_KJT;	-- 利払期日
		v_item.l_inItem003 := rec[gSeqNo].CHOKYU_YMD;	-- 徴求日
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> rec[gSeqNo].ITAKU_KAISHA_CD,
			l_inUserId		=> pkconstant.BATCH_USER(),
			l_inChohyoKbn	=> '1',
			l_inSakuseiYmd	=> gGyomuYmd,
			l_inChohyoId	=> wkChohyoId2,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> pkconstant.BATCH_USER(),
			l_inSakuseiId	=> pkconstant.BATCH_USER()
		);
		gSeqNo2 := gSeqNo2 + 1;
	END LOOP;
  -- オプションフラグ(実質記番号)取得
  gOptionFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd, 'IPP1003302010','0');
  RAISE NOTICE '[DEBUG] gOptionFlg = %, gSeqNo = %', gOptionFlg, gSeqNo;
  -- 実質記番号管理オプションが'1''の場合
  IF gOptionFlg = '1' THEN
         -- 実質記番号管理オプション　基金異動計算・更新処理
         RAISE NOTICE '[DEBUG] Calling SFIPX046K15R01_01_insKknIdo';
         SELECT * FROM SFIPX046K15R01_01_insKknIdo(pkconstant.BATCH_USER(), gKjtFrom, gKjtTo, l_inItakuKaishaCd, '', '', '', '', '', gREPORT_ID, '1', '1', '') INTO STRICT gSqlErrm, gReturnCode;
         IF gReturnCode <> 0 THEN
            CALL pkLog.error('ECM701', 'SFIPX046K15R01_01', 'エラーメッセージ：'|| gSqlErrm);
            RAISE NOTICE '[DEBUG] SFIPX046K15R01_01_insKknIdo returned error: %', gReturnCode;
            RETURN gReturnCode;
         END IF;
  END IF;
	-- 元利払基金・手数料請求書（領収書）【単票】の作成
	RAISE NOTICE '[DEBUG] Calling SPIPX046K15R02';
	BEGIN
		CALL SPIPX046K15R02(pkconstant.BATCH_USER(), gGyomuYmd, pRbrYmdFrom, pRbrYmdTo, l_initakuKaishaCd, '', '', '', '', '', '', gREPORT_ID, '1', gReturnCode, gOutSqlErrM);
	EXCEPTION
		WHEN OTHERS THEN
			RAISE NOTICE '[DEBUG] Error in SPIPX046K15R02: SQLSTATE=%, SQLERRM=%', SQLSTATE, SQLERRM;
			RAISE;
	END;
	-- 元利払基金・手数料請求書（領収書）【単票】の作成時にエラーがあった場合
	IF gReturnCode <> pkconstant.success() THEN
		CALL pkLog.error('ECM701', 'SPIPX046K15R02', 'エラーコード'||gReturnCode);
		CALL pkLog.error('ECM701', 'SPIPX046K15R02', 'エラー内容'||gOutSqlErrM);
		RETURN gReturnCode;
	END IF;
	-- 作票が終了したためワークに挿入したデータをDELETE
	DELETE FROM SREPORT_WK
	WHERE CHOHYO_ID = wkChohyoId;
	RETURN pkconstant.success();
--=========< エラー処理 >==========================================================
 EXCEPTION
	WHEN OTHERS THEN
	--カーソルが開いていたら閉じておく
		BEGIN
			CLOSE gCur;
		EXCEPTION
			WHEN INVALID_CURSOR_STATE THEN
				NULL; -- Cursor already closed
			WHEN OTHERS THEN
				NULL; -- Ignore cursor close errors
		END;
		CALL pkLog.fatal('ECM701', 'SFIPX046K15R01_01', 'エラーコード'||SQLSTATE);
		CALL pkLog.fatal('ECM701', 'SFIPX046K15R01_01', 'エラー内容'||SQLERRM);
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipx046k15r01_01 ( l_initakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE ) FROM PUBLIC;



DROP TYPE IF EXISTS sfipx046k15r01_01_inskknido_type_record;
CREATE TYPE sfipx046k15r01_01_inskknido_type_record AS (
    ITAKU_KAISHA_CD char(4), -- 委託会社コード
    MGR_CD          varchar(13), -- 銘柄コード
    KJT             char(8), -- 期日
    CHOKYU_YMD      char(8) -- 徴求日
    );


CREATE OR REPLACE FUNCTION sfipx046k15r01_01_inskknido (l_inUserId KIKIN_IDO.SAKUSEI_ID%TYPE, l_inKjnFYmd text, l_inKjnTYmd text, l_inItakuKaishaCd MGR_KIHON.ITAKU_KAISHA_CD%TYPE, l_inHktCd MGR_KIHON.HKT_CD%TYPE, l_inKozaTenCd MHAKKOTAI.KOZA_TEN_CD%TYPE, l_inKozaTenCifcd MHAKKOTAI.KOZA_TEN_CIFCD%TYPE, l_inMgrCd MGR_KIHON.MGR_CD%TYPE, l_inIsinCd MGR_KIHON.ISIN_CD%TYPE, l_inChohyoId SREPORT_WK.CHOHYO_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_inDataSakuseiKbn KIKIN_IDO.DATA_SAKUSEI_KBN%TYPE, l_inKknZndkKjnYmdKbn text, l_outErrMessage OUT text, OUT extra_param integer) RETURNS record AS $body$
DECLARE

  --==============================================================================
  --                  定数定義                                                    
  --==============================================================================
    C_FUNCTION_ID CONSTANT varchar(50) := 'insKknIdo'; -- ファンクション名
    C_PRAM_ERR    CONSTANT integer := 1; -- パラメータエラー
  --==============================================================================
  --                  タイプ                                                      
  --==============================================================================
 -- データ取得用タイプ
    recKknIdo sfipx046k15r01_01_inskknido_type_record;
  --==============================================================================
  --                  変数定義                                                    
  --==============================================================================
    v_item type_sreport_wk_item;                      -- Composite type for pkPrint.insertData
    pCursor REFCURSOR; -- カーソル
    pGyomuYmd         SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE; -- 業務日付
    pYokuGyomuYmd     SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE; -- 業務日付・翌営業日
    pYokuyokuGyomuYmd SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE; -- 業務日付・翌々営業日
    pSeqNo            SREPORT_WK.SEQ_NO%TYPE;

BEGIN
  -- ユーザーＩＤ・パラメータチェック
  IF coalesce(trim(both l_inUserId)::text, '') = '' THEN
    l_outErrMessage := 'ユーザーＩＤ';
    CALL pkLog.warn('WCM012', C_FUNCTION_ID, l_outErrMessage);
    extra_param := C_PRAM_ERR;
    RETURN;
  END IF;
  -- 基準日（From）・パラメータチェック
  IF coalesce(trim(both l_inKjnFYmd)::text, '') = '' THEN
    l_outErrMessage := '基準日（From）';
    CALL pkLog.warn('WCM012', C_FUNCTION_ID, l_outErrMessage);
    extra_param := C_PRAM_ERR;
    RETURN;
  END IF;
  -- 基準日（To）・パラメータチェック
  IF coalesce(trim(both l_inKjnTYmd)::text, '') = '' THEN
    l_outErrMessage := '基準日（To）';
    CALL pkLog.warn('WCM012', C_FUNCTION_ID, l_outErrMessage);
    extra_param := C_PRAM_ERR;
    RETURN;
  END IF;
  -- 委託会社コード・パラメータチェック
  IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' THEN
    l_outErrMessage := '委託会社コード';
    CALL pkLog.warn('WCM012', C_FUNCTION_ID, l_outErrMessage);
    extra_param := C_PRAM_ERR;
    RETURN;
  END IF;
  -- 帳票ＩＤ・パラメータチェック
  IF coalesce(trim(both l_inChohyoId)::text, '') = '' THEN
    l_outErrMessage := '帳票ＩＤ';
    CALL pkLog.warn('WCM012', C_FUNCTION_ID, l_outErrMessage);
    extra_param := C_PRAM_ERR;
    RETURN;
  END IF;
  -- リアル・バッチ区分・パラメータチェック
  IF coalesce(trim(both l_inChohyoKbn)::text, '') = '' THEN
    l_outErrMessage := 'リアル・バッチ区分';
    CALL pkLog.warn('WCM012', C_FUNCTION_ID, l_outErrMessage);
    extra_param := C_PRAM_ERR;
    RETURN;
  END IF;
  IF l_inChohyoKbn NOT IN ('0', '1') THEN
    l_outErrMessage := 'リアル・バッチ区分';
    CALL pkLog.warn('WCM013', C_FUNCTION_ID, l_outErrMessage);
    extra_param := C_PRAM_ERR;
    RETURN;
  END IF;
  -- データ作成区分・パラメータチェック
  IF coalesce(trim(both l_inDataSakuseiKbn)::text, '') = '' THEN
    l_outErrMessage := 'データ作成区分';
    CALL pkLog.warn('WCM012', C_FUNCTION_ID, l_outErrMessage);
    extra_param := C_PRAM_ERR;
    RETURN;
  END IF;
  IF l_inDataSakuseiKbn NOT IN ('0', '1') THEN
    l_outErrMessage := 'データ作成区分';
    CALL pkLog.warn('WCM013', C_FUNCTION_ID, l_outErrMessage);
    extra_param := C_PRAM_ERR;
    RETURN;
  END IF;
  -- 業務日付取得
  pGyomuYmd := pkDate.getGyomuYmd();
  -- 業務日付・翌営業日取得
  pYokuGyomuYmd := pkDate.getPlusDateBusiness(pGyomuYmd, 1);
  -- 業務日付・翌々営業日取得
  pYokuyokuGyomuYmd := pkDate.getPlusDateBusiness(pGyomuYmd, 2);
  -- リアル・バッチ区分 = 「'1'：バッチ」の時
  IF l_inChohyoKbn = '1' THEN
    -- 帳票ワークの最大連番取得
    SELECT coalesce(MAX(SC16.SEQ_NO), 0)
      INTO STRICT pSeqNo
      FROM SREPORT_WK SC16
     WHERE SC16.KEY_CD = l_inItakuKaishaCd
       AND SC16.CHOHYO_ID = 'WK' || SUBSTR(l_inChohyoId, 3, 9);
  END IF;
  -- カーソルオープン
  -- Inlined from sfipx046k15r01_01_inskknido_opencursor
  OPEN pCursor FOR
        SELECT T.ITAKU_KAISHA_CD, T.MGR_CD, T.KJT, T.CHOKYU_YMD
          FROM (SELECT  -- 利金（基金請求書出力日がシステム設定）
                 MG2.ITAKU_KAISHA_CD,
                 MG2.MGR_CD,
                 MG2.RBR_KJT AS KJT,
                 MG2.KKN_CHOKYU_YMD AS CHOKYU_YMD
                  FROM MGR_RBRKIJ MG2, MGR_KIHON_VIEW VMG1
                 WHERE MG2.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
                   AND MG2.MGR_CD = VMG1.MGR_CD
                   AND MG2.ITAKU_KAISHA_CD = l_inItakuKaishaCd
                   AND MG2.RBR_KJT BETWEEN l_inKjnFYmd AND l_inKjnTYmd
                   AND (trim(both MG2.KKN_CHOKYU_YMD) IS NOT NULL AND (trim(both MG2.KKN_CHOKYU_YMD))::text <> '')
                   AND coalesce(trim(both MG2.KKNBILL_OUT_YMD)::text, '') = ''
                   AND VMG1.JTK_KBN != '2'
                   AND VMG1.JTK_KBN != '5'
                   AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
                   AND VMG1.MGR_STAT_KBN = '1'
                   AND VMG1.KK_KANYO_FLG = '2'
                
UNION

                SELECT  -- 利金（基金請求書出力日が個別設定）
                 MG2.ITAKU_KAISHA_CD,
                 MG2.MGR_CD,
                 MG2.RBR_KJT AS KJT,
                 MG2.KKN_CHOKYU_YMD AS CHOKYU_YMD
                  FROM MGR_RBRKIJ MG2, MGR_KIHON_VIEW VMG1, MGR_TESKIJ MT1
                 WHERE MG2.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
                   AND MG2.MGR_CD = VMG1.MGR_CD
                   AND MT1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
                   AND MT1.MGR_CD = MG2.MGR_CD
                   AND MT1.CHOKYU_KJT = MG2.RBR_KJT
                   AND MG2.ITAKU_KAISHA_CD = l_inItakuKaishaCd
                   AND MG2.RBR_KJT BETWEEN l_inKjnFYmd AND l_inKjnTYmd
                   AND (trim(both MG2.KKN_CHOKYU_YMD) IS NOT NULL AND (trim(both MG2.KKN_CHOKYU_YMD))::text <> '')
                   AND coalesce(trim(both MG2.KKNBILL_OUT_YMD)::text, '') = ''
                   AND VMG1.JTK_KBN != '2'
                   AND VMG1.JTK_KBN != '5'
                   AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
                   AND VMG1.MGR_STAT_KBN = '1'
                   AND VMG1.KK_KANYO_FLG = '2'
                
UNION

                SELECT  -- 元金（基金請求書出力日がシステム設定）
                 MG3.ITAKU_KAISHA_CD,
                 MG3.MGR_CD,
                 MG3.SHOKAN_KJT AS KJT,
                 MG3.GNKIN_CHOKYU_YMD AS CHOKYU_YMD
                  FROM MGR_SKANKIJ MG3, MGR_KIHON_VIEW VMG2
                 WHERE MG3.ITAKU_KAISHA_CD = VMG2.ITAKU_KAISHA_CD
                   AND MG3.MGR_CD = VMG2.MGR_CD
                   AND MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd
                   AND MG3.SHOKAN_KJT BETWEEN l_inKjnFYmd AND l_inKjnTYmd
                   AND (trim(both MG3.GNKIN_CHOKYU_YMD) IS NOT NULL AND (trim(both MG3.GNKIN_CHOKYU_YMD))::text <> '')
                   AND coalesce(trim(both MG3.GKBILL_OUT_YMD)::text, '') = ''
                   AND VMG2.JTK_KBN != '2'
                   AND VMG2.JTK_KBN != '5'
                   AND (trim(both VMG2.ISIN_CD) IS NOT NULL AND (trim(both VMG2.ISIN_CD))::text <> '')
                   AND VMG2.MGR_STAT_KBN = '1'
                   AND VMG2.KK_KANYO_FLG = '2'
                
UNION

                SELECT  -- 元金（基金請求書出力日が個別設定）
                 MG3.ITAKU_KAISHA_CD,
                 MG3.MGR_CD,
                 MG3.SHOKAN_KJT AS KJT,
                 MG3.GNKIN_CHOKYU_YMD AS CHOKYU_YMD
                  FROM MGR_SKANKIJ MG3, MGR_KIHON_VIEW VMG2, MGR_TESKIJ MT2
                 WHERE MG3.ITAKU_KAISHA_CD = VMG2.ITAKU_KAISHA_CD
                   AND MG3.MGR_CD = VMG2.MGR_CD
                   AND MT2.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
                   AND MT2.MGR_CD = MG3.MGR_CD
                   AND MT2.CHOKYU_KJT = MG3.SHOKAN_KJT
                   AND MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd
                   AND MG3.SHOKAN_KJT BETWEEN l_inKjnFYmd AND l_inKjnTYmd
                   AND (trim(both MG3.GNKIN_CHOKYU_YMD) IS NOT NULL AND (trim(both MG3.GNKIN_CHOKYU_YMD))::text <> '')
                   AND coalesce(trim(both MG3.GKBILL_OUT_YMD)::text, '') = ''
                   AND VMG2.JTK_KBN != '2'
                   AND VMG2.JTK_KBN != '5'
                   AND (trim(both VMG2.ISIN_CD) IS NOT NULL AND (trim(both VMG2.ISIN_CD))::text <> '')
                   AND VMG2.MGR_STAT_KBN = '1'
                   AND VMG2.KK_KANYO_FLG = '2') T
         ORDER BY T.ITAKU_KAISHA_CD, T.MGR_CD, T.KJT;
  -- ループ処理
  LOOP
    FETCH pCursor
      INTO recKknIdo;
    EXIT WHEN NOT FOUND;/* apply on pCursor */
    -- リアル・バッチ区分 = 「'1'：バッチ」の時
    IF l_inChohyoKbn = '1' THEN
      -- カウントアップ
      pSeqNo := pSeqNo + 1;
      -- 帳票ワーク登録
      		-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := recKknIdo.MGR_CD;	-- アイテム１
		v_item.l_inItem002 := recKknIdo.KJT;	-- アイテム２
		v_item.l_inItem003 := recKknIdo.CHOKYU_YMD;	-- アイテム３
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> pGyomuYmd,
			l_inChohyoId	=> 'WK' || SUBSTR(l_inChohyoId, 3, 9),
			l_inSeqNo		=> pSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
    END IF;
  END LOOP;
  CLOSE pCursor;
  -- リターン
  extra_param := pkconstant.success();
  RETURN;
  -- エラー処理
  EXCEPTION
    WHEN OTHERS THEN
      CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'SQLCODE:' || SQLSTATE);
      CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'SQLERRM:' || SQLERRM);
      l_outErrMessage := SQLSTATE || SQLERRM;
      extra_param := pkconstant.fatal();
      RETURN;
  END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipx046k15r01_01_inskknido (l_inUserId KIKIN_IDO.SAKUSEI_ID%TYPE, l_inKjnFYmd text, l_inKjnTYmd text, l_inItakuKaishaCd MGR_KIHON.ITAKU_KAISHA_CD%TYPE, l_inHktCd MGR_KIHON.HKT_CD%TYPE, l_inKozaTenCd MHAKKOTAI.KOZA_TEN_CD%TYPE, l_inKozaTenCifcd MHAKKOTAI.KOZA_TEN_CIFCD%TYPE, l_inMgrCd MGR_KIHON.MGR_CD%TYPE, l_inIsinCd MGR_KIHON.ISIN_CD%TYPE, l_inChohyoId SREPORT_WK.CHOHYO_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_inDataSakuseiKbn KIKIN_IDO.DATA_SAKUSEI_KBN%TYPE, l_inKknZndkKjnYmdKbn text, l_outErrMessage OUT text, OUT extra_param integer) FROM PUBLIC;



-- Note: sfipx046k15r01_01_inskknido_opencursor procedure has been inlined into parent function
-- because PostgreSQL doesn't support nested procedures accessing parent variables

/*
CREATE OR REPLACE PROCEDURE sfipx046k15r01_01_inskknido_opencursor () AS $body$
BEGIN
      OPEN pCursor FOR
        SELECT T.ITAKU_KAISHA_CD, T.MGR_CD, T.KJT, T.CHOKYU_YMD
          FROM (SELECT  -- 利金（基金請求書出力日がシステム設定）
                 MG2.ITAKU_KAISHA_CD,
                 MG2.MGR_CD,
                 MG2.RBR_KJT AS KJT,
                 MG2.KKN_CHOKYU_YMD AS CHOKYU_YMD
                  FROM MGR_RBRKIJ MG2, MGR_KIHON_VIEW VMG1
                 WHERE MG2.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
                   AND MG2.MGR_CD = VMG1.MGR_CD
                   AND MG2.ITAKU_KAISHA_CD = l_inItakuKaishaCd
                   AND MG2.RBR_KJT BETWEEN l_inKjnFYmd AND l_inKjnTYmd
                   AND (trim(both MG2.KKN_CHOKYU_YMD) IS NOT NULL AND (trim(both MG2.KKN_CHOKYU_YMD))::text <> '')
                   AND coalesce(trim(both MG2.KKNBILL_OUT_YMD)::text, '') = ''
                   AND VMG1.JTK_KBN != '2'
                   AND VMG1.JTK_KBN != '5'
                   AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
                   AND VMG1.MGR_STAT_KBN = '1'
                   AND VMG1.KK_KANYO_FLG = '2'
                
UNION

                SELECT  -- 利金（基金請求書出力日が個別設定）
                 MG2.ITAKU_KAISHA_CD,
                 MG2.MGR_CD,
                 MG2.RBR_KJT AS KJT,
                 MG2.KKN_CHOKYU_YMD AS CHOKYU_YMD
                  FROM MGR_RBRKIJ MG2, MGR_KIHON_VIEW VMG1
                 WHERE MG2.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
                   AND MG2.MGR_CD = VMG1.MGR_CD
                   AND MG2.ITAKU_KAISHA_CD = l_inItakuKaishaCd
                   AND (trim(both MG2.KKN_CHOKYU_YMD) IS NOT NULL AND (trim(both MG2.KKN_CHOKYU_YMD))::text <> '')
                   AND MG2.KKNBILL_OUT_YMD >= pYokuGyomuYmd
                   AND MG2.KKNBILL_OUT_YMD < pYokuyokuGyomuYmd
                   AND VMG1.JTK_KBN != '2'
                   AND VMG1.JTK_KBN != '5'
                   AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
                   AND VMG1.MGR_STAT_KBN = '1'
                   AND VMG1.KK_KANYO_FLG = '2' 
                
UNION

                SELECT  -- 利金支払手数料（手数料請求書出力日がシステム設定）
                 MG2.ITAKU_KAISHA_CD,
                 MG2.MGR_CD,
                 MG2.RBR_KJT AS KJT,
                 MG2.TESU_CHOKYU_YMD AS CHOKYU_YMD
                  FROM MGR_RBRKIJ      MG2,
                       MGR_KIHON_VIEW  VMG1,
                       MGR_TESURYO_CTL MG7,
                       MGR_TESURYO_PRM MG8
                 WHERE MG2.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
                   AND MG2.MGR_CD = VMG1.MGR_CD
                   AND MG2.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD
                   AND MG2.MGR_CD = MG7.MGR_CD
                   AND MG2.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD
                   AND MG2.MGR_CD = MG8.MGR_CD
                   AND MG2.ITAKU_KAISHA_CD = l_inItakuKaishaCd
                   AND MG2.RBR_KJT BETWEEN l_inKjnFYmd AND l_inKjnTYmd
                   AND (trim(both MG2.TESU_CHOKYU_YMD) IS NOT NULL AND (trim(both MG2.TESU_CHOKYU_YMD))::text <> '')
                   AND coalesce(trim(both MG2.TESUBILL_OUT_YMD)::text, '') = ''
                   AND MG7.TESU_SHURUI_CD IN ('61', '82')
                   AND MG7.CHOOSE_FLG = '1'
                   AND MG8.RKN_SHR_TESU_BUNBO > 0
                   AND VMG1.JTK_KBN != '2'
                   AND VMG1.JTK_KBN != '5'
                   AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
                   AND VMG1.MGR_STAT_KBN = '1'
                   AND VMG1.KK_KANYO_FLG = '2' 
                
UNION

                SELECT  -- 利金支払手数料（手数料請求書出力日が個別設定）
                 MG2.ITAKU_KAISHA_CD,
                 MG2.MGR_CD,
                 MG2.RBR_KJT AS KJT,
                 MG2.TESU_CHOKYU_YMD AS CHOKYU_YMD
                  FROM MGR_RBRKIJ      MG2,
                       MGR_KIHON_VIEW  VMG1,
                       MGR_TESURYO_CTL MG7,
                       MGR_TESURYO_PRM MG8
                 WHERE MG2.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
                   AND MG2.MGR_CD = VMG1.MGR_CD
                   AND MG2.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD
                   AND MG2.MGR_CD = MG7.MGR_CD
                   AND MG2.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD
                   AND MG2.MGR_CD = MG8.MGR_CD
                   AND MG2.ITAKU_KAISHA_CD = l_inItakuKaishaCd
                   AND (trim(both MG2.TESU_CHOKYU_YMD) IS NOT NULL AND (trim(both MG2.TESU_CHOKYU_YMD))::text <> '')
                   AND MG2.TESUBILL_OUT_YMD >= pYokuGyomuYmd
                   AND MG2.TESUBILL_OUT_YMD < pYokuyokuGyomuYmd
                   AND MG7.TESU_SHURUI_CD IN ('61', '82')
                   AND MG7.CHOOSE_FLG = '1'
                   AND MG8.RKN_SHR_TESU_BUNBO > 0
                   AND VMG1.JTK_KBN != '2'
                   AND VMG1.JTK_KBN != '5'
                   AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
                   AND VMG1.MGR_STAT_KBN = '1'
                   AND VMG1.KK_KANYO_FLG = '2' 
                
UNION

                SELECT  -- 元金（基金請求書出力日がシステム設定）
                 P01.ITAKU_KAISHA_CD,
                 P01.MGR_CD,
                 P01.SHOKAN_KJT AS KJT,
                 P01.KKN_CHOKYU_YMD AS CHOKYU_YMD
                  FROM KBG_SHOKIJ P01, MGR_KIHON_VIEW VMG1
                 WHERE P01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
                   AND P01.MGR_CD = VMG1.MGR_CD
                   AND P01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
                   AND P01.SHOKAN_KJT BETWEEN l_inKjnFYmd AND l_inKjnTYmd
                   AND P01.KBG_SHOKAN_KBN != '62'
                   AND P01.KBG_SHOKAN_KBN != '63'
                   AND (trim(both P01.KKN_CHOKYU_YMD) IS NOT NULL AND (trim(both P01.KKN_CHOKYU_YMD))::text <> '')
                   AND coalesce(trim(both P01.KKNBILL_OUT_YMD)::text, '') = ''
                   AND VMG1.JTK_KBN != '2'
                   AND VMG1.JTK_KBN != '5'
                   AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
                   AND VMG1.MGR_STAT_KBN = '1'
                   AND VMG1.KK_KANYO_FLG = '2' 
                
UNION

                SELECT  -- 元金（基金請求書出力日が個別設定）
                 P01.ITAKU_KAISHA_CD,
                 P01.MGR_CD,
                 P01.SHOKAN_KJT AS KJT,
                 P01.KKN_CHOKYU_YMD AS CHOKYU_YMD
                  FROM KBG_SHOKIJ P01, MGR_KIHON_VIEW VMG1
                 WHERE P01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
                   AND P01.MGR_CD = VMG1.MGR_CD
                   AND P01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
                   AND P01.KBG_SHOKAN_KBN != '62'
                   AND P01.KBG_SHOKAN_KBN != '63'
                   AND (trim(both P01.KKN_CHOKYU_YMD) IS NOT NULL AND (trim(both P01.KKN_CHOKYU_YMD))::text <> '')
                   AND P01.KKNBILL_OUT_YMD >= pYokuGyomuYmd
                   AND P01.KKNBILL_OUT_YMD < pYokuyokuGyomuYmd
                   AND VMG1.JTK_KBN != '2'
                   AND VMG1.JTK_KBN != '5'
                   AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
                   AND VMG1.MGR_STAT_KBN = '1'
                   AND VMG1.KK_KANYO_FLG = '2' 
                
UNION

                SELECT  -- 元金支払手数料（手数料請求書出力日がシステム設定）
                 P01.ITAKU_KAISHA_CD,
                 P01.MGR_CD,
                 P01.SHOKAN_KJT AS KJT,
                 P01.TESU_CHOKYU_YMD AS CHOKYU_YMD
                  FROM KBG_SHOKIJ      P01,
                       MGR_KIHON_VIEW  VMG1,
                       MGR_TESURYO_CTL MG7,
                       MGR_TESURYO_PRM MG8
                 WHERE P01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
                   AND P01.MGR_CD = VMG1.MGR_CD
                   AND P01.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD
                   AND P01.MGR_CD = MG7.MGR_CD
                   AND P01.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD
                   AND P01.MGR_CD = MG8.MGR_CD
                   AND P01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
                   AND P01.SHOKAN_KJT BETWEEN l_inKjnFYmd AND l_inKjnTYmd
                   AND P01.KBG_SHOKAN_KBN != '62'
                   AND P01.KBG_SHOKAN_KBN != '63'
                   AND (trim(both P01.TESU_CHOKYU_YMD) IS NOT NULL AND (trim(both P01.TESU_CHOKYU_YMD))::text <> '')
                   AND coalesce(trim(both P01.TESUBILL_OUT_YMD)::text, '') = ''
                   AND MG7.TESU_SHURUI_CD = '81'
                   AND MG7.CHOOSE_FLG = '1'
                   AND MG8.GNKN_SHR_TESU_BUNBO > 0
                   AND VMG1.JTK_KBN != '2'
                   AND VMG1.JTK_KBN != '5'
                   AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
                   AND VMG1.MGR_STAT_KBN = '1'
                   AND VMG1.KK_KANYO_FLG = '2' 
                
UNION

                SELECT  -- 元金支払手数料（手数料請求書出力日が個別設定）
                 P01.ITAKU_KAISHA_CD,
                 P01.MGR_CD,
                 P01.SHOKAN_KJT AS KJT,
                 P01.TESU_CHOKYU_YMD AS CHOKYU_YMD
                  FROM KBG_SHOKIJ      P01,
                       MGR_KIHON_VIEW  VMG1,
                       MGR_TESURYO_CTL MG7,
                       MGR_TESURYO_PRM MG8
                 WHERE P01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
                   AND P01.MGR_CD = VMG1.MGR_CD
                   AND P01.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD
                   AND P01.MGR_CD = MG7.MGR_CD
                   AND P01.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD
                   AND P01.MGR_CD = MG8.MGR_CD
                   AND P01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
                   AND P01.KBG_SHOKAN_KBN != '62'
                   AND P01.KBG_SHOKAN_KBN != '63'
                   AND (trim(both P01.TESU_CHOKYU_YMD) IS NOT NULL AND (trim(both P01.TESU_CHOKYU_YMD))::text <> '')
                   AND P01.TESUBILL_OUT_YMD >= pYokuGyomuYmd
                   AND P01.TESUBILL_OUT_YMD < pYokuyokuGyomuYmd
                   AND MG7.TESU_SHURUI_CD = '81'
                   AND MG7.CHOOSE_FLG = '1'
                   AND MG8.GNKN_SHR_TESU_BUNBO > 0
                   AND VMG1.JTK_KBN != '2'
                   AND VMG1.JTK_KBN != '5'
                   AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
                   AND VMG1.MGR_STAT_KBN = '1'
                   AND VMG1.KK_KANYO_FLG = '2' ) T,
               MGR_KIHON MG1,
               MHAKKOTAI M01
         WHERE T.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
           AND T.MGR_CD = MG1.MGR_CD
           AND MG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
           AND MG1.HKT_CD = M01.HKT_CD
           AND (coalesce(l_inMgrCd::text, '') = '' OR MG1.MGR_CD = l_inMgrCd)
           AND (coalesce(l_inIsinCd::text, '') = '' OR MG1.ISIN_CD = l_inIsinCd)
           AND (coalesce(l_inHktCd::text, '') = '' OR MG1.HKT_CD = l_inHktCd)
           AND (coalesce(l_inKozaTenCd::text, '') = '' OR M01.KOZA_TEN_CD = l_inKozaTenCd)
           AND (coalesce(l_inKozaTenCifcd::text, '') = '' OR
               M01.KOZA_TEN_CIFCD = l_inKozaTenCifcd) 
         ORDER BY T.ITAKU_KAISHA_CD, T.MGR_CD, T.KJT, T.CHOKYU_YMD;
  END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfipx046k15r01_01_inskknido_opencursor () FROM PUBLIC;
*/