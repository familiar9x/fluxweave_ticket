CREATE OR REPLACE PROCEDURE spipf001k00r01 (
	l_initakuid        TEXT,                                     -- 委託会社コード
	l_inuserid         VARCHAR,                                  -- ユーザID
	l_inchyohyokbn     TEXT,                                     -- 帳票区分
	l_inchyohyosakukbn TEXT,                                     -- 帳票作成区分
	l_ingyoumudt       TEXT,                                     -- 業務日付
	l_indataid         VARCHAR,                                  -- データ種別
	l_inrownum         NUMERIC,                                  -- 行番号
	l_incolnm          VARCHAR,                                  -- 項目名称
	l_insyuroku        VARCHAR,                                  -- 収録内容
	l_inmessageid      varchar(6),                                  -- メッセージID
	l_outsqlcode       OUT INTEGER,                              -- リターン値
	l_outsqlerrm       OUT text                               -- エラーコメント
)
AS $body$
DECLARE
/**
 * 著作権: Copyright (c) 2005
 * 会社名: JIP
 *
 * エラー内容を表示する
 *
 * @author 小林　弘幸
 * @version $Revision: 1.5 $
 *
 * @param l_inItakuId        IN TEXT 委託会社コード
 *        l_inUserId         IN VARCHAR ユーザID
 *        l_inChyohyoKbn     IN TEXT 帳票区分
 *        l_inChyohyoSakuKbn IN TEXT 帳票作成区分
 *        l_inGyoumuDt       IN TEXT 業務日付
 *        l_inDataId         IN VARCHAR データ種別
 *        l_inRowNum         IN NUMERIC   行番号
 *        l_inColNm          IN VARCHAR 項目名称
 *        l_inSyuroku        IN VARCHAR 収録内容
 *        l_inMessageId      IN VARCHAR メッセージID
 *        l_outSqlCode       IN INTEGER  リターン値
 *        l_outSqlErrM       IN VARCHAR  エラーコメント
 * @return INTEGER
 *                0:正常終了
 *                1:予期したエラー
 *                40:データ無し
 *                99:予期せぬエラー
 */
/*==============================================================================*/
/*					定数定義													*/
/*==============================================================================*/
	MSGID_CHECK_HANKAKU_EISU	CONSTANT VARCHAR(6)	:= 'ECM039';	--半角英数チェックエラー
	MSGID_CHECK_ZENKAKU 		CONSTANT VARCHAR(6)	:= 'ECM009';	--全角チェックエラー
	MSGID_CHECK_CODE			CONSTANT VARCHAR(6)	:= 'ECM305';	--コード値チェックエラー
	MSGID_CHECK_NUMBER			CONSTANT VARCHAR(6)	:= 'ECM002';	--数値チェックエラー
	MSGID_CHECK_ZENKAKU_KANA  	CONSTANT VARCHAR(6)	:= 'ECM058';	--全角カナチェックエラー
	MSGID_CHECK_KETASU			CONSTANT VARCHAR(6)	:= 'ECM012';	--桁数チェックエラー
	MSGID_CHECK_HANKAKU			CONSTANT VARCHAR(6)	:= 'ECM010';	--半角チェックエラー
	MSGID_CHECK_HIDUKE			CONSTANT VARCHAR(6) := 'ECM005';	--日付チェックエラー
	MSGID_CHECK_HIKIOTOSHI		CONSTANT VARCHAR(6)	:= 'ECM001';	--引落しチェックエラー
	MSGID_CHECK_FUKUSURAN		CONSTANT VARCHAR(6)	:= 'ECM019';	--複数欄チェックエラー
	MSG_PARAM_ERROR CONSTANT VARCHAR(30)   := 'パラメーターエラー';
	MSG_NO_DATA     CONSTANT VARCHAR(30)   := 'データ無しエラー';
	MSG_DATA_ERROR  CONSTANT VARCHAR(30)   := 'データエラー';
	MSG_COMMON_ERR	CONSTANT VARCHAR(30)	:= '共通関数エラー';
	REPORT_ID       CONSTANT CHAR(11)      := 'IPF30000111';
