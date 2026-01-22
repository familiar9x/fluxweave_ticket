




CREATE OR REPLACE FUNCTION sfipf013k01r01 ( l_inShoriId TEXT,						-- 処理モード
 l_inUserId text						-- 作成ユーザＩＤ
 ) RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * ①処理モード='1'(発行代り金）、='2'（元利払・期中手数料）により処理する。
-- * ②勘定系代り金IF、勘定系元利金・手数料IFから勘定系リアル送信IFを作成する。
-- *   同時に勘定系リアル送信保存ＩＦを作成する。
-- * ③完了後、勘定計系発行代り金IFの送受信ステータスを'1'(送信済)にする。
-- *
-- * @author 小林　弘幸
-- * @version $Revision: 1.8 $
-- * 
-- * @return INTEGER
-- *                0:正常終了、データ無し
-- *                1:予期したエラー
-- *               99:予期せぬエラー
-- 
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	iRet				integer;									-- リターン値
	nTempRet			numeric;									-- 一時リターン値(PROCEDURE用)
	nSqlCode			numeric;									-- リターン値(エラーリスト用)
	nCount				numeric;										-- レコード数
	nMax_data_seq		numeric;										-- シーケンス番号
	cKnj_uke_tuban		TEXT;											-- 受付通番（勘定系）
	cKnj_chukei_tuban	TEXT;											-- 中継取引通番(勘定系)
	cGyoumuDt			ssystem_management.gyomu_ymd%type;			-- 業務日付格納用
	cKnj4tr3			char(100);									-- ４次TR補完部３
	cKnj4tr5			char(82);									-- ４次TR補完部５
	cSeisa				char(3);									-- 精査ビット情報
	cTorikeshi			char(3);									-- 取消ビット情報
	cGenhuri_h			char(1);									-- 現振コード(本店用)
	cGenhuri			char(1);									-- 現振コード
	cTekiyou			char(4);									-- 摘要コード
	cKnj_kamoku			char(4);									-- 勘定科目コード
	vSqlErrM			varchar(200);								-- エラーメッセージ
	vMsgLog				varchar(300);								-- ログ出力用メッセージ
	vMsgTsuchi			varchar(300);								-- メッセージ通知用メッセージ
	vTableName			varchar(300);								-- テーブル名称
	vMsg_Err_list		varchar(300);								-- エラーリスト用メッセージ
--==============================================================================
--                  カーソル定義                                                
--==============================================================================
	-- 勘定系発行代金IFからデータを抽出する
	curHakko CURSOR FOR
		SELECT itaku_kaisha_cd,
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
			   knj_chukei_tsuban,
			   knj_chukei_tsuban_zenkai,
			   knj_torikeshi_flg
		FROM knjhakkouif
		WHERE sr_stat = '0'
		AND kousin_id = l_inUserId
		ORDER BY knj_uke_tsuban_naibu;
	-- 勘定系元利金・手数料IFからデータを抽出する
	curTesu CURSOR FOR
		SELECT itaku_kaisha_cd,
			   knj_uke_tsuban_naibu,
			   knj_azuke_no,
			   knj_shori_ymd,
			   knj_shori_kbn,
			   knj_ten_no,
			   knj_kamoku,
			   knj_kouza_no,
			   knj_kingaku,
			   knj_inout_kbn,
			   knj_chukeimsgid,
			   knj_chukei_tsuban,
			   knj_chukei_tsuban_zenkai,
			   knj_torikeshi_flg
		FROM knjganrikichuif
		WHERE sr_stat = '0'
		AND kousin_id = l_inUserId
		ORDER BY knj_uke_tsuban_naibu;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 業務日付を取得
	cGyoumuDt := pkDate.getGyomuYmd();
	-- 入力パラメータのチェック（処理モード）
	IF trim(both l_inShoriId) != '1' AND trim(both l_inShoriId) != '2' THEN
		-- ログ出力
		CALL pkLog.error(
			'ECM501',
			'IPF013K01R01',
			'パラメータエラー＜処理モード:' || l_inShoriId || '＞'
		);
		RETURN pkconstant.error();
	END IF;
	-- 入力パラメータのチェック（ユーザＩＤ）
	IF coalesce(trim(both l_inUserId)::text, '') = '' OR trim(both l_inUserId) = '' THEN
		-- ログ出力
		CALL pkLog.error(
			'ECM501',
			'IPF013K01R01',
			'パラメータエラー＜ユーザＩＤ:' || l_inUserId || '＞'
		);
		RETURN pkconstant.error();
	END IF;
	-- 作成日の最終データ内連番を取得
	nCount := 0;
	SELECT count(*)
	INTO STRICT nCount
	FROM knjrealsndif
	WHERE make_dt = TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDD');
	IF nCount != 0 THEN
		SELECT MAX(data_seq)
		INTO STRICT nMax_data_seq
		FROM knjrealsndif
		WHERE make_dt = TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDD');
	ELSE
		nMax_data_seq := 0;
	END IF;
	-- 発行代り金対応の処理
	IF l_inShoriId = '1' THEN
		-- 勘定系発行代金IFからデータを抽出し、勘定系リアルIFを作成
		nCount := 0;
		SELECT count(*)
		INTO STRICT nCount
		FROM knjhakkouif
		WHERE sr_stat = '0'
		AND kousin_id = l_inUserId;
		-- データが0件の場合、リターン(リターン値=0)
		IF nCount = 0 THEN
			RETURN pkconstant.success();
		ELSE
			-- 接続ステータスを送信中にする
			UPDATE knjsetuzokustatus
			SET knjif_send = '2',
				kousin_dt = CURRENT_TIMESTAMP,
				kousin_id = 'BATCH';
			-- COMMIT; -- Removed: Cannot COMMIT in function
		END IF;
		FOR recHakko IN curHakko LOOP
			-- 受付通番を受付通番取得関数で取得
			CALL SPIPFGETUKENO('2', cKnj_uke_tuban, iRet);
			IF iRet != 0 THEN
				CALL pkLog.fatal('ECM701', 'IPF013K01R01', '受付通番取得エラー');
				RETURN iRet;
			END IF;
			-- 中継取引通番を中継取引通番取得関数で取得
			CALL SPIPFGETCHUNO(cGyoumuDt, cKnj_chukei_tuban, iRet);
			IF iRet != 0 THEN
				CALL pkLog.fatal('ECM701', 'IPF013K01R01', '中継取引通番取得エラー');
				RETURN iRet;
			END IF;
			-- MAXデータ内連番を＋１
			nMax_data_seq := nMax_data_seq + 1;
			-- 内部関数をCALLする。
			CALL SFIPF013K01R01_COMMON_PROC(
				recHakko.itaku_kaisha_cd,
				(cKnj_uke_tuban)::numeric ,
				recHakko.knj_azuke_no,
				recHakko.knj_shori_ymd,
				recHakko.knj_shori_kbn,
				recHakko.knj_ten_no,
				recHakko.knj_kamoku,
				recHakko.knj_kouza_no,
				trim(both TO_CHAR(recHakko.knj_hrkm_kngk, '000000000000009')),
				recHakko.knj_inout_kbn,
				recHakko.knj_chukeimsgid,
				recHakko.knj_chukei_tsuban,
				recHakko.knj_chukei_tsuban_zenkai,
				recHakko.knj_torikeshi_flg,
				cGyoumuDt,
				cKnj_chukei_tuban,
				nMax_data_seq,
				nTempRet
			);
			-- 勘定系発行代金IFの送受信ステータスを送信済に更新
			UPDATE knjhakkouif
			SET knj_uke_tsuban = (cKnj_uke_tuban)::numeric ,
				knj_chukei_tsuban = (cKnj_chukei_tuban)::numeric ,
				sr_stat = '1',
				kousin_dt = CURRENT_TIMESTAMP,
				kousin_id = 'BATCH'
			WHERE itaku_kaisha_cd = recHakko.itaku_kaisha_cd
			AND   knj_uke_tsuban_naibu = recHakko.knj_uke_tsuban_naibu;
		END LOOP;
	ELSIF l_inShoriId = '2' THEN
		-- 勘定系元利金・手数料IFからデータを抽出し、勘定系リアルIFを作成
		-- データが0件の場合、リターン(リターン値=0)
		nCount := 0;
		SELECT count(*)
		INTO STRICT nCount
		FROM knjganrikichuif
		WHERE sr_stat = '0'
		AND kousin_id = l_inUserId;
		-- データが0件の場合、リターン(リターン値=0)
		IF nCount = 0 THEN
			RETURN pkconstant.success();
		ELSE
			-- 接続ステータスを送信中にする
			UPDATE knjsetuzokustatus
			SET knjif_send = '2',
				kousin_dt = CURRENT_TIMESTAMP,
				kousin_id = 'BATCH';
			-- COMMIT; -- Removed: Cannot COMMIT in function
		END IF;
		FOR recTesu IN curTesu LOOP
			-- 受付通番を受付通番取得関数で取得
			CALL SPIPFGETUKENO('2', cKnj_uke_tuban, iRet);
			IF iRet != 0 THEN
				CALL pkLog.fatal('ECM701', 'IPF013K01R01', '受付通番取得エラー');
				RETURN iRet;
			END IF;
			-- 中継取引通番を中継取引通番取得関数で取得
			CALL SPIPFGETCHUNO(cGyoumuDt, cKnj_chukei_tuban, iRet);
			IF iRet != 0 THEN
				CALL pkLog.fatal('ECM701', 'IPF013K01R01', '中継取引通番取得エラー');
				RETURN iRet;
			END IF;
			-- MAXデータ内連番を＋１
			nMax_data_seq := nMax_data_seq + 1;
			-- 内部関数をCALLする。
			CALL SFIPF013K01R01_COMMON_PROC(
				recTesu.itaku_kaisha_cd,
				(cKnj_uke_tuban)::numeric ,
				recTesu.knj_azuke_no,
				recTesu.knj_shori_ymd,
				recTesu.knj_shori_kbn,
				recTesu.knj_ten_no,
				recTesu.knj_kamoku,
				recTesu.knj_kouza_no,
				trim(both TO_CHAR(recTesu.knj_kingaku, '000000000000009')),
				recTesu.knj_inout_kbn,
				recTesu.knj_chukeimsgid,
				recTesu.knj_chukei_tsuban,
				recTesu.knj_chukei_tsuban_zenkai,
				recTesu.knj_torikeshi_flg,
				cGyoumuDt,
				cKnj_chukei_tuban,
				nMax_data_seq,
				nTempRet
			);
			-- 勘定系元利金・手数料IFの送受信ステータスを送信済に更新
			UPDATE knjganrikichuif
			SET knj_uke_tsuban = (cKnj_uke_tuban)::numeric ,
				knj_chukei_tsuban = (cKnj_chukei_tuban)::numeric ,
				sr_stat = '1',
				kousin_dt = CURRENT_TIMESTAMP,
				kousin_id = 'BATCH'
			WHERE itaku_kaisha_cd = recTesu.itaku_kaisha_cd
			AND knj_uke_tsuban_naibu = recTesu.knj_uke_tsuban_naibu;
		END LOOP;
	END IF;
	-- 接続ステータスを"送信可"にする
	UPDATE knjsetuzokustatus
	SET knjif_send = '1',
		kousin_dt = CURRENT_TIMESTAMP,
		kousin_id = 'BATCH';
	RETURN pkconstant.success();
--==============================================================================
--                  エラー処理                                                  
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		-- ログ出力
		CALL pkLog.fatal(
			'ECM701',
			'IPF013K01R01',
			'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')'
		);
		RETURN pkconstant.fatal();
