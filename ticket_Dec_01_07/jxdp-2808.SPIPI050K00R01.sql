


DROP TYPE IF EXISTS spipi050k00r01_type_record;
CREATE TYPE spipi050k00r01_type_record AS (
	gHktCd         char(6), -- 発行体コード
	gSfskPostNo    char(7), -- 送付先郵便番号
	gAdd1          varchar(50), -- 送付先住所１
	gAdd2          varchar(50), -- 送付先住所２
	gAdd3          varchar(50), -- 送付先住所３
	gHktNm         varchar(100), -- 発行体名称
	gSfskBushoNm   varchar(50), -- 送付先担当部署名称
	gBankNm        varchar(50),  -- 銀行名称
	gBushoNm1      varchar(50),  -- 担当部署名称１
	gTsukaNm       char(3), -- 通貨名称
	gIsinCd        char(12), -- ISINコード
	gKokyakuMgrRnm varchar(52), -- 対顧用銘柄略称
	gPreMnthZndk   decimal(16,2), -- 前月末残高	
	gNknKknKngk    decimal(16,2), -- 当月入金高_基金受入高
	gNknOtherKngk  decimal(16,2), -- 当月入金高_その他		
	gSknGnrKngk    decimal(16,2), -- 当月出金高_元利金支払高
	gSknTsrKngk    decimal(16,2), -- 当月出金高_同手数料
	gSknKzKngk     decimal(16,2), -- 当月出金高_国税
	gSknKknKngk    decimal(16,2), -- 当月出金高_基金返戻金
	gSknOtherKngk  decimal(16,2), -- 当月出金高_その他
	gTsukaCd       char(3),        -- 通貨コード
	gMgrCd         varchar(13),          -- 銘柄コード
	gKozaTenCd    char(4),     -- 口座店コード
	gKozaTenCifcd char(11)  -- 口座店ＣＩＦコード
	);


CREATE OR REPLACE PROCEDURE spipi050k00r01 (
	l_inItakuKaishaCd TEXT, -- 委託会社コード
 l_inUserId TEXT, -- ユーザーID
 l_inChohyoKbn TEXT, -- 帳票区分
 l_inGyomuYmd TEXT, -- 業務日付　←夜間はここまで
 l_inHktCd TEXT, -- 発行体コード
 l_inKozaTenCd TEXT, -- 口座店コード
 l_inKozaTenCifCd TEXT, -- 口座店CIFコード
 l_inMgrCd TEXT, -- 銘柄コード
 l_inIsinCd TEXT, -- ISINコード
 l_inKijunYm TEXT, -- 基準年月
 l_inTsuchiYmd TEXT, -- 通知日
 l_outSqlCode OUT integer, -- リターン値
 l_outSqlErrM OUT text -- エラーコメント
 ) AS $body$
DECLARE

	--
