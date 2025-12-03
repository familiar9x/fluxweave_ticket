




CREATE OR REPLACE FUNCTION sfipxb23k15r01 ( l_inIfId char(6) 		-- 外部IFID
 ) RETURNS numeric AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2017
-- * 会社名:JIP
-- *
-- * 概  要:外部IF送受信データテーブルに格納された、連携ファイル（顧客管理店情報受信ファイル）を、項目ごとに分割して顧客管理店情報受信へ登録する。
-- *
-- * @author 横尾 隆児
-- * @version $Id:$
-- *
-- * @param l_inIfId			外部IFID
-- * @return INTEGER 0:正常、99:異常、それ以外：エラー
-- *
-- ***************************************************************************
-- * ログ:
-- *    日付    開発者名		目的
-- * -------------------------------------------------------------------------
-- * 2017.01.25 横尾			新規作成
-- ***************************************************************************
--
	--==============================================================================
	--					定数定義													
	--==============================================================================
	-- ファンクションＩＤ
	C_FUNCTION_ID		CONSTANT	varchar(50)	:= 'SFIPXB23K15R01';
	-- 連携フラグ
	C_RENKEI_FLG_SUMI	CONSTANT	CHAR			:= '1';		-- 連携済
	--==============================================================================
	--					変数定義													
	--==============================================================================
	gGyomuYmd			char(8)								:= '';		-- 業務日付
	gMakeCnt			numeric(5)		:= 0;		-- 作成回数
	gRenkeiFlg			char(1)	:= '0';	-- 連携フラグ
	gResult				integer								:= 0;		-- 共通部品の戻り値
	gRecCnt				integer								:= 0;		-- レコードカウンター
	gDataNo				numeric(10)		:= 0;		-- 外部IFデータ番号
	gKokyakuKanriTenNo	char(7);											-- 顧客管理店番
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
	-- 処理制御値取得
	gResult := pkIpIF.getRenkeiFlg(l_inIfId, gGyomuYmd, gMakeCnt, gRenkeiFlg);
	IF gResult <> pkconstant.success() THEN
		RETURN gResult;
	ELSE
		-- 戻り値が0でも、作成回数と連携フラグいずれも初期値の場合は異常終了とする。
		IF gMakeCnt = 0 AND gRenkeiFlg = '0' THEN
			CALL pkLog.error('ECM501', C_FUNCTION_ID, '外部IF送受信管理から連携フラグが取得できません。');
			RETURN pkconstant.error();
		END IF;
	END IF;
	IF gRenkeiFlg = '0' THEN 			-- 0:未連携
		-- 顧客管理店情報受信データテーブルの削除
		DELETE FROM KOKYAKU_KANRITEN_REC;
		-- 外部IF送受信データの読み込み
		FOR rec IN curMeisai LOOP
			-- 外部IFデータ番号取得
			gDataNo := rec.IF_DATA_NO;
			-- ヘッダーレコードチェック
			IF substring(rec.IF_DATA, 1, 1) = '1' THEN
				-- ヘッダーレコードの日付が業務日付と異なる場合、エラー判定
				IF substring(rec.IF_DATA, 2, 8) <> gGyomuYmd THEN
					CALL pkLog.error('EIP553', C_FUNCTION_ID, 'ヘッダーレコード日付：[' || substring(rec.IF_DATA, 2, 8) || '] 業務日付：[' || gGyomuYmd || ']' );
					RETURN pkconstant.error();
				END IF;
			END IF;
			-- データレコード編集処理
			IF substring(rec.IF_DATA, 1, 1) = '2' THEN
				-- データレコード件数カウント
				gRecCnt := gRecCnt + 1;
				-- 顧客管理店番
				gKokyakuKanriTenNo := coalesce(RTRIM(substring(rec.IF_DATA, 16, 7)), ' ');
				-- 顧客管理店番未設定時
				IF coalesce(trim(both gKokyakuKanriTenNo)::text, '') = '' THEN
					-- 「取引集約店番」が未設定時は、「店番」7桁を設定する
					IF trim(both substring(rec.IF_DATA, 23, 7)) IS NULL THEN
						gKokyakuKanriTenNo := coalesce(RTRIM(substring(rec.IF_DATA, 2, 7)), ' ');
					ELSE
					-- 「取引集約店番」が設定時は、「取引集約店番」を設定する
						gKokyakuKanriTenNo := coalesce(RTRIM(substring(rec.IF_DATA, 23, 7)), ' ');
					END IF;
				END IF;
				-- 顧客管理店情報受信データ登録
				INSERT INTO KOKYAKU_KANRITEN_REC(
					ITAKU_KAISHA_CD,
					KOZA_TEN_CD,
					KOZA_TEN_CIFCD,
					KOKYAKU_KANRI_TEN_NO,
					TORI_SHUYAKU_TEN_NO,
					TANTO_CD1,
					TANTO_CD2,
					JINKAKU_KBN,
					SHORI_YMD,
					KOUSIN_ID,
					SAKUSEI_ID
				)
				VALUES (
					pkConstant.getKaiinId(),									-- 委託会社コード (固定値 '0005')
					substring(rec.IF_DATA, 5, 4),							-- 口座店コード
					LPAD(substring(rec.IF_DATA, 9, 7), 8, '0'),			-- 口座店ＣＩＦコード
					coalesce(RTRIM(gKokyakuKanriTenNo), ' '),				-- 顧客管理店番
					coalesce(RTRIM(substring(rec.IF_DATA, 23, 7)), ' '),		-- 取引集約店番
					coalesce(RTRIM(substring(rec.IF_DATA, 30, 3)), ' '),		-- 担当者コード１
					coalesce(RTRIM(substring(rec.IF_DATA, 33, 3)), ' '),		-- 担当者コード２
					coalesce(RTRIM(substring(rec.IF_DATA, 36, 2)), ' '),		-- 人格区分
					gGyomuYmd,											-- 処理日付
					pkconstant.BATCH_USER(),								-- 更新者 (固定値 'BATCH')
					pkconstant.BATCH_USER() 								-- 作成者 (固定値 'BATCH')
				);
			END IF;
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
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipxb23k15r01 ( l_inIfId char(6)  ) FROM PUBLIC;
