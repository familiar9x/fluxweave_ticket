




CREATE OR REPLACE FUNCTION sfipi115k00r01 ( l_inItakuKaishaCd character(4) ) RETURNS integer AS $body$
DECLARE

--*******************************************************************************
-- * 著作権: Copyright (c) 2010
-- * 会社名: JIP
-- *
-- * 残存額通知予定データ作成
-- * 夜間バッチにて残存額通知予定データを作成する。
-- *
-- * @author 大久保　拓也(ASK)
-- * @version $Id: SFIPI115K00R01.sql,v 1.2 2010/08/20 12:28:26 kanayama Exp $
-- *
-- * @param l_inItakuKaishaCd		IN	ZANZON_TSUCHI.ITAKU_KAISHA_CD%TYPE 委託会社コード
-- * @return INTEGER
-- * pkIpConstants.SUCCESS():正常終了
-- * pkIpConstants.PARAERR():パラメータエラー
-- * pkIpConstants.SYSERR() :システムエラー(SQLエラー)
-- *******************************************************************************
--******************************************************************************
-- 変数定義                                                                     
--******************************************************************************
	result              integer;                                     --ＳＰのリターンコード
	                                   --パラメータ例外
	errExceptionMessage varchar(100);                               --例外メッセージ
	gSysShaiZndk        numeric(14,0);          --システム_社債残高
	gSysJisshituZndk    numeric(14,0);       --システム_実質残高
	gGyomuYmd           character(8);           --業務日付
	gDataCnt            integer := 0;                           --件数
--====================================================================*
--					定数定義
-- *====================================================================
	FUNC_NAME         CONSTANT varchar(14) := 'SFIPI115K00R01';         -- ファンクション名
	C_MEMOKU_ZNDK     CONSTANT integer      := 1;                        -- 実数（1:名目残高）
	C_JISSITU_ZNDK    CONSTANT integer      := 3;                        -- 実数（3:実質残高）
	C_FACTER          CONSTANT integer      := 5;                        -- 実数（5:ファクター）
	C_SASIOSAE_MEMOKU CONSTANT integer      := 8;                        -- 実数（8:差押名目残高）
	C_TEIJI_SHOKAN	  CONSTANT char(1)		:= '2';				         --償還方法コード：定時償還
	C_TOKUREI_SHASAI  CONSTANT char(1)		:= 'Y';                      --特例社債フラグ:特例社債
