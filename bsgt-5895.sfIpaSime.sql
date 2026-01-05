




CREATE OR REPLACE FUNCTION sfipasime ( 
	l_inItakuKaishaCd text, 
	l_outMishoninCnt OUT text, 
	l_outMisoushinCnt OUT text, 
	l_outErrDataCnt OUT text, 
	l_outUnreadCnt OUT text, 
	l_outMgrKariWarningCnt OUT text, 
	l_outMgrBefWarningCnt OUT text, 
	l_outMgrHenkoWarningCnt OUT text, 
	l_outCommonWarningCnt OUT text, 
	l_outModMgrCnt OUT text , 
	OUT extra_param integer) RETURNS record AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 締め処理用件数取得処理
-- * 以下の件数を取得します。
-- *
-- * 未送信データ件数
-- * エラー通知未対応データ件数
-- * メッセージ通知未読データ件数
-- * 銘柄情報仮登録警告件数
-- * 銘柄登録事前警告リスト件数
-- * 警告リスト（共通）リスト件数
-- * 銘柄情報変更警告リスト件数
-- * 【***重要***】みなとカスタマイズ用に作成した「sfIpaSimeMnt.sql」と同期をとること！！
-- * 【***重要***】警告（共通）リスト(SPIP07851)と同期をとること!
-- * 注 IP-05535の修正のとき、SPIP07851の修正が
-- * sfIpaSimeの方に反映(同期)がされてませんでした。
-- * 工数が取れるときに同期を取ってください！
-- *
-- * @author ASK
-- * @version $Id: sfIpaSime.sql,v 1.48 2015/09/04 01:25:19 takahashi Exp $
-- 
-- **********************************************
-- 定数
-- **********************************************
	-- SP_ID 
	SP_ID				CONSTANT text := 'sfIpaSime';
    T_KK_PHASE            CONSTANT UPD_MGR_KHN.KK_PHASE%TYPE       := 'M2';            -- 機構フェーズ
    T_KK_STAT             CONSTANT UPD_MGR_KHN.KK_STAT%TYPE        := '04';            -- 機構ステータス
    T_MGR_KK_ERR_CD       CONSTANT UPD_MGR_KHN.MGR_KK_ERR_CD%TYPE  := '1';             -- 銘柄機構エラーコード
-- **********************************************
-- 変数
-- **********************************************
    gGyomuYmd                   SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;  -- 業務日付
    gMgrHenkoWarningDd          numeric  := 0;                       -- 銘柄登録警告日付(日数)
	error integer	:= 1;
    gBicCd          varchar(11);       -- BICコード
	gShinBoshuStatFlg		integer := 0;    --警告（新規募集情報未登録）の出力有無フラグ
    gShinRecStatFlg			integer := 0;    --警告（新規記録情報通知未受信）の出力有無フラグ
    gShinRecShoninKahiFlg	integer := 0;    --警告（新規記録承認可否未入力）の出力有無フラグ
    gTesuSetStatFlg		    integer := 0;    --警告（手数料設定情報未登録）の出力有無フラグ
    gJisshitsukiOptionFlg	integer := 0;    --オプションフラグ(実質記番号)取得用変数
	gShinRecOptionFlg 		integer := 0;    --オプションフラグ(新規記録情報取込当日出力フラグ)
	gFurikaeCbOptionFlg     integer := 0;
-- **********************************************
-- 本処理
-- **********************************************
BEGIN
	-- Create temp table to share context between nested functions
	CREATE TEMP TABLE IF NOT EXISTS sfipasime_context (
		l_inItakuKaishaCd text,
		gGyomuYmd text,
		gBicCd text,
		gShinBoshuStatFlg integer,
		gShinRecStatFlg integer,
		gShinRecShoninKahiFlg integer,
		gTesuSetStatFlg integer,
		gJisshitsukiOptionFlg integer,
		gShinRecOptionFlg integer,
		gFurikaeCbOptionFlg integer
	);
	
	-- 業務日付の取得
	gGyomuYmd := pkDate.getGyomuYmd();
    IF (trim(both l_inItakuKaishaCd) IS NOT NULL AND (trim(both l_inItakuKaishaCd))::text <> '') THEN
        -- 自行委託ＶＩＥＷより、ＢＩＣコードを取得
        BEGIN
            SELECT
                trim(both VJ1.BIC_CD)
            INTO STRICT
                gBicCd
            FROM
                VJIKO_ITAKU VJ1
            WHERE
                VJ1.KAIIN_ID = l_inItakuKaishaCd;
        EXCEPTION
            WHEN no_data_found THEN
                -- 全委託委託会社分の件数を取得する。
                CALL pkLog.DEBUG(SP_ID,'','委託会社コードよりＢＩＣコードが取得できなかったので、全委託会社分の件数を取得します。');
                gBicCd := NULL;
        END;
    ELSE
        -- 全委託委託会社分の件数を取得する。
        CALL pkLog.DEBUG(SP_ID,'','全委託会社分の件数を取得します。');
        gBicCd := NULL;
    END IF;
	-- 処理制御フラグ取得
	--警告（新規募集情報未登録）の警告リスト出力有無
    gShinBoshuStatFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'SPIP07851001', '0');
    --警告(新規新規記録情報通知未受信)の警告リスト出力有無
    gShinRecStatFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'SPIP07851002', '0');
    --警告(新規記録承認可否未入力)の警告リスト出力有無
    gShinRecShoninKahiFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'SPIP07851003', '0');
    --警告(手数料設定情報未登録)の警告リスト出力有無
    gTesuSetStatFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'SPIP07851004', '0');
    --オプションフラグ(実質記番号)取得
    gJisshitsukiOptionFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd,'IPP1003302010','0');
    --オプションフラグ(新規記録情報取込当日出力フラグ)
    gShinRecOptionFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd,'SPIP07851005','0');
	--オプションフラグ(振替ＣＢフラグ)
	gFurikaeCbOptionFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd, 'IPW1000000001', '0');
	
	-- Insert context into temp table
	DELETE FROM sfipasime_context;
	INSERT INTO sfipasime_context VALUES (
		l_inItakuKaishaCd,
		gGyomuYmd,
		gBicCd,
		gShinBoshuStatFlg,
		gShinRecStatFlg,
		gShinRecShoninKahiFlg,
		gTesuSetStatFlg,
		gJisshitsukiOptionFlg,
		gShinRecOptionFlg,
		gFurikaeCbOptionFlg
	);
	
	l_outMisoushinCnt := sfIpaSime_getMisoushinCnt()::text;
	l_outErrDataCnt := sfIpaSime_getErrDataCnt()::text;
	l_outUnreadCnt := sfIpaSime_getUnreadCnt()::text;
	l_outMgrKariWarningCnt := sfIpaSime_getMgrKariWarningCnt()::text;
	l_outMgrBefWarningCnt := sfIpaSime_getMgrBefWarningCnt()::text;
	l_outMgrHenkoWarningCnt := sfIpaSime_getMgrHenkoWarningCnt()::text;
	l_outCommonWarningCnt := sfIpaSime_getCommonWarningCnt()::text;
	l_outModMgrCnt := sfIpaSime_getModMgrCnt()::text;
	-- TODO: Fix SPIP07861 call - temporarily commented out
	-- l_outMishoninCnt := sfIpaSime_getMishoninCnt()::text;
	l_outMishoninCnt := '0'::text;
