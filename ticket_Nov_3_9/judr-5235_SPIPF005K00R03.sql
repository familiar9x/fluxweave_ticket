CREATE OR REPLACE PROCEDURE spipf005k00r03 (
	l_inItakuId vjiko_itaku.kaiin_id%type,	-- 委託会社コード
	l_inDataId scode.code_value%type,		-- データ種別
	l_outSqlCode OUT integer,						-- リターン値
	l_outSqlErrM OUT text						-- エラーコメント
) AS $body$
DECLARE

/**
 * 著作権: Copyright (c) 2005
 * 会社名: JIP
 *
 * 金融機関情報を基に金融機関マスタを作成する
 * 
 * @author 戸倉　一成
 * @version $Revision: 1.4 $
 * 
 * @param l_inItakuId    IN     CHAR				委託会社コード
 *        l_inDataId     IN     CHAR				データ種別
 *        l_outSqlCode   OUT    INTEGER				リターン値
 *        l_outSqlErrM   OUT    VARCHAR2			エラーコメント
 * @return INTEGER
 *                0:正常終了
 *                1:予期したエラー
 *               40:データ無し
 *               99:予期せぬエラー
 */
--==============================================================================
--                  定数定義                                                    
--==============================================================================
	MSGID_CHECK_HANKAKU_EISU	CONSTANT varchar(6)	:= 'ECM039'	;	--半角英数チェックエラー
	MSGID_CHECK_ZENKAKU 		CONSTANT varchar(6)	:= 'ECM009'	;	--全角チェックエラー
	MSGID_CHECK_CODE			CONSTANT varchar(6)	:= 'ECM305'	;	--コード値チェックエラー
	MSGID_CHECK_NUMBER			CONSTANT varchar(6)	:= 'ECM002'	;	--数値チェックエラー
	MSGID_CHECK_ZENKAKU_KANA  	CONSTANT varchar(6)	:= 'ECM058'	;	--全角カナチェックエラー
	MSGID_CHECK_KETASU			CONSTANT varchar(6)	:= 'ECM012'	;	--桁数チェックエラー
	MSGID_CHECK_HANKAKU			CONSTANT varchar(6)	:= 'ECM010'	;	--半角チェックエラー
	MSGID_CHECK_HIDUKE			CONSTANT varchar(6)  	:= 'ECM005'	;	--日付チェックエラー
	MSGID_CHECK_HIKIOTOSHI		CONSTANT varchar(6)	:= 'ECM001'	;	--引落しチェックエラー
	MSGID_CHECK_FUKUSURAN		CONSTANT varchar(6)	:= 'ECM019'	;	--複数欄チェックエラー
	MSG_PARAM_ERROR CONSTANT varchar(30)   := 'パラメーターエラー';
	MSG_NO_DATA     CONSTANT varchar(30)   := 'データ無しエラー';
	MSG_DATA_ERROR  CONSTANT varchar(30)   := 'データエラー';
	MSG_COMMON_ERR	CONSTANT varchar(30)	:= '共通関数エラー'		;
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	cGyoumuDt   sreport_wk.sakusei_ymd%type;	-- 業務日付
	nCount      numeric;							-- 件数カウンタ
	nRtnCd      numeric;							-- 正常処理フラグ
	nRtnCd2     numeric;							-- エラーリスト（共通）ＳＰ用
	cMsgId      char(6);						-- メッセージID
	vRtnErrMsg  varchar(10);					-- エラーコメント
	cFlg        char(1);						-- エラーフラグ
	cRbFlg      char(1);						-- ロールバックフラグ
