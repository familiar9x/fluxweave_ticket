


DROP TYPE IF EXISTS sfipxb16k15r01_tgyomudataheader;
CREATE TYPE sfipxb16k15r01_tgyomudataheader AS (
		kubun				char(1),			--区分
		gyomutsuban			char(8),			--業務通番
		gyomurefbango		char(17),			--業務REF番号
		yobi				char(24) 				--予備
	);
DROP TYPE IF EXISTS sfipxb16k15r01_tgyomudatadata;
CREATE TYPE sfipxb16k15r01_tgyomudatadata AS (
		dataTyp				char(3),						-- データ種別（データ作成）
		refNo				char(12),						-- REF番号
		trhkTyp				char(2),						-- 取引種別（資金受取（新規記録））
		kssiDt				char(8),						-- 決済日
		kssiTmFrom			char(4),	-- 決済時刻ＦＲＯＭ
		kssiTmTo			char(4),		-- 決済時刻ＴＯ
		sknUkeKin			char(15),						-- 資金受渡金額
		sknUkeCd			char(7),						-- 資金受入先コード
		sknHaraiCd			char(7),						-- 資金払込先コード
		blank1				char(7),						-- ブランク（資金約定相手先コード）
		kssiNo				char(16),						-- 保振決済番号
		youinCd				char(4),					-- 要因コード
		blank2				char(5),						-- ブランク（元利金サイン１ 〜 元利金サイン５）
		daikoKbn			char(1),						-- プロパー事務代行区分
		blank3				char(45) 							-- ブランク（顧客コード 〜 予備）
	);


CREATE OR REPLACE FUNCTION sfipxb16k15r01 ( l_inIfId GAIBU_IF_KANRI.IF_ID%TYPE,			-- 外部IFID
 l_inItakuKaisyaCd NYUKIN_YOTEI.ITAKU_KAISHA_CD%TYPE,	-- 委託会社コード
 l_inKessaiNo NYUKIN_YOTEI.KESSAI_NO%TYPE 			-- 決済番号
 ) RETURNS numeric AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2016
