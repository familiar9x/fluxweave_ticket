


DROP TYPE IF EXISTS spip01901_type_record CASCADE;
CREATE TYPE spip01901_type_record AS (
		gKijunKinriCd1            char(3)                            -- 基準金利コード１
		,gKinriMax                 char(3)                            -- 基準金利（上限）
		,gKinriMaxKinri            varchar(11)                       -- 基準金利（上限）金利	
		,gKinriMaxSpread           varchar(11)                       -- 基準金利（上限）スプレッド
		,gMaxKinri                 varchar(11)                       -- 上限金利
		,gKinriMaxTekiyoriritru    varchar(11)                       -- 基準金利（上限）適用利率
		,gKinriFloor               char(3)                            -- 基準金利（下限）
		,gKinriFloorKinri          varchar(11)                       -- 基準金利（下限）金利
		,gKinriFloorSpread         varchar(11)                       -- 基準金利（下限）スプレッド
		,gFloorKinri               varchar(11)                       -- 下限金利
		,gFloorKinriTekiyoriritru  varchar(11)                       -- 基準金利（下限）適用利率
		,gTekiyoUmu                char(1)                            -- 上限・下限適用有無
		,gKinriMaxNm               varchar(30)                       -- 基準金利（上限）_基準金利名称
		,gKinriMaxGaiyo            varchar(200)                      -- 基準金利（上限）_基準金利概要
		,gKinriFloorNm             varchar(30)                       -- 基準金利（下限）_基準金利名称
		,gKinriFloorGaiyo          varchar(200)                      -- 基準金利（下限）_基準金利概要
		,gKijunKinriCd1Nm          varchar(30)                       -- 基準金利コード１_基準金利名称
		,gKijunKinriCd1Gaiyo       varchar(200)                      -- 基準金利コード１_基準金利概要
		,gShoriKbn                 varchar(1)                        -- 処理区分
		,gMgrHenkoKbn              varchar(2)                        -- 銘柄情報変更区分
		,gMgrCd                     varchar(13)                      -- 銘柄コード
	);

DROP TYPE IF EXISTS spip01901_coupon_result CASCADE;
CREATE TYPE spip01901_coupon_result AS (
		gCoupon1 varchar(100),
		gCoupon2 varchar(100),
		gCoupon3 varchar(200),
		gCapFloorTekiyoNm varchar(50)
	);

DROP TYPE IF EXISTS spip01901_updmgr_result CASCADE;
CREATE TYPE spip01901_updmgr_result AS (
		recUpdMgr spip01901_type_record,
		gSakuseiDt varchar(8),
		gShoninDt varchar(8)
	);

CREATE OR REPLACE PROCEDURE spip01901 ( l_inHktCd TEXT,		-- 発行体コード
 l_inKozaTenCd TEXT,		-- 口座店コード
 l_inKozaTenCifCd TEXT,		-- 口座店CIFコード
 l_inMgrCd TEXT,		-- 銘柄コード
 l_inIsinCd TEXT,		-- ISINコード
 l_inKijunYmdF TEXT,		-- 基準日(From)
 l_inKijunYmdT TEXT,		-- 基準日(To)
 l_inTsuchiYmd TEXT,		-- 通知日
 l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inUserId TEXT,		-- ユーザーID
 l_inHendoRiritsuShoninDtFlg TEXT,		-- 変動利率承認日フラグ
 l_inChohyoKbn TEXT,		-- 帳票区分
 l_inGyomuYmd TEXT,		-- 業務日付
 l_outSqlCode OUT integer,		-- リターン値
 l_outSqlErrM OUT text	-- エラーコメント
 ) AS $body$
DECLARE

