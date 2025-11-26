

-- TYPE definition commented out - will use RECORD type inside procedure instead
-- PostgreSQL does not support %TYPE in composite type definitions

DROP PROCEDURE IF EXISTS spip03801;

CREATE OR REPLACE PROCEDURE spip03801 ( 
 l_inHktCd TEXT,		-- 発行体コード
 l_inKozaTenCd TEXT,		-- 口座店コード
 l_inKozaTenCifCd TEXT,		-- 口座店CIFコード
 l_inMgrCd TEXT,		-- 銘柄コード
 l_inIsinCd TEXT,		-- ISINコード
 l_inJtkKbn TEXT,		-- 受託区分
 l_inSaikenKbn TEXT,		-- 債券種類
 l_inKkKanyoFlg TEXT,		-- 機関関与方式採用フラグ
 l_inShokanMethodCd TEXT,		-- 償還方法
 l_inTeijiShokanTsutiKbn TEXT,		-- 定時償還通知区分
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
--/* 概要　:事務帳票出力指示画面の入力条件により、受託銘柄一覧表を作成する。
--/* 引数　:l_inHktCd					IN	TEXT		発行体コード
--/* 　　　 l_inKozaTenCd				IN	TEXT		口座店コード
--/* 　　　 l_inKozaTenCifCd			IN	TEXT		口座店CIFコード
--/* 　　　 l_inMgrCd					IN	TEXT		銘柄コード
--/* 　　　 l_inIsinCd				IN	TEXT		ISINコード
--/* 　　　 l_inJtkKbn				IN	TEXT		受託区分
--/* 　　　 l_inSaikenKbn				IN	TEXT		債券種類
--/* 　　　 l_inKkKanyoFlg			IN	TEXT		機関関与方式採用フラグ
--/* 　　　 l_inShokanMethodCd		IN	TEXT		償還方法
--/* 　　　 l_inTeijiShokanTsutiKbn	IN	TEXT		定時償還通知区分
--/* 　　　 l_inItakuKaishaCd			IN	TEXT		委託会社コード
--/* 　　　 l_inUserId				IN	TEXT		ユーザーID
--/* 　　　 l_inChohyoKbn				IN	TEXT		帳票区分
--/* 　　　 l_inGyomuYmd				IN	TEXT		業務日付
--/* 　　　 l_outSqlCode				OUT	INTEGER		リターン値
--/* 　　　 l_outSqlErrM				OUT	VARCHAR	エラーコメント
--/* 返り値:なし
--/* @version $Id: SPIP03801.SQL,v 1.17 2006/10/11 08:16:18 yamashita Exp $
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.02.25	JIP				新規作成
--/*	2005.06.09	山田　安紘		IP-01283修正
--/*	2005.06.14	山田　安紘		IP-01284修正
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
	RTN_OK				CONSTANT integer		:= 0;				-- 正常
	RTN_NG				CONSTANT integer		:= 1;				-- 予期したエラー
	RTN_NODATA			CONSTANT integer		:= 2;				-- データなし
	RTN_FATAL			CONSTANT integer		:= 99;				-- 予期せぬエラー
	REPORT_ID			CONSTANT char(11)		:= 'IP030003811';	-- 帳票ID
	-- 書式フォーマット
	FMT_HAKKO_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	FMT_RBR_KNGK_J		CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 利払金額
	FMT_SHOKAN_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 償還金額
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd				integer :=	RTN_OK;						-- リターンコード
	gSeqNo				integer := 0;							-- シーケンス
	gSQL				varchar(3000) := NULL;				-- SQL編集
	-- DB取得項目
	recMeisai RECORD;								-- レコード (using RECORD type instead of custom type)
	gItakuKaishaRnm				varchar(40);					-- 委託会社略称
	-- カーソル
	curMeisai REFCURSOR;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp03801 START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inUserId)::text, '') = ''
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''
	OR coalesce(trim(both l_inGyomuYmd)::text, '') = ''
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', REPORT_ID, 'SQLERRM:'||'');
		RETURN;
	END IF;
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;
	-- SQL編集
	gSQL := '';
	gSQL := gSQL || 'SELECT VMG1.ISIN_CD,';							-- ＩＳＩＮコード
	gSQL := gSQL || '		VMG1.MGR_CD,';							-- 銘柄コード
	gSQL := gSQL || '		VMG1.MGR_RNM,';							-- 銘柄略称
	gSQL := gSQL || '		VMG1.HKT_CD,';							-- 発行体コード
	gSQL := gSQL || '		M01.HKT_RNM,';							-- 発行体略称
	gSQL := gSQL || '		VMG1.EIGYOTEN_CD,';						-- 営業店店番
	gSQL := gSQL || '		M041.BUTEN_RNM AS EIGYOTEN_NM,';		-- 営業店略称
	gSQL := gSQL || '		VMG1.KOZA_TEN_CIFCD,';					-- 口座店ＣＩＦコード
	gSQL := gSQL || '		VMG1.KOZA_TEN_CD,';						-- 口座店店番
	gSQL := gSQL || '		M042.BUTEN_RNM AS KOZA_TEN_NM,';		-- 口座店略称
	gSQL := gSQL || '		VMG1.HAKKO_YMD,';						-- 発行日
	gSQL := gSQL || '		VMG1.ST_RBR_KJT,';						-- 初回利払期日
	gSQL := gSQL || '		VMG1.FULLSHOKAN_KJT,';					-- 満期償還期日
	gSQL := gSQL || '		VMG1.SHASAI_TOTAL,';					-- 社債の総額
	gSQL := gSQL || '		M64.TSUKA_NM AS HAKKO_TSUKA_NM,';		-- 発行通貨名称
	gSQL := gSQL || '		VMG1.KAKUSHASAI_KNGK,';					-- 各社債の金額
	gSQL := gSQL || '		VMG1.RITSUKE_WARIBIKI_KBN_NM,';			-- 利付割引区分名称
	gSQL := gSQL || '		VMG1.NENRBR_CNT,';						-- 年利払回数
	gSQL := gSQL || '		(SELECT CODE_NM FROM SCODE WHERE VMG1.NENRBR_CNT = CODE_VALUE AND CODE_SHUBETSU = ''142'') AS NENRBR_CNT_NM,';	--	年利払回数名称
	gSQL := gSQL || '		CASE WHEN VMG1.RIRITSU = 0 THEN NULL ELSE VMG1.RIRITSU END,';		-- 利率
	gSQL := gSQL || '		CASE WHEN VMG1.TSUKARISHI_KNGK_FAST = 0 THEN NULL ELSE VMG1.TSUKARISHI_KNGK_FAST END,';	-- １通貨あたりの利息額（初期）
	gSQL := gSQL || '		CASE WHEN VMG1.TSUKARISHI_KNGK_NORM = 0 THEN NULL ELSE VMG1.TSUKARISHI_KNGK_NORM END,';	-- １通貨あたりの利息額（通常）
	gSQL := gSQL || '		CASE WHEN VMG1.TSUKARISHI_KNGK_LAST = 0 THEN NULL ELSE VMG1.TSUKARISHI_KNGK_LAST END,';	-- １通貨あたりの利息額（終期）
	gSQL := gSQL || '		VMG1.SHOKAN_METHOD_NM,';				-- 償還方法名称
	gSQL := gSQL || '		VMG1.PUTUMU_FLG,';						-- プットオプション有無フラグ
	gSQL := gSQL || '		(SELECT CODE_NM FROM SCODE WHERE VMG1.PUTUMU_FLG = CODE_VALUE AND CODE_SHUBETSU = ''101'') AS PUTUMU_FLG_NM ,';	-- プットオプション有無フラグ名称
	gSQL := gSQL || '		CASE ';
	gSQL := gSQL || '			WHEN VMG1.CALLALL_UMU_FLG = ''Y'' and VMG1.CALLITIBU_UMU_FLG = ''Y'' THEN ''全額・一部''';
	gSQL := gSQL || '			WHEN VMG1.CALLALL_UMU_FLG = ''Y'' and VMG1.CALLITIBU_UMU_FLG = ''N'' THEN ''全額''';
	gSQL := gSQL || '			WHEN VMG1.CALLALL_UMU_FLG = ''N'' and VMG1.CALLITIBU_UMU_FLG = ''Y'' THEN ''一部''';
	gSQL := gSQL || '			ELSE ''なし''';
	gSQL := gSQL || '		END AS CALL_UMU_FLG_NM,';				-- コールオプション有無フラグ名称
	gSQL := gSQL || '		(SELECT CODE_RNM FROM SCODE WHERE VMG1.KK_KANYO_FLG = CODE_VALUE AND CODE_SHUBETSU = ''505'') AS KIKO_FLG_NM ,';	-- 機構関与方式フラグ略称
	gSQL := gSQL || '		VMG1.BOSHU_KBN_RNM,';					-- 募集区分略称
	gSQL := gSQL || '		VMG1.SAIKEN_KBN_RNM,';					-- 債権種類略称
	gSQL := gSQL || '		VMG1.HOSHO_KBN_RNM,';					-- 保証区分略称
	gSQL := gSQL || '		VMG1.TANPO_KBN_RNM,';					-- 担保区分略称
	gSQL := gSQL || '		VMG1.JTK_KBN,';							-- 受託区分
	gSQL := gSQL || '		VMG1.JTK_KBN_NM,';						-- 受託区分名称
	gSQL := gSQL || '		pkipazndk.getKjnZndk(VMG1.ITAKU_KAISHA_CD,VMG1.MGR_CD ,''' || l_inGyomuYmd || ''' ,3)::numeric AS JISSHITSU_ZNDK,';	-- （振替債の）実質残高
	gSQL := gSQL || '		VJ1.BANK_RNM,';							-- 銀行略称
	gSQL := gSQL || '		VJ1.JIKO_DAIKO_KBN ';					-- 自行代行区分
	gSQL := gSQL || 'FROM 	VMGR_LIST VMG1,';						-- 銘柄情報一覧VIEW
	gSQL := gSQL || '		MGR_KIHON_VIEW VMG0,';					-- 銘柄基本VIEW
	gSQL := gSQL || '		MHAKKOTAI M01,';						-- 発行体マスタ
	gSQL := gSQL || '		VJIKO_ITAKU VJ1,';			 			-- 自行・委託会社VIEW
	gSQL := gSQL || '		MBUTEN M041,';							-- 部店マスタ
	gSQL := gSQL || '		MBUTEN M042,';							-- 部店マスタ
	gSQL := gSQL || '		MTSUKA M64 ';							-- 通貨マスタ
	gSQL := gSQL || 'WHERE 	VMG1.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' ';
	gSQL := gSQL || 'AND 	VMG1.ITAKU_KAISHA_CD = VMG0.ITAKU_KAISHA_CD ';
	gSQL := gSQL || 'AND 	VMG1.MGR_CD = VMG0.MGR_CD ';
	gSQL := gSQL || 'AND 	VMG1.HKT_CD = M01.HKT_CD ';
	gSQL := gSQL || 'AND 	VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD ';
	gSQL := gSQL || 'AND 	VMG1.ITAKU_KAISHA_CD = M041.ITAKU_KAISHA_CD ';
	gSQL := gSQL || 'AND 	VMG1.ITAKU_KAISHA_CD = M042.ITAKU_KAISHA_CD ';
	gSQL := gSQL || 'AND 	VJ1.KAIIN_ID = ''' || l_inItakuKaishaCd || ''' ';
	gSQL := gSQL || 'AND 	VMG1.EIGYOTEN_CD = M041.BUTEN_CD ';
	gSQL := gSQL || 'AND 	VMG1.KOZA_TEN_CD = M042.BUTEN_CD ';
	gSQL := gSQL || 'AND 	VMG1.HAKKO_TSUKA_CD = M64.TSUKA_CD ';
	gSQL := gSQL || 'AND 	VMG1.MGR_STAT_KBN = ''1'' ';
	gSQL := gSQL || 'AND 	TRIM(VMG1.ISIN_CD) IS NOT NULL ';
	gSQL := gSQL || 'AND	VMG0.HAKKO_YMD <= ''' || l_inGyomuYmd || ''' ';
	gSQL := gSQL || 'AND	VMG0.FULLSHOKAN_KJT >= ''' || l_inGyomuYmd || ''' ';
	gSQL := gSQL || 'AND	pkipazndk.getKjnZndk(VMG1.ITAKU_KAISHA_CD,VMG1.MGR_CD ,''' || l_inGyomuYmd ||''' ,3)::numeric > 0 ';
	IF (l_inHktCd IS NOT NULL AND l_inHktCd::text <> '') THEN
		gSQL := gSQL || 'AND 	VMG1.HKT_CD = ''' || l_inHktCd || ''' ';
	END IF;
	IF (l_inKozaTenCd IS NOT NULL AND l_inKozaTenCd::text <> '') THEN
		gSQL := gSQL || 'AND 	VMG1.KOZA_TEN_CD = ''' || l_inKozaTenCd || ''' ';
	END IF;
	IF (l_inKozaTenCifCd IS NOT NULL AND l_inKozaTenCifCd::text <> '') THEN
		gSQL := gSQL || 'AND 	VMG1.KOZA_TEN_CIFCD = ''' || l_inKozaTenCifCd || ''' ';
	END IF;
	IF (l_inMgrCd IS NOT NULL AND l_inMgrCd::text <> '') THEN
		gSQL := gSQL || 'AND 	VMG1.MGR_CD = ''' || l_inMgrCd || ''' ';
	END IF;
	IF (l_inIsinCd IS NOT NULL AND l_inIsinCd::text <> '') THEN
		gSQL := gSQL || 'AND 	VMG1.ISIN_CD = ''' || l_inIsinCd || ''' ';
	END IF;
	IF (l_inJtkKbn IS NOT NULL AND l_inJtkKbn::text <> '') THEN
		gSQL := gSQL || 'AND 	VMG1.JTK_KBN = ''' || l_inJtkKbn || ''' ';
	END IF;
	IF (l_inSaikenKbn IS NOT NULL AND l_inSaikenKbn::text <> '') THEN
		gSQL := gSQL || 'AND 	VMG1.SAIKEN_SHURUI = ''' || l_inSaikenKbn || ''' ';
	END IF;
	IF (l_inKkKanyoFlg IS NOT NULL AND l_inKkKanyoFlg::text <> '') THEN
		gSQL := gSQL || 'AND 	VMG1.KK_KANYO_FLG = ''' || l_inKkKanyoFlg || ''' ';
	END IF;
	IF (l_inShokanMethodCd IS NOT NULL AND l_inShokanMethodCd::text <> '') THEN
		gSQL := gSQL || 'AND 	VMG1.SHOKAN_METHOD_CD = ''' || l_inShokanMethodCd || ''' ';
	END IF;
	IF (l_inTeijiShokanTsutiKbn IS NOT NULL AND l_inTeijiShokanTsutiKbn::text <> '') THEN
		gSQL := gSQL || 'AND 	VMG1.TEIJI_SHOKAN_TSUTI_KBN = ''' || l_inTeijiShokanTsutiKbn || ''' ';
	END IF;
	gSQL := gSQL || 'ORDER BY 	VMG1.JTK_KBN,';
	gSQL := gSQL || '			VMG1.HKT_CD,';
	gSQL := gSQL || '			VMG1.ISIN_CD ';
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	-- カーソルオープン
	OPEN curMeisai FOR EXECUTE gSQL;
	-- データ取得
	LOOP
		FETCH curMeisai INTO recMeisai;
		EXIT WHEN NOT FOUND;/* apply on curMeisai */
		gSeqNo := gSeqNo + 1;
		-- 委託会社略称
		gItakuKaishaRnm := NULL;
		IF recMeisai.gJikoDaikoKbn = '2' THEN
			gItakuKaishaRnm := recMeisai.gBankRnm;
		END IF;
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- 入力ユーザＩＤ
		v_item.l_inItem002 := recMeisai.gJtkKbnNm;	-- 受託区分名称
		v_item.l_inItem003 := gSeqNo;	-- ＮＯ
		v_item.l_inItem004 := recMeisai.gIsinCd;	-- ＩＳＩＮコード
		v_item.l_inItem005 := recMeisai.gMgrCd;	-- 銘柄コード
		v_item.l_inItem006 := recMeisai.gMgrRnm;	-- 銘柄略称
		v_item.l_inItem007 := recMeisai.gHktCd;	-- 発行体コード
		v_item.l_inItem008 := recMeisai.gHktRnm;	-- 発行体略称
		v_item.l_inItem009 := recMeisai.gEigyotenCd;	-- 営業店店番
		v_item.l_inItem010 := recMeisai.gEigyotenNm;	-- 営業店略称
		v_item.l_inItem011 := recMeisai.gKozaTenCifcd;	-- 口座店ＣＩＦコード
		v_item.l_inItem012 := recMeisai.gKozaTenCd;	-- 口座店店番
		v_item.l_inItem013 := recMeisai.gKozaTenNm;	-- 口座店略称
		v_item.l_inItem014 := recMeisai.gHakkoYmd;	-- 発行日
		v_item.l_inItem015 := recMeisai.gStRbrKjt;	-- 初回利払期日
		v_item.l_inItem016 := recMeisai.gFullshokanKjt;	-- 満期償還期日
		v_item.l_inItem017 := recMeisai.gShasaiTotal;	-- 社債の総額
		v_item.l_inItem018 := recMeisai.gHakkoTsukaNm;	-- 発行通貨名称
		v_item.l_inItem019 := recMeisai.gKakushasaiKngk;	-- 各社債の金額
		v_item.l_inItem020 := recMeisai.gHakkoTsukaNm;	-- 発行通貨名称
		v_item.l_inItem021 := recMeisai.gRitsukeWaribikiKbnNm;	-- 利付割引区分名称
		v_item.l_inItem022 := recMeisai.gNenrbrCnt;	-- 年利払回数
		v_item.l_inItem023 := recMeisai.gRiritsu;	-- 利率
		v_item.l_inItem024 := recMeisai.gTsukarishiKngkFast;	-- １通貨あたりの利息額（初期）
		v_item.l_inItem025 := recMeisai.gTsukarishiKngkNorm;	-- １通貨あたりの利息額（通常）
		v_item.l_inItem026 := recMeisai.gTsukarishiKngkLast;	-- １通貨あたりの利息額（終期）
		v_item.l_inItem027 := recMeisai.gShokanMethodNm;	-- 償還方法名称
		v_item.l_inItem028 := recMeisai.gPutumuFlgNm;	-- プットオプション有無フラグ名称
		v_item.l_inItem029 := recMeisai.gCallUmuFlgNm;	-- コールオプション有無フラグ名称
		v_item.l_inItem030 := recMeisai.gBoshuKbnRnm;	-- 募集区分略称
		v_item.l_inItem031 := recMeisai.gSaikenKbnRnm;	-- 債権種類略称
		v_item.l_inItem032 := recMeisai.gHoshoKbnRnm;	-- 保証区分略称
		v_item.l_inItem033 := recMeisai.gTanpoKbnRnm;	-- 担保区分略称
		v_item.l_inItem034 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem035 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem036 := FMT_HAKKO_KNGK_J;	-- 発行金額書式フォーマット
		v_item.l_inItem037 := FMT_RBR_KNGK_J;	-- 利払金額書式フォーマット
		v_item.l_inItem038 := FMT_SHOKAN_KNGK_J;	-- 償還金額書式フォーマット
		v_item.l_inItem040 := recMeisai.gJtkKbn;	-- 受託区分
		v_item.l_inItem041 := recMeisai.gNenrbrCntNm;	-- 年利払回数名称
		v_item.l_inItem042 := recMeisai.gKikoFlgNm;	-- 機構関与方式採用フラグ略称
		
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
	END LOOP;
	CLOSE curMeisai;
	IF gSeqNo = 0 THEN
		-- 対象データなし
		gRtnCd := RTN_NODATA;
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;
		v_item.l_inItem035 := REPORT_ID;
		v_item.l_inItem036 := FMT_HAKKO_KNGK_J;
		v_item.l_inItem037 := FMT_RBR_KNGK_J;
		v_item.l_inItem038 := FMT_SHOKAN_KNGK_J;
		v_item.l_inItem039 := '対象データなし';
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> 1,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp03801 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		BEGIN
			CLOSE curMeisai;
		EXCEPTION
			WHEN OTHERS THEN NULL;
		END;
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
--		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip03801 ( l_inHktCd TEXT, l_inKozaTenCd TEXT, l_inKozaTenCifCd TEXT, l_inMgrCd TEXT, l_inIsinCd TEXT, l_inJtkKbn TEXT, l_inSaikenKbn TEXT, l_inKkKanyoFlg TEXT, l_inShokanMethodCd TEXT, l_inTeijiShokanTsutiKbn TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;