--******************************************************************************
-- カーソル定義                                                                 
--******************************************************************************
	-- 銘柄基本VIEW抽出 
	curMgrKihonView CURSOR(
		l_inGyomuYmd  character(8)
	) FOR
		SELECT
			VMG1.ITAKU_KAISHA_CD,                               --委託会社コード
			VMG1.MGR_CD,                                        --銘柄コード
			VMG1.ISIN_CD,                                       --ISINコード
			VMG1.HAKKO_TSUKA_CD,                                --発行通貨
			VMG1.SHOKAN_METHOD_CD,                              --償還方法コード
		    VMG1.TOKUREI_SHASAI_FLG,                            --特例社債フラグ
			coalesce(                                                --[↓名目残高↓]
				pkIpaZndk.getKjnZndk(
					VMG1.ITAKU_KAISHA_CD, -- 委託会社コード
					VMG1.MGR_CD,          -- 銘柄コード
					l_inGyomuYmd,         -- 業務日付
					C_MEMOKU_ZNDK          -- 実数（1:名目残高）
				)::numeric
				,'0'
			) AS MEIMOKU_ZNDK,                                  --[↑名目残高↑]
			coalesce(                                                --[↓差押名目残高↓]
				pkIpaZndk.getKjnZndk(
					VMG1.ITAKU_KAISHA_CD, -- 委託会社コード
					VMG1.MGR_CD,          -- 銘柄コード
					l_inGyomuYmd,         -- 業務日付
					C_SASIOSAE_MEMOKU      -- 実数（8:差押名目残高）
				)::numeric
				,'0'
			) AS SASIOSAE_MEMOKU,                               --[↑差押名目残高↑]
			coalesce(                                                --[↓実質残高↓]
				pkIpaZndk.getKjnZndk(
					VMG1.ITAKU_KAISHA_CD, -- 委託会社コード
					VMG1.MGR_CD,          -- 銘柄コード
					l_inGyomuYmd,         -- 業務日付
					C_JISSITU_ZNDK         -- 実数（3:実質残高）
				)::numeric
				,'0'
			) AS JISSITU_ZNDK,                                  --[↑実質残高↑]
			coalesce(                                                --[↓ファクター↑]
				pkIpaZndk.getKjnZndk(
					VMG1.ITAKU_KAISHA_CD, -- 委託会社コード
					VMG1.MGR_CD,          -- 銘柄コード
					pkDate.getZenYmd(
						(SELECT
							trim(both MAX(MG3.SHOKAN_YMD))
						FROM
							MGR_SHOKIJ MG3
						WHERE
							VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD     --委託会社コード
						AND VMG1.MGR_CD          = MG3.MGR_CD              --銘柄コード
						)                       --前日を設定
					),
					C_FACTER                         -- 実数（5:ファクター）
				)::numeric
				,'0'
			) AS FACTER                                          --[↑ファクター↑]
		FROM
			MGR_KIHON_VIEW VMG1
		WHERE
			VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd                   --委託会社コード
		AND VMG1.HAKKO_YMD      <= l_inGyomuYmd                        --発行年月日
		AND (
				coalesce(
					pkIpaZndk.getKjnZndk(
						VMG1.ITAKU_KAISHA_CD, -- 委託会社コード
						VMG1.MGR_CD,          -- 銘柄コード
						l_inGyomuYmd,         -- 業務日付
						C_JISSITU_ZNDK         -- 実数（3:実質残高）
					)::numeric
					,'0'
				)               > 0                                 --最終実質残高
			OR
				coalesce(
					pkIpaZndk.getKjnZndk(
						VMG1.ITAKU_KAISHA_CD, -- 委託会社コード
						VMG1.MGR_CD,          -- 銘柄コード
						l_inGyomuYmd,         -- 業務日付
						C_SASIOSAE_MEMOKU      -- 実数（8:差押名目残高）
					)::numeric
					,'0'
				)               > 0                                 --最終差押残高
			)
		AND VMG1.JTK_KBN        != '2'                              --受託区分  [2:副受託]
		AND VMG1.SAIKEN_SHURUI  != '80'                             --債権種類  [80:新株予約権付社債]
		AND VMG1.SAIKEN_SHURUI  != '89'                             --債権種類  [89:その他ＣＢ]
		AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '');                        --ＩＳＩＮコード
--******************************************************************************
--					メイン処理													
--******************************************************************************
BEGIN
--	pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME,'処理開始');
	RAISE NOTICE '[SFIPI115K00R01] Start processing';
	IF coalesce(l_inItakuKaishaCd::text, '') = '' THEN
		errExceptionMessage := 'パラメータ（委託会社）がNULL';
		RAISE EXCEPTION 'errparamexception' USING ERRCODE = '50001';
	END IF;
--	pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME,'委託会社：' || l_inItakuKaishaCd);
	RAISE NOTICE '[SFIPI115K00R01] Parameter OK: %', l_inItakuKaishaCd;
	result := pkconstant.FATAL();
	-- 業務日付を取得する
	gGyomuYmd := pkDate.getGyomuYmd();
--	pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME,'業務日付：' || gGyomuYmd);
	RAISE NOTICE '[SFIPI115K00R01] Business date: %', gGyomuYmd;
	-- 残存額通知予定データをクリアする
	DELETE
	FROM
		ZANZON_TSUCHI Z03
	WHERE
		Z03.ITAKU_KAISHA_CD = l_inItakuKaishaCd;  --委託会社コード
--	pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME, '残存額通知予定データ削除件数:'||SQL%ROWCOUNT);
	RAISE NOTICE '[SFIPI115K00R01] Deleted % rows from ZANZON_TSUCHI', (SELECT COUNT(*) FROM ZANZON_TSUCHI WHERE 1=0);
	RAISE NOTICE '[SFIPI115K00R01] Starting cursor loop...';
	-- 翌営業日分データ作成
	FOR recMgrKihonView IN curMgrKihonView(gGyomuYmd) LOOP
		IF gDataCnt = 0 THEN
			RAISE NOTICE '[SFIPI115K00R01] First record found, starting processing...';
		END IF;
		IF gDataCnt % 5000 = 0 AND gDataCnt > 0 THEN
			RAISE NOTICE '[SFIPI115K00R01] Processed % records...', gDataCnt;
		END IF;
