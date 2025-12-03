


DROP TYPE IF EXISTS sfipxb18k15r01_tgyomudataheader CASCADE;
CREATE TYPE sfipxb18k15r01_tgyomudataheader AS (
		kubun				char(1),			-- 区分
		gyomutsuban			char(8),			-- 業務通番
		gyomurefbango		char(17),			-- 業務REF番号
		yobi				char(24) 				-- 予備
	);
DROP TYPE IF EXISTS sfipxb18k15r01_tgyomudatadata CASCADE;
CREATE TYPE sfipxb18k15r01_tgyomudatadata AS (
		dataTyp				char(3),						-- データ種別（データ作成）
		refNo				char(12),						-- REF番号
		trhkTyp				char(2),						-- 取引種別（資金受取（元利金受取））
		kssiDt				char(8),						-- 決済日
		kssiTmFrom			char(4),	-- 決済時刻ＦＲＯＭ
		kssiTmTo			char(4),		-- 決済時刻ＴＯ
		sknUkeKin			char(15),						-- 資金受渡金額
		sknUkeCd			char(7),						-- 資金受入先コード
		sknHaraiCd			char(7),						-- 資金払込先コード
		blank1				char(7),						-- ブランク（資金約定相手先コード）
		kssiNo				char(16),						-- 保振決済番号
		youinCd				char(4),					-- 要因コード
		ganSign1			char(1),						-- 元利金サイン１
		ganSign2			char(1),						-- 元利金サイン２
		ganSign3			char(1),						-- 元利金サイン３
		blank2				char(48) 							-- ブランク（元利金サイン４ 〜 予備）
	);


CREATE OR REPLACE FUNCTION sfipxb18k15r01 ( l_inIfId GAIBU_IF_KANRI.IF_ID%TYPE 			-- 外部IFID
 ) RETURNS integer AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2016
-- * 会社名:JIP
-- *
-- * 概  要:機構加入者として当行が、他行（支払代理人）から受け取る元利金資金の決済予定（自行、窓版、口座管理等）をRTGS-XGに連携するデータを作成する。
-- *        作成したデータは外部IF送受信データテーブルに登録し、後続処理でRTGS-XGに連携するデータとしてメッセージ送信（MQ）される。
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
	C_FUNCTION_ID			CONSTANT	varchar(50)	:= 'SFIPXB18K15R01';
	--==============================================================================
	--					変数定義													
	--==============================================================================
	gGyomuYmd				char(8)							:= '';		-- 業務日付
	gYokuEigyoYmd			char(8)							:= '';		-- 翌営業日
	gDenbunNo				numeric(8)						:= 0;		-- 電文通番
	gGyomuNo				numeric(8)						:= 0;		-- 業務通番
	gMakeCnt				GAIBU_IF_DATA.IF_MAKE_CNT%TYPE	:= 0;		-- 作成回数
	gResult					integer							:= 0;		-- 共通部品の戻り値
	gMicHdr					char(172)						:= 0;		-- MIC電文（ヘッダ）
	gDataNo					GAIBU_IF_DATA.IF_DATA_NO%TYPE	:= 0;		-- データ番号
	-- MIC電文・業務データ（業務ヘッダ）
	gGyomuDataHdr SFIPXB18K15R01_tGyomuDataHeader;
	-- MIC電文・業務データ（業務データ）
	gGyomuDataDat SFIPXB18K15R01_tGyomuDataData;
	--==============================================================================
	--					例外定義													
	--==============================================================================
	--==============================================================================
	--					カーソル定義												
	--==============================================================================
	-- 入金予定
	curMeisai CURSOR FOR
		SELECT
			MAX(BT13.ITAKU_KAISHA_CD)										AS ITAKU_KAISHA_CD,			-- 委託会社コード
			MAX(BT13.GNR_YMD)												AS GNR_YMD,					-- 元利払日
			MAX(CASE WHEN substr(BT13.SHOKEN_KZNO, 6, 2) IN ('64','69')                THEN '1' ELSE '0' END) AS GAN_SIGN1,	-- 元利金サイン1
			MAX(CASE WHEN substr(BT13.SHOKEN_KZNO, 6, 2) IN ('00','05','96','98','39') THEN '1' ELSE '0' END) AS GAN_SIGN2,	-- 元利金サイン2
			MAX(CASE WHEN substr(BT13.SHOKEN_KZNO, 6, 2) IN ('60','65','66')           THEN '1' ELSE '0' END) AS GAN_SIGN3,	-- 元利金サイン3
			MAX(BT13.AITE_SKN_KESSAI_BCD || BT13.AITE_SKN_KESSAI_SCD)		AS SKN_UKEIRESAKI_CD,		-- 資金受入先コード
			MAX(BT13.SKN_KESSAI_BCD || BT13.SKN_KESSAI_SCD)					AS SKN_HARAIKOMISAKI_CD,	-- 資金払込先コード
			BT13.KESSAI_NO,																				-- 決済番号
			SUM(BT13.GZEIHIKI_AFT_CHOKYU_KNGK + BT13.SHOKAN_SEIKYU_KNGK)	AS SKN_UKEWATASHI_KNGK 		-- 資金受渡金額
		FROM
			KIKIN_SEIKYU_KNS	BT13,
			SOWN_INFO			SC18
		WHERE
			BT13.ITAKU_KAISHA_CD											= SC18.KAIIN_ID
			AND BT13.GNR_YMD												= gYokuEigyoYmd
			AND (BT13.GZEIHIKI_AFT_CHOKYU_KNGK + BT13.SHOKAN_SEIKYU_KNGK)	> 0
		GROUP BY BT13.KESSAI_NO
		HAVING MAX(BT13.AITE_SKN_KESSAI_BCD || BT13.AITE_SKN_KESSAI_SCD) <> MAX(BT13.SKN_KESSAI_BCD || BT13.SKN_KESSAI_SCD)
		ORDER BY MAX(BT13.SKN_KESSAI_BCD || BT13.SKN_KESSAI_SCD),
				 MAX(BT13.AITE_SKN_KESSAI_BCD || BT13.AITE_SKN_KESSAI_SCD),
				 BT13.KESSAI_NO;
