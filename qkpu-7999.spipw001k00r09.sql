




CREATE OR REPLACE PROCEDURE spipw001k00r09 ( 
    l_inMgrCd TEXT,       -- 銘柄コード
 l_inItakuKaishaCd TEXT,       -- 委託会社コード
 l_inUserId TEXT,       -- ユーザーID
 l_inChohyoKbn TEXT,       -- 帳票区分
 l_inGyomuYmd TEXT,       -- 業務日付
 l_outSqlCode OUT integer,     -- リターン値
 l_outSqlErrM OUT text    -- エラーコメント
 ) AS $body$
DECLARE

--
--/* 著作権:Copyright(c)2008
--/* 会社名:JIP
--/* 概要　:銘柄情報個別照会画面から、銘柄詳細情報リスト（行使価額履歴情報）を作成する。
--/* 引数　:l_inMgrCd         IN  TEXT        銘柄コード
--/* 　　　 l_inItakuKaishaCd IN  TEXT        委託会社コード
--/* 　　　 l_inUserId        IN  TEXT        ユーザーID
--/* 　　　 l_inChohyoKbn     IN  TEXT        帳票区分
--/* 　　　 l_inGyomuYmd      IN  TEXT        業務日付
--/* 　　　 l_outSqlCode      OUT INTEGER     リターン値
--/* 　　　 l_outSqlErrM      OUT VARCHAR    エラーコメント
--/* 返り値:なし
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付   開発者名		目的
--/* -------------------------------------------------------------------
--/*　2008.02.6	JIP				新規作成
--/*　2019.08.21	趙炳程			和暦表記の箇所を西暦表記に変更
--/* @version $Id: SPIPW001K00R09.sql,v 1.7 2019/09/25 02:03:17 hasegawa Exp $
--***************************************************************************
--/*==============================================================================
--					定数定義													
--==============================================================================
	RTN_OK              CONSTANT integer    := 0;                       -- 正常
	RTN_NG              CONSTANT integer    := 1;                       -- 予期したエラー
	RTN_NODATA          CONSTANT integer    := 2;                       -- データなし
	RTN_FATAL           CONSTANT integer    := 99;                      -- 予期せぬエラー
	REPORT_ID           CONSTANT char(11)   := 'IPW300001A1';           -- 帳票ID
--==============================================================================
--					変数定義													
--==============================================================================
	gRtnCd                          integer := RTN_OK;             -- リターンコード
	gSeqNo                          integer := 0;                  -- シーケンス
	gCnt                            numeric  := 0;                  -- 対象データ件数
	v_item                          type_sreport_wk_item;          -- 帳票ワーク項目（NEW STYLE）
	-- 西暦変換用
	gWrkWrntUseStYmd                varchar(20) := NULL;          -- 行使期間開始日
	gWrkWrntUseEdYmd                varchar(20) := NULL;          -- 行使期間終了日
	gWrkWrntUseKahakuKetteiYmd      varchar(20) := NULL;          --  価額決定日
	gItakuKaishaRnm                 VJIKO_ITAKU.BANK_RNM%TYPE;          -- 委託会社略称
	-- 最終承認ユーザ及び最終承認日
	gLastShoninId               VMGR_STS.LAST_SHONIN_ID%TYPE;           -- 最終承認ユーザId
	gLastShoninYmd              VMGR_STS.LAST_SHONIN_YMD%TYPE;          -- 最終承認日
--==============================================================================
--					カーソル定義													
--==============================================================================
	-- CB_MGR_KHN_RUISEKI取得用
	curMeisai CURSOR FOR
	SELECT WMG1.USE_KAGAKU_TEISEI_YMD,           -- 行使価額履歴訂正日
	       WMG1.USE_KAGAKU_TEISEI_USER_ID,       -- 行使価額履歴訂正ユーザ
	       MG0.LAST_SHONIN_YMD,                 -- 最終承認日
	       MG0.LAST_SHONIN_ID,                  -- 最終承認ユーザ
	       MG1.ITAKU_KAISHA_CD,
	       MG1.MGR_CD,
	       MG1.ISIN_CD,
	       MG1.MGR_RNM,
	       MG1.JTK_KBN,
	       (SELECT CODE_RNM FROM SCODE WHERE CODE_SHUBETSU = '112' AND CODE_VALUE = MG1.JTK_KBN) AS JTK_KBN_NM,
	       WMG1.WRNT_TOTAL AS wrntTotal,
	       WMG1.WRNT_HAKKO_KAGAKU AS wrntHakkoKagaku,
	       WMG1.WRNT_USE_ST_YMD AS wrntUseStYmd,
	       WMG1.WRNT_USE_ED_YMD AS wrntUseEdYmd,
	       (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '596' AND CODE_VALUE = WMG1.USE_SEIKYU_UKE_BASHO) AS useSeikyuUkeBashoNm,
	       WMG12.WRNT_USE_KAGAKU_KETTEI_YMD AS wrntUseKagakuKetteiYmd,
	       WMG12.WRNT_USE_KAGAKU AS wrntUseKagaku,
	       WMG12.WRNT_BIKO  AS wrntBiko,
	       VJ1.BANK_RNM,                         -- 銀行略称
	       VJ1.JIKO_DAIKO_KBN,                   -- 自行代行区分
	       (SELECT CODE_NM FROM SCODE WHERE MG0.MGR_STAT_KBN = CODE_VALUE AND CODE_SHUBETSU = '161') AS SHONIN_STAT_NM,  -- 承認状態
	       MG0.MGR_STAT_KBN                                                                                               -- 銘柄ステータス区分
	  FROM MGR_STS            MG0,
	       MGR_KIHON          MG1,
	       CB_MGR_KIHON       WMG1,
	       CB_MGR_KHN_RUISEKI WMG12,
	       VJIKO_ITAKU VJ1
	 WHERE MG1.ITAKU_KAISHA_CD = WMG12.ITAKU_KAISHA_CD
	   AND MG1.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
	   AND MG1.ITAKU_KAISHA_CD = WMG1.ITAKU_KAISHA_CD
	   AND MG1.MGR_CD = WMG12.MGR_CD
	   AND MG1.MGR_CD = MG0.MGR_CD
	   AND MG1.MGR_CD = WMG1.MGR_CD
	   AND MG1.ITAKU_KAISHA_CD = VJ1.KAIIN_ID
	   AND MG0.MASSHO_FLG = '0'
	   AND WMG12.USE_KAGAKU_HENKO_FLG IN ('1', '2')
	   AND WMG12.SHORI_KBN = '1'
	   AND MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
	   AND MG1.MGR_CD = l_inMgrCd
	ORDER BY
	        WMG12.WRNT_USE_KAGAKU_KETTEI_YMD;
	-- CB_MGR_KIHON取得用
	curMeisai2 CURSOR FOR
	  SELECT WMG1.USE_KAGAKU_TEISEI_YMD,           -- 行使価額履歴訂正日
	         WMG1.USE_KAGAKU_TEISEI_USER_ID,       -- 行使価額履歴訂正ユーザ
	         MG0.LAST_SHONIN_YMD,                 -- 最終承認日
	         MG0.LAST_SHONIN_ID,                  -- 最終承認ユーザ
	         MG1.ITAKU_KAISHA_CD,
	         MG1.MGR_CD,
	         MG1.ISIN_CD,
	         MG1.MGR_RNM,
	         MG1.JTK_KBN,
	         (SELECT CODE_RNM FROM SCODE WHERE CODE_SHUBETSU = '112' AND CODE_VALUE =MG1.JTK_KBN) AS JTK_KBN_NM,
	         WMG1.WRNT_TOTAL AS wrntTotal,
	         WMG1.WRNT_HAKKO_KAGAKU AS wrntHakkoKagaku,
	         WMG1.WRNT_USE_ST_YMD AS wrntUseStYmd,
	         WMG1.WRNT_USE_ED_YMD AS wrntUseEdYmd,
	         (SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '596' AND CODE_VALUE = WMG1.USE_SEIKYU_UKE_BASHO) AS useSeikyuUkeBashoNm,
	         WMG1.WRNT_USE_KAGAKU_KETTEI_YMD AS wrntUseKagakuKetteiYmd,
	         WMG1.WRNT_USE_KAGAKU AS wrntUseKagaku,
	         WMG1.WRNT_BIKO  AS wrntBiko,
	         VJ1.BANK_RNM,                         -- 銀行略称
	         VJ1.JIKO_DAIKO_KBN,                   -- 自行代行区分
	         (SELECT CODE_NM FROM SCODE WHERE MG0.MGR_STAT_KBN = CODE_VALUE AND CODE_SHUBETSU = '161') AS SHONIN_STAT_NM,  -- 承認状態
	         MG0.MGR_STAT_KBN                                                                                               -- 銘柄ステータス区分
	    FROM MGR_STS MG0,
	         MGR_KIHON MG1, 
	         CB_MGR_KIHON WMG1,
	         VJIKO_ITAKU VJ1
	   WHERE MG1.ITAKU_KAISHA_CD = WMG1.ITAKU_KAISHA_CD
	     AND MG1.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
	     AND MG1.MGR_CD = WMG1.MGR_CD
	     AND MG1.MGR_CD = MG0.MGR_CD
	     AND MG1.ITAKU_KAISHA_CD = VJ1.KAIIN_ID
	     AND MG0.MASSHO_FLG = '0'
	     AND MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
	     AND MG1.MGR_CD = l_inMgrCd
	ORDER BY WMG1.WRNT_USE_KAGAKU_KETTEI_YMD;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	-- 入力パラメータのチェック
	IF coalesce(l_inMgrCd::text, '') = ''
	OR coalesce(l_inItakuKaishaCd::text, '') = ''
	OR coalesce(l_inUserId::text, '') = ''
	OR coalesce(l_inChohyoKbn::text, '') = ''
	OR coalesce(l_inGyomuYmd::text, '') = ''
	THEN
	    -- パラメータエラー
	    l_outSqlCode := RTN_NG;
	    l_outSqlErrM := '';
	    CALL pkLog.error(l_inUserId, REPORT_ID, 'SQLERRM:'||'');
	    RETURN;
	END IF;
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE   KEY_CD = l_inItakuKaishaCd
	AND     USER_ID = l_inUserId
	AND     CHOHYO_KBN = l_inChohyoKbn
	AND     SAKUSEI_YMD = l_inGyomuYmd
	AND     CHOHYO_ID = REPORT_ID;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	-- 期中銘柄情報変更の件数取得
	SELECT COUNT(MGR_CD)
	  INTO STRICT gCnt
	  FROM CB_MGR_KHN_RUISEKI
	 WHERE ITAKU_KAISHA_CD = l_inItakuKaishaCd
	   AND MGR_CD = l_inMgrCd
	   AND KK_PHASE = 'M2'
	   AND USE_KAGAKU_HENKO_FLG IN ('1', '2');
	-- 期中銘柄情報変更が入力されている場合
	IF gCnt > 0 THEN
		-- データ取得
		FOR recMeisai IN curMeisai LOOP
		        gSeqNo := gSeqNo + 1;
		-- 委託会社略称
		       gItakuKaishaRnm := NULL;
		    IF recMeisai.JIKO_DAIKO_KBN = '2' THEN
		       gItakuKaishaRnm := recMeisai.BANK_RNM;
		    END IF;
		    -- 西暦変換
		    gWrkWrntUseStYmd := NULL;                                               -- 行使期間開始日
		    IF (trim(both recMeisai.wrntUseStYmd) IS NOT NULL AND (trim(both recMeisai.wrntUseStYmd))::text <> '') THEN
		        gWrkWrntUseStYmd := pkDate.seirekiChangeZeroSuppressSlash(recMeisai.wrntUseStYmd);
		    END IF;
	        gWrkWrntUseEdYmd := NULL;
	        IF trim(both recMeisai.wrntUseEdYmd) = '99999999'                            -- 行使期間終了日が9999/99/99 だったら
	        THEN
	            gWrkWrntUseEdYmd := recMeisai.wrntUseEdYmd;                                   -- 行使期間終了日
		    ELSIF (trim(both recMeisai.wrntUseEdYmd) IS NOT NULL AND (trim(both recMeisai.wrntUseEdYmd))::text <> '') THEN
		        gWrkWrntUseEdYmd := pkDate.seirekiChangeZeroSuppressSlash(recMeisai.wrntUseEdYmd);
		    END IF;
		    gWrkWrntUseKahakuKetteiYmd := NULL;                                     -- 行使価額決定日
		    IF (trim(both recMeisai.wrntUseKagakuKetteiYmd) IS NOT NULL AND (trim(both recMeisai.wrntUseKagakuKetteiYmd))::text <> '') THEN
		        gWrkWrntUseKahakuKetteiYmd := pkDate.seirekiChangeZeroSuppressSlash(recMeisai.wrntUseKagakuKetteiYmd);
		    END IF;
		    -- 最終承認ユーザの表示非表示切り替え
		    -- はじめに初期化しておく
		    gLastShoninYmd := ' ';
		    gLastShoninId := ' ';
		    -- 承認ステータスが承認以外の場合には表示しないようにする
		    IF recMeisai.MGR_STAT_KBN = '1' THEN
		        gLastShoninYmd := recMeisai.LAST_SHONIN_YMD;
		        gLastShoninId  := recMeisai.LAST_SHONIN_ID;
		    END IF;
		    -- 帳票ワークへデータを追加
		    v_item := NULL;
		    v_item.l_inItem001 := l_inUserId::varchar;
		    v_item.l_inItem002 := recMeisai.USE_KAGAKU_TEISEI_YMD::varchar;
		    v_item.l_inItem003 := recMeisai.USE_KAGAKU_TEISEI_USER_ID::varchar;
		    v_item.l_inItem004 := gLastShoninYmd::varchar;
		    v_item.l_inItem005 := gLastShoninId::varchar;
		    v_item.l_inItem006 := recMeisai.MGR_CD::varchar;
		    v_item.l_inItem007 := recMeisai.ISIN_CD::varchar;
		    v_item.l_inItem008 := recMeisai.MGR_RNM::varchar;
		    v_item.l_inItem009 := recMeisai.JTK_KBN_NM::varchar;
		    v_item.l_inItem010 := recMeisai.wrntTotal::varchar;
		    v_item.l_inItem011 := recMeisai.wrntHakkoKagaku::varchar;
		    v_item.l_inItem012 := gWrkWrntUseStYmd::varchar;
		    v_item.l_inItem013 := gWrkWrntUseEdYmd::varchar;
		    v_item.l_inItem014 := recMeisai.useSeikyuUkeBashoNm::varchar;
		    v_item.l_inItem015 := gWrkWrntUseKahakuKetteiYmd::varchar;
		    v_item.l_inItem016 := recMeisai.wrntUseKagaku::varchar;
		    v_item.l_inItem017 := recMeisai.wrntBiko::varchar;
		    v_item.l_inItem018 := gItakuKaishaRnm::varchar;
		    v_item.l_inItem019 := REPORT_ID::varchar;
		    v_item.l_inItem021 := recMeisai.SHONIN_STAT_NM::varchar;
		    v_item.l_inItem250 := 'furikaeSort9'::varchar;
		       CALL pkPrint.insertData(
		            l_inKeyCd           =>  l_inItakuKaishaCd::varchar
		            ,l_inUserId         =>  l_inUserId::varchar
		            ,l_inChohyoKbn      =>  l_inChohyoKbn::varchar
		            ,l_inSakuseiYmd     =>  l_inGyomuYmd::varchar
		            ,l_inChohyoId       =>  REPORT_ID::varchar
		            ,l_inSeqNo          =>  gSeqNo
		            ,l_inHeaderFlg      =>  '1'
		            ,l_inItem           =>  v_item
		            ,l_inKousinId       =>  l_inUserId::varchar
		            ,l_inSakuseiId      =>  l_inUserId::varchar
		        );
		END LOOP;
	ELSE
		-- データ取得
		FOR recMeisai2 IN curMeisai2 LOOP
		    gSeqNo := gSeqNo + 1;
		-- 委託会社略称
		       gItakuKaishaRnm := NULL;
		    IF recMeisai2.JIKO_DAIKO_KBN = '2' THEN
		       gItakuKaishaRnm := recMeisai2.BANK_RNM;
		    END IF;
		    -- 西暦変換
		    gWrkWrntUseStYmd := NULL;                                               -- 行使期間開始日
		    IF (trim(both recMeisai2.wrntUseStYmd) IS NOT NULL AND (trim(both recMeisai2.wrntUseStYmd))::text <> '') THEN
		       gWrkWrntUseStYmd := pkDate.seirekiChangeZeroSuppressSlash(recMeisai2.wrntUseStYmd);
		    END IF;
	        gWrkWrntUseEdYmd := NULL;                                               -- 行使期間終了日
		    IF trim(both recMeisai2.wrntUseEdYmd) = '99999999'                            -- 行使期間終了日が9999/99/99 だったら
	        THEN
	            gWrkWrntUseEdYmd := recMeisai2.wrntUseEdYmd;
		    ELSIF (trim(both recMeisai2.wrntUseEdYmd) IS NOT NULL AND (trim(both recMeisai2.wrntUseEdYmd))::text <> '') THEN
		        gWrkWrntUseEdYmd := pkDate.seirekiChangeZeroSuppressSlash(recMeisai2.wrntUseEdYmd);
		    END IF;
		    gWrkWrntUseKahakuKetteiYmd := NULL;                                     -- 行使価額決定日
		    IF (trim(both recMeisai2.wrntUseKagakuKetteiYmd) IS NOT NULL AND (trim(both recMeisai2.wrntUseKagakuKetteiYmd))::text <> '') THEN
		        gWrkWrntUseKahakuKetteiYmd := pkDate.seirekiChangeZeroSuppressSlash(recMeisai2.wrntUseKagakuKetteiYmd);
		    END IF;
		    -- 最終承認ユーザの表示非表示切り替え
		    -- はじめに初期化しておく
		    gLastShoninYmd := ' ';
		    gLastShoninId := ' ';
		    -- 承認ステータスが承認以外の場合には表示しないようにする
		    IF recMeisai2.MGR_STAT_KBN = '1' THEN
		        gLastShoninYmd := recMeisai2.LAST_SHONIN_YMD;
		        gLastShoninId  := recMeisai2.LAST_SHONIN_ID;
		    END IF;
		    IF (trim(both recMeisai2.wrntUseKagakuKetteiYmd) IS NOT NULL AND (trim(both recMeisai2.wrntUseKagakuKetteiYmd))::text <> '') THEN
		    -- 帳票ワークへデータを追加
		    v_item := NULL;
		    v_item.l_inItem001 := l_inUserId::varchar;
		    v_item.l_inItem002 := recMeisai2.USE_KAGAKU_TEISEI_YMD::varchar;
		    v_item.l_inItem003 := recMeisai2.USE_KAGAKU_TEISEI_USER_ID::varchar;
		    v_item.l_inItem004 := gLastShoninYmd::varchar;
		    v_item.l_inItem005 := gLastShoninId::varchar;
		    v_item.l_inItem006 := recMeisai2.MGR_CD::varchar;
		    v_item.l_inItem007 := recMeisai2.ISIN_CD::varchar;
		    v_item.l_inItem008 := recMeisai2.MGR_RNM::varchar;
		    v_item.l_inItem009 := recMeisai2.JTK_KBN_NM::varchar;
		    v_item.l_inItem010 := recMeisai2.wrntTotal::varchar;
		    v_item.l_inItem011 := recMeisai2.wrntHakkoKagaku::varchar;
		    v_item.l_inItem012 := gWrkWrntUseStYmd::varchar;
		    v_item.l_inItem013 := gWrkWrntUseEdYmd::varchar;
		    v_item.l_inItem014 := recMeisai2.useSeikyuUkeBashoNm::varchar;
		    v_item.l_inItem015 := gWrkWrntUseKahakuKetteiYmd::varchar;
		    v_item.l_inItem016 := recMeisai2.wrntUseKagaku::varchar;
		    v_item.l_inItem017 := recMeisai2.wrntBiko::varchar;
		    v_item.l_inItem018 := gItakuKaishaRnm::varchar;
		    v_item.l_inItem019 := REPORT_ID::varchar;
		    v_item.l_inItem021 := recMeisai2.SHONIN_STAT_NM::varchar;
		    v_item.l_inItem250 := 'furikaeSort9'::varchar;
		       CALL pkPrint.insertData(
		            l_inKeyCd           =>  l_inItakuKaishaCd::varchar
		            ,l_inUserId         =>  l_inUserId::varchar
		            ,l_inChohyoKbn      =>  l_inChohyoKbn::varchar
		            ,l_inSakuseiYmd     =>  l_inGyomuYmd::varchar
		            ,l_inChohyoId       =>  REPORT_ID::varchar
		            ,l_inSeqNo          =>  gSeqNo
		            ,l_inHeaderFlg      =>  '1'
		            ,l_inItem           =>  v_item
		            ,l_inKousinId       =>  l_inUserId::varchar
		            ,l_inSakuseiId      =>  l_inUserId::varchar
		        );
		    ELSE
		            -- 帳票ワークへデータを追加
		        v_item := NULL;
		        v_item.l_inItem001 := l_inUserId::varchar;
		        v_item.l_inItem002 := recMeisai2.USE_KAGAKU_TEISEI_YMD::varchar;
		        v_item.l_inItem003 := recMeisai2.USE_KAGAKU_TEISEI_USER_ID::varchar;
		        v_item.l_inItem004 := gLastShoninYmd::varchar;
		        v_item.l_inItem005 := gLastShoninId::varchar;
		        v_item.l_inItem006 := recMeisai2.MGR_CD::varchar;
		        v_item.l_inItem007 := recMeisai2.ISIN_CD::varchar;
		        v_item.l_inItem008 := recMeisai2.MGR_RNM::varchar;
		        v_item.l_inItem009 := recMeisai2.JTK_KBN_NM::varchar;
		        v_item.l_inItem010 := recMeisai2.wrntTotal::varchar;
		        v_item.l_inItem011 := recMeisai2.wrntHakkoKagaku::varchar;
		        v_item.l_inItem012 := gWrkWrntUseStYmd::varchar;
		        v_item.l_inItem013 := gWrkWrntUseEdYmd::varchar;
		        v_item.l_inItem014 := recMeisai2.useSeikyuUkeBashoNm::varchar;
		        v_item.l_inItem018 := gItakuKaishaRnm::varchar;
		        v_item.l_inItem019 := REPORT_ID::varchar;
		        v_item.l_inItem020 := '対象データなし'::varchar;
		        v_item.l_inItem021 := recMeisai2.SHONIN_STAT_NM::varchar;
		        v_item.l_inItem250 := 'furikaeSort9'::varchar;
		        CALL pkPrint.insertData(
		             l_inKeyCd          =>  l_inItakuKaishaCd::varchar
		            ,l_inUserId         =>  l_inUserId::varchar
		            ,l_inChohyoKbn      =>  l_inChohyoKbn::varchar
		            ,l_inSakuseiYmd     =>  l_inGyomuYmd::varchar
		            ,l_inChohyoId       =>  REPORT_ID::varchar
		            ,l_inSeqNo          =>  gSeqNo
		            ,l_inHeaderFlg      =>  '1'
		            ,l_inItem           =>  v_item
		            ,l_inKousinId       =>  l_inUserId::varchar
		            ,l_inSakuseiId      =>  l_inUserId::varchar
		         );
		        gRtnCd := RTN_NODATA;
		        EXIT;
		    END IF;
		END LOOP;
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
-- エラー処理
EXCEPTION
	WHEN   OTHERS   THEN
	    CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLCODE:'||SQLSTATE);
	    CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLERRM:'||SQLERRM);
	    l_outSqlCode := RTN_FATAL;
	    l_outSqlErrM := SQLERRM;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipw001k00r09 ( l_inMgrCd TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;