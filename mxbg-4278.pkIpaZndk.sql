CREATE SCHEMA IF NOT EXISTS pkipazndk;

drop function if exists pkipazndk.getjissitsuzndk_h;
drop function if exists pkipazndk.getjissitsuzndk_i;
drop function if exists pkipazndk.getkjnzndk(char, varchar, char, char, bigint);
drop function if exists pkipazndk.getkjnzndk(char, char, char, bigint);
drop function if exists pkipazndk.getfactor(char, char, char, bigint);
drop function if exists pkipazndk.getfactor(char, varchar, char, char);
drop function if exists pkipazndk.getjissitsuzndk_i(text, text, text, bigint, bigint, varchar);
drop function if exists pkipazndk.getfactor(char, char, char, numeric);
drop function if exists pkipazndk.getfactor(char, char, char, numeric, varchar, varchar, varchar);
drop function if exists pkipazndk.getfactor(char, char, char, numeric, varchar, numeric, varchar);
drop function if exists pkipazndk.getfactor(char, char, char, char, char, numeric, varchar);
drop function if exists pkipazndk.getfactor(char, char, char, char, char, char, varchar);
drop function if exists pkipazndk.getfactor(char, varchar, char, char);
drop function if exists pkipazndk.getjissitsuzndk_i(text, text, text, numeric, numeric, varchar);
drop function if exists pkipazndk.getTokureiKjndtKbn;
drop function if exists pkipazndk.calcmeimokuzndk;
drop function if exists pkipazndk.getshasaitotal;
drop function if exists pkipazndk.gettokureikjndtkbn;
drop function if exists pkipazndk.getikofactor;

CREATE OR REPLACE FUNCTION pkipazndk.getshasaitotal (l_inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE, l_inMgrCd MGR_SHOKIJ.MGR_CD%TYPE, l_inDate MGR_SHOKIJ.SHOKAN_YMD%TYPE, l_inKbn text DEFAULT '0', l_inFlg CHAR DEFAULT NULL) RETURNS varchar AS $body$
DECLARE

    /*==============================================================================*/

    /*          定数定義                          */

    /*==============================================================================*/

        SP_ID CONSTANT varchar(50) := 'pkIpaZndk.getKjnZndk.getShasaiTotal';
        --特例社債フラグ
        NOT_TOKUREI_SHASAI CONSTANT char(1) := 'N'; -- 特例社債でない
        GENTO_FURI_IDO CONSTANT char(2) := '01'; -- 現登債から振替債への異動
    /*==============================================================================*/

    /*          変数定義                          */

    /*==============================================================================*/

        l_outValue       varchar(100); -- 取得した値
        l_shokanMethodCd varchar(1); -- 償還方法
        l_tokurei_flg    varchar(1); -- 特例社債フラグ
        l_furiKngk       numeric; -- 振替債移行額
        l_factor         numeric; -- ファクター
