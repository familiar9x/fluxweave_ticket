




CREATE OR REPLACE PROCEDURE spipf003k00r02 ( l_inDataId scode.code_value%type, l_outSqlCode OUT numeric , l_outSqlErrM OUT text ) AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * コンバート  部店マスタ（移行）→ 部店マスタ
-- * 
-- * @author	yorikane
-- * @version $Revision: 1.6 $
-- * 
-- * @param	l_inDataId		IN VARCHAR		データ種別
-- *			l_outSqlCode	OUT INTEGER 	リターン値
-- *			l_outSqlErrM	OUT VARCHAR	エラーコメント
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
	MSGID_CHECK_HIKIOTOSHI		CONSTANT varchar(6)	:= 'ECM001'	;	--引落しチェックエラー
	MSGID_CHECK_KETASU			CONSTANT varchar(6)	:= 'ECM012'	;	--桁数チェックエラー
	MSGID_CHECK_HANKAKU			CONSTANT varchar(6)	:= 'ECM010'	;	--半角チェックエラー
	MSGID_CHECK_TELNO			CONSTANT varchar(6)	:= 'ECM079'	;	--電話番号エラー
	MSG_PARAM_ERROR CONSTANT varchar(30)   := 'パラメーターエラー';
	MSG_NO_DATA     CONSTANT varchar(30)   := 'データ無しエラー';
	MSG_DATA_ERROR  CONSTANT varchar(30)   := 'データエラー';
	MSG_COMMON_ERR	CONSTANT varchar(30)	:= '共通関数エラー'		;
--==============================================================================
--					変数定義													
--==============================================================================
	cGyoumuDt 		sreport_wk.sakusei_ymd%type;	--業務日付
	nCount			numeric;							--件数取得
	nCheckCounter	numeric;							--ループカウンター
	nRet			numeric;							--関数戻り値
	cFlg			char(1);						--更新フラグ
	cMsgId			varchar(6);					--メッセージID
	sErrorField		varchar(100);					--エラーが発生したフィールド名
	sErrorValue 	varchar(100);					--エラーが発生した値
	cItakuId		char(4);						--委託会社コード
--==============================================================================
--					カーソル定義												
--==============================================================================
	curButen_Trns CURSOR FOR
		SELECT 
			itaku_kaisha_cd,
			buten_cd,
			buten_nm,
			buten_rnm,
			group_cd,
			post_no,
			add1,
			add2,
			add3,
			busho_nm,
			tel_no,
			fax_no,
			mail_add,
			lin_no
		FROM mbuten_trns
		ORDER BY
			itaku_kaisha_cd,
			buten_cd;
