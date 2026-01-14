CREATE OR REPLACE FUNCTION sfadw013s5111common (
	l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE,
	l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE,
	l_inKkStat MGR_STS.KK_STAT%TYPE
) RETURNS integer AS $body$
DECLARE

--
-- * 著作権: Copyright (c) 2008
-- * 会社名: JIP
-- *
-- * 銘柄情報登録データ 送信/取消処理（ステータス更新）
-- * 銘柄ステータステーブル/銘柄機構基本テーブル/CB銘柄機構基本テーブルを更新します。
-- *
-- * @author  中村(JSFIT)
-- * @version $Id: SFADW013S5111COMMON.sql 7920 2017-03-16 02:52:41Z j8800053 $
-- * @param  	l_inKkSakuseiDt 	IN 	KK_RENKEI.KK_SAKUSEI_DT%TYPE	機構連携作成日時
-- * @param  	l_inDenbunMeisaiNo 	IN 	KK_RENKEI.DENBUN_MEISAI_NO%TYPE	電文明細Ｎｏ
-- * @return 	リターンコード		INTEGER
-- *   		 pkconstant.success()				: 正常
-- *   		 pkconstant.NO_DATA_FIND()	 	: 突合相手なし
-- *   		 pkconstant.RECONCILE_ERROR()		: 突合エラー
-- *           pkconstant.FATAL() 			 	: 致命的エラー
-- 
--====================================================================
--					デバッグ機能										  
--====================================================================
	DEBUG	numeric(1)	:= 1;
--====================================================================*
--                  変数定義
-- *====================================================================
 	result		integer;				-- 本ＳＰのリターンコード
	gMgrCd			MGR_KIHON.MGR_CD%TYPE;      				-- 銘柄コード
	gItakuKaishaCd 	MGR_KIHON.ITAKU_KAISHA_CD%TYPE;	            -- 委託会社コード
	gHakkoYmd			MGR_KIHON.HAKKO_YMD%TYPE;	            -- 発行年月日
	gJipDenbunCd 	KK_RENKEI.JIP_DENBUN_CD%TYPE;  	            -- JIP電文コード
	gChkKkPhase     MGR_KIHON_VIEW.KK_PHASE%TYPE := 'M1';       -- 機構フェーズ（チェック用）
	gPutShokanKjt		UPD_MGR_SHN.SHR_KJT%TYPE;	            -- プットオプション繰上償還期日
	gPutShokanPremium	UPD_MGR_SHN.SHOKAN_PREMIUM%TYPE;	    -- プットオプション償還プレミアム
	gPutStkoshikikanYmd	UPD_MGR_SHN.ST_PUTKOSHIKIKAN_YMD%TYPE;	-- プットオプション行使期間開始日
	gPutEdkoshikikanYmd	UPD_MGR_SHN.ED_PUTKOSHIKIKAN_YMD%TYPE;	-- プットオプション行使期間終了日
	gPutKkStat			UPD_MGR_SHN.KK_STAT%TYPE;	            -- プットオプション機構ステータス
	gSql            varchar(2500);
	cSql            integer;
	cFlg			char(1);									-- カンマフラグ
	sqlCount        numeric;
	gKKStat			MGR_STS.KK_STAT%TYPE;						-- 機構ステータス
	gPutFlg			char(1);									-- 銘柄情報通知（ＣＢ）改善オプションフラグ
	gPutUpdFlg		char(1);									-- 期中銘柄変更（償還）更新フラグ
--====================================================================*
--					定数定義
-- *====================================================================
	-- 本SPのID
	SP_ID				CONSTANT varchar(20) := 'SFADW013S5111COMMON';
	-- ユーザID
	USER_ID				CONSTANT varchar(10) := pkconstant.BATCH_USER();
	-- 帳票ID
	REPORT_ID			CONSTANT varchar(10) := '';
	-- 銘柄情報通知（ＣＢ）改善オプションコード
	PUTOPTION_CD		CONSTANT varchar(15)   := 'CBMGR_TSUCHI';
--******************************************************************************
-- カーソル定義																 
--******************************************************************************
-- 機構連携データ取得 
-- 引数の機構連携作成日時，電文明細Ｎｏよりデータ取得 
-- 電文コードが"変更"の場合、変更のあった項目のみ更新したい為 
-- 一旦カーソルで対象データを取得する                         

	tempResult record;
--====================================================================*
--   メイン
-- *====================================================================
BEGIN
	result := pkconstant.FATAL();
	gPutUpdFlg := '0';
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' START');	END IF;
    	-- 入力パラメータのチェック
		IF coalesce(trim(both l_inKkSakuseiDt::text), '') = ''
		  OR coalesce(trim(both l_inDenbunMeisaiNo::text), '') = ''
	      OR coalesce(trim(both l_inKkStat::text), '') = '' THEN
		-- パラメータエラー
		CALL pkLog.error('ECM501', SP_ID, ' ');
		RETURN result;
	END IF;
   	-- 機構連携テーブル、委託会社マスタより 委託会社コードを取得する 
   	SELECT		JM01.KAIIN_ID,
        		RT02.JIP_DENBUN_CD,
        		trim(both RT02.HYOJI_KOMOKU1),
        		trim(both RT02.HYOJI_KOMOKU4)
    	INTO STRICT	gItakuKaishaCd,
        		gJipDenbunCd,
    			gMgrCd,
    			gHakkoYmd
    	FROM	KK_RENKEI RT02,
        		VJIKO_ITAKU JM01
    	WHERE	RT02.KK_SAKUSEI_DT = l_inKkSakuseiDt
    	  AND	RT02.DENBUN_MEISAI_NO = l_inDenbunMeisaiNo
    	  AND	pkIpaName.getBicNoShitenCd(RT02.SR_BIC_CD) = pkIpaName.getBicNoShitenCd(JM01.BIC_CD);
	-- 業務日付≦発行年月日のとき 
   	IF pkDate.getGyomuYmd() <= gHakkoYmd THEN
   		-- 銘柄情報通知（ＣＢ）改善オプションフラグ取得 
		gPutFlg := pkControl.getOPTION_FLG(gItakuKaishaCd, PUTOPTION_CD, '0');
		-- 銘柄情報通知（ＣＢ）改善オプションフラグ ＝ "1" のとき 
		IF gPutFlg = '1' THEN
			-- プットオプション行使条件取得 
			tempResult := sfIpGetPutOption(gItakuKaishaCd, gMgrCd, gPutShokanKjt, gPutShokanPremium,
										gPutStkoshikikanYmd, gPutEdkoshikikanYmd, gPutKkStat);
			result := tempResult.extra_param;
			-- 機構ステータス(プットオプション) ≠ "04" のとき 
			IF gPutKkStat <> '04' THEN
				gPutUpdFlg := '1';
			END IF;
		END IF;
	END IF;
    -- 通常の送信処理のとき 
    IF l_inKkStat = pkKkNotice.MGR_KKSTAT_FIN() THEN
        -- 電文コードが"新規"OR"変更"の場合のみ銘柄ステータステーブル更新 
		IF gJipDenbunCd = 'S5111' OR gJipDenbunCd = 'S5112' THEN
	        CALL pkLog.DEBUG(USER_ID,SP_ID,'送信処理を行います。');
	        CALL pkLog.DEBUG(USER_ID,SP_ID,'銘柄_ステータスの機構フェーズ、機構ステータスを更新します。');
	        --
--	         * 機構フェーズ='M1'、機構ステータス='02'なら更新OK
--	         
	        -- 銘柄_ステータス更新 
			UPDATE MGR_STS
				SET
 					KK_STAT = l_inKkStat,
					SHONIN_KAIJO_YOKUSEI_FLG = '0'
				WHERE
				    ITAKU_KAISHA_CD = gItakuKaishaCd
				AND MGR_CD = gMgrCd
				AND SHORI_KBN = '1'
				AND KK_PHASE = gChkKkPhase
				AND KK_STAT = pkKkNotice.MGR_KKSTAT_SHONIN();
			GET DIAGNOSTICS sqlCount = ROW_COUNT;
		    -- 更新件数チェック 
		    IF sqlCount = 0 THEN
		    	CALL pkLog.error('ECM3A3', SP_ID, '銘柄ステータス管理');
		        -- 突合相手なし'40'を返す。 
	        	RETURN pkconstant.NO_DATA_FIND();
		    END IF;
		    -- 期中銘柄変更（償還）更新フラグ="1"の場合 
		    IF gPutUpdFlg = '1' THEN
		    	-- 期中銘柄変更（償還）更新 
		    	UPDATE UPD_MGR_SHN
				SET
 					KK_STAT = l_inKkStat,
					SHONIN_KAIJO_YOKUSEI_FLG = '0'
				WHERE
				    ITAKU_KAISHA_CD = gItakuKaishaCd
				AND MGR_CD = gMgrCd
				AND MGR_HENKO_KBN = '50'
				AND SHORI_KBN = '1'
				AND KK_STAT = pkKkNotice.MGR_KKSTAT_SHONIN();
				-- 期中銘柄変更（償還）（CB）ワーク削除 
	        	DELETE FROM UPD_MGR_SHN_CB_WK WKMG23
	         	WHERE
	        		WKMG23.ITAKU_KAISHA_CD = gItakuKaishaCd
	           	AND WKMG23.MGR_CD = gMgrCd;
	        	-- プットオプション繰上償還期日　≠　" "　の場合 
	           	IF gPutShokanKjt <> ' ' THEN
					-- 期中銘柄変更（償還）（CB）ワーク登録 
					INSERT INTO UPD_MGR_SHN_CB_WK (ITAKU_KAISHA_CD,
					 MGR_CD,
					 SHR_KJT,
					 SHOKAN_PREMIUM,
					 ST_PUTKOSHIKIKAN_YMD,
					 ED_PUTKOSHIKIKAN_YMD,
					 KOUSIN_ID,
					 SAKUSEI_ID)
					VALUES (
					 gItakuKaishaCd,			-- 委託会社コード
					 gMgrCd,					-- 銘柄コード
					 gPutShokanKjt,				-- 支払期日
					 gPutShokanPremium,			-- 償還プレミアム
					 gPutStkoshikikanYmd,		-- 行使期間開始日
					 gPutEdkoshikikanYmd,		-- 行使期間終了日				
				 	 USER_ID,					-- 更新者
				 	 USER_ID);					-- 作成者
				 END IF;
			END IF;
	    END IF;
	    -- 電文コードが"新規"の場合(銘柄機構基本テーブルInsert) 
	    IF gJipDenbunCd = 'S5111' THEN
        	gSql := '';		-- 初期化 
			cFlg := '';		-- 初期化 
	    	-- 銘柄機構基本・CB銘柄機構基本INSERT処理呼出 
	    	result := SFADW013S5111COMMON_insertMeigara(gItakuKaishaCd,
																										gMgrCd,
																										l_inKkSakuseiDt,
																										l_inDenbunMeisaiNo,
																										USER_ID);
	    	IF result = pkconstant.FATAL() THEN
	    		CALL pkLog.error('ECM3A3', SP_ID, '銘柄機構連携');
	    		RETURN result;
			END IF;
	    -- 電文コードが"変更"の場合(銘柄機構基本テーブル更新) 
	    ELSIF gJipDenbunCd = 'S5112' THEN
	    	-- 銘柄機構基本・CB銘柄機構基本更新処理呼出 
	    	tempResult := SFADW013S5111COMMON_updateMeigara(gItakuKaishaCd,
																										gMgrCd,
																										l_inKkSakuseiDt,
																										l_inDenbunMeisaiNo,
																										USER_ID,
																										sqlCount,
																										gSql,
																										cFlg);
				result := tempResult.rtn;
	    	IF result = pkconstant.NO_DATA_FIND() THEN
	    		CALL pkLog.error('ECM3A3', SP_ID, '銘柄ステータス管理');
	    		RETURN result;
	    	ELSIF result = pkconstant.error() THEN
	    		CALL pkLog.error('ECM3A3', SP_ID, '機構連携');
	    		RETURN pkconstant.NO_DATA_FIND();
			END IF;
        END IF;
        result := pkconstant.success();
    -- 送信取消処理のとき 
    ELSE
        -- 機構ステータス取得 
        SELECT KK_STAT
          INTO STRICT gKKStat
          FROM MGR_STS MG0
         WHERE MG0.ITAKU_KAISHA_CD = gItakuKaishaCd
           AND MG0.MGR_CD = gMgrCd;
        -- 機構ステータスが"承認済の場合のみ銘柄ステータステーブルを更新 
        IF gKKStat = '02' THEN
	        CALL pkLog.DEBUG(USER_ID,SP_ID,'送信取消処理を行います。');
	        CALL pkLog.DEBUG(USER_ID,SP_ID,'銘柄_ステータスの承認解除抑制フラグを更新します。');
	        -- 承認解除抑制フラグを承認解除可能にする。 
	        -- 送信待ち（未送信）か送信済み（通知待ち）なら更新可能 
	        UPDATE
	            MGR_STS
	        SET
							MGR_SEND_TAISHO_FLG = '1',
	            SHONIN_KAIJO_YOKUSEI_FLG = '0'
	        WHERE
	            ITAKU_KAISHA_CD = gItakuKaishaCd
	        AND MGR_CD = gMgrCd
	        AND SHORI_KBN = '1'
	        AND KK_PHASE = gChkKkPhase
	        AND KK_STAT IN (pkKkNotice.MGR_KKSTAT_SHONIN(), pkKkNotice.MGR_KKSTAT_SEND());
	        GET DIAGNOSTICS sqlCount = ROW_COUNT;
		    -- 更新件数チェック 
		    IF sqlCount = 0 THEN
		    	CALL pkLog.error('ECM3A3', SP_ID, '銘柄ステータス管理');
		        -- 突合相手なし'40'を返す。 
	        	RETURN pkconstant.NO_DATA_FIND();
		    END IF;
		END IF;
		-- 期中銘柄変更（償還）更新フラグ="1"の場合 
		IF gPutUpdFlg = '1' THEN		
        	-- 機構ステータス(プット)が"承認済"の場合のみ期中銘柄変更（償還）を更新 
        	IF gPutKKStat = '02' THEN	
	        	-- 承認解除抑制フラグを承認解除可能にする。 
	        	UPDATE
	            	UPD_MGR_SHN
	        	SET
								SHONIN_KAIJO_YOKUSEI_FLG = '0'
	        	WHERE
	            	ITAKU_KAISHA_CD = gItakuKaishaCd
		        AND MGR_CD = gMgrCd
		        AND SHORI_KBN = '1'
	    	    AND MGR_HENKO_KBN = '50'
	        	AND KK_STAT IN (pkKkNotice.MGR_KKSTAT_SHONIN(), pkKkNotice.MGR_KKSTAT_SEND());
	        END IF;
		END IF;		
        result := pkconstant.success();
    END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, 'ステータス更新SP  result = ' || result);	END IF;
	RETURN result;
