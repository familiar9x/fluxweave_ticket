




CREATE OR REPLACE PROCEDURE spip02502 ( l_inKijunYm TEXT,		-- 基準年月
 l_inZeimushoCd TEXT,		-- 税務署コード
 l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inUserId TEXT,		-- ユーザーID
 l_inChohyoKbn TEXT,		-- 帳票区分
 l_inGyomuYmd TEXT,		-- 業務日付
 l_outSqlCode OUT integer,		-- リターン値
 l_outSqlErrM OUT text	-- エラーコメント
 ) AS $body$
DECLARE

--
-- * 著作権:Copyright(c)2004
-- * 会社名:JIP
-- * 概要　:顧客宛帳票出力指示画面の入力条件により、利子所得税納付資料（発行体別）を作成する
-- * 引数　:l_inKijunYm		IN	TEXT		基準年月
-- * 　　　 l_inZeimushoCd	IN	TEXT		税務署コード
-- * 　　　 l_inItakuKaishaCd	IN	TEXT		委託会社コード
-- * 　　　 l_inUserId		IN	TEXT		ユーザーID
-- * 　　　 l_inChohyoKbn		IN	TEXT		帳票区分
-- * 　　　 l_inGyomuYmd		IN	TEXT		業務日付
-- * 　　　 l_outSqlCode		OUT	INTEGER		リターン値
-- * 　　　 l_outSqlErrM		OUT	VARCHAR	エラーコメント
-- * 返り値:なし
-- *
-- * @author JIP
-- * @version $Id: SPIP02502.SQL,v 1.17 2015/03/17 06:46:44 takahashi Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付	開発者名		目的
-- * -------------------------------------------------------------------
-- *　2005.02.09	JIP				新規作成
-- *
-- *
-- ***************************************************************************
--
--==============================================================================
--					デバッグ機能													
--==============================================================================
	DEBUG	numeric(1)	:= 0;
--==============================================================================
--					定数定義													
--==============================================================================
	RTN_OK				CONSTANT integer		:= 0;				-- 正常
	RTN_NG				CONSTANT integer		:= 1;				-- 予期したエラー
	RTN_NODATA			CONSTANT integer		:= 2;				-- データなし
	RTN_FATAL			CONSTANT integer		:= 99;				-- 予期せぬエラー
	REPORT_ID			CONSTANT char(11)		:= 'IP030002521';	-- 帳票ID
	OPTION_ID			CONSTANT char(13)		:= 'IP010061040F6';	-- オプションコード
	SP_ID				CONSTANT varchar(20) 	:= 'spIp02502';		-- プロシージャＩＤ
	
	-- 書式フォーマット
	FMT_RBR_KNGK_J		CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 利払金額
	-- 書式フォーマット（外資）
	FMT_RBR_KNGK_F		CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 利払金額
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd				integer :=	RTN_OK;						-- リターンコード
	gSeqNo				integer := 0;							-- シーケンス
	gSQL				varchar(2000) := NULL;				-- SQL編集
	-- 書式フォーマット
	gFmtRbrKngk			varchar(21) := NULL;					-- 利払金額
	gFmGZeiKngk			varchar(21) := NULL;					-- 国税額
	gFmGZeihikiAftKngk	varchar(21) := NULL;					-- 税引後利金額
	-- DB取得項目
	gHktCd				MHAKKOTAI.HKT_CD%TYPE;						-- 発行体コード
	gHktRNm				MHAKKOTAI.HKT_RNM%TYPE;						-- 発行体略称
	gZeimushoCd			MHAKKOTAI.SHOKATSU_ZEIMUSHO_CD%TYPE;		-- 所轄税務署コード
	gZeimushoNm			MZEIMUSHO.ZEIMUSHO_NM%TYPE;					-- 税務署名称
	gSeiriNo			MHAKKOTAI.SEIRI_NO%TYPE;					-- 整理番号
	gRbrTsukaCd			MGR_KIHON.RBR_TSUKA_CD%TYPE;				-- 利払通貨コード
	gRbrTsukaCdNm		MTSUKA.TSUKA_NM%TYPE;						-- 利払通貨名称
	gTaxKbn				KIKIN_SEIKYU.TAX_KBN%TYPE;					-- 税区分
	gTaxRNm				MTAX.TAX_RNM%TYPE;							-- 税区分略称
	gGZeihikiBefKngk	numeric := 0;--KIKIN_SEIKYU.GZEIHIKI_BEF_CHOKYU_KNGK%TYPE;	-- 税引前利金額
	gGZeiKngk			numeric := 0;--KIKIN_SEIKYU.GZEI_KNGK%TYPE;				-- 国税額
	gGZeihikiAftKngk	numeric := 0;--KIKIN_SEIKYU.GZEIHIKI_AFT_CHOKYU_KNGK%TYPE;	-- 税引後利金額
	gJikoDaikoKbn		VJIKO_ITAKU.JIKO_DAIKO_KBN%TYPE;			-- 自行代行区分
	gItakuKaishaRnm		VJIKO_ITAKU.BANK_RNM%TYPE;					-- 委託会社略称
