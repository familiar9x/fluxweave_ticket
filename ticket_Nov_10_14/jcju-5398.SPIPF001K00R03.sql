




CREATE OR REPLACE PROCEDURE spipf001k00r03 ( l_inDataId scode.code_value%type , l_outSqlCode OUT integer , l_outSqlErrM OUT text ) AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * コンバート  発行体情報マスタ（移行）→ 発行体情報マスタ
-- * 
-- * @author	yorikane
-- * @version $Revision: 1.11 $
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
	MSGID_CHECK_KETASU			CONSTANT varchar(6)	:= 'ECM012'	;	--桁数チェックエラー
	MSGID_CHECK_HANKAKU			CONSTANT varchar(6)	:= 'ECM010'	;	--半角チェックエラー
	MSGID_CHECK_HIDUKE			CONSTANT varchar(6)  	:= 'ECM005'	;	--日付チェックエラー
	MSGID_CHECK_HIKIOTOSHI		CONSTANT varchar(6)	:= 'ECM001'	;	--引落しチェックエラー
	MSGID_CHECK_FUKUSURAN		CONSTANT varchar(6)	:= 'ECM019'	;	--複数欄チェックエラー
	MSGID_CHECK_TYOFUKU			CONSTANT varchar(6)	:= 'ECM040'	;	--重複チェックエラー
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
	sErrorValue 	varchar(200);					--エラーが発生した値
	cItakuId		char(4);						--委託会社コード
--==============================================================================
--					カーソル定義												
--==============================================================================
	curMhakkotai_trns CURSOR FOR
		SELECT
			itaku_kaisha_cd			  , hkt_cd					  ,
			hkt_nm					  , hkt_rnm					  ,
			hkt_kana_rnm			  , kk_hakko_cd				  ,
			kk_hakkosha_rnm			  , kobetsu_shonin_saiyo_flg  ,
			sfsk_post_no 			  , add1 					  ,
			add2 					  , add3 					  ,
			sfsk_busho_nm			  , sfsk_tanto_nm			  ,
			sfsk_tel_no				  , sfsk_fax_no				  ,
			sfsk_mail_add			  , tokijo_post_no			  ,
			tokijo_add1				  , tokijo_add2				  ,
			tokijo_add3				  , tokijo_yakushoku_nm		  ,
			tokijo_delegate_nm		  , eigyoten_cd				  ,
			toitsu_ten_cifcd 		  , gyoshu_cd				  ,
			country_cd				  , bank_rating				  ,
			ryoshu_out_kbn			  , shokatsu_zeimusho_cd 	  ,
			seiri_no 				  , koza_ten_cd				  ,
			koza_ten_cifcd			  , nyukin_koza_kbn			  ,
			bd_koza_kamoku_cd		  , bd_koza_no				  ,
			bd_koza_meiginin_nm		  , bd_koza_meiginin_kana_nm  ,
			hkt_koza_kamoku_cd		  , hkt_koza_no				  ,
			hkt_koza_meiginin_nm 	  , hkt_koza_meiginin_kana_nm ,
			hikiotoshi_flg			  , hko_kamoku_cd			  ,
			hko_koza_no				  , hko_koza_meiginin_nm 	  ,
			hko_koza_meiginin_kana_nm , default_ymd				  ,
			default_biko 			  , yobi1					  ,
			yobi2					  , yobi3					  ,
			lin_no
		FROM mhakkotai_trns
		ORDER BY itaku_kaisha_cd, hkt_cd;
