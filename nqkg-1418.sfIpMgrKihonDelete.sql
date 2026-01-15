




CREATE OR REPLACE FUNCTION sfipmgrkihondelete ( 
	l_inItakuKaishaCd text, 
	l_inMgrCd text, 
	l_inUserId text, 
	l_outErrors out typeErrors , 
	OUT extra_param numeric) RETURNS record AS $body$
DECLARE

--*
-- * 著作権：Copyright(c) 2005
-- * 会社名：JIP
-- *
-- * 銘柄情報(1)基本属性　取消処理
-- *
-- * @author 八巻　真司
-- * @author 小林　伶羽
-- * @version $Id: sfIpMgrKihonDelete.sql,v 1.15.2.2 2025/07/29 11:18:48 taira Exp $
-- *
-- * @param
-- * @return number 0：正常終了，1：異常終了
-- 
	----------------------------------------------------------------------
	-- 定数定義
	----------------------------------------------------------------------
	SHORI_KBN_DELETE CONSTANT char(1) := '3'; -- 履歴処理用処理区分
	MG0_MGR_STS CONSTANT varchar(7) := 'MGR_STS'; -- 履歴処理用テーブル名(MG0　銘柄ステータス管理)
	--MG1_MGR_KIHON       CONSTANT VARCHAR2(9) := 'MGR_KIHON'; -- 履歴処理用テーブル名(MG1　銘柄_基本)
	--MG2_MGR_RBRKIJ      CONSTANT VARCHAR2(10) := 'MGR_RBRKIJ'; -- 履歴処理用テーブル名(MG2　銘柄_利払回次)
	--MG3_MGR_SHOKIJ      CONSTANT VARCHAR2(10) := 'MGR_SHOKIJ'; -- 履歴処理用テーブル名(MG3　銘柄_償還回次)
	--MG4_MGR_TESKIJ      CONSTANT VARCHAR2(10) := 'MGR_TESKIJ'; -- 履歴処理用テーブル名(MG4　銘柄_期中手数料回次)
	--MG5_MGR_HIKIUKE     CONSTANT VARCHAR2(11) := 'MGR_HIKIUKE'; -- 履歴処理用テーブル名(MG5　銘柄_引受会社)
	--MG6_MGR_JUTAKUGINKO CONSTANT VARCHAR2(15) := 'MGR_JUTAKUGINKO'; -- 履歴処理用テーブル名(MG6　銘柄_受託銀行)
	--MG7_MGR_TESURYO_CTL CONSTANT VARCHAR2(15) := 'MGR_TESURYO_CTL'; -- 履歴処理用テーブル名(MG7　銘柄_手数料(制御情報))
	--MG8_MGR_TESURYO_PRM CONSTANT VARCHAR2(15) := 'MGR_TESURYO_PRM'; -- 履歴処理用テーブル名(MG8　銘柄_手数料(計算情報))
	--MG9_MGR_KIKO_KIHON  CONSTANT VARCHAR2(14) := 'MGR_KIKO_KIHON'; -- 履歴処理用テーブル名(MG9　銘柄_機構基本)
	----------------------------------------------------------------------
	-- ローカル変数定義
	----------------------------------------------------------------------
	returnValue numeric; -- リターンコード
	-- 銘柄基本情報取得用変数
	recMG0Line RECORD;
	-- 業務日付関連
	gyomuYmd			SSYSTEM_MANAGEMENT.GYOMU_YMD%type;
	currentTimeStamp	varchar(26);
	errorMessage		varchar(100); -- エラーメッセージ
	wk_rirekiResult		numeric; -- リターンコード (履歴用)
	wk_rirekiErrMsg		varchar(250) := NULL; -- エラーメッセージ(履歴用)
	--  グロスアップ用ワーク変数
	GRS_OPTION_CD  		CONSTANT MOPTION_KANRI.OPTION_CD%TYPE := 'IPX1011112010'; 		--オプションID

