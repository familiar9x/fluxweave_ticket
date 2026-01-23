




CREATE OR REPLACE PROCEDURE spipf009k00r02 ( l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inUserId TEXT,		-- ユーザーID
 l_inChohyoKbn TEXT,		-- 帳票区分
 l_inGyomuYmd TEXT,		-- 業務日付
 l_outSqlCode OUT integer,		-- リターン値
 l_outSqlErrM OUT text	-- エラーコメント
 ) AS $body$
DECLARE

--
--/* 著作権:Copyright(c)2004
--/* 会社名:JIP
--/*
--/* バッチ処理指示により、部店マスタ更新結果リストを作成する。
--/*
--/* @author JIP
--/* @version $Revision: 1.4 $
--/*
--/* @param l_inItakuKaishaCd		IN	TEXT		委託会社コード
--/* @param l_inUserId			IN	TEXT		ユーザーID
--/* @param l_inChohyoKbn			IN	TEXT		帳票区分
--/* @param l_inGyomuYmd			IN	TEXT		業務日付
--/* @param l_outSqlCode			OUT	INTEGER		リターン値
--/* @param l_outSqlErrM			OUT	VARCHAR	エラーコメント
--/*
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.06.24	JIP				新規作成
--/*
--/*
--***************************************************************************
--
--==============================================================================
--					デバッグ機能													
--==============================================================================
	DEBUG	numeric(1)	:= 0;
--==============================================================================
--					配列定義												
--==============================================================================
	-- TYPE NUMARRAY IS TABLE OF numeric INDEX BY integer; -- Oracle associative array
	-- PostgreSQL: Use numeric[] array instead
--==============================================================================
--					定数定義													
--==============================================================================
	RTN_OK				CONSTANT integer		:= 0;				-- 正常
	RTN_NG				CONSTANT integer		:= 1;				-- 予期したエラー
	RTN_NODATA			CONSTANT integer		:= 40;				-- データなし
	RTN_FATAL			CONSTANT integer		:= 99;				-- 予期せぬエラー
	REPORT_ID			CONSTANT char(11)		:= 'IPF30000931';		-- 帳票ID
	-- 合計区分名称
	KBN_NAME_ERROR		CONSTANT char(16)		:= 'エラー件数';
	KBN_NAME_NORMAL		CONSTANT char(20)		:= '正常件数';
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd				integer :=	RTN_OK;						-- リターンコード
	gSeqNo				integer := 0;							-- シーケンス
	gRecCnt				integer := 0;							-- データレコード件数
	gCnt_jiko_daiko		numeric;										-- レコード存在件数
	gAryCnt				numeric[];										-- エラー正常カウンタ (PostgreSQL array)
	gErrUmuFlg			BUTENKOSHIN_LIST_WK.ERR_UMU_FLG%TYPE := '1';	-- エラー有無フラグ
	gItakuKaishaRnm		varchar(100);									-- 委託会社略称
	gItem003			SREPORT_WK.ITEM003%TYPE;						-- 委託会社略称
--==============================================================================
--					カーソル定義													
--==============================================================================
	curMeisai CURSOR FOR
		SELECT	FW04.TEKIYOST_YMD,				-- 適用開始日
				FW04.YOYAKU_KBN,				-- 予約区分
				FW04.BUTEN_CD,					-- 部店コード
				FW04.BUTEN_NM,					-- 部店名称
				FW04.BUTEN_RNM,					-- 部店略称
				FW04.GROUP_CD,					-- グループコード
				FW04.POST_NO,					-- 郵便番号
				FW04.ADD1,						-- 住所１
				FW04.ADD2,						-- 住所２
				FW04.ADD3,						-- 住所３
				FW04.BUSHO_NM,					-- 担当部署名称
				FW04.TEL_NO,					-- 電話番号
				FW04.FAX_NO,					-- ＦＡＸ番号
				FW04.MAIL_ADD,					-- メールアドレス
				FW04.DATA_RECV_YMD,				-- データ受信日
				FW04.ERR_UMU_FLG,				-- エラー有無フラグ
				FW04.ERR_CD_6,					-- エラーコード
				FW04.ERR_NM_30,					-- エラー内容
				FW04.SEQ_NO,					-- SEQ_NO
				MCD1.CODE_NM AS YOYAKU_KBN_NM,	-- 予約区分名称
				VJ1.JIKO_DAIKO_KBN,				-- 自行代行区分
				VJ1.BANK_RNM, 					-- 銀行略称
				WK01.BUTEN_CNT 					-- 部店件数
		FROM (
					SELECT	COUNT(*) AS BUTEN_CNT, ERR_UMU_FLG
					FROM (
								SELECT	BUTEN_CD, ERR_UMU_FLG
								FROM	BUTENKOSHIN_LIST_WK FW04
								WHERE	FW04.ITAKU_KAISHA_CD = l_inItakuKaishaCd
--								GROUP BY FW04.BUTEN_CD, FW04.ERR_UMU_FLG
								GROUP BY FW04.BUTEN_CD, FW04.SEQ_NO, FW04.ERR_UMU_FLG
							) alias1
					GROUP BY ERR_UMU_FLG
				) wk01, vjiko_itaku vj1, butenkoshin_list_wk fw04
LEFT OUTER JOIN scode mcd1 ON (FW04.YOYAKU_KBN = MCD1.CODE_VALUE AND 'S09' = MCD1.CODE_SHUBETSU)
WHERE FW04.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND VJ1.KAIIN_ID = l_inItakuKaishaCd AND FW04.ERR_UMU_FLG = WK01.ERR_UMU_FLG   ORDER BY	
					FW04.ERR_UMU_FLG DESC,
					FW04.TEKIYOST_YMD,
					FW04.YOYAKU_KBN,
					FW04.SEQ_NO
		;
	recPrevMeisai	RECORD;
	recWorkMeisai	RECORD;
	-- Temp variables for handling NULL values (can't modify RECORD fields in PostgreSQL)
	wkBankRnm		varchar;
	wkErrUmuFlg		varchar;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'IPF009K00R02 START');	END IF;
	-- 入力パラメタ(委託会社コード)のチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF009K00R02', '＜項目名称:委託会社コード＞'||'＜項目値:'||l_inItakuKaishaCd||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(ユーザＩＤ)のチェック
	IF coalesce(trim(both l_inUserId)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF009K00R02', '＜項目名称:ユーザＩＤ＞'||'＜項目値:'||l_inUserId||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(帳票区分)のチェック
	IF coalesce(trim(both l_inChohyoKbn)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF009K00R02', '＜項目名称:帳票区分＞'||'＜項目値:'||l_inChohyoKbn||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(業務日付)のチェック
	IF coalesce(trim(both l_inGyomuYmd)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF009K00R02', '＜項目名称:業務日付＞'||'＜項目値:'||l_inGyomuYmd||'＞');
		RETURN;
	END IF;
	-- 銀行略称を設定
	gCnt_jiko_daiko := 0;
	SELECT count(*)
	INTO STRICT gCnt_jiko_daiko
	FROM vjiko_itaku
	WHERE kaiin_id = l_inItakuKaishaCd
	AND jiko_daiko_kbn = '2';
	IF gCnt_jiko_daiko = 0 THEN
		gItakuKaishaRnm := NULL;
	ELSE
		SELECT bank_rnm
		INTO STRICT gItakuKaishaRnm
		FROM vjiko_itaku
		WHERE kaiin_id = l_inItakuKaishaCd
		AND jiko_daiko_kbn = '2';
	END IF;
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	-- 件数のクリア (Initialize PostgreSQL array)
	gAryCnt := ARRAY[0, 0, 0];  -- Initialize with 3 elements (index 1, 2 will be used)
	gAryCnt[1] := 0;		-- 正常件数 (Oracle index 0)
	gAryCnt[2] := 0;		-- エラー件数 (Oracle index 1)
	-- データ取得
	FOR recMeisai IN curMeisai LOOP
		-- 銀行略称
		-- Note: Cannot modify RECORD field in PostgreSQL, handle NULL logic when using BANK_RNM
		-- IF recMeisai.JIKO_DAIKO_KBN != '2' THEN
		-- 	-- 自行代行区分が'2'出ない場合は設定しない
		-- 	recMeisai.BANK_RNM := NULL;
		-- END IF;
		-- エラー有無件数の設定 (convert to 1-based indexing)
		gAryCnt[recMeisai.ERR_UMU_FLG::integer + 1] := recMeisai.BUTEN_CNT;
		IF gErrUmuFlg != recMeisai.ERR_UMU_FLG AND gRecCnt > 0 THEN
		-- エラー有無フラグでブレイク
			-- エラー件数データレコードを帳票ワークへ追加する
			gSeqNo := gSeqNo + 1;
			IF gAryCnt[2] = 0 THEN
				IF gCnt_jiko_daiko = 0 THEN
					-- Use BANK_RNM only if JIKO_DAIKO_KBN = '2'
					IF recPrevMeisai.JIKO_DAIKO_KBN = '2' THEN
						gItem003 := recPrevMeisai.BANK_RNM;
					ELSE
						gItem003 := NULL;
					END IF;
				ELSE
					gItem003 := gItakuKaishaRnm;
				END IF;
			ELSE
				-- Use BANK_RNM only if JIKO_DAIKO_KBN = '2'
				IF recPrevMeisai.JIKO_DAIKO_KBN = '2' THEN
					gItem003 := recPrevMeisai.BANK_RNM;
				ELSE
					gItem003 := NULL;
				END IF;
			END IF;
					-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := l_inGyomuYmd;	-- 入力業務日付
		v_item.l_inItem003 := gItem003;	-- 銀行略称
		v_item.l_inItem004 := recPrevMeisai.TEKIYOST_YMD;	-- 適用開始日
		v_item.l_inItem005 := recPrevMeisai.DATA_RECV_YMD;	-- データ受信日
		v_item.l_inItem007 := '1';	-- エラー有無フラグ
		v_item.l_inItem024 := KBN_NAME_ERROR;	-- 合計区分名称
		v_item.l_inItem025 := trim(both TO_CHAR(gAryCnt[2], '9,999'))||'件';	-- エラー有無毎の件数
		v_item.l_inItem027 := REPORT_ID;	-- 帳票ＩＤ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
			gErrUmuFlg	:= recMeisai.ERR_UMU_FLG;	-- エラー有無フラグ
		END IF;
		-- データレコードを帳票ワークへデータを追加
		gSeqNo := gSeqNo + 1;
		gRecCnt := gRecCnt + 1;
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := l_inGyomuYmd;	-- 入力業務日付
		-- Use BANK_RNM only if JIKO_DAIKO_KBN = '2'
		IF recMeisai.JIKO_DAIKO_KBN = '2' THEN
			v_item.l_inItem003 := recMeisai.BANK_RNM;	-- 銀行略称
		ELSE
			v_item.l_inItem003 := NULL;
		END IF;
		v_item.l_inItem004 := recMeisai.TEKIYOST_YMD;	-- 適用開始日
		v_item.l_inItem005 := recMeisai.DATA_RECV_YMD;	-- データ受信日
		v_item.l_inItem006 := recMeisai.SEQ_NO;	-- 連番
		v_item.l_inItem007 := recMeisai.ERR_UMU_FLG;	-- エラー有無フラグ
		v_item.l_inItem008 := recMeisai.ERR_CD_6;	-- エラーコード
		v_item.l_inItem009 := recMeisai.ERR_NM_30;	-- エラー内容
		v_item.l_inItem010 := recMeisai.YOYAKU_KBN;	-- 予約区分
		v_item.l_inItem011 := recMeisai.YOYAKU_KBN_NM;	-- 予約区分名称
		v_item.l_inItem012 := recMeisai.BUTEN_CD;	-- 部店コード
		v_item.l_inItem013 := recMeisai.BUTEN_NM;	-- 部店名称
		v_item.l_inItem014 := recMeisai.BUTEN_RNM;	-- 部店略称
		v_item.l_inItem015 := recMeisai.MAIL_ADD;	-- メールアドレス
		v_item.l_inItem016 := recMeisai.ADD1;	-- 住所１
		v_item.l_inItem017 := recMeisai.ADD2;	-- 住所２
		v_item.l_inItem018 := recMeisai.ADD3;	-- 住所３
		v_item.l_inItem019 := recMeisai.BUSHO_NM;	-- 担当部署名称
		v_item.l_inItem020 := recMeisai.POST_NO;	-- 郵便番号
		v_item.l_inItem021 := recMeisai.TEL_NO;	-- 電話番号
		v_item.l_inItem022 := recMeisai.FAX_NO;	-- FAX番号
		v_item.l_inItem023 := recMeisai.GROUP_CD;	-- グループコード
		v_item.l_inItem027 := REPORT_ID;	-- 帳票ＩＤ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		recPrevMeisai := recMeisai;
	END LOOP;
	IF gErrUmuFlg = '1' THEN
	-- エラー件数データを出力する
		recWorkMeisai := recPrevMeisai;
		-- Use temp variables instead of modifying RECORD fields
		IF gAryCnt[2] = 0 THEN
		-- エラーデータが存在しない場合はNULLを設定する
		-- 自行代行区分が'2のときは銀行略称を設定
			wkBankRnm := gItakuKaishaRnm;
			v_item.l_inItem004 := NULL;  -- TEKIYOST_YMD
			v_item.l_inItem005 := NULL;  -- DATA_RECV_YMD
		ELSE
			-- Use BANK_RNM only if JIKO_DAIKO_KBN = '2'
			IF recWorkMeisai.JIKO_DAIKO_KBN = '2' THEN
				wkBankRnm := recWorkMeisai.BANK_RNM;
			ELSE
				wkBankRnm := NULL;
			END IF;
			v_item.l_inItem004 := recWorkMeisai.TEKIYOST_YMD;
			v_item.l_inItem005 := recWorkMeisai.DATA_RECV_YMD;
		END IF;
		gSeqNo := gSeqNo + 1;
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := l_inGyomuYmd;	-- 入力業務日付
		v_item.l_inItem003 := wkBankRnm;	-- 銀行略称
		v_item.l_inItem005 := recWorkMeisai.DATA_RECV_YMD;	-- データ受信日
		v_item.l_inItem007 := '1';	-- エラー有無フラグ
		v_item.l_inItem024 := KBN_NAME_ERROR;	-- 合計区分名称
		v_item.l_inItem025 := trim(both TO_CHAR(gAryCnt[2], '9,999'))||'件';	-- エラー有無毎の件数
		v_item.l_inItem027 := REPORT_ID;	-- 帳票ＩＤ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	END IF;
	recWorkMeisai := recPrevMeisai;
	-- Use temp variables instead of modifying RECORD fields
	IF gAryCnt[1] = 0 THEN
	-- 正常データが存在しない場合はNULLを設定する
	-- 自行代行区分が'2のときは銀行略称を設定
		wkBankRnm := gItakuKaishaRnm;
		v_item.l_inItem004 := NULL;  -- TEKIYOST_YMD
		v_item.l_inItem005 := NULL;  -- DATA_RECV_YMD
	ELSE
		-- Use BANK_RNM only if JIKO_DAIKO_KBN = '2'
		IF recWorkMeisai.JIKO_DAIKO_KBN = '2' THEN
			wkBankRnm := recWorkMeisai.BANK_RNM;
		ELSE
			wkBankRnm := NULL;
		END IF;
		v_item.l_inItem004 := recWorkMeisai.TEKIYOST_YMD;
		v_item.l_inItem005 := recWorkMeisai.DATA_RECV_YMD;
	END IF;
	-- 正常件数データを出力する
	gSeqNo := gSeqNo + 1;
			-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := l_inGyomuYmd;	-- 入力業務日付
		v_item.l_inItem003 := wkBankRnm;	-- 銀行略称
		v_item.l_inItem007 := '0';	-- エラー有無フラグ
		v_item.l_inItem024 := KBN_NAME_NORMAL;	-- 合計区分名称
		v_item.l_inItem025 := trim(both TO_CHAR(gAryCnt[1], '9,999'))||'件';	-- エラー有無毎の件数
		v_item.l_inItem027 := REPORT_ID;	-- 帳票ＩＤ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	-- 総新規募集数データレコードを出力する
	gSeqNo := gSeqNo + 1;
	IF gAryCnt[1] = 0 AND gAryCnt[2] = 0 THEN
		IF gCnt_jiko_daiko = 0 THEN
			-- Use BANK_RNM only if JIKO_DAIKO_KBN = '2'
			IF recPrevMeisai.JIKO_DAIKO_KBN = '2' THEN
				gItem003 := recPrevMeisai.BANK_RNM;
			ELSE
				gItem003 := NULL;
			END IF;
		ELSE
			gItem003 := gItakuKaishaRnm;
		END IF;
	ELSE
		-- Use BANK_RNM only if JIKO_DAIKO_KBN = '2'
		IF recPrevMeisai.JIKO_DAIKO_KBN = '2' THEN
			gItem003 := recPrevMeisai.BANK_RNM;
		ELSE
			gItem003 := NULL;
		END IF;
	END IF;
			-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := l_inGyomuYmd;	-- 入力業務日付
		v_item.l_inItem003 := gItem003;	-- 銀行略称
		v_item.l_inItem004 := recPrevMeisai.TEKIYOST_YMD;	-- 適用開始日
		v_item.l_inItem005 := recPrevMeisai.DATA_RECV_YMD;	-- データ受信日
		v_item.l_inItem024 := '合計件数';	-- 合計区分名称
		v_item.l_inItem026 := trim(both TO_CHAR(gAryCnt[1] + gAryCnt[2], '999,999'))||'件';	-- 合計件数
		v_item.l_inItem027 := REPORT_ID;	-- 帳票ＩＤ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	IF gRecCnt = 0 THEN
	-- 対象データなし
		gRtnCd := RTN_NODATA;
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'IPF009K00R02 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		CALL pkLog.fatal('ECM701', 'IPF009K00R02', 'SQLERRM:'||SQLERRM||'('||SQLSTATE||')');
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
--		RAISE;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipf009k00r02 ( l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;
