




CREATE OR REPLACE FUNCTION sfipx016k00r01 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE,      -- 委託会社コード
 l_inUserId SREPORT_WK.USER_ID%TYPE,     -- ユーザーＩＤ
 l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE,  -- 帳票区分
 l_inGyomuYmd SREPORT_WK.SAKUSEI_YMD%TYPE, -- 業務日付
 l_inMgrCd MGR_KIHON.MGR_CD%TYPE         -- 銘柄コード
 ) RETURNS integer AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2008
-- * 会社名:JIP
-- *
-- * 概要　:ガベージ対象銘柄帳票作成
-- *
-- * 引数　:l_inItakuKaishaCd :委託会社コード
-- *        l_inUserId        :ユーザーＩＤ
-- *        l_inChohyoKbn     :帳票区分
-- *        l_inGyomuYmd      :業務日付
-- *        l_inMgrCd         :銘柄コード
-- *
-- * 返り値: 0:正常
-- *        99:異常
-- *
-- * @author ASK
-- * @version $Id: SFIPX016K00R01.sql,v 1.5.2.4 2025/07/29 11:13:22 taira Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- * 2008.09.04  ASK         新規作成
-- * 2024.05.30  今林栄治    副受託銘柄帳票を追加
-- ***************************************************************************
-- 
	--==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_PROGRAM_ID        CONSTANT varchar(20)                 := 'SFIPX016K00R01'; -- プログラムＩＤ
	C_CB_OPTION_CD      CONSTANT MOPTION_KANRI.OPTION_CD%TYPE := 'IPW1000000001';  -- 振替ＣＢオプションコード
	C_KB_OPTION_CD      CONSTANT MOPTION_KANRI.OPTION_CD%TYPE := 'IPP1003302010';  -- 実質記番号オプションコード
	C_KY_OPTION_CD      CONSTANT MOPTION_KANRI.OPTION_CD%TYPE := 'IPN1001108011';  -- 金融債手数料登録判定フラグ
	C_NODATA            integer                               := 2;                -- 対象データなし
	-- ＣＢ用の銘柄情報詳細リスト（基本情報）
	C_CB_MGR_KIHON_ID_A CONSTANT SREPORT_WK.CHOHYO_ID%TYPE    := 'IPW30000111';
	C_CB_MGR_KIHON_ID_B CONSTANT SREPORT_WK.CHOHYO_ID%TYPE    := 'IPW30000112';
	-- 特例債用の銘柄情報詳細リスト（基本情報）
	C_TO_MGR_KIHON_ID_A CONSTANT SREPORT_WK.CHOHYO_ID%TYPE    := 'IPK30000141';
	C_TO_MGR_KIHON_ID_B CONSTANT SREPORT_WK.CHOHYO_ID%TYPE    := 'IPK30000142';
	-- 副受託銘柄情報詳細リスト（基本情報）
	C_FU_MGR_KIHON_ID_A    CONSTANT SREPORT_WK.CHOHYO_ID%TYPE    := 'IP030010911';
	C_FU_MGR_KIHON_ID_B    CONSTANT SREPORT_WK.CHOHYO_ID%TYPE    := 'IP030010912';
	-- 銘柄情報詳細リスト（基本情報）
	C_MGR_KIHON_ID_A    CONSTANT SREPORT_WK.CHOHYO_ID%TYPE    := 'IP030000111';
	C_MGR_KIHON_ID_B    CONSTANT SREPORT_WK.CHOHYO_ID%TYPE    := 'IP030000112';
	-- 銘柄情報詳細リスト（発行時手数料情報）
	C_MGR_HAKKO_ID_A    CONSTANT SREPORT_WK.CHOHYO_ID%TYPE    := 'IP030000161';
	C_MGR_HAKKO_ID_B    CONSTANT SREPORT_WK.CHOHYO_ID%TYPE    := 'IP030000162';
	-- ＣＢ用の銘柄情報詳細リスト（期中手数料情報）
	C_CB_MGR_KICHU_ID_A CONSTANT SREPORT_WK.CHOHYO_ID%TYPE    := 'IPW30000171';
	C_CB_MGR_KICHU_ID_B CONSTANT SREPORT_WK.CHOHYO_ID%TYPE    := 'IPW30000172';
	C_CB_MGR_KICHU_ID_C CONSTANT SREPORT_WK.CHOHYO_ID%TYPE    := 'IPW30000173';
	-- 銘柄情報詳細リスト（期中手数料情報）
	C_MGR_KICHU_ID_A    CONSTANT SREPORT_WK.CHOHYO_ID%TYPE    := 'IP030000171';
	C_MGR_KICHU_ID_B    CONSTANT SREPORT_WK.CHOHYO_ID%TYPE    := 'IP030000172';
	C_MGR_KICHU_ID_C    CONSTANT SREPORT_WK.CHOHYO_ID%TYPE    := 'IP030000173';
	-- 実質記番号用の社債原簿
	C_KB_GENBO_ID_A     CONSTANT SREPORT_WK.CHOHYO_ID%TYPE    := 'IPP30000211';
	C_KB_GENBO_ID_B     CONSTANT SREPORT_WK.CHOHYO_ID%TYPE    := 'IPP30000212';
	-- 社債原簿
	C_GENBO_ID_A        CONSTANT SREPORT_WK.CHOHYO_ID%TYPE    := 'IP030004411';
	C_GENBO_ID_B        CONSTANT SREPORT_WK.CHOHYO_ID%TYPE    := 'IP030004412';
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	gMessage          varchar(500);                     -- メッセージ
	gCbOptionFlg      MOPTION_KANRI.OPTION_FLG%TYPE;     -- 振替ＣＢオプションフラグ
	gKbOptionFlg      MOPTION_KANRI.OPTION_FLG%TYPE;     -- 実質記番号オプションフラグ
	gKyOptionFlg      MOPTION_KANRI.OPTION_FLG%TYPE;     -- 金融債手数料登録判定フラグ
	gSaikenShurui     MGR_KIHON.SAIKEN_SHURUI%TYPE;      -- 債券種類
	gTokureiShasaiFlg MGR_KIHON.TOKUREI_SHASAI_FLG%TYPE; -- 特例社債フラグ
	gKkKanyoFlg       MGR_KIHON.KK_KANYO_FLG%TYPE;       -- 機構関与方式採用フラグ
	gKichuTesuTeiseiYmd MGR_STS.KICHU_TESU_TEISEI_YMD%TYPE; -- 期中手数料訂正日
	gJtkKbn           MGR_KIHON.JTK_KBN%TYPE;            -- 受託区分
	gPartmgrKbn       MGR_KIHON.PARTMGR_KBN%TYPE;        -- 分割銘柄区分
	gKomgrShokanFlg   varchar(2) := '0';           -- 子銘柄償還フラグ
	gReturnCd         integer := 0;                 -- リターン値
	gSqlErrM          text;                             -- エラーコメント
	

