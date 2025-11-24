


DROP TYPE IF EXISTS spipk004k00r01_type_record CASCADE;
CREATE TYPE spipk004k00r01_type_record AS (
		gIsinCd				TEXT 			-- ISINコード
		,gMgrCd				TEXT  			-- 銘柄コード
		,gMgrRnm			TEXT  			-- 銘柄略称
		,gHakkoYmd			TEXT 		-- 発行年月日
		,gFullshokanKjt		TEXT 	-- 満期償還期日
		,gShasaiTotal		numeric 		-- 社債の総額
		,gHakkoTsukaNm		char(3)			-- 発行通貨名称
		,gBank_Rnm			TEXT  	    -- 銀行名略称(自行委託会社ビュー)
        ,gJiko_Daiko_Kbn    TEXT  -- 自行代行区分
		,gGenRuikeiKngk		numeric(14)						-- 現登債累計金額
		,gFuriRuikeiKngk	numeric(14)						-- 振替債累計金額
		,gGenZndk			numeric(14)						-- 現登債残高
		,gFuriZndk			numeric(14)						-- 振替債残高
		,gGenSogk			numeric(14)						-- 現存総額
	);

DROP TYPE IF EXISTS spipk004k00r01_type_gokei CASCADE;
CREATE TYPE spipk004k00r01_type_gokei AS (
		gMgrCount			numeric(5)			-- 銘柄数
		,gShasaiTotal		numeric(16)			-- 社債の総額
		,gGenZndk			numeric(16)			-- 現登債残高
		,gFuriZndk			numeric(16)			-- 振替債残高
		,gGenSogk			numeric(16)			-- 現存総額
	);