--==============================================================================
--					メイン処理													
--==============================================================================
BEGIN
	-- 入力パラメータのチェック データ種別
	IF coalesce(trim(both l_inDataId)::text, '') = '' THEN
		l_outSqlCode := pkconstant.error();
	 	l_outSqlErrM := MSG_PARAM_ERROR;
		CALL pkLog.error('ECM501',
			'IPF001K00R03',
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
			'IPF001K00R03',
			'＜項目名称：データ種別＞＜項目値：' || l_inDataId || '＞'
		);
		RETURN;
	END IF;
	--業務日付を取得
	cGyoumuDt := pkDate.getGyomuYmd();
	--発行体マスタ(移行用)の件数をチェック
	nCount := 0;
	SELECT count(*)
	INTO STRICT nCount
	FROM mhakkotai_trns;
	--発行体マスタ(移行用)の件数が０件の場合
	IF nCount = 0 THEN
		l_outSqlCode := pkconstant.NO_DATA_FIND();
	 	l_outSqlErrM := MSG_NO_DATA;
		CALL pkLog.error('EIP505', 'IPF001K00R03', MSG_NO_DATA);
		RETURN;
	END IF;
	--委託会社コードを取得
	SELECT DISTINCT itaku_kaisha_cd
	INTO STRICT cItakuId
	FROM mhakkotai_trns;
	--帳票ワーク削除
	DELETE FROM sreport_wk
	WHERE key_cd = cItakuId
	AND user_id = 'BATCH'
	AND chohyo_kbn = '1'
	AND sakusei_ymd = cGyoumuDt
	AND chohyo_id = 'IPF30000111'
	AND item003 = l_inDataId;
	--フラグを初期化する（マスタに書き込むか否かのフラグ）
	cFlg := 0;
	--発行体情報マスタ（移行）からデータを取得
	FOR recMhakkotai_trns IN curMhakkotai_trns LOOP
		--共通関数によるデータチェック
		FOR nCheckCounter IN 1..55 LOOP
			--変数初期化
				nRet := 0;
				sErrorField := '';
				sErrorValue := '';
			--発行体コード 半角英数チェック
			IF nCheckCounter = 1 THEN
				sErrorField := '発行体コード';
				sErrorValue := recMhakkotai_trns.hkt_cd;
				IF LENGTH(trim(both recMhakkotai_trns.hkt_cd)) = 6 THEN
					nRet := sfCmIsHalfAlphanumeric2(trim(both recMhakkotai_trns.hkt_cd));
					cMsgId := MSGID_CHECK_HANKAKU_EISU;
				ELSE
					nRet := 1;
					cMsgId := MSGID_CHECK_KETASU;
				END IF;
			--発行体名称 全角チェック
			ELSIF nCheckCounter = 2 THEN
				sErrorField := '発行体名称';
				sErrorValue := recMhakkotai_trns.hkt_nm;
				IF LENGTH(trim(both recMhakkotai_trns.hkt_nm)) > 0 THEN
					nRet := sfCmIsFullsizeChar(trim(both recMhakkotai_trns.hkt_nm));
					cMsgId := MSGID_CHECK_ZENKAKU;
				ELSE
					nRet := 1;
					cMsgId := MSGID_CHECK_HIKIOTOSHI;
				END IF;
			--発行体略称 全角チェック
			ELSIF nCheckCounter = 3 THEN
				sErrorField := '発行体略称';
				sErrorValue := recMhakkotai_trns.hkt_rnm;
				IF LENGTH(trim(both recMhakkotai_trns.hkt_rnm)) > 0 THEN
					nRet := sfCmIsFullsizeChar(trim(both recMhakkotai_trns.hkt_rnm));
					cMsgId := MSGID_CHECK_ZENKAKU;
				ELSE
					nRet := 1;
					cMsgId := MSGID_CHECK_HIKIOTOSHI;
				END IF;
			--発行体略称（カナ） 全角カナチェック
			ELSIF nCheckCounter = 4 THEN
				sErrorField := '発行体略称（カナ）';
				sErrorValue := recMhakkotai_trns.hkt_kana_rnm;
				IF LENGTH(trim(both recMhakkotai_trns.hkt_kana_rnm)) > 0 THEN
					nRet := sfCmIsZenKana(trim(both recMhakkotai_trns.hkt_kana_rnm));
					cMsgId := MSGID_CHECK_ZENKAKU_KANA;
				ELSE
					nRet := 1;
					cMsgId := MSGID_CHECK_HIKIOTOSHI;
				END IF;
			--機構発行体コード 数値チェック
			ELSIF nCheckCounter = 5 THEN
				IF (trim(both recMhakkotai_trns.kk_hakko_cd) IS NOT NULL AND (trim(both recMhakkotai_trns.kk_hakko_cd))::text <> '') THEN
					sErrorField := '機構発行体コード';
					sErrorValue := recMhakkotai_trns.kk_hakko_cd;
					IF LENGTH(trim(both recMhakkotai_trns.kk_hakko_cd)) = 6 THEN
						nRet := sfCmIsNumeric(trim(both recMhakkotai_trns.kk_hakko_cd));
						cMsgId := MSGID_CHECK_NUMBER;
					ELSE
						nRet := 1;
						cMsgId := MSGID_CHECK_KETASU;
					END IF;
				END IF;
			--機構発行者略称 全角チェック
			ELSIF nCheckCounter = 6 THEN
				nRet := sfCmIsFullsizeChar(trim(both recMhakkotai_trns.kk_hakkosha_rnm));
				cMsgId := MSGID_CHECK_ZENKAKU;
				sErrorField := '機構発行者略称';
				sErrorValue := recMhakkotai_trns.kk_hakkosha_rnm;
			--個別承認採用フラグ コード値チェック
			ELSIF nCheckCounter = 7 THEN
				nRet := sfCmIsCodeMChek('511', trim(both recMhakkotai_trns.kobetsu_shonin_saiyo_flg));
				cMsgId := MSGID_CHECK_CODE;
				sErrorField := '個別承認採用フラグ';
				sErrorValue := recMhakkotai_trns.kobetsu_shonin_saiyo_flg;
			--送付先郵便番号 数値チェック
			ELSIF nCheckCounter = 8 THEN
				IF (trim(both recMhakkotai_trns.sfsk_post_no) IS NOT NULL AND (trim(both recMhakkotai_trns.sfsk_post_no))::text <> '') THEN
					sErrorField := '送付先郵便番号';
					sErrorValue := recMhakkotai_trns.sfsk_post_no;
					IF LENGTH(trim(both recMhakkotai_trns.sfsk_post_no)) = 7 THEN
						nRet := sfCmIsNumeric(trim(both recMhakkotai_trns.sfsk_post_no));
						cMsgId := MSGID_CHECK_NUMBER;
					ELSE
						nRet := 1;
						cMsgId := MSGID_CHECK_KETASU;
					END IF;
				END IF;
			--送付先住所１ 全角チェック
			ELSIF nCheckCounter = 9 THEN
				nRet := sfCmIsFullsizeChar(trim(both recMhakkotai_trns.add1));
				cMsgId := MSGID_CHECK_ZENKAKU;
				sErrorField := '送付先住所１';
				sErrorValue := recMhakkotai_trns.add1;
			--送付先住所２ 全角チェック
			ELSIF nCheckCounter = 10 THEN
				nRet := sfCmIsFullsizeChar(trim(both recMhakkotai_trns.add2));
				cMsgId := MSGID_CHECK_ZENKAKU;
				sErrorField := '送付先住所２';
				sErrorValue := recMhakkotai_trns.add2;
			--送付先住所３ 全角チェック
			ELSIF nCheckCounter = 11 THEN
				nRet := sfCmIsFullsizeChar(trim(both recMhakkotai_trns.add3));
				cMsgId := MSGID_CHECK_ZENKAKU;
				sErrorField := '送付先住所３';
				sErrorValue := recMhakkotai_trns.add3;
			--送付先担当部署名称 全角チェック
			ELSIF nCheckCounter = 12 THEN
				nRet := sfCmIsFullsizeChar(trim(both recMhakkotai_trns.sfsk_busho_nm));
				cMsgId := MSGID_CHECK_ZENKAKU;
				sErrorField := '送付先担当部署名称';
				sErrorValue := recMhakkotai_trns.sfsk_busho_nm;
			--送付先担当者名称 全角チェック
			ELSIF nCheckCounter = 13 THEN
				nRet := sfCmIsFullsizeChar(trim(both recMhakkotai_trns.sfsk_tanto_nm));
				cMsgId := MSGID_CHECK_ZENKAKU;
				sErrorField := '送付先担当者名称';
				sErrorValue := recMhakkotai_trns.sfsk_tanto_nm;
			--送付先電話番号 電話番号エラーチェック
			ELSIF nCheckCounter = 14 THEN
				nRet := sfCmIsTelNoCheck(trim(both recMhakkotai_trns.sfsk_tel_no));
				cMsgId := MSGID_CHECK_TELNO;
				sErrorField := '送付先電話番号';
				sErrorValue := recMhakkotai_trns.sfsk_tel_no;
			--送付先FAX番号 電話番号エラーチェック
			ELSIF nCheckCounter = 15 THEN
				nRet := sfCmIsTelNoCheck(trim(both recMhakkotai_trns.sfsk_fax_no));
				cMsgId := MSGID_CHECK_TELNO;
				sErrorField := '送付先FAX番号';
				sErrorValue := recMhakkotai_trns.sfsk_fax_no;
			--送付先メールアドレス 半角チェック
			ELSIF nCheckCounter = 16 THEN
				nRet := sfCmIsHalfsizeChar(trim(both recMhakkotai_trns.sfsk_mail_add));
				cMsgId := MSGID_CHECK_HANKAKU;
				sErrorField := '送付先メールアドレス';
				sErrorValue := recMhakkotai_trns.sfsk_mail_add;
			--登記上郵便番号 数値チェック
			ELSIF nCheckCounter = 17 THEN
				IF (trim(both recMhakkotai_trns.tokijo_post_no) IS NOT NULL AND (trim(both recMhakkotai_trns.tokijo_post_no))::text <> '') THEN
					sErrorField := '登記上郵便番号';
					sErrorValue := recMhakkotai_trns.tokijo_post_no;
					IF LENGTH(trim(both recMhakkotai_trns.tokijo_post_no)) = 7 THEN
						nRet := sfCmIsNumeric(trim(both recMhakkotai_trns.tokijo_post_no));
						cMsgId := MSGID_CHECK_NUMBER;
					ELSE
						nRet := 1;
						cMsgId := MSGID_CHECK_KETASU;
					END IF;
				END IF;
			--登記上住所１ 全角チェック
			ELSIF nCheckCounter = 18 THEN
				nRet := sfCmIsFullsizeChar(trim(both recMhakkotai_trns.tokijo_add1));
				cMsgId := MSGID_CHECK_ZENKAKU;
				sErrorField := '登記上住所１';
				sErrorValue := recMhakkotai_trns.tokijo_add1;
			--登記上住所２ 全角チェック
			ELSIF nCheckCounter = 19 THEN
				nRet := sfCmIsFullsizeChar(trim(both recMhakkotai_trns.tokijo_add2));
				cMsgId := MSGID_CHECK_ZENKAKU;
				sErrorField := '登記上住所２';
				sErrorValue := recMhakkotai_trns.tokijo_add2;
			--登記上住所３ 全角チェック
			ELSIF nCheckCounter = 20 THEN
				nRet := sfCmIsFullsizeChar(trim(both recMhakkotai_trns.tokijo_add3));
				cMsgId := MSGID_CHECK_ZENKAKU;
				sErrorField := '登記上住所３';
				sErrorValue := recMhakkotai_trns.tokijo_add3;
			--登記上役職名称 全角チェック
			ELSIF nCheckCounter = 21 THEN
				nRet := sfCmIsFullsizeChar(trim(both recMhakkotai_trns.tokijo_yakushoku_nm));
				cMsgId := MSGID_CHECK_ZENKAKU;
				sErrorField := '登記上役職名称';
				sErrorValue := recMhakkotai_trns.tokijo_yakushoku_nm;
			--登記上代表者名称 全角チェック
			ELSIF nCheckCounter = 22 THEN
				nRet := sfCmIsFullsizeChar(trim(both recMhakkotai_trns.tokijo_delegate_nm));
				cMsgId := MSGID_CHECK_ZENKAKU;
				sErrorField := '登記上代表者名称';
				sErrorValue := recMhakkotai_trns.tokijo_delegate_nm;
			--営業店コード 半角英数チェック
			ELSIF nCheckCounter = 23 THEN
				sErrorField := '営業店コード';
				sErrorValue := recMhakkotai_trns.eigyoten_cd;
				IF LENGTH(trim(both recMhakkotai_trns.eigyoten_cd)) = 4 THEN
					nRet := sfCmIsHalfAlphanumeric2(trim(both recMhakkotai_trns.eigyoten_cd));
					cMsgId := MSGID_CHECK_HANKAKU_EISU;
				ELSE
					nRet := 1;
					cMsgId := MSGID_CHECK_KETASU;
				END IF;
			--営業店コード 対応する部店コードが部店マスタに存在するかチェック
			ELSIF nCheckCounter = 24 THEN
				nCount := 0;
				nRet := 0;
				SELECT COUNT(*)
					INTO STRICT nCount 
				FROM mbuten 
				WHERE itaku_kaisha_cd = cItakuId
				AND	buten_cd = recMhakkotai_trns.eigyoten_cd
				AND shori_kbn = '1';
				IF nCount = 0 THEN
					nRet := 1;
					cMsgId := MSGID_CHECK_CODE;
				END IF;
				sErrorField := '営業店コード';
				sErrorValue := recMhakkotai_trns.eigyoten_cd;
			--業種コード コード値チェック
			ELSIF nCheckCounter = 25 THEN
				nRet := sfCmIsCodeMChek('705', trim(both recMhakkotai_trns.gyoshu_cd));
				cMsgId := MSGID_CHECK_CODE;
				sErrorField := '業種コード';
				sErrorValue := recMhakkotai_trns.gyoshu_cd;
			--国コード 半角英数チェック
			ELSIF nCheckCounter = 26 THEN
				sErrorField := '国コード';
				sErrorValue := recMhakkotai_trns.country_cd;
				IF LENGTH(trim(both recMhakkotai_trns.country_cd)) = 3 THEN
					nRet := sfCmIsHalfAlphanumeric2(trim(both recMhakkotai_trns.country_cd));
					cMsgId := MSGID_CHECK_HANKAKU_EISU;
				ELSE
					nRet := 1;
					cMsgId := MSGID_CHECK_KETASU;
				END IF;
			--国コード 対応する国コードが国マスタに存在するかチェック
			ELSIF nCheckCounter = 27 THEN
				nCount := 0;
				nRet := 0;
				SELECT COUNT(*)
				INTO STRICT nCount 
				FROM mcountry 
				WHERE country_cd = recMhakkotai_trns.country_cd
				AND shori_kbn = '1';
				IF nCount = 0 THEN
					nRet := 1;
					cMsgId := MSGID_CHECK_CODE;
				END IF;
				sErrorField := '国コード';
				sErrorValue := recMhakkotai_trns.country_cd;
			--行内格付 半角英数チェック
			ELSIF nCheckCounter = 28 THEN
				IF (trim(both recMhakkotai_trns.bank_rating) IS NOT NULL AND (trim(both recMhakkotai_trns.bank_rating))::text <> '') THEN
					sErrorField := '行内格付';
					sErrorValue := recMhakkotai_trns.bank_rating;
					IF LENGTH(trim(both recMhakkotai_trns.bank_rating)) = 10 THEN
						nRet := sfCmIsHalfAlphanumeric2(trim(both recMhakkotai_trns.bank_rating));
						cMsgId := MSGID_CHECK_HANKAKU_EISU;
					ELSE
						nRet := 1;
						cMsgId := MSGID_CHECK_KETASU;
					END IF;
				END IF;
			--領収書出力区分 コード値チェック
			ELSIF nCheckCounter = 29 THEN
				nRet := sfCmIsCodeMChek('717', trim(both recMhakkotai_trns.ryoshu_out_kbn));
				cMsgId := MSGID_CHECK_CODE;
				sErrorField := '領収書出力区分';
				sErrorValue := recMhakkotai_trns.ryoshu_out_kbn;
			--所轄税務署コード 数値チェック
			ELSIF nCheckCounter = 30 THEN
				IF (trim(both recMhakkotai_trns.shokatsu_zeimusho_cd) IS NOT NULL AND (trim(both recMhakkotai_trns.shokatsu_zeimusho_cd))::text <> '') THEN
					sErrorField := '所轄税務署コード';
					sErrorValue := recMhakkotai_trns.shokatsu_zeimusho_cd;
					IF LENGTH(trim(both recMhakkotai_trns.shokatsu_zeimusho_cd)) = 5 THEN
						nRet := sfCmIsNumeric(trim(both recMhakkotai_trns.shokatsu_zeimusho_cd));
						cMsgId := MSGID_CHECK_NUMBER;
					ELSE
						nRet := 1;
						cMsgId := MSGID_CHECK_KETASU;
					END IF;
				END IF;
			--所轄税務署コード 対応する所轄コードが税務署マスタに存在することをチェック
			ELSIF nCheckCounter = 31 THEN
				IF (trim(both recMhakkotai_trns.shokatsu_zeimusho_cd) IS NOT NULL AND (trim(both recMhakkotai_trns.shokatsu_zeimusho_cd))::text <> '') THEN
					nCount := 0;
					nRet := 0;
					SELECT COUNT(*)
					INTO STRICT nCount 
					FROM mzeimusho 
					WHERE zeimusho_cd = recMhakkotai_trns.shokatsu_zeimusho_cd
					AND shori_kbn = '1';
					IF nCount = 0 THEN
						nRet := 1;
						cMsgId := MSGID_CHECK_CODE;
					END IF;
					sErrorField := '所轄税務署コード';
					sErrorValue := recMhakkotai_trns.shokatsu_zeimusho_cd;
				END IF;
			--整理番号 半角英数チェック
			ELSIF nCheckCounter = 32 THEN
				IF (trim(both recMhakkotai_trns.seiri_no) IS NOT NULL AND (trim(both recMhakkotai_trns.seiri_no))::text <> '') THEN
					sErrorField := '整理番号';
					sErrorValue := recMhakkotai_trns.seiri_no;
					IF LENGTH(trim(both recMhakkotai_trns.seiri_no)) = 8 THEN
						nRet := sfCmIsHalfAlphanumeric2(trim(both recMhakkotai_trns.seiri_no));
						cMsgId := MSGID_CHECK_HANKAKU_EISU;
					ELSE
						nRet := 1;
						cMsgId := MSGID_CHECK_KETASU;
					END IF;
				END IF;
			--統一店CIFコード 数値チェック
			ELSIF nCheckCounter = 33 THEN
				nRet := sfCmIsNumeric(trim(both recMhakkotai_trns.toitsu_ten_cifcd));
				cMsgId := MSGID_CHECK_NUMBER;
				sErrorField := '統一店CIFコード';
				sErrorValue := recMhakkotai_trns.toitsu_ten_cifcd;
			--口座店コード 半角英数チェック
			ELSIF nCheckCounter = 34 THEN
				sErrorField := '口座店コード';
				sErrorValue := recMhakkotai_trns.koza_ten_cd;
				IF LENGTH(trim(both recMhakkotai_trns.koza_ten_cd)) = 4 THEN
					nRet := sfCmIsHalfAlphanumeric2(trim(both recMhakkotai_trns.koza_ten_cd));
					cMsgId := MSGID_CHECK_HANKAKU_EISU;
				ELSE
					nRet := 1;
					cMsgId := MSGID_CHECK_KETASU;
				END IF;
			--口座店コード 対応する部店コードが部店マスタに存在することをチェック
			ELSIF nCheckCounter = 35 THEN
				nCount := 0;
				nRet := 0;
				SELECT COUNT(*)
					INTO STRICT nCount 
				FROM mbuten 
				WHERE ITAKU_KAISHA_CD = cItakuId
				AND	buten_cd = recMhakkotai_trns.koza_ten_cd
				AND shori_kbn = '1';
				IF nCount = 0 THEN
					nRet := 1;
					cMsgId := MSGID_CHECK_CODE;
				END IF;
				sErrorField := '口座店コード';
				sErrorValue := recMhakkotai_trns.koza_ten_cd;
			--口座店CIFコード 数値チェック
			ELSIF nCheckCounter = 36 THEN
				sErrorField := '口座店CIFコード';
				sErrorValue := recMhakkotai_trns.koza_ten_cifcd;
				IF LENGTH(trim(both recMhakkotai_trns.koza_ten_cifcd)) > 0 THEN
					nRet := sfCmIsNumeric(trim(both recMhakkotai_trns.koza_ten_cifcd));
					cMsgId := MSGID_CHECK_NUMBER;
				ELSE
					nRet := 1;
					cMsgId := MSGID_CHECK_HIKIOTOSHI;
				END IF;
			--入金口座選択区分 コード値チェック
			ELSIF nCheckCounter = 37 THEN
				nRet := sfCmIsCodeMChek('122', trim(both recMhakkotai_trns.nyukin_koza_kbn));
				cMsgId := MSGID_CHECK_CODE;
				sErrorField := '入金口座選択区分';
				sErrorValue := recMhakkotai_trns.nyukin_koza_kbn;
			--専用別段_口座科目コード コード値チェック
			ELSIF nCheckCounter = 38 THEN
				nRet := sfCmIsCodeMChek('707', trim(both recMhakkotai_trns.bd_koza_kamoku_cd));
				cMsgId := MSGID_CHECK_CODE;
				sErrorField := '専用別段_口座科目コード';
				sErrorValue := recMhakkotai_trns.bd_koza_kamoku_cd;
			--専用別段_口座番号 数値チェック
			ELSIF nCheckCounter = 39 THEN
				IF (trim(both recMhakkotai_trns.bd_koza_no) IS NOT NULL AND (trim(both recMhakkotai_trns.bd_koza_no))::text <> '') THEN
					sErrorField := '専用別段_口座番号';
					sErrorValue := recMhakkotai_trns.bd_koza_no;
					IF LENGTH(trim(both recMhakkotai_trns.bd_koza_no)) = 7 THEN
						nRet := sfCmIsNumeric(trim(both recMhakkotai_trns.bd_koza_no));
						cMsgId := MSGID_CHECK_NUMBER;
					ELSE
						nRet := 1;
						cMsgId := MSGID_CHECK_KETASU;
					END IF;
				END IF;
			--専用別段_口座名義人 全角チェック
			ELSIF nCheckCounter = 40 THEN
				nRet := sfCmIsFullsizeChar(trim(both recMhakkotai_trns.bd_koza_meiginin_nm));
				cMsgId := MSGID_CHECK_ZENKAKU;
				sErrorField := '専用別段_口座名義人';
				sErrorValue := recMhakkotai_trns.bd_koza_meiginin_nm;
			--専用別段_口座名義人（カナ） 全角カナチェック
			ELSIF nCheckCounter = 41 THEN
				nRet := sfCmIsZenKana(trim(both recMhakkotai_trns.bd_koza_meiginin_kana_nm));
				cMsgId := MSGID_CHECK_ZENKAKU_KANA;
				sErrorField := '専用別段_口座名義人（カナ）';
				sErrorValue := recMhakkotai_trns.bd_koza_meiginin_kana_nm;
			--発行体預金口座_口座科目コード コード値チェック
			ELSIF nCheckCounter = 42 THEN
				nRet := sfCmIsCodeMChek('707', trim(both recMhakkotai_trns.hkt_koza_kamoku_cd));
				cMsgId := MSGID_CHECK_CODE;
				sErrorField := '発行体預金口座_口座科目コード';
				sErrorValue := recMhakkotai_trns.hkt_koza_kamoku_cd;
			--発行体預金口座_口座番号 数値チェック
			ELSIF nCheckCounter = 43 THEN
				IF (trim(both recMhakkotai_trns.hkt_koza_no) IS NOT NULL AND (trim(both recMhakkotai_trns.hkt_koza_no))::text <> '') THEN
					sErrorField := '発行体預金口座_口座番号';
					sErrorValue := recMhakkotai_trns.hkt_koza_no;
					IF LENGTH(trim(both recMhakkotai_trns.hkt_koza_no)) = 7 THEN
						nRet := sfCmIsNumeric(trim(both recMhakkotai_trns.hkt_koza_no));
						cMsgId := MSGID_CHECK_NUMBER;
					ELSE
						nRet := 1;
						cMsgId := MSGID_CHECK_KETASU;
					END IF;
				END IF;
			--発行体預金口座_口座名義人 全角チェック
			ELSIF nCheckCounter = 44 THEN
				nRet := sfCmIsFullsizeChar(trim(both recMhakkotai_trns.hkt_koza_meiginin_nm));
				cMsgId := MSGID_CHECK_ZENKAKU;
				sErrorField := '発行体預金口座_口座名義人';
				sErrorValue := recMhakkotai_trns.hkt_koza_meiginin_nm;
			--発行体預金口座_口座名義人（カナ） 全角カナチェック
			ELSIF nCheckCounter = 45 THEN
				nRet := sfCmIsZenKana(trim(both recMhakkotai_trns.hkt_koza_meiginin_kana_nm));
				cMsgId := MSGID_CHECK_ZENKAKU_KANA;
				sErrorField := '発行体預金口座_口座名義人（カナ）';
				sErrorValue := recMhakkotai_trns.hkt_koza_meiginin_kana_nm;
			--自動引落フラグ コード値チェック
			ELSIF nCheckCounter = 46 THEN
				nRet := sfCmIsCodeMChek('711', trim(both recMhakkotai_trns.hikiotoshi_flg));
				cMsgId := MSGID_CHECK_CODE;
				sErrorField := '自動引落フラグ';
				sErrorValue := recMhakkotai_trns.hikiotoshi_flg;
			--自動引落口座_口座科目コード コード値チェック
			ELSIF nCheckCounter = 47 THEN
				nRet := sfCmIsCodeMChek('707', trim(both recMhakkotai_trns.hko_kamoku_cd));
				cMsgId := MSGID_CHECK_CODE;
				sErrorField := '自動引落口座_口座科目コード';
				sErrorValue := recMhakkotai_trns.hko_kamoku_cd;
			--自動引落口座_口座番号 数値チェック
			ELSIF nCheckCounter = 48 THEN
				IF (trim(both recMhakkotai_trns.hko_koza_no) IS NOT NULL AND (trim(both recMhakkotai_trns.hko_koza_no))::text <> '') THEN
					sErrorField := '自動引落口座_口座番号';
					sErrorValue := recMhakkotai_trns.hko_koza_no;
					IF LENGTH(trim(both recMhakkotai_trns.hko_koza_no)) = 7 THEN
						nRet := sfCmIsNumeric(trim(both recMhakkotai_trns.hko_koza_no));
						cMsgId := MSGID_CHECK_NUMBER;
					ELSE
						nRet := 1;
						cMsgId := MSGID_CHECK_KETASU;
					END IF;
				END IF;
			--自動引落口座_口座名義人 全角チェック
			ELSIF nCheckCounter = 49 THEN
				nRet := sfCmIsFullsizeChar(trim(both recMhakkotai_trns.hko_koza_meiginin_nm));
				cMsgId := MSGID_CHECK_ZENKAKU;
				sErrorField := '自動引落口座_口座名義人';
				sErrorValue := recMhakkotai_trns.hko_koza_meiginin_nm;
			--自動引落口座_口座名義人（カナ） 全角カナチェック
			ELSIF nCheckCounter = 50 THEN
				nRet := sfCmIsZenKana(trim(both recMhakkotai_trns.hko_koza_meiginin_kana_nm));
				cMsgId := MSGID_CHECK_ZENKAKU_KANA;
				sErrorField := '自動引落口座_口座名義人（カナ）';
				sErrorValue := recMhakkotai_trns.hko_koza_meiginin_kana_nm;
			--デフォルト日 日付フォーマットチェック
			ELSIF nCheckCounter = 51 THEN
				IF (trim(both recMhakkotai_trns.default_ymd) IS NOT NULL AND (trim(both recMhakkotai_trns.default_ymd))::text <> '') THEN
					nRet := pkDate.validateDate(recMhakkotai_trns.default_ymd);
					cMsgId := MSGID_CHECK_HIDUKE;
					sErrorField := 'デフォルト日';
					sErrorValue := recMhakkotai_trns.default_ymd;
				END IF;
			--送付先住所
			ELSIF nCheckCounter = 52 THEN
				nRet := SPIPF001K00R03_SUB_CHECK_FUKUSURAN(trim(both recMhakkotai_trns.add1),trim(both recMhakkotai_trns.add2),trim(both recMhakkotai_trns.add3));
				cMsgId := MSGID_CHECK_FUKUSURAN;
				sErrorField := '送付先住所';
				sErrorValue := recMhakkotai_trns.add1 || ',' || recMhakkotai_trns.add2 || ',' || recMhakkotai_trns.add3;
			--登記上住所
			ELSIF nCheckCounter = 53 THEN
				nRet := SPIPF001K00R03_SUB_CHECK_FUKUSURAN(trim(both recMhakkotai_trns.tokijo_add1),trim(both recMhakkotai_trns.tokijo_add2),trim(both recMhakkotai_trns.tokijo_add3));
				cMsgId := MSGID_CHECK_FUKUSURAN;
				sErrorField := '登記上住所';
				sErrorValue := recMhakkotai_trns.tokijo_add1 || ',' || recMhakkotai_trns.tokijo_add2 || ',' || recMhakkotai_trns.tokijo_add3;
			--引落し
			ELSIF nCheckCounter = 54 THEN
				nRet := 0;
				IF recMhakkotai_trns.hikiotoshi_flg = '1' THEN
					IF coalesce(trim(both recMhakkotai_trns.hko_kamoku_cd)::text, '') = '' THEN
						nRet := 1;
						cMsgId := MSGID_CHECK_HIKIOTOSHI;
						sErrorField := '自動引落口座_口座科目コード';
						sErrorValue := recMhakkotai_trns.hko_kamoku_cd;
					ELSIF coalesce(trim(both recMhakkotai_trns.hko_koza_no)::text, '') = '' THEN
						nRet := 1;
						cMsgId := MSGID_CHECK_HIKIOTOSHI;
						sErrorField := '自動引落口座_口座番号';
						sErrorValue := recMhakkotai_trns.hko_koza_no;
					ELSIF coalesce(trim(both recMhakkotai_trns.hko_koza_meiginin_nm)::text, '') = '' THEN
						nRet := 1;
						cMsgId := MSGID_CHECK_HIKIOTOSHI;
						sErrorField := '自動引落口座_口座名義人';
						sErrorValue := recMhakkotai_trns.hko_koza_meiginin_nm;
					ELSIF coalesce(trim(both recMhakkotai_trns.hko_koza_meiginin_kana_nm)::text, '') = '' THEN
						nRet := 1;
						cMsgId := MSGID_CHECK_HIKIOTOSHI;
						sErrorField := '自動引落口座_口座名義人（カナ）';
						sErrorValue := recMhakkotai_trns.hko_koza_meiginin_kana_nm;
					END IF;
				END IF;
			--重複チェック（委託会社コード、発行体コード）
			ELSIF nCheckCounter = 55 THEN
				nCount := 0;
				SELECT count(*)
				INTO STRICT nCount
				FROM mhakkotai
				WHERE itaku_kaisha_cd = cItakuId
				AND hkt_cd = recMhakkotai_trns.hkt_cd;
				nRet := 0;
				IF nCount != 0 THEN
					nRet := 1;
					cMsgId := MSGID_CHECK_TYOFUKU;
					sErrorField := '委託会社コード,発行体コード';
					sErrorValue := cItakuId || ',' || recMhakkotai_trns.hkt_cd;
				END IF;
			END IF;
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
					recMhakkotai_trns.lin_no, 
					sErrorField, 
					sErrorValue, 
					cMsgId, 
					l_outSqlCode, 
					l_outSqlErrM
				);
				--マスタに書き込むためのフラグを更新（不可）
				IF cFlg != '1' THEN
					cFlg := '1';
				END IF;
			END IF;
		END LOOP;	--ループ １〜５４まで
	END LOOP;	--ループ レコード数分
	--マスタに書き込むためのフラグが立っていた場合、エラーを返す
	IF cFlg = '1' THEN
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := MSG_DATA_ERROR;
		CALL pkLog.error('ECM502', 'IPF001K00R03', MSG_DATA_ERROR);
		RETURN;
	END IF;
	--発行体情報マスタ更新
	FOR recMhakkotai_trns IN curMhakkotai_trns LOOP
		INSERT INTO MHAKKOTAI(
			itaku_kaisha_cd			  , hkt_cd					  ,
			hkt_nm					  , hkt_rnm					  ,
			hkt_kana_rnm			  , kk_hakko_cd				  ,
			kk_hakkosha_rnm			  , kobetsu_shonin_saiyo_flg  ,
			sfsk_post_no 			  , add1 					  ,
			add2 					  , add3 					  ,
			sfsk_busho_nm			  , sfsk_tanto_nm			  ,
			sfsk_tel_no				  , sfsk_fax_no				  ,
			sfsk_mail_add			  , tokijo_post_no			  ,
			tokijo_add1				  , tokijo_add2				  ,
			tokijo_add3				  , tokijo_yakushoku_nm		  ,
			tokijo_delegate_nm		  , eigyoten_cd				  ,
			toitsu_ten_cifcd 		  , gyoshu_cd				  ,
			country_cd				  , bank_rating				  ,
			ryoshu_out_kbn			  , shokatsu_zeimusho_cd 	  ,
			seiri_no 				  , koza_ten_cd				  ,
			koza_ten_cifcd			  , nyukin_koza_kbn			  ,
			bd_koza_kamoku_cd		  , bd_koza_no				  ,
			bd_koza_meiginin_nm		  , bd_koza_meiginin_kana_nm  ,
			hkt_koza_kamoku_cd		  , hkt_koza_no				  ,
			hkt_koza_meiginin_nm 	  , hkt_koza_meiginin_kana_nm ,
			hikiotoshi_flg			  , hko_kamoku_cd			  ,
			hko_koza_no				  , hko_koza_meiginin_nm 	  ,
			hko_koza_meiginin_kana_nm , default_ymd				  ,
			default_biko 			  , yobi1					  ,
			yobi2					  , yobi3					  ,
			group_id				  , shori_kbn 				  ,
			last_teisei_dt			  , last_teisei_id			  ,
			shonin_dt 				  ,	shonin_id 				  ,
			kousin_dt				  , kousin_id				  ,
			sakusei_dt				  , sakusei_id
		)
		VALUES (
			recMhakkotai_trns.itaku_kaisha_cd			, recMhakkotai_trns.hkt_cd					 ,
	        recMhakkotai_trns.hkt_nm					, recMhakkotai_trns.hkt_rnm					 ,
			recMhakkotai_trns.hkt_kana_rnm				, recMhakkotai_trns.kk_hakko_cd				 ,
			recMhakkotai_trns.kk_hakkosha_rnm			, recMhakkotai_trns.kobetsu_shonin_saiyo_flg ,
			recMhakkotai_trns.sfsk_post_no				, recMhakkotai_trns.add1					 ,
			recMhakkotai_trns.add2						, recMhakkotai_trns.add3					 ,
			recMhakkotai_trns.sfsk_busho_nm				, recMhakkotai_trns.sfsk_tanto_nm			 ,
			recMhakkotai_trns.sfsk_tel_no				, recMhakkotai_trns.sfsk_fax_no				 ,
			recMhakkotai_trns.sfsk_mail_add				, recMhakkotai_trns.tokijo_post_no			 ,
			recMhakkotai_trns.tokijo_add1				, recMhakkotai_trns.tokijo_add2				 ,
			recMhakkotai_trns.tokijo_add3				, recMhakkotai_trns.tokijo_yakushoku_nm		 ,
			recMhakkotai_trns.tokijo_delegate_nm		, recMhakkotai_trns.eigyoten_cd				 ,
			recMhakkotai_trns.toitsu_ten_cifcd			, recMhakkotai_trns.gyoshu_cd				 ,
			recMhakkotai_trns.country_cd				, recMhakkotai_trns.bank_rating				 ,
			recMhakkotai_trns.ryoshu_out_kbn			, recMhakkotai_trns.shokatsu_zeimusho_cd	 ,
			recMhakkotai_trns.seiri_no					, recMhakkotai_trns.koza_ten_cd				 ,
			recMhakkotai_trns.koza_ten_cifcd			, recMhakkotai_trns.nyukin_koza_kbn			 ,
			recMhakkotai_trns.bd_koza_kamoku_cd			, recMhakkotai_trns.bd_koza_no				 ,
			recMhakkotai_trns.bd_koza_meiginin_nm		, recMhakkotai_trns.bd_koza_meiginin_kana_nm ,
			recMhakkotai_trns.hkt_koza_kamoku_cd		, recMhakkotai_trns.hkt_koza_no				 ,
			recMhakkotai_trns.hkt_koza_meiginin_nm		, recMhakkotai_trns.hkt_koza_meiginin_kana_nm,
			recMhakkotai_trns.hikiotoshi_flg			, recMhakkotai_trns.hko_kamoku_cd			 ,
			recMhakkotai_trns.hko_koza_no				, recMhakkotai_trns.hko_koza_meiginin_nm	 ,
			recMhakkotai_trns.hko_koza_meiginin_kana_nm	, recMhakkotai_trns.default_ymd			 	 ,
			recMhakkotai_trns.default_biko				, recMhakkotai_trns.yobi1					 ,
			recMhakkotai_trns.yobi2						, recMhakkotai_trns.yobi3					 ,
			' '						,
			'1'						,
			current_timestamp		,
			'ikou'					,
			current_timestamp		,
			'ikou'					,
			current_timestamp		,
			'ikou'					,
			current_timestamp		,
			'ikou'
		);
	END LOOP;
	--リターン
	l_outSqlCode := pkconstant.success();
	l_outSqlErrM := '';
	RETURN;