extra_param := pkconstant.success();
RETURN;
-- **********************************************
-- 異常終了
-- **********************************************
EXCEPTION
	WHEN OTHERS THEN
	RAISE NOTICE 'SFIPASIME ERROR: SQLSTATE=%, SQLERRM=%', SQLSTATE, SQLERRM;
	CALL pkLog.fatal('ECM701', 'SFIPASIME', 'SQLCODE:'||SQLSTATE);
	CALL pkLog.fatal('ECM701', 'SFIPASIME', 'SQLERRM:'||SQLERRM);
	extra_param := error;
	RETURN;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipasime ( l_inItakuKaishaCd text, l_outMishoninCnt OUT text, l_outMisoushinCnt OUT text, l_outErrDataCnt OUT text, l_outUnreadCnt OUT text, l_outMgrKariWarningCnt OUT text, l_outMgrBefWarningCnt OUT text, l_outMgrHenkoWarningCnt OUT text, l_outCommonWarningCnt OUT text, l_outModMgrCnt OUT text , OUT extra_param integer) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipasime_getcommonwarningcnt () RETURNS numeric AS $body$
DECLARE

	pCnt numeric := 0;


T_KK_PHASE char(2) := 'M2';
T_KK_STAT char(2) := '04';
T_MGR_KK_ERR_CD char(1) := '1';
	DAIKO_KEY_CD text;

	-- Load context from temp table
l_inItakuKaishaCd text;
gGyomuYmd text;
gBicCd text;
gShinBoshuStatFlg integer;
gShinRecStatFlg integer;
gShinRecShoninKahiFlg integer;
gTesuSetStatFlg integer;
gJisshitsukiOptionFlg integer;
gShinRecOptionFlg integer;
gFurikaeCbOptionFlg integer;

BEGIN
SELECT * INTO l_inItakuKaishaCd, gGyomuYmd, gBicCd, gShinBoshuStatFlg, gShinRecStatFlg, 
       gShinRecShoninKahiFlg, gTesuSetStatFlg, gJisshitsukiOptionFlg, gShinRecOptionFlg, gFurikaeCbOptionFlg
