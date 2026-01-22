




CREATE OR REPLACE FUNCTION sfipf010k01r04 ( l_inItakuId toyosend.itaku_kaisha_cd%type,	-- 委託会社コード
 l_inKessaiNo toyosend.kessai_no%type,			-- 決済番号
 l_inDataShoriKbn toyosend.data_shori_kbn%type 		-- データ処理区分
 ) RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 当預テーブル（送信用）の内容を基に当預リアル送信ＩＦテーブル、
-- * 当預リアル送受信保存テーブルに決済日当日日中処理分のデータを挿入する
-- * 
-- * @author 戸倉　一成
-- * @version $Revision: 1.5 $
-- * 
-- * @param  l_inItakuId        IN     TEXT				委託会社コード
-- *         l_inKessaiNo       IN     TEXT				決済番号
-- *         l_inDataShoriKbn   IN     TEXT				データ処理区分
-- * @return INTEGER
-- *                0:正常終了、データ無し
-- *                1:予期したエラー
-- *               99:予期せぬエラー
--
--==============================================================================
--                  定数定義                                                    
--==============================================================================
    MSG_GETIFNO_ERR          CONSTANT text := 'ＩＦ通番取得エラー';
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	nCount      numeric;							-- 件数カウンタ
	nRtnCd      integer;							-- 正常処理フラグ
	cGyoumuDt   text;								-- 業務日付
	vData       text;								-- 連結後データ格納
	cSysDate    text;								-- システム日付
	cIfNo       text;								-- ＩＦ通番採番
	cToyoKngk   text;								-- 当預金額