--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	RAISE NOTICE '[DEBUG] START - MGR_CD: %, ITAKU: %, USER: %', l_inMgrCd, l_inItakuKaishaCd, l_inUserId;
--	pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, C_PROGRAM_ID || ' START');
	-- メッセージ編集
	gMessage := 'ユーザＩＤ：' || l_inUserId || ', 委託会社コード：' || l_inItakuKaishaCd || ', 銘柄コード：' || l_inMgrCd;
	RAISE NOTICE '[DEBUG] Message: %', gMessage;
	-- 振替ＣＢオプションフラグ取得
	gCbOptionFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd, C_CB_OPTION_CD, '0');
	RAISE NOTICE '[DEBUG] After getOPTION_FLG 1';
--	pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '振替ＣＢオプションフラグ：' || gCbOptionFlg);
	-- 実質記番号オプションフラグ取得
	gKbOptionFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd, C_KB_OPTION_CD, '0');
	RAISE NOTICE '[DEBUG] After getOPTION_FLG 2';
--	pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '実質記番号オプションフラグ：' || gKbOptionFlg);
	-- 金融債手数料登録判定オプションフラグ取得
	gKyOptionFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd, C_KY_OPTION_CD, '0');
	RAISE NOTICE '[DEBUG] After getOPTION_FLG 3';
