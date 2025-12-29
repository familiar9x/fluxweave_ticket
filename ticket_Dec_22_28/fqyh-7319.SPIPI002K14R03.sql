


DROP TYPE IF EXISTS SPIPI002K14R03_l_items_type;
CREATE TYPE SPIPI002K14R03_l_items_type AS (items varchar(400));
DROP TYPE IF EXISTS SPIPI002K14R03_gKenketsuRfd_type;
CREATE TYPE SPIPI002K14R03_gKenketsuRfd_type AS (rfd varchar(3));


CREATE OR REPLACE PROCEDURE spipi002k14r03 ( l_inItakuKaishaCd text,        -- 委託会社コード
 l_inUserId text,        -- ユーザID
 l_inChohyoKbn text,        -- 帳票区分
 l_inGyomuYmd text,        -- 業務日付
 l_inZengetuYmd text,        -- 前月末日
 l_outSqlCode OUT integer,      -- リターン値
 l_outSqlErrM OUT text     -- エラーコメント
 ) AS $body$
DECLARE

--
-- * 著作権:Copyright(c)2013
-- * 会社名:JIP
-- *
-- * 概要　:現物債銘柄マスタ、回号マスタを抽出し帳票を作成する
-- *
-- * 引数　:l_inItakuKaishaCd  IN  VARCHAR        -- 委託会社コード
-- *        l_inUserId         IN  VARCHAR        -- ユーザID
-- *        l_inChohyoKbn      IN  VARCHAR        -- 帳票区分
-- *        l_inGyomuYmd       IN  VARCHAR        -- 業務日付
-- *        l_outSqlCode       IN  VARCHAR        -- 前月末日
-- *        l_outSqlErrM       OUT NUMERIC          -- リターン値
-- *                           OUT VARCHAR        -- エラーコメント
-- * 返り値: なし
-- *
-- * @author Xu Chunxu
-- * @version $Id: SPIPI002K14R03.sql,v 1.4 2013/08/16 04:06:02 handa Exp $
--
	--==============================================================================
	--                  デバッグ機能                                                 
	--==============================================================================
	DEBUG	numeric(1)	:= 0;
	--==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	REPORT_ID        CONSTANT text       := 'IP931400231';   -- 帳票ＩＤ（控）
	KREPORT_ID        CONSTANT text      := 'IP931400232';   -- 帳票ＩＤ
	PROGRAM_ID	      CONSTANT text      := 'SPIPI002K14R03';  -- SP名称
	PROGRAM_NAME      CONSTANT text      := '事故債券ならびに欠缺利札管理表';  -- 機能名称
	RTN_CNT           CONSTANT integer           := 15;       --
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
    gRtnCd               numeric := pkconstant.success();      -- リターンコード
    gReportId            varchar(11) := NULL;                  --帳票ID
    
    gSelectDef           TEXT := NULL;               -- 変数．検索項目
    ganponIdoJiyu        TEXT := NULL;
    gRifu                TEXT := NULL;
    gKenk                TEXT := NULL;
    gTableDefSUB_TBL4    TEXT := NULL;               -- SUB_TBL4の変数．検索項目
    gTableDefSUB_TBL2    TEXT := NULL;               -- SUB_TBL2の変数．検索項目
    gTableDefSUB_TBL3    TEXT := NULL;               -- SUB_TBL3の変数．検索項目
    gRifudaJokenKbnRwk   TEXT := NULL;                -- 利札異動事由_利渡期
    gKenketsuRfdKbnRwk   TEXT := NULL;                -- けん欠利札区分_利渡期
    gMgrCd               varchar(7) := NULL;                   -- 銘柄コード
    gKaiGo               varchar(6) := NULL;                   -- 回号コード
    gZenMgrCd            varchar(7) := NULL;                   -- 前回銘柄コード
    gZenKaiGo            varchar(6) := NULL;                   -- 前回回号コード
    gKaiGoNm1            varchar(40) := NULL;                  -- 回号正式名称１
    gKaiGoNm2            varchar(40) := NULL;                  -- 回号正式名称２
    gZenKaiGoNm1         varchar(40) := NULL;                  -- 前回回号正式名称１
    gZenKaiGoNm2         varchar(40) := NULL;                  -- 前回回号正式名称２
    gKenShuCd            varchar(2) := NULL;                   -- 券種コード
    gKenShu              varchar(14) := NULL;                  -- 券種
    gKiBanGO             varchar(6) := NULL;                   -- 記番号
    gGanponIdoHasseiYmd  varchar(8) := NULL;                   --元本異動発生日
    gGanponIdoJiyu       varchar(1) := NULL;                   --元本異動事由
    gHogenKensu          integer := 0;                          -- 本件合計枚数
    gKenKensu            integer := 0;                          -- 利券合計枚数
    gRiKensu             integer := 0;                          -- 欠缺合計枚数
    gZenHogenKensu       integer := 0;                          -- 前回本件合計枚数
    gZenKenKensu         integer := 0;                          -- 前回利券合計枚数
    gZenRiKensu          integer := 0;                          -- 前回欠缺合計枚数
    gKenSu               varchar(4) := NULL;                   -- 件数
    gSeqNo               integer := 0;                          --シーケンス
    gZenKenCnt           integer := 0;                          -- 利札異動事由_利渡期件数
    gZenRiCnt            integer := 0;                          --けん欠利札区分_利渡期件数
    gRino                integer := 0;
    gKenno               integer := 0;
    gCnt                 integer := 0;
    gCount               integer := 0;
    gTotalCount          integer := 0;
    gKenCount            integer := 0;
    gRiCount             integer := 0;
    gTitle1              varchar(100) := NULL;
    gZenTitle1           varchar(100) := NULL;
    gTitle2              varchar(100) := PROGRAM_NAME;
	errMsg               varchar(300);
	errCode              varchar(6);
    curRec REFCURSOR;                                           -- 明細ダデータカーソル
    l_Kenitem001 varchar(400);
    l_Kenitem002 varchar(400);
    l_Kenitem003 varchar(400);
    l_Kenitem004 varchar(400);
    l_Kenitem005 varchar(400);
    l_Kenitem006 varchar(400);
    l_Kenitem007 varchar(400);
    l_Kenitem008 varchar(400);
    l_Kenitem009 varchar(400);
    l_Kenitem010 varchar(400);
    l_Kenitem011 varchar(400);
    l_Kenitem012 varchar(400);
    l_Kenitem013 varchar(400);
    l_Kenitem014 varchar(400);
    l_Kenitem015 varchar(400);
    l_Kenitem016 varchar(400);
    l_Kenitem017 varchar(400);
    l_Kenitem018 varchar(400);
    l_Kenitem019 varchar(400);
    l_Kenitem020 varchar(400);
    l_Kenitem021 varchar(400);
    l_Kenitem022 varchar(400);
    l_Kenitem023 varchar(400);
    l_Kenitem024 varchar(400);
    l_Kenitem025 varchar(400);
    l_Kenitem026 varchar(400);
    l_Kenitem027 varchar(400);
    l_Kenitem028 varchar(400);
    l_Kenitem029 varchar(400);
    l_Kenitem030 varchar(400);
    l_Kenitem031 varchar(400);
    l_Kenitem032 varchar(400);
    l_Kenitem033 varchar(400);
    l_Kenitem034 varchar(400);
    l_Kenitem035 varchar(400);
    l_Kenitem036 varchar(400);
    l_Kenitem037 varchar(400);
    l_Kenitem038 varchar(400);
    l_Kenitem039 varchar(400);
    l_Kenitem040 varchar(400);
    l_Kenitem041 varchar(400);
    l_Kenitem042 varchar(400);
    l_Kenitem043 varchar(400);
    l_Kenitem044 varchar(400);
    l_Kenitem045 varchar(400);
    l_Kenitem046 varchar(400);
    l_Kenitem047 varchar(400);
    l_Kenitem048 varchar(400);
    l_Kenitem049 varchar(400);
    l_Kenitem050 varchar(400);
    l_Kenitem051 varchar(400);
    l_Kenitem052 varchar(400);
    l_Kenitem053 varchar(400);
    l_Kenitem054 varchar(400);
    l_Kenitem055 varchar(400);
    l_Kenitem056 varchar(400);
    l_Kenitem057 varchar(400);
    l_Kenitem058 varchar(400);
    l_Kenitem059 varchar(400);
    l_Kenitem060 varchar(400);
    l_Kenitem061 varchar(400);
    l_Kenitem062 varchar(400);
    l_Kenitem063 varchar(400);
    l_Kenitem064 varchar(400);
    l_Kenitem065 varchar(400);
    l_Kenitem066 varchar(400);
    l_Kenitem067 varchar(400);
    l_Kenitem068 varchar(400);
    l_Kenitem069 varchar(400);
    l_Kenitem070 varchar(400);
    l_Kenitem071 varchar(400);
    l_Kenitem072 varchar(400);
    l_Kenitem073 varchar(400);
    l_Kenitem074 varchar(400);
    l_Kenitem075 varchar(400);
    l_Kenitem076 varchar(400);
    l_Kenitem077 varchar(400);
    l_Kenitem078 varchar(400);
    l_Kenitem079 varchar(400);
    l_Kenitem080 varchar(400);
    l_Kenitem081 varchar(400);
    l_Kenitem082 varchar(400);
    l_Kenitem083 varchar(400);
    l_Kenitem084 varchar(400);
    l_Kenitem085 varchar(400);
    l_Kenitem086 varchar(400);
    l_Kenitem087 varchar(400);
    l_Kenitem088 varchar(400);
    l_Kenitem089 varchar(400);
    l_Kenitem090 varchar(400);
    l_Kenitem091 varchar(400);
    l_Kenitem092 varchar(400);
    l_Kenitem093 varchar(400);
    l_Kenitem094 varchar(400);
    l_Kenitem095 varchar(400);
    l_Kenitem096 varchar(400);
    l_Kenitem097 varchar(400);
    l_Kenitem098 varchar(400);
    l_Kenitem099 varchar(400);
    l_Kenitem100 varchar(400);
    l_Riitem001 varchar(400);
    l_Riitem002 varchar(400);
    l_Riitem003 varchar(400);
    l_Riitem004 varchar(400);
    l_Riitem005 varchar(400);
    l_Riitem006 varchar(400);
    l_Riitem007 varchar(400);
    l_Riitem008 varchar(400);
    l_Riitem009 varchar(400);
    l_Riitem010 varchar(400);
    l_Riitem011 varchar(400);
    l_Riitem012 varchar(400);
    l_Riitem013 varchar(400);
    l_Riitem014 varchar(400);
    l_Riitem015 varchar(400);
    l_Riitem016 varchar(400);
    l_Riitem017 varchar(400);
    l_Riitem018 varchar(400);
    l_Riitem019 varchar(400);
    l_Riitem020 varchar(400);
    l_Riitem021 varchar(400);
    l_Riitem022 varchar(400);
    l_Riitem023 varchar(400);
    l_Riitem024 varchar(400);
    l_Riitem025 varchar(400);
    l_Riitem026 varchar(400);
    l_Riitem027 varchar(400);
    l_Riitem028 varchar(400);
    l_Riitem029 varchar(400);
    l_Riitem030 varchar(400);
    l_Riitem031 varchar(400);
    l_Riitem032 varchar(400);
    l_Riitem033 varchar(400);
    l_Riitem034 varchar(400);
    l_Riitem035 varchar(400);
    l_Riitem036 varchar(400);
    l_Riitem037 varchar(400);
    l_Riitem038 varchar(400);
    l_Riitem039 varchar(400);
    l_Riitem040 varchar(400);
    l_Riitem041 varchar(400);
    l_Riitem042 varchar(400);
    l_Riitem043 varchar(400);
    l_Riitem044 varchar(400);
    l_Riitem045 varchar(400);
    l_Riitem046 varchar(400);
    l_Riitem047 varchar(400);
    l_Riitem048 varchar(400);
    l_Riitem049 varchar(400);
    l_Riitem050 varchar(400);
    l_Riitem051 varchar(400);
    l_Riitem052 varchar(400);
    l_Riitem053 varchar(400);
    l_Riitem054 varchar(400);
    l_Riitem055 varchar(400);
    l_Riitem056 varchar(400);
    l_Riitem057 varchar(400);
    l_Riitem058 varchar(400);
    l_Riitem059 varchar(400);
    l_Riitem060 varchar(400);
    l_Riitem061 varchar(400);
    l_Riitem062 varchar(400);
    l_Riitem063 varchar(400);
    l_Riitem064 varchar(400);
    l_Riitem065 varchar(400);
    l_Riitem066 varchar(400);
    l_Riitem067 varchar(400);
    l_Riitem068 varchar(400);
    l_Riitem069 varchar(400);
    l_Riitem070 varchar(400);
    l_Riitem071 varchar(400);
    l_Riitem072 varchar(400);
    l_Riitem073 varchar(400);
    l_Riitem074 varchar(400);
    l_Riitem075 varchar(400);
    l_Riitem076 varchar(400);
    l_Riitem077 varchar(400);
    l_Riitem078 varchar(400);
    l_Riitem079 varchar(400);
    l_Riitem080 varchar(400);
    l_Riitem081 varchar(400);
    l_Riitem082 varchar(400);
    l_Riitem083 varchar(400);
    l_Riitem084 varchar(400);
    l_Riitem085 varchar(400);
    l_Riitem086 varchar(400);
    l_Riitem087 varchar(400);
    l_Riitem088 varchar(400);
    l_Riitem089 varchar(400);
    l_Riitem090 varchar(400);
    l_Riitem091 varchar(400);
    l_Riitem092 varchar(400);
    l_Riitem093 varchar(400);
    l_Riitem094 varchar(400);
    l_Riitem095 varchar(400);
    l_Riitem096 varchar(400);
    l_Riitem097 varchar(400);
    l_Riitem098 varchar(400);
    l_Riitem099 varchar(400);
    l_Riitem100 varchar(400);
    l_Kenitems varchar(400)[100];                                      --利札異動事由_利渡期XXX
    l_Riitems varchar(400)[100];                                       --けん欠利札区分_利渡期XXX
    gKenketsuRfdDef varchar(3)[105];                            --利札異動事由_利渡期XXXリスト
    gRifudaJokendDef varchar(3)[105];                           --けん欠利札区分_利渡期XXXリスト
