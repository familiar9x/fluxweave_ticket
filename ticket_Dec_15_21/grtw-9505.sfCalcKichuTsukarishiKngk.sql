




CREATE OR REPLACE FUNCTION sfcalckichutsukarishikngk ( l_inItakuKaishaCd text, l_inMgrCd text, l_inRiritsu numeric, l_inRbrFromKjt text, l_inRbrToKjt text, l_inRbrFromYmd text, l_inRbrToYmd text, l_inHankanenKbn text, l_inNissuksnKbn text, l_inRbrNissuSpan text, l_inRbrKjtInclusionKbn text, l_inRknRoundProcess text, l_inNenrbrCnt text, l_inRbrKawaseRate numeric, l_inShokaiRbrKbn text, l_inRbrDd text, l_inAreaCd text, l_inKyujitsuKbn text, l_inKakushasaiKngk numeric, l_inTokureiShasaiFlg text, l_outRbrKikanFromYmd OUT text, l_outRbrKikanToYmd OUT text, l_outSpananbunBunbo OUT integer, l_outSpananbunBunshi OUT integer, l_outTsukarishiKngk OUT numeric , OUT extra_param integer) RETURNS record AS $body$
DECLARE

--*
-- * 期中銘柄変更利払、変動利率一括画面から呼び出される
-- * １通貨あたりの利子額を算出するファンクションです。
-- *
-- * @author 藤本　和哉
-- * @author 久保　由紀子
-- * @version $Id:$
-- *
-- ************************************************
-- * 注意
-- * sfTsukarishiKngk.sqlが更新されるときは
-- *「sfCalcKichuTsukarishiKngk.sql」も修正してください。
-- ************************************************
-- *
-- * @param l_inItakuKaishaCd   委託会社コード
-- * @param l_inMgrCd   銘柄コード
-- * @param l_inRiritsu   利率
-- * @param l_inRbrFromKjt   利払期日（開始日）
-- * @param l_inRbrToKjt   利払期日（終了日）
-- * @param l_inRbrFromYmd   利払日（開始日）
-- * @param l_inRbrToYmd   利払日（終了日）
-- * @param l_inHankanenKbn   半ヶ年区分
-- * @param l_inNissuksnKbn   実日数計算区分
-- * @param l_inRbrNissuSpan   利払日数計算間隔
-- * @param l_inRbrKjtInclusionKbn   利払期日算入区分
-- * @param l_inRknRoundProcess   利金計算単位未満端数処理
-- * @param l_inNenrbrCnt   年利払回数
-- * @param l_inRbrKawaseRate   利払為替レート
-- * @param l_inShokaiRbrKbn   初回利払区分（初回：１、初回以外：０）
-- * @param l_inRbrDd   利払日付
-- * @param l_inAreaCd   地域コード
-- * @param l_inKyujitsuKbn   休日処理区分
-- * @param l_inKakushasaiKngk   各社債の金額
-- * @param l_inTokureiShasaiFlg 特例社債フラグ
-- * @param l_outRbrKikanFromYmd   利払期間開始日
-- * @param l_outRbrKikanToYmd   利払期間終了日
-- * @param l_outSpananbunBunbo   期間按分分母
-- * @param l_outSpananbunBunshi   期間按分分子
-- * @param l_outTsukarishiKngk   １通貨あたりの利子額
-- * @return err  リターンコード
-- 
--====================================================================*
--	変数定義
-- *====================================================================
-- 利払期間開始日 分子（利払回次から取得）
	wk_rbrKikanFromYmd	varchar(8);
-- 利払期間終了日 分子（利払回次から取得）
	wk_rbrKikanToYmd	varchar(8);
-- 年利払間隔 
	wk_nenrbrInterval	numeric(2);
-- 期間按分分母（利払回次から取得） 
	wk_spananbunBunbo	integer;
-- 期間按分分子（利払回次から取得） 
	wk_spananbunBunshi	integer;