--====================================================================*
--    異常終了 出口
-- *====================================================================
EXCEPTION
	-- その他・例外エラー 
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
        -- 例外発生時にカーソルがオープンしたままならクローズする。 
        IF cSql IS NOT NULL AND DBMS_SQL.IS_OPEN(cSql) THEN
        	CALL DBMS_SQL.CLOSE_CURSOR(cSql);
        END IF;
		RETURN result;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadw013s5111common ( l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE, l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE, l_inKkStat MGR_STS.KK_STAT%TYPE ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadw013s5111common_insertmeigara (
	gItakuKaishaCd MGR_KIHON.ITAKU_KAISHA_CD%TYPE,
	gMgrCd MGR_KIHON.MGR_CD%TYPE,
	l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE,
	l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE,
	USER_ID varchar(10)
) RETURNS integer AS $body$
DECLARE

	l_optionFlg		MOPTION_KANRI.OPTION_FLG%TYPE;	-- オプションフラグ
	l_sakuseiDt		MGR_KIKO_KIHON.SAKUSEI_DT%TYPE;	-- 作成日時
	rtn				integer;

	curKK_renkei CURSOR FOR
	SELECT *
	  FROM KK_RENKEI RT02
	 WHERE RT02.KK_SAKUSEI_DT    = l_inKkSakuseiDt
	   AND RT02.DENBUN_MEISAI_NO = l_inDenbunMeisaiNo;

	-- 銘柄_基本累積（ＣＢ）用データ取得カーソル 
	curCB_ruiseki CURSOR FOR
	SELECT MG1.MGR_CD,
	       WMG1.TEKIYOST_YMD,
	       WMG1.SHNK_HNK_TRKSH_KBN,
	       MG1.ISIN_CD,
	       MG1.HAKKODAIRI_CD,
	       MG1.SHRDAIRI_CD,
	       MG1.SKN_KESSAI_CD,
	       MG1.MGR_NM,
	       MG1.KK_HAKKOSHA_RNM,
	       MG1.KAIGO_ETC,
	       MG1.BOSHU_KBN,
	       MG1.SAIKEN_SHURUI,
	       MG1.HOSHO_KBN,
	       MG1.TANPO_KBN,
	       MG1.GODOHAKKO_FLG,
	       MG1.RETSUTOKU_UMU_FLG,
	       MG1.SKNNZISNTOKU_UMU_FLG,
	       MG1.BOSHU_ST_YMD,
	       MG1.HAKKO_YMD,
	       MG1.UCHIKIRI_HAKKO_FLG,
	       MG1.HAKKO_TSUKA_CD,
	       MG1.KAKUSHASAI_KNGK,
	       MG1.SHASAI_TOTAL,
	       MG1.FULLSHOKAN_KJT,
	       MG1.CALLALL_UMU_FLG,
	       MG1.PUTUMU_FLG,
	       MG1.PARTHAKKO_UMU_FLG,
	       MG1.KYUJITSU_KBN,
	       MG1.RITSUKE_WARIBIKI_KBN,
	       MG1.NENRBR_CNT,
	       MG1.TOTAL_RBR_CNT,
	       MG1.RBR_DD,
	       MG1.ST_RBR_KJT,
	       CASE WHEN MG1.TOKUREI_SHASAI_FLG='Y' THEN coalesce(trim(both MG1.YOBI3), ' ')  ELSE ' ' END  AS KK_ST_RBR_KJT,
	       MG1.LAST_RBR_FLG,
	       MG1.RIRITSU,
	       MG1.TSUKARISHI_KNGK_FAST,
	       MG1.TSUKARISHI_KNGK_NORM,
	       MG1.TSUKARISHI_KNGK_LAST,
	       MG1.TSUKARISHI_KNGK_FAST_S,
	       MG1.TSUKARISHI_KNGK_NORM_S,
	       MG1.TSUKARISHI_KNGK_LAST_S,
	       MG1.RBR_KJT_MD1,
	       MG1.RBR_KJT_MD2,
	       MG1.RBR_KJT_MD3,
	       MG1.RBR_KJT_MD4,
	       MG1.RBR_KJT_MD5,
	       MG1.RBR_KJT_MD6,
	       MG1.RBR_KJT_MD7,
	       MG1.RBR_KJT_MD8,
	       MG1.RBR_KJT_MD9,
	       MG1.RBR_KJT_MD10,
	       MG1.RBR_KJT_MD11,
	       MG1.RBR_KJT_MD12,
	       MG1.KK_KANYO_FLG,
	       MG1.KOBETSU_SHONIN_SAIYO_FLG,
	       WMG1.SHANAI_KOMOKU1,
	       WMG1.SHANAI_KOMOKU2,
	       MG1.TOKUREI_SHASAI_FLG,
	       WMG1.KK_MGR_CD,
	       WMG1.JOJO_KBN_TO,
	       WMG1.JOJO_KBN_DA,
	       WMG1.JOJO_KBN_ME,
	       WMG1.JOJO_KBN_FU,
	       WMG1.JOJO_KBN_SA,
	       WMG1.JOJO_KBN_JA,
	       WMG1.SHOKAN_PREMIUM,
	       WMG1.WRNT_TOTAL,
	       WMG1.WRNT_USE_KAGAKU_KETTEI_YMD,
	       WMG1.WRNT_USE_ST_YMD,
	       WMG1.WRNT_USE_ED_YMD,
	       WMG1.WRNT_HAKKO_KAGAKU,
	       WMG1.WRNT_USE_KAGAKU,
	       WMG1.USE_SEIKYU_UKE_BASHO,
	       WMG1.WRNT_BIKO,
	       WMG1.SHTK_JK_UMU_FLG,
	       WMG1.SHTK_JK_YMD,
	       WMG1.SHTK_TAIKA_SHURUI,
	       WMG1.HASU_SHOKAN_UMU_FLG,
	       coalesce((SELECT MG6.FINANCIAL_SECURITIES_KBN || MG6.BANK_CD
	          FROM MGR_JUTAKUGINKO MG6
	         WHERE MG6.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
	           AND MG6.MGR_CD = MG1.MGR_CD
	           AND MG6.INPUT_NUM = '1'),' ') AS SHASAI_KANRI_CD1,
	       coalesce((SELECT MG6.FINANCIAL_SECURITIES_KBN || MG6.BANK_CD
	          FROM MGR_JUTAKUGINKO MG6 
	         WHERE MG6.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
	           AND MG6.MGR_CD = MG1.MGR_CD
	           AND MG6.INPUT_NUM = '2'),' ') AS SHASAI_KANRI_CD2,
	       coalesce((SELECT MG6.FINANCIAL_SECURITIES_KBN || MG6.BANK_CD
	          FROM MGR_JUTAKUGINKO MG6 
	         WHERE MG6.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
	           AND MG6.MGR_CD = MG1.MGR_CD
	           AND MG6.INPUT_NUM = '3'),' ') AS SHASAI_KANRI_CD3,
	       coalesce((SELECT MG6.FINANCIAL_SECURITIES_KBN || MG6.BANK_CD
	          FROM MGR_JUTAKUGINKO MG6 
	         WHERE MG6.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
	           AND MG6.MGR_CD = MG1.MGR_CD
	           AND MG6.INPUT_NUM = '4'),' ') AS SHASAI_KANRI_CD4,
	       coalesce((SELECT MG6.FINANCIAL_SECURITIES_KBN || MG6.BANK_CD
	          FROM MGR_JUTAKUGINKO MG6 
	         WHERE MG6.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
	           AND MG6.MGR_CD = MG1.MGR_CD
	           AND MG6.INPUT_NUM = '5'),' ') AS SHASAI_KANRI_CD5,
	       coalesce((SELECT MG6.FINANCIAL_SECURITIES_KBN || MG6.BANK_CD
	          FROM MGR_JUTAKUGINKO MG6 
	         WHERE MG6.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
	           AND MG6.MGR_CD = MG1.MGR_CD
	           AND MG6.INPUT_NUM = '6'),' ') AS SHASAI_KANRI_CD6,
	       coalesce((SELECT MG6.FINANCIAL_SECURITIES_KBN || MG6.BANK_CD
	          FROM MGR_JUTAKUGINKO MG6 
	         WHERE MG6.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
	           AND MG6.MGR_CD = MG1.MGR_CD
	           AND MG6.INPUT_NUM = '7'),' ') AS SHASAI_KANRI_CD7,
	       coalesce((SELECT MG6.FINANCIAL_SECURITIES_KBN || MG6.BANK_CD
	          FROM MGR_JUTAKUGINKO MG6 
	         WHERE MG6.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
	           AND MG6.MGR_CD = MG1.MGR_CD
	           AND MG6.INPUT_NUM = '8'),' ') AS SHASAI_KANRI_CD8,
	       coalesce((SELECT MG6.FINANCIAL_SECURITIES_KBN || MG6.BANK_CD
	          FROM MGR_JUTAKUGINKO MG6 
	         WHERE MG6.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
	           AND MG6.MGR_CD = MG1.MGR_CD
	           AND MG6.INPUT_NUM = '9'),' ') AS SHASAI_KANRI_CD9,
	       coalesce((SELECT MG6.FINANCIAL_SECURITIES_KBN || MG6.BANK_CD
	          FROM MGR_JUTAKUGINKO MG6 
	         WHERE MG6.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
	           AND MG6.MGR_CD = MG1.MGR_CD
	           AND MG6.INPUT_NUM = '10'),' ') AS SHASAI_KANRI_CD10,
	       CASE WHEN coalesce(MG8.GNKN_SHR_TESU_BUNBO, 0)=0 THEN  0  ELSE TRUNC((MG8.GNKN_SHR_TESU_BUNSHI/MG8.GNKN_SHR_TESU_BUNBO * 10000)::numeric, 14) END  AS KIKO_GANKIN_TESU_RITSU,
	       CASE WHEN coalesce(MG8.RKN_SHR_TESU_BUNBO, 0)=0 THEN  0  ELSE TRUNC((MG8.RKN_SHR_TESU_BUNSHI/MG8.RKN_SHR_TESU_BUNBO * 10000)::numeric, 14) END  AS KIKO_RIKIN_TESU_RITSU,
	       coalesce(CASE MG1.RITSUKE_WARIBIKI_KBN
	       WHEN 'Z' THEN
	            '3'
	       WHEN 'V' THEN
	            CASE MG7_1.TESU_SHURUI_CD
	            WHEN '61' THEN
	                 '1'
	            WHEN '82' THEN
	                 '2'
	            END
	       WHEN 'F' THEN
	            CASE MG7_1.TESU_SHURUI_CD
	            WHEN '61' THEN
	                 '1'
	            WHEN '82' THEN
	                 '2'
	            END
	       END,' ')  AS RKN_TESU_RITSU_KIJUN
	  FROM cb_mgr_kihon wmg1, (SELECT * FROM MGR_TESURYO_CTL MG7 
	      			WHERE MG7.ITAKU_KAISHA_CD = gItakuKaishaCd
	      			  AND MG7.MGR_CD = gMgrCd
	      			  AND MG7.TESU_SHURUI_CD IN ('61', '82')
	      			  AND MG7.CHOOSE_FLG = '1' )mg7_1, mgr_kihon mg1
		LEFT OUTER JOIN mgr_tesuryo_prm mg8 ON (MG1.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD AND MG1.MGR_CD = MG8.MGR_CD)
		LEFT OUTER JOIN mg7_1 ON (MG1.ITAKU_KAISHA_CD = MG7_1.ITAKU_KAISHA_CD AND MG1.MGR_CD = MG7_1.MGR_CD)
		WHERE MG1.ITAKU_KAISHA_CD = gItakuKaishaCd AND MG1.MGR_CD = gMgrCd AND MG1.ITAKU_KAISHA_CD = WMG1.ITAKU_KAISHA_CD AND MG1.MGR_CD = WMG1.MGR_CD;

BEGIN
	rtn := pkconstant.FATAL();
	l_optionFlg := pkControl.getOPTION_FLG(gItakuKaishaCd, 'REDPROJECT', '0');
	l_sakuseiDt := NULL;
	FOR recCurKK_renkei IN curKK_renkei LOOP
		-- [REDPROJECT]作成日を引き継ぐ
		IF l_optionFlg = '1' THEN
			BEGIN
				-- 更新前レコードの作成日を取得
				SELECT SAKUSEI_DT
				INTO STRICT l_sakuseiDt
				FROM MGR_KIKO_KIHON
				WHERE ITAKU_KAISHA_CD = gItakuKaishaCd
				  AND MGR_CD = gMgrCd
				;
			EXCEPTION
				-- 新規登録のケース
				WHEN no_data_found THEN
					l_sakuseiDt := NULL;
			END;
		END IF;
		-- 削除処理 
        DELETE FROM MGR_KIKO_KIHON MG9
         WHERE
        	   MG9.ITAKU_KAISHA_CD = gItakuKaishaCd
           AND MG9.MGR_CD = gMgrCd;
 			-- 登録処理 
    		--* 銘柄機構基本登録 *
    	BEGIN
		INSERT INTO MGR_KIKO_KIHON (ITAKU_KAISHA_CD,
			 MGR_CD,
			 HAKKODAIRI_CD,
			 KK_HAKKO_CD,
			 ISIN_CD,
			 MGR_NM,
			 KK_HAKKOSHA_RNM,
			 KAIGO_ETC,
			 BOSHU_KBN,
			 HOSHO_KBN,
			 TANPO_KBN,
			 GODOHAKKO_FLG,
			 RETSUTOKU_UMU_FLG,
			 SKNNZISNTOKU_UMU_FLG,
			 SAIKEN_SHURUI,
			 BOSHU_ST_YMD,
			 HAKKO_YMD,
			 KAKUSHASAI_KNGK,
			 UCHIKIRI_HAKKO_FLG,
			 SHASAI_TOTAL,
			 SHUTOKU_SUM,
			 HAKKO_TSUKA_CD,
			 SHRDAIRI_CD,
			 SKN_KESSAI_CD,
			 KK_KANYO_FLG,
			 KOBETSU_SHONIN_SAIYO_FLG,
			 SHASAI_KANRI_CD1,
			 SHASAI_KANRI_CD2,
			 SHASAI_KANRI_CD3,
			 SHASAI_KANRI_CD4,
			 SHASAI_KANRI_CD5,
			 SHASAI_KANRI_CD6,
			 SHASAI_KANRI_CD7,
			 SHASAI_KANRI_CD8,
			 SHASAI_KANRI_CD9,
			 SHASAI_KANRI_CD10,
			 JUTAKU_KAISHA1,
			 JUTAKU_KAISHA2,
			 JUTAKU_KAISHA3,
			 JUTAKU_KAISHA4,
			 JUTAKU_KAISHA5,
			 TRUST_SHOSHO_WAREKI,
			 PARTHAKKO_UMU_FLG,
			 KYUJITSU_KBN,
			 KYUJITSU_LD_FLG,
			 KYUJITSU_NY_FLG,
			 KYUJITSU_ETC_FLG,
			 RITSUKE_WARIBIKI_KBN,
			 RBR_TSUKA_CD,
			 RBR_KJT_MD1,
			 RBR_KJT_MD2,
			 RBR_KJT_MD3,
			 RBR_KJT_MD4,
			 RBR_KJT_MD5,
			 RBR_KJT_MD6,
			 RBR_KJT_MD7,
			 RBR_KJT_MD8,
			 RBR_KJT_MD9,
			 RBR_KJT_MD10,
			 RBR_KJT_MD11,
			 RBR_KJT_MD12,
			 ST_RBR_KJT,
			 LAST_RBR_FLG,
			 RIRITSU,
			 TSUKARISHI_KNGK_FAST,
			 TSUKARISHI_KNGK_NORM,
			 TSUKARISHI_KNGK_LAST,
			 SHOKAN_TSUKA_CD,
			 KAWASE_RATE,
			 FULLSHOKAN_KJT,
			 CALLALL_UMU_FLG,
			 TEIJI_SHOKAN_UMU_FLG,
			 ST_TEIJISHOKAN_KJT,
			 TEIJI_SHOKAN_TSUTI_KBN,
			 TEIJI_SHOKAN_KNGK,
			 CALLITIBU_UMU_FLG,
			 PUTUMU_FLG,
			 SHANAI_KOMOKU1,
			 SHANAI_KOMOKU2,
			 TOKUREI_SHASAI_FLG,
			 IKKATSUIKO_FLG,
			 TKTI_KOZA_CD,
			 GENISIN_CD,
			 PARTMGR_KBN,
			 SHORI_KBN,
			 LAST_TEISEI_DT,
			 LAST_TEISEI_ID,
			 KOUSIN_ID,
			 SAKUSEI_DT,
			 SAKUSEI_ID)
			VALUES (
			 gItakuKaishaCd,
			 recCurKK_renkei.HYOJI_KOMOKU1,
			 coalesce(recCurKK_renkei.ITEM028, ' '),
 				 ' ',
			 recCurKK_renkei.ITEM002,
			 coalesce(recCurKK_renkei.ITEM006, ' '),
			 coalesce(recCurKK_renkei.ITEM007, ' '),
			 coalesce(recCurKK_renkei.ITEM008, ' '),
			 coalesce(recCurKK_renkei.ITEM009, ' '),
			 coalesce(recCurKK_renkei.ITEM016, ' '),
			 coalesce(recCurKK_renkei.ITEM017, ' '),
			 coalesce(recCurKK_renkei.ITEM019, ' '),
			 coalesce(recCurKK_renkei.ITEM020, ' '),
			 coalesce(recCurKK_renkei.ITEM021, ' '),
			 coalesce(recCurKK_renkei.ITEM022, ' '),
			 coalesce(recCurKK_renkei.ITEM023, ' '),
			 coalesce(recCurKK_renkei.ITEM024, ' '),
			 TO_NUMBER(coalesce(NULLIF(trim(both recCurKK_renkei.ITEM025), ''), '0'), '99999999999999'),
			 recCurKK_renkei.ITEM026,
			 TO_NUMBER(coalesce(NULLIF(trim(both recCurKK_renkei.ITEM027), ''), '0'), '99999999999999'),
			 ' ',
			 ' ',
			 coalesce(recCurKK_renkei.ITEM029, ' '),
			 coalesce(recCurKK_renkei.ITEM030, ' '),
			 coalesce(recCurKK_renkei.ITEM031, ' '),
			 coalesce(recCurKK_renkei.ITEM032, ' '),
			 recCurKK_renkei.ITEM033,
			 recCurKK_renkei.ITEM034,
			 recCurKK_renkei.ITEM035,
			 recCurKK_renkei.ITEM036,
			 recCurKK_renkei.ITEM037,
			 recCurKK_renkei.ITEM038,
			 recCurKK_renkei.ITEM039,
			 recCurKK_renkei.ITEM040,
			 recCurKK_renkei.ITEM041,
			 recCurKK_renkei.ITEM042,
			 ' ',
			 ' ',
			 ' ',
			 ' ',
			 ' ',
			 ' ',
			 coalesce(recCurKK_renkei.ITEM018, ' '),
			 coalesce(recCurKK_renkei.ITEM043, ' '),
			 ' ',
			 ' ',
			 ' ',
			 coalesce(recCurKK_renkei.ITEM044, ' '),
			 ' ',
			 recCurKK_renkei.ITEM045,
			 recCurKK_renkei.ITEM046,
			 recCurKK_renkei.ITEM047,
			 recCurKK_renkei.ITEM048,
			 recCurKK_renkei.ITEM049,
			 recCurKK_renkei.ITEM050,
			 recCurKK_renkei.ITEM051,
			 recCurKK_renkei.ITEM052,
			 recCurKK_renkei.ITEM053,
			 recCurKK_renkei.ITEM054,
			 recCurKK_renkei.ITEM055,
			 recCurKK_renkei.ITEM056,
			 CASE WHEN coalesce(recCurKK_renkei.ITEM058::text, '') = '' THEN  ' '  ELSE recCurKK_renkei.ITEM058 END ,
			 coalesce(recCurKK_renkei.ITEM057, ' '),
			 TO_NUMBER(coalesce(NULLIF(trim(both recCurKK_renkei.ITEM059), ''), '0'), '9.9999999'),
			 TO_NUMBER(coalesce(NULLIF(trim(both recCurKK_renkei.ITEM060), ''), '0'), '9.9999999999999'),
			 TO_NUMBER(coalesce(NULLIF(trim(both recCurKK_renkei.ITEM061), ''), '0'), '9.9999999999999'),
			 TO_NUMBER(coalesce(NULLIF(trim(both recCurKK_renkei.ITEM062), ''), '0'), '9.9999999999999'),
			 ' ',
			 '0',
			 coalesce(recCurKK_renkei.ITEM069, ' '),
			 coalesce(recCurKK_renkei.ITEM071, ' '),
			 ' ',
			 ' ',
			 ' ',
			 '0',
			 ' ',
			 coalesce(recCurKK_renkei.ITEM076, ' '),
			 ' ',
			 ' ',
			 coalesce(recCurKK_renkei.ITEM092, ' '),
			 ' ',
			 ' ',
			 ' ',
			 ' ',
			 '0',
			 to_timestamp(pkDate.getCurrentTime(), 'YYYY-MM-DD HH24:MI:SS.US'),
			 USER_ID,
			 USER_ID,
			 coalesce(l_sakuseiDt, to_timestamp(pkDate.getCurrentTime(), 'YYYY-MM-DD HH24:MI:SS.US')), -- 作成日時：業務日付＋システム時刻（更新の場合作成時のものを引き継ぎ）
			 USER_ID);
		EXCEPTION
			WHEN OTHERS THEN
				RAISE;
		END;
		--* CB銘柄機構基本登録 *
		-- 削除処理 
        DELETE FROM CB_MGR_KIKO_KIHON WMG9
         WHERE
        	   WMG9.ITAKU_KAISHA_CD = gItakuKaishaCd
           AND WMG9.MGR_CD = gMgrCd;
		-- 登録処理 
		INSERT INTO CB_MGR_KIKO_KIHON (ITAKU_KAISHA_CD,
			MGR_CD,
			SHNK_HNK_TRKSH_KBN,
			KK_MGR_CD,
			TEKIYOST_YMD,
			JOJO_KBN_TO,
			JOJO_KBN_DA,
			JOJO_KBN_ME,
			JOJO_KBN_FU,
			JOJO_KBN_SA,
			JOJO_KBN_JA,
			SHOKAN_KAGAKU,
			WRNT_TOTAL,
			WRNT_USE_ST_YMD,
			WRNT_USE_ED_YMD,
			WRNT_HAKKO_KAGAKU,
			WRNT_USE_KAGAKU,
			USE_SEIKYU_UKE_BASHO,
			SHTK_JK_UMU_FLG,
			SHTK_JK_YMD,
			SHTK_TAIKA_SHURUI,
			HASU_SHOKAN_UMU_FLG,
			SHANAI_KOMOKU1,
			SHANAI_KOMOKU2,
			KIKO_GANKIN_TESU_RITSU,
			GNKN_TESU_RITSU_KIJUN,
			KIKO_RIKIN_TESU_RITSU,
			RKN_TESU_RITSU_KIJUN,
			THIS_RBR_KJT,
			THIS_RIRITSU,
			THIS_TSUKARISHI_KNGK,
			NEXT_RBR_KJT,
			NEXT_RIRITSU,
			NEXT_TSUKARISHI_KNGK,
			SHORI_KBN,
			LAST_TEISEI_DT,
			LAST_TEISEI_ID,
			KOUSIN_ID,
			SAKUSEI_ID)
		VALUES (
			gItakuKaishaCd,
			recCurKK_renkei.HYOJI_KOMOKU1,
			recCurKK_renkei.ITEM005,
			recCurKK_renkei.ITEM001,
			recCurKK_renkei.ITEM003,
			coalesce(recCurKK_renkei.ITEM010, ' '),
			coalesce(recCurKK_renkei.ITEM011, ' '),
			coalesce(recCurKK_renkei.ITEM012, ' '),
			coalesce(recCurKK_renkei.ITEM013, ' '),
			coalesce(recCurKK_renkei.ITEM014, ' '),
			coalesce(recCurKK_renkei.ITEM015, ' '),
			recCurKK_renkei.ITEM070,
			recCurKK_renkei.ITEM082,
			coalesce(recCurKK_renkei.ITEM083, ' '),
			coalesce(recCurKK_renkei.ITEM084, ' '),
			recCurKK_renkei.ITEM085,
			recCurKK_renkei.ITEM086,
			coalesce(recCurKK_renkei.ITEM087, ' '),
			coalesce(recCurKK_renkei.ITEM088, ' '),
			coalesce(recCurKK_renkei.ITEM089, ' '),
			coalesce(recCurKK_renkei.ITEM090, ' '),
			coalesce(recCurKK_renkei.ITEM091, ' '),
			coalesce(recCurKK_renkei.ITEM097, ' '),
			coalesce(recCurKK_renkei.ITEM098, ' '),
			recCurKK_renkei.ITEM093,
			recCurKK_renkei.ITEM094,
			recCurKK_renkei.ITEM095,
			recCurKK_renkei.ITEM096,
			coalesce(recCurKK_renkei.ITEM063, ' '),
			recCurKK_renkei.ITEM064,
			recCurKK_renkei.ITEM065,
			recCurKK_renkei.ITEM066,
			recCurKK_renkei.ITEM067,
			recCurKK_renkei.ITEM068,
			'0',
			to_timestamp(pkDate.getCurrentTime(), 'YYYY-MM-DD HH24:MI:SS.US'),
			USER_ID,
			USER_ID,
			USER_ID);
	END LOOP;
	--* 銘柄_基本累積（ＣＢ）削除・登録 *		
	FOR recCurCB_ruiseki IN curCB_ruiseki LOOP
		-- 削除処理 
        DELETE FROM CB_MGR_KHN_RUISEKI WMG12
         WHERE
        	   WMG12.ITAKU_KAISHA_CD = gItakuKaishaCd
           AND WMG12.MGR_CD = gMgrCd
           AND WMG12.SEQ_NO = '1'
           AND WMG12.KK_PHASE = 'M1';
		-- 登録処理 
		INSERT INTO CB_MGR_KHN_RUISEKI (ITAKU_KAISHA_CD,
			 MGR_CD,
			 TEKIYOST_YMD,
			 SEQ_NO,
			 KK_TSUCHI_YMD,
			 SHNK_HNK_TRKSH_KBN,
			 SHONIN_KAIJO_YOKUSEI_FLG,
			 KK_PHASE,
			 KK_STAT,
			 KK_TSUCHI_FLG,
			 ISIN_CD,
			 HAKKODAIRI_CD,
			 SHRDAIRI_CD,
			 SKN_KESSAI_CD,
			 MGR_NM,
			 KK_HAKKOSHA_RNM,
			 KAIGO_ETC,
			 BOSHU_KBN,
			 SAIKEN_SHURUI,
			 HOSHO_KBN,
			 TANPO_KBN,
			 GODOHAKKO_FLG,
			 RETSUTOKU_UMU_FLG,
			 SKNNZISNTOKU_UMU_FLG,
			 BOSHU_ST_YMD,
			 HAKKO_YMD,
			 UCHIKIRI_HAKKO_FLG,
			 HAKKO_TSUKA_CD,
			 KAKUSHASAI_KNGK,
			 SHASAI_TOTAL,
			 FULLSHOKAN_KJT,
			 CALLALL_UMU_FLG,
			 PUTUMU_FLG,
			 PARTHAKKO_UMU_FLG,
			 KYUJITSU_KBN,
			 RITSUKE_WARIBIKI_KBN,
			 NENRBR_CNT,
			 TOTAL_RBR_CNT,
			 RBR_DD,
			 ST_RBR_KJT,
			 KK_ST_RBR_KJT,
			 LAST_RBR_FLG,
			 RIRITSU,
			 TSUKARISHI_KNGK_FAST,
			 TSUKARISHI_KNGK_NORM,
			 TSUKARISHI_KNGK_LAST,
			 TSUKARISHI_KNGK_FAST_S,
			 TSUKARISHI_KNGK_NORM_S,
			 TSUKARISHI_KNGK_LAST_S,
			 RBR_KJT_MD1,
			 RBR_KJT_MD2,
			 RBR_KJT_MD3,
			 RBR_KJT_MD4,
			 RBR_KJT_MD5,
			 RBR_KJT_MD6,
			 RBR_KJT_MD7,
			 RBR_KJT_MD8,
			 RBR_KJT_MD9,
			 RBR_KJT_MD10,
			 RBR_KJT_MD11,
			 RBR_KJT_MD12,
			 KK_KANYO_FLG,
			 KOBETSU_SHONIN_SAIYO_FLG,
			 SHANAI_KOMOKU1,
			 SHANAI_KOMOKU2,
			 TOKUREI_SHASAI_FLG,
			 KK_MGR_CD,
			 JOJO_KBN_TO,
			 JOJO_KBN_DA,
			 JOJO_KBN_ME,
			 JOJO_KBN_FU,
			 JOJO_KBN_SA,
			 JOJO_KBN_JA,
			 SHOKAN_PREMIUM,
			 WRNT_TOTAL,
			 WRNT_USE_KAGAKU_KETTEI_YMD,
			 WRNT_USE_ST_YMD,
			 WRNT_USE_ED_YMD,
			 WRNT_HAKKO_KAGAKU,
			 WRNT_USE_KAGAKU,
			 USE_KAGAKU_HENKO_FLG,
			 USE_SEIKYU_UKE_BASHO,
			 WRNT_BIKO,
			 SHTK_JK_UMU_FLG,
			 SHTK_JK_YMD,
			 SHTK_TAIKA_SHURUI,
			 HASU_SHOKAN_UMU_FLG,
			 SHASAI_KANRI_CD1,
			 SHASAI_KANRI_CD2,
			 SHASAI_KANRI_CD3,
			 SHASAI_KANRI_CD4,
			 SHASAI_KANRI_CD5,
			 SHASAI_KANRI_CD6,
			 SHASAI_KANRI_CD7,
			 SHASAI_KANRI_CD8,
			 SHASAI_KANRI_CD9,
			 SHASAI_KANRI_CD10,
			 KIKO_GANKIN_TESU_RITSU,
			 GNKN_TESU_RITSU_KIJUN,
			 KIKO_RIKIN_TESU_RITSU,
			 RKN_TESU_RITSU_KIJUN,
			 SHORI_KBN,
			 LAST_TEISEI_DT,
			 LAST_TEISEI_ID,
			 KOUSIN_ID,
			 SAKUSEI_ID)
		VALUES (
			 gItakuKaishaCd,							-- 委託会社コード
			 recCurCB_ruiseki.MGR_CD,					-- 銘柄コード
			 recCurCB_ruiseki.TEKIYOST_YMD,				-- 適用開始日
			 '1',										-- シーケンスＮｏ
			 pkDate.getGyomuYmd(),						-- 機構通知日
			 recCurCB_ruiseki.SHNK_HNK_TRKSH_KBN,		-- 適用開始日				
			 '1',										-- 承認解除抑制フラグ
			 'M1',										-- 機構フェーズ
			 '04',										-- 機構ステータス
			 '1',										-- 機構通知フラグ
			 recCurCB_ruiseki.ISIN_CD,					-- ＩＳＩＮコード
			 recCurCB_ruiseki.HAKKODAIRI_CD,			-- 発行代理人コード
			 recCurCB_ruiseki.SHRDAIRI_CD,				-- 支払代理人コード
			 recCurCB_ruiseki.SKN_KESSAI_CD,			-- 資金決済会社コード
			 recCurCB_ruiseki.MGR_NM,					-- 銘柄の正式名称
			 recCurCB_ruiseki.KK_HAKKOSHA_RNM,			-- 機構発行者略称
			 recCurCB_ruiseki.KAIGO_ETC,				-- 回号等
			 recCurCB_ruiseki.BOSHU_KBN,				-- 募集区分
			 recCurCB_ruiseki.SAIKEN_SHURUI,			-- 債券種類
			 recCurCB_ruiseki.HOSHO_KBN,				-- 保証区分
			 recCurCB_ruiseki.TANPO_KBN,				-- 担保区分
			 recCurCB_ruiseki.GODOHAKKO_FLG,			-- 合同発行フラグ
			 recCurCB_ruiseki.RETSUTOKU_UMU_FLG,		-- 劣後特約有無フラグ
			 recCurCB_ruiseki.SKNNZISNTOKU_UMU_FLG,		-- 責任財産限定特約有無フラグ
			 recCurCB_ruiseki.BOSHU_ST_YMD,				-- 募集開始日	
			 recCurCB_ruiseki.HAKKO_YMD,				-- 発行年月日	
			 recCurCB_ruiseki.UCHIKIRI_HAKKO_FLG,		-- 打切発行フラグ	
			 recCurCB_ruiseki.HAKKO_TSUKA_CD,			-- 発行通貨	
			 recCurCB_ruiseki.KAKUSHASAI_KNGK,			-- 各社債の金額	
			 recCurCB_ruiseki.SHASAI_TOTAL,				-- 社債の総額	
			 recCurCB_ruiseki.FULLSHOKAN_KJT,			-- 満期償還期日	
			 recCurCB_ruiseki.CALLALL_UMU_FLG,			-- コールオプション有無フラグ（全額償還）
			 recCurCB_ruiseki.PUTUMU_FLG,				-- プットオプション有無フラグ	
			 recCurCB_ruiseki.PARTHAKKO_UMU_FLG,		-- 分割発行有無フラグ	
			 recCurCB_ruiseki.KYUJITSU_KBN,				-- 休日処理区分	
			 recCurCB_ruiseki.RITSUKE_WARIBIKI_KBN,		-- 利付割引区分	
			 recCurCB_ruiseki.NENRBR_CNT,				-- 年利払回数	
			 recCurCB_ruiseki.TOTAL_RBR_CNT,			-- 総利払回数	
			 recCurCB_ruiseki.RBR_DD,					-- 利払日付	
			 recCurCB_ruiseki.ST_RBR_KJT,				-- 初回利払期日	
			 recCurCB_ruiseki.KK_ST_RBR_KJT,			-- 機構_初回利払期日
			 recCurCB_ruiseki.LAST_RBR_FLG,				-- 最終利払有無フラグ	
			 recCurCB_ruiseki.RIRITSU,					-- 利率	
			 recCurCB_ruiseki.TSUKARISHI_KNGK_FAST,		-- １通貨あたりの利子金額（初期）	
			 recCurCB_ruiseki.TSUKARISHI_KNGK_NORM,		-- １通貨あたりの利子金額（通常）	
			 recCurCB_ruiseki.TSUKARISHI_KNGK_LAST,		-- １通貨あたりの利子金額（終期）	
			 recCurCB_ruiseki.TSUKARISHI_KNGK_FAST_S,	-- １通貨あたりの利子金額（初期）算出値
			 recCurCB_ruiseki.TSUKARISHI_KNGK_NORM_S,	-- １通貨あたりの利子金額（通常）算出値
			 recCurCB_ruiseki.TSUKARISHI_KNGK_LAST_S,	-- １通貨あたりの利子金額（終期）算出値
			 recCurCB_ruiseki.RBR_KJT_MD1,				-- 利払期日（MD）（１）	
			 recCurCB_ruiseki.RBR_KJT_MD2,				-- 利払期日（MD）（２）	
			 recCurCB_ruiseki.RBR_KJT_MD3,				-- 利払期日（MD）（３）	
			 recCurCB_ruiseki.RBR_KJT_MD4,				-- 利払期日（MD）（４）	
			 recCurCB_ruiseki.RBR_KJT_MD5,				-- 利払期日（MD）（５）	
			 recCurCB_ruiseki.RBR_KJT_MD6,				-- 利払期日（MD）（６）	
			 recCurCB_ruiseki.RBR_KJT_MD7,				-- 利払期日（MD）（７）	
			 recCurCB_ruiseki.RBR_KJT_MD8,				-- 利払期日（MD）（８）	
			 recCurCB_ruiseki.RBR_KJT_MD9,				-- 利払期日（MD）（９）	
			 recCurCB_ruiseki.RBR_KJT_MD10,				-- 利払期日（MD）（１０）	
			 recCurCB_ruiseki.RBR_KJT_MD11,				-- 利払期日（MD）（１１）	
			 recCurCB_ruiseki.RBR_KJT_MD12,				-- 利払期日（MD）（１２）	
			 recCurCB_ruiseki.KK_KANYO_FLG,				-- 機構関与方式採用フラグ	
			 recCurCB_ruiseki.KOBETSU_SHONIN_SAIYO_FLG,	-- 個別承認採用フラグ	
			 recCurCB_ruiseki.SHANAI_KOMOKU1,			-- 社内処理用項目１	
			 recCurCB_ruiseki.SHANAI_KOMOKU2,			-- 社内処理用項目２	
			 recCurCB_ruiseki.TOKUREI_SHASAI_FLG,		--     特例社債フラグ
			 recCurCB_ruiseki.KK_MGR_CD,				-- 機構銘柄コード
			 recCurCB_ruiseki.JOJO_KBN_TO,				-- 上場区分(東証)
			 recCurCB_ruiseki.JOJO_KBN_DA,				-- 上場区分(大証)
			 recCurCB_ruiseki.JOJO_KBN_ME,				-- 上場区分(名証)
			 recCurCB_ruiseki.JOJO_KBN_FU,				-- 上場区分(福証)
			 recCurCB_ruiseki.JOJO_KBN_SA,				-- 上場区分(札証)
			 recCurCB_ruiseki.JOJO_KBN_JA,				-- 上場区分(ジャスダック証)
			 recCurCB_ruiseki.SHOKAN_PREMIUM,			-- 償還プレミアム
			 recCurCB_ruiseki.WRNT_TOTAL,				-- 新株予約権の総数
			 recCurCB_ruiseki.WRNT_USE_KAGAKU_KETTEI_YMD,	-- 新株予約権の行使価額決定日
			 recCurCB_ruiseki.WRNT_USE_ST_YMD,				-- 新株予約権の行使期間開始日
			 recCurCB_ruiseki.WRNT_USE_ED_YMD,				-- 新株予約権の行使期間終了日
			 recCurCB_ruiseki.WRNT_HAKKO_KAGAKU,			-- 新株予約権の発行価額
			 recCurCB_ruiseki.WRNT_USE_KAGAKU,				-- 新株予約権の行使価額
			 '1',											-- 行使価額変更フラグ
			 recCurCB_ruiseki.USE_SEIKYU_UKE_BASHO,		-- 行使請求受付場所
			 recCurCB_ruiseki.WRNT_BIKO,				-- 新株予約権に係る備考
			 recCurCB_ruiseki.SHTK_JK_UMU_FLG,			-- 取得条項有無フラグ
			 recCurCB_ruiseki.SHTK_JK_YMD,				-- 取得条項に係る取得日
			 recCurCB_ruiseki.SHTK_TAIKA_SHURUI,		-- 取得対価(交付財産)の種類
			 recCurCB_ruiseki.HASU_SHOKAN_UMU_FLG,		-- 端数償還金有無フラグ
			 recCurCB_ruiseki.SHASAI_KANRI_CD1,			-- 社債管理者（１）
			 recCurCB_ruiseki.SHASAI_KANRI_CD2,			-- 社債管理者（２）
			 recCurCB_ruiseki.SHASAI_KANRI_CD3,			-- 社債管理者（３）
			 recCurCB_ruiseki.SHASAI_KANRI_CD4,			-- 社債管理者（４）
			 recCurCB_ruiseki.SHASAI_KANRI_CD5,			-- 社債管理者（５）
			 recCurCB_ruiseki.SHASAI_KANRI_CD6,			-- 社債管理者（６）
			 recCurCB_ruiseki.SHASAI_KANRI_CD7,			-- 社債管理者（７）
			 recCurCB_ruiseki.SHASAI_KANRI_CD8,			-- 社債管理者（８）
			 recCurCB_ruiseki.SHASAI_KANRI_CD9,			-- 社債管理者（９）
			 recCurCB_ruiseki.SHASAI_KANRI_CD10,		-- 社債管理者（１０）
			 recCurCB_ruiseki. KIKO_GANKIN_TESU_RITSU,	-- 機構元金手数料率
			 '2',										-- 機構フェーズ
			 recCurCB_ruiseki. KIKO_RIKIN_TESU_RITSU,	-- 機構利金手数料率
			 recCurCB_ruiseki. RKN_TESU_RITSU_KIJUN,	-- 利金手数料率基準
			 '1',										-- 処理区分
			 to_timestamp(pkDate.getCurrentTime(), 'YYYY-MM-DD HH24:MI:SS.US'),	-- 最終訂正日時
			 USER_ID,									-- 最終訂正者
			 USER_ID,									-- 更新者
			 USER_ID);								-- 作成者
	END LOOP;
	rtn := pkconstant.success();
RETURN rtn;
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadw013s5111common_insertmeigara () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfadw013s5111common_updatemeigara (
	gItakuKaishaCd MGR_KIHON.ITAKU_KAISHA_CD%TYPE,
	gMgrCd MGR_KIHON.MGR_CD%TYPE,
	l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE,
	l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE,
	USER_ID varchar(10),
	sqlCount numeric,
	gSql IN OUT varchar(2500),
	cFlg IN OUT integer,
	rtn OUT integer
) RETURNS record AS $body$
DECLARE

	ora2pg_rowcount int;
	tekiyobi	char(8);

	curKK_renkei CURSOR FOR
	SELECT *
	  FROM KK_RENKEI RT02
	 WHERE RT02.KK_SAKUSEI_DT    = l_inKkSakuseiDt
	   AND RT02.DENBUN_MEISAI_NO = l_inDenbunMeisaiNo;

	-- 銘柄_基本累積（ＣＢ）用データ取得カーソル 
	curCB_ruiseki CURSOR FOR
	SELECT MG1.MGR_CD,
	       WMG1.TEKIYOST_YMD,
	       WMG1.SHNK_HNK_TRKSH_KBN,
	       MG1.ISIN_CD,
	       MG1.HAKKODAIRI_CD,
	       MG1.SHRDAIRI_CD,
	       MG1.SKN_KESSAI_CD,
	       MG1.MGR_NM,
	       MG1.KK_HAKKOSHA_RNM,
	       MG1.KAIGO_ETC,
	       MG1.BOSHU_KBN,
	       MG1.SAIKEN_SHURUI,
	       MG1.HOSHO_KBN,
	       MG1.TANPO_KBN,
	       MG1.GODOHAKKO_FLG,
	       MG1.RETSUTOKU_UMU_FLG,
	       MG1.SKNNZISNTOKU_UMU_FLG,
	       MG1.BOSHU_ST_YMD,
	       MG1.HAKKO_YMD,
	       MG1.UCHIKIRI_HAKKO_FLG,
	       MG1.HAKKO_TSUKA_CD,
	       MG1.KAKUSHASAI_KNGK,
	       MG1.SHASAI_TOTAL,
	       MG1.FULLSHOKAN_KJT,
	       MG1.CALLALL_UMU_FLG,
	       MG1.PUTUMU_FLG,
	       MG1.PARTHAKKO_UMU_FLG,
	       MG1.KYUJITSU_KBN,
	       MG1.RITSUKE_WARIBIKI_KBN,
	       MG1.NENRBR_CNT,
	       MG1.TOTAL_RBR_CNT,
	       MG1.RBR_DD,
	       MG1.ST_RBR_KJT,
	       CASE WHEN MG1.TOKUREI_SHASAI_FLG='Y' THEN coalesce(trim(both MG1.YOBI3), ' ')  ELSE ' ' END  AS KK_ST_RBR_KJT,
	       MG1.LAST_RBR_FLG,
	       MG1.RIRITSU,
	       MG1.TSUKARISHI_KNGK_FAST,
	       MG1.TSUKARISHI_KNGK_NORM,
	       MG1.TSUKARISHI_KNGK_LAST,
	       MG1.TSUKARISHI_KNGK_FAST_S,
	       MG1.TSUKARISHI_KNGK_NORM_S,
	       MG1.TSUKARISHI_KNGK_LAST_S,
	       MG1.RBR_KJT_MD1,
	       MG1.RBR_KJT_MD2,
	       MG1.RBR_KJT_MD3,
	       MG1.RBR_KJT_MD4,
	       MG1.RBR_KJT_MD5,
	       MG1.RBR_KJT_MD6,
	       MG1.RBR_KJT_MD7,
	       MG1.RBR_KJT_MD8,
	       MG1.RBR_KJT_MD9,
	       MG1.RBR_KJT_MD10,
	       MG1.RBR_KJT_MD11,
	       MG1.RBR_KJT_MD12,
	       MG1.KK_KANYO_FLG,
	       MG1.KOBETSU_SHONIN_SAIYO_FLG,
	       WMG1.SHANAI_KOMOKU1,
	       WMG1.SHANAI_KOMOKU2,
	       MG1.TOKUREI_SHASAI_FLG,
	       WMG1.KK_MGR_CD,
	       WMG1.JOJO_KBN_TO,
	       WMG1.JOJO_KBN_DA,
	       WMG1.JOJO_KBN_ME,
	       WMG1.JOJO_KBN_FU,
	       WMG1.JOJO_KBN_SA,
	       WMG1.JOJO_KBN_JA,
	       WMG1.SHOKAN_PREMIUM,
	       WMG1.WRNT_TOTAL,
	       WMG1.WRNT_USE_KAGAKU_KETTEI_YMD,
	       WMG1.WRNT_USE_ST_YMD,
	       WMG1.WRNT_USE_ED_YMD,
	       WMG1.WRNT_HAKKO_KAGAKU,
	       WMG1.WRNT_USE_KAGAKU,
	       WMG1.USE_SEIKYU_UKE_BASHO,
	       WMG1.WRNT_BIKO,
	       WMG1.SHTK_JK_UMU_FLG,
	       WMG1.SHTK_JK_YMD,
	       WMG1.SHTK_TAIKA_SHURUI,
	       WMG1.HASU_SHOKAN_UMU_FLG,
	       coalesce((SELECT MG6.FINANCIAL_SECURITIES_KBN || MG6.BANK_CD
	          FROM MGR_JUTAKUGINKO MG6
	         WHERE MG6.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
	           AND MG6.MGR_CD = MG1.MGR_CD
	           AND MG6.INPUT_NUM = '1'),' ') AS SHASAI_KANRI_CD1,
	       coalesce((SELECT MG6.FINANCIAL_SECURITIES_KBN || MG6.BANK_CD
	          FROM MGR_JUTAKUGINKO MG6 
	         WHERE MG6.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
	           AND MG6.MGR_CD = MG1.MGR_CD
	           AND MG6.INPUT_NUM = '2'),' ') AS SHASAI_KANRI_CD2,
	       coalesce((SELECT MG6.FINANCIAL_SECURITIES_KBN || MG6.BANK_CD
	          FROM MGR_JUTAKUGINKO MG6 
	         WHERE MG6.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
	           AND MG6.MGR_CD = MG1.MGR_CD
	           AND MG6.INPUT_NUM = '3'),' ') AS SHASAI_KANRI_CD3,
	       coalesce((SELECT MG6.FINANCIAL_SECURITIES_KBN || MG6.BANK_CD
	          FROM MGR_JUTAKUGINKO MG6 
	         WHERE MG6.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
	           AND MG6.MGR_CD = MG1.MGR_CD
	           AND MG6.INPUT_NUM = '4'),' ') AS SHASAI_KANRI_CD4,
	       coalesce((SELECT MG6.FINANCIAL_SECURITIES_KBN || MG6.BANK_CD
	          FROM MGR_JUTAKUGINKO MG6 
	         WHERE MG6.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
	           AND MG6.MGR_CD = MG1.MGR_CD
	           AND MG6.INPUT_NUM = '5'),' ') AS SHASAI_KANRI_CD5,
	       coalesce((SELECT MG6.FINANCIAL_SECURITIES_KBN || MG6.BANK_CD
	          FROM MGR_JUTAKUGINKO MG6 
	         WHERE MG6.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
	           AND MG6.MGR_CD = MG1.MGR_CD
	           AND MG6.INPUT_NUM = '6'),' ') AS SHASAI_KANRI_CD6,
	       coalesce((SELECT MG6.FINANCIAL_SECURITIES_KBN || MG6.BANK_CD
	          FROM MGR_JUTAKUGINKO MG6 
	         WHERE MG6.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
	           AND MG6.MGR_CD = MG1.MGR_CD
	           AND MG6.INPUT_NUM = '7'),' ') AS SHASAI_KANRI_CD7,
	       coalesce((SELECT MG6.FINANCIAL_SECURITIES_KBN || MG6.BANK_CD
	          FROM MGR_JUTAKUGINKO MG6 
	         WHERE MG6.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
	           AND MG6.MGR_CD = MG1.MGR_CD
	           AND MG6.INPUT_NUM = '8'),' ') AS SHASAI_KANRI_CD8,
	       coalesce((SELECT MG6.FINANCIAL_SECURITIES_KBN || MG6.BANK_CD
	          FROM MGR_JUTAKUGINKO MG6 
	         WHERE MG6.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
	           AND MG6.MGR_CD = MG1.MGR_CD
	           AND MG6.INPUT_NUM = '9'),' ') AS SHASAI_KANRI_CD9,
	       coalesce((SELECT MG6.FINANCIAL_SECURITIES_KBN || MG6.BANK_CD
	          FROM MGR_JUTAKUGINKO MG6 
	         WHERE MG6.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
	           AND MG6.MGR_CD = MG1.MGR_CD
	           AND MG6.INPUT_NUM = '10'),' ') AS SHASAI_KANRI_CD10,
	       CASE WHEN coalesce(MG8.GNKN_SHR_TESU_BUNBO, 0)=0 THEN  0  ELSE TRUNC((MG8.GNKN_SHR_TESU_BUNSHI/MG8.GNKN_SHR_TESU_BUNBO * 10000)::numeric, 14) END  AS KIKO_GANKIN_TESU_RITSU,
	       CASE WHEN coalesce(MG8.RKN_SHR_TESU_BUNBO, 0)=0 THEN  0  ELSE TRUNC((MG8.RKN_SHR_TESU_BUNSHI/MG8.RKN_SHR_TESU_BUNBO * 10000)::numeric, 14) END  AS KIKO_RIKIN_TESU_RITSU,
	       coalesce(CASE MG1.RITSUKE_WARIBIKI_KBN
	       WHEN 'Z' THEN
	            '3'
	       WHEN 'V' THEN
	            CASE MG7_1.TESU_SHURUI_CD
	            WHEN '61' THEN
	                 '1'
	            WHEN '82' THEN
	                 '2'
	            END
	       WHEN 'F' THEN
	            CASE MG7_1.TESU_SHURUI_CD
	            WHEN '61' THEN
	                 '1'
	            WHEN '82' THEN
	                 '2'
	            END
	       END,' ')  AS RKN_TESU_RITSU_KIJUN
	  FROM cb_mgr_kihon wmg1, (SELECT * FROM MGR_TESURYO_CTL MG7 
	      			WHERE MG7.ITAKU_KAISHA_CD = gItakuKaishaCd
	      			  AND MG7.MGR_CD = gMgrCd
	      			  AND MG7.TESU_SHURUI_CD IN ('61', '82')
	      			  AND MG7.CHOOSE_FLG = '1' )mg7_1, mgr_kihon mg1
		LEFT OUTER JOIN mgr_tesuryo_prm mg8 ON (MG1.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD AND MG1.MGR_CD = MG8.MGR_CD)
		LEFT OUTER JOIN mg7_1 ON (MG1.ITAKU_KAISHA_CD = MG7_1.ITAKU_KAISHA_CD AND MG1.MGR_CD = MG7_1.MGR_CD)
		WHERE MG1.ITAKU_KAISHA_CD = gItakuKaishaCd AND MG1.MGR_CD = gMgrCd AND MG1.ITAKU_KAISHA_CD = WMG1.ITAKU_KAISHA_CD AND MG1.MGR_CD = WMG1.MGR_CD;

BEGIN
	rtn := pkconstant.error();
    	FOR recCurKK_renkei IN curKK_renkei LOOP
				gSql := '';		-- 初期化 
				cFlg := '';		-- 初期化 
				tekiyobi := trim(both recCurKK_renkei.ITEM003); -- 適用日取得 
		
    		--* 銘柄機構基本更新 *
    		gSql := 'UPDATE MGR_KIKO_KIHON MG9 '
    			|| ' SET ';
    		-- 発行代理人コード 
    		IF (trim(both recCurKK_renkei.ITEM028) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM028::text)) <> '') THEN
    			gSql := gSql || ' MG9.HAKKODAIRI_CD = ''' || recCurKK_renkei.ITEM028 || '''';
    			cFlg := ',';
    		END IF;
    		-- ＩＳＩＮコード 
    		IF (trim(both recCurKK_renkei.ITEM002) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM002::text)) <> '') THEN
    			gSql := gSql || cFlg || ' MG9.ISIN_CD = ''' || recCurKK_renkei.ITEM002 || '''';
    			cFlg := ',';
    		END IF;
    		-- 銘柄の正式名称 
    		IF (trim(both recCurKK_renkei.ITEM006) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM006::text)) <> '') THEN
    			gSql := gSql || cFlg || ' MG9.MGR_NM = ''' || recCurKK_renkei.ITEM006 || '''';
    			cFlg := ',';
    		END IF;
    		-- 機構発行者略称 
    		IF (trim(both recCurKK_renkei.ITEM007) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM007::text)) <> '') THEN
    			gSql := gSql || cFlg || ' MG9.KK_HAKKOSHA_RNM = ''' || recCurKK_renkei.ITEM007 || '''';
    			cFlg := ',';
    		END IF;
    		-- 回号等 
    		IF (trim(both recCurKK_renkei.ITEM008) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM008::text)) <> '') THEN
    			gSql := gSql || cFlg || ' MG9.KAIGO_ETC = ''' || recCurKK_renkei.ITEM008 || '''';
    			cFlg := ',';
    		END IF;
    		-- 募集区分 
    		IF (trim(both recCurKK_renkei.ITEM009) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM009::text)) <> '') THEN
    			gSql := gSql || cFlg || ' MG9.BOSHU_KBN = ''' || recCurKK_renkei.ITEM009 || '''';
    			cFlg := ',';
    		END IF;
    		-- 保証区分 
    		IF (trim(both recCurKK_renkei.ITEM016) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM016::text)) <> '') THEN
    			gSql := gSql || cFlg || ' MG9.HOSHO_KBN = ''' || recCurKK_renkei.ITEM016 || '''';
    			cFlg := ',';
    		END IF;
    		-- 担保区分 
    		IF (trim(both recCurKK_renkei.ITEM017) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM017::text)) <> '') THEN
    			gSql := gSql || cFlg || ' MG9.TANPO_KBN = ''' || recCurKK_renkei.ITEM017 || '''';
    			cFlg := ',';
    		END IF;
    		-- 合同発行フラグ 
    		IF (trim(both recCurKK_renkei.ITEM019) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM019::text)) <> '') THEN
    			gSql := gSql || cFlg || ' MG9.GODOHAKKO_FLG = ''' || recCurKK_renkei.ITEM019 || '''';
    			cFlg := ',';
    		END IF;
    		-- 劣後特約有無フラグ 
    		IF (trim(both recCurKK_renkei.ITEM020) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM020::text)) <> '') THEN
    			gSql := gSql || cFlg || ' MG9.RETSUTOKU_UMU_FLG = ''' || recCurKK_renkei.ITEM020 || '''';
    			cFlg := ',';
    		END IF;
		-- 責任財産限定特約有無フラグ 
		IF (trim(both recCurKK_renkei.ITEM021) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM021::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.SKNNZISNTOKU_UMU_FLG = ''' || recCurKK_renkei.ITEM021 || '''';
			cFlg := ',';
		END IF;
		-- 債券種類 
		IF (trim(both recCurKK_renkei.ITEM022) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM022::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.SAIKEN_SHURUI = ''' || recCurKK_renkei.ITEM022 || '''';
			cFlg := ',';
		END IF;
		-- 募集開始日 
		IF (trim(both recCurKK_renkei.ITEM023) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM023::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.BOSHU_ST_YMD = ''' || recCurKK_renkei.ITEM023 || '''';
			cFlg := ',';
		END IF;
		-- 発行年月日 
		IF (trim(both recCurKK_renkei.ITEM024) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM024::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.HAKKO_YMD = ''' || recCurKK_renkei.ITEM024 || '''';
			cFlg := ',';
		END IF;
		-- 各社債の金額 
		IF (trim(both recCurKK_renkei.ITEM025) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM025::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.KAKUSHASAI_KNGK = ''' || recCurKK_renkei.ITEM025 || '''';
			cFlg := ',';
		END IF;
		-- 打切発行フラグ 
		IF (trim(both recCurKK_renkei.ITEM026) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM026::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.UCHIKIRI_HAKKO_FLG = ''' || recCurKK_renkei.ITEM026 || '''';
			cFlg := ',';
		END IF;
		-- 社債の総額 
		IF (trim(both recCurKK_renkei.ITEM027) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM027::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.SHASAI_TOTAL = ''' || recCurKK_renkei.ITEM027 || '''';
			cFlg := ',';
		END IF;
		-- 支払代理人コード 
		IF (trim(both recCurKK_renkei.ITEM029) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM029::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.SHRDAIRI_CD = ''' || recCurKK_renkei.ITEM029 || '''';
			cFlg := ',';
		END IF;
		-- 資金決済会社コード 
		IF (trim(both recCurKK_renkei.ITEM030) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM030::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.SKN_KESSAI_CD = ''' || recCurKK_renkei.ITEM030 || '''';
			cFlg := ',';
		END IF;
		-- 機構関与方式採用フラグ 
		IF (trim(both recCurKK_renkei.ITEM031) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM031::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.KK_KANYO_FLG = ''' || recCurKK_renkei.ITEM031 || '''';
			cFlg := ',';
		END IF;
		-- 個別承認採用フラグ 
		IF (trim(both recCurKK_renkei.ITEM032) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM032::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.KOBETSU_SHONIN_SAIYO_FLG = ''' || recCurKK_renkei.ITEM032 || '''';
			cFlg := ',';
		END IF;
		-- 社債管理会社（１） 
		IF (trim(both recCurKK_renkei.ITEM033) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM033::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.SHASAI_KANRI_CD1 = ''' || recCurKK_renkei.ITEM033 || '''';
			cFlg := ',';
		END IF;
		-- 社債管理会社（２） 
		IF (trim(both recCurKK_renkei.ITEM034) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM034::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.SHASAI_KANRI_CD2 = ''' || recCurKK_renkei.ITEM034 || '''';
			cFlg := ',';
		END IF;
		-- 社債管理会社（３） 
		IF (trim(both recCurKK_renkei.ITEM035) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM035::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.SHASAI_KANRI_CD3 = ''' || recCurKK_renkei.ITEM035 || '''';
			cFlg := ',';
		END IF;
		-- 社債管理会社（４） 
		IF (trim(both recCurKK_renkei.ITEM036) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM036::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.SHASAI_KANRI_CD4 = ''' || recCurKK_renkei.ITEM036 || '''';
			cFlg := ',';
		END IF;
		-- 社債管理会社（５） 
		IF (trim(both recCurKK_renkei.ITEM037) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM037::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.SHASAI_KANRI_CD5 = ''' || recCurKK_renkei.ITEM037 || '''';
			cFlg := ',';
		END IF;
		-- 社債管理会社（６） 
		IF (trim(both recCurKK_renkei.ITEM038) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM038::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.SHASAI_KANRI_CD6 = ''' || recCurKK_renkei.ITEM038 || '''';
			cFlg := ',';
		END IF;
		-- 社債管理会社（７） 
		IF (trim(both recCurKK_renkei.ITEM039) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM039::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.SHASAI_KANRI_CD7 = ''' || recCurKK_renkei.ITEM039 || '''';
			cFlg := ',';
		END IF;
		-- 社債管理会社（８） 
		IF (trim(both recCurKK_renkei.ITEM040) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM040::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.SHASAI_KANRI_CD8 = ''' || recCurKK_renkei.ITEM040 || '''';
			cFlg := ',';
		END IF;
		-- 社債管理会社（９） 
		IF (trim(both recCurKK_renkei.ITEM041) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM041::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.SHASAI_KANRI_CD9 = ''' || recCurKK_renkei.ITEM041 || '''';
			cFlg := ',';
		END IF;
		-- 社債管理会社（１０） 
		IF (trim(both recCurKK_renkei.ITEM042) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM042::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.SHASAI_KANRI_CD10 = ''' || recCurKK_renkei.ITEM042 || '''';
			cFlg := ',';
		END IF;
		-- 分割発行有無フラグ 
		IF (trim(both recCurKK_renkei.ITEM018) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM018::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.PARTHAKKO_UMU_FLG = ''' || recCurKK_renkei.ITEM018 || '''';
			cFlg := ',';
		END IF;
		-- 休日処理区分 
		IF (trim(both recCurKK_renkei.ITEM043) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM043::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.KYUJITSU_KBN = ''' || recCurKK_renkei.ITEM043 || '''';
			cFlg := ',';
		END IF;
		-- 利付割引区分 
		IF (trim(both recCurKK_renkei.ITEM044) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM044::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.RITSUKE_WARIBIKI_KBN = ''' || recCurKK_renkei.ITEM044 || '''';
			cFlg := ',';
		END IF;
		-- 利払期日（MD）（１） 
		IF (trim(both recCurKK_renkei.ITEM045) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM045::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.RBR_KJT_MD1 = ''' || recCurKK_renkei.ITEM045 || '''';
			cFlg := ',';
		END IF;
		-- 利払期日（MD）（２） 
		IF (trim(both recCurKK_renkei.ITEM046) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM046::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.RBR_KJT_MD2 = ''' || recCurKK_renkei.ITEM046 || '''';
			cFlg := ',';
		END IF;
		-- 利払期日（MD）（３） 
		IF (trim(both recCurKK_renkei.ITEM047) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM047::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.RBR_KJT_MD3 = ''' || recCurKK_renkei.ITEM047 || '''';
			cFlg := ',';
		END IF;
		-- 利払期日（MD）（４） 
		IF (trim(both recCurKK_renkei.ITEM048) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM048::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.RBR_KJT_MD4 = ''' || recCurKK_renkei.ITEM048 || '''';
			cFlg := ',';
		END IF;
		-- 利払期日（MD）（５） 
		IF (trim(both recCurKK_renkei.ITEM049) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM049::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.RBR_KJT_MD5 = ''' || recCurKK_renkei.ITEM049 || '''';
			cFlg := ',';
		END IF;
		-- 利払期日（MD）（６） 
		IF (trim(both recCurKK_renkei.ITEM050) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM050::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.RBR_KJT_MD6 = ''' || recCurKK_renkei.ITEM050 || '''';
			cFlg := ',';
		END IF;
		-- 利払期日（MD）（７） 
		IF (trim(both recCurKK_renkei.ITEM051) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM051::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.RBR_KJT_MD7 = ''' || recCurKK_renkei.ITEM051 || '''';
			cFlg := ',';
		END IF;
		-- 利払期日（MD）（８） 
		IF (trim(both recCurKK_renkei.ITEM052) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM052::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.RBR_KJT_MD8 = ''' || recCurKK_renkei.ITEM052 || '''';
			cFlg := ',';
		END IF;
		-- 利払期日（MD）（９） 
		IF (trim(both recCurKK_renkei.ITEM053) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM053::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.RBR_KJT_MD9 = ''' || recCurKK_renkei.ITEM053 || '''';
			cFlg := ',';
		END IF;
		-- 利払期日（MD）（１０） 
		IF (trim(both recCurKK_renkei.ITEM054) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM054::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.RBR_KJT_MD10 = ''' || recCurKK_renkei.ITEM054 || '''';
			cFlg := ',';
		END IF;
		-- 利払期日（MD）（１１） 
		IF (trim(both recCurKK_renkei.ITEM055) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM055::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.RBR_KJT_MD11 = ''' || recCurKK_renkei.ITEM055 || '''';
			cFlg := ',';
		END IF;
		-- 利払期日（MD）（１２） 
		IF (trim(both recCurKK_renkei.ITEM056) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM056::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.RBR_KJT_MD12 = ''' || recCurKK_renkei.ITEM056 || '''';
			cFlg := ',';
		END IF;
		-- 初回利払期日 
		IF (trim(both recCurKK_renkei.ITEM058) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM058::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.ST_RBR_KJT = ''' || recCurKK_renkei.ITEM058 || '''';
			cFlg := ',';
		END IF;
		-- 最終利払有無フラグ 
		IF (trim(both recCurKK_renkei.ITEM057) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM057::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.LAST_RBR_FLG = ''' || recCurKK_renkei.ITEM057 || '''';
			cFlg := ',';
		END IF;
		-- 利率 
		IF (trim(both recCurKK_renkei.ITEM059) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM059::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.RIRITSU = ''' || recCurKK_renkei.ITEM059 || '''';
			cFlg := ',';
		END IF;
		-- １通貨あたりの利子金額（初期） 
		IF (trim(both recCurKK_renkei.ITEM060) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM060::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.TSUKARISHI_KNGK_FAST = ''' || recCurKK_renkei.ITEM060 || '''';
			cFlg := ',';
		END IF;
		-- １通貨あたりの利子金額（通常） 
		IF (trim(both recCurKK_renkei.ITEM061) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM061::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.TSUKARISHI_KNGK_NORM = ''' || recCurKK_renkei.ITEM061 || '''';
			cFlg := ',';
		END IF;
		-- １通貨あたりの利子金額（終期） 
		IF (trim(both recCurKK_renkei.ITEM062) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM062::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.TSUKARISHI_KNGK_LAST = ''' || recCurKK_renkei.ITEM062 || '''';
			cFlg := ',';
		END IF;
		-- 満期償還期日 
		IF (trim(both recCurKK_renkei.ITEM069) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM069::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.FULLSHOKAN_KJT = ''' || recCurKK_renkei.ITEM069 || '''';
			cFlg := ',';
		END IF;
		-- コールオプション有無フラグ（全額償還） 
		IF (trim(both recCurKK_renkei.ITEM071) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM071::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.CALLALL_UMU_FLG = ''' || recCurKK_renkei.ITEM071 || '''';
			cFlg := ',';
		END IF;
		-- プットオプション有無フラグ 
		IF (trim(both recCurKK_renkei.ITEM076) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM076::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.PUTUMU_FLG = ''' || recCurKK_renkei.ITEM076 || '''';
			cFlg := ',';
		END IF;
		-- 特例社債フラグ 
		IF (trim(both recCurKK_renkei.ITEM092) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM092::text)) <> '') THEN
			gSql := gSql || cFlg || ' MG9.TOKUREI_SHASAI_FLG = ''' || recCurKK_renkei.ITEM092 || '''';
			cFlg := ',';
		END IF;
		-- 更新日時 
		gSql := gSql || cFlg || ' MG9.KOUSIN_DT = ''' || to_timestamp(pkDate.getCurrentTime(), 'YYYY-MM-DD HH24:MI:SS.US') || '''';
		cFlg := ',';
		-- 更新者 
		gSql := gSql || cFlg || ' MG9.KOUSIN_ID = ''' || USER_ID || '''';
    		gSql := gSql || ' WHERE MG9.ITAKU_KAISHA_CD = ''' || gItakuKaishaCd || ''''
    			 || ' AND MG9.MGR_CD = ''' || recCurKK_renkei.HYOJI_KOMOKU1 || '''';
		-- 更新実行 
		EXECUTE gSql;
		GET DIAGNOSTICS sqlCount = ROW_COUNT;
		--* CB銘柄機構基本更新 *
			gSql := '';		-- 初期化 
			cFlg := '';		-- 初期化 
			gSql := 'UPDATE CB_MGR_KIKO_KIHON WMG9 '
    			|| ' SET ';
		-- 新規変更取消区分 
		IF (trim(both recCurKK_renkei.ITEM005) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM005::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.SHNK_HNK_TRKSH_KBN = ''' || recCurKK_renkei.ITEM005 || '''';
			cFlg := ',';
		END IF;
		-- 機構銘柄コード 
		IF (trim(both recCurKK_renkei.ITEM001) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM001::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.KK_MGR_CD = ''' || recCurKK_renkei.ITEM001 || '''';
			cFlg := ',';
		END IF;
		-- 適用開始日 
		IF (trim(both recCurKK_renkei.ITEM003) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM003::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.TEKIYOST_YMD = ''' || recCurKK_renkei.ITEM003 || '''';
			cFlg := ',';
		END IF;
		-- 上場区分(東証) 
		IF (trim(both recCurKK_renkei.ITEM010) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM010::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.JOJO_KBN_TO = ''' || recCurKK_renkei.ITEM010 || '''';
			cFlg := ',';
		END IF;
		-- 上場区分(大証) 
		IF (trim(both recCurKK_renkei.ITEM011) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM011::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.JOJO_KBN_DA = ''' || recCurKK_renkei.ITEM011 || '''';
			cFlg := ',';
		END IF;
		-- 上場区分(名証) 
		IF (trim(both recCurKK_renkei.ITEM012) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM012::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.JOJO_KBN_ME = ''' || recCurKK_renkei.ITEM012 || '''';
			cFlg := ',';
		END IF;
		-- 上場区分(福証) 
		IF (trim(both recCurKK_renkei.ITEM013) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM013::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.JOJO_KBN_FU = ''' || recCurKK_renkei.ITEM013 || '''';
			cFlg := ',';
		END IF;
		-- 上場区分(札証) 
		IF (trim(both recCurKK_renkei.ITEM014) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM014::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.JOJO_KBN_SA = ''' || recCurKK_renkei.ITEM014 || '''';
			cFlg := ',';
		END IF;
		-- 上場区分(ジャスダック証) 
		IF (trim(both recCurKK_renkei.ITEM015) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM015::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.JOJO_KBN_JA = ''' || recCurKK_renkei.ITEM015 || '''';
			cFlg := ',';
		END IF;
		-- 償還価額 
		IF (trim(both recCurKK_renkei.ITEM070) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM070::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.SHOKAN_KAGAKU = ''' || recCurKK_renkei.ITEM070 || '''';
			cFlg := ',';
		END IF;
		-- 新株予約権の総数 
		IF (trim(both recCurKK_renkei.ITEM082) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM082::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.WRNT_TOTAL = ''' || recCurKK_renkei.ITEM082 || '''';
			cFlg := ',';
		END IF;
		-- 新株予約権の行使期間開始日 
		IF (trim(both recCurKK_renkei.ITEM083) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM083::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.WRNT_USE_ST_YMD = ''' || recCurKK_renkei.ITEM083 || '''';
			cFlg := ',';
		END IF;
		-- 新株予約権の行使期間終了日 
		IF (trim(both recCurKK_renkei.ITEM084) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM084::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.WRNT_USE_ED_YMD = ''' || recCurKK_renkei.ITEM084 || '''';
			cFlg := ',';
		END IF;
		-- 新株予約権の発行価額 
		IF (trim(both recCurKK_renkei.ITEM085) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM085::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.WRNT_HAKKO_KAGAKU = ''' || recCurKK_renkei.ITEM085 || '''';
			cFlg := ',';
		END IF;
		-- 新株予約権の行使価額 
		IF (trim(both recCurKK_renkei.ITEM086) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM086::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.WRNT_USE_KAGAKU = ''' || recCurKK_renkei.ITEM086 || '''';
			cFlg := ',';
		END IF;
		-- 行使請求受付場所 
		IF (trim(both recCurKK_renkei.ITEM087) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM087::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.USE_SEIKYU_UKE_BASHO = ''' || recCurKK_renkei.ITEM087 || '''';
			cFlg := ',';
		END IF;
		-- 取得条項有無フラグ 
		IF (trim(both recCurKK_renkei.ITEM088) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM088::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.SHTK_JK_UMU_FLG = ''' || recCurKK_renkei.ITEM088 || '''';
			cFlg := ',';
		END IF;
		-- 取得条項に係る取得日 
		IF (trim(both recCurKK_renkei.ITEM089) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM089::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.SHTK_JK_YMD = ''' || recCurKK_renkei.ITEM089 || '''';
			cFlg := ',';
		END IF;
		-- 取得対価(交付財産)の種類 
		IF (trim(both recCurKK_renkei.ITEM090) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM090::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.SHTK_TAIKA_SHURUI = ''' || recCurKK_renkei.ITEM090 || '''';
			cFlg := ',';
		END IF;
		-- 端数償還金有無フラグ 
		IF (trim(both recCurKK_renkei.ITEM091) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM091::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.HASU_SHOKAN_UMU_FLG = ''' || recCurKK_renkei.ITEM091 || '''';
			cFlg := ',';
		END IF;
		-- 社内処理用項目１ 
		IF (trim(both recCurKK_renkei.ITEM097) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM097::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.SHANAI_KOMOKU1 = ''' || recCurKK_renkei.ITEM097 || '''';
			cFlg := ',';
		END IF;
		-- 社内処理用項目２ 
		IF (trim(both recCurKK_renkei.ITEM098) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM098::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.SHANAI_KOMOKU2 = ''' || recCurKK_renkei.ITEM098 || '''';
			cFlg := ',';
		END IF;
		-- 機構元金手数料率 
		IF (trim(both recCurKK_renkei.ITEM093) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM093::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.KIKO_GANKIN_TESU_RITSU = ''' || recCurKK_renkei.ITEM093 || '''';
			cFlg := ',';
		END IF;
		-- 元金手数料率基準 
		IF (trim(both recCurKK_renkei.ITEM094) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM094::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.GNKN_TESU_RITSU_KIJUN = ''' || recCurKK_renkei.ITEM094 || '''';
			cFlg := ',';
		END IF;
		-- 機構利金手数料率 
		IF (trim(both recCurKK_renkei.ITEM095) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM095::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.KIKO_RIKIN_TESU_RITSU = ''' || recCurKK_renkei.ITEM095 || '''';
			cFlg := ',';
		END IF;
		-- 利金手数料率基準 
		IF (trim(both recCurKK_renkei.ITEM096) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM096::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.RKN_TESU_RITSU_KIJUN = ''' || recCurKK_renkei.ITEM096 || '''';
			cFlg := ',';
		END IF;
		-- 今回利払期日 
		IF (trim(both recCurKK_renkei.ITEM063) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM063::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.THIS_RBR_KJT = ''' || recCurKK_renkei.ITEM063 || '''';
			cFlg := ',';
		END IF;
		-- 今回利率 
		IF (trim(both recCurKK_renkei.ITEM064) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM064::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.THIS_RIRITSU = ''' || recCurKK_renkei.ITEM064 || '''';
			cFlg := ',';
		END IF;
		-- 今回１通貨あたりの利子金額 
		IF (trim(both recCurKK_renkei.ITEM065) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM065::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.THIS_TSUKARISHI_KNGK = ''' || recCurKK_renkei.ITEM065 || '''';
			cFlg := ',';
		END IF;
		-- 次回利払期日 
		IF (trim(both recCurKK_renkei.ITEM066) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM066::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.NEXT_RBR_KJT = ''' || recCurKK_renkei.ITEM066 || '''';
			cFlg := ',';
		END IF;
		-- 次回利率 
		IF (trim(both recCurKK_renkei.ITEM067) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM067::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.NEXT_RIRITSU = ''' || recCurKK_renkei.ITEM067 || '''';
			cFlg := ',';
		END IF;
		-- 次回１通貨あたりの利子金額 
		IF (trim(both recCurKK_renkei.ITEM068) IS NOT NULL AND (trim(both recCurKK_renkei.ITEM068::text)) <> '') THEN
			gSql := gSql || cFlg || ' WMG9.NEXT_TSUKARISHI_KNGK = ''' || recCurKK_renkei.ITEM068 || '''';
			cFlg := ',';
		END IF;
		-- 更新日時 
		gSql := gSql || cFlg || ' WMG9.KOUSIN_DT = ''' || to_timestamp(pkDate.getCurrentTime(), 'YYYY-MM-DD HH24:MI:SS.US') || '''';
		cFlg := ',';
		-- 更新者 
		gSql := gSql || cFlg || ' WMG9.KOUSIN_ID = ''' || USER_ID || '''';
    		gSql := gSql || ' WHERE WMG9.ITAKU_KAISHA_CD = ''' || gItakuKaishaCd || ''''
    			 || ' AND WMG9.MGR_CD = ''' || recCurKK_renkei.HYOJI_KOMOKU1 || '''';
		-- 更新実行 
		EXECUTE gSql;
		GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;

		sqlCount := sqlCount + ora2pg_rowcount;
		-- "訂正"且つ適用日が"99999999"の場合は累積テーブルは更新しない 
		-- *手数料率のみを変更した場合は機構連携テーブルのITEM003(適用日)に"99999999" 
		-- が設定される　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　 
		IF tekiyobi != '99999999' THEN
			--* 銘柄_基本累積（ＣＢ）更新 *		
			FOR recCurCB_ruiseki IN curCB_ruiseki LOOP
				UPDATE CB_MGR_KHN_RUISEKI
				   SET
						TEKIYOST_YMD = recCurCB_ruiseki.TEKIYOST_YMD,					-- 適用日
						KK_TSUCHI_YMD = pkDate.getGyomuYmd(),							-- 機構通知日
						SHNK_HNK_TRKSH_KBN = recCurCB_ruiseki.SHNK_HNK_TRKSH_KBN,    	-- 新規変更取消区分
						ISIN_CD = recCurCB_ruiseki.ISIN_CD,							    -- ＩＳＩＮコード
						HAKKODAIRI_CD = recCurCB_ruiseki.HAKKODAIRI_CD,				    -- 発行代理人コード
						SHRDAIRI_CD = recCurCB_ruiseki.SHRDAIRI_CD,    					-- 支払代理人コード
						SKN_KESSAI_CD = recCurCB_ruiseki.SKN_KESSAI_CD,    				-- 資金決済会社コード
						MGR_NM = recCurCB_ruiseki.MGR_NM,    							-- 銘柄の正式名称
						KK_HAKKOSHA_RNM = recCurCB_ruiseki.KK_HAKKOSHA_RNM,    			-- 機構発行者略称
						KAIGO_ETC = recCurCB_ruiseki.KAIGO_ETC,    						-- 回号等
						BOSHU_KBN = recCurCB_ruiseki.BOSHU_KBN,    						-- 募集区分
						SAIKEN_SHURUI = recCurCB_ruiseki.SAIKEN_SHURUI,    				-- 債券種類
						HOSHO_KBN = recCurCB_ruiseki.HOSHO_KBN,    						-- 保証区分
						TANPO_KBN = recCurCB_ruiseki.TANPO_KBN,    						-- 担保区分
						GODOHAKKO_FLG = recCurCB_ruiseki.GODOHAKKO_FLG,    				-- 合同発行フラグ
						RETSUTOKU_UMU_FLG = recCurCB_ruiseki.RETSUTOKU_UMU_FLG,    		-- 劣後特約有無フラグ
						SKNNZISNTOKU_UMU_FLG = recCurCB_ruiseki.SKNNZISNTOKU_UMU_FLG,   	-- 責任財産限定特約有無フラグ
						BOSHU_ST_YMD = recCurCB_ruiseki.BOSHU_ST_YMD,    				-- 募集開始日
						HAKKO_YMD = recCurCB_ruiseki.HAKKO_YMD,    						-- 発行年月日
						UCHIKIRI_HAKKO_FLG = recCurCB_ruiseki.UCHIKIRI_HAKKO_FLG,    	-- 打切発行フラグ
						HAKKO_TSUKA_CD = recCurCB_ruiseki.HAKKO_TSUKA_CD,    			-- 発行通貨
						KAKUSHASAI_KNGK = recCurCB_ruiseki.KAKUSHASAI_KNGK,    			-- 各社債の金額
						SHASAI_TOTAL = recCurCB_ruiseki.SHASAI_TOTAL,    				-- 社債の総額
						FULLSHOKAN_KJT = recCurCB_ruiseki.FULLSHOKAN_KJT,    			-- 満期償還期日
						CALLALL_UMU_FLG = recCurCB_ruiseki.CALLALL_UMU_FLG,    			-- コールオプション有無フラグ（全額償還）
						PUTUMU_FLG = recCurCB_ruiseki.PUTUMU_FLG,    					-- プットオプション有無フラグ
						PARTHAKKO_UMU_FLG = recCurCB_ruiseki.PARTHAKKO_UMU_FLG,   	 	-- 分割発行有無フラグ
						KYUJITSU_KBN = recCurCB_ruiseki.KYUJITSU_KBN,    				-- 休日処理区分
						RITSUKE_WARIBIKI_KBN = recCurCB_ruiseki.RITSUKE_WARIBIKI_KBN,   	-- 利付割引区分
						NENRBR_CNT = recCurCB_ruiseki.NENRBR_CNT,    					-- 年利払回数
						TOTAL_RBR_CNT = recCurCB_ruiseki.TOTAL_RBR_CNT,    				-- 総利払回数
						RBR_DD = recCurCB_ruiseki.RBR_DD,    							-- 利払日付
						ST_RBR_KJT = recCurCB_ruiseki.ST_RBR_KJT,    					-- 初回利払期日
						KK_ST_RBR_KJT = recCurCB_ruiseki.KK_ST_RBR_KJT,    				-- 機構_初回利払期日
						LAST_RBR_FLG = recCurCB_ruiseki.LAST_RBR_FLG,    				-- 最終利払有無フラグ
						RIRITSU = recCurCB_ruiseki.RIRITSU,    							-- 利率
						TSUKARISHI_KNGK_FAST = recCurCB_ruiseki.TSUKARISHI_KNGK_FAST,   	-- １通貨あたりの利子金額（初期）
						TSUKARISHI_KNGK_NORM = recCurCB_ruiseki.TSUKARISHI_KNGK_NORM,   	-- １通貨あたりの利子金額（通常）
						TSUKARISHI_KNGK_LAST = recCurCB_ruiseki.TSUKARISHI_KNGK_LAST,   	-- １通貨あたりの利子金額（終期）
						TSUKARISHI_KNGK_FAST_S = recCurCB_ruiseki.TSUKARISHI_KNGK_FAST_S,    -- １通貨あたりの利子金額（初期）算出値
						TSUKARISHI_KNGK_NORM_S = recCurCB_ruiseki.TSUKARISHI_KNGK_NORM_S,    -- １通貨あたりの利子金額（通常）算出値
						TSUKARISHI_KNGK_LAST_S = recCurCB_ruiseki.TSUKARISHI_KNGK_LAST_S,    -- １通貨あたりの利子金額（終期）算出値
						RBR_KJT_MD1 = recCurCB_ruiseki.RBR_KJT_MD1,    					-- 利払期日（MD）（１）
						RBR_KJT_MD2 = recCurCB_ruiseki.RBR_KJT_MD2,    					-- 利払期日（MD）（２）
						RBR_KJT_MD3 = recCurCB_ruiseki.RBR_KJT_MD3,    					-- 利払期日（MD）（３）
						RBR_KJT_MD4 = recCurCB_ruiseki.RBR_KJT_MD4,    					-- 利払期日（MD）（４）
						RBR_KJT_MD5 = recCurCB_ruiseki.RBR_KJT_MD5,    					-- 利払期日（MD）（５）
						RBR_KJT_MD6 = recCurCB_ruiseki.RBR_KJT_MD6,    					-- 利払期日（MD）（６）
						RBR_KJT_MD7 = recCurCB_ruiseki.RBR_KJT_MD7,    					-- 利払期日（MD）（７）
						RBR_KJT_MD8 = recCurCB_ruiseki.RBR_KJT_MD8,    					-- 利払期日（MD）（８）
						RBR_KJT_MD9 = recCurCB_ruiseki.RBR_KJT_MD9,    					-- 利払期日（MD）（９）
						RBR_KJT_MD10 = recCurCB_ruiseki.RBR_KJT_MD10,    				-- 利払期日（MD）（１０）
						RBR_KJT_MD11 = recCurCB_ruiseki.RBR_KJT_MD11,    				-- 利払期日（MD）（１１）
						RBR_KJT_MD12 = recCurCB_ruiseki.RBR_KJT_MD12,    				-- 利払期日（MD）（１２）
						KK_KANYO_FLG = recCurCB_ruiseki.KK_KANYO_FLG,    				-- 機構関与方式採用フラグ
						KOBETSU_SHONIN_SAIYO_FLG = recCurCB_ruiseki.KOBETSU_SHONIN_SAIYO_FLG,    -- 個別承認採用フラグ
						SHANAI_KOMOKU1 = recCurCB_ruiseki.SHANAI_KOMOKU1,    			-- 社内処理用項目１
						SHANAI_KOMOKU2 = recCurCB_ruiseki.SHANAI_KOMOKU2,    			-- 社内処理用項目２
						TOKUREI_SHASAI_FLG = recCurCB_ruiseki.TOKUREI_SHASAI_FLG,   		-- 特例社債フラグ
						KK_MGR_CD = recCurCB_ruiseki.KK_MGR_CD,    						-- 機構銘柄コード
						JOJO_KBN_TO = recCurCB_ruiseki.JOJO_KBN_TO ,    					-- 上場区分(東証)
						JOJO_KBN_DA = recCurCB_ruiseki.JOJO_KBN_DA,    					-- 上場区分(大証)
						JOJO_KBN_ME = recCurCB_ruiseki.JOJO_KBN_ME,    					-- 上場区分(名証)
						JOJO_KBN_FU = recCurCB_ruiseki.JOJO_KBN_FU,    					-- 上場区分(福証)
						JOJO_KBN_SA = recCurCB_ruiseki.JOJO_KBN_SA,    					-- 上場区分(札証)
						JOJO_KBN_JA = recCurCB_ruiseki.JOJO_KBN_JA,    					-- 上場区分(ジャスダック証)
						SHOKAN_PREMIUM = recCurCB_ruiseki.SHOKAN_PREMIUM,    			-- 償還プレミアム
						WRNT_TOTAL = recCurCB_ruiseki.WRNT_TOTAL,    					-- 新株予約権の総数
						WRNT_USE_KAGAKU_KETTEI_YMD = recCurCB_ruiseki.WRNT_USE_KAGAKU_KETTEI_YMD,    -- 新株予約権の行使価額決定日
						WRNT_USE_ST_YMD = recCurCB_ruiseki.WRNT_USE_ST_YMD,    			-- 新株予約権の行使期間開始日
						WRNT_USE_ED_YMD = recCurCB_ruiseki.WRNT_USE_ED_YMD,    			-- 新株予約権の行使期間終了日
						WRNT_HAKKO_KAGAKU = recCurCB_ruiseki.WRNT_HAKKO_KAGAKU,    		-- 新株予約権の発行価額
						WRNT_USE_KAGAKU = recCurCB_ruiseki.WRNT_USE_KAGAKU,    			-- 新株予約権の行使価額
						USE_SEIKYU_UKE_BASHO = recCurCB_ruiseki.USE_SEIKYU_UKE_BASHO,   	-- 行使請求受付場所
						WRNT_BIKO = recCurCB_ruiseki.WRNT_BIKO,    						-- 新株予約権に係る備考
						SHTK_JK_UMU_FLG = recCurCB_ruiseki.SHTK_JK_UMU_FLG,    			-- 取得条項有無フラグ
						SHTK_JK_YMD = recCurCB_ruiseki.SHTK_JK_YMD,    					-- 取得条項に係る取得日
						SHTK_TAIKA_SHURUI = recCurCB_ruiseki.SHTK_TAIKA_SHURUI,    		-- 取得対価(交付財産)の種類
						HASU_SHOKAN_UMU_FLG = recCurCB_ruiseki.HASU_SHOKAN_UMU_FLG,     	-- 端数償還金有無フラグ
						SHASAI_KANRI_CD1 = recCurCB_ruiseki.SHASAI_KANRI_CD1,    		-- 社債管理者（１）
						SHASAI_KANRI_CD2 = recCurCB_ruiseki.SHASAI_KANRI_CD2,    		-- 社債管理者（２）
						SHASAI_KANRI_CD3 = recCurCB_ruiseki.SHASAI_KANRI_CD3,    		-- 社債管理者（３）
						SHASAI_KANRI_CD4 = recCurCB_ruiseki.SHASAI_KANRI_CD4,    		-- 社債管理者（４）
						SHASAI_KANRI_CD5 = recCurCB_ruiseki.SHASAI_KANRI_CD5,   			-- 社債管理者（５）
						SHASAI_KANRI_CD6 = recCurCB_ruiseki.SHASAI_KANRI_CD6,    		-- 社債管理者（６）
						SHASAI_KANRI_CD7 = recCurCB_ruiseki.SHASAI_KANRI_CD7,    		-- 社債管理者（７）
						SHASAI_KANRI_CD8 = recCurCB_ruiseki.SHASAI_KANRI_CD8,    		-- 社債管理者（８）
						SHASAI_KANRI_CD9 = recCurCB_ruiseki.SHASAI_KANRI_CD9,    		-- 社債管理者（９）
						SHASAI_KANRI_CD10 = recCurCB_ruiseki.SHASAI_KANRI_CD10,    		-- 社債管理者（１０）
						KIKO_GANKIN_TESU_RITSU = recCurCB_ruiseki.KIKO_GANKIN_TESU_RITSU,-- 機構元金手数料率
						KIKO_RIKIN_TESU_RITSU = recCurCB_ruiseki.KIKO_RIKIN_TESU_RITSU,  -- 機構利金手数料率
						RKN_TESU_RITSU_KIJUN = recCurCB_ruiseki.RKN_TESU_RITSU_KIJUN,    -- 利金手数料率基準
						LAST_TEISEI_DT = to_timestamp(pkDate.getCurrentTime(), 'YYYY-MM-DD HH24:MI:SS.US'),    -- 最終訂正日時
						LAST_TEISEI_ID = USER_ID,    								-- 最終訂正者
						KOUSIN_ID = USER_ID    										-- 更新者
				 WHERE ITAKU_KAISHA_CD = gItakuKaishaCd
				   AND MGR_CD = recCurKK_renkei.HYOJI_KOMOKU1
				   AND KK_PHASE = 'M1'
				   AND SEQ_NO = '1';
				GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;

				sqlCount:= sqlCount +  ora2pg_rowcount;
			END LOOP;
		END IF;
	END LOOP;
	-- 銘柄機構基本・CB銘柄機構基本・CB銘柄機構基本累積各1件ずつ計3件更新される 
	IF sqlCount = 3 THEN
		rtn := pkconstant.success();
	-- 機構基本テーブル(SB・CB)が更新されていて且つ、適用日="99999999"の場合正常終了を返す 
	ELSIF sqlCount = 2 AND tekiyobi = '99999999' THEN
		rtn := pkconstant.success();
	ELSE
		-- 銘柄機構基本・CB銘柄機構基本に該当銘柄が存在しなかった場合 
		rtn := pkconstant.NO_DATA_FIND();	-- 対象データなし 
	END IF;
	RETURN;
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadw013s5111common_updatemeigara () FROM PUBLIC;
