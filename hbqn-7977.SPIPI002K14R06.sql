




CREATE OR REPLACE PROCEDURE spipi002k14r06 ( l_inItakuKaishaCd text,        -- 委託会社コード
 l_inUserId text,        -- ユーザID
 l_inChohyoKbn text,        -- 帳票区分
 l_inGyomuYmd text,        -- 業務日付
 l_outSqlCode OUT integer,          -- リターン値
 l_outSqlErrM OUT text         -- エラーコメント
 ) AS $body$
DECLARE

--
-- * 著作権:Copyright(c)2013
-- * 会社名:JIP
-- *
-- * 概要　:現物債未払管理入力取込の画面より、「支払報告データ」を選択時に作成される。
-- *
-- * 引数　:l_inItakuKaishaCd  IN  VARCHAR         -- 委託会社コード
-- *        l_inUserId         IN  VARCHAR         -- ユーザID
-- *        l_inChohyoKbn      IN  VARCHAR         -- 帳票区分
-- *        l_inGyomuYmd       IN  VARCHAR         -- 業務日付
-- *        l_outSqlCode       OUT NUMERIC           -- リターン値
-- *        l_outSqlErrM       OUT VARCHAR         -- エラーコメント
-- *
-- * 返り値: なし
-- *
-- * @author Xu Chunxu
-- * @version $Id: SPIPI002K14R06.sql,v 1.2 2013/06/19 05:54:01 ito Exp $
--
	--==============================================================================
	--                  デバッグ゛機能                                               
	--==============================================================================
	DEBUG	numeric(1)	:= 0;
	--==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	REPORT_ID        CONSTANT text        := 'IP931400251';    -- 帳票ＩＤ
	PROGRAM_ID      CONSTANT text         := 'SPIPI002K14R06';  -- SP名称
	PROGRAM_NAME      CONSTANT text      := '現物債未払管理入力取込確認リスト（支払報告データ）';  -- 機能名称
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
    gRtnCd          numeric := pkconstant.success();      -- リターンコード
	errUmuFlg       varchar(1) := '9';                  --エラーフラグ
	errCnt          numeric := 0;                       --エラー件数
	gOkCnt          numeric := 0;                       --正常件数
	gSouCnt         numeric := 0;                       --総件数
	gNo             numeric := 0;                       --NO
	gSeqNo          integer := 0;                      --シーケンス
	
	
	errMsg          varchar(300);
	errCode         varchar(6);
	--======================================================================
	--              カーソル定義                                            
	--======================================================================
	curResult CURSOR FOR
		SELECT
			KC16.MGR_CD,
			MT18.HAKKOSHA_RNM || '　'|| MT18.KAIGO_TO || MT18.BOSHU_KBN AS MGR_NM,
			KC16.ERR_UMU_FLG,
			KC16.ERR_NM30
		FROM import_kakunin_list_wk kc16
LEFT OUTER JOIN gb_hakko_yoko mt18 ON (KC16.MGR_CD = MT18.KOYU_MGR_CD AND KC16.ITAKU_KAISHA_CD = MT18.ITAKU_KAISHA_CD)
WHERE KC16.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND KC16.USER_ID = l_inUserId AND KC16.CHOHYO_ID = REPORT_ID AND KC16.SAKUSEI_YMD = l_inGyomuYmd ORDER BY ERR_UMU_FLG DESC, SEQ_NO;
	curCount CURSOR FOR
		SELECT
			COUNT(*) AS CNT
		FROM import_kakunin_list_wk kc16
