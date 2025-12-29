




CREATE OR REPLACE PROCEDURE spipi002k14r07 ( l_inItakuKaishaCd text,        -- 委託会社コード
 l_inUserId text,        -- ユーザID
 l_inChohyoKbn text,        -- 帳票区分
 l_inGyomuYmd text,        -- 業務日付
 l_inDataList SHIHARAIHOKOKUDATALIST,  --データリスト情報
 l_outSqlCode OUT integer,      -- リターン値
 l_outSqlErrM OUT text     -- エラーコメント
 ) AS $body$
DECLARE

--
-- * 著作権:Copyright(c)2013
-- * 会社名:JIP
-- *
-- * 概要　:現物債未払管理入力取込の画面より、「支払報告データ」を選択時に作成される。
-- *
-- * 引数　:l_inItakuKaishaCd        IN  TEXT,        -- 委託会社コード
-- *        l_inUserId               IN  TEXT,        -- ユーザID
-- *        l_inChohyoKbn            IN  TEXT,        -- 帳票区分
-- *        l_inGyomuYmd             IN  TEXT,        -- 業務日付
-- *        l_inDataList             IN  SHIHARAIHOKOKUDATALIST,  --データリスト情報
-- *        l_outSqlCode             OUT NUMERIC,      -- リターン値
-- *        l_outSqlErrM             OUT VARCHAR     -- エラーコメント
-- *
-- * 返り値: なし
-- *
-- * @author Xu Chunxu
-- * @version $Id: SPIPI002K14R07.sql,v 1.1 2013/06/04 09:31:24 handa Exp $
--
	--==============================================================================
	--					デバッグ機能													
	--==============================================================================
	DEBUG	numeric(1)	:= 0;
	--==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	REPORT_ID         CONSTANT text       := 'IP931400271';     -- 帳票ＩＤ
	PROGRAM_ID      CONSTANT text         := 'SPIPI002K14R07';  -- SP名称
	PROGRAM_NAME      CONSTANT text      := '支払報告データリスト';  -- 機能名称
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gSeqNo          integer := 0;                       --シーケンス
	gRtnCd          numeric := pkconstant.success();      -- リターンコード
	gSyoriKbn		SCODE.CODE_NM%TYPE;                      --処理区分
	gKisanKbn		SCODE.CODE_NM%TYPE;                      --起算区分
	gCapTekiy		SCODE.CODE_NM%TYPE;                      --キャップ適用
	gGnrKbn			SCODE.CODE_NM%TYPE;                      --元利区分
	gBankRnm		MBANK.BANK_RNM%TYPE;                     --支払場所名称
	gTaxNm			GB_MTAX.TAX_NM%TYPE;                     --課税区分名称
	
	
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
		WHERE CODE_SHUBETSU = 'U21'
		ORDER BY CODE_VALUE;
	--起算名称を取得
	curResult2 CURSOR FOR
		SELECT
			CODE_VALUE,
			CODE_NM
		FROM SCODE
		WHERE CODE_SHUBETSU = 'U11'
		ORDER BY CODE_VALUE;
	--キャップ適用名称を取得
	curResult3 CURSOR FOR
		SELECT
			CODE_VALUE,
			CODE_NM
		FROM SCODE
		WHERE CODE_SHUBETSU = 'U12'
		ORDER BY CODE_VALUE;
	--元利区分名称を取得
	curResult4 CURSOR FOR
		SELECT
			CODE_VALUE,
			CODE_NM
		FROM SCODE
		WHERE CODE_SHUBETSU = 'U14'
		ORDER BY CODE_VALUE;
	--支払場所名称を取得
	curResultm02 CURSOR(shaBasyoCd TEXT) FOR
		SELECT	
			BANK_RNM
		FROM MBANK
		WHERE FINANCIAL_SECURITIES_KBN = '0'
			AND BANK_CD = shaBasyoCd;
	--課税区分名称を取得
	curResultmt19 CURSOR(kazeiKbnCd TEXT) FOR
		SELECT
			TAX_NM
		FROM GB_MTAX
		WHERE ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND TAX_KBN = kazeiKbnCd;
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
	FOR i IN 1..coalesce(cardinality(l_inDataList), 0)
	LOOP
		gSeqNo := gSeqNo + 1;
		gSyoriKbn := '';
		gKisanKbn := '';
		gCapTekiy := '';
		gGnrKbn   := '';
		gBankRnm  := '';
		gTaxNm    := '';
		--処理区分名称を取得
		FOR recResult1 IN curResult1
		LOOP
			IF l_inDataList[i].l_inSyoriKbnCd = recResult1.CODE_VALUE THEN
				gSyoriKbn := recResult1.CODE_NM;
			END IF;
		END LOOP;
		--起算名称を取得
		FOR recResult2 IN curResult2
		LOOP
			IF l_inDataList[i].l_inKisanKbnCd = recResult2.CODE_VALUE THEN
				gKisanKbn := recResult2.CODE_NM;
			END IF;
		END LOOP;
		--キャップ適用名称を取得
		FOR recResult3 IN curResult3
		LOOP
			IF l_inDataList[i].l_inCapTekiyoCd = recResult3.CODE_VALUE THEN
				gCapTekiy := recResult3.CODE_NM;
			END IF;
		END LOOP;
		--元利区分名称を取得
		FOR recResult4 IN curResult4
		LOOP
			IF l_inDataList[i].l_inGnrKbnCd = recResult4.CODE_VALUE THEN
				gGnrKbn := recResult4.CODE_NM;
			END IF;
		END LOOP;
		FOR recResultm02 IN curResultm02(l_inDataList[i].l_inShaBasyoCd)
		LOOP
			gBankRnm := recResultm02.BANK_RNM;
		END LOOP;
		--課税区分名称を取得
		FOR recResultmt19 IN curResultmt19(l_inDataList[i].l_inKazeiKbnCd)
		LOOP
			gTaxNm := recResultmt19.TAX_NM;
		END LOOP;
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem003 := gSyoriKbn;	-- 処理区分
		v_item.l_inItem004 := l_inDataList[i].l_inTorihikiCd;	-- 取引月
		v_item.l_inItem005 := l_inDataList[i].l_inShaBasyoCd;	-- 支払場所コード
		v_item.l_inItem006 := gBankRnm;	-- 支払場所名称
		v_item.l_inItem007 := l_inDataList[i].l_inMgrKaigoCd;	-- 銘柄・回号コード
		v_item.l_inItem008 := l_inDataList[i].l_inMgrKaigoNm;	-- 銘柄・回号名称
		v_item.l_inItem009 := l_inDataList[i].l_inKessaiNo;	-- 決済番号
		v_item.l_inItem010 := l_inDataList[i].l_inGyoNo;	-- 行番号
		v_item.l_inItem011 := gKisanKbn;	-- 起算区分
		v_item.l_inItem012 := gCapTekiy;	-- キャップ適用
		v_item.l_inItem013 := l_inDataList[i].l_inRyokanYMD;	-- 償還・利渡期日
		v_item.l_inItem014 := gGnrKbn;	-- 元利区分
		v_item.l_inItem015 := l_inDataList[i].l_inShasaiGkmnRifudaGaku;	-- 社債額面・利札額面
		v_item.l_inItem016 := l_inDataList[i].l_inMaisu;	-- 枚数
		v_item.l_inItem017 := l_inDataList[i].l_inGnrShKngk;	-- 元利金支払額
		v_item.l_inItem018 := gTaxNm;	-- 課税区分
		v_item.l_inItem019 := l_inDataList[i].l_inZeiRitsu;	-- 税率
		v_item.l_inItem020 := l_inDataList[i].l_inKokuzeiGaku;	-- 国税額
		v_item.l_inItem021 := l_inDataList[i].l_inShaRoMaisu;	-- 支払領収書枚数
		
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
-- REVOKE ALL ON PROCEDURE spipi002k14r07 ( l_inItakuKaishaCd text, l_inUserId text, l_inChohyoKbn text, l_inGyomuYmd text, l_inDataList SHIHARAIHOKOKUDATALIST, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;