




CREATE OR REPLACE FUNCTION sfipf009k00r05 ( l_inJobkbn TEXT 				-- 営業日・非営業日判別区分
 ) RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 店CIF予約テーブルにもとに、発行体テーブルを更新する。
-- * 同時に、結果リストに処理結果を追加する。
-- * 
-- * @author 小林　弘幸
-- * @version $Revision: 1.8 $
-- * $Id: SFIPF009K00R05.sql,v 1.8 2005/12/14 02:26:47 kobayashi Exp $
-- * @return INTEGER
-- *				  0:正常終了、データ無し
-- *				  1:予期したエラー
-- *				 99:予期せぬエラー
-- 
--==============================================================================
--					変数定義													
--==============================================================================
	nRet				 numeric;								-- 戻り値
	nRetf				 numeric;								-- 内部ファンクション戻り値
	nCount				 numeric;								-- レコード数
	nCount2				 numeric;								-- レコード数2
	nMax_Seq			 numeric;								-- 連番
	cFil_flg			 TEXT;								-- フィルタ用フラグ
	cBd_flg 			 TEXT;								-- 専用別段口座用フラグ
	cHkt_flg			 TEXT;								-- 発行体預金口座用フラグ
	cHko_flg			 TEXT;								-- 自動引落口座用フラグ
	cKoza_shubetsu		 TEXT;								-- 口座種別
	cErr_flg			 TEXT;								-- エラーフラグ
	cSeq_flg			 TEXT;								-- SEQ_NO用フラグ
	cOld_kamoku_cd		 TEXT;								-- 旧科目コード
	cNew_kamoku_cd		 TEXT;								-- 新科目コード
	cPlusTekiyo_Ymd 	 TEXT;								-- 適用開始日（＋）
	cRcv_dt 			 TEXT;								-- データ受信日
	cItaku_kaisha_cd	 sown_info.kaiin_id%type;				-- 委託会社コード
	cGyoumuDt			 ssystem_management.gyomu_ymd%type; 	-- 業務日付格納用
	cHkt_cd 			 TEXT; 				-- 発行体コード
	cErr_cd 			 kozajyohokoshin_list_wk.err_cd_6%type; -- エラーコード
	cTekiyost_ymd		 TEXT;		-- 運用開始日
	cOld_koza_ten_cd	 TEXT;	-- 旧口座店コード
	cOld_koza_ten_cifcd  TEXT; -- 旧口座店ＣＩＦコード
	cOld_koza_kamoku	 TEXT;	-- 旧口座科目
	cOld_koza_no		 TEXT;		-- 旧口座番号
	cNew_koza_ten_cd	 TEXT;	-- 新口座店コード
	cNew_koza_ten_cifcd  TEXT; -- 新口座店ＣＩＦコード
	cNew_koza_kamoku	 TEXT;	-- 新口座科目
	cNew_koza_no		 TEXT;		-- 新口座番号
	cFilter_shubetu 	 TEXT; 	-- フィルタ種別
	vMsg				 TEXT; 						-- エラーメッセージ
	vLmsg				 TEXT; 						-- ログ用メッセージ
	vTmsg				 TEXT; 						-- 通知用メッセージ
	WARNING				 CONSTANT integer := 2;					-- 定数
--==============================================================================
--					カーソル定義												
--==============================================================================
	-- 店CIF予約テーブルから対象データを抽出
	curYoyakuDS CURSOR FOR
		SELECT
			itaku_kaisha_cd,
			tekiyost_ymd,
			old_koza_ten_cd,
			old_koza_ten_cifcd,
			old_koza_kamoku,
			old_koza_no,
			new_koza_ten_cd,
			new_koza_ten_cifcd,
			new_koza_kamoku,
			new_koza_no,
			filter_shubetu,
			data_recv_ymd,
			make_dt
		FROM
			tencif_yoyaku;
	-- 旧科目科目コードが'S'の場合
	curKamoku_S CURSOR(wk_itaku_kaisha_cd	  TEXT,
						wk_old_koza_ten_cd	  TEXT,
						wk_old_koza_ten_cifcd TEXT) FOR
		SELECT
			hkt_cd
		FROM
			mhakkotai
		WHERE itaku_kaisha_cd = wk_itaku_kaisha_cd
		AND koza_ten_cd = wk_old_koza_ten_cd
		AND koza_ten_cifcd = wk_old_koza_ten_cifcd
		GROUP BY hkt_cd;
	-- 専用別段口座更新用（旧科目科目コードが'S'でない場合）
	curBD_hkt1 CURSOR(wk_itaku_kaisha_cd TEXT,
					   wk_old_koza_ten_cd TEXT,
					   wk_old_koza_kamoku TEXT,
					   wk_old_koza_no TEXT) FOR
		SELECT
			hkt_cd
		FROM
			mhakkotai
		WHERE itaku_kaisha_cd = wk_itaku_kaisha_cd
		AND koza_ten_cd = wk_old_koza_ten_cd
		AND bd_koza_kamoku_cd = wk_old_koza_kamoku
		AND bd_koza_no = wk_old_koza_no
		GROUP BY hkt_cd;
	-- 発行体預金口座更新用（旧科目科目コードが'S'でない場合）
	curHKT_hkt1 CURSOR(wk_itaku_kaisha_cd TEXT,
						wk_old_koza_ten_cd TEXT,
						wk_old_koza_kamoku TEXT,
						wk_old_koza_no TEXT) FOR
		SELECT
			hkt_cd
		FROM
			mhakkotai
		WHERE itaku_kaisha_cd = wk_itaku_kaisha_cd
		AND koza_ten_cd = wk_old_koza_ten_cd
		AND hkt_koza_kamoku_cd = wk_old_koza_kamoku
		AND hkt_koza_no = wk_old_koza_no
		GROUP BY hkt_cd;
	-- 自動引落口座更新用（旧科目科目コードが'S'でない場合）
	curHKO_hkt1 CURSOR(wk_itaku_kaisha_cd TEXT,
						wk_old_koza_ten_cd TEXT,
						wk_old_koza_kamoku TEXT,
						wk_old_koza_no TEXT) FOR
		SELECT
			hkt_cd
		FROM
			mhakkotai
		WHERE itaku_kaisha_cd = wk_itaku_kaisha_cd
		AND koza_ten_cd = wk_old_koza_ten_cd
		AND hko_kamoku_cd = wk_old_koza_kamoku
		AND hko_koza_no = wk_old_koza_no
		GROUP BY hkt_cd;
