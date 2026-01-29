




CREATE OR REPLACE FUNCTION sfipf013k01r04 () RETURNS numeric AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * ①JP1より起動され、帳票作成PG（発行代り金）、帳票作成PG（元金利・元利払手数料）、
-- * 　帳票作成PG（期中手数料）をCallする。
-- * ②当該処理は、夜間バッチにて起動される。（１回のみ）
-- * 
-- * @author 小網　由妃子
-- * @version $Revision: 1.5 $
-- * 
-- * @return NUMERIC
-- * 				0:正常終了、データ無し
-- * 				1:予期したエラー
-- * 				99:予期せぬエラー
-- * 
-- 
--==============================================================================
--					変数定義													
--==============================================================================
	nCount				numeric;									-- 件数カウンタ
	cChohyoId			char(11);								-- 帳票ＩＤ
	cGyoumuDt			text;								-- 業務日付
	cKnj_shori_ymd		text;								-- 処理日
	wk_kaiin			text;								-- 会員ＩＤ 
	HAKKO_eigyoDt		char(8);								-- NN営業日
	GANRI_eigyoDt		char(8);								-- NN営業日
	TESURYO_eigyoDt		char(8);								-- NN営業日
	nRtnCd				numeric;									-- リターンコード
	rtn1				text;									-- 呼び出しＳＰリターン値
	rtn2				text;									-- エラーメッセージ
	tmp_rtn1			integer;								-- CALL用一時変数
--==============================================================================
--					メイン処理													
--==============================================================================
BEGIN
	-- 業務日付を取得
	cGyoumuDt := pkDate.getGyomuYmd();
	-- 自行情報マスタより会員IDと各NN営業日を取得
	SELECT kaiin_id, hakko_eb_make_dd,ganri_eb_make_dd,tesuryo_eb_make_dd
	INTO STRICT wk_kaiin, HAKKO_eigyoDt,GANRI_eigyoDt,TESURYO_eigyoDt
	FROM sown_info;
	-- 処理日を取得 (if 0, use current date)
	IF trim(both HAKKO_eigyoDt) = '0' OR trim(both HAKKO_eigyoDt) = '' THEN
		cKnj_shori_ymd := cGyoumuDt;
	ELSE
		cKnj_shori_ymd := pkDate.getPlusDateBusiness(cGyoumuDt, HAKKO_eigyoDt);
	END IF;
	-- 発行代り金受渡状況確認リストにパラメータを引渡す
	tmp_rtn1 := 0;
	CALL SPIPF013K01R07(wk_kaiin, 'BATCH', '1', cGyoumuDt, cKnj_shori_ymd, tmp_rtn1, rtn2);
	rtn1 := tmp_rtn1::text;
		-- 戻り値が'１'の場合
		IF rtn1 = '1' THEN
			CALL pkLog.fatal(
				'ECM501',
				'IPF013K01R04',
				'発行代り金受渡状況確認リスト:パラメータエラー'
			);
			RETURN pkconstant.error();
		-- 戻り値が'99'の場合
		ELSIF rtn1 = '99' THEN
			CALL pkLog.fatal(
				'ECM701',
				'IPF013K01R04',
				'発行代り金受渡状況確認リスト:帳票出力エラー'
			);
			RETURN pkconstant.fatal();
		END IF;
		-- 戻り値が'0'または'40'の場合
		IF rtn1 IN ('0', '40') THEN
			cChohyoId := 'IPF30101321';
			SELECT f.l_inrtn1, f.l_inrtn2, f.l_outresult INTO rtn1, rtn2, nRtnCd
			FROM SFIPF013K01R04_CHOHYO_TOROKU('発行代り金', wk_kaiin, cGyoumuDt, cChohyoId, '', '') AS f;
		END IF;
	-- 処理日を取得
	IF trim(both GANRI_eigyoDt) = '0' OR trim(both GANRI_eigyoDt) = '' THEN
		cKnj_shori_ymd := cGyoumuDt;
	ELSE
		cKnj_shori_ymd := pkDate.getPlusDateBusiness(cGyoumuDt, GANRI_eigyoDt);
	END IF;
	-- 元利払・元利払手数料受渡状況確認リストにパラメータを引渡す
	tmp_rtn1 := 0;
	CALL SPIPF014K01R03(wk_kaiin, 'BATCH', '1', cGyoumuDt, cKnj_shori_ymd, tmp_rtn1, rtn2);
	rtn1 := tmp_rtn1::text;
		-- 戻り値が'1'の場合
		IF rtn1 = '1' THEN
			CALL pkLog.fatal(
				'ECM501',
				'IPF013K01R04',
				'元利払・元利払手数料受渡状況確認リスト:パラメータエラー'
			);
			RETURN pkconstant.error();
		-- 戻り値が'99'の場合
		ELSIF rtn1 = '99' THEN
			CALL pkLog.fatal(
				'ECM701',
				'IPF013K01R04',
				'元利払・元利払手数料受渡状況確認リスト:帳票出力エラー'
			);
			RETURN pkconstant.fatal();
		END IF;
		-- 戻り値が'0'または'40'の場合
		IF rtn1 IN ('0', '40') THEN
			cChohyoId := 'IPF30101411';
			SELECT f.l_inrtn1, f.l_inrtn2, f.l_outresult INTO rtn1, rtn2, nRtnCd
			FROM SFIPF013K01R04_CHOHYO_TOROKU('元利払・元利払', wk_kaiin, cGyoumuDt, cChohyoId, '', '') AS f;
		END IF;
	-- 処理日を取得
	IF trim(both TESURYO_eigyoDt) = '0' OR trim(both TESURYO_eigyoDt) = '' THEN
		cKnj_shori_ymd := cGyoumuDt;
	ELSE
		cKnj_shori_ymd := pkDate.getPlusDateBusiness(cGyoumuDt, TESURYO_eigyoDt);
	END IF;
	-- 手数料受渡状況確認リストにパラメータを引渡す
	tmp_rtn1 := 0;
	CALL SPIPF015K01R02(wk_kaiin, 'BATCH', '1', cGyoumuDt, cKnj_shori_ymd, tmp_rtn1, rtn2);
	rtn1 := tmp_rtn1::text;
		-- 戻り値が'１'の場合
		IF rtn1 = '1' THEN
				CALL pkLog.fatal(
					'ECM501',
					'IPF013K01R04',
					'手数料受渡状況確認リスト:パラメータエラー'
				);
				RETURN pkconstant.error();
		-- 戻り値が'99'の場合
		ELSIF rtn1 = '99' THEN
				CALL pkLog.fatal(
					'ECM701',
					'IPF013K01R04',
					'手数料受渡状況確認リスト:帳票出力エラー'
				);
				RETURN pkconstant.fatal();
		END IF;
		-- 戻り値が'0'または'40'の場合
		IF rtn1 IN ('0', '40') THEN
			cChohyoId := 'IPF30101511';
			SELECT f.l_inrtn1, f.l_inrtn2, f.l_outresult INTO rtn1, rtn2, nRtnCd
			FROM SFIPF013K01R04_CHOHYO_TOROKU('期中手数料', wk_kaiin, cGyoumuDt, cChohyoId, '', '') AS f;
		END IF;
	RETURN pkconstant.success();
