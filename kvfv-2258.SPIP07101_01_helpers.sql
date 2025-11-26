-- Helper functions for SPIP07101_01

-- Type definition for record
DROP TYPE IF EXISTS spip07101_01_type_record CASCADE;
CREATE TYPE spip07101_01_type_record AS (
    gJtkKbn                 text,
    gJtkKbnNm               text,
    gIsinCd                 text,
    gMgrCd                  text,
    gMgrRnm                 text,
    gHktCd                  text,
    gSaikenShuruiNm         text,
    gKkKanyoFlgNm           text,
    gShokanMethodNm         text,
    gTeijiShokanTsutiKbn    text,
    gFactor1                numeric,
    gFactor2                numeric,
    gCallallUmuFlg          text,
    gCallitibuUmuFlg        text,
    gPutumuFlg              text,
    gPutumuFlgNm            text,
    gShokanYmd              text,
    gShokanKjt              text,
    gJiyuuNm                text,
    gHakkoTsukaNm           text,
    gHakkoTsukaCd           text,
    gGensaiKngk             numeric,
    gGensaiSum              numeric,
    gKaiji                  text,
    gBankRnm                text,
    gJikoDaikoKbn           text,
    gShokanKbn              text,
    gItakuKaishaCd          text,
    gShokanMethodCd         text,
    gShokanKbnSort          text
);

-- Helper function: getMasshoYmd
CREATE OR REPLACE FUNCTION spip07101_01_getMasshoYmd(
    l_inItakuKaishaCd text,
    l_inMgrCd text,
    l_inShokanYmd text,
    l_inShokanKbn text
) RETURNS text AS $$
DECLARE
    masshoYmd text;
BEGIN
    SELECT Z01.MASSHO_YMD INTO masshoYmd
    FROM GENSAI_RIREKI Z01
    WHERE Z01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
      AND Z01.MGR_CD = l_inMgrCd
      AND Z01.SHOKAN_YMD = l_inShokanYmd
      AND Z01.SHOKAN_KBN = l_inShokanKbn;
    RETURN masshoYmd;
EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN NULL;
    WHEN OTHERS THEN RAISE;
END;
$$ LANGUAGE plpgsql;

-- Helper function: getNyuryokuYmd
CREATE OR REPLACE FUNCTION spip07101_01_getNyuryokuYmd(
    l_inItakuKaishaCd text,
    l_inMgrCd text,
    l_inShokanKjt text,
    l_inShokanKbn text
) RETURNS text AS $$
DECLARE
    nyuryokuYmd text;
BEGIN
    SELECT TO_CHAR(MG23.LAST_TEISEI_DT,'YYYYMMDD') INTO nyuryokuYmd
    FROM UPD_MGR_SHN MG23
    WHERE MG23.ITAKU_KAISHA_CD = l_inItakuKaishaCd
      AND MG23.MGR_CD = l_inMgrCd
      AND MG23.SHR_KJT = l_inShokanKjt
      AND MG23.MGR_HENKO_KBN = l_inShokanKbn
      AND MG23.SHORI_KBN = '1';
    RETURN nyuryokuYmd;
EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN NULL;
    WHEN OTHERS THEN RAISE;
END;
$$ LANGUAGE plpgsql;

-- Helper function: checkLastMgrShokij
CREATE OR REPLACE FUNCTION spip07101_01_checkLastMgrShokij(
    l_inItakuKaishaCd text,
    gMgrCd text,
    gShokanYmd text,
    gShokanKbnSort text
) RETURNS integer AS $$
DECLARE
    gLastShokanFlg integer;
    maxVal text;
    compareVal text;
BEGIN
    SELECT MAX(SHOKAN_YMD || LPAD(CODE_SORT::text, 2, '0'))
    INTO maxVal
    FROM MGR_SHOKIJ, SCODE
    WHERE MGR_SHOKIJ.SHOKAN_KBN = SCODE.CODE_VALUE
      AND SCODE.CODE_SHUBETSU = '714'
      AND ITAKU_KAISHA_CD = l_inItakuKaishaCd
      AND MGR_CD = gMgrCd;
    
    compareVal := gShokanYmd || LPAD(gShokanKbnSort::text, 2, '0');
    
    IF maxVal = compareVal THEN
        gLastShokanFlg := 0;
    ELSE
        gLastShokanFlg := 1;
    END IF;
    
    RETURN gLastShokanFlg;
EXCEPTION
    WHEN OTHERS THEN RAISE;
END;
$$ LANGUAGE plpgsql;
