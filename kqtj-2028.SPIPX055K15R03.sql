


DROP TYPE IF EXISTS spipx055k15r03_type_record;
CREATE TYPE spipx055k15r03_type_record AS (
		KYOTEN_KBN		char(1),		  -- 拠点区分
		KYOTEN_KBN_NM		varchar(40),	  -- 拠点区分名称
		KOZA_FURI_KBN		char(2),	  -- 口座振替区分
		KOZA_FURI_KBN_NM	varchar(24),	  -- 口座振替区分名称
		HKT_RNM			varchar(40),		  -- 発行体略称
		KOZA_TEN_CD		char(4),	  -- 口座店コード
		KOZA_TEN_CIFCD		char(11),	  -- 口座店CIFコード
		HKT_CD			char(6),		  -- 発行体コード
		KOZA_TEN_CD2		varchar(4),			  -- 口座店コード２
		KAMOKU_NM		varchar(40),			  -- 科目名称
		KOZA_NO			varchar(7),			  -- 口座番号
		TANPO_KBN		varchar(40),		  -- 担保区分名称
		TSUKA_CD		char(3),		  -- 通貨コード
		TSUKA_NM		char(3),		  -- 通貨名称
		ISIN_CD			char(12),		  -- ISINコード
		MGR_CD			varchar(13),		  -- 銘柄コード
		MGR_RNM			varchar(44),		  -- 銘柄略称
		TESU_SHURUI_NM		varchar(24),	  -- 手数料種類名称
		CHOKYU_YMD		char(8),	  -- 徴求日
		DISTRI_YMD		char(8),	  -- 分配日
		ALL_TESU_KNGK		numeric,	  -- 手数料金額（税抜）全体
		ALL_TESU_SZEI		numeric,	  -- 全体消費税額
		OWN_TESU_KNGK		numeric,	  -- 自行手数料額（税抜）
		OWN_TESU_SZEI		numeric,	  -- 自行消費税額
		OTHER_TESU_KNGK		numeric,	  -- 他行手数料額（税抜）
		OTHER_TESU_SZEI		numeric,	  -- 他行消費税額
		BANK_RNM		varchar(30),		  -- 金融機関略称
		DF_BUNSHI		numeric(5),	  -- 分配分子
		DF_BUNBO		integer,	  	  -- 分配分母
		DF_TESU_KNGK		decimal(14,2), -- 分配手数料金額（税抜）
		DF_TESU_SZEI		decimal(12,2), -- 分配手数料金額（消費税）
		INPUT_NUM		numeric(2)	  -- 入力順
	);


CREATE OR REPLACE PROCEDURE spipx055k15r03 (l_inChohyoId TEXT, -- 帳票ID
 l_inItakuKaishaCd TEXT, -- 委託会社コード
 l_inBankRnm text, -- 委託会社略称
 l_inUserId TEXT, -- ユーザーID
 l_inChohyoKbn TEXT, -- 帳票区分
 l_inGyomuYmd TEXT, -- 業務日付
 l_outSqlCode OUT integer, -- リターン値
 l_outSqlErrM OUT text -- エラーコメント
 ) AS $body$
DECLARE

  --
