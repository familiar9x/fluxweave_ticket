




CREATE OR REPLACE FUNCTION sfipp014k00r02_01 ( l_inItakuKaishaCd text  -- 委託会社コード
 ) RETURNS integer AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2007
-- * 会社名:JIP
-- *
-- * 概要　:実質記番号管理償還回次調整情報テーブル作成
-- *
-- * 引数　:l_inItakuKaishaCd :委託会社コード
-- *
-- * 返り値: 0:正常
-- *         2:対象データなし
-- *        99:異常
-- *
-- * @author ASK
-- * @version $Id: SFIPP014K00R02_01.sql,v 1.5 2009/06/04 08:22:37 kentaro_ikeda Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2007.07.03 中村        新規作成
-- ***************************************************************************
--
	--==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_FUNCTION_ID CONSTANT varchar(50) := 'SFIPP014K00R02_01'; -- ファンクションＩＤ
	C_NO_DATA     CONSTANT numeric(1)    := 2;                   -- 対象データなし
	BILLOUT_KYUJITSU_KBN CONSTANT CHAR := pkconstant.HORIDAY_SHORI_KBN_ZENEI(); -- IP-05977
	BILLOUT_AREA_CD CONSTANT CHAR := pkconstant.TOKYO_AREA_CD(); -- IP-05977
	
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	gAreaCd           varchar(100);                     -- 地域コード
	gShokanYmd        char(8);        -- 償還日
	gHenkoRiyuCd      char(2); -- 変更理由コード
	gKknChokyuKjt     char(8);    -- 基金徴求期日
	gKknChokyuYmd     char(8);    -- 基金徴求日
	gTesuChokyuKjt    char(8);   -- 手数料徴求期日
	gTesuChokyuYmd    char(8);   -- 手数料徴求日
	gKknbillOutYmd    char(8);   -- 基金請求書出力日
	gTtesubillOutYmd  char(8);  -- 手数料請求書出力日
	gCount            numeric;                            -- レコードカウント
	gGyomuYmd         char(8);                           -- 業務年月の１日
	gFYmd             char(8);                           -- 業務年月の１日のnヵ月後
	gVal              varchar(100);       -- 処理制御マスタのリターン値
	gNum              integer;                           -- 期日補正対象月後
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	curMeisai CURSOR FOR
		SELECT
			P01.MGR_CD,                                                     -- 銘柄コード
			P01.SHOKAN_KJT,                                                 -- 償還期日
			P01.SHOKAN_YMD,                                                 -- 償還日
			P01.KBG_SHOKAN_KBN,                                             -- 償還区分（実質記番号用）
			P01.KKN_CHOKYU_KJT,                                             -- 基金徴求期日
			P01.KKN_CHOKYU_YMD,                                             -- 基金徴求日
			P01.TESU_CHOKYU_KJT,                                            -- 手数料徴求期日
			P01.TESU_CHOKYU_YMD,                                            -- 手数料徴求日
			P01.KKNBILL_OUT_YMD,                                            -- 基金請求書出力日
			P01.TESUBILL_OUT_YMD,                                           -- 手数料請求書出力日
			VMG1.KYUJITSU_KBN,                                              -- 休日処理区分
			VMG1.KYUJITSU_LD_FLG,                                           -- 休日処理ロンドン参照フラグ
			VMG1.KYUJITSU_NY_FLG,                                           -- 休日処理ニューヨーク参照フラグ
			VMG1.KYUJITSU_ETC_FLG,                                          -- 休日処理その他海外参照フラグ
			VMG1.ISIN_CD,                                                   -- ＩＳＩＮコード
			VMG1.KKN_CHOKYU_TMG1,                                           -- 基金徴求タイミング１
			VMG1.KKN_CHOKYU_TMG2,                                           -- 基金徴求タイミング２
			VMG1.KKN_CHOKYU_DD,                                             -- 基金徴求タイミング日数
			VMG1.KKN_CHOKYU_KYUJITSU_KBN,                                   -- 基金徴求休日処理区分
			VMG1.KOBETSUSEIKYUOUT_KBN,                                      -- 個別請求書出力区分
			VMG1.KKNBILL_OUT_TMG1,                                          -- 基金請求書出力タイミング１
			VMG1.KKNBILL_OUT_TMG2,                                          -- 基金請求書出力タイミング２
			VMG1.KKNBILL_OUT_DD,                                            -- 基金請求書出力タイミング日数
			MG8.GNKN_SHR_TESU_CHOKYU_TMG1,                                  -- 元金支払手数料徴求タイミング１
			MG8.GNKN_SHR_TESU_CHOKYU_TMG2,                                  -- 元金支払手数料徴求タイミング２
			coalesce(MG8.GNKN_SHR_TESU_CHOKYU_DD, 0) AS GNKN_SHR_TESU_CHOKYU_DD, -- 元金支払手数料徴求タイミング日数
			MG7.BILL_OUT_TMG1,                                              -- 請求書出力タイミング１
			MG7.BILL_OUT_TMG2,                                              -- 請求書出力タイミング２
			coalesce(MG7.BILL_OUT_DD, 0) AS BILL_OUT_DD                           -- 請求書出力タイミング日数
		FROM mgr_kihon_view vmg1, kbg_shokij p01
