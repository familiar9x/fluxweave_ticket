




CREATE OR REPLACE PROCEDURE spipt113k01r01 ( 
    l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE,        -- 委託会社コード
 l_inUserId SREPORT_WK.USER_ID%TYPE,       -- ユーザーID
 l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE,    -- 帳票区分
 l_inHktCd SCODE.CODE_VALUE%TYPE,         -- 発行体コード
 l_inKozaTenCd MHAKKOTAI.KOZA_TEN_CD%TYPE,    -- 口座店店番
 l_inKozaTenCifcd MHAKKOTAI.KOZA_TEN_CIFCD%TYPE, -- 口座店CIFコード
 l_inMgrCd MGR_STS.MGR_CD%TYPE,           -- 銘柄コード
 l_inIsinCd MGR_KIHON.ISIN_CD%TYPE,        -- ISINコード
 l_inKijunYm text,                      -- 基準年月
 l_outSqlCode OUT integer,                        -- リターン値
 l_outSqlErrM OUT text                       -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2006
-- * 会社名:JIP
-- *
-- * 概要　:新規記録手数料の集計処理
-- *
-- * 引数　:l_inItakuKaishaCd :委託会社コード
-- *        l_inUserId        :ユーザーID
-- *        l_inChohyoKbn     :帳票区分
-- *        l_inHktCd         :発行体コード
-- *        l_inKozaTenCd     :口座店店番
-- *        l_inKozaTenCifcd  :口座店CIFコード
-- *        l_inMgrCd         :銘柄コード
-- *        l_inIsinCd        :ISINコード
-- *        l_inKijunYm       :基準年月
-- *        l_outSqlCode      :リターン値
-- *        l_outSqlErrM      :エラーコメント
-- *
-- * 返り値: なし
-- *
-- * @author ASK
-- * @version $Id: SPIPT113K01R01.sql,v 1.6 2023/04/29 06:35:36 kentaro_ikeda Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2006.09.22 ASK         新規作成
-- ***************************************************************************
--
	--==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_PROCEDURE_ID CONSTANT varchar(50) := 'SPIPT113K01R01';            -- プロシージャＩＤ
	C_CHOHYO_ID    CONSTANT SREPORT_WK.CHOHYO_ID%TYPE  := 'IPT30111311'; -- 帳票ＩＤ
	C_FM14_1       CONSTANT varchar(18) := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';        -- 通貨フォーマット(14.2 JPY)
	C_FM14_2       CONSTANT varchar(21) := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';     -- 通貨フォーマット(14.2 JPY以外)
	C_FM16_1       CONSTANT varchar(21) := 'Z,ZZZ,ZZZ,ZZZ,ZZZ,ZZ9';     -- 通貨フォーマット(16.2 JPY)
	C_FM16_2       CONSTANT varchar(24) := 'Z,ZZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';  -- 通貨フォーマット(16.2 JPY以外)
	C_KETACHECK_14 CONSTANT numeric(14)   := 99999999999999;              -- 桁数チェック14桁
	C_KETACHECK_16 CONSTANT numeric(16)   := 9999999999999999;            -- 桁数チェック16桁
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	gSeqNo            integer;                           -- シーケンス
	gTsukaCd          MTSUKA.TSUKA_CD%TYPE := ' ';       -- 発行通貨コード
	gItakuKaishaRnm   SOWN_INFO.BANK_RNM%TYPE;           -- 委託会社略称
	gGyomuYmd         SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE; -- 業務日付
	gTaxRate          numeric := 0;                  -- 消費税率
	gTaxKngk          numeric(21);                        -- 消費税金額
	gHakkoKngkSum     numeric(16);                        -- 発行額合計
	gSeikyuKngkSum    numeric(21);                        -- 手数料額合計
	gTsukaNm          MTSUKA.TSUKA_NM%TYPE;              -- 通貨名称
	gFm14             varchar(21);                      -- 通貨フォーマット
	gFm16             varchar(24);                      -- 通貨フォーマット
	gOptionFlg        MOPTION_KANRI.OPTION_FLG%TYPE;     -- オプションフラグ
	v_item            type_sreport_wk_item;              -- Composite type for pkPrint.insertData
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	curMeisai CURSOR FOR
		SELECT
			T01.TSUKA_CD,         -- 通貨コード
			VMG1.HKT_CD,          -- 発行体コード
			M01.KOZA_TEN_CD,      -- 口座店コード
			M01.KOZA_TEN_CIFCD,   -- 口座店CIFコード
			VMG1.MGR_TAIKEI_KBN,  -- 銘柄体系区分
			VMG1.KK_HAKKOSHA_RNM, -- 機構発行者略称
			VMG1.ISIN_CD,         -- ISINコード
			VMG1.MGR_CD,          -- 銘柄コード
			VMG1.MGR_RNM,         -- 銘柄略称
			VMG1.HAKKO_YMD,       -- 発行年月日
			VMG1.SHASAI_TOTAL,    -- 社債総額(発行額)
			CASE WHEN T01.DATA_SAKUSEI_KBN = '2' THEN
				CASE WHEN T01.SHORI_KBN = '1' THEN
					T01.ALL_TESU_KNGK + T01.HOSEI_ALL_TESU_KNGK
				ELSE
					T01.ALL_TESU_KNGK
				END
			ELSE T01.ALL_TESU_KNGK
			END TESURYO_KNGK,     -- 手数料額
			(SELECT M64.TSUKA_NM FROM MTSUKA M64
				WHERE T01.TSUKA_CD = M64.TSUKA_CD
			)AS TSUKA_NM           -- 通貨出力用名称
		FROM
			TESURYO T01,
			MGR_KIHON_VIEW VMG1,
			MHAKKOTAI M01
		WHERE T01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND T01.DATA_SAKUSEI_KBN  <>  '0'
			AND T01.TESU_SHURUI_CD = '51'
			AND T01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
			AND T01.MGR_CD = VMG1.MGR_CD
			AND VMG1.HAKKO_YMD LIKE l_inKijunYm ||'%'
			AND (coalesce(l_inHktCd::text, '') = '' OR M01.HKT_CD = l_inHktCd)
			AND (coalesce(l_inKozaTenCd::text, '') = '' OR M01.KOZA_TEN_CD = l_inKozaTenCd)
			AND (coalesce(l_inKozaTenCifCd::text, '') = '' OR M01.KOZA_TEN_CIFCD = l_inKozaTenCifCd)
			AND (coalesce(l_inMgrCd::text, '') = '' OR T01.MGR_CD = l_inMgrCd)
			AND (coalesce(l_inIsinCd::text, '') = '' OR VMG1.ISIN_CD = l_inIsinCd)
			AND T01.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
			AND VMG1.HKT_CD = M01.HKT_CD
			AND VMG1.MGR_STAT_KBN = '1'
			AND VMG1.TOKUREI_SHASAI_FLG <> 'Y'
			AND VMG1.JTK_KBN <> '2'
			AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '') 
		ORDER BY
			T01.TSUKA_CD,
			VMG1.MGR_TAIKEI_KBN,
			CASE WHEN VMG1.MGR_TAIKEI_KBN='0' THEN VMG1.KK_HAKKOSHA_RNM  ELSE '' END ,
			VMG1.ISIN_CD;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, C_PROCEDURE_ID||' START');
	-- 入力パラメータチェック
	IF coalesce(l_inItakuKaishaCd::text, '') = '' -- 委託会社コード
	OR coalesce(l_inUserId::text, '') = '' -- ユーザーID
	OR coalesce(l_inChohyoKbn::text, '') = '' -- 帳票区分
	OR coalesce(l_inKijunYm::text, '') = '' -- 基準年月
	THEN
		-- ログ書込み
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID,3,12), 'パラメータエラー');
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := '';
		RETURN;
	END IF;
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '引数');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '委託会社コード:"' || l_inItakuKaishaCd ||'"');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'ユーザーＩＤ:"' || l_inUserId ||'"');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票区分:"' || l_inChohyoKbn ||'"');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '基準年月:"' || l_inKijunYm ||'"');
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
	-- 委託会社略名取得
	SELECT
		CASE WHEN JIKO_DAIKO_KBN='2' THEN BANK_RNM  ELSE ' ' END  INTO STRICT gItakuKaishaRnm
	FROM
		VJIKO_ITAKU
	WHERE
		KAIIN_ID = l_inItakuKaishaCd;
	-- シーケンス初期化
	gSeqNo := 1;
	-- 消費税率の取得
	gTaxRate := pkIpaZei.getShohiZei(l_inKijunYm || '01');
	-- 帳票ワーク削除
	DELETE FROM SREPORT_WK
	WHERE KEY_CD = l_inItakuKaishaCd
	AND USER_ID = l_inUserId
	AND CHOHYO_KBN = l_inChohyoKbn
	AND SAKUSEI_YMD = gGyomuYmd
	AND CHOHYO_ID = C_CHOHYO_ID;
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '削除条件');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '識別コード:"' || l_inItakuKaishaCd ||'"');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'ユーザーＩＤ:"' || l_inUserId ||'"');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票区分:"' || l_inChohyoKbn ||'"');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '作成日付:"' || gGyomuYmd ||'"');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票ＩＤ:"' || C_CHOHYO_ID ||'"');
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, gGyomuYmd, C_CHOHYO_ID);
	-- 合計エリアのクリア
	gHakkoKngkSum := 0;  -- 発行金額合計
	gSeikyuKngkSum := 0; -- 請求金額合計
	--８−Ａ．オプションフラグ取得
	gOptionFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd,'INVOICE_C','0');
	-- データ取得
	FOR recMeisai IN curMeisai LOOP
		-- 通貨コードでブレイク
		IF gTsukaCd != recMeisai.TSUKA_CD AND gSeqNo <> 1 THEN
			-- 合計レコード追加
			CALL SPIPT113K01R01_insertGokeiData(gSeqNo, l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, 
				gGyomuYmd, C_CHOHYO_ID, l_inKijunYm, gItakuKaishaRnm, gTsukaCd, gTsukaNm, 
				gFm14, gFm16, gTaxRate, gOptionFlg, gHakkoKngkSum, gSeikyuKngkSum);
			-- シーケンスのカウント
			gSeqNo := gSeqNo + 1;
		END IF;
		-- キーの退避
		gTsukaCd := recMeisai.TSUKA_CD; -- 通貨コード
		gTsukaNm := recMeisai.TSUKA_NM; -- 通貨名称
		-- 通貨フォーマット設定
		IF recMeisai.TSUKA_CD = 'JPY' THEN
			gFm14 := C_FM14_1;
			gFm16 := C_FM16_1;
		ELSE
			gFm14 := C_FM14_2;
			gFm16 := C_FM16_2;
		END IF;
		-- 合計計算
		gHakkoKngkSum := gHakkoKngkSum + recMeisai.SHASAI_TOTAL;   -- 発行金額合計
		gSeikyuKngkSum := gSeikyuKngkSum + recMeisai.TESURYO_KNGK; -- 請求金額合計
		-- 明細レコード追加
		v_item := ROW();
		v_item.l_inItem001 := ''::varchar;                           -- データ基準日ラベル
		v_item.l_inItem002 := ''::varchar;                           -- 作成年月日
		v_item.l_inItem003 := gItakuKaishaRnm::varchar;              -- 委託会社略称
		v_item.l_inItem004 := recMeisai.MGR_TAIKEI_KBN::varchar;     -- 銘柄体系区分
		v_item.l_inItem005 := recMeisai.TSUKA_CD::varchar;           -- 通貨コード
		v_item.l_inItem006 := l_inKijunYm::varchar;                  -- 基準年月
		v_item.l_inItem007 := recMeisai.HKT_CD::varchar;             -- 発行体コード
		v_item.l_inItem008 := recMeisai.KOZA_TEN_CD::varchar;        -- 口座店コード
		v_item.l_inItem009 := recMeisai.KOZA_TEN_CIFCD::varchar;     -- 口座店CIFコード
		v_item.l_inItem010 := recMeisai.ISIN_CD::varchar;            -- ISINコード
		v_item.l_inItem011 := recMeisai.MGR_CD::varchar;             -- 銘柄コード
		v_item.l_inItem012 := recMeisai.HAKKO_YMD::varchar;          -- 発行年月日
		v_item.l_inItem013 := recMeisai.SHASAI_TOTAL::varchar;       -- 社債総額(発行額)
		v_item.l_inItem014 := recMeisai.TESURYO_KNGK::varchar;       -- 手数料額
		v_item.l_inItem015 := recMeisai.KK_HAKKOSHA_RNM::varchar;    -- 機構発行者略称
		v_item.l_inItem016 := recMeisai.MGR_RNM::varchar;            -- 銘柄略称
		v_item.l_inItem017 := 0::varchar;                            -- 消費税
		v_item.l_inItem018 := gFm14::varchar;                        -- 通貨フォーマット
		v_item.l_inItem019 := gFm16::varchar;                        -- 通貨フォーマット
		v_item.l_inItem021 := 1::varchar;                            -- レコード判別
		v_item.l_inItem022 := gSeqNo::varchar;                       -- SQE№
		v_item.l_inItem023 := C_CHOHYO_ID::varchar;                  -- 帳票ＩＤ
		v_item.l_inItem024 := l_inUserId::varchar;                   -- ユーザーＩＤ
		v_item.l_inItem025 := recMeisai.TSUKA_NM::varchar;           -- 通貨名称
		v_item.l_inItem027 := gOptionFlg::varchar;                   -- ローカル変数．オプションフラグ
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd,         -- 識別コード
			l_inUserId     => l_inUserId,                -- ユーザＩＤ
			l_inChohyoKbn  => l_inChohyoKbn,             -- 帳票区分
			l_inSakuseiYmd => gGyomuYmd,                 -- 作成日付
			l_inChohyoId   => C_CHOHYO_ID,               -- 帳票ＩＤ
			l_inSeqNo      => gSeqNo,                    -- SQE№
			l_inHeaderFlg  => '1',                       -- ヘッダフラグ
			l_inItem       => v_item,                    -- 明細項目
			l_inKousinId   => l_inUserId,                -- 更新者
			l_inSakuseiId  => l_inUserId                 -- 作成者
		);
		-- シーケンスのカウント
		gSeqNo := gSeqNo + 1;
	END LOOP;
	-- 終了処理
	IF gSeqNo = 1 THEN
		-- 明細レコード追加（対象データ無し）
		v_item := ROW();
		v_item.l_inItem021 := 1::varchar;              -- レコード判別
		v_item.l_inItem022 := gSeqNo::varchar;         -- SQE№
		v_item.l_inItem023 := C_CHOHYO_ID::varchar;    -- 帳票ＩＤ
		v_item.l_inItem024 := l_inUserId::varchar;     -- ユーザーＩＤ
		v_item.l_inItem026 := '対象データ無し'::varchar; -- 対象データ無し
		v_item.l_inItem027 := gOptionFlg::varchar;     -- ローカル変数．オプションフラグ
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd, -- 識別コード
			l_inUserId     => l_inUserId,        -- ユーザＩＤ
			l_inChohyoKbn  => l_inChohyoKbn,     -- 帳票区分
			l_inSakuseiYmd => gGyomuYmd,         -- 業務日付
			l_inChohyoId   => C_CHOHYO_ID,       -- 帳票ＩＤ
			l_inSeqNo      => gSeqNo,            -- 連番
			l_inHeaderFlg  => '1',               -- ヘッダフラグ
			l_inItem       => v_item,            -- 明細項目
			l_inKousinId   => l_inUserId,        -- 更新者
			l_inSakuseiId  => l_inUserId         -- 作成者
		);
	ELSE
		-- 合計レコード追加
		CALL SPIPT113K01R01_insertGokeiData(gSeqNo, l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, 
			gGyomuYmd, C_CHOHYO_ID, l_inKijunYm, gItakuKaishaRnm, gTsukaCd, gTsukaNm, 
			gFm14, gFm16, gTaxRate, gOptionFlg, gHakkoKngkSum, gSeikyuKngkSum);
	END IF;
	-- 終了処理
	l_outSqlCode := pkconstant.success();
	l_outSqlErrM := '';
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, gSeqNo ||' 件');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, C_PROCEDURE_ID ||' END');
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
-- REVOKE ALL ON PROCEDURE spipt113k01r01 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE, l_inUserId SREPORT_WK.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_inHktCd SCODE.CODE_VALUE%TYPE, l_inKozaTenCd MHAKKOTAI.KOZA_TEN_CD%TYPE, l_inKozaTenCifcd MHAKKOTAI.KOZA_TEN_CIFCD%TYPE, l_inMgrCd MGR_STS.MGR_CD%TYPE, l_inIsinCd MGR_KIHON.ISIN_CD%TYPE, l_inKijunYm text, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spipt113k01r01_insertgokeidata ( 
	l_inSeqNo integer,
	p_inItakuKaishaCd varchar,
	p_inUserId varchar,
	p_inChohyoKbn char,
	p_inGyomuYmd varchar,
	p_inChohyoId varchar,
	p_inKijunYm varchar,
	p_inItakuKaishaRnm varchar,
	p_inTsukaCd varchar,
	p_inTsukaNm varchar,
	p_inFm14 varchar,
	p_inFm16 varchar,
	p_inTaxRate numeric,
	p_inOptionFlg char,
	p_ioHakkoKngkSum INOUT numeric,
	p_ioSeikyuKngkSum INOUT numeric
) AS $body$
DECLARE
	C_KETACHECK_14 CONSTANT numeric(14) := 99999999999999;
	C_KETACHECK_16 CONSTANT numeric(16) := 9999999999999999;
	v_TaxKngk numeric(21);
	v_item type_sreport_wk_item;
