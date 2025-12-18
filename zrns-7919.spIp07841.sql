

-- ==================================================================
-- SPIP07841
-- 銘柄情報変更警告リスト作成のため帳票ワークテーブルにINSERTする。
--
--
-- 作成：2005/04/26		I.Noshita
-- @version $Id: spIp07841.sql,v 1.20 2008/03/18 10:13:38 shimazoe Exp $
--
-- ==================================================================
CREATE OR REPLACE PROCEDURE spip07841 ( l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inUserId TEXT,		-- ユーザーID
 l_inChohyoKbn TEXT,		-- 帳票区分
 l_inGyomuYmd TEXT,		-- 業務日付
 l_outSqlCode OUT integer,		-- リターン値
 l_outSqlErrM OUT text	-- エラーコメント
 ) AS $body$
DECLARE

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
	REPORT_ID			CONSTANT text		:= 'IP030007841';	-- 帳票ID
    T_KK_PHASE            CONSTANT UPD_MGR_KHN.KK_PHASE%TYPE       := 'M2';            -- 機構フェーズ
    T_KK_STAT             CONSTANT UPD_MGR_KHN.KK_STAT%TYPE        := '04';            -- 機構ステータス
    T_MGR_KK_ERR_CD       CONSTANT UPD_MGR_KHN.MGR_KK_ERR_CD%TYPE  := '1';             -- 銘柄機構エラーコード
    T_WARN_MARK			CONSTANT text		:= '*';				-- 警告マーク
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	wk_gyomu_ymd				char(8)			:= NULL;		-- 業務日付
	wk_mgr_henko_warning_dd		numeric			:= 0;			-- 銘柄登録警告日付(日数)
	wk_mgr_henko_warning_ymd	char(8)			:= NULL;		-- 銘柄登録警告日付
	wk_ritsuke_waribiki_kbn		varchar(40)	:= NULL;		-- 利付割引区分名称
	wk_teiji_shokan_tsuti_kbn	varchar(40)	:= NULL;		-- 定時償還通知区分名称
	wk_rrt_etc_flg				varchar(40)	:= NULL;		-- その他海外参照フラグ名称
	wk_jiko_daiko_kbn			char(1)			:= NULL;		-- 自行代行区分
	wk_bank_rnm					varchar(20)	:= NULL;		-- 委託会社略称
	wk_warn_mark_ritsuke		char(1)			:= NULL;		-- 変動利付債の利率未申請警告マーク
	wk_warn_mark_shokan			char(1)			:= NULL;		-- 定時償還銘柄の償還額未申請警告マーク
	wk_warn_mark_etc			char(1)			:= NULL;		-- その他海外未申請警告マーク
	gRtnCd						integer :=	RTN_OK;			-- リターンコード
	gSeqNo						integer := 1;				-- シーケンス
    gGyomuYmd                   SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;  -- 業務日付
    gMgrHenkoWarningDd          numeric  := 0;                       -- 銘柄登録警告日付(日数)
    gkijunYmd 					char(8)			:= NULL;
    gSakuseiYmd             varchar(8);
    vDaikoKeyCd             TEXT;                                    -- Cache for vDaikoKeyCd
    vKaiinId                TEXT;                                    -- Cache for pkconstant.getKaiinId()
	-- 銘柄情報変更警告リスト取得用カーソル
    -- データ取得のＳＱＬは「sfIpaSime：締め処理用件数取得処理」と同じものを利用しているので、同期を取ってください。
    -- ただし、サマリを取得している都合上、
    -- 取得項目が変更になる場合を除き、同期を取るのはFROM句内のSELECT文のみとなります。
    --
