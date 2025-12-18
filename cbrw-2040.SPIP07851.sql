




CREATE OR REPLACE PROCEDURE spip07851 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE,             -- 委託会社コード
 l_inUserId SREPORT_WK.USER_ID%TYPE,            -- ユーザーID
 l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE,         -- 帳票区分
 l_inGyomuYmd SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE,  -- 業務日付
 l_outSqlCode OUT integer,                             -- リターン値
 l_outSqlErrM OUT text                            -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2006
-- * 会社名:JIP
-- *
-- * 概要　:警告（共通）リストを作成する
-- * 【***重要***】締め処理用件数取得処理(sfIpaSime)と同期をとること!
-- * 注 IP-05535の修正のとき、SPIP07851の修正が
-- * sfIpaSimeの方に反映(同期)がされてませんでした。
-- * 工数が取れるときに同期を取ってください！
-- *
-- * 引数　:l_inItakuKaishaCd :委託会社コード
-- *        l_inUserId        :ユーザーID
-- *        l_inChohyoKbn     :帳票区分
-- *        l_inGyomuYmd      :業務日付
-- *        l_outSqlCode      :リターン値
-- *        l_outSqlErrM      :エラーコメント
-- *
-- * 返り値: なし
-- *
-- * @author ASK
-- * @version $Id: SPIP07851.sql,v 1.20 2008/10/04 07:51:25 fujimoto Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2006.06.29 ASK         新規作成
-- *　2006.12.12 ASK         新規記録情報承認可否未入力の警告追加
-- *　2008.02.05 ASK         新規記録結果情報未登録の警告追加
-- ***************************************************************************
--
	--==============================================================================
	--					デバッグ機能													
	--==============================================================================
		DEBUG	numeric(1)	:= 0;
	--==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_PROCEDURE_ID  CONSTANT text := 'SPIP07851';                -- プロシージャＩＤ
	C_CHOHYO_ID     CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IP030007851'; -- 帳票ＩＤ
	C_CODE_SHUBETSU CONSTANT SCODE.CODE_SHUBETSU%TYPE := '218';          -- コード種別
	C_NO_DATA       CONSTANT SCODE.CODE_SHUBETSU%TYPE := 2;              -- データなしリターン
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gSeqNo          		integer;                 -- シーケンス
	gItakuKaishaRnm 		SOWN_INFO.BANK_RNM%TYPE; -- 委託会社略名
	gCodeNm100      		SCODE.CODE_NM%TYPE;      -- 警告（新規募集情報未登録）
	gCodeNm101      		SCODE.CODE_NM%TYPE;      -- 警告（新規記録情報未受信）
	gCodeNm106      		SCODE.CODE_NM%TYPE;      -- 警告（新規記録承認可否未入力）
	gCodeNm107      		SCODE.CODE_NM%TYPE;      -- 警告（手数料設定情報未登録）
	gCodeNm108      		SCODE.CODE_NM%TYPE;      -- 警告（分かち課税日数設定あり）
	gCodeNm109      		SCODE.CODE_NM%TYPE;      -- 警告（実質記番号ＯＰ残高相違）
	gCodeNm110              SCODE.CODE_NM%TYPE;      -- 警告（新規記録結果情報未登録）
	gCodeSort100			SCODE.CODE_SORT%TYPE;    -- 警告 (新規募集情報未登録)の順序
	gCodeSort101			SCODE.CODE_SORT%TYPE;    -- 警告 (新規記録情報未受信)の順序
	gCodeSort106			SCODE.CODE_SORT%TYPE;    -- 警告 (新規記録承認可否未入力)の順序
	gCodeSort107			SCODE.CODE_SORT%TYPE;    -- 警告 (手数料設定情報未登録)の順序
	gCodeSort108			SCODE.CODE_SORT%TYPE;    -- 警告 (分かち課税日数設定あり)の順序
	gCodeSort109			SCODE.CODE_SORT%TYPE;    -- 警告 (実質記番号ＯＰ残高相違)の順序
	gCodeSort110            SCODE.CODE_SORT%TYPE;    -- 警告 (新規記録結果情報未登録)の順序
	gSakuseiYmd				varchar(8);
	gShinBoshuStatFlg		character := '0';    	 -- 警告（新規募集情報未登録）の出力有無フラグ
	gShinRecStatFlg			character := '0';   	 -- 警告（新規記録情報通知未受信）の出力有無フラグ
	gShinRecShoninKahiFlg	character := '0';    	 -- 警告（新規記録承認可否未入力）の出力有無フラグ
	gTesuSetStatFlg			character := '0';    	 -- 警告（手数料設定情報未登録）の出力有無フラグ
	gJisshitsukiOptionFlg	character := '0';		 --オプションフラグ(実質記番号)取得用変数
	gShinRecOptionFlg 		character := '0';		 --オプションフラグ(新規記録情報取込当日出力フラグ)
	gFurikaeCbOptionFlg     character := '0';       --オプションフラグ(振替ＣＢフラグ)
	gItakuKaishaCd			SREPORT_WK.KEY_CD%TYPE;
	gjikodaikokbn			char(1)		:= NULL;		-- 自行代行区分
	gbankrnm			varchar(20)	:= NULL;		-- 委託会社略称
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	--------------------------------------------------------------------------------
	-- ※データ取得のＳＱＬは「sfIpaSime：締め処理用件数取得処理」と同じものを利用しているので、同期を取ってください。
	--------------------------------------------------------------------------------
	curMeisai CURSOR FOR
		SELECT  --===========================================新規募集情報未登録
			gCodeNm100 AS WARNING_NM,		-- 警告名称
			gCodeSort100 AS WARNING_SORT,	-- 警告の出力順序
			VMG1.MGR_CD,					-- 銘柄コード
			VMG1.ISIN_CD,					-- ＩＳＩＮコード
			VMG1.MGR_RNM,					-- 銘柄略称
			VMG1.HAKKO_YMD,					-- 発行年月日
			0 AS CNT1,						-- 未受信件数（使用しない）
			0 AS CNT2,						-- 受信済件数（使用しない）
			'' AS BIKO 						-- 備考
		FROM
			MGR_KIHON_VIEW VMG1
		WHERE VMG1.ITAKU_KAISHA_CD = gItakuKaishaCd
			AND VMG1.MGR_STAT_KBN = '1'
			AND VMG1.JTK_KBN != '2'
			AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
			AND VMG1.TOKUREI_SHASAI_FLG = 'N'
			AND VMG1.HAKKO_YMD >= pkdate.getGyomuYmd()
			AND NOT(VMG1.SAIKEN_SHURUI IN ('80', '89') AND VMG1.HAKKO_KAGAKU = 0)
			AND NOT EXISTS (
				SELECT
					B01.MGR_CD
				FROM SHINKIBOSHU B01
				WHERE B01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
				AND B01.MGR_CD = VMG1.MGR_CD
			)
			AND gShinBoshuStatFlg = '1'
		
