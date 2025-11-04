CREATE OR REPLACE PROCEDURE spipf005k00r01 (
	l_inItakuKaishaCd CHAR,		-- 委託会社コード
	l_inUserId CHAR,		-- ユーザーID
	l_inChohyoKbn CHAR,		-- 帳票区分
	l_inChohyoSakuKbn CHAR,		-- 帳票作成区分
	l_inGyomuYmd CHAR,		-- 業務日付
	l_outSqlCode OUT numeric,		-- リターン値
	l_outSqlErrM OUT text	-- エラーコメント
) AS $body$
DECLARE

/**
 * 著作権:Copyright(c)2004
 * 会社名:JIP
 * 概要　:金融機関マスタの内容を出力する。
 * 引数　:l_inItakuCode		IN	CHAR		委託会社コード
 *		  l_inUserId		IN	CHAR		ユーザーID
 * 　　　 l_inChohyoKbn		IN	CHAR		帳票区分
 *		  l_inChohyoSakuKbn	IN	CHAR		帳票作成区分
 * 　　　 l_inGyomuYmd		IN	CHAR		業務日付
 * 　　　 l_outSqlCode		OUT	INTEGER		リターン値
 * 　　　 l_outSqlErrM		OUT	VARCHAR2	エラーコメント
 * 返り値:なし
 * @version $Revision: 1.4 $
 *
 ***************************************************************************
 * ログ　:
 * 　　　日付	開発者名		目的
 * -------------------------------------------------------------------
 *　2005.05.09	JIP				新規作成
 *
 ***************************************************************************
 */
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
	REPORT_ID			CONSTANT char(11)	:= 'IPF30000511';			-- 帳票ID
--==============================================================================
--					変数定義													
--==============================================================================
	gRtnCd				integer :=	RTN_OK;							-- リターンコード
	gSeqNo				integer := 0;								-- シーケンス
--==============================================================================
--					カーソル定義													
--==============================================================================
	curMeisai CURSOR FOR
		SELECT 	M02.FINANCIAL_SECURITIES_KBN,				-- 金融証券区分
				SC04.CODE_RNM,								-- 金融証券区分略称
				M02.BANK_CD,								-- 金融機関コード
				M02.BANK_NM,								-- 金融機関名称
				M02.BANK_RNM,								-- 金融機関略称
				M02.BANK_KANA_RNM 							-- 金融機関略称(カナ)
		FROM mbank m02
		LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = '507') sc04 
			ON (M02.FINANCIAL_SECURITIES_KBN = SC04.CODE_VALUE)
		WHERE TO_CHAR(M02.SAKUSEI_DT, 'yyyymmdd') = l_inGyomuYmd 
		AND M02.SAKUSEI_ID = l_inUserId  
		ORDER BY M02.FINANCIAL_SECURITIES_KBN, M02.BANK_CD;
		
	curCount CURSOR FOR
		SELECT 	COUNT(*) AS CNT
		FROM	PRT_OK	S05
		WHERE	S05.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND		S05.KIJUN_YMD = l_inGyomuYmd
		AND		S05.LIST_SAKUSEI_KBN = l_inChohyoSakuKbn
		AND		S05.CHOHYO_ID = REPORT_ID;
--==============================================================================
--					メイン処理														
--==============================================================================
BEGIN
	-- 制作時、ログを出力する。パッケージ使用	
	IF DEBUG = 1 THEN	
		CALL pkLog.debug(l_inUserId, REPORT_ID, 'IPF005K00R01 START');	
	END IF;
	
	-- 入力パラメタ(委託会社コード)のチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' THEN
		IF DEBUG = 1 THEN	
			CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	
		END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF005K00R01', '＜項目名称:委託会社コード＞'||'＜項目値:'||l_inItakuKaishaCd||'＞');
		RETURN;
	END IF;
	
	-- 入力パラメタ(ユーザＩＤ)のチェック
	IF coalesce(trim(both l_inUserId)::text, '') = '' THEN
		IF DEBUG = 1 THEN	
			CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	
		END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF005K00R01', '＜項目名称:ユーザＩＤ＞'||'＜項目値:'||l_inUserId||'＞');
		RETURN;
	END IF;
	
	-- 入力パラメタ(帳票区分)のチェック
	IF coalesce(trim(both l_inChohyoKbn)::text, '') = '' THEN
		IF DEBUG = 1 THEN	
			CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	
		END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF005K00R01', '＜項目名称:帳票区分＞'||'＜項目値:'||l_inChohyoKbn||'＞');
		RETURN;
	END IF;
	
	-- 入力パラメタ(帳票作成区分)のチェック
	IF coalesce(trim(both l_inChohyoSakuKbn)::text, '') = '' THEN
		IF DEBUG = 1 THEN	
			CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	
		END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF005K00R01', '＜項目名称:帳票作成区分＞'||'＜項目値:'||l_inChohyoSakuKbn||'＞');
		RETURN;
	END IF;
	
	-- 入力パラメタ(業務日付)のチェック
	IF coalesce(trim(both l_inGyomuYmd)::text, '') = '' THEN
		IF DEBUG = 1 THEN	
			CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	
		END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF005K00R01', '＜項目名称:業務日付＞'||'＜項目値:'||l_inGyomuYmd||'＞');
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
	
	-- データ取得
	FOR recMeisai IN curMeisai LOOP
		gSeqNo := gSeqNo + 1;
		-- 帳票ワークへデータを追加
		CALL pkPrint.insertData(
			l_inKeyCd			=>	l_inItakuKaishaCd, 						-- 識別コード
			l_inUserId			=>	'BATCH',									-- ユーザＩＤ
			l_inChohyoKbn		=>	l_inChohyoKbn, 							-- 帳票区分
			l_inSakuseiYmd		=>	l_inGyomuYmd, 							-- 業務日付
			l_inChohyoId		=>	REPORT_ID, 								-- 帳票ＩＤ
			l_inSeqNo			=>	gSeqNo, 									-- 連番
			l_inHeaderFlg		=>	'1',										-- ヘッダフラグ
			l_inItem001		=>	l_inGyomuYmd, 							-- 業務日付
			l_inItem002		=>	recMeisai.FINANCIAL_SECURITIES_KBN, 		-- 金融証券区分
			l_inItem003		=>	recMeisai.CODE_RNM, 						-- 金融証券区分略称
			l_inItem004		=>	recMeisai.BANK_CD, 						-- 金融機関コード
			l_inItem005		=>	recMeisai.BANK_NM, 						-- 金融機関名称
			l_inItem006		=>	recMeisai.BANK_RNM, 						-- 金融機関略称
			l_inItem007		=>	recMeisai.BANK_KANA_RNM, 					-- 金融機関略称(カナ)
			l_inItem008		=>	REPORT_ID, 								-- 帳票ＩＤ
			l_inKousinId		=>	l_inUserId, 								-- 更新者ID
			l_inSakuseiId		=>	l_inUserId 								-- 作成者ID
		);	
	END LOOP;
	
	IF gSeqNo = 0 THEN
		-- 対象データなし
		gRtnCd := RTN_NODATA;
	END IF;
	
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
		CALL pkLog.debug(l_inUserId, REPORT_ID, 'IPF005K00R01 END');	
	END IF;
	RETURN;
	
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'IPF005K00R01', 'SQLERRM:'||SQLERRM||'('||SQLSTATE||')');
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
		RETURN;
END;
$body$
LANGUAGE PLPGSQL;
