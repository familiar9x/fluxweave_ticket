




CREATE OR REPLACE PROCEDURE spipp005k00r01 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE,     -- 委託会社コード
 l_inUserId SREPORT_WK.USER_ID%TYPE,    -- ユーザーＩＤ
 l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, -- 帳票区分
 l_inKjnYm text,                   -- 基準年月
 l_outSqlCode OUT integer,                    -- リターン値
 l_outSqlErrM OUT text                    -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2007
-- * 会社名:JIP
-- *
-- * 概要　:決済方法別元利払一覧表
-- *
-- * 引数　:l_inItakuKaishaCd :委託会社コード
-- *        l_inUserId        :ユーザーＩＤ
-- *        l_inChohyoKbn     :帳票区分
-- *        l_inKjnYm         :基準年月
-- *        l_outSqlCode      :リターン値
-- *        l_outSqlErrM      :エラーコメント
-- *
-- * 返り値: なし
-- *
-- * @author ASK
-- * @version $Id: SPIPP005K00R01.sql,v 1.10 2015/03/17 06:50:55 takahashi Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2007.07.04 中村        新規作成
-- *　2007.08.13 JIP         利払情報追加
-- *　2007.08.31 JIP         IP-05589対応
-- *　2007.09.11 JIP         IP-05623対応
-- *　                       IP-05624対応
-- *　2007.09.18 JIP         IP-05650対応
-- ***************************************************************************
--	/*==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_PROGRAM_ID CONSTANT varchar(50)              := 'SPIPP005K00R01'; -- プログラムＩＤ
	C_CHOHYO_ID  CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IPP30000511';    -- 帳票ＩＤ
	C_BLANK      CONSTANT char(1)                   := ' ';              -- ブランク
	C_NO_DATA    CONSTANT integer                   := 2;                -- 対象データなし
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gSeqNo              integer;                                -- シーケンス
	gItakuKaishaRnm     MITAKU_KAISHA.ITAKU_KAISHA_RNM%TYPE;   -- 委託会社略称
	gGyomuYmd           SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;     -- 業務日付
	gSakuseiYmd         SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;     -- 作成年月日
	gRbrKjtFrom         MGR_RBRKIJ.RBR_KJT%TYPE;               -- 元利払期日ＦＲＯＭ（バッチ用）
	gRbrKjtTo           MGR_RBRKIJ.RBR_KJT%TYPE;               -- 元利払期日ＴＯ（バッチ用）
	--  2007/08/31  ADD JIP
	gRbrYmdFrom         MGR_RBRKIJ.RBR_KJT%TYPE;               -- 元利払期日FROM（リアル用）
	gRbrYmdTo           MGR_RBRKIJ.RBR_KJT%TYPE;               -- 元利払期日TO  （リアル用）
	--  2007/08/31  ADD JIP
	gMgrFlg             MPROCESS_CTL.CTL_VALUE%TYPE;           -- 銘柄名称制御フラグ取得（'0'：略称 '1'：正式）
	gTSumGankingk       numeric;                                -- 元金額（取引先合計）
	gTSumZeihikiBefKngk numeric;                                -- 税引前利金額（取引先合計）
	gTSumKokuZeiKingk   numeric;                                -- 国税（取引先合計）
	gTSumChihoZeiKngk   numeric;                                -- 地方税（取引先合計）
	gTSumZeihikiAftKngk numeric;                                -- 税引後利金額（取引先合計）
	gGSumGankingk       numeric;                                -- 元金額（元利払日合計）
	gGSumZeihikiBefKngk numeric;                                -- 税引前利金額（元利払日合計）
	gGSumKokuZeiKingk   numeric;                                -- 国税（元利払日合計）
	gGSumChihoZeiKngk   numeric;                                -- 地方税（元利払日合計）
	gGSumZeihikiAftKngk numeric;                                -- 税引後利金額（元利払日合計）
	-- 2007/08/31 ADD JIP
	gTTaxErrFlg         varchar(1);                           -- 税算出エラーフラグ（取引先合計）
	gGTaxErrFlg         varchar(1);                           -- 税算出エラーフラグ（元利払日合計）
	gTZokusei           KBG_MTORISAKI.TRHK_ZOKUSEI%TYPE;       -- 取引先属性（取引先合計）
	-- 2007/08/31 ADD JIP
	gChihoZeiKngk       varchar(16);                          -- 地方税（法人個人区分が１：法人の場合は−）
	gTSumChihoZeiKngkH  varchar(16);                          -- 地方税（法人個人区分が１：法人の場合は−）
	-- 読込データ
	gItakuKaishaCd      KBG_SHOKBG.ITAKU_KAISHA_CD%TYPE;       -- 委託会社コード
	gMgrCd              KBG_SHOKBG.MGR_CD%TYPE;                -- 銘柄コード
	gKenshuCd           KBG_SHOKBG.KENSHU_CD%TYPE;             -- 券種コード
	gKibangoFrom        KBG_SHOKBG.KIBANGO_FROM%TYPE;          -- 記番号ＦＲＯＭ
	gKibangoTo          KBG_SHOKBG.KIBANGO_TO%TYPE;            -- 記番号ＴＯ
	gTrhkCd             KBG_SHOKBG.TRHK_CD%TYPE;               -- 取引先コード
	gTrhkRnm            KBG_MTORISAKI.TRHK_RNM%TYPE;           -- 取引先略称
	gTaxKbn             KBG_MTORISAKI.TAX_KBN%TYPE;            -- 税区分
	gGnrkKessaiMethod   KBG_MTORISAKI.GNRK_KESSAI_METHOD%TYPE; -- 元利金決済方法区分
	gGnrkKessaiMethodNm SCODE.CODE_NM%TYPE;                    -- 元利金決済方法区分名称
	gTrhkZokusei        KBG_MTORISAKI.TRHK_ZOKUSEI%TYPE;       -- 取引先属性
	gCorpIndKbn         KBG_MTORISAKI.CORPORATION_INDIVIDUAL_KBN%TYPE;   -- 法人個人区分
	gRbrkjt             MGR_RBRKIJ.RBR_KJT%TYPE;               -- 利払期日
	gRbrYmd             MGR_RBRKIJ.RBR_YMD%TYPE;               -- 利払日
	gIsinCd             MGR_KIHON_VIEW.ISIN_CD%TYPE;           -- ＩＳＩＮコード
	gMgrNm              MGR_KIHON.MGR_NM%TYPE;                 -- 銘柄の正式名称
	gMgrRnm             MGR_KIHON.MGR_RNM%TYPE;                -- 銘柄略称
	gGankingk           numeric;                                -- 元金額
	-- Local variables from nested procedures
	gProMgrNm       MGR_KIHON.MGR_NM%TYPE; -- 銘柄名称（正式 OR 略称）（編集用）
	pProKenshuCd    numeric;                -- 券種コード（編集用）
	pRetNo          integer;               -- 戻り値（取引先別税額取得用）
	pSqlErrM        varchar(1000);         -- エラーコメント（取引先別税額取得用）
	pKokuZeiKingk   numeric;                -- 国税
	pChihoZeiKngk   numeric;                -- 地方税
	pZeihikiBefKngk numeric;                -- 税引前利金額
	pZeihikiAftKngk numeric;                -- 税引後利金額
	pSumKngk        numeric;                -- 合計（元金＋税引後利金額）
	pZeiErrFlg      char(1);               -- 税計算エラーフラグ（'0':正常、'1':エラー）
	pZenRbrYmd      MGR_RBRKIJ.RBR_YMD%TYPE; -- 残高基準日（利払日の前日）
	pGSumKngk       numeric; -- 合計（元金＋税引後利金額）元利払日
	pTSumKngk       numeric; -- 合計（元金＋税引後利金額）取引先
	-- ブレイク確認用変数
	gBreakRbrYmd        MGR_RBRKIJ.RBR_YMD%TYPE;               -- 利払日
	gBreakTrhkCd        KBG_SHOKBG.TRHK_CD%TYPE;               -- 取引先コード
	gBreakMgrCd         KBG_SHOKBG.MGR_CD%TYPE;                -- 銘柄コード
	gBreakMethod        KBG_MTORISAKI.GNRK_KESSAI_METHOD%TYPE; -- 元利金決済方法区分
	gBreakMethodNm      SCODE.CODE_NM%TYPE;                    -- 元利金決済方法区分名称
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	-- 2007/08/31 EDIT JIP
	curMeisai CURSOR FOR
		SELECT  WK1.ITAKU_KAISHA_CD,                            -- 委託会社コード
				P05.GNRK_KESSAI_METHOD,                         -- 元利金決済方法区分
				(   SELECT CODE_NM
					FROM   SCODE
					WHERE  CODE_SHUBETSU = '229'
					AND    CODE_VALUE    = P05.GNRK_KESSAI_METHOD
				)   AS     GNRK_KESSAI_METHOD_NM,               -- 元利金決済方法区分名称
				WK1.RBR_KJT,                                    -- 利払期日
				WK1.RBR_YMD,                                    -- 利払日
				WK1.TRHK_CD,                                    -- 取引先コード
				P05.TRHK_RNM,                                   -- 取引先略称
				P05.TRHK_ZOKUSEI,                               -- 取引先属性
				WK1.MGR_CD,                                     -- 銘柄コード
				VMG1.ISIN_CD,                                   -- ＩＳＩＮコード
				VMG1.MGR_NM,                                    -- 銘柄の正式名称
				VMG1.MGR_RNM,                                   -- 銘柄略称
				P05.TAX_KBN,                                    -- 税区分
				P05.CORPORATION_INDIVIDUAL_KBN,                 -- 法人個人区分
				pkIpaKibango.getGankinTrhk(
				    WK1.ITAKU_KAISHA_CD,
				    WK1.MGR_CD,
				    WK1.RBR_YMD,
				    WK1.TRHK_CD
				)   AS  GANKINGK,                               -- 元金額
				coalesce(WK2.KENSHU_CD,    0)    as KENSHU_CD,       -- 券種コード     (利払のみの場合は「0」)
				coalesce(WK2.KIBANGO_FROM, 0)    as KIBANGO_FROM,    -- 記番号ＦＲＯＭ (利払のみの場合は「0」)
				coalesce(WK2.KIBANGO_TO,   0)    as KIBANGO_TO        -- 記番号ＴＯ     (利払のみの場合は「0」)
		FROM mgr_kihon_view vmg1, kbg_mtorisaki p05, (   --  利払情報
				    SELECT  P02.ITAKU_KAISHA_CD,
				            P02.MGR_CD,
				            P02.TRHK_CD,
				            MG2_1.RBR_YMD,
				            MG2_1.RBR_KJT
				    FROM    (   SELECT  MG2.*
								FROM    MGR_RBRKIJ  MG2,
										GENSAI_RIREKI Z01
								WHERE   (   --  出力区分（リアル／バッチ）により参照項目が異なる
											( l_inChohyoKbn = '0' AND (MG2.RBR_YMD BETWEEN gRbrYmdFrom AND gRbrYmdTo) )  OR ( l_inChohyoKbn = '1' AND (MG2.RBR_KJT BETWEEN gRbrKjtFrom AND gRbrKjtTo) )
										)
										AND MG2.ITAKU_KAISHA_CD = Z01.ITAKU_KAISHA_CD 	-- 減債履歴との結合条件は、「特例債のみ」「記番号は振替移行1回のみ」
										AND MG2.MGR_CD = Z01.MGR_CD 						-- という制約に基づくため、この4項目でOK。
										AND MG2.RBR_YMD > Z01.SHOKAN_YMD 	-- 利払日が振替移行日より前の利払情報は出力しない。
										AND Z01.SHOKAN_KBN = '01'			-- (振替移行より利払の処理が先になるので、振替移行日当日も出力しない)
				            )   MG2_1,
							KBG_SHOKBG P02,
				            KBG_SHOKIJ P01
					WHERE   MG2_1.ITAKU_KAISHA_CD = P01.ITAKU_KAISHA_CD
				    AND     MG2_1.ITAKU_KAISHA_CD = P02.ITAKU_KAISHA_CD
				    AND     MG2_1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
				    AND     MG2_1.MGR_CD          = P01.MGR_CD
				    AND     MG2_1.MGR_CD          = P02.MGR_CD
				    AND (   --  償還期日が未決定の記番号債券も含めたすべての未償還債券が対象
							(   P01.SHOKAN_YMD    >= MG2_1.RBR_YMD      AND
							    P02.SHOKAN_KJT     = P01.SHOKAN_KJT     AND   -- 2007/09/11 EDIT JIP
								P02.KBG_SHOKAN_KBN = P01.KBG_SHOKAN_KBN
							)
							OR coalesce(trim(both P02.SHOKAN_KJT)::text, '') = ''
						) 
				    GROUP BY
				            P02.ITAKU_KAISHA_CD,
				            MG2_1.RBR_KJT,
				            MG2_1.RBR_YMD,
				            P02.TRHK_CD,
				            P02.MGR_CD
				) wk1
LEFT OUTER JOIN (   --  償還情報
				    SELECT  P02.ITAKU_KAISHA_CD,
				            P02.MGR_CD,
				            P02.TRHK_CD,
				            P01.SHOKAN_YMD,
				            P02.KENSHU_CD,
				            P02.KIBANGO_FROM,
				            P02.KIBANGO_TO
				    FROM    KBG_SHOKBG  P02,
				            KBG_SHOKIJ  P01
				    WHERE   P02.ITAKU_KAISHA_CD = P01.ITAKU_KAISHA_CD
				    AND     P02.ITAKU_KAISHA_CD = l_inItakuKaishaCd
				    AND     P02.MGR_CD          = P01.MGR_CD
				    AND     P02.SHOKAN_KJT      = P01.SHOKAN_KJT
				    AND     P02.KBG_SHOKAN_KBN  = P01.KBG_SHOKAN_KBN
				    AND     P01.KBG_SHOKAN_KBN != '62'
				    AND     P01.KBG_SHOKAN_KBN != '63'
					AND     (   --  出力区分（リアル／バッチ）により参照項目が異なる
								( l_inChohyoKbn = '0' AND (P01.SHOKAN_YMD BETWEEN gRbrYmdFrom AND gRbrYmdTo) )  OR ( l_inChohyoKbn = '1' AND (P01.SHOKAN_KJT BETWEEN gRbrKjtFrom AND gRbrKjtTo) )
							) 
				) wk2 ON (WK1.ITAKU_KAISHA_CD = WK2.ITAKU_KAISHA_CD AND WK1.RBR_YMD = WK2.SHOKAN_YMD AND WK1.MGR_CD = WK2.MGR_CD AND WK1.TRHK_CD = WK2.TRHK_CD)
WHERE WK1.ITAKU_KAISHA_cD = P05.ITAKU_KAISHA_CD AND WK1.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD   AND WK1.MGR_CD          = VMG1.MGR_CD  AND WK1.TRHK_CD         = P05.TRHK_CD AND VMG1.MGR_STAT_KBN   = '1' AND VMG1.KK_KANYO_FLG   = '2' AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '') ORDER BY
				GNRK_KESSAI_METHOD,
				RBR_YMD,
				TRHK_CD,
				ISIN_CD,
				CASE WHEN  KENSHU_CD=0 THEN  10000000000  ELSE KENSHU_CD END ,  --  償還情報、利払情報の順に出力
				CASE WHEN  KIBANGO_FROM=0 THEN  10000000  ELSE KIBANGO_FROM END;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 入力パラメータチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inUserId)::text, '') = ''
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''
	OR (l_inChohyoKbn = '0' AND coalesce(trim(both l_inKjnYm)::text, '') = '') THEN
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := 'パラメータエラー';
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, l_outSqlErrM);
		RETURN;
	END IF;
	-- 委託会社略称取得
	SELECT
		CASE WHEN JIKO_DAIKO_KBN='2' THEN  BANK_RNM  ELSE ' ' END
	INTO
		gItakuKaishaRnm
	FROM
		VJIKO_ITAKU
	WHERE
		KAIIN_ID = l_inItakuKaishaCd;
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
	--  2007/08/31 EDIT JIP
	-- 作成年月日
	gSakuseiYmd := gGyomuYmd;
	-- バッチの時
	IF l_inChohyoKbn = '1' THEN
		-- 元利払期日FROM
		gRbrKjtFrom := pkDate.getPlusDate(gGyomuYmd, 21);
		gRbrKjtFrom := pkDate.getPlusDate(gRbrKjtFrom, 1);
		-- 元利払期日TO
		gRbrKjtTo := pkDate.getPlusDateBusiness(gGyomuYmd, 1);
		gRbrKjtTo := pkDate.getPlusDate(gRbrKjtTo, 21);
	ELSE
		--  元利払日FROM
		gRbrYmdFrom := l_inKjnYm || '01';
		--  元利払日TO
		gRbrYmdTo := pkDate.getGetsumatsuYmd(gRbrYmdFrom, 0);
	END IF;
	--  2007/08/31 EDIT JIP
	-- 処理制御マスタから銘柄名称制御フラグ取得
	gMgrFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'getMgrNm01', '0');
	-- 帳票ワーク削除
	DELETE FROM SREPORT_WK
	WHERE
		KEY_CD = l_inItakuKaishaCd      -- 識別コード
		AND USER_ID = l_inUserId        -- ユーザーＩＤ
		AND CHOHYO_KBN = l_inChohyoKbn  -- 帳票区分
		AND SAKUSEI_YMD = gGyomuYmd     -- 作成日付
		AND CHOHYO_ID = C_CHOHYO_ID;   -- 帳票ＩＤ
	-- 変数初期化
	gItakuKaishaCd      := C_BLANK; -- 委託会社コード（読込データ）
	gBreakRbrYmd        := C_BLANK; -- 元利払日（ブレイク確認用）
	gBreakTrhkCd        := C_BLANK; -- 取引先コード（ブレイク確認用）
	gBreakMgrCd         := C_BLANK; -- 銘柄コード（ブレイク確認用）
	gBreakMethod        := C_BLANK; -- 元利金決済方法区分（ブレイク確認用）
	gBreakMethodNm      := C_BLANK; -- 元利金決済方法区分名称（ブレイク確認用）
	gSeqNo              := 1;       -- シーケンス初期化
	gTSumGankingk       := 0;       -- 元金額（取引先合計）
	gTSumKokuZeiKingk   := 0;       -- 国税（取引先合計）
	gTSumChihoZeiKngk   := 0;       -- 地方税（取引先合計）
	gTSumZeihikiBefKngk := 0;       -- 税引前利金額（取引先合計）
	gTSumZeihikiAftKngk := 0;       -- 税引後利金額（取引先合計）
	gGSumGankingk       := 0;       -- 元金額（元利払日合計）
	gGSumKokuZeiKingk   := 0;       -- 国税（元利払日合計）
	gGSumChihoZeiKngk   := 0;       -- 地方税（元利払日合計）
	gGSumZeihikiBefKngk := 0;       -- 税引前利金額（元利払日合計）
	gGSumZeihikiAftKngk := 0;       -- 税引後利金額（元利払日合計）
	-- 2007/08/31 ADD JIP
	gTTaxErrFlg         := '0';     -- 税算出エラーフラグ（取引先合計）
	gGTaxErrFlg         := '0';     -- 税算出エラーフラグ（元利払日合計）
	-- 2007/08/31 ADD JIP
	-- データ読込
	FOR recMeisai IN curMeisai
	LOOP
		-- 初回時
		IF gItakuKaishaCd = C_BLANK THEN
			gItakuKaishaCd      := recMeisai.ITAKU_KAISHA_CD;       -- 委託会社コード
			gMgrCd              := recMeisai.MGR_CD;                -- 銘柄コード
			gKenshuCd           := recMeisai.KENSHU_CD;             -- 券種コード
			gKibangoFrom        := recMeisai.KIBANGO_FROM;          -- 記番号ＦＲＯＭ
			gKibangoTo          := recMeisai.KIBANGO_TO;            -- 記番号ＴＯ
			gTrhkCd             := recMeisai.TRHK_CD;               -- 取引先コード
			gTrhkRnm            := recMeisai.TRHK_RNM;              -- 取引先略称
			-- 2007/09/11 EDIT JIP
			IF ( recMeisai.TRHK_ZOKUSEI = '3' ) THEN
				gTaxKbn         := '−';                            -- その他口座管理機関の場合はハイフン表示
			ELSE
				gTaxKbn         := recMeisai.TAX_KBN;               -- 社債権者・常代の場合は税区分を表示
			END IF;
			-- 2007/09/11 EDIT JIP
			gGnrkKessaiMethod   := recMeisai.GNRK_KESSAI_METHOD;    -- 元利金決済方法区分
			gGnrkKessaiMethodNm := recMeisai.GNRK_KESSAI_METHOD_NM; -- 元利金決済方法区分名称
			gTrhkZokusei        := recMeisai.TRHK_ZOKUSEI;          -- 取引先属性
			gRbrkjt             := recMeisai.RBR_KJT;               -- 利払期日
			gRbrYmd             := recMeisai.RBR_YMD;               -- 利払日
			gIsinCd             := recMeisai.ISIN_CD;               -- ＩＳＩＮコード
			gMgrNm              := recMeisai.MGR_NM;                -- 銘柄の正式名称
			gMgrRnm             := recMeisai.MGR_RNM;               -- 銘柄略称
			gGankingk           := recMeisai.GANKINGK;              -- 元金額
			gCorpIndKbn         := recMeisai.CORPORATION_INDIVIDUAL_KBN;       -- 法人個人区分
		-- 初回でない時
		ELSE
			-- 「元利払日」、「取引先コード」、「銘柄コード」、「券種コード」
			-- かつ「記番号ＦＲＯＭ」が１データ前の「記番号ＴＯ」+ 1 の時
			IF  gRbrYmd                = recMeisai.RBR_YMD
			AND gTrhkCd                = recMeisai.TRHK_CD
			AND gMgrCd                 = recMeisai.MGR_CD
			AND gKenshuCd              = recMeisai.KENSHU_CD
			AND recMeisai.KIBANGO_FROM = (gKibangoTo + 1) THEN
				-- 変数再セット「記番号ＴＯ」
				gKibangoTo := recMeisai.KIBANGO_TO;
			ELSE
				-- 登録前編集 ＋ 帳票ワーク登録処理 (inlined from insertData)
				-- 銘柄名称（正式 OR 略称）編集
				IF gMgrFlg = '1' THEN
					gProMgrNm := SUBSTR(gMgrNm, 1, 50);
				ELSE
					gProMgrNm := gMgrRnm;
				END IF;
				-- 券種コード編集
				pProKenshuCd := gKenshuCd / 1000;
				-- 残高基準日（利払日の前日）を取得
				pZenRbrYmd := pkDate.getMinusDate(gRbrYmd, 1);
				-- 税計算エラーフラグ・オフ
				pZeiErrFlg := '0';
				--  取引先別税額取得処理
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
				-- 取引先別税額取得エラー時
				IF pRetNo != pkconstant.success() THEN
					pKokuZeiKingk   := 0;
					pChihoZeiKngk   := 0;
					pZeihikiBefKngk := 0;
					pZeihikiAftKngk := 0;
					CALL pkLog.error('EIP475', C_PROGRAM_ID, '委託会社:"' || l_inItakuKaishaCd || '"' ||
											' 取引先:"'  || gTrhkCd           || '"' || 
											' 利払日:"'  || gRbrYmd           || '"' || 
											' 銘柄:"'    || gMgrCd            || '"' );
					pZeiErrFlg := '1';
				END IF;
				-- 合計（元金＋税引後利金額）
				pSumKngk := gGankingk + pZeihikiAftKngk;
				-- 取引先属性 = 「3:その他口座管理機関」の時
				IF gTrhkZokusei = '3' THEN
					pChihoZeiKngk := 0;
				END IF;
				-- 法人個人区分が１（法人）の場合、地方税の算出しない。（金額に０をセット）
				IF gCorpIndKbn = '1' THEN
					pChihoZeiKngk := 0;
				END IF;
				-- 初回でなく、元利金決済方法区分又は元利払日又は取引先コードがブレイク時
				IF gSeqNo != 1
				AND (
					gBreakMethod != gGnrkKessaiMethod
					OR gBreakRbrYmd != gRbrYmd
					OR gBreakTrhkCd != gTrhkCd
				) THEN
					-- データ作成（取引先合計） - inlined from insertTData
					pTSumKngk := gTSumGankingk + gTSumZeihikiAftKngk;
					v_item := ROW();
					v_item.l_inItem001 := gItakuKaishaRnm;
					v_item.l_inItem002 := gBreakMethod;
					v_item.l_inItem003 := gBreakMethodNm;
					v_item.l_inItem004 := SUBSTR(gBreakRbrYmd, 1, 6);
					v_item.l_inItem005 := gTZokusei;
					v_item.l_inItem006 := C_BLANK;
					v_item.l_inItem007 := C_BLANK;
					v_item.l_inItem008 := C_BLANK;
					v_item.l_inItem009 := C_BLANK;
					v_item.l_inItem010 := C_BLANK;
					v_item.l_inItem011 := C_BLANK;
					v_item.l_inItem012 := '取引先合計';
					v_item.l_inItem013 := C_BLANK;
					v_item.l_inItem014 := gTSumGankingk;
					v_item.l_inItem015 := gTSumKokuZeiKingk;
					v_item.l_inItem016 := gTSumChihoZeiKngkH;
					v_item.l_inItem017 := gTSumZeihikiBefKngk;
					v_item.l_inItem018 := gTSumZeihikiAftKngk;
					v_item.l_inItem019 := pTSumKngk;
					v_item.l_inItem020 := C_BLANK;
					v_item.l_inItem021 := C_BLANK;
					v_item.l_inItem022 := C_BLANK;
					v_item.l_inItem023 := l_inUserId;
					v_item.l_inItem024 := C_CHOHYO_ID;
					v_item.l_inItem025 := gSakuseiYmd;
					v_item.l_inItem026 := gTTaxErrFlg;
					CALL pkPrint.insertData(
						l_inKeyCd		=> l_inItakuKaishaCd,
						l_inUserId		=> l_inUserId,
						l_inChohyoKbn	=> l_inChohyoKbn,
						l_inSakuseiYmd	=> gGyomuYmd,
						l_inChohyoId	=> C_CHOHYO_ID,
						l_inSeqNo		=> gSeqNo,
						l_inHeaderFlg	=> 1,
						l_inItem		=> v_item,
						l_inKousinId	=> l_inUserId,
						l_inSakuseiId	=> l_inUserId
					);
					gSeqNo := gSeqNo + 1;
					gTTaxErrFlg := '0';
					-- 取引先合計
					gTSumGankingk := gGankingk;
					gTSumKokuZeiKingk := pKokuZeiKingk;
					gTSumChihoZeiKngk := pChihoZeiKngk;
					gTSumZeihikiBefKngk := pZeihikiBefKngk;
					gTSumZeihikiAftKngk := pZeihikiAftKngk;
					IF gCorpIndKbn = '1' THEN
						gTSumChihoZeiKngkH := '−';
					ELSE
						gTSumChihoZeiKngkH := coalesce(gTSumChihoZeiKngk::text, ' ');
					END IF;
					gTZokusei := gTrhkZokusei;
					IF ( pZeiErrFlg != '0' ) THEN
						gTTaxErrFlg := '1';
					END IF;
					-- 元利金決済方法区分又は元利払日がブレイク時
					IF gBreakMethod != gGnrkKessaiMethod
					OR gBreakRbrYmd != gRbrYmd THEN
						-- データ作成（元利払日合計） - inlined from insertGData
						pGSumKngk := gGSumGankingk + gGSumZeihikiAftKngk;
						v_item := ROW();
						v_item.l_inItem001 := gItakuKaishaRnm;
						v_item.l_inItem002 := gBreakMethod;
						v_item.l_inItem003 := gBreakMethodNm;
						v_item.l_inItem004 := SUBSTR(gBreakRbrYmd, 1, 6);
						v_item.l_inItem005 := C_BLANK;
						v_item.l_inItem006 := C_BLANK;
						v_item.l_inItem007 := C_BLANK;
						v_item.l_inItem008 := C_BLANK;
						v_item.l_inItem009 := C_BLANK;
						v_item.l_inItem010 := C_BLANK;
						v_item.l_inItem011 := C_BLANK;
						v_item.l_inItem012 := '元利払日合計';
						v_item.l_inItem013 := C_BLANK;
						v_item.l_inItem014 := gGSumGankingk;
						v_item.l_inItem015 := gGSumKokuZeiKingk;
						v_item.l_inItem016 := gGSumChihoZeiKngk;
						v_item.l_inItem017 := gGSumZeihikiBefKngk;
						v_item.l_inItem018 := gGSumZeihikiAftKngk;
						v_item.l_inItem019 := pGSumKngk;
						v_item.l_inItem020 := C_BLANK;
						v_item.l_inItem021 := C_BLANK;
						v_item.l_inItem022 := C_BLANK;
						v_item.l_inItem023 := l_inUserId;
						v_item.l_inItem024 := C_CHOHYO_ID;
						v_item.l_inItem025 := gSakuseiYmd;
						v_item.l_inItem026 := gGTaxErrFlg;
						CALL pkPrint.insertData(
							l_inKeyCd		=> l_inItakuKaishaCd,
							l_inUserId		=> l_inUserId,
							l_inChohyoKbn	=> l_inChohyoKbn,
							l_inSakuseiYmd	=> gGyomuYmd,
							l_inChohyoId	=> C_CHOHYO_ID,
							l_inSeqNo		=> gSeqNo,
							l_inHeaderFlg	=> 1,
							l_inItem		=> v_item,
							l_inKousinId	=> l_inUserId,
							l_inSakuseiId	=> l_inUserId
						);
						gSeqNo := gSeqNo + 1;
						gGTaxErrFlg := '0';
						-- 元利払日合計
						gGSumGankingk := gGankingk;
						gGSumKokuZeiKingk := pKokuZeiKingk;
						gGSumChihoZeiKngk := pChihoZeiKngk;
						gGSumZeihikiBefKngk := pZeihikiBefKngk;
						gGSumZeihikiAftKngk := pZeihikiAftKngk;
						IF ( pZeiErrFlg != '0' ) THEN
							gGTaxErrFlg := '1';
						END IF;
					ELSE
						-- 元利払日合計
						gGSumGankingk := gGSumGankingk + gGankingk;
						gGSumKokuZeiKingk := gGSumKokuZeiKingk + pKokuZeiKingk;
						IF (pChihoZeiKngk IS NOT NULL AND pChihoZeiKngk::text <> '') THEN
							gGSumChihoZeiKngk := gGSumChihoZeiKngk + pChihoZeiKngk;
						END IF;
						gGSumZeihikiBefKngk := gGSumZeihikiBefKngk + pZeihikiBefKngk;
						gGSumZeihikiAftKngk := gGSumZeihikiAftKngk + pZeihikiAftKngk;
						IF ( pZeiErrFlg != '0' ) THEN
							gGTaxErrFlg := '1';
						END IF;
					END IF;
				ELSE
					IF gBreakMgrCd != gMgrCd THEN
						-- 取引先合計
						gTSumGankingk := gTSumGankingk + gGankingk;
						gTSumKokuZeiKingk := gTSumKokuZeiKingk + pKokuZeiKingk;
						IF (pChihoZeiKngk IS NOT NULL AND pChihoZeiKngk::text <> '') THEN
							gTSumChihoZeiKngk := gTSumChihoZeiKngk + pChihoZeiKngk;
						END IF;
						gTSumZeihikiBefKngk := gTSumZeihikiBefKngk + pZeihikiBefKngk;
						gTSumZeihikiAftKngk := gTSumZeihikiAftKngk + pZeihikiAftKngk;
						IF gCorpIndKbn = '1' THEN
							gTSumChihoZeiKngkH := '−';
						ELSE
							gTSumChihoZeiKngkH := coalesce(gTSumChihoZeiKngk::text, ' ');
						END IF;
						gTZokusei := gTrhkZokusei;
						IF ( pZeiErrFlg != '0' ) THEN
							gTTaxErrFlg := '1';
						END IF;
						-- 元利払日合計
						gGSumGankingk := gGSumGankingk + gGankingk;
						gGSumKokuZeiKingk := gGSumKokuZeiKingk + pKokuZeiKingk;
						IF (pChihoZeiKngk IS NOT NULL AND pChihoZeiKngk::text <> '') THEN
							gGSumChihoZeiKngk := gGSumChihoZeiKngk + pChihoZeiKngk;
						END IF;
						gGSumZeihikiBefKngk := gGSumZeihikiBefKngk + pZeihikiBefKngk;
						gGSumZeihikiAftKngk := gGSumZeihikiAftKngk + pZeihikiAftKngk;
						IF ( pZeiErrFlg != '0' ) THEN
							gGTaxErrFlg := '1';
						END IF;
					END IF;
				END IF;
				-- 法人個人区分が１（法人）の場合、地方税の算出しない（"−"表示）	セット
				IF gCorpIndKbn = '1' THEN
					gChihoZeiKngk := '−';
				ELSE
					gChihoZeiKngk := coalesce(pChihoZeiKngk::text, ' ');
				END IF;
				-- 帳票ワーク登録
				v_item := ROW();
				v_item.l_inItem001 := gItakuKaishaRnm;
				v_item.l_inItem002 := gGnrkKessaiMethod;
				v_item.l_inItem003 := gGnrkKessaiMethodNm;
				v_item.l_inItem004 := SUBSTR(gRbrYmd, 1, 6);
				v_item.l_inItem005 := gTrhkZokusei;
				v_item.l_inItem006 := gRbrYmd;
				v_item.l_inItem007 := gTrhkCd;
				v_item.l_inItem008 := gTrhkRnm;
				v_item.l_inItem009 := gIsinCd;
				v_item.l_inItem010 := gMgrCd;
				v_item.l_inItem011 := gProMgrNm;
				v_item.l_inItem012 := C_BLANK;
				v_item.l_inItem013 := gTaxKbn;
				v_item.l_inItem014 := gGankingk;
				v_item.l_inItem015 := pKokuZeiKingk;
				v_item.l_inItem016 := gChihoZeiKngk;
				v_item.l_inItem017 := pZeihikiBefKngk;
				v_item.l_inItem018 := pZeihikiAftKngk;
				v_item.l_inItem019 := pSumKngk;
				v_item.l_inItem020 := pProKenshuCd;
				v_item.l_inItem021 := gKibangoFrom;
				v_item.l_inItem022 := gKibangoTo;
				v_item.l_inItem023 := l_inUserId;
				v_item.l_inItem024 := C_CHOHYO_ID;
				v_item.l_inItem025 := gSakuseiYmd;
				v_item.l_inItem026 := pZeiErrFlg;
				CALL pkPrint.insertData(
					l_inKeyCd		=> l_inItakuKaishaCd,
					l_inUserId		=> l_inUserId,
					l_inChohyoKbn	=> l_inChohyoKbn,
					l_inSakuseiYmd	=> gGyomuYmd,
					l_inChohyoId	=> C_CHOHYO_ID,
					l_inSeqNo		=> gSeqNo,
					l_inHeaderFlg	=> 1,
					l_inItem		=> v_item,
					l_inKousinId	=> l_inUserId,
					l_inSakuseiId	=> l_inUserId
				);
				gSeqNo := gSeqNo + 1;
				-- ブレイク確認用変数へ格納
				gBreakRbrYmd   := gRbrYmd;             -- 元利払日
				gBreakTrhkCd   := gTrhkCd;             -- 取引先コード
				gBreakMgrCd    := gMgrCd;              -- 銘柄コード
				gBreakMethod   := gGnrkKessaiMethod;   -- 元利金決済方法区分
				gBreakMethodNm := gGnrkKessaiMethodNm; -- 元利金決済方法区分名称
				-- 変数セット
				gItakuKaishaCd      := recMeisai.ITAKU_KAISHA_CD;       -- 委託会社コード
				gMgrCd              := recMeisai.MGR_CD;                -- 銘柄コード
				gKenshuCd           := recMeisai.KENSHU_CD;             -- 券種コード
				gKibangoFrom        := recMeisai.KIBANGO_FROM;          -- 記番号ＦＲＯＭ
				gKibangoTo          := recMeisai.KIBANGO_TO;            -- 記番号ＴＯ
				gTrhkCd             := recMeisai.TRHK_CD;               -- 取引先コード
				gTrhkRnm            := recMeisai.TRHK_RNM;              -- 取引先略称
				-- 2007/09/11 EDIT JIP
				IF ( recMeisai.TRHK_ZOKUSEI = '3' ) THEN
					gTaxKbn         := '−';                            -- その他口座管理機関の場合はハイフン表示
				ELSE
					gTaxKbn         := recMeisai.TAX_KBN;               -- 社債権者・常代の場合は税区分を表示
				END IF;
				-- 2007/09/11 EDIT JIP
				gGnrkKessaiMethod   := recMeisai.GNRK_KESSAI_METHOD;    -- 元利金決済方法区分
				gGnrkKessaiMethodNm := recMeisai.GNRK_KESSAI_METHOD_NM; -- 元利金決済方法区分名称
				gTrhkZokusei        := recMeisai.TRHK_ZOKUSEI;          -- 取引先属性
				gRbrkjt             := recMeisai.RBR_KJT;               -- 利払期日
				gRbrYmd             := recMeisai.RBR_YMD;               -- 利払日
				gIsinCd             := recMeisai.ISIN_CD;               -- ＩＳＩＮコード
				gMgrNm              := recMeisai.MGR_NM;                -- 銘柄の正式名称
				gMgrRnm             := recMeisai.MGR_RNM;               -- 銘柄略称
				gGankingk           := recMeisai.GANKINGK;              -- 元金額
				gCorpIndKbn         := recMeisai.CORPORATION_INDIVIDUAL_KBN;       -- 法人個人区分
			END IF;
		END IF;
	END LOOP;
	-- 最終レコードを処理する
	IF gItakuKaishaCd = C_BLANK THEN
		-- リアルの時
		IF l_inChohyoKbn = '0' THEN
			-- ヘッダレコードを追加
			CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, gGyomuYmd, C_CHOHYO_ID);
			-- 帳票ワーク登録
			v_item := ROW();
			v_item.l_inItem001 := gItakuKaishaRnm;
			v_item.l_inItem023 := l_inUserId;
			v_item.l_inItem024 := C_CHOHYO_ID;
			v_item.l_inItem025 := gSakuseiYmd;
			v_item.l_inItem027 := '対象データなし';
			CALL pkPrint.insertData(
				l_inKeyCd		=> l_inItakuKaishaCd,
				l_inUserId		=> l_inUserId,
				l_inChohyoKbn	=> l_inChohyoKbn,
				l_inSakuseiYmd	=> gGyomuYmd,
				l_inChohyoId	=> C_CHOHYO_ID,
				l_inSeqNo		=> gSeqNo,
				l_inHeaderFlg	=> 1,
				l_inItem		=> v_item,
				l_inKousinId	=> l_inUserId,
				l_inSakuseiId	=> l_inUserId
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
		CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, gGyomuYmd, C_CHOHYO_ID);
		-- データ作成 (inlined insertData)
		IF gMgrFlg = '1' THEN
			gProMgrNm := SUBSTR(gMgrNm, 1, 50);
		ELSE
			gProMgrNm := gMgrRnm;
		END IF;
		pProKenshuCd := gKenshuCd / 1000;
		pZenRbrYmd := pkDate.getMinusDate(gRbrYmd, 1);
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
			pKokuZeiKingk   := 0;
			pChihoZeiKngk   := 0;
			pZeihikiBefKngk := 0;
			pZeihikiAftKngk := 0;
			CALL pkLog.error('EIP475', C_PROGRAM_ID, '委託会社:"' || l_inItakuKaishaCd || '"' ||
								' 取引先:"'  || gTrhkCd           || '"' || 
								' 利払日:"'  || gRbrYmd           || '"' || 
								' 銘柄:"'    || gMgrCd            || '"' );
			pZeiErrFlg := '1';
		END IF;
		pSumKngk := gGankingk + pZeihikiAftKngk;
		IF gTrhkZokusei = '3' THEN
			pChihoZeiKngk := 0;
		END IF;
		IF gCorpIndKbn = '1' THEN
			pChihoZeiKngk := 0;
		END IF;
		IF gCorpIndKbn = '1' THEN
			gChihoZeiKngk := '−';
		ELSE
			gChihoZeiKngk := coalesce(pChihoZeiKngk::text, ' ');
		END IF;
		v_item := ROW();
		v_item.l_inItem001 := gItakuKaishaRnm;
		v_item.l_inItem002 := gGnrkKessaiMethod;
		v_item.l_inItem003 := gGnrkKessaiMethodNm;
		v_item.l_inItem004 := SUBSTR(gRbrYmd, 1, 6);
		v_item.l_inItem005 := gTrhkZokusei;
		v_item.l_inItem006 := gRbrYmd;
		v_item.l_inItem007 := gTrhkCd;
		v_item.l_inItem008 := gTrhkRnm;
		v_item.l_inItem009 := gIsinCd;
		v_item.l_inItem010 := gMgrCd;
		v_item.l_inItem011 := gProMgrNm;
		v_item.l_inItem012 := C_BLANK;
		v_item.l_inItem013 := gTaxKbn;
		v_item.l_inItem014 := gGankingk;
		v_item.l_inItem015 := pKokuZeiKingk;
		v_item.l_inItem016 := gChihoZeiKngk;
		v_item.l_inItem017 := pZeihikiBefKngk;
		v_item.l_inItem018 := pZeihikiAftKngk;
		v_item.l_inItem019 := pSumKngk;
		v_item.l_inItem020 := pProKenshuCd;
		v_item.l_inItem021 := gKibangoFrom;
		v_item.l_inItem022 := gKibangoTo;
		v_item.l_inItem023 := l_inUserId;
		v_item.l_inItem024 := C_CHOHYO_ID;
		v_item.l_inItem025 := gSakuseiYmd;
		v_item.l_inItem026 := pZeiErrFlg;
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> gGyomuYmd,
			l_inChohyoId	=> C_CHOHYO_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> 1,
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		gSeqNo := gSeqNo + 1;
		-- 合計用に変数セット
		gBreakRbrYmd   := gRbrYmd;             -- 元利払日
		gBreakMethod   := gGnrkKessaiMethod;   -- 元利金決済方法区分
		gBreakMethodNm := gGnrkKessaiMethodNm; -- 元利金決済方法区分名称
		-- データ作成（取引先合計） (inlined insertTData)
		pTSumKngk := gTSumGankingk + gTSumZeihikiAftKngk;
		v_item := ROW();
		v_item.l_inItem001 := gItakuKaishaRnm;
		v_item.l_inItem002 := gBreakMethod;
		v_item.l_inItem003 := gBreakMethodNm;
		v_item.l_inItem004 := SUBSTR(gBreakRbrYmd, 1, 6);
		v_item.l_inItem005 := gTZokusei;
		v_item.l_inItem006 := C_BLANK;
		v_item.l_inItem007 := C_BLANK;
		v_item.l_inItem008 := C_BLANK;
		v_item.l_inItem009 := C_BLANK;
		v_item.l_inItem010 := C_BLANK;
		v_item.l_inItem011 := C_BLANK;
		v_item.l_inItem012 := '取引先合計';
		v_item.l_inItem013 := C_BLANK;
		v_item.l_inItem014 := gTSumGankingk;
		v_item.l_inItem015 := gTSumKokuZeiKingk;
		v_item.l_inItem016 := gTSumChihoZeiKngkH;
		v_item.l_inItem017 := gTSumZeihikiBefKngk;
		v_item.l_inItem018 := gTSumZeihikiAftKngk;
		v_item.l_inItem019 := pTSumKngk;
		v_item.l_inItem020 := C_BLANK;
		v_item.l_inItem021 := C_BLANK;
		v_item.l_inItem022 := C_BLANK;
		v_item.l_inItem023 := l_inUserId;
		v_item.l_inItem024 := C_CHOHYO_ID;
		v_item.l_inItem025 := gSakuseiYmd;
		v_item.l_inItem026 := gTTaxErrFlg;
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> gGyomuYmd,
			l_inChohyoId	=> C_CHOHYO_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> 1,
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		gSeqNo := gSeqNo + 1;
		gTTaxErrFlg := '0';
		-- データ作成（元利払日合計） (inlined insertGData)
		pGSumKngk := gGSumGankingk + gGSumZeihikiAftKngk;
		v_item := ROW();
		v_item.l_inItem001 := gItakuKaishaRnm;
		v_item.l_inItem002 := gBreakMethod;
		v_item.l_inItem003 := gBreakMethodNm;
		v_item.l_inItem004 := SUBSTR(gBreakRbrYmd, 1, 6);
		v_item.l_inItem005 := C_BLANK;
		v_item.l_inItem006 := C_BLANK;
		v_item.l_inItem007 := C_BLANK;
		v_item.l_inItem008 := C_BLANK;
		v_item.l_inItem009 := C_BLANK;
		v_item.l_inItem010 := C_BLANK;
		v_item.l_inItem011 := C_BLANK;
		v_item.l_inItem012 := '元利払日合計';
		v_item.l_inItem013 := C_BLANK;
		v_item.l_inItem014 := gGSumGankingk;
		v_item.l_inItem015 := gGSumKokuZeiKingk;
		v_item.l_inItem016 := gGSumChihoZeiKngk;
		v_item.l_inItem017 := gGSumZeihikiBefKngk;
		v_item.l_inItem018 := gGSumZeihikiAftKngk;
		v_item.l_inItem019 := pGSumKngk;
		v_item.l_inItem020 := C_BLANK;
		v_item.l_inItem021 := C_BLANK;
		v_item.l_inItem022 := C_BLANK;
		v_item.l_inItem023 := l_inUserId;
		v_item.l_inItem024 := C_CHOHYO_ID;
		v_item.l_inItem025 := gSakuseiYmd;
		v_item.l_inItem026 := gGTaxErrFlg;
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> gGyomuYmd,
			l_inChohyoId	=> C_CHOHYO_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> 1,
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		gSeqNo := gSeqNo + 1;
		gGTaxErrFlg := '0';
		-- バッチの時
		IF l_inChohyoKbn = '1' THEN
			-- バッチ帳票印刷データ作成
			CALL pkPrtOk.insertPrtOk(
								l_inUserId,
								l_inItakuKaishaCd,
								gGyomuYmd,
								pkPrtOk.LIST_SAKUSEI_KBN_DAY(),
								C_CHOHYO_ID
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
-- REVOKE ALL ON PROCEDURE spipp005k00r01 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE, l_inUserId SREPORT_WK.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_inKjnYm text, l_outSqlCode OUT integer, l_outSqlErrM OUT text ) FROM PUBLIC;

-- Nested procedures (insertdata, insertgdata, inserttdata) have been inlined above
