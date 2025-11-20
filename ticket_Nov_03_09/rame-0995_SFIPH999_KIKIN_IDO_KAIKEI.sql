CREATE OR REPLACE FUNCTION sfIph999_KIKIN_IDO_KAIKEI
(
	l_inItakuKaisyaCode IN KIKIN_IDO.ITAKU_KAISHA_CD%TYPE,
	l_inMeigaraCode IN KIKIN_IDO.MGR_CD%TYPE,
	l_inRbrKjt IN KIKIN_IDO.RBR_KJT%TYPE,
	l_inIdoYmd IN KIKIN_IDO.IDO_YMD%TYPE,
	l_inUserId IN KIKIN_IDO_KAIKEI.SAKUSEI_ID%TYPE,
	l_inGroupId IN KIKIN_IDO_KAIKEI.GROUP_ID%TYPE
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $body$
/**
 * 著作権: Copyright (c) 2005
 * 会社名: JIP
 *
 * 基金異動履歴、銘柄_基本、銘柄_利払回次、銘柄_償還回次、銘柄_手数料(計算情報)、会計区分マスタ、会計区分別按分額をもとに
 * データを作成する
 *
 * @author 大田　英子
 * @version $Id: SFIPH999_KIKIN_IDO_KAIKEI.SQL,v 1.17 2015/03/17 02:09:46 nakamura Exp $
 */
/**
 *
 * 基金異動履歴、銘柄_基本、銘柄_利払回次、銘柄_償還回次、銘柄_手数料(計算情報)、会計区分マスタ、会計区分別按分額をもとに
 * 基金異動履歴(会計区分別)データを作成する
 *
 * @param  l_inItakuKaisyaCode IN 委託会社コード
 * @param  l_inMeigaraCode IN 銘柄コード
 * @param  l_inRbrKjt IN 利払期日
 * @param  l_inIdoYmd IN 異動年月日
 * @param  l_inUserId IN ユーザーID
 * @param  l_inGroupId IN グループID
 * @return INTEGER 0:正常、99:異常
 */
DECLARE
/*====================================================================*
            定数定義
 *====================================================================*/
	SP_ID		CONSTANT CHAR(25)	:= 'sfIph999_KIKIN_IDO_KAIKEI';

/*====================================================================*
            変数定義
 *====================================================================*/
/*端数処理をする会計区分*/
	gKaikeiKubun KIKIN_IDO_KAIKEI.KAIKEI_KBN%TYPE DEFAULT ' ';
/*最小端数調整順位*/
	gMinHasuChoseiJuni KAIKEI_KBN.HASU_CHOSEI_JUNI%TYPE DEFAULT 0;
/*会計区分カウント用(会計区分マスタ)*/
	gCountKaikeiKubunM NUMERIC(9) DEFAULT 0;
/*会計区分カウント用(会計区分別按分額)*/
	gCountKaikeiKubunA NUMERIC(9) DEFAULT 0;
/*端数調整順位カウント用*/
	gCountHasuChoseiJuni NUMERIC(9) DEFAULT 0;
/*最大会計区分別按分額*/
	gMaxKaikeiKbnAnbunKngk KAIKEI_ANBUN.KAIKEI_KBN_ANBUN_KNGK%TYPE DEFAULT 0;
/*基金異動区分設定用(11)*/
	gKikinIdoKubun11 KIKIN_IDO.KKN_IDO_KBN%TYPE DEFAULT ' ';
/*基金異動区分設定用(12)*/
	gKikinIdoKubun12 KIKIN_IDO.KKN_IDO_KBN%TYPE DEFAULT ' ';
/*基金異動区分設定用(13)*/
	gKikinIdoKubun13 KIKIN_IDO.KKN_IDO_KBN%TYPE DEFAULT ' ';
/*基金異動区分設定用(21)*/
	gKikinIdoKubun21 KIKIN_IDO.KKN_IDO_KBN%TYPE DEFAULT ' ';
/*基金異動区分設定用(22)*/
	gKikinIdoKubun22 KIKIN_IDO.KKN_IDO_KBN%TYPE DEFAULT ' ';
/*基金異動区分設定用(23)*/
	gKikinIdoKubun23 KIKIN_IDO.KKN_IDO_KBN%TYPE DEFAULT ' ';
/*元金*/
	gGankin KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE DEFAULT 0;
/*利金*/
	gRikin KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE DEFAULT 0;
/*元金支払手数料金額*/
	gGankinTesuryo KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE DEFAULT 0;
/*利金支払手数料金額*/
	gRikinTesuryo KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE DEFAULT 0;
/*請求金額*/
	gSeikyuKngk KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE DEFAULT 0;
/*消費税金額*/
	gSyohiZei KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE DEFAULT 0;
/*元金（按分計算後）*/
	gGankinAnbun KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE DEFAULT 0;
/*利金（按分計算後）*/
	gRikinAnbun KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE DEFAULT 0;
/*元金支払手数料金額（按分計算後）*/
	gGankinTesuryoAnbun KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE DEFAULT 0;
/*利金支払手数料金額（按分計算後）*/
	gRikinTesuryoAnbun KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE DEFAULT 0;
/*請求金額（按分計算後）*/
	gSeikyuKngkAnbun KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE DEFAULT 0;
/*消費税金額（按分計算後）*/
	gSyohiZeiAnbun KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE DEFAULT 0;
/*基準残高（按分計算後）*/
	gKijunZndkAnbun KIKIN_IDO.KIJUN_ZNDK%TYPE DEFAULT 0;
/*基金請求種類*/
	gKknbillShurui KIKIN_IDO.KKNBILL_SHURUI%TYPE DEFAULT ' ';
/*利払日*/
	gRbrYmd KIKIN_IDO.RBR_YMD%TYPE DEFAULT ' ';
/*1通貨あたりの利子金額*/
	gTukaRishiKngk MGR_RBRKIJ.TSUKARISHI_KNGK%TYPE DEFAULT 0;
/*振替単位償還支払金額*/
	gFriKaeSyokanSiharai MGR_SHOKIJ.FUNIT_GENSAI_KNGK%TYPE DEFAULT 0;
/*各社債の金額*/
	gKakuSyasaiKngk MGR_KIHON.KAKUSHASAI_KNGK%TYPE DEFAULT 0;
/*募集区分*/
	gBoshuKbn MGR_KIHON.BOSHU_KBN%TYPE DEFAULT ' ';
/*償還方法*/
	gShokanMethod MGR_KIHON.SHOKAN_METHOD_CD%TYPE DEFAULT ' ';
/*分割銘柄区分*/
	gPartMgrKbn MGR_KIHON.PARTMGR_KBN%TYPE DEFAULT ' ';
/*原ISINコード*/
	gGenisinCd MGR_KIHON.GENISIN_CD%TYPE DEFAULT ' ';
/*償還プレミアム*/
	gSyokanPremium MGR_SHOKIJ.FUNIT_SKN_PREMIUM%TYPE DEFAULT 0;
/*基準残高 取得用*/
--	gKijunZndkS KIKIN_IDO.KIJUN_ZNDK%TYPE DEFAULT 0;
/*社債の総額*/
	gShasaiTotal MGR_KIHON.SHASAI_TOTAL%TYPE DEFAULT 0;
/*基準残高 テーブル設定用*/
	gKijunZndkT KIKIN_IDO.KIJUN_ZNDK%TYPE DEFAULT 0;
/*残高基準日取得用*/
	gZndkKijunYmdS KIKIN_IDO.ZNDK_KIJUN_YMD%TYPE DEFAULT ' ';
/*残高基準日 テーブル設定用*/
	gZndkKijunYmdT KIKIN_IDO.ZNDK_KIJUN_YMD%TYPE DEFAULT ' ';
/*元金支払手数料率(分母)*/
	gGankinTesuryoRituP MGR_TESURYO_PRM.GNKN_SHR_TESU_BUNBO%TYPE DEFAULT 0;
/*元金支払手数料率(分子)*/
	gGankinTesuryoRituC MGR_TESURYO_PRM.GNKN_SHR_TESU_BUNSHI%TYPE DEFAULT 0;
/*利金支払手数料率(分母)*/
	gRikinTesuryoRituP MGR_TESURYO_PRM.RKN_SHR_TESU_BUNBO%TYPE DEFAULT 0;
/*利金支払手数料率(分子)*/
	gRikinTesuryoRituC MGR_TESURYO_PRM.RKN_SHR_TESU_BUNSHI%TYPE DEFAULT 0;
/*手数料率税込フラグ*/
	gTesuryoKomiFlg SOWN_INFO.TESURYO_KOMI_FLG%TYPE DEFAULT ' ';
/*元金集計取得用*/
	gSumGankin KIKIN_IDO_KAIKEI.GANKIN%TYPE DEFAULT 0;
/*利金集計取得用*/
	gSumRikin KIKIN_IDO_KAIKEI.RKN%TYPE DEFAULT 0;
/*元金支払手数料金額集計取得用*/
	gSumGankinTesuryo KIKIN_IDO_KAIKEI.GNKN_SHR_TESU_KNGK%TYPE DEFAULT 0;
/*利金支払手数料金額集計取得用*/
	gSumRikinTesuryo KIKIN_IDO_KAIKEI.RKN_SHR_TESU_KNGK%TYPE DEFAULT 0;
/*請求金額集計取得用*/
	gSumSeikyuKngk KIKIN_IDO_KAIKEI.SEIKYU_KNGK%TYPE DEFAULT 0;
/*消費税金額集計取得用*/
	gSumSyohiZei KIKIN_IDO_KAIKEI.SZEI_KNGK%TYPE DEFAULT 0;
/*基準残高(会計区分別按分額)集計取得用*/
	gSumKijunZndk KIKIN_IDO_KAIKEI.KIJUN_ZNDK%TYPE DEFAULT 0;
/*端数調整先の元金取得用*/
	gGankinHa KIKIN_IDO_KAIKEI.GANKIN%TYPE DEFAULT 0;
/*端数調整先の利金取得用*/
	gRikinHa KIKIN_IDO_KAIKEI.RKN%TYPE DEFAULT 0;
/*端数調整先の元金支払手数料金額取得用*/
	gGankinTesuryoHa KIKIN_IDO_KAIKEI.GNKN_SHR_TESU_KNGK%TYPE DEFAULT 0;
/*端数調整先の利金支払手数料金額取得用*/
	gRikinTesuryoHa KIKIN_IDO_KAIKEI.RKN_SHR_TESU_KNGK%TYPE DEFAULT 0;
/*端数調整先の請求金額取得用*/
	gSeikyuKngkHa KIKIN_IDO_KAIKEI.SEIKYU_KNGK%TYPE DEFAULT 0;
/*端数調整先の消費税金額取得用*/
	gSyohiZeiHa KIKIN_IDO_KAIKEI.SZEI_KNGK%TYPE DEFAULT 0;
/*端数調整先の基準残高(会計区分別按分額)取得用*/
	gKijunZndkHa KIKIN_IDO_KAIKEI.KIJUN_ZNDK%TYPE DEFAULT 0;
/*取得レコード数(基金異動履歴テーブル)*/
	gRecKikinIdo NUMERIC(9) DEFAULT 0;
/*取得レコード数(会計区分別按分額テーブル)*/
	gRecKaikeiAnbun NUMERIC(9) DEFAULT 0;
/*ログ出力用メッセージパラメータ*/
--	message VARCHAR(200);
/*消費税率*/
	gSzeiRate NUMERIC DEFAULT 0;
/*消費税請求区分*/
	gSzeiSeikyuKbn	MGR_TESURYO_PRM.SZEI_SEIKYU_KBN%TYPE;
	-- 処理制御値
	gresult MPROCESS_CTL.CTL_VALUE%TYPE DEFAULT NULL;

/*====================================================================*
		レコード定義
 *====================================================================*/
	recKikinIdoC RECORD;
	recKikinIdoT RECORD;
/*====================================================================*
     エラー定義
 *====================================================================*/
--	err INTEGER := 99;

/*====================================================================*
   		メイン
 *====================================================================*/
BEGIN
--	pkLog.debug('batch','','基金異動履歴(会計区分別)データ作成 START');
--DBMS_OUTPUT.PUT_LINE('基金異動履歴(会計区分別)データ作成 START');
/*基金異動履歴テーブル抽出処理*/
	FOR recKikinIdoC IN (
	SELECT
		K02.RBR_YMD AS RBR_YMD,
		K02.KKN_IDO_KBN AS KKN_IDO_KBN,
		K02.KKNBILL_SHURUI AS KKNBILL_SHURUI,
		K02.KKN_NYUKIN_KNGK AS KKN_NYUKIN_KNGK,
		K02.ZNDK_KIJUN_YMD AS ZNDK_KIJUN_YMD,
		K02.KIJUN_ZNDK AS KIJUN_ZNDK,
		MG1.SHASAI_TOTAL
	FROM
		KIKIN_IDO K02,
		MGR_KIHON MG1
	WHERE
			MG1.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
		AND	MG1.MGR_CD = l_inMeigaraCode
		AND MG1.ITAKU_KAISHA_CD = K02.ITAKU_KAISHA_CD
		AND MG1.MGR_CD = K02.MGR_CD
		AND	K02.RBR_KJT = l_inRbrKjt
		AND	K02.IDO_YMD = l_inIdoYmd
		AND	K02.KKN_IDO_KBN IN('11','12','13','21','22','23')
	ORDER BY
		KKN_IDO_KBN
	) LOOP
		gRecKikinIdo := gRecKikinIdo + 1;
		gKknbillShurui:= recKikinIdoC.KKNBILL_SHURUI;
		gRbrYmd := recKikinIdoC.RBR_YMD;
--		gKijunZndkS := recKikinIdoC.KIJUN_ZNDK;
		gShasaiTotal := recKikinIdoC.SHASAI_TOTAL;
		gKijunZndkT := recKikinIdoC.KIJUN_ZNDK;
		gZndkKijunYmdS := recKikinIdoC.ZNDK_KIJUN_YMD;
		CASE recKikinIdoC.KKN_IDO_KBN
			WHEN '11' THEN	gKikinIdoKubun11 := '11';
					gGankin := recKikinIdoC.KKN_NYUKIN_KNGK;
					gSeikyuKngk := gSeikyuKngk + recKikinIdoC.KKN_NYUKIN_KNGK;
			WHEN '12' THEN	gKikinIdoKubun12 := '12';
					gGankinTesuryo := gGankinTesuryo + recKikinIdoC.KKN_NYUKIN_KNGK;
					gSeikyuKngk := gSeikyuKngk + recKikinIdoC.KKN_NYUKIN_KNGK;
			WHEN '13' THEN	gKikinIdoKubun13 := '13';
					gGankinTesuryo := gGankinTesuryo + recKikinIdoC.KKN_NYUKIN_KNGK;
--					gSyohiZei := gSyohiZei + recKikinIdoC.KKN_NYUKIN_KNGK;
					gSeikyuKngk := gSeikyuKngk + recKikinIdoC.KKN_NYUKIN_KNGK;
			WHEN '21' THEN	gKikinIdoKubun21 := '21';
					gRikin := recKikinIdoC.KKN_NYUKIN_KNGK;
					gSeikyuKngk := gSeikyuKngk + recKikinIdoC.KKN_NYUKIN_KNGK;
			WHEN '22' THEN	gKikinIdoKubun22 := '22';
					gRikinTesuryo := gRikinTesuryo + recKikinIdoC.KKN_NYUKIN_KNGK;
					gSeikyuKngk := gSeikyuKngk + recKikinIdoC.KKN_NYUKIN_KNGK;
			WHEN '23' THEN	gKikinIdoKubun23 := '23';
					gRikinTesuryo := gRikinTesuryo + recKikinIdoC.KKN_NYUKIN_KNGK;
--					gSyohiZei := gSyohiZei + recKikinIdoC.KKN_NYUKIN_KNGK;
					gSeikyuKngk := gSeikyuKngk + recKikinIdoC.KKN_NYUKIN_KNGK;
		END CASE;
	END LOOP;

	/*該当データが存在した場合*/
	IF
		gRecKikinIdo > 0
	THEN
	/*基金異動履歴(会計区分別)テーブル登録処理*/
		/*銘柄_手数料(計算情報)テーブル、自行情報マスタより抽出*/
		SELECT
			MG8.GNKN_SHR_TESU_BUNBO,		--元金支払手数料率(分母)
			MG8.GNKN_SHR_TESU_BUNSHI,		--元金支払手数料率(分子)
			MG8.RKN_SHR_TESU_BUNBO,			--利金支払手数料率(分母)
			MG8.RKN_SHR_TESU_BUNSHI,		--利金支払手数料率(分子)
			SC18.TESURYO_KOMI_FLG, 			--手数料率税込フラグ
			MG8.SZEI_SEIKYU_KBN				--消費税請求区分
		INTO
			gGankinTesuryoRituP,
			gGankinTesuryoRituC,
			gRikinTesuryoRituP,
			gRikinTesuryoRituC,
			gTesuryoKomiFlg,
			gSzeiSeikyuKbn					--消費税請求区分
		FROM
			MGR_TESURYO_PRM MG8,
			VJIKO_ITAKU SC18
		WHERE
				MG8.ITAKU_KAISHA_CD = SC18.KAIIN_ID
			AND	MG8.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
			AND	MG8.MGR_CD = l_inMeigaraCode;

		SELECT
			MG1.KAKUSHASAI_KNGK,		--各社債の金額
			MG1.BOSHU_KBN,				--募集区分
			MG1.SHOKAN_METHOD_CD,		--償還方法
			MG1.PARTMGR_KBN,			--分割銘柄区分
			MG1.GENISIN_CD				--原ISINコード
		INTO
			gKakuSyasaiKngk,
			gBoshuKbn,
			gShokanMethod,
			gPartMgrKbn,
			gGenisinCd
		FROM
			MGR_KIHON MG1
		WHERE
				MG1.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
			AND MG1.MGR_CD = l_inMeigaraCode;

		-- 子銘柄の場合、公債費特別会計の判定は親銘柄に依存するため、親銘柄の募集区分と償還方法に置き換える
		IF gPartMgrKbn = '2' THEN
			BEGIN
				SELECT
					BOSHU_KBN,
					SHOKAN_METHOD_CD
				INTO
					gBoshuKbn,
					gShokanMethod
				FROM
					MGR_KIHON
				WHERE
					ITAKU_KAISHA_CD	=	l_inItakuKaisyaCode
				AND	ISIN_CD			=	gGenisinCd
				AND	TRIM(ISIN_CD) IS NOT NULL;
			EXCEPTION
				WHEN OTHERS THEN
					null;
			END;
		END IF;

		/*基金異動区分による処理*/
		IF
				gKikinIdoKubun11 = '11'
			OR	gKikinIdoKubun12 = '12'
			OR	gKikinIdoKubun13 = '13'
		THEN
			/*銘柄_基本テーブル、銘柄_償還回次テーブルより抽出*/
			SELECT
				SUM(MG3.FUNIT_GENSAI_KNGK),		--振替単位償還支払金額
				SUM(MG3.FUNIT_SKN_PREMIUM)		--振替単位償還プレミアム
			INTO
				gFriKaeSyokanSiharai,
				gSyokanPremium
			FROM
				MGR_SHOKIJ MG3
			WHERE
					MG3.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
				AND	MG3.MGR_CD = l_inMeigaraCode
				AND	MG3.SHOKAN_KJT = l_inRbrKjt
				AND	MG3.SHOKAN_KBN IN('10','20','21','40','41','50')
			GROUP BY
				MG3.ITAKU_KAISHA_CD,MG3.MGR_CD,MG3.SHOKAN_KJT;
		END IF;

		IF
				gKikinIdoKubun21 = '21'
			OR	gKikinIdoKubun22 = '22'
			OR	gKikinIdoKubun23 = '23'
		THEN
			/*銘柄_利払回次テーブルより抽出*/
			SELECT
				TSUKARISHI_KNGK		--１通貨あたりの利子金額
			INTO
				gTukaRishiKngk
			FROM
				MGR_RBRKIJ
			WHERE
					ITAKU_KAISHA_CD = l_inItakuKaisyaCode
				AND	MGR_CD = l_inMeigaraCode
				AND	RBR_KJT = l_inRbrKjt;
			/*基準残高 設定*/
--			gKijunZndkT := gKijunZndkS;
			/*残高基準日 設定*/
			gZndkKijunYmdT := gZndkKijunYmdS;
		ELSE
			/*基準残高 設定*/
			gKijunZndkT := 0;
		END IF;

		/*基金異動履歴(会計区分別)テーブルに既にデータが存在する場合DELETE*/
		DELETE
		FROM
			KIKIN_IDO_KAIKEI
		WHERE
		ITAKU_KAISHA_CD = l_inItakuKaisyaCode
		AND	MGR_CD = l_inMeigaraCode
		AND	RBR_KJT = l_inRbrKjt
		AND IDO_YMD = l_inIdoYmd;

		-- 消費税率取得
		gSzeiRate := PKIPAZEI.getShohiZei(gRbrYmd);
		-- 総合計の内消費税の計算
		gSyohiZei := TRUNC((gGankinTesuryo + gRikinTesuryo)  * gSzeiRate / (1 + gSzeiRate));

		-- 処理制御値取得
		gresult := pkControl.getCtlValue( l_inItakuKaisyaCode, 'ChikoList', '0');
		
		/*基金異動履歴(会計区分別)テーブル登録*/
		FOR recKikinIdoT IN (
		SELECT
			H01.KOUSAIHI_FLG AS KOUSAIHI_FLG,
			H01.INPUT_NUM AS INPUT_NUM,
			H02.KAIKEI_KBN AS KAIKEI_KBN,
			H02.KAIKEI_KBN_ANBUN_KNGK AS KAIKEI_KBN_ANBUN_KNGK
		FROM
			KAIKEI_KBN H01,
			KAIKEI_ANBUN H02,
			MGR_KIHON MG1
		WHERE
			 	MG1.ITAKU_KAISHA_CD = H01.ITAKU_KAISHA_CD
			AND	MG1.HKT_CD = H01.HKT_CD
			AND	H01.ITAKU_KAISHA_CD = H02.ITAKU_KAISHA_CD
			AND 	H01.KAIKEI_KBN = H02.KAIKEI_KBN
			AND	H02.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
			AND	H02.MGR_CD = MG1.MGR_CD
			AND	H02.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
			AND	H02.MGR_CD = l_inMeigaraCode
		ORDER BY
			H02.KAIKEI_KBN
		) LOOP
			gRecKaikeiAnbun := gRecKaikeiAnbun + 1 ;

			/*公債費フラグの置き換え（公募またはその他かつ満期一括償還の銘柄のみを公債費に計上するため*/
			IF recKikinIdoT.KOUSAIHI_FLG = '1' THEN
				-- 1:SRの場合
				IF gresult = '1' THEN
					IF (gBoshuKbn = 'K' AND gShokanMethod = '1') OR (gBoshuKbn = 'S'  AND gShokanMethod = '1')
					THEN
						NULL;
					ELSE
						recKikinIdoT.KOUSAIHI_FLG := 0;
					END IF;
				
				END IF;
			END IF;

			/*元金・利金・手数料の按分計算、請求金額・消費税の計算*/

			-- 変数初期化
			gGankinAnbun := 0;
			gRikinAnbun := 0;
			gGankinTesuryoAnbun := 0;
			gRikinTesuryoAnbun := 0;
			gSeikyuKngkAnbun := 0;
			gSyohiZeiAnbun := 0;
			gKijunZndkAnbun := 0;

			IF gShasaiTotal > 0 THEN
				-- 元金の按分
				gGankinAnbun := TRUNC(gGankin * recKikinIdoT.KAIKEI_KBN_ANBUN_KNGK / gShasaiTotal);
				-- 利金の按分
				gRikinAnbun := TRUNC(gRikin * recKikinIdoT.KAIKEI_KBN_ANBUN_KNGK / gShasaiTotal);
				-- 元金手数料の按分
				gGankinTesuryoAnbun := TRUNC(gGankinTesuryo * recKikinIdoT.KAIKEI_KBN_ANBUN_KNGK / gShasaiTotal);
				-- 利金手数料の按分
				gRikinTesuryoAnbun := TRUNC(gRikinTesuryo * recKikinIdoT.KAIKEI_KBN_ANBUN_KNGK / gShasaiTotal);
				-- 請求金額（各金額の按分の合計）
				gSeikyuKngkAnbun := gGankinAnbun + gRikinAnbun + gGankinTesuryoAnbun + gRikinTesuryoAnbun;
				-- 消費税（請求金額（＝税込）の内消費税）
				gSyohiZeiAnbun := TRUNC((gGankinTesuryoAnbun + gRikinTesuryoAnbun) * gSzeiRate / (1 + gSzeiRate));
				-- 基準残高の按分
				gKijunZndkAnbun := TRUNC(gKijunZndkT * recKikinIdoT.KAIKEI_KBN_ANBUN_KNGK / gShasaiTotal);
			END IF;

			/*基金異動会計テーブル更新*/
			INSERT INTO KIKIN_IDO_KAIKEI(
					ITAKU_KAISHA_CD,		--委託会社コード
					MGR_CD,					--銘柄コード
					RBR_KJT,				--利払期日
					IDO_YMD,				--異動年月日
					KAIKEI_KBN,				--会計区分
					INPUT_NUM,				--入力順
					KKNBILL_SHURUI,
					RBR_YMD,				--利払日
					TSUKA_CD,				--通貨コード
					TSUKARISHI_KNGK,		--１通貨あたりの利子金額
					FUNIT_SKN_SHR_KNGK,		--振替単位償還支払金額
					KAKUSHASAI_KNGK,		--各社債の金額
					SHOKAN_PREMIUM,			--償還プレミアム
					GANKIN,					--元金
					RKN,					--利金
					GNKN_SHR_TESU_BUNBO,	--元金支払手数料率（分母）
					GNKN_SHR_TESU_BUNSHI,	--元金支払手数料率（分子）
					RKN_SHR_TESU_BUNBO,		--利金支払手数料率（分母）
					RKN_SHR_TESU_BUNSHI,	--利金支払手数料率（分子）
					GNKN_SHR_TESU_KNGK,		--元金支払手数料金額
					RKN_SHR_TESU_KNGK,		--利金支払手数料金額
					SEIKYU_KNGK,			--請求金額
					SZEI_KNGK,				--消費税金額
					KIJUN_ZNDK,				--基準残高
					ZNDK_KIJUN_YMD,			--残高基準日
					KOUSAIHI_FLG,			--公債費フラグ
					GROUP_ID,				--グループＩＤ
					SAKUSEI_ID)				--作成者
			VALUES(
					l_inItakuKaisyaCode,
					l_inMeigaraCode,
					l_inRbrKjt,
					l_inIdoYmd,
					recKikinIdoT.KAIKEI_KBN,
					recKikinIdoT.INPUT_NUM,
					gKknbillShurui,
					gRbrYmd,
					'JPY',
					gTukaRishiKngk,
					gFriKaeSyokanSiharai,
					gKakuSyasaiKngk,
					gSyokanPremium,
					gGankinAnbun,
					gRikinAnbun,
					gGankinTesuryoRituP,
					DECODE(gTesuryoKomiFlg,0,gGankinTesuryoRituC, --手数料率税込フラグが０なら率に税をかけない
						DECODE(gSzeiSeikyuKbn,0,
							gGankinTesuryoRituC, --手数料率税込フラグが１でも消費税請求区分が０なら率に税をかけない
							TRUNC(gGankinTesuryoRituC + (gGankinTesuryoRituC * pkIpaZei.getShohiZei(gRbrYmd)),14))),
					gRikinTesuryoRituP,
					DECODE(gTesuryoKomiFlg,0,gRikinTesuryoRituC, --手数料率税込フラグが０なら率に税をかけない
						DECODE(gSzeiSeikyuKbn,0,
							gRikinTesuryoRituC, --手数料率税込フラグが１でも消費税請求区分が０なら率に税をかけない
							TRUNC(gRikinTesuryoRituC + (gRikinTesuryoRituC * pkIpaZei.getShohiZei(gRbrYmd)),14))),
					gGankinTesuryoAnbun,
					gRikinTesuryoAnbun,
					gSeikyuKngkAnbun,
					gSyohiZeiAnbun,
					gKijunZndkAnbun,
					gZndkKijunYmdT,
					recKikinIdoT.KOUSAIHI_FLG,
					l_inGroupId,
					l_inUserId);
		END LOOP;
		IF
			gRecKaikeiAnbun > 1
		THEN
		/*基金異動履歴(会計区分別)テーブルが複数登録された場合端数処理を行なう*/
		/*最小の端数調整順位抽出*/
			SELECT
				MIN(H01.HASU_CHOSEI_JUNI)
			INTO
				gMinHasuChoseiJuni
			FROM
				KAIKEI_KBN H01,
				KAIKEI_ANBUN H02,
				MGR_KIHON MG1
			WHERE
					MG1.HKT_CD = H01.HKT_CD
				AND	MG1.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
				AND	MG1.MGR_CD = l_inMeigaraCode
				AND	H01.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
				AND H01.ITAKU_KAISHA_CD = H02.ITAKU_KAISHA_CD
				AND H01.KAIKEI_KBN = H02.KAIKEI_KBN
				AND H02.MGR_CD = l_inMeigaraCode
				AND	H01.KAIKEI_KBN <> '00';
			/*最小の端数調整順位がゼロの場合、ゼロ以外のアイテムをカウントする*/
			IF
				gMinHasuChoseiJuni = 0
			THEN
				SELECT
					COUNT(H01.HASU_CHOSEI_JUNI)
				INTO
					gCountHasuChoseiJuni
				FROM
					KAIKEI_KBN H01,
					KAIKEI_ANBUN H02,
					MGR_KIHON MG1
				WHERE
						MG1.HKT_CD = H01.HKT_CD
					AND	MG1.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
					AND	MG1.MGR_CD = l_inMeigaraCode
					AND	H01.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
					AND	H01.KAIKEI_KBN <> '00'
					AND H01.ITAKU_KAISHA_CD = H02.ITAKU_KAISHA_CD
					AND H01.KAIKEI_KBN = H02.KAIKEI_KBN
					AND H02.MGR_CD = l_inMeigaraCode
					AND	H01.HASU_CHOSEI_JUNI <> 0;
				/*端数調整順位にゼロ以外のアイテムが存在する場合
		 		*そのなかから最小の端数調整順位を取得する
				*/
				IF
					gCountHasuChoseiJuni > 0
				THEN
					SELECT
						MIN(H01.HASU_CHOSEI_JUNI)
					INTO
						gMinHasuChoseiJuni
					FROM
						KAIKEI_KBN H01,
						KAIKEI_ANBUN H02,
						MGR_KIHON MG1
					WHERE
							MG1.HKT_CD = H01.HKT_CD
						AND	MG1.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
						AND	MG1.MGR_CD = l_inMeigaraCode
						AND	H01.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
						AND	H01.KAIKEI_KBN <> '00'
						AND H01.ITAKU_KAISHA_CD = H02.ITAKU_KAISHA_CD
						AND H01.KAIKEI_KBN = H02.KAIKEI_KBN
						AND H02.MGR_CD = l_inMeigaraCode
						AND	H01.HASU_CHOSEI_JUNI <> 0;
				END IF;
			END IF;

			/*最小の端数調整順位を持つ会計区分をカウントする*/
			SELECT
				COUNT(H01.KAIKEI_KBN)
			INTO
				gCountKaikeiKubunM
			FROM
				KAIKEI_KBN H01,
				KAIKEI_ANBUN H02,
				MGR_KIHON MG1
			WHERE
					MG1.HKT_CD = H01.HKT_CD
				AND	MG1.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
				AND	MG1.MGR_CD = l_inMeigaraCode
				AND	H01.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
				AND	H01.KAIKEI_KBN <> '00'
				AND H01.ITAKU_KAISHA_CD = H02.ITAKU_KAISHA_CD
				AND H01.KAIKEI_KBN = H02.KAIKEI_KBN
				AND H02.MGR_CD = l_inMeigaraCode
				AND	H01.HASU_CHOSEI_JUNI = gMinHasuChoseiJuni;
			/*
			 *最小の端数調整順位がゼロ以外でかつ最小の端数調整順位を持つ会計区分がユニークな場合
			 *その会計区分を端数処理をする会計区分とする
			*/
			IF
					gMinHasuChoseiJuni <> 0
				AND	gCountKaikeiKubunM = 1
			THEN
				SELECT
					H01.KAIKEI_KBN
				INTO
					gKaikeiKubun
				FROM
					KAIKEI_KBN H01,
					KAIKEI_ANBUN H02,
					MGR_KIHON MG1
				WHERE
						MG1.HKT_CD = H01.HKT_CD
					AND	MG1.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
					AND	MG1.MGR_CD = l_inMeigaraCode
					AND	H01.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
					AND	H01.KAIKEI_KBN <> '00'
					AND H01.ITAKU_KAISHA_CD = H02.ITAKU_KAISHA_CD
					AND H01.KAIKEI_KBN = H02.KAIKEI_KBN
					AND H02.MGR_CD = l_inMeigaraCode
					AND	H01.HASU_CHOSEI_JUNI = gMinHasuChoseiJuni;
			ELSE
			/*会計区分別按分額テーブルより会計区分別按分額が最大の会計区分を求める*/
				SELECT
					MAX(KAIKEI_KBN_ANBUN_KNGK)
				INTO
					gMaxKaikeiKbnAnbunKngk
				FROM
					KAIKEI_ANBUN
				WHERE
						ITAKU_KAISHA_CD = l_inItakuKaisyaCode
					AND	MGR_CD = l_inMeigaraCode
					AND	KAIKEI_KBN <> '00';
			/*最大の会計区分別按分額を持つ会計区分をカウントする*/
				SELECT
					COUNT(KAIKEI_KBN)
				INTO
					gCountKaikeiKubunA
				FROM
					KAIKEI_ANBUN
				WHERE
						ITAKU_KAISHA_CD = l_inItakuKaisyaCode
					AND	MGR_CD = l_inMeigaraCode
					AND	KAIKEI_KBN <> '00'
					AND	KAIKEI_KBN_ANBUN_KNGK = gMaxKaikeiKbnAnbunKngk;
				/*
				 *最大の会計区分別按分額を持つ会計区分がユニークな場合
				 *その会計区分を端数処理をする会計区分とする
				 */
				IF
					gCountKaikeiKubunA = 1
				THEN
					SELECT
						KAIKEI_KBN
					INTO
						gKaikeiKubun
					FROM
						KAIKEI_ANBUN
					WHERE
							ITAKU_KAISHA_CD = l_inItakuKaisyaCode
						AND	MGR_CD = l_inMeigaraCode
						AND	KAIKEI_KBN <> '00'
						AND	KAIKEI_KBN_ANBUN_KNGK = gMaxKaikeiKbnAnbunKngk;
				ELSE
				/*
				 *最大の会計区分別按分額を持つ会計区分のなかから最小の会計区分を求め
				 *その会計区分を端数処理をする会計区分とする
				*/
					SELECT
						MIN(KAIKEI_KBN)
					INTO
						gKaikeiKubun
					FROM
						KAIKEI_ANBUN
					WHERE
							ITAKU_KAISHA_CD = l_inItakuKaisyaCode
						AND	MGR_CD = l_inMeigaraCode
						AND	KAIKEI_KBN <> '00'
						AND	KAIKEI_KBN_ANBUN_KNGK = gMaxKaikeiKbnAnbunKngk;
				END IF;
			END IF;
			/*基金異動履歴(会計区分別)テーブル集計処理*/
			SELECT
				SUM(GANKIN) AS SUM_GANKIN,
				SUM(RKN) AS SUM_RKN,
				SUM(GNKN_SHR_TESU_KNGK) AS SUM_GNKN_SHR_TESU_KNGK,
				SUM(RKN_SHR_TESU_KNGK) AS SUM_RKN_SHR_TESU_KNGK,
				SUM(SEIKYU_KNGK) AS SUM_SEIKYU_KNGK,
				SUM(SZEI_KNGK) AS SUM_SZEI_KNGK,
				SUM(KIJUN_ZNDK) AS SUM_KIJUN_ZNDK
			INTO
				gSumGankin,
				gSumRikin,
				gSumGankinTesuryo,
				gSumRikinTesuryo,
				gSumSeikyuKngk,
				gSumSyohiZei,
				gSumKijunZndk
			FROM
				KIKIN_IDO_KAIKEI
			WHERE
					ITAKU_KAISHA_CD = l_inItakuKaisyaCode
				AND	MGR_CD = l_inMeigaraCode
				AND	RBR_KJT = l_inRbrKjt
				AND	IDO_YMD = l_inIdoYmd;

			/*端数処理が必要な場合*/
			/*IP-05955 内消費税のみは調整結果が負の値も取りうると考えられるため、
			           負の値も端数処理を行う*/
			IF
					gGankin - gSumGankin > 0
				OR	gRikin - gSumRikin > 0
				OR	gGankinTesuryo - gSumGankinTesuryo > 0
				OR	gRikinTesuryo - gSumRikinTesuryo > 0
				OR	gSeikyuKngk - gSumSeikyuKngk > 0
				OR	gSyohiZei - gSumSyohiZei <> 0
				OR	gKijunZndkT - gSumKijunZndk > 0
			THEN
			/*端数調整する会計区分の更新前金額取得*/
				SELECT
					GANKIN,
					RKN,
					GNKN_SHR_TESU_KNGK,
					RKN_SHR_TESU_KNGK,
					SEIKYU_KNGK,
					SZEI_KNGK,
					KIJUN_ZNDK
				INTO
					gGankinHa,
					gRikinHa,
					gGankinTesuryoHa,
					gRikinTesuryoHa,
					gSeikyuKngkHa,
					gSyohiZeiHa,
					gKijunZndkHa
				FROM
					KIKIN_IDO_KAIKEI
				WHERE
						ITAKU_KAISHA_CD = l_inItakuKaisyaCode
					AND	MGR_CD = l_inMeigaraCode
					AND	RBR_KJT = l_inRbrKjt
					AND	IDO_YMD = l_inIdoYmd
					AND	KAIKEI_KBN = gKaikeiKubun;

				/* 端数寄せ後の 元金・利金・手数料の按分計算、請求金額・消費税のセット */
					-- 元金の按分
					gGankinHa := gGankinHa + (gGankin - gSumGankin);
					-- 利金の按分
					gRikinHa := gRikinHa + (gRikin - gSumRikin);
					-- 元金手数料の按分
					gGankinTesuryoHa := gGankinTesuryoHa + (gGankinTesuryo - gSumGankinTesuryo);
					-- 利金手数料の按分
					gRikinTesuryoHa := gRikinTesuryoHa + (gRikinTesuryo - gSumRikinTesuryo);
					-- 請求金額（各金額の按分の合計）
					gSeikyuKngkHa := gSeikyuKngkHa + (gSeikyuKngk - gSumSeikyuKngk);
					-- 消費税（請求金額（＝税込）の内消費税）
					gSyohiZeiHa := gSyohiZeiHa + (gSyohiZei - gSumSyohiZei);
					-- 基準残高の按分
					gKijunZndkHa := gKijunZndkHa + (gKijunZndkT - gSumKijunZndk);

				/*基金異動履歴(会計区分別)テーブル更新*/
				UPDATE
					KIKIN_IDO_KAIKEI
				SET
					GANKIN				= gGankinHa,
					RKN					= gRikinHa,
					GNKN_SHR_TESU_KNGK	= gGankinTesuryoHa,
					RKN_SHR_TESU_KNGK	= gRikinTesuryoHa,
					SEIKYU_KNGK			= gSeikyuKngkHa,
					SZEI_KNGK			= gSyohiZeiHa,
					KIJUN_ZNDK			= gKijunZndkHa
				WHERE
						ITAKU_KAISHA_CD = l_inItakuKaisyaCode
					AND	MGR_CD = l_inMeigaraCode
					AND	RBR_KJT = l_inRbrKjt
					AND	IDO_YMD = l_inIdoYmd
					AND	KAIKEI_KBN = gKaikeiKubun;
			END IF;
		ELSE
			IF
				gRecKaikeiAnbun = 0
			THEN
				/*該当データが存在しない場合エラーメッセージ出力(会計区分別按分額テーブル抽出なし)*/
				CALL pkLog.error('Batch','','基金異動履歴(会計区分別)データ作成 対象データが存在しませんでした。');
			END IF;
		END IF;
	ELSE
		/*該当データが存在しない場合エラーメッセージ出力(基金異動履歴テーブル抽出なし)*/
		CALL pkLog.error('Batch','','基金異動履歴(会計区分別)データ作成 対象データが存在しませんでした。');
	END IF;

	RETURN pkconstant.success();

/*====================================================================*
    異常終了 出口
 *====================================================================*/
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.debug(l_inUserId, SP_ID, '***** 基金異動履歴(会計区分別)データ作成エラー  *****');
		CALL pkLog.fatal(l_inUserId, SP_ID, SQLSTATE||' '||SUBSTR(SQLERRM, 1, 100));
		RETURN pkconstant.fatal();
END;
$body$;
