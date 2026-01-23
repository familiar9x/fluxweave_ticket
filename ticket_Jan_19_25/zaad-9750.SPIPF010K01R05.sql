




CREATE OR REPLACE PROCEDURE spipf010k01r05 ( l_inDATA_ID TEXT , l_inMAKE_DT TEXT , l_inDATA_SEQ TEXT , l_inDATA_SECT text , l_outSqlCode OUT integer , l_outSqlErrM OUT text ) AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 処理結果データ受信
-- * 
-- * @author	yorikane
-- * @version $Revision: 1.8 $
-- * $Id: SPIPF010K01R05.sql,v 1.8 2005/11/04 10:12:44 kubo Exp $
-- * @param	l_inDATA_ID 	IN	TEXT		データID
-- * 			l_inMAKE_DT 	IN	TEXT		作成日
-- * 			l_inDATA_SEQ	IN	TEXT		データ内連番
-- * 			l_inDATA_SECT	IN	VARCHAR	データ部
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
	MSG_PARAM_ERROR CONSTANT varchar(30)   := 'パラメーターエラー';
	MSG_NO_DATA     CONSTANT varchar(30)   := 'データ無しエラー';
	MSG_DATA_ERROR  CONSTANT varchar(30)   := 'データエラー';
	MSG_COMMON_ERR	CONSTANT varchar(30)	:= '共通関数エラー'		;
--==============================================================================
--					変数定義													
--==============================================================================
	nCount				numeric;							--件数取得
	nRet				numeric;							--関数戻り値
	cFlg				char(1);						--更新フラグ
	cMsgId				varchar(6);					--メッセージID
	sErrorField			varchar(100);					--エラーが発生したフィールド名
	sErrorValue			varchar(100);					--エラーが発生した値
	nKanmaCounter		numeric;							--ループカウンター
	nCheckCounter		numeric;							--ループカウンター
	nPos				numeric;							--文字列操作
	cItaku_kaisha_cd	char(4);						--委託会社コード
	vTsuchiNaiyo		varchar(200);					--通知内容
	vLogMsg				varchar(200);					--ログメッセージ
	vDataId				varchar(2);					--データ種別
	cGyoumuDt 			sreport_wk.sakusei_ymd%type;	--業務日付
	cItem1				char(2);						--IF区分
	cItem2				char(2);						--データ区分
	cItem3				char(2);						--業務区分
	cItem4				char(16);						--IF通番
	cItem5				char(16);						--当預約定暗号
	cItem6				char(2);						--当預約定詳細番号
	cItem7				char(1);						--処理区分
	cItem8				char(3);						--当預商品区分
	cItem9				char(2);						--当預ステータス区分
	cItem10				char(1);						--約定相手予備区分
	cItem11				char(1);						--約定相手金融機関コード
	cItem12				char(8);						--決済日
	cItem13				char(1);						--決済相手予備区分
	cItem14				char(6);						--決済相手金融機関コード
	cItem15				char(4);						--決済相手店舗コード
	cItem16				char(2);						--決済処理区分
	cItem17				char(2);						--決済方法区分
	cItem18				char(9);						--決済予定時刻
	cItem19				char(4);						--勘定保有店番号
	cItem20				char(1);						--備考コード
	cItem21				char(2);						--当預出入区分
	cItem22				char(18);						--当預金額
	cItem23				char(2);						--DVP区分
	cItem24				char(1);						--自己代行区分
	cItem25				char(1);						--ベネフィシャリー予備区分
	cItem26				char(1);						--ベネフィシャリー金融機関コード
	cItem27				char(8);						--取込日
	cItem28				char(8);						--更新日
	cItem29				char(9);						--更新時刻
	cItem30				char(10);						--更新担当者
	cItem31				char(16);						--決済番号
	cItem32				char(2);						--取引種別
	nItem22				numeric;							--当預金額
--==============================================================================
--					メイン処理													
--==============================================================================
BEGIN
	--入力パラメータ（データID）のチェック
	IF coalesce(trim(both l_inDATA_ID)::text, '') = '' OR trim(both l_inDATA_ID) = '' THEN
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := MSG_PARAM_ERROR;
		CALL pkLog.error('ECM501', 'IPF010K01R05', '＜項目名称:データID＞' || '＜項目値:' || l_inDATA_ID || '＞');
		RETURN;
	END IF;
	--入力パラメータ（作成日）のチェック
	IF coalesce(trim(both l_inMAKE_DT)::text, '') = '' OR trim(both l_inMAKE_DT) = '' THEN
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := MSG_PARAM_ERROR;
		CALL pkLog.error('ECM501', 'IPF010K01R05', '＜項目名称:作成日＞' || '＜項目値:' || l_inMAKE_DT || '＞');
		RETURN;
	END IF;
	--入力パラメータ（データ内連番）のチェック
	IF coalesce(trim(both l_inDATA_SEQ)::text, '') = '' OR trim(both l_inDATA_SEQ) = '' THEN
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := MSG_PARAM_ERROR;
		CALL pkLog.error('ECM501', 'IPF010K01R05', '＜項目名称:データ内連番＞' || '＜項目値:' || l_inDATA_SEQ || '＞');
		RETURN;
	END IF;
	--入力パラメータ（データ部）のチェック
	IF coalesce(trim(both l_inDATA_SECT)::text, '') = '' OR trim(both l_inDATA_SECT) = '' THEN
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := MSG_PARAM_ERROR;
		CALL pkLog.error('ECM501', 'IPF010K01R05', '＜項目名称:データ部＞' || '＜項目値:' || l_inDATA_SECT || '＞');
		RETURN;
	END IF;
	--当預リアル送受信保存テーブルにデータを登録
	INSERT INTO TOYOREALSAVE(
		data_id		,
		make_dt		, 
		data_seq	, 
		data_sect
	)
	VALUES (
		l_inDATA_ID 	,
		l_inMAKE_DT 	,
		l_inDATA_SEQ::NUMERIC	,
		l_inDATA_SECT	
	);
	--業務日付を取得
	cGyoumuDt := pkDate.getGyomuYmd();
	--委託会社コード取得
	SELECT kaiin_id INTO STRICT cItaku_kaisha_cd FROM sown_info;
	--サイズチェック（データ部）
	IF LENGTH(l_inDATA_SECT) != 194 THEN
		--ログ出力
		CALL pkLog.error('ECM502', 'IPF010K01R05', 'データ部の桁数が不正です。');
		--エラーリスト書き込み
		vLogMsg := 'データ部の桁数が不正です。';
		CALL SPIPF001K00R01(
			cItaku_kaisha_cd::TEXT,
			'BATCH', 
			'1', 
			'3', 
			cGyoumuDt::TEXT, 
			'50', 
			l_inDATA_SEQ::NUMERIC, 
			'データ部', 
			vLogMsg, 
			'ECM502', 
			l_outSqlCode, 
			l_outSqlErrM
		);
		--メッセージ通知テーブルへ書き込み
		nRet := SfIpMsgTsuchiUpdate(cItaku_kaisha_cd, 'RTGS','重要','1','0',vLogMsg,'BATCH','BATCH');
		IF nRet != 0 THEN
			l_outSqlCode := nRet;
			l_outSqlErrM := 'メッセージ通知登録エラー';
			CALL pkLog.fatal('ECM701', 'IPF010K01R05', 'メッセージ通知登録エラー');
			RETURN;
		END IF;
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := MSG_PARAM_ERROR;
		RETURN;
	END IF;
	--フォーマットチェック（データ部）
	FOR nKanmaCounter IN 1..31 LOOP
		--カンマ位置３１箇所をチェック
		CASE nKanmaCounter
			WHEN 1 THEN 	nPos := 3;
			WHEN 2 THEN 	nPos := 6;
			WHEN 3 THEN 	nPos := 9;
			WHEN 4 THEN 	nPos := 26;
			WHEN 5 THEN 	nPos := 43;
			WHEN 6 THEN 	nPos := 46;
			WHEN 7 THEN 	nPos := 48;
			WHEN 8 THEN 	nPos := 52;
			WHEN 9 THEN 	nPos := 55;
			WHEN 10 THEN 	nPos := 57;
			WHEN 11 THEN 	nPos := 59;
			WHEN 12 THEN 	nPos := 68;
			WHEN 13 THEN 	nPos := 70;
			WHEN 14 THEN 	nPos := 77;
			WHEN 15 THEN 	nPos := 82;
			WHEN 16 THEN 	nPos := 85;
			WHEN 17 THEN 	nPos := 88;
			WHEN 18 THEN 	nPos := 98;
			WHEN 19 THEN 	nPos := 103;
			WHEN 20 THEN 	nPos := 105;
			WHEN 21 THEN 	nPos := 108;
			WHEN 22 THEN 	nPos := 127;
			WHEN 23 THEN 	nPos := 130;
			WHEN 24 THEN 	nPos := 132;
			WHEN 25 THEN 	nPos := 134;
			WHEN 26 THEN 	nPos := 136;
			WHEN 27 THEN 	nPos := 145;
			WHEN 28 THEN 	nPos := 154;
			WHEN 29 THEN 	nPos := 164;
			WHEN 30 THEN 	nPos := 175;
			WHEN 31 THEN 	nPos := 192;
		END CASE;
		--カンマでない場合
		IF SUBSTRING(l_inDATA_SECT FROM nPos::integer FOR 1) != ',' THEN
			--エラーメッセージ
			vLogMsg := nKanmaCounter::text || '番目のカンマ位置が不正です。';
			--ログ出力
			CALL pkLog.error('ECM502', 'IPF010K01R05', vLogMsg);
			--エラーリスト書き込み
			CALL SPIPF001K00R01(
				cItaku_kaisha_cd::TEXT,
				'BATCH', 
				'1', 
				'3', 
				cGyoumuDt::TEXT, 
				'50', 
				l_inDATA_SEQ::NUMERIC, 
				'データ部', 
				vLogMsg, 
				'ECM502', 
				l_outSqlCode, 
				l_outSqlErrM
			);
			--メッセージ通知テーブルへ書き込み
			nRet := SfIpMsgTsuchiUpdate(cItaku_kaisha_cd, 'RTGS','重要','1','0',vLogMsg,'BATCH','BATCH');
			IF nRet != 0 THEN
				l_outSqlCode := nRet;
				l_outSqlErrM := 'メッセージ通知登録エラー';
				CALL pkLog.fatal('ECM701', 'IPF010K01R05', 'メッセージ通知登録エラー');
				RETURN;
			END IF;
			--リターン値
			l_outSqlCode := pkconstant.error();
			l_outSqlErrM := 'フォーマットエラー';
			--リターン
			RETURN;
		END IF;
	END LOOP;
	--データ分割
	cItem1	:=SUBSTRING(l_inDATA_SECT FROM 1 FOR 2);		--IF区分
	cItem2	:=SUBSTRING(l_inDATA_SECT FROM 4 FOR 2);		--データ区分
	cItem3	:=SUBSTRING(l_inDATA_SECT FROM 7 FOR 2);		--業務区分
	cItem4	:=SUBSTRING(l_inDATA_SECT FROM 10 FOR 16);		--IF通番
	cItem5	:=SUBSTRING(l_inDATA_SECT FROM 27 FOR 16);		--当預約定暗号
	cItem6	:=SUBSTRING(l_inDATA_SECT FROM 44 FOR 2);		--当預約定詳細番号
	cItem7	:=SUBSTRING(l_inDATA_SECT FROM 47 FOR 1);		--処理区分
	cItem8	:=SUBSTRING(l_inDATA_SECT FROM 49 FOR 3);		--当預商品区分
	cItem9	:=SUBSTRING(l_inDATA_SECT FROM 53 FOR 2);		--当預ステータス区分
	cItem10	:=SUBSTRING(l_inDATA_SECT FROM 56 FOR 1);		--約定相手予備区分
	cItem11	:=SUBSTRING(l_inDATA_SECT FROM 58 FOR 1);		--約定相手金融機関コード
	cItem12	:=SUBSTRING(l_inDATA_SECT FROM 60 FOR 8);		--決済日
	cItem13	:=SUBSTRING(l_inDATA_SECT FROM 69 FOR 1);		--決済相手予備区分
	cItem14	:=SUBSTRING(l_inDATA_SECT FROM 71 FOR 6);		--決済相手金融機関コード
	cItem15	:=SUBSTRING(l_inDATA_SECT FROM 78 FOR 4);		--決済相手店舗コード
	cItem16	:=SUBSTRING(l_inDATA_SECT FROM 83 FOR 2);		--決済処理区分
	cItem17	:=SUBSTRING(l_inDATA_SECT FROM 86 FOR 2);		--決済方法区分
	cItem18	:=SUBSTRING(l_inDATA_SECT FROM 89 FOR 9);		--決済予定時刻
	cItem19	:=SUBSTRING(l_inDATA_SECT FROM 99 FOR 4);		--勘定保有店番号
	cItem20	:=SUBSTRING(l_inDATA_SECT FROM 104 FOR 1);		--備考コード
	cItem21	:=SUBSTRING(l_inDATA_SECT FROM 106 FOR 2);		--当預出入区分
	cItem22	:=SUBSTRING(l_inDATA_SECT FROM 109 FOR 18);	--当預金額
	cItem23	:=SUBSTRING(l_inDATA_SECT FROM 128 FOR 2);		--DVP区分
	cItem24	:=SUBSTRING(l_inDATA_SECT FROM 131 FOR 1);		--自己代行区分
	cItem25	:=SUBSTRING(l_inDATA_SECT FROM 133 FOR 1);		--ベネフィシャリー予備区分
	cItem26	:=SUBSTRING(l_inDATA_SECT FROM 135 FOR 1);		--ベネフィシャリー金融機関コード
	cItem27	:=SUBSTRING(l_inDATA_SECT FROM 137 FOR 8);		--取込日
	cItem28	:=SUBSTRING(l_inDATA_SECT FROM 146 FOR 8);		--更新日
	cItem29	:=SUBSTRING(l_inDATA_SECT FROM 155 FOR 9);		--更新時刻
	cItem30	:=SUBSTRING(l_inDATA_SECT FROM 165 FOR 10);	--更新担当者
	cItem31	:=SUBSTRING(l_inDATA_SECT FROM 176 FOR 16);	--決済番号
	cItem32	:=SUBSTRING(l_inDATA_SECT FROM 193 FOR 2);		--取引種別
	--分割データ チェック
	FOR nCheckCounter IN 1..5 LOOP
		CASE nCheckCounter
			WHEN 1 THEN
				--当預金額 数値チェック
				nRet := sfCmIsNumeric(trim(both cItem22));
				cMsgId := MSGID_CHECK_NUMBER;
				sErrorField := '当預金額 ';
				sErrorValue := cItem22;
			WHEN 2 THEN
				--処理区分 コード値チェック
				nRet := sfCmIsCodeMChek('S03', cItem7);
				cMsgId := MSGID_CHECK_CODE;
				sErrorField := '処理区分';
				sErrorValue := cItem7;
			WHEN 3 THEN
				--当預ステータス区分 コード値チェック
				nRet := sfCmIsCodeMChek('S05', cItem9);
				cMsgId := MSGID_CHECK_CODE;
				sErrorField := '当預ステータス区分';
				sErrorValue := cItem9;
			WHEN 4 THEN
				--当預出入区分 コード値チェック
				nRet := sfCmIsCodeMChek('S04', cItem21);
				cMsgId := MSGID_CHECK_CODE;
				sErrorField := '当預出入区分';
				sErrorValue := cItem21;
			WHEN 5 THEN
				--決済日 日付チェック
				nRet := pkDate.validateDate(cItem12);
				cMsgId := MSGID_CHECK_HIDUKE;
				sErrorField := '決済日';
				sErrorValue := cItem12;
		END CASE;
		--エラーの場合
		IF nRet = 1 THEN
			--メッセージの切り替え
			IF cItem21 = '01' THEN
				vTsuchiNaiyo := '支払結果のフォーマットが不正です。＜決済番号：' || cItem31 || '＞';
				vLogMsg := '＜支払結果＞＜決済番号：' || cItem31 || '＞＜エラー項目：' || sErrorValue || '＞';
				vDataId := '52';
			ELSIF cItem21 = '02' THEN
				vTsuchiNaiyo := '当座勘定入金のフォーマットが不正です。＜決済番号：' || cItem31 || '＞';
				vLogMsg := '＜当座勘定入金＞＜決済番号：' || cItem31 || '＞＜エラー項目：' || sErrorValue || '＞';
				vDataId := '51';
			ELSE
				vTsuchiNaiyo := '当預(資金決済)のフォーマットが不正です。＜決済番号：' || cItem31 || '＞';
				vLogMsg := '＜当預(資金決済)＞＜決済番号：' || cItem31 || '＞＜エラー項目：' || sErrorValue || '＞';
				vDataId := '50';
			END IF;
			--ログ出力
			CALL pkLog.error('ECM502', 'IPF010K01R05', vLogMsg);
			--エラーリスト書き込み
			CALL SPIPF001K00R01(
				cItaku_kaisha_cd::TEXT,
				'BATCH', 
				'1', 
				'3', 
				cGyoumuDt::TEXT, 
				vDataId, 
				l_inDATA_SEQ::NUMERIC, 
				sErrorField, 
				sErrorValue, 
				'ECM502', 
				l_outSqlCode, 
				l_outSqlErrM
			);
			--メッセージ通知テーブルへ書き込み
			nRet := SfIpMsgTsuchiUpdate(cItaku_kaisha_cd, 'RTGS','重要','1','0',vTsuchiNaiyo,'BATCH','BATCH');
			IF nRet != 0 THEN
				l_outSqlCode := nRet;
				l_outSqlErrM := 'メッセージ通知登録エラー';
				CALL pkLog.fatal('ECM701', 'IPF010K01R05', 'メッセージ通知登録エラー');
				RETURN;
			END IF;
			--リターン値
			l_outSqlCode := pkconstant.error();
			l_outSqlErrM := 'フォーマットエラー';
			--リターン
			RETURN;
		END IF;
		-- 同一決済番号のチェック
		nCount := 0;
		SELECT count(*)
		INTO STRICT nCount
		FROM toyorcv
		WHERE itaku_kaisha_cd = cItaku_kaisha_cd
		AND kessai_no = cItem31
		AND data_shori_kbn = cITEM7;
		-- 同一決済番号のデータが当預テーブルに存在した場合
		IF nCount != 0 THEN
			--メッセージの切り替え
			IF cItem21 = '01' THEN
				vTsuchiNaiyo := '受信データの決済番号が重複しています。<支払結果><決済番号:' || cItem31 || '>';
				vLogMsg := '<支払結果><受信データの決済番号が重複しています。><決済番号:' || cItem31 || '>';
				vDataId := '52';
			ELSIF cItem21 = '02' THEN
				vTsuchiNaiyo := '受信データの決済番号が重複しています。<当座勘定入金><決済番号:' || cItem31 || '>';
				vLogMsg := '<当座勘定入金><受信データの決済番号が重複しています。><決済番号:' || cItem31 || '>';
				vDataId := '51';
			ELSE
				vTsuchiNaiyo := '受信データの決済番号が重複しています。<決済番号:' || cItem31 || '>';
				vLogMsg := '<当預(資金決済)><受信データの決済番号が重複しています。><決済番号:' || cItem31 || '>';
				vDataId := '50';
			END IF;
			--ログ出力
			CALL pkLog.error('EIP520', 'IPF010K01R05', vLogMsg);
			--エラーリスト書き込み
			CALL SPIPF001K00R01(
				cItaku_kaisha_cd::TEXT,
				'BATCH', 
				'1', 
				'3', 
				cGyoumuDt::TEXT, 
				vDataId, 
				l_inDATA_SEQ::NUMERIC, 
				'決済番号', 
				cItem31, 
				'EIP520', 
				l_outSqlCode, 
				l_outSqlErrM
			);
			--メッセージ通知テーブルへ書き込み
			nRet := SfIpMsgTsuchiUpdate(cItaku_kaisha_cd, 'RTGS','重要','1','0',vTsuchiNaiyo,'BATCH','BATCH');
			IF nRet != 0 THEN
				l_outSqlCode := nRet;
				l_outSqlErrM := 'メッセージ通知登録エラー';
				CALL pkLog.fatal('ECM701', 'IPF010K01R05', 'メッセージ通知登録エラー');
				RETURN;
			END IF;
			--リターン値
			l_outSqlCode := pkconstant.error();
			l_outSqlErrM := '決済番号重複エラー';
			--リターン
			RETURN;
		END IF;
	END LOOP;
	--当預金額の型変換
	nITEM22 := (cItem22)::numeric;
	--当預テーブル（受信用）にデータ挿入
	INSERT INTO TOYORCV(
		itaku_kaisha_cd			,kessai_no				,
		data_shori_kbn			,if_kbn					,
		data_kbn_smbc			,gyomu_kbn_smbc			,
		if_tsuban				,toyo_yakujo_no			,
		toyo_yakujoshosai_no	,toyo_shohin_kbn		,
		toyo_stat_kbn			,yakujo_aite_yobi_kbn	,
		yakujo_aite_bank_cd		,kessai_ymd				,
		kessai_aite_yobi_kbn	,kessai_aite_bank_cd	,
		kessai_aite_tenpo_cd	,kessai_shori_kbn		,
		kessai_method_kbn		,kessai_yotei_tm		,
		kanjo_hoyuten_no		,biko_cd				,
		toyo_deiri_kbn			,toyo_kngk				,
		dvp_kbn_smbc			,own_daiko_kbn			,
		bene_yobi_kbn			,bene_bank_cd			,
		import_ymd				,update_ymd				,
		update_tm				,update_tantosha		,
		trhk_shubetsu_smbc		,nyushukin_joukyou		,
		send_flg				,kousin_dt				,
		kousin_id				,sakusei_dt				,
		sakusei_id
	)
	VALUES (
		cItaku_kaisha_cd	,cITEM31			,
		cITEM7				,cITEM1				,
		cITEM2				,cITEM3				,
		cITEM4				,cITEM5				,
		cITEM6				,cITEM8				,
		cITEM9				,cITEM10			,
		cITEM11				,cITEM12			,
		cITEM13				,cITEM14			,
		cITEM15				,cITEM16			,
		cITEM17				,cITEM18			,
		cITEM19				,cITEM20			,
		cITEM21				,nITEM22			,
		cITEM23				,cITEM24			,
		cITEM25				,cITEM26			,
		cITEM27				,cITEM28			,
		cITEM29				,cITEM30			,
		cITEM32				,' '				,
		' '					,current_timestamp	,
		'BATCH'				,current_timestamp	,
		'BATCH'
	);
	--照合処理の呼び出し
	CALL SPIPF010K01R06(cItaku_kaisha_cd, cITEM31, cITEM21, l_inDATA_SEQ, l_outSqlCode, l_outSqlErrM);
	IF l_outSqlCode = pkconstant.success() OR l_outSqlCode = pkconstant.no_data_find() THEN
		l_outSqlCode := pkconstant.success();
		l_outSqlErrM := '';
	ELSIF l_outSqlCode = pkconstant.fatal() THEN
		l_outSqlCode := pkconstant.fatal();
		l_outSqlErrM := l_outSqlErrM;
	END IF;
	--リターン
	RETURN;
--==============================================================================
--					エラー処理													
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'IPF010K01R05', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		l_outSqlCode := pkconstant.fatal();
		l_outSqlErrM := SQLERRM || '(' || SQLSTATE || ')';
		RETURN;
--		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipf010k01r05 ( l_inDATA_ID TEXT , l_inMAKE_DT TEXT , l_inDATA_SEQ TEXT , l_inDATA_SECT text , l_outSqlCode OUT integer , l_outSqlErrM OUT text ) FROM PUBLIC;