/*==============================================================================*/
/*                  変数定義                                                    */
/*==============================================================================*/
	nCount NUMERIC;
	nRtnCd NUMERIC;
	nSeq_no INTEGER;  -- Changed from NUMERIC to INTEGER for pkPrint.insertData compatibility
	vDataNm VARCHAR(100);
	vMessage MSG_KANRI.MSG_NM%TYPE;
	vItakuKaishaRnm VARCHAR(100);
	cGyoumuDt sreport_wk.sakusei_ymd%type;
	-- Nested function result variables
	v_common_result RECORD;
	-- TYPE_SREPORT_WK_ITEM for insertData
	l_inItem TYPE_SREPORT_WK_ITEM;
/*==============================================================================*/
/*                  メイン処理                                                  */
/*==============================================================================*/
BEGIN
	-- パラメータチェック
	SELECT * INTO v_common_result FROM spipf001k00r01_common_func(l_inUserId, 1);
	IF v_common_result.o_result = TRUE THEN
		l_outSqlCode := v_common_result.o_sqlCode;
		l_outSqlErrM := v_common_result.o_sqlErrM;
		RETURN;
	END IF;
	
	SELECT * INTO v_common_result FROM spipf001k00r01_common_func(l_inChyohyoKbn, 2);
	IF v_common_result.o_result = TRUE THEN
		l_outSqlCode := v_common_result.o_sqlCode;
		l_outSqlErrM := v_common_result.o_sqlErrM;
		RETURN;
	END IF;
	
	SELECT * INTO v_common_result FROM spipf001k00r01_common_func(l_inChyohyoSakuKbn, 3);
	IF v_common_result.o_result = TRUE THEN
		l_outSqlCode := v_common_result.o_sqlCode;
		l_outSqlErrM := v_common_result.o_sqlErrM;
		RETURN;
	END IF;
	
	SELECT * INTO v_common_result FROM spipf001k00r01_common_func(l_inGyoumuDt, 4);
	IF v_common_result.o_result = TRUE THEN
		l_outSqlCode := v_common_result.o_sqlCode;
		l_outSqlErrM := v_common_result.o_sqlErrM;
		RETURN;
	END IF;

	-- 帳票区分をチェック
	nCount := 0;
	SELECT count(*)
	INTO STRICT nCount
	FROM scode
	WHERE code_shubetsu = '916'
	AND code_value = l_inChyohyoKbn;

	-- 帳票区分がコードマスタに存在しない場合
	IF nCount = 0 THEN
		l_outSqlCode := pkConstant.ERROR();
		l_outSqlErrM := MSG_PARAM_ERROR;
		CALL pkLog.error(
			'ECM501',
			'IPF001K00R01',
			('＜項目名称:帳票区分＞＜項目値:' || l_inChyohyoKbn || '＞')
		);
		RETURN;
	END IF;

	-- 帳票作成区分をチェック
	nCount := 0;
	SELECT count(*)
	INTO STRICT nCount
	FROM scode
	WHERE code_shubetsu = '716'
	AND code_value = l_inChyohyoSakuKbn;

	-- 帳票作成区分がコードマスタに存在しない場合
	IF nCount = 0 THEN
		l_outSqlCode := pkConstant.ERROR();
		l_outSqlErrM := MSG_PARAM_ERROR;
		CALL pkLog.error(
			'ECM501',
			'IPF001K00R01',
			('＜項目名称:帳票作成区分＞＜項目値:' || l_inChyohyoSakuKbn || '＞')
		);
		RETURN;
	END IF;

	-- 業務日付をチェック
	nRtnCd := pkDate.validateDate(l_inGyoumuDt);
	IF nRtnCd <> 0 THEN
		l_outSqlCode := pkConstant.ERROR();
		l_outSqlErrM := MSG_PARAM_ERROR;
		CALL pkLog.error(
			'ECM501',
			'IPF001K00R01',
			('＜項目名称:業務日付＞＜項目値:' || l_inGyoumuDt || '＞')
		);
		RETURN;
	END IF;

	-- 帳票ワークが既に作成済みかチェックする
	nCount := 0;
	SELECT count(*)
	INTO STRICT nCount
	FROM sreport_wk
	WHERE key_cd = l_inItakuId
	AND user_id = l_inUserId
	AND chohyo_kbn = l_inChyohyoKbn
	AND sakusei_ymd = l_inGyoumuDt
	AND chohyo_id = REPORT_ID;

	-- 帳票ワークが存在しない場合
	IF nCount = 0 THEN
		-- 帳票ワークヘッダ作成
		CALL pkPrint.insertHeader(
			l_inKeyCd      => l_inItakuId,
			l_inUserId     => l_inUserId,
			l_inChohyoKbn  => l_inChyohyoKbn,
			l_inSakuseiYmd => l_inGyoumuDt,
			l_inChohyoId   => REPORT_ID
		);

		-- バッチ帳票印刷管理が作成済みかチェックする
		nCount := 0;
		SELECT count(*)
		INTO STRICT nCount
		FROM PRT_OK
		WHERE itaku_kaisha_cd = l_inItakuId
		AND kijun_ymd = l_inGyoumuDt
		AND list_sakusei_kbn = l_inChyohyoSakuKbn
		AND chohyo_id = REPORT_ID;

		-- バッチ帳票印刷管理が存在しない場合
		IF nCount = 0 THEN
			-- バッチ帳票印刷管理の更新を行う
			INSERT INTO PRT_OK(
				itaku_kaisha_cd,
				kijun_ymd,
				list_sakusei_kbn,
				chohyo_id,
				group_id,
				shori_kbn,
				last_teisei_dt,
				last_teisei_id,
				shonin_dt,
				shonin_id,
				kousin_dt,
				kousin_id,
				sakusei_dt,
				sakusei_id
			)VALUES (
				l_inItakuId,
				l_inGyoumuDt,
				l_inChyohyoSakuKbn,
				REPORT_ID,
				'1',
				'1',
				CURRENT_TIMESTAMP,
				l_inUserId,
				CURRENT_TIMESTAMP,
				l_inUserId,
				CURRENT_TIMESTAMP,
				l_inUserId,
				CURRENT_TIMESTAMP,
				l_inUserId
			);
		END IF;
	END IF;

	-- SEQ_NO取得
	nCount := 0;
	SELECT COUNT(*)
	INTO STRICT nCount 
	FROM SREPORT_WK 
	WHERE key_cd = l_inItakuId
	AND user_id = l_inUserId
	AND chohyo_kbn = l_inChyohyoKbn
	AND sakusei_ymd = l_inGyoumuDt
	AND chohyo_id = REPORT_ID;

	IF nCount = 0 THEN
		nSeq_no := 0;
	ELSE
		SELECT MAX(seq_no)
		INTO STRICT nSeq_no
		FROM sreport_wk
		WHERE key_cd = l_inItakuId
		AND user_id = l_inUserId
		AND chohyo_kbn = l_inChyohyoKbn
		AND sakusei_ymd = l_inGyoumuDt
		AND chohyo_id = REPORT_ID;
	END IF;

	-- 委託会社略称を設定
	nCount := 0;
	SELECT count(*)
	INTO STRICT nCount
	FROM vjiko_itaku
	WHERE kaiin_id = l_inItakuId
	AND jiko_daiko_kbn = '2';

	IF nCount = 0 THEN
		vItakuKaishaRnm := NULL;
	ELSE
		SELECT bank_rnm
		INTO STRICT vItakuKaishaRnm
		FROM vjiko_itaku
		WHERE kaiin_id = l_inItakuId
		AND jiko_daiko_kbn = '2';
	END IF;

	-- データ種別名称を取得する
	nCount := 0;
	SELECT count(*)
	INTO STRICT nCount
	FROM scode
	WHERE code_shubetsu = '191'
	AND code_value = l_inDataId;

	IF nCount = 0 THEN
		vDataNm := NULL;
	ELSE
		SELECT code_nm
		INTO STRICT vDataNm
		FROM scode
		WHERE code_shubetsu = '191'
		AND code_value = l_inDataId;
	END IF;

	-- メッセージ内容を取得する
	nCount := 0;
	SELECT count(*)
	INTO STRICT nCount
	FROM msg_kanri
	WHERE msg_id = l_inMessageId;

	IF nCount = 0 THEN
		vMessage := NULL;
	ELSE
		SELECT msg_nm
		INTO STRICT vMessage
		FROM msg_kanri
		WHERE msg_id = l_inMessageId;
	END IF;

	-- 帳票ワークデータ作成
	-- TYPE_SREPORT_WK_ITEM にパック
	l_inItem.l_inItem001 := l_inItakuId;
	l_inItem.l_inItem002 := vItakuKaishaRnm;
	l_inItem.l_inItem003 := l_inDataId;
	l_inItem.l_inItem004 := vDataNm;
	l_inItem.l_inItem005 := pkCharacter.numeric_to_char(l_inRowNum);
	l_inItem.l_inItem006 := l_inColNm;
	l_inItem.l_inItem007 := l_inSyuroku;
	l_inItem.l_inItem008 := l_inMessageId;
	l_inItem.l_inItem009 := vMessage;
	l_inItem.l_inItem010 := REPORT_ID;
	l_inItem.l_inItem011 := l_inGyoumuDt;
	
	CALL pkPrint.insertData(
		l_inKeyCd      => l_inItakuId,
		l_inUserId     => l_inUserId,
		l_inChohyoKbn  => l_inChyohyoKbn,
		l_inSakuseiYmd => l_inGyoumuDt,
		l_inChohyoId   => REPORT_ID,
		l_inSeqNo      => (nSeq_no + 1),
		l_inHeaderFlg  => '1',
		l_inItem       => l_inItem,
		l_inKousinId   => l_inUserId,
		l_inSakuseiId  => l_inUserId
	);

	l_outSqlCode := pkConstant.SUCCESS();
	l_outSqlErrM := '';
	RETURN;
