CREATE SCHEMA IF NOT EXISTS pkipakknido;

drop function if exists pkipakknido.getmunitsknpremium(char, bigint, char, numeric, bigint, bigint, bigint);
drop function if exists pkipakknido.getmunitsknpremium(char, bigint, char, numeric, numeric, numeric, bigint);
drop function if exists pkipakknido.getmunitsknshrkngk(char, varchar, bigint, char, char, numeric, char, char, numeric, bigint, bigint, bigint, bigint);
drop function if exists pkipakknido.getmunitsknshrkngk(char, bigint, char, char, numeric, char, numeric, numeric, numeric, bigint, bigint);
drop function if exists pkipakknido.getmunitsknshrkngk(character,character varying,bigint,character,character,numeric,character,character,numeric,numeric,numeric,bigint,bigint);
DROP FUNCTION if exists pkipakknido.getputmunitsknshrkngk(numeric,character,character,numeric,numeric,numeric,numeric);
drop function if exists pkipakknido.updategnrseikyusho;
drop function if exists pkipakknido.inskikinidoukeirekanriout;
drop function if exists pkipakknido.inskikinidoseikyuout;

drop type if exists pkipakknido.type_table ;
DROP TYPE IF EXISTS pkipakknido.typerecord ;
drop type if exists pkipakknido.type_key ;
drop type if exists pkipakknido.type_record ;
drop type if exists pkipakknido.rectype ;

-- constants
create or replace function pkipakknido.success() returns integer as $$ select integer '0' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;

/*==============================================================================*/
/*                  定数定義                                                    */
/*==============================================================================*/
create or replace function pkipakknido.c_SHONIN() returns char as $$ select char '1' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--				CONSTANT MGR_STS.MGR_STAT_KBN%TYPE := '1';	-- 処理区分（承認）
create or replace function pkipakknido.c_NOT_MASSHO() returns char as $$ select char '0' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--			CONSTANT MGR_STS.MASSHO_FLG%TYPE   := '0';	-- 抹消フラグ（未抹消）
create or replace function pkipakknido.c_SEIKYU() returns varchar(11) as $$ select varchar(11) 'IP030004631' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--				CONSTANT VARCHAR(11)	:= 'IP030004631';	-- 請求書
create or replace function pkipakknido.c_RYOSHU() returns varchar(11) as $$ select varchar(11) 'IP030004641' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--				CONSTANT VARCHAR(11)	:= 'IP030004641';	-- 領収書
create or replace function pkipakknido.c_SEIKYU_ICHIRAN() returns char(11) as $$ select char(11) 'IP030004511' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--		CONSTANT CHAR(11)		:= 'IP030004511';	-- 請求書一覧表
create or replace function pkipakknido.c_SEIKYU_KAIKEIKUBUN() returns char(11) as $$ select char(11) 'IPH30000511' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--	CONSTANT CHAR(11)		:= 'IPH30000511';	-- 元利基金・手数料請求書(会計区分別)
create or replace function pkipakknido.c_GANRI_MEISAI() returns char(11) as $$ select char(11) 'IPH30000611' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--			CONSTANT CHAR(11)		:= 'IPH30000611';	-- 公債会計区分別元利金明細票(会計区分毎改ページ)
create or replace function pkipakknido.c_GANRI_MEISAI_M() returns char(11) as $$ select char(11) 'IPH30000911' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--		CONSTANT CHAR(11)		:= 'IPH30000911';	-- 公債会計区分別元利金明細票(銘柄毎改ページ)
create or replace function pkipakknido.c_SEIKYU_MEISAI() returns varchar(11) as $$ select varchar(11) 'IP030010211' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--			CONSTANT VARCHAR(11)	:= 'IP030010211';	-- 請求明細書
create or replace function pkipakknido.c_UKEIRE_KANRI() returns varchar(11) as $$ select varchar(11) 'IP030004811' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--			CONSTANT VARCHAR(11)	:= 'IP030004811';	-- 元利払基金受入管理表

create or replace function pkipakknido.c_HAKKO_ICHIRAN() returns varchar(11) as $$ select varchar(11) 'IPS30200121' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--			CONSTANT VARCHAR(11)	:= 'IPS30200121';	-- 口座店・発行体（CIF）順
create or replace function pkipakknido.c_KOZA_ICHIRAN() returns varchar(11) as $$ select varchar(11) 'IPS30200131' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--			CONSTANT VARCHAR(11)	:= 'IPS30200131';	-- 口座店別

create or replace function pkipakknido.C_RTN_NODATA() returns integer as $$ select integer '2' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--			CONSTANT INTEGER		:= 2;				-- データなし

create or replace function pkipakknido.c_NOT_SEIKYU_OUT() returns char(1) as $$ select char(1) '5' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;-- constant char(1) := '5'; --請求書を出力しない