--==============================================================================
--					メイン処理													
--==============================================================================
BEGIN
	-- 入力パラメータのチェック データ種別
	IF coalesce(trim(both l_inDataId)::text, '') = '' THEN
		l_outSqlCode := pkconstant.error();
	 	l_outSqlErrM := MSG_PARAM_ERROR;
		CALL pkLog.error(
			'ECM501',
			'IPF003K00R02',
			'＜項目名称：データ種別><項目値：' || l_inDataId || '＞'
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
			'IPF003K00R02',
			'＜項目名称：データ種別＞＜項目値：' || l_inDataId || '＞'
		);
		RETURN;
	END IF;
	--部店マスタ(移行用)の件数をチェック
	nCount := 0;
	SELECT count(*)
	INTO STRICT nCount
	FROM mbuten_trns;
	--部店マスタ(移行用)の件数が０件の場合
	IF nCount = 0 THEN
		l_outSqlCode := pkconstant.NO_DATA_FIND();
	 	l_outSqlErrM := MSG_NO_DATA;
		CALL pkLog.error('EIP505', 'IPF003K00R02', MSG_NO_DATA);
		RETURN;
	END IF;
	--委託会社コードを取得
	SELECT DISTINCT itaku_kaisha_cd
	INTO STRICT cItakuId
	FROM mbuten_trns;
	--業務日付を取得
	cGyoumuDt := pkDate.getGyomuYmd;
	--帳票ワーク削除
	DELETE FROM sreport_wk
	WHERE key_cd = cItakuId
	AND user_id = 'BATCH'
	AND chohyo_kbn = '1'
	AND sakusei_ymd = cGyoumuDt
	AND chohyo_id = 'IPF30000111'
	AND item003 = l_inDataId;
	--部店マスタの件数をチェック
	nCount := 0;
	SELECT COUNT(*) INTO STRICT nCount FROM mbuten;
	--部店マスタの件数が０件でない場合、データのバックアップを取得し、データを削除する
	IF nCount != 0 THEN
		--一時テーブル削除
		DELETE FROM mbuten_bk;
		--バックアップ
		INSERT INTO mbuten_bk(
			itaku_kaisha_cd,
			buten_cd,
			buten_nm,
			buten_rnm,
			group_cd,
			post_no,
			add1,
			add2,
			add3,
			busho_nm,
			tel_no,
			fax_no,
			mail_add,
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
			itaku_kaisha_cd,
			buten_cd,
			buten_nm,
			buten_rnm,
			group_cd,
			post_no,
			add1,
			add2,
			add3,
			busho_nm,
			tel_no,
			fax_no,
			mail_add,
			shori_kbn,
			last_teisei_dt,
			last_teisei_id,
			shonin_dt,
			shonin_id,
			kousin_dt,
			kousin_id,
			sakusei_dt,
			sakusei_id
		FROM mbuten;
		--データ削除
		DELETE FROM mbuten WHERE ITAKU_KAISHA_CD = cItakuId;
	END IF;
	--エラーフラグ初期化
	cFlg := '0';
	--部店マスタ（移行）からデータを取得
	FOR recButen_Trns IN curButen_Trns LOOP
		--共通関数によるデータチェック
		FOR nCheckCounter IN 1..12 LOOP
			--変数初期化
			nRet := 0;
			sErrorField := '';
			sErrorValue := '';
			--部店コード 半角英数チェック
			IF nCheckCounter = 1 THEN
				sErrorField := '部店コード';
				sErrorValue := recButen_Trns.buten_cd;
				IF LENGTH(trim(both recButen_Trns.buten_cd)) = 4 THEN
					nRet := sfCmIsHalfAlphanumeric2(trim(both recButen_Trns.buten_cd));
					cMsgId := MSGID_CHECK_HANKAKU_EISU;
				ELSE
					nRet := 1;
					cMsgId := MSGID_CHECK_KETASU;
				END IF;
			--部店名称 全角チェック
			ELSIF  nCheckCounter = 2 THEN
				sErrorField := '部店名称';
				sErrorValue := recButen_Trns.buten_nm;
				IF LENGTH(trim(both recButen_Trns.buten_nm)) > 0 THEN
					nRet := sfCmIsFullsizeChar(trim(both recButen_Trns.buten_nm));
					cMsgId := MSGID_CHECK_ZENKAKU;
				ELSE
					nRet := 1;
					cMsgId := MSGID_CHECK_HIKIOTOSHI;
				END IF;
			--部店略称 全角チェック
			ELSIF  nCheckCounter = 3 THEN
				sErrorField := '部店略称';
				sErrorValue := recButen_Trns.buten_rnm;
				IF LENGTH(trim(both recButen_Trns.buten_rnm)) > 0 THEN
					nRet := sfCmIsFullsizeChar(trim(both recButen_Trns.buten_rnm));
					cMsgId := MSGID_CHECK_ZENKAKU;
				ELSE
					nRet := 1;
					cMsgId := MSGID_CHECK_HIKIOTOSHI;
				END IF;
			--グループコード 半角英数チェック
			ELSIF  nCheckCounter = 4 THEN
				IF (trim(both recButen_Trns.group_cd) IS NOT NULL AND (trim(both recButen_Trns.group_cd))::text <> '') THEN
					sErrorField := 'グループコード';
					sErrorValue := recButen_Trns.group_cd;
					IF LENGTH(trim(both recButen_Trns.group_cd)) = 4 THEN
						nRet := sfCmIsHalfAlphanumeric2(trim(both recButen_Trns.group_cd));
						cMsgId := MSGID_CHECK_HANKAKU_EISU;
					ELSE
						nRet := 1;
						cMsgId := MSGID_CHECK_KETASU;
					END IF;
				END IF;
			--郵便番号 数値チェック
			ELSIF  nCheckCounter = 5 THEN
				IF (trim(both recButen_Trns.post_no) IS NOT NULL AND (trim(both recButen_Trns.post_no))::text <> '') THEN
					sErrorField := '郵便番号';
					sErrorValue := recButen_Trns.post_no;
					IF LENGTH(trim(both recButen_Trns.post_no)) = 7 THEN
						nRet := sfCmIsNumeric(trim(both recButen_Trns.post_no));
						cMsgId := MSGID_CHECK_NUMBER;
					else
						nRet := 1;
						cMsgId := MSGID_CHECK_KETASU;
					END IF;
				END IF;
			--住所１ 全角チェック
			ELSIF  nCheckCounter = 6 THEN
				nRet := sfCmIsFullsizeChar(trim(both recButen_Trns.add1));
				cMsgId := MSGID_CHECK_ZENKAKU;
				sErrorField := '住所１';
				sErrorValue := recButen_Trns.add1;
			--住所２ 全角チェック
			ELSIF  nCheckCounter = 7 THEN
				nRet := sfCmIsFullsizeChar(trim(both recButen_Trns.add2));
				cMsgId := MSGID_CHECK_ZENKAKU;
				sErrorField := '住所２';
				sErrorValue := recButen_Trns.add2;
			--住所３ 全角チェック
			ELSIF  nCheckCounter = 8 THEN
				nRet := sfCmIsFullsizeChar(trim(both recButen_Trns.add3));
				cMsgId := MSGID_CHECK_ZENKAKU;
				sErrorField := '住所３';
				sErrorValue := recButen_Trns.add3;
			--担当部署名称 全角チェック
			ELSIF  nCheckCounter = 9 THEN
				nRet := sfCmIsFullsizeChar(trim(both recButen_Trns.busho_nm));
				cMsgId := MSGID_CHECK_ZENKAKU;
				sErrorField := '担当部署名称';
				sErrorValue := recButen_Trns.busho_nm;
			--電話番号 電話番号エラーチェック
			ELSIF  nCheckCounter = 10 THEN
				nRet := sfCmIsTelNoCheck(trim(both recButen_Trns.tel_no));
				cMsgId := MSGID_CHECK_TELNO;
				sErrorField := '電話番号';
				sErrorValue := recButen_Trns.tel_no;
			--FAX番号 電話番号エラーチェック
			ELSIF  nCheckCounter = 11 THEN
				nRet := sfCmIsTelNoCheck(trim(both recButen_Trns.fax_no));
				cMsgId := MSGID_CHECK_TELNO;
				sErrorField := 'FAX番号';
				sErrorValue := recButen_Trns.fax_no;
			--メールアドレス 半角チェック
			ELSIF  nCheckCounter = 12 THEN
				nRet := sfCmIsHalfsizeChar(trim(both recButen_Trns.mail_add));
				cMsgId := MSGID_CHECK_HANKAKU;
				sErrorField := 'メールアドレス';
				sErrorValue := recButen_Trns.mail_add;
			EnD IF;
			--共通関数内でチェックに引っかかった場合
			IF nRet = 1 THEN
				--エラーリスト書き込み
				CALL SPIPF001K00R01(
					cItakuId,
					'BATCH', 
					'1', 
					'3', 
					cGyoumuDt, 
					l_inDataId,
					recButen_Trns.lin_no, 
					sErrorField, 
					sErrorValue, 
					cMsgId, 
					l_outSqlCode, 
					l_outSqlErrM
				);
				cFlg := '1';
			END IF;
		END LOOP;
		--１レコード全てのチェックに引っかからなかった場合
		IF cFlg = '0' THEN
			--部店マスタ更新
			INSERT INTO mbuten(
				itaku_kaisha_cd,
				buten_cd,
				buten_nm,
				buten_rnm,
				group_cd,
				post_no,
				add1,
				add2,
				add3,
				busho_nm,
				tel_no,
				fax_no,
				mail_add,
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
				recButen_Trns.itaku_kaisha_cd,
				recButen_Trns.buten_cd,
				recButen_Trns.buten_nm,
				recButen_Trns.buten_rnm,
				recButen_Trns.group_cd,
				recButen_Trns.post_no,
				recButen_Trns.add1,
				recButen_Trns.add2,
				recButen_Trns.add3,
				recButen_Trns.busho_nm,
				recButen_Trns.tel_no,
				recButen_Trns.fax_no,
				recButen_Trns.mail_add,
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
	IF cFlg = '1' THEN
		DELETE FROM mbuten;
		INSERT INTO mbuten(
			itaku_kaisha_cd,
			buten_cd,
			buten_nm,
			buten_rnm,
			group_cd,
			post_no,
			add1,
			add2,
			add3,
			busho_nm,
			tel_no,
			fax_no,
			mail_add,
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
			itaku_kaisha_cd,
			buten_cd,
			buten_nm,
			buten_rnm,
			group_cd,
			post_no,
			add1,
			add2,
			add3,
			busho_nm,
			tel_no,
			fax_no,
			mail_add,
			shori_kbn,
			last_teisei_dt,
			last_teisei_id,
			shonin_dt,
			shonin_id,
			kousin_dt,
			kousin_id,
			sakusei_dt,
			sakusei_id
		FROM mbuten_bk;
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := MSG_DATA_ERROR;
		CALL pkLog.error('ECM502', 'IPF003K00R02', MSG_DATA_ERROR);
	ELSE
		l_outSqlCode := pkconstant.success();
		l_outSqlErrM := '';
	END IF;
	RETURN;
--==============================================================================
--					エラー処理													
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'IPF003K00R02', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLERRM || '(' || SQLSTATE || ')';
		RETURN;
--		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipf003k00r02 ( l_inDataId scode.code_value%type, l_outSqlCode OUT numeric , l_outSqlErrM OUT text ) FROM PUBLIC;