--   * 著作権:Copyright(c)2016
--   * 会社名:JIP
--   * 概要　:公社債関連資金受入予定表（信託報酬・期中手数料）を作成する。
--   *
--   * @param    l_inChohyoId            IN  TEXT        帳票ID
--   * @param    l_inItakuKaishaCd       IN  TEXT        委託会社コード
--   * @param    l_inBankRnm	       IN  VARCHAR    委託会社略称
--   * @param    l_inUserId              IN  TEXT        ユーザーID
--   * @param    l_inChohyoKbn           IN  TEXT        帳票区分
--   * @param    l_inGyomuYmd            IN  TEXT        業務日付
--   * @param    l_outSqlCode            OUT INTEGER     リターン値
--   * @param    l_outSqlErrM            OUT VARCHAR    エラーコメント
--   *
--   * @return なし
--   *
--   * @author Y.Nagano
--   * @version $Id: SPIPX055K15R03.sql,v 1.00 2016/11/28 14:45:33 Y.Nagano Exp $
--   *
--   ***************************************************************************
--   * ログ　:
--   * 　　　日付    開発者名        目的
--   * -------------------------------------------------------------------
--   *　2016.11.28   Y.Nagano@Texnos 新規作成
--   *
--   ***************************************************************************
--  
  --==============================================================================
  --                    定数定義                                                  
  --==============================================================================
 	C_PROCEDURE_ID  CONSTANT varchar(50) := 'SPIPX055K15R03';     -- プロシージャＩＤ
 	C_WKREPORT_ID   CONSTANT varchar(50) := 'WK931505531';          -- ＷＫレポートＩＤ
  --==============================================================================
  --                    変数定義                                                  
  --==============================================================================
 	gSQL		text := NULL;			 -- SQL格納用変数
	gSeqNo		integer := 0;				 -- カウンター
	gRecCnt		integer := 0;				 -- レコード件数
	gInsCnt		integer := 1;				 -- 登録件数カウンター
	gTukaFormat		varchar(21) := NULL;		 -- 通貨フォーマット
	gBunsho         varchar(150) := NULL;      -- インボイス文章
	gInvoiceFlg     MOPTION_KANRI.OPTION_FLG%TYPE;   -- インボイスオプションフラグ
	gAryBun         pkIpaBun.BUN_ARRAY;              -- インボイス文章(請求書)配列
	-- レコードタイプ宣言
	-- レコード
	rec spipx055k15r03_type_record[];
	tmp_rec spipx055k15r03_type_record;
	v_item TYPE_SREPORT_WK_ITEM;
  --==============================================================================
  --					カーソル定義													
  --==============================================================================
	curMeisai CURSOR FOR
	SELECT
		    MHK2.KYOTEN_KBN AS KYOTEN_KBN
		  , SC8.CODE_NM AS KYOTEN_KBN_NM
		  , VT.KOZA_FURI_KBN AS KOZA_FURI_KBN
		  , VT.KOZA_FURI_KBN_NM AS KOZA_FURI_KBN_NM
		  , MHK.HKT_RNM AS HKT_RNM
		  , MHK.KOZA_TEN_CD AS KOZA_TEN_CD
		  , MHK.KOZA_TEN_CIFCD AS KOZA_TEN_CIFCD
		  , MHK.HKT_CD AS HKT_CD
		  , (CASE VT.KOZA_FURI_KBN
			WHEN '10' THEN MHK2.HKO_KOZA_TEN_CD1
			WHEN '11' THEN MHK2.HKO_KOZA_TEN_CD2
			WHEN '12' THEN MHK2.HKO_KOZA_TEN_CD3
			WHEN '13' THEN MHK2.HKO_KOZA_TEN_CD4
			WHEN '14' THEN MHK2.HKO_KOZA_TEN_CD5
			ELSE KFR.KOZA_TEN_CD
		     END) AS KOZA_TEN_CD2
		  , (CASE VT.KOZA_FURI_KBN
			WHEN '10' THEN SC2.CODE_NM
			WHEN '11' THEN SC3.CODE_NM
			WHEN '12' THEN SC4.CODE_NM
			WHEN '13' THEN SC5.CODE_NM
			WHEN '14' THEN SC6.CODE_NM
			ELSE SC7.CODE_NM
		   END) AS KAMOKU_NM
		, (CASE VT.KOZA_FURI_KBN
			WHEN '10' THEN MHK.HKO_KOZA_NO
			WHEN '11' THEN MHK2.HKO_KOZA_NO2
			WHEN '12' THEN MHK2.HKO_KOZA_NO3
			WHEN '13' THEN MHK2.HKO_KOZA_NO4
			WHEN '14' THEN MHK2.HKO_KOZA_NO5
			ELSE KFR.KOZA_NO
		   END) AS KOZA_NO
		, SC1.CODE_NM AS TANPO_KBN
		, VT.TSUKA_CD AS TSUKA_CD
		, MT.TSUKA_NM AS TSUKA_NM
		, VT.ISIN_CD AS ISIN_CD
		, VT.MGR_CD AS MGR_CD
		, VT.MGR_RNM AS MGR_RNM
		, VT.TESU_SHURUI_NM AS TESU_SHURUI_NM
		, VT.CHOKYU_YMD AS CHOKYU_YMD
		, VT.DISTRI_YMD AS DISTRI_YMD
		, VT.ALL_TESU_KNGK + VT.HOSEI_ALL_TESU_KNGK + VT.ALL_TESU_SZEI + VT.HOSEI_ALL_TESU_SZEI AS ALL_TESU_KNGK
		, VT.ALL_TESU_SZEI + VT.HOSEI_ALL_TESU_SZEI AS ALL_TESU_SZEI
		, VT.OWN_TESU_KNGK + VT.HOSEI_OWN_TESU_KNGK + VT.OWN_TESU_SZEI + VT.HOSEI_OWN_TESU_SZEI AS OWN_TESU_KNGK
		, VT.OWN_TESU_SZEI + VT.HOSEI_OWN_TESU_SZEI AS OWN_TESU_SZEI
		, VT.OTHER_TESU_KNGK + VT.HOSEI_OTHER_TESU_KNGK + VT.OTHER_TESU_SZEI + VT.HOSEI_OTHER_TESU_SZEI AS OTHER_TESU_KNGK
		, VT.OTHER_TESU_SZEI + VT.HOSEI_OTHER_TESU_SZEI AS OTHER_TESU_SZEI
		, MB.BANK_RNM AS BANK_RNM
		, BUN.DF_BUNSHI AS DF_BUNSHI
		, VT.DF_BUNBO AS DF_BUNBO
		, BUN.DF_TESU_KNGK + BUN.HOSEI_DF_TESU_KNGK + BUN.DF_TESU_SZEI + BUN.HOSEI_DF_TESU_SZEI AS DF_TESU_KNGK
		, BUN.DF_TESU_SZEI + BUN.HOSEI_DF_TESU_SZEI AS DF_TESU_SZEI
		, MJTK.INPUT_NUM AS INPUT_NUM
	FROM vtesuryo vt, sreport_wk rpt, mtsuka mt, mgr_jutakuginko mjtk, mbank mb, tesuryo_bunpai bun, mgr_kihon_view mkhn
