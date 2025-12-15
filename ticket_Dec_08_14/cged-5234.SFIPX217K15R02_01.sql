


-- Array type removed - using varchar(2)[] directly


CREATE OR REPLACE FUNCTION sfipx217k15r02_01 ( l_inItakuKaishaCd TEXT 		-- 委託会社コード
 ,l_inSdFlg TEXT 		-- ＳＤフラグ
 ) RETURNS integer AS $body$
DECLARE

  ora2pg_rowcount int;
--
--   * 著作権:Copyright(c)2017
--   * 会社名:JIP
--   * 概要　:事務代行手数料管理用データを更新する。
--   * 注意事項:当処理を実行する際は、当月分の事務代行手数料管理用データが存在することが前提となります。
--   *　　　　　毎営業日、当日の対象オペを BT31 明細WK に登録します。
--   *　　　　　月末営業日の場合のみ、当月分のBT31 明細WKの件数を集計し、事務代行手数料管理用データの件数に反映します。
--   * @author Y.Nagano
--   * @version $Id: SFIPX217K15R02_01.sql,v 1.00 2017.01.19 15:43:18 Y.Nagano Exp $
--   *
--   * @param    l_inItakuKaishaCd       IN  TEXT        委託会社コード
--   * @param    l_inSdFlg    	       IN  TEXT        ＳＤフラグ
--   *
--   * @return INTEGER 0:正常
--   *                99:異常、それ以外：エラー
--   
  --==============================================================================
  --                    定数定義                                                  
  --==============================================================================
	C_FUNCTION_ID  CONSTANT varchar(50) := 'SFIPX217K15R02_01';	-- ファンクションID
	-- 例外 
			-- 当月枠データなし
	-- 配列定義 
	gSbCbKbn varchar(2)[] := ARRAY['SB', 'CB'];
	gInsUser varchar(2)[] := ARRAY['1', '2'];
	-- 処理モード 
	C_SHORI_MODE_TOROKU		CONSTANT char(1)	:= '1';	-- 登録
	C_SHORI_MODE_TEISEI		CONSTANT char(1)	:= '2';	-- 訂正
	C_SHORI_MODE_TORIKESHI	CONSTANT char(1)	:= '3';	-- 取消
	-- 入力者 
	C_NYURYOKU_KBN_SD		CONSTANT char(1)	:= '1';	-- SD
	C_NYURYOKU_KBN_KO		CONSTANT char(1)	:= '2';	-- 顧客
  --==============================================================================
  --                    変数定義                                                  
  --==============================================================================
	gGyomuYmd				SSYSTEM_MANAGEMENT.GYOMU_YMD%type := NULL;		-- 業務日付
	gGetsumatsuBusinessYmd	SSYSTEM_MANAGEMENT.GYOMU_YMD%type := NULL;		-- 月末営業日
	gGyomuYm				varchar(6) := NULL;		 					-- 業務年月
	gSeqNo					numeric;												-- 連番カウント
	gRecKbn					varchar(2) := NULL;							-- レコード区分
  --==============================================================================
  --                    カーソル定義                                              
  --==============================================================================
	--
--	 * BT31 明細WK への登録データ取得
--	 
	-- 01_銘柄（他行引受あり）・02_銘柄（自行総額引受） 取得
	c01_02Mgr CURSOR FOR
		-- 登録
		SELECT
			 A1.ITAKU_KAISHA_CD
			,CASE WHEN A1.SAIKEN_SHURUI='80' THEN 'CB' WHEN A1.SAIKEN_SHURUI='89' THEN 'CB'  ELSE 'SB' END  AS SHASAI_KBN
			,CASE WHEN A1.JIKO_TOTAL_HKUK_KBN='1' THEN '02'  ELSE '01' END  AS REC_KBN
			,C1.SAKUSEI_ID AS I_USER_ID
			,C_SHORI_MODE_TOROKU AS SHORI_MODE
			,A1.MGR_CD
			,A1.ISIN_CD
		FROM
			 MGR_KIHON		A1
			,MGR_STS		B1
			,MGR_KIKO_KIHON	C1
		WHERE A1.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
		  AND TO_CHAR(C1.SAKUSEI_DT, 'YYYYMMDD') = gGyomuYmd 	-- 銘柄_機構基本 の作成日が本日
		  AND A1.ITAKU_KAISHA_CD	= B1.ITAKU_KAISHA_CD
		  AND A1.MGR_CD				= B1.MGR_CD
		  AND A1.ITAKU_KAISHA_CD	= C1.ITAKU_KAISHA_CD
		  AND A1.MGR_CD				= C1.MGR_CD
		  AND A1.JTK_KBN			<> '2'
		  AND coalesce(trim(both A1.DEFAULT_YMD)::text, '') = '' 		-- デフォルト登録オペは除外（31に計上）
		
UNION

		-- 訂正
		SELECT
			 A2.ITAKU_KAISHA_CD
			,CASE WHEN A2.SAIKEN_SHURUI='80' THEN 'CB' WHEN A2.SAIKEN_SHURUI='89' THEN 'CB'  ELSE 'SB' END  AS SHASAI_KBN
			,CASE WHEN A2.JIKO_TOTAL_HKUK_KBN='1' THEN '02'  ELSE '01' END  AS REC_KBN
			,B2.KOUSIN_ID AS I_USER_ID
			,C_SHORI_MODE_TEISEI AS SHORI_MODE
			,A2.MGR_CD
			,A2.ISIN_CD
		FROM
			 MGR_KIHON		A2
			,MGR_STS		B2
			,MGR_KIKO_KIHON	C2
		WHERE A2.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
		  AND TO_CHAR(C2.SAKUSEI_DT, 'YYYYMMDD') < gGyomuYmd 	-- 銘柄_機構基本 の作成日が本日より前
		  AND ( KIHON_TEISEI_YMD = gGyomuYmd 						-- 銘柄ステータス の基本訂正日が本日
		  OR RBR_KAIJI_TEISEI_YMD = gGyomuYmd 						-- 銘柄ステータス の利払回次訂正日が本日
		  OR SHOKAN_KAIJI_TEISEI_YMD = gGyomuYmd 					-- 銘柄ステータス の償還回次訂正日が本日
		  OR TESU_SET_TEISEI_YMD = gGyomuYmd 						-- 銘柄ステータス の手数料設定訂正日が本日
		  OR HKUK_KAISHA_TEISEI_YMD = gGyomuYmd 					-- 銘柄ステータス の引受会社訂正日が本日
		  OR HAKKO_TESU_TEISEI_YMD = gGyomuYmd 					-- 銘柄ステータス の発行時手数料訂正日が本日
		  OR KICHU_TESU_TEISEI_YMD = gGyomuYmd 					-- 銘柄ステータス の期中手数料訂正日が本日
		  OR KICHU_KAIJI_TEISEI_YMD = gGyomuYmd)					-- 銘柄ステータス の期中回次訂正日が本日
		  AND A2.ITAKU_KAISHA_CD	= B2.ITAKU_KAISHA_CD
		  AND A2.MGR_CD				= B2.MGR_CD
		  AND A2.ITAKU_KAISHA_CD	= C2.ITAKU_KAISHA_CD
		  AND A2.MGR_CD				= C2.MGR_CD
		  AND A2.JTK_KBN			<> '2'
		  AND B2.MASSHO_FLG			<> '1'		-- 抹消以外
		  AND coalesce(trim(both A2.DEFAULT_YMD)::text, '') = '' 		-- デフォルト登録オペは除外（31に計上）
 
		
UNION

		-- 取消
		SELECT
			 A3.ITAKU_KAISHA_CD
			,CASE WHEN A3.SAIKEN_SHURUI='80' THEN 'CB' WHEN A3.SAIKEN_SHURUI='89' THEN 'CB'  ELSE 'SB' END  AS SHASAI_KBN
			,CASE WHEN A3.JIKO_TOTAL_HKUK_KBN='1' THEN '02'  ELSE '01' END  AS REC_KBN
			,B3.KOUSIN_ID AS I_USER_ID
			,C_SHORI_MODE_TORIKESHI AS SHORI_MODE
			,A3.MGR_CD
			,A3.ISIN_CD
		FROM
			 MGR_KIHON		A3
			,MGR_STS		B3
			,MGR_KIKO_KIHON	C3
		WHERE A3.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
		  AND TO_CHAR(C3.SAKUSEI_DT, 'YYYYMMDD') < gGyomuYmd 	-- 銘柄_機構基本 の作成日が本日より前
		  AND TO_CHAR(B3.KOUSIN_DT,  'YYYYMMDD') = gGyomuYmd 	-- 銘柄ステータス の更新日が本日
		  AND A3.ITAKU_KAISHA_CD	= B3.ITAKU_KAISHA_CD
		  AND A3.MGR_CD				= B3.MGR_CD
		  AND A3.ITAKU_KAISHA_CD	= C3.ITAKU_KAISHA_CD
		  AND A3.MGR_CD				= C3.MGR_CD
		  AND A3.JTK_KBN			<> '2'
		  AND B3.MASSHO_FLG			= '1'		-- 抹消
		  AND coalesce(trim(both A3.DEFAULT_YMD)::text, '') = '' 		-- デフォルト登録オペは除外（31に計上）
 
	;
	-- 05_新規記録（他行引受DVP）、06_新規記録（他行引受非DVP）、07_新規記録（自行引受） 取得
	c05_07ShinkiKiroku CURSOR FOR
		-- SB代理人申請
		SELECT
			 A1.ITAKU_KAISHA_CD
			,'SB' AS SHASAI_KBN
			,CASE WHEN A1.FINANCIAL_SECURITIES_KBN || A1.BANK_CD=0 || A1.ITAKU_KAISHA_CD THEN  '07'  ELSE '06' END  AS REC_KBN
			,A1.KOUSIN_ID
			,A1.MGR_CD
			,B1.ISIN_CD
			,A1.FINANCIAL_SECURITIES_KBN 	--決済相手（上１）
			,A1.BANK_CD 						--決済相手（下４）
			,A1.KESSAI_NO
		FROM
			 SHINKIBOSHU	A1
			,MGR_KIHON		B1
		WHERE A1.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
		  AND B1.HAKKO_YMD			= gGyomuYmd
		  AND A1.ITAKU_KAISHA_CD	= B1.ITAKU_KAISHA_CD
		  AND A1.MGR_CD				= B1.MGR_CD
		  AND A1.DAIRI_MOTION_FLG	= '1'	-- 代理人直接申請である
		  AND A1.KK_PHASE			= 'H6'	-- 新規記録完了
		  AND A1.KK_STAT			= '04'
		
