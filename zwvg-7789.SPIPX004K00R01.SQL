


DROP TYPE IF EXISTS spipx004k00r01_type_record CASCADE;
CREATE TYPE spipx004k00r01_type_record AS (
		gDistriYmd        char(8),                -- 分配日
		gTsukaCd          char(3),                -- 通貨コード
		gTesuShuruiCd     char(2),                -- 手数料種類コード
		gTsukaNm          char(3),                -- 通貨出力用名称
		gBankCd           char(5),                -- 金融機関区分+コード
		gBankRnm          varchar(30),            -- 金融機関略称
		gIsinCd           char(12),               -- ＩＳＩＮコード
		gMgrCd            varchar(13),            -- 銘柄コード
		gMgrRnm           varchar(44),            -- 銘柄略称
		gChokyuYmd        char(8),                -- 徴求日
		gTesuShuruiRNm    varchar(20),            -- 手数料種類略称
		gDfTesuKngk       decimal(14,2),          -- 分配手数料（税抜）
		gDfTesuSzei       decimal(12,2),          -- 分配手数料消費税
		gHoseiDfTesuKngk  decimal(14,2),          -- 補正額_分配手数料（税抜）
		gHoseiDfTesuSzei  decimal(12,2),          -- 補正額_分配手数料消費税
		gInputNum         numeric(2),             -- 入力順
		gBunpaiKngk       decimal(16,2),          -- 分配額
		gBunpaiSzei       decimal(16,2)           -- 内消費税
	);


CREATE OR REPLACE PROCEDURE spipx004k00r01 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE,     -- 委託会社コード
 l_inUserId SREPORT_WK.USER_ID%TYPE,    -- ユーザーID
 l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, -- 帳票区分
 l_inKijunYm text,                   -- 基準年月
 l_outSqlCode OUT integer,                     -- リターン値
 l_outSqlErrM OUT text                    -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2006
