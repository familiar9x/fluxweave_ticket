




CREATE OR REPLACE FUNCTION sfipfcalhakkokawarikin ( l_inItakuKaishaCd NYUKIN_YOTEI.ITAKU_KAISHA_CD%TYPE, l_inMgrCd NYUKIN_YOTEI.MGR_CD%TYPE , l_inShasaiTotal MGR_KIHON.SHASAI_TOTAL%TYPE , l_inHakkoKagaku MGR_KIHON.HAKKO_KAGAKU%TYPE , l_outSashihikiHrkmKngk OUT numeric , l_outSzeiSum OUT numeric , l_outHikiukeKngkSum OUT numeric , l_outMeisaiCnt OUT numeric , l_outKousinDt OUT text , OUT extra_param integer) RETURNS record AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2004
-- * 会社名:JIP
-- * 
-- * 発行代り金入金（指示・確認時）の一覧リストに表示する
-- *一部項目（差引後払込金額,内消費税合計,引受金合計,明細件数）と更新日時（入金予定）を取得。
-- *IF-00377 2005-11-07  218行目	l_outKousinDt := ' '; の追加
-- * @author K.Toma
-- * @version $Revision: 1.13 $
-- *
-- * @param l_inItakuKaishaCd           IN NYUKIN_YOTEI.ITAKU_KAISHA_CD%TYPE  --委託会社コード
-- * @param l_inMgrCd                  IN NYUKIN_YOTEI.MGR_CD%TYPE           --銘柄コード
-- * @param l_inShasaiTotal            IN MGR_KIHON.SHASAI_TOTAL%TYPE        --社債の総額
-- * @param l_inHakkoKagaku            IN MGR_KIHON.HAKKO_KAGAKU%TYPE        --発行価額
-- * @param l_outSashihikiHrkmKngk     OUT NUMERIC   --差引後払込金額
-- * @param l_outSzeiSum               OUT NUMERIC   --内消費税合計
-- * @param l_outHikiukeKngkSum        OUT NUMERIC   --引受金合計
-- * @param l_outMeisaiCnt             OUT NUMERIC   --明細件数
-- * @param l_outKousinDt              OUT VARCHAR  --更新日時 入金予定
-- * @return リターンコード
-- *
--
--
--****************************************************************************
--/* ログ　:
--/* 　　　日付   開発者名        目的
--/* -------------------------------------------------------------------
--/*　2005/07/028  K.Toma            新規作成
--/*　
--/*
--***************************************************************************
--
--==============================================================================
--                  デバッグ機能                                                 
--==============================================================================
    DEBUG   numeric(1)   := 0;
--==============================================================================
--                  定数定義                                                    
--==============================================================================
    RTN_OK              CONSTANT integer    := 0;                       -- 正常
    RTN_NG              CONSTANT integer    := 1;                       -- 予期したエラー
    RTN_NODATA          CONSTANT integer    := 40;                      -- データなし
    RTN_FATAL           CONSTANT integer    := 99;                      -- 予期せぬエラー
    FMT_YMDHMS CONSTANT text := 'YYYYMMDDHH24MISSUS';
    FMT_YMDHMS2 CONSTANT text := 'YYYY-MM-DD HH24:MI:SS.US';
--==============================================================================
--                  変数定義                                                    
--==============================================================================
        result				integer;				-- ＳＰのリターンコード
	sumTesuKngkC1                   numeric;					-- 全体手数料金額（税抜） 
	sumTesuSzeiC1                   numeric;					-- 全体消費税額 
	sumHoseiAllTesuKngkC1           numeric;					-- 補正額_全体手数料額（税抜）
	sumHoseiAllTesuSzeiC1           numeric;					-- 補正額_全体消費税額 
	dataSakuseiKbnC1                char(1);				-- データ作成区分
	shoriKbnC1                      char(1);				-- 処理区分
	sashihikiTesuC1                 numeric;					-- 差引手数料
	sashihikiSzeiC1                 numeric;					-- 内消費税合計
	hkukKngk1C2_1					numeric;					-- 引受金額合計
	countC2_1						numeric;					-- 明細件数1 
	maxKousinDtC2_1					char(26);				-- MAX入金更新1
	num_maxKousinDtC2_1				char(22);				-- MAX入金更新1
	hkukKngk1C2_2		       		numeric;					--引渡金額合計 
	countC2_2						numeric;					--明細件数2  
	maxKousinDtC2_2					char(26);				--MAX入金更新2
	num_maxKousinDtC2_2				char(22);				--MAX入金更新2
	wkTesuKngkC1					numeric;					-- 作業用全体手数料金額（税抜） 
	wkTesuSzeiC1					numeric;					-- 作業用全体消費税額 
	wkHoseiAllTesuKngkC1			numeric;					-- 作業用補正額_全体手数料額（税抜）
	wkHoseiAllTesuSzeiC1			numeric;					-- 作業用補正額_全体消費税額 
	wkDataSakuseiKbnC1				char(1);				-- 作業用データ作成区分
	wkShoriKbnC1					char(1);				-- 作業用処理区分
  	c_tesuCur CURSOR FOR
		SELECT
			ALL_TESU_KNGK , 
			ALL_TESU_SZEI ,
			HOSEI_ALL_TESU_KNGK ,
  			HOSEI_ALL_TESU_SZEI ,
  			DATA_SAKUSEI_KBN , 
  			SHORI_KBN
		FROM
  			TESURYO 
		WHERE
  			ITAKU_KAISHA_CD    = l_inItakuKaishaCd   AND
			MGR_CD             = l_inMgrCd          AND
  			TESU_SASHIHIKI_KBN ='1';	
--******************************************************************************
--                  メイン処理                                                  
--******************************************************************************
BEGIN
	result := RTN_NODATA;
	wkTesuKngkC1 := 0;
  	wkTesuSzeiC1 := 0;
  	-- 全体手数料（税抜） + 全体消費税　と補正の計算 
  	FOR r_tesuCur IN c_tesuCur LOOP
  		wkTesuKngkC1 			:= wkTesuKngkC1 + r_tesuCur.ALL_TESU_KNGK;
  		wkTesuSzeiC1 			:= wkTesuSzeiC1 + r_tesuCur.ALL_TESU_SZEI;
  		wkHoseiAllTesuKngkC1 	:= r_tesuCur.HOSEI_ALL_TESU_KNGK;
  		wkHoseiAllTesuSzeiC1 	:= r_tesuCur.HOSEI_ALL_TESU_SZEI;
  		wkDataSakuseiKbnC1 		:= r_tesuCur.DATA_SAKUSEI_KBN;
  		wkShoriKbnC1 			:= r_tesuCur.SHORI_KBN;
  		IF  wkDataSakuseiKbnC1 = '2' AND wkShoriKbnC1 = '1' THEN
  			wkTesuKngkC1 := wkTesuKngkC1 +  wkHoseiAllTesuKngkC1;
  			wkTesuSzeiC1 := wkTesuSzeiC1 + 	wkHoseiAllTesuSzeiC1;
 		END IF;
 	END LOOP;
 	sashihikiTesuC1 := wkTesuKngkC1;
 	sashihikiSzeiC1 := wkTesuSzeiC1;
 	-- 差引後払込金額 = 社債の総額 x 発行価額 / 100 - (差引手数料+内消費税合計)         
    l_outSashihikiHrkmKngk := ( l_inShasaiTotal * l_inHakkoKagaku / 100 ) - (sashihikiTesuC1 + sashihikiSzeiC1);
  	-- 内消費税合計の設定 
  	l_outSzeiSum := sashihikiSzeiC1;
	-- 差引後張り込み金額が14桁以上になる 
	IF length(pkcharacter.numeric_to_char(trunc(l_outSashihikiHrkmKngk))) >= 13 THEN
	  result := RTN_NODATA;
	  extra_param := result;
	  RETURN;
	END IF;
	-- 更新日付を返り値用と内部比較用で二つ取得する 
	SELECT
  		SUM(B03.HKUK_KNGK),
  		COUNT(*),
  		TO_CHAR(MAX(B03.KOUSIN_DT) ,  FMT_YMDHMS) ,
  		TO_CHAR(MAX(B03.KOUSIN_DT) ,  FMT_YMDHMS2) 
	INTO STRICT
  		hkukKngk1C2_1 ,	
  		countC2_1 , 
  		num_maxKousinDtC2_1  ,
  		maxKousinDtC2_1  
	FROM
  		NYUKIN_YOTEI B03
	WHERE
  		B03.DVP_KBN         = '0' AND
  		B03.FURI_STS_KBN    = '1' AND
  		B03.ITAKU_KAISHA_CD = l_inItakuKaishaCd   AND
  		B03.MGR_CD          = l_inMgrCd           AND
  		B03.SHORI_KBN       = '1';
	-- 更新日付を返り値用と内部比較用で二つ取得する 
	SELECT
  		SUM(B03.HKUK_KNGK),
  		COUNT(*),
		TO_CHAR(MAX(B03.KOUSIN_DT) ,  FMT_YMDHMS) ,
		TO_CHAR(MAX(B03.KOUSIN_DT) ,  FMT_YMDHMS2)
	INTO STRICT
  		hkukKngk1C2_2 ,	
  		countC2_2 , 
  		num_maxKousinDtC2_2 , 
  		maxKousinDtC2_2  
	FROM
  		NYUKIN_YOTEI B03,
  		TOYOSEND  FS11 
	WHERE
		B03.ITAKU_KAISHA_CD    = FS11.ITAKU_KAISHA_CD 	AND
  		B03.KESSAI_NO          = FS11.KESSAI_NO    		AND         
  		FS11.ITAKU_KAISHA_CD   = l_inItakuKaishaCd  	AND
  		B03.ITAKU_KAISHA_CD    = l_inItakuKaishaCd  	AND
  		B03.MGR_CD             = l_inMgrCd         		AND
  		FS11.NYUSHUKIN_JOUKYOU = '2';
	-- NULLの時は 0にする 
	IF coalesce(hkukKngk1C2_1::text, '') = '' THEN
		hkukKngk1C2_1 := 0;
	END IF;
	IF coalesce(hkukKngk1C2_2::text, '') = '' THEN
		hkukKngk1C2_2 := 0;
	END IF;
	-- 引受金合計算出 
	l_outHikiukeKngkSum := hkukKngk1C2_1 + hkukKngk1C2_2;
	-- 明細件数算出 
	l_outMeisaiCnt := countC2_1 +  countC2_2;
	IF ( countC2_1 > 0 AND countC2_2 > 0 ) THEN	
		result := RTN_OK;
		-- 更新日を比較し、新しいほうを最終タイムスタンプとする 
		IF (num_maxKousinDtC2_1)::numeric  >=(num_maxKousinDtC2_2 )::numeric  THEN 
		  l_outKousinDt := maxKousinDtC2_1;
		ELSE
		  l_outKousinDt := maxKousinDtC2_2;
		END IF;
	ELSIF ( countC2_1 > 0 AND countC2_2 = 0) THEN
		l_outKousinDt := maxKousinDtC2_1;	
		result := RTN_OK;
	ELSIF ( countC2_1 = 0 AND countC2_2 > 0) THEN
		l_outKousinDt := maxKousinDtC2_2;	
		result := RTN_OK;
	ELSIF ( countC2_1 = 0 AND countC2_2 = 0) THEN
		--result := RTN_NODATA; 
		l_outKousinDt := ' ';
		result := RTN_OK;
	END IF;
	extra_param := result;
	RETURN;
	exception
		WHEN no_data_found Then
			result := RTN_NODATA;
			extra_param := result;
			RETURN;
		WHEN others Then
			result := RTN_NG;
			extra_param := result;
			RETURN;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipfcalhakkokawarikin ( l_inItakuKaishaCd NYUKIN_YOTEI.ITAKU_KAISHA_CD%TYPE, l_inMgrCd NYUKIN_YOTEI.MGR_CD%TYPE , l_inShasaiTotal MGR_KIHON.SHASAI_TOTAL%TYPE , l_inHakkoKagaku MGR_KIHON.HAKKO_KAGAKU%TYPE , l_outSashihikiHrkmKngk OUT numeric , l_outSzeiSum OUT numeric , l_outHikiukeKngkSum OUT numeric , l_outMeisaiCnt OUT numeric , l_outKousinDt OUT text , OUT extra_param integer) FROM PUBLIC;