UNION

		--SB加入者申請
		SELECT
			 A2.ITAKU_KAISHA_CD
			,'SB' AS SHASAI_KBN
			,CASE WHEN C2.DVP_KBN='1' THEN '05'  ELSE '06' END  AS REC_KBN
			,B2.KOUSIN_ID
			,A2.MGR_CD
			,B2.ISIN_CD
			,A2.FINANCIAL_SECURITIES_KBN 	--決済相手（上１）
			,A2.BANK_CD 						--決済相手（下４）
			,A2.KESSAI_NO
		FROM
			 SHINKIBOSHU	A2
			,SHINKIKIROKU	B2
			,NYUKIN_YOTEI	C2
		WHERE A2.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
		  AND B2.KESSAI_YMD			= gGyomuYmd
		  AND A2.ITAKU_KAISHA_CD	= B2.ITAKU_KAISHA_CD
		  AND A2.KESSAI_NO			= B2.KESSAI_NO
		  AND A2.DAIRI_MOTION_FLG	= '0'	-- 加入者申請である
		  AND B2.KK_PHASE			= 'H6'	-- 新規記録完了
		  AND B2.KK_STAT			= '04'
		  AND A2.ITAKU_KAISHA_CD	= C2.ITAKU_KAISHA_CD
		  AND A2.KESSAI_NO			= C2.KESSAI_NO
		
UNION

		--CB加入者申請・代理人申請
		SELECT
			 A3.ITAKU_KAISHA_CD
			,'CB' AS SHASAI_KBN
			,CASE WHEN A3.FINANCIAL_SECURITIES_KBN || A3.BANK_CD=0 || A3.ITAKU_KAISHA_CD THEN  '07'  ELSE CASE WHEN B3.SKN_KESSAI_METHOD_CD_KYOTSU='DVPS' THEN '05'  ELSE '06' END  END  AS REC_KBN
			,A3.KOUSIN_ID
			,A3.MGR_CD
			,C3.ISIN_CD
			,A3.FINANCIAL_SECURITIES_KBN 	--決済相手（上１）
			,A3.BANK_CD 						--決済相手（下４）
			,A3.KESSAI_NO
		FROM
			 SHINKIBOSHU			A3
			,CB_SHNKKIROKU_KEKKA	B3
			,MGR_KIHON				C3
		WHERE A3.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
		  AND C3.HAKKO_YMD			= gGyomuYmd
		  AND A3.ITAKU_KAISHA_CD	= B3.ITAKU_KAISHA_CD
		  AND A3.MGR_CD				= B3.MGR_CD
		  AND A3.MGR_MEISAI_NO		= B3.MGR_MEISAI_NO
		  AND A3.ITAKU_KAISHA_CD	= C3.ITAKU_KAISHA_CD
		  AND A3.MGR_CD				= C3.MGR_CD
		  AND A3.KK_PHASE			= 'C2'	-- 新規記録結果登録完了
		  AND A3.KK_STAT			= '02'
	;
	-- 08〜16_支払登録情報 取得
	c08_16ShrInfo CURSOR FOR
		--0000564（FLG64=1）
		SELECT
			 A1.ITAKU_KAISHA_CD
			,A1.MGR_CD
			,B1.ISIN_CD
			,A1.SHR_YMD
			,A1.FINANCIAL_SECURITIES_KBN
			,A1.BANK_CD
			,A1.KK_KANYO_UMU_FLG
			,'1' AS FLG64
			,CASE WHEN SUM(A1.SHOKAN_SEIKYU_KNGK)=0 THEN CASE WHEN SUM(A1.GZEIHIKI_BEF_CHOKYU_KNGK)=0 THEN '00'  ELSE '01' END   ELSE CASE WHEN SUM(A1.GZEIHIKI_BEF_CHOKYU_KNGK)=0 THEN '10'  ELSE '11' END  END  AS GANRI_UMU
			,CASE WHEN B1.SAIKEN_SHURUI='80' THEN 'CB' WHEN B1.SAIKEN_SHURUI='89' THEN 'CB'  ELSE 'SB' END  AS SHASAI_KBN
			,A1.KOUSIN_ID
		FROM
			 KIKIN_SEIKYU	A1
			,MGR_KIHON		B1
		WHERE A1.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
		  AND A1.SHR_YMD			= gGyomuYmd
		  AND A1.ITAKU_KAISHA_CD	= B1.ITAKU_KAISHA_CD
		  AND A1.MGR_CD				= B1.MGR_CD
		  AND (A1.FINANCIAL_SECURITIES_KBN = '0' AND A1.BANK_CD = '0005' AND A1.KOZA_KBN = '64')	--機構加入者コード='0000564'である事
		  AND (A1.SHOKAN_SEIKYU_KNGK <> 0 OR A1.GZEIHIKI_BEF_CHOKYU_KNGK <> 0)						--元利金いずれか一方が0でない事
		GROUP BY
			 A1.ITAKU_KAISHA_CD
			,A1.MGR_CD
			,B1.ISIN_CD
			,A1.SHR_YMD
			,A1.FINANCIAL_SECURITIES_KBN
			,A1.BANK_CD
			,A1.KK_KANYO_UMU_FLG
			,B1.SAIKEN_SHURUI
			,A1.KOUSIN_ID
		
UNION

		--0000564以外（FLG64=0）
		SELECT
			 A2.ITAKU_KAISHA_CD
			,A2.MGR_CD
			,B2.ISIN_CD
			,A2.SHR_YMD
			,A2.FINANCIAL_SECURITIES_KBN
			,A2.BANK_CD
			,A2.KK_KANYO_UMU_FLG
			,'0' AS FLG64
			,CASE WHEN SUM(A2.SHOKAN_SEIKYU_KNGK)=0 THEN CASE WHEN SUM(A2.GZEIHIKI_BEF_CHOKYU_KNGK)=0 THEN '00'  ELSE '01' END   ELSE CASE WHEN SUM(A2.GZEIHIKI_BEF_CHOKYU_KNGK)=0 THEN '10'  ELSE '11' END  END  AS GANRI_UMU
			,CASE WHEN B2.SAIKEN_SHURUI='80' THEN 'CB' WHEN B2.SAIKEN_SHURUI='89' THEN 'CB'  ELSE 'SB' END  AS SHASAI_KBN
			,A2.KOUSIN_ID
		FROM
			 KIKIN_SEIKYU	A2
			,MGR_KIHON		B2
		WHERE A2.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
		  AND A2.SHR_YMD			= gGyomuYmd
		  AND A2.ITAKU_KAISHA_CD	= B2.ITAKU_KAISHA_CD
		  AND A2.MGR_CD				= B2.MGR_CD
		  AND NOT (A2.FINANCIAL_SECURITIES_KBN = '0' AND A2.BANK_CD = '0005' AND A2.KOZA_KBN = '64')	--機構加入者コード='0000564'以外である事
		  AND (A2.SHOKAN_SEIKYU_KNGK <> 0 OR A2.GZEIHIKI_BEF_CHOKYU_KNGK <> 0)							--元利金いずれか一方が0でない事
 
		GROUP BY
			 A2.ITAKU_KAISHA_CD
			,A2.MGR_CD
			,B2.ISIN_CD
			,A2.SHR_YMD
			,A2.FINANCIAL_SECURITIES_KBN
			,A2.BANK_CD
			,A2.KK_KANYO_UMU_FLG
			,B2.SAIKEN_SHURUI
			,A2.KOUSIN_ID
	;
	-- 03_変動利率 取得
	c03HendoRiritu CURSOR FOR
		-- 期中銘柄変更（利払）登録
		SELECT
			 A1.ITAKU_KAISHA_CD
			,A1.MGR_CD
			,B1.ISIN_CD
			,A1.SHR_KJT
			,CASE WHEN B1.SAIKEN_SHURUI='80' THEN 'CB' WHEN B1.SAIKEN_SHURUI='89' THEN 'CB'  ELSE 'SB' END  AS SHASAI_KBN
			,C_SHORI_MODE_TOROKU AS SHORI_MODE
			,A1.KOUSIN_ID
		FROM
			 UPD_MGR_RBR	A1
			,MGR_KIHON		B1
		WHERE A1.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
		  AND TO_CHAR(A1.KOUSIN_DT, 'YYYYMMDD') = gGyomuYmd
		  AND A1.ITAKU_KAISHA_CD	= B1.ITAKU_KAISHA_CD
		  AND A1.MGR_CD				= B1.MGR_CD
		  AND A1.KK_PHASE			= 'M2'
		  AND A1.KK_STAT			= '04'
		  AND (SELECT COUNT(*)	-- 変更履歴 同一キー（委託会社、銘柄、支払期日、銘柄変更区分）にて、更新日が単一の場合：登録
				FROM
					(SELECT
						 ITAKU_KAISHA_CD
						,MGR_CD
						,SHR_KJT
						,MGR_HENKO_KBN
						,TO_CHAR(KOUSIN_DT, 'YYYYMMDD')
					FROM UPD_MGR_RBR_RIREKI
					GROUP BY
						 ITAKU_KAISHA_CD
						,MGR_CD
						,SHR_KJT
						,MGR_HENKO_KBN
						,TO_CHAR(KOUSIN_DT, 'YYYYMMDD') 
					) alias4 
				WHERE ITAKU_KAISHA_CD	= A1.ITAKU_KAISHA_CD
				  AND MGR_CD			= A1.MGR_CD
				  AND SHR_KJT			= A1.SHR_KJT
				  AND MGR_HENKO_KBN		= A1.MGR_HENKO_KBN
				GROUP BY
					 ITAKU_KAISHA_CD
					,MGR_CD
					,SHR_KJT
					,MGR_HENKO_KBN
			) = 1 
		
