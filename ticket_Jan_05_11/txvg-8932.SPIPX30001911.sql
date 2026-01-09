




CREATE OR REPLACE PROCEDURE spipx30001911 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE,     -- 委託会社コード
 l_inUserId SREPORT_WK.USER_ID%TYPE,    -- ユーザＩＤ
 l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, -- 帳票区分
 l_inSagyoFrom text,                   -- 作業日(FROM)
 l_inSagyoTo text,                   -- 作業日(To)
 l_inJokyoKbn TEXT,                       -- 状況区分
 l_inShoriKbn text,                   -- 処理区分(0：初期処理、1:抽出、2:印刷)
 l_outSqlCode OUT integer,                     -- リターン値
 l_outSqlErrM OUT text                    -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2016
-- * 会社名:JIP
-- *
-- * 概要　:夜間バッチや作業日管理（備忘録）照会画面から、指定した作業日を条件として、作業日管理（備忘録）リスト（帳票）を作成する。
-- *
-- * 引数　:l_inItakuKaishaCd :委託会社コード
-- *        l_inUserId        :ユーザＩＤ
-- *        l_inChohyoKbn     :帳票区分
-- *        l_inSagyoFrom     :作業日(FROM)
-- *        l_inSagyoTo       :作業日(To)
-- *        l_inJokyoKbn      :状況区分
-- *        l_inShoriKbn      :処理区分(0：初期処理、1:抽出、2:印刷)
-- *        l_outSqlCode      :リターン値
-- *        l_outSqlErrM      :エラーコメント
-- *
-- * 返り値: なし
-- *
-- * @author 張鋭(USI)
-- * @version $Id: SPIPX30001911.sql,v 1.2 2017/01/04 11:14:20 fujii Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2016.11.08 呉         新規作成
-- ***************************************************************************
--
	--==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_PROCEDURE_ID CONSTANT text := 'SPIPX30001911';           -- プロシージャＩＤ
	C_CHOHYO_ID    CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IPX30001911'; -- 帳票ＩＤ
	C_NO_DATA      CONSTANT SCODE.CODE_SHUBETSU%TYPE := 2;              -- データなしリターン
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gSeqNo            integer;                                 -- シーケンス
	gGyomuYmd         SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;       -- 業務日付
	gItakuKaishaRnm   SOWN_INFO.BANK_RNM%TYPE;                 -- 委託会社略名
		
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	-- 備忘録作業情報取得のカーソル
	curMeisai CURSOR FOR
		SELECT
			ME00.ITAKU_KAISHA_CD,         --委託会社コード
			ME00.SAGYO_YMD,               --作業日
			ME00.JOKYO_KBN,               --状況区分
			ME00.HYOJI_BUNSHO,            --作業事由
			ME00.MEMORANDOM_CD,           --作業事由コード
			ME00.MGR_CD,                  --銘柄コード
			ME00.ISIN_CD,                 --ISINコード
			ME00.MGR_RNM,                 --銘柄略称
			ME00.MEMORANDOM_BIKO           --備考
		FROM (
			-- 備忘録日次作業情報
			SELECT
				ME04.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD,  --委託会社コード
				ME04.SAGYO_YMD AS SAGYO_YMD,              --作業日
				ME04.JOKYO_KBN AS JOKYO_KBN,              --状況区分
				ME01.HYOJI_BUNSHO AS HYOJI_BUNSHO,        --作業事由
				ME01.MEMORANDOM_CD AS MEMORANDOM_CD,      --作業事由コード
				NULL AS MGR_CD,                           --銘柄コード
				NULL AS ISIN_CD,                          --ISINコード
				NULL AS MGR_RNM,                          --銘柄略称
				NULL AS MEMORANDOM_BIKO                    --備考
			FROM
				MEMORANDOM_D_SAGYO ME04,
				MMEMORANDOM ME01
			WHERE
				ME04.ITAKU_KAISHA_CD = ME01.ITAKU_KAISHA_CD
			AND ME04.MEMORANDOM_CD = ME01.MEMORANDOM_CD
			AND ME04.SAGYO_YMD BETWEEN l_inSagyoFrom AND l_inSagyoTo
			AND ME04.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND ME04.JOKYO_KBN = CASE WHEN coalesce(trim(both l_inJokyoKbn)::text, '') = '' THEN  ME04.JOKYO_KBN  ELSE trim(both l_inJokyoKbn) END
			AND ME04.SHORI_KBN = '1'   -- 承認済
 
			
UNION ALL

			-- 備忘録銘柄別作業情報
			SELECT
				ME05.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD,  --委託会社コード
				ME05.SAGYO_YMD AS SAGYO_YMD,              --作業日
				ME05.JOKYO_KBN AS JOKYO_KBN,              --状況区分
				ME01.HYOJI_BUNSHO AS HYOJI_BUNSHO,        --作業事由
				ME01.MEMORANDOM_CD AS MEMORANDOM_CD,      --作業事由コード
				MG01.MGR_CD,                              --銘柄コード
				MG01.ISIN_CD,                             --ISINコード
				MG01.MGR_RNM,                             --銘柄略称
				CASE WHEN ME01.MEMORANDOM_CD=ME03.MEMORANDOM_CD1 THEN  ME03.BIKO1 WHEN ME01.MEMORANDOM_CD=ME03.MEMORANDOM_CD2 THEN  ME03.BIKO2 WHEN ME01.MEMORANDOM_CD=ME03.MEMORANDOM_CD3 THEN  ME03.BIKO3 WHEN ME01.MEMORANDOM_CD=ME03.MEMORANDOM_CD4 THEN  ME03.BIKO4 WHEN ME01.MEMORANDOM_CD=ME03.MEMORANDOM_CD5 THEN  ME03.BIKO5  ELSE '' END  AS MEMORANDOM_BIKO                 --備考  
			FROM
				MEMORANDOM_M_SAGYO ME05,
				MMEMORANDOM ME01,
				MEMORANDOM_INFO ME03,
				MGR_KIHON MG01
			WHERE
				ME05.ITAKU_KAISHA_CD = ME01.ITAKU_KAISHA_CD
			AND ME05.MEMORANDOM_CD = ME01.MEMORANDOM_CD
			AND ME05.ITAKU_KAISHA_CD = ME03.ITAKU_KAISHA_CD
			AND ME05.MGR_CD = ME03.MGR_CD
			AND ME03.ITAKU_KAISHA_CD = MG01.ITAKU_KAISHA_CD
			AND ME03.MGR_CD = MG01.MGR_CD
			AND ME01.ITAKU_KAISHA_CD = ME03.ITAKU_KAISHA_CD
			AND (ME01.MEMORANDOM_CD = ME03.MEMORANDOM_CD1 OR
				 ME01.MEMORANDOM_CD = ME03.MEMORANDOM_CD2 OR
				 ME01.MEMORANDOM_CD = ME03.MEMORANDOM_CD3 OR
				 ME01.MEMORANDOM_CD = ME03.MEMORANDOM_CD4 OR
				 ME01.MEMORANDOM_CD = ME03.MEMORANDOM_CD5)
			AND ME05.SAGYO_YMD BETWEEN l_inSagyoFrom AND l_inSagyoTo
			AND ME05.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND ME05.JOKYO_KBN = CASE WHEN coalesce(trim(both l_inJokyoKbn)::text, '') = '' THEN  ME05.JOKYO_KBN  ELSE trim(both l_inJokyoKbn) END 
			AND ME05.SHORI_KBN = '1'  -- 承認済
 
		) ME00 
		ORDER BY 
			ME00.JOKYO_KBN ASC,
			ME00.SAGYO_YMD ASC,
			ME00.MEMORANDOM_CD ASC,
			ME00.MGR_CD ASC NULLS LAST;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, C_PROCEDURE_ID||' START');
	-- 入力パラメータチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' -- 委託会社コード
	OR coalesce(trim(both l_inUserId)::text, '') = ''        -- ユーザＩＤ
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''     -- 帳票区分
	OR coalesce(trim(both l_inSagyoFrom)::text, '') = ''     -- 作業日(FROM)
	OR coalesce(trim(both l_inSagyoTo)::text, '') = '' THEN   -- 作業日(To)
		-- ログ書込み
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID,3,12), 'パラメータエラー');
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '';
		RETURN;
	END IF;
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
	-- 委託会社略名取得
	SELECT CASE WHEN JIKO_DAIKO_KBN='1' THEN ' '  ELSE BANK_RNM END
	INTO STRICT gItakuKaishaRnm
	FROM VJIKO_ITAKU
	WHERE KAIIN_ID = l_inItakuKaishaCd;
	-- 帳票ワークテーブル削除処理
	DELETE FROM SREPORT_WK
		WHERE KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = gGyomuYmd
		AND CHOHYO_ID = C_CHOHYO_ID;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, gGyomuYmd, C_CHOHYO_ID);
	-- シーケンス初期化
	gSeqNo := 1;
	-- データ取得
    FOR recMeisai IN curMeisai
	LOOP
		-- 明細レコード追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := gGyomuYmd;	-- データ基準日
		v_item.l_inItem003 := gItakuKaishaRnm;	-- 委託会社略名
		v_item.l_inItem004 := l_inSagyoFrom;	-- 作業日(FROM)
		v_item.l_inItem005 := l_inSagyoTo;	-- 作業日(TO)
		v_item.l_inItem006 := recMeisai.JOKYO_KBN;	-- 状況区分
		v_item.l_inItem007 := gSeqNo;	-- 連番
		v_item.l_inItem008 := recMeisai.SAGYO_YMD;	-- 作業日
		v_item.l_inItem009 := recMeisai.HYOJI_BUNSHO;	-- 作業事由
		v_item.l_inItem010 := recMeisai.MEMORANDOM_CD;	-- 作業事由コード
		v_item.l_inItem011 := recMeisai.MGR_CD;	-- 銘柄コード
		v_item.l_inItem012 := recMeisai.ISIN_CD;	-- ISINコード
		v_item.l_inItem013 := recMeisai.MGR_RNM;	-- 銘柄略称
		v_item.l_inItem014 := recMeisai.MEMORANDOM_BIKO;	-- 備考
		v_item.l_inItem015 := C_CHOHYO_ID;	-- 帳票ＩＤ
		
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
	IF (gSeqNo = 1) AND (l_inShoriKbn = '2') THEN
		-- 明細レコード追加（対象データなし）
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := gGyomuYmd;	-- データ基準日
		v_item.l_inItem003 := gItakuKaishaRnm;	-- 委託会社略名
		v_item.l_inItem004 := l_inSagyoFrom;	-- 作業日(FROM)
		v_item.l_inItem005 := l_inSagyoTo;	-- 作業日(TO)
		v_item.l_inItem015 := C_CHOHYO_ID;	-- 帳票ＩＤ
		v_item.l_inItem016 := '対象データなし';	-- 対象データなし
		
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
		-- 終了処理
		l_outSqlCode := C_NO_DATA;
		l_outSqlErrM := '';
		RETURN;
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
		l_outSqlErrM := SQLERRM || SQLSTATE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipx30001911 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE, l_inUserId SREPORT_WK.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_inSagyoFrom text, l_inSagyoTo text, l_inJokyoKbn TEXT, l_inShoriKbn text, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;