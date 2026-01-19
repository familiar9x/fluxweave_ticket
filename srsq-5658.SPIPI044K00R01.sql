drop procedure if exists spipi044k00r01_genbodatainsert ;
drop procedure if exists spipi044k00r01_rtnfurikaeymd ;
drop procedure if exists spipi044k00r01(char, char, char, char, char, integer, text);
drop procedure if exists spipi044k00r01(text, text, text, text, text, integer, text);
drop procedure if exists spipi044k00r01(char, char, char, char, char, numeric, text);

CREATE OR REPLACE PROCEDURE spipi044k00r01_genbodatainsert (
    inItakuKaishaCd GENBO_WORK.ITAKU_KAISHA_CD % TYPE,				-- char
    inHktCd GENBO_WORK.HKT_CD % TYPE,								-- char
    inIsinCd GENBO_WORK.ISIN_CD % TYPE,								-- char
    inGnrbaraiKjt GENBO_WORK.GNRBARAI_KJT % TYPE,					-- char
    inJtkKbn GENBO_WORK.JTK_KBN % TYPE,								-- char
    inTanpoKbn GENBO_WORK.TANPO_KBN % TYPE,							-- char
    inSaikenShurui GENBO_WORK.SAIKEN_SHURUI % TYPE,					-- char
    inHakkoYmd GENBO_WORK.HAKKO_YMD % TYPE,							-- char
    inShasaiTotal GENBO_WORK.SHASAI_TOTAL % TYPE, 					-- bigint
    inHakkoTsukaCd GENBO_WORK.HAKKO_TSUKA_CD % TYPE,				-- char
    inRbrKjt GENBO_WORK.RBR_KJT % TYPE,								-- char
    inHrkmYmd GENBO_WORK.HRKM_YMD % TYPE,							-- char
    inKakushasaiKngk GENBO_WORK.KAKUSHASAI_KNGK % TYPE, 			-- bigint
    inShokanMethodCd GENBO_WORK.SHOKAN_METHOD_CD % TYPE,			-- char
    inRiritsu GENBO_WORK.RIRITSU % TYPE,							-- numeric
    inFullshokanKjt GENBO_WORK.FULLSHOKAN_KJT % TYPE,				-- char
    inHrkmKngk GENBO_WORK.HRKM_KNGK % TYPE, 						-- bigint
    inRitsukeWaribikiKbn GENBO_WORK.RITSUKE_WARIBIKI_KBN % TYPE,	-- char
    inGnrYmd GENBO_WORK.GNR_YMD % TYPE,								-- char
    inShokanKbn GENBO_WORK.SHOKAN_KBN % TYPE,						-- char
    inGensaiKngk GENBO_WORK.GENSAI_KNGK % TYPE,						-- bigint
    inGenzonKngk GENBO_WORK.GENZON_KNGK % TYPE,						-- numeric
    inMeimokuZndk GENBO_WORK.MEIMOKU_ZNDK % TYPE,					-- numeric
    inFactor GENBO_WORK.FACTOR % TYPE,								-- numeric
    inRknKngk GENBO_WORK.RKN_KNGK % TYPE,							-- numeric
    inTokureiShasaiFlg GENBO_WORK.TOKUREI_SHASAI_FLG % TYPE,		-- char
    inPartmgrKbn GENBO_WORK.PARTMGR_KBN % TYPE,						-- char
    inGenisinCd GENBO_WORK.GENISIN_CD % TYPE,						-- char
    inJutakusakiTitle GENBO_WORK.JUTAKUSAKI_TITLE % TYPE,			-- varchar
    inRbrKjtNm GENBO_WORK.RBR_KJT_NM % TYPE,						-- varchar
    inSakuseiId GENBO_WORK.SAKUSEI_ID % TYPE						-- varchar
) AS $body$ BEGIN
	INSERT INTO GENBO_WORK(
		ITAKU_KAISHA_CD
		,HKT_CD
		,ISIN_CD
		,GNRBARAI_KJT
		,JTK_KBN
		,TANPO_KBN
		,SAIKEN_SHURUI
		,HAKKO_YMD
		,SHASAI_TOTAL
		,HAKKO_TSUKA_CD
		,RBR_KJT
		,HRKM_YMD
		,KAKUSHASAI_KNGK
		,SHOKAN_METHOD_CD
		,RIRITSU
		,FULLSHOKAN_KJT
		,HRKM_KNGK
		,RITSUKE_WARIBIKI_KBN
		,GNR_YMD
		,SHOKAN_KBN
		,GENSAI_KNGK
		,GENZON_KNGK
		,MEIMOKU_ZNDK
		,FACTOR
		,RKN_KNGK
		,TOKUREI_SHASAI_FLG
		,PARTMGR_KBN
		,GENISIN_CD
		,JUTAKUSAKI_TITLE
		,RBR_KJT_NM
		,SAKUSEI_ID
	)
	VALUES (
		inItakuKaishaCd
		,inHktCd
		,inIsinCd
		,inGnrbaraiKjt
		,inJtkKbn
		,inTanpoKbn
		,inSaikenShurui
		,inHakkoYmd
		,inShasaiTotal
		,inHakkoTsukaCd
		,inRbrKjt
		,inHrkmYmd
		,inKakushasaiKngk
		,inShokanMethodCd
		,inRiritsu
		,inFullshokanKjt
		,inHrkmKngk
		,inRitsukeWaribikiKbn
		,inGnrYmd
		,inShokanKbn
		,inGensaiKngk
		,inGenzonKngk
		,inMeimokuZndk
		,inFactor
		,inRknKngk
		,inTokureiShasaiFlg
		,inPartmgrKbn
		,inGenisinCd
		,inJutakusakiTitle
		,inRbrKjtNm
		,inSakuseiId
	);
END;
$body$
LANGUAGE PLPGSQL
;

/*==============================================================================*/

/*                  関数定義                                                    */

/*==============================================================================*/

/**
 * 初回の振替債移行日以降の利払いデータを抽出するため,
 * 判断をさせる日付を返す関数
 *
 * 返り値の型：TEXT
 *
 * ・振替債ではない場合の返り値：'00000000'
 * ・初回の振替債が行われてない場合の返り値：'99999999'
 * ・初回の振替債が行われている場合の返り値：初回の振替債が行われた日付
 *
 * @param inItakuKaishaCd	委託会社コード
 * @param inMgrCd			銘柄コード
 * @param inTokureiFlg		特例社債フラグ
 * @param inGyomuYmd		業務日付
 */
