




CREATE OR REPLACE PROCEDURE spipi062k00r01_01 ( 
    l_inKijunYm TEXT,		-- 基準年月
 l_inEigyotenCd TEXT,		-- 営業店コード
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
--/* 概要　:営業店別手数料予定表出力指示画面の入力条件により、営業店別手数料予定表を作成する
--/* 引数　:l_inKijunYm		IN	TEXT		基準年月
--/* 　　　 l_inEigyotenCd	IN	TEXT		営業店コード
--/* 　　　 l_inItakuKaishaCd	IN	TEXT		委託会社コード
--/* 　　　 l_inUserId		IN	TEXT		ユーザーID
--/* 　　　 l_inChohyoKbn		IN	TEXT		帳票区分
--/* 　　　 l_inGyomuYmd		IN	TEXT		業務日付
--/* 　　　 l_outSqlCode		OUT	INTEGER		リターン値
--/* 　　　 l_outSqlErrM		OUT	VARCHAR	エラーコメント
--/* 返り値:なし
--/*@version $Id: SPIPI062K00R01_01.SQL,v 1.8 2023/04/29 06:24:51 kentaro_ikeda Exp $
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.06.16	JIP				新規作成
--/*　2005.10.27	海老澤 智(ASK)	COMMIT,ROLLBACK削除
--/*　2007.02.23	山下 健太(NOA)	併存銘柄チェックを削除
--/*								SPIPI062K00R01で手数料計算結果登録前に判定している為
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
	RTN_OK				CONSTANT numeric	:= 0;						-- 正常
	RTN_NG				CONSTANT numeric	:= 1;						-- 予期したエラー
	RTN_NODATA			CONSTANT numeric	:= 2;						-- データなし
	RTN_FATAL			CONSTANT numeric	:= 99;						-- 予期せぬエラー
	REPORT_ID			CONSTANT char(11)	:= 'IPI30006211';			-- 帳票ID
	-- 書式フォーマット
	FMT_HAKKO_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	FMT_RBR_KNGK_J		CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 利払金額
	FMT_SHOKAN_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 償還金額
	-- 書式フォーマット（外資）
	FMT_HAKKO_KNGK_F	CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 発行金額
	FMT_RBR_KNGK_F		CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 利払金額
	FMT_SHOKAN_KNGK_F	CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 償還金額
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd				numeric :=	RTN_OK;						-- リターンコード
	gSeqNo				numeric := 0;							-- シーケンス
	gSQL				varchar(2000) := NULL;				-- SQL編集
	-- 書式フォーマット
	gFmtHakkoKngk		varchar(21) := NULL;					-- 発行金額
	gFmtRbrKngk			varchar(21) := NULL;					-- 利払金額
	gFmtShokanKngk		varchar(21) := NULL;					-- 償還金額
	-- 編集項目
	gEditBankRnm		VJIKO_ITAKU.BANK_RNM%TYPE;					-- 銀行略称
	gEditDaiJtkKaishaNm	MBANK.BANK_RNM%TYPE;						-- 代表受託会社名[金融機関略称]
    gEditTesuKngk       decimal(14,2) := 0;						-- 手数料額
    gEditTesuSzei       decimal(16,2) := 0;						-- 内消費税
	-- DB取得項目
	gEigyotenCd			MHAKKOTAI.EIGYOTEN_CD%TYPE;					-- 営業店コード,
	gEigyotenRnm		MBUTEN.BUTEN_RNM%TYPE;						-- 営業店略称[部店略称]
	gTsukaCd			TESURYO.TSUKA_CD%TYPE;						-- 通貨コード
	gTsukaCdNn			MTSUKA.TSUKA_NM%TYPE;						-- 通貨コード名称[通貨出力用名称]
	gIsinCd				MGR_KIHON.ISIN_CD%TYPE;						-- ＩＳＩＮコード
	gMgrCd				MGR_KIHON.MGR_CD%TYPE;						-- 銘柄コード
	gMgrRnm				MGR_KIHON.MGR_RNM%TYPE;						-- 銘柄略称
	gHakkoYmd			MGR_KIHON.HAKKO_YMD%TYPE;					-- 発行年月日
	gFullShokanKjt		MGR_KIHON.FULLSHOKAN_KJT%TYPE;				-- 満期償還期日
	gShasaiTotal		MGR_KIHON.SHASAI_TOTAL%TYPE;				-- 社債の総額
	gDaiHyoJtkKaishaNm	MBANK.BANK_RNM%TYPE;						-- 代表受託会社名[金融機関略称]
	gChokyuYmd			TESURYO.CHOKYU_YMD%TYPE;					-- 徴求日
	gKijunZndk			TESURYO.KIJUN_ZNDK%TYPE;					-- 基準残高
	gTesuRitsuBunshi	TESURYO.TESU_RITSU_BUNSHI%TYPE;				-- 手数料率分子
	gTesuRitsuBunbo		TESURYO.TESU_RITSU_BUNBO%TYPE;				-- 手数料率分母
	gKichuBunDfBunshi	MGR_JUTAKUGINKO.KICHU_BUN_DF_BUNSHI%TYPE;	-- 期中分分配率(分子)
	gDfBunbo			TESURYO.DF_BUNBO%TYPE;						-- 分配率(分母)
	gOwnTesuKngk		TESURYO.OWN_TESU_KNGK%TYPE;					-- 自行手数料額(税抜)
	gOwnTesuSzei		TESURYO.OWN_TESU_SZEI%TYPE;					-- 自行消費税額
	gHoseiOwnTesuKngk	TESURYO.HOSEI_OWN_TESU_KNGK%TYPE;			-- 補正額＿自行手数料額(税抜)
	gHoseiOwnTesuSzei	TESURYO.HOSEI_OWN_TESU_SZEI%TYPE;			-- 補正額＿自行消費税額
	gDataSakuseiKbn		TESURYO.DATA_SAKUSEI_KBN%TYPE;				-- データ作成区分
	gShoriKbn			TESURYO.SHORI_KBN%TYPE;						-- 処理区分
	gJtkKbn				MGR_JUTAKUGINKO.JTK_KBN%TYPE;				-- 受託区分
	gHakkoTsukaCd		MGR_KIHON.HAKKO_TSUKA_CD%TYPE;				-- 発行通貨コード
	gRbrTsukaCd			MGR_KIHON.RBR_TSUKA_CD%TYPE;				-- 利払通貨コード
	gShokanTsukaCd		MGR_KIHON.SHOKAN_TSUKA_CD%TYPE;				-- 償還通貨コード
	gJikoDaikoKbn		VJIKO_ITAKU.JIKO_DAIKO_KBN%TYPE;			-- 自行代行区分
	gBankRnm			VJIKO_ITAKU.BANK_RNM%TYPE;					-- 銀行略称
	gItakuKaishaRnm		VJIKO_ITAKU.BANK_RNM%TYPE;					-- 委託会社略称
	gBunsho				varchar(150) := NULL;					-- インボイス文章
	gInvoiceFlg			MOPTION_KANRI.OPTION_FLG%TYPE;				-- インボイスオプションフラグ
	wAryBun				pkIpaBun.BUN_ARRAY;							-- 文章情報作業用
	-- カーソル
	curMeisai REFCURSOR;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPI062K00R01_01 START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inKijunYm)::text, '') = ''
	OR coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inUserId)::text, '') = ''
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''
	OR coalesce(trim(both l_inGyomuYmd)::text, '') = ''
	THEN
		-- 入力パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error(l_inUserId, REPORT_ID, 'SQLERRM:'||'');
		RETURN;
	END IF;
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;
	-- SQL編集 (inlined from nested procedure)
	gSQL := '';
	gSQL := gSQL || 'SELECT	M01.EIGYOTEN_CD,';									-- 営業店コード,
	gSQL := gSQL || '		M04.BUTEN_RNM,';									-- 部店略称
	gSQL := gSQL || '		T01.TSUKA_CD,';										-- 通貨コード
	gSQL := gSQL || '		M64.TSUKA_NM,';										-- 通貨出力用名称
	gSQL := gSQL || '		VMG1.ISIN_CD,';										-- ＩＳＩＮコード
	gSQL := gSQL || '		VMG1.MGR_CD,';										-- 銘柄コード
	gSQL := gSQL || '		VMG1.MGR_RNM,';										-- 銘柄略称
	gSQL := gSQL || '		VMG1.HAKKO_YMD,';									-- 発行年月日
	gSQL := gSQL || '		VMG1.FULLSHOKAN_KJT,';								-- 満期償還期日
	gSQL := gSQL || '		VMG1.SHASAI_TOTAL,';								-- 社債の総額
	gSQL := gSQL || '		M02.BANK_RNM,';										-- 金融機関略称
	gSQL := gSQL || '		T01.CHOKYU_YMD,';									-- 徴求日
	gSQL := gSQL || '		T01.KIJUN_ZNDK,';									-- 基準残高
	gSQL := gSQL || '		T01.TESU_RITSU_BUNSHI,';							-- 手数料率分子
	gSQL := gSQL || '		T01.TESU_RITSU_BUNBO,';								-- 手数料率分母
	gSQL := gSQL || '		MG61.KICHU_BUN_DF_BUNSHI,';							-- 期中分分配率(分子)
	gSQL := gSQL || '		T01.DF_BUNBO,';										-- 分配率(分母)
	gSQL := gSQL || '		T01.OWN_TESU_KNGK,';								-- 自行手数料額(税抜)
	gSQL := gSQL || '		T01.OWN_TESU_SZEI,';								-- 自行消費税額
	gSQL := gSQL || '		T01.HOSEI_OWN_TESU_KNGK,';							-- 補正額＿自行手数料額(税抜)
	gSQL := gSQL || '		T01.HOSEI_OWN_TESU_SZEI,';							-- 補正額＿自行消費税額
	gSQL := gSQL || '		T01.DATA_SAKUSEI_KBN,';								-- データ作成区分
	gSQL := gSQL || '		T01.SHORI_KBN,';									-- 処理区分
	gSQL := gSQL || '		MG61.JTK_KBN,';										-- 受託区分
	gSQL := gSQL || '		VMG1.HAKKO_TSUKA_CD,';								-- 発行通貨コード
	gSQL := gSQL || '		VMG1.RBR_TSUKA_CD,';									-- 利払通貨コード
	gSQL := gSQL || '		VMG1.SHOKAN_TSUKA_CD,';								-- 償還通貨コード
	gSQL := gSQL || '		VJI.JIKO_DAIKO_KBN,';								-- 自行代行区分
	gSQL := gSQL || '		VJI.BANK_RNM ';										-- 銀行略称
	gSQL := gSQL || 'FROM	TESURYO T01 ';										-- 手数料計算結果
	gSQL := gSQL || 'INNER JOIN MGR_KIHON_VIEW VMG1 ON T01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD AND T01.MGR_CD = VMG1.MGR_CD ';
	gSQL := gSQL || 'INNER JOIN MHAKKOTAI M01 ON VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD AND VMG1.HKT_CD = M01.HKT_CD ';
	gSQL := gSQL || 'INNER JOIN MBUTEN M04 ON M01.ITAKU_KAISHA_CD = M04.ITAKU_KAISHA_CD AND M01.EIGYOTEN_CD = M04.BUTEN_CD ';
	gSQL := gSQL || 'INNER JOIN MGR_JUTAKUGINKO MG61 ON T01.ITAKU_KAISHA_CD = MG61.ITAKU_KAISHA_CD AND T01.MGR_CD = MG61.MGR_CD AND MG61.FINANCIAL_SECURITIES_KBN = ''0'' ';
	gSQL := gSQL || 'INNER JOIN VJIKO_ITAKU VJI ON MG61.BANK_CD = VJI.OWN_BANK_CD AND VJI.KAIIN_ID = ''' || l_inItakuKaishaCd || ''' ';
	gSQL := gSQL || 'LEFT JOIN MGR_JUTAKUGINKO MG62 ON T01.ITAKU_KAISHA_CD = MG62.ITAKU_KAISHA_CD AND T01.MGR_CD = MG62.MGR_CD AND MG62.JTK_KBN = ''1'' ';
	gSQL := gSQL || 'LEFT JOIN MBANK M02 ON MG62.BANK_CD = M02.BANK_CD AND MG62.FINANCIAL_SECURITIES_KBN = M02.FINANCIAL_SECURITIES_KBN ';
	gSQL := gSQL || 'INNER JOIN MTSUKA M64 ON T01.TSUKA_CD = M64.TSUKA_CD ';
	gSQL := gSQL || 'WHERE	SUBSTR(T01.CHOKYU_YMD, 1, 6) = ''' || l_inKijunYm || ''' ';
	gSQL := gSQL || 'AND	T01.TESU_SHURUI_CD IN (''11'',''12'') ';
	gSQL := gSQL || 'AND	T01.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' ';
	gSQL := gSQL || 'AND	VMG1.SHORI_KBN = ''1'' ';	-- 承認済
	IF (trim(both l_inEigyotenCd) IS NOT NULL AND (trim(both l_inEigyotenCd))::text <> '') THEN
		gSQL := gSQL || 'AND	M01.EIGYOTEN_CD = ''' || l_inEigyotenCd || ''' ';
	END IF;
	gSQL := gSQL || 'ORDER BY	M01.EIGYOTEN_CD,';
	gSQL := gSQL || '			T01.TSUKA_CD,';
	gSQL := gSQL || '			VMG1.ISIN_CD ';
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
	-- カーソルオープン
	OPEN curMeisai FOR EXECUTE gSQL;
	-- データ取得
	LOOP
		FETCH curMeisai INTO	gEigyotenCd 					-- 営業店コード
								,gEigyotenRnm 				-- 営業店略称[部店略称]
								,gTsukaCd 					-- 通貨コード
								,gTsukaCdNn 					-- 通貨コード名称[通貨出力用名称]
								,gIsinCd 					-- ＩＳＩＮコード
								,gMgrCd 						-- 銘柄コード
								,gMgrRnm 					-- 銘柄略称
								,gHakkoYmd 					-- 発行年月日
								,gFullShokanKjt 				-- 満期償還期日
								,gShasaiTotal 				-- 社債の総額
								,gDaiHyoJtkKaishaNm 			-- 代表受託会社名[金融機関略称]
								,gChokyuYmd 					-- 徴求日
								,gKijunZndk 					-- 基準残高
								,gTesuRitsuBunshi 			-- 手数料率分子
								,gTesuRitsuBunbo 			-- 手数料率分母
								,gKichuBunDfBunshi 			-- 期中分分配率(分子)
								,gDfBunbo 					-- 分配率(分母)
								,gOwnTesuKngk 				-- 自行手数料額(税抜)
								,gOwnTesuSzei 				-- 自行消費税額
								,gHoseiOwnTesuKngk 			-- 補正額＿自行手数料額(税抜)
								,gHoseiOwnTesuSzei 			-- 補正額＿自行消費税額
								,gDataSakuseiKbn 			-- データ作成区分
								,gShoriKbn 					-- 処理区分
								,gJtkKbn 					-- 受託区分
								,gHakkoTsukaCd 				-- 発行通貨コード
								,gRbrTsukaCd 				-- 利払通貨コード
								,gShokanTsukaCd 				-- 償還通貨コード
								,gJikoDaikoKbn 				-- 自行代行区分
								,gBankRnm 					-- 銀行略称
								;
		EXIT WHEN NOT FOUND;/* apply on curMeisai */
		gSeqNo := gSeqNo + 1;
		-- 銀行略称
		gEditBankRnm := NULL;
		IF gJikoDaikoKbn = '2' THEN
			gEditBankRnm := gBankRnm;
		END IF;
		-- 代表受託会社名
		gEditDaiJtkKaishaNm := NULL;
		IF gJtkKbn = '2' THEN
			gEditDaiJtkKaishaNm := gDaiHyoJtkKaishaNm;
		END IF;
		-- 手数料額と内消費税の算出
		gEditTesuKngk := gOwnTesuKngk + gOwnTesuSzei;
		gEditTesuSzei := gOwnTesuSzei;
		IF  gDataSakuseiKbn = '2'
		AND gShoriKbn = '1'
		THEN
			gEditTesuKngk := gEditTesuKngk + gHoseiOwnTesuKngk + gHoseiOwnTesuSzei;
			gEditTesuSzei := gEditTesuSzei + gHoseiOwnTesuSzei;
		END IF;
		-- 書式フォーマットの設定
		-- 発行
		IF gHakkoTsukaCd = 'JPY' THEN
			gFmtHakkoKngk := FMT_HAKKO_KNGK_J;
		ELSE
			gFmtHakkoKngk := FMT_HAKKO_KNGK_F;
		END IF;
		-- 利払
		IF gRbrTsukaCd = 'JPY' THEN
			gFmtRbrKngk := FMT_RBR_KNGK_J;
		ELSE
			gFmtRbrKngk := FMT_RBR_KNGK_F;
		END IF;
		-- 償還
		IF gShokanTsukaCd = 'JPY' THEN
			gFmtShokanKngk := FMT_SHOKAN_KNGK_J;
		ELSE
			gFmtShokanKngk := FMT_SHOKAN_KNGK_F;
		END IF;
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := gEditBankRnm;	-- 銀行略称
		v_item.l_inItem003 := l_inKijunYm;	-- 基準年月
		v_item.l_inItem004 := gEigyotenCd;	-- 営業店コード
		v_item.l_inItem005 := gEigyotenRnm;	-- 営業店略称[部店略称]
		v_item.l_inItem006 := gTsukaCd;	-- 通貨コード
		v_item.l_inItem007 := gTsukaCdNn;	-- 通貨コード名称[通貨出力用名称]
		v_item.l_inItem008 := gIsinCd;	-- ＩＳＩＮコード
		v_item.l_inItem009 := gMgrCd;	-- 銘柄コード
		v_item.l_inItem010 := gMgrRnm;	-- 銘柄略称
		v_item.l_inItem011 := gHakkoYmd;	-- 発行年月日
		v_item.l_inItem012 := gFullShokanKjt;	-- 満期償還期日
		v_item.l_inItem013 := gShasaiTotal;	-- 社債の総額
		v_item.l_inItem014 := gEditDaiJtkKaishaNm;	-- 代表受託会社名[金融機関略称]
		v_item.l_inItem015 := gChokyuYmd;	-- 徴求日
		v_item.l_inItem016 := gKijunZndk;	-- 基準残高
		v_item.l_inItem017 := gTesuRitsuBunshi;	-- 手数料率分子
		v_item.l_inItem018 := gTesuRitsuBunbo;	-- 手数料率分母
		v_item.l_inItem019 := gKichuBunDfBunshi;	-- 期中分分配率(分子)
		v_item.l_inItem020 := gDfBunbo;	-- 分配率(分母)
		v_item.l_inItem021 := gEditTesuKngk;	-- 手数料額
		v_item.l_inItem022 := gEditTesuSzei;	-- 内消費税
		v_item.l_inItem024 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem025 := gFmtHakkoKngk;	-- 発行金額書式フォーマット
		v_item.l_inItem026 := gFmtRbrKngk;	-- 利払金額書式フォーマット
		v_item.l_inItem027 := gFmtShokanKngk;	-- 償還金額書式フォーマット
		v_item.l_inItem028 := gBunsho;	-- インボイス文章
		v_item.l_inItem029 := gInvoiceFlg;	-- インボイスオプションフラグ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
		l_inSakuseiYmd	=> l_inGyomuYmd,
		l_inChohyoId	=> REPORT_ID,
		l_inSeqNo		=> gSeqNo::integer,
		l_inHeaderFlg	=> '1',
		l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	END LOOP;
	CLOSE curMeisai;
	IF gSeqNo = 0 THEN
		-- 対象データなし
		gRtnCd := RTN_NODATA;
	-- 委託会社略称を取得
	BEGIN
	SELECT
		VJ01.BANK_RNM,
		VJ01.JIKO_DAIKO_KBN
	INTO STRICT
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
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;
		v_item.l_inItem002 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem023 := '対象データなし';
		v_item.l_inItem024 := REPORT_ID;
		v_item.l_inItem028 := gBunsho;	-- インボイス文章
		v_item.l_inItem029 := gInvoiceFlg;	-- インボイスオプションフラグ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> 1,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPI062K00R01_01 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		BEGIN
			CLOSE curMeisai;
		EXCEPTION
			WHEN OTHERS THEN
				NULL;
		END;
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
--		RAISE;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipi062k00r01_01 ( l_inKijunYm TEXT, l_inEigyotenCd TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;




-- Nested procedure spipi062k00r01_01_createsql has been inlined above