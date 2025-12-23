




CREATE OR REPLACE FUNCTION sfiph001k00r32_01 ( l_inKaiinId text ) RETURNS numeric AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2006
-- * 会社名:JIP
-- *
-- * 概要　:元利払手数料の会計処理を行う
-- *        （親ＳＰより、委託会社コードを引数として受け取る）
-- *
-- * 引数　:l_inKaiinId:会員ＩＤ（委託会社コード）
-- *
-- * 返り値: 0:正常
-- *        99:異常
-- *
-- * @author ASK
-- * @version $Id: SFIPH001K00R32_01.sql,v 1.19 2013/10/21 06:37:48 touma Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2006.04.05 ASK         新規作成
-- ***************************************************************************
--
	--==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_FUNCTION_ID  CONSTANT text := 'SFIPH001K00R32_01'; -- ファンクションＩＤ
	C_USER_ID      CONSTANT text   := pkconstant.BATCH_USER();
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	gGyomuYmd             text;          -- 業務日付
	gZenYmd               char(8);                                    -- 利払日の前日
	gRknTesuKngkDiff      numeric;      -- 利金支払手数料金額(差額分)
	gRknShrTesuSzeiDiff   numeric;  -- 利金支払手数料消費税金額(差額分)
	gGnknTesuKngkDiff     numeric;     -- 元金支払手数料金額(差額分)
	gGnknShrTesuSzeiDiff  numeric; -- 元金支払手数料消費税金額(差額分)
	shoriTiming           text;                          -- 処理制御値
	gMgrCd                text := ' ';           -- デバッグ用銘柄コード
	gOsaesetteiKngk       numeric := 0;         -- 差押金額
	gRknTesuKngkOsae      numeric := 0;      -- 利金支払手数料（差押分）
	gRknShrTesuSzeiOsae   numeric := 0;  -- 利金支払手数料消費税額（差押分）
	gGnknTesuKngkOsae     numeric := 0;     -- 元金支払手数料（差押分）
	gGnknShrTesuSzeiOsae  numeric := 0; -- 元金支払手数料消費税額（差押分）
	gRtnCd                numeric(1);
	gOutSqlCode           varchar(50);
	gOutSqlErrM           varchar(100);
	gMoptionFlg				text;						-- 金融債手数料設定判定フラグ
	gRknTesuKjngk			numeric := 0;	-- 元金支払手数料用手数料計算基準額
	gGnknTesuKjngk			numeric := 0;	-- 利金支払手数料用手数料計算基準額
	gCuttingOff				integer	:= 0;									-- 切捨て桁
	gRknTesuKngkSzeiOsae	numeric := 0;	-- 利金支払手数料消費税込（差押分）	
	gGnknTesuKngkSzeiOsae	numeric := 0;	-- 元金支払手数料消費税込（差押分）
	gShzKijunProcess		text;			-- 消費税率適用基準日対応
	gShzKijunYmd			varchar(8);							-- 消費税率適用基準日
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	curMeisai CURSOR FOR
		SELECT
			V1.ITAKU_KAISHA_CD,            -- 委託会社コード
			V1.MGR_CD,                     -- 銘柄コード
			K02W.RBR_KJT,                  -- 元利払期日
			K02W.RBR_YMD,                  -- 元利払日
			V1.TSUKA_CD,                   -- 通貨コード
			V1.GNR_ZNDK,                   -- 元利払残高
			V1.GZEIHIKI_BEF_KNGK,          -- 国税引前利金額
			V1.SHOKAN_KNGK,                -- 償還金額
		coalesce(pkIpaZndk.getKjnZndk(V1.ITAKU_KAISHA_CD, V1.MGR_CD, pkDate.getZenYMD(K02W.RBR_YMD), 7), '0') AS OSAESETTEI_KNGK,  --差押金額
			MG8.RKN_SHR_TESU_BUNSHI,
			MG8.RKN_SHR_TESU_BUNBO,
			MG8.SZEI_SEIKYU_KBN,
			MG8.GNKN_SHR_TESU_BUNSHI,
			MG8.GNKN_SHR_TESU_BUNBO,
			V1.GNKN_TESU_KNGK_DF,                                                             -- 元金支払手数料金額(分配分)
			V1.GNKN_SHR_TESU_SZEI_DF,                                                         -- 元金支払手数料消費税金額(分配分)
			V1.RKN_TESU_KNGK_DF,                                                              -- 利金支払手数料金額(分配分)
			V1.RKN_SHR_TESU_SZEI_DF,                                                          -- 利金支払手数料消費税金額(分配分)
			V1.GNKN_TESU_KNGK_NOTDF,                                                          -- 元金支払手数料金額(非分配分)
			V1.GNKN_SHR_TESU_SZEI_NOTDF,                                                      -- 元金支払手数料消費税金額(非分配分)
			V1.RKN_TESU_KNGK_NOTDF,                                                           -- 利金支払手数料金額(非分配分)
			V1.RKN_SHR_TESU_SZEI_NOTDF,                                                       -- 利金支払手数料消費税金額(非分配分)
			coalesce(K02W.GNKN_SHR_TESU_KNGK, 0) - coalesce(K03W.HENREI_GNKN_SHR_TESU_KNGK, 0) AS GNKN_SHR_TESU_KNGK,   -- 元金支払手数料
			coalesce(K02W.GNKN_SHR_TES_ZEI, 0) - coalesce(K03W.HENREI_GNKN_SHR_TES_ZEI, 0) AS GNKN_SHR_TES_ZEI,         -- 元金支払手数料消費税
			coalesce(K02W.RKN_SHR_TESU_KNGK, 0) - coalesce(K03W.HENREI_RKN_SHR_TESU_KNGK, 0) AS RKN_SHR_TESU_KNGK,      -- 利金支払手数料
			coalesce(K02W.RKN_SHR_TES_ZEI, 0) - coalesce(K03W.HENREI_RKN_SHR_TES_ZEI, 0) AS RKN_SHR_TES_ZEI,            -- 利金支払手数料消費税
			MG2.TSUKARISHI_KNGK,			-- 1通貨あたりの利子金額
			MG7.CHOOSE_FLG,                 -- 選択フラグ
			VMG1.HAKKO_TSUKA_CD,            -- 発行通貨コード
			VMG1.RBR_TSUKA_CD,              -- 利払通貨コード
			VMG1.SHOKAN_TSUKA_CD             -- 償還通貨コード
		FROM mgr_kihon_view vmg1, mgr_tesuryo_prm mg8, mgr_tesuryo_ctl mg7, (SELECT K02.ITAKU_KAISHA_CD,
					K02.MGR_CD,
					K02.RBR_YMD,
					K02.TSUKA_CD,
					trim(both MAX(K02.RBR_KJT)) AS RBR_KJT,
					SUM(CASE WHEN K02.KKN_IDO_KBN='12' THEN  K02.KKN_NYUKIN_KNGK  ELSE 0 END ) AS GNKN_SHR_TESU_KNGK, -- 元金支払手数料
					SUM(CASE WHEN K02.KKN_IDO_KBN='13' THEN  K02.KKN_NYUKIN_KNGK  ELSE 0 END ) AS GNKN_SHR_TES_ZEI,   -- 元金支払手数料消費税
					SUM(CASE WHEN K02.KKN_IDO_KBN='22' THEN  K02.KKN_NYUKIN_KNGK  ELSE 0 END ) AS RKN_SHR_TESU_KNGK,  -- 利金支払手数料
					SUM(CASE WHEN K02.KKN_IDO_KBN='23' THEN  K02.KKN_NYUKIN_KNGK  ELSE 0 END ) AS RKN_SHR_TES_ZEI      -- 利金支払手数料消費税
				FROM KIKIN_IDO K02
				WHERE K02.KKN_IDO_KBN IN ('12', '13', '22', '23')
				AND K02.ITAKU_KAISHA_CD = l_inKaiinId
				AND K02.RBR_YMD = gGyomuYmd
				GROUP BY K02.ITAKU_KAISHA_CD, K02.MGR_CD, K02.RBR_YMD, K02.TSUKA_CD) k02w, (SELECT K09W.ITAKU_KAISHA_CD,
					K09W.TSUKA_CD,
					K09W.MGR_CD,
					K09W.GNR_YMD,
					CASE WHEN SUM(K09W.GNR_JISSHITSU_ZNDK)=0 THEN  SUM(K09W.GNR_ZNDK)  ELSE SUM(K09W.GNR_JISSHITSU_ZNDK) END  AS GNR_ZNDK,
					SUM(K09W.GZEIHIKI_BEF_KNGK) AS GZEIHIKI_BEF_KNGK,
					SUM(K09W.SHOKAN_KNGK) AS SHOKAN_KNGK,                     -- 償還金額
					SUM(K09W.GNKN_TESU_KNGK_DF) AS GNKN_TESU_KNGK_DF,
					SUM(K09W.GNKN_SHR_TESU_SZEI_DF) AS GNKN_SHR_TESU_SZEI_DF,
					SUM(K09W.RKN_TESU_KNGK_DF) AS RKN_TESU_KNGK_DF,
					SUM(K09W.RKN_SHR_TESU_SZEI_DF) AS RKN_SHR_TESU_SZEI_DF,
					SUM(K09W.GNKN_TESU_KNGK_NOTDF) AS GNKN_TESU_KNGK_NOTDF,
					SUM(K09W.GNKN_SHR_TESU_SZEI_NOTDF) AS GNKN_SHR_TESU_SZEI_NOTDF,
					SUM(K09W.RKN_TESU_KNGK_NOTDF) AS RKN_TESU_KNGK_NOTDF,
					SUM(K09W.RKN_SHR_TESU_SZEI_NOTDF) AS RKN_SHR_TESU_SZEI_NOTDF
				FROM
					-- 元利払手数料分配ワークテーブルから分配・非分配ごとの合計を算出するためのテーブル K09W
					(SELECT
						K09.ITAKU_KAISHA_CD,
						K09.DISTRI_KBN,
						K09.TSUKA_CD,
						K09.MGR_CD,
						K09.GNR_YMD,
						coalesce(SUM(K09.GNR_ZNDK), 0) AS GNR_ZNDK,
                        coalesce(SUM(K09.GNR_JISSHITSU_ZNDK), 0) AS GNR_JISSHITSU_ZNDK,
						coalesce(SUM(K09.GZEIHIKI_BEF_CHOKYU_KNGK), 0) AS GZEIHIKI_BEF_KNGK,         -- 国税引前利金額
						coalesce(SUM(K09.SHOKAN_KNGK), 0) AS SHOKAN_KNGK,                            -- 償還金額
						CASE WHEN K09.DISTRI_KBN = '1' THEN SUM(K09.GNKN_SHR_TESU_KNGK) ELSE 0 END AS GNKN_TESU_KNGK_DF,
						CASE WHEN K09.DISTRI_KBN = '1' THEN SUM(K09.GNKN_SHR_TES_ZEI)   ELSE 0 END AS GNKN_SHR_TESU_SZEI_DF,
						CASE WHEN K09.DISTRI_KBN = '1' THEN SUM(K09.RKN_SHR_TESU_KNGK)  ELSE 0 END AS RKN_TESU_KNGK_DF,
						CASE WHEN K09.DISTRI_KBN = '1' THEN SUM(K09.RKN_SHR_TES_ZEI)    ELSE 0 END AS RKN_SHR_TESU_SZEI_DF,
						CASE WHEN K09.DISTRI_KBN = '2' THEN SUM(K09.GNKN_SHR_TESU_KNGK) ELSE 0 END AS GNKN_TESU_KNGK_NOTDF,
						CASE WHEN K09.DISTRI_KBN = '2' THEN SUM(K09.GNKN_SHR_TES_ZEI)   ELSE 0 END AS GNKN_SHR_TESU_SZEI_NOTDF,
						CASE WHEN K09.DISTRI_KBN = '2' THEN SUM(K09.RKN_SHR_TESU_KNGK)  ELSE 0 END AS RKN_TESU_KNGK_NOTDF,
						CASE WHEN K09.DISTRI_KBN = '2' THEN SUM(K09.RKN_SHR_TES_ZEI)    ELSE 0 END AS RKN_SHR_TESU_SZEI_NOTDF
					FROM GANRITES_BUNPAI_WK K09
					WHERE K09.USER_ID = C_USER_ID
					  AND K09.ITAKU_KAISHA_CD = l_inKaiinId
					  AND K09.GNR_YMD = gGyomuYmd
					GROUP BY K09.ITAKU_KAISHA_CD,
						K09.DISTRI_KBN,
						K09.TSUKA_CD,
						K09.MGR_CD,
						K09.GNR_YMD) K09W 
			GROUP BY
				K09W.ITAKU_KAISHA_CD, K09W.TSUKA_CD, K09W.MGR_CD, K09W.GNR_YMD) v1
