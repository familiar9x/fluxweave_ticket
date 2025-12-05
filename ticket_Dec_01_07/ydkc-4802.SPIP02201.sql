




CREATE OR REPLACE PROCEDURE spip02201 ( l_inKijunYmd TEXT,		-- 基準日
 l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inUserId TEXT,		-- ユーザーID
 l_inChohyoKbn TEXT,		-- 帳票区分
 l_inGyomuYmd TEXT,		-- 業務日付
 l_inTojituKbn TEXT,		-- 当日区分(0：当日以外、1：当日)
 l_outSqlCode OUT integer,		-- リターン値
 l_outSqlErrM OUT text	-- エラーコメント
 ) AS $body$
DECLARE

--
--/* 著作権:Copyright(c)2004
--/* 会社名:JIP
--/* 概要　:機構から受信する「元利金請求ファイル」を受信時に、業務側のバッチ処理（突合処理）が
--/* 　　　 起動され、その結果をもとに、元利金請求データ突合リストを作成する。
--/* 　　　 各種バッチ帳票出力指示画面より印刷する。
--/* 引数　:l_inKijunYmd		IN	TEXT		基準日
--/* 　　　 l_inItakuKaishaCd	IN	TEXT		委託会社コード
--/* 　　　 l_inUserId		IN	TEXT		ユーザーID
--/* 　　　 l_inChohyoKbn		IN	TEXT		帳票区分
--/* 　　　 l_inGyomuYmd		IN	TEXT		業務日付
--/* 　　　 l_inTojituKbn		IN	TEXT		当日区分(0：当日以外、1：当日)
--/* 　　　 l_outSqlCode		OUT	INTEGER		リターン値
--/* 　　　 l_outSqlErrM		OUT	VARCHAR	エラーコメント
--/* 返り値:なし
--/* @version $Id: SPIP02201.SQL,v 1.16 2015/03/18 01:18:43 takahashi Exp $
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.02.10	JIP				新規作成
--/*  2005.10.15  JIP松田         発行金額の外貨用通貨フォーマットをZZ9.99からZZ9に変更
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
	REPORT_ID1			CONSTANT char(11)	:= 'IP030002211';			-- 帳票ID（当日以外）
	REPORT_ID2			CONSTANT char(11)	:= 'IP030002221';			-- 帳票ID（当日）
	LIST_SAKUSEI_KBN	CONSTANT char(1)	:= '3';						-- 作成区分(3：随時)
	-- 書式フォーマット
	FMT_HAKKO_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	FMT_RBR_KNGK_J		CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 利払金額
	FMT_SHOKAN_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 償還金額
	-- 書式フォーマット（外資）
	FMT_HAKKO_KNGK_F	CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	FMT_RBR_KNGK_F		CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 利払金額
	FMT_SHOKAN_KNGK_F	CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 償還金額
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd				integer :=	RTN_OK;							-- リターンコード
	gSeqNo				integer := 0;								-- シーケンス
	-- 書式フォーマット
	gFmtHakkoKngk		varchar(21) := NULL;						-- 発行金額
	gFmtRbrKngk			varchar(21) := NULL;						-- 利払金額
	gFmtShokanKngk		varchar(21) := NULL;						-- 償還金額
	gWarning1			varchar(2) := NULL;						-- 帳票コメント(ITEM034)
	gWarning2			varchar(2) := NULL;						-- 帳票コメント(ITEM035)
	gItakuKaishaRnm		VJIKO_ITAKU.BANK_RNM%TYPE;						-- 委託会社略称
	gReportId			char(11) := ' ';							-- 帳票ID
--==============================================================================
--					カーソル定義													
--==============================================================================
	curMeisai CURSOR FOR
		SELECT 	K07.ISIN_CD,											-- ＩＳＩＮコード
				VMG1.MGR_RNM,											-- 銘柄略称
				CASE WHEN K07.RKN_SGK=0 THEN  '0'  ELSE '1' END  AS RKN_SGK_UMU_FLG,	-- 利金差額有無フラグ
				CASE WHEN K07.RKN_SGK=0 THEN  ''  ELSE '差額有' END  AS RKN_SGK_UMU_NM,	-- 利金差額有無名称
				VMG1.HAKKO_TSUKA_CD,										-- 発行通貨コード
				VMG1.RBR_TSUKA_CD,										-- 利払通貨コード
				VMG1.SHOKAN_TSUKA_CD,									-- 償還通貨コード
				M641.TSUKA_NM AS HAKKO_TSUKA_NM,						-- 発行通貨名称
				CASE WHEN K07.TOTSUGO_KEKKA_KBN='3' THEN  NULL  ELSE K07.SYS_FACTOR END  AS SYS_FACTOR,							-- システム_ファクター
				CASE WHEN K07.TOTSUGO_KEKKA_KBN='3' THEN  NULL  ELSE K07.SYS_GNR_ZNDK END  AS SYS_GNR_ZNDK,						-- システム_元利払対象残高
				CASE WHEN K07.TOTSUGO_KEKKA_KBN='3' THEN  NULL  ELSE K07.SYS_GNR_JISSHITSU_ZNDK END  AS SYS_GNR_JISSHITSU_ZNDK,	-- システム_元利払対象残高（実質）
				CASE WHEN K07.TOTSUGO_KEKKA_KBN='3' THEN  NULL  ELSE K07.SYS_ZEIHIKI_BEF_KNGK END  AS SYS_ZEIHIKI_BEF_KNGK,		-- システム_利金金額（税引前）
				CASE WHEN K07.TOTSUGO_KEKKA_KBN='3' THEN  NULL  ELSE K07.SYS_SHOKAN_KNGK END  AS SYS_SHOKAN_KNGK,					-- システム_償還金額
				CASE WHEN K07.TOTSUGO_KEKKA_KBN='0' THEN  NULL WHEN K07.TOTSUGO_KEKKA_KBN='3' THEN  NULL  ELSE K07.RKN_SGK END  AS RKN_SGK,						-- 利金差額
				CASE WHEN K07.TOTSUGO_KEKKA_KBN='3' THEN  NULL  ELSE M642.TSUKA_NM END  AS SYS_RBR_TSUKA_NM,						-- システム_利金通貨名称
				CASE WHEN K07.TOTSUGO_KEKKA_KBN='3' THEN  NULL  ELSE M643.TSUKA_NM END  AS SYS_SHOKAN_TSUKA_NM,					-- システム_償還通貨名称
				coalesce(trim(both K07.KK_GNRBARAI_YMD), K07.SYS_GNRBARAI_YMD) AS GNRBARAI_YMD,	-- 元利払日
				CASE WHEN K07.TOTSUGO_KEKKA_KBN='0' THEN  NULL  ELSE K07.KK_FACTOR END  AS KK_FACTOR,								-- 機構_ファクター
				CASE WHEN K07.TOTSUGO_KEKKA_KBN='0' THEN  NULL  ELSE K07.KK_GNR_ZNDK END  AS KK_GNR_ZNDK,							-- 機構_元利払対象残高
				CASE WHEN K07.TOTSUGO_KEKKA_KBN='0' THEN  NULL  ELSE K07.KK_GNR_JISSHITSU_ZNDK END  AS KK_GNR_JISSHITSU_ZNDK,		-- 機構_元利払対象残高（実質）
				CASE WHEN K07.TOTSUGO_KEKKA_KBN='0' THEN  NULL  ELSE K07.KK_ZEIHIKI_BEF_KNGK END  AS KK_ZEIHIKI_BEF_KNGK,			-- 機構_利金金額（税引前）
				CASE WHEN K07.TOTSUGO_KEKKA_KBN='0' THEN  NULL  ELSE K07.KK_SHOKAN_KNGK END  AS KK_SHOKAN_KNGK,					-- 機構_償還金額
				CASE WHEN K07.TOTSUGO_KEKKA_KBN='0' THEN  NULL  ELSE M644.TSUKA_NM END  AS KK_RBR_TSUKA_NM,						-- 機構_利金通貨名称
				CASE WHEN K07.TOTSUGO_KEKKA_KBN='0' THEN  NULL  ELSE M645.TSUKA_NM END  AS KK_SHOKAN_TSUKA_NM,					-- 機構_償還通貨名称
				K07.ZEI_KBN_TOTSUGO_KEKKA_KBN,																	-- 税区分突合結果区分			
				K07.KK_SHORI_YMD,										-- 機構_処理日
				K07.TOTSUGO_KEKKA_KBN,									-- 突合結果区分
				MCD1.CODE_NM AS TOTSUGO_KEKKA_NM,						-- 突合結果名称
				CASE WHEN K07.TOTSUGO_KEKKA_KBN='3' THEN  NULL  ELSE MCD2.CODE_RNM END  AS SYS_KOBETSU_FLG_RNM,					-- システム_個別承認フラグ略称
				CASE WHEN K07.TOTSUGO_KEKKA_KBN='0' THEN  NULL  ELSE MCD3.CODE_RNM END  AS KK_KOBETSU_FLG_RNM,					-- 機構_個別承認フラグ略称
				VJ1.BANK_RNM,											-- 銀行略称
				VJ1.JIKO_DAIKO_KBN, 										-- 自行代行区分
				VMG1.SHOKAN_METHOD_CD,                                   -- 償還方法
				CASE WHEN K07.TOTSUGO_KEKKA_KBN='0' THEN  1  ELSE 0 END  AS MITOTSU_SORT,  -- 未突合とそれ以外のソート順
				VMG1.TOKUTEI_KOUSHASAI_FLG 								-- 特例公社債フラグ
		FROM mgr_kihon_view vmg1, vjiko_itaku vj1, ganri_seikyu k07
LEFT OUTER JOIN mtsuka m641 ON (K07.SYS_HAKKO_TSUKA_CD = M641.TSUKA_CD)
LEFT OUTER JOIN mtsuka m642 ON (K07.SYS_RBR_TSUKA_CD = M642.TSUKA_CD)
LEFT OUTER JOIN mtsuka m643 ON (K07.SYS_SHOKAN_TSUKA_CD = M643.TSUKA_CD)
LEFT OUTER JOIN mtsuka m644 ON (K07.KK_RBR_TSUKA_CD = M644.TSUKA_CD)
LEFT OUTER JOIN mtsuka m645 ON (K07.KK_SHOKAN_TSUKA_CD = M645.TSUKA_CD)
LEFT OUTER JOIN scode mcd1 ON (K07.TOTSUGO_KEKKA_KBN = MCD1.CODE_VALUE AND '141' = MCD1.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd2 ON (K07.SYS_KOBETSU_FLG = MCD2.CODE_VALUE AND '511' = MCD2.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd3 ON (K07.KK_KOBETSU_FLG = MCD3.CODE_VALUE AND '511' = MCD3.CODE_SHUBETSU)
WHERE K07.ITAKU_KAISHA_CD = L_INITAKUKAISHACD AND K07.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD AND K07.ISIN_CD = VMG1.ISIN_CD AND VJ1.KAIIN_ID = L_INITAKUKAISHACD            AND VMG1.MGR_STAT_KBN = '1' AND (
				(
					l_inTojituKbn        = '1'      AND
					K07.SYS_GNRBARAI_YMD = l_inGyomuYmd
				)
			OR (
					l_inTojituKbn         = '0'      AND
					K07.SYS_GNRBARAI_YMD != l_inGyomuYmd
				)
			) ORDER BY
		MITOTSU_SORT,
                    K07.KK_SHORI_YMD,
                    K07.KK_GNRBARAI_YMD,
                    K07.TOTSUGO_KEKKA_KBN DESC,
					RKN_SGK_UMU_FLG DESC,
					K07.ISIN_CD ASC;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	-- 今回出力する帳票IDを引数の帳票IDより再設定を行う
	IF l_inTojituKbn = '0' THEN
		gReportId := REPORT_ID1;
	ELSE
		gReportId := REPORT_ID2;
	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, gReportId, 'spIp02201 START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inKijunYmd)::text, '') = ''
	OR coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inUserId)::text, '') = ''
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''
	OR coalesce(trim(both l_inGyomuYmd)::text, '') = ''
	OR coalesce(trim(both l_inTojituKbn)::text, '') = ''
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, gReportId, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', gReportId, 'SQLERRM:'||'');
		RETURN;
	END IF;
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = gReportId;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, gReportId);
	-- データ取得
	FOR recMeisai IN curMeisai LOOP
		gSeqNo := gSeqNo + 1;
		-- 書式フォーマットの設定
		-- 発行
		IF recMeisai.HAKKO_TSUKA_CD = 'JPY' THEN
			gFmtHakkoKngk := FMT_HAKKO_KNGK_J;
		ELSE
			gFmtHakkoKngk := FMT_HAKKO_KNGK_F;
		END IF;
		-- 利払
		IF recMeisai.RBR_TSUKA_CD = 'JPY' THEN
			gFmtRbrKngk := FMT_RBR_KNGK_J;
		ELSE
			gFmtRbrKngk := FMT_RBR_KNGK_F;
		END IF;
		-- 償還
		IF recMeisai.SHOKAN_TSUKA_CD = 'JPY' THEN
			gFmtShokanKngk := FMT_SHOKAN_KNGK_J;
		ELSE
			gFmtShokanKngk := FMT_SHOKAN_KNGK_F;
		END IF;
		-- 委託会社略称
		gItakuKaishaRnm := NULL;
		IF recMeisai.JIKO_DAIKO_KBN = '2' THEN
			gItakuKaishaRnm := recMeisai.BANK_RNM;
		END IF;
        -- AD-00188対応
        -- 償還方法が、定額償還時のみ実質残高及びファクタを表示する（IPA・機構両方）
        IF recMeisai.SHOKAN_METHOD_CD <> '2' THEN
           -- 定時償還以外の場合(表示させない)
           recMeisai.SYS_FACTOR             := NULL;
           recMeisai.SYS_GNR_JISSHITSU_ZNDK := NULL;
           recMeisai.KK_FACTOR              := NULL;
           recMeisai.KK_GNR_JISSHITSU_ZNDK  := NULL;
        END IF;
        -- 税区分突合結果区分によって帳票に以下をセットする
        IF recMeisai.ZEI_KBN_TOTSUGO_KEKKA_KBN = '1' THEN
           	gWarning1 := '*1';
           	gWarning2 := NULL;
        ELSIF recMeisai.ZEI_KBN_TOTSUGO_KEKKA_KBN = '2' THEN
        	gWarning1 := NULL;
        	gWarning2 := '*2';
        ELSIF recMeisai.ZEI_KBN_TOTSUGO_KEKKA_KBN = '3' THEN
        	gWarning1 := '*1';
        	gWarning2 := '*2';
        ELSE
        	gWarning1 := NULL;
        	gWarning2 := NULL;
        END IF;
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := recMeisai.KK_SHORI_YMD;	-- 機構_処理日
		v_item.l_inItem003 := recMeisai.GNRBARAI_YMD;	-- 機構_元利払日
		v_item.l_inItem004 := recMeisai.TOTSUGO_KEKKA_NM;	-- 突合結果名称
		v_item.l_inItem005 := recMeisai.RKN_SGK_UMU_NM;	-- 利金差額有無名称
		v_item.l_inItem006 := recMeisai.ISIN_CD;	-- ＩＳＩＮコード
		v_item.l_inItem007 := recMeisai.MGR_RNM;	-- 銘柄略称
		v_item.l_inItem008 := recMeisai.HAKKO_TSUKA_NM;	-- 発行通貨名称
		v_item.l_inItem009 := recMeisai.SYS_KOBETSU_FLG_RNM;	-- システム_個別承認フラグ略称
		v_item.l_inItem010 := recMeisai.SYS_FACTOR;	-- システム_ファクター
		v_item.l_inItem011 := recMeisai.SYS_GNR_ZNDK;	-- システム_元利払対象残高
		v_item.l_inItem012 := recMeisai.SYS_GNR_JISSHITSU_ZNDK;	-- システム_元利払対象残高（実質）
		v_item.l_inItem013 := recMeisai.SYS_ZEIHIKI_BEF_KNGK;	-- システム_利金金額（税引前）
		v_item.l_inItem014 := recMeisai.SYS_SHOKAN_KNGK;	-- システム_償還金額
		v_item.l_inItem015 := recMeisai.SYS_RBR_TSUKA_NM;	-- システム_利金通貨名称
		v_item.l_inItem016 := recMeisai.SYS_SHOKAN_TSUKA_NM;	-- システム_償還通貨名称
		v_item.l_inItem017 := recMeisai.KK_KOBETSU_FLG_RNM;	-- 機構_個別承認フラグ略称
		v_item.l_inItem018 := recMeisai.KK_FACTOR;	-- 機構_ファクター
		v_item.l_inItem019 := recMeisai.KK_GNR_ZNDK;	-- 機構_元利払対象残高
		v_item.l_inItem020 := recMeisai.KK_GNR_JISSHITSU_ZNDK;	-- 機構_元利払対象残高（実質）
		v_item.l_inItem021 := recMeisai.KK_ZEIHIKI_BEF_KNGK;	-- 機構_利金金額（税引前）
		v_item.l_inItem022 := recMeisai.KK_SHOKAN_KNGK;	-- 機構_償還金額
		v_item.l_inItem023 := recMeisai.KK_RBR_TSUKA_NM;	-- 機構_利金通貨名称
		v_item.l_inItem024 := recMeisai.KK_SHOKAN_TSUKA_NM;	-- 機構_償還通貨名称
		v_item.l_inItem025 := recMeisai.RKN_SGK;	-- 利金差額
		v_item.l_inItem026 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem027 := gReportId;	-- 帳票ＩＤ
		v_item.l_inItem028 := gFmtHakkoKngk;	-- 発行金額書式フォーマット
		v_item.l_inItem029 := gFmtRbrKngk;	-- 利払金額書式フォーマット
		v_item.l_inItem030 := gFmtShokanKngk;	-- 償還金額書式フォーマット
		v_item.l_inItem032 := recMeisai.TOTSUGO_KEKKA_KBN;	-- 突合結果区分
		v_item.l_inItem033 := recMeisai.RKN_SGK_UMU_FLG;	-- 利金差額有無フラグ
		v_item.l_inItem034 := l_inKijunYmd;	-- データ基準日
		v_item.l_inItem035 := gWarning1;	-- ワーニング１
		v_item.l_inItem036 := gWarning2;	-- ワーニング２
		v_item.l_inItem037 := recMeisai.TOKUTEI_KOUSHASAI_FLG;	-- 特定公社債フラグ
		
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
	END LOOP;
	IF gSeqNo = 0 THEN
	-- 対象データなし
		gRtnCd := RTN_NODATA;
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem027 := gReportId;	-- 帳票ＩＤ
		v_item.l_inItem028 := FMT_HAKKO_KNGK_J;	-- 発行金額書式フォーマット
		v_item.l_inItem029 := FMT_RBR_KNGK_J;	-- 利払金額書式フォーマット
		v_item.l_inItem030 := FMT_SHOKAN_KNGK_J;	-- 償還金額書式フォーマット
		v_item.l_inItem031 := '対象データなし';
		v_item.l_inItem034 := l_inKijunYmd;	-- データ基準日
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> gReportId,
			l_inSeqNo		=> 1,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	END IF;
	-- バッチ帳票管理テーブルに登録
	CALL pkPrtOk.insertPrtOk(
		l_inUserId, l_inItakuKaishaCd, l_inGyomuYmd, LIST_SAKUSEI_KBN, gReportId);
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, gReportId, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, gReportId, 'spIp02201 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		CALL pkLog.fatal('ECM701', gReportId, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal('ECM701', gReportId, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip02201 ( l_inKijunYmd TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_inTojituKbn TEXT, l_outSqlCode OUT integer, l_outSqlErrM OUT text ) FROM PUBLIC;