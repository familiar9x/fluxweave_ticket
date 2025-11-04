



DROP TYPE IF EXISTS spiph004k00r01_type_record CASCADE;
CREATE TYPE spiph004k00r01_type_record AS (
			 gHktCd					char(6)					-- 発行体コード
			,gKaikeiKbn				char(2)			-- 会計区分
			,gKaikeiKbnNm			varchar(40)			-- 会計区分名称
			,gTokijoYakushokuNm		varchar(50)		-- 登記上役職名称
			,gTokijoDelegateNm		varchar(50)		-- 登記上代表者名称
			,gInvoiceTourokuNo		varchar(13) 		-- 適格請求書発行事業者登録番号
			,gAdd2x1				varchar(50) 					-- 住所２−１
			,gAdd2x2				varchar(50) 					-- 住所２−２
			,gAdd2x3				varchar(50) 					-- 住所２−３
			,gBankNm				varchar(50) 				-- 銀行名称
			,gDelegateNm			varchar(102)							-- 代表者名称
			,gIsinCd				char(12)					-- ISINコード
			,gMgrCd					varchar(13)					-- 銘柄コード
			,gMgrNm					varchar(400)					-- 銘柄の正式名称
			,gChokyuYmd				char(8)			-- 支払日
			,gButenNm				varchar(50)					-- 担当部署名称
			,gThikokozaPrintFlg		char(1) 	-- 地公体請求書顧客口座出力フラグ
			,gKozaNm				varchar(40)						-- 口座科目名称
			,gKozaNo				varchar(14)							-- 口座番号
			,gKozameigininKanaNm	varchar(60)		-- 口座名義人(カナ)
			,gTesuryoKngk			numeric(14)								-- 手数料金額(税抜)
			,gSzeiSeikyuKbn			char(1)	-- 消費税請求区分
			,gHakkoYmd				char(8)				-- 発行年月日
			,gHakkoTsukaCd			char(3)			-- 発行通貨
	);


CREATE OR REPLACE PROCEDURE spiph004k00r01 ( l_inHktCd CHAR,		-- 発行体コード
 l_inKozaTenCd CHAR,		-- 口座店コード
 l_inKozaTenCifCd CHAR,		-- 口座店CIFコード
 l_inMgrCd CHAR,		-- 銘柄コード
 l_inIsinCd CHAR,		-- ISINコード
 l_inKijyunYmdF CHAR,		-- 基準日(FROM)
 l_inKijyunYmdT CHAR,		-- 基準日(TO)
 l_inTuchiYmd CHAR,		-- 通知日
 l_inItakuKaishaCd CHAR,		-- 委託会社コード
 l_inUserId text,	-- ユーザーID
 l_inChohyoKbn CHAR,		-- 帳票区分
 l_inGyomuYmd CHAR,		-- 業務日付
--	l_inStRecKbn		IN	CHAR,		-- 初回レコード区分
 l_outSqlCode OUT numeric,		-- リターン値
 l_outSqlErrM OUT CHAR 		-- エラーコメント
 ) AS $body$
DECLARE

