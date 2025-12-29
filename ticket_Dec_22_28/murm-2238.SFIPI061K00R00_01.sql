




CREATE OR REPLACE FUNCTION sfipi061k00r00_01 ( l_initakuKaishaCd text ) RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 買入消却手数料請求書と請求一覧表データを作成する。（バッチ用）
-- * １．請求データ検索処理
-- * ２．手数料請求計算処理
-- * ３．請求書作表処理
-- * ４．請求一覧表作表処理
-- * ５．バッチ帳票出力ＯＮ処理
-- *
-- * @author 野下 勲
-- * @version $Id: SFIPI061K00R00_01.sql,v 1.7 2007/09/01 07:52:59 kuwabara Exp $
-- *
-- * @param l_initakuKaishaCd 委託会社コード
-- * @return INTEGER 0:正常、99:異常、それ以外：エラー
-- 
--==============================================================================
--				  変数定義														
--==============================================================================
	-- 2006/04/12 NOA高橋 買入消却手数料一覧追加
	c_ICHIRAN				CONSTANT text	:= 'IP030006011';	-- 買入消却手数料一覧
	c_SEIKYU				CONSTANT text	:= 'IP030006111';	-- 買入消却手数請求書
	gReturnCode				integer := 0;
	gGyomuYmd				character(8) := '';
	gKjtFrom				character(8) := '';
	gKjtTo					character(8) := '';
--==============================================================================
--				  メイン処理													
--==============================================================================
BEGIN
	CALL pkLog.debug('BATCH', 'sfIpi061K00R00_01', '--------------------------------------------------Start--------------------------------------------------');
	CALL pkLog.debug('BATCH', 'sfIpi061K00R00_01', '引数（委託会社コード）：'||l_initakuKaishaCd);
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
	-- 請求書出力設定テーブルから、出力期間を取得する（業務日付が出力日ではない場合、From-Toは'99999999'で返る）
	CALL PKIPACALCTESURYO.GETBATCHSEIKYUOUTFROMTO(l_initakukaishacd,		-- 委託会社コード
											 '2',					-- 請求書区分（1：元利金、2：手数料）
											 gKjtFrom,				-- 戻り値１：期間From
											 gKjtTo);				-- 戻り値２：期間To
	-- 買入消却手数料請求計算処理（請求書）※バッチ・請求書出力・請求書
	gReturnCode := pkIpaKaiireTesuryo.insKaiireTesuryoSeikyuOut('BATCH',			-- ユーザID
																gGyomuYmd,			-- 業務日付
																gKjtFrom,			-- 基準日From
																gKjtTo,				-- 基準日To
																l_initakukaishacd,	-- 委託会社CD
																'',					-- 発行体CD
																'',					-- 口座店CD
																'',					-- 口座店CIF
																'',					-- 銘柄CD
																'',					-- ISINCD
																pkDate.getPlusDateBusiness(gGyomuYmd,1),	-- 通知日
																c_SEIKYU,			-- 請求書ID
																PKIPACALCTESURYO.C_BATCH(),			-- リアルバッチ区分
																PKIPACALCTESURYO.C_DATA_KBN_SEIKYU(),	-- データ作成区分
																PKIPACALCTESURYO.C_SI_KBN_SEIKYU(),	-- 請求書一覧区分
																'0' --フロント照会画面判別フラグ '0'(フロント照会画面以外)
																);
	IF gReturnCode <> pkconstant.success() THEN
		RETURN gReturnCode;
	END IF;
	-- 2006/04/12 NOA高橋 買入消却手数料一覧追加
	-- 買入消却手数料請求計算処理（請求書一覧）※バッチ・請求書出力・請求書一覧
	gReturnCode := pkIpaKaiireTesuryo.insKaiireTesuryoSeikyuOut('BATCH',			-- ユーザID
																gGyomuYmd,			-- 業務日付
																gKjtFrom,			-- 基準日From
																gKjtTo,				-- 基準日To
																l_initakukaishacd,	-- 委託会社CD
																'',					-- 発行体CD
																'',					-- 口座店CD
																'',					-- 口座店CIF
																'',					-- 銘柄CD
																'',					-- ISINCD
																pkDate.getPlusDateBusiness(gGyomuYmd,1),	-- 通知日
																c_ICHIRAN,							-- 請求書ID
																PKIPACALCTESURYO.C_BATCH(),			-- リアルバッチ区分
																PKIPACALCTESURYO.C_DATA_KBN_YOTEI(),	-- データ作成区分
																PKIPACALCTESURYO.C_SI_KBN_ICHIRAN(),	-- 請求書一覧区分
																'0' --フロント照会画面判別フラグ '0'(フロント照会画面以外)
																);
	IF gReturnCode <> pkconstant.success() THEN
		RETURN gReturnCode;
	END IF;
	CALL pkLog.debug('BATCH', 'sfIpi061K00R00_01', '返値（正常）');
	CALL pkLog.debug('BATCH', 'sfIpi061K00R00_01', '---------------------------------------------------End---------------------------------------------------');
	RETURN pkconstant.success();
--=========< エラー処理 >==========================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'sfIpi061K00R00_01', 'エラーコード'||SQLSTATE);
		CALL pkLog.fatal('ECM701', 'sfIpi061K00R00_01', 'エラー内容'||SQLERRM);
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi061k00r00_01 ( l_initakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE ) FROM PUBLIC;