-- 復興増税対応 - 2012/06/12 JSFIT山下 開始
	--税区分取得用変数
	gRet			   numeric := 0;
	gTaxNm             MTAX.TAX_NM%TYPE := NULL;				--税区分名称
	gKokuZeiRate       MTAX.KOKU_ZEI_RATE%TYPE := NULL;		--国税率
	gChihoZeiRate      MTAX.CHIHO_ZEI_RATE%TYPE := NULL;		--地方税率
	gTmpExtra          bigint := NULL;							--Temporary for extra_param
-- 復興増税対応 - 2012/06/12 JSFIT山下 終了
    gKyojushaFlg       integer := 0;
    gKyojushaTitle     varchar(12) := NULL;
    gBkHktCd            MHAKKOTAI.HKT_CD%TYPE;	
	gBkRbrTsukaCd		MGR_KIHON.RBR_TSUKA_CD%TYPE;
    gBkKyojushaFlg     integer := 0;
    gOptionFlg			char(1)	:= NULL;
	-- カーソル
	curMeisai refcursor;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp02502 START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(l_inKijunYm::text, '') = ''
	OR coalesce(l_inItakuKaishaCd::text, '') = ''
	OR coalesce(l_inUserId::text, '') = ''
	OR coalesce(l_inChohyoKbn::text, '') = ''
	OR coalesce(l_inGyomuYmd::text, '') = ''
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error(l_inUserId, REPORT_ID, 'SQLERRM:'||'');
		RETURN;
	END IF;
	-- オプションフラグ取得
	gOptionFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd, OPTION_ID, '0');
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;
	-- SQL編集
	gSQL := spIp02502_createSQL(l_inItakuKaishaCd, l_inZeimushoCd, l_inKijunYm, gOptionFlg);
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
    -- 委託会社略称を取得
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
    -- 代行でなければ、委託会社略称は出力しない
    IF gJikoDaikoKbn <> '2' THEN
        gItakuKaishaRnm := NULL;
    END IF;
	-- カーソルオープン
	OPEN curMeisai FOR EXECUTE gSQL;
	-- データ取得
	LOOP
		FETCH curMeisai INTO	gHktCd 						-- 発行体コード
								,gHktRNm 					-- 発行体略称
								,gZeimushoCd 				-- 所轄税務署コード
								,gZeimushoNm 				-- 税務署名称
								,gSeiriNo 					-- 整理番号
								,gRbrTsukaCd 				-- 利払通貨コード
								,gRbrTsukaCdNm 				-- 利払通貨名称
								,gTaxKbn 					-- 税区分
-- 復興増税対応 - 2012/06/12 JSFIT山下 開始
--								,gTaxRNm					-- 税区分略称
-- 復興増税対応 - 2012/06/12 JSFIT山下 終了
								,gGZeihikiBefKngk 			-- 税引前利金額
								,gGZeiKngk 					-- 国税額
								,gGZeihikiAftKngk 			-- 税引後利金額
                                ,gKyojushaFlg 				-- 居住者フラグ
								;
		EXIT WHEN NOT FOUND;/* apply on curMeisai */
		gSeqNo := gSeqNo + 1;
		-- 書式フォーマットの設定
		-- 利払
		IF gRbrTsukaCd = 'JPY' THEN
			gFmtRbrKngk := FMT_RBR_KNGK_J;
		ELSE
			gFmtRbrKngk := FMT_RBR_KNGK_F;
		END IF;
-- 復興増税対応 - 2012/06/12 JSFIT山下 開始
		--基準年月月初からの直近に該当する適用開始日の税区分を取得する
		SELECT l_outtaxnm, l_outtaxrnm, l_outkokuzeirate, l_outchihozeirate, extra_param
		INTO gTaxNm, gTaxRnm, gKokuZeiRate, gChihoZeiRate, gTmpExtra
		FROM pkIpaZei.getMTax(gTaxKbn, l_inKijunYm || '01');
		gRet := gTmpExtra;