--==============================================================================
--					メイン処理													
--==============================================================================
BEGIN
	-- 業務日付を取得
	cGyoumuDt := pkDate.getGyomuYmd();
	cPlusTekiyo_Ymd  := pkDate.getPlusDateBusiness(cGyoumuDt, 1);
	-- 委託会社コード取得
	SELECT kaiin_id
	INTO STRICT cItaku_Kaisha_Cd
	FROM sown_info;
	-- 口座情報更新リストワークの最大連番を取得
	nCount := 0;
	SELECT count(*)
	INTO STRICT nCount
	FROM kozajyohokoshin_list_wk
	WHERE itaku_kaisha_cd = cItaku_Kaisha_Cd;
	-- ０件の場合、ｎ連番は０をセット
	IF nCount = 0 THEN
		nMax_Seq := 0;
	ELSE
		SELECT MAX(seq_no)
		INTO STRICT nMax_Seq
		FROM kozajyohokoshin_list_wk
		WHERE itaku_kaisha_cd = cItaku_Kaisha_Cd;
	END IF;
	-- 店ＣＩＦ予約テーブルからデータを抽出する
	nCount := 0;
	SELECT count(*)
	INTO STRICT nCount
	FROM tencif_yoyaku;
	-- データが無い場合
	IF nCount = 0 THEN
		RETURN pkconstant.success();
	END IF;
	-- データがある場合
	FOR recYoyakuDS IN curYoyakuDS LOOP
		-- 変数初期化
		vMsg := '';
		vLmsg := '';
		vTmsg := '';
		cErr_flg := '';
		cKoza_shubetsu := '';
		cFil_flg := '';
		cBd_flg := '0';
		cHkt_flg := '0';
		cHko_flg := '0';
		cSeq_flg := '0';
		cRcv_dt := recYoyakuDS.data_recv_ymd;
		-- 営業日の場合
		IF l_inJobkbn = '0' THEN
			IF cGyoumuDt <= recYoyakuDS.tekiyost_ymd::TEXT
			AND recYoyakuDS.tekiyost_ymd < cPlusTekiyo_Ymd THEN
				cFil_flg := '1';
			END IF;
		ELSE
			IF cGyoumuDt < recYoyakuDS.tekiyost_ymd::TEXT
			AND recYoyakuDS.tekiyost_ymd <= cPlusTekiyo_Ymd THEN
				cFil_flg := '1';
			END IF;
		END IF;
		-- フィルタフラグが'1'の場合のみ以下の処理を行う
		IF cFil_flg = '1' THEN
			-- 発行体マスタ存在チェック
			nCount := 0;
			SELECT count(hkt_cd)
			INTO STRICT nCount
			FROM mhakkotai
			WHERE itaku_kaisha_cd = recYoyakuDS.itaku_kaisha_cd::TEXT
			AND koza_ten_cd = recYoyakuDS.old_koza_ten_cd::TEXT
			AND trim(both koza_ten_cifcd) = trim(both recYoyakuDS.old_koza_ten_cifcd);
			-- 発行体マスタに該当データが存在する場合、更新処理を行う
			IF nCount != 0 THEN
				-- 旧科目コードが'S'の場合
				IF recYoyakuDS.old_koza_kamoku = 'S' THEN
					FOR recKamoku_S IN curKamoku_S(recYoyakuDS.itaku_kaisha_cd::TEXT,
												   recYoyakuDS.old_koza_ten_cd::TEXT,
												   recYoyakuDS.old_koza_ten_cifcd) LOOP
						-- 発行体コードを取得
						cHkt_cd := ' ';
						cHkt_cd := recKamoku_S.hkt_cd;
						-- 発行体コードの承認チェック
						nRetf := 0;
						SELECT * INTO nMax_Seq, cSeq_flg, cErr_flg, cErr_cd, cKoza_shubetsu, vMsg, vLmsg, vTmsg, nRetf
						FROM SFIPF009K00R05_EXIST_HKT_CD(
									recYoyakuDS.itaku_kaisha_cd::TEXT,
									cHkt_cd,
									recYoyakuDS.make_dt::TEXT,
									recYoyakuDS.tekiyost_ymd::TEXT,
									recYoyakuDS.old_koza_ten_cd::TEXT,
									recYoyakuDS.old_koza_ten_cifcd::TEXT,
									recYoyakuDS.old_koza_kamoku::TEXT,
									recYoyakuDS.old_koza_no::TEXT,
									recYoyakuDS.new_koza_ten_cd::TEXT,
									recYoyakuDS.new_koza_ten_cifcd::TEXT,
									recYoyakuDS.new_koza_kamoku::TEXT,
									recYoyakuDS.new_koza_no::TEXT,
									recYoyakuDS.filter_shubetu::TEXT,
									nMax_Seq,
									cSeq_flg,
									cHkt_cd,
									cErr_flg,
									cErr_cd,
									cKoza_shubetsu,
									vMsg,
									vLmsg,
									vTmsg,
									cRcv_dt,
									WARNING
								 );
						-- 発行体マスタが承認済み（部店マスタなしも含め）の場合
						IF nRetf = 0 OR	nRetf = WARNING	THEN
							UPDATE mhakkotai
							SET koza_ten_cd = recYoyakuDS.new_koza_ten_cd::TEXT,
							koza_ten_cifcd = recYoyakuDS.new_koza_ten_cifcd::TEXT,
							last_teisei_dt = current_timestamp,
							last_teisei_id = 'BATCH',
							kousin_id = 'BATCH'
							WHERE itaku_kaisha_cd = recYoyakuDS.itaku_kaisha_cd::TEXT
							AND hkt_cd = cHkt_cd
							AND koza_ten_cd = recYoyakuDS.old_koza_ten_cd::TEXT
							AND koza_ten_cifcd = recYoyakuDS.old_koza_ten_cifcd;
						END IF;
						-- 発行体マスタが承認済みの場合
						IF nRetf = 0 THEN
							-- 口座情報更新リストワークに追加
							vMsg := ' ';
							cErr_flg := '0';
							cErr_cd := ' ';
							cKoza_shubetsu := ' ';
						nRet := -1; -- Initialize to impossible value
						BEGIN
							SELECT * INTO nMax_Seq, cSeq_flg, nRet
							FROM SFIPF009K00R05_COMMON_FUNC(
										recYoyakuDS.itaku_kaisha_cd::TEXT,
										recYoyakuDS.make_dt::TEXT,
										recYoyakuDS.tekiyost_ymd::TEXT,
										recYoyakuDS.old_koza_ten_cd::TEXT,
										recYoyakuDS.old_koza_ten_cifcd::TEXT,
										' '::TEXT,
										' '::TEXT,
										recYoyakuDS.new_koza_ten_cd::TEXT,
										recYoyakuDS.new_koza_ten_cifcd::TEXT,
										' '::TEXT,
										' '::TEXT,
										recYoyakuDS.filter_shubetu::TEXT,
										nMax_Seq,
										cSeq_flg::TEXT,
										cHkt_cd::TEXT,
										cKoza_shubetsu::TEXT,
										cRcv_dt::TEXT,
										cErr_flg::TEXT,
										cErr_cd::TEXT,
										vMsg::TEXT,
										vLmsg::TEXT,
										vTmsg::TEXT,
										'重要'::TEXT,
										'EIPXXX'::TEXT
									);
						EXCEPTION WHEN OTHERS THEN
							nRet := pkconstant.fatal();
						END;
						IF nRet = pkconstant.fatal() THEN
								RETURN nRet;
							END IF;
						END IF;
					END LOOP;
				-- 旧科目コードが'S'でない場合
				ELSE
					-- 専用別段口座の更新
					FOR recBD_hkt1 IN curBD_hkt1(recYoyakuDS.itaku_kaisha_cd::TEXT,
												 recYoyakuDS.old_koza_ten_cd::TEXT,
												 recYoyakuDS.old_koza_kamoku::TEXT,
												 recYoyakuDS.old_koza_no) LOOP
						-- 発行体コードを取得
						cHkt_cd := ' ';
						cHkt_cd := recBD_hkt1.hkt_cd;
						-- 発行体コードの承認チェック
						nRetf := 0;
						SELECT * INTO nMax_Seq, cSeq_flg, cErr_flg, cErr_cd, cKoza_shubetsu, vMsg, vLmsg, vTmsg, nRetf
						FROM SFIPF009K00R05_EXIST_HKT_CD(
									recYoyakuDS.itaku_kaisha_cd::TEXT,
									cHkt_cd,
									recYoyakuDS.make_dt::TEXT,
									recYoyakuDS.tekiyost_ymd::TEXT,
									recYoyakuDS.old_koza_ten_cd::TEXT,
									recYoyakuDS.old_koza_ten_cifcd::TEXT,
									recYoyakuDS.old_koza_kamoku::TEXT,
									recYoyakuDS.old_koza_no::TEXT,
									recYoyakuDS.new_koza_ten_cd::TEXT,
									recYoyakuDS.new_koza_ten_cifcd::TEXT,
									recYoyakuDS.new_koza_kamoku::TEXT,
									recYoyakuDS.new_koza_no::TEXT,
									recYoyakuDS.filter_shubetu::TEXT,
									nMax_Seq,
									cSeq_flg,
									cHkt_cd,
									cErr_flg,
									cErr_cd,
									cKoza_shubetsu,
									vMsg,
									vLmsg,
									vTmsg,
									cRcv_dt,
									WARNING
								 );
						-- 発行体マスタが承認済み（部店マスタなしも含め）の場合
						IF nRetf = 0 OR	nRetf = WARNING	THEN
							UPDATE mhakkotai
							SET koza_ten_cd = recYoyakuDS.new_koza_ten_cd::TEXT,