--	pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '実質記番号オプションフラグ：' || gKbOptionFlg);
	-- 銘柄基本情報取得
	RAISE NOTICE '[DEBUG] Before SELECT';
	BEGIN
		SELECT
			MG1.SAIKEN_SHURUI,			-- 債券種類
			MG1.TOKUREI_SHASAI_FLG,		-- 特例社債フラグ
			MG1.KK_KANYO_FLG,			-- 機構関与方式採用フラグ
			MG1.JTK_KBN,				-- 受託区分
			MG0.KICHU_TESU_TEISEI_YMD,	-- 期中手数料訂正日
			MG1.PARTMGR_KBN,			-- 分割銘柄区分
			SUBSTR(MG1.YOBI3, 14, 1)	-- 子銘柄償還区分
		INTO STRICT
			gSaikenShurui,
			gTokureiShasaiFlg,
			gKkKanyoFlg,
			gJtkKbn,
			gKichuTesuTeiseiYmd,
			gPartmgrKbn,
			gKomgrShokanFlg
		FROM
			MGR_STS MG0,
			MGR_KIHON MG1
		WHERE
			MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND	MG1.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
		AND MG1.MGR_CD = l_inMgrCd
		AND	MG1.MGR_CD = MG0.MGR_CD;
		RAISE NOTICE '[DEBUG] After SELECT - gSaikenShurui: %, gTokureiShasaiFlg: %', gSaikenShurui, gTokureiShasaiFlg;
	EXCEPTION
		-- 対象データなしの時
		WHEN no_data_found THEN
			-- 致命的エラーログ出力
			RAISE NOTICE '[DEBUG] No data found for MGR_CD: %, ITAKU_KAISHA_CD: %', l_inMgrCd, l_inItakuKaishaCd;
			CALL pkLog.fatal('ECM701', C_PROGRAM_ID, '銘柄_基本に存在しません。' || gMessage);
			-- 異常終了
			RETURN pkconstant.FATAL();
		WHEN OTHERS THEN
			RAISE NOTICE '[DEBUG] Exception: SQLSTATE=%, SQLERRM=%', SQLSTATE, SQLERRM;
			CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'Error: ' || SQLERRM);
			RETURN pkconstant.FATAL();
	END;
--	pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '債券種類：' || gSaikenShurui);
--	pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '特例社債フラグ：' || gTokureiShasaiFlg);
--	pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '機構関与方式採用フラグ：' || gKkKanyoFlg);
	-- 帳票ワークの削除
	RAISE NOTICE '[DEBUG] Before DELETE';
	DELETE FROM SREPORT_WK
	WHERE
		KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = l_inGyomuYmd
		AND CHOHYO_ID IN (
			-- ＣＢ用の銘柄情報詳細リスト（基本情報）
			C_CB_MGR_KIHON_ID_A,
			C_CB_MGR_KIHON_ID_B,
			-- 特例債用の銘柄情報詳細リスト（基本情報）
			C_TO_MGR_KIHON_ID_A,
			C_TO_MGR_KIHON_ID_B,
			-- 副受託銘柄情報詳細リスト（基本情報）
			C_FU_MGR_KIHON_ID_A,
			C_FU_MGR_KIHON_ID_B,
			-- 銘柄情報詳細リスト（基本情報）
			C_MGR_KIHON_ID_A,
			C_MGR_KIHON_ID_B,
			-- 銘柄情報詳細リスト（発行時手数料情報）
			C_MGR_HAKKO_ID_A,
			C_MGR_HAKKO_ID_B,
			-- ＣＢ用の銘柄情報詳細リスト（期中手数料情報）
			C_CB_MGR_KICHU_ID_A,
			C_CB_MGR_KICHU_ID_B,
			C_CB_MGR_KICHU_ID_C,
			-- 銘柄情報詳細リスト（期中手数料情報）
			C_MGR_KICHU_ID_A,
			C_MGR_KICHU_ID_B,
			C_MGR_KICHU_ID_C,
			-- 実質記番号用の社債原簿
			C_KB_GENBO_ID_A,
			C_KB_GENBO_ID_B,
			-- 社債原簿
			C_GENBO_ID_A,
			C_GENBO_ID_B
		);
	RAISE NOTICE '[DEBUG] After DELETE, rows affected: %', FOUND;
	-- 銘柄情報詳細リスト（基本情報）データ作成 =========================================================================START
	-- 振替ＣＢオプションフラグが「1：導入済」かつ債券種類が「80：新株予約権付社債」、「89：その他（ＣＢ）」の時
	RAISE NOTICE '[DEBUG] Check CB: gCbOptionFlg=%, gSaikenShurui=%, gJtkKbn=%', gCbOptionFlg, gSaikenShurui, gJtkKbn;
	IF gCbOptionFlg = '1' AND gSaikenShurui IN ('80', '89') AND gJtkKbn != '2' THEN
		RAISE NOTICE '[DEBUG] Entering CB branch - calling SPIPW001K00R01';
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, 'ＣＢ用の銘柄情報詳細リスト（基本情報）データ作成コール-SPIPW001K00R01');
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第１引数（銘柄コード）：' || l_inMgrCd);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第２引数（委託会社コード）：' || l_inItakuKaishaCd);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第３引数（ユーザーＩＤ）：' || l_inUserId);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第４引数（帳票区分）：' || l_inChohyoKbn);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第５引数（業務日付）：' || l_inGyomuYmd);
		-- ＣＢ用の銘柄情報詳細リスト（基本情報）データ作成
		CALL SPIPW001K00R01(
			l_inMgrCd,         -- 銘柄コード
			l_inItakuKaishaCd, -- 委託会社コード
			l_inUserId,        -- ユーザーＩＤ
			l_inChohyoKbn,     -- 帳票区分
			l_inGyomuYmd,      -- 業務日付
			gReturnCd,         -- リターン値
			gSqlErrM            -- エラーコメント
		);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, 'ＣＢ用の銘柄情報詳細リスト（基本情報）データ作成の返値：' || gReturnCd);
		-- 返値が「2:対象データなし」の時
		IF gReturnCd = C_NODATA THEN
