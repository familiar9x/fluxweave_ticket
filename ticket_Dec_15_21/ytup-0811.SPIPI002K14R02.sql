


CREATE OR REPLACE PROCEDURE spipi002k14r02 ( l_inItakuKaishaCd text,        -- 委託会社コード
 l_inUserId text,        -- ユーザID
 l_inChohyoKbn text,        -- 帳票区分
 l_inGyomuYmd text,        -- 業務日付
 l_inTorihikiYmd text,        -- 前月末日
 l_outSqlCode OUT integer,      -- リターン値
 l_outSqlErrM OUT text     -- エラーコメント
 ) AS $body$
DECLARE

--
-- * 著作権:Copyright(c)2013
-- * 会社名:JIP
-- *
-- * 概要　:現物債未払管理入力取込の画面より、現物債銘柄マスタ、回号マスタを抽出し帳票を作成する。
-- *
-- * 引数　:l_inItakuKaishaCd  : 委託会社コード
-- *        l_inUserId         : ユーザID
-- *        l_inChohyoKbn      : 帳票区分
-- *        l_inGyomuYmd       : 業務日付
-- *        l_inChohyoId       : 帳票ID
-- *        l_outSqlCode       : リターン値
-- *        l_outSqlErrM       : エラーコメント
-- *
-- * 返り値: なし
-- *
-- * @author Xu Chunxu
-- * @version $Id: SPIPI002K14R02.sql,v 1.7 2013/08/12 06:09:25 ito Exp $
--
	--==============================================================================
	--                  デバッグ機能                                                 
	--==============================================================================
	DEBUG	numeric(1)	:= 0;
	--==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	REPORT_ID        CONSTANT text     := 'IP931400221';   -- 帳票ＩＤ（控）
	KREPORT_ID        CONSTANT text     := 'IP931400222';   -- 帳票ＩＤ
	PROGRAM_ID      CONSTANT text      := 'SPIPI002K14R02';  -- SP名称
	PROGRAM_NAME      CONSTANT text    := '現物債未払利札一覧表';  -- 機能名称
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
    gRtnCd            numeric := pkconstant.success();      -- リターンコード
	gReportId         varchar(11) := NULL;                  --帳票ID
	
	
    gSelectDef        varchar(32767) := '';               -- 変数．検索項目
    gTableDefSUB_TBL1 varchar(32767) := '';               -- 変数．検索項目
    gTableDefSUB_TBL4 varchar(32767) := '';               -- 変数．検索項目
    gTableDefSUB_TBL2 varchar(32767) := '';               -- 変数．検索項目
    gTableDefSUB_TBL3 varchar(32767) := '';               -- 変数．検索項目
    gTableDefSUB_TBL5 varchar(32767) := '';               -- 変数．検索項目
    gMgrCd             varchar(7) := NULL;               -- 銘柄コード
    gKaiGo             varchar(6) := NULL;               -- 回号コード
    gZenMgrCd          varchar(7) := NULL;               -- 前回銘柄コード
    gZenKaiGo          varchar(6) := NULL;               -- 前回回号コード
    gKaiGoNm1          varchar(40) := NULL;               -- 回号正式名称１
    gKaiGoNm2          varchar(40) := NULL;               -- 回号正式名称２
    gZenKaiGoNm1       varchar(40) := NULL;               -- 前回回号正式名称１
    gZenKaiGoNm2       varchar(40) := NULL;               -- 前回回号正式名称２
    gKenShuCd          varchar(2) := NULL;               -- 券種コード
    gZenKenShuCd       varchar(2) := NULL;               -- 前回券種コード
    gKenShu            varchar(14) := NULL;               -- 前回券種
    gZenKenShu         varchar(14) := NULL;               -- 券種
    gKiBanGO           varchar(6) := NULL;               -- 記番号
    gZenKiBanGO        varchar(6) := NULL;               -- 前回記番号
    gRifudaJokenKbnRwk   varchar(5000) := '';          -- 利札異動事由_利渡期ｘｘｘ
    gBangoSel   varchar(5000) := '';
    gSoKensu           integer := 0;                      -- 総件数
    gSeqNo             integer := 0;                      --シーケンス
    gKenCnt             integer := 0;                      --件数
    gCnt1               integer := 0;                     --利札異動事由_利渡期01件数 
    gCnt2               integer := 0;                     --利札異動事由_利渡期02件数 
    gCnt3               integer := 0;                     --利札異動事由_利渡期03件数 
    gCnt4               integer := 0;                     --利札異動事由_利渡期04件数 
    gCnt5               integer := 0;                     --利札異動事由_利渡期05件数 
    gCnt6               integer := 0;                     --利札異動事由_利渡期06件数 
    gCnt7               integer := 0;                     --利札異動事由_利渡期07件数 
    gCnt8               integer := 0;                     --利札異動事由_利渡期08件数 
    gCnt9               integer := 0;                     --利札異動事由_利渡期09件数 
    gCnt10              integer := 0;                    --利札異動事由_利渡期10件数  
    gCnt11              integer := 0;                    --利札異動事由_利渡期11件数  
    gCnt12              integer := 0;                    --利札異動事由_利渡期12件数  
    gCnt13              integer := 0;                    --利札異動事由_利渡期13件数  
    gCnt14              integer := 0;                    --利札異動事由_利渡期14件数  
    gCnt15              integer := 0;                    --利札異動事由_利渡期15件数  
    gCnt16              integer := 0;                    --利札異動事由_利渡期16件数  
    gCnt17              integer := 0;                    --利札異動事由_利渡期17件数  
    gCnt18              integer := 0;                    --利札異動事由_利渡期18件数  
    gCnt19              integer := 0;                    --利札異動事由_利渡期19件数  
    gCnt20              integer := 0;                    --利札異動事由_利渡期20件数  
    gCnt21              integer := 0;                    --利札異動事由_利渡期21件数  
    gCnt22              integer := 0;                    --利札異動事由_利渡期22件数  
    gCnt23              integer := 0;                    --利札異動事由_利渡期23件数  
    gCnt24              integer := 0;                    --利札異動事由_利渡期24件数  
    gCnt25              integer := 0;                    --利札異動事由_利渡期25件数  
    gCnt26              integer := 0;                    --利札異動事由_利渡期26件数  
    gCnt27              integer := 0;                    --利札異動事由_利渡期27件数  
    gCnt28              integer := 0;                    --利札異動事由_利渡期28件数  
    gCnt29              integer := 0;                    --利札異動事由_利渡期29件数  
    gCnt30              integer := 0;                    --利札異動事由_利渡期30件数  
    gCnt31              integer := 0;                    --利札異動事由_利渡期31件数  
    gCnt32              integer := 0;                    --利札異動事由_利渡期32件数  
    gCnt33              integer := 0;                    --利札異動事由_利渡期33件数  
    gCnt34              integer := 0;                    --利札異動事由_利渡期34件数  
    gCnt35              integer := 0;                    --利札異動事由_利渡期35件数  
    gCnt36              integer := 0;                    --利札異動事由_利渡期36件数  
    gCnt37              integer := 0;                    --利札異動事由_利渡期37件数  
    gCnt38              integer := 0;                    --利札異動事由_利渡期38件数  
    gCnt39              integer := 0;                    --利札異動事由_利渡期39件数  
    gCnt40              integer := 0;                    --利札異動事由_利渡期40件数  
    gCnt41              integer := 0;                    --利札異動事由_利渡期41件数  
    gTitle1             varchar(100) := NULL;
    gTitle2             varchar(100) := '現物債未払利札一覧表';
    errMsg              varchar(300);
    errCode             varchar(6);
    curRec REFCURSOR;                                           -- 明細ダデータカーソル
    l_Kenitems varchar(400)[];
    -- Temporary variables for FETCH
    v_item1 varchar(400); v_item2 varchar(400); v_item3 varchar(400); v_item4 varchar(400); v_item5 varchar(400);
    v_item6 varchar(400); v_item7 varchar(400); v_item8 varchar(400); v_item9 varchar(400); v_item10 varchar(400);
    v_item11 varchar(400); v_item12 varchar(400); v_item13 varchar(400); v_item14 varchar(400); v_item15 varchar(400);
    v_item16 varchar(400); v_item17 varchar(400); v_item18 varchar(400); v_item19 varchar(400); v_item20 varchar(400);
    v_item21 varchar(400); v_item22 varchar(400); v_item23 varchar(400); v_item24 varchar(400); v_item25 varchar(400);
    v_item26 varchar(400); v_item27 varchar(400); v_item28 varchar(400); v_item29 varchar(400); v_item30 varchar(400);
    v_item31 varchar(400); v_item32 varchar(400); v_item33 varchar(400); v_item34 varchar(400); v_item35 varchar(400);
    v_item36 varchar(400); v_item37 varchar(400); v_item38 varchar(400); v_item39 varchar(400); v_item40 varchar(400);
    v_item41 varchar(400); v_item42 varchar(400); v_item43 varchar(400); v_item44 varchar(400); v_item45 varchar(400);
    v_item46 varchar(400); v_item47 varchar(400); v_item48 varchar(400); v_item49 varchar(400); v_item50 varchar(400);
    v_item51 varchar(400); v_item52 varchar(400); v_item53 varchar(400); v_item54 varchar(400); v_item55 varchar(400);
    v_item56 varchar(400); v_item57 varchar(400); v_item58 varchar(400); v_item59 varchar(400); v_item60 varchar(400);
    v_item61 varchar(400); v_item62 varchar(400); v_item63 varchar(400); v_item64 varchar(400); v_item65 varchar(400);
    v_item66 varchar(400); v_item67 varchar(400); v_item68 varchar(400); v_item69 varchar(400); v_item70 varchar(400);
    v_item71 varchar(400); v_item72 varchar(400); v_item73 varchar(400); v_item74 varchar(400); v_item75 varchar(400);
    v_item76 varchar(400); v_item77 varchar(400); v_item78 varchar(400); v_item79 varchar(400); v_item80 varchar(400);
    v_item81 varchar(400); v_item82 varchar(400); v_item83 varchar(400); v_item84 varchar(400); v_item85 varchar(400);
    v_item86 varchar(400); v_item87 varchar(400); v_item88 varchar(400); v_item89 varchar(400); v_item90 varchar(400);
    v_item91 varchar(400); v_item92 varchar(400); v_item93 varchar(400); v_item94 varchar(400); v_item95 varchar(400);
    v_item96 varchar(400); v_item97 varchar(400); v_item98 varchar(400); v_item99 varchar(400); v_item100 varchar(400);
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
	OR (coalesce(trim(both l_inTorihikiYmd)::text, '') = '')
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
		AND (CHOHYO_ID = KREPORT_ID OR CHOHYO_ID = REPORT_ID);
	gTableDefSUB_TBL4 := gTableDefSUB_TBL4 || ' (SELECT ';
	gTableDefSUB_TBL4 := gTableDefSUB_TBL4 || ' ITAKU_KAISHA_CD, ';
	gTableDefSUB_TBL4 := gTableDefSUB_TBL4 || ' MGR_CD, ';
	gTableDefSUB_TBL4 := gTableDefSUB_TBL4 || ' COUNT(1) AS kenCnt ';
	gTableDefSUB_TBL4 := gTableDefSUB_TBL4 || ' FROM ';
	gTableDefSUB_TBL4 := gTableDefSUB_TBL4 || ' BD_NYUSHUKIN ';
	gTableDefSUB_TBL4 := gTableDefSUB_TBL4 || ' WHERE ';
	gTableDefSUB_TBL4 := gTableDefSUB_TBL4 || ' ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' ';
	gTableDefSUB_TBL4 := gTableDefSUB_TBL4 || ' AND TORIHIKI_YMD <=  ''' || l_inTorihikiYmd || ''' ';
	gTableDefSUB_TBL4 := gTableDefSUB_TBL4 || ' AND TORIHIKI_S_KBN IN (''2C'',''2D'',''2G'',''2H'')  ';
	gTableDefSUB_TBL4 := gTableDefSUB_TBL4 || ' GROUP BY  ';
	gTableDefSUB_TBL4 := gTableDefSUB_TBL4 || ' ITAKU_KAISHA_CD,MGR_CD) SUB_TBL4 ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' (SELECT ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GNBT_MGR_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' HAKKO_KENSHU1 AS HAKKO_KENSHU, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_KNGK1::varchar AS KENSHU_KNGK, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_NM1 AS KENSHU_NM, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM1, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM2 ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' FROM ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GB_KAIGO ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' WHERE ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND TRIM(RIFUDA_OUT_YOKUSEI_FLG) IS NULL ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KIBANGO_KANRI_KBN =  ''1'' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KAKUNIN_YMD <>  '' '' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' UNION ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' SELECT ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GNBT_MGR_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' HAKKO_KENSHU2 AS HAKKO_KENSHU, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_KNGK2::varchar AS KENSHU_KNGK, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_NM2 AS KENSHU_NM, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM1, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM2 ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' FROM ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GB_KAIGO ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' WHERE ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND TRIM(RIFUDA_OUT_YOKUSEI_FLG) IS NULL ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KIBANGO_KANRI_KBN =  ''1'' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KAKUNIN_YMD <>  '' '' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' UNION ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' SELECT ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GNBT_MGR_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' HAKKO_KENSHU3 AS HAKKO_KENSHU, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_KNGK3::varchar AS KENSHU_KNGK, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_NM3 AS KENSHU_NM, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM1, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM2 ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' FROM ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GB_KAIGO ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' WHERE ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND TRIM(RIFUDA_OUT_YOKUSEI_FLG) IS NULL ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KIBANGO_KANRI_KBN =  ''1'' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KAKUNIN_YMD <>  '' '' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' UNION ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' SELECT ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GNBT_MGR_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' HAKKO_KENSHU4 AS HAKKO_KENSHU, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_KNGK4::varchar AS KENSHU_KNGK, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_NM4 AS KENSHU_NM, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM1, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM2 ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' FROM ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GB_KAIGO ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' WHERE ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND TRIM(RIFUDA_OUT_YOKUSEI_FLG) IS NULL ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KIBANGO_KANRI_KBN =  ''1'' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KAKUNIN_YMD <>  '' '' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' UNION ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' SELECT ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GNBT_MGR_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' HAKKO_KENSHU5 AS HAKKO_KENSHU, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_KNGK5::varchar AS KENSHU_KNGK, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_NM5 AS KENSHU_NM, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM1, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM2 ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' FROM ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GB_KAIGO ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' WHERE ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND TRIM(RIFUDA_OUT_YOKUSEI_FLG) IS NULL ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KIBANGO_KANRI_KBN =  ''1'' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KAKUNIN_YMD <>  '' '' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' UNION ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' SELECT ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GNBT_MGR_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' HAKKO_KENSHU6 AS HAKKO_KENSHU, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_KNGK6::varchar AS KENSHU_KNGK, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_NM6 AS KENSHU_NM, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM1, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM2 ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' FROM ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GB_KAIGO ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' WHERE ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND TRIM(RIFUDA_OUT_YOKUSEI_FLG) IS NULL ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KIBANGO_KANRI_KBN =  ''1'' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KAKUNIN_YMD <>  '' '' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' UNION ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' SELECT ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GNBT_MGR_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' HAKKO_KENSHU7 AS HAKKO_KENSHU, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_KNGK7::varchar AS KENSHU_KNGK, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_NM7 AS KENSHU_NM, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM1, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM2 ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' FROM ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GB_KAIGO ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' WHERE ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND TRIM(RIFUDA_OUT_YOKUSEI_FLG) IS NULL ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KIBANGO_KANRI_KBN =  ''1'' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KAKUNIN_YMD <>  '' '' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' UNION ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' SELECT ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GNBT_MGR_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_CD, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' HAKKO_KENSHU8 AS HAKKO_KENSHU, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_KNGK8::varchar AS KENSHU_KNGK, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KENSHU_NM8 AS KENSHU_NM, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM1, ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' KAIGO_NM2 ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' FROM ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' GB_KAIGO ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' WHERE ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND TRIM(RIFUDA_OUT_YOKUSEI_FLG) IS NULL ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KIBANGO_KANRI_KBN =  ''1'' ';
	gTableDefSUB_TBL2 := gTableDefSUB_TBL2 || ' AND KAKUNIN_YMD <>  '' '') SUB_TBL2 ';
	gTableDefSUB_TBL1 := gTableDefSUB_TBL1 || ' (SELECT ';
	gTableDefSUB_TBL1 := gTableDefSUB_TBL1 || ' ITAKU_KAISHA_CD, ';
	gTableDefSUB_TBL1 := gTableDefSUB_TBL1 || ' GNBT_MGR_CD, ';
	gTableDefSUB_TBL1 := gTableDefSUB_TBL1 || ' KAIGO_CD, ';
	gTableDefSUB_TBL1 := gTableDefSUB_TBL1 || ' MAX(TRIM(RIWATARIKI)) AS RIWATARIKI';
	gTableDefSUB_TBL1 := gTableDefSUB_TBL1 || ' FROM ';
	gTableDefSUB_TBL1 := gTableDefSUB_TBL1 || ' GB_RIWATARIKI ';
	gTableDefSUB_TBL1 := gTableDefSUB_TBL1 || ' WHERE ';
	gTableDefSUB_TBL1 := gTableDefSUB_TBL1 || ' ITAKU_KAISHA_CD =  ''' || l_inItakuKaishaCd || ''' ';
	gTableDefSUB_TBL1 := gTableDefSUB_TBL1 || ' AND RIWATARI_YMD <=  ''' || l_inTorihikiYmd || ''' ';
	gTableDefSUB_TBL1 := gTableDefSUB_TBL1 || ' GROUP BY ';
	gTableDefSUB_TBL1 := gTableDefSUB_TBL1 || ' ITAKU_KAISHA_CD, GNBT_MGR_CD, KAIGO_CD) SUB_TBL1';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' (SELECT ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' SUB_TBL2.ITAKU_KAISHA_CD, ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' SUB_TBL2.GNBT_MGR_CD, ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' SUB_TBL2.KAIGO_CD, ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' CASE WHEN TRIM(GB_KENSHU.KENSHU_NM) = '''' THEN SUB_TBL2.KENSHU_NM ELSE GB_KENSHU.KENSHU_NM END AS KENSHU_NM, ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' CASE WHEN TRIM(GB_KENSHU.GB_KENSHU_CD) = '''' THEN SUB_TBL2.HAKKO_KENSHU ELSE GB_KENSHU.GB_KENSHU_CD END AS GB_KENSHU_CD, ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' CASE WHEN TRIM(pkcharacter.numeric_to_char(GB_KENSHU.KENSHU_KNGK)) = '''' THEN SUB_TBL2.KENSHU_KNGK ELSE pkcharacter.numeric_to_char(GB_KENSHU.KENSHU_KNGK) END AS KENSHU_KNGK, ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' SUB_TBL2.KAIGO_NM1, ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' SUB_TBL2.KAIGO_NM2, ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' SUB_TBL1.RIWATARIKI ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' FROM ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' GB_MGR, GB_GENSAI_RIREKI, GB_RIWATARIKI, ' || gTableDefSUB_TBL2 || ', ' || gTableDefSUB_TBL1;
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ', GB_KENSHU ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' WHERE ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' GB_MGR.KOSHASAI_BNRI <> ''07'' ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' AND GB_MGR.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' AND GB_MGR.ITAKU_KAISHA_CD = SUB_TBL2.ITAKU_KAISHA_CD ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' AND GB_MGR.GNBT_MGR_CD = SUB_TBL2.GNBT_MGR_CD ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' AND SUB_TBL2.HAKKO_KENSHU <> '' '' ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' AND GB_RIWATARIKI.ITAKU_KAISHA_CD = SUB_TBL1.ITAKU_KAISHA_CD ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' AND GB_RIWATARIKI.GNBT_MGR_CD = SUB_TBL1.GNBT_MGR_CD ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' AND GB_RIWATARIKI.KAIGO_CD = SUB_TBL1.KAIGO_CD ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' AND GB_RIWATARIKI.RIWATARIKI = SUB_TBL1.RIWATARIKI ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' AND SUB_TBL2.ITAKU_KAISHA_CD = SUB_TBL1.ITAKU_KAISHA_CD ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' AND SUB_TBL2.GNBT_MGR_CD = SUB_TBL1.GNBT_MGR_CD ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' AND SUB_TBL2.KAIGO_CD = SUB_TBL1.KAIGO_CD ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' AND SUB_TBL2.ITAKU_KAISHA_CD = GB_GENSAI_RIREKI.ITAKU_KAISHA_CD ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' AND SUB_TBL2.GNBT_MGR_CD = GB_GENSAI_RIREKI.GNBT_MGR_CD ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' AND SUB_TBL2.KAIGO_CD = GB_GENSAI_RIREKI.KAIGO_CD ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' AND GB_GENSAI_RIREKI.TORIHIKI_ZANDAKA = 0 ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' AND TRIM(GB_GENSAI_RIREKI.MUKO_FLG) IS NULL ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' AND (SUB_TBL2.ITAKU_KAISHA_CD = GB_KENSHU.ITAKU_KAISHA_CD OR GB_KENSHU.ITAKU_KAISHA_CD IS NULL) ';
	gTableDefSUB_TBL3 := gTableDefSUB_TBL3 || ' AND (SUB_TBL2.HAKKO_KENSHU = GB_KENSHU.GB_KENSHU_CD OR GB_KENSHU.GB_KENSHU_CD IS NULL)) SUB_TBL3 ';
    FOR i IN 1..100 LOOP
        gRifudaJokenKbnRwk := gRifudaJokenKbnRwk || 'RIFUDA_IDO_JIYU_RWK' || i || ', ';
    END LOOP;
    FOR i IN 1..100 LOOP
       gBangoSel := gBangoSel || ' RIFUDA_IDO_JIYU_RWK' || i || '= ''0''';
       IF i <> 100 THEN
           gBangoSel := gBangoSel || 'OR';
       END IF;
    END LOOP;
	gSelectDef := gSelectDef || ' SELECT ';
	gSelectDef := gSelectDef || ' SUB_TBL4.kenCnt, ';
	gSelectDef := gSelectDef || ' SUB_TBL3.GNBT_MGR_CD, ';
	gSelectDef := gSelectDef || ' SUB_TBL3.KAIGO_CD, ';
	gSelectDef := gSelectDef || ' SUB_TBL3.KAIGO_NM1, ';
	gSelectDef := gSelectDef || ' SUB_TBL3.KAIGO_NM2, ';
	gSelectDef := gSelectDef || ' SUB_TBL3.GB_KENSHU_CD, ';
	gSelectDef := gSelectDef || ' SUB_TBL3.KENSHU_NM, ';
	gSelectDef := gSelectDef || gRifudaJokenKbnRwk;
	gSelectDef := gSelectDef || ' SUB_TBL5.KIBANGO';
	gSelectDef := gSelectDef || ' FROM ';
	gSelectDef := gSelectDef || gTableDefSUB_TBL3 || ', GB_KIBANGO SUB_TBL5';
	gSelectDef := gSelectDef || ' LEFT JOIN ' || gTableDefSUB_TBL4 || ' ON SUB_TBL5.ITAKU_KAISHA_CD = SUB_TBL4.ITAKU_KAISHA_CD ';
	gSelectDef := gSelectDef || ' AND (SUB_TBL5.GNBT_MGR_CD || SUB_TBL5.KAIGO_CD) = SUB_TBL4.MGR_CD ';
	gSelectDef := gSelectDef || ' WHERE ';
	gSelectDef := gSelectDef || ' SUB_TBL5.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' ';
	gSelectDef := gSelectDef || ' AND SUB_TBL5.ITAKU_KAISHA_CD = SUB_TBL3.ITAKU_KAISHA_CD ';
	gSelectDef := gSelectDef || ' AND SUB_TBL5.GNBT_MGR_CD = SUB_TBL3.GNBT_MGR_CD ';
	gSelectDef := gSelectDef || ' AND SUB_TBL5.KAIGO_CD = SUB_TBL3.KAIGO_CD ';
	gSelectDef := gSelectDef || ' AND (' || gBangoSel || ')';
	gSelectDef := gSelectDef || ' AND TRIM(SUB_TBL5.KENSHU_KNGK::varchar) = TRIM(SUB_TBL3.KENSHU_KNGK::varchar) ';
	gSelectDef := gSelectDef || ' ORDER BY ';
	gSelectDef := gSelectDef || ' GNBT_MGR_CD, KAIGO_CD, GB_KENSHU_CD, KIBANGO';
	FOR cnt IN 1..2 LOOP
        gZenMgrCd := '';
        gZenKaiGo := '';
        gZenKaiGoNm1 := '';
        gZenKaiGoNm2 := '';
        gZenKenShuCd := '';
        gZenKenShu := '';
        gZenKiBanGO  := '';
        -- Clear counter variables
        gCnt1:=0; gCnt2:=0; gCnt3:=0; gCnt4:=0; gCnt5:=0; gCnt6:=0; gCnt7:=0; gCnt8:=0; gCnt9:=0; gCnt10:=0;
        gCnt11:=0; gCnt12:=0; gCnt13:=0; gCnt14:=0; gCnt15:=0; gCnt16:=0; gCnt17:=0; gCnt18:=0; gCnt19:=0; gCnt20:=0;
        gCnt21:=0; gCnt22:=0; gCnt23:=0; gCnt24:=0; gCnt25:=0; gCnt26:=0; gCnt27:=0; gCnt28:=0; gCnt29:=0; gCnt30:=0;
        gCnt31:=0; gCnt32:=0; gCnt33:=0; gCnt34:=0; gCnt35:=0; gCnt36:=0; gCnt37:=0; gCnt38:=0; gCnt39:=0; gCnt40:=0; gCnt41:=0;
        l_Kenitems := ARRAY[]::varchar(400)[];
        FOR idx IN 1..100 LOOP
            l_Kenitems := array_append(l_Kenitems, NULL);
        END LOOP;
		--ヘッダレコードを出力
		IF cnt = 1 THEN
			gReportId := REPORT_ID;
			CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, gReportId);
		ELSE
			IF gSoKensu <> 0 THEN
				gReportId := KREPORT_ID;
				CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, gReportId);
			ELSE
				EXIT;
			END IF;
		END IF;
		gSeqNo := 0;
		BEGIN
			OPEN curRec FOR EXECUTE gSelectDef;
			LOOP
				FETCH curRec INTO gKenCnt, gMgrCd, gKaiGo, gKaiGoNm1, gKaiGoNm2, gKenShuCd, gKenShu, -- gRifudaJokenKbnRwk;
                v_item1, v_item2, v_item3, v_item4, v_item5,
                v_item6, v_item7, v_item8, v_item9, v_item10,
                v_item11, v_item12, v_item13, v_item14, v_item15,
                v_item16, v_item17, v_item18, v_item19, v_item20,
                v_item21, v_item22, v_item23, v_item24, v_item25,
                v_item26, v_item27, v_item28, v_item29, v_item30,
                v_item31, v_item32, v_item33, v_item34, v_item35,
                v_item36, v_item37, v_item38, v_item39, v_item40,
                v_item41, v_item42, v_item43, v_item44, v_item45,
                v_item46, v_item47, v_item48, v_item49, v_item50,
                v_item51, v_item52, v_item53, v_item54, v_item55,
                v_item56, v_item57, v_item58, v_item59, v_item60,
                v_item61, v_item62, v_item63, v_item64, v_item65,
                v_item66, v_item67, v_item68, v_item69, v_item70,
                v_item71, v_item72, v_item73, v_item74, v_item75,
                v_item76, v_item77, v_item78, v_item79, v_item80,
                v_item81, v_item82, v_item83, v_item84, v_item85,
                v_item86, v_item87, v_item88, v_item89, v_item90,
                v_item91, v_item92, v_item93, v_item94, v_item95,
                v_item96, v_item97, v_item98, v_item99, v_item100,gKiBanGO;
				EXIT WHEN NOT FOUND;/* apply on curRec */
				-- Copy temp variables to array
				l_Kenitems[1] := v_item1; l_Kenitems[2] := v_item2; l_Kenitems[3] := v_item3; l_Kenitems[4] := v_item4; l_Kenitems[5] := v_item5;
				l_Kenitems[6] := v_item6; l_Kenitems[7] := v_item7; l_Kenitems[8] := v_item8; l_Kenitems[9] := v_item9; l_Kenitems[10] := v_item10;
				l_Kenitems[11] := v_item11; l_Kenitems[12] := v_item12; l_Kenitems[13] := v_item13; l_Kenitems[14] := v_item14; l_Kenitems[15] := v_item15;
				l_Kenitems[16] := v_item16; l_Kenitems[17] := v_item17; l_Kenitems[18] := v_item18; l_Kenitems[19] := v_item19; l_Kenitems[20] := v_item20;
				l_Kenitems[21] := v_item21; l_Kenitems[22] := v_item22; l_Kenitems[23] := v_item23; l_Kenitems[24] := v_item24; l_Kenitems[25] := v_item25;
				l_Kenitems[26] := v_item26; l_Kenitems[27] := v_item27; l_Kenitems[28] := v_item28; l_Kenitems[29] := v_item29; l_Kenitems[30] := v_item30;
				l_Kenitems[31] := v_item31; l_Kenitems[32] := v_item32; l_Kenitems[33] := v_item33; l_Kenitems[34] := v_item34; l_Kenitems[35] := v_item35;
				l_Kenitems[36] := v_item36; l_Kenitems[37] := v_item37; l_Kenitems[38] := v_item38; l_Kenitems[39] := v_item39; l_Kenitems[40] := v_item40;
				l_Kenitems[41] := v_item41; l_Kenitems[42] := v_item42; l_Kenitems[43] := v_item43; l_Kenitems[44] := v_item44; l_Kenitems[45] := v_item45;
				l_Kenitems[46] := v_item46; l_Kenitems[47] := v_item47; l_Kenitems[48] := v_item48; l_Kenitems[49] := v_item49; l_Kenitems[50] := v_item50;
				l_Kenitems[51] := v_item51; l_Kenitems[52] := v_item52; l_Kenitems[53] := v_item53; l_Kenitems[54] := v_item54; l_Kenitems[55] := v_item55;
				l_Kenitems[56] := v_item56; l_Kenitems[57] := v_item57; l_Kenitems[58] := v_item58; l_Kenitems[59] := v_item59; l_Kenitems[60] := v_item60;
				l_Kenitems[61] := v_item61; l_Kenitems[62] := v_item62; l_Kenitems[63] := v_item63; l_Kenitems[64] := v_item64; l_Kenitems[65] := v_item65;
				l_Kenitems[66] := v_item66; l_Kenitems[67] := v_item67; l_Kenitems[68] := v_item68; l_Kenitems[69] := v_item69; l_Kenitems[70] := v_item70;
				l_Kenitems[71] := v_item71; l_Kenitems[72] := v_item72; l_Kenitems[73] := v_item73; l_Kenitems[74] := v_item74; l_Kenitems[75] := v_item75;
				l_Kenitems[76] := v_item76; l_Kenitems[77] := v_item77; l_Kenitems[78] := v_item78; l_Kenitems[79] := v_item79; l_Kenitems[80] := v_item80;
				l_Kenitems[81] := v_item81; l_Kenitems[82] := v_item82; l_Kenitems[83] := v_item83; l_Kenitems[84] := v_item84; l_Kenitems[85] := v_item85;
				l_Kenitems[86] := v_item86; l_Kenitems[87] := v_item87; l_Kenitems[88] := v_item88; l_Kenitems[89] := v_item89; l_Kenitems[90] := v_item90;
				l_Kenitems[91] := v_item91; l_Kenitems[92] := v_item92; l_Kenitems[93] := v_item93; l_Kenitems[94] := v_item94; l_Kenitems[95] := v_item95;
				l_Kenitems[96] := v_item96; l_Kenitems[97] := v_item97; l_Kenitems[98] := v_item98; l_Kenitems[99] := v_item99; l_Kenitems[100] := v_item100;
				FOR i IN 1..100 LOOP
					IF l_Kenitems[i] = '0' THEN
						IF ((gZenMgrCd IS NOT NULL AND gZenMgrCd::text <> '') AND (gZenKaiGo IS NOT NULL AND gZenKaiGo::text <> '') AND (gZenKenShuCd IS NOT NULL AND gZenKenShuCd::text <> ''))
						AND ((gZenMgrCd <> gMgrCd) OR (gZenKaiGo <> gKaiGo) OR (gZenKenShuCd <> gKenShuCd)) THEN
							gSeqNo := gSeqNo + 1;
									-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gZenMgrCd;	-- 銘柄コード
		v_item.l_inItem002 := gZenKaiGo;	-- 回号コード
		v_item.l_inItem003 := gZenKaiGoNm1;	-- 回号正式名称１
		v_item.l_inItem004 := gZenKaiGoNm2;	-- 回号正式名称２
		v_item.l_inItem005 := gZenKenShuCd;	-- 券種コード
		v_item.l_inItem006 := gZenKenShu;	-- 券種
		v_item.l_inItem007 := '';	-- 記番号
		v_item.l_inItem008 := '';	-- 利渡期
		v_item.l_inItem009 := gTitle1;	-- タイトル
		v_item.l_inItem010 := gCnt1;	-- 利札異動事由_利渡期01件数
		v_item.l_inItem011 := gCnt2;	-- 利札異動事由_利渡期02件数
		v_item.l_inItem012 := gCnt3;	-- 利札異動事由_利渡期03件数
		v_item.l_inItem013 := gCnt4;	-- 利札異動事由_利渡期04件数
		v_item.l_inItem014 := gCnt5;	-- 利札異動事由_利渡期05件数
		v_item.l_inItem015 := gCnt6;	-- 利札異動事由_利渡期06件数
		v_item.l_inItem016 := gCnt7;	-- 利札異動事由_利渡期07件数
		v_item.l_inItem017 := gCnt8;	-- 利札異動事由_利渡期08件数
		v_item.l_inItem018 := gCnt9;	-- 利札異動事由_利渡期09件数
		v_item.l_inItem019 := gCnt10;	-- 利札異動事由_利渡期10件数
		v_item.l_inItem020 := gCnt11;	-- 利札異動事由_利渡期11件数
		v_item.l_inItem021 := gCnt12;	-- 利札異動事由_利渡期12件数
		v_item.l_inItem022 := gCnt13;	-- 利札異動事由_利渡期13件数
		v_item.l_inItem023 := gCnt14;	-- 利札異動事由_利渡期14件数
		v_item.l_inItem024 := gCnt15;	-- 利札異動事由_利渡期15件数
		v_item.l_inItem025 := gCnt16;	-- 利札異動事由_利渡期16件数
		v_item.l_inItem026 := gCnt17;	-- 利札異動事由_利渡期17件数
		v_item.l_inItem027 := gCnt18;	-- 利札異動事由_利渡期18件数
		v_item.l_inItem028 := gCnt19;	-- 利札異動事由_利渡期19件数
		v_item.l_inItem029 := gCnt20;	-- 利札異動事由_利渡期20件数
		v_item.l_inItem030 := gCnt21;	-- 利札異動事由_利渡期21件数
		v_item.l_inItem031 := gCnt22;	-- 利札異動事由_利渡期22件数
		v_item.l_inItem032 := gCnt23;	-- 利札異動事由_利渡期23件数
		v_item.l_inItem033 := gCnt24;	-- 利札異動事由_利渡期24件数
		v_item.l_inItem034 := gCnt25;	-- 利札異動事由_利渡期25件数
		v_item.l_inItem035 := gCnt26;	-- 利札異動事由_利渡期26件数
		v_item.l_inItem036 := gCnt27;	-- 利札異動事由_利渡期27件数
		v_item.l_inItem037 := gCnt28;	-- 利札異動事由_利渡期28件数
		v_item.l_inItem038 := gCnt29;	-- 利札異動事由_利渡期29件数
		v_item.l_inItem039 := gCnt30;	-- 利札異動事由_利渡期30件数
		v_item.l_inItem040 := gCnt31;	-- 利札異動事由_利渡期31件数
		v_item.l_inItem041 := gCnt32;	-- 利札異動事由_利渡期32件数
		v_item.l_inItem042 := gCnt33;	-- 利札異動事由_利渡期33件数
		v_item.l_inItem043 := gCnt34;	-- 利札異動事由_利渡期34件数
		v_item.l_inItem044 := gCnt35;	-- 利札異動事由_利渡期35件数
		v_item.l_inItem045 := gCnt36;	-- 利札異動事由_利渡期36件数
		v_item.l_inItem046 := gCnt37;	-- 利札異動事由_利渡期37件数
		v_item.l_inItem047 := gCnt38;	-- 利札異動事由_利渡期38件数
		v_item.l_inItem048 := gCnt39;	-- 利札異動事由_利渡期39件数
		v_item.l_inItem049 := gCnt40;	-- 利札異動事由_利渡期40件数
		v_item.l_inItem050 := gCnt41;	-- 利札異動事由_利渡期41件数
		
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
						--タイトルの設定
						IF cnt = 1 THEN
							IF gKenCnt > 0 THEN
								gTitle1 := '現物債未払利札一覧表（時効分）（控）';
							ELSE
								gTitle1 := '現物債未払利札一覧表（控）';
							END IF;
						ELSE
							IF gKenCnt > 0 THEN
								gTitle1 := '現物債未払利札一覧表（時効分）';
							ELSE
								gTitle1 := '現物債未払利札一覧表';
							END IF;
						END IF;
						gSoKensu := gSoKensu + 1;
						gSeqNo := gSeqNo + 1;
								-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gMgrCd;	-- 銘柄コード
		v_item.l_inItem002 := gKaiGo;	-- 回号コード
		v_item.l_inItem003 := gKaiGoNm1;	-- 回号正式名称１
		v_item.l_inItem004 := gKaiGoNm2;	-- 回号正式名称２
		v_item.l_inItem005 := gKenShuCd;	-- 券種コード
		v_item.l_inItem006 := gKenShu;	-- 券種
		v_item.l_inItem007 := gKiBanGO;	-- 記番号
		v_item.l_inItem008 := i;	-- 利渡期
		v_item.l_inItem009 := gTitle1;	-- タイトル
		
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
						IF ((gZenMgrCd IS NOT NULL AND gZenMgrCd::text <> '') AND (gZenKaiGo IS NOT NULL AND gZenKaiGo::text <> '') AND (gZenKenShuCd IS NOT NULL AND gZenKenShuCd::text <> ''))
						AND ((gZenMgrCd <> gMgrCd) OR (gZenKaiGo <> gKaiGo) OR (gZenKenShuCd <> gKenShuCd)) THEN
							-- Clear counter variables
							gCnt1:=0; gCnt2:=0; gCnt3:=0; gCnt4:=0; gCnt5:=0; gCnt6:=0; gCnt7:=0; gCnt8:=0; gCnt9:=0; gCnt10:=0;
							gCnt11:=0; gCnt12:=0; gCnt13:=0; gCnt14:=0; gCnt15:=0; gCnt16:=0; gCnt17:=0; gCnt18:=0; gCnt19:=0; gCnt20:=0;
							gCnt21:=0; gCnt22:=0; gCnt23:=0; gCnt24:=0; gCnt25:=0; gCnt26:=0; gCnt27:=0; gCnt28:=0; gCnt29:=0; gCnt30:=0;
							gCnt31:=0; gCnt32:=0; gCnt33:=0; gCnt34:=0; gCnt35:=0; gCnt36:=0; gCnt37:=0; gCnt38:=0; gCnt39:=0; gCnt40:=0; gCnt41:=0;
						END IF;
						IF 1 = i THEN
							gCnt1 := gCnt1 + 1;
						ELSIF 2 = i THEN
							gCnt2 := gCnt2 + 1;
						ELSIF 3 = i THEN
							gCnt3 := gCnt3 + 1;
						ELSIF 4 = i THEN
							gCnt4 := gCnt4 + 1;
						ELSIF 5 = i THEN
							gCnt5 := gCnt5 + 1;
						ELSIF 6 = i THEN
							gCnt6 := gCnt6 + 1;
						ELSIF 7 = i THEN
							gCnt7 := gCnt7 + 1;
						ELSIF 8 = i THEN
							gCnt8 := gCnt8 + 1;
						ELSIF 9 = i THEN
							gCnt9 := gCnt9 + 1;
						ELSIF 10 = i THEN
							gCnt10 := gCnt10 + 1;
						ELSIF 11 = i THEN
							gCnt11 := gCnt11 + 1;
						ELSIF 12 = i THEN
							gCnt12 := gCnt12 + 1;
						ELSIF 13 = i THEN
							gCnt13 := gCnt13 + 1;
						ELSIF 14 = i THEN
							gCnt14 := gCnt14 + 1;
						ELSIF 15 = i THEN
							gCnt15 := gCnt15 + 1;
						ELSIF 16 = i THEN
							gCnt16 := gCnt16 + 1;
						ELSIF 17 = i THEN
							gCnt17 := gCnt17 + 1;
						ELSIF 18 = i THEN
							gCnt18 := gCnt18 + 1;
						ELSIF 19 = i THEN
							gCnt19 := gCnt19 + 1;
						ELSIF 20 = i THEN
							gCnt20 := gCnt20 + 1;
						ELSIF 21 = i THEN
							gCnt21 := gCnt21 + 1;
						ELSIF 22 = i THEN
							gCnt22 := gCnt22 + 1;
						ELSIF 23 = i THEN
							gCnt23 := gCnt23 + 1;
						ELSIF 24 = i THEN
							gCnt24 := gCnt24 + 1;
						ELSIF 25 = i THEN
							gCnt25 := gCnt25 + 1;
						ELSIF 26 = i THEN
							gCnt26 := gCnt26 + 1;
						ELSIF 27 = i THEN
							gCnt27 := gCnt27 + 1;
						ELSIF 28 = i THEN
							gCnt28 := gCnt28 + 1;
						ELSIF 29 = i THEN
							gCnt29 := gCnt29 + 1;
						ELSIF 30 = i THEN
							gCnt30 := gCnt30 + 1;
						ELSIF 31 = i THEN
							gCnt31 := gCnt31 + 1;
						ELSIF 32 = i THEN
							gCnt32 := gCnt32 + 1;
						ELSIF 33 = i THEN
							gCnt33 := gCnt33 + 1;
						ELSIF 34 = i THEN
							gCnt34 := gCnt34 + 1;
						ELSIF 35 = i THEN
							gCnt35 := gCnt35 + 1;
						ELSIF 36 = i THEN
							gCnt36 := gCnt36 + 1;
						ELSIF 37 = i THEN
							gCnt37 := gCnt37 + 1;
						ELSIF 38 = i THEN
							gCnt38 := gCnt38 + 1;
						ELSIF 39 = i THEN
							gCnt39 := gCnt39 + 1;
						ELSIF 40 = i THEN
							gCnt40 := gCnt40 + 1;
						ELSIF 41 = i THEN
							gCnt41:= gCnt41 + 1;
						END IF;
						gZenMgrCd := gMgrCd;
						gZenKaiGo := gKaiGo;
						gZenKaiGoNm1 := gKaiGoNm1;
						gZenKaiGoNm2 := gKaiGoNm2;
						gZenKenShuCd := gKenShuCd;
						gZenKenShu := gKenShu;
						gZenKiBanGO := gKiBanGO;
					END IF;
				END LOOP;
			END LOOP;
		END;
		IF gSoKensu = 0 THEN
			IF cnt = 1 THEN
				gSeqNo := gSeqNo + 1;
						-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := '';	-- 銘柄コード
		v_item.l_inItem002 := '';	-- 回号コード
		v_item.l_inItem003 := '対象データなし';	-- 回号正式名称１
		v_item.l_inItem004 := '';	-- 回号正式名称２
		v_item.l_inItem005 := '';	-- 券種コード
		v_item.l_inItem006 := '';	-- 券種
		v_item.l_inItem007 := '';	-- 記番号
		v_item.l_inItem008 := '';	-- 利渡期
		v_item.l_inItem009 := gTitle2;	-- タイトル
		
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
		v_item.l_inItem005 := gZenKenShuCd;	-- 券種コード
		v_item.l_inItem006 := gZenKenShu;	-- 券種
		v_item.l_inItem007 := '';	-- 記番号
		v_item.l_inItem008 := '';	-- 利渡期
		v_item.l_inItem009 := gTitle1;	-- タイトル
		v_item.l_inItem010 := gCnt1;	-- 利札異動事由_利渡期01件数
		v_item.l_inItem011 := gCnt2;	-- 利札異動事由_利渡期02件数
		v_item.l_inItem012 := gCnt3;	-- 利札異動事由_利渡期03件数
		v_item.l_inItem013 := gCnt4;	-- 利札異動事由_利渡期04件数
		v_item.l_inItem014 := gCnt5;	-- 利札異動事由_利渡期05件数
		v_item.l_inItem015 := gCnt6;	-- 利札異動事由_利渡期06件数
		v_item.l_inItem016 := gCnt7;	-- 利札異動事由_利渡期07件数
		v_item.l_inItem017 := gCnt8;	-- 利札異動事由_利渡期08件数
		v_item.l_inItem018 := gCnt9;	-- 利札異動事由_利渡期09件数
		v_item.l_inItem019 := gCnt10;	-- 利札異動事由_利渡期10件数
		v_item.l_inItem020 := gCnt11;	-- 利札異動事由_利渡期11件数
		v_item.l_inItem021 := gCnt12;	-- 利札異動事由_利渡期12件数
		v_item.l_inItem022 := gCnt13;	-- 利札異動事由_利渡期13件数
		v_item.l_inItem023 := gCnt14;	-- 利札異動事由_利渡期14件数
		v_item.l_inItem024 := gCnt15;	-- 利札異動事由_利渡期15件数
		v_item.l_inItem025 := gCnt16;	-- 利札異動事由_利渡期16件数
		v_item.l_inItem026 := gCnt17;	-- 利札異動事由_利渡期17件数
		v_item.l_inItem027 := gCnt18;	-- 利札異動事由_利渡期18件数
		v_item.l_inItem028 := gCnt19;	-- 利札異動事由_利渡期19件数
		v_item.l_inItem029 := gCnt20;	-- 利札異動事由_利渡期20件数
		v_item.l_inItem030 := gCnt21;	-- 利札異動事由_利渡期21件数
		v_item.l_inItem031 := gCnt22;	-- 利札異動事由_利渡期22件数
		v_item.l_inItem032 := gCnt23;	-- 利札異動事由_利渡期23件数
		v_item.l_inItem033 := gCnt24;	-- 利札異動事由_利渡期24件数
		v_item.l_inItem034 := gCnt25;	-- 利札異動事由_利渡期25件数
		v_item.l_inItem035 := gCnt26;	-- 利札異動事由_利渡期26件数
		v_item.l_inItem036 := gCnt27;	-- 利札異動事由_利渡期27件数
		v_item.l_inItem037 := gCnt28;	-- 利札異動事由_利渡期28件数
		v_item.l_inItem038 := gCnt29;	-- 利札異動事由_利渡期29件数
		v_item.l_inItem039 := gCnt30;	-- 利札異動事由_利渡期30件数
		v_item.l_inItem040 := gCnt31;	-- 利札異動事由_利渡期31件数
		v_item.l_inItem041 := gCnt32;	-- 利札異動事由_利渡期32件数
		v_item.l_inItem042 := gCnt33;	-- 利札異動事由_利渡期33件数
		v_item.l_inItem043 := gCnt34;	-- 利札異動事由_利渡期34件数
		v_item.l_inItem044 := gCnt35;	-- 利札異動事由_利渡期35件数
		v_item.l_inItem045 := gCnt36;	-- 利札異動事由_利渡期36件数
		v_item.l_inItem046 := gCnt37;	-- 利札異動事由_利渡期37件数
		v_item.l_inItem047 := gCnt38;	-- 利札異動事由_利渡期38件数
		v_item.l_inItem048 := gCnt39;	-- 利札異動事由_利渡期39件数
		v_item.l_inItem049 := gCnt40;	-- 利札異動事由_利渡期40件数
		v_item.l_inItem050 := gCnt41;	-- 利札異動事由_利渡期41件数
		
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
		l_outSqlCode := pkconstant.fatal();
		l_outSqlErrM := SQLERRM;
		CALL pkLog.debug(l_inUserId, REPORT_ID, '×' || PROGRAM_ID || ' END（例外発生）');
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipi002k14r02 ( l_inItakuKaishaCd text, l_inUserId text, l_inChohyoKbn text, l_inGyomuYmd text, l_inTorihikiYmd text, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;





-- Nested procedure removed - inlined into main procedure