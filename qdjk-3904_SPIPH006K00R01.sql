


DROP TYPE IF EXISTS spiph006k00r01_type_record;
CREATE TYPE spiph006k00r01_type_record AS (
		gMgrCd				varchar(13)								-- 銘柄コード
		,gKokyakuMgrRnm		varchar(52)								-- 対顧客用銘柄名称１〜２６
		,gRbrYmd			char(4)										-- 利払日１〜２６
		,gGankinGokei		decimal(16,2)				-- 元金総額１〜２６
		,gRknGokei			decimal(14,2)					-- 利金総額１〜２６
		,gGnknShrTesuGokei	decimal(14,2)	-- 元金支払手数料総額１〜２６
		,gRknShrTesuGokei	decimal(14,2)		-- 利金支払手数料総額１〜２６
		,gGankin			decimal(16,2)				-- 元金１〜２６
		,gRkn				decimal(14,2)					-- 利金１〜２６
		,gGnknShrTesuKngk	decimal(14,2)	-- 元金支払手数料金額１〜２６
		,gRknShrTesuKngk	decimal(14,2)		-- 利金支払手数料金額１〜２６
		,gSzeiKngk			decimal(12,2)				-- 消費税金額１〜２６
		,gKousaihiFlg		char(1)										-- 公債費フラグ１〜２６
		,gIsinCd			varchar(12)								-- ISINコード
	);
DROP TYPE IF EXISTS spiph006k00r01_type_key;
CREATE TYPE spiph006k00r01_type_key AS (
		 gHktCd				char(6) 								-- 発行体コード
		,gIdoYmd			char(8) 								-- 異動年月日
		,gKaikeiKbn			char(2) 								-- 会計区分
		,gKousaiTaishoFlg	char(1) 								-- 公債費の対象かどうかを判定するフラグ
	);
DROP TYPE IF EXISTS spiph006k00r01_type_gokei;
CREATE TYPE spiph006k00r01_type_gokei AS (
		gGankinGokei		decimal(16,2)				-- 元金総額１〜２６
		,gRknGokei			decimal(14,2)					-- 利金総額１〜２６
		,gGnknShrTesuGokei	decimal(14,2)	-- 元金支払手数料総額１〜２６
		,gRknShrTesuGokei	decimal(14,2)		-- 利金支払手数料総額１〜２６
		,gGankin			decimal(16,2)				-- 元金１〜２６
		,gRkn				decimal(14,2)					-- 利金１〜２６
		,gGnknShrTesuKngk	decimal(14,2)	-- 元金支払手数料金額１〜２６
		,gRknShrTesuKngk	decimal(14,2)		-- 利金支払手数料金額１〜２６
		,gKaikeiGokeiKkn	decimal(14,2)	-- 会計別合計（基金）
		,gKaikeiGokeiTesu	decimal(14,2)		-- 会計別合計（手数料）
	);
DROP TYPE IF EXISTS spiph006k00r01_type_records;
CREATE TYPE spiph006k00r01_type_records AS (
		gIsin				varchar(400)
		,gWkMgr				varchar(400)
		,gWkGrTotal			varchar(400)
		,gWkGrTes			varchar(400)
		,gWkGr				varchar(400)
		,gWkGTes			varchar(400)
		,gWkKFlg			varchar(400)
		);


