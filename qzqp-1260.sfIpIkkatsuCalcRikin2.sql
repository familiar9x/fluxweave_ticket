




CREATE OR REPLACE FUNCTION sfipikkatsucalcrikin2 ( l_inHendoList typeHendoIkkatuList2, l_inItakuKaishaCd text, l_inKijunKinriRrt1 text, l_inKijunKinriRrt2 text, l_inKinriMaxKinri numeric, l_inKinriMaxSpread numeric, l_inKinriFloorKinri numeric, l_inKinriFloorSpread numeric, l_outTsukarishiKngkList OUT typeTsukarishiKngkList2 , OUT extra_param integer) RETURNS record AS $body$
DECLARE

	----------------------------------------------------------------------
	-- ローカル変数定義
	----------------------------------------------------------------------
	i					numeric;
	ret					numeric;
	rowNo				varchar(30);							-- ROWID
	rbrKawaseRate		numeric;									-- 利払為替レート
	nissuksnKbn			varchar(1);							-- 実日数計算区分
	riritsu				numeric;									-- 利率
	tekiyoKinri numeric;
	tekiyoCapKinri numeric;
	tekiyoFloorKinri numeric;
	tekiyoFlg 	varchar(1);
	itakuKaishaCd		MGR_KIHON.ITAKU_KAISHA_CD%TYPE;			-- 委託会社コード
	mgrCd				MGR_KIHON.MGR_CD%TYPE;					-- 銘柄コード
	hakkoYmd			MGR_KIHON.HAKKO_YMD%TYPE;				-- 発行日
	fullshokanKjt		MGR_KIHON.FULLSHOKAN_KJT%TYPE;			-- 満期償還期日
	stRbrKjt			MGR_KIHON.ST_RBR_KJT%TYPE;				-- 初回利払期日
	hankanenKbn			MGR_KIHON.HANKANEN_KBN%TYPE;			-- 半ヶ年区分
	fstNissuksnKbn		MGR_KIHON.FST_NISSUKSN_KBN%TYPE;		-- 初期実日数計算区分
	kichuNissuksnKbn	MGR_KIHON.KICHU_NISSUKSN_KBN%TYPE;		-- 期中実日数計算区分
	endNissuksnKbn		MGR_KIHON.END_NISSUKSN_KBN%TYPE;		-- 終期実日数計算区分
	rbrNissuSpan		MGR_KIHON.RBR_NISSU_SPAN%TYPE;			-- 利払日数計算間隔
	rbrKjtInclusionKbn	MGR_KIHON.RBR_KJT_INCLUSION_KBN%TYPE;	-- 利払期日算入区分
	rknRoundProcess		MGR_KIHON.RKN_ROUND_PROCESS%TYPE;		-- 利金計算単位未満端数処理
	nenrbrCnt			MGR_KIHON.NENRBR_CNT%TYPE;				-- 年利払回数
	rbrDd				MGR_KIHON.RBR_DD%TYPE;					-- 利払日付
	kyujitsuKbn			MGR_KIHON.KYUJITSU_KBN%TYPE;			-- 休日処理区分
	tokureiShasaiFlg	MGR_KIHON.TOKUREI_SHASAI_FLG%TYPE;		-- 特例社債フラグ
	kakushasaiKngk		MGR_KIHON.KAKUSHASAI_KNGK%TYPE;			-- 各社債の金額
	rbrFromKjt			MGR_RBRKIJ.RBR_KJT%TYPE;				-- 利払期日(From)
	rbrToKjt			MGR_RBRKIJ.RBR_YMD%TYPE;				-- 利払期日(To)
	rbrFromYmd			MGR_RBRKIJ.RBR_KJT%TYPE;				-- 利払日(From)
	rbrToYmd			MGR_RBRKIJ.RBR_YMD%TYPE;				-- 利払日(To)
	shokaiRbrKbn		varchar(1);							-- 初回利払区分
	befRbrKjt			varchar(8);							-- 前回利払期日
	befRbrYmd			varchar(8);							-- 前回利払日
	lastRbrKjt			varchar(8);							-- 最終利払期日
	rbrKjt				MGR_RBRKIJ.RBR_KJT%TYPE;				-- 利払期日
	rbrYmd				MGR_RBRKIJ.RBR_YMD%TYPE;				-- 利払日
	kaiji				MGR_RBRKIJ.KAIJI%TYPE;					-- 回次番号
	chooseFlg			MGR_TESURYO_CTL.CHOOSE_FLG%TYPE;		-- 選択フラグ
	rbrKikanFromYmd		MGR_RBRKIJ.RKN_CALC_F_YMD%TYPE;			-- 利金計算期間（FROM）
	rbrKikanToYmd		MGR_RBRKIJ.RKN_CALC_T_YMD%TYPE;			-- 利金計算期間（TO）
	spananbunBunbo		MGR_RBRKIJ.SPANANBUN_BUNBO%TYPE;		-- 期間按分分母
	spananbunBunshi		MGR_RBRKIJ.SPANANBUN_BUNSHI%TYPE;		-- 期間按分分子
	tsukarishiKngk		numeric;									-- １通貨あたりの利子額
	errorID1			varchar(20);							-- エラーID1
	errorID2			varchar(60);							-- エラーID2
	areaCd				varchar(30);							-- 地域コード
  calcMode      varchar(1);              -- 計算モード
	----------------------------------------------------------------------
	-- ローカル定数定義
	----------------------------------------------------------------------
	ID_WIP023			CONSTANT text := 'WIP023';
	ID_WIP036			CONSTANT text := 'WIP036';
	SP_ID				CONSTANT text := 'sfIpIkkatsuCalcRikin2';
