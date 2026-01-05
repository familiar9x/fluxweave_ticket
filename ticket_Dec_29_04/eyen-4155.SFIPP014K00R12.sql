
CREATE OR REPLACE FUNCTION sfipp014k00r12 () RETURNS integer AS $body$
DECLARE

ora2pg_rowcount int;
--*
-- * 著作権:Copyright(c)2007
-- * 会社名:JIP
-- *
-- * 概要　:実質記番号管理償還回次更新
-- *
-- * 引数　:なし
-- *
-- * 返り値: 0:正常
-- *        99:異常
-- *
-- * @author ASK
-- * @version $Id: SFIPP014K00R12.sql,v 1.2 2008/09/10 01:20:57 harada Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2007.07.03 中村        新規作成
-- ***************************************************************************
--
	--==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_FUNCTION_ID CONSTANT varchar(50) := 'SFIPP014K00R12'; -- ファンクションＩＤ
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	gStRecKbn       integer;                          -- 初回レコード区分
	gItakuKaishaCd  char(4);  -- 委託会社コード
	gMgrCd          varchar(50);           -- 銘柄コード
	gKbgShokanKbn   char(2);   -- 償還区分（実質記番号用）
	gShokanKjt      char(8);       -- 償還期日
	gShokanYmd      char(8);       -- 償還年月日
	gKknChokyuKjt   char(8);   -- 基金徴求期日
	gKknChokyuYmd   char(8);   -- 基金徴求日
	gTesuChokyuKjt  char(8);  -- 手数料徴求期日
	gTesuChokyuYmd  char(8);  -- 手数料徴求日
	gKknbillOutYmd  char(8);  -- 基金請求書出力日
	gTesubillOutYmd char(8); -- 手数料請求書出力日
	gMessage        varchar(200);                     -- メッセージ
	gSqlCode        integer;                          -- リターン値
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	curMeisai CURSOR FOR
		SELECT
			P06.ITAKU_KAISHA_CD, -- 委託会社コード
			P06.MGR_CD,          -- 銘柄コード
			P06.SHOKAN_KJT,      -- 償還期日
			P06.KBG_SHOKAN_KBN,  -- 償還区分（実質記番号用）
			P06.DATE_SHURUI_CD,  -- 日付種類
			P06.HENKO_AFT_YMD     -- 変更後年月日
		FROM
			MOD_KBG_SHOKIJ P06
		WHERE
			EXISTS (
				SELECT
					M61.ITAKU_KAISHA_CD
				FROM
					MCALENDAR_TEISEI M61
				WHERE
					M61.ITAKU_KAISHA_CD = P06.ITAKU_KAISHA_CD
					AND M61.MGR_KJT_CHOSEI_KBN = '3'
			)
		ORDER BY
			P06.ITAKU_KAISHA_CD,
			P06.MGR_CD,
			P06.SHOKAN_KJT,
			P06.KBG_SHOKAN_KBN;
	--==============================================================================
	--                  メイン処理                                                  
	--==============================================================================
	
