


DROP TYPE IF EXISTS spip02902_type_key;
CREATE TYPE spip02902_type_key AS (
		gShrYmd   char(8),  -- 決済日(支払日)
		gTsukaCd  char(3),       -- 通貨
		gDvpKbnNm varchar(40),         -- ＤＶＰ区分
		gSknKessaiKaishaCd char(7),	-- 資金決済会社コード
		gKessaiNo char(16) -- 決済番号
		);


CREATE OR REPLACE PROCEDURE spip02902 ( l_inKessaiYmdF TEXT,     -- 決済日(FROM)
 l_inKessaiYmdT TEXT,     -- 決済日(TO)
 l_inItakuKaishaCd TEXT,     -- 委託会社コード
 l_inUserId TEXT,     -- ユーザーID
 l_inChohyoKbn TEXT,     -- 帳票区分
 l_inGyomuYmd TEXT,     -- 業務日付
 l_outSqlCode OUT integer,  -- リターン値
 l_outSqlErrM OUT text -- エラーコメント
 ) AS $body$
DECLARE

  --
--  /* 著作権:Copyright(c)2004
--  /* 会社名:JIP
--  /*
--  /* 概要　:資金決済関連帳票出力指示画面の入力条件により、資金決済会社別支払予定表を作成する
--  /*      また、元利払日の前営業日の夜間バッチを作成する
--  /*
--  /*　　　　※【修正時の注意点】
--  /*        以下の帳票はパッケージ資金決済会社別支払予定表と同等の帳票のため、コピーし作成している。
--  /*        ・事務代行横串帳票 資金決済会社別支払予定表(SPIPJ207K00R02)
--  /*        ・カスタマイズ帳票 資金決済会社別支払予定表(SPIP9086K05R02)
--  /*　　　　この２帳票と同期をとる必要があるので注意！！
--  /*
--  /* 引数　:l_inKessaiYmdF    IN  TEXT     決済日(FROM)
--  /* 　　　 l_inKessaiYmdT    IN  TEXT     決済日(TO)
--  /* 　　　 l_inItakuKaishaCd IN  TEXT     委託会社コード
--  /* 　　　 l_inUserId        IN  TEXT     ユーザーID
--  /* 　　　 l_inChohyoKbn     IN  TEXT     帳票区分
--  /* 　　　 l_inGyomuYmd      IN  TEXT     業務日付
--  /* 　　　 l_outSqlCode      OUT INTEGER  リターン値
--  /* 　　　 l_outSqlErrM      OUT VARCHAR エラーコメント
--  /*
--  /* 返り値:なし
--  /*
--  /* @author JIP
--  /* @version $Id: SPIP02902.SQL,v 1.37 2017/05/25 08:30:53 fujii Exp $
--  /*
--  ***************************************************************************
--  /* ログ　:
--  /* 　　　日付  開発者名    目的
--  /* -------------------------------------------------------------------
--  /*　2005.05.25 JIP 川田愛   決済日FROMとTOが入力されていなくても
--  /*          帳票が出力されるように訂正
--  /*
--  /*  2005.05.31  久保　由紀子
--  /*             カーソル'curMeisai'のMBANK,MBANK_SHITENを外部結合に変更
--  /*
--  /*  2005.06.14  秋山 純一
--  /*             決済日FROMとTOのどちらかが入力されていなくても、
--  /*             決済日の最大・最小で検索されるように修正。
--  /*
--  /*  2005.06.16  秋山 純一
--  /*             ・通貨フォーマットを円・外貨の２つに統一。
--  /*             ・「相手側資金決済会社略称」のサイズがVARCHAR2(30)になっていたので、
--  /*             　VARCHAR(60)に修正
--  /*             ・金額フォーマットが小さかったので、MAX24桁に修正。
--  /*             ・決済日ごとに合計が計算されていなかったので、ロジックを追加。
--  /*
--  /*  2005.06.29  藤江
--  /*              コードマスタ、通貨マスタを外部結合に変更
--  /*              MBANK,MBANK_SHITEN のFINANCIAL_SECURITIES_KBNに(+)が抜けていたので付加
--  /*
--  /*  2005.07.21  秋山 純一
--  /*             ・ＤＶＰ毎、日付・通貨コード毎に
--  /*             　合計件数と合計金額を計算するロジックを追加
--  /*
--  /*  2006.05.22  緒方 広道
--  /*             ・機構非関与データ対応
--  /*
--  /*  2006.07.21  ASK
--  /*             ・機構加入者コード、名追加
--
--  ***************************************************************************
--  
	--==============================================================================
	--          デバッグ機能                         
	--==============================================================================
	DEBUG numeric(1) := 0;
	--==============================================================================
	--          定数定義                          
	--==============================================================================
	RTN_OK     CONSTANT integer := 0;                           -- 正常
	RTN_NG     CONSTANT integer := 1;                           -- 予期したエラー
	RTN_NODATA CONSTANT integer := 2;                           -- データなし
	RTN_FATAL  CONSTANT integer := 99;                          -- 予期せぬエラー
	REPORT_ID CONSTANT char(11) := 'IP030002921';               -- 帳票ID
	FMT_KNGK_J CONSTANT char(21) := 'Z,ZZZ,ZZZ,ZZZ,ZZZ,ZZ9';    -- 円貨フォーマット
	FMT_KNGK_F CONSTANT char(24) := 'Z,ZZZ,ZZZ,ZZZ,ZZZ,ZZ9.99'; -- 外貨フォーマット
	--==============================================================================
	--          変数定義                          
	--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd              integer := RTN_OK;      -- リターンコード
	gCnt                integer := 0;           -- カウンター
	gDvpGokeiRecCount   integer := 0;           -- ＤＶＰ区分毎　件数
	gDvpGokeiKessaiKngk numeric  := 0;           -- ＤＶＰ区分毎　決済金額
	gGokeiRecCount      integer := 0;           -- 合計　件数
	gGokeiKessaiKngk    numeric  := 0;           -- 合計　決済金額
	gKessaiJigen SOWN_INFO.GANRI_KESSAI_JIGEN%TYPE;  -- 決済時限
	gKessaiNoWk KIKIN_SEIKYU.KESSAI_NO%TYPE := ' ';	 -- 決済番号(ブレイク時に使用)
	-- 決済日がNULLの時の処理用変数
	gKessaiYmdF varchar(8) := NULL;            -- 決済日(始点)
	gKessaiYmdT varchar(8) := NULL;            -- 決済日(終点)
	-- 書式フォーマット
	gFmtKngk varchar(24) := NULL;              -- 金額
	gItakuKaishaRnm VJIKO_ITAKU.BANK_RNM%TYPE;       -- 委託会社略称
	gJikoDaikoKbn   VJIKO_ITAKU.JIKO_DAIKO_KBN%TYPE; -- 自行代行区分
	-- キー
	key spIp02902_TYPE_KEY;                                    -- キー
	--==============================================================================
	--          カーソル定義                                                            
	--==============================================================================
	curMeisai CURSOR FOR
		SELECT
			trim(both MAX(K01.SHR_YMD)) AS SHR_YMD,                                         -- 支払日
			MAX((
					SELECT
						CODE_NM
					FROM SCODE
					WHERE CODE_SHUBETSU = '501'
					AND CODE_VALUE = K01.DVP_KBN
				)) AS DVP_KBN_NM,                                                           -- ＤＶＰ区分名称
			MAX((
					SELECT
						trim(both TSUKA_NM)
					FROM MTSUKA
					WHERE TSUKA_CD = K01.TSUKA_CD
				)) AS TSUKA_NM,                                                             -- 通貨コード名称
			MAX(K01.AITE_SKN_KESSAI_BCD || K01.AITE_SKN_KESSAI_SCD) AS SKN_KESSAI_CD,  -- 資金決済会社コード
			CASE WHEN 				MAX((						SELECT							COUNT(M10.SKN_KESSAI_CD)						FROM MBANK_SHITEN_ZOKUSEI M10						WHERE M10.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD						AND SUBSTR(M10.SKN_KESSAI_CD,1,4) = K01.AITE_SKN_KESSAI_BCD						AND SUBSTR(M10.SKN_KESSAI_CD,5,3) = K01.AITE_SKN_KESSAI_SCD 					))				=1 THEN 				MAX((						SELECT							MAX(M02.BANK_RNM || M03.SHITEN_RNM)						FROM							MBANK M02,							MBANK_SHITEN M03,							MBANK_SHITEN_ZOKUSEI M10						WHERE MG1.ITAKU_KAISHA_CD = M10.ITAKU_KAISHA_CD						AND SUBSTR(M10.SKN_KESSAI_CD,1,4) = K01.AITE_SKN_KESSAI_BCD						AND SUBSTR(M10.SKN_KESSAI_CD,5,3) = K01.AITE_SKN_KESSAI_SCD						AND M10.BANK_CD = M03.BANK_CD						AND M10.SHITEN_CD = M03.SHITEN_CD						AND M10.FINANCIAL_SECURITIES_KBN = M03.FINANCIAL_SECURITIES_KBN						AND M03.BANK_CD = M02.BANK_CD						AND M03.FINANCIAL_SECURITIES_KBN = M02.FINANCIAL_SECURITIES_KBN 					))				  ELSE NULL END  AS SKN_KESSAI_RNM,                                                       -- 相手側資金決済会社略称
			K01.KESSAI_NO,                                                             -- 決済番号
			SUM(K01.GZEIHIKI_AFT_CHOKYU_KNGK)
				+ SUM(K01.SHOKAN_SEIKYU_KNGK) AS KESSAI_KNGK,                          -- 決済金額
			MAX((
					SELECT
						CODE_NM
					FROM SCODE
					WHERE CODE_SHUBETSU = '511'
					AND CODE_VALUE = K01.KOBETSU_SHONIN_SAIYO_FLG
				)) AS KOBETSU_SAIYO_FLG_NM,                                                 -- 個別承認採用フラグ名称
			CASE WHEN 				MAX(K01.KOBETSU_SHONIN_SAIYO_FLG)='Y' THEN 				MAX(MG1.ISIN_CD)  ELSE ' ' END  AS ISIN_CD,                                                              -- ＩＳＩＮコード
			CASE WHEN 				MAX(K01.KOBETSU_SHONIN_SAIYO_FLG)='Y' THEN 				MAX(MG1.MGR_CD)  ELSE ' ' END  AS MGR_CD,                                                               -- 銘柄コード
			CASE WHEN 				MAX(K01.KOBETSU_SHONIN_SAIYO_FLG)='Y' THEN 				MAX(MG1.MGR_RNM)  ELSE ' ' END  AS MGR_RNM,                                                              -- 銘柄略称
			trim(both MAX(VJ1.GANRI_KESSAI_JIGEN)) AS GANRI_KESSAI_JIGEN,                   -- 元利払用決済時限
			trim(both MAX(K01.KOBETSU_SHONIN_SAIYO_FLG)) AS KOBETSU_SHONIN_SAIYO_FLG,       -- 個別承認採用フラグ
			trim(both MAX(K01.DVP_KBN)) AS DVP_KBN,                                         -- ＤＶＰ区分
			trim(both MAX(K01.TSUKA_CD)) AS TSUKA_CD,                                       -- 通貨コード
			trim(both K01.FINANCIAL_SECURITIES_KBN || K01.BANK_CD || KOZA_KBN) AS KANYU_CD, -- 機構加入者コード
			M02.BANK_RNM AS KANYU_RNM,                                                 -- 機構加入者略称
			MAX(VJ1.BANK_RNM) AS BANK_RNM,                                             -- 銀行略称
			trim(both MAX(VJ1.JIKO_DAIKO_KBN)) AS JIKO_DAIKO_KBN                             -- 自行代行区分
		FROM vjiko_itaku vj1, mgr_kihon mg1, mgr_sts mg0, kikin_seikyu k01
LEFT OUTER JOIN mbank m02 ON (K01.FINANCIAL_SECURITIES_KBN = M02.FINANCIAL_SECURITIES_KBN AND K01.BANK_CD = M02.BANK_CD)
WHERE K01.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD AND K01.MGR_CD = MG0.MGR_CD AND K01.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND MG0.MGR_STAT_KBN = '1' AND MG0.MASSHO_FLG = '0' AND MG0.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD AND MG0.MGR_CD = MG1.MGR_CD AND K01.SHR_YMD BETWEEN gKessaiYmdF AND gKessaiYmdT AND VJ1.KAIIN_ID = l_inItakuKaishaCd AND (K01.KK_KANYO_UMU_FLG = '1'												-- 機構関与銘柄は無条件で対象
				OR (K01.KK_KANYO_UMU_FLG != '1' AND K01.SHORI_KBN = '1')) 					-- 機構非関与銘柄(0, 2)は、承認済であること
   GROUP BY
		K01.KESSAI_NO,
		K01.SHR_YMD,
		K01.TSUKA_CD,
		K01.DVP_KBN,
		K01.AITE_SKN_KESSAI_BCD,
		K01.AITE_SKN_KESSAI_SCD,
		K01.FINANCIAL_SECURITIES_KBN,
		K01.BANK_CD,
		KOZA_KBN,
		M02.BANK_RNM
	ORDER BY
		SHR_YMD,
		TSUKA_CD,
		DVP_KBN,
		SKN_KESSAI_CD,
		K01.KESSAI_NO,
		K01.FINANCIAL_SECURITIES_KBN,
		K01.BANK_CD,
		KOZA_KBN,
		M02.BANK_RNM;
	curTokusyu CURSOR FOR
		SELECT
			SEQ_NO,
			ITEM002, -- 支払日
			ITEM003, -- ＤＶＰ区分名称
			ITEM004, -- 通貨コード名称
			ITEM005, -- 資金決済会社コード
			ITEM007, -- 決済番号
			ITEM008  -- 決済金額
		FROM SREPORT_WK
		WHERE
			KEY_CD = l_inItakuKaishaCd
			AND USER_ID = l_inUserId
			AND CHOHYO_KBN = l_inChohyoKbn
			AND SAKUSEI_YMD = l_inGyomuYmd
			AND CHOHYO_ID = REPORT_ID
			AND HEADER_FLG = 1
		ORDER BY
			SEQ_NO DESC;
	--==============================================================================
	--  メイン処理 
	--==============================================================================
BEGIN
	IF DEBUG = 1
	THEN
		CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp02902 START');
	END IF;
	-- 入力パラメータのチェック
	-- 決済日(始点)が入力されなかった際の処理
	IF coalesce(l_inKessaiYmdF::text, '') = ''
	THEN
		SELECT MIN(K01.SHR_YMD) INTO STRICT gKessaiYmdF FROM KIKIN_SEIKYU K01;
	ELSE
		gKessaiYmdF := l_inKessaiYmdF;
	END IF;
	-- 決済日(終点)が入力されなかった際の処理
	IF coalesce(l_inKessaiYmdT::text, '') = ''
	THEN
		SELECT MAX(K01.SHR_YMD) INTO STRICT gKessaiYmdT FROM KIKIN_SEIKYU K01;
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
	WHERE
		KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = l_inGyomuYmd
		AND CHOHYO_ID = REPORT_ID;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	-- データ取得
	FOR recMeisai IN curMeisai
	LOOP
		-- 前回の支払日と同じ場合
		IF key.gShrYmd = recMeisai.SHR_YMD
		THEN
			-- 前回の通貨コードと同じ場合
			IF key.gTsukaCd = recMeisai.TSUKA_CD
			THEN
				IF Key.gKessaiNo <> recMeisai.KESSAI_NO
				OR Key.gSknKessaiKaishaCd <> recMeisai.SKN_KESSAI_CD
				THEN
					-- 総件数をカウント
					gGokeiRecCount   := gGokeiRecCount + 1;
				END IF;
				-- 総合計金額をカウント
				gGokeiKessaiKngk := gGokeiKessaiKngk + recMeisai.KESSAI_KNGK;
				-- 前回のＤＶＰ区分と同じ場合
				IF Key.gDvpKbnNm = recMeisai.DVP_KBN_NM
				THEN
					-- 決済番号または資金決済会社コードが同じでない時
					IF Key.gKessaiNo <> recMeisai.KESSAI_NO
					OR Key.gSknKessaiKaishaCd <> recMeisai.SKN_KESSAI_CD
					THEN
						-- ＤＶＰ毎の件数をカウント
						gDvpGokeiRecCount := gDvpGokeiRecCount + 1;
					END IF;
					-- ＤＶＰ毎の合計金額をカウント
					gDvpGokeiKessaiKngk := gDvpGokeiKessaiKngk + recMeisai.KESSAI_KNGK;
				ELSE
					-- ＤＶＰ毎の件数とＤＶＰ毎の合計金額を初期化
					gDvpGokeiRecCount   := 0;
					Key.gKessaiNo := ' ';
					gDvpGokeiKessaiKngk := recMeisai.KESSAI_KNGK;
				END IF;
			ELSE
				-- ＤＶＰと総合計を初期化
				gDvpGokeiRecCount   := 0;
				Key.gKessaiNo := ' ';
				gDvpGokeiKessaiKngk := recMeisai.KESSAI_KNGK;
				gGokeiRecCount      := 0;
				gGokeiKessaiKngk    := recMeisai.KESSAI_KNGK;
			END IF;
		ELSE
			-- -- ＤＶＰsと総合計を初期化
			gDvpGokeiRecCount   := 0;
			Key.gKessaiNo := ' ';
			gDvpGokeiKessaiKngk := recMeisai.KESSAI_KNGK;
			gGokeiRecCount      := 0;
			gGokeiKessaiKngk    := recMeisai.KESSAI_KNGK;
		END IF;
		-- キーの退避
		key.gShrYmd   := recMeisai.SHR_YMD;
		Key.gTsukaCd  := recMeisai.TSUKA_CD;
		Key.gDvpKbnNm := recMeisai.DVP_KBN_NM;
		Key.gKessaiNo := recMeisai.KESSAI_NO;
		Key.gSknKessaiKaishaCd := recMeisai.SKN_KESSAI_CD;
		-- 決済時限の設定
		IF recMeisai.DVP_KBN = '1'
		THEN
			gKessaiJigen := recMeisai.GANRI_KESSAI_JIGEN;
		ELSE
			gKessaiJigen := NULL;
		END IF;
		-- シーケンスのカウント
		gCnt := gCnt + 1;
		-- 書式フォーマットの設定
		IF Key.gTsukaCd = 'JPY'
		THEN
			gFmtKngk := FMT_KNGK_J;
		ELSE
			gFmtKngk := FMT_KNGK_F;
		END IF;
		-- 委託会社略称
		gItakuKaishaRnm := NULL;
		IF recMeisai.JIKO_DAIKO_KBN = '2'
		THEN
			gItakuKaishaRnm := recMeisai.BANK_RNM;
		END IF;
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := recMeisai.SHR_YMD;	-- 支払日
		v_item.l_inItem003 := recMeisai.DVP_KBN_NM;	-- ＤＶＰ区分名称
		v_item.l_inItem004 := recMeisai.TSUKA_CD;	-- 通貨コード
		v_item.l_inItem005 := recMeisai.SKN_KESSAI_CD;	-- 資金決済会社コード
		v_item.l_inItem006 := recMeisai.SKN_KESSAI_RNM;	-- 相手側資金決済会社略称
		v_item.l_inItem007 := recMeisai.KESSAI_NO;	-- 決済番号
		v_item.l_inItem008 := recMeisai.KESSAI_KNGK;	-- 決済金額
		v_item.l_inItem009 := recMeisai.KOBETSU_SAIYO_FLG_NM;	-- 個別承認採用フラグ名称
		v_item.l_inItem010 := recMeisai.ISIN_CD;	-- ＩＳＩＮコード
		v_item.l_inItem011 := recMeisai.MGR_CD;	-- 銘柄コード
		v_item.l_inItem012 := recMeisai.MGR_RNM;	-- 銘柄略称
		v_item.l_inItem013 := gKessaiJigen;	-- 決済時限
		v_item.l_inItem014 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem015 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem016 := gFmtKngk;	-- 発行金額書式フォーマット
		v_item.l_inItem020 := gDvpGokeiRecCount + 1;	-- ＤＶＰ区分毎　件数
		v_item.l_inItem021 := gDvpGokeiKessaiKngk;	-- ＤＶＰ区分毎　決済金額
		v_item.l_inItem022 := gGokeiRecCount + 1;	-- 合計　件数
		v_item.l_inItem023 := gGokeiKessaiKngk;	-- 合計　決済金額
		v_item.l_inItem024 := l_inGyomuYmd;	-- 作成年月日
		v_item.l_inItem025 := recMeisai.KANYU_CD;	-- 機構加入者コード
		v_item.l_inItem026 := recMeisai.KANYU_RNM;	-- 機構加入者略称
		v_item.l_inItem027 := recMeisai.TSUKA_NM;	-- 通貨名称
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gCnt,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	END LOOP;
	IF gCnt = 0
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
			WHERE VJ01.KAIIN_ID = l_inItakuKaishaCd;
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
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem014 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem015 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem016 := FMT_KNGK_J;	-- 円貨フォーマット
		v_item.l_inItem019 := '対象データなし';
		v_item.l_inItem024 := l_inGyomuYmd;	-- 作成年月日
		
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
	ELSE
		-- 特殊処理（同一決済番号のものは１件目に表示し金額は、合計する）============
		-- 変数初期化
		key.gShrYmd   := ' ';
		Key.gTsukaCd  := ' ';
		Key.gDvpKbnNm := ' ';
		Key.gKessaiNo := ' ';
		Key.gSknKessaiKaishaCd := ' ';
		gGokeiKessaiKngk := 0;
		gCnt := 0;
		-- データ取得
		FOR recTokusyu IN curTokusyu
		LOOP
			-- 決済番号がスペースで入ってきた場合、TRIMをかけるとNULLになってしまうため、
			-- ' 'に置き換えてブレイク時の比較を行う。IP-04869,IP-04885対応
			IF coalesce(trim(both recTokusyu.ITEM007)::text, '') = '' THEN
				gKessaiNoWk := ' ';
			ELSE
				gKessaiNoWk := trim(both recTokusyu.ITEM007);
			END IF;
			IF gCnt = 0 THEN
				-- 更新開始番号
				gCnt := recTokusyu.SEQ_NO;
			ELSE				
				-- ブレイク時
				IF trim(both key.gShrYmd) <> trim(both recTokusyu.ITEM002)
				OR trim(both Key.gDvpKbnNm) <> trim(both recTokusyu.ITEM003)
				OR trim(both Key.gTsukaCd) <> trim(both recTokusyu.ITEM004)
				OR trim(both Key.gSknKessaiKaishaCd) <> trim(both recTokusyu.ITEM005)
				OR Key.gKessaiNo <> gKessaiNoWk THEN
					-- トップデータ更新（合計金額）
					UPDATE SREPORT_WK SET
						ITEM008 = gGokeiKessaiKngk::text
					WHERE
						KEY_CD = l_inItakuKaishaCd
						AND USER_ID = l_inUserId
						AND CHOHYO_KBN = l_inChohyoKbn
						AND SAKUSEI_YMD = l_inGyomuYmd
						AND CHOHYO_ID = REPORT_ID
						AND HEADER_FLG = 1
						AND SEQ_NO = (recTokusyu.SEQ_NO + 1);
					-- その他データ更新（空白）
					UPDATE SREPORT_WK SET
						ITEM005 = '',
						ITEM006 = '',
						ITEM007 = '',
						ITEM008 = '',
						ITEM009 = '',
						ITEM010 = '',
						ITEM011 = '',
						ITEM012 = '',
						ITEM013 = ''
					WHERE
						KEY_CD = l_inItakuKaishaCd
						AND USER_ID = l_inUserId
						AND CHOHYO_KBN = l_inChohyoKbn
						AND SAKUSEI_YMD = l_inGyomuYmd
						AND CHOHYO_ID = REPORT_ID
						AND HEADER_FLG = 1
						AND SEQ_NO BETWEEN(recTokusyu.SEQ_NO + 2)
						AND gCnt;
					-- 更新開始番号
					gCnt := recTokusyu.SEQ_NO;
					-- 合計金額クリア
					gGokeiKessaiKngk := 0;
				END IF;
			END IF;
			-- キーの退避
			key.gShrYmd   := recTokusyu.ITEM002;
			Key.gDvpKbnNm := recTokusyu.ITEM003;
			Key.gTsukaCd  := recTokusyu.ITEM004;
			Key.gSknKessaiKaishaCd := recTokusyu.ITEM005;
			Key.gKessaiNo := gKessaiNoWk;
			-- 合計足し込み
			gGokeiKessaiKngk := gGokeiKessaiKngk + (recTokusyu.ITEM008)::numeric;
		END LOOP;
		-- トップデータ更新（合計金額）
		UPDATE SREPORT_WK SET
			ITEM008 = gGokeiKessaiKngk::text
		WHERE
			KEY_CD = l_inItakuKaishaCd
			AND USER_ID = l_inUserId
			AND CHOHYO_KBN = l_inChohyoKbn
			AND SAKUSEI_YMD = l_inGyomuYmd
			AND CHOHYO_ID = REPORT_ID
			AND HEADER_FLG = 1
			AND SEQ_NO = 1;
		-- その他データ更新（空白）
		UPDATE SREPORT_WK SET
			ITEM005 = '',
			ITEM006 = '',
			ITEM007 = '',
			ITEM008 = '',
			ITEM009 = '',
			ITEM010 = '',
			ITEM011 = '',
			ITEM012 = '',
			ITEM013 = ''
		WHERE
			KEY_CD = l_inItakuKaishaCd
			AND USER_ID = l_inUserId
			AND CHOHYO_KBN = l_inChohyoKbn
			AND SAKUSEI_YMD = l_inGyomuYmd
			AND CHOHYO_ID = REPORT_ID
			AND HEADER_FLG = 1
			AND SEQ_NO BETWEEN 2
			AND gCnt;
		-- ==========================================================================
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
		CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp02902 END');
	END IF;
	-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLERRM:' || SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip02902 ( l_inKessaiYmdF TEXT, l_inKessaiYmdT TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT integer, l_outSqlErrM OUT text ) FROM PUBLIC;