--			pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, 'ＣＢ用の銘柄情報詳細リスト（基本情報）「対象データなし」データ削除');
			-- 帳票ワークの削除
			DELETE FROM SREPORT_WK
			WHERE
				KEY_CD = l_inItakuKaishaCd
				AND USER_ID = l_inUserId
				AND CHOHYO_KBN = l_inChohyoKbn
				AND SAKUSEI_YMD = l_inGyomuYmd
				AND CHOHYO_ID IN (C_CB_MGR_KIHON_ID_A, C_CB_MGR_KIHON_ID_B);
		-- 返値が「99:異常終了」の時
		ELSIF gReturnCd = pkconstant.FATAL() THEN
			-- 致命的エラーログ出力
			CALL pkLog.fatal('ECM701', C_PROGRAM_ID, '銘柄情報詳細リスト（基本情報）データ作成中に異常終了しました。' || gMessage);
			-- 異常終了
			RETURN gReturnCd;
		END IF;
	-- 特例社債フラグが「Y：特例社債等」の時
	ELSIF gTokureiShasaiFlg = 'Y' AND gJtkKbn != '2' THEN
		RAISE NOTICE '[DEBUG] Entering Tokurei branch - calling SPIPK001K00R14';
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '特例債用の銘柄情報詳細リスト（基本情報）データ作成コール-SPIPK001K00R14');
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第１引数（銘柄コード）：' || l_inMgrCd);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第２引数（委託会社コード）：' || l_inItakuKaishaCd);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第３引数（ユーザーＩＤ）：' || l_inUserId);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第４引数（帳票区分）：' || l_inChohyoKbn);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第５引数（業務日付）：' || l_inGyomuYmd);
		-- 特例債用の銘柄情報詳細リスト（基本情報）データ作成
		CALL SPIPK001K00R14(
			l_inMgrCd,         -- 銘柄コード
			l_inItakuKaishaCd, -- 委託会社コード
			l_inUserId,        -- ユーザーＩＤ
			l_inChohyoKbn,     -- 帳票区分
			l_inGyomuYmd,      -- 業務日付
			gReturnCd,         -- リターン値
			gSqlErrM            -- エラーコメント
		);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '特例債用の銘柄情報詳細リスト（基本情報）データ作成の返値：' || gReturnCd);
		-- 返値が「2:対象データなし」の時
		IF gReturnCd = C_NODATA THEN
--			pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '特例債用の銘柄情報詳細リスト（基本情報）「対象データなし」データ削除');
			-- 帳票ワークの削除
			DELETE FROM SREPORT_WK
			WHERE
				KEY_CD = l_inItakuKaishaCd
				AND USER_ID = l_inUserId
				AND CHOHYO_KBN = l_inChohyoKbn
				AND SAKUSEI_YMD = l_inGyomuYmd
				AND CHOHYO_ID IN (C_TO_MGR_KIHON_ID_A, C_TO_MGR_KIHON_ID_B);
		-- 返値が「99:異常終了」の時
		ELSIF gReturnCd = pkconstant.FATAL() THEN
			-- 致命的エラーログ出力
			CALL pkLog.fatal('ECM701', C_PROGRAM_ID, '銘柄情報詳細リスト（基本情報）データ作成中に異常終了しました。' || gMessage);
			-- 異常終了
			RETURN gReturnCd;
		END IF;
	-- 副受託の時
	ELSIF gJtkKbn = '2' THEN
		RAISE NOTICE '[DEBUG] Calling spIp10901 (副受託)';
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '副受託銘柄情報詳細リスト（基本情報）データ作成コール-spIp10901');
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第１引数（銘柄コード）：' || l_inMgrCd);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第２引数（委託会社コード）：' || l_inItakuKaishaCd);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第３引数（ユーザーＩＤ）：' || l_inUserId);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第４引数（帳票区分）：' || l_inChohyoKbn);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第５引数（業務日付）：' || l_inGyomuYmd);
		-- 副受託銘柄情報詳細リスト（基本情報）データ作成
		CALL spIp10901(
			l_inMgrCd,         -- 銘柄コード
			l_inItakuKaishaCd, -- 委託会社コード
			l_inUserId,        -- ユーザーＩＤ
			l_inChohyoKbn,     -- 帳票区分
			l_inGyomuYmd,      -- 業務日付
			gReturnCd,         -- リターン値
			gSqlErrM            -- エラーコメント
		);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '副受託銘柄情報詳細リスト（基本情報）データ作成の返値：' || gReturnCd);
		-- 返値が「2:対象データなし」の時
		IF gReturnCd = C_NODATA THEN
