CREATE OR REPLACE PROCEDURE spipi066k00r01 (
	l_inKijunYm TEXT,		-- 基準年月
	l_inItakuKaishaCd TEXT,		-- 委託会社コード
	l_inUserId TEXT,		-- ユーザーID
	l_inChohyoKbn TEXT,		-- 帳票区分
	l_inGyomuYmd TEXT,		-- 業務日付
	l_outSqlCode OUT integer,		-- リターン値
	l_outSqlErrM OUT text	-- エラーコメント
) AS $body$
DECLARE

--
--/* 著作権:Copyright(c)2004
--/* 会社名:JIP
--/* 概要　:未収・前受収益一覧表出力指示画面の入力条件により、未収・前受収益一覧表を作成する。
--/* 引数　:l_inKijunYm		IN	TEXT		基準年月
--/* 　　　 l_inItakuKaishaCd	IN	TEXT		委託会社コード
--/* 　　　 l_inUserId		IN	TEXT		ユーザーID
--/* 　　　 l_inChohyoKbn		IN	TEXT		帳票区分
--/* 　　　 l_inGyomuYmd		IN	TEXT		業務日付
--/* 　　　 l_outSqlCode		OUT INTEGER	 リターン値
--/* 　　　 l_outSqlErrM		OUT VARCHAR	エラーコメント
--/* 返り値:なし
--/*@version $Id: SPIPI066K00R01.SQL,v 1.13 2023/04/29 06:20:49 kentaro_ikeda Exp $
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.06.23	JIP			 新規作成
--/*	2005.10.13	中山進(ASK)	「対象データなし」追加
--/*　2005.10.26	海老澤 智(ASK)	未収前受収益計算を行うよう修正
--/*　2005.10.27	海老澤 智(ASK)	COMMIT,ROLLBACK削除
--/*	2007.02.23	山下 健太(NOA)	併存銘柄チェックを削除
--/*								(PKIPAKESSANHOSEIで手数料計算結果登録時に判定している為)
--/*　2023.02.20	張奇（USI）		インボイス制度対応
--/*
--***************************************************************************
--
--==============================================================================
--					デバッグ機能													
--==============================================================================
	DEBUG	numeric(1)	:= 0;
--==============================================================================
--					定数定義													
--==============================================================================
	RTN_OK				CONSTANT integer	:= 0;						-- 正常
	RTN_NG				CONSTANT integer	:= 1;						-- 予期したエラー
	RTN_NODATA			CONSTANT integer	:= 2;						-- データなし
	RTN_FATAL			CONSTANT integer	:= 99;						-- 予期せぬエラー
	REPORT_ID			CONSTANT char(11)	:= 'IPI30006611';			-- 帳票ID
	-- 書式フォーマット
	FMT_HAKKO_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	FMT_RBR_KNGK_J		CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 利払金額
	FMT_SHOKAN_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 償還金額
	-- 書式フォーマット（外資）
	FMT_HAKKO_KNGK_F	CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99'; -- 発行金額
	FMT_RBR_KNGK_F		CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99'; -- 利払金額
	FMT_SHOKAN_KNGK_F	CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99'; -- 償還金額
--==============================================================================
--					変数定義													
--==============================================================================
	gRtnCd				integer := RTN_OK;						-- リターンコード
	gSeqNo				integer := 0;							-- シーケンス
	-- 編集項目
	gEditBankRnm		VJIKO_ITAKU.BANK_RNM%TYPE;					-- 銀行略称
	-- 書式フォーマット
	gFmtHakkoKngk		varchar(21) := NULL;					-- 発行金額
	gFmtRbrKngk		 varchar(21) := NULL;						-- 利払金額
	gFmtShokanKngk		varchar(21) := NULL;					-- 償還金額
	gJikoDaikoKbn		VJIKO_ITAKU.JIKO_DAIKO_KBN%TYPE;			-- 自行代行区分
	gItakuKaishaRnm		VJIKO_ITAKU.BANK_RNM%TYPE;					-- 委託会社略称		
	gBunsho				varchar(150) := NULL;					-- インボイス文章
	gInvoiceFlg			MOPTION_KANRI.OPTION_FLG%TYPE;				-- インボイスオプションフラグ
	wAryBun				pkIpaBun.BUN_ARRAY;							-- 文章情報作業用
--==============================================================================
--					カーソル定義													
--==============================================================================
	curMeisai CURSOR FOR
		SELECT	MCD1.CODE_NM AS JTK_KBN_NM,								-- 受託区分名称
				MCD2.CODE_NM AS MIKISYU_KBN_NM,							-- 未既収区分名称
				M64.TSUKA_NM AS TSUKA_CD_NM,							-- 通貨コード名称
				MG1.ISIN_CD,											-- ＩＳＩＮコード
				T05.MGR_CD,												-- 銘柄コード
				MG1.MGR_RNM,											-- 銘柄略称
				MCD3.CODE_RNM AS TESU_SHURUI_NM,						-- 手数料種類名称
				T05.KIJUN_ZNDK,											-- 基準残高
				T05.NYUKIN_YMD,											-- 入金日
				T05.OWN_DF_BUNSHI,										-- 自行分配率(分子)
				T05.OWN_DF_BUNBO,										-- 自行分配率(分母)
				T05.TESU_RITSU_BUNSHI,									-- 手数料率分子
				T05.TESU_RITSU_BUNBO,									-- 手数料率分母
				(T05.TESU_NUKI_KNGK + T05.SZEI_KNGK) AS TESU_KNGK,		-- 手数料
				T05.SZEI_KNGK,											-- 消費税額
				T05.CHOKYU_KJT,											-- 徴求期日
				T05.CHOKYU_YMD,											-- 徴求日
				T05.DDMM_CNT_KBN,										-- 日数・月数区分
				T05.HOSEI_BUNSHI_ST_YMD,								-- 補正期間分子開始日
				T05.HOSEI_BUNSHI_ED_YMD,								-- 補正期間分子終了日
				T05.HOSEI_BUNSHI_DM_CNT_KBN,							-- 補正期間分子日数・月数
				T05.HOSEI_BUNBO_ST_YMD,									-- 補正期間分母開始日
				T05.HOSEI_BUNBO_ED_YMD,									-- 補正期間分母終了日
				T05.HOSEI_BUNBO_DM_CNT_KBN,								-- 補正期間分母日数・月数
				(T05.HOSEI_TESU_NUKI_KNGK + T05.HOSEI_SZEI_KNGK) AS HOSEI_KNGK, -- 補正額
				T05.HOSEI_SZEI_KNGK,									-- 補正_消費税額
				MCD4.CODE_NM AS CALC_PATTERN_NM,						-- 計算パターン名称
				VJI.JIKO_DAIKO_KBN,										-- 自行代行区分
				VJI.BANK_RNM,											-- 銀行略称
				MG1.HAKKO_TSUKA_CD,										-- 発行通貨コード
				MG1.RBR_TSUKA_CD,										-- 利払通貨コード
				MG1.SHOKAN_TSUKA_CD 										-- 償還通貨コード
		FROM	MISYU_MAEUKE T05,
				MGR_KIHON MG1,
				MGR_STS MG0,
				MTSUKA M64,
				SCODE MCD1,
				SCODE MCD2,
				SCODE MCD3,
				SCODE MCD4,
				VJIKO_ITAKU VJI
		WHERE	T05.HOSEI_KIJUN_YM = l_inKijunYm
		AND	 T05.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND	 T05.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
		AND	 T05.MGR_CD			 = MG1.MGR_CD
		AND	 MG1.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
		AND	 MG1.MGR_CD			 = MG0.MGR_CD
		AND	 MG0.MGR_STAT_KBN	 = '1'	-- 承認済み	(IP-03831)
		AND	 MG0.MASSHO_FLG		 != '1'	-- 未取消	(IP-03831)
		AND	 (trim(both MG1.ISIN_CD) IS NOT NULL AND (trim(both MG1.ISIN_CD))::text <> '')
		AND	 T05.TSUKA_CD = M64.TSUKA_CD
		AND	 T05.JTK_KBN = MCD1.CODE_VALUE
		AND	 MCD1.CODE_SHUBETSU = '112'
		AND	 T05.MISHU_MAEUKE_KBN = MCD2.CODE_VALUE
		AND	 MCD2.CODE_SHUBETSU = '126'
		AND	 T05.TESU_SHURUI_CD = MCD3.CODE_VALUE
		AND	 MCD3.CODE_SHUBETSU = '111'
		AND	 T05.CALC_PATTERN_CD = MCD4.CODE_VALUE
		AND	 MCD4.CODE_SHUBETSU = '105'
		AND	 VJI.KAIIN_ID = l_inItakuKaishaCd 
		ORDER BY	T05.JTK_KBN,
					T05.MISHU_MAEUKE_KBN,
					T05.TSUKA_CD,
					T05.MGR_CD;
					
	l_inItem 	   		TYPE_SREPORT_WK_ITEM := ROW();
--==============================================================================
--	メイン処理																		
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPI066K00R01 START');END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inKijunYm::text), '') = ''
	OR coalesce(trim(both l_inItakuKaishaCd::text), '') = ''
	OR coalesce(trim(both l_inUserId::text), '') = ''
	OR coalesce(trim(both l_inChohyoKbn::text), '') = ''
	OR coalesce(trim(both l_inGyomuYmd::text), '') = ''
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error(l_inUserId, REPORT_ID, 'SQLERRM:'||'');
		RETURN;
	END IF;
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
		WHERE	KEY_CD		= l_inItakuKaishaCd
		AND		USER_ID		= l_inUserId
		AND		CHOHYO_KBN	= l_inChohyoKbn
		AND		SAKUSEI_YMD	= l_inGyomuYmd
		AND		CHOHYO_ID	= REPORT_ID;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	-- インボイスオプションフラグを取得する
	gInvoiceFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd, 'INVOICE_C', '0');
	-- インボイスオプションフラグが"1"の場合
	IF gInvoiceFlg = '1' THEN
	    -- 請求文章取得
	    wAryBun := pkIpaBun.getBun(REPORT_ID, 'L0');
	    FOR i IN 0..coalesce(cardinality(wAryBun), 0) - 1 LOOP
	         IF i = 0 THEN
	             gBunsho := wAryBun[i];
	         END IF;
	    END LOOP;
	END IF;
	-- 未収前受収益計算
	gRtnCd := pkIpaKessanHosei.calcHosei(l_inItakuKaishaCd, l_inKijunYm, '1', l_inUserId);
	IF gRtnCd <> RTN_OK THEN
		l_outSqlCode := gRtnCd;
		l_outSqlErrM := '';
		RETURN;
	END IF;
	-- データ取得
	FOR recMeisai IN curMeisai LOOP
		gSeqNo := gSeqNo + 1;
		-- 銀行略称
		gEditBankRnm := NULL;
		IF recMeisai.JIKO_DAIKO_KBN = '2' THEN
			gEditBankRnm := recMeisai.BANK_RNM;
		END IF;
		-- 書式フォーマットの設定
		-- 発行
		IF recMeisai.HAKKO_TSUKA_CD = 'JPY' THEN
			gFmtHakkoKngk := FMT_HAKKO_KNGK_J;
		ELSE
			gFmtHakkoKngk := FMT_HAKKO_KNGK_F;
		END IF;
		-- 利払
		IF recMeisai.RBR_TSUKA_CD = 'JPY' THEN
			gFmtRbrKngk := FMT_RBR_KNGK_J;
		ELSE
			gFmtRbrKngk := FMT_RBR_KNGK_F;
		END IF;
		-- 償還
		IF recMeisai.SHOKAN_TSUKA_CD = 'JPY' THEN
			gFmtShokanKngk := FMT_SHOKAN_KNGK_J;
		ELSE
			gFmtShokanKngk := FMT_SHOKAN_KNGK_F;
		END IF;
		-- 帳票ワークへデータを追加
		l_inItem.l_inItem001		:=	l_inUserId; 							-- ユーザＩＤ
		l_inItem.l_inItem002		:=	gEditBankRnm; 						-- 銀行略称
		l_inItem.l_inItem003		:=	l_inKijunYm; 							-- 入力基準年月
		l_inItem.l_inItem004		:=	recMeisai.JTK_KBN_NM; 				-- 受託区分名称
		l_inItem.l_inItem005		:=	recMeisai.MIKISYU_KBN_NM; 			-- 未既収区分名称
		l_inItem.l_inItem006		:=	recMeisai.TSUKA_CD_NM; 				-- 通貨コード名称
		l_inItem.l_inItem007		:=	recMeisai.ISIN_CD; 					-- ＩＳＩＮコード
		l_inItem.l_inItem008		:=	recMeisai.MGR_CD; 					-- 銘柄コード
		l_inItem.l_inItem009		:=	recMeisai.MGR_RNM; 					-- 銘柄略称
		l_inItem.l_inItem010		:=	recMeisai.TESU_SHURUI_NM; 			-- 手数料種類名称
		l_inItem.l_inItem011		:=	recMeisai.KIJUN_ZNDK; 				-- 基準残高
		l_inItem.l_inItem012		:=	recMeisai.NYUKIN_YMD; 				-- 入金日
		l_inItem.l_inItem013		:=	recMeisai.TESU_RITSU_BUNSHI; 			-- 手数料率分子
		l_inItem.l_inItem014		:=	recMeisai.TESU_RITSU_BUNBO; 			-- 手数料率分母
		l_inItem.l_inItem015		:=	recMeisai.OWN_DF_BUNSHI; 				-- 自行分配率(分子)
		l_inItem.l_inItem016		:=	recMeisai.OWN_DF_BUNBO; 				-- 自行分配率(分母)
		l_inItem.l_inItem017		:=	recMeisai.TESU_KNGK; 					-- 手数料
		l_inItem.l_inItem018		:=	recMeisai.SZEI_KNGK; 					-- 消費税額
		l_inItem.l_inItem019		:=	recMeisai.HOSEI_KNGK; 				-- 補正額
		l_inItem.l_inItem020		:=	recMeisai.HOSEI_SZEI_KNGK; 			-- 補正_消費税額
		l_inItem.l_inItem021		:=	recMeisai.CALC_PATTERN_NM; 			-- 計算パターン名称
		l_inItem.l_inItem022		:=	REPORT_ID; 							-- 帳票ＩＤ
		l_inItem.l_inItem023		:=	gFmtHakkoKngk; 						-- 発行金額書式フォーマット
		l_inItem.l_inItem024		:=	gFmtRbrKngk; 							-- 利払金額書式フォーマット
		l_inItem.l_inItem025		:=	gFmtShokanKngk; 						-- 償還金額書式フォーマット
		l_inItem.l_inItem027		:=	recMeisai.CHOKYU_KJT; 				-- 徴求期日
		l_inItem.l_inItem028		:=	recMeisai.CHOKYU_YMD; 				-- 徴求日
		l_inItem.l_inItem029		:=	recMeisai.NYUKIN_YMD; 				-- 入金日
		l_inItem.l_inItem030		:=	recMeisai.DDMM_CNT_KBN; 				-- 日数・月数区分
		l_inItem.l_inItem031		:=	recMeisai.HOSEI_BUNSHI_ST_YMD; 		-- 補正期間分子開始日
		l_inItem.l_inItem032		:=	recMeisai.HOSEI_BUNSHI_ED_YMD; 		-- 補正期間分子終了日
		l_inItem.l_inItem033		:=	recMeisai.HOSEI_BUNSHI_DM_CNT_KBN; 	-- 補正期間分子日数・月数
		l_inItem.l_inItem034		:=	recMeisai.HOSEI_BUNBO_ST_YMD; 		-- 補正期間分母開始日
		l_inItem.l_inItem035		:=	recMeisai.HOSEI_BUNBO_ED_YMD; 		-- 補正期間分母終了日
		l_inItem.l_inItem036		:=	recMeisai.HOSEI_BUNBO_DM_CNT_KBN; 	-- 補正期間分母日数・月数
		l_inItem.l_inItem037		:=	gBunsho; 								-- インボイス文章
		l_inItem.l_inItem038		:=	gInvoiceFlg; 							-- インボイスオプションフラグ

		CALL pkPrint.insertData(
			l_inKeyCd			=>	l_inItakuKaishaCd 					-- 識別コード
			,l_inUserId			=>	l_inUserId 							-- ユーザＩＤ
			,l_inChohyoKbn		=>	l_inChohyoKbn 						-- 帳票区分
			,l_inSakuseiYmd		=>	l_inGyomuYmd 						-- 作成年月日
			,l_inChohyoId		=>	REPORT_ID 							-- 帳票ＩＤ
			,l_inSeqNo			=>	gSeqNo 								-- 連番
			,l_inHeaderFlg		=>	'1'									-- ヘッダフラグ
			,l_inItem				=> 	l_inItem
			,l_inKousinId		=>	l_inUserId 							-- 更新者ID
			,l_inSakuseiId		=>	l_inUserId 							-- 作成者ID
		);
	END LOOP;
	IF gSeqNo = 0 THEN
		-- 対象データなし
		gRtnCd := RTN_NODATA;
	BEGIN
	SELECT
		VJ01.BANK_RNM,
		VJ01.JIKO_DAIKO_KBN
	INTO
		gItakuKaishaRnm,
		gJikoDaikoKbn
	FROM
		VJIKO_ITAKU VJ01
	WHERE
		VJ01.KAIIN_ID = l_inItakuKaishaCd;
	EXCEPTION
		WHEN no_data_found THEN
			gItakuKaishaRnm := NULL;
	END;		
		-- 委託会社略称
	-- 代行でなければ、委託会社略称は出力しない
	IF gJikoDaikoKbn <> '2' THEN
		gItakuKaishaRnm := NULL;
	END IF;		
		-- 帳票ワークへデータを追加
		l_inItem	:=	ROW();
		l_inItem.l_inItem001		:=	l_inUserId; 							-- ユーザID
		l_inItem.l_inItem002 		:= gItakuKaishaRnm;  						-- 委託会社略称
		l_inItem.l_inItem026		:=	'対象データなし';					--
		l_inItem.l_inItem022		:=	REPORT_ID; 							-- 帳票ＩＤ
		l_inItem.l_inItem037		:=	gBunsho; 								-- インボイス文章
		l_inItem.l_inItem038 		:=	gInvoiceFlg; 							-- インボイスオプションフラグ

		CALL pkPrint.insertData(
			l_inKeyCd			=>	l_inItakuKaishaCd 					-- 識別コード
			,l_inUserId			=>	l_inUserId 							-- ユーザＩＤ
			,l_inChohyoKbn		=>	l_inChohyoKbn 						-- 帳票区分
			,l_inSakuseiYmd		=>	l_inGyomuYmd 						-- 作成年月日
			,l_inChohyoId		=>	REPORT_ID 							-- 帳票ＩＤ
			,l_inSeqNo			=>	1									-- 連番
			,l_inHeaderFlg		=>	'1'									-- ヘッダフラグ
			,l_inItem			=>	l_inItem
			,l_inKousinId		=>	l_inUserId 							-- 更新者ID
			,l_inSakuseiId		=>	l_inUserId 							-- 作成者ID
		);
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPI066K00R01 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
--		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipi066k00r01 ( l_inKijunYm TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;