LEFT OUTER JOIN mgr_tesuryo_prm mg8 ON (P01.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD AND P01.MGR_CD = MG8.MGR_CD)
LEFT OUTER JOIN (
				SELECT
					ITAKU_KAISHA_CD,
					MGR_CD,
					BILL_OUT_TMG1,
					BILL_OUT_TMG2,
					BILL_OUT_DD
				FROM
					MGR_TESURYO_CTL
				WHERE
					ITAKU_KAISHA_CD = l_inItakuKaishaCd
					AND TESU_SHURUI_CD = '81'
					AND KOBETSUSEIKYUOUT_KBN = '1'
			) mg7 ON (P01.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD AND P01.MGR_CD = MG7.MGR_CD)
WHERE P01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD AND P01.MGR_CD = VMG1.MGR_CD     AND P01.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND P01.SHOKAN_KJT >= gGyomuYmd AND VMG1.MGR_STAT_KBN = '1' ORDER BY
			P01.MGR_CD,
			P01.SHOKAN_KJT,
			P01.KBG_SHOKAN_KBN;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- カレンダー訂正履歴チェック
	SELECT
		COUNT(*)
	INTO STRICT
		gCount
	FROM MCALENDAR_TEISEI
	WHERE
		ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND MGR_KJT_CHOSEI_KBN = '1';
	-- 「未承認:1」が存在しない場合
	IF gCount = 0 THEN
--		pkLog.debug(pkconstant.BATCH_USER(), C_FUNCTION_ID, 'カレンダー訂正履歴に「未承認:1」が存在しない');
		RETURN C_NO_DATA;
	END IF;
	-- 「業務年月の１日」取得
	gGyomuYmd := SUBSTRING(pkDate.getGyomuYmd() FROM 1 FOR 6) || '01';
--	pkLog.debug(pkconstant.BATCH_USER(), C_FUNCTION_ID, '業務年月の１日:"' || gGyomuYmd || '"');
	-- MPROCESS_CTLからカレンダー補正のデータを取得
	gVal := pkcontrol.getCtlValue(l_inItakuKaishaCd, 'CALENDARHOSEI', '4');
	-- 数値チェック
	gNum := sfCmToNumeric(gVal);
	IF coalesce(gNum::text, '') = '' THEN
		-- エラーの場合は４ヶ月後を設定
		gNum := 4;
		gFYmd := pkDate.calcMonth(gGyomuYmd, gNum);
	ELSIF gNum = 0 THEN
		-- 0の場合は、業務日付の翌営業日を設定
		gFYmd := pkDate.getYokuBusinessYmd(pkDate.getGyomuYmd());
	ELSE
		-- 「業務年月の１日のnヵ月後」取得
		gFYmd := pkDate.calcMonth(gGyomuYmd, gNum);
	END IF;