BEGIN
        --特例社債フラグ
        SELECT MG1.SHOKAN_METHOD_CD, MG1.TOKUREI_SHASAI_FLG
          INTO STRICT l_shokanMethodCd, l_tokurei_flg
          FROM MGR_KIHON MG1
         WHERE MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
           AND MG1.MGR_CD = l_inMgrCd;
        IF l_tokurei_flg = NOT_TOKUREI_SHASAI THEN
            --特例社債でない場合、銘柄_基本より「社債の総額」を取得する
            SELECT MG1.SHASAI_TOTAL::varchar
              INTO STRICT l_outValue
              FROM MGR_KIHON MG1
             WHERE MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
               AND MG1.MGR_CD = l_inMgrCd;
        ELSE
            --特例社債の場合、減債履歴より「現登債から振替債の異動」かつ
            --承認済のレコードの減債金額合計を取得する
            BEGIN
				SELECT SUM(Z01.GENSAI_KNGK), MAX(Z01.FACTOR)
				INTO STRICT l_furiKngk, l_factor
				FROM GENSAI_RIREKI Z01
				WHERE Z01.ITAKU_KAISHA_CD = l_initakukaishacd
				AND Z01.MGR_CD = l_inmgrcd
				AND Z01.SHOKAN_YMD <= l_indate -- 基準日を含む
				AND Z01.SHOKAN_KBN = GENTO_FURI_IDO
				AND Z01.SHORI_KBN = '1'
				GROUP BY Z01.ITAKU_KAISHA_CD, Z01.MGR_CD;
            EXCEPTION
                WHEN OTHERS THEN
                    -- 振替債移行以前の場合等、減債金額を取得できない場合は 0円をセット
                    l_furiKngk := 0;
                    l_factor   := 1; -- 0除算回避のため
            END;
            -- 満期一括の場合は、ファクターにゼロが設定されているため、１に置き換える
            if (l_shokanMethodCd = '1' AND l_factor = 0) then
                l_factor := 1;
            end if;
            -- 実質
            IF l_inKbn = '1' THEN
                l_outValue := l_furiKngk::varchar;
            -- 名目（デフォルト）
            ELSE
                l_outValue := (l_furiKngk / l_factor)::varchar;
            END IF;
        END IF;
        RETURN l_outValue;
    /*====================================================================*
                   異常終了 出口
    *====================================================================*/
    EXCEPTION
        WHEN OTHERS THEN
            call pkLog.fatal('ECM321', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
            RAISE;
    END;
$body$
LANGUAGE PLPGSQL
 ;

/**
 * 著作権: Copyright (c) 2005
 * 会社名: JIP
 *
 * @version $Id: pkIpaZndk.sql,v 1.36 2011/07/04 08:55:18 kurokawa Exp $
 */
	/**
	 * 特例社債入力時 入力基準日区分取得<br>
	 *
	 * @param l_inItakuKaishaCd		委託会社コード
	 * @param l_inMgrCd				銘柄コード
	 * @param l_inDate				基準日
	 * @param l_outFuriYmd			振替移行日
	 * @return l_return				基準日フラグ
	 *                              1:振替移行経験なし
	 *                              2:振替債残高あり
	 *                              3:満期償還済
	*/
CREATE OR REPLACE FUNCTION pkipazndk.gettokureikjndtkbn (l_inItakuKaishaCd text, l_inMgrCd text, l_inDate text, l_outFuriYmd OUT text, OUT extra_param int) RETURNS record AS $body$
DECLARE

		-- カーソル
		
		curRec REFCURSOR;

		/* ==変数定義=================================*/

		l_bufSql	varchar(5000) := NULL;
		l_wDate		varchar(8) := NULL;		-- 日付項目格納用
		l_dYmd		varchar(8) := NULL;		-- デフォルト日格納用
		/* ==　処理　=================================*/

	
BEGIN
		l_outFuriYmd := null;

		SELECT pkDate.calcDateKyujitsuKbn(VMG1.FULLSHOKAN_KJT, 0, VMG1.KYUJITSU_KBN, VMG1.AREACD),
			   DEFAULT_YMD
		  INTO STRICT l_wDate,
			   l_dYmd
		  FROM MGR_KIHON_VIEW VMG1
		 WHERE VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		   AND VMG1.MGR_CD = l_inMgrCd;

		IF (l_wDate IS NOT NULL) THEN
			-- 基準日＞満期償還日 かつ デフォルト未設定
			IF l_inDate > l_wDate AND nullif(trim(both l_dYmd),'') IS NULL THEN
				extra_param := 3;
				RETURN;
			END IF;
		END IF;

		SELECT trim(both MIN(Z01.SHOKAN_YMD))
		  INTO STRICT l_wDate
		  FROM GENSAI_RIREKI Z01
		 WHERE Z01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		   AND Z01.MGR_CD = l_inMgrCd
		   AND Z01.SHOKAN_KBN = '01'
		   AND Z01.SHORI_KBN = '1'
		   AND Z01.YOJITSU_FLG = '1';

		IF l_wDate IS NOT NULL THEN
			IF l_inDate >= l_wDate THEN
				l_outFuriYmd := l_wDate;
				extra_param := 2;
				RETURN;
			ELSE
				extra_param := 1;
				RETURN;
			END IF;
		ELSE
			extra_param := 1;
			RETURN;
		END IF;

	EXCEPTION
		WHEN OTHERS THEN
			extra_param := pkConstant.FATAL();
			RETURN;
	END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;

CREATE OR REPLACE FUNCTION pkipazndk.getfactor (
    l_initakukaishacd TEXT,
    l_inmgrcd TEXT,
    l_indate TEXT,
    l_jissitsu_zndk TEXT,
    l_tokurei_flg varchar(1),
    l_tokurei_kjndt_kbn numeric,
    TOKUREI_SHASAI varchar(1)
    ) RETURNS numeric AS $body$
BEGIN
    RETURN pkipazndk.getfactor(
        l_initakukaishacd,
        l_inmgrcd,
        l_indate,
        l_jissitsu_zndk::numeric,
        l_tokurei_flg,
        l_tokurei_kjndt_kbn,
        TOKUREI_SHASAI
    );
END;
$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;

CREATE OR REPLACE FUNCTION pkipazndk.getfactor (
    l_initakukaishacd TEXT, 
    l_inmgrcd TEXT, 
    l_indate TEXT, 
    l_jissitsu_zndk TEXT, 
    l_tokurei_flg varchar(1), 
    l_tokurei_kjndt_kbn TEXT, 
    TOKUREI_SHASAI varchar(1)) RETURNS numeric AS $body$
BEGIN
    RETURN pkipazndk.getfactor(
        l_initakukaishacd,
        l_inmgrcd,
        l_indate,
        l_jissitsu_zndk::numeric,
        l_tokurei_flg,
        l_tokurei_kjndt_kbn::numeric,
        TOKUREI_SHASAI
    );
END;
$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;

CREATE OR REPLACE FUNCTION pkipazndk.getfactor (
    l_initakukaishacd CHAR,
    l_inmgrcd CHAR,
    l_indate CHAR,
    l_jissitsu_zndk numeric,
    l_tokurei_flg varchar(1),
    l_tokurei_kjndt_kbn numeric,
    TOKUREI_SHASAI varchar(1)
    ) RETURNS numeric AS $body$
DECLARE


            /* 変数定義 */

            --「D 基準日時点でのファクター」計算用
            l_kakushasai_kngk numeric := 0; --各社債の金額
            l_gensai_kngk     numeric := 0; --振替単位元本減債金額
            -- 特例社債時使用
            l_gensai_kngk_sum numeric := 0; --振替債移行時点減債金額累計
            l_factor          numeric := 0; --振替債移行時点ファクター
            l_return numeric := 0;
            l_shokan_method char(1); --償還方法
            l_min_frk_iko_date char(8); --振替債移行日

            /* カーソル定義 */

            -- 各社債の金額、振替単位元本減債金額取得
            curRecZndk CURSOR FOR
                SELECT MG1.KAKUSHASAI_KNGK, coalesce(MG3SUM.FUNIT_GENSAI_KNGK, 0) AS F_KNGK
                  FROM mgr_kihon mg1
LEFT OUTER JOIN (SELECT MG3.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD,
                               MG3.MGR_CD AS MGR_CD,
                               SUM(MG3.FUNIT_GENSAI_KNGK) AS FUNIT_GENSAI_KNGK
                          FROM MGR_SHOKIJ MG3
                         WHERE MG3.ITAKU_KAISHA_CD = l_initakukaishacd
                           AND MG3.MGR_CD = l_inmgrcd
                           AND MG3.SHOKAN_YMD <= l_indate
                         GROUP BY MG3.ITAKU_KAISHA_CD, MG3.MGR_CD) mg3sum ON (MG1.ITAKU_KAISHA_CD = MG3SUM.ITAKU_KAISHA_CD AND MG1.MGR_CD = MG3SUM.MGR_CD)
WHERE MG1.ITAKU_KAISHA_CD = l_initakukaishacd AND MG1.MGR_CD = l_inmgrcd;

            -- 振替債移行時点ファクター取得
            curRecFactor CURSOR FOR
                SELECT Z01.FACTOR
                  FROM GENSAI_RIREKI Z01
                 WHERE Z01.ITAKU_KAISHA_CD = l_initakukaishacd
                   AND Z01.MGR_CD = l_inmgrcd
                   AND Z01.SHOKAN_KBN = '01'
                   AND Z01.SHOKAN_YMD = l_min_frk_iko_date
                   AND Z01.SHORI_KBN = '1'
                   AND Z01.YOJITSU_FLG = '1';

        /* 処理開始 */

BEGIN

            -- Get SHOKAN_METHOD from MGR_KIHON
            BEGIN
                SELECT MG1.SHOKAN_METHOD_CD INTO l_shokan_method
                FROM MGR_KIHON MG1
                WHERE MG1.ITAKU_KAISHA_CD = l_initakukaishacd
                  AND MG1.MGR_CD = l_inmgrcd;
            EXCEPTION
                WHEN OTHERS THEN
                    l_shokan_method := NULL;
            END;
            
            -- Get MIN furikae date if needed
            IF l_tokurei_flg = TOKUREI_SHASAI AND l_tokurei_kjndt_kbn = 2 THEN
                BEGIN
                    SELECT MIN(Z01.SHOKAN_YMD) INTO l_min_frk_iko_date
                    FROM GENSAI_RIREKI Z01
                    WHERE Z01.ITAKU_KAISHA_CD = l_initakukaishacd
                      AND Z01.MGR_CD = l_inmgrcd
                      AND Z01.SHOKAN_KBN = '01'
                      AND Z01.SHORI_KBN = '1'
                      AND Z01.YOJITSU_FLG = '1';
                EXCEPTION
                    WHEN OTHERS THEN
                        l_min_frk_iko_date := NULL;
                END;
            END IF;

            -- 各社債の金額、振替単位元本減債金額取得
            FOR recZndk IN curRecZndk LOOP
                l_kakushasai_kngk := recZndk.KAKUSHASAI_KNGK;
                l_gensai_kngk     := recZndk.F_KNGK;
            END LOOP;

            -- 特例社債銘柄入力時処理
            IF l_tokurei_flg = TOKUREI_SHASAI THEN
                IF l_tokurei_kjndt_kbn IN (1, 3) THEN
                    l_gensai_kngk := l_kakushasai_kngk;
                ELSE
                    -- MG1.償還方法 = 満期一括 OR 永久債
                    IF l_shokan_method <> '2' THEN
                        l_gensai_kngk := 0;
                        -- MG1.償還方法 = 定時償還
                    ELSE
                        -- 振替債移行時点ファクター取得
                        FOR recFactor IN curRecFactor LOOP
                            l_factor := recFactor.FACTOR;
                        END LOOP;
                        l_gensai_kngk_sum := l_kakushasai_kngk - (l_kakushasai_kngk * l_factor);
                    END IF;
                END IF;
            END IF;

            --0除算回避(念のため)
            IF l_kakushasai_kngk <> 0 THEN
                l_return := (l_kakushasai_kngk - (l_gensai_kngk + l_gensai_kngk_sum)) / l_kakushasai_kngk;
            ELSE
                l_return := 0;
            END IF;

            -- 振替債分の残高が0になった場合、強制的にファクター0を返す。
            IF l_jissitsu_zndk = 0 THEN
                l_return := 0;
            END IF;

            RETURN l_return;

        EXCEPTION
            WHEN OTHERS THEN
                --      RAISE;
                RETURN pkConstant.FATAL();
        END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
 ;
-- REVOKE ALL ON FUNCTION pkipazndk.getfactor (l_initakukaishacd CHAR, l_inmgrcd CHAR, l_indate CHAR, l_jissitsu_zndk bigint) FROM PUBLIC;

       /**
        * H_実質残高( = A_振替債の総額 - B_振替債分の減債金額累計)取得<br>
        *
        * @param  tokureiFlg          特例社債フラグ
        * @param  tokureiKjndtKbn     特例社債入力基準日区分
        * @param  furikaeSogaku       A 振替債移行分の累計金額(=振替債の総額)
        * @param  furikaeGensaiRuikei B 振替債分の減債金額累計
        * @return NUMBER              H_実質残高
        */
CREATE OR REPLACE FUNCTION pkipazndk.getjissitsuzndk_h (
    tokureiFlg text,
    tokureiKjndtKbn numeric,
    furikaeSogaku numeric,
    furikaeGensaiRuikei numeric,
    tokurei_shasai text
) RETURNS numeric AS $body$
DECLARE

            result numeric := 0;

BEGIN
            IF tokureiFlg = TOKUREI_SHASAI AND tokureiKjndtKbn = 1 THEN
                result := 0;
            ELSE
                result := furikaeSogaku - furikaeGensaiRuikei;
            END IF;
            return result;
        END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;
-- REVOKE ALL ON FUNCTION pkipazndk.getjissitsuzndk_h (tokureiFlg text, tokureiKjndtKbn text, furikaeSogaku bigint, furikaeGensaiRuikei bigint) FROM PUBLIC;

       /**
        * I_実質残高(現登債分)取得<br>
        *
        * @param  itakukaishaCd      委託会社コード
        * @param  mgrCd              銘柄コード
        * @param  kijunYmd           基準日
        * @param  furikaeSogaku      A 振替債移行分の累計金額(=振替債の総額)
        * @param  gentouGensaiRuikei C 現登債分の減債金額累計
        * @return NUMBER             I_実質残高(現登債分)
        */
CREATE OR REPLACE FUNCTION pkipazndk.getjissitsuzndk_i (
    itakukaishaCd text,
    mgrCd text,
    kijunYmd text,
    furikaeSogaku numeric,
    gentouGensaiRuikei numeric,
    GENTO_ZNDK varchar(2)
) RETURNS numeric AS $body$
DECLARE
    recGentou REFCURSOR;

    jissitsuZndkGentou numeric := 0;
    /* カーソル定義 */

    -- 移行時の現登債残高取得
    curRecGentou CURSOR FOR
        SELECT Z01.GENSAI_KNGK
            FROM GENSAI_RIREKI Z01
            WHERE Z01.ITAKU_KAISHA_CD = itakukaishaCd
            AND Z01.MGR_CD = mgrCd
            AND Z01.SHOKAN_YMD <= kijunYmd
            AND Z01.SHOKAN_KBN = GENTO_ZNDK  -- 償還区分=「移行時の現登債残高」であるレコードのみ取得
            AND Z01.SHORI_KBN = '1'; -- 処理区分=承認済
BEGIN
            -- 移行時の現登債残高取得
            FOR recGentou IN curRecGentou LOOP
                jissitsuZndkGentou := recGentou.GENSAI_KNGK;
            END LOOP;

            jissitsuZndkGentou := jissitsuZndkGentou - (furikaeSogaku + gentouGensaiRuikei);
            IF jissitsuZndkGentou < 0 THEN
                -- 現登債分の実質残高がマイナスの場合は0をセット
                jissitsuZndkGentou := 0;
            END IF;
            return jissitsuZndkGentou;
        END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;

   /**
    *
    * @author 磯田　浩靖
    *
    * ファクターの妥当性チェック<br>
    * ファクターが正しい値で計算されているかチェックする。
    *
    * @param    l_inFactor          ファクター
    * @return   pkConstant.SUCCESS()  正常
    *           pkConstant.ERROR()    異常
    */
CREATE OR REPLACE FUNCTION pkipazndk.validatefactor (l_inFactor numeric) RETURNS integer AS $body$
BEGIN
        /* ファクターが10桁以内で割り切れているかどうかチェック */

        IF sfCmPrecisionCheck(l_inFactor::text,1,10) = 0 THEN
            RETURN pkConstant.SUCCESS();
        ELSE
            RETURN pkConstant.ERROR();
        END IF;
    EXCEPTION
	    WHEN OTHERS THEN
    		CALL pkLog.fatal(NULL, NULL, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
    		RETURN pkConstant.FATAL();
	END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;


   /**
    *
    * @author 藤本 和哉
    *
    * 名目残高計算<br>
    * パラメータで指定した委託会社、銘柄コード、基準日、償還区分、実数に
    * 対応した名目残高を取得する。（同一期日考慮）
    * 【注：名目残高は「振替債分の名目残高」を返す】
    *
    * @param l_initakukaishacd    委託会社コード
    * @param l_inmgrcd            銘柄コード
    * @param l_indate             基準日
    * @param l_inShokanKbn        償還区分
    * @param l_inrealvalue        実数
    * @param l_inFlg              今回の回次を含むかどうかを判別するフラグ（含む場合'1'）
    * @return  l_outValue          取得した基準日残高
    */
CREATE OR REPLACE FUNCTION pkipazndk.calcmeimokuzndk (l_inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE, l_inMgrCd MGR_SHOKIJ.MGR_CD%TYPE, l_inDate MGR_SHOKIJ.SHOKAN_YMD%TYPE, l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE, l_inFlg CHAR) RETURNS varchar AS $body$
DECLARE

    /*==============================================================================*/

    /*          定数定義                          */

    /*==============================================================================*/

        SP_ID                 CONSTANT varchar(50) := 'pkIpaZndk.getKjnZndk().calcMeimokuZndk';

        CODE_SHOKAN_KBN       CONSTANT varchar(3) := '714';
        KAIIRE_SHOKYAKU       CONSTANT varchar(2) := '30'; -- 買入消却
        PUT_OPTION            CONSTANT varchar(2) := '50'; -- プットオプション
        YOYAKU_KOUSHI         CONSTANT varchar(2) := '60'; -- 新株予約権行使
        GENTO_FURI_IDO        CONSTANT varchar(2) := '01'; -- 現登債から振替債への異動
        GENTO_ZNDK            CONSTANT varchar(2) := '99'; -- 現登債の残高
        --特例社債フラグ
        NOT_TOKUREI_SHASAI    CONSTANT varchar(1) := 'N'; -- 特例社債でない
        TOKUREI_SHASAI        CONSTANT varchar(1) := 'Y'; -- 特例社債である
    /*==============================================================================*/

    /*          変数定義                          */

    /*==============================================================================*/

        l_outValue        varchar(100); -- 取得した値
        l_gensaiTotal     numeric         := 0;
        l_shasaiTotal     varchar(16); -- 社債の総額
        l_factor          numeric         := 0;
        l_tokureiFlg           varchar(1); --特例社債フラグ
        l_shokanMethod         varchar(1); --償還方法コード
        l_jissitsuZndk         numeric := 0; -- 実質残高
        l_bufDate              varchar(8); --  基準残高集計用
        l_bufShokankbn         varchar(2); --　償還区分
        l_bufGensaiKngk        numeric := 0; --  基準残高集計用
        l_bufGensaiTotal       numeric := 0; --  基準残高集計用
        l_bufFactor            numeric := 0; --  減債金額合計計算用ファクター
        l_tokureiKjndtKbn      int := 0; -- 特例社債入力基準日区分
        l_furiYmd              varchar(8);		-- 振替移行日

        temp_rec            record;
    /*==============================================================================*/

    /*             カーソル定義                                                     */

    /*==============================================================================*/

    /*
     * 対象の償還日以前の償還回次データを取得する。
     * 同一償還日に複数償還区分がある場合は、コードマスタのソート順が自分より小さいものまでを取得する。(今回の回次を含まない場合)
     * 同一償還日に複数償還区分がある場合は、自分を含めたコードマスタのソート順が自分より小さいものまでを取得する。(今回の回次を含む場合)
     */
     c_getMgrShokij CURSOR(
            l_inItakuKaishaCd  MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE,
            l_inMgrCd  MGR_SHOKIJ.MGR_CD%TYPE,
            l_inShokanKjt  MGR_SHOKIJ.SHOKAN_KJT%TYPE
        ) FOR
        SELECT
            coalesce(SUM(VMG3.MUNIT_GENSAI_KNGK),0) AS MUNIT_GENSAI_KNGK_SUM
        FROM
         /* 対象の償還日より前の回次の振替単位元本減債金額を取得
          *（同じ振替単位元本減債金額を取得するロジックが
          * 数箇所にあるので、次回にはまとめて外だししましょう）
          */
         (SELECT coalesce(MUNIT_GENSAI_KNGK / pkIpaZndk.GETKJNZNDK(MG3.ITAKU_KAISHA_CD,MG3.MGR_CD,MG3.SHOKAN_YMD,MG3.SHOKAN_KBN,5)::numeric,0) AS MUNIT_GENSAI_KNGK
          FROM   MGR_SHOKIJ MG3,
				 SCODE      SC04
          WHERE  MG3.ITAKU_KAISHA_CD =  l_inItakuKaishaCd
            AND MG3.MGR_CD     		 =  l_inMgrCd
            AND MG3.SHOKAN_YMD 		 <  l_inDate
            AND MG3.SHOKAN_KBN 		 IN (KAIIRE_SHOKYAKU,
                                         PUT_OPTION,
                                         YOYAKU_KOUSHI)
            AND SC04.CODE_SHUBETSU   =  CODE_SHOKAN_KBN
            AND MG3.SHOKAN_KBN 		 =  SC04.CODE_VALUE

UNION ALL

         /*
          * 対象の償還日と同じ日の回次の振替単位元本減債金額を取得
          * 対象の回次のコードソート順より小さいもののみ取得する。
          *（同じ振替単位元本減債金額を取得するロジックが
          * 数箇所にあるので、次回にはまとめて外だししましょう）
          */
          SELECT coalesce(MUNIT_GENSAI_KNGK / pkIpaZndk.GETKJNZNDK(MG3.ITAKU_KAISHA_CD,MG3.MGR_CD,MG3.SHOKAN_YMD,MG3.SHOKAN_KBN,5)::numeric,0) AS MUNIT_GENSAI_KNGK
          FROM   MGR_SHOKIJ MG3,
				 SCODE      SC04
          WHERE  MG3.ITAKU_KAISHA_CD =  l_inItakuKaishaCd
            AND MG3.MGR_CD			 =  l_inMgrCd
            AND MG3.SHOKAN_YMD		 =  l_inDate
            AND MG3.SHOKAN_KBN		 IN (KAIIRE_SHOKYAKU,
                                         PUT_OPTION,
                                         YOYAKU_KOUSHI)
            AND SC04.CODE_SHUBETSU	 =  CODE_SHOKAN_KBN
            AND MG3.SHOKAN_KBN		 =  SC04.CODE_VALUE
            AND ((l_inFlg = '0'
                  AND ((SELECT SC04.CODE_SORT
                          FROM SCODE SC04
                         WHERE SC04.CODE_SHUBETSU = CODE_SHOKAN_KBN
                           AND SC04.CODE_VALUE    = l_inShokanKbn) > SC04.CODE_SORT))
                  OR
                 (l_inFlg = '1'
                  AND ((SELECT SC04.CODE_SORT
                          FROM SCODE SC04
                         WHERE SC04.CODE_SHUBETSU = CODE_SHOKAN_KBN
                           AND SC04.CODE_VALUE    = l_inShokanKbn) >= SC04.CODE_SORT)))) VMG3;

        -- 振替債総額取得（特例社債（定時償還）用）
        curRecTeijiGensai CURSOR FOR
            SELECT coalesce(Z01.GENSAI_KNGK / Z01.FACTOR,0) AS TEIJI_GENSAI_KNGK
              FROM GENSAI_RIREKI Z01
             WHERE Z01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
               AND Z01.MGR_CD = l_inMgrCd
               AND Z01.SHOKAN_KBN = '01'
               AND Z01.SHOKAN_YMD = l_furiYmd
               AND Z01.YOJITSU_FLG = '1' -- 予定実績フラグ=実績
               AND Z01.SHORI_KBN = '1'; -- 処理区分=承認済
        -- 買入、プットの名目減債額取得（特例社債（定時償還）用）
        -- 同一償還日に複数償還区分がある場合は、コードマスタのソート順が自分より小さいものまでを取得
        curRecMeimokuGensaiT CURSOR FOR
            SELECT
                coalesce(SUM(WK1.GENSAI_KNGK),0) AS MEIMOKU_GENSAI_KNGK
            FROM
                (SELECT coalesce(SUM(MG3.MUNIT_GENSAI_KNGK / MG3.FACTOR),0) AS GENSAI_KNGK
                   FROM MGR_SHOKIJ MG3
                  WHERE MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd
                    AND MG3.MGR_CD = l_inMgrCd
                    AND MG3.SHOKAN_KBN IN (KAIIRE_SHOKYAKU, PUT_OPTION)
                    AND MG3.SHOKAN_YMD < l_inDate

UNION ALL

                 SELECT coalesce(SUM(MG3.MUNIT_GENSAI_KNGK / MG3.FACTOR),0) AS GENSAI_KNGK
                   FROM MGR_SHOKIJ MG3,
                        SCODE SC04
                  WHERE MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd
                    AND MG3.MGR_CD = l_inMgrCd
                    AND MG3.SHOKAN_KBN IN (KAIIRE_SHOKYAKU, PUT_OPTION)
                    AND MG3.SHOKAN_YMD = l_inDate
                    AND SC04.CODE_SHUBETSU  =  CODE_SHOKAN_KBN
                    AND MG3.SHOKAN_KBN   =  SC04.CODE_VALUE
                    AND ((l_inFlg = '0'
                          AND ((SELECT SC04.CODE_SORT
                                  FROM SCODE SC04
                                 WHERE SC04.CODE_SHUBETSU = CODE_SHOKAN_KBN
                                   AND SC04.CODE_VALUE    = l_inShokanKbn) > SC04.CODE_SORT))
                          OR
                         (l_inFlg = '1'
                          AND ((SELECT SC04.CODE_SORT
                                  FROM SCODE SC04
                                 WHERE SC04.CODE_SHUBETSU = CODE_SHOKAN_KBN
                                   AND SC04.CODE_VALUE    = l_inShokanKbn) >= SC04.CODE_SORT)))) WK1;

        -- 買入、プット、予約権行使の名目減債額取得（新発債用）
        -- 同一償還日に複数償還区分がある場合は、コードマスタのソート順が自分より小さいものまでを取得
        curRecMeimokuGensaiS CURSOR FOR
            SELECT
                WK1.SHOKAN_YMD,
                WK1.SHOKAN_KBN,
                WK1.MUNIT_GENSAI_KNGK
            FROM
                (SELECT MG3.SHOKAN_YMD,
                        MG3.SHOKAN_KBN,
                        MG3.MUNIT_GENSAI_KNGK
                   FROM MGR_SHOKIJ MG3
                  WHERE MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd
                    AND MG3.MGR_CD = l_inMgrCd
                    AND MG3.SHOKAN_YMD < l_inDate
                    AND MG3.SHOKAN_KBN in (KAIIRE_SHOKYAKU,
                                           PUT_OPTION,
                                           YOYAKU_KOUSHI)

UNION ALL

                 SELECT MG3.SHOKAN_YMD,
                        MG3.SHOKAN_KBN,
                        MG3.MUNIT_GENSAI_KNGK
                   FROM MGR_SHOKIJ MG3,
                        SCODE SC04
                  WHERE MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd
                    AND MG3.MGR_CD = l_inMgrCd
                    AND MG3.SHOKAN_YMD = l_inDate
                    AND MG3.SHOKAN_KBN IN (KAIIRE_SHOKYAKU,
                                           PUT_OPTION,
                                           YOYAKU_KOUSHI)
                    AND SC04.CODE_SHUBETSU  =  CODE_SHOKAN_KBN
                    AND MG3.SHOKAN_KBN   =  SC04.CODE_VALUE
                    AND ((l_inFlg = '0'
                          AND ((SELECT SC04.CODE_SORT
                                  FROM SCODE SC04
                                 WHERE SC04.CODE_SHUBETSU = CODE_SHOKAN_KBN
                                   AND SC04.CODE_VALUE    = l_inShokanKbn) > SC04.CODE_SORT))
                          OR
                         (l_inFlg = '1'
                          AND ((SELECT SC04.CODE_SORT
                                  FROM SCODE SC04
                                 WHERE SC04.CODE_SHUBETSU = CODE_SHOKAN_KBN
                                   AND SC04.CODE_VALUE    = l_inShokanKbn) >= SC04.CODE_SORT)))) WK1;

      /*==============================================================================*/

      /*             メイン　                                                         */

      /*==============================================================================*/

BEGIN
        -- 特例社債フラグ取得
        SELECT MG1.TOKUREI_SHASAI_FLG, MG1.SHOKAN_METHOD_CD
          INTO STRICT l_tokureiFlg, l_shokanMethod
          FROM MGR_KIHON MG1
         WHERE MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
           AND MG1.MGR_CD = l_inMgrCd;

        IF l_tokureiFlg = TOKUREI_SHASAI THEN
            temp_rec := pkipazndk.gettokureikjndtkbn(l_inItakuKaishaCd, l_inMgrCd, l_inDate);

            l_tokureiKjndtKbn := temp_rec.extra_param;
            l_furiYmd := temp_rec.l_outFuriYmd;
        END IF;

        l_shasaiTotal := pkipazndk.getShasaiTotal(l_inItakuKaishaCd,l_inMgrcd,l_inDate,'0',l_inFlg);


        FOR r_getMgrShokij IN c_getMgrShokij(l_inItakuKaishaCd,l_inMgrCd,l_inDate) LOOP
            l_factor := (pkipazndk.getfactor(l_inItakuKaishaCd,l_inMgrcd,l_inDate,l_inShokanKbn))::numeric;
            IF pkipazndk.validatefactor(l_factor) = 0 THEN
                l_gensaiTotal := l_gensaiTotal + r_getMgrShokij.MUNIT_GENSAI_KNGK_SUM;
            ELSE
                --CALL pkLog.ERROR('ECM321',SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
                CALL pkLog.ERROR('ECM321',SP_ID, 'ファクターが割り切れませんでした。ファクター= ' || trunc(l_factor::numeric, 13));
                RETURN NULL;
            END IF;

        END LOOP;

        --実質残高( = 振替債の総額 - 振替債分の減債金額累計)
        IF l_tokureiFlg = TOKUREI_SHASAI AND l_tokureiKjndtKbn = 1 THEN
            l_jissitsuZndk := 0;
        ELSE
            l_jissitsuZndk := l_shasaiTotal::numeric - l_gensaiTotal;
        END IF;

        -- 特例社債銘柄入力時
        IF l_tokureiFlg = TOKUREI_SHASAI THEN
            -- 満期一括 OR 永久債
            IF l_shokanMethod IN ('1', '9') THEN
                -- 基準日が振替移行日より前の場合、または今回回次を含まないかつ基準日と振替移行日（最初）が同じ場合、名目残高'0'
                IF l_tokureiKjndtKbn = 1 OR (l_inFlg = '0' AND l_inShokanKbn = GENTO_FURI_IDO AND l_inDate = l_furiYmd) THEN
                    l_outValue := '0';
                ELSE
                    l_outValue   := l_jissitsuZndk;
                END IF;
                -- 定時償還 AND 入力基準日≧ZO1.基準日
            ELSIF l_shokanMethod = '2' AND l_tokureiKjndtKbn = 2 THEN
                IF l_jissitsuZndk = 0 THEN
                    -- 実質残高が0の場合（満期の場合）、名目残高に0をセット
                    l_outValue := '0';
                ELSE
                    --特例社債（定時償還）の振替債総額取得
                    FOR recTeijiGensai IN curRecTeijiGensai LOOP
                        l_shasaiTotal := recTeijiGensai.TEIJI_GENSAI_KNGK;
                    END LOOP;

                    --買入、プットの名目減債額取得
                    FOR recMeimokuGensaiT IN curRecMeimokuGensaiT LOOP
                        l_bufGensaiTotal := recMeimokuGensaiT.MEIMOKU_GENSAI_KNGK;
                    END LOOP;

                    --基準残高(名目残高) = A_振替債の総額 - (減債金額/ファクター)の累計
                    l_outValue := (l_shasaiTotal::bigint - l_bufGensaiTotal)::varchar;
                END IF;
            ELSE
                l_outValue := '0';
            END IF;
            -- 新発債の場合
        ELSIF l_tokureiFlg = NOT_TOKUREI_SHASAI THEN
            IF l_jissitsuZndk = 0 THEN
                -- 実質残高が0の場合（満期の場合）、名目残高に0をセット
                l_outValue := '0';
            ELSE
                --買入、プット、予約権行使の名目減債額取得
                FOR recMeimokuGensaiS IN curRecMeimokuGensaiS LOOP
                    l_bufDate        := recMeimokuGensaiS.SHOKAN_YMD;
                    l_bufShokankbn   := recMeimokuGensaiS.SHOKAN_KBN;
                    l_bufGensaiKngk  := recMeimokuGensaiS.MUNIT_GENSAI_KNGK;
                    l_bufFactor      := pkIpaZndk.getFactor(l_inItakuKaishaCd, l_inMgrCd, l_bufDate, l_bufShokankbn); -- 基準日時点でのファクター
                    --(銘柄_償還回次.元利減債金額 / 基準日時点でのファクター)を減債金額の件数分加算する
                    IF l_bufFactor <> 0 THEN
                        -- 0除算対策 (ファクターが0の時は0になるので加算しない)
                        l_bufGensaiTotal := l_bufGensaiTotal + (l_bufGensaiKngk / l_bufFactor);
                    END IF;
                END LOOP;


                --基準残高(名目残高) = A_振替債の総額 - (減債金額/ファクター)の累計
                l_outValue := (l_shasaiTotal::bigint - l_bufGensaiTotal)::varchar;
            END IF;
        END IF;

        -- 今回の回次を含めた実質残高が0の場合、名目残高を0にするように修正
        IF l_inFlg = '1' AND pkIpaZndk.getKjnZndk(l_inItakuKaishaCd,l_inMgrcd,l_inDate,l_inShokanKbn,13) = '0' THEN
            --実質残高が0の時、基準残高(名目残高)を強制的に０にする
            l_outValue := '0';
        END IF;

        RETURN l_outValue;
    /*====================================================================*
                異常終了 出口
     *====================================================================*/
    EXCEPTION
	    WHEN OTHERS THEN
    		CALL pkLog.fatal('ECM321', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
            RAISE;
    END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;
-- REVOKE ALL ON FUNCTION pkipazndk.calcmeimokuzndk (l_inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE, l_inMgrCd MGR_SHOKIJ.MGR_CD%TYPE, l_inDate MGR_SHOKIJ.SHOKAN_YMD%TYPE, l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE, l_inFlg CHAR) FROM PUBLIC;

   /**
    *
    * @author 磯田　浩靖
    *
    * 銘柄の残高取得<br>
    * パラメータで指定した委託会社、銘柄コード、基準日、償還区分、実数に
    * 対応した名目残高を取得する。（同一期日考慮）
    * 【注：名目残高は「振替債分の名目残高」を返す】
    *
    *
    * @param l_initakukaishacd    委託会社コード
    * @param l_inmgrcd            銘柄コード
    * @param l_indate             基準日
    * @param l_inShokanKbn        償還区分
    * @param l_inrealvalue        実数
    * @return  l_outValue          取得した基準日残高
    */
CREATE OR REPLACE FUNCTION pkipazndk.getmeimokuzndk (l_inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE, l_inMgrCd MGR_SHOKIJ.MGR_CD%TYPE, l_inDate MGR_SHOKIJ.SHOKAN_YMD%TYPE, l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE) RETURNS varchar AS $body$
DECLARE

    /*==============================================================================*/

    /*          定数定義                          */

    /*==============================================================================*/

        SP_ID                 CONSTANT varchar(50) := 'pkIpaZndk.getKjnZndk().getMeimokuZndk';
        NOT_CONTAIN_KAIJI     CONSTANT varchar(1) := '0'; -- 今回の回次を含まない
    /*==============================================================================*/

    /*          変数定義                          */

    /*==============================================================================*/

        l_outValue        varchar(100); -- 取得した値
BEGIN
        l_outValue := pkipazndk.calcmeimokuzndk(l_inItakuKaishaCd, l_inMgrCd, l_inDate, l_inShokanKbn, NOT_CONTAIN_KAIJI);
        RETURN l_outValue;
    /*====================================================================*
                異常終了 出口
     *====================================================================*/
    EXCEPTION
	    WHEN OTHERS THEN
    		CALL pkLog.fatal('ECM321', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
            RAISE;
    END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;
-- REVOKE ALL ON FUNCTION pkipazndk.getmeimokuzndk (l_inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE, l_inMgrCd MGR_SHOKIJ.MGR_CD%TYPE, l_inDate MGR_SHOKIJ.SHOKAN_YMD%TYPE, l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE) FROM PUBLIC;

   /**
    *
    * @author 緒方 広道
    *
    * 銘柄の残高取得<br>
    * パラメータで指定した委託会社、銘柄コード、基準日、償還区分、実数に
    * 対応した名目残高を取得する。（同一期日考慮）
    * 今回の回次を含んだ名目残高を返します。
    * 【注：名目残高は「振替債分の名目残高」を返す】
    *
    * @param l_initakukaishacd    委託会社コード
    * @param l_inmgrcd            銘柄コード
    * @param l_indate             基準日
    * @param l_inShokanKbn        償還区分
    * @param l_inrealvalue        実数
    * @return  l_outValue          取得した基準日残高
    */
CREATE OR REPLACE FUNCTION pkipazndk.getmeimokuzndkcurrentcontain (l_inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE, l_inMgrCd MGR_SHOKIJ.MGR_CD%TYPE, l_inDate MGR_SHOKIJ.SHOKAN_YMD%TYPE, l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE) RETURNS varchar AS $body$
DECLARE

    /*==============================================================================*/

    /*          定数定義                          */

    /*==============================================================================*/

        SP_ID               CONSTANT varchar(50) := 'pkIpaZndk.getKjnZndk().getMeimokuZndk';
        CONTAIN_KAIJI       CONSTANT varchar(1) := '1'; -- 今回の回次を含む
    /*==============================================================================*/

    /*          変数定義                          */

    /*==============================================================================*/

        l_outValue        varchar(100); -- 取得した値
BEGIN
        l_outValue := pkipazndk.calcmeimokuzndk(l_inItakuKaishaCd, l_inMgrCd, l_inDate, l_inShokanKbn, CONTAIN_KAIJI);
        RETURN l_outValue;
    /*====================================================================*
                異常終了 出口
     *====================================================================*/
    EXCEPTION
	    WHEN OTHERS THEN
    		CALL pkLog.fatal('ECM321', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
            RAISE;
    END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;
-- REVOKE ALL ON FUNCTION pkipazndk.getmeimokuzndkcurrentcontain (l_inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE, l_inMgrCd MGR_SHOKIJ.MGR_CD%TYPE, l_inDate MGR_SHOKIJ.SHOKAN_YMD%TYPE, l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE) FROM PUBLIC;

   /**
    *
    * @author 磯田　浩靖
    *
    * 銘柄の残高取得<br>
    * パラメータで指定した委託会社、銘柄コード、基準日、償還区分、実数に
    * 対応した実質残高を取得する。（同一期日考慮）
    *
    * @param l_initakukaishacd    委託会社コード
    * @param l_inmgrcd            銘柄コード
    * @param l_indate             基準日
    * @param l_inShokanKbn        償還区分
    * @param l_inrealvalue        実数
    * @return  l_outValue          取得した基準日残高
    */
CREATE OR REPLACE FUNCTION pkipazndk.getjissitsuzndk (l_inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE, l_inMgrCd MGR_SHOKIJ.MGR_CD%TYPE, l_inDate MGR_SHOKIJ.SHOKAN_YMD%TYPE, l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE) RETURNS varchar AS $body$
DECLARE

    /*==============================================================================*/

    /*          定数定義                          */

    /*==============================================================================*/

        SP_ID               CONSTANT varchar(50) := 'pkIpaZndk.getKjnZndk().getMeimokuZndk';

        CODE_SHOKAN_KBN     CONSTANT varchar(3)  := '714';

    /*==============================================================================*/

    /*          変数定義                          */

    /*==============================================================================*/

        l_outValue        varchar(100); -- 取得した値
        l_gensaiTotal     numeric         := 0;
        l_shasaiTotal     varchar(16); -- 社債の総額
BEGIN

        l_shasaiTotal := pkipazndk.getShasaiTotal(l_inItakuKaishaCd,l_inMgrcd,l_inDate,'1','0');
        /*
         * 対象の償還期日以前の償還回次データを取得する。
         * 償還期日、償還区分（コードマスタのソート順番）の順にソートして取得する。
         */
        SELECT
            coalesce(SUM(VMG3.MUNIT_GENSAI_KNGK),0) AS MUNIT_GENSAI_KNGK_SUM
        INTO STRICT
            l_gensaiTotal
        FROM
            /* 対象の償還日より前の回次の振替単位元本減債金額を取得 */

            (SELECT coalesce(MG3.MUNIT_GENSAI_KNGK,0) AS MUNIT_GENSAI_KNGK
             FROM   MGR_SHOKIJ MG3
             WHERE  MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd
             AND    MG3.MGR_CD = l_inMgrCd
             AND    MG3.SHOKAN_YMD < l_inDate

UNION ALL

            /*
             * 対象の償還日と同じ日の回次の振替単位元本減債金額を取得
             * 対象の回次のソート順番より小さいもののみ取得する。
             */
             SELECT coalesce(MG3.MUNIT_GENSAI_KNGK,0) AS MUNIT_GENSAI_KNGK
             FROM   MGR_SHOKIJ MG3,
                    SCODE      SC04
             WHERE  MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd
             AND    MG3.MGR_CD = l_inMgrCd
             AND    MG3.SHOKAN_YMD = l_inDate
             AND    SC04.CODE_SHUBETSU = CODE_SHOKAN_KBN
             AND    SC04.CODE_VALUE = MG3.SHOKAN_KBN
             AND (SELECT CODE_SORT
                     FROM   SCODE
                     WHERE  CODE_SHUBETSU = CODE_SHOKAN_KBN
                     AND    CODE_VALUE = l_inShokanKbn) > SC04.CODE_SORT) VMG3;

        --基準残高(実質残高) = 社債の総額 - 減債金額の累計
        l_outValue := (l_shasaiTotal::numeric - l_gensaiTotal)::varchar;

        RETURN l_outValue;
    /*====================================================================*
                異常終了 出口
     *====================================================================*/
    EXCEPTION
	    WHEN OTHERS THEN
    		CALL pkLog.fatal('ECM321', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
            RAISE;
    END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;
-- REVOKE ALL ON FUNCTION pkipazndk.getjissitsuzndk (l_inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE, l_inMgrCd MGR_SHOKIJ.MGR_CD%TYPE, l_inDate MGR_SHOKIJ.SHOKAN_YMD%TYPE, l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE) FROM PUBLIC;

   /**
    *
    * @author 磯田　浩靖
    *
    * 銘柄の残高取得<br>
    * パラメータで指定した委託会社、銘柄コード、基準日、償還区分、実数に
    * 対応した実質残高を取得する。（同一期日考慮）
    * 今回の回次を含んだ実質残高を返します。
    *
    * @param l_initakukaishacd    委託会社コード
    * @param l_inmgrcd            銘柄コード
    * @param l_indate             基準日
    * @param l_inShokanKbn        償還区分
    * @param l_inrealvalue        実数
    * @return  l_outValue          取得した基準日残高
    */
CREATE OR REPLACE FUNCTION pkipazndk.getjissitsuzndkcurrentcontain ( l_inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE, l_inMgrCd MGR_SHOKIJ.MGR_CD%TYPE, l_inDate MGR_SHOKIJ.SHOKAN_YMD%TYPE, l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE) RETURNS varchar AS $body$
DECLARE

    /*==============================================================================*/

    /*          定数定義                          */

    /*==============================================================================*/

        SP_ID               CONSTANT varchar(50) := 'pkIpaZndk.getKjnZndk().getMeimokuZndk';

        CODE_SHOKAN_KBN     CONSTANT varchar(3)  := '714';

    /*==============================================================================*/

    /*          変数定義                          */

    /*==============================================================================*/

        l_outValue        varchar(100); -- 取得した値
        l_gensaiTotal     numeric         := 0;
        l_shasaiTotal     varchar(16); -- 社債の総額
BEGIN

        l_shasaiTotal := pkipazndk.getShasaiTotal(l_inItakuKaishaCd,l_inMgrcd,l_inDate,'1','1');
        /*
         * 対象の償還期日以前の償還回次データを取得する。
         * 償還期日、償還区分（コードマスタのソート順番）の順にソートして取得する。
         */
        SELECT
            coalesce(SUM(VMG3.MUNIT_GENSAI_KNGK),0) AS MUNIT_GENSAI_KNGK_SUM
        INTO STRICT
            l_gensaiTotal
        FROM
            /* 対象の償還日より前の回次の振替単位元本減債金額を取得 */

            (SELECT coalesce(MG3.MUNIT_GENSAI_KNGK,0) AS MUNIT_GENSAI_KNGK
             FROM   MGR_SHOKIJ MG3
             WHERE  MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd
             AND    MG3.MGR_CD = l_inMgrCd
             AND    MG3.SHOKAN_YMD < l_inDate

UNION ALL

            /*
             * 対象の償還日と同じ日の回次の振替単位元本減債金額を取得
             * 対象の回次のソート順番以下のデータを取得する。
             */
             SELECT coalesce(MG3.MUNIT_GENSAI_KNGK,0) AS MUNIT_GENSAI_KNGK
             FROM   MGR_SHOKIJ MG3,
                    SCODE      SC04
             WHERE  MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd
             AND    MG3.MGR_CD = l_inMgrCd
             AND    MG3.SHOKAN_YMD = l_inDate
             AND    SC04.CODE_SHUBETSU = CODE_SHOKAN_KBN
             AND    SC04.CODE_VALUE = MG3.SHOKAN_KBN
             AND (SELECT CODE_SORT
                     FROM   SCODE
                     WHERE  CODE_SHUBETSU = CODE_SHOKAN_KBN
                     AND    CODE_VALUE = l_inShokanKbn) >= SC04.CODE_SORT) VMG3;

        --基準残高(実質残高) = 社債の総額 - 減債金額の累計
        l_outValue := (l_shasaiTotal::numeric - l_gensaiTotal)::varchar;

        RETURN l_outValue;
    /*====================================================================*
                異常終了 出口
     *====================================================================*/
    EXCEPTION
	    WHEN OTHERS THEN
    		CALL pkLog.fatal('ECM321', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
            RAISE;
    END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;
-- REVOKE ALL ON FUNCTION pkipazndk.getjissitsuzndkcurrentcontain ( l_inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE, l_inMgrCd MGR_SHOKIJ.MGR_CD%TYPE, l_inDate MGR_SHOKIJ.SHOKAN_YMD%TYPE, l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE) FROM PUBLIC;


   /**
    *
    * @author 磯田　浩靖
    *
    * 銘柄の残高取得<br>
    * パラメータで指定した委託会社、銘柄コード、基準日、償還区分、実数に
    * 対応したファクターを取得する。（同一期日考慮）
    *
    * @param l_initakukaishacd    委託会社コード
    * @param l_inmgrcd            銘柄コード
    * @param l_indate             基準日
    * @param l_inShokanKbn        償還区分
    * @param l_inrealvalue        実数
    * @return  l_outValue          取得した基準日残高
    */
CREATE OR REPLACE FUNCTION pkipazndk.getfactor (l_inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE, l_inMgrCd MGR_SHOKIJ.MGR_CD%TYPE, l_inDate MGR_SHOKIJ.SHOKAN_YMD%TYPE, l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE) RETURNS varchar AS $body$
DECLARE

    /*==============================================================================*/

    /*          定数定義                          */

    /*==============================================================================*/

        SP_ID               CONSTANT varchar(50) := 'pkIpaZndk.getKjnZndk().getFactor';

        CODE_SHOKAN_KBN     CONSTANT varchar(3)  := '714';

    /*==============================================================================*/

    /*          変数定義                          */

    /*==============================================================================*/

        l_outValue          varchar(100); -- 取得した値
		l_kakushasai_kngk	numeric := 0;
		l_gensai_kngk		numeric := 0;
		l_gensai_kngk_sum	numeric := 0;		-- 振替債移行時点減債金額累計
		l_factor			numeric := 0;		-- ファクター
		l_shokanMethodCd	varchar(1);
		l_tokureiFlg		varchar(1);
		l_kjndtKbn			int := 0;	-- 特例社債入力基準日区分
		l_furiYmd			varchar(8);		-- 振替移行日
		temp_rec            record;
BEGIN
        --特例社債入力時 入力基準日区分取得
        temp_rec := pkipazndk.gettokureikjndtkbn(l_inItakuKaishaCd, l_inMgrCd, l_inDate);

        l_kjndtKbn := temp_rec.extra_param;
        l_furiYmd := temp_rec.l_outFuriYmd;

        SELECT
			MG1.SHOKAN_METHOD_CD,
			MG1.TOKUREI_SHASAI_FLG,
            MG1.KAKUSHASAI_KNGK,
            coalesce(MG3SUM.FUNIT_GENSAI_KNGK_SUM,0)
        INTO STRICT
			l_shokanMethodCd,
			l_tokureiFlg,
            l_kakushasai_kngk,
            l_gensai_kngk
        FROM
            MGR_KIHON MG1,
            (SELECT SUM(VMG3.FUNIT_GENSAI_KNGK) AS FUNIT_GENSAI_KNGK_SUM
                    /* 対象の償還日より前の回次の振替単位元本減債金額を取得 */

             FROM (SELECT MG3.FUNIT_GENSAI_KNGK AS FUNIT_GENSAI_KNGK
                     FROM   MGR_SHOKIJ MG3
                     WHERE  MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd
                     AND    MG3.MGR_CD = l_inMgrCd
                     AND    MG3.SHOKAN_YMD < l_inDate

UNION ALL

                    /*
                     * 対象の償還日と同じ日の回次の振替単位元本減債金額を取得
                     * 対象の回次のソート順番より小さいもののみ取得する。
                     */
                     SELECT MG3.FUNIT_GENSAI_KNGK AS FUNIT_GENSAI_KNGK
                     FROM   MGR_SHOKIJ MG3,
                            SCODE      SC04
                     WHERE  MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd
                     AND    MG3.MGR_CD = l_inMgrCd
                     AND    MG3.SHOKAN_YMD = l_inDate
                     AND    SC04.CODE_SHUBETSU = CODE_SHOKAN_KBN
                     AND    SC04.CODE_VALUE = MG3.SHOKAN_KBN
                     AND (SELECT CODE_SORT
                             FROM   SCODE
                             WHERE  CODE_SHUBETSU = CODE_SHOKAN_KBN
                             AND    CODE_VALUE = l_inShokanKbn) > SC04.CODE_SORT) VMG3
             ) MG3SUM
        WHERE  MG1.ITAKU_KAISHA_CD = l_initakukaishacd
        AND    MG1.MGR_CD = l_inmgrcd;

        IF (l_tokureiFlg = 'Y') THEN
            IF l_kjndtKbn IN (1, 3) THEN
                l_gensai_kngk := l_kakushasai_kngk;
            ELSE
                -- MG1.償還方法 = 定時償還
                IF (l_shokanMethodCd = 2) THEN
                    -- 移行時ファクターを取得
                    l_factor          := pkipazndk.getikofactor(l_inItakuKaishaCd, l_inMgrCd, l_inDate);
                    l_gensai_kngk_sum := l_kakushasai_kngk - (l_kakushasai_kngk * l_factor);
                -- MG1.償還方法 = 満期一括 OR 永久債
                ELSE
                    l_gensai_kngk := 0;
                END IF;
            END IF;
        END IF;

		--0除算回避(念のため)
		IF l_kakushasai_kngk <> 0 THEN
			l_factor := (l_kakushasai_kngk - (l_gensai_kngk + l_gensai_kngk_sum)) / l_kakushasai_kngk;
		ELSE
			l_factor := 0;
		END IF;

        -- 振替債分の残高が0になった場合、強制的にファクター0を返す。
        IF pkipazndk.getjissitsuzndk(l_inItakuKaishaCd,l_inMgrCd,l_inDate,l_inShokanKbn) = '0' THEN
            l_factor := 0;
        END IF;

		l_outValue :=  pkcharacter.numeric_to_char(l_factor);


		RETURN l_outValue;

    /*====================================================================*
                異常終了 出口
     *====================================================================*/
    EXCEPTION
	    WHEN OTHERS THEN
    		CALL pkLog.fatal('ECM321', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
            RAISE;
    END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;
-- REVOKE ALL ON FUNCTION pkipazndk.getfactor (l_inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE, l_inMgrCd MGR_SHOKIJ.MGR_CD%TYPE, l_inDate MGR_SHOKIJ.SHOKAN_YMD%TYPE, l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE) FROM PUBLIC;

   /**
    *
    * @author 磯田　浩靖
    *
    * 銘柄の残高取得<br>
    * パラメータで指定した委託会社、銘柄コード、基準日、償還区分、実数に
    * 対応したファクターを取得する。（同一期日考慮）
    * 今回の回次を含んだファクターを返します。
    *
    * @param l_initakukaishacd    委託会社コード
    * @param l_inmgrcd            銘柄コード
    * @param l_indate             基準日
    * @param l_inShokanKbn        償還区分
    * @param l_inrealvalue        実数
    * @return  l_outValue          取得した基準日残高
    */
CREATE OR REPLACE FUNCTION pkipazndk.getfactorcurrentcontain ( l_inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE, l_inMgrCd MGR_SHOKIJ.MGR_CD%TYPE, l_inDate MGR_SHOKIJ.SHOKAN_YMD%TYPE, l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE) RETURNS varchar AS $body$
DECLARE

    /*==============================================================================*/

    /*          定数定義                          */

    /*==============================================================================*/

        SP_ID               CONSTANT varchar(50) := 'pkIpaZndk.getKjnZndk().getFactor';

        CODE_SHOKAN_KBN     CONSTANT varchar(3)  := '714';

    /*==============================================================================*/

    /*          変数定義                          */

    /*==============================================================================*/

        l_outValue          varchar(100); -- 取得した値
		l_kakushasai_kngk	numeric := 0;
		l_gensai_kngk		numeric := 0;
		l_gensai_kngk_sum	numeric := 0;		-- 振替債移行時点減債金額累計
		l_factor			numeric := 0;		-- ファクター
		l_shokanMethodCd	varchar(1);
		l_tokureiFlg		varchar(1);
		l_kjndtKbn			int := 0;	-- 特例社債入力基準日区分
		l_furiYmd			varchar(8);		-- 振替移行日
		temp_rec            record;
BEGIN
        --特例社債入力時 入力基準日区分取得
        temp_rec := pkipazndk.gettokureikjndtkbn(l_inItakuKaishaCd, l_inMgrCd, l_inDate);

        l_kjndtKbn := temp_rec.extra_param;
        l_furiYmd := temp_rec.l_outFuriYmd;

        SELECT
			MG1.SHOKAN_METHOD_CD,
			MG1.TOKUREI_SHASAI_FLG,
            MG1.KAKUSHASAI_KNGK,
            coalesce(MG3SUM.FUNIT_GENSAI_KNGK_SUM,0)
        INTO STRICT
			l_shokanMethodCd,
			l_tokureiFlg,
            l_kakushasai_kngk,
            l_gensai_kngk
        FROM
            MGR_KIHON MG1,
            (SELECT SUM(VMG3.FUNIT_GENSAI_KNGK) AS FUNIT_GENSAI_KNGK_SUM
                    /* 対象の償還日より前の回次の振替単位元本減債金額を取得 */

             FROM (SELECT MG3.FUNIT_GENSAI_KNGK AS FUNIT_GENSAI_KNGK
                     FROM   MGR_SHOKIJ MG3
                     WHERE  MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd
                     AND    MG3.MGR_CD = l_inMgrCd
                     AND    MG3.SHOKAN_YMD < l_inDate

UNION ALL

                    /*
                     * 対象の償還日と同じ日の回次の振替単位元本減債金額を取得
                     * 対象の回次のソート順番以下のデータを取得する。
                     */
                     SELECT MG3.FUNIT_GENSAI_KNGK AS FUNIT_GENSAI_KNGK
                     FROM   MGR_SHOKIJ MG3,
                            SCODE      SC04
                     WHERE  MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd
                     AND    MG3.MGR_CD = l_inMgrCd
                     AND    MG3.SHOKAN_YMD = l_inDate
                     AND    SC04.CODE_SHUBETSU = CODE_SHOKAN_KBN
                     AND    SC04.CODE_VALUE = MG3.SHOKAN_KBN
                     AND (SELECT CODE_SORT
                             FROM   SCODE
                             WHERE  CODE_SHUBETSU = CODE_SHOKAN_KBN
                             AND    CODE_VALUE = l_inShokanKbn) >= SC04.CODE_SORT) VMG3
             ) MG3SUM
        WHERE  MG1.ITAKU_KAISHA_CD = l_initakukaishacd
        AND    MG1.MGR_CD = l_inmgrcd;

		IF (l_tokureiFlg = 'Y') THEN
            IF l_kjndtKbn IN (1, 3) THEN
                l_gensai_kngk := l_kakushasai_kngk;
            ELSE
			    -- MG1.償還方法 = 定時償還
			    IF (l_shokanMethodCd = 2) THEN
				    -- 移行時ファクターを取得
				    l_factor := pkipazndk.getikofactor(l_inItakuKaishaCd, l_inMgrCd, l_inDate);
				    l_gensai_kngk_sum := l_kakushasai_kngk - (l_kakushasai_kngk * l_factor);

			    -- MG1.償還方法 = 満期一括 OR 永久債
			    ELSE
                    l_gensai_kngk := 0;
       		    END IF;
            END IF;
		END IF;

		--0除算回避(念のため)
		IF l_kakushasai_kngk <> 0 THEN
			l_factor := (l_kakushasai_kngk - (l_gensai_kngk + l_gensai_kngk_sum)) / l_kakushasai_kngk;
		ELSE
			l_factor := 0;
		END IF;

        -- 振替債分の残高が0になった場合、強制的にファクター0を返す。
        IF pkipazndk.getjissitsuzndkcurrentcontain(l_inItakuKaishaCd,l_inMgrCd,l_inDate,l_inShokanKbn) = '0' THEN
			l_factor := 0;
        END IF;

		l_outValue :=  l_factor::varchar;
		RETURN l_outValue;

    /*====================================================================*
                異常終了 出口
     *====================================================================*/
    EXCEPTION
	    WHEN OTHERS THEN
    		CALL pkLog.fatal('ECM321', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
            RAISE;
    END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;

CREATE OR REPLACE FUNCTION pkipazndk.getkjnzndk (
    l_initakukaishacd TEXT, 
    l_inmgrcd TEXT, 
    l_indate TEXT, 
    l_inrealvalue bigint) RETURNS varchar AS $body$
DECLARE

        /*==============================================================================*/

        /*          定数定義                          */

        /*==============================================================================*/

        --償還区分
        MANKI_SHOKAN          CONSTANT char(2) := '10'; -- 満期償還
        TEIGAKU_SHOKAN        CONSTANT char(2) := '20'; -- 定時定額償還
        FUTEIGAKU_SHOKAN      CONSTANT char(2) := '21'; -- 定時不定額償還
        KAIIRE_SHOKYAKU       CONSTANT char(2) := '30'; -- 買入消却
        CALL_OPTION_ZENGAKU   CONSTANT char(2) := '40'; -- コールオプション(全額償還)
        CALL_OPTION_ICHIBU    CONSTANT char(2) := '41'; -- コールオプション(一部償還)
        PUT_OPTION            CONSTANT char(2) := '50'; -- プットオプション
        YOYAKU_KOUSHI         CONSTANT char(2) := '60'; -- 新株予約権行使
        GENTO_FURI_IDO        CONSTANT char(2) := '01'; -- 現登債から振替債への異動
        GENTO_MANKI_SHOKAN    CONSTANT char(2) := '81'; -- 現登債の満期償還
        GENTO_TEIGAKU_SHOKAN  CONSTANT char(2) := '82'; -- 現登債の定時定額償還
        GENTO_KAIIRE_SHOKYAKU CONSTANT char(2) := '83'; -- 現登債の買入消却
        GENTO_KURIAGE_SHOKAN  CONSTANT char(2) := '84'; -- 現登債の繰上償還
        GENTO_PUT_OPTION      CONSTANT char(2) := '85'; -- 現登債のプットオプション
		GENTO_YOYAKU_KOUSHI   CONSTANT char(2) := '86'; -- 現登債の新株予約権行使
        GENTO_ZNDK            CONSTANT char(2) := '99'; -- 現登債の残高
        --特例社債フラグ
        NOT_TOKUREI_SHASAI CONSTANT char(1) := 'N'; -- 特例社債でない
        TOKUREI_SHASAI     CONSTANT char(1) := 'Y'; -- 特例社債である
        /*==============================================================================*/

        /*          変数定義                          */

        /*==============================================================================*/

        l_retzndk numeric; --戻り値の残高
        l_tokurei_flg   char(1); --特例社債フラグ
        l_shokan_method char(1); --償還方法コード
        l_saiken_shurui char(2); --債券種類
        l_isin_cd       char(12); --ISINコード
        l_shokan_ymd    char(8); --償還日
        l_gyomu_ymd     char(8); --業務日付
        l_ritsuke_waribiki_kbn char(1); --利付割引区分
        l_ed_putkoshikikan_ymd char(8); --プットオプション行使期間終了日
        l_munit_gensai_kngk     numeric := 0; --銘柄単位元本減債金額
        l_tsuchi_shokan_kngk    numeric := 0; --償還金額（通知情報）
        l_furikae_sogaku        numeric := 0; --A 振替債移行分の累計金額(=振替債の総額)
        l_furikae_gensai_ruikei numeric := 0; --B 振替債分の減債金額累計
        l_gentou_gensai_ruikei  numeric := 0; --C 現登債分の減債金額累計
        l_kijunbi_factor        numeric := 0; --D 基準日時点でのファクター
        l_buf_factor            numeric := 0; --  減債金額合計計算用ファクター
        l_sashiosae_ruikei      numeric := 0; --E 差押さえの累計金額
        l_sashiosae_date        char(8); --  差押設定日
        l_sashiosae_kbn         char(1); --  差押区分
        l_sashiosae_settei_kngk numeric := 0; --  差押設定金額
        l_sashiosae_factor      numeric := 0; --  差押計算用ファクター
        l_kijun_meimoku_zndk    numeric := 0; --F 基準残高(名目残高)
        l_buf_date              char(8); --  基準残高集計用
        l_buf_shokankbn         char(2); --　償還区分
        l_buf_gensai_kngk       numeric := 0; --  基準残高集計用
        l_buf_gensai_total      numeric := 0; --  基準残高集計用
        l_ganribarai_zndk       numeric := 0; --G_元利払対象残高
        l_ganribarai_zndk_j     numeric := 0; --元利払対象実質残高
        l_jissitsu_zndk         numeric := 0; --H 実質残高
        l_jissitsu_zndk_gentou  numeric := 0; --I 実質残高(現登債分)
        l_jiko_hkuk_zndk        numeric := 0; --J 自行引受残高
        -- 特例社債銘柄入力時使用
        l_tokurei_kjndt_kbn int := 0; -- 特例社債入力基準日区分
        l_min_frk_iko_date  char(8); --  最小振替債移行期日
        temp_rec                     record;
        /*==============================================================================*/

        /*             カーソル定義                                                     */

        /*==============================================================================*/

        --特例社債の場合、減債履歴より「現登債から振替債の異動」かつ
        --承認済のレコードの減債金額合計を取得する
        curRecGensai CURSOR FOR
            SELECT SUM(Z01.GENSAI_KNGK) AS GENSAI_KNGK
              FROM GENSAI_RIREKI Z01
             WHERE Z01.ITAKU_KAISHA_CD = l_initakukaishacd
               AND Z01.MGR_CD = l_inmgrcd
               AND Z01.SHOKAN_YMD <= l_indate
               AND Z01.SHOKAN_KBN = GENTO_FURI_IDO  -- 償還区分=「現登債から振替債への異動」
               AND Z01.SHORI_KBN = '1'
             GROUP BY Z01.ITAKU_KAISHA_CD, Z01.MGR_CD;
        --B_振替債分の減債金額累計
        -- 償還区分=「振替債の各減債情報」であるレコードのみ取得
        curRecFuriRuikei CURSOR FOR
            SELECT SUM(MG3.MUNIT_GENSAI_KNGK) AS MUNIT_GENSAI_KNGK
              FROM MGR_SHOKIJ MG3
             WHERE MG3.ITAKU_KAISHA_CD = l_initakukaishacd
               AND MG3.MGR_CD = l_inmgrcd
               AND MG3.SHOKAN_YMD <= l_indate
               AND MG3.SHOKAN_KBN IN (MANKI_SHOKAN,
                                      TEIGAKU_SHOKAN,
                                      FUTEIGAKU_SHOKAN,
                                      KAIIRE_SHOKYAKU,
                                      CALL_OPTION_ZENGAKU,
                                      CALL_OPTION_ICHIBU,
                                      PUT_OPTION,
                                      YOYAKU_KOUSHI)
             GROUP BY MG3.ITAKU_KAISHA_CD, MG3.MGR_CD;
        --C_現登債分の減債金額累計
        -- 償還区分=「現登債の各減債情報」であるレコードのみ取得
        curRecGentouRuikei CURSOR FOR
            SELECT SUM(Z01.GENSAI_KNGK) AS GENSAI_KNGK
              FROM GENSAI_RIREKI Z01
             WHERE Z01.ITAKU_KAISHA_CD = l_initakukaishacd
               AND Z01.MGR_CD = l_inmgrcd
               AND Z01.SHOKAN_YMD <= l_indate
               AND Z01.SHOKAN_KBN IN (GENTO_MANKI_SHOKAN,
                                      GENTO_TEIGAKU_SHOKAN,
                                      GENTO_KAIIRE_SHOKYAKU,
                                      GENTO_KURIAGE_SHOKAN,
                                      GENTO_PUT_OPTION,
                                      GENTO_YOYAKU_KOUSHI)
               AND Z01.YOJITSU_FLG = '1' -- 予定実績フラグ=実績
               AND Z01.SHORI_KBN = '1' -- 処理区分=承認済
             GROUP BY Z01.ITAKU_KAISHA_CD, Z01.MGR_CD;
        --E_差押さえの累計金額
        curRecOsaeRuikei CURSOR FOR
            SELECT K04.OSAESETTEI_YMD,
                   K04.OSAE_KBN,
                   K04.OSAE_SETTEI_KNGK
              FROM SASHIOSAE K04
             WHERE K04.ITAKU_KAISHA_CD = l_initakukaishacd
               AND K04.MGR_CD = l_inmgrcd
               AND K04.OSAESETTEI_YMD <= l_indate
               AND K04.SHORI_KBN = '1';
        --振替債総額取得（特例社債（定時償還）用）
        curRecTeijiGensai CURSOR FOR
            SELECT Z01.GENSAI_KNGK / Z01.FACTOR AS TEIJI_GENSAI_KNGK
              FROM GENSAI_RIREKI Z01
             WHERE Z01.ITAKU_KAISHA_CD = l_initakukaishacd
               AND Z01.MGR_CD = l_inmgrcd
               AND Z01.SHOKAN_KBN = '01'
               AND Z01.SHOKAN_YMD = l_min_frk_iko_date
               AND Z01.YOJITSU_FLG = '1' -- 予定実績フラグ=実績
               AND Z01.SHORI_KBN = '1'; -- 処理区分=承認済
        --買入、プットの名目減債額取得（特例社債（定時償還）用）
        curRecMeimokuGensaiT CURSOR FOR
            SELECT SUM(MG3.MUNIT_GENSAI_KNGK / MG3.FACTOR) AS MEIMOKU_GENSAI_KNGK
              FROM MGR_SHOKIJ MG3
             WHERE MG3.ITAKU_KAISHA_CD = l_initakukaishacd
               AND MG3.MGR_CD = l_inmgrcd
               AND MG3.SHOKAN_KBN IN (KAIIRE_SHOKYAKU, PUT_OPTION)
               AND MG3.SHOKAN_YMD <= l_indate
             GROUP BY MG3.ITAKU_KAISHA_CD, MG3.MGR_CD;
        --買入、プット、予約権行使の名目減債額取得（新発債用）
        curRecMeimokuGensaiS CURSOR FOR
            SELECT MG3.SHOKAN_YMD,
                   MG3.SHOKAN_KBN,
                   MG3.MUNIT_GENSAI_KNGK
              FROM MGR_SHOKIJ MG3
             WHERE MG3.ITAKU_KAISHA_CD = l_initakukaishacd
               AND MG3.MGR_CD = l_inmgrcd
               AND MG3.SHOKAN_YMD <= l_indate
               AND MG3.SHOKAN_KBN IN (KAIIRE_SHOKYAKU,
                                      PUT_OPTION,
                                      YOYAKU_KOUSHI);
        --J_自行引受残高
        curRecHkukZndk CURSOR FOR
            SELECT coalesce(MG5.HKUK_BUNTAN_KNGK, 0) - coalesce(Z01SUM.SHOKAN_KNGK_JIKO, 0) AS HKUK_ZNDK
              FROM mgr_hikiuke mg5
LEFT OUTER JOIN (SELECT Z01.ITAKU_KAISHA_CD, Z01.MGR_CD, SUM(Z01.SHOKAN_KNGK_JIKO) AS SHOKAN_KNGK_JIKO
                      FROM GENSAI_RIREKI Z01
                     WHERE Z01.ITAKU_KAISHA_CD = l_initakukaishacd
                       AND Z01.MGR_CD = l_inmgrcd
                       AND Z01.SHOKAN_YMD <= l_indate
                     GROUP BY Z01.ITAKU_KAISHA_CD, Z01.MGR_CD) z01sum ON (MG5.ITAKU_KAISHA_CD = Z01SUM.ITAKU_KAISHA_CD AND MG5.MGR_CD = Z01SUM.MGR_CD)
WHERE MG5.ITAKU_KAISHA_CD = l_initakukaishacd AND MG5.MGR_CD = l_inmgrcd   AND MG5.FINANCIAL_SECURITIES_KBN = '0' --金融機関区分:[0]銀行
  AND MG5.BANK_CD = (SELECT OWN_BANK_CD FROM VJIKO_ITAKU WHERE KAIIN_ID = l_initakukaishacd);
    /*==============================================================================*/

    /*  メイン処理 																	*/

    /*==============================================================================*/

BEGIN

        -- 特例社債フラグ、償還方法、債券種類、利付割引区分取得
        l_tokurei_flg := NULL;
        l_shokan_method := NULL;
        l_saiken_shurui := NULL;
        l_ritsuke_waribiki_kbn := NULL;
        l_isin_cd := NULL;
        BEGIN
            SELECT MG1.TOKUREI_SHASAI_FLG,
                   MG1.SHOKAN_METHOD_CD,
                   MG1.SAIKEN_SHURUI,
                   MG1.RITSUKE_WARIBIKI_KBN,
                   MG1.ISIN_CD
              INTO STRICT l_tokurei_flg,
                   l_shokan_method,
                   l_saiken_shurui,
                   l_ritsuke_waribiki_kbn,
                   l_isin_cd
              FROM MGR_KIHON MG1
             WHERE MG1.ITAKU_KAISHA_CD = l_initakukaishacd
               AND MG1.MGR_CD = l_inmgrcd;
        EXCEPTION
            WHEN OTHERS THEN
                RETURN NULL;
        END;


        IF l_tokurei_flg = TOKUREI_SHASAI THEN
            temp_rec := pkipazndk.getTokureiKjndtKbn(l_initakukaishacd, l_inmgrcd, l_indate);

            l_tokurei_kjndt_kbn := temp_rec.extra_param;
            l_min_frk_iko_date := temp_rec.l_outFuriYmd;
        END IF;


        /*****基準残高算出に必要な値の取得*****/

        --A_振替債移行分の累計金額(=振替債の総額)
        IF l_tokurei_flg = TOKUREI_SHASAI THEN
            --特例社債の場合、減債履歴より「現登債から振替債の異動」かつ
            --承認済のレコードの減債金額合計を取得する
            FOR recGensai IN curRecGensai LOOP
                l_furikae_sogaku := recGensai.GENSAI_KNGK;
            END LOOP;
        ELSIF l_tokurei_flg = NOT_TOKUREI_SHASAI THEN
            --特例社債でない場合、銘柄_基本より「社債の総額」を取得する
            BEGIN
                SELECT MG1.SHASAI_TOTAL
                  INTO STRICT l_furikae_sogaku
                  FROM MGR_KIHON MG1
                 WHERE MG1.ITAKU_KAISHA_CD = l_initakukaishacd
                   AND MG1.MGR_CD = l_inmgrcd
                   AND MG1.HAKKO_YMD <= l_indate;
            EXCEPTION
                WHEN OTHERS THEN
                    -- 発行日以前の場合等、社債の総額を取得できない場合は 0円をセット
                    l_furikae_sogaku := 0;
            END;
        END IF;


        --B_振替債分の減債金額累計
        FOR recFuriRuikei IN curRecFuriRuikei LOOP
            l_furikae_gensai_ruikei := recFuriRuikei.MUNIT_GENSAI_KNGK;
        END LOOP;
        --C_現登債分の減債金額累計
        FOR recGentouRuikei IN curRecGentouRuikei LOOP
            l_gentou_gensai_ruikei := recGentouRuikei.GENSAI_KNGK;
        END LOOP;


        --H_実質残高( = A_振替債の総額 - B_振替債分の減債金額累計)
        l_jissitsu_zndk := pkipazndk.getJissitsuZndk_H(l_tokurei_flg, l_tokurei_kjndt_kbn, l_furikae_sogaku, l_furikae_gensai_ruikei, TOKUREI_SHASAI);
        --I_実質残高(現登債分)
        IF l_inrealvalue IN (83, 93) THEN
            l_jissitsu_zndk_gentou := pkipazndk.getJissitsuZndk_I(l_initakukaishacd, l_inmgrcd, l_indate, l_furikae_sogaku, l_gentou_gensai_ruikei, gento_zndk);
        END IF;


        -- ↓** 2005/06/02 ファクター取得を関数化****************************↓
        --D_基準日時点でのファクター
        l_kijunbi_factor := pkipazndk.getFactor(l_initakukaishacd, l_inmgrcd, l_indate, l_jissitsu_zndk, l_tokurei_flg, l_tokurei_kjndt_kbn, TOKUREI_SHASAI);

        -- ↑** 2005/06/02 ファクター取得を関数化****************************↑
		--E_差押さえの累計金額


		IF l_inrealvalue IN (2, 4, 7, 8) THEN
			IF l_tokurei_flg = TOKUREI_SHASAI AND l_tokurei_kjndt_kbn = 1 THEN
				l_sashiosae_ruikei := 0;
			ELSE
				FOR recOsaeRuikei IN curRecOsaeRuikei LOOP
					l_sashiosae_date		:= recOsaeRuikei.OSAESETTEI_YMD;
					l_sashiosae_kbn			:= recOsaeRuikei.OSAE_KBN;
					l_sashiosae_settei_kngk	:= recOsaeRuikei.OSAE_SETTEI_KNGK;
					IF l_sashiosae_kbn = '1' THEN
						-- 差押区分が1:差押設定の場合は差押設定金額を加える
						l_sashiosae_ruikei := l_sashiosae_ruikei + l_sashiosae_settei_kngk;
					ELSIF l_sashiosae_kbn = '2' THEN
						-- 差押区分が2:差押解除の場合は差押設定金額を引く
						l_sashiosae_ruikei := l_sashiosae_ruikei - l_sashiosae_settei_kngk;
					END IF;
				END LOOP;
				IF l_inrealvalue = 8 THEN
					-- 差押残高累計算出【名目】（差押残高累計算出【名目】）
					l_sashiosae_ruikei := l_sashiosae_ruikei;
				ELSE
					-- 差押残高累計算出【実質】（差押残高累計算出【名目】* 基準日時点ファクター）
					l_sashiosae_ruikei := l_sashiosae_ruikei * l_kijunbi_factor;
				END IF;
			END IF;
		END IF;


        --F_基準残高(名目残高)の算出
        IF l_inrealvalue IN (1, 2, 4) THEN
            -- 特例社債銘柄入力時
            IF l_tokurei_flg = TOKUREI_SHASAI THEN
                -- 満期一括 OR 永久債
                IF l_shokan_method IN ('1', '9') THEN
                    -- 基準日が振替移行日より前の場合、名目残高'0'
                    IF l_tokurei_kjndt_kbn = 1 THEN
                        l_kijun_meimoku_zndk := 0;
                    ELSE
                        l_jissitsu_zndk_gentou := pkipazndk.getJissitsuZndk_I(l_initakukaishacd,
                                                                    l_inmgrcd,
                                                                    l_indate,
                                                                    l_furikae_sogaku,
                                                                    l_gentou_gensai_ruikei,
                                                                    gento_zndk);
                        l_kijun_meimoku_zndk   := l_jissitsu_zndk + l_jissitsu_zndk_gentou;
                    END IF;
                    -- 定時償還 AND 入力基準日≧ZO1.基準日
                ELSIF l_shokan_method = '2' AND l_tokurei_kjndt_kbn = 2 THEN
                    IF l_jissitsu_zndk = 0 THEN
                        -- 実質残高が0の場合（満期の場合）、名目残高に0をセット
                        l_kijun_meimoku_zndk := 0;
                    ELSE
                        --特例社債（定時償還）の振替債総額取得
                        FOR recTeijiGensai IN curRecTeijiGensai LOOP
                            l_furikae_sogaku := recTeijiGensai.TEIJI_GENSAI_KNGK;
                        END LOOP;
                        --買入、プットの名目減債額取得
                        FOR recMeimokuGensaiT IN curRecMeimokuGensaiT LOOP
                            l_buf_gensai_total := recMeimokuGensaiT.MEIMOKU_GENSAI_KNGK;
                        END LOOP;
                        --基準残高(名目残高) = A_振替債の総額 - (減債金額/ファクター)の累計
                        l_kijun_meimoku_zndk := l_furikae_sogaku - l_buf_gensai_total;
                    END IF;
                ELSE
                    l_kijun_meimoku_zndk := 0;
                END IF;
                -- 新発債の場合
            ELSIF l_tokurei_flg = NOT_TOKUREI_SHASAI THEN
                IF l_jissitsu_zndk = 0 THEN
                    -- 実質残高が0の場合（満期の場合）、名目残高に0をセット
                    l_kijun_meimoku_zndk := 0;
                ELSE
                    --買入、プット、予約権行使の名目減債額取得
                    FOR recMeimokuGensaiS IN curRecMeimokuGensaiS LOOP
                        l_buf_date        := recMeimokuGensaiS.SHOKAN_YMD;
                        l_buf_shokankbn   := recMeimokuGensaiS.SHOKAN_KBN;
                        l_buf_gensai_kngk := recMeimokuGensaiS.MUNIT_GENSAI_KNGK;
                        l_buf_factor      := pkIpaZndk.getFactor(l_initakukaishacd, l_inmgrcd, l_buf_date, l_buf_shokankbn, l_tokurei_flg, l_tokurei_kjndt_kbn, TOKUREI_SHASAI); -- 基準日時点でのファクター
                        --(銘柄_償還回次.元利減債金額 / 基準日時点でのファクター)を減債金額の件数分加算する
                        IF l_buf_factor <> 0 THEN
                            -- 0除算対策 (ファクターが0の時は0になるので加算しない)
                            l_buf_gensai_total := l_buf_gensai_total + (l_buf_gensai_kngk / l_buf_factor);
                        END IF;

                        IF length(pkcharacter.numeric_to_char(l_kijunbi_factor)) > 12 THEN
                            RETURN('FACTOR_ERROR');
                        END IF;
                    END LOOP;
                    --基準残高(名目残高) = A_振替債の総額 - (減債金額/ファクター)の累計
                    l_kijun_meimoku_zndk := l_furikae_sogaku - l_buf_gensai_total;
                END IF;
            END IF;
        END IF;
        --元利払対象実質残高 = H_実質残高 - E 差押さえの累計金額
        IF l_inrealvalue IN (2, 4) THEN
            IF (l_tokurei_flg = TOKUREI_SHASAI AND l_tokurei_kjndt_kbn IN (1, 3)) OR l_kijun_meimoku_zndk = 0 THEN
                -- 特例社債銘柄かつ基準日フラグ＝1or3の場合、常に「0」
                l_ganribarai_zndk_j := 0;
            ELSE
                l_ganribarai_zndk_j := l_jissitsu_zndk - l_sashiosae_ruikei;
               -- ＣＢ銘柄でかつ割引債の場合、以下の処理を行う。
                -- 割引債のプット行使に係る繰上償還の場合には、元利払対象残高にプット行使数量の総額をセットする
                IF l_saiken_shurui IN ('80', '89') AND l_ritsuke_waribiki_kbn = 'Z' THEN
                    -- 直近の元利払の償還事由がプットである場合に、プット行使数量（償還金額）で元利払対象実質残高を上書きする
                    -- 業務日付を取得
                    l_gyomu_ymd := pkDate.getGyomuYmd();
                    l_ed_putkoshikikan_ymd := NULL;

                    BEGIN
                        SELECT MG3.MUNIT_GENSAI_KNGK,
                               MG3.ED_PUTKOSHIKIKAN_YMD,
                               MG3.SHOKAN_YMD
                          INTO STRICT l_munit_gensai_kngk,
                               l_ed_putkoshikikan_ymd,
                               l_shokan_ymd
                          FROM MGR_SHOKIJ MG3
                         WHERE MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd
                           AND MG3.MGR_CD = l_inMgrCd
                           AND MG3.SHOKAN_YMD = (SELECT trim(both MIN(MG3_1.SHOKAN_YMD))
                                                   FROM MGR_SHOKIJ MG3_1
                                                  WHERE MG3_1.ITAKU_KAISHA_CD = l_initakukaishacd
                                                    AND MG3_1.MGR_CD = l_inmgrcd
                                                    AND MG3_1.SHOKAN_YMD > l_indate
                                                    AND MG3_1.SHOKAN_KBN IN ('10', '40', '50') )
                           AND MG3.SHOKAN_KBN = '50';

                        -- 業務日付>行使期間終了日の場合、プット行使数量（償還金額）で元利払対象実質残高を上書きする
                        -- 業務日付<=行使期間終了日の場合、通知情報テーブルのプット行使数量合計で元利払対象実質残高を上書きする
                        IF l_gyomu_ymd <= l_ed_putkoshikikan_ymd THEN
                            BEGIN
                                SELECT coalesce(SUM(Z02.KNGK), 0) -- 償還金額
                                  INTO STRICT l_tsuchi_shokan_kngk
                                  FROM TSUCHIJOHO Z02
                                 WHERE Z02.ITAKU_KAISHA_CD = l_initakukaishacd
                                   AND Z02.FILE_SHUBETSU_CD = '10' -- 償還口記録情報通知（コード種別：168）
                                   AND Z02.ISIN_CD = l_isin_cd
                                   AND Z02.KESSAI_YMD = l_shokan_ymd;
                            EXCEPTION
                                WHEN OTHERS THEN
				    --通知情報にデータが無ければ0を設定
                                    l_tsuchi_shokan_kngk := 0;
                            END;
			    --通知情報の合計金額を設定
                            l_munit_gensai_kngk := l_tsuchi_shokan_kngk;
                        END IF;

                    EXCEPTION
                        WHEN OTHERS THEN
                            -- データ取得できなかった場合、通常の元利払対象残高を設定
                            l_munit_gensai_kngk := l_ganribarai_zndk_j;
                    END;
                    --最後に個々の処理で求めた元利払対象残高（償還金額）を元の変数へセットする
                    l_ganribarai_zndk_j := l_munit_gensai_kngk;
                END IF;
            END IF;

            --G_元利払対象残高 = 元利払対象実質残高 / D_基準日時点でのファクター
            IF l_kijunbi_factor = 0 THEN
                l_ganribarai_zndk := 0;
            ELSE
                l_ganribarai_zndk := l_ganribarai_zndk_j / l_kijunbi_factor;
            END IF;
        END IF;
        --J_自行引受残高
        IF l_inrealvalue = 6 THEN
            -- 特例社債銘柄入力時、常に「0」
            IF l_tokurei_flg = TOKUREI_SHASAI THEN
                l_jiko_hkuk_zndk := 0;
            ELSE
                FOR recHkukZndk IN curRecHkukZndk LOOP
                    l_jiko_hkuk_zndk := recHkukZndk.HKUK_ZNDK;
                END LOOP;
            END IF;
        END IF;
        /*****「IN_実数」により戻り値をセット*****/

        CASE l_inrealvalue
            WHEN 1 THEN
                -- F_基準残高(名目残高)
                l_retzndk := l_kijun_meimoku_zndk;
            WHEN 2 THEN
                -- G_元利払対象残高
                l_retzndk := l_ganribarai_zndk;
            WHEN 3 THEN
                -- H_実質残高
                l_retzndk := l_jissitsu_zndk;
            WHEN 4 THEN
                -- 元利払対象実質残高
                l_retzndk := l_ganribarai_zndk_j;
            WHEN 5 THEN
                -- D_基準日時点でのファクター
                l_retzndk := l_kijunbi_factor;
            WHEN 6 THEN
                -- J_自行引受残高
                l_retzndk := l_jiko_hkuk_zndk;
            WHEN 7 THEN
                -- E_差押さえの累計金額（実質）
                l_retzndk := l_sashiosae_ruikei;
            WHEN 8 THEN
                -- E_差押さえの累計金額（名目）
                l_retzndk := l_sashiosae_ruikei;
            WHEN 83 THEN
                -- I_実質残高(現登債分)
                l_retzndk := l_jissitsu_zndk_gentou;
            WHEN 93 THEN
                -- 実質残高(銘柄全体)( = H_実質残高 + I_実質残高(現登債分))
                l_retzndk := l_jissitsu_zndk + l_jissitsu_zndk_gentou;
            ELSE
                RETURN('JISSU_ERROR');
        END CASE;


        RETURN l_retzndk::varchar;
    END;
$body$
LANGUAGE PLPGSQL
 ;

   /**
    *
    * @author 磯田　浩靖
    *
    * 銘柄の残高取得<br>
    * パラメータで指定した委託会社、銘柄コード、基準日、償還区分、実数に
    * 対応した基準残高を取得する。（同一期日考慮）
    *
    * 【注意】
    * 振替債移行日(償還区分01)と同一日の償還区分の名目残高、実質残高、ファクター(実数11,13,15)を求める場合、
    * この関数を使用しないでください。
    *
    * 実数が以下のとき、対応した値を取得する。
    *   1　 = 名目残高（今回の回次を含まない）名目残高は「振替債分の名目残高」を返す
    *   3　 = 実質残高（今回の回次を含まない）
    *   5　 = ファクター（今回の回次を含まない）
    *   11  = 名目残高（今回の回次を含む）名目残高は「振替債分の名目残高」を返す
    *   13  = 実質残高（今回の回次を含む）
    *   15  = ファクター（今回の回次を含む）
    *
    * @param l_initakukaishacd    委託会社コード
    * @param l_inmgrcd            銘柄コード
    * @param l_indate             基準日
    * @param l_inShokanKbn        償還区分
    * @param l_inrealvalue        実数
    * @return  l_outValue          取得した値
    */
CREATE OR REPLACE FUNCTION pkipazndk.getkjnzndk (
    l_inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE,
    l_inMgrCd MGR_SHOKIJ.MGR_CD%TYPE,
    l_inDate MGR_SHOKIJ.SHOKAN_YMD%TYPE,
    l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE,
    l_inRealValue bigint
) RETURNS varchar AS $body$
DECLARE

    /*==============================================================================*/

    /*          定数定義                          */

    /*==============================================================================*/

        SP_ID               CONSTANT varchar(50) := 'pkIpaZndk.getKjnZndk()';
        -- 実数
        JISSU_MEIMOKU_ZNDK      CONSTANT smallint := 1;        -- 名目残高取得（今回の回次を含まない）
        JISSU_MEIMOKU_ZNDK_C    CONSTANT smallint := 11;       -- 名目残高取得（今回の回次を含む）
        JISSU_JISSITSU_ZNDK     CONSTANT smallint := 3;        -- 実質残高取得（今回の回次を含まない）
        JISSU_JISSITSU_ZNDK_C   CONSTANT smallint := 13;       -- 実質残高取得（今回の回次を含む）
        JISSU_FACTOR            CONSTANT smallint := 5;        -- ファクター取得（今回の回次を含まない）
        JISSU_FACTOR_C          CONSTANT smallint := 15;       -- ファクター取得（今回の回次を含む）
    /*==============================================================================*/

    /*          変数定義                          */

    /*==============================================================================*/

        l_outValue        varchar(100); -- 取得した値
BEGIN

        CASE l_inRealValue
            WHEN JISSU_MEIMOKU_ZNDK THEN
                l_outValue := pkipazndk.getmeimokuzndk(l_inItakuKaishaCd,l_inMgrCd,l_inDate,l_inShokanKbn);
            WHEN JISSU_MEIMOKU_ZNDK_C THEN
                l_outValue := pkipazndk.getmeimokuzndkcurrentcontain(l_inItakuKaishaCd,l_inMgrCd,l_inDate,l_inShokanKbn);
            WHEN JISSU_JISSITSU_ZNDK THEN
                l_outValue := pkipazndk.getjissitsuzndk(l_inItakuKaishaCd,l_inMgrCd,l_inDate,l_inShokanKbn);
            WHEN JISSU_JISSITSU_ZNDK_C THEN
                l_outValue := pkipazndk.getjissitsuzndkcurrentcontain(l_inItakuKaishaCd,l_inMgrCd,l_inDate,l_inShokanKbn);
            WHEN JISSU_FACTOR THEN
                l_outValue := pkipazndk.getfactor(l_inItakuKaishaCd,l_inMgrCd,l_inDate,l_inShokanKbn);
            WHEN JISSU_FACTOR_C THEN
                l_outValue := pkipazndk.getfactorcurrentcontain(l_inItakuKaishaCd,l_inMgrCd,l_inDate,l_inShokanKbn);
            ELSE
                l_outValue := NULL;
        END CASE;


        RETURN l_outValue;

    /*====================================================================*
                異常終了 出口
     *====================================================================*/
    EXCEPTION
	    WHEN OTHERS THEN
    		CALL pkLog.fatal('ECM321', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
            RETURN NULL;
    END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;

	/**
	 *
	 * @author 八巻　真司
	 *
	 * 銘柄の残高取得<br>
	 * パラメータで指定した委託会社、銘柄コード、基準日、償還区分、実数に
	 * 対応した基準残高を取得する。（同一期日考慮）
	 *
	 * @param l_inItakuKaishaCd		委託会社コード
	 * @param l_inMgrCd				銘柄コード
	 * @param l_inDate				基準日
	 * @return  l_retFactor			取得した基準日残高
	 */
CREATE OR REPLACE FUNCTION pkipazndk.getikofactor (l_inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE, l_inMgrCd MGR_SHOKIJ.MGR_CD%TYPE, l_inDate MGR_SHOKIJ.SHOKAN_YMD%TYPE) RETURNS numeric AS $body$
DECLARE

		l_factor		numeric := 0;	-- ファクター
		l_kjndtKbn		int := 0;	-- 特例社債入力基準日区分
		l_furiYmd		varchar(8);		-- 振替移行日
        temp_rec        record;
BEGIN

		temp_rec := pkipazndk.gettokureikjndtkbn(l_inItakuKaishaCd, l_inMgrCd, l_inDate);

        l_kjndtKbn := temp_rec.extra_param;
        l_furiYmd := temp_rec.l_outFuriYmd;

		IF (l_kjndtKbn = 2) THEN
			SELECT	Z01.FACTOR
			INTO STRICT	l_factor
			FROM	GENSAI_RIREKI Z01
			WHERE	Z01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND		Z01.MGR_CD = l_inMgrCd
			AND		Z01.SHOKAN_KBN = '01'
			AND		Z01.SHOKAN_YMD <= l_furiYmd
			AND		Z01.SHORI_KBN = '1'
			AND		Z01.YOJITSU_FLG = '1';
		END IF;

		RETURN l_factor;

	EXCEPTION
		WHEN no_data_found THEN
			RETURN l_factor;
	END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;
