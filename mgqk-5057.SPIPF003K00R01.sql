




CREATE OR REPLACE PROCEDURE spipf003k00r01 ( l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inUserId text,	-- ユーザーID
 l_inChohyoKbn TEXT,		-- 帳票区分
 l_inChohyoSakuKbn TEXT,		-- 帳票作成区分
 l_inGyomuYmd TEXT,		-- 業務日付
 l_outSqlCode OUT integer,		-- リターン値
 l_outSqlErrM OUT TEXT 		-- エラーコメント
 ) AS $body$
DECLARE

--
--/* 著作権:Copyright(c)2004
--/* 会社名:JIP
--/* 概要　:部店マスタの内容を出力する。
--/* 引数　:l_inItakuKaishaCd	IN	TEXT		委託会社コード
--/* 　　　 l_inUserId		IN	TEXT		ユーザーID
--/* 　　　 l_inChohyoKbn		IN	TEXT		帳票区分
--/* 　　　 l_inChohyoSakuKbn	IN	TEXT		帳票作成区分
--/* 　　　 l_inGyomuYmd		IN	TEXT		業務日付
--/* 　　　 l_outSqlCode		OUT	INTEGER		リターン値
--/* 　　　 l_outSqlErrM		OUT	VARCHAR	エラーコメント
--/* 返り値:なし
--/* @version $Revision: 1.4 $
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.05.09	JIP				新規作成
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
	RTN_OK				CONSTANT integer	:= 0;						-- 正常
	RTN_NG				CONSTANT integer	:= 1;						-- 予期したエラー
	RTN_NODATA			CONSTANT integer	:= 40;						-- データなし
	RTN_FATAL			CONSTANT integer	:= 99;						-- 予期せぬエラー
																		-- 突合エラー
	REPORT_ID			CONSTANT char(11)	:= 'IPF30000311';			--帳票ID
--==============================================================================
--					変数定義													
--==============================================================================
	gRtnCd				integer :=	RTN_OK;							-- リターンコード
	gSeqNo				integer := 0;								-- シーケンス
	CNT					numeric	:= 0;
	v_item				type_sreport_wk_item;						-- アイテム pack用	
--==============================================================================
--					カーソル定義													
--==============================================================================
	curMeisai CURSOR FOR
		SELECT	M04.BUTEN_CD,								--部店CD
				M04.BUTEN_NM,								--部店名称
				M04.BUTEN_RNM,								--部店名略称
				M04.GROUP_CD,								--グループCD
				M04.POST_NO,								--郵便番号
				M04.ADD1,									--住所1
				M04.ADD2,									--住所2
				M04.ADD3,									--住所3
				M04.BUSHO_NM,								--担当部署名称
				M04.TEL_NO,									--電話番号
				M04.FAX_NO,									--FAX番号
				M04.MAIL_ADD 								--メールアドレス
		FROM 	MBUTEN 	M04
		WHERE 	M04.ITAKU_KAISHA_CD = l_inItakuKaishaCd	
		AND   	TO_CHAR(M04.SAKUSEI_DT, 'yyyymmdd') = l_inGyomuYmd
		AND   	M04.SAKUSEI_ID = l_inUserId
		ORDER BY M04.BUTEN_CD;
	curCount CURSOR FOR
		SELECT 	COUNT(*) AS CNT
		FROM	PRT_OK	S05
		WHERE	S05.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND		S05.KIJUN_YMD = l_inGyomuYmd
		AND		S05.LIST_SAKUSEI_KBN = l_inChohyoSakuKbn
		AND		S05.CHOHYO_ID = REPORT_ID;
--FETCHするためのパラメータ
recMeisai	RECORD;			--部店カーソル
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'IPF003K00R01 START');	END IF;
	-- 入力パラメタ(委託会社コード)のチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF003K00R01', '＜項目名称:委託会社コード＞'||'＜項目値:'||l_inItakuKaishaCd||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(ユーザＩＤ)のチェック
	IF coalesce(trim(both l_inUserId)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF003K00R01', '＜項目名称:ユーザＩＤ＞'||'＜項目値:'||l_inUserId||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(帳票区分)のチェック
	IF coalesce(trim(both l_inChohyoKbn)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF003K00R01', '＜項目名称:帳票区分＞'||'＜項目値:'||l_inChohyoKbn||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(帳票作成区分)のチェック
	IF coalesce(trim(both l_inChohyoKbn)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF003K00R01', '＜項目名称:帳票作成区分＞'||'＜項目値:'||l_inChohyoSakuKbn||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(業務日付)のチェック
	IF coalesce(trim(both l_inGyomuYmd)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF003K00R01', '＜項目名称:業務日付＞'||'＜項目値:'||l_inGyomuYmd||'＞');
		RETURN;
	END IF;
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = 'BATCH'
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, 'BATCH', l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	FOR recMeisai IN curMeisai LOOP
		gSeqNo := gSeqNo +1;
		
		-- Clear toàn bộ item
		v_item := ROW();
		
		-- Pack data vào composite type
		v_item.l_inItem001 := l_inGyomuYmd;
		v_item.l_inItem002 := recMeisai.BUTEN_CD;
		v_item.l_inItem003 := recMeisai.BUTEN_NM;
		v_item.l_inItem004 := recMeisai.BUTEN_RNM;
		v_item.l_inItem005 := recMeisai.GROUP_CD;
		v_item.l_inItem006 := recMeisai.POST_NO;
		v_item.l_inItem007 := recMeisai.ADD1;
		v_item.l_inItem008 := recMeisai.ADD2;
		v_item.l_inItem009 := recMeisai.ADD3;
		v_item.l_inItem010 := recMeisai.BUSHO_NM;
		v_item.l_inItem011 := recMeisai.TEL_NO;
		v_item.l_inItem012 := recMeisai.FAX_NO;
		v_item.l_inItem013 := recMeisai.MAIL_ADD;
		v_item.l_inItem014 := REPORT_ID;
		
		-- 帳票ワークへデータを追加
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> 'BATCH',
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> 1,
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	END LOOP;
	IF gSeqNo = 0 THEN
	--対象データなし
		gRtnCd := RTN_NODATA;
	END IF;
	--バッチ帳票印刷管理への登録
	--バッチ帳票印刷管理が存在しない場合
	FOR recCount IN curCount LOOP
		IF recCount.CNT = 0 THEN
			INSERT INTO PRT_OK(ITAKU_KAISHA_CD,				-- 委託会社コード
				KIJUN_YMD,						-- 基準日
				LIST_SAKUSEI_KBN,				-- 帳票作成区分
				CHOHYO_ID,						-- 帳票ＩＤ
				SHORI_KBN,						-- 処理区分
				LAST_TEISEI_DT,					-- 最終訂正日時
				LAST_TEISEI_ID,					-- 最終訂正者
				SHONIN_DT,						-- 承認日時
				SHONIN_ID,						-- 承認者
				KOUSIN_DT,						-- 更新日時
				KOUSIN_ID,						-- 更新者
				SAKUSEI_DT,						-- 作成日時
				SAKUSEI_ID 						-- 作成者
				)
				VALUES (l_inItakuKaishaCd,
				l_inGyomuYmd,
				l_inChohyoSakuKbn,
				REPORT_ID,
				'1',							-- 承認
				clock_timestamp(),
				l_inUserId,
				clock_timestamp(),
				l_inUserId,
				clock_timestamp(),
				l_inUserId,
				clock_timestamp(),
				l_inUserId
			);
		END IF;
	END LOOP;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'IPF003K00R01 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		CALL pkLog.fatal('ECM701', 'IPF003K00R01', 'SQLERRM:'||SQLERRM||'('||SQLSTATE||')');
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
--		RAISE;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipf003k00r01 ( l_inItakuKaishaCd TEXT, l_inUserId text, l_inChohyoKbn TEXT, l_inChohyoSakuKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT TEXT  ) FROM PUBLIC;