CREATE OR REPLACE PROCEDURE spipi044k00r01_rtnfurikaeymd (
    inItakuKaishaCd MGR_KIHON.ITAKU_KAISHA_CD % TYPE,
    inMgrCd MGR_KIHON.MGR_CD % TYPE,
    inTokureiFlg MGR_KIHON.TOKUREI_SHASAI_FLG % TYPE,
    inGyomuYmd SSYSTEM_MANAGEMENT.GYOMU_YMD % TYPE,
    outFurikaeYmd INOUT GENSAI_RIREKI.SHOKAN_YMD % TYPE
) AS $body$ BEGIN
	RAISE NOTICE '[DEBUG rtnfurikaeymd] START inTokureiFlg=%', inTokureiFlg;
	IF trim(both inTokureiFlg) = 'N' THEN
		-- 該当する銘柄が特例社債でなければ、リターン値は'00000000'とする。
		outFurikaeYmd := '00000000';
		RAISE NOTICE '[DEBUG rtnfurikaeymd] Not tokurei, return 00000000';
	ELSE	-- 該当する銘柄が特例社債であれば、以下の処理を行う。
		-- 初回の振替債が行われてない場合は'99999999'を変数に格納
		-- 初回の振替債が行われている場合は初回の振替債が行われた日付を変数に格納
		RAISE NOTICE '[DEBUG rtnfurikaeymd] Is tokurei, query gensai_rireki';
		SELECT  coalesce(trim(both MIN(Z01.SHOKAN_YMD)),'99999999')
		INTO STRICT    outFurikaeYmd
		FROM    GENSAI_RIREKI Z01
		WHERE   Z01.ITAKU_KAISHA_CD = inItakuKaishaCd
		AND     Z01.MGR_CD = inMgrCd
		AND     Z01.SHOKAN_YMD <= inGyomuYmd
		AND     Z01.SHOKAN_KBN = '01';
		RAISE NOTICE '[DEBUG rtnfurikaeymd] Query done, outFurikaeYmd=%', outFurikaeYmd;
	END IF;
	RAISE NOTICE '[DEBUG rtnfurikaeymd] END';
END;
/**
 * 原簿ワークテーブルにデータを登録します。
 *
 * @param				inItakuKaishaCd				委託会社コード
 * @param				inHktCd						発行体コード
 * @param				inIsinCd					ＩＳＩＮコード
 * @param				inGnrbaraiKjt				元利払期日
 * @param				inJtkKbn					受託区分
 * @param				inTanpoKbn					担保区分
 * @param				inSaikenShurui				債券種類
 * @param				inHakkoYmd					発行年月日
 * @param				inShasaiTotal				社債の総額
 * @param				inHakkoTsukaCd				発行通貨
 * @param				inRbrKjt					利払期日
 * @param				inHrkmYmd					払込日
 * @param 				inKakushasaiKngk			各社債の金額
 * @param 				inShokanMethodCd			償還方法
 * @param 				inRiritsu					利率
 * @param 				inFullshokanKjt				満期償還日
 * @param 				inHrkmKngk					払込金額
 * @param 				inRitsukeWaribikiKbn		利付割引区分
 * @param 				inGnrYmd					元利払日
 * @param 				inShokanKbn					償還区分
 * @param 				inGensaiKngk				減債金額
 * @param 				inGenzonKngk				現存金額
 * @param 				inMeimokuZndk				名目残高
 * @param 				inFactor					ファクター
 * @param 				inRknKngk					利金金額
 * @param 				inTokureiShasaiFlg			特例社債フラグ
 * @param 				inPartmgrKbn				分割銘柄区分
 * @param 				inGenisinCd					原ＩＳＩＮコード
 * @param 				inJutakusakiTitle			受託先タイトル
 * @param 				inRbrKjtNm					利払期日名称
 * @param				inSakuseiId					入力ユーザ
 */
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipi044k00r01_rtnfurikaeymd ( inItakuKaishaCd MGR_KIHON.ITAKU_KAISHA_CD%TYPE, inMgrCd MGR_KIHON.MGR_CD%TYPE, inTokureiFlg MGR_KIHON.TOKUREI_SHASAI_FLG%TYPE, inGyomuYmd SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE, outFurikaeYmd INOUT GENSAI_RIREKI.SHOKAN_YMD%TYPE ) FROM PUBLIC;

CREATE OR REPLACE PROCEDURE spipi044k00r01 ( 
    l_inItakuKaishaCd TEXT,				-- 委託会社コード
    l_inUserId TEXT,				-- ユーザーID
    l_inChohyoKbn TEXT,				-- 帳票区分
    l_inGyomuYmd TEXT,				-- 業務日付
    l_inMgrCd TEXT,				-- 銘柄コード
    l_outSqlCode INOUT integer,				-- リターン値
    l_outSqlErrM INOUT text			-- エラーコメント
 ) AS $body$
DECLARE

--
--/* 著作権:Copyright(c)2004
--/* 会社名:JIP
--/* 概要　:原簿ワークファイルを作成する。
--/* 引数　:	l_inItakuKaishaCd			IN		TEXT				-- 委託会社コード
--/*			l_inUserId					IN		TEXT				-- ユーザーID
--/*			l_inChohyoKbn				IN		TEXT				-- 帳票区分
--/*			l_inGyomuYmd				IN		TEXT				-- 業務日付
--/*			l_inMgrCd					IN		TEXT				-- 銘柄コード
--/*			l_inTsuchiYmd				IN 		TEXT  	 			-- 通知日
--/*			l_outSqlCode				OUT		NUMERIC				-- リターン値
--/*			l_outSqlErrM				OUT		VARCHAR			-- エラーコメント
--/* 返り値:なし
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2006.10.17	JIP				リメイク
--/* @version $Id: SPIPI044K00R01.SQL,v 1.40 2009/05/27 07:46:45 satou_t Exp $
--/*
--/*
--***************************************************************************
--
--==============================================================================
--					デバッグ機能
--==============================================================================
	DEBUG	smallint	:= 0;
--==============================================================================*/

/*					定数定義													*/

/*==============================================================================*/

	RTN_OK					CONSTANT integer		:= 0;				-- 正常
	RTN_NG					CONSTANT integer		:= 1;				-- 予期したエラー
	RTN_FATAL				CONSTANT integer		:= 99;				-- 予期せぬエラー
	REPORT_ID				CONSTANT text		:= 'IP030004412';	-- 帳票ID
/*==============================================================================*/

/*					変数定義													*/

