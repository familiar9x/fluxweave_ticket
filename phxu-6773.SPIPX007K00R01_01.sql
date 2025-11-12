




CREATE OR REPLACE PROCEDURE spipx007k00r01_01 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE,     -- 委託会社コード
 l_inUserId SREPORT_WK.USER_ID%TYPE,    -- ユーザーID
 l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, -- 帳票区分
 l_inKessaiYmdF KIKIN_IDO.IDO_YMD%TYPE,     -- 決済年月日FROM
 l_inKessaiYmdT KIKIN_IDO.IDO_YMD%TYPE,     -- 決済年月日TO
 l_outSqlCode OUT integer,                     -- リターン値
 l_outSqlErrM OUT text                    -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2006
-- * 会社名:JIP
-- *
-- * 概要　:資金決済関連帳票の出力指示出力指示画面より、印刷条件の指定を受けて、元利金支払基金引落一覧表を作成する
-- *
-- * 引数　:l_inItakuKaishaCd :委託会社コード
-- *        l_inUserId        :ユーザーID
-- *        l_inChohyoKbn     :帳票区分
-- *        l_inKessaiYmdF    :決済年月日FROM
-- *        l_inKessaiYmdT    :決済年月日TO
-- *        l_outSqlCode      :リターン値
-- *        l_outSqlErrM      :エラーコメント
-- *
-- * 返り値: なし
-- *
-- * @author ASK
-- * @version $Id: SPIPX007K00R01_01.sql,v 1.3 2007/05/22 11:41:58 yamaki Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2006.12.12 ASK         新規作成
-- ***************************************************************************
--
	--==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_PROCEDURE_ID CONSTANT varchar(50) := 'SPIPX007K00R01_01';         -- プロシージャＩＤ
	C_CHOHYO_ID    CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IPX30000711';  -- 帳票ＩＤ
	C_FORMAT_14    CONSTANT varchar(18) := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';        -- フォーマット14桁
	C_FORMAT_14_2  CONSTANT varchar(21) := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';     -- フォーマット14_2桁
	C_FORMAT_16    CONSTANT varchar(21) := 'Z,ZZZ,ZZZ,ZZZ,ZZZ,ZZ9';     -- フォーマット16桁
	C_FORMAT_16_2  CONSTANT varchar(24) := 'Z,ZZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';  -- フォーマット16_2桁
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	gSeqNo                    numeric;                                   -- シーケンス
	gGyomuYmd                 SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;         -- 業務日付
	gItakuKaishaRnm           SOWN_INFO.BANK_RNM%TYPE;                   -- 委託会社略名
	gFm14                     varchar(21);                              -- フォーマット14
	gFm16                     varchar(24);                              -- フォーマット16
	v_item                    TYPE_SREPORT_WK_ITEM;                      -- Composite type for insertData
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	curMeisai CURSOR FOR
		SELECT
			T.*,
			(
				SELECT
					SC04.CODE_NM
				FROM
					SCODE SC04
				WHERE
					SC04.CODE_SHUBETSU = '707'
					AND SC04.CODE_VALUE = T.KOZA_KAMOKU
			) AS KOZA_KAMOKU_NM  -- 口座科目名称
		FROM (
			SELECT
				WT01.MGR_CD,                                  -- 銘柄コード
				WT01.RBR_KJT,                                 -- 元利払期日
				WT01.IDO_YMD,                                 -- 異動年月日
				WT01.KKN_IDO_KBN,                             -- 基金異動区分
				WT01.KOZA_FURI_KBN,                           -- 口座振替区分
				WT01.TSUKA_CD,                                -- 通貨コード
				WT01.ISIN_CD,                                 -- ＩＳＩＮコード
				WT01.MGR_RNM,                                 -- 銘柄略称
				WT01.RBR_YMD,                                 -- 元利払日
				WT01.TEKIYOU_SORT,                            -- 摘要ソート
				WT01.TEKIYOU1,                                -- 摘要１
				WT01.TEKIYOU2,                                -- 摘要２
				SUM(WT01.KKN_NYUKIN_KNGK) AS KKN_NYUKIN_KNGK, -- 基金入金額
				WT01.HKT_CD,                                  -- 発行体コード
				WT01.KOZA_TEN_CD,                             -- 口座店コード
				WT01.KOZA_TEN_CIFCD,                          -- 口座店ＣＩＦコード
				WT01.HKT_RNM,                                 -- 発行体略称
				CASE WHEN 					WT01.KOZA_FURI_KBN='10' THEN  WT01.KOZA_TEN_CD  ELSE S06.KOZA_TEN_CD END  AS KOZA_TEN_CD1,                            -- 口座店コード1
				CASE WHEN 					WT01.KOZA_FURI_KBN='10' THEN  WT01.HKO_KAMOKU_CD  ELSE S06.KOZA_KAMOKU END  AS KOZA_KAMOKU,                             -- 口座科目
				CASE WHEN 					WT01.KOZA_FURI_KBN='10' THEN WT01.HKO_KOZA_NO  ELSE S06.KOZA_NO END  AS KOZA_NO,                                 -- 口座番号
				S06.KOZA_FURI_KBN_NM,                         -- 口座振替区分名称
				M64.TSUKA_NM                                   -- 通貨出力用名称
			FROM mtsuka m64, (
				SELECT  -- 元金・利金===============================================
					K02.ITAKU_KAISHA_CD, -- 委託会社コード
					K02.MGR_CD,          -- 銘柄コード
					VMG1.ISIN_CD,        -- ISINコード
					VMG1.MGR_RNM,        -- 銘柄略称
					VMG1.KOZA_FURI_KBN,  -- 口座振替区分
					K02.IDO_YMD,         -- 異動年月日
					K02.KKN_IDO_KBN,     -- 基金異動区分
					K02.TSUKA_CD,        -- 通貨コード
					K02.RBR_YMD,         -- 元利払日
					K02.RBR_KJT,         -- 元利払期日
					K02.KKN_NYUKIN_KNGK, -- 基金入金額
					CASE WHEN 						K02.KKN_IDO_KBN='11' THEN  '1' WHEN 						K02.KKN_IDO_KBN='21' THEN  '3'					 END  AS TEKIYOU_SORT,   -- 摘要ソート
					CASE WHEN 						K02.KKN_IDO_KBN='11' THEN  '公社債元金' WHEN 						K02.KKN_IDO_KBN='21' THEN  '公社債利金'					 END  AS TEKIYOU1,       -- 摘要１
					CASE WHEN 						K02.KKN_IDO_KBN='11' THEN  'コウシヤサイガンキン' WHEN 						K02.KKN_IDO_KBN='21' THEN  'コウシヤサイリキン'					 END  AS TEKIYOU2,       -- 摘要２
					K02.ZNDK_KIJUN_YMD,  -- 残高基準年月日
					M01.HKT_CD,          -- 発行体コード
					M01.KOZA_TEN_CD,     -- 口座店コード
					M01.KOZA_TEN_CIFCD,  -- 口座店ＣＩＦコード
					M01.HKO_KOZA_NO,     -- 発行体口座番号
					M01.HKO_KAMOKU_CD,   -- 発行体科目コード
					M01.HKT_RNM           -- 発行体略称
				FROM
					KIKIN_IDO K02,
					MGR_KIHON_VIEW VMG1,
					MHAKKOTAI M01
				WHERE
					K02.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
					AND K02.MGR_CD = VMG1.MGR_CD
					AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
					AND VMG1.HKT_CD = M01.HKT_CD
					AND K02.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
					AND K02.IDO_YMD BETWEEN l_inKessaiYmdF AND l_inKessaiYmdT
					AND K02.KKN_IDO_KBN IN ('11', '21')
					AND VMG1.MGR_STAT_KBN = '1'
					AND VMG1.JTK_KBN NOT IN ('2', '5')
					AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
				
UNION ALL

				SELECT  -- 元金支払手数料===========================================
					K02.ITAKU_KAISHA_CD,                        -- 委託会社コード
					K02.MGR_CD,                                 -- 銘柄コード
					VMG1.ISIN_CD,                               -- ISINコード
					VMG1.MGR_RNM,                               -- 銘柄略称
					MG7.KOZA_FURI_KBN,                          -- 口座振替区分
					K02.IDO_YMD,                                -- 異動年月日
					'12' AS KKN_IDO_KBN,                        -- 基金異動区分
					K02.TSUKA_CD,                               -- 通貨コード
					K02.RBR_YMD,                                -- 元利払日
					K02.RBR_KJT,                                -- 元利払期日
					K02.KKN_NYUKIN_KNGK,                        -- 基金入金額
					'2' AS TEKIYOU_SORT,                        -- 摘要ソート
					'公社債元金手数料' AS TEKIYOU1,             -- 摘要１
					'コウシヤサイガンキンテスウリヨウ' AS TEKIYOU2, -- 摘要２
					K02.ZNDK_KIJUN_YMD,                         -- 残高基準年月日
					M01.HKT_CD,                                 -- 発行体コード
					M01.KOZA_TEN_CD,                            -- 口座店コード
					M01.KOZA_TEN_CIFCD,                         -- 口座店ＣＩＦコード
					M01.HKO_KOZA_NO,                            -- 発行体口座番号
					M01.HKO_KAMOKU_CD,                          -- 発行体科目コード
					M01.HKT_RNM                                  -- 発行体略称
				FROM
					KIKIN_IDO K02,
					MGR_TESURYO_CTL MG7,
					MGR_KIHON_VIEW VMG1,
					MHAKKOTAI M01
				WHERE
					K02.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD
					AND K02.MGR_CD = MG7.MGR_CD
					AND K02.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
					AND K02.MGR_CD = VMG1.MGR_CD
					AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
					AND VMG1.HKT_CD = M01.HKT_CD
					AND K02.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
					AND K02.IDO_YMD BETWEEN l_inKessaiYmdF AND l_inKessaiYmdT
					AND K02.KKN_IDO_KBN IN ('12', '13')
					AND MG7.TESU_SHURUI_CD = '81'
					AND VMG1.MGR_STAT_KBN = '1'
					AND VMG1.JTK_KBN NOT IN ('2', '5')
					AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '') 
				
UNION ALL

				SELECT  -- 利金支払手数料===========================================
					K02.ITAKU_KAISHA_CD,                      -- 委託会社コード
					K02.MGR_CD,                               -- 銘柄コード
					VMG1.ISIN_CD,                             -- ISINコード
					VMG1.MGR_RNM,                             -- 銘柄略称
					MG7.KOZA_FURI_KBN,                        -- 口座振替区分
					K02.IDO_YMD,                              -- 異動年月日
					'22' AS KKN_IDO_KBN,                      -- 基金異動区分
					K02.TSUKA_CD,                             -- 通貨コード
					K02.RBR_YMD,                              -- 元利払日
					K02.RBR_KJT,                              -- 元利払期日
					K02.KKN_NYUKIN_KNGK,                      -- 基金入金額
					'4' AS TEKIYOU_SORT,                      -- 摘要ソート
					'公社債利金手数料' AS TEKIYOU1,           -- 摘要１
					'コウシヤサイリキンテスウリヨウ' AS TEKIYOU2, -- 摘要２
					K02.ZNDK_KIJUN_YMD,                       -- 残高基準年月日
					M01.HKT_CD,                               -- 発行体コード
					M01.KOZA_TEN_CD,                          -- 口座店コード
					M01.KOZA_TEN_CIFCD,                       -- 口座店ＣＩＦコード
					M01.HKO_KOZA_NO,                          -- 発行体口座番号
					M01.HKO_KAMOKU_CD,                        -- 発行体科目コード
					M01.HKT_RNM                                -- 発行体略称
				FROM
					KIKIN_IDO K02,
					MGR_TESURYO_CTL MG7,
					MGR_KIHON_VIEW VMG1,
					MHAKKOTAI M01
				WHERE
					K02.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD
					AND K02.MGR_CD = MG7.MGR_CD
					AND K02.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
					AND K02.MGR_CD = VMG1.MGR_CD
					AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
					AND VMG1.HKT_CD = M01.HKT_CD
					AND K02.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
					AND K02.IDO_YMD BETWEEN l_inKessaiYmdF AND l_inKessaiYmdT
					AND K02.KKN_IDO_KBN IN ('22', '23')
					AND MG7.TESU_SHURUI_CD IN ('61', '82')
					AND MG7.CHOOSE_FLG = '1'
					AND VMG1.MGR_STAT_KBN = '1'
					AND VMG1.JTK_KBN NOT IN ('2', '5')
					AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '') 
				) wt01
