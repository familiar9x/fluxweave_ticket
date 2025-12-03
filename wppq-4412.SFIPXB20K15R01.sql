CREATE OR REPLACE FUNCTION sfipxb20k15r01 ( 
	l_inIfId VARCHAR		-- 外部IFID
) RETURNS numeric AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2016
-- * 会社名:JIP
-- *
-- * 概  要:CIF情報受信ファイルで送信した口座店番/顧客情報に紐づく顧客名称、住所等を受信する。
-- *        受信データは外部IF送受信データテーブルより取得し、項目ごとに分割・再編集して
-- *        CIF情報受信データテーブルに登録する。
-- *
-- * @author 村木 明広
-- * @version $Id:$
-- *
-- * @param l_inIfId			外部IFID
-- * @return INTEGER 0:正常、99:異常、それ以外：エラー
-- *
-- ***************************************************************************
-- * ログ:
-- *    日付    開発者名		目的
-- * -------------------------------------------------------------------------
-- * 2016.10.25 村木			新規作成
-- ***************************************************************************
--
	--==============================================================================
	--					定数定義													
	--==============================================================================
	-- ファンクションＩＤ
	C_FUNCTION_ID		CONSTANT	varchar(50)	:= 'SFIPXB20K15R01';
	-- レコード区分
	C_REC_HEADER		CONSTANT	TEXT			:= '1';		-- ヘッダーレコード
	C_REC_DATA			CONSTANT	TEXT			:= '2';		-- データレコード
	C_REC_END			CONSTANT	TEXT			:= '9';		-- エンドレコード
	-- 連携フラグ
	C_RENKEI_FLG_SUMI	CONSTANT	TEXT			:= '1';		-- 連携済
	--==============================================================================
	--					変数定義													
	--==============================================================================
	gGyomuYmd			char(8)								:= '';		-- 業務日付
	gMakeCnt			NUMERIC		:= 0;		-- 作成回数
	gRenkeiFlg			VARCHAR	:= '0';	-- 連携フラグ
	gResult				integer								:= 0;		-- 共通部品の戻り値
	gRecCnt				integer								:= 0;		-- レコードカウンター
	gDataNo				NUMERIC		:= 0;		-- 外部IFデータ番号
	--==============================================================================
	--					例外定義													
	--==============================================================================
	--==============================================================================
	--					カーソル定義												
	--==============================================================================
	-- 外部IF送受信データ
	curMeisai CURSOR FOR
		SELECT
			IF_ID,					-- 外部IFID
			IF_MAKE_DT,				-- 外部IF作成日
			IF_MAKE_CNT,			-- 外部IF作成回数
			IF_DATA_NO,				-- 外部IFデータ番号
			IF_DATA 					-- 外部IFデータ
		FROM
			GAIBU_IF_DATA
		WHERE
			IF_ID					= l_inIfId
			AND IF_MAKE_DT			= gGyomuYmd
			AND IF_MAKE_CNT			= gMakeCnt
		ORDER BY
			IF_DATA_NO;				-- 外部IFID