-- * 会社名:JIP
-- *
-- * 概要　:顧客宛帳票出力指示画面の入力条件により、
-- *        自行が代表受託である銘柄一覧及び各副受託行への分配情報を一覧表示する。
-- *        手数料の種類は期中管理手数料及び期中信託報酬とする。
-- *
-- * 引数　: l_inItakuKaishaCd :委託会社コード
-- *        l_inUserId        :ユーザーID
-- *        l_inChohyoKbn     :帳票区分
-- *        l_inKijunYm       :基準年月
-- *        l_outSqlCode      :リターン値
-- *        l_outSqlErrM      :エラーコメント
-- *
-- * 返り値: なし
-- *
-- * @author ASK
-- * @version $Id: SPIPX004K00R01.SQL,v 1.3 2007/02/08 05:56:25 miura Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2006.11.01 馮（ASK）   新規作成
-- ***************************************************************************
--
--	/*==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_PROCEDURE_ID     CONSTANT varchar(50) := 'SPIPX004K00R01';           -- プロシージャID
	C_REPORT_ID        CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IPX30000411'; -- 帳票ID
	C_TITLE_SINTAKU    CONSTANT varchar(10) := '信託手数料';               -- 帳票タイトル
	C_TITLE_BETUDAN    CONSTANT varchar(10) := '別段預金';                 -- 帳票タイトル
	C_FMT_HAKKO_KNGK_J CONSTANT char(15) := 'ZZZ,ZZZ,ZZZ,ZZ9';              -- 書式フォーマット分配額
	C_FMT_TESU_SZEI_J  CONSTANT char(13) := 'Z,ZZZ,ZZZ,ZZ9';                -- 書式フォーマット内消費
	C_FMT_HAKKO_KNGK_F CONSTANT char(18) := 'ZZZ,ZZZ,ZZZ,ZZ9.99';           -- 書式フォーマット（外資）分配額
	C_FMT_TESU_SZEI_F  CONSTANT char(16) := 'Z,ZZZ,ZZZ,ZZ9.99';             -- 書式フォーマット（外資）内消費
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	gSeqNo             integer := 0;                 -- シーケンス
	gLopNo             integer := 0;                 -- ループ番号
	gGyomuYmd          SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE; -- 業務日付
	gKeyTsukaCd        VTESURYO.TSUKA_CD%TYPE;            -- 通貨コード（キーブレイク用）
	gKeyDistriYmd      VTESURYO.DISTRI_YMD%TYPE;          -- 分配日（キーブレイク用）
	gKeyBankCd         char(5);                           -- 金融機関区分+コード（キーブレイク用）
	gBunpaiKngkSumFJtk decimal(14,2) := 0;           -- 分配額各行合計(副受託)
	gBunpaiSzeiSumFJtk decimal(12,2) := 0;           -- 内消費税各行合計(副受託)
	gBunpaiKngkSum     decimal(14,2) := 0;           -- 分配額分配日合計(通貨毎)
	gBunpaiSzeiSum     decimal(12,2) := 0;           -- 内消費税分配日合計(通貨毎)
	gFmtHakkoKngk      varchar(18) := NULL;         -- 書式フォーマット分配額
	gFmtTesuSzei       varchar(16) := NULL;         -- 書式フォーマット内消費税
	gItakuKaishaRnm    SOWN_INFO.BANK_RNM%TYPE;           -- 委託会社略名
	v_item             TYPE_SREPORT_WK_ITEM;              -- SREPORT_WK item for pkPrint.insertData
	-- DB取得項目
	-- 配列定義
	recMeisai spipx004k00r01_type_record[]; -- 信託手数料用
	recMeisaiBetudan spipx004k00r01_type_record[]; -- 別段預金用
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	-- 信託手数料
	curMeisai_sintaku CURSOR FOR
		SELECT
			VT01.CHOKYU_YMD AS DISTRI_YMD,    -- 分配日
			VT01.TSUKA_CD,                    -- 通貨コード
			VT01.TESU_SHURUI_CD,              -- 手数料種類コード
			VJ1.JIKO_DAIKO_KBN,               -- 自行代行区分
			VJ1.BANK_RNM AS BANK_RNM_VT1,     -- 委託会社略称
			M64.TSUKA_NM,                     -- 通貨出力用名称
			T02.FINANCIAL_SECURITIES_KBN || T02.BANK_CD
			AS BANK_CD,                       -- 金融機関区分+コード
			M02.BANK_RNM,                     -- 金融機関略称
			VT01.ISIN_CD,                     -- ＩＳＩＮコード
			VT01.MGR_CD,                      -- 銘柄コード
			VT01.MGR_RNM,                     -- 銘柄略称
			VT01.CHOKYU_YMD,                  -- 徴求日
			MCD1.CODE_RNM AS TESU_SHURUI_RNM, --  手数料種類略称
			T02.DF_TESU_KNGK,                 -- 分配手数料（税抜）
			T02.DF_TESU_SZEI,                 -- 分配手数料消費税
			CASE WHEN 				VT01.DATA_SAKUSEI_KBN || VT01.SHORI_KBN='21' THEN  T02.HOSEI_DF_TESU_KNGK  ELSE 0 END  AS HOSEI_DF_TESU_KNGK,          -- 補正額_分配手数料（税抜）
			CASE WHEN 				VT01.DATA_SAKUSEI_KBN || VT01.SHORI_KBN='21' THEN  T02.HOSEI_DF_TESU_SZEI  ELSE 0 END  AS HOSEI_DF_TESU_SZEI,          -- 補正額_分配手数料消費税
			MG6.INPUT_NUM                      -- 入力順
		FROM
			VTESURYO VT01,
			TESURYO_BUNPAI T02,
			MGR_KIHON_VIEW VMG1,
			MGR_JUTAKUGINKO MG6,
			VJIKO_ITAKU VJ1,
			MBANK M02,
			MTSUKA M64,
			SCODE MCD1
		WHERE
			VT01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND VT01.TESU_SHURUI_CD IN ('11', '12')
			AND VT01.JTK_KBN = '1'
			AND VT01.ALL_TESU_KNGK > 0
			AND VT01.ITAKU_KAISHA_CD = T02.ITAKU_KAISHA_CD
			AND VT01.MGR_CD = T02.MGR_CD
			AND VT01.TESU_SHURUI_CD = T02.TESU_SHURUI_CD
			AND VT01.CHOKYU_YMD LIKE l_inKijunYm || '%'
			AND VT01.CHOKYU_KJT = T02.CHOKYU_KJT
			AND VT01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
			AND VT01.MGR_CD = VMG1.MGR_CD
			AND VT01.TSUKA_CD = M64.TSUKA_CD
			AND MCD1.CODE_SHUBETSU = '111'
			AND VT01.TESU_SHURUI_CD = MCD1.CODE_VALUE
			AND MG6.ITAKU_KAISHA_CD = T02.ITAKU_KAISHA_CD
			AND MG6.MGR_CD = T02.MGR_CD
			AND MG6.FINANCIAL_SECURITIES_KBN = T02.FINANCIAL_SECURITIES_KBN
			AND MG6.BANK_CD = T02.BANK_CD
			AND T02.FINANCIAL_SECURITIES_KBN = M02.FINANCIAL_SECURITIES_KBN
			AND T02.BANK_CD = M02.BANK_CD
			AND VJ1.KAIIN_ID = l_inItakuKaishaCd
			AND (trim(both VT01.ISIN_CD) IS NOT NULL AND (trim(both VT01.ISIN_CD))::text <> '')
			AND T02.FINANCIAL_SECURITIES_KBN = VJ1.OWN_FINANCIAL_SECURITIES_KBN
			AND T02.BANK_CD = VJ1.OWN_BANK_CD 
		ORDER BY
			VT01.TSUKA_CD,
			VT01.CHOKYU_YMD,
			T02.FINANCIAL_SECURITIES_KBN,
			T02.BANK_CD,
			T02.MGR_CD;
	-- 別段預金
	curMeisai_betudan CURSOR FOR
		SELECT
			VT01.DISTRI_YMD,                  -- 分配日
			VT01.TSUKA_CD,                    -- 通貨コード
			VT01.TESU_SHURUI_CD,              -- 手数料種類コード
			M64.TSUKA_NM,                     -- 通貨出力用名称
			T02.FINANCIAL_SECURITIES_KBN || T02.BANK_CD
			AS BANK_CD,                       -- 金融機関区分+コード
			M02.BANK_RNM,                     -- 金融機関略称
			VT01.ISIN_CD,                     -- ＩＳＩＮコード
			VT01.MGR_CD,                      -- 銘柄コード
			VT01.MGR_RNM,                     -- 銘柄略称
			VT01.CHOKYU_YMD,                  -- 徴求日
			MCD1.CODE_RNM AS TESU_SHURUI_RNM, --  手数料種類略称
			T02.DF_TESU_KNGK,                 -- 分配手数料（税抜）
			T02.DF_TESU_SZEI,                 -- 分配手数料消費税
			CASE WHEN 				VT01.DATA_SAKUSEI_KBN || VT01.SHORI_KBN='21' THEN  T02.HOSEI_DF_TESU_KNGK  ELSE 0 END  AS HOSEI_DF_TESU_KNGK,          -- 補正額_分配手数料（税抜）
			CASE WHEN 				VT01.DATA_SAKUSEI_KBN || VT01.SHORI_KBN='21' THEN  T02.HOSEI_DF_TESU_SZEI  ELSE 0 END  AS HOSEI_DF_TESU_SZEI,          -- 補正額_分配手数料消費税
			MG6.INPUT_NUM                      -- 入力順
		FROM
			VTESURYO VT01,
			TESURYO_BUNPAI T02,
			MGR_KIHON_VIEW VMG1,
			MGR_JUTAKUGINKO MG6,
			VJIKO_ITAKU VJ1,
			MBANK M02,
			MTSUKA M64,
			SCODE MCD1
		WHERE
			VT01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND VT01.TESU_SHURUI_CD IN ('11', '12')
			AND VT01.JTK_KBN = '1'
			AND VT01.ALL_TESU_KNGK > 0
			AND VT01.ITAKU_KAISHA_CD = T02.ITAKU_KAISHA_CD
			AND VT01.MGR_CD = T02.MGR_CD
			AND VT01.TESU_SHURUI_CD = T02.TESU_SHURUI_CD
			AND VT01.DISTRI_YMD LIKE l_inKijunYm || '%'
			AND VT01.CHOKYU_KJT = T02.CHOKYU_KJT
			AND VT01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
			AND VT01.MGR_CD = VMG1.MGR_CD
			AND VT01.TSUKA_CD = M64.TSUKA_CD
			AND MCD1.CODE_SHUBETSU = '111'
			AND VT01.TESU_SHURUI_CD = MCD1.CODE_VALUE
			AND MG6.ITAKU_KAISHA_CD = T02.ITAKU_KAISHA_CD
			AND MG6.MGR_CD = T02.MGR_CD
			AND MG6.FINANCIAL_SECURITIES_KBN = T02.FINANCIAL_SECURITIES_KBN
			AND MG6.BANK_CD = T02.BANK_CD
			AND T02.FINANCIAL_SECURITIES_KBN = M02.FINANCIAL_SECURITIES_KBN
			AND T02.BANK_CD = M02.BANK_CD
			AND VJ1.KAIIN_ID = l_inItakuKaishaCd
			AND (trim(both VT01.ISIN_CD) IS NOT NULL AND (trim(both VT01.ISIN_CD))::text <> '')
			AND (
				T02.FINANCIAL_SECURITIES_KBN <> VJ1.OWN_FINANCIAL_SECURITIES_KBN
				OR T02.BANK_CD <> VJ1.OWN_BANK_CD
			) 
		ORDER BY
			VT01.TSUKA_CD,
			VT01.DISTRI_YMD,
			T02.FINANCIAL_SECURITIES_KBN,
			T02.BANK_CD,
			VT01.CHOKYU_YMD,
			T02.MGR_CD;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	CALL pkLog.debug(l_inUserId, C_REPORT_ID, C_PROCEDURE_ID || ' START');
	-- 入力パラメータのチェック
	IF coalesce(l_inKijunYm::text, '') = ''
		OR coalesce(l_inItakuKaishaCd::text, '') = ''
		OR coalesce(l_inUserId::text, '') = ''
		OR coalesce(l_inChohyoKbn::text, '') = ''
	THEN
		-- パラメータエラー
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID,3,12), 'パラメータエラー');
		l_outSqlCode := pkconstant.fatal();
		l_outSqlErrM := '';
		RETURN;
	END IF;
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '引数');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '基準年月:"' || l_inKijunYm ||'"');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '委託会社コード:"' || l_inItakuKaishaCd ||'"');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'ユーザーID:"' || l_inUserId ||'"');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票区分:"' || l_inChohyoKbn ||'"');
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
	-- 委託会社略名取得
	BEGIN
		SELECT
			CASE WHEN JIKO_DAIKO_KBN='2' THEN  BANK_RNM  ELSE ' ' END
		INTO STRICT
			gItakuKaishaRnm
		FROM VJIKO_ITAKU
		WHERE KAIIN_ID = l_inItakuKaishaCd;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			gItakuKaishaRnm := '';
	END;
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
		WHERE
			KEY_CD = l_inItakuKaishaCd
			AND USER_ID = l_inUserId
			AND CHOHYO_KBN = l_inChohyoKbn
			AND SAKUSEI_YMD = gGyomuYmd
			AND CHOHYO_ID = C_REPORT_ID;
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '削除条件');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '識別コード:"' || l_inItakuKaishaCd ||'"');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'ユーザーID:"' || l_inUserId ||'"');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票区分:"' || l_inChohyoKbn ||'"');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '作成日付:"' || gGyomuYmd ||'"');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票ID:"' || C_REPORT_ID ||'"');
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, gGyomuYmd, C_REPORT_ID);
	-- 信託報酬・期中管理手数料伝票明細表（信託手数料）START=======================================================================
	-- 初期化
	gKeyTsukaCd := ' ';   -- 通貨コード（キーブレイク用）
	gKeyDistriYmd := ' '; -- 分配日（キーブレイク用）
	gKeyBankCd  := ' ';   -- 金融機関コード（キーブレイク用）
	-- 信託手数料のデータ取得 
	recMeisai := ARRAY[]::spipx004k00r01_type_record[];
	FOR rec IN curMeisai_sintaku
	LOOP
		recMeisai := array_append(recMeisai, NULL);
		recMeisai[gLopNo+1].gDistriYmd       := rec.DISTRI_YMD;         -- 分配日
		recMeisai[gLopNo+1].gTsukaCd         := rec.TSUKA_CD;           -- 通貨コード
		recMeisai[gLopNo+1].gTesuShuruiCd    := rec.TESU_SHURUI_CD;     -- 手数料種類コード
		recMeisai[gLopNo+1].gTsukaNm         := rec.TSUKA_NM;           -- 通貨出力用名称
		recMeisai[gLopNo+1].gBankCd          := rec.BANK_CD;            -- 金融機関区分+コード
		recMeisai[gLopNo+1].gBankRnm         := rec.BANK_RNM;           -- 金融機関略称
		recMeisai[gLopNo+1].gIsinCd          := rec.ISIN_CD;            -- ＳＩＮコード
		recMeisai[gLopNo+1].gMgrCd           := rec.MGR_CD;             -- 銘柄コード
		recMeisai[gLopNo+1].gMgrRnm          := rec.MGR_RNM;            -- 銘柄略称
		recMeisai[gLopNo+1].gChokyuYmd       := rec.CHOKYU_YMD;         -- 徴求日
		recMeisai[gLopNo+1].gTesuShuruiRNm   := rec.TESU_SHURUI_RNM;    -- 手数料種類略称
		recMeisai[gLopNo+1].gDfTesuKngk      := rec.DF_TESU_KNGK;       -- 分配手数料（税抜）
		recMeisai[gLopNo+1].gDfTesuSzei      := rec.DF_TESU_SZEI;       -- 分配手数料消費税
		recMeisai[gLopNo+1].gHoseiDfTesuKngk := rec.HOSEI_DF_TESU_KNGK; -- 補正額_分配手数料（税抜）
		recMeisai[gLopNo+1].gHoseiDfTesuSzei := rec.HOSEI_DF_TESU_SZEI; -- 補正額_分配手数料消費税
		recMeisai[gLopNo+1].gInputNum        := rec.INPUT_NUM;          -- 入力順
		-- 分配額と内消費税計算
		-- 補正分を加算する
		recMeisai[gLopNo+1].gBunpaiKngk := rec.DF_TESU_KNGK + rec.DF_TESU_SZEI + rec.HOSEI_DF_TESU_KNGK + rec.HOSEI_DF_TESU_SZEI; -- 分配額
		recMeisai[gLopNo+1].gBunpaiSzei := rec.DF_TESU_SZEI + rec.HOSEI_DF_TESU_SZEI;                                             -- 内消費税
		-- ループ番号のカウント
		gLopNo := gLopNo + 1;
	END LOOP;
	-- 対象データ有りの処理 START
	IF gLopNo >= 1 THEN
		FOR i IN 1..coalesce(cardinality(recMeisai), 0) LOOP
			gSeqNo := gSeqNo + 1;
			-- 分配日合計データ出力判定
			IF i <> 1 AND (
				gKeyTsukaCd <> recMeisai[i].gTsukaCd
				OR gKeyDistriYmd <> recMeisai[i].gDistriYmd
			) THEN
				-- ブレイクキーを退避
				gKeyTsukaCd := recMeisai[i].gTsukaCd;
				gKeyDistriYmd := recMeisai[i].gDistriYmd;
				-- 帳票ワークへ分配日合計データを出力
				v_item := ROW();
				v_item.l_inItem001 := C_TITLE_SINTAKU;             -- 帳票タイトル
				v_item.l_inItem002 := gItakuKaishaRnm;             -- 委託会社略名
				v_item.l_inItem003 := l_inUserId;                  -- ユーザID
				v_item.l_inItem004 := recMeisai[i-1].gDistriYmd;   -- 分配日
				v_item.l_inItem005 := recMeisai[i-1].gTsukaCd;     -- 通貨コード
				v_item.l_inItem006 := recMeisai[i-1].gTsukaNm;     -- 通貨出力用名称
				v_item.l_inItem007 := recMeisai[i-1].gBankCd;      -- 金融機関コード
				v_item.l_inItem012 := '分配日合計';               -- 合計タイトル
				v_item.l_inItem013 := gBunpaiKngkSum;              -- 分配金額分配日合計
				v_item.l_inItem014 := gBunpaiSzeiSum;              -- 内消費税分配日合計
				v_item.l_inItem015 := gFmtHakkoKngk;               -- 分配額フォーマット
				v_item.l_inItem016 := gFmtTesuSzei;                -- 内消費税フォーマット
				v_item.l_inItem017 := C_REPORT_ID;                 -- 帳票ID
				v_item.l_inItem018 := '1';                         -- 帳票名で改ページフラッグ
				
				CALL pkPrint.insertData(
					l_inKeyCd       => l_inItakuKaishaCd,          -- 識別コード
					l_inUserId      => l_inUserId,                 -- ユーザID
					l_inChohyoKbn   => l_inChohyoKbn,              -- 帳票区分
					l_inSakuseiYmd  => gGyomuYmd,                  -- 作成年月日
					l_inChohyoId    => C_REPORT_ID,                -- 帳票ID
					l_inSeqNo       => gSeqNo,                     -- 連番
					l_inHeaderFlg   => 1,                          -- ヘッダフラグ
					l_inItem        => v_item,                     -- アイテム
					l_inKousinId    => l_inUserId,                 -- 更新者ID
					l_inSakuseiId   => l_inUserId                  -- 作成者ID
				);
				-- 分配日合計のクリア
				gBunpaiKngkSum := 0;
				gBunpaiSzeiSum := 0;
				gSeqNo := gSeqNo + 1;
			ELSE
				-- １件目の場合、ブレイクキーを退避
				IF i = 1 THEN
					gKeyTsukaCd := recMeisai[i].gTsukaCd;
					gKeyDistriYmd := recMeisai[i].gDistriYmd;
				END IF;
			END IF;
			-- 書式フォーマットの設定
			IF recMeisai[i].gTsukaCd = 'JPY' THEN
				gFmtHakkoKngk := C_FMT_HAKKO_KNGK_J;
				gFmtTesuSzei  := C_FMT_TESU_SZEI_J;
			ELSE
				gFmtHakkoKngk := C_FMT_HAKKO_KNGK_F;
				gFmtTesuSzei  := C_FMT_TESU_SZEI_F;
			END IF;
			-- 分配日合計を集計
			gBunpaiKngkSum := gBunpaiKngkSum + recMeisai[i].gBunpaiKngk; -- 分配額分配日合計(通貨毎)
			gBunpaiSzeiSum := gBunpaiSzeiSum + recMeisai[i].gBunpaiSzei; -- 内消費税分配日合計(通貨毎)
			-- 帳票ワークへ明細データを出力
			v_item := ROW();
			v_item.l_inItem001 := C_TITLE_SINTAKU;                  -- 帳票タイトル
			v_item.l_inItem002 := gItakuKaishaRnm;                  -- 委託会社略名
			v_item.l_inItem003 := l_inUserId;                       -- ユーザID
			v_item.l_inItem004 := recMeisai[i].gDistriYmd;          -- 分配日
			v_item.l_inItem005 := recMeisai[i].gTsukaCd;            -- 通貨コード
			v_item.l_inItem006 := recMeisai[i].gTsukaNm;            -- 通貨出力用名称
			v_item.l_inItem007 := recMeisai[i].gBankCd;             -- 金融機関コード
			v_item.l_inItem008 := recMeisai[i].gBankRnm;            -- 金融機関略称
			v_item.l_inItem009 := recMeisai[i].gIsinCd;             -- ＩＳＩＮコード
			v_item.l_inItem010 := recMeisai[i].gMgrCd;              -- 銘柄コード
			v_item.l_inItem011 := recMeisai[i].gMgrRnm;             -- 銘柄略称
			v_item.l_inItem012 := SPIPX004K00R01_getYmd(recMeisai[i].gChokyuYmd); -- 徴求日
			v_item.l_inItem013 := recMeisai[i].gBunpaiKngk;         -- 分配金額
			v_item.l_inItem014 := recMeisai[i].gBunpaiSzei;         -- 内消費税
			v_item.l_inItem015 := gFmtHakkoKngk;                    -- 分配額フォーマット
			v_item.l_inItem016 := gFmtTesuSzei;                     -- 内消費税フォーマット
			v_item.l_inItem017 := C_REPORT_ID;                      -- 帳票ID
			v_item.l_inItem018 := '1';                              -- 帳票名で改ページフラッグ
			
			CALL pkPrint.insertData(
				l_inKeyCd       => l_inItakuKaishaCd,               -- 識別コード
				l_inUserId      => l_inUserId,                      -- ユーザID
				l_inChohyoKbn   => l_inChohyoKbn,                   -- 帳票区分
				l_inSakuseiYmd  => gGyomuYmd,                       -- 作成年月日
				l_inChohyoId    => C_REPORT_ID,                     -- 帳票ID
				l_inSeqNo       => gSeqNo,                          -- 連番
				l_inHeaderFlg   => 1,                               -- ヘッダフラグ
				l_inItem        => v_item,                          -- アイテム
				l_inKousinId    => l_inUserId,                      -- 更新者ID
				l_inSakuseiId   => l_inUserId                       -- 作成者ID
			);
		END LOOP;
		-- 最後の合計行を出力
		gSeqNo := gSeqNo + 1;
		-- 帳票ワークへ分配日合計データを出力
		v_item := ROW();
		v_item.l_inItem001 := C_TITLE_SINTAKU;                           -- 帳票タイトル
		v_item.l_inItem002 := gItakuKaishaRnm;                           -- 委託会社略名
		v_item.l_inItem003 := l_inUserId;                                -- ユーザID
		v_item.l_inItem004 := recMeisai[coalesce(cardinality(recMeisai), 0)].gDistriYmd;   -- 分配日
		v_item.l_inItem005 := recMeisai[coalesce(cardinality(recMeisai), 0)].gTsukaCd;     -- 通貨コード
		v_item.l_inItem006 := recMeisai[coalesce(cardinality(recMeisai), 0)].gTsukaNm;     -- 通貨出力用名称
		v_item.l_inItem007 := recMeisai[coalesce(cardinality(recMeisai), 0)].gBankCd;      -- 金融機関コード
		v_item.l_inItem012 := '分配日合計';                             -- 合計タイトル
		v_item.l_inItem013 := gBunpaiKngkSum;                            -- 分配金額分配日合計
		v_item.l_inItem014 := gBunpaiSzeiSum;                            -- 内消費税分配日合計
		v_item.l_inItem015 := gFmtHakkoKngk;                             -- 分配額フォーマット
		v_item.l_inItem016 := gFmtTesuSzei;                              -- 内消費税フォーマット
		v_item.l_inItem017 := C_REPORT_ID;                               -- 帳票ID
		v_item.l_inItem018 := '1';                                       -- 帳票名で改ページフラッグ
		
		CALL pkPrint.insertData(
			l_inKeyCd       => l_inItakuKaishaCd,                        -- 識別コード
			l_inUserId      => l_inUserId,                               -- ユーザID
			l_inChohyoKbn   => l_inChohyoKbn,                            -- 帳票区分
			l_inSakuseiYmd  => gGyomuYmd,                                -- 作成年月日
			l_inChohyoId    => C_REPORT_ID,                              -- 帳票ID
			l_inSeqNo       => gSeqNo,                                   -- 連番
			l_inHeaderFlg   => 1,                                        -- ヘッダフラグ
			l_inItem        => v_item,                                   -- アイテム
			l_inKousinId    => l_inUserId,                               -- 更新者ID
			l_inSakuseiId   => l_inUserId                                -- 作成者ID
		);
		-- 分配日合計のクリア
		gBunpaiKngkSum := 0;
		gBunpaiSzeiSum := 0;
	ELSE
		gSeqNo := gSeqNo + 1;
		-- 明細レコード追加（対象データなし）
		v_item := ROW();
		v_item.l_inItem001 := C_TITLE_SINTAKU;   -- 帳票タイトル
		v_item.l_inItem002 := gItakuKaishaRnm;   -- 委託会社略名
		v_item.l_inItem003 := l_inUserId;        -- ユーザID
		v_item.l_inItem017 := C_REPORT_ID;       -- 帳票ID
		v_item.l_inItem018 := '1';               -- 帳票名で改ページフラッグ
		v_item.l_inItem019 := '対象データなし';  -- 対象データなし
		
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd, -- 識別コード
			l_inUserId     => l_inUserId,        -- ユーザID
			l_inChohyoKbn  => l_inChohyoKbn,     -- 帳票区分
			l_inSakuseiYmd => gGyomuYmd,         -- 業務日付
			l_inChohyoId   => C_REPORT_ID,       -- 帳票ID
			l_inSeqNo      => gSeqNo,            -- 連番
			l_inHeaderFlg  => 1,                 -- ヘッダフラグ
			l_inItem       => v_item,            -- アイテム
			l_inKousinId   => l_inUserId,        -- 更新者
			l_inSakuseiId  => l_inUserId         -- 作成者
		);
	END IF;
	-- 信託報酬・期中管理手数料伝票明細表（信託手数料）END=========================================================================
	-- 信託報酬・期中管理手数料伝票明細表（別段預金）START=========================================================================
	-- 初期化
	gKeyTsukaCd := ' ';   -- 通貨コード（キーブレイク用）
	gKeyDistriYmd := ' '; -- 分配日（キーブレイク用）
	gKeyBankCd  := ' ';   -- 金融機関コード（キーブレイク用）
	gLopNo := 0;
	-- 別段預金のデータ取得 START
	recMeisaiBetudan := ARRAY[]::spipx004k00r01_type_record[];
	FOR rec IN curMeisai_betudan
	LOOP
		recMeisaiBetudan := array_append(recMeisaiBetudan, NULL);
		recMeisaiBetudan[gLopNo+1].gDistriYmd       := rec.DISTRI_YMD;         -- 分配日
		recMeisaiBetudan[gLopNo+1].gTsukaCd         := rec.TSUKA_CD;           -- 通貨コード
		recMeisaiBetudan[gLopNo+1].gTesuShuruiCd    := rec.TESU_SHURUI_CD;     -- 手数料種類コード
		recMeisaiBetudan[gLopNo+1].gTsukaNm         := rec.TSUKA_NM;           -- 通貨出力用名称
		recMeisaiBetudan[gLopNo+1].gBankCd          := rec.BANK_CD;            -- 金融機関区分+コード
		recMeisaiBetudan[gLopNo+1].gBankRnm         := rec.BANK_RNM;           -- 金融機関略称
		recMeisaiBetudan[gLopNo+1].gIsinCd          := rec.ISIN_CD;            -- ＩＳＩＮコード
		recMeisaiBetudan[gLopNo+1].gMgrCd           := rec.MGR_CD;             -- 銘柄コード
		recMeisaiBetudan[gLopNo+1].gMgrRnm          := rec.MGR_RNM;            -- 銘柄略称
		recMeisaiBetudan[gLopNo+1].gChokyuYmd       := rec.CHOKYU_YMD;         -- 徴求日
		recMeisaiBetudan[gLopNo+1].gTesuShuruiRNm   := rec.TESU_SHURUI_RNM;    -- 手数料種類略称
		recMeisaiBetudan[gLopNo+1].gDfTesuKngk      := rec.DF_TESU_KNGK;       -- 分配手数料（税抜）
		recMeisaiBetudan[gLopNo+1].gDfTesuSzei      := rec.DF_TESU_SZEI;       -- 分配手数料消費税
		recMeisaiBetudan[gLopNo+1].gHoseiDfTesuKngk := rec.HOSEI_DF_TESU_KNGK; -- 補正額_分配手数料（税抜）
		recMeisaiBetudan[gLopNo+1].gHoseiDfTesuSzei := rec.HOSEI_DF_TESU_SZEI; -- 補正額_分配手数料消費税
		recMeisaiBetudan[gLopNo+1].gInputNum        := rec.INPUT_NUM;          -- 入力順
		-- 分配額と内消費税計算
		-- 補正分を加算する
		recMeisaiBetudan[gLopNo+1].gBunpaiKngk := rec.DF_TESU_KNGK + rec.DF_TESU_SZEI + rec.HOSEI_DF_TESU_KNGK + rec.HOSEI_DF_TESU_SZEI; -- 分配額
		recMeisaiBetudan[gLopNo+1].gBunpaiSzei := rec.DF_TESU_SZEI + rec.HOSEI_DF_TESU_SZEI;                                             -- 内消費税
		-- ループ番号のカウント
		gLopNo := gLopNo + 1;
	END LOOP;
	-- 対象データ有りの処理 start
	IF gLopNo >=1 THEN
		FOR i IN 1..coalesce(cardinality(recMeisaiBetudan), 0) LOOP
			gSeqNo := gSeqNo + 1;
			-- 各行合計データ出力判定
			IF i <> 1 AND (
				gKeyTsukaCd <> recMeisaiBetudan[i].gTsukaCd
				OR gKeyDistriYmd <> recMeisaiBetudan[i].gDistriYmd
				OR gKeyBankCd <> recMeisaiBetudan[i].gBankCd
			) THEN
				-- ブレイクキーを退避
				gKeyBankCd  := recMeisaiBetudan[i].gBankCd;
				-- 帳票ワークへ各行合計データを出力
				v_item := ROW();
				v_item.l_inItem001 := C_TITLE_BETUDAN;                    -- 帳票タイトル
				v_item.l_inItem002 := gItakuKaishaRnm;                    -- 委託会社略名
				v_item.l_inItem003 := l_inUserId;                         -- ユーザID
				v_item.l_inItem004 := recMeisaiBetudan[i-1].gDistriYmd;   -- 分配日
				v_item.l_inItem005 := recMeisaiBetudan[i-1].gTsukaCd;     -- 通貨コード
				v_item.l_inItem006 := recMeisaiBetudan[i-1].gTsukaNm;     -- 通貨出力用名称
				v_item.l_inItem007 := recMeisaiBetudan[i-1].gBankCd;      -- 金融機関コード
				v_item.l_inItem012 := '各行合計';                        -- 合計タイトル
				v_item.l_inItem013 := gBunpaiKngkSumFJtk;                 -- 分配額各行合計(副受託)
				v_item.l_inItem014 := gBunpaiSzeiSumFJtk;                 -- 内消費税各行合計(副受託)
				v_item.l_inItem015 := gFmtHakkoKngk;                      -- 分配額フォーマット
				v_item.l_inItem016 := gFmtTesuSzei;                       -- 内消費税フォーマット
				v_item.l_inItem017 := C_REPORT_ID;                        -- 帳票ID
				v_item.l_inItem018 := '2';                                -- 帳票名で改ページフラッグ
				
				CALL pkPrint.insertData(
					l_inKeyCd       => l_inItakuKaishaCd,                 -- 識別コード
					l_inUserId      => l_inUserId,                        -- ユーザID
					l_inChohyoKbn   => l_inChohyoKbn,                     -- 帳票区分
					l_inSakuseiYmd  => gGyomuYmd,                         -- 作成年月日
					l_inChohyoId    => C_REPORT_ID,                       -- 帳票ID
					l_inSeqNo       => gSeqNo,                            -- 連番
					l_inHeaderFlg   => 1,                                 -- ヘッダフラグ
					l_inItem        => v_item,                            -- アイテム
					l_inKousinId    => l_inUserId,                        -- 更新者ID
					l_inSakuseiId   => l_inUserId                         -- 作成者ID
				);
				-- 各行合計のクリア
				gBunpaiKngkSumFJtk := 0;
				gBunpaiSzeiSumFJtk := 0;
				gSeqNo := gSeqNo + 1;
				-- 分配日合計データ出力判定
				IF (
					gKeyTsukaCd <> recMeisaiBetudan[i].gTsukaCd
					OR gKeyDistriYmd <> recMeisaiBetudan[i].gDistriYmd
				) THEN
					-- ブレイクキーを退避
					gKeyTsukaCd := recMeisaiBetudan[i].gTsukaCd;
					gKeyDistriYmd := recMeisaiBetudan[i].gDistriYmd;
					-- 帳票ワークへ分配日合計データを出力
					v_item := ROW();
					v_item.l_inItem001 := C_TITLE_BETUDAN;                    -- 帳票タイトル
					v_item.l_inItem002 := gItakuKaishaRnm;                    -- 委託会社略名
					v_item.l_inItem003 := l_inUserId;                         -- ユーザID
					v_item.l_inItem004 := recMeisaiBetudan[i-1].gDistriYmd;   -- 分配日
					v_item.l_inItem005 := recMeisaiBetudan[i-1].gTsukaCd;     -- 通貨コード
					v_item.l_inItem006 := recMeisaiBetudan[i-1].gTsukaNm;     -- 通貨出力用名称
					v_item.l_inItem007 := recMeisaiBetudan[i-1].gBankCd;      -- 金融機関コード
					v_item.l_inItem012 := '分配日合計';                      -- 合計タイトル
					v_item.l_inItem013 := gBunpaiKngkSum;                     -- 分配額各行合計(副受託)
					v_item.l_inItem014 := gBunpaiSzeiSum;                     -- 内消費税各行合計(副受託)
					v_item.l_inItem015 := gFmtHakkoKngk;                      -- 分配額フォーマット
					v_item.l_inItem016 := gFmtTesuSzei;                       -- 内消費税フォーマット
					v_item.l_inItem017 := C_REPORT_ID;                        -- 帳票ID
					v_item.l_inItem018 := '2';                                -- 帳票名で改ページフラッグ
					
					CALL pkPrint.insertData(
						l_inKeyCd       => l_inItakuKaishaCd,                 -- 識別コード
						l_inUserId      => l_inUserId,                        -- ユーザID
						l_inChohyoKbn   => l_inChohyoKbn,                     -- 帳票区分
						l_inSakuseiYmd  => gGyomuYmd,                         -- 作成年月日
						l_inChohyoId    => C_REPORT_ID,                       -- 帳票ID
						l_inSeqNo       => gSeqNo,                            -- 連番
						l_inHeaderFlg   => 1,                                 -- ヘッダフラグ
						l_inItem        => v_item,                            -- アイテム
						l_inKousinId    => l_inUserId,                        -- 更新者ID
						l_inSakuseiId   => l_inUserId                         -- 作成者ID
					);
					-- 分配日合計のクリア
					gBunpaiKngkSum := 0;
					gBunpaiSzeiSum := 0;
					gSeqNo := gSeqNo + 1;
				END IF;
			ELSE
				-- １件目の場合、ブレイクキーを退避
				IF i = 1 THEN
					gKeyTsukaCd := recMeisaiBetudan[i].gTsukaCd;
					gKeyDistriYmd := recMeisaiBetudan[i].gDistriYmd;
					gKeyBankCd  := recMeisaiBetudan[i].gBankCd;
				END IF;
			END IF;
			-- 書式フォーマットの設定
			IF recMeisaiBetudan[i].gTsukaCd = 'JPY' THEN
				gFmtHakkoKngk := C_FMT_HAKKO_KNGK_J;
				gFmtTesuSzei  := C_FMT_TESU_SZEI_J;
			ELSE
				gFmtHakkoKngk := C_FMT_HAKKO_KNGK_F;
				gFmtTesuSzei  := C_FMT_TESU_SZEI_F;
			END IF;
			-- 各行合計を集計
			gBunpaiKngkSumFJtk := gBunpaiKngkSumFJtk + recMeisaiBetudan[i].gBunpaiKngk; -- 各行分配額合計(金融機関コード毎)
			gBunpaiSzeiSumFJtk := gBunpaiSzeiSumFJtk + recMeisaiBetudan[i].gBunpaiSzei; -- 各行内消費税合計(金融機関コード毎)
			-- 分配日合計を集計
			gBunpaiKngkSum := gBunpaiKngkSum + recMeisaiBetudan[i].gBunpaiKngk; -- 分配額分配日合計(通貨毎)
			gBunpaiSzeiSum := gBunpaiSzeiSum + recMeisaiBetudan[i].gBunpaiSzei; -- 内消費税分配日合計(通貨毎)
			-- 帳票ワークへ明細データを出力
			v_item := ROW();
			v_item.l_inItem001 := C_TITLE_BETUDAN;                         -- 帳票タイトル
			v_item.l_inItem002 := gItakuKaishaRnm;                         -- 委託会社略名
			v_item.l_inItem003 := l_inUserId;                              -- ユーザID
			v_item.l_inItem004 := recMeisaiBetudan[i].gDistriYmd;          -- 分配日
			v_item.l_inItem005 := recMeisaiBetudan[i].gTsukaCd;            -- 通貨コード
			v_item.l_inItem006 := recMeisaiBetudan[i].gTsukaNm;            -- 通貨出力用名称
			v_item.l_inItem007 := recMeisaiBetudan[i].gBankCd;             -- 金融機関コード
			v_item.l_inItem008 := recMeisaiBetudan[i].gBankRnm;            -- 金融機関略称
			v_item.l_inItem009 := recMeisaiBetudan[i].gIsinCd;             -- ＩＳＩＮコード
			v_item.l_inItem010 := recMeisaiBetudan[i].gMgrCd;              -- 銘柄コード
			v_item.l_inItem011 := recMeisaiBetudan[i].gMgrRnm;             -- 銘柄略称
			v_item.l_inItem012 := SPIPX004K00R01_getYmd(recMeisaiBetudan[i].gChokyuYmd); -- 徴求日
			v_item.l_inItem013 := recMeisaiBetudan[i].gBunpaiKngk;         -- 分配金額
			v_item.l_inItem014 := recMeisaiBetudan[i].gBunpaiSzei;         -- 内消費税
			v_item.l_inItem015 := gFmtHakkoKngk;                           -- 分配額フォーマット
			v_item.l_inItem016 := gFmtTesuSzei;                            -- 内消費税フォーマット
			v_item.l_inItem017 := C_REPORT_ID;                             -- 帳票ID
			v_item.l_inItem018 := '2';                                     -- 帳票名で改ページフラッグ
			
			CALL pkPrint.insertData(
				l_inKeyCd       => l_inItakuKaishaCd,                      -- 識別コード
				l_inUserId      => l_inUserId,                             -- ユーザID
				l_inChohyoKbn   => l_inChohyoKbn,                          -- 帳票区分
				l_inSakuseiYmd  => gGyomuYmd,                              -- 作成年月日
				l_inChohyoId    => C_REPORT_ID,                            -- 帳票ID
				l_inSeqNo       => gSeqNo,                                 -- 連番
				l_inHeaderFlg   => 1,                                      -- ヘッダフラグ
				l_inItem        => v_item,                                 -- アイテム
				l_inKousinId    => l_inUserId,                             -- 更新者ID
				l_inSakuseiId   => l_inUserId                              -- 作成者ID
			);
		END LOOP;
		-- 最後の各行合計行を出力
		gSeqNo := gSeqNo + 1;
		-- 帳票ワークへ各行合計データを出力
		v_item := ROW();
		v_item.l_inItem001 := C_TITLE_BETUDAN;                                         -- 帳票タイトル
		v_item.l_inItem002 := gItakuKaishaRnm;                                         -- 委託会社略名
		v_item.l_inItem003 := l_inUserId;                                              -- ユーザID
		v_item.l_inItem004 := recMeisaiBetudan[coalesce(cardinality(recMeisaiBetudan), 0)].gDistriYmd;   -- 分配日
		v_item.l_inItem005 := recMeisaiBetudan[coalesce(cardinality(recMeisaiBetudan), 0)].gTsukaCd;     -- 通貨コード
		v_item.l_inItem006 := recMeisaiBetudan[coalesce(cardinality(recMeisaiBetudan), 0)].gTsukaNm;     -- 通貨出力用名称
		v_item.l_inItem007 := recMeisaiBetudan[coalesce(cardinality(recMeisaiBetudan), 0)].gBankCd;      -- 金融機関コード
		v_item.l_inItem012 := '各行合計';                                             -- 合計タイトル
		v_item.l_inItem013 := gBunpaiKngkSumFJtk;                                      -- 分配額各行合計(副受託)
		v_item.l_inItem014 := gBunpaiSzeiSumFJtk;                                      -- 内消費税各行合計(副受託)
		v_item.l_inItem015 := gFmtHakkoKngk;                                           -- 分配額フォーマット
		v_item.l_inItem016 := gFmtTesuSzei;                                            -- 内消費税フォーマット
		v_item.l_inItem017 := C_REPORT_ID;                                             -- 帳票ID
		v_item.l_inItem018 := '2';                                                     -- 帳票名で改ページフラッグ
		
		CALL pkPrint.insertData(
			l_inKeyCd       => l_inItakuKaishaCd,                                      -- 識別コード
			l_inUserId      => l_inUserId,                                             -- ユーザID
			l_inChohyoKbn   => l_inChohyoKbn,                                          -- 帳票区分
			l_inSakuseiYmd  => gGyomuYmd,                                              -- 作成年月日
			l_inChohyoId    => C_REPORT_ID,                                            -- 帳票ID
			l_inSeqNo       => gSeqNo,                                                 -- 連番
			l_inHeaderFlg   => 1,                                                      -- ヘッダフラグ
			l_inItem        => v_item,                                                 -- アイテム
			l_inKousinId    => l_inUserId,                                             -- 更新者ID
			l_inSakuseiId   => l_inUserId                                              -- 作成者ID
		);
		-- 各行合計のクリア
		gBunpaiKngkSumFJtk := 0;
		gBunpaiSzeiSumFJtk := 0;
		-- 最後の合計行を出力
		gSeqNo := gSeqNo + 1;
		-- 帳票ワークへ分配日合計データを出力
		v_item := ROW();
		v_item.l_inItem001 := C_TITLE_BETUDAN;                                         -- 帳票タイトル
		v_item.l_inItem002 := gItakuKaishaRnm;                                         -- 委託会社略名
		v_item.l_inItem003 := l_inUserId;                                              -- ユーザID
		v_item.l_inItem004 := recMeisaiBetudan[coalesce(cardinality(recMeisaiBetudan), 0)].gDistriYmd;   -- 分配日
		v_item.l_inItem005 := recMeisaiBetudan[coalesce(cardinality(recMeisaiBetudan), 0)].gTsukaCd;     -- 通貨コード
		v_item.l_inItem006 := recMeisaiBetudan[coalesce(cardinality(recMeisaiBetudan), 0)].gTsukaNm;     -- 通貨出力用名称
		v_item.l_inItem007 := recMeisaiBetudan[coalesce(cardinality(recMeisaiBetudan), 0)].gBankCd;      -- 金融機関コード
		v_item.l_inItem012 := '分配日合計';                                           -- 合計タイトル
		v_item.l_inItem013 := gBunpaiKngkSum;                                          -- 分配額各行合計(副受託)
		v_item.l_inItem014 := gBunpaiSzeiSum;                                          -- 内消費税各行合計(副受託)
		v_item.l_inItem015 := gFmtHakkoKngk;                                           -- 分配額フォーマット
		v_item.l_inItem016 := gFmtTesuSzei;                                            -- 内消費税フォーマット
		v_item.l_inItem017 := C_REPORT_ID;                                             -- 帳票ID
		v_item.l_inItem018 := '2';                                                     -- 帳票名で改ページフラッグ
		
		CALL pkPrint.insertData(
			l_inKeyCd       => l_inItakuKaishaCd,                                      -- 識別コード
			l_inUserId      => l_inUserId,                                             -- ユーザID
			l_inChohyoKbn   => l_inChohyoKbn,                                          -- 帳票区分
			l_inSakuseiYmd  => gGyomuYmd,                                              -- 作成年月日
			l_inChohyoId    => C_REPORT_ID,                                            -- 帳票ID
			l_inSeqNo       => gSeqNo,                                                 -- 連番
			l_inHeaderFlg   => 1,                                                      -- ヘッダフラグ
			l_inItem        => v_item,                                                 -- アイテム
			l_inKousinId    => l_inUserId,                                             -- 更新者ID
			l_inSakuseiId   => l_inUserId                                              -- 作成者ID
		);
		-- 分配日合計のクリア
		gBunpaiKngkSum := 0;
		gBunpaiSzeiSum := 0;
	ELSE
		gSeqNo := gSeqNo + 1;
		-- 明細レコード追加（対象データなし）
		v_item := ROW();
		v_item.l_inItem001 := C_TITLE_BETUDAN;   -- 帳票タイトル
		v_item.l_inItem002 := gItakuKaishaRnm;   -- 委託会社略名
		v_item.l_inItem003 := l_inUserId;        -- ユーザID
		v_item.l_inItem017 := C_REPORT_ID;       -- 帳票ID
		v_item.l_inItem018 := '2';               -- 帳票名で改ページフラッグ
		v_item.l_inItem019 := '対象データなし';  -- 対象データなし
		
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd, -- 識別コード
			l_inUserId     => l_inUserId,        -- ユーザID
			l_inChohyoKbn  => l_inChohyoKbn,     -- 帳票区分
			l_inSakuseiYmd => gGyomuYmd,         -- 業務日付
			l_inChohyoId   => C_REPORT_ID,       -- 帳票ID
			l_inSeqNo      => gSeqNo,            -- 連番
			l_inHeaderFlg  => 1,                 -- ヘッダフラグ
			l_inItem       => v_item,            -- アイテム
			l_inKousinId   => l_inUserId,        -- 更新者
			l_inSakuseiId  => l_inUserId         -- 作成者
		);
	END IF;
	-- 信託報酬・期中管理手数料伝票明細表（別段預金）END===========================================================================
	-- 終了処理
	l_outSqlCode := pkconstant.success();
	l_outSqlErrM := '';
	CALL pkLog.debug(l_inUserId, C_REPORT_ID, C_PROCEDURE_ID ||' END');
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID,3,12), 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID,3,12), 'SQLERRM:' || SQLERRM);
		l_outSqlCode := pkconstant.fatal();
		l_outSqlErrM := SQLSTATE || SQLERRM;
END;
 $body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipx004k00r01 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE, l_inUserId SREPORT_WK.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_inKijunYm text, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spipx004k00r01_getymd (inYmd text) RETURNS varchar AS $body$
DECLARE

	pResult varchar(10);

BEGIN
	IF (inYmd IS NOT NULL AND inYmd::text <> '') THEN
		pResult := SUBSTR(inYmd, 1, 4)
				|| '.'
				|| REPLACE(SUBSTR(inYmd, 5, 1), '0', ' ')
				|| SUBSTR(inYmd, 6, 1)
				|| '.'
				|| REPLACE(SUBSTR(inYmd, 7, 1), '0', ' ')
				|| SUBSTR(inYmd, 8, 1);
	ELSE
		pResult := ' ';
	END IF;
	RETURN pResult;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spipx004k00r01_getymd (inYmd text) FROM PUBLIC;