UNION

		-- 期中銘柄変更（利払）訂正
		SELECT
			 A2.ITAKU_KAISHA_CD
			,A2.MGR_CD
			,B2.ISIN_CD
			,A2.SHR_KJT
			,CASE WHEN B2.SAIKEN_SHURUI='80' THEN 'CB' WHEN B2.SAIKEN_SHURUI='89' THEN 'CB'  ELSE 'SB' END  AS SHASAI_KBN
			,C_SHORI_MODE_TEISEI AS SHORI_MODE
			,A2.KOUSIN_ID
		FROM
			 UPD_MGR_RBR	A2
			,MGR_KIHON		B2
		WHERE A2.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
		  AND TO_CHAR(A2.KOUSIN_DT, 'YYYYMMDD') = gGyomuYmd
		  AND A2.ITAKU_KAISHA_CD	= B2.ITAKU_KAISHA_CD
		  AND A2.MGR_CD				= B2.MGR_CD
		  AND A2.KK_PHASE			= 'M2'
		  AND A2.KK_STAT			= '04'
		  AND (SELECT COUNT(*)	-- 変更履歴 同一キー（委託会社、銘柄、支払期日、銘柄変更区分）にて、更新日が複数日ある場合：訂正
				FROM 
					(SELECT
						 ITAKU_KAISHA_CD
						,MGR_CD
						,SHR_KJT
						,MGR_HENKO_KBN
						,TO_CHAR(KOUSIN_DT, 'YYYYMMDD')
					FROM UPD_MGR_RBR_RIREKI
					GROUP BY
						 ITAKU_KAISHA_CD
						,MGR_CD
						,SHR_KJT
						,MGR_HENKO_KBN
						,TO_CHAR(KOUSIN_DT, 'YYYYMMDD') 
					) alias10 
				WHERE ITAKU_KAISHA_CD	= A2.ITAKU_KAISHA_CD
				  AND MGR_CD			= A2.MGR_CD
				  AND SHR_KJT			= A2.SHR_KJT
				  AND MGR_HENKO_KBN		= A2.MGR_HENKO_KBN
				GROUP BY
					 ITAKU_KAISHA_CD
					,MGR_CD
					,SHR_KJT
					,MGR_HENKO_KBN
			) > 1 
	;
	-- 04、20〜24_期中銘柄変更（償還）情報 取得
	c04UpdShokan CURSOR FOR
		-- 期中銘柄変更（償還）登録
		SELECT
			 A3.ITAKU_KAISHA_CD
			,A3.MGR_CD
			,B3.ISIN_CD
			,A3.SHR_KJT
			,CASE WHEN B3.SAIKEN_SHURUI='80' THEN 'CB' WHEN B3.SAIKEN_SHURUI='89' THEN 'CB'  ELSE 'SB' END  AS SHASAI_KBN
			,C_SHORI_MODE_TOROKU AS SHORI_MODE
			,CASE WHEN A3.MGR_HENKO_KBN='21' THEN '04' WHEN A3.MGR_HENKO_KBN='30' THEN '22' WHEN A3.MGR_HENKO_KBN='40' THEN '20' WHEN A3.MGR_HENKO_KBN='41' THEN '21' WHEN A3.MGR_HENKO_KBN='50' THEN '23'  ELSE '24' END  AS REC_KBN
			,A3.KOUSIN_ID
		FROM
			 UPD_MGR_SHN	A3
			,MGR_KIHON		B3
		WHERE A3.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
		  AND TO_CHAR(A3.KOUSIN_DT, 'YYYYMMDD') = gGyomuYmd
		  AND A3.ITAKU_KAISHA_CD	= B3.ITAKU_KAISHA_CD
		  AND A3.MGR_CD				= B3.MGR_CD
		  AND A3.KK_PHASE			= 'M2'
		  AND A3.KK_STAT			= '04'
		  AND (SELECT COUNT(*)	-- 変更履歴 同一キー（委託会社、銘柄、支払期日、銘柄変更区分）にて、更新日が単一の場合：登録
				FROM
					(SELECT
						 ITAKU_KAISHA_CD
						,MGR_CD
						,SHR_KJT
						,MGR_HENKO_KBN
						,TO_CHAR(KOUSIN_DT, 'YYYYMMDD')
					FROM UPD_MGR_SHN_RIREKI
					GROUP BY
						 ITAKU_KAISHA_CD
						,MGR_CD
						,SHR_KJT
						,MGR_HENKO_KBN
						,TO_CHAR(KOUSIN_DT, 'YYYYMMDD') 
					) alias4 
				WHERE ITAKU_KAISHA_CD	= A3.ITAKU_KAISHA_CD
				  AND MGR_CD			= A3.MGR_CD
				  AND SHR_KJT			= A3.SHR_KJT
				  AND MGR_HENKO_KBN		= A3.MGR_HENKO_KBN
				GROUP BY
					 ITAKU_KAISHA_CD
					,MGR_CD
					,SHR_KJT
					,MGR_HENKO_KBN
			) = 1 
		
UNION

		-- 期中銘柄変更（償還）訂正
		SELECT
			 A4.ITAKU_KAISHA_CD
			,A4.MGR_CD
			,B4.ISIN_CD
			,A4.SHR_KJT
			,CASE WHEN B4.SAIKEN_SHURUI='80' THEN 'CB' WHEN B4.SAIKEN_SHURUI='89' THEN 'CB'  ELSE 'SB' END  AS SHASAI_KBN
			,C_SHORI_MODE_TEISEI AS SHORI_MODE
			,CASE WHEN A4.MGR_HENKO_KBN='21' THEN '04' WHEN A4.MGR_HENKO_KBN='30' THEN '22' WHEN A4.MGR_HENKO_KBN='40' THEN '20' WHEN A4.MGR_HENKO_KBN='41' THEN '21' WHEN A4.MGR_HENKO_KBN='50' THEN '23'  ELSE '24' END  AS REC_KBN
			,A4.KOUSIN_ID
		FROM
			 UPD_MGR_SHN	A4
			,MGR_KIHON		B4
		WHERE A4.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
		  AND TO_CHAR(A4.KOUSIN_DT,'YYYYMMDD') = gGyomuYmd
		  AND A4.ITAKU_KAISHA_CD	= B4.ITAKU_KAISHA_CD
		  AND A4.MGR_CD				= B4.MGR_CD
		  AND A4.KK_PHASE			= 'M2'
		  AND A4.KK_STAT			= '04'
		  AND (SELECT COUNT(*)	-- 変更履歴 同一キー（委託会社、銘柄、支払期日、銘柄変更区分）にて、更新日が複数日ある場合：訂正
				FROM 
					(SELECT
						 ITAKU_KAISHA_CD
						,MGR_CD
						,SHR_KJT
						,MGR_HENKO_KBN
						,TO_CHAR(KOUSIN_DT, 'YYYYMMDD')
					FROM UPD_MGR_SHN_RIREKI
					GROUP BY
						 ITAKU_KAISHA_CD
						,MGR_CD
						,SHR_KJT
						,MGR_HENKO_KBN
						,TO_CHAR(KOUSIN_DT, 'YYYYMMDD') 
					) alias10 
				WHERE ITAKU_KAISHA_CD	= A4.ITAKU_KAISHA_CD
				  AND MGR_CD			= A4.MGR_CD
				  AND SHR_KJT			= A4.SHR_KJT
				  AND MGR_HENKO_KBN		= A4.MGR_HENKO_KBN
				GROUP BY
					 ITAKU_KAISHA_CD
					,MGR_CD
					,SHR_KJT
					,MGR_HENKO_KBN
			) > 1 
	;
	-- 25〜27_期中銘柄情報 取得
	c25_27UpdMgr CURSOR FOR
		-- 25_海外カレンダ 登録
		SELECT
			 A1.ITAKU_KAISHA_CD
			,A1.MGR_CD
			,B1.ISIN_CD
			,A1.KOUSIN_ID
			,A1.SHR_KJT
			,C_SHORI_MODE_TOROKU AS SHORI_MODE
			,'25' AS REC_KBN
		FROM
			 UPD_MGR_KHN	A1
			,MGR_KIHON		B1
		WHERE A1.ITAKU_KAISHA_CD		= l_inItakuKaishaCd
		  AND TO_CHAR(A1.KOUSIN_DT, 'YYYYMMDD') = gGyomuYmd
		  AND A1.ITAKU_KAISHA_CD		= B1.ITAKU_KAISHA_CD
		  AND A1.MGR_CD					= B1.MGR_CD
		  AND B1.SAIKEN_SHURUI			NOT IN ('80', '89')
		  AND A1.KM_ETCKAIGAI_CHKFLG	= '1'	-- 期中銘柄その他海外チェックフラグ：ON
		  AND A1.KK_PHASE				= 'M2'
		  AND A1.KK_STAT				= '04'
		  AND (SELECT COUNT(*)	-- 変更履歴 同一キー（委託会社、銘柄、支払期日、銘柄変更区分、チェックフラグ）にて、更新日が単一の場合：登録
				FROM
					(SELECT
						 ITAKU_KAISHA_CD
						,MGR_CD
						,SHR_KJT
						,MGR_HENKO_KBN
						,KM_ETCKAIGAI_CHKFLG
						,TO_CHAR(KOUSIN_DT, 'YYYYMMDD')
					FROM UPD_MGR_KHN_RIREKI
					GROUP BY
						 ITAKU_KAISHA_CD
						,MGR_CD
						,SHR_KJT
						,MGR_HENKO_KBN
						,KM_ETCKAIGAI_CHKFLG
						,TO_CHAR(KOUSIN_DT, 'YYYYMMDD') 
					) alias5 
				WHERE ITAKU_KAISHA_CD		= A1.ITAKU_KAISHA_CD
				  AND MGR_CD				= A1.MGR_CD
				  AND SHR_KJT				= A1.SHR_KJT
				  AND MGR_HENKO_KBN			= A1.MGR_HENKO_KBN
				  AND KM_ETCKAIGAI_CHKFLG	= A1.KM_ETCKAIGAI_CHKFLG
				GROUP BY
					 ITAKU_KAISHA_CD
					,MGR_CD
					,SHR_KJT
					,MGR_HENKO_KBN
					,KM_ETCKAIGAI_CHKFLG
			) = '1' 
		