LEFT OUTER JOIN scode sc1 ON (MKHN.TANPO_KBN = SC1.CODE_VALUE)
, mhakkotai2 mhk2
LEFT OUTER JOIN scode sc3 ON (MHK2.HKO_KAMOKU_CD2 = SC3.CODE_VALUE AND '707' = SC3.CODE_SHUBETSU)
LEFT OUTER JOIN scode sc4 ON (MHK2.HKO_KAMOKU_CD3 = SC4.CODE_VALUE AND '707' = SC4.CODE_SHUBETSU)
LEFT OUTER JOIN scode sc5 ON (MHK2.HKO_KAMOKU_CD4 = SC5.CODE_VALUE AND '707' = SC5.CODE_SHUBETSU)
LEFT OUTER JOIN scode sc6 ON (MHK2.HKO_KAMOKU_CD5 = SC6.CODE_VALUE AND '707' = SC6.CODE_SHUBETSU)
LEFT OUTER JOIN scode sc8 ON (MHK2.KYOTEN_KBN = SC8.CODE_VALUE AND 'B02' = SC8.CODE_SHUBETSU)
, mhakkotai mhk
LEFT OUTER JOIN scode sc2 ON (MHK.HKO_KAMOKU_CD = SC2.CODE_VALUE AND '707' = SC2.CODE_SHUBETSU)
, koza_frk kfr
LEFT OUTER JOIN scode sc7 ON (KFR.KOZA_KAMOKU = SC7.CODE_VALUE AND '707' = SC7.CODE_SHUBETSU)
WHERE VT.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND VT.ITAKU_KAISHA_CD = RPT.KEY_CD AND VT.MGR_CD = RPT.ITEM001 AND VT.CHOKYU_YMD = RPT.ITEM002 AND RPT.USER_ID = pkconstant.BATCH_USER() AND RPT.CHOHYO_KBN = '1' AND RPT.SAKUSEI_YMD = l_inGyomuYmd AND RPT.CHOHYO_ID = C_WKREPORT_ID AND VT.TESU_SHURUI_CD IN ('11','12') AND VT.ALL_TESU_KNGK > 0 AND VT.ITAKU_KAISHA_CD = BUN.ITAKU_KAISHA_CD AND VT.MGR_CD = BUN.MGR_CD AND VT.TESU_SHURUI_CD = BUN.TESU_SHURUI_CD AND VT.CHOKYU_KJT = BUN.CHOKYU_KJT AND VT.ITAKU_KAISHA_CD = MKHN.ITAKU_KAISHA_CD AND VT.MGR_CD = MKHN.MGR_CD AND MKHN.JTK_KBN IN ('1','4') AND MJTK.ITAKU_KAISHA_CD = BUN.ITAKU_KAISHA_CD AND MJTK.MGR_CD = BUN.MGR_CD AND MJTK.FINANCIAL_SECURITIES_KBN = BUN.FINANCIAL_SECURITIES_KBN AND MJTK.BANK_CD = BUN.BANK_CD AND BUN.FINANCIAL_SECURITIES_KBN = MB.FINANCIAL_SECURITIES_KBN AND BUN.BANK_CD = MB.BANK_CD AND VT.TSUKA_CD = MT.TSUKA_CD  AND SC1.CODE_SHUBETSU = '519'               AND (VT.ISIN_CD IS NOT NULL AND VT.ISIN_CD::text <> '') AND VT.ITAKU_KAISHA_CD = MHK.ITAKU_KAISHA_CD AND VT.HKT_CD = MHK.HKT_CD AND VT.ITAKU_KAISHA_CD = MHK2.ITAKU_KAISHA_CD AND VT.HKT_CD = MHK2.HKT_CD AND VT.ITAKU_KAISHA_CD = KFR.ITAKU_KAISHA_CD AND VT.KOZA_FURI_KBN = KFR.KOZA_FURI_KBN ORDER BY
		  VT.ITAKU_KAISHA_CD
		, MHK2.KYOTEN_KBN
		, VT.TSUKA_CD
		, VT.KOZA_FURI_KBN
		, VT.CHOKYU_YMD
		, MHK.HKT_KANA_RNM
		, VT.ISIN_CD
		, MJTK.INPUT_NUM;
  --==============================================================================
  --    メイン処理    
  --==============================================================================
