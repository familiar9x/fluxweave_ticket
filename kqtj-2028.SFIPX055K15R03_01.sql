


DROP TYPE IF EXISTS sfipx055k15r03_01_type_record;
CREATE TYPE sfipx055k15r03_01_type_record AS (
		ITAKU_KAISHA_CD		char(4),				-- 委託会社コード
		MGR_CD			varchar(13),					-- 銘柄コード
		HAKKO_TSUKA_CD		char(3),				-- 発行通貨コード
		CHOKYU_YYYYMM		varchar(6),						-- 徴求日の年月
		KOZA_TEN_CD		char(4),				-- 口座店コード
		KOZA_TEN_CIFCD		char(11),				-- 口座店ＣＩＦコード
		CHOKYU_DD		varchar(2),						-- 徴求日の日
		KOZA_FURI_KBN		char(2),				-- 口座振替区分
		ISIN_CD			char(12),					-- ＩＳＩＮコード
		TESU_SHURUI_CD		char(2),				-- 手数料種類コード
		CHOKYU_KJT		char(8),				-- 徴求期日
		CHOKYU_YMD		char(8)				-- 徴求日
	);


CREATE OR REPLACE FUNCTION sfipx055k15r03_01 ( l_initakuKaishaCd char(4) , l_inBankRnm varchar(30) ) RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2016
-- * 会社名: JIP
-- *
-- * 公社債関連資金受入予定表（信託報酬・期中手数料）を作成する。（バッチ用）
-- * １．請求データ検索処理
-- * ２．公社債関連資金受入予定表作表処理
-- * ３．バッチ帳票出力ＯＮ処理
-- *
-- * @author Y.Nagano
-- * @version $Id: SFIPX055K15R03_01.sql,v 1.0 2016/11/29 10:19:30 Y.Nagano Exp $
-- *
-- * @param l_initakuKaishaCd 委託会社コード
-- * @param l_inBankRnm       委託会社略称
-- * @return INTEGER 0:正常、99:異常、それ以外：エラー
-- 
--==============================================================================
--					変数定義													
--==============================================================================
	gReturnCode			integer := 0;
	gCur REFCURSOR;	--システム設定分と個別設定分を取得するカーソル
	gGyomuYmd			char(8);
	gKjtFrom			char(8);
	gKjtTo				char(8);
	gSeqNo				integer := 0;
	gSeqNo2				integer := 0;
	gMaxSeqNo			integer := 0;
	gSQL				varchar(5000) := NULL;		-- SQL格納用変数
	gREPORT_ID			CONSTANT char(11) := 'IP931505531';	-- レポートＩＤ
	wkChohyoId			varchar(11);		-- ワーク帳票ＩＤ
	gAlltesukngk			integer := 0;
	gChokyuYmdFrom			char(8)	:=	'99999999';		--	徴求日	From	(抽出した徴求日との大小関係を比較するため、初期値は最大値)
	gChokyuYmdTo			char(8)	:=	'00000000';		--	徴求日	To	(抽出した徴求日との大小関係を比較するため、初期値は最小値)
	gOutSqlErrM			varchar(5000) := NULL;				-- エラーコメント
	-- レコードタイプ宣言
	-- レコード
	rec sfipx055k15r03_01_type_record[];
	temp_rec sfipx055k15r03_01_type_record;
