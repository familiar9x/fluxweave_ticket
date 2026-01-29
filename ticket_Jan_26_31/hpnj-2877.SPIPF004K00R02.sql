




CREATE OR REPLACE PROCEDURE spipf004k00r02 ( l_inItakuId vjiko_itaku.kaiin_id%type,					 -- 委託者コード
 l_inDataId scode.code_value%type,						 -- データ種別
 l_outSqlCode OUT integer,									 -- リターン値
 l_outSqlErrM OUT text				     				 -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * カレンダ情報（Ｓ個別）を基にカレンダーマスタ（移行用）を作成する
-- * 
-- * @author 小林　弘幸
-- * @version $Revision: 1.5 $
-- * 
-- * @param l_inItakuId  IN VARCHAR2  委託会社コード
-- *        l_inDataId   IN VARCHAR2  データ種別
-- *        l_outSqlCode IN INTEGER   リターン値
-- *        l_outSqlErrM IN VARCHAR2  エラーコメント
-- * @return INTEGER
-- *                0:正常終了
-- *                1:予期したエラー
-- *               40:データ無し
-- *               99:予期せぬエラー
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
--                  変数定義                                                    
--==============================================================================
	iCnt      integer;										-- ループカウンタ
	nRet      numeric;										-- 戻り値
	nCount    numeric;										-- レコード数
	cTemp     char(1);										-- 日付フラグ一時格納用
	cFlg      char(1);										-- エラーフラグ
	cDate     mcalendar.holiday%type;						-- 休日格納用
	cGyoumuDt sreport_wk.sakusei_ymd%type;					-- 業務日付格納用
--==============================================================================
--                  カーソル定義                                                
--==============================================================================
	curCalender CURSOR FOR
			SELECT
				area_cd,
				ad_yyyy,
				mm,
				dd_flg,
				lin_no
			FROM
				calender_s
			ORDER BY
				ad_yyyy,
				mm;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 業務日付を取得
	cGyoumuDt := pkDate.getGyomuYmd();
	-- 入力パラメータのチェック 委託会社コード
	IF coalesce(trim(both l_inItakuId)::text, '') = '' THEN
		l_outSqlCode := pkconstant.error();
	 	l_outSqlErrM := MSG_PARAM_ERROR;
		CALL pkLog.error(
			'ECM501',
			'IPF004K00R02',
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
			'IPF004K00R02',
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
	-- 委託会社コードが自行・委託会社マスタviewに存在しない場合
	IF nCount = 0 THEN
		l_outSqlCode := pkconstant.error();
	 	l_outSqlErrM := MSG_PARAM_ERROR;
		CALL pkLog.error(
			'ECM501',
			'IPF004K00R02',
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
			'IPF004K00R02',
			'＜項目名称:データ種別＞＜項目値:' || l_inDataId || '＞'
		);
		RETURN;
	END IF;
	-- 帳票ワーク削除
	DELETE FROM SREPORT_WK
	WHERE KEY_CD = l_inItakuId
	AND USER_ID = 'BATCH'
	AND CHOHYO_KBN = '1'
	AND SAKUSEI_YMD = cGyoumuDt
	AND CHOHYO_ID = 'IPF30000111'
	AND ITEM003 = l_inDataId;
	-- カレンダ情報(移行用)の件数をチェック
	nCount := 0;
	SELECT count(*)
	INTO STRICT nCount
	FROM mcalender_trns;
	-- カレンダ情報(移行用)の件数が０件でない場合、データを削除する
	IF nCount != 0 THEN
		DELETE FROM mcalender_trns;
	END IF;
	-- カレンダ情報(Ｓ個別)の件数をチェック
	nCount := 0;
	SELECT count(*)
	INTO STRICT nCount
	FROM calender_s;
	-- カレンダ情報(Ｓ個別)の件数が０件の場合、データ無しエラーリターン値(40)を返す
	IF nCount = 0 THEN
		l_outSqlCode := pkconstant.NO_DATA_FIND();
	 	l_outSqlErrM := MSG_NO_DATA;
		CALL pkLog.error(
			'EIP505',
			'IPF004K00R02',
			MSG_NO_DATA
		);
		RETURN;
	END IF;
	-- エラーフラグを初期化
	cFlg := '0';
	-- チェック、更新処理
	FOR recCalender IN curCalender LOOP
		--地域コード コード値チェック
		nRet := sfCmIsCodeMChek('715', recCalender.area_cd);
		IF nRet = 0 THEN
			FOR iCnt IN 1 .. 31 LOOP
				cTemp := SUBSTR(recCalender.dd_flg, iCnt, 1);
				-- '1'の場合、カレンダマスタ(移行用)の更新を行う
				IF cTemp = '1' THEN
					-- 日付が１桁の場合は'0'を付加
					IF LENGTH(iCnt::text) = 1 THEN
						cDate := recCalender.AD_YYYY || recCalender.MM || '0' || iCnt::text;
					ELSE
						cDate := recCalender.AD_YYYY || recCalender.MM || iCnt::text;
					END IF;
					-- カレンダマスタ(移行用)テーブルに挿入
					INSERT INTO mcalender_trns(
						area_cd,
						holiday,
						lin_no
					)
					VALUES (
						recCalender.area_cd,
						cDate,
						recCalender.lin_no
					);
				-- '0'またはスペース以外の場合、エラーリスト作成spをCall
				ELSIF (cTemp != '0' AND cTemp != ' ') THEN
					CALL SPIPF001K00R01(
						l_inItakuId,
						'BATCH',
						'1',
						'3',
						cGyoumuDt,
						l_inDataId,
						recCalender.lin_no,
						'日付フラグ',
						recCalender.dd_flg,
						'ECM502',
						l_outSqlCode,
						l_outSqlErrM
					);
					-- エラーフラグに'1'を設定
					cFlg := '1';
				END IF;
			END LOOP;
		-- 地域コード エラー処理
		ELSE
			CALL SPIPF001K00R01(
				l_inItakuId,
				'BATCH',
				'1',
				'3',
				cGyoumuDt,
				l_inDataId,
				recCalender.lin_no,
				'地域コード',
				recCalender.area_cd,
				MSGID_CHECK_CODE,
				l_outSqlCode,
				l_outSqlErrM
			);
			-- エラーフラグに'1'を設定
			cFlg := '1';
		END IF;
	END LOOP;
	-- エラーフラグが'1'の場合、リターン値に'1'を設定
	IF cFlg = '1' THEN
		l_outSqlCode := pkconstant.error();
	 	l_outSqlErrM := MSG_DATA_ERROR;
		CALL pkLog.error(
			'ECM502',
			'IPF004K00R02',
			MSG_DATA_ERROR
		);
		RETURN;
	END IF;
	l_outSqlCode := pkconstant.success();
	l_outSqlErrM := '';
	RETURN;
--==============================================================================
--                  エラー処理                                                  
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		-- ログ出力
		CALL pkLog.fatal(
			'ECM701',
			'IPF004K00R02',
			'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')'
		);
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLERRM || '(' || SQLSTATE || ')';
		RETURN;
--		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipf004k00r02 ( l_inItakuId vjiko_itaku.kaiin_id%type, l_inDataId scode.code_value%type, l_outSqlCode OUT integer, l_outSqlErrM OUT text ) FROM PUBLIC;
