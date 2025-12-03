


DROP TYPE IF EXISTS sfipxb10k15r01_tgyomudataheader;
CREATE TYPE sfipxb10k15r01_tgyomudataheader AS (
		blank1				char(72) 				-- ブランク
	);
DROP TYPE IF EXISTS sfipxb10k15r01_tgyomudatadata;
CREATE TYPE sfipxb10k15r01_tgyomudatadata AS (
		dataTyp				char(3),			-- データ種別（データ作成）
		refNo				char(12),			-- リファレンスＮＯ
		trhkTyp				char(2),			-- 取引種別
		kssiDt				char(8),			-- 決済日
		blank1				char(8),			-- ブランク（決済時刻ＦＲＯＭ 〜 決済時刻ＴＯ）
		sknUkeKin			char(15),			-- 資金受渡金額
		sknUkeCd			char(7),			-- 資金受入先コード
		sknHaraiCd			char(7),			-- 資金払込先コード
		blank2				char(7),			-- ブランク（資金約定相手先コード）
		kssiNo				char(16),			-- 保振決済番号
		youinCd				char(4),		-- 要因コード
		blank3				char(5),			-- ブランク（元利金サイン１ 〜 元利金サイン５）
		daikoKbn			char(1),			-- プロパー事務代行区分
		kokyakuCd			char(12),			-- 顧客コード
		kokyakuKozaNo		char(8),			-- 顧客専用口座番号
		blank4				char(25) 				-- ブランク（予備）
	);


CREATE OR REPLACE FUNCTION sfipxb10k15r01 ( l_inIfId varchar 			-- 外部IFID
 ) RETURNS numeric AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2016
-- * 会社名:JIP
-- *
-- * 概  要:支払代理人が、他行（機構加入者）へ支払う元利金資金の決済予定（事務代行業務の資金）を債券決済代行システムに連携するデータを作成する。
-- *        作成したデータは外部IF送受信データテーブルに登録し、後続処理で債券決済代行システムに連携するデータとしてメッセージ送信（MQ）される。
-- *
-- * @author 山中 大輔
-- * @version $Id:$
-- *
-- * @param l_inIfId				外部IFID
-- * @return INTEGER 0:正常、99:異常、それ以外：エラー
-- *
-- ***************************************************************************
-- * ログ:
-- *    日付    開発者名		目的
-- * -------------------------------------------------------------------------
-- * 2016.11.18 山中			新規作成
-- ***************************************************************************
--
	--==============================================================================
	--					定数定義													
	--==============================================================================
	-- ファンクションＩＤ
	C_FUNCTION_ID			CONSTANT	varchar(50)	:= 'SFIPXB10K15R01';
	--==============================================================================
	--					変数定義													
	--==============================================================================
	gGyomuYmd				char(8)							:= '';		-- 業務日付
	gYokuEigyoYmd			char(8)							:= '';		-- 翌営業日
	gDenbunNo				numeric(8)						:= 0;		-- 電文通番
	gRefNo					numeric(8)						:= 0;		-- リファレンスＮＯ
	gMakeCnt				numeric	:= 0;		-- 作成回数
	gResult					integer							:= 0;		-- 共通部品の戻り値
	gMicHdr					char(172)						:= '';		-- MIC電文（ヘッダ）
	gDataNo					numeric	:= 0;		-- データ番号
	-- MIC電文・業務データ（業務ヘッダ）
	gGyomuDataHdr SFIPXB10K15R01_tGyomuDataHeader;
	-- MIC電文・業務データ（業務データ）
	gGyomuDataDat SFIPXB10K15R01_tGyomuDataData;
	--==============================================================================
	--					例外定義													
	--==============================================================================
	--==============================================================================
	--					カーソル定義												
	--==============================================================================
	-- 入金予定
	curMeisai CURSOR FOR
		-- ほふりから連携された機構関与銘柄
		SELECT
			MAX(K01.SHR_YMD)												AS SHR_YMD,					-- 支払日
			SUM(K01.GZEIHIKI_AFT_CHOKYU_KNGK + K01.SHOKAN_SEIKYU_KNGK)		AS SKN_UKEWATASHI_KNGK,		-- 資金受渡金額
			MAX(K01.AITE_SKN_KESSAI_BCD || K01.AITE_SKN_KESSAI_SCD)			AS SKN_UKEIRESAKI_CD,		-- 資金受入先コード
			K01.KESSAI_NO													AS KESSAI_BANGO,			-- 決済番号
			MAX(CASE
				WHEN SC18.SKN_KESSAI_CD <> K01.AITE_SKN_KESSAI_BCD || K01.AITE_SKN_KESSAI_SCD
				THEN '1'
				ELSE '0'
			END)															AS UTI_SOTO_FLG,			-- 内振外振フラグ
			MAX(JM01.SKN_KESSAI_CD)											AS SKN_HARAIKOMISAKI_CD,	-- 資金払込先コード
			MAX(LPAD(coalesce(RTRIM(BT02.RGS_KOZA_NO, ' '), '0'), 8, '0'))		AS RGS_KOZA_NO8,			-- ＲＴＧＳ口座番号
			MAX(RPAD(BT02.DAIKO_KOKYAKU_CD, 12, ' '))						AS DAIKO_KOKYAKU_CD 			-- 顧客コード
		FROM
			KIKIN_SEIKYU	K01,
			MITAKU_KAISHA	JM01,
			MITAKU_KAISHA2	BT02,
			SOWN_INFO		SC18
		WHERE (
				K01.ITAKU_KAISHA_CD = JM01.ITAKU_KAISHA_CD
				AND K01.ITAKU_KAISHA_CD = BT02.ITAKU_KAISHA_CD
				AND K01.SHR_YMD = gYokuEigyoYmd
				AND K01.KK_KANYO_UMU_FLG = '1'															-- '1'（機構関与方式）
				AND K01.TSUKA_CD = 'JPY'
				AND (K01.GZEIHIKI_AFT_CHOKYU_KNGK + K01.SHOKAN_SEIKYU_KNGK) > 0
				AND BT02.SKN_KESSAI_DAIKO_UMU = '1'														-- '1'（有）
			)
		GROUP BY K01.KESSAI_NO
		