--==============================================================================
--					メイン処理													
--==============================================================================
BEGIN
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
	-- 請求書出力設定テーブルから、出力期間を取得する（業務日付が出力日ではない場合、From-Toは'99999999'で返る）
	CALL PKIPACALCTESURYO.GETBATCHSEIKYUOUTFROMTO(l_initakukaishacd,		-- 委託会社コード
						 '2',				-- 請求書区分（1：元利金、2：手数料）
						 gKjtFrom,			-- 戻り値１：期間From
						 gKjtTo);
	-- システム設定分と個別設定分の請求書作成データを取得するためのカーソル文を作成する
	gSQL := pkIpaKichuTesuryo.createCursor(gKjtFrom, gKjtTo, l_initakukaishacd, '', '', '', '', '', '1');
        -- カウントの初期化
	gSeqNo := 0;
	rec := ARRAY[]::sfipx055k15r03_01_type_record[];
	-- カーソルオープン
	OPEN gCur FOR EXECUTE gSQL;
	LOOP
		FETCH gCur INTO
			temp_rec.ITAKU_KAISHA_CD,
			temp_rec.MGR_CD,
			temp_rec.HAKKO_TSUKA_CD,
			temp_rec.CHOKYU_YYYYMM,
			temp_rec.KOZA_TEN_CD,
			temp_rec.KOZA_TEN_CIFCD,
			temp_rec.CHOKYU_DD,
			temp_rec.KOZA_FURI_KBN,
			temp_rec.ISIN_CD,
			temp_rec.TESU_SHURUI_CD,
			temp_rec.CHOKYU_KJT,
			temp_rec.CHOKYU_YMD;
		-- データが無くなったらループを抜ける
		EXIT WHEN NOT FOUND;/* apply on gCur */
		-- Append to array
		rec := array_append(rec, temp_rec);
		-- シーケンスナンバーをカウントアップしておく
		gSeqNo := gSeqNo + 1;
	-- レコード数分ループの終了
	END LOOP;
	-- カーソルクローズ
	CLOSE gCur;
	-- ワーク帳票ＩＤ取得 (IPをWKに置き換え)
	wkChohyoId := REPLACE(gREPORT_ID, 'IP', 'WK');
	-- 作票を開始するためワークに残っているかもしれないデータをDELETE
	DELETE FROM SREPORT_WK WHERE CHOHYO_ID = wkChohyoId;
	-- 公社債関連資金受入予定表出力対象をワークに格納
	-- 最大値を保持してカウンタを初期化
	gMaxSeqNo := gSeqNo;
	gSeqNo := 1;
	FOR gSeqNo IN 1..gMaxSeqNo LOOP
		-- 対象銘柄の手数料が0円の場合、出力しない。
		BEGIN
			SELECT MIN(ALL_TESU_KNGK) INTO STRICT gAlltesukngk FROM TESURYO
				WHERE	ITAKU_KAISHA_CD = l_initakukaishacd
				AND		MGR_CD          = rec[gSeqNo].MGR_CD
				AND		CHOKYU_YMD      = rec[gSeqNo].CHOKYU_YMD
				AND		TESU_SHURUI_CD IN ('11','12');
			EXCEPTION
				WHEN OTHERS THEN
					gAlltesukngk := 0;
		END;
		-- ０円以外は出力準備を行う
		IF gAlltesukngk <> 0 THEN
			-- 徴求日Fromを求める(現在の値よりちいさければセット)
			IF gChokyuYmdFrom > rec[gSeqNo].CHOKYU_YMD THEN
				-- 徴求日Fromをセットする
				gChokyuYmdFrom := rec[gSeqNo].CHOKYU_YMD;
			END IF;
			-- 徴求日Toを求める(現在の値よりおおきければセット)
			IF gChokyuYmdTo < rec[gSeqNo].CHOKYU_YMD THEN
				-- 徴求日Toをセットする
				gChokyuYmdTo := rec[gSeqNo].CHOKYU_YMD;
			END IF;
			gSeqNo2 := gSeqNo2 + 1;
			-- 請求書作票処理をおこなう
			-- ワークデータ作成
			CALL pkPrint.insertData(
				l_inKeyCd	=>	rec[gSeqNo].ITAKU_KAISHA_CD 				-- 識別コード
				,l_inUserId	=>	pkconstant.BATCH_USER() 								-- ユーザＩＤ
				,l_inChohyoKbn	=>	'1'						-- 帳票区分
				,l_inSakuseiYmd	=>	gGyomuYmd 							-- 作成年月日
				,l_inChohyoId	=>	wkChohyoId 								-- WK帳票ＩＤ
				,l_inSeqNo	=>	gSeqNo 									-- SEQNO
				,l_inHeaderFlg	=>	'1'										-- ヘッダフラグ								-- 連番
				,l_inItem001	=>	rec[gSeqNo].MGR_CD 						-- 銘柄コード
				,l_inItem002	=>	rec[gSeqNo].CHOKYU_YMD 					-- 徴求日
				,l_inKousinId	=>	pkconstant.BATCH_USER() 								-- 更新者ID
				,l_inSakuseiId	=>	pkconstant.BATCH_USER() 								-- 作成者ID
			);
		END IF;
	END LOOP;
	gMaxSeqNo := gSeqNo2;
	-- 公社債関連資金受入予定表（信託報酬・期中手数料）の作成
	CALL SPIPX055K15R03(gREPORT_ID, l_initakukaishacd, l_inBankRnm, pkconstant.BATCH_USER(), '1', gGyomuYmd, gReturnCode, gOutSqlErrM);
  -- 対象データなしの場合
	IF gReturnCode = pkconstant.NO_DATA_FIND() THEN
		CALL pkLog.debug('BATCH', 'SPIPX055K15R03', '委託会社：' || l_initakukaishacd || ' 対象データなし');
		RETURN gReturnCode;
	END IF;
	-- 公社債関連資金受入予定表（信託報酬・期中手数料）の作成時にエラーがあった場合
	IF gReturnCode <> pkconstant.success() THEN
		CALL pkLog.error('ECM701', 'SPIPX055K15R03', 'エラーコード'||gReturnCode);
		CALL pkLog.error('ECM701', 'SPIPX055K15R03', 'エラー内容'||gOutSqlErrM);
		RETURN gReturnCode;
	END IF;
	-- 作票が終了したためワークに挿入したデータをDELETE
	DELETE FROM SREPORT_WK
	WHERE CHOHYO_ID = wkChohyoId;
	-- バッチ帳票印刷管理テーブルにデータを登録する
	IF gMaxSeqNo <> 0 AND gReturnCode = pkconstant.success() THEN
		CALL PKIPACALCTESURYO.insertDataPrtOk(
			inItakuKaishaCd  => l_initakukaishacd,
			inKijunYmd       => gGyomuYmd,
			inListSakuseiKbn => '1',
			inChohyoId       => gREPORT_ID
		);
	END IF;
	RETURN pkconstant.success();
--=========< エラー処理 >==========================================================
 EXCEPTION
	WHEN OTHERS THEN
	--カーソルが開いていたら閉じておく
		BEGIN
			CLOSE gCur;
		EXCEPTION
			WHEN OTHERS THEN NULL;
		END;
		CALL pkLog.fatal('ECM701', 'SFIPX055K15R03_01', 'エラーコード'||SQLSTATE);
		CALL pkLog.fatal('ECM701', 'SFIPX055K15R03_01', 'エラー内容'||SQLERRM);
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipx055k15r03_01 ( l_initakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE , l_inBankRnm VJIKO_ITAKU.BANK_RNM%TYPE ) FROM PUBLIC;