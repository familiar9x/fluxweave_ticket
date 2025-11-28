CREATE OR REPLACE PROCEDURE spipx025k00r04 ( l_inUserId SUSER.USER_ID%TYPE, -- ユーザーID
 l_inItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE, -- 委託会社コード
 l_inKijunYmdFrom MGR_RBRKIJ.KKN_CHOKYU_YMD%TYPE, -- 基準日From
 l_inKijunYmdTo MGR_RBRKIJ.KKN_CHOKYU_YMD%TYPE, -- 基準日To
 l_inTsuchiYmd TEXT, -- 通知日
 l_inChohyoKbn TEXT, -- 帳票区分
 l_inGyomuYmd TEXT, -- 業務日付
 l_outSqlCode OUT integer, -- リターン値
 l_outSqlErrM OUT text -- エラーコメント
 ) AS $body$
DECLARE

	--
--	 * 著作権:Copyright(c)2016
--	 * 会社名:JIP
--	 * 概要　:画面から、特定振替機関等・適格口座管理機関の所轄税務署に係る通知書を作成する。
--	 *
--	 *	  @param l_inUserId	       IN  SUSER.USER_ID%TYPE			ユーザーID
--	 *	  @param l_inItakuKaishaCd    IN  MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE 	委託会社コード
--	 *	  @param l_inKijunYmdFrom     IN  MGR_RBRKIJ.KKN_CHOKYU_YMD%TYPE	基準日From
--	 *	  @param l_inKijunYmdTo       IN  MGR_RBRKIJ.KKN_CHOKYU_YMD%TYPE	基準日To
--	 *	  @param l_inTsuchiYmd        IN  TEXT	     				通知日
--	 *	  @param l_inChohyoKbn        IN  TEXT	     				帳票区分
--	 *	  @param l_inGyomuYmd         IN  TEXT	     				業務日付
--	 *	  @param l_outSqlCode         OUT INTEGER   				リターン値
--	 *	  @param l_outSqlErrM         OUT VARCHAR  				エラーコメント
--	 *
--	 *	  @returnなし
--	 *
--	 * @author Y.Nagano
--	 * @version $Id: SPIPX025K00R04.sql,v 1.00 2016/12/06 16:07:10 Y.Nagano Exp $
--	 
	--==============================================================================
	--                定数定義                                                      
	--==============================================================================
	REPORT_ID      CONSTANT char(11) := 'IPX30002441'; -- 特定振替機関等・適格口座管理機関の所轄税務署に係る通知書
	TSUCHI_YMD_DEF CONSTANT char(16) := '      年  月  日'; -- 平成10年10月10日
	--==============================================================================
	--                変数定義                                                      
	--==============================================================================
	gRtnCd 		   integer := pkconstant.success(); -- リターンコード
	gSeqNo 		   integer := 0; -- シーケンス
	gNo    		   integer := 0; -- NO
	gSQL		   varchar(10000) := NULL; -- SQL編集
	gWrkTsuchiYmd      varchar(16) := NULL; -- 通知日(西暦)
	aryBun		   pkIpaBun.BUN_ARRAY; -- 請求文章
	gAtena         	   text := NULL; -- 宛名
	gOutflg            integer := 0; -- 正常処理フラグ
	v_item             TYPE_SREPORT_WK_ITEM; -- アイテム用composite type
	--==============================================================================
	--                カーソル定義                                                  
	--==============================================================================
	curMeisai CURSOR FOR
	SELECT DISTINCT
		  VJ.KAIIN_ID AS ITAKU_KAISHA_CD
	 	, HKT.SFSK_POST_NO AS SFSK_POST_NO
		, HKT.ADD1 AS ADD1
		, HKT.ADD2 AS ADD2
		, HKT.ADD3 AS ADD3
		, HKT.HKT_NM AS HKT_NM
		, HKT.SFSK_BUSHO_NM AS SFSK_BUSHO_NM
		, VJ.BANK_NM AS BANK_NM_VJ
		, VJ.BUSHO_NM1 AS BUSHO_NM1
		, MKHN.MGR_NM AS MGR_NM
		, MKHN.ISIN_CD AS ISIN_CD
		, KKNS.SHR_YMD AS SHR_YMD
		, BNK.BANK_NM AS BANK_NM_BNK
		, KKNS.FINANCIAL_SECURITIES_KBN || KKNS.BANK_CD AS KANYUSHA_CD
		, BNKS.TOKIJO_DELEGATE_NM AS TOKIJO_DELEGATE_NM
		, MKHN.HKT_CD AS HKT_CD
		, HKT.KOZA_TEN_CD AS KOZA_TEN_CD
		, HKT.KOZA_TEN_CIFCD AS KOZA_TEN_CIFCD
	FROM kikin_seikyu kkns
