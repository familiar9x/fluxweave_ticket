




CREATE OR REPLACE PROCEDURE spipp002k00r01_02 ( 
	l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE,            -- 委託会社コード
 l_inGyomuYmd SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE, -- 業務日付
 l_inUserId SREPORT_WK.USER_ID%TYPE,           -- ユーザーＩＤ
 l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE,        -- 帳票区分
 l_inTsuchiYmd text,                          -- 通知日
 l_outSqlCode OUT integer,                           -- リターン値
 l_outSqlErrM OUT text                           -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2007
-- * 会社名:JIP
-- *
-- * 概要　:社債原簿（実質記番号方式）作成
-- *
-- * 引数　:l_inItakuKaishaCd :委託会社コード
-- *        l_inGyomuYmd      :業務日付
-- *        l_inUserId        :ユーザーＩＤ
-- *        l_inChohyoKbn     :帳票区分
-- *        l_inTsuchiYmd     :通知日
-- *        l_outSqlCode      :リターン値
-- *        l_outSqlErrM      :エラーコメント
-- *
-- * 返り値: なし
-- *
-- * @author ASK
-- * @version $Id: SPIPP002K00R01_02.sql,v 1.10 2020/09/25 07:58:39 otsuka Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2007.05.01 中村        新規作成
-- ***************************************************************************
--	/*==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_PROGRAM_ID      CONSTANT varchar(50)              := 'SPIPP002K00R01_02'; -- プログラムＩＤ
	C_CHOHYO_SOUFU_ID CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IPP30000211';       -- 帳票ＩＤ（送付）
	C_CHOHYO_GENBO_ID CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IPP30000212';       -- 帳票ＩＤ（原簿）
	C_NO_DATA         CONSTANT integer                   := 2;                   -- 対象データなし
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gSeqNo           numeric;                                -- シーケンス
	gSeqStart        numeric;                                -- シーケンス開始
	gSeqEnd          numeric;                                -- シーケンス終了
	gBankNm          SOWN_INFO.BANK_NM%TYPE;                -- 銀行名称
	gBushoNm1        SOWN_INFO.BUSHO_NM1%TYPE;              -- 担当部署名１
	gGenboSofuFlg    SOWN_INFO.GENBO_SOFU_FLG%TYPE;         -- 原簿送付状出力フラグ
	gWTsuchiYmd      varchar(20);                          -- 通知日（西暦）
	gAtena           varchar(200);                         -- 宛名
	gOutflg          numeric;                                -- 正常処理フラグ
	gKbgShokanKbnNm  SCODE.CODE_NM%TYPE;                    -- 償還区分名称（事由）
	gMunitGensaiKngk KBG_GENBO_WORK.MUNIT_GENSAI_KNGK%TYPE; -- 銘柄単位元本減債金額
	gRknKngk         KBG_GENBO_WORK.RKN_KNGK%TYPE;          -- 利金金額
	gNo              numeric;                                -- ナンバー
	gHktCd           KBG_GENBO_WORK.HKT_CD%TYPE;            -- 発行体コード
	gIsinCd          KBG_GENBO_WORK.ISIN_CD%TYPE;           -- ＩＳＩＮコード
	gGnrbaraiKjt     KBG_GENBO_WORK.GNRBARAI_KJT%TYPE;      -- 元利払期日
	gGnrYmd          KBG_GENBO_WORK.GNR_YMD%TYPE;           -- 元利払日
	gKbgShokanKbn    KBG_GENBO_WORK.KBG_SHOKAN_KBN%TYPE;    -- 償還区分（実質記番号用）
	gChohyoId        SREPORT_WK.CHOHYO_ID%TYPE;             -- 帳票ＩＤ
	gProKenshuCd     numeric;                                -- 券種コード（編集用）
   	gChohyoSortFlg	 MPROCESS_CTL.CTL_VALUE%TYPE;			-- 発行体宛帳票ソート順変更フラグ
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	curSofu CURSOR FOR
		SELECT DISTINCT
			P04.HKT_CD,       -- 発行体コード
			P04.ISIN_CD,      -- ＩＳＩＮコード
			P04.MGR_NM,       -- 銘柄の正式名称
            P04.MGR_CD,       -- 銘柄コード
			M01.SFSK_POST_NO, -- 送付先郵便番号
			M01.ADD1,         -- 送付先住所１
			M01.ADD2,         -- 送付先住所２
			M01.ADD3,         -- 送付先住所３
			M01.HKT_NM,       -- 発行体名称
			M01.HKT_KANA_RNM, -- 発行体略称カナ
			M01.SFSK_BUSHO_NM  -- 送付先担当部署名称
		FROM
			KBG_GENBO_WORK P04,
			MHAKKOTAI M01
		WHERE
			P04.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
			AND P04.HKT_CD = M01.HKT_CD
			AND P04.USER_ID = l_inUserId
			AND P04.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			-- リアルｏｒバッチ条件========================================================
			-- バッチ時は、原簿出力区分 = '1' 又は（原簿出力区分 = '2' かつ 残高0の条件）
			-- ============================================================================
			AND (
				l_inChohyoKbn = '0'
				OR (
					l_inChohyoKbn = '1'
					AND (
						P04.SHASAI_GENBO_OUT_KBN = '1'
						OR (
							P04.SHASAI_GENBO_OUT_KBN = '2'
							AND pkIpaKibango.getKjnZndk(
									P04.ITAKU_KAISHA_CD,
									P04.MGR_CD,
									l_inGyomuYmd
							) = 0
						)
					)
				)
			)
		ORDER BY
			CASE WHEN  gChohyoSortFlg ='1' THEN  M01.HKT_KANA_RNM   ELSE P04.HKT_CD END ,
			P04.HKT_CD,
			CASE WHEN  gChohyoSortFlg ='1' THEN  P04.MGR_CD   ELSE P04.ISIN_CD END;
	curGenbo CURSOR FOR
		SELECT
			P04.GNRBARAI_KJT,             -- 元利払期日
			P04.KBG_SHOKAN_KBN,           -- 償還区分（実質記番号用）
			P04.KENSHU_CD,                -- 券種コード
			P04.GNR_YMD,                  -- 元利払日
			P04.MUNIT_GENSAI_KNGK,        -- 銘柄単位元本減債金額
			P04.KIBANGO_FROM,             -- 記番号FROM
			P04.KIBANGO_TO,               -- 記番号TO
			P04.GENZON_KNGK,              -- 現存金額
			P04.RKN_KNGK,                 -- 利金金額
			P04.HKT_CD,                   -- 発行体コード
			P04.ISIN_CD,                  -- ＩＳＩＮコード
			P04.MGR_CD,                   -- 銘柄コード
			P04.MGR_NM,                   -- 銘柄の正式名称
			P04.JUTAKUSAKI_TITLE,         -- 受託先タイトル
			P04.RBR_KJT_NM,               -- 利払期日名称
			P04.HAKKO_YMD,                -- 発行年月日
			P04.FULLSHOKAN_KJT,           -- 満期償還期日
			P04.SHASAI_TOTAL,             -- 社債の総額
			P04.KAKUSHASAI_KNGK,          -- 各社債の金額
			P04.HRKM_KNGK,                -- 払込金額
			P04.RIRITSU,                  -- 利率
			(
				SELECT
					CODE_NM
				FROM
					SCODE
				WHERE
					CODE_SHUBETSU = '529'
					AND CODE_VALUE = P04.RITSUKE_WARIBIKI_KBN
			) AS RITSUKE_WARIBIKI_KBN_NM, -- 利付割引区分名称
			(
				SELECT
					CODE_NM
				FROM
					SCODE
				WHERE
					CODE_SHUBETSU = '226'
					AND CODE_VALUE = P04.KBG_SHOKAN_KBN
			) AS KBG_SHOKAN_KBN_NM,       -- 償還区分名称
			(
				SELECT
					CODE_NM
				FROM
					SCODE
				WHERE
					CODE_SHUBETSU = '116'
					AND CODE_VALUE = P04.SHOKAN_METHOD_CD
			) AS SHOKAN_METHOD_NM,        -- 償還方法名称
			(
				SELECT
					TSUKA_NM
				FROM
					MTSUKA
				WHERE
					TSUKA_CD = P04.HAKKO_TSUKA_CD
			) AS HAKKO_TSUKA_NM,          -- 発行通貨名称
			M01.HKT_NM,                   -- 発行体名称
   			M01.HKT_KANA_RNM,             -- 発行体略称カナ
			MG1.DEFAULT_YMD,              -- デフォルト日
			(
				SELECT
					DEFAULT_RIYU_NM
				FROM
					DEFAULT_RIYU_KANRI
				WHERE
					ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
					AND DEFAULT_RIYU = MG1.DEFAULT_RIYU
			) AS DEFAULT_RIYU_NM,         -- デフォルト理由名称
            CASE
				WHEN (trim(both MG1.DEFAULT_YMD) IS NOT NULL AND (trim(both MG1.DEFAULT_YMD))::text <> '') THEN 'デフォルト日'
				ELSE ' '
			END AS DEFAULT_YMD_TITLE,     -- デフォルト日タイトル
			CASE
				WHEN (trim(both MG1.DEFAULT_YMD) IS NOT NULL AND (trim(both MG1.DEFAULT_YMD))::text <> '') THEN 'デフォルト事由'
				ELSE ' '
			 END AS DEFAULT_RIYU_TITLE     -- デフォルト理由タイトル
		FROM
			KBG_GENBO_WORK P04,
			MHAKKOTAI M01,
            MGR_KIHON MG1
		WHERE
			P04.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
			AND P04.HKT_CD = M01.HKT_CD
			AND P04.USER_ID = l_inUserId
			AND P04.ITAKU_KAISHA_CD = l_inItakuKaishaCd
            AND P04.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
            AND P04.MGR_CD = MG1.MGR_CD
			-- リアルｏｒバッチ条件========================================================
			-- バッチ時は、原簿出力区分 = '1' 又は（原簿出力区分 = '2' かつ 残高0の条件）
			-- ============================================================================
			AND (
				l_inChohyoKbn = '0'
				OR (
					l_inChohyoKbn = '1'
					AND (
						P04.SHASAI_GENBO_OUT_KBN = '1'
						OR (
							P04.SHASAI_GENBO_OUT_KBN = '2'
							AND pkIpaKibango.getKjnZndk(
									P04.ITAKU_KAISHA_CD,
									P04.MGR_CD,
									l_inGyomuYmd
							) = 0
						)
					)
				)
			)
		ORDER BY
			CASE WHEN  gChohyoSortFlg ='1' THEN  M01.HKT_KANA_RNM   ELSE P04.HKT_CD END ,
			P04.HKT_CD,
			CASE WHEN  gChohyoSortFlg ='1' THEN  P04.MGR_CD   ELSE P04.ISIN_CD END ,
			P04.GNR_YMD,
			CASE WHEN P04.KBG_SHOKAN_KBN='01' THEN  3 WHEN P04.KBG_SHOKAN_KBN='61' THEN  2 WHEN P04.KBG_SHOKAN_KBN='62' THEN  4 WHEN P04.KBG_SHOKAN_KBN='63' THEN  5 WHEN P04.KBG_SHOKAN_KBN='64' THEN  6 WHEN P04.KBG_SHOKAN_KBN='99' THEN  1			 END ,
			P04.KENSHU_CD,
			P04.KIBANGO_FROM;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, C_PROGRAM_ID || ' START');
	-- 入力パラメータチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inGyomuYmd)::text, '') = ''
	OR coalesce(trim(both l_inUserId)::text, '') = ''
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = '' THEN
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := 'パラメータエラー';
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, l_outSqlErrM);
		RETURN;
	END IF;
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '引数');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '委託会社コード:"' || l_inItakuKaishaCd || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '業務日付:"' || l_inGyomuYmd || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, 'ユーザーＩＤ:"' || l_inUserId || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '帳票区分:"' || l_inChohyoKbn || '"');
	-- 自行・委託会社マスタ情報取得
	BEGIN
		SELECT
			BANK_NM,       -- 銀行名称
			BUSHO_NM1,     -- 担当部署名１
			GENBO_SOFU_FLG  -- 原簿送付状出力フラグ
		INTO STRICT
			gBankNm,
			gBushoNm1,
			gGenboSofuFlg
		FROM
			VJIKO_ITAKU
		WHERE
			KAIIN_ID = l_inItakuKaishaCd;
--		pkLog.debug(l_inUserId, C_PROGRAM_ID, '自行・委託会社マスタ検索条件');
--		pkLog.debug(l_inUserId, C_PROGRAM_ID, '委託会社コード:"' || l_inItakuKaishaCd || '"');
--		pkLog.debug(l_inUserId, C_PROGRAM_ID, '取得情報');
--		pkLog.debug(l_inUserId, C_PROGRAM_ID, '銀行名称:"' || gBankNm || '"');
--		pkLog.debug(l_inUserId, C_PROGRAM_ID, '担当部署名１:"' || gBushoNm1 || '"');
--		pkLog.debug(l_inUserId, C_PROGRAM_ID, '原簿送付状出力フラグ:"' || gGenboSofuFlg || '"');
	EXCEPTION
		WHEN no_data_found THEN
			l_outSqlCode := pkconstant.FATAL();
			l_outSqlErrM := '自行・委託会社マスタ情報取得エラー';
			CALL pkLog.fatal('ECM701', C_PROGRAM_ID, l_outSqlErrM);
			RETURN;
	END;
	-- 通知日の西暦変換
	gWTsuchiYmd := '      年  月  日';
	IF (trim(both l_inTsuchiYmd) IS NOT NULL AND (trim(both l_inTsuchiYmd))::text <> '') THEN
		gWTsuchiYmd := pkDate.seirekiChangeSuppressNenGappi(l_inTsuchiYmd);
	END IF;
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '通知日:"' || l_inTsuchiYmd || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '通知日（西暦）:"' || gWTsuchiYmd || '"');
	-- 帳票ワーク削除
	DELETE FROM SREPORT_WK
	WHERE
		KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = l_inGyomuYmd
		AND CHOHYO_ID IN (C_CHOHYO_SOUFU_ID, C_CHOHYO_GENBO_ID);
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '削除条件');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '識別コード:"' || l_inItakuKaishaCd || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, 'ユーザーＩＤ:"' || l_inUserId || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '帳票区分:"' || l_inChohyoKbn || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '作成日付:"' || l_inGyomuYmd || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '帳票ＩＤ（送付）:"' || C_CHOHYO_SOUFU_ID || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '帳票ＩＤ（原簿）:"' || C_CHOHYO_GENBO_ID || '"');
	
    --発行体宛帳票ソート順変更フラグ取得
	gChohyoSortFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'SeikyusyoSort', '0');
	-- 原簿送付状出力フラグ='1'の時、送付状作成
	IF gGenboSofuFlg = '1' THEN
		-- シーケンス初期化
		gSeqNo := 1;
		-- 送付データ読込
		FOR recSofu IN curSofu
		LOOP
			-- 宛名編集
			CALL pkIpaName.getMadoFutoAtena(recSofu.HKT_NM, recSofu.SFSK_BUSHO_NM, gOutflg, gAtena);
--			pkLog.debug(l_inUserId, C_PROGRAM_ID, '発行体名称:"' || recSofu.HKT_NM || '"');
--			pkLog.debug(l_inUserId, C_PROGRAM_ID, '送付先担当部署名称:"' || recSofu.SFSK_BUSHO_NM || '"');
--			pkLog.debug(l_inUserId, C_PROGRAM_ID, '宛名:"' || gAtena || '"');
			-- 帳票ワーク追加
					-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := recSofu.HKT_CD;	-- 発行体コード
		v_item.l_inItem002 := recSofu.ISIN_CD;	-- ＩＳＩＮコード
		v_item.l_inItem003 := gWTsuchiYmd;	-- 通知日
		v_item.l_inItem004 := recSofu.MGR_NM;	-- 銘柄の正式名称
		v_item.l_inItem005 := recSofu.SFSK_POST_NO;	-- 送付先郵便番号
		v_item.l_inItem006 := recSofu.ADD1;	-- 送付先住所１
		v_item.l_inItem007 := recSofu.ADD2;	-- 送付先住所２
		v_item.l_inItem008 := recSofu.ADD3;	-- 送付先住所３
		v_item.l_inItem009 := gAtena;	-- 発行体名称・担当部署名称（宛名）
		v_item.l_inItem010 := gBankNm;	-- 銀行名称
		v_item.l_inItem011 := gBushoNm1;	-- 担当部署名１
		v_item.l_inItem012 := recSofu.HKT_KANA_RNM;	-- 発行体略称カナ
		v_item.l_inItem013 := recSofu.MGR_CD;	-- 銘柄コード
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> C_CHOHYO_SOUFU_ID,
			l_inSeqNo		=> gSeqNo::integer,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
			-- シーケンスのカウントアップ
			gSeqNo := gSeqNo + 1;
		END LOOP;
		-- 送付データが存在する時
		IF gSeqNo != 1 THEN
			-- ヘッダレコードを追加
			CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, C_CHOHYO_SOUFU_ID);
		END IF;
--	ELSE
--		pkLog.debug(l_inUserId, C_PROGRAM_ID, '原簿送付状出力フラグ:"' || gGenboSofuFlg || '"');
--		pkLog.debug(l_inUserId, C_PROGRAM_ID, '原簿送付状は作成しない');
	END IF;
	-- 変数初期化
	gSeqNo := 1;
	gNo := 1;
	gSeqStart := 0;
	gSeqEnd := 0;
	-- 原簿データ読込
	FOR recGenbo IN curGenbo
	LOOP
		-- 初回でなく、
		-- 発行体コード又はＩＳＩＮコード又は
		-- 元利払期日又は元利払日又は
		-- 償還区分（実質記番号用）がブレイク時
		IF gSeqNo != 1 THEN
			IF gHktCd != recGenbo.HKT_CD
			OR gIsinCd != recGenbo.ISIN_CD
			OR gGnrbaraiKjt != recGenbo.GNRBARAI_KJT
			OR gGnrYmd != recGenbo.GNR_YMD
			OR gKbgShokanKbn != recGenbo.KBG_SHOKAN_KBN THEN
				-- 更新シーケンス設定
				gSeqStart := gSeqEnd + 1; -- シーケンス開始
				gSeqEnd := gSeqNo - 1;    -- シーケンス終了
				-- 更新処理
				UPDATE SREPORT_WK SET
					ITEM019 = gNo,                               -- ナンバー
					ITEM023 = coalesce(ITEM023, ' '),                 -- 銘柄単位元本減債金額
					ITEM024 = CASE WHEN ITEM024='0' THEN  ' '  ELSE ITEM024 END , -- 券種コード
					ITEM025 = CASE WHEN ITEM025='0' THEN  ' '  ELSE ITEM025 END , -- 記番号FROM
					ITEM026 = CASE WHEN ITEM026='0' THEN  ' '  ELSE ITEM026 END , -- 記番号TO
					ITEM028 = coalesce(ITEM028, ' ')                  -- 利金金額
				WHERE
					KEY_CD = l_inItakuKaishaCd
					AND USER_ID = l_inUserId
					AND CHOHYO_KBN = l_inChohyoKbn
					AND SAKUSEI_YMD = l_inGyomuYmd
					AND CHOHYO_ID = C_CHOHYO_GENBO_ID
					AND SEQ_NO BETWEEN gSeqStart AND gSeqEnd;
				-- ナンバーのカウントアップ（発行体コード又はＩＳＩＮコードがブレイク時は初期化）
				IF gHktCd = recGenbo.HKT_CD
				AND gIsinCd = recGenbo.ISIN_CD THEN
					gNo := gNo + 1;
				ELSE
					gNo := 1;
				END IF;
			END IF;
		END IF;
		-- 償還区分によるケース分け
		CASE recGenbo.KBG_SHOKAN_KBN
			-- 振替債移行
			WHEN '01' THEN
				-- 償還区分名称（事由）
				gKbgShokanKbnNm := '振替債移行';
				-- 銘柄単位元本減債金額
				gMunitGensaiKngk := NULL;
				-- 利金金額
				gRknKngk := NULL;
--				pkLog.debug(l_inUserId, C_PROGRAM_ID, '振替債移行');
--				pkLog.debug(l_inUserId, C_PROGRAM_ID, '償還区分名称（事由）:"' || gKbgShokanKbnNm || '"');
--				pkLog.debug(l_inUserId, C_PROGRAM_ID, '銘柄単位元本減債金額:"' || gMunitGensaiKngk || '"');
--				pkLog.debug(l_inUserId, C_PROGRAM_ID, '利金金額:"' || gRknKngk || '"');
			-- 利金のみ
			WHEN '99' THEN
				-- 償還区分名称（事由）
				gKbgShokanKbnNm := '定時償還';
				-- 銘柄単位元本減債金額
				gMunitGensaiKngk := 0;
				-- 利金金額
				gRknKngk := recGenbo.RKN_KNGK;
--				pkLog.debug(l_inUserId, C_PROGRAM_ID, '利金のみ');
--				pkLog.debug(l_inUserId, C_PROGRAM_ID, '償還区分名称（事由）:"' || gKbgShokanKbnNm || '"');
--				pkLog.debug(l_inUserId, C_PROGRAM_ID, '銘柄単位元本減債金額:"' || gMunitGensaiKngk || '"');
--				pkLog.debug(l_inUserId, C_PROGRAM_ID, '利金金額:"' || gRknKngk || '"');
			-- その他の時
			ELSE
				-- 銘柄単位元本減債金額
				gMunitGensaiKngk := recGenbo.MUNIT_GENSAI_KNGK;
				-- 買入消却（一部）又は買入消却（全額）の時
				IF recGenbo.KBG_SHOKAN_KBN = '62' OR recGenbo.KBG_SHOKAN_KBN = '63' THEN
					-- 償還区分名称（事由）
					IF (trim(both recGenbo.DEFAULT_YMD) IS NOT NULL AND (trim(both recGenbo.DEFAULT_YMD))::text <> '')
							AND recGenbo.GNR_YMD >= recGenbo.DEFAULT_YMD THEN
						-- デフォルト銘柄の場合は'元本償還'
						gKbgShokanKbnNm := '元本償還';
					ELSE
						gKbgShokanKbnNm := '買入消却';
					END IF;
					-- 利金金額
					gRknKngk := NULL;
				ELSE
					-- 償還区分名称（事由）
					gKbgShokanKbnNm := recGenbo.KBG_SHOKAN_KBN_NM;
					-- 利金金額
					gRknKngk := recGenbo.RKN_KNGK;
				END IF;
--				pkLog.debug(l_inUserId, C_PROGRAM_ID, 'その他');
--				pkLog.debug(l_inUserId, C_PROGRAM_ID, '償還区分名称（事由）:"' || gKbgShokanKbnNm || '"');
--				pkLog.debug(l_inUserId, C_PROGRAM_ID, '銘柄単位元本減債金額:"' || gMunitGensaiKngk || '"');
--				pkLog.debug(l_inUserId, C_PROGRAM_ID, '利金金額:"' || gRknKngk || '"');
		END CASE;
		-- 券種コード編集
		IF recGenbo.KENSHU_CD = 0 THEN
			gProKenshuCd := NULL;
		ELSE
			gProKenshuCd := recGenbo.KENSHU_CD / 1000;
		END IF;
		-- 帳票ワーク追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := recGenbo.HKT_CD;	-- 発行体コード
		v_item.l_inItem002 := recGenbo.ISIN_CD;	-- ＩＳＩＮコード
		v_item.l_inItem003 := gWTsuchiYmd;	-- 通知日
		v_item.l_inItem004 := recGenbo.HKT_NM;	-- 発行体名称
		v_item.l_inItem005 := recGenbo.MGR_NM;	-- 銘柄の正式名称
		v_item.l_inItem006 := recGenbo.JUTAKUSAKI_TITLE;	-- 受託先タイトル
		v_item.l_inItem007 := gBankNm;	-- 銀行名称
		v_item.l_inItem008 := recGenbo.HAKKO_YMD;	-- 発行年月日
		v_item.l_inItem009 := recGenbo.HAKKO_YMD;	-- 払込年月日（発行年月日と同じ）
		v_item.l_inItem010 := recGenbo.FULLSHOKAN_KJT;	-- 満期償還期日
		v_item.l_inItem011 := recGenbo.SHASAI_TOTAL;	-- 社債の総額
		v_item.l_inItem012 := recGenbo.HKT_KANA_RNM;	-- 発行体略称カナ
		v_item.l_inItem013 := recGenbo.MGR_CD;	-- 銘柄コード
		v_item.l_inItem014 := recGenbo.KAKUSHASAI_KNGK;	-- 各社債の金額
		v_item.l_inItem015 := recGenbo.HRKM_KNGK;	-- 払込金額
		v_item.l_inItem016 := recGenbo.HAKKO_TSUKA_NM;	-- 発行通貨名称
		v_item.l_inItem017 := recGenbo.SHOKAN_METHOD_NM;	-- 償還方法名称
		v_item.l_inItem018 := recGenbo.RBR_KJT_NM;	-- 利払期日名称
		v_item.l_inItem020 := recGenbo.RIRITSU;	-- 利率
		v_item.l_inItem021 := recGenbo.RITSUKE_WARIBIKI_KBN_NM;	-- 利付割引区分名称
		v_item.l_inItem022 := recGenbo.GNRBARAI_KJT;	-- 元利払期日
		v_item.l_inItem023 := recGenbo.GNR_YMD;	-- 元利払日
		v_item.l_inItem024 := gKbgShokanKbnNm;	-- 償還区分名称（事由）
		v_item.l_inItem025 := gMunitGensaiKngk;	-- 銘柄単位元本減債金額
		v_item.l_inItem026 := gProKenshuCd;	-- 券種コード
		v_item.l_inItem027 := recGenbo.KIBANGO_FROM;	-- 記番号FROM
		v_item.l_inItem028 := recGenbo.KIBANGO_TO;	-- 記番号TO
		v_item.l_inItem030 := recGenbo.GENZON_KNGK;	-- 現存金額
		v_item.l_inItem031 := gRknKngk;	-- 利金金額
		v_item.l_inItem032 := recGenbo.DEFAULT_YMD_TITLE;	-- デフォルト日タイトル
		v_item.l_inItem033 := recGenbo.DEFAULT_RIYU_TITLE;	-- デフォルト理由タイトル
		v_item.l_inItem034 := recGenbo.DEFAULT_YMD;	-- デフォルト日
		v_item.l_inItem035 := recGenbo.DEFAULT_RIYU_NM;	-- デフォルト理由名称
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
		l_inChohyoId	=> C_CHOHYO_GENBO_ID,
			l_inSeqNo		=> gSeqNo::integer,
			l_inHeaderFlg	=> '0',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		-- シーケンスのカウントアップ
		gSeqNo := gSeqNo + 1;
		-- ブレイク確認用変数へ格納
		gHktCd        := recGenbo.HKT_CD;         -- 発行体コード
		gIsinCd       := recGenbo.ISIN_CD;        -- ＩＳＩＮコード
		gGnrbaraiKjt  := recGenbo.GNRBARAI_KJT;   -- 元利払期日
		gGnrYmd       := recGenbo.GNR_YMD;        -- 元利払日
		gKbgShokanKbn := recGenbo.KBG_SHOKAN_KBN; -- 償還区分（実質記番号用）
	END LOOP;
	-- 原簿データが存在しない時
	IF gSeqNo = 1 THEN
		-- Fibrige対応の為、バッチ時も「対象データなし」を作成
		-- ヘッダレコード追加は常に発生するようになった為、初期処理で1箇所に纏める事が可能
		-- バッチ出力指示から出力されないように、PrtOkには書込しない
		-- 「対象データなし」データ作成
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem003 := gWTsuchiYmd;	-- 通知日
		v_item.l_inItem029 := '対象データなし';	-- 対象データなし
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
		l_inChohyoId	=> C_CHOHYO_GENBO_ID,
		l_inSeqNo		=> gSeqNo::integer,
		l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		-- ヘッダレコードを追加
		CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, C_CHOHYO_GENBO_ID);
		-- 終了（対象データなし）
		l_outSqlCode :=C_NO_DATA;
		l_outSqlErrM := '';
	-- 送付データが存在する時
	ELSE
		-- 更新シーケンス設定
		gSeqStart := gSeqEnd + 1; -- シーケンス開始
		gSeqEnd := gSeqNo - 1;    -- シーケンス終了
		-- 更新処理
		UPDATE SREPORT_WK SET
			ITEM019 = gNo,                               -- ナンバー
			ITEM023 = coalesce(ITEM023, ' '),                 -- 銘柄単位元本減債金額
			ITEM024 = CASE WHEN ITEM024='0' THEN  ' '  ELSE ITEM024 END , -- 券種コード
			ITEM025 = CASE WHEN ITEM025='0' THEN  ' '  ELSE ITEM025 END , -- 記番号FROM
			ITEM026 = CASE WHEN ITEM026='0' THEN  ' '  ELSE ITEM026 END , -- 記番号TO
			ITEM028 = coalesce(ITEM028, ' ')                  -- 利金金額
		WHERE
			KEY_CD = l_inItakuKaishaCd
			AND USER_ID = l_inUserId
			AND CHOHYO_KBN = l_inChohyoKbn
			AND SAKUSEI_YMD = l_inGyomuYmd
			AND CHOHYO_ID = C_CHOHYO_GENBO_ID
			AND SEQ_NO BETWEEN gSeqStart AND gSeqEnd;
		-- ヘッダレコードを追加
		CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, C_CHOHYO_GENBO_ID);
		-- バッチの時
		IF l_inChohyoKbn = '1' THEN
			-- 原簿送付状出力フラグ='1'の時
			IF gGenboSofuFlg = '1' THEN
				-- 帳票ＩＤセット（送付）
				gChohyoId := C_CHOHYO_SOUFU_ID;
			ELSE
				-- 帳票ＩＤセット（原簿）
				gChohyoId := C_CHOHYO_GENBO_ID;
			END IF;
--			pkLog.debug(l_inUserId, C_PROGRAM_ID, '原簿送付状出力フラグ:"' || gGenboSofuFlg || '"');
--			pkLog.debug(l_inUserId, C_PROGRAM_ID, '帳票ＩＤ:"' || gChohyoId || '"');
			-- バッチ帳票印刷データ作成
			CALL pkPrtOk.insertPrtOk(
								l_inUserId,
								l_inItakuKaishaCd,
								l_inGyomuYmd,
								pkPrtOk.LIST_SAKUSEI_KBN_MONTH(),
								gChohyoId
								);
--		ELSE
--			pkLog.debug(l_inUserId, C_PROGRAM_ID, 'リアルの為、バッチ帳票印刷データ作成しない');
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
-- REVOKE ALL ON PROCEDURE spipp002k00r01_02 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE, l_inGyomuYmd SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE, l_inUserId SREPORT_WK.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_inTsuchiYmd text, l_outSqlCode OUT integer, l_outSqlErrM OUT text ) FROM PUBLIC;