UNION

		-- 25_海外カレンダ 訂正
		SELECT
			 A2.ITAKU_KAISHA_CD
			,A2.MGR_CD
			,B2.ISIN_CD
			,A2.KOUSIN_ID
			,A2.SHR_KJT
			,C_SHORI_MODE_TEISEI AS SHORI_MODE
			,'25' AS REC_KBN
		FROM
			 UPD_MGR_KHN	A2
			,MGR_KIHON		B2
		WHERE A2.ITAKU_KAISHA_CD		= l_inItakuKaishaCd
		  AND TO_CHAR(A2.KOUSIN_DT, 'YYYYMMDD') = gGyomuYmd
		  AND A2.ITAKU_KAISHA_CD		= B2.ITAKU_KAISHA_CD
		  AND A2.MGR_CD					= B2.MGR_CD
		  AND B2.SAIKEN_SHURUI			NOT IN ('80', '89')
		  AND A2.KM_ETCKAIGAI_CHKFLG	= '1'	-- 期中銘柄その他海外チェックフラグ：ON
		  AND A2.KK_PHASE				= 'M2'
		  AND A2.KK_STAT				= '04'
		  AND (SELECT COUNT(*)	-- 変更履歴 同一キー（委託会社、銘柄、支払期日、銘柄変更区分、チェックフラグ）にて、更新日が複数日ある場合：訂正
				FROM 
					(SELECT
						 ITAKU_KAISHA_CD
						,MGR_CD
						,SHR_KJT
						,MGR_HENKO_KBN
						,KM_ETCKAIGAI_CHKFLG
						,TO_CHAR(KOUSIN_DT, 'YYYYMMDD')
					FROM UPD_MGR_KHN_RIREKI
					GROUP BY
						 ITAKU_KAISHA_CD
						,MGR_CD
						,SHR_KJT
						,MGR_HENKO_KBN
						,KM_ETCKAIGAI_CHKFLG
						,TO_CHAR(KOUSIN_DT, 'YYYYMMDD') 
					) alias12 
				WHERE ITAKU_KAISHA_CD		= A2.ITAKU_KAISHA_CD
				  AND MGR_CD				= A2.MGR_CD
				  AND SHR_KJT				= A2.SHR_KJT
				  AND MGR_HENKO_KBN			= A2.MGR_HENKO_KBN
				  AND KM_ETCKAIGAI_CHKFLG	= A2.KM_ETCKAIGAI_CHKFLG
				GROUP BY
					 ITAKU_KAISHA_CD
					,MGR_CD
					,SHR_KJT
					,MGR_HENKO_KBN
					,KM_ETCKAIGAI_CHKFLG
			) > '1' 
		
UNION

		-- 26_機構関与方式採用フラグ 登録
		SELECT
			 A3.ITAKU_KAISHA_CD
			,A3.MGR_CD
			,B3.ISIN_CD
			,A3.KOUSIN_ID
			,A3.SHR_KJT
			,C_SHORI_MODE_TOROKU AS SHORI_MODE
			,'26' AS REC_KBN
		FROM
			 UPD_MGR_KHN	A3
			,MGR_KIHON		B3
		WHERE A3.ITAKU_KAISHA_CD		= l_inItakuKaishaCd
		  AND TO_CHAR(A3.KOUSIN_DT, 'YYYYMMDD') = gGyomuYmd
		  AND A3.ITAKU_KAISHA_CD		= B3.ITAKU_KAISHA_CD
		  AND A3.MGR_CD					= B3.MGR_CD
		  AND B3.SAIKEN_SHURUI			NOT IN ('80', '89')
		  AND A3.KM_KK_KANYO_CHKFLG		= '1'	-- 期中銘柄機構関与チェックフラグ：ON
		  AND A3.KK_PHASE				= 'M2'
		  AND A3.KK_STAT				= '04'
		  AND (SELECT COUNT(*)	-- 変更履歴 同一キー（委託会社、銘柄、支払期日、銘柄変更区分、チェックフラグ）にて、更新日が単一の場合：登録
				FROM 
					(SELECT
						 ITAKU_KAISHA_CD
						,MGR_CD
						,SHR_KJT
						,MGR_HENKO_KBN
						,KM_KK_KANYO_CHKFLG
						,TO_CHAR(KOUSIN_DT, 'YYYYMMDD')
					FROM UPD_MGR_KHN_RIREKI
					GROUP BY
						 ITAKU_KAISHA_CD
						,MGR_CD
						,SHR_KJT
						,MGR_HENKO_KBN
						,KM_KK_KANYO_CHKFLG
						,TO_CHAR(KOUSIN_DT, 'YYYYMMDD') 
					) alias19 
				WHERE ITAKU_KAISHA_CD		= A3.ITAKU_KAISHA_CD
				  AND MGR_CD				= A3.MGR_CD
				  AND SHR_KJT				= A3.SHR_KJT
				  AND MGR_HENKO_KBN			= A3.MGR_HENKO_KBN
				  AND KM_KK_KANYO_CHKFLG	= A3.KM_KK_KANYO_CHKFLG
				GROUP BY
					 ITAKU_KAISHA_CD
					,MGR_CD
					,SHR_KJT
					,MGR_HENKO_KBN
					,KM_KK_KANYO_CHKFLG
			) = '1' 
		
UNION

		-- 26_機構関与方式採用フラグ 訂正
		SELECT
			 A4.ITAKU_KAISHA_CD
			,A4.MGR_CD
			,B4.ISIN_CD
			,A4.KOUSIN_ID
			,A4.SHR_KJT
			,C_SHORI_MODE_TEISEI AS SHORI_MODE
			,'26' AS REC_KBN
		FROM
			 UPD_MGR_KHN	A4
			,MGR_KIHON		B4
		WHERE A4.ITAKU_KAISHA_CD		= l_inItakuKaishaCd
		  AND TO_CHAR(A4.KOUSIN_DT, 'YYYYMMDD') = gGyomuYmd
		  AND A4.ITAKU_KAISHA_CD		= B4.ITAKU_KAISHA_CD
		  AND A4.MGR_CD					= B4.MGR_CD
		  AND B4.SAIKEN_SHURUI			NOT IN ('80', '89')
		  AND A4.KM_KK_KANYO_CHKFLG		= '1'	-- 期中銘柄機構関与チェックフラグ：ON
		  AND A4.KK_PHASE				= 'M2'
		  AND A4.KK_STAT				= '04'
		  AND (SELECT COUNT(*)	-- 変更履歴 同一キー（委託会社、銘柄、支払期日、銘柄変更区分、チェックフラグ）にて、更新日が複数日ある場合：訂正
				FROM 
					(SELECT
						 ITAKU_KAISHA_CD
						,MGR_CD
						,SHR_KJT
						,MGR_HENKO_KBN
						,KM_KK_KANYO_CHKFLG
						,TO_CHAR(KOUSIN_DT, 'YYYYMMDD')
					FROM UPD_MGR_KHN_RIREKI
					GROUP BY
						 ITAKU_KAISHA_CD
						,MGR_CD
						,SHR_KJT
						,MGR_HENKO_KBN
						,KM_KK_KANYO_CHKFLG
						,TO_CHAR(KOUSIN_DT, 'YYYYMMDD') 
					) alias26 
				WHERE ITAKU_KAISHA_CD		= A4.ITAKU_KAISHA_CD
				  AND MGR_CD				= A4.MGR_CD
				  AND SHR_KJT				= A4.SHR_KJT
				  AND MGR_HENKO_KBN			= A4.MGR_HENKO_KBN
				  AND KM_KK_KANYO_CHKFLG	= A4.KM_KK_KANYO_CHKFLG
				GROUP BY
					 ITAKU_KAISHA_CD
					,MGR_CD
					,SHR_KJT
					,MGR_HENKO_KBN
					,KM_KK_KANYO_CHKFLG
			) > '1' 
		
