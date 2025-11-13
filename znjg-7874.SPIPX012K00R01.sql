




CREATE OR REPLACE PROCEDURE spipx012k00r01 ( l_inItakuKaishaCd TEXT 		-- 委託会社コード
 ,l_inUserId TEXT 		-- ユーザID
 ,l_inChohyoKbn TEXT 		-- 帳票区分
 ,l_inGyomuYmd TEXT 		-- 業務日付
 ,l_inChohyoId TEXT 		-- 帳票ID
 ,l_inHktCd TEXT 		-- 発行体コード
 ,l_inKozaTenCd TEXT 		-- 口座店コード
 ,l_inKozaTenCifCd TEXT 		-- 口座店CIFコード
 ,l_inMgrCd TEXT 		-- 銘柄コード
 ,l_inIsinCd TEXT 		-- ISINコード
 ,l_inKijunYm TEXT 		-- 基準年月
 ,l_inTsuchiYmd TEXT 		-- 通知日
 ,l_outSqlCode OUT integer 		-- リターン値
 ,l_outSqlErrM OUT text	-- エラーコメント
 ) AS $body$
DECLARE

	--*
--	 * 著作権:	Copyright(c)2007
--	 * 会社名:	JIP
--	 * 
--	 * 元利払基金残高報告書を作成する。（DCS静岡カスタマイズ版）
--	 * 
--	 * 改造元プログラム：元利払基金残高報告書パッケージ版（SPIPI050K00R01）
--	 * オプションコード：IP010061040F4
--	 * @author	ASK
--	 * @version	$Revision: 1.9 $
--	 * 
--	 * @param	l_inItakuKaishaCd	IN  TEXT		委託会社コード
--	 * @param	l_inUserId			IN  TEXT		ユーザID
--	 * @param	l_inChohyoKbn		IN  TEXT		帳票区分
--	 * @param	l_inGyomuYmd		IN  TEXT		業務日付
--	 * @param	l_inChohyoId		IN  TEXT		帳票ID			←バッチはここまで
--	 * @param	l_inHktCd			IN  TEXT		発行体コード
--	 * @param	l_inKozaTenCd		IN  TEXT		口座店コード
--	 * @param	l_inKozaTenCifCd	IN  TEXT		口座店CIFコード
--	 * @param	l_inMgrCd			IN  TEXT		銘柄コード
--	 * @param	l_inIsinCd			IN  TEXT		ISINコード
--	 * @param	l_inKijunYm			IN  TEXT		基準年月
--	 * @param	l_inTsuchiYmd		IN  TEXT		通知日
--	 * @param	l_outSqlCode		OUT INTEGER		リターン値	0:正常終了 1:異常終了 2:正常終了(対象データなし) 99:致命的な異常終了
--	 * @param	l_outSqlErrM		OUT VARCHAR	エラーコメント
--	 
	--==============================================================================*
--		デバッグ機能
--	 *==============================================================================
	DEBUG numeric(1) := 0;	-- 0:オフ 1:オン
	--==============================================================================*
--		定数定義
--	 *==============================================================================
	NODATA			CONSTANT integer := 2;						-- データなし
	PROGRAM_ID		CONSTANT varchar(14) := 'SPIPX012K00R01';	-- プログラムID
	TSUCHI_YMD_DEF	CONSTANT char(16) := '      年  月  日';	-- デフォルト通知日
										-- EXCEPTION
	--==============================================================================*
--		変数定義
--	 *==============================================================================
	gRtnCd			integer := pkconstant.success();			-- リターンコード
	gResult			integer :=	pkconstant.success();			-- 他functionの結果取得用
	gSeqNo			integer := 0;							-- シーケンス
	gKijunYm		char(6) := NULL;						-- 基準年月
	gZengetsumatsuYmd	char(8) := NULL;					-- 基準年月の前月末日
	gKeyHktCd		MHAKKOTAI.HKT_CD%TYPE := NULL;			-- 発行体コード(キーブレイク判定用)
	gNofuYmd		varchar(22) := NULL;					-- 納付年月日
	gShizKbn		char(1) := NULL;						-- 静岡県債区分
	gKeiTitle		varchar(8) := NULL;					-- 合計行タイトル
	-- frm用文字列
	gFrmTsuchiYmd	varchar(16) := NULL;					-- 通知日(西暦)
	gFrmToriYm		varchar(18) := NULL;					-- 取扱年月(西暦)
	gFrmAtena		text := NULL;					-- 宛名
	gFrmAtena2		text := NULL;					-- 宛名(合計行挿入用)
	gFrmBunsho		varchar(200) := NULL;					-- 請求文章
	gFrmBankNm		VJIKO_ITAKU.BANK_NM%TYPE := NULL;		-- 銀行名称
	gFrmBushoNm1	VJIKO_ITAKU.BUSHO_NM1%TYPE := NULL;	-- 担当部署名称１
	-- 計算用
	gWkZenZndkKkn	decimal(16,2) := 0;					-- 前月末残高(基金口)
	gWkZenZndkTesu	decimal(16,2) := 0;					-- 前月末残高(手数料口)
	gWkTouZndkKkn	decimal(16,2) := 0;					-- 当月末残高(基金口)
	gWkTouZndkTesu	decimal(16,2) := 0;					-- 当月末残高(手数料口)
	-- 合計フィールド
	-- 発行体合計
	gWkHktZenZndkKknKei 	decimal(16,2) := 0;			-- 発行体前月末残高(基金口)計
	gWkHktZenZndkTesuKei	decimal(16,2) := 0;			-- 発行体前月末残高(手数料口)計
	gWkHktTouInKknKei		decimal(16,2) := 0;			-- 発行体当月入金(基金口)計
	gWkHktTouInTesuKei		decimal(16,2) := 0;			-- 発行体当月入金(手数料口)計
	gWkHktTouOutKknKei		decimal(16,2) := 0;			-- 発行体当月出金(基金口)計
	gWkHktTouOutTesuKei		decimal(16,2) := 0;			-- 発行体当月出金(手数料口)計
	gWkHktTouOutZeiKei		decimal(16,2) := 0;			-- 発行体当月出金(国税口)計
	gWkHktTouOutHenKei		decimal(16,2) := 0;			-- 発行体当月出金(返戻)計
	gWkHktTouOutEtcKei		decimal(16,2) := 0;			-- 発行体当月出金(その他)計
	gWkHktTouZndkKknKei		decimal(16,2) := 0;			-- 発行体当月末残高(基金口)計
	gWkHktTouZndkTesuKei	decimal(16,2) := 0;			-- 発行体当月末残高(手数料口)計
	-- 静岡県債合計
	gWkShizZenZndkKknKei 	decimal(16,2) := 0;			-- 静岡県債前月末残高(基金口)計
	gWkShizZenZndkTesuKei	decimal(16,2) := 0;			-- 静岡県債前月末残高(手数料口)計
	gWkShizTouInKknKei		decimal(16,2) := 0;			-- 静岡県債当月入金(基金口)計
	gWkShizTouInTesuKei		decimal(16,2) := 0;			-- 静岡県債当月入金(手数料口)計
	gWkShizTouOutKknKei		decimal(16,2) := 0;			-- 静岡県債当月出金(基金口)計
	gWkShizTouOutTesuKei	decimal(16,2) := 0;			-- 静岡県債当月出金(手数料口)計
	gWkShizTouOutZeiKei		decimal(16,2) := 0;			-- 静岡県債当月出金(国税口)計
	gWkShizTouOutHenKei		decimal(16,2) := 0;			-- 静岡県債当月出金(返戻)計
	gWkShizTouOutEtcKei		decimal(16,2) := 0;			-- 静岡県債当月出金(その他)計
	gWkShizTouZndkKknKei	decimal(16,2) := 0;			-- 静岡県債当月末残高(基金口)計
	gWkShizTouZndkTesuKei	decimal(16,2) := 0;			-- 静岡県債当月末残高(手数料口)計
	gWkOutFlg				numeric(1)     := 0;			-- 出力対象フラグ
	v_item					type_sreport_wk_item;			-- 帳票ワークアイテム
	--==============================================================================*
--		カーソル定義
--	 *==============================================================================
	curMeisai CURSOR FOR
	SELECT
		 VMG1.ITAKU_KAISHA_CD
		,VMG1.HKT_CD
		,coalesce(K02.TSUKA_CD,'JPY')			AS TSUKA_CD 	-- 銘柄の対象基金異動レコードがない場合「JPY」のページに0円で明細行を出力する。
		,(SELECT M64.TSUKA_NM FROM MTSUKA M64 WHERE M64.TSUKA_CD = coalesce(K02.TSUKA_CD, 'JPY') ) AS TSUKA_NM  -- ただし、この場合通貨CDは取得できずNULLであるので「JPY」に変換する。
		,VMG1.ISIN_CD 									-- ソートは、変換したこの項目を使って行う。
		,VMG1.MGR_CD
		,SUBSTR(VMG1.MGR_NM, 0, 36)			AS MGR_NM  -- 銘柄の正式名称18文字ずつ2段表示とするため、36文字でカットする。
		-- 機構発行体コードが'222000'であれば静岡県債、それ以外は静岡県債以外で区分は'0'。
