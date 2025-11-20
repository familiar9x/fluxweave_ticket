




CREATE OR REPLACE PROCEDURE spipp003k00r01 ( 
	l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE,     -- 委託会社コード
 l_inUserId SREPORT_WK.USER_ID%TYPE,    -- ユーザーＩＤ
 l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, -- 帳票区分
 l_inKjnYm text,                   -- 基準年月
 l_inTsuchiYmd text,                   -- 通知日
 l_outSqlCode OUT integer,                     -- リターン値
 l_outSqlErrM OUT text                    -- エラーコメント
 ) AS $body$
DECLARE

--
-- * 著作権:Copyright(c)2007
-- * 会社名:JIP
-- *
-- * 概要　:償還記番号通知書（実質記番号管理）
-- *
-- * 引数　:
-- *        l_inItakuKaishaCd :委託会社コード
-- *        l_inUserId        :ユーザーID
-- *        l_inChohyoKbn     :帳票区分
-- *        l_inKjnYm         :基準年月
-- *        l_inTsuchiYmd     :通知日
-- *        l_outSqlCode      :リターン値
-- *        l_outSqlErrM      :エラーコメント
-- *
-- * 返り値:なし
-- *
-- * @author ASK
-- * @version $Id: SPIPP003K00R01.sql,v 1.4 2020/09/25 07:58:39 otsuka Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付   開発者名        目的
-- * -------------------------------------------------------------------
-- *　2007.05.07  叶（ASK）       新規作成
-- ***************************************************************************
--	/*==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_REPORT_ID  CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IPP30000311';    -- 帳票ＩＤ
	C_PROGRAM_ID CONSTANT varchar(50)              := 'SPIPP003K00R01'; -- プログラムＩＤ
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	gSeqNo           numeric;                            -- シーケンス
	gSeqStart        numeric;                            -- シーケンス開始
	gSeqEnd          numeric;                            -- シーケンス終了
	gBankNm          VJIKO_ITAKU.BANK_NM%TYPE;          -- 金融機関名称
	gGyomuYmd        SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE; -- 業務日付
	gMgrFlg          MPROCESS_CTL.CTL_VALUE%TYPE;       -- 銘柄名称制御フラグ取得('0'：略称 '1'：正式)
	gWTsuchiYmd      varchar(16);                      -- 通知日（西暦）
	gWrkKjnYm        varchar(16);                      -- 基準年月（西暦）
	gBun             varchar(300);                     -- 請求文章
	gProKenshuCd     numeric;                            -- 券種コード（編集用）
	gProMgrNm        MGR_KIHON.MGR_NM%TYPE;             -- 銘柄名称（正式 OR 略称）（編集用）
	gGenzonKngk      numeric;                            -- 現存額
	gAtenaNm         varchar(200);                     -- 宛名
	gSumKingk        numeric;                            -- 銘柄単位元本減債金額（合計）
	-- 読込データ
	gItakuKaishaCd   KBG_SHOKBG.ITAKU_KAISHA_CD%TYPE;   -- 委託会社コード
	gMgrCd           KBG_SHOKBG.MGR_CD%TYPE;            -- 銘柄コード
	gShokanKjt       KBG_SHOKBG.SHOKAN_KJT%TYPE;        -- 償還期日
	gKbgShokanKbn    KBG_SHOKBG.KBG_SHOKAN_KBN%TYPE;    -- 事由（償還区分）
	gKenshuCd        KBG_SHOKBG.KENSHU_CD%TYPE;         -- 券種コード
	gKibangoFrom     KBG_SHOKBG.KIBANGO_FROM%TYPE;      -- 記番号ＦＲＯＭ
	gKibangoTo       KBG_SHOKBG.KIBANGO_TO%TYPE;        -- 記番号ＴＯ
	gShokanYmd       KBG_SHOKIJ.SHOKAN_YMD%TYPE;        -- 償還日
	gTrhkCd          KBG_MTORISAKI.TRHK_CD%TYPE;        -- 取引先コード
	gPostNo          KBG_MTORISAKI.POST_NO%TYPE;        -- 郵便番号
	gTrhkAdd1        KBG_MTORISAKI.TRHK_ADD1%TYPE;      -- 送付先住所１
	gTrhkAdd2        KBG_MTORISAKI.TRHK_ADD2%TYPE;      -- 送付先住所２
	gTrhkAdd3        KBG_MTORISAKI.TRHK_ADD3%TYPE;      -- 送付先住所３
	gTrhkNm1         KBG_MTORISAKI.TRHK_NM1%TYPE;       -- 送付先名称１
	gTrhkNm2         KBG_MTORISAKI.TRHK_NM2%TYPE;       -- 送付先名称２
	gTrhkNm3         KBG_MTORISAKI.TRHK_NM3%TYPE;       -- 送付先名称３
	gIsinCd          MGR_KIHON.ISIN_CD%TYPE;            -- ＩＳＩＮコード
	gMgrNm           MGR_KIHON.MGR_NM%TYPE;             -- 銘柄の正式名称
	gMgrRnm          MGR_KIHON.MGR_RNM%TYPE;            -- 銘柄略称
	gKbgShokanKbnNm  SCODE.CODE_NM%TYPE;                -- 償還区分名称（事由）
	gMunitGensaiKngk numeric;                            -- 銘柄単位元本減債金額
	-- ブレイク確認用変数
	gBreakTrhkCd     KBG_SHOKBG.TRHK_CD%TYPE;           -- 取引先コード
	gBreakMgrCd      KBG_SHOKBG.MGR_CD%TYPE;            -- 銘柄コード
	gBreakShokanYmd  KBG_SHOKIJ.SHOKAN_YMD%TYPE;        -- 償還年月日
	gBreakShokanKjt  KBG_SHOKBG.SHOKAN_KJT%TYPE;        -- 償還期日
	gBreakShokanKbn  KBG_SHOKBG.KBG_SHOKAN_KBN%TYPE;    -- 償還区分（実質記番号用）
	v_item           TYPE_SREPORT_WK_ITEM;              -- Composite type for pkPrint.insertData
	--==============================================================================
	--                  カーソル定義                                                    
	--==============================================================================
	curMeisai CURSOR FOR
		-- 償還記番号通知書のSQL文を作成
		SELECT
			P02.ITAKU_KAISHA_CD,    -- 委託会社コード
			P02.MGR_CD,             -- 銘柄コード
			P02.SHOKAN_KJT,         -- 償還期日
			P02.KBG_SHOKAN_KBN,     -- 償還区分（実質記番号用）
			P02.KENSHU_CD,          -- 券種コード
			P02.KIBANGO_FROM,       -- 記番号ＦＲＯＭ
			P02.KIBANGO_TO,         -- 記番号ＴＯ
			P01.SHOKAN_YMD,         -- 償還年月日
			P05.TRHK_CD,            -- 取引先コード
			P05.POST_NO,            -- 郵便番号
			P05.TRHK_ADD1,          -- 送付先住所１
			P05.TRHK_ADD2,          -- 送付先住所２
			P05.TRHK_ADD3,          -- 送付先住所３
			P05.TRHK_NM1,           -- 送付先名称１
			P05.TRHK_NM2,           -- 送付先名称２
			P05.TRHK_NM3,           -- 送付先名称３
			VMG1.ISIN_CD,           -- ＩＳＩＮコード
			VMG1.MGR_NM,            -- 銘柄の正式名称
			VMG1.MGR_RNM,           -- 銘柄略称
			(
				SELECT
					CODE_NM
				FROM
					SCODE
				WHERE
					CODE_SHUBETSU = '226'
					AND CODE_VALUE = P02.KBG_SHOKAN_KBN
			) AS KBG_SHOKAN_KBN_NM, -- 償還区分名称
			(
				SELECT
					SUM(FURI_GENSAI_KNGK)
				FROM
					KBG_SHOKBG P02_1
				WHERE
					P02_1.ITAKU_KAISHA_CD = P02.ITAKU_KAISHA_CD
					AND P02_1.MGR_CD = P02.MGR_CD
					AND P02_1.SHOKAN_KJT = P02.SHOKAN_KJT
					AND P02_1.KBG_SHOKAN_KBN = P02.KBG_SHOKAN_KBN
					AND P02_1.TRHK_CD = P02.TRHK_CD
			) AS MUNIT_GENSAI_KNGK   -- 銘柄単位元本減債金額
		FROM
			KBG_SHOKBG P02,
			KBG_SHOKIJ P01,
			KBG_MTORISAKI P05,
			MGR_KIHON_VIEW VMG1
		WHERE
			P02.ITAKU_KAISHA_CD = P01.ITAKU_KAISHA_CD
			AND P02.MGR_CD = P01.MGR_CD
			AND P02.SHOKAN_KJT = P01.SHOKAN_KJT
			AND P02.KBG_SHOKAN_KBN = P01.KBG_SHOKAN_KBN
			AND P02.ITAKU_KAISHA_CD = P05.ITAKU_KAISHA_CD
			AND P02.TRHK_CD = P05.TRHK_CD
			AND P02.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
			AND P02.MGR_CD = VMG1.MGR_CD
			AND P02.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND P02.KBG_SHOKAN_KBN != '62'
			AND P02.KBG_SHOKAN_KBN != '63'
			AND P01.SHOKAN_YMD LIKE l_inKjnYm || '%'
			AND VMG1.JTK_KBN != '2'
			AND VMG1.JTK_KBN != '5'
			AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
			AND VMG1.MGR_STAT_KBN = '1'
			AND VMG1.KK_KANYO_FLG = '2'
		ORDER BY
			P05.TRHK_CD,
			VMG1.ISIN_CD,
			P01.SHOKAN_YMD,
			P02.KBG_SHOKAN_KBN,
			P02.KENSHU_CD,
			P02.KIBANGO_FROM;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 入力パラメータチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inUserId)::text, '') = ''
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''
	OR coalesce(trim(both l_inKjnYm)::text, '') = ''
	THEN
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := 'パラメータエラー';
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, l_outSqlErrM);
		RETURN;
	END IF;
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '引数');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '委託会社コード:"' || l_inItakuKaishaCd || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, 'ユーザーＩＤ:"' || l_inUserId || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '帳票区分:"' || l_inChohyoKbn || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '基準年月:"' || l_inKjnYm || '"');
	-- 自行・委託会社マスタ情報取得
	BEGIN
		SELECT
			BANK_NM  -- 金融機関名称
		INTO STRICT
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
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '自行・委託会社マスタ情報:"' || gBankNm || '"');
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '業務日付:"' || gGyomuYmd || '"');
	-- 通知日の西暦変換
	gWTsuchiYmd := '      年  月  日';
	IF (trim(both l_inTsuchiYmd) IS NOT NULL AND (trim(both l_inTsuchiYmd))::text <> '') THEN
		gWTsuchiYmd := pkDate.seirekiChangeSuppressNenGappi(l_inTsuchiYmd);
	END IF;
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '通知日（西暦変換後）"' || gWTsuchiYmd || '"');
	-- 基準年月の西暦変換
	gWrkKjnYm := REPLACE(pkDate.seirekiChangeSuppressNenGappi(l_inKjnYm || '01'),' 1日', '');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '基準年月（西暦変換後）"' || gWrkKjnYm || '"');
	-- 基準年月＋請求文章取得
	gBun := (gWrkKjnYm || SPIPP003K00R01_createBun(C_REPORT_ID, '00'));
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '請求文章を取得しました。');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, gBun);
	-- 処理制御マスタから銘柄名称制御フラグ取得
	gMgrFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'getMgrNm01', '0');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '銘柄名称制御フラグ:"' || gMgrFlg || '"');
	-- 帳票ワーク削除
	DELETE FROM SREPORT_WK
	WHERE
		KEY_CD = l_inItakuKaishaCd      -- 識別コード
		AND USER_ID = l_inUserId        -- ユーザーＩＤ
		AND CHOHYO_KBN = l_inChohyoKbn  -- 帳票区分
		AND SAKUSEI_YMD = gGyomuYmd     -- 作成日付
		AND CHOHYO_ID = C_REPORT_ID;   -- 帳票ＩＤ
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '削除条件');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '識別コード:"' || l_inItakuKaishaCd || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, 'ユーザーＩＤ:"' || l_inUserId || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '帳票区分:"' || l_inChohyoKbn || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '作成日付:"' || gGyomuYmd || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '帳票ＩＤ:"' || C_REPORT_ID || '"');
	-- 変数初期化
	gItakuKaishaCd   := ' '; -- 委託会社コード（読込データ）
	gBreakTrhkCd     := ' '; -- 取引先コード（ブレイク確認用）
	gBreakMgrCd      := ' '; -- 銘柄コード（ブレイク確認用）
	gBreakShokanYmd  := ' '; -- 償還年月日（ブレイク確認用）
	gBreakShokanKjt  := ' '; -- 償還期日（ブレイク確認用）
	gBreakShokanKbn  := ' '; -- 償還区分（実質記番号用）（ブレイク確認用）
	gSeqNo           := 1;   -- シーケンス初期化
	gSeqStart        := 0;   -- シーケンス開始
	gSeqEnd          := 0;   -- シーケンス終了
	gMunitGensaiKngk := 0;   -- 銘柄単位元本減債金額
	gSumKingk        := 0;   -- 銘柄単位元本減債金額（合計）
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, gGyomuYmd, C_REPORT_ID);
	-- データ読込
	FOR recMeisai IN curMeisai
	LOOP
		-- 初回時
		IF gItakuKaishaCd = ' ' THEN
			gItakuKaishaCd   := recMeisai.ITAKU_KAISHA_CD;   -- 委託会社コード
			gMgrCd           := recMeisai.MGR_CD;            -- 銘柄コード
			gShokanKjt       := recMeisai.SHOKAN_KJT;        -- 償還期日
			gKbgShokanKbn    := recMeisai.KBG_SHOKAN_KBN;    -- 事由（償還区分）
			gKenshuCd        := recMeisai.KENSHU_CD;         -- 券種コード
			gKibangoFrom     := recMeisai.KIBANGO_FROM;      -- 記番号ＦＲＯＭ
			gKibangoTo       := recMeisai.KIBANGO_TO;        -- 記番号ＴＯ
			gShokanYmd       := recMeisai.SHOKAN_YMD;        -- 償還年月日
			gTrhkCd          := recMeisai.TRHK_CD;           -- 取引先コード
			gPostNo          := recMeisai.POST_NO;           -- 郵便番号
			gTrhkAdd1        := recMeisai.TRHK_ADD1;         -- 送付先住所１
			gTrhkAdd2        := recMeisai.TRHK_ADD2;         -- 送付先住所２
			gTrhkAdd3        := recMeisai.TRHK_ADD3;         -- 送付先住所３
			gTrhkNm1         := recMeisai.TRHK_NM1;          -- 送付先名称１
			gTrhkNm2         := recMeisai.TRHK_NM2;          -- 送付先名称２
			gTrhkNm3         := recMeisai.TRHK_NM3;          -- 送付先名称３
			gIsinCd          := recMeisai.ISIN_CD;           -- ＩＳＩＮコード
			gMgrNm           := recMeisai.MGR_NM;            -- 銘柄の正式名称
			gMgrRnm          := recMeisai.MGR_RNM;           -- 銘柄略称
			gKbgShokanKbnNm  := recMeisai.KBG_SHOKAN_KBN_NM; -- 償還区分名称（事由）
			gMunitGensaiKngk := recMeisai.MUNIT_GENSAI_KNGK; -- 銘柄単位元本減債金額
		-- 初回でない時
		ELSE
			-- 「取引先コード」、「銘柄コード」、「償還期日」、
			-- 「償還日」、「券種コード」、「償還区分」がブレイクしなく、
			-- 「記番号ＦＲＯＭ」が１データ前の「記番号ＴＯ」+ 1 の時
			IF  gTrhkCd       = recMeisai.TRHK_CD
			AND gMgrCd        = recMeisai.MGR_CD
			AND gShokanKjt    = recMeisai.SHOKAN_KJT
			AND gShokanYmd    = recMeisai.SHOKAN_YMD
			AND gKenshuCd     = recMeisai.KENSHU_CD
			AND gKbgShokanKbn = recMeisai.KBG_SHOKAN_KBN
			AND recMeisai.KIBANGO_FROM = (gKibangoTo + 1) THEN
				-- 変数再セット（記番号ＴＯ）
				gKibangoTo := recMeisai.KIBANGO_TO;
			ELSE
				-- 登録前編集 ＋ 帳票ワーク登録処理 (inlined from SPIPP003K00R01_insertData)
				-- 券種コード編集
				IF gKenshuCd = 0 THEN
					gProKenshuCd := NULL;
				ELSE
					gProKenshuCd := gKenshuCd / 1000;
				END IF;
				-- 銘柄名称（正式 OR 略称）編集
				IF gMgrFlg = '1' THEN
					gProMgrNm := SUBSTR(gMgrNm, 1, 50);
				ELSE
					gProMgrNm := gMgrRnm;
				END IF;
				-- 現存額
				gGenzonKngk := pkIpaKibango.getKjnZndkTrhk(l_inItakuKaishaCd, gMgrCd, gShokanYmd, gTrhkCd, gKbgShokanKbn);
				-- 宛名編集「御中」付きの宛名を取得する
				gAtenaNm := pkIpaKibango.getMadoFutoAtenaYoko(gTrhkNm1, gTrhkNm2, gTrhkNm3);
				-- 初回でなく取引先コードがブレイク時
				IF gSeqNo != 1
				AND gBreakTrhkCd != gTrhkCd THEN
					-- 帳票ワーク更新 (inlined from updateWork)
					gSeqStart := gSeqEnd + 1;
					gSeqEnd := gSeqNo - 1;
					UPDATE SREPORT_WK SET
						ITEM021 = gSumKingk::text
					WHERE
						KEY_CD = l_inItakuKaishaCd
						AND USER_ID = l_inUserId
						AND CHOHYO_KBN = l_inChohyoKbn
						AND SAKUSEI_YMD = gGyomuYmd
						AND CHOHYO_ID = C_REPORT_ID
						AND SEQ_NO BETWEEN gSeqStart AND gSeqEnd;
					-- 銘柄単位元本減債金額（合計）
					gSumKingk := gMunitGensaiKngk;
				ELSE
					IF gBreakMgrCd != gMgrCd
					OR gBreakShokanYmd != gShokanYmd
					OR gBreakShokanKjt != gShokanKjt
					OR gBreakShokanKbn != gKbgShokanKbn THEN
						gSumKingk := gSumKingk + gMunitGensaiKngk;
					END IF;
				END IF;
				-- 帳票ワーク登録 (converted to composite type)
				v_item := ROW();
				v_item.l_inItem001 := gWTsuchiYmd;
				v_item.l_inItem002 := gPostNo;
				v_item.l_inItem003 := gTrhkAdd1;
				v_item.l_inItem004 := gTrhkAdd2;
				v_item.l_inItem005 := gTrhkAdd3;
				v_item.l_inItem006 := gtrhkCd;
				v_item.l_inItem007 := gAtenaNm;
				v_item.l_inItem008 := gBankNm;
				v_item.l_inItem009 := gBun;
				v_item.l_inItem010 := gIsinCd;
				v_item.l_inItem011 := gProMgrNm;
				v_item.l_inItem012 := gShokanKjt;
				v_item.l_inItem013 := gShokanYmd;
				v_item.l_inItem014 := gKbgShokanKbn;
				v_item.l_inItem015 := gKbgShokanKbnNm;
				v_item.l_inItem016 := gMunitGensaiKngk;
				v_item.l_inItem017 := gProKenshuCd;
				v_item.l_inItem018 := gKibangoFrom;
				v_item.l_inItem019 := gKibangoTo;
				v_item.l_inItem020 := gGenzonKngk;
				CALL pkPrint.insertData(
					l_inKeyCd      => l_inItakuKaishaCd,
					l_inUserId     => l_inUserId,
					l_inChohyoKbn  => l_inChohyoKbn,
					l_inSakuseiYmd => gGyomuYmd,
					l_inChohyoId   => C_REPORT_ID,
					l_inSeqNo      => gSeqNo::integer,
					l_inHeaderFlg  => 1,
					l_inItem       => v_item,
					l_inKousinId   => l_inUserId,
					l_inSakuseiId  => l_inUserId
				);
				gSeqNo := gSeqNo + 1;
				-- ブレイク確認用変数へ格納
				gBreakTrhkCd    := gTrhkCd;       -- 取引先コード
				gBreakMgrCd     := gMgrCd;        -- 銘柄コード
				gBreakShokanYmd := gShokanYmd;    -- 償還年月日
				gBreakShokanKjt := gShokanKjt;    -- 償還期日
				gBreakShokanKbn := gKbgShokanKbn; -- 償還区分（実質記番号用）
				-- 変数セット
				gItakuKaishaCd   := recMeisai.ITAKU_KAISHA_CD;   -- 委託会社コード
				gMgrCd           := recMeisai.MGR_CD;            -- 銘柄コード
				gShokanKjt       := recMeisai.SHOKAN_KJT;        -- 償還期日
				gKbgShokanKbn    := recMeisai.KBG_SHOKAN_KBN;    -- 事由（償還区分）
				gKenshuCd        := recMeisai.KENSHU_CD;         -- 券種コード
				gKibangoFrom     := recMeisai.KIBANGO_FROM;      -- 記番号ＦＲＯＭ
				gKibangoTo       := recMeisai.KIBANGO_TO;        -- 記番号ＴＯ
				gShokanYmd       := recMeisai.SHOKAN_YMD;        -- 償還年月日
				gTrhkCd          := recMeisai.TRHK_CD;           -- 取引先コード
				gPostNo          := recMeisai.POST_NO;           -- 郵便番号
				gTrhkAdd1        := recMeisai.TRHK_ADD1;         -- 送付先住所１
				gTrhkAdd2        := recMeisai.TRHK_ADD2;         -- 送付先住所２
				gTrhkAdd3        := recMeisai.TRHK_ADD3;         -- 送付先住所３
				gTrhkNm1         := recMeisai.TRHK_NM1;          -- 送付先名称１
				gTrhkNm2         := recMeisai.TRHK_NM2;          -- 送付先名称２
				gTrhkNm3         := recMeisai.TRHK_NM3;          -- 送付先名称３
				gIsinCd          := recMeisai.ISIN_CD;           -- ＩＳＩＮコード
				gMgrNm           := recMeisai.MGR_NM;            -- 銘柄の正式名称
				gMgrRnm          := recMeisai.MGR_RNM;           -- 銘柄略称
				gKbgShokanKbnNm  := recMeisai.KBG_SHOKAN_KBN_NM; -- 償還区分名称（事由）
				gMunitGensaiKngk := recMeisai.MUNIT_GENSAI_KNGK; -- 銘柄単位元本減債金額
			END IF;
		END IF;
	END LOOP;
	-- 最終レコードを処理する
	IF gItakuKaishaCd = ' ' THEN
		-- 帳票ワーク登録 (converted to composite type)
		v_item := ROW();
		v_item.l_inItem001 := gWTsuchiYmd;
		v_item.l_inItem022 := '対象データなし';
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd, -- 識別コード
			l_inUserId     => l_inUserId,        -- ユーザＩＤ
			l_inChohyoKbn  => l_inChohyoKbn,     -- 帳票区分
			l_inSakuseiYmd => gGyomuYmd,         -- 作成日付
			l_inChohyoId   => C_REPORT_ID,       -- 帳票ＩＤ
			l_inSeqNo      => gSeqNo::integer,   -- シーケンス
			l_inHeaderFlg  => 1,                 -- ヘッダフラグ
			l_inItem       => v_item,            -- アイテム
			l_inKousinId   => l_inUserId,        -- 更新者
			l_inSakuseiId  => l_inUserId          -- 作成者
		);
--		pkLog.debug(l_inUserId, C_PROGRAM_ID, '対象データなし');
	ELSE
		-- 登録前編集 ＋ 帳票ワーク登録処理 (inlined from SPIPP003K00R01_insertData)
		-- 券種コード編集
		IF gKenshuCd = 0 THEN
			gProKenshuCd := NULL;
		ELSE
			gProKenshuCd := gKenshuCd / 1000;
		END IF;
		-- 銘柄名称（正式 OR 略称）編集
		IF gMgrFlg = '1' THEN
			gProMgrNm := SUBSTR(gMgrNm, 1, 50);
		ELSE
			gProMgrNm := gMgrRnm;
		END IF;
		-- 現存額
		gGenzonKngk := pkIpaKibango.getKjnZndkTrhk(l_inItakuKaishaCd, gMgrCd, gShokanYmd, gTrhkCd, gKbgShokanKbn);
		-- 宛名編集「御中」付きの宛名を取得する
		gAtenaNm := pkIpaKibango.getMadoFutoAtenaYoko(gTrhkNm1, gTrhkNm2, gTrhkNm3);
		-- 初回でなく取引先コードがブレイク時
		IF gSeqNo != 1
		AND gBreakTrhkCd != gTrhkCd THEN
			-- 帳票ワーク更新 (inlined from updateWork)
			gSeqStart := gSeqEnd + 1;
			gSeqEnd := gSeqNo - 1;
			UPDATE SREPORT_WK SET
				ITEM021 = gSumKingk::text
			WHERE
				KEY_CD = l_inItakuKaishaCd
				AND USER_ID = l_inUserId
				AND CHOHYO_KBN = l_inChohyoKbn
				AND SAKUSEI_YMD = gGyomuYmd
				AND CHOHYO_ID = C_REPORT_ID
				AND SEQ_NO BETWEEN gSeqStart AND gSeqEnd;
			-- 銘柄単位元本減債金額（合計）
			gSumKingk := gMunitGensaiKngk;
		ELSE
			IF gBreakMgrCd != gMgrCd
			OR gBreakShokanYmd != gShokanYmd
			OR gBreakShokanKjt != gShokanKjt
			OR gBreakShokanKbn != gKbgShokanKbn THEN
				gSumKingk := gSumKingk + gMunitGensaiKngk;
			END IF;
		END IF;
		-- 帳票ワーク登録 (converted to composite type)
		v_item := ROW();
		v_item.l_inItem001 := gWTsuchiYmd;
		v_item.l_inItem002 := gPostNo;
		v_item.l_inItem003 := gTrhkAdd1;
		v_item.l_inItem004 := gTrhkAdd2;
		v_item.l_inItem005 := gTrhkAdd3;
		v_item.l_inItem006 := gtrhkCd;
		v_item.l_inItem007 := gAtenaNm;
		v_item.l_inItem008 := gBankNm;
		v_item.l_inItem009 := gBun;
		v_item.l_inItem010 := gIsinCd;
		v_item.l_inItem011 := gProMgrNm;
		v_item.l_inItem012 := gShokanKjt;
		v_item.l_inItem013 := gShokanYmd;
		v_item.l_inItem014 := gKbgShokanKbn;
		v_item.l_inItem015 := gKbgShokanKbnNm;
		v_item.l_inItem016 := gMunitGensaiKngk;
		v_item.l_inItem017 := gProKenshuCd;
		v_item.l_inItem018 := gKibangoFrom;
		v_item.l_inItem019 := gKibangoTo;
		v_item.l_inItem020 := gGenzonKngk;
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd,
			l_inUserId     => l_inUserId,
			l_inChohyoKbn  => l_inChohyoKbn,
			l_inSakuseiYmd => gGyomuYmd,
			l_inChohyoId   => C_REPORT_ID,
			l_inSeqNo      => gSeqNo::integer,
			l_inHeaderFlg  => 1,
			l_inItem       => v_item,
			l_inKousinId   => l_inUserId,
			l_inSakuseiId  => l_inUserId
		);
		gSeqNo := gSeqNo + 1;
		-- 帳票ワーク更新 (inlined from SPIPP003K00R01_updateWork)
		gSeqStart := gSeqEnd + 1;
		gSeqEnd := gSeqNo - 1;
		UPDATE SREPORT_WK SET
			ITEM021 = gSumKingk::text
		WHERE
			KEY_CD = l_inItakuKaishaCd
			AND USER_ID = l_inUserId
			AND CHOHYO_KBN = l_inChohyoKbn
			AND SAKUSEI_YMD = gGyomuYmd
			AND CHOHYO_ID = C_REPORT_ID
			AND SEQ_NO BETWEEN gSeqStart AND gSeqEnd;
	END IF;
	-- 正常終了
	l_outSqlCode := pkconstant.success();
	l_outSqlErrM := '';
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
-- REVOKE ALL ON PROCEDURE spipp003k00r01 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE, l_inUserId SREPORT_WK.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_inKjnYm text, l_inTsuchiYmd text, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spipp003k00r01_createbun (l_inReportId TEXT, l_inPatternCd BUN.BUN_PATTERN_CD%TYPE) RETURNS varchar AS $body$
DECLARE

	-- 請求文章（ワーク）
	aryBun Pkipabun.BUN_ARRAY;
	wkBun  varchar(200) := NULL;
BEGIN
	-- 請求文章の取得
	arybun := pkIpaBun.getBun(l_inReportId, l_inPatternCd);
	FOR i IN 0..coalesce(cardinality(aryBun), 0) - 1 LOOP
		-- 100byteまで全角スペース埋めして、請求文章を連結
		IF i = 0 THEN
			wkBun := wkBun || RPAD(arybun[i], 88, ' ');
		ELSE
			wkBun := wkBun || RPAD(arybun[i], 100, ' ');
		END IF;
	END LOOP;
RETURN wkBun;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spipp003k00r01_createbun (l_inReportId TEXT, l_inPatternCd BUN.BUN_PATTERN_CD%TYPE) FROM PUBLIC;




-- Nested procedures spipp003k00r01_insertdata and spipp003k00r01_updatework have been inlined into main procedure