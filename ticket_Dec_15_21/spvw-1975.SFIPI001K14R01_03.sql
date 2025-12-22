




CREATE OR REPLACE FUNCTION sfipi001k14r01_03 ( l_inItakuKaishaCd MGR_KIHON_VIEW.ITAKU_KAISHA_CD%TYPE, l_inKijunYmd BD_NYUSHUKIN.TORIHIKI_YMD%TYPE ) RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2013
-- * 会社名: JIP
-- *
-- * 概要：  入金・出金一括処理画面より起動される別段預金・会計登録データの一括作成機能のうち
-- *         元利払出金に関するデータを作成するプログラム
-- * 
-- * @author	R.Handa
-- * @version	$Id: SFIPI001K14R01_03.sql,v 1.13 2014/08/22 00:46:51 ito Exp $
-- * @param	l_inItakuKaishaCd		委託会社コード 
-- * @param	l_inKijunYmd			基準日
-- * @return	INTEGER
-- *                0:正常終了、データ無し
-- *                1:予期したエラー
-- *               99:予期せぬエラー
-- 
--==============================================================================
--                  定数定義                                                    
--==============================================================================
	C_PRGRAM_ID				CONSTANT text := 'SFIPI001K14R01_03';	-- プログラムＩＤ
	C_SAIBAN_SHURUI			CONSTANT text := 'C';						-- 採番種別（元利金請求データ（機構非関与））
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	gRtnCd					numeric := pkconstant.success();				-- リターンコード
	nNyukinGknKknKngkSum	numeric := 0;								-- 銘柄単位元金基金入金額合計
	nNyukinGknTesKngkSum	numeric := 0;								-- 銘柄単位元金手数料入金額合計
	nNyukinRknKknKngkSum	numeric := 0;								-- 銘柄単位利金基金入金額合計
	nNyukinRknTesKngkSum	numeric := 0;								-- 銘柄単位利金手数料入金額合計
	nShukkinGknKknKngkSum	numeric := 0;								-- 銘柄単位元金基金出金額合計
	nShukkinGknTesKngkSum	numeric := 0;								-- 銘柄単位元金手数料出金額合計
	nShukkinRknKknKngkSum	numeric := 0;								-- 銘柄単位利金基金出金額合計
	nShukkinRknTesKngkSum	numeric := 0;								-- 銘柄単位利金手数料出金額合計
	nDiffGknKknKngk			numeric := 0;								-- 銘柄単位元金基金差額
	nDiffGknTesKngk			numeric := 0;								-- 銘柄単位元金手数料差額
	nDiffRknKknKngk			numeric := 0;								-- 銘柄単位利金基金差額
	nDiffRknTesKngk			numeric := 0;								-- 銘柄単位利金手数料差額
	bGknTesuMyFlg			boolean := FALSE;							-- 元金手数料当社受入有無フラグ（※有り=True）
	bRknTesuMyFlg			boolean := FALSE;							-- 利金手数料当社受入有無フラグ（※有り=True）
	nGknTesuKngk			numeric := 0;								-- 元金手数料金額（税抜）
	nGknTesuZei				numeric := 0;								-- 元金手数料消費税
	nRknTesuKngk			numeric := 0;								-- 利金手数料金額（税抜）
	nRknTesuZei				numeric := 0;								-- 利金手数料消費税
	nGnrZndk				numeric := 0;								-- 元利払対象残高
	cTesuShuriCd			char(2) := NULL;							-- 手数料種類コード（※利金支払手数料）
	nBunpaiKbn				text := NULL;								-- 分配区分
	cGknTesTorihikiSKbn		BD_NYUSHUKIN.TORIHIKI_S_KBN%TYPE := NULL;	-- セットする取引詳細区分（元金手数料）
	cRknTesTorihikiSKbn		BD_NYUSHUKIN.TORIHIKI_S_KBN%TYPE := NULL;	-- セットする取引詳細区分（利金手数料）
	cTesDifTorihikiKbn		BD_NYUSHUKIN.TORIHIKI_KBN%TYPE := NULL;	-- セットする取引区分（手数料差額分）
	cTesDifTorihikiSKbn		BD_NYUSHUKIN.TORIHIKI_S_KBN%TYPE := NULL;	-- セットする取引詳細区分（手数料差額分）
	cKessaiNo				BD_NYUSHUKIN.KESSAI_NO%TYPE := NULL;		-- セットする決済番号
	cKessaiNoEda			BD_NYUSHUKIN.KESSAI_NO_EDA%TYPE := NULL;	-- セットする決済番号枝番
--==============================================================================
--                  カーソル定義                                                
--==============================================================================
	-- 対象の元利金請求明細が存在する銘柄コードの取得
	curGetMgrCd CURSOR FOR
		SELECT
			K01.MGR_CD 														-- 銘柄コード
		FROM
			KIKIN_SEIKYU K01,
			MGR_KIHON_VIEW VMG1
		WHERE  -- "curKikinSeikyu"と抽出条件をあわせる
			K01.ITAKU_KAISHA_CD = l_inItakuKaishaCd and
			K01.SHR_YMD = l_inKijunYmd and 	  			-- 作成日が当日のデータを抽出
			K01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD and
			K01.MGR_CD = VMG1.MGR_CD
		GROUP BY
			K01.MGR_CD
		ORDER BY
			K01.MGR_CD;
	-- 銘柄ごとの直近入金額の取得
	curNyukinInfo CURSOR(l_inMgrCd  BD_NYUSHUKIN.MGR_CD%TYPE) FOR
		SELECT
			TORIHIKI_KBN,
			KBN,
			SUM(KNGK+SZEI) AS SUMKNGK
		FROM (SELECT
				row_number() over (partition by
					TORIHIKI_KBN,
					CASE TORIHIKI_S_KBN WHEN '26' THEN '2' ELSE '1' END
					order by TORIHIKI_YMD desc) rn,
				TORIHIKI_KBN,
				CASE TORIHIKI_S_KBN WHEN '26' THEN '2' ELSE '1' END AS KBN,
				KNGK,
				SZEI
			FROM
				BD_NYUSHUKIN
			WHERE
				ITAKU_KAISHA_CD = l_inItakuKaishaCd and
				MGR_CD = l_inMgrCd and
				TORIHIKI_YMD <= l_inKijunYmd and
				TORIHIKI_KBN in ('21','31')
			) alias5 
		where rn = 1
		GROUP BY
			TORIHIKI_KBN,
			KBN
		ORDER BY
			TORIHIKI_KBN,KBN;
	-- 銘柄ごとの元利金請求明細情報の取得
	curKikinSeikyu CURSOR(l_inMgrCd  KIKIN_SEIKYU.MGR_CD%TYPE) FOR
		SELECT
			K01.ITAKU_KAISHA_CD,											-- 委託会社コード
			K01.MGR_CD,														-- 銘柄コード
			K01.TSUKA_CD,													-- 通貨コード
			K01.SHR_YMD,													-- 元利払日
			K01.FINANCIAL_SECURITIES_KBN,									-- 金融証券区分
			K01.BANK_CD,													-- 金融機関コード
			K01.KOZA_KBN,													-- 口座区分
			CASE K01.TAX_KBN
				WHEN '90' THEN '90'
				WHEN '91' THEN '90'
				WHEN '92' THEN '92'
				WHEN '93' THEN '92'
				WHEN '94' THEN '94'
				WHEN '95' then '94'
				ELSE K01.TAX_KBN
			END AS TAX_KBN,													-- 税区分
			SUM(K01.GZEIHIKI_BEF_CHOKYU_KNGK) AS GZEIHIKI_BEF_CHOKYU_KNGK,	-- 国税引前利金請求金額
			SUM(K01.GZEI_KNGK) AS GZEI_KNGK,								-- 国税金額
			SUM(K01.GZEIHIKI_AFT_CHOKYU_KNGK) AS GZEIHIKI_AFT_CHOKYU_KNGK,	-- 国税引後利金請求金額
			SUM(K01.SHOKAN_SEIKYU_KNGK) AS SHOKAN_SEIKYU_KNGK,				-- 償還金請求金額
			SUM(
				CASE
					WHEN K01.GNR_JISSHITSU_ZNDK = 0 THEN K01.GNR_ZNDK
					ELSE K01.GNR_JISSHITSU_ZNDK
				END
			) AS GNR_ZNDK,													-- 元利払対象残高（実質残高≠0の場合は実質残高を採用）
			K01.AITE_SKN_KESSAI_BCD,										-- 資金決済会社_金融機関コード
			K01.AITE_SKN_KESSAI_SCD,										-- 資金決済会社_支店コード
			K01.KESSAI_NO,													-- 決済番号
			VMG1.SAIKEN_SHURUI,												-- 債券種類
			VMG1.KYUJITSU_KBN,												-- 休日処理区分
			VMG1.AREACD,													-- エリアコード
			VMG1.KK_KANYO_FLG,												-- 機構関与非関与フラグ
			SUM(MG2.TSUKARISHI_KNGK) AS TSUKARISHI_KNGK 						-- １通貨当たりの利子額
		FROM mgr_kihon_view vmg1, kikin_seikyu k01
