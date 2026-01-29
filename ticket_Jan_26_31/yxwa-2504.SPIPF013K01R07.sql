




CREATE OR REPLACE PROCEDURE spipf013k01r07 ( l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inUserId TEXT,		-- ユーザーID
 l_inChohyoKbn TEXT,		-- 帳票区分
 l_inGyomuYmd TEXT,		-- 業務日付
 l_inShoriYmd TEXT,		-- 処理日付
 l_outSqlCode INOUT integer,		-- リターン値
 l_outSqlErrM INOUT text	-- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 受渡状況確認リスト（発行代り金）を作成する
-- * 
-- * @author 渡邊　かよ
-- * @version $Revision: 1.6 $
-- * 
-- * @param 
-- * 　　　 l_inUserId			IN	TEXT		ユーザーID
-- * 　　　 l_inChohyoKbn			IN	TEXT		帳票区分
-- * 　　　 l_inGyomuYmd			IN	TEXT		業務日付
-- *        l_inShoriYmd                  IN	TEXT		処理日付
-- * 　　　 l_outSqlCode			OUT	INTEGER		リターン値
-- * 　　　 l_outSqlErrM			OUT	VARCHAR	エラーコメント
-- * @return INTEGER 0:正常
-- *                 1:予期したエラー
-- *                 40:データなし
-- *                 99:予期せぬエラー
-- 
--**************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.07.13	JIP				新規作成
--/*
--/*
--***************************************************************************
--
--==============================================================================
--					デバッグ機能													
--==============================================================================
	DEBUG	numeric(1)	:= 0;
--==============================================================================
--					定数定義													
--==============================================================================
	RTN_OK				CONSTANT integer	:= 0;					-- 正常
	RTN_NG				CONSTANT integer	:= 1;					-- 予期したエラー
	RTN_NODATA			CONSTANT integer	:= 40;					-- データなし
	RTN_FATAL			CONSTANT integer	:= 99;					-- 予期せぬエラー
	REPORT_ID				CONSTANT text	:= 'IPF30101321';				-- 帳票ID
--==============================================================================
--					変数定義				
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd				integer :=	RTN_OK;						-- リターンコード
	gSeqNo				integer := 0;						-- シーケンス
	ncount                          numeric;                                                         -- レコード件数（帳票ワーク）
	vItakuKaishaRnm                 varchar(100);                                                  -- 委託会社名略称
	gSeqNo2				integer := 0;						-- 発行日合計件数
	gKingaku			numeric	:= 0;						-- 発行日合計金額
--==============================================================================
--					カーソル定義        			
--==============================================================================
	curMeisai CURSOR FOR
		SELECT	FS21.KNJ_SHORI_YMD,								-- 発行年月日
			FS21.KNJ_INOUT_KBN,							        -- 入出金状況
			MCD1.CODE_RNM AS KNJ_INOUT_RNM,							-- 入出金状況名称
			FS21.KNJ_ERR_CODE,								-- エラーコード
			FS21.KNJ_UKE_TSUBAN,								-- 受付通番
			FS21.KNJ_UKE_TSUBAN_ZENKAI,							-- 前回受付通番
                        FS21.KNJ_AZUKE_NO,                                                              -- 預入番号（勘定系）
                        M01.HKT_CD,                                                                     -- 発行体コード
                        M01.HKT_RNM,                                                                    -- 発行体略名
                        M01.KOZA_TEN_CD,                                                                -- 口座店コード
                        M01.KOZA_TEN_CIFCD,                                                             -- 口座店ＣＩＦコード
                        MG1.ISIN_CD,                                                                    -- ＩＳＩＮコード
                        FS21.MGR_CD,                                                                    -- 銘柄コード
                        MG1.MGR_RNM,                                                                    -- 銘柄略称
                        MG1.SHASAI_TOTAL,                                                               -- 社債の総額
                        FS21.KNJ_HRKM_KNGK,                                                             -- 差引後払込金額
                        FS21.KNJ_TEN_NO,                                                                -- 口座店コード
                        MCD2.CODE_RNM AS KNJ_KOZA__KAMOKU,                                              -- 口座科目名称
                        FS21.KNJ_KOUZA_NO,                                                              -- 口座番号
                        M04.BUTEN_RNM                                                                    -- 部店略称
		FROM mgr_kihon mg1, mbuten m04, mhakkotai m01, knjhakkouif fs21
LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = 'S10') mcd1 ON (FS21.KNJ_INOUT_KBN = MCD1.CODE_VALUE)
LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = 'S11') mcd2 ON (FS21.KNJ_KAMOKU = MCD2.CODE_VALUE)
WHERE FS21.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND FS21.KNJ_SHORI_YMD = l_inShoriYmd AND FS21.KNJ_SHORI_KBN = '1' AND MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND MG1.MGR_CD = FS21.MGR_CD AND M01.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND MG1.HKT_CD = M01.HKT_CD   AND FS21.ITAKU_KAISHA_CD = M04.ITAKU_KAISHA_CD AND FS21.KNJ_TEN_NO = M04.BUTEN_CD ORDER BY KNJ_INOUT_KBN,KNJ_ERR_CODE DESC,KNJ_UKE_TSUBAN,HKT_CD,ISIN_CD;
	
--==============================================================================
--	メイン処理																	    
--==============================================================================
BEGIN
--	制作時、ログを出力する。パッケージ使用		
	IF DEBUG = 1 THEN	
	CALL pkLog.debug(l_inUserId, REPORT_ID, 'IPF013K01R07 START');	
	END IF;
	-- 入力パラメタ(委託会社コード)のチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF013K01R07', '＜項目名称:委託会社コード＞'||'＜項目値:'||l_inItakuKaishaCd||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(ユーザＩＤ)のチェック
	IF coalesce(trim(both l_inUserId)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF013K01R07', '＜項目名称:ユーザＩＤ＞'||'＜項目値:'||l_inUserId||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(帳票区分)のチェック
	IF coalesce(trim(both l_inChohyoKbn)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF013K01R07', '＜項目名称:帳票区分＞'||'＜項目値:'||l_inChohyoKbn||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(業務日付)のチェック
	IF coalesce(trim(both l_inGyomuYmd)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF013K01R07', '＜項目名称:業務日付＞'||'＜項目値:'||l_inGyomuYmd||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(処理日付)のチェック
	IF coalesce(trim(both l_inShoriYmd)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF013K01R07', '＜項目名称:処理日付＞'||'＜項目値:'||l_inShoriYmd||'＞');
		RETURN;
	END IF;
	-- 帳票ワークの削除
        IF l_inChohyoKbn = '0' THEN
	        DELETE
                FROM	SREPORT_WK SC16
	        WHERE	SC16.KEY_CD = l_inItakuKaishaCd
	          AND	SC16.USER_ID = l_inUserId
	          AND	SC16.CHOHYO_KBN = l_inChohyoKbn
	          AND	SC16.SAKUSEI_YMD = l_inGyomuYmd
	          AND	SC16.CHOHYO_ID = REPORT_ID;
        END IF;
	-- ヘッダーレコードを追加
        SELECT
                COUNT(*)
        INTO STRICT
                ncount
        FROM
                SREPORT_WK SC16
	WHERE	SC16.KEY_CD = l_inItakuKaishaCd
	  AND	SC16.USER_ID = l_inUserId
	  AND	SC16.CHOHYO_KBN = l_inChohyoKbn
	  AND	SC16.SAKUSEI_YMD = l_inGyomuYmd
	  AND	SC16.CHOHYO_ID = REPORT_ID
          AND   SC16.HEADER_FLG = 0;
        IF ncount = 0 THEN
	        CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
        END IF;
	-- 委託会社略称を設定
	nCount := 0;
	SELECT count(*)
	INTO STRICT nCount
	FROM vjiko_itaku
	WHERE kaiin_id = l_inItakuKaishaCd
	AND jiko_daiko_kbn = '2';
	IF nCount = 0 THEN
		vItakuKaishaRnm := NULL;
	ELSE
		SELECT bank_rnm
		INTO STRICT vItakuKaishaRnm
		FROM vjiko_itaku
		WHERE kaiin_id = l_inItakuKaishaCd
		AND jiko_daiko_kbn = '2';
	END IF;
	-- デ−タ取得
	FOR recMeisai IN curMeisai LOOP
		gSeqNo := gSeqNo + 1;
		--  発行日合計
                IF recMeisai.KNJ_INOUT_KBN = '4' THEN
                       gSeqNo2 := gSeqNo2 + 1;
		       gKingaku := gKingaku + recMeisai.KNJ_HRKM_KNGK;
                END IF;
		-- 帳票ワークへデータ追加
				-- Clear composite type
		v_item := NULL;
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := l_inGyomuYmd;	-- 業務日付
		v_item.l_inItem003 := vItakuKaishaRnm;	-- 委託会社名略称
		v_item.l_inItem004 := recMeisai.KNJ_SHORI_YMD;	-- 発行年月日
		v_item.l_inItem005 := recMeisai.KNJ_INOUT_KBN;	-- 入出金状況
		v_item.l_inItem006 := recMeisai.KNJ_INOUT_RNM;	-- 入出金状況名称
		v_item.l_inItem007 := recMeisai.KNJ_ERR_CODE;	-- エラーコード
		v_item.l_inItem008 := recMeisai.KNJ_UKE_TSUBAN;	-- 受付通番
		v_item.l_inItem009 := recMeisai.KNJ_UKE_TSUBAN_ZENKAI;	-- 前回受付通番
		v_item.l_inItem010 := recMeisai.KNJ_AZUKE_NO;	-- 預入番号（勘定系）
		v_item.l_inItem011 := recMeisai.HKT_CD;	-- 発行体コード
		v_item.l_inItem012 := recMeisai.HKT_RNM;	-- 発行体略名
		v_item.l_inItem013 := recMeisai.KOZA_TEN_CD;	-- 口座店コード
		v_item.l_inItem014 := recMeisai.KOZA_TEN_CIFCD;	-- 口座店ＣＩＦコード
		v_item.l_inItem015 := recMeisai.ISIN_CD;	-- ＩＳＩＮコード
		v_item.l_inItem016 := recMeisai.MGR_CD;	-- 銘柄コード
		v_item.l_inItem017 := recMeisai.MGR_RNM;	-- 銘柄略称
		v_item.l_inItem018 := recMeisai.SHASAI_TOTAL;	-- 社債の総額
		v_item.l_inItem019 := recMeisai.KNJ_HRKM_KNGK;	-- 差引後払込金額
		v_item.l_inItem020 := recMeisai.KNJ_TEN_NO;	-- 口座店コード
		v_item.l_inItem021 := recMeisai.KNJ_KOZA__KAMOKU;	-- 口座科目名称
		v_item.l_inItem022 := recMeisai.KNJ_KOUZA_NO;	-- 口座番号
		v_item.l_inItem023 := recMeisai.BUTEN_RNM;	-- 部店略称
		v_item.l_inItem027 := REPORT_ID;	-- 帳票ＩＤ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	END LOOP;
	IF gSeqNo = 0 THEN
	   --対象データなし
	   gRtnCd := RTN_NODATA;
           IF l_inChohyoKbn = '0' THEN
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := NULL;
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := l_inGyomuYmd;	-- 作成年月日
		v_item.l_inItem003 := vItakuKaishaRnm;	-- 委託会社名略称
		v_item.l_inItem004 := l_inShoriYmd;	-- 処理日付
		v_item.l_inItem026 := '対象データなし';
		v_item.l_inItem027 := REPORT_ID;	-- 帳票ＩＤ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> 1,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
           END IF;
	ELSE
		gSeqNo := gSeqNo + 1;
		-- 帳票ワークへ合計データを追加
				-- Clear composite type
		v_item := NULL;
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := l_inGyomuYmd;	-- 業務日付
		v_item.l_inItem003 := vItakuKaishaRnm;	-- 委託会社名略称
		v_item.l_inItem004 := l_inShoriYmd;	-- 処理日付
		v_item.l_inItem024 := gSeqNo2;	-- 入金済件数合計
		v_item.l_inItem025 := gKingaku;	-- 入金済金額合計
		v_item.l_inItem027 := REPORT_ID;	-- 帳票ＩＤ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	END IF;
	-- 終了処理
	--COMMIT;
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'IPF013K01R07 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS THEN
			CALL pkLog.fatal('ECM701', 'IPF013K01R07', 'SQLERRM:'||SQLERRM||'('||SQLSTATE||')');
			l_outSqlCode := RTN_FATAL;
			l_outSqlErrM := SQLERRM;
--		RAISE;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipf013k01r07 ( l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_inShoriYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;
