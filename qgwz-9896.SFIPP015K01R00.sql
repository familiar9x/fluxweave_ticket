




CREATE OR REPLACE PROCEDURE insertkikinseikyu () AS $body$
DECLARE

		errMessage    typeMessage;

BEGIN
       gInsertCnt := gInsertCnt + 1;
	        INSERT INTO KIKIN_SEIKYU(
	            ITAKU_KAISHA_CD,
	            MGR_CD,
	            SHR_YMD,
	            TSUKA_CD,
	            FINANCIAL_SECURITIES_KBN,
	            BANK_CD,
	            KOZA_KBN,
	            TAX_KBN,
	            GZEIHIKI_BEF_CHOKYU_KNGK,
	            GZEI_KNGK,
	            GZEIHIKI_AFT_CHOKYU_KNGK,
	            SHOKAN_SEIKYU_KNGK,
	            AITE_SKN_KESSAI_BCD,
	            AITE_SKN_KESSAI_SCD,
	            KESSAI_NO,
	            KOBETSU_SHONIN_SAIYO_FLG,
	            KK_KANYO_UMU_FLG,
	            DVP_KBN,
	            GNR_ZNDK,
	            MASSHO_STATE,
	            SHORI_KBN,
	            KOUSIN_ID,
	            SAKUSEI_DT,
	            SAKUSEI_ID)
	        VALUES (
	            key.gItakuKaishaCd,
	            key.gMgrCd,
	            gShrYmd,
	            DEFAULT_TSUKA_CD,
	            key.gFinancialSecuritiesKbn,
	            key.gBankCd,
	            key.gKozaKbn,
	            TAX_KBN,
	            summry.gGzeihikiBefChokyu_kngk,
	            summry.gGzeiKngk,
	            summry.gZeihikiAftKngk,
	            summry.gShokanSeikyuKngk,
	            key.gAiteSknKessaiBcd,
	            key.gAiteSknKessaiScd,
	            DEFAULT_SPACE,
	            KOBETSU_SHONIN_HIKANYO,
	            KK_KANYO_FLG_HIKANYO,
	            DVP_KBN_NOT_DVP,
	            summry.gGnrZndk,
	            MASSHO_STATE,
	            gShrKbn,
	            USER_ID,
	            gTimeStamp,
	            USER_ID
	            );
 --元利金請求明細２
  INSERT INTO KIKIN_SEIKYU2(
              ITAKU_KAISHA_CD,
              MGR_CD,
              SHR_YMD,
              TSUKA_CD,
              FINANCIAL_SECURITIES_KBN,
              BANK_CD,
              KOZA_KBN,
              TAX_KBN,
              KNJ_FLG,
              GZEIHIKI_BEF_CHOKYU_KNGK,
              GZEI_KNGK,
              GZEIHIKI_AFT_CHOKYU_KNGK,
              SHOKAN_SEIKYU_KNGK,
              AITE_SKN_KESSAI_BCD,
              AITE_SKN_KESSAI_SCD,
              KESSAI_NO,
              KOBETSU_SHONIN_SAIYO_FLG,
              KK_KANYO_UMU_FLG,
              DVP_KBN,
              GNR_ZNDK,
              SHORI_KBN,
              KOUSIN_ID,
              SAKUSEI_DT,
              SAKUSEI_ID)
		VALUES (
              key.gItakuKaishaCd,
	            key.gMgrCd,
	            gShrYmd,
	            DEFAULT_TSUKA_CD,
	            key.gFinancialSecuritiesKbn,
	            key.gBankCd,
	            key.gKozaKbn,
	            TAX_KBN,
	            KNJ_FLG,
	            summry.gGzeihikiBefChokyu_kngk,
	            summry.gGzeiKngk,
	            summry.gZeihikiAftKngk,
	            summry.gShokanSeikyuKngk,
	            key.gAiteSknKessaiBcd,
	            key.gAiteSknKessaiScd,
	            DEFAULT_SPACE,
	            KOBETSU_SHONIN_HIKANYO,
	            KK_KANYO_FLG_HIKANYO,
	            DVP_KBN_NOT_DVP,
	            summry.gGnrZndk,
	            gShrKbn,
	            USER_ID,
	            gTimeStamp,
	            USER_ID
			);
    EXCEPTION
        WHEN OTHERS THEN
			-- エラーの詳細情報をセット
			errMessage := typeMessage();
			errMessage := array_append(errMessage, null);
			errMessage(errMessage.count) := typeMessageRecord('委託会社コード： ' || key.gItakuKaishaCd);
			errMessage := array_append(errMessage, null);
			errMessage(errMessage.count) := typeMessageRecord('銘柄コード： ' || key.gMgrCd);
			errMessage := array_append(errMessage, null);
			errMessage(errMessage.count) := typeMessageRecord('支払日： ' || gShrYmd);
			errMessage := array_append(errMessage, null);
			errMessage(errMessage.count) := typeMessageRecord('通貨コード： ' || DEFAULT_TSUKA_CD);
			errMessage := array_append(errMessage, null);
			errMessage(errMessage.count) := typeMessageRecord('金融証券区分： ' || key.gFinancialSecuritiesKbn);
			errMessage := array_append(errMessage, null);
			errMessage(errMessage.count) := typeMessageRecord('金融機関コード： ' || key.gBankCd);
			errMessage := array_append(errMessage, null);
			errMessage(errMessage.count) := typeMessageRecord('口座区分： ' || key.gKozaKbn);
			errMessage := array_append(errMessage, null);
			errMessage(errMessage.count) := typeMessageRecord('税区分： ' || TAX_KBN);
            pkLog.error('ECM321',SP_ID, errMessage);
            RAISE;
    END;