LEFT OUTER JOIN (SELECT K03.ITAKU_KAISHA_CD,
					K03.MGR_CD,
					K03.RBR_YMD,
					K03.TSUKA_CD,
					trim(both MAX(K03.RBR_KJT)) AS RBR_KJT,
					SUM(CASE WHEN K03.GNR_KBN='1' THEN  K03.SHR_TESU_KNGK  ELSE 0 END ) AS HENREI_GNKN_SHR_TESU_KNGK, -- 元金分返戻支払手数料
					SUM(CASE WHEN K03.GNR_KBN='1' THEN  K03.SHR_TESU_SZEI  ELSE 0 END ) AS HENREI_GNKN_SHR_TES_ZEI,   -- 元金分返戻支払手数料消費税額
					SUM(CASE WHEN K03.GNR_KBN='2' THEN  K03.SHR_TESU_KNGK  ELSE 0 END ) AS HENREI_RKN_SHR_TESU_KNGK,  -- 元金分返戻支払手数料
					SUM(CASE WHEN K03.GNR_KBN='2' THEN  K03.SHR_TESU_SZEI  ELSE 0 END ) AS HENREI_RKN_SHR_TES_ZEI      -- 元金分返戻支払手数料消費税額
				FROM KIKIN_HENREI K03
				WHERE K03.ITAKU_KAISHA_CD = l_inKaiinId
				AND K03.RBR_YMD = gGyomuYmd
				GROUP BY K03.ITAKU_KAISHA_CD, K03.MGR_CD, K03.RBR_YMD, K03.TSUKA_CD) k03w ON (V1.ITAKU_KAISHA_CD = K03W.ITAKU_KAISHA_CD AND V1.MGR_CD = K03W.MGR_CD AND V1.TSUKA_CD = K03W.TSUKA_CD AND V1.GNR_YMD = K03W.RBR_YMD)
