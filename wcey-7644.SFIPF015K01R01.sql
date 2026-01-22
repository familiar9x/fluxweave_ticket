




CREATE OR REPLACE FUNCTION sfipf015k01r01 () RETURNS integer AS $body$
DECLARE

ora2pg_rowcount int;
--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * ①期中手数料のデータを請求書単位に作成する。
-- *   そのデータを基に振替日のｎｎ営業日前の夜間に口座振替データを作成する。
-- * ②勘定系元利金・手数料IFを作成後、JP1起動により、DBIFリアル送信PGが実行され、
-- *   勘定系リアル送信IFを作成する。
-- *
-- * @author 小林　弘幸
-- * @version $Revision: 1.10 $
-- * $Id: SFIPF015K01R01.sql,v 1.10 2005/11/04 10:12:04 kubo Exp $
-- * @return INTEGER
-- *                0:正常終了、データ無し
-- *                1:予期したエラー
-- *               99:予期せぬエラー
-- 
--==============================================================================
--                  カーソル定義                                                
--==============================================================================
	-- 銘柄_基本.受託区分='1'（代表受託）・'3'（財務代理人）・'4'（非受託）
	-- である銘柄を抽出する。
	-- 自行情報よりＮＮ営業日等を取得する。
	curTaisyo CURSOR FOR
		SELECT
			m.itaku_kaisha_cd itaku_kaisha_cd,
			m.hkt_cd hkt_cd,
			s.tesuryo_eb_make_dd tesuryo_eb_make_dd,
			s.tesuryo_eb_send_dd tesuryo_eb_send_dd,
			s.own_financial_securities_kbn financial_kbn,
			s.own_bank_cd bank_cd
		FROM
			mgr_kihon_view m,
			sown_info s
		WHERE (m.jtk_kbn = '1' OR m.jtk_kbn = '3' OR m.jtk_kbn = '4')
		AND m.itaku_kaisha_cd = s.kaiin_id
		AND m.hkt_cd IN (SELECT hkt_cd FROM knj_tesuryo_wk)
		GROUP BY m.hkt_cd,
				 m.itaku_kaisha_cd,
				 s.tesuryo_eb_make_dd,
				 s.tesuryo_eb_send_dd,
				 s.own_financial_securities_kbn,
				 s.own_bank_cd
		ORDER BY m.hkt_cd;
	-- 手数料計算結果ＷＫから対象データを抽出する
	curTesu1 CURSOR(wk_hkt_cd  text,
					wk_tesu_cd1  text,
					wk_tesu_cd2  text) FOR
		SELECT itaku_kaisha_cd,
			   mgr_cd,
			   tesu_shurui_cd,
			   chokyu_kjt,
			   hkt_cd
		FROM knj_tesuryo_wk
		WHERE hkt_cd = wk_hkt_cd
		AND (
			tesu_shurui_cd = wk_tesu_cd1
		OR  tesu_shurui_cd = wk_tesu_cd2
			)
		GROUP BY hkt_cd,
				 tesu_shurui_cd,
				 itaku_kaisha_cd,
				 mgr_cd,
				 chokyu_kjt
		ORDER BY hkt_cd,
				 tesu_shurui_cd;
	-- 補正あり手数料を計算
	curHosei1 CURSOR(wk_hkt_cd  text,
					 wk_tesu_cd1  text,
					 wk_tesu_cd2  text) FOR
		SELECT SUM(all_tesu_kngk) all_tesu_kngk,
			   SUM(all_tesu_szei) all_tesu_szei,
			   SUM(hosei_all_tesu_kngk) hosei_all_tesu_kngk,
			   SUM(hosei_all_tesu_szei) hosei_all_tesu_szei
		FROM knj_tesuryo_wk t, mgr_kihon_view m
		WHERE t.hkt_cd = wk_hkt_cd
		AND (
			tesu_shurui_cd = wk_tesu_cd1
		OR  tesu_shurui_cd = wk_tesu_cd2
			)
		AND t.data_sakusei_kbn = '2'
		AND t.shori_kbn = '1'
		AND t.itaku_kaisha_cd = m.itaku_kaisha_cd
		AND t.mgr_cd = m.mgr_cd;
	-- 補正なし手数料を計算
	curHoseiNashi1 CURSOR(wk_hkt_cd  text,
						  wk_tesu_cd1  text,
						  wk_tesu_cd2  text) FOR
		SELECT SUM(all_tesu_kngk) all_tesu_kngk,
			   SUM(all_tesu_szei) all_tesu_szei
		FROM knj_tesuryo_wk t, mgr_kihon_view m
		WHERE t.hkt_cd = wk_hkt_cd
		AND (
			tesu_shurui_cd = wk_tesu_cd1
		OR  tesu_shurui_cd = wk_tesu_cd2
			)
		AND (t.data_sakusei_kbn != '2' OR t.shori_kbn != '1')
		AND t.itaku_kaisha_cd = m.itaku_kaisha_cd
		AND t.mgr_cd = m.mgr_cd;
	-- 銘柄_基本Viewと手数料計算結果テーブルから対象データを手数料計算結果WKに登録
	curTesu_wk CURSOR(wk_eb_make_dd text,
					  wk_gyoumudt text) FOR
		SELECT m.itaku_kaisha_cd,
			   m.mgr_cd,
			   t.tesu_shurui_cd,
			   t.chokyu_kjt,
			   t.all_tesu_kngk,
			   t.all_tesu_szei,
			   t.hosei_all_tesu_kngk,
			   t.hosei_all_tesu_szei,
			   m.hkt_cd,
			   t.data_sakusei_kbn,
			   t.shori_kbn
		FROM mgr_kihon_view m, tesuryo t
		WHERE t.chokyu_ymd = pkDate.getPlusDateBusiness(wk_gyoumudt, wk_eb_make_dd::integer)
		AND t.data_sakusei_kbn >= '1'
		AND t.tsuka_cd = 'JPY'
		AND t.koza_furi_kbn = '10'
		AND t.tesu_sashihiki_kbn = '2'
		AND (
			t.tesu_shurui_cd = '11' OR t.tesu_shurui_cd = '12' OR t.tesu_shurui_cd = '21'
		OR	t.tesu_shurui_cd = '22' OR t.tesu_shurui_cd = '41'
		)
		AND m.mgr_stat_kbn = '1'
		AND (m.jtk_kbn = '1' OR m.jtk_kbn = '3' OR m.jtk_kbn = '4')
		AND t.eb_make_ymd = '        '
		AND m.itaku_kaisha_cd = t.itaku_kaisha_cd
		AND m.mgr_cd = t.mgr_cd;
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	iRet					integer;								 -- リターン値
	nSqlCode				numeric;									 -- リターン値
	nCount					numeric;									 -- レコード数
	nCounter				numeric;									 -- ループカウンタ
	nZkingaku				numeric;									 -- 全体手数料額（税抜）(補正あり)
	nZshohizei				numeric;									 -- 全体消費税額(補正あり)
	nZHkingaku				numeric;									 -- 補正額_全体手数料額（税抜）(補正あり)
	nZHshohizei				numeric;									 -- 補正額_全体消費税額(補正あり)
	nZNkingaku				numeric;									 -- 全体手数料額（税抜）(補正なし)
	nZNshohizei				numeric;									 -- 全体消費税額(補正なし)
	nKingaku				numeric;									 -- 金額（勘定系）
	nShohizei				numeric;									 -- 消費税金額（勘定系）
	nErr_kingaku			numeric;									 -- エラーの場合の合計金額
	cKnj_tesuryo_kbn		knjganrikichuif.knj_tesuryo_kbn%type;	 -- 手数料区分
	cKamoku					knjganrikichuif.knj_kamoku%type;		 -- 科目（勘定系）
	cKoza_no				knjganrikichuif.knj_kouza_no%type;		 -- 口座番号（勘定系）
	cChukeimsgid			knjganrikichuif.knj_chukeimsgid%type;	 -- 中継メッセージID
	cKnj_shori_ymd			knjganrikichuif.knj_shori_ymd%type;		 -- 処理日
	cKoza_ten_cd			mhakkotai.koza_ten_cd%type;				 -- 口座店コード
	cHko_koza_kamoku_cd		mhakkotai.hko_kamoku_cd%type;			 -- 自動引落口座_口座科目コード
	cHko_koza_no			mhakkotai.hko_koza_no%type;				 -- 自動引落口座_口座番号
	cGyoumuDt				ssystem_management.gyomu_ymd%type;		 -- 業務日付格納用
	cTesu_eb_make_dd		sown_info.tesuryo_eb_make_dd%type;		 -- 元利払基金ＥＢ作成タイミング日数
	cErr_kamoku_cd			mhakkotai.hko_kamoku_cd%type;			 -- エラーの場合の口座科目コード
	cTesu_cd1				tesuryo.tesu_shurui_cd%type;			 -- 検索条件用手数料種類コード１
	cTesu_cd2				tesuryo.tesu_shurui_cd%type;			 -- 検索条件用手数料種類コード２
	cKnj_uke_tsuban			char(10);								 -- 受付通番（勘定系）
	vSqlErrM				varchar(200);							 -- エラーメッセージ
	vMsgLog					varchar(300);							 -- ログ出力用メッセージ
	vMsgTsuchi				varchar(300);							 -- メッセージ通知用メッセージ
	vTableName				varchar(300);							 -- テーブル名称
	vMsg_Err_list			varchar(300);							 -- エラーリスト用メッセージ
	vSql					varchar(1000);							 -- ＳＱＬ格納用
	recTesu					RECORD;						 -- 手数料計算結果ＷＫ用レコード変数
	recTesu_wk				RECORD;						 -- 手数料計算結果ＷＫ作成用レコード変数
	recHosei				RECORD;						 -- 補正あり手数料用レコード変数
	recHoseiNasi			RECORD;					 -- 補正なし手数料用レコード変数
	cCode_rnm				scode.code_rnm%type;					 -- 手数料区分(勘定系）の略称
	cFlg					char(1);								 -- 該当データ存在フラグ
	cErr_Flg_Kingaku		char(1);								 -- エラーフラグ(金額用)
	cErr_Flg_Kamoku			char(1);								 -- エラーフラグ(科目コード用)
	cErr_Flg_buten			char(1);								 -- エラーフラグ(部店コード用)
	cErr_Flg_Koza			char(1);
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 業務日付を取得
	cGyoumuDt := pkDate.getGyomuYmd();
	-- 手数料計算結果ＷＫを削除
	nCount := 0;
	SELECT count(*)
	INTO STRICT nCount
	FROM knj_tesuryo_wk;
	IF nCount != 0 THEN
		DELETE FROM knj_tesuryo_wk;
	END IF;
	-- 銘柄_基本Viewと手数料計算結果テーブルから対象データを手数料計算結果WKに登録
	-- 手数料ＥＢ作成タイミング日数を取得
	SELECT tesuryo_eb_make_dd
	INTO STRICT cTesu_eb_make_dd
	FROM sown_info;
	OPEN curTesu_wk(cTesu_eb_make_dd, cGyoumuDt);
	LOOP
		FETCH curTesu_wk INTO recTesu_wk;
		EXIT WHEN NOT FOUND;/* apply on curTesu_wk */
		INSERT INTO knj_tesuryo_wk(
			itaku_kaisha_cd,
			mgr_cd,
			tesu_shurui_cd,
			chokyu_kjt,
			all_tesu_kngk,
			all_tesu_szei,
			hosei_all_tesu_kngk,
			hosei_all_tesu_szei,
			hkt_cd,
			data_sakusei_kbn,
			shori_kbn
		)
		VALUES (
			recTesu_wk.itaku_kaisha_cd,
			recTesu_wk.mgr_cd,
			recTesu_wk.tesu_shurui_cd,
			recTesu_wk.chokyu_kjt,
			recTesu_wk.all_tesu_kngk,
			recTesu_wk.all_tesu_szei,
			recTesu_wk.hosei_all_tesu_kngk,
			recTesu_wk.hosei_all_tesu_szei,
			recTesu_wk.hkt_cd,
			recTesu_wk.data_sakusei_kbn,
			recTesu_wk.shori_kbn
		);
	END LOOP;
	-- 該当データがない場合、正常リターン
	GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;
IF ora2pg_rowcount = 0 THEN
		-- CLOSE curTesu_wk;
		RETURN pkconstant.success();
	END IF;
	-- CLOSE curTesu_wk;
	FOR recTaisyo IN curTaisyo LOOP
		-- 変数初期化
		iRet := 0;
		nSqlCode := 0;
		nKingaku := 0;
		nShohizei := 0;
		nZkingaku := 0;
		nZshohizei := 0;
		nZHkingaku := 0;
		nZHshohizei := 0;
		nZNkingaku := 0;
		nZNshohizei := 0;
		nErr_kingaku := 0;
		cFlg := '0';
		cKamoku := '';
		cKoza_no := '';
		cKoza_ten_cd := '';
		cChukeimsgid := '';
		cKnj_uke_tsuban := '';
		cKnj_shori_ymd := '';
		cKnj_tesuryo_kbn := '';
		cHko_koza_no := '';
		cHko_koza_kamoku_cd := '';
		cErr_kamoku_cd := '';
		cErr_Flg_Kamoku := '0';
		cErr_Flg_Buten := '0';
		cErr_Flg_Koza := '0';
		vSqlErrM := '';
		vMsgLog := '';
		vMsgTsuchi := '';
		vTableName := '';
		vMsg_Err_list := '';
		-- 対象データを順次読み込み、発行体コード単位に処理
		-- 発行体コードのチェック
		nCount := 0;
		SELECT count(*)
		INTO STRICT nCount
		FROM mhakkotai
		WHERE itaku_kaisha_cd = recTaisyo.itaku_kaisha_cd
		AND hkt_cd = recTaisyo.hkt_cd
		AND hkt_cd IN (SELECT hkt_cd FROM knj_tesuryo_wk)
		AND shori_kbn = '1';
		-- データが取得できない場合
		IF nCount = 0 THEN
			-- ログ出力用メッセージ
			vMsgLog := '＜テーブル:発行体マスタ、' ||
					   '発行体コード:' || recTaisyo.hkt_cd || '＞';
			-- メッセージ通知用メッセージ
			vMsgTsuchi := '未承認のため処理できません。' ||
						  '＜テーブル:発行体マスタ、' ||
						  '発行体コード:' || recTaisyo.hkt_cd || '＞';
			-- エラーリスト用テーブル名称
			vTableName := '発行体マスタ';
			-- エラーリスト用メッセージ
			vMsg_Err_list := '＜テーブル:発行体マスタ、' ||
							 '発行体コード:' || recTaisyo.hkt_cd || '＞';
			iRet := SFIPF015K01R01_COMMON_FUNC(
						'EIP514',
						vMsgLog,
						vMsgTsuchi,
						vTableName,
						vMsg_Err_list,
						recTaisyo.itaku_kaisha_cd,
						cGyoumuDt,
						nSqlCode,
						vSqlErrM
					);
			IF iRet = pkconstant.FATAL() THEN
				RETURN pkconstant.FATAL();
			END IF;
		ELSE
			SELECT koza_ten_cd,
				   hko_kamoku_cd,
				   hko_koza_no
			INTO STRICT cKoza_ten_cd,
				 cHko_koza_kamoku_cd,
				 cHko_koza_no
			FROM mhakkotai
			WHERE itaku_kaisha_cd = recTaisyo.itaku_kaisha_cd
			AND hkt_cd = recTaisyo.hkt_cd
			AND shori_kbn = '1';
			-- 部店コードの承認チェック
			nCount := 0;
			SELECT count(*)
			INTO STRICT nCount
			FROM mbuten
			WHERE itaku_kaisha_cd = recTaisyo.itaku_kaisha_cd
			AND buten_cd = cKoza_ten_cd
			AND shori_kbn = '1';
			IF nCount = 0 THEN
				cErr_Flg_Buten := '1';
			ELSE
				cErr_Flg_Buten := '0';
			END IF;
			-- 口座番号のチェック
			IF coalesce(trim(both cHko_koza_no)::text, '') = '' THEN
				cErr_Flg_Koza := '1';
			ELSE
				cErr_Flg_Koza := '0';
			END IF;
			-- 各発行体コード、手数料種類コード毎に処理を行う
			FOR nCounter IN 1 .. 3 LOOP
				cCode_rnm := '';
				cErr_Flg_Kingaku := '0';
				nKingaku := 0;
				nShohizei := 0;
				nZkingaku := 0;
				nZshohizei := 0;
				nZHkingaku := 0;
				nZHshohizei := 0;
				nZNkingaku := 0;
				nZNshohizei := 0;
				nErr_kingaku := 0;
				CASE nCounter
					WHEN 1	THEN OPEN curTesu1(recTaisyo.hkt_cd, '11', '12');
								 cTesu_cd1 := '11';
								 cTesu_cd2 := '12';
					WHEN 2	THEN OPEN curTesu1(recTaisyo.hkt_cd, '21', '22');
								 cTesu_cd1 := '21';
								 cTesu_cd2 := '22';
					WHEN 3	THEN OPEN curTesu1(recTaisyo.hkt_cd, '41', '41');
								 cTesu_cd1 := '41';
								 cTesu_cd2 := '41';
				END CASE;
				-- 該当データの件数を取得
				nCount := 0;
				SELECT count(*)
				INTO STRICT nCount
				FROM knj_tesuryo_wk
				WHERE hkt_cd = recTaisyo.hkt_cd
				AND (tesu_shurui_cd = cTesu_cd1 OR  tesu_shurui_cd = cTesu_cd2);
				-- 該当データ存在フラグを設定
				IF nCount = 0 THEN
					cFlg := '0';
				ELSE
					cFlg := '1';
				END IF;
				IF cFlg = '1' THEN
					-- 勘定系IF(元利払手数料・期中手数料)テーブルを作成
					-- 手数料区分を設定
					CASE nCounter
						WHEN 1 THEN cKnj_tesuryo_kbn := '1';
						WHEN 2 THEN cKnj_tesuryo_kbn := '2';
						WHEN 3 THEN cKnj_tesuryo_kbn := '3';
					END CASE;
					-- 手数料区分（勘定系）を取得
					SELECT code_rnm
					INTO STRICT cCode_rnm
					FROM scode
					WHERE code_shubetsu = 'S15'
					AND code_value = cKnj_tesuryo_kbn;
					-- 科目（勘定系）、口座番号（勘定系）を設定
					CASE cHko_koza_kamoku_cd
						WHEN 'T' THEN cKamoku := '21';
						WHEN 'F' THEN cKamoku := '22';
						WHEN 'B' THEN cErr_Flg_Kamoku := '1';
									  cErr_kamoku_cd := 'B';
						ELSE cErr_Flg_Kamoku := '1';
							 cErr_kamoku_cd := cHko_koza_kamoku_cd;
					END CASE;
					cKoza_no := '0' || cHko_koza_no;
					LOOP
						FETCH curTesu1 INTO recTesu;
						EXIT WHEN NOT FOUND;/* apply on curTesu1 */
						-- 補正あり手数料を計算
						CASE nCounter
							WHEN 1	THEN OPEN curHosei1(recTaisyo.hkt_cd, '11', '12');
							WHEN 2	THEN OPEN curHosei1(recTaisyo.hkt_cd, '21', '22');
							WHEN 3	THEN OPEN curHosei1(recTaisyo.hkt_cd, '41', '41');
						END CASE;
						LOOP
							FETCH curHosei1 INTO recHosei;
							EXIT WHEN NOT FOUND;/* apply on curHosei1 */
							nZkingaku := recHosei.all_tesu_kngk;
							nZshohizei := recHosei.all_tesu_szei;
							nZHkingaku := recHosei.hosei_all_tesu_kngk;
							nZHshohizei := recHosei.hosei_all_tesu_szei;
						END LOOP;
						-- 補正なし手数料を計算
						CASE nCounter
							WHEN 1	THEN OPEN curHoseiNashi1(recTaisyo.hkt_cd, '11', '12');
							WHEN 2	THEN OPEN curHoseiNashi1(recTaisyo.hkt_cd, '21', '22');
							WHEN 3	THEN OPEN curHoseiNashi1(recTaisyo.hkt_cd, '41', '41');
						END CASE;
						LOOP
							FETCH curHoseiNashi1 INTO recHoseiNasi;
							EXIT WHEN NOT FOUND;/* apply on curHoseiNashi1 */
							nZNkingaku := recHoseiNasi.all_tesu_kngk;
							nZNshohizei := recHoseiNasi.all_tesu_szei;
						END LOOP;
						-- 合計金額を計算
						nKingaku := coalesce(nZkingaku, 0) + coalesce(nZshohizei, 0) + coalesce(nZHkingaku, 0)
								  + coalesce(nZHshohizei, 0) + coalesce(nZNkingaku, 0) + coalesce(nZNshohizei, 0);
						-- 合計消費税額を計算
						nShohizei := coalesce(nZshohizei, 0) + coalesce(nZHshohizei, 0) + coalesce(nZNshohizei, 0);
						-- 集計した値をチェック後、テーブルに登録
						IF nKingaku < 1000000000000 THEN
							-- 科目コードがエラーで無い場合
							IF cErr_Flg_Kamoku = '0' AND cErr_Flg_Koza = '0'
							AND cErr_Flg_Buten = '0' THEN
								-- 手数料計算結果のＥＢ作成年月日、ＥＢ送信年月日を更新
								vSql := '';
								vSql := 'UPDATE tesuryo ';
								vSql := vSql || ' SET eb_make_ymd = ''' || cGyoumuDt || ''', ';
								vSql := vSql || ' eb_send_ymd = pkDate.getMinusDateBusiness(''' || recTesu.chokyu_kjt || ''', ''' || recTaisyo.tesuryo_eb_send_dd || ''') ';
								vSql := vSql || ' WHERE itaku_kaisha_cd = ''' || recTesu.itaku_kaisha_cd || ''' ';
								vSql := vSql || ' AND mgr_cd = ''' || recTesu.mgr_cd || ''' ';
								vSql := vSql || ' AND chokyu_kjt = ''' || recTesu.chokyu_kjt || ''' ';
								CASE nCounter
									WHEN 1 THEN vSql := vSql || ' AND (tesu_shurui_cd = ''11'' OR tesu_shurui_cd = ''12'')';
									WHEN 2 THEN vSql := vSql || ' AND (tesu_shurui_cd = ''21'' OR tesu_shurui_cd = ''22'')';
									WHEN 3 THEN vSql := vSql || ' AND tesu_shurui_cd = ''41''';
								END CASE;
								EXECUTE vSql;
							END IF;
						ELSE
							-- エラーフラグに'1'を設定
							cErr_Flg_Kingaku := '1';
							nErr_kingaku := nKingaku;
						END IF;
					END LOOP;
					-- エラーフラグが'0'の場合
					IF cErr_Flg_Kingaku = '0' AND cErr_Flg_Kamoku = '0'
					AND cErr_Flg_Buten = '0' AND cErr_Flg_Koza = '0' THEN
						-- 中継メッセージIDを設定
						IF cKamoku = '21' THEN
							cChukeimsgid := 'XIPA02';
						ELSIF cKamoku = '22' THEN
							cChukeimsgid := 'XIPF02';
						END IF;
						-- 処理日を設定
						cKnj_shori_ymd := pkDate.getPlusDateBusiness(cGyoumuDt, recTaisyo.tesuryo_eb_make_dd::integer);
						-- 受付通番（勘定系）を取得
						CALL SPIPFGETUKENO('1', cKnj_uke_tsuban, iRet);
						IF iRet != 0 THEN
							CALL pkLog.fatal('ECM701', 'IPF015K01R01', '受付通番取得エラー');
							RETURN iRet;
						END IF;
						INSERT INTO knjganrikichuif(
							itaku_kaisha_cd,
							knj_uke_tsuban_naibu,
							knj_shori_ymd,
							knj_shori_kbn,
							knj_tesuryo_kbn,
							knj_ten_no,
							knj_kamoku,
							knj_kouza_no,
							knj_kingaku,
							knj_shohizei,
							knj_inout_kbn,
							knj_chukeimsgid,
							hkt_cd,
							knj_saishori_flg,
							knj_torikeshi_flg,
							sr_stat,
							kousin_dt,
							kousin_id,
							sakusei_dt,
							sakusei_id
						)
						VALUES (
							recTaisyo.itaku_kaisha_cd,
							(cKnj_uke_tsuban)::numeric ,
							cKnj_shori_ymd,
							'3',
							cKnj_tesuryo_kbn,
							cKoza_ten_cd,
							cKamoku,
							cKoza_no,
							nKingaku,
							nShohizei,
							'2',
							cChukeimsgid,
							recTaisyo.hkt_cd,
							'0',
							'0',
							'0',
							CURRENT_TIMESTAMP,
							'BATCH',
							CURRENT_TIMESTAMP,
							'BATCH'
						);
					-- エラーフラグが'1'の場合、金額のエラー処理
					ELSIF cErr_Flg_Kingaku = '1' THEN
						-- ログ出力用メッセージ
						vMsgLog := '＜発行体コード:' || recTaisyo.hkt_cd ||
								   '、金額:' || nKingaku || '＞';
						-- メッセージ通知用メッセージ
						vMsgTsuchi := '金額が13桁以上のため処理できません。' ||
									  '＜発行体コード:' || recTaisyo.hkt_cd ||
									  '、金額:' || nKingaku || '＞';
						-- エラーリスト用テーブル名称
						vTableName := ' ';
						-- エラーリスト用メッセージ
						vMsg_Err_list := '＜発行体コード:' || recTaisyo.hkt_cd ||
										 '、金額:' || nKingaku || '＞';
						iRet := SFIPF015K01R01_COMMON_FUNC(
									'EIP515',
									vMsgLog,
									vMsgTsuchi,
									vTableName,
									vMsg_Err_list,
									recTaisyo.itaku_kaisha_cd,
						cGyoumuDt,
						nSqlCode,
						vSqlErrM
								);
						IF iRet = pkconstant.FATAL() THEN
							RETURN pkconstant.FATAL();
						END IF;
					-- 部店コードがエラーの場合
					ELSIF cErr_Flg_Buten = '1' THEN
						-- ログ出力用メッセージ
						vMsgLog := '＜発行体コード:' || recTaisyo.hkt_cd ||
								   '、部店コード:' || cKoza_ten_cd || 
								   '、請求金額:' || nKingaku || 
								   '、手数料区分:' || cCode_rnm || '＞';
						-- メッセージ通知用メッセージ
						vMsgTsuchi := '未承認のため処理できません。' ||
									  '＜テーブル:部店マスタ、' ||
									  '発行体:' || recTaisyo.hkt_cd ||
									  '、部店:' || cKoza_ten_cd || '＞';
						-- エラーリスト用テーブル名称
						vTableName := '部店マスタ';
						-- エラーリスト用メッセージ
						vMsg_Err_list := '＜発行体コード:' || recTaisyo.hkt_cd ||
										 '、部店コード:' || cKoza_ten_cd || 
										 '、請求金額:' || nKingaku || 
										 '、手数料区分:' || cCode_rnm || '＞';
						iRet := SFIPF015K01R01_COMMON_FUNC(
									'EIP514',
									vMsgLog,
									vMsgTsuchi,
									vTableName,
									vMsg_Err_list,
									recTaisyo.itaku_kaisha_cd,
						cGyoumuDt,
						nSqlCode,
						vSqlErrM
								);
						IF iRet = pkconstant.FATAL() THEN
							RETURN pkconstant.FATAL();
						END IF;
				END IF;
				END IF;
			END LOOP;
			-- エラーフラグ(科目コード用)が'1'の場合、口座科目のエラー処理
			IF cErr_Flg_Kamoku = '1' THEN
				-- ログ出力用メッセージ
				vMsgLog := '＜発行体コード:' || recTaisyo.hkt_cd ||
						   '、科目コード:' || cErr_kamoku_cd || '＞';
				-- メッセージ通知用メッセージ
				vMsgTsuchi := '口座科目が対象外です。' ||
							  '＜発行体コード:' || recTaisyo.hkt_cd ||
							  '、科目コード:' || cErr_kamoku_cd || '＞';
				-- エラーリスト用テーブル名称
				vTableName := '発行体マスタ';
				-- エラーリスト用メッセージ
				vMsg_Err_list := '＜発行体コード:' || recTaisyo.hkt_cd ||
								 '、科目コード:' || cErr_kamoku_cd || '＞';
				iRet := SFIPF015K01R01_COMMON_FUNC(
							'EIP516',
							vMsgLog,
							vMsgTsuchi,
							vTableName,
							vMsg_Err_list,
							recTaisyo.itaku_kaisha_cd,
						cGyoumuDt,
						nSqlCode,
						vSqlErrM
						);
				IF iRet = pkconstant.FATAL() THEN
					RETURN pkconstant.FATAL();
				END IF;
			-- エラーフラグ(口座番号用)が'1'の場合、口座科目のエラー処理
			ELSIF cErr_Flg_Koza = '1' THEN
				-- ログ出力用メッセージ
				vMsgLog := '＜発行体コード:' || recTaisyo.hkt_cd ||
						   '、口座番号:' || cHko_koza_no || '＞';
				-- メッセージ通知用メッセージ
				vMsgTsuchi := '口座番号が未設定です。' ||
							  '＜発行体コード:' || recTaisyo.hkt_cd ||
							  '、口座番号:' || cHko_koza_no || '＞';
				-- エラーリスト用テーブル名称
				vTableName := '発行体マスタ';
				-- エラーリスト用メッセージ
				vMsg_Err_list := '＜発行体コード:' || recTaisyo.hkt_cd ||
								 '、口座番号:' || cHko_koza_no || '＞';
				iRet := SFIPF015K01R01_COMMON_FUNC(
							'EIP524',
							vMsgLog,
							vMsgTsuchi,
							vTableName,
							vMsg_Err_list,
							recTaisyo.itaku_kaisha_cd,
						cGyoumuDt,
						nSqlCode,
						vSqlErrM
						);
				IF iRet = pkconstant.FATAL() THEN
					RETURN pkconstant.FATAL();
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
			'ECM701',
			'IPF015K01R01',
			'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')'
		);
		RETURN pkconstant.FATAL();
