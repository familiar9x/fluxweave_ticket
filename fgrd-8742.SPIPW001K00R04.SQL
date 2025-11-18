




CREATE OR REPLACE PROCEDURE spipw001k00r04 ( 
    l_inMgrCd TEXT,		-- 銘柄コード
 l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inUserId TEXT,		-- ユーザーID
 l_inChohyoKbn TEXT,		-- 帳票区分
 l_inGyomuYmd TEXT,		-- 業務日付
 l_outSqlCode OUT integer,		-- リターン値
 l_outSqlErrM OUT text	-- エラーコメント
 ) AS $body$
DECLARE

--
--/* 著作権:Copyright(c)2008
--/* 会社名:JIP
--/*
--/* 銘柄情報（ＣＢ）個別照会画面から、銘柄詳細情報リスト（手数料設定情報）を作成する。
--/*
--/* @author  原田
--/* @version $Id: SPIPW001K00R04.SQL,v 1.2 2008/03/31 13:49:43 takubo Exp $
--/*
--/* @param l_inMgrCd			IN	TEXT		銘柄コード
--/* @param l_inItakuKaishaCd	IN	TEXT		委託会社コード
--/* @param l_inUserId		IN	TEXT		ユーザーID
--/* @param l_inChohyoKbn		IN	TEXT		帳票区分
--/* @param l_inGyomuYmd		IN	TEXT		業務日付
--/* @param l_outSqlCode		OUT	INTEGER		リターン値
--/* @param l_outSqlErrM		OUT	VARCHAR	エラーコメント
--/* @return なし
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2008.01.28	原田			新規作成
--/*
--/*
--***************************************************************************
--
--==============================================================================
--					デバッグ機能													
--==============================================================================
	DEBUG	numeric(1)	:= 0;
--==============================================================================
--					配列定義													
--==============================================================================
--==============================================================================
--					定数定義													
--==============================================================================
	RTN_OK				CONSTANT integer	:= 0;						-- 正常
	RTN_NG				CONSTANT integer	:= 1;						-- 予期したエラー
	RTN_NODATA			CONSTANT integer	:= 2;						-- データなし
	RTN_FATAL			CONSTANT integer	:= 99;						-- 予期せぬエラー
	REPORT_ID			CONSTANT char(11)	:= 'IPW30000141';			-- 帳票ID
	-- 書式フォーマット
	FMT_HAKKO_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	FMT_RBR_KNGK_J		CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 利払金額
	FMT_SHOKAN_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 償還金額
--==============================================================================
--					変数定義													
--==============================================================================
	gRtnCd				integer :=	RTN_OK;							-- リターンコード
	gSeqNo				integer := 0;								-- シーケンス
	-- 発行時
	gAryChooseFlgNm1 varchar[];						-- 選択フラグ内容１〜１５
	gAryTesuShuruiNm1 varchar[];						-- 手数料１〜１５
	gAryTesuSashihikiKbnNm varchar[];						-- 手数料差引区分１〜１５
	gAryKozaFuriKbnNm1 varchar[];						-- 口座振替区分１〜１５
	gAryHakkoTesuChokyuKbnNm varchar[];						-- 徴求タイミング１〜１５
	gAryKonaiTesuNm1 varchar[];						-- 行内手数料名称１〜１５
	-- 発行後
	gAryChooseFlgNm2 varchar[];						-- 選択フラグ内容１〜１５
	gAryTesuShuruiNm2 varchar[];						-- 手数料１〜１５
	gAryKonaiTesuNm2 varchar[];						-- 行内手数料名称１〜１５
	gAryKozaFuriKbnNm2 varchar[];						-- 口座振替区分１〜１５
	gAryKobetsuseikyuoutKbnNm varchar[];						-- 個別請求書出力区分１〜１５
	gAryBillOutTmg1Nm varchar[];						-- 請求書出力タイミング１名称１〜１５
	gAryBillOutDd varchar[];						-- 請求書出力タイミング日数１〜１５
	gAryBillOutTmg2Nm varchar[];						-- 請求書出力タイミング２名称１〜１５
	-- カウンタ
	gHakkogoCnt					integer := 0;				-- 発行時請求分
	gHakkojiCnt					integer := 0;				-- 期中請求分
	gItakuKaishaRnm				VJIKO_ITAKU.BANK_RNM%TYPE;			-- 委託会社略称
	-- 最終承認ユーザ及び最終承認日
	gLastShoninId				VMGR_STS.LAST_SHONIN_ID%TYPE;		-- 最終承認ユーザId
	gLastShoninYmd				VMGR_STS.LAST_SHONIN_YMD%TYPE;		-- 最終承認日
	-- Composite type for pkPrint.insertData
	v_item type_sreport_wk_item;
	
--==============================================================================
--					カーソル定義													
--==============================================================================
	curMeisai CURSOR FOR
		SELECT 	VMG0.TESU_SET_TEISEI_YMD,					-- 手数料設定訂正日
				VMG0.TESU_SET_TEISEI_USER_ID,				-- 手数料設定訂正ユーザ
				VMG0.LAST_SHONIN_YMD,						-- 最終承認日
				VMG0.LAST_SHONIN_ID,						-- 最終承認ユーザ
				VMG1.MGR_CD,								-- 銘柄コード
				VMG1.ISIN_CD,								-- ＩＳＩＮコード
				VMG1.MGR_RNM,								-- 銘柄略称
				VMG1.JTK_KBN,								-- 受託区分
				VMG1.JTK_KBN_NM,							-- 受託区分名称
				VMG1.TANPO_KBN_NM,							-- 担保区分名称
				MCD1.CODE_NM AS SZEI_SEIKYU_KBN_NM,			-- 消費税請求区分名称
				MCD2.CODE_NM AS NYUKIN_KOZA_KBN_NM,			-- 入金口座選択区分名称
				CASE WHEN VMG7.CHOOSE_FLG='0' THEN  NULL  ELSE 'レ' END  AS CHOOSE_FLG_NM,
															--選択フラグ内容（選択されていたら"レ"を表示する）
				VMG7.HAKKO_KICHU_KBN,						-- 発行・期中区分
				VMG7.TESU_SHURUI_NM,						-- 手数料種類名称
				VMG7.KONAI_TESU_SHURUI_NM,						-- 行内手数料名称
                --選択されている場合のみ名称を表示する
				CASE WHEN VMG7.CHOOSE_FLG='0' THEN  null  ELSE VMG7.TESU_SASHIHIKI_KBN_NM END  AS TESU_SASHIHIKI_KBN_NM,-- 手数料差引区分名称
				VMG7.KOZA_FURI_KBN_NM,						-- 口座振替区分名称
				MCD3.CODE_NM AS HAKKO_TESU_CHOKYU_KBN_NM,	-- 徴求タイミング名称
                --選択されている場合のみ名称を表示する
				CASE WHEN VMG7.CHOOSE_FLG='0' THEN  null  ELSE MCD4.CODE_NM END  AS KOBETSUSEIKYUOUT_KBN_NM,-- 個別請求書出力区分名称
				VMG7.BILL_OUT_TMG1_NM,						-- 請求書出力タイミング１名称
                --「0」表示しないように修正
				CASE WHEN VMG7.BILL_OUT_DD=0 THEN  NULL  ELSE VMG7.BILL_OUT_DD::text END  AS BILL_OUT_DD, -- 請求書出力タイミング日数
				VMG7.BILL_OUT_TMG2_NM,						-- 請求書出力タイミング２名称
				VJ1.BANK_RNM,								-- 銀行略称
				VJ1.JIKO_DAIKO_KBN 							-- 自行代行区分
				,(SELECT CODE_NM FROM SCODE WHERE VMG0.MGR_STAT_KBN = CODE_VALUE AND CODE_SHUBETSU = '161') AS SHONIN_STAT_NM 		-- 承認状態
				,VMG0.MGR_STAT_KBN 							-- 銘柄ステータス区分
				,CASE WHEN VMG7.TESU_SHURUI_CD='01' THEN 1 WHEN VMG7.TESU_SHURUI_CD='02' THEN 2 WHEN VMG7.TESU_SHURUI_CD='03' THEN 3 WHEN VMG7.TESU_SHURUI_CD='04' THEN 4 WHEN VMG7.TESU_SHURUI_CD='31' THEN 5 WHEN VMG7.TESU_SHURUI_CD='32' THEN 6 WHEN VMG7.TESU_SHURUI_CD='33' THEN 7 WHEN VMG7.TESU_SHURUI_CD='34' THEN 8 WHEN VMG7.TESU_SHURUI_CD='51' THEN 9 WHEN VMG7.TESU_SHURUI_CD='46' THEN 10 WHEN VMG7.TESU_SHURUI_CD='47' THEN 11 WHEN VMG7.TESU_SHURUI_CD='71' THEN 12 WHEN VMG7.TESU_SHURUI_CD='72' THEN 13 WHEN VMG7.TESU_SHURUI_CD='73' THEN 14 WHEN VMG7.TESU_SHURUI_CD='74' THEN 15					  ELSE 9999 END  AS DispOrder
		FROM vmgr_list vmg1, vmgr_sts vmg0, vjiko_itaku vj1, vmgr_tesuryo_ctl vmg7
LEFT OUTER JOIN scode mcd3 ON (VMG7.HAKKO_TESU_CHOKYU_KBN = MCD3.CODE_VALUE AND '119' = MCD3.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd4 ON (VMG7.KOBETSUSEIKYUOUT_KBN = MCD4.CODE_VALUE AND '165' = MCD4.CODE_SHUBETSU)
, vmgr_tesuryo_prm vmg8
LEFT OUTER JOIN scode mcd1 ON (VMG8.SZEI_SEIKYU_KBN = MCD1.CODE_VALUE AND '175' = MCD1.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd2 ON (VMG8.NYUKIN_KOZA_KBN = MCD2.CODE_VALUE AND '122' = MCD2.CODE_SHUBETSU)
WHERE VMG7.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND VMG7.ITAKU_KAISHA_CD = VMG0.ITAKU_KAISHA_CD AND VMG7.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD AND VMG7.ITAKU_KAISHA_CD = VMG8.ITAKU_KAISHA_CD AND VMG7.ITAKU_KAISHA_CD = VJ1.KAIIN_ID AND VMG7.MGR_CD = l_inMgrCd AND VMG7.MGR_CD = VMG0.MGR_CD AND VMG7.MGR_CD = VMG1.MGR_CD AND VMG7.MGR_CD = VMG8.MGR_CD         ORDER BY 	VMG7.HAKKO_KICHU_KBN,
					DispOrder,
					VMG7.TESU_SHURUI_CD;
	-- レコード
	recWkMeisai	RECORD;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPW001K00R04 START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inMgrCd)::text, '') = ''
	OR coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inUserId)::text, '') = ''
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''
	OR coalesce(trim(both l_inGyomuYmd)::text, '') = ''
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := 'パラメータエラー';
		CALL pkLog.error('ECM501', REPORT_ID, 'SQLERRM:'|| l_outSqlErrM);
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
	-- 配列の初期化
	gAryChooseFlgNm1 := ARRAY[NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL]::varchar[];
	gAryTesuShuruiNm1 := ARRAY[NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL]::varchar[];
	gAryKonaiTesuNm1 := ARRAY[NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL]::varchar[];
	gAryTesuSashihikiKbnNm := ARRAY[NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL]::varchar[];
	gAryKozaFuriKbnNm1 := ARRAY[NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL]::varchar[];
	gAryHakkoTesuChokyuKbnNm := ARRAY[NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL]::varchar[];
	gAryChooseFlgNm2 := ARRAY[NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL]::varchar[];
	gAryTesuShuruiNm2 := ARRAY[NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL]::varchar[];
	gAryKonaiTesuNm2 := ARRAY[NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL]::varchar[];
	gAryKozaFuriKbnNm2 := ARRAY[NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL]::varchar[];
	gAryKobetsuseikyuoutKbnNm := ARRAY[NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL]::varchar[];
	gAryBillOutTmg1Nm := ARRAY[NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL]::varchar[];
	gAryBillOutDd := ARRAY[NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL]::varchar[];
	gAryBillOutTmg2Nm := ARRAY[NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL]::varchar[];
	-- データ取得
	FOR recMeisai IN curMeisai LOOP
		gSeqNo := gSeqNo + 1;
		IF gSeqNo = 1 THEN
			-- レコードのセット
			recWkMeisai := recMeisai;
		END IF;
		CASE recMeisai.HAKKO_KICHU_KBN
			WHEN '1' THEN 		-- 発行時請求分
				IF (trim(both recMeisai.TESU_SHURUI_NM) IS NOT NULL AND (trim(both recMeisai.TESU_SHURUI_NM))::text <> '')
				OR (trim(both recMeisai.TESU_SASHIHIKI_KBN_NM) IS NOT NULL AND (trim(both recMeisai.TESU_SASHIHIKI_KBN_NM))::text <> '')
				OR (trim(both recMeisai.KOZA_FURI_KBN_NM) IS NOT NULL AND (trim(both recMeisai.KOZA_FURI_KBN_NM))::text <> '')
				OR (trim(both recMeisai.HAKKO_TESU_CHOKYU_KBN_NM) IS NOT NULL AND (trim(both recMeisai.HAKKO_TESU_CHOKYU_KBN_NM))::text <> '')
				THEN
					gHakkojiCnt := gHakkojiCnt + 1;
					gAryChooseFlgNm1[gHakkojiCnt] 			:= recMeisai.CHOOSE_FLG_NM;				-- 選択フラグ内容１〜１５
					gAryTesuShuruiNm1[gHakkojiCnt] 			:= recMeisai.TESU_SHURUI_NM;			-- 手数料１〜１５
					gAryKonaiTesuNm1[gHakkojiCnt]			:= recMeisai.KONAI_TESU_SHURUI_NM;	-- 行内手数料名称１〜１５
					gAryTesuSashihikiKbnNm[gHakkojiCnt]		:= recMeisai.TESU_SASHIHIKI_KBN_NM;		-- 手数料差引区分１〜１５
					gAryKozaFuriKbnNm1[gHakkojiCnt]			:= recMeisai.KOZA_FURI_KBN_NM;			-- 口座振替区分１〜１５
					gAryHakkoTesuChokyuKbnNm[gHakkojiCnt]	:= recMeisai.HAKKO_TESU_CHOKYU_KBN_NM;	-- 徴求タイミング１〜１５
				END IF;
			WHEN '2' THEN 		-- 期中請求分
				IF (trim(both recMeisai.TESU_SHURUI_NM) IS NOT NULL AND (trim(both recMeisai.TESU_SHURUI_NM))::text <> '')
				OR (trim(both recMeisai.TESU_SASHIHIKI_KBN_NM) IS NOT NULL AND (trim(both recMeisai.TESU_SASHIHIKI_KBN_NM))::text <> '')
				OR (trim(both recMeisai.KOBETSUSEIKYUOUT_KBN_NM) IS NOT NULL AND (trim(both recMeisai.KOBETSUSEIKYUOUT_KBN_NM))::text <> '')
				OR (trim(both recMeisai.BILL_OUT_TMG1_NM) IS NOT NULL AND (trim(both recMeisai.BILL_OUT_TMG1_NM))::text <> '')
				OR (recMeisai.BILL_OUT_DD IS NOT NULL AND recMeisai.BILL_OUT_DD::integer <> 0) --「0」表示しないように修正
				OR (trim(both recMeisai.BILL_OUT_TMG2_NM) IS NOT NULL AND (trim(both recMeisai.BILL_OUT_TMG2_NM))::text <> '')
				THEN
					gHakkogoCnt := gHakkogoCnt + 1;
					gAryChooseFlgNm2[gHakkogoCnt] 			:= recMeisai.CHOOSE_FLG_NM;				-- 選択フラグ内容１〜１５
					gAryTesuShuruiNm2[gHakkogoCnt]			:= recMeisai.TESU_SHURUI_NM;			-- 手数料１〜１５
					gAryKonaiTesuNm2[gHakkogoCnt]			:= recMeisai.KONAI_TESU_SHURUI_NM;	-- 行内手数料名称１〜１５
					gAryKozaFuriKbnNm2[gHakkogoCnt]			:= recMeisai.KOZA_FURI_KBN_NM;			-- 口座振替区分１〜１５
					IF recMeisai.JTK_KBN <> '5' THEN
						gAryKobetsuseikyuoutKbnNm[gHakkogoCnt]	:= recMeisai.KOBETSUSEIKYUOUT_KBN_NM;	-- 個別請求書出力区分１〜１５
					END IF;					
					gAryBillOutTmg1Nm[gHakkogoCnt]			:= recMeisai.BILL_OUT_TMG1_NM;			-- 請求書出力タイミング１名称１〜１５
					gAryBillOutDd[gHakkogoCnt]				:= recMeisai.BILL_OUT_DD;				-- 請求書出力タイミング日数１〜１５
                    gAryBillOutTmg2Nm[gHakkogoCnt]			:= recMeisai.BILL_OUT_TMG2_NM;			-- 請求書出力タイミング２名称１〜１５
				END IF;
		END CASE;
	END LOOP;
	IF gSeqNo > 0 THEN
	-- 対象データあり
		-- 委託会社略称
		gItakuKaishaRnm := NULL;
		IF recWkMeisai.JIKO_DAIKO_KBN = '2' THEN
			gItakuKaishaRnm := recWkMeisai.BANK_RNM;
		END IF;
		-- 最終承認ユーザの表示非表示切り替え
		-- はじめに初期化しておく
		gLastShoninYmd	:= NULL;
		gLastShoninId	:= NULL;		
		-- 承認ステータスが承認以外の場合には表示しないようにする
		IF recWkMeisai.MGR_STAT_KBN = '1' THEN
			gLastShoninYmd	:= recWkMeisai.LAST_SHONIN_YMD;
			gLastShoninId	:= recWkMeisai.LAST_SHONIN_ID;
		END IF;
		-- 帳票ワークへデータを追加
				v_item := ROW();
		v_item.l_inItem001 := l_inUserId 									::varchar; -- ユーザＩＤ
		v_item.l_inItem002 := recWkMeisai.TESU_SET_TEISEI_YMD 				::varchar; -- 手数料設定訂正日
		v_item.l_inItem003 := recWkMeisai.TESU_SET_TEISEI_USER_ID 			::varchar; -- 手数料設定訂正ユーザ
		v_item.l_inItem004 := gLastShoninYmd 								::varchar; -- 最終承認日
		v_item.l_inItem005 := gLastShoninId 								::varchar; -- 最終承認ユーザ
		v_item.l_inItem006 := recWkMeisai.MGR_CD 							::varchar; -- 銘柄コード
		v_item.l_inItem007 := recWkMeisai.ISIN_CD 							::varchar; -- ＩＳＩＮコード
		v_item.l_inItem008 := recWkMeisai.MGR_RNM 							::varchar; -- 銘柄略称
		v_item.l_inItem009 := recWkMeisai.JTK_KBN_NM 						::varchar; -- 受託区分名称
		v_item.l_inItem010 := recWkMeisai.TANPO_KBN_NM 					::varchar; -- 担保区分名称
		v_item.l_inItem011 := recWkMeisai.SZEI_SEIKYU_KBN_NM 				::varchar; -- 消費税請求区分名称
		v_item.l_inItem012 := recWkMeisai.NYUKIN_KOZA_KBN_NM 				::varchar; -- 入金口座選択区分名称
		v_item.l_inItem013 := gAryTesuShuruiNm1[1]						::varchar; -- （発行時）手数料１
		v_item.l_inItem014 := gAryTesuSashihikiKbnNm[1]					::varchar; -- （発行時）手数料差引区分１
		v_item.l_inItem015 := gAryKozaFuriKbnNm1[1]						::varchar; -- （発行時）口座振替区分１
		v_item.l_inItem016 := gAryHakkoTesuChokyuKbnNm[1]					::varchar; -- （発行時）徴求タイミング１
		v_item.l_inItem017 := gAryTesuShuruiNm1[2]						::varchar; -- （発行時）手数料２
		v_item.l_inItem018 := gAryTesuSashihikiKbnNm[2]					::varchar; -- （発行時）手数料差引区分２
		v_item.l_inItem019 := gAryKozaFuriKbnNm1[2]						::varchar; -- （発行時）口座振替区分２
		v_item.l_inItem020 := gAryHakkoTesuChokyuKbnNm[2]					::varchar; -- （発行時）徴求タイミング２
		v_item.l_inItem021 := gAryTesuShuruiNm1[3]						::varchar; -- （発行時）手数料３
		v_item.l_inItem022 := gAryTesuSashihikiKbnNm[3]					::varchar; -- （発行時）手数料差引区分３
		v_item.l_inItem023 := gAryKozaFuriKbnNm1[3]						::varchar; -- （発行時）口座振替区分３
		v_item.l_inItem024 := gAryHakkoTesuChokyuKbnNm[3]					::varchar; -- （発行時）徴求タイミング３
		v_item.l_inItem025 := gAryTesuShuruiNm1[4]						::varchar; -- （発行時）手数料４
		v_item.l_inItem026 := gAryTesuSashihikiKbnNm[4]					::varchar; -- （発行時）手数料差引区分４
		v_item.l_inItem027 := gAryKozaFuriKbnNm1[4]						::varchar; -- （発行時）口座振替区分４
		v_item.l_inItem028 := gAryHakkoTesuChokyuKbnNm[4]					::varchar; -- （発行時）徴求タイミング４
		v_item.l_inItem029 := gAryTesuShuruiNm1[5]						::varchar; -- （発行時）手数料５
		v_item.l_inItem030 := gAryTesuSashihikiKbnNm[5]					::varchar; -- （発行時）手数料差引区分５
		v_item.l_inItem031 := gAryKozaFuriKbnNm1[5]						::varchar; -- （発行時）口座振替区分５
		v_item.l_inItem032 := gAryHakkoTesuChokyuKbnNm[5]					::varchar; -- （発行時）徴求タイミング５
		v_item.l_inItem033 := gAryTesuShuruiNm1[6]						::varchar; -- （発行時）手数料６
		v_item.l_inItem034 := gAryTesuSashihikiKbnNm[6]					::varchar; -- （発行時）手数料差引区分６
		v_item.l_inItem035 := gAryKozaFuriKbnNm1[6]						::varchar; -- （発行時）口座振替区分６
		v_item.l_inItem036 := gAryHakkoTesuChokyuKbnNm[6]					::varchar; -- （発行時）徴求タイミング６
		v_item.l_inItem037 := gAryTesuShuruiNm1[7]						::varchar; -- （発行時）手数料７
		v_item.l_inItem038 := gAryTesuSashihikiKbnNm[7]					::varchar; -- （発行時）手数料差引区分７
		v_item.l_inItem039 := gAryKozaFuriKbnNm1[7]						::varchar; -- （発行時）口座振替区分７
		v_item.l_inItem040 := gAryHakkoTesuChokyuKbnNm[7]					::varchar; -- （発行時）徴求タイミング７
		v_item.l_inItem041 := gAryTesuShuruiNm1[8]						::varchar; -- （発行時）手数料８
		v_item.l_inItem042 := gAryTesuSashihikiKbnNm[8]					::varchar; -- （発行時）手数料差引区分８
		v_item.l_inItem043 := gAryKozaFuriKbnNm1[8]						::varchar; -- （発行時）口座振替区分８
		v_item.l_inItem044 := gAryHakkoTesuChokyuKbnNm[8]					::varchar; -- （発行時）徴求タイミング８
		v_item.l_inItem045 := gAryTesuShuruiNm1[9]						::varchar; -- （発行時）手数料９
		v_item.l_inItem046 := gAryTesuSashihikiKbnNm[9]					::varchar; -- （発行時）手数料差引区分９
		v_item.l_inItem047 := gAryKozaFuriKbnNm1[9]						::varchar; -- （発行時）口座振替区分９
		v_item.l_inItem048 := gAryHakkoTesuChokyuKbnNm[9]					::varchar; -- （発行時）徴求タイミング９
		v_item.l_inItem049 := gAryTesuShuruiNm1[10]						::varchar; -- （発行時）手数料１０
		v_item.l_inItem050 := gAryTesuSashihikiKbnNm[10]					::varchar; -- （発行時）手数料差引区分１０
		v_item.l_inItem051 := gAryKozaFuriKbnNm1[10]						::varchar; -- （発行時）口座振替区分１０
		v_item.l_inItem052 := gAryHakkoTesuChokyuKbnNm[10]				::varchar; -- （発行時）徴求タイミング１０
		v_item.l_inItem053 := gAryTesuShuruiNm1[11]						::varchar; -- （発行時）手数料１１
		v_item.l_inItem054 := gAryTesuSashihikiKbnNm[11]					::varchar; -- （発行時）手数料差引区分１１
		v_item.l_inItem055 := gAryKozaFuriKbnNm1[11]						::varchar; -- （発行時）口座振替区分１１
		v_item.l_inItem056 := gAryHakkoTesuChokyuKbnNm[11]				::varchar; -- （発行時）徴求タイミング１１
		v_item.l_inItem057 := gAryTesuShuruiNm1[12]						::varchar; -- （発行時）手数料１２
		v_item.l_inItem058 := gAryTesuSashihikiKbnNm[12]					::varchar; -- （発行時）手数料差引区分１２
		v_item.l_inItem059 := gAryKozaFuriKbnNm1[12]						::varchar; -- （発行時）口座振替区分１２
		v_item.l_inItem060 := gAryHakkoTesuChokyuKbnNm[12]				::varchar; -- （発行時）徴求タイミング１２
		v_item.l_inItem061 := gAryTesuShuruiNm1[13]						::varchar; -- （発行時）手数料１３
		v_item.l_inItem062 := gAryTesuSashihikiKbnNm[13]					::varchar; -- （発行時）手数料差引区分１３
		v_item.l_inItem063 := gAryKozaFuriKbnNm1[13]						::varchar; -- （発行時）口座振替区分１３
		v_item.l_inItem064 := gAryHakkoTesuChokyuKbnNm[13]				::varchar; -- （発行時）徴求タイミング１３
		v_item.l_inItem065 := gAryTesuShuruiNm1[14]						::varchar; -- （発行時）手数料１４
		v_item.l_inItem066 := gAryTesuSashihikiKbnNm[14]					::varchar; -- （発行時）手数料差引区分１４
		v_item.l_inItem067 := gAryKozaFuriKbnNm1[14]						::varchar; -- （発行時）口座振替区分１４
		v_item.l_inItem068 := gAryHakkoTesuChokyuKbnNm[14]				::varchar; -- （発行時）徴求タイミング１４
		v_item.l_inItem069 := gAryTesuShuruiNm1[15]						::varchar; -- （発行時）手数料１５
		v_item.l_inItem070 := gAryTesuSashihikiKbnNm[15]					::varchar; -- （発行時）手数料差引区分１５
		v_item.l_inItem071 := gAryKozaFuriKbnNm1[15]						::varchar; -- （発行時）口座振替区分１５
		v_item.l_inItem072 := gAryHakkoTesuChokyuKbnNm[15]				::varchar; -- （発行時）徴求タイミング１５
		v_item.l_inItem073 := gAryTesuShuruiNm2[1]						::varchar; -- （発行後）手数料１
		v_item.l_inItem074 := gAryKozaFuriKbnNm2[1]						::varchar; -- （発行後）口座振替区分１
		v_item.l_inItem075 := gAryKobetsuseikyuoutKbnNm[1]				::varchar; -- （発行後）個別請求書出力区分１
		v_item.l_inItem076 := gAryBillOutTmg1Nm[1]						::varchar; -- （発行後）請求書出力タイミング１名称１
		v_item.l_inItem077 := gAryBillOutDd[1]							::varchar; -- （発行後）請求書出力タイミング日数１
		v_item.l_inItem078 := gAryBillOutTmg2Nm[1]						::varchar; -- （発行後）請求書出力タイミング２名称１
		v_item.l_inItem079 := gAryTesuShuruiNm2[2]						::varchar; -- （発行後）手数料２
		v_item.l_inItem080 := gAryKozaFuriKbnNm2[2]						::varchar; -- （発行後）口座振替区分２
		v_item.l_inItem081 := gAryKobetsuseikyuoutKbnNm[2]				::varchar; -- （発行後）個別請求書出力区分２
		v_item.l_inItem082 := gAryBillOutTmg1Nm[2]						::varchar; -- （発行後）請求書出力タイミング１名称２
		v_item.l_inItem083 := gAryBillOutDd[2]							::varchar; -- （発行後）請求書出力タイミング日数２
		v_item.l_inItem084 := gAryBillOutTmg2Nm[2]						::varchar; -- （発行後）請求書出力タイミング２名称２
		v_item.l_inItem085 := gAryTesuShuruiNm2[3]						::varchar; -- （発行後）手数料３
		v_item.l_inItem086 := gAryKozaFuriKbnNm2[3]						::varchar; -- （発行後）口座振替区分３
		v_item.l_inItem087 := gAryKobetsuseikyuoutKbnNm[3]				::varchar; -- （発行後）個別請求書出力区分３
		v_item.l_inItem088 := gAryBillOutTmg1Nm[3]						::varchar; -- （発行後）請求書出力タイミング１名称３
		v_item.l_inItem089 := gAryBillOutDd[3]							::varchar; -- （発行後）請求書出力タイミング日数３
		v_item.l_inItem090 := gAryBillOutTmg2Nm[3]						::varchar; -- （発行後）請求書出力タイミング２名称３
		v_item.l_inItem091 := gAryTesuShuruiNm2[4]						::varchar; -- （発行後）手数料４
		v_item.l_inItem092 := gAryKozaFuriKbnNm2[4]						::varchar; -- （発行後）口座振替区分４
		v_item.l_inItem093 := gAryKobetsuseikyuoutKbnNm[4]				::varchar; -- （発行後）個別請求書出力区分４
		v_item.l_inItem094 := gAryBillOutTmg1Nm[4]						::varchar; -- （発行後）請求書出力タイミング１名称４
		v_item.l_inItem095 := gAryBillOutDd[4]							::varchar; -- （発行後）請求書出力タイミング日数４
		v_item.l_inItem096 := gAryBillOutTmg2Nm[4]						::varchar; -- （発行後）請求書出力タイミング２名称４
		v_item.l_inItem097 := gAryTesuShuruiNm2[5]						::varchar; -- （発行後）手数料５
		v_item.l_inItem098 := gAryKozaFuriKbnNm2[5]						::varchar; -- （発行後）口座振替区分５
		v_item.l_inItem099 := gAryKobetsuseikyuoutKbnNm[5]				::varchar; -- （発行後）個別請求書出力区分５
		v_item.l_inItem100 := gAryBillOutTmg1Nm[5]						::varchar; -- （発行後）請求書出力タイミング１名称５
		v_item.l_inItem101 := gAryBillOutDd[5]							::varchar; -- （発行後）請求書出力タイミング日数５
		v_item.l_inItem102 := gAryBillOutTmg2Nm[5]						::varchar; -- （発行後）請求書出力タイミング２名称５
		v_item.l_inItem103 := gAryTesuShuruiNm2[6]						::varchar; -- （発行後）手数料６
		v_item.l_inItem104 := gAryKozaFuriKbnNm2[6]						::varchar; -- （発行後）口座振替区分６
		v_item.l_inItem105 := gAryKobetsuseikyuoutKbnNm[6]				::varchar; -- （発行後）個別請求書出力区分６
		v_item.l_inItem106 := gAryBillOutTmg1Nm[6]						::varchar; -- （発行後）請求書出力タイミング１名称６
		v_item.l_inItem107 := gAryBillOutDd[6]							::varchar; -- （発行後）請求書出力タイミング日数６
		v_item.l_inItem108 := gAryBillOutTmg2Nm[6]						::varchar; -- （発行後）請求書出力タイミング２名称６
		v_item.l_inItem109 := gAryTesuShuruiNm2[7]						::varchar; -- （発行後）手数料７
		v_item.l_inItem110 := gAryKozaFuriKbnNm2[7]						::varchar; -- （発行後）口座振替区分７
		v_item.l_inItem111 := gAryKobetsuseikyuoutKbnNm[7]				::varchar; -- （発行後）個別請求書出力区分７
		v_item.l_inItem112 := gAryBillOutTmg1Nm[7]						::varchar; -- （発行後）請求書出力タイミング１名称７
		v_item.l_inItem113 := gAryBillOutDd[7]							::varchar; -- （発行後）請求書出力タイミング日数７
		v_item.l_inItem114 := gAryBillOutTmg2Nm[7]						::varchar; -- （発行後）請求書出力タイミング２名称７
		v_item.l_inItem115 := gAryTesuShuruiNm2[8]						::varchar; -- （発行後）手数料８
		v_item.l_inItem116 := gAryKozaFuriKbnNm2[8]						::varchar; -- （発行後）口座振替区分８
		v_item.l_inItem117 := gAryKobetsuseikyuoutKbnNm[8]				::varchar; -- （発行後）個別請求書出力区分８
		v_item.l_inItem118 := gAryBillOutTmg1Nm[8]						::varchar; -- （発行後）請求書出力タイミング１名称８
		v_item.l_inItem119 := gAryBillOutDd[8]							::varchar; -- （発行後）請求書出力タイミング日数８
		v_item.l_inItem120 := gAryBillOutTmg2Nm[8]						::varchar; -- （発行後）請求書出力タイミング２名称８
		v_item.l_inItem121 := gAryTesuShuruiNm2[9]						::varchar; -- （発行後）手数料９
		v_item.l_inItem122 := gAryKozaFuriKbnNm2[9]						::varchar; -- （発行後）口座振替区分９
		v_item.l_inItem123 := gAryKobetsuseikyuoutKbnNm[9]				::varchar; -- （発行後）個別請求書出力区分９
		v_item.l_inItem124 := gAryBillOutTmg1Nm[9]						::varchar; -- （発行後）請求書出力タイミング１名称９
		v_item.l_inItem125 := gAryBillOutDd[9]							::varchar; -- （発行後）請求書出力タイミング日数９
		v_item.l_inItem126 := gAryBillOutTmg2Nm[9]						::varchar; -- （発行後）請求書出力タイミング２名称９
		v_item.l_inItem127 := gAryTesuShuruiNm2[10]						::varchar; -- （発行後）手数料１０
		v_item.l_inItem128 := gAryKozaFuriKbnNm2[10]						::varchar; -- （発行後）口座振替区分１０
		v_item.l_inItem129 := gAryKobetsuseikyuoutKbnNm[10]				::varchar; -- （発行後）個別請求書出力区分１０
		v_item.l_inItem130 := gAryBillOutTmg1Nm[10]						::varchar; -- （発行後）請求書出力タイミング１名称１０
		v_item.l_inItem131 := gAryBillOutDd[10]							::varchar; -- （発行後）請求書出力タイミング日数１０
		v_item.l_inItem132 := gAryBillOutTmg2Nm[10]						::varchar; -- （発行後）請求書出力タイミング２名称１０
		v_item.l_inItem133 := gAryTesuShuruiNm2[11]						::varchar; -- （発行後）手数料１１
		v_item.l_inItem134 := gAryKozaFuriKbnNm2[11]						::varchar; -- （発行後）口座振替区分１１
		v_item.l_inItem135 := gAryKobetsuseikyuoutKbnNm[11]				::varchar; -- （発行後）個別請求書出力区分１１
		v_item.l_inItem136 := gAryBillOutTmg1Nm[11]						::varchar; -- （発行後）請求書出力タイミング１名称１１
		v_item.l_inItem137 := gAryBillOutDd[11]							::varchar; -- （発行後）請求書出力タイミング日数１１
		v_item.l_inItem138 := gAryBillOutTmg2Nm[11]						::varchar; -- （発行後）請求書出力タイミング２名称１１
		v_item.l_inItem139 := gAryTesuShuruiNm2[12]						::varchar; -- （発行後）手数料１２
		v_item.l_inItem140 := gAryKozaFuriKbnNm2[12]						::varchar; -- （発行後）口座振替区分１２
		v_item.l_inItem141 := gAryKobetsuseikyuoutKbnNm[12]				::varchar; -- （発行後）個別請求書出力区分１２
		v_item.l_inItem142 := gAryBillOutTmg1Nm[12]						::varchar; -- （発行後）請求書出力タイミング１名称１２
		v_item.l_inItem143 := gAryBillOutDd[12]							::varchar; -- （発行後）請求書出力タイミング日数１２
		v_item.l_inItem144 := gAryBillOutTmg2Nm[12]						::varchar; -- （発行後）請求書出力タイミング２名称１２
		v_item.l_inItem145 := gAryTesuShuruiNm2[13]						::varchar; -- （発行後）手数料１３
		v_item.l_inItem146 := gAryKozaFuriKbnNm2[13]						::varchar; -- （発行後）口座振替区分１３
		v_item.l_inItem147 := gAryKobetsuseikyuoutKbnNm[13]				::varchar; -- （発行後）個別請求書出力区分１３
		v_item.l_inItem148 := gAryBillOutTmg1Nm[13]						::varchar; -- （発行後）請求書出力タイミング１名称１３
		v_item.l_inItem149 := gAryBillOutDd[13]							::varchar; -- （発行後）請求書出力タイミング日数１３
		v_item.l_inItem150 := gAryBillOutTmg2Nm[13]						::varchar; -- （発行後）請求書出力タイミング２名称１３
		v_item.l_inItem151 := gAryTesuShuruiNm2[14]						::varchar; -- （発行後）手数料１４
		v_item.l_inItem152 := gAryKozaFuriKbnNm2[14]						::varchar; -- （発行後）口座振替区分１４
		v_item.l_inItem153 := gAryKobetsuseikyuoutKbnNm[14]				::varchar; -- （発行後）個別請求書出力区分１４
		v_item.l_inItem154 := gAryBillOutTmg1Nm[14]						::varchar; -- （発行後）請求書出力タイミング１名称１４
		v_item.l_inItem155 := gAryBillOutDd[14]							::varchar; -- （発行後）請求書出力タイミング日数１４
		v_item.l_inItem156 := gAryBillOutTmg2Nm[14]						::varchar; -- （発行後）請求書出力タイミング２名称１４
		v_item.l_inItem157 := gAryTesuShuruiNm2[15]						::varchar; -- （発行後）手数料１５
		v_item.l_inItem158 := gAryKozaFuriKbnNm2[15]						::varchar; -- （発行後）口座振替区分１５
		v_item.l_inItem159 := gAryKobetsuseikyuoutKbnNm[15]				::varchar; -- （発行後）個別請求書出力区分１５
		v_item.l_inItem160 := gAryBillOutTmg1Nm[15]						::varchar; -- （発行後）請求書出力タイミング１名称１５
		v_item.l_inItem161 := gAryBillOutDd[15]							::varchar; -- （発行後）請求書出力タイミング日数１５
		v_item.l_inItem162 := gAryBillOutTmg2Nm[15]						::varchar; -- （発行後）請求書出力タイミング２名称１５
		v_item.l_inItem163 := gItakuKaishaRnm 								::varchar; -- 委託会社略称
		v_item.l_inItem164 := REPORT_ID 									::varchar; -- 帳票ＩＤ
		v_item.l_inItem165 := FMT_HAKKO_KNGK_J 							::varchar; -- 発行金額書式フォーマット
		v_item.l_inItem166 := FMT_RBR_KNGK_J 								::varchar; -- 利払金額書式フォーマット
		v_item.l_inItem167 := FMT_SHOKAN_KNGK_J 							::varchar; -- 償還金額書式フォーマット
		v_item.l_inItem169 := recWkMeisai.SHONIN_STAT_NM 					::varchar; -- 承認ステータス名称
		v_item.l_inItem171 := gAryChooseFlgNm1[1]							::varchar; -- （発行時）選択フラグ内容１
		v_item.l_inItem172 := gAryChooseFlgNm1[2]							::varchar; -- （発行時）選択フラグ内容２
		v_item.l_inItem173 := gAryChooseFlgNm1[3]							::varchar; -- （発行時）選択フラグ内容３
		v_item.l_inItem174 := gAryChooseFlgNm1[4]							::varchar; -- （発行時）選択フラグ内容４
		v_item.l_inItem175 := gAryChooseFlgNm1[5]							::varchar; -- （発行時）選択フラグ内容５
		v_item.l_inItem176 := gAryChooseFlgNm1[6]							::varchar; -- （発行時）選択フラグ内容６
		v_item.l_inItem177 := gAryChooseFlgNm1[7]							::varchar; -- （発行時）選択フラグ内容７
		v_item.l_inItem178 := gAryChooseFlgNm1[8]							::varchar; -- （発行時）選択フラグ内容８
		v_item.l_inItem179 := gAryChooseFlgNm1[9]							::varchar; -- （発行時）選択フラグ内容９
		v_item.l_inItem180 := gAryChooseFlgNm1[10]						::varchar; -- （発行時）選択フラグ内容１０
		v_item.l_inItem181 := gAryChooseFlgNm1[11]						::varchar; -- （発行時）選択フラグ内容１１
		v_item.l_inItem182 := gAryChooseFlgNm1[12]						::varchar; -- （発行時）選択フラグ内容１２
		v_item.l_inItem183 := gAryChooseFlgNm1[13]						::varchar; -- （発行時）選択フラグ内容１３
		v_item.l_inItem184 := gAryChooseFlgNm1[14]						::varchar; -- （発行時）選択フラグ内容１４
		v_item.l_inItem185 := gAryChooseFlgNm1[15]						::varchar; -- （発行時）選択フラグ内容１５
		v_item.l_inItem186 := gAryChooseFlgNm2[1]							::varchar; -- （発行後）選択フラグ内容１
		v_item.l_inItem187 := gAryChooseFlgNm2[2]							::varchar; -- （発行後）選択フラグ内容２
		v_item.l_inItem188 := gAryChooseFlgNm2[3]							::varchar; -- （発行後）選択フラグ内容３
		v_item.l_inItem189 := gAryChooseFlgNm2[4]							::varchar; -- （発行後）選択フラグ内容４
		v_item.l_inItem190 := gAryChooseFlgNm2[5]							::varchar; -- （発行後）選択フラグ内容５
		v_item.l_inItem191 := gAryChooseFlgNm2[6]							::varchar; -- （発行後）選択フラグ内容６
		v_item.l_inItem192 := gAryChooseFlgNm2[7]							::varchar; -- （発行後）選択フラグ内容７
		v_item.l_inItem193 := gAryChooseFlgNm2[8]							::varchar; -- （発行後）選択フラグ内容８
		v_item.l_inItem194 := gAryChooseFlgNm2[9]							::varchar; -- （発行後）選択フラグ内容９
		v_item.l_inItem195 := gAryChooseFlgNm2[10]						::varchar; -- （発行後）選択フラグ内容１０
		v_item.l_inItem196 := gAryChooseFlgNm2[11]						::varchar; -- （発行後）選択フラグ内容１１
		v_item.l_inItem197 := gAryChooseFlgNm2[12]						::varchar; -- （発行後）選択フラグ内容１２
		v_item.l_inItem198 := gAryChooseFlgNm2[13]						::varchar; -- （発行後）選択フラグ内容１３
		v_item.l_inItem199 := gAryChooseFlgNm2[14]						::varchar; -- （発行後）選択フラグ内容１４
		v_item.l_inItem200 := gAryChooseFlgNm2[15]						::varchar; -- （発行後）選択フラグ内容１５
		v_item.l_inItem201 := gAryKonaiTesuNm1[1]						::varchar; -- （発行時）行内手数料１
		v_item.l_inItem202 := gAryKonaiTesuNm1[2]						::varchar; -- （発行時）行内手数料２
		v_item.l_inItem203 := gAryKonaiTesuNm1[3]						::varchar; -- （発行時）行内手数料３
		v_item.l_inItem204 := gAryKonaiTesuNm1[4]						::varchar; -- （発行時）行内手数料４
		v_item.l_inItem205 := gAryKonaiTesuNm1[5]						::varchar; -- （発行時）行内手数料５
		v_item.l_inItem206 := gAryKonaiTesuNm1[6]						::varchar; -- （発行時）行内手数料６
		v_item.l_inItem207 := gAryKonaiTesuNm1[7]						::varchar; -- （発行時）行内手数料７
		v_item.l_inItem208 := gAryKonaiTesuNm1[8]						::varchar; -- （発行時）行内手数料８
		v_item.l_inItem209 := gAryKonaiTesuNm1[9]						::varchar; -- （発行時）行内手数料９
		v_item.l_inItem210 := gAryKonaiTesuNm1[10]						::varchar; -- （発行時）行内手数料１０
		v_item.l_inItem211 := gAryKonaiTesuNm1[11]						::varchar; -- （発行時）行内手数料１１
		v_item.l_inItem212 := gAryKonaiTesuNm1[12]						::varchar; -- （発行時）行内手数料１２
		v_item.l_inItem213 := gAryKonaiTesuNm1[13]						::varchar; -- （発行時）行内手数料１３
		v_item.l_inItem214 := gAryKonaiTesuNm1[14]						::varchar; -- （発行時）行内手数料１４
		v_item.l_inItem215 := gAryKonaiTesuNm1[15]						::varchar; -- （発行時）行内手数料１５
		v_item.l_inItem216 := gAryKonaiTesuNm2[1]						::varchar; -- （発行後）行内手数料１
		v_item.l_inItem217 := gAryKonaiTesuNm2[2]						::varchar; -- （発行後）行内手数料２
		v_item.l_inItem218 := gAryKonaiTesuNm2[3]						::varchar; -- （発行後）行内手数料３
		v_item.l_inItem219 := gAryKonaiTesuNm2[4]						::varchar; -- （発行後）行内手数料４
		v_item.l_inItem220 := gAryKonaiTesuNm2[5]						::varchar; -- （発行後）行内手数料５
		v_item.l_inItem221 := gAryKonaiTesuNm2[6]						::varchar; -- （発行後）行内手数料６
		v_item.l_inItem222 := gAryKonaiTesuNm2[7]						::varchar; -- （発行後）行内手数料７
		v_item.l_inItem223 := gAryKonaiTesuNm2[8]						::varchar; -- （発行後）行内手数料８
		v_item.l_inItem224 := gAryKonaiTesuNm2[9]						::varchar; -- （発行後）行内手数料９
		v_item.l_inItem225 := gAryKonaiTesuNm2[10]						::varchar; -- （発行後）行内手数料１０
		v_item.l_inItem226 := gAryKonaiTesuNm2[11]						::varchar; -- （発行後）行内手数料１１
CALL pkPrint.insertData(
			l_inKeyCd			=>	l_inItakuKaishaCd 							-- 識別コード
			,l_inUserId			=>	l_inUserId 									-- ユーザＩＤ
			,l_inChohyoKbn		=>	l_inChohyoKbn 								-- 帳票区分
			,l_inSakuseiYmd		=>	l_inGyomuYmd 								-- 作成年月日
			,l_inChohyoId		=>	REPORT_ID 									-- 帳票ＩＤ
			,l_inSeqNo			=>	1											-- 連番
			,l_inHeaderFlg		=>	'1'											-- ヘッダフラグ
			,l_inItem			=>	v_item											-- Composite type
			,l_inKousinId		=>	l_inUserId 									-- 更新者ID
			,l_inSakuseiId		=>	l_inUserId 									-- 作成者ID
		);
	ELSE
	-- 対象データなし
				v_item := ROW();
		v_item.l_inItem001 := l_inUserId 									::varchar; -- ユーザＩＤ
		v_item.l_inItem164 := REPORT_ID 									::varchar; -- 帳票ID
		v_item.l_inItem168 := '対象データなし'							::varchar; -- 対象データなし
CALL pkPrint.insertData(
			l_inKeyCd			=>	l_inItakuKaishaCd 							-- 識別コード
			,l_inUserId			=>	l_inUserId 									-- ユーザＩＤ
			,l_inChohyoKbn		=>	l_inChohyoKbn 								-- 帳票区分
			,l_inSakuseiYmd		=>	l_inGyomuYmd 								-- 作成年月日
			,l_inChohyoId		=>	REPORT_ID 									-- 帳票ＩＤ
			,l_inSeqNo			=>	1											-- 連番
			,l_inHeaderFlg		=>	'1'											-- ヘッダフラグ
			,l_inItem			=>	v_item											-- Composite type
			,l_inKousinId		=>	l_inUserId 									-- 更新者ID
			,l_inSakuseiId		=>	l_inUserId 									-- 作成者ID
		);
		gRtnCd := RTN_NODATA;
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPW001K00R04 END');	END IF;
-- エラー処理
-- EXCEPTION
-- 	WHEN	OTHERS	THEN
-- 		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLCODE:'||SQLSTATE);
-- 		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLERRM:'||SQLERRM);
-- 		l_outSqlCode := RTN_FATAL;
-- 		l_outSqlErrM := SQLERRM;
--		RAISE;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipw001k00r04 ( l_inMgrCd TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;