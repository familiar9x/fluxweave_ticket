




CREATE OR REPLACE FUNCTION sfipf009k00r04 () RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * ファイル受信ＩＦテーブルからファイル送受信保存テーブルに登録する。
-- * 同時に、ファイル送受信保存テーブルに受信データを登録する。
-- * その後、部店更新を行う。
-- * 
-- * @author 戸倉　一成
-- * @version $Revision: 1.9 $
-- * $Id: SFIPF009K00R04.sql,v 1.9 2005/12/15 07:35:22 kobayashi Exp $
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
	nNo                    numeric;							-- データ内連番
	nSeq_No                numeric;							-- データ内連番
	cGyoumuDt              sreport_wk.sakusei_ymd%type;		-- 業務日付
	cButen_Cd              char(4);							-- 部店コード
	cShiyo_Kaishi_Ymd      char(8);							-- 使用開始日
	cShiyo_Teishi_Ymd      char(8);							-- 使用停止日
	cButen_Nm              char(30);						-- 部店名称
	cButen_Nm_Ck           varchar(30);					-- 部店名称
	cTel_No                char(12);						-- 電話番号
	cTel_Ck                varchar(12);					-- 電話番号
	cHaiten_Ymd            char(8);							-- 廃店日
	cButen_Rnm             char(10);						-- 部店略称
	cButen_Rnm_Ck          varchar(10);					-- 部店略称
	cGroup_Cd              char(4);							-- グループコード
	cItaku_Kaisha_Cd       char(4);							-- 委託会社コード
	cFlg                   char(1);							-- エラーフラグ
	cFlg_Ins               char(1);							-- 更新判別用フラグ
	cSeq_flg               char(1);							-- SEQ_NO用フラグ
	cTemp                  char(3);							-- 文字列一時格納用
	vButen_Cd_Aft          varchar(4);						-- 部店コード
	vLmsg                  varchar(500);					-- ログ用メッセージ
	vTmsg                  varchar(500);					-- 通知用メッセージ