/*==============================================================================*/
/*                  エラー処理                                                  */
/*==============================================================================*/
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal(
			'ECM701',
			'IPF001K00R01',
			'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')'
		);
		l_outSqlCode := pkConstant.FATAL();
		l_outSqlErrM := SQLERRM || '(' || SQLSTATE || ')';
		RETURN;
END;
$body$
LANGUAGE PLPGSQL;

/*==============================================================================*/
/*                  Nested Function: COMMON_FUNC                               */
/*==============================================================================*/
/**
 * パラメータを基にログファイル出力(共通関数)を呼び出す。
 *
 * @param  l_inwk1  項目値
 * @param  l_inwk2  項目名称振り分け用数値
 * @param  l_outSqlCode  OUT リターン値
 * @param  l_outSqlErrM  OUT エラーコメント
 */
CREATE OR REPLACE FUNCTION spipf001k00r01_common_func(
	l_inwk1        VARCHAR,  -- 項目値
	l_inwk2        NUMERIC,  -- 項目名称振り分け用数値
	OUT o_sqlCode INTEGER,   -- リターン値
	OUT o_sqlErrM TEXT,   -- エラーコメント
	OUT o_result BOOLEAN     -- 結果フラグ
)
AS $nested$
DECLARE
	MSG_PARAM_ERROR CONSTANT VARCHAR(30) := 'パラメーターエラー';
	vKoumokuNm VARCHAR(100);
BEGIN
	-- フラグを初期化
	o_result := FALSE;

	-- NULLチェック
	IF COALESCE(TRIM(l_inwk1), '') = '' THEN
		o_sqlCode := pkConstant.ERROR();
		o_sqlErrM := MSG_PARAM_ERROR;
		o_result := TRUE;
	END IF;

	IF o_result = TRUE THEN
		--項目名称を設定
		CASE l_inwk2
			WHEN 1 THEN
				vKoumokuNm := 'ユーザーＩＤ';
			WHEN 2 THEN
				vKoumokuNm := '帳票区分';
			WHEN 3 THEN
				vKoumokuNm := '帳票作成区分';
			WHEN 4 THEN
				vKoumokuNm := '業務日付';
		END CASE;

		CALL pkLog.error(
			'ECM501',
			'IPF001K00R01',
			('＜項目名称:' || vKoumokuNm || '＞＜項目値:' || l_inwk1 || '＞')
		);
	END IF;
END;
$nested$
LANGUAGE PLPGSQL;
