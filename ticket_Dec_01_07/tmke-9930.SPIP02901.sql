


DROP TYPE IF EXISTS spip02901_type_record;
CREATE TYPE spip02901_type_record AS (
		gShrYmd   char(8), -- 支払日
		gGanriBri varchar(40), -- 元利払方式
		gDvpKbnNm varchar(40), -- DVP区分名称
		gTsukaCd  char(3), -- 通貨コード
		gTsukaNm                 char(3), -- 利金通貨名称
		gSknKessaiCd             char(7), -- 資金決済会社コード
		gSknKessaiRnm            varchar(60), -- 相手側資金決済会社略称
		gKessaiNo                char(16), -- 決済番号
		gKkmemberCd              char(7), -- 機構加入者
		gKkmemberNm              varchar(50), -- 機構加入者名
		gTaxKbn              	 char(2), -- 税区分
		gIsinCd                  char(12), -- ISINコード
		gMgrCd                   varchar(13), -- 銘柄コード
		gMgrRnm                  varchar(44), -- 銘柄略称
		gShokanSeikyuKngk        decimal(16,2), -- 償還額
		gGzeihikiBefChokyuKngk   decimal(14,2), -- 税引前利金額
		gGzeihikiAftChokyuKngk   decimal(14,2), -- 税引後利金額
		gShiharaigkGokei         decimal(21,2), -- 支払額合計
		gKobetsuSaiyoFlgNm       varchar(40), -- 個別承認採用フラグ名称
		gBankRnm                 varchar(60), -- 銀行略称
		gJikoDaikoKbn            char(1), -- 自行代行区分
		gDvpGokeiShokanKngk      numeric(16), -- 償還額   ＤＶＰ区分毎
		gDvpGokeiGzeihikiBefKngk numeric(14), -- 税引前利金額  ＤＶＰ区分毎
		gDvpGokeiGzeihikiAftKngk numeric(14), -- 税引後利金額  ＤＶＰ区分毎
		gDvpGokeiShiharaigk      numeric(16), -- 支払額合計 ＤＶＰ区分毎
		gKkGokeiShokanKngk       numeric(16), -- 償還額   機構関与非関与毎
		gKkGokeiGzeihikiBefKngk  numeric(14), -- 税引前利金額 機構関与非関与毎
		gKkGokeiGzeihikiAftKngk  numeric(14), -- 税引後利金額 機構関与非関与毎
		gKkGokeiShiharaigk       numeric(16), -- 支払額合計 機構関与非関与毎
		gGokeiShokanKngk         numeric(16), -- 償還額   合計
		gGokeiGzeihikiBefKngk    numeric(14), -- 税引前利金額  合計
		gGokeiGzeihikiAftKngk    numeric(14), -- 税引後利金額  合計
		gGokeiShiharaigk         numeric(16) -- 支払額合計 合計
		);


CREATE OR REPLACE PROCEDURE spip02901 ( l_inKessaiYmdF TEXT, -- 決済日(FROM)
 l_inKessaiYmdT TEXT, -- 決済日(TO)
 l_inItakuKaishaCd TEXT, -- 委託会社コード
 l_inUserId TEXT, -- ユーザーID
 l_inChohyoKbn TEXT, -- 帳票区分
 l_inGyomuYmd TEXT, -- 業務日付
 l_outSqlCode OUT integer, -- リターン値
 l_outSqlErrM OUT text -- エラーコメント
 ) AS $body$
DECLARE

	--
