




CREATE OR REPLACE PROCEDURE spipw020k00r02 ( 
    l_inItakuKaishaCd TEXT,    -- 委託会社コード
 l_inUserId TEXT,    -- ユーザＩＤ
 l_inChohyoKbn TEXT,    -- 帳票区分
 l_inKjnYmd TEXT,    -- 基準日
 l_outSqlCode OUT integer, -- リターンコード
 l_outSqlErrM OUT text -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2008
-- * 会社名:JIP
-- *
-- * 概要　:元利払日程（ＣＢ）突合リスト
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
-- * @version $Id: SPIPW020K00R02.sql,v 1.1 2008/03/13 12:26:38 takeshi_narita Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2007.12.18 ASK        新規作成
-- ***************************************************************************
--	/*==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_PROGRAM_ID    CONSTANT varchar(12)              := 'IPW020K00R02'; -- プログラムＩＤ
	C_CHOHYO_ID     CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IPW30002011';  -- 帳票ＩＤ
	C_RCD_NOT_FOUND CONSTANT integer                   := 2;              -- 返値「2:対象データなし」
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	gGyomuYmd SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE; -- 業務日付
	gBankRnm  VJIKO_ITAKU.BANK_RNM%TYPE;         -- 銀行略称
	gSeqNo    integer;                           -- 連番
	v_item    TYPE_SREPORT_WK_ITEM;              -- SREPORT_WK item for pkPrint.insertData
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	curMeisai CURSOR FOR
		SELECT
			WK05.ISIN_CD,                                                                         -- ＩＳＩＮコード
			oracle.to_multi_byte(WK05.NBEF_EIGYOBI_TSUCHI::TEXT) AS NBEF_EIGYOBI_TSUCHI,         -- Ｎ営業日前通知
			WK05.SYS_GNRBARAI_YMD,                                                                -- システム_元利払日
			CASE WHEN WK05.TOTSUGO_KEKKA_KBN='3' THEN  NULL  ELSE WK05.SYS_SHASAI_ZNDK END  AS SYS_SHASAI_ZNDK,   -- システム_社債残高
			WK05.KK_MGR_CD,                                                                       -- 機構銘柄コード
			WK05.MGR_CD,                                                                          -- 銘柄コード
			WK05.KK_SAKUSEI_YMD,                                                                  -- 機構_作成日
			WK05.KK_FURIKAE_TEISHI_YMD,                                                           -- 機構_振替停止日
			WK05.KK_GNRBARAI_YMD,                                                                 -- 機構_元利払日
			WK05.KK_ZNDK_TSUCHI_F_YMD,                                                            -- 機構_残高通知配信期間(FROM)
			WK05.KK_ZNDK_TSUCHI_T_YMD,                                                            -- 機構_残高通知配信期間(TO)
			CASE WHEN WK05.TOTSUGO_KEKKA_KBN='0' THEN  NULL  ELSE WK05.KK_SHASAI_ZNDK END  AS KK_SHASAI_ZNDK,     -- 機構_社債残高
			VMG1.MGR_RNM,                                                                         -- 銘柄略称
			(
				SELECT
					CODE_NM
				FROM
					SCODE
				WHERE
					CODE_SHUBETSU = '141'
					AND CODE_VALUE = WK05.TOTSUGO_KEKKA_KBN
			) AS TOTSUGO_KEKKA_KBN_NM                                                              -- 突合結果区分
		FROM
			CB_GANRI_NITTEI WK05,
			MGR_KIHON_VIEW VMG1
		WHERE
			WK05.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
			AND WK05.MGR_CD = VMG1.MGR_CD
			AND WK05.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		ORDER BY
			WK05.NBEF_EIGYOBI_TSUCHI DESC,
			WK05.TOTSUGO_KEKKA_KBN DESC,
			WK05.KK_MGR_CD;
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
	-- 帳票ワーク削除
	DELETE FROM SREPORT_WK
	WHERE
		KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = gGyomuYmd
		AND CHOHYO_ID = C_CHOHYO_ID;
	-- 連番初期化
	gSeqNo := 1;
	-- 元利払日程予定データ（ＣＢ）取得（EOFまでループ処理）
	FOR recMeisai IN curMeisai LOOP
		-- 帳票ワーク登録
		-- Clear toàn bộ item
		v_item := ROW();
		
		v_item.l_inItem001 := gBankRnm;
		v_item.l_inItem002 := recMeisai.KK_SAKUSEI_YMD;
		v_item.l_inItem003 := recMeisai.NBEF_EIGYOBI_TSUCHI;
		v_item.l_inItem004 := recMeisai.KK_FURIKAE_TEISHI_YMD;
		v_item.l_inItem005 := recMeisai.KK_ZNDK_TSUCHI_F_YMD;
		v_item.l_inItem006 := recMeisai.KK_ZNDK_TSUCHI_T_YMD;
		v_item.l_inItem007 := recMeisai.TOTSUGO_KEKKA_KBN_NM;
		v_item.l_inItem008 := recMeisai.KK_MGR_CD;
		v_item.l_inItem009 := recMeisai.ISIN_CD;
		v_item.l_inItem010 := recMeisai.MGR_CD;
		v_item.l_inItem011 := recMeisai.MGR_RNM;
		v_item.l_inItem012 := recMeisai.SYS_GNRBARAI_YMD;
		v_item.l_inItem013 := recMeisai.SYS_SHASAI_ZNDK;
		v_item.l_inItem014 := recMeisai.KK_GNRBARAI_YMD;
		v_item.l_inItem015 := recMeisai.KK_SHASAI_ZNDK;
		v_item.l_inItem016 := C_CHOHYO_ID;
		v_item.l_inItem017 := l_inUserId;
		v_item.l_inItem018 := l_inKjnYmd;
		
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd,
			l_inUserId     => l_inUserId,
			l_inChohyoKbn  => l_inChohyoKbn,
			l_inSakuseiYmd => gGyomuYmd,
			l_inChohyoId   => C_CHOHYO_ID,
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
		C_CHOHYO_ID         -- 帳票ＩＤ
	);
	-- バッチ帳票印刷管理登録
	CALL pkPrtOk.insertPrtOk(
		l_inUserId,        -- ユーザＩＤ
		l_inItakuKaishaCd, -- 委託会社コード
		gGyomuYmd,         -- 業務日付
		'3',               -- 帳票作成区分「3：随時」
		C_CHOHYO_ID         -- 帳票ＩＤ
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
-- REVOKE ALL ON PROCEDURE spipw020k00r02 ( l_inItakuKaishaCd CHAR, l_inUserId CHAR, l_inChohyoKbn CHAR, l_inKjnYmd CHAR, l_outSqlCode OUT integer, l_outSqlErrM OUT text ) FROM PUBLIC;