--			pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '副受託銘柄情報詳細リスト（基本情報）「対象データなし」データ削除');
			-- 帳票ワークの削除
			DELETE FROM SREPORT_WK
			WHERE
				KEY_CD = l_inItakuKaishaCd
				AND USER_ID = l_inUserId
				AND CHOHYO_KBN = l_inChohyoKbn
				AND SAKUSEI_YMD = l_inGyomuYmd
				AND CHOHYO_ID IN (C_FU_MGR_KIHON_ID_A, C_FU_MGR_KIHON_ID_B);
		-- 返値が「99:異常終了」の時
		ELSIF gReturnCd = pkconstant.FATAL() THEN
			-- 致命的エラーログ出力
			CALL pkLog.fatal('ECM701', C_PROGRAM_ID, '副受託銘柄情報詳細リスト（基本情報）データ作成中に異常終了しました。' || gMessage);
			-- 異常終了
			RETURN gReturnCd;
		END IF;
	-- その他の時
	ELSE
		RAISE NOTICE '[DEBUG] Entering ELSE branch (standard) - calling spIp00101';
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '銘柄情報詳細リスト（基本情報）データ作成コール-spIp00101');
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第１引数（銘柄コード）：' || l_inMgrCd);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第２引数（委託会社コード）：' || l_inItakuKaishaCd);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第３引数（ユーザーＩＤ）：' || l_inUserId);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第４引数（帳票区分）：' || l_inChohyoKbn);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第５引数（業務日付）：' || l_inGyomuYmd);
		-- 銘柄情報詳細リスト（基本情報）データ作成
		CALL spIp00101(
			l_inMgrCd,         -- 銘柄コード
			l_inItakuKaishaCd, -- 委託会社コード
			l_inUserId,        -- ユーザーＩＤ
			l_inChohyoKbn,     -- 帳票区分
			l_inGyomuYmd,      -- 業務日付
			gReturnCd,         -- リターン値
			gSqlErrM            -- エラーコメント
		);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '銘柄情報詳細リスト（基本情報）データ作成の返値：' || gReturnCd);
		-- 返値が「2:対象データなし」の時
		IF gReturnCd = C_NODATA THEN
--			pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '銘柄情報詳細リスト（基本情報）「対象データなし」データ削除');
			-- 帳票ワークの削除
			DELETE FROM SREPORT_WK
			WHERE
				KEY_CD = l_inItakuKaishaCd
				AND USER_ID = l_inUserId
				AND CHOHYO_KBN = l_inChohyoKbn
				AND SAKUSEI_YMD = l_inGyomuYmd
				AND CHOHYO_ID IN (C_MGR_KIHON_ID_A, C_MGR_KIHON_ID_B);
		-- 返値が「99:異常終了」の時
		ELSIF gReturnCd = pkconstant.FATAL() THEN
			-- 致命的エラーログ出力
			CALL pkLog.fatal('ECM701', C_PROGRAM_ID, '銘柄情報詳細リスト（基本情報）データ作成中に異常終了しました。' || gMessage);
			-- 異常終了
			RETURN gReturnCd;
		END IF;
	END IF;
	-- 銘柄情報詳細リスト（基本情報）データ作成 =========================================================================END
--	pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '銘柄情報詳細リスト（発行時手数料情報）データ作成-spIp00106');
--	pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第１引数（銘柄コード）：' || l_inMgrCd);
--	pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第２引数（委託会社コード）：' || l_inItakuKaishaCd);
--	pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第３引数（ユーザーＩＤ）：' || l_inUserId);
--	pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第４引数（帳票区分）：' || l_inChohyoKbn);
--	pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第５引数（業務日付）：' || l_inGyomuYmd);
	-- 銘柄情報詳細リスト（発行時手数料情報）データ作成==================================================================START
	CALL spIp00106(
			l_inMgrCd,         -- 銘柄コード
			l_inItakuKaishaCd, -- 委託会社コード
			l_inUserId,        -- ユーザーＩＤ
			l_inChohyoKbn,     -- 帳票区分
			l_inGyomuYmd,      -- 業務日付
			gReturnCd,         -- リターン値
			gSqlErrM            -- エラーコメント
	);