/*==============================================================================*/

	gRtnCd				integer :=	RTN_OK;							-- リターンコード
	gSeqNo				integer := 0;								-- シーケンス
	gCount				numeric	:= 0;								-- 件数
	gOutFlg				numeric	:= 0;								-- リターンフラグ
	gJutakusakiTitle	GENBO_WORK.JUTAKUSAKI_TITLE%TYPE := NULL;	-- 受託先タイトル
	gRbrKjtNm			GENBO_WORK.RBR_KJT_NM%TYPE := NULL;		-- 利払期日名称
	-- 原簿の上部に出力するデータを格納するための変数
	gHKT_CD							GENBO_WORK.HKT_CD%TYPE;									-- 発行体コード
	gISIN_CD						GENBO_WORK.ISIN_CD%TYPE;								-- ＩＳＩＮコード
	gJTK_KBN						GENBO_WORK.JTK_KBN%TYPE;								-- 受託区分
	gTANPO_KBN						GENBO_WORK.TANPO_KBN%TYPE;								-- 担保区分
	gSAIKEN_SHURUI					GENBO_WORK.SAIKEN_SHURUI%TYPE;							-- 債券種類
	gHAKKO_YMD						GENBO_WORK.HAKKO_YMD%TYPE;								-- 発行年月日
	gSHASAI_TOTAL					GENBO_WORK.SHASAI_TOTAL%TYPE;							-- 社債の総額
	gHAKKO_TSUKA_CD					GENBO_WORK.HAKKO_TSUKA_CD%TYPE;							-- 発行通貨
	gSKN_KOFU_YMD					GENBO_WORK.HRKM_YMD%TYPE;								-- 払込日
	gKAKUSHASAI_KNGK				GENBO_WORK.KAKUSHASAI_KNGK%TYPE;						-- 各社債の金額
	gSHOKAN_METHOD_CD				GENBO_WORK.SHOKAN_METHOD_CD%TYPE;						-- 償還方法
	gRIRITSU						GENBO_WORK.RIRITSU%TYPE;								-- 利率
	gFULLSHOKAN_KJT					GENBO_WORK.FULLSHOKAN_KJT%TYPE;							-- 満期償還日
	gHARAIKOMI_KNGK					GENBO_WORK.HRKM_KNGK%TYPE;								-- 払込金額
	gRITSUKE_WARIBIKI_KBN			GENBO_WORK.RITSUKE_WARIBIKI_KBN%TYPE;					-- 利付割引区分
	gTOKUREI_SHASAI_FLG				GENBO_WORK.TOKUREI_SHASAI_FLG%TYPE;						-- 特例社債フラグ
	gPARTMGR_KBN					GENBO_WORK.PARTMGR_KBN%TYPE;							-- 分割銘柄区分
	gGENISIN_CD						GENBO_WORK.GENISIN_CD%TYPE;								-- 原ＩＳＩＮコード
	gNENRBR_CNT						MGR_KIHON_VIEW.NENRBR_CNT%TYPE;							-- 年利払回数
	gST_RBR_KJT						MGR_KIHON_VIEW.ST_RBR_KJT%TYPE;							-- 初回利払日
	gRBR_DD							MGR_KIHON_VIEW.RBR_DD%TYPE;								-- 利払日付
	gOWN_FINANCIAL_SECURITIES_KBN SOWN_INFO.OWN_FINANCIAL_SECURITIES_KBN%TYPE;				-- 自行金融証券区分
	gOWN_BANK_CD					SOWN_INFO.OWN_BANK_CD%TYPE;								-- 自行金融機関コード
	gFurikaeYmd			char(8)		:= NULL;											-- 振替債移行日格納用変数
	gJiyuCnt			numeric		:= 0;
/*==============================================================================*/

/*					カーソル定義													*/

/*==============================================================================*/

-- 発行分のデータを抽出するカーソル
CUR_HAKKO_DATA CURSOR FOR
SELECT	MG1.HAKKO_YMD AS GANRIBARAI_KJT 								-- 元利払期日
		,MG1.HAKKO_YMD AS GANRIBARAI_YMD 							-- 元利払日
		,'00' AS SHOKAN_KBN 											-- 償還区分
		,0 AS GENSAI_KNGK 											-- 減債金額
		,MG1.SHASAI_TOTAL::varchar AS GENZON_KNGK 					-- 現存金額
		,MG1.SHASAI_TOTAL::varchar AS MEIMOKU_ZNDK 					-- 名目残高
		,'1' AS FACTOR 												-- ファクター
		,0 AS RIKIN_KNGK 											-- 利金金額
FROM	MGR_KIHON MG1
WHERE	MG1.TOKUREI_SHASAI_FLG <> 'Y'
AND		MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
AND		MG1.MGR_CD = l_inMgrCd
AND		MG1.HAKKO_YMD <= l_inGyomuYmd;
-- 期中分のデータを抽出するカーソル
CUR_KICHU_DATA CURSOR FOR
SELECT	WK01.KJT AS GANRIBARAI_KJT 																-- 元利払期日
		,WK01.YMD AS GANRIBARAI_YMD 																-- 元利払日
		,coalesce(Z01.SHOKAN_KBN,'  ') AS SHOKAN_KBN 													-- 償還区分
		,coalesce(Z01.GENSAI_KNGK,0) AS GENSAI_KNGK 													-- 減債金額
		,'0' AS GENZON_KNGK 																		-- 現存金額
		,CASE WHEN trim(both coalesce(Z01.SHOKAN_KBN,'  '))		=''	THEN pkIpaZndk.getKjnZndk(l_inItakuKaishaCd,l_inMgrCd,WK01.YMD,1)		  ELSE pkIpaZndk.getKjnZndk(l_inItakuKaishaCd,l_inMgrCd,WK01.YMD,Z01.SHOKAN_KBN,11) END  AS MEIMOKU_ZNDK 	-- 名目残高
		,CASE WHEN coalesce(Z01.FACTOR,0)=0 THEN pkIpaZndk.getKjnZndk(l_inItakuKaishaCd,l_inMgrCd,WK01.YMD,5)   ELSE Z01.FACTOR::text END  AS FACTOR 	-- ファクター
		,coalesce(K02.KKN_NYUKIN_KNGK,0) - coalesce(K02_1.KKN_SHUKIN_KNGK,0) AS RIKIN_KNGK 														-- 利金金額（入金(利金)−返戻利金）
FROM (
					--利払
					SELECT	MG1.ITAKU_KAISHA_CD 												-- 委託会社コード
							,MG1.MGR_CD 														-- 銘柄コード
							,MG2.RBR_KJT AS KJT 												-- 元利払期日
							,MG2.RBR_YMD AS YMD 												-- 元利払日
					FROM	MGR_KIHON MG1
							,MGR_RBRKIJ MG2
					WHERE	MG1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
					AND		MG1.MGR_CD = MG2.MGR_CD
					AND		MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
					AND		MG1.MGR_CD = l_inMgrCd
					AND		MG2.RBR_YMD <= l_inGyomuYmd
					AND		MG2.RBR_YMD > gFurikaeYmd
					
UNION

					--償還
					SELECT	MG1.ITAKU_KAISHA_CD 												-- 委託会社コード
							,MG1.MGR_CD 														-- 銘柄コード
							,MG3.SHOKAN_KJT AS KJT 											-- 元利払期日
							,MG3.SHOKAN_YMD AS YMD 											-- 元利払日
					FROM	MGR_KIHON MG1
							,MGR_SHOKIJ MG3
					WHERE	MG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
					AND		MG1.MGR_CD = MG3.MGR_CD
					AND		MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
					AND		MG1.MGR_CD = l_inMgrCd
					AND		MG3.SHOKAN_YMD <= l_inGyomuYmd
					AND		MG3.SHOKAN_KBN NOT IN ('30','60')
		) wk01
