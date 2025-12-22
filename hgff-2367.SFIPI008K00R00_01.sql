




CREATE OR REPLACE FUNCTION sfipi008k00r00_01 ( l_inItakuKaishaCd TEXT ) RETURNS numeric AS $body$
DECLARE

--
--/* 著作権：Copyright(c)2005
--/* 会社名：JIP
-- *
-- * @version $Revision: 1.3 $
-- *
--/* 概要　：夜間バッチの処理「日次帳票作成」SFより受けたInパラメータより、
--/* 　　　　作表対象データを検出し、対象データありのときには
--/* 　　　　各新規記録入金予定データ作成のSPをコールして処理をおこなう。
--/* 引数　：l_inItakuKaishaCd	IN	TEXT		委託会社コード
--/* 返り値：リターン値
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/* 2005/05/26	野下　勲		新規作成
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
	USER_ID				CONSTANT text	:= pkconstant.BATCH_USER();	-- ユーザー名
	PROGRAM_ID			CONSTANT text		:= 'IPI008K00R00';		-- プログラムID
	CHOHYO_KBN			CONSTANT text		:= '1';						-- 帳票区分(1：バッチ)
	LIST_SAKUSEI_KBN	CONSTANT text		:= '1';						-- 作成区分(1：日次)
	MSG_ID				CONSTANT text		:= 'ECM602';				-- エラーメッセージID
	RTN_FATAL			CONSTANT integer		:= 99;						-- エラー
--==============================================================================
--					変数定義													
--==============================================================================
	wk_gyomu_ymd		char(8)				:= null;			-- 業務日付
	wk_base_ymd			char(8)				:= null;			-- 基準日
	wk_nyukin_yotei_dd	numeric				:= null;			-- 当預RTGS入金予定日付
	wk_count			numeric				:= 0;				-- 対象データ件数
	wk_sqlCode			numeric				:= 0;				-- 戻り値取得用
	wk_sqlErrM			varchar(100)		:= '';				-- 戻り値取得用
	wk_rtn_cd			numeric :=		0;					-- エラーフラグ
	

--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, PROGRAM_ID, PROGRAM_ID || 'START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, PROGRAM_ID, 'param error');	END IF;
		CALL pkLog.error(MSG_ID, PROGRAM_ID, 'SQLERRM:'||'');
		RETURN RTN_FATAL;
	END IF;
	-- 業務日付の取得
	wk_gyomu_ymd := pkDate.getGyomuYmd();
	-- 基準日の取得
	SELECT
		rtgs_nyukin_yotei_dd
	INTO STRICT
		wk_nyukin_yotei_dd
	FROM
		vjiko_itaku
	WHERE
		kaiin_id = l_inItakuKaishaCd;
	wk_base_ymd := pkDate.getPlusDateBusiness(wk_gyomu_ymd, wk_nyukin_yotei_dd::integer);
	-- 新規記録入金予定作表対象データ件数取得
	SELECT
		count(*)
	INTO
		wk_count
	FROM
		nyukin_yotei
	WHERE
		itaku_kaisha_cd = l_inItakuKaishaCd AND
		kessai_ymd = wk_base_ymd;
	IF wk_count > 0 THEN
		-- 新規記録資金入金予定表(銘柄別)作表処理SPをcall
		CALL SPIP00801(wk_base_ymd, wk_base_ymd, l_inItakuKaishaCd, USER_ID,
					CHOHYO_KBN, wk_gyomu_ymd, wk_sqlCode, wk_sqlErrM);
		-- バッチ帳票印刷管理テーブルにデータを登録
		IF wk_sqlCode = 0 OR wk_sqlCode = 2 THEN
			CALL pkPrtOk.insertPrtOk(
				USER_ID, l_inItakuKaishaCd, pkDate.getGyomuYmd(), LIST_SAKUSEI_KBN, 'IP030000811');
		ELSE
			wk_rtn_cd := RTN_FATAL;
		END IF;
		-- 新規記録資金入金予定表(資金決済会社別)作表処理SPをcall
		CALL SPIP00802(wk_base_ymd, wk_base_ymd, l_inItakuKaishaCd, USER_ID,
					CHOHYO_KBN, wk_gyomu_ymd, wk_sqlCode, wk_sqlErrM);
		-- バッチ帳票印刷管理テーブルにデータを登録
		IF wk_sqlCode = 0 OR wk_sqlCode = 2 THEN
			CALL pkPrtOk.insertPrtOk(
				USER_ID, l_inItakuKaishaCd, pkDate.getGyomuYmd(), LIST_SAKUSEI_KBN, 'IP030000821');
		ELSE
			wk_rtn_cd := RTN_FATAL;
		END IF;
	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, PROGRAM_ID, PROGRAM_ID || ' END');	END IF;
	-- 終了処理
	RETURN wk_rtn_cd;
-- 例外処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal(MSG_ID, PROGRAM_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal(MSG_ID, PROGRAM_ID, 'SQLERRM:'||SQLERRM);
		RETURN RTN_FATAL;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi008k00r00_01 ( l_inItakuKaishaCd TEXT ) FROM PUBLIC;