--	pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '銘柄情報詳細リスト（発行時手数料情報）データ作成の返値：' || gReturnCd);
	-- 返値が「2:対象データなし」の時
	IF gReturnCd = C_NODATA THEN
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '銘柄情報詳細リスト（発行時手数料情報）「対象データなし」データ削除');
		-- 帳票ワークの削除
		DELETE FROM SREPORT_WK
		WHERE
			KEY_CD = l_inItakuKaishaCd
			AND USER_ID = l_inUserId
			AND CHOHYO_KBN = l_inChohyoKbn
			AND SAKUSEI_YMD = l_inGyomuYmd
			AND CHOHYO_ID IN (C_MGR_HAKKO_ID_A, C_MGR_HAKKO_ID_B);
	-- 返値が「99:異常終了」の時
	ELSIF gReturnCd = pkconstant.FATAL() THEN
		-- 致命的エラーログ出力
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, '銘柄情報詳細リスト（発行時手数料情報）データ作成中に異常終了しました。' || gMessage);
		-- 異常終了
		RETURN gReturnCd;
	END IF;
	-- 銘柄情報詳細リスト（発行時手数料情報）データ作成==================================================================END
	-- 銘柄情報詳細リスト（期中手数料情報）データ作成 ===================================================================START
	-- 期中手数料情報の銘柄詳細リストは、発行時手数料情報と違い、手数料が設定されていない場合に返り値が"2"（対象データ無し）を返さない。
	-- そこで、個別照会で印刷不可の場合は、そのロジックに合わせて、データ作成SPを実行させないようにする。
	-- 振替ＣＢオプションフラグが「1：導入済」かつ債券種類が「80：新株予約権付社債」、「89：その他（ＣＢ）」の時
	IF gCbOptionFlg = '1' AND gSaikenShurui IN ('80', '89') THEN
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, 'ＣＢ用の銘柄情報詳細リスト（期中手数料情報）データ作成-SPIPW001K00R07');
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第１引数（銘柄コード）：' || l_inMgrCd);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第２引数（委託会社コード）：' || l_inItakuKaishaCd);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第３引数（ユーザーＩＤ）：' || l_inUserId);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第４引数（帳票区分）：' || l_inChohyoKbn);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第５引数（業務日付）：' || l_inGyomuYmd);
		-- ＣＢ用の銘柄情報詳細リスト（期中手数料情報）データ作成
		-- 期中手数料訂正日がNULLで無い場合はSPを実行
		IF (trim(both gKichuTesuTeiseiYmd) IS NOT NULL AND (trim(both gKichuTesuTeiseiYmd))::text <> '') THEN
			CALL SPIPW001K00R07(
					l_inMgrCd,         -- 銘柄コード
					l_inItakuKaishaCd, -- 委託会社コード
					l_inUserId,        -- ユーザーＩＤ
					l_inChohyoKbn,     -- 帳票区分
					l_inGyomuYmd,      -- 業務日付
					gReturnCd,         -- リターン値
					gSqlErrM            -- エラーコメント
			);
	--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, 'ＣＢ用の銘柄情報詳細リスト（期中手数料情報）データ作成の返値：' || gReturnCd);
			-- 返値が「2:対象データなしの時
			IF gReturnCd = C_NODATA THEN
	--			pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, 'ＣＢ用の銘柄情報詳細リスト（期中手数料情報）「対象データなし」データ削除');
				-- 帳票ワークの削除
				DELETE FROM SREPORT_WK
				WHERE
					KEY_CD = l_inItakuKaishaCd
					AND USER_ID = l_inUserId
					AND CHOHYO_KBN = l_inChohyoKbn
					AND SAKUSEI_YMD = l_inGyomuYmd
					AND CHOHYO_ID IN (C_CB_MGR_KICHU_ID_A, C_CB_MGR_KICHU_ID_B, C_CB_MGR_KICHU_ID_C);
			-- 返値が「99:異常終了」の時
			ELSIF gReturnCd = pkconstant.FATAL() THEN
				-- 致命的エラーログ出力
				CALL pkLog.fatal('ECM701', C_PROGRAM_ID, '銘柄情報詳細リスト（期中手数料情報）データ作成中に異常終了しました。' || gMessage);
				-- 異常終了
				RETURN gReturnCd;
			END IF;
		END IF;
	-- その他の時
	ELSE
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '銘柄情報詳細リスト（期中手数料情報）データ作成-spIp00107');
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第１引数（銘柄コード）：' || l_inMgrCd);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第２引数（委託会社コード）：' || l_inItakuKaishaCd);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第３引数（ユーザーＩＤ）：' || l_inUserId);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第４引数（帳票区分）：' || l_inChohyoKbn);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第５引数（業務日付）：' || l_inGyomuYmd);
		-- 銘柄情報詳細リスト（期中手数料情報）データ作成
		-- 以下の条件の時、SPを実行
		-- ①副受託銘柄で、期中手数料訂正日がNULLでない場合
		-- ②特例債で親銘柄・償還済み子銘柄でなく、期中手数料訂正日がNULLでない場合
		-- ③新発債で、受託区分が５かつ金融債手数料登録判定フラグが"1"でなく、期中手数料訂正日がNULLでない場合
		IF (trim(both gKichuTesuTeiseiYmd) IS NOT NULL AND (trim(both gKichuTesuTeiseiYmd))::text <> '') AND (gJtkKbn = '2' OR (gTokureiShasaiFlg = 'Y' AND NOT(gPartmgrKbn = '1' OR (gPartmgrKbn = '2' AND gKomgrShokanFlg = '1'))) OR (gTokureiShasaiFlg != 'Y' AND NOT(gJtkKbn = '5' AND gKyOptionFlg != '1'))) THEN
			CALL spIp00107(
					l_inMgrCd,         -- 銘柄コード
					l_inItakuKaishaCd, -- 委託会社コード
					l_inUserId,        -- ユーザーＩＤ
					l_inChohyoKbn,     -- 帳票区分
					l_inGyomuYmd,      -- 業務日付
					gReturnCd,         -- リターン値
					gSqlErrM            -- エラーコメント
			);
	--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '銘柄情報詳細リスト（期中手数料情報）データ作成の返値：' || gReturnCd);
			-- 返値が「2:対象データなし」の時
			IF gReturnCd = C_NODATA THEN
	--			pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '銘柄情報詳細リスト（期中手数料情報）「対象データなし」データ削除');
				-- 帳票ワークの削除
				DELETE FROM SREPORT_WK
				WHERE
					KEY_CD = l_inItakuKaishaCd
					AND USER_ID = l_inUserId
					AND CHOHYO_KBN = l_inChohyoKbn
					AND SAKUSEI_YMD = l_inGyomuYmd
					AND CHOHYO_ID IN (C_MGR_KICHU_ID_A, C_MGR_KICHU_ID_B, C_MGR_KICHU_ID_C);
			-- 返値が「99:異常終了」の時
			ELSIF gReturnCd = pkconstant.FATAL() THEN
			-- 致命的エラーログ出力
				CALL pkLog.fatal('ECM701', C_PROGRAM_ID, '銘柄情報詳細リスト（期中手数料情報）データ作成中に異常終了しました。' || gMessage);
				-- 異常終了
				RETURN gReturnCd;
			END IF;
		END IF;
	END IF;
	-- 銘柄情報詳細リスト（期中手数料情報）データ作成 ===================================================================END
	-- 社債原簿データ作成 ===============================================================================================START
	-- 実質記番号オプションフラグが「1：導入済」かつ機構関与方式採用フラグが「2：機構非関与方式（実質記番号管理方式）」の時
	IF gKbOptionFlg = '1' AND gKkKanyoFlg = '2' THEN
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '実質記番号用の社債原簿データ作成-SFIPP002K00R01');
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第１引数（委託会社コード）：' || l_inItakuKaishaCd);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第２引数（ユーザーＩＤ）：' || l_inUserId);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第３引数（帳票区分）：' || l_inChohyoKbn);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第４引数（通知日）：NULL');
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第５引数（銘柄コード）：' || l_inMgrCd);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第６引数（ＩＳＩＮコード）：NULL');
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第７引数（基準年月）：NULL' );
		-- 実質記番号用の社債原簿データ作成
		gReturnCd := SFIPP002K00R01(
									l_inItakuKaishaCd,          -- 委託会社コード
									l_inUserId,                 -- ユーザーＩＤ
									l_inChohyoKbn,              -- 帳票区分
									NULL,                       -- 通知日
									l_inMgrCd,                  -- 銘柄コード
									NULL,                       -- ＩＳＩＮコード
									NULL,                       -- 基準年月
									gSqlErrM                     -- エラーコメント
								);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '実質記番号用の社債原簿データ作成の返値：' || gReturnCd);
		-- 返値が「2:対象データなし」の時
		IF gReturnCd = C_NODATA THEN
