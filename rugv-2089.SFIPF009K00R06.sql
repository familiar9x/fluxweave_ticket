




CREATE OR REPLACE FUNCTION sfipf009k00r06 ( l_inYoyaku_kbn TEXT 					-- 区分
 ) RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 部店マスタ（予約）テーブルを基に、部店マスタテーブルを更新する。
-- * パラメータにより、予約区分単位で処理する。（１：新規、更新　２：削除）
-- * 処理結果を部店更新リストワークに登録する。
-- * 
-- * @author 戸倉　一成
-- * @version $Revision: 1.8 $
-- * $Id: SFIPF009K00R06.sql,v 1.8 2005/12/15 07:34:48 kobayashi Exp $
-- * @return INTEGER
-- *                0:正常終了、データ無し
-- *                1:予期したエラー
-- *               99:予期せぬエラー
--
--==============================================================================
--                  定数定義                                                    
--==============================================================================
	MSG_DATA_ERR           CONSTANT varchar(30) := 'フォーマットエラー';
	MSG_MSGTSUCHI_ERR      CONSTANT varchar(30) := 'メッセージ通知登録エラー';
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	nCount                 numeric;							-- 件数カウンタ
	nRtnCd                 numeric;							-- 共通関数リターン値
	nSeq_No                numeric;							-- データ内連番
	cFlg                   char(1);							-- エラーフラグ
	cGyoumuDt              sreport_wk.sakusei_ymd%type;		-- 業務日付
	cItaku_Kaisha_Cd       char(4);							-- 委託会社コード
	cPlusTekiyo_Ymd        char(8);							-- 適用開始日（＋）
	cMinusTekiyo_Ymd       char(8);							-- 適用開始日（−）
	cSeq_flg               char(1);							-- SEQ_NO用フラグ
	cYoyaku_Kbn            char(1);							-- 予約区分
	cMsgId                 char(6);							-- メッセージＩＤ
	vLmsg                  varchar(200);					-- ログ用メッセージ
	vTmsg                  varchar(200);					-- 通知用メッセージ
	cTel_No                mbuten_yoyaku.tel_no%type;		-- 電話番号
	cButen_Nm              mbuten_yoyaku.buten_nm%type;		-- 部店名称
	cButen_Rnm             mbuten_yoyaku.buten_rnm%type;	-- 部店略称