--==============================================================================
--					関数定義													
--==============================================================================
--==============================================================================
--					メイン処理													
--==============================================================================
BEGIN
	RAISE NOTICE '[DEBUG] Function start';
	-- Initialize composite types with default values
	gGyomuDataHdr := ROW('1','','','');
	gGyomuDataDat := ROW('101','','03','',pkIpIF.C_KESSAI_TM_FROM(),pkIpIF.C_KESSAI_TM_TO(),'','','','','','1007','','','','');
	RAISE NOTICE '[DEBUG] Composite types initialized';
	
	CALL pkLog.debug('BATCH', C_FUNCTION_ID, '***** ' || C_FUNCTION_ID || ' START *****');
	-- 入力パラメータのチェック
	-- 外部IFID の必須チェック
	IF coalesce(l_inIfId::text, '') = '' THEN
		-- パラメータエラー
		CALL pkLog.error('ECM501', C_FUNCTION_ID, '外部IFID');
		RETURN pkconstant.error();
	END IF;
	-- 業務日付の取得
	gGyomuYmd := pkDate.getGyomuYmd();
	RAISE NOTICE '[DEBUG] gGyomuYmd = %', gGyomuYmd;
	--翌営業日の取得
	gYokuEigyoYmd := pkDate.getPlusDateBusiness(gGyomuYmd,1,'1');
	RAISE NOTICE '[DEBUG] gYokuEigyoYmd = %', gYokuEigyoYmd;
	-- 外部ＩＦ送受信管理登録
	gResult := pkIpIF.insGaibuIFKanri(l_inIfId, gGyomuYmd, gMakeCnt);
	IF gResult <> pkconstant.success() THEN
		RETURN gResult;
	END IF;
	FOR rec IN curMeisai LOOP
		-- 初期化
		gDataNo := gDataNo + 1;
		-- 電文通番の取得
		gResult := pkIpIF.getIFNum(pkIpIF.C_NUMBERING_DENBUN_NO(), gDenbunNo);
		IF gResult <> pkconstant.success() THEN
			RETURN gResult;
		END IF;
		-- 業務通番の取得
		gResult := pkIpIF.getIFNum(pkIpIF.C_NUMBERING_GYOMU_NO(), gGyomuNo);
		IF gResult <> pkconstant.success() THEN
			RETURN gResult;
		END IF;
		-- MIC電文（ヘッダ）の編集
		gMicHdr := SFIPXB09K15R01_MIC(pkIpIF.C_MOTO_GYOMU_ID(), pkIpIF.C_SAKI_SYSTEM_ID(), gGyomuYmd, gDenbunNo);
		-- MIC電文・業務データ（業務データ）の編集
		-- 業務通番
		gGyomuDataHdr.gyomutsuban := lpad(gGyomuNo::text, 8, '0');
		-- REF番号
		gGyomuDataDat.refNo := 'U' || SUBSTR(gGyomuYmd, 3, 6) || lpad(gGyomuNo::text, 5, '0');
		-- 業務REF番号
		gGyomuDataHdr.gyomurefbango := gGyomuDataDat.refNo || '     ';
		-- 決済日
		gGyomuDataDat.kssiDt := rec.GNR_YMD;
		-- 資金受渡金額
		gGyomuDataDat.sknUkeKin := lpad(floor(rec.SKN_UKEWATASHI_KNGK)::text, 15, '0');
		-- 資金受入先コード
		gGyomuDataDat.sknUkeCd := rec.SKN_UKEIRESAKI_CD;
		-- 資金払込先コード
		gGyomuDataDat.sknHaraiCd := rec.SKN_HARAIKOMISAKI_CD;
		-- 保振決済番号
		gGyomuDataDat.kssiNo := rec.KESSAI_NO;
		-- 元利金サイン1
		gGyomuDataDat.ganSign1 := rec.GAN_SIGN1;
		-- 元利金サイン2
		gGyomuDataDat.ganSign2 := rec.GAN_SIGN2;
		-- 元利金サイン3
		gGyomuDataDat.ganSign3 := rec.GAN_SIGN3;
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
				 || gGyomuDataDat.ganSign1
				 || gGyomuDataDat.ganSign2
				 || gGyomuDataDat.ganSign3
				 || gGyomuDataDat.blank2,
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
		RAISE NOTICE '[DEBUG] Exception: SQLSTATE = %, SQLERRM = %', SQLSTATE, SQLERRM;
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'SQLERRM:' || SQLERRM);
		-- 外部IF送受信管理テーブルへの登録処理内で例外の場合、対象レコード箇所を出力
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '外部IF送受信管理処理対象レコード：' ||  gDataNo::text || '件目');
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipxb18k15r01 ( l_inIfId GAIBU_IF_KANRI.IF_ID%TYPE  ) FROM PUBLIC;
