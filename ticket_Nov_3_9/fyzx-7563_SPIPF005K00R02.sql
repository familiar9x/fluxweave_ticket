/**
 * 著作権:Copyright(c)2004
 * 会社名:JIP
 * 概要　:金融機関支店マスタの内容を出力する。
 * 引数　:l_inItakuKaishaCd	IN	VARCHAR		委託会社コード
 * 　　　 l_inUserId		IN	VARCHAR		ユーザーID
 * 　　　 l_inChohyoKbn		IN	VARCHAR		帳票区分
 * 　　　 l_inChohyoSakuKbn	IN	VARCHAR		帳票作成区分
 * 　　　 l_inGyomuYmd		IN	VARCHAR		業務日付
 * 　　　 l_outSqlCode		OUT	NUMERIC		リターン値
 * 　　　 l_outSqlErrM		OUT	TEXT		エラーコメント
 * 返り値:なし
 * @version $Revision: 1.4 $
 */

CREATE OR REPLACE PROCEDURE spipf005k00r02 (
	l_inItakuKaishaCd VARCHAR,		-- 委託会社コード
	l_inUserId VARCHAR,				-- ユーザーID
	l_inChohyoKbn VARCHAR,			-- 帳票区分
	l_inChohyoSakuKbn VARCHAR,		-- 帳票作成区分
	l_inGyomuYmd VARCHAR,			-- 業務日付
	l_outSqlCode OUT numeric,		-- リターン値
	l_outSqlErrM OUT text			-- エラーコメント
) AS $body$
DECLARE
--==============================================================================
--					デバッグ機能													
--==============================================================================
	DEBUG	numeric(1)	:= 0;
--==============================================================================
--					定数定義													
--==============================================================================
	RTN_OK				CONSTANT integer	:= 0;					-- 正常
	RTN_NG				CONSTANT integer	:= 1;					-- 予期したエラー
	RTN_NODATA			CONSTANT integer	:= 40;					-- データなし
	RTN_FATAL			CONSTANT integer	:= 99;					-- 予期せぬエラー
	REPORT_ID			CONSTANT char(11)	:= 'IPF30000521';	-- 帳票ID
--==============================================================================
--					変数定義													
--==============================================================================
	gRtnCd				integer :=	RTN_OK;						-- リターンコード
	gSeqNo				integer := 0;							-- シーケンス