--			pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '実質記番号用の社債原簿「対象データなし」データ削除');
			-- 帳票ワークの削除
			DELETE FROM SREPORT_WK
			WHERE
				KEY_CD = l_inItakuKaishaCd
				AND USER_ID = l_inUserId
				AND CHOHYO_KBN = l_inChohyoKbn
				AND SAKUSEI_YMD = l_inGyomuYmd
				AND CHOHYO_ID IN (C_KB_GENBO_ID_A, C_KB_GENBO_ID_B);
		-- 返値が「99:異常終了」の時
		ELSIF gReturnCd = pkconstant.FATAL() THEN
			-- 致命的エラーログ出力
			CALL pkLog.fatal('ECM701', C_PROGRAM_ID, '社債原簿データ作成中に異常終了しました。' || gMessage);
			-- 異常終了
			RETURN gReturnCd;
		END IF;
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '実質記番号用の社債原簿「送付」データ削除');
		-- 帳票ワークの削除（送付は常に削除）
		DELETE FROM SREPORT_WK
		WHERE
			KEY_CD = l_inItakuKaishaCd
			AND USER_ID = l_inUserId
			AND CHOHYO_KBN = l_inChohyoKbn
			AND SAKUSEI_YMD = l_inGyomuYmd
			AND CHOHYO_ID = C_KB_GENBO_ID_A;
	-- その他の時
	ELSE
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '社債原簿データ作成-SPIP04401');
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第１引数（ユーザーＩＤ）：' || l_inUserId);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第２引数（委託会社コード）：' || l_inItakuKaishaCd);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第３引数（銘柄コード）：' || l_inMgrCd);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第４引数（ＩＳＩＮコード）：NULL');
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '第５引数（通知日）：NULL');
		-- 社債原簿データ作成
		CALL SPIP04401(
			l_inUserId,        -- ユーザーＩＤ
			l_inItakuKaishaCd, -- 委託会社コード
			l_inMgrCd,         -- 銘柄コード
			NULL,              -- ＩＳＩＮコード
			NULL,              -- 通知日
			NULL,              -- 画面ID
			NULL,              -- 帳票出力グループ1
			NULL,              -- 帳票出力グループ2
			NULL,              -- 帳票出力グループ3
			NULL,              -- 帳票出力グループ4
			NULL,              -- 帳票出力グループ5
			gReturnCd,         -- リターン値
			gSqlErrM            -- エラーコメント
		);
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '社債原簿データ作成の返値：' || gReturnCd);
		-- 返値が「2:対象データなし」の時
		IF gReturnCd = C_NODATA THEN