UNION

		-- 27_個別承認採用フラグ 登録
		SELECT
			 A5.ITAKU_KAISHA_CD
			,A5.MGR_CD
			,B5.ISIN_CD
			,A5.KOUSIN_ID
			,A5.SHR_KJT
			,C_SHORI_MODE_TOROKU AS SHORI_MODE
			,'27' AS REC_KBN
		FROM
			 UPD_MGR_KHN	A5
			,MGR_KIHON		B5
		WHERE A5.ITAKU_KAISHA_CD		= l_inItakuKaishaCd
		  AND TO_CHAR(A5.KOUSIN_DT, 'YYYYMMDD') = gGyomuYmd
		  AND A5.ITAKU_KAISHA_CD		= B5.ITAKU_KAISHA_CD
		  AND A5.MGR_CD					= B5.MGR_CD
		  AND B5.SAIKEN_SHURUI			NOT IN ('80', '89')
		  AND A5.KM_KOBETSU_CHKFLG		= '1'	-- 期中銘柄個別承認チェックフラグ：ON
		  AND A5.KK_PHASE				= 'M2'
		  AND A5.KK_STAT				= '04'
		  AND (SELECT COUNT(*)	-- 変更履歴 同一キー（委託会社、銘柄、支払期日、銘柄変更区分、チェックフラグ）にて、更新日が単一の場合：登録
				FROM 
					(SELECT
						 ITAKU_KAISHA_CD
						,MGR_CD
						,SHR_KJT
						,MGR_HENKO_KBN
						,KM_KOBETSU_CHKFLG
						,TO_CHAR(KOUSIN_DT, 'YYYYMMDD')
					FROM UPD_MGR_KHN_RIREKI
					GROUP BY
						 ITAKU_KAISHA_CD
						,MGR_CD
						,SHR_KJT
						,MGR_HENKO_KBN
						,KM_KOBETSU_CHKFLG
						,TO_CHAR(KOUSIN_DT, 'YYYYMMDD') 
					) alias33 
				WHERE ITAKU_KAISHA_CD		= A5.ITAKU_KAISHA_CD
				  AND MGR_CD				= A5.MGR_CD
				  AND SHR_KJT				= A5.SHR_KJT
				  AND MGR_HENKO_KBN			= A5.MGR_HENKO_KBN
				  AND KM_KOBETSU_CHKFLG		= A5.KM_KOBETSU_CHKFLG
				GROUP BY
					 ITAKU_KAISHA_CD
					,MGR_CD
					,SHR_KJT
					,MGR_HENKO_KBN
					,KM_KOBETSU_CHKFLG
			) = '1' 
		
UNION

		-- 27_個別承認採用フラグ 訂正
		SELECT
			 A6.ITAKU_KAISHA_CD
			,A6.MGR_CD
			,B6.ISIN_CD
			,A6.KOUSIN_ID
			,A6.SHR_KJT
			,C_SHORI_MODE_TEISEI AS SHORI_MODE
			,'27' AS REC_KBN
		FROM
			 UPD_MGR_KHN	A6
			,MGR_KIHON		B6
		WHERE A6.ITAKU_KAISHA_CD		= l_inItakuKaishaCd
		  AND TO_CHAR(A6.KOUSIN_DT, 'YYYYMMDD') = gGyomuYmd
		  AND A6.ITAKU_KAISHA_CD		= B6.ITAKU_KAISHA_CD
		  AND A6.MGR_CD					= B6.MGR_CD
		  AND B6.SAIKEN_SHURUI			NOT IN ('80', '89')
		  AND A6.KM_KOBETSU_CHKFLG		= '1'	-- 期中銘柄個別承認チェックフラグ：ON
		  AND A6.KK_PHASE				= 'M2'
		  AND A6.KK_STAT				= '04'
		  AND (SELECT COUNT(*)	-- 変更履歴 同一キー（委託会社、銘柄、支払期日、銘柄変更区分、チェックフラグ）にて、更新日が複数日ある場合：訂正
				FROM 
					(SELECT
						 ITAKU_KAISHA_CD
						,MGR_CD
						,SHR_KJT
						,MGR_HENKO_KBN
						,KM_KOBETSU_CHKFLG
						,TO_CHAR(KOUSIN_DT, 'YYYYMMDD')
					FROM UPD_MGR_KHN_RIREKI
					GROUP BY
						 ITAKU_KAISHA_CD
						,MGR_CD
						,SHR_KJT
						,MGR_HENKO_KBN
						,KM_KOBETSU_CHKFLG
						,TO_CHAR(KOUSIN_DT, 'YYYYMMDD') 
					) alias40 
				WHERE ITAKU_KAISHA_CD		= A6.ITAKU_KAISHA_CD
				  AND MGR_CD				= A6.MGR_CD
				  AND SHR_KJT				= A6.SHR_KJT
				  AND MGR_HENKO_KBN			= A6.MGR_HENKO_KBN
				  AND KM_KOBETSU_CHKFLG		= A6.KM_KOBETSU_CHKFLG
				GROUP BY
					 ITAKU_KAISHA_CD
					,MGR_CD
					,SHR_KJT
					,MGR_HENKO_KBN
					,KM_KOBETSU_CHKFLG
			) > '1' 
	;
	-- 28_期中銘柄情報（ＣＢ銘柄） 取得
	c28CBMeigaraInfo CURSOR FOR
		-- 登録
		SELECT
			 A1.ITAKU_KAISHA_CD
			,C_SHORI_MODE_TOROKU AS SHORI_MODE
			,A1.KOUSIN_ID
			,A1.MGR_CD
			,A1.ISIN_CD
			,A1.TEKIYOST_YMD
		FROM
			CB_MGR_KHN_RUISEKI A1
		WHERE A1.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
		  AND A1.KK_TSUCHI_YMD		= gGyomuYmd
		  AND A1.KK_PHASE			= 'M2'
		  AND A1.KK_STAT			= '04'
		  AND (SELECT COUNT(*)	-- 変更履歴 同一キー（委託会社、銘柄、機構通知日）にて、更新日が単一の場合：登録
				FROM
					(SELECT
						 ITAKU_KAISHA_CD
						,MGR_CD
						,TEKIYOST_YMD
						,TO_CHAR(KOUSIN_DT, 'YYYYMMDD')
					FROM CB_MGR_KHN_RUISEKI_RIREKI
					GROUP BY
						 ITAKU_KAISHA_CD
						,MGR_CD
						,TEKIYOST_YMD
						,TO_CHAR(KOUSIN_DT, 'YYYYMMDD') 
					) alias3 
				WHERE ITAKU_KAISHA_CD	= A1.ITAKU_KAISHA_CD
				  AND MGR_CD			= A1.MGR_CD
				  AND TEKIYOST_YMD		= A1.TEKIYOST_YMD
				GROUP BY
					 ITAKU_KAISHA_CD
					,MGR_CD
					,TEKIYOST_YMD
			) = 1 
		