LEFT OUTER JOIN mbank bnk ON (KKNS.FINANCIAL_SECURITIES_KBN = BNK.FINANCIAL_SECURITIES_KBN AND KKNS.BANK_CD = BNK.BANK_CD)
LEFT OUTER JOIN mbank_sfsk bnks ON (KKNS.ITAKU_KAISHA_CD = BNKS.ITAKU_KAISHA_CD AND KKNS.FINANCIAL_SECURITIES_KBN = BNKS.FINANCIAL_SECURITIES_KBN AND KKNS.BANK_CD = BNKS.BANK_CD AND '3' = BNKS.SFSK_SHURUI)
LEFT OUTER JOIN vjiko_itaku vj ON (KKNS.ITAKU_KAISHA_CD = VJ.KAIIN_ID)
LEFT OUTER JOIN mgr_kihon_view mkhn ON (KKNS.ITAKU_KAISHA_CD = MKHN.ITAKU_KAISHA_CD AND KKNS.MGR_CD = MKHN.MGR_CD)
LEFT OUTER JOIN mhakkotai hkt ON (MKHN.ITAKU_KAISHA_CD = HKT.ITAKU_KAISHA_CD AND MKHN.HKT_CD = HKT.HKT_CD)
WHERE KKNS.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND KKNS.SHR_YMD >= l_inKijunYmdFrom AND KKNS.SHR_YMD <= l_inKijunYmdTo AND KKNS.TAX_KBN IN ('80','81') AND MKHN.SAIKEN_SHURUI <> '10' AND MKHN.MGR_STAT_KBN <> '0' ORDER BY
		  VJ.KAIIN_ID
		, KKNS.SHR_YMD
		, HKT.KOZA_TEN_CD
		, KOZA_TEN_CIFCD
		, MKHN.ISIN_CD
		, KKNS.FINANCIAL_SECURITIES_KBN || KKNS.BANK_CD;