CREATE OR REPLACE PROCEDURE spiph006k00r01 ( l_inHktCd CHAR,		-- 発行体コード
 l_inKozaTenCd TEXT,		-- 口座店コード
 l_inKozaTenCifCd TEXT,		-- 口座店ＣＩＦコード
 l_inMgrCd TEXT,		-- 銘柄コード
 l_inIsinCd TEXT,		-- ＩＳＩＮコード
 l_inKijunYmdF TEXT,		-- 基準日From
 l_inKijunYmdT TEXT,		-- 基準日To
 l_inTsuchiYmd TEXT,		-- 通知日
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
--/* 概要　:顧客宛帳票出力指示画面の入力条件により、公債会計別元利金明細票を作成する。
--/* 引数　:	l_inHktCd				IN	CHAR		発行体コード
--/*			l_inKozaTenCd			IN	CHAR		口座店コード
--/*			l_inKozatenCifCd		IN	CHAR		口座店ＣＩＦコード
--/*			l_inMgrCd				IN	CHAR		銘柄コード
--/*			l_inIsinCd				IN	CHAR		ＩＳＩＮコード
--/*			l_inKijunYmdF			IN	CHAR		決済日From
--/*			l_inKijunYmdT			IN	CHAR		決済日To
--/*			l_inTsuchiYmd			IN	CHAR		通知日
--/*			l_inItakuKaishaCd		IN	CHAR		委託会社コード
--/*			l_inUserId				IN	CHAR		ユーザーID
--/*			l_inChohyoKbn			IN	CHAR		帳票区分
--/*			l_inGyomuYmd			IN	CHAR		業務日付
--/*			l_outSqlCode			OUT	INTEGER		リターン値
--/*			l_outSqlErrM			OUT	VARCHAR2	エラーコメント
--/* 返り値:なし
--/* @version $Id: SPIPH006K00R01.SQL,v 1.26 2016/02/16 05:29:06 takahashi Exp $
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.06.29	JIP				新規作成
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
	REPORT_ID			CONSTANT char(11)		:= 'IPH30000611';	-- 帳票ID
	-- 書式フォーマット
	FMT_HAKKO_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	FMT_RBR_KNGK_J		CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 利払金額
	FMT_SHOKAN_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 償還金額
	MGR_MAX_CNT			CONSTANT integer	:= 26;						-- 銘柄最大件数
	KAIKEI_MAX_CNT		CONSTANT integer	:= 9;						-- １頁あたりの最大会計区分数
--==============================================================================
--					変数定義													
--==============================================================================
	gRtnCd				integer :=	RTN_OK;						-- リターンコード
	gSeqNo				integer := 0;							--
	gKaikeiKbnCnt		integer := 0;							-- 会計区分カウンター
	gMgrCnt				integer := 0;							-- 銘柄カウンター
	gInstFlag			char(1) := '0';
--	gSeqNoIni			INTEGER DEFAULT 0;							-- シーケンス
	gPageKey			char(2);									-- 改ページキー
	gPageNum			integer := 0;							-- ページ番号
	gMgrCntFlg			integer := 0;
	gMgrMaxCnt			integer := 0;
	gSCnt				integer := 0;							-- 銘柄ソート用カウンター
	gKousaihiFlg		char(1) := '0';
	gChikoList			MPROCESS_CTL.CTL_VALUE%TYPE;				-- 地公体リスト（0：R、1：SR）
	-- DB取得項目
	-- キー
	-- 合計
	-- ソート順修正用
	recMeisai spiph006k00r01_type_record[];
	key spiph006k00r01_type_key;
	gokei spiph006k00r01_type_gokei;
	recSMeisai spiph006k00r01_type_records[];
	l_inItem TYPE_SREPORT_WK_ITEM;							-- 帳票ワークアイテム
--==============================================================================
--					カーソル定義													
--==============================================================================
	curMeisai CURSOR FOR
		SELECT
			 WT01.ITAKU_KAISHA_CD 						-- 委託会社コード
			,WT01.HKT_CD 								-- 発行体コード
			,WT01.HKT_RNM 								-- 発行体略称
			,WT01.IDO_YMD 								-- 異動年月日
			,trim(both WT01.ISIN_CD) AS ISIN_CD 				-- ＩＳＩＮコード
			,WT01.MGR_CD 								-- 銘柄コード
			,WT01.KOKYAKU_MGR_RNM 						-- 対雇用銘柄略称
			,WT01.BOSHU_KBN 								-- 募集区分
			,WT01.SHOKAN_METHOD_CD  						-- 償還方法
			,SUBSTR(WT01.RBR_YMD,5,4) AS RBR_YMD 		-- 利払日(MM/DD)
			--,TRIM(WT01.KKN_IDO_KBN) AS KKN_IDO_KBN	-- 基金異動区分
			,trim(both WT02.KOUSAIHI_FLG) AS KOUSAIHI_FLG 	-- 公債費フラグ
			,WT01.GANKIN_GOKEI 							-- 元金総額
			,WT01.RKN_GOKEI 								-- 利金総額
			,WT01.GNKN_SHR_TESU_KNGK_GOKEI 				-- 元金支払手数料総額
			,WT01.RKN_SHR_TESU_KNGK_GOKEI 				-- 利金支払手数料総額
			,WT02.INPUT_NUM 								-- 入力順
			,WT02.KAIKEI_KBN 							-- 会計区分
			,WT02.KAIKEI_KBN_RNM 						-- 会計区分略称
			,WT02.GANKIN 								-- 元金
			,WT02.RKN 									-- 利金
			,WT02.GNKN_SHR_TESU_KNGK 					-- 元金支払手数料
			,WT02.RKN_SHR_TESU_KNGK 						-- 利金支払手数料
			,WT02.SHR_KKN 								-- 支払基金
			,WT02.SHR_TESU 								-- 支払手数料
			,WT02.SZEI_KNGK 								-- 消費税
			,CASE coalesce((SELECT MAX(KOUSAIHI_FLG) FROM KAIKEI_KBN WHERE ITAKU_KAISHA_CD = WT01.ITAKU_KAISHA_CD AND HKT_CD = WT01.HKT_CD),'0')
				WHEN '0' THEN
					'0'									-- 会計区分マスタで公債費フラグを使用していない発行体
				ELSE
					WT01.KOUSAIHI_FLG 					-- 公債費フラグを使用している場合は銘柄の属性により判定
			 END KOUSAI_TAISHO_FLG 						-- 公債費の対象を判定するフラグ
		FROM (
			SELECT
				 WT001.ITAKU_KAISHA_CD 					-- 委託会社コード
				,WT001.HKT_CD 							-- 発行体コード
				,WT001.HKT_RNM 							-- 発行体略称
				,WT001.IDO_YMD 							-- 異動年月日
				,H01.INPUT_NUM 							-- 入力順
				,H01.KAIKEI_KBN 							-- 会計区分
				,WT001.ISIN_CD 							-- ＩＳＩＮコード
				,WT001.MGR_CD 							-- 銘柄コード
				,WT001.KOKYAKU_MGR_RNM 					-- 対雇用銘柄略称
				,WT001.BOSHU_KBN 						-- 募集区分
				,WT001.SHOKAN_METHOD_CD  				-- 償還方法
				,WT001.RBR_YMD 							-- 利払日
				,WT001.RBR_KJT 							-- 利払期日
				--,WT001.KKN_IDO_KBN					-- 基金異動区分
				,CASE WHEN gChikoList='0' THEN '1'  ELSE WT001.KOUSAIHI_FLG END  AS KOUSAIHI_FLG 	-- 公債費フラグ
				,WT001.GANKIN_GOKEI 						-- 元金総額
				,WT001.RKN_GOKEI 						-- 利金総額
				,WT001.GNKN_SHR_TESU_KNGK_GOKEI 			-- 元金支払手数料総額
				,WT001.RKN_SHR_TESU_KNGK_GOKEI 			-- 利金支払手数料総額
			FROM (
					SELECT
						 H04.ITAKU_KAISHA_CD 							-- 委託会社コード
						,M01.HKT_CD 										-- 発行体コード
						,MAX(M01.HKT_RNM) AS HKT_RNM 					-- 発行体略称
						,H04.IDO_YMD 									-- 異動年月日
						,MAX(MG1.ISIN_CD) AS ISIN_CD 					-- ＩＳＩＮコード
						,H04.MGR_CD 										-- 銘柄コード
						,MAX(MG1.KOKYAKU_MGR_RNM) AS KOKYAKU_MGR_RNM 	-- 対雇用銘柄略称
						,MAX(MG1.BOSHU_KBN) AS BOSHU_KBN 				-- 募集区分
						,MAX(MG1.SHOKAN_METHOD_CD) AS SHOKAN_METHOD_CD   -- 償還方法
						,MAX(H04.RBR_YMD) AS RBR_YMD 					-- 利払日
						,MAX(H04.RBR_KJT) AS RBR_KJT 					-- 利払期日
						--,MAX(K02.KKN_IDO_KBN) AS KKN_IDO_KBN			-- 基金異動区分
						,MAX(H04.KOUSAIHI_FLG) AS KOUSAIHI_FLG 			-- 公債費フラグ
						,SUM(H04.GANKIN) AS GANKIN_GOKEI 				-- 元金総額
						,SUM(H04.RKN) AS RKN_GOKEI 						-- 利金総額
						,SUM(H04.GNKN_SHR_TESU_KNGK) AS GNKN_SHR_TESU_KNGK_GOKEI 	-- 元金支払手数料総額
						,SUM(H04.RKN_SHR_TESU_KNGK) AS RKN_SHR_TESU_KNGK_GOKEI 		-- 利金支払手数料総額
						,SUM(H04.SZEI_KNGK)AS SZEI_KNGK_GOKEI 			-- 消費税金額総額
					FROM
						 MHAKKOTAI M01
						,MGR_KIHON MG1
						,MGR_STS MG0
						,KIKIN_IDO_KAIKEI H04
					WHERE
							MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
						AND	MG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
						AND	MG1.HKT_CD = M01.HKT_CD
						AND MG1.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
						AND MG1.MGR_CD = MG0.MGR_CD
						AND MG0.MGR_STAT_KBN = '1'
						AND MG0.MASSHO_FLG = '0'
						AND	M01.KOZA_TEN_CD LIKE CASE WHEN coalesce(trim(both l_inKozaTenCd)::text, '') = '' THEN  '%'  ELSE trim(both l_inKozaTenCd) END
						AND	trim(both M01.KOZA_TEN_CIFCD) LIKE CASE WHEN coalesce(trim(both l_inKozaTenCifCd)::text, '') = '' THEN  '%'  ELSE trim(both l_inKozaTenCifCd) END 
						AND	MG1.HKT_CD LIKE CASE WHEN coalesce(trim(both l_inHktCd)::text, '') = '' THEN  '%'  ELSE trim(both l_inHktCd) END 
						AND	MG1.MGR_CD LIKE CASE WHEN coalesce(trim(both l_inMgrCd)::text, '') = '' THEN  '%'  ELSE trim(both l_inMgrCd) END 
						AND	MG1.ISIN_CD LIKE CASE WHEN coalesce(trim(both l_inIsinCd)::text, '') = '' THEN  '%'  ELSE trim(both l_inIsinCd) END 
						AND	MG1.ITAKU_KAISHA_CD = H04.ITAKU_KAISHA_CD
						AND	MG1.MGR_CD = H04.MGR_CD
						-- 会計按分テーブルの承認済み銘柄のみ抽出対象にする
						AND PKIPAKKNIDO.GETKAIKEIANBUNCOUNT(MG1.ITAKU_KAISHA_CD , MG1.MGR_CD) > 0
						AND	H04.IDO_YMD BETWEEN l_inKijunYmdF AND l_inKijunYmdT
						--AND	H04.ITAKU_KAISHA_CD = K02.ITAKU_KAISHA_CD
						--AND	H04.MGR_CD = K02.MGR_CD
						--AND	H04.RBR_KJT = K02.RBR_KJT
 
					GROUP BY
						 H04.ITAKU_KAISHA_CD
						,H04.MGR_CD
						,H04.RBR_KJT
						,H04.IDO_YMD
						,M01.HKT_CD
								) WT001
								,KAIKEI_KBN H01 
						WHERE	WT001.ITAKU_KAISHA_CD = H01.ITAKU_KAISHA_CD
						AND		WT001.HKT_CD = H01.HKT_CD
				) WT01
				,(
					(
					SELECT
						 H04.ITAKU_KAISHA_CD
						,H04.MGR_CD
						,H04.RBR_KJT
						,H04.IDO_YMD
						,H04.INPUT_NUM
						,H04.KOUSAIHI_FLG
						,H04.KAIKEI_KBN
						,H01.KAIKEI_KBN_RNM
						,H04.GANKIN
						,H04.RKN
						,H04.GNKN_SHR_TESU_KNGK
						,H04.RKN_SHR_TESU_KNGK
						,H04.GANKIN + H04.RKN AS SHR_KKN
						,H04.GNKN_SHR_TESU_KNGK + H04.RKN_SHR_TESU_KNGK AS SHR_TESU
						,H04.SZEI_KNGK AS SZEI_KNGK
					FROM
						 KIKIN_IDO_KAIKEI H04
						,KAIKEI_KBN H01
						,MGR_KIHON MG1
						,MGR_STS MG0
					WHERE
							MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
						AND MG1.ITAKU_KAISHA_CD = H04.ITAKU_KAISHA_CD
						AND MG1.MGR_CD = H04.MGR_CD
						AND MG1.ITAKU_KAISHA_CD = H01.ITAKU_KAISHA_CD
						AND MG1.HKT_CD = H01.HKT_CD
						AND MG1.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
						AND MG1.MGR_CD = MG0.MGR_CD
						AND MG0.MGR_STAT_KBN = '1'
						AND MG0.MASSHO_FLG = '0'
						AND	H01.KAIKEI_KBN = H04.KAIKEI_KBN
						AND	H04.MGR_CD LIKE CASE WHEN coalesce(trim(both l_inMgrCd)::text, '') = '' THEN  '%'  ELSE trim(both l_inMgrCd) END 
            			-- 会計按分テーブルの承認済み銘柄のみ抽出対象にする
            			AND PKIPAKKNIDO.GETKAIKEIANBUNCOUNT(MG1.ITAKU_KAISHA_CD , MG1.MGR_CD) > 0
						AND	H04.IDO_YMD BETWEEN l_inKijunYmdF AND l_inKijunYmdT
						AND	H01.HKT_CD LIKE CASE WHEN coalesce(trim(both l_inHktCd)::text, '') = '' THEN  '%'  ELSE trim(both l_inHktCd) END  
					)
					
UNION
(
					SELECT
						 H04.ITAKU_KAISHA_CD
						,H04.MGR_CD
						,H04.RBR_KJT
						,H04.IDO_YMD
						,MAX(0) AS INPUT_NUM
						,MAX('0') AS KOUSAIHI_FLG
						,MAX('00') AS KAIKEI_KBN
						,CASE WHEN gChikoList='0' THEN '小計（公債管理特別会計支払分）'  ELSE '公債費特別会計' END  AS KAIKEI_KBN_RNM
						,SUM(CASE WHEN H04.KOUSAIHI_FLG='1' THEN H04.GANKIN  ELSE 0 END ) AS GANKIN
						,SUM(CASE WHEN H04.KOUSAIHI_FLG='1' THEN H04.RKN  ELSE 0 END ) AS RKN
						,SUM(CASE WHEN H04.KOUSAIHI_FLG='1' THEN H04.GNKN_SHR_TESU_KNGK  ELSE 0 END ) AS GNKN_SHR_TESU_KNGK
						,SUM(CASE WHEN H04.KOUSAIHI_FLG='1' THEN H04.RKN_SHR_TESU_KNGK  ELSE 0 END ) AS RKN_SHR_TESU_KNGK
						,SUM(CASE WHEN H04.KOUSAIHI_FLG='1' THEN H04.GANKIN  ELSE 0 END ) 
						+ SUM(CASE WHEN H04.KOUSAIHI_FLG='1' THEN H04.RKN  ELSE 0 END ) AS SHR_KKN
						,SUM(CASE WHEN H04.KOUSAIHI_FLG='1' THEN H04.GNKN_SHR_TESU_KNGK  ELSE 0 END ) 
						+ SUM(CASE WHEN H04.KOUSAIHI_FLG='1' THEN H04.RKN_SHR_TESU_KNGK  ELSE 0 END )						
						,SUM(CASE WHEN H04.KOUSAIHI_FLG='1' THEN H04.SZEI_KNGK  ELSE 0 END ) AS SZEI_KNGK						
					FROM
						KIKIN_IDO_KAIKEI H04,MGR_KIHON MG1,MGR_STS MG0
					WHERE
							H04.ITAKU_KAISHA_CD = l_inItakuKaishaCd
						AND	H04.MGR_CD LIKE CASE WHEN coalesce(trim(both l_inMgrCd)::text, '') = '' THEN  '%'  ELSE trim(both l_inMgrCd) END 
						AND	H04.IDO_YMD BETWEEN l_inKijunYmdF AND l_inKijunYmdT
						AND	H04.KOUSAIHI_FLG  LIKE CASE WHEN trim(both gChikoList)='0' THEN  '%'  ELSE trim(both '1') END 
						AND H04.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
						AND H04.MGR_CD = MG1.MGR_CD
						AND MG1.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
						AND MG1.MGR_CD = MG0.MGR_CD
						AND MG0.MGR_STAT_KBN = '1'
						AND MG0.MASSHO_FLG = '0'
            			-- 会計按分テーブルの承認済み銘柄のみ抽出対象にする
            			AND PKIPAKKNIDO.GETKAIKEIANBUNCOUNT(MG1.ITAKU_KAISHA_CD , MG1.MGR_CD) > 0 
					GROUP BY
						 H04.ITAKU_KAISHA_CD
						,H04.MGR_CD
						,H04.RBR_KJT
						,H04.IDO_YMD
					)
				) WT02
		WHERE
				WT01.ITAKU_KAISHA_CD = WT02.ITAKU_KAISHA_CD
			AND	WT01.MGR_CD = WT02.MGR_CD
			AND	WT01.RBR_KJT = WT02.RBR_KJT
			AND	WT01.IDO_YMD = WT02.IDO_YMD
			AND (trim(both WT01.ISIN_CD) IS NOT NULL AND (trim(both WT01.ISIN_CD))::text <> '') 
		GROUP BY
			 WT01.ITAKU_KAISHA_CD
			,WT01.HKT_CD
			,WT01.HKT_RNM
			,WT01.IDO_YMD
			,trim(both WT01.ISIN_CD)
			,WT01.MGR_CD
			,WT01.KOKYAKU_MGR_RNM
			,WT01.BOSHU_KBN
			,WT01.SHOKAN_METHOD_CD
			,SUBSTR(WT01.RBR_YMD,5,4)
			,trim(both WT02.KOUSAIHI_FLG)
			,WT01.GANKIN_GOKEI
			,WT01.RKN_GOKEI
			,WT01.GNKN_SHR_TESU_KNGK_GOKEI
			,WT01.RKN_SHR_TESU_KNGK_GOKEI
			,WT02.INPUT_NUM
			,WT02.KAIKEI_KBN
			,WT02.KAIKEI_KBN_RNM
			,WT02.GANKIN
			,WT02.RKN
			,WT02.GNKN_SHR_TESU_KNGK
			,WT02.RKN_SHR_TESU_KNGK
			,WT02.SHR_KKN
			,WT02.SHR_TESU
			,WT02.SZEI_KNGK
			,CASE coalesce((SELECT MAX(KOUSAIHI_FLG) FROM KAIKEI_KBN WHERE ITAKU_KAISHA_CD = WT01.ITAKU_KAISHA_CD AND HKT_CD = WT01.HKT_CD),'0')
				WHEN '0' THEN '0' ELSE WT01.KOUSAIHI_FLG END
		ORDER BY
			 WT01.IDO_YMD
			,HKT_CD ASC
			,KOUSAI_TAISHO_FLG DESC
			,INPUT_NUM
			,ISIN_CD
			,RBR_YMD ASC;
	rec				RECORD;
	recPrevMeisai	RECORD;
	-- ソート順用対象データ抽出SQL
	curSort CURSOR FOR
		SELECT 	S.KEY_CD KEY_CD,
				S.USER_ID USER_ID,
				S.CHOHYO_KBN CHOHYO_KBN,
				S.SAKUSEI_YMD SAKUSEI_YMD,
				S.CHOHYO_ID CHOHYO_ID,
				S.SEQ_NO SEQ_NO
		  FROM  SREPORT_WK S
		 WHERE	S.KEY_CD = l_inItakuKaishaCd
		   AND	S.USER_ID = l_inUserId
		   AND	S.SAKUSEI_YMD = l_inGyomuYmd
		   AND	S.CHOHYO_ID = REPORT_ID
		   AND	S.HEADER_FLG != '0'
	  ORDER BY  S.SEQ_NO;
	recS		RECORD;
	-- 銘柄並べ替えSQL
	curSortMeisai CURSOR(l_inSeqNo numeric) FOR
		SELECT ISIN,WKMGR,WKGRTOTAL,WKGRTES,WKGR,WKGTES,WKKFLG
		  FROM(
			(SELECT T1.ITEM182 AS ISIN, T1.ITEM007 AS WKMGR, T1.ITEM033  AS WKGRTOTAL,T1.ITEM061  AS WKGRTES,T1.ITEM092  AS WKGR,T1.ITEM120  AS WKGTES,T1.ITEM154  AS WKKFLG FROM SREPORT_WK T1 WHERE T1.KEY_CD = l_inItakuKaishaCd AND T1.USER_ID = l_inUserId AND T1.CHOHYO_KBN = '0' AND T1.SAKUSEI_YMD = l_inGyomuYmd AND T1.CHOHYO_ID = REPORT_ID AND T1.SEQ_NO = l_inSeqNo)
UNION ALL
(SELECT T2.ITEM183 AS ISIN, T2.ITEM008 AS WKMGR, T2.ITEM034  AS WKGRTOTAL,T2.ITEM062  AS WKGRTES,T2.ITEM093  AS WKGR,T2.ITEM121  AS WKGTES,T2.ITEM155  AS WKKFLG FROM SREPORT_WK T2 WHERE T2.KEY_CD = l_inItakuKaishaCd AND T2.USER_ID = l_inUserId AND T2.CHOHYO_KBN = '0' AND T2.SAKUSEI_YMD = l_inGyomuYmd AND T2.CHOHYO_ID = REPORT_ID AND T2.SEQ_NO = l_inSeqNo) 
UNION ALL
(SELECT T3.ITEM184 AS ISIN, T3.ITEM009 AS WKMGR, T3.ITEM035  AS WKGRTOTAL,T3.ITEM063  AS WKGRTES,T3.ITEM094  AS WKGR,T3.ITEM122  AS WKGTES,T3.ITEM156  AS WKKFLG FROM SREPORT_WK T3 WHERE T3.KEY_CD = l_inItakuKaishaCd AND T3.USER_ID = l_inUserId AND T3.CHOHYO_KBN = '0' AND T3.SAKUSEI_YMD = l_inGyomuYmd AND T3.CHOHYO_ID = REPORT_ID AND T3.SEQ_NO = l_inSeqNo) 
UNION ALL
(SELECT T4.ITEM185 AS ISIN, T4.ITEM010 AS WKMGR, T4.ITEM036  AS WKGRTOTAL,T4.ITEM064  AS WKGRTES,T4.ITEM095  AS WKGR,T4.ITEM123  AS WKGTES,T4.ITEM157  AS WKKFLG FROM SREPORT_WK T4 WHERE T4.KEY_CD = l_inItakuKaishaCd AND T4.USER_ID = l_inUserId AND T4.CHOHYO_KBN = '0' AND T4.SAKUSEI_YMD = l_inGyomuYmd AND T4.CHOHYO_ID = REPORT_ID AND T4.SEQ_NO = l_inSeqNo) 
UNION ALL
(SELECT T5.ITEM186 AS ISIN, T5.ITEM011 AS WKMGR, T5.ITEM037  AS WKGRTOTAL,T5.ITEM065  AS WKGRTES,T5.ITEM096  AS WKGR,T5.ITEM124  AS WKGTES,T5.ITEM158  AS WKKFLG FROM SREPORT_WK T5 WHERE T5.KEY_CD = l_inItakuKaishaCd AND T5.USER_ID = l_inUserId AND T5.CHOHYO_KBN = '0' AND T5.SAKUSEI_YMD = l_inGyomuYmd AND T5.CHOHYO_ID = REPORT_ID AND T5.SEQ_NO = l_inSeqNo) 
UNION ALL
(SELECT T6.ITEM187 AS ISIN, T6.ITEM012 AS WKMGR, T6.ITEM038  AS WKGRTOTAL,T6.ITEM066  AS WKGRTES,T6.ITEM097  AS WKGR,T6.ITEM125  AS WKGTES,T6.ITEM159  AS WKKFLG FROM SREPORT_WK T6 WHERE T6.KEY_CD = l_inItakuKaishaCd AND T6.USER_ID = l_inUserId AND T6.CHOHYO_KBN = '0' AND T6.SAKUSEI_YMD = l_inGyomuYmd AND T6.CHOHYO_ID = REPORT_ID AND T6.SEQ_NO = l_inSeqNo) 
UNION ALL
(SELECT T7.ITEM188 AS ISIN, T7.ITEM013 AS WKMGR, T7.ITEM039  AS WKGRTOTAL,T7.ITEM067  AS WKGRTES,T7.ITEM098  AS WKGR,T7.ITEM126  AS WKGTES,T7.ITEM160  AS WKKFLG FROM SREPORT_WK T7 WHERE T7.KEY_CD = l_inItakuKaishaCd AND T7.USER_ID = l_inUserId AND T7.CHOHYO_KBN = '0' AND T7.SAKUSEI_YMD = l_inGyomuYmd AND T7.CHOHYO_ID = REPORT_ID AND T7.SEQ_NO = l_inSeqNo) 
UNION ALL
(SELECT T8.ITEM189 AS ISIN, T8.ITEM014 AS WKMGR, T8.ITEM040  AS WKGRTOTAL,T8.ITEM068  AS WKGRTES,T8.ITEM099  AS WKGR,T8.ITEM127  AS WKGTES,T8.ITEM161  AS WKKFLG FROM SREPORT_WK T8 WHERE T8.KEY_CD = l_inItakuKaishaCd AND T8.USER_ID = l_inUserId AND T8.CHOHYO_KBN = '0' AND T8.SAKUSEI_YMD = l_inGyomuYmd AND T8.CHOHYO_ID = REPORT_ID AND T8.SEQ_NO = l_inSeqNo) 
UNION ALL
(SELECT T9.ITEM190 AS ISIN, T9.ITEM015 AS WKMGR, T9.ITEM041  AS WKGRTOTAL,T9.ITEM069  AS WKGRTES,T9.ITEM100  AS WKGR,T9.ITEM128  AS WKGTES,T9.ITEM162  AS WKKFLG FROM SREPORT_WK T9 WHERE T9.KEY_CD = l_inItakuKaishaCd AND T9.USER_ID = l_inUserId AND T9.CHOHYO_KBN = '0' AND T9.SAKUSEI_YMD = l_inGyomuYmd AND T9.CHOHYO_ID = REPORT_ID AND T9.SEQ_NO = l_inSeqNo) 
UNION ALL
(SELECT T10.ITEM191 AS ISIN,T10.ITEM016 AS WKMGR,T10.ITEM042 AS WKGRTOTAL,T10.ITEM070 AS WKGRTES,T10.ITEM101 AS WKGR,T10.ITEM129 AS WKGTES,T10.ITEM163 AS WKKFLG FROM SREPORT_WK T10 WHERE T10.KEY_CD = l_inItakuKaishaCd AND T10.USER_ID = l_inUserId AND T10.CHOHYO_KBN = '0' AND T10.SAKUSEI_YMD = l_inGyomuYmd AND T10.CHOHYO_ID = REPORT_ID AND T10.SEQ_NO = l_inSeqNo) 
UNION ALL
(SELECT T11.ITEM192 AS ISIN,T11.ITEM017 AS WKMGR,T11.ITEM043 AS WKGRTOTAL,T11.ITEM071 AS WKGRTES,T11.ITEM102 AS WKGR,T11.ITEM130 AS WKGTES,T11.ITEM164 AS WKKFLG FROM SREPORT_WK T11 WHERE T11.KEY_CD = l_inItakuKaishaCd AND T11.USER_ID = l_inUserId AND T11.CHOHYO_KBN = '0' AND T11.SAKUSEI_YMD = l_inGyomuYmd AND T11.CHOHYO_ID = REPORT_ID AND T11.SEQ_NO = l_inSeqNo) 
UNION ALL
(SELECT T12.ITEM193 AS ISIN,T12.ITEM018 AS WKMGR,T12.ITEM044 AS WKGRTOTAL,T12.ITEM072 AS WKGRTES,T12.ITEM103 AS WKGR,T12.ITEM131 AS WKGTES,T12.ITEM165 AS WKKFLG FROM SREPORT_WK T12 WHERE T12.KEY_CD = l_inItakuKaishaCd AND T12.USER_ID = l_inUserId AND T12.CHOHYO_KBN = '0' AND T12.SAKUSEI_YMD = l_inGyomuYmd AND T12.CHOHYO_ID = REPORT_ID AND T12.SEQ_NO = l_inSeqNo) 
UNION ALL
(SELECT T13.ITEM194 AS ISIN,T13.ITEM019 AS WKMGR,T13.ITEM045 AS WKGRTOTAL,T13.ITEM073 AS WKGRTES,T13.ITEM104 AS WKGR,T13.ITEM132 AS WKGTES,T13.ITEM166 AS WKKFLG FROM SREPORT_WK T13 WHERE T13.KEY_CD = l_inItakuKaishaCd AND T13.USER_ID = l_inUserId AND T13.CHOHYO_KBN = '0' AND T13.SAKUSEI_YMD = l_inGyomuYmd AND T13.CHOHYO_ID = REPORT_ID AND T13.SEQ_NO = l_inSeqNo) 
UNION ALL
(SELECT T14.ITEM195 AS ISIN,T14.ITEM020 AS WKMGR,T14.ITEM046 AS WKGRTOTAL,T14.ITEM074 AS WKGRTES,T14.ITEM105 AS WKGR,T14.ITEM133 AS WKGTES,T14.ITEM167 AS WKKFLG FROM SREPORT_WK T14 WHERE T14.KEY_CD = l_inItakuKaishaCd AND T14.USER_ID = l_inUserId AND T14.CHOHYO_KBN = '0' AND T14.SAKUSEI_YMD = l_inGyomuYmd AND T14.CHOHYO_ID = REPORT_ID AND T14.SEQ_NO = l_inSeqNo) 
UNION ALL
(SELECT T15.ITEM196 AS ISIN,T15.ITEM021 AS WKMGR,T15.ITEM047 AS WKGRTOTAL,T15.ITEM075 AS WKGRTES,T15.ITEM106 AS WKGR,T15.ITEM134 AS WKGTES,T15.ITEM168 AS WKKFLG FROM SREPORT_WK T15 WHERE T15.KEY_CD = l_inItakuKaishaCd AND T15.USER_ID = l_inUserId AND T15.CHOHYO_KBN = '0' AND T15.SAKUSEI_YMD = l_inGyomuYmd AND T15.CHOHYO_ID = REPORT_ID AND T15.SEQ_NO = l_inSeqNo) 
UNION ALL
(SELECT T16.ITEM197 AS ISIN,T16.ITEM022 AS WKMGR,T16.ITEM048 AS WKGRTOTAL,T16.ITEM076 AS WKGRTES,T16.ITEM107 AS WKGR,T16.ITEM135 AS WKGTES,T16.ITEM169 AS WKKFLG FROM SREPORT_WK T16 WHERE T16.KEY_CD = l_inItakuKaishaCd AND T16.USER_ID = l_inUserId AND T16.CHOHYO_KBN = '0' AND T16.SAKUSEI_YMD = l_inGyomuYmd AND T16.CHOHYO_ID = REPORT_ID AND T16.SEQ_NO = l_inSeqNo) 
UNION ALL
(SELECT T17.ITEM198 AS ISIN,T17.ITEM023 AS WKMGR,T17.ITEM049 AS WKGRTOTAL,T17.ITEM077 AS WKGRTES,T17.ITEM108 AS WKGR,T17.ITEM136 AS WKGTES,T17.ITEM170 AS WKKFLG FROM SREPORT_WK T17 WHERE T17.KEY_CD = l_inItakuKaishaCd AND T17.USER_ID = l_inUserId AND T17.CHOHYO_KBN = '0' AND T17.SAKUSEI_YMD = l_inGyomuYmd AND T17.CHOHYO_ID = REPORT_ID AND T17.SEQ_NO = l_inSeqNo) 
UNION ALL
(SELECT T18.ITEM199 AS ISIN,T18.ITEM024 AS WKMGR,T18.ITEM050 AS WKGRTOTAL,T18.ITEM078 AS WKGRTES,T18.ITEM109 AS WKGR,T18.ITEM137 AS WKGTES,T18.ITEM171 AS WKKFLG FROM SREPORT_WK T18 WHERE T18.KEY_CD = l_inItakuKaishaCd AND T18.USER_ID = l_inUserId AND T18.CHOHYO_KBN = '0' AND T18.SAKUSEI_YMD = l_inGyomuYmd AND T18.CHOHYO_ID = REPORT_ID AND T18.SEQ_NO = l_inSeqNo) 
UNION ALL
(SELECT T19.ITEM200 AS ISIN,T19.ITEM025 AS WKMGR,T19.ITEM051 AS WKGRTOTAL,T19.ITEM079 AS WKGRTES,T19.ITEM110 AS WKGR,T19.ITEM138 AS WKGTES,T19.ITEM172 AS WKKFLG FROM SREPORT_WK T19 WHERE T19.KEY_CD = l_inItakuKaishaCd AND T19.USER_ID = l_inUserId AND T19.CHOHYO_KBN = '0' AND T19.SAKUSEI_YMD = l_inGyomuYmd AND T19.CHOHYO_ID = REPORT_ID AND T19.SEQ_NO = l_inSeqNo) 
UNION ALL
(SELECT T20.ITEM201 AS ISIN,T20.ITEM026 AS WKMGR,T20.ITEM052 AS WKGRTOTAL,T20.ITEM080 AS WKGRTES,T20.ITEM111 AS WKGR,T20.ITEM139 AS WKGTES,T20.ITEM173 AS WKKFLG FROM SREPORT_WK T20 WHERE T20.KEY_CD = l_inItakuKaishaCd AND T20.USER_ID = l_inUserId AND T20.CHOHYO_KBN = '0' AND T20.SAKUSEI_YMD = l_inGyomuYmd AND T20.CHOHYO_ID = REPORT_ID AND T20.SEQ_NO = l_inSeqNo) 
UNION ALL
(SELECT T21.ITEM202 AS ISIN,T21.ITEM027 AS WKMGR,T21.ITEM053 AS WKGRTOTAL,T21.ITEM081 AS WKGRTES,T21.ITEM112 AS WKGR,T21.ITEM140 AS WKGTES,T21.ITEM174 AS WKKFLG FROM SREPORT_WK T21 WHERE T21.KEY_CD = l_inItakuKaishaCd AND T21.USER_ID = l_inUserId AND T21.CHOHYO_KBN = '0' AND T21.SAKUSEI_YMD = l_inGyomuYmd AND T21.CHOHYO_ID = REPORT_ID AND T21.SEQ_NO = l_inSeqNo) 
UNION ALL
(SELECT T22.ITEM203 AS ISIN,T22.ITEM028 AS WKMGR,T22.ITEM054 AS WKGRTOTAL,T22.ITEM082 AS WKGRTES,T22.ITEM113 AS WKGR,T22.ITEM141 AS WKGTES,T22.ITEM175 AS WKKFLG FROM SREPORT_WK T22 WHERE T22.KEY_CD = l_inItakuKaishaCd AND T22.USER_ID = l_inUserId AND T22.CHOHYO_KBN = '0' AND T22.SAKUSEI_YMD = l_inGyomuYmd AND T22.CHOHYO_ID = REPORT_ID AND T22.SEQ_NO = l_inSeqNo) 
UNION ALL
(SELECT T23.ITEM204 AS ISIN,T23.ITEM029 AS WKMGR,T23.ITEM055 AS WKGRTOTAL,T23.ITEM083 AS WKGRTES,T23.ITEM114 AS WKGR,T23.ITEM142 AS WKGTES,T23.ITEM176 AS WKKFLG FROM SREPORT_WK T23 WHERE T23.KEY_CD = l_inItakuKaishaCd AND T23.USER_ID = l_inUserId AND T23.CHOHYO_KBN = '0' AND T23.SAKUSEI_YMD = l_inGyomuYmd AND T23.CHOHYO_ID = REPORT_ID AND T23.SEQ_NO = l_inSeqNo) 
UNION ALL
(SELECT T24.ITEM205 AS ISIN,T24.ITEM030 AS WKMGR,T24.ITEM056 AS WKGRTOTAL,T24.ITEM084 AS WKGRTES,T24.ITEM115 AS WKGR,T24.ITEM143 AS WKGTES,T24.ITEM177 AS WKKFLG FROM SREPORT_WK T24 WHERE T24.KEY_CD = l_inItakuKaishaCd AND T24.USER_ID = l_inUserId AND T24.CHOHYO_KBN = '0' AND T24.SAKUSEI_YMD = l_inGyomuYmd AND T24.CHOHYO_ID = REPORT_ID AND T24.SEQ_NO = l_inSeqNo) 
UNION ALL
(SELECT T25.ITEM206 AS ISIN,T25.ITEM031 AS WKMGR,T25.ITEM057 AS WKGRTOTAL,T25.ITEM085 AS WKGRTES,T25.ITEM116 AS WKGR,T25.ITEM144 AS WKGTES,T25.ITEM178 AS WKKFLG FROM SREPORT_WK T25 WHERE T25.KEY_CD = l_inItakuKaishaCd AND T25.USER_ID = l_inUserId AND T25.CHOHYO_KBN = '0' AND T25.SAKUSEI_YMD = l_inGyomuYmd AND T25.CHOHYO_ID = REPORT_ID AND T25.SEQ_NO = l_inSeqNo) 
UNION ALL
(SELECT T26.ITEM207 AS ISIN,T26.ITEM032 AS WKMGR,T26.ITEM058 AS WKGRTOTAL,T26.ITEM086 AS WKGRTES,T26.ITEM117 AS WKGR,T26.ITEM145 AS WKGTES,T26.ITEM179 AS WKKFLG FROM SREPORT_WK T26 WHERE T26.KEY_CD = l_inItakuKaishaCd AND T26.USER_ID = l_inUserId AND T26.CHOHYO_KBN = '0' AND T26.SAKUSEI_YMD = l_inGyomuYmd AND T26.CHOHYO_ID = REPORT_ID AND T26.SEQ_NO = l_inSeqNo) )W
		ORDER BY W.ISIN;
	recSM		RECORD;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPH006K00R01 START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inKijunYmdF)::text, '') = ''
	OR coalesce(trim(both l_inKijunYmdT)::text, '') = ''
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
	-- プロセス制御値取得
	gChikoList := pkcontrol.getCtlValue(l_inItakuKaishaCd, 'ChikoList', '0'); -- 地公体帳票出力判定フラグ
	-- 初回レコードの場合、帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	-- データ取得
	FOR rec IN curMeisai LOOP
		IF key.gHktCd != rec.HKT_CD
		OR key.gIdoYmd != rec.IDO_YMD
		OR key.gKaikeiKbn != rec.KAIKEI_KBN
		OR key.gKousaiTaishoFlg != rec.KOUSAI_TAISHO_FLG
		THEN
		-- キーブレイク
			IF gInstFlag = '1' THEN
				-- 会計区分カウンター
				IF key.gHktCd = rec.HKT_CD	AND key.gIdoYmd = rec.IDO_YMD
											AND key.gKaikeiKbn != rec.KAIKEI_KBN
											AND key.gKousaiTaishoFlg = rec.KOUSAI_TAISHO_FLG
				THEN
					-- 会計区分のみでブレイクしている場合は＋１
					gKaikeiKbnCnt	:= gKaikeiKbnCnt + 1;
				ELSE
					-- 発行体コードまたは異動年月日でブレイクしている場合は、０クリア
					gKaikeiKbnCnt	:= 0;
				END IF;
				-- 集計
				FOR i IN 0..MGR_MAX_CNT - 1 LOOP
					gokei.gGankinGokei		:= gokei.gGankinGokei		+ coalesce(recMeisai[i].gGankinGokei, 0);			-- 元金総額合計
					gokei.gRknGokei			:= gokei.gRknGokei			+ coalesce(recMeisai[i].gRknGokei, 0);				-- 利金総額合計
					gokei.gGnknShrTesuGokei	:= gokei.gGnknShrTesuGokei	+ coalesce(recMeisai[i].gGnknShrTesuGokei, 0);		-- 元金支払手数料総額合計
					gokei.gRknShrTesuGokei	:= gokei.gRknShrTesuGokei	+ coalesce(recMeisai[i].gRknShrTesuGokei, 0);		-- 利金支払手数料総額合計
					gokei.gGankin			:= gokei.gGankin			+ coalesce(recMeisai[i].gGankin, 0);					-- 元金合計
					gokei.gRkn				:= gokei.gRkn				+ coalesce(recMeisai[i].gRkn, 0);					-- 利金合計
					gokei.gGnknShrTesuKngk	:= gokei.gGnknShrTesuKngk	+ coalesce(recMeisai[i].gGnknShrTesuKngk, 0);		-- 元金支払手数料金額合計
					gokei.gRknShrTesuKngk	:= gokei.gRknShrTesuKngk	+ coalesce(recMeisai[i].gRknShrTesuKngk, 0);			-- 利金支払手数料金額合計
					-- 公債費の対象にならない銘柄は、強制で公債費フラグを「0：公債費ではない」に
					gKousaihiFlg := recPrevMeisai.KOUSAIHI_FLG;
					IF recPrevMeisai.KOUSAI_TAISHO_FLG = '0' THEN
						recMeisai[i].gKousaihiFlg := '0';
						gKousaihiFlg := '0';
					END IF;
					-- 地公体帳票出力判定フラグ'1：SR'の場合
					IF gChikoList = '1' THEN
						IF recMeisai[i].gKousaihiFlg = '0' THEN
							gokei.gKaikeiGokeiKkn	:= coalesce(gokei.gKaikeiGokeiKkn,0) + coalesce(recMeisai[i].gGankin, 0) + coalesce(recMeisai[i].gRkn, 0);
							gokei.gKaikeiGokeiTesu	:= coalesce(gokei.gKaikeiGokeiTesu,0) + coalesce(recMeisai[i].gGnknShrTesuKngk, 0) + coalesce(recMeisai[i].gRknShrTesuKngk, 0);
						END IF;
					ELSE  -- '0:Rの場合'
						-- 基金 + 手数料
						gokei.gKaikeiGokeiKkn	:= coalesce(gokei.gKaikeiGokeiKkn,0) + coalesce(recMeisai[i].gGankin, 0) + coalesce(recMeisai[i].gRkn, 0) + coalesce(recMeisai[i].gGnknShrTesuKngk, 0) + coalesce(recMeisai[i].gRknShrTesuKngk, 0);
						-- 消費税
						gokei.gKaikeiGokeiTesu	:= coalesce(gokei.gKaikeiGokeiTesu,0) + coalesce(recMeisai[i].gSzeiKngk, 0);
					END IF;
					-- 金額項目が0の場合はNULLを設定する
					--IF recMeisai(i).gGankinGokei		= 0 THEN recMeisai(i).gGankinGokei		:= NULL; END IF;		-- 元金総額合計
					--IF recMeisai(i).gRknGokei			= 0 THEN recMeisai(i).gRknGokei			:= NULL; END IF;		-- 利金総額合計
					--IF recMeisai(i).gGnknShrTesuGokei	= 0 THEN recMeisai(i).gGnknShrTesuGokei	:= NULL; END IF; 		-- 元金支払手数料総額合計
					--IF recMeisai(i).gRknShrTesuGokei	= 0 THEN recMeisai(i).gRknShrTesuGokei	:= NULL; END IF; 		-- 利金支払手数料総額合計
					--IF recMeisai(i).gGankin				= 0 THEN recMeisai(i).gGankin			:= NULL; END IF;		-- 元金合計
					--IF recMeisai(i).gRkn				= 0 THEN recMeisai(i).gRkn				:= NULL; END IF;		-- 利金合計
					--IF recMeisai(i).gGnknShrTesuKngk	= 0 THEN recMeisai(i).gGnknShrTesuKngk	:= NULL; END IF; 		-- 元金支払手数料金額合計
					--IF recMeisai(i).gRknShrTesuKngk		= 0 THEN recMeisai(i).gRknShrTesuKngk	:= NULL; END IF;		-- 利金支払手数料金額合計
				END LOOP;
				-- 会計別合計（基金、手数料）を設定
				--IF recPrevMeisai.KOUSAIHI_FLG = '1' THEN
				IF gokei.gKaikeiGokeiKkn + gokei.gKaikeiGokeiTesu = 0 THEN
					-- 公債費フラグが'1'の場合は出力しない
					gokei.gKaikeiGokeiKkn	:= NULL;
					gokei.gKaikeiGokeiTesu	:= NULL;
				--ELSE
					--gokei.gKaikeiGokeiKkn	:= gokei.gGankin + gokei.gRkn;
					--gokei.gKaikeiGokeiTesu	:= gokei.gGnknShrTesuKngk + gokei.gRknShrTesuKngk;
				END IF;
				-- 金額項目が0の場合はNULLを設定する
				--IF gokei.gGankinGokei		= 0 THEN gokei.gGankinGokei			:= NULL; END IF;		-- 元金総額合計
				--IF gokei.gRknGokei			= 0 THEN gokei.gRknGokei			:= NULL; END IF;		-- 利金総額合計
				--IF gokei.gGnknShrTesuGokei	= 0 THEN gokei.gGnknShrTesuGokei	:= NULL; END IF;		-- 元金支払手数料総額合計
				--IF gokei.gRknShrTesuGokei	= 0 THEN gokei.gRknShrTesuGokei		:= NULL; END IF;		-- 利金支払手数料総額合計
				--IF gokei.gGankin			= 0 THEN gokei.gGankin				:= NULL; END IF;		-- 元金合計
				--IF gokei.gRkn				= 0 THEN gokei.gRkn					:= NULL; END IF;		-- 利金合計
				--IF gokei.gGnknShrTesuKngk	= 0 THEN gokei.gGnknShrTesuKngk		:= NULL; END IF;		-- 元金支払手数料金額合計
				--IF gokei.gRknShrTesuKngk	= 0 THEN gokei.gRknShrTesuKngk		:= NULL; END IF;		-- 利金支払手数料金額合計
				--IF gokei.gKaikeiGokeiKkn	= 0 THEN gokei.gKaikeiGokeiKkn		:= NULL; END IF;		-- 会計別合計（基金）
				--IF gokei.gKaikeiGokeiTesu	= 0 THEN gokei.gKaikeiGokeiTesu		:= NULL; END IF;		-- 会計別合計（手数料）
				IF recPrevMeisai.KAIKEI_KBN = gPageKey THEN
					gPageNum := gPageNum + 1;
				END IF;
				-- 帳票ワークへデータを追加
				gSeqNo := gSeqNo + 1;
				-- TYPE_SREPORT_WK_ITEM にパック
				l_inItem.l_inItem001 := l_inUserId;
				l_inItem.l_inItem002 := recPrevMeisai.HKT_CD;
				l_inItem.l_inItem003 := recPrevMeisai.HKT_RNM;
				l_inItem.l_inItem004 := recPrevMeisai.IDO_YMD;
				l_inItem.l_inItem005 := recPrevMeisai.ISIN_CD;
				l_inItem.l_inItem006 := gKousaihiFlg;
				l_inItem.l_inItem007 := recMeisai[0].gKokyakuMgrRnm || '/' || recMeisai[0].gRbrYmd;
				l_inItem.l_inItem008 := recMeisai[1].gKokyakuMgrRnm || '/' || recMeisai[1].gRbrYmd;
				l_inItem.l_inItem009 := recMeisai[2].gKokyakuMgrRnm || '/' || recMeisai[2].gRbrYmd;
				l_inItem.l_inItem010 := recMeisai[3].gKokyakuMgrRnm || '/' || recMeisai[3].gRbrYmd;
				l_inItem.l_inItem011 := recMeisai[4].gKokyakuMgrRnm || '/' || recMeisai[4].gRbrYmd;
				l_inItem.l_inItem012 := recMeisai[5].gKokyakuMgrRnm || '/' || recMeisai[5].gRbrYmd;
				l_inItem.l_inItem013 := recMeisai[6].gKokyakuMgrRnm || '/' || recMeisai[6].gRbrYmd;
				l_inItem.l_inItem014 := recMeisai[7].gKokyakuMgrRnm || '/' || recMeisai[7].gRbrYmd;
				l_inItem.l_inItem015 := recMeisai[8].gKokyakuMgrRnm || '/' || recMeisai[8].gRbrYmd;
				l_inItem.l_inItem016 := recMeisai[9].gKokyakuMgrRnm || '/' || recMeisai[9].gRbrYmd;
				l_inItem.l_inItem017 := recMeisai[10].gKokyakuMgrRnm || '/' || recMeisai[10].gRbrYmd;
				l_inItem.l_inItem018 := recMeisai[11].gKokyakuMgrRnm || '/' || recMeisai[11].gRbrYmd;
				l_inItem.l_inItem019 := recMeisai[12].gKokyakuMgrRnm || '/' || recMeisai[12].gRbrYmd;
				l_inItem.l_inItem020 := recMeisai[13].gKokyakuMgrRnm || '/' || recMeisai[13].gRbrYmd;
				l_inItem.l_inItem021 := recMeisai[14].gKokyakuMgrRnm || '/' || recMeisai[14].gRbrYmd;
				l_inItem.l_inItem022 := recMeisai[15].gKokyakuMgrRnm || '/' || recMeisai[15].gRbrYmd;
				l_inItem.l_inItem023 := recMeisai[16].gKokyakuMgrRnm || '/' || recMeisai[16].gRbrYmd;
				l_inItem.l_inItem024 := recMeisai[17].gKokyakuMgrRnm || '/' || recMeisai[17].gRbrYmd;
				l_inItem.l_inItem025 := recMeisai[18].gKokyakuMgrRnm || '/' || recMeisai[18].gRbrYmd;
				l_inItem.l_inItem026 := recMeisai[19].gKokyakuMgrRnm || '/' || recMeisai[19].gRbrYmd;
				l_inItem.l_inItem027 := recMeisai[20].gKokyakuMgrRnm || '/' || recMeisai[20].gRbrYmd;
				l_inItem.l_inItem028 := recMeisai[21].gKokyakuMgrRnm || '/' || recMeisai[21].gRbrYmd;
				l_inItem.l_inItem029 := recMeisai[22].gKokyakuMgrRnm || '/' || recMeisai[22].gRbrYmd;
				l_inItem.l_inItem030 := recMeisai[23].gKokyakuMgrRnm || '/' || recMeisai[23].gRbrYmd;
				l_inItem.l_inItem031 := recMeisai[24].gKokyakuMgrRnm || '/' || recMeisai[24].gRbrYmd;
				l_inItem.l_inItem032 := recMeisai[25].gKokyakuMgrRnm || '/' || recMeisai[25].gRbrYmd;
				l_inItem.l_inItem037 := recPrevMeisai.KKN_IDO_KBN;
				l_inItem.l_inItem033 := recMeisai[0].gGankinGokei || '/' || recMeisai[0].gRknGokei;
				l_inItem.l_inItem034 := recMeisai[1].gGankinGokei || '/' || recMeisai[1].gRknGokei;
				l_inItem.l_inItem035 := recMeisai[2].gGankinGokei || '/' || recMeisai[2].gRknGokei;
				l_inItem.l_inItem036 := recMeisai[3].gGankinGokei || '/' || recMeisai[3].gRknGokei;
				l_inItem.l_inItem037 := recMeisai[4].gGankinGokei || '/' || recMeisai[4].gRknGokei;
				l_inItem.l_inItem038 := recMeisai[5].gGankinGokei || '/' || recMeisai[5].gRknGokei;
				l_inItem.l_inItem039 := recMeisai[6].gGankinGokei || '/' || recMeisai[6].gRknGokei;
				l_inItem.l_inItem040 := recMeisai[7].gGankinGokei || '/' || recMeisai[7].gRknGokei;
				l_inItem.l_inItem041 := recMeisai[8].gGankinGokei || '/' || recMeisai[8].gRknGokei;
				l_inItem.l_inItem042 := recMeisai[9].gGankinGokei || '/' || recMeisai[9].gRknGokei;
				l_inItem.l_inItem043 := recMeisai[10].gGankinGokei || '/' || recMeisai[10].gRknGokei;
				l_inItem.l_inItem044 := recMeisai[11].gGankinGokei || '/' || recMeisai[11].gRknGokei;
				l_inItem.l_inItem045 := recMeisai[12].gGankinGokei || '/' || recMeisai[12].gRknGokei;
				l_inItem.l_inItem046 := recMeisai[13].gGankinGokei || '/' || recMeisai[13].gRknGokei;
				l_inItem.l_inItem047 := recMeisai[14].gGankinGokei || '/' || recMeisai[14].gRknGokei;
				l_inItem.l_inItem048 := recMeisai[15].gGankinGokei || '/' || recMeisai[15].gRknGokei;
				l_inItem.l_inItem049 := recMeisai[16].gGankinGokei || '/' || recMeisai[16].gRknGokei;
				l_inItem.l_inItem050 := recMeisai[17].gGankinGokei || '/' || recMeisai[17].gRknGokei;
				l_inItem.l_inItem051 := recMeisai[18].gGankinGokei || '/' || recMeisai[18].gRknGokei;
				l_inItem.l_inItem052 := recMeisai[19].gGankinGokei || '/' || recMeisai[19].gRknGokei;
				l_inItem.l_inItem053 := recMeisai[20].gGankinGokei || '/' || recMeisai[20].gRknGokei;
				l_inItem.l_inItem054 := recMeisai[21].gGankinGokei || '/' || recMeisai[21].gRknGokei;
				l_inItem.l_inItem055 := recMeisai[22].gGankinGokei || '/' || recMeisai[22].gRknGokei;
				l_inItem.l_inItem056 := recMeisai[23].gGankinGokei || '/' || recMeisai[23].gRknGokei;
				l_inItem.l_inItem057 := recMeisai[24].gGankinGokei || '/' || recMeisai[24].gRknGokei;
				l_inItem.l_inItem058 := recMeisai[25].gGankinGokei || '/' || recMeisai[25].gRknGokei;
				l_inItem.l_inItem059 := gokei.gGankinGokei;
				l_inItem.l_inItem060 := gokei.gRknGokei;
				l_inItem.l_inItem061 := recMeisai[0].gGnknShrTesuGokei || '/' || recMeisai[0].gRknShrTesuGokei;
				l_inItem.l_inItem062 := recMeisai[1].gGnknShrTesuGokei || '/' || recMeisai[1].gRknShrTesuGokei;
				l_inItem.l_inItem063 := recMeisai[2].gGnknShrTesuGokei || '/' || recMeisai[2].gRknShrTesuGokei;
				l_inItem.l_inItem064 := recMeisai[3].gGnknShrTesuGokei || '/' || recMeisai[3].gRknShrTesuGokei;
				l_inItem.l_inItem065 := recMeisai[4].gGnknShrTesuGokei || '/' || recMeisai[4].gRknShrTesuGokei;
				l_inItem.l_inItem066 := recMeisai[5].gGnknShrTesuGokei || '/' || recMeisai[5].gRknShrTesuGokei;
				l_inItem.l_inItem067 := recMeisai[6].gGnknShrTesuGokei || '/' || recMeisai[6].gRknShrTesuGokei;
				l_inItem.l_inItem068 := recMeisai[7].gGnknShrTesuGokei || '/' || recMeisai[7].gRknShrTesuGokei;
				l_inItem.l_inItem069 := recMeisai[8].gGnknShrTesuGokei || '/' || recMeisai[8].gRknShrTesuGokei;
				l_inItem.l_inItem070 := recMeisai[9].gGnknShrTesuGokei || '/' || recMeisai[9].gRknShrTesuGokei;
				l_inItem.l_inItem071 := recMeisai[10].gGnknShrTesuGokei || '/' || recMeisai[10].gRknShrTesuGokei;
				l_inItem.l_inItem072 := recMeisai[11].gGnknShrTesuGokei || '/' || recMeisai[11].gRknShrTesuGokei;
				l_inItem.l_inItem073 := recMeisai[12].gGnknShrTesuGokei || '/' || recMeisai[12].gRknShrTesuGokei;
				l_inItem.l_inItem074 := recMeisai[13].gGnknShrTesuGokei || '/' || recMeisai[13].gRknShrTesuGokei;
				l_inItem.l_inItem075 := recMeisai[14].gGnknShrTesuGokei || '/' || recMeisai[14].gRknShrTesuGokei;
				l_inItem.l_inItem076 := recMeisai[15].gGnknShrTesuGokei || '/' || recMeisai[15].gRknShrTesuGokei;
				l_inItem.l_inItem077 := recMeisai[16].gGnknShrTesuGokei || '/' || recMeisai[16].gRknShrTesuGokei;
				l_inItem.l_inItem078 := recMeisai[17].gGnknShrTesuGokei || '/' || recMeisai[17].gRknShrTesuGokei;
				l_inItem.l_inItem079 := recMeisai[18].gGnknShrTesuGokei || '/' || recMeisai[18].gRknShrTesuGokei;
				l_inItem.l_inItem080 := recMeisai[19].gGnknShrTesuGokei || '/' || recMeisai[19].gRknShrTesuGokei;
				l_inItem.l_inItem081 := recMeisai[20].gGnknShrTesuGokei || '/' || recMeisai[20].gRknShrTesuGokei;
				l_inItem.l_inItem082 := recMeisai[21].gGnknShrTesuGokei || '/' || recMeisai[21].gRknShrTesuGokei;
				l_inItem.l_inItem083 := recMeisai[22].gGnknShrTesuGokei || '/' || recMeisai[22].gRknShrTesuGokei;
				l_inItem.l_inItem084 := recMeisai[23].gGnknShrTesuGokei || '/' || recMeisai[23].gRknShrTesuGokei;
				l_inItem.l_inItem085 := recMeisai[24].gGnknShrTesuGokei || '/' || recMeisai[24].gRknShrTesuGokei;
				l_inItem.l_inItem086 := recMeisai[25].gGnknShrTesuGokei || '/' || recMeisai[25].gRknShrTesuGokei;
				l_inItem.l_inItem087 := gokei.gGnknShrTesuGokei;
				l_inItem.l_inItem088 := gokei.gRknShrTesuGokei;
				l_inItem.l_inItem089 := gPageNum;
				l_inItem.l_inItem090 := recPrevMeisai.KAIKEI_KBN;
				l_inItem.l_inItem091 := recPrevMeisai.KAIKEI_KBN_RNM;
				l_inItem.l_inItem092 := recMeisai[0].gGankin || '/' || recMeisai[0].gRkn;
				l_inItem.l_inItem093 := recMeisai[1].gGankin || '/' || recMeisai[1].gRkn;
				l_inItem.l_inItem094 := recMeisai[2].gGankin || '/' || recMeisai[2].gRkn;
				l_inItem.l_inItem095 := recMeisai[3].gGankin || '/' || recMeisai[3].gRkn;
				l_inItem.l_inItem096 := recMeisai[4].gGankin || '/' || recMeisai[4].gRkn;
				l_inItem.l_inItem097 := recMeisai[5].gGankin || '/' || recMeisai[5].gRkn;
				l_inItem.l_inItem098 := recMeisai[6].gGankin || '/' || recMeisai[6].gRkn;
				l_inItem.l_inItem099 := recMeisai[7].gGankin || '/' || recMeisai[7].gRkn;
				l_inItem.l_inItem100 := recMeisai[8].gGankin || '/' || recMeisai[8].gRkn;
				l_inItem.l_inItem101 := recMeisai[9].gGankin || '/' || recMeisai[9].gRkn;
				l_inItem.l_inItem102 := recMeisai[10].gGankin || '/' || recMeisai[10].gRkn;
				l_inItem.l_inItem103 := recMeisai[11].gGankin || '/' || recMeisai[11].gRkn;
				l_inItem.l_inItem104 := recMeisai[12].gGankin || '/' || recMeisai[12].gRkn;
				l_inItem.l_inItem105 := recMeisai[13].gGankin || '/' || recMeisai[13].gRkn;
				l_inItem.l_inItem106 := recMeisai[14].gGankin || '/' || recMeisai[14].gRkn;
				l_inItem.l_inItem107 := recMeisai[15].gGankin || '/' || recMeisai[15].gRkn;
				l_inItem.l_inItem108 := recMeisai[16].gGankin || '/' || recMeisai[16].gRkn;
				l_inItem.l_inItem109 := recMeisai[17].gGankin || '/' || recMeisai[17].gRkn;
				l_inItem.l_inItem110 := recMeisai[18].gGankin || '/' || recMeisai[18].gRkn;
				l_inItem.l_inItem111 := recMeisai[19].gGankin || '/' || recMeisai[19].gRkn;
				l_inItem.l_inItem112 := recMeisai[20].gGankin || '/' || recMeisai[20].gRkn;
				l_inItem.l_inItem113 := recMeisai[21].gGankin || '/' || recMeisai[21].gRkn;
				l_inItem.l_inItem114 := recMeisai[22].gGankin || '/' || recMeisai[22].gRkn;
				l_inItem.l_inItem115 := recMeisai[23].gGankin || '/' || recMeisai[23].gRkn;
				l_inItem.l_inItem116 := recMeisai[24].gGankin || '/' || recMeisai[24].gRkn;
				l_inItem.l_inItem117 := recMeisai[25].gGankin || '/' || recMeisai[25].gRkn;
				l_inItem.l_inItem118 := gokei.gGankin;
				l_inItem.l_inItem119 := gokei.gRkn;
				l_inItem.l_inItem120 := recMeisai[0].gGnknShrTesuKngk || '/' || recMeisai[0].gRknShrTesuKngk;
				l_inItem.l_inItem121 := recMeisai[1].gGnknShrTesuKngk || '/' || recMeisai[1].gRknShrTesuKngk;
				l_inItem.l_inItem122 := recMeisai[2].gGnknShrTesuKngk || '/' || recMeisai[2].gRknShrTesuKngk;
				l_inItem.l_inItem123 := recMeisai[3].gGnknShrTesuKngk || '/' || recMeisai[3].gRknShrTesuKngk;
				l_inItem.l_inItem124 := recMeisai[4].gGnknShrTesuKngk || '/' || recMeisai[4].gRknShrTesuKngk;
				l_inItem.l_inItem125 := recMeisai[5].gGnknShrTesuKngk || '/' || recMeisai[5].gRknShrTesuKngk;
				l_inItem.l_inItem126 := recMeisai[6].gGnknShrTesuKngk || '/' || recMeisai[6].gRknShrTesuKngk;
				l_inItem.l_inItem127 := recMeisai[7].gGnknShrTesuKngk || '/' || recMeisai[7].gRknShrTesuKngk;
				l_inItem.l_inItem128 := recMeisai[8].gGnknShrTesuKngk || '/' || recMeisai[8].gRknShrTesuKngk;
				l_inItem.l_inItem129 := recMeisai[9].gGnknShrTesuKngk || '/' || recMeisai[9].gRknShrTesuKngk;
				l_inItem.l_inItem130 := recMeisai[10].gGnknShrTesuKngk || '/' || recMeisai[10].gRknShrTesuKngk;
				l_inItem.l_inItem131 := recMeisai[11].gGnknShrTesuKngk || '/' || recMeisai[11].gRknShrTesuKngk;
				l_inItem.l_inItem132 := recMeisai[12].gGnknShrTesuKngk || '/' || recMeisai[12].gRknShrTesuKngk;
				l_inItem.l_inItem133 := recMeisai[13].gGnknShrTesuKngk || '/' || recMeisai[13].gRknShrTesuKngk;
				l_inItem.l_inItem134 := recMeisai[14].gGnknShrTesuKngk || '/' || recMeisai[14].gRknShrTesuKngk;
				l_inItem.l_inItem135 := recMeisai[15].gGnknShrTesuKngk || '/' || recMeisai[15].gRknShrTesuKngk;
				l_inItem.l_inItem136 := recMeisai[16].gGnknShrTesuKngk || '/' || recMeisai[16].gRknShrTesuKngk;
				l_inItem.l_inItem137 := recMeisai[17].gGnknShrTesuKngk || '/' || recMeisai[17].gRknShrTesuKngk;
				l_inItem.l_inItem138 := recMeisai[18].gGnknShrTesuKngk || '/' || recMeisai[18].gRknShrTesuKngk;
				l_inItem.l_inItem139 := recMeisai[19].gGnknShrTesuKngk || '/' || recMeisai[19].gRknShrTesuKngk;
				l_inItem.l_inItem140 := recMeisai[20].gGnknShrTesuKngk || '/' || recMeisai[20].gRknShrTesuKngk;
				l_inItem.l_inItem141 := recMeisai[21].gGnknShrTesuKngk || '/' || recMeisai[21].gRknShrTesuKngk;
				l_inItem.l_inItem142 := recMeisai[22].gGnknShrTesuKngk || '/' || recMeisai[22].gRknShrTesuKngk;
				l_inItem.l_inItem143 := recMeisai[23].gGnknShrTesuKngk || '/' || recMeisai[23].gRknShrTesuKngk;
				l_inItem.l_inItem144 := recMeisai[24].gGnknShrTesuKngk || '/' || recMeisai[24].gRknShrTesuKngk;
				l_inItem.l_inItem145 := recMeisai[25].gGnknShrTesuKngk || '/' || recMeisai[25].gRknShrTesuKngk;
				l_inItem.l_inItem146 := gokei.gGnknShrTesuKngk;
				l_inItem.l_inItem147 := gokei.gRknShrTesuKngk;
				l_inItem.l_inItem148 := gokei.gKaikeiGokeiKkn;
				l_inItem.l_inItem149 := gokei.gKaikeiGokeiTesu;
				l_inItem.l_inItem150 := REPORT_ID;
				l_inItem.l_inItem151 := FMT_HAKKO_KNGK_J;
				l_inItem.l_inItem152 := FMT_RBR_KNGK_J;
				l_inItem.l_inItem153 := FMT_SHOKAN_KNGK_J;
				l_inItem.l_inItem154 := recMeisai[0].gKousaihiFlg;
				l_inItem.l_inItem155 := recMeisai[1].gKousaihiFlg;
				l_inItem.l_inItem156 := recMeisai[2].gKousaihiFlg;
				l_inItem.l_inItem157 := recMeisai[3].gKousaihiFlg;
				l_inItem.l_inItem158 := recMeisai[4].gKousaihiFlg;
				l_inItem.l_inItem159 := recMeisai[5].gKousaihiFlg;
				l_inItem.l_inItem160 := recMeisai[6].gKousaihiFlg;
				l_inItem.l_inItem161 := recMeisai[7].gKousaihiFlg;
				l_inItem.l_inItem162 := recMeisai[8].gKousaihiFlg;
				l_inItem.l_inItem163 := recMeisai[9].gKousaihiFlg;
				l_inItem.l_inItem164 := recMeisai[10].gKousaihiFlg;
				l_inItem.l_inItem165 := recMeisai[11].gKousaihiFlg;
				l_inItem.l_inItem166 := recMeisai[12].gKousaihiFlg;
				l_inItem.l_inItem167 := recMeisai[13].gKousaihiFlg;
				l_inItem.l_inItem168 := recMeisai[14].gKousaihiFlg;
				l_inItem.l_inItem169 := recMeisai[15].gKousaihiFlg;
				l_inItem.l_inItem170 := recMeisai[16].gKousaihiFlg;
				l_inItem.l_inItem171 := recMeisai[17].gKousaihiFlg;
				l_inItem.l_inItem172 := recMeisai[18].gKousaihiFlg;
				l_inItem.l_inItem173 := recMeisai[19].gKousaihiFlg;
				l_inItem.l_inItem174 := recMeisai[20].gKousaihiFlg;
				l_inItem.l_inItem175 := recMeisai[21].gKousaihiFlg;
				l_inItem.l_inItem176 := recMeisai[22].gKousaihiFlg;
				l_inItem.l_inItem177 := recMeisai[23].gKousaihiFlg;
				l_inItem.l_inItem178 := recMeisai[24].gKousaihiFlg;
				l_inItem.l_inItem179 := recMeisai[25].gKousaihiFlg;
				l_inItem.l_inItem181 := recPrevMeisai.Kousai_Taisho_Flg;
				l_inItem.l_inItem182 := recMeisai[0].gIsinCd;
				l_inItem.l_inItem183 := recMeisai[1].gIsinCd;
				l_inItem.l_inItem184 := recMeisai[2].gIsinCd;
				l_inItem.l_inItem185 := recMeisai[3].gIsinCd;
				l_inItem.l_inItem186 := recMeisai[4].gIsinCd;
				l_inItem.l_inItem187 := recMeisai[5].gIsinCd;
				l_inItem.l_inItem188 := recMeisai[6].gIsinCd;
				l_inItem.l_inItem189 := recMeisai[7].gIsinCd;
				l_inItem.l_inItem190 := recMeisai[8].gIsinCd;
				l_inItem.l_inItem191 := recMeisai[9].gIsinCd;
				l_inItem.l_inItem192 := recMeisai[10].gIsinCd;
				l_inItem.l_inItem193 := recMeisai[11].gIsinCd;
				l_inItem.l_inItem194 := recMeisai[12].gIsinCd;
				l_inItem.l_inItem195 := recMeisai[13].gIsinCd;
				l_inItem.l_inItem196 := recMeisai[14].gIsinCd;
				l_inItem.l_inItem197 := recMeisai[15].gIsinCd;
				l_inItem.l_inItem198 := recMeisai[16].gIsinCd;
				l_inItem.l_inItem199 := recMeisai[17].gIsinCd;
				l_inItem.l_inItem200 := recMeisai[18].gIsinCd;
				l_inItem.l_inItem201 := recMeisai[19].gIsinCd;
				l_inItem.l_inItem202 := recMeisai[20].gIsinCd;
				l_inItem.l_inItem203 := recMeisai[21].gIsinCd;
				l_inItem.l_inItem204 := recMeisai[22].gIsinCd;
				l_inItem.l_inItem205 := recMeisai[23].gIsinCd;
				l_inItem.l_inItem206 := recMeisai[24].gIsinCd;
				l_inItem.l_inItem207 := recMeisai[25].gIsinCd;
				l_inItem.l_inItem208 := gChikoList;
				CALL pkPrint.insertData(
					l_inKeyCd      => l_inItakuKaishaCd,
					l_inUserId     => l_inUserId,
					l_inChohyoKbn  => l_inChohyoKbn,
					l_inSakuseiYmd => l_inGyomuYmd,
					l_inChohyoId   => REPORT_ID,
					l_inSeqNo      => gSeqNo,
					l_inHeaderFlg  => '1',
					l_inItem       => l_inItem,
					l_inKousinId   => l_inUserId,
					l_inSakuseiId  => l_inUserId
				);
				UPDATE SREPORT_WK
				SET ITEM007 =  CASE WHEN recMeisai[0].gKokyakuMgrRnm || recMeisai[0].gRbrYmd = NULL THEN ITEM007  ELSE recMeisai[0].gKokyakuMgrRnm || '/' || recMeisai[0].gRbrYmd END
					,ITEM008 = CASE WHEN recMeisai[1].gKokyakuMgrRnm || recMeisai[1].gRbrYmd = NULL THEN ITEM008  ELSE recMeisai[1].gKokyakuMgrRnm || '/' || recMeisai[1].gRbrYmd END 
					,ITEM009 = CASE WHEN recMeisai[2].gKokyakuMgrRnm || recMeisai[2].gRbrYmd = NULL THEN ITEM009  ELSE recMeisai[2].gKokyakuMgrRnm || '/' || recMeisai[2].gRbrYmd END 
					,ITEM010 = CASE WHEN recMeisai[3].gKokyakuMgrRnm || recMeisai[3].gRbrYmd = NULL THEN ITEM010  ELSE recMeisai[3].gKokyakuMgrRnm || '/' || recMeisai[3].gRbrYmd END 
					,ITEM011 = CASE WHEN recMeisai[4].gKokyakuMgrRnm || recMeisai[4].gRbrYmd = NULL THEN ITEM011  ELSE recMeisai[4].gKokyakuMgrRnm || '/' || recMeisai[4].gRbrYmd END 
					,ITEM012 = CASE WHEN recMeisai[5].gKokyakuMgrRnm || recMeisai[5].gRbrYmd = NULL THEN ITEM012  ELSE recMeisai[5].gKokyakuMgrRnm || '/' || recMeisai[5].gRbrYmd END 
					,ITEM013 = CASE WHEN recMeisai[6].gKokyakuMgrRnm || recMeisai[6].gRbrYmd = NULL THEN ITEM013  ELSE recMeisai[6].gKokyakuMgrRnm || '/' || recMeisai[6].gRbrYmd END 
					,ITEM014 = CASE WHEN recMeisai[7].gKokyakuMgrRnm || recMeisai[7].gRbrYmd = NULL THEN ITEM014  ELSE recMeisai[7].gKokyakuMgrRnm || '/' || recMeisai[7].gRbrYmd END 
					,ITEM015 = CASE WHEN recMeisai[8].gKokyakuMgrRnm || recMeisai[8].gRbrYmd = NULL THEN ITEM015  ELSE recMeisai[8].gKokyakuMgrRnm || '/' || recMeisai[8].gRbrYmd END 
					,ITEM016 = CASE WHEN recMeisai[9].gKokyakuMgrRnm || recMeisai[9].gRbrYmd = NULL THEN ITEM016  ELSE recMeisai[9].gKokyakuMgrRnm || '/' || recMeisai[9].gRbrYmd END 
					,ITEM017 = CASE WHEN recMeisai[10].gKokyakuMgrRnm || recMeisai[10].gRbrYmd = NULL THEN ITEM017  ELSE recMeisai[10].gKokyakuMgrRnm || '/' || recMeisai[10].gRbrYmd END 
					,ITEM018 = CASE WHEN recMeisai[11].gKokyakuMgrRnm || recMeisai[11].gRbrYmd = NULL THEN ITEM018  ELSE recMeisai[11].gKokyakuMgrRnm || '/' || recMeisai[11].gRbrYmd END 
					,ITEM019 = CASE WHEN recMeisai[12].gKokyakuMgrRnm || recMeisai[12].gRbrYmd = NULL THEN ITEM019  ELSE recMeisai[12].gKokyakuMgrRnm || '/' || recMeisai[12].gRbrYmd END 
					,ITEM020 = CASE WHEN recMeisai[13].gKokyakuMgrRnm || recMeisai[13].gRbrYmd = NULL THEN ITEM020  ELSE recMeisai[13].gKokyakuMgrRnm || '/' || recMeisai[13].gRbrYmd END 
					,ITEM021 = CASE WHEN recMeisai[14].gKokyakuMgrRnm || recMeisai[14].gRbrYmd = NULL THEN ITEM021  ELSE recMeisai[14].gKokyakuMgrRnm || '/' || recMeisai[14].gRbrYmd END 
					,ITEM022 = CASE WHEN recMeisai[15].gKokyakuMgrRnm || recMeisai[15].gRbrYmd = NULL THEN ITEM022  ELSE recMeisai[15].gKokyakuMgrRnm || '/' || recMeisai[15].gRbrYmd END 
					,ITEM023 = CASE WHEN recMeisai[16].gKokyakuMgrRnm || recMeisai[16].gRbrYmd = NULL THEN ITEM023  ELSE recMeisai[16].gKokyakuMgrRnm || '/' || recMeisai[16].gRbrYmd END 
					,ITEM024 = CASE WHEN recMeisai[17].gKokyakuMgrRnm || recMeisai[17].gRbrYmd = NULL THEN ITEM024  ELSE recMeisai[17].gKokyakuMgrRnm || '/' || recMeisai[17].gRbrYmd END 
					,ITEM025 = CASE WHEN recMeisai[18].gKokyakuMgrRnm || recMeisai[18].gRbrYmd = NULL THEN ITEM025  ELSE recMeisai[18].gKokyakuMgrRnm || '/' || recMeisai[18].gRbrYmd END 
					,ITEM026 = CASE WHEN recMeisai[19].gKokyakuMgrRnm || recMeisai[19].gRbrYmd = NULL THEN ITEM026  ELSE recMeisai[19].gKokyakuMgrRnm || '/' || recMeisai[19].gRbrYmd END 
					,ITEM027 = CASE WHEN recMeisai[20].gKokyakuMgrRnm || recMeisai[20].gRbrYmd = NULL THEN ITEM027  ELSE recMeisai[20].gKokyakuMgrRnm || '/' || recMeisai[20].gRbrYmd END 
					,ITEM028 = CASE WHEN recMeisai[21].gKokyakuMgrRnm || recMeisai[21].gRbrYmd = NULL THEN ITEM028  ELSE recMeisai[21].gKokyakuMgrRnm || '/' || recMeisai[21].gRbrYmd END 
					,ITEM029 = CASE WHEN recMeisai[22].gKokyakuMgrRnm || recMeisai[22].gRbrYmd = NULL THEN ITEM029  ELSE recMeisai[22].gKokyakuMgrRnm || '/' || recMeisai[22].gRbrYmd END 
					,ITEM030 = CASE WHEN recMeisai[23].gKokyakuMgrRnm || recMeisai[23].gRbrYmd = NULL THEN ITEM030  ELSE recMeisai[23].gKokyakuMgrRnm || '/' || recMeisai[23].gRbrYmd END 
					,ITEM031 = CASE WHEN recMeisai[24].gKokyakuMgrRnm || recMeisai[24].gRbrYmd = NULL THEN ITEM031  ELSE recMeisai[24].gKokyakuMgrRnm || '/' || recMeisai[24].gRbrYmd END 
					,ITEM032 = CASE WHEN recMeisai[25].gKokyakuMgrRnm || recMeisai[25].gRbrYmd = NULL THEN ITEM032  ELSE recMeisai[25].gKokyakuMgrRnm || '/' || recMeisai[25].gRbrYmd END 
					,ITEM182 = recMeisai[0].gIsinCd 				-- ISINCD１
					,ITEM183 = recMeisai[1].gIsinCd 				-- ISINCD２
					,ITEM184 = recMeisai[2].gIsinCd 				-- ISINCD３
					,ITEM185 = recMeisai[3].gIsinCd 				-- ISINCD４
					,ITEM186 = recMeisai[4].gIsinCd 				-- ISINCD５
					,ITEM187 = recMeisai[5].gIsinCd 				-- ISINCD６
					,ITEM188 = recMeisai[6].gIsinCd 				-- ISINCD７
					,ITEM189 = recMeisai[7].gIsinCd 				-- ISINCD８
					,ITEM190 = recMeisai[8].gIsinCd 				-- ISINCD９
					,ITEM191 = recMeisai[9].gIsinCd 				-- ISINCD１０
					,ITEM192 = recMeisai[10].gIsinCd 				-- ISINCD１１
					,ITEM193 = recMeisai[11].gIsinCd 				-- ISINCD１２
					,ITEM194 = recMeisai[12].gIsinCd 				-- ISINCD１３
					,ITEM195 = recMeisai[13].gIsinCd 				-- ISINCD１４
					,ITEM196 = recMeisai[14].gIsinCd 				-- ISINCD１５
					,ITEM197 = recMeisai[15].gIsinCd 				-- ISINCD１６
					,ITEM198 = recMeisai[16].gIsinCd 				-- ISINCD１７
					,ITEM199 = recMeisai[17].gIsinCd 				-- ISINCD１８
					,ITEM200 = recMeisai[18].gIsinCd 				-- ISINCD１９
					,ITEM201 = recMeisai[19].gIsinCd 				-- ISINCD２０
					,ITEM202 = recMeisai[20].gIsinCd 				-- ISINCD２１
					,ITEM203 = recMeisai[21].gIsinCd 				-- ISINCD２２
					,ITEM204 = recMeisai[22].gIsinCd 				-- ISINCD２３
					,ITEM205 = recMeisai[23].gIsinCd 				-- ISINCD２４
					,ITEM206 = recMeisai[24].gIsinCd 				-- ISINCD２５
					,ITEM207 = recMeisai[25].gIsinCd 				-- ISINCD２６
					,ITEM208 = gChikoList 							-- ChikoList
				WHERE	KEY_CD = l_inItakuKaishaCd
				AND		USER_ID = l_inUserId
				AND		CHOHYO_KBN = l_inChohyoKbn
				AND		SAKUSEI_YMD = l_inGyomuYmd
				AND		CHOHYO_ID = REPORT_ID
				AND		ITEM002 = recPrevMeisai.HKT_CD
				AND		ITEM004 = recPrevMeisai.IDO_YMD
				AND		ITEM181 = recPrevMeisai.Kousai_Taisho_Flg
				AND		HEADER_FLG != 0;
			END IF;
			IF key.gHktCd = rec.HKT_CD	AND key.gIdoYmd = rec.IDO_YMD
										AND key.gKaikeiKbn != rec.KAIKEI_KBN
										AND key.gKousaiTaishoFlg = rec.KOUSAI_TAISHO_FLG
			THEN
				FOR i IN 0..MGR_MAX_CNT - 1 LOOP
					recMeisai[i].gGankin			:= NULL;				-- 元金１〜２６
					recMeisai[i].gRkn				:= NULL;				-- 利金１〜２６
					recMeisai[i].gGnknShrTesuKngk	:= NULL;				-- 元金支払手数料金額１〜２６
					recMeisai[i].gRknShrTesuKngk	:= NULL;				-- 利金支払手数料金額１〜２６
					recMeisai[i].gKousaihiFlg		:= NULL;				-- 公債費フラグ１〜２６
					recMeisai[i].gSzeiKngk			:= NULL;				-- 消費税１〜２６
					IF gKaikeiKbnCnt >= KAIKEI_MAX_CNT THEN
						recMeisai[i].gGankinGokei		:= NULL;			-- 元金総額１〜２６
						recMeisai[i].gRknGokei			:= NULL;			-- 利金総額１〜２６
						recMeisai[i].gGnknShrTesuGokei	:= NULL;			-- 元金支払手数料総額１〜２６
						recMeisai[i].gRknShrTesuGokei	:= NULL;			-- 利金支払手数料総額１〜２６
					END IF;
				END LOOP;
			ELSE
				gMgrCnt := 0;
				FOR i IN 0..MGR_MAX_CNT - 1 LOOP
					recMeisai[i].gMgrCd				:= NULL;				-- 銘柄コード
					recMeisai[i].gKokyakuMgrRnm		:= NULL;				-- 対顧客用銘柄名称１〜２６
					recMeisai[i].gRbrYmd			:= NULL;				-- 利払日１〜２６
					recMeisai[i].gGankinGokei		:= NULL;				-- 元金総額１〜２６
					recMeisai[i].gRknGokei			:= NULL;				-- 利金総額１〜２６
					recMeisai[i].gGnknShrTesuGokei	:= NULL;				-- 元金支払手数料総額１〜２６
					recMeisai[i].gRknShrTesuGokei	:= NULL;				-- 利金支払手数料総額１〜２６
					recMeisai[i].gGankin			:= NULL;				-- 元金１〜２６
					recMeisai[i].gRkn				:= NULL;				-- 利金１〜２６
					recMeisai[i].gSzeiKngk			:= NULL;				-- 消費税１〜２６
					recMeisai[i].gGnknShrTesuKngk	:= NULL;				-- 元金支払手数料金額１〜２６
					recMeisai[i].gRknShrTesuKngk	:= NULL;				-- 利金支払手数料金額１〜２６
					recMeisai[i].gIsinCd			:= NULL;				-- ISINコード
				END LOOP;
			END IF;
			-- 集計用レコードをクリアする処理を作成する
			gokei.gGankinGokei		:= 0;		-- 元金総額合計
			gokei.gRknGokei			:= 0;		-- 利金総額合計
			gokei.gGnknShrTesuGokei	:= 0;		-- 元金支払手数料総額合計
			gokei.gRknShrTesuGokei	:= 0;		-- 利金支払手数料総額合計
			gokei.gGankin			:= 0;		-- 元金合計
			gokei.gRkn				:= 0;		-- 利金合計
			gokei.gGnknShrTesuKngk	:= 0;		-- 元金支払手数料金額合計
			gokei.gRknShrTesuKngk	:= 0;		-- 利金支払手数料金額合計
			gokei.gKaikeiGokeiKkn	:= 0;		-- 会計別合計（基金）
			gokei.gKaikeiGokeiTesu	:= 0;		-- 会計別合計（手数料）
			-- キー退避
			key.gHktCd		:= rec.HKT_CD;
			key.gIdoYmd		:= rec.IDO_YMD;
			key.gKaikeiKbn	:= rec.KAIKEI_KBN;
			key.gKousaiTaishoFlg	:= rec.KOUSAI_TAISHO_FLG;
			recPrevMeisai	:= rec;
		END IF;		-- END OF KEY BRAKE
		-- 初回レコード時
		IF gInstFlag = '0' THEN
			gInstFlag := '1';
			-- 改ページキーとなる会計区分を取得
			gPageKey := rec.KAIKEI_KBN;
		END IF;
		IF gMgrCnt != 0 THEN
			FOR i IN 0..gMgrCnt - 1 LOOP
					IF recMeisai[i].gMgrCd = rec.MGR_CD
							AND recMeisai[i].gRbrYmd = rec.RBR_YMD THEN
						gMgrCnt := i;
						gMgrCntFlg := 1;
					END IF;
			END LOOP;
		END IF;
		recMeisai[gMgrCnt].gMgrCd				:= rec.MGR_CD;							-- 銘柄コード
		recMeisai[gMgrCnt].gIsinCd				:= rec.ISIN_CD;							-- ISINコード
		recMeisai[gMgrCnt].gKokyakuMgrRnm		:= rec.KOKYAKU_MGR_RNM;					-- 対顧客用銘柄名称１〜２６
		recMeisai[gMgrCnt].gRbrYmd				:= rec.RBR_YMD;							-- 利払日１〜２６
		recMeisai[gMgrCnt].gKousaihiFlg			:= rec.KOUSAIHI_FLG;					-- 公債費フラグ１〜２６
		IF gKaikeiKbnCnt >= KAIKEI_MAX_CNT THEN
			-- 総額をクリアする
			recMeisai[gMgrCnt].gGankinGokei			:= NULL;							-- 元金総額１〜２６
			recMeisai[gMgrCnt].gRknGokei			:= NULL;							-- 利金総額１〜２６
			recMeisai[gMgrCnt].gGnknShrTesuGokei	:= NULL;							-- 元金支払手数料総額１〜２６
			recMeisai[gMgrCnt].gRknShrTesuGokei		:= NULL;							-- 利金支払手数料総額１〜２６
		ELSE
			recMeisai[gMgrCnt].gGankinGokei			:= rec.GANKIN_GOKEI;				-- 元金総額１〜２６
			recMeisai[gMgrCnt].gRknGokei			:= rec.RKN_GOKEI;					-- 利金総額１〜２６
			recMeisai[gMgrCnt].gGnknShrTesuGokei	:= rec.GNKN_SHR_TESU_KNGK_GOKEI;	-- 元金支払手数料総額１〜２６
			recMeisai[gMgrCnt].gRknShrTesuGokei		:= rec.RKN_SHR_TESU_KNGK_GOKEI;		-- 利金支払手数料総額１〜２６
		END IF;
		recMeisai[gMgrCnt].gGankin				:= rec.GANKIN;							-- 元金１〜２６
		recMeisai[gMgrCnt].gRkn					:= rec.RKN;								-- 利金１〜２６
		recMeisai[gMgrCnt].gGnknShrTesuKngk		:= rec.GNKN_SHR_TESU_KNGK;				-- 元金支払手数料金額１〜２６
		recMeisai[gMgrCnt].gRknShrTesuKngk		:= rec.RKN_SHR_TESU_KNGK;				-- 利金支払手数料金額１〜２６
		recMeisai[gMgrCnt].gSzeiKngk			:= rec.SZEI_KNGK;						-- 消費税金額１〜２６
		IF gMgrCntFlg = 0 THEN
			gMgrCnt := gMgrCnt + 1;
			gMgrMaxCnt := gMgrCnt;
		ELSE
			gMgrCnt := gMgrMaxCnt;
		END IF;
		gMgrCntFlg := 0;
	END LOOP;
	IF gSeqNo = 0 AND gMgrMaxCnt = 0 THEN
	-- 対象データなし
		gRtnCd := RTN_NODATA;
		-- 帳票ワークへデータを追加
		gSeqNo := gSeqNo + 1;
				-- TYPE_SREPORT_WK_ITEM にパック
				l_inItem.l_inItem001 := l_inUserId;
				l_inItem.l_inItem180 := '対象データなし';
				CALL pkPrint.insertData(
					l_inKeyCd      => l_inItakuKaishaCd,
					l_inUserId     => l_inUserId,
					l_inChohyoKbn  => l_inChohyoKbn,
					l_inSakuseiYmd => l_inGyomuYmd,
					l_inChohyoId   => REPORT_ID,
					l_inSeqNo      => gSeqNo,
					l_inHeaderFlg  => '1',
					l_inItem       => l_inItem,
					l_inKousinId   => l_inUserId,
					l_inSakuseiId  => l_inUserId
				);
	ELSE
		-- 集計
		FOR i IN 0..MGR_MAX_CNT - 1 LOOP
			gokei.gGankinGokei		:= gokei.gGankinGokei		+ coalesce(recMeisai[i].gGankinGokei, 0);			-- 元金総額合計
			gokei.gRknGokei			:= gokei.gRknGokei			+ coalesce(recMeisai[i].gRknGokei, 0);				-- 利金総額合計
			gokei.gGnknShrTesuGokei	:= gokei.gGnknShrTesuGokei	+ coalesce(recMeisai[i].gGnknShrTesuGokei, 0);		-- 元金支払手数料総額合計
			gokei.gRknShrTesuGokei	:= gokei.gRknShrTesuGokei	+ coalesce(recMeisai[i].gRknShrTesuGokei, 0);		-- 利金支払手数料総額合計
			gokei.gGankin			:= gokei.gGankin			+ coalesce(recMeisai[i].gGankin, 0);					-- 元金合計
			gokei.gRkn				:= gokei.gRkn				+ coalesce(recMeisai[i].gRkn, 0);					-- 利金合計
			gokei.gGnknShrTesuKngk	:= gokei.gGnknShrTesuKngk	+ coalesce(recMeisai[i].gGnknShrTesuKngk, 0);		-- 元金支払手数料金額合計
			gokei.gRknShrTesuKngk	:= gokei.gRknShrTesuKngk	+ coalesce(recMeisai[i].gRknShrTesuKngk, 0);			-- 利金支払手数料金額合計
			-- 公債費の対象にならない銘柄は、強制で公債費フラグを「0：公債費ではない」に
			gKousaihiFlg := recPrevMeisai.KOUSAIHI_FLG;
			IF key.gKousaiTaishoFlg = '0' THEN
				recMeisai[i].gKousaihiFlg := '0';
				gKousaihiFlg := '0';
			END IF;
			-- 地公体帳票出力判定フラグ'1：SR'の場合
			IF  gChikoList = '1' THEN
				IF recMeisai[i].gKousaihiFlg = '0' THEN
					gokei.gKaikeiGokeiKkn	:= coalesce(gokei.gKaikeiGokeiKkn,0) + coalesce(recMeisai[i].gGankin, 0) + coalesce(recMeisai[i].gRkn, 0);
					gokei.gKaikeiGokeiTesu	:= coalesce(gokei.gKaikeiGokeiTesu,0) + coalesce(recMeisai[i].gGnknShrTesuKngk, 0) + coalesce(recMeisai[i].gRknShrTesuKngk, 0);
				END IF;
			ELSE  -- '0:Rの場合'
				-- 基金 + 手数料
				gokei.gKaikeiGokeiKkn	:= coalesce(gokei.gKaikeiGokeiKkn,0) + coalesce(recMeisai[i].gGankin, 0) + coalesce(recMeisai[i].gRkn, 0) + coalesce(recMeisai[i].gGnknShrTesuKngk, 0) + coalesce(recMeisai[i].gRknShrTesuKngk, 0);
				-- 消費税
				gokei.gKaikeiGokeiTesu	:= coalesce(gokei.gKaikeiGokeiTesu,0) + coalesce(recMeisai[i].gSzeiKngk, 0);
			END IF;
			-- 金額項目が0の場合はNULLを設定する
			--IF recMeisai(i).gGankinGokei		= 0 THEN recMeisai(i).gGankinGokei		:= NULL; END IF;		-- 元金総額合計
			--IF recMeisai(i).gRknGokei			= 0 THEN recMeisai(i).gRknGokei			:= NULL; END IF;		-- 利金総額合計
			--IF recMeisai(i).gGnknShrTesuGokei	= 0 THEN recMeisai(i).gGnknShrTesuGokei	:= NULL; END IF; 		-- 元金支払手数料総額合計
			--IF recMeisai(i).gRknShrTesuGokei	= 0 THEN recMeisai(i).gRknShrTesuGokei	:= NULL; END IF; 		-- 利金支払手数料総額合計
			--IF recMeisai(i).gGankin			= 0 THEN recMeisai(i).gGankin			:= NULL; END IF;		-- 元金合計
			--IF recMeisai(i).gRkn				= 0 THEN recMeisai(i).gRkn				:= NULL; END IF;		-- 利金合計
			--IF recMeisai(i).gGnknShrTesuKngk	= 0 THEN recMeisai(i).gGnknShrTesuKngk	:= NULL; END IF; 		-- 元金支払手数料金額合計
			--IF recMeisai(i).gRknShrTesuKngk	= 0 THEN recMeisai(i).gRknShrTesuKngk	:= NULL; END IF;		-- 利金支払手数料金額合計
		END LOOP;
		-- 会計別合計（基金、手数料）を設定
		--IF recPrevMeisai.KOUSAIHI_FLG = '1' THEN
		IF gokei.gKaikeiGokeiKkn + gokei.gKaikeiGokeiTesu = 0 THEN
			-- 公債費フラグが'1'の場合は出力しない
			gokei.gKaikeiGokeiKkn	:= NULL;
			gokei.gKaikeiGokeiTesu	:= NULL;
		--ELSE
			--gokei.gKaikeiGokeiKkn	:= gokei.gGankin + gokei.gRkn;
			--gokei.gKaikeiGokeiTesu	:= gokei.gGnknShrTesuKngk + gokei.gRknShrTesuKngk;
		END IF;
		-- 金額項目が0の場合はNULLを設定する
		--IF gokei.gGankinGokei		= 0 THEN gokei.gGankinGokei			:= NULL; END IF;		-- 元金総額合計
		--IF gokei.gRknGokei			= 0 THEN gokei.gRknGokei			:= NULL; END IF;		-- 利金総額合計
		--IF gokei.gGnknShrTesuGokei	= 0 THEN gokei.gGnknShrTesuGokei	:= NULL; END IF;		-- 元金支払手数料総額合計
		--IF gokei.gRknShrTesuGokei	= 0 THEN gokei.gRknShrTesuGokei		:= NULL; END IF;		-- 利金支払手数料総額合計
		--IF gokei.gGankin			= 0 THEN gokei.gGankin				:= NULL; END IF;		-- 元金合計
		--IF gokei.gRkn				= 0 THEN gokei.gRkn					:= NULL; END IF;		-- 利金合計
		--IF gokei.gGnknShrTesuKngk	= 0 THEN gokei.gGnknShrTesuKngk		:= NULL; END IF;		-- 元金支払手数料金額合計
		--IF gokei.gRknShrTesuKngk	= 0 THEN gokei.gRknShrTesuKngk		:= NULL; END IF;		-- 利金支払手数料金額合計
		--IF gokei.gKaikeiGokeiKkn	= 0 THEN gokei.gKaikeiGokeiKkn		:= NULL; END IF;		-- 会計別合計（基金）
		--IF gokei.gKaikeiGokeiTesu	= 0 THEN gokei.gKaikeiGokeiTesu		:= NULL; END IF;		-- 会計別合計（手数料）
		-- 帳票ワークへデータを追加
		gSeqNo := gSeqNo + 1;
				-- TYPE_SREPORT_WK_ITEM にパック
				l_inItem.l_inItem001 := l_inUserId;
				l_inItem.l_inItem002 := recPrevMeisai.HKT_CD;
				l_inItem.l_inItem003 := recPrevMeisai.HKT_RNM;
				l_inItem.l_inItem004 := recPrevMeisai.IDO_YMD;
				l_inItem.l_inItem005 := recPrevMeisai.ISIN_CD;
				l_inItem.l_inItem006 := gKousaihiFlg;
				l_inItem.l_inItem007 := recMeisai[0].gKokyakuMgrRnm || '/' || recMeisai[0].gRbrYmd;
				l_inItem.l_inItem008 := recMeisai[1].gKokyakuMgrRnm || '/' || recMeisai[1].gRbrYmd;
				l_inItem.l_inItem009 := recMeisai[2].gKokyakuMgrRnm || '/' || recMeisai[2].gRbrYmd;
				l_inItem.l_inItem010 := recMeisai[3].gKokyakuMgrRnm || '/' || recMeisai[3].gRbrYmd;
				l_inItem.l_inItem011 := recMeisai[4].gKokyakuMgrRnm || '/' || recMeisai[4].gRbrYmd;
				l_inItem.l_inItem012 := recMeisai[5].gKokyakuMgrRnm || '/' || recMeisai[5].gRbrYmd;
				l_inItem.l_inItem013 := recMeisai[6].gKokyakuMgrRnm || '/' || recMeisai[6].gRbrYmd;
				l_inItem.l_inItem014 := recMeisai[7].gKokyakuMgrRnm || '/' || recMeisai[7].gRbrYmd;
				l_inItem.l_inItem015 := recMeisai[8].gKokyakuMgrRnm || '/' || recMeisai[8].gRbrYmd;
				l_inItem.l_inItem016 := recMeisai[9].gKokyakuMgrRnm || '/' || recMeisai[9].gRbrYmd;
				l_inItem.l_inItem017 := recMeisai[10].gKokyakuMgrRnm || '/' || recMeisai[10].gRbrYmd;
				l_inItem.l_inItem018 := recMeisai[11].gKokyakuMgrRnm || '/' || recMeisai[11].gRbrYmd;
				l_inItem.l_inItem019 := recMeisai[12].gKokyakuMgrRnm || '/' || recMeisai[12].gRbrYmd;
				l_inItem.l_inItem020 := recMeisai[13].gKokyakuMgrRnm || '/' || recMeisai[13].gRbrYmd;
				l_inItem.l_inItem021 := recMeisai[14].gKokyakuMgrRnm || '/' || recMeisai[14].gRbrYmd;
				l_inItem.l_inItem022 := recMeisai[15].gKokyakuMgrRnm || '/' || recMeisai[15].gRbrYmd;
				l_inItem.l_inItem023 := recMeisai[16].gKokyakuMgrRnm || '/' || recMeisai[16].gRbrYmd;
				l_inItem.l_inItem024 := recMeisai[17].gKokyakuMgrRnm || '/' || recMeisai[17].gRbrYmd;
				l_inItem.l_inItem025 := recMeisai[18].gKokyakuMgrRnm || '/' || recMeisai[18].gRbrYmd;
				l_inItem.l_inItem026 := recMeisai[19].gKokyakuMgrRnm || '/' || recMeisai[19].gRbrYmd;
				l_inItem.l_inItem027 := recMeisai[20].gKokyakuMgrRnm || '/' || recMeisai[20].gRbrYmd;
				l_inItem.l_inItem028 := recMeisai[21].gKokyakuMgrRnm || '/' || recMeisai[21].gRbrYmd;
				l_inItem.l_inItem029 := recMeisai[22].gKokyakuMgrRnm || '/' || recMeisai[22].gRbrYmd;
				l_inItem.l_inItem030 := recMeisai[23].gKokyakuMgrRnm || '/' || recMeisai[23].gRbrYmd;
				l_inItem.l_inItem031 := recMeisai[24].gKokyakuMgrRnm || '/' || recMeisai[24].gRbrYmd;
				l_inItem.l_inItem032 := recMeisai[25].gKokyakuMgrRnm || '/' || recMeisai[25].gRbrYmd;
				l_inItem.l_inItem037 := recPrevMeisai.KKN_IDO_KBN;
				l_inItem.l_inItem033 := recMeisai[0].gGankinGokei || '/' || recMeisai[0].gRknGokei;
				l_inItem.l_inItem034 := recMeisai[1].gGankinGokei || '/' || recMeisai[1].gRknGokei;
				l_inItem.l_inItem035 := recMeisai[2].gGankinGokei || '/' || recMeisai[2].gRknGokei;
				l_inItem.l_inItem036 := recMeisai[3].gGankinGokei || '/' || recMeisai[3].gRknGokei;
				l_inItem.l_inItem037 := recMeisai[4].gGankinGokei || '/' || recMeisai[4].gRknGokei;
				l_inItem.l_inItem038 := recMeisai[5].gGankinGokei || '/' || recMeisai[5].gRknGokei;
				l_inItem.l_inItem039 := recMeisai[6].gGankinGokei || '/' || recMeisai[6].gRknGokei;
				l_inItem.l_inItem040 := recMeisai[7].gGankinGokei || '/' || recMeisai[7].gRknGokei;
				l_inItem.l_inItem041 := recMeisai[8].gGankinGokei || '/' || recMeisai[8].gRknGokei;
				l_inItem.l_inItem042 := recMeisai[9].gGankinGokei || '/' || recMeisai[9].gRknGokei;
				l_inItem.l_inItem043 := recMeisai[10].gGankinGokei || '/' || recMeisai[10].gRknGokei;
				l_inItem.l_inItem044 := recMeisai[11].gGankinGokei || '/' || recMeisai[11].gRknGokei;
				l_inItem.l_inItem045 := recMeisai[12].gGankinGokei || '/' || recMeisai[12].gRknGokei;
				l_inItem.l_inItem046 := recMeisai[13].gGankinGokei || '/' || recMeisai[13].gRknGokei;
				l_inItem.l_inItem047 := recMeisai[14].gGankinGokei || '/' || recMeisai[14].gRknGokei;
				l_inItem.l_inItem048 := recMeisai[15].gGankinGokei || '/' || recMeisai[15].gRknGokei;
				l_inItem.l_inItem049 := recMeisai[16].gGankinGokei || '/' || recMeisai[16].gRknGokei;
				l_inItem.l_inItem050 := recMeisai[17].gGankinGokei || '/' || recMeisai[17].gRknGokei;
				l_inItem.l_inItem051 := recMeisai[18].gGankinGokei || '/' || recMeisai[18].gRknGokei;
				l_inItem.l_inItem052 := recMeisai[19].gGankinGokei || '/' || recMeisai[19].gRknGokei;
				l_inItem.l_inItem053 := recMeisai[20].gGankinGokei || '/' || recMeisai[20].gRknGokei;
				l_inItem.l_inItem054 := recMeisai[21].gGankinGokei || '/' || recMeisai[21].gRknGokei;
				l_inItem.l_inItem055 := recMeisai[22].gGankinGokei || '/' || recMeisai[22].gRknGokei;
				l_inItem.l_inItem056 := recMeisai[23].gGankinGokei || '/' || recMeisai[23].gRknGokei;
				l_inItem.l_inItem057 := recMeisai[24].gGankinGokei || '/' || recMeisai[24].gRknGokei;
				l_inItem.l_inItem058 := recMeisai[25].gGankinGokei || '/' || recMeisai[25].gRknGokei;
				l_inItem.l_inItem059 := gokei.gGankinGokei;
				l_inItem.l_inItem060 := gokei.gRknGokei;
				l_inItem.l_inItem061 := recMeisai[0].gGnknShrTesuGokei || '/' || recMeisai[0].gRknShrTesuGokei;
				l_inItem.l_inItem062 := recMeisai[1].gGnknShrTesuGokei || '/' || recMeisai[1].gRknShrTesuGokei;
				l_inItem.l_inItem063 := recMeisai[2].gGnknShrTesuGokei || '/' || recMeisai[2].gRknShrTesuGokei;
				l_inItem.l_inItem064 := recMeisai[3].gGnknShrTesuGokei || '/' || recMeisai[3].gRknShrTesuGokei;
				l_inItem.l_inItem065 := recMeisai[4].gGnknShrTesuGokei || '/' || recMeisai[4].gRknShrTesuGokei;
				l_inItem.l_inItem066 := recMeisai[5].gGnknShrTesuGokei || '/' || recMeisai[5].gRknShrTesuGokei;
				l_inItem.l_inItem067 := recMeisai[6].gGnknShrTesuGokei || '/' || recMeisai[6].gRknShrTesuGokei;
				l_inItem.l_inItem068 := recMeisai[7].gGnknShrTesuGokei || '/' || recMeisai[7].gRknShrTesuGokei;
				l_inItem.l_inItem069 := recMeisai[8].gGnknShrTesuGokei || '/' || recMeisai[8].gRknShrTesuGokei;
				l_inItem.l_inItem070 := recMeisai[9].gGnknShrTesuGokei || '/' || recMeisai[9].gRknShrTesuGokei;
				l_inItem.l_inItem071 := recMeisai[10].gGnknShrTesuGokei || '/' || recMeisai[10].gRknShrTesuGokei;
				l_inItem.l_inItem072 := recMeisai[11].gGnknShrTesuGokei || '/' || recMeisai[11].gRknShrTesuGokei;
				l_inItem.l_inItem073 := recMeisai[12].gGnknShrTesuGokei || '/' || recMeisai[12].gRknShrTesuGokei;
				l_inItem.l_inItem074 := recMeisai[13].gGnknShrTesuGokei || '/' || recMeisai[13].gRknShrTesuGokei;
				l_inItem.l_inItem075 := recMeisai[14].gGnknShrTesuGokei || '/' || recMeisai[14].gRknShrTesuGokei;
				l_inItem.l_inItem076 := recMeisai[15].gGnknShrTesuGokei || '/' || recMeisai[15].gRknShrTesuGokei;
				l_inItem.l_inItem077 := recMeisai[16].gGnknShrTesuGokei || '/' || recMeisai[16].gRknShrTesuGokei;
				l_inItem.l_inItem078 := recMeisai[17].gGnknShrTesuGokei || '/' || recMeisai[17].gRknShrTesuGokei;
				l_inItem.l_inItem079 := recMeisai[18].gGnknShrTesuGokei || '/' || recMeisai[18].gRknShrTesuGokei;
				l_inItem.l_inItem080 := recMeisai[19].gGnknShrTesuGokei || '/' || recMeisai[19].gRknShrTesuGokei;
				l_inItem.l_inItem081 := recMeisai[20].gGnknShrTesuGokei || '/' || recMeisai[20].gRknShrTesuGokei;
				l_inItem.l_inItem082 := recMeisai[21].gGnknShrTesuGokei || '/' || recMeisai[21].gRknShrTesuGokei;
				l_inItem.l_inItem083 := recMeisai[22].gGnknShrTesuGokei || '/' || recMeisai[22].gRknShrTesuGokei;
				l_inItem.l_inItem084 := recMeisai[23].gGnknShrTesuGokei || '/' || recMeisai[23].gRknShrTesuGokei;
				l_inItem.l_inItem085 := recMeisai[24].gGnknShrTesuGokei || '/' || recMeisai[24].gRknShrTesuGokei;
				l_inItem.l_inItem086 := recMeisai[25].gGnknShrTesuGokei || '/' || recMeisai[25].gRknShrTesuGokei;
				l_inItem.l_inItem087 := gokei.gGnknShrTesuGokei;
				l_inItem.l_inItem088 := gokei.gRknShrTesuGokei;
				l_inItem.l_inItem089 := gPageNum;
				l_inItem.l_inItem090 := recPrevMeisai.KAIKEI_KBN;
				l_inItem.l_inItem091 := recPrevMeisai.KAIKEI_KBN_RNM;
				l_inItem.l_inItem092 := recMeisai[0].gGankin || '/' || recMeisai[0].gRkn;
				l_inItem.l_inItem093 := recMeisai[1].gGankin || '/' || recMeisai[1].gRkn;
				l_inItem.l_inItem094 := recMeisai[2].gGankin || '/' || recMeisai[2].gRkn;
				l_inItem.l_inItem095 := recMeisai[3].gGankin || '/' || recMeisai[3].gRkn;
				l_inItem.l_inItem096 := recMeisai[4].gGankin || '/' || recMeisai[4].gRkn;
				l_inItem.l_inItem097 := recMeisai[5].gGankin || '/' || recMeisai[5].gRkn;
				l_inItem.l_inItem098 := recMeisai[6].gGankin || '/' || recMeisai[6].gRkn;
				l_inItem.l_inItem099 := recMeisai[7].gGankin || '/' || recMeisai[7].gRkn;
				l_inItem.l_inItem100 := recMeisai[8].gGankin || '/' || recMeisai[8].gRkn;
				l_inItem.l_inItem101 := recMeisai[9].gGankin || '/' || recMeisai[9].gRkn;
				l_inItem.l_inItem102 := recMeisai[10].gGankin || '/' || recMeisai[10].gRkn;
				l_inItem.l_inItem103 := recMeisai[11].gGankin || '/' || recMeisai[11].gRkn;
				l_inItem.l_inItem104 := recMeisai[12].gGankin || '/' || recMeisai[12].gRkn;
				l_inItem.l_inItem105 := recMeisai[13].gGankin || '/' || recMeisai[13].gRkn;
				l_inItem.l_inItem106 := recMeisai[14].gGankin || '/' || recMeisai[14].gRkn;
				l_inItem.l_inItem107 := recMeisai[15].gGankin || '/' || recMeisai[15].gRkn;
				l_inItem.l_inItem108 := recMeisai[16].gGankin || '/' || recMeisai[16].gRkn;
				l_inItem.l_inItem109 := recMeisai[17].gGankin || '/' || recMeisai[17].gRkn;
				l_inItem.l_inItem110 := recMeisai[18].gGankin || '/' || recMeisai[18].gRkn;
				l_inItem.l_inItem111 := recMeisai[19].gGankin || '/' || recMeisai[19].gRkn;
				l_inItem.l_inItem112 := recMeisai[20].gGankin || '/' || recMeisai[20].gRkn;
				l_inItem.l_inItem113 := recMeisai[21].gGankin || '/' || recMeisai[21].gRkn;
				l_inItem.l_inItem114 := recMeisai[22].gGankin || '/' || recMeisai[22].gRkn;
				l_inItem.l_inItem115 := recMeisai[23].gGankin || '/' || recMeisai[23].gRkn;
				l_inItem.l_inItem116 := recMeisai[24].gGankin || '/' || recMeisai[24].gRkn;
				l_inItem.l_inItem117 := recMeisai[25].gGankin || '/' || recMeisai[25].gRkn;
				l_inItem.l_inItem118 := gokei.gGankin;
				l_inItem.l_inItem119 := gokei.gRkn;
				l_inItem.l_inItem120 := recMeisai[0].gGnknShrTesuKngk || '/' || recMeisai[0].gRknShrTesuKngk;
				l_inItem.l_inItem121 := recMeisai[1].gGnknShrTesuKngk || '/' || recMeisai[1].gRknShrTesuKngk;
				l_inItem.l_inItem122 := recMeisai[2].gGnknShrTesuKngk || '/' || recMeisai[2].gRknShrTesuKngk;
				l_inItem.l_inItem123 := recMeisai[3].gGnknShrTesuKngk || '/' || recMeisai[3].gRknShrTesuKngk;
				l_inItem.l_inItem124 := recMeisai[4].gGnknShrTesuKngk || '/' || recMeisai[4].gRknShrTesuKngk;
				l_inItem.l_inItem125 := recMeisai[5].gGnknShrTesuKngk || '/' || recMeisai[5].gRknShrTesuKngk;
				l_inItem.l_inItem126 := recMeisai[6].gGnknShrTesuKngk || '/' || recMeisai[6].gRknShrTesuKngk;
				l_inItem.l_inItem127 := recMeisai[7].gGnknShrTesuKngk || '/' || recMeisai[7].gRknShrTesuKngk;
				l_inItem.l_inItem128 := recMeisai[8].gGnknShrTesuKngk || '/' || recMeisai[8].gRknShrTesuKngk;
				l_inItem.l_inItem129 := recMeisai[9].gGnknShrTesuKngk || '/' || recMeisai[9].gRknShrTesuKngk;
				l_inItem.l_inItem130 := recMeisai[10].gGnknShrTesuKngk || '/' || recMeisai[10].gRknShrTesuKngk;
				l_inItem.l_inItem131 := recMeisai[11].gGnknShrTesuKngk || '/' || recMeisai[11].gRknShrTesuKngk;
				l_inItem.l_inItem132 := recMeisai[12].gGnknShrTesuKngk || '/' || recMeisai[12].gRknShrTesuKngk;
				l_inItem.l_inItem133 := recMeisai[13].gGnknShrTesuKngk || '/' || recMeisai[13].gRknShrTesuKngk;
				l_inItem.l_inItem134 := recMeisai[14].gGnknShrTesuKngk || '/' || recMeisai[14].gRknShrTesuKngk;
				l_inItem.l_inItem135 := recMeisai[15].gGnknShrTesuKngk || '/' || recMeisai[15].gRknShrTesuKngk;
				l_inItem.l_inItem136 := recMeisai[16].gGnknShrTesuKngk || '/' || recMeisai[16].gRknShrTesuKngk;
				l_inItem.l_inItem137 := recMeisai[17].gGnknShrTesuKngk || '/' || recMeisai[17].gRknShrTesuKngk;
				l_inItem.l_inItem138 := recMeisai[18].gGnknShrTesuKngk || '/' || recMeisai[18].gRknShrTesuKngk;
				l_inItem.l_inItem139 := recMeisai[19].gGnknShrTesuKngk || '/' || recMeisai[19].gRknShrTesuKngk;
				l_inItem.l_inItem140 := recMeisai[20].gGnknShrTesuKngk || '/' || recMeisai[20].gRknShrTesuKngk;
				l_inItem.l_inItem141 := recMeisai[21].gGnknShrTesuKngk || '/' || recMeisai[21].gRknShrTesuKngk;
				l_inItem.l_inItem142 := recMeisai[22].gGnknShrTesuKngk || '/' || recMeisai[22].gRknShrTesuKngk;
				l_inItem.l_inItem143 := recMeisai[23].gGnknShrTesuKngk || '/' || recMeisai[23].gRknShrTesuKngk;
				l_inItem.l_inItem144 := recMeisai[24].gGnknShrTesuKngk || '/' || recMeisai[24].gRknShrTesuKngk;
				l_inItem.l_inItem145 := recMeisai[25].gGnknShrTesuKngk || '/' || recMeisai[25].gRknShrTesuKngk;
				l_inItem.l_inItem146 := gokei.gGnknShrTesuKngk;
				l_inItem.l_inItem147 := gokei.gRknShrTesuKngk;
				l_inItem.l_inItem148 := gokei.gKaikeiGokeiKkn;
				l_inItem.l_inItem149 := gokei.gKaikeiGokeiTesu;
				l_inItem.l_inItem150 := REPORT_ID;
				l_inItem.l_inItem151 := FMT_HAKKO_KNGK_J;
				l_inItem.l_inItem152 := FMT_RBR_KNGK_J;
				l_inItem.l_inItem153 := FMT_SHOKAN_KNGK_J;
				l_inItem.l_inItem154 := recMeisai[0].gKousaihiFlg;
				l_inItem.l_inItem155 := recMeisai[1].gKousaihiFlg;
				l_inItem.l_inItem156 := recMeisai[2].gKousaihiFlg;
				l_inItem.l_inItem157 := recMeisai[3].gKousaihiFlg;
				l_inItem.l_inItem158 := recMeisai[4].gKousaihiFlg;
				l_inItem.l_inItem159 := recMeisai[5].gKousaihiFlg;
				l_inItem.l_inItem160 := recMeisai[6].gKousaihiFlg;
				l_inItem.l_inItem161 := recMeisai[7].gKousaihiFlg;
				l_inItem.l_inItem162 := recMeisai[8].gKousaihiFlg;
				l_inItem.l_inItem163 := recMeisai[9].gKousaihiFlg;
				l_inItem.l_inItem164 := recMeisai[10].gKousaihiFlg;
				l_inItem.l_inItem165 := recMeisai[11].gKousaihiFlg;
				l_inItem.l_inItem166 := recMeisai[12].gKousaihiFlg;
				l_inItem.l_inItem167 := recMeisai[13].gKousaihiFlg;
				l_inItem.l_inItem168 := recMeisai[14].gKousaihiFlg;
				l_inItem.l_inItem169 := recMeisai[15].gKousaihiFlg;
				l_inItem.l_inItem170 := recMeisai[16].gKousaihiFlg;
				l_inItem.l_inItem171 := recMeisai[17].gKousaihiFlg;
				l_inItem.l_inItem172 := recMeisai[18].gKousaihiFlg;
				l_inItem.l_inItem173 := recMeisai[19].gKousaihiFlg;
				l_inItem.l_inItem174 := recMeisai[20].gKousaihiFlg;
				l_inItem.l_inItem175 := recMeisai[21].gKousaihiFlg;
				l_inItem.l_inItem176 := recMeisai[22].gKousaihiFlg;
				l_inItem.l_inItem177 := recMeisai[23].gKousaihiFlg;
				l_inItem.l_inItem178 := recMeisai[24].gKousaihiFlg;
				l_inItem.l_inItem179 := recMeisai[25].gKousaihiFlg;
				l_inItem.l_inItem181 := recPrevMeisai.Kousai_Taisho_Flg;
				l_inItem.l_inItem182 := recMeisai[0].gIsinCd;
				l_inItem.l_inItem183 := recMeisai[1].gIsinCd;
				l_inItem.l_inItem184 := recMeisai[2].gIsinCd;
				l_inItem.l_inItem185 := recMeisai[3].gIsinCd;
				l_inItem.l_inItem186 := recMeisai[4].gIsinCd;
				l_inItem.l_inItem187 := recMeisai[5].gIsinCd;
				l_inItem.l_inItem188 := recMeisai[6].gIsinCd;
				l_inItem.l_inItem189 := recMeisai[7].gIsinCd;
				l_inItem.l_inItem190 := recMeisai[8].gIsinCd;
				l_inItem.l_inItem191 := recMeisai[9].gIsinCd;
				l_inItem.l_inItem192 := recMeisai[10].gIsinCd;
				l_inItem.l_inItem193 := recMeisai[11].gIsinCd;
				l_inItem.l_inItem194 := recMeisai[12].gIsinCd;
				l_inItem.l_inItem195 := recMeisai[13].gIsinCd;
				l_inItem.l_inItem196 := recMeisai[14].gIsinCd;
				l_inItem.l_inItem197 := recMeisai[15].gIsinCd;
				l_inItem.l_inItem198 := recMeisai[16].gIsinCd;
				l_inItem.l_inItem199 := recMeisai[17].gIsinCd;
				l_inItem.l_inItem200 := recMeisai[18].gIsinCd;
				l_inItem.l_inItem201 := recMeisai[19].gIsinCd;
				l_inItem.l_inItem202 := recMeisai[20].gIsinCd;
				l_inItem.l_inItem203 := recMeisai[21].gIsinCd;
				l_inItem.l_inItem204 := recMeisai[22].gIsinCd;
				l_inItem.l_inItem205 := recMeisai[23].gIsinCd;
				l_inItem.l_inItem206 := recMeisai[24].gIsinCd;
				l_inItem.l_inItem207 := recMeisai[25].gIsinCd;
				l_inItem.l_inItem208 := gChikoList;
				CALL pkPrint.insertData(
					l_inKeyCd      => l_inItakuKaishaCd,
					l_inUserId     => l_inUserId,
					l_inChohyoKbn  => l_inChohyoKbn,
					l_inSakuseiYmd => l_inGyomuYmd,
					l_inChohyoId   => REPORT_ID,
					l_inSeqNo      => gSeqNo,
					l_inHeaderFlg  => '1',
					l_inItem       => l_inItem,
					l_inKousinId   => l_inUserId,
					l_inSakuseiId  => l_inUserId
				);
		UPDATE SREPORT_WK
		SET ITEM007 =  CASE WHEN recMeisai[0].gKokyakuMgrRnm || recMeisai[0].gRbrYmd = NULL THEN ITEM007  ELSE recMeisai[0].gKokyakuMgrRnm || '/' || recMeisai[0].gRbrYmd END
			,ITEM008 = CASE WHEN recMeisai[1].gKokyakuMgrRnm || recMeisai[1].gRbrYmd = NULL THEN ITEM008  ELSE recMeisai[1].gKokyakuMgrRnm || '/' || recMeisai[1].gRbrYmd END 
			,ITEM009 = CASE WHEN recMeisai[2].gKokyakuMgrRnm || recMeisai[2].gRbrYmd = NULL THEN ITEM009  ELSE recMeisai[2].gKokyakuMgrRnm || '/' || recMeisai[2].gRbrYmd END 
			,ITEM010 = CASE WHEN recMeisai[3].gKokyakuMgrRnm || recMeisai[3].gRbrYmd = NULL THEN ITEM010  ELSE recMeisai[3].gKokyakuMgrRnm || '/' || recMeisai[3].gRbrYmd END 
			,ITEM011 = CASE WHEN recMeisai[4].gKokyakuMgrRnm || recMeisai[4].gRbrYmd = NULL THEN ITEM011  ELSE recMeisai[4].gKokyakuMgrRnm || '/' || recMeisai[4].gRbrYmd END 
			,ITEM012 = CASE WHEN recMeisai[5].gKokyakuMgrRnm || recMeisai[5].gRbrYmd = NULL THEN ITEM012  ELSE recMeisai[5].gKokyakuMgrRnm || '/' || recMeisai[5].gRbrYmd END 
			,ITEM013 = CASE WHEN recMeisai[6].gKokyakuMgrRnm || recMeisai[6].gRbrYmd = NULL THEN ITEM013  ELSE recMeisai[6].gKokyakuMgrRnm || '/' || recMeisai[6].gRbrYmd END 
			,ITEM014 = CASE WHEN recMeisai[7].gKokyakuMgrRnm || recMeisai[7].gRbrYmd = NULL THEN ITEM014  ELSE recMeisai[7].gKokyakuMgrRnm || '/' || recMeisai[7].gRbrYmd END 
			,ITEM015 = CASE WHEN recMeisai[8].gKokyakuMgrRnm || recMeisai[8].gRbrYmd = NULL THEN ITEM015  ELSE recMeisai[8].gKokyakuMgrRnm || '/' || recMeisai[8].gRbrYmd END 
			,ITEM016 = CASE WHEN recMeisai[9].gKokyakuMgrRnm || recMeisai[9].gRbrYmd = NULL THEN ITEM016  ELSE recMeisai[9].gKokyakuMgrRnm || '/' || recMeisai[9].gRbrYmd END 
			,ITEM017 = CASE WHEN recMeisai[10].gKokyakuMgrRnm || recMeisai[10].gRbrYmd = NULL THEN ITEM017  ELSE recMeisai[10].gKokyakuMgrRnm || '/' || recMeisai[10].gRbrYmd END 
			,ITEM018 = CASE WHEN recMeisai[11].gKokyakuMgrRnm || recMeisai[11].gRbrYmd = NULL THEN ITEM018  ELSE recMeisai[11].gKokyakuMgrRnm || '/' || recMeisai[11].gRbrYmd END 
			,ITEM019 = CASE WHEN recMeisai[12].gKokyakuMgrRnm || recMeisai[12].gRbrYmd = NULL THEN ITEM019  ELSE recMeisai[12].gKokyakuMgrRnm || '/' || recMeisai[12].gRbrYmd END 
			,ITEM020 = CASE WHEN recMeisai[13].gKokyakuMgrRnm || recMeisai[13].gRbrYmd = NULL THEN ITEM020  ELSE recMeisai[13].gKokyakuMgrRnm || '/' || recMeisai[13].gRbrYmd END 
			,ITEM021 = CASE WHEN recMeisai[14].gKokyakuMgrRnm || recMeisai[14].gRbrYmd = NULL THEN ITEM021  ELSE recMeisai[14].gKokyakuMgrRnm || '/' || recMeisai[14].gRbrYmd END 
			,ITEM022 = CASE WHEN recMeisai[15].gKokyakuMgrRnm || recMeisai[15].gRbrYmd = NULL THEN ITEM022  ELSE recMeisai[15].gKokyakuMgrRnm || '/' || recMeisai[15].gRbrYmd END 
			,ITEM023 = CASE WHEN recMeisai[16].gKokyakuMgrRnm || recMeisai[16].gRbrYmd = NULL THEN ITEM023  ELSE recMeisai[16].gKokyakuMgrRnm || '/' || recMeisai[16].gRbrYmd END 
			,ITEM024 = CASE WHEN recMeisai[17].gKokyakuMgrRnm || recMeisai[17].gRbrYmd = NULL THEN ITEM024  ELSE recMeisai[17].gKokyakuMgrRnm || '/' || recMeisai[17].gRbrYmd END 
			,ITEM025 = CASE WHEN recMeisai[18].gKokyakuMgrRnm || recMeisai[18].gRbrYmd = NULL THEN ITEM025  ELSE recMeisai[18].gKokyakuMgrRnm || '/' || recMeisai[18].gRbrYmd END 
			,ITEM026 = CASE WHEN recMeisai[19].gKokyakuMgrRnm || recMeisai[19].gRbrYmd = NULL THEN ITEM026  ELSE recMeisai[19].gKokyakuMgrRnm || '/' || recMeisai[19].gRbrYmd END 
			,ITEM027 = CASE WHEN recMeisai[20].gKokyakuMgrRnm || recMeisai[20].gRbrYmd = NULL THEN ITEM027  ELSE recMeisai[20].gKokyakuMgrRnm || '/' || recMeisai[20].gRbrYmd END 
			,ITEM028 = CASE WHEN recMeisai[21].gKokyakuMgrRnm || recMeisai[21].gRbrYmd = NULL THEN ITEM028  ELSE recMeisai[21].gKokyakuMgrRnm || '/' || recMeisai[21].gRbrYmd END 
			,ITEM029 = CASE WHEN recMeisai[22].gKokyakuMgrRnm || recMeisai[22].gRbrYmd = NULL THEN ITEM029  ELSE recMeisai[22].gKokyakuMgrRnm || '/' || recMeisai[22].gRbrYmd END 
			,ITEM030 = CASE WHEN recMeisai[23].gKokyakuMgrRnm || recMeisai[23].gRbrYmd = NULL THEN ITEM030  ELSE recMeisai[23].gKokyakuMgrRnm || '/' || recMeisai[23].gRbrYmd END 
			,ITEM031 = CASE WHEN recMeisai[24].gKokyakuMgrRnm || recMeisai[24].gRbrYmd = NULL THEN ITEM031  ELSE recMeisai[24].gKokyakuMgrRnm || '/' || recMeisai[24].gRbrYmd END 
			,ITEM032 = CASE WHEN recMeisai[25].gKokyakuMgrRnm || recMeisai[25].gRbrYmd = NULL THEN ITEM032  ELSE recMeisai[25].gKokyakuMgrRnm || '/' || recMeisai[25].gRbrYmd END 
			,ITEM182 = recMeisai[0].gIsinCd 				-- ISINCD１
			,ITEM183 = recMeisai[1].gIsinCd 				-- ISINCD２
			,ITEM184 = recMeisai[2].gIsinCd 				-- ISINCD３
			,ITEM185 = recMeisai[3].gIsinCd 				-- ISINCD４
			,ITEM186 = recMeisai[4].gIsinCd 				-- ISINCD５
			,ITEM187 = recMeisai[5].gIsinCd 				-- ISINCD６
			,ITEM188 = recMeisai[6].gIsinCd 				-- ISINCD７
			,ITEM189 = recMeisai[7].gIsinCd 				-- ISINCD８
			,ITEM190 = recMeisai[8].gIsinCd 				-- ISINCD９
			,ITEM191 = recMeisai[9].gIsinCd 				-- ISINCD１０
			,ITEM192 = recMeisai[10].gIsinCd 				-- ISINCD１１
			,ITEM193 = recMeisai[11].gIsinCd 				-- ISINCD１２
			,ITEM194 = recMeisai[12].gIsinCd 				-- ISINCD１３
			,ITEM195 = recMeisai[13].gIsinCd 				-- ISINCD１４
			,ITEM196 = recMeisai[14].gIsinCd 				-- ISINCD１５
			,ITEM197 = recMeisai[15].gIsinCd 				-- ISINCD１６
			,ITEM198 = recMeisai[16].gIsinCd 				-- ISINCD１７
			,ITEM199 = recMeisai[17].gIsinCd 				-- ISINCD１８
			,ITEM200 = recMeisai[18].gIsinCd 				-- ISINCD１９
			,ITEM201 = recMeisai[19].gIsinCd 				-- ISINCD２０
			,ITEM202 = recMeisai[20].gIsinCd 				-- ISINCD２１
			,ITEM203 = recMeisai[21].gIsinCd 				-- ISINCD２２
			,ITEM204 = recMeisai[22].gIsinCd 				-- ISINCD２３
			,ITEM205 = recMeisai[23].gIsinCd 				-- ISINCD２４
			,ITEM206 = recMeisai[24].gIsinCd 				-- ISINCD２５
			,ITEM207 = recMeisai[25].gIsinCd 				-- ISINCD２６
			,ITEM208 = gChikoList 							-- ChikoList
		WHERE	KEY_CD = l_inItakuKaishaCd
		AND		USER_ID = l_inUserId
		AND		CHOHYO_KBN = l_inChohyoKbn
		AND		SAKUSEI_YMD = l_inGyomuYmd
		AND		CHOHYO_ID = REPORT_ID
		AND		ITEM002 = recPrevMeisai.HKT_CD
		AND		ITEM004 = recPrevMeisai.IDO_YMD
		AND		ITEM181 = recPrevMeisai.Kousai_Taisho_Flg
		AND		HEADER_FLG != 0;
	END IF;
	-- 対象データなし以外の場合、銘柄のソート順を修正
	IF gRtnCd != RTN_NODATA THEN
		-- 対象レコード取得
		FOR recS IN curSort LOOP
			-- 初期化
			IF gSCnt != 0 THEN
				FOR a IN 0..MGR_MAX_CNT - 1 LOOP
					recSMeisai[a].gIsin := NULL;
					recSMeisai[a].gWkMgr := NULL;
					recSMeisai[a].gWkGrTotal := NULL;
					recSMeisai[a].gWkGrTes := NULL;
					recSMeisai[a].gWkGr := NULL;
					recSMeisai[a].gWkGTes := NULL;
					recSMeisai[a].gWkKFlg := NULL;
			 	END LOOP;
			END IF;
			gSCnt := 0;
			-- 1レコードの銘柄毎の情報を銘柄順に取得
			FOR recSM IN curSortMeisai(recS.SEQ_NO) LOOP
				recSMeisai[gSCnt].gIsin := recSM.ISIN;
				recSMeisai[gSCnt].gWkMgr := recSM.WKMGR;
				recSMeisai[gSCnt].gWkGrTotal := recSM.WKGRTOTAL;
				recSMeisai[gSCnt].gWkGrTes := recSM.WKGRTES;
				recSMeisai[gSCnt].gWkGr := recSM.WKGR;
				recSMeisai[gSCnt].gWkGTes := recSM.WKGTES;
				recSMeisai[gSCnt].gWkKFlg := recSM.WKKFLG;
				gSCnt := gSCnt + 1;
			END LOOP;
			-- UPDATE
			UPDATE SREPORT_WK
			SET  ITEM007 = recSMeisai[0].gWkMgr	,ITEM008 = recSMeisai[1].gWkMgr	,ITEM009 = recSMeisai[2].gWkMgr	,ITEM010 = recSMeisai[3].gWkMgr
				,ITEM011 = recSMeisai[4].gWkMgr	,ITEM012 = recSMeisai[5].gWkMgr	,ITEM013 = recSMeisai[6].gWkMgr	,ITEM014 = recSMeisai[7].gWkMgr
				,ITEM015 = recSMeisai[8].gWkMgr	,ITEM016 = recSMeisai[9].gWkMgr	,ITEM017 = recSMeisai[10].gWkMgr,ITEM018 = recSMeisai[11].gWkMgr
				,ITEM019 = recSMeisai[12].gWkMgr,ITEM020 = recSMeisai[13].gWkMgr,ITEM021 = recSMeisai[14].gWkMgr,ITEM022 = recSMeisai[15].gWkMgr
				,ITEM023 = recSMeisai[16].gWkMgr,ITEM024 = recSMeisai[17].gWkMgr,ITEM025 = recSMeisai[18].gWkMgr,ITEM026 = recSMeisai[19].gWkMgr
				,ITEM027 = recSMeisai[20].gWkMgr,ITEM028 = recSMeisai[21].gWkMgr,ITEM029 = recSMeisai[22].gWkMgr,ITEM030 = recSMeisai[23].gWkMgr
				,ITEM031 = recSMeisai[24].gWkMgr,ITEM032 = recSMeisai[25].gWkMgr
				,ITEM033 = recSMeisai[0].gWkGrTotal ,ITEM034 = recSMeisai[1].gWkGrTotal ,ITEM035 = recSMeisai[2].gWkGrTotal	,ITEM036 = recSMeisai[3].gWkGrTotal
				,ITEM037 = recSMeisai[4].gWkGrTotal ,ITEM038 = recSMeisai[5].gWkGrTotal	,ITEM039 = recSMeisai[6].gWkGrTotal	,ITEM040 = recSMeisai[7].gWkGrTotal
				,ITEM041 = recSMeisai[8].gWkGrTotal	,ITEM042 = recSMeisai[9].gWkGrTotal	,ITEM043 = recSMeisai[10].gWkGrTotal,ITEM044 = recSMeisai[11].gWkGrTotal
				,ITEM045 = recSMeisai[12].gWkGrTotal,ITEM046 = recSMeisai[13].gWkGrTotal,ITEM047 = recSMeisai[14].gWkGrTotal,ITEM048 = recSMeisai[15].gWkGrTotal
				,ITEM049 = recSMeisai[16].gWkGrTotal,ITEM050 = recSMeisai[17].gWkGrTotal,ITEM051 = recSMeisai[18].gWkGrTotal,ITEM052 = recSMeisai[19].gWkGrTotal
				,ITEM053 = recSMeisai[20].gWkGrTotal,ITEM054 = recSMeisai[21].gWkGrTotal,ITEM055 = recSMeisai[22].gWkGrTotal,ITEM056 = recSMeisai[23].gWkGrTotal
				,ITEM057 = recSMeisai[24].gWkGrTotal,ITEM058 = recSMeisai[25].gWkGrTotal
				,ITEM061 = recSMeisai[0].gWkGrTes,ITEM062 = recSMeisai[1].gWkGrTes,ITEM063 = recSMeisai[2].gWkGrTes,ITEM064 = recSMeisai[3].gWkGrTes
				,ITEM065 = recSMeisai[4].gWkGrTes,ITEM066 = recSMeisai[5].gWkGrTes,ITEM067 = recSMeisai[6].gWkGrTes,ITEM068 = recSMeisai[7].gWkGrTes
				,ITEM069 = recSMeisai[8].gWkGrTes,ITEM070 = recSMeisai[9].gWkGrTes,ITEM071 = recSMeisai[10].gWkGrTes,ITEM072 = recSMeisai[11].gWkGrTes
				,ITEM073 = recSMeisai[12].gWkGrTes,ITEM074 = recSMeisai[13].gWkGrTes,ITEM075 = recSMeisai[14].gWkGrTes,ITEM076 = recSMeisai[15].gWkGrTes
				,ITEM077 = recSMeisai[16].gWkGrTes,ITEM078 = recSMeisai[17].gWkGrTes,ITEM079 = recSMeisai[18].gWkGrTes,ITEM080 = recSMeisai[19].gWkGrTes
				,ITEM081 = recSMeisai[20].gWkGrTes,ITEM082 = recSMeisai[21].gWkGrTes,ITEM083 = recSMeisai[22].gWkGrTes,ITEM084 = recSMeisai[23].gWkGrTes
				,ITEM085 = recSMeisai[24].gWkGrTes,ITEM086 = recSMeisai[25].gWkGrTes
				,ITEM092 = recSMeisai[0].gWkGr,ITEM093 = recSMeisai[1].gWkGr,ITEM094 = recSMeisai[2].gWkGr,ITEM095 = recSMeisai[3].gWkGr
				,ITEM096 = recSMeisai[4].gWkGr,ITEM097 = recSMeisai[5].gWkGr,ITEM098 = recSMeisai[6].gWkGr,ITEM099 = recSMeisai[7].gWkGr
				,ITEM100 = recSMeisai[8].gWkGr,ITEM101 = recSMeisai[9].gWkGr,ITEM102 = recSMeisai[10].gWkGr,ITEM103 = recSMeisai[11].gWkGr
				,ITEM104 = recSMeisai[12].gWkGr,ITEM105 = recSMeisai[13].gWkGr,ITEM106 = recSMeisai[14].gWkGr,ITEM107 = recSMeisai[15].gWkGr
				,ITEM108 = recSMeisai[16].gWkGr,ITEM109 = recSMeisai[17].gWkGr,ITEM110 = recSMeisai[18].gWkGr,ITEM111 = recSMeisai[19].gWkGr
				,ITEM112 = recSMeisai[20].gWkGr,ITEM113 = recSMeisai[21].gWkGr,ITEM114 = recSMeisai[22].gWkGr,ITEM115 = recSMeisai[23].gWkGr
				,ITEM116 = recSMeisai[24].gWkGr,ITEM117 = recSMeisai[25].gWkGr
				,ITEM120 = recSMeisai[0].gWkGTes,ITEM121 = recSMeisai[1].gWkGTes,ITEM122 = recSMeisai[2].gWkGTes,ITEM123 = recSMeisai[3].gWkGTes
				,ITEM124 = recSMeisai[4].gWkGTes,ITEM125 = recSMeisai[5].gWkGTes,ITEM126 = recSMeisai[6].gWkGTes,ITEM127 = recSMeisai[7].gWkGTes
				,ITEM128 = recSMeisai[8].gWkGTes,ITEM129 = recSMeisai[9].gWkGTes,ITEM130 = recSMeisai[10].gWkGTes,ITEM131 = recSMeisai[11].gWkGTes
				,ITEM132 = recSMeisai[12].gWkGTes,ITEM133 = recSMeisai[13].gWkGTes,ITEM134 = recSMeisai[14].gWkGTes,ITEM135 = recSMeisai[15].gWkGTes
				,ITEM136 = recSMeisai[16].gWkGTes,ITEM137 = recSMeisai[17].gWkGTes,ITEM138 = recSMeisai[18].gWkGTes,ITEM139 = recSMeisai[19].gWkGTes
				,ITEM140 = recSMeisai[20].gWkGTes,ITEM141 = recSMeisai[21].gWkGTes,ITEM142 = recSMeisai[22].gWkGTes,ITEM143 = recSMeisai[23].gWkGTes
				,ITEM144 = recSMeisai[24].gWkGTes,ITEM145 = recSMeisai[25].gWkGTes
				,ITEM154 = recSMeisai[0].gWkKFlg,ITEM155 = recSMeisai[1].gWkKFlg,ITEM156 = recSMeisai[2].gWkKFlg,ITEM157 = recSMeisai[3].gWkKFlg
				,ITEM158 = recSMeisai[4].gWkKFlg,ITEM159 = recSMeisai[5].gWkKFlg,ITEM160 = recSMeisai[6].gWkKFlg,ITEM161 = recSMeisai[7].gWkKFlg
				,ITEM162 = recSMeisai[8].gWkKFlg,ITEM163 = recSMeisai[9].gWkKFlg,ITEM164 = recSMeisai[10].gWkKFlg,ITEM165 = recSMeisai[11].gWkKFlg
				,ITEM166 = recSMeisai[12].gWkKFlg,ITEM167 = recSMeisai[13].gWkKFlg,ITEM168 = recSMeisai[14].gWkKFlg,ITEM169 = recSMeisai[15].gWkKFlg
				,ITEM170 = recSMeisai[16].gWkKFlg,ITEM171 = recSMeisai[17].gWkKFlg,ITEM172 = recSMeisai[18].gWkKFlg,ITEM173 = recSMeisai[19].gWkKFlg
				,ITEM174 = recSMeisai[20].gWkKFlg,ITEM175 = recSMeisai[21].gWkKFlg,ITEM176 = recSMeisai[22].gWkKFlg,ITEM177 = recSMeisai[23].gWkKFlg
				,ITEM178 = recSMeisai[24].gWkKFlg,ITEM179 = recSMeisai[25].gWkKFlg
			WHERE KEY_CD = l_inItakuKaishaCd
		      AND USER_ID = l_inUserId
		      AND SAKUSEI_YMD = l_inGyomuYmd
		      AND CHOHYO_ID = REPORT_ID
		      AND SEQ_NO = recS.SEQ_NO;
		END LOOP;
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPH006K00R01 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
--		RAISE;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spiph006k00r01 ( l_inHktCd CHAR, l_inKozaTenCd CHAR, l_inKozaTenCifCd CHAR, l_inMgrCd CHAR, l_inIsinCd CHAR, l_inKijunYmdF CHAR, l_inKijunYmdT CHAR, l_inTsuchiYmd CHAR, l_inItakuKaishaCd CHAR, l_inUserId CHAR, l_inChohyoKbn CHAR, l_inGyomuYmd CHAR, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;