UNION

		-- 訂正
		SELECT
			 A2.ITAKU_KAISHA_CD
			,C_SHORI_MODE_TEISEI AS SHORI_MODE
			,A2.KOUSIN_ID
			,A2.MGR_CD
			,A2.ISIN_CD
			,A2.TEKIYOST_YMD
		FROM
			CB_MGR_KHN_RUISEKI A2
		WHERE A2.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
		  AND A2.KK_TSUCHI_YMD		= gGyomuYmd
		  AND A2.KK_PHASE			= 'M2'
		  AND A2.KK_STAT			= '04'
		  AND (SELECT COUNT(*)	-- 変更履歴 同一キー（委託会社、銘柄、機構通知日）にて、更新日が複数日ある場合：訂正
				FROM 
					(SELECT
						 ITAKU_KAISHA_CD
						,MGR_CD
						,TEKIYOST_YMD
						,TO_CHAR(KOUSIN_DT, 'YYYYMMDD')
					FROM CB_MGR_KHN_RUISEKI_RIREKI
					GROUP BY
						 ITAKU_KAISHA_CD
						,MGR_CD
						,TEKIYOST_YMD
						,TO_CHAR(KOUSIN_DT, 'YYYYMMDD') 
					) alias8 
				WHERE ITAKU_KAISHA_CD	= A2.ITAKU_KAISHA_CD
				  AND MGR_CD			= A2.MGR_CD
				  AND TEKIYOST_YMD		= A2.TEKIYOST_YMD
				GROUP BY
					 ITAKU_KAISHA_CD
					,MGR_CD
					,TEKIYOST_YMD
			) > 1 
	;
	-- 29_新株予約権行使（ＣＢ銘柄） 取得
	c29ShinkabuYoyaku CURSOR FOR
		SELECT
			 MG3.ITAKU_KAISHA_CD
			,MG3.KOUSIN_ID
			,MG3.MGR_CD
			,MG1.ISIN_CD
			,MG3.SHOKAN_YMD
		FROM
			 MGR_KIHON MG1
			,MGR_SHOKIJ MG3
		WHERE MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		  AND MG3.SHOKAN_YMD = gGyomuYmd
		  AND MG3.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
		  AND MG3.MGR_CD = MG1.MGR_CD
		  AND MG1.SAIKEN_SHURUI IN ('80', '89')
		  AND MG3.SHOKAN_KBN = '60'		-- 新株予約権行使
	;
	-- 30_差押情報 取得
	c30Sashiosae CURSOR FOR
		SELECT
			 K04.ITAKU_KAISHA_CD
			,CASE WHEN MG1.SAIKEN_SHURUI='80' THEN 'CB' WHEN MG1.SAIKEN_SHURUI='89' THEN 'CB'  ELSE 'SB' END  AS SHASAI_KBN
			,K04.KOUSIN_ID
			,K04.MGR_CD
			,MG1.ISIN_CD
			,K04.OSAESETTEI_YMD
			,K04.OSAE_KBN
		FROM
			 MGR_KIHON MG1
			,SASHIOSAE K04
		WHERE K04.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
		  AND TO_CHAR(K04.SAKUSEI_DT, 'YYYYMMDD') = gGyomuYmd
		  AND K04.ITAKU_KAISHA_CD	= MG1.ITAKU_KAISHA_CD
		  AND K04.MGR_CD			= MG1.MGR_CD
		  AND K04.SHORI_KBN			= '1'
	;
	-- 31_デフォルト情報 取得
	c31Defalt CURSOR FOR
		SELECT
			 DE01.ITAKU_KAISHA_CD
			,CASE WHEN MG1.SAIKEN_SHURUI='80' THEN 'CB' WHEN MG1.SAIKEN_SHURUI='89' THEN 'CB'  ELSE 'SB' END  AS SHASAI_KBN
			,DE01.KOUSIN_ID
			,DE01.MGR_CD
			,MG1.ISIN_CD
		FROM
			 MGR_KIHON MG1
			,DEFAULT_INFO DE01
		WHERE DE01.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
		  AND TO_CHAR(DE01.SAKUSEI_DT, 'YYYYMMDD') = gGyomuYmd
		  AND DE01.ITAKU_KAISHA_CD	= MG1.ITAKU_KAISHA_CD
		  AND DE01.MGR_CD			= MG1.MGR_CD
		  AND DE01.SHORI_KBN		= '1'
	;
	-- 32_発行体情報 取得
	c32Hakkotai CURSOR FOR
		SELECT
			 M01.ITAKU_KAISHA_CD
			,M01.HKT_CD
			,M01.KOUSIN_ID
		FROM
			MHAKKOTAI M01
		WHERE M01.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
		  AND TO_CHAR(M01.SAKUSEI_DT, 'YYYYMMDD')	= gGyomuYmd
		  AND M01.SHORI_KBN			= '1'
	;
	-- 33_副受託銘柄情報 取得
	c33Fukujutaku CURSOR FOR
		SELECT
			 MG1.ITAKU_KAISHA_CD
			,CASE WHEN MG1.SAIKEN_SHURUI='80' THEN 'CB' WHEN MG1.SAIKEN_SHURUI='89' THEN 'CB'  ELSE 'SB' END  AS SHASAI_KBN
			,MG0.KOUSIN_ID
			,MG1.MGR_CD
			,MG1.ISIN_CD
		FROM
			 MGR_KIHON MG1
			,MGR_STS MG0
		WHERE MG0.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
		  AND TO_CHAR(MG0.KOUSIN_DT, 'YYYYMMDD') = gGyomuYmd
		  AND MG0.ITAKU_KAISHA_CD	= MG1.ITAKU_KAISHA_CD
		  AND MG0.MGR_CD			= MG1.MGR_CD
		  AND MG1.JTK_KBN			= '2'
		  AND MG0.MGR_STAT_KBN		= '1'
	;
	-- 34_償還入力（副受託銘柄） 取得
	c34ShokanInsFuku CURSOR FOR
		SELECT
			 Z01.ITAKU_KAISHA_CD
			,CASE WHEN MG1.SAIKEN_SHURUI='80' THEN 'CB' WHEN MG1.SAIKEN_SHURUI='89' THEN 'CB'  ELSE 'SB' END  AS SHASAI_KBN
			,Z01.KOUSIN_ID
			,Z01.MGR_CD
			,MG1.ISIN_CD
			,Z01.SHOKAN_YMD
			,Z01.SHOKAN_KBN
		FROM
			 MGR_KIHON MG1
			,GENSAI_RIREKI Z01
		WHERE Z01.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
		  AND TO_CHAR(Z01.SAKUSEI_DT, 'YYYYMMDD') = gGyomuYmd
		  AND Z01.ITAKU_KAISHA_CD	= MG1.ITAKU_KAISHA_CD
		  AND Z01.MGR_CD			= MG1.MGR_CD
		  AND MG1.JTK_KBN			= '2'
	;
	--
--	 * BT31 明細WK 当月件数集計
--	 
	cMeisaiWK CURSOR FOR
		SELECT
			 KIJUN_YM
			,ITAKU_KAISHA_CD
			,SHASAI_KBN
			,REC_KBN
			,NYURYOKU_KBN
			,SUM(TOROKU)	AS TOROKU_CNT
			,SUM(TEISEI)	AS TEISEI_CNT
			,SUM(TORIKESHI)	AS TORIKESHI_CNT
		FROM (
			-- 処理モードレベルで集計
			SELECT
				 SUBSTR(KIJUN_YMD, 1, 6) AS KIJUN_YM
				,ITAKU_KAISHA_CD
				,SHASAI_KBN
				,REC_KBN
				,NYURYOKU_KBN
				,SHORI_MODE
				,CASE SHORI_MODE WHEN C_SHORI_MODE_TOROKU    THEN COUNT(*) ELSE 0 END AS TOROKU
				,CASE SHORI_MODE WHEN C_SHORI_MODE_TEISEI    THEN COUNT(*) ELSE 0 END AS TEISEI
				,CASE SHORI_MODE WHEN C_SHORI_MODE_TORIKESHI THEN COUNT(*) ELSE 0 END AS TORIKESHI
			FROM DAIKO_TESURYO_MEISAI_WK
			WHERE SUBSTR(KIJUN_YMD, 1, 6)	= gGyomuYm
			  AND ITAKU_KAISHA_CD			= l_inItakuKaishaCd
			GROUP BY
				 SUBSTR(KIJUN_YMD, 1, 6)
				,ITAKU_KAISHA_CD
				,SHASAI_KBN
				,REC_KBN
				,NYURYOKU_KBN
				,SHORI_MODE
			) alias9 
		GROUP BY
			 KIJUN_YM
			,ITAKU_KAISHA_CD
			,SHASAI_KBN
			,REC_KBN
			,NYURYOKU_KBN
		ORDER BY
			 KIJUN_YM
			,ITAKU_KAISHA_CD
			,SHASAI_KBN
			,REC_KBN
			,NYURYOKU_KBN
	;
  --==============================================================================
  --    メイン処理                                                                   
  --==============================================================================
