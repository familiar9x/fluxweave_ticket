drop procedure if exists spipi044k00r02(char, char, char, char, char, char, integer, text);
drop procedure if exists spipi044k00r02(char, char, char, char, char, char, numeric, text);

CREATE OR REPLACE PROCEDURE spipi044k00r02 ( 
    l_inTsuchiYmd text,			-- 通知日
    l_inItakuKaishaCd text,			-- 委託会社コード
    l_inUserId text,			-- ユーザーID
    l_inChohyoKbn text,			-- 帳票区分
    l_inGenboSofuFlg text,			-- 原簿送付状出力フラグ
    l_inGyomuYmd text,			-- 業務日付
    l_outSqlCode INOUT INT,			-- リターン値
    l_outSqlErrM INOUT text		-- エラーコメント
 ) AS $body$
DECLARE
	--
	--  著作権:Copyright(c)2004
	--  会社名:JIP
	--  概要　:原簿ワークテーブルをもとに、帳票ワーク作成処理を行う。
	--  引数　:	l_inTsuchiYmd		IN		CHAR		通知日
	--  			l_inItakuKaishaCd	IN		CHAR		委託会社コード
	-- 			l_inUserId			IN		CHAR		ユーザーID
	-- 			l_inChohyoKbn		IN		CHAR		帳票区分
	-- 			l_inGenboSofuFlg	IN		CHAR		原簿送付状出力フラグ
	-- 			l_inGyomuYmd		IN		CHAR		業務日付
	-- 			l_outSqlCode		OUT		NUMBER		リターン値
	-- 			l_outSqlErrM		OUT		VARCHAR2	エラーコメント
	--
	--  返り値:なし
	--
	-- ***************************************************************************
	--  ログ　:
	--  　　　日付	開発者名		目的
	--  -------------------------------------------------------------------
	-- 　2016.12.01	JIP				リメイク
	--  @version $Id: SPIPI044K00R02.SQL,v 1.26 2008/12/16 09:38:56 watanabe_t Exp $
	--
	--
	-- ***************************************************************************
	--

	-- ==============================================================================
	-- 					デバッグ機能
	-- ==============================================================================
	DEBUG	smallint	:= 0;

	-- ==============================================================================
	-- 					定数定義
	-- ==============================================================================
    l_inItem 	  		 TYPE_SREPORT_WK_ITEM;

	RTN_OK				CONSTANT integer	:= 0;						-- 正常
	RTN_NG				CONSTANT integer	:= 1;						-- 予期したエラー
	RTN_NODATA			CONSTANT integer	:= 2;						-- データなし
	RTN_FATAL			CONSTANT integer	:= 99;						-- 予期せぬエラー
	REPORT_ID			CONSTANT char(11)	:= 'IP030004411';			-- 帳票ID
	-- 書式フォーマット
	FMT_HAKKO_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	FMT_RBR_KNGK_J		CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 利払金額
	FMT_SHOKAN_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 償還金額
	-- 書式フォーマット（外資）
	FMT_HAKKO_KNGK_F	CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 発行金額
	FMT_RBR_KNGK_F		CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 利払金額
	FMT_SHOKAN_KNGK_F	CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 償還金額
	TSUCHI_YMD_DEF		CONSTANT char(16)	:= '      年  月  日';		-- 通知日（デフォルト）
	CODE_SORT_RBR		CONSTANT numeric	:= 0;						-- 利払コードソート用ダミー定数
	HYPHEN				CONSTANT varchar(16)	:= '−';			-- ハイフン表示用

	-- ==============================================================================
	-- 					変数定義
	-- ==============================================================================
	gRtnCd				integer 		:=	RTN_OK;					-- リターンコード
	gSeqNo				integer 		:= 0;						-- シーケンス
	gSofuSeqNo			integer 		:= 0;						-- 送付状用の連番
	gGenboMgrCd			varchar(13)	:= NULL;					-- 原簿WKにある銘柄の種類分の銘柄コード格納用変数
	mgrRiritsu			numeric			:= 0;						-- 利率を格納する変数
	spc					char(1)			:= ' ';					-- スペース
	-- 送付状出力の際、必要となる項目を格納する変数
	sofuHktCd			GENBO_WORK.HKT_CD%TYPE := NULL;			-- 発行体コード
	sofuSfskPostNo		MHAKKOTAI.SFSK_POST_NO%TYPE := NULL;		-- 送付先郵便番号
	sofuAdd1			MHAKKOTAI.ADD1%TYPE := NULL;				-- 送付先住所１
	sofuAdd2			MHAKKOTAI.ADD2%TYPE := NULL;				-- 送付先住所２
	sofuAdd3			MHAKKOTAI.ADD3%TYPE := NULL;				-- 送付先住所３
	sofuHktNm			MHAKKOTAI.HKT_NM%TYPE := NULL;				-- 発行体名称
	sofuSfskBushoNm		MHAKKOTAI.SFSK_BUSHO_NM%TYPE := NULL;		-- 送付先担当部署名称
	sofuBankNm			VJIKO_ITAKU.BANK_NM%TYPE := NULL;			-- 銀行名称(自行)
	sofuBushoNm1		VJIKO_ITAKU.BUSHO_NM1%TYPE := NULL;		-- 担当部署名称１(自行)
	sofuMgrNm			MGR_KIHON.MGR_NM%TYPE := NULL;				-- 銘柄の正式名称
	sofuIsinCd			GENBO_WORK.ISIN_CD%TYPE := NULL;			-- ＩＳＩＮコード
	sofuMgrCd			MGR_KIHON.MGR_CD%TYPE := NULL;				-- 銘柄コード
	sofuHktRnmKana		MHAKKOTAI.HKT_KANA_RNM%TYPE := NULL;		-- 発行体略称カナ
	-- 書式フォーマット
	gFmtHakkoKngk		varchar(21) := NULL;						-- 発行金額
	gFmtRbrKngk			varchar(21) := NULL;						-- 利払金額
	gFmtShokanKngk		varchar(21) := NULL;						-- 償還金額
	gWrkTsuchiYmd		varchar(16) := NULL;						-- 通知日(西暦)
	gAtena				varchar(200) := NULL;						-- 宛名
	gOutflg				int := 0;								-- 正常処理フラグ
	gMeimokuZndk		SREPORT_WK.ITEM036%TYPE := NULL;
	gRiritsu			SREPORT_WK.ITEM028%TYPE := NULL;
	gBufGenzonKngk		numeric	:=		0;							-- 現存金額の一時保管用
	genzonSetFlg		integer :=		0;
	gFurikaeGaku		numeric	:=		0;							-- 振替債移行額
	gFactor				SREPORT_WK.ITEM036%TYPE := NULL;
	gBufGnrYmd			char(8)	:=		NULL;						-- 同日償還判定用 元利払日
	gBufShokanKbn		char(2)	:=		NULL;						-- 同日償還判定用 償還区分
	gGensaiKngk			SREPORT_WK.ITEM035%TYPE := NULL;			-- 減債金額一時格納変数
	gRikinKngk			SREPORT_WK.ITEM038%TYPE := NULL;			-- 利金金額一時格納変数
	gChohyoSortFlg		MPROCESS_CTL.CTL_VALUE%TYPE;					-- 発行体宛帳票ソート順変更フラグ
	gLineCnt		numeric	:=		0;						-- 銘柄毎出力件数

	-- ==============================================================================
	-- 					カーソル定義
	-- ==============================================================================
	-- 原簿を出力する際に必要な項目を抽出するカーソル
	CUR_GENBO_DATA CURSOR FOR
	SELECT	G01.HKT_CD  																				-- 発行体コード
			,M01.SFSK_POST_NO 																		-- 送付先郵便番号
			,M01.ADD1																				-- 送付先住所１
			,M01.ADD2																				-- 送付先住所２
			,M01.ADD3																				-- 送付先住所３
			,M01.SFSK_BUSHO_NM 																		-- 送付先担当部署名称
			,VJI.BUSHO_NM1																			-- 担当部署名称１(自行)
			,MG1.RIRITSU 																			-- 利率
			,M01.HKT_NM 																				-- 発行体名称
			,M01.HKT_KANA_RNM 																		-- 発行体略称カナ
			,VJI.BANK_NM 																			-- 銀行名称(自行)
			,MG1.MGR_NM 																				-- 銘柄の正式名称
			,MG1.MGR_CD 																				-- 銘柄コード
			,G01.ISIN_CD 																			-- ＩＳＩＮコード
			,CASE
				WHEN G01.TOKUREI_SHASAI_FLG = 'Y' THEN '特例社債'
				ELSE '　'
			 END AS TOKUREI_SHASAI_TITLE 															-- 特例社債タイトル
			,CASE
				WHEN G01.PARTMGR_KBN = '2' THEN '親銘柄ＩＳＩＮコード'
				ELSE '　'
			 END AS OYAMGR_ISINCD_TITLE 																-- 親銘柄ＩＳＩＮコードタイトル
			,CASE
				WHEN G01.PARTMGR_KBN = '2' THEN G01.GENISIN_CD
				ELSE NULL
			 END AS GENISIN_CD 																		-- 原ＩＳＩＮコード
			,G01.JUTAKUSAKI_TITLE 																	-- 受託先タイトル
			,G01.HAKKO_YMD 																			-- 発行年月日
			,G01.HRKM_YMD 																			-- 払込日
			,G01.FULLSHOKAN_KJT 																		-- 満期償還日
			,G01.SHASAI_TOTAL 																		-- 社債の総額
			,G01.KAKUSHASAI_KNGK 																	-- 各社債の金額
			,G01.HRKM_KNGK 																			-- 払込金額
			,M64.TSUKA_NM AS HAKKO_TSUKA_NM 															-- 発行通貨名称
			,MCD1.CODE_NM AS SHOKAN_METHOD_CD_NM 													-- 償還方法名称
			,G01.RBR_KJT_NM 																			-- 利払期日名称
			,G01.RITSUKE_WARIBIKI_KBN 																-- 利付割引区分
			,MCD2.CODE_NM AS RITSUKE_WARIBIKI_KBN_NM 												-- 利付割引区分名称
			,G01.GNRBARAI_KJT 																		-- 元利払期日
			,G01.GNR_YMD 																			-- 元利払日
			,CASE
				WHEN G01.SHOKAN_KBN = '00' THEN '発行'
				WHEN
					G01.SHOKAN_KBN = '30' 
				AND nullif(trim(both MG1.DEFAULT_YMD), '') IS NOT NULL
				AND G01.GNR_YMD >= MG1.DEFAULT_YMD 
				THEN '元本償還'
				ELSE coalesce(MCD3.CODE_NM,' ')
			 END AS JIYU 																			-- 事由(償還区分名称)
			,G01.GENSAI_KNGK 																		-- 減債金額
			,G01.GENZON_KNGK 																		-- 現存金額
			,G01.MEIMOKU_ZNDK 																		-- 名目残高
			,G01.FACTOR 																				-- ファクター
			,G01.RKN_KNGK 																			-- 利金金額
			,MG1.HAKKO_TSUKA_CD 																		-- 発行通貨コード
			,MG1.RBR_TSUKA_CD 																		-- 利払通貨コード
			,MG1.SHOKAN_TSUKA_CD 																	-- 償還通貨コード
			,G01.SHOKAN_METHOD_CD 																	-- 償還方法コード
			,G01.SHOKAN_KBN 																			-- 償還区分
			,MG1.DEFAULT_YMD
			,DE02.DEFAULT_RIYU_NM
			,CASE
				WHEN nullif(trim(both MG1.DEFAULT_YMD), '') IS NOT NULL THEN 'デフォルト日'
				ELSE ' '
			 END AS DEFAULT_YMD_TITLE
			,CASE
				WHEN nullif(trim(both MG1.DEFAULT_YMD), '') IS NOT NULL THEN 'デフォルト事由'
				ELSE ' '
			 END AS DEFAULT_RIYU_TITLE
			,MG1.TEIJI_SHOKAN_TSUTI_KBN                                                              -- 定時償還通知区分
			,BT01.KYOTEN_KBN                                                                         -- 拠点区分（表示なし）
			,BT03.DISPATCH_FLG                                                                       -- 請求書発送区分
			,MG1.DPT_ASSUMP_FLG                                                                      -- デットアサンプション契約先フラグ
			,M01.KOZA_TEN_CD                                                                         -- 口座店コード
			,M01.KOZA_TEN_CIFCD                                                                      -- 口座店ＣＩＦコード
			,M01.SHORI_KBN                                                                           -- 処理区分
	FROM vjiko_itaku vji, scode mcd2, scode mcd1, mtsuka m64, mhakkotai m01, mgr_kihon2 bt03, mhakkotai2 bt01, genbo_work g01