FROM sfipasime_context LIMIT 1;
	DAIKO_KEY_CD := pkconstant.DAIKO_KEY_CD();
	SELECT COUNT(*) INTO STRICT pCnt FROM
	(
		SELECT  --===========================================新規募集情報未登録
			VMG1.MGR_CD
		FROM
			MGR_KIHON_VIEW VMG1
		WHERE
                    VMG1.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  VMG1.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END
			AND VMG1.MGR_STAT_KBN = '1'
			AND VMG1.JTK_KBN != '2'
			AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
			AND VMG1.TOKUREI_SHASAI_FLG = 'N'
			AND VMG1.HAKKO_YMD >= pkdate.getGyomuYmd()::text
			AND NOT(VMG1.SAIKEN_SHURUI IN ('80', '89') AND VMG1.HAKKO_KAGAKU = 0)
			AND NOT EXISTS (
				SELECT
					B01.MGR_CD
				FROM SHINKIBOSHU B01
				WHERE B01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
				AND B01.MGR_CD = VMG1.MGR_CD
			)
			AND gShinBoshuStatFlg = 1 
		
UNION ALL

		SELECT  --===========================================新規記録情報未受信
			T1.MGR_CD
		FROM (
				-- 未受信
				SELECT
					VMG1.ITAKU_KAISHA_CD,
					VMG1.MGR_CD,
					VMG1.ISIN_CD,
					VMG1.MGR_RNM,
					VMG1.HAKKO_YMD,
					COUNT(*) AS CNT
				FROM
					MGR_KIHON_VIEW VMG1,
					VSHINKI_REC_STATUS_MANAGEMENT B04
				WHERE VMG1.ITAKU_KAISHA_CD = B04.ITAKU_KAISHA_CD
					AND VMG1.MGR_CD = B04.MGR_CD
                        AND VMG1.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  VMG1.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
					AND VMG1.MGR_STAT_KBN = '1'
					AND B04.DAIRI_MOTION_FLG != '1'					-- 0：機構加入者申請、1：代理人直接申請（VIEWは、機構申請は0、2がある）
					AND B04.MASSHO_FLG <> '1'
					AND B04.SHINCHOKU_STAT in ('H002', 'H103')		-- H002：新規記録情報通知待ち、H103：新規記録情報取消通知待ち
 
				GROUP BY
					VMG1.ITAKU_KAISHA_CD,
					VMG1.MGR_CD,
					VMG1.ISIN_CD,
					VMG1.MGR_RNM,
					VMG1.HAKKO_YMD
			) t1
LEFT OUTER JOIN (
				-- 受信済み
				SELECT
					VMG1.ITAKU_KAISHA_CD,
					VMG1.MGR_CD,
					VMG1.ISIN_CD,
					VMG1.MGR_RNM,
					VMG1.HAKKO_YMD,
					COUNT(*) AS CNT
				FROM
					MGR_KIHON_VIEW VMG1,
					VSHINKI_REC_STATUS_MANAGEMENT B04
				WHERE VMG1.ITAKU_KAISHA_CD = B04.ITAKU_KAISHA_CD
					AND VMG1.MGR_CD = B04.MGR_CD
                        AND VMG1.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  VMG1.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
					AND VMG1.MGR_STAT_KBN = '1'
					AND B04.DAIRI_MOTION_FLG != '1'					-- 0：機構加入者申請、1：代理人直接申請（VIEWは、機構申請は0、2がある）
					AND B04.MASSHO_FLG <> '1'
					AND B04.TOTSUGO_KEKKA_KBN != '3'				-- 3：突合相手なし
					AND B04.SHINCHOKU_STAT != 'H401'				-- H401：新規募集情報承認待ち
					AND B04.SHINCHOKU_STAT != 'H002'				-- H002：新規記録情報通知待ち
					AND B04.SHINCHOKU_STAT != 'H103'				-- H103：新規記録情報取消通知待ち
					AND B04.SHINCHOKU_STAT != 'H004'				-- H004：新規記録情報取消完了
				GROUP BY
					VMG1.ITAKU_KAISHA_CD,
					VMG1.MGR_CD,
					VMG1.ISIN_CD,
					VMG1.MGR_RNM,
					VMG1.HAKKO_YMD
			) t2 ON (T1.ITAKU_KAISHA_CD = T2.ITAKU_KAISHA_CD AND T1.MGR_CD = T2.MGR_CD) 
WHERE gShinRecStatFlg = 1
		 
UNION ALL

		SELECT  --===========================================新規記録承認可否未入力
			VMG1.MGR_CD
		FROM mgr_kihon_view vmg1, shinkikiroku b04
LEFT OUTER JOIN (
				SELECT
					M08.ITAKU_KAISHA_CD,
					M08.BIC_CD_NOSHITEN,
					M08.FINANCIAL_SECURITIES_KBN,
					M08.BANK_CD
				FROM
					MBANK_ZOKUSEI M08
				WHERE
					(trim(both BIC_CD_NOSHITEN) IS NOT NULL AND (trim(both BIC_CD_NOSHITEN))::text <> '') 
			) m08 ON (B04.ITAKU_KAISHA_CD = M08.ITAKU_KAISHA_CD)
WHERE B04.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD AND B04.ISIN_CD = VMG1.ISIN_CD   --*
--				 * IP-05722(2007/12)での対応
--				 * ==注== IP-05535の修正のとき、SPIP07851の修正が
--				 * sfIpaSimeの方に反映(同期)がされてませんでした。
--				 * IP-05722での対応ではオプションフラグ対応分だけ修正しています。
--				 
			-- :: 新規記録情報取込当日出力OPフラグによる抽出制御 (ここから) ::
  AND (
				-- 当日出力OPフラグがオン_*オプション用
			 		-- (新規募集情報テーブル、業務日付をチェックしない(条件にしない))
	          (gShinRecOptionFlg = 1)
	          OR
	            -- 当日出力OPフラグがオフ_*パッケージ分
			 		-- (新規募集情報テーブルに存在 AND 業務日付より前日 をチェックする)
	          (
	            (EXISTS (SELECT B01.MGR_CD
	                      FROM SHINKIBOSHU B01
	                      WHERE
	                              B01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
	                              AND B01.MGR_CD = VMG1.MGR_CD
								  AND B01.KESSAI_NO = B04.KESSAI_NO
								  AND B01.MASSHO_FLG != '1'
	                )
	             )
	            AND ( TO_CHAR(B04.SAKUSEI_DT, 'YYYYMMDD') < gGyomuYmd )
	           )
	        ) -- :: 新規記録情報取込当日出力OPフラグによる抽出制御 (ここまで) ::
  AND B04.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  B04.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END AND B04.KK_PHASE || B04.KK_STAT IN ('H003', 'H101', 'H102') --*
--					 * 新規記録承認可否未入力の警告は送信(CSV作成)が実行されるまで
--					 * 警告を出力する。
--					 * そのため、
--					 * H003:新規記録情報承認可否入力待ち
--					 * H101:新規記録情報承認待ち
--					 * H102:新規記録情報承認承認送信待ち
--					 * 上記、承認・非承認送信前までが警告の対象ステータスとなる。
--					 *
--					 * (030詳細設計\24_状態遷移図\)
--					 * 状態遷移図(ステートチャート図)新規記録関係.xlsを参照のこと
--					 
  AND VMG1.MGR_STAT_KBN = '1' AND VMG1.JTK_KBN != '2' -- 特例社債ではない
  AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '') 	-- ISIN付番されている
  AND VMG1.TOKUREI_SHASAI_FLG = 'N' -- 特例社債ではない
  AND gShinRecShoninKahiFlg = 1 		-- 警告（新規記録承認可否未入力）の出力有無フラグ
  
