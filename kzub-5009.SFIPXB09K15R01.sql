


DROP TYPE IF EXISTS sfipxb09k15r01_tgyomudataheader;
CREATE TYPE sfipxb09k15r01_tgyomudataheader AS (
		blank1				char(72) 							-- ブランク
	);
DROP TYPE IF EXISTS sfipxb09k15r01_tgyomudatadata;
CREATE TYPE sfipxb09k15r01_tgyomudatadata AS (
		dataTyp				char(3)  ,			-- データ種別（データ作成）
		refNo				char(12) ,			-- リファレンスＮＯ
		trhkTyp				char(2)  ,			-- 取引種別（新規記録）
		kssiDt				char(8)  ,			-- 決済日
		blank1				char(8)  ,			-- ブランク（決済時刻ＦＲＯＭ 〜 決済時刻ＴＯ）
		sknUkeKin			char(15) ,			-- 資金受渡金額
		sknUkeCd			char(7)  ,			-- 資金受入先コード
		sknHaraiCd			char(7)  ,			-- 資金払込先コード
		blank2				char(7)  ,			-- ブランク（資金約定相手先コード）
		kssiNo				char(16) ,			-- 保振決済番号
		youinCd				char(4)  ,		-- 要因コード
		blank3				char(5)  ,			-- ブランク（元利金サイン１ 〜 元利金サイン５）
		daikoKbn			char(1)  ,			-- プロパー事務代行区分
		kokyakuCd			char(12) ,			-- 顧客コード
		kokyakuKozaNo		char(8)  ,			-- 顧客専用口座番号
		blank4				char(25)  				-- ブランク（予備）
	);


CREATE OR REPLACE FUNCTION sfipxb09k15r01 ( l_inIfId GAIBU_IF_KANRI.IF_ID%TYPE,			-- 外部IFID
 l_inItakuKaisyaCd NYUKIN_YOTEI.ITAKU_KAISHA_CD%TYPE,	-- 委託会社コード
 l_inKessaiNo NYUKIN_YOTEI.KESSAI_NO%TYPE 			-- 決済番号
 ) RETURNS numeric AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2016
