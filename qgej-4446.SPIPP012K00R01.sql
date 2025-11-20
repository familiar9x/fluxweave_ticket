




CREATE OR REPLACE PROCEDURE spipp012k00r01 ( 
	l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE,     -- 委託会社コード
 l_inUserId SREPORT_WK.USER_ID%TYPE,    -- ユーザーＩＤ
 l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, -- 帳票区分
 l_inMgrCd KBG_SHOKBG.MGR_CD%TYPE,     -- 銘柄コード
 l_inIsinCd MGR_KIHON.ISIN_CD%TYPE,     -- ＩＳＩＮコード
 l_outSqlCode OUT integer,                    -- リターン値
 l_outSqlErrM OUT text                    -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2007
-- * 会社名:JIP
-- *
-- * 概要　:実質記番号償還情報突合リスト
-- *
-- * 引数　:l_inItakuKaishaCd :委託会社コード
-- *        l_inUserId        :ユーザーＩＤ
-- *        l_inChohyoKbn     :帳票区分
-- *        l_inMgrCd         :銘柄コード
-- *        l_inIsinCd        :ＩＳＩＮコード
-- *        l_outSqlCode      :リターン値
-- *        l_outSqlErrM      :エラーコメント
-- *
-- * 返り値: なし
-- *
-- * @author ASK
-- * @version $Id: SPIPP012K00R01.sql,v 1.2 2007/08/01 04:53:10 nishimura Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2007.06.13 中村        新規作成
-- ***************************************************************************
--	/*==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_PROGRAM_ID CONSTANT varchar(50)              := 'SPIPP012K00R01'; -- プログラムＩＤ
	C_CHOHYO_ID  CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IPP30001211';    -- 帳票ＩＤ
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gSeqNo          numeric;                            -- シーケンス
	gGyomuYmd       SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE; -- 業務日付
	gItakuKaishaRnm SOWN_INFO.BANK_RNM%TYPE;           -- 委託会社略名
	gMgrFlg         MPROCESS_CTL.CTL_VALUE%TYPE;       -- 銘柄名称制御フラグ取得('0'：略称 '1'：正式)
	gProMgrNm       MGR_KIHON.MGR_NM%TYPE;             -- 銘柄名称（正式 OR 略称）（編集用）
	gMgrCd          KBG_SHOKBG.MGR_CD%TYPE;            -- 銘柄コード（ブレイク確認用）
	gKaijiKngk      numeric;                            -- 元本減債金額（償還回次）
	gKibangoKngk    numeric;                            -- 元本減債金額（記番号情報）
	gMatchNm        varchar(16);                      -- 突合結果
	-- 券種情報 (converted from Oracle TABLE to PostgreSQL arrays)
	gKenshuCd       numeric[];                          -- 券種コード
	gKibangoMaisu   numeric[];                          -- 枚数（記番号）
	gKenshuMaisu    numeric[];                          -- 枚数（券種）
	gKMatchNm       varchar[];                          -- 突合結果（券種）
	gKCnt           numeric;                            -- カウント（券種用）
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	-- 明細データ
	curMeisai CURSOR FOR
		SELECT
			T_A.MGR_CD,                               -- 銘柄コード
			coalesce(T_B.KAIJI_FLG, '0') AS KAIJI_FLG,     -- 償還回次存在フラグ（'0'：存在しない '1'：存在する）
			coalesce(T_B.KIBANGO_FLG, '0') AS KIBANGO_FLG, -- 記番号情報存在フラグ（'0'：存在しない '1'：存在する）
			T_B.SHOKAN_KJT,                           -- 償還期日
			T_B.KBG_SHOKAN_KBN,                       -- 償還区分（実質記番号用）
			T_B.KAIJI_KNGK,                           -- 元本減債金額（償還回次）
			T_B.KIBANGO_KNGK,                         -- 元本減債金額（記番号情報）
			pkIpaKibango.getFurikaeSogaku(
				T_A.ITAKU_KAISHA_CD,
				T_A.MGR_CD,
				gGyomuYmd
			) AS FURIKAESOGAKU,                       -- 振替金額
			MG1.ISIN_CD,                              -- ＩＳＩＮコード
			MG1.MGR_NM,                               -- 銘柄の正式名称
			MG1.MGR_RNM,                              -- 銘柄略称
			(
				SELECT
					CODE_NM
				FROM
					SCODE
				WHERE
					CODE_SHUBETSU = '226'
					AND CODE_VALUE = T_B.KBG_SHOKAN_KBN
			) AS KBG_SHOKAN_KBN_NM                     -- 償還区分名称
		FROM mgr_kihon mg1, (
				SELECT
					ITAKU_KAISHA_CD,
					MGR_CD
				FROM
					KBG_SHOKIJ
				WHERE
					ITAKU_KAISHA_CD = l_inItakuKaishaCd
					AND (coalesce(trim(both l_inMgrCd)::text, '') = '' OR MGR_CD = l_inMgrCd)
				
UNION

				SELECT
					ITAKU_KAISHA_CD,
					MGR_CD
				FROM
					KBG_SHOKBG
				WHERE
					ITAKU_KAISHA_CD = l_inItakuKaishaCd
					AND (coalesce(trim(both l_inMgrCd)::text, '') = '' OR MGR_CD = l_inMgrCd) 
				
UNION

				SELECT
					ITAKU_KAISHA_CD,
					MGR_CD
				FROM
					KBG_KENSHU
				WHERE
					ITAKU_KAISHA_CD = l_inItakuKaishaCd
					AND (coalesce(trim(both l_inMgrCd)::text, '') = '' OR MGR_CD = l_inMgrCd) 
			) t_a
LEFT OUTER JOIN (
				SELECT  -- 「実質記番号管理償還回次」がメイン、「実質記番号管理償還記番号情報」外部結合
					P01.ITAKU_KAISHA_CD,                 -- 委託会社コード
					'1' AS KAIJI_FLG,                    -- 償還回次存在フラグ（'0'：存在しない '1'：存在する）
					CASE WHEN 						coalesce(P02.ITAKU_KAISHA_CD::text, '') = '' THEN  '0'  ELSE '1' END  AS KIBANGO_FLG,                    -- 記番号情報存在フラグ（'0'：存在しない '1'：存在する）
					P01.MGR_CD,                          -- 銘柄コード
					P01.SHOKAN_KJT,                      -- 償還期日
					P01.KBG_SHOKAN_KBN,                  -- 償還区分（実質記番号用）
					P01.MUNIT_GENSAI_KNGK AS KAIJI_KNGK, -- 元本減債金額（償還回次）
					P02.FURI_GENSAI_KNGK AS KIBANGO_KNGK  -- 元本減債金額（記番号情報）
				FROM kbg_shokij p01
LEFT OUTER JOIN (
						SELECT
							ITAKU_KAISHA_CD,                          -- 委託会社コード
							MGR_CD,                                   -- 銘柄コード
							SHOKAN_KJT,                               -- 償還期日
							KBG_SHOKAN_KBN,                           -- 償還区分（実質記番号用）
							SUM(FURI_GENSAI_KNGK) AS FURI_GENSAI_KNGK  -- 振替債減債金額
						FROM
							KBG_SHOKBG
						WHERE
							ITAKU_KAISHA_CD = l_inItakuKaishaCd
							AND (coalesce(trim(both l_inMgrCd)::text, '') = '' OR MGR_CD = l_inMgrCd) 
						GROUP BY
							ITAKU_KAISHA_CD,
							MGR_CD,
							SHOKAN_KJT,
							KBG_SHOKAN_KBN
					) p02 ON (P01.ITAKU_KAISHA_CD = P02.ITAKU_KAISHA_CD AND P01.MGR_CD = P02.MGR_CD AND P01.SHOKAN_KJT = P02.SHOKAN_KJT AND P01.KBG_SHOKAN_KBN = P02.KBG_SHOKAN_KBN)
WHERE P01.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND (coalesce(trim(both l_inMgrCd)::text, '') = '' OR P01.MGR_CD = l_inMgrCd) 
				 
UNION

				SELECT  -- 「実質記番号管理償還記番号情報」がメイン、「実質記番号管理償還回次」外部結合
					P02.ITAKU_KAISHA_CD,                 -- 委託会社コード
					CASE WHEN 						coalesce(P01.ITAKU_KAISHA_CD::text, '') = '' THEN  '0'  ELSE '1' END  AS KAIJI_FLG,                      -- 償還回次存在フラグ（'0'：存在しない '1'：存在する）
					'1' AS KIBANGO_FLG,                  -- 記番号情報存在フラグ（'0'：存在しない '1'：存在する）
					P02.MGR_CD,                          -- 銘柄コード
					P02.SHOKAN_KJT,                      -- 償還期日
					P02.KBG_SHOKAN_KBN,                  -- 償還区分（実質記番号用）
					P01.MUNIT_GENSAI_KNGK AS KAIJI_KNGK, -- 元本減債金額（償還回次）
					P02.FURI_GENSAI_KNGK AS KIBANGO_KNGK  -- 元本減債金額（記番号情報）
				FROM (
						SELECT
							ITAKU_KAISHA_CD,                          -- 委託会社コード
							MGR_CD,                                   -- 銘柄コード
							SHOKAN_KJT,                               -- 償還期日
							KBG_SHOKAN_KBN,                           -- 償還区分（実質記番号用）
							SUM(FURI_GENSAI_KNGK) AS FURI_GENSAI_KNGK  -- 振替債減債金額
						FROM
							KBG_SHOKBG
						WHERE
							ITAKU_KAISHA_CD = l_inItakuKaishaCd
							AND (coalesce(trim(both l_inMgrCd)::text, '') = '' OR MGR_CD = l_inMgrCd) 
						GROUP BY
							ITAKU_KAISHA_CD,
							MGR_CD,
							SHOKAN_KJT,
							KBG_SHOKAN_KBN
					) p02
LEFT OUTER JOIN kbg_shokij p01 ON (P02.ITAKU_KAISHA_CD = P01.ITAKU_KAISHA_CD AND P02.MGR_CD = P01.MGR_CD AND P02.SHOKAN_KJT = P01.SHOKAN_KJT AND P02.KBG_SHOKAN_KBN = P01.KBG_SHOKAN_KBN)  ) t_b ON (T_A.ITAKU_KAISHA_CD = T_B.ITAKU_KAISHA_CD AND T_A.MGR_CD = T_B.MGR_CD)
WHERE T_A.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD AND T_A.MGR_CD = MG1.MGR_CD AND (coalesce(trim(both l_inIsinCd)::text, '') = '' OR MG1.ISIN_CD = l_inIsinCd) ORDER BY
			T_A.MGR_CD,
			coalesce(trim(both T_B.SHOKAN_KJT), '99999999'), -- 期日が空の時、最後尾に来るように制御
			T_B.KBG_SHOKAN_KBN;
	-- 券種情報
	curKenshu CURSOR(
		l_inDataMgrCd KBG_SHOKBG.MGR_CD%TYPE  -- 銘柄コード
	) FOR
		SELECT  -- TOP5絞込
			TT.KIBANGO_FLG,   -- 記番号情報存在フラグ（'0'：存在しない '1'：存在する）
			TT.KENSHU_FLG,    -- 券種情報存在フラグ（'0'：存在しない '1'：存在する）
			TT.MGR_CD,        -- 銘柄コード
			TT.KENSHU_CD,     -- 券種コード
			TT.KIBANGO_MAISU, -- 枚数（記番号）
			TT.KENSHU_MAISU    -- 枚数（券種）
		FROM
			(
				SELECT
					T.KIBANGO_FLG,   -- 記番号情報存在フラグ（'0'：存在しない '1'：存在する）
					T.KENSHU_FLG,    -- 券種情報存在フラグ（'0'：存在しない '1'：存在する）
					T.MGR_CD,        -- 銘柄コード
					T.KENSHU_CD,     -- 券種コード
					T.KIBANGO_MAISU, -- 枚数（記番号）
					T.KENSHU_MAISU    -- 枚数（券種）
				FROM
					(
						SELECT  -- 「実質記番号管理償還記番号情報」がメイン、「実質記番号管理券種情報」外部結合
							'1' AS KIBANGO_FLG,         -- 記番号情報存在フラグ（'0'：存在しない '1'：存在する）
							CASE WHEN 								coalesce(P03.ITAKU_KAISHA_CD::text, '') = '' THEN  '0'  ELSE '1' END  AS KENSHU_FLG,            -- 券種情報存在フラグ（'0'：存在しない '1'：存在する）
							P02.MGR_CD,                 -- 銘柄コード
							P02.KENSHU_CD,              -- 券種コード
							P02.MAISU AS KIBANGO_MAISU, -- 枚数（記番号）
							P03.MAISU AS KENSHU_MAISU    -- 枚数（券種）
						FROM (
								SELECT
									ITAKU_KAISHA_CD,                            -- 委託会社コード
									MGR_CD,                                     -- 銘柄コード
									KENSHU_CD,                                  -- 券種コード
									SUM(KIBANGO_TO - KIBANGO_FROM + 1) AS MAISU  -- 枚数
								FROM
									KBG_SHOKBG
								WHERE
									ITAKU_KAISHA_CD = l_inItakuKaishaCd
									AND MGR_CD = l_inDataMgrCd
								GROUP BY
									ITAKU_KAISHA_CD,
									MGR_CD,
									KENSHU_CD
							) p02
LEFT OUTER JOIN kbg_kenshu p03 ON (P02.ITAKU_KAISHA_CD = P03.ITAKU_KAISHA_CD AND P02.MGR_CD = P03.MGR_CD AND P02.KENSHU_CD = P03.KENSHU_CD)
UNION

						SELECT  -- 「実質記番号管理券種情報」がメイン、「実質記番号管理償還記番号情報」外部結合
							CASE WHEN 								coalesce(P02.ITAKU_KAISHA_CD::text, '') = '' THEN  '0'  ELSE '1' END  AS KIBANGO_FLG,           -- 記番号情報存在フラグ（'0'：存在しない '1'：存在する）
							'1' AS KENSHU_FLG,          -- 券種情報存在フラグ（'0'：存在しない '1'：存在する）
							P03.MGR_CD,                 -- 銘柄コード
							P03.KENSHU_CD,              -- 券種コード
							P02.MAISU AS KIBANGO_MAISU, -- 枚数（記番号）
							P03.MAISU AS KENSHU_MAISU    -- 枚数（券種）
						FROM kbg_kenshu p03
LEFT OUTER JOIN (
								SELECT
									ITAKU_KAISHA_CD,                            -- 委託会社コード
									MGR_CD,                                     -- 銘柄コード
									KENSHU_CD,                                  -- 券種コード
									SUM(KIBANGO_TO - KIBANGO_FROM + 1) AS MAISU  -- 枚数
								FROM
									KBG_SHOKBG
								WHERE
									ITAKU_KAISHA_CD = l_inItakuKaishaCd
									AND MGR_CD = l_inDataMgrCd
								GROUP BY
									ITAKU_KAISHA_CD,
									MGR_CD,
									KENSHU_CD
							) p02 ON (P03.ITAKU_KAISHA_CD = P02.ITAKU_KAISHA_CD AND P03.MGR_CD = P02.MGR_CD AND P03.KENSHU_CD = P02.KENSHU_CD) 
WHERE P03.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND P03.MGR_CD = l_inDataMgrCd
					 ) T 
				ORDER BY
					T.KENSHU_CD
			) TT LIMIT 5;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 入力パラメータチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inUserId)::text, '') = ''
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = '' THEN
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := 'パラメータエラー';
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, l_outSqlErrM);
		RETURN;
	END IF;
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '引数');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '委託会社コード:"' || l_inItakuKaishaCd || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, 'ユーザーＩＤ:"' || l_inUserId || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '帳票区分:"' || l_inChohyoKbn || '"');
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '業務日付:"' || gGyomuYmd || '"');
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
	gSeqNo := 1;
	gMgrCd := ' ';
	-- データ読込
	FOR recMeisai IN curMeisai LOOP
		-- 銘柄コードがブレイクした時（初回含む）
		IF gMgrCd != recMeisai.MGR_CD THEN
			-- 変数初期化
			FOR gKCnt IN 1..5 LOOP
				gKenshuCd[gKCnt]     := NULL; -- 券種コード
				gKibangoMaisu[gKCnt] := NULL; -- 枚数（記番号）
				gKenshuMaisu[gKCnt]  := NULL; -- 枚数（券種）
				gKMatchNm[gKCnt]     := NULL; -- 突合結果（券種）
			END LOOP;
			-- カウント（券種用）
			gKCnt := 1;
			-- 券種突合情報
			FOR recKenshu IN curKenshu(recMeisai.MGR_CD)
			LOOP
				-- 券種コード
				gKenshuCd[gKCnt] := recKenshu.KENSHU_CD / 1000;
				-- 記番号情報・券種情報存在フラグ（'0'：存在しない '1'：存在する）によるケース分け
				CASE recKenshu.KIBANGO_FLG || recKenshu.KENSHU_FLG
					-- 券種情報のみ存在
					WHEN '01' THEN
						-- 突合結果（券種）
						gKMatchNm[gKCnt] := '記番号情報なし';
						-- 枚数（券種）
						gKenshuMaisu[gKCnt] := recKenshu.KENSHU_MAISU;
					-- 記番号情報のみ存在
					WHEN '10' THEN
						-- 突合結果（券種）
						gKMatchNm[gKCnt] := '券種情報なし';
						-- 枚数（記番号）
						gKibangoMaisu[gKCnt] := recKenshu.KIBANGO_MAISU;
					-- 券種情報、記番号情報が存在
					ELSE
						-- 枚数（記番号）
						gKibangoMaisu[gKCnt] := recKenshu.KIBANGO_MAISU;
						-- 枚数（券種）
						gKenshuMaisu[gKCnt] := recKenshu.KENSHU_MAISU;
						-- 枚数（記番号） = 枚数（券種）の時
						IF recKenshu.KIBANGO_MAISU = recKenshu.KENSHU_MAISU THEN
							-- 突合結果（券種）
							gKMatchNm[gKCnt] := '一致';
						ELSE
							-- 突合結果（券種）
							gKMatchNm[gKCnt] := '枚数不一致';
						END IF;
				END CASE;
--				pkLog.debug(l_inUserId, C_PROGRAM_ID, '記番号情報存在フラグ:"' || recKenshu.KIBANGO_FLG || '"');
--				pkLog.debug(l_inUserId, C_PROGRAM_ID, '券種情報存在フラグ:"' || recKenshu.KENSHU_FLG || '"');
--				pkLog.debug(l_inUserId, C_PROGRAM_ID, '枚数（記番号）:"' || gKibangoMaisu[gKCnt] || '"');
--				pkLog.debug(l_inUserId, C_PROGRAM_ID, '枚数（券種）:"' || gKenshuMaisu[gKCnt] || '"');
--				pkLog.debug(l_inUserId, C_PROGRAM_ID, '突合結果（券種）:"' || gKMatchNm[gKCnt] || '"');
				-- カウント（券種用）のカウントアップ
				gKCnt := gKCnt + 1;
			END LOOP;
		END IF;
		-- 銘柄名称（正式 OR 略称）編集
		IF gMgrFlg = '1' THEN
			gProMgrNm := SUBSTR(recMeisai.MGR_NM, 1, 50);
		ELSE
			gProMgrNm := recMeisai.MGR_RNM;
		END IF;
--		pkLog.debug(l_inUserId, C_PROGRAM_ID, '銘柄名称（正式 OR 略称）:"' || gProMgrNm || '"');
		-- 突合結果 ＆ 金額編集================================================
		-- 変数初期化
		gKaijiKngk   := NULL; -- 元本減債金額（償還回次）
		gKibangoKngk := NULL; -- 元本減債金額（記番号情報）
		-- 償還回次・記番号情報存在フラグ（'0'：存在しない '1'：存在する）によるケース分け
		CASE recMeisai.KAIJI_FLG || recMeisai.KIBANGO_FLG
			-- 記番号情報のみ存在
			WHEN '01' THEN
				-- 突合結果
				gMatchNm := '償還回次なし';
				-- 元本減債金額（記番号情報）
				gKibangoKngk := recMeisai.KIBANGO_KNGK;
			-- 償還回次のみ存在
			WHEN '10' THEN
				-- 突合結果
				gMatchNm := '記番号情報なし';
				-- 元本減債金額（償還回次）
				gKaijiKngk := recMeisai.KAIJI_KNGK;
			-- 記番号情報、償還回次が存在
			WHEN '11' THEN
				-- 元本減債金額（償還回次）
				gKaijiKngk := recMeisai.KAIJI_KNGK;
				-- 元本減債金額（記番号情報）
				gKibangoKngk := recMeisai.KIBANGO_KNGK;
				-- 元本減債金額（償還回次） = 元本減債金額（記番号情報）の時
				IF recMeisai.KAIJI_KNGK = recMeisai.KIBANGO_KNGK THEN
					-- 突合結果
					gMatchNm := '一致';
				ELSE
					-- 突合結果
					gMatchNm := '元本減債額不一致';
				END IF;
			-- 記番号情報、償還回次が存在しない
			ELSE
				-- 突合結果
				gMatchNm := ' ';
		END CASE;
--		pkLog.debug(l_inUserId, C_PROGRAM_ID, '償還回次存在フラグ:"' || recMeisai.KAIJI_FLG || '"');
--		pkLog.debug(l_inUserId, C_PROGRAM_ID, '記番号情報存在フラグ:"' || recMeisai.KIBANGO_FLG || '"');
--		pkLog.debug(l_inUserId, C_PROGRAM_ID, '元本減債金額（償還回次）:"' || recMeisai.KAIJI_KNGK || '"');
--		pkLog.debug(l_inUserId, C_PROGRAM_ID, '元本減債金額（記番号情報）:"' || recMeisai.KIBANGO_KNGK || '"');
--		pkLog.debug(l_inUserId, C_PROGRAM_ID, '突合結果:"' || gMatchNm || '"');
		-- ====================================================================
		-- 帳票ワーク登録
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gItakuKaishaRnm;	-- 委託会社略名
		v_item.l_inItem002 := gGyomuYmd;	-- 業務日付
		v_item.l_inItem003 := recMeisai.MGR_CD;	-- 銘柄コード
		v_item.l_inItem004 := recMeisai.ISIN_CD;	-- ＩＳＩＮコード
		v_item.l_inItem005 := gProMgrNm;	-- 銘柄名称（正式 OR 略称）
		v_item.l_inItem006 := recMeisai.FURIKAESOGAKU;	-- 振替債総額
		v_item.l_inItem007 := coalesce(gKenshuCd[1]::text, ' ');	-- 券種コード１
		v_item.l_inItem008 := coalesce(gKenshuMaisu[1]::text, ' ');	-- 枚数１
		v_item.l_inItem009 := coalesce(gKibangoMaisu[1]::text, ' ');	-- 記番号枚数１
		v_item.l_inItem010 := coalesce(gKMatchNm[1]::text, ' ');	-- 突合結果１
		v_item.l_inItem011 := coalesce(gKenshuCd[2]::text, ' ');	-- 券種コード２
		v_item.l_inItem012 := coalesce(gKenshuMaisu[2]::text, ' ');	-- 枚数２
		v_item.l_inItem013 := coalesce(gKibangoMaisu[2]::text, ' ');	-- 記番号枚数２
		v_item.l_inItem014 := coalesce(gKMatchNm[2]::text, ' ');	-- 突合結果２
		v_item.l_inItem015 := coalesce(gKenshuCd[3]::text, ' ');	-- 券種コード３
		v_item.l_inItem016 := coalesce(gKenshuMaisu[3]::text, ' ');	-- 枚数３
		v_item.l_inItem017 := coalesce(gKibangoMaisu[3]::text, ' ');	-- 記番号枚数３
		v_item.l_inItem018 := coalesce(gKMatchNm[3]::text, ' ');	-- 突合結果３
		v_item.l_inItem019 := coalesce(gKenshuCd[4]::text, ' ');	-- 券種コード４
		v_item.l_inItem020 := coalesce(gKenshuMaisu[4]::text, ' ');	-- 枚数４
		v_item.l_inItem021 := coalesce(gKibangoMaisu[4]::text, ' ');	-- 記番号枚数４
		v_item.l_inItem022 := coalesce(gKMatchNm[4]::text, ' ');	-- 突合結果４
		v_item.l_inItem023 := coalesce(gKenshuCd[5]::text, ' ');	-- 券種コード５
		v_item.l_inItem024 := coalesce(gKenshuMaisu[5]::text, ' ');	-- 枚数５
		v_item.l_inItem025 := coalesce(gKibangoMaisu[5]::text, ' ');	-- 記番号枚数５
		v_item.l_inItem026 := coalesce(gKMatchNm[5]::text, ' ');	-- 突合結果５
		v_item.l_inItem027 := coalesce(recMeisai.SHOKAN_KJT, ' ');	-- 償還期日
		v_item.l_inItem028 := coalesce(recMeisai.KBG_SHOKAN_KBN, ' ');	-- 償還区分（実質記番号用）
		v_item.l_inItem029 := coalesce(recMeisai.KBG_SHOKAN_KBN_NM, ' ');	-- 償還区分名称
		v_item.l_inItem030 := coalesce(gKaijiKngk::text, ' ');	-- 元本減債金額（償還回次）
		v_item.l_inItem031 := coalesce(gKibangoKngk::text, ' ');	-- 元本減債金額（記番号情報）
		v_item.l_inItem032 := gMatchNm;	-- 突合結果
		v_item.l_inItem033 := l_inUserId;	-- ユーザーＩＤ
		v_item.l_inItem034 := C_CHOHYO_ID;	-- 帳票ＩＤ
		
		-- Call pkPrint.insertData with composite type
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
		-- シーケンスのカウントアップ
		gSeqNo := gSeqNo + 1;
		-- ブレイク確認用変数へ格納
		gMgrCd := recMeisai.MGR_CD;
	END LOOP;
	-- 対象データなし時
	IF gSeqNo = 1 THEN
		-- リアルの時
		IF l_inChohyoKbn = '0' THEN
			-- ヘッダレコードを追加
			CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, gGyomuYmd, C_CHOHYO_ID);
			-- 帳票ワーク登録
					-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gItakuKaishaRnm;	-- 委託会社略名
		v_item.l_inItem033 := l_inUserId;	-- ユーザーＩＤ
		v_item.l_inItem034 := C_CHOHYO_ID;	-- 帳票ＩＤ
		v_item.l_inItem035 := '対象データなし';	-- 対象データなし
		
		-- Call pkPrint.insertData with composite type
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
		END IF;
	ELSE
		-- ヘッダレコードを追加
		CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, gGyomuYmd, C_CHOHYO_ID);
		-- バッチの時
		IF l_inChohyoKbn = '1' THEN
			-- バッチ帳票印刷データ作成
			CALL pkPrtOk.insertPrtOk(
								l_inUserId,
								l_inItakuKaishaCd,
								gGyomuYmd,
								pkPrtOk.LIST_SAKUSEI_KBN_ZUIJI(),
								C_CHOHYO_ID
								);
		END IF;
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
-- REVOKE ALL ON PROCEDURE spipp012k00r01 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE, l_inUserId SREPORT_WK.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_inMgrCd KBG_SHOKBG.MGR_CD%TYPE, l_inIsinCd MGR_KIHON.ISIN_CD%TYPE, l_outSqlCode OUT integer, l_outSqlErrM OUT text ) FROM PUBLIC;