LEFT OUTER JOIN (	SELECT CODE_SHUBETSU
					,CODE_VALUE
					,CODE_SORT
					,CODE_KETA
					,CODE_NM
					,CODE_RNM FROM SCODE
				
UNION

				SELECT '714' AS CODE_SHUBETSU
					,'  ' AS CODE_VALUE
					,CODE_SORT_RBR AS CODE_SORT
					,0 AS CODE_KETA
					,'' AS CODE_NM
					,'' AS CODE_RNM FROM SCODE) mcd3 ON (G01.SHOKAN_KBN = MCD3.CODE_VALUE AND '714' = MCD3.CODE_SHUBETSU)
, mgr_kihon mg1
LEFT OUTER JOIN default_riyu_kanri de02 ON (MG1.ITAKU_KAISHA_CD = DE02.ITAKU_KAISHA_CD AND MG1.DEFAULT_RIYU = DE02.DEFAULT_RIYU)
WHERE VJI.KAIIN_ID = l_inItakuKaishaCd AND MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND MG1.MGR_CD = gGenboMgrCd AND G01.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD 
    AND G01.ISIN_CD = MG1.ISIN_CD AND G01.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD AND G01.HKT_CD = M01.HKT_CD AND G01.JTK_KBN <> '5' 
    AND G01.HAKKO_TSUKA_CD = M64.TSUKA_CD AND trim(both G01.SHOKAN_METHOD_CD) = MCD1.CODE_VALUE AND MCD1.CODE_SHUBETSU = '116' 
    AND G01.RITSUKE_WARIBIKI_KBN = MCD2.CODE_VALUE AND MCD2.CODE_SHUBETSU = '529'     AND MG1.ITAKU_KAISHA_CD = BT03.ITAKU_KAISHA_CD 
    AND MG1.MGR_CD = BT03.MGR_CD AND M01.ITAKU_KAISHA_CD = BT01.ITAKU_KAISHA_CD AND M01.HKT_CD = BT01.HKT_CD -- 口座店コード＞口座店CIFコード＞拠点区分＞請求書発送区分＞デットアサンプション契約先フラグ＞発行日＞ISINコード＞元利払日＞償還事由
 ORDER BY 
			M01.KOZA_TEN_CD,     -- 口座店コード
			M01.KOZA_TEN_CIFCD,  -- 口座店ＣＩＦコード
			BT01.KYOTEN_KBN,     -- 拠点区分
			BT03.DISPATCH_FLG,   -- 請求書発送区分
			MG1.DPT_ASSUMP_FLG,  -- デットアサンプション契約先フラグ
			G01.HAKKO_YMD,       -- 発行日
			MG1.ISIN_CD,         -- ISINコード
			G01.GNR_YMD,         -- 元利払日
			MCD3.CODE_SORT;      -- 償還事由(コードマスタ(償還区分))
	-- 原簿ワークにあるデータの銘柄コードを抽出するカーソル
	CUR_GENBO_MGR CURSOR FOR
	SELECT 	DISTINCT
			MG1.MGR_CD 									-- 銘柄コード
	FROM	GENBO_WORK G01,
			MGR_KIHON MG1
	WHERE	G01.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
	AND		G01.ISIN_CD = MG1.ISIN_CD
	AND		G01.ITAKU_KAISHA_CD = l_inItakuKaishaCd;

BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPI044K00R02 START');	END IF;
	-- 入力パラメータのチェック
	IF nullif(trim(both l_inItakuKaishaCd), '') IS NULL
	OR nullif(trim(both l_inUserId), '') IS NULL
	OR nullif(trim(both l_inChohyoKbn), '') IS NULL
	OR nullif(trim(both l_inGyomuYmd), '') IS NULL
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', REPORT_ID, 'SQLERRM:'||'');
		RETURN;
	END IF;
	-- 通知日の西暦変換
	gWrkTsuchiYmd := TSUCHI_YMD_DEF;
	IF nullif(trim(both l_inTsuchiYmd), '') IS NOT NULL THEN
		gWrkTsuchiYmd := pkDate.seirekiChangeSuppressNenGappi(l_inTsuchiYmd);
	END IF;
	-- シーケンスNOの初期化
	gSeqNo := 0;
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE		KEY_CD = l_inItakuKaishaCd
	AND			USER_ID = l_inUserId
	AND			CHOHYO_KBN = l_inChohyoKbn
	AND			SAKUSEI_YMD = l_inGyomuYmd
	AND			CHOHYO_ID = REPORT_ID;
	-- IP030004411のヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
		--　銘柄の種類の分だけループ
	FOR GENBO_MGR IN CUR_GENBO_MGR LOOP
		-- 銘柄コードを変数に格納する
		gGenboMgrCd := GENBO_MGR.MGR_CD;
		-- 一時格納用変数を初期化
		gBufGnrYmd		:= '';
		gBufShokanKbn	:= '';
		-- 現存金額をセットする際、必要となるフラグ
		genzonSetFlg := 0;
		-- 銘柄毎の件数を取得する
		SELECT	COUNT(*)
		INTO STRICT	gLineCnt 
		FROM	GENBO_WORK G01
			,MGR_KIHON MG1
		WHERE	G01.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
		  AND	G01.ISIN_CD = MG1.ISIN_CD
		  AND	MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		  AND	MG1.MGR_CD = gGenboMgrCd
		;
		-- 原簿の明細部分を帳票ワークに書き込む。明細の分だけループ
		FOR GENBO_DATA IN CUR_GENBO_DATA LOOP
			-- 利率が０％だった場合、原簿には表示させないようにする
			IF GENBO_DATA.RIRITSU = 0 THEN
				gRiritsu := ' ';
			ELSE
				gRiritsu := GENBO_DATA.RIRITSU;
			END IF;
			-- 宛名編集
			--送付先担当部署名称（御中込）
			CALL pkIpaName.getMadoFutoAtena(GENBO_DATA.HKT_NM, GENBO_DATA.SFSK_BUSHO_NM, gOutflg, gAtena);
			-- 同一日に複数償還があった場合に必要となる。一時格納用変数に元利払期日と元利払日を格納
			IF nullif(trim(both gBufGnrYmd), '') IS NULL THEN
				gBufGnrYmd		:= GENBO_DATA.GNR_YMD;
				gBufShokanKbn 	:= GENBO_DATA.SHOKAN_KBN;
			END IF;
			-- シーケンス番号をカウントアップ
			gSeqNo := gSeqNo + 1;
			-- 書式フォーマットの設定
			-- 発行
			IF GENBO_DATA.HAKKO_TSUKA_CD = 'JPY' THEN
				gFmtHakkoKngk := FMT_HAKKO_KNGK_J;
			ELSE
				gFmtHakkoKngk := FMT_HAKKO_KNGK_F;
			END IF;
			-- 利払
			IF (GENBO_DATA.RBR_TSUKA_CD = 'JPY') OR (nullif(trim(both GENBO_DATA.RBR_TSUKA_CD), '') IS NULL) THEN
				gFmtRbrKngk := FMT_RBR_KNGK_J;
			ELSE
				gFmtRbrKngk := FMT_RBR_KNGK_F;
			END IF;
			-- 償還
			IF GENBO_DATA.SHOKAN_TSUKA_CD = 'JPY' THEN
				gFmtShokanKngk := FMT_SHOKAN_KNGK_J;
			ELSE	
				gFmtShokanKngk := FMT_SHOKAN_KNGK_F;
			END IF;	
			-- 現存金額のセット(階段式に現存額から減債額を引いていく)
			IF genzonSetFlg = 0 THEN									-- 初回のみ現存額をセット(社債の総額)
				gBufGenzonKngk := GENBO_DATA.GENZON_KNGK;
				genzonSetFlg := 1;
			ELSIF (GENBO_DATA.SHOKAN_KBN = '01') THEN
				-- 当該回次(振替債移行)の移行額を取得
				SELECT	coalesce(Z01.GENSAI_KNGK, 0)
				INTO STRICT	gFurikaeGaku
				FROM	GENSAI_RIREKI Z01
				WHERE	Z01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
				AND		Z01.MGR_CD = GENBO_DATA.MGR_CD
				AND		Z01.SHOKAN_YMD = GENBO_DATA.GNR_YMD
				AND		Z01.SHOKAN_KBN = GENBO_DATA.SHOKAN_KBN;
				-- 取得した振替債移行額を現存額に加算する
				gBufGenzonKngk := gBufGenzonKngk + gFurikaeGaku;
			END IF;
			gBufGenzonKngk := gBufGenzonKngk - GENBO_DATA.GENSAI_KNGK;
			GENBO_DATA.GENZON_KNGK := gBufGenzonKngk;
			-- 償還区分によって、減債金額と利金金額の表示・非表示を判別させる
			IF nullif(trim(both GENBO_DATA.SHOKAN_KBN), '') IS NULL THEN
				-- 償還区分が設定されていない(利金のみのレコードの)場合,減債金額はブランクにして利金金額はそのまま表示する
				gGensaiKngk := spc;
				gRikinKngk := GENBO_DATA.RKN_KNGK;				
				-- 償還区分が設定されていない(利金のみのレコードの)場合,ファクター・名目残高は前回のものを設定
				gFactor			:= gFactor;
				gMeimokuZndk	:= gMeimokuZndk;
			ELSIF GENBO_DATA.SHOKAN_KBN IN ('00','01') THEN
				-- 償還区分が発行(００)か振替債移行(０１)のレコードは減債金額と利金額をブランクにする
				gGensaiKngk := spc;
				gRikinKngk := spc;				
				-- 償還区分が設定されている場合,ファクター・名目残高を保持する
				gFactor			:= GENBO_DATA.FACTOR;
				gMeimokuZndk	:= GENBO_DATA.MEIMOKU_ZNDK;
			ELSIF GENBO_DATA.SHOKAN_KBN = '30' OR GENBO_DATA.SHOKAN_KBN = '60' THEN
				-- 償還区分が買入消却(３０)か新株予約権行使（６０）のレコードは利金額をブランクにする
				gRikinKngk := spc;				
				-- 減債金額をそのまま表示する
				gGensaiKngk := GENBO_DATA.GENSAI_KNGK;
				-- 償還区分が設定されている場合,ファクター・名目残高を保持する
				gFactor			:= GENBO_DATA.FACTOR;
				gMeimokuZndk	:= GENBO_DATA.MEIMOKU_ZNDK;
			ELSE
				-- 金額をそのまま表示する
				gGensaiKngk := GENBO_DATA.GENSAI_KNGK;
				gRikinKngk := GENBO_DATA.RKN_KNGK;
				-- 償還区分が設定されている場合,ファクター・名目残高を保持する
				gFactor			:= GENBO_DATA.FACTOR;
				gMeimokuZndk	:= GENBO_DATA.MEIMOKU_ZNDK;
			END IF;
			-- 同一日に複数償還がある場合の処理
			IF gBufGnrYmd = GENBO_DATA.GNR_YMD
			AND gBufShokanKbn = '50' 
			AND (GENBO_DATA.SHOKAN_KBN = '20' OR GENBO_DATA.SHOKAN_KBN = '21') THEN
				-- 元利払日＝buf元利払日 かつ buf償還区分が'50'で償還区分が'20'か'21'の場合 利金はクリアする。
				gRikinKngk := spc;
			ELSIF gBufGnrYmd = GENBO_DATA.GNR_YMD
			AND (gBufShokanKbn = '20' OR gBufShokanKbn = '21')
			AND GENBO_DATA.SHOKAN_KBN = '41' THEN
				-- 元利払日＝buf元利払日 かつ buf償還区分が'20'か'21'で、償還区分が'41'の場合 利金はクリアする。
				gRikinKngk := spc;
			END IF;
			-- 元利払日と償還区分を変数に格納する。
			gBufGnrYmd		:= GENBO_DATA.GNR_YMD;
			gBufShokanKbn	:= GENBO_DATA.SHOKAN_KBN;
			-- 割引債の場合、利金金額は必ず非表示
			IF GENBO_DATA.RITSUKE_WARIBIKI_KBN = 'Z' THEN
				gRikinKngk := spc;
			END IF;			
			--償還方法が定時償還の場合のみ名目残高とファクターを表示させる。
			IF GENBO_DATA.SHOKAN_METHOD_CD = '2' THEN
				gMeimokuZndk			:= gMeimokuZndk;
				IF GENBO_DATA.GENZON_KNGK = 0
				AND (GENBO_DATA.SHOKAN_KBN = '30' OR GENBO_DATA.SHOKAN_KBN = '50') THEN
					-- 全額買入または全額プットが行われた場合、ファクターの欄にはハイフンを表示させるようにする。
					gFactor := HYPHEN;
				ELSE
					gFactor					:= gFactor;
				END IF;
			ELSE
				gMeimokuZndk			:= ' ';
				gFactor					:= ' ';
			END IF;
			-- 定時償還の永久債の償還方法を永久債とする
			IF GENBO_DATA.FULLSHOKAN_KJT = '99999999' AND GENBO_DATA.SHOKAN_METHOD_CD = '2'
			AND GENBO_DATA.TEIJI_SHOKAN_TSUTI_KBN = 'V' THEN
			    GENBO_DATA.SHOKAN_METHOD_CD_NM  := '永久債';
			END IF;
			-- 帳票ワークへデータを追加
            l_inItem := ROW();

            --l_inItem.l_inItem001 := l_inUserId;                               -- ユーザＩＤ

			l_inItem.l_inItem001 := gWrkTsuchiYmd;								-- 通知日
			l_inItem.l_inItem002 := GENBO_DATA.SFSK_POST_NO;						-- 送付先郵便番号
			l_inItem.l_inItem003 := GENBO_DATA.ADD1;								-- 送付先住所１
			l_inItem.l_inItem004 := GENBO_DATA.ADD2;								-- 送付先住所２
			l_inItem.l_inItem005 := GENBO_DATA.ADD3;								-- 送付先住所３
			l_inItem.l_inItem006 := gAtena;										--送付先担当部署名称（御中込）
			l_inItem.l_inItem007 := GENBO_DATA.BANK_NM;							-- 銀行名称
			l_inItem.l_inItem008 := GENBO_DATA.BUSHO_NM1;						-- 担当部署名称
			l_inItem.l_inItem010 := GENBO_DATA.MGR_NM;							-- 銘柄の正式名称
			l_inItem.l_inItem011 := GENBO_DATA.HKT_NM;							-- 発行体名称
			l_inItem.l_inItem012 := GENBO_DATA.ISIN_CD;							-- ＩＳＩＮコード
			l_inItem.l_inItem013 := GENBO_DATA.HKT_CD;							-- 発行体コード
			l_inItem.l_inItem014 := GENBO_DATA.MGR_CD;							-- 銘柄コード
			l_inItem.l_inItem015 := GENBO_DATA.HKT_KANA_RNM;						-- 発行体略称カナ
			l_inItem.l_inItem016 := GENBO_DATA.TOKUREI_SHASAI_TITLE;				-- 特例社債タイトル
			l_inItem.l_inItem017 := GENBO_DATA.OYAMGR_ISINCD_TITLE;				-- 親銘柄ＩＳＩＮコードタイトル
			l_inItem.l_inItem018 := GENBO_DATA.BANK_NM;							-- 銀行名称
			l_inItem.l_inItem019 := GENBO_DATA.GENISIN_CD;						-- 原ＩＳＩＮコード
			l_inItem.l_inItem020 := GENBO_DATA.JUTAKUSAKI_TITLE;					-- 受託先タイトル
			l_inItem.l_inItem021 := GENBO_DATA.HAKKO_YMD;						-- 発行年月日
			l_inItem.l_inItem022 := GENBO_DATA.HRKM_YMD;							-- 払込日
			l_inItem.l_inItem023 := GENBO_DATA.FULLSHOKAN_KJT;					-- 満期償還日
			l_inItem.l_inItem024 := GENBO_DATA.SHASAI_TOTAL;						-- 社債の総額
			l_inItem.l_inItem025 := GENBO_DATA.KAKUSHASAI_KNGK;					-- 各社債の金額
			l_inItem.l_inItem026 := GENBO_DATA.HRKM_KNGK;						-- 払込金額
			l_inItem.l_inItem027 := GENBO_DATA.HAKKO_TSUKA_NM;					-- 発行通貨名称
			l_inItem.l_inItem028 := GENBO_DATA.SHOKAN_METHOD_CD_NM;				-- 償還方法名称
			l_inItem.l_inItem029 := GENBO_DATA.RBR_KJT_NM;						-- 利払期日名称
			l_inItem.l_inItem031 := gRiritsu;									-- 利率
			l_inItem.l_inItem032 := GENBO_DATA.RITSUKE_WARIBIKI_KBN_NM;			-- 利付割引区分名称
			l_inItem.l_inItem034 := GENBO_DATA.GNRBARAI_KJT;						-- 元利払期日
			l_inItem.l_inItem035 := GENBO_DATA.GNR_YMD;							-- 元利払日
			l_inItem.l_inItem036 := gGensaiKngk;									-- 減債金額
			l_inItem.l_inItem037 := GENBO_DATA.GENZON_KNGK;						-- 現存金額
			l_inItem.l_inItem038 := gMeimokuZndk;								-- 名目残高
			l_inItem.l_inItem040 := gFactor;										-- ファクター
			l_inItem.l_inItem041 := gRikinKngk;									-- 利金金額
			l_inItem.l_inItem042 := gFmtRbrKngk;									-- 利払金額書式フォーマット
			l_inItem.l_inItem043 := GENBO_DATA.JIYU;								-- 事由
			l_inItem.l_inItem044 := GENBO_DATA.RITSUKE_WARIBIKI_KBN;				-- 利付割引区分
			l_inItem.l_inItem045 := GENBO_DATA.SHOKAN_METHOD_CD;					-- 償還方法コード
			l_inItem.l_inItem046 := GENBO_DATA.DEFAULT_YMD_TITLE;				-- デフォルト日タイトル
			l_inItem.l_inItem047 := GENBO_DATA.DEFAULT_RIYU_TITLE;				-- デフォルト理由タイトル
			l_inItem.l_inItem048 := GENBO_DATA.DEFAULT_YMD;						-- デフォルト日
			l_inItem.l_inItem049 := GENBO_DATA.DEFAULT_RIYU_NM;					-- デフォルト理由
			l_inItem.l_inItem050 := GENBO_DATA.KYOTEN_KBN;                       -- 拠点区分
			l_inItem.l_inItem051 := GENBO_DATA.DISPATCH_FLG;                     -- 請求書発送区分
			l_inItem.l_inItem052 := GENBO_DATA.DPT_ASSUMP_FLG;                   -- デットアサンプション契約先フラグ
			l_inItem.l_inItem053 := GENBO_DATA.KOZA_TEN_CD;                      -- 口座店コード
			l_inItem.l_inItem054 := TRIM(GENBO_DATA.KOZA_TEN_CIFCD);             -- 口座店ＣＩＦコード
			l_inItem.l_inItem101 := GENBO_DATA.SHORI_KBN;                        -- 処理区分
			l_inItem.l_inItem102 := gLineCnt;							-- 出力行数

			CALL pkPrint.insertData(
				l_inKeyCd						=>		l_inItakuKaishaCd							-- 識別コード
				,l_inUserId						=>		l_inUserId									-- ユーザＩＤ
				,l_inChohyoKbn					=>		l_inChohyoKbn								-- 帳票区分
				,l_inSakuseiYmd					=>		l_inGyomuYmd								-- 作成年月日
				,l_inChohyoId					=>		REPORT_ID									-- 帳票ＩＤ
				,l_inSeqNo						=>		gSeqNo										-- 連番
				,l_inHeaderFlg					=>		'1'											-- ヘッダフラグ
				,l_inItem			            =>  	l_inItem
				,l_inKousinId					=>		l_inUserId									-- 更新者ID
				,l_inSakuseiId					=>		l_inUserId									-- 作成者ID
			);																								
		END LOOP;					-- 原簿に出力される明細の分のループの終わり
	END LOOP;					-- 銘柄種類分のループの終わり
	-- gSeqNoが０、すなわち帳票ワークに書き込んだ件数が０件だった場合、「対象データなし」を出力させる
	IF gSeqNo = 0 THEN
		-- 対象データなし
		gRtnCd := RTN_NODATA;
		-- 帳票ワークへデータを追加
        l_inItem := ROW();
        l_inItem.l_inItem001 := gWrkTsuchiYmd;                               -- ユーザＩＤ
        l_inItem.l_inItem039 := '対象データなし';                   -- 引受会社訂正日
		CALL pkPrint.insertData(
			l_inKeyCd					=>		l_inItakuKaishaCd				-- 委託会社コード
			,l_inUserId					=>		l_inUserId						-- ユーザーID
			,l_inChohyoKbn				=>		l_inChohyoKbn					-- 帳票区分
			,l_inSakuseiYmd				=>		l_inGyomuYmd					-- 業務日付
			,l_inChohyoId				=>		REPORT_ID
			,l_inSeqNo					=>		1
			,l_inHeaderFlg				=>		'1'
			,l_inItem			        =>  	l_inItem
			,l_inKousinId				=>		l_inUserId						-- 更新者ID
			,l_inSakuseiId				=>		l_inUserId						-- 作成者ID
		);
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPI044K00R02 END'); END IF;
	-- エラー処理
	EXCEPTION
		WHEN OTHERS THEN
			CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLCODE:'||SQLSTATE);
			CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLERRM:'||SQLERRM);
			l_outSqlCode := RTN_FATAL;
			l_outSqlErrM := SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;