--
--/* 著作権:Copyright(c)2004
--/* 会社名:JIP
--/* 概要　:顧客宛帳票出力指示画面の入力条件により、手数料請求書（会計区分別）を作成する。
--/* 引数　:	l_inHktCd			IN	CHAR		発行体コード
--/*			l_inKozaTenCd		IN	CHAR		口座店コード
--/*			l_inKozaTenCifCd	IN	CHAR		口座店CIFコード
--/*			l_inMgrCd			IN	CHAR		銘柄コード
--/*			l_inIsinCd			IN	CHAR		ISINコード
--/*			l_inKijyunYmdF		IN	CHAR		基準日(FROM)
--/*			l_inKijyunYmdT		IN	CHAR		基準日(TO)
--/*			l_inTuchiYmd		IN	CHAR		通知日
--/*			l_inItakuKaishaCd	IN	CHAR		委託会社コード
--/*			l_inUserId			IN	CHAR		ユーザーID
--/*			l_inChohyoKbn		IN	CHAR		帳票区分
--/*			l_inGyomuYmd		IN	CHAR		業務日付
--/*			l_outSqlCode		OUT	INTEGER		リターン値
--/*			l_outSqlErrM		OUT	VARCHAR2	エラーコメント
--/* 返り値:なし
-- * @version $Id: SPIPH004K00R01.SQL,v 1.14 2023/07/25 05:57:03 kentaro_ikeda Exp $
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.05.XX	JIP				新規作成
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
	RTN_OK				CONSTANT integer	:= 0;					-- 正常
	RTN_NG				CONSTANT integer	:= 1;					-- 予期したエラー
	RTN_NODATA			CONSTANT integer	:= 2;					-- データなし
	RTN_FATAL			CONSTANT integer	:= 99;					-- 予期せぬエラー
	REPORT_ID			CONSTANT char(11)	:= 'IPH30000411';		-- 帳票ID
	-- 書式フォーマット
	FMT_HAKKO_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	FMT_RBR_KNGK_J		CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 利払金額
	FMT_SHOKAN_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 償還金額
	ST_REC_KBN_FIRST	CONSTANT char(1)	:= '1';						-- 初回レコード区分（初回）
	TSUCHI_YMD_DEF      CONSTANT char(16)  := '      年  月  日';		-- 通知日（デフォルト）
--==============================================================================
--					変数定義													
--==============================================================================
	gRtnCd				integer :=	RTN_OK;						-- リターンコード
	gSeqNo				integer := 0;							-- シーケンス
--	gLopNo					INTEGER DEFAULT 0;						-- ループ番号
	gSeqNoIni			integer := 0;							-- シーケンス
	gSQL				varchar(4500) := NULL;				-- SQL編集
	-- DB取得項目
	-- 配列定義
	recMeisai spiph004k00r01_type_record[];
	-- 西暦変換用
	gWrkStTuchiYmd		varchar(20) := NULL;					-- 通知日
	gWrkStSiharaiYmd	varchar(20) := NULL;					-- 支払日
	-- 宛名編集用
	gTokiDelegateNm		varchar(50) := NULL;					-- 登記上代表者名称
	-- 地公体請求書顧客口座出力フラグ判断用
	gWrkHouhou			varchar(8)		:= NULL;				-- 送金方法
	gWrkShurui			varchar(8)		:= NULL;				-- 種類
	gWrkKozaNo			varchar(14)	:= NULL;				-- 口座番号
	gWrkKozaNinNm		varchar(60)	:= NULL;				-- 口座名義人(カナ)
	gWrkMgrNm			varchar(400)	:= NULL;				-- 銘柄の正式名称
	gWrkTesuryoNm		varchar(50)	:= NULL;				-- ただし・・・項目名称
	-- カーソル
	curMeisai REFCURSOR;
	-- インボイス用
	gTesuryoSzei			numeric(10);								-- うち消費税相当額
	gSzeiRate				numeric(2);								-- 適格請求書_消費税率
	gInvoiceTesuLabel		varchar(20);
	-- Temp record for cursor
	tempRec spiph004k00r01_type_record;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPH004K00R01 START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inKijyunYmdF)::text, '') = ''					-- 基準日(FROM)
	OR coalesce(trim(both l_inKijyunYmdT)::text, '') = ''					-- 基準日(TO)
	OR coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''				-- 委託会社コード
	OR coalesce(trim(both l_inUserId)::text, '') = ''						-- ユーザID
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''					-- 帳票区分
	OR coalesce(trim(both l_inGyomuYmd)::text, '') = ''					-- 業務日付
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error(l_inUserId, REPORT_ID, 'SQLERRM:'||'');
		RETURN;
	END IF;
--	IF l_inStRecKbn = ST_REC_KBN_FIRST THEN
		-- 初回レコードの場合、帳票ワークの削除
		DELETE FROM SREPORT_WK
		WHERE	KEY_CD = l_inItakuKaishaCd
		AND		USER_ID = l_inUserId
		AND		CHOHYO_KBN = l_inChohyoKbn
		AND		SAKUSEI_YMD = l_inGyomuYmd
		AND		CHOHYO_ID = REPORT_ID;
		-- ヘッダレコードを追加
		CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
--
--	ELSE
--		-- 帳票ワークから「対象データなし」レコードを削除
--		DELETE FROM SREPORT_WK
--		WHERE	KEY_CD = l_inItakuKaishaCd
--		AND		USER_ID = l_inUserId
--		AND		CHOHYO_KBN = l_inChohyoKbn
--		AND		SAKUSEI_YMD = l_inGyomuYmd
--		AND		CHOHYO_ID = REPORT_ID
--		AND 	ITEM026 = '対象データなし';
--	END IF;
--
	-- 連番取得
	SELECT	coalesce(MAX(SEQ_NO), 0)
	INTO STRICT	gSeqNoIni
	FROM	SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;
	--gSeqNo := gSeqNoIni;
	-- SQL編集
	CALL spiph004k00r01_createsql(
		l_inItakuKaishaCd,
		l_inMgrCd,
		l_inKijyunYmdF,
		l_inKijyunYmdT,
		l_inHktCd,
		l_inKozaTenCd,
		l_inKozaTenCifCd,
		l_inIsinCd,
		gSQL
	);
--	TEST_DEBUG_LOG('SPIPH004K00R01',gSQL);  -- SQL LOG
	-- カーソルオープン
	OPEN curMeisai FOR EXECUTE gSQL;
	-- データ取得
	LOOP
		FETCH curMeisai INTO tempRec;
		EXIT WHEN NOT FOUND;
		
		recMeisai := array_append(recMeisai, tempRec);
		gSeqNo := coalesce(cardinality(recMeisai), 0);
	END LOOP;
	CLOSE curMeisai;
	
	IF gSeqNo = 0 THEN
		-- 対象データなし
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'no data');	END IF;
		CALL pkPrint.insertDetailEmpty(
				 l_inKeycd			=>	l_inItakuKaishaCd 						-- キーコード
				,l_inUserid			=>	l_inUserId 								-- ユーザーID
				,l_inChohyokbn		=>	l_inChohyoKbn 							-- 帳票区分
				,l_inSakuseiymd		=>	l_inGyomuYmd 							-- 作成年月日
				,l_inChohyoid		=>	REPORT_ID 								-- 帳票ID
				,l_inHeaderflg		=>	'1'										-- ヘッダフラグ
				,l_inKousinid		=>	l_inUserId 								-- 更新者ID
				,l_inSakuseiid		=>	l_inUserId 								-- 作成者ID
			);
	ELSE
		-- データ有り
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'has data');	END IF;
		-- インボイス項目の編集
		-- 適格請求書_消費税率
		gSzeiRate := pkInvoice.getInvoiceSzeiRate(recMeisai[1].gHakkoYmd);
		-- 適格請求書発行事業者登録番号がNULLの場合の手数料ラベル
		gInvoiceTesuLabel := '手数料';
		IF recMeisai[1].gInvoiceTourokuNo IS NOT NULL THEN
			gInvoiceTesuLabel := '(10%対象)手数料(税抜)';
		END IF;
		
		FOR i IN 1..coalesce(cardinality(recMeisai), 0) LOOP
			gSeqNo := gSeqNoIni + i;
			-- 西暦変換
			IF coalesce(trim(both l_inTuchiYmd)::text, '') = '' THEN
				gWrkStTuchiYmd := TSUCHI_YMD_DEF;
			ELSE
				gWrkStTuchiYmd := pkDate.getWarekiYmd(l_inTuchiYmd, '2');
			END IF;
			gWrkStSiharaiYmd := pkDate.getWarekiYmd(recMeisai[i].gChokyuYmd, '2');
			-- 発行体マスタ．登記上代表者名称の「殿」を削除
			gTokiDelegateNm := REPLACE(recMeisai[i].gTokijoDelegateNm, '殿', '');
			-- 地公体請求書顧客口座出力フラグ判断
			IF recMeisai[i].gThikokozaPrintFlg = '0' THEN
				gWrkHouhou		:= NULL;
				gWrkShurui		:= NULL;
				gWrkKozaNo		:= NULL;
				gWrkKozaNinNm	:= NULL;
			ELSE
				gWrkHouhou		:= '送金方法';
				gWrkShurui		:= '種類';
				gWrkKozaNo		:= recMeisai[i].gKozaNo;
				gWrkKozaNinNm	:= recMeisai[i].gKozameigininKanaNm;
			END IF;
			-- 銘柄名称の判断
			IF recMeisai[i].gHakkoTsukaCd <> 'JPY' THEN
				gWrkMgrNm	:= recMeisai[i].gMgrNm;
			ELSE
				gWrkMgrNm	:= NULL;
			END IF;
			-- 手数料の種類判断
			IF spiph004k00r01_getkaikeitesuryocount(l_inItakuKaishaCd, recMeisai[i].gMgrCd) > 0 THEN
				gWrkTesuryoNm := 'ただし、発行に係る事務取扱手数料';
			ELSIF spiph004k00r01_getshinkitesuryocount(l_inItakuKaishaCd, recMeisai[i].gMgrCd) > 0 THEN
				gWrkTesuryoNm := 'ただし、登録に係る事務取扱手数料';
			ELSE
				gWrkTesuryoNm := 'ただし、元利金支払に係る事務取扱手数料';
			END IF;
			-- インボイス項目の編集
			-- うち消費税相当額
			IF recMeisai[i].gSzeiSeikyuKbn = '1' THEN
				gTesuryoSzei := pkInvoice.calcInvoiceSzei(recMeisai[i].gTesuryoKngk, recMeisai[i].gHakkoYmd);
			ELSE
				gTesuryoSzei := 0;
			END IF;
			-- 帳票ワーク追加
				CALL pkPrint.insertDetail(
					 l_inKeycd			=>	l_inItakuKaishaCd 						-- キーコード
					,l_inUserid			=>	l_inUserId 								-- ユーザーID
					,l_inChohyokbn		=>	l_inChohyoKbn 							-- 帳票区分
					,l_inSakuseiymd		=>	l_inGyomuYmd 							-- 作成年月日
					,l_inChohyoid		=>	REPORT_ID 								-- 帳票ID
					,l_inSeqno			=>	gSeqNo									-- 連番
					,l_inHeaderFlg		=>	'1'									-- ヘッダフラグ
					,l_inItem001		=>	gWrkStTuchiYmd 						-- 通知日
					,l_inItem002		=>	recMeisai[i].gHktCd 					-- 発行体コード
					,l_inItem003		=>	recMeisai[i].gKaikeiKbn 				-- 会計区分
					,l_inItem004		=>	recMeisai[i].gKaikeiKbnNm 			-- 会計区分名称
					,l_inItem005		=>	recMeisai[i].gTokijoYakushokuNm 		-- 登記上役職名称
					,l_inItem006		=>	recMeisai[i].gTokijoDelegateNm 		-- 登記上代表者名称 2005/08/22 殿を削除
					,l_inItem007		=>	recMeisai[i].gAdd2x1				-- 住所２−１
					,l_inItem008		=>	recMeisai[i].gAdd2x2				-- 住所２−２
					,l_inItem009		=>	recMeisai[i].gAdd2x3				-- 住所２−３
					,l_inItem010		=>	recMeisai[i].gBankNm 				-- 銀行名称
					,l_inItem011		=>	recMeisai[i].gDelegateNm 			-- 代表者名称
					,l_inItem012		=>	recMeisai[i].gThikokozaPrintFlg 		-- 地公体請求書顧客口座出力フラグ
					,l_inItem013		=>	recMeisai[i].gMgrNm 					-- 銘柄の正式名称
					,l_inItem014		=>	'金' || trim(both TO_CHAR(recMeisai[i].gTesuryoKngk,'99,999,999,999,999')) 			-- 手数料金額(税抜)
					,l_inItem015		=>	gTesuryoSzei 						-- うち消費税相当額
					,l_inItem016		=>	gWrkStSiharaiYmd 					-- 支払日
					,l_inItem017		=>	spiph004k00r01_createbun(REPORT_ID)				-- 表示文言
					,l_inItem018		=>	gWrkHouhou 							-- 送金方法
					,l_inItem019		=>	gWrkShurui 							-- 種類
					,l_inItem020		=>	gWrkKozaNo 							-- 口座番号
					,l_inItem021		=>	gWrkKozaNinNm 						-- 口座名義人(カナ)
					,l_inItem022		=>	gWrkMgrNm 							-- 銘柄の正式名称
					,l_inItem023		=>	FMT_HAKKO_KNGK_J 					-- 発行金額書式フォーマット
					,l_inItem024		=>	FMT_RBR_KNGK_J 						-- 利払金額書式フォーマット
					,l_inItem025		=>	FMT_SHOKAN_KNGK_J 					-- 償還金額書式フォーマット
					,l_inItem027		=>	gWrkTesuryoNm 					-- 手数料種類名称
					,l_inItem028		=>	recMeisai[i].gInvoiceTourokuNo 		-- 適格請求書発行事業者登録番号
					,l_inItem029 		=>	gInvoiceTesuLabel 					-- 適格請求書_手数料ラベル
					,l_inItem030		=>	recMeisai[i].gTesuryoKngk 			-- 手数料金額(ジャーナル)
					,l_inItem031		=>	recMeisai[i].gHakkoYmd 				-- 消費税基準日(ジャーナル)
					,l_inItem032 		=>	gSzeiRate 							-- 消費税率(ジャーナル)
					,l_inItem033		=>	recMeisai[i].gTokijoYakushokuNm 		-- 登記上役職名称(ジャーナル)
					,l_inItem034		=>	gTokiDelegateNm 						-- 登記上代表者名称(ジャーナル)
					,l_inKousinId		=>	l_inUserId 							-- 更新者ID
					,l_inSakuseiId		=>	l_inUserId 							-- 作成者ID
				);
			END LOOP;
		-- CSVジャーナルINSERT  
		l_outSqlCode := pkCsvJournal.insertData(
							 l_inItakuKaishaCd 			-- 委託会社コード
							,l_inUserId 					-- ユーザＩＤ
							,l_inChohyoKbn 				-- 帳票区分
							,l_inGyomuYmd 				-- 処理日付
							,REPORT_ID 					-- 帳票ＩＤ
						);
	END IF;
	-- 終了処理
	l_outSqlCode := RTN_OK;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPH004K00R01 END');	END IF;
	-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spiph004k00r01 ( l_inHktCd CHAR, l_inKozaTenCd CHAR, l_inKozaTenCifCd CHAR, l_inMgrCd CHAR, l_inIsinCd CHAR, l_inKijyunYmdF CHAR, l_inKijyunYmdT CHAR, l_inTuchiYmd CHAR, l_inItakuKaishaCd CHAR, l_inUserId text, l_inChohyoKbn CHAR, l_inGyomuYmd CHAR, l_outSqlCode OUT numeric, l_outSqlErrM OUT CHAR  ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spiph004k00r01_createbun (l_in_ReportID CHAR ) RETURNS varchar AS $body$
DECLARE

	patternCd	char(2) := '20';	-- パターンコード
	aryBun		varchar[];		-- 請求文章(ワーク)
	bunsyo		varchar(100);
BEGIN
	-- 請求文章の取得
	aryBun := pkIpaBun.getBun(l_in_ReportID, patternCd);
	FOR i IN 1..coalesce(cardinality(aryBun), 0) LOOP
		IF i <> 1 THEN
			bunsyo := aryBun[i];
			aryBun[i] := NULL;
		ELSE
			bunsyo := aryBun[i];
			aryBun[i] := NULL;
		END IF;
	END LOOP;
	RETURN bunsyo;
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spiph004k00r01_createbun (l_in_ReportID CHAR ) FROM PUBLIC;




CREATE OR REPLACE PROCEDURE spiph004k00r01_createsql (
	l_inItakuKaishaCd CHAR,
	l_inMgrCd CHAR,
	l_inKijyunYmdF CHAR,
	l_inKijyunYmdT CHAR,
	l_inHktCd CHAR,
	l_inKozaTenCd CHAR,
	l_inKozaTenCifCd CHAR,
	l_inIsinCd CHAR,
	INOUT gSQL varchar
) AS $body$
BEGIN
	gSQL := '';
	gSQL := gSQL || ' SELECT';
	gSQL := gSQL || ' 	 M01.HKT_CD';
	gSQL := gSQL || ' 	,WT1.KAIKEI_KBN';
	gSQL := gSQL || ' 	,WT1.KAIKEI_KBN_NM';
	gSQL := gSQL || ' 	,M01.TOKIJO_YAKUSHOKU_NM';
	gSQL := gSQL || ' 	,M01.TOKIJO_DELEGATE_NM';
	gSQL := gSQL || ' 	,VJ1.INVOICE_TOUROKU_NO';
	gSQL := gSQL || ' 	,VJ1.Add2x1';
	gSQL := gSQL || ' 	,VJ1.Add2x2';
	gSQL := gSQL || ' 	,VJ1.Add2x3';
	gSQL := gSQL || ' 	,VJ1.BANK_NM';
	gSQL := gSQL || ' 	,(VJ1.YAKUSHOKU_NM2 || ''　'' || VJ1.DELEGATE_NM2) AS DELEGATE_NM';
	gSQL := gSQL || ' 	,VMG1.ISIN_CD';
	gSQL := gSQL || ' 	,VMG1.MGR_CD';
	gSQL := gSQL || ' 	,VMG1.MGR_NM';
	gSQL := gSQL || ' 	,WT1.CHOKYU_YMD';
	gSQL := gSQL || ' 	,M04.BUTEN_NM';
	gSQL := gSQL || ' 	,VJ1.CHIKOKOZA_PRINT_FLG';
	gSQL := gSQL || ' 	,MCD1.CODE_NM AS KOZA_NM';									-- 口座科目名称
	gSQL := gSQL || ' 	,oracle.to_multi_byte(S06.KOZA_NO)';					-- 口座番号
	gSQL := gSQL || ' 	,S06.KOZAMEIGININ_NM';							-- 口座名義人
	gSQL := gSQL || ' 	,coalesce(WT1.TESURYO_GK,0) AS TESURYO_GK';			-- 手数料金額(税抜)
	gSQL := gSQL || ' 	,MG8.SZEI_SEIKYU_KBN';
	gSQL := gSQL || ' 	,VMG1.HAKKO_YMD';
	gSQL := gSQL || ' 	,VMG1.HAKKO_TSUKA_CD';
	gSQL := gSQL || ' FROM';
	gSQL := gSQL || ' 	 MGR_TESURYO_CTL 	MG7';						-- 銘柄_手数料（制御情報）
	gSQL := gSQL || ' 	,MGR_TESURYO_PRM 	MG8';						-- 銘柄_手数料（計算情報）
	gSQL := gSQL || ' 	,MGR_KIHON_VIEW		VMG1';						-- 銘柄_基本VIEW
	gSQL := gSQL || ' 	,(	SELECT ';					-- 会計区分関連を取得するサブクエリ
	gSQL := gSQL || ' 			 H03.ITAKU_KAISHA_CD';
	gSQL := gSQL || ' 			,H03.MGR_CD';
	gSQL := gSQL || ' 			,H03.KAIKEI_KBN';
	gSQL := gSQL || ' 			,H01.KAIKEI_KBN_NM';
	gSQL := gSQL || ' 			,H03.CHOKYU_YMD';
	gSQL := gSQL || ' 			,SUM(H03.ANBUN_TESU_KNGK_KOMI) AS TESURYO_GK';
	gSQL := gSQL || ' 		FROM';
	gSQL := gSQL || ' 			 KAIKEI_KBN			H01';			-- 会計区分マスタ
	gSQL := gSQL || ' 			,TESURYO_KAIKEI		H03';			-- 手数料計算結果（会計区分別）
	gSQL := gSQL || ' 			,MGR_KIHON_VIEW		VMG1';			-- 銘柄_基本VIEW
	gSQL := gSQL || ' 		WHERE';
	gSQL := gSQL || ' 				H03.ITAKU_KAISHA_CD		= ''' || l_inItakuKaishaCd || '''';
	IF (trim(both l_inMgrCd) IS NOT NULL AND (trim(both l_inMgrCd))::text <> '') THEN
		gSQL := gSQL || '		AND H03.MGR_CD				= ''' || l_inMgrCd || '''';
	END IF;
	gSQL := gSQL || ' 			AND	(H03.TESU_SHURUI_CD		= ''01'' ';
	gSQL := gSQL || ' 			OR	H03.TESU_SHURUI_CD		= ''31'' ';
	gSQL := gSQL || ' 			OR	H03.TESU_SHURUI_CD		= ''32'' ';     -- 幹事手数料条件追加2005/12/08
	gSQL := gSQL || ' 			OR	H03.TESU_SHURUI_CD		= ''51'')';     -- 新規記録手数料条件追加2006/5/18
	gSQL := gSQL || ' 			AND	(H03.CHOKYU_YMD BETWEEN ''' || l_inKijyunYmdF || ''' AND ''' || l_inKijyunYmdT || ''')';
	gSQL := gSQL || ' 			AND	VMG1.ITAKU_KAISHA_CD 	= H03.ITAKU_KAISHA_CD';
	gSQL := gSQL || ' 			AND	VMG1.MGR_CD 			= H03.MGR_CD';
								-- 会計按分テーブルの承認済み銘柄のみ抽出対象にする
	gSQL := gSQL || '			AND	PKIPAKKNIDO.GETKAIKEIANBUNCOUNT(VMG1.ITAKU_KAISHA_CD , VMG1.MGR_CD) > 0 ';
	gSQL := gSQL || ' 			AND	H01.ITAKU_KAISHA_CD		= H03.ITAKU_KAISHA_CD';
	IF (trim(both l_inHktCd) IS NOT NULL AND (trim(both l_inHktCd))::text <> '') THEN
		gSQL := gSQL || '		AND H01.HKT_CD = ''' || l_inHktCd || ''' ';
	END IF;
	gSQL := gSQL || '		    AND H01.HKT_CD 				= VMG1.HKT_CD ';
	gSQL := gSQL || ' 			AND	H01.KAIKEI_KBN			= H03.KAIKEI_KBN';
	gSQL := gSQL || ' 		GROUP BY';
	gSQL := gSQL || ' 			 H03.ITAKU_KAISHA_CD';
	gSQL := gSQL || ' 			,H03.MGR_CD';
	gSQL := gSQL || ' 			,H03.KAIKEI_KBN';
	gSQL := gSQL || ' 			,H01.KAIKEI_KBN_NM';
	gSQL := gSQL || ' 			,H03.CHOKYU_YMD';
	gSQL := gSQL || ' ';
	gSQL := gSQL || ' 	) WT1';
	gSQL := gSQL || ' 	,MBUTEN			M04';					-- 部店マスタ
	gSQL := gSQL || ' 	LEFT JOIN KOZA_FRK 		S06';					-- 口座振替区分情報
	gSQL := gSQL || ' 		ON MG7.ITAKU_KAISHA_CD = S06.ITAKU_KAISHA_CD ';
	gSQL := gSQL || ' 		AND MG7.KOZA_FURI_KBN = S06.KOZA_FURI_KBN ';
	gSQL := gSQL || ' 	LEFT JOIN SCODE 			MCD1';					-- コードマスタ
	gSQL := gSQL || ' 		ON MCD1.CODE_SHUBETSU = ''707'' ';
	gSQL := gSQL || ' 		AND S06.KOZA_KAMOKU = MCD1.CODE_VALUE ';
	gSQL := gSQL || ' 	,MHAKKOTAI 		M01';					-- 発行体マスタ
	gSQL := gSQL || ' 	,VJIKO_ITAKU 	VJ1';					-- 自行・委託会社VIEW
	gSQL := gSQL || ' WHERE	';
	gSQL := gSQL || ' 		WT1.ITAKU_KAISHA_CD = VJ1.KAIIN_ID';
	gSQL := gSQL || ' 	AND	M01.ITAKU_KAISHA_CD = WT1.ITAKU_KAISHA_CD';
	gSQL := gSQL || ' 	AND	VMG1.ITAKU_KAISHA_CD = WT1.ITAKU_KAISHA_CD';
	gSQL := gSQL || ' 	AND	VMG1.MGR_CD = WT1.MGR_CD ';
	gSQL := gSQL || ' 	AND	TRIM(VMG1.ISIN_CD) IS NOT NULL ';
	gSQL := gSQL || ' 	AND VMG1.MGR_STAT_KBN = ''1'' ';
	gSQL := gSQL || '   AND M01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD ';
	gSQL := gSQL || '   AND M01.HKT_CD = VMG1.HKT_CD ';
	gSQL := gSQL || ' 	AND	M01.ITAKU_KAISHA_CD	= M04.ITAKU_KAISHA_CD';
	gSQL := gSQL || ' 	AND	M01.KOZA_TEN_CD    	= M04.BUTEN_CD';
	gSQL := gSQL || '   AND MG7.ITAKU_KAISHA_CD = WT1.ITAKU_KAISHA_CD ';
	gSQL := gSQL || '   AND MG7.MGR_CD = WT1.MGR_CD ';
	gSQL := gSQL || '   AND MG7.TESU_SHURUI_CD = ''01'' ';
	gSQL := gSQL || '   AND MG8.ITAKU_KAISHA_CD = WT1.ITAKU_KAISHA_CD ';
	gSQL := gSQL || '   AND MG8.MGR_CD = WT1.MGR_CD ';
	IF (trim(both l_inHktCd) IS NOT NULL AND (trim(both l_inHktCd))::text <> '') THEN
		gSQL := gSQL || ' AND M01.HKT_CD = ''' || l_inHktCd || ''' ';
	END IF;
	IF (trim(both l_inKozaTenCd) IS NOT NULL AND (trim(both l_inKozaTenCd))::text <> '') THEN
		gSQL := gSQL || ' AND 	M01.KOZA_TEN_CD = ''' || l_inKozaTenCd || ''' ';
	END IF;
	IF (trim(both l_inKozaTenCifCd) IS NOT NULL AND (trim(both l_inKozaTenCifCd))::text <> '') THEN
		gSQL := gSQL || ' AND 	M01.KOZA_TEN_CIFCD = ''' || l_inKozaTenCifCd || ''' ';
	END IF;
	IF (trim(both l_inIsinCd) IS NOT NULL AND (trim(both l_inIsinCd))::text <> '') THEN
		gSQL := gSQL || ' AND 	VMG1.ISIN_CD = ''' || l_inIsinCd || ''' ';
	END IF;
	gSQL := gSQL || '	AND EXISTS( ';
	gSQL := gSQL || ' 	SELECT ';
	gSQL := gSQL || '		H02.MGR_CD ';
	gSQL := gSQL || ' 	FROM ';
	gSQL := gSQL || '		KAIKEI_ANBUN H02 ';
	gSQL := gSQL || ' 	WHERE ';
	gSQL := gSQL || '		H02.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD ';
	gSQL := gSQL || ' 	AND	H02.MGR_CD = VMG1.MGR_CD ) ';
	gSQL := gSQL || ' ORDER BY';
	gSQL := gSQL || ' 	 HKT_CD';
	gSQL := gSQL || ' 	,CHOKYU_YMD';
	gSQL := gSQL || ' 	,ISIN_CD';
	gSQL := gSQL || ' 	,KAIKEI_KBN';
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spiph004k00r01_createsql () FROM PUBLIC;





CREATE OR REPLACE FUNCTION spiph004k00r01_getkaikeitesuryocount ( l_initakukaishacd char, l_inmgrcd char ) RETURNS numeric AS $body$
DECLARE

	gCnt              numeric  := 0;

BEGIN
	SELECT
		COUNT(*)
	INTO STRICT
		gCnt
	FROM
		TESURYO_KAIKEI
	WHERE
	ITAKU_KAISHA_CD = l_initakukaishacd
	AND	MGR_CD = l_inmgrcd
	AND (TESU_SHURUI_CD = '31' OR TESU_SHURUI_CD = '32')
	;
	RETURN gCnt;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spiph004k00r01_getkaikeitesuryocount ( l_initakukaishacd MGR_KIHON.ITAKU_KAISHA_CD%TYPE, l_inmgrcd MGR_KIHON.MGR_CD%TYPE ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spiph004k00r01_getshinkitesuryocount ( l_initakukaishacd char, l_inmgrcd char ) RETURNS numeric AS $body$
DECLARE

	gCnt              numeric  := 0;

BEGIN
	SELECT
		COUNT(*)
	INTO STRICT
		gCnt
	FROM
		TESURYO_KAIKEI
	WHERE
	ITAKU_KAISHA_CD = l_initakukaishacd
	AND	MGR_CD = l_inmgrcd
	AND TESU_SHURUI_CD = '51'
	;
	RETURN gCnt;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spiph004k00r01_getshinkitesuryocount ( l_initakukaishacd MGR_KIHON.ITAKU_KAISHA_CD%TYPE, l_inmgrcd MGR_KIHON.MGR_CD%TYPE ) FROM PUBLIC;