LEFT OUTER JOIN mgr_rbrkij mg2 ON (K01.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD AND K01.MGR_CD = MG2.MGR_CD AND K01.SHR_YMD = MG2.RBR_YMD)
WHERE K01.ITAKU_KAISHA_CD = l_inItakuKaishaCd and K01.SHR_YMD = l_inKijunYmd and  	  		-- 支払日が当日のデータを抽出
 K01.MGR_CD = l_inMgrCd and K01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD and K01.MGR_CD = VMG1.MGR_CD    GROUP BY 		
			K01.ITAKU_KAISHA_CD,
			K01.MGR_CD,
			K01.TSUKA_CD,
			K01.SHR_YMD,
			K01.FINANCIAL_SECURITIES_KBN,
			K01.BANK_CD,
			K01.KOZA_KBN,
			CASE K01.TAX_KBN
				WHEN '90' THEN '90'
				WHEN '91' THEN '90'
				WHEN '92' THEN '92'
				WHEN '93' THEN '92'
				WHEN '94' THEN '94'
				WHEN '95' then '94'
				ELSE K01.TAX_KBN
			END,
			K01.AITE_SKN_KESSAI_BCD,
			K01.AITE_SKN_KESSAI_SCD,
			K01.KESSAI_NO,
			VMG1.SAIKEN_SHURUI,
			VMG1.KYUJITSU_KBN,
			VMG1.AREACD,
			VMG1.KK_KANYO_FLG
		ORDER BY
			K01.FINANCIAL_SECURITIES_KBN,									-- 金融証券区分
			K01.BANK_CD 														-- 金融機関コード
		;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 入力パラメータの必須チェック
	IF (coalesce(trim(both l_inItakuKaishaCd)::text, '') = '') THEN
		CALL pkLog.error('ECM501', C_PRGRAM_ID, '項目名称：委託会社コード');
		RETURN pkconstant.error();
	END IF;
	IF (coalesce(trim(both l_inKijunYmd)::text, '') = '') THEN
		CALL pkLog.error('ECM501', C_PRGRAM_ID, '項目名称：基準日');
		RETURN pkconstant.error();
	END IF;
	-- 対象の元利金請求明細が存在する銘柄コードの取得
	FOR recGetMgrCd IN curGetMgrCd LOOP
		-- 銘柄単位集計変数などのリセット
		nNyukinGknKknKngkSum := 0;
		nNyukinGknTesKngkSum := 0;
		nNyukinRknKknKngkSum := 0;
		nNyukinRknTesKngkSum := 0;
		nShukkinGknKknKngkSum := 0;
		nShukkinGknTesKngkSum := 0;
		nShukkinRknKknKngkSum := 0;
		nShukkinRknTesKngkSum := 0;
		nDiffGknKknKngk := 0;
		nDiffGknTesKngk := 0;
		nDiffRknKknKngk := 0;
		nDiffRknTesKngk := 0;
		bGknTesuMyFlg := FALSE;
		bRknTesuMyFlg := FALSE;
		-- 銘柄ごとの直近入金額の取得
		FOR recNyukinInfo IN curNyukinInfo(recGetMgrCd.MGR_CD) LOOP
			-- 取引区分：21（基金入金）の場合
			IF (recNyukinInfo.TORIHIKI_KBN = '21') THEN
				-- 区分：2（利金）の場合
				IF (recNyukinInfo.KBN = '2') THEN
					nNyukinRknKknKngkSum :=  recNyukinInfo.SUMKNGK;
				-- それ以外の場合
				ELSE
					nNyukinGknKknKngkSum :=  recNyukinInfo.SUMKNGK;
				END IF;
			-- それ以外（取引区分：31（元利払手数料入金））の場合
			ELSE
				-- KBN：2（利金）の場合
				IF (recNyukinInfo.KBN = '2') THEN
					nNyukinRknTesKngkSum :=  recNyukinInfo.SUMKNGK;
				-- それ以外の場合
				ELSE
					nNyukinGknTesKngkSum :=  recNyukinInfo.SUMKNGK;
				END IF;
			END IF;
		END LOOP;
		-- 銘柄ごとの元利金請求明細情報の取得
		FOR recKikinSeikyu IN curKikinSeikyu(recGetMgrCd.MGR_CD) LOOP
			-- 自社分か分配分かの判定
			-- 分配区分の取得
			nBunpaiKbn
										 := SFIPI001K14R01_03_getBunpaiKbn(
										l_inItakuKaishaCd, recKikinSeikyu.SAIKEN_SHURUI, recKikinSeikyu.KOZA_KBN, recKikinSeikyu.SHR_YMD, recKikinSeikyu.MGR_CD, recKikinSeikyu.TSUKA_CD, recKikinSeikyu.FINANCIAL_SECURITIES_KBN, recKikinSeikyu.BANK_CD, recKikinSeikyu.TAX_KBN);
			IF (gRtnCd <> pkconstant.success()) THEN
				CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '分配区分取得エラー 銘柄コード：'||recKikinSeikyu.MGR_CD);
				RETURN pkconstant.FATAL();
			END IF;
			IF nBunpaiKbn= '1' THEN
				-- 分配分の場合、取引詳細区分：52（分配（元手））・54（分配（利手））をセット
				cGknTesTorihikiSKbn := '52';
				cRknTesTorihikiSKbn := '54';
			ELSE
				-- 自社分の場合、取引詳細区分：51（当社受入（元手））・53（当社受入（利手））をセット
				cGknTesTorihikiSKbn := '51';
				cRknTesTorihikiSKbn := '53';
			END IF;
			-- 別段入出金テーブルinsertに用いる決済番号のセット
			IF (SUBSTR(recKikinSeikyu.KESSAI_NO,1,1) <> '8') THEN
				-- KIKIN_SEIKYUテーブルに、ほふりより登録された決済番号を持っていない場合、採番テーブルより取得
				cKessaiNo := PKIPI000K14R01.getKessaiNo(l_inItakuKaishaCd,C_SAIBAN_SHURUI);
			ELSE
				cKessaiNo := recKikinSeikyu.KESSAI_NO;
			END IF;
			-- 元金に関するデータの作成
			IF (recKikinSeikyu.SHOKAN_SEIKYU_KNGK > 0 AND recKikinSeikyu.TSUKA_CD = 'JPY') THEN
				-- 元金基金出金データの作成
				gRtnCd := PKIPI000K14R01.insertBD(
							l_inKijunYmd,							-- 基準日
							l_inItakuKaishaCd,						-- 委託会社コード
							recKikinSeikyu.MGR_CD,					-- 銘柄コード
							l_inKijunYmd,							-- 取引日：基準日
							'22',									-- 取引区分：22（他行支払請求）
							'31',									-- 取引詳細区分：31（元金）
							'2',									-- 入出金区分：2（出金）
							'0',									-- 元利区分：0（元金）
							'2',									-- 現登区分：2（振替債）
							recKikinSeikyu.SHOKAN_SEIKYU_KNGK,		-- 金額
							0,										-- 消費税
							cKessaiNo,								-- 決済番号
							PKIPI000K14R01.getKessaiNoEda(l_inItakuKaishaCd,cKessaiNo),
																	-- 決済番号枝番
							recKikinSeikyu.FINANCIAL_SECURITIES_KBN,-- 金融証券区分
							recKikinSeikyu.BANK_CD,					-- 金融機関コード
							recKikinSeikyu.KOZA_KBN,				-- 口座区分
							recKikinSeikyu.TAX_KBN,					-- 税区分
							recKikinSeikyu.AITE_SKN_KESSAI_BCD,		-- 相手方資金決済会社_金融機関コード
							recKikinSeikyu.AITE_SKN_KESSAI_SCD,		-- 相手方資金決済会社_支店コード
							NULL,									-- 手数料種類コード
							NULL,									-- 分配先金融証券区分
							NULL 									-- 分配先金融機関コード
				);
				IF (gRtnCd <> pkconstant.success()) THEN
					CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '別段預金INSERT処理エラー 銘柄コード：'||recKikinSeikyu.MGR_CD);
					RETURN pkconstant.FATAL();
				END IF;
				-- 銘柄単位元金基金出金額合計への加算
				nShukkinGknKknKngkSum := nShukkinGknKknKngkSum + recKikinSeikyu.SHOKAN_SEIKYU_KNGK;
				-- 元金手数料金額の取得
				SELECT * FROM SFIPI001K14R01_03_getGknTesuKngk(
											l_inItakuKaishaCd, recKikinSeikyu.MGR_CD, recKikinSeikyu.SHOKAN_SEIKYU_KNGK, PKIPAZEI.getShohiZei(l_inKijunYmd)) INTO STRICT nGknTesuKngk, nGknTesuZei
											;
				IF (gRtnCd <> pkconstant.success()) THEN
					CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '元金手数料金額取得エラー 銘柄コード：'||recKikinSeikyu.MGR_CD);
					RETURN pkconstant.FATAL();
				END IF;
				-- 元金の手数料金額が存在する場合、元金手数料出金データを作成する
				IF (nGknTesuKngk > 0) THEN
					-- セットする決済番号枝番の取得
					cKessaiNoEda := PKIPI000K14R01.getKessaiNoEda(l_inItakuKaishaCd,cKessaiNo);
					gRtnCd := PKIPI000K14R01.insertBD(
								l_inKijunYmd,							-- 基準日
								l_inItakuKaishaCd,						-- 委託会社コード
								recKikinSeikyu.MGR_CD,					-- 銘柄コード
								pkDate.getGetsumatsuBusinessYmd(l_inKijunYmd,1),
																		-- 取引日：基準日翌月末営業日
								'32',									-- 取引区分：32（元利払手数料出金）
								cGknTesTorihikiSKbn,					-- 取引詳細区分
								'2',									-- 入出金区分：2（出金）
								'0',									-- 元利区分：0（元金）
								'2',									-- 現登区分：2（振替債）
								nGknTesuKngk,							-- 金額
								nGknTesuZei,							-- 消費税
								cKessaiNo,								-- 決済番号
								cKessaiNoEda,							-- 決済番号枝番
								recKikinSeikyu.FINANCIAL_SECURITIES_KBN,-- 金融証券区分
								recKikinSeikyu.BANK_CD,					-- 金融機関コード
								recKikinSeikyu.KOZA_KBN,				-- 口座区分
								recKikinSeikyu.TAX_KBN,					-- 税区分
								recKikinSeikyu.AITE_SKN_KESSAI_BCD,		-- 相手方資金決済会社_金融機関コード
								recKikinSeikyu.AITE_SKN_KESSAI_SCD,		-- 相手方資金決済会社_支店コード
								NULL,									-- 手数料種類コード
								NULL,									-- 分配先金融証券区分
								NULL 									-- 分配先金融機関コード
					);
					IF (gRtnCd <> pkconstant.success()) THEN
						CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '別段預金INSERT処理エラー 銘柄コード：'||recKikinSeikyu.MGR_CD);
						RETURN pkconstant.FATAL();
					END IF;
					-- 銘柄単位元金手数料出金額合計への加算
					nShukkinGknTesKngkSum := nShukkinGknTesKngkSum + nGknTesuKngk + nGknTesuZei;
					-- 取引詳細区分：51（当社受入（元手））の場合
					IF (cGknTesTorihikiSKbn = '51') THEN
						-- 元金手数料当社受入有無フラグをTRUEにする
						bGknTesuMyFlg := TRUE;
						-- 勘定科目：20（受入手数料（社債管理））の会計登録データ作成
						gRtnCd := PKIPI000K14R01.insertKT(
									l_inItakuKaishaCd,					-- 委託会社コード
									recKikinSeikyu.MGR_CD,				-- 銘柄コード
									pkDate.getGetsumatsuBusinessYmd(l_inKijunYmd,1),
																		-- 取引日：基準日翌月末営業日
									'20',								-- 勘定科目：20（受入手数料（社債管理））
									'81',								-- 手数料種類コード：81（元金支払手数料）
									recKikinSeikyu.FINANCIAL_SECURITIES_KBN,
																		-- 金融証券区分
									recKikinSeikyu.BANK_CD,				-- 金融機関コード
									recKikinSeikyu.KOZA_KBN,			-- 口座区分
									recKikinSeikyu.TAX_KBN,				-- 税区分
									'1',								-- 入出金区分：1（入金）
									nGknTesuKngk,						-- 金額
									nGknTesuZei,						-- 消費税
									PKIPI000K14R01.modGRTesKTBikou(cGknTesTorihikiSKbn,cKessaiNo || '-' || cKessaiNoEda)
																		-- 会計登録備考
						);
						IF (gRtnCd <> pkconstant.success()) THEN
							CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '会計登録INSERT処理エラー 銘柄コード：'||recKikinSeikyu.MGR_CD);
							RETURN gRtnCd;
						END IF;
					END IF;
				END IF;
			END IF;
			-- 利金に関するデータの作成
			IF (recKikinSeikyu.GZEIHIKI_AFT_CHOKYU_KNGK > 0) THEN
				IF (recKikinSeikyu.TSUKA_CD = 'JPY') THEN
					-- 利金基金出金データの作成
					gRtnCd := PKIPI000K14R01.insertBD(
								l_inKijunYmd,							-- 基準日
								l_inItakuKaishaCd,						-- 委託会社コード
								recKikinSeikyu.MGR_CD,					-- 銘柄コード
								l_inKijunYmd,							-- 取引日：基準日
								'22',									-- 取引区分：22（他行支払請求）
								'32',									-- 取引詳細区分：32（利金）
								'2',									-- 入出金区分：2（出金）
								'1',									-- 元利区分：1（利金）
								'2',									-- 現登区分：2（振替債）
								recKikinSeikyu.GZEIHIKI_AFT_CHOKYU_KNGK,-- 金額
								0,										-- 消費税
								cKessaiNo,								-- 決済番号
								PKIPI000K14R01.getKessaiNoEda(l_inItakuKaishaCd,cKessaiNo),
																		-- 決済番号枝番
								recKikinSeikyu.FINANCIAL_SECURITIES_KBN,-- 金融証券区分
								recKikinSeikyu.BANK_CD,					-- 金融機関コード
								recKikinSeikyu.KOZA_KBN,				-- 口座区分
								recKikinSeikyu.TAX_KBN,					-- 税区分
								recKikinSeikyu.AITE_SKN_KESSAI_BCD,		-- 相手方資金決済会社_金融機関コード
								recKikinSeikyu.AITE_SKN_KESSAI_SCD,		-- 相手方資金決済会社_支店コード
								NULL,									-- 手数料種類コード
								NULL,									-- 分配先金融証券区分
								NULL 									-- 分配先金融機関コード
					);
					IF (gRtnCd <> pkconstant.success()) THEN
						CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '別段預金INSERT処理エラー 銘柄コード：'||recKikinSeikyu.MGR_CD);
						RETURN pkconstant.FATAL();
					END IF;
					-- 銘柄単位利金基金出金額合計への加算
					nShukkinRknKknKngkSum := nShukkinRknKknKngkSum + recKikinSeikyu.GZEIHIKI_AFT_CHOKYU_KNGK;
				END IF;
				-- 機構非関与方式の場合、元利払対象残高は前日時点での残高にする。
				IF recKikinSeikyu.KK_KANYO_FLG <> '1' THEN
					nGnrZndk := (PKIPAZNDK.GETKJNZNDK(
															l_inItakuKaishaCd,
															recKikinSeikyu.MGR_CD,
															PKDATE.GETZENBUSINESSYMD(l_inKijunYmd),
															4
															))::numeric;
				ELSE
					nGnrZndk := recKikinSeikyu.GNR_ZNDK;
				END IF;
				-- 利金手数料金額の取得
				SELECT * FROM SFIPI001K14R01_03_getRknTesuKngk(
											l_inItakuKaishaCd, recKikinSeikyu.MGR_CD, recKikinSeikyu.GZEIHIKI_BEF_CHOKYU_KNGK, nGnrZndk, PKIPAZEI.getShohiZei(l_inKijunYmd)) INTO STRICT cTesuShuriCd, nRknTesuKngk, nRknTesuZei
											;
				IF (gRtnCd <> pkconstant.success()) THEN
					CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '利金手数料金額取得エラー 銘柄コード：'||recKikinSeikyu.MGR_CD);
					RETURN pkconstant.FATAL();
				END IF;
				-- 利金の手数料金額が存在する場合、利金手数料出金データを作成する
				IF (nRknTesuKngk > 0) THEN
					-- セットする決済番号枝番の取得
					cKessaiNoEda := PKIPI000K14R01.getKessaiNoEda(l_inItakuKaishaCd,cKessaiNo);
					gRtnCd := PKIPI000K14R01.insertBD(
								l_inKijunYmd,							-- 基準日
								l_inItakuKaishaCd,						-- 委託会社コード
								recKikinSeikyu.MGR_CD,					-- 銘柄コード
								pkDate.getGetsumatsuBusinessYmd(l_inKijunYmd,1),
																		-- 取引日：基準日翌月末営業日
								'32',									-- 取引区分：32（元利払手数料出金）
								cRknTesTorihikiSKbn,					-- 取引詳細区分
								'2',									-- 入出金区分：2（出金）
								'1',									-- 元利区分：1（利金）
								'2',									-- 現登区分：2（振替債）
								nRknTesuKngk,							-- 金額
								nRknTesuZei,							-- 消費税
								cKessaiNo,								-- 決済番号
								cKessaiNoEda,							-- 決済番号枝番
								recKikinSeikyu.FINANCIAL_SECURITIES_KBN,-- 金融証券区分
								recKikinSeikyu.BANK_CD,					-- 金融機関コード
								recKikinSeikyu.KOZA_KBN,				-- 口座区分
								recKikinSeikyu.TAX_KBN,					-- 税区分
								recKikinSeikyu.AITE_SKN_KESSAI_BCD,		-- 相手方資金決済会社_金融機関コード
								recKikinSeikyu.AITE_SKN_KESSAI_SCD,		-- 相手方資金決済会社_支店コード
								NULL,									-- 手数料種類コード
								NULL,									-- 分配先金融証券区分
								NULL 									-- 分配先金融機関コード
					);
					IF (gRtnCd <> pkconstant.success()) THEN
						CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '別段預金INSERT処理エラー 銘柄コード：'||recKikinSeikyu.MGR_CD);
						RETURN pkconstant.FATAL();
					END IF;
					-- 銘柄単位利金手数料出金額合計への加算
					nShukkinRknTesKngkSum := nShukkinRknTesKngkSum + nRknTesuKngk + nRknTesuZei;
					-- 取引詳細区分：53（当社受入（利手））の場合
					IF (cRknTesTorihikiSKbn = '53') THEN
						-- 利金手数料当社受入有無フラグをTRUEにする
						bRknTesuMyFlg := TRUE;
						-- 勘定科目：20（受入手数料（社債管理））の会計登録データ作成
						gRtnCd := PKIPI000K14R01.insertKT(
									l_inItakuKaishaCd,					-- 委託会社コード
									recKikinSeikyu.MGR_CD,				-- 銘柄コード
									pkDate.getGetsumatsuBusinessYmd(l_inKijunYmd,1),
																		-- 取引日：基準日翌月末営業日
									'20',								-- 勘定科目：20（受入手数料（社債管理））
									cTesuShuriCd,						-- 手数料種類コード
									recKikinSeikyu.FINANCIAL_SECURITIES_KBN,
																		-- 金融証券区分
									recKikinSeikyu.BANK_CD,				-- 金融機関コード
									recKikinSeikyu.KOZA_KBN,			-- 口座区分
									recKikinSeikyu.TAX_KBN,				-- 税区分
									'1',								-- 入出金区分：1（入金）
									nRknTesuKngk,						-- 金額
									nRknTesuZei,						-- 消費税
									PKIPI000K14R01.modGRTesKTBikou(cRknTesTorihikiSKbn,cKessaiNo || '-' || cKessaiNoEda)
																		-- 会計登録備考
						);
						IF (gRtnCd <> pkconstant.success()) THEN
							CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '会計登録INSERT処理エラー 銘柄コード：'||recKikinSeikyu.MGR_CD);
							RETURN gRtnCd;
						END IF;
					END IF;
				END IF;
				-- 国税額が存在する場合、国税出金データを作成する
				IF (recKikinSeikyu.GZEI_KNGK > 0 AND recKikinSeikyu.TSUKA_CD = 'JPY') THEN
					gRtnCd := PKIPI000K14R01.insertBD(
								l_inKijunYmd,							-- 基準日
								l_inItakuKaishaCd,						-- 委託会社コード
								recKikinSeikyu.MGR_CD,					-- 銘柄コード
								pkDate.calcDateKyujitsuKbn(SUBSTR(pkDate.GETGETSUMATSUYMD(l_inKijunYmd,1),1,6)||'10',0,pkconstant.HORIDAY_SHORI_KBN_YOKUEI()),
																		-- 取引日：基準日翌月10日（翌営業日補正）
								'42',									-- 取引区分：42（国税納税引落）
								'00',									-- 取引詳細区分：00（詳細なし）
								'2',									-- 入出金区分：2（出金）
								'1',									-- 元利区分：1（利金）
								'2',									-- 現登区分：2（振替債）
								recKikinSeikyu.GZEI_KNGK,				-- 金額
								0,										-- 消費税
								cKessaiNo,								-- 決済番号
								PKIPI000K14R01.getKessaiNoEda(l_inItakuKaishaCd,cKessaiNo),
																		-- 決済番号枝番
								recKikinSeikyu.FINANCIAL_SECURITIES_KBN,-- 金融証券区分
								recKikinSeikyu.BANK_CD,					-- 金融機関コード
								recKikinSeikyu.KOZA_KBN,				-- 口座区分
								recKikinSeikyu.TAX_KBN,					-- 税区分
								recKikinSeikyu.AITE_SKN_KESSAI_BCD,		-- 相手方資金決済会社_金融機関コード
								recKikinSeikyu.AITE_SKN_KESSAI_SCD,		-- 相手方資金決済会社_支店コード
								NULL,									-- 手数料種類コード
								NULL,									-- 分配先金融証券区分
								NULL 									-- 分配先金融機関コード
					);
					IF (gRtnCd <> pkconstant.success()) THEN
						CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '別段預金INSERT処理エラー 銘柄コード：'||recKikinSeikyu.MGR_CD);
						RETURN pkconstant.FATAL();
					END IF;
					-- 銘柄単位利金基金出金額合計への加算
					nShukkinRknKknKngkSum := nShukkinRknKknKngkSum + recKikinSeikyu.GZEI_KNGK;
				END IF;
			END IF;
		END LOOP;
		-- 差額分の計算
		IF (nShukkinGknKknKngkSum > 0) THEN
			nDiffGknKknKngk := nNyukinGknKknKngkSum - nShukkinGknKknKngkSum;
		END IF;
		IF (nShukkinRknKknKngkSum > 0) THEN
			nDiffRknKknKngk := nNyukinRknKknKngkSum - nShukkinRknKknKngkSum;
		END IF;
		IF (nShukkinGknTesKngkSum > 0) THEN
			nDiffGknTesKngk := nNyukinGknTesKngkSum - nShukkinGknTesKngkSum;
		END IF;
		IF (nShukkinRknTesKngkSum > 0) THEN
			nDiffRknTesKngk := nNyukinRknTesKngkSum - nShukkinRknTesKngkSum;
		END IF;
		-- 差額の有無確認
		IF (nDiffGknKknKngk > 0 or nDiffRknKknKngk > 0 or nDiffGknTesKngk <> 0 or nDiffRknTesKngk <> 0) THEN
			-- 決済番号の採番
			cKessaiNo := PKIPI000K14R01.getKessaiNo(l_inItakuKaishaCd,C_SAIBAN_SHURUI);
			-- 元金基金の差額が存在する場合
			IF (nDiffGknKknKngk > 0) THEN
				-- 差額分（元金）の別段預金データ作成
				gRtnCd := PKIPI000K14R01.insertBD(
							l_inKijunYmd,							-- 基準日
							l_inItakuKaishaCd,						-- 委託会社コード
							recGetMgrCd.MGR_CD,						-- 銘柄コード
							l_inKijunYmd,							-- 取引日：基準日
							'25',									-- 取引区分：25（雑益（元利金））
							'2A',									-- 取引詳細区分：2A（差額分（元金））
							'2',									-- 入出金区分：2（出金）
							'0',									-- 元利区分：0（元金）
							'2',									-- 現登区分：2（振替債）
							nDiffGknKknKngk,						-- 金額
							0,										-- 消費税
							cKessaiNo,								-- 決済番号
							PKIPI000K14R01.getKessaiNoEda(l_inItakuKaishaCd,cKessaiNo),
																	-- 決済番号枝番
							NULL,									-- 金融証券区分
							NULL,									-- 金融機関コード
							NULL,									-- 口座区分
							NULL,									-- 税区分
							NULL,									-- 相手方資金決済会社_金融機関コード
							NULL,									-- 相手方資金決済会社_支店コード
							NULL,									-- 手数料種類コード
							NULL,									-- 分配先金融証券区分
							NULL 									-- 分配先金融機関コード
				);
				IF (gRtnCd <> pkconstant.success()) THEN
					CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '別段預金INSERT処理エラー 銘柄コード：'||recGetMgrCd.MGR_CD);
					RETURN pkconstant.FATAL();
				END IF;
				-- 差額分（元金）の会計登録データ作成
				gRtnCd := PKIPI000K14R01.insertKT(
							l_inItakuKaishaCd,					-- 委託会社コード
							recGetMgrCd.MGR_CD,					-- 銘柄コード
							l_inKijunYmd,						-- 取引日：基準日
							PKIPI000K14R01.getSagakuKanjoKamokuCd('25','2A'),
																-- 勘定科目：関数（差額勘定科目取得）の結果
							NULL,								-- 手数料種類コード
							NULL,								-- 金融証券区分
							NULL,								-- 金融機関コード
							NULL,								-- 口座区分
							NULL,								-- 税区分
							'1',								-- 入出金区分：1（入金）
							nDiffGknKknKngk,					-- 金額
							0,									-- 消費税
							PKIPI000K14R01.getTorihikiSKbnRnm('2A')
																-- 会計登録備考：取引詳細区分の略称
				);
				IF (gRtnCd <> pkconstant.success()) THEN
					CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '会計登録INSERT処理エラー 銘柄コード：'||recGetMgrCd.MGR_CD);
					RETURN gRtnCd;
				END IF;
			END IF;
			-- 利金基金の差額が存在する場合
			IF (nDiffRknKknKngk > 0) THEN
				-- 差額分（利金）の別段預金データ作成
				gRtnCd := PKIPI000K14R01.insertBD(
							l_inKijunYmd,							-- 基準日
							l_inItakuKaishaCd,						-- 委託会社コード
							recGetMgrCd.MGR_CD,						-- 銘柄コード
							l_inKijunYmd,							-- 取引日：基準日
							'25',									-- 取引区分：25（雑益（元利金））
							'2B',									-- 取引詳細区分：2B（差額分（利金））
							'2',									-- 入出金区分：2（出金）
							'1',									-- 元利区分：1（利金）
							'2',									-- 現登区分：2（振替債）
							nDiffRknKknKngk,						-- 金額
							0,										-- 消費税
							cKessaiNo,								-- 決済番号
							PKIPI000K14R01.getKessaiNoEda(l_inItakuKaishaCd,cKessaiNo),
																	-- 決済番号枝番
							NULL,									-- 金融証券区分
							NULL,									-- 金融機関コード
							NULL,									-- 口座区分
							NULL,									-- 税区分
							NULL,									-- 相手方資金決済会社_金融機関コード
							NULL,									-- 相手方資金決済会社_支店コード
							NULL,									-- 手数料種類コード
							NULL,									-- 分配先金融証券区分
							NULL 									-- 分配先金融機関コード
				);
				IF (gRtnCd <> pkconstant.success()) THEN
					CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '別段預金INSERT処理エラー 銘柄コード：'||recGetMgrCd.MGR_CD);
					RETURN pkconstant.FATAL();
				END IF;
				-- 差額分（利金）の会計登録データ作成
				gRtnCd := PKIPI000K14R01.insertKT(
							l_inItakuKaishaCd,					-- 委託会社コード
							recGetMgrCd.MGR_CD,					-- 銘柄コード
							l_inKijunYmd,						-- 取引日：基準日
							PKIPI000K14R01.getSagakuKanjoKamokuCd('25','2B'),
																-- 勘定科目：関数（差額勘定科目取得）の結果
							NULL,								-- 手数料種類コード
							NULL,								-- 金融証券区分
							NULL,								-- 金融機関コード
							NULL,								-- 口座区分
							NULL,								-- 税区分
							'1',								-- 入出金区分：1（入金）
							nDiffRknKknKngk,					-- 金額
							0,									-- 消費税
							PKIPI000K14R01.getTorihikiSKbnRnm('2B')
																-- 会計登録備考：取引詳細区分の略称
				);
				IF (gRtnCd <> pkconstant.success()) THEN
					CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '会計登録INSERT処理エラー 銘柄コード：'||recGetMgrCd.MGR_CD);
					RETURN gRtnCd;
				END IF;
			END IF;
			-- 元金手数料の差額が存在する場合
			IF (nDiffGknTesKngk <> 0) THEN
				-- 利用する取引区分・取引詳細区分の設定
				-- 金額がマイナスの場合
				IF (nDiffGknTesKngk < 0) THEN
					cTesDifTorihikiKbn := '31';						-- 取引区分：31（元利払手数料入金）
					cTesDifTorihikiSKbn := '2E';					-- 取引詳細区分：2E（雑損（元手））
				-- 上記以外で当社受入有りの場合
				ELSIF (bGknTesuMyFlg = TRUE) THEN
					cTesDifTorihikiKbn := '32';						-- 取引区分：32（元利払手数料出金）
					cTesDifTorihikiSKbn := '55';					-- 取引詳細区分：55（差額受入（元手））
				-- それ以外の場合
				ELSE
					cTesDifTorihikiKbn := '32';						-- 取引区分：32（元利払手数料出金）
					cTesDifTorihikiSKbn := '57';					-- 取引詳細区分：57（雑益（元手））
				END IF;
				-- 差額受入（元手）／雑益（元手）または雑損（元手）の別段預金データ作成
				gRtnCd := PKIPI000K14R01.insertBD(
							l_inKijunYmd,							-- 基準日
							l_inItakuKaishaCd,						-- 委託会社コード
							recGetMgrCd.MGR_CD,						-- 銘柄コード
							PKDATE.GETGETSUMATSUBUSINESSYMD(l_inKijunYmd,1),
																	-- 取引日：基準日翌月末営業日
							cTesDifTorihikiKbn,						-- 取引区分
							cTesDifTorihikiSKbn,					-- 取引詳細区分
							CASE 									-- 入出金区分：
								WHEN nDiffGknTesKngk < 0 THEN '1'	--     ＜金額がマイナス＞1（入金）
								ELSE '2' END,						--     ＜それ以外＞2（出金）
							'0',									-- 元利区分：0（元金）
							'2',									-- 現登区分：2（振替債）
							ABS(nDiffGknTesKngk),					-- 金額
							0,										-- 消費税
							cKessaiNo,								-- 決済番号
							PKIPI000K14R01.getKessaiNoEda(l_inItakuKaishaCd,cKessaiNo),
																	-- 決済番号枝番
							NULL,									-- 金融証券区分
							NULL,									-- 金融機関コード
							NULL,									-- 口座区分
							NULL,									-- 税区分
							NULL,									-- 相手方資金決済会社_金融機関コード
							NULL,									-- 相手方資金決済会社_支店コード
							NULL,									-- 手数料種類コード
							NULL,									-- 分配先金融証券区分
							NULL 									-- 分配先金融機関コード
				);
				IF (gRtnCd <> pkconstant.success()) THEN
					CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '別段預金INSERT処理エラー 銘柄コード：'||recGetMgrCd.MGR_CD);
					RETURN pkconstant.FATAL();
				END IF;
				-- 勘定科目：差額受入（元手）／雑益（元手）または雑損（元手）の会計登録データ作成
				gRtnCd := PKIPI000K14R01.insertKT(
							l_inItakuKaishaCd,						-- 委託会社コード
							recGetMgrCd.MGR_CD,						-- 銘柄コード
							PKDATE.GETGETSUMATSUBUSINESSYMD(l_inKijunYmd,1),
																	-- 取引日：基準日翌月末営業日
							PKIPI000K14R01.getSagakuKanjoKamokuCd(cTesDifTorihikiKbn,cTesDifTorihikiSKbn),
																	-- 勘定科目：関数（差額勘定科目取得）の結果
							NULL,									-- 手数料種類コード
							NULL,									-- 金融証券区分
							NULL,									-- 金融機関コード
							NULL,									-- 口座区分
							NULL,									-- 税区分
							CASE 									-- 入出金区分：
								WHEN nDiffGknTesKngk < 0 THEN '2'	--     ＜金額がマイナス＞2（出金）
								ELSE '1' END,						--     ＜それ以外＞1（入金）
							ABS(nDiffGknTesKngk),					-- 金額
							0,										-- 消費税
							PKIPI000K14R01.getTorihikiSKbnRnm(cTesDifTorihikiSKbn)
																	-- 会計登録備考：取引詳細区分の略称
				);
				IF (gRtnCd <> pkconstant.success()) THEN
					CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '会計登録INSERT処理エラー 銘柄コード：'||recGetMgrCd.MGR_CD);
					RETURN gRtnCd;
				END IF;
			END IF;
			-- 利金手数料の差額が存在する場合
			IF (nDiffRknTesKngk <> 0) THEN
				-- 利用する取引区分・取引詳細区分の設定
				-- 金額がマイナスの場合
				IF (nDiffRknTesKngk < 0) THEN
					cTesDifTorihikiKbn := '31';						-- 取引区分：31（元利払手数料入金）
					cTesDifTorihikiSKbn := '2F';					-- 取引詳細区分：2F（雑損（利手））
				-- 上記以外で当社受入有りの場合
				ELSIF (bRknTesuMyFlg = TRUE) THEN
					cTesDifTorihikiKbn := '32';						-- 取引区分：32（元利払手数料出金）
					cTesDifTorihikiSKbn := '56';					-- 取引詳細区分：56（差額受入（利手））
				-- それ以外の場合
				ELSE
					cTesDifTorihikiKbn := '32';						-- 取引区分：32（元利払手数料出金）
					cTesDifTorihikiSKbn := '58';					-- 取引詳細区分：58（雑益（利手））
				END IF;
				-- 差額受入（利手）／雑益（利手）または雑損（利手）の別段預金データ作成
				gRtnCd := PKIPI000K14R01.insertBD(
							l_inKijunYmd,							-- 基準日
							l_inItakuKaishaCd,						-- 委託会社コード
							recGetMgrCd.MGR_CD,						-- 銘柄コード
							PKDATE.GETGETSUMATSUBUSINESSYMD(l_inKijunYmd,1),
																	-- 取引日：基準日翌月末営業日
							cTesDifTorihikiKbn,						-- 取引区分
							cTesDifTorihikiSKbn,					-- 取引詳細区分
							CASE 									-- 入出金区分：
								WHEN nDiffRknTesKngk < 0 THEN '1'	--     ＜金額がマイナス＞1（入金）
								ELSE '2' END,						--     ＜それ以外＞2（出金）
							'1',									-- 元利区分：1（利金）
							'2',									-- 現登区分：2（振替債）
							ABS(nDiffRknTesKngk),					-- 金額
							0,										-- 消費税
							cKessaiNo,								-- 決済番号
							PKIPI000K14R01.getKessaiNoEda(l_inItakuKaishaCd,cKessaiNo),
																	-- 決済番号枝番
							NULL,									-- 金融証券区分
							NULL,									-- 金融機関コード
							NULL,									-- 口座区分
							NULL,									-- 税区分
							NULL,									-- 相手方資金決済会社_金融機関コード
							NULL,									-- 相手方資金決済会社_支店コード
							NULL,									-- 手数料種類コード
							NULL,									-- 分配先金融証券区分
							NULL 									-- 分配先金融機関コード
				);
				IF (gRtnCd <> pkconstant.success()) THEN
					CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '別段預金INSERT処理エラー 銘柄コード：'||recGetMgrCd.MGR_CD);
					RETURN pkconstant.FATAL();
				END IF;
				-- 差額受入（利手）／雑益（利手）または雑損（利手）の会計登録データ作成
				gRtnCd := PKIPI000K14R01.insertKT(
							l_inItakuKaishaCd,						-- 委託会社コード
							recGetMgrCd.MGR_CD,						-- 銘柄コード
							PKDATE.GETGETSUMATSUBUSINESSYMD(l_inKijunYmd,1),
																	-- 取引日：基準日翌月末営業日
							PKIPI000K14R01.getSagakuKanjoKamokuCd(cTesDifTorihikiKbn,cTesDifTorihikiSKbn),
																	-- 勘定科目：関数（差額勘定科目取得）の結果
							NULL,									-- 手数料種類コード
							NULL,									-- 金融証券区分
							NULL,									-- 金融機関コード
							NULL,									-- 口座区分
							NULL,									-- 税区分
							CASE 									-- 入出金区分：
								WHEN nDiffRknTesKngk < 0 THEN '2'	--     ＜金額がマイナス＞2（出金）
								ELSE '1' END,						--     ＜それ以外＞1（入金）
							ABS(nDiffRknTesKngk),					-- 金額
							0,										-- 消費税
							PKIPI000K14R01.getTorihikiSKbnRnm(cTesDifTorihikiSKbn)
																	-- 会計登録備考：取引詳細区分の略称
				);
				IF (gRtnCd <> pkconstant.success()) THEN
					CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '会計登録INSERT処理エラー 銘柄コード：'||recGetMgrCd.MGR_CD);
					RETURN gRtnCd;
				END IF;
			END IF;
		END IF;
	END LOOP;
	RETURN pkconstant.success();
