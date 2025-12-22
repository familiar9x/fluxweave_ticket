




CREATE OR REPLACE FUNCTION sfipx016k00r02_01 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE,     -- 委託会社コード
 l_inUserId SREPORT_WK.USER_ID%TYPE,    -- ユーザーＩＤ
 l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, -- 帳票区分
 l_inGyomuYmd SREPORT_WK.SAKUSEI_YMD%TYPE  -- 業務日付
 ) RETURNS integer AS $body$
DECLARE

ora2pg_rowcount int;
--
-- * 著作権: Copyright (c) 2008
-- * 会社名: JIP
-- *
-- * 概要　:業務データガベージ（子ＳＰ）
-- *
-- * 引数　:l_inItakuKaishaCd :委託会社コード
-- *        l_inUserId        :ユーザーＩＤ
-- *        l_inChohyoKbn     :帳票区分
-- *        l_inGyomuYmd      :業務日付
-- *
-- * 返り値: 0:正常
-- *        99:異常
-- *
-- * @author ASK
-- * @version $Id: SFIPX016K00R02_01.sql,v 1.1 2008/11/07 10:41:42 nishimura Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2008.09.05 ASK 新規作成
-- ***************************************************************************
-- 
	--==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_PROGRAM_ID CONSTANT text                 := 'SFIPX016K00R02_01'; -- プログラムＩＤ
	C_OPTION_CD  CONSTANT MOPTION_KANRI.OPTION_CD%TYPE := 'SFIPX016K00R011';   -- オプションコード（業務データガベージオプションフラグ）
	C_REPORT_ID  CONSTANT SREPORT_WK.CHOHYO_ID%TYPE    := 'IPX30001621';       -- 帳票ＩＤ（レコード削除件数リスト）
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gMessage        varchar(500);               -- メッセージ
	gYears          MPROCESS_CTL.CTL_VALUE%TYPE; -- 対象年数（プロセスコントロール）
	gKijunShokanYmd MGR_KIHON.HAKKO_YMD%TYPE;    -- 削除対象償還期日
	gItakuKaishaRnm SOWN_INFO.BANK_RNM%TYPE;     -- 委託会社略名
	gCnt            integer;                     -- 件数
	gSeqNo          integer;                     -- シーケンス番号
	gDelSqlCmd      varchar(200);               -- 削除ＳＱＬコマンド
	gColumnNm       varchar(14);                -- カラム名称
	--==============================================================================
	--                  エラー定義                                                  
	--==============================================================================
	
	
	
	
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	-- 業務テーブルガベージ管理カーソル
	curGbgKanri CURSOR FOR
		SELECT
			TABLE_NAME,  -- テーブル名称
			MGR_ISIN_KBN  -- 銘柄・ＩＳＩＮコード区分
		FROM
			GTBL_GBG_KANRI
		WHERE
			DELETE_FLG = '1'
		ORDER BY
			TABLE_NAME;
	-- ガベージデータ帳票ファイルカーソル
	curGbgReport CURSOR FOR
		SELECT
			MGR_CD, -- 銘柄コード
			ISIN_CD  -- ＩＳＩＮコード
		FROM
			GTBL_GBG_REPORT
		WHERE
			ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND GBG_JISSHI_YMD = l_inGyomuYmd;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
