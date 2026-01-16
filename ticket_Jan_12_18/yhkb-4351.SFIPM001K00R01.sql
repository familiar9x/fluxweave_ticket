




CREATE OR REPLACE FUNCTION sfipm001k00r01 ( l_inUserId MMEMORANDOM.SAKUSEI_ID%TYPE,        -- ユーザID
 l_inItakuKaishaCd MMEMORANDOM.ITAKU_KAISHA_CD%TYPE,   -- 委託会社コード
 l_inMemorandomCd MMEMORANDOM.MEMORANDOM_CD%TYPE,     -- 備忘録コード
 l_inShoriMode text                            -- 処理モード(1:登録、2:訂正、3:削除、4:照会)
 ) RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2006
-- * 会社名: JIP
-- *
-- * 備忘録日次作業情報を作成します。
-- * 銘柄非連動の場合、備忘録マスタの内容を元に備忘録日次作業情報を編集する。
-- *
-- * @param l_inUserId        ユーザID
-- * @param l_inItakuKaishaCd 委託会社コード
-- * @param l_inMemorandomCd  備忘録コード
-- * @param l_inShoriMode     処理モード(1:登録、2:訂正、3:削除、4:照会)
-- * @return INTEGER
-- *                0:正常終了
-- *               99:その他のエラー
-- *
-- * @author ASK
-- * @version $Id: SFIPM001K00R01.sql,v 1.2 2017/01/04 11:03:57 fujii Exp $
-- 
	--==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_PROGRAM_ID            CONSTANT text := 'SFIPM001K00R01';    -- プログラムID
	C_ERR_NO_DATA           CONSTANT integer      := 1;
	C_ERR_DUP_VAL_ON_INDEX  CONSTANT integer      := 2;
	C_ERR_SSI               CONSTANT integer      := 3;
	C_ERR_SKN_KESSAI        CONSTANT integer      := 4;
	C_ERR_HIKIUKE           CONSTANT integer      := 5;
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	gTypeMmemoRandom                 RECORD;                     -- 備忘録マスタ
	gTypeMemoRandomdSagyo            MEMORANDOM_D_SAGYO%ROWTYPE;              -- 備忘録日次作業情報
	gShokaiFspan                     MMEMORANDOM.SHOKAI_F_SPAN%TYPE;          -- 照会期間(FROM)
	gStHyojiYmd                      MMEMORANDOM.ST_HYOJI_YMD%TYPE;           -- 表示年月日
	gHyojiYmd                        MMEMORANDOM.ST_HYOJI_YMD%TYPE;           -- 表示年月日保存
	gSagyoYmd                        MEMORANDOM_D_SAGYO.SAGYO_YMD%TYPE;       -- 作業日
	gActFlg                          integer;                                 -- アクションフラグ
	gResult                          integer;
	v_stack_trace                    text;                                    -- Stack trace for debugging
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	CALL pkLog.debug(l_inUserId, C_PROGRAM_ID, C_PROGRAM_ID||' START');
	-- 必須項目チェック
	IF coalesce(l_inUserId::text, '') = '' OR coalesce(l_inItakuKaishaCd::text, '') = '' OR coalesce(l_inMemorandomCd::text, '') = '' OR coalesce(l_inShoriMode::text, '') = '' THEN
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROGRAM_ID,3,12), '備忘録日次作業情報・必須項目エラー');
		RETURN pkconstant.FATAL();
	END IF;
	-- 初期化
	gActFlg := 0;
	--処理モードが照会なら何もしない
	IF l_inShoriMode = '4' THEN
		RETURN pkconstant.success();
	END IF;
	--処理モードが削除なら削除のみ
	IF l_inShoriMode = '3' THEN
		-- 備忘録日次作業情報（履歴）テーブル追加
		gResult := SFIPM001K00R01_AddMemoRandomdSagyoRireki(l_inItakuKaishaCd, l_inMemorandomCd);
		IF gResult <> 0 THEN
			RETURN gResult;
		END IF;
		-- 対象備忘録日次作業情報テーブル削除
		gResult := SFIPM001K00R01_DelMemoRandomdSagyo(l_inItakuKaishaCd, l_inMemorandomCd);
		IF gResult <> 0 THEN
			RETURN gResult;
		END IF;
	END IF;
	--処理モードが登録・訂正なら対象備忘録日次作業情報レコード作成
	IF l_inShoriMode = '1' OR l_inShoriMode = '2' THEN
		-- 対象備忘録日次作業情報テーブル削除
		gResult := SFIPM001K00R01_DelMemoRandomdSagyo(l_inItakuKaishaCd, l_inMemorandomCd);
		IF gResult <> 0 THEN
			RETURN gResult;
		END IF;
		-- 備忘録マスタ取得
		BEGIN
			SELECT ME01.* INTO STRICT gTypeMmemoRandom
			FROM
				MMEMORANDOM ME01,
				MEMORANDOM_TYPE ME02
			WHERE ME01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND ME01.MEMORANDOM_CD = l_inMemorandomCd
			AND ME01.MEMORANDOM_TYPE_CD = ME02.MEMORANDOM_TYPE_CD
			AND ME02.MGR_RENDO_FLG = '0';
		EXCEPTION
			WHEN no_data_found THEN
				RETURN pkconstant.success();
		END;
		-- 対象備忘録日次作業情報テーブル削除
		gResult := SFIPM001K00R01_DelMemoRandomdSagyo(l_inItakuKaishaCd, l_inMemorandomCd);
		IF gResult <> 0 THEN
			RETURN gResult;
		END IF;
		--初回表示作業日設定
		gStHyojiYmd := gTypeMmemoRandom.ST_HYOJI_YMD;
		--作業日設定
		gSagyoYmd := SFIPM001K00R01_getSagyoYmd(gStHyojiYmd, gTypeMmemoRandom.GMATSU_FLG, gTypeMmemoRandom.KYUJITSU_KBN);
		WHILE pkDate.dateCompareCheck(gSagyoYmd, gTypeMmemoRandom.SHOKAI_T_SPAN) = 0 OR gActFlg = 1 LOOP
			-- 初期化
			CALL SFIPM001K00R01_clearMemoRandomdSagyo(gTypeMemoRandomdSagyo);
			-- 備忘録日次作業情報テーブル編集
			gTypeMemoRandomdSagyo := SFIPM001K00R01_makeMemoRandomdSagyo(gSagyoYmd, gTypeMmemoRandom, gTypeMemoRandomdSagyo);
			-- 備忘録日次作業情報テーブル追加
			gResult := SFIPM001K00R01_AddMemoRandomdSagyo(gTypeMemoRandomdSagyo);
			IF gResult <> 0 THEN
				RETURN gResult;
			END IF;
			--表示間隔が０の場合止める
			IF gTypeMmemoRandom.HYOJI_SPAN = 0 THEN
				EXIT;
			END IF;
			--次回表示作業日のカウント
			gHyojiYmd := pkDate.calcMonth(gStHyojiYmd, gTypeMmemoRandom.HYOJI_SPAN);
			--次回表示作業日保存
			gStHyojiYmd := gHyojiYmd;
			--最初に求めた次回表示作業日が範囲内かチェック
			IF pkDate.dateCompareCheck(gHyojiYmd, gTypeMmemoRandom.SHOKAI_T_SPAN) = 0 THEN
				gActFlg := 1;
				--作業日設定
				gSagyoYmd := SFIPM001K00R01_getSagyoYmd(gStHyojiYmd, gTypeMmemoRandom.GMATSU_FLG, gTypeMmemoRandom.KYUJITSU_KBN);
			ELSE
				gActFlg := 0;
				--作業日設定
				gSagyoYmd := gStHyojiYmd;
			END IF;
		END LOOP;
	END IF;
	CALL pkLog.debug(l_inUserId, C_PROGRAM_ID, C_PROGRAM_ID||' END');
	RETURN pkconstant.success();
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		GET STACKED DIAGNOSTICS v_stack_trace = PG_EXCEPTION_CONTEXT;
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROGRAM_ID,3,12), 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROGRAM_ID,3,12), 'SQLERRM:' || SQLERRM);
		CALL pkLog.debug(l_inUserId, SUBSTR(C_PROGRAM_ID,3,12), 'Stack trace: ' || COALESCE(v_stack_trace, 'N/A'));
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipm001k00r01 ( l_inUserId MMEMORANDOM.SAKUSEI_ID%TYPE, l_inItakuKaishaCd MMEMORANDOM.ITAKU_KAISHA_CD%TYPE, l_inMemorandomCd MMEMORANDOM.MEMORANDOM_CD%TYPE, l_inShoriMode text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipm001k00r01_addmemorandomdsagyo ( inTypeMemoRandomdSagyo MEMORANDOM_D_SAGYO ) RETURNS integer AS $body$
DECLARE
	C_PROGRAM_ID CONSTANT text := 'SFIPM001K00R01';
	C_ERR_DUP_VAL_ON_INDEX CONSTANT integer := 2;
BEGIN
	-- 備忘録日次作業情報テーブル追加
	INSERT INTO MEMORANDOM_D_SAGYO VALUES (inTypeMemoRandomdSagyo.*);
	RETURN pkconstant.success();
EXCEPTION
WHEN unique_violation THEN
	CALL pkLog.fatal(
		'ECM323',
		SUBSTR(C_PROGRAM_ID,3,12),
		'備忘録日次作業情報（委託会社：' || inTypeMemoRandomdSagyo.ITAKU_KAISHA_CD || ' 作業日：' || inTypeMemoRandomdSagyo.SAGYO_YMD || '備忘録コード：' || inTypeMemoRandomdSagyo.MEMORANDOM_CD || '）'
	);
	RETURN C_ERR_DUP_VAL_ON_INDEX;
WHEN OTHERS THEN
	CALL pkLog.fatal('ECM701', SUBSTR(C_PROGRAM_ID,3,12), 'SQLCODE:' || SQLSTATE);
	CALL pkLog.fatal('ECM701', SUBSTR(C_PROGRAM_ID,3,12), 'SQLERRM:' || SQLERRM);
	RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipm001k00r01_addmemorandomdsagyo ( inTypeMemoRandomdSagyo RECORD ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipm001k00r01_addmemorandomdsagyorireki ( inItakuKaishaCd MEMORANDOM_D_SAGYO.ITAKU_KAISHA_CD%TYPE, inMemorandomCd MEMORANDOM_D_SAGYO.MEMORANDOM_CD%TYPE ) RETURNS integer AS $body$
DECLARE
	C_PROGRAM_ID CONSTANT text := 'SFIPM001K00R01';
	C_ERR_DUP_VAL_ON_INDEX CONSTANT integer := 2;
BEGIN
	-- 備忘録日次作業情報（履歴）テーブル追加
	INSERT INTO MEMORANDOM_D_SAGYO_RIREKI
		SELECT * FROM MEMORANDOM_D_SAGYO
		WHERE ITAKU_KAISHA_CD = inItakuKaishaCd
		AND MEMORANDOM_CD = inMemorandomCd;
	RETURN pkconstant.success();
EXCEPTION
WHEN unique_violation THEN
	CALL pkLog.fatal(
		'ECM323',
		SUBSTR(C_PROGRAM_ID,3,12),
		'備忘録日次作業情報（履歴）（委託会社：' || inItakuKaishaCd || '備忘録コード：' || inMemorandomCd || '）'
	);
	RETURN C_ERR_DUP_VAL_ON_INDEX;
WHEN OTHERS THEN
	CALL pkLog.fatal('ECM701', SUBSTR(C_PROGRAM_ID,3,12), 'SQLCODE:' || SQLSTATE);
	CALL pkLog.fatal('ECM701', SUBSTR(C_PROGRAM_ID,3,12), 'SQLERRM:' || SQLERRM);
	RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipm001k00r01_addmemorandomdsagyorireki ( inItakuKaishaCd MEMORANDOM_D_SAGYO.ITAKU_KAISHA_CD%TYPE, inMemorandomCd MEMORANDOM_D_SAGYO.MEMORANDOM_CD%TYPE ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipm001k00r01_delmemorandomdsagyo ( inItakuKaishaCd MEMORANDOM_D_SAGYO.ITAKU_KAISHA_CD%TYPE, inMemorandomCd MEMORANDOM_D_SAGYO.MEMORANDOM_CD%TYPE ) RETURNS integer AS $body$
DECLARE
	C_PROGRAM_ID CONSTANT text := 'SFIPM001K00R01';
BEGIN
	--備忘録日次作業情報レコードを削除する。
	DELETE FROM MEMORANDOM_D_SAGYO
		WHERE ITAKU_KAISHA_CD = inItakuKaishaCd
		AND MEMORANDOM_CD = inMemorandomCd;
	RETURN pkconstant.success();
EXCEPTION
WHEN OTHERS THEN
	CALL pkLog.fatal('ECM701', SUBSTR(C_PROGRAM_ID,3,12), 'SQLCODE:' || SQLSTATE);
	CALL pkLog.fatal('ECM701', SUBSTR(C_PROGRAM_ID,3,12), 'SQLERRM:' || SQLERRM);
	RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipm001k00r01_delmemorandomdsagyo ( inItakuKaishaCd MEMORANDOM_D_SAGYO.ITAKU_KAISHA_CD%TYPE, inMemorandomCd MEMORANDOM_D_SAGYO.MEMORANDOM_CD%TYPE ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfipm001k00r01_clearmemorandomdsagyo ( inTypeMemoRandomdSagyo INOUT MEMORANDOM_D_SAGYO ) AS $body$
BEGIN
	inTypeMemoRandomdSagyo.ITAKU_KAISHA_CD := NULL;     -- 委託会社コード
	inTypeMemoRandomdSagyo.SAGYO_YMD       := NULL;     -- 作業日
	inTypeMemoRandomdSagyo.MEMORANDOM_CD   := NULL;     -- 備忘録コード
	inTypeMemoRandomdSagyo.GROUP_ID        := ' ';      -- グループＩＤ
	inTypeMemoRandomdSagyo.JOKYO_KBN       := '0';      -- 状況区分
	inTypeMemoRandomdSagyo.SHORI_KBN       := ' ';      -- 処理区分
	inTypeMemoRandomdSagyo.LAST_TEISEI_DT  := NULL;     -- 最終訂正日時
	inTypeMemoRandomdSagyo.LAST_TEISEI_ID  := ' ';      -- 最終訂正者
	inTypeMemoRandomdSagyo.SHONIN_DT       := NULL;     -- 承認日時
	inTypeMemoRandomdSagyo.SHONIN_ID       := ' ';      -- 承認者
	inTypeMemoRandomdSagyo.KOUSIN_DT       := NULL;     -- 更新日時
	inTypeMemoRandomdSagyo.KOUSIN_ID       := ' ';      -- 更新者
	inTypeMemoRandomdSagyo.SAKUSEI_DT      := NULL;     -- 作成日時
	inTypeMemoRandomdSagyo.SAKUSEI_ID      := ' ';      -- 作成者
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfipm001k00r01_clearmemorandomdsagyo ( inTypeMemoRandomdSagyo INOUT RECORD ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipm001k00r01_getsagyoymd ( inStHyojiYmd MMEMORANDOM.ST_HYOJI_YMD%TYPE, inGmatsuFlg MMEMORANDOM.GMATSU_FLG%TYPE, inKyuJitsuKbn MMEMORANDOM.KYUJITSU_KBN%TYPE ) RETURNS MEMORANDOM_D_SAGYO.SAGYO_YMD%TYPE AS $body$
DECLARE

	pSagyoYmd MEMORANDOM_D_SAGYO.SAGYO_YMD%TYPE;              -- 作業日
BEGIN
	--月末フラグONの時は月末営業日にする
	IF inGmatsuFlg = '1' THEN
		pSagyoYmd := pkDate.getGetsumatsuBusinessYmd(inStHyojiYmd, 0);
	ELSE
		--作業日が休日かチェック
		IF pkDate.isBusinessDay(inStHyojiYmd) = 0 THEN
			--営業日ならそのまま
			pSagyoYmd := inStHyojiYmd;
		ELSE
			--休日なら休日処理区分により設定
			IF inKyuJitsuKbn = '1' THEN
				--前営業日設定
				pSagyoYmd := pkDate.getZenBusinessYmd(inStHyojiYmd);
			ELSIF inKyuJitsuKbn = '2' THEN
				--翌営業日設定
				pSagyoYmd := pkDate.getYokuBusinessYmd(inStHyojiYmd);
			ELSE
				--翌営業日設定・月跨ぎなら前営業日
				pSagyoYmd := pkDate.getYokuBusinessYmd(inStHyojiYmd);
				IF SUBSTR(pSagyoYmd,1,6) <> SUBSTR(inStHyojiYmd,1,6) THEN
					--翌営業日設定・月跨ぎなら前営業日
					pSagyoYmd := pkDate.getGetsumatsuBusinessYmd(inStHyojiYmd, 0);
				END IF;
			END IF;
		END IF;
	END IF;
	RETURN pSagyoYmd;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipm001k00r01_getsagyoymd ( inStHyojiYmd MMEMORANDOM.ST_HYOJI_YMD%TYPE, inGmatsuFlg MMEMORANDOM.GMATSU_FLG%TYPE, inKyuJitsuKbn MMEMORANDOM.KYUJITSU_KBN%TYPE ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipm001k00r01_makememorandomdsagyo ( inSagyoYmd character, inTypeMmemoRandom RECORD, inTypeMemoRandomdSagyo MEMORANDOM_D_SAGYO ) RETURNS MEMORANDOM_D_SAGYO AS $body$
DECLARE

	pTypeMemoRandomdSagyo MEMORANDOM_D_SAGYO%ROWTYPE;              -- 備忘録日次作業情報
BEGIN
	pTypeMemoRandomdSagyo                 := inTypeMemoRandomdSagyo;
	pTypeMemoRandomdSagyo.ITAKU_KAISHA_CD := inTypeMmemoRandom.ITAKU_KAISHA_CD;       -- 委託会社コード
	pTypeMemoRandomdSagyo.SAGYO_YMD       := inSagyoYmd;                              -- 作業日
	pTypeMemoRandomdSagyo.MEMORANDOM_CD   := inTypeMmemoRandom.MEMORANDOM_CD;         -- 備忘録コード
	pTypeMemoRandomdSagyo.GROUP_ID        := inTypeMmemoRandom.GROUP_ID;              -- グループＩＤ
	pTypeMemoRandomdSagyo.JOKYO_KBN       := '0';                                     -- 状況区分（初期値）
	pTypeMemoRandomdSagyo.SHORI_KBN       := '1';                                     -- 処理区分（承認済）
	pTypeMemoRandomdSagyo.LAST_TEISEI_DT  := to_timestamp(pkDate.getCurrentTime(),'yyyy-mm-dd HH24:MI:SS.US'); -- 最終訂正日時
	pTypeMemoRandomdSagyo.LAST_TEISEI_ID  := inTypeMmemoRandom.LAST_TEISEI_ID;        -- 最終訂正者
	pTypeMemoRandomdSagyo.SHONIN_DT       := to_timestamp(pkDate.getCurrentTime(),'yyyy-mm-dd HH24:MI:SS.US'); -- 承認日時
	pTypeMemoRandomdSagyo.SHONIN_ID       := inTypeMmemoRandom.SHONIN_ID;             -- 承認者
	pTypeMemoRandomdSagyo.KOUSIN_DT       := CURRENT_TIMESTAMP;                       -- 更新日時
	pTypeMemoRandomdSagyo.KOUSIN_ID       := inTypeMmemoRandom.KOUSIN_ID;             -- 更新者
	pTypeMemoRandomdSagyo.SAKUSEI_DT      := CURRENT_TIMESTAMP;                       -- 作成日時
	pTypeMemoRandomdSagyo.SAKUSEI_ID      := inTypeMmemoRandom.SAKUSEI_ID;            -- 作成者
	RETURN pTypeMemoRandomdSagyo;
EXCEPTION
	WHEN OTHERS THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipm001k00r01_makememorandomdsagyo ( inSagyoYmd MEMORANDOM_D_SAGYO.SAGYO_YMD%TYPE, inTypeMmemoRandom RECORD, inTypeMemoRandomdSagyo RECORD ) FROM PUBLIC;
