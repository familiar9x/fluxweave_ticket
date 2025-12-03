


DROP TYPE IF EXISTS sfipxb19k15r01_tcifjohososhinheader CASCADE;
CREATE TYPE sfipxb19k15r01_tcifjohososhinheader AS (
		kubun				char(1),			-- レコード区分
		ymd					char(8),			-- 日付
		filename			char(8),	-- ファイル名
		yobi				char(13) 				-- 予備
	);
DROP TYPE IF EXISTS sfipxb19k15r01_tcifjohososhindata CASCADE;
CREATE TYPE sfipxb19k15r01_tcifjohososhindata AS (
		kubun				char(1),			-- レコード区分
		tenban				char(7),			-- 店番
		kokyakubango		char(7),			-- 顧客番号
		biko				char(15) 				-- 備考
	);
DROP TYPE IF EXISTS sfipxb19k15r01_tcifjohososhinend CASCADE;
CREATE TYPE sfipxb19k15r01_tcifjohososhinend AS (
		kubun				char(1),			-- レコード区分
		kensu				char(6),			-- 件数
		biko				char(23) 				-- 備考
	);


CREATE OR REPLACE FUNCTION sfipxb19k15r01 ( l_inIfId char(6) 			-- 外部IFID
 ) RETURNS integer AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2016
-- * 会社名:JIP
-- *
-- * 概  要:発行体マスタのCIF連動対象の「口座店コード」・「口座店ＣＩＦコード」を預為システムに連携するデータを作成する。
-- *        作成したデータは外部IF送受信データテーブルに登録し、後続処理で預為システムに連携するファイルとして出力される。
-- *
-- * @author 山中 大輔
-- * @version $Id:$
-- *
-- * @param l_inIfId				外部IFID
-- * @return INTEGER 0:正常、99:異常、それ以外：エラー
-- *
-- ***************************************************************************
-- * ログ:
-- *    日付    開発者名		目的
-- * -------------------------------------------------------------------------
-- * 2016.12.06 山中			新規作成
-- ***************************************************************************
--
	--==============================================================================
	--					定数定義													
	--==============================================================================
	-- ファンクションＩＤ
	C_FUNCTION_ID			CONSTANT	varchar(50)	:= 'SFIPXB19K15R01';
	--==============================================================================
	--					変数定義													
	--==============================================================================
	gGyomuYmd				char(8)							:= '';		-- 業務日付
	gMakeCnt				numeric(5)	:= 0;		-- 作成回数
	gResult					integer							:= 0;		-- 共通部品の戻り値
	gDataNo					numeric(10)	:= 0;		-- データ番号
	gRecordCount			numeric(10)	:= 0;		-- 明細レコード件数
	-- CIF情報送信ファイル・ヘッダーレコード
	gCifJohoSoshinHeader SFIPXB19K15R01_tCifJohoSoshinHeader;
	-- CIF情報送信ファイル・データレコード
	gCifJohoSoshinData SFIPXB19K15R01_tCifJohoSoshinData;
	-- CIF情報送信ファイル・エンドレコード
	gCIfJohoSoshinEnd SFIPXB19K15R01_tCifJohoSoshinEnd;
	--==============================================================================
	--					例外定義													
	--==============================================================================
	--==============================================================================
	--					カーソル定義												
	--==============================================================================
	-- CIF情報送信
	curMeisai CURSOR FOR
		SELECT
			ITAKU_KAISHA_CD,											-- 委託会社コード
			KOZA_TEN_CD,												-- 口座店コード
			KOZA_TEN_CIFCD,												-- 口座CIFコード
			SHORI_YMD 													-- 処理日付
		FROM
			CIF_INFO_SND 												-- CIF情報送信
		ORDER BY ITAKU_KAISHA_CD,
			KOZA_TEN_CD,
			KOZA_TEN_CIFCD;