--							koza_ten_cifcd = recYoyakuDS.new_koza_ten_cifcd::TEXT,
							bd_koza_kamoku_cd = recYoyakuDS.new_koza_kamoku::TEXT,
							bd_koza_no = recYoyakuDS.new_koza_no::TEXT,
							last_teisei_dt = current_timestamp,
							last_teisei_id = 'BATCH',
							kousin_id = 'BATCH'
							WHERE itaku_kaisha_cd = recYoyakuDS.itaku_kaisha_cd::TEXT
							AND hkt_cd = cHkt_cd
							AND koza_ten_cd = recYoyakuDS.old_koza_ten_cd::TEXT
							AND bd_koza_kamoku_cd = recYoyakuDS.old_koza_kamoku::TEXT
							AND bd_koza_no = recYoyakuDS.old_koza_no;
						END IF;
						-- 発行体マスタが承認済みの場合
						IF nRetf = 0 THEN
							vMsg := ' ';
							cErr_flg := '0';
							cErr_cd := ' ';
							cKoza_shubetsu := '1';
							SELECT * INTO nMax_Seq, cSeq_flg, nRet
							FROM SFIPF009K00R05_COMMON_FUNC(
										recYoyakuDS.itaku_kaisha_cd::TEXT,
										recYoyakuDS.make_dt::TEXT,
										recYoyakuDS.tekiyost_ymd::TEXT,
										recYoyakuDS.old_koza_ten_cd::TEXT,
--										recYoyakuDS.old_koza_ten_cifcd::TEXT,
										' ',
										recYoyakuDS.old_koza_kamoku::TEXT,
										recYoyakuDS.old_koza_no::TEXT,
										recYoyakuDS.new_koza_ten_cd::TEXT,
--										recYoyakuDS.new_koza_ten_cifcd::TEXT,
										' ',
										recYoyakuDS.new_koza_kamoku::TEXT,
										recYoyakuDS.new_koza_no::TEXT,
										recYoyakuDS.filter_shubetu::TEXT,
										NULL,
										NULL,
										nMax_Seq,
										cSeq_flg,
										cHkt_cd,
										cKoza_shubetsu,
										cRcv_dt,
										cErr_flg,
										cErr_cd,
										vMsg,
										vLmsg,
										vTmsg::TEXT
									);
							IF nRet = pkconstant.FATAL() THEN
								RETURN nRet;
							END IF;
						END IF;
					END LOOP;
					-- 発行体預金口座の更新
					FOR recHKT_hkt1 IN curHKT_hkt1(recYoyakuDS.itaku_kaisha_cd::TEXT,
												   recYoyakuDS.old_koza_ten_cd::TEXT,
												   recYoyakuDS.old_koza_kamoku::TEXT,
												   recYoyakuDS.old_koza_no) LOOP
						-- 発行体コードを取得
						cHkt_cd := ' ';
						cHkt_cd := recHKT_hkt1.hkt_cd;
						-- 発行体コードの承認チェック
						nRetf := 0;
						SELECT * INTO nMax_Seq, cSeq_flg, cErr_flg, cErr_cd, cKoza_shubetsu, vMsg, vLmsg, vTmsg, nRetf
						FROM SFIPF009K00R05_EXIST_HKT_CD(
									recYoyakuDS.itaku_kaisha_cd::TEXT,
									cHkt_cd,
									recYoyakuDS.make_dt::TEXT,
									recYoyakuDS.tekiyost_ymd::TEXT,
									recYoyakuDS.old_koza_ten_cd::TEXT,
									recYoyakuDS.old_koza_ten_cifcd::TEXT,
									recYoyakuDS.old_koza_kamoku::TEXT,
									recYoyakuDS.old_koza_no::TEXT,
									recYoyakuDS.new_koza_ten_cd::TEXT,
									recYoyakuDS.new_koza_ten_cifcd::TEXT,
									recYoyakuDS.new_koza_kamoku::TEXT,
									recYoyakuDS.new_koza_no::TEXT,
									recYoyakuDS.filter_shubetu::TEXT,
									nMax_Seq,
									cSeq_flg,
									cHkt_cd,
									cErr_flg,
									cErr_cd,
									cKoza_shubetsu,
									vMsg,
									vLmsg,
									vTmsg,
									cRcv_dt,
									WARNING
								 );
						-- 発行体マスタが承認済み（部店マスタなしも含め）の場合
						IF nRetf = 0 OR	nRetf = WARNING	THEN
							UPDATE mhakkotai
							SET koza_ten_cd = recYoyakuDS.new_koza_ten_cd::TEXT,