UNION ALL

		-- IPAシステムから登録した機構非関与銘柄
		SELECT 
			MAX(BT12.SHR_YMD)												AS SHR_YMD,					-- 支払日
			SUM(BT12.GZEIHIKI_AFT_CHOKYU_KNGK + BT12.SHOKAN_SEIKYU_KNGK)	AS SKN_UKEWATASHI_KNGK,		-- 資金受渡金額
			MAX(BT12.AITE_SKN_KESSAI_BCD || BT12.AITE_SKN_KESSAI_SCD)		AS SKN_UKEIRESAKI_CD,		-- 資金受入先コード
			'9999999999999999'												AS KESSAI_BANGO,			-- 決済番号
			'0'																AS UTI_SOTO_FLG,			-- 内振外振フラグ
			MAX(JM01.SKN_KESSAI_CD)											AS SKN_HARAIKOMISAKI_CD,	-- 資金払込先コード
			MAX(LPAD(coalesce(RTRIM(BT02.RGS_KOZA_NO, ' '), '0'), 8, '0'))		AS RGS_KOZA_NO8,			-- ＲＴＧＳ口座番号
			MAX(RPAD(BT02.DAIKO_KOKYAKU_CD, 12, ' '))						AS DAIKO_KOKYAKU_CD 			-- 顧客コード
		FROM
			KIKIN_SEIKYU2	BT12,
			KIKIN_SEIKYU	K01,
			MITAKU_KAISHA	JM01,
			MITAKU_KAISHA2	BT02
		WHERE (
				BT12.ITAKU_KAISHA_CD = JM01.ITAKU_KAISHA_CD
				AND BT12.ITAKU_KAISHA_CD = BT02.ITAKU_KAISHA_CD
				AND BT12.ITAKU_KAISHA_CD = K01.ITAKU_KAISHA_CD
				AND BT12.MGR_CD = K01.MGR_CD
				AND BT12.SHR_YMD = K01.SHR_YMD
				AND BT12.TSUKA_CD = K01.TSUKA_CD
				AND BT12.FINANCIAL_SECURITIES_KBN = K01.FINANCIAL_SECURITIES_KBN
				AND BT12.BANK_CD = K01.BANK_CD
				AND BT12.KOZA_KBN = K01.KOZA_KBN
				AND BT12.TAX_KBN = K01.TAX_KBN
				AND BT12.SHR_YMD = gYokuEigyoYmd
				AND BT12.KNJ_FLG = ' '																	-- ' '（勘定処理対象）
				AND BT12.TSUKA_CD = 'JPY'
				AND (BT12.GZEIHIKI_AFT_CHOKYU_KNGK + BT12.SHOKAN_SEIKYU_KNGK) > 0
				AND BT02.SKN_KESSAI_DAIKO_UMU = '1'														-- '1'（有）
				AND K01.SHORI_KBN = '1'																	-- '1'（承認済）
			) 
		GROUP BY
			BT12.ITAKU_KAISHA_CD,
			BT12.KK_KANYO_UMU_FLG
		ORDER BY
			UTI_SOTO_FLG,
			SKN_UKEIRESAKI_CD,
			SKN_HARAIKOMISAKI_CD,
			KESSAI_BANGO,
			DAIKO_KOKYAKU_CD;