UNION ALL

		SELECT  --===========================================新規記録情報未受信
			gCodeNm101 AS WARNING_NM,		-- 警告名称
			gCodeSort101 AS WARNING_SORT,	-- 警告の出力順序
			T1.MGR_CD,						-- 銘柄コード
			T1.ISIN_CD,						-- ＩＳＩＮコード
			T1.MGR_RNM,						-- 銘柄略称
			T1.HAKKO_YMD,					-- 発行年月日
			T1.CNT AS CNT1,					-- 未受信件数
			coalesce(T2.CNT, 0) AS CNT2,			-- 受信済件数
			'' AS BIKO 						-- 備考
		FROM (
				-- 未受信
				SELECT
					VMG1.ITAKU_KAISHA_CD,
					VMG1.MGR_CD,
					VMG1.ISIN_CD,
					VMG1.MGR_RNM,
					VMG1.HAKKO_YMD,
					COUNT(*) AS CNT
				FROM
					MGR_KIHON_VIEW VMG1,
					VSHINKI_REC_STATUS_MANAGEMENT B04
				WHERE VMG1.ITAKU_KAISHA_CD = B04.ITAKU_KAISHA_CD
					AND VMG1.MGR_CD = B04.MGR_CD
					AND VMG1.ITAKU_KAISHA_CD = gItakuKaishaCd
					AND VMG1.MGR_STAT_KBN = '1'
					AND B04.DAIRI_MOTION_FLG != '1'					-- 0：機構加入者申請、1：代理人直接申請（VIEWは、機構申請は0、2がある）
					AND B04.MASSHO_FLG <> '1'
					AND B04.SHINCHOKU_STAT in ('H002', 'H103')		-- H002：新規記録情報通知待ち、H103：新規記録情報取消通知待ち
 
				GROUP BY
					VMG1.ITAKU_KAISHA_CD,
					VMG1.MGR_CD,
					VMG1.ISIN_CD,
					VMG1.MGR_RNM,
					VMG1.HAKKO_YMD
			) t1
