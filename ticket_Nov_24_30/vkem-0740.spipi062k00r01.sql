




CREATE OR REPLACE PROCEDURE spipi062k00r01 ( 
	l_inKijunYm TEXT,			--基準年月
 l_inEigyotenCd TEXT,		--営業店コード
 l_inItakuKaishaCd TEXT,		--委託会社コード
 l_inUserId TEXT,		--ユーザーID
 l_inChohyoKbn TEXT,		--帳票区分
 l_inGyomuYmd TEXT,		--業務日付
 l_outSqlCode OUT integer,		--リターン値
 l_outSqlErrM OUT text	--エラーコメント
 ) AS $body$
DECLARE

--
--/* 著作権:Copyright(c)2005
--/* 会社名:JIP
--/* 概要　:営業店別手数料予定表出力指示画面の入力条件により、営業店別手数料予定表を作成する。
--/*		期中手数料パッケージ呼び出しを行い、パラメータで指定した銘柄情報を抽出し、
--/*		取得レコードを編集した結果を手数料計算結果テーブルに更新する。
--/* 引数　:l_inKijunYm		IN	CHAR		基準年月
--/* 　　　 l_inEigyotenCd	IN	CHAR		営業店コード
--/* 　　　 l_inItakuKaishaCd IN	CHAR		委託会社コード
--/* 　　　 l_inUserId		IN	CHAR		ユーザーID
--/* 　　　 l_inChohyoKbn		IN	CHAR		帳票区分
--/* 　　　 l_inGyomuYmd		IN	CHAR		業務日付
--/* 　　　 l_outSqlCode		OUT INTEGER		リターン値
--/* 　　　 l_outSqlErrM		OUT VARCHAR2	エラーコメント
--/* 返り値:なし
--/* @version $Id: SPIPI062K00R01.SQL,v 1.4 2006/10/03 08:30:29 yamashita Exp $
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/*	-------------------------------------------------------------------
--/*　2005.10.24	海老澤　智(ASK) 新規作成
--/*
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
	RTN_OK				CONSTANT integer	:= 0;						--正常
	RTN_NG				CONSTANT integer	:= 1;						--予期したエラー
	RTN_FATAL			CONSTANT integer	:= 99;						--予期せぬエラー
	CHOHYO_ID			CONSTANT char(11)	:= 'IPI30006211';			--帳票ID
	SP_NAME				CONSTANT char(14)	:= 'SPIPI062K00R01';		--帳票名
	
--==============================================================================
--					変数定義													
--==============================================================================
	gRtnCd				integer := RTN_OK;							--リターンコード
	pReturnCode		 integer := RTN_OK;							--リターンコード(パッケージ戻り値)
	gKijunYmdFrom		MGR_RBRKIJ.RBR_KJT%TYPE;						--基準年月日From
	gKijunYmdTo		 MGR_RBRKIJ.RBR_KJT%TYPE;							--基準年月日To
	
--==============================================================================
--					カーソル定義													
--==============================================================================
	curMeisai CURSOR FOR
		SELECT MG4.ITAKU_KAISHA_CD,
				MG4.MGR_CD,
				MG4.TESU_SHURUI_CD,
				MG4.CHOKYU_YMD
		FROM MGR_TESKIJ MG4,
			 MGR_STS	MG0,
			 MGR_KIHON	MG1,
			 MHAKKOTAI	M01
		WHERE MG4.CHOKYU_YMD BETWEEN gKijunYmdFrom AND gKijunYmdTo
			AND MG4.TESU_SHURUI_CD IN ('11', '12')
			AND MG0.MGR_STAT_KBN = '1'
			AND MG0.MASSHO_FLG = '0'
			AND (trim(both MG1.ISIN_CD) IS NOT NULL AND (trim(both MG1.ISIN_CD))::text <> '')
			AND (M01.EIGYOTEN_CD = l_inEigyotenCd OR coalesce(trim(both l_inEigyotenCd)::text, '') = '')
			AND MG4.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
			AND MG4.MGR_CD = MG0.MGR_CD
			AND MG1.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
			AND MG1.MGR_CD = MG0.MGR_CD
			AND MG1.HKT_CD = M01.HKT_CD
			AND MG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
			-- 請求書出力可能な場合のみ(併存銘柄出力チェック)
			AND	PKIPACALCTESURYO.checkHeizonMgr(
							  MG4.ITAKU_KAISHA_CD
							, MG4.MGR_CD
							, PKDATE.GETZENGETSUMATSUBUSINESSYMD(MG4.CHOKYU_KJT)	--徴求期日の前月末時点
							, '1') = 0;
--==============================================================================
--	メイン処理 
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN
		CALL pkLog.debug(l_inUserId, SP_NAME, CHOHYO_ID || ' START');
		CALL pkLog.debug(l_inUserId, CHOHYO_ID, 'param error 基準年月:' || l_inKijunYm);
		CALL pkLog.debug(l_inUserId, CHOHYO_ID, 'param error 委託会社コード:' || l_inItakuKaishaCd);
		CALL pkLog.debug(l_inUserId, CHOHYO_ID, 'param error ユーザID:' || l_inUserId);
		CALL pkLog.debug(l_inUserId, CHOHYO_ID, 'param error 帳票区分:' || l_inChohyoKbn);
		CALL pkLog.debug(l_inUserId, CHOHYO_ID, 'param error 業務日付:' || l_inGyomuYmd);
	END IF;
	--入力パラメータのチェック
	IF coalesce(trim(both l_inKijunYm)::text, '') = ''
	OR coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inUserId)::text, '') = ''
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''
	OR coalesce(trim(both l_inGyomuYmd)::text, '') = ''
	THEN
		--入力パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, CHOHYO_ID, 'param error');END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error(l_inUserId, CHOHYO_ID, 'SQLERRM:' || '');
		RETURN;
	END IF;
	--基準年月から、基準年月日From-Toをセット
	gKijunYmdFrom	:= l_inKijunYm || '00';
	gKijunYmdTo		:= l_inKijunYm || '99';
	-- データ取得
	FOR rec IN curMeisai LOOP
		EXIT WHEN NOT FOUND;/* apply on curMeisai */
		pReturnCode := pkIpaKichuTesuryo.updateKichuTesuryoTbl(
			l_initakukaishacd	=> rec.ITAKU_KAISHA_CD,	--委託会社コード
			l_inmgrcd			=> rec.MGR_CD,			--銘柄コード
			l_intesucd			=> rec.TESU_SHURUI_CD,	--手数料種類コード
			l_indate			=> rec.CHOKYU_YMD,		--徴求日
			l_injobkbn			=> 0					--データ作成区分
		);
		--パッケージファンクションでエラーが発生していたらエラーを返す
		IF pReturnCode <> 0 THEN
			l_outSqlCode := RTN_NG;
			l_outSqlErrM := '';
			CALL pkLog.error('ECM701', SP_NAME, 'エラーメッセージ：' || l_OutSqlCode);
			CALL pkLog.error('ECM701', SP_NAME, 'エラーメッセージ：' || l_OutSqlErrM);
			RETURN;
		END IF;
	END LOOP;
	--営業店別手数料予定表出力指示画面の入力条件により、営業店別手数料予定表を作成する
	CALL SPIPI062K00R01_01(
					 l_inKijunYm,				--基準年月
					 l_inEigyotenCd,			--営業店コード
					 l_inItakuKaishaCd,			--委託会社コード
					 l_inUserId,				--ユーザーID
					 l_inChohyoKbn,				--帳票区分
					 l_inGyomuYmd,				--業務日付
					 l_outSqlCode,				--リターン値
					 l_outSqlErrM 				--エラーコメント
					 );
	--プロシージャでエラーが発生していたらエラーを返す
	IF coalesce(l_OutSqlCode, 0) <> 0 AND coalesce(l_OutSqlCode, 0) <> 2 THEN
		CALL pkLog.error('ECM701', SP_NAME, 'エラーメッセージ：' || l_OutSqlCode);
		CALL pkLog.error('ECM701', SP_NAME, 'エラーメッセージ：' || l_OutSqlErrM);
		RETURN;
	ELSE
		gRtnCd := l_OutSqlCode;
	END IF;
	--終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, SP_NAME , CHOHYO_ID || ' END');END IF;
--エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SP_NAME, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', SP_NAME, 'SQLERRM:' || SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipi062k00r01 ( l_inKijunYm CHAR, l_inEigyotenCd CHAR, l_inItakuKaishaCd CHAR, l_inUserId CHAR, l_inChohyoKbn CHAR, l_inGyomuYmd CHAR, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;