UNION ALL

		SELECT  --===========================================手数料設定情報未登録
           		VMG1.MGR_CD
       	 	FROM
            	MGR_KIHON_VIEW VMG1
         	WHERE
                    VMG1.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  VMG1.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
        	    AND VMG1.TESU_SET_TEISEI_YMD = ' '
        	    AND VMG1.MGR_STAT_KBN = '1'
			AND (VMG1.KK_KANYO_FLG <> '2' OR gJisshitsukiOptionFlg = 1)
        	    AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
        	    AND gTesuSetStatFlg = 1 
        	
UNION ALL

		SELECT  --===========================================分かち課税日数未来分が設定されている件数
			VMG1.MGR_CD               -- 銘柄コード
		FROM
			MGR_KIHON_VIEW VMG1,
			(SELECT ITAKU_KAISHA_CD,MGR_CD
			FROM MGR_RBRKIJ
			WHERE ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND   RBR_YMD = gGyomuYmd
			GROUP BY ITAKU_KAISHA_CD,MGR_CD) MG2,
			KBG_SHOKIJ P01,
			KBG_SHOKBG P02
		WHERE
                VMG1.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  VMG1.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
		AND VMG1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG2.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = P01.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = P01.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = P02.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = P02.MGR_CD
		--  2007/09/18 ADD JIP  -------------------------------
		AND (
				(  P01.SHOKAN_KJT = P02.SHOKAN_KJT         AND
			   	   P01.KBG_SHOKAN_KBN = P02.KBG_SHOKAN_KBN AND
			   	   P01.SHOKAN_YMD > gGyomuYmd
				)
				OR coalesce(trim(both P02.SHOKAN_KJT)::text, '') = ''
			)
		--  2007/09/18 ADD JIP  -------------------------------
		AND P02.WKC_TAX_DAYS != 0
		AND VMG1.MGR_STAT_KBN = '1'
		AND VMG1.KK_KANYO_FLG = '2'
		AND gJisshitsukiOptionFlg = 1
		AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '') 
		GROUP BY VMG1.MGR_CD
		
UNION ALL

		SELECT  --===========================================実質記番号ＯＰ残高相違
			V.MGR_CD 					-- 銘柄コード
		FROM (
				SELECT
					VMG1.MGR_CD,					-- 銘柄コード
					PKIPAZNDK.getKjnZndk(VMG1.ITAKU_KAISHA_CD, VMG1.MGR_CD, gGyomuYmd, 3)::numeric A,		--パッケージ残高
					PKIPAKIBANGO.getKjnZndk(VMG1.ITAKU_KAISHA_CD, VMG1.MGR_CD, gGyomuYmd) B,		--実質記番号償還回次残高
					PKIPAKIBANGO.getShoKbgZndk(VMG1.ITAKU_KAISHA_CD, VMG1.MGR_CD, gGyomuYmd) C 	--実質記番号情報残高
				FROM
					MGR_KIHON_VIEW VMG1
				WHERE
                        VMG1.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  VMG1.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
				AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
				AND VMG1.MGR_STAT_KBN = '1'
				AND VMG1.KK_KANYO_FLG = '2'
				AND gJisshitsukiOptionFlg = 1 
			) V,
			
			(
				SELECT 1 AS VAL  	
UNION ALL

				SELECT 2 AS VAL  	
UNION ALL

				SELECT 3 AS VAL 
			) VSEQ
		WHERE (VSEQ.VAL = 1 AND V.A <> V.B)
		OR (VSEQ.VAL = 2 AND V.A <> V.C)
		OR (VSEQ.VAL = 3 AND V.B <> V.C) 
		
UNION ALL

		SELECT  --===========================================新規記録結果情報未登録
			VMG1.MGR_CD
		FROM
			MGR_KIHON_VIEW VMG1
		WHERE
                  VMG1.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  VMG1.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
		AND   VMG1.MGR_STAT_KBN       =  '1'
		AND   VMG1.JTK_KBN            != '2'
		AND   (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
		AND   VMG1.TOKUREI_SHASAI_FLG =  'N'
		AND   VMG1.SAIKEN_SHURUI      IN ('80', '89')
		AND   VMG1.HAKKO_YMD          >= pkdate.getGyomuYmd()::text
		AND   EXISTS (
				SELECT
					MGR_CD
				FROM
					SHINKIBOSHU
				WHERE ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
				AND   MGR_CD          = VMG1.MGR_CD
		)
		AND   NOT EXISTS (
				SELECT
					MGR_CD
				FROM
					NYUKIN_YOTEI
				WHERE ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
				AND   MGR_CD          = VMG1.MGR_CD
		)
		AND gFurikaeCbOptionFlg       =  1 
	) alias64;
RETURN pCnt;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipasime_getcommonwarningcnt () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipasime_geterrdatacnt () RETURNS numeric AS $body$
DECLARE

	wk_count numeric := 0;
	wk_count2 numeric := 0;


T_KK_PHASE char(2) := 'M2';
T_KK_STAT char(2) := '04';
T_MGR_KK_ERR_CD char(1) := '1';
	DAIKO_KEY_CD text;

	-- Load context from temp table
