




CREATE OR REPLACE FUNCTION sfipxb08k15r01 ( l_inIfId GAIBU_IF_KANRI.IF_ID%TYPE,			-- 外部IFID
 l_inTokoDaikoKbn TEXT 									-- 当行・事務代行区分　'1'：当行，'2'：事務代行
 ) RETURNS integer AS $body$
DECLARE

/**
 * 著作権:Copyright(c)2016
 * 会社名:JIP
 *
 * 概  要:	（１） 銘柄の新規登録情報、変更情報を債券決済代行システムに連携するデータを作成する。
 *			（２） 以下のデータを作成対象とする。
 *					・当行分は、機構非関与銘柄の新規登録情報、変更情報
 *					・事務代行分は、全銘柄の新規登録情報、変更情報
 *					・特例社債の親銘柄および現登債銘柄を除く
 *			（３） パッケージの「機構非関与銘柄情報」テーブルを利用して登録するが、事務代行の機構関与銘柄も登録される。
 *			（４） 作成したデータは機構非関与銘柄情報２に登録し、後続処理で債券決済代行システムに連携するデータとしてメッセージ送信（MQ）される。
 *
 * @author 横尾 隆児
 * @version $Id:$
 *
 * @param l_inIfId				外部IFID
 * @param l_inTokoDaikoKbn		当行・事務代行区分
 * @return INTEGER 0:正常、99:異常、それ以外：エラー
 *
 ***************************************************************************
 * ログ:
 *	日付	開発者名		目的
 * -------------------------------------------------------------------------
 * 2016.12.15 横尾			新規作成
 ***************************************************************************
*/
	/*==============================================================================*/

	/*					定数定義													*/

	/*==============================================================================*/

	-- ファンクションＩＤ
	C_FUNCTION_ID			CONSTANT	varchar(50)	:= 'SFIPXB08K15R01';
	tSPACE					CONSTANT	char(1)			:= ' ';
	/*==============================================================================*/

	/*					変数定義													*/

	/*==============================================================================*/

	gGyomuYmd				char(8)							:= '';		-- 業務日付
	gYokuEigyoYmd			char(8)							:= '';		-- 翌営業日
	gResult					integer							:= 0;		-- 共通部品の戻り値
	gDataNo					integer							:= 0;		-- データレコード件数
	/* MG2  銘柄_利払回次テーブル */

	g_RBR_KJT_IMA				MGR_RBRKIJ.RBR_KJT%TYPE;				--利払期日(今回)
	g_RIRITSU_IMA				MGR_RBRKIJ.RIRITSU%TYPE;				--利率(今回)
	g_TSUKARISHI_KNGK_IMA		MGR_RBRKIJ.TSUKARISHI_KNGK%TYPE;		--1通貨あたりの利子金額(今回)
	g_RBR_KJT_TUG				MGR_RBRKIJ.RBR_KJT%TYPE;				--利払期日(次回)
	g_RIRITSU_TUG				MGR_RBRKIJ.RIRITSU%TYPE;				--利率(次回)
	g_TSUKARISHI_KNGK_TUG		MGR_RBRKIJ.TSUKARISHI_KNGK%TYPE;		--1通貨あたりの利子金額(次回)
	g_RBR_YMD					MGR_RBRKIJ.RBR_YMD%TYPE;				--利払期日
	g_LAST_SHOKAN_KJT			MGR_RBRKIJ.RBR_YMD%TYPE;				--最終償還期日
	g_LAST_RIRITSU				MGR_RBRKIJ.RIRITSU%TYPE;				--最終回利率
	g_LAST_TSUKARISHI_KNGK		MGR_RBRKIJ.TSUKARISHI_KNGK%TYPE;		--最終回1通貨あたりの利子金額
	
	/* MG3  銘柄_償還回次テーブル */

	g_SHOKAN_KJT				MGR_SHOKIJ.SHOKAN_KJT%TYPE;				--償還期日
	g_SHOKAN_YMD				MGR_SHOKIJ.SHOKAN_YMD%TYPE;				--償還年月日
	g_FUNIT_GENSAI_KNGK			MGR_SHOKIJ.FUNIT_GENSAI_KNGK%TYPE;		--振替単位元本減債金額
	g_FACTOR					MGR_SHOKIJ.FACTOR%TYPE;					--ファクター
	g_SHOKAN_KJT_MAE			MGR_SHOKIJ.SHOKAN_KJT%TYPE;				--償還期日(前回)
	g_FUNIT_GENSAI_KNGK_MAE		MGR_SHOKIJ.FUNIT_GENSAI_KNGK%TYPE;		--振替単位元本減債金額(前回)
	g_FACTOR_MAE				MGR_SHOKIJ.FACTOR%TYPE;					--ファクター(前回)
	g_SHOKAN_KJT_IMA			MGR_SHOKIJ.SHOKAN_KJT%TYPE;				--償還期日(今回)
	g_FUNIT_GENSAI_KNGK_IMA		MGR_SHOKIJ.FUNIT_GENSAI_KNGK%TYPE;		--振替単位元本減債金額(今回)
	g_FACTOR_IMA				MGR_SHOKIJ.FACTOR%TYPE;					--ファクター(今回)
	g_SHOKAN_KJT_TUG			MGR_SHOKIJ.SHOKAN_KJT%TYPE;				--償還期日(次回)
	g_FUNIT_GENSAI_KNGK_TUG		MGR_SHOKIJ.FUNIT_GENSAI_KNGK%TYPE;		--振替単位元本減債金額(次回)
	g_FACTOR_TUG				MGR_SHOKIJ.FACTOR%TYPE;					--ファクター(次回)
	/* MG21 期中銘柄変更(銘柄)テーブル */

	g_ETCKAIGAI_RBR_YMD			UPD_MGR_KHN.ETCKAIGAI_RBR_YMD%TYPE;		--その他海外実利払日
	
	/* MG23 期中銘柄変更(償還)テーブル */

	g_TSUKARISHI_KNGK23			UPD_MGR_SHN.TSUKARISHI_KNGK%TYPE;		--1通貨あたりの利子金額
	g_ST_PUTKOSHIKIKAN_YMD		UPD_MGR_SHN.ST_PUTKOSHIKIKAN_YMD%TYPE;	--行使期間開始日
	g_ED_PUTKOSHIKIKAN_YMD		UPD_MGR_SHN.ED_PUTKOSHIKIKAN_YMD%TYPE;	--行使期間終了日
	
	/* 機構非関与銘柄情報提供テーブル */

	g_MGR_KIKOHIKANYO			MGR_KIKOHIKANYO%ROWTYPE;				--機構非関与銘柄情報提供テーブル
	/*==============================================================================*/

	/*					例外定義													*/

	/*==============================================================================*/

	/*==============================================================================*/

	/*					カーソル定義												*/

	/*==============================================================================*/

	-- 機構非関与銘柄情報SELECT
	curKkHikanyoMgr CURSOR FOR
		SELECT
			AM.ITAKU_KAISHA_CD,														-- 委託会社コード
			AM.MGR_CD,																-- 銘柄コード
			AM.ISIN_CD,																-- ＩＳＩＮコード
			coalesce(trim(both AM.MGR_NM),'　')						as MGR_NM,				-- 銘柄の正式名称
			RPAD(coalesce(trim(both AM.KK_HAKKOSHA_RNM),'　'), 16, '　')		as HAKKOSHA_RNM,-- 発行者略称
			RPAD(coalesce(trim(both AM.KAIGO_ETC),'　'), 20, '　')			as KAIGO_ETC,	-- 回号等
			SFREPLACEZENKAKU(AM.BOSHU_KBN)					as BOSHU_KBN_RNM,		-- 募集区分略称
			'　ＳＢ'										as FIXDISPLAY,			-- 固定表示
			AM.HOSHO_KBN,															-- 保証区分
			AM.TANPO_KBN,															-- 担保区分
			AM.PARTHAKKO_UMU_FLG,													-- 分割発行有無フラグ
			AM.GODOHAKKO_FLG,														-- 合同発行フラグ
			AM.RETSUTOKU_UMU_FLG,													-- 劣後特約有無フラグ
			AM.SKNNZISNTOKU_UMU_FLG,												-- 責任財産限定特約有無フラグ
			AM.SAIKEN_SHURUI,														-- 債権種類
			AM.KK_HAKKO_CD,															-- 機構発行体コード
			AM.BOSHU_ST_YMD,														-- 募集開始日
			AM.HAKKO_YMD									as HRKM_YMD,			-- 払込日
			AM.KAKUSHASAI_KNGK,														-- 各社債の金額
			AM.UCHIKIRI_HAKKO_FLG,													-- 打切発行フラグ
			AM.SHASAI_TOTAL,														-- 社債の総額
			AM.HAKKO_TSUKA_CD,														-- 発行通貨
			AM.HAKKODAIRI_CD,														-- 発行代理人コード
			AM.SHRDAIRI_CD,															-- 支払代理人コード
			AM.SKN_KESSAI_CD,														-- 資金決済会社コード
			AM.KK_KANYO_FLG,														-- 機構関与方式採用フラグ
			AM.KOBETSU_SHONIN_SAIYO_FLG,											-- 個別承認採用フラグ
			AM.KYUJITSU_KBN,														-- 休日処理区分
			AM.KYUJITSU_LD_FLG								as LD_FLG,				-- ロンドン参照フラグ
			AM.KYUJITSU_NY_FLG								as NY_FLG,				-- ニューヨーク参照フラグ
			AM.KYUJITSU_ETC_FLG								as ETCKAIGAI_FLG,		-- その他海外参照フラグ
			AM.RITSUKE_WARIBIKI_KBN,												-- 利付割引区分
			AM.RBR_TSUKA_CD,														-- 利払通貨
			AM.RBR_KJT_MD1,															-- 利払期日（ＭＤ）（１）
			AM.RBR_KJT_MD2,															-- 利払期日（ＭＤ）（２）
			AM.RBR_KJT_MD3,															-- 利払期日（ＭＤ）（３）
			AM.RBR_KJT_MD4,															-- 利払期日（ＭＤ）（４）
			AM.RBR_KJT_MD5,															-- 利払期日（ＭＤ）（５）
			AM.RBR_KJT_MD6,															-- 利払期日（ＭＤ）（６）
			AM.RBR_KJT_MD7,															-- 利払期日（ＭＤ）（７）
			AM.RBR_KJT_MD8,															-- 利払期日（ＭＤ）（８）
			AM.RBR_KJT_MD9,															-- 利払期日（ＭＤ）（９）
			AM.RBR_KJT_MD10,														-- 利払期日（ＭＤ）（１０）
			AM.RBR_KJT_MD11,														-- 利払期日（ＭＤ）（１１）
			AM.RBR_KJT_MD12,														-- 利払期日（ＭＤ）（１２）
			AM.ST_RBR_KJT,															-- 初回利払期日
			AM.LAST_RBR_FLG,														-- 最終利払有無フラグ
			AM.SHOKAN_TSUKA_CD,														-- 償還通貨
			AM.KAWASE_RATE,															-- 為替レート
			AM.FULLSHOKAN_KJT,														-- 満期償還期日
			AM.TEKIYO_END_YMD,														-- 適用終了日
			AM.NEWISIN_CD,															-- 新ＩＳＩＮコード
			AM.CALLALL_UMU_FLG,														-- コールオプション有無フラグ（全額償還）
			CASE WHEN AM.SHOKAN_METHOD_CD='2' THEN  'Y'  ELSE 'N' END 		as TEIJI_SHOKAN_UMU_FLG,-- 定時償還有無フラグ
			AM.ST_TEIJISHOKAN_KJT,													-- 初回定時償還期日
			AM.TEIJI_SHOKAN_TSUTI_KBN,												-- 定時償還通知区分
			AM.CALLITIBU_UMU_FLG,													-- コールオプション有無フラグ（一部償還）
			AM.PUTUMU_FLG,															-- プットオプション有無フラグ
			AM.TOKUREI_SHASAI_FLG,													-- 特例社債フラグ
			AM.IKKATSUIKO_FLG,														-- 一括移行方式フラグ
			AM.TKTI_KOZA_CD,														-- 特定口座管理機関コード
			AM.GENISIN_CD,															-- 原ＩＳＩＮコード
			AM.PARTMGR_KBN,															-- 分割銘柄区分
			M01.KOZA_TEN_CD,														-- 口座店コード
			M01.KOZA_TEN_CIFCD,														-- 口座店ＣＩＦコード
			AM.YOBI1,																-- 予備１
			AM.TOKUTEI_KOUSHASAI_FLG 												-- 特定公社債フラグ
		FROM
			MGR_KIHON_VIEW	VMG1,
			MHAKKOTAI		M01,
			(
			--１．銘柄情報更新
			 SELECT
				VMG1.*
			 FROM
				MGR_KIHON_VIEW	VMG1
			 WHERE
				TO_CHAR(VMG1.KOUSIN_DT, 'YYYYMMDD') = gGyomuYmd 						-- 更新日時 = 業務日付
			
UNION

			-- ２．コールオプション（全額償還）行使条件の期中変更入力
			-- ３．コールオプション（一部償還）行使条件の期中変更入力
			-- ４．定時不定額償還の期中変更入力
			-- ５．プットオプション行使条件の期中変更入力
			-- ６．満期償還条件の期中変更入力
			SELECT
				VMG1.*
			FROM
				MGR_KIHON_VIEW	VMG1,
				UPD_MGR_SHN	MG23
			WHERE
					VMG1.ITAKU_KAISHA_CD = MG23.ITAKU_KAISHA_CD
				AND VMG1.MGR_CD = MG23.MGR_CD
				AND TO_CHAR(MG23.SHONIN_DT, 'YYYYMMDD') = gGyomuYmd 					-- 承認日時 = 業務日付
				AND (MG23.MGR_HENKO_KBN  IN ('10', '40', '50')						-- 銘柄情報変更区分 10:満期償還 40:コールオプション（全額償還）50:プットオプション
					OR (	MG23.MGR_HENKO_KBN  IN ('21', '41')					-- 銘柄情報変更区分 21:定時不定額償還 41:コールオプション（一部償還）
						AND VMG1.TEIJI_SHOKAN_TSUTI_KBN = 'V'						-- 定時償還通知区分  V:（期中に通知）
					   )
					) 
			
UNION

			-- ７．その他海外実利払日の変更入力
			SELECT
				VMG1.*
			FROM
				MGR_KIHON_VIEW	VMG1,
				UPD_MGR_KHN	MG21
			WHERE
					VMG1.ITAKU_KAISHA_CD = MG21.ITAKU_KAISHA_CD
				AND VMG1.MGR_CD = MG21.MGR_CD
				AND ((
						  l_inTokoDaikoKbn = '1'									-- 引数．当行事務代行区分 1:当行
					  AND VMG1.KK_KANYO_FLG  IN ('0', '2')							-- 機構関与方式採用フラグ 0:機構非関与方式 、 2:機構非関与方式（実質機番号管理方式）
					  AND MG21.KM_ETCKAIGAI_CHKFLG = '1'							-- 期中銘柄その他海外チェックフラグ  1:変更する
					 ) OR l_inTokoDaikoKbn = '2'									-- 引数．当行事務代行区分 2:事務代行
					)
				AND VMG1.KYUJITSU_ETC_FLG = 'Y'										-- 休日処理その他海外参照フラグ Y:参照する
				AND MG21.MGR_HENKO_KBN = '01'										-- 銘柄情報変更区分 01:満期償還
				AND TO_CHAR(MG21.SHONIN_DT, 'YYYYMMDD') = gGyomuYmd 					-- 承認日時 = 業務日付
 
			
UNION

			-- ８．変動利付債の利率及び１通貨あたり利子額の変更入力
			SELECT
				VMG1.*
			FROM
				MGR_KIHON_VIEW	VMG1,
				UPD_MGR_RBR	MG22
			WHERE
					VMG1.ITAKU_KAISHA_CD = MG22.ITAKU_KAISHA_CD
				AND VMG1.MGR_CD = MG22.MGR_CD
				AND VMG1.RITSUKE_WARIBIKI_KBN = 'V'									-- 利付割引区分 V:変動利率
				AND MG22.MGR_HENKO_KBN = '02'										-- 銘柄情報変更区分 02:変動利率
				AND TO_CHAR(MG22.SHONIN_DT, 'YYYYMMDD') = gGyomuYmd 					-- 承認日時 = 業務日付
 
			
UNION

			-- ９．利払情報
			SELECT
				VMG1.*
			FROM
				MGR_KIHON_VIEW	VMG1,
				MGR_RBRKIJ	MG2
			WHERE
					VMG1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
				AND VMG1.MGR_CD = MG2.MGR_CD
				AND MG2.RBR_YMD = gYokuEigyoYmd 										-- 利払期日 = 翌営業日
			
UNION

			-- １０．定時償還情報
			SELECT
				VMG1.*
			FROM
				MGR_KIHON_VIEW	VMG1,
				MGR_SHOKIJ	MG3
			WHERE
					VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
				AND VMG1.MGR_CD = MG3.MGR_CD
				AND VMG1.TEIJI_SHOKAN_TSUTI_KBN = 'F'								-- 定時償還通知区分 F:発行時のみ通知
				AND MG3.SHOKAN_KBN IN ('20', '21', '41')							-- 償還区分 20:定時定額償還、21:定時不定額償還、41:コールオプション（一部）
				AND MG3.SHOKAN_YMD = gYokuEigyoYmd 									-- 利払期日 = 翌営業日
 
			) AM
		WHERE
			  	AM.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
			AND AM.MGR_CD = VMG1.MGR_CD
			AND AM.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
			AND AM.HKT_CD = M01.HKT_CD
			AND AM.SAIKEN_SHURUI NOT IN ('80''89')								-- 債権種類 80:新株予約権付社債、89:その他（ＣＢ）
			AND VMG1.MGR_STAT_KBN = '1'												-- 銘柄ステータス区分 1:承認済
			AND (trim(both AM.ISIN_CD) IS NOT NULL AND (trim(both AM.ISIN_CD))::text <> '')
			AND AM.JTK_KBN <> '2'													-- 受託区分 2：副（管理・受託）
			AND ((
					  l_inTokoDaikoKbn = '1'										-- 引数．当行事務代行区分 1:当行
				  AND AM.KK_KANYO_FLG  IN ('0', '2')								-- 機構関与方式採用フラグ 0:機構非関与方式 、 2:機構非関与方式（実質機番号管理方式）
				 ) OR l_inTokoDaikoKbn = '2'										-- 引数．当行事務代行区分 2:事務代行
				) 
		ORDER BY
			AM.ITAKU_KAISHA_CD,
			AM.MGR_CD;