--==============================================================================
--                  関数定義                                                    
--==============================================================================
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	CALL pkLog.debug('BATCH', C_FUNCTION_ID, '***** ' || C_FUNCTION_ID || ' START *****');
	-- 入力パラメータのチェック
	-- 外部IFID の必須チェック
	IF coalesce(l_inIfId::text, '') = '' THEN
		-- パラメータエラー
		CALL pkLog.error('ECM501', C_FUNCTION_ID, '外部IFID');
		RETURN pkconstant.error();
	END IF;
	-- 業務日付の取得
	gGyomuYmd := pkDate.getGyomuYmd();
	RAISE NOTICE 'DEBUG: gGyomuYmd = %', gGyomuYmd;
	-- 作成回数の取得
	gResult := pkIpIF.getRenkeiFlg(l_inIfId, gGyomuYmd, gMakeCnt, gRenkeiFlg);
	RAISE NOTICE 'DEBUG: getRenkeiFlg result = %, gMakeCnt = %, gRenkeiFlg = %', gResult, gMakeCnt, gRenkeiFlg;
	IF gResult <> pkconstant.success() THEN
		RAISE NOTICE 'DEBUG: getRenkeiFlg failed, returning %', gResult;
		RETURN gResult;
	ELSE
		-- 戻り値が0でも、作成回数と連携フラグいずれも初期値の場合は異常終了とする。
		IF gMakeCnt = 0 AND gRenkeiFlg = '0' THEN
			CALL pkLog.error('ECM501', C_FUNCTION_ID, '外部IF送受信管理から連携フラグが取得できません。');
			RETURN pkconstant.error();
		END IF;
	END IF;
	IF gRenkeiFlg = '0' THEN 			-- 0:未連携
		-- CIF情報受信テーブルの削除
		DELETE FROM CIF_INFO_RCV;
		-- 外部IF送受信データの読み込み
		FOR rec IN curMeisai LOOP
			gDataNo := rec.IF_DATA_NO;
			-- レコード区分による処理の振り分け
			CASE substr(rec.IF_DATA, 1, 1)
				WHEN C_REC_HEADER THEN 			-- ヘッダーレコード
					-- ヘッダーレコードチェック
					IF substr(rec.IF_DATA, 2, 8) <> gGyomuYmd THEN
						CALL pkLog.error('EIP553', C_FUNCTION_ID,
								'ヘッダーレコードの日付:[' || substr(rec.IF_DATA, 2, 8) || '] '
								|| '業務日付:[' || gGyomuYmd || ']' );
						RETURN pkconstant.error();
					END IF;
				WHEN C_REC_DATA THEN 			-- データレコード
					-- 登録件数カウント
					gRecCnt := gRecCnt + 1;
					-- CIF情報受信へ登録する
					INSERT INTO CIF_INFO_RCV(
						ITAKU_KAISHA_CD,		-- 委託会社コード
						KOZA_TEN_CD,			-- 口座店コード
						KOZA_TEN_CIFCD,			-- 口座店ＣＩＦコード
						TRHK_KANA,				-- 取引先名（カナ）
						TRHK_KANJI,				-- 取引先名（漢字）
						POST_NO,				-- 郵便番号
						KOKYAKU_ADD_KANJI,		-- 顧客住所（漢字）
						CIF_KEKKA,				-- CIF処理結果
						SHORI_YMD,				-- 処理日付
						KOUSIN_ID,				-- 更新者
						SAKUSEI_ID 				-- 作成者
					)
					VALUES (
						pkconstant.getKaiinId(),
						substr(rec.IF_DATA, 5, 4),
						LPAD(substr(rec.IF_DATA, 9, 7), 8, '0'),
						coalesce(trim(both ' ' from substr(rec.IF_DATA, 16, 50)), ' '),
						coalesce(TRIM(BOTH '　' FROM substr(rec.IF_DATA, 66, 60) ), ' '),
						substr(rec.IF_DATA, 126, 7),
						coalesce(TRIM(BOTH '　' FROM substr(rec.IF_DATA, 133, 100) ), ' '),
						coalesce(RTRIM(substr(rec.IF_DATA, 233, 2)), ' '),
						gGyomuYmd,
						pkconstant.BATCH_USER(),
						pkconstant.BATCH_USER()
					);
				WHEN C_REC_END THEN 			-- エンドレコード
					-- エンドレコードチェック
					IF (substr(rec.IF_DATA, 2, 7))::numeric  <> gRecCnt THEN
						CALL pkLog.error('EIP554', C_FUNCTION_ID,
								'明細レコード数:[' || gRecCnt || '] '
								|| 'エンドレコード件数:[' || substr(rec.IF_DATA, 2, 7) || ']' );
						RETURN pkconstant.error();
					END IF;
			END CASE;
		END LOOP;
		-- 外部IF送受信管理の連携フラグを更新する
		gResult := pkIpIF.updRenkeiFlg(l_inIfId, gGyomuYmd, gMakeCnt, C_RENKEI_FLG_SUMI);
		IF gResult <> pkconstant.success() THEN
			RETURN gResult;
		END IF;
	END IF;
	-- 終了処理
	CALL pkLog.info('IIP015', C_FUNCTION_ID, gRecCnt || ' 件');
	CALL pkLog.debug('BATCH', C_FUNCTION_ID, '***** ' || C_FUNCTION_ID || ' END *****');
 	RETURN pkconstant.success();
-- 例外処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'SQLERRM:' || SQLERRM);
		-- CIF情報受信テーブルへの登録処理内で例外の場合、対象レコード箇所を出力
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '外部IF送受信管理処理対象レコード：' || gDataNo || '件目');
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
