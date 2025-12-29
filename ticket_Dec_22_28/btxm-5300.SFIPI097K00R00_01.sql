




CREATE OR REPLACE FUNCTION sfipi097k00r00_01 ( l_initakuKaishaCd text ) RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2006
-- * 会社名: JIP
-- *
-- * 支払代理人手数料請求書と請求一覧表データを作成する。（バッチ用）
-- * １．出力期間の取得
-- * ２．請求書作表処理
-- * ３．請求一覧表作表処理
-- *
-- * @author 森川　嘉人
-- * @version $Id: SFIPI097K00R00_01.sql,v 1.4 2007/09/01 07:52:58 kuwabara Exp $
-- *
-- * @param l_initakuKaishaCd 委託会社コード
-- * @return INTEGER 0:正常、99:異常、それ以外：エラー
-- 
--==============================================================================
--					変数定義													
--==============================================================================
	c_ICHIRAN				CONSTANT text	:= 'IP030010011';	-- 一覧表
	c_SEIKYU				CONSTANT text	:= 'IP030009711';	-- 請求書
	c_SHIHARAI_TESURYO		CONSTANT text	 := '52';			-- 支払代理人手数料
	gReturnCode				integer := 0;
	gGyomuYmd				character(8) := '';
	gKjtFrom				character(8) := '';
	gKjtTo					character(8) := '';
--==============================================================================
--					メイン処理													
--==============================================================================
BEGIN
	CALL pkLog.debug('BATCH', 'sfIpi097K00R00_01', '--------------------------------------------------Start--------------------------------------------------');
	CALL pkLog.debug('BATCH', 'sfIpi097K00R00_01', '引数（委託会社コードD）：'||l_initakuKaishaCd);
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
	-- 請求書出力設定テーブルから、出力期間を取得する（業務日付が出力日ではない場合、From-Toは'99999999'で返る')
	CALL PKIPACALCTESURYO.GETBATCHSEIKYUOUTFROMTO(l_initakukaishacd,		-- 委託会社コード
											 '2',					-- 請求書区分（1：元利金、2：手数料）
											 gKjtFrom,				-- 戻り値１：期間From
											 gKjtTo);				-- 戻り値２：期間To
	-- 支払代理人手数料計算処理（請求書）※バッチ・請求書出力
	gReturnCode := pkIpaPayEtcKichuTesuryo.insPayEtcKichuTesuryoOut('BATCH',
											gGyomuYmd,
											gKjtFrom,
											gKjtTo,
											l_initakukaishacd,
											'',
											'',
											'',
											'',
											'',
											'',
											c_SEIKYU,
											c_SHIHARAI_TESURYO,
											PKIPACALCTESURYO.C_BATCH(),
											PKIPACALCTESURYO.C_DATA_KBN_SEIKYU(),
											PKIPACALCTESURYO.C_SI_KBN_SEIKYU(),
											'0'); --フロント照会画面判別フラグ '0'(フロント照会画面以外)
	IF gReturnCode <> pkconstant.success() THEN
		RETURN gReturnCode;
	END IF;
	-- 支払代理人手数料請求計算処理（請求書一覧）※バッチ・請求一覧表出力
	gReturnCode := pkIpaPayEtcKichuTesuryo.insPayEtcKichuTesuryoOut('BATCH',
											gGyomuYmd,
											gKjtFrom,
											gKjtTo,
											l_initakukaishacd,
											'',
											'',
											'',
											'',
											'',
											'',
											c_ICHIRAN,
											c_SHIHARAI_TESURYO,
											PKIPACALCTESURYO.C_BATCH(),
											PKIPACALCTESURYO.C_DATA_KBN_YOTEI(),
											PKIPACALCTESURYO.C_SI_KBN_ICHIRAN(),
											'0'); --フロント照会画面判別フラグ '0'(フロント照会画面以外)
	IF gReturnCode <> pkconstant.success() THEN
		RETURN gReturnCode;
	END IF;
	CALL pkLog.debug('BATCH', 'sfIpi097K00R00_01', '返値（正常）');
	CALL pkLog.debug('BATCH', 'sfIpi097K00R00_01', '---------------------------------------------------End---------------------------------------------------');
	RETURN pkconstant.success();
--=========< エラー処理 >==========================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'sfIpi097K00R00_01', 'エラーコード'||SQLSTATE);
		CALL pkLog.fatal('ECM701', 'sfIpi097K00R00_01', 'エラー内容'||SQLERRM);
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi097k00r00_01 ( l_initakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE ) FROM PUBLIC;