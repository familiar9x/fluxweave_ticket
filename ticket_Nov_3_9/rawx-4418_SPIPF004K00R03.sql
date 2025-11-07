CREATE OR REPLACE PROCEDURE spipf004k00r03 (
	l_inItakuId text,					 -- 委託者コード
	l_inDataId text,						 -- データ種別
	l_outSqlCode OUT integer,									 -- リターン値
	l_outSqlErrM OUT text				     				 -- エラーコメント
) AS $body$
DECLARE

/**
 * 著作権: Copyright (c) 2005
 * 会社名: JIP
 *
 * カレンダー作成情報を基にカレンダーマスタを作成する
 * 
 * @author 小林　弘幸
 * @version $Revision: 1.8 $
 * 
 * @param l_inItakuId  IN VARCHAR2  委託会社コード
 *        l_inDataId   IN VARCHAR2  データ種別
 *        l_outSqlCode IN INTEGER   リターン値
 *        l_outSqlErrM IN VARCHAR2  エラーコメント
 * @return INTEGER
 *                0:正常終了
 *                1:予期したエラー
 *                40:データ無し
 *                99:予期せぬエラー
 */
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
--                  変数定義                                                    
--==============================================================================
	iRet      integer;											 -- 戻り値
	nCount    numeric;											 -- レコード数
	cFlg      char(1);											 -- エラーフラグ
	cGyoumuDt sreport_wk.sakusei_ymd%type;						 -- 業務日付格納用
--==============================================================================
--                  カーソル定義                                                
--==============================================================================
	curCalender CURSOR FOR
			SELECT
				area_cd,
				holiday,
				lin_no
			FROM
				mcalender_trns
			ORDER BY
				area_cd,
				holiday;
	curAreacd CURSOR FOR
			SELECT
				distinct area_cd
			FROM
				mcalender_trns
			ORDER BY
				area_cd;
	curMCalendar CURSOR FOR
		SELECT
			AREA_CD,
			HOLIDAY
		FROM
			MCALENDAR
		ORDER BY
			AREA_CD,
			HOLIDAY;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- カレンダー訂正履歴チェック
	nCount := 0;
	SELECT
		COUNT(*)
	INTO STRICT
		nCount
	FROM MCALENDAR_TEISEI
	WHERE
		ITAKU_KAISHA_CD = l_inItakuId
		AND MGR_KJT_CHOSEI_KBN = '3';
	-- 「承認済み:3」が存在する場合
	IF nCount <> 0 THEN
		l_outSqlCode := pkconstant.success();
		l_outSqlErrM := '';
