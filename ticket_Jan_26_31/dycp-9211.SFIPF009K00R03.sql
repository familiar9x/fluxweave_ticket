




CREATE OR REPLACE FUNCTION sfipf009k00r03 () RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * ・ファイル受信IFテーブルから店CIF情報の予約登録管理をする。
-- * ・同時に、ファイル送受信保存テーブルに受信データを登録する。
-- * ・その後、発行体マスタを行う
-- * ・同時に、結果リストに処理結果を追加する。
-- * 
-- * @author 小林　弘幸
-- * @version $Revision: 1.4 $
-- * $Id: SFIPF009K00R03.sql,v 1.4 2005/11/04 10:12:25 kubo Exp $
-- * @return INTEGER
-- *                0:正常終了、データ無し
-- *                1:予期したエラー
-- *               99:予期せぬエラー
-- 
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	nRet				 numeric;								-- 戻り値
	nCount				 numeric;								-- レコード数
	nCount2				 numeric;								-- レコード数
	nMax_Seq			 numeric;								-- 連番
	cFlg				 char(1);								-- 出力フラグ
	cUnyoFlg			 char(1);								-- 運用開始日エラーフラグ
	cTencifFlg			 char(1);								-- 重複チェックフラグ
	cKamokuFlg			 char(1);								-- 科目コードエラーフラグ
	cDataFlg			 char(1);								-- データチェック用フラグ
	cSeq_flg			 char(1);								-- SEQ_NO用フラグ
	cCompDt				 char(8);								-- 比較日付
	cTekiyost_ymd		 char(8);								-- 運用開始日
	cOld_kamoku_cd		 char(2);								-- 旧科目コード
	cNew_kamoku_cd		 char(2);								-- 新科目コード
	cOld_koza_ten_cd	 char(4);								-- 旧口座店コード
	cOld_koza_ten_cifcd  char(8);								-- 旧口座店ＣＩＦコード
	cOld_koza_kamoku	 char(1);								-- 旧口座科目
	cOld_koza_no		 char(8);								-- 旧口座番号
	cNew_koza_ten_cd	 char(4);								-- 新口座店コード
	cNew_koza_ten_cifcd	 char(8);								-- 新口座店ＣＩＦコード
	cNew_koza_kamoku	 char(1);								-- 新口座科目
	cNew_koza_no		 char(8);								-- 新口座番号
	cFilter_shubetu		 char(2);								-- フィルタ種別
	cItaku_kaisha_cd	 sown_info.kaiin_id%type;				-- 委託会社コード
	cGyoumuDt			 ssystem_management.gyomu_ymd%type;		-- 業務日付格納用
	vMsg				 varchar(200);							-- エラーメッセージ
	vLmsg				 varchar(200);							-- ログ用メッセージ
	vTmsg				 varchar(200);							-- 通知用メッセージ
