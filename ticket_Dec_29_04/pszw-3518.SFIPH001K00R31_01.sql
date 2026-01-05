




CREATE OR REPLACE FUNCTION sfiph001k00r31_01 ( l_inKaiinId text    -- 会員ID(委託会社コード)
 ) RETURNS numeric AS $body$
DECLARE

--*
--* 著作権:Copyright(c)2006
--* 会社名:JIP
--*
--* 概要　:利金の端数差額の会計処理
--*        （親ＳＰより、委託会社コードを引数として受け取る）
--*
--* 引数　:l_inKaiinId:会員ＩＤ（委託会社コード）
--*
--* 返り値: 0:正常
--*         2:正常 - 対象データなし
--*        99:異常
--*
--* @author ASK
--* @version $Id: SFIPH001K00R31_01.sql,v 1.8 2010/11/17 09:38:16 kuwabara Exp $
--*
--***************************************************************************
--* ログ　:
--* 　　　日付  開発者名    目的
--* -------------------------------------------------------------------------
--*　2006.04.05 ASK         新規作成
--***************************************************************************
--
	--==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_FUNCTION_ID CONSTANT text := 'SFIPH001K00R31_01'; -- ファンクションＩＤ
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	gSeqNo              integer;								-- シーケンス
	gGyomuYmd           text;		-- 業務日付
	gKijunYmd           char(8);							-- 基準日
	gKijunZndk          numeric;									-- 基準残高
	gRikinSgk           numeric;									-- 利金差額
	gRikinKng           numeric;									-- 利金金額
	gRikinKngOsae       numeric;									-- 利金金額（差押分）
	gGzeihiki_Bef_Kngk  numeric;									-- 国税引前利金額
	gMoptionFlg			text;			-- 金融債手数料設定判定フラグ
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	curMeisai CURSOR FOR
	SELECT
		K02.ITAKU_KAISHA_CD,                            -- 委託会社コード
		K02.MGR_CD,                                     -- 銘柄コード
		K02.RBR_KJT,                                    -- 利払期日
		K02.RBR_YMD,                                    -- 利払日
		K02.TSUKA_CD,                                   -- 通貨コード
		SUM(K02.KKN_SHUKIN_KNGK) AS KKN_SHUKIN_KNGK,	-- 基金出金額
		coalesce(MG2.TSUKARISHI_KNGK,0) AS TSUKARISHI_KNGK,  -- 1通貨あたりの利子金額
		pkIpaZndk.getKjnZndk(K02.ITAKU_KAISHA_CD,K02.MGR_CD,pkDate.GetZenYmd(K02.RBR_YMD),7) AS OSAE 	-- 差押設定金額
	FROM mgr_kihon_view vmg1, kikin_ido k02
LEFT OUTER JOIN mgr_rbrkij mg2 ON (K02.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD AND K02.MGR_CD = MG2.MGR_CD AND K02.RBR_YMD = MG2.RBR_YMD)
WHERE K02.ITAKU_KAISHA_CD = l_inKaiinId AND K02.RBR_YMD = gGyomuYmd AND K02.KKN_IDO_KBN IN ('41','51') AND K02.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD AND K02.MGR_CD = VMG1.MGR_CD AND VMG1.MGR_STAT_KBN = '1' AND (VMG1.JTK_KBN NOT IN ('2','5') OR (VMG1.JTK_KBN = '5' AND gMoptionFlg::character(1) = '1'))    GROUP BY
		K02.ITAKU_KAISHA_CD,
		K02.MGR_CD,
		K02.RBR_KJT,
		K02.RBR_YMD,
		K02.TSUKA_CD,
		MG2.TSUKARISHI_KNGK;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	CALL pkLog.debug(pkconstant.BATCH_USER(), C_FUNCTION_ID, C_FUNCTION_ID||' START');
	-- 入力パラメータチェック
	IF coalesce(l_inKaiinId::text, '') = '' THEN
		-- ログ書込み
		CALL pkLog.fatal('ECM701', SUBSTR(C_FUNCTION_ID,3,12), 'パラメータエラー');
		RETURN pkconstant.fatal();
	END IF;
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
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
	-- シーケンス初期化
	gSeqNo := 1;
	-- データ取得
	FOR recMeisai IN curMeisai LOOP
		-- 基準日を求める(利払日の前営業日)
		gKijunYmd := pkDate.GetZenYmd(recMeisai.RBR_YMD);
		-- 残高計算を行う
		gKijunZndk := pkIpaZndk.getKjnZndk(recMeisai.ITAKU_KAISHA_CD,recMeisai.MGR_CD,gKijunYmd,4);
		-- 「利金額a - 国税引前利金額b = 利金(差押分)c」を算出するため、利金額aを求める
		-- この時、利金額aには返戻額を差し引いた形にする必要がある。
		-- ただ、返戻額には支払手数料と支払手数料消費税が含まれているため、以下の式で求める。
		-- 利金（入金分） - ( 返戻額 - 支払手数料 - 支払手数料消費税 )
		BEGIN
			SELECT
				coalesce(K02.KKN_NYUKIN_KNGK, 0)
				- (coalesce(K03.HENREI_KNGK, 0) - coalesce(K03.SHR_TESU_KNGK, 0) - coalesce(K03.SHR_TESU_SZEI, 0)) AS RIKIN_KNGK  -- 利金額
			INTO STRICT
				gRikinKng
			FROM kikin_ido k02