--====================================================================*
--		メイン
-- *====================================================================
BEGIN
	l_outTsukarishiKngkList := '{}';
	-- 件数分繰り返し
	FOR i IN 1..coalesce(cardinality(l_inHendoList), 0) LOOP
		rowNo := l_inHendoList[i].rowNo;
		rbrKawaseRate := l_inHendoList[i].rbrKawaseRate;
		errorID1 := NULL;					-- エラーメッセージ初期化
		errorID2 := NULL;					-- エラーメッセージ初期化
		SELECT	trim(both VMG1.ITAKU_KAISHA_CD),
				trim(both VMG1.MGR_CD),
				trim(both VMG1.HAKKO_YMD),
				trim(both VMG1.FULLSHOKAN_KJT),
				trim(both VMG1.NENRBR_CNT),
				trim(both VMG1.RBR_DD),
				trim(both VMG1.ST_RBR_KJT),
				trim(both VMG1.RIRITSU),
				trim(both VMG1.HANKANEN_KBN),
				trim(both VMG1.FST_NISSUKSN_KBN),
				trim(both VMG1.KICHU_NISSUKSN_KBN),
				trim(both VMG1.END_NISSUKSN_KBN),
				trim(both VMG1.RBR_NISSU_SPAN),
				trim(both VMG1.RBR_KJT_INCLUSION_KBN),
				trim(both VMG1.RKN_ROUND_PROCESS),
				trim(both VMG1.KYUJITSU_KBN),
				trim(both VMG1.AREACD),
				trim(both VMG1.TOKUREI_SHASAI_FLG),
				trim(both VMG1.KAKUSHASAI_KNGK),
				trim(both MG2.RBR_KJT),
				trim(both MG2.RBR_YMD),
				trim(both MG2.KAIJI),
				trim(both MG7.CHOOSE_FLG)
		INTO STRICT	itakuKaishaCd,
				mgrCd,
				hakkoYmd,
				fullshokanKjt,
				nenrbrCnt,
				rbrDd,
				stRbrKjt,
				riritsu,
				hankanenKbn,
				fstNissuksnKbn,
				kichuNissuksnKbn,
				endNissuksnKbn,
				rbrNissuSpan,
				rbrKjtInclusionKbn,
				rknRoundProcess,
				kyujitsuKbn,
				areaCd,
				tokureiShasaiFlg,
				kakushasaiKngk,
				rbrKjt,
				rbrYmd,
				kaiji,
				chooseFlg
		FROM mgr_rbrkij mg2, mgr_kihon_view vmg1