--	/* 著作権:Copyright(c)2004
--	/* 会社名:JIP
--	/* 概要　:画面から、元利払基金残高報告書を作成する。
--	/* 引数　:l_inItakuKaishaCd    IN  TEXT      委託会社コード
--	/*        l_inUserId           IN  TEXT      ユーザーID
--	/* 　　　 l_inChohyoKbn        IN  TEXT      帳票区分
--	/* 　　　 l_inGyomuYmd         IN  TEXT      業務日付
--	/* 　　　 l_inHktCd            IN  TEXT      発行体コード
--	/* 　　　 l_inKozaTenCd        IN  TEXT      口座店コード
--	/* 　　　 l_inKozaTenCifCd     IN  TEXT      口座店CIFコード
--	/* 　　　 l_inMgrCd            IN  TEXT      銘柄コード
--	/* 　　　 l_inIsin             IN  TEXT      ISINコード
--	/* 　　　 l_inKijunYm          IN  TEXT      基準年月
--	/* 　　　 l_inTsuchiYmd        IN  TEXT      通知日
--	/* 　　　 l_outSqlCode         OUT INTEGER   リターン値
--	/* 　　　 l_outSqlErrM         OUT VARCHAR  エラーコメント
--	/* 返り値:なし
--	/* @version $Id: SPIPI050K00R01.sql,v 1.15 2008/10/31 02:03:04 morita Exp $
--
--	/*==============================================================================
	--                デバッグ機能                                                   
	--==============================================================================
	DEBUG numeric(1) := 0;
	--==============================================================================
	--                定数定義                                                      
	--==============================================================================
	RTN_OK     CONSTANT integer := 0; -- 正常
	RTN_NG     CONSTANT integer := 1; -- 予期したエラー
	RTN_NODATA CONSTANT integer := 2; -- データなし
	RTN_FATAL  CONSTANT integer := 99; -- 予期せぬエラー
	REPORT_ID      CONSTANT char(11) := 'IP030005011'; -- 元利払基金残高報告書帳票ID
	PROGRAM_ID     CONSTANT varchar(14) := 'SPIPI050K00R01'; -- プログラムID
	TSUCHI_YMD_DEF CONSTANT char(16) := '      年  月  日'; -- 平成10年10月10日
	--==============================================================================
	--                変数定義                                                      
	--==============================================================================
	gRtnCd integer := RTN_OK; -- リターンコード
	gSeqNo integer := 0; -- シーケンス
	gSQL   varchar(12800) := NULL; -- SQL編集
	-- 書式フォーマット
	gGyomuYm      char(6) := NULL; -- 業務年月(リアルと夜間で変わる)
	gWrkTsuchiYmd varchar(16) := NULL; -- 通知日(西暦)
	gAtena        varchar(200) := NULL; -- 宛名
	gOutflg       numeric := 0; -- 正常処理フラグ
	gWrkToriYm    varchar(14) := NULL; -- 取扱年月
	gBunsho       varchar(200) := NULL; -- 請求文章
	gMnthZndk     decimal(16,2) := 0; -- 当月末残高
	-- DB取得項目
	-- 配列定義
	recMeisai SPIPI050K00R01_TYPE_RECORD; -- レコード
	gChohyoSortFlg TEXT; -- 発行体宛帳票ソート順変更フラグ
	-- カーソル
	curMeisai REFCURSOR;
	gRedOptionFlg TEXT;
	v_item TYPE_SREPORT_WK_ITEM;
	--==============================================================================
	--                メイン処理                                                       
	--==============================================================================
BEGIN
  IF DEBUG = 1 THEN
    CALL pkLog.debug(l_inUserId, REPORT_ID, PROGRAM_ID || ' START');
    CALL pkLog.debug(l_inUserId,
                REPORT_ID,
                '-------------------- 引数一覧　開始-----------------');
    CALL pkLog.debug(l_inUserId,
                REPORT_ID,
                'l_inItakuKaishaCd = ' || l_inItakuKaishaCd);
    CALL pkLog.debug(l_inUserId, REPORT_ID, 'l_inUserId = ' || l_inUserId);
    CALL pkLog.debug(l_inUserId, REPORT_ID, 'l_inChohyoKbn = ' || l_inChohyoKbn);
    CALL pkLog.debug(l_inUserId, REPORT_ID, 'l_inGyomuYmd = ' || l_inGyomuYmd);
    CALL pkLog.debug(l_inUserId, REPORT_ID, 'l_inHktCd = ' || l_inHktCd);
    CALL pkLog.debug(l_inUserId, REPORT_ID, 'l_inKozaTenCd = ' || l_inKozaTenCd);
    CALL pkLog.debug(l_inUserId,
                REPORT_ID,
                'l_inKozaTenCifCd = ' || l_inKozaTenCifCd);
    CALL pkLog.debug(l_inUserId, REPORT_ID, 'l_inMgrCd = ' || l_inMgrCd);
    CALL pkLog.debug(l_inUserId, REPORT_ID, 'l_inIsinCd = ' || l_inIsinCd);
    CALL pkLog.debug(l_inUserId, REPORT_ID, 'l_inKijunYm = ' || l_inKijunYm);
    CALL pkLog.debug(l_inUserId, REPORT_ID, 'l_inTsuchiYmd = ' || l_inTsuchiYmd);
    CALL pkLog.debug(l_inUserId,
                REPORT_ID,
                '-------------------- 引数一覧　終了-----------------');
  END IF;
  -- 入力パラメータのチェック
  IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' OR coalesce(trim(both l_inUserId)::text, '') = '' OR
     coalesce(trim(both l_inChohyoKbn)::text, '') = '' OR coalesce(trim(both l_inGyomuYmd)::text, '') = '' OR (l_inChohyoKbn = '0' AND coalesce(trim(both l_inKijunYm)::text, '') = '') THEN
    -- パラメータエラー
    IF DEBUG = 1 THEN
      CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');
    END IF;
    l_outSqlCode := RTN_NG;
    l_outSqlErrM := '';
    CALL pkLog.error('ECM501', REPORT_ID, 'SQLERRM:' || '');
    RETURN;
  END IF;
  -- 帳票区分による初期設定
  IF l_inChohyoKbn = '0' THEN
    -- リアル
    -- 業務年月
    gGyomuYm := l_inKijunYm;
    -- 通知日(西暦)
    IF (trim(both l_inTsuchiYmd) IS NOT NULL AND (trim(both l_inTsuchiYmd))::text <> '') THEN
      gWrkTsuchiYmd := pkDate.seirekiChangeSuppressNenGappi(l_inTsuchiYmd);
    ELSE
      gWrkTsuchiYmd := TSUCHI_YMD_DEF;
    END IF;
    -- 2006/04/27　NOA 取扱年月セット箇所追加
    -- 取扱年月取得
    gWrkToriYm := substr(pkDate.seirekiChangeSuppressNenGappi(l_inKijunYm || '01'),
                          1,
                          10);
    gWrkToriYm := gWrkToriYm || '分';
  ELSE
    -- 夜間
    -- 業務年月
    gGyomuYm := substr(l_inGyomuYmd, 1, 6);
    -- 通知日(翌営業日西暦)
    gWrkTsuchiYmd := pkDate.getYokuBusinessYmd(l_inGyomuYmd);
    gWrkTsuchiYmd := pkDate.seirekiChangeSuppressNenGappi(gWrkTsuchiYmd);
    -- 2006/04/27　NOA 取扱年月セット箇所追加
    -- 取扱年月取得
    gWrkToriYm := substr(pkDate.seirekiChangeSuppressNenGappi(l_inGyomuYmd),
                          1,
                          10);
    gWrkToriYm := gWrkToriYm || '分';
  END IF;
  -- 請求文章取得
  gBunsho := SPIPI050K00R01_createBun(REPORT_ID, '00');
  -- 取得データログ
  IF DEBUG = 1 THEN
    CALL pkLog.debug(l_inUserId, REPORT_ID, '業務年月 = ' || gGyomuYm);
    CALL pkLog.debug(l_inUserId, REPORT_ID, '通知日(西暦) = ' || gWrkTsuchiYmd);
    CALL pkLog.debug(l_inUserId, REPORT_ID, '取扱年月 = ' || gWrkToriYm);
    CALL pkLog.debug(l_inUserId, REPORT_ID, '請求文章 = ' || gBunsho);
  END IF;
  -- 帳票ワークの削除
  IF DEBUG = 1 THEN
    CALL pkLog.debug(l_inUserId, REPORT_ID, 'ワークを削除します');
  END IF;
  DELETE FROM SREPORT_WK
   WHERE KEY_CD = l_inItakuKaishaCd
     AND USER_ID = l_inUserId
     AND CHOHYO_KBN = l_inChohyoKbn
     AND SAKUSEI_YMD = l_inGyomuYmd
     AND CHOHYO_ID = REPORT_ID;
  --発行体宛帳票ソート順変更フラグ取得
  gChohyoSortFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'SeikyusyoSort', '0');
	-- レッドプロジェクトオプションフラグ取得
	gRedOptionFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd, 'REDPROJECT', '0');
  -- SQL編集
  gSQL := SPIPI050K00R01_createSQL(l_inItakuKaishaCd, l_inHktCd, l_inKozaTenCd, l_inKozaTenCifCd, l_inMgrCd, l_inIsinCd, l_inKijunYm, gChohyoSortFlg, gRedOptionFlg, gGyomuYm, l_inChohyoKbn);
  -- ヘッダレコードを追加
  IF DEBUG = 1 THEN
    CALL pkLog.debug(l_inUserId, REPORT_ID, 'ヘッダを作成します');
  END IF;
  CALL pkPrint.insertHeader(l_inItakuKaishaCd,
                       l_inUserId,
                       l_inChohyoKbn,
                       l_inGyomuYmd,
                       REPORT_ID);
  -- カーソルオープン
  IF DEBUG = 1 THEN
    CALL pkLog.debug(l_inUserId, REPORT_ID, '対象データを取得します');
  END IF;
  OPEN curMeisai FOR EXECUTE gSQL;
  -- データ取得
  LOOP
    FETCH curMeisai
      INTO recMeisai.gHktCd, -- 発行体コード
    recMeisai.gSfskPostNo, -- 送付先郵便番号
    recMeisai.gAdd1, -- 送付先住所１
    recMeisai.gAdd2, -- 送付先住所２
    recMeisai.gAdd3, -- 送付先住所３
    recMeisai.gHktNm, -- 発行体名称
    recMeisai.gSfskBushoNm, -- 送付先担当部署名称
    recMeisai.gBankNm, -- 銀行名称
    recMeisai.gBushoNm1, -- 担当部署名称１
    recMeisai.gTsukaNm, -- 通貨名称
    recMeisai.gIsinCd, -- ISINコード
    recMeisai.gKokyakuMgrRnm, -- 対顧用銘柄略称
    recMeisai.gPreMnthZndk, -- 前月末残高
    recMeisai.gNknKknKngk, -- 当月入金高_基金受入高
    recMeisai.gNknOtherKngk, -- 当月入金高_その他
    recMeisai.gSknGnrKngk, -- 当月出金高_元利金支払高
    recMeisai.gSknTsrKngk, -- 当月出金高_同手数料
    recMeisai.gSknKzKngk, -- 当月出金高_国税
    recMeisai.gSknKknKngk, -- 当月出金高_基金返戻金
    recMeisai.gSknOtherKngk, -- 当月出金高_その他
    recMeisai.gTsukaCd, -- 通貨コード
    recMeisai.gMgrCd  -- 銘柄コード
	,recMeisai.gKozaTenCd     -- 口座店コード
	,recMeisai.gKozaTenCifcd  -- 口座店ＣＩＦコード
;
    -- データが無くなったらループを抜ける
    EXIT WHEN NOT FOUND;/* apply on curMeisai */
	-- 宛名編集
	CALL pkIpaName.getMadoFutoAtenaYoko(recMeisai.gHktNm,
								recMeisai.gSfskBushoNm,
								gOutflg,
								gAtena);
	-- 当月末残高計算
	gMnthZndk := recMeisai.gPreMnthZndk +
				(recMeisai.gNknKknKngk + recMeisai.gNknOtherKngk) -
				(recMeisai.gSknGnrKngk + recMeisai.gSknTsrKngk +
				recMeisai.gSknKzKngk + recMeisai.gSknKknKngk +
				recMeisai.gSknOtherKngk);
	-- シーケンスアップ
	gSeqNo := gSeqNo + 1;
	-- 取得データログ
	IF DEBUG = 1 THEN
		CALL pkLog.debug(l_inUserId, REPORT_ID, 'データ' || gSeqNo || '件目');
		CALL pkLog.debug(l_inUserId, REPORT_ID, '銘柄コード = ' || recMeisai.gMgrCd);
	END IF;
	-- 帳票ワークへデータを追加
	v_item.item001 := gWrkTsuchiYmd;  -- 通知日
	v_item.item002 := recMeisai.gHktCd;  -- 発行体コード
	v_item.item003 := recMeisai.gSfskPostNo;  -- 送付先郵便番号
	v_item.item004 := recMeisai.gAdd1;  -- 送付先住所１
	v_item.item005 := recMeisai.gAdd2;  -- 送付先住所２
	v_item.item006 := recMeisai.gAdd3;  -- 送付先住所３
	v_item.item007 := gAtena;  -- 発行体名称１(御中込)
	v_item.item008 := recMeisai.gBankNm;  -- 銀行名称
	v_item.item009 := recMeisai.gBushoNm1;  -- 担当部署名称１
	v_item.item010 := gBunsho;  -- 請求文章
	v_item.item011 := gWrkToriYm;  -- 取扱年月
	v_item.item012 := recMeisai.gTsukaNm;  -- 通貨名称
	v_item.item013 := recMeisai.gIsinCd;  -- ISINコード
	v_item.item014 := recMeisai.gKokyakuMgrRnm;  -- 対顧用銘柄略称
	v_item.item015 := recMeisai.gPreMnthZndk;  -- 前月末残高
	v_item.item016 := gMnthZndk;  -- 当月末残高
	v_item.item017 := recMeisai.gNknKknKngk;  -- 当月入金高_基金受入高
	v_item.item018 := recMeisai.gNknOtherKngk;  -- 当月入金高_その他
	v_item.item019 := recMeisai.gSknGnrKngk;  -- 当月出金高_元利金支払高
	v_item.item020 := recMeisai.gSknTsrKngk;  -- 当月出金高_同手数料
	v_item.item021 := recMeisai.gSknKzKngk;  -- 当月出金高_国税
	v_item.item022 := recMeisai.gSknKknKngk;  -- 当月出金高_基金返戻金
	v_item.item023 := recMeisai.gSknOtherKngk;  -- 当月出金高_その他
	v_item.item024 := recMeisai.gTsukaCd;  -- 通貨コード
	v_item.item026 := recMeisai.gKozaTenCd;  -- 口座店コード
	v_item.item027 := trim(both recMeisai.gKozaTenCifcd);  -- 口座店ＣＩＦコード
	v_item.item028 := gRedOptionFlg;  -- レッドプロジェクトオプションフラグ
	CALL pkPrint.insertData(
		l_inKeyCd      => l_inItakuKaishaCd,
		l_inUserId     => l_inUserId,
		l_inChohyoKbn  => l_inChohyoKbn,
		l_inSakuseiYmd => l_inGyomuYmd,
		l_inChohyoId   => REPORT_ID,
		l_inSeqNo      => gSeqNo,
		l_inHeaderFlg  => '1',
		l_inItem       => v_item,
		l_inKousinId   => l_inUserId,
		l_inSakuseiId  => l_inUserId
	);
  END LOOP;
  CLOSE curMeisai;
  IF DEBUG = 1 THEN
    CALL pkLog.debug(l_inUserId,
                REPORT_ID,
                '　☆合計件数　' || gSeqNo || ' 件登録しました');
  END IF;
  IF gSeqNo = 0 THEN
    IF DEBUG = 1 THEN
      CALL pkLog.debug(l_inUserId,
                  REPORT_ID,
                  '　☆元利払基金残高報告書　対象データなしを出力します');
    END IF;
    -- 対象データなし
    gRtnCd := RTN_NODATA;
    -- 帳票ワークへデータを追加
    v_item := ROW(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL)::TYPE_SREPORT_WK_ITEM;
    v_item.item001 := gWrkTsuchiYmd;  -- 通知日
    v_item.item025 := '対象データなし';  -- 対象データ
    CALL pkPrint.insertData(
        l_inKeyCd      => l_inItakuKaishaCd,
        l_inUserId     => l_inUserId,
        l_inChohyoKbn  => l_inChohyoKbn,
        l_inSakuseiYmd => l_inGyomuYmd,
        l_inChohyoId   => REPORT_ID,
        l_inSeqNo      => 1,
        l_inHeaderFlg  => '1',
        l_inItem       => v_item,
        l_inKousinId   => l_inUserId,
        l_inSakuseiId  => l_inUserId
    );
  END IF;
  -- 終了処理
  l_outSqlCode := gRtnCd;
  l_outSqlErrM := '';
  IF DEBUG = 1 THEN
    CALL pkLog.debug(l_inUserId, REPORT_ID, PROGRAM_ID || ' END');
  END IF;
  -- エラー処理
