


DROP TYPE IF EXISTS spip06701_01_type_record;
CREATE TYPE spip06701_01_type_record AS (
		gHktCd					text					-- 発行体コード
		,gSfskPostNo			char(7)					-- 送付先郵便番号
		,gAdd1					varchar(50)				-- 送付先住所１
		,gAdd2					varchar(50)				-- 送付先住所２
		,gAdd3					varchar(50)				-- 送付先住所３
		,gHktNm					varchar(100)			-- 発行体名称
		,gSfskBushoNm			varchar(50)				-- 送付先担当部署名称
		,gHakkoTsukaNm			char(3)					-- 発行通貨名称
		,gHakkoTsukaCd			char(3)					-- 発行通貨コード
		,gIsinCd				varchar(12)				-- ＩＳＩＮコード
		,gKokyakuMgrRnm			varchar(40)				-- 対顧用銘柄略称
		,gShasaiTotal			numeric(16)				-- 社債の総額
		,gRitsukeWaribikiKbn	char(1)					-- 利付割引区分
		,gRiritsu				numeric(6,3)			-- 利率
		,gShokanMethodCd		char(1)					-- 償還方法コード
		,gShokanMethodNm		varchar(20)				-- 償還方法名称
		,gFullshokanKjt			char(8)					-- 満期償還期日
		,gZndk 					numeric(14)				-- 残高
		,gMgrCd                 varchar(13)				-- 銘柄コード
		,gKkKnyoFlg				char(1)					-- 機構関与フラグ
		,gTshokanTsutiKbn       char(1)					-- 定時償還通知区分
		,gKozaTenCd             text					-- 口座店コード
		,gKozaTenCifcd          char(11)				-- 口座店ＣＩＦコード
	);
DROP TYPE IF EXISTS spip06701_01_type_key;
CREATE TYPE spip06701_01_type_key AS (
		gHktCd					text					-- 発行体コード
		,gHakkoTsukaCd			char(3)					-- 発行通貨コード
	);
DROP TYPE IF EXISTS spip06701_01_type_gokei;
CREATE TYPE spip06701_01_type_gokei AS (
		gShasaiTotal			numeric(16)				-- 社債の総額
		,gZndk 					numeric(16)				-- 残高
	);


CREATE OR REPLACE PROCEDURE spip06701_01 ( 
	l_inUserId TEXT,		-- ユーザーID
 l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inKijunYmdF TEXT,		-- 基準日(FROM)
 l_inHktCd TEXT,		-- 発行体コード
 l_inKozaTenCd TEXT,		-- 口座店コード
 l_inKozaTenCifCd TEXT,		-- 口座店CIFコード
 l_inTsuchiYmd TEXT,		-- 通知日
 l_outSqlCode OUT integer,		-- リターン値
 l_outSqlErrM OUT text	-- エラーコメント
 ) AS $body$
DECLARE

