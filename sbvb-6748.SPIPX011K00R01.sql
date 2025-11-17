




CREATE OR REPLACE PROCEDURE spipx011k00r01 ( 
	l_inItakuKaishaCd TEXT 		-- 委託会社コード
 ,l_inUserId TEXT 		-- ユーザID
 ,l_inChohyoKbn TEXT 		-- 帳票区分
 ,l_inGyomuYmd TEXT 		-- 業務日付
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
--	 * 取扱店別銘柄別元利金及び手数料一覧表を作成する。（DCS静岡カスタマイズ）
--	 * オプションコード：IP010061040F5
--	 * （リアルのみ）
--	 * @author	ASK
--	 * @version	$Revision: 1.6 $
--	 * 
--	 * @param	l_inItakuKaishaCd	IN  TEXT		委託会社コード
--	 * @param	l_inUserId			IN  TEXT		ユーザID
--	 * @param	l_inChohyoKbn		IN  TEXT		帳票区分
--	 * @param	l_inGyomuYmd		IN  TEXT		業務日付
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
	PROGRAM_ID		CONSTANT	varchar(14)	:= 'SPIPX011K00R01';	-- プログラムID
	REPORT_ID		CONSTANT	char(11)	:= 'IPX30001111';		-- 取扱店別銘柄別元利金及び手数料一覧表帳票ID
	TSUCHI_YMD_DEF	CONSTANT	char(16)	:= '      年  月  日';	-- 通知日(画面指定なし)
	ATESAKI_DEF		CONSTANT	char(16)	:= '融資担当役席　殿';	-- 宛先(固定値)
	NODATA			CONSTANT	integer		:= 2;					-- データなし
											-- EXCEPTION
	--==============================================================================*
--		変数定義
--	 *==============================================================================
	gRtnCd				integer := pkconstant.success();			-- リターンコード
	gSeqNo				integer := 0;							-- 帳票wk「連番」
	-- frm用文字列
	gFrmTsuchiYmd		varchar(16) := NULL;					-- 通知日(西暦)
	gFrmGnrbrYm			varchar(14) := NULL;					-- 元利払年月文字列
	gFrmBushoNm1		VJIKO_ITAKU.BUSHO_NM1%TYPE := NULL;	-- 担当部署名称１
	gSeikyuBunsho		varchar(100) := NULL;					-- 請求文章
	gSeikyuBunsho1		varchar(100) := NULL;					-- 請求文章(2行目)
	-- 作業用(使用の都度クリアする)
	gWkKknChokyuYmdWareki	char(12);								-- (作業用)基金徴求日
	gWkGnkn					numeric(14);								-- (作業用)元金
	gWkRkn					numeric(14);								-- (作業用)利金
	gWkGnrKngkSum			numeric(14);								-- (作業用)元利金合計
	gWkTesuChokyuYmdWareki	char(12);								-- (作業用)手数料徴求日
	gWkTesu					numeric(14);								-- (作業用)手数料
	gWk2ndFlg				boolean;								-- 2件目有無フラグ
	l_inItem				TYPE_SREPORT_WK_ITEM;					-- 帳票ワークアイテム
	--==============================================================================*
--		カーソル定義
--	 *==============================================================================
	--==============================================================================*
--		カーソル「基金入金明細」
--			基金異動履歴テーブルより、元利金の入金レコードを取得する。
--			入金額は、基金異動区分によって該当の入金項目に振り分ける。
--				集計	：銘柄コード・利払日
--				ソート	：口座店コード→銘柄コード→利払日
--				対象	：処理中の委託会社レコード
--						　基準年月中に利払日が到来するレコード
--						　請求書作成済みのレコード
--						　口座振込が選択されているレコード
--	 *==============================================================================
	curMeisai CURSOR FOR
	SELECT
		 M01.KOZA_TEN_CD 					-- 口座店コード
		,(SELECT 							-- 口座店名称
			M04.BUTEN_NM 					--（部店マスタより取得）
		  FROM
			MBUTEN M04
		  WHERE
				M04.ITAKU_KAISHA_CD	= M01.ITAKU_KAISHA_CD
			AND	M04.BUTEN_CD		= M01.KOZA_TEN_CD
		 ) AS KOZA_TEN_NM
		,K02.MGR_CD 							-- 銘柄コード
		,VMG1.MGR_NM 						-- 銘柄の正式名称
		,(SELECT 							-- 自動引落口座_口座科目名称
			SC04.CODE_NM 					--（コードマスタより取得）
		  FROM
			SCODE SC04
		  WHERE
				SC04.CODE_SHUBETSU	= '707'
			AND	SC04.CODE_VALUE		= M01.HKO_KAMOKU_CD
		 ) AS KOZA_KAMOKU_NM
		,M01.HKO_KOZA_NO 					-- 自動引落口座_口座番号
		,K02.RBR_YMD_SORT 					-- 利払日(ソート用)
		,K02.SHOKAN_YMD 						-- 償還日
		,K02.RBR_YMD 						-- 利払日
		,K02.KKN_CHOKYU_YMD 					-- 基金徴求日
		,K02.GNKN 							-- 元金額
		,K02.RKN 							-- 利金額
		,K02.TESU_CHOKYU_YMD_G 				-- 元金手数料徴求日
		,K02.TESU_G 							-- 元金手数料
		,K02.TESU_CHOKYU_YMD_R 				-- 利金手数料徴求日
		,K02.TESU_R 							-- 利金手数料
	FROM (SELECT
			 K02S.ITAKU_KAISHA_CD 									-- 委託会社コード
			,K02S.MGR_CD 											-- 銘柄コード
			,K02S.RBR_YMD_SORT 										-- 利払日(ソート用)
			,MAX(K02S.SHOKAN_YMD)			AS SHOKAN_YMD 			-- 償還日		←元金・元金手数料がある場合
			,MAX(K02S.RBR_YMD)				AS RBR_YMD 				-- 利払日		←利金・利金手数料　〃
			,MAX(K02S.KKN_CHOKYU_YMD)		AS KKN_CHOKYU_YMD 		-- 基金徴求日	←元利金がある場合
			,SUM(K02S.GNKN)					AS GNKN 					-- 元金額
			,SUM(K02S.RKN)					AS RKN 					-- 利金額
			,MAX(K02S.TESU_CHOKYU_YMD_G)	AS TESU_CHOKYU_YMD_G 	-- 元金手数料徴求日
			,SUM(K02S.TESU_G)				AS TESU_G 				-- 元金手数料
			,MAX(K02S.TESU_CHOKYU_YMD_R)	AS TESU_CHOKYU_YMD_R 	-- 利金手数料徴求日
			,SUM(K02S.TESU_R)				AS TESU_R 				-- 利金手数料
		 FROM (
				--==============================================================
				--	1. 基金異動履歴 -元金
				--		11:入金(元金)
				----------------------------------------------------
				SELECT
					 K02_1.ITAKU_KAISHA_CD 								-- 委託会社コード
					,K02_1.MGR_CD 										-- 銘柄コード
					,K02_1.RBR_YMD				AS RBR_YMD_SORT 			-- 利払日(ソート用)
					,K02_1.RBR_YMD				AS SHOKAN_YMD 			-- 償還日
					,' '						AS RBR_YMD 				-- 利払日
					,K02_1.IDO_YMD				AS KKN_CHOKYU_YMD 		-- 基金徴求日
					,K02_1.KKN_NYUKIN_KNGK		AS GNKN 					-- 元金額
					,0							AS RKN 					-- 利金額
					,' '						AS TESU_CHOKYU_YMD_G 	-- 元金手数料徴求日
					,0							AS TESU_G 				-- 元金手数料
					,' '						AS TESU_CHOKYU_YMD_R 	-- 利金手数料徴求日
					,0							AS TESU_R 				-- 利金手数料
				FROM
					 KIKIN_IDO K02_1
					,MGR_KIHON MG1_1
				WHERE
						K02_1.KKN_IDO_KBN			= '11'
					AND	K02_1.ITAKU_KAISHA_CD		= l_inItakuKaishaCd 	-- 「引数：委託会社コード」を対象
					AND	SUBSTR(K02_1.RBR_YMD, 1, 6)	= l_inKijunYm 		-- 「引数：基準年月」中に利払日が到来
					AND	K02_1.TSUKA_CD				= 'JPY'				-- 円貨 を対象
					AND	K02_1.DATA_SAKUSEI_KBN		>= '1'				-- 1:請求書出力　2:補正入力 を対象
					AND	MG1_1.KOZA_FURI_KBN			= '10'				-- 10:口座振替 を対象
					-- [ テーブルの結合条件 ]
					AND	MG1_1.ITAKU_KAISHA_CD		= K02_1.ITAKU_KAISHA_CD
					AND	MG1_1.MGR_CD				= K02_1.MGR_CD
			
UNION

				--==============================================================
				--	2. 基金異動履歴 -利金
				--		21:入金(利金)
				----------------------------------------------------
				SELECT
					 K02_2.ITAKU_KAISHA_CD 								-- 委託会社コード
					,K02_2.MGR_CD 										-- 銘柄コード
					,K02_2.RBR_YMD				AS RBR_YMD_SORT 			-- 利払日(ソート用)
					,' '						AS SHOKAN_YMD 			-- 償還日
					,K02_2.RBR_YMD				AS RBR_YMD 				-- 利払日
					,K02_2.IDO_YMD				AS KKN_CHOKYU_YMD 		-- 基金徴求日
					,0							AS GNKN 					-- 元金額
					,K02_2.KKN_NYUKIN_KNGK		AS RKN 					-- 利金額
					,' '						AS TESU_CHOKYU_YMD_G 	-- 元金手数料徴求日
					,0							AS TESU_G 				-- 元金手数料
					,' '						AS TESU_CHOKYU_YMD_R 	-- 利金手数料徴求日
					,0							AS TESU_R 				-- 利金手数料
				FROM
					 KIKIN_IDO K02_2
					,MGR_KIHON MG1_1
				WHERE
						K02_2.KKN_IDO_KBN			= '21'
					AND	K02_2.ITAKU_KAISHA_CD		= l_inItakuKaishaCd 	-- 「引数：委託会社コード」を対象
					AND	SUBSTR(K02_2.RBR_YMD, 1, 6)	= l_inKijunYm 		-- 「引数：基準年月」中に利払日が到来
					AND	K02_2.TSUKA_CD				= 'JPY'				-- 円貨 を対象
					AND	K02_2.DATA_SAKUSEI_KBN		>= '1'				-- 1:請求書出力　2:補正入力 を対象
					AND	MG1_1.KOZA_FURI_KBN			= '10'				-- 10:口座振替 を対象
					-- [ テーブルの結合条件 ]
					AND	MG1_1.ITAKU_KAISHA_CD		= K02_2.ITAKU_KAISHA_CD
					AND	MG1_1.MGR_CD				= K02_2.MGR_CD 
			
UNION

				--==============================================================
				--	3. 基金異動履歴 -元金支払手数料
				--		12:入金(元金支払手数料)		13:入金(元金支払手数料消費税)
				----------------------------------------------------
				SELECT
					 K02_3.ITAKU_KAISHA_CD 								-- 委託会社コード
					,K02_3.MGR_CD 										-- 銘柄コード
					,K02_3.RBR_YMD				AS RBR_YMD_SORT 			-- 利払日(ソート用)
					,K02_3.RBR_YMD				AS SHOKAN_YMD 			-- 償還日
					,' '						AS RBR_YMD 				-- 利払日
					,' '						AS KKN_CHOKYU_YMD 		-- 基金徴求日
					,0							AS GNKN 					-- 元金額
					,0							AS RKN 					-- 利金額
					,K02_3.IDO_YMD				AS TESU_CHOKYU_YMD_G 	-- 元金手数料徴求日
					,K02_3.KKN_NYUKIN_KNGK		AS TESU_G 				-- 元金手数料
					,' '						AS TESU_CHOKYU_YMD_R 	-- 利金手数料徴求日
					,0							AS TESU_R 				-- 利金手数料
				FROM
					 KIKIN_IDO K02_3
					,MGR_TESURYO_CTL MG7_3
				WHERE
						K02_3.KKN_IDO_KBN			IN ('12', '13')
					AND	K02_3.ITAKU_KAISHA_CD		= l_inItakuKaishaCd 	-- 「引数：委託会社コード」を対象
					AND	SUBSTR(K02_3.RBR_YMD, 1, 6)	= l_inKijunYm 		-- 「引数：基準年月」中に利払日が到来
					AND	K02_3.TSUKA_CD				= 'JPY'				-- 円貨 を対象
					AND	K02_3.DATA_SAKUSEI_KBN		>= '1'				-- 1:請求書出力　2:補正入力 を対象
					AND	MG7_3.KOZA_FURI_KBN			= '10'				-- 10:口座振替 を対象
					AND	MG7_3.TESU_SHURUI_CD		= '81'				-- 81:元金支払手数料
					AND	MG7_3.CHOOSE_FLG			= '1'				-- 上記手数料種類が選択されている
					-- [ テーブルの結合条件 ]
					AND	MG7_3.ITAKU_KAISHA_CD		= K02_3.ITAKU_KAISHA_CD
					AND	MG7_3.MGR_CD				= K02_3.MGR_CD 
			
UNION

				--==============================================================
				--	4. 基金異動履歴 -利金支払手数料
				--		22:入金(利金支払手数料)		23:入金(利金支払手数料消費税)
				----------------------------------------------------
				SELECT
					 K02_4.ITAKU_KAISHA_CD 								-- 委託会社コード
					,K02_4.MGR_CD 										-- 銘柄コード
					,K02_4.RBR_YMD				AS RBR_YMD_SORT 			-- 利払日(ソート用)
					,' '						AS SHOKAN_YMD 			-- 償還日
					,K02_4.RBR_YMD				AS RBR_YMD 				-- 利払日
					,' '						AS KKN_CHOKYU_YMD 		-- 基金徴求日
					,0							AS GNKN 					-- 元金額
					,0							AS RKN 					-- 利金額
					,' '						AS TESU_CHOKYU_YMD_G 	-- 元金手数料徴求日
					,0							AS TESU_G 				-- 元金手数料
					,K02_4.IDO_YMD				AS TESU_CHOKYU_YMD_R 	-- 利金手数料徴求日
					,K02_4.KKN_NYUKIN_KNGK		AS TESU_R 				-- 利金手数料
				FROM
					 KIKIN_IDO K02_4
					,MGR_TESURYO_CTL MG7_4
				WHERE
						K02_4.KKN_IDO_KBN			IN ('22', '23')
					AND	K02_4.ITAKU_KAISHA_CD		= l_inItakuKaishaCd 	-- 「引数：委託会社コード」を対象
					AND	SUBSTR(K02_4.RBR_YMD, 1, 6)	= l_inKijunYm 		-- 「引数：基準年月」中に利払日が到来
					AND	K02_4.TSUKA_CD				= 'JPY'				-- 円貨 を対象
					AND	K02_4.DATA_SAKUSEI_KBN		>= '1'				-- 1:請求書出力　2:補正入力 を対象
					AND	MG7_4.KOZA_FURI_KBN			= '10'				-- 10:口座振替 を対象
					AND	MG7_4.TESU_SHURUI_CD		IN ('61','82')		-- 61:利金支払手数料(元金)　82:利金支払手数料(利金)
					AND	MG7_4.CHOOSE_FLG			= '1'				-- 上記手数料種類が選択されている
					-- [ テーブルの結合条件 ]
					AND	MG7_4.ITAKU_KAISHA_CD		= K02_4.ITAKU_KAISHA_CD
					AND	MG7_4.MGR_CD				= K02_4.MGR_CD 
			) K02S 
		 GROUP BY
			 K02S.ITAKU_KAISHA_CD 		-- 委託会社コード
			,K02S.MGR_CD 				-- 銘柄コード
			,K02S.RBR_YMD_SORT 			-- 利払日(ソート用)
		 ) k02, mgr_kihon_view vmg1
LEFT OUTER JOIN mhakkotai m01 ON (VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD AND VMG1.HKT_CD = M01.HKT_CD)
WHERE -- [[ 抽出条件 ]]
			-- [ 銘柄_基本view ]
 VMG1.ITAKU_KAISHA_CD	= l_inItakuKaishaCd 		-- 「引数：委託会社コード」を対象
  AND VMG1.JTK_KBN			NOT IN ('2','5') 		-- 2:副受託・5:自社発行銘柄 を除外
  AND VMG1.MGR_STAT_KBN		= '1' -- 承認済銘柄 を対象
  AND VMG1.BOSHU_KBN			NOT IN ('K','S') 		-- 募集区分 K:公募 S:その他 を除外
  AND VMG1.KK_KANYO_FLG		<> '2' -- 2:機構非関与方式(実質記番号銘柄) を除外
		-- [[ テーブルの結合条件 ]]
			-- [ 基金異動履歴 - 銘柄_基本view ]
  AND K02.ITAKU_KAISHA_CD		= VMG1.ITAKU_KAISHA_CD AND K02.MGR_CD				= VMG1.MGR_CD -- [ 銘柄基本view - 発行体マスタ ]
   ORDER BY
		 M01.KOZA_TEN_CD
		,K02.RBR_YMD_SORT
		,K02.MGR_CD
	;
	--==============================================================================*
--		メイン処理
--	 *==============================================================================
BEGIN
	IF DEBUG = 1 THEN
		CALL pkLog.debug(l_inUserId, REPORT_ID, '○' || PROGRAM_ID || ' START');
		CALL pkLog.debug(l_inUserId, REPORT_ID,
					'---- 引数一覧 ------------------------------------');
 		CALL pkLog.debug(l_inUserId, REPORT_ID, '  l_inItakuKaishaCd = [' || l_inItakuKaishaCd || ']');
		CALL pkLog.debug(l_inUserId, REPORT_ID, '  l_inUserId        = [' || l_inUserId || ']');
		CALL pkLog.debug(l_inUserId, REPORT_ID, '  l_inChohyoKbn     = [' || l_inChohyoKbn || ']');
		CALL pkLog.debug(l_inUserId, REPORT_ID, '  l_inGyomuYmd      = [' || l_inGyomuYmd || ']');
		CALL pkLog.debug(l_inUserId, REPORT_ID, '  l_inKijunYm       = [' || l_inKijunYm || ']');
		CALL pkLog.debug(l_inUserId, REPORT_ID, '  l_inTsuchiYmd     = [' || l_inTsuchiYmd || ']');
		CALL pkLog.debug(l_inUserId, REPORT_ID,
					'--------------------------------------------------');
	END IF;
	-- 1. 入力パラメータチェック 
	IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, REPORT_ID, '1. 入力パラメータチェック');END IF;
	IF		coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
		OR	coalesce(trim(both l_inUserId)::text, '') = ''
		OR	coalesce(trim(both l_inChohyoKbn)::text, '') = ''
		OR	l_inChohyoKbn			<> '0'	-- 「帳票区分」0:リアル のみ
		OR	coalesce(trim(both l_inGyomuYmd)::text, '') = ''
		OR	coalesce(trim(both l_inKijunYm)::text, '') = ''
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, REPORT_ID, '×' || PROGRAM_ID || ' END（入力パラメータエラー）');END IF;
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', PROGRAM_ID, '');
		RETURN;
	END IF;
	-- 2. 初期設定 
	IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, REPORT_ID, '2. 初期設定');END IF;
	-- 2.1 通知日(西暦) 設定	(ex.「2007年 8月15日」)
	IF coalesce(trim(both l_inTsuchiYmd)::text, '') = '' THEN
		gFrmTsuchiYmd := TSUCHI_YMD_DEF;
	ELSE
		gFrmTsuchiYmd := trim(both pkDate.seirekiChangeSuppressNenGappi(trim(both l_inTsuchiYmd)));
	END IF;
	--【通知日(西暦) 設定に失敗した場合】通知日(西暦)にデフォルトの通知日をセットして続行する。
	IF coalesce(gFrmTsuchiYmd::text, '') = '' OR SUBSTR(gFrmTsuchiYmd, 1, 2) = '99' THEN 		-- 西暦変換fncは失敗時に「99年[月日]」([]内は可変)を返す
		IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, REPORT_ID, '  △通知日(西暦) 設定 失敗');END IF;
		gFrmTsuchiYmd := TSUCHI_YMD_DEF;
	END IF;
	-- 2.2 元利払年月(西暦) 設定
	gFrmGnrbrYm := substr(pkDate.seirekiChangeSuppressNenGappi(l_inKijunYm || '01'), 1, 10) || '分';
		-- 取得失敗しても困らないが「基準年月」に問題があるようでは困るので、例外等発生時は例外処理へ飛ばす。
	-- 2.3 自行_委託会社情報 設定
	BEGIN
		SELECT
			VJ1.BUSHO_NM1
		INTO STRICT
			gFrmBushoNm1
		FROM
			VJIKO_ITAKU VJ1
		WHERE
			VJ1.KAIIN_ID = l_inItakuKaishaCd
		;
	EXCEPTION WHEN OTHERS THEN
		-- 自行_委託会社情報 取得失敗の場合、自行_委託会社情報にNULLをセットして続行する。
		IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, REPORT_ID, '  △自行_委託会社情報 取得失敗：委託会社コード[' || l_inItakuKaishaCd || ']');END IF;
		gFrmBushoNm1	:= NULL;
	END;
	-- 2.4 請求文章 設定
	CALL SPIPX011K00R01_createBun(REPORT_ID, '00', gSeikyuBunsho, gSeikyuBunsho1);
	IF DEBUG = 1 THEN
		CALL pkLog.debug(l_inUserId, REPORT_ID, '  ---- 設定値一覧 ------------------------------------');
		CALL pkLog.debug(l_inUserId, REPORT_ID, '  通知日(西暦)       = [' || gFrmTsuchiYmd || ']');
		CALL pkLog.debug(l_inUserId, REPORT_ID, '  元利払年月(西暦)   = [' || gFrmGnrbrYm || ']');
		CALL pkLog.debug(l_inUserId, REPORT_ID, '  担当部署名称       = [' || gFrmBushoNm1 || ']');
		CALL pkLog.debug(l_inUserId, REPORT_ID, '  請求文章           = [' || gSeikyuBunsho || ']');
		CALL pkLog.debug(l_inUserId, REPORT_ID, '  請求文章(2行目)    = [' || gSeikyuBunsho1 || ']');
	END IF;
	-- 3. 帳票ワークの旧データ削除 
	IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, REPORT_ID, '3. 帳票ワークの旧データ削除');END IF;
	DELETE FROM SREPORT_WK
	 WHERE	KEY_CD		= l_inItakuKaishaCd
		AND	USER_ID		= l_inUserId
		AND	CHOHYO_KBN	= l_inChohyoKbn
		AND	SAKUSEI_YMD	= l_inGyomuYmd
		AND	CHOHYO_ID	= REPORT_ID
	;
	-- 4. 帳票ワークテーブル登録処理 -ヘッダ 
	IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, REPORT_ID, '4. 帳票ワークテーブル登録処理 -ヘッダ');END IF;
	CALL pkPrint.insertHeader(
				 l_inItakuKaishaCd
				,l_inUserId
				,l_inChohyoKbn
				,l_inGyomuYmd
				,REPORT_ID
	);
	-- 5. 帳票ワークテーブル登録処理 -データ 
	IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, REPORT_ID, '5. 帳票ワークテーブル登録処理 -データ');END IF;
	-----------------------------------------------------------------------------
	--	カーソル1レコードを、帳票wk1レコードとして登録する。
	--	ただし、同一利払日で、元金手数料徴求日と利金手数料徴求日が異なる場合、
	--	（ないことが前提であるが、対応はする）
	--	元金支払手数料、利金支払手数料それぞれで1件ずつ、計2件を出力する。
	--	（この場合、元金支払手数料、利金支払手数料、手数料徴求日 以外の内容は同じものを出力する
	-----------------------------------------------------------------------------
	-- 5.1 データ登録処理
	FOR recMeisai IN curMeisai LOOP
		-- 5.1.1 「連番」カウントアップ
		gSeqNo := gSeqNo + 1;
	IF DEBUG = 1 THEN
		CALL pkLog.debug(l_inUserId, REPORT_ID, '  ---- ' || gSeqNo || ' 行目 ---------------------------------------');
		CALL pkLog.debug(l_inUserId, REPORT_ID, '  取扱店コード       = ['|| recMeisai.KOZA_TEN_CD || ']');
		CALL pkLog.debug(l_inUserId, REPORT_ID, '  銘柄コード         = ['|| recMeisai.MGR_CD || ']');
		CALL pkLog.debug(l_inUserId, REPORT_ID, '  利払日             = ['|| recMeisai.RBR_YMD_SORT || ']');
	END IF;
		-- 5.1.2 作業用変数リセット
		gWkKknChokyuYmdWareki	:= NULL;	-- (作業用)基金徴求日
		gWkGnkn					:= NULL;	-- (作業用)元金
		gWkRkn					:= NULL;	-- (作業用)利金
		gWkTesuChokyuYmdWareki	:= NULL;	-- (作業用)手数料徴求日
		gWkTesu					:= NULL;	-- (作業用)手数料
		gWk2ndFlg				:= FALSE;	-- 2件目有無フラグ
		-- 5.1.3 作業用変数セット
		-- 元利金合計算出
		gWkGnrKngkSum := recMeisai.gnkn + recMeisai.rkn;
		-- 元金額		…0の場合出力しない
		IF recMeisai.GNKN > 0 THEN
			gWkGnkn := recMeisai.GNKN;
		END IF;
		-- 利金額		…0の場合出力しない
		IF recMeisai.RKN > 0 THEN
			gWkRkn := recMeisai.RKN;
		END IF;
		-- 元利金合計	…0の場合出力しない
		IF gWkGnrKngkSum = 0 THEN
			gWkGnrKngkSum := NULL;
		ELSE
			-- >0の場合、基金徴求日も出力する
			gWkKknChokyuYmdWareki := SPIPX011K00R01_warekiChangeZeroSuppressDot(recMeisai.KKN_CHOKYU_YMD);
		END IF;
		-- 手数料徴求日・手数料（1件目）
		IF recMeisai.TESU_G = 0 THEN
			--【1.手数料がないケース】
				-- 手数料情報はNULLをセット
			--【2.利金手数料のみがあるケース】
			IF recMeisai.TESU_R > 0 THEN
				gWkTesuChokyuYmdWareki
								:= SPIPX011K00R01_warekiChangeZeroSuppressDot(recMeisai.TESU_CHOKYU_YMD_R);	-- 利金手数料徴求日
				gWkTesu			:= recMeisai.TESU_R;											-- 利金手数料
			END IF;
		ELSE
			--【3.元金手数料のみがあるケース】
			IF recMeisai.TESU_R = 0 THEN
				gWkTesuChokyuYmdWareki
								:= SPIPX011K00R01_warekiChangeZeroSuppressDot(recMeisai.TESU_CHOKYU_YMD_G);	-- 元金手数料徴求日
				gWkTesu			:= recMeisai.TESU_G;											-- 元金手数料
			ELSE
				--【4.元金手数料徴求日と利金手数料徴求日が同一日のケース】
				IF recMeisai.TESU_CHOKYU_YMD_G = recMeisai.TESU_CHOKYU_YMD_R THEN
					gWkTesuChokyuYmdWareki
								:= SPIPX011K00R01_warekiChangeZeroSuppressDot(recMeisai.TESU_CHOKYU_YMD_G);	-- 元金手数料徴求日
					gWkTesu		:= recMeisai.TESU_G + recMeisai.TESU_R;							-- 元金手数料 + 利金手数料
				--【5.元金手数料徴求日と利金手数料徴求日が異なるケース】
				ELSE
					gWk2ndFlg	:= TRUE;	-- 2件目「有」を設定し、先に元金手数料を登録する
					gWkTesuChokyuYmdWareki
								:= SPIPX011K00R01_warekiChangeZeroSuppressDot(recMeisai.TESU_CHOKYU_YMD_G);	-- 元金手数料徴求日
					gWkTesu		:= recMeisai.TESU_G;											-- 元金手数料
				END IF;
			END IF;
		END IF;
		-- 5.1.4 帳票ワークへデータを追加（1件目）
		-- Clear composite type
		l_inItem := ROW();
		
		l_inItem.l_inItem001 := gFrmTsuchiYmd;										-- 001 通知日
		l_inItem.l_inItem002 := ATESAKI_DEF;										-- 002 宛先
		l_inItem.l_inItem003 := gFrmBushoNm1;										-- 003 担当部署名称１
		l_inItem.l_inItem004 := gSeikyuBunsho;										-- 004 請求文章
		l_inItem.l_inItem005 := gSeikyuBunsho1;										-- 005 請求文章１
		l_inItem.l_inItem006 := gFrmGnrbrYm;										-- 006 元利払年月
		l_inItem.l_inItem007 := recMeisai.KOZA_TEN_CD;								-- 007 口座店コード(取扱店)
		l_inItem.l_inItem008 := recMeisai.KOZA_TEN_NM;								-- 008 部店名称(取扱店名称)
		l_inItem.l_inItem009 := recMeisai.MGR_CD;									-- 009 銘柄コード
		l_inItem.l_inItem010 := SUBSTR(recMeisai.MGR_NM, 1, 50);					-- 010 銘柄回号
		l_inItem.l_inItem011 := recMeisai.KOZA_KAMOKU_NM;							-- 011 口座科目名称(引落口座)
		l_inItem.l_inItem012 := recMeisai.HKO_KOZA_NO;								-- 012 口座番号(引落口座)
		l_inItem.l_inItem013 := SPIPX011K00R01_warekiChangeZeroSuppressDot(recMeisai.RBR_YMD);		-- 013 利払日(西暦)
		l_inItem.l_inItem014 := SPIPX011K00R01_warekiChangeZeroSuppressDot(recMeisai.SHOKAN_YMD);	-- 014 償還日(西暦)
		l_inItem.l_inItem015 := gWkGnkn;											-- 015 元金額
		l_inItem.l_inItem016 := gWkRkn;												-- 016 利金額
		l_inItem.l_inItem017 := gWkKknChokyuYmdWareki;								-- 017 基金徴求日(西暦)
		l_inItem.l_inItem018 := gWkGnrKngkSum;										-- 018 元利払基金合計
		-- ↓2件目は、ここと「連番」だけ変更して登録する
		l_inItem.l_inItem019 := gWkTesuChokyuYmdWareki;								-- 019 手数料徴求日(西暦)
		l_inItem.l_inItem020 := gWkTesu;											-- 020 元利払手数料(税込)
		-- ↑
		
		CALL pkPrint.insertData(
					 l_inKeyCd		=> l_inItakuKaishaCd 				-- 識別コード
					,l_inUserId		=> l_inUserId 						-- ユーザID
					,l_inChohyoKbn	=> l_inChohyoKbn 					-- 帳票区分
					,l_inSakuseiYmd	=> l_inGyomuYmd 						-- 作成年月日
					,l_inChohyoId	=> REPORT_ID 						-- 帳票ID
					,l_inSeqNo		=> gSeqNo 							-- 連番
					,l_inHeaderFlg	=> '1'								-- ヘッダフラグ
					,l_inItem		=> l_inItem							-- アイテム
					,l_inKousinId	=> l_inUserId 						-- 更新者ID
					,l_inSakuseiId	=> l_inUserId 						-- 作成者ID
		);
		-- 5.1.5 2件目データのセットと登録
		IF gWk2ndFlg THEN
			CALL pkLog.debug(l_inUserId, REPORT_ID, '  2件目を登録：銘柄コード['|| recMeisai.MGR_CD || ']');
			-- 5.1.5.1 「連番」カウントアップ
			gSeqNo := gSeqNo + 1;
			-- 5.1.5.2 作業用変数セット
			-- 手数料徴求日・手数料セット（2件目）
				-- （それ以外の項目は、1件目と同じなのでいじらない）
			gWkTesuChokyuYmdWareki
						:= SPIPX011K00R01_warekiChangeZeroSuppressDot(recMeisai.TESU_CHOKYU_YMD_R);	-- 利金手数料徴求日
			gWkTesu		:= recMeisai.TESU_R;											-- 利金手数料
			-- 5.1.5.3 帳票ワークへデータを追加（2件目）
				-- ※注「帳票ワークへデータを追加（1件目）」のソース変更はここにも反映すること
				-- 　（現時点では内容は全く一緒）
			-- Update only changed items (019, 020)
			l_inItem.l_inItem019 := gWkTesuChokyuYmdWareki;								-- 019 手数料徴求日(西暦)
			l_inItem.l_inItem020 := gWkTesu;											-- 020 元利払手数料(税込)
			
			CALL pkPrint.insertData(
					 l_inKeyCd		=> l_inItakuKaishaCd 				-- 識別コード
					,l_inUserId		=> l_inUserId 						-- ユーザID
					,l_inChohyoKbn	=> l_inChohyoKbn 					-- 帳票区分
					,l_inSakuseiYmd	=> l_inGyomuYmd 						-- 作成年月日
					,l_inChohyoId	=> REPORT_ID 						-- 帳票ID
					,l_inSeqNo		=> gSeqNo 							-- 連番
					,l_inHeaderFlg	=> '1'								-- ヘッダフラグ
					,l_inItem		=> l_inItem							-- アイテム
					,l_inKousinId	=> l_inUserId 						-- 更新者ID
					,l_inSakuseiId	=> l_inUserId 						-- 作成者ID
			);
		END IF;
	END LOOP;
	IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, REPORT_ID, '☆取扱店別銘柄別元利金及び手数料一覧表　登録件数：' || gSeqNo || ' 件');END IF;
	-- 5.3 「対象データなし」レコード登録
	IF gSeqNo <= 0 THEN
		IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, REPORT_ID, '☆取扱店別銘柄別元利金及び手数料一覧表　対象データなしを登録');END IF;
		gRtnCd := NODATA;
		-- 帳票ワークへデータを追加
		-- Clear composite type
		l_inItem := ROW();
		
		l_inItem.l_inItem001 := gFrmTsuchiYmd;										-- 001 通知日
		l_inItem.l_inItem006 := gFrmGnrbrYm;										-- 006 元利払年月(画面値・西暦)
		l_inItem.l_inItem021 := '対象データなし';									-- 021 対象データなし
		
		CALL pkPrint.insertData(
					 l_inKeyCd		=> l_inItakuKaishaCd 	-- 識別コード
					,l_inUserId		=> l_inUserId 			-- ユーザID
					,l_inChohyoKbn	=> l_inChohyoKbn 		-- 帳票区分
					,l_inSakuseiYmd	=> l_inGyomuYmd 			-- 作成年月日
					,l_inChohyoId	=> REPORT_ID 			-- 帳票ID
					,l_inSeqNo		=> 1					-- 連番
					,l_inHeaderFlg	=> '1'					-- ヘッダフラグ
					,l_inItem		=> l_inItem				-- アイテム
					,l_inKousinId	=> l_inUserId 			-- 更新者ID
					,l_inSakuseiId	=> l_inUserId 			-- 作成者ID
		);
	END IF;
	-- 6. 正常終了処理 
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, REPORT_ID, '◎' || PROGRAM_ID || ' END');END IF;
	-- COMMIT
	--==============================================================================*