LEFT OUTER JOIN koza_frk s06 ON (WT01.ITAKU_KAISHA_CD = S06.ITAKU_KAISHA_CD AND WT01.KOZA_FURI_KBN = S06.KOZA_FURI_KBN)
WHERE WT01.TSUKA_CD = M64.TSUKA_CD AND PKIPACALCTESURYO.checkHeizonMgr(WT01.ITAKU_KAISHA_CD , WT01.MGR_CD , WT01.ZNDK_KIJUN_YMD , '1') = 0  GROUP BY
				WT01.MGR_CD,
				WT01.RBR_KJT,
				WT01.IDO_YMD,
				WT01.KKN_IDO_KBN,
				WT01.KOZA_FURI_KBN,
				WT01.TSUKA_CD,
				WT01.ISIN_CD,
				WT01.MGR_RNM,
				WT01.RBR_YMD,
				WT01.TEKIYOU_SORT,
				WT01.TEKIYOU1,
				WT01.TEKIYOU2,
				WT01.HKT_CD,
				WT01.KOZA_TEN_CD,
				WT01.KOZA_TEN_CIFCD,
				WT01.HKT_RNM,
				CASE WHEN 					WT01.KOZA_FURI_KBN='10' THEN  WT01.KOZA_TEN_CD  ELSE S06.KOZA_TEN_CD END ,
				CASE WHEN 					WT01.KOZA_FURI_KBN='10' THEN  WT01.HKO_KAMOKU_CD  ELSE S06.KOZA_KAMOKU END ,
				CASE WHEN 					WT01.KOZA_FURI_KBN='10' THEN  WT01.HKO_KOZA_NO  ELSE S06.KOZA_NO END ,
				S06.KOZA_FURI_KBN_NM,
				M64.TSUKA_NM
		) T 
	ORDER BY
		T.TSUKA_CD,
		T.IDO_YMD,
		T.KOZA_FURI_KBN,
		T.KOZA_TEN_CD1,
		T.KOZA_KAMOKU,
		T.KOZA_NO,
		T.ISIN_CD,
		T.RBR_YMD,
		T.TEKIYOU_SORT;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, C_PROCEDURE_ID||' START');
	-- 入力パラメータチェック
	IF coalesce(l_inItakuKaishaCd::text, '') = ''     -- 委託会社コード
	OR coalesce(l_inUserId::text, '') = ''            -- ユーザーID
	OR coalesce(l_inChohyoKbn::text, '') = ''         -- 帳票区分
	OR coalesce(l_inKessaiYmdF::text, '') = ''        -- 決済年月開始
	OR coalesce(l_inKessaiYmdT::text, '') = '' THEN    -- 決済年月終了
		-- ログ書込み
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID,3,12), 'パラメータエラー');
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := '';
		RETURN;
	END IF;
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '引数');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '委託会社コード:"' || l_inItakuKaishaCd ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'ユーザーＩＤ:"' || l_inUserId ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票区分:"' || l_inChohyoKbn ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '決済年月開始:"' || l_inKessaiYmdF ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '決済年月終了:"' || l_inKessaiYmdF ||'"');
--
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
	-- シーケンス初期化
	gSeqNo := 1;
	-- 委託会社略名取得
	SELECT
		CASE WHEN JIKO_DAIKO_KBN='2' THEN BANK_RNM  ELSE ' ' END
		INTO STRICT gItakuKaishaRnm
	FROM
		VJIKO_ITAKU
	WHERE
		KAIIN_ID = l_inItakuKaishaCd;
	-- 帳票ワークテーブル削除処理
	DELETE FROM SREPORT_WK
		WHERE KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = gGyomuYmd
		AND CHOHYO_ID = C_CHOHYO_ID;
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '削除条件');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '識別コード:"' || l_inItakuKaishaCd ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'ユーザーＩＤ:"' || l_inUserId ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票区分:"' || l_inChohyoKbn ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '作成日付:"' || gGyomuYmd ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票ＩＤ:"' || C_CHOHYO_ID ||'"');
--
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, gGyomuYmd, C_CHOHYO_ID);
	-- データ取得
	FOR recMeisai IN curMeisai
	LOOP
		-- 通貨フォーマット設定
		IF recMeisai.TSUKA_CD = 'JPY' THEN
			gFm14 := C_FORMAT_14;   -- フォーマット14
			gFm16 := C_FORMAT_16;   -- フォーマット16
		ELSE
			gFm14 := C_FORMAT_14_2; -- フォーマット14
			gFm16 := C_FORMAT_16_2; -- フォーマット16
		END IF;
		-- 明細レコード追加
				v_item := ROW(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL)::TYPE_SREPORT_WK_ITEM;
		v_item.l_inItem001 := gItakuKaishaRnm;
		v_item.l_inItem002 := recMeisai.IDO_YMD;
		v_item.l_inItem003 := recMeisai.KOZA_FURI_KBN;
		v_item.l_inItem004 := recMeisai.KOZA_FURI_KBN_NM;
		v_item.l_inItem005 := recMeisai.TSUKA_CD;
		v_item.l_inItem006 := recMeisai.TSUKA_NM;
		v_item.l_inItem007 := recMeisai.HKT_CD;
		v_item.l_inItem008 := recMeisai.KOZA_TEN_CD;
		v_item.l_inItem009 := recMeisai.KOZA_TEN_CIFCD;
		v_item.l_inItem010 := recMeisai.HKT_RNM;
		v_item.l_inItem011 := recMeisai.ISIN_CD;
		v_item.l_inItem012 := recMeisai.MGR_CD;
		v_item.l_inItem013 := recMeisai.MGR_RNM;
		v_item.l_inItem014 := recMeisai.KKN_IDO_KBN;
		v_item.l_inItem015 := recMeisai.RBR_YMD;
		v_item.l_inItem016 := recMeisai.RBR_KJT;
		v_item.l_inItem017 := recMeisai.KOZA_TEN_CD1;
		v_item.l_inItem018 := recMeisai.KOZA_KAMOKU_NM;
		v_item.l_inItem019 := recMeisai.KOZA_NO;
		v_item.l_inItem020 := recMeisai.KKN_NYUKIN_KNGK;
		v_item.l_inItem021 := recMeisai.TEKIYOU1;
		v_item.l_inItem022 := recMeisai.TEKIYOU2;
		v_item.l_inItem023 := gFm14;
		v_item.l_inItem024 := gFm16;
		v_item.l_inItem025 := C_CHOHYO_ID;
		v_item.l_inItem026 := l_inUserId;

