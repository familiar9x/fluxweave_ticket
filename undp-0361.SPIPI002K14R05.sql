




CREATE OR REPLACE PROCEDURE spipi002k14r05 ( l_inItakuKaishaCd text,        -- 委託会社コード
 l_inUserId text,        -- ユーザID
 l_inChohyoKbn text,        -- 帳票区分
 l_inGyomuYmd text,        -- 業務日付
 l_inDataList KIBANGODATALIST,  --データリスト情報
 l_outSqlCode OUT integer,      -- リターン値
 l_outSqlErrM OUT text     -- エラーコメント
 ) AS $body$
DECLARE

--
-- * 著作権:Copyright(c)2013
-- * 会社名:JIP
-- *
-- * 概要　:現物債未払管理入力取込の画面より、「記番号データ」を選択時に作成される。
-- *
-- * 引数　:l_inItakuKaishaCd        IN  TEXT,        -- 委託会社コード
-- *        l_inUserId               IN  TEXT,        -- ユーザID
-- *        l_inChohyoKbn            IN  TEXT,        -- 帳票区分
-- *        l_inGyomuYmd             IN  TEXT,        -- 業務日付
-- *        l_inDataList             IN  KIBANGODATALIST,  --データリスト情報
-- *        l_outSqlCode             OUT NUMERIC,      -- リターン値
-- *        l_outSqlErrM             OUT VARCHAR     -- エラーコメント
-- *
-- * 返り値: なし
-- *
-- * @author Xu Chunxu
-- * @version $Id: SPIPI002K14R05.sql,v 1.2 2013/07/09 07:14:43 ito Exp $
--
	--==============================================================================
	--                  デバッグ機能                                                
	--==============================================================================
	DEBUG	numeric(1)	:= 0;
	--==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	REPORT_ID         CONSTANT text        := 'IP931400261';     -- 帳票ＩＤ
	PROGRAM_ID      CONSTANT text      := 'SPIPI002K14R05';  -- SP名称
	PROGRAM_NAME      CONSTANT text    := '記番号データリスト';  -- 機能名称
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gSeqNo          integer := 0;                       --シーケンス
	gRtnCd          numeric := pkconstant.success();      -- リターンコード
	gSyoriKbnNm		SCODE.CODE_NM%TYPE;                      --処理区分名称
	gGnrKbn			SCODE.CODE_NM%TYPE;                      --元利区分
	gSoriKbn		varchar(1) := NULL;                --処理区分（コード）
	gMgrKaigoCd		varchar(13) := NULL;                -- 銘柄・回号コード
	gMgrKaigoNm		varchar(39) := NULL;                -- 銘柄・回号名称
	gSyokomiBi		varchar(8) := NULL;                -- 消込日
	gKenCnt			integer := 0;                       --件数
	gRecdSort		varchar(6) := NULL;                 --レコード入力順
	
	
	errMsg          varchar(300);
	errCode         varchar(6);
	--======================================================================
	--              カーソル定義                                            
	--======================================================================
	--処理区分名称を取得
	curResult1 CURSOR FOR
		SELECT
			CODE_VALUE,
			CODE_NM
		FROM SCODE
		WHERE CODE_SHUBETSU = 'U20'
		ORDER BY CODE_VALUE;
	--元利区分名称を取得
	curResult2 CURSOR FOR
		SELECT
			CODE_VALUE,
			CODE_NM
		FROM SCODE
		WHERE CODE_SHUBETSU = 'U19'
		ORDER BY CODE_VALUE;
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
	--件数統計
	FOR i IN 1..coalesce(cardinality(l_inDataList), 0)
	LOOP
		IF (coalesce(gSoriKbn::text, '') = '' OR gSoriKbn <> l_inDataList[i].l_inSyoriKbnCd)
		OR (coalesce(gMgrKaigoCd::text, '') = '' OR gMgrKaigoCd <> l_inDataList[i].l_inMgrKaigoCd)
		OR (coalesce(gSyokomiBi::text, '') = '' OR gSyokomiBi <> l_inDataList[i].l_inSyokomiBi)
		OR (coalesce(gMgrKaigoNm::text, '') = '' OR gMgrKaigoNm <> l_inDataList[i].l_inMgrKaigoNm)
		OR (coalesce(gRecdSort::text, '') = '' OR gRecdSort <> l_inDataList[i].l_inRecdSort) THEN
			gKenCnt := gKenCnt + 1;
		END IF;
		gSoriKbn := l_inDataList[i].l_inSyoriKbnCd;
		gMgrKaigoCd := l_inDataList[i].l_inMgrKaigoCd;
		gMgrKaigoNm := l_inDataList[i].l_inMgrKaigoNm;
		gSyokomiBi := l_inDataList[i].l_inSyokomiBi;
		gRecdSort := l_inDataList[i].l_inRecdSort;
	END LOOP;
	gSoriKbn := '';
	gMgrKaigoCd := '';
	gMgrKaigoNm := '';
	gSyokomiBi := '';
	gRecdSort := '';
	--帳票ワークテーブルを出力
	FOR i IN 1..coalesce(cardinality(l_inDataList), 0)
	LOOP
		gSeqNo := gSeqNo + 1;
		gSyoriKbnNm := '';
		gGnrKbn   := '';
		--処理区分名称を取得
		FOR recResult1 IN curResult1
		LOOP
			IF l_inDataList[i].l_inSyoriKbnCd = recResult1.CODE_VALUE THEN
				gSyoriKbnNm := recResult1.CODE_NM;
			END IF;
		END LOOP;
		--元利区分名称を取得
		FOR recResult2 IN curResult2
		LOOP
			IF l_inDataList[i].l_inGnrKbnCd = recResult2.CODE_VALUE THEN
				gGnrKbn := recResult2.CODE_NM;
			END IF;
		END LOOP;
		IF (coalesce(gSoriKbn::text, '') = '' OR gSoriKbn <> l_inDataList[i].l_inSyoriKbnCd)
		OR (coalesce(gMgrKaigoCd::text, '') = '' OR gMgrKaigoCd <> l_inDataList[i].l_inMgrKaigoCd)
		OR (coalesce(gSyokomiBi::text, '') = '' OR gSyokomiBi <> l_inDataList[i].l_inSyokomiBi)
		OR (coalesce(gMgrKaigoNm::text, '') = '' OR gMgrKaigoNm <> l_inDataList[i].l_inMgrKaigoNm)
		OR (coalesce(gRecdSort::text, '') = '' OR gRecdSort <> l_inDataList[i].l_inRecdSort) THEN
					-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem003 := gSyoriKbnNm;	-- 処理区分
		v_item.l_inItem004 := l_inDataList[i].l_inMgrKaigoCd;	-- 銘柄・回号コード
		v_item.l_inItem005 := l_inDataList[i].l_inMgrKaigoNm;	-- 銘柄・回号名称
		v_item.l_inItem006 := l_inDataList[i].l_inSyokomiBi;	-- 消込日
		v_item.l_inItem007 := l_inDataList[i].l_inKenShu;	-- 券種
		v_item.l_inItem008 := gGnrKbn;	-- 元利区分
		v_item.l_inItem009 := l_inDataList[i].l_inSaikenNoFrom;	-- 債券番号FROM
		v_item.l_inItem010 := l_inDataList[i].l_inSaikenNoTo;	-- 債券番号TO
		v_item.l_inItem011 := l_inDataList[i].l_inRiwatariNoFrom;	-- 利渡期FROM
		v_item.l_inItem012 := l_inDataList[i].l_inRiwatariNoTo;	-- 利渡期TO
		v_item.l_inItem013 := gKenCnt;	-- 件数
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,			l_inUserId		=> l_inUserId,			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		ELSE
					-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem003 := '';	-- 処理区分
		v_item.l_inItem004 := '';	-- 銘柄・回号コード
		v_item.l_inItem005 := '';	-- 銘柄・回号名称
		v_item.l_inItem006 := '';	-- 消込日
		v_item.l_inItem007 := l_inDataList[i].l_inKenShu;	-- 券種
		v_item.l_inItem008 := gGnrKbn;	-- 元利区分
		v_item.l_inItem009 := l_inDataList[i].l_inSaikenNoFrom;	-- 債券番号FROM
		v_item.l_inItem010 := l_inDataList[i].l_inSaikenNoTo;	-- 債券番号TO
		v_item.l_inItem011 := l_inDataList[i].l_inRiwatariNoFrom;	-- 利渡期FROM
		v_item.l_inItem012 := l_inDataList[i].l_inRiwatariNoTo;	-- 利渡期TO
		v_item.l_inItem013 := pkcharacter.numeric_to_char(gKenCnt);	-- 件数
		
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
		gSoriKbn := l_inDataList[i].l_inSyoriKbnCd;
		gMgrKaigoCd := l_inDataList[i].l_inMgrKaigoCd;
		gMgrKaigoNm := l_inDataList[i].l_inMgrKaigoNm;
		gSyokomiBi := l_inDataList[i].l_inSyokomiBi;
		gRecdSort := l_inDataList[i].l_inRecdSort;
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
-- REVOKE ALL ON PROCEDURE spipi002k14r05 ( l_inItakuKaishaCd text, l_inUserId text, l_inChohyoKbn text, l_inGyomuYmd text, l_inDataList KIBANGODATALIST, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;