--		例外処理
--	 *==============================================================================
EXCEPTION
	WHEN OTHERS THEN
	-- ROLLBACK
		CALL pkLog.fatal('ECM701', PROGRAM_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', PROGRAM_ID, 'SQLERRM:' || SQLERRM);
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLERRM;
		IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, REPORT_ID, '×' || PROGRAM_ID || ' END（例外発生）');END IF;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipx011k00r01 ( l_inItakuKaishaCd TEXT  ,l_inUserId TEXT  ,l_inChohyoKbn TEXT  ,l_inGyomuYmd TEXT  ,l_inKijunYm TEXT  ,l_inTsuchiYmd TEXT  ,l_outSqlCode OUT numeric  ,l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spipx011k00r01_createbun ( 
	l_inReportID TEXT 
	,l_inPatternCd TEXT
	,l_outSeikyuBunsho OUT VARCHAR
	,l_outSeikyuBunsho1 OUT VARCHAR
) AS $body$
DECLARE

	aryBun	pkIpaBun.BUN_ARRAY;
BEGIN
	-- 請求文章の取得
	aryBun := pkIpaBun.getBun(l_inReportID, l_inPatternCd);
	IF coalesce(aryBun::text, '') = '' OR coalesce(cardinality(aryBun), 0) = 0 THEN
		RAISE EXCEPTION 'no_data_err' USING ERRCODE = '50001';
	END IF;
	FOR i IN 0..coalesce(cardinality(aryBun), 0) - 1 LOOP
		IF i = 0 THEN
			l_outSeikyuBunsho	:= aryBun[i];
		ELSIF i = 1 THEN
			l_outSeikyuBunsho1	:= aryBun[i];
		END IF;
		-- 3行目以降の請求文章は無視（ないことが前提）
	END LOOP;
EXCEPTION
	-- 請求文章取得失敗の場合、無視して続行する。
	WHEN OTHERS THEN
		-- DEBUG and l_inUserId, REPORT_ID are not available in nested procedure
		-- Just silently ignore error as per original logic
		NULL;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipx011k00r01_createbun ( l_inReportID TEXT ,l_inPatternCd BUN.BUN_PATTERN_CD%TYPE ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spipx011k00r01_warekichangezerosuppressdot (l_inKijunYmd TEXT) RETURNS char AS $body$
DECLARE

	warekiStr varchar(12);

BEGIN
	-- パラメータチェック
	IF coalesce(trim(both l_inKijunYmd)::text, '') = '' THEN
		RETURN NULL;
	END IF;
	-- 西暦変換(スペース埋め，スラッシュ編集)
	warekiStr := pkDate.seirekiChangeZeroSuppressSlash(l_inKijunYmd);
	-- スラッシュをドットに置換して返す
	RETURN REPLACE(warekiStr, '/', '.');
EXCEPTION
	WHEN OTHERS THEN
		-- DEBUG, l_inUserId, REPORT_ID are not available in nested function
		-- Just raise the exception as per original logic
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spipx011k00r01_warekichangezerosuppressdot (l_inKijunYmd TEXT) FROM PUBLIC;