LEFT OUTER JOIN (
				-- 受信済み
				SELECT
					VMG1.ITAKU_KAISHA_CD,
					VMG1.MGR_CD,
					VMG1.ISIN_CD,
					VMG1.MGR_RNM,
					VMG1.HAKKO_YMD,
					COUNT(*) AS CNT
				FROM
					MGR_KIHON_VIEW VMG1,
					VSHINKI_REC_STATUS_MANAGEMENT B04
				WHERE VMG1.ITAKU_KAISHA_CD = B04.ITAKU_KAISHA_CD
					AND VMG1.MGR_CD = B04.MGR_CD
					AND VMG1.ITAKU_KAISHA_CD = gItakuKaishaCd
					AND VMG1.MGR_STAT_KBN = '1'
					AND B04.DAIRI_MOTION_FLG != '1'					-- 0：機構加入者申請、1：代理人直接申請（VIEWは、機構申請は0、2がある）
					AND B04.MASSHO_FLG <> '1'
					AND B04.TOTSUGO_KEKKA_KBN != '3'				-- 3：突合相手なし
					AND B04.SHINCHOKU_STAT != 'H401'				-- H401：新規募集情報承認待ち
					AND B04.SHINCHOKU_STAT != 'H002'				-- H002：新規記録情報通知待ち
					AND B04.SHINCHOKU_STAT != 'H103'				-- H103：新規記録情報取消通知待ち
					AND B04.SHINCHOKU_STAT != 'H004'				-- H004：新規記録情報取消完了
				GROUP BY
					VMG1.ITAKU_KAISHA_CD,
					VMG1.MGR_CD,
					VMG1.ISIN_CD,
					VMG1.MGR_RNM,
					VMG1.HAKKO_YMD
			) t2 ON (T1.ITAKU_KAISHA_CD = T2.ITAKU_KAISHA_CD AND T1.MGR_CD = T2.MGR_CD)
WHERE gShinRecStatFlg = '1'
		 
UNION ALL

		SELECT  --===========================================新規記録承認可否未入力
			gCodeNm106 AS WARNING_NM,		-- 警告名称
			gCodeSort106 AS WARNING_SORT,	-- 警告の出力順序
			VMG1.MGR_CD,					-- 銘柄コード
			VMG1.ISIN_CD,					-- ＩＳＩＮコード
			VMG1.MGR_RNM,					-- 銘柄略称
			VMG1.HAKKO_YMD,					-- 発行年月日
			0 AS CNT1,						-- 未受信件数（使用しない）
			0 AS CNT2,						-- 受信済件数（使用しない）
			substr(
				'決番：' ||
				B04.KESSAI_NO ||
				'　金融：' ||
				PKIPANAME.getBankRnm(B04.ITAKU_KAISHA_CD,B04.KAI_BANKID_CD,0,1),
				1, 44)
			AS BIKO 							-- 備考
		FROM
			SHINKIKIROKU B04,
			MGR_KIHON_VIEW VMG1
		WHERE
			B04.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
			AND B04.ISIN_CD = VMG1.ISIN_CD
			--*
--			 * IP-05722(2007/12)での対応
--			 * ==注== IP-05535の修正のとき、SPIP07851の修正が
--			 * sfIpaSimeの方に反映(同期)がされてませんでした。
--			 * IP-05722での対応ではオプションフラグ対応分だけ修正しています。
--			 
			-- :: 新規記録情報取込当日出力OPフラグによる抽出制御 (ここから) ::
			AND (
			     -- 当日出力OPフラグがオン_*オプション用
				 	-- (新規募集情報テーブル、業務日付をチェックしない(条件にしない))
			      (gShinRecOptionFlg = '1')
		          OR
		         -- 当日出力OPフラグがオフ_*パッケージ分
				 	-- (新規募集情報テーブルに存在 AND 業務日付より前日 をチェックする)
		          (
		            (EXISTS (SELECT B01.MGR_CD
		                      FROM SHINKIBOSHU B01
		                      WHERE
		                              B01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
		                              AND B01.MGR_CD = VMG1.MGR_CD
									  AND B01.KESSAI_NO = B04.KESSAI_NO
									  AND B01.MASSHO_FLG != '1'
		                )
		             )
		            AND ( to_char(B04.SAKUSEI_DT, 'YYYYMMDD') < l_inGyomuYmd )
		           )
		        )
		    -- :: 新規記録情報取込当日出力OPフラグによる抽出制御 (ここまで) ::
			AND B04.ITAKU_KAISHA_CD = gItakuKaishaCd
			AND B04.KK_PHASE || B04.KK_STAT IN ('H003', 'H101', 'H102')
				--*