LEFT OUTER JOIN mgr_rbrkij mg2 ON (V1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD AND V1.MGR_CD = MG2.MGR_CD AND V1.GNR_YMD = MG2.RBR_YMD)
WHERE V1.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD AND V1.MGR_CD = VMG1.MGR_CD AND V1.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD AND V1.MGR_CD = MG8.MGR_CD AND V1.ITAKU_KAISHA_CD = K02W.ITAKU_KAISHA_CD AND V1.MGR_CD = K02W.MGR_CD AND V1.TSUKA_CD = K02W.TSUKA_CD AND V1.GNR_YMD = K02W.RBR_YMD        AND V1.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD AND V1.MGR_CD = MG7.MGR_CD AND MG7.TESU_SHURUI_CD = '82' AND VMG1.KK_KANYO_FLG <> '2' AND (VMG1.JTK_KBN NOT IN ('2','5') OR (VMG1.JTK_KBN = '5' AND gMoptionFlg::character(1) = '1')) AND VMG1.MGR_STAT_KBN = '1';  -- 承認済み
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	CALL pkLog.debug(C_USER_ID, C_FUNCTION_ID, C_FUNCTION_ID||' START');
	-- 入力パラメータチェック
	IF coalesce(l_inKaiinId::text, '') = '' THEN
		-- ログ書込み
		CALL pkLog.fatal('ECM701', SUBSTR(C_FUNCTION_ID,3,12), 'パラメータエラー');
		RETURN pkconstant.fatal();
	END IF;
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
	-- 処理制御値を取得
	shoriTiming := pkcontrol.getCtlValue(l_inKaiinId,'SFBUNPAIGNRTES0','0');
 	-- MOPTION_KANRIテーブルより、金融債手数料登録判定フラグを取得する(レコードがなかった場合
 	-- エラーメッセージをログに書き込み、valueは'0'とする)
	begin
		SELECT	M92.OPTION_FLG AS OPTION_FLG
		INTO STRICT	gMoptionFlg
		FROM	MOPTION_KANRI M92
		WHERE	M92.KEY_CD = l_inKaiinId
		AND		M92.OPTION_CD = 'IPN1001108011';
	exception
		WHEN no_data_found THEN
			-- MOPTION_KANRIにデータが存在しない場合、エラーログを出力させるが処理は続行。
			CALL pkLog.error('ECM305', C_FUNCTION_ID, '金融債手数料登録判定フラグ NO_DATA_FOUND error');
			gMoptionFlg := '0';
	end;
	-- 消費税率適用基準日フラグ(1:取引日ベース, 0:徴求日ベース(デフォルト))取得
	gShzKijunProcess := pkControl.getCtlValue(l_inKaiinId, 'ShzKijun', '0');
	-- 元利金手数料分配の計算処理（関与分）
	SELECT f.l_outsqlcode, f.l_outsqlerrm, f.extra_param 
	INTO gOutSqlCode, gOutSqlErrM, gRtnCd 
	FROM rh_mufg_ipa.sfBunpaiGnrtes(l_inKaiinId, C_USER_ID, substring(gGyomuYmd, 1, 6)) AS f;
	IF gRtnCd <> pkconstant.success() THEN
		CALL pkLog.error('', C_FUNCTION_ID, 'SFBUNPAIGNRTES呼び出しでエラーが発生しました。元利金手数料分配ワークが作成されていません。');
		RETURN gRtnCd;
	END IF;
	-- 挿入する前に対象データを削除する
	DELETE FROM TESURYO_HASUU
	WHERE ITAKU_KAISHA_CD = l_inKaiinId AND GNR_YMD = gGyomuYmd;
	-- データ取得
	FOR recMeisai IN curMeisai
	LOOP
		-- 差押分算出
		gZenYmd := pkDate.getZenYmd(recMeisai.RBR_YMD);
		-- 差押金額
		gOsaesetteiKngk := pkIpaZndk.getKjnZndk(recMeisai.ITAKU_KAISHA_CD, recMeisai.MGR_CD, gZenYMD, 7);
		-- 元金支払手数料用手数料計算基準額算出
		-- 元利払手数料分配結果の通貨コードが銘柄の償還通貨と異なる場合は元金手数料の支払がないので、基準額は０となる。
		IF recMeisai.TSUKA_CD = recMeisai.SHOKAN_TSUKA_CD THEN
			gGnknTesuKjngk := sfCalcShokanKngkOsae(recMeisai.ITAKU_KAISHA_CD, recMeisai.MGR_CD, gGyomuYmd, 1);
		ELSE
			gGnknTesuKjngk := 0;
		END IF;
       	gRknTesuKjngk := 0;
		-- 利金支払手数料が利金ベースの場合、差押金額に通貨あたり利子額を乗算したものを利金支払手数料用手数料計算基準額とする
		IF recMeisai.CHOOSE_FLG = '1' THEN
			-- 利金ベースのときは元利払手数料分配結果の通貨コードと銘柄の利払通貨が異なるときは利金手数料の支払がないので、基準額は０となる。
			IF recMeisai.TSUKA_CD = recMeisai.RBR_TSUKA_CD THEN
				-- 切捨て桁のセット(通貨単位によって分ける)
				IF (recMeisai.TSUKA_CD = 'JPY') THEN
					gCuttingOff := 0;
				ELSE
					gCuttingOff := 2;
				END IF;
				gRknTesuKjngk := TRUNC(gOsaesetteiKngk * recMeisai.TSUKARISHI_KNGK::numeric, gCuttingOff::int);
			END IF;
       	-- 利金支払手数料が元金ベースかつ利金額≠0もしくは利金額＝0で「利金0利金手数料(元金)請求」設定されている場合
       	ELSIF recMeisai.TSUKARISHI_KNGK <> 0
					OR (recMeisai.TSUKARISHI_KNGK = 0 AND sfRkntesGb_CalcChk(recMeisai.ITAKU_KAISHA_CD, recMeisai.MGR_CD, gGyomuYmd) = 1) THEN
			-- 元金ベースのときは元利払手数料分配結果の通貨コードと銘柄の発行通貨が異なるときは利金手数料の支払がないので、基準額は０となる。
			IF recMeisai.TSUKA_CD = recMeisai.HAKKO_TSUKA_CD THEN
       			gRknTesuKjngk := gOsaesetteiKngk;
			END IF;
		END IF;
		-- 利金支払手数料税抜金額(差押分)と利金支払手数料消費税金額(差押分)を求める
		IF recMeisai.RKN_SHR_TESU_BUNBO > 0 THEN 	-- 0割対応
			-- 消費税率適用基準日切り替え
			IF gShzKijunProcess = '1' THEN
				gShzKijunYmd := recMeisai.RBR_YMD;
			ELSE
				-- 基金異動履歴から利金支払手数料徴求日を取得する
				gShzKijunYmd := PKIPACALCTESURYO.getTesuChokyuYmd(recMeisai.ITAKU_KAISHA_CD, recMeisai.MGR_CD, recMeisai.RBR_YMD, '22');
			END IF;
			SELECT f.l_outtesukngknuki, f.l_outtesukngkkomi, f.l_outszeikngk, f.extra_param 
			INTO gRknTesuKngkOsae, gRknTesuKngkSzeiOsae, gRknShrTesuSzeiOsae, gRtnCd 
			FROM pkipacalctesukngk.getTesuZeiCommon(recMeisai.ITAKU_KAISHA_CD, recMeisai.MGR_CD, 
													gRknTesuKjngk, recMeisai.RKN_SHR_TESU_BUNSHI, 
													recMeisai.RKN_SHR_TESU_BUNBO, recMeisai.TSUKA_CD, 
													gShzKijunYmd, shoriTiming) AS f;
			IF gRtnCd <> pkconstant.success() THEN
			-- 正常終了していなければ、異常終了("1"か"99")をリターンさせる。
