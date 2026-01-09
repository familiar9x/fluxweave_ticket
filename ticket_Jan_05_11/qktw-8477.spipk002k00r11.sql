


DROP TYPE IF EXISTS spipk002k00r11_type_key;
CREATE TYPE spipk002k00r11_type_key AS (
		gIsinCd			char(12),				-- ISINコード
		gMgrCd			varchar(13),	-- 銘柄コード
	    gShokanKbn		char(2),	-- 償還区分
	    gShokanYmd		char(8),	-- 償還年月日
	    gSeqNum		numeric(10)			-- シーケンスＮｏ
	);
DROP TYPE IF EXISTS spipk002k00r11_type_count_key;
CREATE TYPE spipk002k00r11_type_count_key AS (
		gSoriMode		char(1),		-- 処理モード
		gErrUmuFlg		char(1)	-- エラー有無フラグ
	);


CREATE OR REPLACE PROCEDURE spipk002k00r11 ( l_inItakuKaishaCd TEXT,		-- 委託会社コード
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
--/* 概要　:バッチ処理指示により、移行銘柄残高確認リストを作成する。
--/* 引数　:l_inItakuKaishaCd		IN	TEXT		委託会社コード
--/* 　　　 l_inUserId			IN	TEXT		ユーザーID
--/* 　　　 l_inChohyoKbn			IN	TEXT		帳票区分
--/* 　　　 l_inGyomuYmd			IN	TEXT		業務日付
--/* 　　　 l_outSqlCode			OUT	INTEGER		リターン値
--/* 　　　 l_outSqlErrM			OUT	VARCHAR	エラーコメント
--/* 返り値:なし
--/* @version $Id: SPIPK002K00R11.sql,v 1.16 2008/10/04 08:04:40 fujimoto Exp $
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.05.31	JIP		新規作成
--/*  2005.06.24	JIP		正常終了時、PrtOkテーブルにデータを作成する
--/*  2005.09.20	JIP		独自銘柄コード入力時対応
--/*  2006.04.27  JIP     本SPをSPIPF021K01R02(バッチ用)がフルコピーしているため横串修正時は気をつけること！！
--/*
--***************************************************************************
--
--==============================================================================
--					デバッグ機能													
--==============================================================================
	DEBUG	integer	:= 0;
--==============================================================================
--					定数定義													
--==============================================================================
	RTN_OK				CONSTANT integer		:= 0;				-- 正常
	RTN_NG				CONSTANT integer		:= 1;				-- 予期したエラー
	RTN_NODATA			CONSTANT integer		:= 2;				-- データなし
	RTN_DUP_VAL_ON_INDEX	CONSTANT integer	:= 90;				-- 一意制約エラー
	RTN_FATAL			CONSTANT integer		:= 99;				-- 予期せぬエラー
	REPORT_ID			CONSTANT text		:= 'IPK30000211';	-- 帳票ID
	-- 会計区分名称
	KBN_NAME_ERROR		CONSTANT text		:= 'エラー残高履歴数';
	KBN_NAME_NORMAL		CONSTANT text		:= '正常取込残高履歴数';
  -- 独自銘柄コード使用区分名称
	DOKUJI_MGR_CD_SHIYO	CONSTANT text	:= '＊独自銘柄コード使用';
--	LOW_VALUE			CONSTANT NUMERIC(3)		:= -999;
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gItakuKaishaRnm		VJIKO_ITAKU.BANK_RNM%TYPE;					-- 委託会社略称
	gRtnCd				integer := RTN_OK;						-- リターンコード
	gSeqNo				integer := 0;							-- シーケンス
	gRecCnt				integer := 1;							-- データレコード件数
	gMgrCount numeric[];									-- エラー正常銘柄カウンタ
	key SPIPK002K00R11_TYPE_KEY;
	count_key SPIPK002K00R11_TYPE_COUNT_KEY;
	wkTsukaNm			varchar(10);
	wkSeqNo				numeric(10);
	wkSeqNoChar			varchar(10);
	wkShiyoMgrCdKbnNm	varchar(20);
	wSeqNo				numeric       := 0;
	wNo                 numeric       := 0;
--==============================================================================
--					カーソル定義													
--==============================================================================
	curMeisai CURSOR FOR
		SELECT	
			KC16.SAKUSEI_YMD,				-- 作成年月日
			KC16.SHORI_TM,					-- 処理時刻
			KC16.SHORI_MODE,				-- 処理モード
			MCD1.CODE_NM AS SHORI_MODE_NM,	-- 処理モード名称
			KC16.ERR_UMU_FLG,				-- エラー有無フラグ
			MG1.ISIN_CD,					-- ISINコード
			KC16.MGR_CD,					-- 銘柄コード
			MG1.MGR_NM,						-- 銘柄の正式名称
			KC16.DKJ_MGR_CD,				-- 独自銘柄コード
			KC16.SHOKAN_YMD,				-- 償還年月日
			KC16.SHOKAN_KBN,				-- 償還区分
			MCD2.CODE_NM AS SHOKAN_KBN_NM,	-- 償還区分名称
			KC16.SHOKAN_KNGK,				-- 償還金額
			KC16.MEIMOKU_ZNDK,				-- 名目残高
			KC16.TSUKA_CD,					-- 通貨コード
			KC16.ERR_CD6,					-- エラーコード
			KC16.ERR_NM30,					-- エラー内容
			KC16.SEQ_NO 						-- シーケンスＮｏ
		FROM import_kakunin_list_wk kc16
LEFT OUTER JOIN mgr_kihon mg1 ON (KC16.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD AND KC16.MGR_CD = MG1.MGR_CD)
LEFT OUTER JOIN scode mcd1 ON (KC16.SHORI_MODE = MCD1.CODE_VALUE AND '881' = MCD1.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd2 ON (KC16.SHOKAN_KBN = MCD2.CODE_VALUE AND '714' = MCD2.CODE_SHUBETSU)
WHERE KC16.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND KC16.USER_ID = l_inUserId AND KC16.CHOHYO_ID = REPORT_ID AND KC16.SAKUSEI_YMD = l_inGyomuYmd       ORDER BY
			KC16.SHORI_MODE,			-- 処理モード
			KC16.ERR_UMU_FLG DESC,		-- エラー有無フラグ
			KC16.MGR_CD,				-- 銘柄コード
			MG1.ISIN_CD,				-- ISINコード
			KC16.SHOKAN_YMD,			-- 償還年月日
			MCD2.CODE_SORT,				-- 償還区分(コードソート)
			KC16.ERR_CD6				-- エラーコード
		;
	recPrevMeisai	RECORD;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPK002K00R11 START');	END IF;
	-- 入力パラメータのチェック
	IF	coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
		OR coalesce(trim(both l_inUserId)::text, '') = ''
		OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''
		OR coalesce(trim(both l_inGyomuYmd)::text, '') = ''
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error(l_inUserId, REPORT_ID, 'SQLERRM:'||'');
		RETURN;
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
	-- 銘柄件数のクリア
	gMgrCount := array_append(gMgrCount, 0);		-- 正常銘柄件数 [1]
	gMgrCount := array_append(gMgrCount, 0);		-- エラー銘柄件数 [2]
    
	-- 委託会社略称の取得
	gItakuKaishaRnm := SPIPK002K00R11_getItakuKaishaRnm(l_inItakuKaishaCd);
	-- データ取得
	FOR recMeisai IN curMeisai LOOP
		IF gSeqNo = 0 THEN
		-- 始めの処理モードを格納する。
			count_key.gSoriMode	:=	recMeisai.SHORI_MODE;
			wkSeqNo := recMeisai.SEQ_NO;
			IF (trim(both recMeisai.DKJ_MGR_CD) IS NOT NULL AND (trim(both recMeisai.DKJ_MGR_CD))::text <> '') THEN
	      		wkShiyoMgrCdKbnNm := DOKUJI_MGR_CD_SHIYO;
			END IF;
		ELSE
			IF wkSeqNo = recMeisai.SEQ_NO THEN
				recMeisai.SEQ_NO := NULL;
			ELSE
				wkSeqNo := recMeisai.SEQ_NO;
			gRecCnt := gRecCnt + 1;
	    	END IF;
		END IF;
		IF count_key.gSoriMode != recMeisai.SHORI_MODE THEN
		-- 処理モードでブレイク
			IF count_key.gErrUmuFlg = '1' THEN
				-- エラー銘柄件数データを出力する
				gSeqNo := gSeqNo + 1;
						-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := recPrevMeisai.SAKUSEI_YMD;	-- 作成年月日
		v_item.l_inItem003 := recPrevMeisai.SHORI_TM;	-- 処理時刻
		v_item.l_inItem004 := recPrevMeisai.SHORI_MODE;	-- 処理モード
		v_item.l_inItem005 := recPrevMeisai.SHORI_MODE_NM;	-- 処理モード名称
		v_item.l_inItem006 := '1';	-- エラー有無フラグ
		v_item.l_inItem017 := KBN_NAME_ERROR;	-- 会計区分名称
	v_item.l_inItem018 := gMgrCount[2];
		v_item.l_inItem020 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem022 := wkShiyoMgrCdKbnNm;	-- 使用銘柄コード区分
		v_item.l_inItem027 := gItakuKaishaRnm;	-- 委託会社コード
		v_item.l_inItem028 := l_inGyomuYmd;	-- データ基準日
		
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
			-- 正常銘柄件数データを出力する
			gSeqNo := gSeqNo + 1;
					-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := recPrevMeisai.SAKUSEI_YMD;	-- 作成年月日
		v_item.l_inItem003 := recPrevMeisai.SHORI_TM;	-- 処理時刻
		v_item.l_inItem004 := recPrevMeisai.SHORI_MODE;	-- 処理モード
		v_item.l_inItem005 := recPrevMeisai.SHORI_MODE_NM;	-- 処理モード名称
		v_item.l_inItem006 := '0';	-- エラー有無フラグ
		v_item.l_inItem017 := KBN_NAME_NORMAL;	-- 会計区分名称
		v_item.l_inItem018 := gMgrCount[1];
		v_item.l_inItem020 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem022 := wkShiyoMgrCdKbnNm;	-- 使用銘柄コード区分
		v_item.l_inItem027 := gItakuKaishaRnm;	-- 委託会社コード
		v_item.l_inItem028 := l_inGyomuYmd;	-- データ基準日
		
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
			-- 総件数データレコードを出力する
			gSeqNo := gSeqNo + 1;
					-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := recPrevMeisai.SAKUSEI_YMD;	-- 作成年月日
		v_item.l_inItem003 := recPrevMeisai.SHORI_TM;	-- 処理時刻
		v_item.l_inItem004 := recPrevMeisai.SHORI_MODE;	-- 処理モード
		v_item.l_inItem005 := recPrevMeisai.SHORI_MODE_NM;	-- 処理モード名称
		v_item.l_inItem017 := '総件数';	-- 会計区分名称
		v_item.l_inItem019 := gMgrCount[1] + gMgrCount[2];
		v_item.l_inItem020 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem022 := wkShiyoMgrCdKbnNm;	-- 使用銘柄コード区分
		v_item.l_inItem027 := gItakuKaishaRnm;	-- 委託会社コード
		v_item.l_inItem028 := l_inGyomuYmd;	-- データ基準日
		
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
			gMgrCount[1] := 0;
			gMgrCount[2] := 0;
			count_key.gSoriMode		:=	recMeisai.SHORI_MODE;	-- 処理モード
			count_key.gErrUmuFlg	:=	recMeisai.ERR_UMU_FLG;	-- エラー有無フラグ
			-- キークリア
			key.gIsinCd			:= ' ';
			key.gMgrCd			:= ' ';
			IF count_key.gErrUmuFlg = '0' THEN
				-- エラー銘柄件数データレコードを帳票ワークへ追加する
				gSeqNo := gSeqNo + 1;
						-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := recMeisai.SAKUSEI_YMD;	-- 作成年月日
		v_item.l_inItem003 := recMeisai.SHORI_TM;	-- 処理時刻
		v_item.l_inItem004 := recMeisai.SHORI_MODE;	-- 処理モード
		v_item.l_inItem005 := recMeisai.SHORI_MODE_NM;	-- 処理モード名称
		v_item.l_inItem006 := '1';	-- エラー有無フラグ
		v_item.l_inItem017 := KBN_NAME_ERROR;	-- 会計区分名称
		v_item.l_inItem018 := CASE WHEN count_key.gErrUmuFlg = '1' THEN gMgrCount[2] ELSE gMgrCount[1] END;
		v_item.l_inItem020 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem022 := wkShiyoMgrCdKbnNm;	-- 使用銘柄コード区分
		v_item.l_inItem027 := gItakuKaishaRnm;	-- 委託会社コード
		v_item.l_inItem028 := l_inGyomuYmd;	-- データ基準日
		
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
		END IF;
		IF count_key.gErrUmuFlg != recMeisai.ERR_UMU_FLG THEN
		-- エラー有無フラグでブレイク
			-- エラー残高履歴数データレコードを帳票ワークへ追加する
			gSeqNo := gSeqNo + 1;
					-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := recMeisai.SAKUSEI_YMD;	-- 作成年月日
		v_item.l_inItem003 := recMeisai.SHORI_TM;	-- 処理時刻
		v_item.l_inItem004 := recMeisai.SHORI_MODE;	-- 処理モード
		v_item.l_inItem005 := recMeisai.SHORI_MODE_NM;	-- 処理モード名称
		v_item.l_inItem006 := '1';	-- エラー有無フラグ
		v_item.l_inItem017 := KBN_NAME_ERROR;	-- 会計区分名称
		v_item.l_inItem018 := CASE WHEN count_key.gErrUmuFlg = '1' THEN gMgrCount[2] ELSE gMgrCount[1] END;
		v_item.l_inItem020 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem022 := wkShiyoMgrCdKbnNm;	-- 使用銘柄コード区分
		v_item.l_inItem027 := gItakuKaishaRnm;	-- 委託会社コード
		v_item.l_inItem028 := l_inGyomuYmd;	-- データ基準日
		
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
			count_key.gErrUmuFlg	:= recMeisai.ERR_UMU_FLG;				-- エラー有無フラグ
			-- キークリア
			key.gIsinCd			:= ' ';
			key.gMgrCd			:= ' ';
		END IF;
		-- エラー正常銘柄件数
		IF ((coalesce(wNo::text, '') = '') OR (recMeisai.SEQ_NO != wNo) OR (recMeisai.SEQ_NO IS NOT NULL))
		THEN
			IF recMeisai.ERR_UMU_FLG = '1' THEN
				gMgrCount[2] := gMgrCount[2] + 1;
			ELSE
				gMgrCount[1] := gMgrCount[1] + 1;
			END IF;
		END IF;
		-- シーケンスNo保存
		wSeqNo := recMeisai.SEQ_NO;
	    wNo := recMeisai.SEQ_NO;
		-- データレコードを帳票ワークへデータを追加
		gSeqNo := gSeqNo + 1;
		IF (trim(both recMeisai.TSUKA_CD) IS NOT NULL AND (trim(both recMeisai.TSUKA_CD))::text <> '')
		THEN
			SELECT TSUKA_NM
			INTO STRICT wkTsukaNm
			FROM MTSUKA
			WHERE TSUKA_CD = recMeisai.TSUKA_CD;
		ELSE
			wkTsukaNm := NULL;
		END IF;
    -- 銘柄コード＋ISINコード＋償還年月日＋償還区分でグループインディケーション
    IF coalesce(recMeisai.SEQ_NO::text, '') = '' THEN
	    wkSeqNoChar := ' ';
		recMeisai.ISIN_CD		:= NULL;
		recMeisai.MGR_CD		:= NULL;
		recMeisai.MGR_NM		:= NULL;
		recMeisai.SHOKAN_KBN	:= NULL;
		recMeisai.SHOKAN_YMD	:= NULL;
		recMeisai.SHOKAN_KBN_NM	:= NULL;
		recMeisai.DKJ_MGR_CD		:= NULL;
    ELSE
    	wkSeqNoChar := gRecCnt::text;
    END IF;
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := recMeisai.SAKUSEI_YMD;	-- 作成年月日
		v_item.l_inItem003 := recMeisai.SHORI_TM;	-- 処理時刻
		v_item.l_inItem004 := recMeisai.SHORI_MODE;	-- 処理モード
		v_item.l_inItem005 := recMeisai.SHORI_MODE_NM;	-- 処理モード名称
		v_item.l_inItem006 := recMeisai.ERR_UMU_FLG;	-- エラー有無フラグ
		v_item.l_inItem007 := wkSeqNoChar;	-- １からの通し番号
		v_item.l_inItem008 := recMeisai.ISIN_CD;	-- ISINコード
		v_item.l_inItem009 := recMeisai.MGR_CD;	-- 銘柄コード
		v_item.l_inItem010 := SUBSTR(recMeisai.MGR_NM,1,22);	-- 銘柄の正式名称（頭全角２２文字分）
		v_item.l_inItem011 := recMeisai.SHOKAN_YMD;	-- 償還年月日
		v_item.l_inItem012 := recMeisai.SHOKAN_KBN_NM;	-- 償還区分名称
		v_item.l_inItem013 := recMeisai.SHOKAN_KNGK;	-- 償還金額
		v_item.l_inItem014 := recMeisai.TSUKA_CD;	-- 通貨コード
		v_item.l_inItem015 := recMeisai.ERR_CD6;	-- エラーコード
		v_item.l_inItem016 := recMeisai.ERR_NM30;	-- エラー内容
		v_item.l_inItem020 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem021 := wkTsukaNm;	-- 発行通貨名称
		v_item.l_inItem022 := wkShiyoMgrCdKbnNm;	-- 使用銘柄コード区分
		v_item.l_inItem023 := recMeisai.DKJ_MGR_CD;	-- 独自銘柄コード
		v_item.l_inItem024 := recMeisai.SHOKAN_KBN;	-- 償還区分コード
		v_item.l_inItem025 := recMeisai.MEIMOKU_ZNDK;	-- 名目残高
		v_item.l_inItem026 := wkTsukaNm;	-- 発行通貨名称
		v_item.l_inItem027 := gItakuKaishaRnm;	-- 委託会社コード
		v_item.l_inItem028 := l_inGyomuYmd;	-- データ基準日
		
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
	IF gSeqNo = 0 THEN
		gRtnCd := RTN_NODATA;
		l_outSqlCode := gRtnCd;
		l_outSqlErrM := '';
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPK002K00R11 END (NO DATA)');	END IF;
		RETURN;
	END IF;
	IF count_key.gErrUmuFlg = '1' THEN
		-- エラー銘柄件数データを出力する
		gSeqNo := gSeqNo + 1;
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := recPrevMeisai.SAKUSEI_YMD;	-- 作成年月日
		v_item.l_inItem003 := recPrevMeisai.SHORI_TM;	-- 処理時刻
		v_item.l_inItem004 := recPrevMeisai.SHORI_MODE;	-- 処理モード
		v_item.l_inItem005 := recPrevMeisai.SHORI_MODE_NM;	-- 処理モード名称
		v_item.l_inItem006 := '1';	-- エラー有無フラグ
		v_item.l_inItem017 := KBN_NAME_ERROR;	-- 会計区分名称
		v_item.l_inItem018 := gMgrCount[2];
		v_item.l_inItem020 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem022 := wkShiyoMgrCdKbnNm;	-- 使用銘柄コード区分
		v_item.l_inItem027 := gItakuKaishaRnm;	-- 委託会社コード
		v_item.l_inItem028 := l_inGyomuYmd;	-- データ基準日
		
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
	-- 正常銘柄件数データを出力する
	gSeqNo := gSeqNo + 1;
			-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := recPrevMeisai.SAKUSEI_YMD;	-- 作成年月日
		v_item.l_inItem003 := recPrevMeisai.SHORI_TM;	-- 処理時刻
		v_item.l_inItem004 := recPrevMeisai.SHORI_MODE;	-- 処理モード
		v_item.l_inItem005 := recPrevMeisai.SHORI_MODE_NM;	-- 処理モード名称
		v_item.l_inItem006 := '0';	-- エラー有無フラグ
		v_item.l_inItem017 := KBN_NAME_NORMAL;	-- 会計区分名称
		v_item.l_inItem018 := gMgrCount[1];
		v_item.l_inItem020 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem022 := wkShiyoMgrCdKbnNm;	-- 使用銘柄コード区分
		v_item.l_inItem027 := gItakuKaishaRnm;	-- 委託会社コード
		v_item.l_inItem028 := l_inGyomuYmd;	-- データ基準日
		
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
	-- 総件数データを出力する
	gSeqNo := gSeqNo + 1;
			-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := recPrevMeisai.SAKUSEI_YMD;	-- 作成年月日
		v_item.l_inItem003 := recPrevMeisai.SHORI_TM;	-- 処理時刻
		v_item.l_inItem004 := recPrevMeisai.SHORI_MODE;	-- 処理モード
		v_item.l_inItem005 := recPrevMeisai.SHORI_MODE_NM;	-- 処理モード名称
		v_item.l_inItem017 := '総件数';	-- 会計区分名称
		v_item.l_inItem019 := gMgrCount[1] + gMgrCount[2];
		v_item.l_inItem020 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem022 := wkShiyoMgrCdKbnNm;	-- 使用銘柄コード区分
		v_item.l_inItem027 := gItakuKaishaRnm;	-- 委託会社コード
		v_item.l_inItem028 := l_inGyomuYmd;	-- データ基準日
		
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
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPK002K00R11 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	unique_violation THEN
		l_outSqlCode := RTN_DUP_VAL_ON_INDEX;
		l_outSqlErrM := SQLERRM;
	WHEN	OTHERS	THEN
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipk002k00r11 ( l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spipk002k00r11_getitakukaisharnm (l_inItakuKaishaCd text) RETURNS varchar AS $body$
DECLARE

	bankRnm		varchar(100) := NULL;

BEGIN
	-- 自行・委託会社情報から委託会社略称の取得
	SELECT	CASE WHEN JIKO_DAIKO_KBN='2' THEN  BANK_RNM  ELSE NULL END
	INTO STRICT	bankRnm
	FROM	VJIKO_ITAKU
	WHERE	KAIIN_ID = l_inItakuKaishaCd;
	RETURN bankRnm;
EXCEPTION
	WHEN OTHERS THEN
		RETURN bankRnm;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spipk002k00r11_getitakukaisharnm (l_inItakuKaishaCd text) FROM PUBLIC;