--==============================================================================
--					エラー処理													
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'IPF001K00R03', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLERRM || '(' || SQLSTATE || ')';
		RETURN;
--		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipf001k00r03 ( l_inDataId scode.code_value%type , l_outSqlCode OUT integer , l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spipf001k00r03_sub_check_fukusuran ( Item1 text, Item2 text, Item3 text ) RETURNS numeric AS $body$
DECLARE

	nRet numeric := 0;

BEGIN
	--処理
	IF (coalesce(Item3::text, '') = '') OR (Item3 = '') THEN
		IF (coalesce(Item2::text, '') = '') OR (Item2 = '') THEN
			--正常	１    ２×  ３×
			nRet := nRet;
		ELSE
			IF (coalesce(Item1::text, '') = '') OR (Item1 = '') THEN
				--異常	１×  ２○  ３×
				nRet := 1;
			ELSE
				--正常	１○  ２○  ３×
				nRet := nRet;
			END IF;
		END IF;
	ELSE
		IF (coalesce(Item2::text, '') = '') OR (Item2 = '') THEN
			--異常	１    ２×  ３○
			nRet := 1;
		ELSE
			IF (coalesce(Item1::text, '') = '') OR (Item1 = '') THEN
				--異常	１×  ２○  ３○
				nRet := 1;
			ELSE
				--正常	１○  ２○  ３○
				nRet := nRet;
			END IF;
		END IF;
	END IF;
	--リターン
	RETURN nRet;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spipf001k00r03_sub_check_fukusuran ( Item1 text, Item2 text, Item3 text ) FROM PUBLIC;