--==============================================================================
--                  カーソル定義                                                
--==============================================================================
	curMbank CURSOR FOR
		SELECT 
			financial_securities_kbn,
			bank_cd,
			bank_nm,
			bank_rnm,
			bank_kana_rnm,
			LIN_NO 
		FROM 
			mbank_trns 
		ORDER BY 
			financial_securities_kbn, 
			bank_cd;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 入力パラメータのチェック（委託会社コード）
	IF coalesce(trim(both l_inItakuId)::text, '') = '' THEN
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := MSG_PARAM_ERROR;
		CALL pkLog.error('ECM501', 'IPF005K00R03', '＜項目名称:委託会社コード＞＜項目値:' || l_inItakuId || '＞');
		RETURN;
	END IF;
	-- 入力パラメータのチェック（データ種別）
	IF coalesce(trim(both l_inDataId)::text, '') = '' THEN
		l_outSqlCode := pkconstant.error();
	 	l_outSqlErrM := MSG_PARAM_ERROR;
		CALL pkLog.error('ECM501', 'IPF005K00R03',	'＜項目名称:データ種別＞＜項目値:' || l_inDataId || '＞');
		RETURN;
	END IF;
	-- 委託会社コードをチェック
	nCount := 0;
	SELECT count(*) INTO STRICT nCount
	FROM   vjiko_itaku 
	WHERE  kaiin_id = l_inItakuId;
	-- 委託会社コードが自行・委託会社マスタに存在しない場合
	IF nCount = 0 THEN
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := MSG_PARAM_ERROR;
		CALL pkLog.error('ECM501', 'IPF005K00R03', '＜項目名称:委託会社コード＞＜項目値:' || l_inItakuId || '＞');
		RETURN;
	END IF;
	-- データ種別をチェック
	nCount := 0;
	SELECT count(*)	INTO STRICT nCount
	FROM scode
	WHERE  code_shubetsu = '191'
	AND    code_value = l_inDataId;
	-- データ種別がコードマスタに存在しない場合
	IF nCount = 0 THEN
		l_outSqlCode := pkconstant.error();
	 	l_outSqlErrM := MSG_PARAM_ERROR;
		CALL pkLog.error('ECM501', 'IPF005K00R03',	'＜項目名称:データ種別＞＜項目値:' || l_inDataId || '＞');
		RETURN;
	END IF;
	-- 業務日付を取得
	cGyoumuDt := pkDate.getGyomuYmd();
	-- 帳票ワーク削除
	DELETE FROM sreport_wk
	WHERE  key_cd      = l_inItakuId 
	AND    user_id     = 'BATCH' 
	AND    chohyo_kbn  = '1'
	AND    sakusei_ymd = cGyoumuDt 
	AND    chohyo_id   = 'IPF30000111'
	AND    item003     = l_inDataId;
	-- 金融機関マスタ(移行用)の件数をチェック
	nCount := 0;
	SELECT count(*) INTO STRICT nCount FROM mbank_trns;
	-- 金融機関マスタ(移行用)の件数が０件の場合
	IF nCount = 0 THEN
		l_outSqlCode := pkconstant.NO_DATA_FIND();
		l_outSqlErrM := MSG_NO_DATA;
		CALL pkLog.error('EIP505', 'IPF005K00R03', MSG_NO_DATA);
		RETURN;
	END IF;
	-- 金融機関マスタの件数をチェック
	nCount := 0;
	SELECT count(*) INTO STRICT nCount
	FROM   mbank
	WHERE  financial_securities_kbn = '0';
	-- 金融機関マスタの件数が０件でない場合、データを削除する
	IF nCount != 0 THEN
		-- バックアップ
		DELETE FROM mbank_bk;
		INSERT INTO mbank_bk(
			financial_securities_kbn,
			bank_cd,
			bank_nm,
			bank_rnm,
			bank_kana_rnm,
			shori_kbn,
			last_teisei_dt,
			last_teisei_id, 
			shonin_dt, 
			shonin_id, 
			kousin_dt, 
			kousin_id, 
			sakusei_dt, 
			sakusei_id
		)
		SELECT  financial_securities_kbn,
				bank_cd,
				bank_nm,
				bank_rnm,
				bank_kana_rnm,
				shori_kbn,
				last_teisei_dt, 
				last_teisei_id, 
				shonin_dt, 
				shonin_id, 
				kousin_dt, 
				kousin_id, 
				sakusei_dt, 
				sakusei_id
		FROM    mbank;
		-- データ削除
		DELETE FROM mbank
		WHERE  financial_securities_kbn = '0';
		-- 金融機関マスタロールバックフラグに'1'を設定
		cRbFlg := '1';
	END IF;
	-- エラーフラグを初期化
	cFlg := '0';
	-- チェック、更新処理
	FOR recMbank IN curMbank LOOP
		-- コード値チェック
		nRtnCd := spipf005k00r03_common_func(
					recMbank.financial_securities_kbn,
					'金融証券区分', 
					recMbank.lin_no, 
					1,
					l_inItakuId,
					cGyoumuDt,
					l_inDataId
				);
		IF nRtnCd = 1 THEN
			-- エラーフラグに'1'を設定
			cFlg := '1';
		END IF;
		-- 桁数チェック
		IF LENGTH(trim(both recMbank.bank_cd)) = 4 THEN
			-- 数値チェック
			nRtnCd := spipf005k00r03_common_func(
						recMbank.bank_cd,
						'金融機関コード',
						recMbank.lin_no,
						2,
						l_inItakuId,
						cGyoumuDt,
						l_inDataId
					  );
		ELSE
			-- 桁数チェックエラー
			nRtnCd := spipf005k00r03_common_func(
						recMbank.bank_cd,
						'金融機関コード',
						recMbank.lin_no,
						9,
						l_inItakuId,
						cGyoumuDt,
						l_inDataId
					  );
		END IF;
		IF nRtnCd = 1 THEN
			-- エラーフラグに'1'を設定
			cFlg := '1';
		END IF;
		-- 全角チェック
		nRtnCd := spipf005k00r03_common_func(
					recMbank.bank_nm,
					'金融機関名称', 
					recMbank.lin_no, 
					3,
					l_inItakuId,
					cGyoumuDt,
					l_inDataId
				);
		IF nRtnCd = 1 THEN
			-- エラーフラグに'1'を設定
			cFlg := '1';
		END IF;
		nRtnCd := spipf005k00r03_common_func(
					recMbank.bank_rnm,
					'金融機関略称', 
					recMbank.lin_no, 
					3,
					l_inItakuId,
					cGyoumuDt,
					l_inDataId
				);
		IF nRtnCd = 1 THEN
			-- エラーフラグに'1'を設定
			cFlg := '1';
		END IF;
		-- 全角カナチェック
		nRtnCd := spipf005k00r03_common_func(
					recMbank.bank_kana_rnm,
					'金融機関略称（カナ）', 
					recMbank.lin_no, 
					4,
					l_inItakuId,
					cGyoumuDt,
					l_inDataId
				);
		IF nRtnCd = 1 THEN
			-- エラーフラグに'1'を設定
			cFlg := '1';
		END IF;
		-- エラーフラグが'0'の場合、金融機関マスタへ書き込み
		IF cFlg = '0' THEN
			INSERT INTO mbank(
				financial_securities_kbn,
				bank_cd, 
				bank_nm, 
				bank_rnm, 
				bank_kana_rnm,
				shori_kbn, 
				last_teisei_dt, 
				last_teisei_id, 
				shonin_dt, 
				shonin_id, 
				kousin_dt, 
				kousin_id, 
				sakusei_dt, 
				sakusei_id
			)
			VALUES (
				recMbank.financial_securities_kbn, 
				recMbank.bank_cd,
				recMbank.bank_nm, 
				recMbank.bank_rnm, 
				recMbank.bank_kana_rnm,  
				'1', 
				current_timestamp, 
				'ikou', 
				current_timestamp,
				'ikou', 
				current_timestamp, 
				'ikou', 
				current_timestamp, 
				'ikou'
			);
		END IF;
	END LOOP;
	-- エラーフラグが'1'の場合、リターン値に'1'を設定
	IF cFlg = '1' THEN
		DELETE FROM mbank;
		IF cRbFlg = '1' THEN
			-- 金融機関マスタロールバック処理
			INSERT INTO mbank(
				financial_securities_kbn,
				bank_cd, 
				bank_nm, 
				bank_rnm, 
				bank_kana_rnm,
				shori_kbn, 
				last_teisei_dt, 
				last_teisei_id, 
				shonin_dt, 
				shonin_id, 
				kousin_dt, 
				kousin_id, 
				sakusei_dt, 
				sakusei_id
			)
			SELECT 
				financial_securities_kbn,
				bank_cd,
				bank_nm,
				bank_rnm,
				bank_kana_rnm,
				shori_kbn,
				last_teisei_dt, 
				last_teisei_id, 
				shonin_dt, 
				shonin_id, 
				kousin_dt, 
				kousin_id, 
				sakusei_dt, 
				sakusei_id
			FROM 
				mbank_bk;
		END IF;
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := MSG_DATA_ERROR;
		CALL pkLog.error('ECM502', 'IPF005K00R03', MSG_DATA_ERROR);
	ELSE
		-- エラーフラグが'0'の場合、リターン値に'0'を設定
		l_outSqlCode := pkconstant.success();
		l_outSqlErrM := '';
	END IF;
	RETURN;