BEGIN
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
	-- 業務日付の月末営業日取得
	gGetsumatsuBusinessYmd := pkDate.getGetsumatsuBusinessYmd(gGyomuYmd, 0, pkconstant.TOKYO_AREA_CD());
	-- 業務年月取得
	gGyomuYm := pkDate.getGyomuYm();
	-- BT31 明細WK 本日分データの削除（Re-Run用）
	DELETE FROM DAIKO_TESURYO_MEISAI_WK BT31
	WHERE BT31.KIJUN_YMD		= gGyomuYmd
	  AND BT31.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
	;
	-- 連番を初期化
	gSeqNo := 0;
	-- レコード区分ごとに該当オペデータを取得し、BT31 明細WKへ登録 
	--  01_銘柄（他行引受あり）・02_銘柄（自行総額引受） を BT31 明細WKへ登録
	FOR r01 IN c01_02Mgr LOOP
		CALL SFIPX217K15R02_01_wkM_insert(
			 r01.ITAKU_KAISHA_CD 	-- 委託会社コード
			,r01.SHASAI_KBN 			-- SB／CB区分
			,r01.REC_KBN 			-- レコード区分
			,r01.I_USER_ID 			-- ユーザID
			,r01.SHORI_MODE 			-- 処理モード
			,r01.MGR_CD 				-- ITEM001
			,r01.ISIN_CD 			-- ITEM002
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
		);
	END LOOP;
	-- 05_新規記録（他行引受DVP）、06_新規記録（他行引受非DVP）、07_新規記録（自行引受） を BT31 明細WKへ登録
	FOR r05 IN c05_07ShinkiKiroku LOOP
		CALL SFIPX217K15R02_01_wkM_insert(
			 r05.ITAKU_KAISHA_CD 	-- 委託会社コード
			,r05.SHASAI_KBN 			-- SB／CB区分
			,r05.REC_KBN 			-- レコード区分
			,r05.KOUSIN_ID 			-- ユーザID
			,C_SHORI_MODE_TOROKU 	-- 処理モード
			,r05.MGR_CD 				-- ITEM001
			,r05.ISIN_CD 			-- ITEM002
			,r05.FINANCIAL_SECURITIES_KBN || r05.BANK_CD 	-- ITEM003
			,r05.KESSAI_NO 			-- ITEM004
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
		);
	END LOOP;
	-- 08〜16_支払登録情報 を BT31 明細WKへ登録
	FOR r08 IN c08_16ShrInfo LOOP
		-- レコード区分を割り出す
		gRecKbn := NULL;
		IF r08.KK_KANYO_UMU_FLG <> '1' THEN 	-- 機構非関与
			IF r08.FLG64 = '0' THEN 				-- ≠0000564
				IF r08.GANRI_UMU = '01' THEN 		-- 利金のみ支払
					gRecKbn := '17';
				ELSIF r08.GANRI_UMU = '10' THEN 		-- 元金のみ支払
					gRecKbn := '18';
				ELSE 								-- 元利金とも支払
					gRecKbn := '19';
				END IF;
			ELSE 								-- ＝0000564
				IF r08.GANRI_UMU = '01' THEN 		-- 利金のみ支払
					gRecKbn := '10';
				ELSIF r08.GANRI_UMU = '10' THEN 		-- 元金のみ支払
					gRecKbn := '13';
				ELSE 								-- 元利金とも支払
					gRecKbn := '16';
				END IF;
			END IF;
		ELSE 								-- 機構関与
			IF r08.FLG64 = '0' THEN 				-- ≠0000564
				IF r08.GANRI_UMU = '01' THEN 		-- 利金のみ支払
					gRecKbn := '08';
				ELSIF r08.GANRI_UMU = '10' THEN 		-- 元金のみ支払
					gRecKbn := '11';
				ELSE 								-- 元利金とも支払
					gRecKbn := '14';
				END IF;
			ELSE 								-- ＝0000564
				IF r08.GANRI_UMU = '01' THEN 		-- 利金のみ支払
					gRecKbn := '09';
				ELSIF r08.GANRI_UMU = '10' THEN 		-- 元金のみ支払
					gRecKbn := '12';
				ELSE 								-- 元利金とも支払
					gRecKbn := '15';
				END IF;
			END IF;
		END IF;
		CALL SFIPX217K15R02_01_wkM_insert(
			 r08.ITAKU_KAISHA_CD 	-- 委託会社コード
			,r08.SHASAI_KBN 			-- SB／CB区分
			,gRecKbn 				-- レコード区分
			,r08.KOUSIN_ID 			-- ユーザID
			,C_SHORI_MODE_TOROKU 	-- 処理モード
			,r08.MGR_CD 				-- ITEM001
			,r08.ISIN_CD 			-- ITEM002
			,r08.SHR_YMD 			-- ITEM003
			,r08.FINANCIAL_SECURITIES_KBN || r08.BANK_CD 	-- ITEM004
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
		);
	END LOOP;
	-- 03_変動利率 を BT31 明細WKへ登録
	FOR r03 IN c03HendoRiritu LOOP
		CALL SFIPX217K15R02_01_wkM_insert(
			 r03.ITAKU_KAISHA_CD 	-- 委託会社コード
			,r03.SHASAI_KBN 			-- SB／CB区分
			,'03'					-- レコード区分
			,r03.KOUSIN_ID 			-- ユーザID
			,r03.SHORI_MODE 			-- 処理モード
			,r03.MGR_CD 				-- ITEM001
			,r03.ISIN_CD 			-- ITEM002
			,r03.SHR_KJT 			-- ITEM003
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
		);
	END LOOP;
	-- 04、20〜24_期中銘柄変更（償還）情報 を BT31 明細WKへ登録
	FOR r04 IN c04UpdShokan LOOP
		CALL SFIPX217K15R02_01_wkM_insert(
			 r04.ITAKU_KAISHA_CD 	-- 委託会社コード
			,r04.SHASAI_KBN 			-- SB／CB区分
			,r04.REC_KBN 			-- レコード区分
			,r04.KOUSIN_ID 			-- ユーザID
			,r04.SHORI_MODE 			-- 処理モード
			,r04.MGR_CD 				-- ITEM001
			,r04.ISIN_CD 			-- ITEM002
			,r04.SHR_KJT 			-- ITEM003
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
		);
	END LOOP;
	-- 25〜27_期中銘柄情報 を BT31 明細WKへ登録
	FOR r25 IN c25_27UpdMgr LOOP
		CALL SFIPX217K15R02_01_wkM_insert(
			 r25.ITAKU_KAISHA_CD 	-- 委託会社コード
			,'SB'					-- SB／CB区分
			,r25.REC_KBN 			-- レコード区分
			,r25.KOUSIN_ID 			-- ユーザID
			,r25.SHORI_MODE 			-- 処理モード
			,r25.MGR_CD 				-- ITEM001
			,r25.ISIN_CD 			-- ITEM002
			,r25.SHR_KJT 			-- ITEM003
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
		);
	END LOOP;
	-- 28_期中銘柄情報（ＣＢ銘柄） を BT31 明細WKへ登録
	FOR r28 IN c28CBMeigaraInfo LOOP
		CALL SFIPX217K15R02_01_wkM_insert(
			 r28.ITAKU_KAISHA_CD 	-- 委託会社コード
			,'CB'					-- SB／CB区分
			,'28'					-- レコード区分
			,r28.KOUSIN_ID 			-- ユーザID
			,r28.SHORI_MODE 			-- 処理モード
			,r28.MGR_CD 				-- ITEM001
			,r28.ISIN_CD 			-- ITEM002
			,r28.TEKIYOST_YMD 		-- ITEM003
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
		);
	END LOOP;
	-- 29_新株予約権行使（CB銘柄） を BT31 明細WKへ登録
	FOR r29 IN c29ShinkabuYoyaku LOOP
		CALL SFIPX217K15R02_01_wkM_insert(
			 r29.ITAKU_KAISHA_CD 	-- 委託会社コード
			,'CB'					-- SB／CB区分
			,'29'					-- レコード区分
			,r29.KOUSIN_ID 			-- ユーザID
			,C_SHORI_MODE_TOROKU 	-- 処理モード
			,r29.MGR_CD 				-- ITEM001
			,r29.ISIN_CD 			-- ITEM002
			,r29.SHOKAN_YMD 			-- ITEM003
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
		);
	END LOOP;
	-- 30_差押情報 を BT31 明細WKへ登録
	FOR r30 IN c30Sashiosae LOOP
		CALL SFIPX217K15R02_01_wkM_insert(
			 r30.ITAKU_KAISHA_CD 	-- 委託会社コード
			,r30.SHASAI_KBN 			-- SB／CB区分
			,'30'					-- レコード区分
			,r30.KOUSIN_ID 			-- ユーザID
			,C_SHORI_MODE_TOROKU 	-- 処理モード
			,r30.MGR_CD 				-- ITEM001
			,r30.ISIN_CD 			-- ITEM002
			,r30.OSAESETTEI_YMD 		-- ITEM003
			,r30.OSAE_KBN 			-- ITEM004
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
		);
	END LOOP;
	-- 31_デフォルト情報 を BT31 明細WKへ登録
	FOR r31 IN c31Defalt LOOP
		CALL SFIPX217K15R02_01_wkM_insert(
			 r31.ITAKU_KAISHA_CD 	-- 委託会社コード
			,r31.SHASAI_KBN 			-- SB／CB区分
			,'31'					-- レコード区分
			,r31.KOUSIN_ID 			-- ユーザID
			,C_SHORI_MODE_TOROKU 	-- 処理モード
			,r31.MGR_CD 				-- ITEM001
			,r31.ISIN_CD 			-- ITEM002
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
		);
	END LOOP;
	-- 32_発行体情報 を BT31 明細WKへ登録
	FOR r32 IN c32Hakkotai LOOP
		CALL SFIPX217K15R02_01_wkM_insert(
			 r32.ITAKU_KAISHA_CD 	-- 委託会社コード
			,'SB'					-- SB／CB区分
			,'32'					-- レコード区分
			,r32.KOUSIN_ID 			-- ユーザID
			,C_SHORI_MODE_TOROKU 	-- 処理モード
			,r32.HKT_CD 				-- ITEM001
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
		);
	END LOOP;
	-- 33_副受託銘柄情報 を BT31 明細WKへ登録
	FOR r33 IN c33Fukujutaku LOOP
		CALL SFIPX217K15R02_01_wkM_insert(
			 r33.ITAKU_KAISHA_CD 	-- 委託会社コード
			,r33.SHASAI_KBN 			-- SB／CB区分
			,'33'					-- レコード区分
			,r33.KOUSIN_ID 			-- ユーザID
			,C_SHORI_MODE_TOROKU 	-- 処理モード
			,r33.MGR_CD 				-- ITEM001
			,r33.ISIN_CD 			-- ITEM002
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
		);
	END LOOP;
	-- 34_償還入力（副受託銘柄）情報 を BT31 明細WKへ登録
	FOR r34 IN c34ShokanInsFuku LOOP
		CALL SFIPX217K15R02_01_wkM_insert(
			 r34.ITAKU_KAISHA_CD 	-- 委託会社コード
			,r34.SHASAI_KBN 			-- SB／CB区分
			,'34'					-- レコード区分
			,r34.KOUSIN_ID 			-- ユーザID
			,C_SHORI_MODE_TOROKU 	-- 処理モード
			,r34.MGR_CD 				-- ITEM001
			,r34.ISIN_CD 			-- ITEM002
			,r34.SHOKAN_YMD 			-- ITEM003
			,r34.SHOKAN_KBN 			-- ITEM004
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
			,NULL
		);
	END LOOP;
	-- 月末営業日の処理 
	IF gGetsumatsuBusinessYmd = gGyomuYmd THEN
		-- ガベージ 
		-- BT25 事務代行手数料情報EUCデータワーク　→前々月分
		DELETE FROM DAIKO_TESURYO_WK BT25
		WHERE BT25.KIJUN_YM <= SUBSTR(pkdate.calcMonth(gGyomuYmd, -1), 1, 6)	--業務日付の1ヶ月前以前
		;
		-- BT31 明細WK　→1年経過分データ
		DELETE FROM DAIKO_TESURYO_MEISAI_WK BT31
		WHERE SUBSTR(BT31.KIJUN_YMD, 1, 6) < pkDate.calcMonth(gGyomuYm || '01', -11)
		;
		-- 当月分枠作成 
		-- BT25 事務代行手数料情報EUCデータワーク 削除（Re-Run用）
		DELETE FROM DAIKO_TESURYO_WK
		WHERE KIJUN_YM = gGyomuYm
		AND ITAKU_KAISHA_CD = l_inItakuKaishaCd
		;
		-- BT25 事務代行手数料情報EUCデータワーク 作成（当月分・枠のみ）
		FOR gRecKbnCnt IN 1..34 LOOP
			gRecKbn := SUBSTR('00' || gRecKbnCnt, -2);
			FOR gSbCbCnt IN 1..coalesce(cardinality(gSbCbKbn), 0) LOOP
				IF gRecKbn NOT IN ('02','09','10', '12','13','15','16','04','21','25','26','27','32') OR gSbCbKbn(gSbCbCnt) <> 'CB' THEN
					IF gRecKbn NOT IN ('28','29') OR gSbCbKbn(gSbCbCnt) <> 'SB' THEN
						FOR  gUserCnt IN 1..coalesce(cardinality(gInsUser), 0) LOOP
							CALL SFIPX217K15R02_01_wk_insert(gGyomuYm, l_inItakuKaishaCd, l_inSdFlg, gSbCbKbn(gSbCbCnt), gRecKbn, gInsUser(gUserCnt), 0, 0, 0);
						END LOOP;
					END IF;
				END IF;
			END LOOP;
		END LOOP;
		-- 当月件数を集計して登録 
		-- BT31 明細WK を件数集計 → BT25 事務代行手数料情報EUCデータワーク へ件数更新
		FOR rMeisaiWK IN cMeisaiWK LOOP
			UPDATE DAIKO_TESURYO_WK
			SET  TOROKU_CNT		= rMeisaiWK.TOROKU_CNT
				,TEISEI_CNT		= rMeisaiWK.TEISEI_CNT
				,TORIKESHI_CNT	= rMeisaiWK.TORIKESHI_CNT
			WHERE KIJUN_YM			= rMeisaiWK.KIJUN_YM
			  AND ITAKU_KAISHA_CD	= rMeisaiWK.ITAKU_KAISHA_CD
			  AND SD_FLG			= l_inSdFlg
			  AND SHASAI_KBN		= rMeisaiWK.SHASAI_KBN
			  AND REC_KBN			= rMeisaiWK.REC_KBN
			  AND NYURYOKU_KBN		= rMeisaiWK.NYURYOKU_KBN
			;
			-- UPDATE件数が0件の場合（枠がない）、異常終了とする。
			GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;