/*====================================================================*
   		メイン
 *====================================================================*/
BEGIN
  pkLog.debug(USER_ID,SP_ID,'機構非関与銘柄元利金請求データ（実質記番号方式）作成 START');
	/* 共通関数より、業務日付+2営業日の取得（支払日取得） */

	gShrYmd := pkDate.getPlusDateBusiness(pkDate.getGyomuYmd(),2);
--  pkLog.debug(USER_ID,SP_ID,'利払日（支払日）   : ' || gShrYmd);
    /* 支払日1日前取得 */

	gBefShrYmd := pkDate.getMinusDate(gShrYmd, 1);
--  pkLog.debug(USER_ID,SP_ID,'利払日（支払日）前日: ' || gBefShrYmd);
    FOR rSeikyu IN cSeikyu LOOP
--    pkLog.debug(USER_ID,SP_ID,'銘柄コード：'  ||rSeikyu.MGR_CD );
		--キーブレイク処理
		IF key.gItakuKaishaCd <> rSeikyu.ITAKU_KAISHA_CD
		OR key.gMgrCd <> rSeikyu.MGR_CD
		OR key.gKozaKbn <>rSeikyu.KOZA_KBN THEN
--    pkLog.debug(USER_ID,SP_ID,'【キーブレイク】');
--    pkLog.debug(USER_ID,SP_ID,'委託会社コード：' || key.gItakuKaishaCd || ' <> ' || rSeikyu.ITAKU_KAISHA_CD );
--    pkLog.debug(USER_ID,SP_ID,'銘柄コード：'  ||rSeikyu.MGR_CD );
--    pkLog.debug(USER_ID,SP_ID,'口座区分     ：' || key.gKozaKbn || '    <> ' || rSeikyu.KOZA_KBN );
--    pkLog.debug(USER_ID,SP_ID,' ');
 			IF gRecCnt > 0 THEN
--      pkLog.debug(USER_ID,SP_ID, gRecCnt|| 'レコード目（集約前）');
				--請求データ登録
				CALL insertKikinSeikyu();
--         pkLog.debug(USER_ID,SP_ID,'明細登録件数： ' || gInsertCnt);
--         pkLog.debug(USER_ID,SP_ID,'');
--        pkLog.debug(USER_ID,SP_ID,'レコード件数： ' || gRecCnt);
--        pkLog.debug(USER_ID,SP_ID,'請求データ登録');
  			--カウントクリア
  			gRecCNt := 0;
			END IF;
			--キー情報セット
			key.gItakuKaishaCd := rSeikyu.ITAKU_KAISHA_CD;
			key.gMgrCd := rSeikyu.MGR_CD;
			key.gFinancialSecuritiesKbn := rSeikyu.FINANCIAL_SECURITIES_KBN;
			key.gBankCd := rSeikyu.BANK_CD;
			key.gKozaKbn := rSeikyu.KOZA_KBN;
			key.gAiteSknKessaiBcd := SUBSTR(rSeikyu.SKN_KESSAI_CD,1,4);
			key.gAiteSknKessaiScd := SUBSTR(rSeikyu.SKN_KESSAI_CD,5,3);
			--集計エリアクリア
			summry.gGzeihikiBefChokyu_kngk := 0;
			summry.gGzeiKngk := 0;
			summry.gZeihikiAftKngk := 0;
			summry.gShokanSeikyuKngk := 0;
			summry.gGnrZndk := 0;
		END IF;
		--取引先別税額取得処理
--      pkLog.debug(USER_ID,SP_ID,'【取引先別税額取得処理】 ');
--    pkLog.debug(USER_ID,SP_ID,'Pkipakibango.calcZeigaku(' || rSeikyu.ITAKU_KAISHA_CD || ',' || rSeikyu.MGR_CD || ',' || rSeikyu.RBR_KJT || ',' || gBefShrYmd || ',' || rSeikyu.TRHK_CD || ')' );
--    pkLog.debug(USER_ID,SP_ID,' ');
		IF Pkipakibango.calcZeigaku(
                              rSeikyu.ITAKU_KAISHA_CD
                            , rSeikyu.MGR_CD
                            , rSeikyu.RBR_KJT
                            , gBefShrYmd
                            , rSeikyu.TRHK_CD
		                        , calcZei.gZeihikiBefKngk
		                        , calcZei.gZeihikiAftKngk
		                        , calcZei.gKokuZeiKngk
		                        , calcZei.gChihoZeiKngk
		                        , calcZei.gErrMessage)
    --取引先別税額取得 ≠ 0　の場合　集計エリアクリア
        <> pkconstant.success() THEN
                              calcZei.gZeihikiBefKngk := 0;
                              calcZei.gZeihikiAftKngk := 0;
                              calcZei.gKokuZeiKngk := 0;
                              calcZei.gChihoZeiKngk := 0;
		END IF;