--==============================================================================
--	メインルーチン                                                          	
--==============================================================================
BEGIN
	CALL pkLog.debug(l_inUserId,  '○' || PROGRAM_NAME ||'('|| PROGRAM_ID||')', ' START');
	-- 引数（必須）データチェック ※委託会社コード、ユーザID、帳票区分、業務日付は必須入力項目
	IF (coalesce(trim(both l_inItakuKaishaCd)::text, '') = '')
	OR (coalesce(trim(both l_inUserId)::text, '') = '')
	OR (coalesce(trim(both l_inChohyoKbn)::text, '') = '')
	OR (coalesce(trim(both l_inGyomuYmd)::text, '') = '')
	OR (coalesce(trim(both l_inZengetuYmd)::text, '') = '')
	THEN
	-- ログ書込み
		errCode := 'ECM501';
		errMsg := '入力パラメータエラー';
		RAISE EXCEPTION 'errijou' USING ERRCODE = '50001';
	END IF;
	--帳票ワークの削除
	DELETE FROM SREPORT_WK
		WHERE KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = l_inGyomuYmd
		AND (CHOHYO_ID = REPORT_ID OR CHOHYO_ID = KREPORT_ID);
	gTableDefSUB_TBL4 := '';
	gTableDefSUB_TBL4 := gTableDefSUB_TBL4 || ' (SELECT ';
	gTableDefSUB_TBL4 := gTableDefSUB_TBL4 || ' ITAKU_KAISHA_CD, ';
	gTableDefSUB_TBL4 := gTableDefSUB_TBL4 || ' MGR_CD, ';
	gTableDefSUB_TBL4 := gTableDefSUB_TBL4 || ' COUNT(1) AS kenCnt ';
	gTableDefSUB_TBL4 := gTableDefSUB_TBL4 || ' FROM ';
	gTableDefSUB_TBL4 := gTableDefSUB_TBL4 || ' BD_NYUSHUKIN ';
	gTableDefSUB_TBL4 := gTableDefSUB_TBL4 || ' WHERE ';
	gTableDefSUB_TBL4 := gTableDefSUB_TBL4 || ' ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' ';
	gTableDefSUB_TBL4 := gTableDefSUB_TBL4 || ' AND TORIHIKI_YMD <=  ''' || l_inZengetuYmd || ''' ';
	gTableDefSUB_TBL4 := gTableDefSUB_TBL4 || ' AND TORIHIKI_S_KBN IN (''2C'',''2D'',''2G'',''2H'')  ';
	gTableDefSUB_TBL4 := gTableDefSUB_TBL4 || ' GROUP BY  ';
	gTableDefSUB_TBL4 := gTableDefSUB_TBL4 || ' ITAKU_KAISHA_CD,MGR_CD) SUB_TBL4 ';
	gTableDefSUB_TBL2 := '';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' (SELECT ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GNBT_MGR_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' HAKKO_KENSHU1 AS HAKKO_KENSHU, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_KNGK1 AS KENSHU_KNGK, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_NM1 AS KENSHU_NM, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM1, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM2 ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' FROM ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GB_KAIGO ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' WHERE ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND (TRIM(GANPON_OUT_YOKUSEI_FLG) IS NULL OR TRIM(RIFUDA_OUT_YOKUSEI_FLG) IS NULL) ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KIBANGO_KANRI_KBN =  ''1'' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KAKUNIN_YMD <>  '' '' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' UNION ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' SELECT ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GNBT_MGR_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' HAKKO_KENSHU2 AS HAKKO_KENSHU, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_KNGK2 AS KENSHU_KNGK, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_NM2 AS KENSHU_NM, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM1, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM2 ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' FROM ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GB_KAIGO ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' WHERE ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND (TRIM(GANPON_OUT_YOKUSEI_FLG) IS NULL OR TRIM(RIFUDA_OUT_YOKUSEI_FLG) IS NULL) ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KIBANGO_KANRI_KBN =  ''1'' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KAKUNIN_YMD <>  '' '' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' UNION ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' SELECT ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GNBT_MGR_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' HAKKO_KENSHU3 AS HAKKO_KENSHU, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_KNGK3 AS KENSHU_KNGK, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_NM3 AS KENSHU_NM, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM1, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM2 ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' FROM ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GB_KAIGO ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' WHERE ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND (TRIM(GANPON_OUT_YOKUSEI_FLG) IS NULL OR TRIM(RIFUDA_OUT_YOKUSEI_FLG) IS NULL) ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KIBANGO_KANRI_KBN =  ''1'' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KAKUNIN_YMD <>  '' '' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' UNION ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' SELECT ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GNBT_MGR_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' HAKKO_KENSHU4 AS HAKKO_KENSHU, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_KNGK4 AS KENSHU_KNGK, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_NM4 AS KENSHU_NM, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM1, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM2 ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' FROM ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GB_KAIGO ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' WHERE ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND (TRIM(GANPON_OUT_YOKUSEI_FLG) IS NULL OR TRIM(RIFUDA_OUT_YOKUSEI_FLG) IS NULL) ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KIBANGO_KANRI_KBN =  ''1'' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KAKUNIN_YMD <>  '' '' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' UNION ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' SELECT ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GNBT_MGR_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' HAKKO_KENSHU5 AS HAKKO_KENSHU, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_KNGK5 AS KENSHU_KNGK, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_NM5 AS KENSHU_NM, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM1, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM2 ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' FROM ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GB_KAIGO ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' WHERE ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND (TRIM(GANPON_OUT_YOKUSEI_FLG) IS NULL OR TRIM(RIFUDA_OUT_YOKUSEI_FLG) IS NULL) ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KIBANGO_KANRI_KBN =  ''1'' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KAKUNIN_YMD <>  '' '' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' UNION ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' SELECT ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GNBT_MGR_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' HAKKO_KENSHU6 AS HAKKO_KENSHU, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_KNGK6 AS KENSHU_KNGK, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_NM6 AS KENSHU_NM, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM1, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM2 ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' FROM ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GB_KAIGO ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' WHERE ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND (TRIM(GANPON_OUT_YOKUSEI_FLG) IS NULL OR TRIM(RIFUDA_OUT_YOKUSEI_FLG) IS NULL) ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KIBANGO_KANRI_KBN =  ''1'' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KAKUNIN_YMD <>  '' '' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' UNION ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' SELECT ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GNBT_MGR_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' HAKKO_KENSHU7 AS HAKKO_KENSHU, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_KNGK7 AS KENSHU_KNGK, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_NM7 AS KENSHU_NM, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM1, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM2 ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' FROM ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GB_KAIGO ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' WHERE ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND (TRIM(GANPON_OUT_YOKUSEI_FLG) IS NULL OR TRIM(RIFUDA_OUT_YOKUSEI_FLG) IS NULL) ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KIBANGO_KANRI_KBN =  ''1'' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KAKUNIN_YMD <>  '' '' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' UNION ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' SELECT ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GNBT_MGR_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' HAKKO_KENSHU8 AS HAKKO_KENSHU, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_KNGK8 AS KENSHU_KNGK, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_NM8 AS KENSHU_NM, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM1, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM2 ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' FROM ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GB_KAIGO ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' WHERE ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND (TRIM(GANPON_OUT_YOKUSEI_FLG) IS NULL OR TRIM(RIFUDA_OUT_YOKUSEI_FLG) IS NULL) ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KIBANGO_KANRI_KBN =  ''1'' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KAKUNIN_YMD <>  '' '') SUB_TBL2 ';
	gTableDefSUB_TBL3 := '';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' (SELECT ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' SUB_TBL2.ITAKU_KAISHA_CD, ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' SUB_TBL2.GNBT_MGR_CD, ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' SUB_TBL2.KAIGO_CD, ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' COALESCE(NULLIF(TRIM(GB_KENSHU.KENSHU_NM), ''''), SUB_TBL2.KENSHU_NM) AS KENSHU_NM, ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' COALESCE(NULLIF(TRIM(GB_KENSHU.GB_KENSHU_CD), ''''), SUB_TBL2.HAKKO_KENSHU) AS GB_KENSHU_CD, ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' COALESCE(GB_KENSHU.KENSHU_KNGK, SUB_TBL2.KENSHU_KNGK) AS KENSHU_KNGK, ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' SUB_TBL2.KAIGO_NM1, ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' SUB_TBL2.KAIGO_NM2';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' FROM ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' GB_MGR, ' || gTableDefSUB_TBL2;
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' LEFT OUTER JOIN GB_KENSHU ON SUB_TBL2.ITAKU_KAISHA_CD = GB_KENSHU.ITAKU_KAISHA_CD ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' AND SUB_TBL2.HAKKO_KENSHU = GB_KENSHU.GB_KENSHU_CD';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' WHERE ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' GB_MGR.KOSHASAI_BNRI <> ''07'' ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' AND GB_MGR.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' AND GB_MGR.ITAKU_KAISHA_CD = SUB_TBL2.ITAKU_KAISHA_CD ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' AND GB_MGR.GNBT_MGR_CD = SUB_TBL2.GNBT_MGR_CD ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' AND SUB_TBL2.HAKKO_KENSHU <> '' '' ) SUB_TBL3 ';
	gRifudaJokenKbnRwk := '';
	gKenketsuRfdKbnRwk := '';
	FOR i IN 1..99 LOOP
		gRifudaJokenKbnRwk := gRifudaJokenKbnRwk || 'RIFUDA_IDO_JIYU_RWK' || i || ', ';
		gKenketsuRfdKbnRwk := gKenketsuRfdKbnRwk || 'KENKETSU_RFD_KBN_RWK' || i || ', ';
	END LOOP;
	gRifudaJokenKbnRwk := gRifudaJokenKbnRwk || 'RIFUDA_IDO_JIYU_RWK100, ';
	gKenketsuRfdKbnRwk := gKenketsuRfdKbnRwk || 'KENKETSU_RFD_KBN_RWK100';
	gRifu := '';
	gKenk := '';
    FOR i IN 1..100 LOOP
	    gRifu := gRifu || 'RIFUDA_IDO_JIYU_RWK' || i || ' IN (''1'',''2'') OR ';
	    gKenk := gKenk || 'KENKETSU_RFD_KBN_RWK' || i || ' = ''1'' OR ';
    END LOOP;
    ganponIdoJiyu := 'AND (' || gRifu || gKenk  || 'GANPON_IDO_JIYU IN (''1'', ''2'', ''3''))';
	gSelectDef := '';
	gSelectDef := gSelectDef || ' SELECT ';
	gSelectDef := gSelectDef || ' kenCnt, ';
	gSelectDef := gSelectDef || ' SUB_TBL3.GNBT_MGR_CD, ';
	gSelectDef := gSelectDef || ' SUB_TBL3.KAIGO_CD, ';
	gSelectDef := gSelectDef || ' SUB_TBL3.KAIGO_NM1, ';
	gSelectDef := gSelectDef || ' SUB_TBL3.KAIGO_NM2, ';
	gSelectDef := gSelectDef || ' SUB_TBL3.GB_KENSHU_CD, ';
	gSelectDef := gSelectDef || ' SUB_TBL3.KENSHU_NM, ';
	gSelectDef := gSelectDef || ' GB_KIBANGO.KIBANGO, ';
	gSelectDef := gSelectDef || ' GB_KIBANGO.GANPON_IDO_HASSEI_YMD, ';
	gSelectDef := gSelectDef || ' GB_KIBANGO.GANPON_IDO_JIYU, ';
	gSelectDef := gSelectDef ||  gRifudaJokenKbnRwk;
	gSelectDef := gSelectDef ||  gKenketsuRfdKbnRwk;
	gSelectDef := gSelectDef || ' FROM ';
	gSelectDef := gSelectDef || ' GB_KIBANGO ';
	gSelectDef := gSelectDef || ' INNER JOIN ' || gTableDefSUB_TBL3 || ' ON GB_KIBANGO.ITAKU_KAISHA_CD = SUB_TBL3.ITAKU_KAISHA_CD ';
	gSelectDef := gSelectDef || '   AND GB_KIBANGO.GNBT_MGR_CD = SUB_TBL3.GNBT_MGR_CD ';
	gSelectDef := gSelectDef || '   AND GB_KIBANGO.KAIGO_CD = SUB_TBL3.KAIGO_CD ';
	gSelectDef := gSelectDef || ' INNER JOIN GB_GENSAI_RIREKI ON SUB_TBL3.ITAKU_KAISHA_CD = GB_GENSAI_RIREKI.ITAKU_KAISHA_CD ';
	gSelectDef := gSelectDef || '   AND SUB_TBL3.GNBT_MGR_CD = GB_GENSAI_RIREKI.GNBT_MGR_CD ';
	gSelectDef := gSelectDef || '   AND SUB_TBL3.KAIGO_CD = GB_GENSAI_RIREKI.KAIGO_CD ';
	gSelectDef := gSelectDef || '   AND GB_GENSAI_RIREKI.TORIHIKI_ZANDAKA = ''0'' ';
	gSelectDef := gSelectDef || '   AND TRIM(GB_GENSAI_RIREKI.MUKO_FLG) IS NULL ';
	gSelectDef := gSelectDef || ' LEFT OUTER JOIN ' || gTableDefSUB_TBL4 || ' ON GB_KIBANGO.ITAKU_KAISHA_CD = SUB_TBL4.ITAKU_KAISHA_CD ';
	gSelectDef := gSelectDef || '   AND (GB_KIBANGO.GNBT_MGR_CD || GB_KIBANGO.KAIGO_CD) = SUB_TBL4.MGR_CD ';
	gSelectDef := gSelectDef || '   AND GB_KIBANGO.KENSHU_KNGK = SUB_TBL3.KENSHU_KNGK ';
	gSelectDef := gSelectDef || ' WHERE ';
	gSelectDef := gSelectDef || ' GB_KIBANGO.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' ';
	gSelectDef := gSelectDef ||  ganponIdoJiyu;
	gSelectDef := gSelectDef || ' ORDER BY ';
	gSelectDef := gSelectDef || ' GNBT_MGR_CD, KAIGO_CD, GB_KENSHU_CD, KIBANGO, GANPON_IDO_HASSEI_YMD';
	FOR cnt IN 1..2 LOOP
		gZenMgrCd := '';
		gZenKaiGo := '';
		gZenHogenKensu := 0;
		gZenKenKensu := 0;
		gZenRiKensu := 0;
		gKenKensu := 0;
		gRiKensu := 0;
		gSeqNo := 0;
		--ヘッダレコードを出力
		IF cnt = 1 THEN
			gReportId := REPORT_ID;
			CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, gReportId);
		ELSE
			gReportId := KREPORT_ID;
			IF gHogenKensu <> 0 THEN
				CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, gReportId);
			ELSE
				exit;
			END IF;
		END IF;
		l_Kenitems := ARRAY[]::varchar(400)[];
		l_Riitems := ARRAY[]::varchar(400)[];
		gHogenKensu := 0;
		gKenCount := 0;
		gRiCount := 0;
		BEGIN
			OPEN curRec FOR EXECUTE gSelectDef;
			LOOP
			FETCH curRec INTO gKenSu, gMgrCd, gKaiGo, gKaiGoNm1, gKaiGoNm2, gKenShuCd, gKenShu, gKiBanGO, gGanponIdoHasseiYmd,gGanponIdoJiyu,
					l_Kenitem001,l_Kenitem002,l_Kenitem003,l_Kenitem004,l_Kenitem005,
					l_Kenitem006,l_Kenitem007,l_Kenitem008,l_Kenitem009,l_Kenitem010,
					l_Kenitem011,l_Kenitem012,l_Kenitem013,l_Kenitem014,l_Kenitem015,
					l_Kenitem016,l_Kenitem017,l_Kenitem018,l_Kenitem019,l_Kenitem020,
					l_Kenitem021,l_Kenitem022,l_Kenitem023,l_Kenitem024,l_Kenitem025,
					l_Kenitem026,l_Kenitem027,l_Kenitem028,l_Kenitem029,l_Kenitem030,
					l_Kenitem031,l_Kenitem032,l_Kenitem033,l_Kenitem034,l_Kenitem035,
					l_Kenitem036,l_Kenitem037,l_Kenitem038,l_Kenitem039,l_Kenitem040,
					l_Kenitem041,l_Kenitem042,l_Kenitem043,l_Kenitem044,l_Kenitem045,
					l_Kenitem046,l_Kenitem047,l_Kenitem048,l_Kenitem049,l_Kenitem050,
					l_Kenitem051,l_Kenitem052,l_Kenitem053,l_Kenitem054,l_Kenitem055,
					l_Kenitem056,l_Kenitem057,l_Kenitem058,l_Kenitem059,l_Kenitem060,
					l_Kenitem061,l_Kenitem062,l_Kenitem063,l_Kenitem064,l_Kenitem065,
					l_Kenitem066,l_Kenitem067,l_Kenitem068,l_Kenitem069,l_Kenitem070,
					l_Kenitem071,l_Kenitem072,l_Kenitem073,l_Kenitem074,l_Kenitem075,
					l_Kenitem076,l_Kenitem077,l_Kenitem078,l_Kenitem079,l_Kenitem080,
					l_Kenitem081,l_Kenitem082,l_Kenitem083,l_Kenitem084,l_Kenitem085,
					l_Kenitem086,l_Kenitem087,l_Kenitem088,l_Kenitem089,l_Kenitem090,
					l_Kenitem091,l_Kenitem092,l_Kenitem093,l_Kenitem094,l_Kenitem095,
					l_Kenitem096,l_Kenitem097,l_Kenitem098,l_Kenitem099,l_Kenitem100,
					l_Riitem001,l_Riitem002,l_Riitem003,l_Riitem004,l_Riitem005,
					l_Riitem006,l_Riitem007,l_Riitem008,l_Riitem009,l_Riitem010,
					l_Riitem011,l_Riitem012,l_Riitem013,l_Riitem014,l_Riitem015,
					l_Riitem016,l_Riitem017,l_Riitem018,l_Riitem019,l_Riitem020,
					l_Riitem021,l_Riitem022,l_Riitem023,l_Riitem024,l_Riitem025,
					l_Riitem026,l_Riitem027,l_Riitem028,l_Riitem029,l_Riitem030,
					l_Riitem031,l_Riitem032,l_Riitem033,l_Riitem034,l_Riitem035,
					l_Riitem036,l_Riitem037,l_Riitem038,l_Riitem039,l_Riitem040,
					l_Riitem041,l_Riitem042,l_Riitem043,l_Riitem044,l_Riitem045,
					l_Riitem046,l_Riitem047,l_Riitem048,l_Riitem049,l_Riitem050,
					l_Riitem051,l_Riitem052,l_Riitem053,l_Riitem054,l_Riitem055,
					l_Riitem056,l_Riitem057,l_Riitem058,l_Riitem059,l_Riitem060,
					l_Riitem061,l_Riitem062,l_Riitem063,l_Riitem064,l_Riitem065,
					l_Riitem066,l_Riitem067,l_Riitem068,l_Riitem069,l_Riitem070,
					l_Riitem071,l_Riitem072,l_Riitem073,l_Riitem074,l_Riitem075,
					l_Riitem076,l_Riitem077,l_Riitem078,l_Riitem079,l_Riitem080,
					l_Riitem081,l_Riitem082,l_Riitem083,l_Riitem084,l_Riitem085,
					l_Riitem086,l_Riitem087,l_Riitem088,l_Riitem089,l_Riitem090,
					l_Riitem091,l_Riitem092,l_Riitem093,l_Riitem094,l_Riitem095,
					l_Riitem096,l_Riitem097,l_Riitem098,l_Riitem099,l_Riitem100;
				EXIT WHEN NOT FOUND;/* apply on curRec */
				l_Kenitems[1] := l_Kenitem001;
				l_Kenitems[2] := l_Kenitem002;
				l_Kenitems[3] := l_Kenitem003;
				l_Kenitems[4] := l_Kenitem004;
				l_Kenitems[5] := l_Kenitem005;
				l_Kenitems[6] := l_Kenitem006;
				l_Kenitems[7] := l_Kenitem007;
				l_Kenitems[8] := l_Kenitem008;
				l_Kenitems[9] := l_Kenitem009;
				l_Kenitems[10] := l_Kenitem010;
				l_Kenitems[11] := l_Kenitem011;
				l_Kenitems[12] := l_Kenitem012;
				l_Kenitems[13] := l_Kenitem013;
				l_Kenitems[14] := l_Kenitem014;
				l_Kenitems[15] := l_Kenitem015;
				l_Kenitems[16] := l_Kenitem016;
				l_Kenitems[17] := l_Kenitem017;
				l_Kenitems[18] := l_Kenitem018;
				l_Kenitems[19] := l_Kenitem019;
				l_Kenitems[20] := l_Kenitem020;
				l_Kenitems[21] := l_Kenitem021;
				l_Kenitems[22] := l_Kenitem022;
				l_Kenitems[23] := l_Kenitem023;
				l_Kenitems[24] := l_Kenitem024;
				l_Kenitems[25] := l_Kenitem025;
				l_Kenitems[26] := l_Kenitem026;
				l_Kenitems[27] := l_Kenitem027;
				l_Kenitems[28] := l_Kenitem028;
				l_Kenitems[29] := l_Kenitem029;
				l_Kenitems[30] := l_Kenitem030;
				l_Kenitems[31] := l_Kenitem031;
				l_Kenitems[32] := l_Kenitem032;
				l_Kenitems[33] := l_Kenitem033;
				l_Kenitems[34] := l_Kenitem034;
				l_Kenitems[35] := l_Kenitem035;
				l_Kenitems[36] := l_Kenitem036;
				l_Kenitems[37] := l_Kenitem037;
				l_Kenitems[38] := l_Kenitem038;
				l_Kenitems[39] := l_Kenitem039;
				l_Kenitems[40] := l_Kenitem040;
				l_Kenitems[41] := l_Kenitem041;
				l_Kenitems[42] := l_Kenitem042;
				l_Kenitems[43] := l_Kenitem043;
				l_Kenitems[44] := l_Kenitem044;
				l_Kenitems[45] := l_Kenitem045;
				l_Kenitems[46] := l_Kenitem046;
				l_Kenitems[47] := l_Kenitem047;
				l_Kenitems[48] := l_Kenitem048;
				l_Kenitems[49] := l_Kenitem049;
				l_Kenitems[50] := l_Kenitem050;
				l_Kenitems[51] := l_Kenitem051;
				l_Kenitems[52] := l_Kenitem052;
				l_Kenitems[53] := l_Kenitem053;
				l_Kenitems[54] := l_Kenitem054;
				l_Kenitems[55] := l_Kenitem055;
				l_Kenitems[56] := l_Kenitem056;
				l_Kenitems[57] := l_Kenitem057;
				l_Kenitems[58] := l_Kenitem058;
				l_Kenitems[59] := l_Kenitem059;
				l_Kenitems[60] := l_Kenitem060;
				l_Kenitems[61] := l_Kenitem061;
				l_Kenitems[62] := l_Kenitem062;
				l_Kenitems[63] := l_Kenitem063;
				l_Kenitems[64] := l_Kenitem064;
				l_Kenitems[65] := l_Kenitem065;
				l_Kenitems[66] := l_Kenitem066;
				l_Kenitems[67] := l_Kenitem067;
				l_Kenitems[68] := l_Kenitem068;
				l_Kenitems[69] := l_Kenitem069;
				l_Kenitems[70] := l_Kenitem070;
				l_Kenitems[71] := l_Kenitem071;
				l_Kenitems[72] := l_Kenitem072;
				l_Kenitems[73] := l_Kenitem073;
				l_Kenitems[74] := l_Kenitem074;
				l_Kenitems[75] := l_Kenitem075;
				l_Kenitems[76] := l_Kenitem076;
				l_Kenitems[77] := l_Kenitem077;
				l_Kenitems[78] := l_Kenitem078;
				l_Kenitems[79] := l_Kenitem079;
				l_Kenitems[80] := l_Kenitem080;
				l_Kenitems[81] := l_Kenitem081;
				l_Kenitems[82] := l_Kenitem082;
				l_Kenitems[83] := l_Kenitem083;
				l_Kenitems[84] := l_Kenitem084;
				l_Kenitems[85] := l_Kenitem085;
				l_Kenitems[86] := l_Kenitem086;
				l_Kenitems[87] := l_Kenitem087;
				l_Kenitems[88] := l_Kenitem088;
				l_Kenitems[89] := l_Kenitem089;
				l_Kenitems[90] := l_Kenitem090;
				l_Kenitems[91] := l_Kenitem091;
				l_Kenitems[92] := l_Kenitem092;
				l_Kenitems[93] := l_Kenitem093;
				l_Kenitems[94] := l_Kenitem094;
				l_Kenitems[95] := l_Kenitem095;
				l_Kenitems[96] := l_Kenitem096;
				l_Kenitems[97] := l_Kenitem097;
				l_Kenitems[98] := l_Kenitem098;
				l_Kenitems[99] := l_Kenitem099;
				l_Kenitems[100] := l_Kenitem100;
				l_Riitems[1] := l_Riitem001;
				l_Riitems[2] := l_Riitem002;
				l_Riitems[3] := l_Riitem003;
				l_Riitems[4] := l_Riitem004;
				l_Riitems[5] := l_Riitem005;
				l_Riitems[6] := l_Riitem006;
				l_Riitems[7] := l_Riitem007;
				l_Riitems[8] := l_Riitem008;
				l_Riitems[9] := l_Riitem009;
				l_Riitems[10] := l_Riitem010;
				l_Riitems[11] := l_Riitem011;
				l_Riitems[12] := l_Riitem012;
				l_Riitems[13] := l_Riitem013;
				l_Riitems[14] := l_Riitem014;
				l_Riitems[15] := l_Riitem015;
				l_Riitems[16] := l_Riitem016;
				l_Riitems[17] := l_Riitem017;
				l_Riitems[18] := l_Riitem018;
				l_Riitems[19] := l_Riitem019;
				l_Riitems[20] := l_Riitem020;
				l_Riitems[21] := l_Riitem021;
				l_Riitems[22] := l_Riitem022;
				l_Riitems[23] := l_Riitem023;
				l_Riitems[24] := l_Riitem024;
				l_Riitems[25] := l_Riitem025;
				l_Riitems[26] := l_Riitem026;
				l_Riitems[27] := l_Riitem027;
				l_Riitems[28] := l_Riitem028;
				l_Riitems[29] := l_Riitem029;
				l_Riitems[30] := l_Riitem030;
				l_Riitems[31] := l_Riitem031;
				l_Riitems[32] := l_Riitem032;
				l_Riitems[33] := l_Riitem033;
				l_Riitems[34] := l_Riitem034;
				l_Riitems[35] := l_Riitem035;
				l_Riitems[36] := l_Riitem036;
				l_Riitems[37] := l_Riitem037;
				l_Riitems[38] := l_Riitem038;
				l_Riitems[39] := l_Riitem039;
				l_Riitems[40] := l_Riitem040;
				l_Riitems[41] := l_Riitem041;
				l_Riitems[42] := l_Riitem042;
				l_Riitems[43] := l_Riitem043;
				l_Riitems[44] := l_Riitem044;
				l_Riitems[45] := l_Riitem045;
				l_Riitems[46] := l_Riitem046;
				l_Riitems[47] := l_Riitem047;
				l_Riitems[48] := l_Riitem048;
				l_Riitems[49] := l_Riitem049;
				l_Riitems[50] := l_Riitem050;
				l_Riitems[51] := l_Riitem051;
				l_Riitems[52] := l_Riitem052;
				l_Riitems[53] := l_Riitem053;
				l_Riitems[54] := l_Riitem054;
				l_Riitems[55] := l_Riitem055;
				l_Riitems[56] := l_Riitem056;
				l_Riitems[57] := l_Riitem057;
				l_Riitems[58] := l_Riitem058;
				l_Riitems[59] := l_Riitem059;
				l_Riitems[60] := l_Riitem060;
				l_Riitems[61] := l_Riitem061;
				l_Riitems[62] := l_Riitem062;
				l_Riitems[63] := l_Riitem063;
				l_Riitems[64] := l_Riitem064;
				l_Riitems[65] := l_Riitem065;
				l_Riitems[66] := l_Riitem066;
				l_Riitems[67] := l_Riitem067;
				l_Riitems[68] := l_Riitem068;
				l_Riitems[69] := l_Riitem069;
				l_Riitems[70] := l_Riitem070;
				l_Riitems[71] := l_Riitem071;
				l_Riitems[72] := l_Riitem072;
				l_Riitems[73] := l_Riitem073;
				l_Riitems[74] := l_Riitem074;
				l_Riitems[75] := l_Riitem075;
				l_Riitems[76] := l_Riitem076;
				l_Riitems[77] := l_Riitem077;
				l_Riitems[78] := l_Riitem078;
				l_Riitems[79] := l_Riitem079;
				l_Riitems[80] := l_Riitem080;
				l_Riitems[81] := l_Riitem081;
				l_Riitems[82] := l_Riitem082;
				l_Riitems[83] := l_Riitem083;
				l_Riitems[84] := l_Riitem084;
				l_Riitems[85] := l_Riitem085;
				l_Riitems[86] := l_Riitem086;
				l_Riitems[87] := l_Riitem087;
				l_Riitems[88] := l_Riitem088;
				l_Riitems[89] := l_Riitem089;
				l_Riitems[90] := l_Riitem090;
				l_Riitems[91] := l_Riitem091;
				l_Riitems[92] := l_Riitem092;
				l_Riitems[93] := l_Riitem093;
				l_Riitems[94] := l_Riitem094;
				l_Riitems[95] := l_Riitem095;
				l_Riitems[96] := l_Riitem096;
				l_Riitems[97] := l_Riitem097;
				l_Riitems[98] := l_Riitem098;
				l_Riitems[99] := l_Riitem099;
				l_Riitems[100] := l_Riitem100;
				gKenketsuRfdDef := ARRAY[]::varchar(3)[];
				gRifudaJokendDef := ARRAY[]::varchar(3)[];
				gRino := 0;
				gKenno := 0;
				gCount := 0;
				gKenCount := 0;
				gRiCount := 0;
				FOR i IN 1..100 LOOP
					IF (gGanponIdoJiyu = '1' OR gGanponIdoJiyu = '2' OR gGanponIdoJiyu = '3')
					OR (l_Kenitems(i) = '1' OR l_Kenitems(i) = '2') OR l_Riitems(i) = '1' THEN
						IF l_Kenitems(i) = '1' OR l_Kenitems(i) = '2' THEN
							gKenCount := gKenCount + 1;
							IF i <= 9 THEN
								gRino := gRino + 1;
								gKenketsuRfdDef := array_append(gKenketsuRfdDef, null);
								gKenketsuRfdDef[gRino] := '0' || i;
							ELSE
								gRino := gRino + 1;
								gKenketsuRfdDef := array_append(gKenketsuRfdDef, null);
								gKenketsuRfdDef[gRino] := i;
							END IF;
						END IF;
						IF l_Riitems(i) = '1' THEN
							gRiCount := gRiCount + 1;
							IF i <= 9 THEN
								gKenno := gKenno + 1;
								gRifudaJokendDef := array_append(gRifudaJokendDef, null);
								gRifudaJokendDef[gKenno] := '0' || i;
							ELSE
								gKenno := gKenno + 1;
								gRifudaJokendDef := array_append(gRifudaJokendDef, null);
								gRifudaJokendDef[gKenno] := i;
							END IF;
						END IF;
					ELSE
						gCount := gCount + 1;
					END IF;
				END LOOP;
				IF gCount <> 100 THEN
				    --改ページ時、本件合計枚数、利券合計枚数、欠缺合計枚数をセートする。
					IF (gZenMgrCd IS NOT NULL AND gZenMgrCd::text <> '' AND gZenKaiGo IS NOT NULL AND gZenKaiGo::text <> '')
					AND ((gZenMgrCd <> gMgrCd) OR (gZenKaiGo <> gKaiGo)) THEN
						gHogenKensu := 0;
						gKenKensu := 0;
						gRiKensu := 0;
						gHogenKensu := gHogenKensu + 1;
						gKenKensu := gKenKensu + coalesce(cardinality(gKenketsuRfdDef), 0);
						gRiKensu := gRiKensu + coalesce(cardinality(gRifudaJokendDef), 0);
					ELSE
						gHogenKensu := gHogenKensu + 1;
						gKenKensu := gKenKensu + coalesce(cardinality(gKenketsuRfdDef), 0);
						gRiKensu := gRiKensu + coalesce(cardinality(gRifudaJokendDef), 0);
					END IF;
					gZenKenCnt := coalesce(cardinality(gKenketsuRfdDef), 0);
					gZenRiCnt := coalesce(cardinality(gRifudaJokendDef), 0);
					--gKenCnt := '';
					--gRiCnt := '';
					IF gKenCount = 0 AND gRiCount = 0 THEN
						FOR i IN 1..15 LOOP
							gKenketsuRfdDef := array_append(gKenketsuRfdDef, null);
							gKenketsuRfdDef[i] := '';
							gRifudaJokendDef := array_append(gRifudaJokendDef, null);
							gRifudaJokendDef[i] := '';
						END LOOP;
					END IF;
					--毎行１５個値ではなければ、””を追加する。
					IF gZenKenCnt > gZenRiCnt THEN
					   gTotalCount := CEIL(gZenKenCnt/RTN_CNT) * RTN_CNT;
					ELSE
					   gTotalCount := CEIL(gZenRiCnt/RTN_CNT) * RTN_CNT;
				    END IF;
				   FOR i IN (gZenKenCnt + 1)..gTotalCount LOOP
						gKenketsuRfdDef := array_append(gKenketsuRfdDef, null);
						gKenketsuRfdDef[i] := '';
				   END LOOP;
				   FOR i IN (gZenRiCnt + 1)..gTotalCount LOOP
						gRifudaJokendDef := array_append(gRifudaJokendDef, null);
						gRifudaJokendDef[i] := '';
                   END LOOP;
					--タイトルの設定
					IF cnt = 1 THEN
					   IF gKenSu > 0 THEN
					       gTitle1 := PROGRAM_NAME || '（時効分）（控）';
					    ELSE
                            gTitle1 := PROGRAM_NAME || '（控）';
                        END IF;
					ELSE
					   IF gKenSu > 0 THEN
                           gTitle1 := PROGRAM_NAME || '（時効分）';
                       ELSE
                           gTitle1 := PROGRAM_NAME;
                       END IF;
					END IF;
					IF (gZenMgrCd IS NOT NULL AND gZenMgrCd::text <> '' AND gZenKaiGo IS NOT NULL AND gZenKaiGo::text <> '')
					AND ((gZenMgrCd <> gMgrCd) OR (gZenKaiGo <> gKaiGo)) THEN
						gSeqNo := gSeqNo + 1;			
								-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gZenMgrCd;	-- 銘柄コード
		v_item.l_inItem002 := gZenKaiGo;	-- 回号コード
		v_item.l_inItem003 := gZenKaiGoNm1;	-- 回号正式名称１
		v_item.l_inItem004 := gZenKaiGoNm2;	-- 回号正式名称２
		v_item.l_inItem005 := '';	-- 券種
		v_item.l_inItem006 := '';	-- 記番号
		v_item.l_inItem007 := '';	-- 事故発生日
		v_item.l_inItem038 := gZenTitle1;	-- タイトル
		v_item.l_inItem039 := gZenHogenKensu;	-- 本件合計枚数
		v_item.l_inItem040 := gZenKenKensu;	-- 利券合計枚数
		v_item.l_inItem041 := gZenRiKensu;	-- 欠缺合計枚数
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> gReportId,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
					END IF;
					gZenMgrCd := gMgrCd;
					gZenKaiGo := gKaiGo;
					gZenKaiGoNm1 := gKaiGoNm1;
					gZenKaiGoNm2 := gKaiGoNm2;
					gZenHogenKensu := gHogenKensu;
					gZenKenKensu := gKenKensu;
					gZenRiKensu := gRiKensu;
					gZenTitle1 := gTitle1;
					gCnt := TRUNC(COALESCE(cardinality(gKenketsuRfdDef), 0)/RTN_CNT);
					FOR i IN 1..gCnt LOOP
						gSeqNo := gSeqNo + 1;
						IF i = 1 THEN
									-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gMgrCd;	-- 銘柄コード
		v_item.l_inItem002 := gKaiGo;	-- 回号コード
		v_item.l_inItem003 := gKaiGoNm1;	-- 回号正式名称１
		v_item.l_inItem004 := gKaiGoNm2;	-- 回号正式名称２
		v_item.l_inItem005 := gKenShu;	-- 券種
		v_item.l_inItem006 := gKiBanGO;	-- 記番号
		v_item.l_inItem007 := gGanponIdoHasseiYmd;	-- 事故発生日
		v_item.l_inItem008 := gKenketsuRfdDef[(i-1) * RTN_CNT + 1];	-- 利札異動事由_利渡期01
		v_item.l_inItem009 := gKenketsuRfdDef[(i-1) * RTN_CNT + 2];	-- 利札異動事由_利渡期02
		v_item.l_inItem010 := gKenketsuRfdDef[(i-1) * RTN_CNT + 3];	-- 利札異動事由_利渡期03
		v_item.l_inItem011 := gKenketsuRfdDef[(i-1) * RTN_CNT + 4];	-- 利札異動事由_利渡期04
		v_item.l_inItem012 := gKenketsuRfdDef[(i-1) * RTN_CNT + 5];	-- 利札異動事由_利渡期05
		v_item.l_inItem013 := gKenketsuRfdDef[(i-1) * RTN_CNT + 6];	-- 利札異動事由_利渡期06
		v_item.l_inItem014 := gKenketsuRfdDef[(i-1) * RTN_CNT + 7];	-- 利札異動事由_利渡期07
		v_item.l_inItem015 := gKenketsuRfdDef[(i-1) * RTN_CNT + 8];	-- 利札異動事由_利渡期08
		v_item.l_inItem016 := gKenketsuRfdDef[(i-1) * RTN_CNT + 9];	-- 利札異動事由_利渡期09
		v_item.l_inItem017 := gKenketsuRfdDef[(i-1) * RTN_CNT + 10];	-- 利札異動事由_利渡期10
		v_item.l_inItem018 := gKenketsuRfdDef[(i-1) * RTN_CNT + 11];	-- 利札異動事由_利渡期11
		v_item.l_inItem019 := gKenketsuRfdDef[(i-1) * RTN_CNT + 12];	-- 利札異動事由_利渡期12
		v_item.l_inItem020 := gKenketsuRfdDef[(i-1) * RTN_CNT + 13];	-- 利札異動事由_利渡期13
		v_item.l_inItem021 := gKenketsuRfdDef[(i-1) * RTN_CNT + 14];	-- 利札異動事由_利渡期14
		v_item.l_inItem022 := gKenketsuRfdDef[(i-1) * RTN_CNT + 15];	-- 利札異動事由_利渡期15
		v_item.l_inItem023 := gRifudaJokendDef[(i-1) * RTN_CNT + 1];	-- けん欠利札区分_利渡期01
		v_item.l_inItem024 := gRifudaJokendDef[(i-1) * RTN_CNT + 2];	-- けん欠利札区分_利渡期02
		v_item.l_inItem025 := gRifudaJokendDef[(i-1) * RTN_CNT + 3];	-- けん欠利札区分_利渡期03
		v_item.l_inItem026 := gRifudaJokendDef[(i-1) * RTN_CNT + 4];	-- けん欠利札区分_利渡期04
		v_item.l_inItem027 := gRifudaJokendDef[(i-1) * RTN_CNT + 5];	-- けん欠利札区分_利渡期05
		v_item.l_inItem028 := gRifudaJokendDef[(i-1) * RTN_CNT + 6];	-- けん欠利札区分_利渡期06
		v_item.l_inItem029 := gRifudaJokendDef[(i-1) * RTN_CNT + 7];	-- けん欠利札区分_利渡期07
		v_item.l_inItem030 := gRifudaJokendDef[(i-1) * RTN_CNT + 8];	-- けん欠利札区分_利渡期08
		v_item.l_inItem031 := gRifudaJokendDef[(i-1) * RTN_CNT + 9];	-- けん欠利札区分_利渡期09
		v_item.l_inItem032 := gRifudaJokendDef[(i-1) * RTN_CNT + 10];	-- けん欠利札区分_利渡期10
		v_item.l_inItem033 := gRifudaJokendDef[(i-1) * RTN_CNT + 11];	-- けん欠利札区分_利渡期11
		v_item.l_inItem034 := gRifudaJokendDef[(i-1) * RTN_CNT + 12];	-- けん欠利札区分_利渡期12
		v_item.l_inItem035 := gRifudaJokendDef[(i-1) * RTN_CNT + 13];	-- けん欠利札区分_利渡期13
		v_item.l_inItem036 := gRifudaJokendDef[(i-1) * RTN_CNT + 14];	-- けん欠利札区分_利渡期14
		v_item.l_inItem037 := gRifudaJokendDef[(i-1) * RTN_CNT + 15];	-- けん欠利札区分_利渡期15
		v_item.l_inItem038 := gTitle1;	-- タイトル
		v_item.l_inItem039 := '';	-- 本件合計枚数
		v_item.l_inItem040 := '';	-- 利券合計枚数
		v_item.l_inItem041 := '';	-- 欠缺合計枚数
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> gReportId,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
						ELSE
									-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gMgrCd;	-- 銘柄コード
		v_item.l_inItem002 := gKaiGo;	-- 回号コード
		v_item.l_inItem003 := gKaiGoNm1;	-- 回号正式名称１
		v_item.l_inItem004 := gKaiGoNm2;	-- 回号正式名称２
		v_item.l_inItem005 := '';	-- 券種
		v_item.l_inItem006 := '';	-- 記番号
		v_item.l_inItem007 := '';	-- 事故発生日
		v_item.l_inItem008 := gKenketsuRfdDef[(i-1) * RTN_CNT + 1];	-- 利札異動事由_利渡期01
		v_item.l_inItem009 := gKenketsuRfdDef[(i-1) * RTN_CNT + 2];	-- 利札異動事由_利渡期02
		v_item.l_inItem010 := gKenketsuRfdDef[(i-1) * RTN_CNT + 3];	-- 利札異動事由_利渡期03
		v_item.l_inItem011 := gKenketsuRfdDef[(i-1) * RTN_CNT + 4];	-- 利札異動事由_利渡期04
		v_item.l_inItem012 := gKenketsuRfdDef[(i-1) * RTN_CNT + 5];	-- 利札異動事由_利渡期05
		v_item.l_inItem013 := gKenketsuRfdDef[(i-1) * RTN_CNT + 6];	-- 利札異動事由_利渡期06
		v_item.l_inItem014 := gKenketsuRfdDef[(i-1) * RTN_CNT + 7];	-- 利札異動事由_利渡期07
		v_item.l_inItem015 := gKenketsuRfdDef[(i-1) * RTN_CNT + 8];	-- 利札異動事由_利渡期08
		v_item.l_inItem016 := gKenketsuRfdDef[(i-1) * RTN_CNT + 9];	-- 利札異動事由_利渡期09
		v_item.l_inItem017 := gKenketsuRfdDef[(i-1) * RTN_CNT + 10];	-- 利札異動事由_利渡期10
		v_item.l_inItem018 := gKenketsuRfdDef[(i-1) * RTN_CNT + 11];	-- 利札異動事由_利渡期11
		v_item.l_inItem019 := gKenketsuRfdDef[(i-1) * RTN_CNT + 12];	-- 利札異動事由_利渡期12
		v_item.l_inItem020 := gKenketsuRfdDef[(i-1) * RTN_CNT + 13];	-- 利札異動事由_利渡期13
		v_item.l_inItem021 := gKenketsuRfdDef[(i-1) * RTN_CNT + 14];	-- 利札異動事由_利渡期14
		v_item.l_inItem022 := gKenketsuRfdDef[(i-1) * RTN_CNT + 15];	-- 利札異動事由_利渡期15
		v_item.l_inItem023 := gRifudaJokendDef[(i-1) * RTN_CNT + 1];	-- けん欠利札区分_利渡期01
		v_item.l_inItem024 := gRifudaJokendDef[(i-1) * RTN_CNT + 2];	-- けん欠利札区分_利渡期02
		v_item.l_inItem025 := gRifudaJokendDef[(i-1) * RTN_CNT + 3];	-- けん欠利札区分_利渡期03
		v_item.l_inItem026 := gRifudaJokendDef[(i-1) * RTN_CNT + 4];	-- けん欠利札区分_利渡期04
		v_item.l_inItem027 := gRifudaJokendDef[(i-1) * RTN_CNT + 5];	-- けん欠利札区分_利渡期05
		v_item.l_inItem028 := gRifudaJokendDef[(i-1) * RTN_CNT + 6];	-- けん欠利札区分_利渡期06
		v_item.l_inItem029 := gRifudaJokendDef[(i-1) * RTN_CNT + 7];	-- けん欠利札区分_利渡期07
		v_item.l_inItem030 := gRifudaJokendDef[(i-1) * RTN_CNT + 8];	-- けん欠利札区分_利渡期08
		v_item.l_inItem031 := gRifudaJokendDef[(i-1) * RTN_CNT + 9];	-- けん欠利札区分_利渡期09
		v_item.l_inItem032 := gRifudaJokendDef[(i-1) * RTN_CNT + 10];	-- けん欠利札区分_利渡期10
		v_item.l_inItem033 := gRifudaJokendDef[(i-1) * RTN_CNT + 11];	-- けん欠利札区分_利渡期11
		v_item.l_inItem034 := gRifudaJokendDef[(i-1) * RTN_CNT + 12];	-- けん欠利札区分_利渡期12
		v_item.l_inItem035 := gRifudaJokendDef[(i-1) * RTN_CNT + 13];	-- けん欠利札区分_利渡期13
		v_item.l_inItem036 := gRifudaJokendDef[(i-1) * RTN_CNT + 14];	-- けん欠利札区分_利渡期14
		v_item.l_inItem037 := gRifudaJokendDef[(i-1) * RTN_CNT + 15];	-- けん欠利札区分_利渡期15
		v_item.l_inItem038 := gTitle1;	-- タイトル
		v_item.l_inItem039 := '';	-- 本件合計枚数
		v_item.l_inItem040 := '';	-- 利券合計枚数
		v_item.l_inItem041 := '';	-- 欠缺合計枚数
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> gReportId,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
						END IF;
					END LOOP;
				END IF;
			END LOOP;
		END;
		IF gHogenKensu = 0 THEN
			IF cnt = 1 THEN
				gSeqNo := gSeqNo + 1;
						-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := '';	-- 銘柄コード
		v_item.l_inItem002 := '';	-- 回号コード
		v_item.l_inItem003 := '対象データなし';	-- 回号正式名称１
		v_item.l_inItem004 := '';	-- 回号正式名称２
		v_item.l_inItem005 := '';	-- 券種
		v_item.l_inItem006 := '';	-- 記番号
		v_item.l_inItem007 := '';	-- 事故発生日
		v_item.l_inItem038 := gTitle2;	-- タイトル
		v_item.l_inItem039 := '';	-- 本件合計枚数
		v_item.l_inItem040 := '';	-- 利券合計枚数
		v_item.l_inItem041 := '';	-- 欠缺合計枚数
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> gReportId,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
			END IF;
		ELSE
				gSeqNo := gSeqNo + 1;
						-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gZenMgrCd;	-- 銘柄コード
		v_item.l_inItem002 := gZenKaiGo;	-- 回号コード
		v_item.l_inItem003 := gZenKaiGoNm1;	-- 回号正式名称１
		v_item.l_inItem004 := gZenKaiGoNm2;	-- 回号正式名称２
		v_item.l_inItem005 := '';	-- 券種
		v_item.l_inItem006 := '';	-- 記番号
		v_item.l_inItem007 := '';	-- 事故発生日
		v_item.l_inItem038 := gZenTitle1;	-- タイトル
		v_item.l_inItem039 := gZenHogenKensu;	-- 本件合計枚数
		v_item.l_inItem040 := gZenKenKensu;	-- 利券合計枚数
		v_item.l_inItem041 := gZenRiKensu;	-- 欠缺合計枚数
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> gReportId,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		END IF;
	END LOOP;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	CALL pkLog.debug(l_inUserId,  '○' || PROGRAM_NAME ||'('|| PROGRAM_ID ||')', ' END');
-- エラー処理
EXCEPTION
	WHEN SQLSTATE '50002' THEN
		CALL pkLog.debug(l_inUserId,'△' || PROGRAM_NAME ||'('|| PROGRAM_ID ||')', 'warnGyom');
		l_outSqlCode := gRtnCd;
		l_outSqlErrM := '';
	WHEN SQLSTATE '50001' THEN
		CALL pkLog.debug(l_inUserId, '×' || PROGRAM_NAME ||'('|| PROGRAM_ID ||')', 'errIjou');
		CALL pkLog.error(errCode, PROGRAM_ID, errMsg);
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '';
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', PROGRAM_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', PROGRAM_ID, 'SQLERRM:' || SQLERRM);
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLERRM;
		CALL pkLog.debug(l_inUserId, REPORT_ID, '×' || PROGRAM_ID || ' END（例外発生）');
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipi002k14r03 ( l_inItakuKaishaCd text, l_inUserId text, l_inChohyoKbn text, l_inGyomuYmd text, l_inZengetuYmd text, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;