--		   	共通関数の方でログに出力させているので、ここでは特にログに出力は行わない 
				RETURN gRtnCd;
			END IF;
        ELSE
        	gRknTesuKngkOsae := 0;
            gRknTesuKngkSzeiOsae := 0;
            gRknShrTesuSzeiOsae := 0;
		END IF;
		-- 元金支払手数料税抜金額(差押分)と元金支払手数料消費税金額(差押分)を求める
		IF recMeisai.GNKN_SHR_TESU_BUNBO > 0 THEN 	-- 0割対応
			-- 消費税率適用基準日切り替え
			IF gShzKijunProcess = '1' THEN
				gShzKijunYmd := recMeisai.RBR_YMD;
			ELSE
				-- 基金異動履歴から元金支払手数料徴求日を取得する
				gShzKijunYmd := PKIPACALCTESURYO.getTesuChokyuYmd(recMeisai.ITAKU_KAISHA_CD, recMeisai.MGR_CD, recMeisai.RBR_YMD, '12');
			END IF;
			SELECT f.l_outtesukngknuki, f.l_outtesukngkkomi, f.l_outszeikngk, f.extra_param 
			INTO gGnknTesuKngkOsae, gGnknTesuKngkSzeiOsae, gGnknShrTesuSzeiOsae, gRtnCd 
			FROM pkipacalctesukngk.getTesuZeiCommon(recMeisai.ITAKU_KAISHA_CD, recMeisai.MGR_CD, 
													gGnknTesuKjngk, recMeisai.GNKN_SHR_TESU_BUNSHI, 
													recMeisai.GNKN_SHR_TESU_BUNBO, recMeisai.TSUKA_CD, 
													gShzKijunYmd, shoriTiming) AS f;
			IF gRtnCd <> pkconstant.success() THEN
			-- 正常終了していなければ、異常終了("1"か"99")をリターンさせる。
