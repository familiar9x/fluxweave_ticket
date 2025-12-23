
DROP TYPE IF EXISTS sfipepathreportwkinsertbatch_type_record CASCADE;
DROP TYPE IF EXISTS sfipepathreportwkinsertbatch_createerepwkdata_type_key CASCADE;
DROP TABLE IF EXISTS sfipepath_global_state CASCADE;

-- Use a regular table instead of temp table so it persists across sessions
CREATE TABLE IF NOT EXISTS sfipepath_global_state (
    session_key text PRIMARY KEY DEFAULT 'main',
    gSql text, 
    gWhereDispatch text,
    gChohyoId char(11),
    gPoolFlg char(1),
    gEpathSendYmdItem char(7),
    gIsinCdItem char(12),
    gDispatchFlgItem char(7),
    gKeyItem char(7),
    gKensakuNm1 varchar(20), gKensakuItem1 char(7),
    gKensakuNm2 varchar(20), gKensakuItem2 char(7),
    gKensakuNm3 varchar(20), gKensakuItem3 char(7),
    gKensakuNm4 varchar(20), gKensakuItem4 char(7),
    gKensakuNm5 varchar(20), gKensakuItem5 char(7),
    gKensakuNm6 varchar(20), gKensakuItem6 char(7),
    gKensakuNm7 varchar(20), gKensakuItem7 char(7),
    gKensakuNm8 varchar(20), gKensakuItem8 char(7),
    gKensakuNm9 varchar(20), gKensakuItem9 char(7),
    gKensakuNm10 varchar(20), gKensakuItem10 char(7),
    gSeqNo numeric(10),
    gSeqNo2 numeric(10),
    gCnt numeric,
    gMgrCd character(8),
    gRedOptionFlg character(1),
    l_inItakuKaishaCd text,
    l_inSakuseiYmd text,
    SPACE text,
    USER_ID text,
    SP_ID text
); 

DELETE FROM sfipepath_global_state;

CREATE TYPE sfipepathreportwkinsertbatch_type_record AS (    
         HKT_CD     char(6)
        ,KEY_ITEM1  varchar(400)
        ,KEY_ITEM2  varchar(400)
        ,KEY_ITEM3  varchar(400)
        ,KEY_ITEM4  varchar(400)
        ,KEY_ITEM5  varchar(400)
        ,KEY_ITEM6  varchar(400)
        ,KEY_ITEM7  varchar(400)
        ,KEY_ITEM8  varchar(400)
        ,KEY_ITEM9  varchar(400)
        ,KEY_ITEM10 varchar(400)
        ,EPATH_SEND_YMD varchar(400)
        ,ISIN_CD    varchar(400)
        ,ITEM001    varchar(400), ITEM002    varchar(400), ITEM003    varchar(400), ITEM004    varchar(400), ITEM005    varchar(400)
        ,ITEM006    varchar(400), ITEM007    varchar(400), ITEM008    varchar(400), ITEM009    varchar(400), ITEM010    varchar(400)
        ,ITEM011    varchar(400), ITEM012    varchar(400), ITEM013    varchar(400), ITEM014    varchar(400), ITEM015    varchar(400)
        ,ITEM016    varchar(400), ITEM017    varchar(400), ITEM018    varchar(400), ITEM019    varchar(400), ITEM020    varchar(400)
        ,ITEM021    varchar(400), ITEM022    varchar(400), ITEM023    varchar(400), ITEM024    varchar(400), ITEM025    varchar(400)
        ,ITEM026    varchar(400), ITEM027    varchar(400), ITEM028    varchar(400), ITEM029    varchar(400), ITEM030    varchar(400)
        ,ITEM031    varchar(400), ITEM032    varchar(400), ITEM033    varchar(400), ITEM034    varchar(400), ITEM035    varchar(400)
        ,ITEM036    varchar(400), ITEM037    varchar(400), ITEM038    varchar(400), ITEM039    varchar(400), ITEM040    varchar(400)
        ,ITEM041    varchar(400), ITEM042    varchar(400), ITEM043    varchar(400), ITEM044    varchar(400), ITEM045    varchar(400)
        ,ITEM046    varchar(400), ITEM047    varchar(400), ITEM048    varchar(400), ITEM049    varchar(400), ITEM050    varchar(400)
        ,ITEM051    varchar(400), ITEM052    varchar(400), ITEM053    varchar(400), ITEM054    varchar(400), ITEM055    varchar(400)
        ,ITEM056    varchar(400), ITEM057    varchar(400), ITEM058    varchar(400), ITEM059    varchar(400), ITEM060    varchar(400)
        ,ITEM061    varchar(400), ITEM062    varchar(400), ITEM063    varchar(400), ITEM064    varchar(400), ITEM065    varchar(400)
        ,ITEM066    varchar(400), ITEM067    varchar(400), ITEM068    varchar(400), ITEM069    varchar(400), ITEM070    varchar(400)
        ,ITEM071    varchar(400), ITEM072    varchar(400), ITEM073    varchar(400), ITEM074    varchar(400), ITEM075    varchar(400)
        ,ITEM076    varchar(400), ITEM077    varchar(400), ITEM078    varchar(400), ITEM079    varchar(400), ITEM080    varchar(400)
        ,ITEM081    varchar(400), ITEM082    varchar(400), ITEM083    varchar(400), ITEM084    varchar(400), ITEM085    varchar(400)
        ,ITEM086    varchar(400), ITEM087    varchar(400), ITEM088    varchar(400), ITEM089    varchar(400), ITEM090    varchar(400)
        ,ITEM091    varchar(400), ITEM092    varchar(400), ITEM093    varchar(400), ITEM094    varchar(400), ITEM095    varchar(400)
        ,ITEM096    varchar(400), ITEM097    varchar(400), ITEM098    varchar(400), ITEM099    varchar(400), ITEM100    varchar(400)
        ,ITEM101    varchar(400), ITEM102    varchar(400), ITEM103    varchar(400), ITEM104    varchar(400), ITEM105    varchar(400)
        ,ITEM106    varchar(400), ITEM107    varchar(400), ITEM108    varchar(400), ITEM109    varchar(400), ITEM110    varchar(400)
        ,ITEM111    varchar(400), ITEM112    varchar(400), ITEM113    varchar(400), ITEM114    varchar(400), ITEM115    varchar(400)
        ,ITEM116    varchar(400), ITEM117    varchar(400), ITEM118    varchar(400), ITEM119    varchar(400), ITEM120    varchar(400)
        ,ITEM121    varchar(400), ITEM122    varchar(400), ITEM123    varchar(400), ITEM124    varchar(400), ITEM125    varchar(400)
        ,ITEM126    varchar(400), ITEM127    varchar(400), ITEM128    varchar(400), ITEM129    varchar(400), ITEM130    varchar(400)
        ,ITEM131    varchar(400), ITEM132    varchar(400), ITEM133    varchar(400), ITEM134    varchar(400), ITEM135    varchar(400)
        ,ITEM136    varchar(400), ITEM137    varchar(400), ITEM138    varchar(400), ITEM139    varchar(400), ITEM140    varchar(400)
        ,ITEM141    varchar(400), ITEM142    varchar(400), ITEM143    varchar(400), ITEM144    varchar(400), ITEM145    varchar(400)
        ,ITEM146    varchar(400), ITEM147    varchar(400), ITEM148    varchar(400), ITEM149    varchar(400), ITEM150    varchar(400)
        ,ITEM151    varchar(400), ITEM152    varchar(400), ITEM153    varchar(400), ITEM154    varchar(400), ITEM155    varchar(400)
        ,ITEM156    varchar(400), ITEM157    varchar(400), ITEM158    varchar(400), ITEM159    varchar(400), ITEM160    varchar(400)
        ,ITEM161    varchar(400), ITEM162    varchar(400), ITEM163    varchar(400), ITEM164    varchar(400), ITEM165    varchar(400)
        ,ITEM166    varchar(400), ITEM167    varchar(400), ITEM168    varchar(400), ITEM169    varchar(400), ITEM170    varchar(400)
        ,ITEM171    varchar(400), ITEM172    varchar(400), ITEM173    varchar(400), ITEM174    varchar(400), ITEM175    varchar(400)
        ,ITEM176    varchar(400), ITEM177    varchar(400), ITEM178    varchar(400), ITEM179    varchar(400), ITEM180    varchar(400)
        ,ITEM181    varchar(400), ITEM182    varchar(400), ITEM183    varchar(400), ITEM184    varchar(400), ITEM185    varchar(400)
        ,ITEM186    varchar(400), ITEM187    varchar(400), ITEM188    varchar(400), ITEM189    varchar(400), ITEM190    varchar(400)
        ,ITEM191    varchar(400), ITEM192    varchar(400), ITEM193    varchar(400), ITEM194    varchar(400), ITEM195    varchar(400)
        ,ITEM196    varchar(400), ITEM197    varchar(400), ITEM198    varchar(400), ITEM199    varchar(400), ITEM200    varchar(400)
        ,ITEM201    varchar(400), ITEM202    varchar(400), ITEM203    varchar(400), ITEM204    varchar(400), ITEM205    varchar(400)
        ,ITEM206    varchar(400), ITEM207    varchar(400), ITEM208    varchar(400), ITEM209    varchar(400), ITEM210    varchar(400)
        ,ITEM211    varchar(400), ITEM212    varchar(400), ITEM213    varchar(400), ITEM214    varchar(400), ITEM215    varchar(400)
        ,ITEM216    varchar(400), ITEM217    varchar(400), ITEM218    varchar(400), ITEM219    varchar(400), ITEM220    varchar(400)
        ,ITEM221    varchar(400), ITEM222    varchar(400), ITEM223    varchar(400), ITEM224    varchar(400), ITEM225    varchar(400)
        ,ITEM226    varchar(400), ITEM227    varchar(400), ITEM228    varchar(400), ITEM229    varchar(400), ITEM230    varchar(400)
        ,ITEM231    varchar(400), ITEM232    varchar(400), ITEM233    varchar(400), ITEM234    varchar(400), ITEM235    varchar(400)
        ,ITEM236    varchar(400), ITEM237    varchar(400), ITEM238    varchar(400), ITEM239    varchar(400), ITEM240    varchar(400)
        ,ITEM241    varchar(400), ITEM242    varchar(400), ITEM243    varchar(400), ITEM244    varchar(400), ITEM245    varchar(400)
        ,ITEM246    varchar(400), ITEM247    varchar(400), ITEM248    varchar(400), ITEM249    varchar(400), ITEM250    varchar(400)
    );