--==============================================================================
--                  カーソル定義                                                
--==============================================================================
	curYoyakuDS CURSOR FOR
		SELECT
			data_id,
			make_dt,
			make_cnt,
			data_seq,
			data_sect_filedbif
		FROM filercvif
		WHERE sr_stat = '0'
		AND   data_id = '21002'
		ORDER BY
			make_cnt,
			data_seq;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 業務日付を取得
	cGyoumuDt := pkDate.getGyomuYmd();
	-- 委託会社コードを取得
	SELECT kaiin_id
	INTO STRICT cItaku_kaisha_cd
	FROM sown_info;
	-- 口座情報更新リストワークの最大連番を取得
	SELECT MAX(seq_no)
	INTO STRICT nMax_Seq
	FROM kozajyohokoshin_list_wk
	WHERE itaku_kaisha_cd = cItaku_kaisha_cd;
	-- ０件の場合、ｎ連番は０をセット
	IF coalesce(nMax_Seq::text, '') = '' THEN
		nMax_Seq := 0;
	END IF;
	-- ファイル受信IFデーブルデータ有無をチェック
	nCount := 0;
	SELECT count(*)
	INTO STRICT nCount
	FROM filercvif
	WHERE sr_stat = '0'
	AND data_id = '21002';
	-- 該当データがない場合、正常リターン
	IF nCount = 0 THEN
		RETURN pkconstant.success();
	ELSIF nCount != 0 THEN
		-- 保存テーブルに登録
		INSERT INTO filesave(
			data_id,
			make_dt,
			make_cnt,
			data_seq,
			data_sect_filedbif
		) SELECT
			data_id,
			make_dt,
			make_cnt,
			data_seq,
			data_sect_filedbif
		FROM filercvif
		WHERE sr_stat = '0'
		AND data_id = '21002';
	END IF;
	-- 店CIF予約テーブルにデータ登録
	FOR recYoyakuDS IN curYoyakuDS LOOP
		-- ファイル受信ＩＦの送受信ステータスを処理済('1'）に更新
		UPDATE filercvif
		SET sr_stat = '1'
		WHERE data_id = recYoyakuDS.data_id
		AND make_dt = recYoyakuDS.make_dt
		AND make_cnt = recYoyakuDS.make_cnt
		AND data_seq = recYoyakuDS.data_seq;
		-- 変数初期化
		nRet := 0;
		vMsg := '';
		vLmsg := '';
		vTmsg := '';
		cFlg := 'A';
		cUnyoFlg := '0';
		cDataFlg := '0';
		cSeq_flg := '0';
		cTencifFlg := '0';
		cKamokuFlg := '0';
		cTekiyost_ymd := '';
		cFilter_shubetu := '';
		cOld_koza_no := '';
		cOld_kamoku_cd := '';
		cOld_koza_kamoku := '';
		cOld_koza_ten_cd := '';
		cOld_koza_ten_cifcd := '';
		cNew_koza_no := '';
		cNew_kamoku_cd := '';
		cNew_koza_kamoku := '';
		cNew_koza_ten_cd := '';
		cNew_koza_ten_cifcd := '';
		-- ヘッダー、トレーラレコードは処理しない
		IF  SUBSTR(recYoyakuDS.data_sect_filedbif, 1, 2) != 'イ8'
		AND SUBSTR(recYoyakuDS.data_sect_filedbif, 1, 2) != 'イ9' THEN 
			-- データ部分割
			-- フィルタ種別
			cFilter_shubetu := SUBSTR(recYoyakuDS.data_sect_filedbif, 1, 2);
			-- 移管実施日
			cTekiyost_ymd := SUBSTR(recYoyakuDS.data_sect_filedbif, 3, 8);
			-- 旧店番号
			cOld_koza_ten_cd := SUBSTR(recYoyakuDS.data_sect_filedbif, 11, 4);
			-- 旧科目
			cOld_kamoku_cd := SUBSTR(recYoyakuDS.data_sect_filedbif, 15, 2);
			-- 旧口座番号
			cOld_koza_no := SUBSTR(recYoyakuDS.data_sect_filedbif, 17, 8);
			-- 旧取引先番号
			cOld_koza_ten_cifcd := SUBSTR(recYoyakuDS.data_sect_filedbif, 25, 8);
			-- 新店番号
			cNew_koza_ten_cd := SUBSTR(recYoyakuDS.data_sect_filedbif, 33, 4);
			-- 新科目
			cNew_kamoku_cd := SUBSTR(recYoyakuDS.data_sect_filedbif, 37, 2);
			-- 新口座番号
			cNew_koza_no := SUBSTR(recYoyakuDS.data_sect_filedbif, 39, 8);
			-- 新取引先番号
			cNew_koza_ten_cifcd := SUBSTR(recYoyakuDS.data_sect_filedbif, 47, 8);
			-- フィルタ種別のチェック
			IF cFilter_shubetu != 'BR' AND cFilter_shubetu != 'SS'
			AND cFilter_shubetu != 'KK' THEN
				-- データチェック用フラグに'１'を設定
				cDataFlg := '1';
				-- 口座情報更新リストワーク用メッセージ
				vMsg := 'フォーマットが不正です。' ||
						'＜フィルタ種別:' || cFilter_shubetu || '＞';
				-- ログ用メッセージ
				vLmsg := '＜データ:口座移管データ(' || recYoyakuDS.data_seq || ')＞' ||
						 '＜フィルタ種別:' || cFilter_shubetu || '＞';
				-- メッセージ通知用メッセージ
				vTmsg := 'フォーマットが不正です。' ||
						 '＜データ:口座移管データ（' || recYoyakuDS.data_seq || '）＞' ||
						 '＜フィルタ種別:' || cFilter_shubetu || '＞';
				-- エラー処理
				SELECT io_cSeq_flg, io_nMax_Seq INTO cSeq_flg, nMax_Seq FROM SFIPF009K00R03_COMMON_FUNC(
							recYoyakuDS.make_dt,
							'ECM502',
							'重要',
							cSeq_flg,
							nMax_Seq,
							vLmsg,
							cItaku_kaisha_cd,
							cTekiyost_ymd,
							cOld_koza_ten_cd,
							cOld_koza_ten_cifcd,
							cOld_koza_kamoku,
							cOld_koza_no,
							cNew_koza_ten_cd,
							cNew_koza_ten_cifcd,
							cNew_koza_kamoku,
							cNew_koza_no,
							cFilter_shubetu,
							cGyoumuDt,
							vMsg,
							vTmsg
						);
				IF nRet = pkconstant.fatal() THEN
					RETURN nRet;
				END IF;
			END IF;
			-- 移管実施日：日付妥当性チェック
			nRet := pkDate.validateDate(cTekiyost_ymd);
			IF nRet != 0 THEN
				-- データチェック用フラグに'１'を設定
				cDataFlg := '1';
				-- 口座情報更新リストワーク用メッセージ
				vMsg := 'フォーマットが不正です。' ||
						'＜移管実施日:' || cTekiyost_ymd || '＞';
				-- ログ用メッセージ
				vLmsg := '＜データ:口座移管データ(' || recYoyakuDS.data_seq || ')＞' ||
						 '＜移管実施日:' || cTekiyost_ymd || '＞';
				-- メッセージ通知用メッセージ
				vTmsg := 'フォーマットが不正です。' ||
						 '＜データ:口座移管データ（' || recYoyakuDS.data_seq || '）＞' ||
						 '＜移管実施日:' || cTekiyost_ymd || '＞';
				-- エラー処理
				SELECT io_cSeq_flg, io_nMax_Seq INTO cSeq_flg, nMax_Seq FROM SFIPF009K00R03_COMMON_FUNC(
							recYoyakuDS.make_dt,
							'ECM502',
							'重要',
							cSeq_flg,
							nMax_Seq,
							vLmsg,
							cItaku_kaisha_cd,
							cTekiyost_ymd,
							cOld_koza_ten_cd,
							cOld_koza_ten_cifcd,
							cOld_koza_kamoku,
							cOld_koza_no,
							cNew_koza_ten_cd,
							cNew_koza_ten_cifcd,
							cNew_koza_kamoku,
							cNew_koza_no,
							cFilter_shubetu,
							cGyoumuDt,
							vMsg,
							vTmsg
						);
				IF nRet = pkconstant.fatal() THEN
					RETURN nRet;
				END IF;
			END IF;
			-- 旧店番号：数値チェック
			nRet := sfCmIsNumeric(cOld_koza_ten_cd);
			IF nRet != 0 THEN
				-- データチェック用フラグに'１'を設定
				cDataFlg := '1';
				-- 口座情報更新リストワーク用メッセージ
				vMsg := 'フォーマットが不正です。' ||
						'＜旧店番号:' || cOld_koza_ten_cd || '＞';
				-- ログ用メッセージ
				vLmsg := '＜データ:口座移管データ(' || recYoyakuDS.data_seq || ')＞' ||
						 '＜旧店番号:' || cOld_koza_ten_cd || '＞';
				-- メッセージ通知用メッセージ
				vTmsg := 'フォーマットが不正です。' ||
						 '＜データ:口座移管データ（' || recYoyakuDS.data_seq || '）＞' ||
						 '＜旧店番号:' || cOld_koza_ten_cd || '＞';
				-- エラー処理
				SELECT io_cSeq_flg, io_nMax_Seq INTO cSeq_flg, nMax_Seq FROM SFIPF009K00R03_COMMON_FUNC(
							recYoyakuDS.make_dt,
							'ECM502',
							'重要',
							cSeq_flg,
							nMax_Seq,
							vLmsg,
							cItaku_kaisha_cd,
							cTekiyost_ymd,
							cOld_koza_ten_cd,
							cOld_koza_ten_cifcd,
							cOld_koza_kamoku,
							cOld_koza_no,
							cNew_koza_ten_cd,
							cNew_koza_ten_cifcd,
							cNew_koza_kamoku,
							cNew_koza_no,
							cFilter_shubetu,
							cGyoumuDt,
							vMsg,
							vTmsg
						);
				IF nRet = pkconstant.fatal() THEN
					RETURN nRet;
				END IF;
			END IF;
			-- 旧科目：半角英数チェック
			nRet := sfCmIsHalfAlphanumeric2(cOld_kamoku_cd);
			IF nRet != 0 THEN
				-- データチェック用フラグに'１'を設定
				cDataFlg := '1';
				-- 口座情報更新リストワーク用メッセージ
				vMsg := 'フォーマットが不正です。' ||
						'＜旧科目:' || cOld_kamoku_cd || '＞';
				-- ログ用メッセージ
				vLmsg := '＜データ:口座移管データ(' || recYoyakuDS.data_seq || ')＞' ||
						 '＜旧科目:' || cOld_kamoku_cd || '＞';
				-- メッセージ通知用メッセージ
				vTmsg := 'フォーマットが不正です。' ||
						 '＜データ:口座移管データ（' || recYoyakuDS.data_seq || '）＞' ||
						 '＜旧科目:' || cOld_kamoku_cd || '＞';
				-- エラー処理
				SELECT io_cSeq_flg, io_nMax_Seq INTO cSeq_flg, nMax_Seq FROM SFIPF009K00R03_COMMON_FUNC(
							recYoyakuDS.make_dt,
							'ECM502',
							'重要',
							cSeq_flg,
							nMax_Seq,
							vLmsg,
							cItaku_kaisha_cd,
							cTekiyost_ymd,
							cOld_koza_ten_cd,
							cOld_koza_ten_cifcd,
							cOld_koza_kamoku,
							cOld_koza_no,
							cNew_koza_ten_cd,
							cNew_koza_ten_cifcd,
							cNew_koza_kamoku,
							cNew_koza_no,
							cFilter_shubetu,
							cGyoumuDt,
							vMsg,
							vTmsg
						);
				IF nRet = pkconstant.fatal() THEN
					RETURN nRet;
				END IF;
			END IF;
			-- 旧口座番号：数値チェック
			nRet := sfCmIsNumeric(cOld_koza_no);
			IF nRet != 0 THEN
				-- データチェック用フラグに'１'を設定
				cDataFlg := '1';
				-- 口座情報更新リストワーク用メッセージ
				vMsg := 'フォーマットが不正です。' ||
						'＜旧口座番号:' || cOld_koza_no || '＞';
				-- ログ用メッセージ
				vLmsg := '＜データ:口座移管データ(' || recYoyakuDS.data_seq || ')＞' ||
						 '＜旧口座番号:' || cOld_koza_no || '＞';
				-- メッセージ通知用メッセージ
				vTmsg := 'フォーマットが不正です。' ||
						 '＜データ:口座移管データ（' || recYoyakuDS.data_seq || '）＞' ||
						 '＜旧口座番号:' || cOld_koza_no || '＞';
				-- エラー処理
				SELECT io_cSeq_flg, io_nMax_Seq INTO cSeq_flg, nMax_Seq FROM SFIPF009K00R03_COMMON_FUNC(
							recYoyakuDS.make_dt,
							'ECM502',
							'重要',
							cSeq_flg,
							nMax_Seq,
							vLmsg,
							cItaku_kaisha_cd,
							cTekiyost_ymd,
							cOld_koza_ten_cd,
							cOld_koza_ten_cifcd,
							cOld_koza_kamoku,
							cOld_koza_no,
							cNew_koza_ten_cd,
							cNew_koza_ten_cifcd,
							cNew_koza_kamoku,
							cNew_koza_no,
							cFilter_shubetu,
							cGyoumuDt,
							vMsg,
							vTmsg
						);
				IF nRet = pkconstant.fatal() THEN
					RETURN nRet;
				END IF;
			END IF;
			-- 旧取引先番号：数値チェック
			nRet := sfCmIsNumeric(cOld_koza_ten_cifcd);
			IF nRet != 0 THEN
				-- データチェック用フラグに'１'を設定
				cDataFlg := '1';
				-- 口座情報更新リストワーク用メッセージ
				vMsg := 'フォーマットが不正です。' ||
						'＜旧取引先番号:' || cOld_koza_ten_cifcd || '＞';
				-- ログ用メッセージ
				vLmsg := '＜データ:口座移管データ(' || recYoyakuDS.data_seq || ')＞' ||
						 '＜旧取引先番号:' || cOld_koza_ten_cifcd || '＞';
				-- メッセージ通知用メッセージ
				vTmsg := 'フォーマットが不正です。' ||
						 '＜データ:口座移管データ（' || recYoyakuDS.data_seq || '）＞' ||
						 '＜旧取引先番号:' || cOld_koza_ten_cifcd || '＞';
				-- エラー処理
				SELECT io_cSeq_flg, io_nMax_Seq INTO cSeq_flg, nMax_Seq FROM SFIPF009K00R03_COMMON_FUNC(
							recYoyakuDS.make_dt,
							'ECM502',
							'重要',
							cSeq_flg,
							nMax_Seq,
							vLmsg,
							cItaku_kaisha_cd,
							cTekiyost_ymd,
							cOld_koza_ten_cd,
							cOld_koza_ten_cifcd,
							cOld_koza_kamoku,
							cOld_koza_no,
							cNew_koza_ten_cd,
							cNew_koza_ten_cifcd,
							cNew_koza_kamoku,
							cNew_koza_no,
							cFilter_shubetu,
							cGyoumuDt,
							vMsg,
							vTmsg
						);
				IF nRet = pkconstant.fatal() THEN
					RETURN nRet;
				END IF;
			END IF;
			-- 新店番号：数値チェック
			nRet := sfCmIsNumeric(cNew_koza_ten_cd);
			IF nRet != 0 THEN
				-- データチェック用フラグに'１'を設定
				cDataFlg := '1';
				-- 口座情報更新リストワーク用メッセージ
				vMsg := 'フォーマットが不正です。' ||
						'＜新店番号:' || cNew_koza_ten_cd || '＞';
				-- ログ用メッセージ
				vLmsg := '＜データ:口座移管データ(' || recYoyakuDS.data_seq || ')＞' ||
						 '＜新店番号:' || cNew_koza_ten_cd || '＞';
				-- メッセージ通知用メッセージ
				vTmsg := 'フォーマットが不正です。' ||
						 '＜データ:口座移管データ（' || recYoyakuDS.data_seq || '）＞' ||
						 '＜新店番号:' || cNew_koza_ten_cd || '＞';
				-- エラー処理
				SELECT io_cSeq_flg, io_nMax_Seq INTO cSeq_flg, nMax_Seq FROM SFIPF009K00R03_COMMON_FUNC(
							recYoyakuDS.make_dt,
							'ECM502',
							'重要',
							cSeq_flg,
							nMax_Seq,
							vLmsg,
							cItaku_kaisha_cd,
							cTekiyost_ymd,
							cOld_koza_ten_cd,
							cOld_koza_ten_cifcd,
							cOld_koza_kamoku,
							cOld_koza_no,
							cNew_koza_ten_cd,
							cNew_koza_ten_cifcd,
							cNew_koza_kamoku,
							cNew_koza_no,
							cFilter_shubetu,
							cGyoumuDt,
							vMsg,
							vTmsg
						);
				IF nRet = pkconstant.fatal() THEN
					RETURN nRet;
				END IF;
			END IF;
			-- 新科目：半角英数チェック
			nRet := sfCmIsHalfAlphanumeric2(cNew_kamoku_cd);
			IF nRet != 0 THEN
				-- データチェック用フラグに'１'を設定
				cDataFlg := '1';
				-- 口座情報更新リストワーク用メッセージ
				vMsg := 'フォーマットが不正です。' ||
						'＜新科目:' || cNew_kamoku_cd || '＞';
				-- ログ用メッセージ
				vLmsg := '＜データ:口座移管データ(' || recYoyakuDS.data_seq || ')＞' ||
						 '＜新科目:' || cNew_kamoku_cd || '＞';
				-- メッセージ通知用メッセージ
				vTmsg := 'フォーマットが不正です。' ||
						 '＜データ:口座移管データ（' || recYoyakuDS.data_seq || '）＞' ||
						 '＜新科目:' || cNew_kamoku_cd || '＞';
				-- エラー処理
				SELECT io_cSeq_flg, io_nMax_Seq INTO cSeq_flg, nMax_Seq FROM SFIPF009K00R03_COMMON_FUNC(
							recYoyakuDS.make_dt,
							'ECM502',
							'重要',
							cSeq_flg,
							nMax_Seq,
							vLmsg,
							cItaku_kaisha_cd,
							cTekiyost_ymd,
							cOld_koza_ten_cd,
							cOld_koza_ten_cifcd,
							cOld_koza_kamoku,
							cOld_koza_no,
							cNew_koza_ten_cd,
							cNew_koza_ten_cifcd,
							cNew_koza_kamoku,
							cNew_koza_no,
							cFilter_shubetu,
							cGyoumuDt,
							vMsg,
							vTmsg
						);
				IF nRet = pkconstant.fatal() THEN
					RETURN nRet;
				END IF;
			END IF;
			-- 新口座番号：数値チェック
			nRet := sfCmIsNumeric(cNew_koza_no);
			IF nRet != 0 THEN
				-- データチェック用フラグに'１'を設定
				cDataFlg := '1';
				-- 口座情報更新リストワーク用メッセージ
				vMsg := 'フォーマットが不正です。' ||
						'＜新口座番号:' || cNew_koza_no || '＞';
				-- ログ用メッセージ
				vLmsg := '＜データ:口座移管データ(' || recYoyakuDS.data_seq || ')＞' ||
						 '＜新口座番号:' || cNew_koza_no || '＞';
				-- メッセージ通知用メッセージ
				vTmsg := 'フォーマットが不正です。' ||
						 '＜データ:口座移管データ（' || recYoyakuDS.data_seq || '）＞' ||
						 '＜新口座番号:' || cNew_koza_no || '＞';
				-- エラー処理
				SELECT io_cSeq_flg, io_nMax_Seq INTO cSeq_flg, nMax_Seq FROM SFIPF009K00R03_COMMON_FUNC(
							recYoyakuDS.make_dt,
							'ECM502',
							'重要',
							cSeq_flg,
							nMax_Seq,
							vLmsg,
							cItaku_kaisha_cd,
							cTekiyost_ymd,
							cOld_koza_ten_cd,
							cOld_koza_ten_cifcd,
							cOld_koza_kamoku,
							cOld_koza_no,
							cNew_koza_ten_cd,
							cNew_koza_ten_cifcd,
							cNew_koza_kamoku,
							cNew_koza_no,
							cFilter_shubetu,
							cGyoumuDt,
							vMsg,
							vTmsg
						);
				IF nRet = pkconstant.fatal() THEN
					RETURN nRet;
				END IF;
			END IF;
			-- 新取引先番号：数値チェック
			nRet := sfCmIsNumeric(cNew_koza_ten_cifcd);
			IF nRet != 0 THEN
				-- データチェック用フラグに'１'を設定
				cDataFlg := '1';
				-- 口座情報更新リストワーク用メッセージ
				vMsg := 'フォーマットが不正です。' ||
						'＜新取引先番号:' || cNew_koza_ten_cifcd || '＞';
				-- ログ用メッセージ
				vLmsg := '＜データ:口座移管データ(' || recYoyakuDS.data_seq || ')＞' ||
						 '＜新取引先番号:' || cNew_koza_ten_cifcd || '＞';
				-- メッセージ通知用メッセージ
				vTmsg := 'フォーマットが不正です。' ||
						 '＜データ:口座移管データ（' || recYoyakuDS.data_seq || '）＞' ||
						 '＜新取引先番号:' || cNew_koza_ten_cifcd || '＞';
				-- エラー処理
				SELECT io_cSeq_flg, io_nMax_Seq INTO cSeq_flg, nMax_Seq FROM SFIPF009K00R03_COMMON_FUNC(
							recYoyakuDS.make_dt,
							'ECM502',
							'重要',
							cSeq_flg,
							nMax_Seq,
							vLmsg,
							cItaku_kaisha_cd,
							cTekiyost_ymd,
							cOld_koza_ten_cd,
							cOld_koza_ten_cifcd,
							cOld_koza_kamoku,
							cOld_koza_no,
							cNew_koza_ten_cd,
							cNew_koza_ten_cifcd,
							cNew_koza_kamoku,
							cNew_koza_no,
							cFilter_shubetu,
							cGyoumuDt,
							vMsg,
							vTmsg
						);
				IF nRet = pkconstant.fatal() THEN
					RETURN nRet;
				END IF;
			END IF;
			-- データチェック用フラグが'0'の場合のみ更新処理を行う
			IF cDataFlg = '0' THEN
				-- コード変換
				-- 旧科目
				IF cOld_kamoku_cd = '21' THEN
					cOld_koza_kamoku := 'T';
				ELSIF cOld_kamoku_cd = '22' THEN
					cOld_koza_kamoku := 'F';
				ELSIF cOld_kamoku_cd = '29' THEN
					cOld_koza_kamoku := 'B';
				ELSIF cOld_kamoku_cd = '80' THEN
					cOld_koza_kamoku := 'S';
				ELSE
					cKamokuFlg := '1';
				END IF;
				-- 新科目
				IF cNew_kamoku_cd = '21' THEN
					cNew_koza_kamoku := 'T';
				ELSIF cNew_kamoku_cd = '22' THEN
					cNew_koza_kamoku := 'F';
				ELSIF cNew_kamoku_cd = '29' THEN
					cNew_koza_kamoku := 'B';
				ELSIF cNew_kamoku_cd = '80' THEN
					cNew_koza_kamoku := 'S';
				ELSE
					cKamokuFlg := '1';
				END IF;
				-- 科目コードが'21'、'22'、'29'、'80'のいずれかの場合のみ下記の処理を行う
				IF cKamokuFlg  = '0' THEN
					-- データ値のチェック
					-- 出力フラグを初期化
					cFlg := 'A';
					-- 移管実施日
					-- 比較日付を設定
					IF cFilter_shubetu = 'BR' THEN
						IF cGyoumuDt >= cTekiyost_ymd THEN
							cUnyoFlg := '1';
						END IF;
					ELSE
						IF cGyoumuDt > cTekiyost_ymd THEN
							cUnyoFlg := '1';
						END IF;
					END IF;
					IF cUnyoFlg = '1' THEN
						-- 出力フラグに'N'を設定
						cFlg := 'N';
						-- 口座情報更新リストワーク用メッセージ
						vMsg := '過去日付のため処理できません。';
						-- ログ用メッセージ
						vLmsg := '＜データ:口座移管データ(' || recYoyakuDS.data_seq || ')＞' ||
								 '＜移管実施日:' || cTekiyost_ymd || '＞';
						-- メッセージ通知用メッセージ
						vTmsg := '過去日付のため処理できません。' ||
								 '＜データ:口座移管（' || recYoyakuDS.data_seq || '）＞' ||
								 '＜移管実施日:' || cTekiyost_ymd || '＞';
						-- エラー処理
						SELECT io_cSeq_flg, io_nMax_Seq INTO cSeq_flg, nMax_Seq FROM SFIPF009K00R03_COMMON_FUNC(
							recYoyakuDS.make_dt,
							'ECM509',
							'重要',
							cSeq_flg,
							nMax_Seq,
							vLmsg,
							cItaku_kaisha_cd,
							cTekiyost_ymd,
							cOld_koza_ten_cd,
							cOld_koza_ten_cifcd,
							cOld_koza_kamoku,
							cOld_koza_no,
							cNew_koza_ten_cd,
							cNew_koza_ten_cifcd,
							cNew_koza_kamoku,
							cNew_koza_no,
							cFilter_shubetu,
							cGyoumuDt,
							vMsg,
							vTmsg
						);
						IF nRet = pkconstant.fatal() THEN
							RETURN nRet;
						END IF;
					ELSE
						-- 旧店番号
						nCount := 0;
						SELECT count(*)
						INTO STRICT nCount
						FROM MBUTEN
						WHERE itaku_kaisha_cd = cItaku_kaisha_cd
						AND buten_cd = cOld_koza_ten_cd;
						IF nCount = 0 THEN
							-- 出力フラグに'A'(追加)を設定
							cFlg := 'A';
							-- 口座情報更新リストワーク用メッセージ
							vMsg := '部店マスタが存在しません。登録してください。';
							-- ログ用メッセージ
							vLmsg := '＜旧店番号:' || cOld_koza_ten_cd || '＞';
							-- メッセージ通知用メッセージ
							vTmsg := '部店マスタが存在しません。登録してください。' ||
									 '＜旧店番号:' || cOld_koza_ten_cd || '＞';
							-- エラー処理
							SELECT io_cSeq_flg, io_nMax_Seq INTO cSeq_flg, nMax_Seq FROM SFIPF009K00R03_COMMON_FUNC(
							recYoyakuDS.make_dt,
							'WIP502',
							'警告',
							cSeq_flg,
							nMax_Seq,
							vLmsg,
							cItaku_kaisha_cd,
							cTekiyost_ymd,
							cOld_koza_ten_cd,
							cOld_koza_ten_cifcd,
							cOld_koza_kamoku,
							cOld_koza_no,
							cNew_koza_ten_cd,
							cNew_koza_ten_cifcd,
							cNew_koza_kamoku,
							cNew_koza_no,
							cFilter_shubetu,
							cGyoumuDt,
							vMsg,
							vTmsg
						);
							IF nRet = pkconstant.fatal() THEN
								RETURN nRet;
							END IF;
						END IF;
						-- 新店番号
						nCount := 0;
						SELECT count(*)
						INTO STRICT nCount
						FROM MBUTEN
						WHERE itaku_kaisha_cd = cItaku_kaisha_cd
						AND buten_cd = cNew_koza_ten_cd;
						IF nCount = 0 THEN
							-- 出力フラグに'A'(追加)を設定
							cFlg := 'A';
							-- 口座情報更新リストワーク用メッセージ
							vMsg := '部店マスタが存在しません。登録してください。';
							-- ログ用メッセージ
							vLmsg := '＜新店番号:' || cNew_koza_ten_cd || '＞';
							-- メッセージ通知用メッセージ
							vTmsg := '部店マスタが存在しません。登録してください。' ||
									 '＜新店番号:' || cNew_koza_ten_cd || '＞';
							-- エラー処理
							SELECT io_cSeq_flg, io_nMax_Seq INTO cSeq_flg, nMax_Seq FROM SFIPF009K00R03_COMMON_FUNC(
							recYoyakuDS.make_dt,
							'WIP502',
							'警告',
							cSeq_flg,
							nMax_Seq,
							vLmsg,
							cItaku_kaisha_cd,
							cTekiyost_ymd,
							cOld_koza_ten_cd,
							cOld_koza_ten_cifcd,
							cOld_koza_kamoku,
							cOld_koza_no,
							cNew_koza_ten_cd,
							cNew_koza_ten_cifcd,
							cNew_koza_kamoku,
							cNew_koza_no,
							cFilter_shubetu,
							cGyoumuDt,
							vMsg,
							vTmsg
						);
							IF nRet = pkconstant.fatal() THEN
								RETURN nRet;
							END IF;
						END IF;
						-- 同一キーが店ＣＩＦ予約に存在する場合
						nCount := 0;
						SELECT count(*)
						INTO STRICT nCount
						FROM tencif_yoyaku
						WHERE itaku_kaisha_cd = cItaku_kaisha_cd
						AND tekiyost_ymd = cTekiyost_ymd
						AND old_koza_ten_cd = cOld_koza_ten_cd
						AND trim(both old_koza_ten_cifcd) = cOld_koza_ten_cifcd
						AND old_koza_kamoku = cOld_koza_kamoku
						AND old_koza_no = SUBSTR(cOld_koza_no, 2, 7);
						IF nCount = 0 THEN
							-- 出力フラグに'A'(追加)を設定
							cFlg := 'A';
						ELSE
							-- 出力フラグに'U'(更新)を設定
							cFlg := 'U';
							-- フィルタ種別を問わず、全ての項目が同一の場合
							-- 重複データはエラーとしない
							nCount2 := 0;
							SELECT count(*)
							INTO STRICT nCount2
							FROM tencif_yoyaku
							WHERE itaku_kaisha_cd = cItaku_kaisha_cd
							AND tekiyost_ymd = cTekiyost_ymd
							AND old_koza_ten_cd = cOld_koza_ten_cd
							AND trim(both old_koza_ten_cifcd) = cOld_koza_ten_cifcd
							AND old_koza_kamoku = cOld_koza_kamoku
							AND old_koza_no = SUBSTR(cOld_koza_no, 2, 7)
							AND new_koza_ten_cd = cNew_koza_ten_cd
							AND new_koza_ten_cifcd = cNew_koza_ten_cifcd
							AND new_koza_kamoku = cNew_koza_kamoku
							AND new_koza_no = SUBSTR(cNew_koza_no, 2, 7)
							AND filter_shubetu = cFilter_shubetu;
							-- 重複データでない場合
							IF nCount2 = 0 THEN
								cTencifFlg := '1';
							-- 重複データの場合
							ELSE
								cTencifFlg := '0';
							END IF;
							-- 重複チェックフラグが'1'の場合、エラー処理
							IF cTencifFlg = '1' THEN
								-- 口座情報更新リストワーク用メッセージ
								vMsg := '重複データは後のものを採用します。';
								-- ログ用メッセージ
								vLmsg := '＜フィルタ種別:' || cFilter_shubetu ||
										 ',照合キー:' || cOld_koza_ten_cd || ',' || cOld_koza_ten_cifcd ||
										 ',' || cOld_koza_kamoku || ',' || SUBSTR(cOld_koza_no, 2, 7) || '＞';
								-- メッセージ通知用メッセージ
								vTmsg := '重複データは後のものを採用します。' ||
										 '＜' || cFilter_shubetu || '、照合キー:' || cOld_koza_ten_cd || '、' || cOld_koza_ten_cifcd ||
										 '、' || cOld_koza_kamoku || '、' || SUBSTR(cOld_koza_no, 2, 7) || '＞';
								-- エラー処理
								SELECT io_cSeq_flg, io_nMax_Seq INTO cSeq_flg, nMax_Seq FROM SFIPF009K00R03_COMMON_FUNC(
							recYoyakuDS.make_dt,
							'WIP501',
							'警告',
							cSeq_flg,
							nMax_Seq,
							vLmsg,
							cItaku_kaisha_cd,
							cTekiyost_ymd,
							cOld_koza_ten_cd,
							cOld_koza_ten_cifcd,
							cOld_koza_kamoku,
							cOld_koza_no,
							cNew_koza_ten_cd,
							cNew_koza_ten_cifcd,
							cNew_koza_kamoku,
							cNew_koza_no,
							cFilter_shubetu,
							cGyoumuDt,
							vMsg,
							vTmsg
						);
								IF nRet = pkconstant.fatal() THEN
									RETURN nRet;
								END IF;
							END IF;
						END IF;
						-- 出力フラグが'A'の場合、追加
						IF cFlg = 'A' THEN
							INSERT INTO tencif_yoyaku(
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
								make_dt,
								kousin_id,
								sakusei_id
							)
							VALUES (
								l_cItaku_kaisha_cd,
								l_cTekiyost_ymd,
								l_cOld_koza_ten_cd,
								l_cOld_koza_ten_cifcd,
								l_cOld_koza_kamoku,
								SUBSTR(l_cOld_koza_no, 2, 7),
								l_cNew_koza_ten_cd,
								l_cNew_koza_ten_cifcd,
								l_cNew_koza_kamoku,
								SUBSTR(l_cNew_koza_no, 2, 7),
								l_cFilter_shubetu,
								l_cGyoumuDt,
								recYoyakuDS.make_dt,
								'BATCH',
								'BATCH'
							);
						-- 出力フラグが'U'の場合、更新
						ELSIF cFlg = 'U' THEN
							UPDATE tencif_yoyaku
							SET new_koza_ten_cd = cNew_koza_ten_cd,
								new_koza_ten_cifcd = cNew_koza_ten_cifcd,
								new_koza_kamoku = cNew_koza_kamoku,
								new_koza_no = SUBSTR(cNew_koza_no, 2, 7),
								filter_shubetu = cFilter_shubetu,
								data_recv_ymd = cGyoumuDt,
								make_dt = recYoyakuDS.make_dt,
								kousin_dt = CURRENT_TIMESTAMP,
								kousin_id = 'BATCH'
							WHERE itaku_kaisha_cd = cItaku_kaisha_cd
							ANd tekiyost_ymd = cTekiyost_ymd
							AND old_koza_ten_cd = cOld_koza_ten_cd
							AND trim(both old_koza_ten_cifcd) = cOld_koza_ten_cifcd
							AND old_koza_kamoku = cOld_koza_kamoku
							AND old_koza_no = SUBSTR(cOld_koza_no, 2, 7);
						END IF;
					END IF;
				END IF;
			END IF;
		END IF;
	END LOOP;
	RETURN pkconstant.success();
--==============================================================================
--                  エラー処理                                                  
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		-- ログ出力
		CALL pkLog.fatal(
			'ECM701', 'IPF009K00R03', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')'
		);
		RETURN pkconstant.fatal();
--		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf009k00r03 () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipf009k00r03_common_func ( l_inMake_dt CHAR,			-- 作成日
 l_inMsgId CHAR,			-- メッセージＩＤ
 l_inLevel CHAR,				-- 通知レベル
 INOUT io_cSeq_flg char(1),
 INOUT io_nMax_Seq numeric,
 IN l_vLmsg varchar(200),
 IN l_cItaku_kaisha_cd char(4),
 IN l_cTekiyost_ymd char(8),
 IN l_cOld_koza_ten_cd char(4),
 IN l_cOld_koza_ten_cifcd char(8),
 IN l_cOld_koza_kamoku char(1),
 IN l_cOld_koza_no char(8),
 IN l_cNew_koza_ten_cd char(4),
 IN l_cNew_koza_ten_cifcd char(8),
 IN l_cNew_koza_kamoku char(1),
 IN l_cNew_koza_no char(8),
 IN l_cFilter_shubetu char(2),
 IN l_cGyoumuDt char(8),
 IN l_vMsg varchar(200),
 IN l_vTmsg varchar(200)
 ) RETURNS RECORD AS $body$
DECLARE
	nRet numeric;
BEGIN
	-- 対象レコードが変わる毎にSEQ_NOをインクリメント
	IF io_cSeq_flg = '0' THEN
		-- 口座情報更新リストワークの連番カウント
		io_nMax_Seq := io_nMax_Seq + 1;
	END IF;
	-- ログ出力
	CALL pkLog.error(l_inMsgId, 'IPF009K00R03', l_vLmsg);
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
		l_cItaku_kaisha_cd,
		'IPF30000911',
		io_nMax_Seq,
		l_cTekiyost_ymd,
		l_cOld_koza_ten_cd,
		l_cOld_koza_ten_cifcd,
		l_cOld_koza_kamoku,
		SUBSTR(l_cOld_koza_no, 2, 7),
		l_cNew_koza_ten_cd,
		l_cNew_koza_ten_cifcd,
		l_cNew_koza_kamoku,
		SUBSTR(l_cNew_koza_no, 2, 7),
		' ',
		' ',
		l_cFilter_shubetu,
		l_cGyoumuDt,
		'1',
		l_inMsgId,
		l_vMsg,
		CURRENT_TIMESTAMP,
		'BATCH',
		CURRENT_TIMESTAMP,
		'BATCH'
	);
	--メッセージ通知テーブルへ書き込み
	nRet := SfIpMsgTsuchiUpdate(l_cItaku_kaisha_cd, 'CAPS', l_inLevel, '1', '0', l_vTmsg, 'BATCH', 'BATCH');
	IF nRet != 0 THEN
		CALL pkLog.fatal('ECM701', 'IPF009K00R03', 'メッセージ通知登録エラー');
		RETURN;
	END IF;
	-- シーケンス用フラグに'1'を設定
	io_cSeq_flg := '1';
	RETURN;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf009k00r03_common_func ( l_inMake_dt CHAR, l_inMsgId CHAR, l_inLevel CHAR  ) FROM PUBLIC;