--==============================================================================
--                  エラー処理                                                  
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'IPF005K00R03', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLERRM || '(' || SQLSTATE || ')';
		RETURN;
END;
$body$
LANGUAGE PLPGSQL;

--==============================================================================
-- Nested Function: spipf005k00r03_common_func
-- パラメータを基に各共通関数を呼び出す
--==============================================================================
CREATE OR REPLACE FUNCTION spipf005k00r03_common_func (
	l_inwk1 text,			-- 共通関数へ引き渡す文字列
	l_inwk2 text,			-- 項目名称
	l_inwk3 numeric,		-- 行番号
	l_inwk4 numeric,		-- 共通関数振り分け用数値
	p_inItakuId text,		-- 委託会社コード (from parent)
	p_cGyoumuDt text,		-- 業務日付 (from parent)
	p_inDataId text			-- データ種別 (from parent)
) RETURNS numeric AS $body$
DECLARE
	MSGID_CHECK_CODE			CONSTANT varchar(6)	:= 'ECM305'	;
	MSGID_CHECK_NUMBER			CONSTANT varchar(6)	:= 'ECM002'	;
	MSGID_CHECK_ZENKAKU 		CONSTANT varchar(6)	:= 'ECM009'	;
	MSGID_CHECK_ZENKAKU_KANA  	CONSTANT varchar(6)	:= 'ECM058'	;
	MSGID_CHECK_KETASU			CONSTANT varchar(6)	:= 'ECM012'	;
	
	nRtnCd numeric;
	nRtnCd2 integer;  -- Changed from numeric to integer for spipf001k00r01 compatibility
	vRtnErrMsg varchar(10);
	cMsgId char(6);

