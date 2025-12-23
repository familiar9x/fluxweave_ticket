




CREATE OR REPLACE FUNCTION sfipi055k00r00_01 ( l_initakuKaishaCd text ) RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 期中管理手数料請求書と請求一覧表データを作成する。（バッチ用）
-- * １．請求データ検索処理
-- * ２．基金請求計算処理
-- * ３．請求書作表処理
-- * ４．請求一覧表作表処理
-- * ５．バッチ帳票出力ＯＮ処理
-- *
-- * @author 山下　健太(NOA)
-- * @version $Id: SFIPI055K00R00_01.sql,v 1.7 2023/11/10 05:36:41 harada_n Exp $
-- *
-- * @param l_initakuKaishaCd 委託会社コード
-- * @return INTEGER 0:正常、99:異常、それ以外：エラー
-- 
--==============================================================================
--					変数定義													
--==============================================================================
	c_SEIKYU				CONSTANT text	:= 'IP030005511';	-- 請求書
	c_RYOSHU				CONSTANT text	:= 'IP030005521';	-- 領収書
	c_ICHIRAN				CONSTANT text	:= 'IP030005411';	-- 請求一覧
--	c_BUNPAI_ICHIRAN		CONSTANT CHAR(11) 		:= 'IP030005811';	-- 帳票ID
	c_BUNPAI_SEIKYU			CONSTANT text		:= 'IP030005911';	-- 帳票ID
	gReturnCode				integer := 0;
	gSeikyuIchiranCnt		numeric	:= 0;
	gSeikyushoCnt			numeric	:= 0;
	gGyomuYmd				character(8) := '';
	gKjtFrom				character(8) := '';
	gKjtTo					character(8) := '';
	pOutSqlCode				integer := 0;
	pOutSqlErrM				varchar(2000) := '';
