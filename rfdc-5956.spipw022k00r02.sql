




CREATE OR REPLACE PROCEDURE spipw022k00r02 ( 
	l_inItakuKaishaCd text,    -- 委託会社コード
 l_inUserId text,    -- ユーザＩＤ
 l_inChohyoKbn text,    -- 帳票区分
 l_inKjnYmd text,    -- 基準日
 l_inTojituKbn text,    -- 当日区分(0：当日以外、1：当日)
 l_outSqlCode OUT integer, -- リターンコード
 l_outSqlErrM OUT text -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2008
-- * 会社名:JIP
-- *
-- * 概要　:元利金請求データ（ＣＢ）突合リスト
-- *
-- * 引数　:l_inItakuKaishaCd :委託会社コード
-- *        l_inUserId        :ユーザＩＤ
-- *        l_inChohyoKbn     :帳票区分
-- *        l_inKjnYmd        :基準日
-- *        l_outSqlCode      :リターンコード
-- *        l_outSqlErrM      :エラーコメント
-- *
-- * 返り値: なし
-- *
-- * @author ASK
-- * @version $Id: SPIPW022K00R02.sql,v 1.3 2015/03/18 01:20:02 takahashi Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2007.12.19 ASK        新規作成
-- ***************************************************************************
--	/*==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_PROGRAM_ID    CONSTANT varchar(12)              := 'IPW022K00R02'; -- プログラムＩＤ
	C_CHOHYO_ID1    CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IPW30002211';  -- 帳票ＩＤ（元利金請求データ（ＣＢ）突合リスト）
	C_CHOHYO_ID2    CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IPW30002221';  -- 帳票ＩＤ（元利金請求データ（ＣＢ）（当日）突合リスト）
	C_RCD_NOT_FOUND CONSTANT integer                   := 2;              -- 返値「2:対象データなし」
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	gGyomuYmd SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE; -- 業務日付
	gBankRnm  VJIKO_ITAKU.BANK_RNM%TYPE;         -- 銀行略称
	gSeqNo    integer;                           -- 連番
	gReportId			char(11) := ' ';							-- 帳票ID
	gWarning1			varchar(2) := NULL;						-- 帳票コメント(ITEM023)
	gWarning2			varchar(2) := NULL;						-- 帳票コメント(ITEM024)
	v_item            TYPE_SREPORT_WK_ITEM;              -- SREPORT_WK item for pkPrint.insertData
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	curMeisai CURSOR FOR
		SELECT
			WK07.ISIN_CD,                                                                                 -- ＩＳＩＮコード
			CASE WHEN WK07.TOTSUGO_KEKKA_KBN='3' THEN  NULL  ELSE WK07.SYS_GNR_ZNDK END  AS SYS_GNR_ZNDK,                 -- システム_元利払対象残高
			CASE WHEN WK07.TOTSUGO_KEKKA_KBN='3' THEN  NULL  ELSE WK07.SYS_ZEIHIKI_BEF_KNGK END  AS SYS_ZEIHIKI_BEF_KNGK, -- システム_利金金額（税引前）
			CASE WHEN WK07.TOTSUGO_KEKKA_KBN='3' THEN  NULL  ELSE WK07.SYS_SHOKAN_KNGK END  AS SYS_SHOKAN_KNGK,           -- システム_償還金額
			WK07.KK_MGR_CD,                                                                               -- 機構銘柄コード
			WK07.MGR_CD,                                                                                  -- 銘柄コード
			WK07.KK_SAKUSEI_YMD,                                                                          -- 機構_作成日
			WK07.KK_GNRBARAI_YMD,                                                                         -- 機構_元利払日
			CASE WHEN WK07.TOTSUGO_KEKKA_KBN='0' THEN  NULL  ELSE WK07.KK_GNR_ZNDK END  AS KK_GNR_ZNDK,                   -- 機構_元利払対象残高
			CASE WHEN WK07.TOTSUGO_KEKKA_KBN='0' THEN  NULL  ELSE WK07.KK_ZEIHIKI_BEF_KNGK END  AS KK_ZEIHIKI_BEF_KNGK,   -- 機構_利金金額（税引前）
			CASE WHEN WK07.TOTSUGO_KEKKA_KBN='0' THEN  NULL  ELSE WK07.KK_SHOKAN_KNGK END  AS KK_SHOKAN_KNGK,             -- 機構_償還金額
			CASE WHEN WK07.TOTSUGO_KEKKA_KBN='0' THEN  NULL WHEN WK07.TOTSUGO_KEKKA_KBN='3' THEN  NULL  ELSE WK07.RKN_SGK END  AS RKN_SGK,                -- 利金差額
			VMG1.MGR_RNM,                                                                                 -- 銘柄略称
			CASE WHEN WK07.RKN_SGK=0 THEN  '0'  ELSE '1' END  AS RKN_SGK_UMUFLG,                                          -- 利金差額有無フラグ
			CASE WHEN WK07.RKN_SGK=0 THEN  ' '  ELSE '差額有' END  AS RKN_SGK_UMUFLG_NM,                                  -- 利金差額有無フラグ名称
			WK07.ZEI_KBN_TOTSUGO_KEKKA_KBN,																  -- 税区分突合結果区分
			(
				SELECT
					CODE_NM
				FROM
					SCODE
				WHERE
					CODE_SHUBETSU = '141'
					AND CODE_VALUE = WK07.TOTSUGO_KEKKA_KBN
			) AS TOTSUGO_KEKKA_NM,                                                                        -- 突合結果区分名称
			(
				SELECT
					CODE_RNM
				FROM
					SCODE
				WHERE
					CODE_SHUBETSU = '511'
					AND CODE_VALUE = WK07.SYS_KOBETSU_FLG
			) AS SYS_KOBETSU_RNM,                                                                         -- システム_個別承認採用フラグ内容（略称）
			(
				SELECT
					CODE_RNM
				FROM
					SCODE
				WHERE
					CODE_SHUBETSU = '511'
					AND CODE_VALUE = WK07.KK_KOBETSU_FLG
			) AS KK_KOBETSU_RNM                                                                            -- 機構_個別承認採用フラグ内容（略称）
		FROM
			CB_GANRI_SEIKYU WK07,
			MGR_KIHON_VIEW VMG1
		WHERE
			WK07.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
			AND WK07.MGR_CD = VMG1.MGR_CD
			AND WK07.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND (( l_inTojituKbn = '1' AND
				WK07.SYS_GNRBARAI_YMD = l_inKjnYmd)
			OR (l_inTojituKbn = '0' AND 
				WK07.SYS_GNRBARAI_YMD != l_inKjnYmd)) 
		ORDER BY
			WK07.TOTSUGO_KEKKA_KBN DESC,
			CASE WHEN WK07.RKN_SGK=0 THEN  '0'  ELSE '1' END  DESC,
			WK07.KK_MGR_CD;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 引数(委託会社)チェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' THEN
		-- パラメータエラーとして出力
		CALL pkLog.error('ECM501', C_PROGRAM_ID, '委託会社コード');
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '委託会社・パラメータエラー';
		RETURN;
	END IF;
	-- 引数(ユーザＩＤ)チェック
	IF coalesce(trim(both l_inUserId)::text, '') = '' THEN
		-- パラメータエラーとして出力
		CALL pkLog.error('ECM501', C_PROGRAM_ID, 'ユーザＩＤ');
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := 'ユーザＩＤ・パラメータエラー';
		RETURN;
	END IF;
	-- 引数(帳票区分)チェック
	IF coalesce(trim(both l_inChohyoKbn)::text, '') = '' THEN
		-- パラメータエラーとして出力
		CALL pkLog.error('ECM501', C_PROGRAM_ID, '帳票区分');
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '帳票区分・パラメータエラー';
		RETURN;
	END IF;
	-- 引数(基準日)チェック
	IF coalesce(trim(both l_inKjnYmd)::text, '') = '' THEN
		-- パラメータエラーとして出力
		CALL pkLog.error('ECM501', C_PROGRAM_ID, '基準日');
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '基準日・パラメータエラー';
		RETURN;
	END IF;
	-- 引数(当日区分)チェック
	IF coalesce(trim(both l_inTojituKbn)::text, '') = '' THEN
		-- パラメータエラーとして出力
		CALL pkLog.error('ECM501', C_PROGRAM_ID, '当日区分');
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '当日区分・パラメータエラー';
		RETURN;
	END IF;
	-- 業務日付を取得
	gGyomuYmd := pkDate.getGyomuYmd();
	-- 委託会社略称取得
	SELECT
		CASE WHEN JIKO_DAIKO_KBN='2' THEN  BANK_RNM  ELSE ' ' END
	INTO STRICT
		gBankRnm
	FROM
		VJIKO_ITAKU
	WHERE
		KAIIN_ID = l_inItakuKaishaCd;
	-- 今回出力する帳票IDを引数の帳票IDより再設定を行う
	IF l_inTojituKbn = '0' THEN
		gReportId := C_CHOHYO_ID1;
	ELSE
		gReportId := C_CHOHYO_ID2;
	END IF;
	-- 帳票ワーク削除
	DELETE FROM SREPORT_WK
	WHERE
		KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = gGyomuYmd
		AND CHOHYO_ID = gReportId;
	-- 連番初期化
	gSeqNo := 1;
	-- 元利金請求予定データ（ＣＢ）取得（EOFまでループ処理）
	FOR recMeisai IN curMeisai LOOP
	-- 税区分突合結果区分によって帳票に以下をセットする
        IF recMeisai.ZEI_KBN_TOTSUGO_KEKKA_KBN = '1' THEN
           	gWarning1 := '*1';
           	gWarning2 := NULL;
        ELSIF recMeisai.ZEI_KBN_TOTSUGO_KEKKA_KBN = '2' THEN
        	gWarning1 := NULL;
        	gWarning2 := '*2';
        ELSIF recMeisai.ZEI_KBN_TOTSUGO_KEKKA_KBN = '3' THEN
        	gWarning1 := '*1';
        	gWarning2 := '*2';
        ELSE
        	gWarning1 := NULL;
        	gWarning2 := NULL;
        END IF;
		-- 帳票ワーク登録
		-- Clear toàn bộ item
		v_item := ROW();
		
		v_item.l_inItem001 := gBankRnm;
		v_item.l_inItem002 := recMeisai.KK_SAKUSEI_YMD;
		v_item.l_inItem003 := recMeisai.KK_GNRBARAI_YMD;
		v_item.l_inItem004 := recMeisai.TOTSUGO_KEKKA_NM;
		v_item.l_inItem005 := recMeisai.RKN_SGK_UMUFLG;
		v_item.l_inItem006 := recMeisai.RKN_SGK_UMUFLG_NM;
		v_item.l_inItem007 := recMeisai.KK_MGR_CD;
		v_item.l_inItem008 := recMeisai.ISIN_CD;
		v_item.l_inItem009 := recMeisai.MGR_CD;
		v_item.l_inItem010 := recMeisai.MGR_RNM;
		v_item.l_inItem011 := recMeisai.SYS_KOBETSU_RNM;
		v_item.l_inItem012 := recMeisai.SYS_GNR_ZNDK;
		v_item.l_inItem013 := recMeisai.SYS_ZEIHIKI_BEF_KNGK;
		v_item.l_inItem014 := recMeisai.SYS_SHOKAN_KNGK;
		v_item.l_inItem015 := recMeisai.KK_KOBETSU_RNM;
		v_item.l_inItem016 := recMeisai.KK_GNR_ZNDK;
		v_item.l_inItem017 := recMeisai.KK_ZEIHIKI_BEF_KNGK;
		v_item.l_inItem018 := recMeisai.KK_SHOKAN_KNGK;
		v_item.l_inItem019 := recMeisai.RKN_SGK;
		v_item.l_inItem020 := gReportId;
		v_item.l_inItem021 := l_inUserId;
		v_item.l_inItem022 := l_inKjnYmd;
		v_item.l_inItem023 := gWarning1;
		v_item.l_inItem024 := gWarning2;
		
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd,
			l_inUserId     => l_inUserId,
			l_inChohyoKbn  => l_inChohyoKbn,
			l_inSakuseiYmd => gGyomuYmd,
			l_inChohyoId   => gReportId,
			l_inSeqNo      => gSeqNo,
			l_inHeaderFlg  => 1,
			l_inItem       => v_item,
			l_inKousinId   => l_inUserId,
			l_inSakuseiId  => l_inUserId
		);
		-- 連番インクリメント
		gSeqNo := gSeqNo + 1;
	END LOOP;
	-- 対象データが存在しなかった場合
	IF gSeqNo = 1 THEN
		l_outSqlCode := C_RCD_NOT_FOUND;
		l_outSqlErrM := '対象データなし';
		RETURN;
	END IF;
	-- ヘッダレコード作成
	CALL pkPrint.insertHeader(
		l_inItakuKaishaCd, -- 委託会社コード
		l_inUserId,        -- ユーザＩＤ
		l_inChohyoKbn,     -- 帳票区分
		gGyomuYmd,         -- 業務日付
		gReportId           -- 帳票ＩＤ
	);
	-- バッチ帳票印刷管理登録
	CALL pkPrtOk.insertPrtOk(
		l_inUserId,        -- ユーザＩＤ
		l_inItakuKaishaCd, -- 委託会社コード
		gGyomuYmd,         -- 業務日付
		'3',               -- 帳票作成区分「3：随時」
		gReportId           -- 帳票ＩＤ
	);
	-- 正常終了
	l_outSqlCode := pkconstant.success();
	l_outSqlErrM := '';
	RETURN;
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'SQLERRM:' || SQLERRM);
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLSTATE || SQLERRM;
		RETURN;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipw022k00r02 ( l_inItakuKaishaCd CHAR, l_inUserId CHAR, l_inChohyoKbn CHAR, l_inKjnYmd CHAR, l_inTojituKbn CHAR, l_outSqlCode OUT integer, l_outSqlErrM OUT text ) FROM PUBLIC;