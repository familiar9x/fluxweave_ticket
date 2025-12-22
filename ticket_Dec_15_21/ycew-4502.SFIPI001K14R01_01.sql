




CREATE OR REPLACE FUNCTION sfipi001k14r01_01 ( l_inItakuKaishaCd MGR_KIHON_VIEW.ITAKU_KAISHA_CD%TYPE, l_inKijunYmd BD_NYUSHUKIN.TORIHIKI_YMD%TYPE ) RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2013
-- * 会社名: JIP
-- *
-- * 概要：  入金・出金一括処理画面より起動される別段預金・会計登録データの一括作成機能のうち
-- *         発行時に関するデータを作成するプログラム
-- * 
-- * @author	R.Handa
-- * @version	$Id: SFIPI001K14R01_01.sql,v 1.7 2014/08/22 00:46:51 ito Exp $
-- * @param	l_inItakuKaishaCd		委託会社コード 
-- * @param	l_inKijunYmd			基準日
-- * @return	INTEGER
-- *                0:正常終了、データ無し
-- *                1:予期したエラー
-- *               99:予期せぬエラー
-- 
--==============================================================================
--                  定数定義                                                    
--==============================================================================
	C_PRGRAM_ID				CONSTANT text := 'SFIPI001K14R01_01';	-- プログラムＩＤ
	C_SAIBAN_SHURUI			CONSTANT text := 'G';						-- 採番種別（引受金別段登録）
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	gRtnCd					numeric := pkconstant.success();				-- リターンコード
	cTesuryo51ShukkinYmd	char(8) := NULL;							-- 新規記録手数料（種類：51）出金日
	nSashihikiTesuryoKngk	numeric := 0;								-- 差引分手数料額合計
	cKessaiNo				BD_NYUSHUKIN.KESSAI_NO%TYPE := NULL;		-- セットする決済番号
	nKessaiNoEdaNum			numeric := 0;								-- セットする決済番号枝番用の数値
--==============================================================================
--                  カーソル定義                                                
--==============================================================================
	-- 新規募集情報等の取得
	curShinkiboshu CURSOR FOR
		SELECT
			B01.MGR_CD,
			VMG1.SHASAI_TOTAL,
			SUM(B01.YAKUJO_KNGK) AS YAKUJO_KNGK,
			SUM(B01.KESSAI_KNGK) AS KESSAI_KNGK
		FROM mgr_kihon_view vmg1, shinkiboshu b01