-- 期間按分分子（端数計算判定用） 
	wk_spananbunBunshi_check integer;
-- 期間按分分母（端数計算判定用） 
	wk_spananbunBunbo_check	integer;
-- １回分外だしの有無
	wk_onceOutUmu		char(1);
-- １回の通貨あたりの利子額 
	wk_onceTsukarishiKngk	decimal(14,13);
-- 端数利子額 
	wk_hasuTsukarishiKngk	numeric;
-- 利払為替レート 
	wk_rbrKawaseRate	numeric;
-- 半ヶ年分母 
	wk_hankanenBunbo	numeric;
-- 年利払回数 
	wk_nenrbrCnt		numeric;
-- 応答日 
	wk_ReplyYmd			varchar(8);
-- 閏年対応365日の分母の起点 
	wk_uru365Ymd		varchar(8);
-- 応答日(開始日） 分母
	wk_answerFromYmd	varchar(8);
-- 応答日(終了日） 分母
	wk_answerToYmd		varchar(8);
-- 処理制御フラグ 
	CTL_VALUE			MPROCESS_CTL.CTL_VALUE%TYPE;
--====================================================================*
--	ユーザ例外定義
-- *====================================================================
			-- パラメタ不正例外
--====================================================================*
--	エラー定義
-- *====================================================================
	err integer := 1;
--====================================================================*
--			メイン
-- *====================================================================
BEGIN
	-- OUTパラメタ初期化
	l_outRbrKikanFromYmd := NULL;
	l_outRbrKikanToYmd := NULL;
	l_outSpananbunBunbo := 0;
	l_outSpananbunBunshi := 0;
	l_outTsukarishiKngk := 0;
	-- 処理制御マスタで通貨あたり利子額算出式を制御する
	CTL_VALUE := pkControl.getCtlValue(l_inItakuKaishaCd, 'sfTsukarishiKng', '0');
  -- 利払回次取得select
	SELECT
		MG2.RKN_CALC_F_YMD,
		MG2.RKN_CALC_T_YMD,
		MG2.SPANANBUN_BUNBO,
		MG2.SPANANBUN_BUNSHI
	INTO STRICT
		wk_rbrKikanFromYmd,
		wk_rbrKikanToYmd,
		wk_spananbunBunbo,
		wk_spananbunBunshi
	FROM
		MGR_RBRKIJ MG2
	WHERE
				MG2.ITAKU_KAISHA_CD = l_inItakuKaishaCd
	AND		MG2.MGR_CD = l_inMgrCd
	AND		MG2.RBR_KJT = l_inRbrToKjt
	AND		MG2.KAIJI != 0;
	-- ************************************************************* 
	-- 分子の日数を算出する。                                        
	-- ************************************************************* 
	-- outパラメータにはこの時点でセットする 
	-- 分子　計算期間Fromto                  
	l_outRbrKikanFromYmd := wk_rbrKikanFromYmd;	-- 分子の計算期間FromYmd 
	l_outRbrKikanToYmd := wk_rbrKikanToYmd;		-- 分子の計算期間ToYmd 
	-- 按分分子算出（端数計算判定用）
	wk_spananbunBunshi_check := to_date(l_outRbrKikanToYmd,'YYYYMMDD') - to_date(l_outRbrKikanFromYmd,'YYYYMMDD') + 1;
	-- ************************************************************* 
	-- 分母の日数と１通貨あたりの利子額を算出する。                  
	-- ************************************************************* 
	-- 計算に使用するの変数初期化 
	wk_onceTsukarishiKngk := 0;
	wk_hasuTsukarishiKngk := 0;
	-- 半か年実日数、閏年対応３６５日の分母計算期間FromTO用 
	wk_answerFromYmd := NULL;
	wk_answerToYmd := NULL;
	-- １回分外だしの有無（有：１、なし：null） 
	wk_onceOutUmu := NULL;
	-- 利払為替レートチェック
	IF (coalesce(l_inRbrKawaseRate::text, '') = '' OR l_inRbrKawaseRate = 0) THEN
		wk_rbrKawaseRate := 1;
	ELSE
		wk_rbrKawaseRate := l_inRbrKawaseRate;
	END IF;
	-- 年利払間隔（ヶ月）を取得する 
	wk_nenrbrInterval := sfCalcKichuTsukarishiKngk_sfKaijiInterval(l_inNenrbrCnt);
	-------------------------------------------------------------
	-- 実日数計算区分 = "4"(半ヵ年実日数) の分母算出用
	-- 利払日間隔の場合は、期日を基にPGMで応答日を算出後に営業日補正を行うため期日を設定する。
	-------------------------------------------------------------
	-- 実日数計算区分 = "4"(半ヵ年実日数) 
	IF (l_inNissuksnKbn ='4') THEN
		wk_hankanenBunbo := l_inNenrbrCnt::numeric;
	ELSE
		wk_hankanenBunbo := 1;
	END IF;
	-- ************************************************************* 
	-- １/年利払回数or１回分外だしの判定を行う。
--	/*   1.ロングの場合、１回分の１通貨あたりの利子額を算出
--	/*   2.ロングの場合、端数部分の分子日数と分母計算期間FROM-TOを算出
--	/* ************************************************************* 
	-- 実日数計算区分 = "5"(1／年利払回数) の時 
	IF (l_inNissuksnKbn = '5') THEN
		-- 初期・期中・終期に関わらず丸１回の利子額のみ。端数は算出しない 
		wk_onceTsukarishiKngk := sfCalcKichuTsukarishiKngk_sfOnceTsukarishiKngk(l_inRiritsu, l_inNenrbrCnt, wk_rbrKawaseRate, l_inTokureiShasaiFlg, CTL_VALUE, l_inRknRoundProcess, l_inKakushasaiKngk);
		wk_onceOutUmu := '1';
		-- 端数利子額は算出しないのでNULLセット 
		wk_rbrKikanFromYmd := NULL;
		wk_rbrKikanToYmd := NULL;
	ELSE
		-- 半ヶ年区分＝"1"（半ヶ年（年利払回数割））の場合 
		IF (l_inHankanenKbn = '1') THEN
			-- 初期または終期  ロングかショートかの判定と１回分の通貨利子金額と 
			-- 外出しする端数分の利払期間開始日、終了日を設定 
			CALL sfCalcKichuTsukarishiKngk_sfKikananBunbo(
						l_inRbrFromKjt,
						l_inRbrToKjt,
						l_inShokaiRbrKbn,
						wk_nenrbrInterval,
						l_inRbrNissuSpan,
						l_inRbrDd,
						l_inKyujitsuKbn,
						l_inAreaCd,
						wk_ReplyYmd,
						wk_answerFromYmd,
						wk_answerToYmd,
						wk_spananbunBunbo_check);
			-- 期間按分分母 < 期間按分分子の時（ロング） 
			IF (wk_spananbunBunbo_check < wk_spananbunBunshi_check) THEN
			-- １回の通貨あたりの利子額を算出する
			wk_onceTsukarishiKngk := sfCalcKichuTsukarishiKngk_sfOnceTsukarishiKngk(l_inRiritsu, l_inNenrbrCnt, wk_rbrKawaseRate, l_inTokureiShasaiFlg, CTL_VALUE, l_inRknRoundProcess, l_inKakushasaiKngk);
				wk_onceOutUmu := '1';
			-- 期間按分分母 = 期間按分分子の時  （利払期間＝丸１回分の利子額利払期間） 
			ELSIF (wk_spananbunBunbo_check = wk_spananbunBunshi_check) THEN
				-- １回の通貨あたりの利子額を算出する 端数計算なし
				wk_onceTsukarishiKngk := sfCalcKichuTsukarishiKngk_sfOnceTsukarishiKngk(l_inRiritsu, l_inNenrbrCnt, wk_rbrKawaseRate, l_inTokureiShasaiFlg, CTL_VALUE, l_inRknRoundProcess, l_inKakushasaiKngk);
				wk_onceOutUmu := '1';
				-- 端数利子額は算出しないのでNULLセット 
				wk_rbrKikanFromYmd := NULL;
				wk_rbrKikanToYmd := NULL;
			ELSE
			-- 期間按分分母 > 期間按分分子の時（ショート） なにもしない。
				wk_onceTsukarishiKngk := 0;
			END IF;
		END IF;
	END IF;
	-- **************************************************************************** 
	-- 端数日数部分の分母日数と端数部分の利子金額を算出
--	/* （その他実日数選択・ショート・ロングの端数部分の１通貨あたりの利子額を算出
--	/* **************************************************************************** 
	IF (((trim(both wk_rbrKikanFromYmd) IS NOT NULL AND (trim(both wk_rbrKikanFromYmd))::text <> '')) AND ((trim(both wk_rbrKikanToYmd) IS NOT NULL AND (trim(both wk_rbrKikanToYmd))::text <> ''))) THEN
		IF (l_inTokureiShasaiFlg = 'Y' AND CTL_VALUE = '1') THEN
			-- 新計算方式で計算 端数計算は切上
			IF (l_inRknRoundProcess = '1') THEN
				wk_hasuTsukarishiKngk := TRUNC(TRUNC(l_inKakushasaiKngk * l_inRiritsu / 100 * 1 / wk_hankanenBunbo * wk_spananbunBunshi / wk_spananbunBunbo / wk_rbrKawaseRate) / l_inKakushasaiKngk::numeric, 13);
			ELSIF (l_inRknRoundProcess = '2') THEN
				wk_hasuTsukarishiKngk := TRUNC(ROUND(l_inKakushasaiKngk * l_inRiritsu / 100 * 1 / wk_hankanenBunbo * wk_spananbunBunshi / wk_spananbunBunbo / wk_rbrKawaseRate) / l_inKakushasaiKngk::numeric, 13);
			ELSIF (l_inRknRoundProcess = '3') THEN
				wk_hasuTsukarishiKngk := TRUNC(TRUNC((l_inKakushasaiKngk * l_inRiritsu / 100 * 1 / wk_hankanenBunbo * wk_spananbunBunshi / wk_spananbunBunbo / wk_rbrKawaseRate) + .9) / l_inKakushasaiKngk, 13);
			END IF;
		ELSE
			-- 端数部分の利子額計算 
			wk_hasuTsukarishiKngk := l_inRiritsu / 100 * 1 / wk_hankanenBunbo * wk_spananbunBunshi / wk_spananbunBunbo / wk_rbrKawaseRate;
			-- 利金計算単位未満端数処理区分によって小数第14位の端数計算を行う 
			wk_hasuTsukarishiKngk := sfCalcKichuTsukarishiKngk_sfTsukarishiKngkDecimalCalc(l_inRknRoundProcess, wk_hasuTsukarishiKngk);
		END IF;
	END IF;
	-- ************************************************************* 
	-- OUTパラメータにセット
--	/* ************************************************************* 
	l_outSpananbunBunshi := wk_spananbunBunshi;	-- 端数部分 分子の日数 
	l_outSpananbunBunbo  := wk_spananbunBunbo;	-- 端数部分 分母の日数 
	-- １回あたりの利子額と端数利子額を合算 
	l_outTsukarishiKngk := wk_hasuTsukarishiKngk + coalesce(wk_onceTsukarishiKngk, 0);
	extra_param := 0;
	RETURN;
--====================================================================*
--    異常終了 出口
-- *====================================================================
EXCEPTION
	WHEN SQLSTATE '50001' THEN
		CALL pkLog.debug('sfCalcKichuTsukarishiKngk：', '', '１通貨あたりの利子額算出処理のパラメタが正しくありません');
		extra_param := err;
		RETURN;
	WHEN OTHERS THEN
		CALL pkLog.debug('sfCalcKichuTsukarishiKngk：', '', '１通貨あたりの利子額算出処理でエラーが発生しました');
		CALL pkLog.debug('sfCalcKichuTsukarishiKngk(SQLCODE)：', '', SQLSTATE);
		CALL pkLog.debug('sfCalcKichuTsukarishiKngk(SQLERRM)：', '', SQLERRM);
		extra_param := err;
		RETURN;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfcalckichutsukarishikngk ( l_inItakuKaishaCd text, l_inMgrCd text, l_inRiritsu numeric, l_inRbrFromKjt text, l_inRbrToKjt text, l_inRbrFromYmd text, l_inRbrToYmd text, l_inHankanenKbn text, l_inNissuksnKbn text, l_inRbrNissuSpan text, l_inRbrKjtInclusionKbn text, l_inRknRoundProcess text, l_inNenrbrCnt text, l_inRbrKawaseRate numeric, l_inShokaiRbrKbn text, l_inRbrDd text, l_inAreaCd text, l_inKyujitsuKbn text, l_inKakushasaiKngk numeric, l_inTokureiShasaiFlg text, l_outRbrKikanFromYmd OUT text, l_outRbrKikanToYmd OUT text, l_outSpananbunBunbo OUT integer, l_outSpananbunBunshi OUT integer, l_outTsukarishiKngk OUT numeric , OUT extra_param integer) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfcalckichutsukarishikngk_sfkaijiinterval ( l_inNenkaisu text		--年利払回数
 ) RETURNS integer AS $body$
DECLARE

wk_nenkaisu			numeric(2);
wk_kaijiInterval	numeric(2);

BEGIN
wk_nenkaisu := (l_inNenkaisu)::numeric;
IF (wk_nenkaisu = 0) THEN
	wk_kaijiInterval := 0;
ELSE
	wk_kaijiInterval := 12 / wk_nenkaisu;
END IF;
RETURN wk_kaijiInterval;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfcalckichutsukarishikngk_sfkaijiinterval ( l_inNenkaisu text ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfcalckichutsukarishikngk_sfkikananbunbo ( l_inRbrKikanYmdFrom text,	-- 利払期間開始期日（分子）
 l_inRbrKikanYmdTo text,		-- 利払期間終了期日（分子）
 l_inShokaiRbrKbn text,		-- 初回利払区分
 l_inCalcMonth numeric,			-- 何ヶ月前(後）の日付から日数を求めるか
 l_inRbrNissuSpan text,		-- 利払日数計算間隔
 l_inRbrDd text,				-- 利払日付
 l_inKyujitsuKbn text,		-- 休日処理区分
 l_inAreaCd text,				-- 地域コード
 l_outCalcReplyYmd OUT text,		-- 応答日（期日ベース）
 l_outCalcSpanBunboFrom OUT text,	-- 端数分母計算期間FROM
 l_outCalcSpanBunboTo OUT text,		-- 端数分母計算期間TO
 l_outCalcSpanNissu OUT numeric 		-- 計算日数
 ) AS $body$
DECLARE

calcNissu			numeric(3);
kijunKjt			varchar(8);	-- 計算基準期日
calcMonth			numeric;
replyYmd			varchar(8);
lastDay				varchar(8);
calcYmd				varchar(8);
calcYmdFrom			varchar(8);
calcYmdTo			varchar(8);
checkDd				varchar(2);

BEGIN
-- 初期化
calcNissu := 0;
-- 初回利払区分＝'1'の場合
IF (l_inShokaiRbrKbn = '1') THEN
	calcMonth := -(l_inCalcMonth);
	kijunKjt := l_inRbrKikanYmdTo;
-- 初回利払区分≠'1'の場合
ELSE
	calcMonth := l_inCalcMonth;
	kijunKjt := l_inRbrKikanYmdFrom;
END IF;
-- 応答日を算出
replyYmd := pkDate.calcMonth(kijunKjt, calcMonth);
-- 計算基準期日と応答日の日(DD)が異なる場合
IF (TO_CHAR(to_date(kijunKjt,'YYYYMMDD'), 'DD') != TO_CHAR(to_date(replyYmd,'YYYYMMDD'), 'DD')) THEN
	-- 応答日の月末日を取得
	lastDay := TO_CHAR(oracle.LAST_DAY(to_date(replyYmd,'YYYYMMDD')), 'YYYYMMDD');
	IF (l_inRbrDd = '99') THEN
		calcYmd := lastDay;
	ELSE
		calcYmd := TO_CHAR(to_date(replyYmd,'YYYYMMDD'), 'YYYYMM') || trim(both TO_CHAR((l_inRbrDd)::numeric , '00'));
		-- 月末日を超えている場合は、月末日を設定
		IF (calcYmd > lastDay) THEN
			calcYmd := lastDay;
		END IF;
	END IF;
ELSE
	calcYmd := replyYmd;
END IF;
-- 初回利払区分＝'1'の場合
IF (l_inShokaiRbrKbn = '1') THEN
	calcYmdFrom := calcYmd;
	calcYmdTo := kijunKjt;
-- 初回利払区分≠'1'の場合
ELSE
	calcYmdFrom := kijunKjt;
	calcYmdTo := calcYmd;
END IF;
-- 利払日数計算間隔が「2：利払日間隔」の場合、営業日補正を行う
IF (l_inRbrNissuSpan = '2') THEN
	calcYmdFrom := pkDate.calcDateKyujitsuKbn(calcYmdFrom, 0, l_inKyujitsuKbn, l_inAreaCd);
	calcYmdTo := pkDate.calcDateKyujitsuKbn(calcYmdTo, 0, l_inKyujitsuKbn, l_inAreaCd);
END IF;
calcNissu := to_date(calcYmdTo,'YYYYMMDD') - to_date(calcYmdFrom,'YYYYMMDD');
--"4"(半ヵ年実日数)用　（期日ベース：利払日間隔でも利払期日から応答日を求めて営業日補正するため）
l_outCalcReplyYmd := calcYmd;			-- 応答日を返す（ロングの場合用）
--"3"(閏年対応365日)　利払日間隔ならば営業日ベースが端数の起点となる。
l_outCalcSpanBunboFrom := calcYmdFrom;	-- 端数分母FROM（デバッグ情報）
l_outCalcSpanBunboTo := calcYmdTo;		-- 端数分母TO（デバッグ情報）
--１回分の分母日数
l_outCalcSpanNissu := calcNissu;		-- 期間日数を返す
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfcalckichutsukarishikngk_sfkikananbunbo ( l_inRbrKikanYmdFrom text, l_inRbrKikanYmdTo text, l_inShokaiRbrKbn text, l_inCalcMonth numeric, l_inRbrNissuSpan text, l_inRbrDd text, l_inKyujitsuKbn text, l_inAreaCd text, l_outCalcReplyYmd OUT text, l_outCalcSpanBunboFrom OUT text, l_outCalcSpanBunboTo OUT text, l_outCalcSpanNissu OUT numeric  ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfcalckichutsukarishikngk_sfoncetsukarishikngk ( l_inRiritsu numeric,		--利率
 l_inNenrbrCnt text,	--利払回数
 l_inRbrKawaseRate numeric, 	--利払為替レート
 l_inTokureiShasaiFlg text, -- 特例社債フラグ
 CTL_VALUE text, -- 処理制御値
 l_inRknRoundProcess text, -- 利金計算単位未満端数処理
 l_inKakushasaiKngk numeric -- 各社債の金額
 ) RETURNS numeric AS $body$
DECLARE

wk_onceTsukarishiKngk		numeric;
wk_onceTsukarishiKngkCalc	decimal(14,13);
wk_nenrbrCnt				numeric(2);

BEGIN
-- 初期化
wk_onceTsukarishiKngkCalc := 0;
wk_nenrbrCnt := (l_inNenrbrCnt )::numeric;
IF (l_inTokureiShasaiFlg = 'Y' AND CTL_VALUE = '1') THEN
	-- 新計算方式で計算 端数計算は切上
	IF (l_inRknRoundProcess = '1') THEN
		wk_onceTsukarishiKngkCalc := TRUNC(TRUNC(l_inKakushasaiKngk * l_inRiritsu / 100 * 1 / wk_nenrbrCnt / l_inRbrKawaseRate) / l_inKakushasaiKngk::numeric, 13);
	ELSIF (l_inRknRoundProcess = '2') THEN
		wk_onceTsukarishiKngkCalc := TRUNC(ROUND(l_inKakushasaiKngk * l_inRiritsu / 100 * 1 / wk_nenrbrCnt / l_inRbrKawaseRate) / l_inKakushasaiKngk::numeric, 13);
	ELSIF (l_inRknRoundProcess = '3') THEN
		wk_onceTsukarishiKngkCalc := TRUNC(TRUNC((l_inKakushasaiKngk * l_inRiritsu / 100 * 1 / wk_nenrbrCnt / l_inRbrKawaseRate) + .9) / l_inKakushasaiKngk, 13);
	END IF;
ELSE
	--１回の通貨あたりの利子額の計算 
	wk_onceTsukarishiKngk := l_inRiritsu / 100 * 1 / wk_nenrbrCnt / l_inRbrKawaseRate;
	--小数第14位以下の端数計算 
	wk_onceTsukarishiKngkCalc := sfCalcKichuTsukarishiKngk_sfTsukarishiKngkDecimalCalc(l_inRknRoundProcess, wk_onceTsukarishiKngk);
END IF;
RETURN wk_onceTsukarishiKngkCalc;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfcalckichutsukarishikngk_sfoncetsukarishikngk ( l_inRiritsu numeric, l_inNenrbrCnt text, l_inRbrKawaseRate numeric  ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfcalckichutsukarishikngk_sftsukarishikngkdecimalcalc ( l_inRknRoundProcess text,	-- 利金計算単位未満端数処理区分 
 l_inTaishoTsukarishiKngk numeric 	-- 対象１通貨あたりの利子額 
 ) RETURNS numeric AS $body$
DECLARE

wk_tsukarishiKngkDecimalCalc decimal(14,13);

BEGIN
-- 初期化
wk_tsukarishiKngkDecimalCalc := 0;
-- 利金計算単位端数処理＝"1"（切捨て）の場合
IF (l_inRknRoundProcess = '1') THEN
	wk_tsukarishiKngkDecimalCalc := TRUNC(l_inTaishoTsukarishiKngk::numeric, 13);
-- 利金計算単位端数処理＝"2"（四捨五入）の場合
ELSIF (l_inRknRoundProcess = '2') THEN
	wk_tsukarishiKngkDecimalCalc := round((l_inTaishoTsukarishiKngk)::numeric,13);
-- 利金計算単位端数処理＝"3"（切上げ）の場合
ELSIF (l_inRknRoundProcess = '3') THEN
	wk_tsukarishiKngkDecimalCalc := TRUNC(l_inTaishoTsukarishiKngk + .00000000000009::numeric, 13);
END IF;
RETURN wk_tsukarishiKngkDecimalCalc;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfcalckichutsukarishikngk_sftsukarishikngkdecimalcalc ( l_inRknRoundProcess text, l_inTaishoTsukarishiKngk numeric  ) FROM PUBLIC;