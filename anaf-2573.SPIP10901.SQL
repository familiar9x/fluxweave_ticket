DROP PROCEDURE spip10901;
CREATE OR REPLACE PROCEDURE spip10901 (
	l_inMgrCd TEXT,		-- 銘柄コード
	l_inItakuKaishaCd TEXT,		-- 委託会社コード
	l_inUserId TEXT,		-- ユーザーID
	l_inChohyoKbn TEXT,		-- 帳票区分
	l_inGyomuYmd TEXT,		-- 業務日付
	l_outSqlCode OUT integer,		-- リターン値
	l_outSqlErrM OUT text	-- エラーコメント
) AS $body$
DECLARE

--
--  * 著作権:Copyright(c)2004
--  * 会社名:JIP
--  * 概要　:副受託銘柄情報個別照会画面から、副受託銘柄詳細情報リスト（基本属性）を作成する。
--  * 引数　:l_inMgrCd			IN  CHAR		銘柄コード
--  * 　　　 l_inItakuKaishaCd	IN  CHAR		委託会社コード
--  * 　　　 l_inUserId			IN  CHAR		ユーザーID
--  * 　　　 l_inChohyoKbn		IN  CHAR		帳票区分
--  * 　　　 l_inGyomuYmd			IN  CHAR		業務日付
--  * 　　　 l_outSqlCode			OUT INTEGER		リターン値
--  * 　　　 l_outSqlErrM			OUT VARCHAR2	エラーコメント
--  * 返り値:なし
--  * @version $Id:$
--  *
--  ***************************************************************************
--  /* ログ　:
--  /* 日付        開発者名  目的
--  /* -------------------------------------------------------------------
--  /*　2025.01.08 JIP       新規作成
--  /*
--  ***************************************************************************
-- 
	--==============================================================================
	--          デバッグ機能                         
	--==============================================================================
	DEBUG numeric(1) := 0;
	--==============================================================================
	--          配列定義                          
	--==============================================================================
	-- TYPE spIp10901_TYPE_VARCHAR2 IS TABLE OF varchar(100) INDEX BY integer;
	--==============================================================================
	--          定数定義                          
	--==============================================================================
	RTN_OK     CONSTANT integer := 0; -- 正常
	RTN_NG     CONSTANT integer := 1; -- 予期したエラー
	RTN_NODATA CONSTANT integer := 2; -- データなし
	RTN_FATAL  CONSTANT integer := 99; -- 予期せぬエラー
    REPORT_ID1 CONSTANT char(11) := 'IP030010911'; -- 帳票ID
	REPORT_ID2 CONSTANT char(11) := 'IP030010912'; -- 帳票ID
	-- 書式フォーマット
	FMT_HAKKO_KNGK_J  CONSTANT char(18) := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9'; -- 発行金額
	FMT_SHOKAN_KNGK_J CONSTANT char(18) := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9'; -- 償還金額
	--==============================================================================
	--          変数定義                          
	--==============================================================================
	gRtnCd integer := RTN_OK; -- リターンコード
	gSeqNo integer := 0; -- シーケンス
	gGensaiRirekiSeqNo integer := 0; -- 減債履歴シーケンス
	gShoninStat SCODE.CODE_NM%TYPE; -- 承認状態
	gArySknKessaiCd varchar(100)[]; -- 社債管理会社受託会社コード１〜１０
	gArySknKessaiNm varchar(100)[]; -- 社債管理会社受託会社名１〜１０
	gItakuKaishaRnm VJIKO_ITAKU.BANK_RNM%TYPE; -- 委託会社略称
	-- 西暦変換用
	gWkHakkoYmd         varchar(20) := NULL; -- 発行年月日
	gWkFullshokanKjt    varchar(20) := NULL; -- 満期償還期日
	gWkStTeijishokanKjt varchar(20) := NULL; -- 初回定時償還期日
	gWkStRbrKjt         varchar(20) := NULL; -- 初回利払期日
	gWkZndkKijunYmd     varchar(20) := NULL; -- 残高基準日
	gWkTeikyoEndYmd     varchar(20) := NULL; -- 適用終了日
	gWkDefaultYmd       varchar(20) := NULL; -- デフォルト日
	-- 最終承認ユーザ及び最終承認日
	gLastShoninId  VMGR_STS.LAST_SHONIN_ID%TYPE; -- 最終承認ユーザId
	gLastShoninYmd VMGR_STS.LAST_SHONIN_YMD%TYPE; -- 最終承認日
	gMeimokuZndk        numeric := NULL;  -- 名目残高 
	gBankRnm            SOWN_INFO.BANK_RNM%TYPE;   -- 銀行略称
	--==============================================================================
	--          カーソル定義                          
	--==============================================================================
	curMeisai CURSOR FOR
		SELECT
			VMG0.KIHON_TEISEI_YMD, -- 基本訂正日
			VMG0.KIHON_TEISEI_USER_ID, -- 基本訂正ユーザ
			VMG0.LAST_SHONIN_YMD, -- 最終承認日
			VMG0.LAST_SHONIN_ID, -- 最終承認ユーザ
			VMG0.MGR_STAT_KBN, -- 銘柄ステータス区分
			VMG0.MGR_SEND_TAISHO_FLG, -- 銘柄送信対象フラグ
			VMG0.MGR_TAIKEI_KBN, -- 銘柄体系区分
			(SELECT CODE_NM
				FROM   SCODE
				WHERE  VMG0.MGR_STAT_KBN = CODE_VALUE AND
							 CODE_SHUBETSU = '161') AS SHONIN_STAT, -- 承認状態
			VMG1.MGR_CD, -- 銘柄コード
			VMG1.ISIN_CD, -- ＩＳＩＮコード
			VMG1.MGR_RNM, -- 銘柄略称
			VMG1.JTK_KBN_NM, -- 受託区分名称
			VMG1.HKT_CD, -- 発行体コード
			M01.HKT_RNM, -- 発行体略称
			VMG1.EIGYOTEN_CD, -- 営業店店番
			(SELECT M04.BUTEN_RNM
				FROM MBUTEN M04
				WHERE VMG1.ITAKU_KAISHA_CD = M04.ITAKU_KAISHA_CD
				AND VMG1.EIGYOTEN_CD = M04.BUTEN_CD) AS EIGYOTEN_NM, -- 営業店名称
			VMG1.HAKKODAIRI_CD, -- 発行代理人コード
			(SELECT VM02.BANK_RNM
				FROM VMBANK VM02
				WHERE VMG1.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				AND substr(VMG1.HAKKODAIRI_CD, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				AND substr(VMG1.HAKKODAIRI_CD, 2) = VM02.BANK_CD) AS HAKKODAIRI_RNM, -- 発行代理人略称
			M01.KOZA_TEN_CD, -- 口座店コード
			M01.KOZA_TEN_CIFCD, -- 口座店ＣＩＦコード
			VMG1.SHRDAIRI_CD, -- 支払代理人コード
			(SELECT VM02.BANK_RNM
				FROM VMBANK VM02
				WHERE VMG1.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				AND substr(VMG1.SHRDAIRI_CD, 1, 1) = VM02.FINANCIAL_SECURITIES_KBN
				AND substr(VMG1.SHRDAIRI_CD, 2) = VM02.BANK_CD) AS SHRDAIRI_RNM, -- 支払代理人略称
			VMG1.SKN_KESSAI_CD, -- 資金決済会社コード
			pkIpaName.getSknKessaiRnm(VMG1.ITAKU_KAISHA_CD,VMG1.SKN_KESSAI_CD) AS SKN_KESSAI_RNM, -- 資金決済会社略称
			VMG1.MGR_NM, -- 銘柄の正式名称
			VMG1.KK_HAKKO_CD, -- 機構発行体コード
			VMG1.KK_HAKKOSHA_RNM, -- 機構発行者略称
			VMG1.KAIGO_ETC, -- 回号等
			VMG1.BOSHU_KBN, -- 募集区分
			VMG1.BOSHU_KBN_NM, -- 募集区分名称
			VMG1.SAIKEN_KBN_NM, -- 債券種類名称
			VMG1.HOSHO_KBN_NM, -- 保証区分名称
			VMG1.TANPO_KBN_NM, -- 担保区分名称
			VMG1.HAKKO_YMD, -- 発行年月日
			(SELECT TSUKA_NM FROM MTSUKA WHERE VMG1.HAKKO_TSUKA_CD = TSUKA_CD) AS HAKKO_TSUKA_NM, -- 発行通貨名称
			CASE WHEN VMG1.KAKUSHASAI_KNGK=0 THEN  NULL  ELSE VMG1.KAKUSHASAI_KNGK END  AS KAKUSHASAI_KNGK, -- 各社債の金額
			CASE WHEN VMG1.HAKKO_KAGAKU=0 THEN  NULL  ELSE VMG1.HAKKO_KAGAKU END  AS HAKKO_KAGAKU, -- 発行価額
			CASE WHEN VMG1.SHASAI_TOTAL=0 THEN  NULL  ELSE VMG1.SHASAI_TOTAL END  AS SHASAI_TOTAL, -- 社債の総額
			VMG1.SHOKAN_METHOD_CD, -- 償還方法コード
			VMG1.SHOKAN_METHOD_NM, -- 償還方法名称
			(SELECT TSUKA_NM
				FROM   MTSUKA
				WHERE  VMG1.SHOKAN_TSUKA_CD = TSUKA_CD) AS SHOKAN_TSUKA_NM, -- 償還通貨名称
			CASE WHEN VMG1.KAWASE_RATE=0 THEN  NULL  ELSE VMG1.KAWASE_RATE END  AS KAWASE_RATE, -- 為替レート
			VMG1.CALLALL_UMU_FLG_NM, -- コールオプション有無（全額）名称
			VMG1.FULLSHOKAN_KJT, -- 満期償還期日
			(SELECT CODE_NM
				FROM   SCODE
				WHERE  VMG1.TEIJI_SHOKAN_TSUTI_KBN = CODE_VALUE AND
							 CODE_SHUBETSU = '520') AS TEIJI_SHOKAN_TSUTI_KBN_NM, -- 定時償還通知区分名称
			VMG1.CALLITIBU_UMU_FLG_NM, -- コールオプション有無（一部）名称
			(SELECT CODE_NM
				FROM   SCODE
				WHERE  VMG1.NEN_TEIJI_SHOKAN_CNT = CODE_VALUE AND
							 CODE_SHUBETSU = '142') AS NEN_TEIJI_SHOKAN_CNT, -- 年定時償還回数(名称)
			CASE WHEN VMG1.TOTAL_TEIJI_SHOKAN_CNT=0 THEN  NULL  ELSE VMG1.TOTAL_TEIJI_SHOKAN_CNT END  AS TOTAL_TEIJI_SHOKAN_CNT, -- 総定時償還回数
			VMG1.PUTUMU_FLG_NM, -- プットオプション有無名称
			VMG1.ST_TEIJISHOKAN_KJT, -- 初回定時償還期日
			CASE WHEN VMG1.TEIJI_SHOKAN_KNGK=0 THEN  NULL  ELSE VMG1.TEIJI_SHOKAN_KNGK END  AS TEIJI_SHOKAN_KNGK, -- 定時償還金額
			MG6.BANK_CD AS SHASAI_KANRI_JUTAKU_CD, -- 社債管理会社受託会社コード
			(SELECT VM02.BANK_RNM
				FROM VMBANK VM02
				WHERE MG6.ITAKU_KAISHA_CD = VM02.ITAKU_KAISHA_CD
				AND MG6.FINANCIAL_SECURITIES_KBN = VM02.FINANCIAL_SECURITIES_KBN
				AND MG6.BANK_CD = VM02.BANK_CD) AS SHASAI_KANRI_JUTAKU_RNM, -- 社債管理会社受託会社名称
			(SELECT CODE_NM
				FROM   SCODE
				WHERE  VMG1.KYUJITSU_KBN = CODE_VALUE AND
							 CODE_SHUBETSU = '506') AS KYUJITSU_KBN_NM, -- 休日処理区分名称
			(SELECT CODE_NM
				FROM   SCODE
				WHERE  VMG1.KYUJITSU_LD_FLG = CODE_VALUE AND
							 CODE_SHUBETSU = '504') AS KYUJITSU_LD_FLG_NM, -- 休日処理ロンドン名称
			(SELECT CODE_NM
				FROM   SCODE
				WHERE  VMG1.KYUJITSU_NY_FLG = CODE_VALUE AND
							 CODE_SHUBETSU = '504') AS KYUJITSU_NY_FLG_NM, -- 休日処理ニューヨーク名称
			(SELECT CODE_NM
				FROM   SCODE
				WHERE  VMG1.KYUJITSU_ETC_FLG = CODE_VALUE AND
							 CODE_SHUBETSU = '504') AS KYUJITSU_ETC_FLG_NM, -- 休日処理その他海外名称
			VMG1.RITSUKE_WARIBIKI_KBN_NM, -- 利付割引区分名称
			(SELECT TSUKA_NM FROM MTSUKA WHERE VMG1.RBR_TSUKA_CD = TSUKA_CD) AS RBR_TSUKA_NM, -- 利払通貨名称
			CASE WHEN VMG1.RBR_KAWASE_RATE=0 THEN  NULL  ELSE VMG1.RBR_KAWASE_RATE END  AS RBR_KAWASE_RATE, -- 利払為替レート
			(SELECT CODE_NM
				FROM   SCODE
				WHERE  VMG1.NENRBR_CNT = CODE_VALUE AND
							 CODE_SHUBETSU = '142') AS NENRBR_CNT_NM, -- 年利払回数(名称)
			CASE WHEN VMG1.TOTAL_RBR_CNT=0 THEN  NULL  ELSE VMG1.TOTAL_RBR_CNT END  AS TOTAL_RBR_CNT, -- 総利払回数
			VMG1.RBR_DD, -- 利払日付
			VMG1.ST_RBR_KJT, -- 初回利払期日
			(SELECT CODE_NM
				FROM   SCODE
				WHERE  VMG1.LAST_RBR_FLG = CODE_VALUE AND
							 CODE_SHUBETSU = '515') AS LAST_RBR_FLG_NM, -- 最終利払有無フラグ名称
			CASE WHEN VMG1.RIRITSU=0 THEN  NULL  ELSE VMG1.RIRITSU END  AS RIRITSU, -- 利率
			VMG1.SHANAI_KOMOKU1, -- 社内処理用項目１
			VMG1.SHANAI_KOMOKU2, -- 社内処理用項目２
			VMG1.YOBI1, -- 予備１
			VMG1.YOBI2, -- 予備２
			VMG1.DKJ_MGR_CD, -- 独自銘柄コード
			(SELECT CODE_NM
				FROM   SCODE
				WHERE  VMG1.TOKUREI_SHASAI_FLG = CODE_VALUE AND
							 CODE_SHUBETSU = '522') AS TOKUREI_SHASAI_FLG_NM, -- 特例社債フラグ名称
			(SELECT CODE_NM
				FROM   SCODE
				WHERE  VMG1.PARTMGR_KBN = CODE_VALUE AND
							 CODE_SHUBETSU = '526') AS PARTMGR_KBN_NM, -- 分割銘柄区分名称
			VMG1.TEKIYO_END_YMD, -- 適用終了日
			VMG1.NEWISIN_CD, -- 新ＩＳＩＮコード
			VMG1.DEFAULT_YMD, -- デフォルト日
			VMG1.DEFAULT_BIKO, -- デフォルト備考
			VJ1.BANK_RNM, -- 銀行略称
			VJ1.JIKO_DAIKO_KBN, -- 自行代行区分
			VMG1.JTK_KBN, -- 受託区分
			VMG1.TOKUTEI_KOUSHASAI_FLG_NM, -- 特定公社債フラグ
			(SELECT CODE_RNM FROM SCODE WHERE CODE_VALUE = BT03.MUTB_FLG AND CODE_SHUBETSU = 'B23') AS MUTB_FLG_NM  -- 信託フラグ名称
		FROM vmgr_sts vmg0, vjiko_itaku vj1, mgr_kihon2 bt03, vmgr_list vmg1
LEFT OUTER JOIN mhakkotai m01 ON (VMG1.HKT_CD = M01.HKT_CD AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD)
LEFT OUTER JOIN mgr_jutakuginko mg6 ON (VMG1.MGR_CD = MG6.MGR_CD AND VMG1.ITAKU_KAISHA_CD = MG6.ITAKU_KAISHA_CD)
WHERE VMG1.MGR_CD = l_inMgrCd AND VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND VMG1.MGR_CD = VMG0.MGR_CD AND VMG1.ITAKU_KAISHA_CD = VMG0.ITAKU_KAISHA_CD     AND VMG1.ITAKU_KAISHA_CD = VJ1.KAIIN_ID AND VMG1.MGR_CD = BT03.MGR_CD AND VMG1.ITAKU_KAISHA_CD = BT03.ITAKU_KAISHA_CD
		ORDER  BY
			MG6.JTK_KBN,
			MG6.INPUT_NUM;
	-- レコード
	recWkMeisai RECORD;
	curGensaiRireki CURSOR FOR
		SELECT
			Z01.SHOKAN_YMD AS ZNDK_KIJUN_YMD, 									-- 残高基準日
			Z01.GENSAI_KNGK AS MGR_ZNDK, 										-- 銘柄残高
			Z01.FACTOR AS FACTOR 												-- 名目残高
		FROM
			GENSAI_RIREKI Z01
		WHERE
			Z01.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND
			Z01.MGR_CD = l_inMgrCd AND
			Z01.SHOKAN_KBN = '99';
	-- 減債履歴レコード
	recWkGensaiRireki RECORD;
	l_inItem 	   		TYPE_SREPORT_WK_ITEM := ROW();
	tempResult			record;
	--==============================================================================
	--  メイン処理 
	--==============================================================================
BEGIN
	IF DEBUG = 1
	THEN
		CALL pkLog.debug(l_inUserId, REPORT_ID1, 'spIp10901 START');
	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inMgrCd::text), '') = '' OR
		 coalesce(trim(both l_inItakuKaishaCd::text), '') = '' OR
		 coalesce(trim(both l_inUserId::text), '') = '' OR
		 coalesce(trim(both l_inChohyoKbn::text), '') = '' OR
		 coalesce(trim(both l_inGyomuYmd::text), '') = ''
	THEN
		-- パラメータエラー
		IF  DEBUG = 1
		THEN
			CALL pkLog.debug(l_inUserId, REPORT_ID1, 'param error');
		END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error(l_inUserId, REPORT_ID1, 'SQLERRM:' || '');
		RETURN;
	END IF;
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE  KEY_CD = l_inItakuKaishaCd AND
				 USER_ID = l_inUserId AND
				 CHOHYO_KBN = l_inChohyoKbn AND
				 SAKUSEI_YMD = l_inGyomuYmd AND (CHOHYO_ID = REPORT_ID1 OR CHOHYO_ID = REPORT_ID2);
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID1);
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID2);
	-- 配列の初期化
	FOR i IN 1 .. 10
	LOOP
		gArySknKessaiCd[i] := NULL;
		gArySknKessaiNm[i] := NULL;
	END LOOP;
	-- ５−１．自行情報マスタから銀行略称を取得
	SELECT
		BANK_RNM
	INTO STRICT
		gBankRnm
	FROM SOWN_INFO;
	-- データ取得
	FOR recMeisai IN curMeisai
	LOOP
		gSeqNo := gSeqNo + 1;
		IF gSeqNo = 1
		THEN
			gShoninStat := recMeisai.SHONIN_STAT;
			-- レコードのセット
			recWkMeisai := recMeisai;
		END IF;
		gArySknKessaiCd[gSeqNo] := recMeisai.SHASAI_KANRI_JUTAKU_CD;
		gArySknKessaiNm[gSeqNo] := recMeisai.SHASAI_KANRI_JUTAKU_RNM;
	END LOOP;
	-- 減債履歴データ取得
	FOR recGensaiRireki IN curGensaiRireki
	LOOP
		gGensaiRirekiSeqNo := gGensaiRirekiSeqNo + 1;
		IF gGensaiRirekiSeqNo = 1
		THEN
			recWkGensaiRireki := recGensaiRireki;
		END IF;
	END LOOP;
	IF gSeqNo > 0
	THEN
		-- 対象データあり
		-- 委託会社略称の設定
		gItakuKaishaRnm := NULL;
		IF recWkMeisai.JIKO_DAIKO_KBN = '2'
		THEN
			gItakuKaishaRnm := recWkMeisai.BANK_RNM;
		END IF;
		--  発行年月日（西暦変換）
		gWkHakkoYmd := NULL;
		IF (trim(both recWkMeisai.HAKKO_YMD) IS NOT NULL AND (trim(both recWkMeisai.HAKKO_YMD::text)) <> '')
		THEN
			gWkHakkoYmd := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.HAKKO_YMD);
		END IF;
		--  満期償還期日（西暦変換）-- 99999999のデータだけありえるのでそれに対処。
		gWkFullshokanKjt := NULL;
		IF trim(both recWkMeisai.FULLSHOKAN_KJT) = '99999999'	--	償還期日が9999/99/99 だったら
		THEN
			gWkFullshokanKjt := recWkMeisai.FULLSHOKAN_KJT;
		ELSIF (trim(both recWkMeisai.FULLSHOKAN_KJT) IS NOT NULL AND (trim(both recWkMeisai.FULLSHOKAN_KJT::text)) <> '')
		THEN
			gWkFullshokanKjt := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.FULLSHOKAN_KJT);
		END IF;
		--  初回定時償還期日（西暦変換）
		gWkStTeijishokanKjt := NULL;
		IF (trim(both recWkMeisai.ST_TEIJISHOKAN_KJT) IS NOT NULL AND (trim(both recWkMeisai.ST_TEIJISHOKAN_KJT::text)) <> '')
		THEN
			gWkStTeijishokanKjt := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.ST_TEIJISHOKAN_KJT);
		END IF;
		--  初回利払期日（西暦変換）
		gWkStRbrKjt := NULL;
		IF (trim(both recWkMeisai.ST_RBR_KJT) IS NOT NULL AND (trim(both recWkMeisai.ST_RBR_KJT::text)) <> '')
		THEN
			gWkStRbrKjt := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.ST_RBR_KJT);
		END IF;
		--  残高基準日（西暦変換）
		gWkZndkKijunYmd := NULL;
		IF (trim(both recWkGensaiRireki.ZNDK_KIJUN_YMD) IS NOT NULL AND (trim(both recWkGensaiRireki.ZNDK_KIJUN_YMD::text)) <> '')
		THEN
			gWkZndkKijunYmd := pkDate.seirekiChangeZeroSuppressSlash(recWkGensaiRireki.ZNDK_KIJUN_YMD);
		END IF;
		--  適用終了日（西暦変換）
		gWkTeikyoEndYmd := NULL;
		IF (trim(both recWkMeisai.TEKIYO_END_YMD) IS NOT NULL AND (trim(both recWkMeisai.TEKIYO_END_YMD::text)) <> '')
		THEN
			gWkTeikyoEndYmd := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.TEKIYO_END_YMD);
		END IF;
		--  デフォルト日（西暦変換）
		gWkDefaultYmd := NULL;
		IF (trim(both recWkMeisai.DEFAULT_YMD) IS NOT NULL AND (trim(both recWkMeisai.DEFAULT_YMD::text)) <> '')
		THEN
			gWkDefaultYmd := pkDate.seirekiChangeZeroSuppressSlash(recWkMeisai.DEFAULT_YMD);
		END IF;
		-- 最終承認ユーザの表示非表示切り替え
		-- はじめに初期化しておく
		gLastShoninYmd := NULL;
		gLastShoninId  := NULL;
		-- 承認ステータスが承認以外の場合には表示しないようにする
		IF recWkMeisai.MGR_STAT_KBN = '1'
		THEN
			gLastShoninYmd := recWkMeisai.LAST_SHONIN_YMD;
			gLastShoninId  := recWkMeisai.LAST_SHONIN_ID;
		END IF;
		-- 減債履歴レコードあり かつ 償還方法コードが2(定時償還)の場合、名目残高を計算する
		gMeimokuzndk := NULL;
		IF gGensaiRirekiSeqNo > 0 AND recWkMeisai.SHOKAN_METHOD_CD = '2'
		THEN
			gMeimokuZndk := TRUNC(recWkGensaiRireki.MGR_ZNDK / recWkGensairireki.FACTOR::numeric, 0);
		END IF;
		-- 帳票ワークへデータを追加
		l_inItem.l_inItem001		:=	l_inUserId; 								-- ユーザＩＤ
		l_inItem.l_inItem002		:=	recWkMeisai.KIHON_TEISEI_YMD;			-- 基本訂正日
		l_inItem.l_inItem003		:=	recWkMeisai.KIHON_TEISEI_USER_ID; 		-- 基本訂正ユーザ
		l_inItem.l_inItem004		:=	gLastShoninYmd; 							-- 最終承認日
		l_inItem.l_inItem005		:=	gLastShoninId; 							-- 最終承認ユーザ
		l_inItem.l_inItem006		:=	gShoninStat; 								-- 承認状態
		l_inItem.l_inItem007		:=	recWkMeisai.MGR_CD; 						-- 銘柄コード
		l_inItem.l_inItem008		:=	recWkMeisai.ISIN_CD; 						-- ＩＳＩＮコード
		l_inItem.l_inItem009		:=	recWkMeisai.MGR_RNM; 						-- 銘柄略称
		l_inItem.l_inItem010		:=	recWkMeisai.JTK_KBN_NM; 					-- 受託区分名称
		l_inItem.l_inItem011		:=	recWkMeisai.HKT_CD; 						-- 発行体コード
		l_inItem.l_inItem012		:=	recWkMeisai.HKT_RNM; 						-- 発行体略称
		l_inItem.l_inItem013		:=	recWkMeisai.EIGYOTEN_CD; 					-- 営業店店番
		l_inItem.l_inItem014		:=	recWkMeisai.EIGYOTEN_NM; 					-- 営業店名称
		l_inItem.l_inItem015		:=	recWkMeisai.HAKKODAIRI_CD; 				-- 発行代理人コード
		l_inItem.l_inItem016		:=	recWkMeisai.HAKKODAIRI_RNM; 				-- 発行代理人略称
		l_inItem.l_inItem017		:=	recWkMeisai.KOZA_TEN_CD; 					-- 口座店コード
		l_inItem.l_inItem018		:=	recWkMeisai.KOZA_TEN_CIFCD; 				-- 口座店ＣＩＦコード
		l_inItem.l_inItem019		:=	recWkMeisai.SHRDAIRI_CD; 					-- 支払代理人コード
		l_inItem.l_inItem020		:=	recWkMeisai.SHRDAIRI_RNM; 				-- 支払代理人略称
		l_inItem.l_inItem021		:=	recWkMeisai.SKN_KESSAI_CD; 				-- 資金決済会社コード
		l_inItem.l_inItem022		:=	recWkMeisai.SKN_KESSAI_RNM; 				-- 資金決済会社略称
		l_inItem.l_inItem023		:=	recWkMeisai.MGR_NM; 						-- 銘柄の正式名称
		l_inItem.l_inItem024		:=	recWkMeisai.KK_HAKKO_CD; 					-- 機構発行体コード
		l_inItem.l_inItem025		:=	recWkMeisai.KK_HAKKOSHA_RNM; 				-- 機構発行者略称
		l_inItem.l_inItem026		:=	recWkMeisai.KAIGO_ETC; 					-- 回号等
		l_inItem.l_inItem027		:=	recWkMeisai.BOSHU_KBN; 					-- 募集区分
		l_inItem.l_inItem028		:=	recWkMeisai.BOSHU_KBN_NM; 				-- 募集区分名称
		l_inItem.l_inItem029		:=	recWkMeisai.SAIKEN_KBN_NM; 				-- 債券種類名称
		l_inItem.l_inItem030		:=	recWkMeisai.HOSHO_KBN_NM; 				-- 保証区分名称
		l_inItem.l_inItem031		:=	recWkMeisai.TANPO_KBN_NM; 				-- 担保区分名称
		l_inItem.l_inItem032		:=	gWkHakkoYmd; 								-- 発行年月日
		l_inItem.l_inItem033		:=	recWkMeisai.HAKKO_TSUKA_NM; 				-- 発行通貨名称
		l_inItem.l_inItem034		:=	recWkMeisai.KAKUSHASAI_KNGK; 				-- 各社債の金額
		l_inItem.l_inItem035		:=	recWkMeisai.HAKKO_KAGAKU; 				-- 発行価額
		l_inItem.l_inItem036		:=	recWkMeisai.SHASAI_TOTAL; 				-- 社債の総額
		l_inItem.l_inItem037		:=	recWkMeisai.SHOKAN_METHOD_NM; 			-- 償還方法名称
		l_inItem.l_inItem038		:=	recWkMeisai.SHOKAN_TSUKA_NM; 				-- 償還通貨名称
		l_inItem.l_inItem039		:=	recWkMeisai.KAWASE_RATE; 					-- 為替レート
		l_inItem.l_inItem040		:=	recWkMeisai.CALLALL_UMU_FLG_NM; 			-- コールオプション有無（全額）名称
		l_inItem.l_inItem041		:=	gWkFullshokanKjt; 						-- 満期償還期日
		l_inItem.l_inItem042		:=	recWkMeisai.TEIJI_SHOKAN_TSUTI_KBN_NM; 	-- 定時償還通知区分名称
		l_inItem.l_inItem043		:=	recWkMeisai.CALLITIBU_UMU_FLG_NM; 		-- コールオプション有無（一部）名称
		l_inItem.l_inItem044		:=	recWkMeisai.NEN_TEIJI_SHOKAN_CNT; 		-- 年定時償還回数
		l_inItem.l_inItem045		:=	recWkMeisai.TOTAL_TEIJI_SHOKAN_CNT; 		-- 総定時償還回数
		l_inItem.l_inItem046		:=	recWkMeisai.PUTUMU_FLG_NM; 				-- プットオプション有無名称
		l_inItem.l_inItem047		:=	gWkStTeijishokanKjt; 						-- 初回定時償還期日
		l_inItem.l_inItem048		:=	recWkMeisai.TEIJI_SHOKAN_KNGK; 			-- 定時償還金額
		l_inItem.l_inItem049		:=	gArySknKessaiCd[1];						-- 社債管理会社受託会社コード
		l_inItem.l_inItem050		:=	gArySknKessaiNm[1];						-- 社債管理会社受託会社名称
		l_inItem.l_inItem051		:=	gArySknKessaiCd[2];						-- 社債管理会社受託会社コード２
		l_inItem.l_inItem052		:=	gArySknKessaiNm[2];						-- 社債管理会社受託会社名称２
		l_inItem.l_inItem053		:=	gArySknKessaiCd[3];						-- 社債管理会社受託会社コード３
		l_inItem.l_inItem054		:=	gArySknKessaiNm[3];						-- 社債管理会社受託会社名称３
		l_inItem.l_inItem055		:=	gArySknKessaiCd[4];						-- 社債管理会社受託会社コード４
		l_inItem.l_inItem056		:=	gArySknKessaiNm[4];						-- 社債管理会社受託会社名称４
		l_inItem.l_inItem057		:=	gArySknKessaiCd[5];						-- 社債管理会社受託会社コード５
		l_inItem.l_inItem058		:=	gArySknKessaiNm[5];						-- 社債管理会社受託会社名称５
		l_inItem.l_inItem059		:=	gArySknKessaiCd[6];						-- 社債管理会社受託会社コード６
		l_inItem.l_inItem060		:=	gArySknKessaiNm[6];						-- 社債管理会社受託会社名称６
		l_inItem.l_inItem061		:=	gArySknKessaiCd[7];						-- 社債管理会社受託会社コード７
		l_inItem.l_inItem062		:=	gArySknKessaiNm[7];						-- 社債管理会社受託会社名称７
		l_inItem.l_inItem063		:=	gArySknKessaiCd[8];						-- 社債管理会社受託会社コード８
		l_inItem.l_inItem064		:=	gArySknKessaiNm[8];						-- 社債管理会社受託会社名称８
		l_inItem.l_inItem065		:=	gArySknKessaiCd[9];						-- 社債管理会社受託会社コード９
		l_inItem.l_inItem066		:=	gArySknKessaiNm[9];						-- 社債管理会社受託会社名称９
		l_inItem.l_inItem067		:=	gArySknKessaiCd[10];						-- 社債管理会社受託会社コード１０
		l_inItem.l_inItem068		:=	gArySknKessaiNm[10];						-- 社債管理会社受託会社名称１０
		l_inItem.l_inItem069		:=	recWkMeisai.KYUJITSU_KBN_NM; 				-- 休日処理区分名称
		l_inItem.l_inItem070		:=	recWkMeisai.KYUJITSU_LD_FLG_NM; 			-- 休日処理ロンドン名称
		l_inItem.l_inItem071		:=	recWkMeisai.KYUJITSU_NY_FLG_NM; 			-- 休日処理ニューヨーク名称
		l_inItem.l_inItem072		:=	recWkMeisai.KYUJITSU_ETC_FLG_NM; 			-- 休日処理その他海外名称
		l_inItem.l_inItem073		:=	gItakuKaishaRnm; 							-- 委託会社略称
		l_inItem.l_inItem074		:=	REPORT_ID1;								-- 帳票ＩＤ
		l_inItem.l_inItem075		:=	FMT_HAKKO_KNGK_J; 						-- 発行金額書式フォーマット
		l_inItem.l_inItem076		:=	FMT_SHOKAN_KNGK_J; 						-- 償還金額書式フォーマット
		l_inItem.l_inItem077		:=	'1';										-- ページNo
		l_inItem.l_inItem078		:=	'2';										-- ページ総数
		l_inItem.l_inItem079		:=	recWkMeisai.JTK_KBN; 						-- 受託区分
		l_inItem.l_inItem080		:=	recWkMeisai.TOKUTEI_KOUSHASAI_FLG_NM; 	-- 特定公社債フラグ名称
		l_inItem.l_inItem081		:=	gBankRnm; 								-- 銀行略称
		l_inItem.l_inItem082		:=	recWkMeisai.MUTB_FLG_NM; 					-- 信託フラグ名称
		l_inItem.l_inItem249		:=	'fkJtkSort1';							-- 帳票の出力順が、既存では帳票ＩＤの順になる。副受託の場合は銘柄情報のように、
																		-- 基本属性〜発行関連手数料計算書の順にならないため、ここでソート順を付け加えてます。

		CALL pkPrint.insertData(
			l_inKeyCd			=>	l_inItakuKaishaCd  						-- 識別コード
			, l_inUserId		=>	l_inUserId  								-- ユーザＩＤ
			, l_inChohyoKbn		=>	l_inChohyoKbn  							-- 帳票区分
			, l_inSakuseiYmd	=>	l_inGyomuYmd  							-- 作成年月日
			, l_inChohyoId		=>	REPORT_ID1 								-- 帳票ＩＤ
			, l_inSeqNo			=>	1 										-- 連番
			, l_inHeaderFlg		=>	'1' 									-- ヘッダフラグ
			,	l_inItem				=>	l_inItem
			, l_inKousinId		=>	l_inUserId  								-- 更新者ID
			, l_inSakuseiId		=>	l_inUserId  								-- 作成者ID
		);
		-- 帳票ワークへデータを追加
		l_inItem	:= ROW();
		l_inItem.l_inItem001		:=	l_inUserId; 								-- ユーザＩＤ
		l_inItem.l_inItem002		:=	recWkMeisai.KIHON_TEISEI_YMD; 			-- 基本訂正日
		l_inItem.l_inItem003		:=	recWkMeisai.KIHON_TEISEI_USER_ID; 		-- 基本訂正ユーザ
		l_inItem.l_inItem004		:=	gLastShoninYmd; 							-- 最終承認日
		l_inItem.l_inItem005		:=	gLastShoninId; 							-- 最終承認ユーザ
		l_inItem.l_inItem006		:=	gShoninStat; 								-- 承認状態
		l_inItem.l_inItem007		:=	recWkMeisai.MGR_CD; 						-- 銘柄コード
		l_inItem.l_inItem008		:=	recWkMeisai.ISIN_CD; 						-- ＩＳＩＮコード
		l_inItem.l_inItem009		:=	recWkMeisai.MGR_RNM; 						-- 銘柄略称
		l_inItem.l_inItem010		:=	recWkMeisai.RITSUKE_WARIBIKI_KBN_NM; 		-- 利付割引区分名称
		l_inItem.l_inItem011		:=	recWkMeisai.RBR_TSUKA_NM; 				-- 利払通貨名称
		l_inItem.l_inItem012		:=	recWkMeisai.RBR_KAWASE_RATE; 				-- 利払為替レート
		l_inItem.l_inItem013		:=	recWkMeisai.NENRBR_CNT_NM; 				-- 年利払回数
		l_inItem.l_inItem014		:=	recWkMeisai.TOTAL_RBR_CNT; 				-- 総利払回数
		l_inItem.l_inItem015		:=	recWkMeisai.RBR_DD; 						-- 利払日付
		l_inItem.l_inItem016		:=	gWkStRbrKjt; 								-- 初回利払期日
		l_inItem.l_inItem017		:=	recWkMeisai.LAST_RBR_FLG_NM; 				-- 最終利払有無フラグ名称
		l_inItem.l_inItem018		:=	recWkMeisai.RIRITSU; 						-- 利率
		l_inItem.l_inItem019		:=	recWkMeisai.SHANAI_KOMOKU1;				-- 社内処理用項目１
		l_inItem.l_inItem020		:=	recWkMeisai.SHANAI_KOMOKU2;				-- 社内処理用項目２
		l_inItem.l_inItem021		:=	recWkMeisai.YOBI1;						-- 予備１
		l_inItem.l_inItem022		:=	recWkMeisai.DKJ_MGR_CD; 					-- 独自銘柄コード
		l_inItem.l_inItem023		:=	recWkMeisai.YOBI2;						-- 予備２
		l_inItem.l_inItem024		:=	recWkMeisai.TOKUREI_SHASAI_FLG_NM; 		-- 特例社債フラグ名称
		l_inItem.l_inItem025		:=	recWkMeisai.PARTMGR_KBN_NM; 				-- 分割銘柄区分名称
		l_inItem.l_inItem026		:=	gWkZndkKijunYmd; 							-- 残高基準日
		l_inItem.l_inItem027		:=	recWkGensaiRireki.MGR_ZNDK; 				-- 銘柄残高
		l_inItem.l_inItem028		:=	gMeimokuZndk; 							-- 名目残高
		l_inItem.l_inItem029		:=	gWkTeikyoEndYmd; 							-- 適用終了日
		l_inItem.l_inItem030		:=	recWkMeisai.NEWISIN_CD; 					-- 新ＩＳＩＮコード
		l_inItem.l_inItem031		:=	gWkDefaultYmd; 							-- デフォルト日
		l_inItem.l_inItem032		:=	recWkMeisai.DEFAULT_BIKO; 				-- デフォルト備考
		l_inItem.l_inItem033		:=	gItakuKaishaRnm; 							-- 委託会社略称
		l_inItem.l_inItem034		:=	REPORT_ID1;								-- 帳票ＩＤ
		l_inItem.l_inItem035		:=	'2';										-- ページNo
		l_inItem.l_inItem036		:=	'2';										-- ページ総数
		l_inItem.l_inItem037		:=	recWkMeisai.JTK_KBN; 						-- 受託区分
		l_inItem.l_inItem249		:=	'fkJtkSort1';							-- 帳票の出力順が、既存では帳票ＩＤの順になる。副受託の場合は銘柄情報のように、
																		-- 基本属性〜発行関連手数料計算書の順にならないため、ここでソート順を付け加えてます。

		CALL pkPrint.insertData(
			l_inKeyCd 			=>	l_inItakuKaishaCd  						-- 識別コード
			, l_inUserId		=>	l_inUserId 								-- ユーザＩＤ
			, l_inChohyoKbn		=>	l_inChohyoKbn 							-- 帳票区分
			, l_inSakuseiYmd	=>	l_inGyomuYmd 							-- 作成年月日
			, l_inChohyoId		=>	REPORT_ID2								-- 帳票ＩＤ
			, l_inSeqNo			=>	1										-- 連番
			, l_inHeaderFlg		=>	'1'										-- ヘッダフラグ
			,	l_inItem				=>	l_inItem
			, l_inKousinId		=>	l_inUserId  								-- 更新者ID
			, l_inSakuseiId		=>	l_inUserId  								-- 作成者ID
		);
	ELSE
		-- 対象データなし
		gRtnCd := RTN_NODATA;
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1
	THEN
		CALL pkLog.debug(l_inUserId, REPORT_ID1, 'ROWCOUNT:' || gSeqNo);
	END IF;
	IF DEBUG = 1
	THEN
		CALL pkLog.debug(l_inUserId, REPORT_ID1, 'spIp10901 END');
	END IF;
	-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', REPORT_ID1, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', REPORT_ID1, 'SQLERRM:' || SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
		--    RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip10901 ( l_inMgrCd CHAR, l_inItakuKaishaCd CHAR, l_inUserId CHAR, l_inChohyoKbn CHAR, l_inGyomuYmd CHAR, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;