--==============================================================================
--                  カーソル定義                                                
--==============================================================================
	curFilercvif CURSOR FOR
		SELECT 
			data_id,
			make_dt,
			make_cnt,
			data_seq,
			data_sect_filedbif
		FROM 
			filercvif
		WHERE 
			sr_stat = '0'
		AND 
			data_id = '21001'
		ORDER BY 
			make_cnt, 
			data_seq;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 業務日付を取得
	cGyoumuDt := pkDate.getGyomuYmd();
	-- 委託会社コード取得
	SELECT kaiin_id INTO STRICT cItaku_Kaisha_Cd
	FROM   sown_info;
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
	-- データ内連番初期化
	nNo := 0;
	-- データの件数をチェック
	SELECT count(*) INTO STRICT nCount
	FROM   filercvif
	WHERE  sr_stat = '0'
	AND    data_id = '21001';
	-- データが存在しない場合
	IF nCount = 0 THEN
		RETURN pkconstant.success();
	END IF;
	-- ファイル送受信保存テーブル更新処理
	INSERT INTO filesave(
		data_id,
		make_dt,
		make_cnt,
		data_seq,
		data_sect_filedbif
	)
	SELECT
		data_id,
		make_dt,
		make_cnt,
		data_seq,
		data_sect_filedbif
	FROM 
		filercvif
	WHERE 
		sr_stat = '0'
	AND 
		data_id = '21001';
	-- 部店マスタ（予約）テーブルを削除
	DELETE FROM mbuten_yoyaku;
	-- 部店マスタ（予約）テーブル登録処理
	FOR recFilercvif IN curFilercvif LOOP
		-- 変数初期化
		cFlg_Ins := '0';
		cSeq_flg := '0';
		cTemp := '';
		-- ファイル受信ＩＦテーブル更新処理
		UPDATE filercvif
		SET    sr_stat  = '1'
		WHERE  data_id  = recFilercvif.data_id
		AND    make_dt  = recFilercvif.make_dt
		AND    make_cnt = recFilercvif.make_cnt
		AND    data_seq = recFilercvif.data_seq;
		-- ヘッダー、トレーラレコードは処理しない
		IF  SUBSTR(recFilercvif.data_sect_filedbif, 1, 2) <> 'イ8'
		AND SUBSTR(recFilercvif.data_sect_filedbif, 1, 2) <> 'イ9' 
		AND SUBSTR(recFilercvif.data_sect_filedbif, 1, 2)  = 'エキ' THEN 
			-- データ部分割
			cButen_Cd         := substr(recFilercvif.data_sect_filedbif, 3, 4);
			cShiyo_Teishi_Ymd := substr(recFilercvif.data_sect_filedbif, 7, 8);
			cShiyo_Kaishi_Ymd := substr(recFilercvif.data_sect_filedbif, 23, 8);
			cButen_Nm         := substr(recFilercvif.data_sect_filedbif, 165, 30);
			cTel_No           := substr(recFilercvif.data_sect_filedbif, 269, 12);
			cHaiten_Ymd       := substr(recFilercvif.data_sect_filedbif, 353, 8);
			cButen_Rnm        := substr(recFilercvif.data_sect_filedbif, 361, 10);
			cTemp             := substr(recFilercvif.data_sect_filedbif, 427, 3);
			-- グループコード編集
			-- スペースをゼロに置換する
			cTemp := REPLACE(cTemp, ' ', '0');
			-- 前ゼロ（1桁）を補完する
			cGroup_Cd := trim(both '0' || trim(both cTemp));
			-- 初期化
			vButen_Cd_Aft := '';
			cFlg          := '0';
			-- データチェック（部店コード）
			-- フル桁スペースはエラー扱いとする
			IF coalesce(trim(both cButen_Cd)::text, '') = '' THEN
				-- 更新判別用フラグに'1'を設定
				cFlg_Ins := '1';
				-- ログ用メッセージ
				vLmsg := '＜データ:店舗（' || recFilercvif.data_seq ||
						 '）＞＜部店コード:' || cButen_Cd || '＞';
				-- メッセージ通知用メッセージ
				vTmsg := 'フォーマット不正' ||
						 '＜店舗（' || recFilercvif.data_seq ||
						 '）＞＜部店コード:' || cButen_Cd || '＞';
				-- エラー処理
				SELECT io_cSeq_flg, io_nSeq_No INTO cSeq_flg, nSeq_No FROM SFIPF009K00R04_ERR_FUNC(
							  vLmsg,
							  substr(vTmsg, 1, 80),
							  cItaku_Kaisha_Cd,
							  nSeq_No,
							  cButen_Cd,
							  cButen_Nm,
							  cButen_Rnm,
							  cGroup_Cd,
							  cTel_No,
							  '1',
							  'ECM502',
							  'フォーマット不正＜部店コード:' || cButen_Cd || '＞',
						  cSeq_flg,
						  nSeq_No,
						  cGyoumuDt
						  );
			END IF;
			-- データ値チェック
			FOR count_len IN 1 .. 4 LOOP
				IF  SUBSTR(cButen_Cd, count_len, 1) >= '0'
				AND SUBSTR(cButen_Cd, count_len, 1) <= '9' 
				OR  SUBSTR(cButen_Cd, count_len, 1) = ' ' THEN
					IF SUBSTR(cButen_Cd, count_len, 1) = ' ' THEN
						vButen_Cd_Aft := vButen_Cd_Aft || '0';
					ELSE
						vButen_Cd_Aft := vButen_Cd_Aft || SUBSTR(cButen_Cd, count_len, 1);
					END IF;
				ELSE
					cFlg := '1';
				END IF;
			END LOOP;
			-- エラー処理
			IF cFlg = '1' THEN
				-- 更新判別用フラグに'1'を設定
				cFlg_Ins := '1';
				-- ログ用メッセージ
				vLmsg := '＜データ:店舗（' || recFilercvif.data_seq ||
						 '）＞＜部店コード:' || cButen_Cd || '＞';
				-- メッセージ通知用メッセージ
				vTmsg := 'フォーマット不正' ||
						 '＜店舗（' || recFilercvif.data_seq ||
						 '）＞＜部店コード:' || cButen_Cd || '＞';
				-- エラー処理
				SELECT io_cSeq_flg, io_nSeq_No INTO cSeq_flg, nSeq_No FROM SFIPF009K00R04_ERR_FUNC(
							  vLmsg,
							  substr(vTmsg, 1, 80),
							  cItaku_Kaisha_Cd,
							  nSeq_No,
							  cButen_Cd,
							  cButen_Nm,
							  cButen_Rnm,
							  cGroup_Cd,
							  cTel_No,
							  '1',
							  'ECM502',
							  'フォーマット不正＜部店コード:' || cButen_Cd || '＞',
						  cSeq_flg,
						  nSeq_No,
						  cGyoumuDt
						  );
			END IF;
			-- データチェック（使用停止日）
			IF cShiyo_Teishi_Ymd != '99999999' AND cShiyo_Teishi_Ymd != '        ' THEN
				-- 日付妥当性チェック
				nRtnCd := pkDate.validateDate(cShiyo_Teishi_Ymd);
			END IF;
			IF nRtnCd <> 0 THEN
				-- 更新判別用フラグに'1'を設定
				cFlg_Ins := '1';
				-- ログ用メッセージ
				vLmsg := '＜データ:店舗（' || recFilercvif.data_seq ||
						 '）＞＜使用停止日:' || cShiyo_Teishi_Ymd || '＞';
				-- メッセージ通知用メッセージ
				vTmsg := 'フォーマット不正' ||
						 '＜店舗（' || recFilercvif.data_seq ||
						 '）＞＜使用停止日:' || cShiyo_Teishi_Ymd || '＞';
				-- エラー処理
				SELECT io_cSeq_flg, io_nSeq_No INTO cSeq_flg, nSeq_No FROM SFIPF009K00R04_ERR_FUNC(
							  vLmsg,
							  substr(vTmsg, 1, 80),
							  cItaku_Kaisha_Cd,
							  nSeq_No,
							  cButen_Cd,
							  cButen_Nm,
							  cButen_Rnm,
							  cGroup_Cd,
							  cTel_No,
							  '1',
							  'ECM502',
							  'フォーマット不正＜使用停止日:' || cShiyo_Teishi_Ymd || '＞',
						  cSeq_flg,
						  nSeq_No,
						  cGyoumuDt
						  );
			END IF;
			-- データチェック（使用開始日）
			IF cShiyo_Kaishi_Ymd != '99999999' AND cShiyo_Kaishi_Ymd != '        '
			AND cShiyo_Kaishi_Ymd != '00000000' THEN
				-- 日付妥当性チェック
				nRtnCd := pkDate.validateDate(cShiyo_Kaishi_Ymd);
			END IF;
			IF nRtnCd <> 0 THEN
				-- 更新判別用フラグに'1'を設定
				cFlg_Ins := '1';
				-- ログ用メッセージ
				vLmsg := '＜データ:店舗（' || recFilercvif.data_seq ||
						 '）＞＜使用開始日:' || cShiyo_Kaishi_Ymd || '＞';
				-- メッセージ通知用メッセージ
				vTmsg := 'フォーマット不正' ||
						 '＜店舗（' || recFilercvif.data_seq ||
						 '）＞＜使用開始日:' || cShiyo_Kaishi_Ymd || '＞';
				-- エラー処理
				SELECT io_cSeq_flg, io_nSeq_No INTO cSeq_flg, nSeq_No FROM SFIPF009K00R04_ERR_FUNC(
							  vLmsg,
							  substr(vTmsg, 1, 80),
							  cItaku_Kaisha_Cd,
							  nSeq_No,
							  cButen_Cd,
							  cButen_Nm,
							  cButen_Rnm,
							  cGroup_Cd,
							  cTel_No,
							  '1',
							  'ECM502',
							  'フォーマット不正＜使用開始日:' || cShiyo_Kaishi_Ymd || '＞',
						  cSeq_flg,
						  nSeq_No,
						  cGyoumuDt
						  );
			END IF;
			-- データチェック（部店名称）
			-- 部店名称がallスペース(全角スペース15個)のものはチェックＯＫとする
			IF cButen_Nm <> '　　　　　　　　　　　　　　　' THEN
				-- 全角チェック
				cButen_Nm_Ck := '';
				cButen_Nm_Ck := trim(both cButen_Nm);
				nRtnCd := sfCmIsFullsizeChar(cButen_Nm_Ck);
				IF nRtnCd <> 0 THEN
					-- 更新判別用フラグに'1'を設定
					cFlg_Ins := '1';
					-- ログ用メッセージ
					vLmsg := '＜データ:店舗（' || recFilercvif.data_seq ||
							 '）＞＜部店名称:' || cButen_Nm || '＞';
					-- メッセージ通知用メッセージ
					vTmsg := 'フォーマット不正' ||
							 '＜店舗（' || recFilercvif.data_seq ||
							 '）＞＜部店名称:' || cButen_Nm || '＞';
					-- エラー処理
					SELECT io_cSeq_flg, io_nSeq_No INTO cSeq_flg, nSeq_No FROM SFIPF009K00R04_ERR_FUNC(
								  vLmsg,
								  substr(vTmsg, 1, 80),
								  cItaku_Kaisha_Cd,
								  nSeq_No,
								  cButen_Cd,
								  cButen_Nm,
								  cButen_Rnm,
								  cGroup_Cd,
								  cTel_No,
								  '1',
								  'ECM502',
								  'フォーマット不正＜部店名称:' || cButen_Nm || '＞',
						  cSeq_flg,
						  nSeq_No,
						  cGyoumuDt
							  );
				END IF;
				-- TRIMを掛ける
				cButen_Nm_Ck := trim(both '　' FROM cButen_Nm_Ck);
			ELSE
				-- 部店名称がallスペースのものは、そのままMBUTEN_YOYAKUへINSERT
				cButen_Nm_Ck := cButen_Nm;
			END IF;
			-- 初期化
			cFlg := '0';
			-- データチェック（電話番号）
			-- 電話番号がallスペースのものはチェックＯＫとする
			IF cTel_No <> '            ' THEN
					cTel_Ck := trim(both cTel_No);
				FOR count_len IN 1 .. 12 LOOP
					IF (SUBSTR(cTel_Ck, count_len, 1) < '0'
					OR   SUBSTR(cTel_Ck, count_len, 1) > '9') 
					AND SUBSTR(cTel_Ck, count_len, 1) <> '-' THEN
						cFlg := '1';
					END IF;
				END LOOP;
				-- エラー処理
				IF cFlg = '1' THEN
					-- 更新判別用フラグに'1'を設定
					cFlg_Ins := '1';
					-- ログ用メッセージ
					vLmsg := '＜データ:店舗（' || recFilercvif.data_seq ||
							 '）＞＜電話番号:' || cTel_No || '＞';
					-- メッセージ通知用メッセージ
					vTmsg := 'フォーマット不正' ||
							 '＜店舗（' || recFilercvif.data_seq ||
							 '）＞＜電話番号:' || cTel_No || '＞';
					-- エラー処理
					SELECT io_cSeq_flg, io_nSeq_No INTO cSeq_flg, nSeq_No FROM SFIPF009K00R04_ERR_FUNC(
								  vLmsg,
								  substr(vTmsg, 1, 80),
								  cItaku_Kaisha_Cd,
								  nSeq_No,
								  cButen_Cd,
								  cButen_Nm,
								  cButen_Rnm,
								  cGroup_Cd,
								  cTel_No,
								  '1',
								  'ECM502',
--								  'フォーマット不正＜電話番号:' || cTel_Ck || '＞',
						  cSeq_flg,
						  nSeq_No,
						  cGyoumuDt
								  'フォーマット不正＜電話番号:' || cTel_No || '＞'
							  );
				END IF;
			ELSE
				-- 電話番号がallスペースのものは、そのままMBUTEN_YOYAKUへINSERT
				cTel_Ck := cTel_No;
			END IF;
			-- データチェック（廃店日）
			-- 廃店日が'       0'のものは'99999999'に更新する。
			IF cHaiten_Ymd = '       0' THEN
				cHaiten_Ymd := '99999999';
			END IF;
			IF cHaiten_Ymd != '99999999' AND cHaiten_Ymd != '        ' THEN
				-- 日付妥当性チェック
				nRtnCd := pkDate.validateDate(cHaiten_Ymd);
			END IF;
			IF nRtnCd <> 0 THEN
				-- 更新判別用フラグに'1'を設定
				cFlg_Ins := '1';
			-- ログ用メッセージ
				vLmsg := '＜データ:店舗（' || recFilercvif.data_seq ||
						 '）＞＜廃店日:' || cHaiten_Ymd || '＞';
				-- メッセージ通知用メッセージ
				vTmsg := 'フォーマット不正' ||
						 '＜店舗（' || recFilercvif.data_seq ||
						 '）＞＜廃店日:' || cHaiten_Ymd || '＞';
				-- エラー処理
				SELECT io_cSeq_flg, io_nSeq_No INTO cSeq_flg, nSeq_No FROM SFIPF009K00R04_ERR_FUNC(
							  vLmsg,
							  substr(vTmsg, 1, 80),
							  cItaku_Kaisha_Cd,
							  nSeq_No,
							  cButen_Cd,
							  cButen_Nm,
							  cButen_Rnm,
							  cGroup_Cd,
							  cTel_No,
							  '1',
							  'ECM502',
							  'フォーマット不正＜廃店日:' || cHaiten_Ymd || '＞',
						  cSeq_flg,
						  nSeq_No,
						  cGyoumuDt
						  );
			END IF;
			-- データチェック（部店略称）
			-- 部店略称がallスペース(全角スペース5個)のものはチェックＯＫとする
			IF cButen_Rnm <> '　　　　　' THEN
				-- 全角チェック
				cButen_Rnm_Ck := '';
				cButen_Rnm_Ck := trim(both cButen_Rnm);
				nRtnCd := sfCmIsFullsizeChar(cButen_Rnm_Ck);
				IF nRtnCd <> 0 THEN
					-- 更新判別用フラグに'1'を設定
					cFlg_Ins := '1';
					-- ログ用メッセージ
					vLmsg := '＜データ:店舗（' || recFilercvif.data_seq ||
							 '）＞＜部店略称:' || cButen_Rnm || '＞';
					-- メッセージ通知用メッセージ
					vTmsg := 'フォーマット不正' ||
							 '＜店舗（' || recFilercvif.data_seq ||
							 '）＞＜部店略称:' || cButen_Rnm || '＞';
					-- エラー処理
					SELECT io_cSeq_flg, io_nSeq_No INTO cSeq_flg, nSeq_No FROM SFIPF009K00R04_ERR_FUNC(
								  vLmsg,
								  substr(vTmsg, 1, 80),
								  cItaku_Kaisha_Cd,
								  nSeq_No,
								  cButen_Cd,
								  cButen_Nm,
								  cButen_Rnm,
								  cGroup_Cd,
								  cTel_No,
								  '1',
								  'ECM502',
								  'フォーマット不正＜部店略称:' || cButen_Rnm || '＞',
						  cSeq_flg,
						  nSeq_No,
						  cGyoumuDt
							  );
				END IF;
				-- TRIMを掛ける
				cButen_Rnm_Ck := trim(both '　' FROM cButen_Rnm_Ck);
			ELSE
				-- 部店略称がallスペースのものは、そのままMBUTEN_YOYAKUへINSERT
				cButen_Rnm_Ck := cButen_Rnm;
			END IF;
			-- データチェック（グループコード）
			-- 半角英数チェック
			nRtnCd := sfCmIsHalfAlphanumeric2(trim(both cGroup_Cd));
			-- エラー処理
			IF nRtnCd <> 0 THEN
				-- 更新判別用フラグに'1'を設定
				cFlg_Ins := '1';
				-- ログ用メッセージ
				vLmsg := '＜データ:店舗（' || recFilercvif.data_seq ||
						 '）＞＜グループコード:' || cGroup_Cd || '＞';
				-- メッセージ通知用メッセージ
				vTmsg := 'フォーマット不正' ||
						 '＜店舗（' || recFilercvif.data_seq ||
						 '）＞＜グループコード:' || cGroup_Cd || '＞';
				-- エラー処理
				SELECT io_cSeq_flg, io_nSeq_No INTO cSeq_flg, nSeq_No FROM SFIPF009K00R04_ERR_FUNC(
							  vLmsg,
							  substr(vTmsg, 1, 80),
							  cItaku_Kaisha_Cd,
							  nSeq_No,
							  cButen_Cd,
							  cButen_Nm,
							  cButen_Rnm,
							  cGroup_Cd,
							  cTel_No,
							  '1',
							  'ECM502',
							  'フォーマット不正＜グループコード:' || cGroup_Cd || '＞',
						  cSeq_flg,
						  nSeq_No,
						  cGyoumuDt
						  );
			END IF;
			-- 更新判別用フラグが'0'の場合のみ、更新処理を行う
			IF cFlg_Ins = '0' THEN
				-- データ内連番カウント
				nNo := nNo + 1;
				-- 部店マスタ（予約）テーブル更新
				INSERT INTO mbuten_yoyaku(
					itaku_kaisha_cd,
					seq_no,
					buten_cd,
					buten_nm,
					buten_rnm,
					group_cd,
					tel_no,
					shiyo_kaishi_ymd,
					shiyo_teishi_ymd,
					haiten_ymd,
					data_recv_ymd,
					make_dt,
					kousin_id,
					sakusei_id
				)
				VALUES (
					cItaku_Kaisha_Cd,
					nNo,
					vButen_Cd_Aft,
					cButen_Nm_Ck,
					cButen_Rnm_Ck,
					cGroup_Cd,
					cTel_Ck,
					cShiyo_Kaishi_Ymd,
					cShiyo_Teishi_Ymd,
					cHaiten_Ymd,
					cGyoumuDt,
					recFilercvif.make_dt,
					'BATCH',
					'BATCH'
				);
			END IF;
		END IF;
	END LOOP;
	RETURN pkconstant.success();