--		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf015k01r01 () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipf015k01r01_common_func ( l_inMessage_id text,			-- メッセージＩＤ
 l_inMsgLog text,			-- ログ出力用メッセージ
 l_inMsgTsuchi text,			-- メッセージ通知用メッセージ
 l_inTableName text,			-- テーブル名称
 l_inMsg_Err_list text,			-- エラーリスト用メッセージ
 l_inItaku_kaisha_cd text, 				-- 委託会社コード
 l_inCGyoumuDt text,		-- 業務日付
 l_inNSqlCode integer,		-- SQLコード
 l_inVSqlErrM text			-- エラーメッセージ
 ) RETURNS integer AS $body$
DECLARE
	iRet integer;
BEGIN
	-- ログ出力
	CALL pkLog.error(
		l_inMessage_id,
		'IPF015K01R01',
		l_inMsgLog
	);
	-- エラーリスト出力
	CALL SPIPF001K00R01(
		l_inItaku_kaisha_cd,
		'BATCH', 
		'1', 
		'3', 
		l_inCGyoumuDt, 
		'63', 
		'9999999999', 
		l_inTableName, 
		l_inMsg_Err_list,
		l_inMessage_id, 
		l_inNSqlCode, 
		l_inVSqlErrM
	);
	-- メッセージ通知テーブルへ書き込み
	iRet := SfIpMsgTsuchiUpdate(
			l_inItaku_kaisha_cd,
			'勘定系',
			'警告',
			'1',
			'0',
			l_inMsgTsuchi,
			'BATCH',
			'BATCH'
	);
	IF iRet != 0 THEN
		CALL pkLog.fatal(
			'ECM701',
			'IPF015K01R01',
			'メッセージ通知登録エラー'
		);
		RETURN iRet;
	END IF;
	RETURN pkconstant.error();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf015k01r01_common_func ( l_inMessage_id text, l_inMsgLog text, l_inMsgTsuchi text, l_inTableName text, l_inMsg_Err_list text, l_inItaku_kaisha_cd text  ) FROM PUBLIC;