LEFT OUTER JOIN shinkikiroku b04 ON (B01.ITAKU_KAISHA_CD = B04.ITAKU_KAISHA_CD AND B01.KESSAI_NO = B04.KESSAI_NO)
WHERE B01.ITAKU_KAISHA_CD = l_inItakuKaishaCd and VMG1.HAKKO_YMD = l_inKijunYmd and VMG1.JTK_KBN <> '2' and VMG1.HAKKO_TSUKA_CD = 'JPY'   and VMG1.ITAKU_KAISHA_CD = B01.ITAKU_KAISHA_CD and VMG1.MGR_CD = B01.MGR_CD and (B01.KK_PHASE = 'H6' and B01.KK_STAT = '04' or
			B04.KK_PHASE = 'H6' and B04.KK_STAT = '04') GROUP BY
			B01.MGR_CD,VMG1.SHASAI_TOTAL
		ORDER BY
			B01.MGR_CD;
	-- 手数料情報の取得
	curTesuryo CURSOR(l_inMgrCd  TESURYO.MGR_CD%TYPE) FOR
		SELECT
			TK.HAKKO_KICHU_FLG,
			T01.TESU_SHURUI_CD,
			MT05.ACCOUNT_CD_UKEIRE,
			T01.JTK_KBN,
			T01.CHOKYU_YMD,
			T01.TESU_SASHIHIKI_KBN,
			CASE
				WHEN T01.DATA_SAKUSEI_KBN = '2' and T01.SHORI_KBN = '1'
					THEN T01.ALL_TESU_KNGK + T01.HOSEI_ALL_TESU_KNGK 		-- データ作成区分:2、処理区分:1の場合、補正手数料額を加算する
				ELSE T01.ALL_TESU_KNGK
			END AS ALL_TESU_KNGK,
			CASE
				WHEN T01.DATA_SAKUSEI_KBN = '2' and T01.SHORI_KBN = '1'
					THEN T01.ALL_TESU_SZEI + T01.HOSEI_ALL_TESU_SZEI 		-- データ作成区分:2、処理区分:1の場合、補正消費税額を加算する
				ELSE T01.ALL_TESU_SZEI
			END AS ALL_TESU_SZEI,
			T01.DATA_SAKUSEI_KBN,
			T01.SHORI_KBN
		FROM
			TESURYO T01,
			TESURYO_KANRI TK,
			MT_TESURYO_KANRI MT05
		WHERE
			T01.ITAKU_KAISHA_CD = l_inItakuKaishaCd and
			T01.MGR_CD = l_inMgrCd and
			T01.ITAKU_KAISHA_CD = TK.ITAKU_KAISHA_CD and
			T01.TESU_SHURUI_CD = TK.TESU_SHURUI_CD and
			T01.TESU_SHURUI_CD <> '31' and
			T01.ITAKU_KAISHA_CD = MT05.ITAKU_KAISHA_CD and
			T01.TESU_SHURUI_CD = MT05.TESU_SHURUI_CD
		ORDER BY
			T01.TESU_SHURUI_CD;
	-- 手数料情報（分配）の取得
	curTesuryoBunpai CURSOR(
		l_inMgrCd			 TESURYO_BUNPAI.MGR_CD%TYPE,
		l_inTesuShuruiCd	 TESURYO_BUNPAI.TESU_SHURUI_CD%TYPE,
		l_inChokyuYmd		 TESURYO_BUNPAI.CHOKYU_YMD%TYPE,
		l_inDataSakuseiKbn	 TESURYO.DATA_SAKUSEI_KBN%TYPE,
		l_inShoriKbn		 TESURYO.SHORI_KBN%TYPE
	) FOR
		SELECT
			FINANCIAL_SECURITIES_KBN,
			BANK_CD,
			CASE
				WHEN l_inDataSakuseiKbn = '2' and l_inShoriKbn = '1'
					THEN DF_TESU_KNGK + HOSEI_DF_TESU_KNGK 					-- データ作成区分:2、処理区分:1の場合、補正手数料額を加算する
				ELSE DF_TESU_KNGK
			END AS DF_TESU_KNGK,
			CASE
				WHEN l_inDataSakuseiKbn = '2' and l_inShoriKbn = '1'
					THEN DF_TESU_SZEI + HOSEI_DF_TESU_SZEI 					-- データ作成区分:2、処理区分:1の場合、補正消費税額を加算する
				ELSE DF_TESU_SZEI
			END AS DF_TESU_SZEI
		FROM
			TESURYO_BUNPAI
		WHERE
			ITAKU_KAISHA_CD = l_inItakuKaishaCd and
			MGR_CD = l_inMgrCd and
			TESU_SHURUI_CD = l_inTesuShuruiCd and
			CHOKYU_YMD = l_inChokyuYmd
		ORDER BY
			FINANCIAL_SECURITIES_KBN,
			BANK_CD;