--
--/* 著作権:Copyright(c)2004
--/* 会社名:JIP
--/* 概要　:顧客宛帳票出力指示画面の入力条件により、変動利率決定通知を作成する。
--/* 引数　:l_inHktCd				IN	TEXT		発行体コード
--/* 　　　 l_inKozaTenCd			IN	TEXT		口座店コード
--/* 　　　 l_inKozaTenCifCd		IN	TEXT		口座店CIFコード
--/* 　　　 l_inMgrCd				IN	TEXT		銘柄コード
--/* 　　　 l_inIsinCd			IN	TEXT		ISINコード
--/* 　　　 l_inKijunYmdF			IN	TEXT		基準日(From)
--/* 　　　 l_inKijunYmdT			IN	TEXT		基準日(To)
--/* 　　　 l_inTsuchiYmd			IN	TEXT		通知日
--/* 　　　 l_inItakuKaishaCd		IN	TEXT		委託会社コード
--/* 　　　 l_inUserId			IN	TEXT		ユーザーID
--/* 　　　 l_inHendoRiritsuShoninDtFlg			IN	TEXT		変動利率承認日フラグ
--/* 　　　 l_inChohyoKbn			IN	TEXT		帳票区分
--/* 　　　 l_inGyomuYmd			IN	TEXT		業務日付
--/* 　　　 l_outSqlCode			OUT	INTEGER		リターン値
--/* 　　　 l_outSqlErrM			OUT	VARCHAR	エラーコメント
--/* 返り値:なし
--/* @version $Id: SPIP01901.SQL,v 1.43 2014/05/14 08:31:10 nakamura Exp $
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.02.15	JIP				新規作成
--/*　2005.10.25	海老澤(ASK)		更新
--/*　2013.08.01	四宮　芳紀			更新
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
	RTN_OK				CONSTANT integer		:= 0;					-- 正常
	RTN_NG				CONSTANT integer		:= 1;					-- 予期したエラー
	RTN_NODATA			CONSTANT integer		:= 2;					-- データなし
	RTN_FATAL			CONSTANT integer		:= 99;					-- 予期せぬエラー
	REPORT_ID			CONSTANT char(11)		:= 'IP030001911';		-- 帳票ID
	-- 書式フォーマット
	FMT_HAKKO_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	FMT_RBR_KNGK_J		CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 利払金額
	FMT_SHOKAN_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 償還金額
	TSUCHI_YMD_DEF		CONSTANT char(14)	:= '    年  月  日';		-- 入力通知日
	-- 書式フォーマット（外資）
	FMT_HAKKO_KNGK_F	CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 発行金額
	FMT_RBR_KNGK_F		CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 利払金額
	FMT_SHOKAN_KNGK_F	CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 償還金額
	-- 利子額文言
	RISHIGAKU_COMMENT	CONSTANT varchar(4)	:= '※１';
	RISHIGAKU_BUN		CONSTANT varchar(72)	:= '※１　各社債当りの利子額を算出の上、１通貨当りの利子額に換算しています。';
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd					integer :=	RTN_OK;						-- リターンコード
	gSeqNo					integer := 0;							-- シーケンス
	gSQL					varchar(10000) := NULL;				-- SQL編集
	-- 書式フォーマット
	gFmtHakkoKngk			varchar(21) := NULL;					-- 発行金額
	gFmtRbrKngk				varchar(21) := NULL;					-- 利払金額
	gFmtShokanKngk			varchar(21) := NULL;					-- 償還金額
	-- DB取得項目
	gHktCd						MHAKKOTAI.HKT_CD%TYPE;					-- 発行体コード
	gSfskPostNo					MHAKKOTAI.SFSK_POST_NO%TYPE;			-- 送付先郵便番号
	gAdd1						MHAKKOTAI.ADD1%TYPE;					-- 送付先住所１
	gAdd2						MHAKKOTAI.ADD2%TYPE;					-- 送付先住所２
	gAdd3						MHAKKOTAI.ADD3%TYPE;					-- 送付先住所３
	gHktNm						MHAKKOTAI.HKT_NM%TYPE;					-- 発行体名称
	gSfskBushoNm				MHAKKOTAI.SFSK_BUSHO_NM%TYPE;			-- 送付先担当部署名称
	gBankNm						MBANK.BANK_NM%TYPE;						-- 金融機関名称
	gBushoNm					MBANK_SFSK.BUSHO_NM%TYPE;				-- 担当部署名称
	gIsinCd						MGR_KIHON.ISIN_CD%TYPE;					-- ＩＳＩＮコード
	gMgrCd						MGR_KIHON.MGR_CD%TYPE;					-- 銘柄コード
	gMgrNm						MGR_KIHON.MGR_NM%TYPE;					-- 銘柄の正式名称
	gKakushasaiKngk				MGR_KIHON.KAKUSHASAI_KNGK%TYPE;			-- 各社債の金額
	gHakkoTsukaCd				MGR_KIHON.HAKKO_TSUKA_CD%TYPE;			-- 発行通貨コード
	gRbrTsukaCd					MGR_KIHON.RBR_TSUKA_CD%TYPE;			-- 利払通貨コード
	gShokanTsukaCd				MGR_KIHON.SHOKAN_TSUKA_CD%TYPE;			-- 償還通貨コード
	gNenRbrCnt					MGR_KIHON.NENRBR_CNT%TYPE;				-- 年利払回数
	gRbrTsukaNm					MTSUKA.TSUKA_NM%TYPE;					-- 利払通貨名称
	gKijunKinriNm1				SCODE.CODE_NM%TYPE;						-- 基準金利１名称
	gKijunKinriNm2				SCODE.CODE_NM%TYPE;						-- 基準金利２名称
	gSpread						char(11);								-- スプレッド
	gKaiji						MGR_RBRKIJ.KAIJI%TYPE;					-- 回次
	gRiritsu					numeric;							-- 利率
	gKijunKinriRrt1				char(11);								-- 基準金利１
	gKijunKinriRrt2				char(11);								-- 基準金利２
	gKijunKinriCmnt				MGR_KIHON.KIJUN_KINRI_CMNT%TYPE;		-- 基準金利コメント
	gStRbrKjt					MGR_KIHON.ST_RBR_KJT%TYPE;				-- 初回利払期日
	gShrKjt						UPD_MGR_RBR.SHR_KJT%TYPE;				-- 支払期日
	gRbrYmd						MGR_RBRKIJ.RBR_YMD%TYPE;				-- 利払日
	gRbrKawaseRate				MGR_RBRKIJ.RBR_KAWASE_RATE%TYPE;		-- 利払為替レート
	gSpananbunBunshi			MGR_RBRKIJ.SPANANBUN_BUNSHI%TYPE;		-- 日数按分分子
	gSpananbunBunbo				MGR_RBRKIJ.SPANANBUN_BUNBO%TYPE;		-- 日数按分分母
	gRknCalcFYmd				MGR_RBRKIJ.RKN_CALC_F_YMD%TYPE;			-- 利金計算期間ＦＲＯＭ
	gRknCalcTYmd				MGR_RBRKIJ.RKN_CALC_T_YMD%TYPE;			-- 利金計算期間ＴＯ
	gRknRoundProcessKbn			MGR_KIHON.RKN_ROUND_PROCESS%TYPE;		-- 利金計算単位未満端数処理区分
	gRknRoundProcessNm			SCODE.CODE_NM%TYPE;						-- 利金計算単位未満端数処理名称
	gNextRiritsuKetteiYmd		MGR_RBRKIJ.RIRITSU_KETTEI_YMD%TYPE;		-- 次回利率決定日
--	gRisokuKngk					NUMERIC(14, 2);							-- 利息金額
	gRisokuKngk					varchar(17);							-- 利息金額
	gRiritsuKeisanKikan			numeric;									-- 利払計算期間（日数）
	gRbrTaishoZndk				varchar(14);							-- 利払対象残高
	gZndkKijunYmd				varchar(8);							-- 残高基準日
	gZndkKakuteiKbn				MGR_KIHON.KKN_ZNDK_KAKUTEI_KBN%TYPE;	-- 基金残高確定区分
	gHakkoYmd					MGR_KIHON.HAKKO_YMD%TYPE;				-- 発行日
	gTokureiShasaiFlg			MGR_KIHON.TOKUREI_SHASAI_FLG%TYPE;		-- 特例社債フラグ
	-- 西暦変換用
	gWrkShrYmd					varchar(20) := NULL;			-- 支払期日
	gWrkRknCalcFYmd				varchar(20) := NULL;			-- 利金計算期間ＦＲＯＭ
	gWrkRknCalcTYmd				varchar(20) := NULL;			-- 利金計算期間ＴＯ
	gWrkNextRiritsuKetteiYmd	varchar(20) := NULL;			-- 次回利率決定日
	gWrkTsuchiYmd				varchar(16) := NULL;			-- 通知日(西暦)
	gAtena						varchar(200) := NULL;			-- 宛名
	gOutflg						integer := 0;					-- 正常処理フラグ
	gRisokuKngkCalc				varchar(90) := NULL;			-- 利息金額(計算式)
	gTsukaRishiKngk				MGR_RBRKIJ.TSUKARISHI_KNGK%TYPE := NULL;	-- １通貨当たりの利子額
	gTsukaRishiKngkChk			MGR_RBRKIJ.TSUKARISHI_KNGK%TYPE := NULL;	-- １通貨当たりの利子額(金額のチェック用)
	gTsukaRishiKngk_S			MGR_RBRKIJ.TSUKARISHI_KNGK_S%TYPE := NULL;	-- １通貨当たりの利子額(算出値)
	gTsukaRishiCalc				varchar(90) := NULL;						-- １通貨当たりの利子額(計算式)
	gTsukaRishiCalc1			varchar(120) := NULL;						-- １通貨当たりの利子額(計算式)1
	gTsukaRishiCalc2			varchar(120) := NULL;						-- １通貨当たりの利子額(計算式)2
	gTsukaRishiCalc3			varchar(120) := NULL;						-- １通貨当たりの利子額(計算式)3
	gTsukaRishiKawaseRate		varchar(40) := NULL;						-- １通貨当たりの利子額(利払為替レート)
	gTsukaRishiKngkKakushasai	numeric := 0;								-- 各社債当りの利子額
	gJitsuNissuCalcKbn			MGR_KIHON.KICHU_NISSUKSN_KBN%TYPE;				-- 実日数計算区分
	gCoupon1					varchar(100) := NULL;			-- クーポン条件１ 
	gCoupon2					varchar(100) := NULL;			-- クーポン条件２
	gCoupon3					varchar(200) := NULL;			-- クーポン条件３
	gRiwatariNo					varchar(3);						-- 利渡期番号
	CTL_VALUE					MPROCESS_CTL.CTL_VALUE%TYPE;		-- 処理制御フラグ
	gChohyoSortFlg				MPROCESS_CTL.CTL_VALUE%TYPE;		-- 発行体宛帳票ソート順変更フラグ
	gChohyoHankoFileNm			varchar(400);						-- 帳票印影の画像ファイルの絶対パス
	gKetteibiOutUmuFlg          MPROCESS_CTL.CTL_VALUE%TYPE;         -- 利率決定日出力有無フラグ
	gKozaTenCd                  MHAKKOTAI.KOZA_TEN_CD%TYPE;          -- 口座店コード
	gKozaTenCifcd               MHAKKOTAI.KOZA_TEN_CIFCD%TYPE;       -- 口座店ＣＩＦコード
	gMgrKihonKinriCd2           MGR_KIHON.KIJUN_KINRI_CD2%TYPE;      -- 基準金利コード２
	gKijunKinriNm3              varchar(30);                        -- 基準金利２名称
	gShihyoukinriNmEtc          varchar(200);                       -- その他指標金利コード内容
	gCapFloorTekiyoNm           varchar(50);                        -- ＣＡＰ・ＦＬＯＯＲ適用名称
	gDispatchFlg                char(1);                             -- 請求書発送区分
	gKyotenKbn                  char(1);                             -- 拠点区分
	gShoriKbn                   MHAKKOTAI.SHORI_KBN%TYPE;            -- 処理区分
	gSakuseiDt                  varchar(20);                        -- 作成日時
	gShoninDt                   varchar(20);                        -- 承認日時
	-- 配列定義
	recUpdMgrRbr2 spIp01901_TYPE_RECORD;  -- 期中銘柄変更（利払）２のレコード
	recUpdMgrShn2 spIp01901_TYPE_RECORD;  -- 期中銘柄変更（償還）２のレコード
	-- カーソル
	curMeisai refcursor;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp01901 START');	END IF;
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
	--発行体宛帳票ソート順変更フラグ取得(銘柄コード順に設定変更 2013/9対応)
	--gChohyoSortFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'spIp019011', '0');
	-- - 利率決定日出力有無フラグ
	gKetteibiOutUmuFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'KetteibiOutUmu', '0');
	-- SQL編集
	gSQL := spIp01901_createSQL(l_inItakuKaishaCd, l_inHendoRiritsuShoninDtFlg, l_inKijunYmdF, l_inKijunYmdT, 
		l_inHktCd, l_inKozaTenCd, l_inKozaTenCifCd, l_inMgrCd, l_inIsinCd, l_inGyomuYmd);
	-- 通知日の西暦変換
	IF (trim(both l_inTsuchiYmd) IS NOT NULL AND (trim(both l_inTsuchiYmd))::text <> '') THEN
		gWrkTsuchiYmd := pkDate.seirekiChangeSuppressNenGappi(l_inTsuchiYmd);
	ELSE
		gWrkTsuchiYmd := TSUCHI_YMD_DEF;
	END IF;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	-- 処理制御マスタで通貨あたり利子額算出式を制御する
	CTL_VALUE := pkControl.getCtlValue(l_inItakuKaishaCd, 'sfTsukarishiKng', '0');
	-- 帳票印影の画像ファイルの絶対パスを取得する
	gChohyoHankoFileNm := pkIpaChohyoHanko.getChohyoHankoFileName(l_inItakuKaishaCd);
	-- カーソルオープン
	OPEN curMeisai FOR EXECUTE gSQL;
	-- データ取得
	LOOP
		FETCH curMeisai INTO	gHktCd 					-- 発行体コード
								,gSfskPostNo 			-- 送付先郵便番号
								,gAdd1					-- 送付先住所１
								,gAdd2					-- 送付先住所２
								,gAdd3					-- 送付先住所３
								,gHktNm 					-- 発行体名称
								,gSfskBushoNm 			-- 送付先担当部署名称
								,gBankNm 				-- 銀行名称
								,gBushoNm 				-- 担当部署名称１
								,gIsinCd 				-- ＩＳＩＮコード
								,gMgrCd 					-- 銘柄コード
								,gMgrNm 					-- 銘柄の正式名称
								,gHakkoYmd 				-- 発行日
								,gKakushasaiKngk 		-- 各社債の金額
								,gHakkoTsukaCd 			-- 発行通貨コード
								,gRbrTsukaCd 			-- 利払通貨コード
								,gShokanTsukaCd 			-- 償還通貨コード
								,gNenRbrCnt 				-- 年利払回数
								,gZndkKakuteiKbn 		-- 基金残高確定区分
								,gTokureiShasaiFlg 		-- 特例社債フラグ
								,gRbrTsukaNm 			-- 利払通貨名称
								,gKijunKinriNm1			-- 基準金利１名称
								,gKijunKinriNm2			-- 基準金利２名称
								,gSpread 				-- スプレッド
								,gKaiji 					-- 回次
								,gRiritsu 				-- 利率
								,gKijunKinriRrt1		-- 基準金利１
								,gKijunKinriRrt2		-- 基準金利２
								,gKijunKinriCmnt 		-- 基準金利コメント
								,gStRbrKjt 				-- 初回利払期日
								,gShrKjt 				-- 支払期日
								,gRbrYmd 				-- 利払日
								,gRbrKawaseRate 			-- 利払為替レート
								,gSpananbunBunshi 		-- 日数按分分子
								,gSpananbunBunbo 		-- 日数按分分母
								,gRknCalcFYmd 			-- 利金計算期間ＦＲＯＭ
								,gRknCalcTYmd 			-- 利金計算期間ＴＯ
								,gRknRoundProcessKbn 	-- 利金計算単位未満端数処理区分
								,gRknRoundProcessNm 		-- 利金計算単位未満端数処理名称
								,gTsukaRishiKngk 		-- １通貨当たりの利子額
								,gTsukaRishiKngk_S 		-- 			〃			(算出値)
								--,gRisokuKngk			-- 利息金額
								,gKozaTenCd                               -- 口座店コード
								,gKozaTenCifcd                            -- 口座店ＣＩＦコード
								,gMgrKihonKinriCd2                       -- 基準金利コード２
								,gKijunKinriNm3                          -- 基準金利２名称
								,gShihyoukinriNmEtc                       -- その他指標金利コード内容
								,gDispatchFlg                             -- 請求書発送区分
								,gKyotenKbn                               -- 拠点区分
								,gShoriKbn                                -- 処理区分
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
		-- 利渡期番号の編集
		IF ((gTokureiShasaiFlg = 'Y') OR (gKaiji = 0)) THEN
			gRiwatariNo := '−';
		ELSE
			gRiwatariNo := gKaiji::text;
		END IF;
		-- 次回利率決定日の取得
		gNextRiritsuKetteiYmd := spIp01901_getNextRiritsuKetteiYmd(l_inItakuKaishaCd, gMgrCd, gShrKjt);
		-- 西暦変換
		-- 支払日(利払日)
		gWrkShrYmd := NULL;
		IF (trim(both gShrKjt) IS NOT NULL AND (trim(both gShrKjt))::text <> '') THEN
			gWrkShrYmd := pkDate.seirekiChangeSuppressNenGappi(gRbrYmd);
		END IF;
		-- 利金計算期間ＦＲＯＭ
		gWrkRknCalcFYmd := NULL;
		IF (trim(both gRknCalcFYmd) IS NOT NULL AND (trim(both gRknCalcFYmd))::text <> '') THEN
			gWrkRknCalcFYmd := pkDate.seirekiChangeSuppressNenGappi(gRknCalcFYmd);
		END IF;
		-- 利金計算期間ＴＯ
		gWrkRknCalcTYmd := NULL;
		IF (trim(both gRknCalcTYmd) IS NOT NULL AND (trim(both gRknCalcTYmd))::text <> '') THEN
			gWrkRknCalcTYmd := pkDate.seirekiChangeSuppressNenGappi(gRknCalcTYmd);
		END IF;
		-- 次回利率決定日
		gWrkNextRiritsuKetteiYmd := NULL;
		IF (trim(both gNextRiritsuKetteiYmd) IS NOT NULL AND (trim(both gNextRiritsuKetteiYmd))::text <> '') THEN
			gWrkNextRiritsuKetteiYmd := pkDate.seirekiChangeSuppressNenGappi(gNextRiritsuKetteiYmd);
		ELSE
			-- ブランクの場合は全角ハイフンをセット
			gWrkNextRiritsuKetteiYmd := '−';
		END IF;
		-- 宛名編集
		CALL pkIpaName.getMadoFutoAtena(gHktNm, gSfskBushoNm, gOutflg, gAtena);
		-- 利払対象残高算出
		-- 残高確定区分でセットする日付を変える
		CASE gZndkKakuteiKbn
			-- 支払期日の1ヶ月前の末日
			WHEN '1' THEN
				gZndkKijunYmd := pkDate.getGetsumatsuYmd(gShrKjt, -1);
			-- 支払期日の2ヶ月前の末日
			WHEN '2' THEN
				gZndkKijunYmd := pkDate.getGetsumatsuYmd(gShrKjt, -2);
			-- 8:利払日前日時点
			WHEN '8' THEN
				gZndkKijunYmd := pkDate.getZenYmd(gRbrYmd);
			-- 請求書作成時点
			WHEN '9' THEN
				gZndkKijunYmd := pkDate.getZenYmd(gRbrYmd);
			ELSE
				gZndkKijunYmd := '';
		END CASE;
		-- 発行日と比較、残高基準日が発行日以降の場合には残高基準日時点の残高をセットする
		IF pkDate.dateCompareCheck(gHakkoYmd, gZndkKijunYmd) = 0 THEN
			gRbrTaishoZndk	:= pkIpaZndk.getKjnZndk(l_inItakuKaishaCd, gMgrCd, gZndkKijunYmd, 3);
		ELSE
			-- 残高基準日が発行日より前になる場合、発行日残高（社債の総額）をセットする
			gRbrTaishoZndk	:= pkIpaZndk.getKjnZndk(l_inItakuKaishaCd, gMgrCd, gHakkoYmd, 3);
		END IF;
		IF gRbrTsukaCd = 'JPY' THEN
			gRisokuKngk := TRUNC(gRbrTaishoZndk::numeric * gTsukaRishiKngk::numeric, 0);
		ELSE
			gRisokuKngk := TRUNC(gRbrTaishoZndk::numeric * gTsukaRishiKngk::numeric, 2);
		END IF;
		-- この後で計算式を編集するために、その回次で使う実日数計算区分を取得する
		SELECT
			CASE 
				WHEN MG2.RBR_KJT = MG1.ST_RBR_KJT	THEN MG1.FST_NISSUKSN_KBN 	-- 初期
				WHEN MG2.RBR_KJT = MG2MAX.KAIJI_MAX	THEN MG1.END_NISSUKSN_KBN 	-- 終期
				WHEN MG2.KAIJI   = 0				THEN MG1.END_NISSUKSN_KBN 	-- 期中利払の場合も終期の実日数計算区分を使用
				ELSE									 MG1.KICHU_NISSUKSN_KBN 	-- 期中
			END INTO STRICT gJitsuNissuCalcKbn 		-- 実日数計算区分をセット
			FROM
				MGR_KIHON MG1,
				MGR_RBRKIJ MG2,
				(SELECT  ITAKU_KAISHA_CD , MGR_CD,MAX(RBR_KJT) AS KAIJI_MAX FROM MGR_RBRKIJ GROUP BY ITAKU_KAISHA_CD ,MGR_CD) MG2MAX 
			WHERE MG1.ITAKU_KAISHA_CD	=	MG2.ITAKU_KAISHA_CD
				AND MG1.MGR_CD			=	MG2.MGR_CD
				AND MG1.ITAKU_KAISHA_CD	=	MG2MAX.ITAKU_KAISHA_CD
				AND MG1.MGR_CD			=	MG2MAX.MGR_CD
				AND MG1.ITAKU_KAISHA_CD	=	l_inItakuKaishaCd
				AND MG1.MGR_CD			=	gMgrCd
				AND MG2.RBR_KJT			=	gShrKjt;
		--*********** １通貨当たりの利子額計算式の編集 ************
		-- １通貨当たりの金額（帳票セット用）、計算式、為替レートの初期化
		gTsukaRishiCalc := NULL;
		gTsukaRishiKawaseRate := NULL;
		gTsukaRishiCalc1 := NULL;
		gTsukaRishiCalc2 := NULL;
		gTsukaRishiCalc3 := NULL;
		gTsukaRishiKngkKakushasai := 0;
		--------------------------------------------------------------------------
--		 １通貨当たりの利子額が、１通貨当たりの利子額が(算出値)と異なる場合は、
--		「６．１通貨当たりの利子額」に利子額、計算式、為替レートを表示しない。
--		 ------------------------------------------------------------------------
		-- １通貨当たりの利子額が算出値と一致するなら利子額、計算式、為替レートをセット。
		IF gTsukaRishiKngk = gTsukaRishiKngk_S THEN
			IF gSpananbunBunbo != 0 THEN
				-- 半ヵ年区分＝「1/年利払回数」の場合
				IF gSpananbunBunbo <= 12 THEN
					-- 特例債かつフラグが1の場合は、新計算方式
					IF (CTL_VALUE = '1' AND gTokureiShasaiFlg = 'Y') THEN
					-- 新計算方式の場合、１通貨当たりの利子額（計算式）は表示しない
						gTsukaRishiCalc := '';
--
--						gTsukaRishiCalc := RISHIGAKU_COMMENT;
--						gTsukaRishiCalc1 := RISHIGAKU_BUN;
--
--						gTsukaRishiKngkKakushasai := getKakushasaiRoundProcess(gRknRoundProcessKbn, gKakushasaiKngk * (gRiritsu::numeric / 100) * gSpananbunBunshi / gSpananbunBunbo);
--
--						gTsukaRishiCalc2 := '各社債当りの利子額　' || TRIM(TO_CHAR(TO_NUMBER(gKakushasaiKngk), '99,999,999,999,999')) || '円 × ' || TRIM(gRiritsu) || '% × ' 
--											|| gSpananbunBunshi || '日 ÷ '|| gSpananbunBunbo || '日 ＝ ' || TRIM(TO_CHAR(TO_NUMBER(gTsukaRishiKngkKakushasai), '99,999,999,999,999'))
--											|| ' (' || gRknRoundProcessNm || ')';
--
--						gTsukaRishiKngkChk := TRUNC(gTsukaRishiKngkKakushasai / gKakushasaiKngk + 0.00000000000009, 13);
--
--						gTsukaRishiCalc3 := '１通貨当りの利子額　' || TRIM(TO_CHAR(TO_NUMBER(gTsukaRishiKngkKakushasai), '99,999,999,999,999')) || '円 ÷ ' 
--											|| TRIM(TO_CHAR(TO_NUMBER(gKakushasaiKngk), '99,999,999,999,999')) || '円　＝ '
--											|| TRIM(TO_CHAR(TO_NUMBER(gTsukaRishiKngkChk), '0.9999999999999')) || ' (切上げ)';
--
					ELSE
						-- １通貨当たりの利子額の計算式
						gTsukaRishiCalc := '('	|| trim(both gRiritsu) || '% × '
												|| gSpananbunBunshi || '/' || gSpananbunBunbo
												|| ' ・・・' || gRknRoundProcessNm || ')';
						-- 計算式の値を計算し、次に１通貨当たりの利子額が正しいかをチェックする為に確認用の金額を取得する
						gTsukaRishiKngkChk := spIp01901_getRknRoundProcess(gRknRoundProcessKbn,(gRiritsu::numeric / 100) * gSpananbunBunshi / gSpananbunBunbo);
						-- 発行通貨≠利払通貨の場合
						IF gHakkoTsukaCd != gRbrTsukaCd THEN
							IF gRbrKawaseRate <> 0 THEN
								gTsukaRishiKngkChk := spIp01901_getRknRoundProcess(gRknRoundProcessKbn,(gRiritsu::numeric / 100) * gSpananbunBunshi / gSpananbunBunbo / gRbrKawaseRate);
							END IF;
						END IF;
					END IF;
				-- 半ヵ年区分＝「1/年利払回数」以外（'2'その他実日数　など）
				ELSE
					-- 計算期間From-Toの日数と、期間按分分子が一致する場合はショート
					IF PKDATE.CALCNISSURYOHA(gRknCalcFYmd,gRknCalcTYmd) = gSpananbunBunshi THEN
						-- 実日数計算区分 = 半か年実日数の場合
						IF gJitsuNissuCalcKbn = '4' THEN
							-- 特例債かつフラグが1の場合は、新計算方式
							IF (CTL_VALUE = '1' AND gTokureiShasaiFlg = 'Y') THEN
					           -- 新計算方式の場合、１通貨当たりの利子額（計算式）は表示しない
								gTsukaRishiCalc := '';
--
--								gTsukaRishiCalc := RISHIGAKU_COMMENT;
--								gTsukaRishiCalc1 := RISHIGAKU_BUN;
--
--								gTsukaRishiKngkKakushasai := getKakushasaiRoundProcess(gRknRoundProcessKbn, gKakushasaiKngk * (gRiritsu::numeric / 100) * 1 / gNenRbrCnt * gSpananbunBunshi / gSpananbunBunbo);
--
--								gTsukaRishiCalc2 := '各社債当りの利子額　' || TRIM(TO_CHAR(TO_NUMBER(gKakushasaiKngk), '99,999,999,999,999')) || '円 × ' || TRIM(gRiritsu) || '% × '
--													|| '1/ ' || TO_NUMBER(gNenRbrCnt) || ' × ' || gSpananbunBunshi || '日 ÷ '
--													|| gSpananbunBunbo || '日 ＝ ' || TRIM(TO_CHAR(TO_NUMBER(gTsukaRishiKngkKakushasai), '99,999,999,999,999')) || ' (' || gRknRoundProcessNm || ')';
--
--								gTsukaRishiKngkChk := TRUNC(gTsukaRishiKngkKakushasai / gKakushasaiKngk + 0.00000000000009, 13);
--
--								gTsukaRishiCalc3 := '１通貨当りの利子額　' || TRIM(TO_CHAR(TO_NUMBER(gTsukaRishiKngkKakushasai), '99,999,999,999,999')) || '円 ÷ ' 
--													|| TRIM(TO_CHAR(TO_NUMBER(gKakushasaiKngk), '99,999,999,999,999')) || '円　＝ ' || TRIM(TO_CHAR(TO_NUMBER(gTsukaRishiKngkChk), '0.9999999999999')) || ' (切上げ)';
--
							ELSE
								-- １通貨当たりの利子額の計算式
								gTsukaRishiCalc := '('	|| trim(both gRiritsu) || '% × '
														|| '1/' || (gNenRbrCnt)::numeric  || ' × '
														|| gSpananbunBunshi || '日 ÷ ' || gSpananbunBunbo || '日 '
														|| ' ・・・' || gRknRoundProcessNm || ')';
								-- 計算式の値を計算し、次に１通貨当たりの利子額が正しいかをチェックする為に確認用の金額を取得する
								gTsukaRishiKngkChk := spIp01901_getRknRoundProcess(gRknRoundProcessKbn,(gRiritsu::numeric / 100) * 1 / gNenRbrCnt * gSpananbunBunshi / gSpananbunBunbo);
								-- 発行通貨≠利払通貨の場合
								IF gHakkoTsukaCd != gRbrTsukaCd THEN
									IF gRbrKawaseRate <> 0 THEN
										gTsukaRishiKngkChk := spIp01901_getRknRoundProcess(gRknRoundProcessKbn,(gRiritsu::numeric / 100) * 1 / gNenRbrCnt * gSpananbunBunshi / gSpananbunBunbo / gRbrKawaseRate);
									END IF;
								END IF;
							END IF;
						-- 半か年実日数以外（365日、366日、実日数）
						ELSE
							-- 特例債かつフラグが1の場合は、新計算方式
							IF (CTL_VALUE = '1' AND gTokureiShasaiFlg = 'Y') THEN
					           -- 新計算方式の場合、１通貨当たりの利子額（計算式）は表示しない
								gTsukaRishiCalc := '';
--
--								gTsukaRishiCalc := RISHIGAKU_COMMENT;
--								gTsukaRishiCalc1 := RISHIGAKU_BUN;
--
--								gTsukaRishiKngkKakushasai := getKakushasaiRoundProcess(gRknRoundProcessKbn, gKakushasaiKngk * (gRiritsu::numeric / 100) * gSpananbunBunshi / gSpananbunBunbo);
--
--								gTsukaRishiCalc2 := '各社債当りの利子額　' || TRIM(TO_CHAR(TO_NUMBER(gKakushasaiKngk), '99,999,999,999,999')) || '円 × ' || TRIM(gRiritsu) || '% × ' || gSpananbunBunshi || '日 ÷ ' 
--														|| gSpananbunBunbo || '日 ＝ ' || TRIM(TO_CHAR(TO_NUMBER(gTsukaRishiKngkKakushasai), '99,999,999,999,999')) || ' (' || gRknRoundProcessNm || ')';
--
--								gTsukaRishiKngkChk := TRUNC(gTsukaRishiKngkKakushasai / gKakushasaiKngk + 0.00000000000009, 13);
--
--								gTsukaRishiCalc3 := '１通貨当りの利子額　' || TRIM(TO_CHAR(TO_NUMBER(gTsukaRishiKngkKakushasai), '99,999,999,999,999')) || '円 ÷ ' 
--													|| TRIM(TO_CHAR(TO_NUMBER(gKakushasaiKngk), '99,999,999,999,999')) || '円　＝ ' || TRIM(TO_CHAR(TO_NUMBER(gTsukaRishiKngkChk), '0.9999999999999')) || ' (切上げ)';
--
							ELSE
								-- １通貨当たりの利子額の計算式
								gTsukaRishiCalc := '('	|| trim(both gRiritsu) || '% × '
														|| gSpananbunBunshi || '日 ÷ ' || gSpananbunBunbo || '日 '
														|| ' ・・・' || gRknRoundProcessNm || ')';
								-- 計算式の値を計算し、次に１通貨当たりの利子額が正しいかをチェックする為に確認用の金額を取得する
								gTsukaRishiKngkChk := spIp01901_getRknRoundProcess(gRknRoundProcessKbn,(gRiritsu::numeric / 100) * gSpananbunBunshi / gSpananbunBunbo);
								-- 発行通貨≠利払通貨の場合
								IF gHakkoTsukaCd != gRbrTsukaCd THEN
									IF gRbrKawaseRate <> 0 THEN
										gTsukaRishiKngkChk := spIp01901_getRknRoundProcess(gRknRoundProcessKbn,(gRiritsu::numeric / 100) * gSpananbunBunshi / gSpananbunBunbo / gRbrKawaseRate);
									END IF;
								END IF;
							END IF;
						END IF;
					END IF;
				END IF;
				--------------------------------------------------------------------------
--				 式に含まれる値の計算結果と１通貨当たりの利子額が一致しない場合にも
--				「６．１通貨当たりの利子額」に利子額、計算式、為替レートを表示しない。
--				 ------------------------------------------------------------------------
				IF gTsukaRishiKngk_S = gTsukaRishiKngkChk THEN
					-- 発行通貨≠利払通貨の場合
					-- 利息金額(計算式)、為替レート
					IF gHakkoTsukaCd != gRbrTsukaCd THEN
						IF (CTL_VALUE = '1' AND gTokureiShasaiFlg = 'Y') THEN
							-- 新計算方式の場合は、式を表示しない
							gTsukaRishiKawaseRate := ' ';
							gTsukaRishiCalc := '';
							gTsukaRishiCalc1 := '';
							gTsukaRishiCalc2 := '';
							gTsukaRishiCalc3 := '';
						ELSE
							gTsukaRishiKawaseRate := '為替レート ＝ ' || trim(both TO_CHAR((gRbrKawaseRate)::numeric , '990.9999'));
							-- 計算式に、「÷為替レート」を追加表示
							gTsukaRishiCalc := REPLACE(gTsukaRishiCalc,' ・・・', ' ÷ ' || trim(both TO_CHAR((gRbrKawaseRate)::numeric , '990.9999')) || ' ・・・');
						END IF;
					ELSE
						gTsukaRishiKawaseRate := NULL;
					END IF;
				ELSE
					-- 一致しない場合には計算式をクリア
					gTsukaRishiCalc := '';
					gTsukaRishiCalc1 := '';
					gTsukaRishiCalc2 := '';
					gTsukaRishiCalc3 := '';
				END IF;
			END IF;
		ELSIF gTsukaRishiKngk_S <> gTsukaRishiKngkChk THEN
			-- 「１通貨当たりの利子額(算出値)」と計算式の「１通貨当たりの利子額」が一致しない場合にはログも書き出す。
			CALL PKLOG.DEBUG(l_inUserId,REPORT_ID,'銘柄_基本.１通貨当たりの利子額(算出値)と、計算式の結果が一致しません。');
		END IF;
		--*********** 利息金額編集式 ************
		gRisokuKngkCalc := '('	|| trim(both TO_CHAR((gRbrTaishoZndk)::numeric , '999,999,999,999,999')) || ' × '
								|| trim(both TO_CHAR((gTsukaRishiKngk)::numeric , '0.9999999999999'))
								|| ' ・・・切捨て)';
		--利払計算期間（日数）
		gRiritsuKeisanKikan := NULL;
		IF (trim(both gRknCalcFYmd) IS NOT NULL AND (trim(both gRknCalcFYmd))::text <> '') AND (trim(both gRknCalcTYmd) IS NOT NULL AND (trim(both gRknCalcTYmd))::text <> '') THEN
			gRiritsuKeisanKikan := pkDate.calcNissuRyoha(gRknCalcFYmd, gRknCalcTYmd);
		END IF;
		--クーポン条件の初期化
		gCoupon1 := NULL;
		gCoupon2 := NULL;
		gCoupon3 := NULL;
		gCapFloorTekiyoNm := NULL;  -- ＣＡＰ・ＦＬＯＯＲ適用名称
		-- 【非応答日の場合】
		IF gKaiji = 0 THEN
			--期中銘柄変更（償還）の取得
			DECLARE
				updmgr_result spip01901_updmgr_result;
			BEGIN
				updmgr_result := spIp01901_getUpdMgrShn2(l_inKozaTenCifCd, gMgrCd, gShrKjt, l_inItakuKaishaCd, REPORT_ID);
				recUpdMgrShn2 := updmgr_result.recUpdMgr;
				gSakuseiDt := updmgr_result.gSakuseiDt;
				gShoninDt := updmgr_result.gShoninDt;
			END;
			IF (recUpdMgrShn2.gMgrCd IS NOT NULL AND recUpdMgrShn2.gMgrCd::text <> '') THEN
				DECLARE
					coupon_result spip01901_coupon_result;
				BEGIN
					coupon_result := spIp01901_getCoupon(recUpdMgrShn2);
					gCoupon1 := coupon_result.gCoupon1;
					gCoupon2 := coupon_result.gCoupon2;
					gCoupon3 := coupon_result.gCoupon3;
					gCapFloorTekiyoNm := coupon_result.gCapFloorTekiyoNm;
				END;
			END IF;
		-- 【応答日の場合】
		ELSE
			--期中銘柄変更（利払）の取得
			DECLARE
				updmgr_result spip01901_updmgr_result;
			BEGIN
				updmgr_result := spIp01901_getUpdMgrRbr2(l_inItakuKaishaCd, gMgrCd, gShrKjt, REPORT_ID);
				recUpdMgrRbr2 := updmgr_result.recUpdMgr;
				gSakuseiDt := updmgr_result.gSakuseiDt;
				gShoninDt := updmgr_result.gShoninDt;
			END;
			IF (recUpdMgrRbr2.gMgrCd IS NOT NULL AND recUpdMgrRbr2.gMgrCd::text <> '') THEN
				DECLARE
					coupon_result spip01901_coupon_result;
				BEGIN
					coupon_result := spIp01901_getCoupon(recUpdMgrRbr2);
					gCoupon1 := coupon_result.gCoupon1;
					gCoupon2 := coupon_result.gCoupon2;
					gCoupon3 := coupon_result.gCoupon3;
					gCapFloorTekiyoNm := coupon_result.gCapFloorTekiyoNm;
				END;
			END IF;
		END IF;
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := NULL::type_sreport_wk_item;
		
		v_item.l_inItem001 := gWrkTsuchiYmd;	-- 入力通知日
		v_item.l_inItem002 := gSfskPostNo;	-- 送付先郵便番号
		v_item.l_inItem003 := gAdd1;	-- 送付先住所１
		v_item.l_inItem004 := gAdd2;	-- 送付先住所２
		v_item.l_inItem005 := gAdd3;	-- 送付先住所３
		v_item.l_inItem006 := gAtena;	-- 発行体名称
		v_item.l_inItem007 := gBankNm;	-- 銀行名称
		v_item.l_inItem008 := gBushoNm;	-- 担当部署名称１
		v_item.l_inItem009 := gIsinCd;	-- ＩＳＩＮコード
		v_item.l_inItem010 := gMgrNm;	-- 銘柄の正式名称
		v_item.l_inItem011 := gRiwatariNo;	-- 回次(利渡期番号)
		v_item.l_inItem012 := gRiritsu;	-- 利率
		v_item.l_inItem013 := gCoupon1;	-- クーポン条件１(銘柄基本.基準金利名１-銘柄基本.基準金利名２＋銘柄基本.スプレッド)
		v_item.l_inItem014 := gCoupon2;	-- クーポン条件２(銘柄基本.基準金利名１=期中銘柄変更(利払).基準金利利率１
		v_item.l_inItem015 := gCoupon3;	-- クーポン条件３(銘柄_基本.基準金利コメント)
		v_item.l_inItem016 := gWrkShrYmd;	-- 支払日
		v_item.l_inItem017 := gRiritsuKeisanKikan;	-- 利払計算期間（日数）
		v_item.l_inItem018 := gWrkRknCalcFYmd;	-- 利金計算期間ＦＲＯＭ
		v_item.l_inItem019 := gWrkRknCalcTYmd;	-- 利金計算期間ＴＯ
		v_item.l_inItem020 := trim(both TO_CHAR((gTsukaRishiKngk)::numeric , '0.9999999999999'));
		v_item.l_inItem021 := gTsukaRishiCalc;	-- １通貨当たりの利子額(計算式)
		v_item.l_inItem022 := gTsukaRishiKawaseRate;	-- １通貨当たりの利子額(利払為替レート)
		v_item.l_inItem023 := gRisokuKngk;	-- 利息金額
		v_item.l_inItem024 := gRbrTsukaNm;	-- 利払通貨名称
		v_item.l_inItem025 := gRisokuKngkCalc;	-- 利息金額（計算式）
		v_item.l_inItem026 := gWrkNextRiritsuKetteiYmd;	-- 次回利率決定日
		v_item.l_inItem027 := gFmtHakkoKngk;	-- 発行金額書式フォーマット
		v_item.l_inItem028 := gFmtRbrKngk;	-- 利払金額書式フォーマット
		v_item.l_inItem029 := gFmtShokanKngk;	-- 償還金額書式フォーマット
		v_item.l_inItem031 := gTsukaRishiCalc1;	-- １通貨当たりの利子額(計算式)文言
		v_item.l_inItem032 := gTsukaRishiCalc2;	-- 各社債当たりの利子額(計算式)
		v_item.l_inItem033 := gTsukaRishiCalc3;	-- １通貨当たりの利子額(計算式)
		v_item.l_inItem034 := gKozaTenCd;	-- 口座店コード
		v_item.l_inItem035 := trim(both gKozaTenCifcd);	-- 口座店ＣＩＦコード
		v_item.l_inItem036 := gCapFloorTekiyoNm;	-- ＣＡＰ・ＦＬＯＯＲ適用名称
		v_item.l_inItem037 := gKetteibiOutUmuFlg;	-- 利率決定日出力有無フラグ
		v_item.l_inItem038 := gHktCd;	-- 発行体コード
		v_item.l_inItem101 := gDispatchFlg;	-- 請求書発送区分
		v_item.l_inItem102 := gKyotenKbn;	-- 拠点区分
		v_item.l_inItem103 := gSakuseiDt;	-- 期中銘柄変更（利払/償還）作成日時
		v_item.l_inItem104 := gShoninDt;	-- 期中銘柄変更（利払/償還）承認日時
		v_item.l_inItem105 := gShoriKbn;	-- 発行体マスタ処理区分
		
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
		v_item := NULL::type_sreport_wk_item;
		
		v_item.l_inItem001 := gWrkTsuchiYmd;	-- 入力通知日
		v_item.l_inItem030 := '対象データなし';
		
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
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp01901 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		BEGIN
			CLOSE curMeisai;
		EXCEPTION
			WHEN OTHERS THEN NULL;  -- Cursor already closed
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
-- REVOKE ALL ON PROCEDURE spip01901 ( l_inHktCd TEXT, l_inKozaTenCd TEXT, l_inKozaTenCifCd TEXT, l_inMgrCd TEXT, l_inIsinCd TEXT, l_inKijunYmdF TEXT, l_inKijunYmdT TEXT, l_inTsuchiYmd TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inHendoRiritsuShoninDtFlg TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT integer, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spip01901_createsql (
	l_inItakuKaishaCd TEXT,
	l_inHendoRiritsuShoninDtFlg TEXT,
	l_inKijunYmdF TEXT,
	l_inKijunYmdT TEXT,
	l_inHktCd TEXT,
	l_inKozaTenCd TEXT,
	l_inKozaTenCifCd TEXT,
	l_inMgrCd TEXT,
	l_inIsinCd TEXT,
	l_inGyomuYmd TEXT
) RETURNS TEXT AS $body$
DECLARE
	gSQL varchar(10000);
BEGIN
	gSQL := '';
	gSQL := gSQL || 'SELECT	M01.HKT_CD,';										-- 発行体コード
	gSQL := gSQL || '		M01.SFSK_POST_NO,';									-- 送付先郵便番号
	gSQL := gSQL || '		M01.ADD1,';											-- 送付先住所１
	gSQL := gSQL || '		M01.ADD2,';											-- 送付先住所２
	gSQL := gSQL || '		M01.ADD3,';											-- 送付先住所３
	gSQL := gSQL || '		M01.HKT_NM,';										-- 発行体名称
	gSQL := gSQL || '		M01.SFSK_BUSHO_NM,';								-- 送付先担当部署名称
	gSQL := gSQL || '		VJ1.BANK_NM,';										-- 銀行名称
	gSQL := gSQL || '		VJ1.BUSHO_NM1,';									-- 担当部署名称１
	gSQL := gSQL || '		VMG1.ISIN_CD,';										-- ＩＳＩＮコード
	gSQL := gSQL || '		VMG1.MGR_CD,';										-- 銘柄コード
	gSQL := gSQL || '		VMG1.MGR_NM,	';									-- 銘柄の正式名称
	gSQL := gSQL || '		VMG1.HAKKO_YMD,';									-- 発行日    
	gSQL := gSQL || '		VMG1.KAKUSHASAI_KNGK,';								-- 各社債の金額
	gSQL := gSQL || '		VMG1.HAKKO_TSUKA_CD,';								-- 発行通貨コード
	gSQL := gSQL || '		VMG1.RBR_TSUKA_CD,';								-- 利払通貨コード
	gSQL := gSQL || '		VMG1.SHOKAN_TSUKA_CD,';								-- 償還通貨コード
	gSQL := gSQL || '		VMG1.NENRBR_CNT,';									-- 年利払回数
	gSQL := gSQL || '		VMG1.KKN_ZNDK_KAKUTEI_KBN,';						-- 基金残高確定区分
	gSQL := gSQL || '		VMG1.TOKUREI_SHASAI_FLG,';							-- 特例社債フラグ
	gSQL := gSQL || '		(SELECT M64.TSUKA_NM';								-- 利払通貨名称
	gSQL := gSQL || '		   FROM MTSUKA M64';
	gSQL := gSQL || '		  WHERE M64.TSUKA_CD = VMG1.RBR_TSUKA_CD';
	gSQL := gSQL || '		) AS RBR_TSUKA_NM,';
	gSQL := gSQL || '		(SELECT MCD1.CODE_NM';								-- 基準金利１名称
	gSQL := gSQL || '		   FROM SCODE MCD1';
	gSQL := gSQL || '		  WHERE MCD1.CODE_SHUBETSU = ''140''';
	gSQL := gSQL || '		    AND VMG1.KIJUN_KINRI_CD1 = MCD1.CODE_VALUE';
	gSQL := gSQL || '		) AS KIJUN_KINRI_NM1,';
	gSQL := gSQL || '		(SELECT MCD2.CODE_NM';								-- 基準金利２名称
	gSQL := gSQL || '		   FROM SCODE MCD2';
	gSQL := gSQL || '		  WHERE MCD2.CODE_SHUBETSU = ''140''';
	gSQL := gSQL || '		    AND VMG1.KIJUN_KINRI_CD2 = MCD2.CODE_VALUE';
	gSQL := gSQL || '		) AS KIJUN_KINRI_NM2,';
	gSQL := gSQL || '		TO_CHAR(MG2.SPREAD,''FM99999999990.0000000''),';				-- スプレッド
	gSQL := gSQL || '		MG2.KAIJI,';										-- 回次
	gSQL := gSQL || '		TO_CHAR(MG2.RIRITSU,''FM99999999990.0000000''),';			-- 利率
	gSQL := gSQL || '		TO_CHAR(MG2.KIJUN_KINRI_RRT1,''FM99999999990.0000000''),';	-- 基準金利１
	gSQL := gSQL || '		TO_CHAR(MG2.KIJUN_KINRI_RRT2,''FM99999999990.0000000''),';	-- 基準金利２
	gSQL := gSQL || '		VMG1.KIJUN_KINRI_CMNT,';							-- 基準金利コメント
	gSQL := gSQL || '		VMG1.ST_RBR_KJT,';									-- 初回利払期日
	gSQL := gSQL || '		MG2.RBR_KJT,';										-- 支払期日
	gSQL := gSQL || '		MG2.RBR_YMD,';										-- 利払日
	gSQL := gSQL || '		MG2.RBR_KAWASE_RATE,';								-- 利払為替レート
	gSQL := gSQL || '		MG2.SPANANBUN_BUNSHI,';								-- 日数按分分子
	gSQL := gSQL || '		MG2.SPANANBUN_BUNBO,';								-- 日数按分分母
	gSQL := gSQL || '		MG2.RKN_CALC_F_YMD,';								-- 利金計算期間ＦＲＯＭ
	gSQL := gSQL || '		MG2.RKN_CALC_T_YMD,';								-- 利金計算期間ＴＯ
	gSQL := gSQL || '		VMG1.RKN_ROUND_PROCESS AS RKN_ROUND_PROCESS_KBN,';	-- 利金計算単位未満端数処理区分
	gSQL := gSQL || '		(SELECT MCD3.CODE_NM';								-- 利金計算単位未満端数処理名称
	gSQL := gSQL || '		   FROM SCODE MCD3';
	gSQL := gSQL || '		  WHERE MCD3.CODE_SHUBETSU = ''128''';
	gSQL := gSQL || '		    AND VMG1.RKN_ROUND_PROCESS = MCD3.CODE_VALUE';
	gSQL := gSQL || '		) AS RKN_ROUND_PROCESS_NM,';
	gSQL := gSQL || '		MG2.TSUKARISHI_KNGK,';								-- １通貨当たりの金額
	gSQL := gSQL || '		MG2.TSUKARISHI_KNGK_S ';							-- １通貨当たりの金額(システム算出値)
	--gSQL := gSQL || '		CASE';
--		gSQL := gSQL || '			WHEN VMG1.RBR_TSUKA_CD = ''JPY'' THEN TRIM(TO_CHAR(TRUNC(VMG1.KAKUSHASAI_KNGK * MG2.TSUKARISHI_KNGK, 0))) ';
--		gSQL := gSQL || '			ELSE TRIM(TO_CHAR(TRUNC(VMG1.KAKUSHASAI_KNGK * MG2.TSUKARISHI_KNGK, 2), ''999999999990.00'')) ';
--		gSQL := gSQL || '		END AS RISOKU_KNGK ';								-- 利息金額
--		
	gSql := gSql || '		,M01.KOZA_TEN_CD ';                             -- 口座店コード
	gSql := gSql || '		,M01.KOZA_TEN_CIFCD ';                          -- 口座店ＣＩＦコード
	gSql := gSql || '		,VMG1.KIJUN_KINRI_CD2 ';                        -- 銘柄_基本・基準金利コード２
	gSQL := gSQL || '		,(SELECT BT20.KINRI_NM ';
	gSQL := gSQL || '		   FROM KINRI_GAIYO BT20';
	gSQL := gSQL || '		  WHERE BT20.SHIHYOKINRI_CD = VMG1.KIJUN_KINRI_CD2';
	gSQL := gSQL || '		) AS KIJUN_KINRI_NM3 ';             -- 基準金利２名称
	--銘柄_基本2
	gSql := gSql || '		,BT03.SHIHYOKINRI_NM_ETC ';         -- その他指標金利コード内容
	gSql := gSql
		 || '	,BT03.DISPATCH_FLG AS DISPATCH_FLG '            -- 請求書発送区分
		 || '	,BT01.KYOTEN_KBN AS KYOTEN_KBN '                -- 拠点区分
		 || '	,M01.SHORI_KBN AS SHORI_KBN ';                  -- 処理区分
	gSQL := gSQL || ' FROM MGR_RBRKIJ MG2 ';								-- 銘柄_利払回次
	gSQL := gSQL || ' INNER JOIN MGR_KIHON_VIEW VMG1 ON VMG1.MGR_CD = MG2.MGR_CD AND VMG1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD ';
	gSQL := gSQL || ' INNER JOIN MGR_KIHON2 BT03 ON VMG1.ITAKU_KAISHA_CD = BT03.ITAKU_KAISHA_CD AND VMG1.MGR_CD = BT03.MGR_CD ';
	gSQL := gSQL || ' INNER JOIN MHAKKOTAI M01 ON MG2.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD AND VMG1.HKT_CD = M01.HKT_CD ';
	gSQL := gSQL || ' INNER JOIN MHAKKOTAI2 BT01 ON M01.ITAKU_KAISHA_CD = BT01.ITAKU_KAISHA_CD AND M01.HKT_CD = BT01.HKT_CD ';
	gSQL := gSQL || ' CROSS JOIN VJIKO_ITAKU VJ1 '; 								-- 自行・委託会社VIEW
	-- 変動利率承認日チェックボックスによる場合分け
	IF l_inHendoRiritsuShoninDtFlg = '1' THEN
		gSQL := gSQL || ' LEFT JOIN UPD_MGR_RBR MG22 ON MG2.ITAKU_KAISHA_CD = MG22.ITAKU_KAISHA_CD AND MG2.MGR_CD = MG22.MGR_CD AND MG2.RBR_KJT = MG22.SHR_KJT ';
		gSQL := gSQL || ' LEFT JOIN UPD_MGR_SHN MG23 ON MG2.ITAKU_KAISHA_CD = MG23.ITAKU_KAISHA_CD AND MG2.MGR_CD = MG23.MGR_CD AND MG2.RBR_KJT = MG23.SHR_KJT ';
	END IF;
	gSQL := gSQL || ' WHERE MG2.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' ';
	gSQL := gSQL || 'AND	VMG1.RITSUKE_WARIBIKI_KBN = ''V'' ';
	gSQL := gSQL || 'AND	VMG1.ISIN_CD <> '' '' ';
	gSQL := gSQL || 'AND	VMG1.JTK_KBN				<> ''2'' ';		-- 受託区分=副受託は対象外
	gSQL := gSQL || 'AND	VMG1.JTK_KBN				<> ''5'' ';		-- 受託区分=金融債は対象外
	gSQL := gSQL || 'AND	VMG1.MGR_STAT_KBN			=  ''1'' ';		-- 未承認は対象外
--		gSQL := gSQL || 'AND	MG2.RIRITSU <> 0 ';
	gSQL := gSQL || 'AND	VJ1.KAIIN_ID = ''' || l_inItakuKaishaCd || ''' ';
	-- 請求書出力可能な場合のみ(併存銘柄出力チェック)
	gSQL := gSQL || 'AND	PKIPACALCTESURYO.checkHeizonMgr( '
				 || '		 VMG1.ITAKU_KAISHA_CD'
				 || '		, VMG1.MGR_CD '
				 || '		,''' || l_inGyomuYmd || '''' 	--業務日付時点
				 || '		,''1'') = 0 ';
	-- ※基準日From-Toの両方とも必須入力なので必ず値が入ってくる
	-- 変動利率承認日チェックボックスによる場合分け
	IF l_inHendoRiritsuShoninDtFlg = '1' THEN
		-- 「期中銘柄情報変更−利払情報−」で承認済みのデータ、または、 「期中銘柄情報変更−償還情報−」の非応答日のコール一部・全額が承認済でデータ
		gSQL := gSQL || 'AND ';
		gSQL := gSQL || '( ';
		gSQL := gSQL || '( ';
		gSQL := gSQL || 'MG22.SHORI_KBN = ''1'' ';
		gSQL := gSQL || 'AND 	TO_CHAR(MG22.SHONIN_DT,''YYYYMMDD'') BETWEEN ''' || l_inKijunYmdF || ''' AND ''' || l_inKijunYmdT || ''' ';
		gSQL := gSQL || ') ';
		gSQL := gSQL || 'OR ';
		gSQL := gSQL || '( ';
		gSQL := gSQL || 'MG23.SHORI_KBN = ''1'' ';
		gSQL := gSQL || 'AND 	MG23.MGR_HENKO_KBN IN (''40'',''41'') ';			-- コード種別714（40：コールオプション・全額 , 41：コールオプション・一部）
		gSQL := gSQL || 'AND 	MG2.KAIJI = 0 ';
		gSQL := gSQL || 'AND 	MG2.RBR_KJT = MG23.SHR_KJT ';
		gSQL := gSQL || 'AND 	TO_CHAR(MG23.SHONIN_DT,''YYYYMMDD'') BETWEEN ''' || l_inKijunYmdF || ''' AND ''' || l_inKijunYmdT || ''' ';
		gSQL := gSQL || ') ';
		gSQL := gSQL || ') ';
	ELSE
		gSQL := gSQL || 'AND 	MG2.RBR_KJT BETWEEN ''' || l_inKijunYmdF || ''' AND ''' || l_inKijunYmdT || ''' ';
	END IF;
	IF (l_inHktCd IS NOT NULL AND l_inHktCd::text <> '') THEN
		gSQL := gSQL || 'AND 	VMG1.HKT_CD = ''' || l_inHktCd || ''' ';
	END IF;
	IF (l_inKozaTenCd IS NOT NULL AND l_inKozaTenCd::text <> '') THEN
		gSQL := gSQL || 'AND 	M01.KOZA_TEN_CD = ''' || l_inKozaTenCd || ''' ';
	END IF;
	IF (l_inKozaTenCifCd IS NOT NULL AND l_inKozaTenCifCd::text <> '') THEN
		gSQL := gSQL || 'AND 	M01.KOZA_TEN_CIFCD = ''' || l_inKozaTenCifCd || ''' ';
	END IF;
	IF (trim(both l_inMgrCd) IS NOT NULL AND (trim(both l_inMgrCd))::text <> '') THEN
		gSQL := gSQL || 'AND 	TRIM(VMG1.MGR_CD) = TRIM(''' || l_inMgrCd || ''') ';
	END IF;
	IF (l_inIsinCd IS NOT NULL AND l_inIsinCd::text <> '') THEN
		gSQL := gSQL || 'AND 	VMG1.ISIN_CD = ''' || l_inIsinCd || ''' ';
	END IF;
	-- 口座店コード＞口座店CIFコード＞拠点区分（表示なし）＞請求書発送区分（表示なし）
	-- ＞デットアサンプション契約先フラグ（表示なし）＞発行日（表示なし）
	-- ＞ISINコード＞元利払日
	gSQL := gSQL || ' ORDER BY ';
	gSQL := gSQL || '	M01.KOZA_TEN_CD, ';       -- 口座店コード
	gSQL := gSQL || '	M01.KOZA_TEN_CIFCD, ';   -- 口座店ＣＩＦコード
	gSQL := gSQL || '	BT01.KYOTEN_KBN, ';      -- 拠点区分（表示なし）
	gSQL := gSQL || '	BT03.DISPATCH_FLG, ';    -- 請求書発送区分
	gSQL := gSQL || '	VMG1.DPT_ASSUMP_FLG, ';  -- デットアサンプション契約先フラグ
	gSQL := gSQL || '	VMG1.HAKKO_YMD, ';       -- 発行日
	gSQL := gSQL || '	VMG1.ISIN_CD, ';         -- ISINコード
	gSQL := gSQL || '	MG2.RBR_YMD ';          -- 利払日
	
	RETURN gSQL;
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spip01901_createsql () FROM PUBLIC;





CREATE OR REPLACE FUNCTION spip01901_getcoupon (recUpdMgr spip01901_type_record) RETURNS spip01901_coupon_result AS $body$
DECLARE
	result spip01901_coupon_result;
BEGIN
	-- 指標金利が未設定の場合
	IF coalesce(trim(both recUpdMgr.gKijunKinriCd1)::text, '') = '' THEN
		result.gCoupon1 := '';  -- クーポン条件１
		result.gCoupon2 := '';  -- クーポン条件２
		result.gCoupon3 := '';  -- クーポン条件３
		result.gCapFloorTekiyoNm := '';  -- ＣＡＰ・ＦＬＯＯＲ適用名称
		RETURN result;
	END IF;
	-- ＣＡＰ適用の場合(上限下限適用有無フラグ＝”１”上限適用有り、”２”上限固定　の場合)　→　（上限金利　 Z9.9999999%を適用）
	IF recUpdMgr.gTekiyoUmu IN ('1','2') THEN
		result.gCapFloorTekiyoNm := '( ' || '上限金利　' || recUpdMgr.gKinriMaxTekiyoriritru || '%を適用 )';  -- ＣＡＰ・ＦＬＯＯＲ適用名称
	-- FLOOR適用の場合(上限下限適用有無フラグ＝”３”下限適用有り、”４”下限固定　の場合)　→　（下限金利　 Z9.9999999%を適用）
	ELSIF recUpdMgr.gTekiyoUmu IN ('3','4') THEN
		result.gCapFloorTekiyoNm := '( ' || '下限金利　' || recUpdMgr.gFloorKinriTekiyoriritru || '%を適用 )';  -- ＣＡＰ・ＦＬＯＯＲ適用名称
	--C上限下限適用有無フラグ＝”０”適用なし、”５”適用利率マイナス　の場合　→　空白
	ELSE
		result.gCapFloorTekiyoNm := '';  -- ＣＡＰ・ＦＬＯＯＲ適用名称
	END IF;
	CASE recUpdMgr.gTekiyoUmu   -- 上限・下限適用有無
		-- 上限下限適用有無フラグ:”１”上限適用有り
		WHEN '1' THEN
			--期中銘柄変更（利払/償還）２．基準金利（上限）名称　＋（−）　期中銘柄変更（利払/償還）２．基準金利（上限）スプレッド
			-- 基準金利（上限）スプレッドがプラスの場合
			IF (coalesce(trim(both recUpdMgr.gKinriMaxSpread),0))::numeric  >= 0 THEN
				result.gCoupon1 := recUpdMgr.gKinriMaxNm || ' ＋ ' || recUpdMgr.gKinriMaxSpread || '%';
			-- 基準金利（上限）スプレッドがマイナスの場合
			ELSE
				result.gCoupon1 := recUpdMgr.gKinriMaxNm || ' − ' || replace(recUpdMgr.gKinriMaxSpread, '-', '') || '%';
			END IF;
			--期中銘柄変更（利払/償還）２．基準金利（上限）名称　＋（−）　期中銘柄変更（利払/償還）２．基準金利（上限）金利
			result.gCoupon2 := '( ' || recUpdMgr.gKinriMaxNm || ' ＝ ' || recUpdMgr.gKinriMaxKinri || '% )';
			-- 期中銘柄変更（利払/償還）２．基準金利（上限） = 「その他」の場合　→　空白
			IF recUpdMgr.gKinriMax = '700' THEN
				result.gCoupon3 := '';
			-- 期中銘柄変更（利払/償還）２．基準金利（上限） = 「その他」以外の場合　→　金利概要．金利概要
			ELSE
				result.gCoupon3 := recUpdMgr.gKinriMaxGaiyo;
			END IF;
		-- 上限下限適用有無フラグ:”３”下限適用有り
		WHEN '3' THEN
			--期中銘柄変更（利払/償還）２．基準金利（下限）名称　＋（−）　期中銘柄変更（利払/償還）２．基準金利（下限）スプレッド
			-- 基準金利（下限）スプレッドがプラスの場合
			IF (coalesce(trim(both recUpdMgr.gKinriFloorSpread),0))::numeric  >= 0 THEN
				result.gCoupon1 := recUpdMgr.gKinriFloorNm || ' ＋ ' || recUpdMgr.gKinriFloorSpread || '%';
			-- 基準金利（下限）スプレッドがマイナスの場合
			ELSE
				result.gCoupon1 := recUpdMgr.gKinriFloorNm || ' − ' || replace(recUpdMgr.gKinriFloorSpread, '-', '') || '%';
			END IF;
			--期中銘柄変更（利払/償還）２．基準金利（下限）名称　＋（−）　期中銘柄変更（利払/償還）２．基準金利（下限）金利
			result.gCoupon2 := '( ' || recUpdMgr.gKinriFloorNm || ' ＝ ' || recUpdMgr.gKinriFloorKinri || '% )';
			-- 基準金利（下限）金利がマイナスの場合
			-- 期中銘柄変更（利払/償還）２．基準金利（下限） = 「その他」の場合　→　空白
			IF recUpdMgr.gKinriFloor = '700' THEN
				result.gCoupon3 := '';
			-- 期中銘柄変更（利払/償還）２．基準金利（下限） = 「その他」以外の場合　→　金利概要．金利概要
			ELSE
				result.gCoupon3 := recUpdMgr.gKinriFloorGaiyo;
			END IF;
		-- 上限下限適用有無フラグ:”０”上限下限適用無し
		WHEN '0' THEN
			IF (trim(both recUpdMgr.gKijunKinriCd1Nm) IS NOT NULL AND (trim(both recUpdMgr.gKijunKinriCd1Nm))::text <> '')
				AND	(trim(both gKijunKinriNm3) IS NOT NULL AND (trim(both gKijunKinriNm3))::text <> '')  THEN
				-- スプレッドがプラスの場合
				IF (coalesce(trim(both gSpread),0))::numeric  >= 0 THEN
					result.gCoupon1 := recUpdMgr.gKijunKinriCd1Nm || ' − ' || gKijunKinriNm3 || ' ＋ ' || trim(both gSpread) || '%';
				-- スプレッドがマイナスの場合
				ELSE
					result.gCoupon1 := recUpdMgr.gKijunKinriCd1Nm || ' − ' || gKijunKinriNm3 || ' − ' || replace(trim(both gSpread), '-', '') || '%';
				END IF;
				--期中銘柄変更（利払/償還）２．基準金利コード１　=　銘柄利払回次．基準金利利率１、銘柄基本．基準金利コード２　= 銘柄利払回次．基準金利利率２
				result.gCoupon2 := '( ' || recUpdMgr.gKijunKinriCd1Nm || ' ＝ ' || trim(both gKijunKinriRrt1) || '%' || '、'
							 || gKijunKinriNm3 || ' ＝ ' || trim(both gKijunKinriRrt2) || '% )';
			ELSE
				IF coalesce(trim(both recUpdMgr.gKijunKinriCd1Nm)::text, '') = ''
					AND	coalesce(trim(both gKijunKinriNm3)::text, '') = ''  THEN
					-- スプレッドが 0 の場合
					IF (coalesce(trim(both gSpread),0))::numeric  = 0 THEN
						result.gCoupon1 := '';
					-- スプレッドが 0以外の場合
					ELSE
						result.gCoupon1 := trim(both gSpread) || '%';
					END IF;
					result.gCoupon2 := '';
				ELSE
					-- 期中銘柄変更（利払/償還）２．基準金利コード１のみ入力されている場合
					IF (trim(both recUpdMgr.gKijunKinriCd1Nm) IS NOT NULL AND (trim(both recUpdMgr.gKijunKinriCd1Nm))::text <> '') THEN
						-- スプレッドがプラスの場合
						IF (coalesce(trim(both gSpread),0))::numeric  >= 0 THEN
							result.gCoupon1 := recUpdMgr.gKijunKinriCd1Nm || ' ＋ ' || trim(both gSpread) || '%';
						-- スプレッドがマイナスの場合
						ELSE
							result.gCoupon1 := recUpdMgr.gKijunKinriCd1Nm || ' − ' || replace(trim(both gSpread), '-', '') || '%';
						END IF;
						result.gCoupon2 := '( ' || recUpdMgr.gKijunKinriCd1Nm || ' ＝ ' || trim(both gKijunKinriRrt1) || '% )';
					END IF;
					-- 銘柄基本．基準金利コード２のみ入力されている場合
					IF (trim(both gKijunKinriNm3) IS NOT NULL AND (trim(both gKijunKinriNm3))::text <> '') THEN
						IF (coalesce(trim(both gSpread),0))::numeric  >= 0 THEN
							result.gCoupon1 := gKijunKinriNm3 || ' ＋ ' || trim(both gSpread) || '%';
						-- スプレッドがマイナスの場合
						ELSE
							result.gCoupon1 := gKijunKinriNm3 || ' − ' || replace(trim(both gSpread), '-', '') || '%';
						END IF;
						result.gCoupon2 := '( ' || gKijunKinriNm3 || ' ＝ ' || trim(both gKijunKinriRrt2) || '% )';
					END IF;
				END IF;
			END IF;
			-- 銘柄基本．基準金利コード２ = 「ブランク」以外の場合　→　空白
			IF (trim(both gMgrKihonKinriCd2) IS NOT NULL AND (trim(both gMgrKihonKinriCd2))::text <> '') THEN
				result.gCoupon3 := '';
			ELSE
				-- 期中銘柄変更（利払/償還）２．基準金利コード１ = 「その他」の場合　→　銘柄基本２．その他指標金利コード内容
				IF recUpdMgr.gKijunKinriCd1 = '700' THEN
					result.gCoupon3 := gShihyoukinriNmEtc;
				-- 期中銘柄変更（利払/償還）２．基準金利コード１ = 「その他」以外の場合　→　金利概要．金利概要
				ELSE
					result.gCoupon3 := recUpdMgr.gKijunKinriCd1Gaiyo;
				END IF;
			END IF;
		-- 上限下限適用有無フラグ:適用利率マイナス
		WHEN '5' THEN
			result.gCoupon1 := '';  -- クーポン条件１
			result.gCoupon2 := '';  -- クーポン条件２
			result.gCoupon3 := '';  -- クーポン条件３
		-- 上限下限適用有無フラグ:上限適用有り（固定値）
		WHEN '2' THEN
			result.gCoupon1 := '';  -- クーポン条件１
			result.gCoupon2 := '';  -- クーポン条件２
			result.gCoupon3 := '';  -- クーポン条件３
		-- 上限下限適用有無フラグ:下限適用有り（固定値）
		WHEN '4' THEN
			result.gCoupon1 := '';  -- クーポン条件１
			result.gCoupon2 := '';  -- クーポン条件２
			result.gCoupon3 := '';  -- クーポン条件３
		ELSE
			result.gCoupon1 := '';  -- クーポン条件１
			result.gCoupon2 := '';  -- クーポン条件２
			result.gCoupon3 := '';  -- クーポン条件３
	END CASE;
	
	RETURN result;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spip01901_getcoupon (recUpdMgr spip01901_type_record) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spip01901_getkakushasairoundprocess (processKbn MGR_KIHON.RKN_ROUND_PROCESS%TYPE ,kakusahsaiKngk numeric) RETURNS numeric AS $body$
BEGIN
	-- 利金計算単位未満端数処理区分 により、各社債当りの利子額の端数処理を切替
	IF		processKbn = '1' THEN 	-- 切捨て
		RETURN TRUNC(kakusahsaiKngk);
	ELSIF 	processKbn = '2' THEN 	-- 四捨五入
		RETURN ROUND(kakusahsaiKngk);
	ELSIF 	processKbn = '3' THEN 	-- 切上げ
		RETURN TRUNC(kakusahsaiKngk + 0.9);
	END IF;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spip01901_getkakushasairoundprocess (processKbn MGR_KIHON.RKN_ROUND_PROCESS%TYPE ,kakusahsaiKngk numeric) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spip01901_getnextriritsuketteiymd (l_inItakuKaishaCd MGR_KIHON.ITAKU_KAISHA_CD%TYPE ,l_inMgrCd MGR_KIHON.MGR_CD%TYPE ,l_inRbrKjt MGR_RBRKIJ.RBR_KJT%TYPE) RETURNS MGR_RBRKIJ.RIRITSU_KETTEI_YMD%TYPE AS $body$
DECLARE
	gNextRiritsuKetteiYmd MGR_RBRKIJ.RIRITSU_KETTEI_YMD%TYPE;
	REPORT_ID CONSTANT char(11) := 'IP030001911';
BEGIN
	gNextRiritsuKetteiYmd := NULL;
	SELECT	MG2.RIRITSU_KETTEI_YMD 				-- 利率決定日
	INTO STRICT	gNextRiritsuKetteiYmd
	FROM	MGR_RBRKIJ MG2
	WHERE	MG2.ITAKU_KAISHA_CD = l_inItakuKaishaCd
	AND 	MG2.MGR_CD = l_inMgrCd
	AND     MG2.RBR_KJT = (SELECT trim(both MIN(wMG2.RBR_KJT))
							FROM  MGR_RBRKIJ wMG2
							WHERE wMG2.ITAKU_KAISHA_CD = l_inItakuKaishaCd
							  AND wMG2.MGR_CD = l_inMgrCd
							  AND wMG2.RBR_KJT > l_inRbrKjt
							  AND wMG2.KAIJI != 0);
	RETURN gNextRiritsuKetteiYmd;
EXCEPTION
	WHEN no_data_found THEN
		-- 今回が最終の場合等データが取得できないときはNULLにしておく。（この後のロジックで'-'がセットされる。）
		RETURN NULL;
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', REPORT_ID, '銘柄コード:'||l_inMgrCd||' 利払期日:'||l_inRbrKjt);
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spip01901_getnextriritsuketteiymd (l_inItakuKaishaCd MGR_KIHON.ITAKU_KAISHA_CD%TYPE ,l_inMgrCd MGR_KIHON.MGR_CD%TYPE ,l_inRbrKjt MGR_RBRKIJ.RBR_KJT%TYPE) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spip01901_getrknroundprocess (processKbn MGR_KIHON.RKN_ROUND_PROCESS%TYPE ,rknKngk MGR_KIHON.TSUKARISHI_KNGK_FAST%TYPE) RETURNS numeric AS $body$
BEGIN
	-- 利金計算単位未満端数処理区分 により、「金額チェック用の１通貨当たりの利子額」の端数処理を切替
	IF		processKbn = '1' THEN 	-- 切捨て
		RETURN TRUNC(rknKngk ::numeric, 13);
	ELSIF 	processKbn = '2' THEN 	-- 四捨五入
		RETURN round((rknKngk )::numeric,13);
	ELSIF 	processKbn = '3' THEN 	-- 切上げ
		RETURN TRUNC(rknKngk + 0.0000000000009 ::numeric, 13);
	END IF;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spip01901_getrknroundprocess (processKbn MGR_KIHON.RKN_ROUND_PROCESS%TYPE ,rknKngk MGR_KIHON.TSUKARISHI_KNGK_FAST%TYPE) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spip01901_getupdmgrrbr2 (
	l_inItakuKaishaCd TEXT, -- 委託会社コード
	l_inMgrCd TEXT, -- 銘柄コード
	l_inShrKjt TEXT,   -- 支払期日
	p_reportId TEXT  -- REPORT_ID parameter
) RETURNS spip01901_updmgr_result AS $body$
DECLARE
	result spip01901_updmgr_result;
BEGIN
	-- Initialize result
	result.recUpdMgr.gMgrCd := NULL;
	result.gSakuseiDt        := NULL;
	result.gShoninDt         := NULL;
	
	SELECT
		-- 期中銘柄変更（利払）２ 
		BT05.KIJUN_KINRI_CD1                                   AS RBR2_KIJUN_KINRI_CD1           -- 基準金利コード１
		,BT05.KINRIMAX                                         AS RBR2_KINRIMAX                   -- 基準金利（上限） 
		,TO_CHAR(BT05.KINRIMAX_KINRI,'FM99999999990.0000000')           AS RBR2_KINRIMAX_KINRI             -- 基準金利（上限）金利
		,TO_CHAR(BT05.KINRIMAX_SPREAD,'FM99999999990.0000000')          AS RBR2_KINRIMAX_SPREAD            -- 基準金利（上限）スプレッド
		,TO_CHAR(BT05.MAX_KINRI,'FM99999999990.0000000')                AS RBR2_MAX_KINRI                  -- 上限金利
		,TO_CHAR(BT05.KINRIMAX_TEKIYORIRITSU,'FM99999999990.0000000')   AS RBR2_KINRIMAX_TEKIYORIRITSU     -- 基準金利（上限）適用利率
		,BT05.KINRIFLOOR                                       AS RBR2_KINRIFLOOR                 -- 基準金利（下限）
		,TO_CHAR(BT05.KINRIFLOOR_KINRI,'FM99999999990.0000000')         AS RBR2_KINRIFLOOR_KINRI           -- 基準金利（下限）金利
		,TO_CHAR(BT05.KINRIFLOOR_SPREAD,'FM99999999990.0000000')        AS RBR2_KINRIFLOOR_SPREAD          -- 基準金利（下限）スプレッド
		,TO_CHAR(BT05.FLOOR_KINRI,'FM99999999990.0000000')              AS RBR2_FLOOR_KINRI                -- 下限金利
		,TO_CHAR(BT05.KINRIFLOOR_TEKIYORIRITSU,'FM99999999990.0000000') AS RBR2_KINRIFLOOR_TEKIYORIRITSU   -- 基準金利（下限）適用利率
		,BT05.TEKIYO_UMU                                       AS RBR2_TEKIYO_UMU                 -- 上限・下限適用有無
		,(SELECT BT20.KINRI_NM
			FROM KINRI_GAIYO BT20
			  WHERE BT20.SHIHYOKINRI_CD = BT05.KINRIMAX
			) AS RBR2_KINRIMAX_NM   -- 期中銘柄変更（利払）２_基準金利（上限）_基準金利名称
		,(SELECT BT20.KINRI_GAIYO 
			FROM KINRI_GAIYO BT20
			WHERE BT20.SHIHYOKINRI_CD = BT05.KINRIMAX
			) AS RBR2_KINRIMAX_GAIYO_NM   -- 期中銘柄変更（利払）２_基準金利（上限）_基準金利概要
		,(SELECT BT20.KINRI_NM 
			FROM KINRI_GAIYO BT20
			WHERE BT20.SHIHYOKINRI_CD = BT05.KINRIFLOOR
			) AS RBR2_KINRIFLOOR_NM   -- 期中銘柄変更（利払）２_基準金利（下限）_基準金利名称
		,(SELECT BT20.KINRI_GAIYO 
			FROM KINRI_GAIYO BT20
			WHERE BT20.SHIHYOKINRI_CD = BT05.KINRIFLOOR
			) AS RBR2_KINRIMAX_GAIYO_NM   -- 期中銘柄変更（利払）２_基準金利（下限）_基準金利概要
		,(SELECT BT20.KINRI_NM 
			   FROM KINRI_GAIYO BT20
			  WHERE BT20.SHIHYOKINRI_CD = BT05.KIJUN_KINRI_CD1
			) AS RBR2_KIJUN_KINRI_CD1_NM   -- 期中銘柄変更（利払）２_基準金利コード１_基準金利名称
		,(SELECT BT20.KINRI_GAIYO 
			FROM KINRI_GAIYO BT20
			  WHERE BT20.SHIHYOKINRI_CD = BT05.KIJUN_KINRI_CD1
		) AS RBR2_KIJUN_KINRI_CD1_GAIYO_NM    -- 期中銘柄変更（利払）２_基準金利コード１_基準金利概要
		-- 期中銘柄変更（利払）
		,MG22.SHORI_KBN       AS RBR_SHORI_KBN                        -- 処理区分
		,MG22.MGR_HENKO_KBN   AS RBR_MGR_HENKO_KBN                    -- 銘柄情報変更区分
		,MG22.MGR_CD                                                  -- 期中銘柄変更（利払）
		,TO_CHAR(MG22.SAKUSEI_DT, 'YYYYMMDD') AS AKUSEI_DT            --作成日時
		,TO_CHAR(MG22.SHONIN_DT, 'YYYYMMDD')  AS SHONIN_DT            --承認日時
		INTO STRICT 
			-- 期中銘柄変更（利払）２
			result.recUpdMgr.gKijunKinriCd1             -- 基準金利コード１
			,result.recUpdMgr.gKinriMax                  -- 基準金利（上限）
			,result.recUpdMgr.gKinriMaxKinri             -- 基準金利（上限）金利	
			,result.recUpdMgr.gKinriMaxSpread            -- 基準金利（上限）スプレッド
			,result.recUpdMgr.gMaxKinri                  -- 上限金利
			,result.recUpdMgr.gKinriMaxTekiyoriritru     -- 基準金利（上限）適用利率
			,result.recUpdMgr.gKinriFloor                -- 基準金利（下限）
			,result.recUpdMgr.gKinriFloorKinri 	         -- 基準金利（下限）金利
			,result.recUpdMgr.gKinriFloorSpread          -- 基準金利（下限）スプレッド
			,result.recUpdMgr.gFloorKinri                -- 下限金利
			,result.recUpdMgr.gFloorKinriTekiyoriritru   -- 基準金利（下限）適用利率
			,result.recUpdMgr.gTekiyoUmu                 -- 上限・下限適用有無
			,result.recUpdMgr.gKinriMaxNm                -- 基準金利（上限）_基準金利名称
			,result.recUpdMgr.gKinriMaxGaiyo             -- 基準金利（上限）_基準金利概要
			,result.recUpdMgr.gKinriFloorNm              -- 基準金利（下限）_基準金利名称
			,result.recUpdMgr.gKinriFloorGaiyo           -- 基準金利（下限）_基準金利概要
			,result.recUpdMgr.gKijunKinriCd1Nm           -- 基準金利コード１_基準金利名称
			,result.recUpdMgr.gKijunKinriCd1Gaiyo        -- 基準金利コード１_基準金利概要
			,result.recUpdMgr.gShoriKbn                  -- 処理区分
			,result.recUpdMgr.gMgrHenkoKbn               -- 銘柄情報変更区分
			,result.recUpdMgr.gMgrCd                     -- 銘柄コード
			,result.gSakuseiDt                               -- 作成日時
			,result.gShoninDt                                -- 作成日時
	FROM
		UPD_MGR_RBR MG22,
		UPD_MGR_RBR2 BT05
	WHERE 
		MG22.ITAKU_KAISHA_CD = BT05.ITAKU_KAISHA_CD   -- 委託会社コード
	AND	MG22.MGR_CD  = BT05.MGR_CD                    -- 銘柄コード
	AND	MG22.SHR_KJT = BT05.SHR_KJT                   -- 支払期日
	AND	MG22.MGR_HENKO_KBN = BT05.MGR_HENKO_KBN       -- 銘柄情報変更区分
	AND MG22.SHORI_KBN = '1'
	AND MG22.ITAKU_KAISHA_CD = l_inItakuKaishaCd
	AND MG22.MGR_CD = l_inMgrCd
	AND MG22.SHR_KJT =l_inShrKjt  LIMIT 1;
	
	RETURN result;
-- エラー処理
EXCEPTION
	WHEN no_data_found THEN
		result.recUpdMgr.gMgrCd := NULL; -- 銘柄コード
		result.gSakuseiDt        := NULL; -- 作成日時
		result.gShoninDt         := NULL; -- 作成日時
		RETURN result;
	WHEN	OTHERS	THEN
		CALL pkLog.fatal('ECM701', p_reportId, '銘柄コード:' || l_inMgrCd||' 利払期日:' || l_inShrKjt);
		-- RAISE;
		RETURN result;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spip01901_getupdmgrrbr2 (l_inItakuKaishaCd TEXT, l_inMgrCd TEXT, l_inShrKjt TEXT, p_reportId TEXT) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spip01901_getupdmgrshn2 (
	l_inKozaTenCifCd TEXT, -- 口座店CIFコード
	l_inMgrCd TEXT, -- 銘柄コード
	l_inShrKjt TEXT,   -- 支払期日
	l_inItakuKaishaCd TEXT,  -- Added parameter
	p_reportId TEXT  -- REPORT_ID parameter
) RETURNS spip01901_updmgr_result AS $body$
DECLARE
	result spip01901_updmgr_result;
BEGIN
	-- Initialize result
	result.recUpdMgr.gMgrCd := NULL;
	result.gSakuseiDt        := NULL;
	result.gShoninDt         := NULL;
	
	SELECT
		-- 期中銘柄変更（利払）２ 
		BT06.KIJUN_KINRI_CD1                                   AS SHN2_KIJUN_KINRI_CD1           -- 基準金利コード１
		,BT06.KINRIMAX                                         AS SHN2_KINRIMAX                   -- 基準金利（上限） 
		,TO_CHAR(BT06.KINRIMAX_KINRI,'FM99999999990.0000000')           AS SHN2_KINRIMAX_KINRI             -- 基準金利（上限）金利
		,TO_CHAR(BT06.KINRIMAX_SPREAD,'FM99999999990.0000000')          AS SHN2_KINRIMAX_SPREAD            -- 基準金利（上限）スプレッド
		,TO_CHAR(BT06.MAX_KINRI,'FM99999999990.0000000')                AS SHN2_MAX_KINRI                  -- 上限金利
		,TO_CHAR(BT06.KINRIMAX_TEKIYORIRITSU,'FM99999999990.0000000')   AS SHN2_KINRIMAX_TEKIYORIRITSU     -- 基準金利（上限）適用利率
		,BT06.KINRIFLOOR                                       AS SHN2_KINRIFLOOR                 -- 基準金利（下限）
		,TO_CHAR(BT06.KINRIFLOOR_KINRI,'FM99999999990.0000000')         AS SHN2_KINRIFLOOR_KINRI           -- 基準金利（下限）金利
		,TO_CHAR(BT06.KINRIFLOOR_SPREAD,'FM99999999990.0000000')        AS SHN2_KINRIFLOOR_SPREAD          -- 基準金利（下限）スプレッド
		,TO_CHAR(BT06.FLOOR_KINRI,'FM99999999990.0000000')              AS SHN2_FLOOR_KINRI                -- 下限金利
		,TO_CHAR(BT06.KINRIFLOOR_TEKIYORIRITSU,'FM99999999990.0000000') AS SHN2_KINRIFLOOR_TEKIYORIRITSU   -- 基準金利（下限）適用利率
		,BT06.TEKIYO_UMU                                       AS SHN2_TEKIYO_UMU                 -- 上限・下限適用有無
		,(SELECT BT20.KINRI_NM
			FROM KINRI_GAIYO BT20
			  WHERE BT20.SHIHYOKINRI_CD = BT06.KINRIMAX
			) AS SHN2_KINRIMAX_NM   -- 期中銘柄変更（利払）２_基準金利（上限）_基準金利名称
		,(SELECT BT20.KINRI_GAIYO 
			FROM KINRI_GAIYO BT20
			WHERE BT20.SHIHYOKINRI_CD = BT06.KINRIMAX
			) AS SHN2_KINRIMAX_GAIYO_NM   -- 期中銘柄変更（利払）２_基準金利（上限）_基準金利概要
		,(SELECT BT20.KINRI_NM 
			FROM KINRI_GAIYO BT20
			WHERE BT20.SHIHYOKINRI_CD = BT06.KINRIFLOOR
			) AS SHN2_KINRIFLOOR_NM   -- 期中銘柄変更（利払）２_基準金利（下限）_基準金利名称
		,(SELECT BT20.KINRI_GAIYO 
			FROM KINRI_GAIYO BT20
			WHERE BT20.SHIHYOKINRI_CD = BT06.KINRIFLOOR
			) AS SHN2_KINRIFLOOR_GAIYO_NM   -- 期中銘柄変更（利払）２_基準金利（下限）_基準金利概要
		,(SELECT BT20.KINRI_NM 
			   FROM KINRI_GAIYO BT20
			  WHERE BT20.SHIHYOKINRI_CD = BT06.KIJUN_KINRI_CD1
			) AS SHN2_KIJUN_KINRI_CD1_NM   -- 期中銘柄変更（利払）２_基準金利コード１_基準金利名称
		,(SELECT BT20.KINRI_GAIYO 
			FROM KINRI_GAIYO BT20
			  WHERE BT20.SHIHYOKINRI_CD = BT06.KIJUN_KINRI_CD1
		) AS SHN2_KIJUN_KINRI_CD1_GAIYO_NM    -- 期中銘柄変更（利払）２_基準金利コード１_基準金利概要
		-- 期中銘柄変更（利払）
		,MG23.SHORI_KBN       AS RBR_SHORI_KBN                        -- 処理区分
		,MG23.MGR_HENKO_KBN   AS RBR_MGR_HENKO_KBN                    -- 銘柄情報変更区分
		,MG23.MGR_CD                                                  -- 期中銘柄変更（利払）
		,TO_CHAR(MG23.SAKUSEI_DT, 'YYYYMMDD') AS AKUSEI_DT            -- 作成日時
		,TO_CHAR(MG23.SHONIN_DT, 'YYYYMMDD')  AS SHONIN_DT            -- 承認日時
		INTO STRICT 
			-- 期中銘柄変更（利払）２
			result.recUpdMgr.gKijunKinriCd1             -- 基準金利コード１
			,result.recUpdMgr.gKinriMax                  -- 基準金利（上限）
			,result.recUpdMgr.gKinriMaxKinri             -- 基準金利（上限）金利	
			,result.recUpdMgr.gKinriMaxSpread            -- 基準金利（上限）スプレッド
			,result.recUpdMgr.gMaxKinri                  -- 上限金利
			,result.recUpdMgr.gKinriMaxTekiyoriritru     -- 基準金利（上限）適用利率
			,result.recUpdMgr.gKinriFloor                -- 基準金利（下限）
			,result.recUpdMgr.gKinriFloorKinri 	         -- 基準金利（下限）金利
			,result.recUpdMgr.gKinriFloorSpread          -- 基準金利（下限）スプレッド
			,result.recUpdMgr.gFloorKinri                -- 下限金利
			,result.recUpdMgr.gFloorKinriTekiyoriritru   -- 基準金利（下限）適用利率
			,result.recUpdMgr.gTekiyoUmu                 -- 上限・下限適用有無
			,result.recUpdMgr.gKinriMaxNm                -- 基準金利（上限）_基準金利名称
			,result.recUpdMgr.gKinriMaxGaiyo             -- 基準金利（上限）_基準金利概要
			,result.recUpdMgr.gKinriFloorNm              -- 基準金利（下限）_基準金利名称
			,result.recUpdMgr.gKinriFloorGaiyo           -- 基準金利（下限）_基準金利概要
			,result.recUpdMgr.gKijunKinriCd1Nm           -- 基準金利コード１_基準金利名称
			,result.recUpdMgr.gKijunKinriCd1Gaiyo        -- 基準金利コード１_基準金利概要
			,result.recUpdMgr.gShoriKbn                  -- 処理区分
			,result.recUpdMgr.gMgrHenkoKbn               -- 銘柄情報変更区分
			,result.recUpdMgr.gMgrCd                     -- 銘柄コード
			,result.gSakuseiDt                           -- 作成日時
			,result.gShoninDt                            -- 作成日時
	FROM
		UPD_MGR_SHN  MG23,
		UPD_MGR_SHN2 BT06
	WHERE 
		MG23.ITAKU_KAISHA_CD = BT06.ITAKU_KAISHA_CD  -- 委託会社コード
	AND	MG23.MGR_CD  = BT06.MGR_CD                    -- 銘柄コード
	AND	MG23.SHR_KJT = BT06.SHR_KJT                   -- 支払期日
	AND	MG23.MGR_HENKO_KBN = BT06.MGR_HENKO_KBN       -- 銘柄情報変更区分
	AND MG23.SHORI_KBN = '1'
	AND MG23.ITAKU_KAISHA_CD = l_inItakuKaishaCd
	AND MG23.MGR_CD = l_inMgrCd
	AND MG23.SHR_KJT =l_inShrKjt
	AND MG23.MGR_HENKO_KBN IN ('40','41')   LIMIT 1;
	
	RETURN result;
	
-- エラー処理
EXCEPTION
	WHEN no_data_found THEN
		result.recUpdMgr.gMgrCd := NULL; -- 銘柄コード
		result.gSakuseiDt       := NULL; -- 作成日時
		result.gShoninDt        := NULL; -- 作成日時
		RETURN result;
	WHEN	OTHERS	THEN
		CALL pkLog.fatal('ECM701', p_reportId, '銘柄コード:' || l_inMgrCd || ' 利払期日:' || l_inShrKjt);
		-- RAISE;
		RETURN result;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spip01901_getupdmgrshn2 (l_inKozaTenCifCd TEXT, l_inMgrCd TEXT, l_inShrKjt TEXT, l_inItakuKaishaCd TEXT, p_reportId TEXT) FROM PUBLIC;