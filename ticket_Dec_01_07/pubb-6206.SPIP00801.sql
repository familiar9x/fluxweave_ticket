




CREATE OR REPLACE PROCEDURE spip00801 ( l_inKessaiYmdF TEXT, -- 決済日(From)
 l_inKessaiYmdT TEXT, -- 決済日(To)
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
--  /* 概要　:資金決済関連帳票出力指示画面またはバッチ起動の入力条件により、
--  /* 　　　 新規記録資金入金予定表（銘柄別）を作成する。
--  /*
--  /* 引数　:l_inKessaiYmdF IN  TEXT    決済日(From)
--  /* 　　　 l_inKessaiYmdT IN  TEXT    決済日(To)
--  /* 　　　 l_inItakuKaishaCd  IN  TEXT    委託会社コード
--  /* 　　　 l_inUserId   IN  TEXT    ユーザーID
--  /* 　　　 l_inChohyoKbn    IN  TEXT    帳票区分
--  /* 　　　 l_inGyomuYmd   IN  TEXT    業務日付
--  /* 　　　 l_outSqlCode   OUT INTEGER   リターン値
--  /* 　　　 l_outSqlErrM   OUT VARCHAR  エラーコメント
--  /*
--  /* 返り値:なし
--  /* @version $Id: SPIP00801.SQL,v 1.17 2006/12/13 07:10:11 iwakami Exp $
--  /*
--  ***************************************************************************
--  /* ログ　:
--  /* 　　　日付  開発者名    目的
--  /* -------------------------------------------------------------------
--  /*　2005.05.25 JIP 川田愛   決済日FROMとTOが入力されていなくても
--  /*             帳票が出力されるように訂正
--  /*
--  /*  2005.06.03 秋山 純一
--  /*             作成日、件数、合計件数がなかったので、追加。
--  /*             件数を表示するために、前のレコードと比較する必要があったので
--  /*             退避用のISINコードを追加。
--  /*
--  /*  2005.06.14 秋山 純一
--  /*             決済日FROMとTOのどちらかが入力されていなくても、
--  /*             決済日の最大・最小で検索されるように修正。
--  /*
--  /*  2005.06.28 藤江
--  /*             IP-01454対応
--  /*             資金決済方法取得時、参照するコード種別を516から
--  /*       743:資金決済方法コード（共通）に変更。
--  /*             金融機関マスタ、コードマスタ、通貨マスタを内部結合から外部結合に変更。
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
	REPORT_ID CONSTANT char(11) := 'IP030000811'; -- 帳票ID
	-- 書式フォーマット
	FMT_HAKKO_KNGK_J  CONSTANT char(21) := 'Z,ZZZ,ZZZ,ZZZ,ZZZ,ZZ9'; -- 発行金額
	FMT_RBR_KNGK_J    CONSTANT char(21) := 'Z,ZZZ,ZZZ,ZZZ,ZZZ,ZZ9'; -- 利払金額
	FMT_SHOKAN_KNGK_J CONSTANT char(21) := 'Z,ZZZ,ZZZ,ZZZ,ZZZ,ZZ9'; -- 償還金額
	-- 書式フォーマット（外資）
	FMT_HAKKO_KNGK_F  CONSTANT char(24) := 'Z,ZZZ,ZZZ,ZZZ,ZZZ,ZZ9.99'; -- 発行金額
	FMT_RBR_KNGK_F    CONSTANT char(24) := 'Z,ZZZ,ZZZ,ZZZ,ZZZ,ZZ9.99'; -- 利払金額
	FMT_SHOKAN_KNGK_F CONSTANT char(24) := 'Z,ZZZ,ZZZ,ZZZ,ZZZ,ZZ9.99'; -- 償還金額
	--==============================================================================
	--          変数定義                          
	--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd       integer := RTN_OK; -- リターンコード
	gSeqNo       integer := 0; -- シーケンス
	gKensu       integer := 0; -- 件数
	gGoukeiKensu integer := 0; -- 合計件数
	beforeKessaiYmd    varchar(8) := NULL; -- 退避用決済日
	beforeHakkoTsukaCd varchar(8) := NULL; -- 退避用発行通貨コード
	beforeIsinCd       varchar(12) := NULL; -- 退避用ISINコード
	-- 決済日がNULLの時の処理用変数
	gKessaiYmdF varchar(8) := NULL; -- 決済日(始点)
	gKessaiYmdT varchar(8) := NULL; -- 決済日(終点)
	-- 書式フォーマット
	gFmtHakkoKngk  varchar(24) := NULL; -- 発行金額
	gFmtRbrKngk    varchar(24) := NULL; -- 利払金額
	gFmtShokanKngk varchar(24) := NULL; -- 償還金額
	gItakuKaishaRnm VJIKO_ITAKU.BANK_RNM%TYPE; -- 委託会社略称
  gJikoDaikoKbn   VJIKO_ITAKU.JIKO_DAIKO_KBN%TYPE;    -- 自行代行区分
	--==============================================================================
	--          カーソル定義                          
	--==============================================================================
	curMeisai CURSOR FOR
		SELECT B03.KESSAI_YMD, -- 決済日
					 M64.TSUKA_NM AS HAKKO_TSUKA_NM, -- 発行通貨名称
					 MG1.ISIN_CD, -- ＩＳＩＮコード
					 MG1.HAKKO_TSUKA_CD, -- 発行通貨コード
					 MG1.RBR_TSUKA_CD, -- 利払通貨コード
					 MG1.SHOKAN_TSUKA_CD, -- 償還通貨コード
					 B03.MGR_CD, -- 銘柄コード
					 MG1.MGR_RNM, -- 銘柄略称
					 B03.AITE_KKMEMBER_FS_KBN || B03.AITE_KKMEMBER_BCD ||
					 B03.AITE_KKMEMBER_KKBN AS KKMEMBER_CD, -- 機構加入者コード
					 M021.BANK_RNM AS KKMEMBER_RNM, -- 相手方機構加入者略称
					 B03.SKN_KESSAI_CD AS SKN_KESSAI_KAISHA_CD, -- 資金決済会社コード
					 CASE WHEN(SELECT COUNT(M10.SKN_KESSAI_CD) FROM MBANK_SHITEN_ZOKUSEI M10                        WHERE M10.ITAKU_KAISHA_CD = B03.ITAKU_KAISHA_CD                        AND   M10.SKN_KESSAI_CD = B03.SKN_KESSAI_CD)=1 THEN (SELECT M02.BANK_RNM || M03.SHITEN_RNM                        FROM   MBANK M02,MBANK_SHITEN M03,MBANK_SHITEN_ZOKUSEI M10                        WHERE  B03.ITAKU_KAISHA_CD = M10.ITAKU_KAISHA_CD                        AND    B03.SKN_KESSAI_CD = M10.SKN_KESSAI_CD                        AND    M10.BANK_CD = M03.BANK_CD                        AND    M10.SHITEN_CD = M03.SHITEN_CD                        AND    M10.FINANCIAL_SECURITIES_KBN = M03.FINANCIAL_SECURITIES_KBN                        AND    M03.BANK_CD = M02.BANK_CD                        AND    M03.FINANCIAL_SECURITIES_KBN = M02.FINANCIAL_SECURITIES_KBN)                              ELSE NULL END  AS SKN_KESSAI_KAISHA_RNM, -- 相手側資金決済会社略称
					 B03.KESSAI_NO, -- 決済番号
					 B03.KESSAI_KNGK, -- 決済金額
					 B03.HKUK_KNGK, -- 引受金額
					 MCD1.CODE_NM AS DVP_KBN_NM, -- ＤＶＰ区分名称
					 MCD2.CODE_NM AS SKN_KESSAI_METHOD_NM, -- 資金決済方法名称
					 MCD3.CODE_NM AS DAIRI_MOTION_FLG_NM, -- 代理人直接申請フラグ名称
					 VJ1.BANK_RNM, -- 銀行略称
					 VJ1.JIKO_DAIKO_KBN  -- 自行代行区分
		FROM vjiko_itaku vj1, mgr_sts mg0, nyukin_yotei b03
LEFT OUTER JOIN mbank m021 ON (B03.AITE_KKMEMBER_FS_KBN = M021.FINANCIAL_SECURITIES_KBN AND B03.AITE_KKMEMBER_BCD = M021.BANK_CD)
LEFT OUTER JOIN scode mcd1 ON (B03.DVP_KBN = MCD1.CODE_VALUE AND '501' = MCD1.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd2 ON (B03.SKN_KESSAI_METHOD_CD = MCD2.CODE_VALUE AND '743' = MCD2.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd3 ON (B03.DAIRI_MOTION_FLG = MCD3.CODE_VALUE AND '133' = MCD3.CODE_SHUBETSU)
, mgr_kihon mg1
LEFT OUTER JOIN mtsuka m64 ON (MG1.HAKKO_TSUKA_CD = M64.TSUKA_CD)
WHERE B03.KESSAI_YMD BETWEEN gKessaiYmdF AND gKessaiYmdT AND B03.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND B03.MGR_CD = MG1.MGR_CD AND B03.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD    AND VJ1.KAIIN_ID = l_inItakuKaishaCd       AND MG0.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD AND MG0.MGR_CD = MG1.MGR_CD AND MG0.MGR_STAT_KBN = '1' AND MG0.MASSHO_FLG = '0'
		ORDER  BY B03.KESSAI_YMD,
							MG1.HAKKO_TSUKA_CD,
							MG1.ISIN_CD,
							KKMEMBER_CD,
							SKN_KESSAI_KAISHA_CD,
							B03.KESSAI_NO;
	--==============================================================================
	--  メイン処理 
	--==============================================================================
BEGIN
	IF DEBUG = 1
	THEN
		CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp00801 START');
	END IF;
	-- 入力パラメータのチェック
	-- 決済日(始点)が入力されなかった際の処理
	IF coalesce(l_inKessaiYmdF::text, '') = ''
	THEN
		SELECT trim(both MIN(B03.KESSAI_YMD)) INTO STRICT gKessaiYmdF FROM NYUKIN_YOTEI B03;
	ELSE
		gKessaiYmdF := l_inKessaiYmdF;
	END IF;
	-- 決済日(終点)が入力されなかった際の処理
	IF coalesce(l_inKessaiYmdT::text, '') = ''
	THEN
		SELECT trim(both MAX(B03.KESSAI_YMD)) INTO STRICT gKessaiYmdT FROM NYUKIN_YOTEI B03;
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
	FOR recMeisai IN curMeisai
	LOOP
		-- シーケンスのカウント
		gSeqNo := gSeqNo + 1;
		-- 件数のカウント
		IF beforeIsinCd = recMeisai.ISIN_CD
		THEN
			gKensu := gKensu + 1;
		ELSE
			gKensu := 0;
		END IF;
		-- 前のISINコードの退避
		beforeIsinCd := recMeisai.ISIN_CD;
		-- 合計件数のカウント
		IF beforeKessaiYmd = recMeisai.KESSAI_YMD
		THEN
			IF beforeHakkoTsukaCd = recMeisai.HAKKO_TSUKA_CD
			THEN
				gGoukeiKensu := gGoukeiKensu + 1;
			ELSE
				gGoukeiKensu := 0;
			END IF;
		ELSE
			gGoukeiKensu := 0;
		END IF;
		-- 前の決済日の退避
		beforeKessaiYmd    := recMeisai.KESSAI_YMD;
		beforeHakkoTsukaCd := recMeisai.HAKKO_TSUKA_CD;
		-- 書式フォーマットの設定
		-- 発行
		IF recMeisai.HAKKO_TSUKA_CD = 'JPY'
		THEN
			gFmtHakkoKngk := FMT_HAKKO_KNGK_J;
		ELSE
			gFmtHakkoKngk := FMT_HAKKO_KNGK_F;
		END IF;
		-- 利払
		IF recMeisai.RBR_TSUKA_CD = 'JPY'
		THEN
			gFmtRbrKngk := FMT_RBR_KNGK_J;
		ELSE
			gFmtRbrKngk := FMT_RBR_KNGK_F;
		END IF;
		-- 償還
		IF recMeisai.SHOKAN_TSUKA_CD = 'JPY'
		THEN
			gFmtShokanKngk := FMT_SHOKAN_KNGK_J;
		ELSE
			gFmtShokanKngk := FMT_SHOKAN_KNGK_F;
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
		v_item.l_inItem002 := recMeisai.KESSAI_YMD;	-- 決済日
		v_item.l_inItem003 := recMeisai.HAKKO_TSUKA_NM;	-- 発行通貨名称
		v_item.l_inItem004 := recMeisai.ISIN_CD;	-- ＩＳＩＮコード
		v_item.l_inItem005 := recMeisai.MGR_CD;	-- 銘柄コード
		v_item.l_inItem006 := recMeisai.MGR_RNM;	-- 銘柄略称
		v_item.l_inItem007 := recMeisai.KKMEMBER_CD;	-- 機構加入者コード
		v_item.l_inItem008 := recMeisai.KKMEMBER_RNM;	-- 相手方機構加入者略称
		v_item.l_inItem009 := recMeisai.SKN_KESSAI_KAISHA_CD;	-- 資金決済会社コード
		v_item.l_inItem010 := recMeisai.SKN_KESSAI_KAISHA_RNM;	-- 相手側資金決済会社略称
		v_item.l_inItem011 := recMeisai.KESSAI_NO;	-- 決済番号
		v_item.l_inItem012 := recMeisai.KESSAI_KNGK;	-- 決済金額
		v_item.l_inItem013 := recMeisai.HKUK_KNGK;	-- 引受金額
		v_item.l_inItem014 := recMeisai.DAIRI_MOTION_FLG_NM;	-- 代理人直接申請フラグ名称
		v_item.l_inItem015 := recMeisai.DVP_KBN_NM;	-- ＤＶＰ区分名称
		v_item.l_inItem016 := recMeisai.SKN_KESSAI_METHOD_NM;	-- 資金決済方法名称
		v_item.l_inItem017 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem018 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem019 := gFmtHakkoKngk;	-- 発行金額書式フォーマット
		v_item.l_inItem020 := gFmtRbrKngk;	-- 利払金額書式フォーマット
		v_item.l_inItem021 := gFmtShokanKngk;	-- 償還金額書式フォーマット
		v_item.l_inItem023 := l_inGyomuYmd;	-- 作成年月日
		v_item.l_inItem024 := gKensu + 1;	-- 件数
		v_item.l_inItem025 := gGoukeiKensu + 1;	-- 合計件数
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	END LOOP;
	IF gSeqNo = 0
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
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem017 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem018 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem019 := FMT_HAKKO_KNGK_J;	-- 発行金額書式フォーマット
		v_item.l_inItem020 := FMT_RBR_KNGK_J;	-- 利払金額書式フォーマット
		v_item.l_inItem021 := FMT_SHOKAN_KNGK_J;	-- 償還金額書式フォーマット
		v_item.l_inItem022 := '対象データなし';	-- メッセージ
		v_item.l_inItem023 := l_inGyomuYmd;	-- 作成年月日
		
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
		CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:' || gSeqNo);
	END IF;
	IF DEBUG = 1
	THEN
		CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp00801 END');
	END IF;
	-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLERRM:' || SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
		--    RAISE;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip00801 ( l_inKessaiYmdF TEXT, l_inKessaiYmdT TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT integer, l_outSqlErrM OUT text ) FROM PUBLIC;