BEGIN
--	pkLog.debug(pkconstant.BATCH_USER(), C_FUNCTION_ID, C_FUNCTION_ID || ' START');
	-- 変数初期化-----------------------------------
	gStRecKbn := 0;          -- 初回レコード区分
	gShokanYmd := NULL;      -- 償還年月日
	gKknChokyuKjt := NULL;   -- 基金徴求期日
	gKknChokyuYmd := NULL;   -- 基金徴求日
	gTesuChokyuKjt := NULL;  -- 手数料徴求期日
	gTesuChokyuYmd := NULL;  -- 手数料徴求日
	gKknbillOutYmd := NULL;  -- 基金請求書出力日
	gTesubillOutYmd := NULL; -- 手数料請求書出力日
	------------------------------------------------
	FOR recMeisai IN curMeisai
	LOOP
		-- 初回レコードでなく、委託会社コード、銘柄コード、償還期日、償還区分（実質記番号用）がブレイク時
		IF gStRecKbn = 1
		AND (
			recMeisai.ITAKU_KAISHA_CD <> gItakuKaishaCd
			OR recMeisai.MGR_CD <> gMgrCd
			OR recMeisai.SHOKAN_KJT <> gShokanKjt
			OR recMeisai.KBG_SHOKAN_KBN <> gKbgShokanKbn
			) THEN
			-- 実質記番号管理償還回次更新
			UPDATE KBG_SHOKIJ SET
				SHOKAN_YMD = coalesce(gShokanYmd, SHOKAN_YMD),                                          -- 償還年月日
				KKN_CHOKYU_KJT = coalesce(gKknChokyuKjt, KKN_CHOKYU_KJT),                               -- 基金徴求期日
				KKN_CHOKYU_YMD = coalesce(gKknChokyuYmd, KKN_CHOKYU_YMD),                               -- 基金徴求日
				TESU_CHOKYU_KJT = coalesce(gTesuChokyuKjt, TESU_CHOKYU_KJT),                            -- 手数料徴求期日
				TESU_CHOKYU_YMD = coalesce(gTesuChokyuYmd, TESU_CHOKYU_YMD),                            -- 手数料徴求日
				KKNBILL_OUT_YMD = coalesce(gKknbillOutYmd, KKNBILL_OUT_YMD),                            -- 基金請求書出力日
				TESUBILL_OUT_YMD = coalesce(gTesubillOutYmd, TESUBILL_OUT_YMD),                         -- 手数料請求書出力日
				LAST_TEISEI_DT = to_timestamp(pkDate.getCurrentTime(), 'YYYY-MM-DD HH24:MI:SS.US'), -- 最終訂正日時
				LAST_TEISEI_ID = pkconstant.BATCH_USER(),                                            -- 最終訂正者
				KOUSIN_ID = pkconstant.BATCH_USER()                                                   -- 更新者
			WHERE
				ITAKU_KAISHA_CD = gItakuKaishaCd
				AND MGR_CD = gMgrCd
				AND SHOKAN_KJT = gShokanKjt
				AND KBG_SHOKAN_KBN = gKbgShokanKbn;
			GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;
			IF ora2pg_rowcount = 0 THEN
				-- ログ出力
				gMessage := '更新対象・実質記番号管理償還回次は削除済みです。'
							|| '委託会社コード:' || gItakuKaishaCd
							|| ' 銘柄コード:' || gMgrCd
							|| ' 償還期日:' || gShokanKjt
							|| ' 償還区分（実質記番号用）:' || gKbgShokanKbn;
				CALL pkLog.warn(pkconstant.BATCH_USER(), C_FUNCTION_ID, gMessage);
			END IF;
			-- 変数初期化-----------------------------------
			gShokanYmd := NULL;      -- 償還年月日
			gKknChokyuKjt := NULL;   -- 基金徴求期日
			gKknChokyuYmd := NULL;   -- 基金徴求日
			gTesuChokyuKjt := NULL;  -- 手数料徴求期日
			gTesuChokyuYmd := NULL;  -- 手数料徴求日
			gKknbillOutYmd := NULL;  -- 基金請求書出力日
			gTesubillOutYmd := NULL; -- 手数料請求書出力日
			------------------------------------------------
		END IF;
		-- 初回レコード区分
		gStRecKbn := 1;
		-- 委託会社コード
		gItakuKaishaCd := recMeisai.ITAKU_KAISHA_CD;
		-- 銘柄コード
		gMgrCd := recMeisai.MGR_CD;
		-- 償還期日
		gShokanKjt := recMeisai.SHOKAN_KJT;
		-- 償還区分（実質記番号用）
		gKbgShokanKbn := recMeisai.KBG_SHOKAN_KBN;
		CASE recMeisai.DATE_SHURUI_CD
			WHEN '21' THEN
				-- 償還年月日
				gShokanYmd := recMeisai.HENKO_AFT_YMD;
			WHEN '22' THEN
				-- 基金徴求期日
				gKknChokyuKjt := recMeisai.HENKO_AFT_YMD;
			WHEN '23' THEN
				-- 基金徴求日
				gKknChokyuYmd := recMeisai.HENKO_AFT_YMD;
			WHEN '24' THEN
				-- 手数料徴求期日
				gTesuChokyuKjt := recMeisai.HENKO_AFT_YMD;
			WHEN '25' THEN
				-- 手数料徴求日
				gTesuChokyuYmd := recMeisai.HENKO_AFT_YMD;
			WHEN '26' THEN
				-- 基金請求書出力日
				gKknbillOutYmd := recMeisai.HENKO_AFT_YMD;
			WHEN '27' THEN
				-- 手数料請求書出力日
				gTesubillOutYmd := recMeisai.HENKO_AFT_YMD;
		END CASE;
	END LOOP;
	IF gStRecKbn = 1 THEN
		-- 実質記番号管理償還回次更新
		UPDATE KBG_SHOKIJ SET
			SHOKAN_YMD = coalesce(gShokanYmd, SHOKAN_YMD),                                          -- 償還年月日
			KKN_CHOKYU_KJT = coalesce(gKknChokyuKjt, KKN_CHOKYU_KJT),                               -- 基金徴求期日
			KKN_CHOKYU_YMD = coalesce(gKknChokyuYmd, KKN_CHOKYU_YMD),                               -- 基金徴求日
			TESU_CHOKYU_KJT = coalesce(gTesuChokyuKjt, TESU_CHOKYU_KJT),                            -- 手数料徴求期日
			TESU_CHOKYU_YMD = coalesce(gTesuChokyuYmd, TESU_CHOKYU_YMD),                            -- 手数料徴求日
			KKNBILL_OUT_YMD = coalesce(gKknbillOutYmd, KKNBILL_OUT_YMD),                            -- 基金請求書出力日
			TESUBILL_OUT_YMD = coalesce(gTesubillOutYmd, TESUBILL_OUT_YMD),                         -- 手数料請求書出力日
			LAST_TEISEI_DT = to_timestamp(pkDate.getCurrentTime(), 'YYYY-MM-DD HH24:MI:SS.US'), -- 最終訂正日時
			LAST_TEISEI_ID = pkconstant.BATCH_USER(),                                            -- 最終訂正者
			KOUSIN_ID = pkconstant.BATCH_USER()                                                   -- 更新者
		WHERE
			ITAKU_KAISHA_CD = gItakuKaishaCd
			AND MGR_CD = gMgrCd
			AND SHOKAN_KJT = gShokanKjt
			AND KBG_SHOKAN_KBN = gKbgShokanKbn;
		GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;
		IF ora2pg_rowcount = 0 THEN
			-- ログ出力
			gMessage := '更新対象・実質記番号管理償還回次は削除済みです。'
						|| '委託会社コード:' || gItakuKaishaCd
						|| ' 銘柄コード:' || gMgrCd
						|| ' 償還期日:' || gShokanKjt
						|| ' 償還区分（実質記番号用）:' || gKbgShokanKbn;
			CALL pkLog.warn(pkconstant.BATCH_USER(), C_FUNCTION_ID, gMessage);
		END IF;
		-- エラー判定
		IF gSqlCode <> pkconstant.success() THEN
			RETURN gSqlCode;
		END IF;
	END IF;
	-- 実質記番号管理償還回次調整情報を実質記番号管理償還回次調整情報（履歴）へ退避
	INSERT INTO MOD_KBG_SHOKIJ_RIREKI
	SELECT P06.* FROM MOD_KBG_SHOKIJ P06
	WHERE
		EXISTS (
			SELECT
				M61.ITAKU_KAISHA_CD
			FROM
				MCALENDAR_TEISEI M61
			WHERE
				M61.ITAKU_KAISHA_CD = P06.ITAKU_KAISHA_CD
				AND M61.MGR_KJT_CHOSEI_KBN = '3'
		);
	-- IP-05816　実質記番号管理償還回次調整情報の削除処理をSFIPI077K00R14に移動
	
--	pkLog.debug(pkconstant.BATCH_USER(), C_FUNCTION_ID, C_FUNCTION_ID || ' END');
	-- 終了処理
	RETURN pkconstant.success();
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SUBSTRING(C_FUNCTION_ID FROM 1 FOR 12), 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', SUBSTRING(C_FUNCTION_ID FROM 1 FOR 12), 'SQLERRM:' || SQLERRM);
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipp014k00r12 () FROM PUBLIC;