--==============================================================================
--                  エラー処理                                                  
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		-- ログ出力
		CALL pkLog.fatal('ECM701', C_PRGRAM_ID, 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi001k14r01_03 ( l_inItakuKaishaCd MGR_KIHON_VIEW.ITAKU_KAISHA_CD%TYPE, l_inKijunYmd BD_NYUSHUKIN.TORIHIKI_YMD%TYPE ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipi001k14r01_03_getbunpaikbn ( l_inItakuKaishaCd text, l_inSaikenShurui text, l_inKozaKbn text, l_inShrYmd text, l_inMgrCd text, l_inTsukaCd text, l_inFinancialSecuritiesKbn text, l_inBankCd text, l_inTaxKbn text, l_outBunpaiKbn OUT TEXT , OUT extra_param char) RETURNS record AS $body$
BEGIN
	BEGIN
		--SB銘柄
		IF (l_inSaikenShurui NOT IN ('80', '89')
			-- 分配分データの作成対象となる口座区分＝「顧客口」(60〜69・70〜79・80〜89)、「信託口」(20〜29・30〜39・97・99)
			AND ((l_inKozaKbn >= '20' AND l_inKozaKbn <= '39')
				OR (l_inKozaKbn >= '60' AND l_inKozaKbn <= '89')
				OR (l_inKozaKbn IN ('97','99','90','91'))) -- 振替地方債 非居住者非課税別段対応
			)
		THEN
			-- 分配あり
			l_outBunpaiKbn := '1';
		--CB銘柄の場合は口座区分元利払手数料分配マスタで分配有無判断を行う。
		ELSIF l_inSaikenShurui IN ('80', '89') THEN
			BEGIN
				SELECT
					DISTRI_KBN
				INTO STRICT
					l_outBunpaiKbn
				FROM
					KIKIN_SEIKYU_GNRTES_BUNPAI K10
				WHERE
					K10.ITAKU_KAISHA_CD = l_inItakuKaishaCd
					AND K10.MGR_CD = l_inMgrCd
					AND K10.SHR_YMD = l_inShrYmd
					AND K10.TSUKA_CD = l_inTsukaCd
					AND K10.FINANCIAL_SECURITIES_KBN = l_inFinancialSecuritiesKbn
					AND K10.BANK_CD = l_inBankCd
					AND K10.KOZA_KBN = l_inKozaKbn
					AND K10.TAX_KBN = l_inTaxKbn
					AND K10.SHORI_KBN = '1';
			EXCEPTION
				-- 対象データなしの時
				WHEN no_data_found THEN
				BEGIN
					SELECT
						DISTRI_KBN
					INTO STRICT
						l_outBunpaiKbn
					FROM
						KOZA_KBN_GNRTES_BUNPAI
					WHERE
						ITAKU_KAISHA_CD = l_inItakuKaishaCd
						AND KOZA_KBN = l_inKozaKbn
						AND SHOHIN_KBN = '2';
				EXCEPTION
					WHEN no_data_found THEN
					CALL pkLog.error('ECM504', C_PRGRAM_ID, 'テーブル名称：口座区分元利払手数料分配 口座区分：'||l_inKozaKbn);
					extra_param := pkconstant.error();
					RETURN;
				END;
			END;
		ELSE
		 	-- 分配なし
			l_outBunpaiKbn := '2';
		END IF;
	END;
	extra_param := pkconstant.success();
	RETURN;
EXCEPTION
	WHEN OTHERS THEN
		extra_param := pkconstant.FATAL();
		RETURN;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi001k14r01_03_getbunpaikbn ( l_inItakuKaishaCd text, l_inSaikenShurui text, l_inKozaKbn text, l_inShrYmd text, l_inMgrCd text, l_inTsukaCd text, l_inFinancialSecuritiesKbn text, l_inBankCd text, l_inTaxKbn text, l_outBunpaiKbn OUT TEXT , OUT extra_param char) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipi001k14r01_03_getgkntesukngk ( l_inItakuKaishaCd text, l_inMgrCd text, l_inSknKngk numeric, l_inSzeiRate numeric, l_outTesuKngk OUT numeric, l_outTesuZei OUT numeric , OUT extra_param integer) RETURNS record AS $body$
DECLARE

	l_bunshi		MGR_TESURYO_PRM.GNKN_SHR_TESU_BUNSHI%TYPE := 0;	-- 元金支払手数料率分子
	l_bunbo			MGR_TESURYO_PRM.GNKN_SHR_TESU_BUNBO%TYPE := 0;		-- 元金支払手数料率分母
	l_truncKeta		integer;												-- 端数金額の切捨て桁
	l_szeiSeikyuKbn MGR_TESURYO_PRM.SZEI_SEIKYU_KBN%TYPE := 0; --消費税請求区分
BEGIN
	-- 銘柄_手数料計算情報より、元金手数料率分子/分母 を取得
	BEGIN
		SELECT
			 MG8.GNKN_SHR_TESU_BUNSHI
			,MG8.GNKN_SHR_TESU_BUNBO
			,CASE WHEN VMG1.SHOKAN_TSUKA_CD='JPY' THEN 0  ELSE 2 END 		-- 償還通貨が円なら小数点以下、外貨なら小数点第二位以下切捨
			,MG8.SZEI_SEIKYU_KBN
		INTO STRICT
			 l_bunshi
			,l_bunbo
			,l_truncKeta
			,l_szeiSeikyuKbn
		FROM
			 MGR_KIHON_VIEW VMG1
			,MGR_TESURYO_PRM MG8
		WHERE
			VMG1.ITAKU_KAISHA_CD	= MG8.ITAKU_KAISHA_CD
		AND	VMG1.MGR_CD				= MG8.MGR_CD
		AND	VMG1.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
		AND	VMG1.MGR_CD				= l_inMgrCd		;
	EXCEPTION
		WHEN no_data_found THEN
			l_bunshi := 0;
			l_bunbo := 0;
			l_truncKeta := 0;
			l_szeiSeikyuKbn := 0;
	END;
	-- 元金支払手数料金額の計算
	l_outTesuKngk := TRUNC((l_inSknKngk * l_bunshi / SFIPI001K14R01_03_prevZeroDivision(l_bunbo))::numeric, l_truncKeta::int);
	-- 元金支払手数料消費税の計算
	IF (l_szeiSeikyuKbn = '0') THEN
		-- 消費税請求区分が「請求なし」の場合
		l_outTesuZei := 0;
	ELSE
		-- 消費税請求区分が「請求あり」の場合
		l_outTesuZei := TRUNC(l_outTesuKngk * l_inSzeiRate::numeric, l_truncKeta::int);
	END IF;
	extra_param := pkconstant.success();
	RETURN;
EXCEPTION
	WHEN OTHERS THEN
		extra_param := pkconstant.FATAL();
		RETURN;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi001k14r01_03_getgkntesukngk ( l_inItakuKaishaCd text, l_inMgrCd text, l_inSknKngk numeric, l_inSzeiRate numeric, l_outTesuKngk OUT numeric, l_outTesuZei OUT numeric , OUT extra_param integer) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipi001k14r01_03_getrkntesukngk ( l_inItakuKaishaCd text, l_inMgrCd text, l_inBefZeibikiRknKngk numeric, l_inGnrTaishoZndk numeric, l_inSzeiRate numeric, l_outTesuShuruiCd OUT TEXT, l_outTesuKngk OUT numeric, l_outTesuZei OUT numeric , OUT extra_param char) RETURNS record AS $body$
DECLARE

	l_bunshi		MGR_TESURYO_PRM.GNKN_SHR_TESU_BUNSHI%TYPE := NULL;	-- 元金支払手数料率分子
	l_bunbo			MGR_TESURYO_PRM.GNKN_SHR_TESU_BUNBO%TYPE := NULL;	-- 元金支払手数料率分母
	l_truncKeta		integer;												-- 端数金額の切捨て桁
	l_szeiSeikyuKbn	MGR_TESURYO_PRM.SZEI_SEIKYU_KBN%TYPE := 0; --消費税請求区分
BEGIN
	-- 銘柄_手数料計算情報より、利金手数料率分子/分母 を取得
	BEGIN
		SELECT
			 MG8.RKN_SHR_TESU_BUNSHI
			,MG8.RKN_SHR_TESU_BUNBO
			,MG7.TESU_SHURUI_CD
			,CASE MG7.TESU_SHURUI_CD
				WHEN '82' THEN CASE WHEN VMG1.RBR_TSUKA_CD='JPY' THEN 0  ELSE 2 END
				ELSE CASE WHEN VMG1.HAKKO_TSUKA_CD='JPY' THEN 0  ELSE 2 END 
			END 			-- 利払通貨が円なら小数点以下、外貨なら小数点第二位以下切捨
			,MG8.SZEI_SEIKYU_KBN
		INTO STRICT
			 l_bunshi
			,l_bunbo
			,l_outTesuShuruiCd
			,l_truncKeta
			,l_szeiSeikyuKbn
		FROM
			 MGR_KIHON_VIEW VMG1
			,MGR_TESURYO_CTL MG7
			,MGR_TESURYO_PRM MG8
		WHERE
			VMG1.ITAKU_KAISHA_CD	= MG8.ITAKU_KAISHA_CD
		AND	VMG1.MGR_CD				= MG8.MGR_CD
		AND	VMG1.ITAKU_KAISHA_CD	= MG7.ITAKU_KAISHA_CD
		AND	VMG1.MGR_CD				= MG7.MGR_CD
		AND	VMG1.ITAKU_KAISHA_CD	= l_inItakuKaishaCd
		AND	VMG1.MGR_CD				= l_inMgrCd
		AND MG7.TESU_SHURUI_CD		IN ('61','82')
		AND MG7.CHOOSE_FLG			= '1';
	EXCEPTION
		WHEN no_data_found THEN
			l_bunshi := 0;
			l_bunbo := 0;
			l_outTesuShuruiCd := ' ';
			l_truncKeta := 0;
			l_szeiSeikyuKbn := 0;
	END;
	-- 利金支払手数料金額の計算
	-- 手数料種類コードが利金ベース(82)の場合
	IF l_outTesuShuruiCd = '82' AND l_truncKeta = 0 THEN
		-- 実績国税引前利金請求金額 × 手数料率
		l_outTesuKngk := TRUNC((l_inBefZeibikiRknKngk * l_bunshi / SFIPI001K14R01_03_prevZeroDivision(l_bunbo))::numeric, l_truncKeta::int);
	-- 手数料種類コードが元金ベース(61)の場合
	ELSE
		-- 国税引前利金請求金額が0円の場合は計算しない
		IF l_inBefZeibikiRknKngk <> 0 AND l_truncKeta = 0 THEN
			-- 元利払対象残高 × 手数料率
			l_outTesuKngk := TRUNC((l_inGnrTaishoZndk * l_bunshi / SFIPI001K14R01_03_prevZeroDivision(l_bunbo))::numeric, l_truncKeta::int);
		ELSE
			l_outTesuKngk := 0;
		END IF;
	END IF;
	-- 消費税請求区分が「請求なし」の場合
	IF (l_szeiSeikyuKbn = '0') THEN
		l_outTesuZei := 0;
	-- 消費税請求区分が「請求あり」の場合
	ELSE
		l_outTesuZei := TRUNC(l_outTesuKngk * l_inSzeiRate::numeric, l_truncKeta::int);
	END IF;
	extra_param := pkconstant.success();
	RETURN;
EXCEPTION
	WHEN OTHERS THEN
		extra_param := pkconstant.FATAL();
		RETURN;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi001k14r01_03_getrkntesukngk ( l_inItakuKaishaCd text, l_inMgrCd text, l_inBefZeibikiRknKngk numeric, l_inGnrTaishoZndk numeric, l_inSzeiRate numeric, l_outTesuShuruiCd OUT TEXT, l_outTesuKngk OUT numeric, l_outTesuZei OUT numeric , OUT extra_param char) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipi001k14r01_03_prevzerodivision ( l_inNumber numeric ) RETURNS char AS $body$
BEGIN
	IF l_inNumber > 0 THEN
		RETURN l_inNumber;
	ELSE
		RETURN 1;
	END IF;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi001k14r01_03_prevzerodivision ( l_inNumber numeric ) FROM PUBLIC;