--		   静岡県債の内でISINコードの9桁目が数字の場合は公募公債で区分は'1'、9桁目が英字の場合は公債で区分は'2'とする。
		,CASE WHEN VMG1.KK_HAKKO_CD='222000' THEN 				CASE WHEN sfCmIsNumeric(SUBSTR(VMG1.ISIN_CD, 9, 1))=0 THEN  '1'  ELSE '2' END   ELSE '0' END  AS SHIZ_KBN
		,VMG1.HAKKO_YMD
		-- 銘柄の発行体情報
		,M01.HKT_NM
		,M01.SFSK_POST_NO
		,M01.ADD1
		,M01.ADD2
		,M01.ADD3
		,M01.SFSK_BUSHO_NM
		-- 金額（銘柄ベースのため、基金異動履歴レコードはないこともある…ゼロで取得）
		---- 当月
		,coalesce(K02.T1_TOU_IN_KKN,0)			AS TOU_IN_KKN 				-- 当月入金_基金
		,coalesce(K02.T2_TOU_IN_TESU,0)			AS TOU_IN_TESU 				-- 当月入金_手数料
		,coalesce(K02.T3_TOU_OUT_KKN,0)			AS TOU_OUT_KKN 				-- 当月出金_基金
		,coalesce(K02.T4_TOU_OUT_TESU,0)			AS TOU_OUT_TESU 				-- 当月出金_手数料
		,coalesce(K02.T5_TOU_OUT_ZEI,0)			AS TOU_OUT_ZEI 				-- 当月出金_国税
		,coalesce(K02.T6_TOU_OUT_HEN_KKN,0)		AS TOU_OUT_HEN_KKN 			-- 当月出金_返戻金(基金口)
		,coalesce(K02.T7_TOU_OUT_HEN_TESU,0)		AS TOU_OUT_HEN_TESU 			-- 当月出金_返戻金(手数料口)
		,coalesce(K02.T8_TOU_OUT_ETC_KKN,0)		AS TOU_OUT_ETC_KKN 			-- 当月出金_その他(基金口)
		,coalesce(K02.T9_TOU_OUT_ETC_TESU,0)		AS TOU_OUT_ETC_TESU 			-- 当月出金_その他(手数料口)
		---- 前月まで
		,coalesce(K02.Z1_ZEN_IN_KKN,0)			AS ZEN_IN_KKN 				-- 前月入金_基金
		,coalesce(K02.Z2_ZEN_IN_TESU,0)			AS ZEN_IN_TESU 				-- 前月入金_手数料
		,coalesce(K02.Z3_ZEN_OUT_KKN,0)			AS ZEN_OUT_KKN 				-- 前月出金_基金
		,coalesce(K02.Z4_ZEN_OUT_TESU,0)			AS ZEN_OUT_TESU 				-- 前月出金_手数料
		,coalesce(K02.Z5_ZEN_OUT_ZEI,0)			AS ZEN_OUT_ZEI 				-- 前月出金_国税
		,coalesce(K02.Z6_ZEN_OUT_HEN_KKN,0)		AS ZEN_OUT_HEN_KKN 			-- 前月出金_返戻金(基金口)
		,coalesce(K02.Z7_ZEN_OUT_HEN_TESU,0)		AS ZEN_OUT_HEN_TESU 			-- 前月出金_返戻金(手数料口)
		,coalesce(K02.Z8_ZEN_OUT_ETC_KKN,0)		AS ZEN_OUT_ETC_KKN 			-- 前月出金_その他(基金口)
		,coalesce(K02.Z9_ZEN_OUT_ETC_TESU,0)		AS ZEN_OUT_ETC_TESU 			-- 前月出金_その他(手数料口)
	FROM mgr_kihon_view vmg1