LEFT OUTER JOIN gb_hakko_yoko mt18 ON (KC16.MGR_CD = MT18.KOYU_MGR_CD AND KC16.ITAKU_KAISHA_CD = MT18.ITAKU_KAISHA_CD)
WHERE KC16.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND KC16.USER_ID = l_inUserId AND KC16.CHOHYO_ID = REPORT_ID AND KC16.SAKUSEI_YMD = l_inGyomuYmd;
--==============================================================================
--	メインルーチン                                                          	
--==============================================================================
BEGIN
	CALL pkLog.debug(l_inUserId,  '○' || PROGRAM_NAME ||'('|| PROGRAM_ID||')', ' START');
	-- 引数（必須）データチェック ※委託会社コード、ユーザID、帳票区分、業務日付は必須入力項目
	IF (coalesce(trim(both l_inItakuKaishaCd)::text, '') = '')
	OR (coalesce(trim(both l_inUserId)::text, '') = '')
	OR (coalesce(trim(both l_inChohyoKbn)::text, '') = '')
	OR (coalesce(trim(both l_inGyomuYmd)::text, '') = '')
	THEN
	-- ログ書込み
		errCode := 'ECM501';
		errMsg := '入力パラメータエラー';
		RAISE EXCEPTION 'errijou' USING ERRCODE = '50001';
	END IF;
	--帳票ワークの削除
	DELETE FROM SREPORT_WK
		WHERE KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = l_inGyomuYmd
		AND CHOHYO_ID = REPORT_ID;
	--ヘッダレコードを出力
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	--帳票ワークテーブルを出力
	FOR recCount IN curCount LOOP
		IF recCount.CNT = 0 THEN
			gSeqNo := gSeqNo + 1;
			IF errUmuFlg = '9' THEN
						-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := '';	-- 番号
		v_item.l_inItem003 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem004 := '';	-- 銘柄コード
		v_item.l_inItem005 := '';	-- 銘柄名称
		v_item.l_inItem006 := '';	-- エラー内容
		v_item.l_inItem007 := 'エラー件数';	-- "件数"
		v_item.l_inItem008 := errCnt;	-- 件数
		v_item.l_inItem009 := '件';	-- "件"
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
			END IF;
		ELSE
			FOR recResult IN curResult LOOP
				gSeqNo := gSeqNo + 1;
				gSouCnt := gSouCnt + 1;
				IF recResult.ERR_UMU_FLG = '1' THEN
					errCnt := errCnt + 1;
					gNo := gNo + 1;
				ELSIF recResult.ERR_UMU_FLG = '0' THEN
  					IF errUmuFlg <> recResult.ERR_UMU_FLG THEN
								-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := '';	-- 番号
		v_item.l_inItem003 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem004 := '';	-- 銘柄コード
		v_item.l_inItem005 := '';	-- 銘柄名称
		v_item.l_inItem006 := '';	-- エラー内容
		v_item.l_inItem007 := '';	-- "件数"
		v_item.l_inItem008 := '';	-- 件数
		v_item.l_inItem009 := '';	-- "件"
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
						gSeqNo := gSeqNo + 1;
								-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := '';	-- 番号
		v_item.l_inItem003 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem004 := '';	-- 銘柄コード
		v_item.l_inItem005 := '';	-- 銘柄名称
		v_item.l_inItem006 := '';	-- エラー内容
		v_item.l_inItem007 := 'エラー件数';	-- "件数"
		v_item.l_inItem008 := errCnt;	-- 件数
		v_item.l_inItem009 := '件';	-- "件"
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
						gSeqNo := gSeqNo + 1;
								-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := '';	-- 番号
		v_item.l_inItem003 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem004 := '';	-- 銘柄コード
		v_item.l_inItem005 := '';	-- 銘柄名称
		v_item.l_inItem006 := '';	-- エラー内容
		v_item.l_inItem007 := '';	-- "件数"
		v_item.l_inItem008 := '';	-- 件数
		v_item.l_inItem009 := '';	-- "件"
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
						gSeqNo := gSeqNo + 1;
						gNo := 0;
					END IF;
					gOkCnt := gOkCnt + 1;
					gNo := gNo + 1;
				END IF;
						-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := gNo;	-- 番号
		v_item.l_inItem003 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem004 := recResult.MGR_CD;	-- 銘柄コード
		v_item.l_inItem005 := recResult.MGR_NM;	-- 銘柄名称
		v_item.l_inItem006 := recResult.ERR_NM30;	-- エラー内容
		v_item.l_inItem007 := '';	-- "件数"
		v_item.l_inItem008 := '';	-- 件数
		v_item.l_inItem009 := '';	-- "件"
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
				errUmuFlg := recResult.ERR_UMU_FLG;
			END LOOP;
		END IF;
		IF errUmuFlg = '1' THEN
			gSeqNo := gSeqNo + 1;
					-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := '';	-- 番号
		v_item.l_inItem003 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem004 := '';	-- 銘柄コード
		v_item.l_inItem005 := '';	-- 銘柄名称
		v_item.l_inItem006 := '';	-- エラー内容
		v_item.l_inItem007 := '';	-- "件数"
		v_item.l_inItem008 := '';	-- 件数
		v_item.l_inItem009 := '';	-- "件"
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
			gSeqNo := gSeqNo + 1;
					-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := '';	-- 番号
		v_item.l_inItem003 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem004 := '';	-- 銘柄コード
		v_item.l_inItem005 := '';	-- 銘柄名称
		v_item.l_inItem006 := '';	-- エラー内容
		v_item.l_inItem007 := 'エラー件数';	-- "件数"
		v_item.l_inItem008 := errCnt;	-- 件数
		v_item.l_inItem009 := '件';	-- "件"
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		END IF;
		gSeqNo := gSeqNo + 1;
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := '';	-- 番号
		v_item.l_inItem003 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem004 := '';	-- 銘柄コード
		v_item.l_inItem005 := '';	-- 銘柄名称
		v_item.l_inItem006 := '';	-- エラー内容
		v_item.l_inItem007 := '';	-- "件数"
		v_item.l_inItem008 := '';	-- 件数
		v_item.l_inItem009 := '';	-- "件"
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		gSeqNo := gSeqNo + 1;
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := '';	-- 番号
		v_item.l_inItem003 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem004 := '';	-- 銘柄コード
		v_item.l_inItem005 := '';	-- 銘柄名称
		v_item.l_inItem006 := '';	-- エラー内容
		v_item.l_inItem007 := '正常取込件数';	-- "件数"
		v_item.l_inItem008 := gOkCnt;	-- 件数
		v_item.l_inItem009 := '件';	-- "件"
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		gSeqNo := gSeqNo + 1;
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := '';	-- 番号
		v_item.l_inItem003 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem004 := '';	-- 銘柄コード
		v_item.l_inItem005 := '';	-- 銘柄名称
		v_item.l_inItem006 := '';	-- エラー内容
		v_item.l_inItem007 := '';	-- "件数"
		v_item.l_inItem008 := '';	-- 件数
		v_item.l_inItem009 := '';	-- "件"
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		gSeqNo := gSeqNo + 1;
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := '';	-- 番号
		v_item.l_inItem003 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem004 := '';	-- 銘柄コード
		v_item.l_inItem005 := '';	-- 銘柄名称
		v_item.l_inItem006 := '';	-- エラー内容
		v_item.l_inItem007 := '総取込件数';	-- "総件数"
		v_item.l_inItem008 := gSouCnt;	-- 総件数
		v_item.l_inItem009 := '件';	-- "件"
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	END LOOP;
   -- バッチ帳票印刷管理テーブル登録
    CALL pkPrtOk.insertPrtOk(
			l_inUserId,
			l_inItakuKaishaCd,
			l_inGyomuYmd,
			pkPrtOk.LIST_SAKUSEI_KBN_ZUIJI(),
			REPORT_ID);
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	CALL pkLog.debug(l_inUserId,  '○' || PROGRAM_NAME ||'('|| PROGRAM_ID ||')', ' END');
-- エラー処理
EXCEPTION
	WHEN SQLSTATE '50002' THEN
		CALL pkLog.debug(l_inUserId,'△' || PROGRAM_NAME ||'('|| PROGRAM_ID ||')', 'warnGyom');
		l_outSqlCode := gRtnCd;
		l_outSqlErrM := '';
	WHEN SQLSTATE '50001' THEN
		CALL pkLog.debug(l_inUserId, '×' || PROGRAM_NAME ||'('|| PROGRAM_ID ||')', 'errIjou');
		CALL pkLog.error(errCode, PROGRAM_ID, errMsg);
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '';
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', PROGRAM_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', PROGRAM_ID, 'SQLERRM:' || SQLERRM);
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLERRM;
		CALL pkLog.debug(l_inUserId, REPORT_ID, '×' || PROGRAM_ID || ' END（例外発生）');
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipi002k14r06 ( l_inItakuKaishaCd text, l_inUserId text, l_inChohyoKbn text, l_inGyomuYmd text, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;