--				 * 新規記録承認可否未入力の警告は送信(CSV作成)が実行されるまで
--				 * 警告を出力する。
--				 * そのため、
--				 * H003:新規記録情報承認可否入力待ち
--				 * H101:新規記録情報承認待ち
--				 * H102:新規記録情報承認承認送信待ち
--				 * 上記、承認・非承認送信前までが警告の対象ステータスとなる。
--				 *
--				 * (030詳細設計\24_状態遷移図\)
--				 * 状態遷移図(ステートチャート図)新規記録関係.xlsを参照のこと
--				 
			AND VMG1.MGR_STAT_KBN = '1'
			AND VMG1.JTK_KBN != '2'					-- 特例社債ではない
			AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '') 		-- ISIN付番されている
			AND VMG1.TOKUREI_SHASAI_FLG = 'N'		-- 特例社債ではない
			AND gShinRecShoninKahiFlg = '1'			-- 警告（新規記録承認可否未入力）の出力有無フラグ
 
		
UNION ALL

		SELECT  --===========================================手数料設定情報未登録
			gCodeNm107 AS WARNING_NM,		-- 警告名称
			gCodeSort107 AS WARNING_SORT,	-- 警告の出力順序
			VMG1.MGR_CD,					-- 銘柄コード
			VMG1.ISIN_CD,					-- ＩＳＩＮコード
			VMG1.MGR_RNM,					-- 銘柄略称
			VMG1.HAKKO_YMD,					-- 発行年月日
			0 AS CNT1,						-- 未受信件数（使用しない）
			0 AS CNT2,						-- 受信済件数（使用しない）
			'' AS BIKO 						-- 備考
		FROM
			MGR_KIHON_VIEW VMG1
		WHERE VMG1.ITAKU_KAISHA_CD = gItakuKaishaCd
			AND VMG1.TESU_SET_TEISEI_YMD = ' '
			AND VMG1.MGR_STAT_KBN = '1'
			AND (VMG1.KK_KANYO_FLG <> '2' OR gJisshitsukiOptionFlg = '1')
			AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
			AND gTesuSetStatFlg = '1' 
		
UNION ALL

		SELECT  --===========================================分かち課税日数未来分が設定されている件数
			gCodeNm108 AS WARNING_NM,		-- 警告名称
			gCodeSort108 AS WARNING_SORT,	-- 警告の出力順序
			VMG1.MGR_CD,					-- 銘柄コード
			VMG1.ISIN_CD,					-- ＩＳＩＮコード
			VMG1.MGR_RNM,					-- 銘柄略称
			VMG1.HAKKO_YMD,					-- 発行年月日
			0 AS CNT1,						-- 未受信件数（使用しない）
			0 AS CNT2,						-- 受信済件数（使用しない）
			'' AS BIKO 						-- 備考
		FROM
			MGR_KIHON_VIEW VMG1,
			(SELECT ITAKU_KAISHA_CD,MGR_CD
			FROM MGR_RBRKIJ
			WHERE ITAKU_KAISHA_CD = gItakuKaishaCd
			AND   RBR_YMD = l_inGyomuYmd
			GROUP BY ITAKU_KAISHA_CD,MGR_CD) MG2,
			KBG_SHOKIJ P01,
			KBG_SHOKBG P02
		WHERE VMG1.ITAKU_KAISHA_CD = gItakuKaishaCd
		AND VMG1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = MG2.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = P01.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = P01.MGR_CD
		AND VMG1.ITAKU_KAISHA_CD = P02.ITAKU_KAISHA_CD
		AND VMG1.MGR_CD = P02.MGR_CD
		--  2007/09/12 ADD JIP  -------------------------------
		AND (
				(  P01.SHOKAN_KJT = P02.SHOKAN_KJT		 AND
				   P01.KBG_SHOKAN_KBN = P02.KBG_SHOKAN_KBN AND
				   P01.SHOKAN_YMD > l_inGyomuYmd
				)
				OR coalesce(trim(both P02.SHOKAN_KJT)::text, '') = ''
			)
		--  2007/09/12 ADD JIP  -------------------------------
		AND P02.WKC_TAX_DAYS != 0
		AND VMG1.MGR_STAT_KBN = '1'
		AND VMG1.KK_KANYO_FLG = '2'
		AND gJisshitsukiOptionFlg = '1'
		AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '') 
		GROUP BY
			gCodeNm108,
			gCodeSort108,
			VMG1.MGR_CD,
			VMG1.ISIN_CD,
			VMG1.MGR_RNM,
			VMG1.HAKKO_YMD
		
