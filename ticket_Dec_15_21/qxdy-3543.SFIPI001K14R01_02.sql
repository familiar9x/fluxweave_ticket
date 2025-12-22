




CREATE OR REPLACE FUNCTION sfipi001k14r01_02 ( l_inItakuKaishaCd MGR_KIHON_VIEW.ITAKU_KAISHA_CD%TYPE, l_inKijunYmd BD_NYUSHUKIN.TORIHIKI_YMD%TYPE ) RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2013
-- * 会社名: JIP
-- *
-- * 概要：  入金・出金一括処理画面より起動される別段預金・会計登録データの一括作成機能のうち
-- *         元利払入金に関するデータを作成するプログラム
-- * 
-- * @author	R.Handa
-- * @version	$Id: SFIPI001K14R01_02.sql,v 1.4 2014/08/22 00:46:51 ito Exp $
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
	C_PRGRAM_ID				CONSTANT text := 'SFIPI001K14R01_02';	-- プログラムＩＤ
	C_SAIBAN_SHURUI			CONSTANT text := 'A';						-- 採番種別（支払基金請求）
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	gRtnCd					numeric := pkconstant.success();				-- リターンコード
	cNyushukkinKbn			BD_NYUSHUKIN.BD_NYUSHUKIN_KBN%TYPE := NULL;-- セットする入出金区分
	cGnrKbn					BD_NYUSHUKIN.GNR_KBN%TYPE := NULL;			-- セットする元利区分
	cKknTorihikiKbn			BD_NYUSHUKIN.TORIHIKI_KBN%TYPE := NULL;	-- セットする取引区分（基金レコード用）
	cTesTorihikiKbn			BD_NYUSHUKIN.TORIHIKI_KBN%TYPE := NULL;	-- セットする取引区分（手数料レコード用）
	cTorihikiSKbn			BD_NYUSHUKIN.TORIHIKI_S_KBN%TYPE := NULL;	-- セットする取引詳細区分
	cKessaiNo				BD_NYUSHUKIN.KESSAI_NO%TYPE := NULL;		-- セットする決済番号
	nKessaiNoEdaNum			numeric := 0;								-- セットする決済番号枝番用の数値
	vKeyMgrCd				TESURYO.MGR_CD%TYPE := NULL;				-- 決済番号判定用キー_銘柄コード
--==============================================================================
--                  カーソル定義                                                
--==============================================================================
	-- 基金異動履歴情報の取得
	curKikinIdo CURSOR FOR
		SELECT
			KBN,
			MGR_CD,
			MAX(SHOKAN_KBN) AS SHOKAN_KBN,
			MAX(KKN_KNGK) AS KKN_KNGK,
			MAX(TES_KNGK) AS TES_KNGK,
			MAX(TES_ZEI) AS TES_ZEI
		FROM
			-- ①元金
