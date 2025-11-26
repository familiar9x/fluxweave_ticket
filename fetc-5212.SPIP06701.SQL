




CREATE OR REPLACE PROCEDURE spip06701 ( 
	l_inUserId TEXT,		-- ユーザーID
	l_inItakuKaishaCd TEXT,		-- 委託会社コード
	l_inKijunYmdF TEXT,		-- 基準日(FROM)
	l_inHktCd TEXT,		-- 発行体コード
	l_inKozaTenCd TEXT,		-- 口座店コード
	l_inKozaTenCifCd TEXT,		-- 口座店CIFコード
	l_inTsuchiYmd TEXT,		-- 通知日
	l_outSqlCode OUT integer,		-- リターン値
	l_outSqlErrM OUT TEXT	-- エラーコメント
 ) AS $body$
DECLARE

--
--/* 著作権:Copyright(c)2007
--/* 会社名:JIP
--/* 概要　:顧客宛帳票出力指示画面の入力条件により、債券残高証明書を作成する。
--/*
--/* @author ASK
--/* @version $Id: SPIP06701.SQL,v 1.26 2007/10/23 04:30:57 ogata Exp $
--/*
--/* @parama  l_inUserId			IN	CHAR,		-- ユーザーID
--/* @parama  l_inItakuKaishaCd	IN	CHAR,		-- 委託会社コード
--/* @parama  l_inKijunYmdF		IN	CHAR,		-- 基準日(FROM)
--/* @parama  l_inHktCd			IN	CHAR,		-- 発行体コード
--/* @parama  l_inKozaTenCd		IN	CHAR,		-- 口座店コード
--/* @parama  l_inKozaTenCifCd	IN	CHAR,		-- 口座店CIFコード
--/* @parama  l_inTsuchiYmd		IN	CHAR,		-- 通知日
--/* @parama  l_outSqlCode		OUT	NUMBER,		-- リターン値
--/* @parama  l_outSqlErrM		OUT	VARCHAR2	-- エラーコメント
--/* @return	なし
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*	2007.10.11	Nakayama(ASK)	新規作成（元々のspIp06701はspIp06701_01へ）
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
	RTN_OK				CONSTANT integer		:= 0;				-- 正常
	RTN_NG				CONSTANT integer		:= 1;				-- 予期したエラー
	RTN_NODATA			CONSTANT integer		:= 2;				-- データなし
	RTN_FATAL			CONSTANT integer		:= 99;				-- 予期せぬエラー
	SP_ID				CONSTANT char(9)		:= 'SPIP06701';		-- ストアドID
	REPORT_ID			CONSTANT char(11)		:= 'IP030006711';	-- 帳票ID
	OPTION_CD			CONSTANT char(10)		:= 'SPIP067010';	-- オプションコード
	
--==============================================================================
--					変数定義													
--==============================================================================
	gSpId				char(11);									-- SPID
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
--	IF DEBUG = 1 THEN	pkLog.debug(l_inUserId, REPORT_ID, SP_ID || ' START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	THEN
		-- パラメータエラー
--		IF DEBUG = 1 THEN	pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := 'パラメータエラー';
		CALL pkLog.error('ECM501', REPORT_ID, 'SQLERRM:'||'');
		RETURN;
	END IF;
	IF pkControl.getCtlValue(l_inItakuKaishaCd, OPTION_CD, '0') = '1' THEN
--		IF DEBUG = 1 THEN	pkLog.debug(l_inUserId, REPORT_ID, 'spIp06701_02(カスタマイズ版) START');	END IF;
		-- 子銘柄合算対応カスタマイズ版
		CALL spIp06701_02(l_inUserId
					,l_inItakuKaishaCd
					,l_inKijunYmdF
					,l_inHktCd
					,l_inKozaTenCd
					,l_inKozaTenCifCd
					,l_inTsuchiYmd
					,l_outSqlCode
					,l_outSqlErrM);
--		IF DEBUG = 1 THEN	pkLog.debug(l_inUserId, REPORT_ID, 'spIp06701_02(カスタマイズ版) END');	END IF;
	ELSE
--		IF DEBUG = 1 THEN	pkLog.debug(l_inUserId, REPORT_ID, 'spIp06701_01(パッケージ版) START');	END IF;
		-- パッケージ版
		CALL spIp06701_01(l_inUserId
					,l_inItakuKaishaCd
					,l_inKijunYmdF
					,l_inHktCd
					,l_inKozaTenCd
					,l_inKozaTenCifCd
					,l_inTsuchiYmd
					,l_outSqlCode
					,l_outSqlErrM);
--		IF DEBUG = 1 THEN	pkLog.debug(l_inUserId, REPORT_ID, 'spIp06701_01(パッケージ版) END');	END IF;
	END IF;
--	IF DEBUG = 1 THEN	pkLog.debug(l_inUserId, REPORT_ID, SP_ID || ' END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		CALL pkLog.fatal('ECM701', SP_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal('ECM701', SP_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip06701 ( l_inUserId CHAR, l_inItakuKaishaCd CHAR, l_inKijunYmdF CHAR, l_inHktCd CHAR, l_inKozaTenCd CHAR, l_inKozaTenCifCd CHAR, l_inTsuchiYmd CHAR, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;