UNION ALL

		SELECT  --===========================================実質記番号ＯＰ残高相違
			gCodeNm109 AS WARNING_NM,								-- 警告名称
			gCodeSort109 + (VSEQ.VAL / 10) AS WARNING_SORT,			-- 警告の出力順序
			V.MGR_CD,												-- 銘柄コード
			V.ISIN_CD,												-- ＩＳＩＮコード
			V.MGR_RNM,												-- 銘柄略称
			V.HAKKO_YMD,											-- 発行年月日
			0 AS CNT1,												-- 未受信件数（使用しない）
			0 AS CNT2,												-- 受信済件数（使用しない）
		CASE WHEN VSEQ.VAL=1 THEN  'パ:' || trim(both to_char(V.A::numeric, '99,999,999,999,999')) || ' 実:' || trim(both to_char(V.B::numeric, '99,999,999,999,999')) WHEN VSEQ.VAL=2 THEN  'パ:' || trim(both to_char(V.A::numeric, '99,999,999,999,999')) || ' 記:' || trim(both to_char(V.C::numeric, '99,999,999,999,999'))  ELSE '実:' || trim(both to_char(V.B::numeric, '99,999,999,999,999')) || ' 記:' || trim(both to_char(V.C::numeric, '99,999,999,999,999')) END  AS BIKO 												-- 備考
		FROM (
				SELECT
					VMG1.MGR_CD,					-- 銘柄コード
					VMG1.ISIN_CD,					-- ＩＳＩＮコード
					VMG1.MGR_RNM,					-- 銘柄略称
					VMG1.HAKKO_YMD,					-- 発行年月日
					PKIPAZNDK.getKjnZndk(VMG1.ITAKU_KAISHA_CD, VMG1.MGR_CD, l_inGyomuYmd, 3) A,		--パッケージ残高
					PKIPAKIBANGO.getKjnZndk(VMG1.ITAKU_KAISHA_CD, VMG1.MGR_CD, l_inGyomuYmd) B,		--実質記番号償還回次残高
					PKIPAKIBANGO.getShoKbgZndk(VMG1.ITAKU_KAISHA_CD, VMG1.MGR_CD, l_inGyomuYmd) C 	--実質記番号情報残高
				FROM
					MGR_KIHON_VIEW VMG1
				WHERE VMG1.ITAKU_KAISHA_CD = gItakuKaishaCd
				AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
				AND VMG1.MGR_STAT_KBN = '1'
				AND VMG1.KK_KANYO_FLG = '2'
				AND gJisshitsukiOptionFlg = '1' 
			) V,
			
			(
				SELECT 1 AS VAL  	
UNION ALL

				SELECT 2 AS VAL  	
UNION ALL

				SELECT 3 AS VAL 
			) VSEQ
		WHERE (VSEQ.VAL = 1 AND V.A::numeric <> V.B)
		OR (VSEQ.VAL = 2 AND V.A::numeric <> V.C)
		OR (VSEQ.VAL = 3 AND V.B <> V.C) 
		