--     * 以下の３つのSELECT文から構成されています。
--     *
--     * 1. 変動利付債の利率未申請分
--     * 2. 定時償還銘柄の償還額未申請分
--     * 3. その他海外未申請分
--     *
--     * ３つのSELECT文に共通してる処理は
--     * 1. 変更警告対象となるデータを取得
--     *    抽出期間は　銘柄変更締め警告出力日付 <= 業務日付 <= 支払日　の間です。
--     *    銘柄変更締め警告出力日付：支払日よりシステム情報マスタ.銘柄変更警告日付を引いた日付
--     *    例：
--     *      支払日が2005/11/11
--     *      システム情報マスタ.銘柄変更警告日付が5が設定されている。
--     *      業務日付が2005/11/06〜2005/11/11（すべて営業日として）の間が対象となります。
--     *
--     * 2. WHERE句のNOT IN ですでに期中銘柄情報で処理が完了している、委託会社、銘柄、支払期日のデータは除く
--     *    期中銘柄情報変更が承認済みかつ、機構フェーズ、ステータスが送信完了かつ、銘柄機構エラーコードが'1'でないものは処理完了とみなす
--     *
--     *
--     * 上記3つの事由のうち、どの事由で警告となっているかを"*"で示すために
--     * ビット演算（サマリ取得）を行います。
--     * 各事由のSELECT文で立てるビットは以下の通り。
--     * 1. 変動利付債の利率未申請分　　　：1 (001)
--     * 2. 定時償還銘柄の償還額未申請分　：2 (010)
--     * 3. その他海外未申請分　　　　　　：4 (100)
--     *
--     * ビット演算した結果により、以下の事由により警告が発生していることになります。
--     * 1 (001)：変動利付債の利率未申請分
--     * 2 (010)：定時償還銘柄の償還額未申請分
--     * 3 (011)：変動利付債の利率未申請分, 定時償還銘柄の償還額未申請分
--     * 4 (100)：その他海外未申請分
--     * 5 (101)：変動利付債の利率未申請分, その他海外未申請分
--     * 6 (110)：定時償還銘柄の償還額未申請分, その他海外未申請分
--     * 7 (111)：変動利付債の利率未申請分, 定時償還銘柄の償還額未申請分, その他海外未申請分
--     *
--     
	henko_cur CURSOR FOR
	SELECT
		ITAKU_KAISHA_CD,
		SUM(WARN_KIND) AS WARN_KIND,
		SHR_KJT,
		MGR_CD,
		ISIN_CD,
		MGR_RNM,
		RITSUKE_WARIBIKI_KBN,
		TEIJI_SHOKAN_TSUTI_KBN,
		KYUJITSU_ETC_FLG
	FROM (
	    -- 利払
	    SELECT
	    	1 AS WARN_KIND,
		VMG1.ITAKU_KAISHA_CD,
	        MG2.RBR_KJT AS SHR_KJT,
	        VMG1.MGR_CD,
	        VMG1.ISIN_CD,
	        VMG1.MGR_RNM,
	        VMG1.RITSUKE_WARIBIKI_KBN,
	        VMG1.TEIJI_SHOKAN_TSUTI_KBN,
	        VMG1.KYUJITSU_ETC_FLG
	    FROM
	        MGR_KIHON_VIEW VMG1,
	        MGR_RBRKIJ MG2
	    WHERE
	        VMG1.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=vDaikoKeyCd THEN  VMG1.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END
	    AND VMG1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
	    AND VMG1.MGR_CD = MG2.MGR_CD
	    AND VMG1.JTK_KBN != '2'             -- 副受託以外
	    AND VMG1.RITSUKE_WARIBIKI_KBN = 'V'
	    AND VMG1.SHORI_KBN = '1'
		AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')   -- ISINコード＝ブランクは対象外
	--    AND MG2.KK_KANYO_FLG = '1'
	    AND MG2.RBR_YMD <= gkijunYmd
	    AND gGyomuYmd <= MG2.RBR_YMD
	    AND MG2.KAIJI != '0'
	    AND (
	            MG2.RBR_KJT,
	            VMG1.MGR_CD
	    ) NOT IN (
	        SELECT  --+ HASH_AJ 
	            MG22.SHR_KJT,
	            MG22.MGR_CD
	        FROM
	            UPD_MGR_RBR MG22
	        WHERE
	            MG22.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=vDaikoKeyCd THEN  MG22.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
	        AND MG22.KK_PHASE = T_KK_PHASE
	        AND MG22.KK_STAT = T_KK_STAT
	        AND MG22.MGR_KK_ERR_CD != T_MGR_KK_ERR_CD
	        AND MG22.SHORI_KBN = '1'
	        
UNION

	        SELECT
	            MG2.RBR_KJT,
	            MG2.MGR_CD
	        FROM    MGR_RBRKIJ MG2,MGR_STS MG0,MGR_KIHON MG1
	        WHERE   MG2.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
	        AND     MG2.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
	        AND     MG2.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=vDaikoKeyCd THEN  MG2.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
	        AND     MG2.MGR_CD = MG0.MGR_CD
	        AND     MG2.MGR_CD = MG1.MGR_CD
	        AND     MG2.KAIJI	= 1
	        AND 	MG1.RITSUKE_WARIBIKI_KBN = 'V'
	        AND     MG1.TSUKARISHI_KNGK_FAST <> 0
			-- １回次目で銘柄登録時に機構登録済みでも、期中銘柄変更から変更されて、
			-- 期中銘柄変更のステータスが正常の登録済みではない場合は、警告の対象とする。
			AND (
						MG2.ITAKU_KAISHA_CD,
						MG2.MGR_CD
					)
					NOT IN (
						SELECT
							MG22.ITAKU_KAISHA_CD,
							MG22.MGR_CD
						FROM
							UPD_MGR_RBR MG22
						WHERE MG22.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
						AND   MG22.MGR_CD = MG2.MGR_CD
						AND   MG22.SHR_KJT = MG2.RBR_KJT
						AND (MG22.KK_STAT != T_KK_STAT OR MG22.MGR_KK_ERR_CD = T_MGR_KK_ERR_CD OR MG22.SHORI_KBN != '1') 
					) 
	    ) 
	    
UNION

	    -- 償還
	    SELECT
	    	2 AS WARN_KIND,
		VMG1.ITAKU_KAISHA_CD,
	        MG3.SHOKAN_KJT AS SHR_KJT,
	        VMG1.MGR_CD,
	        VMG1.ISIN_CD,
	        VMG1.MGR_RNM,
	        VMG1.RITSUKE_WARIBIKI_KBN,
	        VMG1.TEIJI_SHOKAN_TSUTI_KBN,
	        VMG1.KYUJITSU_ETC_FLG
	    FROM
	        MGR_KIHON_VIEW VMG1,
	        MGR_SHOKIJ MG3
	    WHERE
	        VMG1.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=vDaikoKeyCd THEN  VMG1.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
	    AND VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
	    AND VMG1.MGR_CD = MG3.MGR_CD
	    AND VMG1.JTK_KBN != '2'             -- 副受託以外
	    AND VMG1.TEIJI_SHOKAN_TSUTI_KBN = 'V'
	    AND VMG1.SHORI_KBN = '1'
		AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')   -- ISINコード＝ブランクは対象外
	    AND VMG1.KK_KANYO_FLG <> '2'
	    AND MG3.SHOKAN_KBN IN ('20','21')
	    AND MG3.SHOKAN_YMD <= gkijunYmd
	    AND gGyomuYmd <= MG3.SHOKAN_YMD
	    AND (
				MG3.SHOKAN_KJT,
				VMG1.MGR_CD,
				MG3.SHOKAN_KBN
		) NOT IN (
			SELECT  --+ HASH_AJ 
				MG23.SHR_KJT,
				MG23.MGR_CD,
				MG23.MGR_HENKO_KBN
			FROM
				UPD_MGR_SHN MG23
			WHERE
				MG23.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=vDaikoKeyCd THEN  MG23.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
			AND MG23.KK_PHASE = T_KK_PHASE
			AND MG23.KK_STAT = T_KK_STAT
			AND MG23.MGR_KK_ERR_CD != T_MGR_KK_ERR_CD
			AND MG23.SHORI_KBN = '1'
			AND	MG23.MGR_HENKO_KBN IN ('20','21') 
			
UNION

			SELECT
				MG3.SHOKAN_KJT,
				MG3.MGR_CD,
				MG3.SHOKAN_KBN
			FROM    MGR_SHOKIJ MG3,MGR_STS MG0,MGR_KIHON MG1
			WHERE   MG3.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
			AND     MG3.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
			AND     MG3.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=vDaikoKeyCd THEN  MG3.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
			AND     MG3.MGR_CD = MG0.MGR_CD
			AND     MG3.MGR_CD = MG1.MGR_CD
			AND     MG3.KAIJI = 1
			AND     MG1.TEIJI_SHOKAN_KNGK <> 0
			AND		MG3.SHOKAN_KBN IN ('20','21')
			-- １回次目で銘柄登録時に機構登録済みでも、期中銘柄変更から変更されて、
			-- 期中銘柄変更のステータスが正常の登録済みではない場合は、警告の対象とする。
			AND (
						MG3.ITAKU_KAISHA_CD,
						MG3.MGR_CD,
						MG3.SHOKAN_KJT,
						MG3.SHOKAN_KBN
					)
					NOT IN (
						SELECT
							MG23.ITAKU_KAISHA_CD,
							MG23.MGR_CD,
							MG23.SHR_KJT,
							MG23.MGR_HENKO_KBN
						FROM
							UPD_MGR_SHN MG23
						WHERE MG23.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
						AND   MG23.MGR_CD = MG3.MGR_CD
						AND   MG23.SHR_KJT = MG3.SHOKAN_KJT
						AND (MG23.KK_STAT != T_KK_STAT OR MG23.MGR_KK_ERR_CD = T_MGR_KK_ERR_CD OR MG23.SHORI_KBN != '1')
						AND	  MG23.MGR_HENKO_KBN = MG3.SHOKAN_KBN 
					) 
		) 
	    
UNION

	    -- 銘柄
	    SELECT
	    	4 AS WARN_KIND,
		VMG1.ITAKU_KAISHA_CD,
	        MG2.RBR_KJT AS SHR_KJT,
	        VMG1.MGR_CD,
	        VMG1.ISIN_CD,
	        VMG1.MGR_RNM,
	        VMG1.RITSUKE_WARIBIKI_KBN,
	        VMG1.TEIJI_SHOKAN_TSUTI_KBN,
	        VMG1.KYUJITSU_ETC_FLG
	    FROM
	        MGR_KIHON_VIEW VMG1,
	        MGR_RBRKIJ MG2
	    WHERE
	        VMG1.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=vDaikoKeyCd THEN  VMG1.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
	    AND VMG1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
	    AND VMG1.MGR_CD = MG2.MGR_CD
	    AND VMG1.JTK_KBN != '2'             -- 副受託以外
	    AND VMG1.KYUJITSU_ETC_FLG = 'Y'
	    AND VMG1.RITSUKE_WARIBIKI_KBN != 'Z'
	    AND VMG1.KK_KANYO_FLG <> '2'
	    AND VMG1.SHORI_KBN = '1'
		AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')   -- ISINコード＝ブランクは対象外
	    AND MG2.RBR_YMD <= gkijunYmd
	    AND gGyomuYmd <= MG2.RBR_YMD
	    AND (
	            MG2.RBR_KJT,
	            VMG1.MGR_CD
	    ) NOT IN (
	        SELECT
	            MG21.SHR_KJT,
	            MG21.MGR_CD
	        FROM
	            UPD_MGR_KHN MG21
	        WHERE
	            MG21.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=vDaikoKeyCd THEN  MG21.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
	        AND MG21.KK_PHASE = T_KK_PHASE
	        AND MG21.KK_STAT = T_KK_STAT
	        AND MG21.MGR_KK_ERR_CD != T_MGR_KK_ERR_CD
	        AND MG21.SHORI_KBN = '1'
	    ) 
	    
UNION

	    -- 銘柄(割引債)
	    SELECT
	    	4 AS WARN_KIND,
		VMG1.ITAKU_KAISHA_CD,
	        MG3.SHOKAN_KJT AS SHR_KJT,
	        VMG1.MGR_CD,
	        VMG1.ISIN_CD,
	        VMG1.MGR_RNM,
	        VMG1.RITSUKE_WARIBIKI_KBN,
	        VMG1.TEIJI_SHOKAN_TSUTI_KBN,
	        VMG1.KYUJITSU_ETC_FLG
	    FROM
	        MGR_KIHON_VIEW VMG1,
	        MGR_SHOKIJ MG3
	    WHERE
	        VMG1.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=vDaikoKeyCd THEN  VMG1.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
	    AND VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
	    AND VMG1.MGR_CD = MG3.MGR_CD
	    AND VMG1.JTK_KBN != '2'             -- 副受託以外
	    AND VMG1.KYUJITSU_ETC_FLG = 'Y'
	    AND VMG1.RITSUKE_WARIBIKI_KBN = 'Z'
	    AND VMG1.KK_KANYO_FLG <> '2'
	    AND VMG1.SHORI_KBN = '1'
		AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')   -- ISINコード＝ブランクは対象外
	    AND MG3.SHOKAN_YMD <= gkijunYmd
	    AND gGyomuYmd <= MG3.SHOKAN_YMD
	    AND (
	            MG3.SHOKAN_KJT,
	            VMG1.MGR_CD
	    ) NOT IN (
	        SELECT
	            MG21.SHR_KJT,
	            MG21.MGR_CD
	        FROM
	            UPD_MGR_KHN MG21
	        WHERE
	            MG21.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=vDaikoKeyCd THEN  MG21.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
	        AND MG21.KK_PHASE = T_KK_PHASE
	        AND MG21.KK_STAT = T_KK_STAT
	        AND MG21.MGR_KK_ERR_CD != T_MGR_KK_ERR_CD
	        AND MG21.SHORI_KBN = '1'
	    ) 
	) MGR_WARN_TBL 
	GROUP BY
		ITAKU_KAISHA_CD,
		SHR_KJT,
		MGR_CD,
		ISIN_CD,
		MGR_RNM,
		RITSUKE_WARIBIKI_KBN,
		TEIJI_SHOKAN_TSUTI_KBN,
		KYUJITSU_ETC_FLG
    ORDER BY ITAKU_KAISHA_CD,SHR_KJT,MGR_CD;
	-- レコード型変数
	henko_rectype		RECORD;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	-- Cache pkconstant functions to avoid schema context issues
	vDaikoKeyCd := vDaikoKeyCd;
	vKaiinId := pkconstant.getKaiinId();
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp07841 START');	END IF;
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
	-- 業務日付の取得
	wk_gyomu_ymd := pkDate.getGyomuYmd();
    gGyomuYmd := pkDate.getGyomuYmd();
	-- 銘柄変更警告日付の取得(日数)
	SELECT
		mgr_henko_warning_dd
	INTO STRICT
		gMgrHenkoWarningDd
	FROM
		ssystem_info
    WHERE
        kaiin_id = vKaiinId;
    -- 業務日付から銘柄変更警告日付の取得(日数)先の日付を取得（営業日ベース）
    gkijunYmd := pkDate.getPlusDateBusiness(gGyomuYmd, gMgrHenkoWarningDd::integer);
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
    -- 夜間バッチで作成する場合にはデータ基準日を出力する。
    IF l_inChohyoKbn = pkKakuninList.CHOHYO_KBN_BATCH() THEN
        gSakuseiYmd := l_inGyomuYmd;
    ELSE
        gSakuseiYmd := NULL;
    END IF;
	-- レコードがなくなるまでループ
	FOR henko_rectype IN henko_cur LOOP
		wk_ritsuke_waribiki_kbn		:= SPIP07841_getName('529', henko_rectype.ritsuke_waribiki_kbn);
		wk_teiji_shokan_tsuti_kbn	:= SPIP07841_getName('520', henko_rectype.teiji_shokan_tsuti_kbn);
		wk_rrt_etc_flg				:= SPIP07841_getName('504', henko_rectype.kyujitsu_etc_flg);
		-- ビットの論理積を取得し、その結果に応じて警告マークを編集します。
		--
		-- 変動利付債の利率未申請
		--
		-- 以下の場合が該当します。(2進数の1桁目が1)
		-- 1 (001)：変動利付債の利率未申請分
		-- 3 (011)：変動利付債の利率未申請分, 定時償還銘柄の償還額未申請分
		-- 5 (101)：変動利付債の利率未申請分, その他海外未申請分
		-- 7 (111)：変動利付債の利率未申請分, 定時償還銘柄の償還額未申請分, その他海外未申請分
		IF (1 & henko_rectype.warn_kind) = 0 THEN
			wk_warn_mark_ritsuke := NULL;
		ELSE
			wk_warn_mark_ritsuke := T_WARN_MARK;
		END IF;
		-- 定時償還銘柄の償還額未申請
		--
		-- 以下の場合が該当します。(2進数の2桁目が1)
		-- 2 (010)：定時償還銘柄の償還額未申請分
		-- 3 (011)：変動利付債の利率未申請分, 定時償還銘柄の償還額未申請分
		-- 6 (110)：定時償還銘柄の償還額未申請分, その他海外未申請分
		-- 7 (111)：変動利付債の利率未申請分, 定時償還銘柄の償還額未申請分, その他海外未申請分
		IF (2 & henko_rectype.warn_kind) = 0 THEN
			wk_warn_mark_shokan := NULL;
		ELSE
			wk_warn_mark_shokan := T_WARN_MARK;
		END IF;
		-- その他海外未申請
		--
		-- 以下の場合が該当します。(2進数の2桁目が3)
		-- 4 (100)：その他海外未申請分
		-- 5 (101)：変動利付債の利率未申請分, その他海外未申請分
		-- 6 (110)：定時償還銘柄の償還額未申請分, その他海外未申請分
		-- 7 (111)：変動利付債の利率未申請分, 定時償還銘柄の償還額未申請分, その他海外未申請分
		IF (4 & henko_rectype.warn_kind) = 0 THEN
			wk_warn_mark_etc := NULL;
		ELSE
			wk_warn_mark_etc := T_WARN_MARK;
		END IF;
		-- 自行情報の取得
		CALL SPIP07841_getJikouInfo(henko_rectype.itaku_kaisha_cd, wk_jiko_daiko_kbn, wk_bank_rnm);
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := wk_bank_rnm;	-- 委託会社略称
		v_item.l_inItem002 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem003 := l_inGyomuYmd;	-- 業務日付
		v_item.l_inItem004 := henko_rectype.shr_kjt;	-- 利払期日
		v_item.l_inItem005 := henko_rectype.mgr_cd;	-- 銘柄コード
		v_item.l_inItem006 := henko_rectype.isin_cd;	-- ISINコード
		v_item.l_inItem007 := henko_rectype.mgr_rnm;	-- 銘柄略称
		v_item.l_inItem008 := henko_rectype.ritsuke_waribiki_kbn;	-- 利付割引区分
		v_item.l_inItem009 := wk_ritsuke_waribiki_kbn;	-- 利付割引区分名称
		v_item.l_inItem010 := henko_rectype.teiji_shokan_tsuti_kbn;	-- 定時償還通知区分
		v_item.l_inItem011 := wk_teiji_shokan_tsuti_kbn;	-- 定時償還通知区分名称
		v_item.l_inItem012 := henko_rectype.kyujitsu_etc_flg;	-- その他海外参照フラグ
		v_item.l_inItem013 := wk_rrt_etc_flg;	-- その他海外参照フラグ名称
		v_item.l_inItem014 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem016 := gSakuseiYmd;	-- データ基準日
		v_item.l_inItem017 := wk_warn_mark_ritsuke;	-- 変動利付債の利率未申請警告マーク
		v_item.l_inItem018 := wk_warn_mark_shokan;	-- 定時償還銘柄の償還額未申請警告マーク
		v_item.l_inItem019 := wk_warn_mark_etc;	-- その他海外未申請警告マーク
		
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
		gSeqNo := gSeqNo + 1;
	END LOOP;
	IF gSeqNo = 1 THEN
		-- 対象データなし
		gRtnCd := RTN_NODATA;
		-- 自行情報の取得
		CALL SPIP07841_getJikouInfo(l_inItakuKaishaCd, wk_jiko_daiko_kbn, wk_bank_rnm);
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := wk_bank_rnm;	-- 委託会社略称
		v_item.l_inItem002 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem003 := l_inGyomuYmd;	-- 業務日付
		v_item.l_inItem014 := REPORT_ID;
		v_item.l_inItem015 := '対象データなし';
		
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
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp07841 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip07841 ( l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spip07841_getjikouinfo ( 
	l_inItakuKaishaCd TEXT,
	INOUT wk_jiko_daiko_kbn char(1),
	INOUT wk_bank_rnm varchar(20)
) AS $body$
BEGIN
	SELECT
		jiko_daiko_kbn,				-- 自行代行区分
		bank_rnm 					-- 委託会社略称
	INTO STRICT
		wk_jiko_daiko_kbn,
		wk_bank_rnm
	FROM
		VJIKO_ITAKU
	WHERE
		kaiin_id = l_inItakuKaishaCd;
	-- 自行代行区分が'2'以外のときに委託会社略称を表示する
	IF wk_jiko_daiko_kbn != '2' THEN
		wk_bank_rnm := NULL;
	END IF;
EXCEPTION
	WHEN no_data_found THEN
		wk_bank_rnm := NULL;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip07841_getjikouinfo ( l_inItakuKaishaCd TEXT, INOUT wk_jiko_daiko_kbn char, INOUT wk_bank_rnm varchar ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spip07841_getname ( l_code_shubetsu TEXT, l_cole_value TEXT ) RETURNS varchar AS $body$
DECLARE

	wk_name		varchar(40) := null;
	wk_count	numeric := 0;

BEGIN
	SELECT
		count(ctid)
	INTO STRICT
		wk_count
	FROM
		SCODE
	WHERE
		code_shubetsu = l_code_shubetsu AND
		code_value = l_cole_value;
	IF wk_count > 0 THEN
		SELECT
			code_nm
		INTO STRICT
			wk_name
		FROM
			SCODE
		WHERE
			code_shubetsu = l_code_shubetsu AND
			code_value = l_cole_value;
	END IF;
	RETURN wk_name;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spip07841_getname ( l_code_shubetsu TEXT, l_cole_value TEXT ) FROM PUBLIC;