BEGIN
	-- リターンコードを初期化
	nRtnCd := 0;
	CASE l_inwk4
		-- コードチェック
		WHEN 1 THEN
			cMsgId := MSGID_CHECK_CODE;
			IF LENGTH(trim(both l_inwk1)) > 0 THEN
				nRtnCd := sfCmIsCodeMChek('507', l_inwk1);
			ELSE
				nRtnCd := 1;
			END IF;
		-- 数値チェック
		WHEN 2 THEN
			cMsgId := MSGID_CHECK_NUMBER;
			IF LENGTH(trim(both l_inwk1)) > 0 THEN
				nRtnCd := sfCmIsNumeric(l_inwk1);
			ELSE
				nRtnCd := 1;
			END IF;
		-- 全角チェック
		WHEN 3 THEN
			cMsgId := MSGID_CHECK_ZENKAKU;
			IF LENGTH(trim(both l_inwk1)) > 0 THEN
				nRtnCd := sfCmIsFullsizeChar(l_inwk1);
			ELSE
				nRtnCd := 1;
			END IF;
		-- 全角カナチェック
		WHEN 4 THEN
			cMsgId := MSGID_CHECK_ZENKAKU_KANA;
			IF LENGTH(trim(both l_inwk1)) > 0 THEN
				nRtnCd := sfCmIsZenKana(l_inwk1);
			ELSE
				nRtnCd := 1;
			END IF;
		-- 桁数チェックエラー
		ELSE
			nRtnCd := 1;
			cMsgId := MSGID_CHECK_KETASU;
	END CASE;
	-- 共通関数からの戻り値が'1'の場合、エラーリスト（共通）作成ＳＰを呼び出す
	IF nRtnCd = 1 THEN
		CALL spipf001k00r01(
			l_inItakuId    => p_inItakuId::CHAR,
			l_inUserId     => 'BATCH'::VARCHAR,
			l_inChyohyoKbn => '1'::CHAR,
			l_inChyohyoSakuKbn => '3'::CHAR,
			l_inGyoumuDt   => p_cGyoumuDt::CHAR,
			l_inDataId     => p_inDataId::VARCHAR,
			l_inRowNum     => l_inwk3,
			l_inColNm      => l_inwk2::VARCHAR,
			l_inSyuroku    => l_inwk1::VARCHAR,
			l_inMessageId  => cMsgId::VARCHAR,
			l_outSqlCode   => nRtnCd2,
			l_outSqlErrM   => vRtnErrMsg
		);
		RETURN nRtnCd;
	END IF;
	RETURN nRtnCd;
END;
$body$
LANGUAGE PLPGSQL;
