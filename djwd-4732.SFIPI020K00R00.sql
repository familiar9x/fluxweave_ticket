




CREATE OR REPLACE FUNCTION sfipi020k00r00 () RETURNS integer AS $body$
DECLARE

ora2pg_rowcount int;
--*******************************************************************************
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 元利払日程予定データを作成する。
-- *
-- * @author JIP
-- * @version $Id: SFIPI020K00R00.sql,v 1.17 2008/10/04 07:03:04 fujimoto Exp $
-- *
-- * @param Nothing
-- * @return INTEGER
-- *               pkIpConstants.SUCCESS():正常終了
-- *               pkIpConstants.SYSERR() :システムエラー(SQLエラー、パラメータエラー)
-- *******************************************************************************
--==============================================================================
--					定数定義													
--==============================================================================
	TEIJI_SHOKAN	CONSTANT text		:= '2';				--定時償還(償還方法コード)
	TOKUREI_SHASAI	CONSTANT text		:= 'Y';        --特例社債(特例社債フラグ)
--******************************************************************************
-- 変数定義 																	
--******************************************************************************
	-- 業務日付 
	gyoumuHiduke char(8);
	-- インサート件数 
	insertKensuu integer := 0;
	-- 業務日付のN日後 
	gyoumuHidukeAfter char(8);
	-- システム_社債残高 
	systemShasaiZandaka GANRI_NITTEI.SYS_SHASAI_ZNDK%TYPE;
    -- 支払日前日 
    previousShrYmd GANRI_NITTEI.SYS_GNRBARAI_YMD%TYPE;
	-- ファンクション名 
	FUNC_NAME CONSTANT text := 'SfIpI020K00R00';
--******************************************************************************
-- カーソル定義 																
--******************************************************************************
-- 元利払日程予定データの作成対象とする銘柄の元利払データを抽出し、銘柄情報を取得する 
curGanriBaraiNitteiYoteiData CURSOR(
	l_inDate  GANRI_NITTEI.SYS_GNRBARAI_YMD%TYPE
) FOR
	SELECT
		VMG1.ITAKU_KAISHA_CD			ITAKU_KAISHA_CD,   		-- 委託会社コード
        VMG1.MGR_CD         			MGR_CD,   		        -- 銘柄コード
		VMG1.ISIN_CD					ISIN_CD,   				-- ISINコード
		VMG1.HAKKO_TSUKA_CD			    HAKKO_TSUKA_CD,   		-- 発行通貨
		MG2.RBR_YMD					    SHR_YMD,  				 -- システム実支払日
		VMG1.SHOKAN_METHOD_CD    SHOKAN_METHOD_CD,  -- 償還方法コード
		VMG1.TOKUREI_SHASAI_FLG   TOKUREI_SHASAI_FLG   --特例社債フラグ
	FROM
		MGR_RBRKIJ	MG2,
		MGR_KIHON_VIEW	VMG1
	WHERE
		VMG1.JTK_KBN IN ('1', '3', '4', '5', '6')		        -- 受託区分
		AND VMG1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD 	        -- 委託会社コード
		AND VMG1.MGR_CD = MG2.MGR_CD 						    -- 銘柄コード
		AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '') 					    -- ISINコードが付番されていないものは除く
		AND MG2.RBR_YMD = l_inDate 							    -- 利払日
		AND VMG1.KK_KANYO_FLG = '1'						        -- 機構関与方式採用フラグ
		AND VMG1.SAIKEN_SHURUI != '80'                          -- 振替ＣＢ以外
		AND VMG1.SAIKEN_SHURUI != '89'                          -- 振替ＣＢ以外
	
UNION

	SELECT DISTINCT
		VMG1.ITAKU_KAISHA_CD			ITAKU_KAISHA_CD,	    -- 委託会社コード
        VMG1.MGR_CD         			MGR_CD,   		        -- 銘柄コード
		VMG1.ISIN_CD					ISIN_CD,   			    -- ISINコード
		VMG1.HAKKO_TSUKA_CD			    HAKKO_TSUKA_CD, 	    -- 発行通貨
		MG3.SHOKAN_YMD				    SHR_YMD,  		  	    -- システム実支払日
		VMG1.SHOKAN_METHOD_CD    SHOKAN_METHOD_CD,  -- 償還方法コード
		VMG1.TOKUREI_SHASAI_FLG   TOKUREI_SHASAI_FLG   --特例社債フラグ
	FROM
		MGR_SHOKIJ	MG3,
		MGR_KIHON_VIEW	VMG1
	WHERE
		VMG1.JTK_KBN IN ('1', '3', '4', '5', '6')		        -- 受託区分
		AND VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD 	        -- 委託会社コード
		AND VMG1.MGR_CD = MG3.MGR_CD 					    	-- 銘柄コード
		AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '') 					    -- ISINコードが付番されていないものは除く
		AND MG3.SHOKAN_YMD = l_inDate 				        	-- 利払日
		AND VMG1.KK_KANYO_FLG = '1'						        -- 機構関与方式採用フラグ
		AND MG3.SHOKAN_KBN IN ('10','20','21','40','41','50')	-- 償還区分
		AND VMG1.SAIKEN_SHURUI != '80'                          -- 振替ＣＢ以外
		AND VMG1.SAIKEN_SHURUI != '89'                          -- 振替ＣＢ以外
 
	ORDER BY
		SHR_YMD,					                        	-- システム実支払日
		ITAKU_KAISHA_CD,			                        	-- 委託会社コード
		ISIN_CD;				                            	-- ISINコード