-- 復興増税対応 - 2012/06/12 JSFIT山下 終了
        IF gOptionFlg = '1' THEN
			IF gHktCd = gBkHktCd AND gBkRbrTsukaCd = gRbrTsukaCd AND gKyojushaFlg = gBkKyojushaFlg THEN
				gKyojushaTitle := '';
			ELSE
				IF gKyojushaFlg = '0' THEN
					gKyojushaTitle := '【居住者】';
				ELSE
					gKyojushaTitle := '【非居住者】';
				END IF;
			END IF;
		END IF;
		-- 税区分が'85'の場合、以下をセットする
		IF gTaxKbn = '85' THEN
		   gFmGZeiKngk := '-';
		   gFmGZeihikiAftKngk := '-';
    	ELSE
 		   gFmGZeiKngk := gGZeiKngk;
		   gFmGZeihikiAftKngk := gGZeihikiAftKngk;
		END IF;
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := gRbrTsukaCd;	-- 利払通貨コード
		v_item.l_inItem003 := gHktCd;	-- 発行体コード
		v_item.l_inItem004 := gHktRNm;	-- 発行体略称
		v_item.l_inItem005 := gZeimushoCd;	-- 所轄税務署コード
		v_item.l_inItem006 := gZeimushoNm;	-- 税務署名称
		v_item.l_inItem007 := gSeiriNo;	-- 整理番号
		v_item.l_inItem008 := gTaxKbn;	-- 税区分
		v_item.l_inItem009 := gTaxRNm;	-- 税区分略称
		v_item.l_inItem010 := gGZeihikiBefKngk;	-- 税引前利金額
		v_item.l_inItem011 := gFmGZeiKngk;	-- 国税額
		v_item.l_inItem012 := gFmGZeihikiAftKngk;	-- 税引後利金額
		v_item.l_inItem013 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem014 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem016 := gFmtRbrKngk;	-- 利払金額書式フォーマット
		v_item.l_inItem019 := l_inKijunYm;	-- 基準年月日
		v_item.l_inItem020 := gRbrTsukaCdNm;	-- 利払通貨名称
		v_item.l_inItem021 := gKyojushaFlg;	-- 居住者フラグ
		v_item.l_inItem022 := gKyojushaTitle;	-- 居住者タイトル
		
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
        gBkHktCd := gHktCd;
		gBkRbrTsukaCd := gRbrTsukaCd;
        gBkKyojushaFlg := gKyojushaFlg;
	END LOOP;
	CLOSE curMeisai;
	IF gSeqNo = 0 THEN
	-- 対象データなし
		gRtnCd := RTN_NODATA;
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem013 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem014 := REPORT_ID;	-- レポートID
		v_item.l_inItem016 := FMT_RBR_KNGK_J;	-- 利払金額
		v_item.l_inItem018 := '対象データなし';	-- 対象データなし
		v_item.l_inItem019 := l_inKijunYm;	-- 基準年月日
		
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
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp02502 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		BEGIN
			CLOSE curMeisai;
		EXCEPTION
			WHEN OTHERS THEN
				NULL; -- Cursor already closed
		END;
		CALL pkLog.fatal('ECM701', SP_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal('ECM701', SP_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
--		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip02502 ( l_inKijunYm TEXT, l_inZeimushoCd TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT integer, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spip02502_createsql (
	p_inItakuKaishaCd TEXT,
	p_inZeimushoCd TEXT,
	p_inKijunYm TEXT,
	p_OptionFlg CHAR
) RETURNS TEXT AS $body$
DECLARE
	v_SQL text := '';
BEGIN
	v_SQL := v_SQL || 'SELECT M01.HKT_CD,';									-- 発行体コード
	v_SQL := v_SQL || '		MAX(M01.HKT_RNM),';								-- 発行体略称
	v_SQL := v_SQL || '		MAX(M01.SHOKATSU_ZEIMUSHO_CD),';				-- 所轄税務署コード
	v_SQL := v_SQL || '		MAX(M41.ZEIMUSHO_NM),';							-- 税務署名称
	v_SQL := v_SQL || '		MAX(M01.SEIRI_NO),';							-- 整理番号
	v_SQL := v_SQL || '		MG1.RBR_TSUKA_CD,';								-- 利払通貨コード
	v_SQL := v_SQL || '		MAX(M64.TSUKA_NM),';							-- 利払通貨名称
	v_SQL := v_SQL || '		K01.TAX_KBN,';									-- 税区分
-- 復興増税対応 - 2012/06/12 JSFIT山下 開始
--		gSQL := gSQL || '		MAX(M42.TAX_RNM),';								-- 税区分略称
-- 復興増税対応 - 2012/06/12 JSFIT山下 終了
	v_SQL := v_SQL || '		SUM(COALESCE(K01.GZEIHIKI_BEF_CHOKYU_KNGK,0)),';		-- 税引前利金額
	v_SQL := v_SQL || '		SUM(COALESCE(K01.GZEI_KNGK,0)),';					-- 国税額
	v_SQL := v_SQL || '		SUM(COALESCE(K01.GZEIHIKI_AFT_CHOKYU_KNGK,0))';		-- 税引後利金額
	IF p_OptionFlg = '1' THEN
		v_SQL := v_SQL || ',CASE WHEN K01.Koza_Kbn IN (''90'',''91'') THEN 1 WHEN K01.Tax_Kbn IN (''70'',''71'',''72'',''73'',''74'',''75'') THEN 1 ELSE 0 END as kyojushaFlg ';
	ELSE
		v_SQL := v_SQL || ',0 as kyojushaFlg ';
	END IF;
	v_SQL := v_SQL || ' FROM KIKIN_SEIKYU K01 ';
	v_SQL := v_SQL || 'INNER JOIN MGR_STS MG0 ON K01.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD AND K01.MGR_CD = MG0.MGR_CD ';
	v_SQL := v_SQL || 'INNER JOIN MGR_KIHON MG1 ON MG0.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD AND MG0.MGR_CD = MG1.MGR_CD ';
	v_SQL := v_SQL || 'INNER JOIN MHAKKOTAI M01 ON MG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD AND MG1.HKT_CD = M01.HKT_CD ';
	v_SQL := v_SQL || 'LEFT OUTER JOIN MZEIMUSHO M41 ON M01.SHOKATSU_ZEIMUSHO_CD = M41.ZEIMUSHO_CD ';
	v_SQL := v_SQL || 'INNER JOIN MTSUKA M64 ON MG1.RBR_TSUKA_CD = M64.TSUKA_CD ';
	v_SQL := v_SQL || 'WHERE K01.ITAKU_KAISHA_CD = ''' || p_inItakuKaishaCd || ''' ';
	v_SQL := v_SQL || 'AND MG0.MASSHO_FLG = ''0'' ';
	v_SQL := v_SQL || 'AND MG0.MGR_STAT_KBN = ''1'' ';
	v_SQL := v_SQL || 'AND (K01.KK_KANYO_UMU_FLG = ''1'' OR (K01.KK_KANYO_UMU_FLG != ''1'' AND K01.SHORI_KBN = ''1'')) ';
	v_SQL := v_SQL || 'AND substring(K01.SHR_YMD,1,6) = ''' || p_inKijunYm || ''' ';
	v_SQL := v_SQL || 'AND K01.TAX_KBN <> ''00'' ';
	IF (p_inZeimushoCd IS NOT NULL AND p_inZeimushoCd::text <> '') THEN
		v_SQL := v_SQL || 'AND M01.SHOKATSU_ZEIMUSHO_CD = ''' || p_inZeimushoCd || ''' ';
	END IF;
	v_SQL := v_SQL || ' GROUP BY M01.HKT_CD, MG1.RBR_TSUKA_CD, K01.TAX_KBN';
	IF p_OptionFlg = '1' THEN
		v_SQL := v_SQL || ', CASE WHEN K01.Koza_Kbn IN (''90'',''91'') THEN 1 WHEN K01.Tax_Kbn IN (''70'',''71'',''72'',''73'',''74'',''75'') THEN 1 ELSE 0 END ';
	END IF;
	v_SQL := v_SQL || ' ORDER BY M01.HKT_CD,';
	v_SQL := v_SQL || '			MG1.RBR_TSUKA_CD,';
	v_SQL := v_SQL || '			kyojushaFlg, ';
	v_SQL := v_SQL || '			K01.TAX_KBN ';
	RETURN v_SQL;
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip02502_createsql () FROM PUBLIC;