--
--/* 著作権:Copyright(c)2004
--/* 会社名:JIP
--/* 概要　:顧客宛帳票出力指示画面の入力条件により、債券残高証明書を作成する。
--/*
--/* @author	yoshisue
--/* @version $Id: SPIP06701_01.SQL,v 1.5 2008/12/16 09:37:37 watanabe_t Exp $
--/*
--/* @parama  l_inUserId			IN	TEXT,		-- ユーザーID
--/* @parama  l_inItakuKaishaCd	IN	TEXT,		-- 委託会社コード
--/* @parama  l_inKijunYmdF		IN	TEXT,		-- 基準日(FROM)
--/* @parama  l_inHktCd			IN	TEXT,		-- 発行体コード
--/* @parama  l_inKozaTenCd		IN	TEXT,		-- 口座店コード
--/* @parama  l_inKozaTenCifCd	IN	TEXT,		-- 口座店CIFコード
--/* @parama  l_inTsuchiYmd		IN	TEXT,		-- 通知日
--/* @parama  l_outSqlCode		OUT	NUMERIC,		-- リターン値
--/* @parama  l_outSqlErrM		OUT	VARCHAR	-- エラーコメント
--/* @return	なし
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.03.03	JIP				新規作成
--/*  2005.08.27  yoshisue		1.2次リリースにむけて引数等修正
--/*	2005.09.21  yoshisue		IP-02216 帳票ワークテーブルにINSERTする際、
--/*										 発行体コードをセットするように修正
--/*	2005.09.22  fujie			IP-02218 承認済の銘柄のみ出力されるように修正
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
	REPORT_ID			CONSTANT char(11)		:= 'IP030006711';	-- 帳票ID
	REAL_KBN			CONSTANT char(1)		:= '0';				-- 帳票区分（「0：リアル」固定）
	JOPTION_CD			CONSTANT varchar(15)   := 'IPP1003302010';-- 実質記番号管理オプションコード
	JISSITU_MGR			CONSTANT char(1)		:= '2';				-- 実質記番号銘柄
	TEIJI_SHO_CD		CONSTANT char(1)		:= '2';				-- 定時償還
	
	-- 書式フォーマット
	FMT_HAKKO_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	FMT_RBR_KNGK_J		CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 利払金額
	FMT_SHOKAN_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 償還金額
	FMT_HAKKO_KNGK_J_TOTAL	CONSTANT char(21)	:= 'Z,ZZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額合計フォーマット
	FMT_RBR_KNGK_J_TOTAL	CONSTANT char(21)	:= 'Z,ZZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 利払金額合計フォーマット
	FMT_SHOKAN_KNGK_J_TOTAL	CONSTANT char(21)	:= 'Z,ZZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 償還金額合計フォーマット
	SHONIN              CONSTANT char(1) := '1';  -- 処理区分（承認）
	NOT_MASSHO          CONSTANT char(1) := '0';  -- 抹消フラグ（未抹消）
												--平成10年10月10日
	TSUCHI_YMD_DEF      CONSTANT char(16)   := '　　  年  月  日';	-- 通知日（デフォルト）
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd				integer :=	RTN_OK;					-- リターンコード
	gSeqNo				integer := 0;							-- シーケンス
	gSeqNoIni			integer := 0;							-- シーケンス
	gGyomuYmd			char(8);									-- 業務日付
	gHktCd				text;						-- 合計行をINSERTする時の改ページ条件となる発行体コード
	gOptionFlg			char(1);				-- オプションフラグ
	gTeijiShoNm			varchar(20);			-- 定時償還名称
	
	-- DB取得項目
	recMeisai spip06701_01_type_record;							-- レコード
	gWrkTsuchiYmd			varchar(16);								-- 通知日(西暦)
	gWrkKijunYmd			varchar(16);								-- 基準日(西暦)
	jikoBankNm              varchar(100);
	jikoBushoNm1            varchar(50);
	-- 宛名編集
	gAtena					varchar(200) := NULL;					-- 宛名1行目
	gOutflg					integer := 0;							-- 正常処理フラグ
	gChohyoSortFlg		varchar(1);					-- 発行体宛帳票ソート順変更フラグ
	gRedOptionFlg           char(1);              -- レッドプロジェクトオプションフラグ
	gSQL					varchar(10000);						-- SQL for dynamic cursor
	-- キー
	key spip06701_01_type_key;									-- キー
	gokei spip06701_01_type_gokei;									-- 合計
	recPrevMeisai spip06701_01_type_record;								-- 前レコード
	-- カーソル
	curMeisai REFCURSOR;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIP06701_01 START');	END IF;
	-- 変数の初期化
	key.gHktCd := ' ';
	key.gHakkoTsukaCd := ' ';
	gokei.gShasaiTotal := 0;
	gokei.gZndk := 0;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inKijunYmdF)::text, '') = ''
	OR coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inUserId)::text, '') = ''
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', REPORT_ID, 'SQLERRM:'||'');
		RETURN;
	END IF;
    -- 業務日付を取得する
    gGyomuYmd := PKDATE.getGyomuYmd();
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = REAL_KBN
	AND		SAKUSEI_YMD = gGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;
	-- 通知日の西暦変換
	IF (trim(both l_inTsuchiYmd) IS NOT NULL AND (trim(both l_inTsuchiYmd))::text <> '') THEN
		gWrkTsuchiYmd := pkDate.seirekiChangeSuppressNenGappi(l_inTsuchiYmd);
	ELSE
		gWrkTsuchiYmd := TSUCHI_YMD_DEF;
	END IF;
	-- 基準日の西暦変換
	gWrkKijunYmd := pkDate.seirekiChangeSuppressNenGappi(l_inKijunYmdF);
	-- 自行情報の取得
	SELECT BANK_NM, BUSHO_NM1 INTO STRICT jikoBankNm, jikoBushoNm1 FROM VJIKO_ITAKU WHERE KAIIN_ID = l_inItakuKaishaCd;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, REAL_KBN, gGyomuYmd, REPORT_ID);
	-- 連番取得
	SELECT	coalesce(MAX(SEQ_NO), 0)
	INTO STRICT	gSeqNoIni
	FROM	SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = REAL_KBN
	AND		SAKUSEI_YMD = gGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;
	-- 実質記番号オプションフラグ取得
	gOptionFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd, JOPTION_CD, '0');
	-- 定時償還コードの名称を取得
	SELECT CODE_NM INTO STRICT gTeijiShoNm
	  FROM SCODE
	 WHERE CODE_VALUE = TEIJI_SHO_CD AND 
	       CODE_SHUBETSU = '116';
	--発行体宛帳票ソート順変更フラグ取得
	gChohyoSortFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'SeikyusyoSort', '0');
	-- レッドプロジェクトオプションフラグ取得
	gRedOptionFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd, 'REDPROJECT', '0');
	-- SQL構築
	gSQL := 'SELECT	VMG1.HKT_CD,'												-- 発行体コード
				 || '		M01.SFSK_POST_NO,'											-- 送付先郵便番号
				 || '		M01.ADD1,'													-- 送付先住所１
				 || '		M01.ADD2,'													-- 送付先住所２
				 || '		M01.ADD3,'													-- 送付先住所３
				 || '		M01.HKT_NM,'													-- 発行体名称
				 || '		M01.SFSK_BUSHO_NM,'											-- 送付先担当部署名称
				 || '		(SELECT TSUKA_NM FROM MTSUKA WHERE VMG1.HAKKO_TSUKA_CD = TSUKA_CD) AS HAKKO_TSUKA_NM,'		-- 発行通貨名称
				 || '		VMG1.HAKKO_TSUKA_CD,'										-- 発行通貨コード
				 || '		VMG1.ISIN_CD,'												-- ＩＳＩＮコード
				 || '		VMG1.KOKYAKU_MGR_RNM,'										-- 対顧用銘柄略称
				 || '		VMG1.SHASAI_TOTAL,'											-- 社債の総額
				 || '		VMG1.RITSUKE_WARIBIKI_KBN,'									-- 利付割引区分
				 || '		VMG1.RIRITSU,'												-- 利率
				 || '		VMG1.SHOKAN_METHOD_CD,'										-- 償還方法コード
				 || '		(SELECT CODE_NM FROM SCODE WHERE VMG1.SHOKAN_METHOD_CD = CODE_VALUE AND CODE_SHUBETSU = ''116'') AS SHOKAN_METHOD_NM,'
				 || '		VMG1.FULLSHOKAN_KJT,'										-- 満期償還期日
				 || '		PKIPAZNDK.getKjnZndk(VMG1.ITAKU_KAISHA_CD, VMG1.MGR_CD, ''' || l_inKijunYmdF || ''', 3) AS ZNDK,'	--未償還残高
				 || '		VMG1.MGR_CD AS MGR_CD,'                                      --銘柄コード
				 || '		VMG1.KK_KANYO_FLG,'											-- 機構関与フラグ
				 || '		VMG1.TEIJI_SHOKAN_TSUTI_KBN,'                                  -- 定時償還通知区分
				 || '		M01.KOZA_TEN_CD,'                                             -- 口座店コード
				 || '		M01.KOZA_TEN_CIFCD'                                          -- 口座店ＣＩＦコード
				 || '	FROM  	MGR_KIHON_VIEW VMG1,'
				 || '			MHAKKOTAI M01'
				 || '	WHERE VMG1.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''''
				 || '	AND 	VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD'
				 || '	AND		VMG1.HKT_CD = M01.HKT_CD'
				 || '	AND 	VMG1.JTK_KBN != ''2'''
				 || '	AND 	(trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '''')'
				 || '	AND 	VMG1.MGR_STAT_KBN = ''' || SHONIN || ''''
				 || '	AND 	VMG1.MASSHO_FLG = ''' || NOT_MASSHO || ''''
				 || '	AND     VMG1.HAKKO_YMD <= ''' || gGyomuYmd || ''''
				 || '	AND     ((VMG1.TOKUREI_SHASAI_FLG = ''Y'' AND (SELECT COUNT(Z01.MGR_CD) FROM GENSAI_RIREKI Z01'
				 || '													WHERE Z01.SHOKAN_KBN = ''01'''
				 || '													AND Z01.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''''
				 || '													AND Z01.MGR_CD = VMG1.MGR_CD'
				 || '													GROUP BY Z01.MGR_CD ) >= 1)'
				 || '			OR VMG1.TOKUREI_SHASAI_FLG = ''N'')';
	IF (l_inHktCd IS NOT NULL AND l_inHktCd::text <> '') THEN
		gSQL := gSQL || '	AND VMG1.HKT_CD = ''' || l_inHktCd || '''';
	END IF;
	IF (l_inKozaTenCd IS NOT NULL AND l_inKozaTenCd::text <> '') THEN
		gSQL := gSQL || '	AND M01.KOZA_TEN_CD = ''' || l_inKozaTenCd || '''';
	END IF;
	IF (l_inKozaTenCifCd IS NOT NULL AND l_inKozaTenCifCd::text <> '') THEN
		gSQL := gSQL || '	AND M01.KOZA_TEN_CIFCD = ''' || l_inKozaTenCifCd || '''';
	END IF;
	gSQL := gSQL || '	ORDER BY'
				 || '		M01.KOZA_TEN_CD,'      --口座店コード
				 || '		M01.KOZA_TEN_CIFCD,'   -- 口座店CIFコード
				 || '		VMG1.HAKKO_TSUKA_CD,'  -- 通貨コード
				 || '		VMG1.HAKKO_YMD,'       -- 発行日
				 || '		VMG1.ISIN_CD';         -- ISINコード
	-- カーソルオープン
	OPEN curMeisai FOR EXECUTE gSQL;
	-- データ取得
	LOOP
		FETCH curMeisai INTO	recMeisai.gHktCd 				-- 発行体コード
								,recMeisai.gSfskPostNo 			-- 送付先郵便番号
								,recMeisai.gAdd1				-- 送付先住所１
								,recMeisai.gAdd2				-- 送付先住所２
								,recMeisai.gAdd3				-- 送付先住所３
								,recMeisai.gHktNm 				-- 発行体名称
								,recMeisai.gSfskBushoNm 			-- 送付先担当部署名称
								,recMeisai.gHakkoTsukaNm 		-- 発行通貨名称
								,recMeisai.gHakkoTsukaCd 		-- 発行通貨コード
								,recMeisai.gIsinCd 				-- ＩＳＩＮコード
								,recMeisai.gKokyakuMgrRnm 		-- 対顧用銘柄略称
								,recMeisai.gShasaiTotal 			-- 社債の総額
								,recMeisai.gRitsukeWaribikiKbn 	-- 利付割引区分
								,recMeisai.gRiritsu 				-- 利率
								,recMeisai.gShokanMethodCd 		-- 償還方法コード
								,recMeisai.gShokanMethodNm 		-- 償還方法名称
								,recMeisai.gFullshokanKjt 		-- 満期償還期日
								,recMeisai.gZndk  				-- 残高
								,recMeisai.gMgrCd 				-- 銘柄コード
								,recMeisai.gKkKnyoFlg 			-- 機構関与フラグ
								,recMeisai.gTshokanTsutiKbn 		-- 定時償還通知区分
								,recMeisai.gKozaTenCd            -- 口座店コード
								,recMeisai.gKozaTenCifcd         -- 口座店ＣＩＦコード
								;
		EXIT WHEN NOT FOUND;
		-- 実質記番号オプションフラグがONの場合
		IF gOptionFlg = '1' THEN
			-- 機構関与フラグが「2：実質記番号銘柄」の場合
			IF recMeisai.gKkKnyoFlg = JISSITU_MGR THEN
				-- 固定で「2：定時償還」を設定する
				recMeisai.gShokanMethodCd := TEIJI_SHO_CD;
				recMeisai.gShokanMethodNm := gTeijiShoNm;
			END IF;
		END IF;
		-- 定時償還永久債の償還方法の表示を「永久債」とする
		IF recMeisai.gFullshokanKjt = '99999999' AND recMeisai.gShokanMethodCd = '2'
		AND recMeisai.gTshokanTsutiKbn = 'V' THEN
			recMeisai.gShokanMethodNm := '永久債';
		END IF;
	-- IP-04876
		-- 併存銘柄での請求出力チェック
		IF pkIPACalcTesuryo.checkHeizonMgr(l_inItakuKaishaCd, recMeisai.gMgrCd, l_inKijunYmdF, '1') = 0 THEN
		IF (key.gHktCd IS DISTINCT FROM recMeisai.gHktCd OR key.gHakkoTsukaCd IS DISTINCT FROM recMeisai.gHakkoTsukaCd)
		THEN
		-- キーブレイク、合計行出力
			IF gokei.gZndk > 0  AND gSeqNo > gSeqNoIni THEN
				gSeqNo := gSeqNo + 1;
				-- 帳票ワークへデータを追加
						-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gWrkTsuchiYmd;	-- 通知日
		v_item.l_inItem002 := recPrevMeisai.gSfskPostNo;	-- 送付先郵便番号
		v_item.l_inItem003 := recPrevMeisai.gAdd1;	-- 送付先住所１
		v_item.l_inItem004 := recPrevMeisai.gAdd2;	-- 送付先住所２
		v_item.l_inItem005 := recPrevMeisai.gAdd3;	-- 送付先住所３
		v_item.l_inItem006 := gAtena;	-- 発行体名称
		v_item.l_inItem007 := jikoBankNm;	-- 金融機関名称
		v_item.l_inItem008 := jikoBushoNm1;	-- 担当部署名称
		v_item.l_inItem009 := gWrkKijunYmd;	-- 入力基準日
		v_item.l_inItem010 := recPrevMeisai.gHakkoTsukaNm;	-- 発行通貨名称
		v_item.l_inItem018 := FMT_HAKKO_KNGK_J_TOTAL;	-- 発行金額書式合計フォーマット
		v_item.l_inItem019 := FMT_RBR_KNGK_J_TOTAL;	-- 利払金額書式合計フォーマット
		v_item.l_inItem020 := FMT_SHOKAN_KNGK_J_TOTAL;	-- 償還金額書式合計フォーマット
		v_item.l_inItem022 := gokei.gShasaiTotal;	-- 社債の総額＿合計
		v_item.l_inItem023 := gokei.gZndk;	-- 残高＿合計
		v_item.l_inItem025 := key.gHktCd;	-- 発行体コード
		v_item.l_inItem026 := recMeisai.gRitsukeWaribikiKbn;	-- 利付割引区分
		v_item.l_inItem029 := recPrevMeisai.gKozaTenCd;	-- 口座店コード
		v_item.l_inItem030 := recPrevMeisai.gKozaTenCifcd;	-- 口座店ＣＩＦコード
		v_item.l_inItem031 := gRedOptionFlg;	-- レッドプロジェクトオプションフラグ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> REAL_KBN,
			l_inSakuseiYmd	=> gGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
			END IF;
			-- キーと現在のレコードを退避する
			key.gHktCd			:= recMeisai.gHktCd;
			key.gHakkoTsukaCd	:= recMeisai.gHakkoTsukaCd;
			recPrevMeisai		:= recMeisai;
			-- 合計行のクリア
			gokei.gShasaiTotal	:= 0;
			gokei.gZndk			:= 0;
		END IF;
		-- 残高が「0」以外の場合帳票ワークへデータを追加
		IF recMeisai.gZndk != 0 AND (recMeisai.gZndk IS NOT NULL AND recMeisai.gZndk::text <> '') THEN
			-- 合計計算
			gokei.gShasaiTotal := gokei.gShasaiTotal + recMeisai.gShasaiTotal;
			gokei.gZndk := gokei.gZndk + recMeisai.gZndk;
			-- 宛名編集
			CALL pkIpaName.getMadoFutoAtena(recMeisai.gHktNm, recMeisai.gSfskBushoNm, gOutflg, gAtena);
			gSeqNo := gSeqNo + 1;
					-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gWrkTsuchiYmd;	-- 通知日
		v_item.l_inItem002 := recMeisai.gSfskPostNo;	-- 送付先郵便番号
		v_item.l_inItem003 := recMeisai.gAdd1;	-- 送付先住所１
		v_item.l_inItem004 := recMeisai.gAdd2;	-- 送付先住所２
		v_item.l_inItem005 := recMeisai.gAdd3;	-- 送付先住所３
		v_item.l_inItem006 := gAtena;	-- 発行体名称
		v_item.l_inItem007 := jikoBankNm;	-- 金融機関名称
		v_item.l_inItem008 := jikoBushoNm1;	-- 担当部署名称
		v_item.l_inItem009 := gWrkKijunYmd;	-- 入力基準日
		v_item.l_inItem010 := recMeisai.gHakkoTsukaNm;	-- 発行通貨名称
		v_item.l_inItem011 := recMeisai.gIsinCd;	-- ＩＳＩＮコード
		v_item.l_inItem012 := recMeisai.gKokyakuMgrRnm;	-- 対顧用銘柄略称
		v_item.l_inItem013 := recMeisai.gShasaiTotal;	-- 社債の総額
		v_item.l_inItem014 := recMeisai.gRiritsu;	-- 利率
		v_item.l_inItem015 := recMeisai.gShokanMethodNm;	-- 償還方法名称
		v_item.l_inItem016 := recMeisai.gFullshokanKjt;	-- 満期償還期日
		v_item.l_inItem017 := recMeisai.gZndk;	-- 残高
		v_item.l_inItem018 := FMT_HAKKO_KNGK_J;	-- 発行金額書式フォーマット
		v_item.l_inItem019 := FMT_RBR_KNGK_J;	-- 利払金額書式フォーマット
		v_item.l_inItem020 := FMT_SHOKAN_KNGK_J;	-- 償還金額書式フォーマット
		v_item.l_inItem025 := recMeisai.gHktCd;	-- 発行体コード
		v_item.l_inItem026 := recMeisai.gRitsukeWaribikiKbn;	-- 利付割引区分
		v_item.l_inItem027 := recMeisai.gShokanMethodCd;	-- 償還方法コード
		v_item.l_inItem029 := recMeisai.gKozaTenCd;	-- 口座店コード
		v_item.l_inItem030 := recMeisai.gKozaTenCifcd;	-- 口座店ＣＩＦコード
		v_item.l_inItem031 := gRedOptionFlg;	-- レッドプロジェクトオプションフラグ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> REAL_KBN,
			l_inSakuseiYmd	=> gGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		END IF;
	END IF;
	END LOOP;
	CLOSE curMeisai;
	IF gSeqNo = 0 THEN
		-- 対象データなし
--		gRtnCd := RTN_NODATA;
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gWrkTsuchiYmd;	-- 通知日
		v_item.l_inItem018 := FMT_HAKKO_KNGK_J;	-- 発行金額書式フォーマット
		v_item.l_inItem019 := FMT_RBR_KNGK_J;	-- 利払金額書式フォーマット
		v_item.l_inItem020 := FMT_SHOKAN_KNGK_J;	-- 償還金額書式フォーマット
		v_item.l_inItem021 := '対象データなし';	-- 対象データなし
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> REAL_KBN,
			l_inSakuseiYmd	=> gGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> 1,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	ELSE
		IF gokei.gZndk > 0 THEN
			-- 合計行をINSERTする直前に振られたシーケンスNoに該当する帳票データの発行体コードを取得する
			SELECT 	ITEM025
			INTO STRICT	gHktCd
			FROM 	SREPORT_WK s
			WHERE 	s.KEY_CD = l_inItakuKaishaCd
			AND		s.USER_ID = l_inUserId
			AND		s.CHOHYO_KBN = REAL_KBN
			AND		s.SAKUSEI_YMD = gGyomuYmd
			AND		s.CHOHYO_ID = REPORT_ID
			AND		s.SEQ_NO = gSeqNo
			AND		s.HEADER_FLG = '1';
			-- 合計行を出力する
			gSeqNo := gSeqNo + 1;
			-- 帳票ワークへデータを追加
					-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gWrkTsuchiYmd;	-- 通知日
		v_item.l_inItem002 := recPrevMeisai.gSfskPostNo;	-- 送付先郵便番号
		v_item.l_inItem003 := recPrevMeisai.gAdd1;	-- 送付先住所１
		v_item.l_inItem004 := recPrevMeisai.gAdd2;	-- 送付先住所２
		v_item.l_inItem005 := recPrevMeisai.gAdd3;	-- 送付先住所３
		v_item.l_inItem006 := gAtena;	-- 発行体名称
		v_item.l_inItem007 := jikoBankNm;	-- 金融機関名称
		v_item.l_inItem008 := jikoBushoNm1;	-- 担当部署名称
		v_item.l_inItem009 := gWrkKijunYmd;	-- 入力基準日
		v_item.l_inItem010 := recPrevMeisai.gHakkoTsukaNm;	-- 発行通貨名称
		v_item.l_inItem018 := FMT_HAKKO_KNGK_J_TOTAL;	-- 発行金額書式合計フォーマット
		v_item.l_inItem019 := FMT_RBR_KNGK_J_TOTAL;	-- 利払金額書式合計フォーマット
		v_item.l_inItem020 := FMT_SHOKAN_KNGK_J_TOTAL;	-- 償還金額書式合計フォーマット
		v_item.l_inItem022 := gokei.gShasaiTotal;	-- 社債の総額＿合計
		v_item.l_inItem023 := gokei.gZndk;	-- 残高＿合計
		v_item.l_inItem025 := gHktCd;	-- 発行体コード
		v_item.l_inItem029 := recPrevMeisai.gKozaTenCd;	-- 口座店コード
		v_item.l_inItem030 := recPrevMeisai.gKozaTenCifcd;	-- 口座店ＣＩＦコード
		v_item.l_inItem031 := gRedOptionFlg;	-- レッドプロジェクトオプションフラグ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> REAL_KBN,
			l_inSakuseiYmd	=> gGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		END IF;
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIP06701_01 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		BEGIN
			CLOSE curMeisai;
		EXCEPTION
			WHEN OTHERS THEN
				NULL;
		END;
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip06701_01 ( l_inUserId TEXT, l_inItakuKaishaCd TEXT, l_inKijunYmdF TEXT, l_inHktCd TEXT, l_inKozaTenCd TEXT, l_inKozaTenCifCd TEXT, l_inTsuchiYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;