




CREATE OR REPLACE PROCEDURE spipp014k00r02_02 ( 
	l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE,     -- 委託会社コード
 l_inUserId SREPORT_WK.USER_ID%TYPE,    -- ユーザーＩＤ
 l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, -- 帳票区分
 l_outSqlCode OUT integer                       -- リターン値
 ) AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2007
-- * 会社名:JIP
-- *
-- * 概要　:実質記番号管理償還回次期日調整リスト作成
-- *
-- * 引数　:l_inItakuKaishaCd :委託会社コード
-- *        l_inUserId        :ユーザーＩＤ
-- *        l_inChohyoKbn     :帳票区分
-- *        l_outSqlCode      :リターン値
-- *
-- * 返り値: なし
-- *
-- * @author ASK
-- * @version $Id: SPIPP014K00R02_02.sql,v 1.2 2008/09/10 01:11:43 harada Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2007.07.03 中村        新規作成
-- ***************************************************************************
--
--	/*==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_PROCEDURE_ID CONSTANT varchar(50)              := 'SPIPP014K00R02_02'; -- プロシージャＩＤ
	C_CHOHYO_ID    CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IPP30001411';       -- 帳票ＩＤ
	C_NO_DATA      CONSTANT numeric(1)                 := 2;                   -- 対象データなし
	C_OPTION_CD    CONSTANT MOPTION_KANRI.OPTION_CD%TYPE := 'IPP1003302010';  -- 実質記番号管理オプションコード
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gSeqNo           integer;                           -- シーケンス
	gGyomuYmd        SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE; -- 業務日付
	gItakuKaishaRnm  SOWN_INFO.BANK_RNM%TYPE;           -- 委託会社略名
	gKknChokyuTmgNm  varchar(24);                      -- 基金徴求タイミング名称
	gKknBillOutTmgNm varchar(24);                      -- 基金請求書出力タイミング名称
	gStartYmd        char(8);                           -- 業務年月の１日
	gVal             MPROCESS_CTL.CTL_VALUE%TYPE;       -- 処理制御マスタのリターン値
	gNum             integer;                           -- 期日補正対象月後
	gTaishoYmd       char(8);                           -- 対象年月日
	gRtnCd           integer := 0;                 -- リターンコード
	
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	curMeisai CURSOR FOR
		SELECT
			P06.MGR_CD,                -- 銘柄コード
			P06.ISIN_CD,               -- ＩＳＩＮコード
			P06.SHOKAN_KJT,            -- 償還期日
			P06.KBG_SHOKAN_KBN,        -- 償還区分（実質記番号用）
			P06.DATE_SHURUI_CD,        -- 日付種類コード
			P06.HENKO_BEF_YMD,         -- 変更前年月日
			P06.HENKO_AFT_YMD,         -- 変更後年月日
			VMG1.MGR_RNM,              -- 銘柄略称
			VMG1.KKN_CHOKYU_TMG1,      -- 基金徴求タイミング１
			VMG1.KKN_CHOKYU_DD,        -- 基金徴求タイミング日数
			VMG1.KOBETSUSEIKYUOUT_KBN, -- 個別請求書出力区分
			VMG1.KKNBILL_OUT_TMG1,     -- 基金請求書出力タイミング１
			VMG1.KKNBILL_OUT_DD,       -- 基金請求書出力タイミング日数
			(
				SELECT
					CODE_NM
				FROM
					SCODE
				WHERE
					CODE_SHUBETSU = '226'
					AND CODE_VALUE = P06.KBG_SHOKAN_KBN
			) AS KBG_SHOKAN_KBN_NM,    -- 償還区分名称（実質記番号用）
			(
				SELECT
					CODE_NM
				FROM
					SCODE
				WHERE
					CODE_SHUBETSU = '143'
					AND CODE_VALUE = P06.DATE_SHURUI_CD
			) AS DATE_SHURUI_NM,       -- 日付種類名称
			(
				SELECT
					CODE_NM
				FROM
					SCODE
				WHERE
					CODE_SHUBETSU = '225'
					AND CODE_VALUE = P06.HENKO_RIYU_CD
			) AS DATE_HENKO_RIYU_NM,   -- 変更理由名称
			(
				SELECT
					CODE_NM
				FROM
					SCODE
				WHERE
					CODE_SHUBETSU = '135'
					AND CODE_VALUE = VMG1.KKN_CHOKYU_TMG1
			) AS KKN_CHOKYU_TMG1_NM,   -- 基金徴求タイミング１名称
			(
				SELECT
					CODE_NM
				FROM
					SCODE
				WHERE
					CODE_SHUBETSU = '132'
					AND CODE_VALUE = VMG1.KKN_CHOKYU_TMG2
			) AS KKN_CHOKYU_TMG2_NM,   -- 基金徴求タイミング２名称
			(
				SELECT
					CODE_NM
				FROM
					SCODE
				WHERE
					CODE_SHUBETSU = '135'
					AND CODE_VALUE = VMG1.KKNBILL_OUT_TMG1
			) AS KKNBILL_OUT_TMG1_NM,  -- 基金請求書出力タイミング１名称
			(
				SELECT
					CODE_NM
				FROM
					SCODE
				WHERE
					CODE_SHUBETSU = '132'
					AND CODE_VALUE = VMG1.KKNBILL_OUT_TMG2
			) AS KKNBILL_OUT_TMG2_NM,  -- 基金請求書出力タイミング２名称
			(
				SELECT
					COUNT(*)
				FROM
					MOD_KBG_SHOKIJ P06,
					MGR_KIHON_VIEW VMG1
				WHERE
					P06.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
					AND P06.MGR_CD = VMG1.MGR_CD
					AND P06.ITAKU_KAISHA_CD = l_inItakuKaishaCd
					AND VMG1.MGR_STAT_KBN = '1'
			) AS TAISHO_RECORD              -- 対象件数
		FROM
			MOD_KBG_SHOKIJ P06,
			MGR_KIHON_VIEW VMG1
		WHERE
			P06.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
			AND P06.MGR_CD = VMG1.MGR_CD
			AND P06.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND VMG1.MGR_STAT_KBN = '1'
		ORDER BY
			P06.MGR_CD,
			P06.SHOKAN_KJT,
			P06.KBG_SHOKAN_KBN,
			P06.DATE_SHURUI_CD;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, C_PROCEDURE_ID || ' START');
	-- 実質記番号管理オプションフラグチェック
	IF pkControl.getOPTION_FLG(l_inItakuKaishaCd, C_OPTION_CD, '0')::integer = 0 THEN
		-- ＯＦＦの場合は終了
		l_outSqlCode := gRtnCd;
		RETURN;
	END IF;
	-- 入力パラメータチェック
	IF coalesce(l_inItakuKaishaCd::text, '') = ''  -- 委託会社コード
	OR coalesce(l_inUserId::text, '') = ''         -- ユーザーID
	OR coalesce(l_inChohyoKbn::text, '') = '' THEN  -- 帳票区分
		-- ログ書込み
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID, 1, 12), 'パラメータエラー');
		l_outSqlCode := pkconstant.FATAL();
		RETURN;
	END IF;
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '引数');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '委託会社コード:"' || l_inItakuKaishaCd || '"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'ユーザーＩＤ:"' || l_inUserId || '"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票区分:"' || l_inChohyoKbn || '"');
	
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '業務日付:"' || gGyomuYmd || '"');
	
	-- 対象年月日の取得
	-- 「業務年月の１日」取得
	gStartYmd := SUBSTR(pkDate.getGyomuYmd(), 1, 6) || '01';
	-- MPROCESS_CTLからカレンダー補正のデータを取得
	gVal := pkcontrol.getCtlValue(l_inItakuKaishaCd, 'CALENDARHOSEI', '4');
	-- 数値チェック
	gNum := sfCmToNumeric(gVal);
	IF coalesce(gNum::text, '') = '' THEN
		-- エラーの場合は４ヶ月後を設定
		gNum := 4;
		gTaishoYmd := pkDate.calcMonth(gStartYmd, gNum);
	ELSIF gNum = 0 THEN
		-- 0の場合は、業務日付の翌営業日を設定
		gTaishoYmd := pkDate.getYokuBusinessYmd(gGyomuYmd);
	ELSE
		-- 「業務年月の１日のnヵ月後」取得
		gTaishoYmd := pkDate.calcMonth(gStartYmd, gNum);
	END IF;
	-- シーケンス初期化
	gSeqNo := 1;
	-- 委託会社略名取得
	SELECT
		CASE WHEN JIKO_DAIKO_KBN='2' THEN  BANK_RNM  ELSE ' ' END
	INTO STRICT
		gItakuKaishaRnm
	FROM
		VJIKO_ITAKU
	WHERE
		KAIIN_ID = l_inItakuKaishaCd;
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '委託会社略名:"' || gItakuKaishaRnm || '"');
	-- 帳票ワーク削除
	DELETE FROM SREPORT_WK
	WHERE
		KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = gGyomuYmd
		AND CHOHYO_ID = C_CHOHYO_ID;
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '削除条件');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '識別コード:"' || l_inItakuKaishaCd || '"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'ユーザーＩＤ:"' || l_inUserId || '"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票区分:"' || l_inChohyoKbn || '"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '作成日付:"' || gGyomuYmd || '"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票ＩＤ:"' || C_CHOHYO_ID || '"');
	-- データ取得
	FOR recMeisai IN curMeisai
	LOOP
		-- 基金徴求タイミング名称編集
		gKknChokyuTmgNm := SPIPP014K00R02_02_getTmgNm(
										recMeisai.KKN_CHOKYU_TMG1,    -- 基金徴求タイミング１
										recMeisai.KKN_CHOKYU_DD,      -- 基金徴求タイミング日数
										recMeisai.KKN_CHOKYU_TMG1_NM, -- 基金徴求タイミング１名称
										recMeisai.KKN_CHOKYU_TMG2_NM   -- 基金徴求タイミング２名称
										);
--		pkLog.debug(l_inUserId, C_PROCEDURE_ID, '基金徴求タイミング名称:"' || gKknChokyuTmgNm || '"');
		-- 基金請求書出力タイミング名称編集 --------------------------------------
		-- 個別請求書出力区分が設定されている時
		IF recMeisai.KOBETSUSEIKYUOUT_KBN = '1' THEN
			gKknBillOutTmgNm := SPIPP014K00R02_02_getTmgNm(
											recMeisai.KKNBILL_OUT_TMG1,    -- 基金請求書出力タイミング１
											recMeisai.KKNBILL_OUT_DD,      -- 基金請求書出力タイミング日数
											recMeisai.KKNBILL_OUT_TMG1_NM, -- 基金請求書出力タイミング１名称
											recMeisai.KKNBILL_OUT_TMG2_NM   -- 基金請求書出力タイミング２名称
											);
		ELSE
			gKknBillOutTmgNm := 'システム設定値';
		END IF;
--		pkLog.debug(l_inUserId, C_PROCEDURE_ID, '基金請求書出力タイミング:"' || gKknBillOutTmgNm || '"');
		--------------------------------------------------------------------------
		-- 明細レコード追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := gItakuKaishaRnm;	-- 委託会社略名
		v_item.l_inItem003 := recMeisai.MGR_CD;	-- 銘柄コード
		v_item.l_inItem004 := recMeisai.ISIN_CD;	-- ＩＳＩＮコード
		v_item.l_inItem005 := recMeisai.MGR_RNM;	-- 銘柄略称
		v_item.l_inItem006 := gKknChokyuTmgNm;	-- 基金徴求タイミング名称
		v_item.l_inItem007 := gKknBillOutTmgNm;	-- 基金請求書出力タイミング名称
		v_item.l_inItem008 := recMeisai.SHOKAN_KJT;	-- 償還期日
		v_item.l_inItem009 := recMeisai.KBG_SHOKAN_KBN_NM;	-- 償還区分名称（実質記番号用）
		v_item.l_inItem010 := recMeisai.DATE_SHURUI_CD;	-- 日付種類コード
		v_item.l_inItem011 := recMeisai.DATE_SHURUI_NM;	-- 日付種類名称
		v_item.l_inItem012 := recMeisai.HENKO_BEF_YMD;	-- 変更前年月日
		v_item.l_inItem013 := recMeisai.HENKO_AFT_YMD;	-- 変更後年月日
		v_item.l_inItem014 := recMeisai.DATE_HENKO_RIYU_NM;	-- 変更理由名称
		v_item.l_inItem015 := C_CHOHYO_ID;	-- 帳票ＩＤ
		v_item.l_inItem016 := gGyomuYmd;	-- データ基準日
		v_item.l_inItem017 := gTaishoYmd;	-- 対象年月日
		v_item.l_inItem018 := recMeisai.TAISHO_RECORD;	-- 対象件数
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> gGyomuYmd,
			l_inChohyoId	=> C_CHOHYO_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> 1,
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		-- シーケンスのカウント
		gSeqNo := gSeqNo + 1;
	END LOOP;
	-- 対象データなし
	IF gSeqNo = 1 THEN
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := gItakuKaishaRnm;	-- 委託会社略名
		v_item.l_inItem015 := C_CHOHYO_ID;	-- 帳票ＩＤ
		v_item.l_inItem016 := gGyomuYmd;	-- データ基準日
		v_item.l_inItem017 := gTaishoYmd;	-- 対象年月日
		v_item.l_inItem018 := 0;	-- 対象件数
		v_item.l_inItem019 := '対象データなし';	-- 対象データなし
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> gGyomuYmd,
			l_inChohyoId	=> C_CHOHYO_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		gRtnCd := C_NO_DATA;
	END IF;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, gGyomuYmd, C_CHOHYO_ID);
	-- バッチ帳票印刷データ作成
	CALL pkPrtOk.insertPrtOk(
						l_inUserId,
						l_inItakuKaishaCd,
						gGyomuYmd,
						pkPrtOk.LIST_SAKUSEI_KBN_DAY(),
						C_CHOHYO_ID
						);
	-- 正常終了
	l_outSqlCode := gRtnCd;
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, C_PROCEDURE_ID || ' END');
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID, 1, 12), 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID, 1, 12), 'SQLERRM:' || SQLERRM);
		l_outSqlCode := pkconstant.FATAL();
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipp014k00r02_02 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE, l_inUserId SREPORT_WK.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_outSqlCode OUT numeric  ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spipp014k00r02_02_gettmgnm ( l_inTmg1 MGR_KIHON.KKN_CHOKYU_TMG1%TYPE, l_inDd MGR_KIHON.KKN_CHOKYU_DD%TYPE, l_inTmg1Nm SCODE.CODE_NM%TYPE, l_inTmg2Nm SCODE.CODE_NM%TYPE ) RETURNS varchar AS $body$
DECLARE

pTmgNm varchar(24); -- タイミング名称
BEGIN
	IF l_inTmg1 = '1' OR l_inTmg1 = '2' THEN
		pTmgNm := l_inTmg1Nm || 'の' || oracle.to_multi_byte(l_inDd) || l_inTmg2Nm;
	ELSE
		pTmgNm := l_inTmg1Nm;
	END IF;
	RETURN pTmgNm;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spipp014k00r02_02_gettmgnm ( l_inTmg1 MGR_KIHON.KKN_CHOKYU_TMG1%TYPE, l_inDd MGR_KIHON.KKN_CHOKYU_DD%TYPE, l_inTmg1Nm SCODE.CODE_NM%TYPE, l_inTmg2Nm SCODE.CODE_NM%TYPE ) FROM PUBLIC;