LEFT OUTER JOIN (SELECT KK02.* FROM KIKIN_IDO KK02 WHERE KK02.KKN_IDO_KBN = '21') k02 ON (WK01.ITAKU_KAISHA_CD = K02.ITAKU_KAISHA_CD AND WK01.MGR_CD = K02.MGR_CD AND WK01.KJT = K02.RBR_KJT)
LEFT OUTER JOIN (SELECT KK02_1.* FROM KIKIN_IDO KK02_1 WHERE KK02_1.KKN_IDO_KBN IN ('71','72','73','74','75','76','77','7A','7B')) k02_1 ON (WK01.ITAKU_KAISHA_CD = K02_1.ITAKU_KAISHA_CD AND WK01.MGR_CD = K02_1.MGR_CD AND WK01.KJT = K02_1.RBR_KJT)
LEFT OUTER JOIN (SELECT ZZ01.* FROM GENSAI_RIREKI ZZ01 WHERE ZZ01.SHOKAN_KBN IN ('10','20','21','40','41','50')) z01 ON (WK01.ITAKU_KAISHA_CD = Z01.ITAKU_KAISHA_CD AND WK01.MGR_CD = Z01.MGR_CD AND WK01.YMD = Z01.SHOKAN_YMD);
-- 買入消却分のデータを抽出するカーソル
CUR_KAIIRE_DATA CURSOR FOR
SELECT	MG3.SHOKAN_KJT AS GANRIBARAI_KJT 													-- 元利払期日
		,MG3.SHOKAN_YMD AS GANRIBARAI_YMD 													-- 元利払日
		,Z01.SHOKAN_KBN AS SHOKAN_KBN 														-- 償還区分
		,Z01.GENSAI_KNGK AS GENSAI_KNGK 														-- 減債金額
		,'0' AS GENZON_KNGK 																	-- 現存金額
		,(pkIpaZndk.getKjnZndk(l_inItakuKaishaCd,l_inMgrCd,MG3.SHOKAN_YMD,1))::bigint AS MEIMOKU_ZNDK 	-- 名目残高
		,Z01.FACTOR AS FACTOR 																-- ファクター
		,0 AS RIKIN_KNGK 																	-- 利金金額
FROM	MGR_KIHON MG1
		,MGR_SHOKIJ MG3
		,GENSAI_RIREKI Z01
WHERE	MG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
AND		MG1.MGR_CD = MG3.MGR_CD
AND		MG3.ITAKU_KAISHA_CD = Z01.ITAKU_KAISHA_CD
AND		MG3.MGR_CD = Z01.MGR_CD
AND		MG3.SHOKAN_YMD = Z01.SHOKAN_YMD
AND		MG3.SHOKAN_KBN = Z01.SHOKAN_KBN
AND		Z01.SHOKAN_KBN = '30'
AND		MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
AND		MG1.MGR_CD = l_inMgrCd
AND		MG3.SHOKAN_YMD <= l_inGyomuYmd;
-- 振替債移行分のデータを抽出するカーソル
CUR_FURIKAE_DATA CURSOR FOR
SELECT	MG1.ITAKU_KAISHA_CD 																	-- 委託会社コード
		,MG1.MGR_CD 																			-- 銘柄コード
		,Z01.SHOKAN_YMD AS GANRIBARAI_KJT 													-- 元利払期日
		,Z01.SHOKAN_YMD AS GANRIBARAI_YMD 													-- 元利払日
		,Z01.SHOKAN_KBN AS SHOKAN_KBN 														-- 償還区分
		,0 AS GENSAI_KNGK 																	-- 減債金額
		,pkIpaZndk.getKjnZndk(l_inItakuKaishaCd,l_inMgrCd,Z01.SHOKAN_YMD,'01',13) AS GENZON_KNGK 	-- 現存金額
		,pkIpaZndk.getKjnZndk(l_inItakuKaishaCd,l_inMgrCd,Z01.SHOKAN_YMD,'01',11) AS MEIMOKU_ZNDK 	-- 名目残高
		,CASE WHEN Z01.FACTOR IS NULL THEN NULL ELSE Z01.FACTOR::text END AS FACTOR 																-- ファクター
		,0 AS RIKIN_KNGK 																	-- 利金金額
FROM	MGR_KIHON MG1
		,GENSAI_RIREKI Z01
WHERE	MG1.ITAKU_KAISHA_CD = Z01.ITAKU_KAISHA_CD
AND		MG1.MGR_CD = Z01.MGR_CD
AND		Z01.SHOKAN_KBN = '01'
AND		MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
AND		MG1.MGR_CD = l_inMgrCd
AND		Z01.SHOKAN_YMD <= l_inGyomuYmd
AND		( (	(SELECT	COUNT(*)
			FROM	GENSAI_RIREKI Z011
			WHERE	Z011.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND		Z011.MGR_CD = l_inMgrCd
			AND		Z011.SHOKAN_KBN = '01'	) > 1)
		OR
		(	(SELECT	COUNT(*)
			FROM	GENSAI_RIREKI Z011
			WHERE	Z011.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND		Z011.MGR_CD = l_inMgrCd
			AND		Z011.SHOKAN_KBN = '01'	) = 1
			AND 	((l_inChohyoKbn = '0') OR (gJiyuCnt > 0))));
-- 新株予約権行使分のデータを抽出するカーソル
CUR_SHINKABUYOYAKU_DATA CURSOR FOR
SELECT	MG3.SHOKAN_KJT AS GANRIBARAI_KJT 													-- 元利払期日
		,MG3.SHOKAN_YMD AS GANRIBARAI_YMD 													-- 元利払日
		,Z01.SHOKAN_KBN AS SHOKAN_KBN 														-- 償還区分
		,Z01.GENSAI_KNGK AS GENSAI_KNGK 														-- 減債金額
		,'0' AS GENZON_KNGK 																	-- 現存金額
		,(pkIpaZndk.getKjnZndk(l_inItakuKaishaCd,l_inMgrCd,MG3.SHOKAN_YMD,1))::bigint AS MEIMOKU_ZNDK 	-- 名目残高
		,Z01.FACTOR AS FACTOR 																-- ファクター
		,0 AS RIKIN_KNGK 																	-- 利金金額
FROM	MGR_KIHON MG1
		,MGR_SHOKIJ MG3
		,GENSAI_RIREKI Z01
WHERE	MG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
AND		MG1.MGR_CD = MG3.MGR_CD
AND		MG3.ITAKU_KAISHA_CD = Z01.ITAKU_KAISHA_CD
AND		MG3.MGR_CD = Z01.MGR_CD
AND		MG3.SHOKAN_YMD = Z01.SHOKAN_YMD
AND		MG3.SHOKAN_KBN = Z01.SHOKAN_KBN
AND		Z01.SHOKAN_KBN = '60'
AND		MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
AND		MG1.MGR_CD = l_inMgrCd
AND		MG3.SHOKAN_YMD <= l_inGyomuYmd;
/*==============================================================================*/

/*	メイン処理	*/

/*==============================================================================*/

