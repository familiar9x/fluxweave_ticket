




CREATE OR REPLACE FUNCTION sfipi098k00r00_01 ( l_initakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE ) RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2006
-- * 会社名: JIP
-- *
-- * その他期中手数料１請求書と請求一覧表データを作成する。（バッチ用）
-- * １．出力期間の取得
-- * ２．請求書作表処理
-- * ３．請求一覧表作表処理
-- *
-- * @author 森川　嘉人
-- * @version $Id: SFIPI098K00R00_01.sql,v 1.4 2007/09/01 07:52:59 kuwabara Exp $
-- *
-- * @param l_initakuKaishaCd 委託会社コード
-- * @return INTEGER 0:正常、99:異常、それ以外：エラー
-- 
--==============================================================================
--					変数定義													
--==============================================================================
	c_ICHIRAN				CONSTANT varchar(11)	:= 'IP030010111';	-- 一覧表
	c_SEIKYU				CONSTANT varchar(11)	:= 'IP030009811';	-- 請求書
	c_SHIHARAI_TESURYO		CONSTANT char(2)		 := '91';			-- その他期中手数料１
	gReturnCode				integer := 0;
	gGyomuYmd				SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;
	gKjtFrom				MGR_TESKIJ.CHOKYU_KJT%TYPE;
	gKjtTo					MGR_TESKIJ.CHOKYU_KJT%TYPE;
--==============================================================================
--					メイン処理													
--==============================================================================
BEGIN
	CALL pkLog.debug('BATCH', 'sfIpi098K00R00_01', '--------------------------------------------------Start--------------------------------------------------');
	CALL pkLog.debug('BATCH', 'sfIpi098K00R00_01', '引数（委託会社コードD）：'||l_initakuKaishaCd);
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
	-- 請求書出力設定テーブルから、出力期間を取得する（業務日付が出力日ではない場合、From-Toは'99999999'で返る）
	CALL PKIPACALCTESURYO.GETBATCHSEIKYUOUTFROMTO(l_initakukaishacd,		-- 委託会社コード
											 '2',					-- 請求書区分（1：元利金、2：手数料）
											 gKjtFrom,				-- 戻り値１：期間From
											 gKjtTo);				-- 戻り値２：期間To
	-- その他期中手数料１計算処理（請求書）※バッチ・請求書出力
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
	-- その他期中手数料１請求計算処理（請求書一覧）※バッチ・請求一覧表出力
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
	CALL pkLog.debug('BATCH', 'sfIpi098K00R00_01', '返値（正常）');
	CALL pkLog.debug('BATCH', 'sfIpi098K00R00_01', '---------------------------------------------------End---------------------------------------------------');
	RETURN pkconstant.success();
--=========< エラー処理 >==========================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'sfIpi098K00R00_01', 'エラーコード'||SQLSTATE);
		CALL pkLog.fatal('ECM701', 'sfIpi098K00R00_01', 'エラー内容'||SQLERRM);
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi098k00r00_01 ( l_initakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE ) FROM PUBLIC;