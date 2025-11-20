




CREATE OR REPLACE PROCEDURE spipp001k00r01 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE,     -- 委託会社コード
 l_inUserId SREPORT_WK.USER_ID%TYPE,    -- ユーザーＩＤ
 l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, -- 帳票区分
 l_inMgrCd MGR_KIHON.MGR_CD%TYPE,      -- 銘柄コード
 l_inIsinCd MGR_KIHON.ISIN_CD%TYPE,     -- ＩＳＩＮコード
 l_inKjnYm text,                   -- 基準年月
 l_outSqlCode OUT integer,                    -- リターン値
 l_outSqlErrM OUT text                    -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2007
-- * 会社名:JIP
-- *
-- * 概要　:償還年次表（実質記番号管理）
-- *
-- * 引数　:l_inItakuKaishaCd :委託会社コード
-- *        l_inUserId        :ユーザーＩＤ
-- *        l_inChohyoKbn     :帳票区分
-- *        l_inMgrCd         :銘柄コード
-- *        l_inIsinCd        :ＩＳＩＮコード
-- *        l_inKjnYm         :基準年月
-- *        l_outSqlCode      :リターン値
-- *        l_outSqlErrM      :エラーコメント
-- *
-- * 返り値: なし
-- *
-- * @author ASK
-- * @version $Id: SPIPP001K00R01.sql,v 1.2 2007/07/18 11:49:55 nishimura Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2007.05.17 中村        新規作成
-- ***************************************************************************
--	/*==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_PROGRAM_ID CONSTANT varchar(50)              := 'SPIPP001K00R01'; -- プログラムＩＤ
	C_CHOHYO_ID  CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IPP30000111';    -- 帳票ＩＤ
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	gSeqNo              numeric;                            -- シーケンス
	gSeqStartA          numeric;                            -- シーケンス開始（更新用Ａ）
	gSeqEndA            numeric;                            -- シーケンス終了（更新用Ａ）
	gSeqStartB          numeric;                            -- シーケンス開始（更新用Ｂ）
	gSeqEndB            numeric;                            -- シーケンス終了（更新用Ｂ）
	gNo                 numeric;                            -- ナンバー（更新用）
	gMunitGensaiKngkSum numeric;                            -- 銘柄単位元本減債金額（合計）
	gGyomuYmd           SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE; -- 業務日付
	gKjnMatuYmd         SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE; -- 基準年月末日
	gItakuKaishaRnm     SOWN_INFO.BANK_RNM%TYPE;           -- 委託会社略名
	gMgrFlg             MPROCESS_CTL.CTL_VALUE%TYPE;       -- 銘柄名称制御フラグ取得('0'：略称 '1'：正式)
	gProKenshuCd        numeric;                            -- 券種コード（編集用）
	gProMgrNm           MGR_KIHON.MGR_NM%TYPE;             -- 銘柄名称(正式 OR 略称)（編集用）
	gNoDataFlg          char(1);                           -- 対象データなし作成フラグ('0'：作成しない '1'：作成する)
	-- 券種情報 (converted to arrays)
	gKKenshuCd          numeric[];                         -- 券種コード array
	gKMaisu             numeric[];                         -- 枚数 array
	gKRishigakuFirst    numeric[];                         -- 利子額（初期）array
	gKRishigakuMid      numeric[];                         -- 利子額（通常）array
	gKRishigakuLast     numeric[];                         -- 利子額（終期）array
	gKKbgShokanKindNm   SCODE.CODE_NM%TYPE;                -- 償還種類名称
	gKCnt               numeric;                            -- カウント（券種用）
	-- 読込データ
	gItakuKaishaCd      KBG_SHOKIJ.ITAKU_KAISHA_CD%TYPE;   -- 委託会社コード
	gMgrCd              KBG_SHOKIJ.MGR_CD%TYPE;            -- 銘柄コード
	gShokanKjt          KBG_SHOKIJ.SHOKAN_KJT%TYPE;        -- 償還期日
	gShokanYmd          KBG_SHOKIJ.SHOKAN_YMD%TYPE;        -- 償還日
	gKknChokyuKjt       KBG_SHOKIJ.KKN_CHOKYU_KJT%TYPE;    -- 基金徴求期日
	gKknChokyuYmd       KBG_SHOKIJ.KKN_CHOKYU_YMD%TYPE;    -- 基金徴求日
	gKbgShokanKbn       KBG_SHOKIJ.KBG_SHOKAN_KBN%TYPE;    -- 償還区分（実質記番号用）
	gMunitGensaiKngk    KBG_SHOKIJ.MUNIT_GENSAI_KNGK%TYPE; -- 銘柄単位元本減債金額
	gKenshuCd           KBG_SHOKBG.KENSHU_CD%TYPE;         -- 券種コード
	gKibangoFrom        KBG_SHOKBG.KIBANGO_FROM%TYPE;      -- 記番号FROM
	gKibangoTo          KBG_SHOKBG.KIBANGO_TO%TYPE;        -- 記番号TO
	gSensatsuNo         KBG_SHOKBG.SENSATSU_NO%TYPE;       -- 籤札番号
	gMgrNm              MGR_KIHON.MGR_NM%TYPE;             -- 銘柄の正式名称
	gMgrRnm             MGR_KIHON.MGR_RNM%TYPE;            -- 銘柄略称
	gIsinCd             MGR_KIHON.ISIN_CD%TYPE;            -- ＩＳＩＮコード
	gHktCd              MGR_KIHON.HKT_CD%TYPE;             -- 発行体コード
	gHakkoYmd           MGR_KIHON.HAKKO_YMD%TYPE;          -- 発行年月日
	gRiritsu            MGR_KIHON.RIRITSU%TYPE;            -- 利率
	gFullshokanKjt      MGR_KIHON.FULLSHOKAN_KJT%TYPE;     -- 満期償還期日
	gShasaiTotal        MGR_KIHON.SHASAI_TOTAL%TYPE;       -- 社債の総額
	gKakushasaiKngk     MGR_KIHON.KAKUSHASAI_KNGK%TYPE;    -- 各社債の金額
	gHakkoTsukaNm       MTSUKA.TSUKA_NM%TYPE;              -- 発行通貨名称
	gShokanTsukaNm      MTSUKA.TSUKA_NM%TYPE;              -- 償還通貨名称
	gHktRnm             MHAKKOTAI.HKT_RNM%TYPE;            -- 発行体略称
	gJtkKbnNm           SCODE.CODE_NM%TYPE;                -- 受託区分名称
	gKbgShokanKbnNm     SCODE.CODE_NM%TYPE;                -- 償還区分名称
	gFurikaesogaku      numeric;                            -- 振替金額
	-- ブレイク確認用変数
	gBreakHktCd        MGR_KIHON.HKT_CD%TYPE;              -- 発行体コード
	gBreakIsinCd       MGR_KIHON.ISIN_CD%TYPE;             -- ＩＳＩＮコード
	gBreakShokanKjt    KBG_SHOKIJ.SHOKAN_KJT%TYPE;         -- 償還期日
	gBreakShokanYmd    KBG_SHOKIJ.SHOKAN_YMD%TYPE;         -- 償還日
	gBreakKbgShokanKbn KBG_SHOKIJ.KBG_SHOKAN_KBN%TYPE;     -- 償還区分（実質記番号用）
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	curMeisai CURSOR FOR
		SELECT
			P01.ITAKU_KAISHA_CD,                      -- 委託会社コード
			P01.MGR_CD,                               -- 銘柄コード
			P01.SHOKAN_KJT,                           -- 償還期日
			P01.SHOKAN_YMD,                           -- 償還日
			P01.KKN_CHOKYU_KJT,                       -- 基金徴求期日
			P01.KKN_CHOKYU_YMD,                       -- 基金徴求日
			P01.KBG_SHOKAN_KBN,                       -- 償還区分（実質記番号用）
			P01.MUNIT_GENSAI_KNGK,                    -- 銘柄単位元本減債金額
			coalesce(P02.KENSHU_CD, 0) AS KENSHU_CD,       -- 券種コード
			coalesce(P02.KIBANGO_FROM, 0) AS KIBANGO_FROM, -- 記番号FROM
			coalesce(P02.KIBANGO_TO, 0) AS KIBANGO_TO,     -- 記番号TO
			coalesce(P02.SENSATSU_NO, 0) AS SENSATSU_NO,   -- 籤札番号
			VMG1.MGR_NM,                              -- 銘柄の正式名称
			VMG1.MGR_RNM,                             -- 銘柄略称
			VMG1.ISIN_CD,                             -- ＩＳＩＮコード
			VMG1.HKT_CD,                              -- 発行体コード
			VMG1.HAKKO_YMD,                           -- 発行年月日
			VMG1.RIRITSU,                             -- 利率
			VMG1.FULLSHOKAN_KJT,                      -- 満期償還期日
			VMG1.SHASAI_TOTAL,                        -- 社債の総額
			VMG1.KAKUSHASAI_KNGK,                     -- 各社債の金額
			M01.HKT_RNM,                              -- 発行体略称
			(
				SELECT
					TSUKA_NM
				FROM
					MTSUKA
				WHERE
					TSUKA_CD = VMG1.HAKKO_TSUKA_CD
			) AS HAKKO_TSUKA_NM,                      -- 発行通貨名称
			(
				SELECT
					TSUKA_NM
				FROM
					MTSUKA
				WHERE
					TSUKA_CD = VMG1.SHOKAN_TSUKA_CD
			) AS SHOKAN_TSUKA_NM,                     -- 償還通貨名称
			(
				SELECT
					CODE_NM
				FROM
					SCODE
				WHERE
					CODE_SHUBETSU = '112'
					AND CODE_VALUE = VMG1.JTK_KBN
			) AS JTK_KBN_NM,                          -- 受託区分名称
			(
				SELECT
					CODE_NM
				FROM
					SCODE
				WHERE
					CODE_SHUBETSU = '226'
					AND CODE_VALUE = P01.KBG_SHOKAN_KBN
			) AS KBG_SHOKAN_KBN_NM,                   -- 償還区分名称
			pkIpaKibango.getFurikaeSogaku(
				P01.ITAKU_KAISHA_CD,
				P01.MGR_CD,
				gGyomuYmd
			) AS FURIKAESOGAKU                         -- 振替金額
		FROM mgr_kihon_view vmg1, mhakkotai m01, kbg_shokij p01
LEFT OUTER JOIN kbg_shokbg p02 ON (P01.ITAKU_KAISHA_CD = P02.ITAKU_KAISHA_CD AND P01.MGR_CD = P02.MGR_CD AND P01.SHOKAN_KJT = P02.SHOKAN_KJT AND P01.KBG_SHOKAN_KBN = P02.KBG_SHOKAN_KBN)
WHERE P01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD AND P01.MGR_CD = VMG1.MGR_CD AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD AND VMG1.HKT_CD = M01.HKT_CD AND P01.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND VMG1.JTK_KBN != '2' AND VMG1.JTK_KBN != '5' AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '') AND VMG1.MGR_STAT_KBN = '1' AND VMG1.KK_KANYO_FLG = '2' AND (
				coalesce(gKjnMatuYmd::text, '') = ''
				OR pkIpaKibango.getKjnZndk(
					P01.ITAKU_KAISHA_CD,
					P01.MGR_CD,
					gKjnMatuYmd
				) > 0
			) AND (coalesce(trim(both l_inMgrCd)::text, '') = '' OR P01.MGR_CD = l_inMgrCd) AND (coalesce(trim(both l_inIsinCd)::text, '') = '' OR VMG1.ISIN_CD = l_inIsinCd) ORDER BY
			P01.MGR_CD,
			VMG1.ISIN_CD,
			M01.HKT_CD,
			P01.SHOKAN_YMD,
			P01.KBG_SHOKAN_KBN,
			P02.KENSHU_CD,
			P02.KIBANGO_FROM;
	curKenshuA CURSOR FOR
		SELECT
			KENSHU_CD,              -- 券種コード
			MAISU,                  -- 枚数
			RISHIGAKU_FIRST,        -- 利子額（初期）
			RISHIGAKU_MID,          -- 利子額（通常）
			RISHIGAKU_LAST,         -- 利子額（終期）
			(
				SELECT
					CODE_NM
				FROM
					SCODE
				WHERE
					CODE_SHUBETSU = '227'
					AND CODE_VALUE = KBG_SHOKAN_KIND
			) AS KBG_SHOKAN_KIND_NM  -- 償還種類名称
		FROM
			KBG_KENSHU
		WHERE
			ITAKU_KAISHA_CD = gItakuKaishaCd
			AND MGR_CD = gMgrCd
		ORDER BY
			KENSHU_CD;
	curKenshuB CURSOR FOR
		SELECT
			P03.MGR_CD,              -- 銘柄コード
			P03.KENSHU_CD,           -- 券種コード
			P03.MAISU,               -- 枚数
			P03.RISHIGAKU_FIRST,     -- 利子額（初期）
			P03.RISHIGAKU_MID,       -- 利子額（通常）
			P03.RISHIGAKU_LAST,      -- 利子額（終期）
			VMG1.MGR_NM,             -- 銘柄の正式名称
			VMG1.MGR_RNM,            -- 銘柄略称
			VMG1.ISIN_CD,            -- ＩＳＩＮコード
			VMG1.HKT_CD,             -- 発行体コード
			VMG1.HAKKO_YMD,          -- 発行年月日
			VMG1.RIRITSU,            -- 利率
			VMG1.FULLSHOKAN_KJT,     -- 満期償還期日
			VMG1.SHASAI_TOTAL,       -- 社債の総額
			VMG1.KAKUSHASAI_KNGK,    -- 各社債の金額
			M01.HKT_RNM,             -- 発行体略称
			(
				SELECT
					CODE_NM
				FROM
					SCODE
				WHERE
					CODE_SHUBETSU = '227'
					AND CODE_VALUE = P03.KBG_SHOKAN_KIND
			) AS KBG_SHOKAN_KIND_NM, -- 償還種類名称
			(
				SELECT
					TSUKA_NM
				FROM
					MTSUKA
				WHERE
					TSUKA_CD = VMG1.HAKKO_TSUKA_CD
			) AS HAKKO_TSUKA_NM,     -- 発行通貨名称
			(
				SELECT
					TSUKA_NM
				FROM
					MTSUKA
				WHERE
					TSUKA_CD = VMG1.SHOKAN_TSUKA_CD
			) AS SHOKAN_TSUKA_NM,    -- 償還通貨名称
			(
				SELECT
					CODE_NM
				FROM
					SCODE
				WHERE
					CODE_SHUBETSU = '112'
					AND CODE_VALUE = VMG1.JTK_KBN
			) AS JTK_KBN_NM,         -- 受託区分名称
			pkIpaKibango.getFurikaeSogaku(
				P03.ITAKU_KAISHA_CD,
				P03.MGR_CD,
				gGyomuYmd
			) AS FURIKAESOGAKU        -- 振替金額
		FROM
			KBG_KENSHU P03,
			MGR_KIHON_VIEW VMG1,
			MHAKKOTAI M01
		WHERE
			P03.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
			AND P03.MGR_CD = VMG1.MGR_CD
			AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
			AND VMG1.HKT_CD = M01.HKT_CD
			AND P03.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND VMG1.JTK_KBN != '2'
			AND VMG1.JTK_KBN != '5'
			AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
			AND VMG1.MGR_STAT_KBN = '1'
			AND VMG1.KK_KANYO_FLG = '2'
			AND (
				coalesce(gKjnMatuYmd::text, '') = ''
				OR pkIpaKibango.getKjnZndk(
					P03.ITAKU_KAISHA_CD,
					P03.MGR_CD,
					gKjnMatuYmd
				) > 0
			)
			AND (coalesce(trim(both l_inMgrCd)::text, '') = '' OR P03.MGR_CD = l_inMgrCd)
			AND (coalesce(trim(both l_inIsinCd)::text, '') = '' OR VMG1.ISIN_CD = l_inIsinCd)
		ORDER BY
			KENSHU_CD;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, C_PROGRAM_ID || ' START');
	-- 入力パラメータチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inUserId)::text, '') = ''
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''
	OR (
		coalesce(trim(both l_inMgrCd)::text, '') = ''
		AND coalesce(trim(both l_inIsinCd)::text, '') = ''
		AND coalesce(trim(both l_inKjnYm)::text, '') = ''
	) THEN
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := 'パラメータエラー';
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, l_outSqlErrM);
		RETURN;
	END IF;
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '引数');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '委託会社コード:"' || l_inItakuKaishaCd || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, 'ユーザーＩＤ:"' || l_inUserId || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '帳票区分:"' || l_inChohyoKbn || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '銘柄コード:"' || l_inMgrCd || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, 'ＩＳＩＮコード:"' || l_inIsinCd || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '基準年月:"' || l_inKjnYm || '"');
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '業務日付:"' || gGyomuYmd || '"');
	-- 基準年月末日取得
	IF coalesce(trim(both l_inKjnYm)::text, '') = '' THEN
		gKjnMatuYmd := NULL;
	ELSE
		gKjnMatuYmd := pkDate.getGetsumatsuYmd(l_inKjnYm || '01', 0);
	END IF;
--	pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '基準年月末日:"' || gKjnMatuYmd || '"');
	-- 委託会社略名取得
	SELECT
		CASE WHEN JIKO_DAIKO_KBN='2' THEN  BANK_RNM  ELSE ' ' END
	INTO STRICT
		gItakuKaishaRnm
	FROM
		VJIKO_ITAKU
	WHERE
		KAIIN_ID = l_inItakuKaishaCd;
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '委託会社略名:"' || gItakuKaishaRnm || '"');
	-- 処理制御マスタから銘柄名称制御フラグ取得
	gMgrFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'getMgrNm01', '0');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '銘柄名称制御フラグ:"' || gMgrFlg || '"');
	-- 帳票ワーク削除
	DELETE FROM SREPORT_WK
	WHERE
		KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = gGyomuYmd
		AND CHOHYO_ID = C_CHOHYO_ID;
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '削除条件');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '識別コード:"' || l_inItakuKaishaCd || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, 'ユーザーＩＤ:"' || l_inUserId || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '帳票区分:"' || l_inChohyoKbn || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '作成日付:"' || gGyomuYmd || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '帳票ＩＤ:"' || C_CHOHYO_ID || '"');
	-- 変数初期化
	gItakuKaishaCd      := ' '; -- 委託会社コード（読込データ）
	gSeqNo              := 1;   -- シーケンス
	gNo                 := 1;   -- ナンバー（更新用）
	gMunitGensaiKngkSum := 0;   -- 銘柄単位元本減債金額（合計）
	gSeqStartA          := 0;   -- シーケンス開始（更新用Ａ）
	gSeqEndA            := 0;   -- シーケンス終了（更新用Ａ）
	gSeqStartB          := 0;   -- シーケンス開始（更新用Ｂ）
	gSeqEndB            := 0;   -- シーケンス終了（更新用Ｂ）
	gBreakHktCd         := ' '; -- 発行体コード（ブレイク確認用）
	gBreakIsinCd        := ' '; --ＩＳＩＮコード（ブレイク確認用）
	-- Initialize arrays (5 elements for 0-4 index)
	gKKenshuCd          := ARRAY[NULL, NULL, NULL, NULL, NULL]::numeric[];
	gKMaisu             := ARRAY[NULL, NULL, NULL, NULL, NULL]::numeric[];
	gKRishigakuFirst    := ARRAY[NULL, NULL, NULL, NULL, NULL]::numeric[];
	gKRishigakuMid      := ARRAY[NULL, NULL, NULL, NULL, NULL]::numeric[];
	gKRishigakuLast     := ARRAY[NULL, NULL, NULL, NULL, NULL]::numeric[];
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, gGyomuYmd, C_CHOHYO_ID);
	-- データ読込
	FOR recMeisai IN curMeisai
	LOOP
		-- 初回時
		IF gItakuKaishaCd = ' ' THEN
			gItakuKaishaCd   := recMeisai.ITAKU_KAISHA_CD;   -- 委託会社コード
			gMgrCd           := recMeisai.MGR_CD;            -- 銘柄コード
			gShokanKjt       := recMeisai.SHOKAN_KJT;        -- 償還期日
			gShokanYmd       := recMeisai.SHOKAN_YMD;        -- 償還日
			gKknChokyuKjt    := recMeisai.KKN_CHOKYU_KJT;    -- 基金徴求期日
			gKknChokyuYmd    := recMeisai.KKN_CHOKYU_YMD;    -- 基金徴求日
			gKbgShokanKbn    := recMeisai.KBG_SHOKAN_KBN;    -- 償還区分（実質記番号用）
			gMunitGensaiKngk := recMeisai.MUNIT_GENSAI_KNGK; -- 銘柄単位元本減債金額
			gKenshuCd        := recMeisai.KENSHU_CD;         -- 券種コード
			gKibangoFrom     := recMeisai.KIBANGO_FROM;      -- 記番号FROM
			gKibangoTo       := recMeisai.KIBANGO_TO;        -- 記番号TO
			gSensatsuNo      := recMeisai.SENSATSU_NO;       -- 籤札番号
			gMgrNm           := recMeisai.MGR_NM;            -- 銘柄の正式名称
			gMgrRnm          := recMeisai.MGR_RNM;           -- 銘柄略称
			gIsinCd          := recMeisai.ISIN_CD;           -- ＩＳＩＮコード
			gHktCd           := recMeisai.HKT_CD;            -- 発行体コード
			gHakkoYmd        := recMeisai.HAKKO_YMD;         -- 発行年月日
			gRiritsu         := recMeisai.RIRITSU;           -- 利率
			gFullshokanKjt   := recMeisai.FULLSHOKAN_KJT;    -- 満期償還期日
			gShasaiTotal     := recMeisai.SHASAI_TOTAL;      -- 社債の総額
			gKakushasaiKngk  := recMeisai.KAKUSHASAI_KNGK;   -- 各社債の金額
			gHakkoTsukaNm    := recMeisai.HAKKO_TSUKA_NM;    -- 発行通貨名称
			gShokanTsukaNm   := recMeisai.SHOKAN_TSUKA_NM;   -- 償還通貨名称
			gHktRnm          := recMeisai.HKT_RNM;           -- 発行体略称
			gJtkKbnNm        := recMeisai.JTK_KBN_NM;        -- 受託区分名称
			gKbgShokanKbnNm  := recMeisai.KBG_SHOKAN_KBN_NM; -- 償還区分名称
			gFurikaesogaku   := recMeisai.FURIKAESOGAKU;     -- 振替金額
			-- 銘柄単位元本減債金額（合計）
			gMunitGensaiKngkSum := gMunitGensaiKngk;
		-- 初回でない時
		ELSE
			-- 「委託会社コード」、「ＩＳＩＮコード」、「償還期日」、「償還日」、
			-- 「償還区分」、「券種コード」、「籤札番号」がブレイクしなく、
			-- 「記番号FROM」が１データ前の「記番号TO」+ 1 の時
			IF gItakuKaishaCd  = recMeisai.ITAKU_KAISHA_CD
			AND gIsinCd        = recMeisai.ISIN_CD
			AND gShokanKjt     = recMeisai.SHOKAN_KJT
			AND gShokanYmd     = recMeisai.SHOKAN_YMD
			AND gKbgShokanKbn  = recMeisai.KBG_SHOKAN_KBN
			AND gKenshuCd      = recMeisai.KENSHU_CD
			AND gSensatsuNo    = recMeisai.SENSATSU_NO
			AND recMeisai.KIBANGO_FROM = (gKibangoTo + 1) THEN
				-- 変数再セット（記番号TO）
				gKibangoTo := recMeisai.KIBANGO_TO;
			ELSE
				-- 登録前編集 ＋ 帳票ワーク登録処理
				CALL SPIPP001K00R01_insertData();
				-- ブレイク確認用変数へ格納
				gBreakHktCd        := gHktCd;        -- 発行体コード
				gBreakIsinCd       := gIsinCd;       -- ＩＳＩＮコード
				gBreakShokanKjt    := gShokanKjt;    -- 償還期日
				gBreakShokanYmd    := gShokanYmd;    -- 償還日
				gBreakKbgShokanKbn := gKbgShokanKbn; -- 償還区分（実質記番号用）
				-- 変数セット
				gItakuKaishaCd   := recMeisai.ITAKU_KAISHA_CD;   -- 委託会社コード
				gMgrCd           := recMeisai.MGR_CD;            -- 銘柄コード
				gShokanKjt       := recMeisai.SHOKAN_KJT;        -- 償還期日
				gShokanYmd       := recMeisai.SHOKAN_YMD;        -- 償還日
				gKknChokyuKjt    := recMeisai.KKN_CHOKYU_KJT;    -- 基金徴求期日
				gKknChokyuYmd    := recMeisai.KKN_CHOKYU_YMD;    -- 基金徴求日
				gKbgShokanKbn    := recMeisai.KBG_SHOKAN_KBN;    -- 償還区分（実質記番号用）
				gMunitGensaiKngk := recMeisai.MUNIT_GENSAI_KNGK; -- 銘柄単位元本減債金額
				gKenshuCd        := recMeisai.KENSHU_CD;         -- 券種コード
				gKibangoFrom     := recMeisai.KIBANGO_FROM;      -- 記番号FROM
				gKibangoTo       := recMeisai.KIBANGO_TO;        -- 記番号TO
				gSensatsuNo      := recMeisai.SENSATSU_NO;       -- 籤札番号
				gMgrNm           := recMeisai.MGR_NM;            -- 銘柄の正式名称
				gMgrRnm          := recMeisai.MGR_RNM;           -- 銘柄略称
				gIsinCd          := recMeisai.ISIN_CD;           -- ＩＳＩＮコード
				gHktCd           := recMeisai.HKT_CD;            -- 発行体コード
				gHakkoYmd        := recMeisai.HAKKO_YMD;         -- 発行年月日
				gRiritsu         := recMeisai.RIRITSU;           -- 利率
				gFullshokanKjt   := recMeisai.FULLSHOKAN_KJT;    -- 満期償還期日
				gShasaiTotal     := recMeisai.SHASAI_TOTAL;      -- 社債の総額
				gKakushasaiKngk  := recMeisai.KAKUSHASAI_KNGK;   -- 各社債の金額
				gHakkoTsukaNm    := recMeisai.HAKKO_TSUKA_NM;    -- 発行通貨名称
				gShokanTsukaNm   := recMeisai.SHOKAN_TSUKA_NM;   -- 償還通貨名称
				gHktRnm          := recMeisai.HKT_RNM;           -- 発行体略称
				gJtkKbnNm        := recMeisai.JTK_KBN_NM;        -- 受託区分名称
				gKbgShokanKbnNm  := recMeisai.KBG_SHOKAN_KBN_NM; -- 償還区分名称
				gFurikaesogaku   := recMeisai.FURIKAESOGAKU;     -- 振替金額
			END IF;
		END IF;
	END LOOP;
	-- 読込データが存在しない時
	IF gItakuKaishaCd = ' ' THEN
		-- 対象データなし作成フラグ・オン
		gNoDataFlg := '1';
		-- 「引数：銘柄コード」又は「引数：ＩＳＩＮコード」が設定されている
		IF (trim(both l_inMgrCd) IS NOT NULL AND (trim(both l_inMgrCd))::text <> '')
		OR (trim(both l_inIsinCd) IS NOT NULL AND (trim(both l_inIsinCd))::text <> '') THEN
			-- 変数初期化
			FOR gKCnt IN 0..4 LOOP
				gKKenshuCd[gKCnt+1]       := NULL; -- 券種コード
				gKMaisu[gKCnt+1]          := NULL; -- 枚数
				gKRishigakuFirst[gKCnt+1] := NULL; -- 利子額（初期）
				gKRishigakuMid[gKCnt+1]   := NULL; -- 利子額（通常）
				gKRishigakuLast[gKCnt+1]  := NULL; -- 利子額（終期）
			END LOOP;
			-- 償還種類名称
			gKKbgShokanKindNm := NULL;
			-- カウント（券種用）
			gKCnt := 0;
			-- 券種情報取得
			FOR recKenshuB IN curKenshuB
			LOOP
				gKKenshuCd[gKCnt+1]       := recKenshuB.KENSHU_CD / 1000;   -- 券種コード
				gKMaisu[gKCnt+1]          := recKenshuB.MAISU;              -- 枚数
				gKRishigakuFirst[gKCnt+1] := recKenshuB.RISHIGAKU_FIRST;    -- 利子額（初期）
				gKRishigakuMid[gKCnt+1]   := recKenshuB.RISHIGAKU_MID;      -- 利子額（通常）
				gKRishigakuLast[gKCnt+1]  := recKenshuB.RISHIGAKU_LAST;     -- 利子額（終期）
				gKKbgShokanKindNm       := recKenshuB.KBG_SHOKAN_KIND_NM; -- 償還種類名称
				gMgrCd                  := recKenshuB.MGR_CD;             -- 銘柄コード
				gMgrNm                  := recKenshuB.MGR_NM;             -- 銘柄の正式名称
				gMgrRnm                 := recKenshuB.MGR_RNM;            -- 銘柄略称
				gIsinCd                 := recKenshuB.ISIN_CD;            -- ＩＳＩＮコード
				gHktCd                  := recKenshuB.HKT_CD;             -- 発行体コード
				gHakkoYmd               := recKenshuB.HAKKO_YMD;          -- 発行年月日
				gRiritsu                := recKenshuB.RIRITSU;            -- 利率
				gFullshokanKjt          := recKenshuB.FULLSHOKAN_KJT;     -- 満期償還期日
				gShasaiTotal            := recKenshuB.SHASAI_TOTAL;       -- 社債の総額
				gKakushasaiKngk         := recKenshuB.KAKUSHASAI_KNGK;    -- 各社債の金額
				gHakkoTsukaNm           := recKenshuB.HAKKO_TSUKA_NM;     -- 発行通貨名称
				gShokanTsukaNm          := recKenshuB.SHOKAN_TSUKA_NM;    -- 償還通貨名称
				gHktRnm                 := recKenshuB.HKT_RNM;            -- 発行体略称
				gJtkKbnNm               := recKenshuB.JTK_KBN_NM;         -- 受託区分名称
				gFurikaesogaku          := recKenshuB.FURIKAESOGAKU;      -- 振替金額
				-- カウント（券種用）のカウントアップ
				gKCnt := gKCnt + 1;
			END LOOP;
			-- 券種情報が存在する時
			IF gKCnt != 0 THEN
				-- 対象データなし作成フラグ・オフ
				gNoDataFlg := '0';
				-- 銘柄名称(正式 OR 略称)編集
				CALL SPIPP001K00R01_setMgrNm();
				-- 帳票ワーク登録
				CALL pkPrint.SPIPP001K00R01_insertData(
					l_inKeyCd      => l_inItakuKaishaCd,   -- 識別コード
					l_inUserId     => l_inUserId,          -- ユーザＩＤ
					l_inChohyoKbn  => l_inChohyoKbn,       -- 帳票区分
					l_inSakuseiYmd => gGyomuYmd,           -- 作成日付
					l_inChohyoId   => C_CHOHYO_ID,         -- 帳票ＩＤ
					l_inSeqNo      => gSeqNo,              -- シーケンス
					l_inHeaderFlg  => 1,                   -- ヘッダフラグ
					l_inItem001    => gItakuKaishaRnm,     -- 委託会社略名
					l_inItem002    => l_inUserId,          -- ユーザーＩＤ
					l_inItem003    => gMgrCd,              -- 銘柄コード
					l_inItem004    => gProMgrNm,           -- 銘柄名称(正式 OR 略称)
					l_inItem005    => gIsinCd,             -- ＩＳＩＮコード
					l_inItem006    => gHktCd,              -- 発行体コード
					l_inItem007    => gHktRnm,             -- 発行体略称
					l_inItem008    => gJtkKbnNm,           -- 受託区分名称
					l_inItem009    => gHakkoYmd,           -- 発行年月日
					l_inItem010    => gHakkoTsukaNm,       -- 発行通貨名称
					l_inItem011    => gRiritsu,            -- 利率
					l_inItem012    => gShokanTsukaNm,      -- 償還通貨名称
					l_inItem013    => gKKbgShokanKindNm,   -- 償還種類名称
					l_inItem014    => gFullshokanKjt,      -- 満期償還期日
					l_inItem017    => gShasaiTotal,        -- 社債の総額
					l_inItem018    => gFurikaesogaku,      -- 振替金額
					l_inItem019    => gKakushasaiKngk,     -- 各社債の金額
					l_inItem020    => gKKenshuCd[0+1],       -- 券種コード１
					l_inItem021    => gKMaisu[0+1],          -- 枚数１
					l_inItem022    => gKRishigakuFirst[0+1], -- 利子額（初期）１
					l_inItem023    => gKRishigakuMid[0+1],   -- 利子額（通常）１
					l_inItem024    => gKRishigakuLast[0+1],  -- 利子額（終期）１
					l_inItem025    => gKKenshuCd[1+1],       -- 券種コード２
					l_inItem026    => gKMaisu[1+1],          -- 枚数２
					l_inItem027    => gKRishigakuFirst[1+1], -- 利子額（初期）２
					l_inItem028    => gKRishigakuMid[1+1],   -- 利子額（通常）２
					l_inItem029    => gKRishigakuLast[1+1],  -- 利子額（終期）２
					l_inItem030    => gKKenshuCd[2+1],       -- 券種コード３
					l_inItem031    => gKMaisu[2+1],          -- 枚数３
					l_inItem032    => gKRishigakuFirst[2+1], -- 利子額（初期）３
					l_inItem033    => gKRishigakuMid[2+1],   -- 利子額（通常）３
					l_inItem034    => gKRishigakuLast[2+1],  -- 利子額（終期）３
					l_inItem035    => gKKenshuCd[3+1],       -- 券種コード４
					l_inItem036    => gKMaisu[3+1],          -- 枚数４
					l_inItem037    => gKRishigakuFirst[3+1], -- 利子額（初期）４
					l_inItem038    => gKRishigakuMid[3+1],   -- 利子額（通常）４
					l_inItem039    => gKRishigakuLast[3+1],  -- 利子額（終期）４
					l_inItem040    => gKKenshuCd[4+1],       -- 券種コード５
					l_inItem041    => gKMaisu[4+1],          -- 枚数５
					l_inItem042    => gKRishigakuFirst[4+1], -- 利子額（初期）５
					l_inItem043    => gKRishigakuMid[4+1],   -- 利子額（通常）５
					l_inItem044    => gKRishigakuLast[4+1],  -- 利子額（終期）５
					l_inItem055    => C_CHOHYO_ID,         -- 帳票ＩＤ
					l_inKousinId   => l_inUserId,          -- 更新者
					l_inSakuseiId  => l_inUserId            -- 作成者
				);
			END IF;
		END IF;
		-- 対象データなし作成フラグがオンの時
		IF gNoDataFlg = '1' THEN
			-- 帳票ワーク登録
			CALL pkPrint.SPIPP001K00R01_insertData(
				l_inKeyCd      => l_inItakuKaishaCd, -- 識別コード
				l_inUserId     => l_inUserId,        -- ユーザＩＤ
				l_inChohyoKbn  => l_inChohyoKbn,     -- 帳票区分
				l_inSakuseiYmd => gGyomuYmd,         -- 作成日付
				l_inChohyoId   => C_CHOHYO_ID,       -- 帳票ＩＤ
				l_inSeqNo      => gSeqNo,            -- シーケンス
				l_inHeaderFlg  => 1,                 -- ヘッダフラグ
				l_inItem001    => gItakuKaishaRnm,   -- 委託会社略名
				l_inItem002    => l_inUserId,        -- ユーザーＩＤ
				l_inItem055    => C_CHOHYO_ID,       -- 帳票ＩＤ
				l_inItem057    => '対象データなし',  -- 対象データなし
				l_inKousinId   => l_inUserId,        -- 更新者
				l_inSakuseiId  => l_inUserId          -- 作成者
			);
		END IF;
	-- 読込データが存在する時
	ELSE
		-- 登録前編集 ＋ 帳票ワーク登録処理
		CALL SPIPP001K00R01_insertData();
		-- 帳票ワーク更新
		CALL SPIPP001K00R01_updateWorkA();
		CALL SPIPP001K00R01_updateWorkB();
	END IF;
	-- 正常終了
	l_outSqlCode := pkconstant.success();
	l_outSqlErrM := '';
	-- Arrays are automatically freed at end of procedure block
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
-- REVOKE ALL ON PROCEDURE spipp001k00r01 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE, l_inUserId SREPORT_WK.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_inMgrCd MGR_KIHON.MGR_CD%TYPE, l_inIsinCd MGR_KIHON.ISIN_CD%TYPE, l_inKjnYm text, l_outSqlCode OUT integer, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spipp001k00r01_insertdata () AS $body$
BEGIN
	-- 初回でなく、
	-- 発行体コード又はＩＳＩＮコード又は
	-- 償還期日又は償還日又は
	-- 償還区分（実質記番号用）がブレイク時
	IF gSeqNo != 1 THEN
		IF gBreakHktCd != gHktCd
		OR gBreakIsinCd != gIsinCd
		OR gBreakShokanKjt != gShokanKjt
		OR gBreakShokanYmd != gShokanYmd
		OR gBreakKbgShokanKbn != gKbgShokanKbn THEN
			-- 帳票ワーク更新
			CALL updateWorkA();
			IF gBreakHktCd = gHktCd
			AND gBreakIsinCd = gIsinCd THEN
				-- ナンバー
				gNo := gNo + 1;
				-- 銘柄単位元本減債金額（合計）
				gMunitGensaiKngkSum := gMunitGensaiKngkSum + gMunitGensaiKngk;
			ELSE
				-- 帳票ワーク更新
				CALL updateWorkB();
				-- ナンバー
				gNo := 1;
				-- 銘柄単位元本減債金額（合計）
				gMunitGensaiKngkSum := gMunitGensaiKngk;
			END IF;
		END IF;
	END IF;
	-- 発行体コード又はＩＳＩＮコードがブレイク時
	IF gBreakHktCd != gHktCd
	OR gBreakIsinCd != gIsinCd THEN
		-- 変数初期化
		FOR gKCnt IN 0..4 LOOP
			gKKenshuCd[gKCnt+1]       := NULL; -- 券種コード
			gKMaisu[gKCnt+1]          := NULL; -- 枚数
			gKRishigakuFirst[gKCnt+1] := NULL; -- 利子額（初期）
			gKRishigakuMid[gKCnt+1]   := NULL; -- 利子額（通常）
			gKRishigakuLast[gKCnt+1]  := NULL; -- 利子額（終期）
		END LOOP;
		-- 償還種類名称
		gKKbgShokanKindNm := NULL;
		-- カウント（券種用）
		gKCnt := 0;
		-- 券種情報取得
		FOR recKenshuA IN curKenshuA
		LOOP
			gKKenshuCd[gKCnt+1]       := recKenshuA.KENSHU_CD / 1000;   -- 券種コード
			gKMaisu[gKCnt+1]          := recKenshuA.MAISU;              -- 枚数
			gKRishigakuFirst[gKCnt+1] := recKenshuA.RISHIGAKU_FIRST;    -- 利子額（初期）
			gKRishigakuMid[gKCnt+1]   := recKenshuA.RISHIGAKU_MID;      -- 利子額（通常）
			gKRishigakuLast[gKCnt+1]  := recKenshuA.RISHIGAKU_LAST;     -- 利子額（終期）
			gKKbgShokanKindNm       := recKenshuA.KBG_SHOKAN_KIND_NM; -- 償還種類名称
			-- カウント（券種用）のカウントアップ
			gKCnt := gKCnt + 1;
		END LOOP;
	END IF;
	-- 券種コード編集
	IF gKenshuCd = 0 THEN
		gProKenshuCd := 0;
	ELSE
		gProKenshuCd := gKenshuCd / 1000;
	END IF;
	-- 銘柄名称(正式 OR 略称)編集
	CALL setMgrNm();
	-- 帳票ワーク登録
	CALL pkPrint.SPIPP001K00R01_insertData(
		l_inKeyCd      => l_inItakuKaishaCd,   -- 識別コード
		l_inUserId     => l_inUserId,          -- ユーザＩＤ
		l_inChohyoKbn  => l_inChohyoKbn,       -- 帳票区分
		l_inSakuseiYmd => gGyomuYmd,           -- 作成日付
		l_inChohyoId   => C_CHOHYO_ID,         -- 帳票ＩＤ
		l_inSeqNo      => gSeqNo,              -- シーケンス
		l_inHeaderFlg  => 1,                   -- ヘッダフラグ
		l_inItem001    => gItakuKaishaRnm,     -- 委託会社略名
		l_inItem002    => l_inUserId,          -- ユーザーＩＤ
		l_inItem003    => gMgrCd,              -- 銘柄コード
		l_inItem004    => gProMgrNm,           -- 銘柄名称(正式 OR 略称)
		l_inItem005    => gIsinCd,             -- ＩＳＩＮコード
		l_inItem006    => gHktCd,              -- 発行体コード
		l_inItem007    => gHktRnm,             -- 発行体略称
		l_inItem008    => gJtkKbnNm,           -- 受託区分名称
		l_inItem009    => gHakkoYmd,           -- 発行年月日
		l_inItem010    => gHakkoTsukaNm,       -- 発行通貨名称
		l_inItem011    => gRiritsu,            -- 利率
		l_inItem012    => gShokanTsukaNm,      -- 償還通貨名称
		l_inItem013    => gKKbgShokanKindNm,   -- 償還種類名称
		l_inItem014    => gFullshokanKjt,      -- 満期償還期日
		l_inItem015    => gKbgShokanKbn,       -- 償還区分（実質記番号用）
		l_inItem016    => gKbgShokanKbnNm,     -- 償還区分名称
		l_inItem017    => gShasaiTotal,        -- 社債の総額
		l_inItem018    => gFurikaesogaku,      -- 振替金額
		l_inItem019    => gKakushasaiKngk,     -- 各社債の金額
		l_inItem020    => gKKenshuCd[0+1],       -- 券種コード１
		l_inItem021    => gKMaisu[0+1],          -- 枚数１
		l_inItem022    => gKRishigakuFirst[0+1], -- 利子額（初期）１
		l_inItem023    => gKRishigakuMid[0+1],   -- 利子額（通常）１
		l_inItem024    => gKRishigakuLast[0+1],  -- 利子額（終期）１
		l_inItem025    => gKKenshuCd[1+1],       -- 券種コード２
		l_inItem026    => gKMaisu[1+1],          -- 枚数２
		l_inItem027    => gKRishigakuFirst[1+1], -- 利子額（初期）２
		l_inItem028    => gKRishigakuMid[1+1],   -- 利子額（通常）２
		l_inItem029    => gKRishigakuLast[1+1],  -- 利子額（終期）２
		l_inItem030    => gKKenshuCd[2+1],       -- 券種コード３
		l_inItem031    => gKMaisu[2+1],          -- 枚数３
		l_inItem032    => gKRishigakuFirst[2+1], -- 利子額（初期）３
		l_inItem033    => gKRishigakuMid[2+1],   -- 利子額（通常）３
		l_inItem034    => gKRishigakuLast[2+1],  -- 利子額（終期）３
		l_inItem035    => gKKenshuCd[3+1],       -- 券種コード４
		l_inItem036    => gKMaisu[3+1],          -- 枚数４
		l_inItem037    => gKRishigakuFirst[3+1], -- 利子額（初期）４
		l_inItem038    => gKRishigakuMid[3+1],   -- 利子額（通常）４
		l_inItem039    => gKRishigakuLast[3+1],  -- 利子額（終期）４
		l_inItem040    => gKKenshuCd[4+1],       -- 券種コード５
		l_inItem041    => gKMaisu[4+1],          -- 枚数５
		l_inItem042    => gKRishigakuFirst[4+1], -- 利子額（初期）５
		l_inItem043    => gKRishigakuMid[4+1],   -- 利子額（通常）５
		l_inItem044    => gKRishigakuLast[4+1],  -- 利子額（終期）５
		-- 45はナンバー（後で更新）
		l_inItem046    => gShokanKjt,          -- 償還期日
		l_inItem047    => gShokanYmd,          -- 償還日
		l_inItem048    => gKknChokyuKjt,       -- 基金徴求期日
		l_inItem049    => gKknChokyuYmd,       -- 基金徴求日
		l_inItem050    => gMunitGensaiKngk,    -- 銘柄単位元本減債金額
		l_inItem051    => gProKenshuCd,        -- 券種コード
		l_inItem052    => gKibangoFrom,        -- 記番号FROM
		l_inItem053    => gKibangoTo,          -- 記番号TO
		l_inItem054    => gSensatsuNo,         -- 籤札番号
		l_inItem055    => C_CHOHYO_ID,         -- 帳票ＩＤ
		-- 56は銘柄単位元本減債金額（合計）（後で更新）
		l_inKousinId   => l_inUserId,          -- 更新者
		l_inSakuseiId  => l_inUserId            -- 作成者
	);
	-- シーケンスのカウントアップ
	gSeqNo := gSeqNo + 1;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipp001k00r01_insertdata () FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spipp001k00r01_setmgrnm (
	INOUT gMgrFlg character(1),
	IN gMgrNm character varying(100),
	IN gMgrRnm character varying(50),
	INOUT gProMgrNm character varying(100)
) AS $body$
BEGIN
	IF gMgrFlg = '1' THEN
		gProMgrNm := SUBSTR(gMgrNm, 1, 50);
	ELSE
		gProMgrNm := gMgrRnm;
	END IF;
--		pkLog.debug(l_inUserId, C_PROGRAM_ID, C_PROGRAM_ID || '銘柄名称(正式 OR 略称):' || gProMgrNm);
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipp001k00r01_setmgrnm (INOUT gMgrFlg character(1), IN gMgrNm character varying(100), IN gMgrRnm character varying(50), INOUT gProMgrNm character varying(100)) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spipp001k00r01_updateworka () AS $body$
BEGIN
	-- 更新シーケンス設定
	gSeqStartA := gSeqEndA + 1; -- シーケンス開始（更新用Ａ）
	gSeqEndA := gSeqNo - 1;     -- シーケンス終了（更新用Ａ）
	-- 更新処理
	UPDATE SREPORT_WK SET
		ITEM045 = gNo,                               -- ナンバー
		ITEM013 = coalesce(ITEM013, ' '),                 -- 償還種類名称
		ITEM020 = coalesce(ITEM020, ' '),                 -- 券種コード１
		ITEM021 = coalesce(ITEM021, ' '),                 -- 枚数１
		ITEM022 = coalesce(ITEM022, ' '),                 -- 利子額（初期）１
		ITEM023 = coalesce(ITEM023, ' '),                 -- 利子額（通常）１
		ITEM024 = coalesce(ITEM024, ' '),                 -- 利子額（終期）１
		ITEM025 = coalesce(ITEM025, ' '),                 -- 券種コード２
		ITEM026 = coalesce(ITEM026, ' '),                 -- 枚数２
		ITEM027 = coalesce(ITEM027, ' '),                 -- 利子額（初期）２
		ITEM028 = coalesce(ITEM028, ' '),                 -- 利子額（通常）２
		ITEM029 = coalesce(ITEM029, ' '),                 -- 利子額（終期）２
		ITEM030 = coalesce(ITEM030, ' '),                 -- 券種コード３
		ITEM031 = coalesce(ITEM031, ' '),                 -- 枚数３
		ITEM032 = coalesce(ITEM032, ' '),                 -- 利子額（初期）３
		ITEM033 = coalesce(ITEM033, ' '),                 -- 利子額（通常）３
		ITEM034 = coalesce(ITEM034, ' '),                 -- 利子額（終期）３
		ITEM035 = coalesce(ITEM035, ' '),                 -- 券種コード４
		ITEM036 = coalesce(ITEM036, ' '),                 -- 枚数４
		ITEM037 = coalesce(ITEM037, ' '),                 -- 利子額（初期）４
		ITEM038 = coalesce(ITEM038, ' '),                 -- 利子額（通常）４
		ITEM039 = coalesce(ITEM039, ' '),                 -- 利子額（終期）４
		ITEM040 = coalesce(ITEM040, ' '),                 -- 券種コード５
		ITEM041 = coalesce(ITEM041, ' '),                 -- 枚数５
		ITEM042 = coalesce(ITEM042, ' '),                 -- 利子額（初期）５
		ITEM043 = coalesce(ITEM043, ' '),                 -- 利子額（通常）５
		ITEM044 = coalesce(ITEM044, ' '),                 -- 利子額（終期）５
		ITEM051 = CASE WHEN ITEM051='0' THEN  ' '  ELSE ITEM051 END , -- 券種コード → 券種が0の時は空にする
		ITEM052 = CASE WHEN ITEM051='0' THEN  ' '  ELSE ITEM052 END , -- 記番号FROM → 券種が0の時は空にする
		ITEM053 = CASE WHEN ITEM051='0' THEN  ' '  ELSE ITEM053 END , -- 記番号TO   → 券種が0の時は空にする
		ITEM054 = CASE WHEN ITEM051='0' THEN  ' '  ELSE ITEM054 END   -- 籤札番号   → 券種が0の時は空にする
	WHERE
		KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = gGyomuYmd
		AND CHOHYO_ID = C_CHOHYO_ID
		AND SEQ_NO BETWEEN gSeqStartA AND gSeqEndA;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipp001k00r01_updateworka () FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spipp001k00r01_updateworkb () AS $body$
BEGIN
	-- 更新シーケンス設定
	gSeqStartB := gSeqEndB + 1; -- シーケンス開始（更新用Ｂ）
	gSeqEndB := gSeqNo - 1;     -- シーケンス終了（更新用Ｂ）
	-- 更新処理
	UPDATE SREPORT_WK SET
		ITEM056 = gMunitGensaiKngkSum::text  -- 銘柄単位元本減債金額（合計）
	WHERE
		KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = gGyomuYmd
		AND CHOHYO_ID = C_CHOHYO_ID
		AND SEQ_NO BETWEEN gSeqStartB AND gSeqEndB;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipp001k00r01_updateworkb () FROM PUBLIC;