LEFT OUTER JOIN mhakkotai m01 ON (VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD AND VMG1.HKT_CD = M01.HKT_CD)
LEFT OUTER JOIN (SELECT
			-- キー
			 K02_T.ITAKU_KAISHA_CD
			,K02_T.MGR_CD
			,K02_T.TSUKA_CD
			-- 金額（当月）
			,coalesce(SUM(K02_T.TOU_IN_KKN),0)			AS T1_TOU_IN_KKN 			-- 当月入金_基金
			,coalesce(SUM(K02_T.TOU_IN_TESU),0)			AS T2_TOU_IN_TESU 			-- 当月入金_手数料
			,coalesce(SUM(K02_T.TOU_OUT_KKN),0)			AS T3_TOU_OUT_KKN 			-- 当月出金_基金
			,coalesce(SUM(K02_T.TOU_OUT_TESU),0)			AS T4_TOU_OUT_TESU 			-- 当月出金_手数料
			,coalesce(SUM(K02_T.TOU_OUT_ZEI),0)			AS T5_TOU_OUT_ZEI 			-- 当月出金_国税
			,coalesce(SUM(K02_T.TOU_OUT_HEN_KKN),0)		AS T6_TOU_OUT_HEN_KKN 		-- 当月出金_返戻金(基金口)
			,coalesce(SUM(K02_T.TOU_OUT_HEN_TESU),0)		AS T7_TOU_OUT_HEN_TESU 		-- 当月出金_返戻金(手数料口)
			,coalesce(SUM(K02_T.TOU_OUT_ETC_KKN),0)		AS T8_TOU_OUT_ETC_KKN 		-- 当月出金_その他(基金口)
			,coalesce(SUM(K02_T.TOU_OUT_ETC_TESU),0)		AS T9_TOU_OUT_ETC_TESU 		-- 当月出金_その他(手数料口)
			-- 金額（前月まで）
			,coalesce(SUM(K02_T.ZEN_IN_KKN),0)			AS Z1_ZEN_IN_KKN 			-- 前月入金_基金
			,coalesce(SUM(K02_T.ZEN_IN_TESU),0)			AS Z2_ZEN_IN_TESU 			-- 前月入金_手数料
			,coalesce(SUM(K02_T.ZEN_OUT_KKN),0)			AS Z3_ZEN_OUT_KKN 			-- 前月出金_基金
			,coalesce(SUM(K02_T.ZEN_OUT_TESU),0)			AS Z4_ZEN_OUT_TESU 			-- 前月出金_手数料
			,coalesce(SUM(K02_T.ZEN_OUT_ZEI),0)			AS Z5_ZEN_OUT_ZEI 			-- 前月出金_国税
			,coalesce(SUM(K02_T.ZEN_OUT_HEN_KKN),0)		AS Z6_ZEN_OUT_HEN_KKN 		-- 前月出金_返戻金(基金口)
			,coalesce(SUM(K02_T.ZEN_OUT_HEN_TESU),0)		AS Z7_ZEN_OUT_HEN_TESU 		-- 前月出金_返戻金(手数料口)
			,coalesce(SUM(K02_T.ZEN_OUT_ETC_KKN),0)		AS Z8_ZEN_OUT_ETC_KKN 		-- 前月出金_その他(基金口)
			,coalesce(SUM(K02_T.ZEN_OUT_ETC_TESU),0)		AS Z9_ZEN_OUT_ETC_TESU 		-- 前月出金_その他(手数料口)
		 FROM
			--* 出力対象基金異動履歴(K02_T) *
			-- 金額は、基金異動履歴(K02_S)のキー「委託会社CD・銘柄CD・利払期日・異動年月日・通貨CD」で引っ張ってくる
			(SELECT
			 	-- キー
				 K02_S.ITAKU_KAISHA_CD
				,K02_S.MGR_CD
				,K02_S.RBR_KJT
				,K02_S.IDO_YMD
				,K02_S.TSUKA_CD
				,
				-- T1〜T9 金額（当月）
				--==============================================================
				--	T1	当月入金_基金
				--		11:入金(元金)			21:入金(利金)
				----------------------------------------------------
				(SELECT
					coalesce(SUM(K02_T1.KKN_NYUKIN_KNGK),0)
				 FROM
					KIKIN_IDO K02_T1
				 WHERE
						K02_T1.KKN_IDO_KBN IN ('11','21')
					-- 異動日(徴求日) ＝ 基準年月
					AND	SUBSTR(K02_T1.IDO_YMD,1,6) = gKijunYm
					-- 入金は請求書出力済
					AND K02_T1.DATA_SAKUSEI_KBN >= '1'
					-- [[ 以下、基金異動履歴(K02_S)レコードとの結合条件 ]]
					AND	K02_T1.ITAKU_KAISHA_CD	= K02_S.ITAKU_KAISHA_CD
					AND	K02_T1.MGR_CD			= K02_S.MGR_CD
					AND	K02_T1.RBR_KJT			= K02_S.RBR_KJT
					AND	K02_T1.IDO_YMD			= K02_S.IDO_YMD
					AND	K02_T1.TSUKA_CD			= K02_S.TSUKA_CD
				) AS TOU_IN_KKN
				,
				--==============================================================
				--	T2	当月入金_手数料
				--		12:入金(元金手数料)			22:入金(利金手数料)
				--		13:入金(元金手数料消費税)	23:入金(利金手数料消費税)
				----------------------------------------------------
				(SELECT
					coalesce(SUM(K02_T2.KKN_NYUKIN_KNGK),0)
				 FROM
					KIKIN_IDO K02_T2
				 WHERE
						K02_T2.KKN_IDO_KBN IN ('12','13','22','23')
					-- 異動日(徴求日) ＝ 基準年月
					AND	SUBSTR(K02_T2.IDO_YMD,1,6) = gKijunYm
					-- 入金は請求書出力済
					AND K02_T2.DATA_SAKUSEI_KBN >= '1'
					-- [[ 以下、基金異動履歴(K02_S)レコードとの結合条件 ]]
					AND	K02_T2.ITAKU_KAISHA_CD	= K02_S.ITAKU_KAISHA_CD
					AND	K02_T2.MGR_CD			= K02_S.MGR_CD
					AND	K02_T2.RBR_KJT			= K02_S.RBR_KJT
					AND	K02_T2.IDO_YMD			= K02_S.IDO_YMD
					AND	K02_T2.TSUKA_CD			= K02_S.TSUKA_CD 
				) AS TOU_IN_TESU
				,
				--==============================================================
				--	T3	当月出金_基金
				--		31:出金(元金)			41:出金(利金)
				----------------------------------------------------
				(SELECT
					coalesce(SUM(K02_T3.KKN_SHUKIN_KNGK),0)
				 FROM
					KIKIN_IDO K02_T3
				 WHERE
						K02_T3.KKN_IDO_KBN IN ('31','41')
					-- 異動日(支払日) ＝ 基準年月
					AND	SUBSTR(K02_T3.IDO_YMD,1,6) = gKijunYm
					-- 基金・手数料支払高と国税は、機構非関与銘柄の場合は元利金請求明細が承認済であること
					AND EXISTS (SELECT ctid FROM KIKIN_SEIKYU K01
						 WHERE (K01.KK_KANYO_UMU_FLG = '1'
									OR (K01.KK_KANYO_UMU_FLG <> '1' AND K01.SHORI_KBN = '1'))
							AND	K02_T3.ITAKU_KAISHA_CD	= K01.ITAKU_KAISHA_CD
							AND K02_T3.MGR_CD			= K01.MGR_CD
							AND K02_T3.RBR_YMD			= K01.SHR_YMD )
					-- [[ 以下、基金異動履歴(K02_S)レコードとの結合条件 ]]
					AND	K02_T3.ITAKU_KAISHA_CD	= K02_S.ITAKU_KAISHA_CD
					AND	K02_T3.MGR_CD			= K02_S.MGR_CD
					AND	K02_T3.RBR_KJT			= K02_S.RBR_KJT
					AND	K02_T3.IDO_YMD			= K02_S.IDO_YMD
					AND	K02_T3.TSUKA_CD			= K02_S.TSUKA_CD 
				) AS TOU_OUT_KKN
				,
				--==============================================================
				--	T4	当月出金_手数料
				--		32:出金(元金手数料)			42:出金(利金手数料)
				--		33:出金(元金手数料消費税)	43:出金(利金手数料消費税)
				----------------------------------------------------
				(SELECT
					coalesce(SUM(K02_T4.KKN_SHUKIN_KNGK),0)
				 FROM
					KIKIN_IDO K02_T4
				 WHERE
						K02_T4.KKN_IDO_KBN IN ('32','33','42','43')
					-- 利払日 ＝ 基準年月
					AND	SUBSTR(K02_T4.RBR_YMD,1,6) = gKijunYm
					-- 基金・手数料支払高と国税は、機構非関与銘柄の場合は元利金請求明細が承認済であること
					AND EXISTS (SELECT ctid FROM KIKIN_SEIKYU K01
						 WHERE (K01.KK_KANYO_UMU_FLG = '1'
									OR (K01.KK_KANYO_UMU_FLG <> '1' AND K01.SHORI_KBN = '1'))
							AND	K02_T4.ITAKU_KAISHA_CD	= K01.ITAKU_KAISHA_CD
							AND K02_T4.MGR_CD			= K01.MGR_CD
							AND K02_T4.RBR_YMD			= K01.SHR_YMD )
					-- [[ 以下、基金異動履歴(K02_S)レコードとの結合条件 ]]
					AND	K02_T4.ITAKU_KAISHA_CD	= K02_S.ITAKU_KAISHA_CD
					AND	K02_T4.MGR_CD			= K02_S.MGR_CD
					AND	K02_T4.RBR_KJT			= K02_S.RBR_KJT
					AND	K02_T4.IDO_YMD			= K02_S.IDO_YMD
					AND	K02_T4.TSUKA_CD			= K02_S.TSUKA_CD 
				) AS TOU_OUT_TESU
				,
				--==============================================================
				--	T5	当月出金_国税
				--		51:国税
				----------------------------------------------------
				(SELECT
					coalesce(SUM(K02_T5.KKN_SHUKIN_KNGK),0)
				 FROM
					KIKIN_IDO K02_T5
				 WHERE
						K02_T5.KKN_IDO_KBN = '51'
					-- 利払日 ＝ 基準年月
					AND	SUBSTR(K02_T5.RBR_YMD,1,6) = gKijunYm
					-- 基金・手数料支払高と国税は、機構非関与銘柄の場合は元利金請求明細が承認済であること
					AND EXISTS (SELECT ctid FROM KIKIN_SEIKYU K01
						 WHERE (K01.KK_KANYO_UMU_FLG = '1'
									OR (K01.KK_KANYO_UMU_FLG <> '1' AND K01.SHORI_KBN = '1'))
							AND	K02_T5.ITAKU_KAISHA_CD	= K01.ITAKU_KAISHA_CD
							AND K02_T5.MGR_CD			= K01.MGR_CD
							AND K02_T5.RBR_YMD			= K01.SHR_YMD )
					-- [[ 以下、基金異動履歴(K02_S)レコードとの結合条件 ]]
					AND	K02_T5.ITAKU_KAISHA_CD	= K02_S.ITAKU_KAISHA_CD
					AND	K02_T5.MGR_CD			= K02_S.MGR_CD
					AND	K02_T5.RBR_KJT			= K02_S.RBR_KJT
					AND	K02_T5.IDO_YMD			= K02_S.IDO_YMD
					AND	K02_T5.TSUKA_CD			= K02_S.TSUKA_CD 
				) AS TOU_OUT_ZEI
				,
				--==============================================================
				--	T6	当月出金_返戻金(基金口)
				--		60〜67:返戻元金			70〜77:返戻利金
				----------------------------------------------------
				(SELECT
					coalesce(SUM(K02_T6.KKN_SHUKIN_KNGK),0)
				 FROM
					KIKIN_IDO K02_T6
				 WHERE
						K02_T6.KKN_IDO_KBN IN ('60','61','62','63','64','65','66','67',
												'70','71','72','73','74','75','76','77')
					-- 利払日 ＝ 基準年月
					AND	SUBSTR(K02_T6.RBR_YMD,1,6) = gKijunYm
					-- [[ 以下、基金異動履歴(K02_S)レコードとの結合条件 ]]
					AND	K02_T6.ITAKU_KAISHA_CD	= K02_S.ITAKU_KAISHA_CD
					AND	K02_T6.MGR_CD			= K02_S.MGR_CD
					AND	K02_T6.RBR_KJT			= K02_S.RBR_KJT
					AND	K02_T6.IDO_YMD			= K02_S.IDO_YMD
					AND	K02_T6.TSUKA_CD			= K02_S.TSUKA_CD 
				) AS TOU_OUT_HEN_KKN
				,
				--==============================================================
				--	T7	当月出金_返戻金(手数料口)
				--		68:返戻元金手数料		78:返戻利金手数料
				----------------------------------------------------
				(SELECT
					coalesce(SUM(K02_T7.KKN_SHUKIN_KNGK),0)
				 FROM
					KIKIN_IDO K02_T7
				 WHERE
						K02_T7.KKN_IDO_KBN IN ('68','78')
					-- 利払日 ＝ 基準年月
					AND	SUBSTR(K02_T7.RBR_YMD,1,6) = gKijunYm
					-- [[ 以下、基金異動履歴(K02_S)レコードとの結合条件 ]]
					AND	K02_T7.ITAKU_KAISHA_CD	= K02_S.ITAKU_KAISHA_CD
					AND	K02_T7.MGR_CD			= K02_S.MGR_CD
					AND	K02_T7.RBR_KJT			= K02_S.RBR_KJT
					AND	K02_T7.IDO_YMD			= K02_S.IDO_YMD
					AND	K02_T7.TSUKA_CD			= K02_S.TSUKA_CD 
				) AS TOU_OUT_HEN_TESU
				,
				--==============================================================
				--	T8	当月出金_その他(基金口)
				--		92:出金(利金端数)
				----------------------------------------------------
				(SELECT
					coalesce(SUM(K02_T8.KKN_SHUKIN_KNGK),0)
				 FROM
					KIKIN_IDO K02_T8
				 WHERE
						K02_T8.KKN_IDO_KBN = '92'
					-- 異動日(計上日) ＝ 基準年月
					AND	SUBSTR(K02_T8.IDO_YMD,1,6) = gKijunYm
					-- [[ 以下、基金異動履歴(K02_S)レコードとの結合条件 ]]
					AND	K02_T8.ITAKU_KAISHA_CD	= K02_S.ITAKU_KAISHA_CD
					AND	K02_T8.MGR_CD			= K02_S.MGR_CD
					AND	K02_T8.RBR_KJT			= K02_S.RBR_KJT
					AND	K02_T8.IDO_YMD			= K02_S.IDO_YMD
					AND	K02_T8.TSUKA_CD			= K02_S.TSUKA_CD 
				) AS TOU_OUT_ETC_KKN
				,
				--==============================================================
				--	T9	当月出金_その他(手数料口)
				--		94:出金(元金手数料端数)	96:出金(利金手数料端数)
				----------------------------------------------------
				(SELECT
					coalesce(SUM(K02_T9.KKN_SHUKIN_KNGK),0)
				 FROM
					KIKIN_IDO K02_T9
				 WHERE
						K02_T9.KKN_IDO_KBN IN ('94','96')
					-- 異動日(計上日) ＝ 基準年月
					AND	SUBSTR(K02_T9.IDO_YMD,1,6) = gKijunYm
					-- [[ 以下、基金異動履歴(K02_S)レコードとの結合条件 ]]
					AND	K02_T9.ITAKU_KAISHA_CD	= K02_S.ITAKU_KAISHA_CD
					AND	K02_T9.MGR_CD			= K02_S.MGR_CD
					AND	K02_T9.RBR_KJT			= K02_S.RBR_KJT
					AND	K02_T9.IDO_YMD			= K02_S.IDO_YMD
					AND	K02_T9.TSUKA_CD			= K02_S.TSUKA_CD 
				) AS TOU_OUT_ETC_TESU
				,
				-- Z1〜Z7 金額（前月まで）
				--==============================================================
				--	Z1	前月入金_基金
				--		11:入金(元金)			21:入金(利金)
				----------------------------------------------------
				(SELECT
					coalesce(SUM(K02_Z1.KKN_NYUKIN_KNGK),0)
				 FROM
					KIKIN_IDO K02_Z1
				 WHERE
						K02_Z1.KKN_IDO_KBN IN ('11','21')
					-- 異動日(基金…徴求日・その他…計上日) ＜ 基準年月
					AND	SUBSTR(K02_Z1.IDO_YMD,1,6) < gKijunYm
					-- 入金は請求書出力済
					AND K02_Z1.DATA_SAKUSEI_KBN >= '1'
					-- [[ 以下、基金異動履歴(K02_S)レコードとの結合条件 ]]
					AND	K02_Z1.ITAKU_KAISHA_CD	= K02_S.ITAKU_KAISHA_CD
					AND	K02_Z1.MGR_CD			= K02_S.MGR_CD
					AND	K02_Z1.RBR_KJT			= K02_S.RBR_KJT
					AND	K02_Z1.IDO_YMD			= K02_S.IDO_YMD
					AND	K02_Z1.TSUKA_CD			= K02_S.TSUKA_CD 
				) AS ZEN_IN_KKN
				,
				--==============================================================
				--	Z2	前月入金_手数料
				--		12:入金(元金手数料)			22:入金(利金手数料)
				--		13:入金(元金手数料消費税)	23:入金(利金手数料消費税)
				----------------------------------------------------
				(SELECT
					coalesce(SUM(K02_Z2.KKN_NYUKIN_KNGK),0)
				 FROM
					KIKIN_IDO K02_Z2
				 WHERE
						K02_Z2.KKN_IDO_KBN IN ('12','13','22','23')
					-- 異動日(手数料…徴求日・その他…計上日) ＜ 基準年月
					AND	SUBSTR(K02_Z2.IDO_YMD,1,6) < gKijunYm
					-- 入金は請求書出力済
					AND K02_Z2.DATA_SAKUSEI_KBN >= '1'
					-- [[ 以下、基金異動履歴(K02_S)レコードとの結合条件 ]]
					AND	K02_Z2.ITAKU_KAISHA_CD	= K02_S.ITAKU_KAISHA_CD
					AND	K02_Z2.MGR_CD			= K02_S.MGR_CD
					AND	K02_Z2.RBR_KJT			= K02_S.RBR_KJT
					AND	K02_Z2.IDO_YMD			= K02_S.IDO_YMD
					AND	K02_Z2.TSUKA_CD			= K02_S.TSUKA_CD 
				) AS ZEN_IN_TESU
				,
				--==============================================================
				--	Z3	前月出金_基金
				--		31:出金(元金)			41:出金(利金)
				----------------------------------------------------
				(SELECT
					coalesce(SUM(K02_Z3.KKN_SHUKIN_KNGK),0)
				 FROM
					KIKIN_IDO K02_Z3
				 WHERE
						K02_Z3.KKN_IDO_KBN IN ('31','41')
					-- 異動日(支払日) ＜ 基準年月
					AND	SUBSTR(K02_Z3.IDO_YMD,1,6) < gKijunYm
					-- 基金・手数料支払高と国税は、機構非関与銘柄の場合は元利金請求明細が承認済であること
					AND EXISTS (SELECT ctid FROM KIKIN_SEIKYU K01
						 WHERE (K01.KK_KANYO_UMU_FLG = '1'
									OR (K01.KK_KANYO_UMU_FLG <> '1' AND K01.SHORI_KBN = '1'))
							AND	K02_Z3.ITAKU_KAISHA_CD	= K01.ITAKU_KAISHA_CD
							AND K02_Z3.MGR_CD			= K01.MGR_CD
							AND K02_Z3.RBR_YMD			= K01.SHR_YMD )
					-- [[ 以下、基金異動履歴(K02_S)レコードとの結合条件 ]]
					AND	K02_Z3.ITAKU_KAISHA_CD	= K02_S.ITAKU_KAISHA_CD
					AND	K02_Z3.MGR_CD			= K02_S.MGR_CD
					AND	K02_Z3.RBR_KJT			= K02_S.RBR_KJT
					AND	K02_Z3.IDO_YMD			= K02_S.IDO_YMD
					AND	K02_Z3.TSUKA_CD			= K02_S.TSUKA_CD 
				) AS ZEN_OUT_KKN
				,
				--==============================================================
				--	Z4	前月出金_手数料
				--		32:出金(元金手数料)			42:出金(利金手数料)
				--		33:出金(元金手数料消費税)	43:出金(利金手数料消費税)
				----------------------------------------------------
				(SELECT
					coalesce(SUM(K02_Z4.KKN_SHUKIN_KNGK),0)
				 FROM
					KIKIN_IDO K02_Z4
				 WHERE
						K02_Z4.KKN_IDO_KBN IN ('32','33','42','43')
					-- 利払日 ＜ 基準年月
					AND	SUBSTR(K02_Z4.RBR_YMD,1,6) < gKijunYm
					-- 基金・手数料支払高と国税は、機構非関与銘柄の場合は元利金請求明細が承認済であること
					AND EXISTS (SELECT ctid FROM KIKIN_SEIKYU K01
						 WHERE (K01.KK_KANYO_UMU_FLG = '1'
									OR (K01.KK_KANYO_UMU_FLG <> '1' AND K01.SHORI_KBN = '1'))
							AND	K02_Z4.ITAKU_KAISHA_CD	= K01.ITAKU_KAISHA_CD
							AND K02_Z4.MGR_CD			= K01.MGR_CD
							AND K02_Z4.RBR_YMD			= K01.SHR_YMD )
					-- [[ 以下、基金異動履歴(K02_S)レコードとの結合条件 ]]
					AND	K02_Z4.ITAKU_KAISHA_CD	= K02_S.ITAKU_KAISHA_CD
					AND	K02_Z4.MGR_CD			= K02_S.MGR_CD
					AND	K02_Z4.RBR_KJT			= K02_S.RBR_KJT
					AND	K02_Z4.IDO_YMD			= K02_S.IDO_YMD
					AND	K02_Z4.TSUKA_CD			= K02_S.TSUKA_CD 
				) AS ZEN_OUT_TESU
				,
				--==============================================================
				--	Z5	前月出金_国税
				--		51:国税
				----------------------------------------------------
				(SELECT
					coalesce(SUM(K02_Z5.KKN_SHUKIN_KNGK),0)
				 FROM
					KIKIN_IDO K02_Z5
				 WHERE
						K02_Z5.KKN_IDO_KBN = '51'
					-- 利払日 ＜ 基準年月
					AND	SUBSTR(K02_Z5.RBR_YMD,1,6) < gKijunYm
					-- 基金・手数料支払高と国税は、機構非関与銘柄の場合は元利金請求明細が承認済であること
					AND EXISTS (SELECT ctid FROM KIKIN_SEIKYU K01
						 WHERE (K01.KK_KANYO_UMU_FLG = '1'
									OR (K01.KK_KANYO_UMU_FLG <> '1' AND K01.SHORI_KBN = '1'))
							AND	K02_Z5.ITAKU_KAISHA_CD	= K01.ITAKU_KAISHA_CD
							AND K02_Z5.MGR_CD			= K01.MGR_CD
							AND K02_Z5.RBR_YMD			= K01.SHR_YMD )
					-- [[ 以下、基金異動履歴(K02_S)レコードとの結合条件 ]]
					AND	K02_Z5.ITAKU_KAISHA_CD	= K02_S.ITAKU_KAISHA_CD
					AND	K02_Z5.MGR_CD			= K02_S.MGR_CD
					AND	K02_Z5.RBR_KJT			= K02_S.RBR_KJT
					AND	K02_Z5.IDO_YMD			= K02_S.IDO_YMD
					AND	K02_Z5.TSUKA_CD			= K02_S.TSUKA_CD 
				) AS ZEN_OUT_ZEI
				,
				--==============================================================
				--	Z6	前月出金_返戻金(基金口)
				--		60〜67:返戻金(元金)		70〜77:返戻金(利金)
				----------------------------------------------------
				(SELECT
					coalesce(SUM(K02_Z6.KKN_SHUKIN_KNGK),0)
				 FROM
					KIKIN_IDO K02_Z6
				 WHERE
						K02_Z6.KKN_IDO_KBN IN ('60','61','62','63','64','65','66','67',
												'70','71','72','73','74','75','76','77')
					-- 利払日 ＜ 基準年月
					AND	SUBSTR(K02_Z6.RBR_YMD,1,6) < gKijunYm
					-- [[ 以下、基金異動履歴(K02_S)レコードとの結合条件 ]]
					AND	K02_Z6.ITAKU_KAISHA_CD	= K02_S.ITAKU_KAISHA_CD
					AND	K02_Z6.MGR_CD			= K02_S.MGR_CD
					AND	K02_Z6.RBR_KJT			= K02_S.RBR_KJT
					AND	K02_Z6.IDO_YMD			= K02_S.IDO_YMD
					AND	K02_Z6.TSUKA_CD			= K02_S.TSUKA_CD 
				) AS ZEN_OUT_HEN_KKN
				,
				--==============================================================
				--	Z7	前月出金_返戻金(手数料口)
				--		68:返戻元金手数料		78:返戻利金手数料
				----------------------------------------------------
				(SELECT
					coalesce(SUM(K02_Z7.KKN_SHUKIN_KNGK),0)
				 FROM
					KIKIN_IDO K02_Z7
				 WHERE
						K02_Z7.KKN_IDO_KBN IN ('68','78')
					-- 利払日 ＜ 基準年月
					AND	SUBSTR(K02_Z7.RBR_YMD,1,6) < gKijunYm
					-- [[ 以下、基金異動履歴(K02_S)レコードとの結合条件 ]]
					AND	K02_Z7.ITAKU_KAISHA_CD	= K02_S.ITAKU_KAISHA_CD
					AND	K02_Z7.MGR_CD			= K02_S.MGR_CD
					AND	K02_Z7.RBR_KJT			= K02_S.RBR_KJT
					AND	K02_Z7.IDO_YMD			= K02_S.IDO_YMD
					AND	K02_Z7.TSUKA_CD			= K02_S.TSUKA_CD 
				) AS ZEN_OUT_HEN_TESU
				,
				--==============================================================
				--	Z8	前月出金_その他(基金口)
				--								92:出金(利金端数)
				----------------------------------------------------
				(SELECT
					coalesce(SUM(K02_Z8.KKN_SHUKIN_KNGK),0)
				 FROM
					KIKIN_IDO K02_Z8
				 WHERE
						K02_Z8.KKN_IDO_KBN = '92'
					-- 異動日(計上日) ＜ 基準年月
					AND	SUBSTR(K02_Z8.IDO_YMD,1,6) < gKijunYm
					-- [[ 以下、基金異動履歴(K02_S)レコードとの結合条件 ]]
					AND	K02_Z8.ITAKU_KAISHA_CD	= K02_S.ITAKU_KAISHA_CD
					AND	K02_Z8.MGR_CD			= K02_S.MGR_CD
					AND	K02_Z8.RBR_KJT			= K02_S.RBR_KJT
					AND	K02_Z8.IDO_YMD			= K02_S.IDO_YMD
					AND	K02_Z8.TSUKA_CD			= K02_S.TSUKA_CD 
				) AS ZEN_OUT_ETC_KKN
				,
				--==============================================================
				--	Z9	前月出金_その他(手数料口)
				--		94:出金(元金手数料端数)	96:出金(利金手数料端数)
				----------------------------------------------------
				(SELECT
					coalesce(SUM(K02_Z9.KKN_SHUKIN_KNGK),0)
				 FROM
					KIKIN_IDO K02_Z9
				 WHERE
						K02_Z9.KKN_IDO_KBN IN ('94','96')
					-- 異動日(計上日) ＜ 基準年月
					AND	SUBSTR(K02_Z9.IDO_YMD,1,6) < gKijunYm
					-- [[ 以下、基金異動履歴(K02_S)レコードとの結合条件 ]]
					AND	K02_Z9.ITAKU_KAISHA_CD	= K02_S.ITAKU_KAISHA_CD
					AND	K02_Z9.MGR_CD			= K02_S.MGR_CD
					AND	K02_Z9.RBR_KJT			= K02_S.RBR_KJT
					AND	K02_Z9.IDO_YMD			= K02_S.IDO_YMD
					AND	K02_Z9.TSUKA_CD			= K02_S.TSUKA_CD 
				) AS ZEN_OUT_ETC_TESU
			 FROM
				-- 基金異動履歴(K02_S) 
				-- 基金の請求書作成済である銘柄のみを対象とする
				-- (基金の請求書未作成時は、出金データは対象外)
				(SELECT
					 K02_S1.ITAKU_KAISHA_CD
					,K02_S1.MGR_CD
					,K02_S1.RBR_KJT
					,K02_S1.IDO_YMD
					,K02_S1.TSUKA_CD
				 FROM
					KIKIN_IDO K02_S1,
					(
					-- 基金の請求書作成済銘柄(回次)
					-- これとK02_S1を結合し、基金異動履歴-基金の請求書作成済のみ(K02_S)を抽出する
					 SELECT
						 K02_S2_1.ITAKU_KAISHA_CD
						,K02_S2_1.MGR_CD
						,K02_S2_1.RBR_KJT
						,K02_S2_1.TSUKA_CD
					 FROM
						KIKIN_IDO K02_S2_1
					 WHERE
							K02_S2_1.DATA_SAKUSEI_KBN >= '1'	-- 請求書出力済
						AND	K02_S2_1.KKN_IDO_KBN IN ('11','21','22')	-- 基金入金データ 11:入金(元金) 21:入金(利金) 22:入金(利金支払手数料)
 
					 GROUP BY
						 K02_S2_1.ITAKU_KAISHA_CD
						,K02_S2_1.MGR_CD
						,K02_S2_1.RBR_KJT
						,K02_S2_1.TSUKA_CD
					) K02_S2 
				 WHERE
						K02_S1.ITAKU_KAISHA_CD	= K02_S2.ITAKU_KAISHA_CD
					AND	K02_S1.MGR_CD			= K02_S2.MGR_CD
					AND K02_S1.RBR_KJT			= K02_S2.RBR_KJT
					AND K02_S1.TSUKA_CD			= K02_S2.TSUKA_CD
				) K02_S 
			 GROUP BY
				 K02_S.ITAKU_KAISHA_CD
				,K02_S.MGR_CD
				,K02_S.RBR_KJT
				,K02_S.IDO_YMD
				,K02_S.TSUKA_CD
			) K02_T 
		 GROUP BY
			 K02_T.ITAKU_KAISHA_CD
			,K02_T.MGR_CD
			,K02_T.TSUKA_CD
		) k02 ON (VMG1.ITAKU_KAISHA_CD = K02.ITAKU_KAISHA_CD AND VMG1.MGR_CD = K02.MGR_CD)