CREATE OR REPLACE PROCEDURE spipk004k00r01 ( p_inShasaiFlg TEXT,		-- 全特例社債指定フラグ
 p_inKijunYm TEXT,		-- 基準年月
 p_inHktCd TEXT,		-- 発行体コード
 p_inKozaTenCd TEXT,		-- 口座店コード
 p_inKozaTenCifCd TEXT,		-- 口座店CIFコード
 p_inMgrCd TEXT,		-- 銘柄コード
 p_inIsinCd TEXT,		-- ISINコード
 p_inJtkKbn TEXT,		-- 受託区分
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
--/* 概要　:事務帳票出力画面から、併存銘柄残高一覧表を作成する。
--/* 引数　:p_inShasaiFlg			IN	TEXT		全特例社債指定フラグ
--/* 　　　 p_inKijunYm			IN	CAHR		基準年月
--/* 　　　 p_inHktCd				IN	TEXT		発行体コード
--/* 　　　 p_inKozaTenCd			IN	TEXT		口座店コード
--/* 　　　 p_inKozaTenCifCd		IN	TEXT		口座店CIFコード
--/* 　　　 p_inMgrCd				IN	TEXT		銘柄コード
--/* 　　　 p_inIsinCd			IN	TEXT		ISINコード
--/* 　　　 p_inJtkKbn			IN	TEXT		受託区分
--/* 　　　 l_inItakuKaishaCd		IN	TEXT		委託会社コード
--/* 　　　 l_inUserId			IN	TEXT		ユーザーID
--/* 　　　 l_inChohyoKbn			IN	TEXT		帳票区分
--/* 　　　 l_inGyomuYmd			IN	TEXT		業務日付
--/* 　　　 l_outSqlCode			OUT	INTEGER		リターン値
--/* 　　　 l_outSqlErrM			OUT	VARCHAR	エラーコメント
--/* 返り値:なし
--/* @version $Id: SPIPK004K00R01.SQL,v 1.21 2008/10/04 08:26:40 fujimoto Exp $
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.02.25	JIP				新規作成
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
	REPORT_ID			CONSTANT char(11)		:= 'IPK30000411';	-- 帳票ID
	-- 書式フォーマット
	FMT_HAKKO_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	FMT_RBR_KNGK_J		CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 利払金額
	FMT_SHOKAN_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 償還金額
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd				integer := RTN_OK;					-- リターンコード
	gSeqNo				integer := 0;							-- シーケンス
	gSQL				varchar(2500) := NULL;				-- SQL編集
	-- DB取得項目
	-- 合計
	recMeisai SPIPK004K00R01_TYPE_RECORD;							-- レコード
	gokei SPIPK004K00R01_TYPE_GOKEI;
	p_gZndkKijunYmd			character varying := NULL;				-- 残高基準日
	gHktRnm					MHAKKOTAI.HKT_RNM%TYPE;					-- 発行体略称
	gKeyHakkoTsuka			MTSUKA.TSUKA_NM%TYPE := NULL;			-- 発行通貨略称
	gKeyHakkoTsukaCd		MTSUKA.TSUKA_CD%TYPE := NULL;			-- 発行通貨コード
	gBank_Rnm				VJIKO_ITAKU.BANK_RNM%TYPE;	    		-- 銀行名略称
	gRet					numeric := 0;			-- 戻り値格納用
	GenZndk					numeric(14);					-- 現登債残高
	FuriZndk				numeric(14);					-- 振替債残高
	GenSogk					numeric(14);					-- 現存総額
	-- カーソル
	curMeisai REFCURSOR;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SFIP80101 START');	END IF;
    IF DEBUG = 1 THEN
       CALL pkLog.debug(l_inUserId, 'SPIPK004K00R01', 'IPK30000411' || ' START');
       CALL pkLog.debug(l_inUserId, 'IPK30000411', 'param error 全特例社債指定フラグ:' || p_inShasaiFlg);
       CALL pkLog.debug(l_inUserId, 'IPK30000411', 'param error 基準年月:' || p_inKijunYm);
       CALL pkLog.debug(l_inUserId, 'IPK30000411', 'param error 発行体コード:' || p_inHktCd);
       CALL pkLog.debug(l_inUserId, 'IPK30000411', 'param error 口座店コード:' || p_inKozaTenCd);
       CALL pkLog.debug(l_inUserId, 'IPK30000411', 'param error 口座店CIFコード:' || p_inKozaTenCifCd);
       CALL pkLog.debug(l_inUserId, 'IPK30000411', 'param error 銘柄コード:' || p_inMgrCd);
       CALL pkLog.debug(l_inUserId, 'IPK30000411', 'param error ISINコード:' || p_inIsinCd);
       CALL pkLog.debug(l_inUserId, 'IPK30000411', 'param error 受託区分:' || p_inJtkKbn);
       CALL pkLog.debug(l_inUserId, 'IPK30000411', 'param error 委託会社コード:' || l_inItakuKaishaCd);
       CALL pkLog.debug(l_inUserId, 'IPK30000411', 'param error ユーザーID:' || l_inUserId);
       CALL pkLog.debug(l_inUserId, 'IPK30000411', 'param error 帳票区分:' || l_inChohyoKbn);
       CALL pkLog.debug(l_inUserId, 'IPK30000411', 'param error 業務日付:' || l_inGyomuYmd);
    END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both p_inShasaiFlg)::text, '') = ''
	OR coalesce(trim(both p_inKijunYm)::text, '') = ''
	OR coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
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
	-- 残高基準日の設定
	CASE
		WHEN p_inKijunYm < SUBSTR(l_inGyomuYmd, 1, 6) THEN p_gZndkKijunYmd := pkDate.getGetsumatsuYmd(p_inKijunYm||'01', 0);
		WHEN p_inKijunYm = SUBSTR(l_inGyomuYmd, 1, 6) THEN p_gZndkKijunYmd := l_inGyomuYmd;
		ELSE
			-- パラメータエラー
			IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
			l_outSqlCode := RTN_NG;
			l_outSqlErrM := '';
			CALL pkLog.error(l_inUserId, REPORT_ID, 'SQLERRM:'||'');
			RETURN;
	END CASE;
	-- 発行体コードが入力されている場合は発行体略称を取得する
	IF (p_inHktCd IS NOT NULL AND p_inHktCd::text <> '') THEN
		gHktRnm := SPIPK004K00R01_getHktRnm(l_inItakuKaishaCd,p_inHktCd);
	END IF;
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID::text;
	-- SQL編集
	gSQL := SPIPK004K00R01_createSQL(p_gZndkKijunYmd, l_inItakuKaishaCd, p_inKijunYm, p_inShasaiFlg, p_inHktCd, p_inKozaTenCd, p_inKozaTenCifCd, p_inMgrCd, p_inIsinCd, p_inJtkKbn);
    IF DEBUG = 1 THEN
	  CALL pkLog.debug(l_inUserId, REPORT_ID, substr(gsql, 1, 200));
	  CALL pkLog.debug(l_inUserId, REPORT_ID, substr(gsql, 201, 200));
	  CALL pkLog.debug(l_inUserId, REPORT_ID, substr(gsql, 401, 200));
	  CALL pkLog.debug(l_inUserId, REPORT_ID, substr(gsql, 601, 200));
	  CALL pkLog.debug(l_inUserId, REPORT_ID, substr(gsql, 801, 200));
	  CALL pkLog.debug(l_inUserId, REPORT_ID, substr(gsql, 1001, 200));
	  CALL pkLog.debug(l_inUserId, REPORT_ID, substr(gsql, 1201, 200));
	  CALL pkLog.debug(l_inUserId, REPORT_ID, substr(gsql, 1401, 200));
	END IF;
  --pkLog.debug(l_inUserId, REPORT_ID, 'gsql=' || gsql);
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd::character varying, l_inUserId::character varying, l_inChohyoKbn::character, l_inGyomuYmd::character, REPORT_ID::character);
	-- カーソルオープン
	OPEN curMeisai FOR EXECUTE gSQL;
	-- データ取得
	LOOP
		FETCH curMeisai INTO	recMeisai.gIsinCd 					-- ISINコード
								,recMeisai.gMgrCd 					-- 銘柄コード
								,recMeisai.gMgrRnm 					-- 銘柄略称
								,recMeisai.gHakkoYmd 				-- 発行年月日
								,recMeisai.gFullshokanKjt 			-- 満期償還期日
								,recMeisai.gShasaiTotal 				-- 社債の総額
								,recMeisai.gHakkoTsukaNm 			-- 発行通貨名称
								,recMeisai.gBank_Rnm 				-- 銀行名略称(自行委託会社ビュー)
								,recMeisai.gJiko_Daiko_Kbn 			-- 自行代行区分
								,recMeisai.gGenRuikeiKngk 			-- 現登債累計金額
								,recMeisai.gFuriRuikeiKngk 			-- 振替債累計金額
								;
		EXIT WHEN NOT FOUND;/* apply on curMeisai */
	-- 現登債残高を算出
	GenZndk := pkIpaZndk.getKjnZndk(l_inItakuKaishaCd, recMeisai.gMgrCd, p_gZndkKijunYmd, 83);
	-- 振替債残高を算出
	FuriZndk := pkIpaZndk.getKjnZndk(l_inItakuKaishaCd, recMeisai.gMgrCd, p_gZndkKijunYmd, 3);
	-- 全特例社債チェックなしの場合は、現登債残高と振替債残高がある場合のみ、処理を行う
	IF p_inShasaiFlg = '1'
	OR (p_inShasaiFlg = '0' AND GenZndk > 0 AND FuriZndk > 0)
	THEN
		-- 現存総額を算出
		GenSogk := pkIpaZndk.getKjnZndk(l_inItakuKaishaCd, recMeisai.gMgrCd, p_gZndkKijunYmd, 93);
		IF gKeyHakkoTsuka != recMeisai.gHakkoTsukaNm THEN
		-- 発行通貨でブレイク
			IF gSeqNo > 0 THEN
				gSeqNo := gSeqNo + 1;
						-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- 入力ユーザＩＤ
		v_item.l_inItem002 := p_inKijunYm;	-- 入力基準年月
		v_item.l_inItem003 := p_inHktCd;	-- 入力発行体コード
		v_item.l_inItem004 := p_inKozaTenCd;	-- 入力口座店コード
		v_item.l_inItem005 := p_inKozaTenCifCd;	-- 入力口座店CIFコード
		v_item.l_inItem006 := gHktRnm;	-- 発行体略称
		v_item.l_inItem007 := gKeyHakkoTsuka;	-- 発行通貨名称
		v_item.l_inItem019 := gokei.gMgrCount;	-- 銘柄数
		v_item.l_inItem020 := gokei.gShasaiTotal;	-- 社債の総額合計
		v_item.l_inItem021 := GenZndk;	-- 現登債残高合計
		v_item.l_inItem022 := FuriZndk;	-- 振替債残高合計
		v_item.l_inItem023 := GenSogk;	-- 現存残高合計
		v_item.l_inItem025 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem026 := FMT_HAKKO_KNGK_J;	-- 発行金額書式フォーマット
		v_item.l_inItem027 := FMT_RBR_KNGK_J;	-- 利払金額書式フォーマット
		v_item.l_inItem028 := FMT_SHOKAN_KNGK_J;	-- 償還金額書式フォーマット
		v_item.l_inItem029 := gBank_Rnm;	-- 銀行名略称(自行委託会社ビュー)
		
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
			-- キーの退避
			gKeyHakkoTsuka := recMeisai.gHakkoTsukaNm;
			-- 委託会社略称
			IF recMeisai.gJiko_Daiko_Kbn != '2' THEN
				gBank_Rnm := NULL;
			ELSE
				gBank_Rnm := recMeisai.gBank_Rnm;
			END IF;
			-- 合計クリア
			gokei.gMgrCount		:= 0;		-- 銘柄数
			gokei.gShasaiTotal	:= 0;		-- 社債の総額
			gokei.gGenZndk		:= 0;		-- 現登債残高
			gokei.gFuriZndk		:= 0;		-- 振替債残高
			gokei.gGenSogk		:= 0;		-- 現存総額
		END IF;
		-- 合計計算
		gokei.gMgrCount		:= gokei.gMgrCount + 1;							-- 銘柄数
		gokei.gShasaiTotal	:= gokei.gShasaiTotal + recMeisai.gShasaiTotal;	-- 社債の総額
		gokei.gGenZndk		:= gokei.gGenZndk + GenZndk;					-- 現登債残高
		gokei.gFuriZndk		:= gokei.gFuriZndk + FuriZndk;					-- 振替債残高
		gokei.gGenSogk		:= gokei.gGenSogk + GenSogk;					-- 現存総額
		-- 帳票ワークへデータを追加
		gSeqNo := gSeqNo + 1;
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- 入力ユーザＩＤ
		v_item.l_inItem002 := p_inKijunYm;	-- 入力基準年月
		v_item.l_inItem003 := p_inHktCd;	-- 入力発行体コード
		v_item.l_inItem004 := p_inKozaTenCd;	-- 入力口座店コード
		v_item.l_inItem005 := p_inKozaTenCifCd;	-- 入力口座店CIFコード
		v_item.l_inItem006 := gHktRnm;	-- 発行体略称
		v_item.l_inItem007 := gKeyHakkoTsuka;	-- 発行通貨名称
		v_item.l_inItem008 := recMeisai.gIsinCd;	-- ISINコード
		v_item.l_inItem009 := recMeisai.gMgrCd;	-- 銘柄コード
		v_item.l_inItem010 := recMeisai.gMgrRnm;	-- 銘柄略称
		v_item.l_inItem011 := recMeisai.gHakkoYmd;	-- 発行年月日
		v_item.l_inItem012 := recMeisai.gFullshokanKjt;	-- 満期償還期日
		v_item.l_inItem013 := recMeisai.gShasaiTotal;	-- 社債の総額
		v_item.l_inItem014 := recMeisai.gGenRuikeiKngk;	-- 現登債累計金額
		v_item.l_inItem015 := recMeisai.gFuriRuikeiKngk;	-- 振替債累計金額
		v_item.l_inItem016 := GenZndk;	-- 現登債残高
		v_item.l_inItem017 := FuriZndk;	-- 振替債残高
		v_item.l_inItem018 := GenSogk;	-- 現存残高
		v_item.l_inItem025 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem026 := FMT_HAKKO_KNGK_J;	-- 発行金額書式フォーマット
		v_item.l_inItem027 := FMT_RBR_KNGK_J;	-- 利払金額書式フォーマット
		v_item.l_inItem028 := FMT_SHOKAN_KNGK_J;	-- 償還金額書式フォーマット
		v_item.l_inItem029 := gBank_Rnm;	-- 銀行名略称(自行委託会社ビュー)
		
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
	END LOOP;
	CLOSE curMeisai;
	IF gSeqNo = 0 THEN
        IF DEBUG = 1 THEN CALL PkLog.debug(l_inUserId, REPORT_ID, '対象データ無し用のデータを出力します。' );END IF;
        -- 対象データなし
        gRtnCd := RTN_NODATA;
        -- データ無し帳票出力
        gRet := PKIPACALCTESURYO.setNoDataPrint(SUBSTR(l_inItakuKaishaCd,1,1),  -- 委託会社コード (character(1))
                                                l_inUserId,         -- ユーザID
                                                SUBSTR(l_ingyomuymd,1,1),       -- 業務日付 (character(1))
                                                SUBSTR(REPORT_ID,1,1),          -- 帳票ID (character(1))
                                                l_inChohyoKbn,      -- 帳票区分
                                                24,                 -- 対象データなし の出力位置
                                                l_inUserId,       -- セットするアイテムその１
                                                1,                  -- セットするアイテムその１のItem番号
                                                p_inKijunYm,				-- セットするアイテムその2
                                                2,                  -- セットするアイテムその2のItem番号
                                                REPORT_ID,       -- セットするアイテムその3
                                                25,                  -- セットするアイテムその3のItem番号
                                                '',       -- セットするアイテムその4
                                                0,                  -- セットするアイテムその5のItem番号
                                                '',       -- セットするアイテムその5
                                                0                  -- セットするアイテムその5のItem番号
                                                );
        -- 帳票が正しく出力されたかどうか確認
        IF gRet <> pkconstant.success() THEN
            IF DEBUG = 1 THEN CALL PkLog.debug(l_inUserId, REPORT_ID, '対象データ無し用のデータの出力が失敗。' );END IF;
            -- エラーの場合はエラーログを出力し、エラーで返す
            CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLCODE:'||SQLSTATE);
            CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLERRM:'||SQLERRM);
            -- Out引数にエラー内容を設定
            l_outSqlCode := pkconstant.FATAL();
            l_outSqlErrM := SQLERRM;
            RETURN;
        END IF;
	ELSE
	-- 合計行出力
		gSeqNo := gSeqNo + 1;
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- 入力ユーザＩＤ
		v_item.l_inItem002 := p_inKijunYm;	-- 入力基準年月
		v_item.l_inItem003 := p_inHktCd;	-- 入力発行体コード
		v_item.l_inItem004 := p_inKozaTenCd;	-- 入力口座店コード
		v_item.l_inItem005 := p_inKozaTenCifCd;	-- 入力口座店CIFコード
		v_item.l_inItem006 := gHktRnm;	-- 発行体略称
		v_item.l_inItem007 := gKeyHakkoTsuka;	-- 発行通貨名称
		v_item.l_inItem019 := gokei.gMgrCount;	-- 銘柄数
		v_item.l_inItem020 := gokei.gShasaiTotal;	-- 社債の総額合計
		v_item.l_inItem021 := gokei.gGenZndk;	-- 現登債残高合計
		v_item.l_inItem022 := gokei.gFuriZndk;	-- 振替債残高合計
		v_item.l_inItem023 := gokei.gGenSogk;	-- 現存残高合計
		v_item.l_inItem025 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem026 := FMT_HAKKO_KNGK_J;	-- 発行金額書式フォーマット
		v_item.l_inItem027 := FMT_RBR_KNGK_J;	-- 利払金額書式フォーマット
		v_item.l_inItem028 := FMT_SHOKAN_KNGK_J;	-- 償還金額書式フォーマット
		v_item.l_inItem029 := gBank_Rnm;	-- 銀行名略称(自行委託会社ビュー)
		
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
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SFIP80101 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		BEGIN
			CLOSE curMeisai;
		EXCEPTION
			WHEN OTHERS THEN NULL;
		END;
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
--		RAISE;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipk004k00r01 ( p_inShasaiFlg TEXT, p_inKijunYm TEXT, p_inHktCd TEXT, p_inKozaTenCd TEXT, p_inKozaTenCifCd TEXT, p_inMgrCd TEXT, p_inIsinCd TEXT, p_inJtkKbn TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spipk004k00r01_createsql (
	p_gZndkKijunYmd varchar,
	p_inItakuKaishaCd text,
	p_inKijunYm text,
	p_inShasaiFlg text,
	p_inHktCd text,
	p_inKozaTenCd text,
	p_inKozaTenCifCd text,
	p_inMgrCd text,
	p_inIsinCd text,
	p_inJtkKbn text
) RETURNS varchar(2500) AS $body$
DECLARE
	v_gSQL varchar(2500);
BEGIN
	v_gSQL := '';
	v_gSQL := v_gSQL || 'SELECT	VMG1.ISIN_CD,';									-- ISINコード
	v_gSQL := v_gSQL || '		VMG1.MGR_CD,';									-- 銘柄コード
	v_gSQL := v_gSQL || '		VMG1.MGR_RNM,';									-- 銘柄略称
	v_gSQL := v_gSQL || '		VMG1.HAKKO_YMD,';								-- 発行年月日
	v_gSQL := v_gSQL || '		VMG1.FULLSHOKAN_KJT,';							-- 満期償還期日
	v_gSQL := v_gSQL || '		VMG1.SHASAI_TOTAL,';							-- 社債の総額
	v_gSQL := v_gSQL || '		M64.TSUKA_NM AS HAKKO_TSUKA_NM,';				-- 発行通貨名称
	v_gSQL := v_gSQL || '		VJ1.BANK_RNM,';									-- 銀行名略称(自行委託会社ビュー)
	v_gSQL := v_gSQL || '		VJ1.JIKO_DAIKO_KBN,';							-- 自行代行区分(自行委託会社ビュー)
	v_gSQL := v_gSQL || '		COALESCE(WK1.GEN_RUIKEI_KNGK,0),';					-- 現登債累計金額
	v_gSQL := v_gSQL || '		COALESCE(WK2.FURI_RUIKEI_KNGK,0)';					-- 振替債累計金額
	v_gSQL := v_gSQL || 'FROM	(SELECT MG1.ITAKU_KAISHA_CD,MG1.ISIN_CD,MG1.MGR_CD,MG1.MGR_RNM,MG1.HAKKO_YMD,MG1.FULLSHOKAN_KJT, ';
	v_gSQL := v_gSQL || '		 		MG1.SHASAI_TOTAL,MG1.HAKKO_TSUKA_CD,MG1.RBR_TSUKA_CD,MG1.SHOKAN_TSUKA_CD,MG1.TOKUREI_SHASAI_FLG, ';
	v_gSQL := v_gSQL || '		 		MG1.HKT_CD,M01.KOZA_TEN_CD,M01.KOZA_TEN_CIFCD,MG1.JTK_KBN ';
	v_gSQL := v_gSQL || '		 FROM MGR_KIHON MG1 ';
	v_gSQL := v_gSQL || '		 INNER JOIN MGR_STS MG0 ON (MG1.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD AND MG1.MGR_CD = MG0.MGR_CD) ';
	v_gSQL := v_gSQL || '		 LEFT OUTER JOIN MHAKKOTAI M01 ON (MG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD AND MG1.HKT_CD = M01.HKT_CD) ';
	v_gSQL := v_gSQL || '		 WHERE  MG0.MASSHO_FLG = ''0'' ';						-- 抹消されていない
	v_gSQL := v_gSQL || '		 AND	MG1.PARTMGR_KBN IN (''0'', ''2'') ';		-- 親銘柄を対象外
	v_gSQL := v_gSQL || '		 AND	(MG1.PARTMGR_KBN IN (''0'', ''1'') OR SUBSTR(MG1.YOBI3, 14, 1) = ''0'') ';	-- 子銘柄（残高なし）を対象外
	v_gSQL := v_gSQL || '		 AND    MG1.JTK_KBN != ''2''';							-- 副受託銘柄を対象外
	v_gSQL := v_gSQL || '		) VMG1 ';
	v_gSQL := v_gSQL || '		INNER JOIN MTSUKA M64 ON (VMG1.HAKKO_TSUKA_CD = M64.TSUKA_CD) ';
	v_gSQL := v_gSQL || '		INNER JOIN VJIKO_ITAKU VJ1 ON (VMG1.ITAKU_KAISHA_CD = VJ1.KAIIN_ID) ';
	v_gSQL := v_gSQL || '		LEFT OUTER JOIN (SELECT	SUM(COALESCE(Z01.GENSAI_KNGK, 0)) AS GEN_RUIKEI_KNGK,';		-- 現登債累計金額,
	v_gSQL := v_gSQL || '				Z01.ITAKU_KAISHA_CD,';									-- 委託会社コード
	v_gSQL := v_gSQL || '				Z01.MGR_CD ';											-- 銘柄コード
	v_gSQL := v_gSQL || '		 FROM	GENSAI_RIREKI Z01 ';
	v_gSQL := v_gSQL || '		 WHERE	Z01.SHOKAN_YMD <= ''' || p_gZndkKijunYmd || '''';
	v_gSQL := v_gSQL || '		 AND	Z01.SHOKAN_KBN IN (''81'',''82'',''83'',''84'',''85'',''86'',''98'') '; -- ＣＢ行使（現登債）を追加する。（ＣＢ対応）
	v_gSQL := v_gSQL || '		 GROUP BY	Z01.ITAKU_KAISHA_CD,';
	v_gSQL := v_gSQL || '					Z01.MGR_CD ';
	v_gSQL := v_gSQL || '		) WK1 ON (VMG1.MGR_CD = WK1.MGR_CD AND VMG1.ITAKU_KAISHA_CD = WK1.ITAKU_KAISHA_CD) ';
	v_gSQL := v_gSQL || '		LEFT OUTER JOIN (SELECT	SUM(COALESCE(Z01.GENSAI_KNGK, 0)) AS FURI_RUIKEI_KNGK,';		-- 振替債累計金額,
	v_gSQL := v_gSQL || '				Z01.ITAKU_KAISHA_CD,';									-- 委託会社コード
	v_gSQL := v_gSQL || '				Z01.MGR_CD ';											-- 銘柄コード
	v_gSQL := v_gSQL || '		 FROM	GENSAI_RIREKI Z01 ';
	v_gSQL := v_gSQL || '		 WHERE	Z01.SHOKAN_YMD <= ''' || p_gZndkKijunYmd || '''';
	v_gSQL := v_gSQL || '		 AND	Z01.SHOKAN_KBN IN (''10'',''20'',''21'',''30'',''40'',''41'',''50'',''60'')'; -- ＣＢ行使を追加する。（ＣＢ対応）
	v_gSQL := v_gSQL || '		 GROUP BY	Z01.ITAKU_KAISHA_CD,';
	v_gSQL := v_gSQL || '					Z01.MGR_CD ';
	v_gSQL := v_gSQL || '		) WK2 ON (VMG1.MGR_CD = WK2.MGR_CD AND VMG1.ITAKU_KAISHA_CD = WK2.ITAKU_KAISHA_CD) ';
	v_gSQL := v_gSQL || 'WHERE	VMG1.ITAKU_KAISHA_CD = ''' || p_inItakuKaishaCd || '''';
--		v_gSQL := v_gSQL || 'AND	VMG1.MGR_STAT_KBN = ''1'' ';	-- ※未承認でも出力する仕様のため、この条件は含まない
	-- 基準年月が 発行日〜満期償還期日 のものが対象
	v_gSQL := v_gSQL || 'AND	VMG1.HAKKO_YMD      <= ''' || TO_CHAR(oracle.LAST_DAY(to_date(p_inKijunYm || '01','YYYYMMDD')),'YYYYMMDD') || ''' ';
	v_gSQL := v_gSQL || 'AND	VMG1.FULLSHOKAN_KJT >= ''' || p_inKijunYm || '01'' ';
	IF p_inShasaiFlg = '1' THEN
		v_gSQL := v_gSQL || 'AND		VMG1.TOKUREI_SHASAI_FLG = ''Y'' ';
	END IF;
	IF (p_inHktCd IS NOT NULL AND p_inHktCd::text <> '') THEN
		v_gSQL := v_gSQL || 'AND		VMG1.HKT_CD = ''' || p_inHktCd || '''';
	END IF;
	IF (p_inKozaTenCd IS NOT NULL AND p_inKozaTenCd::text <> '') THEN
		v_gSQL := v_gSQL || 'AND		VMG1.KOZA_TEN_CD = ''' || p_inKozaTenCd || '''';
	END IF;
	IF (p_inKozaTenCifCd IS NOT NULL AND p_inKozaTenCifCd::text <> '') THEN
		v_gSQL := v_gSQL || 'AND		VMG1.KOZA_TEN_CIFCD = ''' || p_inKozaTenCifCd || '''';
	END IF;
	IF (p_inMgrCd IS NOT NULL AND p_inMgrCd::text <> '') THEN
		v_gSQL := v_gSQL || 'AND		VMG1.MGR_CD = ''' || p_inMgrCd || '''';
	END IF;
	IF (p_inIsinCd IS NOT NULL AND p_inIsinCd::text <> '') THEN
		v_gSQL := v_gSQL || 'AND		VMG1.ISIN_CD = ''' || p_inIsinCd || '''';
	END IF;
	IF (p_inJtkKbn IS NOT NULL AND p_inJtkKbn::text <> '') THEN
		v_gSQL := v_gSQL || 'AND		VMG1.JTK_KBN = ''' || p_inJtkKbn || '''';
	END IF;
	v_gSQL := v_gSQL || 'ORDER BY	VMG1.HAKKO_TSUKA_CD,';
	v_gSQL := v_gSQL || '			VMG1.ISIN_CD ';
	RETURN v_gSQL;
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipk004k00r01_createsql () FROM PUBLIC;





CREATE OR REPLACE FUNCTION spipk004k00r01_gethktrnm (inItakuKaishaCd text,inHktCd text) RETURNS character varying AS $body$
DECLARE

	hkt_rnm		character varying := NULL;

BEGIN
	SELECT	M01.HKT_RNM
	INTO STRICT	hkt_rnm
	FROM	MHAKKOTAI M01
	WHERE	M01.HKT_CD = inHktCd
	AND		ITAKU_KAISHA_CD = inItakuKaishaCd;
	RETURN hkt_rnm;
EXCEPTION
	WHEN no_data_found	THEN RETURN NULL;
	WHEN OTHERS			THEN RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spipk004k00r01_gethktrnm (inItakuKaishaCd text,inHktCd text) FROM PUBLIC;