--==============================================================================
--					カーソル定義													
--==============================================================================
	curMeisai CURSOR FOR
		SELECT	M03.FINANCIAL_SECURITIES_KBN,					-- 金融機関証券区分
				SC04.CODE_RNM,									-- 金融機関証券区分略称
				M03.BANK_CD,									-- 金融機関コード
				M03.SHITEN_CD,									-- 支店コード
				M03.SHITEN_NM,									-- 支店名称
				M03.SHITEN_RNM,									-- 支店略称
				M03.SHITEN_KANA_RNM 							-- 支店略称(カナ)
		FROM mbank_shiten m03
		LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = '507') sc04 
			ON (M03.FINANCIAL_SECURITIES_KBN = SC04.CODE_VALUE)
		WHERE TO_CHAR(M03.SAKUSEI_DT, 'yyyymmdd') = l_inGyomuYmd 
		AND M03.SAKUSEI_ID = l_inUserId 
		ORDER BY M03.FINANCIAL_SECURITIES_KBN,
				 M03.BANK_CD,
				 M03.SHITEN_CD;
	
	curCount CURSOR FOR
		SELECT 	COUNT(*) AS CNT
		FROM	PRT_OK	S05
		WHERE	S05.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND		S05.KIJUN_YMD = l_inGyomuYmd
		AND		S05.LIST_SAKUSEI_KBN = l_inChohyoSakuKbn
		AND		S05.CHOHYO_ID = REPORT_ID;
	
	recMeisai RECORD;
	recCount RECORD;
	l_inItem TYPE_SREPORT_WK_ITEM;
	
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	
		CALL pkLog.debug(l_inUserId, REPORT_ID, 'IPF005K00R02 START');	
	END IF;
	
	-- 入力パラメタ(委託会社コード)のチェック
	IF coalesce(trim(l_inItakuKaishaCd), '') = '' THEN
		IF DEBUG = 1 THEN	
			CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	
		END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF005K00R02', '＜項目名称:委託会社コード＞'||'＜項目値:'||l_inItakuKaishaCd||'＞');
		RETURN;
	END IF;
	
	-- 入力パラメタ(ユーザＩＤ)のチェック
	IF coalesce(trim(l_inUserId), '') = '' THEN
		IF DEBUG = 1 THEN	
			CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	
		END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF005K00R02', '＜項目名称:ユーザＩＤ＞'||'＜項目値:'||l_inUserId||'＞');
		RETURN;
	END IF;
	
	-- 入力パラメタ(帳票区分)のチェック
	IF coalesce(trim(l_inChohyoKbn), '') = '' THEN
		IF DEBUG = 1 THEN	
			CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	
		END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF005K00R02', '＜項目名称:帳票区分＞'||'＜項目値:'||l_inChohyoKbn||'＞');
		RETURN;
	END IF;
	
	-- 入力パラメタ(帳票作成区分)のチェック
	IF coalesce(trim(l_inChohyoSakuKbn), '') = '' THEN
		IF DEBUG = 1 THEN	
			CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	
		END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF005K00R02', '＜項目名称:帳票作成区分＞'||'＜項目値:'||l_inChohyoSakuKbn||'＞');
		RETURN;
	END IF;
	
	-- 入力パラメタ(業務日付)のチェック
	IF coalesce(trim(l_inGyomuYmd), '') = '' THEN
		IF DEBUG = 1 THEN	
			CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	
		END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF005K00R02', '＜項目名称:業務日付＞'||'＜項目値:'||l_inGyomuYmd||'＞');
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
		gSeqNo := gSeqNo + 1;
		
		-- Initialize composite type
		l_inItem := ROW();
		l_inItem.l_inItem001 := l_inGyomuYmd;
		l_inItem.l_inItem002 := recMeisai.FINANCIAL_SECURITIES_KBN;
		l_inItem.l_inItem003 := recMeisai.CODE_RNM;
		l_inItem.l_inItem004 := recMeisai.BANK_CD;
		l_inItem.l_inItem005 := recMeisai.SHITEN_CD;
		l_inItem.l_inItem006 := recMeisai.SHITEN_NM;
		l_inItem.l_inItem007 := recMeisai.SHITEN_RNM;
		l_inItem.l_inItem008 := recMeisai.SHITEN_KANA_RNM;
		l_inItem.l_inItem009 := REPORT_ID;
		
		-- 帳票ワークへデータを追加
		CALL pkPrint.insertData(
			l_inKeyCd			=>	l_inItakuKaishaCd,				-- 識別コード
			l_inUserId			=>	'BATCH',						-- ユーザＩＤ
			l_inChohyoKbn		=>	l_inChohyoKbn,					-- 帳票区分
			l_inSakuseiYmd		=>	l_inGyomuYmd,					-- 作成年月日
			l_inChohyoId		=>	REPORT_ID,						-- 帳票ＩＤ
			l_inSeqNo			=>	gSeqNo,							-- 連番
			l_inHeaderFlg		=>	'1',							-- ヘッダフラグ
			l_inItem			=>	l_inItem,						-- アイテム
			l_inKousinId		=>	l_inUserId,						-- 更新者ID
			l_inSakuseiId		=>	l_inUserId						-- 作成者ID
		);
	END LOOP;
	
	IF gSeqNo = 0 THEN
		-- 対象データなし
		gRtnCd := RTN_NODATA;
	END IF;
	
	-- バッチ帳票印刷管理への登録
	FOR recCount IN curCount LOOP
		IF recCount.CNT = 0 THEN
			INSERT INTO PRT_OK(
				ITAKU_KAISHA_CD,				-- 委託会社コード
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
			VALUES (
				l_inItakuKaishaCd,
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
	
	IF DEBUG = 1 THEN	
		CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	
	END IF;
	IF DEBUG = 1 THEN	
		CALL pkLog.debug(l_inUserId, REPORT_ID, 'IPF005K00R02 END');	
	END IF;
	
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'IPF005K00R02', 'SQLERRM:'||SQLERRM||'('||SQLSTATE||')');
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
END;
$body$
LANGUAGE PLPGSQL;