BEGIN
	--raise notice 'in SPIPI044K00R01';

	RAISE NOTICE '[DEBUG R01] START MGR_CD=%', l_inMgrCd;
	IF DEBUG = 1 THEN	call pkLog.debug(l_inUserId, REPORT_ID, 'SPIPI044K00R01 START');	END IF;
	-- 入力パラメータのチェック
	IF nullif(trim(both l_inItakuKaishaCd), '') Is Null
	OR nullif(trim(both l_inUserId), '') Is Null
	OR nullif(trim(both l_inChohyoKbn), '') Is Null
	OR nullif(trim(both l_inGyomuYmd), '') Is Null
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN	call pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		call pkLog.error('ECM501', REPORT_ID, 'SQLERRM:'||'');
		RETURN;
	END IF;
	RAISE NOTICE '[DEBUG R01] After param check';
	-- 原簿の上部で必要となるデータを抽出し、変数に格納する
	SELECT 	/*+ INDEX(MG1 MGR_KIHON_PK) */			MG1.HKT_CD,
			MG1.ISIN_CD,
			MG1.JTK_KBN,
			MG1.TANPO_KBN,
			MG1.SAIKEN_SHURUI,
			MG1.HAKKO_YMD,
			MG1.SHASAI_TOTAL,
			MG1.HAKKO_TSUKA_CD,
			MG1.SKN_KOFU_YMD,
			MG1.KAKUSHASAI_KNGK,
			MG1.SHOKAN_METHOD_CD,
			MG1.RIRITSU,
			MG1.FULLSHOKAN_KJT,
			(MG1.SHASAI_TOTAL * MG1.HAKKO_KAGAKU / 100)::bigint AS HARAIKOMI_KNGK,
			coalesce(MG1.RITSUKE_WARIBIKI_KBN,' '),
			MG1.TOKUREI_SHASAI_FLG,
			MG1.PARTMGR_KBN,
			MG1.GENISIN_CD,
			MG1.NENRBR_CNT,
			MG1.ST_RBR_KJT,
			MG1.RBR_DD,
			VJ1.OWN_FINANCIAL_SECURITIES_KBN,
			VJ1.OWN_BANK_CD
	INTO	gHKT_CD
			,gISIN_CD
			,gJTK_KBN
			,gTANPO_KBN
			,gSAIKEN_SHURUI
			,gHAKKO_YMD
			,gSHASAI_TOTAL
			,gHAKKO_TSUKA_CD
			,gSKN_KOFU_YMD
			,gKAKUSHASAI_KNGK
			,gSHOKAN_METHOD_CD
			,gRIRITSU
			,gFULLSHOKAN_KJT
			,gHARAIKOMI_KNGK
			,gRITSUKE_WARIBIKI_KBN
			,gTOKUREI_SHASAI_FLG
			,gPARTMGR_KBN
			,gGENISIN_CD
			,gNENRBR_CNT
			,gST_RBR_KJT
			,gRBR_DD
			,gOWN_FINANCIAL_SECURITIES_KBN
			,gOWN_BANK_CD
	FROM	MGR_KIHON MG1,
			VJIKO_ITAKU VJ1
	WHERE	VJ1.KAIIN_ID = MG1.ITAKU_KAISHA_CD
	AND		MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
	AND		MG1.MGR_CD = l_inMgrCd
	AND		MG1.ISIN_CD <> ' '
	AND		MG1.KK_KANYO_FLG IN ('0','1')
	AND		MG1.JTK_KBN <> '2'
	AND		MG1.JTK_KBN <> '5'
	AND		MG1.PARTMGR_KBN IN ('0','2')
	ORDER BY VJ1.OWN_BANK_CD DESC NULLS LAST
	LIMIT 1;
	RAISE NOTICE '[DEBUG R01] After SELECT mgr_kihon';
	-- 初回の振替債移行日を格納。なければ他の固定文字を格納。
	call spipi044k00r01_rtnfurikaeymd(l_inItakuKaishaCd,l_inMgrCd,gTOKUREI_SHASAI_FLG,l_inGyomuYmd,gFurikaeYmd);
	RAISE NOTICE '[DEBUG R01] After rtnfurikaeymd, gFurikaeYmd=%', gFurikaeYmd;
	-- 銘柄_受託銀行の検索
	SELECT	COUNT(ITAKU_KAISHA_CD)
	INTO STRICT	gCount
	FROM	MGR_JUTAKUGINKO
	WHERE	ITAKU_KAISHA_CD = l_inItakuKaishaCd
	AND		MGR_CD = l_inMgrCd
	AND		FINANCIAL_SECURITIES_KBN = gOWN_FINANCIAL_SECURITIES_KBN
	AND		BANK_CD = gOWN_BANK_CD;
	RAISE NOTICE '[DEBUG R01] After SELECT mgr_jutakuginko, gCount=%', gCount;
	-- 受託タイトルの編集
	CASE gJTK_KBN
		WHEN '1' THEN
			CASE gTANPO_KBN
				WHEN '2' THEN
					gJutakusakiTitle := '受託会社';
				ELSE
					CASE gSAIKEN_SHURUI
						WHEN '10' THEN
							gJutakusakiTitle := '受託会社';
						ELSE
							CASE gCount
								WHEN 0 THEN
									gJutakusakiTitle := '発行代理人';
								ELSE
									gJutakusakiTitle := '社債管理者';
							END CASE;
					END CASE;
			END CASE;
		WHEN '3' THEN
			gJutakusakiTitle := '財務代理人';
		WHEN '4' THEN
			gJutakusakiTitle := '発行支払代理人';
		WHEN '6' THEN
			gJutakusakiTitle := '社債事務取扱者';
		ELSE
			gJutakusakiTitle := '　';
	END CASE;
	RAISE NOTICE '[DEBUG R01] After CASE gJutakusakiTitle, gNENRBR_CNT=%', gNENRBR_CNT;
	-- 年利払回数がNULLでなければ利払期日名称の編集を行う
	IF nullif(trim(both gNENRBR_CNT), '') IS NULL THEN
		gRbrKjtNm 				:=	' ';
	ELSE
		-- 利払期日名称の編集
		RAISE NOTICE '[DEBUG R01] Before getRibaraiKijitsu';
		select * into gOutFlg, gRbrKjtNm from pkRibaraiKijitsu.getRibaraiKijitsu(gNENRBR_CNT::int,gST_RBR_KJT,gRBR_DD);
		RAISE NOTICE '[DEBUG R01] After getRibaraiKijitsu, gOutFlg=%', gOutFlg;
	END IF;
	-- 発行分のデータを抽出するカーソル
	RAISE NOTICE '[DEBUG R01] Before cursor HAKKO_DATA';
	FOR HAKKO_DATA IN CUR_HAKKO_DATA LOOP
		-- 原簿ワークへの登録
		RAISE NOTICE '[DEBUG R01] In HAKKO_DATA loop';
		call spipi044k00r01_genboDataInsert(
			inItakuKaishaCd			=>	l_inItakuKaishaCd						-- 委託会社コード
			,inHktCd				=>	gHKT_CD									-- 発行体コード
			,inIsinCd				=>	gISIN_CD								-- ＩＳＩＮコード
			,inGnrbaraiKjt			=>	HAKKO_DATA.GANRIBARAI_KJT				-- 元利払期日
			,inJtkKbn				=>	gJTK_KBN								-- 受託区分
			,inTanpoKbn				=>	gTANPO_KBN								-- 担保区分
			,inSaikenShurui			=>	gSAIKEN_SHURUI							-- 債券種類
			,inHakkoYmd				=>	gHAKKO_YMD								-- 発行年月日
			,inShasaiTotal			=>	gSHASAI_TOTAL							-- 社債の総額
			,inHakkoTsukaCd			=>	gHAKKO_TSUKA_CD							-- 発行通貨
			,inRbrKjt				=>	HAKKO_DATA.GANRIBARAI_KJT				-- 利払期日
			,inHrkmYmd				=>	gSKN_KOFU_YMD							-- 払込日
			,inKakushasaiKngk		=>	gKAKUSHASAI_KNGK						-- 各社債の金額
			,inShokanMethodCd		=>	gSHOKAN_METHOD_CD						-- 償還方法
			,inRiritsu				=>	gRIRITSU								-- 利率
			,inFullshokanKjt		=>	gFULLSHOKAN_KJT							-- 満期償還日
			,inHrkmKngk				=>	gHARAIKOMI_KNGK							-- 払込金額
			,inRitsukeWaribikiKbn	=>	gRITSUKE_WARIBIKI_KBN					-- 利付割引区分
			,inGnrYmd				=>	HAKKO_DATA.GANRIBARAI_YMD				-- 元利払日
			,inShokanKbn			=>	HAKKO_DATA.SHOKAN_KBN					-- 償還区分
			,inGensaiKngk			=>	HAKKO_DATA.GENSAI_KNGK::bigint			-- 減債金額
			,inGenzonKngk			=>	CASE WHEN HAKKO_DATA.GENZON_KNGK ~ '^[0-9]+$' THEN HAKKO_DATA.GENZON_KNGK::bigint::numeric ELSE 0 END			-- 現存金額
			,inMeimokuZndk			=>	CASE WHEN HAKKO_DATA.MEIMOKU_ZNDK ~ '^[0-9]+$' THEN HAKKO_DATA.MEIMOKU_ZNDK::bigint::numeric ELSE 0 END		-- 名目残高
			,inFactor				=>	CASE WHEN HAKKO_DATA.FACTOR ~ '^[0-9.]+$' THEN HAKKO_DATA.FACTOR::numeric ELSE 1 END				-- ファクター
			,inRknKngk				=>	HAKKO_DATA.RIKIN_KNGK::bigint::numeric			-- 利金金額
			,inTokureiShasaiFlg		=>	gTOKUREI_SHASAI_FLG						-- 特例社債フラグ
			,inPartmgrKbn			=>	gPARTMGR_KBN							-- 分割銘柄区分
			,inGenisinCd			=>	gGENISIN_CD								-- 原ＩＳＩＮコード
			,inJutakusakiTitle		=>	gJutakusakiTitle						-- 受託先タイトル
			,inRbrKjtNm				=>	gRbrKjtNm								-- 利払期日名称
			,inSakuseiId			=>	l_inUserId								-- 入力ユーザ
		);
	END LOOP;
	-- 期中分のデータを抽出するカーソル
	RAISE NOTICE '[DEBUG R01] Before cursor KICHU_DATA';
	BEGIN
		FOR KICHU_DATA IN CUR_KICHU_DATA LOOP
			RAISE NOTICE '[DEBUG R01] In KICHU loop: KJT=%, YMD=%, SHOKAN_KBN=%, MEIMOKU_ZNDK=%', KICHU_DATA.GANRIBARAI_KJT, KICHU_DATA.GANRIBARAI_YMD, KICHU_DATA.SHOKAN_KBN, KICHU_DATA.MEIMOKU_ZNDK;
			-- 残高ファンクションを使用する時のエラー対応
			IF KICHU_DATA.MEIMOKU_ZNDK ='JISSU_ERROR' THEN
			l_outSqlCode := RTN_NG;
			l_outSqlErrM := 'JISSU_ERROR';
			return;
		ELSIF KICHU_DATA.MEIMOKU_ZNDK ='FACTOR_ERROR' THEN
			l_outSqlCode := RTN_NG;
			l_outSqlErrM := 'FACTOR_ERROR';
			return;
		END IF;
		-- 原簿ワークへの登録
		call spipi044k00r01_genbodatainsert(
				inItakuKaishaCd			=>	l_inItakuKaishaCd						-- 委託会社コード
				,inHktCd				=>	gHKT_CD									-- 発行体コード
				,inIsinCd				=>	gISIN_CD								-- ＩＳＩＮコード
				,inGnrbaraiKjt			=>	KICHU_DATA.GANRIBARAI_KJT				-- 元利払期日
				,inJtkKbn				=>	gJTK_KBN								-- 受託区分
				,inTanpoKbn				=>	gTANPO_KBN								-- 担保区分
				,inSaikenShurui			=>	gSAIKEN_SHURUI							-- 債券種類
				,inHakkoYmd				=>	gHAKKO_YMD								-- 発行年月日
				,inShasaiTotal			=>	gSHASAI_TOTAL							-- 社債の総額
				,inHakkoTsukaCd			=>	gHAKKO_TSUKA_CD							-- 発行通貨
				,inRbrKjt				=>	KICHU_DATA.GANRIBARAI_KJT				-- 利払期日
				,inHrkmYmd				=>	gSKN_KOFU_YMD							-- 払込日
				,inKakushasaiKngk		=>	gKAKUSHASAI_KNGK						-- 各社債の金額
				,inShokanMethodCd		=>	gSHOKAN_METHOD_CD						-- 償還方法
				,inRiritsu				=>	gRIRITSU								-- 利率
				,inFullshokanKjt		=>	gFULLSHOKAN_KJT							-- 満期償還日
				,inHrkmKngk				=>	gHARAIKOMI_KNGK							-- 払込金額
				,inRitsukeWaribikiKbn	=>	gRITSUKE_WARIBIKI_KBN					-- 利付割引区分
				,inGnrYmd				=>	KICHU_DATA.GANRIBARAI_YMD				-- 元利払日
				,inShokanKbn			=>	KICHU_DATA.SHOKAN_KBN					-- 償還区分
				,inGensaiKngk			=>	KICHU_DATA.GENSAI_KNGK::bigint					-- 減債金額
				,inGenzonKngk			=>	CASE WHEN KICHU_DATA.GENZON_KNGK ~ '^[0-9]+$' THEN KICHU_DATA.GENZON_KNGK::bigint::numeric ELSE 0 END					-- 現存金額
				,inMeimokuZndk			=>	CASE WHEN KICHU_DATA.MEIMOKU_ZNDK ~ '^[0-9]+$' THEN KICHU_DATA.MEIMOKU_ZNDK::bigint::numeric ELSE 0 END					-- 名目残高
				,inFactor				=>	CASE WHEN KICHU_DATA.FACTOR ~ '^[0-9.]+$' THEN KICHU_DATA.FACTOR::numeric ELSE 0 END						-- ファクター
				,inRknKngk				=>	KICHU_DATA.RIKIN_KNGK::bigint::numeric					-- 利金金額
				,inTokureiShasaiFlg		=>	gTOKUREI_SHASAI_FLG						-- 特例社債フラグ
				,inPartmgrKbn			=>	gPARTMGR_KBN							-- 分割銘柄区分
				,inGenisinCd			=>	gGENISIN_CD								-- 原ＩＳＩＮコード
				,inJutakusakiTitle		=>	gJutakusakiTitle						-- 受託先タイトル
				,inRbrKjtNm				=>	gRbrKjtNm								-- 利払期日名称
				,inSakuseiId			=>	l_inUserId								-- 入力ユーザ
		);
			-- 事由があった場合、カウントアップする
			gJiyuCnt := gJiyuCnt + 1;
		END LOOP;
	EXCEPTION
		WHEN OTHERS THEN
			RAISE NOTICE '[DEBUG R01] KICHU cursor ERROR: SQLSTATE=%, SQLERRM=%', SQLSTATE, SQLERRM;
			RAISE;
	END;
	-- 買入消却分のデータを抽出するカーソル
	FOR KAIIRE_DATA IN CUR_KAIIRE_DATA LOOP
		-- 残高ファンクションを使用する時のエラー対応
		IF KAIIRE_DATA.MEIMOKU_ZNDK ='JISSU_ERROR' THEN
			l_outSqlCode := RTN_NG;
			l_outSqlErrM := 'JISSU_ERROR';
			return;
		ELSIF KAIIRE_DATA.MEIMOKU_ZNDK ='FACTOR_ERROR' THEN
			l_outSqlCode := RTN_NG;
			l_outSqlErrM := 'FACTOR_ERROR';
			return;
		END IF;
		-- 原簿ワークへの登録
		call spipi044k00r01_genbodatainsert(
				inItakuKaishaCd			=>	l_inItakuKaishaCd						-- 委託会社コード
				,inHktCd				=>	gHKT_CD									-- 発行体コード
				,inIsinCd				=>	gISIN_CD								-- ＩＳＩＮコード
				,inGnrbaraiKjt			=>	KAIIRE_DATA.GANRIBARAI_KJT				-- 元利払期日
				,inJtkKbn				=>	gJTK_KBN								-- 受託区分
				,inTanpoKbn				=>	gTANPO_KBN								-- 担保区分
				,inSaikenShurui			=>	gSAIKEN_SHURUI							-- 債券種類
				,inHakkoYmd				=>	gHAKKO_YMD								-- 発行年月日
				,inShasaiTotal			=>	gSHASAI_TOTAL							-- 社債の総額
				,inHakkoTsukaCd			=>	gHAKKO_TSUKA_CD							-- 発行通貨
				,inRbrKjt				=>	KAIIRE_DATA.GANRIBARAI_KJT				-- 利払期日
				,inHrkmYmd				=>	gSKN_KOFU_YMD							-- 払込日
				,inKakushasaiKngk		=>	gKAKUSHASAI_KNGK						-- 各社債の金額
				,inShokanMethodCd		=>	gSHOKAN_METHOD_CD						-- 償還方法
				,inRiritsu				=>	gRIRITSU								-- 利率
				,inFullshokanKjt		=>	gFULLSHOKAN_KJT							-- 満期償還日
				,inHrkmKngk				=>	gHARAIKOMI_KNGK							-- 払込金額
				,inRitsukeWaribikiKbn	=>	gRITSUKE_WARIBIKI_KBN					-- 利付割引区分
				,inGnrYmd				=>	KAIIRE_DATA.GANRIBARAI_YMD				-- 元利払日
				,inShokanKbn			=>	KAIIRE_DATA.SHOKAN_KBN					-- 償還区分
				,inGensaiKngk			=>	KAIIRE_DATA.GENSAI_KNGK::bigint					-- 減債金額
				,inGenzonKngk			=>	CASE WHEN KAIIRE_DATA.GENZON_KNGK ~ '^[0-9]+$' THEN KAIIRE_DATA.GENZON_KNGK::bigint::numeric ELSE 0 END					-- 現存金額
				,inMeimokuZndk			=>	CASE WHEN KAIIRE_DATA.MEIMOKU_ZNDK ~ '^[0-9]+$' THEN KAIIRE_DATA.MEIMOKU_ZNDK::bigint::numeric ELSE 0 END				-- 名目残高
				,inFactor				=>	CASE WHEN KAIIRE_DATA.FACTOR ~ '^[0-9.]+$' THEN KAIIRE_DATA.FACTOR::numeric ELSE 0 END						-- ファクター
				,inRknKngk				=>	KAIIRE_DATA.RIKIN_KNGK::bigint::numeric					-- 利金金額
				,inTokureiShasaiFlg		=>	gTOKUREI_SHASAI_FLG						-- 特例社債フラグ
				,inPartmgrKbn			=>	gPARTMGR_KBN							-- 分割銘柄区分
				,inGenisinCd			=>	gGENISIN_CD								-- 原ＩＳＩＮコード
				,inJutakusakiTitle		=>	gJutakusakiTitle						-- 受託先タイトル
				,inRbrKjtNm				=>	gRbrKjtNm								-- 利払期日名称
				,inSakuseiId			=>	l_inUserId								-- 入力ユーザ
		);
		-- 事由があった場合、カウントアップする
		gJiyuCnt := gJiyuCnt + 1;
	END LOOP;
	-- 新株予約権行使分のデータを抽出するカーソル
	FOR SHINKABUYOYAKU_DATA IN CUR_SHINKABUYOYAKU_DATA LOOP
		-- 残高ファンクションを使用する時のエラー対応
		IF SHINKABUYOYAKU_DATA.MEIMOKU_ZNDK ='JISSU_ERROR' THEN
			l_outSqlCode := RTN_NG;
			l_outSqlErrM := 'JISSU_ERROR';
			return;
		ELSIF SHINKABUYOYAKU_DATA.MEIMOKU_ZNDK ='FACTOR_ERROR' THEN
			l_outSqlCode := RTN_NG;
			l_outSqlErrM := 'FACTOR_ERROR';
			return;
		END IF;
		-- 原簿ワークへの登録
		call spipi044k00r01_genbodatainsert(
				inItakuKaishaCd			=>	l_inItakuKaishaCd						-- 委託会社コード
				,inHktCd				=>	gHKT_CD									-- 発行体コード
				,inIsinCd				=>	gISIN_CD								-- ＩＳＩＮコード
				,inGnrbaraiKjt			=>	SHINKABUYOYAKU_DATA.GANRIBARAI_KJT		-- 元利払期日
				,inJtkKbn				=>	gJTK_KBN								-- 受託区分
				,inTanpoKbn				=>	gTANPO_KBN								-- 担保区分
				,inSaikenShurui			=>	gSAIKEN_SHURUI							-- 債券種類
				,inHakkoYmd				=>	gHAKKO_YMD								-- 発行年月日
				,inShasaiTotal			=>	gSHASAI_TOTAL							-- 社債の総額
				,inHakkoTsukaCd			=>	gHAKKO_TSUKA_CD							-- 発行通貨
				,inRbrKjt				=>	SHINKABUYOYAKU_DATA.GANRIBARAI_KJT			-- 利払期日
				,inHrkmYmd				=>	gSKN_KOFU_YMD							-- 払込日
				,inKakushasaiKngk		=>	gKAKUSHASAI_KNGK						-- 各社債の金額
				,inShokanMethodCd		=>	gSHOKAN_METHOD_CD						-- 償還方法
				,inRiritsu				=>	gRIRITSU								-- 利率
				,inFullshokanKjt		=>	gFULLSHOKAN_KJT							-- 満期償還日
				,inHrkmKngk				=>	gHARAIKOMI_KNGK							-- 払込金額
				,inRitsukeWaribikiKbn	=>	gRITSUKE_WARIBIKI_KBN					-- 利付割引区分
				,inGnrYmd				=>	SHINKABUYOYAKU_DATA.GANRIBARAI_YMD		-- 元利払日
				,inShokanKbn			=>	SHINKABUYOYAKU_DATA.SHOKAN_KBN			-- 償還区分
				,inGensaiKngk			=>	SHINKABUYOYAKU_DATA.GENSAI_KNGK::bigint				-- 減債金額
				,inGenzonKngk			=>	CASE WHEN SHINKABUYOYAKU_DATA.GENZON_KNGK ~ '^[0-9]+$' THEN SHINKABUYOYAKU_DATA.GENZON_KNGK::bigint::numeric ELSE 0 END				-- 現存金額
				,inMeimokuZndk			=>	CASE WHEN SHINKABUYOYAKU_DATA.MEIMOKU_ZNDK ~ '^[0-9]+$' THEN SHINKABUYOYAKU_DATA.MEIMOKU_ZNDK::bigint::numeric ELSE 0 END		-- 名目残高
				,inFactor				=>	CASE WHEN SHINKABUYOYAKU_DATA.FACTOR ~ '^[0-9.]+$' THEN SHINKABUYOYAKU_DATA.FACTOR::numeric ELSE 0 END				-- ファクター
				,inRknKngk				=>	SHINKABUYOYAKU_DATA.RIKIN_KNGK::bigint::numeric				-- 利金金額
				,inTokureiShasaiFlg		=>	gTOKUREI_SHASAI_FLG						-- 特例社債フラグ
				,inPartmgrKbn			=>	gPARTMGR_KBN							-- 分割銘柄区分
				,inGenisinCd			=>	gGENISIN_CD								-- 原ＩＳＩＮコード
				,inJutakusakiTitle		=>	gJutakusakiTitle						-- 受託先タイトル
				,inRbrKjtNm				=>	gRbrKjtNm								-- 利払期日名称
				,inSakuseiId			=>	l_inUserId								-- 入力ユーザ
		);
		-- 事由があった場合、カウントアップする
		gJiyuCnt := gJiyuCnt + 1;
	END LOOP;
	-- 振替債移行分のデータを抽出するカーソル
	FOR FURIKAE_DATA IN CUR_FURIKAE_DATA LOOP
		-- 残高ファンクションを使用する時のエラー対応
		IF FURIKAE_DATA.MEIMOKU_ZNDK ='JISSU_ERROR' THEN
			l_outSqlCode := RTN_NG;
			l_outSqlErrM := 'JISSU_ERROR';
			return;
		ELSIF FURIKAE_DATA.MEIMOKU_ZNDK ='FACTOR_ERROR' THEN
			l_outSqlCode := RTN_NG;
			l_outSqlErrM := 'FACTOR_ERROR';
			return;
		END IF;
		IF FURIKAE_DATA.MEIMOKU_ZNDK ='JISSU_ERROR' THEN
			l_outSqlCode := RTN_NG;
			l_outSqlErrM := 'JISSU_ERROR';
			return;
		ELSIF FURIKAE_DATA.MEIMOKU_ZNDK ='FACTOR_ERROR' THEN
			l_outSqlCode := RTN_NG;
			l_outSqlErrM := 'FACTOR_ERROR';
			return;
		END IF;
		-- 原簿ワークへの登録
		call spipi044k00r01_genbodatainsert(
				inItakuKaishaCd			=>	l_inItakuKaishaCd						-- 委託会社コード
				,inHktCd				=>	gHKT_CD									-- 発行体コード
				,inIsinCd				=>	gISIN_CD								-- ＩＳＩＮコード
				,inGnrbaraiKjt			=>	FURIKAE_DATA.GANRIBARAI_KJT				-- 元利払期日
				,inJtkKbn				=>	gJTK_KBN								-- 受託区分
				,inTanpoKbn				=>	gTANPO_KBN								-- 担保区分
				,inSaikenShurui			=>	gSAIKEN_SHURUI							-- 債券種類
				,inHakkoYmd				=>	gHAKKO_YMD								-- 発行年月日
				,inShasaiTotal			=>	gSHASAI_TOTAL							-- 社債の総額
				,inHakkoTsukaCd			=>	gHAKKO_TSUKA_CD							-- 発行通貨
				,inRbrKjt				=>	FURIKAE_DATA.GANRIBARAI_KJT				-- 利払期日
				,inHrkmYmd				=>	gSKN_KOFU_YMD							-- 払込日
				,inKakushasaiKngk		=>	gKAKUSHASAI_KNGK						-- 各社債の金額
				,inShokanMethodCd		=>	gSHOKAN_METHOD_CD						-- 償還方法
				,inRiritsu				=>	gRIRITSU								-- 利率
				,inFullshokanKjt		=>	gFULLSHOKAN_KJT							-- 満期償還日
				,inHrkmKngk				=>	gHARAIKOMI_KNGK							-- 払込金額
				,inRitsukeWaribikiKbn	=>	gRITSUKE_WARIBIKI_KBN					-- 利付割引区分
				,inGnrYmd				=>	FURIKAE_DATA.GANRIBARAI_YMD				-- 元利払日
				,inShokanKbn			=>	FURIKAE_DATA.SHOKAN_KBN					-- 償還区分
				,inGensaiKngk			=>	FURIKAE_DATA.GENSAI_KNGK::bigint					-- 減債金額
				,inGenzonKngk			=>	CASE WHEN FURIKAE_DATA.GENZON_KNGK ~ '^[0-9]+$' THEN FURIKAE_DATA.GENZON_KNGK::bigint::numeric ELSE 0 END					-- 現存金額
				,inMeimokuZndk			=>	CASE WHEN FURIKAE_DATA.MEIMOKU_ZNDK ~ '^[0-9]+$' THEN FURIKAE_DATA.MEIMOKU_ZNDK::bigint::numeric ELSE 0 END				-- 名目残高
				,inFactor				=>	CASE WHEN FURIKAE_DATA.FACTOR ~ '^[0-9.]+$' THEN FURIKAE_DATA.FACTOR::numeric ELSE 0 END						-- ファクター
				,inRknKngk				=>	FURIKAE_DATA.RIKIN_KNGK::bigint::numeric					-- 利金金額
				,inTokureiShasaiFlg		=>	gTOKUREI_SHASAI_FLG						-- 特例社債フラグ
				,inPartmgrKbn			=>	gPARTMGR_KBN							-- 分割銘柄区分
				,inGenisinCd			=>	gGENISIN_CD								-- 原ＩＳＩＮコード
				,inJutakusakiTitle		=>	gJutakusakiTitle						-- 受託先タイトル
				,inRbrKjtNm				=>	gRbrKjtNm								-- 利払期日名称
				,inSakuseiId			=>	l_inUserId								-- 入力ユーザ
		);
	END LOOP;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	call pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	call pkLog.debug(l_inUserId, REPORT_ID, 'SPIPI044K00R01 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		call pkLog.fatal('ECM701', REPORT_ID, 'SQLCODE:'||SQLSTATE);
		call pkLog.fatal('ECM701', REPORT_ID, 'SQLERRM:'||SUBSTR(SQLERRM, 1, 100));
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
		raise notice 'SQLERRM: %', SQLERRM;
		raise notice 'SQLSTATE: %', SQLSTATE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipi044k00r01 ( l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_inMgrCd TEXT, l_outSqlCode INOUT numeric, l_outSqlErrM INOUT text ) FROM PUBLIC;

