




CREATE OR REPLACE FUNCTION sfipf011k01r01 () RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 元利金請求明細テーブルの内容を基に、
-- * 決済日当日処理までの当預データを作成する
-- * 
-- * @author 小林　弘幸
-- * @version $Revision: 1.7 $
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
	nCount    numeric;										   -- カウント数格納用
	cGyoumuDt char(8);										   -- 業務日付格納用
	wCount    numeric;										   -- 存在チェック用
	wKessai_no char(16);										   -- 決済番号
--==============================================================================
--                  カーソル定義                                                
--==============================================================================
	curToyoData CURSOR FOR
			SELECT
				G.kessai_no AS kessai_no,  -- 決済番号
				MAX(G.itaku_kaisha_cd) AS itaku_kaisha_cd,	 -- 委託会社コード
				MAX(G.shr_ymd) AS shr_ymd,			 -- 支払日
				MAX(G.aite_skn_kessai_bcd) AS aite_skn_kessai_bcd,	 -- 金融機関コード(相手方資金決済会社)
				MAX(G.aite_skn_kessai_scd) AS aite_skn_kessai_scd,	 -- 支店コード(相手方資金決済会社)
				SUM(G.gzeihiki_aft_chokyu_kngk + G.shokan_seikyu_kngk) AS toyogk,  -- 国税引後利金請求金額 + 償還金請求金額
				MAX(S.ganri_kessai_jigen) AS ganri_kessai_jigen,	   -- 元利払要決済時限
				COUNT(*) AS rec_count
			FROM
				kikin_seikyu G,
				(SELECT	K01.ITAKU_KAISHA_CD,
						K01.MGR_CD,
						K01.SHR_YMD AS RBR_YMD
				FROM	 KIKIN_SEIKYU	K01
				WHERE	 pkDate.getMinusDateBusiness(K01.SHR_YMD, 1) = cGyoumuDt
				 AND	 K01.DVP_KBN = '1'
				GROUP BY K01.ITAKU_KAISHA_CD,
						 K01.MGR_CD,
						 K01.SHR_YMD
				EXCEPT
				SELECT	K01.ITAKU_KAISHA_CD,
						K01.MGR_CD,
						K01.SHR_YMD AS RBR_YMD
				FROM	 KIKIN_SEIKYU	K01,
					 KIKIN_IDO K02
				WHERE	K01.ITAKU_KAISHA_CD = K02.ITAKU_KAISHA_CD
				 AND	 K01.MGR_CD = K02.MGR_CD
				 AND	 K01.SHR_YMD = K02.RBR_YMD
				 AND	 pkDate.getMinusDateBusiness(K01.SHR_YMD, 1) = cGyoumuDt
				 AND	 K01.DVP_KBN = '1'
				 AND	 K02.TSUKA_CD = 'JPY'
				 AND	 K02.KKN_IDO_KBN IN ('11','21')
				 AND (K01.KOBETSU_SHONIN_SAIYO_FLG = 'Y' OR (K01.KOBETSU_SHONIN_SAIYO_FLG = 'N' AND K02.DATA_SAKUSEI_KBN = '0'))
				 AND	 K02.SHORI_KBN = '0' ) K,
				sown_info S
			WHERE G.itaku_kaisha_cd = K.itaku_kaisha_cd
			AND   G.mgr_cd = K.mgr_cd
			AND   G.shr_ymd = K.rbr_ymd
			AND   G.itaku_kaisha_cd = S.kaiin_id
			AND   pkDate.getMinusDateBusiness(G.shr_ymd, 1) = cGyoumuDt
			AND   G.dvp_kbn = '1' 
			GROUP BY
				G.kessai_no;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 業務日付を取得
	cGyoumuDt := pkDate.getGyomuYmd();
	-- 当預データ作成
	nCount := 0;
	FOR recToyoData IN curToyoData LOOP
	-- 元利金請求明細の該当データの存在チェック
		SELECT
			kessai_no,
			COUNT(kessai_no)
		INTO STRICT	wKessai_no,
			wCount
		FROM	kikin_seikyu
		WHERE	kessai_no = recToyoData.kessai_no
		GROUP BY
			kessai_no;
		IF recToyoData.rec_count = wCount THEN
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
		VALUES(
			recToyoData.itaku_kaisha_cd,
			recToyoData.kessai_no,
			'1',
			'A1',
			'01',
			'R2',
			recToyoData.kessai_no,
			'00',
			'468',
			'30',
			recToyoData.shr_ymd,
			'0',
			('00' || recToyoData.aite_skn_kessai_bcd),
			('0' || recToyoData.aite_skn_kessai_scd),
			'01',
			'01',
			(recToyoData.ganri_kessai_jigen || '00000'),
			'0922',
			'01',
			recToyoData.toyogk,
			'01',
			'1',
			TO_CHAR(current_timestamp, 'YYYYMMDD'),
			(SUBSTR(TO_CHAR(current_timestamp, 'YYYYMMDDHH24MISS'), 9) || '000'),
			'23',
			'3',
			'0',
			current_timestamp,
			'BATCH',
			current_timestamp,
			'BATCH');
		nCount := nCount + 1;
		END IF;
	END LOOP;
	IF nCount = 0 THEN
		RETURN pkconstant.success();
	END IF;
	RETURN pkconstant.success();
--==============================================================================
--                  エラー処理                                                  
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		-- ログ出力
		CALL pkLog.fatal(
			'ECM701',
			'IPF011K01R01',
			'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')'
		);
		RETURN pkconstant.FATAL();
--		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf011k01r01 () FROM PUBLIC;