--      pkLog.debug(USER_ID,SP_ID,'【サマリ前国税関連請求金額】 ');
--      pkLog.debug(USER_ID,SP_ID,'国税引前利金請求額=' || summry.gGzeihikiBefChokyu_kngk);
--      pkLog.debug(USER_ID,SP_ID,'国税引後利金請求額=' || summry.gZeihikiAftKngk);
--      pkLog.debug(USER_ID,SP_ID,'国税額=' || summry.gGzeiKngk);
--    pkLog.debug(USER_ID,SP_ID,' ');
		--取引先別元金額取得処理
--      pkLog.debug(USER_ID,SP_ID,'【取引先別元金額取得処理】 ');
--      pkLog.debug(USER_ID,SP_ID,'pkipakibango.getGankinTrhk(' || rSeikyu.ITAKU_KAISHA_CD || ',' || rSeikyu.MGR_CD || ',' || gShrYmd || ',' || rSeikyu.TRHK_CD || ')' );
      calcZei.gShokanSeikyuKngk := pkipakibango.getGankinTrhk(rSeikyu.ITAKU_KAISHA_CD, rSeikyu.MGR_CD, gShrYmd, rSeikyu.TRHK_CD);
--      pkLog.debug(USER_ID,SP_ID,'償還金請求額=' || calcZei.gShokanSeikyuKngk);
--    pkLog.debug(USER_ID,SP_ID,' ');
		--取引先別振替債基準残高取得処理
--      pkLog.debug(USER_ID,SP_ID,'【取引先別振替債基準残高取得処理】');
--      pkLog.debug(USER_ID,SP_ID,'pkipakibango.getKjnZndkTrhk(' || rSeikyu.ITAKU_KAISHA_CD || ',' || rSeikyu.MGR_CD || ',' || gBefShrYmd || ',' || rSeikyu.TRHK_CD || ')' );
  		calcZei.gGnrZndk := pkipakibango.getKjnZndkTrhk(rSeikyu.ITAKU_KAISHA_CD, rSeikyu.MGR_CD, gBefShrYmd, rSeikyu.TRHK_CD);
--      pkLog.debug(USER_ID,SP_ID,'元利払対象残高=' || calcZei.gGnrZndk);
--    pkLog.debug(USER_ID,SP_ID,' ');
		--集計処理
		summry.gGzeihikiBefChokyu_kngk := summry.gGzeihikiBefChokyu_kngk + calcZei.gZeihikiBefKngk;
		summry.gGzeiKngk := summry.gGzeiKngk + calcZei.gKokuZeiKngk;
		summry.gZeihikiAftKngk := summry.gZeihikiAftKngk + (calcZei.gZeihikiBefKngk - calcZei.gKokuZeiKngk);
		summry.gShokanSeikyuKngk := summry.gShokanSeikyuKngk + calcZei.gShokanSeikyuKngk;
		summry.gGnrZndk := summry.gGnrZndk + calcZei.gGnrZndk;
		--処理区分設定
		IF rSeikyu.OSAE_KNGK > 0 THEN
			gShrKbn := '0';
		ELSE
			gShrKbn := '1';
		END IF;
		--レコード件数カウント
		gRecCnt := gRecCnt + 1;
    END LOOP;
		IF gRecCnt > 0 THEN
			--請求データ登録
--      pkLog.debug(USER_ID,SP_ID,'【登録時請求額】');
--      pkLog.debug(USER_ID,SP_ID,'国税引前利金請求額=' || summry.gGzeihikiBefChokyu_kngk);
--      pkLog.debug(USER_ID,SP_ID,'国税引後利金請求額=' || summry.gZeihikiAftKngk);
--      pkLog.debug(USER_ID,SP_ID,'国税額=' || summry.gGzeiKngk);
--    pkLog.debug(USER_ID,SP_ID,' ');
			CALL insertKikinSeikyu();
--      pkLog.debug(USER_ID,SP_ID,'明細登録件数： ' || gInsertCnt);
--      pkLog.debug(USER_ID,SP_ID,'最終データ登録');
		END IF;
--    IF gInsertCnt < 1 THEN
--    pkLog.debug(USER_ID,SP_ID,'登録件数：' || gInsertCnt);
--    END IF;
    result := pkconstant.success();
    pkLog.debug(USER_ID,SP_ID,'機構非関与銘柄元利金請求データ作成（実質記番号方式） END result' || result);
	RETURN result;
/*====================================================================*
    異常終了 出口
 *====================================================================*/
EXCEPTION
	WHEN OTHERS THEN
		pkLog.fatal('ECM701', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE insertkikinseikyu () FROM PUBLIC;