l_inItakuKaishaCd text;
gGyomuYmd text;
gBicCd text;
gShinBoshuStatFlg integer;
gShinRecStatFlg integer;
gShinRecShoninKahiFlg integer;
gTesuSetStatFlg integer;
gJisshitsukiOptionFlg integer;
gShinRecOptionFlg integer;
gFurikaeCbOptionFlg integer;

BEGIN
SELECT * INTO l_inItakuKaishaCd, gGyomuYmd, gBicCd, gShinBoshuStatFlg, gShinRecStatFlg, 
       gShinRecShoninKahiFlg, gTesuSetStatFlg, gJisshitsukiOptionFlg, gShinRecOptionFlg, gFurikaeCbOptionFlg
FROM sfipasime_context LIMIT 1;
	DAIKO_KEY_CD := pkconstant.DAIKO_KEY_CD();
	-- 銘柄情報登録のエラー警告
	SELECT
		COUNT(MG0.ctid)
	INTO STRICT
		wk_count2
	FROM
		MGR_STS MG0,
		MGR_KIHON_VIEW VMG1
	WHERE
		MG0.MGR_KK_ERR_CD = T_MGR_KK_ERR_CD
	AND MG0.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
	AND MG0.MGR_CD = VMG1.MGR_CD
	AND VMG1.MGR_STAT_KBN <> '2'		-- 仮登録以外
        AND MG0.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  MG0.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END
	AND VMG1.TOKUREI_SHASAI_FLG <> 'Y'  -- 特例社債以外
	AND VMG1.HAKKO_YMD >= gGYomuYmd;
	wk_count := wk_count + wk_count2;
	wk_count2 := 0;
	SELECT
		COUNT(MG0.ctid)
	INTO STRICT
		wk_count2
	FROM
		MGR_STS MG0,
		MGR_KIHON_VIEW VMG1
	WHERE
		MG0.MGR_KK_ERR_CD = T_MGR_KK_ERR_CD
	AND MG0.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
	AND MG0.MGR_CD = VMG1.MGR_CD
	AND VMG1.MGR_STAT_KBN <> '2'		-- 仮登録以外
        AND MG0.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  MG0.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END
	AND VMG1.TOKUREI_SHASAI_FLG = 'Y';   -- 特例社債
	wk_count := wk_count + wk_count2;
	wk_count2 := 0;
	-- 新規募集のエラー警告
	SELECT
		COUNT(B01.ctid)
	INTO STRICT
		wk_count2
	FROM
		SHINKIBOSHU B01,
		MGR_KIHON_VIEW VMG1
	WHERE
		B01.KK_KEIKOKU_ERR_CD = '2'
	AND B01.KK_TORIKESHI_JUSHIN_FLG <> '1'	-- 機構取消通告受信フラグ = 取消受信以外(IP-03876山本)
	AND B01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
	AND B01.MGR_CD = VMG1.MGR_CD
        AND B01.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  B01.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END
	AND VMG1.HAKKO_YMD >= gGYomuYmd;
	wk_count := wk_count + wk_count2;
	wk_count2 := 0;
	-- 新規記録のエラー警告
	SELECT
		COUNT(B04.ctid)
	INTO STRICT
		wk_count2
	FROM
		SHINKIKIROKU B04,
		MGR_KIHON_VIEW VMG1
	WHERE
		B04.KK_KEIKOKU_ERR_CD = '2'
	AND B04.KK_TORIKESHI_JUSHIN_FLG <> '1'	-- 機構取消通告受信フラグ = 取消受信以外(IP-03876山本)
	AND B04.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
	AND B04.ISIN_CD = VMG1.ISIN_CD
        AND B04.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  B04.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END
	AND VMG1.HAKKO_YMD >= gGYomuYmd;
	wk_count := wk_count + wk_count2;
	RETURN wk_count;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipasime_geterrdatacnt () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipasime_getmgrbefwarningcnt () RETURNS numeric AS $body$
DECLARE

	wk_mgr_toroku_warning_dd numeric := 0;
	wk_count numeric := 0;


T_KK_PHASE char(2) := 'M2';
T_KK_STAT char(2) := '04';
T_MGR_KK_ERR_CD char(1) := '1';
	DAIKO_KEY_CD text;

	-- Load context from temp table
l_inItakuKaishaCd text;
gGyomuYmd text;
gBicCd text;
gShinBoshuStatFlg integer;
gShinRecStatFlg integer;
gShinRecShoninKahiFlg integer;
gTesuSetStatFlg integer;
gJisshitsukiOptionFlg integer;
gShinRecOptionFlg integer;
gFurikaeCbOptionFlg integer;

BEGIN
SELECT * INTO l_inItakuKaishaCd, gGyomuYmd, gBicCd, gShinBoshuStatFlg, gShinRecStatFlg, 
       gShinRecShoninKahiFlg, gTesuSetStatFlg, gJisshitsukiOptionFlg, gShinRecOptionFlg, gFurikaeCbOptionFlg