--		   	共通関数の方でログに出力させているので、ここでは特にログに出力は行わない 
				RETURN gRtnCd;
			END IF;
        ELSE
        	gGnknTesuKngkOsae := 0;
            gGnknTesuKngkSzeiOsae := 0;
            gGnknShrTesuSzeiOsae := 0;
		END IF;
		-- 差額分算出
		-- 元金支払手数料金額(差額分)
		gGnknTesuKngkDiff := recMeisai.GNKN_SHR_TESU_KNGK - gGnknTesuKngkOsae - recMeisai.GNKN_TESU_KNGK_DF - recMeisai.GNKN_TESU_KNGK_NOTDF;
		-- 元金支払手数料消費税金額(差額分)
		gGnknShrTesuSzeiDiff := recMeisai.GNKN_SHR_TES_ZEI - gGnknShrTesuSzeiOsae - recMeisai.GNKN_SHR_TESU_SZEI_DF - recMeisai.GNKN_SHR_TESU_SZEI_NOTDF;
		-- 利金支払手数料金額(差額分)
		gRknTesuKngkDiff := recMeisai.RKN_SHR_TESU_KNGK - gRknTesuKngkOsae - recMeisai.RKN_TESU_KNGK_DF - recMeisai.RKN_TESU_KNGK_NOTDF;
		-- 利金支払手数料消費税金額(差額分)
		gRknShrTesuSzeiDiff := recMeisai.RKN_SHR_TES_ZEI - gRknShrTesuSzeiOsae - recMeisai.RKN_SHR_TESU_SZEI_DF - recMeisai.RKN_SHR_TESU_SZEI_NOTDF;
		-- デバッグ用
		gMgrCd := recMeisai.MGR_CD;
		-- データを挿入する
		INSERT INTO TESURYO_HASUU(
				ITAKU_KAISHA_CD,
				MGR_CD,
				GNRBARAI_KJT,
				GNR_YMD,
				TSUKA_CD,
				KEIJO_STS_KBN,
				GNR_ZNDK,
				GZEIHIKI_BEF_KNGK,
				SHOKAN_KNGK,
				OSAESETTEI_KNGK,
				RKN_TESU_KNGK_OSAE,
				RKN_SHR_TESU_SZEI_OSAE,
				GNKN_TESU_KNGK_OSAE,
				GNKN_SHR_TESU_SZEI_OSAE,
				RKN_TESU_KNGK_DF,
				RKN_SHR_TESU_SZEI_DF,
				GNKN_TESU_KNGK_DF,
				GNKN_SHR_TESU_SZEI_DF,
				RKN_TESU_KNGK_NOTDF,
				RKN_SHR_TESU_SZEI_NOTDF,
				GNKN_TESU_KNGK_NOTDF,
				GNKN_SHR_TESU_SZEI_NOTDF,
				RKN_TESU_KNGK_DIFF,
				RKN_SHR_TESU_SZEI_DIFF,
				GNKN_TESU_KNGK_DIFF,
				GNKN_SHR_TESU_SZEI_DIFF,
				KOUSIN_ID,
				SAKUSEI_ID
			)
			VALUES (
				recMeisai.ITAKU_KAISHA_CD,             -- 委託会社コード
				recMeisai.MGR_CD,                      -- 銘柄コード
				recMeisai.RBR_KJT,                     -- 元利払期日
				recMeisai.RBR_YMD,                     -- 元利払日
				recMeisai.TSUKA_CD,                    -- 通貨コード
				'0',                                   -- 計上状況区分
				recMeisai.GNR_ZNDK,                    -- 元利払対象残高
				recMeisai.GZEIHIKI_BEF_KNGK,           -- 国税引前利金額
				recMeisai.SHOKAN_KNGK,                 -- 償還金額
				recMeisai.OSAESETTEI_KNGK,             -- 差押金額
				gRknTesuKngkOsae,                      -- 利金支払手数料金額(差押分)
				gRknShrTesuSzeiOsae,                   -- 利金支払手数料消費税金額(差押分)
				gGnknTesuKngkOsae,                     -- 元金支払手数料金額(差押分)
				gGnknShrTesuSzeiOsae,                  -- 元金支払手数料消費税金額(差押分)
				recMeisai.RKN_TESU_KNGK_DF,            -- 利金支払手数料金額(分配分)
				recMeisai.RKN_SHR_TESU_SZEI_DF,        -- 利金支払手数料消費税金額(分配分)
				recMeisai.GNKN_TESU_KNGK_DF,           -- 元金支払手数料金額(分配分)
				recMeisai.GNKN_SHR_TESU_SZEI_DF,       -- 元金支払手数料消費税金額(分配分)
				recMeisai.RKN_TESU_KNGK_NOTDF,         -- 利金支払手数料金額(非分配分)
				recMeisai.RKN_SHR_TESU_SZEI_NOTDF,     -- 利金支払手数料消費税金額(非分配分)
				recMeisai.GNKN_TESU_KNGK_NOTDF,        -- 元金支払手数料金額(非分配分)
				recMeisai.GNKN_SHR_TESU_SZEI_NOTDF,    -- 元金支払手数料消費税金額(非分配分)
				gRknTesuKngkDiff,                      -- 利金支払手数料金額(差額分)
				gRknShrTesuSzeiDiff,                   -- 利金支払手数料消費税金額(差額分)
				gGnknTesuKngkDiff,                     -- 元金支払手数料金額(差額分)
				gGnknShrTesuSzeiDiff,                  -- 元金支払手数料消費税金額(差額分)
				C_USER_ID,                             -- 更新者
				C_USER_ID                               -- 作成者
			);
	END LOOP;
	CALL pkLog.debug(C_USER_ID, C_FUNCTION_ID, C_FUNCTION_ID||' END');
	RETURN pkconstant.success();
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SUBSTR(C_FUNCTION_ID,3,12), '銘柄コード：' || gMgrCd);
		CALL pkLog.fatal('ECM701', SUBSTR(C_FUNCTION_ID,3,12), 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', SUBSTR(C_FUNCTION_ID,3,12), 'SQLERRM:' || SQLERRM);
	RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfiph001k00r32_01 ( l_inKaiinId text ) FROM PUBLIC;