(SELECT
				'1' AS KBN,
				K02.MGR_CD,
				MG3.SHOKAN_KBN,
				SUM(CASE WHEN K02.KKN_IDO_KBN = '11' THEN K02.KKN_NYUKIN_KNGK ELSE 0 END) AS KKN_KNGK,
				SUM(CASE WHEN K02.KKN_IDO_KBN = '12' THEN K02.KKN_NYUKIN_KNGK ELSE 0 END) AS TES_KNGK,
				SUM(CASE WHEN K02.KKN_IDO_KBN = '13' THEN K02.KKN_NYUKIN_KNGK ELSE 0 END) AS TES_ZEI
			FROM
				KIKIN_IDO K02,
				MGR_SHOKIJ MG3,
				MGR_KIHON_VIEW VMG1
			WHERE
				K02.ITAKU_KAISHA_CD = l_inItakuKaishaCd and
				K02.IDO_YMD = l_inKijunYmd and
				K02.TSUKA_CD = 'JPY' and
				K02.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD and
				K02.MGR_CD = VMG1.MGR_CD and
				K02.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD and
				K02.MGR_CD = MG3.MGR_CD and
				K02.RBR_KJT = MG3.SHOKAN_KJT and
				K02.KKN_IDO_KBN like '1_'
			GROUP BY
--				K02.IDO_YMD,
				K02.MGR_CD,
				MG3.SHOKAN_KBN
			-- ②利払
			
UNION ALL

			SELECT
				'2' AS KBN,
				K02.MGR_CD,
				' ' AS SHOKAN_KBN,
				SUM(CASE WHEN K02.KKN_IDO_KBN = '21' THEN K02.KKN_NYUKIN_KNGK ELSE 0 END) AS KKN_KNGK,
				SUM(CASE WHEN K02.KKN_IDO_KBN = '22' THEN K02.KKN_NYUKIN_KNGK ELSE 0 END) AS TES_KNGK,
				SUM(CASE WHEN K02.KKN_IDO_KBN = '23' THEN K02.KKN_NYUKIN_KNGK ELSE 0 END) AS TES_ZEI
			FROM
				KIKIN_IDO K02,
				MGR_KIHON_VIEW VMG1
			WHERE
				K02.ITAKU_KAISHA_CD = l_inItakuKaishaCd and
				K02.IDO_YMD = l_inKijunYmd and
				K02.TSUKA_CD = 'JPY' and
				K02.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD and
				K02.MGR_CD = VMG1.MGR_CD and
				K02.KKN_IDO_KBN like '2_'
			GROUP BY
				K02.MGR_CD
			-- ③返戻元金
			
UNION ALL

			SELECT
				'6' AS KBN,
				K02.MGR_CD,
				MG3.SHOKAN_KBN,
				SUM(CASE WHEN K02.KKN_IDO_KBN = '68' THEN 0 ELSE K02.KKN_SHUKIN_KNGK END) AS KKN_KNGK,
				SUM(CASE WHEN K02.KKN_IDO_KBN = '68' THEN K02.KKN_SHUKIN_KNGK ELSE 0 END) AS TES_KNGK,
				0 AS TES_ZEI
			FROM
				KIKIN_IDO K02,
				MGR_SHOKIJ MG3,
				MGR_KIHON_VIEW VMG1
			WHERE
				K02.ITAKU_KAISHA_CD = l_inItakuKaishaCd and
				K02.IDO_YMD = l_inKijunYmd and
				K02.TSUKA_CD = 'JPY' and
				K02.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD and
				K02.MGR_CD = VMG1.MGR_CD and
				K02.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD and
				K02.MGR_CD = MG3.MGR_CD and
				K02.RBR_KJT = MG3.SHOKAN_KJT and
				K02.KKN_IDO_KBN like '6_'
			GROUP BY
				K02.MGR_CD,
				MG3.SHOKAN_KBN
			-- ④返戻利払
			
UNION ALL

			SELECT
				'7' AS KBN,
				K02.MGR_CD,
				' ' AS SHOKAN_KBN,
				SUM(CASE WHEN K02.KKN_IDO_KBN = '78' THEN 0 ELSE K02.KKN_SHUKIN_KNGK END) AS KKN_KNGK,
				SUM(CASE WHEN K02.KKN_IDO_KBN = '78' THEN K02.KKN_SHUKIN_KNGK ELSE 0 END) AS TES_KNGK,
				0 AS TES_ZEI
			FROM
				KIKIN_IDO K02,
				MGR_KIHON_VIEW VMG1
			WHERE
				K02.ITAKU_KAISHA_CD = l_inItakuKaishaCd and
				K02.IDO_YMD = l_inKijunYmd and
				K02.TSUKA_CD = 'JPY' and
				K02.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD and
				K02.MGR_CD = VMG1.MGR_CD and
				K02.KKN_IDO_KBN like '7_'
			GROUP BY
				K02.MGR_CD
			)
		GROUP BY
			MGR_CD,KBN
		ORDER BY
			MGR_CD,KBN;