--==============================================================================
--					関数定義													
--==============================================================================
--==============================================================================
--					メイン処理													
--==============================================================================
BEGIN
	-- Initialize TYPE variables
	gGyomuDataHdr.blank1 := RPAD('', 72, ' ');
	gGyomuDataDat.dataTyp := '101';
	gGyomuDataDat.refNo := RPAD('', 12, ' ');
	gGyomuDataDat.trhkTyp := RPAD('', 2, ' ');
	gGyomuDataDat.kssiDt := RPAD('', 8, ' ');
	gGyomuDataDat.blank1 := RPAD('', 8, ' ');
	gGyomuDataDat.sknUkeKin := RPAD('', 15, ' ');
	gGyomuDataDat.sknUkeCd := RPAD('', 7, ' ');
	gGyomuDataDat.sknHaraiCd := RPAD('', 7, ' ');
	gGyomuDataDat.blank2 := RPAD('', 7, ' ');
	gGyomuDataDat.kssiNo := RPAD('', 16, ' ');
	gGyomuDataDat.youinCd := '1310';
	gGyomuDataDat.blank3 := RPAD('', 5, ' ');
	gGyomuDataDat.daikoKbn := '2';
	gGyomuDataDat.kokyakuCd := RPAD('', 12, ' ');
	gGyomuDataDat.kokyakuKozaNo := RPAD('', 8, ' ');
	gGyomuDataDat.blank4 := RPAD('', 25, ' ');
	CALL pkLog.debug('BATCH', C_FUNCTION_ID, '***** ' || C_FUNCTION_ID || ' START *****');
	-- 入力パラメータのチェック
	-- 外部IFID の必須チェック
	IF coalesce(l_inIfId::text, '') = '' THEN
		-- パラメータエラー
		CALL pkLog.error('ECM501', C_FUNCTION_ID, '外部IFID');
		RETURN pkconstant.error();
	END IF;
	RAISE NOTICE 'Parameter check passed. IF_ID: %', l_inIfId;
	-- 業務日付の取得
	gGyomuYmd := pkDate.getGyomuYmd();
	RAISE NOTICE 'gGyomuYmd: %', gGyomuYmd;
	--翌営業日の取得
	gYokuEigyoYmd := pkDate.getPlusDateBusiness(gGyomuYmd, 1, '1');
	RAISE NOTICE 'gYokuEigyoYmd: %', gYokuEigyoYmd;
	-- 外部ＩＦ送受信管理登録
	RAISE NOTICE 'Calling insGaibuIFKanri...';
	gResult := pkIpIF.insGaibuIFKanri(l_inIfId, gGyomuYmd, gMakeCnt);
	RAISE NOTICE 'insGaibuIFKanri result: %', gResult;
	IF gResult <> pkconstant.success() THEN
		RETURN gResult;
	END IF;
	RAISE NOTICE 'Starting cursor loop...';
	FOR rec IN curMeisai LOOP
		-- 初期化
		gDataNo := gDataNo + 1;
		RAISE NOTICE 'Processing record %, SKN_UKEWATASHI_KNGK: %', gDataNo, rec.SKN_UKEWATASHI_KNGK;
		-- 電文通番の取得
		gResult := pkIpIF.getIFNum(pkIpIF.C_NUMBERING_DENBUN_NO(), gDenbunNo);
		IF gResult <> pkconstant.success() THEN
			RETURN gResult;
		END IF;
		-- リファレンスＮＯの取得
		gResult := pkIpIF.getIFNum(pkIpIF.C_NUMBERING_REF_NO(), gRefNo);
		IF gResult <> pkconstant.success() THEN
			RETURN gResult;
		END IF;
		-- MIC電文（ヘッダ・決済代行・資金決済予定）の編集
		gMicHdr := SFIPXB09K15R01_MIC(pkIpIF.C_MOTO_GYOMU_ID_DAIKOU_SKNKSI(), pkIpIF.C_SAKI_SYSTEM_ID_DAIKOU(), gGyomuYmd, gDenbunNo);
		-- MIC電文・業務データ（業務データ）の編集
		-- リファレンスNo
		gGyomuDataDat.refNo := 'U' || substring(gGyomuYmd, 3, 6) || TO_CHAR(gRefNo, 'FM00000');
		-- 取引種別
		IF rec.UTI_SOTO_FLG = '0' THEN
			gGyomuDataDat.trhkTyp := 'B2';
		ELSE
			gGyomuDataDat.trhkTyp := 'B4';
		END IF;
		-- 決済日
		gGyomuDataDat.kssiDt := rec.SHR_YMD;
		-- 資金受渡金額
		gGyomuDataDat.sknUkeKin := TO_CHAR(oracle.trunc(rec.SKN_UKEWATASHI_KNGK), 'FM000000000000000');
		-- 資金受入先コード
		gGyomuDataDat.sknUkeCd := rec.SKN_UKEIRESAKI_CD;
		-- 資金払込先コード
		gGyomuDataDat.sknHaraiCd := rec.SKN_HARAIKOMISAKI_CD;
		-- 保振決済番号
		gGyomuDataDat.kssiNo := rec.KESSAI_BANGO;
		-- 顧客コード
		gGyomuDataDat.kokyakuCd := rec.DAIKO_KOKYAKU_CD;
		-- 顧客専用口座番号
		gGyomuDataDat.kokyakuKozaNo := 'ト' || substring(rec.RGS_KOZA_NO8, 2, 7);
		-- 外部IF送受信データへMIC電文を登録する
		INSERT INTO GAIBU_IF_DATA(
			IF_ID,
			IF_MAKE_DT,
			IF_MAKE_CNT,
			IF_DATA_NO,
			IF_DATA,
			KOUSIN_ID,
			SAKUSEI_ID
		)
		VALUES (
			l_inIfId,
			gGyomuYmd,
			gMakeCnt,
			gDataNo,
			gMicHdr
				 || gGyomuDataHdr.blank1
				 || gGyomuDataDat.dataTyp
				 || gGyomuDataDat.refNo
				 || gGyomuDataDat.trhkTyp
				 || gGyomuDataDat.kssiDt
				 || gGyomuDataDat.blank1
				 || gGyomuDataDat.sknUkeKin
				 || gGyomuDataDat.sknUkeCd
				 || gGyomuDataDat.sknHaraiCd
				 || gGyomuDataDat.blank2
				 || gGyomuDataDat.kssiNo
				 || gGyomuDataDat.youinCd
				 || gGyomuDataDat.blank3
				 || gGyomuDataDat.daikoKbn
				 || gGyomuDataDat.kokyakuCd
				 || gGyomuDataDat.kokyakuKozaNo
				 || gGyomuDataDat.blank4,
			pkconstant.BATCH_USER(),
			pkconstant.BATCH_USER()
		);
	END LOOP;
	RAISE NOTICE 'Loop completed. Total records: %', gDataNo;
	-- 連携データなしの場合
	IF gDataNo = 0 THEN
		-- 外部IF送受信管理の連携フラグを更新する
		gResult := pkIpIF.updRenkeiFlg(l_inIfId, gGyomuYmd, gMakeCnt, pkIpIF.C_RENKEI_FLG_FUYO());
		IF gResult <> pkconstant.success() THEN
			RETURN gResult;
		END IF;
	END IF;
	-- 終了処理
	CALL pkLog.info('IIP015', C_FUNCTION_ID, gDataNo::text || ' 件');
	CALL pkLog.debug('BATCH', C_FUNCTION_ID, '***** ' || C_FUNCTION_ID || ' END *****');
	RETURN pkconstant.success();
-- 例外処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'SQLERRM:' || SQLERRM);
		-- 外部IF送受信管理テーブルへの登録処理内で例外の場合、対象レコード箇所を出力
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '外部IF送受信管理処理対象レコード：' ||  gDataNo::text || '件目');
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipxb10k15r01 ( l_inIfId GAIBU_IF_KANRI.IF_ID%TYPE  ) FROM PUBLIC;
