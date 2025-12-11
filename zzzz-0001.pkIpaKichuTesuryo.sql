CREATE SCHEMA IF NOT EXISTS pkipakichutesuryo;

drop function if exists pkipakichutesuryo.updateKichuTesuryoTbl_Sai;
drop function if exists pkipakichutesuryo.updateKichuTesuryoTbl;
drop function if exists pkipakichutesuryo.getmonthfromto_wakachi;
drop function if exists pkipakichutesuryo.calctesuryo_wakachi;
drop function if exists pkipakichutesuryo.getzndk;
drop function if exists pkipakichutesuryo.calctesuryo;
drop function if exists pkipakichutesuryo.calcbunpaitesuryo;
drop function if exists pkipakichutesuryo.calcbunpaitesuryo_wakachi;
drop function if exists pkipakichutesuryo.inskichutesuryoseikyuout;

drop type if exists pkipakichutesuryo.vcr_array;

drop type if exists pkipakichutesuryo.chr_array;

drop type if exists pkipakichutesuryo.ch6_array;

drop type if exists pkipakichutesuryo.ch4_array;

drop type if exists pkipakichutesuryo.ch3_array;

drop type if exists pkipakichutesuryo.ch2_array;

drop type if exists pkipakichutesuryo.ch1_array;

drop type if exists pkipakichutesuryo.num_array;

drop type if exists pkipakichutesuryo.rectype;

CREATE TYPE pkipakichutesuryo.vcr_array AS (vcr_array varchar(20)[]);

CREATE TYPE pkipakichutesuryo.chr_array AS (chr_array char(8)[]);

CREATE TYPE pkipakichutesuryo.ch6_array AS (ch6_array char(6)[]);

CREATE TYPE pkipakichutesuryo.ch4_array AS (ch4_array char(4)[]);

CREATE TYPE pkipakichutesuryo.ch3_array AS (ch3_array char(3)[]);

CREATE TYPE pkipakichutesuryo.ch2_array AS (ch2_array char(2)[]);

CREATE TYPE pkipakichutesuryo.ch1_array AS (ch1_array char(1)[]);

CREATE TYPE pkipakichutesuryo.num_array AS (num_array numeric[]);

CREATE TYPE pkipakichutesuryo.rectype AS (
    rItakuKaishaCd			varchar(4),
    rMgrCd					varchar(13),
    rHakkoTsukaCd			varchar(3),
    rChokyuYyyymm			CHAR(8),
    rKozaTenCd				varchar(4),
    rKozaTenCifcd			varchar(11),
    rChokyuDd				INTEGER,
    rKozaFuriKbn			CHAR(2),
    rIsinCd					CHAR(12),
    rTesuShuruiCd			CHAR(2),
    rChokyuKjt				char(8),
    rChokyuYmd				char(8)
);


create or replace function pkipakichutesuryo.c_SHONIN() returns char as $$ select char '1' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE; --	処理区分（承認）
create or replace function pkipakichutesuryo.c_NOT_MASSHO() returns char as $$ select char '0' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE; --	抹消フラグ（未抹消）
create or replace function pkipakichutesuryo.c_BUNPAI_ICHIRAN() returns char(11) as $$ select char(11) 'IP030005811' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE; --	帳票ID
create or replace function pkipakichutesuryo.c_BUNPAI_SEIKYU() returns char(11) as $$ select char(11) 'IP030005911' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE; --	帳票ID

CREATE OR REPLACE FUNCTION pkipakichutesuryo.getcode (l_insyubetsu CHAR ,l_incdvalue CHAR) RETURNS varchar AS $$
DECLARE

		l_tmpret varchar(20)	:= NULL;

BEGIN
			SELECT CODE_NM INTO STRICT l_tmpret
				FROM SCODE
			WHERE CODE_SHUBETSU = l_insyubetsu
			AND   CODE_VALUE    = l_incdvalue;
			RETURN l_tmpret;
		END;

$$ LANGUAGE PLPGSQL ;

	/*==============================================================================

	手数料計算結果テーブルへの更新処理を行うかを判断する
	return 1:更新しない　0:更新する
	==============================================================================*/

CREATE OR REPLACE FUNCTION pkipakichutesuryo.isupdate (l_inItakuKaishaCd VARCHAR ,l_inMgrCd VARCHAR,l_inDate VARCHAR) RETURNS integer AS $$
DECLARE


	wk_tokureiShasaiFlg			MGR_KIHON.TOKUREI_SHASAI_FLG%TYPE;
	wk_shokanYmd				GENSAI_RIREKI.SHOKAN_YMD%TYPE;


BEGIN

	/* 特例社債フラグ取得 */

	SELECT	MG1.TOKUREI_SHASAI_FLG
	INTO STRICT	wk_tokureiShasaiFlg
	FROM	MGR_KIHON MG1
	WHERE	MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
	AND		MG1.MGR_CD          = l_inMgrCd;

	/* 償還日取得 */

	SELECT	coalesce(nullif(trim(both MIN(Z01.SHOKAN_YMD)), ''),'99999999')
	INTO STRICT	wk_shokanYmd
	FROM	Gensai_Rireki Z01
	WHERE	Z01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
	AND		Z01.MGR_CD          = l_inMgrCd
	AND		Z01.SHOKAN_KBN = '01';

	/* 特例社債でかつ徴求日が償還日(振替移行時)より小さい場合、更新処理をしない */

	IF  wk_tokureiShasaiFlg = 'Y' AND wk_shokanYmd > l_inDate THEN
		RETURN 1;
	ELSE
		RETURN 0;
	END IF;
END $$ LANGUAGE PLPGSQL;

/**
	 * システム設定分と個別設定分の請求書作成データを取得するための
	 * カーソル文を作成するファンクション
	 *
	 * @return SQL文
	 */
	CREATE OR REPLACE FUNCTION pkipakichutesuryo.createCursor(
							l_inkjnfrom IN CHAR ,              -- 基準日From
							l_inkjnto IN CHAR ,                -- 基準日To
							l_initakukaishacd IN VARCHAR ,    -- 委託会社CD
							l_inhktcd IN CHAR ,                -- 発行体CD
							l_inkozatencd IN VARCHAR ,        -- 口座店CD
							l_inkozatencifcd IN VARCHAR ,     -- 口座店CIFCD
							l_inmgrcd IN CHAR ,                -- 銘柄CD
							l_inisincd IN CHAR,                -- ISINCD
							l_inrealbatchkbn IN CHAR   DEFAULT '0' -- リアルバッチ区分
							)
	RETURNS VARCHAR AS $$
	DECLARE
	/*==============================================================================*/
	/*					変数定義													*/
	/*==============================================================================*/
		rCursor VARCHAR(10000);
		gGyomuYmd               SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;
		gGyomuYmdPlusOne        SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;
		gConstShonin            CHAR(1);
		gConstNotMassho         CHAR(1);
	/*==============================================================================*/
	/*	メイン処理	*/
	/*==============================================================================*/
	BEGIN

		-- 業務日付取得
		gGyomuYmd := pkDate.getGyomuYmd();
		-- 業務日付取得 + 1営業日
		gGyomuYmdPlusOne := pkDate.getPlusDateBusiness(gGyomuYmd, 1);
		
		-- Get constant values before building SQL string
		gConstShonin := pkipakknido.c_SHONIN();
		gConstNotMassho := pkipakknido.c_NOT_MASSHO();

		--変数を初期化
		 -- カーソルを動的SQL文として定義する
		rCursor := 'SELECT ';
		rCursor := rCursor || ' T1.ITAKU_KAISHA_CD as ITAKU_KAISHA_CD, ';
		rCursor := rCursor || ' T1.MGR_CD as MGR_CD, ';
		rCursor := rCursor || ' T1.HAKKO_TSUKA_CD as HAKKO_TSUKA_CD, ';
		rCursor := rCursor || ' T1.CHOKYU_YYYYMM as CHOKYU_YYYYMM, ';
		rCursor := rCursor || ' T1.KOZA_TEN_CD as KOZA_TEN_CD, ';
		rCursor := rCursor || ' T1.KOZA_TEN_CIFCD as KOZA_TEN_CIFCD, ';
		rCursor := rCursor || ' T1.CHOKYU_DD as CHOKYU_DD, ';
		rCursor := rCursor || ' T1.KOZA_FURI_KBN as KOZA_FURI_KBN, ';
		rCursor := rCursor || ' T1.ISIN_CD as ISIN_CD, ';
		rCursor := rCursor || ' T1.TESU_SHURUI_CD as TESU_SHURUI_CD, ';
		rCursor := rCursor || ' T1.CHOKYU_KJT as CHOKYU_KJT, ';
		rCursor := rCursor || ' T1.CHOKYU_YMD as CHOKYU_YMD';
		rCursor := rCursor || ' FROM( ';
		rCursor := rCursor || ' SELECT ';
		rCursor := rCursor || ' MG0.ITAKU_KAISHA_CD, ';
		rCursor := rCursor || ' MG0.MGR_CD, ';
		rCursor := rCursor || ' MG1.HAKKO_TSUKA_CD, ';
		rCursor := rCursor || ' SUBSTR(MG4.CHOKYU_YMD,1,6) AS CHOKYU_YYYYMM, ';
		rCursor := rCursor || ' M01.KOZA_TEN_CD, ';
		rCursor := rCursor || ' M01.KOZA_TEN_CIFCD, ';
		rCursor := rCursor || ' SUBSTR(MG4.CHOKYU_YMD,7,2) AS CHOKYU_DD, ';
		rCursor := rCursor || ' MG1.KOZA_FURI_KBN, ';
		rCursor := rCursor || ' MG1.ISIN_CD, ';
		-- 永久債、かつ併存銘柄請求出力区分が'1'、かつ特例債の場合で、
		-- 償還回次の最大償還日（存在しない場合はALL9)時点での残高がある場合は
		-- FULLSHOKAN_YMDをALL9に置き換える。
		rCursor := rCursor || ' CASE WHEN';
		rCursor := rCursor || ' MG1.FULLSHOKAN_KJT = ''99999999'' AND VJ1.HEIZON_SEIKYU_KBN = ''1'' AND';
		rCursor := rCursor || ' MG1.TOKUREI_SHASAI_FLG = ''Y'' AND ';
		rCursor := rCursor || ' pkIpaZndk.getKjnZndk(MG0.ITAKU_KAISHA_CD, MG0.MGR_CD,';
		rCursor := rCursor || ' COALESCE(MG3MAX.FULLSHOKAN_YMD, ''99999999''), 3)::INT > 0';
		rCursor := rCursor || ' THEN ''99999999''';
		rCursor := rCursor || ' ELSE COALESCE(MG3MAX.FULLSHOKAN_YMD, ''99999999'') END AS FULLSHOKAN_YMD, ';
		rCursor := rCursor || ' MG4.TESU_SHURUI_CD, ';
		rCursor := rCursor || ' MG4.CALC_PATTERN_CD, ';
		rCursor := rCursor || ' MG4.ST_CALC_YMD, ';
		rCursor := rCursor || ' MG4.ZNDK_KIJUN_YMD, ';
		rCursor := rCursor || ' MG4.CHOKYU_KJT, ';
		rCursor := rCursor || ' MG4.CHOKYU_YMD, ';
		rCursor := rCursor || ' VJ1.HEIZON_SEIKYU_KBN, ';
		rCursor := rCursor || ' MG1.TOKUREI_SHASAI_FLG ';
		rCursor := rCursor || ' FROM ';
		rCursor := rCursor || ' MGR_KIHON  MG1, ';
		rCursor := rCursor || ' MGR_TESKIJ MG4, ';
		rCursor := rCursor || ' VJIKO_ITAKU VJ1, ';
		rCursor := rCursor || ' MHAKKOTAI  M01, ';
		rCursor := rCursor || ' MGR_STS    MG0 left outer join ';
		rCursor := rCursor || ' (SELECT ITAKU_KAISHA_CD,MGR_CD,TRIM(MAX(SHOKAN_YMD)) AS FULLSHOKAN_YMD FROM MGR_SHOKIJ';
		rCursor := rCursor || '  GROUP BY ITAKU_KAISHA_CD,MGR_CD) MG3MAX ON ';	-- 銘柄の最終償還日
		rCursor := rCursor || ' MG0.ITAKU_KAISHA_CD =  MG3MAX.ITAKU_KAISHA_CD ';
		rCursor := rCursor || ' AND   MG0.MGR_CD          =  MG3MAX.MGR_CD ';
		rCursor := rCursor || ' WHERE MG0.ITAKU_KAISHA_CD =  MG1.ITAKU_KAISHA_CD ';
		rCursor := rCursor || ' AND   MG0.MGR_CD          =  MG1.MGR_CD ';
		rCursor := rCursor || ' AND   MG0.ITAKU_KAISHA_CD =  MG4.ITAKU_KAISHA_CD ';
		rCursor := rCursor || ' AND   MG0.MGR_CD          =  MG4.MGR_CD ';
		-- 永久債は基本的に償還回次がないため、外部結合にする。
		rCursor := rCursor || ' AND   MG1.ITAKU_KAISHA_CD =  M01.ITAKU_KAISHA_CD ';
		rCursor := rCursor || ' AND   MG1.HKT_CD          =  M01.HKT_CD ';
		rCursor := rCursor || ' AND   MG0.ITAKU_KAISHA_CD =  VJ1.KAIIN_ID ';
		rCursor := rCursor || ' AND   MG0.ITAKU_KAISHA_CD =  ''' || l_initakuKaishaCd || ''' ';
		rCursor := rCursor || ' AND   MG0.MGR_STAT_KBN    =  ''' || gConstShonin || ''' ';
		rCursor := rCursor || ' AND   MG0.MASSHO_FLG      =  ''' || gConstNotMassho || ''' ';
		rCursor := rCursor || ' AND   MG4.TESU_SHURUI_CD  IN (''11'', ''12'') ';
		rCursor := rCursor || ' AND   MG1.KK_KANYO_FLG !=  ''2'' ';
		rCursor := rCursor || ' AND   TRIM(MG1.ISIN_CD) IS NOT NULL ';

		IF l_inrealbatchkbn = PKIPACALCTESURYO.C_BATCH() THEN
			rCursor := rCursor || ' AND   MG4.BILL_OUT_YMD    =  '' '' ';  -- バッチ時のみ対象とする
		END IF;
		rCursor := rCursor || ' AND   MG4.CHOKYU_YMD BETWEEN ''' || l_inkjnFrom || ''' ';
		rCursor := rCursor || '                      AND     ''' || l_inkjnTo   || ''' ';
		IF TRIM(l_inhktcd)        IS NOT NULL THEN -- 発行体CD
			rCursor := rCursor || '	AND   MG1.HKT_CD          = ''' || l_inhktcd || ''' ';
		END IF;
		IF TRIM(l_inkozatencd)    IS NOT NULL THEN -- 口座店CD
			rCursor := rCursor || '	AND   M01.KOZA_TEN_CD	  = ''' || l_inkozatencd || ''' ';
		END IF;
		IF TRIM(l_inkozatencifcd) IS NOT NULL THEN -- 口座店CIFCD
			rCursor := rCursor || '	AND   M01.KOZA_TEN_CIFCD  = ''' || l_inkozatencifcd || ''' ';
		END IF;
		IF TRIM(l_inmgrcd)        IS NOT NULL THEN -- 銘柄CD
			rCursor := rCursor || '	AND   MG1.MGR_CD          = ''' || l_inmgrcd || ''' ';
		END IF;
		IF TRIM(l_inisincd)       IS NOT NULL THEN -- ISINCD
			rCursor := rCursor || '	AND   MG1.ISIN_CD         = ''' || l_inisincd || ''' ';
		END IF;

		IF l_inrealbatchkbn = PKIPACALCTESURYO.C_BATCH() THEN --バッチ時のみ下の処理を行う。
			rCursor := rCursor || ' UNION ';
			-- 銘柄個別設定分 '
			rCursor := rCursor || ' SELECT ';
			rCursor := rCursor || ' MG0.ITAKU_KAISHA_CD, ';
			rCursor := rCursor || ' MG0.MGR_CD, ';
			rCursor := rCursor || ' MG1.HAKKO_TSUKA_CD, ';
			rCursor := rCursor || ' SUBSTR(MG4.CHOKYU_YMD,1,6) AS CHOKYU_YYYYMM, ';
			rCursor := rCursor || ' M01.KOZA_TEN_CD, ';
			rCursor := rCursor || ' M01.KOZA_TEN_CIFCD, ';
			rCursor := rCursor || ' SUBSTR(MG4.CHOKYU_YMD,7,2) AS CHOKYU_DD, ';
			rCursor := rCursor || ' MG1.KOZA_FURI_KBN, ';
			rCursor := rCursor || ' MG1.ISIN_CD, ';
			-- 永久債、かつ併存銘柄請求出力区分が'1'、かつ特例債の場合で、
			-- 償還回次の最大償還日（存在しない場合はALL9)時点での残高がある場合は
			-- FULLSHOKAN_YMDをALL9に置き換える。
			rCursor := rCursor || ' CASE WHEN';
			rCursor := rCursor || ' MG1.FULLSHOKAN_KJT = ''99999999'' AND VJ1.HEIZON_SEIKYU_KBN = ''1'' AND';
			rCursor := rCursor || ' MG1.TOKUREI_SHASAI_FLG = ''Y'' AND ';
			rCursor := rCursor || ' pkIpaZndk.getKjnZndk(MG0.ITAKU_KAISHA_CD, MG0.MGR_CD,';
			rCursor := rCursor || ' COALESCE(MG3MAX.FULLSHOKAN_YMD, ''99999999''), 3)::INT > 0';
			rCursor := rCursor || ' THEN ''99999999''';
			rCursor := rCursor || ' ELSE COALESCE(MG3MAX.FULLSHOKAN_YMD, ''99999999'') END AS FULLSHOKAN_YMD, ';
			rCursor := rCursor || ' MG4.TESU_SHURUI_CD, ';
			rCursor := rCursor || ' MG4.CALC_PATTERN_CD, ';
			rCursor := rCursor || ' MG4.ST_CALC_YMD, ';
			rCursor := rCursor || ' MG4.ZNDK_KIJUN_YMD, ';
			rCursor := rCursor || ' MG4.CHOKYU_KJT, ';
			rCursor := rCursor || ' MG4.CHOKYU_YMD, ';
			rCursor := rCursor || ' VJ1.HEIZON_SEIKYU_KBN, ';
			rCursor := rCursor || ' MG1.TOKUREI_SHASAI_FLG ';
			rCursor := rCursor || ' FROM ';
			rCursor := rCursor || ' MGR_KIHON  MG1, ';
			rCursor := rCursor || ' MGR_TESKIJ MG4, ';
			rCursor := rCursor || ' VJIKO_ITAKU VJ1, ';
			rCursor := rCursor || ' MHAKKOTAI  M01, ';
			rCursor := rCursor || ' MGR_STS    MG0 left outer join ';
			rCursor := rCursor || ' (SELECT ITAKU_KAISHA_CD,MGR_CD,TRIM(MAX(SHOKAN_YMD)) AS FULLSHOKAN_YMD FROM MGR_SHOKIJ';
			rCursor := rCursor || '  GROUP BY ITAKU_KAISHA_CD,MGR_CD) MG3MAX ON ';	-- 銘柄の最終償還日
			rCursor := rCursor || '    MG0.ITAKU_KAISHA_CD =  MG3MAX.ITAKU_KAISHA_CD';
			rCursor := rCursor || ' AND   MG0.MGR_CD          =  MG3MAX.MGR_CD';
			rCursor := rCursor || ' WHERE MG0.ITAKU_KAISHA_CD =  MG1.ITAKU_KAISHA_CD ';
			rCursor := rCursor || ' AND MG0.MGR_CD =  MG1.MGR_CD ';
			rCursor := rCursor || ' AND	MG0.ITAKU_KAISHA_CD =  MG4.ITAKU_KAISHA_CD ';
			rCursor := rCursor || ' AND MG0.MGR_CD =  MG4.MGR_CD ';
			-- 永久債は基本的に償還回次がないため、外部結合にする。
			rCursor := rCursor || ' AND MG1.ITAKU_KAISHA_CD =  M01.ITAKU_KAISHA_CD ';
			rCursor := rCursor || ' AND MG1.HKT_CD =  M01.HKT_CD ';
			rCursor := rCursor || ' AND MG0.ITAKU_KAISHA_CD =  VJ1.KAIIN_ID ';
			rCursor := rCursor || ' AND MG0.ITAKU_KAISHA_CD =  ''' || l_initakuKaishaCd || ''' ';
			rCursor := rCursor || ' AND MG0.MGR_STAT_KBN    =  ''' || gConstShonin || ''' ';
			rCursor := rCursor || ' AND MG0.MASSHO_FLG      =  ''' || gConstNotMassho || ''' ';
			rCursor := rCursor || ' AND MG4.TESU_SHURUI_CD IN (''11'', ''12'') ';
			rCursor := rCursor || ' AND MG4.BILL_OUT_YMD = ''' || gGyomuYmdPlusOne || ''' ';
			rCursor := rCursor || ' AND MG1.KK_KANYO_FLG  !=  ''2'' ';
			rCursor := rCursor || ' AND TRIM(MG1.ISIN_CD) IS NOT NULL ';

			--	        rCursor := rCursor || ' AND MG1.JTK_KBN  IN (''1'', ''2'',''4'') ';			--受託区分は作表ＳＰの検索条件に含める(計算時は指定しない)
			IF TRIM(l_inhktcd)        IS NOT NULL THEN -- 発行体CD
				rCursor := rCursor || '	AND   MG1.HKT_CD          = ''' || l_inhktcd || ''' ';
			END IF;
			IF TRIM(l_inkozatencd)    IS NOT NULL THEN -- 口座店CD
				rCursor := rCursor || '	AND   M01.KOZA_TEN_CD	  = ''' || l_inkozatencd || ''' ';
			END IF;
			IF TRIM(l_inkozatencifcd) IS NOT NULL THEN -- 口座店CIFCD
				rCursor := rCursor || '	AND   M01.KOZA_TEN_CIFCD  = ''' || l_inkozatencifcd || ''' ';
			END IF;
			IF TRIM(l_inmgrcd)        IS NOT NULL THEN -- 銘柄CD
				rCursor := rCursor || '	AND   MG1.MGR_CD          = ''' || l_inmgrcd || ''' ';
			END IF;
			IF TRIM(l_inisincd)       IS NOT NULL THEN -- ISINCD
				rCursor := rCursor || '	AND   MG1.ISIN_CD         = ''' || l_inisincd || ''' ';
			END IF;
		END IF;   --バッチのみ上の処理を行う

		rCursor := rCursor || ' ) T1 ';

		/* 基準日時点の残高チェックおよび併存銘柄チェック */
		rCursor := rCursor || ' WHERE ';
		rCursor := rCursor || ' ( ';
		rCursor := rCursor || '		(CASE ';
										--新発債(特例債フラグがN)の場合　または　併存銘柄請求出力フラグが'2'(併存銘柄も出力する)の場合
		rCursor := rCursor || '			WHEN T1.TOKUREI_SHASAI_FLG = ''N'' OR T1.HEIZON_SEIKYU_KBN = ''2'' THEN ';
		rCursor := rCursor || '				 (CASE T1.CALC_PATTERN_CD ';
												--	残高基準日方式(計算方法が'1')の場合
												--		残高基準日時点の振替債 > 0 のものを抽出
		rCursor := rCursor || '					WHEN ''1'' THEN	SIGN(pkIpaZndk.getKjnZndk(T1.ITAKU_KAISHA_CD, T1.MGR_CD, T1.ZNDK_KIJUN_YMD, 3)::numeric) ';
												--	平均残高、月毎残高、定額方式(計算方法が'1'でない)の場合
												--		計算開始日時点の振替債 > 0 のものを抽出
		rCursor := rCursor || '					ELSE			SIGN(pkIpaZndk.getKjnZndk(T1.ITAKU_KAISHA_CD, T1.MGR_CD, T1.ST_CALC_YMD, 3)::numeric) ';
		rCursor := rCursor || '				  END) ';

										--それ以外、併存銘柄請求出力のチェックを行う(併存銘柄は出力しない)場合
		rCursor := rCursor || '			ELSE ';
		rCursor := rCursor || '				(CASE ';
												--	手数料徴求期日の前月末時点が満期償還日(最終の償還日)以降の場合
		rCursor := rCursor || '					WHEN pkDate.getZengetsumatsuYmd(T1.CHOKYU_KJT) >= T1.FULLSHOKAN_YMD THEN ';
													--	満期償還日前日時点の振替債 > 0 かつ 満期償還日前日時点の現登債 <= 0 のものを抽出
		rCursor := rCursor || '						(CASE SIGN(pkIpaZndk.getKjnZndk(T1.ITAKU_KAISHA_CD, T1.MGR_CD, pkDate.getZenYmd(T1.FULLSHOKAN_YMD), 3)::numeric) ';
		rCursor := rCursor || '							WHEN 1 THEN (CASE SIGN(pkIpaZndk.getKjnZndk(T1.ITAKU_KAISHA_CD, T1.MGR_CD, pkDate.getZenYmd(T1.FULLSHOKAN_YMD), 83)::numeric) ';
		rCursor := rCursor || '											WHEN 1 THEN 0 ';
		rCursor := rCursor || '											ELSE		1 ';
		rCursor := rCursor || '										 END) ';
		rCursor := rCursor || '							ELSE		 0 ';
		rCursor := rCursor || '						END) ';

												--	手数料徴求期日の前月末時点が満期償還期日より前の場合
												--	手数料徴求期日の前月末時点の振替債 > 0 かつ 手数料徴求期日の前月末時点の現登債 <= 0 のものを抽出
		rCursor := rCursor || '					ELSE (CASE SIGN(pkIpaZndk.getKjnZndk(T1.ITAKU_KAISHA_CD, T1.MGR_CD, pkDate.getZengetsumatsuYmd(T1.CHOKYU_KJT), 3)::numeric) ';
		rCursor := rCursor || '									WHEN 1 THEN (CASE SIGN(pkIpaZndk.getKjnZndk(T1.ITAKU_KAISHA_CD, T1.MGR_CD, pkDate.getZengetsumatsuYmd(T1.CHOKYU_KJT), 83)::numeric) ';
		rCursor := rCursor || '													WHEN 1 THEN 0 ';
		rCursor := rCursor || '													ELSE		1 ';
		rCursor := rCursor || '												 END) ';
		rCursor := rCursor || '									ELSE		 0 ';
		rCursor := rCursor || '						  END) ';
		rCursor := rCursor || '				END) ';
		rCursor := rCursor || ' 	END) = 1 ';
		rCursor := rCursor || ' OR ';
		rCursor := rCursor || ' (SELECT MG8.SS_NENCHOKYU_CNT FROM MGR_TESURYO_PRM MG8 ';
		rCursor := rCursor || '   WHERE MG8.ITAKU_KAISHA_CD = T1.ITAKU_KAISHA_CD ';
		rCursor := rCursor || '     AND MG8.MGR_CD = T1.MGR_CD) = ''00''';
		rCursor := rCursor || ' ) ';
		rCursor := rCursor || ' ORDER BY ';
		rCursor := rCursor || ' T1.HAKKO_TSUKA_CD, ';
		rCursor := rCursor || ' T1.CHOKYU_YYYYMM, ';
		rCursor := rCursor || ' T1.KOZA_TEN_CD, ';
		rCursor := rCursor || ' T1.KOZA_TEN_CIFCD, ';
		rCursor := rCursor || ' T1.CHOKYU_DD, ';
		rCursor := rCursor || ' T1.KOZA_FURI_KBN, ';
		rCursor := rCursor || ' T1.ISIN_CD ';

	RETURN rCursor;

	EXCEPTION
		WHEN OTHERS	THEN
			RAISE;
	END	$$ LANGUAGE PLPGSQL;


	/********************************************************************************
	 * 期中手数料計算後、請求書出力処理を実行する。
	 *
	 * @param inDataSakuseiKbn データ作成区分
	 * @return INTEGER 0:正常、99:異常、それ以外：エラー
	*********************************************************************************/
CREATE OR REPLACE FUNCTION pkipakichutesuryo.inskichutesuryoseikyuout (
	l_inuserid CHAR ,               -- ユーザID
 l_ingyomuymd CHAR ,             -- 業務日付
 l_inkjnfrom CHAR ,              -- 基準日From
 l_inkjnto CHAR ,                -- 基準日To
 l_initakukaishacd VARCHAR ,    -- 委託会社CD
 l_inhktcd CHAR ,                -- 発行体CD
 l_inkozatencd VARCHAR ,        -- 口座店CD
 l_inkozatencifcd VARCHAR ,     -- 口座店CIFCD
 l_inmgrcd CHAR ,                -- 銘柄CD
 l_inisincd CHAR ,               -- ISINCD
 l_inTsuchiYmd CHAR ,            -- 通知日
 l_inseikyuchoid VARCHAR,       -- 請求書ID
 l_inrealbatchkbn CHAR,          -- リアルバッチ区分
 l_indatasakuseikbn CHAR,        -- データ作成区分
 l_inseikyuichirankbn CHAR,      -- 請求書一覧区分
 l_inFrontFlg VARCHAR,          -- フロント照会画面判別フラグ
 l_outSqlCode OUT integer,
 l_outSqlErrM OUT VARCHAR ,
 OUT extra_param integer)
 RETURNS record AS $$
DECLARE

	typeRecord pkipakichutesuryo.recType[];
    rec pkipakichutesuryo.recType;

					--システム設定分と個別設定分を取得するカーソルタイプ
	pCur REFCURSOR;	--システム設定分と個別設定分を取得するカーソル
	pCurSql					varchar(10000) := NULL;

	pReturnCode		numeric	:=	0; -- return type from other proc is numeric
	pSqlErrM		text; -- return type is of type type, we need this so that we can cast to varchar
	pCnt			integer	:=	0;
	pCnt2			integer	:=	0;
	intMax			integer	:=	0;

	l_alltesukngk	numeric	:=	0;

	pStRecKbn		varchar	:=	'1';				--	デリートインサートモード
	pChokyuYmdFrom	char(8)	:=	'99999999';		--	徴求日	From	(抽出した徴求日との大小関係を比較するため、初期値は最大値)
	pChokyuYmdTo	char(8)	:=	'00000000';		--	徴求日	To	(抽出した徴求日との大小関係を比較するため、初期値は最小値)
	wkChohyoId		SREPORT_WK.CHOHYO_ID%TYPE;		--	ワーク帳票ＩＤ
	l_inItem 	  		 TYPE_SREPORT_WK_ITEM;

BEGIN

		--カーソルの作成		抽出条件に該当するレコードを基金移動テーブルに更新する
		pCurSql := pkipakichutesuryo.createCursor(l_inkjnfrom,l_inkjnto,l_initakukaishacd,l_inhktcd,l_inkozatencd,l_inkozatencifcd,l_inmgrcd,l_inisincd,l_inrealbatchkbn);

		--カウンターの初期化
		pCnt := 0;

		--システム設定分と個別設定分の請求書作成データを取得するためのカーソルを実行する
		OPEN pCur FOR EXECUTE pCurSql;
		LOOP
			FETCH pCur into rec;

			EXIT WHEN NOT FOUND; /* apply on pCur */
			-- フロント照会帳票出力指示以外からcallされた場合、手数料計算・更新処理を行う。

			IF l_inFrontFlg = '0' THEN

				--期中手数料を計算し、計算結果テーブルに格納する
				pReturnCode := pkIpaKichuTesuryo.updateKichuTesuryoTbl(rec.rItakuKaishaCd,
																		rec.rMgrCd,
																		rec.rTesuShuruiCd,
																		rec.rChokyuYmd,
																		l_inDataSakuseiKbn
																		);

				-- raise notice 'pReturnCode: %', pReturnCode;

				IF pReturnCode <> pkConstant.SUCCESS() THEN
					l_outSqlCode := pReturnCode;
					l_outSqlErrM := '手数料計算結果テーブル作成処理（データ作成区分'|| l_inDataSakuseiKbn ||'）が失敗しました。';
					CALL pkLog.error('ECM701', 'sfIpi055K00R00_01', 'エラーメッセージ：'|| l_OutSqlErrM);
					extra_param := pReturnCode;
					RETURN;
				END IF;
			END IF;
			typeRecord[pCnt] := rec;
			--カウンターを+1する
			pCnt := pCnt + 1;

		END LOOP;
		CLOSE pCur;

		-- バッチのときワークに残っているデータを削除
		IF l_inrealbatchkbn = '1' THEN
			-- ワーク帳票ＩＤ取得 (IPをWKに置き換え)
			wkChohyoId := REPLACE(l_inseikyuchoid, 'IP', 'WK');

			-- 作票を開始するためワークに残っているかもしれないデータをDELETE
			DELETE FROM SREPORT_WK
			WHERE CHOHYO_ID = wkChohyoId;
		END IF;

		-- 請求書・請求書一覧を出力
		intMax := pCnt;
		pCnt := 0;
		FOR pCnt IN 0..intMax - 1 LOOP

			-- 対象銘柄の手数料が0円の場合、出力しない。
			BEGIN
				SELECT MIN(ALL_TESU_KNGK) INTO STRICT l_alltesukngk FROM TESURYO
					WHERE	ITAKU_KAISHA_CD = l_initakukaishacd
					AND		MGR_CD          = typeRecord[pCnt].rMgrCd
					AND		CHOKYU_YMD      = typeRecord[pCnt].rChokyuYmd
					AND		TESU_SHURUI_CD IN ('11','12');
				EXCEPTION
					WHEN OTHERS THEN
						l_alltesukngk := 0;
			END;

			-- ０円以外は出力準備を行う
			IF l_alltesukngk <> 0 THEN

				-- 徴求日Fromを求める(現在の値よりちいさければセット)
				IF pChokyuYmdFrom > typeRecord[pCnt].rChokyuYmd THEN

					-- 徴求日Fromをセットする
					pChokyuYmdFrom := typeRecord[pCnt].rChokyuYmd;

				END IF;

				-- 徴求日Toを求める(現在の値よりおおきければセット)
				IF pChokyuYmdTo < typeRecord[pCnt].rChokyuYmd THEN

					-- 徴求日Toをセットする
					pChokyuYmdTo := typeRecord[pCnt].rChokyuYmd;

				END IF;

				pCnt2 := pCnt2 + 1;

				-- バッチのとき帳票作成SPに渡す条件の加工を行う
				IF l_inrealbatchkbn = '1' THEN
					-- 請求書作票処理をおこなう
					-- ワークデータ作成

					l_inItem := ROW();
					l_inItem.l_inItem001 := typeRecord[pCnt].rMgrCd;					-- 銘柄コード
					l_inItem.l_inItem002 := typeRecord[pCnt].rChokyuYmd;					-- 徴求日

					call pkPrint.insertData
						(
							l_inKeyCd			=>	typeRecord[pCnt].rItakuKaishaCd				-- 識別コード
							,l_inUserId			=>	l_inUserId								-- ユーザＩＤ
							,l_inChohyoKbn		=>	l_inrealbatchkbn						-- 帳票区分
							,l_inSakuseiYmd		=>	l_inGyomuYmd							-- 作成年月日
							,l_inChohyoId		=>	wkChohyoId								-- WK帳票ＩＤ
							,l_inSeqNo			=>	pCnt									-- SEQNO
							,l_inHeaderFlg		=>	'1'										-- ヘッダフラグ
							,l_inItem			=>  l_inItem
							,l_inKousinId		=>	l_inUserId								-- 更新者ID
							,l_inSakuseiId		=>	l_inUserId								-- 作成者ID
						);
					END IF;

			END IF;
		END LOOP;
		intMax := pCnt2;

		-- 徴求日
		-- ループを抜けた後初期値の場合には、両方共に抽出できない条件を付属させる
		-- 徴求日Toを求める
		IF pChokyuYmdTo = '00000000' THEN

			-- 徴求日Toをセットする
			pChokyuYmdTo := '99999999';

		END IF;

		-- バッチ処理の場合、徴求日From-Toがワークのデータと結合して抽出する邪魔にならないようにする
		IF l_inrealbatchkbn = '1' THEN
			-- 基準日FROMとTOにMIN値とMAX値をセット
			pChokyuYmdFrom := '00000000';
			pChokyuYmdTo := '99999999';

		-- リアルかつ一覧表のとき
		ELSIF l_inrealbatchkbn = '0' AND  l_inseikyuichirankbn = PKIPACALCTESURYO.C_SI_KBN_ICHIRAN()  THEN
			pChokyuYmdFrom := l_inkjnfrom;
			pChokyuYmdTo := l_inkjnto;
		END IF;

		-- 出力処理の開始！
		-- 請求書の場合
		IF l_inseikyuichirankbn = PKIPACALCTESURYO.C_SI_KBN_SEIKYU() THEN

			IF l_inseikyuchoid = pkipakichutesuryo.c_bunpai_seikyu() THEN -- 分配請求書の場合
				CALL SPIP05901_01(pStRecKbn, l_inmgrcd, pChokyuYmdFrom, pChokyuYmdTo, l_inhktcd, l_inkozatencd, l_inkozatencifcd, l_inisincd, l_inTsuchiYmd, l_initakukaishacd, l_inUserId, l_inrealbatchkbn, l_ingyomuymd, pReturnCode, pSqlErrM);

			ELSE -- 期中管理手数料請求書の場合
				CALL SPIP05501_01(l_inseikyuchoid, pStRecKbn, l_inmgrcd, pChokyuYmdFrom, pChokyuYmdTo, l_inhktcd, l_inkozatencd, l_inkozatencifcd, l_inisincd, l_inTsuchiYmd, l_initakukaishacd, l_inUserId, l_inrealbatchkbn, l_ingyomuymd, pReturnCode, pSqlErrM);

			END IF;

			l_outSqlErrM := pSqlErrM::varchar;

		-- 請求書一覧の場合
		ELSIF l_inseikyuichirankbn = PKIPACALCTESURYO.C_SI_KBN_ICHIRAN() THEN

			IF l_inseikyuchoid = pkipakichutesuryo.c_bunpai_ichiran() THEN  -- 分配一覧の場合(リアルのみ)
				CALL SPIP05801_01(SUBSTR(l_inkjnfrom,1,6), l_initakukaishacd, l_inUserId, l_inrealbatchkbn, l_ingyomuymd, pReturnCode, pSqlErrM);
				l_outSqlCode := pReturnCode::int;
			ELSE -- 期中管理手数料一覧の場合
				CALL SPIP05401_01(l_inseikyuchoid, pStRecKbn, l_inmgrcd, pChokyuYmdFrom, pChokyuYmdTo, l_initakukaishacd, l_inUserId, l_inrealbatchkbn, l_ingyomuymd, pReturnCode, pSqlErrM);
				--CALL SPIP05401_01(l_inseikyuchoid, pStRecKbn, l_inmgrcd, l_inkjnfrom, l_inkjnto, l_initakukaishacd, l_inUserId, l_inrealbatchkbn, l_ingyomuymd, pReturnCode, pSqlErrM);
			END IF;

			l_outSqlErrM := pSqlErrM::varchar;
		END IF;

		-- バッチ処理か？
		IF l_inrealbatchkbn = PKIPACALCTESURYO.C_BATCH() THEN

			-- 作票が終了したためワークに挿入したデータをDELETE
			DELETE FROM SREPORT_WK
			WHERE CHOHYO_ID = wkChohyoId;

			-- バッチ帳票印刷管理テーブルにデータを登録する
			IF intMax <> 0 AND pReturnCode = pkConstant.SUCCESS() THEN

				CALL PKIPACALCTESURYO.insertDataPrtOk(
					inItakuKaishaCd  => l_inItakuKaishaCd,
					inKijunYmd       => l_inGyomuYmd,
					inListSakuseiKbn => '1',
					inChohyoId       => l_inseikyuchoid
				);

			END IF;

		END IF;


		extra_param := pkConstant.SUCCESS();


		RETURN;

END $$ LANGUAGE PLPGSQL;
-- REVOKE ALL ON FUNCTION pkipakichutesuryo.inskichutesuryoseikyuout (l_inuserid CHAR , l_ingyomuymd CHAR , l_inkjnfrom CHAR , l_inkjnto CHAR , l_initakukaishacd VARCHAR , l_inhktcd CHAR , l_inkozatencd VARCHAR , l_inkozatencifcd VARCHAR , l_inmgrcd CHAR , l_inisincd CHAR , l_inTsuchiYmd CHAR , l_inseikyuchoid VARCHAR, l_inrealbatchkbn CHAR, l_indatasakuseikbn CHAR, l_inseikyuichirankbn CHAR, l_inFrontFlg VARCHAR, l_outSqlCode OUT integer, l_outSqlErrM OUT VARCHAR , OUT extra_param integer) FROM PUBLIC;

--******************** 特例社債の期中手数料でも使用する共通関数 ********************
	/*******************************************************************************
	 * データ取得<br>
	 * 引数で渡された値に対応したレコードを取得するSQLを生成
	 *
	 * @param  l_initakukaishacd	委託会社コード
	 * @param  l_inmgrcd			銘柄コード
	 * @param  l_intesucd			手数料種類コード
	 * @param  l_indate				徴求日
	 * @param  l_inheizonflg		並存銘柄手数料結果抽出フラグ 0=通常、1=並存
	 * @return l_return				正常終了/異常終了
	 *******************************************************************************/
CREATE OR REPLACE FUNCTION pkipakichutesuryo.creategetdatasql (
	l_initakukaishacd CHAR,
	l_inmgrcd CHAR,
	l_intesucd CHAR,
	l_indate CHAR,
	l_inheizonflg numeric
) RETURNS varchar AS $$ DECLARE


	/* ==変数定義=================================*/

	 -- SQL編集
	 l_strSql varchar(10000)	:= NULL;

	/* ==　処理　=================================*/


BEGIN

		/*銘柄_基本、銘柄_手数料回次、銘柄_受託銀行、銘柄_手数料　　　　　　　　　　　*/

		/*、銘柄_手数料(計算情報)、発行体マスタ から手数料計算に必要なデータを取得する*/

		l_strSql :=             'SELECT';
		l_strSql := l_strSql || ' MG1.ITAKU_KAISHA_CD,';				-- 委託会社コード
		l_strSql := l_strSql || ' MG1.MGR_CD,';							-- 銘柄コード
		l_strSql := l_strSql || ' MG1.JTK_KBN,';						-- 受託区分
		l_strSql := l_strSql || ' MG4.TESU_SHURUI_CD,';					-- 手数料種類コード
		l_strSql := l_strSql || ' MG1.HAKKO_TSUKA_CD,';					-- 発行通貨コード
		l_strSql := l_strSql || ' MG4.CHOKYU_KJT,';						-- 徴求期日
		l_strSql := l_strSql || ' MG4.CHOKYU_YMD,';						-- 徴求日
		l_strSql := l_strSql || ' MG4.DISTRI_YMD,';						-- 分配日
		l_strSql := l_strSql || ' MG1.HAKKO_YMD,';						-- 発行年月日
		l_strSql := l_strSql || ' pkDate.calcDateKyujitsuKbn(MG1.FULLSHOKAN_KJT, 0, MG1.KYUJITSU_KBN, ';
		l_strSql := l_strSql || ' 	pkDate.getAreaCd(MG1.Kyujitsu_Ld_Flg, MG1.Kyujitsu_Ny_Flg, MG1.Kyujitsu_Etc_Flg, ''N'', MG1.ETCKAIGAI_AREA1, MG1.ETCKAIGAI_AREA2, MG1.ETCKAIGAI_AREA3)) ,';	-- 満期償還期日
		l_strSql := l_strSql || ' '' ''	AS 			EB_MAKE_YMD,';		-- EB作成年月日  -- 徴求日-EB作成日営業日前
		l_strSql := l_strSql || ' CASE ';
		l_strSql := l_strSql || '   WHEN TRIM(TO_CHAR(REPLACE(ENCODE(SUBSTRING(VJ01.TESURYO_EB_SEND_DD::bytea,1), ''escape''), '' '',''0'')::numeric,''9990'')) = ''0'' THEN';
		l_strSql := l_strSql || '     '' ''';
		l_strSql := l_strSql || '   ELSE';
		l_strSql := l_strSql || '     pkDate.getMinusDateBusiness(MG4.CHOKYU_YMD, VJ01.TESURYO_EB_SEND_DD, ''' || pkConstant.TOKYO_AREA_CD() || ''')';
		l_strSql := l_strSql || ' END	AS 			EB_SEND_YMD,';		-- EB送信年月日  -- 徴求日-EB送信日営業日前
		l_strSql := l_strSql || ' CASE ';
		l_strSql := l_strSql || ' 	WHEN MG1.JTK_KBN =  ''2''     THEN MG4.DISTRI_YMD';  -- 副受託の場合は分配日と同値(2005.07.29 yoshisue)
		l_strSql := l_strSql || ' 	WHEN MG1.JTK_KBN <> ''2''     THEN MG4.CHOKYU_YMD';  -- 副受託以外の場合は徴求日と同値(2005.07.29 yoshisue)
		l_strSql := l_strSql || ' END             AS NYUKIN_YMD,';		-- 入金日
		l_strSql := l_strSql || ' CASE MG4.KAIJI WHEN ''1'' THEN MG7.TESU_SASHIHIKI_KBN ELSE ''2'' END   AS TESU_SASHIHIKI_KBN,';	-- 手数料差引区分
		l_strSql := l_strSql || ' M01.EIGYOTEN_CD,';					-- 営業店コード
		l_strSql := l_strSql || ' MG7.KOZA_FURI_KBN,';					-- 口座振替区分
		l_strSql := l_strSql || ' M01.KOZA_TEN_CD,';					-- 口座店コード
		l_strSql := l_strSql || ' CASE ';
		l_strSql := l_strSql || ' 	WHEN MG4.KAIJI = ''1''            THEN ''1''';    -- 初期
		l_strSql := l_strSql || ' 	WHEN MG4.KAIJI < MG4MAX.KAIJI_MAX THEN ''2''';    -- 期中
		l_strSql := l_strSql || ' 	WHEN MG4.KAIJI = MG4MAX.KAIJI_MAX THEN ''9''';    -- 終期
		l_strSql := l_strSql || ' END AS FIRSTLASTKICHU_KBN,';			--初期・期中・終期区分
		l_strSql := l_strSql || ' MG4.CALC_PATTERN_CD,';				-- 計算パターンコード
		l_strSql := l_strSql || ' MG4.SS_TEIGAKU_TESU_KNGK,';			-- MG4.信託報酬・社管手数料_定額手数料
		l_strSql := l_strSql || ' MG4.ST_CALC_YMD,';					-- 計算開始日
		l_strSql := l_strSql || ' MG4.ED_CALC_YMD,';					-- 計算終了日
		l_strSql := l_strSql || ' MG4.ZNDK_KIJUN_YMD,';					-- 残高基準日
		l_strSql := l_strSql || ' MG4.BILL_OUT_YMD,';					-- 請求書出力日
		l_strSql := l_strSql || ' MG8.SS_TESU_BUNBO,';					-- 信託報酬・社債管理手数料率（分母）
		l_strSql := l_strSql || ' MG8.SS_TESU_BUNSHI,';					-- 信託報酬・社債管理手数料率（分子）
		l_strSql := l_strSql || ' MG8.SS_TESU_DF_BUNBO,';				-- 信託報酬・社債管理手数料分配率（分母）
		l_strSql := l_strSql || ' MG8.SS_NENCHOKYU_CNT,';				-- 信託報酬・社管手数料_年徴求回数
		l_strSql := l_strSql || ' COALESCE(T01.DATA_SAKUSEI_KBN,''0'') AS DATA_SAKUSEI_KBN,';	-- データ作成区分
		l_strSql := l_strSql || ' MG8.CALC_PATTERN_CD,';				-- 計算パターンコード
		l_strSql := l_strSql || ' MG8.ZNDK_KAKUTEI_KBN,';				-- 残高確定区分
		l_strSql := l_strSql || ' MG8.ZENGO_KBN,';						-- 前取後取区分
		l_strSql := l_strSql || ' MG8.DAY_MONTH_KBN,';					-- 日割月割区分
		l_strSql := l_strSql || ' MG8.HASU_NISSU_CALC_KBN,';			-- 端数日数計算区分
		l_strSql := l_strSql || ' MG8.CALC_YMD_KBN,';					-- 計算期間区分
		l_strSql := l_strSql || ' MG8.SS_CALC_YMD2,';					-- 信託報酬・社管手数料_計算期間２
		l_strSql := l_strSql || ' MG8.SS_CALC_YMD2_GMATSU_FLG,';		-- 信託報酬・社管手数料_計算期間月末フラグ２
		l_strSql := l_strSql || ' MG8.SZEI_SEIKYU_KBN,';				-- 消費税請求区分
		l_strSql := l_strSql || ' COALESCE(T01.EB_MAKE_YMD,'' '') AS T01_EB_YMD,';		-- 手数料計算結果テーブルのEB作成年月日
		l_strSql := l_strSql || ' VJ01.EB_FLG,';						-- EB作成フラグ
		l_strSql := l_strSql || ' VJ01.HEIZON_SEIKYU_KBN';				-- 併存銘柄請求書出力区分
		l_strSql := l_strSql || ' FROM MGR_KIHON MG1,';					-- 銘柄_基本
		l_strSql := l_strSql || ' MGR_TESURYO_CTL MG7,';				-- 銘柄_手数料
		l_strSql := l_strSql || ' MGR_TESURYO_PRM MG8,';				-- 銘柄_手数料(計算情報)
		l_strSql := l_strSql || ' MHAKKOTAI M01,';						-- 発行体マスタ
		l_strSql := l_strSql || ' VJIKO_ITAKU VJ01,';					-- 自行情報・委託会社View
		l_strSql := l_strSql || ' MGR_TESKIJ MG4 left outer join ';						-- 銘柄_手数料回次

		IF l_inheizonflg = 0 THEN	--IN引数の並存銘柄手数料結果抽出フラグにより参照するテーブルを切り替え
			l_strSql := l_strSql || ' TESURYO T01 ON ';					-- 手数料計算結果			←パッケージの計算処理から呼ばれた場合
		ELSE
			l_strSql := l_strSql || ' HEIZON_MGR_TESURYO T01 ON';			-- 併存銘柄手数料計算結果	←特例社債の計算処理から呼ばれた場合
		END IF;


		l_strSql := l_strSql || '    	MG4.ITAKU_KAISHA_CD = T01.ITAKU_KAISHA_CD';
		l_strSql := l_strSql || ' AND   MG4.MGR_CD = T01.MGR_CD';
		l_strSql := l_strSql || ' AND   MG4.TESU_SHURUI_CD = T01.TESU_SHURUI_CD';
		l_strSql := l_strSql || ' AND   MG4.CHOKYU_KJT = T01.CHOKYU_KJT,';

		l_strSql := l_strSql || ' (SELECT ITAKU_KAISHA_CD,MGR_CD,TESU_SHURUI_CD,MAX(KAIJI) AS KAIJI_MAX FROM MGR_TESKIJ';
		l_strSql := l_strSql || '  GROUP BY ITAKU_KAISHA_CD,MGR_CD,TESU_SHURUI_CD) MG4MAX';	-- 銘柄_手数料回次 銘柄ごとの最大回次
		--ConstParameter
		l_strSql := l_strSql || ' WHERE MG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD';
		l_strSql := l_strSql || ' AND   MG1.HKT_CD = M01.HKT_CD';

		l_strSql := l_strSql || ' AND   MG1.ITAKU_KAISHA_CD = MG4.ITAKU_KAISHA_CD';
		l_strSql := l_strSql || ' AND   MG1.MGR_CD = MG4.MGR_CD';

		l_strSql := l_strSql || ' AND   MG1.ITAKU_KAISHA_CD = MG4MAX.ITAKU_KAISHA_CD';
		l_strSql := l_strSql || ' AND   MG1.MGR_CD = MG4MAX.MGR_CD';

		l_strSql := l_strSql || ' AND   MG1.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD';
		l_strSql := l_strSql || ' AND   MG1.MGR_CD = MG7.MGR_CD';

		l_strSql := l_strSql || ' AND   MG1.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD';
		l_strSql := l_strSql || ' AND   MG1.MGR_CD = MG8.MGR_CD';

		l_strSql := l_strSql || ' AND   MG4.TESU_SHURUI_CD = MG7.TESU_SHURUI_CD';
		l_strSql := l_strSql || ' AND   MG4.TESU_SHURUI_CD = MG4MAX.TESU_SHURUI_CD';

		l_strSql := l_strSql || ' AND   MG1.ITAKU_KAISHA_CD = VJ01.KAIIN_ID';

		--WhereParameter
		l_strSql := l_strSql || ' AND   MG1.ITAKU_KAISHA_CD = ''' || l_initakukaishacd || '''';
		l_strSql := l_strSql || ' AND   MG1.MGR_CD          = ''' || l_inmgrcd         || '''';
		l_strSql := l_strSql || ' AND   MG4.CHOKYU_YMD      = ''' || l_indate          || '''';
		l_strSql := l_strSql || ' AND   MG4.TESU_SHURUI_CD  = ''' || l_intesucd        || '''';

		RETURN l_strsql;

	EXCEPTION
		WHEN OTHERS THEN
RETURN pkConstant.FATAL();END $$ LANGUAGE PLPGSQL;
-- REVOKE ALL ON FUNCTION pkipakichutesuryo.creategetdatasql (l_initakukaishacd CHAR ,l_inmgrcd CHAR,l_intesucd CHAR ,l_indate CHAR ,l_inheizonflg numeric) FROM PUBLIC;

	/********************************************************************************
	 * 手数料分配結果取得<br>
	 * 手数料分配計算の元になるレコードを抽出し、
	 * 手数料分配計算レコード用のリストにセットする
	 *
	 * @return l_return				正常終了/異常終了
	 *******************************************************************************/
CREATE OR REPLACE FUNCTION pkipakichutesuryo.creategetbunpaidatasql (
	l_initakukaishacd CHAR,
	l_inmgrcd CHAR,
	l_inchokyukjt CHAR,
	l_intesucd CHAR,
	l_indate CHAR
) RETURNS varchar AS $$ DECLARE


	/* ==変数定義=================================*/

	 -- SQL編集
	 l_strSql varchar(10000)	:= NULL;
	/* ==　処理　=================================*/


BEGIN


		l_strSql :=             'SELECT';
		l_strSql := l_strSql || ' MG1.ITAKU_KAISHA_CD,';				-- 委託会社コード
		l_strSql := l_strSql || ' MG1.MGR_CD,';							-- 銘柄コード
		l_strSql := l_strSql || ' MG1.GROUP_ID,';						-- グループID
		l_strSql := l_strSql || ' MG4.TESU_SHURUI_CD,';					-- 手数料種類コード
		l_strSql := l_strSql || ' MG6.JTK_KBN,';						-- 受託区分
		l_strSql := l_strSql || ' MG4.CHOKYU_KJT,';						-- 徴求期日
		l_strSql := l_strSql || ' MG4.CHOKYU_YMD,';						-- 徴求日
		l_strSql := l_strSql || ' MG6.FINANCIAL_SECURITIES_KBN,';		-- 金融証券区分
		l_strSql := l_strSql || ' MG6.BANK_CD,';						-- 金融機関コード
		l_strSql := l_strSql || ' MG6.KICHU_BUN_DF_BUNSHI';				-- 分配率(分子)
		l_strSql := l_strSql || ' FROM';
		l_strSql := l_strSql || ' MGR_KIHON MG1,';						-- 銘柄_基本
		l_strSql := l_strSql || ' MGR_TESKIJ MG4,';						-- 銘柄_手数料回次
		l_strSql := l_strSql || ' MGR_JUTAKUGINKO MG6';					-- 銘柄_受託銀行
		l_strSql := l_strSql || ' WHERE MG1.ITAKU_KAISHA_CD = MG4.ITAKU_KAISHA_CD';
		l_strSql := l_strSql || ' AND   MG1.MGR_CD = MG4.MGR_CD';
		l_strSql := l_strSql || ' AND   MG1.ITAKU_KAISHA_CD = MG6.ITAKU_KAISHA_CD';
		l_strSql := l_strSql || ' AND   MG1.MGR_CD = MG6.MGR_CD';

		--WhereParameter
		l_strSql := l_strSql || ' AND   MG1.ITAKU_KAISHA_CD = ''' || l_initakukaishacd || '''';
		l_strSql := l_strSql || ' AND   MG1.MGR_CD          = ''' || l_inmgrcd         || '''';
		l_strSql := l_strSql || ' AND   MG4.CHOKYU_KJT      = ''' || l_inchokyukjt     || '''';
		l_strSql := l_strSql || ' AND   MG4.CHOKYU_YMD      = ''' || l_indate          || '''';
		l_strSql := l_strSql || ' AND   MG4.TESU_SHURUI_CD  = ''' || l_intesucd        || '''';

		RETURN l_strsql;

	EXCEPTION
		WHEN OTHERS THEN
		RETURN pkConstant.FATAL();END $$ LANGUAGE PLPGSQL;
-- REVOKE ALL ON FUNCTION pkipakichutesuryo.creategetbunpaidatasql (l_initakukaishacd CHAR ,l_inmgrcd CHAR ,l_inchokyukjt CHAR ,l_intesucd CHAR ,l_indate CHAR) FROM PUBLIC;

	/********************************************************************************
	 * 残高取得<br>
	 * 共通関数の基準日残高取得処理をコールし、
	 * 取得したレコードをリストにセットする
	 *
	 * @param  l_initakukaishacd	委託会社コード
	 * @param  l_inmgrcd			銘柄コード
	 * @param  l_indate				基準日
	 * @param  l_instcalcymd		計算開始日
	 * @param  l_inedcalcymd		計算終了日 ※getZndkでは不要
	 * @param  l_inhakkoymd			発行年月日
	 * @param  l_inshokanymd		満期償還日
	 * @param  l_incalcpatterncd	計算パターンコード
	 * @param  l_inzndkkbn			残高確定区分
	 * @param  l_injissu			実数（残高取得SPに渡す）

	 * @param  l_outkjnzndk			基準残高
	 * @param  l_outkeisanyymm		計算年月（１〜１３）
	 * @param  l_outtsukizndk		月毎残高（１〜１３）

	 * @return l_return				正常終了/異常終了
	********************************************************************************/
CREATE OR REPLACE FUNCTION pkipakichutesuryo.getzndk (
    l_initakukaishacd CHAR,
    l_inmgrcd VARCHAR,
    l_indate CHAR,
    l_instcalcymd CHAR,
    l_inedcalcymd CHAR,
    l_inhakkoymd CHAR,
    l_inshokanymd CHAR,
    l_incalcpatterncd CHAR,
    l_inzndkkbn CHAR,
    l_injissu numeric,
    l_outzndk OUT numeric,
    l_outkeisanyymm OUT pkipakichutesuryo.ch6_array,
    l_outtsukizndk OUT pkipakichutesuryo.num_array,
    OUT extra_param numeric
) RETURNS record AS $$ DECLARE

	/* ==変数定義=================================*/

	l_return				numeric := 0;

	l_addmonths				numeric := 0;    --計算開始月からの追加月数(最大12)
	l_targetymd				char(8);      --取得対象年月日
	l_maxshokanymd			char(8);      --最終償還日
	l_setymd				char(8);      --計算年月にセットする年月日
	l_minusmonth			numeric := 0; -- 残高確定区分：前月末 の時は -1 、当月末 の時は 0
	/* ==　処理　=================================*/


BEGIN

	-- コレクションの初期化
	LOOP
		l_outkeisanyymm[l_addmonths] := ' ';	-- 計算年月
		l_outtsukizndk[l_addmonths]  := 0;		-- 月毎残高
		l_addmonths := l_addmonths + 1;
		EXIT WHEN l_addmonths > 12;
	END LOOP;
	l_addmonths := 0;

	--基準残高の初期化
	l_outzndk := 0;

		--計算パターンコード = 残高基準日方式の場合
		IF l_incalcpatterncd = '1' THEN
			--残高取得SPをコール　※第四引数=（通常：実質残高…3、併存銘柄：振替債+現登債…93)
			l_outzndk := pkIpaZndk.getKjnZndk(l_initakukaishacd,l_inmgrcd,l_indate,l_injissu)::numeric;

		--計算パターンコード = 残高基準日方式以外(月毎残高方式・平均残高方式)
		ELSIF  l_incalcpatterncd IN ('2','3','5') THEN
			--計算パターンコード　IN　('2'（月毎残高方式）、3'（平均残高方式）、'5'（平均残高（後除算）方式)　の場合
			--計算年月日の初期値をセット
			l_setymd := TO_CHAR(oracle.LAST_DAY(TO_DATE(l_instcalcymd, 'YYYYMMDD')),'YYYYMMDD');
			--基準残高取得対象年月日の初期値をセット
			--※残高確定区分＝前月末（1）：計算開始前月の月末日、当月末（2）：計算開始月の月末日
			-- 残高取得基準日に計算年月（残高確定区分＝前月末の場合は一ヶ月引く）をセット
			IF l_inzndkkbn = 1 THEN
				l_minusmonth := -1;
			END IF;
			l_targetymd := TO_CHAR(oracle.ADD_MONTHS(TO_DATE(l_setymd, 'YYYYMMDD'),l_minusmonth),'YYYYMMDD');

			LOOP
				--残高確定区分＝前月末残高（1）の場合
				IF l_inzndkkbn = 1 THEN
					--発行日が前月末以降の場合
					IF (l_targetymd)::numeric  < (l_inhakkoymd)::numeric  THEN
						--発行日を基準日にセット
						l_targetymd := l_inhakkoymd;
					END IF;
					--発行日が前月末以前の場合は、基準日は前月末のまま
					--償還日が前月末以前の場合
					IF (l_targetymd)::numeric  >= (l_inshokanymd)::numeric  THEN
						--満期償還日−1日を基準日にセット
						l_targetymd := pkDate.getMinusDate(l_inshokanymd, 1);
					END IF;
				--残高確定区分＝当月末残高（2）の場合
				ELSE
					--最終償還日を取得（回次がない場合は'99999999'）
					BEGIN
						SELECT coalesce(nullif(trim(both MAX(MG3.SHOKAN_YMD)), ''),'99999999')
						  INTO STRICT l_maxshokanymd
						  FROM MGR_SHOKIJ MG3
						 WHERE MG3.ITAKU_KAISHA_CD = l_initakukaishacd
						   AND MG3.MGR_CD = l_inmgrcd;
					EXCEPTION
						WHEN OTHERS THEN
						l_maxshokanymd := '99999999';
					END;

					--満期償還日が'99999999'の場合（永久債の場合）
					IF l_inshokanymd = '99999999' THEN
						--SELECT結果が'99999999'でない場合、償還日時点の振替債残高（実数：3）が0でなければ'99999999'を最終償還日とする。
						IF l_maxshokanymd <> '99999999' AND pkIpaZndk.getKjnZndk(l_initakukaishacd, l_inmgrcd, l_maxshokanymd, 3) <> '0' THEN
							l_maxshokanymd := '99999999';
						END IF;
					ELSE
						--SELECT結果が'99999999'の場合、満期償還日を最終償還日とする。（償還回次を作成していない場合）
						IF l_maxshokanymd = '99999999' THEN
							l_maxshokanymd := l_inshokanymd;
						END IF;
					END IF;

					--償還日が当月末以前の場合
					IF (l_targetymd)::numeric  >= (l_maxshokanymd)::numeric  THEN
						--最終償還日−1日を基準日にセット
						l_targetymd := pkDate.getMinusDate(l_maxshokanymd, 1);
					END IF;
					--償還日が当月末以降の場合は、基準日は当月末のまま
				END IF;

				--基準残高（1〜13）をセット（通常：実質残高…3、併存銘柄：振替債+現登債…93)
				l_outtsukizndk[l_addmonths] := pkIpaZndk.getKjnZndk(l_initakukaishacd,l_inmgrcd,l_targetymd,l_injissu)::numeric;

				-- 計算年月（1〜13）をセット
				l_outkeisanyymm[l_addmonths] := SUBSTR(l_setymd, 1, 6);

				-- 日割部分計算用の基準残高に、端数月の残高を一時的にセット
				IF (SUBSTR(l_instcalcymd,1,6) = SUBSTR(l_setymd,1,6)
					AND SUBSTR(l_instcalcymd,7,2) <> '01'
					AND l_addmonths = 0)      -- 初期で端数日数がある場合　または
					OR (SUBSTR(l_inedcalcymd,1,6) = SUBSTR(l_setymd,1,6)
					AND SUBSTR(l_inedcalcymd,7,2) <>
					SUBSTR(TO_CHAR(oracle.LAST_DAY(TO_DATE(l_setymd,'YYYYMMDD')),'YYYYMMDD'),7,2)
					AND l_addmonths > 0) THEN -- 終期で端数日数がある場合
						l_outzndk := l_outtsukizndk[l_addmonths];
				END IF;

				l_addmonths := l_addmonths + 1;

				--残高確定区分が前月末で、残高取得の基準日が月末ではない場合 その月の月末日をセットする
				IF TO_DATE(l_setymd,'YYYYMMDD') <> oracle.LAST_DAY(TO_DATE(l_setymd, 'YYYYMMDD'))
					AND l_inzndkkbn = 1 THEN

					l_setymd := TO_CHAR(oracle.LAST_DAY(TO_DATE(l_setymd, 'YYYYMMDD')),'YYYYMMDD');
				ELSE
					--通常は翌月の月末をセット
					l_setymd := TO_CHAR(oracle.LAST_DAY(oracle.ADD_MONTHS(TO_DATE(l_setymd, 'YYYYMMDD'),1)),'YYYYMMDD');
				END IF;

				-- 残高取得ターゲット年月日に、計算セット年月日をセット（残高基準日が前月末の場合は-1ヶ月）
				l_targetymd := TO_CHAR(oracle.ADD_MONTHS(TO_DATE(l_setymd, 'YYYYMMDD'),l_minusmonth),'YYYYMMDD');

				--取得対象年月が計算終了月を超えたらループを抜ける
				EXIT WHEN (SUBSTR(l_inedcalcymd,1,6))::numeric  < (SUBSTR(l_setymd,1,6))::numeric;

				-- 月割（端数期間切捨）かつ、計算終了日が月末でない時は、１月手前でループを抜ける
				EXIT WHEN pkipakichutesuryo.p_daymonthkbn() = '5' And (SUBSTR(l_inedcalcymd,1,6))::numeric  = (SUBSTR(l_setymd,1,6))::numeric  AND TO_DATE(l_inedcalcymd, 'YYYYMMDD') <> oracle.LAST_DAY(TO_DATE(l_inedcalcymd, 'YYYYMMDD'));

				--開始月の12ヶ月後までで処理を抜ける
				EXIT WHEN l_addmonths > 12;

			END LOOP;

		END IF;

		extra_param := l_return;

		RETURN;

	EXCEPTION
		WHEN OTHERS THEN
		extra_param := pkConstant.FATAL();
		RETURN;END $$ LANGUAGE PLPGSQL;

	/********************************************************************************
	 * 応答日取得<br>
	 *
	 * @param  l_inkjnymd	         CHAR   基準日
	 * @param  l_insscalcymd2        CHAR   計算期間２
	 * @param  l_inoutoudd　         NUMERIC   １２／年徴求回数
	 * @param  l_inmatsuFlg          CHAR   計算期間月末フラグ２
	 *
	 * @return l_return  応答日
	********************************************************************************/
CREATE OR REPLACE FUNCTION pkipakichutesuryo.getoutoymd ( l_inkjnymd CHAR, l_insscalcymd2 CHAR, l_inoutoudd numeric, l_inmatsuFlg CHAR 		-- 計算期間月末フラグ２
 ) RETURNS char AS $$
DECLARE


	replyYmd		char(8); -- 応答日

BEGIN
			replyYmd := '';
			-- 基準開始日からの応答日を算出
			replyYmd := pkDate.calcMonth(l_inkjnymd, l_inoutoudd);

			-- 月末フラグなしかつ計算期間２が月末日の場合
			IF l_inmatsuFlg = '0' AND l_insscalcymd2 = pkDate.getGetsumatsuYmd(l_insscalcymd2, 0) THEN
				-- 計算期間２の日付部分が応答日の日付部分より小さい場合、応答日の日付部分に計算期間２の日付部分をセットする
				IF (TO_CHAR(TO_DATE(l_insscalcymd2, 'YYYYMMDD'), 'DD') < SUBSTR(replyYmd, 7, 2)) THEN
					replyYmd := TO_CHAR(TO_DATE(replyYmd,'YYYYMMDD'), 'YYYYMM') || TO_CHAR(TO_DATE(l_insscalcymd2, 'YYYYMMDD'), 'DD');
				END IF;
			-- 月末フラグなしかつ計算期間２が月末日でないかつ応答日が月末日の場合
			ELSIF l_inmatsuFlg = '0' AND l_insscalcymd2 <> pkDate.getGetsumatsuYmd(l_insscalcymd2, 0) AND replyYmd = pkDate.getGetsumatsuYmd(replyYmd, 0) THEN
				-- 計算期間２の日付部分が応答日の日付部分より小さい場合、応答日の日付部分に計算期間２の日付部分をセットする
				IF (TO_CHAR(TO_DATE(l_insscalcymd2, 'YYYYMMDD'), 'DD') < SUBSTR(replyYmd, 7, 2)) THEN
					replyYmd := TO_CHAR(TO_DATE(replyYmd,'YYYYMMDD'), 'YYYYMM') || TO_CHAR(TO_DATE(l_insscalcymd2, 'YYYYMMDD'), 'DD');
				END IF;
			END IF;

		RETURN replyYmd;
	EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.FATAL('', '', SQLSTATE || SUBSTR(SQLERRM, 1, 50));
		RETURN replyYmd;END $$ LANGUAGE PLPGSQL;
-- REVOKE ALL ON FUNCTION pkipakichutesuryo.getoutoymd ( l_inkjnymd CHAR, l_insscalcymd2 CHAR, l_inoutoudd numeric, l_inmatsuFlg CHAR  ) FROM PUBLIC;

	/********************************************************************************
	 * 月数取得<br>
	 * リストの値を参照し、月数、月割部分From、月割部分To、端数月、
	 * を取得する
	 *
	 * @param  l_instcalcymd         CHAR   計算開始日
	 * @param  l_inedcalcymd         CHAR   計算終了日
	 * @param  l_indaymonthkbn       CHAR   端数期間日割月割区分
	 * @param  l_incalcymdkbn        CHAR   計算期間区分
	 * @param  l_inmatsuFlg          CHAR   計算期間月末フラグ２
	 * @param  l_infirstlastkichukbn CHAR   初期・終期・期中区分
	 * @param  l_inoutoudd           NUMERIC 応答日
	 * @param  l_insscalcymd2        CHAR   計算期間２
	 *
	 * @param  l_outtsukiwarifrom    CHAR   月割期間From
	 * @param  l_outtsukiwarito      CHAR   月割期間To
	 * @param  l_outtsukisu          NUMERIC 月数
	 * @param  l_outhasutsuki        CHAR   端数月
	 *
	 * @return l_return  pkConstant.SUCCESS() 正常終了
	 *                   pkConstant.FATAL()   異常終了
	********************************************************************************/
CREATE OR REPLACE FUNCTION pkipakichutesuryo.getmonthfromto (
	l_instcalcymd CHAR,
	l_inedcalcymd CHAR,
	l_indaymonthkbn CHAR,
	l_incalcymdkbn CHAR,
	l_inmatsuFlg CHAR,
	-- 計算期間月末フラグ２
	l_infirstlastkichukbn CHAR,
	l_inoutoudd numeric,
	l_insscalcymd2 CHAR,
	l_outtsukiwarifrom OUT CHAR,
	l_outtsukiwarito OUT CHAR,
	l_outtsukisu OUT numeric,
	l_outhasutsuki OUT CHAR,
	OUT extra_param numeric
) RETURNS record AS $$ DECLARE


	/* -------------------------内部変数定義----------------------------- */

	l_tmpymd        char(8); --対象日（計算用年月日一時取得）
	l_tmpmonths     numeric; --月数 一時取得用
	l_tmpjustmonths numeric; --月数 端数月判定用
	l_edcalcymd1    char(8); --計算終了日＋１
	/* ============================= 本処理 ============================= */


BEGIN

		--  初期化処理
		--  OUT変数初期化
		l_outtsukiwarifrom := '';
		l_outtsukiwarito   := '';
		l_outtsukisu       := 0;
		l_outhasutsuki     := ' ';

		-- 計算終了日＋１を取得
		l_edcalcymd1 := pkDate.getPlusDate(l_inedcalcymd, 1);

		--  ※端数期間日割月割区分＝月割日割（1）、月割（3）　共通処理
		--  初期の場合（初期・終期・期中区分＝1）
		IF l_infirstlastkichukbn = '1' THEN

			-- 計算期間区分＝応答日ベースもしくは、端数期間日割月割区分＝日割（端数期間のみ）の場合
			IF l_incalcymdkbn = '1' OR l_indaymonthkbn = '4' THEN

				-- 前回応答日＝計算開始日の場合、月数に12/年徴求回数をセットする
				IF pkipakichutesuryo.getoutoymd(l_edcalcymd1, l_insscalcymd2, -(l_inoutoudd), l_inmatsuFlg) = l_instcalcymd THEN
					l_tmpmonths := l_inoutoudd;
					l_tmpymd := pkDate.getMinusDate( l_instcalcymd, 1 );

				-- 端数期間が発生した場合
				ELSE
					-- 開始日と終了日の月数を計算する
					l_tmpmonths := oracle.MONTHS_BETWEEN(TO_DATE(l_edcalcymd1, 'YYYYMMDD'), TO_DATE(l_instcalcymd, 'YYYYMMDD'));

					-- 計算終了日＋１が月末日の場合
					IF l_edcalcymd1 = pkDate.getGetsumatsuYmd(l_edcalcymd1, 0) THEN
						-- 月末フラグありかつ計算開始日が月末日でないかつ
						-- 計算終了日＋１の日付部分が計算開始日の日付部分より小さい場合、月数＋１をセットする
						IF l_inmatsuFlg = '1' AND l_instcalcymd <> pkDate.getGetsumatsuYmd(l_instcalcymd, 0)
						AND SUBSTR(l_edcalcymd1, 7, 2) < SUBSTR(l_instcalcymd, 7, 2) THEN
							l_tmpmonths := l_tmpmonths + 1;
						-- 月末フラグなしかつ計算開始日が月末日の場合、月数−１をセットする
						-- 計算終了日＋１の日付部分が計算開始日の日付部分より小さい場合、月数−１をセットする
						ELSIF l_inmatsuFlg = '0' AND l_instcalcymd = pkDate.getGetsumatsuYmd(l_instcalcymd, 0)
						AND SUBSTR(l_edcalcymd1, 7, 2) < SUBSTR(l_instcalcymd, 7, 2) THEN
							l_tmpmonths := l_tmpmonths - 1;
						END IF;
					END IF;

					-- 計算終了日＋１の月数前の応答日前日をセット
					l_tmpymd := pkDate.getMinusDate(pkipakichutesuryo.getoutoymd(l_edcalcymd1, l_insscalcymd2, - FLOOR(l_tmpmonths), l_inmatsuFlg), 1);

					-- 計算終了日＋１の月数前の応答日が計算開始日でない場合
					IF pkipakichutesuryo.getoutoymd(l_edcalcymd1, l_insscalcymd2, - FLOOR(l_tmpmonths), l_inmatsuFlg) <> l_instcalcymd THEN
						--端数月をセット … 計算開始年月
						l_outhasutsuki := SUBSTR( l_instcalcymd, 1, 6 );
					END IF;

				END IF;

			-- 計算期間区分＝月末ベースの場合
			ELSE

				-- 計算開始日が月初の場合
				IF SUBSTR( l_instcalcymd, 7, 2 ) = '01' THEN

					--対象日に、計算開始日の前日をセット（期間取得関数で両端日数をセットするため）
					l_tmpymd := pkDate.getMinusDate( l_instcalcymd, 1 );


				-- 計算開始日が月初以外の場合
				ELSE

					--対象日に、計算開始日の月末日をセット（期間取得関数で両端日数をセットするため）
					l_tmpymd := pkDate.getGetsumatsuYmd( l_instcalcymd, 0 );

				END IF;

				--計算終了日から見て、対象日までの片端期間の月数を取得
				l_tmpmonths := oracle.MONTHS_BETWEEN( TO_DATE( l_inedcalcymd, 'YYYYMMDD' ), TO_DATE( l_tmpymd, 'YYYYMMDD' ) );

				--端数月をセット … 端数日数（取得月数に小数点以下の値）がある場合のみ
				--計算終了日の日付部分より計算開始日の日付部分が大きい場合。
				--初期の場合のみ条件追加。月末ベースで期中・終期の場合、開始日が必ず月初であるためMONTHS_BETWEENの不具合はなく、補正の必要なし。
				--【例】2006/03/31〜2006/09/30（初期）の場合、端数月がセットされないので条件追加
				IF oracle.MONTHS_BETWEEN( TO_DATE( l_inedcalcymd, 'YYYYMMDD' ), TO_DATE( pkDate.getMinusDate(l_instcalcymd, 1 ),'YYYYMMDD' ) ) - FLOOR(l_tmpmonths ) <> 0
				OR SUBSTR(l_inedcalcymd, 7, 2) < SUBSTR(l_instcalcymd, 7, 2)THEN

					--端数月をセット … 計算開始年月
					l_outhasutsuki := SUBSTR( l_instcalcymd, 1, 6 );

				END IF;

			END IF;

			--月数をセット … （端数日数を切捨）
			l_outtsukisu := FLOOR( l_tmpmonths );

			--月割期間Fromをセット … 対象日＋1日（両端日数のため）
			l_outtsukiwarifrom := TO_CHAR( TO_DATE( l_tmpymd, 'YYYYMMDD' ) + 1, 'YYYYMMDD' );

			--月割期間Toをセット … 計算終了日
			l_outtsukiwarito := l_inedcalcymd;

		--初期以外の場合（初期・終期・期中区分<>1）
		ELSE

			-- 計算期間区分＝応答日ベースもしくは、端数期間日割月割区分＝日割（端数期間のみ）の場合
			IF l_incalcymdkbn = '1' OR l_indaymonthkbn = '4' THEN
				-- 次回応答日＝計算終了日＋１の場合、月数に12/年徴求回数をセットする
				IF pkipakichutesuryo.getoutoymd(l_instcalcymd, l_insscalcymd2, l_inoutoudd, l_inmatsuFlg) = l_edcalcymd1 THEN
					l_tmpmonths := l_inoutoudd;
					l_tmpymd := l_edcalcymd1;

				-- 端数期間が発生した場合
				ELSE
					--日数でカウントした月数を出す
					l_tmpmonths := oracle.MONTHS_BETWEEN( TO_DATE( l_edcalcymd1, 'YYYYMMDD' ), TO_DATE( l_instcalcymd, 'YYYYMMDD' ) );

					-- 月末フラグありかつ計算終了日＋１が月末日でないかつ
					-- 計算終了日＋１の日付部分が計算開始日の日付部分以上の場合、月数＋１をセットする
					IF l_inmatsuFlg = '1' AND l_edcalcymd1 <> pkDate.getGetsumatsuYmd(l_edcalcymd1, 0)
					AND SUBSTR(l_edcalcymd1, 7, 2) >= SUBSTR(l_instcalcymd, 7, 2) THEN
						l_tmpmonths := l_tmpmonths - 1;
					-- 月末フラグなしかつ計算終了日＋１が月末日かつ
					-- 計算開始日が月末日でないかつ計算開始日の日付部分が計算終了日＋１の日付部分より大きい場合、月数＋１をセットする
					ELSIF l_inmatsuFlg = '0' AND l_edcalcymd1 = pkDate.getGetsumatsuYmd(l_edcalcymd1, 0)
					AND l_instcalcymd <> pkDate.getGetsumatsuYmd(l_instcalcymd, 0) AND SUBSTR(l_instcalcymd, 7, 2) > SUBSTR(l_edcalcymd1, 7, 2) THEN
						l_tmpmonths := l_tmpmonths + 1;
					END IF;

					-- 計算開始日月数後の応答日をセット
					l_tmpymd := pkipakichutesuryo.getoutoymd(l_instcalcymd, l_insscalcymd2, FLOOR( l_tmpmonths ), l_inmatsuFlg);

					-- 計算開始日月数後の応答日が計算終了日＋１でない場合
					IF pkipakichutesuryo.getoutoymd(l_instcalcymd, l_insscalcymd2, FLOOR( l_tmpmonths ), l_inmatsuFlg) <> l_edcalcymd1 THEN
						--端数月をセット … 計算終了年月
						l_outhasutsuki := SUBSTR(l_inedcalcymd, 1, 6);
					END IF;

				END IF;
			-- 計算期間区分＝月末ベースの場合
			ELSE

				-- 計算終了日が月末の場合
				IF TO_DATE( l_inedcalcymd, 'YYYYMMDD' ) = oracle.LAST_DAY( TO_DATE( l_inedcalcymd, 'YYYYMMDD' ) ) THEN

					--対象日に、計算終了日＋1日をセット（期間取得関数で両端日数をセットするため）
					l_tmpymd := l_edcalcymd1;

				-- 計算終了日が月末以外の場合
				ELSE

					--対象日に、「計算終了月の月初」をセット（期間取得関数で両端日数をセットするため）
					l_tmpymd := pkDate.getGesshoYmd( l_inedcalcymd );

				END IF;

				--計算開始日から見て、対象日までの片端期間の月数を取得
				IF (TO_DATE( l_inedcalcymd, 'YYYYMMDD' ) = oracle.LAST_DAY( TO_DATE( l_inedcalcymd, 'YYYYMMDD' ) ) AND
					TO_DATE( l_instcalcymd, 'YYYYMMDD' ) <> oracle.LAST_DAY( TO_DATE( l_instcalcymd, 'YYYYMMDD' ) )  ) THEN

					IF (SUBSTR(l_instcalcymd, 7, 2) > SUBSTR(l_inedcalcymd, 7, 2)) THEN

						l_tmpmonths := ABS( oracle.MONTHS_BETWEEN( TO_DATE( l_instcalcymd, 'YYYYMMDD' ), TO_DATE( l_tmpymd, 'YYYYMMDD' ) ) ) + 1;

					ELSE

						l_tmpmonths := ABS( oracle.MONTHS_BETWEEN( TO_DATE( l_instcalcymd, 'YYYYMMDD' ), TO_DATE( l_tmpymd, 'YYYYMMDD' ) ) );

					END IF;

				ELSE

					l_tmpmonths := ABS( oracle.MONTHS_BETWEEN( TO_DATE( l_instcalcymd, 'YYYYMMDD' ), TO_DATE( l_tmpymd, 'YYYYMMDD' ) ) );

				END IF;


				--端数月をセット … 端数日数（取得月数に小数点以下の値）がある場合のみ
				IF oracle.MONTHS_BETWEEN( TO_DATE( l_edcalcymd1, 'YYYYMMDD' ), TO_DATE( l_instcalcymd, 'YYYYMMDD' ) ) - FLOOR( l_tmpmonths ) <> 0 THEN

					--端数月をセット … 計算終了年月
					l_outhasutsuki := SUBSTR(l_inedcalcymd, 1, 6);

				END IF;
			END IF;

			--月数をセット … （端数日数を切捨）
			l_outtsukisu := FLOOR( l_tmpmonths );

			--月割期間Fromをセット … 計算開始日
			l_outtsukiwarifrom := l_instcalcymd;

			--月割期間Toをセット … 対象日−1日（両端日数のため）
			l_outtsukiwarito := TO_CHAR( TO_DATE( l_tmpymd, 'YYYYMMDD' ) - 1, 'YYYYMMDD' );


		END IF;


		--※端数期間日割月割区分＝月割（3）　の場合のみの処理
		IF l_indaymonthkbn = '3' THEN

			--月数に端数分の1ヶ月を加算（端数月が有る時のみ）
			IF l_outhasutsuki <> ' ' THEN

				l_outtsukisu := l_outtsukisu + 1;

			END IF;

			--両端日数でカウントした月数を出し、端数月が本当に無い時は初期化(端数月判定用に追加 ※単体でＯＫだった部分をいじりたくたい為)
			l_tmpjustmonths := oracle.MONTHS_BETWEEN( TO_DATE( l_inedcalcymd, 'YYYYMMDD' ) + 1, TO_DATE( l_instcalcymd, 'YYYYMMDD' ) );

			IF l_tmpjustmonths = FLOOR( l_tmpjustmonths ) THEN

				l_outhasutsuki := ' ';

			END IF;

			--初期の場合（初期・終期・期中区分＝1）
			IF l_infirstlastkichukbn = '1' THEN

				--計算開始日が月割期間Fromより前の場合
				IF l_instcalcymd < l_outtsukiwarifrom THEN

					--月割期間Fromに計算開始日をセット
					l_outtsukiwarifrom := l_instcalcymd;

				END IF;

			--初期以外の場合（初期・終期・期中区分<>1）
			ELSE

				--計算終了日が月割期間Toより後の場合
				IF l_inedcalcymd > l_outtsukiwarito THEN

					--月割期間Toに計算終了日をセット
					l_outtsukiwarito := l_inedcalcymd;

				END IF;

			END IF;

		END IF;

	--※端数期間日割月割区分＝'5'（月割（端数期間切捨）
		IF l_indaymonthkbn = '5' THEN

			--月数に端数分の1ヶ月を加算（端数月が有る時のみ）
			IF l_outhasutsuki <> ' ' THEN

				IF l_infirstlastkichukbn = '9' THEN
				--  終期の場合（初期・終期・期中区分＝9）
					l_outtsukisu := l_outtsukisu + 0;

				ELSE
				--  終期以外の場合（初期・終期・期中区分≠9）
					l_outtsukisu := l_outtsukisu + 1;

				END IF;

			END IF;

			--両端日数でカウントした月数を出し、端数月が本当に無い時は初期化(端数月判定用に追加
			l_tmpjustmonths := oracle.MONTHS_BETWEEN( TO_DATE( l_inedcalcymd, 'YYYYMMDD' ) + 1, TO_DATE( l_instcalcymd, 'YYYYMMDD' ) );

			IF l_tmpjustmonths = FLOOR( l_tmpjustmonths ) THEN

				l_outhasutsuki := ' ';

			END IF;

			--初期の場合（初期・終期・期中区分＝1）
			IF l_infirstlastkichukbn = '1' THEN

				--計算開始日が月割期間Fromより前の場合
				IF l_instcalcymd < l_outtsukiwarifrom THEN

					--月割期間Fromに計算開始日をセット
					l_outtsukiwarifrom := l_instcalcymd;

				END IF;

			--初期以外の場合（初期・終期・期中区分<>1）
			ELSE

				--計算終了日が月割期間Toより後の場合
				IF l_inedcalcymd > l_outtsukiwarito THEN

					--月割期間Toに計算終了日をセット
					l_outtsukiwarito := l_inedcalcymd;

				END IF;

			END IF;

		END IF;

		--  ここまで通ったら正常終了
		extra_param := pkConstant.SUCCESS();
		RETURN;


	EXCEPTION

	--  全ての例外はここで受ける
	WHEN OTHERS THEN

		--  エラーがあった場合には、エラー内容を出力する
		CALL pkLog.FATAL('', '', SQLSTATE || SUBSTR(SQLERRM, 1, 50));

		--  処理場はエラーで返す
		extra_param := pkConstant.FATAL();
		RETURN;
END $$ LANGUAGE PLPGSQL;


	/********************************************************************************
	 * 日数取得<br>
	 * リストの値を参照し、日数、日割部分From、日割部分To
	 * を取得する
	 *
	 * @param  l_instcalcymd			計算開始日
	 * @param  l_inedcalcymd			計算終了日
	 * @param  l_indaymonthkbn			端数期間日割月割区分
	 * @param  l_incalcymdkbn			計算期間区分 ※getDataFromToでは不要
	 * @param  l_inmatsuFlg				計算期間月末フラグ２
	 * @param  l_intsukiwarifrom		月割期間From
	 * @param  l_intsukiwarito			月割期間To
	 * @param  l_intsukisu				月数
	 * @param  l_inhasutsuki			端数月

	 * @param  l_infirstlastkichukbn	初期・終期・期中区分
	 * @param  l_inhasunissukbn			端数日数計算区分
	 * @param  l_inoutoudd				応答日
	 * @param  l_insscalcymd2           計算期間２

	 * @param  l_outhiwarifrom			日割期間From
	 * @param  l_outhiwarito			日割期間To
	 * @param  l_outnissu				日数
	 * @param  l_outhankanenoutkbn		半か年外出し区分

	 * @return l_return				正常終了/異常終了
	********************************************************************************/
CREATE OR REPLACE FUNCTION pkipakichutesuryo.getdatefromto (
	l_instcalcymd CHAR,
	l_inedcalcymd CHAR,
	l_indaymonthkbn CHAR,
	l_incalcymdkbn CHAR,
	l_inmatsuFlg CHAR,
	-- 計算期間月末フラグ２
	l_intsukiwarifrom INOUT CHAR,
	l_intsukiwarito INOUT CHAR,
	l_intsukisu INOUT numeric,
	l_inhasutsuki INOUT CHAR,
	l_infirstlastkichukbn CHAR,
	l_inhasunissukbn CHAR,
	l_inoutoudd numeric,
	l_insscalcymd2 CHAR,
	l_outhiwarifrom OUT CHAR,
	l_outhiwarito OUT CHAR,
	l_outnissu OUT CHAR,
	l_outhankanenoutkbn OUT CHAR,
	OUT extra_param numeric
) RETURNS record AS $$ DECLARE


	/* ==変数定義=================================*/

	l_tmpymd				char(8);    --対象日（計算用年月日一時取得）
	l_tmpKijyunYmd			char(8);	--計算基準日
	l_tmpLastDay			char(8);	--月末日
	/* ==　処理　=================================*/


BEGIN

		-- OUT変数の初期化
		l_outhiwarifrom     := ' ';
		l_outhiwarito       := ' ';
		l_outnissu          := ' ';
		l_outhankanenoutkbn := ' ';

		--半か年外出し区分 初期値セット(2：外出しなし)
		l_outhankanenoutkbn := 2;

		-- 端数期間日割月割区分＝月割日割の場合
		IF l_indaymonthkbn = '1' THEN

			--計算開始日〜計算終了日の期間に端数日数がある場合のみ
			--IF MOD(MONTHS_BETWEEN(l_instcalcymd,l_tmpymd), 1) > 0 THEN
			IF nullif(trim(both l_inhasutsuki), '') is not null THEN

				--初期の場合（初期・終期・期中区分＝1）
				IF l_infirstlastkichukbn = 1 THEN
					--日割部分Fromに計算開始日をセット
					l_outhiwarifrom := l_instcalcymd;
					--日割期間Toに、月割期間Fromの前日をセット
					l_outhiwarito := TO_CHAR(TO_DATE(l_intsukiwarifrom, 'YYYYMMDD') - 1 ,'YYYYMMDD');

				--期中、終期の場合（初期・終期・期中区分<>1）
				ELSE
					--日割部分Fromに、月割期間Toの翌日をセット
					l_outhiwarifrom := TO_CHAR(TO_DATE(l_intsukiwarito, 'YYYYMMDD') + 1 ,'YYYYMMDD');
					--日割期間Toに、計算終了日をセット
					l_outhiwarito := l_inedcalcymd;

				END IF;

			END IF;

		-- 端数期間日割月割区分＝日割の場合
		ELSE
			--日割なので月割部分From-Toを初期化
			l_intsukiwarifrom := ' ';
			l_intsukiwarito   := ' ';

			--日割部分Fromに計算開始日をセット
			l_outhiwarifrom := l_instcalcymd;
			--日割期間Toに、計算終了日をセット
			l_outhiwarito := l_inedcalcymd;

			--端数日数分母計算区分=4（半か年実日数）の場合、半か年外出しする
			IF l_inhasunissukbn = '4' THEN

				--半か年分を外出しするために月割部分と日割部分を取得する処理
				--初期の場合（初期・終期・期中区分＝1）
				IF l_infirstlastkichukbn = 1 THEN

					---------------------------------------------------------
					-- 計算終了日＋１日からみて（12/年回数）ヵ月前の応答日を算出
					---------------------------------------------------------
					l_tmpKijyunYmd := TO_CHAR(TO_DATE(l_inedcalcymd, 'YYYYMMDD') + 1, 'YYYYMMDD');

					-- 基準日からの前回応答日を算出
					l_tmpymd := pkipakichutesuryo.getoutoymd(l_tmpKijyunYmd, l_insscalcymd2, -(l_inoutoudd), l_inmatsuFlg);

					-- 応答日が計算開始日より未来である場合に外出しする処理
					IF (l_instcalcymd <= l_tmpymd) THEN

						--端数月をセット … 計算開始年月
						l_inhasutsuki := SUBSTR(l_instcalcymd,1,6);

						--月数をセット … 応答日を月数としてそのままセット
						l_intsukisu := l_inoutoudd;

						-- 応答日が計算開始日より未来である場合に日割期間From-Toをセット
						IF (l_instcalcymd < l_tmpymd) THEN
							--日割期間Fromをセット … 計算開始日
							l_outhiwarifrom := l_instcalcymd;

							--日割期間Toをセット … 対象日
							l_outhiwarito   := TO_CHAR(TO_DATE(l_tmpymd, 'YYYYMMDD') - 1, 'YYYYMMDD');
						END IF;

						-- 応答日が計算開始日と同日の場合は日割期間From-Toに空文字セット
						-- (外出しして日割期間がなくなるため)
						IF (l_instcalcymd = l_tmpymd) THEN
							l_outhiwarifrom := ' ';  -- 計算開始日
							l_outhiwarito   := ' ';  -- 計算終了日
						END IF;

						--月割期間Fromをセット … 対象日＋1日（両端日数のため）
						l_intsukiwarifrom := TO_CHAR(TO_DATE(l_tmpymd, 'YYYYMMDD') + 1 ,'YYYYMMDD');

						--月割期間Toをセット … 計算終了日
						l_intsukiwarito := l_inedcalcymd;

						--半か年外出し区分に1（外出しあり）をセット
						l_outhankanenoutkbn := 1;

					END IF;

				--初期以外の場合（初期・終期・期中区分＜＞1）
				ELSE

					---------------------------------------------------------
					-- 計算開始日からみて（12/年回数）ヵ月後の応答日を算出
					---------------------------------------------------------
					-- 計算開始日からの次回応答日を算出
					l_tmpKijyunYmd := l_instcalcymd;

					-- 基準日からの次回応答日を算出
					l_tmpymd := pkipakichutesuryo.getoutoymd(l_tmpKijyunYmd, l_insscalcymd2, l_inoutoudd, l_inmatsuFlg);

					-- 応答日が計算終了日より過去の場合に外出しする処理
					IF (to_char(to_date(l_inedcalcymd, 'YYYYMMDD') + 1, 'YYYYMMDD') >= l_tmpymd) THEN

						--端数月をセット … 計算終了年月
						l_inhasutsuki := SUBSTR(l_inedcalcymd,1,6);

						--月数をセット … 応答日を月数としてそのままセット
						l_intsukisu := l_inoutoudd;

						--月割期間Fromをセット … 計算開始日
						l_intsukiwarifrom := l_instcalcymd;

						--月割期間Toをセット … 対象日−1日（両端日数のため）
						l_intsukiwarito := TO_CHAR(TO_DATE(l_tmpymd, 'YYYYMMDD') - 1 ,'YYYYMMDD');

						-- 応答日が計算終了日より過去の場合に日割期間From-Toをセット
						IF (to_char(to_date(l_inedcalcymd, 'YYYYMMDD') + 1, 'YYYYMMDD') > l_tmpymd) THEN
							--日割期間Fromをセット … 対象日
							l_outhiwarifrom := TO_CHAR(TO_DATE(l_tmpymd, 'YYYYMMDD') ,'YYYYMMDD');

							--日割期間Toをセット … 計算終了日
							l_outhiwarito   := l_inedcalcymd;
						END IF;

						-- 応答日が計算終了日と同日の場合は日割期間From-Toに空文字セット
						-- (外出しして日割期間がなくなるため)
						IF (to_char(to_date(l_inedcalcymd, 'YYYYMMDD') + 1, 'YYYYMMDD') = l_tmpymd) THEN
							l_outhiwarifrom := ' ';  -- 計算開始日
							l_outhiwarito   := ' ';  -- 計算終了日
						END IF;

						--半か年外出し区分に1（外出しあり）をセット
						l_outhankanenoutkbn := 1;

					END IF;

				END IF;

			END IF;

		END IF;

		IF nullif(trim(both l_outhiwarifrom), '') IS NOT NULL THEN
			--日割部分の日数をセットする
			l_outnissu := ABS(TO_DATE(l_outhiwarifrom, 'YYYYMMDD') - (TO_DATE(l_outhiwarito, 'YYYYMMDD'))) + 1;
			ELSE
			l_outnissu := 0;
		END IF;

		extra_param := pkConstant.SUCCESS();

		RETURN;

	EXCEPTION
		WHEN OTHERS THEN
			CALL pkLog.FATAL('', '', SQLSTATE || SUBSTR(SQLERRM, 1, 50));
			extra_param := pkConstant.FATAL();
			RETURN;END $$ LANGUAGE PLPGSQL;

	/********************************************************************************
	 * 手数料計算<br>
	 * リストの値を参照して、期中手数料を計算し戻り値に
	 * セットする
	 *
	 * @param  l_inszeiprocess			消費税算出方式（総額：0　従来：1）
	 * @param  l_instcalcymd			計算開始日
	 * @param  l_intsukiwarifrom		月割期間From
	 * @param  l_inhiwarifrom			日割期間From
	 * @param  l_incalcpatterncd		手数料計算パターン
	 * @param  l_intsukisu				月数
	 * @param  l_inkjnzndk				基準残高
	 * @param  l_inteigakutesukngk		定額期中手数料
	 * @param  l_insstesubunshi			手数料率（分子）
	 * @param  l_insstesubunbo			手数料率（分母）
	 * @param  l_inchokyuymd			徴求日
	 * @param  l_inhakkotsukacd			発行通貨コード
	 * @param  l_inszeiseikyukbn		消費税請求区分
	 * @param  l_inkeisanyydd			計算年月1〜13
	 * @param  l_intsukizndk			月毎残高1〜13
	 * @param  l_inanbunbunshi			期間按分分子
	 * @param  l_inanbunbunbo			期間按分分母
	 * @param  l_inhasunissucalckbn		端数日数計算区分
	 * @param  l_inssnenchokyucnt		年徴求回数

	 * @param  l_outtesuryo				期中手数料（税込）
	 * @param  l_outtesuryozei			期中手数料消費税
	 * @param  l_outtesuryonuki			期中手数料（税抜）
	 * @param  l_outtsukitesuryo		月毎手数料1〜13

	 * @return l_return					正常終了/異常終了
	********************************************************************************/
CREATE OR REPLACE FUNCTION pkipakichutesuryo.calctesuryo (
    l_inszeiprocess VARCHAR,
    l_instcalcymd CHAR,
    l_intsukiwarifrom CHAR,
    l_inhiwarifrom CHAR,
    l_incalcpatterncd CHAR,
    l_intsukisu numeric,
    l_inkjnzndk INOUT numeric,
    l_inteigakutesukngk numeric,
    l_insstesubunshi numeric,
    l_insstesubunbo numeric,
    l_inchokyuymd CHAR,
    l_inhakkotsukacd CHAR,
    l_inszeiseikyukbn CHAR,
    l_keisanyydd pkipakichutesuryo.ch6_array,
    l_intsukizndk pkipakichutesuryo.num_array,
    l_inanbunbunshi numeric,
    l_inanbunbunbo numeric,
    l_inhasunissucalckbn CHAR,
    l_inssnenchokyucnt numeric,
    l_outtesuryo OUT numeric,
    l_outtesuryozei OUT numeric,
    l_outtesuryonuki OUT numeric,
    l_outtsukitesuryo OUT pkipakichutesuryo.num_array,
    OUT extra_param numeric
) RETURNS record AS $$ DECLARE


	/* ==変数定義=================================*/

	 l_return					numeric := 0;

	 l_tsukisu					numeric := 0;
	 l_kjnzndk					numeric := 0;
	 l_teigakutesukngk			numeric := 0;
	 l_sstesubunshi				numeric := 0;
	 l_sstesubunbo 				numeric := 0;
	 l_ssnenchokyucnt			numeric := 0;
	 l_anbunbunshi				numeric := 0;
	 l_anbunbunbo				numeric := 0;

	 l_tesuryomm				numeric := 0;
	 l_tesuryodd				numeric := 0;

	 l_loopcnt					numeric := 0;
	 l_hankanencnt				numeric := -1;

	 l_tmpsumtesuryo			numeric := 0;
	 l_tmpsumzndk				numeric := 0;

	 l_hiwariindex				numeric := -1;	--日割部分がある場合のインデックス
	 l_szeiritsu				numeric := 0;	--消費税率
	 l_tsukaketa				integer := 0;	--小数点以下の桁数
	 l_cnt						numeric := 0; --平均残高計算用カウント
	/* ==　処理　=================================*/


BEGIN
		--inパラメータ数値項目Nullの場合の初期化
		l_tsukisu := coalesce(l_intsukisu,0);
		l_kjnzndk := coalesce(l_inkjnzndk,0);
		l_teigakutesukngk := coalesce(l_inteigakutesukngk,0);
		l_sstesubunshi := coalesce(l_insstesubunshi,0);
		l_sstesubunbo := coalesce(l_insstesubunbo,0);
		l_anbunbunshi := coalesce(l_inanbunbunshi,0);
		l_anbunbunbo := coalesce(l_inanbunbunbo,0);

		-- コレクションの初期化
		LOOP
			l_outtsukitesuryo[l_loopcnt] := 0;
			l_loopcnt := l_loopcnt + 1;
			EXIT WHEN l_loopcnt > 12;
		END LOOP;
		l_loopcnt := 0;

		/* 消費税計算用 */

		l_szeiritsu := 0;
		IF l_inszeiseikyukbn = '1' THEN   -- 消費税「請求する」の場合
			l_szeiritsu := PKIPAZEI.getShohiZei(l_inchokyuymd);	 -- 消費税率取得
		END IF;

		/* JPYまたは外貨の場合の小数点以下の桁数 */

		l_tsukaketa := 0;
		IF l_inhakkotsukacd <> 'JPY' THEN
			l_tsukaketa := 2;		-- JPY以外なら小数点以下2桁まで
		END IF;

		-- 計算パターンごとに、月割部分の手数料を求める（単位未満切捨て）
		CASE l_incalcpatterncd
			-- 残高基準日方式
			WHEN '1' THEN
				-- 期中手数料（月割部分）
				IF l_sstesubunbo <> 0 THEN
					-- 総額方式の場合
					IF l_inszeiprocess = '0' THEN
						l_tesuryomm := TRUNC(l_kjnzndk * l_sstesubunshi / l_sstesubunbo * l_tsukisu / 12 * ( 1 + l_szeiritsu), l_tsukaketa);
					-- 従来方式の場合
					ELSIF l_inszeiprocess = '1' THEN
						l_tesuryomm := trunc(l_kjnzndk * l_sstesubunshi / l_sstesubunbo * l_tsukisu / 12, l_tsukaketa);
					END IF;
				END IF;
			-- 平均残高方式
			WHEN '2' THEN
				LOOP
					-- 日割部分がある場合、そのIndexを一時保存
					IF nullif(trim(both l_inhiwarifrom), '') IS NOT NULL AND SUBSTR(l_inhiwarifrom,1,6) = l_keisanyydd[l_loopcnt] THEN
						l_hiwariindex := l_loopcnt;
					END IF;

					IF SUBSTR(l_instcalcymd,1,6) <= l_keisanyydd[l_loopcnt] AND l_hankanencnt < l_intsukisu THEN
						-- 計算期間内全ての月の残高を加算
						l_tmpsumzndk := l_tmpsumzndk + l_intsukizndk[l_loopcnt];
						l_hankanencnt := l_hankanencnt + 1;
					END IF;

					l_loopcnt := l_loopcnt + 1;
					EXIT WHEN l_loopcnt > 12;
				END LOOP;

				-- 日割部分がある場合は月数＋１
				IF l_hiwariindex >= 0 THEN
					l_cnt := l_tsukisu + 1;
				ELSE
					l_cnt := l_tsukisu;
				END IF;

				-- 計算パターンが平均計算方式の場合、月割部分の平均残高を基準残高にセットする（国内、外貨に関わらず小数部分切捨て）
				l_inkjnzndk := trunc(l_tmpsumzndk / l_cnt, 0);

				-- 期中手数料（月割部分）
				-- 一ヶ月あたりの平均残高×手数料率×月数
				IF l_tsukisu > 0 THEN

					-- 手数料を計算
					IF l_sstesubunbo <> 0 THEN
						-- 総額方式の場合
						IF l_inszeiprocess = '0' THEN
							l_tesuryomm := TRUNC(l_inkjnzndk * l_sstesubunshi / l_sstesubunbo * l_tsukisu / 12 * ( 1 + l_szeiritsu), l_tsukaketa);
						-- 従来方式の場合
						ELSIF l_inszeiprocess = '1' THEN
							l_tesuryomm := trunc(l_inkjnzndk * l_sstesubunshi / l_sstesubunbo * l_tsukisu / 12, l_tsukaketa);
						END IF;
					END IF;
				END IF;

			-- 5'（平均残高（後除算）方式）
			WHEN '5' THEN
				LOOP
					-- 日割部分がある場合、そのIndexを一時保存
					IF nullif(trim(both l_inhiwarifrom), '') IS NOT NULL AND SUBSTR(l_inhiwarifrom,1,6) = l_keisanyydd[l_loopcnt] THEN
						l_hiwariindex := l_loopcnt;
					END IF;

					IF SUBSTR(l_instcalcymd,1,6) <= l_keisanyydd[l_loopcnt] AND l_hankanencnt < l_intsukisu THEN
						-- 計算期間内全ての月の残高を加算
						l_tmpsumzndk := l_tmpsumzndk + l_intsukizndk[l_loopcnt];
						l_hankanencnt := l_hankanencnt + 1;
					END IF;

					l_loopcnt := l_loopcnt + 1;
					EXIT WHEN l_loopcnt > 12;
				END LOOP;

				-- 日割部分がある場合は月数＋１
				IF l_hiwariindex >= 0 THEN
					l_cnt := l_tsukisu + 1;
				ELSE
					l_cnt := l_tsukisu;
				END IF;

				-- 計算パターンが平均残高（後除算）方式）の場合、基準残高にセットする（国内、外貨に関わらず小数部分切捨て）
				l_inkjnzndk := trunc(l_tmpsumzndk , 0);

				-- 総額方式の場合
				IF l_inszeiprocess = '0' THEN
					l_tesuryomm := TRUNC(l_inkjnzndk * l_sstesubunshi / l_sstesubunbo * 1 / 12 * ( 1 + l_szeiritsu), l_tsukaketa);
				-- 従来方式の場合
				ELSIF l_inszeiprocess = '1' THEN
					l_tesuryomm := trunc(l_inkjnzndk * l_sstesubunshi / l_sstesubunbo * 1 / 12, l_tsukaketa);
				END IF;

			-- 月毎計算方式
			WHEN '3' THEN
				LOOP
					l_outtsukitesuryo[l_loopcnt] := 0;

					-- 日割部分がある場合、そのIndexを一時保存
					IF nullif(trim(both l_inhiwarifrom), '') IS NOT NULL AND SUBSTR(l_inhiwarifrom,1,6) = l_keisanyydd[l_loopcnt] THEN
						l_hiwariindex := l_loopcnt;
					END IF;

					-- 月割部分のみ期中手数料（月割部分）を計算する
					IF SUBSTR(l_intsukiwarifrom,1,6) <= l_keisanyydd[l_loopcnt] AND l_hankanencnt < l_intsukisu AND l_hiwariindex <> l_loopcnt THEN
						-- 月割期間内の一ヶ月ごとの手数料を計算（月毎に単位未満切捨）
						IF l_sstesubunbo <> 0 THEN
							-- 総額方式の場合
							IF l_inszeiprocess = '0' THEN
								l_outtsukitesuryo[l_loopcnt] := TRUNC(l_intsukizndk[l_loopcnt] * l_sstesubunshi / l_sstesubunbo / 12 * ( 1 + l_szeiritsu), l_tsukaketa);
							-- 従来方式の場合
							ELSIF l_inszeiprocess = '1' THEN
								l_outtsukitesuryo[l_loopcnt] := trunc(l_intsukizndk[l_loopcnt] * l_sstesubunshi / l_sstesubunbo / 12, l_tsukaketa);
							END IF;
						END IF;
						-- 計算した手数料を加算
						l_tmpsumtesuryo := l_tmpsumtesuryo + l_outtsukitesuryo[l_loopcnt];
						l_hankanencnt := l_hankanencnt + 1;
					END IF;
					l_loopcnt := l_loopcnt + 1;
					EXIT WHEN l_loopcnt > 12;
				END LOOP;
				--　手数料の合計金額を期中手数料（月割部分）の変数にセットする
				l_tesuryomm := l_tmpsumtesuryo;

				-- 計算パターンが月毎計算方式の場合、基準残高は登録しない
				l_inkjnzndk := 0;

			-- 定額方式・発行時一括
			ELSE
				--定額期中手数料を戻り値にセット
				-- 手数料（税抜）
				l_outtesuryonuki := l_teigakutesukngk;
				-- 消費税
				l_outtesuryozei := trunc(l_teigakutesukngk * l_szeiritsu, l_tsukaketa);

				-- 総額方式の場合
				IF l_inszeiprocess = '0' THEN
					-- 手数料（税込）
					l_outtesuryo := TRUNC(l_teigakutesukngk * (1 + l_szeiritsu), l_tsukaketa);
				-- 従来方式の場合
				ELSIF l_inszeiprocess = '1' THEN
					-- 手数料（税込）
					l_outtesuryo := l_outtesuryonuki + l_outtesuryozei;
				END IF;
		END CASE;

		-- 計算パターンが 残高基準日方式、月毎残高方式、平均残高方式、（平均残高（後除算）方式） の場合
		IF l_incalcpatterncd IN ('1','2','3','5') THEN
			-- 端数日数計算区分が半か年実日数以外の場合は、年徴求回数に１をセット)
			IF l_inhasunissucalckbn <> '4' THEN
				l_ssnenchokyucnt := 1;
			ELSE
				l_ssnenchokyucnt := l_inssnenchokyucnt;
			END IF;

			-- 期中手数料（日割部分）
			IF l_sstesubunbo <> 0 AND l_anbunbunbo <> 0 THEN
				-- 残高基準日方式の場合
				IF l_incalcpatterncd = '1' THEN
					-- 総額方式の場合
					IF l_inszeiprocess = '0' THEN
						l_tesuryodd := TRUNC(l_kjnzndk * l_sstesubunshi / l_sstesubunbo * l_anbunbunshi / l_anbunbunbo / l_ssnenchokyucnt * ( 1 + l_szeiritsu),l_tsukaketa);
					-- 従来方式の場合
					ELSIF l_inszeiprocess = '1' THEN
						l_tesuryodd := trunc(l_kjnzndk * l_sstesubunshi / l_sstesubunbo * l_anbunbunshi / l_anbunbunbo / l_ssnenchokyucnt, l_tsukaketa);
					END IF;

				-- 平均残高計算方式で日割部分がある場合、その月の手数料に端数分の手数料をセット
				--ELSIF l_incalcpatterncd = '2' AND l_hiwariindex >= 0 THEN
				-- 平均残高計算方式、（平均残高（後除算）方式）で日割部分がある場合、その月の手数料に端数分の手数料をセット
				ELSIF l_incalcpatterncd in ('2','5') AND l_hiwariindex >= 0 THEN
					-- 総額方式の場合
					IF l_inszeiprocess = '0' THEN
						l_tesuryodd := TRUNC(l_inkjnzndk * l_sstesubunshi / l_sstesubunbo * l_anbunbunshi / l_anbunbunbo / l_ssnenchokyucnt * ( 1 + l_szeiritsu),l_tsukaketa);
					-- 従来方式の場合
					ELSIF l_inszeiprocess = '1' THEN
						l_tesuryodd := trunc(l_inkjnzndk * l_sstesubunshi / l_sstesubunbo * l_anbunbunshi / l_anbunbunbo / l_ssnenchokyucnt, l_tsukaketa);
					END IF;
				-- 月毎残高計算方式で日割部分がある場合、その月の手数料に端数分の手数料をセット
				ELSIF l_hiwariindex >= 0 THEN
					-- 総額方式の場合
					IF l_inszeiprocess = '0' THEN
						l_tesuryodd := TRUNC(l_intsukizndk[l_hiwariindex] * l_sstesubunshi / l_sstesubunbo * l_anbunbunshi / l_anbunbunbo / l_ssnenchokyucnt * ( 1 + l_szeiritsu),l_tsukaketa);
					-- 従来方式の場合
					ELSIF l_inszeiprocess = '1' THEN
						l_tesuryodd := trunc(l_intsukizndk[l_hiwariindex] * l_sstesubunshi / l_sstesubunbo * l_anbunbunshi / l_anbunbunbo / l_ssnenchokyucnt, l_tsukaketa);
					END IF;
					l_outtsukitesuryo[l_hiwariindex] := l_tesuryodd;
				END IF;
			END IF;

			--期中手数料を戻り値にセット（月割部分＋日割部分＋定額手数料）
			-- 総額方式の場合
			IF l_inszeiprocess = '0' THEN
				-- 手数料（税込）
				l_outtesuryo := l_tesuryomm + l_tesuryodd + TRUNC(l_teigakutesukngk * (1 + l_szeiritsu),l_tsukaketa);
				-- 消費税
				l_outtesuryozei := TRUNC(l_outtesuryo * l_szeiritsu / (1 + l_szeiritsu), l_tsukaketa);
				-- 手数料（税抜）
				l_outtesuryonuki := l_outtesuryo - l_outtesuryozei;
			-- 従来方式の場合
			ELSIF l_inszeiprocess = '1' THEN
				-- 手数料（税抜）
				l_outtesuryonuki := l_tesuryomm + l_tesuryodd + l_teigakutesukngk;
				-- 消費税
				l_outtesuryozei := trunc(l_outtesuryonuki * l_szeiritsu, l_tsukaketa);
				-- 手数料（税込）
				l_outtesuryo := l_outtesuryonuki + l_outtesuryozei;
			END IF;
		END IF;

		extra_param := l_return;

		RETURN;

	EXCEPTION
		WHEN OTHERS THEN
		extra_param := pkConstant.FATAL();
		RETURN;
END $$ LANGUAGE PLPGSQL;

	/********************************************************************************
	 * 分配手数料計算<br>
	 * リストの値を参照して、期中手数料を計算し戻り値に
	 * セットする
	 *
	 * @param l_inszeiprocess           消費税算出方式（総額：0　従来：1）
	 * @param l_initakukaishacd       委託会社コード
	 * @param l_inbankcd   					  金融期間コード()
	 * @param l_inzentaitesuryogaku   全体手数料額（総額方式：税込、従来方式：税抜）
	 * @param l_inzentaitesuryozei  　全体手数料消費税（総額方式：内消費税、従来方式：消費税）
	 * @param l_inrowmaxbunpai        分配会社数
	 * @param l_inbunjtkkbn           受託区分()
	 * @param l_inbunkichubundfbunshi 分配期中分DF分子()
	 * @param l_insstesudfbunbo       信託報酬手数料DF分母()
	 * @param l_inchokyuymd           徴求日
	 * @param l_inhakkotsukacd        発行通貨
	 * @param l_inszeiseikyukbn       消費税請求区分

	 * @param  l_outbuntesuryogaku			  分配手数料金額()
	 * @param  l_outbuntesuryogakuzei		  分配手数料消費税()
	 * @param  l_outjikotesuryogaku			  自行手数料金額
	 * @param  l_outtakotesuryogaku		    自行手数料消費税
	 * @param  l_outjikotesuryogakuzei	  他行手数料金額
	 * @param  l_outtakotesuryogakuzei	  他行手数料消費税

	 * @return l_return					正常終了/異常終了
	********************************************************************************/
CREATE OR REPLACE FUNCTION pkipakichutesuryo.calcbunpaitesuryo (
    l_inszeiprocess VARCHAR,
    l_initakukaishacd CHAR,
    l_inbankcd pkipakichutesuryo.ch4_array,
    l_inzentaitesuryogaku numeric,
    l_inzentaitesuryozei numeric,
    l_inrowmaxbunpai numeric,
    l_inbunjtkkbn pkipakichutesuryo.ch1_array,
    l_inbunkichubundfbunshi pkipakichutesuryo.num_array,
    l_insstesudfbunbo numeric,
    l_inchokyuymd CHAR,
    l_inhakkotsukacd CHAR,
    l_inszeiseikyukbn CHAR,
    l_outbuntesuryogaku OUT pkipakichutesuryo.num_array,
    l_outbuntesuryogakuzei OUT pkipakichutesuryo.num_array,
    l_outjikotesuryogaku OUT numeric,
    l_outjikotesuryogakuzei OUT numeric,
    l_outtakotesuryogaku OUT numeric,
    l_outtakotesuryogakuzei OUT numeric,
    OUT extra_param numeric
) RETURNS record AS $$ DECLARE

	/* ==変数定義=================================*/

	l_rowcntbunpai				numeric	:= 0;
	l_rowdahyobunpai			numeric	:= 0;			--代表受託のIndex
	l_rowjikobunpai				numeric	:= 0;			--自行のIndex
	l_bunpaikngk		pkipakichutesuryo.num_array;							--分配手数料金額（総額方式：税込、従来方式：税抜）
	l_bunpaitotalkngk			numeric	:= 0;			--分配金額合計　全体手数料からこの額を引いて代表受託に加算する
	l_bunpaitotalzeikngk	numeric	:= 0;			--分配消費税合計　全体消費税からこの額を引いて代表受託に加算する
	l_szeiritsu				numeric := 0;	--消費税率
	l_tsukaketa				integer := 0;	--小数点以下の桁数
	l_hasukngk						numeric	:= 0;			--分配時の端数金額
	l_hasuzeikngk					numeric	:= 0;			--分配時の端数消費税
	/* ==　処理　=================================*/


BEGIN
		l_outjikotesuryogaku := 0;
		l_outtakotesuryogaku := 0;

		/* 消費税計算用 */

		l_szeiritsu := 0;
		IF l_inszeiseikyukbn = '1' THEN   -- 消費税「請求する」の場合
			l_szeiritsu := PKIPAZEI.getShohiZei(l_inchokyuymd);	 -- 消費税率取得
		END IF;

		/* JPYまたは外貨の場合の小数点以下の桁数 */

		l_tsukaketa := 0;
		IF l_inhakkotsukacd <> 'JPY' THEN
			l_tsukaketa := 2;		-- JPY以外なら小数点以下2桁まで
		END IF;

		-- ***** 手数料(税込)をまず分配する *****************************************************
		--取得した分配情報の件数分ループする
		FOR l_rowcntbunpai IN 0..l_inrowmaxbunpai LOOP

			-- 分配手数料（総額方式：税込、従来方式：税抜）を計算（全体手数料額×（分配率分子/分配率分母））単位未満切捨。
			l_bunpaikngk[l_rowcntbunpai] := trunc(l_inzentaitesuryogaku * l_inbunkichubundfbunshi[l_rowcntbunpai] / l_insstesudfbunbo, l_tsukaketa);

			-- 分配手数料の合計を加算
			l_bunpaitotalkngk := l_bunpaitotalkngk + l_bunpaikngk[l_rowcntbunpai];

			-- 代表受託の場合
			IF l_inbunjtkkbn[l_rowcntbunpai] = '1' THEN
				--代表受託のIndexを一時保存
				l_rowdahyobunpai := l_rowcntbunpai;
			END IF;

			--自行の場合(取得データの委託会社コードと金融機関コードが一致する場合)
			IF l_initakukaishacd = l_inbankcd[l_rowcntbunpai] THEN
				l_rowjikobunpai := l_rowcntbunpai;
			END IF;

		END LOOP;

		-- 全体手数料額（総額方式：税込、従来方式：税抜）から分配手数料の合計を引いて端数を求める
		l_hasukngk := l_inzentaitesuryogaku - l_bunpaitotalkngk;
		--分配手数料消費税の端数を代表受託に加算
		l_bunpaikngk[l_rowdahyobunpai] := l_bunpaikngk[l_rowdahyobunpai] + l_hasukngk;

		-- ***** 手数料(税込)を分配＆調整後に消費税を分配する ***********************************
		--再度取得した分配情報の件数分ループする
		FOR l_rowcntbunpai IN 0..l_inrowmaxbunpai LOOP

			-- 分配消費税を計算
			-- 総額方式の場合
			IF l_inszeiprocess = '0' THEN
				l_outbuntesuryogakuzei[l_rowcntbunpai] := TRUNC(l_bunpaikngk[l_rowcntbunpai] * l_szeiritsu / (1 + l_szeiritsu) ,l_tsukaketa);
			-- 従来方式の場合
			ELSIF l_inszeiprocess = '1' THEN
				l_outbuntesuryogakuzei[l_rowcntbunpai] := trunc(l_bunpaikngk[l_rowcntbunpai] * l_szeiritsu, l_tsukaketa);
			END IF;

			-- 分配消費税の合計を加算
			l_bunpaitotalzeikngk := l_bunpaitotalzeikngk + l_outbuntesuryogakuzei[l_rowcntbunpai];

		END LOOP;

		-- 全体消費税から、分配消費税の合計を引いて端数を求める
		l_hasuzeikngk := l_inzentaitesuryozei - l_bunpaitotalzeikngk;

		--分配手数料の端数を代表受託に加算
		l_outbuntesuryogakuzei[l_rowdahyobunpai] := l_outbuntesuryogakuzei[l_rowdahyobunpai] + l_hasuzeikngk;

		-- ***** 手数料(税込)から消費税を引いて税抜金額をセットする *****************************
		--再度取得した分配情報の件数分ループする
		FOR l_rowcntbunpai IN 0..l_inrowmaxbunpai LOOP
			-- 総額方式の場合
			IF l_inszeiprocess = '0' THEN
				-- 分配手数料(税抜)にセット（調整後の分配手数料金額（税込）−分配手数料消費税）
				l_outbuntesuryogaku[l_rowcntbunpai] := l_bunpaikngk[l_rowcntbunpai] - l_outbuntesuryogakuzei[l_rowcntbunpai];
			-- 従来方式の場合
			ELSIF l_inszeiprocess = '1' THEN
				-- 分配手数料(税抜)にセット
				l_outbuntesuryogaku[l_rowcntbunpai] := l_bunpaikngk[l_rowcntbunpai];
			END IF;
		END LOOP;

		--自行の手数料・消費税額を計算する
		l_outjikotesuryogaku    := l_outbuntesuryogaku[l_rowjikobunpai];
		l_outjikotesuryogakuzei := l_outbuntesuryogakuzei[l_rowjikobunpai];

		--他行の手数料・消費税額を計算する
		-- 総額方式の場合（手数料（税込）−内消費税−自行手数料）
		IF l_inszeiprocess = '0' THEN
			l_outtakotesuryogaku := l_inzentaitesuryogaku - l_inzentaitesuryozei - l_outjikotesuryogaku;
		-- 従来方式の場合（手数料（税抜）−自行手数料）
		ELSIF l_inszeiprocess = '1' THEN
			l_outtakotesuryogaku := l_inzentaitesuryogaku - l_outjikotesuryogaku;
		END IF;

		l_outtakotesuryogakuzei := l_inzentaitesuryozei - l_outjikotesuryogakuzei;

		extra_param := pkConstant.SUCCESS();

		RETURN;

	EXCEPTION
		WHEN OTHERS THEN
			extra_param := pkConstant.FATAL();
			RETURN;END $$ LANGUAGE PLPGSQL;


--******************** 利金計算でも使用する共通関数 ********************
	/**
	 * 期間按分取得関数<br>
	 *
	 * 引数の値と条件を元に、端数期間日数と按分の分母を算出し、期間按分を返す。
	 *
	 * ※当パッケージ内　各Function呼出元
	 *
	 * @param  l_inkeisanstart		計算期間S（日割部分From）
	 * @param  l_inkeisanend		計算期間E（日割部分To）
	 * @param  l_inchokyucnt		年徴求回数
	 * @param  l_indaycalckbn		実日数計算区分（端数期間分母日数計算区分）
	 * @param  l_infirstlastkichukbn	初回利払区分（初期・終期・期中区分）
	 * @param  l_inhankanenkbn		半か年区分
	 * @param  l_insscalcymd2       計算期間２

	 * @param  l_outkikananbun		期間按分
	 * @param  l_outbunshifrom		分子期間From
	 * @param  l_outbunshito		分子期間To
	 * @param  l_outanbunbunshi		期間按分分子
	 * @param  l_outbunbofrom		分母期間From
	 * @param  l_outbunboto			分母期間To
	 * @param  l_outanbunbunbo		期間按分分母

	 * @return l_return				正常終了/異常終了
	 */
CREATE OR REPLACE FUNCTION pkipakichutesuryo.getkikananbun (
	l_inkeisanstart CHAR,
	l_inkeisanend CHAR,
	l_inchokyucnt CHAR,
	l_indaycalckbn CHAR,
	l_inmatsuFlg CHAR,
	l_infirstlastkichukbn CHAR,
	l_inhankanenkbn CHAR,
	l_insscalcymd2 CHAR,
	l_outkikananbun OUT numeric,
	l_outbunshifrom OUT CHAR,
	l_outbunshito OUT CHAR,
	l_outanbunbunshi OUT numeric,
	l_outbunbofrom OUT CHAR,
	l_outbunboto OUT CHAR,
	l_outanbunbunbo OUT numeric,
	OUT extra_param numeric
) RETURNS record AS $$ DECLARE

	/*==============================================================================*/

	/*					変数定義													*/

	/*==============================================================================*/

	l_outoubi					numeric;		-- 応答日
	l_tmpKijyunYmd				char(8);	-- 計算基準日
	l_tmpLastDay				char(8);	-- 月末日
	l_tmpYmd					char(8);	-- 応答日
	/*==============================================================================*/

	/*	メイン処理	*/

	/*==============================================================================*/


BEGIN

		--OUT変数初期化
		l_outkikananbun  := 0;
		l_outanbunbunshi := 0;
		l_outbunbofrom   := ' ';
		l_outbunboto     := ' ';
		l_outanbunbunbo  := 0;
		-- 分子期間(日割期間)From-Toに計算期間From-Toをとりあえずセット
		l_outbunshifrom := l_inkeisanstart;
		l_outbunshito   := l_inkeisanend;

		IF nullif(trim(both l_inkeisanstart), '') IS NULL
			OR nullif(trim(both l_inkeisanend), '') IS NULL THEN

			extra_param := 0;

			RETURN;
		END IF;

		--応答日を取得（期中の月数）
		l_outoubi	 := 12 / l_inchokyucnt;

		-- 端数期間分母日数（期間按分分母）の取得（実日数計算区分＝1〜4）
		CASE l_indaycalckbn
			-- 365日
			WHEN 1 THEN
				l_outanbunbunbo := 365;

			-- 360日
			WHEN 2 THEN
				l_outanbunbunbo := 360;

			-- 閏年対応365日
			WHEN 3 THEN
				-- 初期の場合
				IF l_infirstlastkichukbn = 1 THEN
					--「計算期間E＋1」→「計算期間E＋1の1年前」の片端日数
					l_outanbunbunbo := ABS(TO_DATE(pkDate.getPlusDate(l_inkeisanend, 1), 'YYYYMMDD') - oracle.ADD_MONTHS(TO_DATE(pkDate.getPlusDate(l_inkeisanend, 1), 'YYYYMMDD'),-12));

				-- 初期以外の場合
				ELSE
					--「計算期間S」→「計算期間Sの1年後」の片端日数
					l_outanbunbunbo := ABS(oracle.ADD_MONTHS(TO_DATE(l_inkeisanstart,'YYYYMMDD'), 12) - TO_DATE(l_inkeisanstart, 'YYYYMMDD'));
				END IF;

			-- 半か年実日数
			WHEN 4 THEN
				-- 初期の場合
				IF l_infirstlastkichukbn = 1 THEN

					---------------------------------------------------------
					-- 計算終了日＋１日からみて（12/年回数）ヵ月前の応答日を算出
					---------------------------------------------------------
					l_tmpKijyunYmd := TO_CHAR(TO_DATE(l_inkeisanend, 'YYYYMMDD') + 1, 'YYYYMMDD');

					-- 基準日からの前回応答日を算出
					l_tmpymd := pkipakichutesuryo.getoutoymd(l_tmpKijyunYmd, l_insscalcymd2, -(l_outoubi), l_inmatsuFlg);

					--「計算期間E」→「計算期間Eの（応答日）ヶ月前」の片端日数
					l_outanbunbunbo := ABS(TO_DATE(l_tmpKijyunYmd, 'YYYYMMDD') - TO_DATE(l_tmpYmd, 'YYYYMMDD'));

				-- 初期以外の場合
				ELSE

					-- 計算開始日からの次回応答日を算出
					l_tmpKijyunYmd := l_inkeisanstart;

					-- 基準日からの次回応答日を算出
					l_tmpymd := pkipakichutesuryo.getoutoymd(l_tmpKijyunYmd, l_insscalcymd2, l_outoubi, l_inmatsuFlg);

					--「計算期間S」→「計算期間Sの（応答日）ヶ月後」の片端日数
					l_outanbunbunbo := ABS(TO_DATE(l_tmpYmd, 'YYYYMMDD') - TO_DATE(l_tmpKijyunYmd, 'YYYYMMDD'));

				END IF;

		END CASE;

		-- 分母期間From-Toのセット
		-- 初期の場合
		IF l_infirstlastkichukbn = 1 THEN
			-- 分母期間Fromに、計算終了日を基準に分母日数を引いた日付をセット
			l_outbunbofrom := TO_CHAR(TO_DATE(l_inkeisanend, 'YYYYMMDD')  -  l_outanbunbunbo,'YYYYMMDD');
			-- 分母期間Toに、計算期間Eをセット
			l_outbunboto   := l_inkeisanend;
		-- 初期以外の場合
		ELSE
			-- 分母期間Fromに、計算期間Sをセット
			l_outbunbofrom := l_inkeisanstart;
			-- 分母期間Toに、計算開始日を基準に分母日数を足した日付をセット
			l_outbunboto   := TO_CHAR(TO_DATE(l_inkeisanstart, 'YYYYMMDD') + l_outanbunbunbo,'YYYYMMDD');

		END IF;

		-- 端数日数（期間按分分子）を取得（計算期間S〜計算期間Eの片端日数）
		l_outanbunbunshi := ABS(TO_DATE(l_outbunshito, 'YYYYMMDD') - TO_DATE(l_outbunshifrom, 'YYYYMMDD')) + 1;

		-- 期間按分を取得（期間按分分子／期間按分分母）
		l_outkikananbun := l_outanbunbunshi / l_outanbunbunbo;

		extra_param := pkConstant.SUCCESS();

		RETURN;

	EXCEPTION
		WHEN OTHERS THEN
			extra_param := pkConstant.FATAL();
			RETURN;

END $$ LANGUAGE PLPGSQL;

	/********************************************************************************
     * 分配日算出処理。
     * 償還日から分配日を算出します。
     *
	 * @param l_inUserId   	    ユーザID
     * @param l_inShrYmd        支払日
     * @param l_inDistriTmg     分配タイミング
     * @param l_inDistriTmgDd   分配タイミング日付
	 * @return 			        分配日
    ********************************************************************************/
CREATE OR REPLACE FUNCTION pkipakichutesuryo.sfgetdistriymd (
	l_inUserId VARCHAR,
	l_inShrYmd MGR_SHOKIJ.SHOKAN_YMD % TYPE,
	l_inDistriTmg MGR_TESURYO_PRM.DISTRI_TMG % TYPE,
	l_inDistriTmgDd MGR_TESURYO_PRM2.DISTRI_TMG_DD % TYPE
) RETURNS varchar AS $$ DECLARE

    /*==============================================================================*/

	/*                  定数定義                                                    */

	/*==============================================================================*/

    /* 分配タイミング:10 徴求日当日 (コード種別:125) */

    	DISTRI_TMG_CURRENT_DAY CONSTANT varchar(2) := '10';
	/* 分配タイミング:11 徴求日の翌営業日 (コード種別:125) */

    	DISTRI_TMG_NEXT_DAY CONSTANT varchar(2) := '11';
	/* 分配タイミング:12 徴求日の翌翌営業日 (コード種別:125) */

    	DISTRI_TMG_DAY_AFTER_NEXT CONSTANT varchar(2) := '12';
	/* 分配タイミング:13 徴求日の３営業日後 (コード種別:125) */

		DISTRI_TMG_THREE_DAYS_AFTER CONSTANT varchar(2) := '13';
	/* 分配タイミング:21 徴求日の当月XX日 (コード種別:125) */

		DISTRI_TMG_THIS_MONTH_XX CONSTANT varchar(2) := '21';
	/* 分配タイミング:22 徴求日の翌月XX日 (コード種別:125) */

		DISTRI_TMG_NEXT_MONTH_XX CONSTANT varchar(2) := '22';
	/* 分配日地域コード（東京） */

		DISTRI_AREA_CD CONSTANT CHAR := pkConstant.TOKYO_AREA_CD();
   	/*==============================================================================*/

	/*					変数定義													*/

	/*==============================================================================*/

	/* 基準日 */

		wk_baseYmd varchar(8);
	/* 分配日 */

        wk_MG4_distriYmd MGR_TESKIJ.DISTRI_YMD%TYPE;
    /*==============================================================================*/

	/*	メイン処理	*/

	/*==============================================================================*/

BEGIN
		-- 初期化
		wk_baseYmd := NULL;
		wk_MG4_distriYmd := NULL;

        /* 分配日の取得 */

        CASE l_inDistriTmg
            WHEN DISTRI_TMG_CURRENT_DAY THEN
                wk_MG4_distriYmd := l_inShrYmd;
            WHEN DISTRI_TMG_NEXT_DAY THEN
                wk_MG4_distriYmd := pkDate.GETPLUSDATEBUSINESS(l_inShrYmd,1,DISTRI_AREA_CD);
            WHEN DISTRI_TMG_DAY_AFTER_NEXT THEN
                wk_MG4_distriYmd := pkDate.GETPLUSDATEBUSINESS(l_inShrYmd,2,DISTRI_AREA_CD);
            WHEN DISTRI_TMG_THREE_DAYS_AFTER THEN
                wk_MG4_distriYmd := pkDate.GETPLUSDATEBUSINESS(l_inShrYmd,3,DISTRI_AREA_CD);
            ELSE

				-- 基準日の算出
				IF l_inDistriTmg = DISTRI_TMG_THIS_MONTH_XX THEN
					-- 支払日の当月
					wk_baseYmd := l_inShrYmd;
				ELSIF l_inDistriTmg = DISTRI_TMG_NEXT_MONTH_XX THEN
					-- 支払日の翌月
					wk_baseYmd := pkDate.calcMonth(l_inShrYmd, 1);
				ELSE
					wk_MG4_distriYmd := NULL;
				END IF;

				IF wk_baseYmd IS NOT NULL THEN
					-- 分配タイミング日付≠'99'の場合
					IF sfIsMonthEndDd(l_inDistriTmgDd::varchar) = 0 THEN
						-- 分配日算出(月初からXX日の日付)
						wk_MG4_distriYmd := pkDate.getPlusDate(pkDate.getGesshoYmd(wk_baseYmd), l_inDistriTmgDd - 1);
						-- 徴求日の月と算出した分配日の月が異なっていれば、(徴求日の)月末営業日取得
						IF SUBSTR(wk_baseYmd, 5, 2) != SUBSTR(wk_MG4_distriYmd, 5, 2) THEN
							wk_MG4_distriYmd := pkDate.getGetsumatsuBusinessYmd(wk_baseYmd, 0, DISTRI_AREA_CD);
						-- 休みの場合、(算出した分配日の)前営業日取得
						ELSIF pkDate.isBusinessDay(wk_MG4_distriYmd, DISTRI_AREA_CD) = 1 THEN
							wk_MG4_distriYmd := pkDate.getZenBusinessYmd(wk_MG4_distriYmd, DISTRI_AREA_CD);
						END IF;
					ELSE
						-- (徴求日の)月末営業日取得
						wk_MG4_distriYmd := pkDate.getGetsumatsuBusinessYmd(wk_baseYmd, 0, DISTRI_AREA_CD);
					END IF;
				END IF;

        END CASE;
        RETURN wk_MG4_distriYmd;
    EXCEPTION
        WHEN OTHERS THEN
            CALL pkLog.DEBUG(l_inUserId,'pkIpaKichuTesuryo','分配日算出処理が失敗しました。');
            RAISE;
    END;

$$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipakichutesuryo.sfgetdistriymd ( l_inUserId VARCHAR, l_inShrYmd MGR_SHOKIJ.SHOKAN_YMD%TYPE, l_inDistriTmg MGR_TESURYO_PRM.DISTRI_TMG%TYPE, l_inDistriTmgDd MGR_TESURYO_PRM2.DISTRI_TMG_DD%TYPE ) FROM PUBLIC;

    /********************************************************************************
     * 銘柄_期中手数料回次削除。
     * 銘柄_期中手数料回次データを削除します。
     *
     * @param l_inUserId   		ユーザID
     * @param l_inItakuKaishaCd	委託会社コード
     * @param l_inMgrCd         銘柄コード
     * @param l_inShokanYmd     償還日
     * @param l_inTesuShuruiCd  手数料種類コード

	 * @return 					正常終了/異常終了
    ********************************************************************************/
CREATE OR REPLACE FUNCTION pkipakichutesuryo.sfdeletemgrteskij (
	l_inUserId VARCHAR,
	l_inItakuKaishaCd VARCHAR,
	l_inMgrCd MGR_KIHON.MGR_CD % TYPE,
	l_inShokanYmd MGR_TESKIJ.ED_CALC_YMD % TYPE,
	l_inTesuShuruiCd MGR_TESKIJ.TESU_SHURUI_CD % TYPE
) RETURNS numeric AS $$ BEGIN
    	/* 償還日から算出した日付よりも計算終了日が大きい回次を削除する。 */

        DELETE FROM
            MGR_TESKIJ MG4
        WHERE
            MG4.ITAKU_KAISHA_CD = l_inItakuKaishaCd
        AND MG4.MGR_CD = l_inMgrCd
        AND MG4.TESU_SHURUI_CD = l_inTesuShuruiCd
        AND MG4.ED_CALC_YMD > l_inShokanYmd;

        RETURN pkConstant.SUCCESS();
    EXCEPTION
        WHEN OTHERS THEN
            RETURN pkConstant.FATAL();
    END;

$$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipakichutesuryo.sfdeletemgrteskij ( l_inUserId VARCHAR, l_inItakuKaishaCd VARCHAR, l_inMgrCd MGR_KIHON.MGR_CD%TYPE, l_inShokanYmd MGR_TESKIJ.ED_CALC_YMD%TYPE, l_inTesuShuruiCd MGR_TESKIJ.TESU_SHURUI_CD%TYPE ) FROM PUBLIC;

    /********************************************************************************
     * 銘柄_期中手数料回次削除。
     * 指定の一意な銘柄_期中手数料回次データを削除します。
     * 削除後、歯抜けになった回次番号を更新します。
     *
     * @param l_inUserId   		ユーザID
     * @param l_inItakuKaishaCd	委託会社コード
     * @param l_inMgrCd         銘柄コード
     * @param l_inChokyuKjt     徴求期日
     * @param l_inTesuShuruiCd  手数料種類コード

	 * @return 					正常終了/異常終了
    ********************************************************************************/
CREATE OR REPLACE FUNCTION pkipakichutesuryo.sfdeletemgrteskijone (
	l_inUserId VARCHAR,
	l_inItakuKaishaCd VARCHAR,
	l_inMgrCd MGR_KIHON.MGR_CD % TYPE,
	l_inChokyuKjt MGR_TESKIJ.CHOKYU_KJT % TYPE,
	l_inTesuShuruiCd MGR_TESKIJ.TESU_SHURUI_CD % TYPE
) RETURNS numeric AS $$ DECLARE

    /*==============================================================================*/

	/*					変数定義													　　　 */

	/*==============================================================================*/

	/* タイムスタンプ */

    	wk_timestamp TIMESTAMP := TO_TIMESTAMP(pkDate.getCurrentTime(),'YYYY-MM-DD HH24:MI:SS.FF6');

BEGIN
    	/*指定の回次を削除する。 */

        DELETE FROM
            MGR_TESKIJ MG4
        WHERE
            MG4.ITAKU_KAISHA_CD = l_inItakuKaishaCd
        AND MG4.MGR_CD          = l_inMgrCd
        AND MG4.TESU_SHURUI_CD  = l_inTesuShuruiCd
        AND MG4.CHOKYU_KJT      = l_inChokyuKjt;

		UPDATE
			MGR_TESKIJ
		SET
			KAIJI = KAIJI -1,
            KOUSIN_ID = l_inUserId,
            LAST_TEISEI_ID = l_inUserId,
            LAST_TEISEI_DT = wk_timestamp
		WHERE
            ITAKU_KAISHA_CD = l_inItakuKaishaCd
        AND MGR_CD          = l_inMgrCd
		AND	TESU_SHURUI_CD  = l_inTesuShuruiCd
        AND CHOKYU_KJT      > l_inChokyuKjt;

        RETURN pkConstant.SUCCESS();
    EXCEPTION
        WHEN OTHERS THEN
            RETURN pkConstant.FATAL();
    END;

$$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipakichutesuryo.sfdeletemgrteskijone ( l_inUserId VARCHAR, l_inItakuKaishaCd VARCHAR, l_inMgrCd MGR_KIHON.MGR_CD%TYPE, l_inChokyuKjt MGR_TESKIJ.CHOKYU_KJT%TYPE, l_inTesuShuruiCd MGR_TESKIJ.TESU_SHURUI_CD%TYPE ) FROM PUBLIC;

	/********************************************************************************
	 * 銘柄_期中手数料回次更新<br>
	 * 銘柄_期中手数料回次を更新します。
	 *
	 * @param  l_inUserId   	    ユーザID
	 * @param  l_inItakuKaishaCd	委託会社コード
	 * @param  l_inMgrCd			銘柄コード
	 * @param  l_inShokanYmd		償還日
	 * @param  l_inAreaCd			地域コード

	 * @return 						正常終了/異常終了
	********************************************************************************/
CREATE OR REPLACE FUNCTION pkipakichutesuryo.sfreflectionmgrteskij ( l_inUserId VARCHAR, l_inItakuKaishaCd VARCHAR, l_inMgrCd MGR_KIHON.MGR_CD%TYPE, l_inShokanYmd MGR_SHOKIJ.SHOKAN_YMD%TYPE, l_inAreaCd MGR_KIHON_VIEW.AREACD%TYPE ) RETURNS numeric AS $$
DECLARE

	/*==============================================================================*/

	/*                  定数定義                                                    */

	/*==============================================================================*/

	/* 日数 */

    	NISSU CONSTANT smallint := 1;
    /* 処理区分 承認 */

    	SHORI_KBN_SHONIN CONSTANT MGR_KIHON.SHORI_KBN%TYPE := '1';
	/* 請求書出力休日区分 */

		BILLOUT_KYUJITSU_KBN CONSTANT CHAR := pkConstant.HORIDAY_SHORI_KBN_ZENEI(); -- IP-05977
	/* 請求書出力地域コード */

		BILLOUT_AREA_CD CONSTANT CHAR := pkConstant.TOKYO_AREA_CD(); -- IP-05977
	/*==============================================================================*/

	/*					変数定義													*/

	/*==============================================================================*/

	/* タイムスタンプ */

    	wk_timestamp TIMESTAMP := TO_TIMESTAMP(pkDate.getCurrentTime(),'YYYY-MM-DD HH24:MI:SS.FF6');
    /* 前取後取区分 */

        wk_zengoKbn MGR_TESURYO_PRM.ZENGO_KBN%TYPE;
    /* 繰上償還時償還期日算入フラグ */

        wk_kshokanKjtFlg MGR_TESURYO_PRM.KSHOKAN_KJT_FLG%TYPE;
    /* 計算終了日 */

        wk_EdCalcYmd MGR_TESKIJ.ED_CALC_YMD%TYPE;
    /* 繰上償還時徴求日区分 */

        wk_kuriageShokanChokyuKbn MGR_TESURYO_PRM.KURIAGE_SHOKAN_CHOKYU_KBN%TYPE;
    /* 繰上償還時徴求日付 */

        wk_kuriageShokanChokyuDd MGR_TESURYO_PRM.KURIAGE_SHOKAN_CHOKYU_DD%TYPE;
    /* 徴求期日 */

        wk_ChokyuKjt MGR_TESKIJ.CHOKYU_KJT%TYPE;
    /* 徴求日 */

        wk_ChokyuYmd MGR_TESKIJ.CHOKYU_YMD%TYPE;
    /* 受入日算出パターン */

        wk_UkeireYmdPattern MGR_TESURYO_PRM2.UKEIRE_YMD_PATTERN%TYPE;
    /* 期中管理手数料徴求タイミング１ */

        wk_KicyuKanriTesuChokyuTmg1 MGR_TESURYO_PRM2.KICYU_KANRI_TESU_CHOKYU_TMG1%TYPE;
    /* 期中管理手数料徴求タイミング２ */

        wk_KicyuKanriTesuChokyuTmg2 MGR_TESURYO_PRM2.KICYU_KANRI_TESU_CHOKYU_TMG2%TYPE;
    /* 期中管理手数料徴求タイミング日数 */

        wk_KicyuKanriTesuChokyuDd MGR_TESURYO_PRM2.KICYU_KANRI_TESU_CHOKYU_DD%TYPE;
    /* 分配日 */

        wk_DistriYmd MGR_TESKIJ.DISTRI_YMD%TYPE;
    /* 請求書出力日 */

        wk_billOutYmd MGR_TESKIJ.BILL_OUT_YMD%TYPE;
    /* 分配タイミング */

        wk_DistriTmg MGR_TESURYO_PRM.DISTRI_TMG%TYPE;
    /* 分配タイミング日付 */

        wk_DistriTmgDd MGR_TESURYO_PRM2.DISTRI_TMG_DD%TYPE;
    /* 信託報酬・社管手数料_徴求日休日処理区分 */

        wk_ssChokyuKyujitsuKbn MGR_TESURYO_PRM.SS_CHOKYU_KYUJITSU_KBN%TYPE;
    /* 請求書出力タイミング１ */

        wk_billOutTmg1 MGR_TESURYO_CTL.BILL_OUT_TMG1%TYPE;
    /* 請求書出力タイミング２ */

        wk_billOutTmg2 MGR_TESURYO_CTL.BILL_OUT_TMG2%TYPE;
    /* 請求書出力タイミング日数 */

        wk_billOutDd MGR_TESURYO_CTL.BILL_OUT_DD%TYPE;
    /* 件数 */

        wk_count smallint;
	/* ファンクション実行用*/

    	wk_result smallint;
	/*======================================================================*/

    /*   カーソル定義														*/

	/*======================================================================*/

	/* 手数料種類コード、徴求期日を取得します。 */

    c_getTesKij CURSOR(
            l_inItakuKaishaCd  MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE,
            l_inMgrCd  MGR_SHOKIJ.MGR_CD%TYPE,
            l_inShokanYmd  MGR_SHOKIJ.SHOKAN_YMD%TYPE
        ) FOR
        SELECT
            MG4.CHOKYU_KJT,
            MG4.TESU_SHURUI_CD
        FROM
            MGR_TESKIJ MG4
        WHERE
            MG4.ITAKU_KAISHA_CD = l_inItakuKaishaCd
        AND MG4.MGR_CD = l_inMgrCd
		AND	MG4.TESU_SHURUI_CD in ('11', '12')
        AND MG4.ST_CALC_YMD <= l_inShokanYmd
        AND l_inShokanYmd <= MG4.ED_CALC_YMD;
    c_getTeskijForInsert CURSOR(
            l_inItakuKaishaCd MGR_KIHON.ITAKU_KAISHA_CD%TYPE,
            l_inMgrCd  MGR_KIHON.MGR_CD%TYPE,
            l_inChokyuKjt  MGR_TESKIJ.CHOKYU_KJT%TYPE,
            l_inTesuShuruiCd  MGR_TESKIJ.TESU_SHURUI_CD%TYPE
        ) FOR
        SELECT
            MG4.*
        FROM
            MGR_TESKIJ MG4
        WHERE
            MG4.ITAKU_KAISHA_CD = l_inItakuKaishaCd
        AND MG4.MGR_CD = l_inMgrCd
        AND MG4.CHOKYU_KJT = l_inChokyuKjt
        AND MG4.TESU_SHURUI_CD = l_inTesuShuruiCd;
	/*==============================================================================*/

	/*	メイン処理																		*/

	/*==============================================================================*/

BEGIN
		FOR r_getTesKij IN c_getTesKij(
									l_inItakuKaishaCd,
									l_inMgrCd,
									l_inShokanYmd
									)
		LOOP
			/* 期中管理手数料 及び 期中信託報酬 回次データ削除 */

			FOR r_getTeskijForInsert IN c_getTeskijForInsert(
															l_inItakuKaishaCd,
															l_inMgrCd,
															r_getTesKij.CHOKYU_KJT,
															r_getTesKij.TESU_SHURUI_CD
															)
			LOOP
				/* 前取後取区分、償還日算入区分、繰上償還時徴求日区分、
				 * 繰上償還時徴求日付、分配タイミング、信託報酬・社管手数料_徴求日休日処理区分の取得 */
				SELECT	coalesce(MG8.ZENGO_KBN,' ') AS ZENGO_KBN,
						coalesce(MG8.KSHOKAN_KJT_FLG,' ') AS KSHOKAN_KJT_FLG,
						coalesce(MG8.KURIAGE_SHOKAN_CHOKYU_KBN,' ') AS KURIAGE_SHOKAN_CHOKYU_KBN,
						coalesce(MG8.KURIAGE_SHOKAN_CHOKYU_DD,0) AS KURIAGE_SHOKAN_CHOKYU_DD,
						coalesce(BT04.UKEIRE_YMD_PATTERN ,' ') AS UKEIRE_YMD_PATTERN,
						coalesce(BT04.KICYU_KANRI_TESU_CHOKYU_TMG1 ,' ') AS KICYU_KANRI_TESU_CHOKYU_TMG1,
						coalesce(BT04.KICYU_KANRI_TESU_CHOKYU_TMG2 ,' ') AS KICYU_KANRI_TESU_CHOKYU_TMG2,
						coalesce(BT04.KICYU_KANRI_TESU_CHOKYU_DD ,0) AS KICYU_KANRI_TESU_CHOKYU_DD,
						coalesce(MG8.DISTRI_TMG,' ') AS DISTRI_TMG,
						coalesce(BT04.DISTRI_TMG_DD ,0) AS DISTRI_TMG_DD,
						coalesce(MG8.SS_CHOKYU_KYUJITSU_KBN,' ') AS SS_CHOKYU_KYUJITSU_KBN
				INTO STRICT	wk_zengoKbn,
						wk_kshokanKjtFlg,
						wk_kuriageShokanChokyuKbn,
						wk_kuriageShokanChokyuDd,
						wk_UkeireYmdPattern,
						wk_KicyuKanriTesuChokyuTmg1,
						wk_KicyuKanriTesuChokyuTmg2,
						wk_KicyuKanriTesuChokyuDd,
						wk_distriTmg,
						wk_distriTmgDd,
						wk_SsChokyuKyujitsuKbn
				FROM mgr_kihon_view mg1
LEFT OUTER JOIN mgr_tesuryo_prm mg8 ON (MG1.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD AND MG1.MGR_CD = MG8.MGR_CD)
LEFT OUTER JOIN mgr_tesuryo_prm2 bt04 ON (MG1.ITAKU_KAISHA_CD = BT04.ITAKU_KAISHA_CD AND MG1.MGR_CD = BT04.MGR_CD)
WHERE MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND MG1.MGR_CD = l_inMgrCd;

				/* 前取後取区分が「1：前取」の場合 */

				IF (wk_zengoKbn = '1') THEN

					/* 当該徴求期日より未来の手数料回次を削除 */

					DELETE
					FROM	MGR_TESKIJ MG4
					WHERE	MG4.ITAKU_KAISHA_CD = l_inItakuKaishaCd
					AND		MG4.MGR_CD = l_inMgrCd
					AND		MG4.CHOKYU_KJT > r_getTeskijForInsert.CHOKYU_KJT
					AND		MG4.TESU_SHURUI_CD = r_getTeskijForInsert.TESU_SHURUI_CD;

				/* 前取後取区分が「2：後取」の場合 */

				ELSIF (wk_zengoKbn = '2') THEN

					/* 請求書出力タイミング情報取得 */

					SELECT	coalesce(MG7.BILL_OUT_TMG1,' ') AS BILL_OUT_TMG1,
							coalesce(MG7.BILL_OUT_TMG2,' ') AS BILL_OUT_TMG2,
							coalesce(MG7.BILL_OUT_DD,0) AS BILL_OUT_DD
					INTO STRICT	wk_billOutTmg1,
							wk_billOutTmg2,
							wk_billOutDd
					FROM mgr_kihon_view mg1
LEFT OUTER JOIN mgr_tesuryo_ctl mg7 ON (MG1.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD AND MG1.MGR_CD = MG7.MGR_CD)
, r_getteskijforinsert
LEFT OUTER JOIN mgr_tesuryo_ctl mg7 ON (r_getTeskijForInsert.TESU_SHURUI_CD = MG7.TESU_SHURUI_CD)
WHERE MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND MG1.MGR_CD = l_inMgrCd;

					/* 償還日算入区分 = 算入しないなら償還日の前日を取得 */

					IF wk_kshokanKjtFlg = '0' THEN
						wk_EdCalcYmd := pkDate.GETMINUSDATE(l_inShokanYmd,NISSU);
					ELSE
						wk_EdCalcYmd := l_inShokanYmd;
					END IF;

					/* 徴求期日の取得 */

					wk_ChokyuKjt := coalesce(sfCalcChokyuKjt(
														l_inShokanYmd,
														r_getTeskijForInsert.CHOKYU_KJT,
														wk_kuriageShokanChokyuKbn,
														wk_kuriageShokanChokyuDd,
														l_inAreaCd
														),' ');

					/* 徴求期日が取得できれば、徴求日も取得 */

					IF nullif(trim(both wk_ChokyuKjt), '') IS NOT NULL THEN
						-- 徴求期日の休日補正後を算出する（受入日算出パターン＝1：受入日基準 の場合、これをそのまま徴求日とする）
						wk_ChokyuYmd := coalesce(pkDate.calcDateKyujitsuKbn(wk_ChokyuKjt,0,wk_ssChokyuKyujitsuKbn,l_inAreaCd),' ');

						-- 受入日算出パターン≠1（受入日基準）の場合、期中管理手数料徴求タイミングから徴求日を算出する
						IF nullif(trim(both wk_UkeireYmdPattern), '') IS NOT NULL AND wk_UkeireYmdPattern <> '1' THEN
							wk_ChokyuYmd := coalesce(sfCalcTmgYmd(
												wk_ChokyuKjt,
												wk_ChokyuYmd,
												CASE wk_KicyuKanriTesuChokyuTmg1
													WHEN '4' THEN '1'
													WHEN '5' THEN '2'
													WHEN '6' THEN '3'
													ELSE wk_KicyuKanriTesuChokyuTmg1
												END,
												wk_KicyuKanriTesuChokyuDd,
												wk_KicyuKanriTesuChokyuTmg2,
												wk_ssChokyuKyujitsuKbn,
												l_inAreaCd
											),' ');
						END IF;
					ELSE
						wk_ChokyuYmd := ' ';
					END IF;

					/* 分配日の取得（徴求日ベース） */

					wk_DistriYmd := coalesce(pkIpaKichuTesuryo.sfGetDistriYmd(l_inUserId, wk_ChokyuYmd, wk_distriTmg, wk_distriTmgDd), ' ');

					/* 請求書出力日の取得 */

					wk_billOutYmd := coalesce(sfCalcTmgYmd(wk_ChokyuKjt,wk_ChokyuYmd,
													wk_billOutTmg1,wk_billOutDd,wk_billOutTmg2,
													BILLOUT_KYUJITSU_KBN,BILLOUT_AREA_CD),' '); -- IP-05977
					/* 該当回次の削除、以降回次の削除 */

					wk_result := pkIpaKichuTesuryo.sfDeleteMgrTeskij(l_inUserId,l_inItakuKaishaCd,l_inMgrCd, wk_EdCalcYmd, r_getTeskijForInsert.TESU_SHURUI_CD);

					IF wk_result <> pkConstant.SUCCESS() THEN
						CALL pkLog.FATAL('ECM701','pkIpaKichuTesuryo','委託会社コード = ' || l_inItakuKaishaCd || ' 銘柄コード = ' || l_inMgrCd);
           				CALL pkLog.FATAL('ECM701','pkIpaKichuTesuryo','該当回次の削除、以降回次の削除に失敗しました。');
		                RETURN wk_result;
		            END IF;

					/* 償還日から算出した計算終了日と計算終了日が一致する回次が銘柄_期中手数料回次テーブルにあるか検索する */

					SELECT
				        COUNT(*)
			        INTO STRICT
			            wk_count
			        FROM
       					MGR_TESKIJ MG4
    				WHERE
        				MG4.ITAKU_KAISHA_CD = l_inItakuKaishaCd
    				AND MG4.MGR_CD = l_inMgrCd
    				AND MG4.TESU_SHURUI_CD = r_getTeskijForInsert.TESU_SHURUI_CD
    				AND MG4.ED_CALC_YMD = wk_EdCalcYmd;

					/* 銘柄_期中手数料回次に該当レコードが存在しなかった場合、データの挿入を行う */

					IF wk_count = 0 THEN
						/* データの挿入 */

						INSERT
						INTO	MGR_TESKIJ(
								ITAKU_KAISHA_CD,
								MGR_CD,
								TESU_SHURUI_CD,
								CHOKYU_KJT,
								KAIJI,
								CHOKYU_YMD,
								DISTRI_YMD,
								CALC_PATTERN_CD,
								SS_TEIGAKU_TESU_KNGK,
								ZTEIGAKU_TESU_KNGK,
								ST_CALC_YMD,
								ED_CALC_YMD,
								ZNDK_KIJUN_YMD,
								BILL_OUT_YMD,
								GROUP_ID,
								SHORI_KBN,
								LAST_TEISEI_DT,
								LAST_TEISEI_ID,
								SHONIN_DT,
								SHONIN_ID,
								KOUSIN_ID,
								SAKUSEI_DT,
								SAKUSEI_ID
						) VALUES (
								l_inItakuKaishaCd,
								l_inMgrCd,
								r_getTeskijForInsert.TESU_SHURUI_CD,
								wk_ChokyuKjt,
								0,
								wk_ChokyuYmd,
								wk_DistriYmd,
								r_getTeskijForInsert.CALC_PATTERN_CD,
								r_getTeskijForInsert.SS_TEIGAKU_TESU_KNGK,
								r_getTeskijForInsert.ZTEIGAKU_TESU_KNGK,
								r_getTeskijForInsert.ST_CALC_YMD,
								wk_EdCalcYmd,
								r_getTeskijForInsert.ZNDK_KIJUN_YMD,
								wk_billOutYmd,
								r_getTeskijForInsert.GROUP_ID,
								SHORI_KBN_SHONIN,
								wk_timestamp,
								l_inUserId,
								wk_timestamp,
								l_inUserId,
								l_inUserId,
								wk_timestamp,
								l_inUserId
						);
					END IF;
				END IF;
			END LOOP;
		END LOOP;

		/* 手数料種類 = 事務手数料（期中）及び 財務代理人手数料（期中）及び 支払代理人手数料 及び その他期中手数料１の回次データ削除 */

		DELETE
		FROM	MGR_TESKIJ MG4
		WHERE	MG4.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND		MG4.MGR_CD = l_inMgrCd
		AND		MG4.TESU_SHURUI_CD in ('21', '22', '52', '91')
		AND		MG4.CHOKYU_YMD > l_inShokanYmd;

		/* 残高基準日方式かつ残高基準日≧償還日の場合は、残高基準日に繰上償還日前日をセットする */

		UPDATE
            	MGR_TESKIJ
        SET
            	ZNDK_KIJUN_YMD = pkDate.getMinusDate(l_inShokanYmd,1),
            	KOUSIN_ID = l_inUserId,
            	LAST_TEISEI_ID = l_inUserId,
            	LAST_TEISEI_DT = wk_timestamp
        WHERE
        		ITAKU_KAISHA_CD = l_inItakuKaishaCd
        AND		MGR_CD = l_inMgrCd
		AND		TESU_SHURUI_CD in ('11', '12')
		AND 	nullif(trim(both ZNDK_KIJUN_YMD), '') IS NOT NULL
        AND		ZNDK_KIJUN_YMD >= l_inShokanYmd;

		RETURN pkConstant.SUCCESS();
    EXCEPTION
        WHEN OTHERS THEN
            CALL pkLog.FATAL('ECM701','pkIpaKichuTesuryo','委託会社コード = ' || l_inItakuKaishaCd || ' 銘柄コード = ' || l_inMgrCd);
            CALL pkLog.FATAL('ECM701','pkIpaKichuTesuryo','銘柄_期中手数料回次への更新が失敗しました。');

            RETURN pkConstant.FATAL();
    END;

$$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipakichutesuryo.sfreflectionmgrteskij ( l_inUserId VARCHAR, l_inItakuKaishaCd VARCHAR, l_inMgrCd MGR_KIHON.MGR_CD%TYPE, l_inShokanYmd MGR_SHOKIJ.SHOKAN_YMD%TYPE, l_inAreaCd MGR_KIHON_VIEW.AREACD%TYPE ) FROM PUBLIC;

/*************************************************************************************/

	/********************************************************************************
	 * 月数取得(分かち計算用)<br>
	 * 分かち計算する・しないの判断を行い、分かち計算する場合は
	 * 改定前と改定後の月数を取得する
	 *
	 * @param  l_initakukaishaCd	CHAR  	委託会社コード
	 * @param  l_instcalcymd	CHAR  	計算開始日
	 * @param  l_inedcalcymd	CHAR	計算終了日
	 * @param  l_intsukisu		NUMERIC 月数
	 * @param  l_infirstlastkichukbn CHAR   初期・終期・期中区分
	 * @param  l_inszeiseikyukbn	CHAR 消費税を請求する(1)・しない(0)
	 * @param  l_outkeisanyymmdd	CHR_ARRAY 計算期間（年月日）※計算開始日〜終了日を月別に分解し、月の先頭日を設定する
	 * @param  l_outtsukisu_mae	NUMERIC 改定前の月数
	 * @param  l_outtsukisu_ato	NUMERIC 改定後の月数
	 * @param  l_outwakachi		CHAR   分かち計算する・しない
	 * @param  l_outtekiyost_ymd	CHAR   消費税適用日
	 * @param  l_outshohizei_sai	CHAR 消費税率の差異あり・なし ※差異なし=1 差異あり=0
	 *
	 * @return l_return  pkConstant.SUCCESS() 正常終了
	 *                   pkConstant.FATAL()   異常終了
	********************************************************************************/
CREATE OR REPLACE FUNCTION pkipakichutesuryo.getmonthfromto_wakachi (
    l_initakukaishaCd CHAR,
    l_instcalcymd CHAR,
    l_inedcalcymd CHAR,
    l_intsukisu numeric,
    l_infirstlastkichukbn CHAR,
    l_inszeiseikyukbn CHAR,
    l_outkeisanyymmdd OUT pkipakichutesuryo.chr_array,
    l_outtsukisu_mae OUT numeric,
    l_outtsukisu_ato OUT numeric,
    l_outwakachi OUT CHAR,
    l_outtekiyost_ymd OUT CHAR,
    l_outshohizei_sai OUT CHAR,
    OUT extra_param numeric
) RETURNS record AS $$ DECLARE


		wk_szeiritsu_mae	numeric;
		wk_szeiritsu_ato	numeric;
		wk_tekiyost_ymd		char(8); --yyyymmdd
		wk_cntMax numeric;	-- カウンタ(計算期間の月数）
		wk_tsukisu numeric;


BEGIN


		-- 消費税の差異あり(0)を初期値として設定
		l_outshohizei_sai :='0';

		-- カウンタ(計算期間の月数）
		wk_cntMax :=0;

		-- 分かち計算をしないを設定。
		l_outwakachi := '0';

		-- 消費税を請求しない場合
		IF l_inszeiseikyukbn <> '1' THEN
			-- 分かち計算をしないで復帰する。
			extra_param := pkConstant.SUCCESS();
			RETURN;
		END IF;

		--分かち計算する・しないを取得する。
		l_outwakachi := pkControl.getCtlValue(l_initakukaishaCd,'ShzWakachi','0');

		IF l_outwakachi <> '1' THEN

			-- 分かち計算をしない場合は復帰する。
			extra_param := pkConstant.SUCCESS();
			RETURN;
		END IF;

		--初期化
		wk_szeiritsu_mae :=0;
		wk_szeiritsu_ato :=0;

		--計算開始時点での消費税率を取得する。
		IF nullif(trim(both l_instcalcymd), '') IS NOT NULL THEN

			wk_szeiritsu_mae := PKIPAZEI.getShohiZei(l_instcalcymd);	 -- 改定前の消費税率取得
		END IF;

		--計算終了時点での消費税率を取得する。
		IF nullif(trim(both l_inedcalcymd), '') IS NOT NULL THEN

			wk_szeiritsu_ato := PKIPAZEI.getShohiZei(l_inedcalcymd);	 -- 改定後の消費税率取得
		END IF;

		IF wk_szeiritsu_mae = wk_szeiritsu_ato THEN

			-- 改定前と改定後の消費税率が同じ場合、分かち計算しない、消費税差異なし(1)を設定し、復帰する。
			l_outwakachi := '0';
			l_outshohizei_sai :='1';
			extra_param := pkConstant.SUCCESS();
			RETURN;
		END IF;

		l_outtsukisu_mae := 0;
		l_outtsukisu_ato := 0;

		-- 月数(WK)
		wk_tsukisu :=0;

		-- 月数がない場合（日割の場合）も定額手数料の計算で改定前、改定後の月数が必要なので、取得する様にする
		IF l_intsukisu = 0 THEN

			-- 月数が応答日ベースの場合、20130726-20140623の場合11ヶ月になる。
			wk_tsukisu := CEIL(oracle.MONTHS_BETWEEN( TO_DATE( l_inedcalcymd, 'YYYYMMDD' ) + 1, TO_DATE( l_instcalcymd, 'YYYYMMDD' )));
		ELSE
			wk_tsukisu := l_intsukisu;
		END IF;

		-- 改定後の適用開始日を取得する。
		l_outtekiyost_ymd := PKIPAZEI.getShohiZeiStYmd(l_inedcalcymd);

		IF l_infirstlastkichukbn = '1' THEN	--初期・終期・期中区分が初期(1)の場合
			--計算終了日+1から改定後の適用開始日の月数を取得 ※月のカウントは1/1〜1/31=0月、1/1〜2/1=1月
			l_outtsukisu_ato := FLOOR(oracle.MONTHS_BETWEEN( TO_DATE( l_inedcalcymd, 'YYYYMMDD' )+1, TO_DATE( l_outtekiyost_ymd, 'YYYYMMDD' )));

			--改定前の月数に月数-改定後の月数を設定する。
			l_outtsukisu_mae := wk_tsukisu - l_outtsukisu_ato;

			-- 追加　計算期間の設定を行う。初期・終期・期中区分が初期(1)の場合は、計算終了日から設定を行う。
			-- 計算期間の月数をカウントする
			LOOP
				wk_cntMax :=wk_cntMax+1;
				IF oracle.ADD_MONTHS(TO_DATE(l_inedcalcymd,'YYYYMMDD'),((wk_cntMax) * -1) )+1 <= TO_DATE( l_instcalcymd,'YYYYMMDD') THEN

					EXIT;
				END IF;
				IF wk_cntMax >= 12 THEN
					EXIT;
				END IF;
			END LOOP;

			-- 0〜Max-1件までLOOP
			FOR wk_cnt IN 0..(wk_cntMax-1) LOOP

				IF oracle.ADD_MONTHS(TO_DATE(l_inedcalcymd,'YYYYMMDD'),((wk_cntMax-wk_cnt) * -1))+1 >= TO_DATE( l_instcalcymd,'YYYYMMDD') THEN

					-- 計算月の初日を設定する ※pkDate.getGesshoYMDを使うと01日(固定）になってしまうので使わない
					l_outkeisanyymmdd[wk_cnt] := TO_CHAR(oracle.ADD_MONTHS(TO_DATE(l_inedcalcymd,'YYYYMMDD'),((wk_cntMax-wk_cnt) * -1))+1,'YYYYMMDD');

				ELSE
					-- 計算開始日を設定する。
					l_outkeisanyymmdd[wk_cnt] := TO_CHAR(TO_DATE( l_instcalcymd,'YYYYMMDD'),'YYYYMMDD');
				END IF;

			END LOOP;

		ELSE	--初期・終期・期中区分が初期(1)以外の場合
			--計算開始日から改定後の適用開始日の月数を取得
			--12/31〜4/1の場合は3ヶ月、1/1〜4/1の場合は3ヶ月、1/2〜4/1の場合は2ヶ月
			l_outtsukisu_mae := CEIL(oracle.MONTHS_BETWEEN( TO_DATE( l_outtekiyost_ymd, 'YYYYMMDD' ), TO_DATE( l_instcalcymd, 'YYYYMMDD' )));

			--改定後の月数に月数-改定前の月数を設定する。
			l_outtsukisu_ato := wk_tsukisu - l_outtsukisu_mae;

			-- 追加　計算期間の設定を行う。初期・終期・期中区分が初期(1)以外の場合は、計算開始日から設定を行う。
			LOOP
				IF wk_cntMax = 0 THEN
					-- 計算開始日を設定する。
					l_outkeisanyymmdd[wk_cntMax] := TO_CHAR(TO_DATE( l_instcalcymd,'YYYYMMDD'),'YYYYMMDD');
				ELSE
					IF oracle.ADD_MONTHS(TO_DATE(l_instcalcymd,'YYYYMMDD'),wk_cntMax)  < TO_DATE( l_inedcalcymd,'YYYYMMDD') THEN
						-- 計算月の初日を設定する　※pkDate.getGesshoYMDを使うと01日(固定）になってしまうので使わない
						l_outkeisanyymmdd[wk_cntMax] := TO_CHAR(oracle.ADD_MONTHS(TO_DATE(l_instcalcymd,'YYYYMMDD'),wk_cntMax),'YYYYMMDD');
					ELSE
						EXIT;
					END IF;
				END IF;

				wk_cntMax :=wk_cntMax +1;
				IF wk_cntMax >= 12 THEN
					EXIT;
				END IF;

			END LOOP;

		END IF;

		-- 正常終了
		extra_param := pkConstant.SUCCESS();
		RETURN;

	EXCEPTION

		--  全ての例外はここで受ける
		WHEN OTHERS THEN

		--  エラーがあった場合には、エラー内容を出力する
		CALL pkLog.FATAL('', '', SQLSTATE || SUBSTR(SQLERRM, 1, 50));

		--  処理場はエラーで返す
		extra_param := pkConstant.FATAL();
		RETURN;
END $$ LANGUAGE PLPGSQL;


	/**
	 * 手数料計算(分かち計算用）<br>
	 * リストの値を参照して、分かち計算で期中手数料を算出し、戻り値に
	 * セットする
	 *
	 * @param	l_inszeiprocess			消費税算出方式（総額：0　従来：1）
	 * @param	l_instcalcymd			計算開始日
	 * @param	l_intsukiwarifrom		月割期間From
	 * @param	l_inhiwarifrom			日割期間From
	 * @param	l_incalcpatterncd		手数料計算パターン
	 * @param	l_intsukisu			月数
	 * @param	l_inkjnzndk			基準残高
	 * @param	l_inteigakutesukngk		定額期中手数料
	 * @param	l_insstesubunshi		手数料率（分子）
	 * @param	l_insstesubunbo			手数料率（分母）
	 * @param	l_inchokyuymd			徴求日
	 * @param	l_inhakkotsukacd		発行通貨コード
	 * @param	l_inkeisanyydd			計算年月1〜13
	 * @param	l_intsukizndk			月毎残高1〜13
	 * @param	l_inanbunbunshi			期間按分分子
	 * @param	l_inanbunbunbo			期間按分分母
	 * @param	l_inhasunissucalckbn		端数日数計算区分
	 * @param	l_inssnenchokyucnt		年徴求回数
	 * @param	l_inedcalcymd			計算終了日
	 * @param	l_intsukisu_mae			改定前の月数
	 * @param	l_intsukisu_ato			改定後の月数
	 * @param	l_intekiyost_ymd		改定後の消費税適用日
	 * @param	l_inkeisanyymmdd		計算期間（年月日）※計算開始日〜終了日を月別に分解し、月の先頭日を設定する
	 * @param	l_outtesuryo			期中手数料（税込）
	 * @param	l_outtesuryozei			期中手数料消費税
	 * @param	l_outtesuryonuki		期中手数料（税抜）
	 * @param	l_outtsukitesuryo		月毎手数料1〜13
	 * @param	l_outtesuryo_mae		改定前の手数料（税抜）
	 * @param	l_outtesuryo_ato		改定後の手数料（税抜）
	 * @param	l_outtesuryozei_mae		改定前の消費税
	 * @param	l_outtesuryozei_ato		改定後の消費税
	 * @param	l_outkikan_mae			改定前の期間
	 * @param	l_outkikan_ato			改定後の期間

	 * @return l_return					正常終了/異常終了
	 */
CREATE OR REPLACE FUNCTION pkipakichutesuryo.calctesuryo_wakachi (
    l_inszeiprocess VARCHAR,
    l_instcalcymd CHAR,
    l_intsukiwarifrom CHAR,
    l_inhiwarifrom CHAR,
    l_incalcpatterncd CHAR,
    l_intsukisu numeric,
    l_inkjnzndk INOUT numeric,
    l_inteigakutesukngk numeric,
    l_insstesubunshi numeric,
    l_insstesubunbo numeric,
    l_inchokyuymd CHAR,
    l_inhakkotsukacd CHAR,
    l_keisanyydd pkipakichutesuryo.ch6_array,
    l_intsukizndk pkipakichutesuryo.num_array,
    l_inanbunbunshi numeric,
    l_inanbunbunbo numeric,
    l_inhasunissucalckbn CHAR,
    l_inssnenchokyucnt numeric,
    l_inedcalcymd CHAR,
    l_intsukisu_mae numeric,
    l_intsukisu_ato numeric,
    l_intekiyost_ymd CHAR,
    l_inkeisanyymmdd pkipakichutesuryo.chr_array,
    l_outtesuryo OUT numeric,
    l_outtesuryozei OUT numeric,
    l_outtesuryonuki OUT numeric,
    l_outtsukitesuryo OUT pkipakichutesuryo.num_array,
    l_outtesuryo_mae OUT numeric,
    l_outtesuryo_ato OUT numeric,
    l_outtesuryozei_mae OUT numeric,
    l_outtesuryozei_ato OUT numeric,
    l_outkikan_mae OUT numeric,
    l_outkikan_ato OUT numeric,
    OUT extra_param numeric
) RETURNS record AS $$ DECLARE


	/* ==変数定義=================================*/

	 l_return				numeric := 0;

	 l_tsukisu				numeric := 0;
	 l_kjnzndk				numeric := 0;
	 l_teigakutesukngk			numeric := 0;
	 l_sstesubunshi				numeric := 0;
	 l_sstesubunbo 				numeric := 0;
	 l_ssnenchokyucnt			numeric := 0;
	 l_anbunbunshi				numeric := 0;
	 l_anbunbunbo				numeric := 0;
	 l_tsukisu_mae				numeric := 0;
	 l_tsukisu_ato				numeric := 0;
	 l_tesuryomm_mae			numeric := 0;	-- 改定前の手数料(月割)
	 l_tesuryomm_ato			numeric := 0;	-- 改定後の手数料(月割)
	 l_tesuryomm				numeric := 0;
	 l_tesuryodd				numeric := 0;
	 l_tesuryodd_mae			numeric := 0;	-- 改定前の手数料(日割）
	 l_tesuryodd_ato			numeric := 0;	-- 改定後の手数料(日割）
	 l_loopcnt				numeric := 0;
	 l_hankanencnt				numeric := -1;
	 l_tmpsumtesuryo			numeric := 0;
	 l_tmpsumtesuryo_mae			numeric := 0;	--改定前の手数料の合計
	 l_tmpsumtesuryo_ato			numeric := 0;	--改定後の手数料の合計
	 l_tmpsumzndk_mae			numeric := 0;	--改定前の残高(WK)
	 l_tmpsumzndk_ato			numeric := 0;	--改定後の残高(WK)
	 l_tmpkjnzndk_mae			numeric := 0;	--改定前の基準残高(WK)
	 l_tmpkjnzndk_ato			numeric := 0;	--改定後の基準残高(WK)
	 l_tmpkjnzndk				numeric := 0;	--基準残高(WK)
	 wk_anbunbunshi_mae			numeric := 0;	--期間按分分子（改定前）
	 wk_anbunbunshi_ato			numeric := 0;	--期間按分分子（改定後）
	 l_hiwariindex				numeric := -1;	--日割部分がある場合のインデックス
	 l_szeiritsu_mae			numeric := 0;	--改定前の消費税率
	 l_szeiritsu_ato			numeric := 0;	--改定後の消費税率
	 wk_szeiritsu_mae			numeric := 0;	--改定前の消費税率(WK)
	 wk_szeiritsu_ato			numeric := 0;	--改定後の消費税率(WK)
	 wk_szeiritsu				numeric := 0;	--消費税率(WK)
	 wk_hiwaristatus			char(1);		--日割部分の状態（'0':改定前、'1':改定後）
	 l_tsukaketa				integer := 0;	--小数点以下の桁数
	 l_cnt_mae				numeric := 0;	--平均残高計算用カウント（総額_改定前）
	 l_cnt_ato				numeric := 0;	--平均残高計算用カウント（総額_改定後）
	 l_cnt					numeric := 0;	--平均残高計算用カウント(従来）
	 wk_tesuryozei_mae			numeric := 0;	-- 改定前の手数料(WK)
	 wk_tesuryozei_ato			numeric := 0;	-- 改定後の手数料(WK)
	 wk_teigakutesukngk_mae			numeric := 0;	-- 改定前の定額手数料(WK)
	 wk_teigakutesukngk_ato			numeric := 0;	-- 改定後の定額手数料(WK)
	 wk_zei_mae				numeric := 0;	-- 改定前の消費税(WK)
	 wk_zei_ato				numeric := 0;	-- 改定後の消費税(WK)
	 wk_teigakutesukngk_zei_mae		numeric := 0;	-- 改定前の定額手数料の消費税(WK)
	 wk_teigakutesukngk_zei_ato		numeric := 0;	-- 改定後の定額手数料の消費税(WK)
	 wk_tesuryo_mae				numeric := 0;	-- 改定前の手数料(WK)
	 wk_tesuryo_ato				numeric := 0;	-- 改定後の手数料(WK)
	/* ==　処理　=================================*/


BEGIN
		--inパラメータ数値項目Nullの場合の初期化
		l_tsukisu := coalesce(l_intsukisu,0);
		l_kjnzndk := coalesce(l_inkjnzndk,0);
		l_teigakutesukngk := coalesce(l_inteigakutesukngk,0);
		l_sstesubunshi := coalesce(l_insstesubunshi,0);
		l_sstesubunbo := coalesce(l_insstesubunbo,0);
		l_anbunbunshi := coalesce(l_inanbunbunshi,0);
		l_anbunbunbo := coalesce(l_inanbunbunbo,0);
		l_tsukisu_mae := coalesce(l_intsukisu_mae,0);
		l_tsukisu_ato := coalesce(l_intsukisu_ato,0);

		-- コレクションの初期化
		LOOP
			l_outtsukitesuryo[l_loopcnt] := 0;
			l_loopcnt := l_loopcnt + 1;
			EXIT WHEN l_loopcnt > 12;
		END LOOP;
		l_loopcnt := 0;

		/* 消費税計算用 */

		l_szeiritsu_mae := 0;
		l_szeiritsu_ato := 0;

		wk_szeiritsu_mae := PKIPAZEI.getShohiZei(l_instcalcymd);	 -- 改定前の消費税率取得
		wk_szeiritsu_ato := PKIPAZEI.getShohiZei(l_inedcalcymd);	 -- 改定後の消費税率取得
		l_szeiritsu_mae := wk_szeiritsu_mae;	 -- 改定前の消費税率取得
		l_szeiritsu_ato := wk_szeiritsu_ato;	 -- 改定後の消費税率取得
		/* JPYまたは外貨の場合の小数点以下の桁数 */

		l_tsukaketa := 0;
		IF l_inhakkotsukacd <> 'JPY' THEN

			l_tsukaketa := 2;		-- JPY以外なら小数点以下2桁まで
		END IF;

		l_tesuryomm_mae :=0;
		l_tesuryomm_ato :=0;
		l_tesuryodd_mae :=0;
		l_tesuryodd_ato :=0;
		l_tesuryomm :=0;
		l_tmpsumzndk_mae :=0;
		l_tmpsumzndk_ato :=0;
		l_tmpkjnzndk_mae :=0;
		l_tmpkjnzndk_ato :=0;
		l_tmpkjnzndk :=0;
		l_tmpsumtesuryo_mae :=0;
		l_tmpsumtesuryo_ato :=0;
		wk_szeiritsu :=0;
		wk_hiwaristatus :='0';

		-- 計算パターンごとに、月割部分の手数料を求める（単位未満切捨て）
		CASE l_incalcpatterncd

			-- 残高基準日方式
			WHEN '1' THEN

				--手数料率（分母）が設定されている場合
				IF l_sstesubunbo <> 0 THEN
					-- 総額方式の場合
					IF l_inszeiprocess = '0' THEN

						-- 月数が未設定の場合は日割なので、呼ばない。
						IF l_intsukisu <> 0 THEN

							-- 改定前の期中手数料（税込）を算出する
							l_tesuryomm_mae := TRUNC(l_kjnzndk * l_sstesubunshi / l_sstesubunbo * l_tsukisu_mae / 12 * ( 1 + l_szeiritsu_mae), l_tsukaketa);

							-- 改定後の期中手数料（税込）を算出する
							l_tesuryomm_ato := TRUNC(l_kjnzndk * l_sstesubunshi / l_sstesubunbo * l_tsukisu_ato / 12 * ( 1 + l_szeiritsu_ato), l_tsukaketa);

						END IF;

					-- 従来方式の場合
					ELSIF l_inszeiprocess = '1' THEN

						-- 月数が０でも、改定前、改定後の月数が設定される場合があるので追加。
						IF l_intsukisu <> 0 THEN

							-- 期中手数料（税抜）を算出する
							l_tesuryomm := TRUNC(l_kjnzndk * l_sstesubunshi / l_sstesubunbo * (l_tsukisu_mae + l_tsukisu_ato) / 12, l_tsukaketa);

						END IF;

					END IF;
				END IF;

			-- 平均残高方式
			WHEN '2' THEN

				LOOP
					-- 日割部分がある場合、そのIndexを一時保存
					IF nullif(trim(both l_inhiwarifrom), '') IS NOT NULL AND SUBSTR(l_inhiwarifrom,1,6) = l_keisanyydd[l_loopcnt] THEN
						l_hiwariindex := l_loopcnt;

					END IF;

					IF SUBSTR(l_instcalcymd,1,6) <= l_keisanyydd[l_loopcnt] AND l_hankanencnt < (l_intsukisu_mae + l_intsukisu_ato) THEN
						-- 改定後の消費税適用日＞計算年月日（n）の場合(改定前の場合）
						IF l_intekiyost_ymd >  l_inkeisanyymmdd[l_loopcnt] THEN

							-- 計算期間内の改定前の残高を加算する。
							l_tmpsumzndk_mae := l_tmpsumzndk_mae + l_intsukizndk[l_loopcnt];

						-- 改定後の場合
						ELSE

							-- 計算期間内の改定後の残高を加算する。
							l_tmpsumzndk_ato := l_tmpsumzndk_ato + l_intsukizndk[l_loopcnt];

						END IF;

						l_hankanencnt := l_hankanencnt + 1;

					END IF;
					l_loopcnt := l_loopcnt + 1;

					EXIT WHEN l_loopcnt > 12;
				END LOOP;

				-- 日割部分がある場合は月数＋１
				IF l_hiwariindex >= 0 THEN

					-- 総額方式の場合
					IF l_inszeiprocess = '0' THEN

						-- 改定後の消費税適用日＞計算年月日（n）の場合(改定前の場合）
						IF l_intekiyost_ymd >  l_inkeisanyymmdd[l_hiwariindex] THEN

							l_cnt_mae := l_intsukisu_mae + 1;
							l_cnt_ato := l_intsukisu_ato;

						ELSE

							l_cnt_ato := l_intsukisu_ato + 1;
							l_cnt_mae := l_intsukisu_mae;

						END IF;

					-- 従来方式の場合
					ELSIF l_inszeiprocess = '1' THEN

						l_cnt := l_intsukisu_mae + l_intsukisu_ato + 1;

					END IF;
				ELSE

					l_cnt_mae := l_intsukisu_mae;
					l_cnt_ato := l_intsukisu_ato;

					-- 従来方式の場合
					IF l_inszeiprocess = '1' THEN
						l_cnt := l_intsukisu_mae + l_intsukisu_ato;
					END IF;
				END IF;

				--手数料率（分母）が設定されている場合
				IF l_sstesubunbo <> 0 THEN

					-- 総額方式の場合
					IF l_inszeiprocess = '0' THEN

						-- 改定前の月数＝０の場合、異常終了するため対処
						IF l_cnt_mae <> 0 THEN

							-- 改定前の平均残高を算出する ※JPY以外の場合も小数点以下は切り捨てる
							l_tmpkjnzndk_mae := trunc(l_tmpsumzndk_mae / l_cnt_mae , 0);

						END IF;

						-- 改定後の月数＝０の場合、異常終了するため対処
						IF l_cnt_ato <> 0 THEN

							-- 改定後の平均残高を算出する　※JPY以外の場合も小数点以下は切り捨てる
							l_tmpkjnzndk_ato := trunc(l_tmpsumzndk_ato / l_cnt_ato , 0);

						END IF;

						-- 出力パラメータの基準残高に0を設定する。
						l_inkjnzndk := 0;

						-- 改定前の期中手数料（税込）を算出する
						l_tesuryomm_mae := TRUNC(l_tmpkjnzndk_mae * l_sstesubunshi / l_sstesubunbo * l_tsukisu_mae / 12 * ( 1 + l_szeiritsu_mae), l_tsukaketa);

						-- 改定後の期中手数料（税込）を算出する
						l_tesuryomm_ato := TRUNC(l_tmpkjnzndk_ato * l_sstesubunshi / l_sstesubunbo * l_tsukisu_ato / 12 * ( 1 + l_szeiritsu_ato), l_tsukaketa);

					-- 従来方式の場合
					ELSIF l_inszeiprocess = '1' THEN

						-- 平均残高を算出する　※JPY以外の場合も小数点以下は切り捨てる
						l_tmpkjnzndk := TRUNC((l_tmpsumzndk_mae + l_tmpsumzndk_ato) / l_cnt ,0);

						-- 出力パラメータの基準残高に平均残高を設定する。
						l_inkjnzndk := l_tmpkjnzndk;

						-- 期中手数料（税抜）を算出する
						l_tesuryomm := TRUNC(l_tmpkjnzndk * l_sstesubunshi / l_sstesubunbo * (l_tsukisu_mae + l_tsukisu_ato) / 12, l_tsukaketa);

					END IF;

				END IF;
				--'5'（平均残高（後除算）方式)
			WHEN '5' THEN

				LOOP
					-- 日割部分がある場合、そのIndexを一時保存
					IF nullif(trim(both l_inhiwarifrom), '') IS NOT NULL AND SUBSTR(l_inhiwarifrom,1,6) = l_keisanyydd[l_loopcnt] THEN
						l_hiwariindex := l_loopcnt;

					END IF;

					IF SUBSTR(l_instcalcymd,1,6) <= l_keisanyydd[l_loopcnt] AND l_hankanencnt < (l_intsukisu_mae + l_intsukisu_ato) THEN
						-- 改定後の消費税適用日＞計算年月日（n）の場合(改定前の場合）
						IF l_intekiyost_ymd >  l_inkeisanyymmdd[l_loopcnt] THEN

							-- 計算期間内の改定前の残高を加算する。
							l_tmpsumzndk_mae := l_tmpsumzndk_mae + l_intsukizndk[l_loopcnt];

						-- 改定後の場合
						ELSE

							-- 計算期間内の改定後の残高を加算する。
							l_tmpsumzndk_ato := l_tmpsumzndk_ato + l_intsukizndk[l_loopcnt];

						END IF;

						l_hankanencnt := l_hankanencnt + 1;

					END IF;
					l_loopcnt := l_loopcnt + 1;

					EXIT WHEN l_loopcnt > 12;
				END LOOP;

				-- 日割部分がある場合は月数＋１
				IF l_hiwariindex >= 0 THEN

					-- 総額方式の場合
					IF l_inszeiprocess = '0' THEN

						-- 改定後の消費税適用日＞計算年月日（n）の場合(改定前の場合）
						IF l_intekiyost_ymd >  l_inkeisanyymmdd[l_hiwariindex] THEN

							l_cnt_mae := l_intsukisu_mae + 1;
							l_cnt_ato := l_intsukisu_ato;

						ELSE

							l_cnt_ato := l_intsukisu_ato + 1;
							l_cnt_mae := l_intsukisu_mae;

						END IF;

					-- 従来方式の場合
					ELSIF l_inszeiprocess = '1' THEN

						l_cnt := l_intsukisu_mae + l_intsukisu_ato + 1;

					END IF;
				ELSE

					l_cnt_mae := l_intsukisu_mae;
					l_cnt_ato := l_intsukisu_ato;

					-- 従来方式の場合
					IF l_inszeiprocess = '1' THEN
						l_cnt := l_intsukisu_mae + l_intsukisu_ato;
					END IF;
				END IF;

				--手数料率（分母）が設定されている場合
				IF l_sstesubunbo <> 0 THEN

					-- 総額方式の場合
					IF l_inszeiprocess = '0' THEN

						-- 改定前の月数＝０の場合、異常終了するため対処
						IF l_cnt_mae <> 0 THEN

							-- 改定前の平均残高を算出する ※JPY以外の場合も小数点以下は切り捨てる
							l_tmpkjnzndk_mae := trunc(l_tmpsumzndk_mae  , 0);

						END IF;

						-- 改定後の月数＝０の場合、異常終了するため対処
						IF l_cnt_ato <> 0 THEN

							-- 改定後の平均残高を算出する　※JPY以外の場合も小数点以下は切り捨てる
							l_tmpkjnzndk_ato := trunc(l_tmpsumzndk_ato , 0);

						END IF;

						-- 出力パラメータの基準残高に0を設定する。
						l_inkjnzndk := 0;

						-- 改定前の期中手数料（税込）を算出する
						l_tesuryomm_mae := TRUNC(l_tmpkjnzndk_mae * l_sstesubunshi / l_sstesubunbo * 1 / 12 * ( 1 + l_szeiritsu_mae), l_tsukaketa);

						-- 改定後の期中手数料（税込）を算出する
						l_tesuryomm_ato := TRUNC(l_tmpkjnzndk_ato * l_sstesubunshi / l_sstesubunbo * 1 / 12 * ( 1 + l_szeiritsu_ato), l_tsukaketa);

					-- 従来方式の場合
					ELSIF l_inszeiprocess = '1' THEN

						-- 平均残高を算出する　※JPY以外の場合も小数点以下は切り捨てる
						l_tmpkjnzndk := trunc((l_tmpsumzndk_mae + l_tmpsumzndk_ato),0 );

						-- 出力パラメータの基準残高に平均残高を設定する。
						l_inkjnzndk := l_tmpkjnzndk;

						-- 期中手数料（税抜）を算出する
						l_tesuryomm := trunc(l_tmpkjnzndk * l_sstesubunshi / l_sstesubunbo * 1 / 12, l_tsukaketa);

					END IF;

				END IF;

			-- 月毎計算方式
			WHEN '3' THEN

				LOOP
					l_outtsukitesuryo[l_loopcnt] := 0;

					-- 日割部分がある場合、そのIndexを一時保存
					IF nullif(trim(both l_inhiwarifrom), '') IS NOT NULL AND SUBSTR(l_inhiwarifrom,1,6) = l_keisanyydd[l_loopcnt] THEN
						l_hiwariindex := l_loopcnt;

					END IF;

					-- 月割部分のみ期中手数料（月割部分）を計算する
					IF SUBSTR(l_intsukiwarifrom,1,6) <= l_keisanyydd[l_loopcnt] AND l_hankanencnt < (l_intsukisu_mae + l_intsukisu_ato) AND l_hiwariindex <> l_loopcnt THEN

						--手数料率（分母）が設定されている場合
						IF l_sstesubunbo <> 0 THEN

							-- 総額方式の場合
							IF l_inszeiprocess = '0' THEN

								-- 改定後の消費税適用日＞計算年月日（n）の場合(改定前の場合）
								IF l_intekiyost_ymd >  l_inkeisanyymmdd[l_loopcnt] THEN

									l_outtsukitesuryo[l_loopcnt] := TRUNC(l_intsukizndk[l_loopcnt] * l_sstesubunshi / l_sstesubunbo / 12 * ( 1 + l_szeiritsu_mae), l_tsukaketa);

									--改定前の期中手数料（税込）を算出
									l_tmpsumtesuryo_mae := l_tmpsumtesuryo_mae + l_outtsukitesuryo[l_loopcnt];

								-- 改定後の場合
								ELSE

									l_outtsukitesuryo[l_loopcnt] := TRUNC(l_intsukizndk[l_loopcnt] * l_sstesubunshi / l_sstesubunbo / 12 * ( 1 + l_szeiritsu_ato), l_tsukaketa);

									--改定後の期中手数料（税込）を算出
									l_tmpsumtesuryo_ato := l_tmpsumtesuryo_ato + l_outtsukitesuryo[l_loopcnt];

								END IF;

							-- 従来方式の場合
							ELSIF l_inszeiprocess = '1' THEN

								l_outtsukitesuryo[l_loopcnt] := trunc(l_intsukizndk[l_loopcnt] * l_sstesubunshi / l_sstesubunbo / 12, l_tsukaketa);

								-- 改定後の消費税適用日＞計算年月日（n）の場合(改定前の場合）
								IF l_intekiyost_ymd >  l_inkeisanyymmdd[l_loopcnt] THEN

									--改定前の期中手数料（税抜）を算出
									l_tmpsumtesuryo_mae := l_tmpsumtesuryo_mae + l_outtsukitesuryo[l_loopcnt];

								-- 改定後の場合
								ELSE

									--改定後の期中手数料（税抜）を算出
									l_tmpsumtesuryo_ato := l_tmpsumtesuryo_ato + l_outtsukitesuryo[l_loopcnt];

								END IF;

							END IF;

						END IF;

						l_hankanencnt := l_hankanencnt + 1;

					END IF;
					l_loopcnt := l_loopcnt + 1;
					EXIT WHEN l_loopcnt > 12;

				END LOOP;


				-- 改定前の期中手数料を算出する
				l_tesuryomm_mae := l_tmpsumtesuryo_mae;

				-- 改定後の期中手数料を算出する
				l_tesuryomm_ato := l_tmpsumtesuryo_ato;

				-- 従来方式の場合
				IF l_inszeiprocess = '1' THEN

					-- 期中手数料（税抜）を算出する ※l_tesuryomm_mae、l_tesuryomm_atoは消費税の計算であとで使用する
					l_tesuryomm := l_tesuryomm_mae + l_tesuryomm_ato;

				END IF;

				-- 計算パターンが月毎計算方式の場合、基準残高は登録しない ※既存処理なのでとりあえず残す。
				l_inkjnzndk := 0;

			-- 定額方式(4)の場合
			ELSE

				-- 手数料（税抜）に定額手数料を設定する。
				l_outtesuryonuki := l_teigakutesukngk;

				-- 消費税を算出する。 改定前の消費税＋改定後の消費税
				wk_tesuryo_mae := TRUNC(l_outtesuryonuki * l_tsukisu_mae / (l_tsukisu_mae + l_tsukisu_ato) ,l_tsukaketa);
				wk_zei_mae := trunc(wk_tesuryo_mae * l_szeiritsu_mae, l_tsukaketa);
				wk_tesuryo_ato := TRUNC(l_outtesuryonuki * l_tsukisu_ato / (l_tsukisu_mae + l_tsukisu_ato) ,l_tsukaketa);
				wk_zei_ato := trunc(wk_tesuryo_ato * l_szeiritsu_ato, l_tsukaketa);

				l_outtesuryozei := wk_zei_mae + wk_zei_ato;

				-- 手数料（税込）を算出する。
				l_outtesuryo := l_outtesuryonuki + l_outtesuryozei;

				-- 総額方式の場合
				IF l_inszeiprocess = '0' THEN

					-- 改定前、改定後の手数料（税込）を設定
					l_outtesuryo_mae := wk_tesuryo_mae + wk_zei_mae;
					l_outtesuryo_ato := wk_tesuryo_ato + wk_zei_ato;

					-- 改定前の消費税、改定後の消費税を設定
					l_outtesuryozei_mae := wk_zei_mae;
					l_outtesuryozei_ato := wk_zei_ato;

				-- 従来方式の場合
				ELSIF l_inszeiprocess = '1' THEN

					-- 改定前、改定後の期間に改定前、改定後の月数を設定
					l_outkikan_mae := l_intsukisu_mae;
					l_outkikan_ato := l_intsukisu_ato;

				END IF;


			END CASE;

			-- 計算パターンが 残高基準日方式、月毎残高方式、平均残高方式、'5'（平均残高（後除算）方式の場合
			--IF l_incalcpatterncd IN('1','2','3') THEN
			IF l_incalcpatterncd IN ('1','2','3','5') THEN

				-- 端数日数計算区分が半か年実日数以外の場合は、年徴求回数に１をセット)
				IF l_inhasunissucalckbn <> '4' THEN
					l_ssnenchokyucnt := 1;

				ELSE
					l_ssnenchokyucnt := l_inssnenchokyucnt;

				END IF;

				-- 期中手数料（日割部分）がある場合
				IF l_sstesubunbo <> 0 AND l_anbunbunbo <> 0 THEN

					-- 日割期間Fromより消費税を取得する。
					wk_szeiritsu := 0;
					wk_szeiritsu := PKIPAZEI.getShohiZei(l_inhiwarifrom);	 -- 日割部分の消費税率取得
					-- 改定後の消費税と同じ場合
					wk_hiwaristatus := '0';

					IF wk_szeiritsu = wk_szeiritsu_ato THEN

						-- 日割期間は改定後と判定
						wk_hiwaristatus := '1';

					END IF;

					-- 残高基準日方式の場合
					IF l_incalcpatterncd = '1' THEN

						-- 日割の場合(月数=０の場合）
						IF l_intsukisu = 0 THEN

							wk_anbunbunshi_mae := 0;
							wk_anbunbunshi_ato := 0;

							-- 改定前の期間按分分子を取得
							wk_anbunbunshi_mae := (TO_DATE(l_intekiyost_ymd,'YYYYMMDD') - TO_DATE(l_inhiwarifrom,'YYYYMMDD'))::numeric;

							-- 改定後の期間按分分子を取得
							wk_anbunbunshi_ato := l_inanbunbunshi - wk_anbunbunshi_mae;

							-- 総額方式の場合
							IF l_inszeiprocess = '0' THEN

								-- 改定前の期中手数料（税込）（日割分）を算出
								l_tesuryodd_mae := TRUNC(l_kjnzndk * l_sstesubunshi / l_sstesubunbo * wk_anbunbunshi_mae / l_anbunbunbo / l_ssnenchokyucnt * ( 1 + l_szeiritsu_mae),l_tsukaketa);

								-- 改定前の期中手数料（税込）に日割分を加算
								l_tesuryomm_mae := l_tesuryomm_mae + l_tesuryodd_mae;

								-- 改定後の期中手数料（税込）（日割分）を算出
								l_tesuryodd_ato := TRUNC(l_kjnzndk * l_sstesubunshi / l_sstesubunbo * wk_anbunbunshi_ato / l_anbunbunbo / l_ssnenchokyucnt * ( 1 + l_szeiritsu_ato),l_tsukaketa);

								-- 改定後の期中手数料（税込）に日割分を加算
								l_tesuryomm_ato := l_tesuryomm_ato + l_tesuryodd_ato;

							-- 従来方式の場合
							ELSIF l_inszeiprocess = '1' THEN

								-- 改定前の期中手数料（税抜）（日割分）を算出
								l_tesuryodd_mae := trunc(l_kjnzndk * l_sstesubunshi / l_sstesubunbo * wk_anbunbunshi_mae / l_anbunbunbo / l_ssnenchokyucnt, l_tsukaketa);

								-- 改定後の期中手数料（税抜）（日割分）を算出
								l_tesuryodd_ato := trunc(l_kjnzndk * l_sstesubunshi / l_sstesubunbo * wk_anbunbunshi_ato / l_anbunbunbo / l_ssnenchokyucnt, l_tsukaketa);

								-- 期中手数料（税抜）を算出
								l_tesuryomm := l_tesuryomm + l_tesuryodd_mae + l_tesuryodd_ato;

							END IF;

						-- 日割以外の場合
						ELSE

							-- 総額方式の場合
							IF l_inszeiprocess = '0' THEN

								-- 期中手数料（税込）（日割分）を算出
								l_tesuryodd := TRUNC(l_kjnzndk * l_sstesubunshi / l_sstesubunbo * l_anbunbunshi / l_anbunbunbo / l_ssnenchokyucnt * ( 1 + wk_szeiritsu),l_tsukaketa);

								-- 改定前の場合
								IF wk_hiwaristatus = '0' THEN

									-- 改定前の期中手数料（税込）に日割分を加算
									l_tesuryomm_mae := l_tesuryomm_mae + l_tesuryodd;

								-- 改定後の場合
								ELSE
									-- 改定前の期中手数料（税込）に日割分を加算
									l_tesuryomm_ato := l_tesuryomm_ato + l_tesuryodd;

								END IF;


							-- 従来方式の場合
							ELSIF l_inszeiprocess = '1' THEN

								-- 期中手数料（税抜）（日割分）を算出
								l_tesuryodd := trunc(l_kjnzndk * l_sstesubunshi / l_sstesubunbo * l_anbunbunshi / l_anbunbunbo / l_ssnenchokyucnt, l_tsukaketa);

								-- 期中手数料（税抜）を算出
								l_tesuryomm := l_tesuryomm + l_tesuryodd;

							END IF;

						END IF;

					-- 平均残高計算方式、（平均残高（後除算）方式で日割部分がある場合、その月の手数料に端数分の手数料をセット
					--ELSIF l_incalcpatterncd = '2' AND l_hiwariindex >= 0 THEN
					ELSIF l_incalcpatterncd in ('2','5') AND l_hiwariindex >= 0 THEN

						-- 総額方式の場合
						IF l_inszeiprocess = '0' THEN

							-- 改定前の場合
							IF wk_hiwaristatus = '0' THEN

								-- 改定前の期中手数料（税込）（日割分）を算出
								l_tesuryodd := TRUNC(l_tmpkjnzndk_mae * l_sstesubunshi / l_sstesubunbo * l_anbunbunshi / l_anbunbunbo / l_ssnenchokyucnt * ( 1 + wk_szeiritsu),l_tsukaketa);

								-- 改定前の期中手数料（税込）に日割分を加算
								l_tesuryomm_mae := l_tesuryomm_mae + l_tesuryodd;

							-- 改定後の場合
							ELSE

								-- 改定後の期中手数料（税込）（日割分）を算出
								l_tesuryodd := TRUNC(l_tmpkjnzndk_ato * l_sstesubunshi / l_sstesubunbo * l_anbunbunshi / l_anbunbunbo / l_ssnenchokyucnt * ( 1 + wk_szeiritsu),l_tsukaketa);

								-- 改定後の期中手数料（税込）に日割分を加算
								l_tesuryomm_ato := l_tesuryomm_ato + l_tesuryodd;

							END IF;

						-- 従来方式の場合
						ELSIF l_inszeiprocess = '1' THEN

							-- 手数料（税抜）（日割分）を算出する。　手数料（税抜）（日割分）=平均残高 * 手数料分子 / 手数料分母 * 期間按分分子 / 期間按分分母 / 年徴求回数
							l_tesuryodd := trunc(l_tmpkjnzndk * l_sstesubunshi / l_sstesubunbo * l_anbunbunshi / l_anbunbunbo / l_ssnenchokyucnt, l_tsukaketa);

							-- 期中手数料（税抜）を算出
							l_tesuryomm := l_tesuryomm + l_tesuryodd;

						END IF;

					-- 月毎残高計算方式で日割部分がある場合、その月の手数料に端数分の手数料をセット
					ELSIF l_hiwariindex >= 0 THEN

						-- 総額方式の場合
						IF l_inszeiprocess = '0' THEN

							-- 期中手数料（税込）（日割分）を算出
							l_tesuryodd := TRUNC(l_intsukizndk[l_hiwariindex] * l_sstesubunshi / l_sstesubunbo * l_anbunbunshi / l_anbunbunbo / l_ssnenchokyucnt * ( 1 + wk_szeiritsu),l_tsukaketa);

							-- 改定前の場合
							IF wk_hiwaristatus = '0' THEN

								-- 改定前の期中手数料（税込）に日割分を加算
								l_tesuryomm_mae := l_tesuryomm_mae + l_tesuryodd;

							-- 改定後の場合
							ELSE

								-- 改定後の期中手数料（税込）に日割分を加算
								l_tesuryomm_ato := l_tesuryomm_ato + l_tesuryodd;

							END IF;

						-- 従来方式の場合
						ELSIF l_inszeiprocess = '1' THEN

							--期中手数料（税抜）（日割分）を算出
							l_tesuryodd := trunc(l_intsukizndk[l_hiwariindex] * l_sstesubunshi / l_sstesubunbo * l_anbunbunshi / l_anbunbunbo / l_ssnenchokyucnt, l_tsukaketa);

							-- 期中手数料（税抜）を算出
							l_tesuryomm := l_tesuryomm + l_tesuryodd;

							-- 改定前の場合
							IF wk_hiwaristatus = '0' THEN

								-- 消費税の計算で使用するため、設定
								l_tesuryomm_mae := l_tesuryomm_mae + l_tesuryodd;

							ELSE
								-- 消費税の計算で使用するため、設定
								l_tesuryomm_ato := l_tesuryomm_ato + l_tesuryodd;

							END IF;

						END IF;

						-- 月毎手数料（n）に手数料（日割分）を設定する。
						l_outtsukitesuryo[l_hiwariindex] := l_tesuryodd;

					END IF;
				END IF;

				--出力パラメータを設定する。
				-- 日割（月数=0でない）かつ日割Fromが設定されている場合　（月割日割の場合）
				IF l_intsukisu != 0 AND nullif(trim(both l_inhiwarifrom), '') IS NOT NULL THEN

					-- 改定後の端数がある場合、改定後の月数に１加算する。
					IF wk_hiwaristatus = '1' THEN
						l_tsukisu_ato := l_tsukisu_ato +1;

					-- 改定前の端数がある場合、改定前の月数に１加算する。
					ELSE
						l_tsukisu_mae := l_tsukisu_mae +1;
					END IF;
				END IF;

				-- 総額方式の場合
				IF l_inszeiprocess = '0' THEN

					-- 改定前、改定後の消費税を算出する。
					wk_zei_mae := TRUNC(l_tesuryomm_mae * l_szeiritsu_mae / (1 + l_szeiritsu_mae), l_tsukaketa);
					wk_zei_ato := TRUNC(l_tesuryomm_ato * l_szeiritsu_ato / (1 + l_szeiritsu_ato), l_tsukaketa);

					-- 改定前、改定後の定額期中手数料（税抜）を算出する。
					wk_teigakutesukngk_mae := TRUNC(l_teigakutesukngk * l_tsukisu_mae / (l_tsukisu_mae + l_tsukisu_ato), l_tsukaketa);
					wk_teigakutesukngk_ato := TRUNC(l_teigakutesukngk * l_tsukisu_ato / (l_tsukisu_mae + l_tsukisu_ato), l_tsukaketa);

					-- 改定前、改定後の定額期中手数料の消費税を算出する。
					wk_teigakutesukngk_zei_mae := trunc(wk_teigakutesukngk_mae * l_szeiritsu_mae, l_tsukaketa);
					wk_teigakutesukngk_zei_ato := trunc(wk_teigakutesukngk_ato * l_szeiritsu_ato, l_tsukaketa);

					-- 手数料（税込）= 改定前の期中手数料（税込）＋ 改定後の期中手数料（税込）＋ 定額期中手数料（税抜）＋ 改定前の定額期中手数料の消費税＋ 改定後の定額期中手数料の消費税
					l_outtesuryo := l_tesuryomm_mae + l_tesuryomm_ato + l_teigakutesukngk + wk_teigakutesukngk_zei_mae + wk_teigakutesukngk_zei_ato;

					-- 消費税 = 改定前の消費税＋改定後の消費税＋改定前の定額期中手数料の消費税＋改定後の定額期中手数料の消費税
					l_outtesuryozei := wk_zei_mae + wk_zei_ato + wk_teigakutesukngk_zei_mae + wk_teigakutesukngk_zei_ato;

					-- 手数料（税抜）= 手数料（税込）- 消費税
					l_outtesuryonuki := l_outtesuryo - l_outtesuryozei;

					-- 分配手数料で使用するため追加
					-- 改定前の手数料（税込）、改定後の手数料（税込）を設定
					l_outtesuryo_mae := l_tesuryomm_mae + wk_teigakutesukngk_mae + wk_teigakutesukngk_zei_mae;
					l_outtesuryo_ato := l_tesuryomm_ato + wk_teigakutesukngk_ato + wk_teigakutesukngk_zei_ato;

					-- 改定前の消費税、改定後の消費税を設定
					l_outtesuryozei_mae := wk_zei_mae + wk_teigakutesukngk_zei_mae;
					l_outtesuryozei_ato := wk_zei_ato + wk_teigakutesukngk_zei_ato;

				-- 従来方式の場合
				ELSIF l_inszeiprocess = '1' THEN

					-- 手数料（税抜）= 期中手数料（税抜）＋ 定額手数料
					l_outtesuryonuki := l_tesuryomm + l_teigakutesukngk;

					-- 日割期間Fromが設定されている場合
					IF nullif(trim(both l_inhiwarifrom), '') IS NOT NULL THEN

						-- 残高基準日方式で日割(月数=０の場合）の場合
						IF l_incalcpatterncd = '1' AND l_intsukisu = 0 THEN
							-- 改定前、改定後の按分を設定する。
							l_outkikan_mae :=wk_anbunbunshi_mae;
							l_outkikan_ato :=wk_anbunbunshi_ato;
						ELSE
							-- 改定前、改定後の日数を設定
							l_outkikan_mae := (TO_DATE(l_intekiyost_ymd,'YYYYMMDD') - TO_DATE(l_instcalcymd,'YYYYMMDD'))::numeric;
							l_outkikan_ato := (TO_DATE(l_inedcalcymd,'YYYYMMDD')+1 - TO_DATE(l_intekiyost_ymd,'YYYYMMDD'))::numeric;
						END IF;

					-- 日割が設定されていない場合
					ELSE

						-- 改定前、改定後の期間に改定前、改定後の月数を設定
						l_outkikan_mae := l_intsukisu_mae;
						l_outkikan_ato := l_intsukisu_ato;

					END IF;

					-- 手数料計算パターンが残高基準日方式（1)、または平均残高方式（2)、（平均残高（後除算）方式)(5)の場合
					--IF l_incalcpatterncd IN('1','2') THEN
					IF l_incalcpatterncd IN ('1','2','5') THEN

						--改定前の期中手数料（税抜）を算出後、改定前の消費税を算出する。
						wk_tesuryo_mae := TRUNC(l_outtesuryonuki * l_outkikan_mae / (l_outkikan_mae + l_outkikan_ato),l_tsukaketa);

						wk_zei_mae := trunc(wk_tesuryo_mae * l_szeiritsu_mae, l_tsukaketa);

						--改定後の期中手数料（税抜）を算出後、改定後の消費税を算出する。
						wk_tesuryo_ato := TRUNC(l_outtesuryonuki * l_outkikan_ato / (l_outkikan_mae + l_outkikan_ato),l_tsukaketa);

						wk_zei_ato := trunc(wk_tesuryo_ato * l_szeiritsu_ato, l_tsukaketa);

					-- 手数料計算パターンが月毎残高方式(3)の場合
					ELSE

						-- 改定前の期中手数料（税抜）を算出 ※　定額手数料を加算する
						wk_tesuryo_mae := TRUNC(l_tesuryomm_mae + l_teigakutesukngk * l_tsukisu_mae / (l_tsukisu_mae + l_tsukisu_ato),l_tsukaketa);

						-- 改定前の消費税を算出
						wk_zei_mae := trunc(wk_tesuryo_mae * l_szeiritsu_mae , l_tsukaketa);

						-- 改定後の期中手数料（税抜）を算出 ※　定額手数料を加算する
						wk_tesuryo_ato := TRUNC(l_tesuryomm_ato + l_teigakutesukngk * l_tsukisu_ato / (l_tsukisu_mae + l_tsukisu_ato),l_tsukaketa);

						-- 改定後の消費税を算出
						wk_zei_ato := trunc(wk_tesuryo_ato * l_szeiritsu_ato , l_tsukaketa);

					END IF;

					--消費税＝改定前の消費税＋改定後の消費税
					l_outtesuryozei := wk_zei_mae + wk_zei_ato;

					-- 手数料（税込）= 手数料（税抜）＋ 消費税
					l_outtesuryo := l_outtesuryonuki + l_outtesuryozei;

				END IF;
			END IF;

		extra_param := l_return;

		RETURN;

	EXCEPTION
		WHEN OTHERS THEN
		extra_param := pkConstant.FATAL();
		RETURN;
END $$ LANGUAGE PLPGSQL;

	/********************************************************************************
	 * 分配手数料計算(分かち計算用）<br>
	 * リストの値を参照して、期中手数料を計算し戻り値に
	 * セットする
	 *
	 * @param l_inszeiprocess           消費税算出方式（総額：0　従来：1）
	 * @param l_initakukaishacd       委託会社コード
	 * @param l_inbankcd   					  金融期間コード()
	 * @param l_inzentaitesuryogaku   全体手数料額（総額方式：税込、従来方式：税抜）
	 * @param l_inzentaitesuryozei  　全体手数料消費税（総額方式：内消費税、従来方式：消費税）
	 * @param l_inrowmaxbunpai        分配会社数
	 * @param l_inbunjtkkbn           受託区分()
	 * @param l_inbunkichubundfbunshi 分配期中分DF分子()
	 * @param l_insstesudfbunbo       信託報酬手数料DF分母()
	 * @param l_inhakkotsukacd        発行通貨
	 * @param l_instcalcymd　	  計算開始日
	 * @param l_inedcalcymd		  計算終了日
	 * @param  l_intesuryo_mae　　	  改定前の手数料（税込）※総額方式で使用
	 * @param　l_intesuryo_ato        改定後の手数料（税込）※総額方式で使用
	 * @param　l_intesuryozei_mae     改定前の消費税　　　　※総額方式で使用
	 * @param　l_intesuryozei_ato　　 改定後の消費税　　　　※総額方式で使用
	 * @param　l_inkikan_mae          改定前の期間　　　　　※従来方式で使用
	 * @param　l_inkikan_ato          改定後の期間　　　　　※従来方式で使用
	 * @param  l_outbuntesuryogaku	  分配手数料金額()
	 * @param  l_outbuntesuryogakuzei 分配手数料消費税()
	 * @param  l_outjikotesuryogaku	  自行手数料金額
	 * @param  l_outtakotesuryogaku	  自行手数料消費税
	 * @param  l_outjikotesuryogakuzei 他行手数料金額
	 * @param  l_outtakotesuryogakuzei 他行手数料消費税
	 * @return l_return					正常終了/異常終了
	********************************************************************************/
CREATE OR REPLACE FUNCTION pkipakichutesuryo.calcbunpaitesuryo_wakachi (
	l_inszeiprocess VARCHAR, l_initakukaishacd CHAR, l_inbankcd pkipakichutesuryo.ch4_array,
	l_inzentaitesuryogaku numeric, l_inzentaitesuryozei numeric, l_inrowmaxbunpai numeric,
	l_inbunjtkkbn pkipakichutesuryo.ch1_array, l_inbunkichubundfbunshi pkipakichutesuryo.num_array,
	l_insstesudfbunbo numeric, l_inhakkotsukacd CHAR, l_instcalcymd CHAR, l_inedcalcymd CHAR,
	l_intesuryo_mae numeric, l_intesuryo_ato numeric, l_intesuryozei_mae numeric, l_intesuryozei_ato numeric,
	l_inkikan_mae numeric, l_inkikan_ato numeric, l_outbuntesuryogaku OUT pkipakichutesuryo.num_array,
	l_outbuntesuryogakuzei OUT pkipakichutesuryo.num_array, l_outjikotesuryogaku OUT numeric,
	l_outjikotesuryogakuzei OUT numeric, l_outtakotesuryogaku OUT numeric, l_outtakotesuryogakuzei OUT numeric ,
	OUT extra_param numeric) RETURNS record AS $$
DECLARE

	/* ==変数定義=================================*/

	l_rowcntbunpai				numeric	:= 0;
	l_rowdahyobunpai			numeric	:= 0;	--代表受託のIndex
	l_rowjikobunpai				numeric	:= 0;	--自行のIndex
	l_bunpaikngk				pkipakichutesuryo.num_array;		--分配手数料金額（従来方式：税抜）
	l_bunpaikngk_mae			pkipakichutesuryo.num_array;		--改定前の分配手数料金額（税込）
	l_bunpaikngk_ato			pkipakichutesuryo.num_array;		--改定後の分配手数料金額（税込）
	l_bunpaitotalkngk			numeric	:= 0;	--分配金額合計　※従来方式で使用
	l_bunpaitotalkngk_mae			numeric	:= 0;	--改定前の分配金額合計
	l_bunpaitotalkngk_ato			numeric	:= 0;	--改定後の分配金額合計
	l_bunpaitotalzeikngk			numeric	:= 0;	--分配消費税合計　※従来方式で使用
	l_bunpaitotalzeikngk_mae		numeric	:= 0;	--改定前の分配消費税合計
	l_bunpaitotalzeikngk_ato		numeric	:= 0;	--改定後の分配消費税合計
	l_szeiritsu_mae				numeric	:= 0;	--改定前の消費税率
	l_szeiritsu_ato				numeric	:= 0;	--改定後の消費税率
	l_tsukaketa				integer	:= 0;	--小数点以下の桁数
	l_hasukngk				numeric	:= 0;	--分配時の端数金額
	l_hasuzeikngk				numeric	:= 0;	--分配時の端数消費税
	l_buntesuryogakuzei_mae			pkipakichutesuryo.num_array;		--改定前の分配手数料の消費税
	l_buntesuryogakuzei_ato			pkipakichutesuryo.num_array;		--改定前の分配手数料の消費税
	/* ==　処理　=================================*/


BEGIN
		l_outjikotesuryogaku := 0;
		l_outtakotesuryogaku := 0;

		l_szeiritsu_mae := PKIPAZEI.getShohiZei(l_instcalcymd);	 -- 改定前の消費税率取得
		l_szeiritsu_ato := PKIPAZEI.getShohiZei(l_inedcalcymd);	 -- 改定後の消費税率取得
		/* JPYまたは外貨の場合の小数点以下の桁数 */

		l_tsukaketa := 0;
		IF l_inhakkotsukacd <> 'JPY' THEN
			l_tsukaketa := 2;		-- JPY以外なら小数点以下2桁まで
		END IF;

		-- 総額方式(0)の場合
		IF l_inszeiprocess = '0' THEN

			--①手数料を分配する
			--取得した分配情報の件数分ループする
			FOR l_rowcntbunpai IN 0..l_inrowmaxbunpai LOOP

				--自行の場合(取得データの委託会社コードと金融機関コードが一致する場合)
				IF l_initakukaishacd = l_inbankcd[l_rowcntbunpai] THEN
					l_rowjikobunpai := l_rowcntbunpai;

				END IF;

				-- 代表受託の場合
				IF l_inbunjtkkbn[l_rowcntbunpai] = '1' THEN

					--代表受託のIndexを一時保存
					l_rowdahyobunpai := l_rowcntbunpai;

				ELSE

					-- 改定前の分配手数料（税込）を計算（改定前の手数料(税込）×（分配率分子/分配率分母））単位未満切捨。
					l_bunpaikngk_mae[l_rowcntbunpai] := trunc(l_intesuryo_mae * l_inbunkichubundfbunshi[l_rowcntbunpai] / l_insstesudfbunbo, l_tsukaketa);

					-- 改定前の分配手数料の合計を加算
					l_bunpaitotalkngk_mae := l_bunpaitotalkngk_mae + l_bunpaikngk_mae[l_rowcntbunpai];

					-- 改定後の分配手数料（税込）を計算（改定後の手数料(税込）×（分配率分子/分配率分母））単位未満切捨。
					l_bunpaikngk_ato[l_rowcntbunpai] := trunc(l_intesuryo_ato * l_inbunkichubundfbunshi[l_rowcntbunpai] / l_insstesudfbunbo, l_tsukaketa);

					-- 改定後の分配手数料の合計を加算
					l_bunpaitotalkngk_ato := l_bunpaitotalkngk_ato + l_bunpaikngk_ato[l_rowcntbunpai];

				END IF;

			END LOOP;

			--②消費税を分配する
			--取得した分配情報の件数分ループする
			FOR l_rowcntbunpai IN 0..l_inrowmaxbunpai LOOP

				-- 代表受託でない場合
				IF l_rowdahyobunpai != l_rowcntbunpai THEN

					--改定前の分配手数料の消費税=改定前の分配手数料(n)×改定前の消費税/（1＋改定前の消費税）単位未満切捨。
					l_buntesuryogakuzei_mae[l_rowcntbunpai] := TRUNC(l_bunpaikngk_mae[l_rowcntbunpai] * l_szeiritsu_mae / (1 + l_szeiritsu_mae) ,l_tsukaketa);

					-- 改定前の分配手数料の消費税の合計を加算
					l_bunpaitotalzeikngk_mae := l_bunpaitotalzeikngk_mae + l_buntesuryogakuzei_mae[l_rowcntbunpai];

					--改定後の分配手数料の消費税=改定後の分配手数料(n)×改定後の消費税/（1＋改定後の消費税）単位未満切捨。
					l_buntesuryogakuzei_ato[l_rowcntbunpai] := TRUNC(l_bunpaikngk_ato[l_rowcntbunpai] * l_szeiritsu_ato / (1 + l_szeiritsu_ato) ,l_tsukaketa);

					-- 改定後の分配手数料の消費税の合計を加算
					l_bunpaitotalzeikngk_ato := l_bunpaitotalzeikngk_ato + l_buntesuryogakuzei_ato[l_rowcntbunpai];

				END IF;

			END LOOP;

			--③分配手数料（税抜）、消費税を算出する
			--取得した分配情報の件数分ループする
			FOR l_rowcntbunpai IN 0..l_inrowmaxbunpai LOOP

				-- 代表受託でない場合
				IF l_rowdahyobunpai != l_rowcntbunpai THEN

					-- 分配手数料の消費税を設定する。　改定前の消費税＋改定後の消費税
					l_outbuntesuryogakuzei[l_rowcntbunpai] := l_buntesuryogakuzei_mae[l_rowcntbunpai] + l_buntesuryogakuzei_ato[l_rowcntbunpai];

					-- 分配手数料（税抜）を設定する。  改定前の分配手数料（税込）＋ 改定後の分配手数料（税込）- 分配手数料の消費税
					l_outbuntesuryogaku[l_rowcntbunpai]:=l_bunpaikngk_mae[l_rowcntbunpai] + l_bunpaikngk_ato[l_rowcntbunpai] - l_outbuntesuryogakuzei[l_rowcntbunpai];

				END IF;

			END LOOP;

			--④分配手数料（税抜）、消費税の代表受託分を設定
			-- 分配手数料の消費税(代表受託分)=全体手数料消費税 - 分配手数料の消費税の合計（代表受託なし分）
			l_outbuntesuryogakuzei[l_rowdahyobunpai] := l_inzentaitesuryozei - (l_bunpaitotalzeikngk_mae + l_bunpaitotalzeikngk_ato);

			-- 分配手数料（税抜）(代表受託分) = 全体手数料額 - 分配手数料（税抜）の合計（代表受託なし分）
			l_outbuntesuryogaku[l_rowdahyobunpai] := l_inzentaitesuryogaku - (l_bunpaitotalkngk_mae + l_bunpaitotalkngk_ato + l_outbuntesuryogakuzei[l_rowdahyobunpai]);

		-- 従来方式の場合
		ELSIF l_inszeiprocess = '1' THEN

			--①手数料を分配する
			--取得した分配情報の件数分ループする
			FOR l_rowcntbunpai IN 0..l_inrowmaxbunpai LOOP

				--自行の場合(取得データの委託会社コードと金融機関コードが一致する場合)
				IF l_initakukaishacd = l_inbankcd[l_rowcntbunpai] THEN
					l_rowjikobunpai := l_rowcntbunpai;

				END IF;

				-- 代表受託の場合
				IF l_inbunjtkkbn[l_rowcntbunpai] = '1' THEN

					--代表受託のIndexを一時保存
					l_rowdahyobunpai := l_rowcntbunpai;

				ELSE

					-- 分配手数料（税抜）を計算（全体手数料額×（分配率分子/分配率分母））単位未満切捨。
					l_bunpaikngk[l_rowcntbunpai] := trunc(l_inzentaitesuryogaku * l_inbunkichubundfbunshi[l_rowcntbunpai] / l_insstesudfbunbo, l_tsukaketa);

					-- 改定前の分配手数料（税抜）を計算（分配手数料（税抜）×（改定前の期間/改定前の期間＋改定後の期間））単位未満切捨。
					l_bunpaikngk_mae[l_rowcntbunpai] := TRUNC(l_bunpaikngk[l_rowcntbunpai] * l_inkikan_mae/(l_inkikan_mae + l_inkikan_ato) , l_tsukaketa);

					-- 改定後の分配手数料（税抜）を計算（分配手数料（税抜）×（改定後の期間/改定前の期間＋改定後の期間））単位未満切捨。
					l_bunpaikngk_ato[l_rowcntbunpai] := TRUNC(l_bunpaikngk[l_rowcntbunpai] * l_inkikan_ato/(l_inkikan_mae + l_inkikan_ato) , l_tsukaketa);

					--改定前の分配手数料の消費税=改定前の分配手数料(税抜)(n)×改定前の消費税　単位未満切捨。
					l_buntesuryogakuzei_mae[l_rowcntbunpai] := trunc(l_bunpaikngk_mae[l_rowcntbunpai] * l_szeiritsu_mae , l_tsukaketa);

					-- 改定後の分配手数料の消費税=改定後の分配手数料(税抜)(n)×改定後の消費税　単位未満切捨。
					l_buntesuryogakuzei_ato[l_rowcntbunpai] := trunc(l_bunpaikngk_ato[l_rowcntbunpai] * l_szeiritsu_ato , l_tsukaketa);

					-- 分配手数料（税抜）を算出する。　改定前の分配手数料（税抜）＋ 改定後の分配手数料（税抜）
					l_outbuntesuryogaku[l_rowcntbunpai]:=l_bunpaikngk_mae[l_rowcntbunpai] + l_bunpaikngk_ato[l_rowcntbunpai];

					-- 分配手数料の合計（代表受託なし分）を加算
					l_bunpaitotalkngk := l_bunpaitotalkngk + l_outbuntesuryogaku[l_rowcntbunpai];

					-- 分配手数料の消費税を算出する。　改定前の分配手数料の消費税＋ 改定後の分配手数料の消費税
					l_outbuntesuryogakuzei[l_rowcntbunpai] := l_buntesuryogakuzei_mae[l_rowcntbunpai] + l_buntesuryogakuzei_ato[l_rowcntbunpai];

					-- 分配手数料の消費税の合計（代表受託なし分）を加算
					l_bunpaitotalzeikngk := l_bunpaitotalzeikngk + l_outbuntesuryogakuzei[l_rowcntbunpai];

				END IF;

			END LOOP;

			--②分配手数料（税抜）、消費税の代表受託分を設定
			-- 分配手数料（税抜）(代表受託分)=全体手数料額 - 分配手数料（税抜）の合計（代表受託なし分）
			l_outbuntesuryogaku[l_rowdahyobunpai]:=l_inzentaitesuryogaku - l_bunpaitotalkngk;

			-- 分配手数料の消費税(代表受託分)=全体手数料消費税 - 分配手数料の消費税の合計（代表受託なし分）
			l_outbuntesuryogakuzei[l_rowdahyobunpai]:=l_inzentaitesuryozei - l_bunpaitotalzeikngk;

		END IF;

		--自行の手数料・消費税額を計算する
		l_outjikotesuryogaku    := l_outbuntesuryogaku[l_rowjikobunpai];
		l_outjikotesuryogakuzei := l_outbuntesuryogakuzei[l_rowjikobunpai];

		--他行の手数料・消費税額を計算する
		-- 総額方式の場合
		IF l_inszeiprocess = '0' THEN

			-- 他行の手数料 = 全体手数料（税込）−全体消費税 −自行手数料
			l_outtakotesuryogaku := l_inzentaitesuryogaku - l_inzentaitesuryozei - l_outjikotesuryogaku;

		-- 従来方式の場合（手数料（税抜）−自行手数料）
		ELSIF l_inszeiprocess = '1' THEN

			-- 他行の手数料 = 全体手数料（税抜）−自行手数料
			l_outtakotesuryogaku := l_inzentaitesuryogaku - l_outjikotesuryogaku;

		END IF;

		-- 他行の消費税 = 全体手数料消費税 - 自行手数料消費税
		l_outtakotesuryogakuzei := l_inzentaitesuryozei - l_outjikotesuryogakuzei;

		extra_param := pkConstant.SUCCESS();

		RETURN;

	EXCEPTION
		WHEN OTHERS THEN
			extra_param := pkConstant.FATAL();
			RETURN;
END $$ LANGUAGE PLPGSQL;

	/********************************************************************************
	 * 金融機関コード、金融機関略称の情報取得。
	 *
	 * @param p_inItakuKaishaCd			委託会社コード
	 * @param p_inMgrCd					銘柄コード
	 * @param p_outBankCd				金融機関コード
	 * @param p_outBankRnm				金融機関略称
	 * @return 							正常終了/異常終了
	********************************************************************************/
CREATE OR REPLACE FUNCTION pkipakichutesuryo.getmbank_cd_rnm (
	p_inItakuKaishaCd MGR_JUTAKUGINKO.ITAKU_KAISHA_CD%TYPE, p_inMgrCd MGR_JUTAKUGINKO.MGR_CD%TYPE,
	p_outBankCd OUT MGR_JUTAKUGINKO.BANK_CD%TYPE, p_outBankRnm OUT MBANK.BANK_RNM%TYPE , OUT extra_param numeric) RETURNS record AS $$
DECLARE


	CUR_BANK CURSOR FOR
		SELECT MG6.BANK_CD AS BANK_CD ,M02.BANK_RNM AS BANK_RNM

		FROM MGR_JUTAKUGINKO MG6,
			MBANK M02

		WHERE MG6.FINANCIAL_SECURITIES_KBN = M02.FINANCIAL_SECURITIES_KBN
		AND	MG6.BANK_CD = M02.BANK_CD
		AND MG6.ITAKU_KAISHA_CD = p_inItakuKaishaCd
		AND MG6.MGR_CD = p_inMgrCd

		ORDER BY MG6.ITAKU_KAISHA_CD,
				MG6.MGR_CD,
				MG6.INPUT_NUM;


BEGIN

		FOR rec IN CUR_BANK LOOP
			--一件目は対象データ。
			p_outBankCd 	:= rec.BANK_CD;
			p_outBankRnm 	:= rec.BANK_RNM;

			EXIT;

		END LOOP;

		extra_param := pkConstant.SUCCESS();

		RETURN;
	EXCEPTION
		WHEN OTHERS THEN
			CALL pkLog.FATAL('', '', SQLSTATE || SUBSTR(SQLERRM, 1, 50));
			extra_param := pkConstant.FATAL();
			RETURN;
END $$ LANGUAGE PLPGSQL;
-- REVOKE ALL ON FUNCTION pkipakichutesuryo.getmbank_cd_rnm ( p_inItakuKaishaCd MGR_JUTAKUGINKO.ITAKU_KAISHA_CD%TYPE, p_inMgrCd MGR_JUTAKUGINKO.MGR_CD%TYPE, p_outBankCd OUT MGR_JUTAKUGINKO.BANK_CD%TYPE, p_outBankRnm OUT MBANK.BANK_RNM%TYPE , OUT extra_param numeric) FROM PUBLIC;

/********************************************************************************
	* 総額従来判定フラグの情報取得。
	*
	* @param p_inItakuKaishaCd  		委託会社コード
	* @param p_inBankCd         		金融機関コード
	* @param p_outHanteiFlg     		総額従来判定フラグ
	* @return 							正常終了/異常終了
********************************************************************************/
CREATE OR REPLACE FUNCTION pkipakichutesuryo.getsouju_hantei_flg ( p_inItakuKaishaCd TESURYO_SOUJU_HANTEI.ITAKU_KAISHA_CD%TYPE, p_inBankCd TESURYO_SOUJU_HANTEI.BANK_CD%TYPE, p_outHanteiFlg OUT TESURYO_SOUJU_HANTEI.SOUJU_HANTEI_FLG%TYPE , OUT extra_param numeric) RETURNS record AS $$
BEGIN
	SELECT SOUJU_HANTEI_FLG
	INTO STRICT p_outHanteiFlg

	FROM TESURYO_SOUJU_HANTEI
	WHERE 	ITAKU_KAISHA_CD = p_inItakuKaishaCd
	AND 	BANK_CD			= p_inBankCd;

	extra_param := pkConstant.SUCCESS();

	RETURN;
EXCEPTION
	WHEN no_data_found THEN
		p_outHanteiFlg := NULL;
		extra_param := pkConstant.ERROR();
		RETURN;

WHEN OTHERS THEN
	CALL pkLog.FATAL('', '', SQLSTATE || SUBSTR(SQLERRM, 1, 50));
extra_param := pkConstant.FATAL();
RETURN;
END $$ LANGUAGE PLPGSQL;
-- REVOKE ALL ON FUNCTION pkipakichutesuryo.getsouju_hantei_flg ( p_inItakuKaishaCd TESURYO_SOUJU_HANTEI.ITAKU_KAISHA_CD%TYPE, p_inBankCd TESURYO_SOUJU_HANTEI.BANK_CD%TYPE, p_outHanteiFlg OUT TESURYO_SOUJU_HANTEI.SOUJU_HANTEI_FLG%TYPE , OUT extra_param numeric) FROM PUBLIC;


/**
* 手数料計算結果テーブル再作成<br>
* パラメータで指定した銘柄情報を抽出し、取得レコードを編集した結果を
* 手数料計算結果テーブルに更新する
*
* ※当パッケージ内　各Function呼出元
*
* @param	l_initakukaishacd		委託会社コード
* @param	l_inmgrcd				銘柄コード
* @param	l_intesucd				手数料種類コード
* @param	l_indate				徴求日
* @param	l_injobkbn				作成区分
* @param	l_inKessanKijunYmd		期末日
* @param	l_inChokyuKjt			徴求期日
* @param	l_outOwnTesuKngk		自行手数料額（税抜）
* @param	l_outOwnTesuSzei		自行消費税額

* @return	l_return				正常終了/以上終了 f
*/
CREATE OR REPLACE FUNCTION pkipakichutesuryo.updateKichuTesuryoTbl_Sai(
								l_initakukaishacd		IN VARCHAR
								,l_inmgrcd				IN VARCHAR
								,l_intesucd				IN VARCHAR
								,l_indate				IN VARCHAR
								,l_injobkbn				IN VARCHAR
								,l_inKessanKijunYmd		IN VARCHAR
								,l_inChokyuKjt			IN VARCHAR
								,l_outOwnTesuKngk		OUT NUMERIC
								,l_outOwnTesuSzei		OUT NUMERIC
								,result out numeric
)
RETURNS record AS $$
DECLARE
	/*==============================================================================*/
	/*                  定数定義                                                    */
	/*==============================================================================*/

	/*==============================================================================*/
	/*					変数定義													*/
	/*==============================================================================*/
	l_return					NUMERIC;
	-- SQL編集
	l_strSql VARCHAR(10000)		DEFAULT NULL;

	l_rowcnt					NUMERIC	DEFAULT 0;

	l_rowmaxbunpai				NUMERIC	DEFAULT 0;
	l_rowcntbunpai				NUMERIC	DEFAULT 0;

	l_szeiseikyukbn				CHAR(1)	DEFAULT '0';			-- 消費税請求区分　0=請求しない 1=請求する
	l_ebymd						CHAR(8)	DEFAULT ' ';			-- 手数料計算結果テーブルに登録済みのEB作成年月日
	l_ebflg						CHAR(1)	DEFAULT ' ';			-- 自行・委託会社ビュー の EB送信FLG
	l_szeiprocess				MPROCESS_CTL.CTL_VALUE%type;	-- 消費税算出方式（総額：0　従来：1）
	l_tesuryogaku				NUMERIC	DEFAULT	0;				-- 手数料額（総額方式：税込、従来方式：税抜）

	l_option_flg				MOPTION_KANRI.OPTION_FLG%TYPE;				--オプションフラグ
	l_BankCd					MGR_JUTAKUGINKO.BANK_CD%TYPE;				--金融機関コード
	l_BankRnm					MBANK.BANK_RNM%TYPE;						--金融機関略称
	l_HanteiFlg					TESURYO_SOUJU_HANTEI.SOUJU_HANTEI_FLG%TYPE;	--総額従来判定フラグ

	l_heizonseikyukbn			CHAR(1) DEFAULT 0;
	l_jissu						NUMERIC(2) DEFAULT 3;
	l_hasuFlg					CHAR(1) DEFAULT '0';	-- 端数判定フラグ（端数なし：0　端数あり：1）

	l_ShzKijunYmd				VARCHAR(8);			-- 消費税率適用基準日

	-- 分配手数料の分かち計算で使用するため追加
	l_tesuryo_mae				NUMERIC DEFAULT 0;		-- 改定前の手数料(税込)
	l_tesuryo_ato				NUMERIC DEFAULT 0;		-- 改定後の手数料(税込)
	l_tesuryozei_mae			NUMERIC DEFAULT 0;		-- 改定前の消費税
	l_tesuryozei_ato			NUMERIC DEFAULT 0;		-- 改定後の消費税
	l_kikan_mae					NUMERIC DEFAULT 0;		-- 改定前の期間
	l_kikan_ato					NUMERIC DEFAULT 0;		-- 改定後の期間

	-- カーソル
	curRec						REFCURSOR;
	curTesuRec					REFCURSOR;

	/*	取得データ格納用変数リスト	*/
	p_itakukaishacd			CHAR(4);										--	委託会社コード
	p_mgrcd					VARCHAR(13);									--	銘柄コード
	p_jtkkbn				CHAR(1);										--	受託区分
	p_tesushuruicd			CHAR(2);										--	手数料種類コード
	p_hakkotsukacd			CHAR(3);										--	発行通貨コード
	p_chokyukjt				CHAR(8);										--	徴求期日
	p_chokyuymd				CHAR(8);										--	徴求日
	p_distriymd				CHAR(8);										--	分配日
	p_hakkoymd				CHAR(8);										--	発行年月日
	p_fullshokanymd			CHAR(8);										--	満期償還日
	p_ebmakeymd				CHAR(8);										--	EB作成年月日	--	徴求日-EB作成日営業日前
	p_ebsendymd				CHAR(8);										--	EB送信年月日	--	徴求日-EB送信日営業日前
	p_nyukinymd				CHAR(8);										--	入金日
	p_tesusashihikikbn		CHAR(1);										--	手数料差引区分
	p_eigyotencd			CHAR(4);										--	営業店コード
	p_kozafurikbn			CHAR(2);										--	口座振替区分
	p_kozatencd				CHAR(4);										--	口座店コード
	p_firstlastkichukbn		CHAR(1);										--	初期・終期・期中区分
	p_calcpatterncd			MGR_TESKIJ.CALC_PATTERN_CD%TYPE;				--	計算パターンコード
	p_ssteigakutesukngk		NUMERIC;											--	信託報酬・社管手数料定額手数料
	p_stcalcymd				CHAR(8);										--	計算開始日
	p_edcalcymd				CHAR(8);										--	計算終了日
	p_zndkkijunymd			CHAR(8);										--	残高基準日
	p_billoutymd			CHAR(8);										--	請求書出力日
	p_sstesubunbo			NUMERIC;											--	信託報酬・社債管理手数料率（分母）
	p_sstesubunshi			NUMERIC;											--	信託報酬・社債管理手数料率（分子）
	p_sstesudfbunbo			NUMERIC;											--	信託報酬・社債管理手数料分配率（分母）
	p_ssnenchokyucnt		NUMERIC;											--	信託報酬・社管手数料年徴求回数
	p_datasakuseikbn		TESURYO.DATA_SAKUSEI_KBN%TYPE;					--	データ作成区分
	p_calcpatterncd2		MGR_TESURYO_PRM.CALC_PATTERN_CD%TYPE;			--	計算パターンコード(MG8)
	p_zndkkakuteikbn		MGR_TESURYO_PRM.ZNDK_KAKUTEI_KBN%TYPE;			--	残高確定区分
	p_zengokbn				MGR_TESURYO_PRM.ZENGO_KBN%TYPE;					--	前取後取区分
	p_daymonthkbn			MGR_TESURYO_PRM.DAY_MONTH_KBN%TYPE;				--	日割月割区分
	p_hasunissucalckbn		MGR_TESURYO_PRM.HASU_NISSU_CALC_KBN%TYPE;		--	端数日数計算区分（端数期間分母日数計算区分）
	p_calcymdkbn			MGR_TESURYO_PRM.CALC_YMD_KBN%TYPE;				--	計算期間区分
	p_sscalcymd2			MGR_TESURYO_PRM.SS_CALC_YMD2%TYPE;				--	信託報酬・社管手数料_計算期間２
	p_matsuFlg				MGR_TESURYO_PRM.SS_CALC_YMD2_GMATSU_FLG%TYPE;	--	信託報酬・社管手数料_計算期間月末フラグ２

	p_bun_itakukaishacd				pkipakichutesuryo.CH4_ARRAY;	--	委託会社コード
	p_bun_mgrcd						pkipakichutesuryo.VCR_ARRAY;	--	銘柄コード
	p_bun_groupid					pkipakichutesuryo.CH3_ARRAY;	--	グループID
	p_bun_tesushuruicd				pkipakichutesuryo.CH2_ARRAY;	--	手数料種類コード
	p_bun_jtkkbn					pkipakichutesuryo.CH1_ARRAY;	--	受託区分
	p_bun_chokyukjt					pkipakichutesuryo.CHR_ARRAY;	--	徴求期日
	p_bun_chokyuymd					pkipakichutesuryo.CHR_ARRAY;	--	徴求日
	p_bun_financialsecuritieskbn	pkipakichutesuryo.CH1_ARRAY;	--	金融証券区分
	p_bun_bankcd					pkipakichutesuryo.CH4_ARRAY;	--	金融機関コード
	p_bun_kichubundfbunshi			pkipakichutesuryo.NUM_ARRAY;	--	分配率(分子)

	p_outoudd				numeric	DEFAULT	0	;							--	応答日
	p_ssteigakutesukngkzei	numeric	DEFAULT	0	;							--	信託報酬・社管手数料定額手数料（税込）
	p_kjnzndk				numeric	DEFAULT	0	;							--	基準残高
	p_kikananbun			numeric	DEFAULT	0	;							--	期間按分
	p_zentaitesuryozeikomi	numeric	DEFAULT	0	;							--	全体手数料額（税込）
	p_zentaitesuryogaku		numeric	DEFAULT	0	;							--	全体手数料額（税抜）
	p_zentaitesuryogakuzei	numeric	DEFAULT	0	;							--	全体手数料額
	p_jikotesuryogaku		numeric	DEFAULT	0	;							--	自行手数料額（税抜）
	p_jikotesuryogakuzei	numeric	DEFAULT	0	;							--	自行手数料額
	p_takotesuryogaku		numeric	DEFAULT	0	;							--	他行手数料額（税抜）
	p_takotesuryogakuzei	numeric	DEFAULT	0	;							--	他行手数料額
	p_hasutsuki				CHAR(6)	DEFAULT	'	';							--	端数月
	p_hankanenoutkbn		CHAR(1)	DEFAULT	'	';							--	半か年外出し区分
	p_tsukiwarifrom			CHAR(8)	DEFAULT	'	';							--	月割期間From
	p_tsukiwarito			CHAR(8)	DEFAULT	'	';							--	月割期間To
	p_tsukisu				numeric	DEFAULT	0	;							--	月数
	p_hiwarifrom			CHAR(8)	DEFAULT	'	';							--	日割期間From
	p_hiwarito				CHAR(8)	DEFAULT	'	';							--	日割期間To
	p_nissu					numeric	DEFAULT	0	;							--	日数
	p_keisanbibunbo			numeric	DEFAULT	0;								--	計算式日（分母）
	p_keisanbibunshi		numeric	DEFAULT	0;								--	計算式日（分子）

	p_hiwaribunbofrom		CHAR(8)	;										--	分母期間From
	p_hiwaribunboto			CHAR(8)	;										--	分母期間To

	p_wakachi					CHAR(1) DEFAULT ' ';						-- 分かち計算する(1)・しない(0)
	p_tsukisu_mae    				numeric	DEFAULT 0;						-- 改定前の月数
	p_tsukisu_ato    				numeric	DEFAULT 0;						-- 改定後の月数
	p_tekiyost_ymd					CHAR(8)	DEFAULT	'	';					-- 消費税適用日

	p_keisanyymmdd					pkipakichutesuryo.CHR_ARRAY;			--計算期間（年月日）※計算開始日〜終了日を月別に分解し、月の先頭日を設定する

	p_shohizei_sai					CHAR(1) DEFAULT ' ';					-- 消費税の差異あり(0)・なし(1)

	bun_itakukaishacd				char(4);
	bun_mgrcd						varchar(20);
	bun_groupid						char(3);
	bun_tesushuruicd				char(2);
	bun_jtkkbn						char(1);
	bun_chokyukjt					char(8);
	bun_chokyuymd					char(8);
	bun_financialsecuritieskbn		char(1);
	bun_bankcd						char(4);
	bun_kichubundfbunshi			numeric;

	rec								record;

	p_keisanyydd					pkipakichutesuryo.CH6_ARRAY;
	p_tsukizndk						pkipakichutesuryo.NUM_ARRAY;
	p_tsukitesuryo					pkipakichutesuryo.NUM_ARRAY;

	--以下は取得データから計算してセットする項目
	p_bun_tesuryogaku				pkipakichutesuryo.NUM_ARRAY;	--	分配手数料額（税抜）
	p_bun_tesuryogakuzei			pkipakichutesuryo.NUM_ARRAY;	--	分配手数料額

/*==============================================================================*/
/*	メイン処理	*/
/*==============================================================================*/
BEGIN

CALL PKLOG.debug('batch', 'PKIPAKICHUTESURYO', '-------------------PKIPAKICHUTESURYO.UPDATEKICHUTESURYO START------------------');

l_outOwnTesuKngk := 0; -- 自行手数料額（税抜）
l_outOwnTesuSzei := 0; -- 自行消費税額

/* 特例社債でかつ徴求日が償還日(振替移行時)より小さい場合は正常終了で処理を抜ける */
IF pkipakichutesuryo.isUpdate(l_initakukaishacd,l_inmgrcd,l_indate) = 1 THEN
	result := pkConstant.SUCCESS();
	return;
END IF;

/* データ取得 */
l_strSql := pkipakichutesuryo.createGetDataSql(l_initakukaishacd,l_inmgrcd,l_intesucd,l_indate,0);

OPEN curTesuRec FOR EXECUTE l_strSql;
LOOP
	FETCH curTesuRec INTO
		p_itakukaishacd,				-- 委託会社コード
		p_mgrcd,						-- 銘柄コード
		p_jtkkbn,						-- 受託区分
		p_tesushuruicd,					-- 手数料種類コード
		p_hakkotsukacd,					-- 発行通貨コード
		p_chokyukjt,					-- 徴求期日
		p_chokyuymd,					-- 徴求日
		p_distriymd,					-- 分配日
		p_hakkoymd,						-- 発行年月日
		p_fullshokanymd,				-- 満期償還日
		p_ebmakeymd,					-- EB作成年月日  -- 徴求日-EB作成日営業日前
		p_ebsendymd,					-- EB送信年月日  -- 徴求日-EB送信日営業日前
		p_nyukinymd,					-- 入金日
		p_tesusashihikikbn,				-- 手数料差引区分
		p_eigyotencd,					-- 営業店コード
		p_kozafurikbn,					-- 口座振替区分
		p_kozatencd,					-- 口座店コード
		p_firstlastkichukbn,			-- 初期・期中・終期区分
		p_calcpatterncd,				-- 計算パターンコード
		p_ssteigakutesukngk,			-- 信託報酬・社管手数料定額手数料
		p_stcalcymd,					-- 計算開始日
		p_edcalcymd,					-- 計算終了日
		p_zndkkijunymd,					-- 残高基準日
		p_billoutymd,					-- 請求書出力日
		p_sstesubunbo,					-- 信託報酬・社債管理手数料率（分母）
		p_sstesubunshi,					-- 信託報酬・社債管理手数料率（分子）
		p_sstesudfbunbo,				-- 信託報酬・社債管理手数料分配率（分母）
		p_ssnenchokyucnt,				-- 信託報酬・社管手数料年徴求回数
		p_datasakuseikbn,				-- データ作成区分
		p_calcpatterncd2,				-- 計算パターンコード
		p_zndkkakuteikbn,				-- 残高確定区分
		p_zengokbn,						-- 前取後取区分
		p_daymonthkbn,					-- 端数日数日割月割区分
		p_hasunissucalckbn,				-- 端数日数計算区分
		p_calcymdkbn,					-- 計算期間区分
		p_sscalcymd2,					-- 信託報酬・社管手数料_計算期間２
		p_matsuFlg,						-- 信託報酬・社管手数料_計算期間月末フラグ２

		l_szeiseikyukbn,				-- 消費税請求区分
		l_ebymd,						-- 手数料計算結果テーブルのEB作成年月日
		l_ebflg,						-- EB作成フラグ
		l_heizonseikyukbn;				-- 並存請求区分
		EXIT WHEN NOT FOUND;

	l_outOwnTesuKngk := 0; -- 自行手数料額（税抜）
	l_outOwnTesuSzei := 0; -- 自行消費税額

	IF p_chokyukjt <> l_inChokyuKjt THEN
		--再計算対象外のとき、次のループ
		CONTINUE;

	END IF;

	/* 自行委託会社ビュー.EB作成フラグ が 作成する の場合以外は、EB作成・送信年月日に初期値をセット */
	IF l_ebflg <> '1' THEN
			p_ebsendymd := ' ';			-- EB送信年月日
	END IF;

	-- 半か年区分のデフォルト（2=外出しなし）
	p_hankanenoutkbn := '2';

	-- オプション管理マスタより、処理制御値を取得する。
	l_option_flg := pkControl.getOPTION_FLG(l_initakukaishaCd, 'REDPROJECT', '0');

	IF l_option_flg = '1' AND p_jtkkbn = '2' THEN
		--オプションフラグ＝’1’:あり　かつ　受託区分＝’２’（副受託）の場合
		select * into
			l_BankCd,				--金融機関コード
			l_BankRnm,				--金融機関略称
			l_return
		from pkIpaKichuTesuryo.getMbank_Cd_Rnm(
			l_initakukaishacd,	--委託会社コード
			l_inmgrcd				--銘柄コード
		);

		IF l_return <> pkConstant.SUCCESS() THEN
			result := pkConstant.FATAL();
			return;
		END IF;

		select * into
			l_HanteiFlg,			--総額従来判定フラグ
			l_return
		from pkIpaKichuTesuryo.getSouju_Hantei_Flg(
			l_initakukaishacd,	--委託会社コード
			l_BankCd			--金融機関コード
		);

		IF l_return = pkConstant.FATAL() THEN
			result := pkConstant.FATAL();
			return;
		END IF;

		IF l_return = pkConstant.ERROR() THEN
			--手数料従来方式テーブルには金融機関コードが存在しません。
			CALL PKLOG.ERROR('ECM701','PKIPAKICHUTESURYO',l_BankRnm || 'の消費税算出方式が登録されていません。システム管理部署に追加の依頼をしてください。');
			result := pkConstant.FATAL();
			return;
		END IF;

		l_szeiprocess := l_HanteiFlg;

	ELSE

		-- MPROCESS_CTLテーブルより、総額・従来判定フラグを取得する
		l_szeiprocess := pkControl.getCtlValue(l_initakukaishaCd, 'CALCTESUKNGK0', '0');

	END IF;

	/* -----取得データから値を計算および編集----- */
	/* 応答日 */
	IF p_ssnenchokyucnt = 0 THEN
		p_ssnenchokyucnt := 1;
	END IF;
	p_outoudd := 12 / oracle.TO_NUMBER(p_ssnenchokyucnt);

	/* 基準残高取得 */
	--手数料計算の為の基準残高を取得する。(定額方式（4）以外の場合）
	-- 並存銘柄請求書出力区分が'1'の場合は、'3'ではなく'93'を渡す
	IF l_heizonseikyukbn = '1' THEN
		l_jissu := 93; -- 振替債+現登債…93
	ELSE l_jissu := 3; -- 実質残高…3
	END IF;

	l_return :=	pkipakichutesuryo.getZndk(l_initakukaishacd,
					l_inmgrcd,
					p_zndkkijunymd,
					p_stcalcymd,
					l_inKessanKijunYmd,
					p_hakkoymd,
					p_fullshokanymd,
					p_calcpatterncd,
					p_zndkkakuteikbn,
					l_jissu,
					p_kjnzndk,
					p_keisanyydd,
					p_tsukizndk);

	IF l_return <> pkConstant.SUCCESS() THEN
		result := pkConstant.FATAL();
		return;
	END IF;

	-- 月割・日割期間From−Toの初期化
	p_tsukiwarifrom := ' ';
	p_tsukiwarito   := ' ';
	p_hiwarifrom    := ' ';
	p_hiwarito      := ' ';
	p_tsukisu       :=  0 ;
	p_hasutsuki     := ' ';

	--端数判定フラグの初期化
	l_hasuFlg := '0';

	/* 月数、月割部分From-To、端数月 */
	--端数期間日割月割区分＝「月割日割」（1）、「月割」（3）、「日割（端数期間のみ）」（4）、（月割（端数期間切捨）(5)の場合のみ取得
	IF p_daymonthkbn IN('1','3','4','5') THEN
		select * into
			p_tsukiwarifrom,
			p_tsukiwarito,
			p_tsukisu,
			p_hasutsuki,
			l_return
		from pkipakichutesuryo.getMonthFromTo(
			p_stcalcymd,
			l_inKessanKijunYmd,
			p_daymonthkbn,
			p_calcymdkbn,
			p_matsuFlg,		-- 計算期間月末フラグ２
			p_firstlastkichukbn,
			p_outoudd,
			p_sscalcymd2
		);

		IF l_return <> pkConstant.SUCCESS() THEN
			result := pkConstant.FATAL();
			return;
		END IF;

		--端数期間日割月割区分＝「日割（端数期間のみ）」（4）の場合、端数判定を行う
		IF p_daymonthkbn = '4' THEN
			--端数判定
			IF TRIM(p_hasutsuki) IS NULL THEN
				IF p_outoudd != p_tsukisu THEN
					--端数月が設定されていないかつ月数!=12/年徴求回数の場合は「端数あり」
					l_hasuFlg := '1';
				END IF;
			ELSE
				--端数月が設定されている場合は「端数あり」
				l_hasuFlg := '1';
			END IF;
		END IF;

		--「端数あり」の場合、月割・日割期間From−Toの初期化を初期化
		IF l_hasuFlg = '1' THEN
			p_tsukiwarifrom := ' ';
			p_tsukiwarito   := ' ';
			p_hiwarifrom    := ' ';
			p_hiwarito      := ' ';
			p_tsukisu       :=  0 ;
			p_hasutsuki     := ' ';
		END IF;

	END IF;

	-- 端数期間日割月割区分＝「月割日割」（1）、「日割」（2）、
	--「日割（端数期間のみ）」（4）かつ「端数あり」の場合のみ
	-- 日数取得 と 期間按分取得 を行う
	-- 変数初期化
	p_hiwarifrom      := ' ';			-- 分子期間From
	p_hiwarito        := ' ';			-- 分子期間To
	p_nissu           := 0;				-- 日数
	p_hankanenoutkbn  := '2';			-- 半か年区分
	p_keisanbibunshi  := 0;				-- 期間按分分子
	p_hiwaribunbofrom := ' ';			-- 分母期間From
	p_hiwaribunboto   := ' ';			-- 分母期間To
	p_keisanbibunbo   := 0;				-- 期間按分分母
	p_kikananbun      := 0;				-- 期間按分

	IF p_daymonthkbn IN('1','2') OR (p_daymonthkbn = '4' AND l_hasuFlg = '1') THEN

		/* 日割部分From-To、日数 */
		select * into
						p_hiwarifrom,
						p_hiwarito,
						p_nissu,
						p_hankanenoutkbn,
						l_return
		from pkipakichutesuryo.getDateFromTo(p_stcalcymd,
						l_inKessanKijunYmd,
						p_daymonthkbn,
						p_calcymdkbn,
						p_matsuFlg,		-- 計算期間月末フラグ２
						p_tsukiwarifrom,
						p_tsukiwarito,
						p_tsukisu,
						p_hasutsuki,
						p_firstlastkichukbn,
						p_hasunissucalckbn,
						p_outoudd,
						p_sscalcymd2
		);

		IF l_return <> pkConstant.SUCCESS() THEN
			result := pkConstant.FATAL();
			return;
		END IF;

		/* 期間按分、期間按分分子、期間按分分母、日割部分From-To、半か年外出し区分 取得 */
		select * into
												p_kikananbun,			-- 期間按分
												p_hiwarifrom,			-- 分子期間From
												p_hiwarito,				-- 分子期間To
												p_keisanbibunshi,		-- 期間按分分子
												p_hiwaribunbofrom,		-- 分母期間From
												p_hiwaribunboto,		-- 分母期間To
												p_keisanbibunbo,
												l_return
		from pkIpaKichuTesuryo.getKikanAnbun(p_hiwarifrom,
												p_hiwarito,
												p_ssnenchokyucnt,
												p_hasunissucalckbn,
												p_matsuFlg,				-- 計算期間月末フラグ２
												p_firstlastkichukbn,
												p_hankanenoutkbn,
												p_sscalcymd2
		);		-- 期間按分分母

		IF l_return <> pkConstant.SUCCESS() THEN
			result := pkConstant.FATAL();
			return;
		END IF;

	END IF;

	/* 手数料計算前の準備 */

	-- 月割期間From-Toが無い場合は月数（月割期間分子）を初期化
	IF TRIM(p_tsukiwarifrom || p_tsukiwarito) IS NULL THEN
		p_tsukisu := 0;
	END IF;

	/******************************/
	/* 分かち計算を行う処理を追加 */
	/******************************/

	/* 月数取得(分かち計算用）を実行する。*/
	p_tsukisu_mae  := 0;
	p_tsukisu_ato  := 0;
	p_wakachi := '0';	--分かち計算しないを設定
	p_shohizei_sai := '0';  -- 消費税の差異　差異あり(初期値:0)を設定

	-- cannot use select into variable of type record or row
	rec := pkipakichutesuryo.getMonthFromTo_Wakachi(
			l_initakukaishaCd,	--委託会社コード
			p_stcalcymd,	--計算開始日
			l_inKessanKijunYmd,	--期末日
			p_tsukisu,
			p_firstlastkichukbn,
			l_szeiseikyukbn	-- 消費税を請求する(1)・しない(0)
	);

	p_keisanyymmdd := rec.l_outkeisanyymmdd;
	p_tsukisu_mae := rec.l_outtsukisu_mae;  --改定前の月数
	p_tsukisu_ato := rec.l_outtsukisu_ato;  --改定後の月数
	p_wakachi := rec.l_outwakachi;	--分かち計算する・しない
	p_tekiyost_ymd := rec.l_outtekiyost_ymd; --消費税適用日
	p_shohizei_sai := rec.l_outshohizei_sai; --消費税率の差異あり・なし ※差異なし=1 差異あり=0
	l_return := rec.extra_param;

	IF l_return <> pkConstant.SUCCESS() THEN
		result := pkConstant.FATAL();
		return;
	END IF;

	/* 分かち計算する場合 */
	IF p_wakachi = '1' THEN

		/* 手数料計算(分かち計算用）を実行する。*/
		rec := pkipakichutesuryo.calcTesuryo_Wakachi(
							l_szeiprocess,
							p_stcalcymd,
							p_tsukiwarifrom,
							p_hiwarifrom,
							p_calcpatterncd,
							p_tsukisu,
							p_kjnzndk,
							p_ssteigakutesukngk,
							p_sstesubunshi,
							p_sstesubunbo,
							p_chokyuymd,
							p_hakkotsukacd,
							p_keisanyydd,
							p_tsukizndk,
							p_keisanbibunshi,
							p_keisanbibunbo,
							p_hasunissucalckbn,
							p_ssnenchokyucnt,
							l_inKessanKijunYmd,   --期末日
							p_tsukisu_mae, --改定前の月数
							p_tsukisu_ato, --改定後の月数
							p_tekiyost_ymd, --改定後の消費税適用日
							p_keisanyymmdd  -- 計算期間（年月日）※月別に設定
		);

		p_zentaitesuryozeikomi := rec.l_outtesuryo; --全体手数料額(税込)
		p_zentaitesuryogakuzei := rec.l_outtesuryozei; --消費税額
		p_zentaitesuryogaku := rec.l_outtesuryonuki;	 --手数料額(税抜)
		p_tsukitesuryo := rec.l_outtsukitesuryo; --月毎手数料1〜13
		l_tesuryo_mae := rec.l_outtesuryo_mae;	-- 改定前の手数料(税込)
		l_tesuryo_ato := rec.l_outtesuryo_ato;	-- 改定後の手数料(税込)
		l_tesuryozei_mae := rec.l_outtesuryozei_mae; -- 改定前の消費税
		l_tesuryozei_ato := rec.l_outtesuryozei_ato; -- 改定後の消費税
		l_kikan_mae := rec.l_outkikan_mae;      -- 改定前の期間
		l_kikan_ato := rec.l_outkikan_ato;       -- 改定後の期間
		l_return := rec.extra_param;

	ELSE

		-- 発行時一括の場合
		IF TRIM(p_calcpatterncd) IS NULL THEN
			-- 発行日を取得する
			l_ShzKijunYmd := pkIpacalctesuryo.getHakkoYmd(p_itakukaishacd,p_mgrcd);

		ELSE

			-- 分かち計算ありで消費税の差異がない場合
			IF p_shohizei_sai = '1' THEN

				-- 基準日に計算開始日を設定
				l_ShzKijunYmd := p_stcalcymd;

			-- 分かち計算なし場合
			ELSE
				-- 基準日に徴求日を設定
				l_ShzKijunYmd := p_chokyuymd;

			END IF;

		END IF;

		/* 期中手数料・月毎期中手数料(1〜13)を計算する */
		rec := pkipakichutesuryo.calcTesuryo(
							l_szeiprocess,
							p_stcalcymd,
							p_tsukiwarifrom,
							p_hiwarifrom,
							p_calcpatterncd,
							p_tsukisu,
							p_kjnzndk,
							p_ssteigakutesukngk,
							p_sstesubunshi,
							p_sstesubunbo,
							l_ShzKijunYmd,
							p_hakkotsukacd,
							l_szeiseikyukbn,
							p_keisanyydd,
							p_tsukizndk,
							p_keisanbibunshi,
							p_keisanbibunbo,
							p_hasunissucalckbn,
							p_ssnenchokyucnt
		);			--月毎手数料1〜13

		p_zentaitesuryozeikomi := rec.l_outtesuryo;		--手数料額(税込)
		p_zentaitesuryogakuzei := rec.l_outtesuryozei;		--消費税額
		p_zentaitesuryogaku := rec.l_outtesuryonuki;			--手数料額(税抜)
		p_tsukitesuryo := rec.l_outtsukitesuryo;
		l_return := rec.extra_param;

	END IF;


	IF l_return <> pkConstant.SUCCESS() THEN
		result := pkConstant.FATAL();
		return;
	END IF;

	/* 分配情報を取得 */
	l_strSql := pkipakichutesuryo.createGetBunpaiDataSql(l_initakukaishacd,l_inmgrcd ,p_chokyukjt ,l_intesucd ,l_indate);

	OPEN curRec FOR EXECUTE l_strSql;

	LOOP

		FETCH curRec INTO
			bun_itakukaishacd,
			bun_mgrcd,
			bun_groupid,
			bun_tesushuruicd,
			bun_jtkkbn,
			bun_chokyukjt,
			bun_chokyuymd,
			bun_financialsecuritieskbn,
			bun_bankcd,
			bun_kichubundfbunshi;

		EXIT WHEN NOT FOUND;

		p_bun_itakukaishacd[l_rowcntbunpai] := bun_itakukaishacd;
		p_bun_mgrcd[l_rowcntbunpai] := bun_mgrcd;
		p_bun_groupid[l_rowcntbunpai] := bun_groupid;
		p_bun_tesushuruicd[l_rowcntbunpai] := bun_tesushuruicd;
		p_bun_jtkkbn[l_rowcntbunpai] := bun_jtkkbn;
		p_bun_chokyukjt[l_rowcntbunpai] := bun_chokyukjt;
		p_bun_chokyuymd[l_rowcntbunpai] := bun_chokyuymd;
		p_bun_financialsecuritieskbn[l_rowcntbunpai] := bun_financialsecuritieskbn;
		p_bun_bankcd[l_rowcntbunpai] := bun_bankcd;
		p_bun_kichubundfbunshi[l_rowcntbunpai] := bun_kichubundfbunshi;

		l_rowcntbunpai := l_rowcntbunpai + 1;

	END LOOP;

	l_rowmaxbunpai := l_rowcntbunpai - 1;
	l_rowcntbunpai := 0;

	CLOSE curRec;

	--手数料分配情報取得エラー
	IF l_rowmaxbunpai < 0 THEN
		result:= 1;
		return;
	END IF;

	-- 総額方式の場合、手数料（税込）をセット
	IF l_szeiprocess = '0' THEN
		l_tesuryogaku := p_zentaitesuryozeikomi;
	-- 従来方式の場合、手数料（税抜）をセット
	ELSIF l_szeiprocess = '1' THEN
		l_tesuryogaku := p_zentaitesuryogaku;
	END IF;


	/* 分かち計算する場合 */
	IF p_wakachi = '1' THEN

		/* 分かち計算のための分配計算実行 */
		rec := pkipakichutesuryo.calcBunpaiTesuryo_Wakachi(
						l_szeiprocess,
						l_initakukaishacd,
						p_bun_bankcd,
						l_tesuryogaku,
						p_zentaitesuryogakuzei,
						l_rowmaxbunpai,
						p_bun_jtkkbn,
						p_bun_kichubundfbunshi,
						p_sstesudfbunbo,
						p_hakkotsukacd,
						p_stcalcymd,
						p_edcalcymd,
						l_tesuryo_mae,
						l_tesuryo_ato,
						l_tesuryozei_mae,
						l_tesuryozei_ato,
						l_kikan_mae,
						l_kikan_ato
		);

		p_bun_tesuryogaku := rec.l_outbuntesuryogaku;
		p_bun_tesuryogakuzei := rec.l_outbuntesuryogakuzei;
		p_jikotesuryogaku := rec.l_outjikotesuryogaku;
		p_jikotesuryogakuzei := rec.l_outjikotesuryogakuzei;
		p_takotesuryogaku := rec.l_outtakotesuryogaku;
		p_takotesuryogakuzei := rec.l_outtakotesuryogakuzei;
		l_return := rec.extra_param;

	/* 分かち計算しない場合 */
	ELSE

		/* 手数料分配情報を元に分配計算実行 */
		rec := pkipakichutesuryo.calcBunpaiTesuryo(
						l_szeiprocess,
						l_initakukaishacd,
						p_bun_bankcd,
						l_tesuryogaku,
						p_zentaitesuryogakuzei,
						l_rowmaxbunpai,
						p_bun_jtkkbn,
						p_bun_kichubundfbunshi,
						p_sstesudfbunbo,
						l_ShzKijunYmd,
						p_hakkotsukacd,
						l_szeiseikyukbn
		);

		p_bun_tesuryogaku := rec.l_outbuntesuryogaku;
		p_bun_tesuryogakuzei := rec.l_outbuntesuryogakuzei;
		p_jikotesuryogaku := rec.l_outjikotesuryogaku;
		p_jikotesuryogakuzei := rec.l_outjikotesuryogakuzei;
		p_takotesuryogaku := rec.l_outtakotesuryogaku;
		p_takotesuryogakuzei := rec.l_outtakotesuryogakuzei;
		l_return := rec.extra_param;

	END IF;

	IF l_return <> pkConstant.SUCCESS() THEN
		result := pkConstant.FATAL();
		return;
	END IF;

	l_outOwnTesuKngk := p_jikotesuryogaku;    -- 自行手数料額（税抜）
	l_outOwnTesuSzei := p_jikotesuryogakuzei; -- 自行消費税額

END LOOP;

CLOSE curTesuRec;

CALL PKLOG.debug('batch', 'PKIPAKICHUTESURYO', '-----------PKIPAKICHUTESURYO.UPDATEKICHUTESURYO   END --------');
-- 正常戻り値
result := pkConstant.SUCCESS();
return;

EXCEPTION
	WHEN OTHERS THEN
		CALL PKLOG.ERROR('ECM701','PKIPAKICHUTESURYO', SQLSTATE);
		CALL PKLOG.ERROR('ECM701','PKIPAKICHUTESURYO',SQLERRM);
		result := pkConstant.FATAL();
		return;

END $$ LANGUAGE PLPGSQL;

/**
*
* @author 山下　健太
* @author 西村　瞳
* @version $Revision: 1.64 $
*
* 手数料計算結果テーブル作成<br>
* パラメータで指定した銘柄情報を抽出し、取得レコードを編集した結果を
* 手数料計算結果テーブルに更新する
*
* @param  l_initakukaishacd	委託会社
* @param  l_inmgrcd			銘柄コード
* @param  l_intesucd			手数料種類コード
* @param  l_indate			徴求日
* @param  l_injobkbn			作成区分
* @return l_return				正常終了/以上終了
*/
CREATE OR REPLACE FUNCTION pkipakichutesuryo.updateKichuTesuryoTbl(
									l_initakukaishacd IN VARCHAR,
									l_inmgrcd IN VARCHAR,
									l_intesucd IN VARCHAR,
									l_indate IN VARCHAR,
									l_injobkbn IN CHAR
) RETURNS NUMERIC AS $$
DECLARE
	/*==============================================================================*/
	/*                  定数定義                                                    */
	/*==============================================================================*/

	/*==============================================================================*/
	/*					変数定義													*/
	/*==============================================================================*/
	l_return					NUMERIC;
	-- SQL編集
	l_strSql VARCHAR(10000)		DEFAULT NULL;

	l_rowcnt					NUMERIC	DEFAULT 0;

	l_rowmaxbunpai				NUMERIC	DEFAULT 0;
	l_rowcntbunpai				NUMERIC	DEFAULT 0;

	l_szeiseikyukbn				CHAR(1)	DEFAULT '0'; -- 消費税請求区分　0=請求しない 1=請求する
	l_ebymd								CHAR(8)	DEFAULT ' '; -- 手数料計算結果テーブルに登録済みのEB作成年月日
	l_ebflg								CHAR(1)	DEFAULT ' '; -- 自行・委託会社ビュー の EB送信FLG
	l_szeiprocess				MPROCESS_CTL.CTL_VALUE%type; -- 消費税算出方式（総額：0　従来：1）
	l_tesuryogaku				NUMERIC	DEFAULT	0;	--	手数料額（総額方式：税込、従来方式：税抜）

	l_option_flg				MOPTION_KANRI.OPTION_FLG%TYPE;				--オプションフラグ
	l_BankCd					MGR_JUTAKUGINKO.BANK_CD%TYPE;				--金融機関コード
	l_BankRnm					MBANK.BANK_RNM%TYPE;						--金融機関略称
	l_HanteiFlg     			TESURYO_SOUJU_HANTEI.SOUJU_HANTEI_FLG%TYPE;	--総額従来判定フラグ



	l_heizonseikyukbn			CHAR(1) DEFAULT 0;
	l_jissu						NUMERIC(2) DEFAULT 3;
	l_hasuFlg					CHAR(1) DEFAULT '0'; -- 端数判定フラグ（端数なし：0　端数あり：1）

	l_ShzKijunYmd				VARCHAR(8);						-- 消費税率適用基準日

	-- 分配手数料の分かち計算で使用するため追加
	l_tesuryo_mae      NUMERIC DEFAULT 0;     -- 改定前の手数料(税込)
	l_tesuryo_ato      NUMERIC DEFAULT 0;	 -- 改定後の手数料(税込)
	l_tesuryozei_mae   NUMERIC DEFAULT 0;	 -- 改定前の消費税
	l_tesuryozei_ato   NUMERIC DEFAULT 0;	 -- 改定後の消費税
	l_kikan_mae        NUMERIC DEFAULT 0;     -- 改定前の期間
	l_kikan_ato        NUMERIC DEFAULT 0;     -- 改定後の期間

	-- カーソル
	curRec						REFCURSOR;
	curTesuRec					REFCURSOR;

	/*	取得データ格納用変数リスト	*/
	p_itakukaishacd			CHAR(4);										--	委託会社コード
	p_mgrcd					VARCHAR(13);									--	銘柄コード
	p_jtkkbn				CHAR(1);										--	受託区分
	p_tesushuruicd			CHAR(2);										--	手数料種類コード
	p_hakkotsukacd			CHAR(3);										--	発行通貨コード
	p_chokyukjt				CHAR(8);										--	徴求期日
	p_chokyuymd				CHAR(8);										--	徴求日
	p_distriymd				CHAR(8);										--	分配日
	p_hakkoymd				CHAR(8);										--	発行年月日
	p_fullshokanymd			CHAR(8);										--	満期償還日
	p_ebmakeymd				CHAR(8);										--	EB作成年月日	--	徴求日-EB作成日営業日前
	p_ebsendymd				CHAR(8);										--	EB送信年月日	--	徴求日-EB送信日営業日前
	p_nyukinymd				CHAR(8);										--	入金日
	p_tesusashihikikbn		CHAR(1);										--	手数料差引区分
	p_eigyotencd			CHAR(4);										--	営業店コード
	p_kozafurikbn			CHAR(2);										--	口座振替区分
	p_kozatencd				CHAR(4);										--	口座店コード
	p_firstlastkichukbn		CHAR(1);										--	初期・終期・期中区分
	p_calcpatterncd			MGR_TESKIJ.CALC_PATTERN_CD%TYPE;				--	計算パターンコード
	p_ssteigakutesukngk		NUMERIC;											--	信託報酬・社管手数料定額手数料
	p_stcalcymd				CHAR(8);										--	計算開始日
	p_edcalcymd				CHAR(8);										--	計算終了日
	p_zndkkijunymd			CHAR(8);										--	残高基準日
	p_billoutymd			CHAR(8);										--	請求書出力日
	p_sstesubunbo			NUMERIC;											--	信託報酬・社債管理手数料率（分母）
	p_sstesubunshi			NUMERIC;											--	信託報酬・社債管理手数料率（分子）
	p_sstesudfbunbo			NUMERIC;											--	信託報酬・社債管理手数料分配率（分母）
	p_ssnenchokyucnt		NUMERIC;											--	信託報酬・社管手数料年徴求回数
	p_datasakuseikbn		TESURYO.DATA_SAKUSEI_KBN%TYPE;					--	データ作成区分
	p_calcpatterncd2		MGR_TESURYO_PRM.CALC_PATTERN_CD%TYPE;			--	計算パターンコード(MG8)
	p_zndkkakuteikbn		MGR_TESURYO_PRM.ZNDK_KAKUTEI_KBN%TYPE;			--	残高確定区分
	p_zengokbn				MGR_TESURYO_PRM.ZENGO_KBN%TYPE;					--	前取後取区分
	p_daymonthkbn			MGR_TESURYO_PRM.DAY_MONTH_KBN%TYPE;				--	日割月割区分
	p_hasunissucalckbn		MGR_TESURYO_PRM.HASU_NISSU_CALC_KBN%TYPE;		--	端数日数計算区分（端数期間分母日数計算区分）
	p_calcymdkbn			MGR_TESURYO_PRM.CALC_YMD_KBN%TYPE;				--	計算期間区分
	p_sscalcymd2			MGR_TESURYO_PRM.SS_CALC_YMD2%TYPE;				--	信託報酬・社管手数料_計算期間２
	p_matsuFlg				MGR_TESURYO_PRM.SS_CALC_YMD2_GMATSU_FLG%TYPE;	--	信託報酬・社管手数料_計算期間月末フラグ２

	p_outoudd				numeric	DEFAULT	0	;							--	応答日
	p_ssteigakutesukngkzei	numeric	DEFAULT	0	;							--	信託報酬・社管手数料定額手数料（税込）
	p_kjnzndk				numeric	DEFAULT	0	;							--	基準残高
	p_kikananbun			numeric	DEFAULT	0	;							--	期間按分
	p_zentaitesuryozeikomi	numeric	DEFAULT	0	;							--	全体手数料額（税込）
	p_zentaitesuryogaku		numeric	DEFAULT	0	;							--	全体手数料額（税抜）
	p_zentaitesuryogakuzei	numeric	DEFAULT	0	;							--	全体手数料額
	p_jikotesuryogaku		numeric	DEFAULT	0	;							--	自行手数料額（税抜）
	p_jikotesuryogakuzei	numeric	DEFAULT	0	;							--	自行手数料額
	p_takotesuryogaku		numeric	DEFAULT	0	;							--	他行手数料額（税抜）
	p_takotesuryogakuzei	numeric	DEFAULT	0	;							--	他行手数料額
	p_hasutsuki				CHAR(6)	DEFAULT	'	';							--	端数月
	p_hankanenoutkbn		CHAR(1)	DEFAULT	'	';							--	半か年外出し区分
	p_tsukiwarifrom			CHAR(8)	DEFAULT	'	';							--	月割期間From
	p_tsukiwarito			CHAR(8)	DEFAULT	'	';							--	月割期間To
	p_tsukisu				numeric	DEFAULT	0	;							--	月数
	p_hiwarifrom			CHAR(8)	DEFAULT	'	';							--	日割期間From
	p_hiwarito				CHAR(8)	DEFAULT	'	';							--	日割期間To
	p_nissu					numeric	DEFAULT	0	;							--	日数
	p_keisanbibunbo			numeric	DEFAULT	0;								--	計算式日（分母）
	p_keisanbibunshi		numeric	DEFAULT	0;								--	計算式日（分子）

	p_hiwaribunbofrom		CHAR(8)	;										--	分母期間From
	p_hiwaribunboto			CHAR(8)	;										--	分母期間To

	 p_wakachi					CHAR(1) DEFAULT ' ';						-- 分かち計算する(1)・しない(0)
	 p_tsukisu_mae    				numeric	DEFAULT 0;						-- 改定前の月数
	 p_tsukisu_ato    				numeric	DEFAULT 0;						-- 改定後の月数
	 p_tekiyost_ymd					CHAR(8)	DEFAULT	'	';					-- 消費税適用日

	 p_keisanyymmdd					pkipakichutesuryo.CHR_ARRAY;			--計算期間（年月日）※計算開始日〜終了日を月別に分解し、月の先頭日を設定する

	 p_shohizei_sai					CHAR(1) DEFAULT ' ';						-- 消費税の差異あり(0)・なし(1)

	p_bun_itakukaishacd				pkipakichutesuryo.CH4_ARRAY;	--	委託会社コード
	p_bun_mgrcd						pkipakichutesuryo.VCR_ARRAY;	--	銘柄コード
	p_bun_groupid					pkipakichutesuryo.CH3_ARRAY;	--	グループID
	p_bun_tesushuruicd				pkipakichutesuryo.CH2_ARRAY;	--	手数料種類コード
	p_bun_jtkkbn					pkipakichutesuryo.CH1_ARRAY;	--	受託区分
	p_bun_chokyukjt					pkipakichutesuryo.CHR_ARRAY;	--	徴求期日
	p_bun_chokyuymd					pkipakichutesuryo.CHR_ARRAY;	--	徴求日
	p_bun_financialsecuritieskbn	pkipakichutesuryo.CH1_ARRAY;	--	金融証券区分
	p_bun_bankcd					pkipakichutesuryo.CH4_ARRAY;	--	金融機関コード
	p_bun_kichubundfbunshi			pkipakichutesuryo.NUM_ARRAY;	--	分配率(分子)

	bun_itakukaishacd				char(4);
	bun_mgrcd						varchar(20);
	bun_groupid						char(3);
	bun_tesushuruicd				char(2);
	bun_jtkkbn						char(1);
	bun_chokyukjt					char(8);
	bun_chokyuymd					char(8);
	bun_financialsecuritieskbn		char(1);
	bun_bankcd						char(4);
	bun_kichubundfbunshi			numeric;

	p_keisanyydd					pkipakichutesuryo.CH6_ARRAY;
	p_tsukizndk						pkipakichutesuryo.NUM_ARRAY;
	p_tsukitesuryo					pkipakichutesuryo.NUM_ARRAY;

	p_bun_tesuryogaku				pkipakichutesuryo.NUM_ARRAY;	--	分配手数料額（税抜）
	p_bun_tesuryogakuzei			pkipakichutesuryo.NUM_ARRAY;	--	分配手数料額

	rec								record;

BEGIN

		CALL PKLOG.debug('batch', 'PKIPAKICHUTESURYO', '-------------------PKIPAKICHUTESURYO.UPDATEKICHUTESURYO START------------------');

		/* 特例社債でかつ徴求日が償還日(振替移行時)より小さい場合は正常終了で処理を抜ける */
		IF pkipakichutesuryo.isUpdate(l_initakukaishacd,l_inmgrcd,l_indate) = 1 THEN
			RETURN pkConstant.SUCCESS();
		END IF;

		/* データ取得 */
		l_strSql := pkipakichutesuryo.createGetDataSql(l_initakukaishacd,l_inmgrcd,l_intesucd,l_indate,0);

		OPEN curTesuRec FOR EXECUTE l_strSql;
		LOOP
			FETCH curTesuRec INTO
				p_itakukaishacd,				-- 委託会社コード
				p_mgrcd,						-- 銘柄コード
				p_jtkkbn,						-- 受託区分
				p_tesushuruicd,					-- 手数料種類コード
				p_hakkotsukacd,					-- 発行通貨コード
				p_chokyukjt,					-- 徴求期日
				p_chokyuymd,					-- 徴求日
				p_distriymd,					-- 分配日
				p_hakkoymd,						-- 発行年月日
				p_fullshokanymd,				-- 満期償還日
				p_ebmakeymd,					-- EB作成年月日  -- 徴求日-EB作成日営業日前
				p_ebsendymd,					-- EB送信年月日  -- 徴求日-EB送信日営業日前
				p_nyukinymd,					-- 入金日
				p_tesusashihikikbn,				-- 手数料差引区分
				p_eigyotencd,					-- 営業店コード
				p_kozafurikbn,					-- 口座振替区分
				p_kozatencd,					-- 口座店コード
				p_firstlastkichukbn,			-- 初期・期中・終期区分
				p_calcpatterncd,				-- 計算パターンコード
				p_ssteigakutesukngk,			-- 信託報酬・社管手数料定額手数料
				p_stcalcymd,					-- 計算開始日
				p_edcalcymd,					-- 計算終了日
				p_zndkkijunymd,					-- 残高基準日
				p_billoutymd,					-- 請求書出力日
				p_sstesubunbo,					-- 信託報酬・社債管理手数料率（分母）
				p_sstesubunshi,					-- 信託報酬・社債管理手数料率（分子）
				p_sstesudfbunbo,				-- 信託報酬・社債管理手数料分配率（分母）
				p_ssnenchokyucnt,				-- 信託報酬・社管手数料年徴求回数
				p_datasakuseikbn,				-- データ作成区分
				p_calcpatterncd2,				-- 計算パターンコード
				p_zndkkakuteikbn,				-- 残高確定区分
				p_zengokbn,						-- 前取後取区分
				p_daymonthkbn,					-- 端数日数日割月割区分
				p_hasunissucalckbn,				-- 端数日数計算区分
				p_calcymdkbn,					-- 計算期間区分
				p_sscalcymd2,					-- 信託報酬・社管手数料_計算期間２
				p_matsuFlg,						-- 信託報酬・社管手数料_計算期間月末フラグ２

				l_szeiseikyukbn,				-- 消費税請求区分
				l_ebymd,						-- 手数料計算結果テーブルのEB作成年月日
				l_ebflg,						-- EB作成フラグ
				l_heizonseikyukbn;				-- 並存請求区分
				EXIT WHEN NOT FOUND;

			--これから登録しようとするデータの存在チェック
			/* 引数のデータ作成区分＜T01.データ作成区分　の場合は正常終了で処理を抜ける */
			IF l_injobkbn::numeric < p_datasakuseikbn::numeric THEN
				RETURN pkConstant.SUCCESS();
			END IF;

			/* EBデータ作成年月日が初期値ではない　場合は正常終了で処理を抜ける */
			IF ENCODE(SUBSTR(l_ebymd::bytea,1,1), 'escape') <> ' ' THEN
				RETURN pkConstant.SUCCESS();
			END IF;

			/* 自行委託会社ビュー.EB作成フラグ が 作成する の場合以外は、EB作成・送信年月日に初期値をセット */
			IF l_ebflg <> '1' THEN
				 p_ebsendymd := ' ';			-- EB送信年月日
			END IF;

			-- 半か年区分のデフォルト（2=外出しなし）
			p_hankanenoutkbn := '2';

			-- 更新処理の前に既存の手数料計算結果データをDelete
			--T01
			IF PKIPACALCTESURYO.DELETETESURYO(l_initakukaishaCd,l_inmgrcd,l_intesucd,p_chokyukjt) <> pkConstant.SUCCESS() THEN

				RETURN pkConstant.FATAL();
			END IF;
			--T02
			IF PKIPACALCTESURYO.DELETETESURYOBUNPAI(l_initakukaishaCd,l_inmgrcd,l_intesucd,p_chokyukjt) <> pkConstant.SUCCESS() THEN

				RETURN pkConstant.FATAL();
			END IF;
			--T03
			DELETE FROM TESURYO_KICHU
				WHERE
					ITAKU_KAISHA_CD = l_initakukaishacd
				AND MGR_CD 				= l_inmgrcd
				AND	TESU_SHURUI_CD 	= l_intesucd
				AND	CHOKYU_KJT		  = p_chokyukjt;

				-- オプション管理マスタより、処理制御値を取得する。
			l_option_flg := pkControl.getOPTION_FLG(l_initakukaishaCd, 'REDPROJECT', '0');

			IF l_option_flg = '1' AND p_jtkkbn = '2' THEN
				--オプションフラグ＝’1’:あり　かつ　受託区分＝’２’（副受託）の場合
				select * into
					l_BankCd,				--金融機関コード
					l_BankRnm,				--金融機関略称
					l_return
				from pkIpaKichuTesuryo.getMbank_Cd_Rnm(
					l_initakukaishacd,	--委託会社コード
					l_inmgrcd				--銘柄コード
				);

				IF l_return <> pkConstant.SUCCESS() THEN
					RETURN pkConstant.FATAL();
				END IF;

				select * into
					l_HanteiFlg,			--総額従来判定フラグ
					l_return
				from pkIpaKichuTesuryo.getSouju_Hantei_Flg(
					l_initakukaishacd,	--委託会社コード
					l_BankCd			--金融機関コード
				);
				IF l_return = pkConstant.FATAL() THEN
					RETURN pkConstant.FATAL();
				END IF;

				IF l_return = pkConstant.ERROR() THEN
					--手数料従来方式テーブルには金融機関コードが存在しません。
					CALL PKLOG.ERROR('ECM701','PKIPAKICHUTESURYO',l_BankRnm || 'の消費税算出方式が登録されていません。システム管理部署に追加の依頼をしてください。');
					RETURN pkConstant.FATAL();
				END IF;

				l_szeiprocess := l_HanteiFlg;

			ELSE

				-- MPROCESS_CTLテーブルより、総額・従来判定フラグを取得する
				l_szeiprocess := pkControl.getCtlValue(l_initakukaishaCd, 'CALCTESUKNGK0', '0');

			END IF;

			/* -----取得データから値を計算および編集----- */
			/* 応答日 */
			IF p_ssnenchokyucnt = 0 THEN
				p_ssnenchokyucnt := 1;
			END IF;
			p_outoudd := 12 / oracle.TO_NUMBER(p_ssnenchokyucnt);

			/* 基準残高取得 */
			--手数料計算の為の基準残高を取得する。(定額方式（4）以外の場合）
			-- 並存銘柄請求書出力区分が'1'の場合は、'3'ではなく'93'を渡す
			IF l_heizonseikyukbn = '1' THEN
				l_jissu := 93; -- 振替債+現登債…93
			ELSE l_jissu := 3; -- 実質残高…3
			END IF;

			l_return :=	pkipakichutesuryo.getZndk(l_initakukaishacd,
							l_inmgrcd,
							p_zndkkijunymd,
							p_stcalcymd,
							p_edcalcymd,
							p_hakkoymd,
							p_fullshokanymd,
							p_calcpatterncd,
							p_zndkkakuteikbn,
							l_jissu,
							p_kjnzndk,
							p_keisanyydd,
							p_tsukizndk);

			IF l_return <> pkConstant.SUCCESS() THEN
				RETURN pkConstant.FATAL();
			END IF;

			-- 月割・日割期間From−Toの初期化
			p_tsukiwarifrom := ' ';
			p_tsukiwarito   := ' ';
			p_hiwarifrom    := ' ';
			p_hiwarito      := ' ';
			p_tsukisu       :=  0 ;
			p_hasutsuki     := ' ';

			--端数判定フラグの初期化
			l_hasuFlg := '0';

			/* 月数、月割部分From-To、端数月 */
			--端数期間日割月割区分＝「月割日割」（1）、「月割」（3）、「日割（端数期間のみ）」（4）、（月割（端数期間切捨）(5)の場合のみ取得
			IF p_daymonthkbn IN('1','3','4','5') THEN
				select * into
					p_tsukiwarifrom,
					p_tsukiwarito,
					p_tsukisu,
					p_hasutsuki,
					l_return
				from pkipakichutesuryo.getMonthFromTo(
					p_stcalcymd,
					p_edcalcymd,
					p_daymonthkbn,
					p_calcymdkbn,
					p_matsuFlg,		-- 計算期間月末フラグ２
					p_firstlastkichukbn,
					p_outoudd,
					p_sscalcymd2
				);

				IF l_return <> pkConstant.SUCCESS() THEN
					RETURN pkConstant.FATAL();
				END IF;

				--端数期間日割月割区分＝「日割（端数期間のみ）」（4）の場合、端数判定を行う
				IF p_daymonthkbn = '4' THEN
					--端数判定
					IF TRIM(p_hasutsuki) IS NULL THEN
						IF p_outoudd != p_tsukisu THEN
							--端数月が設定されていないかつ月数!=12/年徴求回数の場合は「端数あり」
							l_hasuFlg := '1';
						END IF;
					ELSE
						--端数月が設定されている場合は「端数あり」
						l_hasuFlg := '1';
					END IF;
				END IF;

				--「端数あり」の場合、月割・日割期間From−Toの初期化を初期化
				IF l_hasuFlg = '1' THEN
					p_tsukiwarifrom := ' ';
					p_tsukiwarito   := ' ';
					p_hiwarifrom    := ' ';
					p_hiwarito      := ' ';
					p_tsukisu       :=  0 ;
					p_hasutsuki     := ' ';
				END IF;

			END IF;

			-- 端数期間日割月割区分＝「月割日割」（1）、「日割」（2）、
			--「日割（端数期間のみ）」（4）かつ「端数あり」の場合のみ
			-- 日数取得 と 期間按分取得 を行う
			-- 変数初期化
			p_hiwarifrom      := ' ';			-- 分子期間From
			p_hiwarito        := ' ';			-- 分子期間To
			p_nissu           := 0;				-- 日数
			p_hankanenoutkbn  := '2';			-- 半か年区分
			p_keisanbibunshi  := 0;				-- 期間按分分子
			p_hiwaribunbofrom := ' ';			-- 分母期間From
			p_hiwaribunboto   := ' ';			-- 分母期間To
			p_keisanbibunbo   := 0;				-- 期間按分分母
			p_kikananbun      := 0;				-- 期間按分

			IF p_daymonthkbn IN('1','2') OR (p_daymonthkbn = '4' AND l_hasuFlg = '1') THEN

				/* 日割部分From-To、日数 */
				select * into
								p_hiwarifrom,
								p_hiwarito,
								p_nissu,
								p_hankanenoutkbn,
								l_return
				from pkipakichutesuryo.getDateFromTo(p_stcalcymd,
								p_edcalcymd,
								p_daymonthkbn,
								p_calcymdkbn,
								p_matsuFlg,		-- 計算期間月末フラグ２
								p_tsukiwarifrom,
								p_tsukiwarito,
								p_tsukisu,
								p_hasutsuki,
								p_firstlastkichukbn,
								p_hasunissucalckbn,
								p_outoudd,
								p_sscalcymd2
				);

				IF l_return <> pkConstant.SUCCESS() THEN
					RETURN pkConstant.FATAL();
				END IF;

				/* 期間按分、期間按分分子、期間按分分母、日割部分From-To、半か年外出し区分 取得 */
				select * into
														p_kikananbun,			-- 期間按分
														p_hiwarifrom,			-- 分子期間From
														p_hiwarito,				-- 分子期間To
														p_keisanbibunshi,		-- 期間按分分子
														p_hiwaribunbofrom,		-- 分母期間From
														p_hiwaribunboto,		-- 分母期間To
														p_keisanbibunbo,		-- 期間按分分母
														l_return
				from pkIpaKichuTesuryo.getKikanAnbun(p_hiwarifrom,
														p_hiwarito,
														p_ssnenchokyucnt,
														p_hasunissucalckbn,
														p_matsuFlg,				-- 計算期間月末フラグ２
														p_firstlastkichukbn,
														p_hankanenoutkbn,
														p_sscalcymd2
				);

				IF l_return <> pkConstant.SUCCESS() THEN
					RETURN pkConstant.FATAL();
				END IF;

			END IF;

			/* 手数料計算前の準備 */

			-- 月割期間From-Toが無い場合は月数（月割期間分子）を初期化
			IF TRIM(p_tsukiwarifrom || p_tsukiwarito) IS NULL THEN
				p_tsukisu := 0;
			END IF;

			/******************************/
			/* 分かち計算を行う処理を追加 */
			/******************************/

			/* 月数取得(分かち計算用）を実行する。*/
			p_tsukisu_mae  := 0;
			p_tsukisu_ato  := 0;
			p_wakachi := '0';	--分かち計算しないを設定
			p_shohizei_sai := '0';  -- 消費税の差異　差異あり(初期値:0)を設定

			rec := pkipakichutesuryo.getMonthFromTo_Wakachi(
					l_initakukaishaCd,	--委託会社コード
					p_stcalcymd,	--計算開始日
					p_edcalcymd,	--計算終了日
					p_tsukisu,
					p_firstlastkichukbn,
					l_szeiseikyukbn	-- 消費税を請求する(1)・しない(0)
			);

			p_keisanyymmdd := rec.l_outkeisanyymmdd;
			p_tsukisu_mae := rec.l_outtsukisu_mae;  --改定前の月数
			p_tsukisu_ato := rec.l_outtsukisu_ato;  --改定後の月数
			p_wakachi := rec.l_outwakachi;	--分かち計算する・しない
			p_tekiyost_ymd := rec.l_outtekiyost_ymd; --消費税適用日
			p_shohizei_sai := rec.l_outshohizei_sai; --消費税率の差異あり・なし ※差異なし=1 差異あり=0
			l_return := rec.extra_param;

			IF l_return <> pkConstant.SUCCESS() THEN
				RETURN pkConstant.FATAL();
			END IF;

			/* 分かち計算する場合 */
			IF p_wakachi = '1' THEN

				/* 手数料計算(分かち計算用）を実行する。*/
				rec := pkipakichutesuryo.calcTesuryo_Wakachi(
								 l_szeiprocess,
								 p_stcalcymd,
								 p_tsukiwarifrom,
								 p_hiwarifrom,
								 p_calcpatterncd,
								 p_tsukisu,
								 p_kjnzndk,
								 p_ssteigakutesukngk,
								 p_sstesubunshi,
								 p_sstesubunbo,
								 p_chokyuymd,
								 p_hakkotsukacd,
								 p_keisanyydd,
								 p_tsukizndk,
								 p_keisanbibunshi,
								 p_keisanbibunbo,
								 p_hasunissucalckbn,
								 p_ssnenchokyucnt,
								 p_edcalcymd,   --計算終了日
								 p_tsukisu_mae, --改定前の月数
								 p_tsukisu_ato, --改定後の月数
								 p_tekiyost_ymd, --改定後の消費税適用日
								 p_keisanyymmdd  -- 計算期間（年月日）※月別に設定
				);

				p_zentaitesuryozeikomi := rec.l_outtesuryo; --全体手数料額(税込)
				p_zentaitesuryogakuzei := rec.l_outtesuryozei; --消費税額
				p_zentaitesuryogaku := rec.l_outtesuryonuki;	 --手数料額(税抜)
				p_tsukitesuryo := rec.l_outtsukitesuryo; --月毎手数料1〜13
				l_tesuryo_mae := rec.l_outtesuryo_mae;	-- 改定前の手数料(税込)
				l_tesuryo_ato := rec.l_outtesuryo_ato;	-- 改定後の手数料(税込)
				l_tesuryozei_mae := rec.l_outtesuryozei_mae; -- 改定前の消費税
				l_tesuryozei_ato := rec.l_outtesuryozei_ato; -- 改定後の消費税
				l_kikan_mae := rec.l_outkikan_mae;      -- 改定前の期間
				l_kikan_ato := rec.l_outkikan_ato;       -- 改定後の期間
				l_return := rec.extra_param;

			ELSE

				-- 発行時一括の場合
				IF TRIM(p_calcpatterncd) IS NULL THEN
					-- 発行日を取得する
					l_ShzKijunYmd := pkIpacalctesuryo.getHakkoYmd(p_itakukaishacd,p_mgrcd);

				ELSE

					-- 分かち計算ありで消費税の差異がない場合
					IF p_shohizei_sai = '1' THEN

						-- 基準日に計算開始日を設定
						l_ShzKijunYmd := p_stcalcymd;

					-- 分かち計算なし場合
					ELSE
						-- 基準日に徴求日を設定
						l_ShzKijunYmd := p_chokyuymd;

					END IF;

				END IF;

				/* 期中手数料・月毎期中手数料(1〜13)を計算する */
				rec := pkipakichutesuryo.calcTesuryo(
								 l_szeiprocess,
								 p_stcalcymd,
								 p_tsukiwarifrom,
								 p_hiwarifrom,
								 p_calcpatterncd,
								 p_tsukisu,
								 p_kjnzndk,
								 p_ssteigakutesukngk,
								 p_sstesubunshi,
								 p_sstesubunbo,
								 l_ShzKijunYmd,
								 p_hakkotsukacd,
								 l_szeiseikyukbn,
								 p_keisanyydd,
								 p_tsukizndk,
								 p_keisanbibunshi,
								 p_keisanbibunbo,
								 p_hasunissucalckbn,
								 p_ssnenchokyucnt
				);

				p_zentaitesuryozeikomi := rec.l_outtesuryo;		--手数料額(税込)
				p_zentaitesuryogakuzei := rec.l_outtesuryozei;		--消費税額
				p_zentaitesuryogaku := rec.l_outtesuryonuki;			--手数料額(税抜)
				p_tsukitesuryo := rec.l_outtsukitesuryo;
				l_return := rec.extra_param;

			END IF;


			IF l_return <> pkConstant.SUCCESS() THEN
				RETURN pkConstant.FATAL();
			END IF;

			/* 分配情報を取得 */
			l_strSql := pkipakichutesuryo.createGetBunpaiDataSql(l_initakukaishacd,l_inmgrcd ,p_chokyukjt ,l_intesucd ,l_indate);

			OPEN curRec FOR EXECUTE l_strSql;

			LOOP

				FETCH curRec INTO
					bun_itakukaishacd,
					bun_mgrcd,
					bun_groupid,
					bun_tesushuruicd,
					bun_jtkkbn,
					bun_chokyukjt,
					bun_chokyuymd,
					bun_financialsecuritieskbn,
					bun_bankcd,
					bun_kichubundfbunshi;

				EXIT WHEN NOT FOUND;

				p_bun_itakukaishacd[l_rowcntbunpai] := bun_itakukaishacd;
				p_bun_mgrcd[l_rowcntbunpai] := bun_mgrcd;
				p_bun_groupid[l_rowcntbunpai] := bun_groupid;
				p_bun_tesushuruicd[l_rowcntbunpai] := bun_tesushuruicd;
				p_bun_jtkkbn[l_rowcntbunpai] := bun_jtkkbn;
				p_bun_chokyukjt[l_rowcntbunpai] := bun_chokyukjt;
				p_bun_chokyuymd[l_rowcntbunpai] := bun_chokyuymd;
				p_bun_financialsecuritieskbn[l_rowcntbunpai] := bun_financialsecuritieskbn;
				p_bun_bankcd[l_rowcntbunpai] := bun_bankcd;
				p_bun_kichubundfbunshi[l_rowcntbunpai] := bun_kichubundfbunshi;

				l_rowcntbunpai := l_rowcntbunpai + 1;

			END LOOP;


			l_rowmaxbunpai := l_rowcntbunpai - 1;
			l_rowcntbunpai := 0;

			CLOSE curRec;

			--手数料分配情報取得エラー
			IF l_rowmaxbunpai < 0 THEN
				RETURN 1;
			END IF;

			-- 総額方式の場合、手数料（税込）をセット
			IF l_szeiprocess = '0' THEN
				l_tesuryogaku := p_zentaitesuryozeikomi;
			-- 従来方式の場合、手数料（税抜）をセット
			ELSIF l_szeiprocess = '1' THEN
				l_tesuryogaku := p_zentaitesuryogaku;
			END IF;


			/* 分かち計算する場合 */
			IF p_wakachi = '1' THEN

				/* 分かち計算のための分配計算実行 */
				rec := pkipakichutesuryo.calcBunpaiTesuryo_Wakachi
							(l_szeiprocess,
							 l_initakukaishacd,
							 p_bun_bankcd,
							 l_tesuryogaku,
							 p_zentaitesuryogakuzei,
							 l_rowmaxbunpai,
							 p_bun_jtkkbn,
							 p_bun_kichubundfbunshi,
							 p_sstesudfbunbo,
							 p_hakkotsukacd,
							 p_stcalcymd,
							 p_edcalcymd,
							 l_tesuryo_mae,
							 l_tesuryo_ato,
							 l_tesuryozei_mae,
							 l_tesuryozei_ato,
							 l_kikan_mae,
							 l_kikan_ato
				);


				p_bun_tesuryogaku := rec.l_outbuntesuryogaku;
				p_bun_tesuryogakuzei := rec.l_outbuntesuryogakuzei;
				p_jikotesuryogaku := rec.l_outjikotesuryogaku;
				p_jikotesuryogakuzei := rec.l_outjikotesuryogakuzei;
				p_takotesuryogaku := rec.l_outtakotesuryogaku;
				p_takotesuryogakuzei := rec.l_outtakotesuryogakuzei;
				l_return := rec.extra_param;

			/* 分かち計算しない場合 */
			ELSE

				/* 手数料分配情報を元に分配計算実行 */
				rec := pkipakichutesuryo.calcBunpaiTesuryo(
							 l_szeiprocess,
							 l_initakukaishacd,
							 p_bun_bankcd,
							 l_tesuryogaku,
							 p_zentaitesuryogakuzei,
							 l_rowmaxbunpai,
							 p_bun_jtkkbn,
							 p_bun_kichubundfbunshi,
							 p_sstesudfbunbo,
							 l_ShzKijunYmd,
							 p_hakkotsukacd,
							 l_szeiseikyukbn
				);

				p_bun_tesuryogaku := rec.l_outbuntesuryogaku;
				p_bun_tesuryogakuzei := rec.l_outbuntesuryogakuzei;
				p_jikotesuryogaku := rec.l_outjikotesuryogaku;
				p_jikotesuryogakuzei := rec.l_outjikotesuryogakuzei;
				p_takotesuryogaku := rec.l_outtakotesuryogaku;
				p_takotesuryogakuzei := rec.l_outtakotesuryogakuzei;
				l_return := rec.extra_param;

			END IF;

			IF l_return <> pkConstant.SUCCESS() THEN
				RETURN pkConstant.FATAL();
			END IF;

			/* 手数料計算結果テーブルに更新 */
			l_strSql :=				'INSERT INTO TESURYO(';
			l_strSql := l_strSql || ' ITAKU_KAISHA_CD      ,';	-- 委託会社コード
			l_strSql := l_strSql || ' MGR_CD               ,';	-- 銘柄コード
			l_strSql := l_strSql || ' TESU_SHURUI_CD       ,';	-- 手数料種類コード
			l_strSql := l_strSql || ' JTK_KBN              ,';	-- 受託区分
			l_strSql := l_strSql || ' TSUKA_CD             ,';	-- 通貨コード
			l_strSql := l_strSql || ' CHOKYU_KJT           ,';	-- 徴求期日
			l_strSql := l_strSql || ' CHOKYU_YMD           ,';	-- 徴求日
			l_strSql := l_strSql || ' DISTRI_YMD           ,';	-- 分配日
			l_strSql := l_strSql || ' EB_SEND_YMD          ,';	-- ＥＢ送信年月日
			l_strSql := l_strSql || ' NYUKIN_YMD           ,';	-- 入金日
			l_strSql := l_strSql || ' TESU_SASHIHIKI_KBN   ,';	-- 手数料差引区分
			l_strSql := l_strSql || ' EIGYOTEN_CD          ,';	-- 営業店コード
			l_strSql := l_strSql || ' KOZA_FURI_KBN        ,';	-- 口座振替区分
			l_strSql := l_strSql || ' KOZA_TEN_CD          ,';	-- 口座店コード
			l_strSql := l_strSql || ' KIJUN_ZNDK           ,';	-- 基準残高
			l_strSql := l_strSql || ' TESU_RITSU_BUNBO     ,';	-- 手数料率分母
			l_strSql := l_strSql || ' TESU_RITSU_BUNSHI    ,';	-- 手数料率分子
			l_strSql := l_strSql || ' ALL_TESU_KNGK        ,';	-- 全体手数料額（税抜）
			l_strSql := l_strSql || ' ALL_TESU_SZEI        ,';	-- 全体消費税額
			l_strSql := l_strSql || ' DF_BUNBO             ,';	-- 分配率（分母）
			l_strSql := l_strSql || ' OWN_TESU_KNGK        ,';	-- 自行手数料額（税抜）
			l_strSql := l_strSql || ' OWN_TESU_SZEI        ,';	-- 自行消費税額
			l_strSql := l_strSql || ' OTHER_TESU_KNGK      ,';	-- 他行手数料額（税抜）
			l_strSql := l_strSql || ' OTHER_TESU_SZEI      ,';	-- 他行消費税額
			l_strSql := l_strSql || ' HOSEI_ALL_TESU_KNGK  ,';	-- 補正額_全体手数料額（税抜）
			l_strSql := l_strSql || ' HOSEI_ALL_TESU_SZEI  ,';	-- 補正額_全体消費税額
			l_strSql := l_strSql || ' HOSEI_OWN_TESU_KNGK  ,';	-- 補正額_自行手数料額（税抜）
			l_strSql := l_strSql || ' HOSEI_OWN_TESU_SZEI  ,';	-- 補正額_自行消費税額
			l_strSql := l_strSql || ' HOSEI_OTHER_TESU_KNGK,';	-- 補正額_他行手数料額（税抜）
			l_strSql := l_strSql || ' HOSEI_OTHER_TESU_SZEI,';	-- 補正額_他行消費税額
			l_strSql := l_strSql || ' DATA_SAKUSEI_KBN     ,';	-- データ作成区分
			l_strSql := l_strSql || ' GROUP_ID             ,';	-- グループＩＤ
			l_strSql := l_strSql || ' SHORI_KBN            ,';	-- 処理区分
			l_strSql := l_strSql || ' LAST_TEISEI_ID       ,';	-- 最終訂正者
			l_strSql := l_strSql || ' SHONIN_ID            ,';	-- 承認者
			l_strSql := l_strSql || ' KOUSIN_ID            ,';	-- 更新者
			l_strSql := l_strSql || ' SAKUSEI_ID            ';	-- 作成者

			l_strSql := l_strSql || ' )VALUES(';

			l_strSql := l_strSql || '''' || p_itakukaishacd        || ''', '; -- 委託会社コード
			l_strSql := l_strSql || '''' || p_mgrcd                || ''', '; -- 銘柄コード
			l_strSql := l_strSql || '''' || p_tesushuruicd         || ''', '; -- 手数料種類コード
			l_strSql := l_strSql || '''' || p_jtkkbn               || ''', '; -- 受託区分
			l_strSql := l_strSql || '''' || p_hakkotsukacd         || ''', '; -- 通貨コード
			l_strSql := l_strSql || '''' || p_chokyukjt            || ''', '; -- 徴求期日
			l_strSql := l_strSql || '''' || p_chokyuymd            || ''', '; -- 徴求日
			l_strSql := l_strSql || '''' || p_distriymd            || ''', '; -- 分配日
			l_strSql := l_strSql || '''' || p_ebsendymd            || ''', '; -- ＥＢ送信年月日
			l_strSql := l_strSql || '''' || p_nyukinymd            || ''', '; -- 入金日
			l_strSql := l_strSql || '''' || p_tesusashihikikbn     || ''', '; -- 手数料差引区分
			l_strSql := l_strSql || '''' || p_eigyotencd           || ''', '; -- 営業店コード
			l_strSql := l_strSql || '''' || p_kozafurikbn          || ''', '; -- 口座振替区分
			l_strSql := l_strSql || '''' || p_kozatencd            || ''', '; -- 口座店コード
			l_strSql := l_strSql || '''' || p_kjnzndk              || ''', '; -- 基準残高
			l_strSql := l_strSql || '''' || p_sstesubunbo          || ''', '; -- 手数料率分母
			l_strSql := l_strSql || '''' || p_sstesubunshi         || ''', '; -- 手数料率分子
			l_strSql := l_strSql || '''' || p_zentaitesuryogaku    || ''', '; -- 全体手数料額（税抜）
			l_strSql := l_strSql || '''' || p_zentaitesuryogakuzei || ''', '; -- 全体消費税額
			l_strSql := l_strSql || '''' || p_sstesudfbunbo        || ''', '; -- 分配率（分母）
			l_strSql := l_strSql || '''' || p_jikotesuryogaku      || ''', '; -- 自行手数料額（税抜）
			l_strSql := l_strSql || '''' || p_jikotesuryogakuzei   || ''', '; -- 自行消費税額
			l_strSql := l_strSql || '''' || p_takotesuryogaku      || ''', '; -- 他行手数料額（税抜）
			l_strSql := l_strSql || '''' || p_takotesuryogakuzei   || ''', '; -- 他行消費税額料率（分母）
			l_strSql := l_strSql || '       0                            , '; -- 補正額_全体手数料額（税抜）
			l_strSql := l_strSql || '       0                            , '; -- 補正額_全体消費税額
			l_strSql := l_strSql || '       0                            , '; -- 補正額_自行手数料額（税抜）
			l_strSql := l_strSql || '       0                            , '; -- 補正額_自行消費税額
			l_strSql := l_strSql || '       0                            , '; -- 補正額_他行手数料額（税抜）
			l_strSql := l_strSql || '       0                            , '; -- 補正額_他行消費税額
			l_strSql := l_strSql || '''' || l_injobkbn             || ''', '; -- データ作成区分
			l_strSql := l_strSql || '     '' ''                          , '; -- グループＩＤ
			l_strSql := l_strSql || '     ''0''                          , '; -- 処理区分
			l_strSql := l_strSql || '     '' ''                          , '; -- 最終訂正者
			l_strSql := l_strSql || '     '' ''                          , '; -- 承認者
			l_strSql := l_strSql || '     '' ''                          , '; -- 更新者
			l_strSql := l_strSql || '''' || pkConstant.BATCH_USER()  || ''') '; -- 作成者('BATCH'をセットする 2005.07.29 yoshisue)

			EXECUTE IMMEDIATE l_strSql;

			/* 手数料計算結果テーブル（期中）に更新 */
			l_strSql :=             'INSERT INTO TESURYO_KICHU(';
			l_strSql := l_strSql || ' ITAKU_KAISHA_CD             ,';	-- 委託会社コード
			l_strSql := l_strSql || ' MGR_CD                      ,';	-- 銘柄コード
			l_strSql := l_strSql || ' TESU_SHURUI_CD              ,';	-- 手数料種類コード
			l_strSql := l_strSql || ' CHOKYU_KJT                  ,';	-- 徴求期日
			l_strSql := l_strSql || ' CHOKYU_YMD                  ,';	-- 徴求日
			l_strSql := l_strSql || ' CALC_F_YMD                  ,';	-- 計算期間（FROM）
			l_strSql := l_strSql || ' CALC_T_YMD                  ,';	-- 計算期間（TO）
			l_strSql := l_strSql || ' CALC_MM_BUNBO               ,';	-- 計算式月（分母）
			l_strSql := l_strSql || ' CALC_MM_BUNSHI              ,';	-- 計算式月（分子）
			l_strSql := l_strSql || ' CALC_DD_BUNBO               ,';	-- 計算式日（分母）
			l_strSql := l_strSql || ' CALC_DD_BUNSHI              ,';	-- 計算式日（分子）
			l_strSql := l_strSql || ' FASTLASTKICHU_KBN           ,';	-- 初期・終期・期中区分
			l_strSql := l_strSql || ' CALC_PATTERN_CD             ,';	-- 計算パターン
			l_strSql := l_strSql || ' HANKANEN_OUT_KBN            ,';	-- 半か年外出し区分
			l_strSql := l_strSql || ' MSPAN_FROM                  ,';	-- 月割期間From
			l_strSql := l_strSql || ' MSPAN_TO                    ,';	-- 月割期間To
			l_strSql := l_strSql || ' DSPAN_FROM                  ,';	-- 日割期間From
			l_strSql := l_strSql || ' DSPAN_TO                    ,';	-- 日割期間To
			l_strSql := l_strSql || ' HASU_YM                     ,';	-- 端数月
			l_strSql := l_strSql || ' CALC_YM1                    ,';	-- 計算年月１
			l_strSql := l_strSql || ' CALC_YM2                    ,';	-- 計算年月２
			l_strSql := l_strSql || ' CALC_YM3                    ,';	-- 計算年月３
			l_strSql := l_strSql || ' CALC_YM4                    ,';	-- 計算年月４
			l_strSql := l_strSql || ' CALC_YM5                    ,';	-- 計算年月５
			l_strSql := l_strSql || ' CALC_YM6                    ,';	-- 計算年月６
			l_strSql := l_strSql || ' CALC_YM7                    ,';	-- 計算年月７
			l_strSql := l_strSql || ' CALC_YM8                    ,';	-- 計算年月８
			l_strSql := l_strSql || ' CALC_YM9                    ,';	-- 計算年月９
			l_strSql := l_strSql || ' CALC_YM10                   ,';	-- 計算年月１０
			l_strSql := l_strSql || ' CALC_YM11                   ,';	-- 計算年月１１
			l_strSql := l_strSql || ' CALC_YM12                   ,';	-- 計算年月１２
			l_strSql := l_strSql || ' CALC_YM13                   ,';	-- 計算年月１３
			l_strSql := l_strSql || ' MGOTO_ZNDK1                 ,';	-- 月毎残高１
			l_strSql := l_strSql || ' MGOTO_ZNDK2                 ,';	-- 月毎残高２
			l_strSql := l_strSql || ' MGOTO_ZNDK3                 ,';	-- 月毎残高３
			l_strSql := l_strSql || ' MGOTO_ZNDK4                 ,';	-- 月毎残高４
			l_strSql := l_strSql || ' MGOTO_ZNDK5                 ,';	-- 月毎残高５
			l_strSql := l_strSql || ' MGOTO_ZNDK6                 ,';	-- 月毎残高６
			l_strSql := l_strSql || ' MGOTO_ZNDK7                 ,';	-- 月毎残高７
			l_strSql := l_strSql || ' MGOTO_ZNDK8                 ,';	-- 月毎残高８
			l_strSql := l_strSql || ' MGOTO_ZNDK9                 ,';	-- 月毎残高９
			l_strSql := l_strSql || ' MGOTO_ZNDK10                ,';	-- 月毎残高１０
			l_strSql := l_strSql || ' MGOTO_ZNDK11                ,';	-- 月毎残高１１
			l_strSql := l_strSql || ' MGOTO_ZNDK12                ,';	-- 月毎残高１２
			l_strSql := l_strSql || ' MGOTO_ZNDK13                ,';	-- 月毎残高１３
			l_strSql := l_strSql || ' MGOTO_KICHUTESU_KNGK1       ,';	-- 月毎期中手数料１
			l_strSql := l_strSql || ' MGOTO_KICHUTESU_KNGK2       ,';	-- 月毎期中手数料２
			l_strSql := l_strSql || ' MGOTO_KICHUTESU_KNGK3       ,';	-- 月毎期中手数料３
			l_strSql := l_strSql || ' MGOTO_KICHUTESU_KNGK4       ,';	-- 月毎期中手数料４
			l_strSql := l_strSql || ' MGOTO_KICHUTESU_KNGK5       ,';	-- 月毎期中手数料５
			l_strSql := l_strSql || ' MGOTO_KICHUTESU_KNGK6       ,';	-- 月毎期中手数料６
			l_strSql := l_strSql || ' MGOTO_KICHUTESU_KNGK7       ,';	-- 月毎期中手数料７
			l_strSql := l_strSql || ' MGOTO_KICHUTESU_KNGK8       ,';	-- 月毎期中手数料８
			l_strSql := l_strSql || ' MGOTO_KICHUTESU_KNGK9       ,';	-- 月毎期中手数料９
			l_strSql := l_strSql || ' MGOTO_KICHUTESU_KNGK10      ,';	-- 月毎期中手数料１０
			l_strSql := l_strSql || ' MGOTO_KICHUTESU_KNGK11      ,';	-- 月毎期中手数料１１
			l_strSql := l_strSql || ' MGOTO_KICHUTESU_KNGK12      ,';	-- 月毎期中手数料１２
			l_strSql := l_strSql || ' MGOTO_KICHUTESU_KNGK13      ,';	-- 月毎期中手数料１３
			l_strSql := l_strSql || ' GROUP_ID                    ,';	-- グループＩＤ
			l_strSql := l_strSql || ' SHORI_KBN                   ,';	-- 処理区分
			l_strSql := l_strSql || ' LAST_TEISEI_ID              ,';	-- 最終訂正者
			l_strSql := l_strSql || ' SHONIN_ID                   ,';	-- 承認者
			l_strSql := l_strSql || ' KOUSIN_ID                   ,';	-- 更新者
			l_strSql := l_strSql || ' SAKUSEI_ID                   ';	-- 作成者

			l_strSql := l_strSql || ' )VALUES( ';

			l_strSql := l_strSql || '''' || p_itakukaishacd         || ''', '; -- 委託会社コード
			l_strSql := l_strSql || '''' || p_mgrcd                 || ''', '; -- 銘柄コード
			l_strSql := l_strSql || '''' || p_tesushuruicd          || ''', '; -- 手数料種類コード
			l_strSql := l_strSql || '''' || p_chokyukjt             || ''', '; -- 徴求期日
			l_strSql := l_strSql || '''' || p_chokyuymd             || ''', '; -- 徴求日
			l_strSql := l_strSql || '''' || p_stcalcymd             || ''', '; -- 計算期間（FROM）※計算開始日）
			l_strSql := l_strSql || '''' || p_edcalcymd             || ''', '; -- 計算期間（TO）　※計算終了日）
			l_strSql := l_strSql || '''' || 12                      || ''', '; -- 計算式月（分母）※12ヶ月固定
			l_strSql := l_strSql || '''' || p_tsukisu               || ''', '; -- 計算式月（分子）※月数
			l_strSql := l_strSql || '''' || p_keisanbibunbo         || ''', '; -- 計算式日（分母）※日割分母
			l_strSql := l_strSql || '''' || p_keisanbibunshi        || ''', '; -- 計算式日（分子）※日割分子
			l_strSql := l_strSql || '''' || p_firstlastkichukbn     || ''', '; -- 初期・終期・期中区分
			l_strSql := l_strSql || '''' || p_calcpatterncd         || ''', '; -- 計算パターン
			l_strSql := l_strSql || '''' || p_hankanenoutkbn        || ''', '; -- 半か年外出し区分
			l_strSql := l_strSql || '''' || p_tsukiwarifrom         || ''', '; -- 月割期間From
			l_strSql := l_strSql || '''' || p_tsukiwarito           || ''', '; -- 月割期間To
			l_strSql := l_strSql || '''' || p_hiwarifrom            || ''', '; -- 日割期間From
			l_strSql := l_strSql || '''' || p_hiwarito              || ''', '; -- 日割期間To
			l_strSql := l_strSql || '''' || p_hasutsuki             || ''', '; -- 端数月
			l_strSql := l_strSql || '''' || p_keisanyydd[0]         || ''', '; -- 計算年月１
			l_strSql := l_strSql || '''' || p_keisanyydd[1]         || ''', '; -- 計算年月２
			l_strSql := l_strSql || '''' || p_keisanyydd[2]         || ''', '; -- 計算年月３
			l_strSql := l_strSql || '''' || p_keisanyydd[3]         || ''', '; -- 計算年月４
			l_strSql := l_strSql || '''' || p_keisanyydd[4]         || ''', '; -- 計算年月５
			l_strSql := l_strSql || '''' || p_keisanyydd[5]         || ''', '; -- 計算年月６
			l_strSql := l_strSql || '''' || p_keisanyydd[6]         || ''', '; -- 計算年月７
			l_strSql := l_strSql || '''' || p_keisanyydd[7]         || ''', '; -- 計算年月８
			l_strSql := l_strSql || '''' || p_keisanyydd[8]         || ''', '; -- 計算年月９
			l_strSql := l_strSql || '''' || p_keisanyydd[9]         || ''', '; -- 計算年月１０
			l_strSql := l_strSql || '''' || p_keisanyydd[10]        || ''', '; -- 計算年月１１
			l_strSql := l_strSql || '''' || p_keisanyydd[11]        || ''', '; -- 計算年月１２
			l_strSql := l_strSql || '''' || p_keisanyydd[12]        || ''', '; -- 計算年月１３
			l_strSql := l_strSql || '''' || p_tsukizndk[0]          || ''', '; -- 月毎残高１
			l_strSql := l_strSql || '''' || p_tsukizndk[1]          || ''', '; -- 月毎残高２
			l_strSql := l_strSql || '''' || p_tsukizndk[2]          || ''', '; -- 月毎残高３
			l_strSql := l_strSql || '''' || p_tsukizndk[3]          || ''', '; -- 月毎残高４
			l_strSql := l_strSql || '''' || p_tsukizndk[4]          || ''', '; -- 月毎残高５
			l_strSql := l_strSql || '''' || p_tsukizndk[5]          || ''', '; -- 月毎残高６
			l_strSql := l_strSql || '''' || p_tsukizndk[6]          || ''', '; -- 月毎残高７
			l_strSql := l_strSql || '''' || p_tsukizndk[7]          || ''', '; -- 月毎残高８
			l_strSql := l_strSql || '''' || p_tsukizndk[8]          || ''', '; -- 月毎残高９
			l_strSql := l_strSql || '''' || p_tsukizndk[9]          || ''', '; -- 月毎残高１０
			l_strSql := l_strSql || '''' || p_tsukizndk[10]         || ''', '; -- 月毎残高１１
			l_strSql := l_strSql || '''' || p_tsukizndk[11]         || ''', '; -- 月毎残高１２
			l_strSql := l_strSql || '''' || p_tsukizndk[12]         || ''', '; -- 月毎残高１３
			l_strSql := l_strSql || '''' || p_tsukitesuryo[0]       || ''', '; -- 月毎期中手数料１
			l_strSql := l_strSql || '''' || p_tsukitesuryo[1]       || ''', '; -- 月毎期中手数料２
			l_strSql := l_strSql || '''' || p_tsukitesuryo[2]       || ''', '; -- 月毎期中手数料３
			l_strSql := l_strSql || '''' || p_tsukitesuryo[3]       || ''', '; -- 月毎期中手数料４
			l_strSql := l_strSql || '''' || p_tsukitesuryo[4]       || ''', '; -- 月毎期中手数料５
			l_strSql := l_strSql || '''' || p_tsukitesuryo[5]       || ''', '; -- 月毎期中手数料６
			l_strSql := l_strSql || '''' || p_tsukitesuryo[6]       || ''', '; -- 月毎期中手数料７
			l_strSql := l_strSql || '''' || p_tsukitesuryo[7]       || ''', '; -- 月毎期中手数料８
			l_strSql := l_strSql || '''' || p_tsukitesuryo[8]       || ''', '; -- 月毎期中手数料９
			l_strSql := l_strSql || '''' || p_tsukitesuryo[9]       || ''', '; -- 月毎期中手数料１０
			l_strSql := l_strSql || '''' || p_tsukitesuryo[10]      || ''', '; -- 月毎期中手数料１１
			l_strSql := l_strSql || '''' || p_tsukitesuryo[11]      || ''', '; -- 月毎期中手数料１２
			l_strSql := l_strSql || '''' || p_tsukitesuryo[12]      || ''', '; -- 月毎期中手数料１３
			l_strSql := l_strSql || '''' || ' '                     || ''', '; -- グループＩＤ
			l_strSql := l_strSql || '''' || '0'                     || ''', '; -- 処理区分
			l_strSql := l_strSql || '''' || ' '                     || ''', '; -- 最終訂正者
			l_strSql := l_strSql || '''' || ' '                     || ''', '; -- 承認者
			l_strSql := l_strSql || '''' || ' '                     || ''', '; -- 更新者
			l_strSql := l_strSql || '''' || pkConstant.BATCH_USER()   || '''  '; -- 作成者('BATCH'をセット 2005.07.29 yoshisue)
			l_strSql := l_strSql || ')';

			EXECUTE IMMEDIATE l_strSql;


			/* 手数料計算結果テーブル（分配）に更新 */
			FOR l_rowcntbunpai IN 0..l_rowmaxbunpai LOOP

				-- 分配手数料が０円の金融機関以外を登録する
				IF p_bun_tesuryogaku[l_rowcntbunpai] > 0 THEN

					l_strSql :=				'INSERT INTO TESURYO_BUNPAI(';
					l_strSql := l_strSql || ' ITAKU_KAISHA_CD           ,';	-- 委託会社コード
					l_strSql := l_strSql || ' MGR_CD                    ,';	-- 銘柄コード
					l_strSql := l_strSql || ' TESU_SHURUI_CD            ,';	-- 手数料種類コード
					l_strSql := l_strSql || ' JTK_KBN                   ,';	-- 受託区分
					l_strSql := l_strSql || ' CHOKYU_KJT                ,';	-- 徴求期日
					l_strSql := l_strSql || ' CHOKYU_YMD                ,';	-- 徴求日
					l_strSql := l_strSql || ' FINANCIAL_SECURITIES_KBN  ,';	-- 金融証券区分
					l_strSql := l_strSql || ' BANK_CD                   ,';	-- 金融機関コード
					l_strSql := l_strSql || ' DF_BUNSHI                 ,';	-- 分配率（分子）
					l_strSql := l_strSql || ' DF_TESU_KNGK              ,';	-- 分配手数料（税抜）
					l_strSql := l_strSql || ' DF_TESU_SZEI              ,';	-- 分配手数料消費税
					l_strSql := l_strSql || ' HOSEI_DF_TESU_KNGK        ,';	-- 補正額_分配手数料（税抜）
					l_strSql := l_strSql || ' HOSEI_DF_TESU_SZEI        ,';	-- 補正額_分配手数料消費税
					l_strSql := l_strSql || ' GROUP_ID                  ,';	-- グループＩＤ
					l_strSql := l_strSql || ' SHORI_KBN                 ,';	-- 処理区分
					l_strSql := l_strSql || ' LAST_TEISEI_ID            ,';	-- 最終訂正者
					l_strSql := l_strSql || ' SHONIN_ID                 ,';	-- 承認者
					l_strSql := l_strSql || ' KOUSIN_ID                 ,';	-- 更新者
					l_strSql := l_strSql || ' SAKUSEI_ID                 ';	-- 作成者

					l_strSql := l_strSql || ' )VALUES( ';

					l_strSql := l_strSql || '''' ||  p_itakukaishacd                               || ''', '; -- 委託会社コード
					l_strSql := l_strSql || '''' ||  p_mgrcd                                       || ''', '; -- 銘柄コード
					l_strSql := l_strSql || '''' ||  p_bun_tesushuruicd[l_rowcntbunpai]            || ''', '; -- 手数料種類コード
					l_strSql := l_strSql || '''' ||  p_bun_jtkkbn[l_rowcntbunpai]                  || ''', '; -- 受託区分
					l_strSql := l_strSql || '''' ||  p_bun_chokyukjt[l_rowcntbunpai]               || ''', '; -- 徴求期日
					l_strSql := l_strSql || '''' ||  p_bun_chokyuymd[l_rowcntbunpai]                || ''', '; -- 徴求日
					l_strSql := l_strSql || '''' ||  p_bun_financialsecuritieskbn[l_rowcntbunpai]  || ''', '; -- 金融証券区分
					l_strSql := l_strSql || '''' ||  p_bun_bankcd[l_rowcntbunpai]                  || ''', '; -- 金融機関コード
					l_strSql := l_strSql || '''' ||  p_bun_kichubundfbunshi[l_rowcntbunpai]        || ''', '; -- 分配率（分子）
					l_strSql := l_strSql || '''' ||  p_bun_tesuryogaku[l_rowcntbunpai]             || ''', '; -- 分配手数料（税抜）
					l_strSql := l_strSql || '''' ||  p_bun_tesuryogakuzei[l_rowcntbunpai]          || ''', '; -- 分配手数料消費税
					l_strSql := l_strSql || '''' ||   0                                            || ''', '; -- 補正額_分配手数料（税抜）
					l_strSql := l_strSql || '''' ||   0                                            || ''', '; -- 補正額_分配手数料消費税
					l_strSql := l_strSql || '''' ||  p_bun_groupid[l_rowcntbunpai]                 || ''', '; -- グループＩＤ
					l_strSql := l_strSql || '''' ||  '0'                                           || ''', '; -- 処理区分
					l_strSql := l_strSql || '''' ||  ' '                                           || ''', '; -- 最終訂正者
					l_strSql := l_strSql || '''' ||  ' '                                           || ''', '; -- 承認者
					l_strSql := l_strSql || '''' ||  ' '                                           || ''', '; -- 更新者
					l_strSql := l_strSql || '''' ||  pkConstant.BATCH_USER()                         || ''' '; -- 作成者
					l_strSql := l_strSql || ')';

					EXECUTE l_strSql;

				END IF;

			END LOOP;

		END LOOP;

		CLOSE curTesuRec;

		CALL PKLOG.debug('batch', 'PKIPAKICHUTESURYO', '-------------------PKIPAKICHUTESURYO.UPDATEKICHUTESURYO   END ------------------');
		-- 正常戻り値
		RETURN pkConstant.SUCCESS();

		EXCEPTION
			WHEN OTHERS THEN
				--raise notice 'SQLERR: %', SQLERRM;
				CALL PKLOG.ERROR('ECM701','PKIPAKICHUTESURYO', SQLSTATE);
				CALL PKLOG.ERROR('ECM701','PKIPAKICHUTESURYO',SQLERRM);
				RETURN pkConstant.FATAL();

	END $$ LANGUAGE PLPGSQL;