--******************************************************************************
--                  メイン処理                                                  
--******************************************************************************
BEGIN
	CALL pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME, '************* メイン処理開始 '||statement_timestamp()||' ************');
	-- 元利払日程予定データを全件削除する。
	DELETE FROM GANRI_NITTEI;
	--
--	 * システム管理情報マスタから、業務日付を取得する。
--	 * （夜間バッチ処理後、次の営業日の日付）
--	gyoumuHiduke := pkDate.getYokuBusinessYmd(pkDate.getGyomuYmd(), 1); 
	gyoumuHiduke := pkDate.getYokuBusinessYmd(pkDate.getGyomuYmd());
	-- debug
	CALL pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME, '業務日付 : '||gyoumuHiduke);
	--
--	 * 取得したワークレコードを配列に格納すると共に、
--	 * システム_社債残高を格納する
--	 
	FOR nissuu IN 2..5 LOOP
		-- 業務日付N日後取得 
		gyoumuHidukeAfter := pkDate.getPlusDateBusiness(gyoumuHiduke, nissuu, pkconstant.TOKYO_AREA_CD());
		-- debug
		CALL pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME, '業務日付 '||nissuu||' 日後 : '||gyoumuHidukeAfter);
		FOR recGanriBaraiNitteiYoteiData IN curGanriBaraiNitteiYoteiData(gyoumuHidukeAfter) LOOP
            -- 支払日前日の初期化 
            previousShrYmd := NULL;
            -- 支払日前日の取得 
            previousShrYmd := pkDate.getZenYmd(recGanriBaraiNitteiYoteiData.SHR_YMD);
			-- 残高取得共通ＳＰシステム_社債残高を取得
--             * 引数:1=基準日時点の社債残高（名目残高）
--             * 基準日=支払日前日
--             
            IF  recGanriBaraiNitteiYoteiData.TOKUREI_SHASAI_FLG = TOKUREI_SHASAI  AND recGanriBaraiNitteiYoteiData.SHOKAN_METHOD_CD <> TEIJI_SHOKAN THEN
            	-- 特例債で定時償還でない銘柄は実質残高を取得
            	systemShasaiZandaka := pkIpaZndk.getKjnZndk(recGanriBaraiNitteiYoteiData.ITAKU_KAISHA_CD,
                                                        recGanriBaraiNitteiYoteiData.MGR_CD,
                                                        previousShrYmd,
                                                        3
                                                        );
           ELSE
           		-- 上の条件以外は名目残高を取得
            	systemShasaiZandaka := pkIpaZndk.getKjnZndk(recGanriBaraiNitteiYoteiData.ITAKU_KAISHA_CD,
                                                        recGanriBaraiNitteiYoteiData.MGR_CD,
                                                        previousShrYmd,
                                                        1
                                                        );
		   END IF;
			-- debug
			CALL pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME, '-----------------------------------');
			CALL pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME, '委託会社コード : '||recGanriBaraiNitteiYoteiData.ITAKU_KAISHA_CD);
			CALL pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME, 'ISINコード : '||recGanriBaraiNitteiYoteiData.ISIN_CD);
			CALL pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME, 'N営業日前通知 : '||nissuu);
			CALL pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME, '元利払日 : '||recGanriBaraiNitteiYoteiData.SHR_YMD);
			CALL pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME, '社債残高 : '||systemShasaiZandaka);
			CALL pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME, '発行通貨 : '||recGanriBaraiNitteiYoteiData.HAKKO_TSUKA_CD);
			--