--==============================================================================
--                  エラー処理                                                  
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'IPF009K00R04', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf009k00r04 () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipf009k00r04_err_func ( l_inLMsg text,			-- ログ用メッセージ
 l_inTMsg text,			-- 通知用メッセージ
 l_inwk01 CHAR,				-- 委託会社コード
 l_inwk02 numeric,				-- 連番
 l_inwk03 CHAR,				-- 部店コード
 l_inwk04 text,			-- 部店名称
 l_inwk05 text,			-- 部店略称
 l_inwk06 CHAR,				-- グループコード
 l_inwk07 text,			-- 電話番号
 l_inwk08 CHAR,				-- エラー有無フラグ
 l_inwk09 CHAR,				-- エラーコード
 l_inwk10 text,				-- エラー内容
 INOUT io_cSeq_flg char(1),
 INOUT io_nSeq_No numeric,
 IN l_cGyoumuDt char(8)
 ) RETURNS RECORD AS $body$
DECLARE
	MSG_MSGTSUCHI_ERR      CONSTANT varchar(30) := 'メッセージ通知登録エラー';
	nRtnCd                 numeric;
BEGIN
	-- 対象レコードが変わる毎にSEQ_NOをインクリメント
	IF io_cSeq_flg = '0' THEN
		-- 部店更新リストワークの連番カウント
		io_nSeq_No := io_nSeq_No + 1;
	END IF;
	--エラーログ出力
	CALL pkLog.error(
		l_inwk09,
		'IPF009K00R04', 
		l_inLMsg
	);
	-- 部店更新リストワークへ書き込み
	INSERT INTO butenkoshin_list_wk(
		itaku_kaisha_cd,
		seq_no,
		buten_cd,
		buten_nm,
		buten_rnm,
		group_cd,
		tel_no,
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
		l_cGyoumuDt,
		l_inwk08,
		l_inwk09,
		l_inwk10,
		'BATCH',
		'BATCH'
	);
	--メッセージ通知テーブルへ書き込み
	nRtnCd := SfIpMsgTsuchiUpdate(	
					l_inwk01,
					'CAPS',
					'重要',
					'1',
					'0',
					l_inTMsg,
					'BATCH',
					'BATCH'
				);
	IF nRtnCd <> 0 THEN
		CALL pkLog.fatal(
			'ECM701',
			'IPF009K00R04', 
			MSG_MSGTSUCHI_ERR
		);
		RETURN;
	END IF;
	-- シーケンス用フラグに'1'を設定
	io_cSeq_flg := '1';
	RETURN;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf009k00r04_err_func ( l_inLMsg text, l_inTMsg text, l_inwk01 CHAR, l_inwk02 numeric, l_inwk03 CHAR, l_inwk04 text, l_inwk05 text, l_inwk06 CHAR, l_inwk07 text, l_inwk08 CHAR, l_inwk09 CHAR, l_inwk10 text ) FROM PUBLIC;