WHERE -- [[ 銘柄の抽出条件 ]]
			-- 銘柄_基本viewは、取消済銘柄、親銘柄、子銘柄(償還済) を除外済み
 VMG1.ITAKU_KAISHA_CD	= l_inItakuKaishaCd AND VMG1.JTK_KBN			NOT IN ('2','5') 	-- 2:副受託・5:自社発行銘柄を除外
  AND VMG1.MGR_STAT_KBN		= '1' -- 承認済銘柄を対象
  AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '') 			-- ISINコード付番済銘柄を対象
  AND VMG1.KK_KANYO_FLG		<> '2' -- 2:機構非関与方式(実質記番号銘柄)を除外
		-- [[ テーブルの結合条件 ]]
		-- [ 銘柄_基本view - 発行体マスタ ]
   -- [ 銘柄_基本view - 基金異動履歴 ]
   -- [[ 「顧客宛帳票出力指示」画面の抽出条件 ]]
  AND (coalesce(l_inHktCd::text, '') = ''	OR (VMG1.HKT_CD		= l_inHktCd)) 		-- ①発行体コード
  AND (coalesce(l_inKozaTenCd::text, '') = ''	OR (M01.KOZA_TEN_CD	= l_inKozaTenCd)) 	-- ②口座店店番
  AND (coalesce(l_inKozaTenCifcd::text, '') = ''	OR (trim(both M01.KOZA_TEN_CIFCD) = l_inKozaTenCifcd)) 	-- ③口座店CIFコード
  AND (coalesce(l_inMgrCd::text, '') = ''	OR (VMG1.MGR_CD		= l_inMgrCd)) 		-- ④銘柄コード
  AND (coalesce(l_inIsinCd::text, '') = ''	OR (VMG1.ISIN_CD	= l_inIsinCd)) 		-- ⑤ISINコード
 ORDER BY
		 VMG1.ITAKU_KAISHA_CD
		,VMG1.HKT_CD
		,coalesce(K02.TSUKA_CD,'JPY')
		,CASE WHEN VMG1.KK_HAKKO_CD='222000' THEN 				CASE WHEN sfCmIsNumeric(SUBSTR(VMG1.ISIN_CD, 9, 1))=0 THEN  '1'  ELSE '2' END   ELSE '0' END 
		,VMG1.HAKKO_YMD
		,VMG1.ISIN_CD 
	;
	  rec_meisai_2	RECORD := NULL;
	--==============================================================================*