-- * 会社名:JIP
-- *
-- * 概  要:発行代理人が、他行（機構加入者）から受け取る発行払込金の決済予定（事務代行業務の資金）を
-- *        債券決済代行システムに連携するデータ「資金決済予定データ（新規記録）」を作成する。
-- *
-- * @author 村木 明広
-- * @version $Id:$
-- *
-- * @param l_inIfId				外部IFID
-- * @param l_inItakuKaisyaCd		委託会社コード
-- * @param l_inKessaiNo			決済番号
-- * @return INTEGER 0:正常、99:異常、それ以外：エラー
-- *
-- ***************************************************************************
-- * ログ:
-- *    日付    開発者名		目的
-- * -------------------------------------------------------------------------
-- * 2016.10.14 村木			新規作成
-- ***************************************************************************
--
	--==============================================================================
	--					定数定義													
	--==============================================================================
	-- ファンクションＩＤ
	C_FUNCTION_ID			CONSTANT text	;
	--==============================================================================
	--					変数定義													
	--==============================================================================
	gGyomuYmd				char(8)							;		-- 業務日付
	gDenbunNo				numeric(8)						;		-- 電文通番
	gRefNo					numeric(8)						;		-- リファレンスＮＯ
	gMakeCnt				GAIBU_IF_DATA.IF_MAKE_CNT%TYPE	;		-- 作成回数
	gResult					integer							;		-- 共通部品の戻り値
	gMicHdr					char(172)						;		-- MIC電文（ヘッダ）
	gDataNo					GAIBU_IF_DATA.IF_DATA_NO%TYPE	;		-- データ番号
	-- MIC電文・業務データ（業務ヘッダ）
	gGyomuDataHdr SFIPXB09K15R01_tGyomuDataHeader;
	-- MIC電文・業務データ（業務データ）
	gGyomuDataDat SFIPXB09K15R01_tGyomuDataData;
	--==============================================================================
	--					例外定義													
	--==============================================================================
	--==============================================================================
	--					カーソル定義												
	--==============================================================================
	-- 入金予定
	curMeisai CURSOR FOR
		SELECT
			B03.ITAKU_KAISHA_CD				ITAKU_KAISHA_CD,		-- 委託会社コード
			B03.KESSAI_NO					KESSAI_NO,				-- 決済番号
			B03.KESSAI_YMD					KESSAI_YMD,				-- 決済日
			B03.KESSAI_KNGK					KESSAI_KNGK,			-- 決済金額
			B03.SKN_SHRNIN_BCD				SKN_SHRNIN_BCD,			-- 金融機関コード(資金支払人）
			B03.SKN_SHRNIN_SCD				SKN_SHRNIN_SCD,			-- 支店コード(資金支払人）
			JM01.SKN_KESSAI_CD				SKN_KESSAI_CD,			-- 資金決済会社コード
			SUBSTR('00000000' || RTRIM(BT02.RGS_KOZA_NO), -8)
											RGS_KOZA_NO8,			-- ＲＴＧＳ口座番号
			SUBSTR('00000000' || RTRIM(BT02.DAIKO_KOKYAKU_CD), -8)
											DAIKO_KOKYAKU_CD 		-- 決済代行顧客コード
		FROM
			NYUKIN_YOTEI	B03,
			MITAKU_KAISHA	JM01,
			MITAKU_KAISHA2	BT02
		WHERE
			B03.ITAKU_KAISHA_CD				= JM01.ITAKU_KAISHA_CD
			AND B03.ITAKU_KAISHA_CD			= BT02.ITAKU_KAISHA_CD
			AND B03.ITAKU_KAISHA_CD			= l_inItakuKaisyaCd
			AND B03.KESSAI_NO				= l_inKessaiNo
			AND B03.DVP_KBN					= '1'					-- 1：DVP
			AND BT02.SKN_KESSAI_DAIKO_UMU	= '1';					-- 1：有
--==============================================================================
--                  関数定義                                                    
--==============================================================================
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	CALL pkLog.debug('BATCH', C_FUNCTION_ID, '***** ' || C_FUNCTION_ID || ' START *****');
	-- 入力パラメータのチェック
	-- 外部IFID の必須チェック
	IF coalesce(l_inIfId::text, '') = '' THEN
		-- パラメータエラー
		CALL pkLog.error('ECM501', C_FUNCTION_ID, '外部IFID');
		RETURN pkconstant.error();
	END IF;
	-- 決済番号 の必須チェック
	IF coalesce(l_inKessaiNo::text, '') = '' THEN
		-- パラメータエラー
		CALL pkLog.error('ECM501', C_FUNCTION_ID, '決済番号');
		RETURN pkconstant.error();
	END IF;
	-- 委託会社コード の必須チェック
	IF coalesce(l_inItakuKaisyaCd::text, '') = '' THEN
		-- パラメータエラー
		CALL pkLog.error('ECM501', C_FUNCTION_ID, '委託会社コード');
		RETURN pkconstant.error();
	END IF;
	-- 業務日付の取得
	gGyomuYmd := pkDate.getGyomuYmd();
	-- 外部ＩＦ送受信管理登録
	SELECT l_outcnt, extra_param INTO gMakeCnt, gResult FROM pkIpIF.insGaibuIFKanri(l_inIfId, gGyomuYmd);
	IF gResult <> pkconstant.success() THEN
		RETURN gResult;
	END IF;
	FOR rec IN curMeisai LOOP
		-- 初期化
		gDataNo := gDataNo + 1;
		-- 電文通番の取得
		SELECT l_outno, extra_param INTO gDenbunNo, gResult FROM pkIpIF.getIFNum(pkIpIF.C_NUMBERING_DENBUN_NO());
		IF gResult <> pkconstant.success() THEN
			RETURN gResult;
		END IF;
		-- リファレンスＮＯの取得
		SELECT l_outno, extra_param INTO gRefNo, gResult FROM pkIpIF.getIFNum(pkIpIF.C_NUMBERING_REF_NO());
		IF gResult <> pkconstant.success() THEN
			RETURN gResult;
		END IF;
		-- MIC電文（ヘッダ・決済代行・資金決済予定）の編集
		gMicHdr := SFIPXB09K15R01_MIC(pkIpIF.C_MOTO_GYOMU_ID_DAIKOU_SKNKSI(), pkIpIF.C_SAKI_SYSTEM_ID_DAIKOU(), gGyomuYmd, gDenbunNo);
		-- MIC電文・業務データ（業務データ）の編集
		-- リファレンスNo
		gGyomuDataDat.refNo := 'U' || SUBSTR(gGyomuYmd, 3, 6) || TO_CHAR(gRefNo, 'FM00000');
		-- 決済日
		gGyomuDataDat.kssiDt := rec.KESSAI_YMD;
		-- 資金受渡金額
		gGyomuDataDat.sknUkeKin := TO_CHAR(TRUNC(rec.KESSAI_KNGK), 'FM000000000000000');
		-- 資金受入先コード
		gGyomuDataDat.sknUkeCd := rec.SKN_KESSAI_CD;
		-- 資金払込先コード
		gGyomuDataDat.sknHaraiCd := rec.SKN_SHRNIN_BCD || rec.SKN_SHRNIN_SCD;
		-- 保振決済番号
		gGyomuDataDat.kssiNo := rec.KESSAI_NO;
		-- 顧客コード
		gGyomuDataDat.kokyakuCd := rec.DAIKO_KOKYAKU_CD || '    ';
		-- 顧客専用口座番号
		gGyomuDataDat.kokyakuKozaNo := 'ト' || SUBSTR(rec.RGS_KOZA_NO8, 2, 7);
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
	-- 連携データなしの場合
	IF gDataNo = 0 THEN
		-- 外部IF送受信管理の連携フラグを更新する
		gResult := pkIpIF.updRenkeiFlg(l_inIfId, gGyomuYmd, gMakeCnt, pkIpIF.C_RENKEI_FLG_FUYO());
		IF gResult <> pkconstant.success() THEN
			RETURN gResult;
		END IF;
	END IF;
	-- 終了処理
	CALL pkLog.info('IIP015', C_FUNCTION_ID, gDataNo || ' 件');
	CALL pkLog.debug('BATCH', C_FUNCTION_ID, '***** ' || C_FUNCTION_ID || ' END *****');
 	RETURN pkconstant.success();
-- 例外処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'SQLERRM:' || SQLERRM);
		-- 外部IF送受信管理テーブルへの登録処理内で例外の場合、対象レコード箇所を出力
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '外部IF送受信管理処理対象レコード：' || gDataNo || '件目');
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipxb09k15r01 ( l_inIfId GAIBU_IF_KANRI.IF_ID%TYPE, l_inItakuKaisyaCd NYUKIN_YOTEI.ITAKU_KAISHA_CD%TYPE, l_inKessaiNo NYUKIN_YOTEI.KESSAI_NO%TYPE  ) FROM PUBLIC;
