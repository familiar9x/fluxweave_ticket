

-- ==================================================================
-- SPIP07831
-- 銘柄登録事前警告リスト作成のため帳票ワークテーブルにINSERTする。
--
--
-- 作成：2005/04/26		I.Noshita
-- @version $Id: spIp07831.sql,v 1.12 2006/03/14 07:48:44 nishimura Exp $
--
-- ==================================================================
CREATE OR REPLACE PROCEDURE spip07831 ( l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inUserId TEXT,		-- ユーザーID
 l_inChohyoKbn TEXT,		-- 帳票区分
 l_inGyomuYmd TEXT,		-- 業務日付
 l_outSqlCode OUT integer,		-- リターン値
 l_outSqlErrM OUT text	-- エラーコメント
 ) AS $body$
DECLARE

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
	REPORT_ID			CONSTANT text		:= 'IP030007831';	-- 帳票ID
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	wk_mgr_toroku_warning_dd	numeric			:= 0;				-- 銘柄登録警告日付(日数)
	wk_jiko_daiko_kbn			char(1)			:= NULL;			-- 自行代行区分
	wk_bank_rnm					varchar(20)	:= NULL;			-- 委託会社略称
	gRtnCd						integer :=	RTN_OK;				-- リターンコード
	gSeqNo						integer := 1;					-- シーケンス
    gGyomuYmd                   SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;  -- 業務日付
    gGyomuYmd20After            SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;  -- 業務日付２０営業日後
    gSakuseiYmd             varchar(8);
	-- 銘柄登録事前警告リスト情報取得用カーソル
    -- データ取得のＳＱＬは「sfIpaSime：締め処理用件数取得処理」と同じものを利用しているので、同期を取ってください。
    -- 銘柄登録締め警告出力日付 <= 業務日付 <= 発行日 が抽出期間 
    -- 銘柄登録締め警告出力日付：発行日よりシステム情報マスタ.銘柄登録警告日付(を引いた日付 
	mgr_touroku_cur CURSOR FOR
	SELECT
		VMG1.BOSHU_ST_YMD,
		VMG1.HAKKO_YMD,
		VMG1.BEF_WARNING_L,
		VMG1.BEF_WARNING_S,
		VMG1.MGR_CD,
		VMG1.ISIN_CD,
		VMG1.MGR_RNM,
		CASE WHEN VJK1.JIKO_DAIKO_KBN='1' THEN  NULL  ELSE VJK1.BANK_RNM END  AS BANK_RNM
	FROM
		MGR_KIHON_VIEW VMG1,
		VJIKO_ITAKU VJK1
	WHERE
		VMG1.ITAKU_KAISHA_CD = VJK1.KAIIN_ID AND
		VMG1.ITAKU_KAISHA_CD = CASE WHEN l_inItakuKaishaCd=pkconstant.DAIKO_KEY_CD() THEN  VMG1.ITAKU_KAISHA_CD  ELSE l_inItakuKaishaCd END  AND
		VMG1.HAKKO_YMD <= gGyomuYmd20After AND
    	gGyomuYmd <= VMG1.HAKKO_YMD AND (VMG1.BEF_WARNING_L in ('1', '2') or VMG1.BEF_WARNING_S in ('1', '2', '9')) AND
		VMG1.SHORI_KBN = '1' AND
		VMG1.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD AND
		VMG1.MGR_CD = VMG1.MGR_CD
	ORDER BY
		VMG1.ITAKU_KAISHA_CD,VMG1.BOSHU_ST_YMD, VMG1.HAKKO_YMD, VMG1.MGR_CD;
	-- レコード型変数
	mgr_touroku_rectype		RECORD;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp07831 START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inUserId)::text, '') = ''
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''
	OR coalesce(trim(both l_inGyomuYmd)::text, '') = ''
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error(l_inUserId, REPORT_ID, 'SQLERRM:'||'');
		RETURN;
	END IF;
	-- 業務日付の取得
	gGyomuYmd  := pkDate.getGyomuYmd();
	-- 銘柄登録警告日付の取得(日数)
	SELECT
		mgr_toroku_warning_dd
	INTO STRICT
		wk_mgr_toroku_warning_dd
	FROM
		ssystem_info
    WHERE
        kaiin_id = pkconstant.getKaiinId();
    -- 業務日付２０営業日後取得
	gGyomuYmd20After := pkDate.getPlusDateBusiness(gGyomuYmd, wk_mgr_toroku_warning_dd::integer);
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
    -- 夜間バッチで作成する場合にはデータ基準日を出力する。
    IF l_inChohyoKbn = pkKakuninList.CHOHYO_KBN_BATCH() THEN
        gSakuseiYmd := l_inGyomuYmd;
    ELSE
        gSakuseiYmd := NULL;
    END IF;
	-- レコードがなくなるまでループ
	FOR mgr_touroku_rectype IN mgr_touroku_cur LOOP
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := mgr_touroku_rectype.bank_rnm;	-- 委託会社略称
		v_item.l_inItem002 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem003 := l_inGyomuYmd;	-- 業務日付
		v_item.l_inItem004 := mgr_touroku_rectype.boshu_st_ymd;	-- 募集開始日
		v_item.l_inItem005 := mgr_touroku_rectype.hakko_ymd;	-- 発行年月日
		v_item.l_inItem006 := SPIP07831_getName('183',mgr_touroku_rectype.bef_warning_l);	-- 事前警告L
		v_item.l_inItem007 := SPIP07831_getName('183',mgr_touroku_rectype.bef_warning_s);	-- 事前警告S
		v_item.l_inItem008 := mgr_touroku_rectype.mgr_cd;	-- 銘柄コード
		v_item.l_inItem009 := mgr_touroku_rectype.isin_cd;	-- ISINコード
		v_item.l_inItem010 := mgr_touroku_rectype.mgr_rnm;	-- 銘柄略称
		v_item.l_inItem011 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem013 := gSakuseiYmd;	-- データ基準日
		
		-- Call pkPrint.insertData with composite type
				-- Clear composite type
		v_item := ROW();
		
		
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
		gSeqNo := gSeqNo + 1;
	END LOOP;
	IF gSeqNo = 1 THEN
		-- 対象データなし
		gRtnCd := RTN_NODATA;
		-- 自行情報の取得
		CALL SPIP07831_getJikouInfo(l_inItakuKaishaCd, wk_jiko_daiko_kbn, wk_bank_rnm);
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := wk_bank_rnm;	-- 委託会社略称
		v_item.l_inItem002 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem003 := l_inGyomuYmd;	-- 業務日付
		v_item.l_inItem011 := REPORT_ID;
		v_item.l_inItem012 := '対象データなし';
		
		-- Call pkPrint.insertData with composite type
				-- Clear composite type
		v_item := ROW();
		
		
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
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIP07831 END');	END IF;
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
-- REVOKE ALL ON PROCEDURE spip07831 ( l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spip07831_getjikouinfo ( 
	l_inItakuKaishaCd TEXT,
	INOUT wk_jiko_daiko_kbn char(1),
	INOUT wk_bank_rnm varchar(20)
) AS $body$
BEGIN
	SELECT
		jiko_daiko_kbn,				-- 自行代行区分
		bank_rnm 					-- 委託会社略称
	INTO STRICT
		wk_jiko_daiko_kbn,
		wk_bank_rnm
	FROM
		VJIKO_ITAKU
	WHERE
		kaiin_id = l_inItakuKaishaCd;
	-- 自行代行区分が'2'以外のときに委託会社略称を表示する
	IF wk_jiko_daiko_kbn != '2' THEN
		wk_bank_rnm := NULL;
	END IF;
EXCEPTION
	WHEN no_data_found THEN
		wk_bank_rnm := NULL;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip07831_getjikouinfo ( l_inItakuKaishaCd TEXT, INOUT wk_jiko_daiko_kbn char, INOUT wk_bank_rnm varchar ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spip07831_getname ( l_code_shubetsu TEXT, l_cole_value TEXT ) RETURNS varchar AS $body$
DECLARE

	wk_name		varchar(40) := null;
	wk_count	numeric := 0;

BEGIN
	SELECT
		count(*)
	INTO STRICT
		wk_count
	FROM
		SCODE
	WHERE
		code_shubetsu = l_code_shubetsu AND
		code_value = l_cole_value;
	IF wk_count > 0 THEN
		SELECT
			code_nm
		INTO STRICT
			wk_name
		FROM
			SCODE
		WHERE
			code_shubetsu = l_code_shubetsu AND
			code_value = l_cole_value;
	END IF;
	RETURN wk_name;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spip07831_getname ( l_code_shubetsu TEXT, l_cole_value TEXT ) FROM PUBLIC;