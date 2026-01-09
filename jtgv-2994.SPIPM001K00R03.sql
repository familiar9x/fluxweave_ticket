




CREATE OR REPLACE PROCEDURE spipm001k00r03 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE,     -- 委託会社コード
 l_inUserId SREPORT_WK.USER_ID%TYPE,    -- ユーザーID
 l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, -- 帳票区分
 l_inMemorandomCd text,                   -- 備忘録コード
 l_outSqlCode OUT integer,                     -- リターン値
 l_outSqlErrM OUT text                    -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2006
-- * 会社名:JIP
-- *
-- * 概要　:備忘録マスタ画面より、銘柄非連動型の備忘録コードの時、備忘録設定情報一覧表（銘柄非連動分）を作成する
-- *
-- * 引数　:l_inItakuKaishaCd  :委託会社コード
-- *        l_inUserId         :ユーザーID
-- *        l_inChohyoKbn      :帳票区分
-- *        l_inMemorandomCd   :備忘録コード
-- *        l_outSqlCode       :リターン値
-- *        l_outSqlErrM       :エラーコメント
-- *
-- * 返り値: なし
-- *
-- * @author ASK
-- * @version $Id: SPIPM001K00R03.sql,v 1.1 2006/07/18 11:52:03 itou Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2006.06.28 ASK         新規作成
-- ***************************************************************************
--
	--==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_PROCEDURE_ID CONSTANT text := 'SPIPM001K00R03';            -- プロシージャＩＤ
	C_CHOHYO_ID    CONSTANT SREPORT_WK.CHOHYO_ID%TYPE  := 'IPM30000121'; -- 帳票ＩＤ
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gSeqNo            integer;                                    -- シーケンス
	gItakuKaishaRnm   SOWN_INFO.BANK_RNM%TYPE;                    -- 委託会社略称
	gGyomuYmd         SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;          -- 業務日付
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	curMeisai CURSOR FOR
		SELECT
			ME04.MEMORANDOM_CD,                           -- 備忘録コード
			ME04.SAGYO_YMD,                               -- 作業日
			ME01.HYOJI_BUNSHO                              -- 表示文章
		FROM
			MEMORANDOM_D_SAGYO ME04,
			MMEMORANDOM ME01,
			MEMORANDOM_TYPE ME02
		WHERE
			ME04.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND ME04.MEMORANDOM_CD = l_inMemorandomCd
			AND ME04.ITAKU_KAISHA_CD = ME01.ITAKU_KAISHA_CD
			AND ME04.MEMORANDOM_CD = ME01.MEMORANDOM_CD
			AND ME01.MEMORANDOM_TYPE_CD = ME02.MEMORANDOM_TYPE_CD
			AND ME02.MGR_RENDO_FLG = '0'
		ORDER BY
			--作業日
			ME04.SAGYO_YMD;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, C_PROCEDURE_ID||' START');
	-- 入力パラメータチェック
	IF coalesce(l_inItakuKaishaCd::text, '') = '' -- 委託会社コード
	OR coalesce(l_inUserId::text, '') = ''        -- ユーザーID
	OR coalesce(l_inChohyoKbn::text, '') = ''     -- 帳票区分
	OR coalesce(l_inMemorandomCd::text, '') = ''  -- 備忘録コード
	THEN
		-- ログ書込み
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID,3,12), 'パラメータエラー');
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := '';
		RETURN;
	END IF;
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '引数');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '委託会社コード:"' || l_inItakuKaishaCd ||'"');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'ユーザーＩＤ:"' || l_inUserId ||'"');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票区分:"' || l_inChohyoKbn ||'"');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '備忘録コード:"' || l_inMemorandomCd ||'"');
	-- 委託会社略名取得
	SELECT CASE WHEN JIKO_DAIKO_KBN='1' THEN ' '  ELSE BANK_RNM END  INTO STRICT gItakuKaishaRnm
	FROM VJIKO_ITAKU
	WHERE KAIIN_ID = l_inItakuKaishaCd;
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
	-- シーケンス初期化
	gSeqNo := 1;
	-- 帳票ワーク削除
	DELETE FROM SREPORT_WK
		WHERE KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = gGyomuYmd
		AND CHOHYO_ID = C_CHOHYO_ID;
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '削除条件');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '識別コード:"' || l_inItakuKaishaCd ||'"');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'ユーザーＩＤ:"' || l_inUserId ||'"');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票区分:"' || l_inChohyoKbn ||'"');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '作成日付:"' || gGyomuYmd ||'"');
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票ＩＤ:"' || C_CHOHYO_ID ||'"');
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, gGyomuYmd, C_CHOHYO_ID);
	-- データ取得
	FOR recMeisai IN curMeisai
	LOOP
		-- 明細レコード追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem002 := recMeisai.MEMORANDOM_CD;	-- 備忘録コード
		v_item.l_inItem003 := gSeqNo;	-- Ｎｏ（４桁）連番
		v_item.l_inItem004 := recMeisai.SAGYO_YMD;	-- 作業日
		v_item.l_inItem005 := recMeisai.HYOJI_BUNSHO;	-- 表示文章
		v_item.l_inItem006 := C_CHOHYO_ID;	-- 帳票ＩＤ
		v_item.l_inItem007 := l_inUserId;	-- ユーザーＩＤ
		
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
		-- シーケンスのカウント
		gSeqNo := gSeqNo + 1;
	END LOOP;
	-- 終了処理
	IF gSeqNo = 1 THEN
		-- 明細レコード追加（対象データ無し）
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem006 := C_CHOHYO_ID;	-- 帳票ＩＤ
		v_item.l_inItem007 := l_inUserId;	-- ユーザーＩＤ
		v_item.l_inItem008 := '対象データ無し';	-- 対象データ無し
		
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
	END IF;
	-- 終了処理
	l_outSqlCode := pkconstant.success();
	l_outSqlErrM := '';
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, C_PROCEDURE_ID ||' END');
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID,3,12), 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID,3,12), 'SQLERRM:' || SQLERRM);
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLSTATE || SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipm001k00r03 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE, l_inUserId SREPORT_WK.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_inMemorandomCd text, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;