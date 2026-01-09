

-- ==================================================================
-- SPIPX078K00R01
-- 変動利率情報送信対象リスト作成のため帳票ワークテーブルにINSERTする。
--
--
-- 作成：2012/8/1		桑原
-- @version $Id: SPIPX078K00R01.sql,v 1.3 2012/10/01 05:38:41 takahashi Exp $
--
-- ==================================================================
CREATE OR REPLACE PROCEDURE spipx078k00r01 ( l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inUserId TEXT,		-- ユーザーID
 l_inChohyoKbn TEXT,		-- 帳票区分
 l_inGyomuYmd TEXT,		-- 業務日付
 l_outSqlCode OUT integer,		-- リターン値
 l_outSqlErrM OUT text	-- エラーコメント
 ) AS $body$
DECLARE

--==============================================================================
--					デバッグ機能													
--==============================================================================
	DEBUG	numeric(1)	:= 0;
--==============================================================================
--					定数定義													
--==============================================================================
	REPORT_ID			CONSTANT text		:= 'IPX30007811';	 -- 帳票ID
	PROGRAM_ID          CONSTANT text   := 'SPIPX078K00R01'; -- プログラムＩＤ
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd				integer :=	pkconstant.success();	-- リターンコード
	gSeqNo				integer := 1;				    -- シーケンス
    gYokuGyomuYmd 		char(8)			:= NULL;
	-- 変動利率情報送信対象リスト取得用カーソル
    --
--     * 以下のSELECT文で構成されています。
--     *
--     * 1. 変動利付債の利率未申請分
--     *    抽出期間は　業務日付 = 次回利率決定日の３営業日前　です。
--     *    次回利率決定日の２営業日前に出力させたいので、次回利率決定日の３営業日前の夜間処理で
--     *    対象データを抽出します。
--     *    また、初回利払分については　銘柄登録＜帳票出力日　となる場合のみ出力対象とします。
--     *    発行日直前では、利率情報の入力は忘れないだろうということからこのような仕様になりました。
--     *
--     *    例：
--     *      業務日付が2012/08/09、帳票出力日は2012/08/10となり、次回利率決定日が2012/08/14のデータが
--     *      抽出対象となります。
--     
	henko_cur CURSOR FOR
    -- 利払
    SELECT
        MG2.RBR_KJT,            -- 利払期日
        MG2.RBR_YMD,	        -- 利払日
        MG2.RIRITSU_KETTEI_YMD, -- 利率決定日
        VMG1.MGR_CD,            -- 銘柄コード
        VMG1.ISIN_CD,           -- ISINコード
        VMG1.MGR_RNM,           -- 銘柄略称
        VMG1.HAKKO_YMD,         -- 発行日
        VMG1.FULLSHOKAN_KJT,    -- 満期償還期日
        MG2.SPREAD,             -- スプレッド
        VMG1.KIJUN_KINRI_CD1,   -- 基準金利１（コード）
        (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '140' AND CODE_VALUE = VMG1.KIJUN_KINRI_CD1) AS kijunKinri1Nm,   -- 基準金利１
        (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '140' AND CODE_VALUE = VMG1.KIJUN_KINRI_CD2) AS kijunKinri2Nm,   -- 基準金利２
        VMG1.KIJUN_KINRI_CMNT,  -- 基準金利コメント
        VMG1.HKT_CD,            -- 発行体コード
        VMG1.KAIGO_ETC           -- 回号等
    FROM
        MGR_KIHON_VIEW VMG1,
        MGR_RBRKIJ MG2
    WHERE
        VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
    AND VMG1.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
    AND VMG1.MGR_CD = MG2.MGR_CD
    AND VMG1.JTK_KBN != '2'             -- 副受託以外
    AND VMG1.RITSUKE_WARIBIKI_KBN = 'V'
    AND VMG1.SHORI_KBN = '1'
	AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')   -- ISINコード＝ブランクは対象外
    AND l_inGyomuYmd = pkDate.getMinusDateBusiness(MG2.RIRITSU_KETTEI_YMD, 3) -- 業務日付が利率決定日の３営業日前
    AND MG2.KAIJI != '0'
    AND (trim(both MG2.RIRITSU_KETTEI_YMD) IS NOT NULL AND (trim(both MG2.RIRITSU_KETTEI_YMD))::text <> '')
    ORDER BY
        MG2.RIRITSU_KETTEI_YMD,
        VMG1.KIJUN_KINRI_CD1,
        MG2.RBR_KJT,
        VMG1.HKT_CD,
        VMG1.KAIGO_ETC,
        VMG1.ISIN_CD
;
	-- レコード型変数
	henko_rectype		RECORD;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, PROGRAM_ID || ' START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inUserId)::text, '') = ''
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''
	OR coalesce(trim(both l_inGyomuYmd)::text, '') = ''
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '入力パラメータチェックエラー';
		CALL pkLog.error('ECM001', REPORT_ID, 'SQLERRM:'|| l_outSqlErrM);
		RETURN;
	END IF;
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	-- 表示用業務日付（帳票を作成した日の翌営業日）（東京営業日ベース）
	gYokuGyomuYmd := pkDate.getPlusDateBusiness(l_inGyomuYmd, 1);
	-- レコードがなくなるまでループ
	FOR henko_rectype IN henko_cur LOOP
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := gYokuGyomuYmd;	-- 業務日付
		v_item.l_inItem003 := henko_rectype.RIRITSU_KETTEI_YMD;	-- 利率決定日
		v_item.l_inItem004 := henko_rectype.RBR_KJT;	-- 利払期日
		v_item.l_inItem005 := henko_rectype.RBR_YMD;	-- 利払日
		v_item.l_inItem006 := henko_rectype.MGR_CD;	-- 銘柄コード
		v_item.l_inItem007 := henko_rectype.ISIN_CD;	-- ISINコード
		v_item.l_inItem008 := henko_rectype.MGR_RNM;	-- 銘柄略称
		v_item.l_inItem009 := henko_rectype.HAKKO_YMD;	-- 発行日
		v_item.l_inItem010 := henko_rectype.FULLSHOKAN_KJT;	-- 満期償還期日
		v_item.l_inItem011 := henko_rectype.SPREAD;	-- スプレッド
		v_item.l_inItem012 := henko_rectype.kijunKinri1Nm;	-- 基準金利１
		v_item.l_inItem013 := henko_rectype.kijunKinri2Nm;	-- 基準金利２
		v_item.l_inItem014 := henko_rectype.KIJUN_KINRI_CMNT;	-- 基準金利コメント
		v_item.l_inItem015 := henko_rectype.HKT_CD;	-- 発行体コード
		v_item.l_inItem016 := henko_rectype.KAIGO_ETC;	-- 回号等
		v_item.l_inItem017 := REPORT_ID;	-- 帳票ID
		v_item.l_inItem019 := henko_rectype.KIJUN_KINRI_CD1;	-- 基準金利１（コード）
		
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
		gSeqNo := gSeqNo + 1;
	END LOOP;
	IF gSeqNo = 1 THEN
		-- 対象データなし
		gRtnCd := pkconstant.NO_DATA_FIND();
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := gYokuGyomuYmd;	-- 業務日付
		v_item.l_inItem017 := REPORT_ID;	-- 帳票ID
		v_item.l_inItem018 := '対象データなし';
		
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
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, PROGRAM_ID || ' END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		IF henko_cur%ISOPEN THEN
			CLOSE henko_cur;
		END IF;
		CALL pkLog.fatal('ECM701', PROGRAM_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', PROGRAM_ID, 'SQLERRM:' || SQLERRM);
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipx078k00r01 ( l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;