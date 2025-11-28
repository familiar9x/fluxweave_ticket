




CREATE OR REPLACE PROCEDURE spipk004k00r02 ( l_inShasaiFlg TEXT,		-- 全特例社債指定フラグ
 l_inHktCd TEXT,		-- 発行体コード
 l_inKozaTenCd TEXT,		-- 口座店コード
 l_inKozaTenCifCd TEXT,		-- 口座店CIFコード
 l_inMgrCd TEXT,		-- 銘柄コード
 l_inIsinCd TEXT,		-- ISINコード
 l_inJtkKbn TEXT,		-- 受託区分
 l_inGnrbaraiFYmd TEXT,		-- 元利払日From
 l_inGnrbaraiTYmd TEXT,		-- 元利払日To
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
--/* 概要　:事務帳票出力画面から、併存銘柄残高異動明細表を作成する。
--/* 引数　:l_inShasaiFlg			IN	TEXT		全特例社債指定フラグ
--/* 　　　 l_inHktCd				IN	TEXT		発行体コード
--/* 　　　 l_inKozaTenCd			IN	TEXT		口座店コード
--/* 　　　 l_inKozaTenCifCd		IN	TEXT		口座店CIFコード
--/* 　　　 l_inMgrCd				IN	TEXT		銘柄コード
--/* 　　　 l_inIsinCd			IN	TEXT		ISINコード
--/* 　　　 l_inJtkKbn			IN	TEXT		受託区分
--/*		  l_inGnrbaraiFYmd		IN	TEXT		元利払日From
--/*		  l_inGnrbaraiTYmd		IN	TEXT		元利払日To
--/* 　　　 l_inItakuKaishaCd		IN	TEXT		委託会社コード
--/* 　　　 l_inUserId			IN	TEXT		ユーザーID
--/* 　　　 l_inChohyoKbn			IN	TEXT		帳票区分
--/* 　　　 l_inGyomuYmd			IN	TEXT		業務日付
--/* 　　　 l_outSqlCode			OUT	INTEGER		リターン値
--/* 　　　 l_outSqlErrM			OUT	VARCHAR	エラーコメント
--/* 返り値:なし
--/* @version $Id: SPIPK004K00R02.SQL,v 1.26 2008/10/04 08:26:40 fujimoto Exp $
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.06.30	JIP				新規作成
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
	RTN_DATA_OVER		CONSTANT integer		:= 3;				-- 帳票出力の上限件数を超えた場合のエラー
	RTN_FATAL			CONSTANT integer		:= 99;				-- 予期せぬエラー
	REPORT_ID			CONSTANT char(11)		:= 'IPK30000421';	-- 帳票ID
	MAX_DATA			CONSTANT integer		:= 1000;			-- 出力データの最大件数
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
	gHktRnm					MHAKKOTAI.HKT_RNM%TYPE;					-- 発行体略称
  gRet                numeric := 0;                               -- 戻り値格納用
    gMgrCnt				integer := 0;							-- 銘柄件数
    gPreMgrCd           MGR_KIHON.MGR_CD%TYPE;                      -- 銘柄コード
    gGenZndk			decimal(16,2) := 0;						-- 現登債残高
	gFuriZndk			decimal(16,2) := 0;						-- 振替債残高
--==============================================================================
--					カーソル定義													
--==============================================================================
	curMeisai CURSOR FOR
		SELECT 	--+ INDEX(MG0 MGR_STS_PK) INDEX(MG1 MGR_KIHON_PK) INDEX(M01 MHAKKOTAI_PK)
				MG1.ISIN_CD,						-- ＩＳＩＮコード
				MG1.MGR_CD,							-- 銘柄コード
				MG1.MGR_RNM,						-- 銘柄略称
				(SELECT MCD4.CODE_NM FROM SCODE MCD4 WHERE MG1.JTK_KBN = MCD4.CODE_VALUE AND MCD4.CODE_SHUBETSU = '112') AS JTK_KBN_NM,		-- 受託区分名称
				(SELECT M64.TSUKA_NM FROM MTSUKA M64 WHERE MG1.HAKKO_TSUKA_CD = M64.TSUKA_CD) AS HAKKO_TSUKA_NM,		-- 発行通貨名称
				(SELECT MCD5.CODE_NM FROM SCODE MCD5 WHERE MG1.BOSHU_KBN = MCD5.CODE_VALUE AND MCD5.CODE_SHUBETSU = '528') AS BOSHU_KBN_NM,	-- 募集区分名称
				(SELECT MCD6.CODE_NM FROM SCODE MCD6 WHERE MG1.SHOKAN_METHOD_CD = MCD6.CODE_VALUE AND MCD6.CODE_SHUBETSU = '116') AS SHOKAN_METHOD_NM,	-- 償還方法名称
				(SELECT MCD7.CODE_NM FROM SCODE MCD7 WHERE MG1.SAIKEN_SHURUI = MCD7.CODE_VALUE AND MCD7.CODE_SHUBETSU = '514') AS SAIKEN_KBN_NM,		-- 債券種類名称
				MG1.FULLSHOKAN_KJT,					-- 満期償還期日
				(SELECT MCD8.CODE_NM FROM SCODE MCD8 WHERE MG1.TANPO_KBN = MCD8.CODE_VALUE AND MCD8.CODE_SHUBETSU = '519') AS TANPO_KBN_NM,				-- 担保区分名称
				MG1.SHASAI_TOTAL,					-- 社債の総額
				WK01.SHOKAN_YMD,					-- 償還年月日
				coalesce(WK01.GEN_GENSAI_KNGK,0) AS GEN_GENSAI_KNGK,			-- 現登債減債金額
				coalesce(WK01.FURI_GENSAI_KNGK,0) AS FURI_GENSAI_KNGK,		-- 振替債減債金額
				coalesce(coalesce(WK01.GEN_GENSAI_KNGK,WK01.FURI_GENSAI_KNGK),0) AS GENSAI_KNGK,		-- 減債金額
				(SELECT MCD3.CODE_NM FROM SCODE MCD3 WHERE WK01.YOJITSU_FLG = MCD3.CODE_VALUE AND MCD3.CODE_SHUBETSU = '144') AS YOJITSU_FLG_NM,	-- 予定実績フラグ名称
				CASE WHEN coalesce(WK01.FURI_SHOKAN_KBN::text, '') = '' THEN (SELECT MCD2.CODE_NM FROM SCODE MCD2 WHERE WK01.GEN_SHOKAN_KBN = MCD2.CODE_VALUE AND MCD2.CODE_SHUBETSU = '714')  ELSE (SELECT MCD1.CODE_NM FROM SCODE MCD1 WHERE WK01.FURI_SHOKAN_KBN = MCD1.CODE_VALUE AND MCD1.CODE_SHUBETSU = '714') END  AS JIYU, -- 事由
				CASE WHEN coalesce(WK01.FURI_SHOKAN_KBN::text, '') = '' THEN (SELECT MCD2.CODE_SORT FROM SCODE MCD2 WHERE WK01.GEN_SHOKAN_KBN = MCD2.CODE_VALUE AND MCD2.CODE_SHUBETSU = '714')  ELSE (SELECT MCD1.CODE_SORT FROM SCODE MCD1 WHERE WK01.FURI_SHOKAN_KBN = MCD1.CODE_VALUE AND MCD1.CODE_SHUBETSU = '714') END  AS CODE_SORT,
				CASE WHEN coalesce(WK01.FURI_SHOKAN_KBN::text, '') = '' THEN WK01.GEN_SHOKAN_KBN  ELSE WK01.FURI_SHOKAN_KBN END  AS SHOKAN_KBN,					-- 償還区分
				VJ1.BANK_RNM,						-- 銀行名略称(自行委託会社ビュー)
				VJ1.JIKO_DAIKO_KBN,					-- 自行代行区分
				WK01.GEN_SHOKAN_KBN,
				WK01.FURI_SHOKAN_KBN
		FROM (SELECT	WK001.ITAKU_KAISHA_CD, WK001.MGR_CD, WK001.SHOKAN_YMD,
						WK003.SHOKAN_KNGK AS GEN_GENSAI_KNGK, WK002.SHOKAN_KNGK AS FURI_GENSAI_KNGK,
						WK003.SHOKAN_KBN AS GEN_SHOKAN_KBN, WK002.SHOKAN_KBN AS FURI_SHOKAN_KBN, WK002.YOJITSU_FLG
				 FROM (SELECT 	Z01.ITAKU_KAISHA_CD, Z01.MGR_CD, Z01.SHOKAN_YMD,
									CASE
										WHEN Z01.SHOKAN_KBN = '01' THEN 'H'
										WHEN Z01.SHOKAN_KBN = '10' THEN 'A'
										WHEN Z01.SHOKAN_KBN = '20' THEN 'B'
										WHEN Z01.SHOKAN_KBN = '21' THEN 'B'
										WHEN Z01.SHOKAN_KBN = '30' THEN 'C'
										WHEN Z01.SHOKAN_KBN = '50' THEN 'D'
										WHEN Z01.SHOKAN_KBN = '40' THEN 'E'
										WHEN Z01.SHOKAN_KBN = '41' THEN 'E'
										WHEN Z01.SHOKAN_KBN = '60' THEN 'I' -- ＣＢ対応
										WHEN Z01.SHOKAN_KBN = '81' THEN 'A'
										WHEN Z01.SHOKAN_KBN = '82' THEN 'B'
										WHEN Z01.SHOKAN_KBN = '83' THEN 'C'
										WHEN Z01.SHOKAN_KBN = '84' THEN 'G'
										WHEN Z01.SHOKAN_KBN = '85' THEN 'D'
										WHEN Z01.SHOKAN_KBN = '86' THEN 'I' -- ＣＢ対応
										WHEN Z01.SHOKAN_KBN = '98' THEN 'F'
									END AS KBN
						 FROM		GENSAI_RIREKI Z01,MGR_KIHON MG1
 						 WHERE 		MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
   						 AND 		MG1.TOKUREI_SHASAI_FLG = 'Y'
					     AND 		MG1.ITAKU_KAISHA_CD = Z01.ITAKU_KAISHA_CD
    					 AND 		MG1.MGR_CD = Z01.MGR_CD
						 AND		Z01.SHOKAN_KBN IN ('01','10','20','21','30','40','41','50','60','81','82','83','84','85','86','98') -- ＣＢ対応
						 GROUP BY	Z01.ITAKU_KAISHA_CD, Z01.MGR_CD, Z01.SHOKAN_YMD,
									CASE
										WHEN Z01.SHOKAN_KBN = '01' THEN 'H'
										WHEN Z01.SHOKAN_KBN = '10' THEN 'A'
										WHEN Z01.SHOKAN_KBN = '20' THEN 'B'
										WHEN Z01.SHOKAN_KBN = '21' THEN 'B'
										WHEN Z01.SHOKAN_KBN = '30' THEN 'C'
										WHEN Z01.SHOKAN_KBN = '50' THEN 'D'
										WHEN Z01.SHOKAN_KBN = '40' THEN 'E'
										WHEN Z01.SHOKAN_KBN = '41' THEN 'E'
										WHEN Z01.SHOKAN_KBN = '60' THEN 'I' -- ＣＢ対応
										WHEN Z01.SHOKAN_KBN = '81' THEN 'A'
										WHEN Z01.SHOKAN_KBN = '82' THEN 'B'
										WHEN Z01.SHOKAN_KBN = '83' THEN 'C'
										WHEN Z01.SHOKAN_KBN = '84' THEN 'G'
										WHEN Z01.SHOKAN_KBN = '85' THEN 'D'
										WHEN Z01.SHOKAN_KBN = '86' THEN 'I' -- ＣＢ対応
										WHEN Z01.SHOKAN_KBN = '98' THEN 'F'
									END) wk001
LEFT OUTER JOIN (SELECT	Z01.ITAKU_KAISHA_CD, Z01.MGR_CD, Z01.SHOKAN_YMD, SUM(Z01.GENSAI_KNGK) AS SHOKAN_KNGK, Z01.SHOKAN_KBN, trim(both MAX(Z01.YOJITSU_FLG)) AS YOJITSU_FLG,
								CASE
									WHEN Z01.SHOKAN_KBN = '10' THEN 'A'
									WHEN Z01.SHOKAN_KBN = '20' THEN 'B'
									WHEN Z01.SHOKAN_KBN = '21' THEN 'B'
									WHEN Z01.SHOKAN_KBN = '30' THEN 'C'
									WHEN Z01.SHOKAN_KBN = '50' THEN 'D'
									WHEN Z01.SHOKAN_KBN = '40' THEN 'E'
									WHEN Z01.SHOKAN_KBN = '41' THEN 'E'
									WHEN Z01.SHOKAN_KBN = '60' THEN 'I' -- ＣＢ対応
								END AS KBN
						 FROM		GENSAI_RIREKI Z01,MGR_KIHON MG1
 						 WHERE 		MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
   						 AND 		MG1.TOKUREI_SHASAI_FLG = 'Y'
    					 AND 		MG1.ITAKU_KAISHA_CD = Z01.ITAKU_KAISHA_CD
    					 AND 		MG1.MGR_CD = Z01.MGR_CD
						 AND		Z01.SHOKAN_KBN IN ('10','20','21','30','40','41','50','60') -- ＣＢ対応
 
						 GROUP BY	Z01.ITAKU_KAISHA_CD, Z01.MGR_CD, Z01.SHOKAN_YMD, Z01.SHOKAN_KBN,
									CASE
										WHEN Z01.SHOKAN_KBN = '10' THEN 'A'
										WHEN Z01.SHOKAN_KBN = '20' THEN 'B'
										WHEN Z01.SHOKAN_KBN = '21' THEN 'B'
										WHEN Z01.SHOKAN_KBN = '30' THEN 'C'
										WHEN Z01.SHOKAN_KBN = '50' THEN 'D'
										WHEN Z01.SHOKAN_KBN = '40' THEN 'E'
										WHEN Z01.SHOKAN_KBN = '41' THEN 'E'
										WHEN Z01.SHOKAN_KBN = '60' THEN 'I' -- ＣＢ対応
									END) wk002 ON (WK001.ITAKU_KAISHA_CD = WK002.ITAKU_KAISHA_CD AND WK001.MGR_CD = WK002.MGR_CD AND WK001.SHOKAN_YMD = WK002.SHOKAN_YMD AND WK001.KBN = WK002.KBN)
LEFT OUTER JOIN (SELECT		Z01.ITAKU_KAISHA_CD, Z01.MGR_CD, Z01.SHOKAN_YMD, SUM(Z01.GENSAI_KNGK) AS SHOKAN_KNGK, Z01.SHOKAN_KBN,
									CASE
										WHEN Z01.SHOKAN_KBN = '01' THEN 'H'
										WHEN Z01.SHOKAN_KBN = '81' THEN 'A'
										WHEN Z01.SHOKAN_KBN = '82' THEN 'B'
										WHEN Z01.SHOKAN_KBN = '83' THEN 'C'
										WHEN Z01.SHOKAN_KBN = '85' THEN 'D'
										WHEN Z01.SHOKAN_KBN = '84' THEN 'G'
										WHEN Z01.SHOKAN_KBN = '86' THEN 'I' -- ＣＢ対応
										WHEN Z01.SHOKAN_KBN = '98' THEN 'F'
									END AS KBN
						 FROM		GENSAI_RIREKI Z01,MGR_KIHON MG1
 						 WHERE 		MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
   						 AND 		MG1.TOKUREI_SHASAI_FLG = 'Y'
    					 AND 		MG1.ITAKU_KAISHA_CD = Z01.ITAKU_KAISHA_CD
    					 AND 		MG1.MGR_CD = Z01.MGR_CD
						 AND		Z01.SHOKAN_KBN IN ('01','81','82','83','85','84','86','98') -- ＣＢ対応
 
						 GROUP BY	Z01.ITAKU_KAISHA_CD, Z01.MGR_CD, Z01.SHOKAN_YMD, Z01.SHOKAN_KBN,
									CASE
										WHEN Z01.SHOKAN_KBN = '01' THEN 'H'
										WHEN Z01.SHOKAN_KBN = '81' THEN 'A'
										WHEN Z01.SHOKAN_KBN = '82' THEN 'B'
										WHEN Z01.SHOKAN_KBN = '83' THEN 'C'
										WHEN Z01.SHOKAN_KBN = '84' THEN 'G'
										WHEN Z01.SHOKAN_KBN = '85' THEN 'D'
										WHEN Z01.SHOKAN_KBN = '86' THEN 'I' -- ＣＢ対応
										WHEN Z01.SHOKAN_KBN = '98' THEN 'F'
									END) wk003 ON (WK001.ITAKU_KAISHA_CD = WK003.ITAKU_KAISHA_CD AND WK001.MGR_CD = WK003.MGR_CD AND WK001.SHOKAN_YMD = WK003.SHOKAN_YMD AND WK001.KBN = WK003.KBN)  ) wk01, vjiko_itaku vj1, mgr_sts mg0, mgr_kihon mg1
LEFT OUTER JOIN mhakkotai m01 ON (MG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD AND MG1.HKT_CD = M01.HKT_CD)
WHERE MG1.ITAKU_KAISHA_CD = WK01.ITAKU_KAISHA_CD AND MG1.MGR_CD = WK01.MGR_CD AND MG1.ITAKU_KAISHA_CD = VJ1.KAIIN_ID AND MG1.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD AND MG1.MGR_CD = MG0.MGR_CD   AND MG1.HAKKO_YMD <= l_inGyomuYmd 			-- 業務日付が
  AND MG1.FULLSHOKAN_KJT >= l_inGyomuYmd 		-- 発行日〜満期償還期日 のものが対象
  AND ((l_inShasaiFlg = '0'
  				  -- 業務日付を基準として、併存状態の銘柄を出力
				  AND pkIpaZndk.getKjnZndk(MG1.ITAKU_KAISHA_CD, MG1.MGR_CD, l_inGyomuYmd, 83)::numeric > 0	--振替債残高
				  AND pkIpaZndk.getKjnZndk(MG1.ITAKU_KAISHA_CD, MG1.MGR_CD, l_inGyomuYmd, 3)::numeric > 0)	--現登債残高
				  -- 全特例社債を出力
				  OR (l_inShasaiFlg = '1')) AND MG1.HKT_CD LIKE CASE WHEN coalesce(trim(both l_inHktCd)::text, '') = '' THEN  '%'  ELSE l_inHktCd END AND M01.KOZA_TEN_CD LIKE CASE WHEN coalesce(trim(both l_inKozaTenCd)::text, '') = '' THEN  '%'  ELSE l_inKozaTenCd END AND trim(both M01.KOZA_TEN_CIFCD) LIKE CASE WHEN coalesce(trim(both l_inKozaTenCifCd)::text, '') = '' THEN  '%'  ELSE trim(both l_inKozaTenCifCd) END AND MG1.MGR_CD LIKE CASE WHEN coalesce(trim(both l_inMgrCd)::text, '') = '' THEN  '%'  ELSE l_inMgrCd END AND MG1.ISIN_CD LIKE CASE WHEN coalesce(trim(both l_inIsinCd)::text, '') = '' THEN  '%'  ELSE l_inIsinCd END AND MG1.JTK_KBN LIKE CASE WHEN coalesce(trim(both l_inJtkKbn)::text, '') = '' THEN  '%'  ELSE l_inJtkKbn END AND MG1.JTK_KBN != '2' --		AND		MG0.MGR_STAT_KBN = '1'	-- ※未承認でも出力する仕様のため、この条件は含まない
  AND MG0.MASSHO_FLG = '0' ORDER BY	MG1.ISIN_CD, WK01.SHOKAN_YMD, CODE_SORT;	-- 償還区分ソート順
	-- 元利払日の条件がある場合SQL
	curMeisai2 CURSOR FOR
		SELECT 	--+ INDEX(MG0 MGR_STS_PK) INDEX(MG1 MGR_KIHON_PK) INDEX(M01 MHAKKOTAI_PK)
				MG1.ISIN_CD,						-- ＩＳＩＮコード
				MG1.MGR_CD,							-- 銘柄コード
				MG1.MGR_RNM,						-- 銘柄略称
				(SELECT MCD4.CODE_NM FROM SCODE MCD4 WHERE MG1.JTK_KBN = MCD4.CODE_VALUE AND MCD4.CODE_SHUBETSU = '112') AS JTK_KBN_NM,		-- 受託区分名称
				(SELECT M64.TSUKA_NM FROM MTSUKA M64 WHERE MG1.HAKKO_TSUKA_CD = M64.TSUKA_CD) AS HAKKO_TSUKA_NM,		-- 発行通貨名称
				(SELECT MCD5.CODE_NM FROM SCODE MCD5 WHERE MG1.BOSHU_KBN = MCD5.CODE_VALUE AND MCD5.CODE_SHUBETSU = '528') AS BOSHU_KBN_NM,	-- 募集区分名称
				(SELECT MCD6.CODE_NM FROM SCODE MCD6 WHERE MG1.SHOKAN_METHOD_CD = MCD6.CODE_VALUE AND MCD6.CODE_SHUBETSU = '116') AS SHOKAN_METHOD_NM,	-- 償還方法名称
				(SELECT MCD7.CODE_NM FROM SCODE MCD7 WHERE MG1.SAIKEN_SHURUI = MCD7.CODE_VALUE AND MCD7.CODE_SHUBETSU = '514') AS SAIKEN_KBN_NM,		-- 債券種類名称
				MG1.FULLSHOKAN_KJT,					-- 満期償還期日
				(SELECT MCD8.CODE_NM FROM SCODE MCD8 WHERE MG1.TANPO_KBN = MCD8.CODE_VALUE AND MCD8.CODE_SHUBETSU = '519') AS TANPO_KBN_NM,				-- 担保区分名称
				MG1.SHASAI_TOTAL,					-- 社債の総額
				WK01.SHOKAN_YMD,					-- 償還年月日
				coalesce(WK01.GEN_GENSAI_KNGK,0) AS GEN_GENSAI_KNGK,			-- 現登債減債金額
				coalesce(WK01.FURI_GENSAI_KNGK,0) AS FURI_GENSAI_KNGK,		-- 振替債減債金額
				coalesce(coalesce(WK01.GEN_GENSAI_KNGK,WK01.FURI_GENSAI_KNGK),0) AS GENSAI_KNGK,		-- 減債金額
				(SELECT MCD3.CODE_NM FROM SCODE MCD3 WHERE WK01.YOJITSU_FLG = MCD3.CODE_VALUE AND MCD3.CODE_SHUBETSU = '144') AS YOJITSU_FLG_NM,	-- 予定実績フラグ名称
				CASE WHEN coalesce(WK01.FURI_SHOKAN_KBN::text, '') = '' THEN (SELECT MCD2.CODE_NM FROM SCODE MCD2 WHERE WK01.GEN_SHOKAN_KBN = MCD2.CODE_VALUE AND MCD2.CODE_SHUBETSU = '714')  ELSE (SELECT MCD1.CODE_NM FROM SCODE MCD1 WHERE WK01.FURI_SHOKAN_KBN = MCD1.CODE_VALUE AND MCD1.CODE_SHUBETSU = '714') END  AS JIYU, -- 事由
				CASE WHEN coalesce(WK01.FURI_SHOKAN_KBN::text, '') = '' THEN (SELECT MCD2.CODE_SORT FROM SCODE MCD2 WHERE WK01.GEN_SHOKAN_KBN = MCD2.CODE_VALUE AND MCD2.CODE_SHUBETSU = '714')  ELSE (SELECT MCD1.CODE_SORT FROM SCODE MCD1 WHERE WK01.FURI_SHOKAN_KBN = MCD1.CODE_VALUE AND MCD1.CODE_SHUBETSU = '714') END  AS CODE_SORT,
				CASE WHEN coalesce(WK01.FURI_SHOKAN_KBN::text, '') = '' THEN WK01.GEN_SHOKAN_KBN  ELSE WK01.FURI_SHOKAN_KBN END  AS SHOKAN_KBN,					-- 償還区分
				VJ1.BANK_RNM,						-- 銀行名略称(自行委託会社ビュー)
				VJ1.JIKO_DAIKO_KBN,					-- 自行代行区分
				WK01.GEN_SHOKAN_KBN,
				WK01.FURI_SHOKAN_KBN
		FROM (SELECT  --+ INDEX(MG1 MGR_KIHON_PK) INDEX(MG3 MGR_SHOKIJ_PK)
							MG1.ITAKU_KAISHA_CD,MG1.MGR_CD
				 FROM		MGR_KIHON MG1,MGR_SHOKIJ MG3
				 WHERE		MG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
				 AND		MG1.MGR_CD = MG3.MGR_CD
				 AND		MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
				 AND        MG1.Tokurei_Shasai_Flg = 'Y'
				 AND		MG3.SHOKAN_YMD BETWEEN l_inGnrbaraiFYmd AND l_inGnrbaraiTYmd
				 GROUP BY	MG1.ITAKU_KAISHA_CD,MG1.MGR_CD) wk02, (SELECT	WK001.ITAKU_KAISHA_CD, WK001.MGR_CD, WK001.SHOKAN_YMD,
						WK003.SHOKAN_KNGK AS GEN_GENSAI_KNGK, WK002.SHOKAN_KNGK AS FURI_GENSAI_KNGK,
						WK003.SHOKAN_KBN AS GEN_SHOKAN_KBN, WK002.SHOKAN_KBN AS FURI_SHOKAN_KBN, WK002.YOJITSU_FLG
				 FROM (SELECT 	Z01.ITAKU_KAISHA_CD, Z01.MGR_CD, Z01.SHOKAN_YMD,
									CASE
										WHEN Z01.SHOKAN_KBN = '01' THEN 'H'
										WHEN Z01.SHOKAN_KBN = '10' THEN 'A'
										WHEN Z01.SHOKAN_KBN = '20' THEN 'B'
										WHEN Z01.SHOKAN_KBN = '21' THEN 'B'
										WHEN Z01.SHOKAN_KBN = '30' THEN 'C'
										WHEN Z01.SHOKAN_KBN = '50' THEN 'D'
										WHEN Z01.SHOKAN_KBN = '40' THEN 'E'
										WHEN Z01.SHOKAN_KBN = '41' THEN 'E'
										WHEN Z01.SHOKAN_KBN = '60' THEN 'I' -- ＣＢ対応
										WHEN Z01.SHOKAN_KBN = '81' THEN 'A'
										WHEN Z01.SHOKAN_KBN = '82' THEN 'B'
										WHEN Z01.SHOKAN_KBN = '83' THEN 'C'
										WHEN Z01.SHOKAN_KBN = '84' THEN 'G'
										WHEN Z01.SHOKAN_KBN = '85' THEN 'D'
										WHEN Z01.SHOKAN_KBN = '86' THEN 'I' -- ＣＢ対応
										WHEN Z01.SHOKAN_KBN = '98' THEN 'F'
									END AS KBN
						 FROM		GENSAI_RIREKI Z01,MGR_KIHON MG1
 						 WHERE 		MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
   						 AND 		MG1.TOKUREI_SHASAI_FLG = 'Y'
    					 AND 		MG1.ITAKU_KAISHA_CD = Z01.ITAKU_KAISHA_CD
    					 AND 		MG1.MGR_CD = Z01.MGR_CD
						 AND		Z01.SHOKAN_KBN IN ('01','10','20','21','30','40','41','50','60','81','82','83','84','85','86','98') -- ＣＢ対応
						 GROUP BY	Z01.ITAKU_KAISHA_CD, Z01.MGR_CD, Z01.SHOKAN_YMD,
									CASE
										WHEN Z01.SHOKAN_KBN = '01' THEN 'H'
										WHEN Z01.SHOKAN_KBN = '10' THEN 'A'
										WHEN Z01.SHOKAN_KBN = '20' THEN 'B'
										WHEN Z01.SHOKAN_KBN = '21' THEN 'B'
										WHEN Z01.SHOKAN_KBN = '30' THEN 'C'
										WHEN Z01.SHOKAN_KBN = '50' THEN 'D'
										WHEN Z01.SHOKAN_KBN = '40' THEN 'E'
										WHEN Z01.SHOKAN_KBN = '41' THEN 'E'
										WHEN Z01.SHOKAN_KBN = '60' THEN 'I' -- ＣＢ対応
										WHEN Z01.SHOKAN_KBN = '81' THEN 'A'
										WHEN Z01.SHOKAN_KBN = '82' THEN 'B'
										WHEN Z01.SHOKAN_KBN = '83' THEN 'C'
										WHEN Z01.SHOKAN_KBN = '84' THEN 'G'
										WHEN Z01.SHOKAN_KBN = '85' THEN 'D'
										WHEN Z01.SHOKAN_KBN = '86' THEN 'I' -- ＣＢ対応
										WHEN Z01.SHOKAN_KBN = '98' THEN 'F'
									END) wk001
LEFT OUTER JOIN (SELECT	Z01.ITAKU_KAISHA_CD, Z01.MGR_CD, Z01.SHOKAN_YMD, SUM(Z01.GENSAI_KNGK) AS SHOKAN_KNGK, Z01.SHOKAN_KBN, trim(both MAX(Z01.YOJITSU_FLG)) AS YOJITSU_FLG,
								CASE
									WHEN Z01.SHOKAN_KBN = '10' THEN 'A'
									WHEN Z01.SHOKAN_KBN = '20' THEN 'B'
									WHEN Z01.SHOKAN_KBN = '21' THEN 'B'
									WHEN Z01.SHOKAN_KBN = '30' THEN 'C'
									WHEN Z01.SHOKAN_KBN = '50' THEN 'D'
									WHEN Z01.SHOKAN_KBN = '40' THEN 'E'
									WHEN Z01.SHOKAN_KBN = '41' THEN 'E'
									WHEN Z01.SHOKAN_KBN = '60' THEN 'I' -- ＣＢ対応
								END AS KBN
						 FROM		GENSAI_RIREKI Z01,MGR_KIHON MG1
 						 WHERE 		MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
   					 	 AND 		MG1.TOKUREI_SHASAI_FLG = 'Y'
    					 AND 		MG1.ITAKU_KAISHA_CD = Z01.ITAKU_KAISHA_CD
    					 AND 		MG1.MGR_CD = Z01.MGR_CD
						 AND		Z01.SHOKAN_KBN IN ('10','20','21','30','40','41','50','60') -- ＣＢ対応
 
						 GROUP BY	Z01.ITAKU_KAISHA_CD, Z01.MGR_CD, Z01.SHOKAN_YMD, Z01.SHOKAN_KBN,
									CASE
										WHEN Z01.SHOKAN_KBN = '10' THEN 'A'
										WHEN Z01.SHOKAN_KBN = '20' THEN 'B'
										WHEN Z01.SHOKAN_KBN = '21' THEN 'B'
										WHEN Z01.SHOKAN_KBN = '30' THEN 'C'
										WHEN Z01.SHOKAN_KBN = '50' THEN 'D'
										WHEN Z01.SHOKAN_KBN = '40' THEN 'E'
										WHEN Z01.SHOKAN_KBN = '41' THEN 'E'
										WHEN Z01.SHOKAN_KBN = '60' THEN 'I' -- ＣＢ対応
									END) wk002 ON (WK001.ITAKU_KAISHA_CD = WK002.ITAKU_KAISHA_CD AND WK001.MGR_CD = WK002.MGR_CD AND WK001.SHOKAN_YMD = WK002.SHOKAN_YMD AND WK001.KBN = WK002.KBN)
LEFT OUTER JOIN (SELECT		Z01.ITAKU_KAISHA_CD, Z01.MGR_CD, Z01.SHOKAN_YMD, SUM(Z01.GENSAI_KNGK) AS SHOKAN_KNGK, Z01.SHOKAN_KBN,
									CASE
										WHEN Z01.SHOKAN_KBN = '01' THEN 'H'
										WHEN Z01.SHOKAN_KBN = '81' THEN 'A'
										WHEN Z01.SHOKAN_KBN = '82' THEN 'B'
										WHEN Z01.SHOKAN_KBN = '83' THEN 'C'
										WHEN Z01.SHOKAN_KBN = '85' THEN 'D'
										WHEN Z01.SHOKAN_KBN = '84' THEN 'G'
										WHEN Z01.SHOKAN_KBN = '86' THEN 'I' -- ＣＢ対応
										WHEN Z01.SHOKAN_KBN = '98' THEN 'F'
									END AS KBN
						 FROM		GENSAI_RIREKI Z01,MGR_KIHON MG1
 						 WHERE 		MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
   						 AND 		MG1.TOKUREI_SHASAI_FLG = 'Y'
    					 AND 		MG1.ITAKU_KAISHA_CD = Z01.ITAKU_KAISHA_CD
    					 AND 		MG1.MGR_CD = Z01.MGR_CD
						 AND		Z01.SHOKAN_KBN IN ('01','81','82','83','85','84','86','98') -- ＣＢ対応
 
						 GROUP BY	Z01.ITAKU_KAISHA_CD, Z01.MGR_CD, Z01.SHOKAN_YMD, Z01.SHOKAN_KBN,
									CASE
										WHEN Z01.SHOKAN_KBN = '01' THEN 'H'
										WHEN Z01.SHOKAN_KBN = '81' THEN 'A'
										WHEN Z01.SHOKAN_KBN = '82' THEN 'B'
										WHEN Z01.SHOKAN_KBN = '83' THEN 'C'
										WHEN Z01.SHOKAN_KBN = '84' THEN 'G'
										WHEN Z01.SHOKAN_KBN = '85' THEN 'D'
										WHEN Z01.SHOKAN_KBN = '86' THEN 'I' -- ＣＢ対応
										WHEN Z01.SHOKAN_KBN = '98' THEN 'F'
									END) wk003 ON (WK001.ITAKU_KAISHA_CD = WK003.ITAKU_KAISHA_CD AND WK001.MGR_CD = WK003.MGR_CD AND WK001.SHOKAN_YMD = WK003.SHOKAN_YMD AND WK001.KBN = WK003.KBN)  ) wk01, vjiko_itaku vj1, mgr_sts mg0, mgr_kihon mg1
LEFT OUTER JOIN mhakkotai m01 ON (MG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD AND MG1.HKT_CD = M01.HKT_CD)
WHERE MG1.ITAKU_KAISHA_CD = WK01.ITAKU_KAISHA_CD AND MG1.MGR_CD = WK01.MGR_CD AND MG1.ITAKU_KAISHA_CD = WK02.ITAKU_KAISHA_CD AND MG1.MGR_CD = WK02.MGR_CD AND MG1.ITAKU_KAISHA_CD = VJ1.KAIIN_ID AND MG1.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD AND MG1.MGR_CD = MG0.MGR_CD   AND MG1.HAKKO_YMD <= l_inGyomuYmd 			-- 業務日付が
  AND MG1.FULLSHOKAN_KJT >= l_inGyomuYmd 		-- 発行日〜満期償還期日 のものが対象
  AND ((l_inShasaiFlg = '0'
  				  -- 業務日付を基準として、併存状態の銘柄を出力
				  AND pkIpaZndk.getKjnZndk(MG1.ITAKU_KAISHA_CD, MG1.MGR_CD, l_inGyomuYmd, 83)::numeric > 0	--振替債残高
				  AND pkIpaZndk.getKjnZndk(MG1.ITAKU_KAISHA_CD, MG1.MGR_CD, l_inGyomuYmd, 3)::numeric > 0)	--現登債残高
				  -- 全特例社債を出力
				  OR (l_inShasaiFlg = '1')) AND MG1.HKT_CD LIKE CASE WHEN coalesce(trim(both l_inHktCd)::text, '') = '' THEN  '%'  ELSE l_inHktCd END AND M01.KOZA_TEN_CD LIKE CASE WHEN coalesce(trim(both l_inKozaTenCd)::text, '') = '' THEN  '%'  ELSE l_inKozaTenCd END AND trim(both M01.KOZA_TEN_CIFCD) LIKE CASE WHEN coalesce(trim(both l_inKozaTenCifCd)::text, '') = '' THEN  '%'  ELSE trim(both l_inKozaTenCifCd) END AND MG1.MGR_CD LIKE CASE WHEN coalesce(trim(both l_inMgrCd)::text, '') = '' THEN  '%'  ELSE l_inMgrCd END AND MG1.ISIN_CD LIKE CASE WHEN coalesce(trim(both l_inIsinCd)::text, '') = '' THEN  '%'  ELSE l_inIsinCd END AND MG1.JTK_KBN LIKE CASE WHEN coalesce(trim(both l_inJtkKbn)::text, '') = '' THEN  '%'  ELSE l_inJtkKbn END AND MG1.JTK_KBN != '2' --		AND		MG0.MGR_STAT_KBN = '1'	-- ※未承認でも出力する仕様のため、この条件は含まない
  AND MG0.MASSHO_FLG = '0' ORDER BY	MG1.ISIN_CD, WK01.SHOKAN_YMD, CODE_SORT;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPK004K00R02 START');	END IF;
    IF DEBUG = 1 THEN
       CALL pkLog.debug(l_inUserId, 'SPIPK004K00R02', 'IPK30000421' || ' START');
       CALL pkLog.debug(l_inUserId, 'IPK30000421', 'param error 全特例社債指定フラグ:' || l_inShasaiFlg);
       CALL pkLog.debug(l_inUserId, 'IPK30000421', 'param error 発行体コード:' || l_inHktCd);
       CALL pkLog.debug(l_inUserId, 'IPK30000421', 'param error 口座店コード:' || l_inKozaTenCd);
       CALL pkLog.debug(l_inUserId, 'IPK30000421', 'param error 口座店CIFコード:' || l_inKozaTenCifCd);
       CALL pkLog.debug(l_inUserId, 'IPK30000421', 'param error 銘柄コード:' || l_inMgrCd);
       CALL pkLog.debug(l_inUserId, 'IPK30000421', 'param error ISINコード:' || l_inIsinCd);
       CALL pkLog.debug(l_inUserId, 'IPK30000421', 'param error 受託区分:' || l_inJtkKbn);
	   CALL pkLog.debug(l_inUserId, 'IPK30000421', 'param error 元利払日From:' || l_inGnrbaraiFYmd);
	   CALL pkLog.debug(l_inUserId, 'IPK30000421', 'param error 元利払日To:' || l_inGnrbaraiTYmd);
       CALL pkLog.debug(l_inUserId, 'IPK30000421', 'param error 委託会社コード:' || l_inItakuKaishaCd);
       CALL pkLog.debug(l_inUserId, 'IPK30000421', 'param error ユーザーID:' || l_inUserId);
       CALL pkLog.debug(l_inUserId, 'IPK30000421', 'param error 帳票区分:' || l_inChohyoKbn);
       CALL pkLog.debug(l_inUserId, 'IPK30000421', 'param error 業務日付:' || l_inGyomuYmd);
    END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inShasaiFlg)::text, '') = ''
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
	-- 発行体コードが入力されている場合は発行体略称を取得する
	IF (trim(both l_inHktCd) IS NOT NULL AND (trim(both l_inHktCd))::text <> '') THEN
		gHktRnm := SPIPK004K00R02_getHktRnm(l_inItakuKaishaCd, l_inHktCd);
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
    -- 初期化
    gPreMgrCd := '';
	-- 元利払日が入力されている場合は、curMeisai2を使うようにする。
	IF coalesce(l_inGnrbaraiFYmd::text, '') = '' THEN
		-- データ取得
		FOR recMeisai IN curMeisai LOOP
			-- 銘柄単位で、最初のレコードのみ社債の総額を出力する。
			-- 最初のレコードの場合、現登債残高と振替債残高の値を0にクリアする。
			IF gPreMgrCd = recMeisai.MGR_CD THEN
				recMeisai.SHASAI_TOTAL := NULL;
			ELSE
				gGenZndk := 0;
				gFuriZndk := 0;
				-- 銘柄の件数を求める。
				gMgrCnt := gMgrCnt + 1;
			END IF;
			-- 銘柄の件数が、MAX_DATA以上なら、エラーを返して処理を抜ける。
			IF gMgrCnt > MAX_DATA THEN
				l_outSqlCode := RTN_DATA_OVER;
				l_outSqlErrM := '';
				RETURN;
			END IF;
			-- 現登債残高と振替債残高を算出する。
			CASE
				WHEN recMeisai.GEN_SHOKAN_KBN = '98' THEN
					gGenZndk := recMeisai.SHASAI_TOTAL - recMeisai.GEN_GENSAI_KNGK;
				WHEN recMeisai.GEN_SHOKAN_KBN IN ('01','81','82','83','84','85','86') THEN  -- ＣＢ対応
					gGenZndk := gGenZndk - recMeisai.GEN_GENSAI_KNGK;
				ELSE
					gGenZndk := gGenZndk;
			END CASE;
			CASE
				WHEN recMeisai.GEN_SHOKAN_KBN IN ('98','99') THEN
					gFuriZndk := 0;
				WHEN recMeisai.GEN_SHOKAN_KBN = '01' THEN
					gFuriZndk := gFuriZndk + recMeisai.GEN_GENSAI_KNGK;
				WHEN recMeisai.FURI_SHOKAN_KBN IN ('10','20','21','30','40','41','50','60') THEN  -- ＣＢ対応
					gFuriZndk := gFuriZndk - recMeisai.FURI_GENSAI_KNGK;
				ELSE
					gFuriZndk := gFuriZndk;
			END CASE;
			-- 減債額が0の場合は、NULLにする。(現行保障)
			IF recMeisai.GEN_GENSAI_KNGK = 0 THEN
				recMeisai.GEN_GENSAI_KNGK := NULL;
			END IF;
			IF recMeisai.FURI_GENSAI_KNGK = 0 THEN
				recMeisai.FURI_GENSAI_KNGK := NULL;
			END IF;
			-- 委託会社略称
			IF recMeisai.JIKO_DAIKO_KBN != '2' THEN
				recMeisai.BANK_RNM := NULL;
			END IF;
			-- 帳票ワークへデータを追加
			gSeqNo := gSeqNo + 1;
					-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- 入力ユーザＩＤ
		v_item.l_inItem002 := l_inHktCd;	-- 入力発行体コード
		v_item.l_inItem003 := l_inKozaTenCd;	-- 入力口座店コード
		v_item.l_inItem004 := l_inKozaTenCifCd;	-- 入力口座店ＣＩＦコード
		v_item.l_inItem005 := gHktRnm;	-- 発行体略称
		v_item.l_inItem006 := recMeisai.ISIN_CD;	-- ＩＳＩＮコード
		v_item.l_inItem007 := recMeisai.MGR_CD;	-- 銘柄コード
		v_item.l_inItem008 := recMeisai.MGR_RNM;	-- 銘柄略称
		v_item.l_inItem009 := recMeisai.JTK_KBN_NM;	-- 受託区分名称
		v_item.l_inItem010 := recMeisai.HAKKO_TSUKA_NM;	-- 発行通貨名称
		v_item.l_inItem011 := recMeisai.BOSHU_KBN_NM;	-- 募集区分名称
		v_item.l_inItem012 := recMeisai.SHOKAN_METHOD_NM;	-- 償還方法名称
		v_item.l_inItem013 := recMeisai.SAIKEN_KBN_NM;	-- 債券種類名称
		v_item.l_inItem014 := recMeisai.FULLSHOKAN_KJT;	-- 満期償還期日
		v_item.l_inItem015 := recMeisai.TANPO_KBN_NM;	-- 担保区分名称
		v_item.l_inItem016 := recMeisai.SHOKAN_YMD;	-- 償還年月日
		v_item.l_inItem017 := recMeisai.YOJITSU_FLG_NM;	-- 予定実績フラグ名称
		v_item.l_inItem018 := recMeisai.JIYU;	-- 事由
		v_item.l_inItem019 := recMeisai.SHASAI_TOTAL;	-- 社債の総額
		v_item.l_inItem020 := recMeisai.GEN_GENSAI_KNGK;	-- 現登債減債金額
		v_item.l_inItem021 := recMeisai.FURI_GENSAI_KNGK;	-- 振替債減債金額
		v_item.l_inItem022 := gGenZndk;	-- 現登債残高
		v_item.l_inItem023 := gFuriZndk;	-- 振替債残高
		v_item.l_inItem024 := gGenZndk + gFuriZndk;	-- 社債の残高
		v_item.l_inItem026 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem027 := FMT_HAKKO_KNGK_J;	-- 発行金額書式フォーマット
		v_item.l_inItem028 := FMT_RBR_KNGK_J;	-- 利払金額書式フォーマット
		v_item.l_inItem029 := FMT_SHOKAN_KNGK_J;	-- 償還金額書式フォーマット
		v_item.l_inItem030 := recMeisai.BANK_RNM;	-- 銀行名略称(自行委託会社ビュー)
		
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
			-- 前のレコードの銘柄コードを保存しておく。
			gPreMgrCd := recMeisai.MGR_CD;
		END LOOP;
	ELSE
		-- データ取得
		FOR recMeisai IN curMeisai2 LOOP
			-- 銘柄単位で、最初のレコードのみ社債の総額を出力する。
			-- 最初のレコードの場合、現登債残高と振替債残高の値を0にクリアする。
			IF gPreMgrCd = recMeisai.MGR_CD THEN
				recMeisai.SHASAI_TOTAL := NULL;
			ELSE
				gGenZndk := 0;
				gFuriZndk := 0;
				-- 銘柄の件数を求める。
				gMgrCnt := gMgrCnt + 1;
			END IF;
			-- 銘柄の件数が、MAX_DATA以上なら、エラーを返して処理を抜ける。
			IF gMgrCnt > MAX_DATA THEN
				l_outSqlCode := RTN_DATA_OVER;
				l_outSqlErrM := '';
				RETURN;
			END IF;
			-- 現登債残高と振替債残高を算出する。
			-- 既存バグの修正
			-- 現登債・振替債の残高を正しく計算できるようにする（IP-05851）
			CASE
				WHEN recMeisai.GEN_SHOKAN_KBN = '98' THEN
					gGenZndk := recMeisai.SHASAI_TOTAL - recMeisai.GEN_GENSAI_KNGK;
				WHEN recMeisai.GEN_SHOKAN_KBN IN ('01','81','82','83','84','85','86') THEN  -- ＣＢ対応
					gGenZndk := gGenZndk - recMeisai.GEN_GENSAI_KNGK;
				ELSE
					gGenZndk := gGenZndk;
			END CASE;
			CASE
				WHEN recMeisai.GEN_SHOKAN_KBN IN ('98','99') THEN
					gFuriZndk := 0;
				WHEN recMeisai.GEN_SHOKAN_KBN = '01' THEN
					gFuriZndk := gFuriZndk + recMeisai.GEN_GENSAI_KNGK;
				WHEN recMeisai.FURI_SHOKAN_KBN IN ('10','20','21','30','40','41','50','60') THEN  -- ＣＢ対応
					gFuriZndk := gFuriZndk - recMeisai.FURI_GENSAI_KNGK;
				ELSE
					gFuriZndk := gFuriZndk;
			END CASE;
			-- 減債額が0の場合は、NULLにする。(現行保障)
			IF recMeisai.GEN_GENSAI_KNGK = 0 THEN
				recMeisai.GEN_GENSAI_KNGK := NULL;
			END IF;
			IF recMeisai.FURI_GENSAI_KNGK = 0 THEN
				recMeisai.FURI_GENSAI_KNGK := NULL;
			END IF;
			-- 委託会社略称
			IF recMeisai.JIKO_DAIKO_KBN != '2' THEN
				recMeisai.BANK_RNM := NULL;
			END IF;
			gSeqNo := gSeqNo + 1;
					-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- 入力ユーザＩＤ
		v_item.l_inItem002 := l_inHktCd;	-- 入力発行体コード
		v_item.l_inItem003 := l_inKozaTenCd;	-- 入力口座店コード
		v_item.l_inItem004 := l_inKozaTenCifCd;	-- 入力口座店ＣＩＦコード
		v_item.l_inItem005 := gHktRnm;	-- 発行体略称
		v_item.l_inItem006 := recMeisai.ISIN_CD;	-- ＩＳＩＮコード
		v_item.l_inItem007 := recMeisai.MGR_CD;	-- 銘柄コード
		v_item.l_inItem008 := recMeisai.MGR_RNM;	-- 銘柄略称
		v_item.l_inItem009 := recMeisai.JTK_KBN_NM;	-- 受託区分名称
		v_item.l_inItem010 := recMeisai.HAKKO_TSUKA_NM;	-- 発行通貨名称
		v_item.l_inItem011 := recMeisai.BOSHU_KBN_NM;	-- 募集区分名称
		v_item.l_inItem012 := recMeisai.SHOKAN_METHOD_NM;	-- 償還方法名称
		v_item.l_inItem013 := recMeisai.SAIKEN_KBN_NM;	-- 債券種類名称
		v_item.l_inItem014 := recMeisai.FULLSHOKAN_KJT;	-- 満期償還期日
		v_item.l_inItem015 := recMeisai.TANPO_KBN_NM;	-- 担保区分名称
		v_item.l_inItem016 := recMeisai.SHOKAN_YMD;	-- 償還年月日
		v_item.l_inItem017 := recMeisai.YOJITSU_FLG_NM;	-- 予定実績フラグ名称
		v_item.l_inItem018 := recMeisai.JIYU;	-- 事由
		v_item.l_inItem019 := recMeisai.SHASAI_TOTAL;	-- 社債の総額
		v_item.l_inItem020 := recMeisai.GEN_GENSAI_KNGK;	-- 現登債減債金額
		v_item.l_inItem021 := recMeisai.FURI_GENSAI_KNGK;	-- 振替債減債金額
		v_item.l_inItem022 := gGenZndk;	-- 現登債残高
		v_item.l_inItem023 := gFuriZndk;	-- 振替債残高
		v_item.l_inItem024 := gGenZndk + gFuriZndk;	-- 社債の残高
		v_item.l_inItem026 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem027 := FMT_HAKKO_KNGK_J;	-- 発行金額書式フォーマット
		v_item.l_inItem028 := FMT_RBR_KNGK_J;	-- 利払金額書式フォーマット
		v_item.l_inItem029 := FMT_SHOKAN_KNGK_J;	-- 償還金額書式フォーマット
		v_item.l_inItem030 := recMeisai.BANK_RNM;	-- 銀行名略称(自行委託会社ビュー)
		
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
			gPreMgrCd := recMeisai.MGR_CD;
		END LOOP;
	END IF;
	IF gSeqNo = 0 THEN
        IF DEBUG = 1 THEN CALL PkLog.debug(l_inUserId, REPORT_ID, '対象データ無し用のデータを出力します。' );END IF;
        -- 対象データなし
        gRtnCd := RTN_NODATA;
        -- データ無し帳票出力
        gRet := PKIPACALCTESURYO.setNoDataPrint(l_inItakuKaishaCd,  -- 委託会社コード
                                                l_inUserId,         -- ユーザID
                                                l_ingyomuymd,       -- 業務日付
                                                REPORT_ID,          -- 帳票ID
                                                l_inChohyoKbn,      -- 帳票区分
                                                18,                 -- 対象データなし の出力位置
                                                l_inUserId,       -- セットするアイテムその１
                                                1,                  -- セットするアイテムその１のItem番号
                                                REPORT_ID,				-- セットするアイテムその2
                                                26,                  -- セットするアイテムその2のItem番号
                                                '',       -- セットするアイテムその3
                                                0,                  -- セットするアイテムその3のItem番号
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
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPK004K00R02 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		-- ROLLBACK;
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
--		RAISE;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipk004k00r02 ( l_inShasaiFlg TEXT, l_inHktCd TEXT, l_inKozaTenCd TEXT, l_inKozaTenCifCd TEXT, l_inMgrCd TEXT, l_inIsinCd TEXT, l_inJtkKbn TEXT, l_inGnrbaraiFYmd TEXT, l_inGnrbaraiTYmd TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spipk004k00r02_gethktrnm (inItakuKaishaCd text, inHktCd text) RETURNS MHAKKOTAI.HKT_RNM%TYPE AS $body$
DECLARE

	hkt_rnm		MHAKKOTAI.HKT_RNM%TYPE := NULL;

BEGIN
	SELECT	M01.HKT_RNM
	INTO STRICT	hkt_rnm
	FROM	MHAKKOTAI M01
	WHERE	M01.ITAKU_KAISHA_CD = inItakuKaishaCd
	AND		M01.HKT_CD = inHktCd;
	RETURN hkt_rnm;
EXCEPTION
	WHEN no_data_found	THEN RETURN NULL;
	WHEN OTHERS			THEN RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spipk004k00r02_gethktrnm (inItakuKaishaCd text, inHktCd text) FROM PUBLIC;