--==============================================================================
--					メイン処理													
--==============================================================================
BEGIN
	CALL pkLog.debug('BATCH', 'sfIpi055K00R00_01', '--------------------------------------------------Start--------------------------------------------------');
	CALL pkLog.debug('BATCH', 'sfIpi055K00R00_01', '引数（委託会社コードD）：'||l_initakuKaishaCd);
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
	-- 請求書出力設定テーブルから、出力期間を取得する（業務日付が出力日ではない場合、From-Toは'99999999'で返る）
	CALL PKIPACALCTESURYO.GETBATCHSEIKYUOUTFROMTO(l_initakukaishacd,		-- 委託会社コード
											 '2',					-- 請求書区分（1：元利金、2：手数料）
											 gKjtFrom,				-- 戻り値１：期間From
											 gKjtTo);				-- 戻り値２：期間To
	-- 期中手数料計算処理（請求書）※バッチ・請求書出力・請求書 c_SEIKYU
	BEGIN
		SELECT f.l_outsqlcode, f.l_outsqlerrm, f.extra_param
		INTO pOutSqlCode, pOutSqlErrM, gReturnCode
		FROM pkipakichutesuryo.insKichuTesuryoSeikyuOut(
			'BATCH'::character,
			gGyomuYmd,
			gKjtFrom,
			gKjtTo,
			l_initakukaishacd::character varying,
			''::character,
			''::character varying,
			''::character varying,
			''::character,
			''::character,
			pkDate.getPlusDateBusiness(gGyomuYmd,1),
			c_SEIKYU::character varying,
			PKIPACALCTESURYO.C_BATCH(),
			PKIPACALCTESURYO.C_DATA_KBN_SEIKYU(),
			PKIPACALCTESURYO.C_SI_KBN_SEIKYU(),
			'0'::character varying
		) AS f;
	EXCEPTION WHEN OTHERS THEN
		RETURN 99;
	END;
	IF pOutSqlCode <> 0 THEN
		CALL pkLog.error('ECM701', 'sfIpi055K00R00_01', 'SQLCODE:'||pOutSqlCode);
		CALL pkLog.error('ECM701', 'sfIpi055K00R00_01', 'SQLERRM:'||pOutSqlErrM);
		CALL pkLog.error('ECM701', 'SPIPI055K00R00', 'エラーメッセージ：'||'請求書出力処理が失敗しました。');
		RETURN gReturnCode;
	END IF;
	-- バッチ帳票出力ＯＮ処理
	IF gSeikyushoCnt <> 0 THEN
		CALL sfIpi055K00R00_01_insertData(
			inItakuKaishaCd		=> l_inItakuKaishaCd,
			inKijunYmd			=> gGyomuYmd,
			inListSakuseiKbn	=> '1',
			inChohyoId			=> c_SEIKYU
		);
	END IF;
	-- 期中手数料計算処理（請求書）※バッチ・予定表出力・請求書一覧（期日順）c_ICHIRAN
	SELECT f.l_outsqlcode, f.l_outsqlerrm, f.extra_param
	INTO pOutSqlCode, pOutSqlErrM, gReturnCode
	FROM pkipakichutesuryo.insKichuTesuryoSeikyuOut(
		'BATCH'::character,
		gGyomuYmd,
		gKjtFrom,
		gKjtTo,
		l_initakukaishacd::character varying,
		''::character,
		''::character varying,
		''::character varying,
		''::character,
		''::character,
		pkDate.getPlusDateBusiness(gGyomuYmd,1),
		c_ICHIRAN::character varying,
		PKIPACALCTESURYO.C_BATCH(),
		PKIPACALCTESURYO.C_DATA_KBN_YOTEI(),
		PKIPACALCTESURYO.C_SI_KBN_ICHIRAN(),
		'0'::character varying
	) AS f;
	IF pOutSqlCode <> 0 THEN
		CALL pkLog.error('ECM701', 'sfIpi055K00R00_01', 'SQLCODE:'||pOutSqlCode);
		CALL pkLog.error('ECM701', 'sfIpi055K00R00_01', 'SQLERRM:'||pOutSqlErrM);
		CALL pkLog.error('ECM701', 'SPIPI055K00R00', 'エラーメッセージ：'||'請求書出力処理が失敗しました。');
		RETURN gReturnCode;
	END IF;
	-- バッチ帳票出力ＯＮ処理
	IF gSeikyuIchiranCnt <> 0 THEn
		CALL sfIpi055K00R00_01_insertData(
			inItakuKaishaCd		=> l_inItakuKaishaCd,
			inKijunYmd			=> gGyomuYmd,
			inListSakuseiKbn	=> '1',
			inChohyoId			=> c_ICHIRAN
		);
	END IF;
	-- 期中手数料計算処理（分配請求書）※バッチ・予定表出力・請求書 c_BUNPAI_SEIKYU
	SELECT f.l_outsqlcode, f.l_outsqlerrm, f.extra_param
	INTO pOutSqlCode, pOutSqlErrM, gReturnCode
	FROM pkipakichutesuryo.insKichuTesuryoSeikyuOut(
		'BATCH'::character,
		gGyomuYmd,
		gKjtFrom,
		gKjtTo,
		l_initakukaishacd::character varying,
		''::character,
		''::character varying,
		''::character varying,
		''::character,
		''::character,
		pkDate.getPlusDateBusiness(gGyomuYmd,1),
		c_BUNPAI_SEIKYU::character varying,
		PKIPACALCTESURYO.C_BATCH(),
		PKIPACALCTESURYO.C_DATA_KBN_SEIKYU(),
		PKIPACALCTESURYO.C_SI_KBN_SEIKYU(),
		'0'::character varying
	) AS f;
	IF pOutSqlCode <> 0 THEN
		CALL pkLog.error('ECM701', 'sfIpi055K00R00_01', 'SQLCODE:'||pOutSqlCode);
		CALL pkLog.error('ECM701', 'sfIpi055K00R00_01', 'SQLERRM:'||pOutSqlErrM);
		CALL pkLog.error('ECM701', 'SPIPI055K00R00', 'エラーメッセージ：'||'請求書出力処理が失敗しました。');
		RETURN gReturnCode;
	END IF;
	-- バッチ帳票出力ＯＮ処理
	IF gSeikyuIchiranCnt <> 0 THEn
		CALL sfIpi055K00R00_01_insertData(
			inItakuKaishaCd	=> l_inItakuKaishaCd,
			inKijunYmd		=> gGyomuYmd,
			inListSakuseiKbn => '1',
			inChohyoId		=> c_BUNPAI_SEIKYU
		);
	END IF;
	CALL pkLog.debug('BATCH', 'sfIpi055K00R00_01', '返値（正常）');
	CALL pkLog.debug('BATCH', 'sfIpi055K00R00_01', '---------------------------------------------------End---------------------------------------------------');
	RETURN pkconstant.success();
