




CREATE OR REPLACE PROCEDURE spipx002k00r01 ( l_inKessaiYmdF TESURYO.CHOKYU_YMD%TYPE,             -- 決済日From
 l_inKessaiYmdT TESURYO.CHOKYU_YMD%TYPE,             -- 決済日To
 l_inHakkoKichuFlg TESURYO_KANRI.HAKKO_KICHU_FLG%TYPE,  -- 発行・期中フラグ
 l_inItakuKaishaCd TESURYO.ITAKU_KAISHA_CD%TYPE,        -- 委託会社コード
 l_inUserId SREPORT_WK.USER_ID%TYPE,             -- ユーザーＩＤ
 l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE,          -- 帳票区分
 l_inGyomuYmd SREPORT_WK.SAKUSEI_YMD%TYPE,         -- 業務日付
 l_outSqlCode OUT INTEGER,     -- リターン値
 l_outSqlErrM OUT text    -- エラーコメント
 ) AS $body$
DECLARE

--*
--/* 著作権:Copyright(c)2006
--/* 会社名:JIP
--/*
--/* 概要　:出力指示画面の入力条件により、手数料受入管理表を作成する。
--/*        社債管理会社は『手数料受入管理表（当初差引分含む）』を作成し、手数料受入の管理を行う。
--/* 引数　:l_inKessaiYmdF    IN  TESURYO.CHOKYU_YMD%TYPE,             -- 決済日From
--/*        l_inKessaiYmdT    IN  TESURYO.CHOKYU_YMD%TYPE,             -- 決済日To
--/*        l_inHakkoKichuFlg IN  TESURYO_KANRI.HAKKO_KICHU_FLG%TYPE,  -- 発行・期中フラグ
--/*        l_inItakuKaishaCd IN  TESURYO.ITAKU_KAISHA_CD%TYPE,        -- 委託会社コード
--/*        l_inUserId        IN  SREPORT_WK.USER_ID%TYPE,             -- ユーザーＩＤ
--/*        l_inChohyoKbn     IN  SREPORT_WK.CHOHYO_KBN%TYPE,          -- 帳票区分
--/*        l_inGyomuYmd      IN  SREPORT_WK.SAKUSEI_YMD%TYPE,         -- 業務日付
--/*        l_outSqlCode      OUT INTEGER     リターン値
--/*        l_outSqlErrM      OUT VARCHAR2    エラーコメント
--/*
--/* 返り値:なし
-- *
-- * @author ASK
-- * @version $Id: SPIPX002K00R01.sql,v 1.9 2023/04/29 06:32:23 kentaro_ikeda Exp $
-- *
-- ***************************************************************************
--/* ログ　:
--/* 　　　日付  開発者名    目的
--/* -------------------------------------------------------------------------
--/*　2006.11.10 丸田（ASK） 新規作成
--/*　2023.02.20 張奇（USI） インボイス制度対応
--****************************************************************************
--
	--==============================================================================
	--          定数定義                          
	--==============================================================================
	C_PROCEDURE_ID CONSTANT varchar(50) := 'SPIPX002K00R01';   -- プロシージャＩＤ
	C_CHOHYO_ID CONSTANT char(11)  := 'IPX30000211';            -- 帳票ＩＤ
	FMT_KNGK_J  CONSTANT char(18)  := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';     -- 通貨フォーマット
	FMT_KNGK_F  CONSTANT char(21)  := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';  -- 通貨フォーマット
	FMT_SZEI_J  CONSTANT char(18)  := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';     -- 通貨フォーマット（消費税）
	FMT_SZEI_F  CONSTANT char(21)  := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';  -- 通貨フォーマット（消費税）
	--==============================================================================
	--          変数定義                          
	--==============================================================================
	gSeqNo          integer := 0;
	-- 書式フォーマット
	gTsukaCdFmt      varchar(21) := NULL;      -- 金額フォーマット
	gTsukaSzeiCdFmt  varchar(21) := NULL;      -- 金額フォーマット（消費税）
	gItakuKaishaRnm  SOWN_INFO.BANK_RNM%TYPE;        -- 委託会社略名
	gKessaiYmdFrom   TESURYO.CHOKYU_YMD%TYPE;        -- 決済日From
	gKessaiYmdTo     TESURYO.CHOKYU_YMD%TYPE;        -- 決済日To
	gKozaTenCd2      KOZA_FRK.KOZA_TEN_CD%TYPE;      -- 口座店コード
	gKozaKamokuNm    SCODE.CODE_NM%TYPE;             -- 口座科目名称
	gKozaNo          KOZA_FRK.KOZA_NO%TYPE;          -- 口座番号
	gKozameigininNn  MHAKKOTAI.HKO_KOZA_MEIGININ_NM%TYPE;  -- 口座名義人
	gChohyoSortFlg		MPROCESS_CTL.CTL_VALUE%TYPE;				-- 発行体宛帳票ソート順変更フラグ
	gBunsho             varchar(150) := NULL;                 -- インボイス文章
	gInvoiceFlg         MOPTION_KANRI.OPTION_FLG%TYPE;              -- インボイスオプションフラグ
	v_item              type_sreport_wk_item;                       -- 帳票ワーク項目（composite type）
	wAryBun				pkIpaBun.BUN_ARRAY;							-- 文章情報作業用
	--==============================================================================
	--          カーソル定義                          
	--==============================================================================
	curMeisai CURSOR FOR
	SELECT
		T01.CHOKYU_YMD                              -- 徴求日
		,T01.TESU_SHURUI_CD                         -- 手数料種類コード
		,S01.KONAI_TESU_SHURUI_NM
					AS TESU_SHURUI_NM               -- 手数料種類名称
		,T01.TESU_SASHIHIKI_KBN                     -- 手数料差引区分
		,CASE WHEN T01.TESU_SASHIHIKI_KBN='1' THEN  '00'  ELSE T01.KOZA_FURI_KBN END
					AS KOZA_FURI_KBN                -- 口座振込区分
		,CASE WHEN 			T01.TESU_SASHIHIKI_KBN='1' THEN  '払込金差引'  ELSE S06.KOZA_FURI_KBN_NM END  AS NYUKIN_METHOD                           -- 入金方法
		,T01.TSUKA_CD                                -- 通貨コード
		,M64.TSUKA_NM                                -- 通貨コード名称
		,M01.HKT_CD                                  -- 発行体コード
		,M01.KOZA_TEN_CD AS KOZA_TEN_CD1            -- 口座店コード
		,M01.KOZA_TEN_CIFCD                          -- 口座店CIFコード
		,M01.HKT_RNM                                 -- 発行体略称
		,VMG0.ISIN_CD                                -- ＩＳＩＮコード
		,VMG0.MGR_CD                                 -- 銘柄コード
		,VMG0.MGR_RNM                                -- 銘柄略称
		-- 全体手数料額税込に補正額を反映させるか判断する関数を使用
		,PKIPACALCTESURYO.getHoseiKasanKngk(
			T01.ALL_TESU_KNGK + T01.ALL_TESU_SZEI                     -- 全体手数料額
			,T01.HOSEI_ALL_TESU_KNGK + T01.HOSEI_ALL_TESU_SZEI        -- 補正手数料額
			,T01.DATA_SAKUSEI_KBN
			,T01.SHORI_KBN) AS TESU_KNGK
		-- 全体消費税額に補正額を反映させるか判断する関数を使用
		,PKIPACALCTESURYO.getHoseiKasanKngk(
			T01.ALL_TESU_SZEI                                         -- 全体消費税額
			,T01.HOSEI_ALL_TESU_SZEI                                  -- 補正消費税額
			,T01.DATA_SAKUSEI_KBN
			,T01.SHORI_KBN) AS UCHI_SZEI
		-- 手数料額（自行）税込に補正額を反映させるか判断する関数を使用 
		,PKIPACALCTESURYO.getHoseiKasanKngk(
			T01.OWN_TESU_KNGK + T01.OWN_TESU_SZEI                     -- 自行手数料額
			,T01.HOSEI_OWN_TESU_KNGK + T01.HOSEI_OWN_TESU_SZEI        -- 補正手数料額
			,T01.DATA_SAKUSEI_KBN
			,T01.SHORI_KBN) AS OWN_TESU_KNGK
		-- 自行消費税額に補正額を反映させるか判断する関数を使用 
		,PKIPACALCTESURYO.getHoseiKasanKngk(
			T01.OWN_TESU_SZEI                                         -- 自行消費税額
			,T01.HOSEI_OWN_TESU_SZEI                                  -- 補正消費税額
			,T01.DATA_SAKUSEI_KBN
			,T01.SHORI_KBN) AS OWN_UCHI_SZEI
		-- 手数料額（他行）税込に補正額を反映させるか判断する関数を使用 
		,PKIPACALCTESURYO.getHoseiKasanKngk(
			T01.OTHER_TESU_KNGK + T01.OTHER_TESU_SZEI                 -- 他行手数料額
			,T01.HOSEI_OTHER_TESU_KNGK + T01.HOSEI_OTHER_TESU_SZEI    -- 補正手数料額
			,T01.DATA_SAKUSEI_KBN
			,T01.SHORI_KBN) AS OTHER_TESU_KNGK
		-- 他行消費税額に補正額を反映させるか判断する関数を使用 
		,PKIPACALCTESURYO.getHoseiKasanKngk(
			T01.OTHER_TESU_SZEI                                       -- 他行消費税額
			,T01.HOSEI_OTHER_TESU_SZEI                                -- 補正消費税額
			,T01.DATA_SAKUSEI_KBN
			,T01.SHORI_KBN) AS OTHER_UCHI_SZEI
		,M01.KOZA_TEN_CD AS HKO_KOZA_TEN_CD          -- 発行体マスタ.口座店コード
		,MCD2.CODE_NM AS CODE_NM2                   -- コードマスタ.口座科目名称
		,M01.HKO_KOZA_NO                             -- 発行体マスタ.口座番号
		,M01.HKO_KOZA_MEIGININ_NM                    -- 発行体マスタ.口座名義人
		,S06.KOZA_TEN_CD                             -- 口座振替区分情報.口座店コード
		,MCD1.CODE_NM AS CODE_NM1                   -- コードマスタ.口座科目名称
		,S06.KOZA_NO                                 -- 口座振替区分情報.口座番号
		,S06.KOZAMEIGININ_NM                         -- 口座振替区分情報.口座名義人
	FROM mgr_kihon_view vmg0, tesuryo_kanri s01, mtsuka m64, tesuryo t01
LEFT OUTER JOIN koza_frk s06 ON (T01.ITAKU_KAISHA_CD = S06.ITAKU_KAISHA_CD AND T01.KOZA_FURI_KBN = S06.KOZA_FURI_KBN)
LEFT OUTER JOIN scode mcd1 ON (S06.KOZA_KAMOKU = MCD1.CODE_VALUE AND '707' = MCD1.CODE_SHUBETSU)
, mhakkotai m01
LEFT OUTER JOIN scode mcd2 ON (M01.HKO_KAMOKU_CD = MCD2.CODE_VALUE AND '707' = MCD2.CODE_SHUBETSU)
WHERE T01.CHOKYU_YMD BETWEEN gKessaiYmdFrom AND gKessaiYmdTo AND T01.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND T01.ITAKU_KAISHA_CD = S01.ITAKU_KAISHA_CD AND T01.ITAKU_KAISHA_CD = VMG0.ITAKU_KAISHA_CD  AND T01.MGR_CD = VMG0.MGR_CD  AND T01.TSUKA_CD = M64.TSUKA_CD AND T01.JTK_KBN <> '2' AND T01.TESU_SHURUI_CD = S01.TESU_SHURUI_CD AND VMG0.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD AND VMG0.HKT_CD = M01.HKT_CD AND VMG0.MGR_STAT_KBN = '1' AND (trim(both VMG0.ISIN_CD) IS NOT NULL AND (trim(both VMG0.ISIN_CD))::text <> '')     AND (S01.HAKKO_KICHU_FLG = l_inHakkoKichuFlg OR coalesce(l_inHakkoKichuFlg::text, '') = '') ORDER BY
		T01.TSUKA_CD
		,T01.CHOKYU_YMD
		,T01.TESU_SHURUI_CD
		,CASE WHEN T01.TESU_SASHIHIKI_KBN='1' THEN  '00'  ELSE T01.KOZA_FURI_KBN END 
		,CASE WHEN  gChohyoSortFlg ='1' THEN  M01.HKT_KANA_RNM   ELSE M01.HKT_CD END 
		,HKT_CD
		,CASE WHEN  gChohyoSortFlg ='1' THEN  VMG0.MGR_CD   ELSE VMG0.ISIN_CD END;
--==============================================================================
--  メイン処理  
--==============================================================================
BEGIN
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, C_PROCEDURE_ID||' START');
	-- 入力パラメータのチェック
	IF (coalesce(trim(both l_inKessaiYmdF)::text, '') = '' AND coalesce(trim(both l_inKessaiYmdT)::text, '') = '')
		OR coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
		OR coalesce(trim(both l_inUserId)::text, '') = ''
		OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''
		OR coalesce(trim(both l_inGyomuYmd)::text, '') = ''
	THEN
		-- ログ書込み
		CALL pkLog.fatal('ECM305', SUBSTR(C_PROCEDURE_ID,3,12), 'パラメータエラー');
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := '';
		RETURN;
	END IF;
	-- パラメータの基準日From-Toをセット
	gKessaiYmdFrom := l_inKessaiYmdF;
	gKessaiYmdTo   := l_inKessaiYmdT;
	-- 基準日Toのみ入力されている場合はFromに最小値を、Fromのみの場合はToに最大値をセットする。
	IF coalesce(trim(both gKessaiYmdFrom)::text, '') = '' THEN
		gKessaiYmdFrom := '00000000';
	END IF;
	IF coalesce(trim(both gKessaiYmdTo)::text, '') = '' THEN
		gKessaiYmdTo := '99999999';
	END IF;
	-- 委託会社略名取得
	BEGIN
		SELECT
			CASE WHEN JIKO_DAIKO_KBN='2' THEN  BANK_RNM  ELSE ' ' END
		INTO STRICT
			gItakuKaishaRnm
		FROM VJIKO_ITAKU
		WHERE KAIIN_ID = l_inItakuKaishaCd;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			gItakuKaishaRnm := '';
	END;
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '削除条件');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '識別コード:"' || l_inItakuKaishaCd ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'ユーザーＩＤ:"' || l_inUserId ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票区分:"' || l_inChohyoKbn ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '作成日付:"' || l_inGyomuYmd ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票ＩＤ:"' || C_CHOHYO_ID ||'"');
	 -- 帳票ワークの削除
	DELETE FROM SREPORT_WK
		WHERE KEY_CD    = l_inItakuKaishaCd
		AND USER_ID     = l_inUserId
		AND CHOHYO_KBN  = l_inChohyoKbn
		AND SAKUSEI_YMD = l_inGyomuYmd
		AND CHOHYO_ID   = C_CHOHYO_ID;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, C_CHOHYO_ID);
	-- インボイスオプションフラグを取得する
	gInvoiceFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd, 'INVOICE_C', '0');
	-- インボイスオプションフラグが"1"の場合
	IF gInvoiceFlg = '1' THEN
	    -- 請求文章取得
	    wAryBun := pkIpaBun.getBun(C_CHOHYO_ID, 'L0');
	    FOR i IN 0..coalesce(cardinality(wAryBun), 0) - 1 LOOP
	         IF i = 0 THEN
	             gBunsho := wAryBun[i];
	         END IF;
	    END LOOP;
	END IF;
	-- 帳票ワークへデータを追加
	gSeqNo := gSeqNo + 1;
	--発行体宛帳票ソート順変更フラグ取得
	gChohyoSortFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'SeikyusyoSort', '0');
	-- データ取得
	FOR recMeisai IN curMeisai LOOP
		-- 通貨フォーマットの設定
		IF recMeisai.TSUKA_CD = 'JPY' THEN
			gTsukaCdFmt     := FMT_KNGK_J;
			gTsukaSzeiCdFmt := FMT_SZEI_J;
		ELSE
			gTsukaCdFmt     := FMT_KNGK_F;
			gTsukaSzeiCdFmt := FMT_SZEI_F;
		END IF;
		-- 口座項目のクリア
		-- ※ 手数料差引区分が「1：当初差引分」のデータも含む
		gKozaTenCd2     := '';        -- 口座店コード
		gKozaKamokuNm   := '';        -- 口座科目名称
		gKozaNo         := '';        -- 口座番号
		gKozameigininNn := '';        -- 口座名義人
		-- 口座項目の編集
		-- 手数料差引区分が「2:後日請求分」の場合
		IF recMeisai.TESU_SASHIHIKI_KBN = '2' THEN
			IF recMeisai.KOZA_FURI_KBN = '10' THEN
				gKozaTenCd2     := recMeisai.HKO_KOZA_TEN_CD;       -- 口座店コード
				gKozaKamokuNm   := recMeisai.CODE_NM2;              -- 口座科目名称
				gKozaNo         := recMeisai.HKO_KOZA_NO;           -- 口座番号
				gKozameigininNn := recMeisai.HKO_KOZA_MEIGININ_NM;  -- 口座名義人
			ELSIF SUBSTR(recMeisai.KOZA_FURI_KBN, 1, 1) = '2' THEN
				gKozaTenCd2     := recMeisai.KOZA_TEN_CD;           -- 口座店コード
				gKozaKamokuNm   := recMeisai.CODE_NM1;              -- 口座科目名称
				gKozaNo         := recMeisai.KOZA_NO;               -- 口座番号
				gKozameigininNn := recMeisai.KOZAMEIGININ_NM;       -- 口座名義人
			END IF;
		END IF;
		-- Populate composite type for insertData
		v_item := ROW();
		v_item.l_inItem001 := l_inUserId;                   -- ユーザＩＤ
		v_item.l_inItem002 := l_inGyomuYmd;                 -- 入力業務日付
		v_item.l_inItem003 := gItakuKaishaRnm;              -- 委託会社略名取得
		v_item.l_inItem004 := recMeisai.NYUKIN_METHOD;      -- 入金方法
		v_item.l_inItem005 := recMeisai.KOZA_FURI_KBN;      -- 口座振替区分
		v_item.l_inItem006 := recMeisai.TSUKA_NM;           -- 通貨コード名称
		v_item.l_inItem007 := gSeqNo::text;                 -- 連番
		v_item.l_inItem008 := recMeisai.CHOKYU_YMD;         -- 徴求日
		v_item.l_inItem009 := recMeisai.HKT_CD;             -- 発行体コード
		v_item.l_inItem010 := recMeisai.KOZA_TEN_CD1;       -- 口座店コード
		v_item.l_inItem011 := recMeisai.KOZA_TEN_CIFCD;     -- 口座店CIFコード
		v_item.l_inItem012 := recMeisai.HKT_RNM;            -- 発行体略称
		v_item.l_inItem013 := recMeisai.ISIN_CD;            -- ＩＳＩＮコード
		v_item.l_inItem014 := recMeisai.MGR_CD;             -- 銘柄コード
		v_item.l_inItem015 := recMeisai.MGR_RNM;            -- 銘柄略称
		v_item.l_inItem016 := recMeisai.TESU_SHURUI_CD;     -- 手数料種類コード
		v_item.l_inItem017 := recMeisai.TESU_SHURUI_NM;     -- 手数料種類名称
		v_item.l_inItem018 := recMeisai.TESU_KNGK;          -- 手数料額
		v_item.l_inItem019 := recMeisai.UCHI_SZEI;          -- 内消費税
		v_item.l_inItem020 := recMeisai.OWN_TESU_KNGK;      -- 手数料額（自行）
		v_item.l_inItem021 := recMeisai.OWN_UCHI_SZEI;      -- 内消費税（自行）
		v_item.l_inItem022 := recMeisai.OTHER_TESU_KNGK;    -- 手数料額（他行）
		v_item.l_inItem023 := recMeisai.OTHER_UCHI_SZEI;    -- 内消費税（他行）
		v_item.l_inItem024 := gKozaTenCd2;                  -- 口座店コード
		v_item.l_inItem025 := gKozaKamokuNm;                -- 口座科目名称
		v_item.l_inItem026 := gKozaNo;                      -- 口座番号
		v_item.l_inItem027 := gKozameigininNn;              -- 口座名義人
		v_item.l_inItem029 := C_CHOHYO_ID;                  -- 帳票ＩＤ
		v_item.l_inItem030 := recMeisai.TSUKA_CD;           -- 通貨コード
		v_item.l_inItem031 := gTsukaCdFmt;                  -- 通貨フォーマット
		v_item.l_inItem032 := gTsukaSzeiCdFmt;              -- 通貨フォーマット（消費税）
		v_item.l_inItem033 := gBunsho;                      -- インボイス文章
		v_item.l_inItem034 := gInvoiceFlg;                  -- インボイスオプションフラグ
		
		CALL pkPrint.insertData(
			l_inKeyCd       => l_inItakuKaishaCd,           -- 識別コード
			l_inUserId      => l_inUserId,                  -- ユーザＩＤ
			l_inChohyoKbn   => l_inChohyoKbn,               -- 帳票区分
			l_inSakuseiYmd  => l_inGyomuYmd,                -- 作成年月日
			l_inChohyoId    => C_CHOHYO_ID,                 -- 帳票ＩＤ
			l_inSeqNo       => gSeqNo,                      -- 連番
			l_inHeaderFlg   => 1,                           -- ヘッダフラグ
			l_inItem        => v_item,                      -- 帳票ワーク項目
			l_inKousinId    => l_inUserId,                  -- 更新者ＩＤ
			l_inSakuseiId   => l_inUserId                   -- 作成者ＩＤ
		);
		-- 帳票ワークへデータを追加
		gSeqNo := gSeqNo + 1;
	END LOOP;
	IF gSeqNo = 1 THEN
		-- 明細レコード追加（対象データなし）
		v_item := ROW();
		v_item.l_inItem001 := l_inUserId;                   -- ユーザＩＤ
		v_item.l_inItem002 := l_inGyomuYmd;                 -- 入力業務日付
		v_item.l_inItem003 := gItakuKaishaRnm;              -- 委託会社略名取得
		v_item.l_inItem028 := '対象データなし';            -- 対象データなし
		v_item.l_inItem029 := C_CHOHYO_ID;                  -- 帳票ＩＤ
		v_item.l_inItem033 := gBunsho;                      -- インボイス文章
		v_item.l_inItem034 := gInvoiceFlg;                  -- インボイスオプションフラグ
		
		CALL pkPrint.insertData(
			l_inKeyCd       => l_inItakuKaishaCd,           -- 識別コード
			l_inUserId      => l_inUserId,                  -- ユーザＩＤ
			l_inChohyoKbn   => l_inChohyoKbn,               -- 帳票区分
			l_inSakuseiYmd  => l_inGyomuYmd,                -- 作成年月日
			l_inChohyoId    => C_CHOHYO_ID,                 -- 帳票ＩＤ
			l_inSeqNo       => gSeqNo,                      -- 連番
			l_inHeaderFlg   => 1,                           -- ヘッダフラグ
			l_inItem        => v_item,                      -- 帳票ワーク項目
			l_inKousinId    => l_inUserId,                  -- 更新者ＩＤ
			l_inSakuseiId   => l_inUserId                   -- 作成者ＩＤ
		);
	END IF;
	-- 終了処理
	l_outSqlCode := pkconstant.success();
	l_outSqlErrM := '';
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, C_PROCEDURE_ID ||' END');
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID,3,12), 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID,3,12), 'SQLERRM:' || SQLERRM);
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLSTATE || SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipx002k00r01 ( l_inKessaiYmdF TESURYO.CHOKYU_YMD%TYPE, l_inKessaiYmdT TESURYO.CHOKYU_YMD%TYPE, l_inHakkoKichuFlg TESURYO_KANRI.HAKKO_KICHU_FLG%TYPE, l_inItakuKaishaCd TESURYO.ITAKU_KAISHA_CD%TYPE, l_inUserId SREPORT_WK.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_inGyomuYmd SREPORT_WK.SAKUSEI_YMD%TYPE, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;