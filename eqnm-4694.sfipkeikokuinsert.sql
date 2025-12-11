




CREATE OR REPLACE FUNCTION sfipkeikokuinsert ( l_inItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE, -- 委託会社コード
 l_inWarnInfoKbn text,                           -- 警告連絡区分
 l_inWarnInfoId WARNING_WK.WARN_INFO_ID%TYPE,       -- 警告連絡ID
 l_inIsinCd WARNING_WK.ISIN_CD%TYPE,            -- ISINコード
 l_inKozaTenCd WARNING_WK.KOZA_TEN_CD%TYPE,        -- 口座店コード
 l_inKozaTenCifCd WARNING_WK.KOZA_TEN_CIFCD%TYPE,	  -- 口座店CIFコード
 l_inKkmemberCd WARNING_WK.KKMEMBER_CD%TYPE,	  -- 機構加入社コード
 l_inMgrRnm WARNING_WK.MGR_RNM%TYPE,            -- 銘柄略称
 l_inTaishoKomoku WARNING_WK.TAISHO_KOMOKU%TYPE,      -- 対象項目
 l_inTaishoYmd WARNING_WK.TAISHO_YMD%TYPE,         -- 対象期日
 l_inYobi1 text,                           -- 予備１
 l_inYobi2 text,                           -- 予備２
 l_inYobi3 text,                           -- 予備３
 l_inYobi4 text,                           -- 予備４
 l_inJikodaikoKbn TEXT                                 -- 自行代行区分
 ) RETURNS numeric AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2016
-- * 会社名: JIP
-- *
-- * 警告ワークに対象データを作成する。（バッチ用）
-- * １．各警告・連絡の登録データを定数に設定
-- * ２．各警告・連絡のデータを警告ワークに登録
-- *
-- * @author Y.Yamada
-- * @version $Id: SFIPKEIKOKUINSERT.sql,v 1.0 2017/02/10 10:19:30 Y.Yamada Exp $
-- *
-- * @param l_inItakuKaishaCd 委託会社コード
-- * @param l_inWarnInfoKbn 警告連絡区分
-- * @param l_inWarnInfoId 警告連絡ID
-- * @param l_inIsinCd ISINコード
-- * @param l_inKozaTenCd 口座店コード
-- * @param l_inKozaTenCifCd 口座店CIFコード
-- * @param l_inKkmemberCd 機構加入社コード
-- * @param l_inMgrRnm 銘柄略称
-- * @param l_inTaishoKomoku 対象項目
-- * @param l_inTaishoYmd 対象期日
-- * @param l_inYobi1 予備１
-- * @param l_inYobi2 予備２
-- * @param l_inYobi3 予備３
-- * @param l_inYobi4 予備４
-- * @param l_inJikodaikoKbn 自行代行区分
-- * @return INTEGER 0:正常
-- *                99:異常、それ以外：エラー
-- 
--==============================================================================
--                定数定義                                                      
--==============================================================================
	C_REPORT_ID CONSTANT varchar(50) := 'IP931511711'; -- レポートID
--==============================================================================
--                変数定義                                                      
--==============================================================================
	gMessage1   varchar(100) := NULL;  -- メッセージ１
	gMessage2   varchar(100) := NULL;  -- メッセージ２
	gBiko1      varchar(100) := ' ';  -- 備考１
	gBiko2      varchar(100) := ' ';  -- 備考２
	gBiko3      varchar(100) := ' ';  -- 備考３
	gSortKey    varchar(50) := NULL;  -- ソートキー
	gGyomuYmd   SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE; -- 業務日付
	gBikoWk     varchar(100) := ' ';  -- 備考ワーク
	gareacd     MCALENDAR_MAKE_INFO.AREA_CD%TYPE; -- 地域コード
--==============================================================================
--                カーソル定義                                                  
--==============================================================================
	curMeisai CURSOR FOR
	SELECT
		BT24.MSG_NM_JIKO1,     -- メッセージ（自行）１
		BT24.MSG_NM_JIKO2,     -- メッセージ（自行）２
		BT24.MSG_NM_DAIKO1,    -- メッセージ（事務代行）１
		BT24.MSG_NM_DAIKO2,    -- メッセージ（事務代行）２
		BT24.MSG_BIKO_JIKO1,   -- 備考（自行）１
		BT24.MSG_BIKO_JIKO2,   -- 備考（自行）２
		BT24.MSG_BIKO_DAIKO1,  -- 備考（事務代行）１
		BT24.MSG_BIKO_DAIKO2,  -- 備考（事務代行）２
		BT24.SORT_KEY_JIKO,    -- ソートキー（自行）
		BT24.SORT_KEY_DAIKO     -- ソートキー（事務代行）
	FROM
		KEIKOKU_MSG_KANRI BT24
	WHERE
		BT24.WARN_INFO_ID = l_inWarnInfoId;
	curMeisaicalendar CURSOR FOR
	SELECT MC1.AREA_NM
		FROM MCALENDAR_MAKE_INFO MC1,
		(SELECT MC2.AREA_CD, MAX(MC2.SAKUSEI_TAISHO_YYYY) AS SAKUSEI_TAISHO_YYYY FROM mcalendar_make_info MC2 GROUP BY MC2.AREA_CD) MC3
		WHERE MC1.AREA_CD = MC3.AREA_CD
		AND MC1.SAKUSEI_TAISHO_YYYY = MC3.SAKUSEI_TAISHO_YYYY
		AND MC1.AREA_CD = gareacd;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	--業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
	FOR recMeisai IN curMeisai LOOP
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPI102の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPI102' THEN
			gMessage1 := recMeisai.MSG_NM_JIKO1;
			gMessage2 := '振込日：' || SUBSTR(l_inYobi3,1,4) || '.' || SUBSTR(l_inYobi3,5,2) || '.' || SUBSTR(l_inYobi3,7,2);
			gBiko1    := recMeisai.MSG_BIKO_JIKO1;
			gBiko2    := 'データ件数：' || l_inYobi1 || '件' || '　合計金額：' || l_inYobi2 || '円';
			gSortKey  := recMeisai.SORT_KEY_JIKO;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW001の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW001' THEN
			--==============================================================================
			-- 引数．自行代行区分 ＝ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := recMeisai.MSG_NM_JIKO2;
				gBiko1    := recMeisai.MSG_BIKO_JIKO1;
				gBiko2    := recMeisai.MSG_BIKO_JIKO2;
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := recMeisai.MSG_NM_DAIKO2;
				gBiko1    := recMeisai.MSG_BIKO_DAIKO1;
				gBiko2    := recMeisai.MSG_BIKO_DAIKO2;
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPI001の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPI001' THEN
			--==============================================================================
			-- 引数．自行代行区分 ＝ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := recMeisai.MSG_NM_JIKO2;
				gBiko1    := l_inYobi2 || recMeisai.MSG_BIKO_JIKO1;
				gBiko2    := recMeisai.MSG_BIKO_JIKO2 || l_inYobi1;
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := recMeisai.MSG_NM_DAIKO2;
				gBiko1    := l_inYobi2 || recMeisai.MSG_BIKO_DAIKO1;
				gBiko2    := recMeisai.MSG_BIKO_DAIKO2 || l_inYobi1;
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW002の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW002' THEN
			--==============================================================================
			-- 引数．自行代行区分 ＝ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := recMeisai.MSG_NM_JIKO2;
				gBiko1    := recMeisai.MSG_BIKO_JIKO1;
				gBiko2    := recMeisai.MSG_BIKO_JIKO2;
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := recMeisai.MSG_NM_DAIKO2;
				gBiko1    := recMeisai.MSG_BIKO_DAIKO1;
				gBiko2    := recMeisai.MSG_BIKO_DAIKO2;
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW003の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW003' THEN
			--==============================================================================
			-- 引数．自行代行区分 ＝ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := recMeisai.MSG_NM_JIKO2;
				gBiko1    := recMeisai.MSG_BIKO_JIKO1;
				gBiko2    := recMeisai.MSG_BIKO_JIKO2;
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := recMeisai.MSG_NM_DAIKO2;
				gBiko1    := recMeisai.MSG_BIKO_DAIKO1;
				gBiko2    := recMeisai.MSG_BIKO_DAIKO2;
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW004の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW004' THEN
			--==============================================================================
			-- 引数．自行代行区分 ＝ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := recMeisai.MSG_NM_JIKO2;
				gBiko1    := recMeisai.MSG_BIKO_JIKO1;
				gBiko2    := recMeisai.MSG_BIKO_JIKO2;
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := recMeisai.MSG_NM_DAIKO2;
				gBiko1    := recMeisai.MSG_BIKO_DAIKO1;
				gBiko2    := recMeisai.MSG_BIKO_DAIKO2;
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW013の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW013' THEN
			--==============================================================================
			-- 引数．自行代行区分 ＝ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := recMeisai.MSG_NM_JIKO2;
				gBiko1    := recMeisai.MSG_BIKO_JIKO1;
				gBiko2    := recMeisai.MSG_BIKO_JIKO2;
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := recMeisai.MSG_NM_DAIKO2;
				gBiko1    := recMeisai.MSG_BIKO_DAIKO1;
				gBiko2    := recMeisai.MSG_BIKO_DAIKO2;
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW014の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW014' THEN
			--==============================================================================
			-- 引数．自行代行区分 ＝ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := recMeisai.MSG_NM_JIKO2;
				gBiko1    := recMeisai.MSG_BIKO_JIKO1;
				gBiko2    := recMeisai.MSG_BIKO_JIKO2;
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := recMeisai.MSG_NM_DAIKO2;
				gBiko1    := recMeisai.MSG_BIKO_DAIKO1;
				gBiko2    := recMeisai.MSG_BIKO_DAIKO2;
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPI103の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPI103' THEN
			gMessage1 := recMeisai.MSG_NM_JIKO1;
			gMessage2 := recMeisai.MSG_NM_JIKO2;
			gBiko1    := recMeisai.MSG_BIKO_JIKO1 || SUBSTR(l_inYobi1,1,4) || '.' || SUBSTR(l_inYobi1,5,2) || '.' || SUBSTR(l_inYobi1,7,2);
			gBiko2    := recMeisai.MSG_BIKO_JIKO2 || l_inYobi2 || '件';
			gSortKey  := recMeisai.SORT_KEY_JIKO;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW102の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW102' THEN
			gMessage1 := recMeisai.MSG_NM_JIKO1;
			gMessage2 := recMeisai.MSG_NM_JIKO2;
			gBiko1    := recMeisai.MSG_BIKO_JIKO1;
			gBiko2    := recMeisai.MSG_BIKO_JIKO2;
			gSortKey  := recMeisai.SORT_KEY_JIKO;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPI201の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPI201' THEN
			gMessage1 := recMeisai.MSG_NM_DAIKO1;
			gMessage2 := recMeisai.MSG_NM_DAIKO2;
			gBiko1    := recMeisai.MSG_BIKO_DAIKO1;
			gBiko2    := recMeisai.MSG_BIKO_DAIKO2;
			gSortKey  := recMeisai.SORT_KEY_DAIKO;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPI202の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPI202' THEN
			gMessage1 := recMeisai.MSG_NM_DAIKO1;
			gMessage2 := recMeisai.MSG_NM_DAIKO2;
			gBiko1    := recMeisai.MSG_BIKO_DAIKO1;
			gBiko2    := recMeisai.MSG_BIKO_DAIKO2;
			gSortKey  := recMeisai.SORT_KEY_DAIKO;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPI204の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPI204' THEN
			gMessage1 := recMeisai.MSG_NM_DAIKO1;
			gMessage2 := recMeisai.MSG_NM_DAIKO2;
			gBiko1    := recMeisai.MSG_BIKO_DAIKO1;
			gBiko2    := recMeisai.MSG_BIKO_DAIKO2;
			gSortKey  := recMeisai.SORT_KEY_DAIKO;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW018	の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW018' THEN
			--==============================================================================
			-- 引数．自行代行区分 ＝ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := recMeisai.MSG_NM_JIKO2;
				gBiko1    := recMeisai.MSG_BIKO_JIKO1;
				gBiko2    := recMeisai.MSG_BIKO_JIKO2;
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := recMeisai.MSG_NM_DAIKO2;
				gBiko1    := recMeisai.MSG_BIKO_DAIKO1;
				gBiko2    := recMeisai.MSG_BIKO_DAIKO2;
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW019	の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW019' THEN
			--==============================================================================
			-- 引数．自行代行区分 ＝ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := recMeisai.MSG_NM_JIKO2;
				gBiko1    := l_inYobi1;
				gBiko2    := l_inYobi2;
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := recMeisai.MSG_NM_DAIKO2;
				gBiko1    := l_inYobi1;
				gBiko2    := l_inYobi2;
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW020	の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW020' THEN
			--==============================================================================
			-- 引数．自行代行区分 ＝ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := recMeisai.MSG_NM_JIKO2;
				gBiko1    := l_inYobi1;
				gBiko2    := l_inYobi2;
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := recMeisai.MSG_NM_DAIKO2;
				gBiko1    := l_inYobi1;
				gBiko2    := l_inYobi2;
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW009	の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW009' THEN
			--==============================================================================
			-- 引数．自行代行区分 ＝ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := recMeisai.MSG_NM_JIKO2;
				gBiko1    := recMeisai.MSG_BIKO_JIKO1;
				gBiko2    := recMeisai.MSG_BIKO_JIKO2;
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := recMeisai.MSG_NM_DAIKO2;
				gBiko1    := recMeisai.MSG_BIKO_DAIKO1;
				gBiko2    := recMeisai.MSG_BIKO_DAIKO2;
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW011の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW011' THEN
			--==============================================================================
			-- 引数．自行代行区分 ＝ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := recMeisai.MSG_NM_JIKO2;
				gBiko1    := recMeisai.MSG_BIKO_JIKO1;
				gBiko2    := recMeisai.MSG_BIKO_JIKO2;
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := recMeisai.MSG_NM_DAIKO2;
				gBiko1    := recMeisai.MSG_BIKO_DAIKO1;
				gBiko2    := recMeisai.MSG_BIKO_DAIKO2;
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW008の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW008' THEN
			--==============================================================================
			-- 引数．自行代行区分 ＝ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := recMeisai.MSG_NM_JIKO2;
				gBiko1    := recMeisai.MSG_BIKO_JIKO1;
				gBiko2    := recMeisai.MSG_BIKO_JIKO2;
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := recMeisai.MSG_NM_DAIKO2;
				gBiko1    := recMeisai.MSG_BIKO_DAIKO1;
				gBiko2    := recMeisai.MSG_BIKO_DAIKO2;
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW010の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW010' THEN
			--==============================================================================
			-- 引数．自行代行区分 ＝ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := recMeisai.MSG_NM_JIKO2;
				gBiko1    := recMeisai.MSG_BIKO_JIKO1;
				gBiko2    := recMeisai.MSG_BIKO_JIKO2;
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := recMeisai.MSG_NM_DAIKO2;
				gBiko1    := recMeisai.MSG_BIKO_DAIKO1;
				gBiko2    := recMeisai.MSG_BIKO_DAIKO2;
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPI203の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPI203' THEN
			gMessage1 := recMeisai.MSG_NM_DAIKO1;
			gMessage2 := recMeisai.MSG_NM_DAIKO2;
			gBiko1    := recMeisai.MSG_BIKO_DAIKO1;
			gBiko2    := recMeisai.MSG_BIKO_DAIKO2;
			gSortKey  := recMeisai.SORT_KEY_DAIKO;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW012の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW012' THEN
			--==============================================================================
			-- 引数．自行代行区分 ＝ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := recMeisai.MSG_NM_JIKO2;
				gBiko1    := l_inYobi1 || recMeisai.MSG_BIKO_JIKO1;
				gBiko2    := recMeisai.MSG_BIKO_JIKO2;
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := recMeisai.MSG_NM_DAIKO2;
				gBiko1    := l_inYobi1 || recMeisai.MSG_BIKO_DAIKO1;
				gBiko2    := recMeisai.MSG_BIKO_DAIKO2;
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPI004の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPI004' THEN
			--==============================================================================
			-- 引数．自行代行区分 ＝ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := l_inYobi1;
				gBiko1    := l_inYobi2;
				gBiko2    := l_inYobi3;
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := l_inYobi1;
				gBiko1    := l_inYobi2;
				gBiko2    := l_inYobi3;
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW201の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW201' THEN
			gMessage1 := recMeisai.MSG_NM_DAIKO1;
			gMessage2 := recMeisai.MSG_NM_DAIKO2;
			gBiko1    := l_inYobi1 || recMeisai.MSG_BIKO_DAIKO1;
			gBiko2    := recMeisai.MSG_BIKO_DAIKO2;
			gSortKey  := recMeisai.SORT_KEY_DAIKO;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW006の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW006' THEN
			--==============================================================================
			-- 引数．自行代行区分 ＝ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := recMeisai.MSG_NM_JIKO2;
				gBiko1    := recMeisai.MSG_BIKO_JIKO1;
				gBiko2    := recMeisai.MSG_BIKO_JIKO2;
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := recMeisai.MSG_NM_DAIKO2;
				gBiko1    := recMeisai.MSG_BIKO_DAIKO1;
				gBiko2    := recMeisai.MSG_BIKO_DAIKO2;
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW007の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW007' THEN
			--==============================================================================
			-- 引数．自行代行区分 ＝ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := recMeisai.MSG_NM_JIKO2;
				gBiko1    := recMeisai.MSG_BIKO_JIKO1;
				gBiko2    := recMeisai.MSG_BIKO_JIKO2;
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := recMeisai.MSG_NM_DAIKO2;
				gBiko1    := recMeisai.MSG_BIKO_DAIKO1;
				gBiko2    := recMeisai.MSG_BIKO_DAIKO2;
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPI205の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPI205' THEN
			gMessage1 := recMeisai.MSG_NM_DAIKO1;
			gMessage2 := recMeisai.MSG_NM_DAIKO2;
			gBiko1    := recMeisai.MSG_BIKO_DAIKO1;
			gBiko2    := recMeisai.MSG_BIKO_DAIKO2;
			gSortKey  := recMeisai.SORT_KEY_DAIKO;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPI002の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPI002' THEN
			--==============================================================================
			-- 引数．自行代行区分 ＝ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := recMeisai.MSG_NM_JIKO2;
				gBiko1    := l_inYobi1 || recMeisai.MSG_BIKO_JIKO1;
				gBiko2    := recMeisai.MSG_BIKO_JIKO2;
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := recMeisai.MSG_NM_DAIKO2;
				gBiko1    := l_inYobi1 || recMeisai.MSG_BIKO_JIKO1;
				gBiko2    := recMeisai.MSG_BIKO_JIKO2;
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPI003の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPI003' THEN
			--==============================================================================
			-- 引数．自行代行区分 ＝ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := recMeisai.MSG_NM_JIKO2;
				gBiko1    := recMeisai.MSG_BIKO_JIKO1;
				gBiko2    := recMeisai.MSG_BIKO_JIKO2;
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := recMeisai.MSG_NM_DAIKO2;
				gBiko1    := recMeisai.MSG_BIKO_DAIKO1;
				gBiko2    := recMeisai.MSG_BIKO_DAIKO2;
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPI104の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPI104' THEN
			gMessage1 := recMeisai.MSG_NM_JIKO1;
			gMessage2 := recMeisai.MSG_NM_JIKO2;
			gBiko1    := coalesce(SUBSTR(recMeisai.MSG_BIKO_JIKO1 || '計' || l_inYobi1 || '銘柄。' || l_inYobi2 || l_inYobi3 || l_inYobi4,1,25),' ');
			gBiko2    := coalesce(SUBSTR(recMeisai.MSG_BIKO_JIKO1 || '計' || l_inYobi1 || '銘柄。' || l_inYobi2 || l_inYobi3 || l_inYobi4,26,25),' ');
			gBiko3    := coalesce(SUBSTR(recMeisai.MSG_BIKO_JIKO1 || '計' || l_inYobi1 || '銘柄。' || l_inYobi2 || l_inYobi3 || l_inYobi4,51,25), ' ');
			gSortKey  := recMeisai.SORT_KEY_JIKO;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPI101の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPI101' THEN
			gMessage1 := recMeisai.MSG_NM_JIKO1;
			gMessage2 := recMeisai.MSG_NM_JIKO2;
			gBiko1    := l_inYobi1;
			gBiko2    := l_inYobi2;
			gSortKey  := recMeisai.SORT_KEY_JIKO;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW101の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW101' THEN
			gMessage1 := recMeisai.MSG_NM_JIKO1;
			gMessage2 := recMeisai.MSG_NM_JIKO2;
			gBiko1    := recMeisai.MSG_BIKO_JIKO1;
			gBiko2    := recMeisai.MSG_BIKO_JIKO2;
			gSortKey  := recMeisai.SORT_KEY_JIKO;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW021の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW021' THEN
			--==============================================================================
			-- 引数．自行代行区分 ＝ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := recMeisai.MSG_NM_JIKO2;
				gBiko1    := recMeisai.MSG_BIKO_JIKO1;
				gBiko2    := l_inYobi1 || recMeisai.MSG_BIKO_JIKO2;
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := recMeisai.MSG_NM_DAIKO2;
				gBiko1    := recMeisai.MSG_BIKO_DAIKO1;
				gBiko2    := l_inYobi1 || recMeisai.MSG_BIKO_DAIKO2;
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW015の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW015' THEN
			--==============================================================================
			-- 引数．自行代行区分 ＝ '1'の場合                                              
			--==============================================================================
			IF (trim(both l_inYobi1) IS NOT NULL AND (trim(both l_inYobi1))::text <> '') THEN
				gareacd := l_inYobi1;
				FOR recMeisaicalendar IN curMeisaicalendar LOOP
					gBikoWk := recMeisaicalendar.AREA_NM;
				END LOOP;
			END IF;
			IF (trim(both l_inYobi2) IS NOT NULL AND (trim(both l_inYobi2))::text <> '') THEN
				gareacd := l_inYobi2;
				FOR recMeisaicalendar IN curMeisaicalendar LOOP
					gBikoWk := gBikoWk || '、' || recMeisaicalendar.AREA_NM;
				END LOOP;
			END IF;
			IF (trim(both l_inYobi3) IS NOT NULL AND (trim(both l_inYobi3))::text <> '') THEN
				gareacd := l_inYobi3;
				FOR recMeisaicalendar IN curMeisaicalendar LOOP
					gBikoWk := gBikoWk || '、' || recMeisaicalendar.AREA_NM;
				END LOOP;
			END IF;
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := recMeisai.MSG_NM_JIKO2 || SUBSTR(l_inYobi4,1,4) || '.' || SUBSTR(l_inYobi4,5,2) || '.' || SUBSTR(l_inYobi4,7,8);
				gBiko1    := recMeisai.MSG_BIKO_JIKO1;
				gBikoWk := recMeisai.MSG_BIKO_JIKO2 || gBikoWk;
				IF LENGTH(gBikoWk) <= 25 THEN
					gBiko2    := gBikoWk;
				ELSE
					gBiko2    := SUBSTR(gBikoWk,1,25);
					gBiko3    := SUBSTR(gBikoWk,26);
				END IF;
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := recMeisai.MSG_NM_DAIKO2 || SUBSTR(l_inYobi4,1,4) || '.' || SUBSTR(l_inYobi4,5,2) || '.' || SUBSTR(l_inYobi4,7,8);
				gBiko1    := recMeisai.MSG_BIKO_DAIKO1;
				gBikoWk := recMeisai.MSG_BIKO_DAIKO2 || gBikoWk;
				IF LENGTH(gBikoWk) <= 25 THEN
					gBiko2    := gBikoWk;
				ELSE
					gBiko2    := SUBSTR(gBikoWk,1,25);
					gBiko3    := SUBSTR(gBikoWk,26);
				END IF;
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW016の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW016' THEN
			IF (trim(both l_inYobi1) IS NOT NULL AND (trim(both l_inYobi1))::text <> '') THEN
				gareacd := l_inYobi1;
				FOR recMeisaicalendar IN curMeisaicalendar LOOP
					gBikoWk := recMeisaicalendar.AREA_NM;
				END LOOP;
			END IF;
			IF (trim(both l_inYobi2) IS NOT NULL AND (trim(both l_inYobi2))::text <> '') THEN
				gareacd := l_inYobi2;
				FOR recMeisaicalendar IN curMeisaicalendar LOOP
					gBikoWk := gBikoWk || '、' || recMeisaicalendar.AREA_NM;
				END LOOP;
			END IF;
			IF (trim(both l_inYobi3) IS NOT NULL AND (trim(both l_inYobi3))::text <> '') THEN
				gareacd := l_inYobi3;
				FOR recMeisaicalendar IN curMeisaicalendar LOOP
					gBikoWk := gBikoWk || '、' || recMeisaicalendar.AREA_NM;
				END LOOP;
			END IF;
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := recMeisai.MSG_NM_JIKO2;
				gBiko1    := recMeisai.MSG_BIKO_JIKO1;
				gBikoWk := recMeisai.MSG_BIKO_JIKO2 || gBikoWk;
				IF LENGTH(gBikoWk) <= 25 THEN
					gBiko2    := gBikoWk;
				ELSE
					gBiko2    := SUBSTR(gBikoWk,1,25);
					gBiko3    := SUBSTR(gBikoWk,26);
				END IF;
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := recMeisai.MSG_NM_DAIKO2;
				gBiko1    := recMeisai.MSG_BIKO_DAIKO1;
				gBikoWk := recMeisai.MSG_BIKO_DAIKO2 || gBikoWk;
				IF LENGTH(gBikoWk) <= 25 THEN
					gBiko2    := gBikoWk;
				ELSE
					gBiko2    := SUBSTR(gBikoWk,1,25);
					gBiko3    := SUBSTR(gBikoWk,26);
				END IF;
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW103の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW103' THEN
			gMessage1 := recMeisai.MSG_NM_JIKO1;
			gMessage2 := recMeisai.MSG_NM_JIKO2;
			gBiko1    := recMeisai.MSG_BIKO_JIKO1;
			gBiko2    := recMeisai.MSG_BIKO_JIKO2;
			gSortKey  := recMeisai.SORT_KEY_JIKO;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW104の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW104' THEN
			gMessage1 := recMeisai.MSG_NM_JIKO1;
			gMessage2 := recMeisai.MSG_NM_JIKO2;
			gBiko1    := recMeisai.MSG_BIKO_JIKO1;
			gBiko2    := recMeisai.MSG_BIKO_JIKO2;
			gSortKey  := recMeisai.SORT_KEY_JIKO;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW005の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW005' THEN
			--==============================================================================
			-- 引数．自行代行区分 ＝ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := recMeisai.MSG_NM_JIKO2;
				gBiko1    := recMeisai.MSG_BIKO_JIKO1;
				gBiko2    := recMeisai.MSG_BIKO_JIKO2 || l_inYobi1 || '円（税込）';
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := recMeisai.MSG_NM_DAIKO2;
				gBiko1    := recMeisai.MSG_BIKO_DAIKO1;
				gBiko2    := recMeisai.MSG_BIKO_DAIKO2 || l_inYobi1 || '円（税込）';
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 引数．警告連絡ID　＝　IPW017の場合                                           
		--==============================================================================
		IF l_inWarnInfoId = 'IPW017' THEN
			--==============================================================================
			-- 引数．自行代行区分 ＝ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn = '1' THEN
				gMessage1 := recMeisai.MSG_NM_JIKO1;
				gMessage2 := recMeisai.MSG_NM_JIKO2;
				gBiko1    := recMeisai.MSG_BIKO_JIKO1;
				gBiko2    := SUBSTR(recMeisai.MSG_BIKO_JIKO2,1,25);
				gBiko3    := SUBSTR(recMeisai.MSG_BIKO_JIKO2,26);
				gSortKey  := recMeisai.SORT_KEY_JIKO;
			END IF;
			--==============================================================================
			-- 引数．自行代行区分 ≠ '1'の場合                                              
			--==============================================================================
			IF l_inJikodaikoKbn != '1' THEN
				gMessage1 := recMeisai.MSG_NM_DAIKO1;
				gMessage2 := recMeisai.MSG_NM_DAIKO2;
				gBiko1    := recMeisai.MSG_BIKO_DAIKO1;
				gBiko2    := SUBSTR(recMeisai.MSG_BIKO_DAIKO2,1,25);
				gBiko3    := SUBSTR(recMeisai.MSG_BIKO_DAIKO2,26);
				gSortKey  := recMeisai.SORT_KEY_DAIKO;
			END IF;
		END IF;
		--==============================================================================
		-- 警告ワーク登録処理                                                           
		--==============================================================================
		INSERT INTO WARNING_WK(
        			ITAKU_KAISHA_CD, -- 委託会社コード
				WARN_INFO_KBN,   -- 警告連絡区分
				WARN_INFO_ID,    -- 警告連絡ＩＤ
				MESSAGE1,        -- メッセージ１
				MESSAGE2,        -- メッセージ２
				ISIN_CD,         -- ＩＳＩＮコード
				KOZA_TEN_CD,     -- 口座店コード
				KOZA_TEN_CIFCD,  -- 口座店ＣＩＦコード
				MGR_RNM,         -- 銘柄略称
				KKMEMBER_CD,     -- 機構加入者コード
				TAISHO_KOMOKU,   -- 対象項目
				TAISHO_YMD,      -- 対象期日
				BIKO1,           -- 備考１
				BIKO2,           -- 備考２
				BIKO3,           -- 備考３
				SORT_KEY,        -- ソートキー
				SHORI_KBN,       -- 処理区分
				LAST_TEISEI_DT,  -- 最終訂正日時
				LAST_TEISEI_ID,  -- 最終訂正者
				SHONIN_DT,       -- 承認日時
				SHONIN_ID,       -- 承認者
				KOUSIN_DT,       -- 更新日時
				KOUSIN_ID,       -- 更新者
				SAKUSEI_DT,      -- 作成日時
				SAKUSEI_ID        -- 作成者
				)
			VALUES (
				l_inItakuKaishaCd,
				l_inWarnInfoKbn,
				l_inWarnInfoId,
				coalesce(gMessage1,' '),
				coalesce(gMessage2,' '),
				coalesce(l_inIsinCd,' '),
				coalesce(l_inKozaTenCd,' '),
				coalesce(l_inKozaTenCifCd,' '),
				coalesce(l_inMgrRnm,' '),
				coalesce(l_inKkmemberCd,' '),
				coalesce(l_inTaishoKomoku,' '),
				coalesce(l_inTaishoYmd,' '),
				coalesce(gBiko1,' '),
				coalesce(gBiko2,' '),
				coalesce(gBiko3,' '),
				coalesce(gSortKey::numeric, 0),
				' ',
				to_timestamp(pkDate.getCurrentTime(), 'YYYY-MM-DD HH24:MI:SS.US'),
				'BATCH',
				DEFAULT,
				DEFAULT,
				CURRENT_TIMESTAMP,
				'BATCH',
				CURRENT_TIMESTAMP,
				'BATCH'
				);
	END LOOP;
	RETURN pkconstant.success();
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', C_REPORT_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', C_REPORT_ID, 'SQLERRM:' || SQLERRM);
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipkeikokuinsert ( l_inItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE, l_inWarnInfoKbn text, l_inWarnInfoId WARNING_WK.WARN_INFO_ID%TYPE, l_inIsinCd WARNING_WK.ISIN_CD%TYPE, l_inKozaTenCd WARNING_WK.KOZA_TEN_CD%TYPE, l_inKozaTenCifCd WARNING_WK.KOZA_TEN_CIFCD%TYPE, l_inKkmemberCd WARNING_WK.KKMEMBER_CD%TYPE, l_inMgrRnm WARNING_WK.MGR_RNM%TYPE, l_inTaishoKomoku WARNING_WK.TAISHO_KOMOKU%TYPE, l_inTaishoYmd WARNING_WK.TAISHO_YMD%TYPE, l_inYobi1 text, l_inYobi2 text, l_inYobi3 text, l_inYobi4 text, l_inJikodaikoKbn TEXT  ) FROM PUBLIC;