IF ora2pg_rowcount = 0 THEN
				CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '更新対象データなし' );
				CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'KIJUN_YM = ' || rMeisaiWK.KIJUN_YM || ' ITAKU_KAISHA_CD = ' || l_inItakuKaishaCd || ' SD_FLG = ' || l_inSdFlg);
				CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'SHASAI_KBN = ' || rMeisaiWK.SHASAI_KBN || ' REC_KBN = ' || rMeisaiWK.REC_KBN || ' NYURYOKU_KBN = ' || rMeisaiWK.NYURYOKU_KBN);
				RAISE EXCEPTION 'not_update_record' USING ERRCODE = '50001';
			END IF;
		END LOOP;
	END IF;
	-- 終了処理
	RETURN pkconstant.success();
--=========< エラー処理 >==========================================================
 EXCEPTION
	WHEN SQLSTATE '50001' THEN
		RETURN pkconstant.FATAL();
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'エラーコード'||SQLSTATE);
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'エラー内容'||SQLERRM);
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipx217k15r02_01 ( l_inItakuKaishaCd TEXT  ,l_inSdFlg TEXT  ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipx217k15r02_01_getnyuryokukbn ( l_inIUserId SUSER.USER_ID%TYPE ) RETURNS char AS $body$
DECLARE

	l_cnt			numeric;
	l_nyuryokuKbn	char(1);

BEGIN
	IF l_inIUserId = 'BATCH' THEN
		-- 'BATCH' は SD
		l_nyuryokuKbn := C_NYURYOKU_KBN_SD;
	ELSE
		-- 代行ロールが割り当てられているユーザは SD
		SELECT COUNT(*) INTO STRICT l_cnt
		FROM SUSER_ROLE
		WHERE ROLE_ID = '300'	-- 代行ロール
		  AND USER_ID = l_inIUserId
		;
		IF l_cnt = 0 THEN
			l_nyuryokuKbn := C_NYURYOKU_KBN_KO;
		ELSE
			l_nyuryokuKbn := C_NYURYOKU_KBN_SD;
		END IF;
	END IF;
	RETURN l_nyuryokuKbn;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipx217k15r02_01_getnyuryokukbn ( l_inIUserId SUSER.USER_ID%TYPE ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfipx217k15r02_01_wkm_insert ( l_inItakuKaisha text ,l_inSbCbKbn text ,l_inRecKbn text ,l_inIUserId text ,l_inShoriMode text ,l_inItem01 text ,l_inItem02 text ,l_inItem03 text ,l_inItem04 text ,l_inItem05 text ,l_inItem06 text ,l_inItem07 text ,l_inItem08 text ,l_inItem09 text ,l_inItem10 text, INOUT p_gSeqNo numeric ) AS $body$
DECLARE

	l_nyuryokuKbn	char(1);
	gSeqNo numeric := p_gSeqNo;
	gKjnYmd char(8);

BEGIN
	SELECT KIJUN_YMD INTO gKjnYmd FROM DAIKO_TESURYO_KIJUN_WK LIMIT 1;
	-- 連番をカウントアップ
	gSeqNo := gSeqNo + 1;
	-- 入力者を取得
	l_nyuryokuKbn := SFIPX217K15R02_01_getNyuryokuKbn(l_inIUserId);
	INSERT INTO DAIKO_TESURYO_MEISAI_WK(
		 KIJUN_YMD
		,ITAKU_KAISHA_CD
		,SEQ_NO
		,SHASAI_KBN
		,REC_KBN
		,NYURYOKU_KBN
		,SHORI_MODE
		,USER_ID
		,ITEM001
		,ITEM002
		,ITEM003
		,ITEM004
		,ITEM005
		,ITEM006
		,ITEM007
		,ITEM008
		,ITEM009
		,ITEM010
	) VALUES (
		 gGyomuYmd 						-- 基準日
		,l_inItakuKaisha 				-- 委託会社コード
		,gSeqNo 							-- 連番
		,l_inSbCbKbn 					-- SB／CB区分
		,l_inRecKbn 						-- レコード区分
		,l_nyuryokuKbn 					-- 入力者
		,l_inShoriMode 					-- 処理モード
		,l_inIUserId 					-- ユーザID
		,coalesce(l_inItem01, ' ')			-- ITEM001
		,coalesce(l_inItem02, ' ')			-- ITEM002
		,coalesce(l_inItem03, ' ')			-- ITEM003
		,coalesce(l_inItem04, ' ')			-- ITEM004
		,coalesce(l_inItem05, ' ')			-- ITEM005
		,coalesce(l_inItem06, ' ')			-- ITEM006
		,coalesce(l_inItem07, ' ')			-- ITEM007
		,coalesce(l_inItem08, ' ')			-- ITEM008
		,coalesce(l_inItem09, ' ')			-- ITEM009
		,coalesce(l_inItem10, ' ')			-- ITEM010
	);
	p_gSeqNo := gSeqNo;
RETURN;
EXCEPTION
WHEN OTHERS THEN
	RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfipx217k15r02_01_wkm_insert ( l_inItakuKaisha text ,l_inSbCbKbn text ,l_inRecKbn text ,l_inIUserId text ,l_inShoriMode text ,l_inItem01 text ,l_inItem02 text ,l_inItem03 text ,l_inItem04 text ,l_inItem05 text ,l_inItem06 text ,l_inItem07 text ,l_inItem08 text ,l_inItem09 text ,l_inItem10 text ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfipx217k15r02_01_wk_insert ( l_inKjnYm text ,l_inItakuKaisha text ,l_inSdFlg text ,l_inSbCbKbn text ,l_inRecKbn text ,l_inInsUser text ,l_inInsCnt numeric ,l_inUpdCnt numeric ,l_inDelCnt numeric ) AS $body$
BEGIN
	INSERT INTO DAIKO_TESURYO_WK(
		 KIJUN_YM
		,ITAKU_KAISHA_CD
		,SD_FLG
		,SHASAI_KBN
		,REC_KBN
		,NYURYOKU_KBN
		,TOROKU_CNT
		,TEISEI_CNT
		,TORIKESHI_CNT
	) VALUES (
		 l_inKjnYm
		,l_inItakuKaisha
		,l_inSdFlg
		,l_inSbCbKbn
		,l_inRecKbn
		,l_inInsUser
		,l_inInsCnt
		,l_inUpdCnt
		,l_inDelCnt
	);
RETURN;
EXCEPTION
WHEN OTHERS THEN
	RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfipx217k15r02_01_wk_insert ( l_inKjnYm text ,l_inItakuKaisha text ,l_inSdFlg text ,l_inSbCbKbn text ,l_inRecKbn text ,l_inInsUser text ,l_inInsCnt numeric ,l_inUpdCnt numeric ,l_inDelCnt numeric ) FROM PUBLIC;