--		メイン処理
--	 *==============================================================================
BEGIN
	IF DEBUG = 1 THEN
		CALL pkLog.debug(l_inUserId, l_inChohyoId, '○' || PROGRAM_ID || ' START');
		CALL pkLog.debug(l_inUserId, l_inChohyoId,
					'-------------------- 引数一覧 -----------------');
 		CALL pkLog.debug(l_inUserId, l_inChohyoId, '  l_inItakuKaishaCd = [' || l_inItakuKaishaCd || ']');
		CALL pkLog.debug(l_inUserId, l_inChohyoId, '  l_inUserId        = [' || l_inUserId || ']');
		CALL pkLog.debug(l_inUserId, l_inChohyoId, '  l_inChohyoKbn     = [' || l_inChohyoKbn || ']');
		CALL pkLog.debug(l_inUserId, l_inChohyoId, '  l_inGyomuYmd      = [' || l_inGyomuYmd || ']');
		CALL pkLog.debug(l_inUserId, l_inChohyoId, '  l_inHktCd         = [' || l_inHktCd || ']');
		CALL pkLog.debug(l_inUserId, l_inChohyoId, '  l_inKozaTenCd     = [' || l_inKozaTenCd || ']');
		CALL pkLog.debug(l_inUserId, l_inChohyoId, '  l_inKozaTenCifCd  = [' || l_inKozaTenCifCd || ']');
		CALL pkLog.debug(l_inUserId, l_inChohyoId, '  l_inMgrCd         = [' || l_inMgrCd || ']');
		CALL pkLog.debug(l_inUserId, l_inChohyoId, '  l_inIsinCd        = [' || l_inIsinCd || ']');
		CALL pkLog.debug(l_inUserId, l_inChohyoId, '  l_inKijunYm       = [' || l_inKijunYm || ']');
		CALL pkLog.debug(l_inUserId, l_inChohyoId, '  l_inTsuchiYmd     = [' || l_inTsuchiYmd || ']');
	END IF;
	-- 入力パラメータチェック 
	IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, l_inChohyoId, '1. 入力パラメータチェック');END IF;
	IF		coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
		OR	coalesce(trim(both l_inUserId)::text, '') = ''
		OR	coalesce(trim(both l_inChohyoKbn)::text, '') = ''
		OR	l_inChohyoKbn			NOT IN ('0','1')	-- 「帳票区分」0または1
		OR	coalesce(trim(both l_inGyomuYmd)::text, '') = ''
		OR (l_inChohyoKbn = '0' AND coalesce(trim(both l_inKijunYm)::text, '') = '')	-- 「基準年月」リアルの場合のみ必須
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, l_inChohyoId, '×' || PROGRAM_ID || ' END（入力パラメータエラー）');END IF;
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', PROGRAM_ID, '');
		RETURN;
	END IF;
	-- 初期設定 
	IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, l_inChohyoId, '2. 初期設定');END IF;
	--【リアル】
	IF l_inChohyoKbn = '0' THEN
		-- 2.1 基準年月 設定
		gKijunYm := trim(both l_inKijunYm);
		-- 2.2 通知日(西暦) 設定	(ex.「ZZZ9年Z9月Z9日」)
		IF coalesce(trim(both l_inTsuchiYmd)::text, '') = '' THEN
			gFrmTsuchiYmd := TSUCHI_YMD_DEF;
		ELSE
			gFrmTsuchiYmd := trim(both pkDate.seirekiChangeSuppressNenGappi(trim(both l_inTsuchiYmd)));
		END IF;
	--【バッチ】
	ELSE
		-- 基準年月 設定
		gKijunYm := substr(trim(both l_inGyomuYmd), 1, 6);
		-- 通知日(西暦) 設定
		gFrmTsuchiYmd := trim(both pkDate.getYokuBusinessYmd(trim(both l_inGyomuYmd)));
		gFrmTsuchiYmd := trim(both pkDate.seirekiChangeSuppressNenGappi(gFrmTsuchiYmd));
	END IF;
	--【通知日(西暦) 設定に失敗した場合】通知日(西暦)にデフォルトの通知日をセットして続行する。
	IF coalesce(gFrmTsuchiYmd::text, '') = '' OR SUBSTR(gFrmTsuchiYmd, 1, 2) = '99' THEN 		-- 西暦変換fncは失敗時に「99年[月日]」([]内は可変)を返す
		IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, l_inChohyoId, '  △通知日(西暦) 設定 失敗');END IF;
		gFrmTsuchiYmd := TSUCHI_YMD_DEF;
	END IF;
	-- 基準年月の前月末日 設定
	gZengetsumatsuYmd := pkDate.getZengetsumatsuYmd(gKijunYm || '01');
		-- 取得失敗すると困るので、例外等発生時は例外処理へ飛ばす。
	-- 取扱年月(西暦) 設定	(ex.「ZZZ9年Z9月分」)
	IF l_inChohyoId = 'IPX30001211' THEN
		gFrmToriYm := substr(pkDate.seirekiChangeSuppressNenGappi(gKijunYm || '01'), 1, 10) || '分';
	ELSIF l_inChohyoId = 'IPX30001212' THEN
		gFrmToriYm := substr(pkDate.seirekiChangeSuppressNenGappi(gKijunYm || '01'), 1, 10) || '異動分';
	END IF;
		-- 取得失敗しても困らないが「基準年月」に問題があるようでは困るので、例外等発生時は例外処理へ飛ばす。
	-- 自行_委託会社情報 設定
	BEGIN
		SELECT
			 VJ1.BANK_NM
			,VJ1.BUSHO_NM1
		INTO STRICT
			 gFrmBankNm
			,gFrmBushoNm1
		FROM
			VJIKO_ITAKU VJ1
		WHERE
			VJ1.KAIIN_ID = l_inItakuKaishaCd
		;
	EXCEPTION WHEN OTHERS THEN
		-- 自行_委託会社情報 取得失敗の場合、自行_委託会社情報にNULLをセットして続行する。
		IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, l_inChohyoId, '  △自行_委託会社情報 取得失敗：委託会社コード[' || l_inItakuKaishaCd || ']');END IF;
		gFrmBankNm		:= NULL;
		gFrmBushoNm1	:= NULL;
	END;
	-- 請求文章 設定
	gFrmBunsho	:= SPIPX012K00R01_createBun(l_inChohyoId, '00');
	-- 納付年月日取得(基準年月の翌月10日 休日の場合は翌営業日)
	gNofuYmd := pkDate.calcMonthKyujitsuKbn(gKijunYm || '10', 1, pkconstant.HORIDAY_SHORI_KBN_YOKUEI(), pkconstant.TOKYO_AREA_CD());
	gNofuYmd := pkDate.seirekiChangeSuppressNenGappi(gNofuYmd);
	gNofuYmd := '(' || gNofuYmd || '納付)';
	-- 取得データログ
	IF DEBUG = 1 THEN
		CALL pkLog.debug(l_inUserId, l_inChohyoId, '----- 設定値一覧 -----');
		CALL pkLog.debug(l_inUserId, l_inChohyoId, '  基準年月           = [' || gKijunYm || ']');
		CALL pkLog.debug(l_inUserId, l_inChohyoId, '  基準年月の前月末日 = [' || gZengetsumatsuYmd || ']');
		CALL pkLog.debug(l_inUserId, l_inChohyoId, '  通知日(西暦)       = [' || gFrmTsuchiYmd || ']');
		CALL pkLog.debug(l_inUserId, l_inChohyoId, '  取扱年月(西暦)     = [' || gFrmToriYm || ']');
		CALL pkLog.debug(l_inUserId, l_inChohyoId, '  銀行名称           = [' || gFrmBankNm || ']');
		CALL pkLog.debug(l_inUserId, l_inChohyoId, '  担当部署名称       = [' || gFrmBushoNm1 || ']');
		CALL pkLog.debug(l_inUserId, l_inChohyoId, '  請求文章           = [' || gFrmBunsho || ']');
	END IF;
	-- 帳票ワークの旧データ削除 
	IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, l_inChohyoId, '3. 帳票ワークの旧データ削除');END IF;
	DELETE FROM SREPORT_WK
	 WHERE	KEY_CD		= l_inItakuKaishaCd
		AND	USER_ID		= l_inUserId
		AND	CHOHYO_KBN	= l_inChohyoKbn
		AND	SAKUSEI_YMD	= l_inGyomuYmd
		AND	CHOHYO_ID	= l_inChohyoId
	;
	-- 帳票ワークテーブル登録処理 -ヘッダ 
	IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, l_inChohyoId, '4. 帳票ワークテーブル登録処理 -ヘッダ');END IF;
	CALL pkPrint.insertHeader(
				 l_inItakuKaishaCd
				,l_inUserId
				,l_inChohyoKbn
				,l_inGyomuYmd
				,l_inChohyoId
	);
	-- 帳票ワークテーブル登録処理 -データ 
	IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, l_inChohyoId, '5. 帳票ワークテーブル登録処理 -データ');END IF;
	-- 明細レコード登録
	FOR recMeisai IN  curMeisai LOOP
		-- 現在明細ログ
		IF DEBUG = 1 THEN
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '----- カーソル ' || gSeqNo || '件目 -----');
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  委託会社コード                = ' || recMeisai.ITAKU_KAISHA_CD);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  発行体コード                  = ' || recMeisai.HKT_CD);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  通貨コード                    = ' || recMeisai.TSUKA_CD);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  通貨名称                      = ' || recMeisai.TSUKA_NM);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  ISINコード                    = ' || recMeisai.ISIN_CD);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  銘柄コード                    = ' || recMeisai.MGR_CD);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  銘柄の正式名称                = ' || recMeisai.MGR_NM);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '[銘柄の発行体情報]');
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  発行体名称                    = ' || recMeisai.HKT_NM);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  送付先郵便番号                = ' || recMeisai.SFSK_POST_NO);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  送付先住所１                  = ' || recMeisai.ADD1);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  送付先住所２                  = ' || recMeisai.ADD2);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  送付先住所３                  = ' || recMeisai.ADD3);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  送付先担当部署                = ' || recMeisai.SFSK_BUSHO_NM);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '[金額(当月分)]');
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  入金_基金                     = ' || recMeisai.TOU_IN_KKN);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  入金_手数料                   = ' || recMeisai.TOU_IN_TESU);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  出金_基金                     = ' || recMeisai.TOU_OUT_KKN);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  出金_手数料                   = ' || recMeisai.TOU_OUT_TESU);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  出金_国税                     = ' || recMeisai.TOU_OUT_ZEI);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  出金_返戻(基金口)             = ' || recMeisai.TOU_OUT_HEN_KKN);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  出金_返戻(手数料口)           = ' || recMeisai.TOU_OUT_HEN_TESU);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  出金_その他(基金口)           = ' || recMeisai.TOU_OUT_ETC_KKN);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  出金_その他(手数料口)         = ' || recMeisai.TOU_OUT_ETC_TESU);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '[金額(前月以前分)]');
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  入金_基金                     = ' || recMeisai.ZEN_IN_KKN);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  入金_手数料                   = ' || recMeisai.ZEN_IN_TESU);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  出金_基金                     = ' || recMeisai.ZEN_OUT_KKN);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  出金_手数料                   = ' || recMeisai.ZEN_OUT_TESU);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  出金_国税                     = ' || recMeisai.ZEN_OUT_ZEI);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  出金_返戻(基金口)             = ' || recMeisai.ZEN_OUT_HEN_KKN);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  出金_返戻(手数料口)           = ' || recMeisai.ZEN_OUT_HEN_TESU);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  出金_その他(基金口)           = ' || recMeisai.ZEN_OUT_ETC_KKN);
			CALL pkLog.debug(l_inUserId, l_inChohyoId, '  出金_その他(手数料口)         = ' || recMeisai.ZEN_OUT_ETC_TESU);
		END IF;
		-- 宛名編集	【1件目または発行体コードがブレークした場合のみ】
		IF recMeisai.HKT_CD <> gKeyHktCd OR coalesce(gKeyHktCd::text, '') = ''
		THEN
			CALL pkIpaName.getMadoFutoAtenaYoko(
						 recMeisai.HKT_NM
						,recMeisai.SFSK_BUSHO_NM
						,gResult
						,gFrmAtena
			);
			-- キーを保存
			gKeyHktCd := recMeisai.HKT_CD;
		END IF;
		-- 前月末残高 算出　[前月までの入金計 - 前月までの出金計]
		-- << 基金口 >>
		gWkZenZndkKkn :=
				recMeisai.ZEN_IN_KKN 				-- 前月入金_基金
			 - (  recMeisai.ZEN_OUT_KKN 				-- 前月出金_基金
				+ recMeisai.ZEN_OUT_ZEI 				-- 前月出金_国税
				+ recMeisai.ZEN_OUT_HEN_KKN 			-- 前月出金_返戻金(基金口)
				+ recMeisai.ZEN_OUT_ETC_KKN)		-- 前月出金_その他(基金口)
		;
		-- << 手数料口 >>
		gWkZenZndkTesu :=
				recMeisai.ZEN_IN_TESU 				-- 前月入金_手数料
			 - (  recMeisai.ZEN_OUT_TESU 			-- 前月出金_手数料
				+ recMeisai.ZEN_OUT_HEN_TESU 		-- 前月出金_返戻金(手数料口)
				+ recMeisai.ZEN_OUT_ETC_TESU)		-- 前月出金_その他(手数料口)
		;
		-- 5.2.5 当月末残高 算出　[前月末残高 ＋ 当月分入金計 - 当月分出金計]
		-- << 基金口 >>
		gWkTouZndkKkn :=
				gWkZenZndkKkn 						-- 5.2.4 前月末残高 << 基金口 >>
			 +  recMeisai.TOU_IN_KKN 				-- 当月入金_基金
			 - (  recMeisai.TOU_OUT_KKN 				-- 当月出金_基金
				+ recMeisai.TOU_OUT_ZEI 				-- 当月出金_国税
				+ recMeisai.TOU_OUT_HEN_KKN 			-- 当月出金_返戻金(基金口)
				+ recMeisai.TOU_OUT_ETC_KKN)		-- 当月出金_その他(基金口)
		;
		-- << 手数料口 >>
		gWkTouZndkTesu :=							
				gWkZenZndkTesu 						-- 5.2.4 前月末残高 << 手数料口 >>
			 +  recMeisai.TOU_IN_TESU 				-- 当月入金_手数料
			 - (  recMeisai.TOU_OUT_TESU 			-- 当月出金_手数料
				+ recMeisai.TOU_OUT_HEN_TESU 		-- 当月出金_返戻金(手数料口)
				+ recMeisai.TOU_OUT_ETC_TESU)		-- 当月出金_その他(手数料口)
		;
		-- 出力対象となるかを判断する