/*==============================================================================*/

/*					関数定義													*/

/*==============================================================================*/

/*==============================================================================*/

/*					メイン処理													*/

/*==============================================================================*/

BEGIN
	CALL pkLog.debug('BATCH', C_FUNCTION_ID, '***** ' || C_FUNCTION_ID || ' START *****');
	-- 入力パラメータのチェック
	-- 外部IFID の必須チェック
	IF coalesce(l_inIfId::text, '') = '' THEN
		-- パラメータエラー
		CALL pkLog.error('ECM501', C_FUNCTION_ID, '外部IFID');
		RETURN pkconstant.error();
	END IF;
	-- 当行・事務代行区分のチェック
	IF coalesce(l_inTokoDaikoKbn::text, '') = '' THEN
		-- パラメータエラー
		CALL pkLog.error('ECM501', C_FUNCTION_ID, '当行・事務代行区分');
		RETURN pkconstant.error();
	END IF;
	-- 機構非関与銘柄情報TBL削除
	DELETE FROM MGR_KIKOHIKANYO;
	-- 業務日付の取得
	gGyomuYmd := pkDate.getGyomuYmd();
	--翌営業日の取得
	gYokuEigyoYmd := pkDate.getPlusDateBusiness(gGyomuYmd,1,'1');
	FOR curKkHikanyoMgr_rec IN curKkHikanyoMgr LOOP
		-- 次回定時償還情報の取得
		-- 初期化
		g_SHOKAN_KJT_TUG := tSPACE;
		g_SHOKAN_YMD := tSPACE;
		g_FACTOR_TUG := 0;
		g_FUNIT_GENSAI_KNGK_TUG := 0;
		-- データレコード件数加算
		gDataNo := gDataNo + 1;
		-- 共通部品で次回、今回、前回定時償還情報の取得
		gResult := pkIpGetKijyunKaiji.getAllShokanKaiji(curKkHikanyoMgr_rec.ITAKU_KAISHA_CD
														, curKkHikanyoMgr_rec.MGR_CD
														, gYokuEigyoYmd
														, g_SHOKAN_KJT_IMA
														, g_SHOKAN_YMD 								--未使用
														, g_FACTOR_IMA
														, g_FUNIT_GENSAI_KNGK_IMA
														, g_SHOKAN_KJT_TUG
														, g_SHOKAN_YMD 								--未使用
														, g_FACTOR_TUG
														, g_FUNIT_GENSAI_KNGK_TUG
														, g_SHOKAN_KJT_MAE
														, g_SHOKAN_YMD 								--未使用
														, g_FACTOR_MAE
														, g_FUNIT_GENSAI_KNGK_MAE);
		IF gResult <> pkconstant.success() THEN
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '共通部品エラー［定時償還情報取得]：銘柄情報データ作成処理（関与・非関与）対象レコード：' ||  gDataNo::text || '件目');
			RETURN gResult;
		END IF;
		-- コールオプション情報（全額償還）の取得
		gResult := pkIpGetKijyunKaiji.getShokanOptionNoKijunYmd(curKkHikanyoMgr_rec.ITAKU_KAISHA_CD
													, curKkHikanyoMgr_rec.MGR_CD
													, '40' -- コールオプション（全額償還）
													, g_MGR_KIKOHIKANYO.CALLALL_KURIAGE_SHOKAN_KJT
													, g_FUNIT_GENSAI_KNGK 							--未使用
													, g_MGR_KIKOHIKANYO.CALLALL_PLEMIUM_KNGK
													, g_FACTOR 										--未使用
													, g_MGR_KIKOHIKANYO.CALLALL_TSUKA_RISHI_KNGK
													, g_ST_PUTKOSHIKIKAN_YMD 						--未使用
													, g_ED_PUTKOSHIKIKAN_YMD);						--未使用
		IF gResult <> pkconstant.success() THEN
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '共通部品エラー［コールオプション情報（全額償還）取得]：銘柄情報データ作成処理（関与・非関与）対象レコード：' ||  gDataNo::text || '件目');
			RETURN gResult;
		END IF;
		-- コールオプション行使フラグ（全額償還）の取得
		-- 初期化
		g_MGR_KIKOHIKANYO.CALLALL_USE_FLG := tSPACE;
		-- コールオプション償還期日（全額償還）がNOT NULLなら'Y',NULLなら'N'
		IF (trim(both g_MGR_KIKOHIKANYO.CALLALL_KURIAGE_SHOKAN_KJT) IS NOT NULL AND (trim(both g_MGR_KIKOHIKANYO.CALLALL_KURIAGE_SHOKAN_KJT))::text <> '') THEN
			 g_MGR_KIKOHIKANYO.CALLALL_USE_FLG := 'Y';
		ELSE
			 g_MGR_KIKOHIKANYO.CALLALL_USE_FLG := 'N';
		END IF;
		-- プットオプション情報の取得
		gResult := pkIpGetKijyunKaiji.getShokanOptionNoKijunYmd(curKkHikanyoMgr_rec.ITAKU_KAISHA_CD
													, curKkHikanyoMgr_rec.MGR_CD
													, '50' -- プットオプション
													, g_MGR_KIKOHIKANYO.PUT_KURIAGE_SHOKAN_KJT
													, g_FUNIT_GENSAI_KNGK 							--未使用
													, g_MGR_KIKOHIKANYO.PUT_PLEMIUM_KNGK
													, g_FACTOR 										--未使用
													, g_TSUKARISHI_KNGK23							--未使用
													, g_MGR_KIKOHIKANYO.PUT_USE_ST_YMD
													, g_MGR_KIKOHIKANYO.PUT_USE_ED_YMD);
		IF gResult <> pkconstant.success() THEN
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '共通部品エラー［プットオプション情報取得]：銘柄情報データ作成処理（関与・非関与）対象レコード：' ||  gDataNo::text || '件目');
			RETURN gResult;
		END IF;
		-- プットオプション行使フラグの取得
		-- 初期化
		g_MGR_KIKOHIKANYO.PUTUSE_FLG := tSPACE;
		-- プットオプション償還期日がNOT NULLなら'Y',NULLなら'N'
		IF (trim(both g_MGR_KIKOHIKANYO.PUT_KURIAGE_SHOKAN_KJT) IS NOT NULL AND (trim(both g_MGR_KIKOHIKANYO.PUT_KURIAGE_SHOKAN_KJT))::text <> '') THEN
			 g_MGR_KIKOHIKANYO.PUTUSE_FLG := 'Y';
		ELSE
			 g_MGR_KIKOHIKANYO.PUTUSE_FLG := 'N';
		END IF;
		-- コールオプション情報（一部償還）の取得
		gResult := pkIpGetKijyunKaiji.getShokanOptionNoKijunYmd(curKkHikanyoMgr_rec.ITAKU_KAISHA_CD
													, curKkHikanyoMgr_rec.MGR_CD
													, '41' -- コールオプション（一部償還）
													, g_MGR_KIKOHIKANYO.CALLITIBU_KURIAGE_SHOKAN_KJT
													, g_MGR_KIKOHIKANYO.CALLITIBU_KURIAGE_SHOKAN_KNGK
													, g_MGR_KIKOHIKANYO.CALLITIBU_PLEMIUM_KNGK
													, g_MGR_KIKOHIKANYO.CALLITIBU_FACTOR
													, g_MGR_KIKOHIKANYO.CALLITIBU_TSUKA_RISHI_KNGK
													, g_ST_PUTKOSHIKIKAN_YMD 						--未使用
													, g_ED_PUTKOSHIKIKAN_YMD);						--未使用
		IF gResult <> pkconstant.success() THEN
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '共通部品エラー［コールオプション情報（一部償還）取得]：銘柄情報データ作成処理（関与・非関与）対象レコード：' ||  gDataNo::text || '件目');
			RETURN gResult;
		END IF;
		-- コールオプション行使フラグ（一部償還）の取得
		-- 初期化
		g_MGR_KIKOHIKANYO.CALLITIBU_USE_FLG := tSPACE;
		-- コールオプション償還期日（一部償還）がNOT NULLなら'Y',NULLなら'N'
		IF (trim(both g_MGR_KIKOHIKANYO.CALLITIBU_KURIAGE_SHOKAN_KJT) IS NOT NULL AND (trim(both g_MGR_KIKOHIKANYO.CALLITIBU_KURIAGE_SHOKAN_KJT))::text <> '') THEN
			 g_MGR_KIKOHIKANYO.CALLITIBU_USE_FLG := 'Y';
		ELSE
			 g_MGR_KIKOHIKANYO.CALLITIBU_USE_FLG := 'N';
		END IF;
		-- 利払情報の取得
		-- 初期化
		g_RBR_KJT_IMA := tSPACE;
		g_RIRITSU_IMA := 0;
		g_TSUKARISHI_KNGK_IMA := 0;
		g_RBR_KJT_TUG := tSPACE;
		g_RIRITSU_TUG := 0;
		g_TSUKARISHI_KNGK_TUG := 0;
		g_LAST_SHOKAN_KJT := tSPACE;
		g_LAST_RIRITSU := 0;
		g_LAST_TSUKARISHI_KNGK := 0;
		g_RBR_YMD := '0';
		-- 今回利払情報の取得
		gResult := pkIpGetKijyunKaiji.getKonkaiRbrKaiji(curKkHikanyoMgr_rec.ITAKU_KAISHA_CD
													  , curKkHikanyoMgr_rec.MGR_CD
													  , gYokuEigyoYmd
													  , g_RBR_KJT_IMA
													  , g_RBR_YMD 									--未使用
													  , g_RIRITSU_IMA
													  , g_TSUKARISHI_KNGK_IMA);
		IF gResult <> pkconstant.success() THEN
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '共通部品エラー［今回利払情報取得]：銘柄情報データ作成処理（関与・非関与）対象レコード：' ||  gDataNo::text || '件目');
			RETURN gResult;
		END IF;
		-- 今回利払期日が有効な場合のみ次回利払情報取得及び最終回利払情報取得
		IF (trim(both g_RBR_KJT_IMA) IS NOT NULL AND (trim(both g_RBR_KJT_IMA))::text <> '') THEN
			-- 初期化
			g_RBR_YMD := '0';
			-- 次回利払情報の取得
			gResult := pkIpGetKijyunKaiji.getKonkaiRbrKaiji(curKkHikanyoMgr_rec.ITAKU_KAISHA_CD
														  , curKkHikanyoMgr_rec.MGR_CD
														  , g_RBR_KJT_IMA
														  , g_RBR_KJT_TUG
														  , g_RBR_YMD 								--未使用
														  , g_RIRITSU_TUG
														  , g_TSUKARISHI_KNGK_TUG);
			IF gResult <> pkconstant.success() THEN
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '共通部品エラー［次回利払情報取得]：銘柄情報データ作成処理（関与・非関与）対象レコード：' ||  gDataNo::text || '件目');
				RETURN gResult;
			END IF;
			-- 初期化
			g_RBR_YMD := '0';
			-- 最終回利払情報の取得
			gResult := pkIpGetKijyunKaiji.getLastRbrKaiji(curKkHikanyoMgr_rec.ITAKU_KAISHA_CD
													  , curKkHikanyoMgr_rec.MGR_CD
													  , g_LAST_SHOKAN_KJT
													  , g_RBR_YMD 									--未使用
													  , g_LAST_RIRITSU
													  , g_LAST_TSUKARISHI_KNGK);
			IF gResult <> pkconstant.success() THEN
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '共通部品エラー［最終回利払情報取得]：銘柄情報データ作成処理（関与・非関与）対象レコード：' ||  gDataNo::text || '件目');
				RETURN gResult;
			END IF;
		END IF;
		-- その他海外実利払日を取得
		-- 初期化
		g_ETCKAIGAI_RBR_YMD := tSPACE;
		-- その他海外実利払日を取得
		gResult := pkIpGetKijyunKaiji.getEtckaigaiRbrYmd(curKkHikanyoMgr_rec.ITAKU_KAISHA_CD
													   , curKkHikanyoMgr_rec.MGR_CD
													   , gYokuEigyoYmd
													   , g_ETCKAIGAI_RBR_YMD);
		IF gResult <> pkconstant.success() THEN
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '共通部品エラー［その他海外実利払日取得]：銘柄情報データ作成処理（関与・非関与）対象レコード：' ||  gDataNo::text || '件目');
			RETURN gResult;
		END IF;
		-- その他海外実利払日が取得できず かつ その他海外参照フラグが有なら今回利払期日設定
		IF coalesce(trim(both g_ETCKAIGAI_RBR_YMD)::text, '') = '' THEN
			IF curKkHikanyoMgr_rec.ETCKAIGAI_FLG = 'Y'  THEN
				g_ETCKAIGAI_RBR_YMD := g_RBR_KJT_IMA;
			ELSE
				g_ETCKAIGAI_RBR_YMD := tSPACE;
			END IF;
		END IF;
		g_MGR_KIKOHIKANYO.ETCKAIGAI_RBR_YMD := g_ETCKAIGAI_RBR_YMD;
		-- 償還プレミアムの取得
		-- 初期化
		g_MGR_KIKOHIKANYO.SHOKAN_PREMIUM := 0;
		-- （満期）償還プレミアムの取得
		gResult := pkIpGetKijyunKaiji.getShokanOptionNoKijunYmd(curKkHikanyoMgr_rec.ITAKU_KAISHA_CD
													, curKkHikanyoMgr_rec.MGR_CD
													, '10' -- 満期償還
													, g_SHOKAN_KJT 									--未使用
													, g_FUNIT_GENSAI_KNGK 							--未使用
													, g_MGR_KIKOHIKANYO.SHOKAN_PREMIUM
													, g_FACTOR 										--未使用
													, g_TSUKARISHI_KNGK23							--未使用
													, g_ST_PUTKOSHIKIKAN_YMD 						--未使用
													, g_ED_PUTKOSHIKIKAN_YMD);						--未使用
		IF gResult <> pkconstant.success() THEN
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '共通部品エラー［満期償還情報（償還プレミアム）取得]：銘柄情報データ作成処理（関与・非関与）対象レコード：' ||  gDataNo::text || '件目');
			RETURN gResult;
		END IF;
		/*	機構非関与銘柄情報登録	*/

		INSERT INTO MGR_KIKOHIKANYO(
/* 01 */

	 MAKE_DT
			,ITAKU_KAISHA_CD
			,ISIN_CD
			,MGR_NM
			,HAKKOSHA_RNM
			,KAIGO_ETC
			,BOSHU_KBN_RNM
			,FIXDISPLAY
			,HOSHO_KBN
/* 10 */

	,TANPO_KBN
			,PARTHAKKO_UMU_FLG
			,GODOHAKKO_FLG
			,RETSUTOKU_UMU_FLG
			,SKNNZISNTOKU_UMU_FLG
			,SAIKEN_SHURUI
			,KK_HAKKO_CD
			,BOSHU_ST_YMD
			,HRKM_YMD
			,KAKUSHASAI_KNGK
/* 20 */

	,UCHIKIRI_HAKKO_FLG
			,SHASAI_TOTAL
			,HAKKO_TSUKA_CD
			,HAKKODAIRI_CD
			,SHRDAIRI_CD
			,SKN_KESSAI_CD
			,KK_KANYO_FLG
			,KOBETSU_SHONIN_SAIYO_FLG
			,KYUJITSU_KBN
			,LD_FLG
/* 30 */

	,NY_FLG
			,ETCKAIGAI_FLG
			,ETCKAIGAI_RBR_YMD
			,RITSUKE_WARIBIKI_KBN
			,RBR_TSUKA_CD
			,RBR_KJT_MD1
			,RBR_KJT_MD2
			,RBR_KJT_MD3
			,RBR_KJT_MD4
			,RBR_KJT_MD5
/* 40 */

	,RBR_KJT_MD6
			,RBR_KJT_MD7
			,RBR_KJT_MD8
			,RBR_KJT_MD9
			,RBR_KJT_MD10
			,RBR_KJT_MD11
			,RBR_KJT_MD12
			,ST_RBR_KJT
			,LAST_RBR_FLG
			,THIS_RBR_KJT
/* 50 */

	,THIS_RIRITSU
			,THIS_TSUKARISHI_KNGK
			,NEXT_RBR_KJT
			,NEXT_RIRITSU
			,NEXT_TSUKARISHI_KNGK
			,LAST_SHOKAN_KJT
			,LAST_RIRITSU
			,LAST_TSUKARISHI_KNGK
			,SHOKAN_TSUKA_CD
			,KAWASE_RATE
/* 60 */

	,SHOKAN_PREMIUM
			,FULLSHOKAN_KJT
			,TEKIYO_END_YMD
			,NEWISIN_CD
			,CALLALL_UMU_FLG
			,CALLALL_USE_FLG
			,CALLALL_KURIAGE_SHOKAN_KJT
			,CALLALL_PLEMIUM_KNGK
			,CALLALL_TSUKA_RISHI_KNGK
			,TEIJI_SHOKAN_UMU_FLG
/* 70 */

	,ST_TEIJISHOKAN_KJT
			,TEIJI_SHOKAN_TSUTI_KBN
			,BEF_TEIJI_SHOKAN_KJT
			,BEF_TEIJI_SHOKAN_KNGK
			,BEF_FACTOR
			,THIS_TEIJI_SHOKAN_KJT
			,THIS_TEIJI_SHOKAN_KNGK
			,THIS_FACTOR
			,NEXT_YOTEI_TEIJI_SHOKAN_KJT
			,NEXT_YOTEI_TEIJI_SHOKAN_KNGK
/* 80 */

	,NEXT_YOTEI_FACTOR
			,CALLITIBU_UMU_FLG
			,CALLITIBU_USE_FLG
			,CALLITIBU_KURIAGE_SHOKAN_KJT
			,CALLITIBU_PLEMIUM_KNGK
			,CALLITIBU_KURIAGE_SHOKAN_KNGK
			,CALLITIBU_FACTOR
			,CALLITIBU_TSUKA_RISHI_KNGK
			,PUTUMU_FLG
			,PUTUSE_FLG
/* 90 */

	,PUT_USE_ST_YMD
			,PUT_USE_ED_YMD
			,PUT_KURIAGE_SHOKAN_KJT
			,PUT_PLEMIUM_KNGK
			,TOKUREI_SHASAI_FLG
			,IKKATSUIKO_FLG
			,TKTI_KOZA_CD
			,GENISIN_CD
			,PARTMGR_KBN
			,KOZA_TEN_CD
/* 100 */

	,KOZA_TEN_CIFCD
			,YOBI1
			,TOKUTEI_KOUSHASAI_FLG
			,KOUSIN_ID
			,SAKUSEI_ID
		) VALUES (
/* 01 */

	 gGyomuYmd
			,curKkHikanyoMgr_rec.ITAKU_KAISHA_CD
			,curKkHikanyoMgr_rec.ISIN_CD
			,curKkHikanyoMgr_rec.MGR_NM
			,curKkHikanyoMgr_rec.HAKKOSHA_RNM
			,curKkHikanyoMgr_rec.KAIGO_ETC
			,curKkHikanyoMgr_rec.BOSHU_KBN_RNM
			,curKkHikanyoMgr_rec.FIXDISPLAY
			,curKkHikanyoMgr_rec.HOSHO_KBN
/* 10 */

	,curKkHikanyoMgr_rec.TANPO_KBN
			,curKkHikanyoMgr_rec.PARTHAKKO_UMU_FLG
			,curKkHikanyoMgr_rec.GODOHAKKO_FLG
			,curKkHikanyoMgr_rec.RETSUTOKU_UMU_FLG
			,curKkHikanyoMgr_rec.SKNNZISNTOKU_UMU_FLG
			,curKkHikanyoMgr_rec.SAIKEN_SHURUI
			,curKkHikanyoMgr_rec.KK_HAKKO_CD
			,curKkHikanyoMgr_rec.BOSHU_ST_YMD
			,curKkHikanyoMgr_rec.HRKM_YMD
			,curKkHikanyoMgr_rec.KAKUSHASAI_KNGK
/* 20 */

	,curKkHikanyoMgr_rec.UCHIKIRI_HAKKO_FLG
			,curKkHikanyoMgr_rec.SHASAI_TOTAL
			,curKkHikanyoMgr_rec.HAKKO_TSUKA_CD
			,curKkHikanyoMgr_rec.HAKKODAIRI_CD
			,curKkHikanyoMgr_rec.SHRDAIRI_CD
			,curKkHikanyoMgr_rec.SKN_KESSAI_CD
			,curKkHikanyoMgr_rec.KK_KANYO_FLG
			,curKkHikanyoMgr_rec.KOBETSU_SHONIN_SAIYO_FLG
			,curKkHikanyoMgr_rec.KYUJITSU_KBN
			,curKkHikanyoMgr_rec.LD_FLG
/* 30 */

	,curKkHikanyoMgr_rec.NY_FLG
			,curKkHikanyoMgr_rec.ETCKAIGAI_FLG
			,g_MGR_KIKOHIKANYO.ETCKAIGAI_RBR_YMD
			,curKkHikanyoMgr_rec.RITSUKE_WARIBIKI_KBN
			,curKkHikanyoMgr_rec.RBR_TSUKA_CD
			,curKkHikanyoMgr_rec.RBR_KJT_MD1
			,curKkHikanyoMgr_rec.RBR_KJT_MD2
			,curKkHikanyoMgr_rec.RBR_KJT_MD3
			,curKkHikanyoMgr_rec.RBR_KJT_MD4
			,curKkHikanyoMgr_rec.RBR_KJT_MD5
/* 40 */

	,curKkHikanyoMgr_rec.RBR_KJT_MD6
			,curKkHikanyoMgr_rec.RBR_KJT_MD7
			,curKkHikanyoMgr_rec.RBR_KJT_MD8
			,curKkHikanyoMgr_rec.RBR_KJT_MD9
			,curKkHikanyoMgr_rec.RBR_KJT_MD10
			,curKkHikanyoMgr_rec.RBR_KJT_MD11
			,curKkHikanyoMgr_rec.RBR_KJT_MD12
			,curKkHikanyoMgr_rec.ST_RBR_KJT
			,curKkHikanyoMgr_rec.LAST_RBR_FLG
			,g_RBR_KJT_IMA
/* 50 */

	,g_RIRITSU_IMA
			,g_TSUKARISHI_KNGK_IMA
			,g_RBR_KJT_TUG
			,g_RIRITSU_TUG
			,g_TSUKARISHI_KNGK_TUG
			,g_LAST_SHOKAN_KJT
			,g_LAST_RIRITSU
			,g_LAST_TSUKARISHI_KNGK
			,curKkHikanyoMgr_rec.SHOKAN_TSUKA_CD
			,curKkHikanyoMgr_rec.KAWASE_RATE
/* 60 */

	,g_MGR_KIKOHIKANYO.SHOKAN_PREMIUM
			,curKkHikanyoMgr_rec.FULLSHOKAN_KJT
			,curKkHikanyoMgr_rec.TEKIYO_END_YMD
			,curKkHikanyoMgr_rec.NEWISIN_CD
			,curKkHikanyoMgr_rec.CALLALL_UMU_FLG
			,g_MGR_KIKOHIKANYO.CALLALL_USE_FLG
			,g_MGR_KIKOHIKANYO.CALLALL_KURIAGE_SHOKAN_KJT
			,g_MGR_KIKOHIKANYO.CALLALL_PLEMIUM_KNGK
			,g_MGR_KIKOHIKANYO.CALLALL_TSUKA_RISHI_KNGK
			,curKkHikanyoMgr_rec.TEIJI_SHOKAN_UMU_FLG
/* 70 */

	,curKkHikanyoMgr_rec.ST_TEIJISHOKAN_KJT
			,curKkHikanyoMgr_rec.TEIJI_SHOKAN_TSUTI_KBN
			,g_SHOKAN_KJT_MAE
			,g_FUNIT_GENSAI_KNGK_MAE
			,g_FACTOR_MAE
			,g_SHOKAN_KJT_IMA
			,g_FUNIT_GENSAI_KNGK_IMA
			,g_FACTOR_IMA
			,g_SHOKAN_KJT_TUG
			,g_FUNIT_GENSAI_KNGK_TUG
/* 80 */

	,g_FACTOR_TUG
			,curKkHikanyoMgr_rec.CALLITIBU_UMU_FLG
			,g_MGR_KIKOHIKANYO.CALLITIBU_USE_FLG
			,g_MGR_KIKOHIKANYO.CALLITIBU_KURIAGE_SHOKAN_KJT
			,g_MGR_KIKOHIKANYO.CALLITIBU_PLEMIUM_KNGK
			,g_MGR_KIKOHIKANYO.CALLITIBU_KURIAGE_SHOKAN_KNGK
			,g_MGR_KIKOHIKANYO.CALLITIBU_FACTOR
			,g_MGR_KIKOHIKANYO.CALLITIBU_TSUKA_RISHI_KNGK
			,curKkHikanyoMgr_rec.PUTUMU_FLG
			,g_MGR_KIKOHIKANYO.PUTUSE_FLG
/* 90 */

	,g_MGR_KIKOHIKANYO.PUT_USE_ST_YMD
			,g_MGR_KIKOHIKANYO.PUT_USE_ED_YMD
			,g_MGR_KIKOHIKANYO.PUT_KURIAGE_SHOKAN_KJT	
			,g_MGR_KIKOHIKANYO.PUT_PLEMIUM_KNGK
			,curKkHikanyoMgr_rec.TOKUREI_SHASAI_FLG
			,curKkHikanyoMgr_rec.IKKATSUIKO_FLG
			,curKkHikanyoMgr_rec.TKTI_KOZA_CD
			,curKkHikanyoMgr_rec.GENISIN_CD
			,curKkHikanyoMgr_rec.PARTMGR_KBN
			,curKkHikanyoMgr_rec.KOZA_TEN_CD
/* 100 */

	,curKkHikanyoMgr_rec.KOZA_TEN_CIFCD
			,curKkHikanyoMgr_rec.YOBI1
			,curKkHikanyoMgr_rec.TOKUTEI_KOUSHASAI_FLG
			,pkconstant.BATCH_USER()
			,pkconstant.BATCH_USER()
		);
	END LOOP;
	-- 終了処理
	CALL pkLog.info('IIP015', C_FUNCTION_ID,  gDataNo::text || ' 件');
	CALL pkLog.debug('BATCH', C_FUNCTION_ID, '***** ' || C_FUNCTION_ID || ' END *****');
	RETURN pkconstant.success();
-- 例外処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'SQLERRM:' || SQLERRM);
		-- 機構非関与銘柄情報提供テーブルへの登録処理内で例外の場合、対象レコード箇所を出力
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '銘柄情報データ作成処理（関与・非関与）対象レコード：' ||  gDataNo::text || '件目');
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipxb08k15r01 ( l_inIfId GAIBU_IF_KANRI.IF_ID%TYPE, l_inTokoDaikoKbn TEXT  ) FROM PUBLIC;