--	pkLog.debug(pkconstant.BATCH_USER(), C_PROGRAM_ID, C_PROGRAM_ID || ' START');
	-- メッセージ編集
	gMessage := 'ユーザＩＤ：' || l_inUserId || ', 委託会社コード：' || l_inItakuKaishaCd;
	-- 業務データガベージオプションフラグが「0：未導入」の時
	IF pkControl.getOPTION_FLG(l_inItakuKaishaCd, C_OPTION_CD, '0') = '0' THEN
		-- 情報ログ出力
		CALL pkLog.info('IIP484', C_PROGRAM_ID, gMessage);
		-- 正常終了
		RETURN pkconstant.success();
	END IF;
	-- 削除銘柄対象件数取得
	SELECT
		COUNT(*)
	INTO STRICT
		gCnt
	FROM
		GTBL_GBG_REPORT
	WHERE
		ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND GBG_JISSHI_YMD = l_inGyomuYmd;
	-- 削除銘柄対象件数が０件の時
	IF gCnt = 0 THEN
		-- ワーニングログ出力
		CALL pkLog.warn('WIP055', C_PROGRAM_ID, gMessage);
		-- 正常終了
		RETURN pkconstant.success();
	END IF;
	-- 情報ログ出力
	CALL pkLog.info('IIP485', C_PROGRAM_ID, gMessage);
	-- ガベージ対象年数取得
	gYears := pkControl.getCtlValue(l_inItakuKaishaCd, C_OPTION_CD, '0');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, 'ガベージ対象年数：' || gYears || '年');
	-- ガベージ対象年数が「0：未導入」の時
	IF gYears = '0' THEN
		-- エラーログ出力
		CALL pkLog.error('EIP4A4', C_PROGRAM_ID, gMessage);
		-- 正常終了
		RETURN pkconstant.success();
	END IF;
	-- 削除対象償還期日取得
	gKijunShokanYmd := (SUBSTR(l_inGyomuYmd, 1, 4))::numeric  - ((gYears)::numeric  + 1) || '1231';
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '削除対象償還期日：' || gKijunShokanYmd);
	-- 情報ログ出力
	CALL pkLog.info('IIP486', C_PROGRAM_ID, gMessage);
	-- 委託会社略名取得
	SELECT
		CASE WHEN JIKO_DAIKO_KBN='2' THEN  BANK_RNM  ELSE ' ' END
	INTO STRICT
		gItakuKaishaRnm
	FROM 
		VJIKO_ITAKU
	WHERE 
		KAIIN_ID = l_inItakuKaishaCd;
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE
		KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = l_inGyomuYmd
		AND CHOHYO_ID = C_REPORT_ID;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(
		l_inItakuKaishaCd, -- 委託会社コード
		l_inUserId,        -- ユーザーＩＤ
		l_inChohyoKbn,     -- 帳票区分
		l_inGyomuYmd,      -- 作成年月日
		C_REPORT_ID         -- 帳票ＩＤ
	);
	-- 変数初期化
	gSeqNo := 1;
	-- ガベージ対象テーブル件数取得
	SELECT
		COUNT(*)
	INTO STRICT
		gCnt
	FROM
		GTBL_GBG_KANRI
	WHERE
		DELETE_FLG = '1';
	-- ガベージ対象テーブル件数が０件の時
	IF gCnt = 0 THEN
		-- エラーログ出力
		CALL pkLog.error('EIP4A5', C_PROGRAM_ID, gMessage);
		-- 「対象データなし」レコード追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := l_inGyomuYmd;	-- データ基準日
		v_item.l_inItem003 := gItakuKaishaRnm;	-- 委託会社略名
		v_item.l_inItem004 := gKijunShokanYmd;	-- 削除対象償還期日
		v_item.l_inItem008 := C_REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem009 := '対象データなし';	-- 対象データなし
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> C_REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> 1,
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	-- ガベージ対象テーブル件数が０件でない時
	ELSE
		-- 情報ログ出力
		CALL pkLog.INFO('IIP488', C_PROGRAM_ID, gMessage);
		-- 業務テーブルガベージ管理・データ取得
		FOR recGbgKanri IN curGbgKanri LOOP
			-- 件数初期化
			gCnt := 0;
			-- ガベージデータ帳票ファイルカーソル
			FOR recGbgReport IN curGbgReport LOOP
				-- 削除ＳＱＬコマンド編集
				gDelSqlCmd := 'DELETE FROM ' || recGbgKanri.TABLE_NAME;
				gDelSqlCmd := gDelSqlCmd || ' WHERE ITAKU_KAISHA_CD = ' || '''' || l_inItakuKaishaCd || '''';
				-- 銘柄コード条件の時
				IF recGbgKanri.MGR_ISIN_KBN = '1' THEN
					-- 条件追加
					gDelSqlCmd := gDelSqlCmd || ' AND MGR_CD = ' || '''' || recGbgReport.MGR_CD || '''';
					-- カラム名称設定
					gColumnNm := '銘柄コード';
				-- ＩＳＩＮコード条件の時
				ELSIF recGbgKanri.MGR_ISIN_KBN = '2' THEN
					-- 条件追加
					gDelSqlCmd := gDelSqlCmd || ' AND ISIN_CD = ' || '''' || recGbgReport.ISIN_CD || '''';
					-- カラム名称設定
					gColumnNm := 'ＩＳＩＮコード';
				-- 条件が設定されていない時
				ELSE
					-- 致命的エラーログ出力
					CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'テーブル名：' || recGbgKanri.TABLE_NAME || 'に削除キーが設定されていないため、削除処理は行いません');
					-- 異常終了
					RETURN pkconstant.fatal();
				END IF;
				BEGIN
					-- 削除実行
					EXECUTE gDelSqlCmd;
					GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;

					-- 削除件数カウントアップ
					gCnt := gCnt +  ora2pg_rowcount;
				EXCEPTION
					-- テーブルエラー
					WHEN SQLSTATE '50001' THEN
						CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'テーブル名：' || recGbgKanri.TABLE_NAME || 'は存在しない為、削除処理を行いません');
						-- 異常終了
						RETURN pkconstant.fatal();
					-- カラムエラー
					WHEN SQLSTATE '50002' THEN
						CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'テーブル名：' || recGbgKanri.TABLE_NAME || 'には、列名：' || gColumnNm || 'は、存在しない為、削除処理を行いません');
						-- 異常終了
						RETURN pkconstant.fatal();
					WHEN OTHERS THEN
						-- 何もしない（スキップ）
						NULL;
				END;
			END LOOP;
			-- 明細レコード追加
					-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := l_inGyomuYmd;	-- データ基準日
		v_item.l_inItem003 := gItakuKaishaRnm;	-- 委託会社略名
		v_item.l_inItem004 := gKijunShokanYmd;	-- 削除対象償還期日
		v_item.l_inItem005 := pkcharacter.numeric_to_char(gSeqNo);	-- 帳票出力番号
		v_item.l_inItem006 := recGbgKanri.TABLE_NAME;	-- テーブル名
		v_item.l_inItem007 := pkcharacter.numeric_to_char(gCnt);	-- 件数
		v_item.l_inItem008 := C_REPORT_ID;	-- 帳票ＩＤ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> C_REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
			-- シーケンス番号のカウント
			gSeqNo := gSeqNo + 1;
		END LOOP;
	END IF;
	-- バッチ帳票印刷データ作成
	CALL pkPrtOk.insertPrtOk(
		l_inUserId,                   -- ユーザＩＤ
		l_inItakuKaishaCd,            -- 委託会社コード
		l_inGyomuYmd,                 -- 業務日付
		pkPrtOk.LIST_SAKUSEI_KBN_DAY(), -- 帳票作成区分
		C_REPORT_ID                    -- 帳票ＩＤ
	);
	-- 正常終了
	RETURN pkconstant.success();
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'SQLERRM:' || SQLERRM);
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipx016k00r02_01 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE, l_inUserId SREPORT_WK.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_inGyomuYmd SREPORT_WK.SAKUSEI_YMD%TYPE  ) FROM PUBLIC;