--==============================================================================
--                メイン処理                                                       
--==============================================================================
BEGIN
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inUserId)::text, '') = '' OR coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' OR coalesce(trim(both l_inKijunYmdFrom)::text, '') = '' OR
	   coalesce(trim(both l_inKijunYmdTo)::text, '') = '' OR coalesce(trim(both l_inChohyoKbn)::text, '') = '' OR coalesce(trim(both l_inGyomuYmd)::text, '') = '' THEN
		-- パラメータエラー
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', REPORT_ID, 'SQLERRM:' || '');
		RETURN;
	END IF;
	-- 通知日(西暦)
	IF (trim(both l_inTsuchiYmd) IS NOT NULL AND (trim(both l_inTsuchiYmd))::text <> '') THEN
		gWrkTsuchiYmd := pkDate.seirekiChangeSuppressNenGappi(l_inTsuchiYmd);
	ELSE
		gWrkTsuchiYmd := TSUCHI_YMD_DEF;
	END IF;
	  -- 請求文章取得
	  aryBun := SPIPX025K00R04_createBun(REPORT_ID, '00');
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
		WHERE KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = l_inGyomuYmd
		AND CHOHYO_ID = REPORT_ID;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd,
			     l_inUserId,
			     l_inChohyoKbn,
			     l_inGyomuYmd,
			     REPORT_ID);
	-- データ取得
	FOR recMeisai IN curMeisai LOOP
		-- 宛名編集
		CALL pkIpaName.getMadoFutoAtenaYoko(recMeisai.HKT_NM, recMeisai.SFSK_BUSHO_NM, gOutflg, gAtena);
		-- シーケンスアップ
		gSeqNo := gSeqNo + 1;
		
		-- Clear composite type
		v_item := ROW(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL)::TYPE_SREPORT_WK_ITEM;
		
		-- Set item values
		v_item.l_inItem001 := gWrkTsuchiYmd; 			-- 通知日
		v_item.l_inItem002 := recMeisai.ITAKU_KAISHA_CD; 	-- 委託会社コード
		v_item.l_inItem003 := recMeisai.SFSK_POST_NO; 		-- 送付先郵便番号
		v_item.l_inItem004 := recMeisai.ADD1;			-- 送付先住所１
		v_item.l_inItem005 := recMeisai.ADD2;			-- 送付先住所２
		v_item.l_inItem006 := recMeisai.ADD3;			-- 送付先住所３
		v_item.l_inItem007 := gAtena; 				-- 発行体名称(御中込)
		v_item.l_inItem008 := recMeisai.BANK_NM_VJ; 		-- 金融機関名称
		v_item.l_inItem009 := recMeisai.BUSHO_NM1;		-- 担当部署名称
		v_item.l_inItem010 := aryBun[1];			-- 請求文章１
		v_item.l_inItem011 := aryBun[2];			-- 請求文章２
		v_item.l_inItem012 := aryBun[3];			-- 請求文章３
		v_item.l_inItem013 := aryBun[4];			-- 請求文章４
		v_item.l_inItem014 := aryBun[5];			-- 請求文章５
		v_item.l_inItem015 := aryBun[6];			-- 請求文章６
		v_item.l_inItem016 := aryBun[7];			-- 請求文章７
		v_item.l_inItem017 := recMeisai.MGR_NM; 		-- 銘柄の正式名称
		v_item.l_inItem018 := recMeisai.ISIN_CD; 		-- ＩＳＩＮコード
		v_item.l_inItem019 := recMeisai.SHR_YMD; 		-- 支払日
		v_item.l_inItem020 := recMeisai.BANK_NM_BNK; 		-- 金融機関名称
		v_item.l_inItem021 := recMeisai.KANYUSHA_CD; 		-- 機構加入者コード
		v_item.l_inItem022 := recMeisai.TOKIJO_DELEGATE_NM; 	-- 税務署名称
		v_item.l_inItem023 := recMeisai.HKT_CD; 		-- 発行体コード
		v_item.l_inItem024 := recMeisai.KOZA_TEN_CD; 		-- 口座店コード
		v_item.l_inItem025 := recMeisai.KOZA_TEN_CIFCD; 	-- 口座店ＣＩＦコード
		
		-- 帳票ワークへデータを追加
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd,
			l_inUserId     => l_inUserId,
			l_inChohyoKbn  => l_inChohyoKbn,
			l_inSakuseiYmd => l_inGyomuYmd,
			l_inChohyoId   => REPORT_ID,
			l_inSeqNo      => gSeqNo,
			l_inHeaderFlg  => '1',
			l_inItem       => v_item,
			l_inKousinId   => l_inUserId,
			l_inSakuseiId  => l_inUserId
		);
	END LOOP;
	IF gSeqNo = 0 THEN
		-- 対象データなし
		gRtnCd := pkconstant.NO_DATA_FIND();
		
		-- Clear composite type
		v_item := ROW(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
		              NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL)::TYPE_SREPORT_WK_ITEM;
		
		-- Set item values
		v_item.l_inItem001 := gWrkTsuchiYmd;	-- 通知日
		v_item.l_inItem010 := aryBun[1];	-- 請求文章１
		v_item.l_inItem011 := aryBun[2];	-- 請求文章２
		v_item.l_inItem012 := aryBun[3];	-- 請求文章３
		v_item.l_inItem013 := aryBun[4];	-- 請求文章４
		v_item.l_inItem014 := aryBun[5];	-- 請求文章５
		v_item.l_inItem015 := aryBun[6];	-- 請求文章６
		v_item.l_inItem016 := aryBun[7];	-- 請求文章７
		v_item.l_inItem017 := '対象データなし';	-- 対象データ
		
		-- 帳票ワークへデータを追加
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd,
			l_inUserId     => l_inUserId,
			l_inChohyoKbn  => l_inChohyoKbn,
			l_inSakuseiYmd => l_inGyomuYmd,
			l_inChohyoId   => REPORT_ID,
			l_inSeqNo      => 1,
			l_inHeaderFlg  => '1',
			l_inItem       => v_item,
			l_inKousinId   => l_inUserId,
			l_inSakuseiId  => l_inUserId
		);
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
  -- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLERRM:' || SQLERRM);
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;

CREATE OR REPLACE FUNCTION spipx025k00r04_createbun ( l_in_ReportID TEXT, l_in_PatternCd BUN.BUN_PATTERN_CD%TYPE) RETURNS PKIPABUN.BUN_ARRAY AS $body$
DECLARE

	-- 請求文章(ワーク)
	aryBunWk pkIpaBun.BUN_ARRAY;

BEGIN
-- 請求文章の取得
aryBunWk := pkIpaBun.getBun(l_in_ReportID, l_in_PatternCd);
RETURN aryBunWk;
EXCEPTION
WHEN OTHERS THEN
	RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
