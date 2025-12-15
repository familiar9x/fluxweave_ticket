




CREATE OR REPLACE PROCEDURE spipx022k95102r01 ( l_inItakuKaishaCd SREPORT_WK_SSKM.KEY_CD%TYPE,		-- 委託会社コード
 l_inUserId SREPORT_WK_SSKM.USER_ID%TYPE,		-- ユーザーID
 l_inChohyoKbn SREPORT_WK_SSKM.CHOHYO_KBN%TYPE,	-- 帳票区分
 l_inChohyoId SREPORT_WK_SSKM.CHOHYO_ID%TYPE,		-- 帳票ID	
 l_inGyomuYmd SREPORT_WK_SSKM.SAKUSEI_YMD%TYPE,	-- 業務日付
 l_inMgrCd text,							-- 銘柄コード
 l_inIsinCd text,							-- ISINコード
 l_inTsuchiYmd text,							-- 通知日
 l_outSqlCode OUT integer 								-- リターンコード
 ) AS $body$
DECLARE

--
-- * 著作権:Copyright(c)2022
-- * 会社名:JIP
-- * @author ASK
-- * @version $Id: $
-- * 概要  :差込帳票出力指示画面の入力条件により、保証料明細書を作成する。
-- *
-- * 引数  :l_inItakuKaishaCd :    -- 委託会社コード 
-- *        l_inUserId        :    -- ユーザーID
-- *        l_inChohyoKbn     :    -- 帳票区分
-- *        l_inChohyoId      :    -- 帳票ID
-- *        l_inGyomuYmd      :    -- 業務日付
-- *        l_inMgrCd         :    -- 銘柄コード
-- *        l_inIsinCd        :    -- ISINコード
-- *        l_inTsuchiYmd     :    -- 通知日
-- *        l_outSqlCode      :    -- リターンコード
-- *
-- * 返り値: なし
-- *
--***************************************************************************
-- * ログ　: 
-- * 	日付			開発者名		目的
-- * -------------------------------------------------------------------
-- *　2022.10.27	ASK	新規作成
-- *
--***************************************************************************
--
--==============================================================================
--                  デバッグ機能                                                 
--==============================================================================
	DEBUG	numeric(1)	:= 0;
--==============================================================================
--                  定数定義                                                    
--==============================================================================
	C_PROCEDURE_ID     CONSTANT varchar(50) := 'SPIPX022K95102R01';			-- プロシージャID
	C_DEFAULT_TSUKA_CD CONSTANT MGR_KIHON.HAKKO_TSUKA_CD%TYPE := 'JPY';			-- デフォルト通貨コード
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	gRtnCd				integer :=	0;						-- リターンコード
	gSeqNo				numeric := 0;						-- シーケンス
	gCnt				numeric := 0;						-- カウント
	gSqlErrM			varchar(200);							-- エラーメッセージ