FROM sfipasime_context LIMIT 1;
	DAIKO_KEY_CD := pkconstant.DAIKO_KEY_CD();
	-- 銘柄登録警告日付の取得(日数)
	SELECT
		mgr_toroku_warning_dd
	INTO STRICT
		wk_mgr_toroku_warning_dd
	FROM
		ssystem_info
	WHERE
		KAIIN_ID  =  pkConstant.getKaiinId();
	-- 銘柄登録事前警告件数の取得
        -- 銘柄登録変更日付 <= 業務日付 <= 発行日 の間出力 
	SELECT
		count(*)
	INTO STRICT
		wk_count
	FROM
		MGR_KIHON_VIEW VMG1
	WHERE
            VMG1.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  VMG1.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END  AND
		pkDate.getMinusDateBusiness(VMG1.HAKKO_YMD,WK_MGR_TOROKU_WARNING_DD::integer) <= gGyomuYmd AND
    		gGyomuYmd <= VMG1.HAKKO_YMD AND (VMG1.BEF_WARNING_L in ('1', '2') or VMG1.BEF_WARNING_S in ('1', '2', '9')) AND
		VMG1.SHORI_KBN = '1' AND
		VMG1.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD AND
		VMG1.MGR_CD = VMG1.MGR_CD;
	RETURN wk_count;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipasime_getmgrbefwarningcnt () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipasime_getmgrhenkowarningcnt () RETURNS numeric AS $body$
DECLARE

	wk_mgr_henko_warning_dd numeric := 0;
        cnt numeric := 0;
        kijunYmd char(8);


T_KK_PHASE char(2) := 'M2';
T_KK_STAT char(2) := '04';
T_MGR_KK_ERR_CD char(1) := '1';
	DAIKO_KEY_CD text;

	-- Load context from temp table
l_inItakuKaishaCd text;
gGyomuYmd text;
gBicCd text;
gShinBoshuStatFlg integer;
gShinRecStatFlg integer;
gShinRecShoninKahiFlg integer;
gTesuSetStatFlg integer;
gJisshitsukiOptionFlg integer;
gShinRecOptionFlg integer;
gFurikaeCbOptionFlg integer;

BEGIN
SELECT * INTO l_inItakuKaishaCd, gGyomuYmd, gBicCd, gShinBoshuStatFlg, gShinRecStatFlg, 
       gShinRecShoninKahiFlg, gTesuSetStatFlg, gJisshitsukiOptionFlg, gShinRecOptionFlg, gFurikaeCbOptionFlg
FROM sfipasime_context LIMIT 1;
	DAIKO_KEY_CD := pkconstant.DAIKO_KEY_CD();
	-- 銘柄変更警告日付の取得(日数)
	SELECT
		mgr_henko_warning_dd
	INTO STRICT
		wk_mgr_henko_warning_dd
	FROM
		ssystem_info
	WHERE
		KAIIN_ID  =  pkConstant.getKaiinId();
    --
--     * 銘柄情報変更警告リスト件数取得
--     *
--     * 以下の３つのSELECT文から構成されています。
--     *
--     * 1. 変動利付債の利率未申請分
--     * 2. 定時償還銘柄の償還額未申請分
--     * 3. その他海外未申請分
--     *
--     * ３つのSELECT文に共通してる処理は
--     * 1. 変更警告対象となるデータを取得
--     *    抽出期間は　業務日付 <= 支払日 <= 業務日付から銘柄変更警告日付の取得(日数)先の日付の間です。
--     *
--     *    例：
--     *      業務日付が2005/11/06
--     *      システム情報マスタ.銘柄変更警告日付が5が設定されている。
--     *      支払日が2005/11/06〜2005/11/11（すべて営業日として）の間が対象となります。
--     *
--     * 2. WHERE句のNOT IN ですでに期中銘柄情報で処理が完了している、委託会社、銘柄、支払期日のデータは除く
--     *    期中銘柄情報変更が承認済みかつ、機構フェーズ、ステータスが送信完了かつ、銘柄機構エラーコードが'1'でないものは処理完了とみなす
--     *
--     
	-- 業務日付から銘柄変更警告日付の取得(日数)先の日付を取得（営業日ベース）
	kijunYmd := pkDate.getPlusDateBusiness(gGyomuYmd, wk_mgr_henko_warning_dd::integer);
	SELECT COUNT(*) INTO STRICT cnt FROM (
	-- 利払
	SELECT
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
            VMG1.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  VMG1.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END
	AND VMG1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
	AND VMG1.MGR_CD = MG2.MGR_CD
	AND VMG1.JTK_KBN != '2'             -- 副受託以外
	AND VMG1.RITSUKE_WARIBIKI_KBN = 'V'
	AND VMG1.SHORI_KBN = '1'
	AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')  -- ISINコード＝ブランクは対象外
--		AND MG2.KK_KANYO_FLG = '1'
	AND MG2.RBR_YMD <= kijunYmd
	AND gGyomuYmd <= MG2.RBR_YMD
	AND MG2.KAIJI != 0
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
                MG22.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  MG22.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
		AND MG22.KK_PHASE = T_KK_PHASE
		AND MG22.KK_STAT = T_KK_STAT
		AND MG22.MGR_KK_ERR_CD != T_MGR_KK_ERR_CD
		AND MG22.SHORI_KBN = '1'
		
UNION

		SELECT
			MG2.RBR_KJT,
			MG2.MGR_CD
		FROM	MGR_RBRKIJ MG2,MGR_STS MG0,MGR_KIHON MG1
		WHERE	MG2.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
		AND		MG2.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
            AND     MG2.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  MG2.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
		AND		MG2.MGR_CD = MG0.MGR_CD
		AND		MG2.MGR_CD = MG1.MGR_CD
		AND		MG2.KAIJI	= 1
		AND		MG1.RITSUKE_WARIBIKI_KBN = 'V'
		AND		MG1.TSUKARISHI_KNGK_FAST <> 0
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
            VMG1.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  VMG1.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
	AND VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
	AND VMG1.MGR_CD = MG3.MGR_CD
	AND VMG1.JTK_KBN != '2'             -- 副受託以外
	AND VMG1.TEIJI_SHOKAN_TSUTI_KBN = 'V'
	AND VMG1.SHORI_KBN = '1'
	AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')  -- ISINコード＝ブランクは対象外
	AND VMG1.KK_KANYO_FLG <> '2'
	AND MG3.SHOKAN_KBN IN ('20','21')
	AND MG3.SHOKAN_YMD <= kijunYmd
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
                MG23.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  MG23.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
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
            AND     MG3.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  MG3.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
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
            VMG1.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  VMG1.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
	AND VMG1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
	AND VMG1.MGR_CD = MG2.MGR_CD
	AND VMG1.JTK_KBN != '2'             -- 副受託以外
	AND VMG1.KYUJITSU_ETC_FLG = 'Y'
	AND VMG1.RITSUKE_WARIBIKI_KBN != 'Z'
	AND VMG1.KK_KANYO_FLG <> '2'
	AND VMG1.SHORI_KBN = '1'
	AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')  -- ISINコード＝ブランクは対象外
	AND MG2.RBR_YMD <= kijunYmd
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
                MG21.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  MG21.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
		AND MG21.KK_PHASE = T_KK_PHASE
		AND MG21.KK_STAT = T_KK_STAT
		AND MG21.MGR_KK_ERR_CD != T_MGR_KK_ERR_CD
		AND MG21.SHORI_KBN = '1'
	) 
    