--==============================================================================
--                  サブルーチン                                                
--==============================================================================
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
	-- 基金異動履歴情報の取得
	FOR recKikinIdo IN curKikinIdo LOOP
		-- セットする取引区分・入出金区分の判定
		-- ①元金・②利金の場合
		IF (recKikinIdo.KBN in ('1','2')) THEN
			-- 取引区分：21（基金入金）・31（元利払手数料入金）をセット
			cKknTorihikiKbn := '21';
			cTesTorihikiKbn := '31';
			-- 入出金区分：1（入金）をセット
			cNyushukkinKbn := '1';
		-- ③返戻元金・④返戻利金
		ELSIF (recKikinIdo.KBN in ('6','7')) THEN
			-- 取引区分：23（基金返戻）・33（元利払手数料返戻）をセット
			cKknTorihikiKbn := '23';
			cTesTorihikiKbn := '33';
			-- 入出金区分：2（出金）をセット
			cNyushukkinKbn := '2';
		-- ○それ以外（ここを通ることはないはずだが、念のため）
		ELSE
			-- NULLをセットしておく
			cKknTorihikiKbn := NULL;
			cTesTorihikiKbn := NULL;
			cNyushukkinKbn := NULL;
		END IF;
		-- セットする元利区分・取引詳細区分の判定
		-- ①元金・③返戻元金の場合
		IF (recKikinIdo.KBN in ('1','6')) THEN
			-- 元利区分：0（元金）をセット
			cGnrKbn := '0';
			-- 償還区分によって判定
			IF (recKikinIdo.SHOKAN_KBN in ('20','21')) THEN
				-- 償還区分：20（定時定額償還）・21（定時不定額償還）のとき、取引詳細区分：21（定時償還）をセット
				cTorihikiSKbn := '21';
			ELSIF (recKikinIdo.SHOKAN_KBN = '41') THEN
				-- 償還区分：41（コール（一部））のとき、取引詳細区分：22（一部繰上償還）をセット
				cTorihikiSKbn := '22';
			ELSIF (recKikinIdo.SHOKAN_KBN = '40') THEN
				-- 償還区分：40（コール（全額））のとき、取引詳細区分：23（全額繰上償還）をセット
				cTorihikiSKbn := '23';
			ELSIF (recKikinIdo.SHOKAN_KBN = '10') THEN
				-- 償還区分：10（満期償還）のとき、取引詳細区分：24（満期償還）をセット
				cTorihikiSKbn := '24';
			ELSIF (recKikinIdo.SHOKAN_KBN = '50') THEN
				-- 償還区分：50（プットオプション）のとき、取引詳細区分：25（プットオプション）をセット
				cTorihikiSKbn := '25';
			ELSE
				-- それ以外のときNULLをセット（ここを通ることはないはずだが、念のため）
				cTorihikiSKbn := NULL;
			END IF;
		-- ②利金・④返戻利金の場合
		ELSIF (recKikinIdo.KBN in ('2','7')) THEN
			-- 元利区分：1（利金）をセット
			cGnrKbn := '1';
			-- 取引詳細区分：26（利金）をセット
			cTorihikiSKbn := '26';
		-- ○それ以外（ここを通ることはないはずだが、念のため）
		ELSE
			-- NULLをセットしておく
			cGnrKbn := NULL;
			cTorihikiSKbn := NULL;
		END IF;
		-- 決済番号の判定（新しい番号を取得する場合は、枝番用数値をリセット）
		IF (coalesce(vKeyMgrCd::text, '') = '' or vKeyMgrCd <> recKikinIdo.MGR_CD) THEN
			cKessaiNo := PKIPI000K14R01.getKessaiNo(l_inItakuKaishaCd,C_SAIBAN_SHURUI);
			nKessainoEdaNum := 0;
		END IF;
		-- 基金分の入金データを作成する
		IF (recKikinIdo.KKN_KNGK > 0) THEN
			-- 決済番号枝番用数値の加算
			nKessaiNoEdaNum := nKessaiNoEdaNum + 1;
			-- insert処理
			gRtnCd := PKIPI000K14R01.insertBD(
						l_inKijunYmd,						-- 基準日
						l_inItakuKaishaCd,					-- 委託会社コード
						recKikinIdo.MGR_CD,					-- 銘柄コード
						l_inKijunYmd,						-- 取引日：基準日
						cKknTorihikiKbn,					-- 取引区分
						cTorihikiSKbn,						-- 取引詳細区分
						cNyushukkinKbn,						-- 入出金区分
						cGnrKbn,							-- 元利区分
						'2',								-- 現登区分：2（振替債）
						recKikinIdo.KKN_KNGK,				-- 金額
						0,									-- 消費税
						cKessaiNo,							-- 決済番号
						TO_CHAR(nKessaiNoEdaNum,'FM000'),	-- 決済番号枝番
						NULL,								-- 金融証券区分
						NULL,								-- 金融機関コード
						NULL,								-- 口座区分
						NULL,								-- 税区分
						NULL,								-- 相手方資金決済会社_金融機関コード
						NULL,								-- 相手方資金決済会社_支店コード
						NULL,								-- 手数料種類コード
						NULL,								-- 分配先金融証券区分
						NULL 								-- 分配先金融機関コード
			);
			IF (gRtnCd <> pkconstant.success()) THEN
				CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '別段預金INSERT処理エラー');
				RETURN pkconstant.FATAL();
			END IF;
		END IF;
		-- 手数料額がある場合、手数料分の入金データを作成する
		IF (recKikinIdo.TES_KNGK > 0) THEN
			-- 決済番号枝番用数値の加算
			nKessaiNoEdaNum := nKessaiNoEdaNum + 1;
			-- insert処理
			gRtnCd := PKIPI000K14R01.insertBD(
						l_inKijunYmd,						-- 基準日
						l_inItakuKaishaCd,					-- 委託会社コード
						recKikinIdo.MGR_CD,					-- 銘柄コード
						l_inKijunYmd,						-- 取引日：基準日
						cTesTorihikiKbn,					-- 取引区分
						cTorihikiSKbn,						-- 取引詳細区分
						cNyushukkinKbn,						-- 入出金区分
						cGnrKbn,							-- 元利区分
						'2',								-- 現登区分：2（振替債）
						recKikinIdo.TES_KNGK,				-- 金額
						recKikinIdo.TES_ZEI,				-- 消費税
						cKessaiNo,							-- 決済番号
						TO_CHAR(nKessaiNoEdaNum,'FM000'),	-- 決済番号枝番
						NULL,								-- 金融証券区分
						NULL,								-- 金融機関コード
						NULL,								-- 口座区分
						NULL,								-- 税区分
						NULL,								-- 相手方資金決済会社_金融機関コード
						NULL,								-- 相手方資金決済会社_支店コード
						NULL,								-- 手数料種類コード
						NULL,								-- 分配先金融証券区分
						NULL 								-- 分配先金融機関コード
			);
			IF (gRtnCd <> pkconstant.success()) THEN
				CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '別段預金INSERT処理エラー');
				RETURN pkconstant.FATAL();
			END IF;
		END IF;
		-- 決済番号判定用キーへの値セット（銘柄コードを用いる）
		vKeyMgrCd := recKikinIdo.MGR_CD;
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
-- REVOKE ALL ON FUNCTION sfipi001k14r01_02 ( l_inItakuKaishaCd MGR_KIHON_VIEW.ITAKU_KAISHA_CD%TYPE, l_inKijunYmd BD_NYUSHUKIN.TORIHIKI_YMD%TYPE ) FROM PUBLIC;