--		   元利払基金残高報告書のときは　月末営業日の前月末時点で、全額償還していない銘柄または、
--		                                 前月末基金残高または、前月末手数料残高が残っている銘柄を出力対象とする。
--		   元利払基金残高報告書(基準年月異動分のみ)のときは、基準年月に元利金の受払した銘柄のみを出力対象とする。
		IF l_inChohyoId = 'IPX30001211' AND (0 < pkIpaZndk.getKjnZndk(recMeisai.ITAKU_KAISHA_CD, recMeisai.MGR_CD, gZengetsumatsuYmd, 3)
										OR gWkZenZndkKkn <> 0 OR gWkZenZndkTesu <> 0) THEN
			gWkOutFlg := 1;
		ELSIF l_inChohyoId = 'IPX30001212' AND (recMeisai.TOU_IN_KKN <> 0 OR recMeisai.TOU_IN_TESU <> 0
										OR recMeisai.TOU_OUT_KKN <> 0 OR recMeisai.TOU_OUT_TESU <> 0 OR recMeisai.TOU_OUT_ZEI <> 0
										OR recMeisai.TOU_OUT_HEN_KKN + recMeisai.TOU_OUT_HEN_TESU <> 0
										OR recMeisai.TOU_OUT_ETC_KKN + recMeisai.TOU_OUT_ETC_TESU <> 0) THEN
			gWkOutFlg := 1;
		ELSE
			gWkOutFlg := 0;
		END IF;
		IF gWkOutFlg = 1 THEN
			IF gSeqNo <> 0 THEN
				-- 発行体、通貨、静岡県債区分毎に静岡県債計を出力する
				IF recMeisai.ITAKU_KAISHA_CD <> rec_meisai_2.ITAKU_KAISHA_CD
					OR recMeisai.HKT_CD <> rec_meisai_2.HKT_CD
					OR recMeisai.TSUKA_CD <> rec_meisai_2.TSUKA_CD
					OR recMeisai.SHIZ_KBN <> rec_meisai_2.SHIZ_KBN THEN
						-- 静岡県債がブレイクしたので、静岡県債合計を出力する
						-- (静岡県債以外のときは公募・公債計は出力しない)
						IF rec_meisai_2.SHIZ_KBN <> '0' THEN
							IF rec_meisai_2.SHIZ_KBN = '1' THEN
								gKeiTitle := '公募計';
							ELSE
								gKeiTitle := '公債計';
							END IF;
							gSeqNo := gSeqNo + 1;
							
							-- Clear composite type
							v_item := ROW();
							v_item.l_inItem001 := gFrmTsuchiYmd;
							v_item.l_inItem002 := rec_meisai_2.HKT_CD;
							v_item.l_inItem003 := rec_meisai_2.SFSK_POST_NO;
							v_item.l_inItem004 := rec_meisai_2.ADD1;
							v_item.l_inItem005 := rec_meisai_2.ADD2;
							v_item.l_inItem006 := rec_meisai_2.ADD3;
							v_item.l_inItem007 := gFrmAtena2;
							v_item.l_inItem008 := gFrmBankNm;
							v_item.l_inItem009 := gFrmBushoNm1;
							v_item.l_inItem010 := gFrmToriYm;
							v_item.l_inItem011 := gFrmBunsho;
							v_item.l_inItem012 := rec_meisai_2.TSUKA_CD;
							v_item.l_inItem013 := rec_meisai_2.TSUKA_NM;
							v_item.l_inItem016 := gWkShizZenZndkKknKei;
							v_item.l_inItem017 := gWkShizZenZndkTesuKei;
							v_item.l_inItem018 := gWkShizTouInKknKei;
							v_item.l_inItem019 := gWkShizTouInTesuKei;
							v_item.l_inItem020 := gWkShizTouOutKknKei;
							v_item.l_inItem021 := gWkShizTouOutTesuKei;
							v_item.l_inItem022 := gWkShizTouOutZeiKei;
							v_item.l_inItem023 := gWkShizTouOutHenKei;
							v_item.l_inItem024 := gWkShizTouOutEtcKei;
							v_item.l_inItem025 := gWkShizTouZndkKknKei;
							v_item.l_inItem026 := gWkShizTouZndkTesuKei;
							v_item.l_inItem028 := gNofuYmd;
							v_item.l_inItem029 := rec_meisai_2.SHIZ_KBN;
							v_item.l_inItem030 := rec_meisai_2.HAKKO_YMD;
							v_item.l_inItem031 := gKeiTitle;
							
							CALL pkPrint.insertData(
									 l_inKeyCd		=> l_inItakuKaishaCd
									,l_inUserId		=> l_inUserId
									,l_inChohyoKbn	=> l_inChohyoKbn
									,l_inSakuseiYmd	=> l_inGyomuYmd
									,l_inChohyoId	=> l_inChohyoId
									,l_inSeqNo		=> gSeqNo
									,l_inHeaderFlg  => '1'
									,l_inItem		=> v_item
									,l_inKousinId	=> l_inUserId
									,l_inSakuseiId	=> l_inUserId
								);
							-- 静岡県債合計クリア
							gWkShizZenZndkKknKei  := 0;
							gWkShizZenZndkTesuKei := 0;
							gWkShizTouInKknKei := 0;
							gWkShizTouInTesuKei := 0;
							gWkShizTouOutKknKei := 0;
							gWkShizTouOutTesuKei := 0;
							gWkShizTouOutZeiKei := 0;
							gWkShizTouOutHenKei := 0;
							gWkShizTouOutEtcKei := 0;
							gWkShizTouZndkKknKei := 0;
							gWkShizTouZndkTesuKei := 0;
						END IF;
						-- 発行体、通貨毎に発行体計を出力する
						IF recMeisai.ITAKU_KAISHA_CD <> rec_meisai_2.ITAKU_KAISHA_CD
							OR recMeisai.HKT_CD <> rec_meisai_2.HKT_CD
							OR recMeisai.TSUKA_CD <> rec_meisai_2.TSUKA_CD THEN
								-- 発行体がブレイクしたので、発行体合計を出力する
								IF rec_meisai_2.SHIZ_KBN = '0' THEN
									gShizKbn := rec_meisai_2.SHIZ_KBN;
								ELSE
									gShizKbn := '9';
								END IF;
								gKeiTitle := '発行体計';
								gSeqNo := gSeqNo + 1;
								-- Clear composite type

								v_item := ROW();

								v_item.l_inItem001 := gFrmTsuchiYmd;

								v_item.l_inItem002 := rec_meisai_2.HKT_CD;

								v_item.l_inItem003 := rec_meisai_2.SFSK_POST_NO;

								v_item.l_inItem004 := rec_meisai_2.ADD1;

								v_item.l_inItem005 := rec_meisai_2.ADD2;

								v_item.l_inItem006 := rec_meisai_2.ADD3;

								v_item.l_inItem007 := gFrmAtena2;

								v_item.l_inItem008 := gFrmBankNm;

								v_item.l_inItem009 := gFrmBushoNm1;

								v_item.l_inItem010 := gFrmToriYm;

								v_item.l_inItem011 := gFrmBunsho;

								v_item.l_inItem012 := rec_meisai_2.TSUKA_CD;

								v_item.l_inItem013 := rec_meisai_2.TSUKA_NM;

								v_item.l_inItem016 := gWkHktZenZndkKknKei;

								v_item.l_inItem017 := gWkHktZenZndkTesuKei;

								v_item.l_inItem018 := gWkHktTouInKknKei;

								v_item.l_inItem019 := gWkHktTouInTesuKei;

								v_item.l_inItem020 := gWkHktTouOutKknKei;

								v_item.l_inItem021 := gWkHktTouOutTesuKei;

								v_item.l_inItem022 := gWkHktTouOutZeiKei;

								v_item.l_inItem023 := gWkHktTouOutHenKei;

								v_item.l_inItem024 := gWkHktTouOutEtcKei;

								v_item.l_inItem025 := gWkHktTouZndkKknKei;

								v_item.l_inItem026 := gWkHktTouZndkTesuKei;

								v_item.l_inItem028 := gNofuYmd;

								v_item.l_inItem029 := gShizKbn;

								v_item.l_inItem030 := rec_meisai_2.HAKKO_YMD;

								v_item.l_inItem031 := gKeiTitle;

								CALL pkPrint.insertData(
										 l_inKeyCd		=> l_inItakuKaishaCd 					-- 識別コード
										,l_inUserId		=> l_inUserId 							-- ユーザID
										,l_inChohyoKbn	=> l_inChohyoKbn 						-- 帳票区分
										,l_inSakuseiYmd	=> l_inGyomuYmd 							-- 作成年月日
										,l_inChohyoId	=> l_inChohyoId 							-- 帳票ID
										,l_inSeqNo		=> gSeqNo 								-- 連番
										,l_inHeaderFlg  => '1'									-- ヘッダフラグ
										,l_inItem		=> v_item
					,l_inKousinId	=> l_inUserId 							-- 更新者ID
										,l_inSakuseiId	=> l_inUserId 							-- 作成者ID
				);
								-- 発行体合計クリア
								gWkHktZenZndkKknKei  := 0;
								gWkHktZenZndkTesuKei := 0;
								gWkHktTouInKknKei := 0;
								gWkHktTouInTesuKei := 0;
								gWkHktTouOutKknKei := 0;
								gWkHktTouOutTesuKei := 0;
								gWkHktTouOutZeiKei := 0;
								gWkHktTouOutHenKei := 0;
								gWkHktTouOutEtcKei := 0;
								gWkHktTouZndkKknKei := 0;
								gWkHktTouZndkTesuKei := 0;
					END IF;
				END IF;
			END IF;
			-- 静岡県債区分計と発行体計の計算出力処理
			IF recMeisai.SHIZ_KBN <> '0' THEN
				-- 静岡県債合計足しこみ
				gWkShizZenZndkKknKei  := gWkShizZenZndkKknKei + gWkZenZndkKkn;
				gWkShizZenZndkTesuKei := gWkShizZenZndkTesuKei + gWkZenZndkTesu;
				gWkShizTouInKknKei := gWkShizTouInKknKei + recMeisai.TOU_IN_KKN;
				gWkShizTouInTesuKei := gWkShizTouInTesuKei + recMeisai.TOU_IN_TESU;
				gWkShizTouOutKknKei := gWkShizTouOutKknKei + recMeisai.TOU_OUT_KKN;
				gWkShizTouOutTesuKei := gWkShizTouOutTesuKei + recMeisai.TOU_OUT_TESU;
				gWkShizTouOutZeiKei := gWkShizTouOutZeiKei + recMeisai.TOU_OUT_ZEI;
				gWkShizTouOutHenKei := gWkShizTouOutHenKei + recMeisai.TOU_OUT_HEN_KKN + recMeisai.TOU_OUT_HEN_TESU;
				gWkShizTouOutEtcKei := gWkShizTouOutEtcKei + recMeisai.TOU_OUT_ETC_KKN + recMeisai.TOU_OUT_ETC_TESU;
				gWkShizTouZndkKknKei := gWkShizTouZndkKknKei + gWkTouZndkKkn;
				gWkShizTouZndkTesuKei := gWkShizTouZndkTesuKei + gWkTouZndkTesu;
			END IF;
			--発行体合計足しこみ
			gWkHktZenZndkKknKei  := gWkHktZenZndkKknKei + gWkZenZndkKkn;
			gWkHktZenZndkTesuKei := gWkHktZenZndkTesuKei + gWkZenZndkTesu;
			gWkHktTouInKknKei := gWkHktTouInKknKei + recMeisai.TOU_IN_KKN;
			gWkHktTouInTesuKei := gWkHktTouInTesuKei + recMeisai.TOU_IN_TESU;
			gWkHktTouOutKknKei := gWkHktTouOutKknKei + recMeisai.TOU_OUT_KKN;
			gWkHktTouOutTesuKei := gWkHktTouOutTesuKei + recMeisai.TOU_OUT_TESU;
			gWkHktTouOutZeiKei := gWkHktTouOutZeiKei + recMeisai.TOU_OUT_ZEI;
			gWkHktTouOutHenKei := gWkHktTouOutHenKei + recMeisai.TOU_OUT_HEN_KKN + recMeisai.TOU_OUT_HEN_TESU;
			gWkHktTouOutEtcKei := gWkHktTouOutEtcKei + recMeisai.TOU_OUT_ETC_KKN + recMeisai.TOU_OUT_ETC_TESU;
			gWkHktTouZndkKknKei := gWkHktTouZndkKknKei + gWkTouZndkKkn;
			gWkHktTouZndkTesuKei := gWkHktTouZndkTesuKei + gWkTouZndkTesu;
			-- 帳票ワークへデータを追加
			gSeqNo := gSeqNo + 1;
			gKeiTitle := '';
			-- Clear composite type

			v_item := ROW();

			v_item.l_inItem001 := gFrmTsuchiYmd;

			v_item.l_inItem002 := recMeisai.HKT_CD;

			v_item.l_inItem003 := recMeisai.SFSK_POST_NO;

			v_item.l_inItem004 := recMeisai.ADD1;

			v_item.l_inItem005 := recMeisai.ADD2;

			v_item.l_inItem006 := recMeisai.ADD3;

			v_item.l_inItem007 := gFrmAtena;

			v_item.l_inItem008 := gFrmBankNm;

			v_item.l_inItem009 := gFrmBushoNm1;

			v_item.l_inItem010 := gFrmToriYm;

			v_item.l_inItem011 := gFrmBunsho;

			v_item.l_inItem012 := recMeisai.TSUKA_CD;

			v_item.l_inItem013 := recMeisai.TSUKA_NM;

			v_item.l_inItem014 := recMeisai.ISIN_CD;

			v_item.l_inItem015 := recMeisai.MGR_NM;

			v_item.l_inItem016 := gWkZenZndkKkn;

			v_item.l_inItem017 := gWkZenZndkTesu;

			v_item.l_inItem018 := recMeisai.TOU_IN_KKN;

			v_item.l_inItem019 := recMeisai.TOU_IN_TESU;

			v_item.l_inItem020 := recMeisai.TOU_OUT_KKN;

			v_item.l_inItem021 := recMeisai.TOU_OUT_TESU;

			v_item.l_inItem022 := recMeisai.TOU_OUT_ZEI;

			v_item.l_inItem023 := recMeisai.TOU_OUT_HEN_KKN
										+ recMeisai.TOU_OUT_HEN_TESU;

			v_item.l_inItem024 := recMeisai.TOU_OUT_ETC_KKN
										+ recMeisai.TOU_OUT_ETC_TESU;

			v_item.l_inItem025 := gWkTouZndkKkn;

			v_item.l_inItem026 := gWkTouZndkTesu;

			v_item.l_inItem028 := gNofuYmd;

			v_item.l_inItem029 := recMeisai.SHIZ_KBN;

			v_item.l_inItem030 := recMeisai.HAKKO_YMD;

			v_item.l_inItem031 := gKeiTitle;

			CALL pkPrint.insertData(
					 l_inKeyCd		=> l_inItakuKaishaCd 					-- 識別コード
					,l_inUserId		=> l_inUserId 							-- ユーザID
					,l_inChohyoKbn	=> l_inChohyoKbn 						-- 帳票区分
					,l_inSakuseiYmd	=> l_inGyomuYmd 							-- 作成年月日
					,l_inChohyoId	=> l_inChohyoId 							-- 帳票ID
					,l_inSeqNo		=> gSeqNo 								-- 連番
					,l_inHeaderFlg  => '1'									-- ヘッダフラグ
					,l_inItem		=> v_item
					,l_inKousinId	=> l_inUserId 							-- 更新者ID
					,l_inSakuseiId	=> l_inUserId 							-- 作成者ID
				);
			-- 呼び出したレコードを２へ退避する。
			rec_meisai_2 := recMeisai;
			gFrmAtena2 := gFrmAtena;
		END IF;
	END LOOP;
	IF gSeqNo <> 0 THEN
		-- 最終合計行の出力
		IF rec_meisai_2.SHIZ_KBN <> '0' THEN
			IF rec_meisai_2.SHIZ_KBN = '1' THEN
				gKeiTitle := '公募計';
			ELSE
				gKeiTitle := '公債計';
			END IF;
			gSeqNo := gSeqNo + 1;
			-- Clear composite type

			v_item := ROW();

			v_item.l_inItem001 := gFrmTsuchiYmd;

			v_item.l_inItem002 := rec_meisai_2.HKT_CD;

			v_item.l_inItem003 := rec_meisai_2.SFSK_POST_NO;

			v_item.l_inItem004 := rec_meisai_2.ADD1;

			v_item.l_inItem005 := rec_meisai_2.ADD2;

			v_item.l_inItem006 := rec_meisai_2.ADD3;

			v_item.l_inItem007 := gFrmAtena2;

			v_item.l_inItem008 := gFrmBankNm;

			v_item.l_inItem009 := gFrmBushoNm1;

			v_item.l_inItem010 := gFrmToriYm;

			v_item.l_inItem011 := gFrmBunsho;

			v_item.l_inItem012 := rec_meisai_2.TSUKA_CD;

			v_item.l_inItem013 := rec_meisai_2.TSUKA_NM;

			v_item.l_inItem016 := gWkShizZenZndkKknKei;

			v_item.l_inItem017 := gWkShizZenZndkTesuKei;

			v_item.l_inItem018 := gWkShizTouInKknKei;

			v_item.l_inItem019 := gWkShizTouInTesuKei;

			v_item.l_inItem020 := gWkShizTouOutKknKei;

			v_item.l_inItem021 := gWkShizTouOutTesuKei;

			v_item.l_inItem022 := gWkShizTouOutZeiKei;

			v_item.l_inItem023 := gWkShizTouOutHenKei;

			v_item.l_inItem024 := gWkShizTouOutEtcKei;

			v_item.l_inItem025 := gWkShizTouZndkKknKei;

			v_item.l_inItem026 := gWkShizTouZndkTesuKei;

			v_item.l_inItem028 := gNofuYmd;

			v_item.l_inItem029 := rec_meisai_2.SHIZ_KBN;

			v_item.l_inItem030 := rec_meisai_2.HAKKO_YMD;

			v_item.l_inItem031 := gKeiTitle;

			CALL pkPrint.insertData(
					 l_inKeyCd		=> l_inItakuKaishaCd 					-- 識別コード
					,l_inUserId		=> l_inUserId 							-- ユーザID
					,l_inChohyoKbn	=> l_inChohyoKbn 						-- 帳票区分
					,l_inSakuseiYmd	=> l_inGyomuYmd 							-- 作成年月日
					,l_inChohyoId	=> l_inChohyoId 							-- 帳票ID
					,l_inSeqNo		=> gSeqNo 								-- 連番
					,l_inHeaderFlg  => '1'									-- ヘッダフラグ
					,l_inItem		=> v_item
					,l_inKousinId	=> l_inUserId 							-- 更新者ID
					,l_inSakuseiId	=> l_inUserId 							-- 作成者ID
				);
		END IF;
		IF rec_meisai_2.SHIZ_KBN = '0' THEN
			gShizKbn := rec_meisai_2.SHIZ_KBN;
		ELSE
			gShizKbn := '9';
		END IF;
		gKeiTitle := '発行体計';
		gSeqNo := gSeqNo + 1;
		-- Clear composite type

		v_item := ROW();

		v_item.l_inItem001 := gFrmTsuchiYmd;

		v_item.l_inItem002 := rec_meisai_2.HKT_CD;

		v_item.l_inItem003 := rec_meisai_2.SFSK_POST_NO;

		v_item.l_inItem004 := rec_meisai_2.ADD1;

		v_item.l_inItem005 := rec_meisai_2.ADD2;

		v_item.l_inItem006 := rec_meisai_2.ADD3;

		v_item.l_inItem007 := gFrmAtena2;

		v_item.l_inItem008 := gFrmBankNm;

		v_item.l_inItem009 := gFrmBushoNm1;

		v_item.l_inItem010 := gFrmToriYm;

		v_item.l_inItem011 := gFrmBunsho;

		v_item.l_inItem012 := rec_meisai_2.TSUKA_CD;

		v_item.l_inItem013 := rec_meisai_2.TSUKA_NM;

		v_item.l_inItem016 := gWkHktZenZndkKknKei;

		v_item.l_inItem017 := gWkHktZenZndkTesuKei;

		v_item.l_inItem018 := gWkHktTouInKknKei;

		v_item.l_inItem019 := gWkHktTouInTesuKei;

		v_item.l_inItem020 := gWkHktTouOutKknKei;

		v_item.l_inItem021 := gWkHktTouOutTesuKei;

		v_item.l_inItem022 := gWkHktTouOutZeiKei;

		v_item.l_inItem023 := gWkHktTouOutHenKei;

		v_item.l_inItem024 := gWkHktTouOutEtcKei;

		v_item.l_inItem025 := gWkHktTouZndkKknKei;

		v_item.l_inItem026 := gWkHktTouZndkTesuKei;

		v_item.l_inItem028 := gNofuYmd;

		v_item.l_inItem029 := gShizKbn;

		v_item.l_inItem030 := rec_meisai_2.HAKKO_YMD;

		v_item.l_inItem031 := gKeiTitle;

		CALL pkPrint.insertData(
					 l_inKeyCd		=> l_inItakuKaishaCd 					-- 識別コード
					,l_inUserId		=> l_inUserId 							-- ユーザID
					,l_inChohyoKbn	=> l_inChohyoKbn 						-- 帳票区分
					,l_inSakuseiYmd	=> l_inGyomuYmd 							-- 作成年月日
					,l_inChohyoId	=> l_inChohyoId 							-- 帳票ID
					,l_inSeqNo		=> gSeqNo 								-- 連番
					,l_inHeaderFlg  => '1'									-- ヘッダフラグ
					,l_inItem		=> v_item
					,l_inKousinId	=> l_inUserId 							-- 更新者ID
					,l_inSakuseiId	=> l_inUserId 							-- 作成者ID
				);
		IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, l_inChohyoId, '☆元利払基金残高報告書　登録件数：' || gSeqNo || ' 件');END IF;
	-- 「対象データなし」レコード登録
	ELSE
		IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, l_inChohyoId, '☆元利払基金残高報告書　対象データなしを登録');END IF;
		-- バッチの場合、「対象データなし」レコードのPDF出力はしないが、帳票ワークには登録する。
		-- 当プロシージャの戻り値が2:対象データなし の場合「バッチ帳票印刷管理」テーブルに登録されないので
		-- バッチ帳票出力画面から出力できない。
		gRtnCd := NODATA;
		-- 帳票ワークへデータを追加
		-- Clear composite type

		v_item := ROW();

		v_item.l_inItem001 := gFrmTsuchiYmd;

		v_item.l_inItem010 := gFrmToriYm;

		v_item.l_inItem027 := '対象データなし';

		v_item.l_inItem028 := gNofuYmd;

		CALL pkPrint.insertData(
					 l_inKeyCd		=> l_inItakuKaishaCd 	-- 識別コード
					,l_inUserId		=> l_inUserId 			-- ユーザID
					,l_inChohyoKbn	=> l_inChohyoKbn 		-- 帳票区分
					,l_inSakuseiYmd	=> l_inGyomuYmd 			-- 作成年月日
					,l_inChohyoId	=> l_inChohyoId 			-- 帳票ID
					,l_inSeqNo		=> 1					-- 連番
					,l_inHeaderFlg	=> '1'					-- ヘッダフラグ
					,l_inItem		=> v_item
					,l_inKousinId	=> l_inUserId 			-- 更新者ID
					,l_inSakuseiId	=> l_inUserId 			-- 作成者ID
				);
	END IF;
	-- 正常終了処理 
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, l_inChohyoId, '◎' || PROGRAM_ID || ' END');END IF;
	--==============================================================================*