--		pkLog.debug(pkconstant.BATCH_USER(), 'SPIPF004K00R03', 'カレンダー訂正履歴に承認済みデータ存在の為、終了');
		RETURN;
	END IF;
	-- 業務日付を取得
	cGyoumuDt := pkDate.getGyomuYmd();
	-- 入力パラメータのチェック 委託会社コード
	IF coalesce(trim(both l_inItakuId)::text, '') = '' THEN
		l_outSqlCode := pkconstant.error();
	 	l_outSqlErrM := MSG_PARAM_ERROR;
		CALL pkLog.error(
			'ECM501',
			'IPF004K00R03',
			'＜項目名称:委託会社コード＞＜項目値:' || l_inItakuId || '＞'
		);
		RETURN;
	END IF;
	-- 入力パラメータのチェック データ種別
	IF coalesce(trim(both l_inDataId)::text, '') = '' THEN
		l_outSqlCode := pkconstant.error();
	 	l_outSqlErrM := MSG_PARAM_ERROR;
		CALL pkLog.error(
			'ECM501',
			'IPF004K00R03',
			'＜項目名称:データ種別＞＜項目値:' || l_inDataId || '＞'
		);
		RETURN;
	END IF;
	-- 委託会社コードをチェック
	nCount := 0;
	SELECT count(*)
	INTO STRICT nCount
	FROM vjiko_itaku
	WHERE kaiin_id = l_inItakuId;
	-- 委託会社コードが委託会社マスタに存在しない場合
	IF nCount = 0 THEN
		l_outSqlCode := pkconstant.error();
	 	l_outSqlErrM := MSG_PARAM_ERROR;
		CALL pkLog.error(
			'ECM501',
			'IPF004K00R03',
			'＜項目名称:委託会社コード＞＜項目値:' || l_inItakuId || '＞'
		);
		RETURN;
	END IF;
	-- データ種別をチェック
	nCount := 0;
	SELECT count(*)
	INTO STRICT nCount
	FROM scode
	WHERE code_shubetsu = '191'
	AND code_value = l_inDataId;
	-- データ種別がコードマスタに存在しない場合
	IF nCount = 0 THEN
		l_outSqlCode := pkconstant.error();
	 	l_outSqlErrM := MSG_PARAM_ERROR;
		CALL pkLog.error(
			'ECM501',
			'IPF004K00R03',
			'＜項目名称:データ種別＞＜項目値:' || l_inDataId || '＞'
		);
		RETURN;
	END IF;
	-- 帳票ワーク削除
	DELETE FROM sreport_wk
	WHERE key_cd = l_inItakuId
	AND user_id = 'BATCH'
	AND chohyo_kbn = '1'
	AND sakusei_ymd = cGyoumuDt
	AND chohyo_id = 'IPF30000111'
	AND item003 = l_inDataId;
	-- カレンダマスタ(移行用)の件数をチェック
	nCount := 0;
	SELECT count(*)
	INTO STRICT nCount
	FROM mcalender_trns;
	-- カレンダマスタ(移行用)の件数が０件の場合、データ無しエラーリターン値(40)を返す
	IF nCount = 0 THEN
		l_outSqlCode := pkconstant.NO_DATA_FIND();
	 	l_outSqlErrM := MSG_NO_DATA;
		CALL pkLog.error(
			'EIP505',
			'IPF004K00R03',
			MSG_NO_DATA
		);
		RETURN;
	END IF;
	-- カレンダマスタの件数をチェック
	nCount := 0;
	SELECT count(*)
	INTO STRICT nCount
	FROM mcalendar;
	-- カレンダマスタの件数が０件でない場合、データを削除する
	IF nCount != 0 THEN
		-- バックアップ用テーブルを空にする
		DELETE FROM mcalendar_bk;
		-- 全件バックアップ
		INSERT INTO mcalendar_bk(
			area_cd,
			holiday,
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
			area_cd,
			holiday,
			shori_kbn,
			last_teisei_dt,
			last_teisei_id,
			shonin_dt,
			shonin_id,
			kousin_dt,
			kousin_id,
			sakusei_dt, sakusei_id
		FROM mcalendar;
		-- カレンダマスタ(移行用)に存在する地域コードのデータのみ削除
		For recAreacd IN curAreacd LOOP
			DELETE FROM mcalendar
			WHERE area_cd = recAreacd.area_cd;
	 	END LOOP;
	END IF;
	-- エラーフラグを初期化
	cFlg := '0';
	-- チェック、更新処理
	FOR recCalender IN curCalender LOOP
		-- 日付チェック
		IF LENGTH(trim(both recCalender.holiday)) = 8 THEN
			iRet := pkDate.validateDate(recCalender.holiday);
		ELSE
			iRet := 1;
		END IF;
		-- 正常処理フラグが'0'の場合
		IF iRet = 0 THEN
			-- エラーフラグが'0'の場合、カレンダマスタへ書き込み
			INSERT INTO mcalendar(
				area_cd,
				holiday,
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
				recCalender.area_cd,
				recCalender.holiday,
				'1',
				current_timestamp,
				'BATCH',
				current_timestamp,
				'BATCH',
				current_timestamp,
				'BATCH',
				current_timestamp,
				'BATCH'
			);
		-- エラーフラグが'1'の場合、帳票ワークへ書き込み
		ELSIF iRet = 1 THEN
			CALL SPIPF001K00R01(
				l_inItakuId,
				'BATCH',
				'1',
				'3',
				cGyoumuDt,
				l_inDataId,
				recCalender.lin_no,
				'休日',
				recCalender.holiday,
				MSGID_CHECK_HIDUKE,
				l_outSqlCode,
				l_outSqlErrM
			);
			-- エラーフラグに'1'を設定
			cFlg := '1';
		END IF;
	END LOOP;
	-- エラーフラグが'1'の場合、カレンダマスタを更新前の状態に戻し、リターン値に'1'を設定
	IF cFlg = '1' THEN
		DELETE FROM mcalendar;
		INSERT INTO mcalendar(
			area_cd,
			holiday,
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
			area_cd,
			holiday,
			shori_kbn,
			last_teisei_dt,
			last_teisei_id,
			shonin_dt,
			shonin_id,
			kousin_dt,
			kousin_id,
			sakusei_dt,
			sakusei_id
		FROM mcalendar_bk;
		l_outSqlCode := pkconstant.error();
	 	l_outSqlErrM := MSG_DATA_ERROR;
		CALL pkLog.error(
			'ECM502',
			'IPF004K00R03',
			MSG_DATA_ERROR
		);
		RETURN;
	ELSE
		FOR recMCalendar IN curMCalendar
		LOOP
			-- カレンダー訂正履歴の件数をチェック
			nCount := 0;
			SELECT
				COUNT(*)
			INTO STRICT
				nCount
			FROM MCALENDAR_TEISEI
			WHERE
				ITAKU_KAISHA_CD = l_inItakuId
				AND AREA_CD = recMCalendar.AREA_CD
				AND CALENDAR_YMD = recMCalendar.HOLIDAY;
			-- カレンダー訂正履歴に存在しない場合、登録する
			IF nCount = 0 THEN
				INSERT INTO MCALENDAR_TEISEI(
					ITAKU_KAISHA_CD,
					AREA_CD,
					CALENDAR_YMD,
					CALENDAR_HENKO_KBN,
					MGR_KJT_CHOSEI_KBN,
					LAST_TEISEI_DT,
					LAST_TEISEI_ID,
					KOUSIN_ID,
					SAKUSEI_ID
				) VALUES (
					l_inItakuId,
					recMCalendar.AREA_CD,
					recMCalendar.HOLIDAY,
					'1',
					'1',
					to_timestamp(pkDate.getCurrentTime(), 'YYYY-MM-DD HH24:MI:SS.US'),
					'BATCH',
					'BATCH',
					'BATCH'
				);
			END IF;
		END LOOP;
		UPDATE SSYSTEM_MANAGEMENT SET
			EIGYOBI_HOSEI_FLG = '1';
	END IF;
	l_outSqlCode := pkconstant.success();
	l_outSqlErrM := '';
	RETURN;
--==============================================================================
--                  エラー処理                                                  
--==============================================================================
EXCEPTION
	-- その他のエラー
	WHEN OTHERS THEN
		CALL pkLog.fatal(
			'ECM701',
			'IPF004K00R03',
			'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')'
		);
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLERRM || '(' || SQLSTATE || ')';
		RETURN;
END;
$body$
LANGUAGE PLPGSQL;
