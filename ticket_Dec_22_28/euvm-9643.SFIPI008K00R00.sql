




CREATE OR REPLACE FUNCTION sfipi008k00r00 () RETURNS numeric AS $body$
DECLARE

--
--/* 著作権：Copyright(c)2005
--/* 会社名：JIP
-- *
-- * @version $Revision: 1.4 $
-- *
--/* 概要　：夜間バッチとして起動する、日次帳票の作成処理をおこなうPGを
--/* 　　　　コールする親SF。
--/* 引数　：なし
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
	USER_ID			CONSTANT text		:= pkconstant.BATCH_USER();	-- ユーザーID
	PROGRAM_ID		CONSTANT text	:= 'IPI008K00R00';		-- プログラムID
	RTN_FATAL		CONSTANT numeric			:= 99;						-- エラー
	MSG_ID			CONSTANT text		:= 'ECM602';				-- エラーメッセージID
--==============================================================================
--					変数定義													
--==============================================================================
	wk_sqlCd		numeric					:= 0;			-- エラーコード
	return_cd		numeric	:=			0;				-- リターン値
	gSeqNo			numeric	:= 		0;				-- シーケンス(デバッグ用)
	
	-- 委託会社コード取得用カーソル
	itaku_kaisha_cur CURSOR FOR
	SELECT
		kaiin_id
	FROM
		vjiko_itaku;
	-- レコード型変数
	itaku_kaisha_rectype		RECORD;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	-- レコードがなくなるまでループ
	FOR itaku_kaisha_rectype IN itaku_kaisha_cur LOOP
		-- 各帳票作成SPをcall
		-- 新規記録入金予定表データ作成
		wk_sqlCd := SFIPI008K00R00_01(itaku_kaisha_rectype.kaiin_id);
		--対象データなしの場合、正常終了（但し、デバッグログを書き出す）
		IF wk_sqlCd = PKIPACALCTESURYO.C_NODATA() THEN
			wk_sqlCd := pkconstant.success();
			CALL pkLog.debug('Batch', 'SFIPI008K00R00', '委託会社：' || itaku_kaisha_rectype.kaiin_id || ' 対象データなし');
		END IF;
		IF wk_sqlCd <> 0 THEN
			return_cd := RTN_FATAL;
		END IF;
		gSeqNo := gSeqNo + 1;
	END LOOP;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, PROGRAM_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	RETURN return_cd;
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal(MSG_ID, PROGRAM_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal(MSG_ID, PROGRAM_ID, 'SQLERRM:'||SQLERRM);
		RETURN RTN_FATAL;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi008k00r00 () FROM PUBLIC;