CREATE TYPE sfipepathreportwkinsertbatch_createerepwkdata_type_key AS (
         wkHktCd            char(6)
        ,wkKeyItem1         varchar(400)
        ,wkKeyItem2         varchar(400)
        ,wkKeyItem3         varchar(400)
        ,wkKeyItem4         varchar(400)
        ,wkKeyItem5         varchar(400)
        ,wkKeyItem6         varchar(400)
        ,wkKeyItem7         varchar(400)
        ,wkKeyItem8         varchar(400)
        ,wkKeyItem9         varchar(400)
        ,wkKeyItem10        varchar(400)
    );


CREATE OR REPLACE PROCEDURE sfipepathreportwkinsertbatch_createsql (
    l_inMode TEXT,
    l_inItakuKaishaCd TEXT,
    l_inSakuseiYmd TEXT,
    INOUT gSql text,            -- Đổi sang TEXT
    INOUT gWhereDispatch text,  -- Đổi sang TEXT
    IN gChohyoId char(11),
    IN gDispatchFlgItem char(7),
    IN gKensakuItem1 char(7),
    IN gKensakuItem2 char(7),
    IN gKensakuItem3 char(7),
    IN gKensakuItem4 char(7),
    IN gKensakuItem5 char(7),
    IN gKensakuItem6 char(7),
    IN gKensakuItem7 char(7),
    IN gKensakuItem8 char(7),
    IN gKensakuItem9 char(7),
    IN gKensakuItem10 char(7),
    IN gEpathSendYmdItem char(7),
    IN gIsinCdItem char(12),
    IN gKeyItem char(7),
    IN gRedOptionFlg character(1)
) AS $body$
DECLARE
    wkTableNm           varchar(50);
    -- Các biến chứa đoạn SQL con
    wkKensakuColumn1    text;
    wkKensakuColumn2    text;
    wkKensakuColumn3    text;
    wkKensakuColumn4    text;
    wkKensakuColumn5    text;
    wkKensakuColumn6    text;
    wkKensakuColumn7    text;
    wkKensakuColumn8    text;
    wkKensakuColumn9    text;
    wkKensakuColumn10   text;