UNION

    -- 銘柄(割引債)
    SELECT
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
            VMG1.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  VMG1.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
    AND VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
    AND VMG1.MGR_CD = MG3.MGR_CD
    AND VMG1.JTK_KBN != '2'             -- 副受託以外
    AND VMG1.KYUJITSU_ETC_FLG = 'Y'
    AND VMG1.RITSUKE_WARIBIKI_KBN = 'Z'
    AND VMG1.KK_KANYO_FLG <> '2'
    AND VMG1.SHORI_KBN = '1'
	AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')  -- ISINコード＝ブランクは対象外
    AND MG3.SHOKAN_YMD <= kijunYmd
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
                MG21.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  MG21.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
        AND MG21.KK_PHASE = T_KK_PHASE
        AND MG21.KK_STAT = T_KK_STAT
        AND MG21.MGR_KK_ERR_CD != T_MGR_KK_ERR_CD
        AND MG21.SHORI_KBN = '1'
    ) 
	) alias34;
    RETURN cnt;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipasime_getmgrhenkowarningcnt () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipasime_getmgrkariwarningcnt () RETURNS numeric AS $body$
DECLARE

	wk_count numeric := 0;


T_KK_PHASE char(2) := 'M2';
T_KK_STAT char(2) := '04';
T_MGR_KK_ERR_CD char(1) := '1';
	DAIKO_KEY_CD text;

	-- Load context from temp table
l_inItakuKaishaCd text;
gGyomuYmd text;
gBicCd text;
gShinBoshuStatFlg integer;
gShinRecStatFlg integer;
gShinRecShoninKahiFlg integer;
gTesuSetStatFlg integer;
gJisshitsukiOptionFlg integer;
gShinRecOptionFlg integer;
gFurikaeCbOptionFlg integer;

BEGIN
SELECT * INTO l_inItakuKaishaCd, gGyomuYmd, gBicCd, gShinBoshuStatFlg, gShinRecStatFlg, 
       gShinRecShoninKahiFlg, gTesuSetStatFlg, gJisshitsukiOptionFlg, gShinRecOptionFlg, gFurikaeCbOptionFlg
FROM sfipasime_context LIMIT 1;
	DAIKO_KEY_CD := pkconstant.DAIKO_KEY_CD();
	-- 銘柄情報仮登録警告件数の取得
	SELECT
		count(*)
	INTO STRICT
		wk_count
	FROM
		mgr_sts MG0,
		mgr_kihon MG1
	WHERE
            MG1.itaku_kaisha_cd = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  MG1.itaku_kaisha_cd  ELSE l_inItakuKaishaCd END  AND
		MG0.mgr_stat_kbn = '2' AND
		MG0.itaku_kaisha_cd = MG1.itaku_kaisha_cd AND
		MG0.mgr_cd = MG1.mgr_cd;
	RETURN wk_count;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipasime_getmgrkariwarningcnt () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipasime_getmishonincnt () RETURNS numeric AS $body$
DECLARE

	total_cnt 		varchar(5) := '';
	l_outSqlCode	integer := 0;
	l_outSqlErrM	text:= '';


T_KK_PHASE char(2) := 'M2';
T_KK_STAT char(2) := '04';
T_MGR_KK_ERR_CD char(1) := '1';
	DAIKO_KEY_CD text;

	-- Load context from temp table
l_inItakuKaishaCd text;
gGyomuYmd text;
gBicCd text;
gShinBoshuStatFlg integer;
gShinRecStatFlg integer;
gShinRecShoninKahiFlg integer;
gTesuSetStatFlg integer;
gJisshitsukiOptionFlg integer;
gShinRecOptionFlg integer;
gFurikaeCbOptionFlg integer;

BEGIN
SELECT * INTO l_inItakuKaishaCd, gGyomuYmd, gBicCd, gShinBoshuStatFlg, gShinRecStatFlg, 
       gShinRecShoninKahiFlg, gTesuSetStatFlg, gJisshitsukiOptionFlg, gShinRecOptionFlg, gFurikaeCbOptionFlg
FROM sfipasime_context LIMIT 1;
	DAIKO_KEY_CD := pkconstant.DAIKO_KEY_CD();
	CALL SPIP07861(l_inItakuKaishaCd, 'BATCH', '0', gGyomuYmd, total_cnt, l_outSqlCode, l_outSqlErrM, '1');
	RETURN total_cnt::numeric;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipasime_getmishonincnt () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipasime_getmisoushincnt () RETURNS numeric AS $body$