UNION ALL

		SELECT  --===========================================新規記録結果情報未登録
			gCodeNm110   AS WARNING_NM,      -- 警告名称
			gCodeSort110 AS WARNING_SORT,    -- 警告の出力順序
			VMG1.MGR_CD,                     -- 銘柄コード
			VMG1.ISIN_CD,                    -- ＩＳＩＮコード
			VMG1.MGR_RNM,                    -- 銘柄略称
			VMG1.HAKKO_YMD,                  -- 発行年月日
			0 AS CNT1,                       -- 未受信件数（使用しない）
			0 AS CNT2,                       -- 受信済件数（使用しない）
			'' AS BIKO                        -- 備考
		FROM
			MGR_KIHON_VIEW VMG1
		WHERE VMG1.ITAKU_KAISHA_CD    =  gItakuKaishaCd
		AND   VMG1.MGR_STAT_KBN       =  '1'
		AND   VMG1.JTK_KBN            != '2'
		AND   (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
		AND   VMG1.TOKUREI_SHASAI_FLG =  'N'
		AND   VMG1.SAIKEN_SHURUI      IN ('80', '89')
		AND   VMG1.HAKKO_YMD          >= pkdate.getGyomuYmd()
		AND   EXISTS (
				SELECT
					MGR_CD
				FROM
					SHINKIBOSHU
				WHERE ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
				AND   MGR_CD          = VMG1.MGR_CD
		)
		AND   NOT EXISTS (
				SELECT
					MGR_CD
				FROM
					NYUKIN_YOTEI
				WHERE ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
				AND   MGR_CD          = VMG1.MGR_CD
		)
		AND gFurikaeCbOptionFlg       =  '1' 
		ORDER BY
			MGR_CD,
			WARNING_SORT,
			BIKO;
	--------------------------------------------------------------------------------
	-- 委託会社コードの取得カーソル
	--------------------------------------------------------------------------------
	curItakuKaisha CURSOR FOR
		SELECT
			KAIIN_ID,
			CASE WHEN JIKO_DAIKO_KBN='1' THEN  ' '  ELSE BANK_RNM END  AS BANK_RNM
		FROM
			VJIKO_ITAKU
		WHERE
			KAIIN_ID = CASE WHEN l_inItakuKaishaCd=pkconstant.DAIKO_KEY_CD() THEN  KAIIN_ID  ELSE l_inItakuKaishaCd END
		ORDER BY KAIIN_ID;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
    IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, C_PROCEDURE_ID||' START');	END IF;
    -- 入力パラメータチェック
    IF coalesce(l_inItakuKaishaCd::text, '') = ''  -- 委託会社コード
    OR coalesce(l_inUserId::text, '') = ''         -- ユーザーID
    OR coalesce(l_inChohyoKbn::text, '') = '' THEN  -- 帳票区分
        -- ログ書込み
        CALL pkLog.fatal('ECM701', C_PROCEDURE_ID, 'パラメータエラー');
        l_outSqlCode := pkconstant.FATAL();
        l_outSqlErrM := '';
        RETURN;
    END IF;
	IF DEBUG = 1 THEN
	    CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '引数');
	    CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '委託会社コード:"' 	|| l_inItakuKaishaCd ||'"');
	    CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'ユーザーＩＤ:"' 	|| l_inUserId ||'"');
	    CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票区分:"' 		|| l_inChohyoKbn ||'"');
	    CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '業務日付:"' 		|| l_inGyomuYmd ||'"');
	END IF;
    -- シーケンス初期化
    gSeqNo := 1;
    -- 警告（新規募集情報未登録）取得
    BEGIN
        SELECT CODE_NM, CODE_SORT INTO STRICT gCodeNm100, gCodeSort100
        FROM SCODE
        WHERE CODE_SHUBETSU = C_CODE_SHUBETSU
        AND CODE_VALUE = '100';
    EXCEPTION
        WHEN no_data_found THEN
            gCodeNm100 := '新規募集情報未登録';
            gCodeSort100 := 1;
    END;
    -- 警告（新規記録情報未受信）取得
    BEGIN
        SELECT CODE_NM, CODE_SORT INTO STRICT gCodeNm101, gCodeSort101
        FROM SCODE
        WHERE CODE_SHUBETSU = C_CODE_SHUBETSU
        AND CODE_VALUE = '101';
    EXCEPTION
        WHEN no_data_found THEN
            gCodeNm101 := '新規記録情報未受信';
            gCodeSort101 := 2;
    END;
	-- 警告（新規記録承認可否未入力）取得
    BEGIN
        SELECT CODE_NM, CODE_SORT INTO STRICT gCodeNm106, gCodeSort106
        FROM SCODE
        WHERE CODE_SHUBETSU = C_CODE_SHUBETSU
        AND CODE_VALUE = '106';
    EXCEPTION
        WHEN no_data_found THEN
            gCodeNm106 := '新規記録承認可否未入力';
            gCodeSort106 := 7;
    END;
    -- 警告（手数料設定情報未登録）取得
    BEGIN
        SELECT CODE_NM, CODE_SORT INTO STRICT gCodeNm107, gCodeSort107
        FROM SCODE
        WHERE CODE_SHUBETSU = C_CODE_SHUBETSU
        AND CODE_VALUE = '107';
    EXCEPTION
        WHEN no_data_found THEN
            gCodeNm107 := '手数料設定情報未登録';
            gCodeSort107 := 8;
    END;
    -- 警告（分かち課税日数未来分設定あり）取得
    BEGIN
        SELECT CODE_NM, CODE_SORT INTO STRICT gCodeNm108, gCodeSort108
        FROM SCODE
        WHERE CODE_SHUBETSU = C_CODE_SHUBETSU
        AND CODE_VALUE = '108';
    EXCEPTION
        WHEN no_data_found THEN
            gCodeNm108 := '分かち課税日数設定あり';
            gCodeSort108 := 9;
    END;
    -- 警告（実質記番号ＯＰ残高相違）取得
    BEGIN
        SELECT CODE_NM, CODE_SORT INTO STRICT gCodeNm109, gCodeSort109
        FROM SCODE
        WHERE CODE_SHUBETSU = C_CODE_SHUBETSU
        AND CODE_VALUE = '109';
    EXCEPTION
        WHEN no_data_found THEN
            gCodeNm109 := '実質記番号ＯＰ残高相違';
            gCodeSort109 := 10;
    END;
	-- 警告（新規記録結果情報未登録）取得
	BEGIN
		SELECT
			CODE_NM,
			CODE_SORT
		INTO STRICT
			gCodeNm110,
			gCodeSort110
		FROM
			SCODE
		WHERE CODE_SHUBETSU = C_CODE_SHUBETSU
		AND   CODE_VALUE    = '110';
	EXCEPTION
		WHEN no_data_found THEN
			gCodeNm110   := '新規記録結果情報未登録';
			gCodeSort110 := 11;
    END;
    
    -- 帳票ワークテーブル削除処理
    DELETE FROM SREPORT_WK
        WHERE KEY_CD = l_inItakuKaishaCd
        AND USER_ID = l_inUserId
        AND CHOHYO_KBN = l_inChohyoKbn
        AND SAKUSEI_YMD = l_inGyomuYmd
        AND CHOHYO_ID = C_CHOHYO_ID;
        
	IF DEBUG = 1 THEN
	    CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '削除条件');
	    CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '識別コード:"' || l_inItakuKaishaCd ||'"');
	    CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'ユーザーＩＤ:"' || l_inUserId ||'"');
	    CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票区分:"' || l_inChohyoKbn ||'"');
	    CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '作成日付:"' || l_inGyomuYmd ||'"');
	    CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票ＩＤ:"' || C_CHOHYO_ID ||'"');
	END IF;
	-- 夜間バッチで作成する場合にはデータ基準日を出力する。
	IF (l_inChohyoKbn = pkKakuninList.CHOHYO_KBN_BATCH()) THEN
		gSakuseiYmd := l_inGyomuYmd;
	ELSE
		gSakuseiYmd := NULL;
	END IF;
    -- 処理制御フラグ取得
    --警告（新規募集情報未登録）の警告リスト出力有無
    gShinBoshuStatFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'SPIP07851001', '0');
    --警告(新規新規記録情報通知未受信)の警告リスト出力有無
    gShinRecStatFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'SPIP07851002', '0');
    --警告(新規記録承認可否未入力)の警告リスト出力有無
    gShinRecShoninKahiFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'SPIP07851003', '0');
    --警告(手数料設定情報未登録)の警告リスト出力有無
    gTesuSetStatFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'SPIP07851004', '0');
    --オプションフラグ(実質記番号)取得
    gJisshitsukiOptionFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd,'IPP1003302010','0');
    --オプションフラグ(新規記録情報取込当日出力フラグ)
    gShinRecOptionFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd,'SPIP07851005','0');
    --オプションフラグ(振替ＣＢフラグ)
    gFurikaeCbOptionFlg := pkControl.getOPTION_FLG(l_inItakuKaishaCd, 'IPW1000000001', '0');
    
    -- データ取得
    FOR recItakuKaisha IN curItakuKaisha
    LOOP
	--委託会社コードのセット
	gItakuKaishaCd := recItakuKaisha.KAIIN_ID;
	    -- データ取得
	    FOR recMeisai IN curMeisai
	    LOOP
	        -- 明細レコード追加
	        		-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := recItakuKaisha.BANK_RNM;	-- 委託会社略名
		v_item.l_inItem002 := l_inGyomuYmd;	-- 業務日付
		v_item.l_inItem003 := LPAD(pkcharacter.numeric_to_char(gSeqNo), 3, '0');	-- №
		v_item.l_inItem004 := recMeisai.MGR_CD;	-- 銘柄コード
		v_item.l_inItem005 := recMeisai.ISIN_CD;	-- ＩＳＩＮコード
		v_item.l_inItem006 := recMeisai.MGR_RNM;	-- 銘柄略名
		v_item.l_inItem007 := recMeisai.HAKKO_YMD;	-- 発行年月日
		v_item.l_inItem008 := recMeisai.WARNING_NM;	-- 警告
		v_item.l_inItem009 := SPIP07851_formatBiko(recMeisai.CNT1, recMeisai.CNT2, recMeisai.BIKO);	-- 備考
		v_item.l_inItem010 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem011 := C_CHOHYO_ID;	-- 帳票ＩＤ
		v_item.l_inItem013 := gSakuseiYmd;	-- データ基準日
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> C_CHOHYO_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	        -- シーケンスのカウント
	        gSeqNo := gSeqNo + 1;
	    END LOOP;
    END LOOP;
    IF gSeqNo = 1 THEN
        -- ヘッダレコードを追加
        CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, C_CHOHYO_ID);
		-- 自行情報の取得
		CALL SPIP07851_getJikouInfo(l_inItakuKaishaCd, gjikodaikokbn, gItakuKaishaRnm);
        -- 対象データなし
        		-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gItakuKaishaRnm;	-- 委託会社略名
		v_item.l_inItem010 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem011 := C_CHOHYO_ID;	-- 帳票ＩＤ
		v_item.l_inItem012 := '対象データなし';	-- 対象データなし
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> C_CHOHYO_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
        l_outSqlCode := C_NO_DATA;
        l_outSqlErrM := '';
    ELSE
        -- ヘッダレコードを追加
        CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, C_CHOHYO_ID);
        -- 正常終了
        l_outSqlCode := pkconstant.success();
        l_outSqlErrM := '';
    END IF;
    IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, C_PROCEDURE_ID ||' END');	END IF;
