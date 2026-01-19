




CREATE OR REPLACE PROCEDURE spipf010k01r06 ( l_inItakuId vjiko_itaku.kaiin_id%type , l_inKessaiNo CHAR , l_inToyoKubun CHAR , l_inDATA_SEQ CHAR , l_outSqlCode OUT integer , l_outSqlErrM OUT text ) AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 照合処理PG（共通）
-- * 
-- * @author	yorikane
-- * @version $Revision: 1.6 $
-- * $Id: SPIPF010K01R06.sql,v 1.6 2005/11/10 14:03:49 yamamoto Exp $
-- * @param	l_inItakuId		IN	vjiko_itaku.kaiin_id%type	委託会社コード
-- *          l_inKessaiNo 	IN	CHAR						決済番号
-- *			l_inToyoKubun	IN 	CHAR	 					当預出入区分
-- *			l_inDATA_SEQ	IN 	CHAR	 					データ内連番
-- *			l_outSqlCode	OUT INTEGER	 					リターン値
-- *			l_outSqlErrM	OUT VARCHAR2					エラーコメント
-- * @return INTEGER
-- *				  0:正常終了
-- *				  1:予期したエラー
-- *				 40:データ無し
-- *				 99:予期せぬエラー
-- 
--==============================================================================
--					定数定義													
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
--					変数定義													
--==============================================================================
	cGyoumuDt 		sreport_wk.sakusei_ymd%type;	--業務日付
	nCount			numeric;							--件数取得
	cPara			char(1);						--パラメータ
	cPara2			char(2);						--パラメータ
	vTsuchiNaiyo	varchar(200);					--通知内容
	nRet			numeric;							--リターン値
--==============================================================================
--					メイン処理													
--==============================================================================
BEGIN
	--入力パラメータのチェック（委託会社コード）
	IF coalesce(trim(both l_inItakuId)::text, '') = '' THEN
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := MSG_PARAM_ERROR;
		CALL pkLog.error('ECM501', 'IPF010K01R06', '＜項目名称:委託会社コード＞' || '＜項目値:' || l_inItakuId || '＞');
		RETURN;
	END IF;
	--入力パラメータのチェック（決済番号）
	IF coalesce(trim(both l_inKessaiNo)::text, '') = '' THEN
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := MSG_PARAM_ERROR;
		CALL pkLog.error('ECM501', 'IPF010K01R06', '＜項目名称:決済番号＞' || '＜項目値:' || l_inKessaiNo || '＞');
		RETURN;
	END IF;
	--入力パラメータのチェック（当預出入区分）
	IF coalesce(trim(both l_inToyoKubun)::text, '') = '' THEN
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := MSG_PARAM_ERROR;
		CALL pkLog.error('ECM501', 'IPF010K01R06', '＜項目名称:当預出入区分＞' || '＜項目値:' || l_inToyoKubun || '＞');
		RETURN;
	END IF;
	--入力パラメータのチェック（データ内連番）
	IF coalesce(trim(both l_inDATA_SEQ)::text, '') = '' THEN
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := MSG_PARAM_ERROR;
		CALL pkLog.error('ECM501', 'IPF010K01R06', '＜項目名称:データ内連番＞' || '＜項目値:' || l_inDATA_SEQ || '＞');
		RETURN;
	END IF;
	--業務日付を取得
	cGyoumuDt := pkDate.getGyomuYmd();
	--該当する決済番号が当預テーブル（送信用）に存在するかチェック
	SELECT COUNT(*) INTO STRICT nCount
	FROM toyosend 
	WHERE itaku_kaisha_cd = l_inItakuId
	AND kessai_no = l_inKessaiNo
	AND data_shori_kbn = '1';
	--存在する場合
	IF nCount > 0 THEN
		--入出金区分値の切り替え
		IF l_inToyoKubun = '01' THEN
			cPara := '4';
		ELSIF l_inToyoKubun = '02' THEN
			cPara := '2';
		END IF;
		--当預テーブル（送信用）更新
		UPDATE toyosend
		SET nyushukin_joukyou = cPara 
		WHERE itaku_kaisha_cd = l_inItakuId
		AND kessai_no = l_inKessaiNo
		AND data_shori_kbn = '1';
		--当預テーブル（受信用）更新
		UPDATE toyorcv
		SET nyushukin_joukyou = cPara 
		WHERE itaku_kaisha_cd = l_inItakuId
		AND kessai_no = l_inKessaiNo
		AND data_shori_kbn = '1';
		--リターン値を設定
		l_outSqlCode := pkconstant.success();
		l_outSqlErrM := '';
	--存在しない場合
	ELSE
		--当預テーブル（受信用）更新
		UPDATE toyorcv
		SET nyushukin_joukyou = '0'
		WHERE itaku_kaisha_cd = l_inItakuId
		AND kessai_no = l_inKessaiNo
		AND data_shori_kbn = '1';
		--当預出入区分により「通知内容」「データ種別」「」の値を切り分ける
		IF l_inToyoKubun = '01' THEN
			vTsuchiNaiyo := '＜支払結果＞＜決済番号：' || l_inKessaiNo || '＞';
			cPara2 := '52';
		ELSIF l_inToyoKubun = '02' THEN
			vTsuchiNaiyo := '＜当座勘定入金＞＜決済番号：' || l_inKessaiNo || '＞';
			cPara2 := '51';
		END IF;
		--ログ出力
		CALL pkLog.error('ECM503', 'IPF010K01R06', vTsuchiNaiyo);
		--エラーリスト書き込み
		CALL SPIPF001K00R01(
			l_inItakuId,
			'BATCH', 
			'1', 
			'3', 
			cGyoumuDt, 
			cPara2, 
			l_inDATA_SEQ::NUMERIC, 
			'決済番号', 
			l_inKessaiNo, 
			'ECM503', 
			l_outSqlCode, 
			l_outSqlErrM
		);
		--メッセージ通知テーブルへ書き込み
		nRet := SfIpMsgTsuchiUpdate(l_inItakuId, 'RTGS','重要','1','0','該当の決済番号は存在しません。' || vTsuchiNaiyo,'BATCH','BATCH');
		IF nRet != 0 THEN
			l_outSqlCode := nRet;
			l_outSqlErrM := 'メッセージ通知登録エラー';
			CALL pkLog.fatal('ECM701', 'IPF010K01R06', 'メッセージ通知登録エラー');
			RETURN;
		END IF;
		--リターン値を設定
		l_outSqlCode := pkconstant.no_data_find();
		l_outSqlErrM := MSG_NO_DATA;
	END IF;
	--リターン
	RETURN;
--==============================================================================
--					エラー処理													
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'IPF010K01R06', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		l_outSqlCode := pkconstant.fatal();
		l_outSqlErrM := SQLERRM || '(' || SQLSTATE || ')';
		RETURN;
--		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipf010k01r06 ( l_inItakuId vjiko_itaku.kaiin_id%type , l_inKessaiNo CHAR , l_inToyoKubun CHAR , l_inDATA_SEQ CHAR , l_outSqlCode OUT integer , l_outSqlErrM OUT text ) FROM PUBLIC;
