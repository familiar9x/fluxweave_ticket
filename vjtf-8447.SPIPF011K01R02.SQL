




CREATE OR REPLACE PROCEDURE spipf011k01r02 ( l_inItakuKaishaCd TEXT,		-- 委託会社コード
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
--/* 概要　:元利金請求明細テーブルの内容を基に、決済日当日の朝バッチ処理にて日銀当預支払依頼未作成リスト作成する。
--/* 引数　:l_inItakuKaishaCd	IN	TEXT		委託会社コード
--/* 　　　 l_inUserId		IN	TEXT		ユーザーID
--/* 　　　 l_inChohyoKbn		IN	TEXT		帳票区分
--/* 　　　 l_inGyomuYmd		IN	TEXT		業務日付
--/* 　　　 l_outSqlCode		OUT	INTEGER		リターン値
--/* 　　　 l_outSqlErrM		OUT	VARCHAR	エラーコメント
--/* 返り値:なし
--/* @version $Revision: 1.15 $
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* ------------------------------------------------------------------------
--/*　2005.05.17	JIP				新規作成
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
	REPORT_ID			CONSTANT text	:= 'IPF30001121';			-- 帳票ID
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd				integer :=	RTN_OK;							-- リターンコード
	gSeqNo				integer := 0;								-- シーケンス
--	nCount				NUMERIC;									--件数取得
	-- 合計金額計算用
	gKingaku			numeric	:= 0;								-- 決済金額の合計
	gShiharai_YMD		varchar(8);									-- 支払日格納
	-- 帳票ワークデータ比較用
	hItakuKaishaCd		varchar(4);									-- 委託会社コード
	hMgrCd			varchar(13);									-- 銘柄コード
	hShrYmd			varchar(8);									-- 支払日
	hTsukaCd		varchar(3);									-- 通貨コード
	hFinSecKbn		varchar(1);									-- 金融証券区分
	hBankCd			varchar(4);									-- 金融機関コード
	hKozaKbn		varchar(2);									-- 口座区分
	hTaxKbn			varchar(2);									-- 税区分
	hKessaiNo		varchar(16);									-- 決済番号
	-- 合計件数表示用
	wSeqNo				integer := 0;								-- シーケンス
--==============================================================================
--					カーソル定義													
--==============================================================================
	curMeisai CURSOR FOR
	SELECT	DISTINCT K01.SHR_YMD AS SHR_YMD,					-- 決済日
			 (K01.AITE_SKN_KESSAI_BCD || K01.AITE_SKN_KESSAI_SCD)
			 AS AITE_SKN_KESSAI_CD,						-- 資金決済会社コード
			 (M02.BANK_RNM || M03.SHITEN_RNM)
			 AS KESSAI_KAI_RNM,						-- 相手側資金決済会社略称
			 K01.KESSAI_NO AS KESSAI_NO,					-- 決済番号
			 (K01.SHOKAN_SEIKYU_KNGK + K01.GZEIHIKI_AFT_CHOKYU_KNGK)
			 AS KESSAI_GAKU,						-- 決済金額
			 M01.HKT_CD AS HKT_CD,						-- 発行体コード
			 M01.KOZA_TEN_CD AS KOZA_TEN_CD,				-- 口座店コード
			 M01.KOZA_TEN_CIFCD AS KOZA_TEN_CIFCD,				-- 口座店ＣＩＦコード
			 M01.HKT_KANA_RNM AS HKT_KANA_RNM,				-- 発行体略称
			 MG1.ISIN_CD AS ISIN_CD,					-- ＩＳＩＮコード
			 K01.MGR_CD AS MGR_CD,						-- 銘柄コード
			 MG1.MGR_RNM AS MGR_RNM,					-- 銘柄略称
			 K02.KKN_NYUKIN_KNGK AS KKN_NYUKIN_KNGK,			-- 元利払基金請求額
			 K01.KOBETSU_SHONIN_SAIYO_FLG AS KOBETSU_SHONIN_SAIYO_FLG,	-- 個別採用フラグ
			 coalesce(MCD1.CODE_NM,' ') AS KOBETSU_SHONIN_SAIYO_NM,		-- 個別承認採用フラグ
			 K02.IDO_YMD AS IDO_YMD,					-- 徴求日
			 MG1.KOZA_FURI_KBN AS KOZA_FURI_KBN,				-- 口座振替区分
			 S06.KOZA_FURI_KBN_NM AS KOZA_FURI_KBN_NM,			-- 口座振替区分名称
			 K02.NYUKIN_STS_KBN AS NYUKIN_STS_KBN,				-- 入金状況区分
			 MCD2.CODE_NM AS NYUKIN_STS_NM,					-- 入金状況区分名称
			 K02.SHORI_KBN AS SHORI_KBN,					-- 処理区分
			 MCD3.CODE_NM AS SHORI_NM,					-- 処理区分名称
			 K01.TSUKA_CD AS TSUKA_CD,					-- 通貨コード
			 K01.FINANCIAL_SECURITIES_KBN AS FINANCIAL_SECURITIES_KBN,	-- 金融証券区分
			 K01.BANK_CD AS BANK_CD,					-- 金融機関コード
			 K01.KOZA_KBN AS KOZA_KBN,					-- 口座区分
			 K01.TAX_KBN AS TAX_KBN,					-- 税区分
			 K02.KKN_IDO_KBN AS KKN_IDO_KBN 					-- 基金異動区分
		FROM sown_info sc18, (SELECT * FROM SCODE WHERE CODE_SHUBETSU = '713' ) mcd3, (SELECT * FROM SCODE WHERE CODE_SHUBETSU = '145' ) mcd2, (SELECT  
				K001.KESSAI_NO AS KESSAI_NO 	-- 決済金額
			FROM KIKIN_IDO K002,
				KIKIN_SEIKYU K001
			WHERE K001.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		 AND	 K001.ITAKU_KAISHA_CD = K002.ITAKU_KAISHA_CD
		 AND	 K001.MGR_CD = K002.MGR_CD
		 AND	 pkDate.getMinusDateBusiness(K001.SHR_YMD, 1) = l_inGyomuYmd
		 AND	 K001.SHR_YMD = K002.RBR_YMD
		 AND	 K002.ITAKU_KAISHA_CD = l_inItakuKaishaCd
				    AND pkDate.getMinusDateBusiness(K002.RBR_YMD, 1) = l_inGyomuYmd
				    AND K002.TSUKA_CD = 'JPY'
				    AND K002.KKN_IDO_KBN IN ('11','21')
		 AND	 K001.DVP_KBN = '1'
		 AND (K001.KOBETSU_SHONIN_SAIYO_FLG = 'Y' OR (K001.KOBETSU_SHONIN_SAIYO_FLG = 'N' AND K002.DATA_SAKUSEI_KBN = '0'))
		 AND	 K002.SHORI_KBN = '0' ) k02a, kikin_ido k02, kikin_seikyu k01
LEFT OUTER JOIN mbank_shiten_zokusei m04 ON (K01.ITAKU_KAISHA_CD = M04.ITAKU_KAISHA_CD AND K01.AITE_SKN_KESSAI_BCD || K01.AITE_SKN_KESSAI_SCD = M04.SKN_KESSAI_CD)
LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = '511' ) mcd1 ON (K01.KOBETSU_SHONIN_SAIYO_FLG = MCD1.CODE_VALUE)
LEFT OUTER JOIN mbank_shiten m03 ON (M04.BANK_CD = M03.BANK_CD AND M04.SHITEN_CD = M03.SHITEN_CD AND M04.FINANCIAL_SECURITIES_KBN = M03.FINANCIAL_SECURITIES_KBN)
LEFT OUTER JOIN mbank m02 ON (M03.BANK_CD = M02.BANK_CD AND M03.FINANCIAL_SECURITIES_KBN = M02.FINANCIAL_SECURITIES_KBN)
, mgr_kihon mg1
LEFT OUTER JOIN koza_frk s06 ON (MG1.ITAKU_KAISHA_CD = S06.ITAKU_KAISHA_CD AND MG1.KOZA_FURI_KBN = S06.KOZA_FURI_KBN)
LEFT OUTER JOIN mhakkotai m01 ON (MG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD AND MG1.HKT_CD = M01.HKT_CD)
WHERE K01.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND pkDate.getMinusDateBusiness(K01.SHR_YMD, 1) = l_inGyomuYmd AND K01.KESSAI_NO = K02A.KESSAI_NO AND K01.ITAKU_KAISHA_CD = K02.ITAKU_KAISHA_CD AND K01.MGR_CD = K02.MGR_CD AND K01.SHR_YMD = K02.RBR_YMD AND K02.KKN_IDO_KBN IN ('11','21') AND K01.ITAKU_KAISHA_CD = SC18.KAIIN_ID AND K01.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD AND K01.MGR_CD = MG1.MGR_CD        AND K01.DVP_KBN = '1' AND K02.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD AND K02.MGR_CD = MG1.MGR_CD        ORDER BY SHR_YMD,
			 AITE_SKN_KESSAI_CD,
			 KESSAI_NO,
			 ISIN_CD,
			 MGR_CD,
			 HKT_CD,
			 KOZA_TEN_CD,
			 KOZA_TEN_CIFCD,
			 TSUKA_CD,
			 FINANCIAL_SECURITIES_KBN,
			 BANK_CD,
			 KOZA_KBN,
			 TAX_KBN,
			 KESSAI_GAKU,
			 KKN_IDO_KBN;
	
--==============================================================================
--	メイン処理																	    
--==============================================================================
BEGIN
--	制作時、ログを出力する。パッケージ使用		
	IF DEBUG = 1 THEN	
		CALL pkLog.debug(l_inUserId, REPORT_ID, 'IPF011K01R02 START');	
	END IF;
	-- 入力パラメタ(委託会社コード)のチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF011K01R02', '＜項目名称:委託会社コード＞'||'＜項目値:'||l_inItakuKaishaCd||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(ユーザＩＤ)のチェック
	IF coalesce(trim(both l_inUserId)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF011K01R02', '＜項目名称:ユーザＩＤ＞'||'＜項目値:'||l_inUserId||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(帳票区分)のチェック
	IF coalesce(trim(both l_inChohyoKbn)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF011K01R02', '＜項目名称:帳票区分＞'||'＜項目値:'||l_inChohyoKbn||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(業務日付)のチェック
	IF coalesce(trim(both l_inGyomuYmd)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF011K01R02', '＜項目名称:業務日付＞'||'＜項目値:'||l_inGyomuYmd||'＞');
		RETURN;
	END IF;
	-- 帳票ワークの削除
	DELETE FROM	SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;
	-- ヘッダーレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	-- デ−タ取得
	FOR recMeisai IN curMeisai LOOP
		gSeqNo := gSeqNo + 1;
	--同一データが存在しない場合、合計件数、合計金額加算
	IF 	hItakuKaishaCd = l_inItakuKaishaCd
	 AND	hMgrCd = recMeisai.MGR_CD
	 AND	hShrYmd = recMeisai.SHR_YMD
	 AND	hTsukaCd = recMeisai.TSUKA_CD
	 AND	hFinSecKbn = recMeisai.FINANCIAL_SECURITIES_KBN
	 AND	hBankCd = recMeisai.BANK_CD
	 AND	hKozaKbn = recMeisai.KOZA_KBN
	 AND	hTaxKbn = recMeisai.TAX_KBN
	 AND	hKessaiNo = recMeisai.KESSAI_NO
	THEN
		gKingaku := gKingaku;
		wSeqNo := wSeqNo;
	ELSE
		gKingaku := gKingaku + recMeisai.KESSAI_GAKU;
		wSeqNo := wSeqNo + 1;
	END IF;
		gShiharai_YMD := recMeisai.SHR_YMD;
	--同一データが存在し、先頭行でない場合
	IF 	hItakuKaishaCd = l_inItakuKaishaCd
	 AND	hMgrCd = recMeisai.MGR_CD
	 AND	hShrYmd = recMeisai.SHR_YMD
	 AND	hTsukaCd = recMeisai.TSUKA_CD
	 AND	hFinSecKbn = recMeisai.FINANCIAL_SECURITIES_KBN
	 AND	hBankCd = recMeisai.BANK_CD
	 AND	hKozaKbn = recMeisai.KOZA_KBN
	 AND	hTaxKbn = recMeisai.TAX_KBN
	 AND	hKessaiNo = recMeisai.KESSAI_NO
--	 AND	MOD(gSeqNo,18) != 1 
	THEN
		-- 帳票ワークへデータ追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := l_inGyomuYmd;	-- 業務日付
		v_item.l_inItem004 := recMeisai.SHR_YMD;	-- 決済日
		v_item.l_inItem016 := recMeisai.KKN_NYUKIN_KNGK;	-- 元利払基金請求額
		v_item.l_inItem019 := recMeisai.IDO_YMD;	-- 徴求日
		v_item.l_inItem020 := recMeisai.KOZA_FURI_KBN;	-- 口座振替区分
		v_item.l_inItem021 := recMeisai.KOZA_FURI_KBN_NM;	-- 入金方法
		v_item.l_inItem022 := recMeisai.NYUKIN_STS_KBN;	-- 入金状況区分
		v_item.l_inItem023 := recMeisai.NYUKIN_STS_NM;	-- 入金状況名称
		v_item.l_inItem024 := recMeisai.SHORI_KBN;	-- 処理区分
		v_item.l_inItem025 := recMeisai.SHORI_NM;	-- 処理区分名称
		v_item.l_inItem028 := REPORT_ID;	-- 帳票ＩＤ
		
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
	--同一のデータが存在しない場合
	ELSE
		-- 帳票ワークへデータ追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := l_inGyomuYmd;	-- 業務日付
		v_item.l_inItem004 := recMeisai.SHR_YMD;	-- 決済日
		v_item.l_inItem005 := recMeisai.AITE_SKN_KESSAI_CD;	-- 資金決済会社コード
		v_item.l_inItem006 := recMeisai.KESSAI_KAI_RNM;	-- 相手側資金決済会社略称
		v_item.l_inItem007 := recMeisai.KESSAI_NO;	-- 決済番号
		v_item.l_inItem008 := recMeisai.KESSAI_GAKU;	-- 決済金額
		v_item.l_inItem009 := recMeisai.HKT_CD;	-- 発行体コード
		v_item.l_inItem010 := recMeisai.KOZA_TEN_CD;	-- 口座店コード
		v_item.l_inItem011 := recMeisai.KOZA_TEN_CIFCD;	-- 口座店ＣＩＦコード
		v_item.l_inItem012 := recMeisai.HKT_KANA_RNM;	-- 発行体略称
		v_item.l_inItem013 := recMeisai.ISIN_CD;	-- ＩＳＩＮコード
		v_item.l_inItem014 := recMeisai.MGR_CD;	-- 銘柄コード
		v_item.l_inItem015 := recMeisai.MGR_RNM;	-- 銘柄略称
		v_item.l_inItem016 := recMeisai.KKN_NYUKIN_KNGK;	-- 元利払基金請求額
		v_item.l_inItem017 := recMeisai.KOBETSU_SHONIN_SAIYO_FLG;	-- 個別承認採用フラグ
		v_item.l_inItem018 := recMeisai.KOBETSU_SHONIN_SAIYO_NM;	-- 個別採用フラグ内容
		v_item.l_inItem019 := recMeisai.IDO_YMD;	-- 徴求日
		v_item.l_inItem020 := recMeisai.KOZA_FURI_KBN;	-- 口座振替区分
		v_item.l_inItem021 := recMeisai.KOZA_FURI_KBN_NM;	-- 入金方法
		v_item.l_inItem022 := recMeisai.NYUKIN_STS_KBN;	-- 入金状況区分
		v_item.l_inItem023 := recMeisai.NYUKIN_STS_NM;	-- 入金状況名称
		v_item.l_inItem024 := recMeisai.SHORI_KBN;	-- 処理区分
		v_item.l_inItem025 := recMeisai.SHORI_NM;	-- 処理区分名称
		v_item.l_inItem028 := REPORT_ID;	-- 帳票ＩＤ
		
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
		--同一データ比較用変数にデータ格納
		hItakuKaishaCd := l_inItakuKaishaCd;
		hMgrCd := recMeisai.MGR_CD;
		hShrYmd := recMeisai.SHR_YMD;
		hTsukaCd := recMeisai.TSUKA_CD;
		hFinSecKbn := recMeisai.FINANCIAL_SECURITIES_KBN;
		hBankCd := recMeisai.BANK_CD;
		hKozaKbn := recMeisai.KOZA_KBN;
		hTaxKbn := recMeisai.TAX_KBN;
		hKessaiNo := recMeisai.KESSAI_NO;
	END LOOP;	
	IF gSeqNo = 0 THEN
		gRtnCd := RTN_NODATA;
	ELSE
		gSeqNo := gSeqNo + 1;
		-- 帳票ワークへ合計データ追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := l_inGyomuYmd;	-- 業務日付
		v_item.l_inItem004 := gShiharai_YMD;	-- 決済日
		v_item.l_inItem026 := wSeqNo;	-- 決済番号の合計件数
		v_item.l_inItem027 := gKingaku;	-- 決済金額の合計
		v_item.l_inItem028 := REPORT_ID;	-- 帳票ＩＤ
		
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
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||pkcharacter.numeric_to_char(gSeqNo));	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'IPF011K01R02 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS THEN
			CALL pkLog.fatal('ECM701', 'IPF011K01R02', 'SQLERRM:'||SQLERRM||'('||SQLSTATE||')');
			l_outSqlCode := RTN_FATAL;
			l_outSqlErrM := SQLERRM;
--		RAISE;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipf011k01r02 ( l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;