--	pkLog.debug(pkconstant.BATCH_USER(), C_FUNCTION_ID, '業務年月の１日のnヵ月後:"' || gFYmd || '"');
	-- 実質記番号管理償還回次調整情報テーブル削除
	DELETE FROM
		MOD_KBG_SHOKIJ
	WHERE
		ITAKU_KAISHA_CD = l_inItakuKaishaCd;
	FOR recMeisai IN curMeisai
	LOOP
		-- 地域コード設定
		-- 償還区分(記番号)が'62','63'のときは地域コードを'1'とする。
		IF recMeisai.KBG_SHOKAN_KBN IN ('62','63') THEN
			gAreaCd := '1';
		ELSE
			gAreaCd := pkDate.getAreaCd(
										recMeisai.KYUJITSU_LD_FLG, -- 休日処理ロンドン参照フラグ
										recMeisai.KYUJITSU_NY_FLG, -- 休日処理ニューヨーク参照フラグ
										recMeisai.KYUJITSU_ETC_FLG  -- 休日処理その他海外参照フラグ
										);
		END IF;
		-- ■償還日---------------------------------------------------------------------------------------------------■
		-- 償還日の算出
		gShokanYmd := pkDate.calcDateKyujitsuKbn(
											recMeisai.SHOKAN_KJT,   -- 償還期日
											0,                      -- 日数
											recMeisai.KYUJITSU_KBN, -- 休日処理区分
											gAreaCd                  -- 地域コード
											);
		-- 償還日に変更がない場合
		IF gShokanYmd = recMeisai.SHOKAN_YMD THEN
			-- 変更理由コード（休日補正）
			gHenkoRiyuCd := '01';
		ELSE
			-- 実質記番号管理償還回次調整情報テーブル登録
			IF (trim(both recMeisai.SHOKAN_YMD) IS NOT NULL AND (trim(both recMeisai.SHOKAN_YMD))::text <> '') THEN
				CALL SFIPP014K00R02_01_insertData(
							l_inItakuKaishaCd,        -- 委託会社コード
							recMeisai.MGR_CD,         -- 銘柄コード
							recMeisai.ISIN_CD,        -- ＩＳＩＮコード
							recMeisai.SHOKAN_KJT,     -- 償還期日
							recMeisai.KBG_SHOKAN_KBN, -- 償還区分（実質記番号用）
							'21',                     -- 日付種類コード
							recMeisai.SHOKAN_YMD,     -- 変更前年月日
							gShokanYmd,               -- 変更後年月日
							'01',                     -- 変更理由コード
							gFYmd                     -- 業務年月の１日のnヵ月後
							);
			END IF;
			-- 変更理由コード（償還日補正）
			gHenkoRiyuCd := '03';
		END IF;
		-- ■---------------------------------------------------------------------------------------------------------■
		-- ■基金徴求期日・基金徴求日---------------------------------------------------------------------------------■
		-- 基金徴求タイミングが設定されている場合
		IF ((trim(both recMeisai.KKN_CHOKYU_TMG1) IS NOT NULL AND (trim(both recMeisai.KKN_CHOKYU_TMG1))::text <> '')) THEN
			-- 基金徴求期日の算出
			gKknChokyuKjt := sfCalcTmgYmdKjt(
											recMeisai.SHOKAN_KJT,      -- 償還期日
											gShokanYmd,                -- 償還日
											recMeisai.KKN_CHOKYU_TMG1, -- 基金徴求タイミング１
											recMeisai.KKN_CHOKYU_DD,   -- 基金徴求タイミング日数
											recMeisai.KKN_CHOKYU_TMG2, -- 基金徴求タイミング２
											gAreaCd                     -- 地域コード
											);
			-- 基金徴求期日に変更がある場合
			IF (trim(both recMeisai.KKN_CHOKYU_KJT) IS NOT NULL AND (trim(both recMeisai.KKN_CHOKYU_KJT))::text <> '') AND gKknChokyuKjt <> recMeisai.KKN_CHOKYU_KJT THEN
				-- 実質記番号管理償還回次調整情報テーブル登録
				CALL SFIPP014K00R02_01_insertData(
							l_inItakuKaishaCd,        -- 委託会社コード
							recMeisai.MGR_CD,         -- 銘柄コード
							recMeisai.ISIN_CD,        -- ＩＳＩＮコード
							recMeisai.SHOKAN_KJT,     -- 償還期日
							recMeisai.KBG_SHOKAN_KBN, -- 償還区分（実質記番号用）
							'22',                     -- 日付種類コード
							recMeisai.KKN_CHOKYU_KJT, -- 変更前年月日
							gKknChokyuKjt,            -- 変更後年月日
							gHenkoRiyuCd,              -- 変更理由コード
							gFYmd                     -- 業務年月の１日のnヵ月後
							);
			END IF;
			-- 基金徴求休日処理区分が設定されている場合
			IF ((trim(both recMeisai.KKN_CHOKYU_KYUJITSU_KBN) IS NOT NULL AND (trim(both recMeisai.KKN_CHOKYU_KYUJITSU_KBN))::text <> '')) THEN
				-- 基金徴求日の算出
				gKknChokyuYmd := pkDate.calcDateKyujitsuKbn(
															gKknChokyuKjt,                     -- 基金徴求期日
															0,                                 -- 日数
															recMeisai.KKN_CHOKYU_KYUJITSU_KBN, -- 休日処理区分
															gAreaCd                             -- 地域コード
															);
				-- 基金徴求日に変更がある場合
				IF (trim(both recMeisai.KKN_CHOKYU_YMD) IS NOT NULL AND (trim(both recMeisai.KKN_CHOKYU_YMD))::text <> '') AND gKknChokyuYmd <> recMeisai.KKN_CHOKYU_YMD THEN
					-- 実質記番号管理償還回次調整情報テーブル登録
					CALL SFIPP014K00R02_01_insertData(
								l_inItakuKaishaCd,        -- 委託会社コード
								recMeisai.MGR_CD,         -- 銘柄コード
								recMeisai.ISIN_CD,        -- ＩＳＩＮコード
								recMeisai.SHOKAN_KJT,     -- 償還期日
								recMeisai.KBG_SHOKAN_KBN, -- 償還区分（実質記番号用）
								'23',                     -- 日付種類コード
								recMeisai.KKN_CHOKYU_YMD, -- 変更前年月日
								gKknChokyuYmd,            -- 変更後年月日
								gHenkoRiyuCd,              -- 変更理由コード
								gFYmd                     -- 業務年月の１日のnヵ月後
								);
				END IF;
			END IF;
		END IF;
		-- ■---------------------------------------------------------------------------------------------------------■
		-- ■手数料徴求期日・手数料徴求日-----------------------------------------------------------------------------■
		-- 手数料徴求タイミングが設定されている場合
		IF ((trim(both recMeisai.GNKN_SHR_TESU_CHOKYU_TMG1) IS NOT NULL AND (trim(both recMeisai.GNKN_SHR_TESU_CHOKYU_TMG1))::text <> '')) THEN
			-- 手数料徴求期日の算出
			gTesuChokyuKjt := sfCalcTmgYmdKjt(
											recMeisai.SHOKAN_KJT,                -- 償還期日
											gShokanYmd,                          -- 償還日
											recMeisai.GNKN_SHR_TESU_CHOKYU_TMG1, -- 手数料徴求タイミング１
											recMeisai.GNKN_SHR_TESU_CHOKYU_DD,   -- 手数料徴求タイミング日数
											recMeisai.GNKN_SHR_TESU_CHOKYU_TMG2, -- 手数料徴求タイミング２
											gAreaCd                               -- 地域コード
											);
			-- 手数料徴求期日に変更がある場合
			IF (trim(both recMeisai.TESU_CHOKYU_KJT) IS NOT NULL AND (trim(both recMeisai.TESU_CHOKYU_KJT))::text <> '') AND gTesuChokyuKjt <> recMeisai.TESU_CHOKYU_KJT THEN
				-- 実質記番号管理償還回次調整情報テーブル登録
				CALL SFIPP014K00R02_01_insertData(
							l_inItakuKaishaCd,         -- 委託会社コード
							recMeisai.MGR_CD,          -- 銘柄コード
							recMeisai.ISIN_CD,         -- ＩＳＩＮコード
							recMeisai.SHOKAN_KJT,      -- 償還期日
							recMeisai.KBG_SHOKAN_KBN,  -- 償還区分（実質記番号用）
							'24',                      -- 日付種類コード
							recMeisai.TESU_CHOKYU_KJT, -- 変更前年月日
							gTesuChokyuKjt,            -- 変更後年月日
							gHenkoRiyuCd,               -- 変更理由コード
							gFYmd                      -- 業務年月の１日のnヵ月後
							);
			END IF;
			-- 基金徴求休日処理区分が設定されている場合
			IF ((trim(both recMeisai.KKN_CHOKYU_KYUJITSU_KBN) IS NOT NULL AND (trim(both recMeisai.KKN_CHOKYU_KYUJITSU_KBN))::text <> '')) THEN
				-- 手数料徴求日の算出
				gTesuChokyuYmd := pkDate.calcDateKyujitsuKbn(
															gTesuChokyuKjt,                    -- 手数料徴求期日
															0,                                 -- 日数
															recMeisai.KKN_CHOKYU_KYUJITSU_KBN, -- 休日処理区分
															gAreaCd                             -- 地域コード
															);
				-- 手数料徴求日に変更がある場合
				IF (trim(both recMeisai.TESU_CHOKYU_YMD) IS NOT NULL AND (trim(both recMeisai.TESU_CHOKYU_YMD))::text <> '') AND gTesuChokyuYmd <> recMeisai.TESU_CHOKYU_YMD THEN
					-- 実質記番号管理償還回次調整情報テーブル登録
					CALL SFIPP014K00R02_01_insertData(
								l_inItakuKaishaCd,         -- 委託会社コード
								recMeisai.MGR_CD,          -- 銘柄コード
								recMeisai.ISIN_CD,         -- ＩＳＩＮコード
								recMeisai.SHOKAN_KJT,      -- 償還期日
								recMeisai.KBG_SHOKAN_KBN,  -- 償還区分（実質記番号用）
								'25',                      -- 日付種類コード
								recMeisai.TESU_CHOKYU_YMD, -- 変更前年月日
								gTesuChokyuYmd,            -- 変更後年月日
								gHenkoRiyuCd,               -- 変更理由コード
								gFYmd                      -- 業務年月の１日のnヵ月後
								);
				END IF;
			END IF;
		END IF;
		-- ■---------------------------------------------------------------------------------------------------------■
		-- ■基金請求書出力日・手数料請求書出力日---------------------------------------------------------------------■
		-- 基金徴求休日処理区分が設定されている場合
		IF ((trim(both recMeisai.KKN_CHOKYU_KYUJITSU_KBN) IS NOT NULL AND (trim(both recMeisai.KKN_CHOKYU_KYUJITSU_KBN))::text <> '')) THEN
			-- 請求書出力タイミングが設定されている場合
			IF (recMeisai.KOBETSUSEIKYUOUT_KBN = '1') AND ((trim(both recMeisai.KKNBILL_OUT_TMG1) IS NOT NULL AND (trim(both recMeisai.KKNBILL_OUT_TMG1))::text <> '')) AND ((trim(both recMeisai.KKNBILL_OUT_TMG2) IS NOT NULL AND (trim(both recMeisai.KKNBILL_OUT_TMG2))::text <> '')) THEN
				-- 基金請求書出力日の算出
				gKknbillOutYmd := sfCalcTmgYmd(
											recMeisai.SHOKAN_KJT,              -- 償還期日
											gShokanYmd,                        -- 償還日
											recMeisai.KKNBILL_OUT_TMG1,        -- 基金請求書出力タイミング１
											recMeisai.KKNBILL_OUT_DD,          -- 基金請求書出力タイミング日数
											recMeisai.KKNBILL_OUT_TMG2,        -- 基金請求書出力タイミング２
											BILLOUT_KYUJITSU_KBN,              -- 休日処理区分 IP-05977
											BILLOUT_AREA_CD                     -- 地域コード IP-05977
											);
				-- 基金請求書出力日に変更がある場合
				IF (trim(both recMeisai.KKNBILL_OUT_YMD) IS NOT NULL AND (trim(both recMeisai.KKNBILL_OUT_YMD))::text <> '') AND gKknbillOutYmd <> recMeisai.KKNBILL_OUT_YMD THEN
					-- 実質記番号管理償還回次調整情報テーブル登録
					CALL SFIPP014K00R02_01_insertData(
								l_inItakuKaishaCd,         -- 委託会社コード
								recMeisai.MGR_CD,          -- 銘柄コード
								recMeisai.ISIN_CD,         -- ＩＳＩＮコード
								recMeisai.SHOKAN_KJT,      -- 償還期日
								recMeisai.KBG_SHOKAN_KBN,  -- 償還区分（実質記番号用）
								'26',                      -- 日付種類コード
								recMeisai.KKNBILL_OUT_YMD, -- 変更前年月日
								gKknbillOutYmd,            -- 変更後年月日
								gHenkoRiyuCd,               -- 変更理由コード
								gFYmd                      -- 業務年月の１日のnヵ月後
								);
				END IF;
			END IF;
			-- 手数料請求書出力タイミングが設定されている場合
			IF ((trim(both recMeisai.BILL_OUT_TMG1) IS NOT NULL AND (trim(both recMeisai.BILL_OUT_TMG1))::text <> '')) AND ((trim(both recMeisai.BILL_OUT_TMG2) IS NOT NULL AND (trim(both recMeisai.BILL_OUT_TMG2))::text <> '')) THEN
				-- 手数料請求書出力日の算出
				gTtesubillOutYmd := sfCalcTmgYmd(
											recMeisai.SHOKAN_KJT,              -- 償還期日
											gShokanYmd,                        -- 償還日
											recMeisai.BILL_OUT_TMG1,           -- 請求書出力タイミング１
											recMeisai.BILL_OUT_DD,             -- 請求書出力タイミング日数
											recMeisai.BILL_OUT_TMG2,           -- 請求書出力タイミング２
											BILLOUT_KYUJITSU_KBN,              -- 休日処理区分 IP-05977
											BILLOUT_AREA_CD                     -- 地域コード IP-05977
											);
				-- 手数料請求書出力日に変更がある場合
				IF (trim(both recMeisai.TESUBILL_OUT_YMD) IS NOT NULL AND (trim(both recMeisai.TESUBILL_OUT_YMD))::text <> '') AND gTtesubillOutYmd <> recMeisai.TESUBILL_OUT_YMD THEN
					-- 実質記番号管理償還回次調整情報テーブル登録
					CALL SFIPP014K00R02_01_insertData(
								l_inItakuKaishaCd,          -- 委託会社コード
								recMeisai.MGR_CD,           -- 銘柄コード
								recMeisai.ISIN_CD,          -- ＩＳＩＮコード
								recMeisai.SHOKAN_KJT,       -- 償還期日
								recMeisai.KBG_SHOKAN_KBN,   -- 償還区分（実質記番号用）
								'27',                       -- 日付種類コード
								recMeisai.TESUBILL_OUT_YMD, -- 変更前年月日
								gTtesubillOutYmd,           -- 変更後年月日
								gHenkoRiyuCd,                -- 変更理由コード
								gFYmd                       -- 業務年月の１日のnヵ月後
								);
				END IF;
			END IF;
		END IF;
		-- ■---------------------------------------------------------------------------------------------------------■
	END LOOP;
	-- 終了処理
	RETURN pkconstant.success();
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SUBSTRING(C_FUNCTION_ID FROM 1 FOR 12), 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', SUBSTRING(C_FUNCTION_ID FROM 1 FOR 12), 'SQLERRM:' || SQLERRM);
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipp014k00r02_01 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE  ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfipp014k00r02_01_insertdata ( l_inItakuKaishaCd text, l_inMgrCd varchar(50), l_inIsinCd varchar(12), l_inShokanKjt char(8), l_inKbgShokanKbn char(2), l_inDateShuruiCd char(2), l_inHenkoBefYmd char(8), l_inHenkoAftYmd char(8), l_inHenkoRiyuCd char(2), l_inFYmd char(8) ) AS $body$
BEGIN
	-- 「変更前年月日」が「業務年月の１日のnヵ月後」以上の時
	IF l_inHenkoBefYmd >= l_inFYmd THEN
		-- 実質記番号管理償還回次調整情報テーブル登録
		INSERT INTO MOD_KBG_SHOKIJ(
			ITAKU_KAISHA_CD, -- 委託会社コード
			MGR_CD,          -- 銘柄コード
			ISIN_CD,         -- ＩＳＩＮコード
			SHOKAN_KJT,      -- 償還期日
			KBG_SHOKAN_KBN,  -- 償還区分（実質記番号用）
			DATE_SHURUI_CD,  -- 日付種類コード
			HENKO_BEF_YMD,   -- 変更前年月日
			HENKO_AFT_YMD,   -- 変更後年月日
			HENKO_RIYU_CD,   -- 変更理由コード
			GROUP_ID,        -- グループＩＤ
			SHORI_KBN,       -- 処理区分
			LAST_TEISEI_DT,  -- 最終訂正日時
			LAST_TEISEI_ID,  -- 最終訂正者
			SHONIN_DT,       -- 承認日時
			SHONIN_ID,       -- 承認者
			KOUSIN_ID,       -- 更新者
			SAKUSEI_ID        -- 作成者
		) VALUES (
			l_inItakuKaishaCd,
			l_inMgrCd,
			l_inIsinCd,
			l_inShokanKjt,
			l_inKbgShokanKbn,
			l_inDateShuruiCd,
			l_inHenkoBefYmd,
			l_inHenkoAftYmd,
			l_inHenkoRiyuCd,
			'   ',
			'1',
			to_timestamp(pkDate.getCurrentTime(), 'YYYY-MM-DD HH24:MI:SS.US'),
			pkconstant.BATCH_USER(),
			to_timestamp(pkDate.getCurrentTime(), 'YYYY-MM-DD HH24:MI:SS.US'),
			pkconstant.BATCH_USER(),
			pkconstant.BATCH_USER(),
			pkconstant.BATCH_USER()
		);
	END IF;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfipp014k00r02_01_insertdata ( l_inMgrCd MOD_KBG_SHOKIJ.MGR_CD%TYPE, l_inIsinCd MOD_KBG_SHOKIJ.ISIN_CD%TYPE, l_inShokanKjt MOD_KBG_SHOKIJ.SHOKAN_KJT%TYPE, l_inKbgShokanKbn MOD_KBG_SHOKIJ.KBG_SHOKAN_KBN%TYPE, l_inDateShuruiCd MOD_KBG_SHOKIJ.DATE_SHURUI_CD%TYPE, l_inHenkoBefYmd MOD_KBG_SHOKIJ.HENKO_BEF_YMD%TYPE, l_inHenkoAftYmd MOD_KBG_SHOKIJ.HENKO_AFT_YMD%TYPE, l_inHenkoRiyuCd MOD_KBG_SHOKIJ.HENKO_RIYU_CD%TYPE ) FROM PUBLIC;