--==============================================================================
--					関数定義													
--==============================================================================
--==============================================================================
--					メイン処理													
--==============================================================================
BEGIN
	-- 複合型の初期化
	gCifJohoSoshinHeader := ('1', '', 'WYBIDE40', '')::SFIPXB19K15R01_tCifJohoSoshinHeader;
	gCifJohoSoshinData := ('2', '', '', '')::SFIPXB19K15R01_tCifJohoSoshinData;
	gCIfJohoSoshinEnd := ('9', '', '')::SFIPXB19K15R01_tCifJohoSoshinEnd;
	
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
	-- 外部ＩＦ送受信管理登録
	gResult := pkIpIF.insGaibuIFKanri(l_inIfId, gGyomuYmd, gMakeCnt);
	IF gResult <> pkconstant.success() THEN
		RETURN gResult;
	END IF;
	-- 外部IFデータ番号
	gDataNo := gDataNo + 1;
	-- 日付
	gCifJohoSoshinHeader.ymd := gGyomuYmd;
	INSERT INTO GAIBU_IF_DATA(
		IF_ID,
		IF_MAKE_DT,
		IF_MAKE_CNT,
		IF_DATA_NO,
		IF_DATA,
		KOUSIN_ID,
		SAKUSEI_ID
	)
	VALUES (
		l_inIfId,
		gGyomuYmd,
		gMakeCnt,
		gDataNo,
		gCifJohoSoshinHeader.kubun
			 || gCifJohoSoshinHeader.ymd
			 || gCifJohoSoshinHeader.filename
			 || gCifJohoSoshinHeader.yobi,
		pkconstant.BATCH_USER(),
		pkconstant.BATCH_USER()
	);
	FOR rec IN curMeisai LOOP
		-- 外部IFデータ番号
		gDataNo := gDataNo + 1;
		-- 明細レコードデータ件数
		gRecordCount := gRecordCount + 1;
		-- 店番
		gCifJohoSoshinData.tenban := LPAD(rec.KOZA_TEN_CD, 7, 0);
		-- 顧客番号
		gCifJohoSoshinData.kokyakubango := substring(rec.KOZA_TEN_CIFCD, 2, 7);
		INSERT INTO GAIBU_IF_DATA(
			IF_ID,
			IF_MAKE_DT,
			IF_MAKE_CNT,
			IF_DATA_NO,
			IF_DATA,
			KOUSIN_ID,
			SAKUSEI_ID
		)
		VALUES (
			l_inIfId,
			gGyomuYmd,
			gMakeCnt,
			gDataNo,
			gCifJohoSoshinData.kubun
				 || gCifJohoSoshinData.tenban
				 || gCifJohoSoshinData.kokyakubango
				 || gCifJohoSoshinData.biko,
			pkconstant.BATCH_USER(),
			pkconstant.BATCH_USER()
		);
	END LOOP;
	-- 外部IFデータ番号
	gDataNo := gDataNo + 1;
	-- 件数
	gCIfjohoSoshinEnd.kensu := LPAD(gRecordCount, 6, '0');
	INSERT INTO GAIBU_IF_DATA(
		IF_ID,
		IF_MAKE_DT,
		IF_MAKE_CNT,
		IF_DATA_NO,
		IF_DATA,
		KOUSIN_ID,
		SAKUSEI_ID
	)
	VALUES (
		l_inIfId,
		gGyomuYmd,
		gMakeCnt,
		gDataNo,
		gCifJohoSoshinEnd.kubun
			 || gCifJohoSoshinEnd.kensu
			 || gCifJohoSoshinEnd.biko,
		pkconstant.BATCH_USER(),
		pkconstant.BATCH_USER()
	);
	-- 終了処理
	CALL pkLog.info('IIP015', C_FUNCTION_ID,  gDataNo::text || ' 件');
	CALL pkLog.debug('BATCH', C_FUNCTION_ID, '***** ' || C_FUNCTION_ID || ' END *****');
	RETURN pkconstant.success();
-- 例外処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'SQLERRM:' || SQLERRM);
		-- 外部IF送受信管理テーブルへの登録処理内で例外の場合、対象レコード箇所を出力
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '外部IF送受信管理処理対象レコード：' ||  gDataNo::text || '件目');
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipxb19k15r01 ( l_inIfId char(6)  ) FROM PUBLIC;