-- エラー処理
EXCEPTION
    WHEN OTHERS THEN
        CALL pkLog.fatal('ECM701', C_PROCEDURE_ID, 'SQLCODE:' || SQLSTATE);
        CALL pkLog.fatal('ECM701', C_PROCEDURE_ID, 'SQLERRM:' || SQLERRM);
        l_outSqlCode := pkconstant.FATAL();
        l_outSqlErrM := SQLSTATE || SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip07851 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE, l_inUserId SREPORT_WK.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_inGyomuYmd SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spip07851_formatbiko ( l_inCnt1 numeric, l_inCnt2 numeric, l_inBiko text ) RETURNS varchar AS $body$
DECLARE

	total				numeric;
	biko				varchar(40);

BEGIN
	biko := null;
	-- 未受信、受信済ともゼロ件の場合、編集しない
	IF (l_inCnt1 = 0 AND l_inCnt2 = 0) THEN
		return l_inBiko;
	END IF;
	-- 合計算出
	total := l_inCnt1 + l_inCnt2;
	biko := '機構申請' || LPAD(trim(both total::text), 3, ' ') || '件';
	biko := biko || '(未受信' || LPAD(trim(both l_inCnt1::text), 3, ' ') || '件、';
	biko := biko || '受信済' || LPAD(trim(both l_inCnt2::text), 3, ' ') || '件)';
	RETURN biko;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spip07851_formatbiko ( l_inCnt1 numeric, l_inCnt2 numeric, l_inBiko text ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spip07851_getjikouinfo ( 
	l_inItakuKaishaCd TEXT,
	INOUT gjikodaikokbn char(1),
	INOUT gItakuKaishaRnm varchar(100)
) AS $body$
BEGIN
	SELECT
		jiko_daiko_kbn,				-- 自行代行区分
		bank_rnm 				-- 委託会社略称
	INTO STRICT
		gjikodaikokbn,
		gItakuKaishaRnm
	FROM
		VJIKO_ITAKU
	WHERE
		kaiin_id = l_inItakuKaishaCd;
	-- 自行代行区分が'1'のときに委託会社略称を表示しない
	IF gjikodaikokbn != '2' THEN
		gItakuKaishaRnm := NULL;
	END IF;
EXCEPTION
	WHEN no_data_found THEN
		gItakuKaishaRnm := NULL;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip07851_getjikouinfo ( l_inItakuKaishaCd TEXT, INOUT gjikodaikokbn char, INOUT gItakuKaishaRnm varchar ) FROM PUBLIC;
