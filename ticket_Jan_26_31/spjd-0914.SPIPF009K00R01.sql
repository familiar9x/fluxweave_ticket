




CREATE OR REPLACE PROCEDURE spipf009k00r01 ( l_inChohyoId TEXT,		-- 帳票ID
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
--/*
--/* バッチ処理指示により、口座情報更新結果リストを作成する。
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
	gAryCnt				numeric[];								-- エラー正常カウンタ (PostgreSQL array)
	gErrUmuFlg			BUTENKOSHIN_LIST_WK.ERR_UMU_FLG%TYPE := '1';	-- エラー有無フラグ
	gItakuKaishaRnm		varchar(100);									-- 委託会社略称
	gItem003			SREPORT_WK.ITEM003%TYPE;						-- 委託会社略称
	gCnt_jiko_daiko		numeric;										-- レコード存在件数
--==============================================================================
--					カーソル定義													
--==============================================================================
	curMeisai CURSOR FOR
		SELECT	FW01.TEKIYOST_YMD,						-- 適用開始日
				FW01.OLD_KOZA_TEN_CD,					-- 旧口座店コード
				FW01.OLD_KOZA_TEN_CIFCD,				-- 旧口座店CIFコード
				FW01.OLD_KOZA_KAMOKU,					-- 旧口座科目
				FW01.OLD_KOZA_NO,						-- 旧口座番号
				FW01.NEW_KOZA_TEN_CD,					-- 新口座店コード
				FW01.NEW_KOZA_TEN_CIFCD,				-- 新口座店CIFコード
				FW01.NEW_KOZA_KAMOKU,					-- 新口座各目
				FW01.NEW_KOZA_NO,						-- 新口座番号
				FW01.HKT_CD,							-- 発行体コード
				FW01.KOZA_SHUBETU,						-- 口座種別
				FW01.FILTER_SHUBETU,					-- フィルタ種別
				FW01.DATA_RECV_YMD,						-- データ受信日
				FW01.ERR_UMU_FLG,						-- エラー有無フラグ
				FW01.ERR_CD_6,							-- エラーコード
				FW01.ERR_NM_30,							-- エラー内容
				FW01.SEQ_NO,							-- SEQ_NO
				MCD1.CODE_RNM AS FILTER_SHUBETU_RNM,	-- フィルタ種別名称
				MCD2.CODE_NM AS	OLD_KOZA_KAMOKU_NM,		-- 旧口座科目名称
				MCD3.CODE_NM AS	NEW_KOZA_KAMOKU_NM,		-- 新口座科目名称
				MCD4.CODE_NM AS	KOZA_SHUBETU_NM,		-- 口座種別
				M041.BUTEN_RNM AS OLD_KOZA_TEN_RNM,		-- 旧部店略称
				M042.BUTEN_RNM AS NEW_KOZA_TEN_RNM,		-- 新部店略称
				M01.HKT_RNM,							-- 発行体略称
				VJ1.JIKO_DAIKO_KBN,						-- 自行代行区分
				VJ1.BANK_RNM, 							-- 銀行略称
				WK01.KOZA_CNT 							-- 件数
		FROM (	-- エラー有無件数取得
					SELECT	COUNT(*) AS KOZA_CNT, ERR_UMU_FLG
					FROM (
								SELECT	FW01.ERR_UMU_FLG, FW01.OLD_KOZA_TEN_CD, FW01.OLD_KOZA_TEN_CIFCD, FW01.OLD_KOZA_KAMOKU, FW01.OLD_KOZA_NO
								FROM	KOZAJYOHOKOSHIN_LIST_WK FW01
								WHERE	FW01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
								AND		FW01.CHOHYO_ID = l_inChohyoId
								GROUP BY FW01.ERR_UMU_FLG, FW01.OLD_KOZA_TEN_CD, FW01.OLD_KOZA_TEN_CIFCD, FW01.OLD_KOZA_KAMOKU, FW01.OLD_KOZA_NO, FW01.SEQ_NO
							) alias1
					GROUP BY ERR_UMU_FLG
				) wk01, vjiko_itaku vj1, kozajyohokoshin_list_wk fw01
LEFT OUTER JOIN mhakkotai m01 ON (FW01.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD AND FW01.HKT_CD = M01.HKT_CD)
LEFT OUTER JOIN mbuten m041 ON (FW01.ITAKU_KAISHA_CD = M041.ITAKU_KAISHA_CD AND FW01.OLD_KOZA_TEN_CD = M041.BUTEN_CD)
LEFT OUTER JOIN mbuten m042 ON (FW01.ITAKU_KAISHA_CD = M042.ITAKU_KAISHA_CD AND FW01.NEW_KOZA_TEN_CD = M042.BUTEN_CD)
LEFT OUTER JOIN scode mcd1 ON (FW01.FILTER_SHUBETU = MCD1.CODE_VALUE AND 'S08' = MCD1.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd2 ON (FW01.OLD_KOZA_KAMOKU = MCD2.CODE_VALUE AND '707' = MCD2.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd3 ON (FW01.NEW_KOZA_KAMOKU = MCD3.CODE_VALUE AND '707' = MCD3.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd4 ON (FW01.KOZA_SHUBETU = MCD4.CODE_VALUE AND '193' = MCD4.CODE_SHUBETSU)
WHERE FW01.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND FW01.CHOHYO_ID = l_inChohyoId AND VJ1.KAIIN_ID = l_inItakuKaishaCd       AND FW01.ERR_UMU_FLG = WK01.ERR_UMU_FLG         ORDER BY	FW01.ERR_UMU_FLG DESC,
					FW01.TEKIYOST_YMD,
					FW01.OLD_KOZA_TEN_CD,
					FW01.OLD_KOZA_TEN_CIFCD,
					FW01.OLD_KOZA_KAMOKU,
					FW01.OLD_KOZA_NO
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
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, l_inChohyoId, 'IPF009K00R01 START');	END IF;
	-- 入力パラメタ(帳票ID)のチェック
	IF coalesce(trim(both l_inChohyoId)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, 'IPF30000911', 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF009K00R01', '＜項目名称:帳票ＩＤ＞'||'＜項目値:'||l_inChohyoId||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(委託会社コード)のチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, l_inChohyoId, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF009K00R01', '＜項目名称:委託会社コード＞'||'＜項目値:'||l_inItakuKaishaCd||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(ユーザＩＤ)のチェック
	IF coalesce(trim(both l_inUserId)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, l_inChohyoId, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF009K00R01', '＜項目名称:ユーザＩＤ＞'||'＜項目値:'||l_inUserId||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(帳票区分)のチェック
	IF coalesce(trim(both l_inChohyoKbn)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, l_inChohyoId, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF009K00R01', '＜項目名称:帳票区分＞'||'＜項目値:'||l_inChohyoKbn||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(業務日付)のチェック
	IF coalesce(trim(both l_inGyomuYmd)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, l_inChohyoId, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF009K00R01', '＜項目名称:業務日付＞'||'＜項目値:'||l_inGyomuYmd||'＞');
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
		INTO gItakuKaishaRnm
		FROM vjiko_itaku
		WHERE kaiin_id = l_inItakuKaishaCd
		AND jiko_daiko_kbn = '2'
		LIMIT 1;
	END IF;
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = l_inChohyoId;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, l_inChohyoId);
	-- 件数のクリア (Initialize PostgreSQL array)
	gAryCnt := ARRAY[0, 0, 0];  -- Initialize with 3 elements (index 1, 2 will be used)
	gAryCnt[1] := 0;		-- 正常件数
	gAryCnt[2] := 0;		-- エラー件数
	-- データ取得
	FOR recMeisai IN curMeisai LOOP
		-- 銀行略称
		-- Note: Cannot modify RECORD field in PostgreSQL, handle NULL logic when using BANK_RNM
		-- IF recMeisai.JIKO_DAIKO_KBN != '2' THEN
		-- 	recMeisai.BANK_RNM := NULL;
		-- END IF;
		-- エラー有無件数の設定
		gAryCnt[recMeisai.ERR_UMU_FLG::integer + 1] := recMeisai.KOZA_CNT;
		IF gErrUmuFlg != recMeisai.ERR_UMU_FLG AND gRecCnt > 0 THEN
		-- エラー有無フラグでブレイク (only if not first record)
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
		v_item.l_inItem005 := '1';	-- エラー有無フラグ
		v_item.l_inItem028 := KBN_NAME_ERROR;	-- 合計区分名称
		v_item.l_inItem029 := trim(both TO_CHAR(gAryCnt[2], '9,999'))||'件';	-- エラー有無毎の件数
		v_item.l_inItem031 := l_inChohyoId;	-- 帳票ＩＤ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> l_inChohyoId,
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
		v_item.l_inItem004 := recMeisai.SEQ_NO;	-- SEQ_NO
		v_item.l_inItem005 := recMeisai.ERR_UMU_FLG;	-- エラー有無フラグ
		v_item.l_inItem006 := recMeisai.ERR_CD_6;	-- エラーコード
		v_item.l_inItem007 := recMeisai.ERR_NM_30;	-- エラー内容
		v_item.l_inItem008 := recMeisai.TEKIYOST_YMD;	-- 適用開始日
		v_item.l_inItem009 := recMeisai.DATA_RECV_YMD;	-- データ受信日
		v_item.l_inItem010 := recMeisai.OLD_KOZA_TEN_CD;	-- 旧口座店コード
		v_item.l_inItem011 := recMeisai.NEW_KOZA_TEN_CD;	-- 新口座店コード
		v_item.l_inItem012 := recMeisai.OLD_KOZA_TEN_RNM;	-- 旧口座店略称
		v_item.l_inItem013 := recMeisai.NEW_KOZA_TEN_RNM;	-- 新口座店略称
		v_item.l_inItem014 := recMeisai.OLD_KOZA_TEN_CIFCD;	-- 旧口座店CIFコード
		v_item.l_inItem015 := recMeisai.NEW_KOZA_TEN_CIFCD;	-- 新口座店CIFコード
		v_item.l_inItem016 := recMeisai.OLD_KOZA_KAMOKU;	-- 旧口座科目
		v_item.l_inItem017 := recMeisai.NEW_KOZA_KAMOKU;	-- 新口座科目
		v_item.l_inItem018 := recMeisai.OLD_KOZA_KAMOKU_NM;	-- 旧口座科目名称
		v_item.l_inItem019 := recMeisai.NEW_KOZA_KAMOKU_NM;	-- 新口座科目名称
		v_item.l_inItem020 := recMeisai.OLD_KOZA_NO;	-- 旧口座番号
		v_item.l_inItem021 := recMeisai.NEW_KOZA_NO;	-- 新口座番号
		v_item.l_inItem022 := recMeisai.HKT_CD;	-- 発行体コード
		v_item.l_inItem023 := recMeisai.HKT_RNM;	-- 発行体略称
		v_item.l_inItem024 := recMeisai.KOZA_SHUBETU;	-- 口座種別
		v_item.l_inItem025 := recMeisai.KOZA_SHUBETU_NM;	-- 口座種別名称
		v_item.l_inItem026 := recMeisai.FILTER_SHUBETU;	-- フィルタ種別
		v_item.l_inItem027 := recMeisai.FILTER_SHUBETU_RNM;	-- フィルタ種別略称
		v_item.l_inItem031 := l_inChohyoId;	-- 帳票ＩＤ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> l_inChohyoId,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		recPrevMeisai := recMeisai;
	END LOOP;
	IF gErrUmuFlg = '1' AND gRecCnt > 0 THEN
	-- エラー件数データを出力する (only if data was processed)
		recWorkMeisai := recPrevMeisai;
		-- Use temp variables instead of modifying RECORD fields
		IF gAryCnt[2] = 0 THEN
		-- エラーデータが存在しない場合はNULLを設定する
			wkBankRnm := gItakuKaishaRnm;
			wkErrUmuFlg := NULL;
		ELSE
			-- Use BANK_RNM only if JIKO_DAIKO_KBN = '2'
			IF recWorkMeisai.JIKO_DAIKO_KBN = '2' THEN
				wkBankRnm := recWorkMeisai.BANK_RNM;
			ELSE
				wkBankRnm := NULL;
			END IF;
			wkErrUmuFlg := recWorkMeisai.ERR_UMU_FLG;
		END IF;
		gSeqNo := gSeqNo + 1;
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := l_inGyomuYmd;	-- 入力業務日付
		v_item.l_inItem003 := wkBankRnm;	-- 銀行略称
		v_item.l_inItem005 := '1';	-- エラー有無フラグ
		v_item.l_inItem028 := KBN_NAME_ERROR;	-- 合計区分名称
		v_item.l_inItem029 := trim(both TO_CHAR(gAryCnt[2], '9,999'))||'件';	-- エラー有無毎の件数
		v_item.l_inItem031 := l_inChohyoId;	-- 帳票ＩＤ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> l_inChohyoId,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	END IF;
	
	-- Only process summary records if data was actually processed
	IF gRecCnt > 0 THEN
		recWorkMeisai := recPrevMeisai;
		-- Use temp variables instead of modifying RECORD fields
		IF gAryCnt[1] = 0 THEN
		-- 正常データが存在しない場合はNULLを設定する
			wkBankRnm := gItakuKaishaRnm;
			wkErrUmuFlg := NULL;
	ELSE
		-- Use BANK_RNM only if JIKO_DAIKO_KBN = '2'
		IF recWorkMeisai.JIKO_DAIKO_KBN = '2' THEN
			wkBankRnm := recWorkMeisai.BANK_RNM;
		ELSE
			wkBankRnm := NULL;
		END IF;
		wkErrUmuFlg := recWorkMeisai.ERR_UMU_FLG;
	END IF;
	-- 正常件数データを出力する
	gSeqNo := gSeqNo + 1;
			-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := l_inGyomuYmd;	-- 入力業務日付
		v_item.l_inItem003 := wkBankRnm;	-- 銀行略称
		v_item.l_inItem005 := '0';	-- エラー有無フラグ
		v_item.l_inItem028 := KBN_NAME_NORMAL;	-- 合計区分名称
		v_item.l_inItem029 := trim(both TO_CHAR(gAryCnt[1], '9,999'))||'件';	-- エラー有無毎の件数
		v_item.l_inItem031 := l_inChohyoId;	-- 帳票ＩＤ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> l_inChohyoId,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	-- 総新規募集数データレコードを出力する
	gSeqNo := gSeqNo + 1;
	IF gAryCnt[2] = 0 AND gAryCnt[2] = 0 THEN
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
		v_item.l_inItem028 := '合計件数';	-- 合計区分名称
		v_item.l_inItem030 := trim(both TO_CHAR(gAryCnt[1] + gAryCnt[2], '999,999'))||'件';	-- 合計件数
		v_item.l_inItem031 := l_inChohyoId;	-- 帳票ＩＤ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> l_inChohyoId,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	END IF; -- End of gRecCnt > 0 check
	
	IF gRecCnt = 0 THEN
	-- 対象データなし
		gRtnCd := RTN_NODATA;
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, l_inChohyoId, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, l_inChohyoId, 'IPF009K00R01 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		CALL pkLog.fatal('ECM701', 'IPF009K00R01', 'SQLERRM:'||SQLERRM||'('||SQLSTATE||')');
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
--		RAISE;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipf009k00r01 ( l_inChohyoId TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT integer, l_outSqlErrM OUT text ) FROM PUBLIC;