--==============================================================================
--                  カーソル定義                                                
--==============================================================================
	-- 区分１（新規、更新）用カーソル
	curInsbuten CURSOR FOR
		SELECT 
			itaku_kaisha_cd,
			buten_cd,
			buten_nm,
			buten_rnm,
			group_cd,
			post_no,
			add1,
			add2,
			add3,
			busho_nm,
			tel_no,
			fax_no,
			mail_add,
			shiyo_kaishi_ymd,
			shiyo_teishi_ymd,
			haiten_ymd,
			data_recv_ymd,
			make_dt,
			sakusei_dt
		FROM 
			mbuten_yoyaku
		WHERE 
			cGyoumuDt < shiyo_kaishi_ymd
		AND
			shiyo_kaishi_ymd <= cPlusTekiyo_Ymd
		AND
			shiyo_teishi_ymd = '99999999'
		GROUP BY
			itaku_kaisha_cd,
			buten_cd,
			buten_nm,
			buten_rnm,
			group_cd,
			post_no,
			add1,
			add2,
			add3,
			busho_nm,
			tel_no,
			fax_no,
			mail_add,
			shiyo_kaishi_ymd,
			shiyo_teishi_ymd,
			haiten_ymd,
			data_recv_ymd,
			make_dt,
			sakusei_dt
		ORDER BY 
			itaku_kaisha_cd,
			buten_cd,
			sakusei_dt;
	-- 区分２（削除）用カーソル
	curDelbuten CURSOR FOR
		SELECT 
			itaku_kaisha_cd,
			buten_cd,
			buten_nm,
			buten_rnm,
			group_cd,
			post_no,
			add1,
			add2,
			add3,
			busho_nm,
			tel_no,
			fax_no,
			mail_add,
			shiyo_kaishi_ymd,
			shiyo_teishi_ymd,
			haiten_ymd,
			data_recv_ymd,
			make_dt,
			sakusei_dt
		FROM 
			mbuten_yoyaku
		WHERE 
			cMinusTekiyo_Ymd <= shiyo_teishi_ymd
		AND
			shiyo_teishi_ymd < cGyoumuDt
		AND 
			haiten_ymd = shiyo_teishi_ymd
		GROUP BY
			itaku_kaisha_cd,
			buten_cd,
			buten_nm,
			buten_rnm,
			group_cd,
			post_no,
			add1,
			add2,
			add3,
			busho_nm,
			tel_no,
			fax_no,
			mail_add,
			shiyo_kaishi_ymd,
			shiyo_teishi_ymd,
			haiten_ymd,
			data_recv_ymd,
			make_dt,
			sakusei_dt;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 業務日付、適用開始日を取得
	cGyoumuDt        := pkDate.getGyomuYmd();
	cPlusTekiyo_Ymd  := pkDate.getPlusDateBusiness(cGyoumuDt, 1);
	cMinusTekiyo_Ymd := pkDate.getMinusDateBusiness(cGyoumuDt, 1);
	-- 委託会社コード取得
	SELECT
		kaiin_id 
	INTO STRICT 
		cItaku_Kaisha_Cd
	FROM 
		sown_info;
	-- 区分１（新規、更新）の場合
	IF l_inYoyaku_kbn = '1' THEN
		-- データの件数をチェック
		SELECT
			count(*) 
		INTO STRICT 
			nCount 
		FROM 
			mbuten_yoyaku
		WHERE 
			cGyoumuDt < shiyo_kaishi_ymd
		AND
			shiyo_kaishi_ymd <= cPlusTekiyo_Ymd
		AND
			shiyo_teishi_ymd = '99999999';
		-- データが存在しない場合
		IF nCount = 0 THEN
			RETURN pkconstant.success();
		END IF;
		-- 部店更新リストワークの最大連番を取得
		SELECT
			max(seq_no), 
			count(*)
		INTO STRICT 
			nSeq_No, 
			nCount
		FROM 
			butenkoshin_list_wk
		WHERE 
			itaku_kaisha_cd = cItaku_Kaisha_Cd;
		-- データが存在しない場合
		IF nCount = 0 THEN
			nSeq_No := 0;
		END IF;
		-- 部店マスタテーブル登録処理（新規、更新）
		FOR recInsbuten IN curInsbuten LOOP
			-- 変数初期化
			cSeq_flg := '0';
			cButen_Nm := '　';
			cButen_Rnm := '　';
			cTel_No := ' ';
			-- 部店名称、部店略称、電話番号を編集
			-- 部店名称が全て空白の場合は、' '（全角スペース1個）
			IF recInsbuten.buten_nm = '　　　　　　　　　　　　　　　' THEN
				cButen_Nm := '　';
			ELSE
				cButen_Nm := recInsbuten.buten_nm;
			END IF;
			-- 部店略称が全て空白の場合は、' '（全角スペース1個）
			IF recInsbuten.buten_rnm = '　　　　　' THEN
				cButen_Rnm := '　';
			ELSE
				cButen_Rnm := recInsbuten.buten_rnm;
			END IF;
			-- 電話番号が全て空白の場合は、' '（半角スペース1個）
			IF recInsbuten.tel_no = '            ' THEN
				cTel_No := ' ';
			ELSE
				cTel_No := recInsbuten.tel_no;
			END IF;
			-- エラーフラグを初期化
			cFlg := '0';
			-- データの件数をチェック
			SELECT
				count(*) 
			INTO STRICT 
				nCount
			FROM 
				mbuten
			WHERE 
				itaku_kaisha_cd = recInsbuten.itaku_kaisha_cd
			AND 
				buten_cd        = recInsbuten.buten_cd;
				-- データが存在しない場合
				IF nCount = 0 THEN
					-- 予約区分の設定
					cYoyaku_Kbn := '2';
					-- 部店マスタテーブル更新処理（新規）
					INSERT INTO mbuten(
						itaku_kaisha_cd,
						buten_cd,
						buten_nm,
						buten_rnm,
						group_cd,
						tel_no,
						shori_kbn,
						last_teisei_dt,
						last_teisei_id,
						shonin_dt,
						shonin_id,
						kousin_id,
						sakusei_id
					)
					VALUES (
						recInsbuten.itaku_kaisha_cd,
						recInsbuten.buten_cd,
						cButen_Nm,
						cButen_Rnm,
						recInsbuten.group_cd,
						cTel_No,
						'1',
						current_timestamp,
						'BATCH',
						current_timestamp,
						'BATCH',
						'BATCH',
						'BATCH'
					);
				ELSE
					-- 予約区分の設定
					cYoyaku_Kbn := '3';
					-- 部店マスタテーブルの件数をチェック
					SELECT
						count(*) 
					INTO STRICT 
						nCount
					FROM 
						mbuten
					WHERE 
						itaku_kaisha_cd = recInsbuten.itaku_kaisha_cd
					AND 
						buten_cd        = recInsbuten.buten_cd
					AND 
						shori_kbn       = '1';
					-- データが存在しない場合
					IF nCount = 0 THEN
						-- メッセージＩＤ
						cMsgId := 'EIP514';
						-- ログ用メッセージ
						vLmsg := '＜テーブル:部店,部店コード:' || recInsbuten.buten_cd || '＞';
						-- メッセージ通知用メッセージ
						vTmsg := '未承認のため処理できません。',
								nSeq_No,
								cSeq_flg ||
								 '＜テーブル:部店、部店コード:' || recInsbuten.buten_cd || '＞';
						-- エラー処理
						nRtnCd := SFIPF009K00R06_ERR_FUNC(recInsbuten.itaku_kaisha_cd, cMsgId, vLmsg, vTmsg, '重要');
						-- 部店更新リストワーク登録サブルーチンの呼び出し
						nRtnCd := SFIPF009K00R06_INSERT_FUNC(
										recInsbuten.itaku_kaisha_cd,
										nSeq_No,
										cPlusTekiyo_Ymd,
										cYoyaku_Kbn,
										recInsbuten.buten_cd,
										recInsbuten.buten_nm,
										recInsbuten.buten_rnm,
										recInsbuten.group_cd,
										' ',
										' ',
										' ',
										' ',
										' ',
										recInsbuten.tel_no,
										' ',
										' ',
										recInsbuten.data_recv_ymd,
										'1',
										'EIP514',
										'未承認のため処理できません。',
								nSeq_No,
								cSeq_flg
									);
						-- エラーフラグに'1'を設定
						cFlg := '1';
					ELSE
						-- 部店マスタテーブル更新処理（更新）
						UPDATE
							mbuten
						SET 
							buten_nm        = cButen_Nm,
							buten_rnm       = cButen_Rnm,
							group_cd        = recInsbuten.group_cd,
							tel_no          = cTel_No,
							shori_kbn       = '1',
							last_teisei_dt  = current_timestamp,
							last_teisei_id  = 'BATCH',
							shonin_dt       = current_timestamp,
							shonin_id       = 'BATCH',
							kousin_id       = 'BATCH'
						WHERE 
							itaku_kaisha_cd = recInsbuten.itaku_kaisha_cd
						AND 
							buten_cd        = recInsbuten.buten_cd;
					END IF;
				END IF;
			IF cFlg = '0' THEN
				-- 部店更新リストワーク登録サブルーチンの呼び出し
				nRtnCd := SFIPF009K00R06_INSERT_FUNC(
								recInsbuten.itaku_kaisha_cd,
								nSeq_No,
								cPlusTekiyo_Ymd,
								cYoyaku_Kbn,
								recInsbuten.buten_cd,
								cButen_Nm,
								cButen_Rnm,
								recInsbuten.group_cd,
								' ',
								' ',
								' ',
								' ',
								' ',
								cTel_No,
								' ',
								' ',
								recInsbuten.data_recv_ymd,
								'0',
								' ',
								' '
							);
			END IF;
		END LOOP;
	-- 区分２（削除）の場合
	ELSIF l_inYoyaku_kbn = '2' THEN
		-- 予約区分の設定
		cYoyaku_Kbn := '1';
		-- 部店マスタ（予約）のデータの件数をチェック
		SELECT
			count(*) 
		INTO STRICT 
			nCount 
		FROM 
			mbuten_yoyaku
		WHERE 
			cMinusTekiyo_Ymd <= shiyo_teishi_ymd
		AND
			shiyo_teishi_ymd < cGyoumuDt
		AND 
			haiten_ymd = shiyo_teishi_ymd;
		-- データが存在しない場合
		IF nCount = 0 THEN
			RETURN pkconstant.success();
		END IF;
		-- 部店更新リストワークの最大連番を取得
		SELECT
			max(seq_no), 
			count(*)
		INTO STRICT 
			nSeq_No, 
			nCount
		FROM 
			butenkoshin_list_wk
		WHERE 
			itaku_kaisha_cd = cItaku_Kaisha_Cd;
		-- データが存在しない場合
		IF nCount = 0 THEN
			nSeq_No := 0;
		END IF;
		-- 部店マスタテーブル削除処理（削除）
		FOR recDelbuten IN curDelbuten LOOP
			-- 変数初期化
			cFlg := '0';
			cSeq_flg := '0';
			-- 部店マスタのデータの件数をチェック
			SELECT
				count(*) 
			INTO STRICT 
				nCount
			FROM 
				mbuten
			WHERE 
				itaku_kaisha_cd = recDelbuten.itaku_kaisha_cd
			AND 
				buten_cd        = recDelbuten.buten_cd;
			-- データが存在しない場合
			IF nCount = 0 THEN
				-- メッセージＩＤ
				cMsgId := 'ECM504';
				-- ログ用メッセージ
				vLmsg := '＜テーブル:部店,部店コード:' || recDelbuten.buten_cd || '＞';
				-- メッセージ通知用メッセージ
				vTmsg := '部店マスタが存在しません。登録してください。' ||
						 '＜テーブル:部店、部店コード:' || recDelbuten.buten_cd || '＞';
				-- エラー処理
				nRtnCd := SFIPF009K00R06_ERR_FUNC(recDelbuten.itaku_kaisha_cd, cMsgId, vLmsg, vTmsg, '警告');
				-- 部店更新リストワーク登録サブルーチンの呼び出し
				nRtnCd := SFIPF009K00R06_INSERT_FUNC(
								recDelbuten.itaku_kaisha_cd,
								nSeq_No,
								cMinusTekiyo_Ymd,
								cYoyaku_Kbn,
								recDelbuten.buten_cd,
								recDelbuten.buten_nm,
								recDelbuten.buten_rnm,
								recDelbuten.group_cd,
								recDelbuten.post_no,
								recDelbuten.add1,
								recDelbuten.add2,
								recDelbuten.add3,
								recDelbuten.busho_nm,
								recDelbuten.tel_no,
								recDelbuten.fax_no,
								recDelbuten.mail_add,
								recDelbuten.data_recv_ymd,
								'1',
								'ECM504',
								'部店マスタが存在しません。登録してください。'
							);
				-- エラーフラグに'1'を設定
				cFlg := '1';
			ELSE
				-- データの件数をチェック
				SELECT
					count(*) 
				INTO STRICT 
					nCount
				FROM 
					mbuten
				WHERE 
					itaku_kaisha_cd = recDelbuten.itaku_kaisha_cd
				AND 
					buten_cd        = recDelbuten.buten_cd
				AND 
					shori_kbn       = '1';
				-- データが存在しない場合
				IF nCount = 0 THEN
					-- メッセージＩＤ
					cMsgId := 'EIP514';
					-- ログ用メッセージ
					vLmsg := '＜テーブル:部店,部店コード:' || recDelbuten.buten_cd || '＞';
					-- メッセージ通知用メッセージ
					vTmsg := '未承認のため処理できません。',
								nSeq_No,
								cSeq_flg ||
							 '＜テーブル:部店、部店コード:' || recDelbuten.buten_cd || '＞';
					-- エラー処理
					nRtnCd := SFIPF009K00R06_ERR_FUNC(recDelbuten.itaku_kaisha_cd, cMsgId, vLmsg, vTmsg, '重要');
					-- 部店更新リストワーク登録サブルーチンの呼び出し
					nRtnCd := SFIPF009K00R06_INSERT_FUNC(
									recDelbuten.itaku_kaisha_cd,
									nSeq_No,
									cMinusTekiyo_Ymd,
									cYoyaku_Kbn,
									recDelbuten.buten_cd,
									recDelbuten.buten_nm,
									recDelbuten.buten_rnm,
									recDelbuten.group_cd,
									recDelbuten.post_no,
									recDelbuten.add1,
									recDelbuten.add2,
									recDelbuten.add3,
									recDelbuten.busho_nm,
									recDelbuten.tel_no,
									recDelbuten.fax_no,
									recDelbuten.mail_add,
									recDelbuten.data_recv_ymd,
									'1',
									'EIP514',
									'未承認のため処理できません。',
								nSeq_No,
								cSeq_flg
								);
					-- エラーフラグに'1'を設定
					cFlg := '1';
				END IF;
			END IF;
			-- 発行体マスタのデータの口座店コードをチェック
			SELECT
				count(*) 
			INTO STRICT 
				nCount
			FROM 
				mhakkotai
			WHERE 
				itaku_kaisha_cd = recDelbuten.itaku_kaisha_cd
			AND 
				koza_ten_cd     = recDelbuten.buten_cd;
			-- データが存在した場合
			IF nCount <> 0 THEN
				-- メッセージＩＤ
				cMsgId := 'EIP519';
				-- ログ用メッセージ
				vLmsg := '＜テーブル:発行体,口座店コード:' || recDelbuten.buten_cd || '＞';
				-- メッセージ通知用メッセージ
				vTmsg := '使用中のため削除できません。' ||
						 '＜テーブル:発行体、口座店コード:' || recDelbuten.buten_cd || '＞';
				-- エラー処理
				nRtnCd := SFIPF009K00R06_ERR_FUNC(recDelbuten.itaku_kaisha_cd, cMsgId, vLmsg, vTmsg, '重要');
				-- 部店更新リストワーク登録サブルーチンの呼び出し
				nRtnCd := SFIPF009K00R06_INSERT_FUNC(
								recDelbuten.itaku_kaisha_cd,
								nSeq_No,
								cMinusTekiyo_Ymd,
								cYoyaku_Kbn,
								recDelbuten.buten_cd,
								recDelbuten.buten_nm,
								recDelbuten.buten_rnm,
								recDelbuten.group_cd,
								recDelbuten.post_no,
								recDelbuten.add1,
								recDelbuten.add2,
								recDelbuten.add3,
								recDelbuten.busho_nm,
								recDelbuten.tel_no,
								recDelbuten.fax_no,
								recDelbuten.mail_add,
								recDelbuten.data_recv_ymd,
								'1',
								'EIP519',
								'使用中のため削除できません。'
							);
				-- エラーフラグに'1'を設定
				cFlg := '1';
			END IF;
			-- 発行体マスタのデータの営業店コードをチェック
			SELECT
				count(*) 
			INTO STRICT 
				nCount
			FROM 
				mhakkotai
			WHERE 
				itaku_kaisha_cd = recDelbuten.itaku_kaisha_cd
			AND 
				eigyoten_cd     = recDelbuten.buten_cd;
			-- データが存在した場合
			IF nCount <> 0 THEN
				-- メッセージＩＤ
				cMsgId := 'EIP519';
				-- ログ用メッセージ
				vLmsg := '＜テーブル:発行体,営業店コード:' || recDelbuten.buten_cd || '＞';
				-- メッセージ通知用メッセージ
				vTmsg := '使用中のため削除できません。' ||
						 '＜テーブル:発行体、営業店コード:' || recDelbuten.buten_cd || '＞';
				-- エラー処理
				nRtnCd := SFIPF009K00R06_ERR_FUNC(recDelbuten.itaku_kaisha_cd, cMsgId, vLmsg, vTmsg, '重要');
				-- 部店更新リストワーク登録サブルーチンの呼び出し
				nRtnCd := SFIPF009K00R06_INSERT_FUNC(
								recDelbuten.itaku_kaisha_cd,
								nSeq_No,
								cMinusTekiyo_Ymd,
								cYoyaku_Kbn,
								recDelbuten.buten_cd,
								recDelbuten.buten_nm,
								recDelbuten.buten_rnm,
								recDelbuten.group_cd,
								recDelbuten.post_no,
								recDelbuten.add1,
								recDelbuten.add2,
								recDelbuten.add3,
								recDelbuten.busho_nm,
								recDelbuten.tel_no,
								recDelbuten.fax_no,
								recDelbuten.mail_add,
								recDelbuten.data_recv_ymd,
								'1',
								'EIP519',
								'使用中のため削除できません。'
							);
				-- エラーフラグに'1'を設定
				cFlg := '1';
			END IF;
			-- 口座振替区分情報のデータの件数をチェック
			SELECT
				count(*) 
			INTO STRICT 
				nCount
			FROM 
				koza_frk
			WHERE 
				itaku_kaisha_cd = recDelbuten.itaku_kaisha_cd
			AND 
				koza_ten_cd     = recDelbuten.buten_cd;
			-- データが存在した場合
			IF nCount <> 0 THEN
				-- メッセージＩＤ
				cMsgId := 'EIP519';
				-- ログ用メッセージ
				vLmsg := '＜テーブル:口座振替区分情報,口座店コード:' || recDelbuten.buten_cd || '＞';
				-- メッセージ通知用メッセージ
				vTmsg := '使用中のため削除できません。' ||
						 '＜テーブル:口座振替区分情報、口座店コード:' || recDelbuten.buten_cd || '＞';
				-- エラー処理
				nRtnCd := SFIPF009K00R06_ERR_FUNC(recDelbuten.itaku_kaisha_cd, cMsgId, vLmsg, vTmsg, '重要');
				-- 部店更新リストワーク登録サブルーチンの呼び出し
				nRtnCd := SFIPF009K00R06_INSERT_FUNC(
								recDelbuten.itaku_kaisha_cd,
								nSeq_No,
								cMinusTekiyo_Ymd,
								cYoyaku_Kbn,
								recDelbuten.buten_cd,
								recDelbuten.buten_nm,
								recDelbuten.buten_rnm,
								recDelbuten.group_cd,
								recDelbuten.post_no,
								recDelbuten.add1,
								recDelbuten.add2,
								recDelbuten.add3,
								recDelbuten.busho_nm,
								recDelbuten.tel_no,
								recDelbuten.fax_no,
								recDelbuten.mail_add,
								recDelbuten.data_recv_ymd,
								'1',
								'EIP519',
								'使用中のため削除できません。'
							);
				-- エラーフラグに'1'を設定
				cFlg := '1';
			END IF;
			IF cFlg = '0' THEN
				-- 部店履歴テーブル更新処理
				INSERT INTO mbuten_rireki(
					itaku_kaisha_cd,
					buten_cd,
					buten_nm,
					buten_rnm,
					group_cd,
					post_no,
					add1,
					add2,
					add3,
					busho_nm,
					tel_no,
					fax_no,
					mail_add,
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
				SELECT
					itaku_kaisha_cd,
					buten_cd,
					buten_nm,
					buten_rnm,
					group_cd,
					post_no,
					add1,
					add2,
					add3,
					busho_nm,
					tel_no,
					fax_no,
					mail_add,
					shori_kbn,
					last_teisei_dt,
					last_teisei_id,
					shonin_dt,
					shonin_id,
					current_timestamp,
					'BATCH',
					sakusei_dt,
					sakusei_id
				FROM 
					mbuten
				WHERE 
					itaku_kaisha_cd = recDelbuten.itaku_kaisha_cd
				AND 
					buten_cd        = recDelbuten.buten_cd;
				-- 部店マスタ削除処理
				DELETE FROM mbuten
				WHERE
					itaku_kaisha_cd = recDelbuten.itaku_kaisha_cd
				AND 
					buten_cd        = recDelbuten.buten_cd;
				-- 部店更新リストワーク登録サブルーチンの呼び出し
				nRtnCd := SFIPF009K00R06_INSERT_FUNC(
								recDelbuten.itaku_kaisha_cd,
								nSeq_No,
								cMinusTekiyo_Ymd,
								cYoyaku_Kbn,
								recDelbuten.buten_cd,
								recDelbuten.buten_nm,
								recDelbuten.buten_rnm,
								recDelbuten.group_cd,
								recDelbuten.post_no,
								recDelbuten.add1,
								recDelbuten.add2,
								recDelbuten.add3,
								recDelbuten.busho_nm,
								recDelbuten.tel_no,
								recDelbuten.fax_no,
								recDelbuten.mail_add,
								recDelbuten.data_recv_ymd,
								'0',
								' ',
								' '
							);
			END IF;
		END LOOP;
	END IF;
	RETURN pkconstant.success();
--==============================================================================
--                  エラー処理                                                  
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'IPF009K00R06', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf009k00r06 ( l_inYoyaku_kbn TEXT  ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipf009k00r06_err_func ( l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inMsgId TEXT,		-- メッセージＩＤ
 l_inLMsg text,	-- ログ用メッセージ
 l_inTMsg text,	-- 通知用メッセージ
 l_inLevel TEXT 		-- 通知レベル
 ) RETURNS integer AS $body$
DECLARE
	nRtnCd numeric;
	MSG_MSGTSUCHI_ERR CONSTANT varchar(30) := 'メッセージ通知登録エラー';
BEGIN
	--エラーログ出力
	CALL pkLog.error(
		l_inMsgId,
		'IPF009K00R06', 
		l_inLMsg
	);
	--メッセージ通知テーブルへ書き込み
	nRtnCd := SfIpMsgTsuchiUpdate(
					l_inItakuKaishaCd,
					'CAPS',
					l_inLevel,
					'1',
					'0',
					l_inTMsg,
					'BATCH',
					'BATCH'
				);
	IF nRtnCd <> 0 THEN
		CALL pkLog.fatal(
			'ECM701',
			'IPF009K00R06', 
			MSG_MSGTSUCHI_ERR
		);
		RETURN pkconstant.FATAL();
	END IF;
	RETURN pkconstant.error();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf009k00r06_err_func ( l_inItakuKaishaCd TEXT, l_inMsgId TEXT, l_inLMsg text, l_inTMsg text, l_inLevel TEXT  ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipf009k00r06_insert_func ( l_inwk01 TEXT,				-- 委託会社コード
 l_inwk02 numeric,			-- 連番
 l_inwk03 TEXT,				-- 適用開始日
 l_inwk04 TEXT,				-- 予約区分
 l_inwk05 TEXT,				-- 部店コード
 l_inwk06 text,			-- 部店名称
 l_inwk07 text,			-- 部店略称
 l_inwk08 TEXT,				-- グループコード
 l_inwk09 TEXT,				-- 郵便番号
 l_inwk10 text,			-- 住所１
 l_inwk11 text,			-- 住所２
 l_inwk12 text,			-- 住所３
 l_inwk13 text,			-- 担当部署名称
 l_inwk14 text,			-- 電話番号
 l_inwk15 text,			-- ＦＡＸ番号
 l_inwk16 text,			-- メールアドレス
 l_inwk17 TEXT,				-- データ受信日
 l_inwk18 TEXT,				-- エラー有無フラグ
 l_inwk19 TEXT,				-- エラーコード
 l_inwk20 text,			-- エラー内容
 INOUT nSeq_No numeric,			-- 連番 (parent variable)
 INOUT cSeq_flg TEXT			-- SEQ_NO用フラグ (parent variable)
 ) AS $body$
BEGIN
	-- 対象レコードが変わる毎にSEQ_NOをインクリメント
	IF cSeq_flg = '0' THEN
		-- 部店更新リストワークの連番カウント
		nSeq_No := nSeq_No + 1;
	END IF;
	-- 部店更新リストワークへ書き込み
	INSERT INTO butenkoshin_list_wk(
		itaku_kaisha_cd,
		seq_no,
		tekiyost_ymd,
		yoyaku_kbn,
		buten_cd,
		buten_nm,
		buten_rnm,
		group_cd,
		post_no,
		add1,
		add2,
		add3,
		busho_nm,
		tel_no,
		fax_no,
		mail_add,
		data_recv_ymd,
		err_umu_flg,
		err_cd_6,
		err_nm_30,
		kousin_id,
		sakusei_id
	)
	VALUES (
		l_inwk01,
		l_inwk02,
		l_inwk03,
		l_inwk04,
		l_inwk05,
		l_inwk06,
		l_inwk07,
		l_inwk08,
		l_inwk09,
		l_inwk10,
		l_inwk11,
		l_inwk12,
		l_inwk13,
		l_inwk14,
		l_inwk15,
		l_inwk16,
		l_inwk17,
		l_inwk18,
		l_inwk19,
		l_inwk20,
		'BATCH',
		'BATCH'
	);
	-- シーケンス用フラグに'1'を設定
	cSeq_flg := '1';
	RETURN pkconstant.success();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf009k00r06_insert_func ( l_inwk01 TEXT, l_inwk02 numeric, l_inwk03 TEXT, l_inwk04 TEXT, l_inwk05 TEXT, l_inwk06 text, l_inwk07 text, l_inwk08 TEXT, l_inwk09 TEXT, l_inwk10 text, l_inwk11 text, l_inwk12 text, l_inwk13 text, l_inwk14 text, l_inwk15 text, l_inwk16 text, l_inwk17 TEXT, l_inwk18 TEXT, l_inwk19 TEXT, l_inwk20 text ) FROM PUBLIC;