-- 書式フォーマット
create or replace function pkipakknido.FMT_HAKKO_KNGK_J() returns char(18) as $$ select char(18) 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--	CONSTANT CHAR(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
create or replace function pkipakknido.FMT_RBR_KNGK_J() returns char(18) as $$ select char(18) 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--		CONSTANT CHAR(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 利払金額
create or replace function pkipakknido.FMT_SHOKAN_KNGK_J() returns char(18) as $$ select char(18) 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--	CONSTANT CHAR(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 償還金額

-- 書式フォーマット（外資）
create or replace function pkipakknido.FMT_HAKKO_KNGK_F() returns char(21) as $$ select char(21) 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--	CONSTANT CHAR(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 発行金額
create or replace function pkipakknido.FMT_RBR_KNGK_F() returns char(21) as $$ select char(21) 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--		CONSTANT CHAR(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 利払金額
create or replace function pkipakknido.FMT_SHOKAN_KNGK_F() returns char(21) as $$ select char(21) 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--	CONSTANT CHAR(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 償還金額

-- 最終回次フラグ
create or replace function pkipakknido.KAIJI_LAST() returns char(1) as $$ select char(1) '1' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--          CONSTANT CHAR(1) := '1';                        -- 最終
create or replace function pkipakknido.KAIJI_NOT_LAST() returns char(1) as $$ select char(1) '0' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--      CONSTANT CHAR(1) := '0';                        -- 最終ではない

-- 償還区分 （コード種別:714） */
create or replace function pkipakknido.CODE_SHOKAN_KBN() returns varchar(3) as $$ select varchar(3) '714' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;-- 	CONSTANT VARCHAR(3) := '714';

-- 償還区分（コード種別：714）
create or replace function pkipakknido.MANKI_IKKATU() returns char(2) as $$ select char(2) '10' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--        CONSTANT CHAR(2) := '10';                       -- 満期一括
create or replace function pkipakknido.TEIJI_TEIGAKU() returns char(2) as $$ select char(2) '20' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--       CONSTANT CHAR(2) := '20';                       -- 定時定額償還
create or replace function pkipakknido.TEIJI_FUTEIGAKU() returns char(2) as $$ select char(2) '21' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--     CONSTANT CHAR(2) := '21';                       -- 定時不定額償還
create or replace function pkipakknido.KAIIRE_SHOKYAKU() returns char(2) as $$ select char(2) '30' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--     CONSTANT CHAR(2) := '30';                       -- 買入消却
create or replace function pkipakknido.call_all() returns char(2) as $$ select char(2) '40' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--            CONSTANT CHAR(2) := '40';                       -- コール（全額）
create or replace function pkipakknido.CALL_ITIBU() returns char(2) as $$ select char(2) '41' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--          CONSTANT CHAR(2) := '41';                       -- コール（一部）
create or replace function pkipakknido.PUT() returns char(2) as $$ select char(2) '50' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--                 CONSTANT CHAR(2) := '50';                       -- プット
create or replace function pkipakknido.CB_KOUSHI() returns char(2) as $$ select char(2) '60' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;--           CONSTANT CHAR(2) := '60';                       -- ＣＢ行使


CREATE TYPE pkipakknido.rectype AS (
		rItakuKaishaCd			char(4), --MGR_KIHON.ITAKU_KAISHA_CD%TYPE,
		rMgrCd			varchar(13), --		MGR_KIHON.MGR_CD%TYPE,
		rRbrKjt					char(8),
		rChokyuYmd				char(8)

);

CREATE TYPE pkipakknido.typerecord AS (typerecord pkIpaKknIdo.recType[]);

CREATE TYPE pkipakknido.type_key AS (
		gIdoYmd				char(8), -- KIKIN_IDO.IDO_YMD%TYPE := ' '
		gTsukaCd			char(3), -- KIKIN_IDO.TSUKA_CD%TYPE := ' '
		gKozaFuriKbn		char(2), -- MGR_KIHON.KOZA_FURI_KBN%TYPE := ' '
		gRbrYmd			char(8), -- KIKIN_IDO.RBR_YMD%TYPE := ' '
		gHktCd				char(6), -- MGR_KIHON.HKT_CD%TYPE := ' '
		gIsinCd			char(12) -- MGR_KIHON.ISIN_CD%TYPE := ' '

);

CREATE TYPE pkipakknido.type_record AS (
		gTsukaNm				char(3), --MTSUKA.TSUKA_NM%TYPE
		gTsukaCd				char(3), -- KIKIN_IDO.TSUKA_CD%TYPE
		gHakkoTsukaCd			char(3), -- MGR_KIHON.HAKKO_TSUKA_CD%TYPE
		gRbrTsukaCd			char(3), -- MGR_KIHON.RBR_TSUKA_CD%TYPE
		gShokanTsukaCd			char(3), -- MGR_KIHON.SHOKAN_TSUKA_CD%TYPE
		gIsinCd				char(12), -- MGR_KIHON.ISIN_CD%TYPE
		gMgrCd					varchar(13), -- MGR_KIHON.MGR_CD%TYPE
		gMgrRnm				char(44), -- MGR_KIHON.MGR_RNM%TYPE
		gRbrYmd				char(8), -- KIKIN_IDO.RBR_YMD%TYPE
		gIdoYmd				char(8), -- KIKIN_IDO.IDO_YMD%TYPE
		gKozaFuriKbn			char(2), -- MGR_KIHON.KOZA_FURI_KBN%TYPE
		gNyukinMethod			text,
		gKozaTenCd				char(4), -- MHAKKOTAI.KOZA_TEN_CD%TYPE
		gKknbillShuruiNm		varchar(20), -- SCODE.CODE_RNM%TYPE
		gKknNyukinKngk			numeric(16,2), -- KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE
		gKknIdoKbn				char(2), -- KIKIN_IDO.KKN_IDO_KBN%TYPE
		gRknShrTesuBunshi		numeric(17,14), -- MGR_TESURYO_PRM.RKN_SHR_TESU_BUNSHI%TYPE
		gRknShrTesuBunbo		integer, -- MGR_TESURYO_PRM.RKN_SHR_TESU_BUNBO%TYPE
		gGnknShrTesuBunshi		numeric(17,14), -- MGR_TESURYO_PRM.GNKN_SHR_TESU_BUNSHI%TYPE
		gGnknShriTesuBunbo		integer, -- MGR_TESURYO_PRM.GNKN_SHR_TESU_BUNBO%TYPE
		gHktCd					char(6), -- MGR_KIHON.HKT_CD%TYPE
		gHktRnm					varchar(40), -- MHAKKOTAI.HKT_RNM%TYPE
		gKozaTenCifcd 			char(11), -- MHAKKOTAI.KOZA_TEN_CIFCD%TYPE
		gRknKngk				double precision, -- := 0,
		gRknTesuKngk			double precision, -- := 0,
		gGnknKngk				double precision, -- := 0,
		gGnknTesuKngk			double precision, -- := 0,
		gGokeiKngk				double precision, -- := 0,
		gGokeiSzei				double precision, -- := 0,
		gBankRnm				varchar(20), -- VJIKO_ITAKU.BANK_RNM%TYPE
		gJikoDaikoKbn			char --  VJIKO_ITAKU.JIKO_DAIKO_KBN%TYPE

);

CREATE TYPE pkipakknido.type_table AS (type_table pkIpaKknIdo.TYPE_RECORD[]);

 /**
 * 元利払基金・手数料
 * 請求書一覧表・請求書（リアル・バッチ）に関する処理を行なうパッケージです
 *
 * @author 山下　健太
 * @author 海老澤　智(ASK)
 * @version $Id: pkIpaKknIdo.sql 7920 2017-03-16 02:52:41Z j8800053 $
 */
	/********************************************************************************
	* 概要　:SQLを作成する
	* 引数　:
	* 返り値:SQLステートメント
	*
	* @param
	* @return	l_ret				正常終了/異常終了
	*********************************************************************************/
CREATE OR REPLACE FUNCTION pkipakknido.createsql ( l_ingyomuymd TEXT ,             -- 業務日付
 l_inkjnfrom TEXT ,              -- 基準日From
 l_inkjnto TEXT ,                -- 基準日To
 l_initakukaishacd text ,    -- 委託会社CD
 l_inhktcd TEXT ,                -- 発行体CD
 l_inkozatencd text ,        -- 口座店CD
 l_inkozatencifcd text ,     -- 口座店CIFCD
 l_inmgrcd TEXT ,                -- 銘柄CD
 l_inisincd TEXT ,               -- ISINCD
 l_inrealbatchkbn TEXT ,         -- リアルバッチ区分 0:リアル 1:バッチ 2:バッチ（地公体）
 l_inseikyuichirankbn TEXT,      -- 請求書一覧区分
 l_insyoriflg TEXT                -- 処理フラグ 0:請求書出力処理 1:元利払基金受入管理表出力処理
 ) RETURNS varchar AS $body$
DECLARE

		l_sql					varchar(10000);
		rSqlWhere 				varchar(10000);
		rGyomuYmdAfter1d		char(8);		-- 1営業日後
		rGyomuYmdAfter2d		char(8);		-- 2営業日後
		rOutYmd					char(8);		-- 請求書出力日
		rDays					int := 0;

BEGIN

		-- バッチの場合、システム出力分の出力範囲を取得する
		IF	l_inrealbatchkbn = '1' OR l_inrealbatchkbn = '2' THEN
			--業務日付から数えて２営業日後の日付を取得する
			rGyomuYmdAfter2d := pkdate.getPlusDateBusiness(l_ingyomuymd, 2, PKCONSTANT.TOKYO_AREA_CD());
			--業務日付から数えて１営業日後の日付を取得する
			rGyomuYmdAfter1d := pkdate.getPlusDateBusiness(l_ingyomuymd, 1, PKCONSTANT.TOKYO_AREA_CD());

			/*※請求書出力対象の日付
			　業務日付 から見て→ １営業日後〜２営業日後の前日（１営業日後≦出力日＜２営業日後）*/
			/* 出力日抽出条件SQL編集開始 */

			rSqlWhere := ' IN	(''' || rGyomuYmdAfter1d || ''' '; -- １営業日後
			LOOP
				rDays := rDays+1;
				-- 請求書出力日 = １営業日後 + rDays後
				rOutYmd := TO_CHAR(TO_DATE(rGyomuYmdAfter1d,'YYYYMMDD') + rDays ,'YYYYMMDD');

				-- 請求書出力日は２営業日後の前日まで ２営業日後に到達したらループ終了
				EXIT WHEN TO_DATE(rOutYmd,'YYYYMMDD') >= TO_DATE(rGyomuYmdAfter2d,'YYYYMMDD');

				--「１営業日後〜２営業日後の前日」までの範囲内を IN条件にセットする
				rSqlWhere := rSqlWhere || ',''' || rOutYmd	|| ''' ';
			END LOOP;
			rSqlWhere := rSqlWhere || ' )';
			/* 出力日抽出条件SQL編集終了 */

		END IF;

		/* 	l_sql
			以下の帳票を出力する時の、出力対象データを抽出するsqlを作成する。
			・手数料請求一覧表			（リアル・バッチ）
			・元利払基金請求書／領収書	（リアル・バッチ）
			・元利払基金受入管理表		（リアルのみ）	*/
		-- 利金
		l_sql := '	SELECT /*+ INDEX(MG1 MGR_KIHON_PK) INDEX(MG0 MGR_STS_PK)*/'; -- ヒント文付加
		l_sql := l_sql || '		MG1.ITAKU_KAISHA_CD, ';
		l_sql := l_sql || '		MG1.MGR_CD, ';
		l_sql := l_sql || '		MG2.RBR_KJT, ';
		l_sql := l_sql || '		CASE MG1.JTK_KBN WHEN ''5'' THEN MG2.RBR_YMD ELSE MG2.KKN_CHOKYU_YMD END AS CHOKYU_YMD';	-- 自社発行の場合は利払日をセット
		l_sql := l_sql || '	FROM ';
		l_sql := l_sql || '		MGR_KIHON       MG1, ';
		l_sql := l_sql || '		MGR_STS         MG0, ';
		l_sql := l_sql || '		MGR_RBRKIJ      MG2, ';
		l_sql := l_sql || '		MHAKKOTAI       M01 ';
		l_sql := l_sql || '	WHERE MG0.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD ';
		l_sql := l_sql || '	AND   MG0.MGR_CD = MG1.MGR_CD ';
		l_sql := l_sql || '	AND   MG1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD ';
		l_sql := l_sql || '	AND   MG1.MGR_CD          = MG2.MGR_CD ';
		l_sql := l_sql || '	AND   MG0.MASSHO_FLG = ''0''';
		l_sql := l_sql || '	AND   MG1.PARTMGR_KBN IN (''0'',''2'')'; --親銘柄を対象外
		l_sql := l_sql || '	AND   (MG1.PARTMGR_KBN IN (''0'',''1'') OR SUBSTR(MG1.YOBI3, 14, 1) = ''0'')'; --子銘柄（残高なし）を対象外
		l_sql := l_sql || '	AND   MG1.ITAKU_KAISHA_CD = ''' || l_initakuKaishaCd || ''' ';
		l_sql := l_sql || '	AND   MG0.MGR_STAT_KBN    = ''' || pkipakknido.c_SHONIN() || ''' ';
		l_sql := l_sql || '	AND   MG1.JTK_KBN		  <> ''2'' ';
		l_sql := l_sql || '	AND   MG1.KK_KANYO_FLG	  <> ''2'' ';	--実質記番号管理方式は対象外
		l_sql := l_sql || '	AND   MG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD ';
		l_sql := l_sql || '	AND   MG1.HKT_CD          = M01.HKT_CD ';
		l_sql := l_sql || '	AND   TRIM(MG1.ISIN_CD)   IS NOT NULL ';
		IF l_inrealbatchkbn = '1' OR l_inrealbatchkbn = '2' THEN	-- リアルの場合は徴求日の個別設定をしている銘柄も出力するため、この条件を入れない
			l_sql := l_sql || '	AND   MG2.KKNBILL_OUT_YMD =  '' ''';
			l_sql := l_sql || '	AND   MG1.KKNBILL_OUT_TMG1    <> ''' || pkipakknido.c_NOT_SEIKYU_OUT()|| ''' ';
		END IF;
		-- 受託区分＝自社発行以外は基金徴求日が空白のレコードは対象外
		l_sql := l_sql || '	AND  ((MG2.KKN_CHOKYU_YMD  <> '' '' AND MG1.JTK_KBN <> ''5'') OR (MG1.JTK_KBN = ''5'')) ';

		-- 基準日From〜Toの検索対象
		-- 受入管理表　　　→基金徴求日を検索
		IF l_insyoriflg = '1' THEN
			l_sql := l_sql || '	AND   MG2.KKN_CHOKYU_YMD BETWEEN ''' || l_inkjnfrom || ''' AND ''' || l_inkjnto  || '''';
			l_sql := l_sql || '	AND   MG1.JTK_KBN		 <> ''5'' ';	-- リアルでは自社発行を計算しない
			-- その他（リアル）→基金徴求日(自社発行以外) または 利払期日(自社発行)を検索
		ELSIF l_inrealbatchkbn = '0' THEN
			l_sql := l_sql || '	AND   MG2.KKN_CHOKYU_YMD BETWEEN ''' || l_inkjnfrom || ''' AND ''' || l_inkjnto  || '''';
			l_sql := l_sql || '	AND   MG1.JTK_KBN		 <> ''5'' ';	-- リアルでは自社発行を計算しない
		    -- 地公体（バッチ）→基金徴求日(自社発行以外)
		ELSIF l_inrealbatchkbn = '2' THEN
			l_sql := l_sql || '	AND  ((MG2.KKN_CHOKYU_YMD BETWEEN ''' || l_inkjnfrom || ''' AND ''' || l_inkjnto  || ''' AND MG1.JTK_KBN <> ''5'')) ';
			-- その他（バッチ）→利払期日(自社発行以外) --または 業務日付=利払期日-1日(自社発行)を検索
		ELSE
			l_sql := l_sql || '	AND  ((MG2.RBR_KJT BETWEEN ''' || l_inkjnfrom || ''' AND ''' || l_inkjnto  || ''' AND MG1.JTK_KBN <> ''5'') '
						   || '		OR(PKDATE.GETMINUSDATEBUSINESS(MG2.RBR_YMD,1) = ''' || l_ingyomuymd || ''' AND MG1.JTK_KBN = ''5''))';
		END IF;

		IF nullif(trim(both l_inhktcd), '')        IS NOT NULL THEN -- 発行体CD
			l_sql := l_sql || '	AND   MG1.HKT_CD          = ''' || l_inhktcd || ''' ';
		END IF;
		IF nullif(trim(both l_inkozatencd), '')    IS NOT NULL THEN -- 口座店CD
			l_sql := l_sql || '	AND   M01.KOZA_TEN_CD	  = ''' || l_inkozatencd || ''' ';
		END IF;
		IF nullif(trim(both l_inkozatencifcd), '') IS NOT NULL THEN -- 口座店CIFCD
			l_sql := l_sql || '	AND   M01.KOZA_TEN_CIFCD  = ''' || l_inkozatencifcd || ''' ';
		END IF;
		IF nullif(trim(both l_inmgrcd), '')        IS NOT NULL THEN -- 銘柄CD
			l_sql := l_sql || '	AND   MG1.MGR_CD          = ''' || l_inmgrcd || ''' ';
		END IF;
		IF nullif(trim(both l_inisincd), '')       IS NOT NULL THEN -- ISINCD
			l_sql := l_sql || '	AND   MG1.ISIN_CD         = ''' || l_inisincd || ''' ';
		END IF;

		l_sql := l_sql || '	UNION ';
		-- 利金手数料
		l_sql := l_sql || '	SELECT /*+ INDEX(MG1 MGR_KIHON_PK) INDEX(MG0 MGR_STS_PK)*/'; -- ヒント文付加
		l_sql := l_sql || '		MG1.ITAKU_KAISHA_CD, ';
		l_sql := l_sql || '		MG1.MGR_CD, ';
		l_sql := l_sql || '		MG2.RBR_KJT, ';
		l_sql := l_sql || '		MG2.TESU_CHOKYU_YMD AS CHOKYU_YMD ';
		l_sql := l_sql || '	FROM ';
		l_sql := l_sql || '		MGR_KIHON       MG1, ';
		l_sql := l_sql || '		MGR_STS         MG0, ';
		l_sql := l_sql || '		MGR_RBRKIJ      MG2, ';
		l_sql := l_sql || '		MGR_KIHON2      BT3, ';
		l_sql := l_sql || '		MHAKKOTAI       M01, ';
		l_sql := l_sql || '		MGR_TESURYO_CTL MG7, ';
		l_sql := l_sql || '		MGR_TESURYO_PRM MG8 ';
		l_sql := l_sql || '	WHERE MG0.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD ';
		l_sql := l_sql || '	AND   MG0.MGR_CD = MG1.MGR_CD ';
		l_sql := l_sql || '	AND   MG1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD ';
		l_sql := l_sql || '	AND   MG1.MGR_CD          = MG2.MGR_CD ';
		l_sql := l_sql || '	AND   MG1.ITAKU_KAISHA_CD = BT3.ITAKU_KAISHA_CD ';
		l_sql := l_sql || '	AND   MG1.MGR_CD          = BT3.MGR_CD ';
		l_sql := l_sql || '	AND   MG0.MASSHO_FLG = ''0''';
		l_sql := l_sql || '	AND   MG1.PARTMGR_KBN IN (''0'',''2'')'; --親銘柄を対象外
		l_sql := l_sql || '	AND   (MG1.PARTMGR_KBN IN (''0'',''1'') OR SUBSTR(MG1.YOBI3, 14, 1) = ''0'')'; --子銘柄（残高なし）を対象外
		l_sql := l_sql || '	AND   MG1.ITAKU_KAISHA_CD = ''' || l_initakuKaishaCd || ''' ';
		l_sql := l_sql || '	AND   MG0.MGR_STAT_KBN    = ''' || pkipakknido.c_SHONIN() || ''' ';
		l_sql := l_sql || '	AND   MG1.JTK_KBN		   NOT IN (''2'',''5'') ';
		l_sql := l_sql || '	AND   MG1.KK_KANYO_FLG	  <> ''2'' ';	--実質記番号管理方式は対象外
		l_sql := l_sql || '	AND   MG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD ';
		l_sql := l_sql || '	AND   MG1.HKT_CD          = M01.HKT_CD ';
		l_sql := l_sql || '	AND   TRIM(MG1.ISIN_CD)   IS NOT NULL ';
		IF l_inrealbatchkbn = '1' OR l_inrealbatchkbn = '2' THEN	-- リアルの場合は徴求日の個別設定をしている銘柄も出力するため、この条件を入れない
			l_sql := l_sql || '	AND   MG2.TESUBILL_OUT_YMD = '' ''';
			l_sql := l_sql || '	AND   MG1.KKNBILL_OUT_TMG1    <> ''' || pkipakknido.c_NOT_SEIKYU_OUT()|| ''' ';
		END IF;
		IF l_inrealbatchkbn = '1' OR l_inrealbatchkbn = '2' THEN	-- バッチの場合、アップフロント銘柄を対象外とする。
			l_sql := l_sql || '	AND   BT3.UPFRONT_FLG = ''0'' ';
		END IF;
		l_sql := l_sql || '	AND   MG2.TESU_CHOKYU_YMD  <> '' ''';
		-- 銘柄_手数料（制御情報）tblより、手数料種類-利金支払手数料が選択されている銘柄のみ対象とする
		l_sql := l_sql || '	AND   MG1.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD ';
		l_sql := l_sql || '	AND   MG1.MGR_CD = MG7.MGR_CD ';
		l_sql := l_sql || '	AND   MG7.TESU_SHURUI_CD IN (''61'',''82'') ';
		l_sql := l_sql || '	AND   MG7.CHOOSE_FLG = ''1'' ';
		-- 銘柄_手数料（計算情報）tblより、利金支払手数料率（分母）>0の銘柄のみ対象とする（0除算エラー回避のため）
		l_sql := l_sql || '	AND   MG1.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD ';
		l_sql := l_sql || '	AND   MG1.MGR_CD = MG8.MGR_CD ';
		l_sql := l_sql || '	AND   MG8.RKN_SHR_TESU_BUNBO > 0 ';

		  -- 基準日From〜Toの検索対象
		   -- 受入管理表　　　→手数料徴求日を検索
		IF l_insyoriflg = '1' THEN
			l_sql := l_sql || '	AND   MG2.TESU_CHOKYU_YMD BETWEEN ''' || l_inkjnfrom || ''' AND ''' || l_inkjnto  || '''';
		   -- その他（リアル）→手数料徴求日を検索
		ELSIF l_inrealbatchkbn = '0' THEN
			l_sql := l_sql || '	AND   MG2.TESU_CHOKYU_YMD BETWEEN ''' || l_inkjnfrom || ''' AND ''' || l_inkjnto  || '''';
			-- 地公体（バッチ）→手数料徴求日を検索
		ELSIF l_inrealbatchkbn = '2' THEN
		    l_sql := l_sql || '	AND   MG2.TESU_CHOKYU_YMD BETWEEN ''' || l_inkjnfrom || ''' AND ''' || l_inkjnto  || '''';
			-- その他（バッチ）→利払期日を検索
		ELSE
			l_sql := l_sql || '	AND   MG2.RBR_KJT BETWEEN ''' || l_inkjnfrom || ''' AND ''' || l_inkjnto  || '''';
		END IF;

		IF nullif(trim(both l_inhktcd), '')        IS NOT NULL THEN -- 発行体CD
			l_sql := l_sql || '	AND   MG1.HKT_CD          = ''' || l_inhktcd || ''' ';
		END IF;
		IF nullif(trim(both l_inkozatencd), '')    IS NOT NULL THEN -- 口座店CD
			l_sql := l_sql || '	AND   M01.KOZA_TEN_CD	  = ''' || l_inkozatencd || ''' ';
		END IF;
		IF nullif(trim(both l_inkozatencifcd), '') IS NOT NULL THEN -- 口座店CIFCD
			l_sql := l_sql || '	AND   M01.KOZA_TEN_CIFCD  = ''' || l_inkozatencifcd || ''' ';
		END IF;
		IF nullif(trim(both l_inmgrcd), '')        IS NOT NULL THEN -- 銘柄CD
			l_sql := l_sql || '	AND   MG1.MGR_CD          = ''' || l_inmgrcd || ''' ';
		END IF;
		IF nullif(trim(both l_inisincd), '')       IS NOT NULL THEN -- ISINCD
			l_sql := l_sql || '	AND   MG1.ISIN_CD         = ''' || l_inisincd || ''' ';
		END IF;

		l_sql := l_sql || '	UNION ';
		-- 元金
		l_sql := l_sql || '	SELECT /*+ INDEX(MG1 MGR_KIHON_PK) INDEX(MG0 MGR_STS_PK)*/'; -- ヒント文付加
		l_sql := l_sql || '		MG1.ITAKU_KAISHA_CD, ';
		l_sql := l_sql || '		MG1.MGR_CD, ';
		l_sql := l_sql || '		MG3.SHOKAN_KJT     AS RBR_KJT, ';
		l_sql := l_sql || '		CASE MG1.JTK_KBN WHEN ''5'' THEN MG3.SHOKAN_YMD ELSE MG3.KKN_CHOKYU_YMD END AS CHOKYU_YMD';	-- 自社発行の場合は償還日をセット
		l_sql := l_sql || '	FROM ';
		l_sql := l_sql || '		MGR_KIHON       MG1, ';
		l_sql := l_sql || '		MGR_STS         MG0, ';
		l_sql := l_sql || '		MGR_SHOKIJ      MG3, ';
		l_sql := l_sql || '		MHAKKOTAI       M01 ';
		l_sql := l_sql || '	WHERE MG0.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD ';
		l_sql := l_sql || '	AND   MG0.MGR_CD = MG1.MGR_CD ';
		l_sql := l_sql || '	AND   MG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD ';
		l_sql := l_sql || '	AND   MG1.MGR_CD          = MG3.MGR_CD ';
		l_sql := l_sql || '	AND   MG0.MASSHO_FLG = ''0''';
		l_sql := l_sql || '	AND   MG1.PARTMGR_KBN IN (''0'',''2'')'; --親銘柄を対象外
		l_sql := l_sql || '	AND   (MG1.PARTMGR_KBN IN (''0'',''1'') OR SUBSTR(MG1.YOBI3, 14, 1) = ''0'')'; --子銘柄（残高なし）を対象外
		l_sql := l_sql || '	AND   MG1.ITAKU_KAISHA_CD = ''' || l_initakuKaishaCd || ''' ';
		l_sql := l_sql || '	AND   MG0.MGR_STAT_KBN    =''' || pkipakknido.c_SHONIN() || ''' ';
		l_sql := l_sql || '	AND   MG1.JTK_KBN		  <> ''2'' ';
		l_sql := l_sql || '	AND   MG1.KK_KANYO_FLG	  <> ''2'' ';	--実質記番号管理方式は対象外
		l_sql := l_sql || '	AND   MG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD ';
		l_sql := l_sql || '	AND   MG1.HKT_CD          = M01.HKT_CD ';
		l_sql := l_sql || '	AND   TRIM(MG1.ISIN_CD)   IS NOT NULL ';
		IF l_inrealbatchkbn = '1' OR l_inrealbatchkbn = '2' THEN	-- リアルの場合は徴求日の個別設定をしている銘柄も出力するため、この条件を入れない
			l_sql := l_sql || '	AND   MG3.KKNBILL_OUT_YMD =  '' ''';
			l_sql := l_sql || '	AND   MG1.KKNBILL_OUT_TMG1    <> ''' || pkipakknido.c_NOT_SEIKYU_OUT()|| ''' ';
		END IF;

		-- 受託区分＝自社発行以外は基金徴求日が空白のレコードは対象外
		l_sql := l_sql || '	AND  ((MG3.KKN_CHOKYU_YMD  <> '' '' AND MG1.JTK_KBN <> ''5'') OR (MG1.JTK_KBN = ''5'')) ';

		l_sql := l_sql || '	AND   MG3.SHOKAN_KBN  <> ''30''';

		-- 基準日From〜Toの検索対象
		-- 受入管理表　　　→基金徴求日を検索
		IF l_insyoriflg = '1' THEN
			l_sql := l_sql || '	AND   MG3.KKN_CHOKYU_YMD BETWEEN ''' || l_inkjnfrom || ''' AND ''' || l_inkjnto  || '''';
			l_sql := l_sql || '	AND   MG1.JTK_KBN		 <> ''5'' ';	-- リアルでは自社発行を計算しない
			-- その他（リアル）→基金徴求日(自社発行以外) または 利払期日(自社発行)を検索
		ELSIF l_inrealbatchkbn = '0' THEN
			l_sql := l_sql || '	AND   MG3.KKN_CHOKYU_YMD BETWEEN ''' || l_inkjnfrom || ''' AND ''' || l_inkjnto  || '''';
			l_sql := l_sql || '	AND   MG1.JTK_KBN		 <> ''5'' ';	-- リアルでは自社発行を計算しない
			-- 地公体（バッチ）→基金徴求日(自社発行以外)
		ELSIF l_inrealbatchkbn = '2' THEN
			l_sql := l_sql || '	AND  ((MG3.KKN_CHOKYU_YMD BETWEEN ''' || l_inkjnfrom || ''' AND ''' || l_inkjnto  || ''' AND MG1.JTK_KBN <> ''5'')) ';
			-- その他（バッチ）→償還期日(自社発行以外) または 業務日付=償還期日-1日(自社発行)を検索
		ELSE
			l_sql := l_sql || '	AND  ((MG3.SHOKAN_KJT BETWEEN ''' || l_inkjnfrom || ''' AND ''' || l_inkjnto  || ''' AND MG1.JTK_KBN <> ''5'') '
						   || '		OR(PKDATE.GETMINUSDATEBUSINESS(MG3.SHOKAN_YMD,1) = ''' || l_ingyomuymd || ''' AND MG1.JTK_KBN = ''5''))';
		END IF;

		IF nullif(trim(both l_inhktcd), '')        IS NOT NULL THEN -- 発行体CD
			l_sql := l_sql || '	AND   MG1.HKT_CD          = ''' || l_inhktcd || ''' ';
		END IF;
		IF nullif(trim(both l_inkozatencd), '')    IS NOT NULL THEN -- 口座店CD
			l_sql := l_sql || '	AND   M01.KOZA_TEN_CD	  = ''' || l_inkozatencd || ''' ';
		END IF;
		IF nullif(trim(both l_inkozatencifcd), '') IS NOT NULL THEN -- 口座店CIFCD
			l_sql := l_sql || '	AND   M01.KOZA_TEN_CIFCD  = ''' || l_inkozatencifcd || ''' ';
		END IF;
		IF nullif(trim(both l_inmgrcd), '')        IS NOT NULL THEN -- 銘柄CD
			l_sql := l_sql || '	AND   MG1.MGR_CD          = ''' || l_inmgrcd || ''' ';
		END IF;
		IF nullif(trim(both l_inisincd), '')       IS NOT NULL THEN -- ISINCD
			l_sql := l_sql || '	AND   MG1.ISIN_CD         = ''' || l_inisincd || ''' ';
		END IF;

		l_sql := l_sql || '	UNION ';
		-- 元金手数料
		l_sql := l_sql || '	SELECT /*+ INDEX(MG1 MGR_KIHON_PK) INDEX(MG0 MGR_STS_PK)*/'; -- ヒント文付加
		l_sql := l_sql || '		MG1.ITAKU_KAISHA_CD, ';
		l_sql := l_sql || '		MG1.MGR_CD, ';
		l_sql := l_sql || '		MG3.SHOKAN_KJT      AS RBR_KJT, ';
		l_sql := l_sql || '		MG3.TESU_CHOKYU_YMD AS CHOKYU_YMD ';
		l_sql := l_sql || '	FROM ';
		l_sql := l_sql || '		MGR_KIHON       MG1, ';
		l_sql := l_sql || '		MGR_STS         MG0, ';
		l_sql := l_sql || '		MGR_SHOKIJ      MG3, ';
		l_sql := l_sql || '		MGR_KIHON2      BT3, ';
		l_sql := l_sql || '		MHAKKOTAI       M01, ';
		l_sql := l_sql || '		MGR_TESURYO_CTL MG7, ';
		l_sql := l_sql || '		MGR_TESURYO_PRM MG8 ';
		l_sql := l_sql || '	WHERE MG0.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD ';
		l_sql := l_sql || '	AND   MG0.MGR_CD = MG1.MGR_CD ';
		l_sql := l_sql || '	AND   MG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD ';
		l_sql := l_sql || '	AND   MG1.MGR_CD          = MG3.MGR_CD ';
		l_sql := l_sql || '	AND   MG1.ITAKU_KAISHA_CD = BT3.ITAKU_KAISHA_CD ';
		l_sql := l_sql || '	AND   MG1.MGR_CD          = BT3.MGR_CD ';
		l_sql := l_sql || '	AND   MG0.MASSHO_FLG = ''0''';
		l_sql := l_sql || '	AND   MG1.PARTMGR_KBN IN (''0'',''2'')'; --親銘柄を対象外
		l_sql := l_sql || '	AND   (MG1.PARTMGR_KBN IN (''0'',''1'') OR SUBSTR(MG1.YOBI3, 14, 1) = ''0'')'; --子銘柄（残高なし）を対象外
		l_sql := l_sql || '	AND   MG1.ITAKU_KAISHA_CD = ''' || l_initakuKaishaCd || ''' ';
		l_sql := l_sql || '	AND   MG0.MGR_STAT_KBN    =''' || pkipakknido.c_SHONIN() || ''' ';
		l_sql := l_sql || '	AND   MG1.JTK_KBN		   NOT IN (''2'',''5'') ';
		l_sql := l_sql || '	AND   MG1.KK_KANYO_FLG	  <> ''2'' ';	--実質記番号管理方式は対象外
		l_sql := l_sql || '	AND   MG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD ';
		l_sql := l_sql || '	AND   MG1.HKT_CD          = M01.HKT_CD ';
		l_sql := l_sql || '	AND   TRIM(MG1.ISIN_CD)   IS NOT NULL ';
		IF l_inrealbatchkbn = '1' OR l_inrealbatchkbn = '2' THEN	-- リアルの場合は徴求日の個別設定をしている銘柄も出力するため、この条件を入れない
			l_sql := l_sql || '	AND   MG3.TESUBILL_OUT_YMD = '' ''';
			l_sql := l_sql || '	AND   MG1.KKNBILL_OUT_TMG1    <> ''' || pkipakknido.c_NOT_SEIKYU_OUT()|| ''' ';
		END IF;
		IF l_inrealbatchkbn = '1' OR l_inrealbatchkbn = '2' THEN	-- バッチの場合、アップフロント銘柄を対象外とする。
			l_sql := l_sql || '	AND   BT3.UPFRONT_FLG = ''0'' ';
		END IF;
		l_sql := l_sql || '	AND   MG3.TESU_CHOKYU_YMD  <> '' ''';
		l_sql := l_sql || '	AND   MG3.SHOKAN_KBN  <> ''30''';
		-- 銘柄_手数料（制御情報）tblより、手数料種類-元金支払手数料が選択されている銘柄のみ対象とする
		l_sql := l_sql || '	AND   MG1.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD ';
		l_sql := l_sql || '	AND   MG1.MGR_CD = MG7.MGR_CD ';
		l_sql := l_sql || '	AND   MG7.TESU_SHURUI_CD = ''81'' ';
		l_sql := l_sql || '	AND   MG7.CHOOSE_FLG = ''1'' ';
		-- 銘柄_手数料（計算情報）tblより、元金支払手数料率（分母）>0の銘柄のみ対象とする（0除算エラー回避のため）
		l_sql := l_sql || '	AND   MG1.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD ';
		l_sql := l_sql || '	AND   MG1.MGR_CD = MG8.MGR_CD ';
		l_sql := l_sql || '	AND   MG8.GNKN_SHR_TESU_BUNBO > 0 ';

		  -- 基準日From〜Toの検索対象
		   -- 受入管理表　　　→手数料徴求日を検索
		IF l_insyoriflg = '1' THEN
			l_sql := l_sql || '	AND   MG3.TESU_CHOKYU_YMD BETWEEN ''' || l_inkjnfrom || ''' AND ''' || l_inkjnto  || '''';
		   -- その他（リアル）→手数料徴求日を検索
		ELSIF l_inrealbatchkbn = '0' THEN
			l_sql := l_sql || '	AND   MG3.TESU_CHOKYU_YMD BETWEEN ''' || l_inkjnfrom || ''' AND ''' || l_inkjnto  || '''';
			-- 地公体（バッチ）→手数料徴求日を検索
		ELSIF l_inrealbatchkbn = '2' THEN
			l_sql := l_sql || '	AND   MG3.TESU_CHOKYU_YMD BETWEEN ''' || l_inkjnfrom || ''' AND ''' || l_inkjnto  || '''';
			-- その他（バッチ）→償還期日を検索
		ELSE
			l_sql := l_sql || '	AND   MG3.SHOKAN_KJT BETWEEN ''' || l_inkjnfrom || ''' AND ''' || l_inkjnto  || '''';
		END IF;

		IF nullif(trim(both l_inhktcd), '')        IS NOT NULL THEN -- 発行体CD
			l_sql := l_sql || '	AND   MG1.HKT_CD          = ''' || l_inhktcd || ''' ';
		END IF;
		IF nullif(trim(both l_inkozatencd), '')    IS NOT NULL THEN -- 口座店CD
			l_sql := l_sql || '	AND   M01.KOZA_TEN_CD	  = ''' || l_inkozatencd || ''' ';
		END IF;
		IF nullif(trim(both l_inkozatencifcd), '') IS NOT NULL THEN -- 口座店CIFCD
			l_sql := l_sql || '	AND   M01.KOZA_TEN_CIFCD  = ''' || l_inkozatencifcd || ''' ';
		END IF;
		IF nullif(trim(both l_inmgrcd), '')        IS NOT NULL THEN -- 銘柄CD
			l_sql := l_sql || '	AND   MG1.MGR_CD          = ''' || l_inmgrcd || ''' ';
		END IF;
		IF nullif(trim(both l_inisincd), '')       IS NOT NULL THEN -- ISINCD
			l_sql := l_sql || '	AND   MG1.ISIN_CD         = ''' || l_inisincd || ''' ';
		END IF;

		-- 処理を追加
		-- バッチの場合、銘柄個別の請求書出力タイミングによる出力も行う
		-- （リアルの場合にはここは通さない）
		IF l_inrealbatchkbn = '1' OR l_inrealbatchkbn = '2' THEN

			l_sql := l_sql || '	UNION ';
			-- 利金
			l_sql := l_sql || '	SELECT ';
			l_sql := l_sql || '		VMG1.ITAKU_KAISHA_CD, ';
			l_sql := l_sql || '		VMG1.MGR_CD, ';
			l_sql := l_sql || '		MG2.RBR_KJT, ';
			l_sql := l_sql || '		MG2.KKN_CHOKYU_YMD AS CHOKYU_YMD ';
			l_sql := l_sql || '	FROM ';
			l_sql := l_sql || '		MGR_KIHON_VIEW  VMG1, ';
			l_sql := l_sql || '		MGR_RBRKIJ      MG2, ';
			l_sql := l_sql || '		MHAKKOTAI       M01 ';
			l_sql := l_sql || '	WHERE VMG1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD ';
			l_sql := l_sql || '	AND   VMG1.MGR_CD          = MG2.MGR_CD ';
			l_sql := l_sql || '	AND   VMG1.ITAKU_KAISHA_CD = ''' || l_initakuKaishaCd || ''' ';
			l_sql := l_sql || '	AND   VMG1.MGR_STAT_KBN    =''' || pkipakknido.c_SHONIN() || ''' ';
			l_sql := l_sql || '	AND   VMG1.JTK_KBN		   NOT IN (''2'',''5'') ';
			l_sql := l_sql || '	AND   VMG1.KK_KANYO_FLG	  <> ''2'' ';	--実質記番号管理方式は対象外
			l_sql := l_sql || '	AND   VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD ';
			l_sql := l_sql || '	AND   VMG1.HKT_CD          = M01.HKT_CD ';
			l_sql := l_sql || '	AND   MG2.KKNBILL_OUT_YMD ' || rSqlWhere;
			l_sql := l_sql || '	AND   VMG1.KKNBILL_OUT_TMG1    <> ''' || pkipakknido.c_NOT_SEIKYU_OUT()|| ''' ';
			l_sql := l_sql || '	AND   TRIM(VMG1.ISIN_CD)   IS NOT NULL ';

			IF nullif(trim(both l_inhktcd), '')        IS NOT NULL THEN -- 発行体CD
				l_sql := l_sql || '	AND   VMG1.HKT_CD          = ''' || l_inhktcd || ''' ';
			END IF;
			IF nullif(trim(both l_inkozatencd), '')    IS NOT NULL THEN -- 口座店CD
				l_sql := l_sql || '	AND   M01.KOZA_TEN_CD	  = ''' || l_inkozatencd || ''' ';
			END IF;
			IF nullif(trim(both l_inkozatencifcd), '') IS NOT NULL THEN -- 口座店CIFCD
				l_sql := l_sql || '	AND   M01.KOZA_TEN_CIFCD  = ''' || l_inkozatencifcd || ''' ';
			END IF;
			IF nullif(trim(both l_inmgrcd), '')        IS NOT NULL THEN -- 銘柄CD
				l_sql := l_sql || '	AND   VMG1.MGR_CD          = ''' || l_inmgrcd || ''' ';
			END IF;
			IF nullif(trim(both l_inisincd), '')       IS NOT NULL THEN -- ISINCD
				l_sql := l_sql || '	AND   VMG1.ISIN_CD         = ''' || l_inisincd || ''' ';
			END IF;

			l_sql := l_sql || '	UNION ';
			-- 利金手数料
			l_sql := l_sql || '	SELECT ';
			l_sql := l_sql || '		VMG1.ITAKU_KAISHA_CD, ';
			l_sql := l_sql || '		VMG1.MGR_CD, ';
			l_sql := l_sql || '		MG2.RBR_KJT, ';
			l_sql := l_sql || '		MG2.TESU_CHOKYU_YMD AS CHOKYU_YMD ';
			l_sql := l_sql || '	FROM ';
			l_sql := l_sql || '		MGR_KIHON_VIEW2  VMG1, ';
			l_sql := l_sql || '		MGR_RBRKIJ      MG2, ';
			l_sql := l_sql || '		MHAKKOTAI       M01, ';
			l_sql := l_sql || '		MGR_TESURYO_CTL MG7, ';
			l_sql := l_sql || '		MGR_TESURYO_PRM MG8 ';
			l_sql := l_sql || '	WHERE VMG1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD ';
			l_sql := l_sql || '	AND   VMG1.MGR_CD          = MG2.MGR_CD ';
			l_sql := l_sql || '	AND   VMG1.ITAKU_KAISHA_CD = ''' || l_initakuKaishaCd || ''' ';
			l_sql := l_sql || '	AND   VMG1.MGR_STAT_KBN    =''' || pkipakknido.c_SHONIN() || ''' ';
			l_sql := l_sql || '	AND   VMG1.JTK_KBN		   NOT IN (''2'',''5'') ';
			l_sql := l_sql || '	AND   VMG1.KK_KANYO_FLG	  <> ''2'' ';	--実質記番号管理方式は対象外
			l_sql := l_sql || '	AND   VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD ';
			l_sql := l_sql || '	AND   VMG1.HKT_CD          = M01.HKT_CD ';
			l_sql := l_sql || '	AND   MG2.TESUBILL_OUT_YMD ' || rSqlWhere;
    		IF l_inrealbatchkbn = '1' OR l_inrealbatchkbn = '2' THEN	-- バッチの場合、アップフロント銘柄を対象外とする。
    			l_sql := l_sql || '	AND   VMG1.UPFRONT_FLG = ''0'' ';
    		END IF;
			-- 銘柄_手数料（制御情報）tblより、手数料種類-利金支払手数料が選択されている銘柄のみ対象とする
			l_sql := l_sql || '	AND   VMG1.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD ';
			l_sql := l_sql || '	AND   VMG1.MGR_CD = MG7.MGR_CD ';
			l_sql := l_sql || '	AND   MG7.TESU_SHURUI_CD IN (''61'',''82'') ';
			l_sql := l_sql || '	AND   MG7.CHOOSE_FLG = ''1'' ';
			-- 銘柄_手数料（計算情報）tblより、利金支払手数料率（分母）>0の銘柄のみ対象とする（0除算エラー回避のため）
			l_sql := l_sql || '	AND   VMG1.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD ';
			l_sql := l_sql || '	AND   VMG1.MGR_CD = MG8.MGR_CD ';
			l_sql := l_sql || '	AND   MG8.RKN_SHR_TESU_BUNBO > 0 ';
			l_sql := l_sql || '	AND   VMG1.KKNBILL_OUT_TMG1    <> ''' || pkipakknido.c_NOT_SEIKYU_OUT()|| ''' ';
			l_sql := l_sql || '	AND   TRIM(VMG1.ISIN_CD)   IS NOT NULL ';

			IF nullif(trim(both l_inhktcd), '')        IS NOT NULL THEN -- 発行体CD
				l_sql := l_sql || '	AND   VMG1.HKT_CD          = ''' || l_inhktcd || ''' ';
			END IF;
			IF nullif(trim(both l_inkozatencd), '')    IS NOT NULL THEN -- 口座店CD
				l_sql := l_sql || '	AND   M01.KOZA_TEN_CD	  = ''' || l_inkozatencd || ''' ';
			END IF;
			IF nullif(trim(both l_inkozatencifcd), '') IS NOT NULL THEN -- 口座店CIFCD
				l_sql := l_sql || '	AND   M01.KOZA_TEN_CIFCD  = ''' || l_inkozatencifcd || ''' ';
			END IF;
			IF nullif(trim(both l_inmgrcd), '')        IS NOT NULL THEN -- 銘柄CD
				l_sql := l_sql || '	AND   VMG1.MGR_CD          = ''' || l_inmgrcd || ''' ';
			END IF;
			IF nullif(trim(both l_inisincd), '')       IS NOT NULL THEN -- ISINCD
				l_sql := l_sql || '	AND   VMG1.ISIN_CD         = ''' || l_inisincd || ''' ';
			END IF;

			l_sql := l_sql || '	UNION ';
			-- 元金
			l_sql := l_sql || '	SELECT ';
			l_sql := l_sql || '		VMG1.ITAKU_KAISHA_CD, ';
			l_sql := l_sql || '		VMG1.MGR_CD, ';
			l_sql := l_sql || '		MG3.SHOKAN_KJT     AS RBR_KJT, ';
			l_sql := l_sql || '		MG3.KKN_CHOKYU_YMD AS CHOKYU_YMD ';
			l_sql := l_sql || '	FROM ';
			l_sql := l_sql || '		MGR_KIHON_VIEW  VMG1, ';
			l_sql := l_sql || '		MGR_SHOKIJ      MG3, ';
			l_sql := l_sql || '		MHAKKOTAI       M01 ';
			l_sql := l_sql || '	WHERE VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD ';
			l_sql := l_sql || '	AND   VMG1.MGR_CD          = MG3.MGR_CD ';
			l_sql := l_sql || '	AND   VMG1.ITAKU_KAISHA_CD = ''' || l_initakuKaishaCd || ''' ';
			l_sql := l_sql || '	AND   VMG1.MGR_STAT_KBN    =''' || pkipakknido.c_SHONIN() || ''' ';
			l_sql := l_sql || '	AND   VMG1.JTK_KBN		   NOT IN (''2'',''5'') ';
			l_sql := l_sql || '	AND   VMG1.KK_KANYO_FLG	  <> ''2'' ';	--実質記番号管理方式は対象外
			l_sql := l_sql || '	AND   VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD ';
			l_sql := l_sql || '	AND   VMG1.HKT_CD          = M01.HKT_CD ';
			l_sql := l_sql || '	AND   MG3.KKNBILL_OUT_YMD ' || rSqlWhere;
			l_sql := l_sql || '	AND   MG3.SHOKAN_KBN  <> ''30''';
			l_sql := l_sql || '	AND   VMG1.KKNBILL_OUT_TMG1    <> ''' || pkipakknido.c_NOT_SEIKYU_OUT()|| ''' ';
			l_sql := l_sql || '	AND   TRIM(VMG1.ISIN_CD)   IS NOT NULL ';

			IF nullif(trim(both l_inhktcd), '')        IS NOT NULL THEN -- 発行体CD
				l_sql := l_sql || '	AND   VMG1.HKT_CD          = ''' || l_inhktcd || ''' ';
			END IF;
			IF nullif(trim(both l_inkozatencd), '')    IS NOT NULL THEN -- 口座店CD
				l_sql := l_sql || '	AND   M01.KOZA_TEN_CD	  = ''' || l_inkozatencd || ''' ';
			END IF;
			IF nullif(trim(both l_inkozatencifcd), '') IS NOT NULL THEN -- 口座店CIFCD
				l_sql := l_sql || '	AND   M01.KOZA_TEN_CIFCD  = ''' || l_inkozatencifcd || ''' ';
			END IF;
			IF nullif(trim(both l_inmgrcd), '')        IS NOT NULL THEN -- 銘柄CD
				l_sql := l_sql || '	AND   VMG1.MGR_CD          = ''' || l_inmgrcd || ''' ';
			END IF;
			IF nullif(trim(both l_inisincd), '')       IS NOT NULL THEN -- ISINCD
				l_sql := l_sql || '	AND   VMG1.ISIN_CD         = ''' || l_inisincd || ''' ';
			END IF;

			l_sql := l_sql || '	UNION ';
			-- 元金手数料
			l_sql := l_sql || '	SELECT ';
			l_sql := l_sql || '		VMG1.ITAKU_KAISHA_CD, ';
			l_sql := l_sql || '		VMG1.MGR_CD, ';
			l_sql := l_sql || '		MG3.SHOKAN_KJT      AS RBR_KJT, ';
			l_sql := l_sql || '		MG3.TESU_CHOKYU_YMD AS CHOKYU_YMD ';
			l_sql := l_sql || '	FROM ';
			l_sql := l_sql || '		MGR_KIHON_VIEW2  VMG1, ';
			l_sql := l_sql || '		MGR_SHOKIJ      MG3, ';
			l_sql := l_sql || '		MHAKKOTAI       M01, ';
			l_sql := l_sql || '		MGR_TESURYO_CTL MG7, ';
			l_sql := l_sql || '		MGR_TESURYO_PRM MG8 ';
			l_sql := l_sql || '	WHERE VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD ';
			l_sql := l_sql || '	AND   VMG1.MGR_CD          = MG3.MGR_CD ';
			l_sql := l_sql || '	AND   VMG1.ITAKU_KAISHA_CD = ''' || l_initakuKaishaCd || ''' ';
			l_sql := l_sql || '	AND   VMG1.MGR_STAT_KBN    =''' || pkipakknido.c_SHONIN() || ''' ';
			l_sql := l_sql || '	AND   VMG1.JTK_KBN		   NOT IN (''2'',''5'') ';
			l_sql := l_sql || '	AND   VMG1.KK_KANYO_FLG	  <> ''2'' ';	--実質記番号管理方式は対象外
			l_sql := l_sql || '	AND   VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD ';
			l_sql := l_sql || '	AND   VMG1.HKT_CD          = M01.HKT_CD ';
			l_sql := l_sql || '	AND   MG3.TESUBILL_OUT_YMD ' || rSqlWhere;
			l_sql := l_sql || '	AND   MG3.SHOKAN_KBN  <> ''30''';
    		IF l_inrealbatchkbn = '1' OR l_inrealbatchkbn = '2' THEN	-- バッチの場合、アップフロント銘柄を対象外とする。
    			l_sql := l_sql || '	AND   VMG1.UPFRONT_FLG = ''0'' ';
    		END IF;
			-- 銘柄_手数料（制御情報）tblより、手数料種類-元金支払手数料が選択されている銘柄のみ対象とする
			l_sql := l_sql || '	AND   VMG1.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD ';
			l_sql := l_sql || '	AND   VMG1.MGR_CD = MG7.MGR_CD ';
			l_sql := l_sql || '	AND   MG7.TESU_SHURUI_CD = ''81'' ';
			l_sql := l_sql || '	AND   MG7.CHOOSE_FLG = ''1'' ';
			-- 銘柄_手数料（計算情報）tblより、元金支払手数料率（分母）>0の銘柄のみ対象とする（0除算エラー回避のため）
			l_sql := l_sql || '	AND   VMG1.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD ';
			l_sql := l_sql || '	AND   VMG1.MGR_CD = MG8.MGR_CD ';
			l_sql := l_sql || '	AND   MG8.GNKN_SHR_TESU_BUNBO > 0 ';
			l_sql := l_sql || '	AND   VMG1.KKNBILL_OUT_TMG1    <> ''' || pkipakknido.c_NOT_SEIKYU_OUT()|| ''' ';
			l_sql := l_sql || '	AND   TRIM(VMG1.ISIN_CD)   IS NOT NULL ';

			IF nullif(trim(both l_inhktcd), '')        IS NOT NULL THEN -- 発行体CD
				l_sql := l_sql || '	AND   VMG1.HKT_CD          = ''' || l_inhktcd || ''' ';
			END IF;
			IF nullif(trim(both l_inkozatencd), '')    IS NOT NULL THEN -- 口座店CD
				l_sql := l_sql || '	AND   M01.KOZA_TEN_CD	  = ''' || l_inkozatencd || ''' ';
			END IF;
			IF nullif(trim(both l_inkozatencifcd), '') IS NOT NULL THEN -- 口座店CIFCD
				l_sql := l_sql || '	AND   M01.KOZA_TEN_CIFCD  = ''' || l_inkozatencifcd || ''' ';
			END IF;
			IF nullif(trim(both l_inmgrcd), '')        IS NOT NULL THEN -- 銘柄CD
				l_sql := l_sql || '	AND   VMG1.MGR_CD          = ''' || l_inmgrcd || ''' ';
			END IF;
			IF nullif(trim(both l_inisincd), '')       IS NOT NULL THEN -- ISINCD
				l_sql := l_sql || '	AND   VMG1.ISIN_CD         = ''' || l_inisincd || ''' ';
			END IF;

		END IF;

		RETURN l_sql;

	END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;
	/********************************************************************************
	 * 会計按分テーブルから指定銘柄コードのレコード件数を返す。
	 *
	 * @param l_initakukaishacd 委託会社コード
	 * @param l_inmgrcd         銘柄コード
	 * @return NUMERIC           レコード件数
	*********************************************************************************/
/*
CREATE OR REPLACE FUNCTION pkipakknido.getkaikeianbuncount ( l_initakukaishacd char(4) /*MGR_KIHON.ITAKU_KAISHA_CD%TYPE*/, l_inmgrcd varchar(13)/*MGR_KIHON.MGR_CD%TYPE*/ ) RETURNS bigint AS $body$
DECLARE

		gCnt              bigint  := 0;

BEGIN

		SELECT
			COUNT(*)
		INTO STRICT
			gCnt
		FROM
			KAIKEI_ANBUN
		WHERE
			ITAKU_KAISHA_CD = l_initakukaishacd
		AND	MGR_CD = l_inmgrcd
		AND	SHORI_KBN = '1'
		;

		RETURN gCnt;

	END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;
*/
	/********************************************************************************
	 * ユーザーIDからグループIDを返す。
	 *
	 * @param l_inUserId ユーザーID
	 * @return TEXT      グループID
	*********************************************************************************/
CREATE OR REPLACE FUNCTION pkipakknido.getgroupid ( l_inUserId SUSER.USER_ID%TYPE ) RETURNS char AS $body$
DECLARE

		gGroupId		SUSER.GROUP_ID%TYPE;

BEGIN

	IF l_inUserId = 'BATCH' THEN
		RETURN ' ';
	END IF;

		SELECT
			group_id
		INTO STRICT
			gGroupId
		FROM
			suser
		WHERE
			user_id = l_inUserId
		;
	RETURN gGroupId;

	END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;

	/********************************************************************************
	 * 帳票ワークテーブルに登録済の元利払基金手数料請求書/領収書の合計額を更新する
	 * @param l_inKeyCd			IN	識別コード（委託会社コード）
	 * @param l_inUserId		IN	ユーザＩＤ
	 * @param l_inChohyoKbn		IN	帳票区分
	 * @param l_inSakuseiYmd	IN	作成年月日
	 * @param l_inChohyoId1		IN	帳票ＩＤ(請求書)
	 * @param l_inChohyoId2		IN	帳票ＩＤ(領収書)
	 * @param l_outSqlCode		OUT	リターン値
	 * @param l_outSqlErrM		OUT	エラーコメント
	 * @return	なし
	*********************************************************************************/
CREATE OR REPLACE FUNCTION pkipakknido.updategnrseikyusho (
	l_inKeyCd SREPORT_WK.KEY_CD%TYPE,
	l_inUserId SREPORT_WK.USER_ID%TYPE,
	l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE,
	l_inSakuseiYmd SREPORT_WK.SAKUSEI_YMD%TYPE,
	l_inChohyoId1 SREPORT_WK.CHOHYO_ID%TYPE,
	l_inChohyoId2 SREPORT_WK.CHOHYO_ID%TYPE DEFAULT ' ',
	l_outSqlCode OUT integer,		-- リターン値
    l_outSqlErrM OUT text,	-- エラーコメント
	OUT extra_param int
) RETURNS record AS $body$
DECLARE

		/*==============================================================================*/

		/*					変数定義													*/

		/*==============================================================================*/

		returnCd		int;
		cnt				integer := 0;
		UtiSzei			numeric;
		nSeqNo			bigint;							-- 帳票連携キーID
		--インボイス用
		lOptionFlg		MOPTION_KANRI.OPTION_FLG%TYPE;	-- インボイスオプションフラグ
		gInvoiceTesuRitsu numeric := 0;
		gInvoiceTesuRitsuLabel varchar(50) := NULL;
		gInshizeiOptionFlg MOPTION_KANRI.OPTION_FLG%TYPE;	-- 印紙税オプションフラグ
		gStampTax		MSTAMP_TAX.STAMP_TAX%TYPE;		-- 印紙税額

		/*==============================================================================*/

		/*					ｶｰｿﾙ定義													*/

		/*==============================================================================*/

		curSum CURSOR FOR
			-- 合計値取得
			SELECT
				ITEM024,					-- 通貨
				ITEM014,					-- 支払日
				ITEM016,					-- 口座店
				ITEM002,					-- CIFコード
				ITEM071,					-- 請求書出力区分（レッドプロジェクトオプション用）
				ITEM015,					-- 口座振替区分
				ITEM003,					-- 発行体コード
				SUM(CASE WHEN nullif(trim(both ITEM044), '') IS NULL THEN  0  ELSE (ITEM044)::numeric  END ) AS GOKEI,		-- 手数料額合計
				SUM(CASE WHEN nullif(trim(both ITEM045), '') IS NULL THEN  0  ELSE (ITEM045)::numeric  END )	AS GOKEI_SZEI,	-- 内消費税額合計
				SUM(CASE WHEN nullif(trim(both ITEM074), '') IS NULL THEN  0  ELSE (ITEM074)::numeric  END )	AS GOKEI_SEIKYU,	-- 適格請求書_請求額合計
				SUM(CASE WHEN nullif(trim(both ITEM076), '') IS NULL THEN  0  ELSE (ITEM076)::numeric  END )	AS GOKEI_KKNTESUU,	-- 適格請求書_基金および手数料合計
				SUM(CASE WHEN nullif(trim(both ITEM075), '') IS NULL THEN  0  ELSE (ITEM075)::numeric  END )	AS GOKEI_TESUU,		-- 適格請求書_手数料合計
				SUM(CASE WHEN nullif(trim(both ITEM036), '') IS NULL THEN  0  ELSE (ITEM036)::numeric  END )	AS GOKEI_GANKIN,	-- 元金合計
				SUM(CASE WHEN nullif(trim(both ITEM037), '') IS NULL THEN  0  ELSE (ITEM037)::numeric  END )	AS GOKEI_RIKIN,		-- 利金合計
				SUM(CASE WHEN nullif(trim(both ITEM042), '') IS NULL THEN  0  ELSE (ITEM042)::numeric  END )	AS GOKEI_GNKNSHRTESUKNGK,	-- 元金支払手数料金額合計
				SUM(CASE WHEN nullif(trim(both ITEM043), '') IS NULL THEN  0  ELSE (ITEM043)::numeric  END )	AS GOKEI_RKNSHRTESUKNGK,	-- 利金支払手数料金額合計
				MAX(nullif(trim(both ITEM087), '')) AS KIJUNBI,	-- 消費税率適用基準日
				MAX(nullif(trim(both ITEM090), '')) AS SZEIKBN,	-- 消費税請求区分
				MAX(nullif(trim(both ITEM091), '')) AS TSUKA_CD, 	-- 発行通貨コード
				COUNT(*) AS KENSU	--出力件数
			FROM SREPORT_WK
			WHERE	KEY_CD = l_inKeyCd
				AND	USER_ID = trim(both l_inUserId)
				AND	CHOHYO_KBN = l_inChohyoKbn
				AND	SAKUSEI_YMD = l_inSakuseiYmd
				AND	CHOHYO_ID = l_inChohyoId1
				AND 	HEADER_FLG = '1'
				AND 	coalesce(ITEM048, ' ') != '対象データなし'
			GROUP BY
				ITEM024,
				ITEM014,
				ITEM016,
				ITEM002,
				ITEM071,
				ITEM015,
				ITEM003;

	/*==============================================================================*/

	/*					メイン														*/

	/*==============================================================================*/


BEGIN
		-- パラメータチェック
		IF nullif(trim(both l_inKeyCd), '') IS NULL
			OR nullif(trim(both l_inUserId), '') IS NULL
			OR nullif(trim(both l_inKeyCd), '') IS NULL
			OR nullif(trim(both l_inChohyoKbn), '') IS NULL
			OR nullif(trim(both l_inSakuseiYmd), '') IS NULL
			OR nullif(trim(both l_inChohyoId1), '') IS NULL THEN
			-- パラメータエラー
			returnCd	 := PKCONSTANT.ERROR();
			l_outSqlCode := PKCONSTANT.ERROR();
			l_outSqlErrM := 'パラメータエラー';
			CALL pkLog.error('ECM501', l_inChohyoId1, 'param error');
			extra_param := returnCd;
			RETURN;
		END IF;

		-- オプションフラグ取得
		lOptionFlg := pkControl.getOPTION_FLG(l_inKeyCd, 'INVOICE_A', '0');
		-- 印紙税オプション
		gInshizeiOptionFlg := pkControl.getOPTION_FLG(l_inKeyCd, 'INSHIZEI', '0');

		-- データ取得
		FOR recSum IN curSum LOOP
			cnt := cnt + 1;
           BEGIN
                SELECT
                   MAX(TRIM(ITEM069)) AS STAMP_TAX    -- 印紙税額
                INTO
                    gStampTax
                FROM SREPORT_WK
                WHERE   KEY_CD = l_inKeyCd
                   AND  USER_ID = TRIM(l_inUserId)
                   AND  CHOHYO_KBN = l_inChohyoKbn
                   AND  SAKUSEI_YMD = l_inSakuseiYmd
                   AND  CHOHYO_ID = l_inChohyoId2
                   AND  HEADER_FLG = '1'
                   AND  COALESCE(ITEM048, ' ') != '対象データなし'
                   AND  ITEM024 = recSum.ITEM024
                   AND  ITEM014 = recSum.ITEM014
                   AND  ITEM016 = recSum.ITEM016
                   AND  ITEM002 = recSum.ITEM002
                   AND  ITEM071 = recSum.ITEM071
                   AND  ITEM015 = recSum.ITEM015
                   AND  ITEM003 = recSum.ITEM003
                GROUP BY
                   ITEM024,
                   ITEM014,
                   ITEM016,
                   ITEM002,
                   ITEM071,
                   ITEM015,
                   ITEM003;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                   gStampTax := null;
            END;

			-- 割戻消費税算出
			IF lOptionFlg = '1' THEN
				IF nullif(trim(both recSum.SZEIKBN), '') = '1' THEN
					UtiSzei := PKIPACALCTESUKNGK.getTesuZeiWarimodoshi(nullif(trim(both recSum.KIJUNBI), ''),
																			recSum.GOKEI_TESUU,
																			recSum.TSUKA_CD);

					gInvoiceTesuRitsu := pkIpaZei.getShohiZeiRate(recSum.KIJUNBI);

					gInvoiceTesuRitsuLabel := '手数料（' || SUBSTRING('　' || TO_MULTI_BYTE(pkcharacter.numeric_to_char(gInvoiceTesuRitsu)), '.{2}$') || '％対象）';

					IF gInshizeiOptionFlg = '1' THEN
						IF recSum.TSUKA_CD = 'JPY' THEN
							--データあるの場合
							--印紙税額
							gStampTax := pkIpaStampTax.getStampTax(recSum.TSUKA_CD,	--通貨コード
																	recSum.GOKEI_GANKIN + recSum.GOKEI_RIKIN,	-- 元利基金合計
																	(recSum.GOKEI_GNKNSHRTESUKNGK + recSum.GOKEI_RKNSHRTESUKNGK) - UtiSzei	-- 元利金支払手数料金額合計
																	);
						ELSE
							gStampTax := NULL;
						END IF;
					END IF;
				ELSE
					UtiSzei := 0;
					gInvoiceTesuRitsu := NULL;
					gInvoiceTesuRitsuLabel := '手数料';
				END IF;
			END IF;

			-- 帳票ワーク更新
			UPDATE 	SREPORT_WK
			SET		ITEM046 = recSum.GOKEI,
					ITEM047 = recSum.GOKEI_SZEI,
					ITEM069 = CASE CHOHYO_ID  WHEN l_inChohyoId1 THEN  ITEM069  ELSE gStampTax::VARCHAR END,
					ITEM077 = recSum.GOKEI_SEIKYU,
					ITEM080 = recSum.GOKEI_KKNTESUU,
					ITEM082 = gInvoiceTesuRitsuLabel,
					ITEM083 = recSum.GOKEI_TESUU,
					ITEM085 = pkcharacter.numeric_to_char(UtiSzei),
					ITEM096 = pkcharacter.numeric_to_char(gInvoiceTesuRitsu),
					ITEM113 = recSum.GOKEI_GANKIN,
					ITEM114 = recSum.GOKEI_RIKIN,
					ITEM115 = recSum.GOKEI_GNKNSHRTESUKNGK + recSum.GOKEI_RKNSHRTESUKNGK,
					ITEM116 = recSum.GOKEI_SEIKYU,
					ITEM118 = recSum.KENSU
			WHERE	KEY_CD = l_inKeyCd
				AND	USER_ID = trim(both l_inUserId)
				AND	CHOHYO_KBN = l_inChohyoKbn
				AND	SAKUSEI_YMD = l_inSakuseiYmd
				AND	CHOHYO_ID IN (l_inChohyoId1, l_inChohyoId2)
				AND 	HEADER_FLG = '1'
				AND 	ITEM024 = recSum.ITEM024	-- 通貨コード
				AND 	ITEM014 = recSum.ITEM014	-- 支払日
				AND 	ITEM016 = recSum.ITEM016	-- 口座店コード
				AND 	ITEM002 = recSum.ITEM002	-- CIFコード
				AND 	ITEM071 = recSum.ITEM071	-- 請求書出力区分（レッドプロジェクトオプション用）
				AND 	ITEM015 = recSum.ITEM015	-- 口座振替区分
				AND 	ITEM003 = recSum.ITEM003;	-- 発行体コード
		END LOOP;
		IF cnt = 0 THEN
			CALL pkLog.debug(l_inUserId, l_inChohyoId1, '帳票ワークテーブルに該当データがありません。');
			CALL pkLog.debug(l_inUserId, l_inChohyoId1, '委託会社コード ' || l_inKeyCd);
			CALL pkLog.debug(l_inUserId, l_inChohyoId1, 'ユーザＩＤ ' || l_inUserId);
			CALL pkLog.debug(l_inUserId, l_inChohyoId1, '帳票区分 ' || l_inChohyoKbn);
			CALL pkLog.debug(l_inUserId, l_inChohyoId1, '作成年月日 ' || l_inSakuseiYmd);
			CALL pkLog.debug(l_inUserId, l_inChohyoId1, '帳票ＩＤ1 ' || l_inChohyoId1);
			CALL pkLog.debug(l_inUserId, l_inChohyoId2, '帳票ＩＤ2 ' || l_inChohyoId2);
		ELSE
			--オプションフラグ取得
			lOptionFlg := pkControl.getOPTION_FLG(l_inKeyCd, 'INVOICE_A', '0');

			IF lOptionFlg = '1' THEN
				/* CSVジャーナルINSERT */

				returnCd := pkCsvJournal.insertData(
							l_inKeyCd					-- 委託会社コード
							,trim(both l_inUserId)			-- ユーザＩＤ
							,l_inChohyoKbn				-- 帳票区分
							,l_inSakuseiYmd				-- 処理日時
							,l_inChohyoId1				-- 帳票ＩＤ
							);
			END IF;
		END IF;

		-- 終了処理
		returnCd	 := PKCONSTANT.SUCCESS();
		l_outSqlCode := PKCONSTANT.SUCCESS();
		l_outSqlErrM := '';

		-- 返値を返す
		extra_param := returnCd;
		RETURN;

	-- エラー処理
	EXCEPTION
		WHEN	OTHERS	THEN
			returnCd 	 := PKCONSTANT.FATAL();

			l_outSqlCode := PKCONSTANT.FATAL();
			l_outSqlErrM := SQLERRM;
			CALL pkLog.fatal('ECM701', l_inChohyoId1, 'SQLCODE:'||SQLSTATE);
			CALL pkLog.fatal('ECM701', l_inChohyoId1, 'SQLERRM:'||SQLERRM);

		extra_param := returnCd;

		RETURN;

	END;

	/********************************************************************************
	 * 基金請求計算後、請求書出力処理を実行する。
	 *
	 * @param inDataSakuseiKbn データ作成区分
	 * @return INTEGER 0:正常、99:異常、それ以外：エラー
	*********************************************************************************/
$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;

CREATE OR REPLACE FUNCTION pkipakknido.inskikinidoseikyuout (
 l_inUserId text ,      -- ユーザID
 l_inGyomuYmd text ,             -- 業務日付
 l_inKjnFrom text ,              -- 基準日From
 l_inKjnTo text ,                -- 基準日To
 l_inItakuKaishaCd text ,    -- 委託会社CD
 l_inKknZndkKjnYmdKbn text,  -- 基金残高基準日区分
 l_inHktCd text ,                -- 発行体CD
 l_inKozatenCd text ,        -- 口座店CD
 l_inKozatenCifCd text ,     -- 口座店CIFCD
 l_inMgrCd text ,                -- 銘柄CD
 l_inIsinCd text ,               -- ISINCDd
 l_inTsuchiYmd text ,            -- 通知日
 l_inSeikyushoId text,       -- 請求書ID
 l_inRealBatchKbn text,          -- リアルバッチ区分
 l_inDataSakuseiKbn text,--データ作成区分
 l_inSeikyuIchiranKbn text,      -- 請求書一覧区分
 l_inChikoFlg text,				-- 地公体利用フラグ
 l_inFrontFlg text,			-- フロント照会画面判別フラグ
 l_OutSqlCode OUT INTEGER,         -- SQLエラーコード
 l_OutSqlErrM OUT text          -- SQLエラーメッセージ
 , OUT extra_param integer) RETURNS record AS $body$
DECLARE
		rec pkipakknido.recType[];   --システム設定分と個別設定分を取得するカーソルのレコード
						--システム設定分と個別設定分を取得するカーソルタイプ
		--pCur REFCURSOR;	--システム設定分と個別設定分を取得するカーソル
		pCurSql                     varchar(10000) := NULL;
		pCurRec		record;

		pReturnCode integer := 0;
		pRowCnt     integer := 0;
		intMax      integer := 0;

		WK_GNR_TESU_ID char(11) := NULL;    -- バッチの時、作票対象データのキーを帳票WKへ退避しておくための帳票ID
		--gWrkTsuchiYmd		VARCHAR(16) DEFAULT NULL;					-- 通知日(和暦)
		pRbrYmdFrom char(8) := '99999999';     -- 徴求日 From
		pRbrYmdTo   char(8) := '00000000';     -- 徴求日 To
		pHeizonSeikyuKbn	char(1) := '';		-- 自行委託ビュー.併存銘柄請求区分
		optionFlg   MOPTION_KANRI.OPTION_FLG%TYPE := '0';  -- オプションフラグ
		DEBUG smallint := 1;

		temp_rItakuKaishaCd char(4);
		temp_rMgrCd varchar(13);
		temp_rRbrKjt char(8);
		temp_rChokyuYmd char(8);

		l_inItem 	   		TYPE_SREPORT_WK_ITEM;
BEGIN

	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inUserId : ' || l_inUserId ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inGyomuYmd : ' || l_inGyomuYmd ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inKjnFrom : ' || l_inKjnFrom ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inKjnTo : ' || l_inKjnTo ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inItakuKaishaCd : ' || l_inItakuKaishaCd ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inKknZndkKjnYmdKbn : ' || l_inKknZndkKjnYmdKbn ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inHktCd : ' || l_inHktCd ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inKozatenCd : ' || l_inKozatenCd ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inKozatenCifCd : ' || l_inKozatenCifCd ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inMgrCd : ' || l_inMgrCd ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inIsinCd : ' || l_inIsinCd ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inTsuchiYmd : ' || l_inTsuchiYmd ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inSeikyushoId : ' || l_inSeikyushoId ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inRealBatchKbn : ' || l_inRealBatchKbn ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inDataSakuseiKbn : ' || l_inDataSakuseiKbn ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inSeikyuIchiranKbn : ' || l_inSeikyuIchiranKbn ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inChikoFlg : ' || l_inChikoFlg ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_OutSqlCode : ' || l_OutSqlCode ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_OutSqlErrM : ' || l_OutSqlErrM ); END IF;


	 -- RAISE NOTICE 'xxx引数 l_inUserId : %' ,l_inUserId;
	 -- RAISE NOTICE '引数 l_inGyomuYmd : %' ,l_inGyomuYmd;
	 -- RAISE NOTICE '引数 l_inKjnFrom : %' ,l_inKjnFrom;
	 -- RAISE NOTICE '引数 l_inKjnTo : %' ,l_inKjnTo;
	 -- RAISE NOTICE '引数 l_inItakuKaishaCd : %' ,l_inItakuKaishaCd;
	 -- RAISE NOTICE '引数 l_inKknZndkKjnYmdKbn : %' ,l_inKknZndkKjnYmdKbn;
	 -- RAISE NOTICE '引数 l_inHktCd : %' ,l_inHktCd;
	 -- RAISE NOTICE '引数 l_inKozatenCd : %' ,l_inKozatenCd;
	 -- RAISE NOTICE '引数 l_inKozatenCifCd : %' ,l_inKozatenCifCd;
	 -- RAISE NOTICE '引数 l_inMgrCd : %' ,l_inMgrCd;
	 -- RAISE NOTICE '引数 l_inIsinCd : %' ,l_inIsinCd;
	 -- RAISE NOTICE '引数 l_inTsuchiYmd : %' ,l_inTsuchiYmd;
	 -- RAISE NOTICE '引数 l_inSeikyushoId : %' ,l_inSeikyushoId;
	 -- RAISE NOTICE '引数 l_inRealBatchKbn : %' ,l_inRealBatchKbn;
	 -- RAISE NOTICE '引数 l_inDataSakuseiKbn : %' ,l_inDataSakuseiKbn;
	 -- RAISE NOTICE '引数 l_inSeikyuIchiranKbn : %' ,l_inSeikyuIchiranKbn;
	 -- RAISE NOTICE '引数 l_inChikoFlg : %' ,l_inChikoFlg;
	 -- RAISE NOTICE '引数 l_inFrontFlg : %', l_inFrontFlg;

	--カーソルの作成    抽出条件に該当するレコードを基金移動テーブルに更新する
	pCurSql := pkipakknido.createsql(l_ingyomuymd,l_inkjnfrom,l_inkjnto,l_initakukaishacd,l_inhktcd,l_inkozatencd,l_inkozatencifcd,l_inmgrcd,l_inisincd,l_inrealbatchkbn,l_inseikyuichirankbn,'0');
		-- 併存銘柄請求区分取得
		SELECT HEIZON_SEIKYU_KBN INTO STRICT pHeizonSeikyuKbn FROM VJIKO_ITAKU WHERE KAIIN_ID = l_inItakuKaishaCd;

		--TEST_DEBUG_LOG('TEST',pCurSql);
		FOR pCurRec IN EXECUTE pCurSql
		LOOP
			-- FETCH pCur INTO
			-- 	temp_rItakuKaishaCd,
			-- 	temp_rMgrCd,
			-- 	temp_rRbrKjt,
			-- 	temp_rChokyuYmd;

			-- EXIT WHEN NOT FOUND; /* apply on pCur */

			rec[pRowCnt].rItakuKaishaCd := pCurRec.ITAKU_KAISHA_CD;
			rec[pRowCnt].rMgrCd := pCurRec.MGR_CD;
			rec[pRowCnt].rRbrKjt := pCurRec.RBR_KJT;
			rec[pRowCnt].rChokyuYmd := pCurRec.CHOKYU_YMD;

			 -- RAISE NOTICE 'in loop, l_inFrontFlg: %, pCurRec.CHOKYU_YMD: %, pHeizonSeikyuKbn: %', l_inFrontFlg, pCurRec.CHOKYU_YMD, pHeizonSeikyuKbn;
			 -- RAISE NOTICE 'rec[pRowCnt].rItakuKaishaCd: %', rec[pRowCnt].rItakuKaishaCd;
			 -- RAISE NOTICE 'rec[pRowCnt].rMgrCd: %', rec[pRowCnt].rMgrCd;
			 -- RAISE NOTICE 'rec[pRowCnt].rChokyuYmd: %', rec[pRowCnt].rChokyuYmd;


			-- フロント照会帳票出力指示以外からcallされた場合、基金異動計算・更新処理を行う。
			IF l_inFrontFlg = '0' THEN

				-- 併存銘柄請求区分='0'(出力しない) かつ、併存銘柄(実質残高(現登債)と実質残高(振替債)が両方0円ではない)場合は
				-- 計算および基金異動テーブル更新処理を行わない
				IF NOT(pHeizonSeikyuKbn = '0'
					AND (PKIPAZNDK.getKjnZndk(rec[pRowCnt].rItakuKaishaCd,rec[pRowCnt].rMgrCd,rec[pRowCnt].rChokyuYmd,3))::numeric  > 0			-- 振替債実質残高
					AND (PKIPAZNDK.getKjnZndk(rec[pRowCnt].rItakuKaishaCd,rec[pRowCnt].rMgrCd,rec[pRowCnt].rChokyuYmd,83))::numeric  > 0) THEN	-- 現登債実質残高

					-- 地行体帳票を出力した場合は地行体銘柄のみ基金異動履歴にデータを作成するための対応
					-- 自行情報マスタ.地公体フラグがONかつ公社債元利金支払基金請求書or公債会計別元利金明細表かつ会計按分テーブルにデータがある場合、
					-- または、自行情報マスタ.地公体フラグがONかつ元利払基金・手数料請求書or元利払基金・手数料請求明細書かつ会計按分テーブルにデータがない場合、
					-- または、自行情報マスタ.地公体フラグがONかつ元利払基金・手数料請求一覧表の場合、
					-- または、自行情報マスタ.地公体フラグがOFFの場合に基金異動履歴更新処理を行う。
					IF (l_inChikoFlg = '1' AND (l_inSeikyushoId = pkIpaKknIdo.c_SEIKYU_KAIKEIKUBUN()
												OR l_inSeikyushoId = pkIpaKknIdo.c_GANRI_MEISAI()
												OR l_inSeikyushoId = pkIpaKknIdo.c_GANRI_MEISAI_M())
						AND pkipakknido.getkaikeianbuncount(rec[pRowCnt].rItakuKaishaCd, rec[pRowCnt].rMgrCd) > 0)
					OR (l_inChikoFlg = '1' AND (l_inSeikyushoId = pkIpaKknIdo.c_SEIKYU() OR l_inSeikyushoId = pkIpaKknIdo.c_SEIKYU_MEISAI())
						AND pkipakknido.getkaikeianbuncount(rec[pRowCnt].rItakuKaishaCd, rec[pRowCnt].rMgrCd) = 0)
					OR (l_inChikoFlg = '1' AND l_inSeikyushoId = pkIpaKknIdo.c_SEIKYU_ICHIRAN())
					OR (l_inChikoFlg = '0') THEN
						-- 基金異動計算・更新処理
						-- リアル・バッチ区分は「0」（リアル）「1」（バッチ）
						pReturnCode := sfInsKikinIdo(
												pkConstant.BATCH_USER(),
												rec[pRowCnt].rItakuKaishaCd,
												rec[pRowCnt].rMgrCd,
												rec[pRowCnt].rRbrKjt,
												rec[pRowCnt].rChokyuYmd,
													l_indatasakuseikbn,
													l_inrealbatchkbn,
													l_inKknZndkKjnYmdKbn);
					END IF;			END IF;

			IF pReturnCode <> 0 THEN
				l_OutSqlCode := pReturnCode;
				l_OutSqlErrM := '基金請求計算処理（データ作成区分'||l_indatasakuseikbn||'）が失敗しました。';
				CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlErrM);
				extra_param := pReturnCode;
				RETURN;
			END IF;				-- 自行情報マスタ.地公体フラグがONかつ会計按分テーブルにデータがある場合
				-- 会計区分別基金請求計算SPを呼び出す。
				IF l_inChikoFlg = '1' THEN
					IF pkipakknido.getkaikeianbuncount(rec[pRowCnt].rItakuKaishaCd, rec[pRowCnt].rMgrCd) > 0 THEN
						pReturnCode := sfIph999_KIKIN_IDO_KAIKEI(rec[pRowCnt].rItakuKaishaCd,
																rec[pRowCnt].rMgrCd,
																rec[pRowCnt].rRbrKjt,
																rec[pRowCnt].rChokyuYmd,
																l_inuserid,
																pkipakknido.getgroupid(l_inuserid));
						IF pReturnCode <> 0 THEN
							l_OutSqlCode := pReturnCode;
							l_OutSqlErrM := '会計区分別基金請求計算処理（データ作成区分'||l_indatasakuseikbn||'）が失敗しました。';
							CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlErrM);
							extra_param := pReturnCode;
							RETURN;
						END IF;
					END IF;
				END IF;
			END IF;


		pRowCnt := pRowCnt + 1;

	END LOOP;
	-- バッチの場合、作票SPに渡す条件の加工を行う
	-- （ここで抽出したデータを、キーとして帳票WKに退避）
		IF l_inRealBatchKbn = '1' then
			 -- RAISE NOTICE 'IF l_inRealBatchKbn = 1 then';

			WK_GNR_TESU_ID := 'WK' || SUBSTR(l_inSeikyushoId, 3, 9);    -- 作票対象データを仮登録しておく帳票WKの帳票ID
			-- 帳票WKに残っているかもしれない仮データをDELETE
			DELETE FROM SREPORT_WK
				WHERE CHOHYO_ID = WK_GNR_TESU_ID;

			intMax := pRowCnt - 1;
			pRowCnt := 0;
			FOR pRowCnt IN 0..intMax LOOP
				l_inItem := ROW();
				l_inItem.l_inItem001 := rec[pRowCnt].rMgrCd;					-- 銘柄コード
				l_inItem.l_inItem002 := rec[pRowCnt].rRbrKjt;					-- 利払期日
				l_inItem.l_inItem003 := rec[pRowCnt].rChokyuYmd;				-- 徴求日

				CALL pkPrint.insertData(
					 l_inkeyCd         =>    rec[pRowCnt].rItakuKaishaCd     -- 識別コード
					,l_inUserId        =>    l_inUserId                      -- ユーザID
					,l_inChohyoKbn     =>    l_inRealBatchKbn                -- 帳票区分
					,l_inSakuseiYmd    =>    l_inGyomuYmd                    -- 作成年月日
					,l_inChohyoId      =>    WK_GNR_TESU_ID                  -- WK帳票ID
					,l_inSeqNo         =>    pRowCnt                         -- SEQNO
					,l_inHeaderFlg     =>    '1'                             -- ヘッダフラグ
					,l_inItem		   =>	 l_inItem
					,l_inKousinId      =>    l_inUserId                      -- 更新者ID
					,l_inSakuseiId     =>    l_inUserId                      -- 作成者ID
				);

			END LOOP;

		END IF;

		 -- RAISE NOTICE '実質記番号オプション用処理 START';

		----- 実質記番号オプション用処理 START
		BEGIN
			SELECT OPTION_FLG
			INTO STRICT  optionFlg
			FROM  MOPTION_KANRI
			WHERE KEY_CD = l_inItakuKaishaCd
			AND   OPTION_CD = 'IPP1003302010';
		EXCEPTION
			WHEN no_data_found THEN
				optionFlg := 0;
		END;

		-- フロント照会帳票出力指示以外からcallされた場合、基金異動計算・更新処理を行う。
		IF l_inFrontFlg = '0' THEN
			IF optionFlg = 1 THEN
				-- 実質記番号管理オプション　基金異動計算・更新処理
				pReturnCode := pkIpaKibango.insKknIdo(  l_inUserId,
														l_inKjnFrom,
														l_inKjnTo,
														l_inItakuKaishaCd,
														l_inHktCd,
														l_inKozatenCd,
														l_inKozatenCifCd,
														l_inMgrCd,
														l_inIsinCd,
														l_inSeikyushoId,
														l_inRealBatchKbn,
														l_inDataSakuseiKbn,
														l_inKknZndkKjnYmdKbn,
														l_OutSqlErrM);
				IF pReturnCode <> 0 THEN
					l_OutSqlCode := pReturnCode;
					CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlErrM);
					extra_param := pReturnCode;
					RETURN;
				END IF;
			END IF;
			----- 実質記番号オプション用処理 END
		END IF;

		-- バッチの場合は、基準日From、Toに、MIN値、MAX値をセット
		IF l_inRealBatchKbn = '1' THEN
			pRbrYmdFrom := '00000000';
			pRbrYmdTo   := '99999999';
		ELSE
			pRbrYmdFrom	:= l_inKjnFrom;
			pRbrYmdTo	:= l_inKjnTo;
		END IF;

		 -- RAISE NOTICE 'IP030004511　帳票　元利払基金・手数料請求一覧表';

		-- IP030004511　帳票　元利払基金・手数料請求一覧表
		IF l_inseikyushoid = pkipakknido.c_SEIKYU_ICHIRAN() THEN
			 -- RAISE NOTICE 'in 元利払基金・手数料請求一覧表を作成する';

			-- 元利払基金・手数料請求一覧表を作成する
			IF pkControl.getCtlValue(l_inItakuKaishaCd, 'pkIpaKknIdo1', '0') = '1' THEN
				 -- RAISE NOTICE 'calling spIp04501_02';

				 CALL spIp04501_02(
					l_inSeikyushoId,   -- 帳票ID
					l_inItakuKaishaCd, -- 委託会社コード
					pRbrYmdFrom,       -- 基準日(From)
					pRbrYmdTo,         -- 基準日(To)
					l_inGyomuYmd,      -- 業務日付
					'1',                 -- 初回レコード区分
					l_inUserId ,       -- ユーザーID
					l_inRealBatchKbn,  -- 帳票区分
					l_OutSqlCode,      -- リターン値
					l_OutSqlErrM       -- エラーコメント
				);
			ELSE
				 -- RAISE NOTICE 'calling spIp04501_01';
				 CALL spIp04501_01(
					l_inSeikyushoId,   -- 帳票ID
					l_inItakuKaishaCd, -- 委託会社コード
					pRbrYmdFrom,       -- 基準日(From)
					pRbrYmdTo,         -- 基準日(To)
					l_inGyomuYmd,      -- 業務日付
					'1',                 -- 初回レコード区分
					l_inUserId ,       -- ユーザーID
					l_inRealBatchKbn,  -- 帳票区分
					l_OutSqlCode,      -- リターン値
					l_OutSqlErrM       -- エラーコメント
				);
			END IF;

			 -- RAISE NOTICE 'calling spIp04501_01 or spIp04502_01 completed';

			-- 戻り値が２の場合は0にする
			IF coalesce(l_OutSqlCode,0) = 2 THEN
				-- ２：帳票データなしだけど、正常終了
				l_OutSqlCode := 0;
			END IF;

			-- 戻り値チェック(エラーの場合はすぐに戻る)
			IF coalesce(l_OutSqlCode,0) <> 0 THEN
				CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlCode);
				CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlErrM);
				extra_param := l_OutSqlCode;

				 -- RAISE NOTICE '戻り値チェック(エラーの場合はすぐに戻る) l_OutSqlErrM: %', l_OutSqlErrM;
				RETURN;
			END IF;

		END IF;


		-- IP030004631　帳票　元利払基金・手数料請求書(領収書)
		IF l_inseikyushoid = pkipakknido.c_seikyu() THEN

			-- 元利払基金・手数料請求書(領収書)を作成する
			IF pkControl.getCtlValue(l_inItakuKaishaCd, 'pkIpaKknIdo1', '0') = '1' THEN
				 -- RAISE NOTICE 'calling spipi046k00r02';

				 CALL spipi046k00r02(
					l_inSeikyushoId,   -- 帳票ID
					l_inItakuKaishaCd, -- 委託会社コード
					pRbrYmdFrom,       -- 基準日(From)
					pRbrYmdTo,         -- 基準日(To)
					l_inGyomuYmd,      -- 業務日付
					'1',                 -- 初回レコード区分
					l_inUserId,        -- ユーザーID
					l_inRealBatchKbn,  -- 帳票区分
					l_inHktCd,         -- 発行体コード
					l_inKozatenCd,     -- 口座店コード
					l_inKozatenCifCd,  -- 口座店CIFコード
					l_inMgrCd,         -- 銘柄コード
					l_inIsinCd,        -- ISINコード
					l_inTsuchiYmd,     -- 通知日
					l_outSqlCode,      -- リターン値
					l_outSqlErrM       -- エラーコメント
				);
			ELSE
				 -- RAISE NOTICE 'calling spipi046k00r01';

				 CALL spipi046k00r01(
					l_inSeikyushoId,   -- 帳票ID
					l_inItakuKaishaCd, -- 委託会社コード
					pRbrYmdFrom,       -- 基準日(From)
					pRbrYmdTo,         -- 基準日(To)
					l_inGyomuYmd,      -- 業務日付
					'1',                 -- 初回レコード区分
					l_inUserId,        -- ユーザーID
					l_inRealBatchKbn,  -- 帳票区分
					l_inHktCd,         -- 発行体コード
					l_inKozatenCd,     -- 口座店コード
					l_inKozatenCifCd,  -- 口座店CIFコード
					l_inMgrCd,         -- 銘柄コード
					l_inIsinCd,        -- ISINコード
					l_inTsuchiYmd,     -- 通知日
					l_outSqlCode,      -- リターン値
					l_outSqlErrM       -- エラーコメント
				);
			END IF;

			-- 戻り値が２の場合は0にする
			IF coalesce(l_OutSqlCode,0) = 2 THEN
				-- ２：帳票データなしだけど、正常終了
				l_OutSqlCode := 0;

			END IF;

			-- 戻り値チェック(エラーの場合はすぐに戻る)
			IF coalesce(l_OutSqlCode,0) <> 0 THEN

				CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlCode);
				CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlErrM);
				extra_param := l_OutSqlCode;

				 -- RAISE NOTICE 'calling spipi046k00r01 completed with errors: %', l_OutSqlErrM;

				RETURN;

			END IF;

		END IF;

		-- IP030010211　帳票　元利払基金・手数料請求明細書
		IF l_inseikyushoid = pkipakknido.c_SEIKYU_MEISAI() THEN
			 -- RAISE NOTICE 'calling SPIPI046K00R03';

			-- 元利払基金・手数料請求明細書を作成する
			 CALL SPIPI046K00R03(
				l_inSeikyushoId,   -- 帳票ID
				l_inItakuKaishaCd, -- 委託会社コード
				pRbrYmdFrom,       -- 基準日(From)
				pRbrYmdTo,         -- 基準日(To)
				l_inGyomuYmd,      -- 業務日付
				'1',                 -- 初回レコード区分
				l_inUserId,        -- ユーザーID
				l_inRealBatchKbn,  -- 帳票区分
				l_inHktCd,         -- 発行体コード
				l_inKozatenCd,     -- 口座店コード
				l_inKozatenCifCd,  -- 口座店CIFコード
				l_inMgrCd,         -- 銘柄コード
				l_inIsinCd,        -- ISINコード
				l_inTsuchiYmd,     -- 通知日
				l_outSqlCode,      -- リターン値
				l_outSqlErrM       -- エラーコメント
			);

			-- 戻り値が２の場合は0にする
			IF coalesce(l_OutSqlCode,0) = 2 THEN
				-- ２：帳票データなしだけど、正常終了
				l_OutSqlCode := 0;

			END IF;

			-- 戻り値チェック(エラーの場合はすぐに戻る)
			IF coalesce(l_OutSqlCode,0) <> 0 THEN

				CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlCode);
				CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlErrM);
				extra_param := l_OutSqlCode;
				RETURN;

			END IF;

		END IF;

		-- 地公体オプション帳票出力
		-- 地公体帳票は画面の入力条件により１回だけ呼び出す
		-- 元利払基金・手数料請求書(会計区分別)の場合
		IF l_inseikyushoid = pkipakknido.c_SEIKYU_KAIKEIKUBUN() THEN
			CALL SPIPH005K00R01(	 '0'							-- 帳票作成区分には0を指定
							,l_inhktcd 						-- 発行体コード
							,l_inkozatencd 					-- 口座店コード
							,l_inkozatencifcd 				-- 口座店CIFコード
							,l_inmgrcd 						-- 銘柄コード
							,l_inisincd 						-- ISINコード
							,l_inkjnfrom 					-- 基準日(FROM)
							,l_inkjnto 						-- 基準日(TO)
							,l_inTsuchiYmd 					-- 通知日
							,l_initakukaishacd 				-- 委託会社コード
							,l_inuserid 						-- ユーザーID
							,l_inrealbatchkbn 				-- 帳票区分
							,l_ingyomuymd 					-- 業務日付
							,l_OutSqlCode 					-- リターン値
							,l_OutSqlErrM 					-- エラーコメント
						);
		-- 公債会計別元利金明細表の場合
		ELSIF l_inseikyushoid = pkipakknido.c_GANRI_MEISAI() THEN
			CALL SPIPH006K00R01(	 l_inhktcd 						-- 発行体コード
							,l_inkozatencd 					-- 口座店コード
							,l_inkozatencifcd 				-- 口座店ＣＩＦコード
							,l_inmgrcd 						-- 銘柄コード
							,l_inisincd 						-- ISINコード
							,l_inkjnfrom 					-- 基準日From
							,l_inkjnto 						-- 基準日To
							,l_inTsuchiYmd 					-- 通知日
							,l_initakukaishacd 				-- 委託会社コード
							,l_inuserid 						-- ユーザーID
							,l_inrealbatchkbn 				-- 帳票区分
							,l_ingyomuymd 					-- 業務日付
							,l_OutSqlCode 					-- リターン値
							,l_OutSqlErrM 					-- エラーコメント
						);
		END IF;

        -- 戻り値が２の場合は0にする
        IF coalesce(l_OutSqlCode,0) = 2 THEN
            -- ２：帳票データなしだけど、正常終了
            l_OutSqlCode := 0;

        END IF;

		IF coalesce(l_OutSqlCode,0) <> 0 THEN
			CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlCode);
			CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlErrM);

			 -- RAISE NOTICE '戻り値が２の場合は0にする terminated 1: %', l_OutSqlErrM;

			extra_param := l_OutSqlCode;
			RETURN;
		END IF;

		-- 請求書の場合
        IF l_inseikyushoid = pkipakknido.c_seikyu() THEN
        	-- 帳票ワークテーブルの手数料額合計、消費税額合計を更新する。
            SELECT *
            INTO
				l_OutSqlCode, 			-- リターン値
				l_OutSqlErrM			-- エラーコメント
			FROM pkipakknido.updategnrseikyusho(
				l_inItakuKaishaCd, 		-- 委託会社コード
				l_inUserId, 				-- ユーザーID
				l_inrealbatchkbn, 		-- 帳票区分
				l_ingyomuymd, 			-- 業務日付
				pkipakknido.c_seikyu(), -- 請求書帳票ID
				pkipakknido.c_ryoshu()  -- 領収書帳票ID
			);
		END IF;

            -- 戻り値が２の場合は0にする
            IF coalesce(l_OutSqlCode,0) = 2 THEN
                -- ２：帳票データなしだけど、正常終了
                l_OutSqlCode := 0;

            END IF;

            -- 戻り値チェック(エラーの場合はすぐに戻る)
    		IF coalesce(l_OutSqlCode,0) <> 0 THEN
	   		CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlCode);
			CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlErrM);

			 -- RAISE NOTICE '戻り値チェック(エラーの場合はすぐに戻る) terminate: %', l_OutSqlErrM;

			extra_param := pReturnCode;
			RETURN;
		END IF;

        -- 作票処理（子SPで）が終了したため、帳票WKの仮データDELETE
        IF l_inRealBatchKbn = '1' then
            DELETE FROM SREPORT_WK
            WHERE CHOHYO_ID = WK_GNR_TESU_ID;
        END IF;

    extra_param := PKCONSTANT.SUCCESS();

     -- RAISE NOTICE 'end of insKikinIdoSeikyuOut';

    RETURN;

    -- エラー処理
    EXCEPTION
	WHEN	OTHERS	THEN
        l_OutSqlCode := SQLSTATE;
        l_OutSqlErrM := SQLERRM;
		CALL pkLog.fatal('ECM701', 'PKIPAKKNIDO', 'SQLCODE:'||l_OutSqlCode);
		CALL pkLog.fatal('ECM701', 'PKIPAKKNIDO', 'SQLERRM:'||l_OutSqlErrM);
		 -- RAISE NOTICE 'ERR: %', SQLERRM;

        extra_param := PKCONSTANT.FATAL();

        RETURN;

	END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;

    /********************************************************************************
	 * 基金請求計算後、元利払基金受入管理表出力処理を実行する。
	 * SMTBカスタマイズ帳票(spIp04801_08）で同様の処理を行っているため、この処理を修正する場合同期をとる必要があります。
	 *
	 * @param inDataSakuseiKbn データ作成区分
	 * @return INTEGER 0:正常、99:異常、それ以外：エラー
    *********************************************************************************/
CREATE OR REPLACE FUNCTION pkipakknido.inskikinidoukeirekanriout (l_inuserid TEXT , -- ユーザID
 l_ingyomuymd TEXT ,             -- 業務日付
 l_inkjnfrom TEXT ,              -- 基準日From
 l_inkjnto TEXT ,                -- 基準日To
 l_initakukaishacd text ,    -- 委託会社CD
 l_OutSqlCode OUT integer,         -- SQLエラーコード
 l_OutSqlErrM OUT text          -- SQLエラーメッセージ
 , OUT extra_param integer) RETURNS record AS $body$
DECLARE

        rec		pkipakknido.recType[];         --システム設定分と個別設定分を取得するカーソルのレコード
        				--システム設定分と個別設定分を取得するカーソルタイプ
        pCur record;	--システム設定分と個別設定分を取得するカーソル
        pCurSql                     varchar(10000) := NULL;

		pReturnCode integer := 0;
        pRowCnt     integer := 0;
		optionFlg   MOPTION_KANRI.OPTION_FLG%TYPE := '0';  -- オプションフラグ
		temp_rItakuKaishaCd char(4);
		temp_rMgrCd varchar(13);
		temp_rRbrKjt char(8);
		temp_rChokyuYmd char(8);
BEGIN
		 -- RAISE NOTICE 'in pkipakknido.inskikinidoukeirekanriout';
        --カーソルの作成    抽出条件に該当するレコードを基金移動テーブルに更新する
        pCurSql := pkipakknido.createsql(l_ingyomuymd,l_inkjnfrom,l_inkjnto,l_initakukaishacd,'','','','','',PKIPACALCTESURYO.C_REAL(),'','1');

        FOR pCur IN EXECUTE pCurSql
        LOOP

			rec[pRowCnt].rItakuKaishaCd := pCur.ITAKU_KAISHA_CD;
			rec[pRowCnt].rMgrCd := pCur.MGR_CD;
			rec[pRowCnt].rRbrKjt := pCur.RBR_KJT;
			rec[pRowCnt].rChokyuYmd := pCur.CHOKYU_YMD;

 			-- リアル・バッチ区分は「0」（リアル）「1」（バッチ）
			pReturnCode := sfInsKikinIdo(
									l_inuserid,
									rec[pRowCnt].rItakuKaishaCd,
									rec[pRowCnt].rMgrCd,
									rec[pRowCnt].rRbrKjt,
									rec[pRowCnt].rChokyuYmd,
									PKIPACALCTESURYO.C_DATA_KBN_YOTEI(),
									PKIPACALCTESURYO.C_REAL(),
									'');

            IF pReturnCode <> 0 THEN
                l_OutSqlCode := pReturnCode;
				l_OutSqlErrM := '基金請求計算処理（データ作成区分'|| PKIPACALCTESURYO.C_DATA_KBN_YOTEI||'）が失敗しました。';
				CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlErrM);
				extra_param := pReturnCode;
				RETURN;
			END IF;

            pRowCnt := pRowCnt + 1;

		END LOOP;

		----- 実質記番号オプション用処理 START
		BEGIN
			SELECT OPTION_FLG
			INTO STRICT  optionFlg
			FROM  MOPTION_KANRI
			WHERE KEY_CD = l_inItakuKaishaCd
			AND   OPTION_CD = 'IPP1003302010';
		EXCEPTION
			WHEN no_data_found THEN
				optionFlg := 0;
		END;

		IF optionFlg = 1 THEN
			-- 実質記番号管理オプション　基金異動計算・更新処理
			pReturnCode := pkIpaKibango.insKknIdo(  l_inUserId,
													l_inKjnFrom,
													l_inKjnTo,
													l_inItakuKaishaCd,
													NULL,
													NULL,
													NULL,
													NULL,
													NULL,
													pkipakknido.c_UKEIRE_KANRI(),
													PKIPACALCTESURYO.C_REAL(),
													PKIPACALCTESURYO.C_DATA_KBN_YOTEI(),
													'',
													l_OutSqlErrM);
			IF pReturnCode <> 0 THEN
				l_OutSqlCode := pReturnCode;
				CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlErrM);
				extra_param := pReturnCode;
				RETURN;
			END IF;
		END IF;
		----- 実質記番号オプション用処理 END
		-- 受入管理表出力
		IF pkControl.getCtlValue(l_inItakuKaishaCd, 'pkIpaKknIdo1', '0') = '1' THEN
			 -- RAISE NOTICE 'calling spIp04801_02';
			CALL spIp04801_02(
				l_inkjnfrom,             -- 決済日(FROM)
				l_inkjnto,               -- 決済日(TO)
				l_inItakuKaishaCd,       -- 委託会社コード
				l_inUserId,              -- ユーザーID
				PKIPACALCTESURYO.C_REAL(), -- 帳票区分
				l_inGyomuYmd,            -- 業務日付
				l_outSqlCode,            -- リターン値
				l_outSqlErrM             -- エラーコメント
			);
		ELSE
			 -- RAISE NOTICE 'calling spIp04801_01: %', PKIPACALCTESURYO.C_REAL();

			CALL spIp04801_01(
				l_inkjnfrom,             -- 決済日(FROM)
				l_inkjnto,               -- 決済日(TO)
				l_inItakuKaishaCd,       -- 委託会社コード
				l_inUserId,              -- ユーザーID
				PKIPACALCTESURYO.C_REAL(), -- 帳票区分
				l_inGyomuYmd,            -- 業務日付
				l_outSqlCode,            -- リターン値
				l_outSqlErrM             -- エラーコメント
			);
		END IF;


		 -- RAISE NOTICE 'calling spIp04801_* completged';

		-- 戻り値が２の場合は0にする
		IF coalesce(l_OutSqlCode,0) = 2 THEN
			l_OutSqlCode := 0;
		END IF;

		IF coalesce(l_OutSqlCode,0) <> 0 THEN
            CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlCode);
            CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlErrM);
            extra_param := pReturnCode;
            RETURN;
        END IF;

    extra_param := PKCONSTANT.SUCCESS();

    RETURN;

    -- エラー処理
    EXCEPTION
	WHEN	OTHERS	THEN
        l_OutSqlCode := SQLSTATE;
        l_OutSqlErrM := SQLERRM;
		CALL pkLog.fatal('ECM701', 'PKIPAKKNIDO', 'SQLCODE:'||l_OutSqlCode);
		CALL pkLog.fatal('ECM701', 'PKIPAKKNIDO', 'SQLERRM:'||l_OutSqlErrM);
		 -- RAISE NOTICE 'insKikinIdoUkeireKanriOut: %', SQLERRM;

        extra_param := PKCONSTANT.FATAL();

        RETURN;

	END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;

	/**
	 * 最終回次かどうかチェックします。
	 *
	 * @param l_inItakuKaishaCd		委託会社コード
	 * @param l_inMgrCd				銘柄コード
	 * @param l_inShokanKjt			償還期日
	 * @param l_inShokanKbn			償還区分
	 * @param l_inGensaiKngk		減債金額（※任意）
	 *
	 * @return VARCHAR 最終回次フラグ(最終回次：１、最終回次ではない：０)
	 */
CREATE OR REPLACE FUNCTION pkipakknido.sfchecklastkaiji (l_inItakuKaishaCd MGR_KIHON.ITAKU_KAISHA_CD%TYPE, l_inMgrCd MGR_KIHON.MGR_CD%TYPE, l_inShokanKjt MGR_SHOKIJ.SHOKAN_KJT%TYPE, l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE, l_inGensaiKngk MGR_SHOKIJ.MUNIT_GENSAI_KNGK%TYPE DEFAULT NULL) RETURNS varchar AS $body$
DECLARE

		l_shokanYmd			MGR_SHOKIJ.SHOKAN_YMD%TYPE;			-- 償還日
		l_kakushasaiKngk	MGR_KIHON.KAKUSHASAI_KNGK%TYPE;		-- 各社債の金額
		l_defaultYmd		MGR_KIHON.DEFAULT_YMD%TYPE;			-- デフォルト日
		l_shokanMethodCd	MGR_KIHON.SHOKAN_METHOD_CD%TYPE;	-- 償還方法
		l_fullshokanKjt		MGR_KIHON.FULLSHOKAN_KJT%TYPE;		-- 満期償還期日
		l_cnt				integer;							-- 件数取得用
		l_jisshitsuZndk		MGR_SHOKIJ.MUNIT_GENSAI_KNGK%TYPE;	-- 実質残高
		l_meimokuZndk		MGR_SHOKIJ.MUNIT_GENSAI_KNGK%TYPE;	-- 名目残高
		l_munitGensaiKngk	MGR_SHOKIJ.MUNIT_GENSAI_KNGK%TYPE;	-- 銘柄単位元本減債金額
		l_ret				varchar(1) := pkipakknido.kaiji_not_last();	-- 返り値

BEGIN
		-- 満期またはコール全額の場合は、'1'を返却する
		IF l_inShokanKbn IN ('10', '40') THEN
			RETURN pkipakknido.kaiji_last();
		-- 定時定額またはコール一部の場合は、'0'を返却する
		ELSIF l_inShokanKbn IN ('20', '41') THEN
			RETURN pkipakknido.kaiji_not_last();
		END IF;

		-- 銘柄_基本、銘柄_償還回次を検索
		SELECT
			coalesce(MG3.SHOKAN_YMD,
				pkDate.calcDateKyujitsuKbn(
									l_inShokanKjt,
									0,
									MG1.KYUJITSU_KBN,
									pkDate.getAreaCd(
											MG1.KYUJITSU_LD_FLG,
											MG1.KYUJITSU_NY_FLG,
											MG1.KYUJITSU_ETC_FLG,
											'N',
											MG1.ETCKAIGAI_AREA1,
											MG1.ETCKAIGAI_AREA2,
											MG1.ETCKAIGAI_AREA3))),		-- 償還日
			MG1.KAKUSHASAI_KNGK,										-- 各社債の金額
			MG1.DEFAULT_YMD,											-- デフォルト日
			MG1.SHOKAN_METHOD_CD										-- 償還方法
		INTO STRICT
			l_shokanYmd,
			l_kakushasaiKngk,
			l_defaultYmd,
			l_shokanMethodCd
		FROM mgr_kihon mg1
LEFT OUTER JOIN mgr_shokij mg3 ON (MG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD AND MG1.MGR_CD = MG3.MGR_CD AND l_inShokanKjt = MG3.SHOKAN_KJT AND l_inShokanKbn = MG3.SHOKAN_KBN)
WHERE MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND MG1.MGR_CD = l_inMgrCd;

		-- 引数の減債金額が未設定の場合
		IF l_inGensaiKngk IS NULL THEN
			-- 銘柄_償還回次より、引数の回次情報より後の償還件数を取得する
			SELECT
				COUNT(*)
			INTO STRICT
				l_cnt
			FROM
				MGR_SHOKIJ MG3,
				SCODE SC04
			WHERE
				MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd
				AND MG3.MGR_CD = l_inMgrCd
				AND MG3.SHOKAN_KBN = SC04.CODE_VALUE
				AND SC04.CODE_SHUBETSU = '714'
				AND MG3.SHOKAN_YMD || TO_CHAR(SC04.CODE_SORT, 'FM09') >
					(
						SELECT
							l_shokanYmd || TO_CHAR(SC04_WK.CODE_SORT, 'FM09')
						FROM
							SCODE SC04_WK
						WHERE
							SC04_WK.CODE_SHUBETSU = '714'
							AND SC04_WK.CODE_VALUE = l_inShokanKbn
					);

			-- 件数 > 0の場合は、'0'を返却
			IF l_cnt > 0 THEN
				l_ret := pkipakknido.kaiji_not_last();
			ELSE
				-- 件数 = 0の場合
				-- 永久債でもデフォルトでもない場合は、'1'を返却
				IF l_fullshokanKjt <> '99999999' AND nullif(trim(both l_defaultYmd), '') IS NULL THEN
					RETURN pkipakknido.kaiji_last();
				ELSE
					-- 永久債またはデフォルトの場合
					-- 償還日時点での実質残高を取得（引数の回次含む）
					l_jisshitsuZndk := pkIpaZndk.getKjnZndk(l_inItakuKaishaCd, l_inMgrCd, l_shokanYmd, l_inShokanKbn, 13)::bigint;
					-- 実質残高が0より大きい場合
					IF l_jisshitsuZndk > 0 THEN
						-- '0'を返却
						l_ret := pkipakknido.kaiji_not_last();
					ELSE
						-- 0の場合は'1'を返却
						l_ret := pkipakknido.kaiji_last();
					END IF;
				END IF;
			END IF;
		-- 引数の減債金額が設定されている場合
		ELSE
			-- 定時不定額の場合
			IF l_inShokanKbn = '21' THEN
				-- 償還日時点での名目残高を取得（引数の回次を含まない）
				l_meimokuZndk := pkIpaZndk.getKjnZndk(l_inItakuKaishaCd, l_inMgrCd, l_shokanYmd, l_inShokanKbn, 1)::bigint;
				-- 銘柄単位元本減債金額を求める
				l_munitGensaiKngk := l_meimokuZndk / l_kakushasaiKngk * l_inGensaiKngk;
			ELSE
				-- 買入・プット・新株予約権行使の場合
				-- 銘柄単位元本減債金額に引数の減債金額をセット
				l_munitGensaiKngk := l_inGensaiKngk;
			END IF;
			-- 償還日時点での実質残高を取得する（引数の回次を含まない）
			l_jisshitsuZndk := pkIpaZndk.getKjnZndk(l_inItakuKaishaCd, l_inMgrCd, l_shokanYmd, l_inShokanKbn, 3)::bigint;
			-- 銘柄単位元本減債金額と実質残高を比較
			-- 実質残高の方が大きい場合
			IF l_jisshitsuZndk > l_munitGensaiKngk THEN
				-- '0'を返却
				l_ret := pkipakknido.kaiji_not_last();
			ELSE
				-- '1'を返却
				l_ret := pkipakknido.kaiji_last();
			END IF;
		END IF;

		RETURN l_ret;

	EXCEPTION
		WHEN OTHERS THEN
			RAISE;
	END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;
	/*
	 * 債券の種類を判断します。
	 *
	 * @param l_inHakkoTsukaCd
	 * @param l_inShokanTsukaCd
	 *
	 * @return BOOLEAN 発行通貨と償還通貨が異なる場合はTRUE、それ以外はFALSE
	 */
CREATE OR REPLACE FUNCTION pkipakknido.sfgetbondtype (l_inHakkoTsukaCd MGR_KIHON.HAKKO_TSUKA_CD%TYPE, l_inShokanTsukaCd MGR_KIHON.SHOKAN_TSUKA_CD%TYPE) RETURNS boolean AS $body$
BEGIN
		/* 償還通貨 <> 発行通貨 かつ 償還通貨 <> '999'（'999' = 永久債） */

		IF l_inShokanTsukaCd <> l_inHakkoTsukaCd AND l_inShokanTsukaCd <> '999' THEN
			RETURN TRUE;
		ELSE
			RETURN FALSE;
		END IF;
	EXCEPTION
		WHEN OTHERS THEN
			RETURN FALSE;
	END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;
-- REVOKE ALL ON FUNCTION pkipakknido.sfgetbondtype (l_inHakkoTsukaCd MGR_KIHON.HAKKO_TSUKA_CD%TYPE, l_inShokanTsukaCd MGR_KIHON.SHOKAN_TSUKA_CD%TYPE) FROM PUBLIC;

	/*
	 * 銘柄単位償還プレミアムを算出します。
	 *
	 *  1.最終回次または、コールオプション（全額）、コールオプション（一部）、プットのとき
	 *    銘柄単位償還プレミアム = 名目金額 / 各社債の金額 * 振替単位償還プレミアム
	 *    名目金額はプットのときは減債名目金額、プット以外のときは名目残高です。
	 *  2.上記以外のとき
	 *    銘柄単位償還プレミアム = 銘柄単位元本減債額 / (各社債の金額 * ファクター) * 振替単位償還プレミアム
	 *  いずれの場合もファクターが０のときは０を返します。
	 *
	 */
CREATE OR REPLACE FUNCTION pkipakknido.getmunitsknpremium (
	l_inLastKaiji TEXT,
	l_inKakushasaiKngk MGR_KIHON.KAKUSHASAI_KNGK%TYPE,  -- bigint
	l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE,  -- char
	l_inFactor MGR_SHOKIJ.FACTOR%TYPE, --numeric
	l_inMeimokuKngk numeric,
	l_inMunitGensaiKngk numeric,
	l_inFunitSknPremium MGR_SHOKIJ.FUNIT_SKN_PREMIUM%TYPE --bigint
) RETURNS numeric AS $body$
DECLARE

		outMunitSknPremium numeric := 0;

BEGIN
		/* 最終回次、またはコールオプション（全額）、コールオプション（一部）、プットのとき */

		/* ファクターが洗い換え中になるときがあるので、エラーにならないようにする。（通常ありえない） */

		IF l_inLastKaiji = pkipakknido.kaiji_last() OR l_inShokanKbn in (pkipakknido.call_all(), pkipakknido.call_itibu(), pkipakknido.put()) THEN
			IF l_inFactor = 0 THEN
				outMunitSknPremium := 0;
			ELSE
				outMunitSknPremium := (l_inMeimokuKngk / l_inKakushasaiKngk) * l_inFunitSknPremium;
			END IF;
		/* それ以外 */

		ELSE
			IF l_inFactor = 0 THEN
				outMunitSknPremium := 0;
			ELSE
				outMunitSknPremium := (l_inMunitGensaiKngk / (l_inKakushasaiKngk * l_inFactor)) * l_inFunitSknPremium;
			END IF;
		END IF;
		RETURN outMunitSknPremium;
	END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;

/**
* 定時定額償還、定時不定額償還、コールオプション（全額）、コールオプション（一部）のときの
* 銘柄単位元本減債金額を算出します。
*  委託会社コード、銘柄コード、償還期日を渡すと、最終回次かを判定してから次へ渡します。
*  すでに呼び出し元で最終回次か判定されている場合は直接下を呼んでください。
*
* @param l_inItakuKaishaCd
* @param l_inMgrCd
* @param l_inKakushasaiKngk
* @param l_inHakkoTsukaCd
* @param l_inShokanTsukaCd
* @param l_inKawaseRate
* @param l_inShokanKjt
* @param l_inShokanKbn
* @param l_inFactor
* @param l_inMeimokuZndk
* @param l_inMunitGensaiKngk
* @param l_inFunitGensaiKngk
* @param l_inMunitSknPremium
*
* @retrun NUMERIC 銘柄単位償還支払金額
*/
CREATE OR REPLACE FUNCTION pkipakknido.getmunitsknshrkngk (
	l_inItakuKaishaCd MGR_KIHON.ITAKU_KAISHA_CD%TYPE,
	l_inMgrCd MGR_KIHON.MGR_CD%TYPE,
	l_inKakushasaiKngk MGR_KIHON.KAKUSHASAI_KNGK%TYPE,
	l_inHakkoTsukaCd MGR_KIHON.HAKKO_TSUKA_CD%TYPE,
	l_inShokanTsukaCd MGR_KIHON.SHOKAN_TSUKA_CD%TYPE,
	l_inKawaseRate MGR_KIHON.KAWASE_RATE%TYPE,
	l_inShokanKjt MGR_SHOKIJ.SHOKAN_KJT%TYPE,
	l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE,
	l_inFactor MGR_SHOKIJ.FACTOR%TYPE,
	l_inMeimokuZndk numeric,
	l_inMunitGensaiKngk numeric,
	l_inFunitGensaiKngk MGR_SHOKIJ.FUNIT_GENSAI_KNGK%TYPE,
	l_inMunitSknPremium MGR_SHOKIJ.MUNIT_SKN_PREMIUM%TYPE
	) RETURNS numeric AS $body$
DECLARE

		/* 回次（最終:1、その他:0) */

		wk_kaiji varchar(1);
		outMunitSknShrKngk numeric := 0;

BEGIN
		wk_kaiji := pkIpaKknIdo.sfCheckLastKaiji(l_inItakuKaishaCd, l_inMgrCd, l_inShokanKjt, l_inShokanKbn);
		outMunitSknShrKngk := pkIpaKknIdo.getMunitSknShrKngk( wk_kaiji,
															l_inKakushasaiKngk,
															l_inHakkoTsukaCd,
															l_inShokanTsukaCd,
															l_inKawaseRate,
															l_inShokanKbn,
															l_inFactor,
															l_inMeimokuZndk,
															l_inMunitGensaiKngk,
															l_inFunitGensaiKngk,
															l_inMunitSknPremium);
		RETURN outMunitSknShrKngk;
	END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;

/**
* 定時定額償還、定時不定額償還、コールオプション（全額）、コールオプション（一部）のときの
* 銘柄単位元本減債金額を算出します。
*
* 発行通貨と償還通貨が異なるとき
*      1.　最終回次または、コールオプション（全額）のとき
*      口数 * 振替単位レート換算 + 銘柄単位償還プレミアム
*      口数               = 名目残高 / 各社債の金額 * ファクター
*      振替単位レート換算 = 各社債の金額 / 為替レート（補助通貨単位未満を切捨て）
*
*      2.　上記以外のとき
*      口数 * 振替単位レート換算 + 銘柄単位償還プレミアム
*      口数               = 名目残高 / 各社債の金額
*      振替単位レート換算 = 振替単位元本減債額 / 為替レート（補助通貨単位未満を切捨て）
*
* 上記以外（円建て、外貨建て、リバースデュアルカレンシー債）
*      1.　最終回次または、コールオプション（全額）のとき
*      社債残高 + 銘柄単位償還プレミアム
*      社債残高 = 名目残高 * ファクター
*
*      2.　上記以外のとき
*      口数 * 振替単位元本減債額 + 銘柄単位償還プレミアム
*      口数 = 名目残高 * 各社債の金額
*
*/
CREATE OR REPLACE FUNCTION pkipakknido.getmunitsknshrkngk (
	l_inLastKaiji TEXT,
	l_inKakushasaiKngk MGR_KIHON.KAKUSHASAI_KNGK%TYPE,
	l_inHakkoTsukaCd MGR_KIHON.HAKKO_TSUKA_CD%TYPE,
	l_inShokanTsukaCd MGR_KIHON.SHOKAN_TSUKA_CD%TYPE,
	l_inKawaseRate MGR_KIHON.KAWASE_RATE%TYPE,
	l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE,
	l_inFactor MGR_SHOKIJ.FACTOR%TYPE,
	l_inMeimokuZndk numeric,
	l_inMunitGensaiKngk numeric,
	l_inFunitGensaiKngk MGR_SHOKIJ.FUNIT_GENSAI_KNGK%TYPE,
	l_inMunitSknPremium MGR_SHOKIJ.MUNIT_SKN_PREMIUM%TYPE
) RETURNS numeric AS $body$
DECLARE

		outMunitSknShrKngk numeric := 0;
		wk_scale smallint := 0;
BEGIN
		-- 償還通貨の精度を設定
		wk_scale := 0;
		IF (l_inShokanTsukaCd != 'JPY' and l_inShokanTsukaCd != '999') THEN
			wk_scale := 2;
		END IF;

		/* 発行通貨と償還通貨が異なる場合 */

		IF pkIpaKknIdo.sfGetBondType(l_inHakkoTsukaCd, l_inShokanTsukaCd) THEN
			/* 最終回次、またはコールオプション（全額）のとき */

			IF l_inLastKaiji = pkipakknido.kaiji_last() OR l_inShokanKbn = pkipakknido.call_all() THEN
				IF l_inFactor = 0 THEN
					outMunitSknShrKngk := 0;
				ELSE
					outMunitSknShrKngk := (l_inMeimokuZndk / l_inKakushasaiKngk * l_inFactor) * trunc((l_inKakushasaiKngk / l_inKawaseRate), wk_scale) + l_inMunitSknPremium;
				END IF;
			/* 最終回次以外 */

			ELSE
				outMunitSknShrKngk := (l_inMeimokuZndk / l_inKakushasaiKngk) * trunc((l_inFunitGensaiKngk / l_inKawaseRate), wk_scale) + l_inMunitSknPremium;
			END IF;
		ELSE
		/* 円建て、外貨建て、リバースデュアルカレンシー債の場合 */

			/* 最終回次、またはコールオプション（全額）のとき */

			IF l_inLastKaiji = pkipakknido.kaiji_last() OR l_inShokanKbn = pkipakknido.call_all() THEN
				IF l_inFactor = 0 THEN
					outMunitSknShrKngk := 0;
				ELSE
					outMunitSknShrKngk := (l_inMeimokuZndk * l_inFactor ) + l_inMunitSknPremium;
				END IF;
			/* 最終回次以外 */

			ELSE
				outMunitSknShrKngk := (l_inMeimokuZndk / l_inKakushasaiKngk) * l_inFunitGensaiKngk + l_inMunitSknPremium;
			END IF;
		END IF;

		-- 償還通貨に精度を調整する
		outMunitSknShrKngk := trunc(outMunitSknShrKngk, wk_scale);

		RETURN outMunitSknShrKngk;
	END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;

	/**
	 * プットオプションの銘柄単位償還支払額を算出します。
	 *
	 * @param l_inKakushasaiKngk
	 * @param l_inHakkoTsukaCd
	 * @param l_inShokanTsukaCd
	 * @param l_inKawaseRate
	 * @param l_inFactor
	 * @param l_inMeimokuKngk
	 * @param l_inMunitSknPremium
	 *
	 * @return NUMERIC プットオプションの銘柄単位償還支払金額
	 */
CREATE OR REPLACE FUNCTION pkipakknido.getputmunitsknshrkngk (
	l_inKakushasaiKngk numeric,
	l_inHakkoTsukaCd MGR_KIHON.HAKKO_TSUKA_CD%TYPE,
	l_inShokanTsukaCd MGR_KIHON.SHOKAN_TSUKA_CD%TYPE,
	l_inKawaseRate numeric,
	l_inFactor numeric,
	l_inMeimokuKngk numeric,
	l_inMunitSknPremium numeric
) RETURNS numeric AS $body$
DECLARE

		/* 銘柄単位償還支払額 */

		outMunitSknShrKngk numeric := 0;
		/* 振替単位為替レート換算 */

		wk_FunitKawaseRateConversion numeric := 0;
		/* ファクター */

		wk_Factor MGR_SHOKIJ.FACTOR%TYPE;
		/* 通貨精度 */

		wk_scale integer;

BEGIN
		/* ファクターが0（ファクター銘柄でない）なら1として計算 */

		IF l_inFactor = 0 THEN
			wk_Factor := 1;
		ELSE
			wk_Factor := l_inFactor;
		END IF;
		/* 償還通貨の精度を設定 */

		wk_scale := 0;
		IF (l_inShokanTsukaCd != 'JPY' and l_inShokanTsukaCd != '999') THEN
			wk_scale := 2;
		END IF;

		/* 銘柄単位償還支払額の算出
		 * 発行通貨と償還通貨が異なる
		 *      ・定時償還銘柄：（減債額÷（各社債の金額×ファクター)×振替単位レート換算）＋銘柄単位の償還プレミアム
		 *      ・上記以外　　：（減債額÷（各社債の金額)×振替単位レート換算）＋銘柄単位の償還プレミアム
		 * 上記以外
		 *      ・定時償還銘柄：（減債額＋銘柄単位の償還プレミアム）
		 *      ・上記以外　　：（減債額＋銘柄単位の償還プレミアム）
		 *
		 * 振替単位レート換算       = (各社債の金額)÷為替レート （補助通貨単位未満を切捨て）
		 *
		 * 定時償還銘柄、それ以外の銘柄について
		 * 定時償還銘柄でないものはファクター = 1として計算するため、式自体は同一のものとなる。
		 */
		/* 発行通貨と償還通貨が異なる場合は振替単位為替レート換算を行う*/

		IF pkIpaKknIdo.sfGetBondType(l_inHakkoTsukaCd, l_inShokanTsukaCd) THEN
			/* 振替単位為替レート換算 */

			wk_FunitKawaseRateConversion := trunc((l_inKakushasaiKngk / l_inKawaseRate), wk_scale::integer);
			/* 銘柄単位償還支払額 */

			outMunitSknShrKngk := ((l_inMeimokuKngk / l_inKakushasaiKngk * wk_Factor) * wk_FunitKawaseRateConversion) + l_inMunitSknPremium;
		ELSE
			/* 銘柄単位償還支払額 */

			outMunitSknShrKngk := (l_inMeimokuKngk * wk_Factor) + l_inMunitSknPremium;
		END IF;


		/* 通貨単位に精度を調整 */

		outMunitSknShrKngk := trunc(outMunitSknShrKngk::numeric, wk_scale::integer);
		RETURN outMunitSknShrKngk;
	END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;

/********************************************************************************
* 銘柄_償還回次削除
* 社債残高0なら以降の償還回次、利払回次の期日は物理削除します。
*
* @param l_inUserId         ユーザID
* @param l_inItakuKaishaCd  委託会社コード
* @param l_inMgrCd          銘柄コード
* @param l_inShrYmd         支払日
* @param l_inShokanKbn      償還区分
* @param l_inFlg            同一日の償還回次を削除するかを判別するフラグ（削除する場合'1'）
*
* @return INTEGER 0:正常、99:異常、それ以外：エラー
*********************************************************************************/
CREATE OR REPLACE FUNCTION pkipakknido.sfdeleteremainsofkaiji (
	l_inUserId text,
	l_inItakuKaishaCd text,
	l_inMgrCd MGR_KIHON.MGR_CD%TYPE,
	l_inShrYmd MGR_SHOKIJ.SHOKAN_YMD%TYPE,
	l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE,
	l_inFlg TEXT DEFAULT '1'
) RETURNS bigint AS $body$
BEGIN
    	/* 銘柄_償還回次の削除 */

		DELETE FROM
            MGR_SHOKIJ MG3
        WHERE
            MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd
        AND MG3.MGR_CD = l_inMgrCd
        AND MG3.SHOKAN_YMD > l_inShrYmd;

	    /* 同一日の償還回次を削除 */

    	IF (trim(both l_inFlg) = '1') THEN
	        DELETE FROM
	            MGR_SHOKIJ MG3
	        WHERE
	            MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd
	        AND MG3.MGR_CD = l_inMgrCd
	        AND MG3.SHOKAN_YMD = l_inShrYmd
	        AND MG3.SHOKAN_KBN IN
            	    (SELECT CODE_VALUE
            	     FROM   SCODE
            	     WHERE  CODE_SHUBETSU = CODE_SHOKAN_KBN
            	     AND    CODE_SORT > (SELECT   CODE_SORT
                	                     FROM     SCODE
                    	                 WHERE    CODE_SHUBETSU = CODE_SHOKAN_KBN
                        	             AND      CODE_VALUE = l_inShokanKbn));
	     END IF;

        CALL pkLog.DEBUG(l_inUserId,'PKIPAKKNIDO','全額償還になったので、以降の償還回次を削除します。');

    /* 銘柄_利払回次の削除 */

        DELETE FROM
            MGR_RBRKIJ MG2
        WHERE
            MG2.ITAKU_KAISHA_CD = l_inItakuKaishaCd
        AND MG2.MGR_CD = l_inMgrCd
        AND MG2.RBR_YMD > l_inShrYmd;

        CALL pkLog.DEBUG(l_inUserId,'PKIPAKKNIDO','全額償還になったので、以降の利払回次を削除します。');

        RETURN PKCONSTANT.SUCCESS();
    EXCEPTION
        WHEN OTHERS THEN
			CALL pkLog.FATAL('ECM701','PKIPAKKNIDO','委託会社コード = ' || l_inItakuKaishaCd || ' 銘柄コード = ' || l_inMgrCd);
            CALL pkLog.FATAL('ECM701','PKIPAKKNIDO','銘柄_償還回次、銘柄_利払回次の削除が失敗しました。');

            RETURN PKCONSTANT.FATAL();
    END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;

/**
* 請求書出力日取得
* 委託会社、支払期日より請求書出力日を算出して返します。
*
* @param l_inItakuKaishaCd  委託会社コード
* @param l_inShrKjt         支払期日
* @param l_inKKnbillOutYmd  基金請求書出力日(個別設定)
*
* @return TEXT 請求書出力日(エラー発生時はNULLを返却)
*/
CREATE OR REPLACE FUNCTION pkipakknido.getseikyushobilloutymd ( l_inItakuKaishaCd text, l_inShrKjt MGR_RBRKIJ.RBR_KJT%TYPE, l_inKknbillOutYmd MGR_RBRKIJ.KKNBILL_OUT_YMD%TYPE ) RETURNS char AS $body$
DECLARE

		l_kknBillOutYmd		MGR_RBRKIJ.KKNBILL_OUT_YMD%TYPE;
		l_outDd				SEIKYUSHO_KANRI.OUT_DD%TYPE;
		l_nmonthAftKbn		SEIKYUSHO_KANRI.NMONTH_AFT_KBN%TYPE;
		l_kknBillOutYYYYMM	char(6);

BEGIN
		-- 個別請求書出力日が設定されている場合
		IF nullif(trim(both l_inKknbillOutYmd), '') IS NOT NULL THEN
			-- 回次の請求書出力日を返却
			RETURN l_inKknbillOutYmd;
		END IF;

		-- システム設定の場合は、請求書出力設定テーブルより算出する
		SELECT
			LPAD(S02.OUT_DD, 2, '0'),
			S02.NMONTH_AFT_KBN
		INTO STRICT
			l_outDd,
			l_nmonthAftKbn
		FROM
			SEIKYUSHO_KANRI S02
       WHERE S02.ITAKU_KAISHA_CD = l_inItakuKaishaCd
         AND S02.BILL_KBN = '1'
         AND l_inShrKjt BETWEEN
                           CASE
                           WHEN S02.FKJT_DD > S02.TKJT_DD
                           THEN
                              -- FROM、TOが月をまたぐ場合
                              CASE
                              WHEN S02.FKJT_DD > SUBSTR(l_inShrKjt,7,2)
                              THEN
                                  -- 支払期日が月をまたぐ場合
                                  SUBSTR(TO_CHAR(oracle.ADD_MONTHS(l_inShrKjt,-1),'YYYYMMDD'),1,6) || S02.FKJT_DD
                              ELSE
                                  -- 支払期日が月をまたがない場合
                                  SUBSTR(TO_CHAR(oracle.ADD_MONTHS(l_inShrKjt,1),'YYYYMMDD'),1,6) || S02.TKJT_DD
                              END
                           ELSE
                              -- FROM、TOが月をまたがない場合
                              SUBSTR(l_inShrKjt,1,6) || S02.FKJT_DD
                           END
                        AND
                           CASE
                           WHEN S02.FKJT_DD > S02.TKJT_DD
                           THEN
                              -- FROM、TOが月をまたぐ場合
                              CASE
                              WHEN S02.FKJT_DD > SUBSTR(l_inShrKjt,7,2)
                              THEN
                                  -- 支払期日が月をまたぐ場合
                                  SUBSTR(l_inShrKjt,1,6) || S02.TKJT_DD
                              ELSE
                                  -- 支払期日が月をまたがない場合
                                  SUBSTR(TO_CHAR(l_inShrKjt + '1 month'::interval,'YYYYMMDD'),1,6) || S02.TKJT_DD
                              END
                           ELSE
                              -- FROM、TOが月をまたがない場合
                              SUBSTR(l_inShrKjt,1,6) || S02.TKJT_DD
                           END;

		-- 請求書出力年月を求める
		l_kknBillOutYYYYMM := TO_CHAR(oracle.ADD_MONTHS(TO_DATE(l_inShrKjt, 'YYYYMMDD') , -(oracle.TO_NUMBER(l_nmonthAftKbn))), 'YYYYMM');
		-- 請求書出力日を求める（暫定で出力日をそのまま連結）
		l_kknBillOutYmd := l_kknBillOutYYYYMM || l_outDd;

		-- 日付として不正値の場合は、月末営業日を求める
		IF pkDate.validateDate(l_kknBillOutYmd) != 0 THEN
			l_kknBillOutYmd := pkDate.getGetsumatsuBusinessYmd(l_kknBillOutYYYYMM || '01', 0);
		-- 日付形式でも非営業日の場合は、前営業日を求める
		ELSIF pkDate.isBusinessDay(l_kknBillOutYmd) != 0 THEN
			l_kknBillOutYmd := pkDate.getZenBusinessYmd(l_kknBillOutYmd);
		END IF;

		RETURN l_kknBillOutYmd;

	EXCEPTION
		WHEN OTHERS THEN
			RETURN NULL;
	END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;

--*******************************************************************************
--	 * 会計按分テーブルから指定銘柄コードのレコード件数を返す。
--	 *
--	 * @param l_initakukaishacd 委託会社コード
--	 * @param l_inmgrcd         銘柄コード
--	 * @return NUMERIC           レコード件数
--	********************************************************************************
CREATE OR REPLACE FUNCTION pkipakknido.getkaikeianbuncount (
	l_initakukaishacd MGR_KIHON.ITAKU_KAISHA_CD%TYPE,
	l_inmgrcd MGR_KIHON.MGR_CD%TYPE
) RETURNS numeric AS $body$
DECLARE

		gCnt              numeric  := 0;

BEGIN

		SELECT
			COUNT(1)
		INTO STRICT
			gCnt
		FROM
			KAIKEI_ANBUN
		WHERE
			ITAKU_KAISHA_CD = l_initakukaishacd
		AND	MGR_CD = l_inmgrcd
		AND	SHORI_KBN = '1'
		;

		RETURN gCnt;

	END;
$body$
LANGUAGE PLPGSQL
;

--*******************************************************************************
--	 * 基金請求計算後、元利金支払基金引落一覧表出力処理を実行する。
--	 *
--	 * @param inDataSakuseiKbn データ作成区分
--	 * @return INTEGER 0:正常、99:異常、それ以外：エラー
--	********************************************************************************
CREATE OR REPLACE FUNCTION pkipakknido.inskikinidohikiotoshiout (
	l_inuserid TEXT ,  -- ユーザID
 l_ingyomuymd TEXT ,              -- 業務日付
 l_inkjnfrom TEXT ,               -- 基準日From
 l_inkjnto TEXT ,                 -- 基準日To
 l_initakukaishacd TEXT ,     -- 委託会社CD
 l_OutSqlCode OUT integer,          -- SQLエラーコード
 l_OutSqlErrM OUT TEXT           -- SQLエラーメッセージ
 , OUT extra_param integer) RETURNS record AS $body$
DECLARE

		rec pkipakknido.recType[];   --システム設定分と個別設定分を取得するカーソルのレコード
		pCur record;        --システム設定分と個別設定分を取得するカーソル
		pCurSql                     varchar(10000) := NULL;

		pReturnCode integer := 0;
		pRowCnt     integer := 0;


BEGIN
		--カーソルの作成    抽出条件に該当するレコードを基金移動テーブルに更新する
		pCurSql := pkipakknido.createsql(l_ingyomuymd,l_inkjnfrom,l_inkjnto,l_initakukaishacd,'','','','','',PKIPACALCTESURYO.C_REAL(),'','1');

		FOR pCur IN EXECUTE pCurSql
		LOOP

			rec[pRowCnt].rItakuKaishaCd := pCur.ITAKU_KAISHA_CD;
			rec[pRowCnt].rMgrCd := pCur.MGR_CD;
			rec[pRowCnt].rRbrKjt := pCur.RBR_KJT;
			rec[pRowCnt].rChokyuYmd := pCur.CHOKYU_YMD;

			-- リアル・バッチ区分は「0」（リアル）「1」（バッチ）
			pReturnCode := sfInsKikinIdo(
									l_inuserid,
									rec[pRowCnt].rItakuKaishaCd,
									rec[pRowCnt].rMgrCd,
									rec[pRowCnt].rRbrKjt,
									rec[pRowCnt].rChokyuYmd,
									PKIPACALCTESURYO.C_DATA_KBN_YOTEI(),
									PKIPACALCTESURYO.C_REAL(),
									'');

			IF pReturnCode <> 0 THEN
				l_OutSqlCode := pReturnCode;
				l_OutSqlErrM := '基金請求計算処理（データ作成区分'|| PKIPACALCTESURYO.C_DATA_KBN_YOTEI()||'）が失敗しました。';
				CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlErrM);
				extra_param := pReturnCode;
				RETURN;
			END IF;

			pRowCnt := pRowCnt + 1;
		END LOOP;

		-- 元利金支払基金引落一覧表出力
		CALL SPIPX007K00R01_01(
					l_inItakuKaishaCd,         -- 委託会社コード
					l_inUserId,                -- ユーザーID
					PKIPACALCTESURYO.C_REAL(),   -- 帳票区分
					l_inkjnfrom,               -- 決済日(FROM)
					l_inkjnto,                 -- 決済日(TO)
					l_outSqlCode,              -- リターン値
					l_outSqlErrM                -- エラーコメント
					);

		-- 戻り値が２の場合は0にする
		IF coalesce(l_OutSqlCode,0) = 2 THEN
			l_OutSqlCode := 0;
		END IF;

		IF coalesce(l_OutSqlCode,0) <> 0 THEN
			CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlCode);
			CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlErrM);
			extra_param := pReturnCode;
			RETURN;
		END IF;

	extra_param := pkconstant.success();

	RETURN;

	-- エラー処理
	EXCEPTION
		WHEN	OTHERS	THEN
			l_OutSqlCode := SQLSTATE;
			l_OutSqlErrM := SQLERRM;
			CALL pkLog.fatal('ECM701', 'PKIPAKKNIDO', 'SQLCODE:'||l_OutSqlCode);
			CALL pkLog.fatal('ECM701', 'PKIPAKKNIDO', 'SQLERRM:'||l_OutSqlErrM);

	extra_param := pkconstant.FATAL();

	RETURN;

	END;
$body$
LANGUAGE PLPGSQL
;

--*******************************************************************************
--	 * 会計按分テーブルから指定銘柄コードのレコード件数を返す。
--	 *
--	 * @param l_initakukaishacd 委託会社コード
--	 * @param l_inmgrcd         銘柄コード
--	 * @return NUMERIC           レコード件数
--	********************************************************************************
CREATE OR REPLACE FUNCTION pkipakknido.getkaikeianbuncount ( l_initakukaishacd MGR_KIHON.ITAKU_KAISHA_CD%TYPE, l_inmgrcd MGR_KIHON.MGR_CD%TYPE ) RETURNS numeric AS $body$
DECLARE

		gCnt              numeric  := 0;

BEGIN

		SELECT
			COUNT(1)
		INTO STRICT
			gCnt
		FROM
			KAIKEI_ANBUN
		WHERE
			ITAKU_KAISHA_CD = l_initakukaishacd
		AND	MGR_CD = l_inmgrcd
		AND	SHORI_KBN = '1'
		;

		RETURN gCnt;

	END;
$body$
LANGUAGE PLPGSQL
;

--*******************************************************************************
--	 * 基金請求計算後、元利金支払基金引落一覧表出力処理を実行する。
--	 *
--	 * @param inDataSakuseiKbn データ作成区分
--	 * @return INTEGER 0:正常、99:異常、それ以外：エラー
--	********************************************************************************
CREATE OR REPLACE FUNCTION pkipakknido.inskikinidohikiotoshiout (
	l_inuserid TEXT ,  -- ユーザID
 l_ingyomuymd TEXT ,              -- 業務日付
 l_inkjnfrom TEXT ,               -- 基準日From
 l_inkjnto TEXT ,                 -- 基準日To
 l_initakukaishacd TEXT ,     -- 委託会社CD
 l_OutSqlCode OUT integer,          -- SQLエラーコード
 l_OutSqlErrM OUT TEXT           -- SQLエラーメッセージ
 , OUT extra_param integer) RETURNS record AS $body$
DECLARE

	rec pkipakknido.recType[];   --システム設定分と個別設定分を取得するカーソルのレコード
	pCur record;        --システム設定分と個別設定分を取得するカーソル
	pCurSql                     varchar(10000) := NULL;
	pReturnCode integer := 0;
	pRowCnt     integer := 0;
BEGIN
		--カーソルの作成    抽出条件に該当するレコードを基金移動テーブルに更新する
		pCurSql := pkipakknido.createsql(l_ingyomuymd,l_inkjnfrom,l_inkjnto,l_initakukaishacd,'','','','','',PKIPACALCTESURYO.C_REAL(),'','1');

		FOR pCur IN EXECUTE pCurSql
		LOOP
			rec[pRowCnt].rItakuKaishaCd := pCur.ITAKU_KAISHA_CD;
			rec[pRowCnt].rMgrCd := pCur.MGR_CD;
			rec[pRowCnt].rRbrKjt := pCur.RBR_KJT;
			rec[pRowCnt].rChokyuYmd := pCur.CHOKYU_YMD;

			-- リアル・バッチ区分は「0」（リアル）「1」（バッチ）
			pReturnCode := sfInsKikinIdo(
									l_inuserid,
									rec[pRowCnt].rItakuKaishaCd,
									rec[pRowCnt].rMgrCd,
									rec[pRowCnt].rRbrKjt,
									rec[pRowCnt].rChokyuYmd,
									PKIPACALCTESURYO.C_DATA_KBN_YOTEI(),
									PKIPACALCTESURYO.C_REAL(),
									'');

			IF pReturnCode <> 0 THEN
				l_OutSqlCode := pReturnCode;
				l_OutSqlErrM := '基金請求計算処理（データ作成区分'|| PKIPACALCTESURYO.C_DATA_KBN_YOTEI()||'）が失敗しました。';
				CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlErrM);
				extra_param := pReturnCode;
				RETURN;
			END IF;

			pRowCnt := pRowCnt + 1;
		END LOOP;

		-- 元利金支払基金引落一覧表出力
		CALL SPIPX007K00R01_01(
					l_inItakuKaishaCd,         -- 委託会社コード
					l_inUserId,                -- ユーザーID
					PKIPACALCTESURYO.C_REAL(),   -- 帳票区分
					l_inkjnfrom,               -- 決済日(FROM)
					l_inkjnto,                 -- 決済日(TO)
					l_outSqlCode,              -- リターン値
					l_outSqlErrM                -- エラーコメント
					);

		-- 戻り値が２の場合は0にする
		IF coalesce(l_OutSqlCode,0) = 2 THEN
			l_OutSqlCode := 0;
		END IF;

		IF coalesce(l_OutSqlCode,0) <> 0 THEN
			CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlCode);
			CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlErrM);
			extra_param := pReturnCode;
			RETURN;
		END IF;

	extra_param := pkconstant.success();

	RETURN;

	-- エラー処理
	EXCEPTION
		WHEN	OTHERS	THEN
			l_OutSqlCode := SQLSTATE;
			l_OutSqlErrM := SQLERRM;
			CALL pkLog.fatal('ECM701', 'PKIPAKKNIDO', 'SQLCODE:'||l_OutSqlCode);
			CALL pkLog.fatal('ECM701', 'PKIPAKKNIDO', 'SQLERRM:'||l_OutSqlErrM);

	extra_param := pkconstant.FATAL();

	RETURN;

	END;
$body$
LANGUAGE PLPGSQL
;