BEGIN
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inChohyoId)::text, '') = '' OR coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' OR
	    coalesce(trim(both l_inUserId)::text, '') = '' OR coalesce(trim(both l_inChohyoKbn)::text, '') = '' OR
	    coalesce(trim(both l_inGyomuYmd)::text, '') = '' THEN
	  	-- ログ書込み
	      CALL pkLog.error('ECM501', C_PROCEDURE_ID, '');
	      l_outSqlCode := pkconstant.error();
	      l_outSqlErrM := '';
	      RETURN;
	END IF;
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	   WHERE KEY_CD = l_inItakuKaishaCd
	     AND USER_ID = l_inUserId
	     AND CHOHYO_KBN = l_inChohyoKbn
	     AND SAKUSEI_YMD = l_inGyomuYmd
	     AND CHOHYO_ID = l_inChohyoId;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd,
	                     l_inUserId,
	                     l_inChohyoKbn,
	                     l_inGyomuYmd,
	                     l_inChohyoId);
	-- インボイスオプションフラグを取得する
	gInvoiceFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd, 'INVOICE_C', '0');
	-- インボイスオプションフラグが"1"の場合
	IF gInvoiceFlg = '1' THEN
	    -- インボイス文章取得
	    gAryBun := pkIpaBun.getBun(l_inChohyoId, 'L0');
	    FOR i IN 0..coalesce(cardinality(gAryBun), 0) - 1 LOOP
	         IF i = 0 THEN
	             gBunsho := gAryBun[i];
	         END IF;
	    END LOOP;
	END IF;
	-- カウンタ初期化
	gSeqNo := 0;
	-- データの取得
	FOR recMeisai IN curMeisai
	LOOP
		-- Extend array
		rec := array_append(rec, NULL::spipx055k15r03_type_record);
		gSeqNo := gSeqNo + 1;
		rec[gSeqNo].KYOTEN_KBN := recMeisai.KYOTEN_KBN;
		rec[gSeqNo].KYOTEN_KBN_NM := recMeisai.KYOTEN_KBN_NM;
		rec[gSeqNo].KOZA_FURI_KBN := recMeisai.KOZA_FURI_KBN;
		rec[gSeqNo].KOZA_FURI_KBN_NM := recMeisai.KOZA_FURI_KBN_NM;
		rec[gSeqNo].HKT_RNM := recMeisai.HKT_RNM;
		rec[gSeqNo].KOZA_TEN_CD := recMeisai.KOZA_TEN_CD;
		rec[gSeqNo].KOZA_TEN_CIFCD := recMeisai.KOZA_TEN_CIFCD;
		rec[gSeqNo].HKT_CD := recMeisai.HKT_CD;
		rec[gSeqNo].KOZA_TEN_CD2 := recMeisai.KOZA_TEN_CD2;
		rec[gSeqNo].KAMOKU_NM := recMeisai.KAMOKU_NM;
		rec[gSeqNo].KOZA_NO := recMeisai.KOZA_NO;
		rec[gSeqNo].TANPO_KBN := recMeisai.TANPO_KBN;
		rec[gSeqNo].TSUKA_CD := recMeisai.TSUKA_CD;
		rec[gSeqNo].TSUKA_NM := recMeisai.TSUKA_NM;
		rec[gSeqNo].ISIN_CD := recMeisai.ISIN_CD;
		rec[gSeqNo].MGR_CD := recMeisai.MGR_CD;
		rec[gSeqNo].MGR_RNM := recMeisai.MGR_RNM;
		rec[gSeqNo].TESU_SHURUI_NM := recMeisai.TESU_SHURUI_NM;
		rec[gSeqNo].CHOKYU_YMD := recMeisai.CHOKYU_YMD;
		rec[gSeqNo].DISTRI_YMD := recMeisai.DISTRI_YMD;
		rec[gSeqNo].ALL_TESU_KNGK := recMeisai.ALL_TESU_KNGK;
		rec[gSeqNo].ALL_TESU_SZEI := recMeisai.ALL_TESU_SZEI;
		rec[gSeqNo].OWN_TESU_KNGK := recMeisai.OWN_TESU_KNGK;
		rec[gSeqNo].OWN_TESU_SZEI := recMeisai.OWN_TESU_SZEI;
		rec[gSeqNo].OTHER_TESU_KNGK := recMeisai.OTHER_TESU_KNGK;
		rec[gSeqNo].OTHER_TESU_SZEI := recMeisai.OTHER_TESU_SZEI;
		rec[gSeqNo].BANK_RNM := recMeisai.BANK_RNM;
		rec[gSeqNo].DF_BUNSHI := recMeisai.DF_BUNSHI;
		rec[gSeqNo].DF_BUNBO := recMeisai.DF_BUNBO;
		rec[gSeqNo].DF_TESU_KNGK := recMeisai.DF_TESU_KNGK;
		rec[gSeqNo].DF_TESU_SZEI := recMeisai.DF_TESU_SZEI;
		rec[gSeqNo].INPUT_NUM := recMeisai.INPUT_NUM;
	-- レコード数分ループの終了
	END LOOP;
	-- 対象データ無しの場合の処理
	IF gSeqNo = 0 THEN
		-- 対象データなし
		l_outSqlCode := pkconstant.NO_DATA_FIND();
		RETURN;
	ELSE
		-- レコード件数を保持する
		gRecCnt := gSeqNo;
		-- ローカル変数を初期化する
		FOR gSeqNo IN 1..gRecCnt LOOP
			-- 通貨フォーマットの設定
			IF rec[gSeqNo].TSUKA_CD = 'JPY' THEN
				gTukaFormat := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';
			ELSE
				gTukaFormat := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';
			END IF;
			-- ローカル変数．レコード（ローカル変数．カウンター）．入力順　＝　1の場合
			IF rec[gSeqNo].INPUT_NUM = '1' THEN
				-- 最終行の場合
				IF gSeqNo = gRecCnt - 1 THEN
					-- ワークデータ作成
					CALL pkPrint.insertData(
						l_inKeyCd	=>	l_inItakuKaishaCd
						,l_inUserId	=>	pkconstant.BATCH_USER()
						,l_inChohyoKbn	=>	'1'
						,l_inSakuseiYmd	=>	l_inGyomuYmd
						,l_inChohyoId	=>	l_inChohyoId
						,l_inSeqNo	=>	gInsCnt
						,l_inHeaderFlg	=>	'1'
						,l_inItem001	=>	l_inItakuKaishaCd
						,l_inItem002	=>	l_inBankRnm
						,l_inItem003	=>	rec[gSeqNo].KYOTEN_KBN
						,l_inItem004	=>	rec[gSeqNo].KYOTEN_KBN_NM
						,l_inItem005	=>	rec[gSeqNo].KOZA_FURI_KBN
						,l_inItem006	=>	rec[gSeqNo].KOZA_FURI_KBN_NM
						,l_inItem007	=>	rec[gSeqNo].CHOKYU_YMD
						,l_inItem008	=>	rec[gSeqNo].HKT_RNM
						,l_inItem009	=>	rec[gSeqNo].MGR_RNM
						,l_inItem010	=>	rec[gSeqNo].ISIN_CD
						,l_inItem011	=>	rec[gSeqNo].KOZA_TEN_CD
						,l_inItem012	=>	rec[gSeqNo].KOZA_TEN_CIFCD
						,l_inItem013	=>	rec[gSeqNo].HKT_CD
						,l_inItem014	=>	rec[gSeqNo].KOZA_TEN_CD2
						,l_inItem015	=>	rec[gSeqNo].KAMOKU_NM
						,l_inItem016	=>	rec[gSeqNo].KOZA_NO
						,l_inItem017	=>	rec[gSeqNo].TANPO_KBN
						,l_inItem018	=>	rec[gSeqNo].ALL_TESU_KNGK
						,l_inItem019	=>	rec[gSeqNo].ALL_TESU_SZEI
						,l_inItem020	=>	rec[gSeqNo].OWN_TESU_KNGK
						,l_inItem021	=>	rec[gSeqNo].OWN_TESU_SZEI
						,l_inItem022	=>	NULL
						,l_inItem023	=>	NULL
						,l_inItem024	=>	NULL
						,l_inItem025	=>	NULL
						,l_inItem026	=>	NULL
						,l_inItem027	=>	NULL
						,l_inItem028	=>	NULL
						,l_inItem029	=>	NULL
						,l_inItem030	=>	rec[gSeqNo].TSUKA_CD
						,l_inItem031	=>	rec[gSeqNo].TSUKA_NM
						,l_inItem032	=>	gTukaFormat
						,l_inItem033	=>	rec[gSeqNo].INPUT_NUM
						,l_inItem034	=>	l_inGyomuYmd
						,l_inItem035	=>	l_inChohyoId
						,l_inItem036	=>	pkconstant.BATCH_USER()
						,l_inItem037	=>	gInvoiceFlg
						,l_inItem038	=>	gBunsho
						,l_inKousinId	=>	pkconstant.BATCH_USER()
						,l_inSakuseiId	=>	pkconstant.BATCH_USER()
					);
					-- 登録件数カウントアップ
					gInsCnt := gInsCnt + 1;
				ELSE
					-- ローカル変数．レコード（ローカル変数．カウンター）．入力順　＝　ローカル変数．レコード（ローカル変数．カウンター＋1）．入力順の場合
					IF rec[gSeqNo].INPUT_NUM = rec[gSeqNo + 1].INPUT_NUM  THEN
						-- ワークデータ作成
						CALL pkPrint.insertData(
							l_inKeyCd	=>	l_inItakuKaishaCd
							,l_inUserId	=>	pkconstant.BATCH_USER()
							,l_inChohyoKbn	=>	'1'
							,l_inSakuseiYmd	=>	l_inGyomuYmd
							,l_inChohyoId	=>	l_inChohyoId
							,l_inSeqNo	=>	gInsCnt
							,l_inHeaderFlg	=>	'1'
							,l_inItem001	=>	l_inItakuKaishaCd
							,l_inItem002	=>	l_inBankRnm
							,l_inItem003	=>	rec[gSeqNo].KYOTEN_KBN
							,l_inItem004	=>	rec[gSeqNo].KYOTEN_KBN_NM
							,l_inItem005	=>	rec[gSeqNo].KOZA_FURI_KBN
							,l_inItem006	=>	rec[gSeqNo].KOZA_FURI_KBN_NM
							,l_inItem007	=>	rec[gSeqNo].CHOKYU_YMD
							,l_inItem008	=>	rec[gSeqNo].HKT_RNM
							,l_inItem009	=>	rec[gSeqNo].MGR_RNM
							,l_inItem010	=>	rec[gSeqNo].ISIN_CD
							,l_inItem011	=>	rec[gSeqNo].KOZA_TEN_CD
							,l_inItem012	=>	rec[gSeqNo].KOZA_TEN_CIFCD
							,l_inItem013	=>	rec[gSeqNo].HKT_CD
							,l_inItem014	=>	rec[gSeqNo].KOZA_TEN_CD2
							,l_inItem015	=>	rec[gSeqNo].KAMOKU_NM
							,l_inItem016	=>	rec[gSeqNo].KOZA_NO
							,l_inItem017	=>	rec[gSeqNo].TANPO_KBN
							,l_inItem018	=>	rec[gSeqNo].ALL_TESU_KNGK
							,l_inItem019	=>	rec[gSeqNo].ALL_TESU_SZEI
							,l_inItem020	=>	rec[gSeqNo].OWN_TESU_KNGK
							,l_inItem021	=>	rec[gSeqNo].OWN_TESU_SZEI
							,l_inItem022	=>	NULL
							,l_inItem023	=>	NULL
							,l_inItem024	=>	NULL
							,l_inItem025	=>	NULL
							,l_inItem026	=>	NULL
							,l_inItem027	=>	NULL
							,l_inItem028	=>	NULL
							,l_inItem029	=>	NULL
							,l_inItem030	=>	rec[gSeqNo].TSUKA_CD
							,l_inItem031	=>	rec[gSeqNo].TSUKA_NM
							,l_inItem032	=>	gTukaFormat
							,l_inItem033	=>	rec[gSeqNo].INPUT_NUM
							,l_inItem034	=>	l_inGyomuYmd
							,l_inItem035	=>	l_inChohyoId
							,l_inItem036	=>	pkconstant.BATCH_USER()
							,l_inItem037	=>	gInvoiceFlg
						    ,l_inItem038	=>	gBunsho
							,l_inKousinId	=>	pkconstant.BATCH_USER()
							,l_inSakuseiId	=>	pkconstant.BATCH_USER()
						);
						-- 登録件数カウントアップ
						gInsCnt := gInsCnt + 1;
					END IF;
				END IF;
			END IF;
			-- ローカル変数．レコード（ローカル変数．カウンター）．入力順　＞＝　2の場合
			IF rec[gSeqNo].INPUT_NUM >= '2' THEN
				-- ワークデータ作成
				CALL pkPrint.insertData(
					l_inKeyCd	=>	l_inItakuKaishaCd
					,l_inUserId	=>	pkconstant.BATCH_USER()
					,l_inChohyoKbn	=>	'1'
					,l_inSakuseiYmd	=>	l_inGyomuYmd
					,l_inChohyoId	=>	l_inChohyoId
					,l_inSeqNo	=>	gInsCnt
					,l_inHeaderFlg	=>	'1'
					,l_inItem001	=>	l_inItakuKaishaCd
					,l_inItem002	=>	l_inBankRnm
					,l_inItem003	=>	rec[gSeqNo].KYOTEN_KBN
					,l_inItem004	=>	rec[gSeqNo].KYOTEN_KBN_NM
					,l_inItem005	=>	rec[gSeqNo].KOZA_FURI_KBN
					,l_inItem006	=>	rec[gSeqNo].KOZA_FURI_KBN_NM
					,l_inItem007	=>	rec[gSeqNo].CHOKYU_YMD
					,l_inItem008	=>	rec[gSeqNo].HKT_RNM
					,l_inItem009	=>	rec[gSeqNo].MGR_RNM
					,l_inItem010	=>	rec[gSeqNo].ISIN_CD
					,l_inItem011	=>	rec[gSeqNo].KOZA_TEN_CD
					,l_inItem012	=>	rec[gSeqNo].KOZA_TEN_CIFCD
					,l_inItem013	=>	rec[gSeqNo].HKT_CD
					,l_inItem014	=>	rec[gSeqNo].KOZA_TEN_CD2
					,l_inItem015	=>	rec[gSeqNo].KAMOKU_NM
					,l_inItem016	=>	rec[gSeqNo].KOZA_NO
					,l_inItem017	=>	rec[gSeqNo].TANPO_KBN
					,l_inItem018	=>	rec[gSeqNo].ALL_TESU_KNGK
					,l_inItem019	=>	rec[gSeqNo].ALL_TESU_SZEI
					,l_inItem020	=>	rec[gSeqNo].OWN_TESU_KNGK
					,l_inItem021	=>	rec[gSeqNo].OWN_TESU_SZEI
					,l_inItem022	=>	rec[gSeqNo].OTHER_TESU_KNGK
					,l_inItem023	=>	rec[gSeqNo].OTHER_TESU_SZEI
					,l_inItem024	=>	Substr(rec[gSeqNo].BANK_RNM,1,5)
					,l_inItem025	=>	Substr(rec[gSeqNo].BANK_RNM,6,5)
					,l_inItem026	=>	rec[gSeqNo].DF_BUNSHI
					,l_inItem027	=>	rec[gSeqNo].DF_BUNBO
					,l_inItem028	=>	rec[gSeqNo].DF_TESU_KNGK
					,l_inItem029	=>	rec[gSeqNo].DF_TESU_SZEI
					,l_inItem030	=>	rec[gSeqNo].TSUKA_CD
					,l_inItem031	=>	rec[gSeqNo].TSUKA_NM
					,l_inItem032	=>	gTukaFormat
					,l_inItem033	=>	rec[gSeqNo].INPUT_NUM
					,l_inItem034	=>	l_inGyomuYmd
					,l_inItem035	=>	l_inChohyoId
					,l_inItem036	=>	pkconstant.BATCH_USER()
					,l_inItem037	=>	gInvoiceFlg
					,l_inItem038	=>	gBunsho
					,l_inKousinId	=>	pkconstant.BATCH_USER()
					,l_inSakuseiId	=>	pkconstant.BATCH_USER()
				);
				-- 登録件数カウントアップ
				gInsCnt := gInsCnt + 1;
			END IF;
		-- レコード数分ループの終了
		END LOOP;
	END IF;
	-- 終了処理
	l_outSqlCode := pkconstant.success();
	l_outSqlErrM := '';
-- エラー処理
EXCEPTION
  WHEN OTHERS THEN
    CALL pkLog.fatal('ECM701', l_inChohyoId, 'SQLCODE:' || SQLSTATE);
    CALL pkLog.fatal('ECM701', l_inChohyoId, 'SQLERRM:' || SQLERRM);
    l_outSqlCode := pkconstant.FATAL();
    l_outSqlErrM := SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipx055k15r03 (l_inChohyoId TEXT, l_inItakuKaishaCd TEXT, l_inBankRnm text, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;