--  /* 著作権:Copyright(c)2004
--  /* 会社名:JIP
--  /*
--  /* 概要　:資金決済関連帳票出力指示画面の入力条件により、機構関与有無別資金支払予定表を作成する
--  /*
--  /* 引数　:l_inKessaiYmdF IN  TEXT    決済日(FROM)
--  /* 　　　 l_inKessaiYmdT IN  TEXT    決済日(TO)
--  /* 　　　 l_inItakuKaishaCd  IN  TEXT    委託会社コード
--  /* 　　　 l_inUserId   IN  TEXT    ユーザーID
--  /* 　　　 l_inChohyoKbn    IN  TEXT    帳票区分
--  /* 　　　 l_inGyomuYmd   IN  TEXT    業務日付
--  /* 　　　 l_outSqlCode   OUT INTEGER   リターン値
--  /* 　　　 l_outSqlErrM   OUT VARCHAR  エラーコメント
--  /*
--  /* 返り値:なし
--  /*
--  /* @author JIP
--  /* @version $Id: SPIP02901.SQL,v 1.26 2007/08/21 04:59:57 kuwabara Exp $
--  /*
--  ***************************************************************************
--  /* ログ　:
--  /* 　　　日付  開発者名    目的
--  /* -------------------------------------------------------------------
--  /*　2005.05.25 JIP 川田愛
--  /*             決済日FROMとTOが入力されていなくても帳票が出力されるように訂正。
--  /*             対象データが存在しなくても帳票が出力されるように訂正。
--  /*
--  /*  2005.06.02  秋山　純一
--  /*             ・通貨フォーマットを１つに統一。
--  /*             ・「相手側資金決済会社略称」のサイズがVARCHAR2(30)になっていたので、
--  /*               VARCHAR(60)に修正。
--  /*
--  /*  2005.06.14 秋山 純一
--  /*             決済日FROMとTOのどちらかが入力されていなくても、
--  /*             決済日の最大・最小で検索されるように修正。
--  /*
--  /*  2005.06.17 秋山 純一
--  /*             ・金額フォーマットが小さかったので、MAX24桁に修正。
--  /*             ・決済日ごとに合計が計算されていなかったので、ロジックを追加。
--  /*
--  /*  2005.06.29  藤江
--  /*			コードマスタ、通貨マスタを外部結合に変更
--  /*			MBANK,MBANK_SHITEN のFINANCIAL_SECURITIES_KBNに(+)が抜けていたので付加
--  /*
--  ***************************************************************************
--  
	--==============================================================================
	--          デバッグ機能                         
	--==============================================================================
	DEBUG numeric(1) := 0;
	--==============================================================================
	--          定数定義                          
	--==============================================================================
	RTN_OK     CONSTANT integer := 0; -- 正常
	RTN_NG     CONSTANT integer := 1; -- 予期したエラー
	RTN_NODATA CONSTANT integer := 2; -- データなし
	RTN_FATAL  CONSTANT integer := 99; -- 予期せぬエラー
	REPORT_ID CONSTANT char(11) := 'IP030002911'; -- 帳票ID
	-- 書式フォーマット
	FMT_KNGK_J CONSTANT char(21) := 'Z,ZZZ,ZZZ,ZZZ,ZZZ,ZZ9'; -- 発行金額
	-- 書式フォーマット（外資）
	FMT_KNGK_F CONSTANT char(24) := 'Z,ZZZ,ZZZ,ZZZ,ZZZ,ZZ9.99'; -- 発行金額
	--==============================================================================
	--          変数定義                          
	--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd integer := RTN_OK; -- リターンコード
	gCnt   integer := - 1; -- カウンター
	-- 決済日がNULLの時の処理用変数
	gKessaiYmdF varchar(8) := NULL; -- 決済日(始点)
	gKessaiYmdT varchar(8) := NULL; -- 決済日(終点)
	-- 書式フォーマット
	gFmtKngk varchar(24) := NULL; -- 発行金額
	gItakuKaishaRnm VJIKO_ITAKU.BANK_RNM%TYPE;          -- 委託会社略称
    gJikoDaikoKbn   VJIKO_ITAKU.JIKO_DAIKO_KBN%TYPE;    -- 自行代行区分
	recMeisai spip02901_type_record[]; -- レコード (array)
	--==============================================================================
	--          カーソル定義                          
	--==============================================================================
	curMeisai CURSOR FOR
		SELECT	K01.SHR_YMD, -- 支払日
				CASE WHEN K01.KK_KANYO_UMU_FLG='2' THEN  REPLACE(MCD3.CODE_NM, '方式', NULL)  ELSE MCD3.CODE_NM END  AS GANRI_BRI, -- 元利払方式
				MCD1.CODE_NM AS DVP_KBN_NM, -- DVP区分名称
				K01.TSUKA_CD,
				(SELECT M64.TSUKA_NM FROM MTSUKA M64 WHERE M64.TSUKA_CD = K01.TSUKA_CD) AS TSUKA_NM,	-- 通貨名称
					 K01.AITE_SKN_KESSAI_BCD || K01.AITE_SKN_KESSAI_SCD AS SKN_KESSAI_CD, -- 資金決済会社コード
					 CASE WHEN(SELECT COUNT(M10.SKN_KESSAI_CD) FROM MBANK_SHITEN_ZOKUSEI M10                        WHERE M10.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD                        AND   SUBSTR(M10.SKN_KESSAI_CD,1,4) = K01.AITE_SKN_KESSAI_BCD                        AND   SUBSTR(M10.SKN_KESSAI_CD,5,3) = K01.AITE_SKN_KESSAI_SCD )=1 THEN (SELECT M02.BANK_RNM || M03.SHITEN_RNM                        FROM   MBANK M02,MBANK_SHITEN M03,MBANK_SHITEN_ZOKUSEI M10                        WHERE  MG1.ITAKU_KAISHA_CD = M10.ITAKU_KAISHA_CD                        AND   SUBSTR(M10.SKN_KESSAI_CD,1,4) = K01.AITE_SKN_KESSAI_BCD                        AND   SUBSTR(M10.SKN_KESSAI_CD,5,3) = K01.AITE_SKN_KESSAI_SCD                        AND    M10.BANK_CD = M03.BANK_CD                        AND    M10.SHITEN_CD = M03.SHITEN_CD                        AND    M10.FINANCIAL_SECURITIES_KBN = M03.FINANCIAL_SECURITIES_KBN                        AND    M03.BANK_CD = M02.BANK_CD                        AND    M03.FINANCIAL_SECURITIES_KBN = M02.FINANCIAL_SECURITIES_KBN )                              ELSE NULL END  AS SKN_KESSAI_RNM, -- 相手側資金決済会社略称
				K01.KESSAI_NO, -- 決済番号
				K01.FINANCIAL_SECURITIES_KBN||K01.BANK_CD||K01.KOZA_KBN AS KK_MEMBER_CD,		-- 機構加入者
				(
				select substr(M02.BANK_RNM, 1, 20) from MBANK M02 where
				M02.FINANCIAL_SECURITIES_KBN = K01.FINANCIAL_SECURITIES_KBN
				AND M02.BANK_CD = K01.BANK_CD
				) AS KK_MEMBER_NM, 															-- 機構加入者名
				K01.TAX_KBN,													-- 税区分
				MG1.ISIN_CD, -- ISINコード
				MG1.MGR_CD, -- 銘柄コード
				substr(MG1.MGR_RNM, 1, 38) AS MGR_RNM, -- 銘柄略称
				K01.SHOKAN_SEIKYU_KNGK, -- 償還額
				K01.GZEIHIKI_BEF_CHOKYU_KNGK, -- 税引前利金額
				K01.GZEIHIKI_AFT_CHOKYU_KNGK, -- 税引後利金額
				K01.SHOKAN_SEIKYU_KNGK + K01.GZEIHIKI_AFT_CHOKYU_KNGK AS SHIHARAIGK_GOKEI, -- 支払額合計
				MCD2.CODE_NM AS KOBETSU_SAIYO_FLG_NM, -- 個別承認採用フラグ名称
				VJ1.BANK_RNM, -- 銀行略称
				VJ1.JIKO_DAIKO_KBN, -- 自行代行区分
				CASE WHEN K01.KK_KANYO_UMU_FLG='0' THEN '1' WHEN K01.KK_KANYO_UMU_FLG='1' THEN '0'  ELSE K01.KK_KANYO_UMU_FLG END  KK_FLG_CODE_SORT
		FROM vjiko_itaku vj1, mgr_kihon mg1, mgr_sts mg0, kikin_seikyu k01
LEFT OUTER JOIN scode mcd1 ON (K01.DVP_KBN = MCD1.CODE_VALUE AND '501' = MCD1.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd2 ON (K01.KOBETSU_SHONIN_SAIYO_FLG = MCD2.CODE_VALUE AND '511' = MCD2.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd3 ON (K01.KK_KANYO_UMU_FLG = MCD3.CODE_VALUE AND '505' = MCD3.CODE_SHUBETSU)
WHERE K01.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD AND K01.MGR_CD = MG0.MGR_CD AND K01.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND MG0.MGR_STAT_KBN = '1' AND MG0.MASSHO_FLG = '0' AND MG0.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD AND MG0.MGR_CD = MG1.MGR_CD AND K01.SHR_YMD BETWEEN trim(both gKessaiYmdF) AND trim(both gKessaiYmdT) AND (K01.KK_KANYO_UMU_FLG = '1'												-- 機構関与銘柄は無条件で対象
				OR (K01.KK_KANYO_UMU_FLG != '1' AND K01.SHORI_KBN = '1')) AND  				-- 機構非関与銘柄(0, 2)は、承認済であること
 K01.ITAKU_KAISHA_CD = VJ1.KAIIN_ID       ORDER BY
				K01.SHR_YMD,
				TSUKA_CD,
				KK_FLG_CODE_SORT,
				DVP_KBN_NM,
				SKN_KESSAI_CD,
				K01.KESSAI_NO,
				KK_MEMBER_CD,
				TAX_KBN,
				ISIN_CD;
	--==============================================================================
	--  メイン処理 
	--==============================================================================
BEGIN
	IF DEBUG = 1
	THEN
		CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp02901 START');
	END IF;
	-- 入力パラメータのチェック
	-- 決済日(始点)が入力されなかった際の処理
	IF coalesce(l_inKessaiYmdF::text, '') = ''
	THEN
		SELECT trim(both MIN(K01.SHR_YMD)) INTO STRICT gKessaiYmdF FROM KIKIN_SEIKYU K01;
	ELSE
		gKessaiYmdF := l_inKessaiYmdF;
	END IF;
	-- 決済日(終点)が入力されなかった際の処理
	IF coalesce(l_inKessaiYmdT::text, '') = ''
	THEN
		SELECT trim(both MAX(K01.SHR_YMD)) INTO STRICT gKessaiYmdT FROM KIKIN_SEIKYU K01;
	ELSE
		gKessaiYmdT := l_inKessaiYmdT;
	END IF;
	-- その他の入力パラメータのチェック
	IF coalesce(l_inItakuKaishaCd::text, '') = '' OR
		 coalesce(l_inUserId::text, '') = '' OR
		 coalesce(l_inChohyoKbn::text, '') = '' OR
		 coalesce(l_inGyomuYmd::text, '') = ''
	THEN
		-- パラメータエラー
		IF DEBUG = 1
		THEN
			CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');
		END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error(l_inUserId, REPORT_ID, 'SQLERRM:' || '');
		RETURN;
	END IF;
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE  KEY_CD = l_inItakuKaishaCd AND
				 USER_ID = l_inUserId AND
				 CHOHYO_KBN = l_inChohyoKbn AND
				 SAKUSEI_YMD = l_inGyomuYmd AND
				 CHOHYO_ID = REPORT_ID;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	-- データ取得
	FOR rec IN curMeisai
	LOOP
		gCnt := gCnt + 1;
		recMeisai[gCnt].gShrYmd               := rec.SHR_YMD;        -- 支払日
		recMeisai[gCnt].gGanriBri             := rec.GANRI_BRI;      -- 元利払方式
		recMeisai[gCnt].gDvpKbnNm             := rec.DVP_KBN_NM;     -- DVP区分名称
		recMeisai[gCnt].gTsukaCd              := rec.TSUKA_CD;       -- 発行通貨コード
		recMeisai[gCnt].gTsukaNm              := rec.TSUKA_NM;       -- 利金通貨名称
		recMeisai[gCnt].gSknKessaiCd          := rec.SKN_KESSAI_CD;  -- 資金決済会社コード
		recMeisai[gCnt].gSknKessaiRnm         := rec.SKN_KESSAI_RNM; -- 相手側資金決済会社略称
		recMeisai[gCnt].gKessaiNo             := rec.KESSAI_NO;      -- 決済番号
		recMeisai[gCnt].gKkmemberCd           := rec.KK_MEMBER_CD;   -- 機構加入者コード
		recMeisai[gCnt].gKkmemberNm           := rec.KK_MEMBER_NM;   -- 機構加入者名
		recMeisai[gCnt].gTaxKbn               := rec.TAX_KBN;        -- 税区分
		recMeisai[gCnt].gIsinCd               := rec.ISIN_CD;        -- ISINコード
		recMeisai[gCnt].gMgrCd                := rec.MGR_CD;         -- 銘柄コード
		recMeisai[gCnt].gMgrRnm               := rec.MGR_RNM;        -- 銘柄略称
		recMeisai[gCnt].gShokanSeikyuKngk     := rec.SHOKAN_SEIKYU_KNGK;       -- 償還額
		recMeisai[gCnt].gGzeihikiBefChokyuKngk:= rec.GZEIHIKI_BEF_CHOKYU_KNGK; -- 税引前利金額
		recMeisai[gCnt].gGzeihikiAftChokyuKngk:= rec.GZEIHIKI_AFT_CHOKYU_KNGK; -- 税引後利金額
		recMeisai[gCnt].gShiharaigkGokei      := rec.SHIHARAIGK_GOKEI;     -- 支払額合計
		recMeisai[gCnt].gKobetsuSaiyoFlgNm    := rec.KOBETSU_SAIYO_FLG_NM; -- 個別承認採用フラグ名称
		recMeisai[gCnt].gBankRnm              := rec.BANK_RNM;       -- 銀行略称
		recMeisai[gCnt].gJikoDaikoKbn         := rec.JIKO_DAIKO_KBN; -- 自行代行区分
        
        -- 委託会社のセット
        IF rec.JIKO_DAIKO_KBN = '2' AND coalesce(trim(both gItakuKaishaRnm)::text, '') = '' THEN
            gItakuKaishaRnm := recMeisai[gCnt].gBankRnm;
        END IF;
	END LOOP;
	-- データ登録
	FOR i IN 0 .. coalesce(cardinality(recMeisai), 0) - 1
	LOOP
		-- 通貨フォーマットの設定
		IF recMeisai[i].gTsukaNm = '円'
		THEN
			gFmtKngk := FMT_KNGK_J;
		ELSE
			gFmtKngk := FMT_KNGK_F;
		END IF;
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := l_inGyomuYmd;	-- 作成年月日
		v_item.l_inItem003 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem004 := recMeisai[i].gShrYmd;	-- 支払日
		v_item.l_inItem005 := recMeisai[i].gGanriBri;	-- 元利払方式
		v_item.l_inItem006 := recMeisai[i].gDvpKbnNm;	-- ＤＶＰ区分名称
		v_item.l_inItem007 := recMeisai[i].gTsukaCd;	-- 通貨コード
		v_item.l_inItem008 := recMeisai[i].gSknKessaiCd;	-- 資金決済会社コード
		v_item.l_inItem009 := recMeisai[i].gSknKessaiRnm;	-- 相手側資金決済会社略称
		v_item.l_inItem010 := recMeisai[i].gKessaiNo;	-- 決済番号
		v_item.l_inItem011 := recMeisai[i].gKkmemberCd;	-- 機構加入者コード
		v_item.l_inItem012 := recMeisai[i].gKkmemberNm;	-- 機構加入者名
		v_item.l_inItem013 := recMeisai[i].gTaxKbn;	-- 税区分
		v_item.l_inItem014 := recMeisai[i].gIsinCd;	-- ＩＳＩＮコード
		v_item.l_inItem015 := recMeisai[i].gMgrCd;	-- 銘柄コード
		v_item.l_inItem016 := recMeisai[i].gMgrRnm;	-- 銘柄略称
		v_item.l_inItem017 := recMeisai[i].gShokanSeikyuKngk;	-- 償還金額
		v_item.l_inItem018 := recMeisai[i].gGzeihikiBefChokyuKngk;	-- 税引前利金額
		v_item.l_inItem019 := recMeisai[i].gGzeihikiAftChokyuKngk;	-- 税引後利金額
		v_item.l_inItem020 := recMeisai[i].gShiharaigkGokei;	-- 支払額合計
		v_item.l_inItem021 := recMeisai[i].gKobetsuSaiyoFlgNm;	-- 個別承認採用フラグ名称
		v_item.l_inItem034 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem035 := gFmtKngk;	-- 発行金額書式フォーマット
		v_item.l_inItem037 := recMeisai[i].gTsukaNm;	-- 通貨名称
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> i + 1,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	END LOOP;
	IF gCnt < 0
	THEN
        -- 委託会社略称を取得する。
        BEGIN
            SELECT
                VJ01.BANK_RNM,
                VJ01.JIKO_DAIKO_KBN
            INTO STRICT
                gItakuKaishaRnm,
                gJikoDaikoKbn
            FROM
                VJIKO_ITAKU VJ01
            WHERE
                VJ01.KAIIN_ID = l_inItakuKaishaCd;
        EXCEPTION
            WHEN no_data_found THEN
                gItakuKaishaRnm := NULL;
        END;
        -- 代行でないなら委託会社略称は出力しない。
        IF gJikoDaikoKbn <> '2' THEN
            gItakuKaishaRnm := NULL;
        END IF;
		-- 対象データなし
		gRtnCd := RTN_NODATA;
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;
		v_item.l_inItem002 := l_inGyomuYmd;	-- 作成年月日
		v_item.l_inItem003 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem034 := REPORT_ID;
		v_item.l_inItem035 := FMT_KNGK_J;
		v_item.l_inItem036 := '対象データなし';
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> 1,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1
	THEN
		CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:' || gCnt);
	END IF;
	IF DEBUG = 1
	THEN
		CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp02901 END');
	END IF;
	-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLERRM:' || SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip02901 ( l_inKessaiYmdF TEXT, l_inKessaiYmdT TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT integer, l_outSqlErrM OUT text ) FROM PUBLIC;