BEGIN
	-- リターンコードを初期化する
	returnValue := pkconstant.error();
	l_outErrors := ARRAY[]::typeErrors;
	
	-- 業務日付を取得
	gyomuYmd := pkDate.getGyomuYmd();
	
	-- 業務日付とシステム時間を取得
	currentTimeStamp := TO_CHAR(to_date(gyomuYmd,'yyyymmdd'), 'yyyy-mm-dd') || ' ' || TO_CHAR(CURRENT_TIMESTAMP, 'HH24:MI:SS.US');
	
	-- 銘柄基本情報取得
	BEGIN
		SELECT trim(both MG0.SHONIN_ID) INTO STRICT recMG0Line
		FROM MGR_STS MG0
		WHERE MG0.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND MG0.MGR_CD = l_inMgrCd
		AND MG0.MASSHO_FLG = '0';
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			NULL; -- No data found, continue with deletion
		WHEN TOO_MANY_ROWS THEN
			NULL; -- Multiple rows found, continue with deletion
	END;
	
	-- 論理削除は無し（銘柄_機構基本に登録されてる場合のみ、現状の画面からは論理削除しない）
	--------------------------------------------------------------------------------
	--
	-- 銘柄関連データを削除する
	--
	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- 銘柄ステータス管理
	--------------------------------------------------------------------------------
	delete
	from	MGR_STS MG0
	where	ITAKU_KAISHA_CD = l_inItakukaishaCd
	and		MGR_CD = l_inMgrCd;
	--------------------------------------------------------------------------------
	-- 銘柄基本属性
	--------------------------------------------------------------------------------
	delete
	from	MGR_KIHON
	where	ITAKU_KAISHA_CD = l_inItakukaishaCd
	and		MGR_CD = l_inMgrCd;
	--------------------------------------------------------------------------------
	-- 銘柄利払回次
	--------------------------------------------------------------------------------
	delete
	from	MGR_RBRKIJ
	where	ITAKU_KAISHA_CD = l_inItakukaishaCd
	and		MGR_CD = l_inMgrCd;
	--------------------------------------------------------------------------------
	-- 銘柄償還回次
	--------------------------------------------------------------------------------
	delete
	from	MGR_SHOKIJ
	where	ITAKU_KAISHA_CD = l_inItakukaishaCd
	and		MGR_CD = l_inMgrCd;
	--------------------------------------------------------------------------------
	-- 銘柄期中手数料回次
	--------------------------------------------------------------------------------
	delete
	from	MGR_TESKIJ
	where	ITAKU_KAISHA_CD = l_inItakukaishaCd
	and		MGR_CD = l_inMgrCd;
	--------------------------------------------------------------------------------
	-- 銘柄引受会社
	--------------------------------------------------------------------------------
	delete
	from	MGR_HIKIUKE
	where	ITAKU_KAISHA_CD = l_inItakukaishaCd
	and		MGR_CD = l_inMgrCd;
	--------------------------------------------------------------------------------
	-- 銘柄受託銀行
	--------------------------------------------------------------------------------
	delete
	from	MGR_JUTAKUGINKO
	where	ITAKU_KAISHA_CD = l_inItakukaishaCd
	and		MGR_CD = l_inMgrCd;
	--------------------------------------------------------------------------------
	-- 銘柄手数料（制御情報）
	--------------------------------------------------------------------------------
	delete
	from	MGR_TESURYO_CTL
	where	ITAKU_KAISHA_CD = l_inItakukaishaCd
	and		MGR_CD = l_inMgrCd;
	--------------------------------------------------------------------------------
	-- 銘柄手数料（制御情報）２
	--------------------------------------------------------------------------------
	delete
	from	MGR_TESURYO_CTL2
	where	ITAKU_KAISHA_CD = l_inItakukaishaCd
	and		MGR_CD = l_inMgrCd;
	--------------------------------------------------------------------------------
	-- 銘柄_手数料（計算情報）
	--------------------------------------------------------------------------------
	delete
	from	MGR_TESURYO_PRM
	where	ITAKU_KAISHA_CD = l_inItakukaishaCd
	and		MGR_CD = l_inMgrCd;
	--------------------------------------------------------------------------------
	-- 銘柄_手数料（計算情報）２
	--------------------------------------------------------------------------------
	delete
	from	MGR_TESURYO_PRM2
	where	ITAKU_KAISHA_CD = l_inItakukaishaCd
	and		MGR_CD = l_inMgrCd;
	--------------------------------------------------------------------------------
	-- 銘柄_機構基本
	--------------------------------------------------------------------------------
	delete
	from	MGR_KIKO_KIHON
	where	ITAKU_KAISHA_CD = l_inItakukaishaCd
	and		MGR_CD = l_inMgrCd;
	--------------------------------------------------------------------------------
	-- 新規募集情報
	--------------------------------------------------------------------------------
	delete
	from	SHINKIBOSHU
	where	ITAKU_KAISHA_CD = l_inItakukaishaCd
	and		MGR_CD = l_inMgrCd;
	--------------------------------------------------------------------------------
	-- 会計区別按分額マスタ
	--------------------------------------------------------------------------------
	delete
	from	KAIKEI_ANBUN
	where	ITAKU_KAISHA_CD = l_inItakukaishaCd
	and		MGR_CD = l_inMgrCd;
	--------------------------------------------------------------------------------
	-- 銘柄契約書ファイル
	--------------------------------------------------------------------------------
	delete
	from	MGR_KEIYAKUSHO_FILE
	where	ITAKU_KAISHA_CD = l_inItakukaishaCd
	and		MGR_CD = l_inMgrCd;
	--------------------------------------------------------------------------------
	-- グロスアップ銘柄税率
	--------------------------------------------------------------------------------
	--グロスアップ銘柄税率入力ＯＰフラグの有無
	IF pkControl.getOPTION_FLG(l_inItakuKaishaCd , GRS_OPTION_CD,'0') = '1' THEN
		delete
			from GROSSUP_MGR_TAX
			where ITAKU_KAISHA_CD = l_inItakukaishaCd
			and		MGR_CD = l_inMgrCd;
	END IF;
	
	returnValue := pkconstant.success();
	extra_param := returnValue;
	RETURN;
exception
	when others then
		errorMessage := substr(SQLERRM, 1, 100);
		CALL pkLog.fatal(l_inUserId, null, errorMessage);
		l_outErrors := array_append(l_outErrors, null);
		l_outErrors[COALESCE(CARDINALITY(l_outErrors), 0)] := ROW('allErrs', 'ECM602', errorMessage, null, null, null)::typeErrorRecord;
		returnValue := pkconstant.FATAL();
		extra_param := returnValue;
		RETURN;
end;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipmgrkihondelete ( l_inItakuKaishaCd text, l_inMgrCd text, l_inUserId text, l_outErrors out typeErrors , OUT extra_param numeric) FROM PUBLIC;
