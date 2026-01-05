




CREATE OR REPLACE FUNCTION sfipi091k00r00_01 ( l_initakuKaishaCd text ) RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 財務代理人手数料請求書と請求一覧表データを作成する。（バッチ用）
-- * １．請求データ検索処理
-- * ２．手数料請求計算処理
-- * ３．請求書作表処理
-- * ４．請求一覧表作表処理
-- * ５．バッチ帳票出力ＯＮ処理
-- *
-- * @author 吉末　美希
-- * @author 山下　健太(NOA)
-- * @version $Id: SFIPI091K00R00_01.sql,v 1.8 2007/09/01 07:52:59 kuwabara Exp $
-- *
-- * @param l_initakuKaishaCd 委託会社コード
-- * @return INTEGER 0:正常、99:異常、それ以外：エラー
-- 
--==============================================================================
--					デバッグ機能												
--==============================================================================
	DEBUG	CONSTANT numeric(1)	:= 0;
--==============================================================================
--					変数定義												
--==============================================================================
	c_ICHIRAN				CONSTANT text	:= 'IP030009411';	-- 一覧表
	c_SEIKYU				CONSTANT text	:= 'IP030009111';	-- 請求書
	c_ZAIMU_TESURYO			CONSTANT text		 := '22';			-- 財務代理人手数料（期中）
	gReturnCode				integer := 0;
	gGyomuYmd				text;
	gKjtFrom				character(8);
	gKjtTo					character(8);
--==============================================================================
--					メイン処理													
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN
		CALL pkLog.debug('BATCH', 'sfIpi091K00R00_01', '----------------------Start----------------------');
		CALL pkLog.debug('BATCH', 'sfIpi091K00R00_01', '引数（委託会社コードD）：'||l_initakuKaishaCd);
	END IF;
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
	-- 請求書出力設定テーブルから、出力期間を取得する（業務日付が出力日ではない場合、From-Toは'99999999'で返る）
	CALL PKIPACALCTESURYO.GETBATCHSEIKYUOUTFROMTO(l_initakukaishacd,		-- 委託会社コード
											 '2',					-- 請求書区分（1：元利金、2：手数料）
											 gKjtFrom,				-- 戻り値１：期間From
											 gKjtTo);				-- 戻り値２：期間To
	-- 財務代理人手数料（期中分）請求計算処理（請求書）※バッチ・請求書出力・請求書
	gReturnCode := Pkipazaimujimutesuryo.insZaimuJimuTesuryoSeikyuOut('BATCH',
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
											c_ZAIMU_TESURYO,
											PKIPACALCTESURYO.C_BATCH(),
											PKIPACALCTESURYO.C_DATA_KBN_SEIKYU(),
											PKIPACALCTESURYO.C_SI_KBN_SEIKYU(),
											'0'); -- フロント出力指示用フラグ 0は計算結果tblを作成しない
	IF gReturnCode <> pkconstant.success() THEN
		RETURN gReturnCode;
	END IF;
	-- 財務代理人手数料（期中分）請求計算処理（請求書一覧）※バッチ・請求書出力・請求書一覧
	gReturnCode := Pkipazaimujimutesuryo.insZaimuJimuTesuryoSeikyuOut('BATCH',
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
											c_ZAIMU_TESURYO,
											PKIPACALCTESURYO.C_BATCH(),
											PKIPACALCTESURYO.C_DATA_KBN_YOTEI(),
											PKIPACALCTESURYO.C_SI_KBN_ICHIRAN(),
											'0'); -- フロント出力指示用フラグ 0は計算結果tblを作成しない
	IF gReturnCode <> pkconstant.success() THEN
		RETURN gReturnCode;
	END IF;
	IF DEBUG = 1 THEN
		CALL pkLog.debug('BATCH', 'sfIpi091K00R00_01', '返値（正常）');
		CALL pkLog.debug('BATCH', 'sfIpi091K00R00_01', '----------------------End----------------------');
	END IF;
	RETURN pkconstant.success();
--=========< エラー処理 >==========================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'sfIpi091K00R00_01', 'エラーコード'||SQLSTATE);
		CALL pkLog.fatal('ECM701', 'sfIpi091K00R00_01', 'エラー内容'||SQLERRM);
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi091k00r00_01 ( l_initakuKaishaCd text ) FROM PUBLIC;