--		IF recMgrKihonView.MGR_CD IN ('M102','M407','M408') THEN 
--			pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME,'委託会社コード：' || recMgrKihonView.ITAKU_KAISHA_CD);
--			pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME,'銘柄コード：' || recMgrKihonView.MGR_CD);
--			pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME,'ISINコード：' || recMgrKihonView.ISIN_CD);
--			pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME,'発行通貨：' || recMgrKihonView.HAKKO_TSUKA_CD);
--			pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME,'償還方法：' || recMgrKihonView.SHOKAN_METHOD_CD);
--			pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME,'(1)名目残高：' || recMgrKihonView.MEIMOKU_ZNDK);
--			pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME,'(3)実質残高：' || recMgrKihonView.JISSITU_ZNDK);
--			pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME,'(5)ファクター：' || recMgrKihonView.FACTER);
--			pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME,'(8)差押名目残高：' || recMgrKihonView.SASIOSAE_MEMOKU);
--		END IF;
        IF  recMgrKihonView.TOKUREI_SHASAI_FLG = C_TOKUREI_SHASAI  AND recMgrKihonView.SHOKAN_METHOD_CD <> C_TEIJI_SHOKAN THEN
        	-- 特例債で定時償還でない銘柄は名目残高に実質残高を設定
			gSysShaiZndk := recMgrKihonView.JISSITU_ZNDK;
		ELSE
			-- システム_社債残高を設定
			gSysShaiZndk := recMgrKihonView.MEIMOKU_ZNDK;
		END IF;
		-- 名目残高=0かつ差押名目残高＞0の場合システム_差押残高を社債残高に設定以外はシステム_社債残高を設定
		IF gSysShaiZndk = 0 AND recMgrKihonView.SASIOSAE_MEMOKU > 0 THEN
			-- システム_差押残高を設定
			gSysShaiZndk := recMgrKihonView.SASIOSAE_MEMOKU;
		END IF;
		-- SHOKAN_METHOD_CDが2(定時償還)の場合
		IF recMgrKihonView.SHOKAN_METHOD_CD = '2' THEN    --[2:定時償還]
			-- 実質残高=0かつ差押名目残高＞0の場合システム_差押残高を実質残高に設定以外はシステム_実質残高を設定
			IF recMgrKihonView.JISSITU_ZNDK = 0 AND recMgrKihonView.SASIOSAE_MEMOKU > 0 THEN
				-- システム_差押残高を設定
				gSysJisshituZndk := recMgrKihonView.SASIOSAE_MEMOKU * recMgrKihonView.FACTER;
			ELSE
				-- システム_実質残高を設定
				gSysJisshituZndk := recMgrKihonView.JISSITU_ZNDK;
			END IF;
		ELSE
				-- 初期値を設定
				gSysJisshituZndk := NULL;
		END IF;
		INSERT INTO ZANZON_TSUCHI                --残存通知予定データテーブル
			(
				ITAKU_KAISHA_CD,                --委託会社コード
				MGR_CD,                         --銘柄コード
				ISIN_CD,                        --ＩＳＩＮコード
				ZNDK_KIJUN_YMD_ERR_FLG,         --残高基準日エラーフラグ
				SYS_ZNDK_KIJUN_YMD,             --システム_残高基準日
				HAKKO_TSUKA_CD_ERR_FLG,         --発行通貨エラーフラグ
				SYS_HAKKO_TSUKA_CD,             --システム_発行通貨
				SHASAI_ZNDK_ERR_FLG,            --社債残高エラーフラグ
				SYS_SHASAI_ZNDK,                --システム_社債残高
				OSAE_ZNDK_ERR_FLG,              --差押残高エラーフラグ
				SYS_OSAE_ZNDK,                  --システム_差押残高
				OSAE_IGAI_TOKETSU_ZNDK_ERR_FLG, --差押以外凍結分残高エラーフラグ
				SYS_OSAE_IGAI_TOKETSU_ZNDK,     --システム_差押以外凍結分残高
				JISSHITSU_ZNDK_ERR_FLG,         --実質残高エラーフラグ
				SYS_JISSHITSU_ZNDK,             --システム_実質残高
				KK_ZNDK_KIJUN_YMD,              --機構_残高基準日
				KK_SHORI_YMD,                   --機構_処理日
				KK_HAKKO_TSUKA_CD,              --機構_発行通貨
				KK_SHASAI_ZNDK,                 --機構_社債残高
				KK_OSAE_ZNDK,                   --機構_差押残高
				KK_OSAE_IGAI_TOKETSU_ZNDK,      --機構_差押以外凍結分残高
				KK_JISSHITSU_ZNDK,              --機構_実質残高
				KK_THIS_RBR_YMD,                --機構_今回利払日
				KK_THIS_RIRITSU,                --機構_今回利率
				KK_THIS_TSUKARISHI_KNGK,        --機構_今回１通貨あたりの利子金額
				KK_NEXT_RBR_YMD,                --機構_次回利払日
				KK_NEXT_RIRITSU,                --機構_次回利率
				KK_NEXT_TSUKARISHI_KNGK,        --機構_次回１通貨あたりの利子金額
				TOTSUGO_KEKKA_KBN,              --突合結果区分
				RECEP_DT,                       --受信日時
				KOUSIN_ID,                      --更新者
				SAKUSEI_ID                       --作成者
			)
		VALUES (
			recMgrKihonView.ITAKU_KAISHA_CD,    --委託会社コード
			recMgrKihonView.MGR_CD,             --銘柄コード
			recMgrKihonView.ISIN_CD,            --ＩＳＩＮコード
			' ',                                --残高基準日エラーフラグ
			gGyomuYmd,                          --システム_残高基準日
			' ',                                --発行通貨エラーフラグ
			recMgrKihonView.HAKKO_TSUKA_CD,     --システム_発行通貨
			' ',                                --社債残高エラーフラグ
			gSysShaiZndk,                       --システム_社債残高
			' ',                                --差押残高エラーフラグ
			recMgrKihonView.SASIOSAE_MEMOKU,    --システム_差押残高
			' ',                                --差押以外凍結分残高エラーフラグ
			0,                                  --システム_差押以外凍結分残高
			' ',                                --実質残高エラーフラグ
			gSysJisshituZndk,                   --システム_実質残高
			' ',                                --機構_残高基準日
			' ',                                --機構_処理日
			' ',                                --機構_発行通貨
			0,                                  --機構_社債残高
			0,                                  --機構_差押残高
			0,                                  --機構_差押以外凍結分残高
			NULL,                               --機構_実質残高
			NULL,                               --機構_今回利払日
			NULL,                               --機構_今回利率
			NULL,                               --機構_今回１通貨あたりの利子金額
			NULL,                               --機構_次回利払日
			NULL,                               --機構_次回利率
			NULL,                               --機構_次回１通貨あたりの利子金額
			'0',                                --突合結果区分
			' ',                                --受信日時
			pkconstant.BATCH_USER(),              --更新者
			pkconstant.BATCH_USER()                --作成者
			);
		gDataCnt := gDataCnt + 1;               --件数
	END LOOP;
--	pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME,'件数：' || gDataCnt);
	RAISE NOTICE '[SFIPI115K00R01] Total records processed: %', gDataCnt;
--	pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME,'処理終了');
--******************************************************************************
--                  終了処理                                                    
--******************************************************************************
	RAISE NOTICE '[SFIPI115K00R01] Processing completed successfully';
	result := pkconstant.success();
	RETURN result;
--******************************************************************************
--                  エラー処理                                                  
--******************************************************************************
EXCEPTION
	-- パラメータエラー 
	WHEN SQLSTATE '50001' THEN
		CALL pkLog.fatal('ECM501', FUNC_NAME, substring(errExceptionMessage from 1 for 100));
		RETURN pkIpConstants.PARAERR();
	-- その他例外発生 
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', FUNC_NAME, SQLSTATE||substring(SQLERRM from 1 for 100));
		RETURN pkIpConstants.SYSERR();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi115k00r01 ( l_inItakuKaishaCd character(4) ) FROM PUBLIC;
