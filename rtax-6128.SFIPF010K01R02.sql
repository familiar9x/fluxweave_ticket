




CREATE OR REPLACE FUNCTION sfipf010k01r02 ( l_inDenbunId TEXT,								-- ＪＩＰ電文コード
 l_inItakuId nyukin_yotei.itaku_kaisha_cd%type,	-- 委託会社コード
 l_inKessaiNo nyukin_yotei.kessai_no%type 			-- 決済番号
 ) RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 入金予定テーブルから、決算日当日朝処理までの当預データを作成する
-- * 
-- * @author 戸倉　一成
-- * @version $Revision: 1.11 $
-- * $Id: SFIPF010K01R02.sql,v 1.11 2005/12/15 08:28:42 koami Exp $
-- * @param  l_inDenbunId   IN     TEXT						ＪＩＰ電文コード
-- *         l_inItakuId    IN     TEXT						委託会社コード
-- *         l_inKessaiNo   IN     TEXT						決済番号
-- * @return INTEGER
-- *                0:正常終了、データ無し
-- *                1:予期したエラー
-- *               99:予期せぬエラー
-- 
--==============================================================================
--                  定数定義                                                    
--==============================================================================
	MSG_PARAM_ERROR      CONSTANT text := 'パラメーターエラー';
	MSG_R04_ERROR        CONSTANT text := 'リアル共有ＤＢＩＦ（送信）更新処理エラー';
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	nRtnCd        numeric;									-- リターン値
	nCount        numeric;									-- 件数カウンタ
	nSqlCode	  numeric;									-- ＳＱＬコード
	cGyoumuDt     sreport_wk.sakusei_ymd%type;				-- 業務日付
	cSysDate      char(8);									-- システム日付
	cSysTime      char(9);									-- システム時刻
	cDateShoriKbn char(1);									-- データ処理区分
	cKonai_stat   toyokonaiif.konaiif_connect_stat%type;	-- 行内ＩＦ接続ステータス
	vSqlErrM	  varchar(1000);							-- ＳＱＬエラーメッセージ
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 入力パラメータ（ＪＩＰ電文コード）のチェック
	IF coalesce(trim(both l_inDenbunId)::text, '') = '' THEN
		CALL pkLog.error('ECM501', 'IPF010K01R02', '＜項目名称:ＪＩＰ電文コード＞' || '＜項目値:' || l_inDenbunId || '＞');
		RETURN pkconstant.error();
	END IF;
	-- 入力パラメータ（委託会社コード）のチェック
	IF coalesce(trim(both l_inItakuId)::text, '') = '' THEN
		CALL pkLog.error('ECM501', 'IPF010K01R02', '＜項目名称:委託会社コード＞' || '＜項目値:' || l_inItakuId || '＞');
		RETURN pkconstant.error();
	END IF;
	-- 入力パラメータ（決済番号）のチェック
	IF coalesce(trim(both l_inKessaiNo)::text, '') = '' THEN
		CALL pkLog.error('ECM501', 'IPF010K01R02', '＜項目名称:決済番号＞' || '＜項目値:' || l_inKessaiNo || '＞');
		RETURN pkconstant.error();
	END IF;
	-- 業務日付を取得
	cGyoumuDt := pkDate.getGyomuYmd();
	-- システム日付を取得
	cSysDate := TO_CHAR(current_timestamp,'YYYYMMDD');
	-- システム時刻を取得
	cSysTime := TO_CHAR(current_timestamp,'HH24MISS') || '000';
	-- 入金予定データの有無をチェック
	nCount := 0;
	SELECT count(*) INTO STRICT nCount
	FROM   nyukin_yotei,sown_info 
	WHERE  itaku_kaisha_cd              = l_inItakuId 
	AND    kessai_no                    = l_inKessaiNo 
	AND    nyukin_yotei.dvp_kbn         = '1' 
	AND    nyukin_yotei.itaku_kaisha_cd = sown_info.kaiin_id;
	-- 入金予定データが存在しない場合
	IF nCount = 0 THEN
		RETURN pkconstant.success();
	END IF;
	-- 行内IF管理情報テーブルのステータス確認
	cKonai_stat := '';
	SELECT konaiif_connect_stat
	INTO STRICT cKonai_stat
	FROM toyokonaiif;
	-- 行内IF接続ステータスが'0'である場合
	IF cKonai_stat = '0' THEN
		-- ログ出力
		CALL pkLog.error(
			'EIP511',
			'IPF010K01R02',
			'＜決済番号:' || l_inKessaiNo || '＞'
		);
		-- エラーリスト書き込み
			CALL SPIPF001K00R01(
				l_inItakuId,
				'BATCH', 
				'1', 
				'3', 
				cGyoumuDt, 
				'53', 
				'9999999999', 
				'決済番号', 
				l_inKessaiNo, 
				'EIP511', 
				nSqlCode, 
				vSqlErrM
			);
		-- メッセージ通知テーブルへ書き込み
		nRtnCd := SfIpMsgTsuchiUpdate(
					l_inItakuId,
					'RTGS',
					'重要',
					'1',
					'0',
					'閉局電文送信終了しているため、送信対象外です。＜決済番号：' || l_inKessaiNo || '＞',
					'BATCH',
					'BATCH');
		IF nRtnCd != 0 THEN
			CALL pkLog.fatal('ECM701', 'IPF010K01R02', 'メッセージ通知登録エラー');
			RETURN nRtnCd;
		END IF;
		RETURN pkconstant.error();
	END IF;
	IF cKonai_stat >= '1' THEN
		IF l_inDenbunId != 'R0111' THEN
		--当預テーブル（送信用）のデータ有無をチェック
			nCount := 0;
			SELECT COUNT(*) INTO STRICT nCount
			FROM   toyosend
			WHERE  itaku_kaisha_cd			= l_inItakuId
			AND    kessai_no				= l_inKessaiNo
			AND    update_ymd				= cSysDate
			AND    kessai_ymd			   != cGyoumuDt;
		--対象データが存在した場合は削除
			IF nCount != 0 THEN
				DELETE FROM toyosend
				WHERE  itaku_kaisha_cd			= l_inItakuId
				AND    kessai_no				= l_inKessaiNo
				AND    update_ymd				= cSysDate
				AND    kessai_ymd			   != cGyoumuDt;
				RETURN pkconstant.success();
			END IF;
		END IF;
		-- ＪＩＰ電文コードにより処理区分を判別
		IF l_inDenbunId = 'R0111' THEN
			cDateShoriKbn := '1';
		ELSE
			cDateShoriKbn := '3';
		END IF;
		-- 当預テーブル（送信用）更新処理
		INSERT INTO toyosend(
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
			kessai_ymd,
			kessai_aite_yobi_kbn,
			kessai_aite_bank_cd,
			kessai_aite_tenpo_cd,
			kessai_shori_kbn,
			kessai_method_kbn,
			kessai_yotei_tm,
			kanjo_hoyuten_no,
			toyo_deiri_kbn,
			toyo_kngk,
			dvp_kbn_smbc,
			own_daiko_kbn,
			update_ymd,
			update_tm,
			trhk_shubetsu_smbc,
			nyushukin_joukyou,
			send_flg,
			kousin_dt,
			kousin_id,
			sakusei_dt,
			sakusei_id
		)
		SELECT
			nyukin_yotei.itaku_kaisha_cd,
			nyukin_yotei.kessai_no,
			cDateShoriKbn,
			'A1',
			'01',
			'R2',
			nyukin_yotei.kessai_no,
			'00',
			'467',
			'30',
			nyukin_yotei.kessai_ymd,
			'0',
			'00' || nyukin_yotei.skn_shrnin_bcd,
			'0' || nyukin_yotei.skn_shrnin_scd,
			'02',
			'01',
			nyukin_yotei.kessai_jigen || '00000',
			'0922',
			'02',
			nyukin_yotei.kessai_kngk,
			'01',
			'1',
			cSysDate,
			cSysTime,
			'21',
			'1',
			'0',
			current_timestamp,
			'BATCH',
			current_timestamp,
			'BATCH' 
		FROM 
			nyukin_yotei,sown_info 
		WHERE itaku_kaisha_cd              = l_inItakuId 
		AND   kessai_no                    = l_inKessaiNo 
		AND   nyukin_yotei.dvp_kbn         = '1' 
		AND   nyukin_yotei.itaku_kaisha_cd = sown_info.kaiin_id;
		-- 入金予定テーブルのデータの有無をチェック
		nCount := 0;
		SELECT COUNT(*)
		INTO STRICT   nCount
		FROM   nyukin_yotei
		WHERE  itaku_kaisha_cd              = l_inItakuId
		AND    kessai_no                    = l_inKessaiNo 
		AND    kessai_ymd                   = cGyoumuDt;
		-- データが存在した場合、リアル共有ＤＢＩＦ（送信）更新（日中処理分データ）
		IF nCount != 0 THEN
			nRtnCd := SFIPF010K01R04(l_inItakuId, l_inKessaiNo, cDateShoriKbn);
		END IF;
		-- リアル共有ＤＢＩＦ（送信）更新（日中処理分データ）で例外エラー
		IF nRtnCd = 99 THEN
			CALL pkLog.error('ECM701', 'IPF010K01R02', MSG_R04_ERROR);
		END IF;
	END IF;
	RETURN nRtnCd;
--==============================================================================
--                  エラー処理                                                  
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'IPF010K01R02', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf010k01r02 ( l_inDenbunId TEXT, l_inItakuId nyukin_yotei.itaku_kaisha_cd%type, l_inKessaiNo nyukin_yotei.kessai_no%type  ) FROM PUBLIC;
