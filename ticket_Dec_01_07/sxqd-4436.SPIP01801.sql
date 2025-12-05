




CREATE OR REPLACE PROCEDURE spip01801 ( l_inHktCd TEXT,		-- 発行体コード
 l_inKozaTenCd TEXT,		-- 口座店コード
 l_inKozaTenCifCd TEXT,		-- 口座店CIFコード
 l_inMgrCd TEXT,		-- 銘柄コード
 l_inIsinCd TEXT,		-- ISINコード
 l_inGanriBaraiYmdF TEXT,		-- 元利払期日(From)
 l_inGanriBaraiYmdT TEXT,		-- 元利払期日(To)
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
--/* 概要　:事務帳票出力指示画面の入力条件により、銘柄情報変更リストを作成する。
--/* 引数　:l_inHktCd				IN	TEXT		発行体コード
--/* 　　　 l_inKozaTenCd			IN	TEXT		口座店コード
--/* 　　　 l_inKozaTenCifCd		IN	TEXT		口座店CIFコード
--/* 　　　 l_inMgrCd				IN	TEXT		銘柄コード
--/* 　　　 l_inIsinCd			IN	TEXT		ISINコード
--/* 　　　 l_inGanriBaraiYmdF	IN	TEXT		元利払期日(From)
--/* 　　　 l_inGanriBaraiYmdT	IN	TEXT		元利払期日(To)
--/* 　　　 l_inItakuKaishaCd		IN	TEXT		委託会社コード
--/* 　　　 l_inUserId			IN	TEXT		ユーザーID
--/* 　　　 l_inChohyoKbn			IN	TEXT		帳票区分
--/* 　　　 l_inGyomuYmd			IN	TEXT		業務日付
--/* 　　　 l_outSqlCode			OUT	INTEGER		リターン値
--/* 　　　 l_outSqlErrM			OUT	VARCHAR	エラーコメント
--/* 返り値:なし
--/* @version $Revision: 1.8 $
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.02.16	JIP				新規作成
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
	REPORT_ID			CONSTANT char(11)		:= 'IP030001811';	-- 帳票ID
	-- 書式フォーマット
	FMT_HAKKO_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	FMT_RBR_KNGK_J		CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 利払金額
	FMT_SHOKAN_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 償還金額
	-- 書式フォーマット（外資）
	FMT_HAKKO_KNGK_F	CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 発行金額
	FMT_RBR_KNGK_F		CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 利払金額
	FMT_SHOKAN_KNGK_F	CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 償還金額
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd				integer :=	RTN_OK;						-- リターンコード
	gSeqNo				integer := 0;							-- シーケンス
	gOutFlg				numeric	:= 0;							-- リターンフラグ
	gSQL				varchar(3500) := NULL;				-- SQL編集
	-- 書式フォーマット
	gFmtHakkoKngk		varchar(21) := NULL;					-- 発行金額
	gFmtRbrKngk			varchar(21) := NULL;					-- 利払金額
	gFmtShokanKngk		varchar(21) := NULL;					-- 償還金額
	-- DB取得項目
	gIsinCd						MGR_KIHON.ISIN_CD%TYPE;						-- ＩＳＩＮコード
	gMgrCd						MGR_KIHON.MGR_CD%TYPE;						-- 銘柄コード
	gMgrNm						MGR_KIHON.MGR_NM%TYPE;						-- 銘柄の正式名称
	gHakkoYmd					MGR_KIHON.HAKKO_YMD%TYPE;					-- 発行年月日
	gShasaiTotal				MGR_KIHON.SHASAI_TOTAL%TYPE;				-- 社債の総額
	gFullshokanKjt				MGR_KIHON.FULLSHOKAN_KJT%TYPE;				-- 満期償還期日
	gNenrbrCnt					MGR_KIHON.NENRBR_CNT%TYPE;					-- 年利払回数
	gStRbrKjt					MGR_KIHON.ST_RBR_KJT%TYPE;					-- 初回利払期日
	gRbrDd						MGR_KIHON.RBR_DD%TYPE;						-- 利払日付
	gRbrKjtMd1					MGR_KIHON.RBR_KJT_MD1%TYPE;					-- 利払期日（１）
	gRbrKjtMd2					MGR_KIHON.RBR_KJT_MD2%TYPE;					-- 利払期日（２）
	gRbrKjtMd3					MGR_KIHON.RBR_KJT_MD3%TYPE;					-- 利払期日（３）
	gRbrKjtMd4					MGR_KIHON.RBR_KJT_MD4%TYPE;					-- 利払期日（４）
	gRbrKjtMd5					MGR_KIHON.RBR_KJT_MD5%TYPE;					-- 利払期日（５）
	gRbrKjtMd6					MGR_KIHON.RBR_KJT_MD6%TYPE;					-- 利払期日（６）
	gRbrKjtMd7					MGR_KIHON.RBR_KJT_MD7%TYPE;					-- 利払期日（７）
	gRbrKjtMd8					MGR_KIHON.RBR_KJT_MD8%TYPE;					-- 利払期日（８）
	gRbrKjtMd9					MGR_KIHON.RBR_KJT_MD9%TYPE;					-- 利払期日（９）
	gRbrKjtMd10					MGR_KIHON.RBR_KJT_MD10%TYPE;				-- 利払期日（１０）
	gRbrKjtMd11					MGR_KIHON.RBR_KJT_MD11%TYPE;				-- 利払期日（１１）
	gRbrKjtMd12					MGR_KIHON.RBR_KJT_MD12%TYPE;				-- 利払期日（１２）
	gHakkoTsukaCd				MGR_KIHON.HAKKO_TSUKA_CD%TYPE;				-- 発行通貨コード
	gRbrTsukaCd					MGR_KIHON.RBR_TSUKA_CD%TYPE;				-- 利払通貨コード
	gShokanTsukaCd				MGR_KIHON.SHOKAN_TSUKA_CD%TYPE;				-- 償還通貨コード
	gHakkoTsukaNm				MTSUKA.TSUKA_NM%TYPE;						-- 発行通貨名称
	gRbrTsukaNm					MTSUKA.TSUKA_NM%TYPE;						-- 利払通貨名称
	gShokanTsukaNm				MTSUKA.TSUKA_NM%TYPE;						-- 償還通貨名称
	gMgrHenkoKbnMg21			UPD_MGR_KHN.MGR_HENKO_KBN%TYPE;				-- 銘柄情報変更区分
	gShrKjtMg21					UPD_MGR_KHN.SHR_KJT%TYPE;					-- 支払期日
	gEtckaigaiRbrYmd			UPD_MGR_KHN.ETCKAIGAI_RBR_YMD%TYPE;			-- その他海外実利払日
	gKkKanyoFlg					UPD_MGR_KHN.KK_KANYO_FLG%TYPE;				-- 機構関与方式フラグ
	gKkKanyoFlgNm				SCODE.CODE_NM%TYPE;							-- 機構関与方式フラグ名称
	gKobetsuShoninSaiyoFlg		UPD_MGR_KHN.KOBETSU_SHONIN_SAIYO_FLG%TYPE;	-- 個別承認採用フラグ
	gKobetsuShoninSaiyoFlgNm	SCODE.CODE_NM%TYPE;							-- 個別承認採用フラグ名称
	gMgrHenkoKbnMg22			UPD_MGR_RBR.MGR_HENKO_KBN%TYPE;				-- 銘柄情報変更区分
	gShrKjtMg22					UPD_MGR_RBR.SHR_KJT%TYPE;					-- 支払期日
	gRiritsu					UPD_MGR_RBR.RIRITSU%TYPE;					-- 利率
	gTsukarishiKngkMg22			UPD_MGR_RBR.TSUKARISHI_KNGK%TYPE;			-- １通貨当りの利子額
	gMgrHenkoKbnMg23			UPD_MGR_SHN.MGR_HENKO_KBN%TYPE;				-- 銘柄情報変更区分
	gCallallUmuFlg				MGR_KIHON.CALLALL_UMU_FLG%TYPE;				-- コールオプション有無フラグ（全額償還）
	gCallitibuUmuFlg			MGR_KIHON.CALLITIBU_UMU_FLG%TYPE;			-- コールオプション有無フラグ（一部償還）
	gCallallUmuFlgNm			SCODE.CODE_NM%TYPE;							-- コールオプション有無フラグ（全額償還）名称
	gCallitibuUmuFlgNm			SCODE.CODE_NM%TYPE;							-- コールオプション有無フラグ（一部償還）名称
	gShrKjtMg23					UPD_MGR_SHN.SHR_KJT%TYPE;					-- 支払期日
	gShokanPremium				UPD_MGR_SHN.SHOKAN_PREMIUM%TYPE;			-- 償還プレミアム
	gTsukarishiKngkMg23			UPD_MGR_SHN.TSUKARISHI_KNGK%TYPE;			-- １通貨当りの利子額
	gShokanKngk					UPD_MGR_SHN.SHOKAN_KNGK_JIKO%TYPE;			-- 償還額
	gPutumuFlg					MGR_KIHON.PUTUMU_FLG%TYPE;					-- プットオプション有無フラグ
	gPutumuFlgNm				SCODE.CODE_NM%TYPE;							-- プットオプション有無フラグ名称
	gStPutkoshikikanYmd			UPD_MGR_SHN.ST_PUTKOSHIKIKAN_YMD%TYPE;		-- 行使期間開始日
	gEdPutkoshikikanYmd 		UPD_MGR_SHN.ED_PUTKOSHIKIKAN_YMD%TYPE;		-- 行使期間終了日
	gBankRnm					VJIKO_ITAKU.BANK_RNM%TYPE;					-- 銀行略称
	gJikoDaikoKbn				VJIKO_ITAKU.JIKO_DAIKO_KBN%TYPE;			-- 自行代行区分
	-- コールオプション(全額)
	gCallAllKuriageShokanYmd	UPD_MGR_SHN.SHR_KJT%TYPE;					-- 支払期日
	gCallAllPlemiumKngk			UPD_MGR_SHN.SHOKAN_PREMIUM%TYPE;			-- 償還プレミアム
	gCallAllTsukarishiKngk		UPD_MGR_SHN.TSUKARISHI_KNGK%TYPE;			-- １通貨当りの利子額
	-- 定時定額償還
	gTeijiShokanKjt				UPD_MGR_SHN.SHR_KJT%TYPE;					-- 支払期日
	gTeijiShokanKngk			UPD_MGR_SHN.SHOKAN_KNGK_JIKO%TYPE;			-- 償還額
	-- コールオプション(一部償還)
	gCallitibuKuriageShokanKjt	UPD_MGR_SHN.SHR_KJT%TYPE;					-- 支払期日
	gCallitibuPlemiumKngk		UPD_MGR_SHN.SHOKAN_PREMIUM%TYPE;			-- 償還プレミアム
	gCallitibuShokanKngk		UPD_MGR_SHN.SHOKAN_KNGK_JIKO%TYPE;			-- 償還額
	gCallitibuTsukaRishiKngk	UPD_MGR_SHN.TSUKARISHI_KNGK%TYPE;			-- １通貨当りの利子額
	-- プットオプション
	gPutKuriageShokanKjt		UPD_MGR_SHN.SHR_KJT%TYPE;					-- 支払期日
	gPutPlemiumKngk				UPD_MGR_SHN.SHOKAN_PREMIUM%TYPE;			-- 償還プレミアム
	-- 変更有無
	gKaigaicalHenkoUmu				char(2)	:= NULL;					-- 海外カレンダ変更有無
	gKkKanyoHenkoUmu				char(2)	:= NULL;					-- 機構関与方式変更有無
	gKobetsuShoninSaiyoHenkoUmu		char(2)	:= NULL;					-- 個別承認採用変更有無
	gRibaraiHenkoUmu				char(2)	:= NULL;					-- 利払情報変更有無
	gCallallHenkoUmu				char(2)	:= NULL;					-- コールオプション（全額償還）変更有無
	gTeijiShokanHenkoUmu			char(2)	:= NULL;					-- 定時償還変更有無
	gCallItibuHenkoUmu				char(2)	:= NULL;					-- コールオプション（一部償還）変更有無
	gPutHenkoUmu					char(2)	:= NULL;					-- プットオプション変更有無
	-- 利払期日編集
	gRbrKjtMoji					varchar(20) := NULL;					-- 利払期日
	gItakuKaishaRnm			VJIKO_ITAKU.BANK_RNM%TYPE;					-- 委託会社略称
	-- カーソル
	curMeisai refcursor;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp01801 START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(l_inItakuKaishaCd::text, '') = ''
	OR coalesce(l_inUserId::text, '') = ''
	OR coalesce(l_inChohyoKbn::text, '') = ''
	OR coalesce(l_inGyomuYmd::text, '') = ''
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
	-- SQL編集
	gSQL := spIp01801_createSQL(l_inItakuKaishaCd, l_inHktCd, l_inKozaTenCd, l_inKozaTenCifCd, 
		l_inMgrCd, l_inIsinCd, l_inGanriBaraiYmdF, l_inGanriBaraiYmdT);
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	-- カーソルオープン
	OPEN curMeisai FOR EXECUTE gSQL;
	-- データ取得
	LOOP
		FETCH curMeisai INTO	gIsinCd 						-- ＩＳＩＮコード
								,gMgrCd 						-- 銘柄コード
								,gMgrNm 						-- 銘柄の正式名称
								,gHakkoYmd 					-- 発行年月日
								,gShasaiTotal 				-- 社債の総額
								,gFullshokanKjt 				-- 満期償還期日
								,gNenrbrCnt 					-- 年利払回数
								,gStRbrKjt 					-- 初回利払期日
								,gRbrDd 						-- 利払日付
								,gRbrKjtMd1					-- 利払期日（１）
								,gRbrKjtMd2					-- 利払期日（２）
								,gRbrKjtMd3					-- 利払期日（３）
								,gRbrKjtMd4					-- 利払期日（４）
								,gRbrKjtMd5					-- 利払期日（５）
								,gRbrKjtMd6					-- 利払期日（６）
								,gRbrKjtMd7					-- 利払期日（７）
								,gRbrKjtMd8					-- 利払期日（８）
								,gRbrKjtMd9					-- 利払期日（９）
								,gRbrKjtMd10				-- 利払期日（１０）
								,gRbrKjtMd11				-- 利払期日（１１）
								,gRbrKjtMd12				-- 利払期日（１２）
								,gHakkoTsukaCd 				-- 発行通貨コード
								,gRbrTsukaCd 				-- 利払通貨コード
								,gShokanTsukaCd 				-- 償還通貨コード
								,gHakkoTsukaNm 				-- 発行通貨名称
								,gRbrTsukaNm 				-- 利払通貨名称
								,gShokanTsukaNm 				-- 償還通貨名称
								,gMgrHenkoKbnMg21			-- 銘柄情報変更区分
								,gShrKjtMg21				-- 支払期日
								,gEtckaigaiRbrYmd 			-- その他海外実利払日
								,gKkKanyoFlg 				-- 機構関与方式フラグ
								,gKkKanyoFlgNm 				-- 機構関与方式フラグ名称
								,gKobetsuShoninSaiyoFlg 		-- 個別承認採用フラグ
								,gKobetsuShoninSaiyoFlgNm 	-- 個別承認採用フラグ名称
								,gMgrHenkoKbnMg22			-- 銘柄情報変更区分
								,gShrKjtMg22				-- 支払期日
								,gRiritsu 					-- 利率
								,gTsukarishiKngkMg22		-- １通貨当りの利子額
								,gMgrHenkoKbnMg23			-- 銘柄情報変更区分
								,gCallallUmuFlg 				-- コールオプション有無フラグ（全額償還）
								,gCallitibuUmuFlg 			-- コールオプション有無フラグ（一部償還）
								,gCallallUmuFlgNm 			-- コールオプション有無フラグ（全額償還）名称
								,gCallitibuUmuFlgNm 			-- コールオプション有無フラグ（一部償還）名称
								,gShrKjtMg23				-- 支払期日
								,gShokanPremium 				-- 償還プレミアム
								,gTsukarishiKngkMg23		-- １通貨当りの利子額
								,gShokanKngk 				-- 償還額
								,gPutumuFlg 					-- プットオプション有無フラグ
								,gPutumuFlgNm 				-- プットオプション有無フラグ名称
								,gStPutkoshikikanYmd 		-- 行使期間開始日
								,gEdPutkoshikikanYmd  		-- 行使期間終了日
								,gBankRnm 					-- 銀行略称
								,gJikoDaikoKbn 				-- 自行代行区分
								;
		EXIT WHEN NOT FOUND;/* apply on curMeisai */
		gSeqNo := gSeqNo + 1;
		-- 書式フォーマットの設定
		-- 発行
		IF gHakkoTsukaCd = 'JPY' THEN
			gFmtHakkoKngk := FMT_HAKKO_KNGK_J;
		ELSE
			gFmtHakkoKngk := FMT_HAKKO_KNGK_F;
		END IF;
		-- 利払
		IF gRbrTsukaCd = 'JPY' THEN
			gFmtRbrKngk := FMT_RBR_KNGK_J;
		ELSE
			gFmtRbrKngk := FMT_RBR_KNGK_F;
		END IF;
		-- 償還
		IF gShokanTsukaCd = 'JPY' THEN
			gFmtShokanKngk := FMT_SHOKAN_KNGK_J;
		ELSE
			gFmtShokanKngk := FMT_SHOKAN_KNGK_F;
		END IF;
		IF coalesce(trim(both gNenrbrCnt)::text, '') = '' THEN
     		gRbrKjtMoji := ' ';
  		ELSE
	   		-- 利払期日名称の編集
	   		DECLARE
	   			v_outflg integer;
	   		BEGIN
		   		SELECT l_outflg, l_outResult INTO v_outflg, gRbrKjtMoji 
		   		FROM pkRibaraiKijitsu.getRibaraiKijitsu(gNenrbrCnt::integer, gStRbrKjt, gRbrDd);
	   		END;
  		END IF;
		-- 期中銘柄変更(銘柄).銘柄変更区分が'01'(銘柄情報)の時、情報出力(※１)
		IF gMgrHenkoKbnMg21 = '01' THEN
			gKaigaicalHenkoUmu			:= '有';		-- 海外カレンダ変更有無
			gKkKanyoHenkoUmu 			:= '有';		-- 機構関与方式変更有無
			gKobetsuShoninSaiyoHenkoUmu := '有';		-- 個別承認採用変更有無
		ELSE
			gKaigaicalHenkoUmu			:= '無';		-- 海外カレンダ変更有無
			gKkKanyoHenkoUmu 			:= '無';		-- 機構関与方式変更有無
			gKobetsuShoninSaiyoHenkoUmu := '無';		-- 個別承認採用変更有無
			gShrKjtMg21					:= NULL;		-- 支払期日
			gEtckaigaiRbrYmd			:= NULL;		-- その他海外実利払日
			gKkKanyoFlg					:= NULL;		-- 機構関与方式フラグ
			gKkKanyoFlgNm				:= NULL;		-- 機構関与方式フラグ名称
			gKobetsuShoninSaiyoFlg		:= NULL;		-- 個別承認採用フラグ
			gKobetsuShoninSaiyoFlgNm	:= NULL;		-- 個別承認採用フラグ名称
		END IF;
		-- 期中銘柄変更(利払).銘柄情報変更区分が'11'(変動利率)の時、情報出力(※２)
		IF gMgrHenkoKbnMg22 = '11' THEN
			gRibaraiHenkoUmu			:= '有';		-- 利払情報変更有無
		ELSE
			gRibaraiHenkoUmu			:= '無';		-- 利払情報変更有無
			gShrKjtMg22					:= NULL;		-- 支払期日
			gRiritsu					:= NULL;		-- 利率
			gTsukarishiKngkMg22			:= NULL;		-- １通貨当りの利子額
		END IF;
		-- 期中銘柄変更(償還).銘柄情報変更区分が'23'(コールオプション(全額))の時、情報出力(※３)
		IF gMgrHenkoKbnMg23 = '23' THEN
			gCallallHenkoUmu			:= '有';					-- コールオプション（全額償還）変更有無
			gCallAllKuriageShokanYmd	:= gShrKjtMg23;				-- 支払期日
			gCallAllPlemiumKngk			:= gShokanPremium;			-- 償還プレミアム
			gCallAllTsukarishiKngk		:= gTsukarishiKngkMg23;		-- １通貨当りの利子額
		ELSE
			gCallallHenkoUmu			:= '無';					-- コールオプション（全額償還）変更有無
			gCallallUmuFlg				:= NULL;					-- コールオプション有無フラグ（全額償還）
			gCallallUmuFlgNm			:= NULL;					-- コールオプション有無フラグ（全額償還）名称
			gCallAllKuriageShokanYmd	:= NULL;					-- 支払期日
			gCallAllPlemiumKngk			:= NULL;					-- 償還プレミアム
			gCallAllTsukarishiKngk		:= NULL;					-- １通貨当りの利子額
		END IF;
		-- 期中銘柄変更(償還).銘柄情報変更区分が'21'(定時定額償還)の時、情報出力(※４)
		IF gMgrHenkoKbnMg23 = '21' THEN
			gTeijiShokanHenkoUmu		:= '有';					-- 定時償還変更有無
			gTeijiShokanKjt				:= gShrKjtMg23;				-- 支払期日
			gTeijiShokanKngk			:= gShokanKngk;				-- 償還額
		ELSE
			gTeijiShokanHenkoUmu		:= '無';					-- 定時償還変更有無
			gTeijiShokanKjt				:= NULL;					-- 支払期日
			gTeijiShokanKngk			:= NULL;					-- 償還額
		END IF;
		-- 期中銘柄変更(償還).銘柄情報変更区分が'24'(一部)の時、情報出力(※５)
		IF gMgrHenkoKbnMg23 = '24' THEN
			gCallItibuHenkoUmu			:= '有';					-- コールオプション（一部償還）変更有無
			gCallitibuKuriageShokanKjt	:= gShrKjtMg23;				-- 支払期日
			gCallitibuPlemiumKngk		:= gShokanPremium;			-- 償還プレミアム
			gCallitibuShokanKngk		:= gShokanKngk;				-- 償還額
			gCallitibuTsukaRishiKngk	:= gTsukarishiKngkMg23;		-- １通貨当りの利子額
		ELSE
			gCallItibuHenkoUmu			:= '無';					-- コールオプション（一部償還）変更有無
			gCallitibuUmuFlg			:= NULL;					-- コールオプション有無フラグ（一部償還）
			gCallitibuUmuFlgNm			:= NULL;					-- コールオプション有無フラグ（一部償還）名称
			gCallitibuKuriageShokanKjt	:= NULL;					-- 支払期日
			gCallitibuPlemiumKngk		:= NULL;					-- 償還プレミアム
			gCallitibuShokanKngk		:= NULL;					-- 償還額
			gCallitibuTsukaRishiKngk	:= NULL;					-- １通貨当りの利子額
		END IF;
		-- 期中銘柄変更(償還).銘柄情報変更区分が'25'(プットオプション)の時、情報出力(※６)
		IF gMgrHenkoKbnMg23 = '25' THEN
			gPutHenkoUmu				:= '有';					-- プットオプション変更有無
			gPutKuriageShokanKjt		:= gShrKjtMg23;				-- 支払期日
			gPutPlemiumKngk				:= gShokanPremium;			-- 償還プレミアム
		ELSE
			gPutHenkoUmu				:= '無';					-- プットオプション変更有無
			gPutumuFlg					:= NULL;					-- プットオプション有無フラグ
			gPutumuFlgNm				:= NULL;					-- プットオプション有無フラグ名称
			gStPutkoshikikanYmd			:= NULL;					-- 行使期間開始日
			gEdPutkoshikikanYmd			:= NULL; 					-- 行使期間終了日
			gPutKuriageShokanKjt		:= NULL;					-- 支払期日
			gPutPlemiumKngk				:= NULL;					-- 償還プレミアム
		END IF;
		-- 委託会社略称
		gItakuKaishaRnm := NULL;
		IF gJikoDaikoKbn = '2' THEN
			gItakuKaishaRnm := gBankRnm;
		END IF;
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := gIsinCd;	-- ＩＳＩＮコード
		v_item.l_inItem003 := gMgrCd;	-- 銘柄コード
		v_item.l_inItem004 := gMgrNm;	-- 銘柄の正式名称
		v_item.l_inItem005 := gHakkoYmd;	-- 発行年月日
		v_item.l_inItem006 := gShasaiTotal;	-- 社債の総額
		v_item.l_inItem007 := gFullshokanKjt;	-- 満期償還期日
		v_item.l_inItem008 := gRbrKjtMoji;	-- 利払日
		v_item.l_inItem009 := gHakkoTsukaNm;	-- 発行通貨名称
		v_item.l_inItem010 := gRbrTsukaNm;	-- 利払通貨名称
		v_item.l_inItem011 := gShokanTsukaNm;	-- 償還通貨名称
		v_item.l_inItem012 := gKaigaicalHenkoUmu;	-- 海外カレンダ変更有無				(※１)
		v_item.l_inItem013 := gShrKjtMg21;	-- 支払期日							(※１)
		v_item.l_inItem014 := gEtckaigaiRbrYmd;	-- その他海外実利払日				(※１)
		v_item.l_inItem015 := gKkKanyoHenkoUmu;	-- 機構関与方式変更有無				(※１)
		v_item.l_inItem016 := gKkKanyoFlg;	-- 機構関与方式フラグ				(※１)
		v_item.l_inItem017 := gKkKanyoFlgNm;	-- 機構関与方式フラグ名称			(※１)
		v_item.l_inItem018 := gKobetsuShoninSaiyoHenkoUmu;	-- 個別承認採用変更有無				(※１)
		v_item.l_inItem019 := gKobetsuShoninSaiyoFlg;	-- 個別承認採用フラグ				(※１)
		v_item.l_inItem020 := gKobetsuShoninSaiyoFlgNm;	-- 個別承認採用フラグ名称			(※１)
		v_item.l_inItem021 := gRibaraiHenkoUmu;	-- 利払情報変更有無					(※２)
		v_item.l_inItem022 := gShrKjtMg22;	-- 支払期日							(※２)
		v_item.l_inItem023 := gRiritsu;	-- 利率								(※２)
		v_item.l_inItem024 := gTsukarishiKngkMg22;	-- １通貨当りの利子額				(※２)
		v_item.l_inItem025 := gCallallHenkoUmu;	-- コールオプション(全額償還)変更有無		(※３)
		v_item.l_inItem026 := gCallallUmuFlg;	-- コールオプション有無フラグ(全額償還)		(※３)
		v_item.l_inItem027 := gCallallUmuFlgNm;	-- コールオプション有無フラグ(全額償還)名称	(※３)
		v_item.l_inItem028 := gCallAllKuriageShokanYmd;	-- 支払期日							(※３)
		v_item.l_inItem029 := gCallAllPlemiumKngk;	-- 償還プレミアム					(※３)
		v_item.l_inItem030 := gCallAllTsukarishiKngk;	-- １通貨当りの利子額				(※３)
		v_item.l_inItem031 := gTeijiShokanHenkoUmu;	-- 定時償還変更有無					(※４)
		v_item.l_inItem032 := gTeijiShokanKjt;	-- 支払期日							(※４)
		v_item.l_inItem033 := gTeijiShokanKngk;	-- 償還額							(※４)
		v_item.l_inItem034 := gCallItibuHenkoUmu;	-- コールオプション(一部償還)変更有無		(※５)
		v_item.l_inItem035 := gCallitibuUmuFlg;	-- コールオプション有無フラグ(一部償還)		(※５)
		v_item.l_inItem036 := gCallitibuUmuFlgNm;	-- コールオプション有無フラグ(一部償還)名称	(※５)
		v_item.l_inItem037 := gCallitibuKuriageShokanKjt;	-- 支払期日							(※５)
		v_item.l_inItem038 := gCallitibuPlemiumKngk;	-- 償還プレミアム					(※５)
		v_item.l_inItem039 := gCallitibuShokanKngk;	-- 償還額							(※５)
		v_item.l_inItem040 := gCallitibuTsukaRishiKngk;	-- １通貨当りの利子額				(※５)
		v_item.l_inItem041 := gPutHenkoUmu;	-- プットオプション変更有無			(※６)
		v_item.l_inItem042 := gPutumuFlg;	-- プットオプション有無フラグ		(※６)
		v_item.l_inItem043 := gPutumuFlgNm;	-- プットオプション有無フラグ名称	(※６)
		v_item.l_inItem044 := gStPutkoshikikanYmd;	-- 行使期間開始日					(※６)
		v_item.l_inItem045 := gEdPutkoshikikanYmd;	-- 行使期間終了日					(※６)
		v_item.l_inItem046 := gPutKuriageShokanKjt;	-- 支払期日							(※６)
		v_item.l_inItem047 := gPutPlemiumKngk;	-- 償還プレミアム					(※６)
		v_item.l_inItem048 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem049 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem050 := gFmtHakkoKngk;	-- 発行金額書式フォーマット
		v_item.l_inItem051 := gFmtRbrKngk;	-- 利払金額書式フォーマット
		v_item.l_inItem052 := gFmtShokanKngk;	-- 償還金額書式フォーマット
		
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
		v_item.l_inItem049 := REPORT_ID;
		v_item.l_inItem050 := FMT_HAKKO_KNGK_J;
		v_item.l_inItem051 := FMT_RBR_KNGK_J;
		v_item.l_inItem052 := FMT_SHOKAN_KNGK_J;
		v_item.l_inItem053 := '対象データなし';
		
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
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp01801 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		BEGIN
			CLOSE curMeisai;
		EXCEPTION
			WHEN OTHERS THEN
				NULL;  -- Ignore if cursor not open
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
-- REVOKE ALL ON PROCEDURE spip01801 ( l_inHktCd TEXT, l_inKozaTenCd TEXT, l_inKozaTenCifCd TEXT, l_inMgrCd TEXT, l_inIsinCd TEXT, l_inGanriBaraiYmdF TEXT, l_inGanriBaraiYmdT TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT integer, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spip01801_createsql (
	l_inItakuKaishaCd TEXT,
	l_inHktCd TEXT,
	l_inKozaTenCd TEXT,
	l_inKozaTenCifCd TEXT,
	l_inMgrCd TEXT,
	l_inIsinCd TEXT,
	l_inGanriBaraiYmdF TEXT,
	l_inGanriBaraiYmdT TEXT
) RETURNS TEXT AS $body$
DECLARE
	gSQL varchar(3500);
BEGIN
	gSQL := '';
	gSQL := gSQL || 'SELECT VMG1.ISIN_CD,';										-- ＩＳＩＮコード
	gSQL := gSQL || '		VMG1.MGR_CD,';										-- 銘柄コード
	gSQL := gSQL || '		VMG1.MGR_NM,';										-- 銘柄の正式名称
	gSQL := gSQL || '		VMG1.HAKKO_YMD,';									-- 発行年月日
	gSQL := gSQL || '		VMG1.SHASAI_TOTAL,';								-- 社債の総額
	gSQL := gSQL || '		VMG1.FULLSHOKAN_KJT,';								-- 満期償還期日
	gSQL := gSQL || '		VMG1.NENRBR_CNT,';									-- 年利払回数
	gSQL := gSQL || '		VMG1.ST_RBR_KJT,';									-- 初回利払期日
	gSQL := gSQL || '		VMG1.RBR_DD,';										-- 利払日付
	gSQL := gSQL || '		VMG1.RBR_KJT_MD1,';									-- 利払期日（１）
	gSQL := gSQL || '		VMG1.RBR_KJT_MD2,';									-- 利払期日（２）
	gSQL := gSQL || '		VMG1.RBR_KJT_MD3,';									-- 利払期日（３）
	gSQL := gSQL || '		VMG1.RBR_KJT_MD4,';									-- 利払期日（４）
	gSQL := gSQL || '		VMG1.RBR_KJT_MD5,';									-- 利払期日（５）
	gSQL := gSQL || '		VMG1.RBR_KJT_MD6,';									-- 利払期日（６）
	gSQL := gSQL || '		VMG1.RBR_KJT_MD7,';									-- 利払期日（７）
	gSQL := gSQL || '		VMG1.RBR_KJT_MD8,';									-- 利払期日（８）
	gSQL := gSQL || '		VMG1.RBR_KJT_MD9,';									-- 利払期日（９）
	gSQL := gSQL || '		VMG1.RBR_KJT_MD10,';								-- 利払期日（１０）
	gSQL := gSQL || '		VMG1.RBR_KJT_MD11,';								-- 利払期日（１１）
	gSQL := gSQL || '		VMG1.RBR_KJT_MD12,';								-- 利払期日（１２）
	gSQL := gSQL || '		VMG1.HAKKO_TSUKA_CD,';								-- 発行通貨コード
	gSQL := gSQL || '		VMG1.RBR_TSUKA_CD,';								-- 利払通貨コード
	gSQL := gSQL || '		VMG1.SHOKAN_TSUKA_CD,';								-- 償還通貨コード
	gSQL := gSQL || '		M641.TSUKA_NM AS HAKKO_TSUKA_NM,';					-- 発行通貨名称
	gSQL := gSQL || '		M642.TSUKA_NM AS RBR_TSUKA_NM,';					-- 利払通貨名称
	gSQL := gSQL || '		M643.TSUKA_NM AS SHOKAN_TSUKA_NM,';					-- 償還通貨名称
	gSQL := gSQL || '		MG21.MGR_HENKO_KBN AS MGR_HENKO_KBN_MG21,';			-- 銘柄情報変更区分
	gSQL := gSQL || '		MG21.SHR_KJT AS SHR_KJT_MG21,';						-- 支払期日
	gSQL := gSQL || '		MG21.ETCKAIGAI_RBR_YMD,';							-- その他海外実利払日
	gSQL := gSQL || '		MG21.KK_KANYO_FLG,';								-- 機構関与方式フラグ
	gSQL := gSQL || '		MCD1.CODE_NM AS KK_KANYO_FLG_NM,';					-- 機構関与方式フラグ名称
	gSQL := gSQL || '		MG21.KOBETSU_SHONIN_SAIYO_FLG,';					-- 個別承認採用フラグ
	gSQL := gSQL || '		MCD2.CODE_NM AS KOBETSU_SHONIN_SAIYO_FLG_NM,';		-- 個別承認採用フラグ名称
	gSQL := gSQL || '		MG22.MGR_HENKO_KBN AS MGR_HENKO_KBN_MG22,';			-- 銘柄情報変更区分
	gSQL := gSQL || '		MG22.SHR_KJT AS SHR_KJT_MG22,';						-- 支払期日
	gSQL := gSQL || '		MG22.RIRITSU,';										-- 利率
	gSQL := gSQL || '		MG22.TSUKARISHI_KNGK AS TSUKARISHI_KNGK_MG22,';		-- １通貨当りの利子額
	gSQL := gSQL || '		MG23.MGR_HENKO_KBN AS MGR_HENKO_KBN_MG23,';			-- 銘柄情報変更区分
	gSQL := gSQL || '		VMG1.CALLALL_UMU_FLG,';								-- コールオプション有無フラグ（全額償還）
	gSQL := gSQL || '		VMG1.CALLITIBU_UMU_FLG,';							-- コールオプション有無フラグ（一部償還）
	gSQL := gSQL || '		MCD3.CODE_NM AS CALLALL_UMU_FLG_NM,';				-- コールオプション有無フラグ（全額償還）名称
	gSQL := gSQL || '		MCD4.CODE_NM AS CALLITIBU_UMU_FLG_NM,';				-- コールオプション有無フラグ（一部償還）名称
	gSQL := gSQL || '		MG23.SHR_KJT AS SHR_KJT_MG23,';						-- 支払期日
	gSQL := gSQL || '		MG23.SHOKAN_PREMIUM,';								-- 償還プレミアム
	gSQL := gSQL || '		MG23.TSUKARISHI_KNGK AS TSUKARISHI_KNGK_MG23,';		-- １通貨当りの利子額
	gSQL := gSQL || '		MG23.SHOKAN_KNGK_JIKO,';							-- 償還額
	gSQL := gSQL || '		VMG1.PUTUMU_FLG,';									-- プットオプション有無フラグ
	gSQL := gSQL || '		MCD5.CODE_NM AS PUTUMU_FLG_NM,';					-- プットオプション有無フラグ名称
	gSQL := gSQL || '		MG23.ST_PUTKOSHIKIKAN_YMD,';						-- 行使期間開始日
	gSQL := gSQL || '		MG23.ED_PUTKOSHIKIKAN_YMD,';						-- 行使期間終了日
	gSQL := gSQL || '		VJ1.BANK_RNM,';										-- 銀行略称
	gSQL := gSQL || '		VJ1.JIKO_DAIKO_KBN ';								-- 自行代行区分
	gSQL := gSQL || 'FROM 	VMGR_LIST VMG1 ';									-- 銘柄情報一覧VIEW
	gSQL := gSQL || 'LEFT OUTER JOIN UPD_MGR_KHN MG21 ON (VMG1.MGR_CD = MG21.MGR_CD AND VMG1.ITAKU_KAISHA_CD = MG21.ITAKU_KAISHA_CD AND MG21.SHORI_KBN = ''1'') ';
	gSQL := gSQL || 'LEFT OUTER JOIN UPD_MGR_RBR MG22 ON (VMG1.MGR_CD = MG22.MGR_CD AND VMG1.ITAKU_KAISHA_CD = MG22.ITAKU_KAISHA_CD AND MG22.SHORI_KBN = ''1'') ';
	gSQL := gSQL || 'LEFT OUTER JOIN UPD_MGR_SHN MG23 ON (VMG1.MGR_CD = MG23.MGR_CD AND VMG1.ITAKU_KAISHA_CD = MG23.ITAKU_KAISHA_CD AND MG23.SHORI_KBN = ''1'') ';
	gSQL := gSQL || 'INNER JOIN VJIKO_ITAKU VJ1 ON (VJ1.KAIIN_ID = ''' || l_inItakuKaishaCd || ''') ';
	gSQL := gSQL || 'INNER JOIN MTSUKA M641 ON (VMG1.HAKKO_TSUKA_CD = M641.TSUKA_CD) ';
	gSQL := gSQL || 'INNER JOIN MTSUKA M642 ON (VMG1.RBR_TSUKA_CD = M642.TSUKA_CD) ';
	gSQL := gSQL || 'INNER JOIN MTSUKA M643 ON (VMG1.SHOKAN_TSUKA_CD = M643.TSUKA_CD) ';
	gSQL := gSQL || 'LEFT OUTER JOIN SCODE MCD1 ON (MG21.KK_KANYO_FLG = MCD1.CODE_VALUE AND MCD1.CODE_SHUBETSU = ''505'') ';
	gSQL := gSQL || 'LEFT OUTER JOIN SCODE MCD2 ON (MG21.KOBETSU_SHONIN_SAIYO_FLG = MCD2.CODE_VALUE AND MCD2.CODE_SHUBETSU = ''511'') ';
	gSQL := gSQL || 'LEFT OUTER JOIN SCODE MCD3 ON (VMG1.CALLALL_UMU_FLG = MCD3.CODE_VALUE AND MCD3.CODE_SHUBETSU = ''101'') ';
	gSQL := gSQL || 'LEFT OUTER JOIN SCODE MCD4 ON (VMG1.CALLITIBU_UMU_FLG = MCD4.CODE_VALUE AND MCD4.CODE_SHUBETSU = ''101'') ';
	gSQL := gSQL || 'LEFT OUTER JOIN SCODE MCD5 ON (VMG1.PUTUMU_FLG = MCD5.CODE_VALUE AND MCD5.CODE_SHUBETSU = ''101'') ';
	gSQL := gSQL || 'WHERE 	VMG1.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' ';
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
	IF (l_inGanriBaraiYmdF IS NOT NULL AND l_inGanriBaraiYmdF::text <> '') THEN
		gSQL := gSQL || 'AND 	MG21.SHR_KJT >= ''' || l_inGanriBaraiYmdF || ''' ';
	END IF;
	IF (l_inGanriBaraiYmdT IS NOT NULL AND l_inGanriBaraiYmdT::text <> '') THEN
		gSQL := gSQL || 'AND 	MG21.SHR_KJT <= ''' || l_inGanriBaraiYmdT || ''' ';
	END IF;
	IF (l_inGanriBaraiYmdF IS NOT NULL AND l_inGanriBaraiYmdF::text <> '') THEN
		gSQL := gSQL || 'AND 	MG22.SHR_KJT >= ''' || l_inGanriBaraiYmdF || ''' ';
	END IF;
	IF (l_inGanriBaraiYmdT IS NOT NULL AND l_inGanriBaraiYmdT::text <> '') THEN
		gSQL := gSQL || 'AND 	MG22.SHR_KJT <= ''' || l_inGanriBaraiYmdT || ''' ';
	END IF;
	IF (l_inGanriBaraiYmdF IS NOT NULL AND l_inGanriBaraiYmdF::text <> '') THEN
		gSQL := gSQL || 'AND 	MG23.SHR_KJT >= ''' || l_inGanriBaraiYmdF || ''' ';
	END IF;
	IF (l_inGanriBaraiYmdT IS NOT NULL AND l_inGanriBaraiYmdT::text <> '') THEN
		gSQL := gSQL || 'AND 	MG23.SHR_KJT <= ''' || l_inGanriBaraiYmdT || ''' ';
	END IF;
	gSQL := gSQL || 'ORDER BY 	VMG1.ISIN_CD ';
	
	RETURN gSQL;
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spip01801_createsql () FROM PUBLIC;