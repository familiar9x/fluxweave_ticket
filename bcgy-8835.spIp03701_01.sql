




CREATE OR REPLACE PROCEDURE spip03701_01 ( l_inUserId TEXT,		-- ユーザーID
 l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inMgrCd text,	-- 銘柄コード
 l_inIsinCd TEXT,		-- ISINコード
 l_inHakkoYmd TEXT,		-- 発行日
 l_inTsuchiYmd TEXT,		-- 通知日
 l_inChohyoKbn TEXT,		-- 帳票区分
 l_outSqlCode OUT integer,		-- リターン値
 l_outSqlErrM OUT text	-- エラーコメント
 ) AS $body$
DECLARE

--
--/* 著作権:	Copyright(c)2004
--/* 会社名:	JIP
--/* 概要　:	顧客宛帳票出力指示画面の入力条件により、償還スケジュール表を作成する。
--/* @author:	yoshisue
--/* $Id: spIp03701_01.sql,v 1.40 2009/01/28 00:26:46 fujimoto Exp $
--/* @param	l_inUserId				IN	TEXT,		-- ユーザーID
--/* 			l_inItakuKaishaCd		IN	TEXT,		-- 委託会社コード
--/*			l_inMgrCd				IN	VARCHAR,	-- 銘柄コード
--/*			l_inIsinCd				IN	TEXT,		-- ISINコード
--/*			l_inHakkoYmd			IN	TEXT,		-- 発行日
--/*			l_inTsuchiYmd			IN	TEXT,		-- 通知日
--/*			l_inChohyoKbn			IN	TEXT,		-- 帳票区分
--/*			l_outSqlCode			OUT	NUMERIC,		-- リターン値
--/*			l_outSqlErrM			OUT	VARCHAR	-- エラーコメント
--/*
--/* @return なし
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.03.02	JIP				新規作成
--/*	2005.08.25  yoshisue		1.2次リリースに向けて修正
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
	REPORT_ID			CONSTANT char(11)		:= 'IP030003711';	-- 帳票ID
	-- 書式フォーマット
	FMT_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	-- 書式フォーマット（外貨）
	FMT_KNGK_F	CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';
	TSUCHI_YMD_DEF		CONSTANT char(16)	:= '      年  月  日';		-- 通知日（デフォルト）
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd					integer :=	RTN_OK;		-- リターンコード
	gSeqNo					integer := 0;			-- シーケンス
	gGyomuYmd				char(8);					-- 業務日付
	gTsuchiYmdWrk			varchar(18) := NULL;	-- 通知日西暦
	-- 書式フォーマット
	gFmtHakkoKngk			varchar(21) := NULL;	-- 発行金額
	gFmtRbrKngk				varchar(21) := NULL;	-- 利払金額
	gFmtShokanKngk			varchar(21) := NULL;	-- 償還金額
	gFmtRknTesu				varchar(21) := NULL;	-- 利金手数料金額
	-- 計算項目
	gFactor					numeric := 0;			-- ファクター
	gShokanGankin			numeric := 0;			-- 償還元金
	gGnknShrTesuryo			numeric := 0;			-- 元金支払手数料
	gGnknShrTesuryoZei		numeric := 0;			-- 元金支払手数料内消費税
	gRkn					numeric := 0;			-- 利金
	gRknShrTesuryo			numeric := 0;			-- 利金支払手数料
	gRknShrTesuryoZei		numeric := 0;			-- 利金支払手数料内消費税
	gKichuTesuryo			numeric := 0;			-- 期中手数料
	gKichuTesuryoZei		numeric := 0;			-- 期中手数料内消費税
	gShokanGankinGk			numeric := 0;			-- 償還元金合計
	gGnknShrTesuryoGk		numeric := 0;			-- 元金支払手数料合計
	gGnknShrTesuryoZeiGk	numeric := 0;			-- 元金支払手数料内消費税合計
	gRknGk					numeric := 0;			-- 利金合計
	gRknShrTesuryoGk		numeric := 0;			-- 利金支払手数料合計
	gRknShrTesuryoZeiGk		numeric := 0;			-- 利金支払手数料内消費税合計
	gKichuTesuryoGk			numeric := 0;			-- 期中手数料合計
	gKichuTesuryoZeiGk		numeric := 0;			-- 期中手数料内消費税合計
	gShrGk					numeric := 0;			-- 支払額合計
	gShrZeiGk				numeric := 0;			-- 支払額内消費税合計
	gAllShrGk				numeric := 0;			-- 支払額合計
	gAllShrZeiGk			numeric := 0;			-- 支払額内消費税合計
	gAtena				varchar(200) := NULL;		-- 宛名
	gOutflg				integer := 0;				-- 正常処理フラグ
	gRtnFlg				integer := 0;				-- リターンフラグ
	gRbrKjtMoji			varchar(20) := NULL;		-- 利払期日
	gRknTesTsukaCd		KIKIN_IDO.TSUKA_CD%TYPE := ' ';	-- 利金手数料用通貨コード
	gShokanKbn			MGR_SHOKIJ.SHOKAN_KBN%TYPE;		        -- 償還区分
	gRiritsu			SREPORT_WK.ITEM014%TYPE := NULL;	--利率
	gBefMgrCd			MGR_KIHON.MGR_CD%TYPE := ' ';	-- 銘柄コード（退避用）
	gBefHktCd			MGR_KIHON.HKT_CD%TYPE := ' ';	-- 発行体コード（退避用）
	gNo					numeric := 0;					-- 帳票出力用No
	gRedOptionFlg       MOPTION_KANRI.OPTION_FLG%TYPE;      -- レッドプロジェクトオプションフラグ
	gBunsho             varchar(150) := NULL;         -- インボイス文章
	gInvoiceFlg         MOPTION_KANRI.OPTION_FLG%TYPE;      -- インボイスオプションフラグ
	gAryBun				pkIpaBun.BUN_ARRAY;                 -- インボイス文章(請求書)配列
--==============================================================================
--					カーソル定義												
--==============================================================================
	-- 帳票に出力する項目を取得するカーソル
	chohyoCur CURSOR FOR
		SELECT	trim(both MAX(WT01.SORT_KEY)),														-- ソート順
				trim(both MAX(M01.SFSK_POST_NO)) AS SFSK_POST_NO,									-- 送付先郵便番号
				MAX(M01.ADD1) AS ADD1,															-- 送付先住所１
				MAX(M01.ADD2) AS ADD2,															-- 送付先住所２
				MAX(M01.ADD3) AS ADD3,															-- 送付先住所３
				trim(both MAX(M01.HKT_CD)) AS HKT_CD,												-- 発行体コード
				MAX(M01.HKT_NM) AS HKT_NM,														-- 発行体名称
				MAX(M01.SFSK_BUSHO_NM) AS SFSK_BUSHO_NM,										-- 送付先担当部署名称
				MAX(VJ1.BANK_NM) AS BANK_NM,													-- 銀行名称
				MAX(VJ1.BUSHO_NM1) AS BUSHO_NM1,												-- 担当部署名称１
				VMG1.ISIN_CD AS ISIN_CD,														-- ＩＳＩＮコード
				MAX(VMG1.KOKYAKU_MGR_RNM) AS KOKYAKU_MGR_RNM,									-- 対顧用銘柄略称
				MAX(VMG1.MGR_NM) AS MGR_NM,														-- 正式名称				
				trim(both MAX(VMG1.HAKKO_YMD)) AS HAKKO_YMD,											-- 発行年月日
				trim(both MAX(VMG1.NENRBR_CNT)) AS NENRBR_CNT,										-- 年利払回数
				trim(both MAX(VMG1.ST_RBR_KJT)) AS ST_RBR_KJT,										-- 初回利払期日
				trim(both MAX(VMG1.RBR_DD)) AS RBR_DD,												-- 利払日付
				trim(both MAX(VMG1.RBR_KJT_MD1)) AS RBR_KJT_MD1,										-- 利払日（１）
				trim(both MAX(VMG1.RBR_KJT_MD2)) AS RBR_KJT_MD2,										-- 利払日（２）
				trim(both MAX(VMG1.RBR_KJT_MD3)) AS RBR_KJT_MD3,										-- 利払日（３）
				trim(both MAX(VMG1.RBR_KJT_MD4)) AS RBR_KJT_MD4,										-- 利払日（４）
				trim(both MAX(VMG1.RBR_KJT_MD5)) AS RBR_KJT_MD5,										-- 利払日（５）
				trim(both MAX(VMG1.RBR_KJT_MD6)) AS RBR_KJT_MD6,										-- 利払日（６）
				trim(both MAX(VMG1.RBR_KJT_MD7)) AS RBR_KJT_MD7,										-- 利払日（７）
				trim(both MAX(VMG1.RBR_KJT_MD8)) AS RBR_KJT_MD8,										-- 利払日（８）
				trim(both MAX(VMG1.RBR_KJT_MD9)) AS RBR_KJT_MD9,										-- 利払日（９）
				trim(both MAX(VMG1.RBR_KJT_MD10)) AS RBR_KJT_MD10,									-- 利払日（１０）
				trim(both MAX(VMG1.RBR_KJT_MD11)) AS RBR_KJT_MD11,									-- 利払日（１１）
				trim(both MAX(VMG1.RBR_KJT_MD12)) AS RBR_KJT_MD12,									-- 利払日（１２）
				trim(both MAX(VMG1.FULLSHOKAN_KJT)) AS FULLSHOKAN_KJT,								-- 満期償還期日
				MAX(VMG1.RIRITSU) AS RIRITSU,													-- 利率
				MAX(VMG1.RITSUKE_WARIBIKI_KBN_NM) AS RITSUKE_WARIBIKI_KBN_NM,					-- 利付割引区分名称
				trim(both MAX(VMG1.RITSUKE_WARIBIKI_KBN)) AS RITSUKE_WARIBIKI_KBN,					-- 利付割引区分
				trim(both MAX(VMG1.SHOKAN_METHOD_CD)) AS SHOKAN_METHOD_CD,							-- 償還方法コード
				MAX(VMG1.SHOKAN_METHOD_NM) AS SHOKAN_METHOD_NM,									-- 償還方法名称
				trim(both MAX(VMG1.HAKKO_TSUKA_CD)) AS HAKKO_TSUKA_CD,								-- 発行通貨コード
				trim(both MAX(VMG1.RBR_TSUKA_CD)) AS RBR_TSUKA_CD,									-- 利払通貨コード
				trim(both MAX(VMG1.SHOKAN_TSUKA_CD)) AS SHOKAN_TSUKA_CD,								-- 償還通貨コード
				trim(both MAX(M641.TSUKA_NM)) AS HAKKO_TSUKA_NM,										-- 発行通貨名称
				trim(both MAX(M642.TSUKA_NM)) AS RBR_TSUKA_NM,										-- 利払通貨名称
				trim(both MAX(M643.TSUKA_NM)) AS SHOKAN_TSUKA_NM,									-- 償還通貨名称
				MAX(VMG1.SHASAI_TOTAL) AS SHASAI_TOTAL,											-- 社債の総額
				MAX(VMG1.KAKUSHASAI_KNGK) AS KAKUSHASAI_KNGK,									-- 各社債の金額
				MAX(VMG1.TEIJI_SHOKAN_KNGK) AS TEIJI_SHOKAN_KNGK,								-- 定時償還金額
				WT01.SHR_KIGEN AS SHR_KIGEN,													-- お支払期限
				WT01.GNR_YMD AS GNR_YMD,														-- 元利払日
				MAX(WT01.OUTSTANDING_ZNDK) AS OUTSTANDING_ZNDK,									-- 未償還残高（償還後）
				MAX(WT01.FACTOR) AS FACTOR,														-- ファクター
				MAX(WT01.SHOKAN_GNKN) AS SHOKAN_GNKN,											-- 償還元金
				MAX(WT01.GNKN_SHR_TESU_KNGK + WT01.GNKN_SZEI) AS GNKN_SHR_TESU_KNGK,			-- 元金支払手数料
				MAX(WT01.GNKN_SZEI)	AS GNKN_SZEI,												-- 元金支払手数料内消費税
				MAX(WT01.RKN) AS RKN,															-- 利金
				MAX(WT01.RKN_SHR_TESU_KNGK + WT01.RKN_SZEI) 	AS RKN_SHR_TESU_KNGK,			-- 利金支払手数料
				MAX(WT01.RKN_SZEI) AS RKN_SZEI,													-- 利金支払手数料内消費税
				WT01.TESU_SHURUI_NM AS TESU_SHURUI_NM,											-- 手数料科目
				MAX(WT01.SHUEKI_TESU_KNGK) AS SHUEKI_TESU_KNGK,									-- 期中手数料
				MAX(WT01.SHUEKI_SZEI) AS SHUEKI_SZEI,											-- 期中手数料内消費税
				MAX(WT01.ZNDK_KIJUN_YMD) AS ZNDK_KIJUN_YMD,										-- 残高基準日　IP-04975対応用
				VMG1.MGR_CD AS MGR_CD,															-- 銘柄コード
				trim(both MAX(WT01.KKMEMBER_FS_KBN)) AS GNK_SHRTESU_CAP_FLG,							-- 元金支払手数料ＣＡＰ採用フラグ
				MAX(VMG1.TEIJI_SHOKAN_TSUTI_KBN) AS TEIJI_SHOKAN_TSUTI_KBN                       -- 定時償還通知区分
				,MAX(M01.KOZA_TEN_CD) AS KOZA_TEN_CD                                             -- 口座店コード
				,MAX(M01.KOZA_TEN_CIFCD) AS KOZA_TEN_CIFCD                                       -- 口座店ＣＩＦコード
				,MAX(BT01.KYOTEN_KBN) AS KYOTEN_KBN                                              -- 拠点区分
				,MAX(BT03.DISPATCH_FLG) AS DISPATCH_FLG                                          -- 請求書発送区分
				,MAX(VMG1.DPT_ASSUMP_FLG) AS DPT_ASSUMP_FLG                                      -- デットアサンプション契約先フラグ
		FROM (	--元金と未償還残高
					SELECT	'2' AS SORT_KEY,							-- ソート順
							K02.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD,		-- 委託会社コード
							K02.MGR_CD AS MGR_CD,						-- 銘柄コード
							V01.HKT_CD AS HKT_CD,						-- 発行体コード
							K02.TSUKA_CD AS TSUKA_CD,					-- 通貨コード
							MG3.KKN_CHOKYU_YMD AS SHR_KIGEN,			-- お支払期限
							MG3.SHOKAN_YMD AS GNR_YMD,					-- 元利払日（償還日）
							PKIPAZNDK.getKjnZndk(V01.ITAKU_KAISHA_CD, V01.MGR_CD, MG3.SHOKAN_YMD, 3) AS OUTSTANDING_ZNDK,	--未償還残高（償還後）
							(PKIPAZNDK.getKjnZndk(V01.ITAKU_KAISHA_CD, V01.MGR_CD, MG3.SHOKAN_YMD, 5))::numeric  AS FACTOR,						-- ファクター
							K02.KKN_NYUKIN_KNGK AS SHOKAN_GNKN,			-- 償還元金
							K02.KKMEMBER_FS_KBN,						-- 元金支払手数料ＣＡＰ採用フラグ
							0 AS GNKN_SHR_TESU_KNGK,					-- 元金支払手数料
							0 AS GNKN_SZEI,								-- 元金支払手数料内消費税
							0 AS RKN,									-- 利金
							0 AS RKN_SHR_TESU_KNGK,						-- 利金支払手数料
							0 AS RKN_SZEI,								-- 利金支払手数料内消費税
							' ' AS TESU_SHURUI_NM,						-- 手数料科目
							0 AS SHUEKI_TESU_KNGK,						-- 期中手数料
							0 AS SHUEKI_SZEI,							-- 期中手数料内消費税
							K02.ZNDK_KIJUN_YMD AS ZNDK_KIJUN_YMD 		-- 残高基準日　IP-04975対応用
					FROM	KIKIN_IDO K02,
							MGR_KIHON_VIEW V01,
							MGR_SHOKIJ MG3
					WHERE	K02.ITAKU_KAISHA_CD = V01.ITAKU_KAISHA_CD AND
							K02.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD AND
							K02.MGR_CD = V01.MGR_CD AND
							K02.MGR_CD = MG3.MGR_CD AND
							K02.RBR_YMD = MG3.SHOKAN_YMD AND
							V01.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND
							V01.MGR_CD = CASE WHEN coalesce(trim(both l_inMgrCd)::text, '') = '' THEN  V01.MGR_CD  ELSE trim(both l_inMgrCd) END  AND
							V01.ISIN_CD = CASE WHEN coalesce(trim(both l_inIsinCd)::text, '') = '' THEN  V01.ISIN_CD  ELSE trim(both l_inIsinCd) END  AND
							V01.HAKKO_YMD = CASE WHEN coalesce(trim(both l_inHakkoYmd)::text, '') = '' THEN  V01.HAKKO_YMD  ELSE trim(both l_inHakkoYmd) END  AND
							V01.MGR_STAT_KBN = '1' AND 	-- 承認済
							K02.KKN_IDO_KBN = '11' AND
							MG3.SHOKAN_KBN NOT IN ('30', '60')	--買入消却・新株予約権行使対象外
					--元金支払手数料
					
UNION

					SELECT	'2' AS SORT_KEY,							-- ソート順
							K02.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD,		-- 委託会社コード
							K02.MGR_CD AS MGR_CD, 						-- 銘柄コード
							V01.HKT_CD AS HKT_CD,						-- 発行体コード
							K02.TSUKA_CD AS TSUKA_CD, 					-- 通貨コード
							MG3.TESU_CHOKYU_YMD AS SHR_KIGEN,			-- お支払期限
							MG3.SHOKAN_YMD AS GNR_YMD,					-- 元利払日（償還日）
							PKIPAZNDK.getKjnZndk(V01.ITAKU_KAISHA_CD, V01.MGR_CD, MG3.SHOKAN_YMD, 3) AS OUTSTANDING_ZNDK,	--未償還残高（償還後)
							(PKIPAZNDK.getKjnZndk(V01.ITAKU_KAISHA_CD, V01.MGR_CD, MG3.SHOKAN_YMD, 5))::numeric  AS FACTOR,						-- ファクター
							0 AS SHOKAN_GNKN,							-- 償還元金
							K02.KKMEMBER_FS_KBN AS KKMEMBER_FS_KBN,		-- 元金支払手数料ＣＡＰ採用フラグ
							K02.KKN_NYUKIN_KNGK AS GNKN_SHR_TESU_KNGK,	-- 元金支払手数料
							0 AS GNKN_SZEI,								-- 元金支払手数料内消費税
							0 AS RKN,									-- 利金
							0 AS RKN_SHR_TESU_KNGK,						-- 利金支払手数料
							0 AS RKN_SZEI,								-- 利金支払手数料内消費税
							' ' AS TESU_SHURUI_NM,						-- 手数料科目
							0 AS SHUEKI_TESU_KNGK,						-- 期中手数料
							0 AS SHUEKI_SZEI,							-- 期中手数料内消費税
							K02.ZNDK_KIJUN_YMD AS ZNDK_KIJUN_YMD 		-- 残高基準日　IP-04975対応用
					FROM	KIKIN_IDO K02,
							MGR_KIHON_VIEW V01,
							MGR_SHOKIJ MG3
					WHERE	K02.ITAKU_KAISHA_CD = V01.ITAKU_KAISHA_CD AND
							K02.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD AND
							K02.MGR_CD = V01.MGR_CD AND
							K02.MGR_CD = MG3.MGR_CD AND
							K02.RBR_YMD = MG3.SHOKAN_YMD AND
							V01.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND
							V01.MGR_CD = CASE WHEN coalesce(trim(both l_inMgrCd)::text, '') = '' THEN  V01.MGR_CD  ELSE trim(both l_inMgrCd) END  AND
							V01.ISIN_CD = CASE WHEN coalesce(trim(both l_inIsinCd)::text, '') = '' THEN  V01.ISIN_CD  ELSE trim(both l_inIsinCd) END  AND
							V01.HAKKO_YMD = CASE WHEN coalesce(trim(both l_inHakkoYmd)::text, '') = '' THEN  V01.HAKKO_YMD  ELSE trim(both l_inHakkoYmd) END  AND
							V01.MGR_STAT_KBN = '1' AND 	-- 承認済
							K02.KKN_IDO_KBN = '12' AND
							MG3.SHOKAN_KBN NOT IN ('30', '60')	--買入消却・新株予約権行使対象外
					--元金支払手数料内消費税
 
					
UNION

					SELECT	'2' AS SORT_KEY,							-- ソート順
							K02.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD,		-- 委託会社コード
							K02.MGR_CD AS MGR_CD, 						-- 銘柄コード
							V01.HKT_CD AS HKT_CD,						-- 発行体コード
							K02.TSUKA_CD AS TSUKA_CD, 					-- 通貨コード
							MG3.TESU_CHOKYU_YMD AS SHR_KIGEN,			-- お支払期限
							MG3.SHOKAN_YMD AS GNR_YMD,					-- 元利払日（償還日）
							' ' AS OUTSTANDING_ZNDK,					--未償還残高（償還後)
							(PKIPAZNDK.getKjnZndk(V01.ITAKU_KAISHA_CD, V01.MGR_CD, MG3.SHOKAN_YMD, 5))::numeric  AS FACTOR,						-- ファクター
							0 AS SHOKAN_GNKN,							-- 償還元金
							K02.KKMEMBER_FS_KBN AS KKMEMBER_FS_KBN,		-- 元金支払手数料ＣＡＰ採用フラグ
							0 AS GNKN_SHR_TESU_KNGK,					-- 元金支払手数料
							K02.KKN_NYUKIN_KNGK AS GNKN_SZEI,			-- 元金支払手数料内消費税
							0 AS RKN,									-- 利金
							0 AS RKN_SHR_TESU_KNGK,						-- 利金支払手数料
							0 AS RKN_SZEI,								-- 利金支払手数料内消費税
							' ' AS TESU_SHURUI_NM,						-- 手数料科目
							0 AS SHUEKI_TESU_KNGK,						-- 期中手数料
							0 AS SHUEKI_SZEI,							-- 期中手数料内消費税
							K02.ZNDK_KIJUN_YMD AS ZNDK_KIJUN_YMD 		-- 残高基準日　IP-04975対応用
					FROM	KIKIN_IDO K02,
							MGR_KIHON_VIEW V01,
							MGR_SHOKIJ MG3
					WHERE	K02.ITAKU_KAISHA_CD = V01.ITAKU_KAISHA_CD AND
							K02.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD AND
							K02.MGR_CD = V01.MGR_CD AND
							K02.MGR_CD = MG3.MGR_CD AND
							K02.RBR_YMD = MG3.SHOKAN_YMD AND
							V01.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND
							V01.MGR_CD = CASE WHEN coalesce(trim(both l_inMgrCd)::text, '') = '' THEN  V01.MGR_CD  ELSE trim(both l_inMgrCd) END  AND
							V01.ISIN_CD = CASE WHEN coalesce(trim(both l_inIsinCd)::text, '') = '' THEN  V01.ISIN_CD  ELSE trim(both l_inIsinCd) END  AND
							V01.HAKKO_YMD = CASE WHEN coalesce(trim(both l_inHakkoYmd)::text, '') = '' THEN  V01.HAKKO_YMD  ELSE trim(both l_inHakkoYmd) END  AND
							V01.MGR_STAT_KBN = '1' AND 	-- 承認済
							K02.KKN_IDO_KBN = '13' AND
							MG3.SHOKAN_KBN NOT IN ('30', '60')	--買入消却・新株予約権行使対象外
					--利金
 
					
UNION

					SELECT	'1' AS SORT_KEY,						-- ソート順
							K02.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD,	-- 委託会社コード
							K02.MGR_CD AS MGR_CD, 					-- 銘柄コード
							V01.HKT_CD AS HKT_CD,					-- 発行体コード
							K02.TSUKA_CD AS TSUKA_CD, 				-- 通貨コード
							MG2.KKN_CHOKYU_YMD AS SHR_KIGEN,		-- お支払期限
							MG2.RBR_YMD AS GNR_YMD,					-- 元利払日
							PKIPAZNDK.getKjnZndk(V01.ITAKU_KAISHA_CD, V01.MGR_CD, MG2.RBR_YMD, 3) AS OUTSTANDING_ZNDK,				-- 未償還残高（償還後)
							(PKIPAZNDK.getKjnZndk(V01.ITAKU_KAISHA_CD, V01.MGR_CD, MG2.RBR_YMD, 5))::numeric  AS FACTOR,	-- ファクター
							0 AS SHOKAN_GNKN,						-- 償還元金
							K02.KKMEMBER_FS_KBN AS KKMEMBER_FS_KBN,	-- 元金支払手数料ＣＡＰ採用フラグ
							0 AS GNKN_SHR_TESU_KNGK,				-- 元金支払手数料
							0 AS GNKN_SZEI,							-- 元金支払手数料内消費税
							K02.KKN_NYUKIN_KNGK AS RKN,				-- 利金
							0 AS RKN_SHR_TESU_KNGK,					-- 利金支払手数料
							0 AS RKN_SZEI,							-- 利金支払手数料内消費税
							' ' AS TESU_SHURUI_NM,					-- 手数料科目
							0 AS SHUEKI_TESU_KNGK,					-- 期中手数料
							0 AS SHUEKI_SZEI,						-- 期中手数料内消費税
							K02.ZNDK_KIJUN_YMD AS ZNDK_KIJUN_YMD 	-- 残高基準日　IP-04975対応用
					FROM	KIKIN_IDO K02,
							MGR_KIHON_VIEW V01,
							MGR_RBRKIJ	MG2
					WHERE	K02.ITAKU_KAISHA_CD = V01.ITAKU_KAISHA_CD AND
							K02.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD AND
							K02.MGR_CD = V01.MGR_CD AND
							K02.MGR_CD = MG2.MGR_CD AND
							K02.RBR_YMD = MG2.RBR_YMD AND
							V01.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND
							V01.MGR_CD = CASE WHEN coalesce(trim(both l_inMgrCd)::text, '') = '' THEN  V01.MGR_CD  ELSE trim(both l_inMgrCd) END  AND
							V01.ISIN_CD = CASE WHEN coalesce(trim(both l_inIsinCd)::text, '') = '' THEN  V01.ISIN_CD  ELSE trim(both l_inIsinCd) END  AND
							V01.HAKKO_YMD = CASE WHEN coalesce(trim(both l_inHakkoYmd)::text, '') = '' THEN  V01.HAKKO_YMD  ELSE trim(both l_inHakkoYmd) END  AND
							V01.MGR_STAT_KBN = '1' AND 	-- 承認済
							K02.KKN_IDO_KBN = '21'
					--利金支払手数料
 
					
UNION

					SELECT	'1' AS SORT_KEY,						-- ソート順
							K02.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD,	-- 委託会社コード
							K02.MGR_CD AS MGR_CD, 					-- 銘柄コード
							V01.HKT_CD AS HKT_CD,					-- 発行体コード
							K02.TSUKA_CD AS TSUKA_CD, 				-- 通貨コード
							MG2.TESU_CHOKYU_YMD AS SHR_KIGEN,		-- お支払期限
							MG2.RBR_YMD AS GNR_YMD,					-- 元利払日
							PKIPAZNDK.getKjnZndk(V01.ITAKU_KAISHA_CD, V01.MGR_CD, MG2.RBR_YMD, 3) AS OUTSTANDING_ZNDK,				-- 未償還残高（償還後)
							(PKIPAZNDK.getKjnZndk(V01.ITAKU_KAISHA_CD, V01.MGR_CD, MG2.RBR_YMD, 5))::numeric  AS FACTOR,	-- ファクター
							0 AS SHOKAN_GNKN,						-- 償還元金
							K02.KKMEMBER_FS_KBN AS KKMEMBER_FS_KBN,	-- 元金支払手数料ＣＡＰ採用フラグ
							0 AS GNKN_SHR_TESU_KNGK,				-- 元金支払手数料
							0 AS GNKN_SZEI,							-- 元金支払手数料内消費税
							0 AS RKN,								-- 利金
							K02.KKN_NYUKIN_KNGK AS RKN_SHR_TESU_KNGK,-- 利金支払手数料
							0 AS RKN_SZEI,							-- 利金支払手数料内消費税
							' ' AS TESU_SHURUI_NM,					-- 手数料科目
							0 AS SHUEKI_TESU_KNGK,					-- 期中手数料
							0 AS SHUEKI_SZEI,						-- 期中手数料内消費税
							K02.ZNDK_KIJUN_YMD AS ZNDK_KIJUN_YMD 	-- 残高基準日　IP-04975対応用
					FROM	KIKIN_IDO K02,
							MGR_KIHON_VIEW V01,
							MGR_RBRKIJ	MG2
					WHERE	K02.ITAKU_KAISHA_CD = V01.ITAKU_KAISHA_CD AND
							K02.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD AND
							K02.MGR_CD = V01.MGR_CD AND
							K02.MGR_CD = MG2.MGR_CD AND
							K02.RBR_YMD = MG2.RBR_YMD AND
							V01.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND
							V01.MGR_CD = CASE WHEN coalesce(trim(both l_inMgrCd)::text, '') = '' THEN  V01.MGR_CD  ELSE trim(both l_inMgrCd) END  AND
							V01.ISIN_CD = CASE WHEN coalesce(trim(both l_inIsinCd)::text, '') = '' THEN  V01.ISIN_CD  ELSE trim(both l_inIsinCd) END  AND
							V01.HAKKO_YMD = CASE WHEN coalesce(trim(both l_inHakkoYmd)::text, '') = '' THEN  V01.HAKKO_YMD  ELSE trim(both l_inHakkoYmd) END  AND
							V01.MGR_STAT_KBN = '1' AND 	-- 承認済
							K02.KKN_IDO_KBN = '22'
					--利金支払手数料内消費税
 
					
UNION

					SELECT	'1' AS SORT_KEY,						-- ソート順
							K02.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD,	-- 委託会社コード
							K02.MGR_CD AS MGR_CD, 					-- 銘柄コード
							V01.HKT_CD AS HKT_CD,					-- 発行体コード
							K02.TSUKA_CD AS TSUKA_CD, 				-- 通貨コード
							MG2.TESU_CHOKYU_YMD AS SHR_KIGEN,		-- お支払期限
							MG2.RBR_YMD AS GNR_YMD,					-- 元利払日
							' ' AS OUTSTANDING_ZNDK,				-- 未償還残高（償還後)
							(PKIPAZNDK.getKjnZndk(V01.ITAKU_KAISHA_CD, V01.MGR_CD, MG2.RBR_YMD, 5))::numeric  AS FACTOR,	-- ファクター
							0 AS SHOKAN_GNKN,						-- 償還元金
							K02.KKMEMBER_FS_KBN AS KKMEMBER_FS_KBN,	-- 元金支払手数料ＣＡＰ採用フラグ
							0 AS GNKN_SHR_TESU_KNGK,				-- 元金支払手数料
							0 AS GNKN_SZEI,							-- 元金支払手数料内消費税
							0 AS RKN,								-- 利金
							0 AS RKN_SHR_TESU_KNGK,					-- 利金支払手数料
							K02.KKN_NYUKIN_KNGK AS RKN_SZEI,		-- 利金支払手数料内消費税
							' ' AS TESU_SHURUI_NM,					-- 手数料科目
							0 AS SHUEKI_TESU_KNGK,					-- 期中手数料
							0 AS SHUEKI_SZEI,						-- 期中手数料内消費税
							K02.ZNDK_KIJUN_YMD AS ZNDK_KIJUN_YMD 	-- 残高基準日　IP-04975対応用
					FROM	KIKIN_IDO K02,
							MGR_KIHON_VIEW V01,
							MGR_RBRKIJ	MG2
					WHERE	K02.ITAKU_KAISHA_CD = V01.ITAKU_KAISHA_CD AND
							K02.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD AND
							K02.MGR_CD = V01.MGR_CD AND
							K02.MGR_CD = MG2.MGR_CD AND
							K02.RBR_YMD = MG2.RBR_YMD AND
							V01.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND
							V01.MGR_CD = CASE WHEN coalesce(trim(both l_inMgrCd)::text, '') = '' THEN  V01.MGR_CD  ELSE trim(both l_inMgrCd) END  AND
							V01.ISIN_CD = CASE WHEN coalesce(trim(both l_inIsinCd)::text, '') = '' THEN  V01.ISIN_CD  ELSE trim(both l_inIsinCd) END  AND
							V01.HAKKO_YMD = CASE WHEN coalesce(trim(both l_inHakkoYmd)::text, '') = '' THEN  V01.HAKKO_YMD  ELSE trim(both l_inHakkoYmd) END  AND
							V01.MGR_STAT_KBN = '1' AND 	-- 承認済
							K02.KKN_IDO_KBN = '23'
					--期中手数料
 
					
UNION

					SELECT	'3' AS SORT_KEY,						-- ソート順
							T01.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD,	-- 委託会社コード
							T01.MGR_CD AS MGR_CD,		 			-- 銘柄コード
							V01.HKT_CD AS HKT_CD,					-- 発行体コード
							T01.TSUKA_CD AS TSUKA_CD, 				-- 通貨コード
							T01.CHOKYU_YMD AS SHR_KIGEN,			-- お支払期限
							' ' AS GNR_YMD,							-- 元利払日
							PKIPAZNDK.getKjnZndk(V01.ITAKU_KAISHA_CD, V01.MGR_CD, T01.CHOKYU_YMD,3) AS OUTSTANDING_ZNDK,				-- 未償還残高（償還後)
							CASE WHEN V01.SHOKAN_METHOD_CD='2' THEN  CASE WHEN V01.KK_KANYO_FLG='2' THEN  0  ELSE (PKIPAZNDK.getKjnZndk(V01.ITAKU_KAISHA_CD, V01.MGR_CD, T01.CHOKYU_YMD,5))::numeric  END   ELSE 0 END  AS FACTOR,							-- ファクター
							0 AS SHOKAN_GNKN,						-- 償還元金
							' ' AS KKMEMBER_FS_KBN,					-- 元金支払手数料ＣＡＰ採用フラグ
							0 AS GNKN_SHR_TESU_KNGK,				-- 元金支払手数料
							0 AS GNKN_SZEI,							-- 元金支払手数料内消費税
							0 AS RKN,								-- 利金
							0 AS RKN_SHR_TESU_KNGK,					-- 利金支払手数料
							0 AS RKN_SZEI,							-- 利金支払手数料内消費税
							S01.KONAI_TESU_SHURUI_NM AS TESU_SHURUI_NM,	-- 手数料科目
							-- 全体手数料額税込に補正額を反映させるか判断する関数を使用
							PKIPACALCTESURYO.getHoseiKasanKngk(
								T01.ALL_TESU_KNGK
								,T01.HOSEI_ALL_TESU_KNGK
								,T01.DATA_SAKUSEI_KBN
								,T01.SHORI_KBN) AS SHUEKI_TESU_KNGK,-- 全体手数料額
							-- 全体消費税額に補正額を反映させるか判断する関数を使用
							PKIPACALCTESURYO.getHoseiKasanKngk(
								T01.ALL_TESU_SZEI 					-- 全体消費税額
								,T01.HOSEI_ALL_TESU_SZEI 			-- 補正消費税額
								,T01.DATA_SAKUSEI_KBN
								,T01.SHORI_KBN) AS SHUEKI_SZEI,		-- 全体手数料内消費税
							' ' AS ZNDK_KIJUN_YMD 					-- 残高基準日　IP-04975対応用
					FROM	TESURYO	T01,
							MGR_KIHON_VIEW V01,
							TESURYO_KANRI S01
					WHERE	T01.ITAKU_KAISHA_CD = V01.ITAKU_KAISHA_CD and
							T01.ITAKU_KAISHA_CD = S01.ITAKU_KAISHA_CD AND
							T01.MGR_CD = V01.MGR_CD AND
							T01.TESU_SHURUI_CD = S01.TESU_SHURUI_CD AND
							T01.TESU_SASHIHIKI_KBN = '2' AND
							V01.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND
							V01.MGR_CD = CASE WHEN coalesce(trim(both l_inMgrCd)::text, '') = '' THEN  V01.MGR_CD  ELSE trim(both l_inMgrCd) END  AND
							V01.ISIN_CD = CASE WHEN coalesce(trim(both l_inIsinCd)::text, '') = '' THEN  V01.ISIN_CD  ELSE trim(both l_inIsinCd) END  AND
							V01.HAKKO_YMD = CASE WHEN coalesce(trim(both l_inHakkoYmd)::text, '') = '' THEN  V01.HAKKO_YMD  ELSE trim(both l_inHakkoYmd) END  AND
							T01.TESU_SHURUI_CD IN ('11','12','21','22','41','52','91') AND
							V01.MGR_STAT_KBN = '1'	-- 承認済
 
				) wt01, vjiko_itaku vj1, mgr_tesuryo_prm mg8, mtsuka m643, mtsuka m641, mhakkotai m01, mgr_kihon2 bt03, mhakkotai2 bt01, vmgr_list vmg1
LEFT OUTER JOIN mtsuka m642 ON (VMG1.RBR_TSUKA_CD = M642.TSUKA_CD)
WHERE VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND VMG1.HKT_CD = M01.HKT_CD AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD AND VMG1.MGR_CD = WT01.MGR_CD AND VMG1.ITAKU_KAISHA_CD = WT01.ITAKU_KAISHA_CD AND VMG1.MGR_CD = MG8.MGR_CD AND VMG1.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD AND VJ1.KAIIN_ID = l_inItakuKaishaCd AND VMG1.HAKKO_TSUKA_CD = M641.TSUKA_CD  AND VMG1.SHOKAN_TSUKA_CD = M643.TSUKA_CD AND VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND VMG1.MGR_CD = CASE WHEN coalesce(trim(both l_inMgrCd)::text, '') = '' THEN  VMG1.MGR_CD  ELSE trim(both l_inMgrCd) END AND VMG1.ISIN_CD = CASE WHEN coalesce(trim(both l_inIsinCd)::text, '') = '' THEN  VMG1.ISIN_CD  ELSE trim(both l_inIsinCd) END AND VMG1.HAKKO_YMD = CASE WHEN coalesce(trim(both l_inHakkoYmd)::text, '') = '' THEN  VMG1.HAKKO_YMD  ELSE trim(both l_inHakkoYmd) END AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '') AND VMG1.JTK_KBN NOT IN ('2','5')  --副受託・自社発行銘柄は出力しない
  AND VMG1.KK_KANYO_FLG <> '2' --実質記番号管理方式銘柄以外
  AND M01.ITAKU_KAISHA_CD = BT01.ITAKU_KAISHA_CD AND M01.HKT_CD = BT01.HKT_CD AND VMG1.ITAKU_KAISHA_CD = BT03.ITAKU_KAISHA_CD AND VMG1.MGR_CD = BT03.MGR_CD GROUP BY WT01.SHR_KIGEN,
				 WT01.GNR_YMD,
				 VMG1.HKT_CD,
				 VMG1.ISIN_CD,
				 WT01.TESU_SHURUI_NM,
				 VMG1.MGR_CD
		ORDER BY VMG1.HKT_CD,
				 VMG1.ISIN_CD,
				 WT01.SHR_KIGEN,
				 TESU_SHURUI_NM,
				 trim(both MAX(WT01.SORT_KEY));
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp03701 START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''							-- 委託会社コードがNULL
	OR coalesce(trim(both l_inUserId)::text, '') = ''									-- ユーザIDがNULL
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''								-- 帳票区分がNULL
	OR trim(both l_inChohyoKbn) NOT IN 								-- 帳票区分が0, 1以外
		(PKIPACALCTESURYO.C_REAL(), PKIPACALCTESURYO.C_BATCH())
	OR (trim(both l_inChohyoKbn) = PKIPACALCTESURYO.C_REAL() 			-- リアルで銘柄コード・ISINコード共にNULL
		AND coalesce(trim(both l_inMgrCd)::text, '') = '' AND coalesce(trim(both l_inIsinCd)::text, '') = '')
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', REPORT_ID, 'SQLERRM:'||'');
		RETURN;
	END IF;
	-- 業務日付を取得する
	gGyomuYmd := pkDate.getGyomuYmd();
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = gGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, gGyomuYmd, REPORT_ID);
	-- インボイスオプションフラグを取得する
	gInvoiceFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd, 'INVOICE_C', '0');
	-- インボイスオプションフラグが"1"の場合
	IF gInvoiceFlg = '1' THEN
	    -- インボイス文章取得
	    gAryBun := pkIpaBun.getBun(REPORT_ID, 'L0');
	    FOR i IN 0..coalesce(cardinality(gAryBun), 0) - 1 LOOP
	         IF i = 0 THEN
	             gBunsho := gAryBun[i];
	         END IF;
	    END LOOP;
	END IF;
	--合計行の初期化
	gShokanGankinGk			:= 0;
	gGnknShrTesuryoGk		:= 0;
	gGnknShrTesuryoZeiGk	:= 0;
	gRknGk					:= 0;
	gRknShrTesuryoGk		:= 0;
	gRknShrTesuryoZeiGk		:= 0;
	-- 通知日の西暦変換
	gTsuchiYmdWrk := TSUCHI_YMD_DEF;
	IF (trim(both l_inTsuchiYmd) IS NOT NULL AND (trim(both l_inTsuchiYmd))::text <> '') THEN
		gTsuchiYmdWrk := pkDate.seirekiChangeSuppressNenGappi(l_inTsuchiYmd);
	END IF;
	-- コードマスタより、償還区分のソート順位がもっとも低いものを取得する。
	-- SQLの期中手数料でpkIpaZndkで償還後残高を取得しているため、同一期日のすべての償還額を反映させたもので取得する。
	BEGIN
		SELECT
			CODE_VALUE
		INTO STRICT
			gShokanKbn
		FROM (
				SELECT
					CODE_VALUE
				FROM
					SCODE
				WHERE
					CODE_SHUBETSU = '714'
				ORDER BY CODE_SORT DESC
			) alias0 LIMIT 1;
	EXCEPTION
		WHEN no_data_found THEN
			-- 取得できなかった場合は現在定義されているものを固定値でセット
			-- 満期一括
			gShokanKbn := '10';
	END;
	-- レッドプロジェクトオプションフラグ取得
	gRedOptionFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd, 'REDPROJECT', '0');
	FOR chohyoRec IN chohyoCur
	LOOP
	-- 残高基準日がセットされていなければ、無条件でINSERTさせる。⇒　期中手数料のカーソル分 
	-- または、残高基準日がセットされていてもpkipacalctesuryo.checkHeizonMgr関数の戻り値が０ならINSERTさせる 
	-- 残高基準日がセットされていて、pkipacalctesuryo.checkHeizonMgr関数の戻り値が１だった場合はINSERTさせないように制御する 
	IF (coalesce(trim(both chohyoRec.ZNDK_KIJUN_YMD)::text, '') = '')
	OR ( ((trim(both chohyoRec.ZNDK_KIJUN_YMD) IS NOT NULL AND (trim(both chohyoRec.ZNDK_KIJUN_YMD))::text <> '')) AND (pkipacalctesuryo.checkHeizonMgr(l_inItakuKaishaCd,chohyoRec.MGR_CD,chohyoRec.ZNDK_KIJUN_YMD,'1') = 0) ) THEN
		-- 銘柄コードがブレークした場合、合計行を設定
		IF gSeqNo > 0 AND trim(both chohyoRec.MGR_CD) <> trim(both gBefMgrCd) THEN
			-- 帳票ワークテーブルに合計行を設定
			CALL spIp03701_01_updSreportWkKngkSum();
			-- 各変数を初期化
			gNo := 0;					-- 帳票出力用No
			gShokanGankinGk := 0;		-- 償還元金合計
			gGnknShrTesuryoGk := 0;		-- 元金支払手数料合計
			gGnknShrTesuryoZeiGk := 0;	-- 元金支払手数料消費税合計
			gRknGk := 0;				-- 利金合計
			gRknShrTesuryoGk := 0;		-- 利金支払手数料合計
			gRknShrTesuryoZeiGk := 0;	-- 利金支払手数料消費税合計
			gKichuTesuryoGk := 0;		-- 収益管理手数料合計
			gKichuTesuryoZeiGk := 0;	-- 収益管理手数料消費税合計
			gAllShrGk := 0;				-- 支払額合計
			gAllShrZeiGk := 0;			-- 支払額消費税合計
		END IF;
		--シーケンスNoをセットする
		gSeqNo := gSeqNo + 1;
		gNo := gNo + 1;
		-- ループの先頭、または発行体が変わったら行う。
		IF gSeqNo = 1 OR trim(both chohyoRec.HKT_CD) <> trim(both gBefHktCd) THEN
	 		-- 宛名編集
			CALL pkIpaName.getMadoFutoAtena(chohyoRec.HKT_NM, chohyoRec.SFSK_BUSHO_NM, gOutflg, gAtena);
		END IF;
		IF coalesce(trim(both chohyoRec.NENRBR_CNT)::text, '') = '' THEN
			gRbrKjtMoji := ' ';
		ELSE
			-- 利払期日名称の編集
			SELECT l_outflg, l_outresult INTO gRtnFlg, gRbrKjtMoji 
			FROM pkRibaraiKijitsu.getRibaraiKijitsu(chohyoRec.NENRBR_CNT::integer, substring(chohyoRec.ST_RBR_KJT, 1, 1)::char, substring(chohyoRec.RBR_DD, 1, 1)::char, gRtnFlg);
		END IF;
		-- ループの先頭、または銘柄コードが変わったら行う。
		IF gNo = 1 THEN
			-- 手数料種類に応じて利払手数料通貨コードを取得(元金ベース=発行通貨コード、利金ベース=利払通貨コード)
			BEGIN
				SELECT
					coalesce(CASE WHEN MG7.TESU_SHURUI_CD='61' THEN MG1.HAKKO_TSUKA_CD WHEN MG7.TESU_SHURUI_CD='82' THEN MG1.RBR_TSUKA_CD END ,'')
				INTO STRICT
					gRknTesTsukaCd
				FROM
					MGR_KIHON MG1,
					(SELECT
						MG7.ITAKU_KAISHA_CD,
						MG7.MGR_CD,
						MG7.TESU_SHURUI_CD
					FROM	MGR_TESURYO_CTL MG7
						WHERE	MG7.TESU_SHURUI_CD IN ('61', '82')
							AND	MG7.CHOOSE_FLG = '1' ) MG7
				WHERE	MG1.ITAKU_KAISHA_CD		= MG7.ITAKU_KAISHA_CD
					AND	MG1.MGR_CD				= MG7.MGR_CD
					AND	MG1.ITAKU_KAISHA_CD		= l_inItakuKaishaCd
					AND	MG1.MGR_CD				= chohyoRec.MGR_CD;
			EXCEPTION
				WHEN no_data_found THEN
					gRknTesTsukaCd := chohyoRec.RBR_TSUKA_CD;
			END;
		END IF;
		-- 書式フォーマットの設定
		-- 発行
		IF chohyoRec.HAKKO_TSUKA_CD = 'JPY' THEN
			gFmtHakkoKngk := FMT_KNGK_J;
		ELSE
			gFmtHakkoKngk := FMT_KNGK_F;
		END IF;
		-- 利払
		IF chohyoRec.RBR_TSUKA_CD = 'JPY' THEN
			gFmtRbrKngk := FMT_KNGK_J;
		ELSE
			gFmtRbrKngk := FMT_KNGK_F;
		END IF;
		-- 償還
		IF chohyoRec.SHOKAN_TSUKA_CD = 'JPY' THEN
			gFmtShokanKngk := FMT_KNGK_J;
		ELSE
			gFmtShokanKngk := FMT_KNGK_F;
		END IF;
		-- 利金手数料
		IF gRknTesTsukaCd = 'JPY' THEN
			gFmtRknTesu := FMT_KNGK_J;
		ELSE
			gFmtRknTesu := FMT_KNGK_F;
		END IF;
		-- ファクターは、償還区分=定時償還以外 の場合は表示しない
		IF chohyoRec.SHOKAN_METHOD_CD != '2' THEN
			gFactor := NULL;
		ELSE
			gFactor := chohyoRec.FACTOR;
		END IF;
		-- 償還元金
		IF chohyoRec.SHOKAN_GNKN = 0 THEN
			gShokanGankin := NULL;
		ELSE
			gShokanGankin := chohyoRec.SHOKAN_GNKN;
		END IF;
		-- 元金支払手数料
		IF (chohyoRec.GNKN_SHR_TESU_KNGK + chohyoRec.GNKN_SZEI) = 0 THEN
			gGnknShrTesuryo := NULL;
		ELSE
			gGnknShrTesuryo := (chohyoRec.GNKN_SHR_TESU_KNGK + chohyoRec.GNKN_SZEI);
		END IF;
		-- 元金支払手数料内消費税
		IF chohyoRec.GNKN_SZEI = 0 THEN
			gGnknShrTesuryoZei := NULL;
		ELSE
			gGnknShrTesuryoZei := chohyoRec.GNKN_SZEI;
		END IF;
		-- 利金
		IF chohyoRec.RKN = 0 THEN
			gRkn := NULL;
		ELSE
			gRkn := chohyoRec.RKN;
		END IF;
		-- 利金支払手数料
		IF (chohyoRec.RKN_SHR_TESU_KNGK	+ chohyoRec.RKN_SZEI) = 0 THEN
			gRknShrTesuryo := NULL;
		ELSE
			gRknShrTesuryo := (chohyoRec.RKN_SHR_TESU_KNGK	+ chohyoRec.RKN_SZEI);
		END IF;
		-- 利金支払手数料内消費税
		IF chohyoRec.RKN_SZEI = 0 THEN
			gRknShrTesuryoZei := NULL;
		ELSE
			gRknShrTesuryoZei := chohyoRec.RKN_SZEI;
		END IF;
		-- 期中手数料
		IF (chohyoRec.SHUEKI_TESU_KNGK + chohyoRec.SHUEKI_SZEI) = 0 THEN
			gKichuTesuryo := NULL;
		ELSE
			gKichuTesuryo := (chohyoRec.SHUEKI_TESU_KNGK + chohyoRec.SHUEKI_SZEI);
		END IF;
		-- 期中手数料内消費税
		IF chohyoRec.SHUEKI_SZEI = 0 THEN
			gKichuTesuryoZei := NULL;
		ELSE
			gKichuTesuryoZei := chohyoRec.SHUEKI_SZEI;
		END IF;
		-- 発行通貨コード = 利払通貨コード = 償還通貨コードの場合にのみ合計する
		IF (chohyoRec.HAKKO_TSUKA_CD = chohyoRec.RBR_TSUKA_CD OR coalesce(chohyoRec.RBR_TSUKA_CD::text, '') = '')
		AND (chohyoRec.HAKKO_TSUKA_CD = gRknTesTsukaCd OR coalesce(gRknTesTsukaCd::text, '') = '')
		AND chohyoRec.HAKKO_TSUKA_CD = chohyoRec.SHOKAN_TSUKA_CD THEN
			-- お支払金額を計算する
			gShrGk := chohyoRec.SHOKAN_GNKN + chohyoRec.GNKN_SHR_TESU_KNGK
											+ chohyoRec.GNKN_SZEI
											+ chohyoRec.RKN
											+ chohyoRec.RKN_SHR_TESU_KNGK
											+ chohyoRec.RKN_SZEI
											+ chohyoRec.SHUEKI_TESU_KNGK
											+ chohyoRec.SHUEKI_SZEI;
			-- お支払金額（内消費税)を計算する
			gShrZeiGk := chohyoRec.GNKN_SZEI + chohyoRec.RKN_SZEI + chohyoRec.SHUEKI_SZEI;
			-- 計算結果が0の場合は表示したくないのでNULLをセットする
			IF gShrGk = 0 THEN
				gShrGk := NULL;
			END IF;
			IF gShrZeiGk = 0 THEN
				gShrZeiGk := NULL;
			END IF;
		ELSE
			-- 通貨が異なる場合、お支払金額は出力しない。
			gShrGk := NULL;
			gShrZeiGk := NULL;
		END IF;
		IF chohyoRec.RIRITSU = 0 THEN
			gRiritsu := ' ';
		ELSE
			gRiritsu := chohyoRec.RIRITSU;
		END IF;
		IF chohyoRec.GNK_SHRTESU_CAP_FLG = 'X' THEN			-- 採用フラグに'X'がある時は、
				chohyoRec.GNK_SHRTESU_CAP_FLG := '#';			-- 帳票に'#'を出力させる。
		ELSE
			chohyoRec.GNK_SHRTESU_CAP_FLG := ' ';
		END IF;
		-- 定時償還永久債の償還方法の表示を「永久債」にする
		IF chohyoRec.FULLSHOKAN_KJT = '99999999' AND chohyoRec.SHOKAN_METHOD_CD = '2'
		AND chohyoRec.TEIJI_SHOKAN_TSUTI_KBN = 'V' THEN
		    chohyoRec.SHOKAN_METHOD_NM := '永久債';
		END IF;
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gTsuchiYmdWrk;	-- 通知日
		v_item.l_inItem002 := chohyoRec.SFSK_POST_NO;	-- 送付先郵便番号
		v_item.l_inItem003 := chohyoRec.ADD1;	-- 送付先住所１
		v_item.l_inItem004 := chohyoRec.ADD2;	-- 送付先住所２
		v_item.l_inItem005 := chohyoRec.ADD3;	-- 送付先住所３
		v_item.l_inItem006 := gAtena;	-- 発行体名称
		v_item.l_inItem007 := chohyoRec.BANK_NM;	-- 金融機関名称
		v_item.l_inItem008 := chohyoRec.BUSHO_NM1;	-- 担当部署名称
		v_item.l_inItem009 := chohyoRec.ISIN_CD;	-- ＩＳＩＮコード
		v_item.l_inItem010 := chohyoRec.KOKYAKU_MGR_RNM;	-- 対顧用銘柄略称
		v_item.l_inItem011 := chohyoRec.HAKKO_YMD;	-- 発行年月日
		v_item.l_inItem012 := gRbrKjtMoji;	-- 利払日（１）〜（１２）
		v_item.l_inItem013 := chohyoRec.FULLSHOKAN_KJT;	-- 満期償還期日
		v_item.l_inItem014 := gRiritsu;	-- 利率
		v_item.l_inItem015 := chohyoRec.RITSUKE_WARIBIKI_KBN_NM;	-- 利付割引区分名称
		v_item.l_inItem016 := chohyoRec.SHOKAN_METHOD_NM;	-- 償還方法名称
		v_item.l_inItem017 := chohyoRec.HAKKO_TSUKA_NM;	-- 発行通貨名称
		v_item.l_inItem018 := chohyoRec.RBR_TSUKA_NM;	-- 利払通貨名称
		v_item.l_inItem019 := chohyoRec.SHOKAN_TSUKA_NM;	-- 償還通貨名称
		v_item.l_inItem020 := chohyoRec.SHASAI_TOTAL;	-- 社債の総額
		v_item.l_inItem021 := chohyoRec.KAKUSHASAI_KNGK;	-- 各社債の金額
		v_item.l_inItem022 := chohyoRec.TEIJI_SHOKAN_KNGK;	-- 定時償還金額
		v_item.l_inItem023 := gNo;	-- Ｎｏ
		v_item.l_inItem024 := chohyoRec.SHR_KIGEN;	-- お支払期限
		v_item.l_inItem025 := chohyoRec.GNR_YMD;	-- 元利払日
		v_item.l_inItem026 := chohyoRec.OUTSTANDING_ZNDK;	-- 未償還残高（償還後）
		v_item.l_inItem027 := gFactor;	-- ファクター
		v_item.l_inItem028 := gShokanGankin;	-- 償還元金
		v_item.l_inItem029 := gGnknShrTesuryo;	-- 元金支払手数料
		v_item.l_inItem030 := gGnknShrTesuryoZei;	-- 元金支払手数料内消費税
		v_item.l_inItem031 := gRkn;	-- 利金
		v_item.l_inItem032 := gRknShrTesuryo;	-- 利金支払手数料
		v_item.l_inItem033 := gRknShrTesuryoZei;	-- 利金支払手数料内消費税
		v_item.l_inItem034 := gKichuTesuryo;	-- 期中手数料
		v_item.l_inItem035 := gKichuTesuryoZei;	-- 期中手数料内消費税
		v_item.l_inItem036 := gFmtHakkoKngk;	-- 発行金額書式フォーマット
		v_item.l_inItem037 := gFmtRbrKngk;	-- 利払金額書式フォーマット
		v_item.l_inItem038 := gFmtShokanKngk;	-- 償還金額書式フォーマット
		v_item.l_inItem040 := chohyoRec.HKT_CD;	-- 発行体コード
		v_item.l_inItem041 := chohyoRec.TESU_SHURUI_NM;	-- 手数料科目
		v_item.l_inItem042 := gShrGk;	-- お支払金額合計
		v_item.l_inItem043 := gShrZeiGk;	-- お支払金額合計(内消費税)
		v_item.l_inItem054 := chohyoRec.RITSUKE_WARIBIKI_KBN;	-- 利付割引区分
		v_item.l_inItem055 := chohyoRec.SHOKAN_METHOD_CD;	-- 償還方法コード
		v_item.l_inItem056 := gFmtRknTesu;	-- 利金手数料金額書式フォーマット
		v_item.l_inItem057 := chohyoRec.MGR_NM;	-- 正式名称
		v_item.l_inItem058 := chohyoRec.GNK_SHRTESU_CAP_FLG;	-- 元金支払手数料ＣＡＰ採用フラグ
		v_item.l_inItem059 := chohyoRec.KOZA_TEN_CD;	-- 口座店コード
		v_item.l_inItem060 := trim(both chohyoRec.KOZA_TEN_CIFCD);	-- 口座店ＣＩＦコード
		v_item.l_inItem061 := gRedOptionFlg;	-- レッドプロジェクトオプションフラグ
		v_item.l_inItem062 := gInvoiceFlg;	-- インボイスオプションフラグ
		v_item.l_inItem063 := gBunsho;	-- インボイス文章
		v_item.l_inItem101 := chohyoRec.KYOTEN_KBN;	-- 拠点区分
		v_item.l_inItem102 := chohyoRec.DISPATCH_FLG;	-- 請求書発送区分
		v_item.l_inItem103 := chohyoRec.DPT_ASSUMP_FLG;	-- デットアサンプション契約先フラグ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> gGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		-- 合計行を計算する
		gShokanGankinGk			:= gShokanGankinGk + chohyoRec.SHOKAN_GNKN;
		gGnknShrTesuryoGk		:= gGnknShrTesuryoGk + chohyoRec.GNKN_SHR_TESU_KNGK + chohyoRec.GNKN_SZEI;
		gGnknShrTesuryoZeiGk	:= gGnknShrTesuryoZeiGk + chohyoRec.GNKN_SZEI;
		gRknGk					:= gRknGk + chohyoRec.RKN;
		gRknShrTesuryoGk		:= gRknShrTesuryoGk + chohyoRec.RKN_SHR_TESU_KNGK + chohyoRec.RKN_SZEI;
		gRknShrTesuryoZeiGk		:= gRknShrTesuryoZeiGk + chohyoRec.RKN_SZEI;
		gKichuTesuryoGk			:= gKichuTesuryoGk + chohyoRec.SHUEKI_TESU_KNGK + chohyoRec.SHUEKI_SZEI;
		gKichuTesuryoZeiGk		:= gKichuTesuryoZeiGk + chohyoRec.SHUEKI_SZEI;
		-- 発行通貨コード = 利払通貨コード = 償還通貨コードの場合,もしくは利払通貨がNULL(割引債)の場合にのみ合計する
		IF (chohyoRec.HAKKO_TSUKA_CD = chohyoRec.RBR_TSUKA_CD OR coalesce(chohyoRec.RBR_TSUKA_CD::text, '') = '')
		AND chohyoRec.HAKKO_TSUKA_CD = chohyoRec.SHOKAN_TSUKA_CD THEN
			--支払合計と支払合計内税がNULLの場合は0に戻す。NULLだと合計が全てNULLになるため。
			IF coalesce(gShrGk::text, '') = '' THEN
				gShrGk := 0;
			END IF;
			IF coalesce(gShrZeiGk::text, '') = '' THEN
				gShrZeiGk := 0;
			END IF;
			-- お支払金額合計
			gAllShrGk			:= gAllShrGk + gShrGk;
			-- 内消費税
			gAllShrZeiGk		:= gAllShrZeiGk + gShrZeiGk;
		END IF;
		-- 銘柄コード、発行体コードを退避する。
		gBefMgrCd := chohyoRec.MGR_CD;
		gBefHktCd := chohyoRec.HKT_CD;
	END IF;
	END LOOP;
	IF gSeqNo = 0 THEN
		-- 対象データなし
		gRtnCd := RTN_NODATA;
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gTsuchiYmdWrk;	-- 通知日
		v_item.l_inItem036 := FMT_KNGK_J;
		v_item.l_inItem037 := FMT_KNGK_J;
		v_item.l_inItem038 := FMT_KNGK_J;
		v_item.l_inItem039 := '対象データなし';
		v_item.l_inItem062 := gInvoiceFlg;	-- インボイスオプションフラグ
		v_item.l_inItem063 := gBunsho;	-- インボイス文章
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> gGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> 1,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	ELSE
		-- 帳票ワークへ追加した最終行に合計行を更新する（最終銘柄分）
		CALL spIp03701_01_updSreportWkKngkSum();
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug('ECM701', REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug('ECM701', REPORT_ID, 'spIp03701_01 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip03701_01 ( l_inUserId TEXT, l_inItakuKaishaCd TEXT, l_inMgrCd text, l_inIsinCd TEXT, l_inHakkoYmd TEXT, l_inTsuchiYmd TEXT, l_inChohyoKbn TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spip03701_01_updsreportwkkngksum () AS $body$
BEGIN
	-- 帳票ワークへ追加した最終行に合計行を更新する
	UPDATE SREPORT_WK SC16
	SET
		 SC16.ITEM044		=   CASE WHEN gShokanGankinGk=0 THEN  NULL  ELSE gShokanGankinGk END 			-- 償還元金合計
		,SC16.ITEM045		=   CASE WHEN gGnknShrTesuryoGk=0 THEN  NULL  ELSE gGnknShrTesuryoGk END 		-- 元金支払手数料合計
		,SC16.ITEM046		=   CASE WHEN gGnknShrTesuryoZeiGk=0 THEN  NULL  ELSE gGnknShrTesuryoZeiGk END 	-- 元金支払手数料消費税合計
		,SC16.ITEM047		=	CASE WHEN gRknGk=0 THEN  NULL  ELSE gRknGk END 								-- 利金合計
		,SC16.ITEM048		=	CASE WHEN gRknShrTesuryoGk=0 THEN  NULL  ELSE gRknShrTesuryoGk END 			-- 利金支払手数料合計
		,SC16.ITEM049		=	CASE WHEN gRknShrTesuryoZeiGk=0 THEN  NULL  ELSE gRknShrTesuryoZeiGk END 	-- 利金支払手数料消費税合計
		,SC16.ITEM050		=	CASE WHEN gKichuTesuryoGk=0 THEN  NULL  ELSE gKichuTesuryoGk END 			-- 収益管理手数料合計
		,SC16.ITEM051		=	CASE WHEN gKichuTesuryoZeiGk=0 THEN  NULL  ELSE gKichuTesuryoZeiGk END 		-- 収益管理手数料消費税合計
		,SC16.ITEM052		=	CASE WHEN gAllShrGk=0 THEN  NULL  ELSE gAllShrGk END 						-- 支払額合計
		,SC16.ITEM053		=	CASE WHEN gAllShrZeiGk=0 THEN  NULL  ELSE gAllShrZeiGk END 					-- 支払額消費税合計
		,SC16.KOUSIN_ID		=	l_inUserId 				-- 更新者ID
		,SC16.SAKUSEI_ID	=	l_inUserId 				-- 作成者ID
	WHERE
		SC16.KEY_CD 		=	l_inItakuKaishaCd
	AND
		SC16.USER_ID		= 	l_inUserId
	AND
		SC16.CHOHYO_KBN		= 	l_inChohyoKbn
	AND
		SC16.SAKUSEI_YMD	= 	gGyomuYmd
	AND
		SC16.CHOHYO_ID		= 	REPORT_ID
	AND
		SC16.SEQ_NO			= 	gSeqNo
	AND
		SC16.HEADER_FLG		= 	'1';
EXCEPTION
	WHEN OTHERS THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip03701_01_updsreportwkkngksum () FROM PUBLIC;
