




CREATE OR REPLACE PROCEDURE spipp004k00r01 ( 
	l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE,     -- 委託会社コード
 l_inUserId SREPORT_WK.USER_ID%TYPE,    -- ユーザーＩＤ
 l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, -- 帳票区分
 l_inMgrCd MGR_KIHON.MGR_CD%TYPE,      -- 銘柄コード
 l_inIsinCd MGR_KIHON.ISIN_CD%TYPE,     -- ＩＳＩＮコード
 l_inKjnYmdFrom MGR_RBRKIJ.RBR_YMD%TYPE,    -- 基準日ＦＲＯＭ
 l_inKjnYmdTo MGR_RBRKIJ.RBR_YMD%TYPE,    -- 基準日ＴＯ
 l_inTsuchiYmd text,                   -- 通知日
 l_outSqlCode OUT integer,                     -- リターン値
 l_outSqlErrM OUT text                    -- エラーコメント
 ) AS $body$
DECLARE

--
-- * 著作権:Copyright(c)2007
-- * 会社名:JIP
-- *
-- * 概要　:振込案内（実質記番号管理）
-- *
-- * 引数　:
-- *        l_inItakuKaishaCd :委託会社コード
-- *        l_inUserId        :ユーザーID
-- *        l_inChohyoKbn     :帳票区分
-- *        l_inMgrCd         :銘柄コード
-- *        l_inIsinCd        :ＩＳＩＮコード
-- *        l_inKjnYmdFrom    :基準日ＦＲＯＭ
-- *        l_inKjnYmdTo      :基準日ＴＯ
-- *        l_inTsuchiYmd     :通知日
-- *        l_outSqlCode      :リターン値
-- *        l_outSqlErrM      :エラーコメント
-- *
-- * 返り値:なし
-- *
-- * @author ASK
-- * @version $Id: SPIPP004K00R01.sql,v 1.10 2020/09/25 07:58:39 otsuka Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付   開発者名        目的
-- * -------------------------------------------------------------------------
-- * 　2007.06.14  叶（ASK）       新規作成
-- * 　2007.08.07  JIP             利払情報追加
-- * 　2007.08.28  JIP             IP-05595対応
-- * 　2007.09.10  JIP             IP-05622対応
-- ***************************************************************************
--	/*==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_REPORT_ID      CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IPP30000411';    -- 帳票ＩＤ
	C_PROGRAM_ID     CONSTANT varchar(50)              := 'SPIPP004K00R01'; -- プログラムＩＤ
	C_KOZATEN_TITLE  CONSTANT varchar(6)               := '口座店';         -- 口座タイトル
	C_KOZANO_TITLE   CONSTANT varchar(8)               := '口座番号';       -- 口座番号タイトル
	C_MEIGININ_TITLE CONSTANT varchar(6)               := '名義人';         -- 口座名義人タイトル
	C_BLANK          CONSTANT char(1)                   := ' ';              -- ブランク
	C_NO_DATA        CONSTANT integer                   := 2;                -- 対象データなし
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	gSeqNo             integer;                                  -- シーケンス
	gSeqStart          integer;                                  -- シーケンス開始
	gSeqEnd            integer;                                  -- シーケンス終了
	gWTsuchiYmd        varchar(16);                            -- 通知日（西暦）
	gBankNm            VJIKO_ITAKU.BANK_NM%TYPE;                -- 金融機関名称
	gGyomuYmd          SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;       -- 業務日付
	gMgrFlg            MPROCESS_CTL.CTL_VALUE%TYPE;             -- 銘柄名称制御フラグ取得（'0'：略称 '1'：正式）
	gKozatenTitle      varchar(6);                             -- 口座店タイトル
	gKBankNm           MBANK.BANK_NM%TYPE;                      -- 口座店名称（銀行名称）
	gKShitenNm         MBANK_SHITEN.SHITEN_NM%TYPE;             -- 口座店名称（支店名称）
	gMeigininTitle     varchar(6);                             -- 口座名義人タイトル
	gMeigininNm        KBG_MTORISAKI.KBG_KOZA_MEIGININ_NM%TYPE; -- 口座名義人
	gSumGankingk       numeric;                                  -- 元金額（合計）
	gSumZeihikiBefKngk numeric;                                  -- 税引前利金額（合計）
	gSumKokuZeiKingk   numeric;                                  -- 国税（合計）
	gSumChihoZeiKngk   numeric;                                  -- 地方税（合計）
	gSumZeihikiAftKngk numeric;                                  -- 税引後利金額（合計）
	gChihoZeiKngk      varchar(16);                            -- 地方税（法人個人区分が１：法人の場合は−）
	gSumChihoZeiKngkH  varchar(16);                            -- 地方税（法人個人区分が１：法人の場合は−）
	-- 読込データ
	gItakuKaishaCd    KBG_SHOKBG.ITAKU_KAISHA_CD%TYPE;          -- 委託会社コード
	gMgrCd            KBG_SHOKBG.MGR_CD%TYPE;                   -- 銘柄コード
	gKenshuCd         KBG_SHOKBG.KENSHU_CD%TYPE;                -- 券種コード
	gKibangoFrom      KBG_SHOKBG.KIBANGO_FROM%TYPE;             -- 記番号ＦＲＯＭ
	gKibangoTo        KBG_SHOKBG.KIBANGO_TO%TYPE;               -- 記番号ＴＯ
	gWkcTaxDays       KBG_SHOKBG.WKC_TAX_DAYS%TYPE;             -- 分かち課税日数
	gTrhkCd           KBG_SHOKBG.TRHK_CD%TYPE;                  -- 取引先コード
	gPostNo           KBG_MTORISAKI.POST_NO%TYPE;               -- 郵便番号
	gTrhkAdd1         KBG_MTORISAKI.TRHK_ADD1%TYPE;             -- 送付先住所１
	gTrhkAdd2         KBG_MTORISAKI.TRHK_ADD2%TYPE;             -- 送付先住所２
	gTrhkAdd3         KBG_MTORISAKI.TRHK_ADD3%TYPE;             -- 送付先住所３
	gTrhkNm1          KBG_MTORISAKI.TRHK_NM1%TYPE;              -- 取引先名称１
	gTrhkNm2          KBG_MTORISAKI.TRHK_NM2%TYPE;              -- 取引先名称２
	gTrhkNm3          KBG_MTORISAKI.TRHK_NM3%TYPE;              -- 取引先名称３
	gGnrkKessaiMethod KBG_MTORISAKI.GNRK_KESSAI_METHOD%TYPE;    -- 元利金決済方法区分
	gTrhkZokusei      KBG_MTORISAKI.TRHK_ZOKUSEI%TYPE;          -- 取引先属性
	gCorpIndKbn       KBG_MTORISAKI.CORPORATION_INDIVIDUAL_KBN%TYPE;   -- 法人個人区分
	gRbrkjt           MGR_RBRKIJ.RBR_KJT%TYPE;                  -- 利払期日
	gRbrYmd           MGR_RBRKIJ.RBR_YMD%TYPE;                  -- 利払日
	gIsinCd           MGR_KIHON_VIEW.ISIN_CD%TYPE;              -- ＩＳＩＮコード
	gMgrNm            MGR_KIHON.MGR_NM%TYPE;                    -- 銘柄の正式名称
	gMgrRnm           MGR_KIHON.MGR_RNM%TYPE;                   -- 銘柄略称
	gRiritsu          MGR_KIHON.RIRITSU%TYPE;                   -- 利率
	gKozaKamokuNm     SCODE.CODE_NM%TYPE;                       -- 口座科目名称
	gKbgKozaNo        KBG_MTORISAKI.KBG_KOZA_NO%TYPE;           -- 口座番号
	gToyoKozaNo       KBG_MTORISAKI.BOJ_TOYO_KOZA_NO%TYPE;      -- 日銀当預口座番号  -- 2007/09/10 ADD JIP
	gGankingk         numeric;                                   -- 元金額
	-- ブレイク確認用変数
	gBreakRbrYmd      MGR_RBRKIJ.RBR_YMD%TYPE;                  -- 利払日
	gBreakTrhkCd      KBG_SHOKBG.TRHK_CD%TYPE;                  -- 取引先コード
	gBreakMgrCd       KBG_SHOKBG.MGR_CD%TYPE;                   -- 銘柄コード
	-- Local variables from nested procedures
	pWRbrYmd        varchar(16);            -- 利払日（西暦）
	pAtenaNm        varchar(200);           -- 宛名（「御中」付き）
	pPatternCd      BUN.BUN_PATTERN_CD%TYPE; -- パターンコード（請求文章取得用）
	pBun            varchar(2000);          -- 請求文章
	gProMgrNm       MGR_KIHON.MGR_NM%TYPE;   -- 銘柄名称（正式 OR 略称）（編集用）
	pGanriZandaka   numeric;                  -- 元利払対象残高
	pProKenshuCd    numeric;                  -- 券種コード（編集用）
	pHosokuBunsho   varchar(100);            -- 補足説明文章
	pRetNo          integer;                 -- 戻り値（取引先別税額取得用）
	pSqlErrM        varchar(1000);           -- エラーコメント（取引先別税額取得用）
	pZeihikiBefKngk numeric;                  -- 税引前利金額
	pKokuZeiKingk   numeric;                  -- 国税
	pChihoZeiKngk   numeric;                  -- 地方税
	pZeihikiAftKngk numeric;                  -- 税引後利金額
	pZenRbrYmd      MGR_RBRKIJ.RBR_YMD%TYPE; -- 残高基準日（利払日の前日）
	pZeiErrFlg      char(1);                 -- 税計算エラーフラグ（'0':正常、'1':エラー）
	pKozaNo         char(7);                 -- 口座番号
	v_item          type_sreport_wk_item;    -- Composite type for pkPrint.insertData
	--==============================================================================
	--                  カーソル定義                                                    
	--==============================================================================
	--  2007/08/28  EDIT  JIP
	curMeisai CURSOR FOR
		SELECT  WK1.ITAKU_KAISHA_CD,                            -- 委託会社コード
				WK1.MGR_CD,                                     -- 銘柄コード
				coalesce(WK2.KENSHU_CD,    0)    as KENSHU_CD,       -- 券種コード
				coalesce(WK2.KIBANGO_FROM, 0)    as KIBANGO_FROM,    -- 記番号ＦＲＯＭ
				coalesce(WK2.KIBANGO_TO,   0)    as KIBANGO_TO,      -- 記番号ＴＯ
				WK1.WKC_TAX_DAYS,                               -- 分かち課税日数
				WK1.TRHK_CD,                                    -- 取引先コード
				P05.POST_NO,                                    -- 郵便番号
				P05.TRHK_ADD1,                                  -- 送付先住所１
				P05.TRHK_ADD2,                                  -- 送付先住所２
				P05.TRHK_ADD3,                                  -- 送付先住所３
				P05.TRHK_NM1,                                   -- 取引先名称１
				P05.TRHK_NM2,                                   -- 取引先名称２
				P05.TRHK_NM3,                                   -- 取引先名称３
				P05.GNRK_KESSAI_METHOD,                         -- 元利金決済方法区分
				P05.TRHK_ZOKUSEI,                               -- 取引先属性
				P05.KBG_KOZA_NO,                                -- 口座番号
				P05.BOJ_TOYO_KOZA_NO,                           -- 日銀当預口座番号  -- 2007/09/10 ADD JIP
				P05.KBG_KOZA_MEIGININ_NM,                       -- 記番号_口座名義人
				P05.CORPORATION_INDIVIDUAL_KBN,                 -- 法人個人区分
				WK1.RBR_KJT,                                    -- 利払期日
				WK1.RBR_YMD,                                    -- 利払日
				VMG1.ISIN_CD,                                   -- ＩＳＩＮコード
				VMG1.MGR_NM,                                    -- 銘柄の正式名称
				VMG1.MGR_RNM,                                   -- 銘柄略称
				VMG1.RIRITSU,                                   -- 利率
				(   SELECT  M02.BANK_NM
					FROM    MBANK M02
					WHERE   FINANCIAL_SECURITIES_KBN = '0'
					AND     M02.BANK_CD = P05.BANK_CD
				)   AS      BANK_NM,                            -- 口座名称（銀行名）
				(   SELECT  M03.SHITEN_NM
					FROM    MBANK_SHITEN M03
					WHERE   FINANCIAL_SECURITIES_KBN = '0'
					AND     M03.BANK_CD   = P05.BANK_CD
					AND     M03.SHITEN_CD = P05.SHITEN_CD
				)   AS      SHITEN_NM,                          -- 口座名称（支店名）
				(   SELECT  CODE_NM
					FROM    SCODE
					WHERE   CODE_SHUBETSU = '707'
					AND     CODE_VALUE    = P05.KOZA_KAMOKU
				)   AS      KOZA_KAMOKU_NM,                     -- 口座科目名称
				pkIpaKibango.getGankinTrhk(
					WK1.ITAKU_KAISHA_CD,
					WK1.MGR_CD,
					WK1.RBR_YMD,
					WK1.TRHK_CD
				)   AS  GANKINGAKU                               -- 元金額
		FROM mgr_kihon_view vmg1, kbg_mtorisaki p05, (   --  利払情報
					SELECT  B02.ITAKU_KAISHA_CD,
							B02.MGR_CD,
							B02.TRHK_CD,
							B02.WKC_TAX_DAYS,
							MG2_1.RBR_YMD,
							MG2_1.RBR_KJT
					FROM    KBG_SHOKBG B02,
							KBG_SHOKIJ B01,
							(   SELECT  MG2.*
								FROM    MGR_RBRKIJ MG2,
										GENSAI_RIREKI Z01
											
								WHERE   (   (l_inChohyoKbn = '0' AND MG2.RBR_YMD BETWEEN l_inKjnYmdFrom AND l_inKjnYmdTo) OR (l_inChohyoKbn = '1' AND MG2.RBR_KJT BETWEEN l_inKjnYmdFrom AND l_inKjnYmdTo)
										)
										AND MG2.ITAKU_KAISHA_CD = Z01.ITAKU_KAISHA_CD 	-- 減債履歴との結合条件は、「特例債のみ」「記番号は振替移行1回のみ」
										AND MG2.MGR_CD = Z01.MGR_CD 						-- という制約に基づくため、この4項目でOK。
										AND MG2.RBR_YMD > Z01.SHOKAN_YMD 	-- 利払日が振替移行日より前の利払情報は出力しない。
										AND Z01.SHOKAN_KBN = '01'			-- (振替移行より利払の処理が先になるので、振替移行日当日も出力しない)
							)   MG2_1
					WHERE   B02.ITAKU_KAISHA_CD = B01.ITAKU_KAISHA_CD
					AND     B02.ITAKU_KAISHA_CD = MG2_1.ITAKU_KAISHA_CD
					AND     B02.ITAKU_KAISHA_CD = l_inItakuKaishaCd
					AND     B02.MGR_CD          = B01.MGR_CD
					AND     B02.MGR_CD          = MG2_1.MGR_CD
					AND (   --  償還期日が未決定の記番号債券も含めたすべての未償還債券が対象
							(   B01.SHOKAN_YMD    >= MG2_1.RBR_YMD      AND 
								B02.SHOKAN_KJT     = B01.SHOKAN_KJT     AND 
								B02.KBG_SHOKAN_KBN = B01.KBG_SHOKAN_KBN
							) 
							OR (coalesce(trim(both B02.SHOKAN_KJT)::text, '') = '')
						)
					AND (coalesce(trim(both l_inMgrCd)::text, '') = ''  OR  B02.MGR_CD = l_inMgrCd) 
					GROUP BY
							B02.ITAKU_KAISHA_CD,
							B02.MGR_CD,
							B02.TRHK_CD,
							B02.WKC_TAX_DAYS,
							MG2_1.RBR_YMD,
                			MG2_1.RBR_KJT
				) wk1
LEFT OUTER JOIN (   --  償還情報
					SELECT  B02.ITAKU_KAISHA_CD,
							B02.MGR_CD,
							B02.TRHK_CD,
							B01.SHOKAN_YMD,
							B01.SHOKAN_KJT,
							B02.KENSHU_CD,
							B02.KIBANGO_FROM,
							B02.KIBANGO_TO,
							B02.WKC_TAX_DAYS
					FROM    KBG_SHOKBG  B02,
							KBG_SHOKIJ  B01
					WHERE   B02.ITAKU_KAISHA_CD = B01.ITAKU_KAISHA_CD
					AND     B02.ITAKU_KAISHA_CD = l_inItakuKaishaCd
					AND     B02.MGR_CD          = B01.MGR_CD
					AND     B02.SHOKAN_KJT      = B01.SHOKAN_KJT
					AND     B02.KBG_SHOKAN_KBN  = B01.KBG_SHOKAN_KBN
					AND     B01.KBG_SHOKAN_KBN != '62'
					AND     B01.KBG_SHOKAN_KBN != '63'
					AND (coalesce(trim(both l_inMgrCd)::text, '') = ''  OR  B02.MGR_CD = l_inMgrCd)
								--  出力区分（リアル／バッチ）により参照項目が変化
					AND     (   (l_inChohyoKbn = '0' AND B01.SHOKAN_YMD BETWEEN l_inKjnYmdFrom AND l_inKjnYmdTo) OR (l_inChohyoKbn = '1' AND B01.SHOKAN_KJT BETWEEN l_inKjnYmdFrom AND l_inKjnYmdTo)
						    ) 
				) wk2 ON (WK1.ITAKU_KAISHA_CD = WK2.ITAKU_KAISHA_CD AND WK1.RBR_KJT = WK2.SHOKAN_KJT AND WK1.MGR_CD = WK2.MGR_CD AND WK1.TRHK_CD = WK2.TRHK_CD AND WK1.WKC_TAX_DAYS = WK2.WKC_TAX_DAYS)
WHERE WK1.ITAKU_KAISHA_CD = P05.ITAKU_KAISHA_CD AND WK1.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD   AND WK1.MGR_CD          = VMG1.MGR_CD  AND WK1.TRHK_CD         = P05.TRHK_CD  AND VMG1.MGR_STAT_KBN   = '1' AND VMG1.KK_KANYO_FLG   = '2' AND (coalesce(trim(both l_inMgrCd)::text, '') = ''  OR  WK1.MGR_CD   = l_inMgrCd ) AND (coalesce(trim(both l_inIsinCd)::text, '') = ''  OR  VMG1.ISIN_CD = l_inIsinCd) AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '') AND P05.GNRK_KESSAI_METHOD IN ('1', '2') ORDER BY
				GNRK_KESSAI_METHOD,
				RBR_YMD,
				TRHK_CD,
				ISIN_CD,
				CASE WHEN KENSHU_CD=0 THEN  10000000000  ELSE KENSHU_CD END , --  償還情報、利払情報の順に出力
				CASE WHEN KIBANGO_FROM=0 THEN  10000000  ELSE KIBANGO_FROM END , --  償還情報、利払情報の順に出力
				WKC_TAX_DAYS;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 入力パラメータチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inUserId)::text, '') = ''
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''
	OR coalesce(trim(both l_inKjnYmdFrom)::text, '') = ''
	OR coalesce(trim(both l_inKjnYmdTo)::text, '') = ''
	THEN
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := 'パラメータエラー';
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, l_outSqlErrM);
		RETURN;
	END IF;
	-- 通知日の西暦変換
	gWTsuchiYmd := '      年  月  日';
	IF (trim(both l_inTsuchiYmd) IS NOT NULL AND (trim(both l_inTsuchiYmd))::text <> '') THEN
		gWTsuchiYmd := pkDate.seirekiChangeSuppressNenGappi(l_inTsuchiYmd);
	END IF;
	-- 自行・委託会社マスタ情報取得
	BEGIN
		SELECT
			BANK_NM  -- 金融機関名称
		INTO
			gBankNm
		FROM
			VJIKO_ITAKU
		WHERE
			KAIIN_ID = l_inItakuKaishaCd;
	EXCEPTION
		WHEN no_data_found THEN
			l_outSqlCode := pkconstant.FATAL();
			l_outSqlErrM := '自行・委託会社マスタ情報取得エラー';
			CALL pkLog.fatal('ECM701', C_PROGRAM_ID, l_outSqlErrM);
			RETURN;
	END;
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
	-- 処理制御マスタから銘柄名称制御フラグ取得
	gMgrFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'getMgrNm01', '0');
	-- 帳票ワーク削除
	DELETE FROM SREPORT_WK
	WHERE
		KEY_CD = l_inItakuKaishaCd      -- 識別コード
		AND USER_ID = l_inUserId        -- ユーザーＩＤ
		AND CHOHYO_KBN = l_inChohyoKbn  -- 帳票区分
		AND SAKUSEI_YMD = gGyomuYmd     -- 作成日付
		AND CHOHYO_ID = C_REPORT_ID;   -- 帳票ＩＤ
	-- 変数初期化
	gItakuKaishaCd     := C_BLANK; -- 委託会社コード（読込データ）
	gBreakRbrYmd       := C_BLANK; -- 元利払日（ブレイク確認用）
	gBreakTrhkCd       := C_BLANK; -- 取引先コード（ブレイク確認用）
	gBreakMgrCd        := C_BLANK; -- 銘柄コード（ブレイク確認用）
	gSeqNo             := 1;       -- シーケンス初期化
	gSeqStart          := 0;       -- シーケンス開始（更新用Ａ）
	gSeqEnd            := 0;       -- シーケンス終了（更新用Ａ）
	gSumGankingk       := 0;       -- 元金額（合計）
	gSumZeihikiBefKngk := 0;       -- 税引前利金額（合計）
	gSumKokuZeiKingk   := 0;       -- 国税（合計）
	gSumChihoZeiKngk   := 0;       -- 地方税（合計）
	gSumZeihikiAftKngk := 0;       -- 税引後利金額（合計）
	-- データ読込
	FOR recMeisai IN curMeisai
	LOOP
		-- 初回時
		IF gItakuKaishaCd = C_BLANK THEN
			gItakuKaishaCd := recMeisai.ITAKU_KAISHA_CD;              -- 委託会社コード
			gPostNo := recMeisai.POST_NO;                             -- 郵便番号
			gTrhkAdd1 := recMeisai.TRHK_ADD1;                         -- 送付先住所１
			gTrhkAdd2 := recMeisai.TRHK_ADD2;                         -- 送付先住所２
			gTrhkAdd3 := recMeisai.TRHK_ADD3;                         -- 送付先住所３
			gTrhkNm1 := recMeisai.TRHK_NM1;                           -- 取引先名称１
			gTrhkNm2 := recMeisai.TRHK_NM2;                           -- 取引先名称２
			gTrhkNm3 := recMeisai.TRHK_NM3;                           -- 取引先名称３
			gTrhkCd := recMeisai.TRHK_CD;                             -- 取引先コード
			gTrhkZokusei := recMeisai.TRHK_ZOKUSEI;                   -- 取引先属性
			gGnrkKessaiMethod := recMeisai.GNRK_KESSAI_METHOD;        -- 元利金決済方法区分
			gCorpIndKbn := recMeisai.CORPORATION_INDIVIDUAL_KBN;       -- 法人個人区分
			gRbrYmd := recMeisai.RBR_YMD;                             -- 元利払日
			gRbrkjt := recMeisai.RBR_KJT;                             -- 利払期日
			-- 「振込」の時
			IF gGnrkKessaiMethod = '1' THEN
				gKozatenTitle := C_KOZATEN_TITLE;                     -- 口座名称タイトル
				gKBankNm := recMeisai.BANK_NM;                        -- 口座店名称（銀行名称）
				gKShitenNm := recMeisai.SHITEN_NM;                    -- 口座店名称（支店名称）
				gKozaKamokuNm := recMeisai.KOZA_KAMOKU_NM;            -- 口座科目名称
				gMeigininTitle := C_MEIGININ_TITLE;                   -- 口座名義人タイトル
				gMeigininNm := recMeisai.KBG_KOZA_MEIGININ_NM;        -- 記番号_口座名義人
				gKbgKozaNo := recMeisai.KBG_KOZA_NO;                  -- 口座番号  -- 2007/09/10 EDIT JIP
			-- 「日銀ネット」の時
			ELSE
				gKozatenTitle := C_BLANK;                             -- 口座名称タイトル
				gKBankNm := C_BLANK;                                  -- 口座店名称（銀行名称）
				gKShitenNm := C_BLANK;                                -- 口座店名称（支店名称）
				gKozaKamokuNm := C_BLANK;                             -- 口座科目名称
				gMeigininTitle := C_BLANK;                            -- 口座名義人タイトル
				gMeigininNm := C_BLANK;                               -- 記番号_口座名義人
				gToyoKozaNo := recMeisai.BOJ_TOYO_KOZA_NO;            -- 日銀当預口座番号  -- 2007/09/10 ADD JIP
			END IF;
			gMgrCd := recMeisai.MGR_CD;                               -- 銘柄コード
			gMgrNm := recMeisai.MGR_NM;                               -- 銘柄の正式名称
			gMgrRnm := recMeisai.MGR_RNM;                             -- 銘柄略称
			gIsinCd := recMeisai.ISIN_CD;                             -- ＩＳＩＮコード
			gRiritsu := recMeisai.RIRITSU;                            -- 利率
			gKenshuCd := recMeisai.KENSHU_CD;                         -- 券種コード
			gKibangoFrom := recMeisai.KIBANGO_FROM;                   -- 記番号ＦＲＯＭ
			gKibangoTo := recMeisai.KIBANGO_TO;                       -- 記番号ＴＯ
			gWkcTaxDays := recMeisai.WKC_TAX_DAYS;                    -- 分かち課税日数
			gGankingk := recMeisai.GANKINGAKU;                        -- 元金額
		-- 初回でない時
		ELSE
			-- 「元利払日」、「取引先コード」、「銘柄コード」、
			-- 「券種コード」、「分かち課税日数」、「記番号ＦＲＯＭ」が１データ前の「記番号ＴＯ」+ 1 の時
			IF  gRbrYmd                = recMeisai.RBR_YMD
			AND gTrhkCd                = recMeisai.TRHK_CD
			AND gMgrCd                 = recMeisai.MGR_CD
			AND gKenshuCd              = recMeisai.KENSHU_CD
			AND gWkcTaxDays            = recMeisai.WKC_TAX_DAYS
			AND recMeisai.KIBANGO_FROM = (gKibangoTo + 1) THEN
				-- 変数再セット「記番号ＴＯ」
				gKibangoTo := recMeisai.KIBANGO_TO;
			--  2007/08/28  ADD  JIP
			--  償還対象および償還対象外の記番号債券が混在する場合、直前のレコードと
			--  元利金決済方法、取引先、利払日、銘柄が同一で償還対象外である記番号債券は出力対象外とする
			ELSIF   (
						(gGnrkKessaiMethod = recMeisai.GNRK_KESSAI_METHOD)
					AND (gTrhkCd           = recMeisai.TRHK_CD) 
					AND (gRbrYmd           = recMeisai.RBR_YMD) 
					AND (gMgrCd            = recMeisai.MGR_CD ) 
					AND (recMeisai.KENSHU_CD    = 0 ) 
					AND (recMeisai.KIBANGO_FROM = 0 ) 
					AND (recMeisai.KIBANGO_TO   = 0 ) 
					AND (recMeisai.WKC_TAX_DAYS = 0 )
					)
			THEN
				NULL;
			--  2007/08/28  ADD  JIP
			ELSE
				-- 登録前編集 ＋ 帳票ワーク登録処理
				-- Inlined: SPIPP004K00R01_insertData (BEGIN)
				pWRbrYmd := pkDate.seirekiChangeSuppressNenGappi(gRbrYmd);
				pAtenaNm := pkIpaKibango.getMadoFutoAtenaYoko(gTrhkNm1, gTrhkNm2, gTrhkNm3);
				IF gGnrkKessaiMethod = '1' THEN
					pPatternCd := '01';
				ELSE
					pPatternCd := '02';
				END IF;
				pBun := SPIPP004K00R01_createBun(C_REPORT_ID, pPatternCd);
				IF gMgrFlg = '1' THEN
					gProMgrNm := SUBSTR(gMgrNm, 1, 50);
				ELSE
					gProMgrNm := gMgrRnm;
				END IF;
				IF ( gGnrkKessaiMethod = '1' ) THEN
					pKozaNo := gKbgKozaNo;
				ELSE
					pKozaNo := gToyoKozaNo;
				END IF;
				pZenRbrYmd := pkDate.getMinusDate(gRbrYmd, 1);
				pGanriZandaka := pkIpaKibango.getKjnZndkTrhk(l_inItakuKaishaCd, gMgrCd, pZenRbrYmd, gTrhkCd);
				pProKenshuCd := gKenshuCd / 1000;
				pZeiErrFlg := '0';
				pRetNo := pkIpaKibango.calcZeigaku(
												gItakuKaishaCd,
												gMgrCd,
												gRbrkjt,
												pZenRbrYmd,
												gTrhkCd,
												pZeihikiBefKngk,
												pZeihikiAftKngk,
												pKokuZeiKingk,
												pChihoZeiKngk,
												pSqlErrM
											);
				IF pRetNo != pkconstant.success() THEN
					pZeihikiBefKngk := 0;
					pKokuZeiKingk   := 0;
					pChihoZeiKngk   := 0;
					pZeihikiAftKngk := 0;
					CALL pkLog.error(
						'EIP475', C_PROGRAM_ID,
						'委託会社:"' || l_inItakuKaishaCd || '"' || 
						' 取引先:"'  || gTrhkCd           || '"' || 
						' 利払日:"'  || gRbrYmd           || '"' || 
						' 銘柄:"'    || gMgrCd            || '"' );
					pZeiErrFlg := '1';
				END IF;
				IF gTrhkZokusei NOT IN ('1', '2') OR gCorpIndKbn = '1' THEN
					pChihoZeiKngk := NULL;
					pHosokuBunsho := '＊ 計算式 : (e) = (b) - (c)';
				ELSE
					pHosokuBunsho := '＊ 計算式 : (e) = (b) - (c) - (d)';
				END IF;
				IF gSeqNo != 1
				AND (
					gBreakRbrYmd != gRbrYmd
					OR gBreakTrhkCd != gTrhkCd
				) THEN
					-- Inlined: SPIPP004K00R01_updateWork
					gSeqStart := gSeqEnd + 1;
					gSeqEnd := gSeqNo - 1;
					UPDATE SREPORT_WK SET
						ITEM034 = gSumGankingk::text,
						ITEM035 = gSumZeihikiBefKngk::text,
						ITEM036 = gSumKokuZeiKingk::text,
						ITEM037 = gSumChihoZeiKngkH::text,
						ITEM038 = gSumZeihikiAftKngk::text,
						ITEM040 = (gSumGankingk + gSumZeihikiAftKngk)::text,
						ITEM028 = coalesce(ITEM028, ' ')
					WHERE
						KEY_CD = l_inItakuKaishaCd
						AND USER_ID = l_inUserId
						AND CHOHYO_KBN = l_inChohyoKbn
						AND SAKUSEI_YMD = gGyomuYmd
						AND CHOHYO_ID = C_REPORT_ID
						AND SEQ_NO BETWEEN gSeqStart AND gSeqEnd;
					gSumGankingk := gGankingk;
					gSumZeihikiBefKngk := pZeihikiBefKngk;
					gSumKokuZeiKingk := pKokuZeiKingk;
					gSumChihoZeiKngk := pChihoZeiKngk;
					gSumZeihikiAftKngk := pZeihikiAftKngk;
					IF gCorpIndKbn = '1' THEN
						gSumChihoZeiKngkH := '−';
					ELSE
						gSumChihoZeiKngkH := gSumChihoZeiKngk;
					END IF;
				ELSE
					IF gBreakMgrCd != gMgrCd THEN
						gSumGankingk := gSumGankingk + gGankingk;
						gSumZeihikiBefKngk := gSumZeihikiBefKngk + pZeihikiBefKngk;
						gSumKokuZeiKingk := gSumKokuZeiKingk + pKokuZeiKingk;
						IF coalesce(pChihoZeiKngk::text, '') = '' THEN
							gSumChihoZeiKngk := NULL;
						ELSE
							gSumChihoZeiKngk := gSumChihoZeiKngk + pChihoZeiKngk;
						END IF;
						gSumZeihikiAftKngk := gSumZeihikiAftKngk + pZeihikiAftKngk;
						IF gCorpIndKbn = '1' THEN
							gSumChihoZeiKngkH := '−';
						ELSE
							gSumChihoZeiKngkH := gSumChihoZeiKngk;
						END IF;
					END IF;
				END IF;
				IF gCorpIndKbn = '1' THEN
					gChihoZeiKngk := '−';
				ELSE
					gChihoZeiKngk := pChihoZeiKngk;
				END IF;
				v_item.l_inItem001 := gWTsuchiYmd;
				v_item.l_inItem002 := gPostNo;
				v_item.l_inItem003 := gTrhkAdd1;
				v_item.l_inItem004 := gTrhkAdd2;
				v_item.l_inItem005 := gTrhkAdd3;
				v_item.l_inItem006 := gTrhkCd;
				v_item.l_inItem007 := gGnrkKessaiMethod;
				v_item.l_inItem008 := gTrhkZokusei;
				v_item.l_inItem009 := pAtenaNm;
				v_item.l_inItem010 := gBankNm;
				v_item.l_inItem011 := pBun;
				v_item.l_inItem012 := pWRbrYmd;
				v_item.l_inItem013 := gKozatenTitle;
				v_item.l_inItem014 := gKBankNm;
				v_item.l_inItem015 := gKShitenNm;
				v_item.l_inItem016 := C_KOZANO_TITLE;
				v_item.l_inItem017 := gKozaKamokuNm;
				v_item.l_inItem018 := pKozaNo;
				v_item.l_inItem019 := gMeigininTitle;
				v_item.l_inItem020 := gMeigininNm;
				v_item.l_inItem021 := gIsinCd;
				v_item.l_inItem022 := gProMgrNm;
				v_item.l_inItem023 := gRiritsu;
				v_item.l_inItem024 := pGanriZandaka;
				v_item.l_inItem025 := gGankingk;
				v_item.l_inItem026 := pZeihikiBefKngk;
				v_item.l_inItem027 := pKokuZeiKingk;
				v_item.l_inItem028 := gChihoZeiKngk;
				v_item.l_inItem029 := pZeihikiAftKngk;
				v_item.l_inItem030 := pProKenshuCd;
				v_item.l_inItem031 := gKibangoFrom;
				v_item.l_inItem032 := gKibangoTo;
				v_item.l_inItem033 := gWkcTaxDays;
				v_item.l_inItem039 := pHosokuBunsho;
				v_item.l_inItem041 := pZeiErrFlg;
				CALL pkPrint.insertData(
					l_inKeyCd      => l_inItakuKaishaCd,
					l_inUserId     => l_inUserId,
					l_inChohyoKbn  => l_inChohyoKbn,
					l_inSakuseiYmd => gGyomuYmd,
					l_inChohyoId   => C_REPORT_ID,
					l_inSeqNo      => gSeqNo::integer,
					l_inHeaderFlg  => '1',
					l_inItem       => v_item,
					l_inKousinId   => l_inUserId,
					l_inSakuseiId  => l_inUserId
				);
				gSeqNo := gSeqNo + 1;
				-- Inlined: SPIPP004K00R01_insertData (END)
				-- ブレイク確認用変数へ格納
				gBreakRbrYmd := gRbrYmd; -- 元利払日
				gBreakTrhkCd := gTrhkCd; -- 取引先コード
				gBreakMgrCd  := gMgrCd;  -- 銘柄コード
				-- 変数セット
				gItakuKaishaCd := recMeisai.ITAKU_KAISHA_CD;              -- 委託会社コード
				gPostNo := recMeisai.POST_NO;                             -- 郵便番号
				gTrhkAdd1 := recMeisai.TRHK_ADD1;                         -- 送付先住所１
				gTrhkAdd2 := recMeisai.TRHK_ADD2;                         -- 送付先住所２
				gTrhkAdd3 := recMeisai.TRHK_ADD3;                         -- 送付先住所３
				gTrhkNm1 := recMeisai.TRHK_NM1;                           -- 取引先名称１
				gTrhkNm2 := recMeisai.TRHK_NM2;                           -- 取引先名称２
				gTrhkNm3 := recMeisai.TRHK_NM3;                           -- 取引先名称３
				gTrhkCd := recMeisai.TRHK_CD;                             -- 取引先コード
				gTrhkZokusei := recMeisai.TRHK_ZOKUSEI;                   -- 取引先属性
				gGnrkKessaiMethod := recMeisai.GNRK_KESSAI_METHOD;        -- 元利金決済方法区分
				gCorpIndKbn := recMeisai.CORPORATION_INDIVIDUAL_KBN;       -- 法人個人区分
				gRbrYmd := recMeisai.RBR_YMD;                             -- 元利払日
				gRbrkjt := recMeisai.RBR_KJT;                             -- 利払期日
				-- 「振込」の時
				IF gGnrkKessaiMethod = '1' THEN
					gKozatenTitle := C_KOZATEN_TITLE;                     -- 口座名称タイトル
					gKBankNm := recMeisai.BANK_NM;                        -- 口座店名称（銀行名称）
					gKShitenNm := recMeisai.SHITEN_NM;                    -- 口座店名称（支店名称）
					gKozaKamokuNm := recMeisai.KOZA_KAMOKU_NM;            -- 口座科目名称
					gMeigininTitle := C_MEIGININ_TITLE;                   -- 口座名義人タイトル
					gMeigininNm := recMeisai.KBG_KOZA_MEIGININ_NM;        -- 記番号_口座名義人
					gKbgKozaNo := recMeisai.KBG_KOZA_NO;                  -- 口座番号  -- 2007/09/10 EDIT JIP
				-- 「日銀ネット」の時
				ELSE
					gKozatenTitle := C_BLANK;                             -- 口座名称タイトル
					gKBankNm := C_BLANK;                                  -- 口座店名称（銀行名称）
					gKShitenNm := C_BLANK;                                -- 口座店名称（支店名称）
					gKozaKamokuNm := C_BLANK;                             -- 口座科目名称
					gMeigininTitle := C_BLANK;                            -- 口座名義人タイトル
					gMeigininNm := C_BLANK;                               -- 記番号_口座名義人
					gToyoKozaNo := recMeisai.BOJ_TOYO_KOZA_NO;            -- 日銀当預口座番号  -- 2007/09/10 ADD JIP
				END IF;
				gMgrCd := recMeisai.MGR_CD;                               -- 銘柄コード
				gMgrNm := recMeisai.MGR_NM;                               -- 銘柄の正式名称
				gMgrRnm := recMeisai.MGR_RNM;                             -- 銘柄略称
				gIsinCd := recMeisai.ISIN_CD;                             -- ＩＳＩＮコード
				gRiritsu := recMeisai.RIRITSU;                            -- 利率
				gKenshuCd := recMeisai.KENSHU_CD;                         -- 券種コード
				gKibangoFrom := recMeisai.KIBANGO_FROM;                   -- 記番号ＦＲＯＭ
				gKibangoTo := recMeisai.KIBANGO_TO;                       -- 記番号ＴＯ
				gWkcTaxDays := recMeisai.WKC_TAX_DAYS;                    -- 分かち課税日数
				gGankingk := recMeisai.GANKINGAKU;                        -- 元金額
			END IF;
		END IF;
	END LOOP;
	-- 最終レコードを処理する
	IF gItakuKaishaCd = C_BLANK THEN
		-- リアルの時
		IF l_inChohyoKbn = '0' THEN
			-- ヘッダレコードを追加
			CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, gGyomuYmd, C_REPORT_ID);
			-- 帳票ワーク登録
			v_item.l_inItem042 := '対象データなし';
			CALL pkPrint.insertData(
				l_inKeyCd      => l_inItakuKaishaCd,
				l_inUserId     => l_inUserId,
				l_inChohyoKbn  => l_inChohyoKbn,
				l_inSakuseiYmd => gGyomuYmd,
				l_inChohyoId   => C_REPORT_ID,
				l_inSeqNo      => gSeqNo::integer,
				l_inHeaderFlg  => '1',
				l_inItem       => v_item,
				l_inKousinId   => l_inUserId,
				l_inSakuseiId  => l_inUserId
			);
			-- 正常終了
			l_outSqlCode := pkconstant.success();
			l_outSqlErrM := '';
		ELSE
			-- 終了（対象データなし）
			l_outSqlCode := C_NO_DATA;
			l_outSqlErrM := '';
		END IF;
	ELSE
		-- ヘッダレコードを追加
		CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, gGyomuYmd, C_REPORT_ID);
		-- データ作成
		-- Inlined: SPIPP004K00R01_insertData (BEGIN)
		pWRbrYmd := pkDate.seirekiChangeSuppressNenGappi(gRbrYmd);
		pAtenaNm := pkIpaKibango.getMadoFutoAtenaYoko(gTrhkNm1, gTrhkNm2, gTrhkNm3);
		IF gGnrkKessaiMethod = '1' THEN
			pPatternCd := '01';
		ELSE
			pPatternCd := '02';
		END IF;
		pBun := SPIPP004K00R01_createBun(C_REPORT_ID, pPatternCd);
		IF gMgrFlg = '1' THEN
			gProMgrNm := SUBSTR(gMgrNm, 1, 50);
		ELSE
			gProMgrNm := gMgrRnm;
		END IF;
		IF ( gGnrkKessaiMethod = '1' ) THEN
			pKozaNo := gKbgKozaNo;
		ELSE
			pKozaNo := gToyoKozaNo;
		END IF;
		pZenRbrYmd := pkDate.getMinusDate(gRbrYmd, 1);
		pGanriZandaka := pkIpaKibango.getKjnZndkTrhk(l_inItakuKaishaCd, gMgrCd, pZenRbrYmd, gTrhkCd);
		pProKenshuCd := gKenshuCd / 1000;
		pZeiErrFlg := '0';
		pRetNo := pkIpaKibango.calcZeigaku(
										gItakuKaishaCd,
										gMgrCd,
										gRbrkjt,
										pZenRbrYmd,
										gTrhkCd,
										pZeihikiBefKngk,
										pZeihikiAftKngk,
										pKokuZeiKingk,
										pChihoZeiKngk,
										pSqlErrM
									);
		IF pRetNo != pkconstant.success() THEN
			pZeihikiBefKngk := 0;
			pKokuZeiKingk   := 0;
			pChihoZeiKngk   := 0;
			pZeihikiAftKngk := 0;
			CALL pkLog.error(
				'EIP475', C_PROGRAM_ID,
				'委託会社:"' || l_inItakuKaishaCd || '"' || 
				' 取引先:"'  || gTrhkCd           || '"' || 
				' 利払日:"'  || gRbrYmd           || '"' || 
				' 銘柄:"'    || gMgrCd            || '"' );
			pZeiErrFlg := '1';
		END IF;
		IF gTrhkZokusei NOT IN ('1', '2') OR gCorpIndKbn = '1' THEN
			pChihoZeiKngk := NULL;
			pHosokuBunsho := '＊ 計算式 : (e) = (b) - (c)';
		ELSE
			pHosokuBunsho := '＊ 計算式 : (e) = (b) - (c) - (d)';
		END IF;
		IF gSeqNo != 1
		AND (
			gBreakRbrYmd != gRbrYmd
			OR gBreakTrhkCd != gTrhkCd
		) THEN
			-- Inlined: SPIPP004K00R01_updateWork
			gSeqStart := gSeqEnd + 1;
			gSeqEnd := gSeqNo - 1;
			UPDATE SREPORT_WK SET
				ITEM034 = gSumGankingk::text,
				ITEM035 = gSumZeihikiBefKngk::text,
				ITEM036 = gSumKokuZeiKingk::text,
				ITEM037 = gSumChihoZeiKngkH::text,
				ITEM038 = gSumZeihikiAftKngk::text,
				ITEM040 = (gSumGankingk + gSumZeihikiAftKngk)::text,
				ITEM028 = coalesce(ITEM028, ' ')
			WHERE
				KEY_CD = l_inItakuKaishaCd
				AND USER_ID = l_inUserId
				AND CHOHYO_KBN = l_inChohyoKbn
				AND SAKUSEI_YMD = gGyomuYmd
				AND CHOHYO_ID = C_REPORT_ID
				AND SEQ_NO BETWEEN gSeqStart AND gSeqEnd;
			gSumGankingk := gGankingk;
			gSumZeihikiBefKngk := pZeihikiBefKngk;
			gSumKokuZeiKingk := pKokuZeiKingk;
			gSumChihoZeiKngk := pChihoZeiKngk;
			gSumZeihikiAftKngk := pZeihikiAftKngk;
			IF gCorpIndKbn = '1' THEN
				gSumChihoZeiKngkH := '−';
			ELSE
				gSumChihoZeiKngkH := gSumChihoZeiKngk;
			END IF;
		ELSE
			IF gBreakMgrCd != gMgrCd THEN
				gSumGankingk := gSumGankingk + gGankingk;
				gSumZeihikiBefKngk := gSumZeihikiBefKngk + pZeihikiBefKngk;
				gSumKokuZeiKingk := gSumKokuZeiKingk + pKokuZeiKingk;
				IF coalesce(pChihoZeiKngk::text, '') = '' THEN
					gSumChihoZeiKngk := NULL;
				ELSE
					gSumChihoZeiKngk := gSumChihoZeiKngk + pChihoZeiKngk;
				END IF;
				gSumZeihikiAftKngk := gSumZeihikiAftKngk + pZeihikiAftKngk;
				IF gCorpIndKbn = '1' THEN
					gSumChihoZeiKngkH := '−';
				ELSE
					gSumChihoZeiKngkH := gSumChihoZeiKngk;
				END IF;
			END IF;
		END IF;
		IF gCorpIndKbn = '1' THEN
			gChihoZeiKngk := '−';
		ELSE
			gChihoZeiKngk := pChihoZeiKngk;
		END IF;
		v_item.l_inItem001 := gWTsuchiYmd;
		v_item.l_inItem002 := gPostNo;
		v_item.l_inItem003 := gTrhkAdd1;
		v_item.l_inItem004 := gTrhkAdd2;
		v_item.l_inItem005 := gTrhkAdd3;
		v_item.l_inItem006 := gTrhkCd;
		v_item.l_inItem007 := gGnrkKessaiMethod;
		v_item.l_inItem008 := gTrhkZokusei;
		v_item.l_inItem009 := pAtenaNm;
		v_item.l_inItem010 := gBankNm;
		v_item.l_inItem011 := pBun;
		v_item.l_inItem012 := pWRbrYmd;
		v_item.l_inItem013 := gKozatenTitle;
		v_item.l_inItem014 := gKBankNm;
		v_item.l_inItem015 := gKShitenNm;
		v_item.l_inItem016 := C_KOZANO_TITLE;
		v_item.l_inItem017 := gKozaKamokuNm;
		v_item.l_inItem018 := pKozaNo;
		v_item.l_inItem019 := gMeigininTitle;
		v_item.l_inItem020 := gMeigininNm;
		v_item.l_inItem021 := gIsinCd;
		v_item.l_inItem022 := gProMgrNm;
		v_item.l_inItem023 := gRiritsu;
		v_item.l_inItem024 := pGanriZandaka;
		v_item.l_inItem025 := gGankingk;
		v_item.l_inItem026 := pZeihikiBefKngk;
		v_item.l_inItem027 := pKokuZeiKingk;
		v_item.l_inItem028 := gChihoZeiKngk;
		v_item.l_inItem029 := pZeihikiAftKngk;
		v_item.l_inItem030 := pProKenshuCd;
		v_item.l_inItem031 := gKibangoFrom;
		v_item.l_inItem032 := gKibangoTo;
		v_item.l_inItem033 := gWkcTaxDays;
		v_item.l_inItem039 := pHosokuBunsho;
		v_item.l_inItem041 := pZeiErrFlg;
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd,
			l_inUserId     => l_inUserId,
			l_inChohyoKbn  => l_inChohyoKbn,
			l_inSakuseiYmd => gGyomuYmd,
			l_inChohyoId   => C_REPORT_ID,
			l_inSeqNo      => gSeqNo::integer,
			l_inHeaderFlg  => '1',
			l_inItem       => v_item,
			l_inKousinId   => l_inUserId,
			l_inSakuseiId  => l_inUserId
		);
		gSeqNo := gSeqNo + 1;
		-- Inlined: SPIPP004K00R01_insertData (END)
		-- 帳票ワーク更新
		-- Inlined: SPIPP004K00R01_updateWork (BEGIN)
		gSeqStart := gSeqEnd + 1;
		gSeqEnd := gSeqNo - 1;
		UPDATE SREPORT_WK SET
			ITEM034 = gSumGankingk::text,
			ITEM035 = gSumZeihikiBefKngk::text,
			ITEM036 = gSumKokuZeiKingk::text,
			ITEM037 = gSumChihoZeiKngkH::text,
			ITEM038 = gSumZeihikiAftKngk::text,
			ITEM040 = (gSumGankingk + gSumZeihikiAftKngk)::text,
			ITEM028 = coalesce(ITEM028, ' ')
		WHERE
			KEY_CD = l_inItakuKaishaCd
			AND USER_ID = l_inUserId
			AND CHOHYO_KBN = l_inChohyoKbn
			AND SAKUSEI_YMD = gGyomuYmd
			AND CHOHYO_ID = C_REPORT_ID
			AND SEQ_NO BETWEEN gSeqStart AND gSeqEnd;
		-- Inlined: SPIPP004K00R01_updateWork (END)
		-- バッチの時
		IF l_inChohyoKbn = '1' THEN
			-- バッチ帳票印刷データ作成
			CALL pkPrtOk.insertPrtOk(
								l_inUserId,
								l_inItakuKaishaCd,
								gGyomuYmd,
								pkPrtOk.LIST_SAKUSEI_KBN_DAY(),
								C_REPORT_ID
								);
		END IF;
		-- 正常終了
		l_outSqlCode := pkconstant.success();
		l_outSqlErrM := '';
	END IF;
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'SQLERRM:' || SQLERRM);
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLSTATE || SQLERRM;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipp004k00r01 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE, l_inUserId SREPORT_WK.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_inMgrCd MGR_KIHON.MGR_CD%TYPE, l_inIsinCd MGR_KIHON.ISIN_CD%TYPE, l_inKjnYmdFrom MGR_RBRKIJ.RBR_YMD%TYPE, l_inKjnYmdTo MGR_RBRKIJ.RBR_YMD%TYPE, l_inTsuchiYmd text, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spipp004k00r01_createbun (l_inReportId TEXT,l_inPatternCd BUN.BUN_PATTERN_CD%TYPE) RETURNS varchar AS $body$
DECLARE

	-- 請求文章（ワーク）
	aryBun Pkipabun.BUN_ARRAY;
	wkBun  varchar(300) := NULL;
BEGIN
	-- 請求文章の取得
	arybun := pkIpaBun.getBun(l_inReportId, l_inPatternCd);
	FOR i IN 0..coalesce(cardinality(aryBun), 0) - 1 LOOP
		-- 100byteまで全角スペース埋めして、請求文章を連結
		wkBun := wkBun || RPAD(arybun[i], 100, C_BLANK);
	END LOOP;
RETURN wkBun;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spipp004k00r01_createbun (l_inReportId TEXT,l_inPatternCd BUN.BUN_PATTERN_CD%TYPE) FROM PUBLIC;
