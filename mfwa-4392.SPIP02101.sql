




CREATE OR REPLACE PROCEDURE spip02101 ( l_inKijunYmd TEXT,		-- 基準日
 l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inUserId TEXT,		-- ユーザーID
 l_inChohyoKbn TEXT,		-- 帳票区分
 l_inGyomuYmd TEXT,		-- 業務日付
 l_outSqlCode OUT integer,		-- リターン値
 l_outSqlErrM OUT text	-- エラーコメント
 ) AS $body$
DECLARE

--
--/* 著作権:Copyright(c)2004
--/* 会社名:JIP
--/* 概要　:機構から受信する「元利払対象残高ファイル」を受信時に、業務側のバッチ処理（突合処理）が
--/* 　　　 起動され、その結果をもとに、元利払対象残高突合リストを作成する。
--/* 　　　 各種バッチ帳票出力指示画面より印刷する。
--/* 引数　:l_inKijunYmd		IN	TEXT		基準日
--/* 　　　 l_inItakuKaishaCd	IN	TEXT		委託会社コード
--/* 　　　 l_inUserId		IN	TEXT		ユーザーID
--/* 　　　 l_inChohyoKbn		IN	TEXT		帳票区分
--/* 　　　 l_inGyomuYmd		IN	TEXT		業務日付
--/* 　　　 l_outSqlCode		OUT	INTEGER		リターン値
--/* 　　　 l_outSqlErrM		OUT	VARCHAR	エラーコメント
--/* 返り値:なし
--/* @version $Revision: 1.12 $
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.02.10	JIP				新規作成
--/*
--/*
--***************************************************************************
--
--==============================================================================
--					デバッグ機能													
--==============================================================================
	DEBUG	numeric(1)	:= 0;
--==============================================================================
--					定数定義													
--==============================================================================
	RTN_OK				CONSTANT integer	:= 0;						-- 正常
	RTN_NG				CONSTANT integer	:= 1;						-- 予期したエラー
	RTN_NODATA			CONSTANT integer	:= 2;						-- データなし
	RTN_FATAL			CONSTANT integer	:= 99;						-- 予期せぬエラー
	REPORT_ID			CONSTANT char(11)	:= 'IP030002111';			-- 帳票ID
	LIST_SAKUSEI_KBN	CONSTANT char(1)	:= '3';						-- 作成区分(3：随時)
	-- 書式フォーマット
	FMT_HAKKO_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	FMT_RBR_KNGK_J		CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 利払金額
	FMT_SHOKAN_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 償還金額
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd				integer :=	RTN_OK;							-- リターンコード
	gSeqNo				integer := 0;								-- シーケンス
	gItakuKaishaRnm		VJIKO_ITAKU.BANK_RNM%TYPE;						-- 委託会社略称
--==============================================================================
--					カーソル定義													
--==============================================================================
	curMeisai CURSOR FOR
		SELECT 	K06.ISIN_CD,									-- ＩＳＩＮコード
				K06.SYS_GNRBARAI_YMD,							-- システム_元利払日
				CASE WHEN K06.TOTSUGO_KEKKA_KBN='3' THEN  NULL  ELSE K06.SYS_SHASAI_ZNDK END  AS SYS_SHASAI_ZNDK,	   -- システム_社債残高
				CASE WHEN K06.TOTSUGO_KEKKA_KBN='3' THEN  NULL  ELSE M641.TSUKA_NM END  AS SYS_HAKKO_TSUKA_NM,       -- システム_発行通貨名称
				CASE WHEN K06.TOTSUGO_KEKKA_KBN='3' THEN  NULL  ELSE K06.SYS_FACTOR END  AS SYS_FACTOR,     -- システム_ファクター
				CASE WHEN K06.TOTSUGO_KEKKA_KBN='3' THEN  NULL  ELSE K06.SYS_GNR_ZNDK END  AS SYS_GNR_ZNDK, -- システム_元利払対象残高
				CASE WHEN K06.TOTSUGO_KEKKA_KBN='3' THEN  NULL  ELSE K06.SYS_GNR_JISSHITSU_ZNDK END  AS SYS_GNR_JISSHITSU_ZNDK,  -- システム_元利払対象残高（実質）
				CASE WHEN K06.TOTSUGO_KEKKA_KBN='3' THEN  NULL  ELSE K06.SYS_OSAE_ZNDK END  AS SYS_OSAE_ZNDK,      -- システム_差押残高
				K06.KK_SHORI_YMD,          						-- 機構_処理日
				CASE WHEN K06.TOTSUGO_KEKKA_KBN='0' THEN  NULL  ELSE K06.KK_GNRBARAI_YMD END  AS KK_GNRBARAI_YMD,    -- 機構_元利払日
				CASE WHEN K06.TOTSUGO_KEKKA_KBN='0' THEN  NULL  ELSE K06.KK_FACTOR END  AS KK_FACTOR,                -- 機構_ファクター
				CASE WHEN K06.TOTSUGO_KEKKA_KBN='0' THEN  NULL  ELSE K06.KK_GNR_ZNDK END  AS KK_GNR_ZNDK,            -- 機構_元利払対象残高
				CASE WHEN K06.TOTSUGO_KEKKA_KBN='0' THEN  NULL  ELSE K06.KK_GNR_JISSHITSU_ZNDK END  AS KK_GNR_JISSHITSU_ZNDK,    -- 機構_元利払対象残高（実質）
				CASE WHEN K06.TOTSUGO_KEKKA_KBN='0' THEN  NULL  ELSE M642.TSUKA_NM END  AS KK_HAKKO_TSUKA_NM,        -- 機構_発行通貨名称
				K06.TOTSUGO_KEKKA_KBN,							-- 突合結果区分
				MCD1.CODE_NM AS TOTSUGO_KEKKA_NM,				-- 突合結果名称
				VMG1.MGR_RNM,									-- 銘柄略称
				MCD2.CODE_NM AS GNR_ZNDK_NM, 					-- 元利払対象残高区分名称
				VJ1.BANK_RNM,									-- 銀行略称
				VJ1.JIKO_DAIKO_KBN,								-- 自行代行区分
				K06.GNR_ZNDK_KBN,								-- 元利払対象残高区分
				CASE WHEN K06.TOTSUGO_KEKKA_KBN='0' THEN  1  ELSE 0 END  AS MITOTSU_SORT 	-- 未突合とそれ以外のソート順
		FROM mgr_kihon_view vmg1, vjiko_itaku vj1, scode mcd1, ganri_zandaka k06
LEFT OUTER JOIN mtsuka m641 ON (K06.SYS_HAKKO_TSUKA_CD = M641.TSUKA_CD)
LEFT OUTER JOIN mtsuka m642 ON (K06.KK_HAKKO_TSUKA_CD = M642.TSUKA_CD)
LEFT OUTER JOIN scode mcd2 ON (K06.GNR_ZNDK_KBN = MCD2.CODE_VALUE AND '742' = MCD2.CODE_SHUBETSU)
WHERE K06.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND K06.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD AND K06.ISIN_CD = VMG1.ISIN_CD AND VJ1.KAIIN_ID = l_inItakuKaishaCd   AND K06.TOTSUGO_KEKKA_KBN = MCD1.CODE_VALUE AND MCD1.CODE_SHUBETSU = '141'   AND VMG1.MGR_STAT_KBN = '1' ORDER BY 	K06.GNR_ZNDK_KBN DESC,
					MITOTSU_SORT,
					K06.TOTSUGO_KEKKA_KBN DESC,
					K06.ISIN_CD ASC;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp02101 START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inKijunYmd)::text, '') = ''
	OR coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inUserId)::text, '') = ''
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''
	OR coalesce(trim(both l_inGyomuYmd)::text, '') = ''
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		--pkLog.error(l_inUserId, REPORT_ID, 'SQLERRM:'||'');
		RETURN;
	END IF;
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	-- データ取得
	FOR recMeisai IN curMeisai LOOP
		gSeqNo := gSeqNo + 1;
		-- 委託会社略称
		gItakuKaishaRnm := NULL;
		IF recMeisai.JIKO_DAIKO_KBN = '2' THEN
			gItakuKaishaRnm := recMeisai.BANK_RNM;
		END IF;
        if spIp02101_isTeijiShokan(l_inItakuKaishaCd, recMeisai.ISIN_CD) <> 1::numeric then
           recMeisai.SYS_FACTOR := null;
           recMeisai.SYS_GNR_JISSHITSU_ZNDK := null;
           recMeisai.KK_FACTOR := null;
           recMeisai.KK_GNR_JISSHITSU_ZNDK := null;
        end if;
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := recMeisai.KK_SHORI_YMD;	-- 機構_処理日
		v_item.l_inItem003 := recMeisai.GNR_ZNDK_NM;	-- 元利払対象残高区分名称
		v_item.l_inItem004 := recMeisai.TOTSUGO_KEKKA_NM;	-- 突合結果名称
		v_item.l_inItem005 := recMeisai.ISIN_CD;	-- ＩＳＩＮコード
		v_item.l_inItem006 := recMeisai.MGR_RNM;	-- 銘柄略称
		v_item.l_inItem007 := recMeisai.SYS_SHASAI_ZNDK;	-- システム_社債残高
		v_item.l_inItem008 := recMeisai.SYS_OSAE_ZNDK;	-- システム_差押残高
		v_item.l_inItem009 := recMeisai.SYS_GNRBARAI_YMD;	-- システム_元利払日
		v_item.l_inItem010 := recMeisai.SYS_FACTOR;	-- システム_ファクター
		v_item.l_inItem011 := recMeisai.SYS_GNR_ZNDK;	-- システム_元利払対象残高
		v_item.l_inItem012 := recMeisai.SYS_GNR_JISSHITSU_ZNDK;	-- システム_元利払対象残高（実質）
		v_item.l_inItem013 := recMeisai.SYS_HAKKO_TSUKA_NM;	-- システム_発行通貨名称
		v_item.l_inItem014 := recMeisai.KK_GNRBARAI_YMD;	-- 機構_元利払日
		v_item.l_inItem015 := recMeisai.KK_FACTOR;	-- 機構_ファクター
		v_item.l_inItem016 := recMeisai.KK_GNR_ZNDK;	-- 機構_元利払対象残高
		v_item.l_inItem017 := recMeisai.KK_GNR_JISSHITSU_ZNDK;	-- 機構_元利払対象残高（実質）
		v_item.l_inItem018 := recMeisai.KK_HAKKO_TSUKA_NM;	-- 機構_発行通貨名称
		v_item.l_inItem019 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem020 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem021 := FMT_HAKKO_KNGK_J;	-- 発行金額書式フォーマット
		v_item.l_inItem022 := FMT_RBR_KNGK_J;	-- 利払金額書式フォーマット
		v_item.l_inItem023 := FMT_SHOKAN_KNGK_J;	-- 償還金額書式フォーマット
		v_item.l_inItem025 := recMeisai.TOTSUGO_KEKKA_KBN;	-- 突合結果区分
		v_item.l_inItem026 := l_inKijunYmd;	-- 基準日
		v_item.l_inItem027 := recMeisai.GNR_ZNDK_KBN;	-- 元利払対象残高区分
		
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
	IF gSeqNo = 0 THEN
	-- 対象データなし
		gRtnCd := RTN_NODATA;
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem020 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem021 := FMT_HAKKO_KNGK_J;	-- 発行金額書式フォーマット
		v_item.l_inItem022 := FMT_RBR_KNGK_J;	-- 利払金額書式フォーマット
		v_item.l_inItem023 := FMT_SHOKAN_KNGK_J;	-- 償還金額書式フォーマット
		v_item.l_inItem024 := '対象データなし';
		v_item.l_inItem026 := l_inKijunYmd;	-- 基準日
		
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
	-- バッチ帳票管理テーブルに登録
	CALL pkPrtOk.insertPrtOk(
		l_inUserId, l_inItakuKaishaCd, l_inGyomuYmd, LIST_SAKUSEI_KBN, REPORT_ID);
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp02101 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
--		RAISE;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip02101 ( l_inKijunYmd TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT integer, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spip02101_isteijishokan ( l_inItakuKaishaCd MGR_KIHON_VIEW.ITAKU_KAISHA_CD%TYPE, l_inIsinCd MGR_KIHON_VIEW.ISIN_CD%TYPE ) RETURNS numeric AS $body$
DECLARE

        l_shokanMethodCd  MGR_KIHON_VIEW.SHOKAN_METHOD_CD%TYPE;  -- 償還方法格納先
        l_result  numeric(1) := 0;

BEGIN
        SELECT
            VMG1.SHOKAN_METHOD_CD AS SHOKAN_METHOD_CD         -- 償還方法
        INTO STRICT
            l_shokanMethodCd
        FROM
            MGR_KIHON_VIEW VMG1
        WHERE
            VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
            AND VMG1.ISIN_CD = l_inIsinCd
;
        -- 定時償還かどうか(定時償還の時だけ１を設定)
        IF ( l_shokanMethodCd = '2' )THEN
            l_result := 1;
        END IF;
        -- 1 = 定時償還 / 0 = それ以外
        RETURN(l_result);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN(NULL);
    END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spip02101_isteijishokan ( l_inItakuKaishaCd MGR_KIHON_VIEW.ITAKU_KAISHA_CD%TYPE, l_inIsinCd MGR_KIHON_VIEW.ISIN_CD%TYPE ) FROM PUBLIC;