--==============================================================================
--                  カーソル定義                                                
--==============================================================================
	-- 期中管理手数料、期中信託報酬カーソル
	curTesuryo CURSOR(itakuKaishaCd text, mgrCd text, isinCd text) FOR
		SELECT	MG4.ITAKU_KAISHA_CD,
				MG4.MGR_CD,
				MG4.CHOKYU_KJT,					-- 徴求期日
				MG4.TESU_SHURUI_CD,				-- 手数料種類コード
				MG4.CHOKYU_YMD 					-- 徴求日
		FROM	MGR_TESKIJ MG4,
				MGR_KIHON_VIEW VMG1
		WHERE	VMG1.ITAKU_KAISHA_CD = MG4.ITAKU_KAISHA_CD
		AND		VMG1.MGR_CD = MG4.MGR_CD
		AND 	MG4.TESU_SHURUI_CD IN ('11', '12')							-- 11:期中管理手数料;12:期中信託報酬
		AND		VMG1.ITAKU_KAISHA_CD = itakuKaishaCd 						-- 委託会社コード
		AND		VMG1.HAKKO_TSUKA_CD = C_DEFAULT_TSUKA_CD 					-- デフォルト通貨コード
		AND (coalesce(trim(both mgrCd)::text, '') = '' OR VMG1.MGR_CD = trim(both mgrCd))			-- 銘柄コード
		AND (coalesce(trim(both isinCd)::text, '') = '' OR VMG1.ISIN_CD = trim(both isinCd))		-- ISINコード
		ORDER BY
				MG4.ITAKU_KAISHA_CD,
				MG4.MGR_CD,
				MG4.TESU_SHURUI_CD,			-- 手数料種類コード
				MG4.CHOKYU_KJT;
	-- 銀行保証料取得カーソル
	curHoshoryo CURSOR(itakuKaishaCd text, mgrCd text, isinCd text) FOR
		SELECT	VMG1.ITAKU_KAISHA_CD,							-- 委託会社コード
				VMG1.MGR_CD,									-- 銘柄コード
				VMG1.ISIN_CD,									-- ＩＳＩＮコード
				VMG1.MGR_NM,									-- 銘柄の正式名称
				VMG1.HAKKO_YMD,									-- 発行年月日
				M01.HKT_NM,										-- 発行体名称
				VJ1.BANK_NM,									-- 金融機関名称
				VMG1.FULLSHOKAN_KJT,							-- 満期償還期日
				VMG1.SHASAI_TOTAL,								-- 社債の総額
				VMG1.BNK_GUARANTEE_RATE,						-- 銀行保証料率
				M04.BUTEN_NM,									-- 保証料受入店
				M01.KOZA_TEN_CD,								-- 口座店コード
				MG4.CHOKYU_YMD,									-- 徴求日
				T01.KIJUN_ZNDK,									-- 計算額面金額
				T03.CALC_F_YMD,									-- 計算期間From
				T03.CALC_T_YMD,									-- 計算期間To
				T03.CALC_DD_BUNSHI,								-- 計算日数
				PKIPACALCTESURYO.getHoseiKasanKngk(
					T01.ALL_TESU_KNGK,
					T01.HOSEI_ALL_TESU_KNGK,
					T01.DATA_SAKUSEI_KBN,
					T01.SHORI_KBN) AS HOSHORYO_KNGK,			-- 保証料金額
				VJ1.BUSHO_NM1,									-- 担当部署名称
				M01.SFSK_BUSHO_NM 								-- 送付先担当部署名称
				,M01.EIGYOTEN_CD 								-- 営業店コード
				,M05.BUTEN_NM AS KOZA_TEN_NM 					-- 口座店名称
		FROM	MBUTEN M04,
				MHAKKOTAI M01,
				VJIKO_ITAKU VJ1,
				TESURYO_KICHU T03,
				TESURYO T01,
				MGR_TESKIJ MG4,
				MGR_KIHON_VIEW VMG1,
				MBUTEN M05
		WHERE	VMG1.ITAKU_KAISHA_CD = MG4.ITAKU_KAISHA_CD
		AND		VMG1.MGR_CD = MG4.MGR_CD
		AND		MG4.ITAKU_KAISHA_CD = T01.ITAKU_KAISHA_CD
		AND		MG4.MGR_CD = T01.MGR_CD
		AND		MG4.TESU_SHURUI_CD = T01.TESU_SHURUI_CD
		AND		MG4.CHOKYU_KJT = T01.CHOKYU_KJT
		AND		MG4.TESU_SHURUI_CD IN ('11', '12')							-- 11:期中管理手数料;12:期中信託報酬
		AND		T01.ITAKU_KAISHA_CD = T03.ITAKU_KAISHA_CD
		AND		T01.MGR_CD = T03.MGR_CD
		AND		T01.TESU_SHURUI_CD = T03.TESU_SHURUI_CD
		AND		T01.CHOKYU_KJT = T03.CHOKYU_KJT
		AND		VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
		AND		VMG1.HKT_CD = M01.HKT_CD
		AND		M01.ITAKU_KAISHA_CD = M04.ITAKU_KAISHA_CD
		AND		M01.EIGYOTEN_CD = M04.BUTEN_CD
		AND		M01.ITAKU_KAISHA_CD = M05.ITAKU_KAISHA_CD
		AND		M01.KOZA_TEN_CD = M05.BUTEN_CD
		AND		VMG1.ITAKU_KAISHA_CD = VJ1.KAIIN_ID
		AND		VMG1.ITAKU_KAISHA_CD = itakuKaishaCd 						-- 委託会社コード
		AND		VMG1.HAKKO_TSUKA_CD = C_DEFAULT_TSUKA_CD 					-- デフォルト通貨コード
		AND (coalesce(trim(both mgrCd)::text, '') = '' OR VMG1.MGR_CD = trim(both mgrCd))
		AND (coalesce(trim(both isinCd)::text, '') = '' OR VMG1.ISIN_CD = trim(both isinCd))
		ORDER BY
				MG4.ITAKU_KAISHA_CD,
				MG4.MGR_CD,
				MG4.TESU_SHURUI_CD,			-- 手数料種類コード
				MG4.CHOKYU_YMD;