--							koza_ten_cifcd = recYoyakuDS.new_koza_ten_cifcd::TEXT,
							hkt_koza_kamoku_cd = recYoyakuDS.new_koza_kamoku::TEXT,
							hkt_koza_no = recYoyakuDS.new_koza_no::TEXT,
							last_teisei_dt = current_timestamp,
							last_teisei_id = 'BATCH',
							kousin_id = 'BATCH'
							WHERE itaku_kaisha_cd = recYoyakuDS.itaku_kaisha_cd::TEXT
							AND hkt_cd = cHkt_cd
							AND koza_ten_cd = recYoyakuDS.old_koza_ten_cd::TEXT
							AND hkt_koza_kamoku_cd = recYoyakuDS.old_koza_kamoku::TEXT
							AND hkt_koza_no = recYoyakuDS.old_koza_no;
						END IF;
						-- 発行体マスタが承認済みの場合
						IF nRetf = 0 THEN
							vMsg := ' ';
							cErr_flg := '0';
							cErr_cd := ' ';
							cKoza_shubetsu := '2';
							SELECT * INTO nMax_Seq, cSeq_flg, nRet
							FROM SFIPF009K00R05_COMMON_FUNC(
										recYoyakuDS.itaku_kaisha_cd::TEXT,
										recYoyakuDS.make_dt::TEXT,
										recYoyakuDS.tekiyost_ymd::TEXT,
										recYoyakuDS.old_koza_ten_cd::TEXT,
--										recYoyakuDS.old_koza_ten_cifcd::TEXT,
										' ',
										recYoyakuDS.old_koza_kamoku::TEXT,
										recYoyakuDS.old_koza_no::TEXT,
										recYoyakuDS.new_koza_ten_cd::TEXT,
--										recYoyakuDS.new_koza_ten_cifcd::TEXT,
										' ',
										recYoyakuDS.new_koza_kamoku::TEXT,
										recYoyakuDS.new_koza_no::TEXT,
										recYoyakuDS.filter_shubetu::TEXT,
										NULL,
										NULL,
										nMax_Seq,
										cSeq_flg,
										cHkt_cd,
										cKoza_shubetsu,
										cRcv_dt,
										cErr_flg,
										cErr_cd,
										vMsg,
										vLmsg,
										vTmsg::TEXT
									);
							IF nRet = pkconstant.FATAL() THEN
								RETURN nRet;
							END IF;
						END IF;
					END LOOP;
					-- 自動引落口座の更新
					FOR recHKO_hkt1 IN curHKO_hkt1(recYoyakuDS.itaku_kaisha_cd::TEXT,
												   recYoyakuDS.old_koza_ten_cd::TEXT,
												   recYoyakuDS.old_koza_kamoku::TEXT,
												   recYoyakuDS.old_koza_no) LOOP
						-- 発行体コードを取得
						cHkt_cd := ' ';
						cHkt_cd := recHKO_hkt1.hkt_cd;
						-- 発行体コードの承認チェック
						nRetf := 0;
						SELECT * INTO nMax_Seq, cSeq_flg, cErr_flg, cErr_cd, cKoza_shubetsu, vMsg, vLmsg, vTmsg, nRetf
						FROM SFIPF009K00R05_EXIST_HKT_CD(
									recYoyakuDS.itaku_kaisha_cd::TEXT,
									cHkt_cd,
									recYoyakuDS.make_dt::TEXT,
									recYoyakuDS.tekiyost_ymd::TEXT,
									recYoyakuDS.old_koza_ten_cd::TEXT,
									recYoyakuDS.old_koza_ten_cifcd::TEXT,
									recYoyakuDS.old_koza_kamoku::TEXT,
									recYoyakuDS.old_koza_no::TEXT,
									recYoyakuDS.new_koza_ten_cd::TEXT,
									recYoyakuDS.new_koza_ten_cifcd::TEXT,
									recYoyakuDS.new_koza_kamoku::TEXT,
									recYoyakuDS.new_koza_no::TEXT,
									recYoyakuDS.filter_shubetu::TEXT,
									nMax_Seq,
									cSeq_flg,
									cHkt_cd,
									cErr_flg,
									cErr_cd,
									cKoza_shubetsu,
									vMsg,
									vLmsg,
									vTmsg,
									cRcv_dt,
									WARNING
								 );
						-- 発行体マスタが承認済み（部店マスタなしも含め）の場合
						IF nRetf = 0 OR	nRetf = WARNING	THEN
							UPDATE mhakkotai
							SET koza_ten_cd = recYoyakuDS.new_koza_ten_cd::TEXT,