--==============================================================================
--					エラー処理													
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'IPF013K01R04', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf013k01r04 () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipf013k01r04_chohyo_toroku ( l_inMsg text,			-- エラーメッセージ
 l_inWkKaiin text,		-- 会員ID
 l_inCGyoumuDt text,		-- 業務日付
 l_inCChohyoId text,	-- 帳票ID
 l_inRtn1 INOUT text,		-- 戻り値
 l_inRtn2 INOUT text,		-- エラーメッセージ
 l_outResult OUT numeric	-- 戻り値
 ) RETURNS record AS $body$
DECLARE
	nCount numeric;
BEGIN
--帳票ワークが登録されているかのチェックを行う
nCount := 0;
SELECT COUNT(*) INTO STRICT nCount
FROM   sreport_wk
WHERE key_cd = l_inWkKaiin
	  AND user_id = 'BATCH'
	  AND chohyo_kbn = '1'
	  AND sakusei_ymd = l_inCGyoumuDt
	  AND chohyo_id = l_inCChohyoId
	  AND header_flg = '1';
--データが存在しない場合、リターンコード'0'で返す
IF nCount = 0 THEN
	l_outResult := pkconstant.success();
	RETURN;
END IF;
--バッチ帳票印刷管理が既に作成済みであるかのチェックを行う
nCount := 0;
SELECT COUNT(*) INTO STRICT nCount
FROM   prt_ok
WHERE  itaku_kaisha_cd = l_inWkKaiin AND 
	   kijun_ymd = l_inCGyoumuDt	  AND
	   list_sakusei_kbn = '1'	  AND
	   chohyo_id = l_inCChohyoId;
--存在しない場合、バッチ帳票印刷管理の登録を行う
IF nCount = 0 THEN
	INSERT INTO prt_ok(
		itaku_kaisha_cd,
		kijun_ymd, 
		list_sakusei_kbn, 
		chohyo_id, 
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
		l_inWkKaiin, 
		l_inCGyoumuDt, 
		'1', 
		l_inCChohyoId, 
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
	l_outResult := pkconstant.success();
	RETURN;
--存在した場合、エラー処理を行う
ELSE
	l_inRtn1 := 'ECM507';
	l_inRtn2 := 'データが既に登録されています';
	CALL pkLog.fatal('ECM507', 'IPF013K01R04', 'データが既に登録されています'|| '(' || l_inMsg || ')');
	l_outResult := pkconstant.error();
	RETURN;
END IF;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf013k01r04_chohyo_toroku ( l_inMsg text, l_inWkKaiin char(4), l_inCGyoumuDt char(8), l_inCChohyoId char(11), l_inRtn1 INOUT char(6), l_inRtn2 INOUT varchar(300) ) FROM PUBLIC;