--==============================================================================
--                  関数定義                                                    
--==============================================================================
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, C_PROCEDURE_ID||' START');
	-- デバッグ
	IF DEBUG = 1 THEN	
		CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'l_inItakuKaishaCd = ' || l_inItakuKaishaCd);
		CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'l_inUserId = ' || l_inUserId);	
		CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'l_inChohyoKbn = ' || l_inChohyoKbn);	
		CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'l_inChohyoId = ' || l_inChohyoId);	
		CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'l_inGyomuYmd = ' || l_inGyomuYmd);	
		CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'l_inMgrCd = ' || l_inMgrCd);	
		CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'l_inIsinCd = ' || l_inIsinCd);	
		CALL pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'l_inTsuchiYmd = ' || l_inTsuchiYmd);	
	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''							-- 委託会社コードがNULL
	OR coalesce(trim(both l_inUserId)::text, '') = ''									-- ユーザIDがNULL
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''								-- 帳票区分がNULL
	OR coalesce(trim(both l_inChohyoId)::text, '') = ''								-- 帳票IDがNULL
	OR coalesce(trim(both l_inGyomuYmd)::text, '') = ''								-- 帳票業務日付がNULL
	OR (coalesce(trim(both l_inMgrCd)::text, '') = '' AND coalesce(trim(both l_inIsinCd)::text, '') = '')	-- 銘柄コードがNULL、かつISINコードがNULL
	THEN
		-- パラメータエラー
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID,3,12), 'パラメータエラー');
		l_outSqlCode := pkconstant.FATAL();
		RETURN;
	END IF;
	-- カウンタ初期化
	gCnt := 0;
	-- 差込用帳票ワークの削除
	DELETE	FROM SREPORT_WK_SSKM
	WHERE	KEY_CD 		= l_inItakuKaishaCd
	AND		USER_ID 	= l_inUserId
	AND		CHOHYO_KBN 	= l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID 	= l_inChohyoId;
	-- 銘柄数分ループ
	FOR recTesuryo IN curTesuryo(l_inItakuKaishaCd, l_inMgrCd, l_inIsinCd)
	LOOP
		--　期中手数料計算
		gRtnCd := pkIpaKichuTesuryo.updateKichuTesuryoTbl(	recTesuryo.ITAKU_KAISHA_CD,			-- 委託会社コード
															recTesuryo.MGR_CD,					-- 銘柄コード
															recTesuryo.TESU_SHURUI_CD,			-- 手数料種類コード
															recTesuryo.CHOKYU_YMD,				-- 徴求日
															PKIPACALCTESURYO.C_DATA_KBN_YOTEI() 	-- 予定表出力
															);
		-- 期中手数料計算
		IF gRtnCd <> pkconstant.success() THEN
			l_OutSqlCode := gRtnCd;
			gSqlErrM := '手数料計算結果テーブル更新処理（期中管理手数料と期中信託報酬）が失敗しました。';
			CALL pkLog.error('ECM701', SUBSTR(C_PROCEDURE_ID,3,12), 'エラーメッセージ：'|| gSqlErrM);
			RETURN;
		END IF;
		gCnt := gCnt + 1;
	END LOOP;
	-- シーケンス初期化
	gSeqNo := 0;
	FOR recHoshoryo IN curHoshoryo(l_inItakuKaishaCd, l_inMgrCd, l_inIsinCd)
	LOOP
		-- 差込用帳票ワークへデータを追加
		CALL pkPrintSskm.insertData(
			l_inKeyCd			=>	l_inItakuKaishaCd 					-- 識別コード
			,l_inUserId			=>	l_inUserId 							-- ユーザID
			,l_inChohyoKbn		=>	l_inChohyoKbn 						-- 帳票区分
			,l_inSakuseiYmd		=>	l_inGyomuYmd 						-- 作成年月日
			,l_inChohyoId		=>	l_inChohyoId 						-- 帳票ＩＤ
			,l_inSeqNo 			=>	'0'									-- 連番
			,l_inSeqNo2 		=>	gSeqNo 								-- 連番2
			,l_inHeaderFlg		=>	'1'									-- ヘッダフラグ
			,l_inItem001		=>	recHoshoryo.MGR_CD 					-- ユーザID
			,l_inItem002		=>	recHoshoryo.ISIN_CD 					-- ISIN_CD
			,l_inItem003		=>	recHoshoryo.SFSK_BUSHO_NM 			-- 送付先担当部署名称
			,l_inItem004		=>	l_inTsuchiYmd 						-- 通知日
			,l_inItem005		=>	recHoshoryo.BUSHO_NM1				-- 担当部署名称
			,l_inItem006		=>	recHoshoryo.MGR_NM 					-- 銘柄正式名称
			,l_inItem007		=>	recHoshoryo.HAKKO_YMD 				-- 発行年月日
			,l_inItem008		=>	recHoshoryo.HKT_NM 					-- 発行体名称
			,l_inItem009		=>	recHoshoryo.BANK_NM 					-- 金融機関名称
			,l_inItem010		=>	recHoshoryo.FULLSHOKAN_KJT 			-- 満期償還期日
			,l_inItem011		=>	recHoshoryo.SHASAI_TOTAL 			-- 社債の総額
			,l_inItem012		=>	recHoshoryo.BNK_GUARANTEE_RATE 		-- 銀行保証料率
			,l_inItem013		=>	recHoshoryo.BUTEN_NM 				-- 保証料受入店
			,l_inItem014		=>	recHoshoryo.KOZA_TEN_CD 				-- 勘定店コード
			,l_inItem015		=>	recHoshoryo.CHOKYU_YMD 				-- 支払日
			,l_inItem016		=>	recHoshoryo.KIJUN_ZNDK 				-- 計算額面金額
			,l_inItem017		=>	recHoshoryo.CALC_F_YMD 				-- 計算期間FROM
			,l_inItem018		=>	recHoshoryo.CALC_T_YMD 				-- 計算期間TO
			,l_inItem019		=>	recHoshoryo.CALC_DD_BUNSHI 			-- 計算日数
			,l_inItem020		=>	recHoshoryo.HOSHORYO_KNGK 			-- 保証料金額
			,l_inItem021		=>	recHoshoryo.EIGYOTEN_CD 				-- 営業店コード
			,l_inItem022		=>	recHoshoryo.KOZA_TEN_NM 				-- 口座店名称
			,l_inKousinId		=>	l_inUserId 							-- 更新者ID
			,l_inSakuseiId		=>	l_inUserId 							-- 作成者ID
		);
		-- 連番2
		gSeqNo := gSeqNo + 1;
	END LOOP;
	-- 終了処理
	l_outSqlCode := pkconstant.success();
	gSqlErrM := NULL;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID,3,12), 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID,3,12), 'SQLERRM:'||SQLERRM);
		l_outSqlCode := pkconstant.FATAL();
		gSqlErrM := SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipx022k95102r01 ( l_inItakuKaishaCd SREPORT_WK_SSKM.KEY_CD%TYPE, l_inUserId SREPORT_WK_SSKM.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK_SSKM.CHOHYO_KBN%TYPE, l_inChohyoId SREPORT_WK_SSKM.CHOHYO_ID%TYPE, l_inGyomuYmd SREPORT_WK_SSKM.SAKUSEI_YMD%TYPE, l_inMgrCd text, l_inIsinCd text, l_inTsuchiYmd text, l_outSqlCode OUT integer  ) FROM PUBLIC;