--							koza_ten_cifcd = recYoyakuDS.new_koza_ten_cifcd::TEXT,
							hko_kamoku_cd = recYoyakuDS.new_koza_kamoku::TEXT,
							hko_koza_no = recYoyakuDS.new_koza_no::TEXT,
							last_teisei_dt = current_timestamp,
							last_teisei_id = 'BATCH',
							kousin_id = 'BATCH'
							WHERE itaku_kaisha_cd = recYoyakuDS.itaku_kaisha_cd::TEXT
							AND hkt_cd = cHkt_cd
							AND koza_ten_cd = recYoyakuDS.old_koza_ten_cd::TEXT
							AND hko_kamoku_cd = recYoyakuDS.old_koza_kamoku::TEXT
							AND hko_koza_no = recYoyakuDS.old_koza_no;
						END IF;
						-- 発行体マスタが承認済みの場合
						IF nRetf = 0 THEN
							vMsg := ' ';
							cErr_flg := '0';
							cErr_cd := ' ';
							cKoza_shubetsu := '3';
							SELECT * INTO nMax_Seq, cSeq_flg, nRet
							FROM SFIPF009K00R05_COMMON_FUNC(
										recYoyakuDS.itaku_kaisha_cd::TEXT,
										recYoyakuDS.make_dt::TEXT,
										recYoyakuDS.tekiyost_ymd::TEXT,
										recYoyakuDS.old_koza_ten_cd::TEXT,
--										recYoyakuDS.old_koza_ten_cifcd::TEXT,
										' ',
										recYoyakuDS.old_koza_kamoku::TEXT,
										recYoyakuDS.old_koza_no::TEXT,
										recYoyakuDS.new_koza_ten_cd::TEXT,
--										recYoyakuDS.new_koza_ten_cifcd::TEXT,
										' ',
										recYoyakuDS.new_koza_kamoku::TEXT,
										recYoyakuDS.new_koza_no::TEXT,
										recYoyakuDS.filter_shubetu::TEXT,
										NULL,
										NULL,
										nMax_Seq,
										cSeq_flg,
										cHkt_cd,
										cKoza_shubetsu,
										cRcv_dt,
										cErr_flg,
										cErr_cd,
										vMsg,
										vLmsg,
										vTmsg::TEXT
									);
							IF nRet = pkconstant.FATAL() THEN
								RETURN nRet;
							END IF;
						END IF;
					END LOOP;
				END IF;
			END IF;
		END IF;
	END LOOP;
	RETURN pkconstant.success();
--==============================================================================
--					エラー処理													
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		-- ログ出力
		CALL pklog.fatal(
			'ECM701', 'IPF009K00R05', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')'
		);
		RETURN pkconstant.fatal();