LEFT OUTER JOIN kikin_henrei k03 ON (K02.ITAKU_KAISHA_CD = K03.ITAKU_KAISHA_CD AND K02.MGR_CD = K03.MGR_CD AND K02.RBR_KJT = K03.RBR_KJT AND K02.RBR_YMD = K03.RBR_YMD AND K02.TSUKA_CD = K03.TSUKA_CD AND '2' = K03.GNR_KBN)
WHERE K02.ITAKU_KAISHA_CD = recMeisai.ITAKU_KAISHA_CD AND K02.MGR_CD          = recMeisai.MGR_CD AND K02.RBR_KJT         = recMeisai.RBR_KJT AND K02.RBR_YMD         = recMeisai.RBR_YMD AND K02.TSUKA_CD        = recMeisai.TSUKA_CD AND K02.KKN_IDO_KBN     = '21';
		EXCEPTION
			WHEN no_data_found THEN
				-- 入金データが存在しない場合、利金額を０とし、処理を続行。
				gRikinKng := 0;
		END;
		-- 国税引前利金額算出
		IF recMeisai.TSUKA_CD = 'JPY' THEN
			gGzeihiki_Bef_Kngk := TRUNC(gKijunZndk * recMeisai.TSUKARISHI_KNGK::numeric, 0);
		Else
			gGzeihiki_Bef_Kngk := TRUNC(gKijunZndk * recMeisai.TSUKARISHI_KNGK::numeric, 2);
		END IF;
		-- 「利金額a - 国税引前利金額b = 利金(差押分)c」を算出
		gRikinKngOsae := gRikinKng - gGzeihiki_Bef_Kngk;
		-- 利金差額算出
		gRikinSgk := gGzeihiki_Bef_Kngk - recMeisai.KKN_SHUKIN_KNGK;
		IF gRikinSgk <> 0 THEN
			-- 挿入する前に対象データを削除する
			DELETE FROM RIKIN_HASUU
			WHERE
				ITAKU_KAISHA_CD = recMeisai.ITAKU_KAISHA_CD AND
				MGR_CD = recMeisai.MGR_CD AND
				RBR_KJT = recMeisai.RBR_KJT;
			INSERT INTO RIKIN_HASUU(
				ITAKU_KAISHA_CD,
				MGR_CD,
				RBR_KJT,
				RBR_YMD,
				TSUKA_CD,
				KEIJO_STS_KBN,
				KEIJO_YMD,
				GNR_ZNDK,
				GZEIHIKI_BEF_KNGK,
				OSAESETTEI_KNGK,
				RKN_KNGK_OSAE,
				RKN_SGK,
				GROUP_ID,
				KOUSIN_ID,
				SAKUSEI_ID
			)
			VALUES (
				recMeisai.ITAKU_KAISHA_CD,  -- 委託会社コード
				recMeisai.MGR_CD,           -- 銘柄コード
				recMeisai.RBR_KJT,          -- 利払期日
				recMeisai.RBR_YMD,          -- 利払日
				recMeisai.TSUKA_CD,         -- 通貨コード
				'0',                        -- 計上状況区分
				' ',                        -- 計上日
				gKijunZndk,                 -- 元利払対象残高
				gGzeihiki_Bef_Kngk,         -- 国税引前利金額
				recMeisai.OSAE,             -- 差押金額
				gRikinKngOsae,              -- 利金金額(差押分)
				gRikinSgk,                  -- 利金差額
				' ',                        -- グループID
				pkconstant.BATCH_USER(),      -- 更新者
				pkconstant.BATCH_USER()        -- 作成者
			);
			-- シーケンスのカウント
			gSeqNo := gSeqNo + 1;
		END IF;
	END LOOP;
	CALL pkLog.debug(pkconstant.BATCH_USER(), C_FUNCTION_ID, C_FUNCTION_ID||' END');
	RETURN pkconstant.success();
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SUBSTR(C_FUNCTION_ID,3,12), 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', SUBSTR(C_FUNCTION_ID,3,12), 'SQLERRM:' || SQLERRM);
	RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfiph001k00r31_01 ( l_inKaiinId text  ) FROM PUBLIC;