--==============================================================================
--                  カーソル定義                                                
--==============================================================================
	curToyosend CURSOR FOR
		SELECT 
			itaku_kaisha_cd,
			kessai_no,
			data_shori_kbn,
			if_kbn,
			data_kbn_smbc,
			gyomu_kbn_smbc,
			toyo_yakujo_no,
			toyo_yakujoshosai_no,
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
			update_ymd,
			update_tm,
			update_tantosha,
			trhk_shubetsu_smbc 
		FROM 
			toyosend 
		WHERE itaku_kaisha_cd = l_inItakuId 
		AND   kessai_no       = l_inKessaiNo 
		AND   data_shori_kbn  = l_inDataShoriKbn;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 業務日付を取得
	cGyoumuDt := pkDate.getGyomuYmd();
	-- システム日付を取得
	cSysDate := to_char(current_timestamp,'YYYYMMDD');
	-- 当預テーブル（送信用）の件数をチェック
	SELECT count(*) INTO STRICT nCount
	FROM   toyosend 
	WHERE  itaku_kaisha_cd = l_inItakuId 
	AND    kessai_no       = l_inKessaiNo 
	AND    data_shori_kbn  = l_inDataShoriKbn;
	-- 入金予定データが存在しない場合
	IF nCount = 0 THEN
		RETURN pkconstant.success();
	END IF;
	-- チェック、更新処理
	FOR recToyosend IN curToyosend LOOP
		-- ＩＦ区分とデータ区分の連結
		vData := recToyosend.if_kbn || ',' || recToyosend.data_kbn_smbc;
		-- 業務区分の連結
		vData := vData || ',' || recToyosend.gyomu_kbn_smbc;
		-- ＩＦ通番採番取得
		CALL SPIPFGETIFNO(nRtnCd, cGyoumuDt, cIfNo);
		-- ＩＦ通番採番取得関数でエラー
		IF nRtnCd <> 0 THEN
			CALL pkLog.error('ECM701', 'IPF010K01R04', MSG_GETIFNO_ERR);
			RETURN nRtnCd;
		END IF;
		-- ＩＦ通番の連結
		vData := vData || ',' || cIfNo;
		-- 当預約定暗号の連結
		vData := vData || ',' || recToyosend.toyo_yakujo_no;
		-- 当預約定詳細番号の連結
		vData := vData || ',' || recToyosend.toyo_yakujoshosai_no;
		-- データ処理区分の連結
		vData := vData || ',' || recToyosend.data_shori_kbn;
		-- 当預商品区分の連結
		vData := vData || ',' || recToyosend.toyo_shohin_kbn;
		-- 当預ステータス区分の連結
		vData := vData || ',' || recToyosend.toyo_stat_kbn;
		-- 約定相手予備区分の連結
		vData := vData || ',' || recToyosend.yakujo_aite_yobi_kbn;
		-- 約定相手金融機関コードの連結
		vData := vData || ',' || ' ';
		-- 決済日の連結
		vData := vData || ',' || recToyosend.kessai_ymd;
		-- 決済相手予備区分の連結
		vData := vData || ',' || recToyosend.kessai_aite_yobi_kbn;
		-- 決済相手金融機関コードの連結
		vData := vData || ',' || recToyosend.kessai_aite_bank_cd;
		-- 決済相手店舗コードの連結
		vData := vData || ',' || recToyosend.kessai_aite_tenpo_cd;
		-- 決済処理区分の連結
		vData := vData || ',' || recToyosend.kessai_shori_kbn;
		-- 決済方法区分の連結
		vData := vData || ',' || recToyosend.kessai_method_kbn;
		-- 決済予定時刻の連結
		vData := vData || ',' || recToyosend.kessai_yotei_tm;
		-- 勘定保有店番号の連結
		vData := vData || ',' || recToyosend.kanjo_hoyuten_no;
		-- 備考コードの連結
		vData := vData || ',' || ' ';
		-- 当預出入区分の連結
		vData := vData || ',' || recToyosend.toyo_deiri_kbn;
		-- 当預金額をＣＨＡＲ型に変換
		cToyoKngk  := to_char(recToyosend.toyo_kngk,'000000000000000000');
		-- 当預金額の連結
		vData := vData || ',' || trim(both cToyoKngk);
		-- ＤＶＰ区分の連結
		vData := vData || ',' || recToyosend.dvp_kbn_smbc;
		-- 自己代行区分の連結
		vData := vData || ',' || recToyosend.own_daiko_kbn;
		-- ベネフィシャリー予備区分の連結
		vData := vData || ',' || recToyosend.bene_yobi_kbn;
		-- ベネフィシャリー金融機関コードの連結
		vData := vData || ',' || ' ';
		-- 取込日の連結
		vData := vData || ',' || cGyoumuDt;
		-- 更新日の連結
		vData := vData || ',' || recToyosend.update_ymd;
		-- 更新時刻の連結
		vData := vData || ',' || recToyosend.update_tm;
		-- 更新担当者の連結
		vData := vData || ',' || recToyosend.update_tantosha;
		-- 決済番号の連結
		vData := vData || ',' || recToyosend.kessai_no;
		-- 取引種別の連結
		vData := vData || ',' || recToyosend.trhk_shubetsu_smbc;
		-- 当預リアル送信ＩＦテーブル更新処理
		INSERT INTO toyorealsndif(
			data_id,
			make_dt,
			data_seq,
			data_sect,
			sr_stat
		)
		VALUES (
			'13002',
			cSysDate,
			SUBSTR(cIfNo, 9, 8)::numeric,
			vData,
			'0'
		);
		-- 当預リアル送受信保存テーブル更新処理
		INSERT INTO toyorealsave(
			data_id,
			make_dt,
			data_seq,
			data_sect
		)
		VALUES (
			'13002',
			cSysDate,
			SUBSTR(cIfNo, 9, 8)::numeric,
			vData
		);
		-- 当預テーブル（送信用）更新処理
		UPDATE toyosend
		SET    send_flg        = '1', 
			   if_tsuban       = cIfNo, 
			   import_ymd      = cGyoumuDt
		WHERE  itaku_kaisha_cd = recToyosend.itaku_kaisha_cd
		AND    kessai_no       = l_inKessaiNo 
		AND    data_shori_kbn  = recToyosend.data_shori_kbn;
	END LOOP;
	RETURN pkconstant.success();
--==============================================================================
--                  エラー処理                                                  
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'IPF010K01R04', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf010k01r04 ( l_inItakuId toyosend.itaku_kaisha_cd%type, l_inKessaiNo toyosend.kessai_no%type, l_inDataShoriKbn toyosend.data_shori_kbn%type  ) FROM PUBLIC;
