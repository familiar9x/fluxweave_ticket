




CREATE OR REPLACE FUNCTION sfitretrydata () RETURNS numeric AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * ①勘定系発行代り金IF、勘定系元利金・手数料IFの再処理フラグ = '1'のデータを抽出し、
-- * 勘定系発行代り金IF、勘定系元利金・手数料IFを新規に作成する。（受付通番（内部）を取得）
-- * 
-- * ②作成したもとの勘定系発行代り金IF、勘定系元利金・手数料IFの再処理フラグを'9'にする。
-- * 
-- * @author 小網　由妃子
-- * @version $Revision: 1.1 $
-- * 
-- 
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	nCount      numeric;							-- 件数カウンタ
	nUkeNo      text;							-- 受付通番
	nRtnCd      integer;							-- リターン値
	cInOutFlg	TEXT;
	cTorikeshi	TEXT;
--==============================================================================
--                  カーソル定義                                                
--==============================================================================
	curKnjHakkou CURSOR FOR
		SELECT 
			itaku_kaisha_cd,
			knj_azuke_no,
			knj_shori_ymd,
			knj_shori_kbn,
			knj_ten_no,
			knj_kamoku,
			knj_kouza_no,
			knj_hrkm_kngk,
			knj_inout_kbn,
			knj_chukeimsgid,
			mgr_cd,
			knj_uke_tsuban,
			knj_chukei_tsuban, 
			knj_torikeshi_flg 
		FROM knjhakkouif 
		WHERE knj_saishori_flg = '1'
		ORDER BY itaku_kaisha_cd, knj_uke_tsuban_naibu;
	curKnjGanrikichu CURSOR FOR
		SELECT 
			itaku_kaisha_cd,
			knj_azuke_no,
			knj_shori_ymd,
			knj_shori_kbn,
			knj_tesuryo_kbn,
			knj_ten_no,
			knj_kamoku,
			knj_kouza_no,
			knj_gankin,
			knj_rkn,
			knj_gnkn_shr_tesu_kngk,
			knj_rkn_shr_tesu_kngk,
			knj_kingaku,
			knj_shohizei,
			knj_inout_kbn,
			knj_chukeimsgid,
			knj_uke_tsuban,
			hkt_cd,
			knj_chukei_tsuban ,
			knj_torikeshi_flg 
		FROM knjganrikichuif 
		WHERE knj_saishori_flg = '1'
		ORDER BY itaku_kaisha_cd, knj_uke_tsuban_naibu;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 勘定系IF（発行代り金）の再処理フラグ＝'1'のデータを取得する。
	FOR recKnjHakkou IN curKnjHakkou LOOP
		--受付通番（内部）を取得する。
		CALL SPIPFGETUKENO('1'::text, nUkeNo, nRtnCd);
		cTorikeshi := recKnjHakkou.knj_torikeshi_flg;
		IF cTorikeshi = '1' THEN
			cInOutFlg := '3';
		ELSE
			cInOutFlg := recKnjHakkou.knj_inout_kbn;
		END IF;
		INSERT INTO knjhakkouif(
			itaku_kaisha_cd,
			knj_uke_tsuban_naibu,
			knj_azuke_no,
			knj_shori_ymd,
			knj_shori_kbn,
			knj_ten_no,
			knj_kamoku,
			knj_kouza_no,
			knj_hrkm_kngk,
			knj_inout_kbn,
			knj_chukeimsgid,
			mgr_cd,
			knj_uke_tsuban_zenkai,
			knj_chukei_tsuban_zenkai,
			knj_torikeshi_flg,
			kousin_id,
			sakusei_id
		)
		VALUES (
			recKnjHakkou.itaku_kaisha_cd,
			nUkeNo::numeric,
			recKnjHakkou.knj_azuke_no,
			recKnjHakkou.knj_shori_ymd,
			recKnjHakkou.knj_shori_kbn,
			recKnjHakkou.knj_ten_no,
			recKnjHakkou.knj_kamoku,
			recKnjHakkou.knj_kouza_no,
			recKnjHakkou.knj_hrkm_kngk,
			cInOutFlg,
			recKnjHakkou.knj_chukeimsgid,
			recKnjHakkou.mgr_cd,
			recKnjHakkou.knj_uke_tsuban,
			recKnjHakkou.knj_chukei_tsuban,
			recKnjHakkou.knj_torikeshi_flg,
			'BATCH',
			'BATCH' 
		);
	END LOOP;
	-- 勘定系IF（発行代り金）の再処理フラグ＝'1'のデータを'9'に更新する。
	UPDATE knjhakkouif
	SET knj_saishori_flg = '9'
	WHERE knj_saishori_flg = '1';
	-- 勘定系元利金・手数料の再処理フラグ＝'1'のデータを取得する。
	FOR recKnjGanrikichu IN curKnjGanrikichu LOOP
		--受付通番（内部）を取得する。
		CALL SPIPFGETUKENO('1'::text, nUkeNo, nRtnCd);
		cTorikeshi := recKnjGanrikichu.knj_torikeshi_flg;
		IF cTorikeshi = '1' THEN
			cInOutFlg := '3';
		ELSE
			cInOutFlg := recKnjGanrikichu.knj_inout_kbn;
		END IF;
		INSERT INTO knjganrikichuif(
			itaku_kaisha_cd,
			knj_uke_tsuban_naibu,
			knj_azuke_no,
			knj_shori_ymd,
			knj_shori_kbn,
			knj_tesuryo_kbn,
			knj_ten_no,
			knj_kamoku,
			knj_kouza_no,
			knj_gankin,
			knj_rkn,
			knj_gnkn_shr_tesu_kngk,
			knj_rkn_shr_tesu_kngk,
			knj_kingaku,
			knj_shohizei,
			knj_inout_kbn,
			knj_chukeimsgid,
			knj_uke_tsuban_zenkai,
			hkt_cd,
			knj_chukei_tsuban_zenkai,
			knj_torikeshi_flg,
			kousin_id,
			sakusei_id
		)
		VALUES (
			recKnjGanrikichu.itaku_kaisha_cd,
			nUkeNo::numeric,
			recKnjGanrikichu.knj_azuke_no,
			recKnjGanrikichu.knj_shori_ymd,
			recKnjGanrikichu.knj_shori_kbn,
			recKnjGanrikichu.knj_tesuryo_kbn,
			recKnjGanrikichu.knj_ten_no,
			recKnjGanrikichu.knj_kamoku,
			recKnjGanrikichu.knj_kouza_no,
			recKnjGanrikichu.knj_gankin,
			recKnjGanrikichu.knj_rkn,
			recKnjGanrikichu.knj_gnkn_shr_tesu_kngk,
			recKnjGanrikichu.knj_rkn_shr_tesu_kngk,
			recKnjGanrikichu.knj_kingaku,
			recKnjGanrikichu.knj_shohizei,
			cInOutFlg,
			recKnjGanrikichu.knj_chukeimsgid,
			recKnjGanrikichu.knj_uke_tsuban,
			recKnjGanrikichu.hkt_cd,
			recKnjGanrikichu.knj_chukei_tsuban, 
			recKnjGanrikichu.knj_torikeshi_flg,
			'BATCH',
			'BATCH' 
		);
	END LOOP;
	-- 勘定系IF（発行代り金）の再処理フラグ＝'1'のデータを'9'に更新する。
	UPDATE knjganrikichuif
	SET knj_saishori_flg = '9'
	WHERE knj_saishori_flg = '1';
	RETURN pkconstant.success();
--==============================================================================
--                  エラー処理                                                  
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'ITRetryData', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfitretrydata () FROM PUBLIC;