EXCEPTION
  WHEN OTHERS THEN
    BEGIN
      CLOSE curMeisai;
    EXCEPTION
      WHEN OTHERS THEN NULL;
    END;
    CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLCODE:' || SQLSTATE);
    CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLERRM:' || SQLERRM);
    l_outSqlCode := RTN_FATAL;
    l_outSqlErrM := SQLERRM;
    --    RAISE;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipi050k00r01 (l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_inHktCd TEXT, l_inKozaTenCd TEXT, l_inKozaTenCifCd TEXT, l_inMgrCd TEXT, l_inIsinCd TEXT, l_inKijunYm TEXT, l_inTsuchiYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spipi050k00r01_createbun (l_in_ReportID TEXT, l_in_PatternCd BUN.BUN_PATTERN_CD%TYPE) RETURNS varchar AS $body$
DECLARE

-- 請求文章(ワーク)
aryBun pkIpaBun.BUN_ARRAY;
wkBun  varchar(200) := NULL;
BEGIN
-- 請求文章の取得
aryBun := pkIpaBun.getBun(l_in_ReportID, l_in_PatternCd);
FOR i IN 0 .. coalesce(cardinality(aryBun), 0) - 1 LOOP
	-- 100byteまで全角スペース埋めして、請求文章を連結
	wkBun := wkBun || RPAD(aryBun[i], 100, '　');
END LOOP;
RETURN wkBun;
EXCEPTION
WHEN OTHERS THEN
	RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spipi050k00r01_createbun (l_in_ReportID TEXT, l_in_PatternCd BUN.BUN_PATTERN_CD%TYPE) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spipi050k00r01_createsql (
	l_inItakuKaishaCd TEXT,
	l_inHktCd TEXT,
	l_inKozaTenCd TEXT,
	l_inKozaTenCifCd TEXT,
	l_inMgrCd TEXT,
	l_inIsinCd TEXT,
	l_inKijunYm TEXT,
	gChohyoSortFlg TEXT,
	gRedOptionFlg TEXT,
	gGyomuYm TEXT,
	l_inChohyoKbn TEXT
) RETURNS varchar AS $body$
DECLARE
	gSql varchar(12800) := NULL;
BEGIN
-- 変数を初期化
gSql := '';
-- 変数にSQLクエリ文を代入
gSql := 'SELECT '
		 || '	M01.HKT_CD, '				-- 発行体コード
		 || '	M01.SFSK_POST_NO, '			-- 送付先郵便番号
		 || '	M01.ADD1, '					-- 送付先住所１
		 || '	M01.ADD2, '					-- 送付先住所２
		 || '	M01.ADD3, '					-- 送付先住所３
		 || '	M01.HKT_NM, '				-- 発行体名称
		 || '	M01.SFSK_BUSHO_NM, '		-- 送付先担当部署名称
		 || '	VJ1.BANK_NM, '				-- 金融機関名称
		 || '	VJ1.BUSHO_NM1, '			-- 担当部署名称
		 || '	M64.TSUKA_NM, '				-- 通貨名称
		 || '	VMG1.ISIN_CD, '				-- ISINコード
		 || '	VMG1.KOKYAKU_MGR_RNM, '		-- 対顧用銘柄略称
		 || '	K02.KKN_NYUKIN_KNGK028 - K02.KKN_SHUKIN_KNGK029 - K02.KKN_SHUKIN_KNGK030, '		-- 前月末残高
		 || '	K02.KKN_NYUKIN_KNGK021, '	-- 当月入金高_基金受入高
		 || '	K02.KKN_NYUKIN_KNGK022, '	-- 当月入金高_その他
		 || '	K02.KKN_SHUKIN_KNGK023, '	-- 当月出金高_元利金支払高
		 || '	K02.KKN_SHUKIN_KNGK024, '	-- 当月出金高_同手数料
		 || '	K02.KKN_SHUKIN_KNGK025, '	-- 当月出金高_国税
		 || '	K02.KKN_NYUKIN_KNGK026, '	-- 当月出金高_基金返戻金
		 || '	K02.KKN_NYUKIN_KNGK027, '	-- 当月出金高_その他
		 || '	K02.TSUKA_CD, '				-- 通貨コード
		 || '	K02.MGR_CD '				-- 銘柄コード
		 || '	,M01.KOZA_TEN_CD'           -- 口座店コード
		 || '	,M01.KOZA_TEN_CIFCD '       -- 口座店ＣＩＦコード
		 || ' FROM '
		 || '	('
			 		-- 委託会社・銘柄コード・利払期日・異動年月日・通貨コードの単位で
			 		-- 集約して取得した出力対象となる基金異動明細を
			 		-- 更に委託会社・銘柄コード・通貨コード・異動年月で集約します。
			 		-- これが元利払基金残高報告書の明細行出力単位となります。
			 		-- また、前月末入出金額を同時に取得します。
			 		-- 前月末入出金額取得時、同時に並存銘柄チェックを行い並存銘柄については集計対象外とします。
		 || '		SELECT '
		 || '			K02_T2.ITAKU_KAISHA_CD, '
		 || '			K02_T2.MGR_CD, '
		 || '			K02_T2.TSUKA_CD, '
		 || '			SUBSTR(K02_T2.IDO_YMD, 1, 6), '
		 || '			( '
		 || '				SELECT '
		 || '					COALESCE(SUM(K028.KKN_NYUKIN_KNGK), 0) '
		 || '				FROM '
		 || '					KIKIN_IDO K028, '
		 || '					( '
		 || '						SELECT '
		 || '							K028_2.ITAKU_KAISHA_CD, '
		 || '							K028_2.MGR_CD, '
		 || '							K028_2.RBR_KJT, '
		 || '							K028_2.TSUKA_CD, '
		 || '							TRIM(MAX(K028_2.ZNDK_KIJUN_YMD)) AS ZNDK_KIJUN_YMD '
		 || '						FROM '
		 || '							KIKIN_IDO K028_2'
		 || '						WHERE '
		 || '							K028_2.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' '
		 || '							AND K028_2.KKN_IDO_KBN IN (''11'', ''21'', ''22'') '
		 || '							AND K028_2.DATA_SAKUSEI_KBN >= ''1'' '
		 || '						GROUP BY '
		 || '							K028_2.ITAKU_KAISHA_CD, '
		 || '							K028_2.MGR_CD, '
		 || '							K028_2.RBR_KJT, '
		 || '							K028_2.TSUKA_CD '
		 || '					) K028_1 '
		 || '				WHERE '
		 || '					K028.KKN_IDO_KBN IN (''11'', ''12'', ''13'', ''21'', ''22'', ''23'', ''91'', ''93'', ''95'') '
		 || '					AND SUBSTR(K028.IDO_YMD,1, 6) < ''' || gGyomuYm || ''' '
		 || '					AND K02_T2.ITAKU_KAISHA_CD = K028.ITAKU_KAISHA_CD '
		 || '					AND K02_T2.MGR_CD = K028.MGR_CD '
		 || '					AND K02_T2.TSUKA_CD = K028.TSUKA_CD '
		 || '					AND K028_1.ITAKU_KAISHA_CD = K028.ITAKU_KAISHA_CD '
		 || '					AND K028_1.MGR_CD = K028.MGR_CD '
		 || '					AND K028_1.RBR_KJT = K028.RBR_KJT '
		 || '					AND K028_1.TSUKA_CD = K028.TSUKA_CD '
		 || '					AND PKIPACALCTESURYO.checkHeizonMgr(K028_1.ITAKU_KAISHA_CD, K028_1.MGR_CD, K028_1.ZNDK_KIJUN_YMD, ''1'') = 0 '
		 || '			) AS KKN_NYUKIN_KNGK028, '		-- 前月末入金高
		 || '			( '
		 || '				SELECT '
		 || '					COALESCE(SUM(K029.KKN_SHUKIN_KNGK), 0) '
		 || '				FROM '
		 || '					KIKIN_IDO K029, '
		 || '					( '
		 || '						SELECT '
		 || '							K029_2.ITAKU_KAISHA_CD, '
		 || '							K029_2.MGR_CD, '
		 || '							K029_2.RBR_KJT, '
		 || '							K029_2.TSUKA_CD, '
		 || '							TRIM(MAX(K029_2.ZNDK_KIJUN_YMD)) AS ZNDK_KIJUN_YMD '
		 || '						FROM '
		 || '							KIKIN_IDO K029_2 '
		 || '						WHERE '
		 || '							K029_2.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' '
		 || '							AND K029_2.KKN_IDO_KBN IN (''11'', ''21'', ''22'') '
		 || '							AND K029_2.DATA_SAKUSEI_KBN >= ''1'' '
		 || '						GROUP BY '
		 || '							K029_2.ITAKU_KAISHA_CD, '
		 || '							K029_2.MGR_CD, '
		 || '							K029_2.RBR_KJT, '
		 || '							K029_2.TSUKA_CD '
		 || '					) K029_1'
		 || '				WHERE '
		 || '					K029.KKN_IDO_KBN IN (''31'', ''32'', ''33'', ''41'', ''42'', ''43'', ''51'') '
		 || '					AND SUBSTR(K029.IDO_YMD,1, 6) < ''' || gGyomuYm || ''' '
		 || '					AND K02_T2.ITAKU_KAISHA_CD = K029.ITAKU_KAISHA_CD '
		 || '					AND K02_T2.MGR_CD = K029.MGR_CD '
		 || '					AND K02_T2.TSUKA_CD = K029.TSUKA_CD '
		 || '					AND K029_1.ITAKU_KAISHA_CD = K029.ITAKU_KAISHA_CD '
		 || '					AND K029_1.MGR_CD = K029.MGR_CD '
		 || '					AND K029_1.RBR_KJT = K029.RBR_KJT '
		 || '					AND K029_1.TSUKA_CD = K029.TSUKA_CD '
		 || '					AND PKIPACALCTESURYO.checkHeizonMgr(K029_1.ITAKU_KAISHA_CD, K029_1.MGR_CD, K029_1.ZNDK_KIJUN_YMD, ''1'') = 0 '
		 || '					AND EXISTS '
		 || '					( '
		 || '						SELECT ctid FROM KIKIN_SEIKYU K01 '
		 || '						WHERE (K01.KK_KANYO_UMU_FLG = ''1'' '
		 || '							OR (K01.KK_KANYO_UMU_FLG <> ''1'' AND K01.SHORI_KBN = ''1'')) '
		 || '							AND K029.ITAKU_KAISHA_CD = K01.ITAKU_KAISHA_CD '
		 || '							AND K029.MGR_CD = K01.MGR_CD '
		 || '							AND K029.RBR_YMD = K01.SHR_YMD '
		 || '					) '
		 || '			) AS KKN_SHUKIN_KNGK029, '		-- 前月末出金高
		 || '			( '
		 || '				SELECT '
		 || '					COALESCE(SUM(K030.KKN_SHUKIN_KNGK), 0) '
		 || '				FROM '
		 || '					KIKIN_IDO K030, '
		 || '					( '
		 || '						SELECT '
		 || '							K030_2.ITAKU_KAISHA_CD, '
		 || '							K030_2.MGR_CD, '
		 || '							K030_2.RBR_KJT, '
		 || '							K030_2.TSUKA_CD, '
		 || '							TRIM(MAX(K030_2.ZNDK_KIJUN_YMD)) AS ZNDK_KIJUN_YMD '
		 || '						FROM '
		 || '							KIKIN_IDO K030_2 '
		 || '						WHERE '
		 || '							K030_2.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' '
		 || '							AND K030_2.KKN_IDO_KBN IN (''11'', ''21'', ''22'') '
		 || '							AND K030_2.DATA_SAKUSEI_KBN >= ''1'' '
		 || '						GROUP BY '
		 || '							K030_2.ITAKU_KAISHA_CD, '
		 || '							K030_2.MGR_CD, '
		 || '							K030_2.RBR_KJT, '
		 || '							K030_2.TSUKA_CD '
		 || '					) K030_1 '
		 || '				WHERE '
		 || '					K030.KKN_IDO_KBN IN (''60'', ''61'', ''62'', ''63'', ''64'', ''65'', ''66'', ''67'', ''68'', ''69'', ''6A'', ''6B'', '
		 || '						''70'', ''71'', ''72'', ''73'', ''74'', ''75'', ''76'', ''77'', ''78'', ''79'', ''7A'', ''7B'', ''92'', ''94'', ''96'') '
		 || '					AND SUBSTR(K030.IDO_YMD,1, 6) < ''' || gGyomuYm || ''' '
		 || '					AND K02_T2.ITAKU_KAISHA_CD = K030.ITAKU_KAISHA_CD '
		 || '					AND K02_T2.MGR_CD = K030.MGR_CD '
		 || '					AND K02_T2.TSUKA_CD = K030.TSUKA_CD '
		 || '					AND K030_1.ITAKU_KAISHA_CD = K030.ITAKU_KAISHA_CD '
		 || '					AND K030_1.MGR_CD = K030.MGR_CD '
		 || '					AND K030_1.RBR_KJT = K030.RBR_KJT '
		 || '					AND K030_1.TSUKA_CD = K030.TSUKA_CD '
		 || '					AND PKIPACALCTESURYO.checkHeizonMgr(K030_1.ITAKU_KAISHA_CD, K030_1.MGR_CD, K030_1.ZNDK_KIJUN_YMD, ''1'') = 0 '
		 || '			) AS KKN_SHUKIN_KNGK030, '		-- 前月末出金高
		 || '			SUM(K02_T2.KKN_NYUKIN_KNGK021) AS KKN_NYUKIN_KNGK021, '		-- 当月入金高_基金受入高（出力する明細毎に集約）
		 || '			SUM(K02_T2.KKN_NYUKIN_KNGK022) AS KKN_NYUKIN_KNGK022, '		-- 当月入金高_その他（出力する明細毎に集約）
		 || '			SUM(K02_T2.KKN_SHUKIN_KNGK023) AS KKN_SHUKIN_KNGK023, '		-- 当月出金高_元利金支払高（出力する明細毎に集約）
		 || '			SUM(K02_T2.KKN_SHUKIN_KNGK024) AS KKN_SHUKIN_KNGK024, '		-- 当月出金高_同手数料（出力する明細毎に集約）
		 || '			SUM(K02_T2.KKN_SHUKIN_KNGK025) AS KKN_SHUKIN_KNGK025, '		-- 当月出金高_国税（出力する明細毎に集約）
		 || '			SUM(K02_T2.KKN_NYUKIN_KNGK026) AS KKN_NYUKIN_KNGK026, '		-- 当月出金高_基金返戻金（出力する明細毎に集約）
		 || '			SUM(K02_T2.KKN_NYUKIN_KNGK027) AS KKN_NYUKIN_KNGK027 '		-- 当月出金高_その他（出力する明細毎に集約）
		 || '		FROM'
		 || '		( '
				 		-- 出力対象となる基金異動明細を、
				 		-- 委託会社・銘柄コード・利払期日・異動年月日・通貨コードの単位で集約して取得します。
				 		-- 同時に並存銘柄チェックを行い並存銘柄については取得対象外とします。
		 || '			SELECT '
		 || '				K02_T1.ITAKU_KAISHA_CD, '
		 || '				K02_T1.MGR_CD, '
		 || '				K02_T1.RBR_KJT, '
		 || '				K02_T1.IDO_YMD, '
		 || '				K02_T1.TSUKA_CD, '
		 || '				( '
		 || '					SELECT '
		 || '						COALESCE(SUM(K021.KKN_NYUKIN_KNGK), 0) '
		 || '					FROM '
		 || '						KIKIN_IDO K021 '
		 || '					WHERE '
		 || '						K021.KKN_IDO_KBN IN (''11'', ''12'', ''13'', ''21'', ''22'', ''23'') '
		 || '						AND K02_T1.ITAKU_KAISHA_CD = K021.ITAKU_KAISHA_CD '
		 || '						AND K02_T1.MGR_CD = K021.MGR_CD '
		 || '						AND K02_T1.RBR_KJT = K021.RBR_KJT '
		 || '						AND K02_T1.IDO_YMD = K021.IDO_YMD '
		 || '						AND K02_T1.TSUKA_CD = K021.TSUKA_CD '
		 || '				) AS KKN_NYUKIN_KNGK021, '		-- 当月入金高_基金受入高
		 || '				( '
		 || '					SELECT '
		 || '						COALESCE(SUM(K022.KKN_NYUKIN_KNGK), 0) '
		 || '					FROM '
		 || '						KIKIN_IDO K022 '
		 || '					WHERE '
		 || '						K022.KKN_IDO_KBN IN (''91'', ''93'', ''95'') '
		 || '						AND K02_T1.ITAKU_KAISHA_CD = K022.ITAKU_KAISHA_CD '
		 || '						AND K02_T1.MGR_CD = K022.MGR_CD '
		 || '						AND K02_T1.RBR_KJT = K022.RBR_KJT '
		 || '						AND K02_T1.IDO_YMD = K022.IDO_YMD '
		 || '						AND K02_T1.TSUKA_CD = K022.TSUKA_CD '
		 || '				) AS KKN_NYUKIN_KNGK022, '		-- 当月入金高_その他
		 || '				( '
		 || '					SELECT '
		 || '						COALESCE(SUM(K023.KKN_SHUKIN_KNGK), 0) '
		 || '					FROM '
		 || '						KIKIN_IDO K023 '
		 || '					WHERE '
		 || '						K023.KKN_IDO_KBN IN (''31'', ''41'') '
		 || '						AND K02_T1.ITAKU_KAISHA_CD = K023.ITAKU_KAISHA_CD '
		 || '						AND K02_T1.MGR_CD = K023.MGR_CD '
		 || '						AND K02_T1.RBR_KJT = K023.RBR_KJT '
		 || '						AND K02_T1.IDO_YMD = K023.IDO_YMD '
		 || '						AND K02_T1.TSUKA_CD = K023.TSUKA_CD '
		 || '						AND EXISTS '
		 || '						( ' 
		 || '							SELECT ctid FROM KIKIN_SEIKYU K01 ' 
		 || '							WHERE (K01.KK_KANYO_UMU_FLG = ''1'' '
		 || '								OR (K01.KK_KANYO_UMU_FLG <> ''1'' AND K01.SHORI_KBN = ''1'')) '
		 || '								AND K023.ITAKU_KAISHA_CD = K01.ITAKU_KAISHA_CD '
		 || '								AND K023.MGR_CD = K01.MGR_CD '
		 || '								AND K023.RBR_YMD = K01.SHR_YMD '
		 || '						) '
		 || '				) AS KKN_SHUKIN_KNGK023, '		-- 当月出金高_元利金支払高
		 || '				( '
		 || '					SELECT '
		 || '						COALESCE(SUM(K024.KKN_SHUKIN_KNGK), 0) '
		 || '					FROM '
		 || '						KIKIN_IDO K024 '
		 || '					WHERE '
		 || '						K024.KKN_IDO_KBN IN(''32'', ''33'', ''42'', ''43'') '
		 || '						AND K02_T1.ITAKU_KAISHA_CD = K024.ITAKU_KAISHA_CD '
		 || '						AND K02_T1.MGR_CD = K024.MGR_CD '
		 || '						AND K02_T1.RBR_KJT = K024.RBR_KJT '
		 || '						AND K02_T1.IDO_YMD = K024.IDO_YMD '
		 || '						AND K02_T1.TSUKA_CD = K024.TSUKA_CD '
		 || '						AND EXISTS '
		 || '						( '
		 || '							SELECT ctid FROM KIKIN_SEIKYU K01 '
		 || '							WHERE (K01.KK_KANYO_UMU_FLG = ''1'' '
		 || '								OR (K01.KK_KANYO_UMU_FLG <> ''1'' AND K01.SHORI_KBN = ''1'')) '
		 || '								AND SUBSTR(K01.SHR_YMD,1, 6) = SUBSTR(PKDATE.getMinusDate(''' || gGyomuYm || '01'', 1), 1, 6) '
		 || '								AND K024.ITAKU_KAISHA_CD = K01.ITAKU_KAISHA_CD '
		 || '								AND K024.MGR_CD = K01.MGR_CD '
		 || '								AND K024.RBR_YMD = K01.SHR_YMD '
		 || '						) '
		 || '				) AS KKN_SHUKIN_KNGK024, '		-- 当月出金高_同手数料
		 || '				( '
		 || '					SELECT '
		 || '						COALESCE(SUM(K025.KKN_SHUKIN_KNGK), 0) '
		 || '					FROM '
		 || '						KIKIN_IDO K025 '
		 || '					WHERE '
		 || '						K025.KKN_IDO_KBN IN (''51'') '
		 || '						AND K02_T1.ITAKU_KAISHA_CD = K025.ITAKU_KAISHA_CD '
		 || '						AND K02_T1.MGR_CD = K025.MGR_CD '
		 || '						AND K02_T1.RBR_KJT = K025.RBR_KJT '
		 || '						AND K02_T1.IDO_YMD = K025.IDO_YMD '
		 || '						AND K02_T1.TSUKA_CD = K025.TSUKA_CD '
		 || '						AND EXISTS '
		 || '						( '
		 || '							SELECT ctid FROM KIKIN_SEIKYU K01 '
		 || '							WHERE (K01.KK_KANYO_UMU_FLG = ''1'' '
		 || '								OR (K01.KK_KANYO_UMU_FLG <> ''1'' AND K01.SHORI_KBN = ''1'')) '
		 || '								AND SUBSTR(K01.SHR_YMD, 1, 6) = SUBSTR(PKDATE.getMinusDate(''' || gGyomuYm || '01'', 1), 1, 6) '
		 || '								AND K025.ITAKU_KAISHA_CD = K01.ITAKU_KAISHA_CD '
		 || '								AND K025.ITAKU_KAISHA_CD = K01.ITAKU_KAISHA_CD '
		 || '								AND K025.MGR_CD = K01.MGR_CD '
		 || '								AND K025.RBR_YMD = K01.SHR_YMD '
		 || '						) '
		 || '				) AS KKN_SHUKIN_KNGK025, '		-- 当月出金高_国税
		 || '				( '
		 || '					SELECT '
		 || '						COALESCE(SUM(K026.KKN_SHUKIN_KNGK), 0) '
		 || '					FROM '
		 || '						KIKIN_IDO K026 '
		 || '					WHERE '
		 || '						K026.KKN_IDO_KBN IN (''60'', ''61'', ''62'', ''63'', ''64'', ''65'', ''66'', '
		 || '							''67'', ''68'', ''69'', ''6A'', ''6B'', ''70'', ''71'', ''72'', ''73'', ''74'','
		 || '							''75'', ''76'', ''77'', ''78'', ''79'', ''7A'', ''7B'') '
		 || '						AND K02_T1.ITAKU_KAISHA_CD = K026.ITAKU_KAISHA_CD '
		 || '						AND K02_T1.MGR_CD = K026.MGR_CD '
		 || '						AND K02_T1.RBR_KJT = K026.RBR_KJT '
		 || '						AND K02_T1.IDO_YMD = K026.IDO_YMD '
		 || '						AND K02_T1.TSUKA_CD = K026.TSUKA_CD '
		 || '				) AS KKN_NYUKIN_KNGK026, '		-- 当月出金高_基金返戻金
		 || '				( '
		 || '					SELECT '
		 || '						COALESCE(SUM(K027.KKN_SHUKIN_KNGK), 0) '
		 || '					FROM '
		 || '						KIKIN_IDO K027 '
		 || '					WHERE '
		 || '						K027.KKN_IDO_KBN IN (''92'', ''94'', ''96'') '
		 || '						AND K02_T1.ITAKU_KAISHA_CD = K027.ITAKU_KAISHA_CD '
		 || '						AND K02_T1.MGR_CD = K027.MGR_CD '
		 || '						AND K02_T1.RBR_KJT = K027.RBR_KJT '
		 || '						AND K02_T1.IDO_YMD = K027.IDO_YMD '
		 || '						AND K02_T1.TSUKA_CD = K027.TSUKA_CD '
		 || '				) AS KKN_NYUKIN_KNGK027 '		-- 当月出金高_その他
		 || '			FROM '
		 || '				KIKIN_IDO K02_T1, '
		 || '				( '
		 || '					SELECT '
		 || '						K02_T3.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD, '
		 || '						K02_T3.MGR_CD AS MGR_CD, '
		 || '						K02_T3.RBR_KJT AS RBR_KJT, '
		 || '						K02_T3.TSUKA_CD AS TSUKA_CD, '
		 || '						TRIM(MAX(K02_T3.ZNDK_KIJUN_YMD)) AS ZNDK_KIJUN_YMD '
		 || '					FROM '
		 || '						KIKIN_IDO K02_T3 '
		 || '					WHERE '
		 || '						K02_T3.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' '
		 || '						AND K02_T3.KKN_IDO_KBN IN (''11'', ''21'', ''22'') '
		 || '						AND K02_T3.DATA_SAKUSEI_KBN >= ''1'' '
		 || '					GROUP BY '
		 || '						K02_T3.ITAKU_KAISHA_CD, '
		 || '						K02_T3.MGR_CD, '
		 || '						K02_T3.RBR_KJT, '
		 || '						K02_T3.TSUKA_CD '
		 || '				) K02_T4 '		-- 並存銘柄チェック用の残高基準日を取得
		 || '			WHERE '
		 || '				K02_T1.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' '
		 || '				AND SUBSTR(K02_T1.IDO_YMD, 1, 6) = ''' || gGyomuYm || ''' '
		 || '				AND K02_T1.ITAKU_KAISHA_CD = K02_T4.ITAKU_KAISHA_CD '
		 || '				AND K02_T1.MGR_CD = K02_T4.MGR_CD '
		 || '				AND K02_T1.RBR_KJT = K02_T4.RBR_KJT '
		 || '				AND K02_T1.TSUKA_CD = K02_T4.TSUKA_CD '
		 || '				AND PKIPACALCTESURYO.checkHeizonMgr(K02_T4.ITAKU_KAISHA_CD, K02_T4.MGR_CD, K02_T4.ZNDK_KIJUN_YMD, ''1'') = 0 '
		 || '				AND EXISTS '
		 || '				( '
		 || '					SELECT '
		 || '						ctid '
		 || '					FROM '
		 || '						MGR_KIHON_VIEW VMG12 '
		 || '					WHERE '
		 || '						VMG12.ISIN_CD IS NOT NULL '
		 || '						AND VMG12.SHORI_KBN = ''1'' '
		 || '						AND VMG12.JTK_KBN NOT IN (''2'', ''5'') '
		 || '						AND K02_T1.ITAKU_KAISHA_CD = VMG12.ITAKU_KAISHA_CD '
		 || '						AND K02_T1.MGR_CD = VMG12.MGR_CD ';
-- リアルの場合
IF l_inChohyoKbn = '0' THEN
	-- 銘柄コード
	IF (trim(both l_inMgrCd) IS NOT NULL AND (trim(both l_inMgrCd))::text <> '') THEN
		gSql := gSql || '			AND VMG12.MGR_CD = ''' || l_inMgrCd || ''' ';
	END IF;
	-- ISINコード
	IF (trim(both l_inIsinCd) IS NOT NULL AND (trim(both l_inIsinCd))::text <> '') THEN
		gSql := gSql || '			AND VMG12.ISIN_CD = ''' || l_inIsinCd || ''' ';
	END IF;
END IF;
gSql := gSql || '			) '
		 || '			GROUP BY '
		 || '				K02_T1.ITAKU_KAISHA_CD, '
		 || '				K02_T1.MGR_CD, '
		 || '				K02_T1.RBR_KJT, '
		 || '				K02_T1.IDO_YMD, '
		 || '				K02_T1.TSUKA_CD '
		 || '		) K02_T2'
		 || '		GROUP BY '
		 || '			K02_T2.ITAKU_KAISHA_CD, '
		 || '			K02_T2.MGR_CD, '
		 || '			K02_T2.TSUKA_CD, '
		 || '			SUBSTR(K02_T2.IDO_YMD, 1, 6)'
		 || '	) 	K02 '
		 || '	INNER JOIN VJIKO_ITAKU VJ1 ON K02.ITAKU_KAISHA_CD = VJ1.KAIIN_ID '
		 || '	INNER JOIN MGR_KIHON_VIEW VMG1 ON VMG1.ITAKU_KAISHA_CD = K02.ITAKU_KAISHA_CD '
		 || '		AND VMG1.MGR_CD = K02.MGR_CD '
		 || '		AND VMG1.KK_KANYO_FLG <> ''2'' '
		 || '	LEFT JOIN MHAKKOTAI M01 ON VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD '
		 || '		AND VMG1.HKT_CD = M01.HKT_CD '
		 || '	LEFT JOIN MTSUKA M64 ON K02.TSUKA_CD = M64.TSUKA_CD '
		 || '	WHERE 1=1 ';	-- 実質記番号管理銘柄対応
-- 入力パラメータ条件
-- リアルの場合
IF l_inChohyoKbn = '0' THEN
	-- 発行体コード
	IF (trim(both l_inHktCd) IS NOT NULL AND (trim(both l_inHktCd))::text <> '') THEN
		gSql := gSql || '	AND M01.HKT_CD = ''' || l_inHktCd || ''' ';
	END IF;
	-- 口座店コード
	IF (trim(both l_inKozaTenCd) IS NOT NULL AND (trim(both l_inKozaTenCd))::text <> '') THEN
		gSql := gSql || '	AND M01.KOZA_TEN_CD = ''' || l_inKozaTenCd || ''' ';
	END IF;
	-- 口座店CIFコード
	IF (trim(both l_inKozaTenCifCd) IS NOT NULL AND (trim(both l_inKozaTenCifCd))::text <> '') THEN
		gSql := gSql || '	AND M01.KOZA_TEN_CIFCD = ''' || l_inKozaTenCifCd || ''' ';
	END IF;
END IF;
-- ORDER BY句
gSql := gSql || 'ORDER BY ';
IF gRedOptionFlg = '1' THEN
	-- 口座店コード＞口座店ＣＩＦコード＞通貨コード＞発行日（表示なし）＞ＩＳＩＮコード
	gSql := gSql
		||	'	M01.KOZA_TEN_CD, '
		||	'	M01.KOZA_TEN_CIFCD, '
		||	'	K02.TSUKA_CD, '
		||	'	VMG1.HAKKO_YMD, '
		||	'	VMG1.ISIN_CD';
ELSE
	-- ORDER BY句
	gSql := gSql
		||	'	K02.ITAKU_KAISHA_CD, ' 
		||	'	CASE WHEN ''' || gChohyoSortFlg || ''' = ''1'' THEN M01.HKT_KANA_RNM ELSE M01.HKT_CD END, ' 
		||	'	M01.HKT_CD, '
		||	'	K02.TSUKA_CD, ' 
		||	'	CASE WHEN ''' || gChohyoSortFlg || ''' = ''1'' THEN VMG1.MGR_CD ELSE VMG1.ISIN_CD END';
END IF;
	RETURN gSql;
EXCEPTION
	WHEN OTHERS THEN
	RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipi050k00r01_createsql () FROM PUBLIC;