--		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf009k00r05 ( l_inJobkbn TEXT  ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipf009k00r05_common_func ( 
 l_inItaku_kaisha_cd TEXT,				-- 委託会社コード
 l_inMake_dt TEXT,				-- 作成日
 l_inTekiyost_ymd TEXT,				-- 適用開始日
 l_inOld_koza_ten_cd TEXT,				-- 旧口座店コード
 l_inOld_koza_ten_cifcd TEXT,				-- 旧口座店ＣＩＦコード
 l_inOld_koza_kamoku TEXT,				-- 旧口座科目
 l_inOld_koza_no TEXT,				-- 旧口座番号
 l_inNew_koza_ten_cd TEXT,				-- 新口座店コード
 l_inNew_koza_ten_cifcd TEXT,				-- 新口座店ＣＩＦコード
 l_inNew_koza_kamoku TEXT,				-- 新口座科目
 l_inNew_koza_no TEXT,				-- 新口座番号
 l_inFilter_shubetu TEXT,				-- フィルタ種別
 INOUT nMax_Seq NUMERIC,
 INOUT cSeq_flg TEXT,
 IN cHkt_cd TEXT,
 IN cKoza_shubetsu TEXT,
 IN cRcv_dt TEXT,
 IN cErr_flg TEXT,
 IN cErr_cd TEXT,
 IN vMsg TEXT,
 IN vLmsg TEXT,
 IN vTmsg TEXT,
 l_inLevel TEXT DEFAULT NULL,	-- 通知レベル
 l_inMsg_id TEXT DEFAULT NULL, 	-- メッセージＩＤ
 OUT result_code INTEGER
) AS $body$
DECLARE
	nRet INTEGER;
BEGIN
	-- 対象レコードが変わる毎にSEQ_NOをインクリメント
	IF cSeq_flg = '0' THEN
		-- 口座情報更新リストワークの連番カウント
		nMax_Seq := nMax_Seq + 1;
	END IF;
	-- 口座情報更新リストワークに出力
	INSERT INTO kozajyohokoshin_list_wk(
		itaku_kaisha_cd,
		chohyo_id,
		seq_no,
		tekiyost_ymd,
		old_koza_ten_cd,
		old_koza_ten_cifcd,
		old_koza_kamoku,
		old_koza_no,
		new_koza_ten_cd,
		new_koza_ten_cifcd,
		new_koza_kamoku,
		new_koza_no,
		hkt_cd,
		koza_shubetu,
		filter_shubetu,
		data_recv_ymd,
		err_umu_flg,
		err_cd_6,
		err_nm_30,
		kousin_dt,
		kousin_id,
		sakusei_dt,
		sakusei_id
	)
	VALUES (
		l_inItaku_kaisha_cd,
		'IPF30000921',
		nMax_Seq,
		l_inTekiyost_ymd,
		l_inOld_koza_ten_cd,
		l_inOld_koza_ten_cifcd,
		l_inOld_koza_kamoku,
		l_inOld_koza_no,
		l_inNew_koza_ten_cd,
		l_inNew_koza_ten_cifcd,
		l_inNew_koza_kamoku,
		l_inNew_koza_no,
		cHkt_cd,
		cKoza_shubetsu,
		l_inFilter_shubetu,
		cRcv_dt,
		cErr_flg,
		cErr_cd,
		vMsg,
		CURRENT_TIMESTAMP,
		'BATCH',
		CURRENT_TIMESTAMP,
		'BATCH'
	);
	IF cErr_flg = '1' THEN
		--ログ出力
		CALL pklog.error(l_inMsg_id, 'IPF009K00R05', vLmsg);
		--メッセージ通知テーブルへ書き込み
		nRet := sfipmsgtsuchiupdate(l_inItaku_kaisha_cd, 'CAPS', l_inLevel, '1', '0', vTmsg, 'BATCH', 'BATCH');
		IF nRet != 0 THEN
			CALL pklog.fatal('ECM701', 'IPF009K00R05', 'メッセージ通知登録エラー');
			result_code := pkconstant.fatal();
			RETURN;
		END IF;
	END IF;
	-- シーケンス用フラグに'1'を設定
	cSeq_flg := '1';
	result_code := pkconstant.success();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf009k00r05_common_func ( l_inItaku_kaisha_cd TEXT, l_inMake_dt TEXT, l_inTekiyost_ymd TEXT, l_inOld_koza_ten_cd TEXT, l_inOld_koza_ten_cifcd TEXT, l_inOld_koza_kamoku TEXT, l_inOld_koza_no TEXT, l_inNew_koza_ten_cd TEXT, l_inNew_koza_ten_cifcd TEXT, l_inNew_koza_kamoku TEXT, l_inNew_koza_no TEXT, l_inFilter_shubetu TEXT, l_inLevel TEXT DEFAULT NULL, l_inMsg_id TEXT DEFAULT NULL  ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipf009k00r05_exist_hkt_cd ( 
 l_in_itaku_kaisha_cd TEXT,				-- 委託会社コード
 l_in_hkt_cd TEXT,					-- 発行体コード
 l_in_make_dt TEXT,				-- 作成日
 l_in_tekiyost_ymd TEXT,			-- 適用日
 l_in_old_koza_ten_cd TEXT,			-- 旧口座店番号
 l_in_old_koza_ten_cifcd TEXT,		-- 旧口座店ＣＩＦ番号
 l_in_old_koza_kamoku TEXT,			-- 旧口座科目
 l_in_old_koza_no TEXT,				-- 旧口座番号
 l_in_new_koza_ten_cd TEXT,			-- 新口座店番号
 l_in_new_koza_ten_cifcd TEXT,		-- 新口座店ＣＩＦ番号
 l_in_new_koza_kamoku TEXT,			-- 新口座科目
 l_in_new_koza_no TEXT,				-- 新口座番号
 l_in_filter_shubetu TEXT,				-- フィルタ種別
 INOUT nMax_Seq NUMERIC,
 INOUT cSeq_flg TEXT,
 IN cHkt_cd TEXT,
 INOUT cErr_flg TEXT,
 INOUT cErr_cd TEXT,
 INOUT cKoza_shubetsu TEXT,
 INOUT vMsg TEXT,
 INOUT vLmsg TEXT,
 INOUT vTmsg TEXT,
 IN cRcv_dt TEXT,
 IN WARNING INTEGER,
 OUT result_code INTEGER
 ) AS $body$
DECLARE
	nCount INTEGER;
	nCount2 INTEGER;
	nRet INTEGER;
BEGIN
	nCount := 0;
	SELECT count(hkt_cd)
	INTO STRICT nCount
	FROM mhakkotai
	WHERE itaku_kaisha_cd = l_in_itaku_kaisha_cd
	AND hkt_cd = l_in_hkt_cd
	AND koza_ten_cd = l_in_old_koza_ten_cd
	AND trim(both koza_ten_cifcd) = trim(both l_in_old_koza_ten_cifcd)
	AND shori_kbn = '1';
	-- 発行体マスタが承認済み以外の場合、エラー
	IF nCount = 0 THEN
		-- 既に同一の発行体コードでエラーのレコードが口座情報更新リストワーク
		-- に存在する場合は、書き込まない
		nCount2 := 0;
		SELECT count(*)
		INTO STRICT nCount2
		FROM kozajyohokoshin_list_wk
		WHERE itaku_kaisha_cd = l_in_itaku_kaisha_cd
		AND hkt_cd = l_in_hkt_cd
		AND tekiyost_ymd = l_in_tekiyost_ymd
		AND old_koza_ten_cd = l_in_old_koza_ten_cd
		AND old_koza_ten_cifcd = l_in_old_koza_ten_cifcd
		AND old_koza_kamoku = l_in_old_koza_kamoku
		AND old_koza_no = l_in_old_koza_no
		AND new_koza_ten_cd = l_in_new_koza_ten_cd
		AND new_koza_ten_cifcd = l_in_new_koza_ten_cifcd
		AND new_koza_kamoku = l_in_new_koza_kamoku
		AND new_koza_no = l_in_new_koza_no
		AND filter_shubetu = l_in_filter_shubetu;
		IF nCount2 = 0 THEN
			-- エラー処理
			vMsg := '未承認データのため処理できません。';
			vLmsg := '＜テーブル:発行体,口座店:' || l_in_old_koza_ten_cd ||
					 ',口座店CIF:' || trim(both l_in_old_koza_ten_cifcd) || '＞';
			vTmsg := '未承認データのため処理できません。' ||
					 '＜発行体、口座店:' || l_in_old_koza_ten_cd ||
					 ',口座店CIF:' || trim(both l_in_old_koza_ten_cifcd) || '＞';
			cErr_flg := '1';
			cErr_cd := 'EIP514';
			cKoza_shubetsu := ' ';
			SELECT * INTO nMax_Seq, cSeq_flg, nRet
			FROM SFIPF009K00R05_COMMON_FUNC(
						l_in_itaku_kaisha_cd,
						l_in_make_dt,
						l_in_tekiyost_ymd,
						l_in_old_koza_ten_cd,
						l_in_old_koza_ten_cifcd,
						l_in_old_koza_kamoku,
						l_in_old_koza_no,
						l_in_new_koza_ten_cd,
						l_in_new_koza_ten_cifcd,
						l_in_new_koza_kamoku,
						l_in_new_koza_no,
						l_in_filter_shubetu,
						'重要',
						'EIP514',
						nMax_Seq,
						cSeq_flg::TEXT,
						l_in_hkt_cd,
						cKoza_shubetsu::TEXT,
						l_in_cRcv_dt,
						cErr_flg::TEXT,
						cErr_cd::TEXT,
						vMsg,
						vLmsg,
						vTmsg::TEXT
				);
			IF nRet = pkconstant.FATAL() THEN
			result_code := nRet;
			RETURN;
			END IF;
		END IF;
		result_code := pkconstant.error();
		RETURN;
	ELSE
		-- 旧店番号をチェック
		nCount := 0;
		SELECT count(buten_cd)
		INTO STRICT nCount
		FROM mbuten
		WHERE itaku_kaisha_cd = l_in_itaku_kaisha_cd
		AND buten_cd = l_in_old_koza_ten_cd;
		-- 旧店番号が部店マスタに存在しない場合
		IF nCount = 0 THEN
			-- 既に同一の発行体コード、旧店番号でエラーのレコードが
			-- 口座情報更新リストワークに存在する場合は、書き込まない
			nCount2 := 0;
			SELECT count(*)
			INTO STRICT nCount2
			FROM kozajyohokoshin_list_wk
			WHERE itaku_kaisha_cd = l_in_itaku_kaisha_cd
			AND hkt_cd = l_in_hkt_cd
			AND tekiyost_ymd = l_in_tekiyost_ymd
			AND old_koza_ten_cd = l_in_old_koza_ten_cd
			AND old_koza_ten_cifcd = l_in_old_koza_ten_cifcd
			AND old_koza_kamoku = l_in_old_koza_kamoku
			AND old_koza_no = l_in_old_koza_no
			AND new_koza_ten_cd = l_in_new_koza_ten_cd
			AND new_koza_ten_cifcd = l_in_new_koza_ten_cifcd
			AND new_koza_kamoku = l_in_new_koza_kamoku
			AND new_koza_no = l_in_new_koza_no
			AND filter_shubetu = l_in_filter_shubetu;
			IF nCount2 = 0 THEN
				-- エラー処理
				vMsg := '部店マスタが存在しません。登録してください。';
				vLmsg := '＜旧店番号:' || l_in_old_koza_ten_cd || '＞';
				vTmsg := '部店マスタが存在しません。登録してください。' ||
						 '＜旧店番号:' || l_in_old_koza_ten_cd || '＞';
				cKoza_shubetsu := ' ';
				cErr_flg := '1';
				cErr_cd := 'WIP502';
				cKoza_shubetsu := ' ';
				SELECT * INTO nMax_Seq, cSeq_flg, nRet
				FROM SFIPF009K00R05_COMMON_FUNC(
							l_in_itaku_kaisha_cd,
							l_in_make_dt,
							l_in_tekiyost_ymd,
							l_in_old_koza_ten_cd,
							l_in_old_koza_ten_cifcd,
							l_in_old_koza_kamoku,
							l_in_old_koza_no,
							l_in_new_koza_ten_cd,
							l_in_new_koza_ten_cifcd,
							l_in_new_koza_kamoku,
							l_in_new_koza_no,
							l_in_filter_shubetu,
							'警告',
							'WIP502',
							nMax_Seq,
							cSeq_flg::TEXT,
							l_in_hkt_cd,
							cKoza_shubetsu::TEXT,
							l_in_cRcv_dt,
							cErr_flg::TEXT,
							cErr_cd::TEXT,
							vMsg,
							vLmsg,
							vTmsg::TEXT
						);
				IF nRet = pkconstant.FATAL() THEN
					result_code := nRet;
					RETURN;
				END IF;
			END IF;
--				RETURN pkconstant.error();
			result_code := WARNING;
			RETURN;
		ELSE
			-- 新店番号をチェック
			nCount := 0;
			SELECT count(buten_cd)
			INTO STRICT nCount
			FROM mbuten
			WHERE itaku_kaisha_cd = l_in_itaku_kaisha_cd
			AND buten_cd = l_in_new_koza_ten_cd;
			-- 新店番号が部店マスタに存在しない場合
			IF nCount = 0 THEN
				-- 既に同一の発行体コード、旧店番号でエラーのレコードが
				-- 口座情報更新リストワークに存在する場合は、書き込まない
				nCount2 := 0;
				SELECT count(*)
				INTO STRICT nCount2
				FROM kozajyohokoshin_list_wk
				WHERE itaku_kaisha_cd = l_in_itaku_kaisha_cd
				AND hkt_cd = l_in_hkt_cd
				AND tekiyost_ymd = l_in_tekiyost_ymd
				AND old_koza_ten_cd = l_in_old_koza_ten_cd
				AND old_koza_ten_cifcd = l_in_old_koza_ten_cifcd
				AND old_koza_kamoku = l_in_old_koza_kamoku
				AND old_koza_no = l_in_old_koza_no
				AND new_koza_ten_cd = l_in_new_koza_ten_cd
				AND new_koza_ten_cifcd = l_in_new_koza_ten_cifcd
				AND new_koza_kamoku = l_in_new_koza_kamoku
				AND new_koza_no = l_in_new_koza_no
				AND filter_shubetu = l_in_filter_shubetu;
				IF nCount2 = 0 THEN
					-- エラー処理
					vMsg := '部店マスタが存在しません。登録してください。';
					vLmsg := '＜新店番号:' || l_in_new_koza_ten_cd || '＞';
					vTmsg := '部店マスタが存在しません。登録してください。' ||
							 '＜新店番号:' || l_in_new_koza_ten_cd || '＞';
					cKoza_shubetsu := ' ';
					cErr_flg := '1';
					cErr_cd := 'WIP502';
					cKoza_shubetsu := ' ';
					SELECT * INTO nMax_Seq, cSeq_flg, nRet
					FROM SFIPF009K00R05_COMMON_FUNC(
								l_in_itaku_kaisha_cd,
								l_in_make_dt,
								l_in_tekiyost_ymd,
								l_in_old_koza_ten_cd,
								l_in_old_koza_ten_cifcd,
								l_in_old_koza_kamoku,
								l_in_old_koza_no,
								l_in_new_koza_ten_cd,
								l_in_new_koza_ten_cifcd,
								l_in_new_koza_kamoku,
								l_in_new_koza_no,
								l_in_filter_shubetu,
								'警告',
								'WIP502',
								nMax_Seq,
								cSeq_flg::TEXT,
								l_in_hkt_cd,
								cKoza_shubetsu::TEXT,
								l_in_cRcv_dt,
								cErr_flg::TEXT,
								cErr_cd::TEXT,
								vMsg,
								vLmsg,
								vTmsg::TEXT
							);
					IF nRet = pkconstant.FATAL() THEN
						result_code := nRet;
						RETURN;
					END IF;
				END IF;
--					RETURN pkconstant.error();
				result_code := WARNING;
				RETURN;
			END IF;
		END IF;
	END IF;
	result_code := pkconstant.success();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf009k00r05_exist_hkt_cd ( l_in_itaku_kaisha_cd TEXT, l_in_hkt_cd TEXT, l_in_make_dt TEXT, l_in_tekiyost_ymd TEXT, l_in_old_koza_ten_cd TEXT, l_in_old_koza_ten_cifcd TEXT, l_in_old_koza_kamoku TEXT, l_in_old_koza_no TEXT, l_in_new_koza_ten_cd TEXT, l_in_new_koza_ten_cifcd TEXT, l_in_new_koza_kamoku TEXT, l_in_new_koza_no TEXT, l_in_filter_shubetu TEXT  ) FROM PUBLIC;