LEFT OUTER JOIN mgr_tesuryo_ctl mg7 ON (VMG1.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD AND VMG1.MGR_CD = MG7.MGR_CD AND '61' = MG7.TESU_SHURUI_CD)
WHERE MG2.oid = rowNo AND VMG1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD AND VMG1.MGR_CD = MG2.MGR_CD;
		-- 利払期日 = 初回利払期日の場合
		IF (rbrKjt = stRbrKjt) THEN
			-- 開始日-->発行年月日
			rbrFromKjt := hakkoYmd;
			rbrFromYmd := hakkoYmd;
			-- 終了日-->今回の利払期日・利払日
			rbrToKjt := rbrKjt;
			rbrToYmd := rbrYmd;
			shokaiRbrKbn := '1';
			-- 初期実日数計算区分がセットされていない場合
			IF (coalesce(fstNissuksnKbn::text, '') = '') THEN
				-- 期中実日数計算区分
				nissuksnKbn := kichuNissuksnKbn;
			ELSE
				-- 初期実日数計算区分
				nissuksnKbn := fstNissuksnKbn;
			END IF;
		-- 期中、終期の場合
		ELSE
			-- 特例債で１回次目の場合
			IF (tokureiShasaiFlg = 'Y' and kaiji = '1') THEN
				-- 前回の利払期日・利払日、最終利払期日を取得
				ret := sfIpGetBeforeRbrKjt(itakuKaishaCd,
										mgrCd,
										rbrKjt,
										befRbrKjt,
										befRbrYmd,
										lastRbrKjt);
			ELSE
				-- 前回次の利払期日・利払日、最終利払期日を取得
				SELECT	MG2.RBR_KJT,
						MG2.RBR_YMD,
						(SELECT MAX(MG2.RBR_KJT) FROM MGR_RBRKIJ MG2 WHERE MG2.ITAKU_KAISHA_CD = itakuKaishaCd AND MG2.MGR_CD = mgrCd) AS RBR_KJT
				INTO STRICT	befRbrKjt,
						befRbrYmd,
						lastRbrKjt
				FROM (
						SELECT	MG2.ITAKU_KAISHA_CD,
								MG2.MGR_CD,
								trim(both MAX(MG2.RBR_KJT)) AS RBR_KJT
						FROM	MGR_RBRKIJ MG2
						WHERE	MG2.ITAKU_KAISHA_CD = itakuKaishaCd
						AND		MG2.MGR_CD = mgrCd
						AND		MG2.RBR_KJT < rbrKjt
						GROUP BY
								MG2.ITAKU_KAISHA_CD,
								MG2.MGR_CD) WMG2,
						MGR_RBRKIJ MG2
				WHERE	MG2.ITAKU_KAISHA_CD = WMG2.ITAKU_KAISHA_CD
				AND		MG2.MGR_CD = WMG2.MGR_CD
				AND		MG2.RBR_KJT = WMG2.RBR_KJT;
			END IF;
			-- 前回の利払期日、利払日
			rbrFromKjt := befRbrKjt;
			rbrFromYmd := befRbrYmd;
			-- 今回の利払期日・利払日
			rbrToKjt := rbrKjt;
			rbrToYmd := rbrYmd;
			shokaiRbrKbn := '0';
			-- 実日数計算区分
			-- 利払期日 = 算出した最終利払期日の場合
			IF (rbrKjt = lastRbrKjt) THEN
				IF (coalesce(endNissuksnKbn::text, '') = '') THEN
					-- 期中実日数計算区分
					nissuksnKbn := kichuNissuksnKbn;
				ELSE
					-- 終期実日数計算区分
					nissuksnKbn := endNissuksnKbn;
				END IF;
			-- 期中
			ELSE
				nissuksnKbn := kichuNissuksnKbn;
			END IF;
		END IF;
		IF (coalesce(l_inKinriMaxKinri,0))::numeric  <> 0 OR
		(coalesce(l_inHendoList[i].maxKinri,0))::numeric  <> 0 OR
		(coalesce(l_inKinriMaxSpread,0))::numeric  <> 0 THEN
			calcmode := '1';
		ELSIF (coalesce(l_inKinriFloorKinri,0))::numeric  <> 0 OR
		(coalesce(l_inHendoList[i].floorKinri,0))::numeric  <> 0 OR
		(coalesce(l_inKinriFloorSpread,0))::numeric  <> 0 THEN
			calcmode := '2';
		ELSE
			calcMode := '0';
 		END IF;
		IF calcMode = '0' THEN
			   -- 利率の算出
			riritsu := (coalesce(l_inKijunKinriRrt1, 0))::numeric  - (coalesce(l_inKijunKinriRrt2, 0))::numeric  + (coalesce(l_inHendoList[i].spread, 0))::numeric;
			tekiyoKinri := 0;
			tekiyoCapKinri := 0;
			tekiyoFloorKinri := 0;
			tekiyoFlg := 0;
		ELSE
			ret := sfCalcKetteiRiritsu(
				calcmode,
				(coalesce(l_inKijunKinriRrt1, 0))::numeric ,
				(coalesce(l_inKijunKinriRrt2, 0))::numeric ,
				(coalesce(l_inHendoList[i].spread,0))::numeric ,
				l_inKinriMaxKinri,
				l_inKinriMaxSpread,
				(coalesce(l_inHendoList[i].maxKinri,0))::numeric ,
				l_inKinriFloorKinri,
				l_inKinriFloorSpread,
				(coalesce(l_inHendoList[i].floorKinri,0))::numeric ,
				tekiyoKinri,
				tekiyoCapKinri,
				tekiyoFloorKinri,
				riritsu,
				tekiyoFlg
				);
		END IF;
		-- 算出した利率がマイナス値の場合は、０にする
		IF (riritsu < 0) THEN
			riritsu := 0;
		END IF;
		IF (riritsu = 0) THEN
			-- 利率が０の場合は、ワーニングメッセージを返す
			errorID1 := ID_WIP023;
			IF (chooseFlg = 1 and (pkControl.getOPTION_FLG(l_inItakuKaishaCd, 'IPX1011113010', '0')) = 1) THEN
				-- 利率が０、かつ『利金０時利金手数料（元金）請求書』オプションフラグが１のとき、ワーニングを返す。
				errorID2 := ID_WIP036;
			END IF;
		END IF;
		-- １通貨あたりの利子額算出
		ret := sfCalcKichuTsukarishiKngk(
								l_inItakuKaishaCd,
								mgrCd,
								riritsu,
								rbrFromKjt,
								rbrToKjt,
								rbrFromYmd,
								rbrToYmd,
								hankanenKbn,
								nissuksnKbn,
								rbrNissuSpan,
								rbrKjtInclusionKbn,
								rknRoundProcess,
								nenrbrCnt,
								rbrKawaseRate,
								shokaiRbrKbn,
								rbrDd,
								areaCd,
								kyujitsuKbn,
								kakushasaiKngk,
								tokureiShasaiFlg,
								rbrKikanFromYmd,
								rbrKikanToYmd,
								spananbunBunbo,
								spananbunBunshi,
								tsukarishiKngk);
		-- 利金計算結果をOUTパラメタにセット
		l_outTsukarishiKngkList := array_append(l_outTsukarishiKngkList, null);
		l_outTsukarishiKngkList[coalesce(cardinality(l_outTsukarishiKngkList), 0)] := ROW(
																						riritsu,
																						rbrKikanFromYmd,
																						rbrKikanToYmd,
																						spananbunBunbo,
																						spananbunBunshi,
																						tsukarishiKngk,
																						errorID1,
																						errorID2,
                                            tekiyoKinri,
                                            tekiyoCapKinri,
                                            tekiyoFloorKinri,
                                            tekiyoFlg)::typeTsukarishiKngkRecord2;
	END LOOP;
	extra_param := pkconstant.success();
	RETURN;
--====================================================================*
--    異常終了 出口
-- *====================================================================
EXCEPTION
	WHEN no_data_found THEN
		CALL pkLog.fatal('ECM701', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
		extra_param := pkconstant.error();
		RETURN;
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
		extra_param := pkconstant.error();
		RETURN;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipikkatsucalcrikin2 ( l_inHendoList typeHendoIkkatuList2, l_inItakuKaishaCd text, l_inKijunKinriRrt1 text, l_inKijunKinriRrt2 text, l_inKinriMaxKinri numeric, l_inKinriMaxSpread numeric, l_inKinriFloorKinri numeric, l_inKinriFloorSpread numeric, l_outTsukarishiKngkList OUT typeTsukarishiKngkList2 , OUT extra_param integer) FROM PUBLIC;