DECLARE

	wk_count numeric := 0;


T_KK_PHASE char(2) := 'M2';
T_KK_STAT char(2) := '04';
T_MGR_KK_ERR_CD char(1) := '1';
	DAIKO_KEY_CD text;

	-- Load context from temp table
l_inItakuKaishaCd text;
gGyomuYmd text;
gBicCd text;
gShinBoshuStatFlg integer;
gShinRecStatFlg integer;
gShinRecShoninKahiFlg integer;
gTesuSetStatFlg integer;
gJisshitsukiOptionFlg integer;
gShinRecOptionFlg integer;
gFurikaeCbOptionFlg integer;

BEGIN
SELECT * INTO l_inItakuKaishaCd, gGyomuYmd, gBicCd, gShinBoshuStatFlg, gShinRecStatFlg, 
       gShinRecShoninKahiFlg, gTesuSetStatFlg, gJisshitsukiOptionFlg, gShinRecOptionFlg, gFurikaeCbOptionFlg
FROM sfipasime_context LIMIT 1;
	DAIKO_KEY_CD := pkconstant.DAIKO_KEY_CD();
	SELECT
		count(*)
	INTO STRICT
		wk_count
	FROM
		kk_renkei
	WHERE (denbun_stat = '11' or denbun_stat = '12')
        AND (trim(both sr_bic_cd) = gBicCd or coalesce(gBicCd::text, '') = '');
	RETURN wk_count;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipasime_getmisoushincnt () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipasime_getmodmgrcnt () RETURNS numeric AS $body$
DECLARE

	pCnt numeric := 0;


T_KK_PHASE char(2) := 'M2';
T_KK_STAT char(2) := '04';
T_MGR_KK_ERR_CD char(1) := '1';
	DAIKO_KEY_CD text;

	-- Load context from temp table
l_inItakuKaishaCd text;
gGyomuYmd text;
gBicCd text;
gShinBoshuStatFlg integer;
gShinRecStatFlg integer;
gShinRecShoninKahiFlg integer;
gTesuSetStatFlg integer;
gJisshitsukiOptionFlg integer;
gShinRecOptionFlg integer;
gFurikaeCbOptionFlg integer;

BEGIN
SELECT * INTO l_inItakuKaishaCd, gGyomuYmd, gBicCd, gShinBoshuStatFlg, gShinRecStatFlg, 
       gShinRecShoninKahiFlg, gTesuSetStatFlg, gJisshitsukiOptionFlg, gShinRecOptionFlg, gFurikaeCbOptionFlg
FROM sfipasime_context LIMIT 1;
	DAIKO_KEY_CD := pkconstant.DAIKO_KEY_CD();
	-- カレンダ訂正履歴「2:リスト出力」カウント
	SELECT
		COUNT(*)
	INTO STRICT
		pCnt
	FROM
		MCALENDAR_TEISEI
	WHERE
                ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END
		AND MGR_KJT_CHOSEI_KBN = '2';
	-- カレンダ訂正履歴「2:リスト出力」が存在する時
	IF pCnt <> 0 THEN
		SELECT (
				SELECT
					COUNT(*) -- 利払回次調整情報カウント
				FROM
					MOD_MGR_RBRKIJ
				WHERE
                        ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END
			) +
			(
				SELECT
					COUNT(*) -- 償還回次調整情報カウント
				FROM
					MOD_MGR_SHOKIJ
				WHERE
					ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
			) +
			(
				SELECT
					COUNT(*) -- 期中手数料回次調整情報カウント
				FROM
					MOD_MGR_TESKIJ
				WHERE
					ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
			) +
			(
				SELECT
					COUNT(*) -- 実質記番号管理償還回次調整情報カウント
				FROM
					MOD_KBG_SHOKIJ
				WHERE
					ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END 
			)
		INTO STRICT
			pCnt
		;
	END IF;
	RETURN pCnt;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipasime_getmodmgrcnt () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipasime_getunreadcnt () RETURNS numeric AS $body$
DECLARE

	wk_count numeric := 0;


T_KK_PHASE char(2) := 'M2';
T_KK_STAT char(2) := '04';
T_MGR_KK_ERR_CD char(1) := '1';
	DAIKO_KEY_CD text;

	-- Load context from temp table
l_inItakuKaishaCd text;
gGyomuYmd text;
gBicCd text;
gShinBoshuStatFlg integer;
gShinRecStatFlg integer;
gShinRecShoninKahiFlg integer;
gTesuSetStatFlg integer;
gJisshitsukiOptionFlg integer;
gShinRecOptionFlg integer;
gFurikaeCbOptionFlg integer;

BEGIN
SELECT * INTO l_inItakuKaishaCd, gGyomuYmd, gBicCd, gShinBoshuStatFlg, gShinRecStatFlg, 
       gShinRecShoninKahiFlg, gTesuSetStatFlg, gJisshitsukiOptionFlg, gShinRecOptionFlg, gFurikaeCbOptionFlg
FROM sfipasime_context LIMIT 1;
	DAIKO_KEY_CD := pkconstant.DAIKO_KEY_CD();
	SELECT
		COUNT(*)
	INTO STRICT
		wk_count
	FROM
		MSG_TSUCHI
	WHERE
		KIDOKU_FLG = '0'
        AND ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=DAIKO_KEY_CD THEN  ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END
	AND GYOMU_YMD = gGYomuYmd;
	RETURN wk_count;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipasime_getunreadcnt () FROM PUBLIC;
