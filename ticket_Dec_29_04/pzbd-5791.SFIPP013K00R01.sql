




CREATE OR REPLACE FUNCTION sfipp013k00r01 () RETURNS integer AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2007
-- * 会社名:JIP
-- *
-- * 概要　:買入消却データ自動作成（実質記番号）
-- *
-- * 返り値: 0:正常
-- *         1:エラー
-- *        99:予期しない例外
-- *
-- * @author ASK
-- * @version $Id: SFIPP013K00R01.sql,v 1.4 2020/11/06 10:53:31 saito Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2007.06.21 中村        新規作成
-- ***************************************************************************
--	/*==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_PROGRAM_ID CONSTANT varchar(50) := 'SFIPP013K00R01'; -- プログラムＩＤ
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	gYokuGyoYmd char(8); -- 業務日付の翌営業日付取得
	gOptionFlg  char(1);     -- 実質記番号オプション
	gUpdMgr     TYPEUPDMGR_ARRAY;                  -- 期中銘柄情報変更タイプ
	gRowid      varchar(30);                      -- 行ＩＤ
	gSqlCode    integer;                           -- リターン値
	gErrIsinCd  varchar(12);            -- エラーＩＳＩＮコード
	gErrMsg     varchar(1000);                    -- エラーメッセージ
	gCnt		integer;
	gAllShokanYmd char(8);      -- 買入消却（全額）の償還日取得
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	-- 自行委託ビュー・カーソル
	curItaku CURSOR FOR
		SELECT
			KAIIN_ID
		FROM
			VJIKO_ITAKU;
	-- 明細・カーソル
	curMeisai CURSOR(
		l_inItakuKaishaCd text  -- 委託会社コード
	) FOR
		SELECT
			P01.MGR_CD,                                     -- 銘柄コード
			P01.SHOKAN_YMD,                                 -- 償還年月日
			SUM(P01.MUNIT_GENSAI_KNGK) AS MUNIT_GENSAI_KNGK  -- 銘柄単位元本減債金額
		FROM
			KBG_SHOKIJ P01,
			MGR_KIHON_VIEW VMG1
		WHERE
			P01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
			AND P01.MGR_CD = VMG1.MGR_CD
			AND P01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND P01.SHOKAN_YMD = gYokuGyoYmd
			AND P01.KBG_SHOKAN_KBN IN ('61', '62', '63')
			AND VMG1.JTK_KBN != '2'
			AND VMG1.JTK_KBN != '5'
			AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
			AND VMG1.MGR_STAT_KBN = '1'
			AND VMG1.KK_KANYO_FLG = '2'
		GROUP BY
			P01.MGR_CD,
			P01.SHOKAN_YMD
		ORDER BY
			P01.MGR_CD,
			P01.SHOKAN_YMD;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 業務日付の翌営業日付取得
	gYokuGyoYmd := pkDate.getYokuBusinessYmd(pkDate.getGyomuYmd());
--	pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '翌営業日付:"' || gYokuGyoYmd || '"');
	-- 自行委託ビュー読込
	FOR recItaku IN curItaku LOOP
		-- 実質記番号オプション取得
		BEGIN
			SELECT
				OPTION_FLG
			INTO STRICT
				gOptionFlg
			FROM
				MOPTION_KANRI
			WHERE
				KEY_CD = recItaku.KAIIN_ID
				AND OPTION_CD = 'IPP1003302010';
		EXCEPTION
			WHEN no_data_found THEN
				gOptionFlg := '0';
		END;
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '委託会社コード:"' || recItaku.KAIIN_ID || '"');
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '実質記番号オプション:"' || gOptionFlg || '"');
		-- 実質記番号オプション・オンの時
		IF gOptionFlg = '1' THEN
--			pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '買入消却データ自動作成（実質記番号） 実行する');
			-- 期中銘柄情報変更タイプ初期化
			gUpdMgr := '{}';
			-- 明細読込
			FOR recMeisai IN curMeisai(recItaku.KAIIN_ID) LOOP
				-- 期中銘柄変更（銘柄）の更新対象データチェック(件数取得)
				SELECT COUNT(*) INTO STRICT gCnt FROM UPD_MGR_SHN	
					WHERE	ITAKU_KAISHA_CD = recItaku.KAIIN_ID
						AND	MGR_CD = recMeisai.MGR_CD
						AND	SHR_KJT = recMeisai.SHOKAN_YMD;
				-- 自動作成前にデータが既に存在する場合は更新しないでスルー
				IF gCnt > 0 THEN
					CALL PKLOG.WARN('WCM014',C_PROGRAM_ID,'既に買入消却データが存在する為、自動作成しません。'
								|| '委託会社：' || recItaku.KAIIN_ID || '　銘柄：' || recMeisai.MGR_CD);
				ELSE
					-- 期中銘柄変更（銘柄）登録（「実質記番号管理償還回次」 → 「期中銘柄変更（銘柄）」）
					INSERT INTO UPD_MGR_SHN(
						ITAKU_KAISHA_CD,          -- 委託会社コード
						MGR_CD,                   -- 銘柄コード
						SHR_KJT,                  -- 支払期日
						MGR_HENKO_KBN,            -- 銘柄情報変更区分
						GENSAI_KNGK,              -- 減債金額
						KK_PHASE,                 -- 機構フェーズ
						KK_STAT,                  -- 機構ステータス
						SHONIN_KAIJO_YOKUSEI_FLG, -- 承認解除抑制フラグ
						SHORI_KBN,                -- 処理区分
						LAST_TEISEI_DT,           -- 最終訂正日時
						LAST_TEISEI_ID,           -- 最終訂正者
						SHONIN_DT,                -- 承認日時
						SHONIN_ID,                -- 承認者
						KOUSIN_ID,                -- 更新者
						SAKUSEI_ID                 -- 作成者
					) VALUES (
						recItaku.KAIIN_ID,
						recMeisai.MGR_CD,
						recMeisai.SHOKAN_YMD,
						'30',
						recMeisai.MUNIT_GENSAI_KNGK,
						'M2',
						'01',
						'0',
						'0',
						to_timestamp(pkDate.getCurrentTime(), 'YYYY-MM-DD HH24:MI:SS.US'),
						pkconstant.BATCH_USER(),
						to_timestamp(pkDate.getCurrentTime(), 'YYYY-MM-DD HH24:MI:SS.US'),
						pkconstant.BATCH_USER(),
						pkconstant.BATCH_USER(),
						pkconstant.BATCH_USER()
					)
					RETURNING ROWIDTOCHAR(oid) INTO gRowid;
	--				pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '行ＩＤ:' || gRowid);
					-- 期中銘柄情報変更タイプセット===================================================
					gUpdMgr := array_append(gUpdMgr, null);
					gUpdMgr[coalesce(cardinality(gUpdMgr), 0)] := ROW(
															recMeisai.MGR_CD,      -- 銘柄コード
															recMeisai.SHOKAN_YMD,  -- 支払期日（償還年月日）
															'30',                  -- 銘柄情報変更区分
															'0',                   -- 2営業日前チェックフラグ
															gRowid                  -- 行ＩＤ
														)::TYPEUPDMGR;
					-- ===============================================================================
					-- 翌営業日に買入消却（全額）がある場合、買入消却（全額）以降の基金異動履歴を削除する
					BEGIN
						SELECT trim(both MAX(P01.SHOKAN_YMD))
						INTO STRICT   gAllShokanYmd
						FROM   KBG_SHOKIJ P01
						WHERE  P01.ITAKU_KAISHA_CD = recItaku.KAIIN_ID
						  AND  P01.MGR_CD = recMeisai.MGR_CD
						  AND  P01.SHOKAN_YMD = recMeisai.SHOKAN_YMD
						  AND  P01.KBG_SHOKAN_KBN = '63'         -- 63:買入消却（全額）
						GROUP  BY P01.ITAKU_KAISHA_CD, P01.MGR_CD;
						DELETE FROM KIKIN_IDO K02
						WHERE K02.ITAKU_KAISHA_CD = recItaku.KAIIN_ID
						  AND K02.MGR_CD = recMeisai.MGR_CD
						  AND K02.RBR_YMD > gAllShokanYmd;
					EXCEPTION
						WHEN no_data_found THEN
						     NULL;
					END;
				END IF;
			END LOOP;
			-- 明細データがある時
			IF coalesce(cardinality(gUpdMgr), 0) != 0 THEN
				-- 期中銘柄情報変更一覧（承認）ファンクション・コール
				gSqlCode := sfIpUpdMgrShnProcess(
					gUpdMgr,               -- 期中銘柄情報変更タイプ
					recItaku.KAIIN_ID,     -- 委託会社コード
					pkconstant.BATCH_USER(), -- ユーザーＩＤ
					gErrIsinCd,            -- エラーＩＳＩＮコード
					gErrMsg                 -- エラーメッセージ
				);
				-- エラー判定
				IF gSqlCode != pkconstant.success() THEN
					CALL pkLog.error('ECM701', C_PROGRAM_ID, '買入消却データ自動作成（実質記番号）失敗');
					RETURN gSqlCode;
				END IF;
			END IF;
		-- 実質記番号オプション・オフの時
--		ELSE
--			pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '買入消却データ自動作成（実質記番号） 実行しない');
		END IF;
	END LOOP;
	-- 正常終了
	RETURN pkconstant.success();
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'SQLERRM:' || SQLERRM);
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipp013k00r01 () FROM PUBLIC;