--			pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '社債原簿「対象データなし」データ削除');
			-- 帳票ワークの削除
			DELETE FROM SREPORT_WK
			WHERE
				KEY_CD = l_inItakuKaishaCd
				AND USER_ID = l_inUserId
				AND CHOHYO_KBN = l_inChohyoKbn
				AND SAKUSEI_YMD = l_inGyomuYmd
				AND CHOHYO_ID IN (C_GENBO_ID_A, C_GENBO_ID_B);
		-- 返値が「99:異常終了」の時
		ELSIF gReturnCd = pkconstant.FATAL() THEN
			-- 致命的エラーログ出力
			CALL pkLog.fatal('ECM701', C_PROGRAM_ID, '社債原簿データ作成中に異常終了しました。' || gMessage);
			-- 異常終了
			RETURN gReturnCd;
		END IF;
--		pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, '社債原簿「送付」データ削除');
		-- 帳票ワークの削除（送付は常に削除）
		DELETE FROM SREPORT_WK
		WHERE
			KEY_CD = l_inItakuKaishaCd
			AND USER_ID = l_inUserId
			AND CHOHYO_KBN = l_inChohyoKbn
			AND SAKUSEI_YMD = l_inGyomuYmd
			AND CHOHYO_ID = C_GENBO_ID_A;
	END IF;
	-- 社債原簿データ作成 ===============================================================================================END
	-- 正常終了
	RAISE NOTICE '[DEBUG] Returning SUCCESS';
	RETURN pkconstant.success();
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		RAISE NOTICE '[DEBUG] EXCEPTION caught: SQLSTATE=%, SQLERRM=%', SQLSTATE, SQLERRM;
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'SQLERRM:' || SQLERRM);
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipx016k00r01 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE, l_inUserId SREPORT_WK.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_inGyomuYmd SREPORT_WK.SAKUSEI_YMD%TYPE, l_inMgrCd MGR_KIHON.MGR_CD%TYPE  ) FROM PUBLIC;