--=========< エラー処理 >==========================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'sfIpi055K00R00_01', 'エラーコード'||SQLSTATE);
		CALL pkLog.fatal('ECM701', 'sfIpi055K00R00_01', 'エラー内容'||SQLERRM);
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi055k00r00_01 ( l_initakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfipi055k00r00_01_insertdata ( inItakuKaishaCd PRT_OK.ITAKU_KAISHA_CD%TYPE, inKijunYmd PRT_OK.KIJUN_YMD%TYPE, inListSakuseiKbn PRT_OK.LIST_SAKUSEI_KBN%TYPE, inChohyoId PRT_OK.CHOHYO_ID%TYPE, inGroupId PRT_OK.GROUP_ID%TYPE DEFAULT ' ', inShoriKbn PRT_OK.SHORI_KBN%TYPE DEFAULT ' ', inLastTeiseiDt PRT_OK.LAST_TEISEI_DT%TYPE DEFAULT NULL, inLastTeiseiId PRT_OK.LAST_TEISEI_ID%TYPE DEFAULT ' ', inShoninDt PRT_OK.SHONIN_DT%TYPE DEFAULT NULL, inShoninId PRT_OK.SHONIN_ID%TYPE DEFAULT ' ', inKousinId PRT_OK.KOUSIN_ID%TYPE DEFAULT ' ', inSakuseiId PRT_OK.SAKUSEI_ID%TYPE DEFAULT ' ') AS $body$
BEGIN
	INSERT INTO PRT_OK(
		ITAKU_KAISHA_CD,	KIJUN_YMD,		LIST_SAKUSEI_KBN,	CHOHYO_ID,	GROUP_ID,
		SHORI_KBN,			LAST_TEISEI_DT,	LAST_TEISEI_ID,		SHONIN_DT,	SHONIN_ID,
		KOUSIN_ID,			SAKUSEI_ID
	)
	VALUES (
		inItakuKaishaCd,	inKijunYmd,		inListSakuseiKbn,	inChohyoId,	inGroupId,
		inShoriKbn,			inLastTeiseiDt,	inLastTeiseiId,		inShoninDt,	inShoninId,
		inKousinId,			inSakuseiId
	);
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfipi055k00r00_01_insertdata ( inItakuKaishaCd PRT_OK.ITAKU_KAISHA_CD%TYPE, inKijunYmd PRT_OK.KIJUN_YMD%TYPE, inListSakuseiKbn PRT_OK.LIST_SAKUSEI_KBN%TYPE, inChohyoId PRT_OK.CHOHYO_ID%TYPE, inGroupId PRT_OK.GROUP_ID%TYPE DEFAULT ' ', inShoriKbn PRT_OK.SHORI_KBN%TYPE DEFAULT ' ', inLastTeiseiDt PRT_OK.LAST_TEISEI_DT%TYPE DEFAULT NULL, inLastTeiseiId PRT_OK.LAST_TEISEI_ID%TYPE DEFAULT ' ', inShoninDt PRT_OK.SHONIN_DT%TYPE DEFAULT NULL, inShoninId PRT_OK.SHONIN_ID%TYPE DEFAULT ' ', inKousinId PRT_OK.KOUSIN_ID%TYPE DEFAULT ' ', inSakuseiId PRT_OK.SAKUSEI_ID%TYPE DEFAULT ' ') FROM PUBLIC;