--		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf013k01r01 ( l_inShoriId TEXT, l_inUserId text ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfipf013k01r01_common_proc ( 
	l_inKnj_itaku_kaisha_cd TEXT,		-- 委託会社コード
	l_inKnj_uke_tsuban numeric,		-- 受付通番
	l_inKnj_azuke_tsuban numeric,		-- 預入番号
	l_inKnj_shori_ymd TEXT,		-- 処理日
	l_inKnj_shori_kbn TEXT,		-- 処理区分（勘定系）
	l_inKnj_ten TEXT,		-- 店番号（勘定系）
	l_inKnj_kamoku TEXT,		-- 科目（勘定系）
	l_inKnj_kouza TEXT,		-- 口座番号（勘定系）
	l_inKnj_haraikomi TEXT,		-- 払込金額（勘定系）
	l_inKnj_inout_kbn TEXT,		-- 入出金区分（勘定系）
	l_inKnj_chukeimsgid TEXT,		-- 中継メッセージID
	l_inKnj_chukei_tsuban numeric,		-- 中継取引通番(勘定系）
	l_inKnj_chukei_tsuban_zenkai numeric,		-- 中継取引通番(前回)
	l_inKnj_torikeshi_fl TEXT,		-- 取消データ作成フラグ
	l_inCGyoumuDt char(8),		-- 業務日付
	l_inCKnj_chukei_tuban char(4),		-- 中継取引通番
	l_inNMax_data_seq numeric,		-- シーケンス番号
	l_outRet OUT numeric 		-- リターンコード
 ) AS $body$
DECLARE
	nRet		numeric;							-- リターン値
	cGyoumuDt		char(8);						-- 業務日付格納用
	cKnj4tr3		char(100);						-- ４次TR補完部３
	cKnj4tr5		char(82);						-- ４次TR補完部５
	cSeisa			char(3);						-- 精査ビット情報
	cTorikeshi		char(3);						-- 取消ビット情報
	cGenhuri_h		char(1);						-- 現振コード(本店用)
	cGenhuri		char(1);						-- 現振コード
	cTekiyou		char(4);						-- 摘要コード
	cKnj_kamoku		char(4);						-- 勘定科目コード
	cKnj_chukei_tuban	char(4);					-- 中継取引通番
	nMax_data_seq	numeric;						-- シーケンス番号
BEGIN
	-- Copy input parameters to local variables
	cGyoumuDt := l_inCGyoumuDt;
	cKnj_chukei_tuban := l_inCKnj_chukei_tuban;
	nMax_data_seq := l_inNMax_data_seq;
	-- 変数初期化
	cKnj4tr3 := '';
	cKnj4tr5 := '';
	cSeisa := '';
	cTorikeshi := '';
	cGenhuri := '';
	cGenhuri_h := '';
	cTekiyou := '';
	cKnj_kamoku := '';
	-- ４次TR補完部３を作成
	cKnj4tr3 := '0' ||
				'00000' ||
				'              ' ||
				'              ' ||
				'6656' ||
				'0000' ||
				'S050' ||
				'0020' ||
				'C' ||
				'03' ||
				cGyoumuDt ||
				TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDD') ||
				TO_CHAR(CURRENT_TIMESTAMP, 'HH24MISS') || '000' ||
				l_inKnj_ten ||
				l_inKnj_kamoku ||
				l_inKnj_kouza ||
				'0789' ||
				'0000';
	-- ４次TR補完部５を作成
	cKnj4tr5 := '0000' ||
				l_inKnj_ten ||
				'50' ||
				'    ' ||
				'0000000' ||
				'        ' ||
				' ' ||
				' ' ||
				'0000000000' ||
				'                                         ';
	-- 精査ビットを設定
	IF l_inKnj_kamoku = '21'
	AND (l_inKnj_shori_kbn = '2' OR l_inKnj_shori_kbn = '3') THEN
		cSeisa := '128';
	ELSE
		cSeisa := '000';
	END IF;
	-- 取消ビット情報を設定
	IF l_inKnj_torikeshi_fl = '1' THEN
		cTorikeshi := '002';
	ELSE
		cTorikeshi := '000';
	END IF;
	-- 現振コードを設定
	IF l_inKnj_shori_kbn = '1' THEN
		cGenhuri := '0';
		cGenhuri_h := '6';
	ELSE
		cGenhuri := '6';
		cGenhuri_h := '0';
	END IF;
	-- 摘要コードを設定
	IF l_inKnj_shori_kbn = '1' THEN
		cTekiyou := '1281';
	ELSIF l_inKnj_shori_kbn = '2'	THEN
		cTekiyou := '1282';
	ELSIF l_inKnj_shori_kbn = '3'	THEN
		cTekiyou := '1283';
	END IF;
	-- 勘定科目コードを設定
	IF l_inKnj_kamoku = '21' THEN
		cKnj_kamoku := '0201';
	ELSIF l_inKnj_kamoku = '22' THEN
		cKnj_kamoku := '0202';
	ELSIF l_inKnj_kamoku = '29' THEN
		cKnj_kamoku := '0205';
	END IF;
	-- 勘定系リアル送信IFへ追加
	INSERT INTO knjrealsndif(
		data_id,
		make_dt,
		data_seq,
		knj4tr_uke_tsuban,
		knj4tr3,
		knj4tr5,
		m1_ten_no,
		m1_kamoku,
		m1_koza_no,
		m1_azukeire_no,
		m1_torikeshi,
		m1_kanjyo_ymd,
		m1_seisa,
		knj_yo_kamoku,
		knj_yo_torikeshi,
		knj_yo_genhuri,
		knj_yo_tekiyou,
		knj_yo_kingaku,
		daiukebarai_aitekamoku,
		chukei_chukei_tsuban,
		chukei_chukei_tsuban_zenkai,
		knj_hon_torikeshi,
		knj_hon_genhuri,
		knj_hon_tekiyou,
		knj_hon_kingaku,
		knj_hon_aitekamoku,
		m1_ki_kamoku,
		m1_ki_azukeire_no,
		m1_ki_torikeshi,
		m1_ki_kanjyo_ymd,
		m1_ki_seisa,
		knj_ki_torikeshi,
		knj_ki_genhuri,
		knj_ki_tekiyou,
		knj_ki_kingaku,
		daiukebarai_ki_aiteten_no,
		daiukebarai_ki_aitekamoku,
		daiukebarai_ki_aitekoza_no,
		system_chukeimsgid
	)
	VALUES (
		'14002',
		TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDD'),
		nMax_data_seq,
		trim(both TO_CHAR(l_inKnj_uke_tsuban, '0000000009')),
		cKnj4tr3,
		cKnj4tr5,
		l_inKnj_ten,
		l_inKnj_kamoku,
		l_inKnj_kouza,
		trim(both TO_CHAR(l_inKnj_azuke_tsuban, '00000009')),
		cTorikeshi,
		l_inKnj_shori_ymd,
		cSeisa,
		cKnj_kamoku,
		cTorikeshi,
		cGenhuri,
		cTekiyou,
		l_inKnj_haraikomi,
		l_inKnj_kamoku,
		cKnj_chukei_tuban,
		trim(both TO_CHAR(l_inKnj_chukei_tsuban_zenkai, '0009')),
		cTorikeshi,
		cGenhuri_h,
		cTekiyou,
		l_inKnj_haraikomi,
		cKnj_kamoku,
		l_inKnj_kamoku,
		trim(both TO_CHAR(l_inKnj_azuke_tsuban, '00000009')),
		cTorikeshi,
		l_inKnj_shori_ymd,
		cSeisa,
		cTorikeshi,
		cGenhuri,
		cTekiyou,
		l_inKnj_haraikomi,
		l_inKnj_ten,
		l_inKnj_kamoku,
		l_inKnj_kouza,
		l_inKnj_chukeimsgid
	);
	-- 勘定系リアル送信保存IFへ追加
	INSERT INTO knjrealsndsaveif(
		data_id,
		make_dt,
		data_seq,
		knj4tr_uke_tsuban,
		knj4tr3,
		knj4tr5,
		m1_ten_no,
		m1_kamoku,
		m1_koza_no,
		m1_azukeire_no,
		m1_torikeshi,
		m1_kanjyo_ymd,
		m1_seisa,
		knj_yo_kamoku,
		knj_yo_torikeshi,
		knj_yo_genhuri,
		knj_yo_tekiyou,
		knj_yo_kingaku,
		daiukebarai_aitekamoku,
		chukei_chukei_tsuban,
		chukei_chukei_tsuban_zenkai,
		knj_hon_torikeshi,
		knj_hon_genhuri,
		knj_hon_tekiyou,
		knj_hon_kingaku,
		knj_hon_aitekamoku,
		m1_ki_kamoku,
		m1_ki_azukeire_no,
		m1_ki_torikeshi,
		m1_ki_kanjyo_ymd,
		m1_ki_seisa,
		knj_ki_torikeshi,
		knj_ki_genhuri,
		knj_ki_tekiyou,
		knj_ki_kingaku,
		daiukebarai_ki_aiteten_no,
		daiukebarai_ki_aitekamoku,
		daiukebarai_ki_aitekoza_no,
		system_chukeimsgid
	)
	VALUES (
		'14002',
		TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDD'),
		nMax_data_seq,
		trim(both TO_CHAR(l_inKnj_uke_tsuban, '0000000009')),
		cKnj4tr3,
		cKnj4tr5,
		l_inKnj_ten,
		l_inKnj_kamoku,
		l_inKnj_kouza,
		trim(both TO_CHAR(l_inKnj_azuke_tsuban, '00000009')),
		cTorikeshi,
		l_inKnj_shori_ymd,
		cSeisa,
		cKnj_kamoku,
		cTorikeshi,
		cGenhuri,
		cTekiyou,
		l_inKnj_haraikomi,
		l_inKnj_kamoku,
		cKnj_chukei_tuban,
		trim(both TO_CHAR(l_inKnj_chukei_tsuban_zenkai, '0009')),
		cTorikeshi,
		cGenhuri_h,
		cTekiyou,
		l_inKnj_haraikomi,
		cKnj_kamoku,
		l_inKnj_kamoku,
		trim(both TO_CHAR(l_inKnj_azuke_tsuban, '00000009')),
		cTorikeshi,
		l_inKnj_shori_ymd,
		cSeisa,
		cTorikeshi,
		cGenhuri,
		cTekiyou,
		l_inKnj_haraikomi,
		l_inKnj_ten,
		l_inKnj_kamoku,
		l_inKnj_kouza,
		l_inKnj_chukeimsgid
	);
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfipf013k01r01_common_proc ( l_inKnj_itaku_kaisha_cd TEXT, l_inKnj_uke_tsuban numeric, l_inKnj_azuke_tsuban numeric, l_inKnj_shori_ymd TEXT, l_inKnj_shori_kbn TEXT, l_inKnj_ten TEXT, l_inKnj_kamoku TEXT, l_inKnj_kouza TEXT, l_inKnj_haraikomi TEXT, l_inKnj_inout_kbn TEXT, l_inKnj_chukeimsgid TEXT, l_inKnj_chukei_tsuban numeric, l_inKnj_chukei_tsuban_zenkai numeric, l_inKnj_torikeshi_fl TEXT, l_outRet OUT numeric  ) FROM PUBLIC;