--==============================================================================
--                  サブルーチン                                                
--==============================================================================
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 入力パラメータの必須チェック
	IF (coalesce(trim(both l_inItakuKaishaCd)::text, '') = '') THEN
		CALL pkLog.error('ECM501', C_PRGRAM_ID, '項目名称：委託会社コード');
		RETURN pkconstant.error();
	END IF;
	IF (coalesce(trim(both l_inKijunYmd)::text, '') = '') THEN
		CALL pkLog.error('ECM501', C_PRGRAM_ID, '項目名称：基準日');
		RETURN pkconstant.error();
	END IF;
	-- 新規記録手数料出金日の算出 （翌月20日※前営業日補正）
	cTesuryo51ShukkinYmd := pkDate.calcDateKyujitsuKbn(
							SUBSTR(pkDate.calcMonth(l_inKijunYmd,1),1,6)||'20',
							0, pkconstant.HORIDAY_SHORI_KBN_ZENEI());
	-- 新規募集情報の取得
	FOR recShinkiboshu IN curShinkiboshu LOOP
		-- 約定金額と社債の総額が一致しているかのチェック
		IF (recShinkiboshu.YAKUJO_KNGK <> recShinkiboshu.SHASAI_TOTAL) THEN
			-- 一致していない場合はログに出力する
			CALL pkLog.fatal('WIP004', C_PRGRAM_ID,'銘柄コード：'||recShinkiboshu.MGR_CD||'をスキップします');
		ELSE
			-- 一致している場合にのみ当該銘柄に対する後続の処理を行う
			
			-- 差引分手数料額合計のリセット
			nSashihikiTesuryoKngk := 0;
			-- 別段入出金テーブルinsertに用いる決済番号のセット
			cKessaiNo := PKIPI000K14R01.getKessaiNo(l_inItakuKaishaCd,C_SAIBAN_SHURUI);
			-- 別段入出金テーブルinsertに用いる決済番号枝番用数値のリセット（insert時に+1するので、2にしておく）
			nKessaiNoEdaNum := 2;
			-- 銘柄ごとの手数料情報取得
			FOR recTesuryo IN curTesuryo(recShinkiboshu.MGR_CD) LOOP
				-- 差引の手数料ならば差引分手数料額合計の集計
				IF (recTesuryo.TESU_SASHIHIKI_KBN = '1') THEN
					nSashihikiTesuryoKngk := nSashihikiTesuryoKngk + recTesuryo.ALL_TESU_KNGK + recTesuryo.ALL_TESU_SZEI;
				END IF;
				-- ③取引区分：11（引受金入金）・取引詳細区分：14（当初手数料）のデータ作成
				-- ※別立ての発行時手数料の場合に、入金データを作成する
				IF (recTesuryo.HAKKO_KICHU_FLG = '1' and recTesuryo.TESU_SASHIHIKI_KBN = '2') THEN
					-- 決済番号枝番用数値の加算
					nKessaiNoEdaNum := nKessaiNoEdaNum + 1;
					-- insert処理
					gRtnCd := PKIPI000K14R01.insertBD(
								l_inKijunYmd,						-- 基準日
								l_inItakuKaishaCd,					-- 委託会社コード
								recShinkiboshu.MGR_CD,				-- 銘柄コード
								recTesuryo.CHOKYU_YMD,				-- 取引日：徴求日
								'11',								-- 取引区分：11（引受金入金）
								'14',								-- 取引詳細区分：14（当初手数料）
								'1',								-- 入出金区分：1（入金）
								'0',								-- 元利区分：0（元金）
								'2',								-- 現登区分：2（振替債）
								recTesuryo.ALL_TESU_KNGK + recTesuryo.ALL_TESU_SZEI,
																	-- 金額（入金データは税込で登録する）
								0,									-- 消費税（「金額」を税込にしているため0をセット）
								cKessaiNo,							-- 決済番号
								TO_CHAR(nKessaiNoEdaNum,'FM000'),	-- 決済番号枝番
								NULL,								-- 金融証券区分
								NULL,								-- 金融機関コード
								NULL,								-- 口座区分
								NULL,								-- 税区分
								NULL,								-- 相手方資金決済会社_金融機関コード
								NULL,								-- 相手方資金決済会社_支店コード
								recTesuryo.TESU_SHURUI_CD,			-- 手数料種類コード
								NULL,								-- 分配先金融証券区分
								NULL 								-- 分配先金融機関コード
					);
					IF (gRtnCd <> pkconstant.success()) THEN
						CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '別段預金INSERT処理エラー 銘柄コード：'||recShinkiboshu.MGR_CD);
						RETURN gRtnCd;
					END IF;
				END IF;
				-- 手数料出金データの作成
				
				-- ※発行時手数料で分配のない手数料の場合
				IF (recTesuryo.TESU_SHURUI_CD IN ('03','04','32','33','34','51','46','47','71','72','73','74')) THEN
					-- ⑥取引区分：12（引受金出金）・取引詳細区分：14（当初手数料）のデータ作成
					
					-- 決済番号枝番用数値の加算
					nKessaiNoEdaNum := nKessaiNoEdaNum + 1;
					-- insert処理
					gRtnCd := PKIPI000K14R01.insertBD(
								l_inKijunYmd,						-- 基準日
								l_inItakuKaishaCd,					-- 委託会社コード
								recShinkiboshu.MGR_CD,				-- 銘柄コード
								CASE
									WHEN recTesuryo.TESU_SHURUI_CD = '51' THEN cTesuryo51ShukkinYmd
									ELSE recTesuryo.CHOKYU_YMD
								END,								-- 取引日：徴求日
								'12',								-- 取引区分：12（引受金出金）
								'14',								-- 取引詳細区分：14（当初手数料）
								'2',								-- 入出金区分：2（出金）
								'0',								-- 元利区分：0（元金）
								'2',								-- 現登区分：2（振替債）
								recTesuryo.ALL_TESU_KNGK,			-- 金額
								recTesuryo.ALL_TESU_SZEI,			-- 消費税
								cKessaiNo,							-- 決済番号
								TO_CHAR(nKessaiNoEdaNum,'FM000'),	-- 決済番号枝番
								NULL,								-- 金融証券区分
								NULL,								-- 金融機関コード
								NULL,								-- 口座区分
								NULL,								-- 税区分
								NULL,								-- 相手方資金決済会社_金融機関コード
								NULL,								-- 相手方資金決済会社_支店コード
								recTesuryo.TESU_SHURUI_CD,			-- 手数料種類コード
								NULL,								-- 分配先金融証券区分
								NULL 								-- 分配先金融機関コード
					);
					IF (gRtnCd <> pkconstant.success()) THEN
						CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '別段預金INSERT処理エラー 銘柄コード：'||recShinkiboshu.MGR_CD);
						RETURN gRtnCd;
					END IF;
					-- 手数料種類が51（新規記録手数料）以外の場合、会計登録データ作成
					IF (recTesuryo.TESU_SHURUI_CD <> '51' and (trim(both recTesuryo.ACCOUNT_CD_UKEIRE) IS NOT NULL AND (trim(both recTesuryo.ACCOUNT_CD_UKEIRE))::text <> '')) THEN
						-- insert処理
						gRtnCd := PKIPI000K14R01.insertKT(
									l_inItakuKaishaCd,					-- 委託会社コード
									recShinkiboshu.MGR_CD,				-- 銘柄コード
									recTesuryo.CHOKYU_YMD,				-- 取引日：徴求日
									recTesuryo.ACCOUNT_CD_UKEIRE,		-- 勘定科目
									recTesuryo.TESU_SHURUI_CD,			-- 手数料種類コード
									NULL,								-- 金融証券区分
									NULL,								-- 金融機関コード
									NULL,								-- 口座区分
									NULL,								-- 税区分
									'1',								-- 入出金区分：1（入金）
									recTesuryo.ALL_TESU_KNGK,			-- 金額
									recTesuryo.ALL_TESU_SZEI,			-- 消費税
									PKIPI000K14R01.getMtTesuNm(l_inItakuKaishaCd,recTesuryo.TESU_SHURUI_CD)
																		-- 会計登録備考：手数料種類の名称
						);
						IF (gRtnCd <> pkconstant.success()) THEN
							CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '会計登録INSERT処理エラー 銘柄コード：'||recShinkiboshu.MGR_CD);
							RETURN gRtnCd;
						END IF;
					END IF;
				-- ※発行時手数料で分配のあるもの および期中手数料の場合
				ELSE
					-- ※期中で分配の無い種類の手数料の場合（差引の場合のみ）
					IF (recTesuryo.TESU_SASHIHIKI_KBN = '1' and recTesuryo.TESU_SHURUI_CD IN ('21','22','52','46','91')) THEN
						-- ⑦・⑧取引区分：12（引受金出金）・
						-- 取引詳細区分：15・16（期中手数料（当社受入／副受託分配））のデータ作成
						-- 決済番号枝番用数値の加算
						nKessaiNoEdaNum := nKessaiNoEdaNum + 1;
						-- insert処理
						gRtnCd := PKIPI000K14R01.insertBD(
									l_inKijunYmd,						-- 基準日
									l_inItakuKaishaCd,					-- 委託会社コード
									recShinkiboshu.MGR_CD,				-- 銘柄コード
									recTesuryo.CHOKYU_YMD,				-- 取引日：徴求日
									'12',								-- 取引区分：12（引受金出金）
									'15',								-- 取引詳細区分：15（当社受入）
									'2',								-- 入出金区分：2（出金）
									'0',								-- 元利区分：0（元金）
									'2',								-- 現登区分：2（振替債）
									recTesuryo.ALL_TESU_KNGK,			-- 金額
									recTesuryo.ALL_TESU_SZEI,			-- 消費税
									cKessaiNo,							-- 決済番号
									TO_CHAR(nKessaiNoEdaNum,'FM000'),	-- 決済番号枝番
									NULL,								-- 金融証券区分
									NULL,								-- 金融機関コード
									NULL,								-- 口座区分
									NULL,								-- 税区分
									NULL,								-- 相手方資金決済会社_金融機関コード
									NULL,								-- 相手方資金決済会社_支店コード
									recTesuryo.TESU_SHURUI_CD,			-- 手数料種類コード
									NULL,								-- 分配先金融証券区分
									NULL 								-- 分配先金融機関コード
						);
						IF (gRtnCd <> pkconstant.success()) THEN
							CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '別段預金INSERT処理エラー 銘柄コード：'||recShinkiboshu.MGR_CD);
							RETURN gRtnCd;
						END IF;
						-- 会計登録データ作成
						IF ((trim(both recTesuryo.ACCOUNT_CD_UKEIRE) IS NOT NULL AND (trim(both recTesuryo.ACCOUNT_CD_UKEIRE))::text <> '')) THEN
							gRtnCd := PKIPI000K14R01.insertKT(
										l_inItakuKaishaCd,					-- 委託会社コード
										recShinkiboshu.MGR_CD,				-- 銘柄コード
										recTesuryo.CHOKYU_YMD,				-- 取引日：徴求日
										recTesuryo.ACCOUNT_CD_UKEIRE,		-- 勘定科目
										recTesuryo.TESU_SHURUI_CD,			-- 手数料種類コード
										NULL,								-- 金融証券区分
										NULL,								-- 金融機関コード
										NULL,								-- 口座区分
										NULL,								-- 税区分
										'1',								-- 入出金区分：1（入金）
										recTesuryo.ALL_TESU_KNGK,			-- 金額
										recTesuryo.ALL_TESU_SZEI,			-- 消費税
										PKIPI000K14R01.getMtTesuNm(l_inItakuKaishaCd,recTesuryo.TESU_SHURUI_CD)
																			-- 会計登録備考：手数料種類の名称
							);
							IF (gRtnCd <> pkconstant.success()) THEN
								CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '会計登録INSERT処理エラー 銘柄コード：'||recShinkiboshu.MGR_CD);
								RETURN gRtnCd;
							END IF;
						END IF;
					-- ※期中で分配の無い手数料以外で、差引ありの手数料および分配のある発行時手数料の場合
					ELSIF (recTesuryo.TESU_SASHIHIKI_KBN = '1' or recTesuryo.TESU_SHURUI_CD IN ('01','02','31')) THEN
						FOR recTesuryoBunpai IN curTesuryoBunpai(
							recShinkiboshu.MGR_CD,
							recTesuryo.TESU_SHURUI_CD,
							recTesuryo.CHOKYU_YMD,
							recTesuryo.DATA_SAKUSEI_KBN,
							recTesuryo.SHORI_KBN
						) LOOP
							-- 自行に対する分配分の場合、当社受入の出金データを作成する
							IF (recTesuryoBunpai.FINANCIAL_SECURITIES_KBN = '0' and recTesuryoBunpai.BANK_CD = pkConstant.getKaiinId) THEN
								-- 決済番号枝番用数値の加算
								nKessaiNoEdaNum := nKessaiNoEdaNum + 1;
								-- insert処理
								gRtnCd := PKIPI000K14R01.insertBD(
											l_inKijunYmd,						-- 基準日
											l_inItakuKaishaCd,					-- 委託会社コード
											recShinkiboshu.MGR_CD,				-- 銘柄コード
											recTesuryo.CHOKYU_YMD,				-- 取引日：徴求日
											'12',								-- 取引区分：12（引受金出金）
											'15',								-- 取引詳細区分：15（当社受入）
											'2',								-- 入出金区分：2（出金）
											'0',								-- 元利区分：0（元金）
											'2',								-- 現登区分：2（振替債）
											recTesuryoBunpai.DF_TESU_KNGK,		-- 金額
											recTesuryoBunpai.DF_TESU_SZEI,		-- 消費税
											cKessaiNo,							-- 決済番号
											TO_CHAR(nKessaiNoEdaNum,'FM000'),	-- 決済番号枝番
											NULL,								-- 金融証券区分
											NULL,								-- 金融機関コード
											NULL,								-- 口座区分
											NULL,								-- 税区分
											NULL,								-- 相手方資金決済会社_金融機関コード
											NULL,								-- 相手方資金決済会社_支店コード
											recTesuryo.TESU_SHURUI_CD,			-- 手数料種類コード
											NULL,								-- 分配先金融証券区分
											NULL 								-- 分配先金融機関コード
								);
								IF (gRtnCd <> pkconstant.success()) THEN
									CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '別段預金INSERT処理エラー 銘柄コード：'||recShinkiboshu.MGR_CD);
									RETURN gRtnCd;
								END IF;
								-- 会計登録データ作成
								IF ((trim(both recTesuryo.ACCOUNT_CD_UKEIRE) IS NOT NULL AND (trim(both recTesuryo.ACCOUNT_CD_UKEIRE))::text <> '')) THEN
									gRtnCd := PKIPI000K14R01.insertKT(
												l_inItakuKaishaCd,					-- 委託会社コード
												recShinkiboshu.MGR_CD,				-- 銘柄コード
												recTesuryo.CHOKYU_YMD,				-- 取引日：徴求日
												recTesuryo.ACCOUNT_CD_UKEIRE,		-- 勘定科目
												recTesuryo.TESU_SHURUI_CD,			-- 手数料種類コード
												NULL,								-- 金融証券区分
												NULL,								-- 金融機関コード
												NULL,								-- 口座区分
												NULL,								-- 税区分
												'1',								-- 入出金区分：1（入金）
												recTesuryoBunpai.DF_TESU_KNGK,		-- 金額
												recTesuryoBunpai.DF_TESU_SZEI,		-- 消費税
												PKIPI000K14R01.getMtTesuNm(l_inItakuKaishaCd,recTesuryo.TESU_SHURUI_CD)
																					-- 会計登録備考：手数料種類の名称
									);
									IF (gRtnCd <> pkconstant.success()) THEN
										CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '会計登録INSERT処理エラー 銘柄コード：'||recShinkiboshu.MGR_CD);
										RETURN gRtnCd;
									END IF;
								END IF;
							-- 自行以外に対する分配分の場合、副受託分配の出金データを作成する
							ELSE
								-- 決済番号枝番用数値の加算
								nKessaiNoEdaNum := nKessaiNoEdaNum + 1;
								-- insert処理
								gRtnCd := PKIPI000K14R01.insertBD(
											l_inKijunYmd,						-- 基準日
											l_inItakuKaishaCd,					-- 委託会社コード
											recShinkiboshu.MGR_CD,				-- 銘柄コード
											recTesuryo.CHOKYU_YMD,				-- 取引日：徴求日
											'12',								-- 取引区分：12（引受金出金）
											'16',								-- 取引詳細区分：16（副受託分配）
											'2',								-- 入出金区分：2（出金）
											'0',								-- 元利区分：0（元金）
											'2',								-- 現登区分：2（振替債）
											recTesuryoBunpai.DF_TESU_KNGK,		-- 金額
											recTesuryoBunpai.DF_TESU_SZEI,		-- 消費税
											cKessaiNo,							-- 決済番号
											TO_CHAR(nKessaiNoEdaNum,'FM000'),	-- 決済番号枝番
											NULL,								-- 金融証券区分
											NULL,								-- 金融機関コード
											NULL,								-- 口座区分
											NULL,								-- 税区分
											NULL,								-- 相手方資金決済会社_金融機関コード
											NULL,								-- 相手方資金決済会社_支店コード
											recTesuryo.TESU_SHURUI_CD,			-- 手数料種類コード
											recTesuryoBunpai.FINANCIAL_SECURITIES_KBN,
																				-- 分配先金融証券区分
											recTesuryoBunpai.BANK_CD 			-- 分配先金融機関コード
								);
								IF (gRtnCd <> pkconstant.success()) THEN
									CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '別段預金INSERT処理エラー 銘柄コード：'||recShinkiboshu.MGR_CD);
									RETURN gRtnCd;
								END IF;
							END IF;
						END LOOP;
					END IF;
				END IF;
			END LOOP;
			-- 基金の入出金データを作成する
			-- 差引分手数料額合計の値により差引の有無を判断する
			IF (nSashihikiTesuryoKngk > 0) THEN
				-- ②差引ありの場合、差引の引受金入金データを作成する
				gRtnCd := PKIPI000K14R01.insertBD(
							l_inKijunYmd,						-- 基準日
							l_inItakuKaishaCd,					-- 委託会社コード
							recShinkiboshu.MGR_CD,				-- 銘柄コード
							l_inKijunYmd,						-- 取引日：基準日
							'11',								-- 取引区分：11（引受金入金）
							'12',								-- 取引詳細区分：12（差引）
							'1',								-- 入出金区分：1（入金）
							'0',								-- 元利区分：0（元金）
							'2',								-- 現登区分：2（振替債）
							recShinkiboshu.KESSAI_KNGK,			-- 金額
							0,									-- 消費税
							cKessaiNo,							-- 決済番号
							'001',								-- 決済番号枝番：001
							NULL,								-- 金融証券区分
							NULL,								-- 金融機関コード
							NULL,								-- 口座区分
							NULL,								-- 税区分
							NULL,								-- 相手方資金決済会社_金融機関コード
							NULL,								-- 相手方資金決済会社_支店コード
							NULL,								-- 手数料種類コード
							NULL,								-- 分配先金融証券区分
							NULL 								-- 分配先金融機関コード
				);
				IF (gRtnCd <> pkconstant.success()) THEN
					CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '別段預金INSERT処理エラー 銘柄コード：'||recShinkiboshu.MGR_CD);
					RETURN gRtnCd;
				END IF;
				-- ⑤差引ありの場合、差引振込額の引受金出金データを作成する
				gRtnCd := PKIPI000K14R01.insertBD(
							l_inKijunYmd,						-- 基準日
							l_inItakuKaishaCd,					-- 委託会社コード
							recShinkiboshu.MGR_CD,				-- 銘柄コード
							l_inKijunYmd,						-- 取引日：基準日
							'12',								-- 取引区分：12（引受金出金）
							'13',								-- 取引詳細区分：13（差引振込額）
							'2',								-- 入出金区分：2（出金）
							'0',								-- 元利区分：0（元金）
							'2',								-- 現登区分：2（振替債）
							recShinkiboshu.KESSAI_KNGK - nSashihikiTesuryoKngk,
																-- 金額：決済金額から差引手数料額を減じたもの
							0,									-- 消費税
							cKessaiNo,							-- 決済番号
							'002',								-- 決済番号枝番：002
							NULL,								-- 金融証券区分
							NULL,								-- 金融機関コード
							NULL,								-- 口座区分
							NULL,								-- 税区分
							NULL,								-- 相手方資金決済会社_金融機関コード
							NULL,								-- 相手方資金決済会社_支店コード
							NULL,								-- 手数料種類コード
							NULL,								-- 分配先金融証券区分
							NULL 								-- 分配先金融機関コード
				);
				IF (gRtnCd <> pkconstant.success()) THEN
					CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '別段預金INSERT処理エラー 銘柄コード：'||recShinkiboshu.MGR_CD);
					RETURN gRtnCd;
				END IF;
			ELSE
				-- ①差引なしの場合、別立ての引受金入金データを作成する
				gRtnCd := PKIPI000K14R01.insertBD(
							l_inKijunYmd,						-- 基準日
							l_inItakuKaishaCd,					-- 委託会社コード
							recShinkiboshu.MGR_CD,				-- 銘柄コード
							l_inKijunYmd,						-- 取引日：基準日
							'11',								-- 取引区分：11（引受金入金）
							'11',								-- 取引詳細区分：11（別立て）
							'1',								-- 入出金区分：1（入金）
							'0',								-- 元利区分：0（元金）
							'2',								-- 現登区分：2（振替債）
							recShinkiboshu.KESSAI_KNGK,			-- 金額
							0,									-- 消費税
							cKessaiNo,							-- 決済番号
							'001',								-- 決済番号枝番：001
							NULL,								-- 金融証券区分
							NULL,								-- 金融機関コード
							NULL,								-- 口座区分
							NULL,								-- 税区分
							NULL,								-- 相手方資金決済会社_金融機関コード
							NULL,								-- 相手方資金決済会社_支店コード
							NULL,								-- 手数料種類コード
							NULL,								-- 分配先金融証券区分
							NULL 								-- 分配先金融機関コード
				);
				IF (gRtnCd <> pkconstant.success()) THEN
					CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '別段預金INSERT処理エラー 銘柄コード：'||recShinkiboshu.MGR_CD);
					RETURN gRtnCd;
				END IF;
				-- ④差引なしの場合、別立ての引受金出金データを作成する
				gRtnCd := PKIPI000K14R01.insertBD(
							l_inKijunYmd,						-- 基準日
							l_inItakuKaishaCd,					-- 委託会社コード
							recShinkiboshu.MGR_CD,				-- 銘柄コード
							l_inKijunYmd,						-- 取引日：基準日
							'12',								-- 取引区分：12（引受金出金）
							'11',								-- 取引詳細区分：11（別立て）
							'2',								-- 入出金区分：2（出金）
							'0',								-- 元利区分：0（元金）
							'2',								-- 現登区分：2（振替債）
							recShinkiboshu.KESSAI_KNGK,			-- 金額
							0,									-- 消費税
							cKessaiNo,							-- 決済番号
							'002',								-- 決済番号枝番：002
							NULL,								-- 金融証券区分
							NULL,								-- 金融機関コード
							NULL,								-- 口座区分
							NULL,								-- 税区分
							NULL,								-- 相手方資金決済会社_金融機関コード
							NULL,								-- 相手方資金決済会社_支店コード
							NULL,								-- 手数料種類コード
							NULL,								-- 分配先金融証券区分
							NULL 								-- 分配先金融機関コード
				);
				IF (gRtnCd <> pkconstant.success()) THEN
					CALL pkLog.fatal('ECM701', C_PRGRAM_ID, '別段預金INSERT処理エラー 銘柄コード：'||recShinkiboshu.MGR_CD);
					RETURN gRtnCd;
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
			C_PRGRAM_ID,
			'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')'
		);
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi001k14r01_01 ( l_inItakuKaishaCd MGR_KIHON_VIEW.ITAKU_KAISHA_CD%TYPE, l_inKijunYmd BD_NYUSHUKIN.TORIHIKI_YMD%TYPE ) FROM PUBLIC;