CALL pkPrint.insertData(			l_inKeyCd      => l_inItakuKaishaCd,                                       -- 識別コード
			l_inUserId     => l_inUserId,                                              -- ユーザＩＤ
			l_inChohyoKbn  => l_inChohyoKbn,                                           -- 帳票区分
			l_inSakuseiYmd => gGyomuYmd,                                               -- 業務日付
			l_inChohyoId   => C_CHOHYO_ID,                                             -- 帳票ＩＤ
			l_inSeqNo      => gSeqNo::bigint,                                                  -- 連番
			l_inHeaderFlg  => '1',                                                     -- ヘッダフラグ
			l_inItem       => v_item,
			l_inKousinId   => l_inUserId,                                              -- 更新者
			l_inSakuseiId  => l_inUserId                                                -- 作成者
		);
		-- シーケンスのカウント
		gSeqNo := gSeqNo + 1;
	END LOOP;
	IF gSeqNo = 1 THEN
		-- 明細レコード追加（対象データなし）
				v_item := ROW(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL)::TYPE_SREPORT_WK_ITEM;
		v_item.l_inItem001 := gItakuKaishaRnm;
		v_item.l_inItem025 := C_CHOHYO_ID;
		v_item.l_inItem026 := l_inUserId;
		v_item.l_inItem027 := '対象データなし';

CALL pkPrint.insertData(			l_inKeyCd      => l_inItakuKaishaCd, -- 識別コード
			l_inUserId     => l_inUserId,        -- ユーザＩＤ
			l_inChohyoKbn  => l_inChohyoKbn,     -- 帳票区分
			l_inSakuseiYmd => gGyomuYmd,         -- 業務日付
			l_inChohyoId   => C_CHOHYO_ID,       -- 帳票ＩＤ
			l_inSeqNo      => gSeqNo::bigint,            -- 連番
			l_inHeaderFlg  => '1',               -- ヘッダフラグ
			l_inItem       => v_item,
			l_inKousinId   => l_inUserId,        -- 更新者
			l_inSakuseiId  => l_inUserId          -- 作成者
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
-- REVOKE ALL ON PROCEDURE spipx007k00r01_01 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE, l_inUserId SREPORT_WK.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_inKessaiYmdF KIKIN_IDO.IDO_YMD%TYPE, l_inKessaiYmdT KIKIN_IDO.IDO_YMD%TYPE, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;