--		例外処理
--	 *==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', PROGRAM_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', PROGRAM_ID, 'SQLERRM:' || SQLERRM);
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLERRM;
		IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, l_inChohyoId, '×' || PROGRAM_ID || ' END（例外発生）');END IF;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipx012k00r01 ( l_inItakuKaishaCd TEXT  ,l_inUserId TEXT  ,l_inChohyoKbn TEXT  ,l_inGyomuYmd TEXT  ,l_inChohyoId TEXT  ,l_inHktCd TEXT  ,l_inKozaTenCd TEXT  ,l_inKozaTenCifCd TEXT  ,l_inMgrCd TEXT  ,l_inIsinCd TEXT  ,l_inKijunYm TEXT  ,l_inTsuchiYmd TEXT  ,l_outSqlCode OUT numeric  ,l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spipx012k00r01_createbun ( 
	l_inReportID TEXT ,
	l_inPatternCd BUN.BUN_PATTERN_CD%TYPE ,
	l_inUserId    text DEFAULT NULL,
  	l_inChohyoId  text DEFAULT NULL,
  	DEBUG         numeric  DEFAULT 0
	) RETURNS varchar AS $body$
DECLARE

	aryBun	pkIpaBun.BUN_ARRAY;
	wkBun	varchar(200) := NULL;
BEGIN
	-- 請求文章の取得
	aryBun := pkIpaBun.getBun(l_inReportID, l_inPatternCd);
	IF coalesce(aryBun::text, '') = '' OR coalesce(cardinality(aryBun), 0) = 0 THEN
		RAISE EXCEPTION 'no_data_err' USING ERRCODE = '50001';
	END IF;
	FOR i IN 0 .. coalesce(cardinality(aryBun), 0) - 1 LOOP
		-- 100byteまで全角スペース埋めして、請求文章を連結
		wkBun := wkBun || RPAD(aryBun[i], 100, '　');
	END LOOP;
	RETURN wkBun;
EXCEPTION
	-- 請求文章取得失敗の場合、NULLを設定して続行する。
	WHEN OTHERS THEN
		IF DEBUG = 1 THEN
			CALL pkLog.debug(l_inUserId, l_inChohyoId,
			'  △請求文章 設定 失敗：帳票ID[' || l_inReportID || '] 文章パターン[' || l_inPatternCd || ']');
		END IF;
		RETURN NULL;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spipx012k00r01_createbun ( l_inReportID TEXT ,l_inPatternCd BUN.BUN_PATTERN_CD%TYPE ) FROM PUBLIC;