--			 *  システム_社債残高が０でなければ元利払日程予定データにデータを登録する
--			 *
--			 * 【登録項目】
--			 * 		<項目>							<内容>
--			 * 		委託会社コード					銘柄_基本.委託会社コード
--			 * 		ＩＳＩＮコード					銘柄_基本.ISINコード
--			 * 		Ｎ営業日前通知					日数
--			 * 		システム_元利払日				銘柄_利払回次.利払日または償還回次.償還年月日
--			 * 		システム_社債残高				実質残高View.基準残高（ファクター計算時に使用の残高）
--			 * 		システム_発行通貨				銘柄_基本.発行通貨
--			 * 		機構_作成日						' '
--			 * 		機構_振替停止日					' '
--			 * 		機構_元利払日					' '
--			 * 		機構_残高通知配信期間(FROM)		' '
--			 * 		機構_残高通知配信期間(TO)		' '
--			 * 		機構_社債残高					' '
--			 * 		機構_発行通貨					' '
--			 * 		突合結果区分					'0'をセット
--			 * 		受信日時						' '
--			 * 		更新日時						' '
--			 * ---------------------------------------------------------------
--			 * 夜間バッチのため不要
--			 * 		グループID
--			 * 		処理区分
--			 * 		最終訂正日時
--			 * 		最終訂正者
--			 * 		承認日時
--			 * 		承認者
--			 * ---------------------------------------------------------------
--			 * 		更新日時						CURRENT_TIMESTAMPをセット
--			 * 		更新者							'BATCH'をセット
--			 * 		作成日時						CURRENT_TIMESTAMPをセット
--			 * 		作成者							'BATCH'をセット
--			 
       IF systemShasaiZandaka > 0 THEN
    			INSERT INTO GANRI_NITTEI(
    				ITAKU_KAISHA_CD,			-- 委託会社コード
    				ISIN_CD,					-- ＩＳＩＮコード
    				NBEF_EIGYOBI_TSUCHI,		-- Ｎ営業日前通知
    				SYS_GNRBARAI_YMD,			-- システム_元利払日
    				SYS_SHASAI_ZNDK,			-- システム_社債残高
    				SYS_HAKKO_TSUKA_CD,			-- システム_発行通貨
    				KK_SAKUSEI_YMD,				-- 機構_作成日
    				KK_FURIKAE_TEISHI_YMD,		-- 機構_振替停止日
    				KK_GNRBARAI_YMD,			-- 機構_元利払日
    				KK_ZNDK_TSUCHI_F_YMD,		-- 機構_残高通知配信期間(FROM)
    				KK_ZNDK_TSUCHI_T_YMD,		-- 機構_残高通知配信期間(TO)
    				KK_SHASAI_ZNDK,				-- 機構_社債残高
    				KK_HAKKO_TSUKA_CD,			-- 機構_発行通貨
    				TOTSUGO_KEKKA_KBN,			-- 突合結果区分
    				RECEP_DT,					-- 受信日時
    				KOUSIN_DT,					-- 更新日時
    				KOUSIN_ID,					-- 更新者
    				SAKUSEI_ID 					-- 作成者
    			) VALUES (
    				recGanriBaraiNitteiYoteiData.ITAKU_KAISHA_CD,	-- 委託会社コード
    				recGanriBaraiNitteiYoteiData.ISIN_CD,			-- ＩＳＩＮコード
    				nissuu,												-- Ｎ営業日前通知
    				recGanriBaraiNitteiYoteiData.SHR_YMD,			-- システム_元利払日
    				systemShasaiZandaka,								-- システム_社債残高
    				recGanriBaraiNitteiYoteiData.HAKKO_TSUKA_CD,	-- システム_発行通貨
    				' ',												-- 機構_作成日
    				' ',												-- 機構_振替停止日
    				' ',												-- 機構_元利払日
    				' ',												-- 機構_残高通知配信期間(FROM)
    				' ',												-- 機構_残高通知配信期間(TO)
    				0,													-- 機構_社債残高
    				' ',												-- 機構_発行通貨
    				'0',												-- 突合結果区分
    				' ',												-- 受信日時
    				CURRENT_TIMESTAMP,									-- 更新日時
    				pkconstant.BATCH_USER(),								-- 更新者
    				pkconstant.BATCH_USER() 								-- 作成者
    			);
      END IF;
			GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;

			CALL pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME, '元利払日程予定データに登録 ROWCOUNT='|| ora2pg_rowcount);
			GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;

			insertKensuu := insertKensuu +  ora2pg_rowcount;
		END LOOP;
	END LOOP;
	-- debug
	CALL pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME, '総登録件数 : '||insertKensuu);
	CALL pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME, '************* メイン処理正常終了 '||statement_timestamp()||' ************');
	--
--	 * 処理正常終了
--	 
	RETURN pkconstant.success();
--******************************************************************************
--                  エラー処理                                                  
--******************************************************************************
EXCEPTION
	-- その他例外発生 
	WHEN OTHERS THEN
		CALL pkLog.debug(pkconstant.BATCH_USER(), FUNC_NAME, '***** その他例外発生 *****');
		CALL pkLog.fatal('ECM701', FUNC_NAME, '元利払日程予定データ作成エラー '||SQLSTATE||SUBSTR(SQLERRM,1,100));
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi020k00r00 () FROM PUBLIC;