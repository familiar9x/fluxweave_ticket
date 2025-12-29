




CREATE OR REPLACE FUNCTION sfipw001k00r01 () RETURNS integer AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2008
-- * 会社名:JIP
-- *
-- * 概要　:銘柄情報（ＣＢ）更新
-- *
-- *
-- * 返り値: 0:正常
-- *        99:致命的エラー
-- *
-- * @author 田久保　直樹
-- * @version $Id: SFIPW001K00R01.sql,v 1.5 2016/12/21 04:49:38 takami Exp $
-- *
-- ***************************************************************************
-- *　2008.03.31         新規作成
-- ***************************************************************************
-- 	/*==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_PROGRAM_ID CONSTANT text := 'SFIPW001K00R01'; -- プログラムＩＤ
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	-- 翌業務日付 
    gYokuGyoYmd            SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;
    -- 翌日 
    gYokuYmd               SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	curData CURSOR FOR
		SELECT
			WMG12.ITAKU_KAISHA_CD,														-- 委託会社コード
			WMG12.MGR_CD,																-- 銘柄コード
			WMG12.TEKIYOST_YMD,															-- 適用開始日
			WMG12.SHNK_HNK_TRKSH_KBN,													-- 新規変更取消区分
			WMG12.MGR_NM,																-- 銘柄の正式名称
			CASE WHEN WMG12.Kk_Hakkosha_Rnm='' THEN  ''  ELSE (WMG12.Kk_Hakkosha_Rnm				|| sfCmRepeat('　', 8 - coalesce(LENGTH(WMG12.Kk_Hakkosha_Rnm), 0))				|| WMG12.KAIGO_ETC || sfCmRepeat('　', 6 - coalesce(LENGTH(WMG12.KAIGO_ETC), 0))				|| sfCmToFullsize(WMG12.BOSHU_KBN) || '　ＣＢ') END  AS MGR_RNM,			-- 銘柄略称
			WMG12.KK_HAKKOSHA_RNM,														-- 機構発行者略称
			WMG12.JOJO_KBN_TO,															-- 上場区分（東証）
			WMG12.JOJO_KBN_DA,															-- 上場区分（大証）
			WMG12.JOJO_KBN_ME,															-- 上場区分（名証）
			WMG12.JOJO_KBN_FU,															-- 上場区分（福証）
			WMG12.JOJO_KBN_SA,															-- 上場区分（札証）
			WMG12.JOJO_KBN_JA,															-- 上場区分（ジャスダック証）
			WMG12.SAIKEN_SHURUI,														-- 債券種類
			WMG12.HOSHO_KBN,															-- 保証区分
			WMG12.TANPO_KBN,															-- 担保区分
			WMG12.GODOHAKKO_FLG,														-- 合同発行フラグ
			WMG12.RETSUTOKU_UMU_FLG,													-- 劣後特約有無フラグ
			WMG12.SKNNZISNTOKU_UMU_FLG,													-- 責任財産限定特約有無フラグ
			WMG12.PARTHAKKO_UMU_FLG,													-- 分割発行有無フラグ
			WMG12.KK_KANYO_FLG,															-- 機構関与方式採用フラグ
			WMG12.KOBETSU_SHONIN_SAIYO_FLG,												-- 個別承認採用フラグ
			WMG12.WRNT_TOTAL,															-- 新株予約権の総額
			WMG12.WRNT_USE_KAGAKU_KETTEI_YMD,											-- 新株予約権の行使価額決定日
			WMG12.WRNT_USE_ST_YMD,														-- 新株予約権の行使期間開始日
			WMG12.WRNT_USE_ED_YMD,														-- 新株予約権の行使期間終了日
			WMG12.WRNT_USE_KAGAKU,														-- 新株予約権の行使価額
			WMG12.USE_KAGAKU_HENKO_FLG,													-- 行使価額変更フラグ
			WMG12.USE_SEIKYU_UKE_BASHO,													-- 行使請求受付場所
			WMG12.WRNT_BIKO,															-- 新株予約権に係る備考
			WMG12.SHTK_JK_YMD,															-- 取得条項に係る取得日
			WMG12.SHTK_TAIKA_SHURUI,													-- 取得対価（行使財産）の種類
			WMG12.SHANAI_KOMOKU1,														-- 社内処理用項目１
			WMG12.SHANAI_KOMOKU2														-- 社内処理用項目２
		FROM
			CB_MGR_KHN_RUISEKI WMG12,
			MGR_KIHON MG1,
			MGR_STS MG0
		WHERE
			WMG12.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
		AND WMG12.MGR_CD = MG1.MGR_CD
		AND WMG12.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
		AND WMG12.MGR_CD = MG0.MGR_CD
		AND WMG12.TEKIYOST_YMD BETWEEN gYokuYmd AND gYokuGyoYmd
		AND WMG12.SHNK_HNK_TRKSH_KBN = '1'	
		AND	WMG12.KK_TSUCHI_FLG = '1'
		AND WMG12.KK_PHASE = 'M2'
		AND MG0.MASSHO_FLG != '1'
		AND WMG12.TEKIYOST_YMD < coalesce(trim(both MG1.DEFAULT_YMD), '99999999')
		ORDER BY WMG12.TEKIYOST_YMD ASC;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 業務日付の翌日を取得
	gYokuYmd := pkDate.getYokuYmd(pkDate.getGyomuYmd());
	-- 業務日付の翌営業日を取得
	gYokuGyoYmd := pkDate.getYokuBusinessYmd(pkDate.getGyomuYmd());
	-- 銘柄情報（ＣＢ）更新対象銘柄情報を取得（EOFまでループ処理）
	FOR recData IN curData LOOP
	-- 銘柄基本テーブルの更新
		UPDATE
			MGR_KIHON
		SET
			MGR_NM = recData.MGR_NM,																-- 銘柄名称
			MGR_RNM = recData.MGR_RNM,																-- 銘柄略称
			KK_HAKKOSHA_RNM = recData.KK_HAKKOSHA_RNM,												-- 機構発行者略称
			SAIKEN_SHURUI = recData.SAIKEN_SHURUI,													-- 債券種類
			HOSHO_KBN = recData.HOSHO_KBN,															-- 保証区分
			TANPO_KBN = recData.TANPO_KBN,															-- 担保区分
			GODOHAKKO_FLG = recData.GODOHAKKO_FLG,													-- 合同発行フラグ
			RETSUTOKU_UMU_FLG = recData.RETSUTOKU_UMU_FLG,											-- 劣後特約有無フラグ
			SKNNZISNTOKU_UMU_FLG = recData.SKNNZISNTOKU_UMU_FLG,									-- 責任財産限定特約有無フラグ
			PARTHAKKO_UMU_FLG = recData.PARTHAKKO_UMU_FLG,											-- 分割発行有無フラグ
			KK_KANYO_FLG = recData.KK_KANYO_FLG,													-- 機構関与方式採用フラグ
			KOBETSU_SHONIN_SAIYO_FLG = recData.KOBETSU_SHONIN_SAIYO_FLG,							-- 個別承認採用フラグ
			LAST_TEISEI_DT = to_timestamp(pkDate.getCurrentTime(), 'yyyy-mm-dd HH24:MI:SS.US6'),	-- 最終訂正日時
			LAST_TEISEI_ID = pkconstant.BATCH_USER(),													-- 最終訂正ユーザ
			KOUSIN_DT = CURRENT_TIMESTAMP,															-- 更新日時
			KOUSIN_ID = pkconstant.BATCH_USER() 														-- 更新ユーザ
		WHERE
			ITAKU_KAISHA_CD = recData.ITAKU_KAISHA_CD
		AND	MGR_CD = recData.MGR_CD;
		-- 銘柄基本（ＣＢ）テーブルの更新
		UPDATE
			CB_MGR_KIHON
		SET
			TEKIYOST_YMD = recData.TEKIYOST_YMD,													-- 適用開始日
			SHNK_HNK_TRKSH_KBN = recData.SHNK_HNK_TRKSH_KBN,										-- 新規変更取消区分
			JOJO_KBN_TO = recData.JOJO_KBN_TO,														-- 上場区分（東証）
			JOJO_KBN_DA = recData.JOJO_KBN_DA,														-- 上場区分（大証）
			JOJO_KBN_ME = recData.JOJO_KBN_ME,														-- 上場区分（名証）
			JOJO_KBN_FU = recData.JOJO_KBN_FU,														-- 上場区分（福証）
			JOJO_KBN_SA = recData.JOJO_KBN_SA,														-- 上場区分（札証）
			JOJO_KBN_JA = recData.JOJO_KBN_JA,														-- 上場区分（ジャスダック証）
			WRNT_TOTAL = recData.WRNT_TOTAL,														-- 新株予約権の総額
			WRNT_USE_KAGAKU_KETTEI_YMD = recData.WRNT_USE_KAGAKU_KETTEI_YMD,						-- 新株予約権の行使価額決定日
			WRNT_USE_ST_YMD = recData.WRNT_USE_ST_YMD,												-- 新株予約権の行使期間開始日
			WRNT_USE_ED_YMD = recData.WRNT_USE_ED_YMD,												-- 新株予約権の行使期間終了日
			WRNT_USE_KAGAKU = recData.WRNT_USE_KAGAKU,												-- 新株予約権の行使価額
			USE_SEIKYU_UKE_BASHO = recData.USE_SEIKYU_UKE_BASHO,									-- 行使請求受付場所
			WRNT_BIKO = recData.WRNT_BIKO,															-- 新株予約権に係る備考
			SHTK_JK_YMD = recData.SHTK_JK_YMD,														-- 取得条項に係る取得日
			SHTK_TAIKA_SHURUI = recData.SHTK_TAIKA_SHURUI,											-- 取得対価（行使財産）の種類
			SHANAI_KOMOKU1 = recData.SHANAI_KOMOKU1,												-- 社内処理用項目１
			SHANAI_KOMOKU2 = recData.SHANAI_KOMOKU2,												-- 社内処理用項目２
			LAST_TEISEI_DT = to_timestamp(pkDate.getCurrentTime(), 'yyyy-mm-dd HH24:MI:SS.US6'),	-- 最終訂正日時
			LAST_TEISEI_ID = pkconstant.BATCH_USER(),															-- 最終訂正ユーザ
			KOUSIN_DT = CURRENT_TIMESTAMP,																-- 更新日時
			KOUSIN_ID = pkconstant.BATCH_USER() 																-- 更新ユーザ
		WHERE
			ITAKU_KAISHA_CD = recData.ITAKU_KAISHA_CD
		AND	MGR_CD = recData.MGR_CD;
		-- 銘柄ステータステーブル
		UPDATE
			MGR_STS
		SET
			KIHON_TEISEI_YMD = pkDate.getGyomuYmd(),												-- 基本訂正日
			KIHON_TEISEI_USER_ID = pkconstant.BATCH_USER(),											-- 基本訂正ユーザ
			LAST_TEISEI_DT = to_timestamp(pkDate.getCurrentTime(), 'yyyy-mm-dd HH24:MI:SS.US6'),	-- 最終訂正日時
			LAST_TEISEI_ID = pkconstant.BATCH_USER(),													-- 最終訂正ユーザ
			KOUSIN_DT = CURRENT_TIMESTAMP,															-- 更新日時
			KOUSIN_ID = pkconstant.BATCH_USER() 														-- 更新ユーザ
		WHERE
			ITAKU_KAISHA_CD = recData.ITAKU_KAISHA_CD
		AND	MGR_CD = recData.MGR_CD;
	END LOOP;
	-- 正常終了
	RETURN pkconstant.success();
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'SQLERRM:' || SQLERRM);
		RETURN pkconstant.FATAL();
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipw001k00r01 () FROM PUBLIC;