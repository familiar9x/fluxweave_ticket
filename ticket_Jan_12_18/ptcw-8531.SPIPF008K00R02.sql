


-- Note: PostgreSQL composite types don't support default values
-- We'll initialize these in the procedure body


CREATE OR REPLACE PROCEDURE spipf008k00r02 ( 
 l_inItakuKaishaCd TEXT,		-- 委託会社コード
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
--/* 概要　:バッチ処理指示により、新規募集情報取込確認リストを作成する。
--/* 引数　:l_inItakuKaishaCd		IN	TEXT		委託会社コード
--/* 　　　 l_inUserId			IN	TEXT		ユーザーID
--/* 　　　 l_inChohyoKbn			IN	TEXT		帳票区分
--/* 　　　 l_inGyomuYmd			IN	TEXT		業務日付
--/* 　　　 l_outSqlCode			OUT	INTEGER		リターン値
--/* 　　　 l_outSqlErrM			OUT	VARCHAR	エラーコメント
--/* 返り値:なし
--/* @version $Revision: 1.8 $
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.05.31	JIP				新規作成
--/*  2005.06.24	JIP 緒方			正常終了時、PrtOkテーブルにデータを作成する
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
	RTN_NODATA			CONSTANT integer		:= 40;				-- データなし
	RTN_DUP_VAL_ON_INDEX	CONSTANT integer	:= 90;				-- 一意制約エラー
	RTN_FATAL			CONSTANT integer		:= 99;				-- 予期せぬエラー
	REPORT_ID			CONSTANT char(11)		:= 'IPF30000821';		-- 帳票ID
	-- 会計区分名称
	KBN_NAME_ERROR		CONSTANT char(16)		:= 'エラー新規募集数';
	KBN_NAME_NORMAL		CONSTANT char(20)		:= '正常取込新規募集件数';
	LOW_VALUE			CONSTANT numeric(3)		:= -999;
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd				integer :=	RTN_OK;						-- リターンコード
	gSeqNo				integer := 0;							-- シーケンス
	gRecCnt				integer := 0;							-- データレコード件数
	gMgrCount			numeric[];								-- エラー正常銘柄カウンタ array
	key					RECORD;									-- Key record
	count_key			RECORD;									-- Count key record
	wSeqNo				numeric := null;
	wRecCnt				varchar(10);
--==============================================================================
--					カーソル定義													
--==============================================================================
	curMeisai CURSOR FOR
		SELECT	KC16.SAKUSEI_YMD,			-- 作成年月日
				KC16.SHORI_TM,				-- 処理時刻
				KC16.ERR_UMU_FLG,			-- エラー有無フラグ
				KC16.SEQ_NO,					-- シーケンスNo
				MG1.ISIN_CD,				-- ISINコード
				KC16.MGR_CD,				-- 銘柄コード
				MG1.MGR_NM,					-- 銘柄の正式名称
				KC16.MGR_MEISAI_NO,			-- 銘柄明細NO
				KC16.HKUK_CD,				-- 引受会社コード
				KC16.ERR_CD6,				-- エラーコード
				KC16.ERR_NM30,				-- エラー内容
				VJ1.JIKO_DAIKO_KBN,			-- 自行代行区分
				VJ1.BANK_RNM  				-- 銀行略称
		FROM vjiko_itaku vj1, import_kakunin_list_wk kc16
LEFT OUTER JOIN mgr_kihon mg1 ON (KC16.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD AND KC16.MGR_CD = MG1.MGR_CD)
WHERE KC16.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND KC16.USER_ID = l_inUserId AND KC16.CHOHYO_ID = REPORT_ID AND KC16.SAKUSEI_YMD = l_inGyomuYmd AND VJ1.KAIIN_ID = l_inItakuKaishaCd   ORDER BY	KC16.ERR_UMU_FLG DESC,
					KC16.SEQ_NO,
					KC16.MGR_CD,
					MG1.ISIN_CD,
					KC16.MGR_MEISAI_NO,
					KC16.HKUK_CD,
					KC16.ERR_CD6
		;
	recPrevMeisai	RECORD;
	recWorkMeisai	RECORD;
	has_data		boolean := false;  -- Track if cursor returned any data
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	-- Initialize array and records
	gMgrCount := ARRAY[0, 0]; -- [1]=normal, [2]=error (1-based indexing)
	key := ROW(' '::text, ' '::text, LOW_VALUE::numeric, ' '::text);  -- gIsinCd, gMgrCd, gMgrMeisaiNo, gHkukCd
	count_key := ROW('1'::text, ' '::text, ' '::text, LOW_VALUE::numeric, ' '::text);  -- gErrUmuFlg, gIsinCd, gMgrCd, gMgrMeisaiNo, gHkukCd
	
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPF008K00R02 START');	END IF;
	-- 入力パラメタ(委託会社コード)のチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF008K00R02', '＜項目名称:委託会社コード＞'||'＜項目値:'||l_inItakuKaishaCd||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(ユーザＩＤ)のチェック
	IF coalesce(trim(both l_inUserId)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF008K00R02', '＜項目名称:ユーザＩＤ＞'||'＜項目値:'||l_inUserId||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(帳票区分)のチェック
	IF coalesce(trim(both l_inChohyoKbn)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF008K00R02', '＜項目名称:帳票区分＞'||'＜項目値:'||l_inChohyoKbn||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(業務日付)のチェック
	IF coalesce(trim(both l_inGyomuYmd)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF008K00R02', '＜項目名称:業務日付＞'||'＜項目値:'||l_inGyomuYmd||'＞');
		RETURN;
	END IF;
	-- 帳票ワークの削除
	DELETE	FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	-- 銘柄件数のクリア
	gMgrCount[1] := 0;		-- 正常銘柄件数
	gMgrCount[2] := 0;		-- エラー銘柄件数
	-- データ取得
	FOR recMeisai IN curMeisai LOOP
		has_data := true;  -- Mark that we have data
		-- 銀行略称
		IF recMeisai.JIKO_DAIKO_KBN != '2' THEN
			-- 自行代行区分が'2'でない場合は設定しない
			recMeisai.BANK_RNM := NULL;
		END IF;
		IF count_key.f1 != recMeisai.ERR_UMU_FLG THEN
		-- エラー有無フラグでブレイク
			-- Only output if recPrevMeisai has been assigned
			IF has_data AND gRecCnt > 0 THEN
				-- エラー銘柄件数データレコードを帳票ワークへ追加する
				gSeqNo := gSeqNo + 1;
						-- Clear composite type
			v_item := ROW();
			
			v_item.l_inItem001 := l_inUserId;	-- ユーザID
			v_item.l_inItem002 := l_inGyomuYmd;	-- 入力業務日付
			v_item.l_inItem003 := recPrevMeisai.BANK_RNM;	-- 銀行略称
			v_item.l_inItem004 := recPrevMeisai.SAKUSEI_YMD;	-- 作成年月日
			v_item.l_inItem005 := recPrevMeisai.SHORI_TM;	-- 処理時刻
			v_item.l_inItem007 := recPrevMeisai.ERR_UMU_FLG;	-- エラー有無フラグ
			v_item.l_inItem015 := KBN_NAME_ERROR;	-- 会計区分名称
			v_item.l_inItem016 := gMgrCount[2];	-- エラー有無毎の件数
			v_item.l_inItem018 := REPORT_ID;	-- 帳票ＩＤ
			
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
			count_key.f1	:= recMeisai.ERR_UMU_FLG;	-- エラー有無フラグ
			-- キークリア
			key.f1			:= ' ';
			key.f2			:= ' ';
			key.f3	:= LOW_VALUE;
			key.f4			:= ' ';
			count_key.f2	:= ' ';
			count_key.f4	:= LOW_VALUE;
			count_key.f5	:= ' ';
		END IF;
		-- エラー正常銘柄件数
		if ((coalesce(wSeqNo::text, '') = '') or (recMeisai.SEQ_NO != wSeqNo)) then
			-- Increment counter based on error flag
			IF recMeisai.ERR_UMU_FLG = '0' THEN
				gMgrCount[1] := gMgrCount[1] + 1;  -- Normal count
			ELSE
				gMgrCount[2] := gMgrCount[2] + 1;  -- Error count
			END IF;
			gRecCnt := gRecCnt + 1;
			wRecCnt := pkcharacter.numeric_to_char(gRecCnt);
		end if;
		-- シーケンスNo保存
		wSeqNo := recMeisai.SEQ_NO;
		-- ISINコード、銘柄コード、銘柄名称、銘柄明細No、引受会社コードのうち
		-- 前レコードを同一の場合は出力しない
		CASE
--			WHEN key.f1 != recMeisai.ISIN_CD
--			THEN
--				key.f1			:= recMeisai.ISIN_CD;
--				key.f2			:= recMeisai.MGR_CD;
--				key.f3	:= recMeisai.MGR_MEISAI_NO;
--				key.f4			:= recMeisai.HKUK_CD;
--			WHEN key.f1 = recMeisai.ISIN_CD
--			AND  key.f2 != recMeisai.MGR_CD
			WHEN key.f2 != recMeisai.MGR_CD 		--追加
			THEN
--				recMeisai.ISIN_CD	:= NULL;
				key.f2			:= recMeisai.MGR_CD;
				key.f3	:= recMeisai.MGR_MEISAI_NO;
				key.f4			:= recMeisai.HKUK_CD;
--			WHEN key.f1 = recMeisai.ISIN_CD
--			AND  key.f2 = recMeisai.MGR_CD
			WHEN key.f2 = recMeisai.MGR_CD 		--追加
			AND  key.f3 != recMeisai.MGR_MEISAI_NO
			THEN
				recMeisai.ISIN_CD	:= NULL;
				recMeisai.MGR_CD	:= NULL;
				recMeisai.MGR_NM	:= NULL;
				key.f3	:= recMeisai.MGR_MEISAI_NO;
				key.f4			:= recMeisai.HKUK_CD;
--			WHEN key.f1 = recMeisai.ISIN_CD
--			AND  key.f2 = recMeisai.MGR_CD
			WHEN key.f2 = recMeisai.MGR_CD 		--追加
			AND  key.f3 = recMeisai.MGR_MEISAI_NO
			AND  key.f4 != recMeisai.HKUK_CD
			THEN
				recMeisai.ISIN_CD		:= NULL;
				recMeisai.MGR_CD		:= NULL;
				recMeisai.MGR_NM		:= NULL;
				recMeisai.MGR_MEISAI_NO	:= NULL;
				key.f4				:= recMeisai.HKUK_CD;
			ELSE
				recMeisai.ISIN_CD		:= NULL;
				recMeisai.MGR_CD		:= NULL;
				recMeisai.MGR_NM		:= NULL;
				recMeisai.MGR_MEISAI_NO	:= NULL;
				recMeisai.HKUK_CD		:= NULL;
		END CASE;
		-- データレコードを帳票ワークへデータを追加
		gSeqNo := gSeqNo + 1;
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := l_inGyomuYmd;	-- 入力業務日付
		v_item.l_inItem003 := recMeisai.BANK_RNM;	-- 銀行略称
		v_item.l_inItem004 := recMeisai.SAKUSEI_YMD;	-- 作成年月日
		v_item.l_inItem005 := recMeisai.SHORI_TM;	-- 処理時刻
		v_item.l_inItem006 := wRecCnt;	-- 連番
		v_item.l_inItem007 := recMeisai.ERR_UMU_FLG;	-- エラー有無フラグ
		v_item.l_inItem008 := recMeisai.ISIN_CD;	-- ISINコード
		v_item.l_inItem009 := recMeisai.MGR_CD;	-- 銘柄コード
		v_item.l_inItem010 := SUBSTR(recMeisai.MGR_NM,1, 22);	-- 銘柄の正式名称
		v_item.l_inItem011 := recMeisai.MGR_MEISAI_NO;	-- 銘柄明細No
		v_item.l_inItem012 := recMeisai.HKUK_CD;	-- 引受会社コード
		v_item.l_inItem013 := recMeisai.ERR_CD6;	-- エラーコード
		v_item.l_inItem014 := recMeisai.ERR_NM30;	-- エラー内容
		v_item.l_inItem018 := REPORT_ID;	-- 帳票ＩＤ
		
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
		wRecCnt := ' ';
	END LOOP;
	IF has_data AND count_key.f1 = '1' THEN
	-- エラー銘柄件数データを出力する (only if we have data)
		recWorkMeisai := recPrevMeisai;
		IF gMgrCount[2] = 0 THEN
		-- エラー銘柄データが存在しない場合はNULLを設定する
			recWorkMeisai.BANK_RNM		:= NULL;
			recWorkMeisai.SAKUSEI_YMD	:= NULL;
			recWorkMeisai.SHORI_TM		:= NULL;
			recWorkMeisai.ERR_UMU_FLG	:= NULL;
		END IF;
		gSeqNo := gSeqNo + 1;
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := l_inGyomuYmd;	-- 入力業務日付
		v_item.l_inItem003 := recWorkMeisai.BANK_RNM;	-- 銀行略称
		v_item.l_inItem004 := recWorkMeisai.SAKUSEI_YMD;	-- 作成年月日
		v_item.l_inItem005 := recWorkMeisai.SHORI_TM;	-- 処理時刻
		v_item.l_inItem007 := recWorkMeisai.ERR_UMU_FLG;	-- エラー有無フラグ
		v_item.l_inItem015 := KBN_NAME_ERROR;	-- 会計区分名称
		v_item.l_inItem016 := gMgrCount[2];	-- エラー有無毎の件数
		v_item.l_inItem018 := REPORT_ID;	-- 帳票ＩＤ
		
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
	IF has_data THEN
	-- 正常銘柄件数データを出力する (only if we have data)
		recWorkMeisai := recPrevMeisai;
		IF gMgrCount[1] = 0 THEN
		-- 正常銘柄データが存在しない場合はNULLを設定する
			recWorkMeisai.BANK_RNM		:= NULL;
			recWorkMeisai.SAKUSEI_YMD	:= NULL;
			recWorkMeisai.SHORI_TM		:= NULL;
			recWorkMeisai.ERR_UMU_FLG	:= NULL;
		END IF;
	-- 正常銘柄件数データを出力する
	gSeqNo := gSeqNo + 1;
			-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := l_inGyomuYmd;	-- 入力業務日付
		v_item.l_inItem003 := recWorkMeisai.BANK_RNM;	-- 銀行略称
		v_item.l_inItem004 := recWorkMeisai.SAKUSEI_YMD;	-- 作成年月日
		v_item.l_inItem005 := recWorkMeisai.SHORI_TM;	-- 処理時刻
		v_item.l_inItem007 := recWorkMeisai.ERR_UMU_FLG;	-- エラー有無フラグ
		v_item.l_inItem015 := KBN_NAME_NORMAL;	-- 会計区分名称
		v_item.l_inItem016 := gMgrCount[1];	-- エラー有無毎の件数
		v_item.l_inItem018 := REPORT_ID;	-- 帳票ＩＤ
		
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
				-- Clear composite type
			v_item := ROW();
			
			v_item.l_inItem001 := l_inUserId;	-- ユーザID
			v_item.l_inItem002 := l_inGyomuYmd;	-- 入力業務日付
			v_item.l_inItem003 := recPrevMeisai.BANK_RNM;	-- 銀行略称
			v_item.l_inItem004 := recPrevMeisai.SAKUSEI_YMD;	-- 作成年月日
			v_item.l_inItem005 := recPrevMeisai.SHORI_TM;	-- 処理時刻
			v_item.l_inItem019 := '総新規募集数';	-- 会計区分名称
			v_item.l_inItem017 := gMgrCount[1] + gMgrCount[2];	-- 総新規募集件数
			v_item.l_inItem018 := REPORT_ID;	-- 帳票ＩＤ
			
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
	END IF;  -- End of has_data check
	IF gRecCnt = 0 THEN
	-- 対象データなし
		gRtnCd := RTN_NODATA;
	END IF;
	IF gRtnCd = RTN_OK THEN
		CALL pkPrtOk.insertPrtOk(
			l_inUserId,
			l_inItakuKaishaCd,
			l_inGyomuYmd,
			pkPrtOk.LIST_SAKUSEI_KBN_ZUIJI(),
			REPORT_ID
		);
	END IF;	
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'IPF008K00R02 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	unique_violation THEN
		l_outSqlCode := RTN_DUP_VAL_ON_INDEX;
		l_outSqlErrM := SQLERRM;
	WHEN	OTHERS	THEN
		CALL pkLog.fatal('ECM701', 'IPF008K00R02', 'SQLERRM:'||SQLERRM||'('||SQLSTATE||')');
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
--		RAISE;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipf008k00r02 ( l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;