BEGIN
    -- 取得元テーブル
    IF l_inMode = '9' THEN
        -- 送信日到来分はプールテーブル
        wkTableNm := 'EPATH_REPORT_WK_POOL';
    ELSE
        -- 当日作成分は帳票wk
        wkTableNm := 'SREPORT_WK';
    END IF;

    -- 検索条件_請求書発送区分
    IF coalesce(trim(both gDispatchFlgItem)::text, '') = '' THEN
        gWhereDispatch := ' ';
    ELSE
        gWhereDispatch := '   AND SC16.' || gDispatchFlgItem || ' IN (''3'', ''4'', ''6'') ';
    END IF;

    -- e.parth連携用の場合（当日作成分(プール) 以外）、キー項目を取得
    IF l_inMode != '1' THEN
        -- FIX: Thay thế DECODE bằng CASE WHEN cho Postgres chuẩn
        IF (trim(both gKensakuItem1) IS NOT NULL AND (trim(both gKensakuItem1))::text <> '') THEN
            wkKensakuColumn1 := 'CASE WHEN TRIM(''' || gKensakuItem1 || ''') = '''' THEN '' '' ELSE SC16.' || gKensakuItem1 || ' END';
        ELSE
            wkKensakuColumn1 := 'CASE WHEN TRIM(''' || gKensakuItem1 || ''') = '''' THEN '' '' ELSE '' '' END';
        END IF;

        IF (trim(both gKensakuItem2) IS NOT NULL AND (trim(both gKensakuItem2))::text <> '') THEN
            wkKensakuColumn2 := 'CASE WHEN TRIM(''' || gKensakuItem2 || ''') = '''' THEN '' '' ELSE SC16.' || gKensakuItem2 || ' END';
        ELSE
            wkKensakuColumn2 := 'CASE WHEN TRIM(''' || gKensakuItem2 || ''') = '''' THEN '' '' ELSE '' '' END';
        END IF;

        IF (trim(both gKensakuItem3) IS NOT NULL AND (trim(both gKensakuItem3))::text <> '') THEN
            wkKensakuColumn3 := 'CASE WHEN TRIM(''' || gKensakuItem3 || ''') = '''' THEN '' '' ELSE SC16.' || gKensakuItem3 || ' END';
        ELSE
            wkKensakuColumn3 := 'CASE WHEN TRIM(''' || gKensakuItem3 || ''') = '''' THEN '' '' ELSE '' '' END';
        END IF;

        IF (trim(both gKensakuItem4) IS NOT NULL AND (trim(both gKensakuItem4))::text <> '') THEN
            wkKensakuColumn4 := 'CASE WHEN TRIM(''' || gKensakuItem4 || ''') = '''' THEN '' '' ELSE SC16.' || gKensakuItem4 || ' END';
        ELSE
            wkKensakuColumn4 := 'CASE WHEN TRIM(''' || gKensakuItem4 || ''') = '''' THEN '' '' ELSE '' '' END';
        END IF;

        IF (trim(both gKensakuItem5) IS NOT NULL AND (trim(both gKensakuItem5))::text <> '') THEN
            wkKensakuColumn5 := 'CASE WHEN TRIM(''' || gKensakuItem5 || ''') = '''' THEN '' '' ELSE SC16.' || gKensakuItem5 || ' END';
        ELSE
            wkKensakuColumn5 := 'CASE WHEN TRIM(''' || gKensakuItem5 || ''') = '''' THEN '' '' ELSE '' '' END';
        END IF;

        IF (trim(both gKensakuItem6) IS NOT NULL AND (trim(both gKensakuItem6))::text <> '') THEN
            wkKensakuColumn6 := 'CASE WHEN TRIM(''' || gKensakuItem6 || ''') = '''' THEN '' '' ELSE SC16.' || gKensakuItem6 || ' END';
        ELSE
            wkKensakuColumn6 := 'CASE WHEN TRIM(''' || gKensakuItem6 || ''') = '''' THEN '' '' ELSE '' '' END';
        END IF;

        IF (trim(both gKensakuItem7) IS NOT NULL AND (trim(both gKensakuItem7))::text <> '') THEN
            wkKensakuColumn7 := 'CASE WHEN TRIM(''' || gKensakuItem7 || ''') = '''' THEN '' '' ELSE SC16.' || gKensakuItem7 || ' END';
        ELSE
            wkKensakuColumn7 := 'CASE WHEN TRIM(''' || gKensakuItem7 || ''') = '''' THEN '' '' ELSE '' '' END';
        END IF;

        IF (trim(both gKensakuItem8) IS NOT NULL AND (trim(both gKensakuItem8))::text <> '') THEN
            wkKensakuColumn8 := 'CASE WHEN TRIM(''' || gKensakuItem8 || ''') = '''' THEN '' '' ELSE SC16.' || gKensakuItem8 || ' END';
        ELSE
            wkKensakuColumn8 := 'CASE WHEN TRIM(''' || gKensakuItem8 || ''') = '''' THEN '' '' ELSE '' '' END';
        END IF;

        IF (trim(both gKensakuItem9) IS NOT NULL AND (trim(both gKensakuItem9))::text <> '') THEN
            wkKensakuColumn9 := 'CASE WHEN TRIM(''' || gKensakuItem9 || ''') = '''' THEN '' '' ELSE SC16.' || gKensakuItem9 || ' END';
        ELSE
            wkKensakuColumn9 := 'CASE WHEN TRIM(''' || gKensakuItem9 || ''') = '''' THEN '' '' ELSE '' '' END';
        END IF;

        IF (trim(both gKensakuItem10) IS NOT NULL AND (trim(both gKensakuItem10))::text <> '') THEN
            wkKensakuColumn10 := 'CASE WHEN TRIM(''' || gKensakuItem10 || ''') = '''' THEN '' '' ELSE SC16.' || gKensakuItem10 || ' END';
        ELSE
            wkKensakuColumn10 := 'CASE WHEN TRIM(''' || gKensakuItem10 || ''') = '''' THEN '' '' ELSE '' '' END';
        END IF;
    END IF;

    -- SELECT文生成
    gSql := 'SELECT '
        || ' X08.HKT_CD ';
    
    IF l_inMode != '1' THEN
        gSql := gSql
        || ',' || wkKensakuColumn1 || ' AS KEY_ITEM1 '
        || ',' || wkKensakuColumn2 || ' AS KEY_ITEM2 '
        || ',' || wkKensakuColumn3 || ' AS KEY_ITEM3 '
        || ',' || wkKensakuColumn4 || ' AS KEY_ITEM4 '
        || ',' || wkKensakuColumn5 || ' AS KEY_ITEM5 '
        || ',' || wkKensakuColumn6 || ' AS KEY_ITEM6 '
        || ',' || wkKensakuColumn7 || ' AS KEY_ITEM7 '
        || ',' || wkKensakuColumn8 || ' AS KEY_ITEM8 '
        || ',' || wkKensakuColumn9 || ' AS KEY_ITEM9 '
        || ',' || wkKensakuColumn10 || ' AS KEY_ITEM10 ';
    ELSE
        gSql := gSql
        || ',NULL AS KEY_ITEM1 '
        || ',NULL AS KEY_ITEM2 '
        || ',NULL AS KEY_ITEM3 '
        || ',NULL AS KEY_ITEM4 '
        || ',NULL AS KEY_ITEM5 '
        || ',NULL AS KEY_ITEM6 '
        || ',NULL AS KEY_ITEM7 '
        || ',NULL AS KEY_ITEM8 '
        || ',NULL AS KEY_ITEM9 '
        || ',NULL AS KEY_ITEM10 ';
    END IF;

    IF l_inMode = '1' THEN
        gSql := gSql || ',SC16.' || gEpathSendYmdItem || ' AS EPATH_SEND_YMD ';
    ELSE
        gSql := gSql || ',NULL AS EPATH_SEND_YMD ';
    END IF;

    IF l_inMode = '1' AND (gIsinCdItem IS NOT NULL AND gIsinCdItem::text <> '') THEN
        gSql := gSql || ',TRIM(SC16.' || gIsinCdItem || ') AS ISIN_CD ';
    ELSE
        gSql := gSql || ',NULL AS ISIN_CD ';
    END IF;

    -- Thêm các cột ITEM từ 001 đến 250
    gSql := gSql
        || ',SC16.ITEM001, SC16.ITEM002, SC16.ITEM003, SC16.ITEM004, SC16.ITEM005'
        || ',SC16.ITEM006, SC16.ITEM007, SC16.ITEM008, SC16.ITEM009, SC16.ITEM010'
        || ',SC16.ITEM011, SC16.ITEM012, SC16.ITEM013, SC16.ITEM014, SC16.ITEM015'
        || ',SC16.ITEM016, SC16.ITEM017, SC16.ITEM018, SC16.ITEM019, SC16.ITEM020'
        || ',SC16.ITEM021, SC16.ITEM022, SC16.ITEM023, SC16.ITEM024, SC16.ITEM025'
        || ',SC16.ITEM026, SC16.ITEM027, SC16.ITEM028, SC16.ITEM029, SC16.ITEM030'
        || ',SC16.ITEM031, SC16.ITEM032, SC16.ITEM033, SC16.ITEM034, SC16.ITEM035'
        || ',SC16.ITEM036, SC16.ITEM037, SC16.ITEM038, SC16.ITEM039, SC16.ITEM040'
        || ',SC16.ITEM041, SC16.ITEM042, SC16.ITEM043, SC16.ITEM044, SC16.ITEM045'
        || ',SC16.ITEM046, SC16.ITEM047, SC16.ITEM048, SC16.ITEM049, SC16.ITEM050'
        || ',SC16.ITEM051, SC16.ITEM052, SC16.ITEM053, SC16.ITEM054, SC16.ITEM055'
        || ',SC16.ITEM056, SC16.ITEM057, SC16.ITEM058, SC16.ITEM059, SC16.ITEM060'
        || ',SC16.ITEM061, SC16.ITEM062, SC16.ITEM063, SC16.ITEM064, SC16.ITEM065'
        || ',SC16.ITEM066, SC16.ITEM067, SC16.ITEM068, SC16.ITEM069, SC16.ITEM070'
        || ',SC16.ITEM071, SC16.ITEM072, SC16.ITEM073, SC16.ITEM074, SC16.ITEM075'
        || ',SC16.ITEM076, SC16.ITEM077, SC16.ITEM078, SC16.ITEM079, SC16.ITEM080'
        || ',SC16.ITEM081, SC16.ITEM082, SC16.ITEM083, SC16.ITEM084, SC16.ITEM085'
        || ',SC16.ITEM086, SC16.ITEM087, SC16.ITEM088, SC16.ITEM089, SC16.ITEM090'
        || ',SC16.ITEM091, SC16.ITEM092, SC16.ITEM093, SC16.ITEM094, SC16.ITEM095'
        || ',SC16.ITEM096, SC16.ITEM097, SC16.ITEM098, SC16.ITEM099, SC16.ITEM100'
        || ',SC16.ITEM101, SC16.ITEM102, SC16.ITEM103, SC16.ITEM104, SC16.ITEM105'
        || ',SC16.ITEM106, SC16.ITEM107, SC16.ITEM108, SC16.ITEM109, SC16.ITEM110'
        || ',SC16.ITEM111, SC16.ITEM112, SC16.ITEM113, SC16.ITEM114, SC16.ITEM115'
        || ',SC16.ITEM116, SC16.ITEM117, SC16.ITEM118, SC16.ITEM119, SC16.ITEM120'
        || ',SC16.ITEM121, SC16.ITEM122, SC16.ITEM123, SC16.ITEM124, SC16.ITEM125'
        || ',SC16.ITEM126, SC16.ITEM127, SC16.ITEM128, SC16.ITEM129, SC16.ITEM130'
        || ',SC16.ITEM131, SC16.ITEM132, SC16.ITEM133, SC16.ITEM134, SC16.ITEM135'
        || ',SC16.ITEM136, SC16.ITEM137, SC16.ITEM138, SC16.ITEM139, SC16.ITEM140'
        || ',SC16.ITEM141, SC16.ITEM142, SC16.ITEM143, SC16.ITEM144, SC16.ITEM145'
        || ',SC16.ITEM146, SC16.ITEM147, SC16.ITEM148, SC16.ITEM149, SC16.ITEM150'
        || ',SC16.ITEM151, SC16.ITEM152, SC16.ITEM153, SC16.ITEM154, SC16.ITEM155'
        || ',SC16.ITEM156, SC16.ITEM157, SC16.ITEM158, SC16.ITEM159, SC16.ITEM160'
        || ',SC16.ITEM161, SC16.ITEM162, SC16.ITEM163, SC16.ITEM164, SC16.ITEM165'
        || ',SC16.ITEM166, SC16.ITEM167, SC16.ITEM168, SC16.ITEM169, SC16.ITEM170'
        || ',SC16.ITEM171, SC16.ITEM172, SC16.ITEM173, SC16.ITEM174, SC16.ITEM175'
        || ',SC16.ITEM176, SC16.ITEM177, SC16.ITEM178, SC16.ITEM179, SC16.ITEM180'
        || ',SC16.ITEM181, SC16.ITEM182, SC16.ITEM183, SC16.ITEM184, SC16.ITEM185'
        || ',SC16.ITEM186, SC16.ITEM187, SC16.ITEM188, SC16.ITEM189, SC16.ITEM190'
        || ',SC16.ITEM191, SC16.ITEM192, SC16.ITEM193, SC16.ITEM194, SC16.ITEM195'
        || ',SC16.ITEM196, SC16.ITEM197, SC16.ITEM198, SC16.ITEM199, SC16.ITEM200'
        || ',SC16.ITEM201, SC16.ITEM202, SC16.ITEM203, SC16.ITEM204, SC16.ITEM205'
        || ',SC16.ITEM206, SC16.ITEM207, SC16.ITEM208, SC16.ITEM209, SC16.ITEM210'
        || ',SC16.ITEM211, SC16.ITEM212, SC16.ITEM213, SC16.ITEM214, SC16.ITEM215'
        || ',SC16.ITEM216, SC16.ITEM217, SC16.ITEM218, SC16.ITEM219, SC16.ITEM220'
        || ',SC16.ITEM221, SC16.ITEM222, SC16.ITEM223, SC16.ITEM224, SC16.ITEM225'
        || ',SC16.ITEM226, SC16.ITEM227, SC16.ITEM228, SC16.ITEM229, SC16.ITEM230'
        || ',SC16.ITEM231, SC16.ITEM232, SC16.ITEM233, SC16.ITEM234, SC16.ITEM235'
        || ',SC16.ITEM236, SC16.ITEM237, SC16.ITEM238, SC16.ITEM239, SC16.ITEM240'
        || ',SC16.ITEM241, SC16.ITEM242, SC16.ITEM243, SC16.ITEM244, SC16.ITEM245'
        || ',SC16.ITEM246, SC16.ITEM247, SC16.ITEM248, SC16.ITEM249, SC16.ITEM250 '
    || 'FROM ' || wkTableNm || ' SC16,'
    || '     EPATH_KAIIN_HAKKOTAI X08 '
    || ' WHERE SC16.KEY_CD = ''' || l_inItakuKaishaCd || ''' '
    || '   AND SC16.CHOHYO_KBN = ''1'' '
    || '   AND SC16.SAKUSEI_YMD = ''' || l_inSakuseiYmd || ''' '
    || '   AND SC16.CHOHYO_ID = ''' || gChohyoId || ''' '
    || '   AND SC16.HEADER_FLG = ''1'' '
    || '   AND X08.ITAKU_KAISHA_CD = SC16.KEY_CD '
    || '   AND X08.HKT_CD = SC16.' || gKeyItem || ' '
    || '   AND X08.CHOHYO_ID = SC16.CHOHYO_ID '
    || gWhereDispatch;

    -- RedOption Check
    IF gRedOptionFlg = '1' AND l_inMode = '9' THEN
        gSql := gSql
        || '   AND (SC16.MGR_CD IS NULL '
        || '       OR EXISTS (SELECT 1 FROM MGR_KIHON MG1, MGR_KIHON2 BT03 '
        || '                  WHERE SC16.KEY_CD = MG1.ITAKU_KAISHA_CD '
        || '                    AND SC16.MGR_CD = MG1.MGR_CD '
        || '                    AND MG1.ITAKU_KAISHA_CD = BT03.ITAKU_KAISHA_CD '
        || '                    AND MG1.MGR_CD = BT03.MGR_CD '
        || '                    AND BT03.DISPATCH_FLG IN (''3'', ''4'', ''6'') '
        || '                 ) '
        || '       ) ';
    END IF;

    gSql := gSql || ' ORDER BY';
    IF gChohyoId = 'IP030004411' OR gChohyoId = 'IP030004412' THEN
        gSql := gSql || '     SC16.ITEM013,';
    END IF;
    gSql := gSql || '     SC16.SEQ_NO';

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$body$
LANGUAGE PLPGSQL;


-- 5. Procedure tạo dữ liệu (sfipepathreportwkinsertbatch_createerepwkdata)
CREATE OR REPLACE PROCEDURE sfipepathreportwkinsertbatch_createerepwkdata () AS $body$
DECLARE
    -- Lấy state từ bảng tạm
    rec_state           RECORD;
    
    wkHktCd             char(6);
    wkIsinCd            char(12);
    wkShrYmd            char(8);
    wkKeyItem1          varchar(400);
    wkKeyItem2          varchar(400);
    wkKeyItem3          varchar(400);
    wkKeyItem4          varchar(400);
    wkKeyItem5          varchar(400);
    wkKeyItem6          varchar(400);
    wkKeyItem7          varchar(400);
    wkKeyItem8          varchar(400);
    wkKeyItem9          varchar(400);
    wkKeyItem10         varchar(400);
    
    -- Local variables to hold state pulled from temp table
    l_gSeqNo            numeric(10);
    l_gSeqNo2           numeric(10);
    l_gChohyoId         char(11);
    l_gKensakuNm1       varchar(20);
    l_gKensakuNm2       varchar(20);
    l_gKensakuNm3       varchar(20);
    l_gKensakuNm4       varchar(20);
    l_gKensakuNm5       varchar(20);
    l_gKensakuNm6       varchar(20);
    l_gKensakuNm7       varchar(20);
    l_gKensakuNm8       varchar(20);
    l_gKensakuNm9       varchar(20);
    l_gKensakuNm10      varchar(20);
    l_inItakuKaishaCd   text;
    l_inSakuseiYmd      text;
    l_gSql              text;
    
    -- Record/Cursor
    recSreport          sfIpEpathReportWkInsertBatch_TYPE_RECORD;
    curReport           refcursor;
    
    key                 sfIpEpathReportWkInsertBatch_createErepWkData_TYPE_KEY;
    SPACE               text := ' ';

BEGIN
    -- 1. Lấy dữ liệu từ bảng Global State
    SELECT * INTO rec_state FROM sfipepath_global_state WHERE session_key = 'main';
    
    l_gSeqNo := 0;
    l_gSeqNo2 := rec_state.gSeqNo2; -- Mặc dù khởi tạo sau, cứ lấy ra
    l_gChohyoId := rec_state.gChohyoId;
    l_gKensakuNm1 := rec_state.gKensakuNm1; l_gKensakuNm2 := rec_state.gKensakuNm2;
    l_gKensakuNm3 := rec_state.gKensakuNm3; l_gKensakuNm4 := rec_state.gKensakuNm4;
    l_gKensakuNm5 := rec_state.gKensakuNm5; l_gKensakuNm6 := rec_state.gKensakuNm6;
    l_gKensakuNm7 := rec_state.gKensakuNm7; l_gKensakuNm8 := rec_state.gKensakuNm8;
    l_gKensakuNm9 := rec_state.gKensakuNm9; l_gKensakuNm10 := rec_state.gKensakuNm10;
    l_inItakuKaishaCd := rec_state.l_inItakuKaishaCd;
    l_inSakuseiYmd := rec_state.l_inSakuseiYmd;
    l_gSql := rec_state.gSql;

    -- Init vars
    key.wkHktCd := SPACE;
    key.wkKeyItem1 := SPACE; key.wkKeyItem2 := SPACE; key.wkKeyItem3 := SPACE;
    key.wkKeyItem4 := SPACE; key.wkKeyItem5 := SPACE; key.wkKeyItem6 := SPACE;
    key.wkKeyItem7 := SPACE; key.wkKeyItem8 := SPACE; key.wkKeyItem9 := SPACE;
    key.wkKeyItem10 := SPACE;
    wkIsinCd := SPACE;
    wkShrYmd := SPACE;

    -- Loop
    OPEN curReport FOR EXECUTE l_gSql;
    LOOP
        FETCH curReport INTO recSreport;
        EXIT WHEN NOT FOUND;

        wkHktCd := recSreport.HKT_CD;
        wkKeyItem1 := recSreport.KEY_ITEM1; wkKeyItem2 := recSreport.KEY_ITEM2;
        wkKeyItem3 := recSreport.KEY_ITEM3; wkKeyItem4 := recSreport.KEY_ITEM4;
        wkKeyItem5 := recSreport.KEY_ITEM5; wkKeyItem6 := recSreport.KEY_ITEM6;
        wkKeyItem7 := recSreport.KEY_ITEM7; wkKeyItem8 := recSreport.KEY_ITEM8;
        wkKeyItem9 := recSreport.KEY_ITEM9; wkKeyItem10 := recSreport.KEY_ITEM10;

        -- Break logic
        IF (l_gKensakuNm1 = '支払日' AND (key.wkKeyItem1 <> wkKeyItem1)
            OR (key.wkKeyItem2 <> wkKeyItem2 AND l_gKensakuNm2 NOT LIKE '%金額%')
            OR (key.wkKeyItem3 <> wkKeyItem3 AND l_gKensakuNm3 NOT LIKE '%金額%')
            OR (key.wkKeyItem4 <> wkKeyItem4 AND l_gKensakuNm4 NOT LIKE '%金額%')
            OR (key.wkKeyItem5 <> wkKeyItem5 AND l_gKensakuNm5 NOT LIKE '%金額%')
            OR (key.wkKeyItem6 <> wkKeyItem6 AND l_gKensakuNm6 NOT LIKE '%金額%')
            OR (key.wkKeyItem7 <> wkKeyItem7 AND l_gKensakuNm7 NOT LIKE '%金額%')
            OR (key.wkKeyItem8 <> wkKeyItem8 AND l_gKensakuNm8 NOT LIKE '%金額%')
            OR (key.wkKeyItem9 <> wkKeyItem9 AND l_gKensakuNm9 NOT LIKE '%金額%')
            OR (key.wkKeyItem10 <> wkKeyItem10 AND l_gKensakuNm10 NOT LIKE '%金額%'))
            OR key.wkHktCd <> wkHktCd
        THEN
            key.wkHktCd := wkHktCd;
            key.wkKeyItem1 := wkKeyItem1; key.wkKeyItem2 := wkKeyItem2;
            key.wkKeyItem3 := wkKeyItem3; key.wkKeyItem4 := wkKeyItem4;
            key.wkKeyItem5 := wkKeyItem5; key.wkKeyItem6 := wkKeyItem6;
            key.wkKeyItem7 := wkKeyItem7; key.wkKeyItem8 := wkKeyItem8;
            key.wkKeyItem9 := wkKeyItem9; key.wkKeyItem10 := wkKeyItem10;
            l_gSeqNo2 := 1;

            IF l_gKensakuNm1 = '支払日' THEN
                wkShrYmd := pkEpath.seirekiChangeReverse(wkKeyItem1);
            END IF;

            l_gSeqNo := l_gSeqNo + 1;
            
            -- Call external pkg
            CALL pkEpath.insertPrintHeader(l_inItakuKaishaCd, pkconstant.BATCH_USER(), '1', l_inSakuseiYmd, l_gChohyoId, l_gSeqNo, wkHktCd, ' ', wkIsinCd, wkShrYmd);
        END IF;

        -- Call external pkg
        CALL pkEpath.insertPrintData(
             l_inKeyCd => l_inItakuKaishaCd
            ,l_inUserId => pkconstant.BATCH_USER()
            ,l_inChohyoKbn => '1'
            ,l_inSakuseiYmd => l_inSakuseiYmd
            ,l_inChohyoId => l_gChohyoId
            ,l_inSeqNo => l_gSeqNo
            ,l_inSeqNo2 => l_gSeqNo2
            ,l_inHktCd => wkHktCd
            ,l_inKkmemberCdM5k => ' '
            ,l_inIsinCd => wkIsinCd
            ,l_inShrYmd => wkShrYmd
            ,l_inHeaderFlg => '1'
            ,l_inItem001 => recSreport.ITEM001, l_inItem002 => recSreport.ITEM002, l_inItem003 => recSreport.ITEM003
            ,l_inItem004 => recSreport.ITEM004, l_inItem005 => recSreport.ITEM005, l_inItem006 => recSreport.ITEM006
            ,l_inItem007 => recSreport.ITEM007, l_inItem008 => recSreport.ITEM008, l_inItem009 => recSreport.ITEM009
            ,l_inItem010 => recSreport.ITEM010, l_inItem011 => recSreport.ITEM011, l_inItem012 => recSreport.ITEM012
            ,l_inItem013 => recSreport.ITEM013, l_inItem014 => recSreport.ITEM014, l_inItem015 => recSreport.ITEM015
            ,l_inItem016 => recSreport.ITEM016, l_inItem017 => recSreport.ITEM017, l_inItem018 => recSreport.ITEM018
            ,l_inItem019 => recSreport.ITEM019, l_inItem020 => recSreport.ITEM020, l_inItem021 => recSreport.ITEM021
            ,l_inItem022 => recSreport.ITEM022, l_inItem023 => recSreport.ITEM023, l_inItem024 => recSreport.ITEM024
            ,l_inItem025 => recSreport.ITEM025, l_inItem026 => recSreport.ITEM026, l_inItem027 => recSreport.ITEM027
            ,l_inItem028 => recSreport.ITEM028, l_inItem029 => recSreport.ITEM029, l_inItem030 => recSreport.ITEM030
            ,l_inItem031 => recSreport.ITEM031, l_inItem032 => recSreport.ITEM032, l_inItem033 => recSreport.ITEM033
            ,l_inItem034 => recSreport.ITEM034, l_inItem035 => recSreport.ITEM035, l_inItem036 => recSreport.ITEM036
            ,l_inItem037 => recSreport.ITEM037, l_inItem038 => recSreport.ITEM038, l_inItem039 => recSreport.ITEM039
            ,l_inItem040 => recSreport.ITEM040, l_inItem041 => recSreport.ITEM041, l_inItem042 => recSreport.ITEM042
            ,l_inItem043 => recSreport.ITEM043, l_inItem044 => recSreport.ITEM044, l_inItem045 => recSreport.ITEM045
            ,l_inItem046 => recSreport.ITEM046, l_inItem047 => recSreport.ITEM047, l_inItem048 => recSreport.ITEM048
            ,l_inItem049 => recSreport.ITEM049, l_inItem050 => recSreport.ITEM050, l_inItem051 => recSreport.ITEM051
            ,l_inItem052 => recSreport.ITEM052, l_inItem053 => recSreport.ITEM053, l_inItem054 => recSreport.ITEM054
            ,l_inItem055 => recSreport.ITEM055, l_inItem056 => recSreport.ITEM056, l_inItem057 => recSreport.ITEM057
            ,l_inItem058 => recSreport.ITEM058, l_inItem059 => recSreport.ITEM059, l_inItem060 => recSreport.ITEM060
            ,l_inItem061 => recSreport.ITEM061, l_inItem062 => recSreport.ITEM062, l_inItem063 => recSreport.ITEM063
            ,l_inItem064 => recSreport.ITEM064, l_inItem065 => recSreport.ITEM065, l_inItem066 => recSreport.ITEM066
            ,l_inItem067 => recSreport.ITEM067, l_inItem068 => recSreport.ITEM068, l_inItem069 => recSreport.ITEM069
            ,l_inItem070 => recSreport.ITEM070, l_inItem071 => recSreport.ITEM071, l_inItem072 => recSreport.ITEM072
            ,l_inItem073 => recSreport.ITEM073, l_inItem074 => recSreport.ITEM074, l_inItem075 => recSreport.ITEM075
            ,l_inItem076 => recSreport.ITEM076, l_inItem077 => recSreport.ITEM077, l_inItem078 => recSreport.ITEM078
            ,l_inItem079 => recSreport.ITEM079, l_inItem080 => recSreport.ITEM080, l_inItem081 => recSreport.ITEM081
            ,l_inItem082 => recSreport.ITEM082, l_inItem083 => recSreport.ITEM083, l_inItem084 => recSreport.ITEM084
            ,l_inItem085 => recSreport.ITEM085, l_inItem086 => recSreport.ITEM086, l_inItem087 => recSreport.ITEM087
            ,l_inItem088 => recSreport.ITEM088, l_inItem089 => recSreport.ITEM089, l_inItem090 => recSreport.ITEM090
            ,l_inItem091 => recSreport.ITEM091, l_inItem092 => recSreport.ITEM092, l_inItem093 => recSreport.ITEM093
            ,l_inItem094 => recSreport.ITEM094, l_inItem095 => recSreport.ITEM095, l_inItem096 => recSreport.ITEM096
            ,l_inItem097 => recSreport.ITEM097, l_inItem098 => recSreport.ITEM098, l_inItem099 => recSreport.ITEM099
            ,l_inItem100 => recSreport.ITEM100, l_inItem101 => recSreport.ITEM101, l_inItem102 => recSreport.ITEM102
            ,l_inItem103 => recSreport.ITEM103, l_inItem104 => recSreport.ITEM104, l_inItem105 => recSreport.ITEM105
            ,l_inItem106 => recSreport.ITEM106, l_inItem107 => recSreport.ITEM107, l_inItem108 => recSreport.ITEM108
            ,l_inItem109 => recSreport.ITEM109, l_inItem110 => recSreport.ITEM110, l_inItem111 => recSreport.ITEM111
            ,l_inItem112 => recSreport.ITEM112, l_inItem113 => recSreport.ITEM113, l_inItem114 => recSreport.ITEM114
            ,l_inItem115 => recSreport.ITEM115, l_inItem116 => recSreport.ITEM116, l_inItem117 => recSreport.ITEM117
            ,l_inItem118 => recSreport.ITEM118, l_inItem119 => recSreport.ITEM119, l_inItem120 => recSreport.ITEM120
            ,l_inItem121 => recSreport.ITEM121, l_inItem122 => recSreport.ITEM122, l_inItem123 => recSreport.ITEM123
            ,l_inItem124 => recSreport.ITEM124, l_inItem125 => recSreport.ITEM125, l_inItem126 => recSreport.ITEM126
            ,l_inItem127 => recSreport.ITEM127, l_inItem128 => recSreport.ITEM128, l_inItem129 => recSreport.ITEM129
            ,l_inItem130 => recSreport.ITEM130, l_inItem131 => recSreport.ITEM131, l_inItem132 => recSreport.ITEM132
            ,l_inItem133 => recSreport.ITEM133, l_inItem134 => recSreport.ITEM134, l_inItem135 => recSreport.ITEM135
            ,l_inItem136 => recSreport.ITEM136, l_inItem137 => recSreport.ITEM137, l_inItem138 => recSreport.ITEM138
            ,l_inItem139 => recSreport.ITEM139, l_inItem140 => recSreport.ITEM140, l_inItem141 => recSreport.ITEM141
            ,l_inItem142 => recSreport.ITEM142, l_inItem143 => recSreport.ITEM143, l_inItem144 => recSreport.ITEM144
            ,l_inItem145 => recSreport.ITEM145, l_inItem146 => recSreport.ITEM146, l_inItem147 => recSreport.ITEM147
            ,l_inItem148 => recSreport.ITEM148, l_inItem149 => recSreport.ITEM149, l_inItem150 => recSreport.ITEM150
            ,l_inItem151 => recSreport.ITEM151, l_inItem152 => recSreport.ITEM152, l_inItem153 => recSreport.ITEM153
            ,l_inItem154 => recSreport.ITEM154, l_inItem155 => recSreport.ITEM155, l_inItem156 => recSreport.ITEM156
            ,l_inItem157 => recSreport.ITEM157, l_inItem158 => recSreport.ITEM158, l_inItem159 => recSreport.ITEM159
            ,l_inItem160 => recSreport.ITEM160, l_inItem161 => recSreport.ITEM161, l_inItem162 => recSreport.ITEM162
            ,l_inItem163 => recSreport.ITEM163, l_inItem164 => recSreport.ITEM164, l_inItem165 => recSreport.ITEM165
            ,l_inItem166 => recSreport.ITEM166, l_inItem167 => recSreport.ITEM167, l_inItem168 => recSreport.ITEM168
            ,l_inItem169 => recSreport.ITEM169, l_inItem170 => recSreport.ITEM170, l_inItem171 => recSreport.ITEM171
            ,l_inItem172 => recSreport.ITEM172, l_inItem173 => recSreport.ITEM173, l_inItem174 => recSreport.ITEM174
            ,l_inItem175 => recSreport.ITEM175, l_inItem176 => recSreport.ITEM176, l_inItem177 => recSreport.ITEM177
            ,l_inItem178 => recSreport.ITEM178, l_inItem179 => recSreport.ITEM179, l_inItem180 => recSreport.ITEM180
            ,l_inItem181 => recSreport.ITEM181, l_inItem182 => recSreport.ITEM182, l_inItem183 => recSreport.ITEM183
            ,l_inItem184 => recSreport.ITEM184, l_inItem185 => recSreport.ITEM185, l_inItem186 => recSreport.ITEM186
            ,l_inItem187 => recSreport.ITEM187, l_inItem188 => recSreport.ITEM188, l_inItem189 => recSreport.ITEM189
            ,l_inItem190 => recSreport.ITEM190, l_inItem191 => recSreport.ITEM191, l_inItem192 => recSreport.ITEM192
            ,l_inItem193 => recSreport.ITEM193, l_inItem194 => recSreport.ITEM194, l_inItem195 => recSreport.ITEM195
            ,l_inItem196 => recSreport.ITEM196, l_inItem197 => recSreport.ITEM197, l_inItem198 => recSreport.ITEM198
            ,l_inItem199 => recSreport.ITEM199, l_inItem200 => recSreport.ITEM200, l_inItem201 => recSreport.ITEM201
            ,l_inItem202 => recSreport.ITEM202, l_inItem203 => recSreport.ITEM203, l_inItem204 => recSreport.ITEM204
            ,l_inItem205 => recSreport.ITEM205, l_inItem206 => recSreport.ITEM206, l_inItem207 => recSreport.ITEM207
            ,l_inItem208 => recSreport.ITEM208, l_inItem209 => recSreport.ITEM209, l_inItem210 => recSreport.ITEM210
            ,l_inItem211 => recSreport.ITEM211, l_inItem212 => recSreport.ITEM212, l_inItem213 => recSreport.ITEM213
            ,l_inItem214 => recSreport.ITEM214, l_inItem215 => recSreport.ITEM215, l_inItem216 => recSreport.ITEM216
            ,l_inItem217 => recSreport.ITEM217, l_inItem218 => recSreport.ITEM218, l_inItem219 => recSreport.ITEM219
            ,l_inItem220 => recSreport.ITEM220, l_inItem221 => recSreport.ITEM221, l_inItem222 => recSreport.ITEM222
            ,l_inItem223 => recSreport.ITEM223, l_inItem224 => recSreport.ITEM224, l_inItem225 => recSreport.ITEM225
            ,l_inItem226 => recSreport.ITEM226, l_inItem227 => recSreport.ITEM227, l_inItem228 => recSreport.ITEM228
            ,l_inItem229 => recSreport.ITEM229, l_inItem230 => recSreport.ITEM230, l_inItem231 => recSreport.ITEM231
            ,l_inItem232 => recSreport.ITEM232, l_inItem233 => recSreport.ITEM233, l_inItem234 => recSreport.ITEM234
            ,l_inItem235 => recSreport.ITEM235, l_inItem236 => recSreport.ITEM236, l_inItem237 => recSreport.ITEM237
            ,l_inItem238 => recSreport.ITEM238, l_inItem239 => recSreport.ITEM239, l_inItem240 => recSreport.ITEM240
            ,l_inItem241 => recSreport.ITEM241, l_inItem242 => recSreport.ITEM242, l_inItem243 => recSreport.ITEM243
            ,l_inItem244 => recSreport.ITEM244, l_inItem245 => recSreport.ITEM245, l_inItem246 => recSreport.ITEM246
            ,l_inItem247 => recSreport.ITEM247, l_inItem248 => recSreport.ITEM248, l_inItem249 => recSreport.ITEM249
            ,l_inItem250 => recSreport.ITEM250
            ,l_inKousinId => pkconstant.BATCH_USER()
            ,l_inSakuseiId => pkconstant.BATCH_USER()
        );
        l_gSeqNo2 := l_gSeqNo2 + 1;
    END LOOP;
    
    CLOSE curReport;
    
    -- Update state back to global table (sequence values updated)
    UPDATE sfipepath_global_state 
    SET gSeqNo = l_gSeqNo, gSeqNo2 = l_gSeqNo2
    WHERE session_key = 'main';

END;
$body$
LANGUAGE PLPGSQL;


-- 6. Main Function (sfipepathreportwkinsertbatch)
CREATE OR REPLACE FUNCTION sfipepathreportwkinsertbatch (
    l_inItakuKaishaCd TEXT,
    l_inSakuseiYmd TEXT
) RETURNS integer AS $body$
DECLARE
    SPACE               CONSTANT text := ' ';
    USER_ID             text;
    SP_ID               CONSTANT text := 'sfIpEpathReportWkInsertBatch';
    
    gRtnCd              integer := 0;
    gSql                text; -- Change to text
    gWhereDispatch      text; -- Change to text
    gChohyoId           char(11);
    gPoolFlg            char(1);
    gEpathSendYmdItem   char(7);
    gIsinCdItem         char(12);
    gDispatchFlgItem    char(7);
    gKeyItem            char(7);
    
    -- Local variables for search items
    gKensakuNm1         varchar(20); gKensakuItem1       char(7);
    gKensakuNm2         varchar(20); gKensakuItem2       char(7);
    gKensakuNm3         varchar(20); gKensakuItem3       char(7);
    gKensakuNm4         varchar(20); gKensakuItem4       char(7);
    gKensakuNm5         varchar(20); gKensakuItem5       char(7);
    gKensakuNm6         varchar(20); gKensakuItem6       char(7);
    gKensakuNm7         varchar(20); gKensakuItem7       char(7);
    gKensakuNm8         varchar(20); gKensakuItem8       char(7);
    gKensakuNm9         varchar(20); gKensakuItem9       char(7);
    gKensakuNm10        varchar(20); gKensakuItem10      char(7);
    
    gSeqNo              numeric(10);
    gCnt                numeric;
    gMgrCd              text; -- Typed as text for safety
    gRedOptionFlg       text; -- Typed as text for safety
    
    rec                 RECORD;
    recSreport          sfIpEpathReportWkInsertBatch_TYPE_RECORD;
    curReport           refcursor;
    
    -- Cursor for settings
    CUR_SHIWAKE CURSOR FOR
        SELECT
            CHOHYO_ID,
            coalesce(trim(both POOL_FLG), '0') AS POOL_FLG,
            trim(both EPATH_SEND_YMD_ITEM) AS EPATH_SEND_YMD_ITEM,
            trim(both ISIN_CD_ITEM) AS ISIN_CD_ITEM,
            trim(both DISPATCH_FLG_ITEM) AS DISPATCH_FLG_ITEM,
            KEY_ITEM,
            KENSAKU_NM1, KENSAKU_ITEM1,
            KENSAKU_NM2, KENSAKU_ITEM2,
            KENSAKU_NM3, KENSAKU_ITEM3,
            KENSAKU_NM4, KENSAKU_ITEM4,
            KENSAKU_NM5, KENSAKU_ITEM5,
            KENSAKU_NM6, KENSAKU_ITEM6,
            KENSAKU_NM7, KENSAKU_ITEM7,
            KENSAKU_NM8, KENSAKU_ITEM8,
            KENSAKU_NM9, KENSAKU_ITEM9,
            KENSAKU_NM10, KENSAKU_ITEM10
        FROM EPATH_SHIWAKE
        WHERE ITAKU_KAISHA_CD = l_inItakuKaishaCd
          AND BATCH_FLG = '1';

BEGIN
    USER_ID := pkconstant.BATCH_USER();

    -- Reset global state table for this session
    BEGIN
        DELETE FROM sfipepath_global_state WHERE session_key = 'main';
        INSERT INTO sfipepath_global_state (session_key, SPACE, USER_ID, SP_ID, l_inItakuKaishaCd, l_inSakuseiYmd)
        VALUES ('main', ' ', USER_ID, SP_ID, l_inItakuKaishaCd, l_inSakuseiYmd);
    EXCEPTION WHEN OTHERS THEN
        RETURN pkconstant.fatal();
    END;
    
    CALL pkLog.debug(USER_ID, SP_ID,'START');

    -- Parameter check
    IF coalesce(trim(both l_inItakuKaishaCd), '') = '' OR coalesce(trim(both l_inSakuseiYmd), '') = '' THEN
        CALL pkLog.error('ECM501', SP_ID, ' ');
        RETURN pkconstant.fatal();
    END IF;
    

    gRtnCd := pkconstant.success();
    
    gRedOptionFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd, 'REDPROJECT', '0');
    
    EXECUTE format('UPDATE sfipepath_global_state SET gRedOptionFlg = %L WHERE session_key = ''main''', gRedOptionFlg);

    -- 1. 当日夜間バッチ作成分の処理
    FOR rec IN CUR_SHIWAKE LOOP
        gChohyoId           := rec.CHOHYO_ID;
        gPoolFlg            := rec.POOL_FLG;
        gDispatchFlgItem    := rec.DISPATCH_FLG_ITEM;
        gKeyItem            := rec.KEY_ITEM;
        
        CALL pkLog.debug(USER_ID, SP_ID,'◆当日夜間バッチ作成分 -帳票ID：' || gChohyoId);
        
        -- Update state for sub-procedures (using local vars to avoid ambiguity)
        EXECUTE format('UPDATE sfipepath_global_state SET gChohyoId = %L, gPoolFlg = %L, gDispatchFlgItem = %L, gKeyItem = %L WHERE session_key = ''main''',
            gChohyoId, gPoolFlg, gDispatchFlgItem, gKeyItem);

        IF gPoolFlg = '0' THEN
            -- Immediate Link
            CALL pkLog.debug(USER_ID, SP_ID,'◆即連携する');
            
            EXECUTE format('UPDATE sfipepath_global_state SET ' ||
                'gKensakuNm1=%L, gKensakuItem1=%L, ' ||
                'gKensakuNm2=%L, gKensakuItem2=%L, ' ||
                'gKensakuNm3=%L, gKensakuItem3=%L, ' ||
                'gKensakuNm4=%L, gKensakuItem4=%L, ' ||
                'gKensakuNm5=%L, gKensakuItem5=%L, ' ||
                'gKensakuNm6=%L, gKensakuItem6=%L, ' ||
                'gKensakuNm7=%L, gKensakuItem7=%L, ' ||
                'gKensakuNm8=%L, gKensakuItem8=%L, ' ||
                'gKensakuNm9=%L, gKensakuItem9=%L, ' ||
                'gKensakuNm10=%L, gKensakuItem10=%L ' ||
                'WHERE session_key=''main''',
                rec.KENSAKU_NM1, rec.KENSAKU_ITEM1,
                rec.KENSAKU_NM2, rec.KENSAKU_ITEM2,
                rec.KENSAKU_NM3, rec.KENSAKU_ITEM3,
                rec.KENSAKU_NM4, rec.KENSAKU_ITEM4,
                rec.KENSAKU_NM5, rec.KENSAKU_ITEM5,
                rec.KENSAKU_NM6, rec.KENSAKU_ITEM6,
                rec.KENSAKU_NM7, rec.KENSAKU_ITEM7,
                rec.KENSAKU_NM8, rec.KENSAKU_ITEM8,
                rec.KENSAKU_NM9, rec.KENSAKU_ITEM9,
                rec.KENSAKU_NM10, rec.KENSAKU_ITEM10
            );

            -- Generate SQL
            -- Note: We pass variables INOUT to get the result back
            gSql := NULL; gWhereDispatch := NULL;
            CALL sfIpEpathReportWkInsertBatch_createSQL(
                gPoolFlg, l_inItakuKaishaCd, l_inSakuseiYmd, 
                gSql, gWhereDispatch, -- INOUT
                gChohyoId, gDispatchFlgItem, 
                rec.KENSAKU_ITEM1, rec.KENSAKU_ITEM2, rec.KENSAKU_ITEM3, rec.KENSAKU_ITEM4, rec.KENSAKU_ITEM5,
                rec.KENSAKU_ITEM6, rec.KENSAKU_ITEM7, rec.KENSAKU_ITEM8, rec.KENSAKU_ITEM9, rec.KENSAKU_ITEM10,
                NULL, NULL, gKeyItem, gRedOptionFlg
            );
            
            -- Push generated SQL to global state for next proc
            EXECUTE format('UPDATE sfipepath_global_state SET gSql = %L WHERE session_key = ''main''', gSql);
            
            -- Create Data
            CALL sfIpEpathReportWkInsertBatch_createErepWkData();

        ELSE    -- gPoolFlg = '1' (POOL)
            CALL pkLog.debug(USER_ID, SP_ID,'◆プールする');
            
            gEpathSendYmdItem := rec.EPATH_SEND_YMD_ITEM;
            gIsinCdItem       := rec.ISIN_CD_ITEM;
            EXECUTE format('UPDATE sfipepath_global_state SET gEpathSendYmdItem=%L, gIsinCdItem=%L WHERE session_key=''main''',
                gEpathSendYmdItem, gIsinCdItem);

            -- Generate SQL
            gSql := NULL; gWhereDispatch := NULL;
            CALL sfIpEpathReportWkInsertBatch_createSQL(
                gPoolFlg, l_inItakuKaishaCd, l_inSakuseiYmd, 
                gSql, gWhereDispatch, -- INOUT
                gChohyoId, gDispatchFlgItem, 
                NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                gEpathSendYmdItem, gIsinCdItem, gKeyItem, gRedOptionFlg
            );
            
            -- Logic xử lý Pool (Loop qua kết quả SQL)
            gSeqNo := 0;
            OPEN curReport FOR EXECUTE gSql;
            LOOP
                FETCH curReport INTO recSreport;
                EXIT WHEN NOT FOUND;
                
                -- Get MgrCd
                gMgrCd := NULL;
                IF (recSreport.ISIN_CD IS NOT NULL AND recSreport.ISIN_CD <> '') THEN
                    BEGIN
                        SELECT VMG1.MGR_CD INTO STRICT gMgrCd
                        FROM MGR_KIHON_VIEW VMG1
                        WHERE VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
                          AND VMG1.ISIN_CD = recSreport.ISIN_CD;
                    EXCEPTION
                        WHEN no_data_found THEN
                            CALL pkLog.debug(USER_ID, SP_ID, 'ISIN_CD不正：' || recSreport.ISIN_CD);
                            gMgrCd := NULL;
                        WHEN too_many_rows THEN
                            CALL pkLog.debug(USER_ID, SP_ID, 'ISIN_CD不正：' || recSreport.ISIN_CD);
                            gMgrCd := NULL;
                        WHEN OTHERS THEN
                            RAISE;
                    END;
                END IF;

                INSERT INTO EPATH_REPORT_WK_POOL(
                     KEY_CD, USER_ID, CHOHYO_KBN, SAKUSEI_YMD, CHOHYO_ID, SEQ_NO, MGR_CD, HEADER_FLG
                    ,ITEM001, ITEM002, ITEM003, ITEM004, ITEM005, ITEM006, ITEM007, ITEM008, ITEM009, ITEM010
                    ,ITEM011, ITEM012, ITEM013, ITEM014, ITEM015, ITEM016, ITEM017, ITEM018, ITEM019, ITEM020
                    ,ITEM021, ITEM022, ITEM023, ITEM024, ITEM025, ITEM026, ITEM027, ITEM028, ITEM029, ITEM030
                    ,ITEM031, ITEM032, ITEM033, ITEM034, ITEM035, ITEM036, ITEM037, ITEM038, ITEM039, ITEM040
                    ,ITEM041, ITEM042, ITEM043, ITEM044, ITEM045, ITEM046, ITEM047, ITEM048, ITEM049, ITEM050
                    ,ITEM051, ITEM052, ITEM053, ITEM054, ITEM055, ITEM056, ITEM057, ITEM058, ITEM059, ITEM060
                    ,ITEM061, ITEM062, ITEM063, ITEM064, ITEM065, ITEM066, ITEM067, ITEM068, ITEM069, ITEM070
                    ,ITEM071, ITEM072, ITEM073, ITEM074, ITEM075, ITEM076, ITEM077, ITEM078, ITEM079, ITEM080
                    ,ITEM081, ITEM082, ITEM083, ITEM084, ITEM085, ITEM086, ITEM087, ITEM088, ITEM089, ITEM090
                    ,ITEM091, ITEM092, ITEM093, ITEM094, ITEM095, ITEM096, ITEM097, ITEM098, ITEM099, ITEM100
                    ,ITEM101, ITEM102, ITEM103, ITEM104, ITEM105, ITEM106, ITEM107, ITEM108, ITEM109, ITEM110
                    ,ITEM111, ITEM112, ITEM113, ITEM114, ITEM115, ITEM116, ITEM117, ITEM118, ITEM119, ITEM120
                    ,ITEM121, ITEM122, ITEM123, ITEM124, ITEM125, ITEM126, ITEM127, ITEM128, ITEM129, ITEM130
                    ,ITEM131, ITEM132, ITEM133, ITEM134, ITEM135, ITEM136, ITEM137, ITEM138, ITEM139, ITEM140
                    ,ITEM141, ITEM142, ITEM143, ITEM144, ITEM145, ITEM146, ITEM147, ITEM148, ITEM149, ITEM150
                    ,ITEM151, ITEM152, ITEM153, ITEM154, ITEM155, ITEM156, ITEM157, ITEM158, ITEM159, ITEM160
                    ,ITEM161, ITEM162, ITEM163, ITEM164, ITEM165, ITEM166, ITEM167, ITEM168, ITEM169, ITEM170
                    ,ITEM171, ITEM172, ITEM173, ITEM174, ITEM175, ITEM176, ITEM177, ITEM178, ITEM179, ITEM180
                    ,ITEM181, ITEM182, ITEM183, ITEM184, ITEM185, ITEM186, ITEM187, ITEM188, ITEM189, ITEM190
                    ,ITEM191, ITEM192, ITEM193, ITEM194, ITEM195, ITEM196, ITEM197, ITEM198, ITEM199, ITEM200
                    ,ITEM201, ITEM202, ITEM203, ITEM204, ITEM205, ITEM206, ITEM207, ITEM208, ITEM209, ITEM210
                    ,ITEM211, ITEM212, ITEM213, ITEM214, ITEM215, ITEM216, ITEM217, ITEM218, ITEM219, ITEM220
                    ,ITEM221, ITEM222, ITEM223, ITEM224, ITEM225, ITEM226, ITEM227, ITEM228, ITEM229, ITEM230
                    ,ITEM231, ITEM232, ITEM233, ITEM234, ITEM235, ITEM236, ITEM237, ITEM238, ITEM239, ITEM240
                    ,ITEM241, ITEM242, ITEM243, ITEM244, ITEM245, ITEM246, ITEM247, ITEM248, ITEM249, ITEM250
                    ,KOUSIN_ID, SAKUSEI_ID
                ) VALUES (
                     l_inItakuKaishaCd
                    ,pkconstant.BATCH_USER()
                    ,'1'
                    ,pkEpath.seirekiChangeReverse(recSreport.EPATH_SEND_YMD)
                    ,gChohyoId
                    ,gSeqNo
                    ,gMgrCd
                    ,'1'
                    ,recSreport.ITEM001, recSreport.ITEM002, recSreport.ITEM003, recSreport.ITEM004, recSreport.ITEM005, recSreport.ITEM006, recSreport.ITEM007, recSreport.ITEM008, recSreport.ITEM009, recSreport.ITEM010
                    ,recSreport.ITEM011, recSreport.ITEM012, recSreport.ITEM013, recSreport.ITEM014, recSreport.ITEM015, recSreport.ITEM016, recSreport.ITEM017, recSreport.ITEM018, recSreport.ITEM019, recSreport.ITEM020
                    ,recSreport.ITEM021, recSreport.ITEM022, recSreport.ITEM023, recSreport.ITEM024, recSreport.ITEM025, recSreport.ITEM026, recSreport.ITEM027, recSreport.ITEM028, recSreport.ITEM029, recSreport.ITEM030
                    ,recSreport.ITEM031, recSreport.ITEM032, recSreport.ITEM033, recSreport.ITEM034, recSreport.ITEM035, recSreport.ITEM036, recSreport.ITEM037, recSreport.ITEM038, recSreport.ITEM039, recSreport.ITEM040
                    ,recSreport.ITEM041, recSreport.ITEM042, recSreport.ITEM043, recSreport.ITEM044, recSreport.ITEM045, recSreport.ITEM046, recSreport.ITEM047, recSreport.ITEM048, recSreport.ITEM049, recSreport.ITEM050
                    ,recSreport.ITEM051, recSreport.ITEM052, recSreport.ITEM053, recSreport.ITEM054, recSreport.ITEM055, recSreport.ITEM056, recSreport.ITEM057, recSreport.ITEM058, recSreport.ITEM059, recSreport.ITEM060
                    ,recSreport.ITEM061, recSreport.ITEM062, recSreport.ITEM063, recSreport.ITEM064, recSreport.ITEM065, recSreport.ITEM066, recSreport.ITEM067, recSreport.ITEM068, recSreport.ITEM069, recSreport.ITEM070
                    ,recSreport.ITEM071, recSreport.ITEM072, recSreport.ITEM073, recSreport.ITEM074, recSreport.ITEM075, recSreport.ITEM076, recSreport.ITEM077, recSreport.ITEM078, recSreport.ITEM079, recSreport.ITEM080
                    ,recSreport.ITEM081, recSreport.ITEM082, recSreport.ITEM083, recSreport.ITEM084, recSreport.ITEM085, recSreport.ITEM086, recSreport.ITEM087, recSreport.ITEM088, recSreport.ITEM089, recSreport.ITEM090
                    ,recSreport.ITEM091, recSreport.ITEM092, recSreport.ITEM093, recSreport.ITEM094, recSreport.ITEM095, recSreport.ITEM096, recSreport.ITEM097, recSreport.ITEM098, recSreport.ITEM099, recSreport.ITEM100
                    ,recSreport.ITEM101, recSreport.ITEM102, recSreport.ITEM103, recSreport.ITEM104, recSreport.ITEM105, recSreport.ITEM106, recSreport.ITEM107, recSreport.ITEM108, recSreport.ITEM109, recSreport.ITEM110
                    ,recSreport.ITEM111, recSreport.ITEM112, recSreport.ITEM113, recSreport.ITEM114, recSreport.ITEM115, recSreport.ITEM116, recSreport.ITEM117, recSreport.ITEM118, recSreport.ITEM119, recSreport.ITEM120
                    ,recSreport.ITEM121, recSreport.ITEM122, recSreport.ITEM123, recSreport.ITEM124, recSreport.ITEM125, recSreport.ITEM126, recSreport.ITEM127, recSreport.ITEM128, recSreport.ITEM129, recSreport.ITEM130
                    ,recSreport.ITEM131, recSreport.ITEM132, recSreport.ITEM133, recSreport.ITEM134, recSreport.ITEM135, recSreport.ITEM136, recSreport.ITEM137, recSreport.ITEM138, recSreport.ITEM139, recSreport.ITEM140
                    ,recSreport.ITEM141, recSreport.ITEM142, recSreport.ITEM143, recSreport.ITEM144, recSreport.ITEM145, recSreport.ITEM146, recSreport.ITEM147, recSreport.ITEM148, recSreport.ITEM149, recSreport.ITEM150
                    ,recSreport.ITEM151, recSreport.ITEM152, recSreport.ITEM153, recSreport.ITEM154, recSreport.ITEM155, recSreport.ITEM156, recSreport.ITEM157, recSreport.ITEM158, recSreport.ITEM159, recSreport.ITEM160
                    ,recSreport.ITEM161, recSreport.ITEM162, recSreport.ITEM163, recSreport.ITEM164, recSreport.ITEM165, recSreport.ITEM166, recSreport.ITEM167, recSreport.ITEM168, recSreport.ITEM169, recSreport.ITEM170
                    ,recSreport.ITEM171, recSreport.ITEM172, recSreport.ITEM173, recSreport.ITEM174, recSreport.ITEM175, recSreport.ITEM176, recSreport.ITEM177, recSreport.ITEM178, recSreport.ITEM179, recSreport.ITEM180
                    ,recSreport.ITEM181, recSreport.ITEM182, recSreport.ITEM183, recSreport.ITEM184, recSreport.ITEM185, recSreport.ITEM186, recSreport.ITEM187, recSreport.ITEM188, recSreport.ITEM189, recSreport.ITEM190
                    ,recSreport.ITEM191, recSreport.ITEM192, recSreport.ITEM193, recSreport.ITEM194, recSreport.ITEM195, recSreport.ITEM196, recSreport.ITEM197, recSreport.ITEM198, recSreport.ITEM199, recSreport.ITEM200
                    ,recSreport.ITEM201, recSreport.ITEM202, recSreport.ITEM203, recSreport.ITEM204, recSreport.ITEM205, recSreport.ITEM206, recSreport.ITEM207, recSreport.ITEM208, recSreport.ITEM209, recSreport.ITEM210
                    ,recSreport.ITEM211, recSreport.ITEM212, recSreport.ITEM213, recSreport.ITEM214, recSreport.ITEM215, recSreport.ITEM216, recSreport.ITEM217, recSreport.ITEM218, recSreport.ITEM219, recSreport.ITEM220
                    ,recSreport.ITEM221, recSreport.ITEM222, recSreport.ITEM223, recSreport.ITEM224, recSreport.ITEM225, recSreport.ITEM226, recSreport.ITEM227, recSreport.ITEM228, recSreport.ITEM229, recSreport.ITEM230
                    ,recSreport.ITEM231, recSreport.ITEM232, recSreport.ITEM233, recSreport.ITEM234, recSreport.ITEM235, recSreport.ITEM236, recSreport.ITEM237, recSreport.ITEM238, recSreport.ITEM239, recSreport.ITEM240
                    ,recSreport.ITEM241, recSreport.ITEM242, recSreport.ITEM243, recSreport.ITEM244, recSreport.ITEM245, recSreport.ITEM246, recSreport.ITEM247, recSreport.ITEM248, recSreport.ITEM249, recSreport.ITEM250
                    ,pkconstant.BATCH_USER()
                    ,pkconstant.BATCH_USER()
                );
                gSeqNo := gSeqNo + 1;
            END LOOP;
            CLOSE curReport;
        END IF;

        -- 帳票ワーク削除
        gSql := 'DELETE FROM SREPORT_WK'
            || '    WHERE (KEY_CD, USER_ID, CHOHYO_KBN, SAKUSEI_YMD, CHOHYO_ID, SEQ_NO) IN ('
            || '        SELECT'
            || '            SC16.KEY_CD'
            || '            ,SC16.USER_ID'
            || '            ,SC16.CHOHYO_KBN'
            || '            ,SC16.SAKUSEI_YMD'
            || '            ,SC16.CHOHYO_ID'
            || '            ,SC16.SEQ_NO'
            || '        FROM SREPORT_WK SC16, '
            || '             EPATH_KAIIN_HAKKOTAI X08 '
            || '        WHERE SC16.KEY_CD = ''' || l_inItakuKaishaCd || ''' '
            || '          AND SC16.CHOHYO_KBN = ''1'' '
            || '          AND SC16.SAKUSEI_YMD = ''' || l_inSakuseiYmd || ''' '
            || '          AND SC16.CHOHYO_ID = ''' || gChohyoId || ''' '
            || '          AND SC16.HEADER_FLG = ''1'' '
            || '          AND X08.ITAKU_KAISHA_CD = SC16.KEY_CD '
            || '          AND X08.HKT_CD = SC16.' || gKeyItem || ' '
            || '          AND X08.CHOHYO_ID = SC16.CHOHYO_ID '
            ||            gWhereDispatch
            || '        )';
        EXECUTE gSql;

        -- Special cleanup for IP030004412
        IF gChohyoId = 'IP030004412' THEN
            gSql := 'DELETE FROM SREPORT_WK'
                || '    WHERE (KEY_CD, USER_ID, CHOHYO_KBN, SAKUSEI_YMD, CHOHYO_ID, SEQ_NO) IN ('
                || '        SELECT'
                || '            SC16.KEY_CD'
                || '            ,SC16.USER_ID'
                || '            ,SC16.CHOHYO_KBN'
                || '            ,SC16.SAKUSEI_YMD'
                || '            ,SC16.CHOHYO_ID'
                || '            ,SC16.SEQ_NO'
                || '        FROM SREPORT_WK SC16, '
                || '             EPATH_KAIIN_HAKKOTAI X08 '
                || '        WHERE SC16.KEY_CD = ''' || l_inItakuKaishaCd || ''' '
                || '          AND SC16.CHOHYO_KBN = ''1'' '
                || '          AND SC16.SAKUSEI_YMD = ''' || l_inSakuseiYmd || ''' '
                || '          AND SC16.CHOHYO_ID = ''IP030004411'' '
                || '          AND SC16.HEADER_FLG = ''1'' '
                || '          AND X08.ITAKU_KAISHA_CD = SC16.KEY_CD '
                || '          AND X08.HKT_CD = SC16.' || gKeyItem || ' '
                || '          AND X08.CHOHYO_ID = SC16.CHOHYO_ID '
                ||            gWhereDispatch
                || '        )';
            EXECUTE gSql;
        END IF;

        -- Check empty reports
        BEGIN
            SELECT count(*) INTO STRICT gCnt
            FROM SREPORT_WK
            WHERE KEY_CD = l_inItakuKaishaCd
              AND CHOHYO_KBN = '1'
              AND SAKUSEI_YMD = l_inSakuseiYmd
              AND CHOHYO_ID = gChohyoId
              AND HEADER_FLG = '1';
        EXCEPTION
            WHEN no_data_found THEN
                gCnt := 0;
        END;

        IF gCnt = 0 THEN
            DELETE FROM SREPORT_WK
            WHERE KEY_CD = l_inItakuKaishaCd
              AND CHOHYO_KBN = '1'
              AND SAKUSEI_YMD = l_inSakuseiYmd
              AND CHOHYO_ID = gChohyoId
              AND HEADER_FLG = '0';
              
            DELETE FROM PRT_OK
            WHERE ITAKU_KAISHA_CD = l_inItakuKaishaCd
              AND KIJUN_YMD = l_inSakuseiYmd
              AND CHOHYO_ID = gChohyoId;
              
            IF gChohyoId = 'IP030004412' THEN
                DELETE FROM SREPORT_WK
                WHERE KEY_CD = l_inItakuKaishaCd
                  AND CHOHYO_KBN = '1'
                  AND SAKUSEI_YMD = l_inSakuseiYmd
                  AND CHOHYO_ID = 'IP030004411'
                  AND HEADER_FLG = '0';
                  
                DELETE FROM PRT_OK
                WHERE ITAKU_KAISHA_CD = l_inItakuKaishaCd
                  AND KIJUN_YMD = l_inSakuseiYmd
                  AND CHOHYO_ID = 'IP030004411';
            END IF;
        END IF;

    END LOOP;

    -- 2. 送信日到来処理
    FOR rec IN CUR_SHIWAKE LOOP
        CALL pkLog.debug(USER_ID, SP_ID,'◆送信日到来分 -帳票ID：' || rec.CHOHYO_ID);
        
        gChohyoId := rec.CHOHYO_ID;
        gPoolFlg := NULL;
        gDispatchFlgItem := NULL;
        gKeyItem := rec.KEY_ITEM;
        
        -- Update state (using EXECUTE to avoid ambiguity)
        EXECUTE format('UPDATE sfipepath_global_state SET ' ||
            'gChohyoId = %L, gKeyItem = %L, ' ||
            'gKensakuNm1=%L, gKensakuItem1=%L, ' ||
            'gKensakuNm2=%L, gKensakuItem2=%L, ' ||
            'gKensakuNm3=%L, gKensakuItem3=%L, ' ||
            'gKensakuNm4=%L, gKensakuItem4=%L, ' ||
            'gKensakuNm5=%L, gKensakuItem5=%L, ' ||
            'gKensakuNm6=%L, gKensakuItem6=%L, ' ||
            'gKensakuNm7=%L, gKensakuItem7=%L, ' ||
            'gKensakuNm8=%L, gKensakuItem8=%L, ' ||
            'gKensakuNm9=%L, gKensakuItem9=%L, ' ||
            'gKensakuNm10=%L, gKensakuItem10=%L ' ||
            'WHERE session_key=''main''',
            gChohyoId, gKeyItem,
            rec.KENSAKU_NM1, rec.KENSAKU_ITEM1,
            rec.KENSAKU_NM2, rec.KENSAKU_ITEM2,
            rec.KENSAKU_NM3, rec.KENSAKU_ITEM3,
            rec.KENSAKU_NM4, rec.KENSAKU_ITEM4,
            rec.KENSAKU_NM5, rec.KENSAKU_ITEM5,
            rec.KENSAKU_NM6, rec.KENSAKU_ITEM6,
            rec.KENSAKU_NM7, rec.KENSAKU_ITEM7,
            rec.KENSAKU_NM8, rec.KENSAKU_ITEM8,
            rec.KENSAKU_NM9, rec.KENSAKU_ITEM9,
            rec.KENSAKU_NM10, rec.KENSAKU_ITEM10
        );

        -- Generate SQL (Mode '9')
        gSql := NULL; gWhereDispatch := NULL;
        CALL sfIpEpathReportWkInsertBatch_createSQL(
            '9', l_inItakuKaishaCd, l_inSakuseiYmd, 
            gSql, gWhereDispatch, -- INOUT
            gChohyoId, gDispatchFlgItem, 
            rec.KENSAKU_ITEM1, rec.KENSAKU_ITEM2, rec.KENSAKU_ITEM3, rec.KENSAKU_ITEM4, rec.KENSAKU_ITEM5,
            rec.KENSAKU_ITEM6, rec.KENSAKU_ITEM7, rec.KENSAKU_ITEM8, rec.KENSAKU_ITEM9, rec.KENSAKU_ITEM10,
            NULL, NULL, gKeyItem, gRedOptionFlg
        );
        EXECUTE format('UPDATE sfipepath_global_state SET gSql = %L WHERE session_key = ''main''', gSql);

        -- Create Data
        CALL sfIpEpathReportWkInsertBatch_createErepWkData();

        -- Clean Pool
        gSql := 'DELETE FROM EPATH_REPORT_WK_POOL'
            || '    WHERE (KEY_CD, USER_ID, CHOHYO_KBN, SAKUSEI_YMD, CHOHYO_ID, SEQ_NO) IN ('
            || '        SELECT'
            || '            SC16.KEY_CD'
            || '            ,SC16.USER_ID'
            || '            ,SC16.CHOHYO_KBN'
            || '            ,SC16.SAKUSEI_YMD'
            || '            ,SC16.CHOHYO_ID'
            || '            ,SC16.SEQ_NO'
            || '        FROM EPATH_REPORT_WK_POOL SC16, '
            || '             EPATH_KAIIN_HAKKOTAI X08 '
            || '        WHERE SC16.KEY_CD = ''' || l_inItakuKaishaCd || ''' '
            || '          AND SC16.CHOHYO_KBN = ''1'' '
            || '          AND SC16.SAKUSEI_YMD = ''' || l_inSakuseiYmd || ''' '
            || '          AND SC16.CHOHYO_ID = ''' || gChohyoId || ''' '
            || '          AND SC16.HEADER_FLG = ''1'' '
            || '          AND X08.ITAKU_KAISHA_CD = SC16.KEY_CD '
            || '          AND X08.HKT_CD = SC16.' || gKeyItem || ' '
            || '          AND X08.CHOHYO_ID = SC16.CHOHYO_ID '
            || '        )';
        EXECUTE gSql;
    END LOOP;

    CALL pkLog.debug(USER_ID, SP_ID,'END');
    RETURN gRtnCd;

EXCEPTION
    WHEN OTHERS THEN
        CALL pkLog.debug(USER_ID, SP_ID, '***** その他例外発生 *****');
        CALL pkLog.fatal('ECM701', SP_ID, SQLSTATE||SUBSTR(SQLERRM, 1, 100));
        RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL;