




CREATE OR REPLACE FUNCTION sfipf016k01r02 () RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 当預閉局電文送信PG
-- * 
-- * @author	yorikane
-- * @version $Revision: 1.7 $
-- * @return INTEGER
-- *				  0:正常終了 データ無し
-- *				  1:予期したエラー
-- *				 99:予期せぬエラー
-- 
--==============================================================================
--					定数定義													
--==============================================================================
	MSGID_CHECK_HANKAKU_EISU	CONSTANT varchar(6)	:= 'ECM013';	--半角英数チェックエラー
	MSGID_CHECK_HANKAKU 		CONSTANT varchar(6)	:= 'ECM009';	--半角チェックエラー
	MSGID_CHECK_KISYUIZONMOJI	CONSTANT varchar(6)	:= 'ECM008';	--機種依存文字チェックエラー
	MSGID_CHECK_HIDUKE			CONSTANT varchar(6)	:= 'ECM005';	--日付チェックエラー
	MSGID_CHECK_FUKUSURAN		CONSTANT varchar(6)	:= 'ECM019';	--複数欄チェックエラー
	MSGID_CHECK_CODE			CONSTANT varchar(6)	:= 'ECM305';	--コード値チェックエラー
	MSGID_CHECK_NUMBER			CONSTANT varchar(6)	:= 'ECM002';	--数値チェックエラー
	MSGID_CHECK_HANKAKU_KANA	CONSTANT varchar(6)	:= 'ECMXXX';	--半角カナチェックエラー
	MSGID_CHECK_HIKIOTOSHI		CONSTANT varchar(6)	:= 'ECM001';	--引落しチェックエラー
	MSGPARAM_ERROR	CONSTANT varchar(30)	:= 'パラメーターエラー' 		;
	MSG_NO_DATA 	CONSTANT varchar(30)	:= 'データ無しエラー'			;
	MSG_DATA_ERROR	CONSTANT varchar(30)	:= 'データエラー'				;
	MSG_COMMON_ERR	CONSTANT varchar(30)	:= '共通関数エラー' 			;
--==============================================================================
--					変数定義													
--==============================================================================
	cGyoumuDt sreport_wk.sakusei_ymd%type;
	nRet		integer;
	vItemRecord varchar(300);
	nMaxDataSeq integer;
	cItem1	char(2)  := 'A1';					-- IF区分
	cItem2	char(2)  := '03';					-- データ区分
	cItem3	char(2)  := 'R2';					-- 業務区分
	cItem4	text := '                ';		-- IF通番
	cItem5	char(16) := '                ';		-- 当預約定暗号
	cItem6	char(2)  := '  ';					-- 当預約定詳細番号
	cItem7	char(1)  := ' ';					-- 処理区分
	cItem8	char(3)  := '   ';					-- 当預商品区分
	cItem9	char(2)  := '  ';					-- 当預ステータス区分
	cItem10 char(1)  := ' ';					-- 約定相手予備区分
	cItem11 char(1)  := ' ';					-- 約定相手金融機関コード
	cItem12 char(8)  := '        ';				-- 決済日
	cItem13 char(1)  := ' ';					-- 決済相手予備区分
	cItem14 char(6)  := '      ';				-- 決済相手金融機関コード
	cItem15 char(4)  := '    ';					-- 決済相手店舗コード
	cItem16 char(2)  := '  ';					-- 決済処理区分
	cItem17 char(2)  := '  ';					-- 決済方法区分
	cItem18 char(9)  := '         ';			-- 決済予定時刻
	cItem19 char(4)  := '    ';					-- 勘定保有店番号
	cItem20 char(1)  := ' ';					-- 備考コード
	cItem21 char(2)  := '  ';					-- 当預出入区分
	cItem22 char(18) := '                  ';	-- 当預金額
	cItem23 char(2)  := '  ';					-- ＤＶＰ区分
	cItem24 char(1)  := ' ';					-- 自己代行区分
	cItem25 char(1)  := ' ';					-- ベネフィシャリー予備区分
	cItem26 char(1)  := ' ';					-- ベネフィシャリー金融機関コード
	cItem27 char(8)  := '        ';				-- 取込日
	cItem28 char(8)  := '        ';				-- 更新日
	cItem29 char(9)  := '         ';			-- 更新時刻
	cItem30 char(10) := '          ';			-- 更新担当者
	cItem31 char(16) := '                ';		-- 決済番号
	cItem32 char(2)  := '  ';					-- 取引種別
--==============================================================================
--					カーソル定義												
--==============================================================================
--==============================================================================
--					メイン処理													
--==============================================================================
BEGIN
	--IF通番
	cGyoumuDt := pkDate.getGyomuYmd();
	CALL SPIPFGETIFNO(nRet, cGyoumuDt, cItem4);
	IF nRet != 0 THEN
		CALL pkLog.fatal('ECM701', 'IPF016K01R02', 'IF通番取得エラー');
		RETURN nRet;
	END IF;
	--更新日
	cItem28 := TO_CHAR(current_timestamp,'YYYYMMDD');
	--更新時刻
	cItem29 := TO_CHAR(current_timestamp,'HH24MISS') || '000';
	--データ連結
	vItemRecord := cItem1  || ',' || cItem2  || ',' || cItem3  || ',' || cItem4  || ',' || cItem5  || ','
				|| cItem6  || ',' || cItem7  || ',' || cItem8  || ',' || cItem9  || ',' || cItem10 || ','
				|| cItem11 || ',' || cItem12 || ',' || cItem13 || ',' || cItem14 || ',' || cItem15 || ','
				|| cItem16 || ',' || cItem17 || ',' || cItem18 || ',' || cItem19 || ',' || cItem20 || ','
				|| cItem21 || ',' || cItem22 || ',' || cItem23 || ',' || cItem24 || ',' || cItem25 || ','
				|| cItem26 || ',' || cItem27 || ',' || cItem28 || ',' || cItem29 || ',' || cItem30 || ','
				|| cItem31 || ',' || cItem32;
	--データ内連番取得
	SELECT MAX(data_seq) INTO STRICT nMaxDataSeq FROM toyorealsndif WHERE make_dt = TO_CHAR(current_timestamp,'YYYYMMDD');
	nMaxDataSeq := coalesce(nMaxDataSeq, 0) + 1;
	--当預リアル送信IFテーブル更新
	INSERT INTO toyorealsndif(
		data_id,
		make_dt,
		data_seq,
		data_sect,
		sr_stat
	)
	VALUES (
		'13003',
		TO_CHAR(current_timestamp,'YYYYMMDD'),
		coalesce(nMaxDataSeq, 0),
		vItemRecord,
		'0'
	);
	--当預リアル送受信保存テーブル更新
	INSERT INTO toyorealsave(
		data_id,
		make_dt,
		data_seq,
		data_sect
	)
	VALUES (
		'13003',
		TO_CHAR(current_timestamp,'YYYYMMDD'),
		coalesce(nMaxDataSeq, 0),
		vItemRecord
	);
	--行内IF管理情報テーブル 行内IF接続ステータス
	UPDATE toyokonaiif SET konaiif_connect_stat = '0';
	--リターン
	RETURN pkconstant.success();
--==============================================================================
--					エラー処理													
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'IPF016K01R02', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		RETURN pkconstant.FATAL();
--		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf016k01r02 () FROM PUBLIC;
