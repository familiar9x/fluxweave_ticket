




CREATE OR REPLACE FUNCTION sfipf012k01r01 () RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 当預テーブル（送信用）のデータを送信ＩＦテーブル、
-- * ファイル送受信保存テーブルに挿入する
-- * 
-- * @author 小林　弘幸
-- * @version $Revision: 1.5 $
-- * 
-- * @return INTEGER
-- *                0:正常終了、データ無し
-- *                1:予期したエラー
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
	nCount    numeric;										   -- 件数カウンタ
	iCnt      integer;										   -- ループカウンタ
	nRowNum   numeric := 0;									   -- 行数
	nRenban   numeric := 0;									   -- データ内連番
	nMakeNum  numeric := 0;									   -- 作成回数
	nRet      numeric := 0;									   -- 戻り値
	cGyoumuDt char(8) := '';								   -- 業務日付格納用
	vData     varchar(2000);								   -- 連結データ
--==============================================================================
--                  カーソル定義                                                
--==============================================================================
	curToyoData CURSOR FOR
			SELECT
				if_kbn,
				data_kbn_smbc,
				gyomu_kbn_smbc,
				if_tsuban,
				toyo_yakujo_no,
				toyo_yakujoshosai_no,
				data_shori_kbn,
				toyo_shohin_kbn,
				toyo_stat_kbn,
				yakujo_aite_yobi_kbn,
				yakujo_aite_bank_cd,
				kessai_ymd,
				kessai_aite_yobi_kbn,
				kessai_aite_bank_cd,
				kessai_aite_tenpo_cd,
				kessai_shori_kbn,
				kessai_method_kbn,
				kessai_yotei_tm,
				kanjo_hoyuten_no,
				biko_cd,
				toyo_deiri_kbn,
				toyo_kngk,
				dvp_kbn_smbc,
				own_daiko_kbn,
				bene_yobi_kbn,
				bene_bank_cd,
				import_ymd,
				update_ymd,
				update_tm,
				update_tantosha,
				kessai_no,
				trhk_shubetsu_smbc
			FROM
				toyosend
			WHERE kessai_ymd >= cGyoumuDt
			AND send_flg = '1'
			ORDER BY
				kessai_no,
				data_shori_kbn;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 業務日付を取得
	cGyoumuDt := pkDate.getGyomuYmd();
	-- ヘッダーレコードの挿入
	-- データ内連番設定
	nRenban := 1;
	-- 行数を設定
	nRowNum := 1;
	-- ファイル送信ＩＦテーブル
	INSERT INTO filesndif(
		data_id,
		make_dt,
		make_cnt,
		data_seq,
		data_sect_filedbif,
		sr_stat
	)
	VALUES (
		'13015',
		TO_CHAR(clock_timestamp(), 'YYYYMMDD'),
		1,
		nRenban,
		('HDR' || cGyoumuDt || 'VMTZFRB00AX0'),
		'0'
	);
	-- ファイル送受信保存テーブル
	INSERT INTO filesave(
		data_id,
		make_dt,
		make_cnt,
		data_seq,
		data_sect_filedbif
	)
	VALUES (
		'13015',
		TO_CHAR(clock_timestamp(), 'YYYYMMDD'),
		1,
		nRenban,
		('HDR' || cGyoumuDt || 'VMTZFRB00AX0')
	);
	-- データ編集
	FOR recToyoData IN curToyoData LOOP
		--決済番号重複件数チェック
		SELECT COUNT(*)
		INTO STRICT   nCount
		FROM   toyosend
		WHERE  kessai_no = recToyoData.kessai_no;
		IF nCount < 2 THEN
			vData := '';
			-- 行数をインクリメント
			nRowNum := nRowNum + 1;
			-- データ内連番をインクリメント
			nRenban := nRenban + 1;
			For iCnt IN 1 .. 32 LOOP
				CASE iCnt
					-- ＩＦ区分
					WHEN 1 THEN
						vData := 'DAT' || ',' || recToyoData.if_kbn;
					-- データ区分（ＳＭＢＣ）
					WHEN 2 THEN
						vData := vData || ',' || recToyoData.data_kbn_smbc;
					-- 業務区分（ＳＭＢＣ）
					WHEN 3 THEN
						vData := vData || ',' || recToyoData.gyomu_kbn_smbc;
					-- ＩＦ通番
					WHEN 4 THEN
						vData := vData || ',' || recToyoData.if_tsuban;
					-- 当預約定番号
					WHEN 5 THEN
						vData := vData || ',' || recToyoData.toyo_yakujo_no;
					-- 当預約定詳細番号
					WHEN 6 THEN
						vData := vData || ',' || recToyoData.toyo_yakujoshosai_no;
					-- データ処理区分
					WHEN 7 THEN
						vData := vData || ',' || recToyoData.data_shori_kbn;
					-- 当預商品区分
					WHEN 8 THEN
						vData := vData || ',' || recToyoData.toyo_shohin_kbn;
					-- 当預ステータス区分
					WHEN 9 THEN
						vData := vData || ',' || recToyoData.toyo_stat_kbn;
					-- 約定相手予備区分
					WHEN 10 THEN
						vData := vData || ',' || recToyoData.yakujo_aite_yobi_kbn;
					-- 約定相手金融機関コード
					WHEN 11 THEN
						vData := vData || ',' || recToyoData.yakujo_aite_bank_cd;
					-- 決済日
					WHEN 12 THEN
						vData := vData || ',' || recToyoData.kessai_ymd;
					-- 決済相手予備区分
					WHEN 13 THEN
						vData := vData || ',' || recToyoData.kessai_aite_yobi_kbn;
					-- 決済相手金融機関コード
					WHEN 14 THEN
						vData := vData || ',' || recToyoData.kessai_aite_bank_cd;
					-- 決済相手店舗コード
					WHEN 15 THEN
						vData := vData || ',' || recToyoData.kessai_aite_tenpo_cd;
					-- 決済処理区分
					WHEN 16 THEN
						vData := vData || ',' || recToyoData.kessai_shori_kbn;
					-- 決済方法区分
					WHEN 17 THEN
						vData := vData || ',' || recToyoData.kessai_method_kbn;
					-- 決済予定時刻
					WHEN 18 THEN
						vData := vData || ',' || recToyoData.kessai_yotei_tm;
					-- 勘定保有店番号
					WHEN 19 THEN
						vData := vData || ',' || recToyoData.kanjo_hoyuten_no;
					-- 備考コード
					WHEN 20 THEN
						vData := vData || ',' || recToyoData.biko_cd;
					-- 当預出入区分
					WHEN 21 THEN
						vData := vData || ',' || recToyoData.toyo_deiri_kbn;
					-- 当預金額
					WHEN 22 THEN
						vData := vData || ',' || LPAD(recToyoData.toyo_kngk::text, 18, '0');
					-- ＤＶＰ区分（ＳＭＢＣ）
					WHEN 23 THEN
						vData := vData || ',' || recToyoData.dvp_kbn_smbc;
					-- 自行代行区分
					WHEN 24 THEN
						vData := vData || ',' || recToyoData.own_daiko_kbn;
					-- ベネフィシャリー予備区分
					WHEN 25 THEN
						vData := vData || ',' || recToyoData.bene_yobi_kbn;
					-- ベネフィシャリー金融機関コード
					WHEN 26 THEN
						vData := vData || ',' || recToyoData.bene_bank_cd;
					-- 取込日
					WHEN 27 THEN
						vData := vData || ',' || recToyoData.import_ymd;
					-- 更新日
					WHEN 28 THEN
						vData := vData || ',' || recToyoData.update_ymd;
					-- 更新時刻
					WHEN 29 THEN
						vData := vData || ',' || recToyoData.update_tm;
					-- 更新担当者
					WHEN 30 THEN
						vData := vData || ',' || recToyoData.update_tantosha;
					-- 決済番号
					WHEN 31 THEN
						vData := vData || ',' || recToyoData.kessai_no;
					-- 取引種別（ＳＭＢＣ）
					WHEN 32 THEN
						vData := vData || ',' || recToyoData.trhk_shubetsu_smbc;
				END CASE;
			END LOOP;
			-- ファイル送信ＩＦテーブルへデータ挿入
			INSERT INTO filesndif(
				data_id,
				make_dt,
				make_cnt,
				data_seq,
				data_sect_filedbif,
				sr_stat
			)
			VALUES (
				'13015',
				TO_CHAR(clock_timestamp(), 'YYYYMMDD'),
				1,
				nRenban,
				vData,
				'0'
			);
			-- ファイル送受信保存テーブルへデータ挿入
			INSERT INTO filesave(
				data_id,
				make_dt,
				make_cnt,
				data_seq,
				data_sect_filedbif
			)
			VALUES (
				'13015',
				TO_CHAR(clock_timestamp(), 'YYYYMMDD'),
				1,
				nRenban,
			vData
			);
		END IF;
	END LOOP;
	-- フッターレコードの挿入
	-- ファイル送信ＩＦテーブル
	INSERT INTO filesndif(
		data_id,
		make_dt,
		make_cnt,
		data_seq,
		data_sect_filedbif,
		sr_stat
	)
	VALUES(
		'13015',
		TO_CHAR(clock_timestamp(), 'YYYYMMDD'),
		1,
		(nRenban + 1),
		('TRL' || cGyoumuDt || LPAD(nRowNum+1::text, 8, '0')),
		'0'
	);
	-- ファイル送受信保存テーブル
	INSERT INTO filesave(
		data_id,
		make_dt,
		make_cnt,
		data_seq,
		data_sect_filedbif
	)
	VALUES(
		'13015',
		TO_CHAR(clock_timestamp(), 'YYYYMMDD'),
		1,
		(nRenban + 1),
		('TRL' || cGyoumuDt || LPAD(nRowNum+1::text, 8, '0'))
	);
	RETURN pkconstant.success();
--==============================================================================
--                  エラー処理                                                  
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		-- ログ出力
		CALL pkLog.fatal(
			'ECM701',
			'IPF012K01R01',
			'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')'
		);
		RETURN pkconstant.FATAL();
--		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf012k01r01 () FROM PUBLIC;