-- * 会社名:JIP
-- *
-- * 概  要:発行代理人として当行が、他行（機構加入者）から受け取る発行払込金の決済予定（当行代表受託業務の資金）をRTGS-XGに連携するデータを作成する。
-- *        作成したデータは外部IF送受信データテーブルに登録し、後続処理でRTGS-XGに連携するデータとしてメッセージ送信（MQ）される。
-- *
-- * @author 山中 大輔
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
-- * 2016.11.16 山中			新規作成
-- ***************************************************************************
--
	--==============================================================================
	--					定数定義													
	--==============================================================================
	-- ファンクションＩＤ
	C_FUNCTION_ID			CONSTANT	varchar(50)	:= 'SFIPXB16K15R01';
	--==============================================================================
	--					変数定義													
	--==============================================================================
	gGyomuYmd				char(8)							:= '';		-- 業務日付
	gDenbunNo				numeric(8)						:= 0;		-- 電文通番
	gGyomuNo				numeric(8)						:= 0;		-- 業務通番
	gGyomuNoShinkikiroku	numeric(8)						:= 0;		-- 業務通番（新規記録）
	gMakeCnt				GAIBU_IF_DATA.IF_MAKE_CNT%TYPE	:= 0;		-- 作成回数
	gResult					integer							:= 0;		-- 共通部品の戻り値
	gMicHdr					char(172)						:= 0;		-- MIC電文（ヘッダ）
	gDataNo					GAIBU_IF_DATA.IF_DATA_NO%TYPE	:= 0;		-- データ番号
	-- MIC電文・業務データ（業務ヘッダ）
	gGyomuDataHdr SFIPXB16K15R01_tGyomuDataHeader;
	-- MIC電文・業務データ（業務データ）
	gGyomuDataDat SFIPXB16K15R01_tGyomuDataData;
	--==============================================================================
	--					例外定義													
	--==============================================================================
	--==============================================================================
	--					カーソル定義												
	--==============================================================================
	-- 入金予定
	curMeisai CURSOR FOR
		SELECT
			B03.ITAKU_KAISHA_CD,									-- 委託会社コード
			B03.KESSAI_NO,											-- 決済番号
			B03.KESSAI_YMD,											-- 決済日
			B03.KESSAI_KNGK,										-- 決済金額
			B03.SKN_SHRNIN_BCD,										-- 金融機関コード(資金支払人）
			B03.SKN_SHRNIN_SCD,										-- 支店コード(資金支払人）
			SC18.SKN_KESSAI_CD 										-- 資金決済会社コード
		FROM
			NYUKIN_YOTEI	B03,
			SOWN_INFO		SC18
		WHERE
			B03.ITAKU_KAISHA_CD				= SC18.KAIIN_ID
			AND B03.ITAKU_KAISHA_CD			= l_inItakuKaisyaCd
			AND B03.KESSAI_NO				= l_inKessaiNo
			AND B03.DVP_KBN					= '1';					-- 1：DVP
--==============================================================================
--					関数定義													
--==============================================================================
--==============================================================================
--					メイン処理													
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
	gResult := pkIpIF.insGaibuIFKanri(l_inIfId, gGyomuYmd, gMakeCnt);
	IF gResult <> pkconstant.success() THEN
		RETURN gResult;
	END IF;
	FOR rec IN curMeisai LOOP
		-- 初期化
		gDataNo := gDataNo + 1;
		-- Initialize composite types with default values
		gGyomuDataHdr.kubun := '1';
		gGyomuDataHdr.gyomutsuban := REPEAT(' ', 8);
		gGyomuDataHdr.gyomurefbango := REPEAT(' ', 17);
		gGyomuDataHdr.yobi := REPEAT(' ', 24);
		gGyomuDataDat.dataTyp := '101';
		gGyomuDataDat.refNo := REPEAT(' ', 12);
		gGyomuDataDat.trhkTyp := '01';
		gGyomuDataDat.kssiDt := REPEAT(' ', 8);
		gGyomuDataDat.kssiTmFrom := pkIpIF.C_KESSAI_TM_FROM();
		gGyomuDataDat.kssiTmTo := pkIpIF.C_KESSAI_TM_TO();
		gGyomuDataDat.sknUkeKin := REPEAT(' ', 15);
		gGyomuDataDat.sknUkeCd := REPEAT(' ', 7);
		gGyomuDataDat.sknHaraiCd := REPEAT(' ', 7);
		gGyomuDataDat.blank1 := REPEAT(' ', 7);
		gGyomuDataDat.kssiNo := REPEAT(' ', 16);
		gGyomuDataDat.youinCd := '1203';
		gGyomuDataDat.blank2 := REPEAT(' ', 5);
		gGyomuDataDat.daikoKbn := '1';
		gGyomuDataDat.blank3 := REPEAT(' ', 45);
		-- 電文通番の取得
		gResult := pkIpIF.getIFNum(pkIpIF.C_NUMBERING_DENBUN_NO_RTGS_XG(), gDenbunNo);
		IF gResult <> pkconstant.success() THEN
			RETURN gResult;
		END IF;
		-- 業務通番の取得
		gResult := pkIpIF.getIFNum(pkIpIF.C_NUMBERING_GYOMU_NO(), gGyomuNo);
		IF gResult <> pkconstant.success() THEN
			RETURN gResult;
		END IF;
		-- 業務通番（新規記録）の取得
		gResult := pkIpIF.getIFNum(pkIpIF.C_NUMBERING_GYOMU_NO_SHINKI(), gGyomuNoShinkikiroku);
		IF gResult <> pkconstant.success() THEN
			RETURN gResult;
		END IF;
		-- MIC電文（ヘッダ）の編集
		gMicHdr := SFIPXB09K15R01_MIC(pkIpIF.C_MOTO_GYOMU_ID(), pkIpIF.C_SAKI_SYSTEM_ID(), gGyomuYmd, gDenbunNo);
		-- MIC電文・業務データ（業務データ）の編集
		-- 業務通番
		gGyomuDataHdr.gyomutsuban := TO_CHAR(gGyomuNoShinkikiroku, 'FM00000000');
		-- REF番号
		gGyomuDataDat.refNo := 'U' || SUBSTR(gGyomuYmd, 3, 6) || TO_CHAR(gGyomuNo, 'FM00000');
		-- 業務REF番号
		gGyomuDataHdr.gyomurefbango := gGyomuDataDat.refNo || '     ';
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
				 || gGyomuDataHdr.kubun
				 || gGyomuDataHdr.gyomutsuban
				 || gGyomuDataHdr.gyomurefbango
				 || gGyomuDataHdr.yobi
				 || gGyomuDataDat.dataTyp
				 || gGyomuDataDat.refNo
				 || gGyomuDataDat.trhkTyp
				 || gGyomuDataDat.kssiDt
				 || gGyomuDataDat.kssiTmFrom
				 || gGyomuDataDat.kssiTmTo
				 || gGyomuDataDat.sknUkeKin
				 || gGyomuDataDat.sknUkeCd
				 || gGyomuDataDat.sknHaraiCd
				 || gGyomuDataDat.blank1
				 || gGyomuDataDat.kssiNo
				 || gGyomuDataDat.youinCd
				 || gGyomuDataDat.blank2
				 || gGyomuDataDat.daikoKbn
				 || gGyomuDataDat.blank3,
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
	CALL pkLog.info('IIP015', C_FUNCTION_ID,  gDataNo::text || ' 件');
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
-- REVOKE ALL ON FUNCTION sfipxb16k15r01 ( l_inIfId GAIBU_IF_KANRI.IF_ID%TYPE, l_inItakuKaisyaCd NYUKIN_YOTEI.ITAKU_KAISHA_CD%TYPE, l_inKessaiNo NYUKIN_YOTEI.KESSAI_NO%TYPE  ) FROM PUBLIC;