BEGIN
	-- 発行金額合計
	IF p_ioHakkoKngkSum > C_KETACHECK_16 THEN
		p_ioHakkoKngkSum := 0.00;  -- 桁あふれ時（全て０）
	END IF;
	-- 請求金額合計
	IF p_ioSeikyuKngkSum > C_KETACHECK_16 THEN
		p_ioSeikyuKngkSum := 0.00; -- 桁あふれ時（全て０）
	END IF;
	-- 消費税額算出
	v_TaxKngk := TRUNC(p_ioSeikyuKngkSum * p_inTaxRate::numeric, 0);
	IF v_TaxKngk > C_KETACHECK_14 THEN
		v_TaxKngk := 0.00;       -- 桁あふれ時（全て０）
	END IF;
	v_item := ROW();
	v_item.l_inItem001 := ''::varchar;                     -- データ基準日ラベル
	v_item.l_inItem002 := ''::varchar;                     -- 作成年月日
	v_item.l_inItem003 := p_inItakuKaishaRnm::varchar;     -- 委託会社略称
	v_item.l_inItem005 := p_inTsukaCd::varchar;            -- 通貨コード
	v_item.l_inItem006 := p_inKijunYm::varchar;            -- 基準年月
	v_item.l_inItem012 := ' 合計'::varchar;                -- 合計
	v_item.l_inItem013 := p_ioHakkoKngkSum::varchar;       -- 発行金額合計
	v_item.l_inItem014 := p_ioSeikyuKngkSum::varchar;      -- 請求金額合計
	v_item.l_inItem017 := v_TaxKngk::varchar;              -- 消費税金額
	v_item.l_inItem018 := p_inFm14::varchar;               -- 通貨フォーマット
	v_item.l_inItem019 := p_inFm16::varchar;               -- 通貨フォーマット
	v_item.l_inItem020 := ' 消費税'::varchar;              -- 消費税
	v_item.l_inItem021 := 2::varchar;                      -- レコード判別
	v_item.l_inItem022 := l_inSeqNo::varchar;              -- SQE№
	v_item.l_inItem023 := p_inChohyoId::varchar;           -- 帳票ＩＤ
	v_item.l_inItem024 := p_inUserId::varchar;             -- ユーザーＩＤ
	v_item.l_inItem025 := p_inTsukaNm::varchar;            -- 通貨名称
	v_item.l_inItem027 := p_inOptionFlg::varchar;          -- ローカル変数．オプションフラグ
	CALL pkPrint.insertData(
		l_inKeyCd      => p_inItakuKaishaCd,        -- 識別コード
		l_inUserId     => p_inUserId,               -- ユーザＩＤ
		l_inChohyoKbn  => p_inChohyoKbn,            -- 帳票区分
		l_inSakuseiYmd => p_inGyomuYmd,             -- 作成日付
		l_inChohyoId   => p_inChohyoId,             -- 帳票ＩＤ
		l_inSeqNo      => l_inSeqNo,                -- SQE№
		l_inHeaderFlg  => '1',                      -- ヘッダフラグ
		l_inItem       => v_item,                   -- 明細項目
		l_inKousinId   => p_inUserId,               -- 更新者
		l_inSakuseiId  => p_inUserId                -- 作成者
	);
	-- 合計エリアのクリア
	p_ioHakkoKngkSum := 0;  -- 発行金額合計
	p_ioSeikyuKngkSum := 0; -- 請求金額合計
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipt113k01r01_insertgokeidata ( l_inSeqNo integer ) FROM PUBLIC;