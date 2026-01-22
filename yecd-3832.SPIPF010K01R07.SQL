




CREATE OR REPLACE PROCEDURE spipf010k01r07 ( l_inChohyoId TEXT,       -- 帳票ID
 l_inItakuKaishaCd TEXT,       -- 委託会社コード
 l_inUserId TEXT,       -- ユーザーID
 l_inChohyoKbn TEXT,       -- 帳票区分
 l_inGyomuYmd TEXT,       -- 業務日付
 l_inKessaiYmdF TEXT,       -- 決済日(FROM)
 l_inKessaiYmdT TEXT,       -- 決済日(TO)
 l_outSqlCode OUT integer,     -- リターン値
 l_outSqlErrM OUT text    -- エラーコメント
 ) AS $body$
DECLARE

--
--/* 著作権:Copyright(c)2004
--/* 会社名:JIP
--/* 概要　:日銀当預受渡状況確認リスト（入金予定 or 資金受渡依頼）の出力処理を行う。
--/* 引数　:l_inChohyoId          IN  TEXT        帳票ID
--/*        l_inItakuKaishaCd     IN  TEXT        委託会社コード
--/* 　　　 l_inUserId            IN  TEXT        ユーザーID
--/* 　　　 l_inChohyoKbn         IN  TEXT        帳票区分
--/* 　　　 l_inGyomuYmd          IN  TEXT        業務日付
--/* 　　　 l_inKessaiYmdF        IN  TEXT        決済日(FROM)
--/* 　　　 l_inKessaiYmdT        IN  TEXT        決済日(TO)
--/* 　　　 l_outSqlCode          OUT INTEGER     リターン値
--/* 　　　 l_outSqlErrM          OUT VARCHAR    エラーコメント
--/* 返り値:なし
--/* @version $Revision: 1.13 $
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付   開発者名        目的
--/* -------------------------------------------------------------------
--/*　2005.05.17  JIP             新規作成
--/*
--/*
--***************************************************************************
--
--==============================================================================
--                  デバッグ機能                                                 
--==============================================================================
    DEBUG   numeric(1)   := 0;
--==============================================================================
--                  定数定義                                                    
--==============================================================================
    RTN_OK              CONSTANT integer    := 0;                       -- 正常
    RTN_NG              CONSTANT integer    := 1;                       -- 予期したエラー
    RTN_NODATA          CONSTANT integer    := 40;                      -- データなし
    RTN_FATAL           CONSTANT integer    := 99;                      -- 予期せぬエラー
    REPORT_ID1          CONSTANT text   := 'IPF30101011';           -- 帳票ID
    REPORT_ID2          CONSTANT text   := 'IPF30101111';           -- 帳票ID
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
    gRtnCd              integer := RTN_OK;                         -- リターンコード
    gSeqNo              integer := 0;                              -- シーケンス
    -- 合計金額計算用
    gKingaku            numeric  := 0;                              -- 決算金額合計
    gCount              numeric  := 0;                              -- 決済日ごとの合計件数
    gWkKessaiYmd        char(8) := NULL;                           -- 前レコードの決済日
    -- 確認リスト区分用
    gKakuninListKbn     char(1) := NULL;                           -- 確認リスト区分
    gKakuninListNm      varchar(40) := NULL;                       -- 確認リスト区分名称
    -- 当預出入用
    gTouyoOutIn         char(2) := NULL;                           -- 当預出入区分
    -- 決済日がNULLの時の処理用変数
    gKessaiYmdF varchar(8) := NULL; -- 決済日(FROM)
    gKessaiYmdT varchar(8) := NULL; -- 決済日(TO)
--==============================================================================
--                  カーソル定義                                                    
--==============================================================================
    curMeisai CURSOR FOR
        SELECT  MCD1.CODE_NM AS KLK_NM,                                         -- 確認リスト区分名称
                FS11.KESSAI_YMD,                                                -- 決済日
                FS11.NYUSHUKIN_JOUKYOU,                                         -- 入出金状況
                MCD2.CODE_NM AS NJ_NM,                                          -- 入出金状況名称
                FS11.KESSAI_NO,                                                 -- 決済番号
                FS11.DATA_SHORI_KBN,                                            -- データ処理区分
                MCD3.CODE_NM AS DSK_NM,                                         -- データ処理区分名称
                SUBSTR(FS11.KESSAI_AITE_BANK_CD,3)
                || SUBSTR(FS11.KESSAI_AITE_TENPO_CD,2) AS SKK_CD,               -- 資金決済会社コード
                M02.BANK_RNM || M03.SHITEN_RNM AS AITE_SHIKIN_KESSAI_KAISHA_NM, -- 相手側資金決済会社名
                FS11.TOYO_KNGK,                                                 -- 決済金額
                SUBSTR(FS11.KESSAI_YOTEI_TM,1,4) AS K_TM,                       -- 決済時限
                FS11.UPDATE_YMD || SUBSTR(FS11.UPDATE_TM,1,6) AS DTTM                        -- データ作成日時
        FROM    TOYOSEND FS11
        CROSS JOIN (SELECT * FROM SCODE WHERE gKakuninListKbn = CODE_VALUE AND CODE_SHUBETSU = 'S06') MCD1
        LEFT OUTER JOIN MBANK_SHITEN_ZOKUSEI M04 ON (FS11.ITAKU_KAISHA_CD = M04.ITAKU_KAISHA_CD AND SUBSTR(FS11.KESSAI_AITE_BANK_CD,3) || SUBSTR(FS11.KESSAI_AITE_TENPO_CD,2) = M04.SKN_KESSAI_CD)
        LEFT OUTER JOIN MBANK_SHITEN M03 ON (M04.BANK_CD = M03.BANK_CD AND M04.SHITEN_CD = M03.SHITEN_CD AND M04.FINANCIAL_SECURITIES_KBN = M03.FINANCIAL_SECURITIES_KBN)
        LEFT OUTER JOIN MBANK M02 ON (M03.BANK_CD = M02.BANK_CD AND M03.FINANCIAL_SECURITIES_KBN = M02.FINANCIAL_SECURITIES_KBN)
        LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = 'S01') MCD2 ON (FS11.NYUSHUKIN_JOUKYOU = MCD2.CODE_VALUE)
        LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = 'S03') MCD3 ON (FS11.DATA_SHORI_KBN = MCD3.CODE_VALUE)
        WHERE   FS11.ITAKU_KAISHA_CD = l_inItakuKaishaCd
         AND    FS11.KESSAI_YMD BETWEEN gKessaiYmdF AND gKessaiYmdT
         AND    FS11.TOYO_STAT_KBN = '30'
         AND    FS11.TOYO_DEIRI_KBN = gTouyoOutIn
         AND    FS11.NYUSHUKIN_JOUKYOU IN ('1','2','3','4')
             
UNION ALL

        SELECT  MCD1.CODE_NM AS KLK_NM,                                         -- 確認リスト区分名称
                FS12.KESSAI_YMD,                                                -- 決済日
                FS12.NYUSHUKIN_JOUKYOU,                                         -- 入出金状況
                MCD2.CODE_NM AS NJ_NM,                                          -- 入出金状況名称
                FS12.KESSAI_NO,                                                 -- 決済番号
                FS12.DATA_SHORI_KBN,                                            -- データ処理区分
                MCD3.CODE_NM AS DSK_NM,                                         -- データ処理区分名称
                SUBSTR(FS12.KESSAI_AITE_BANK_CD,3)
                || SUBSTR(FS12.KESSAI_AITE_TENPO_CD,2) AS SKK_CD,               -- 資金決済会社コード
                M02.BANK_RNM || M03.SHITEN_RNM AS AITE_SHIKIN_KESSAI_KAISHA_NM, -- 相手側資金決済会社名
                FS12.TOYO_KNGK,                                                 -- 決済金額
                SUBSTR(FS12.KESSAI_YOTEI_TM,1,4) AS K_TM,                       -- 決済時限
                FS12.UPDATE_YMD || SUBSTR(FS12.UPDATE_TM,1,6) AS DTTM                        -- データ作成日時
        FROM    TOYORCV FS12
        CROSS JOIN (SELECT * FROM SCODE WHERE gKakuninListKbn = CODE_VALUE AND CODE_SHUBETSU = 'S06') MCD1
        LEFT OUTER JOIN MBANK_SHITEN_ZOKUSEI M04 ON (FS12.ITAKU_KAISHA_CD = M04.ITAKU_KAISHA_CD AND SUBSTR(FS12.KESSAI_AITE_BANK_CD,3) || SUBSTR(FS12.KESSAI_AITE_TENPO_CD,2) = M04.SKN_KESSAI_CD)
        LEFT OUTER JOIN MBANK_SHITEN M03 ON (M04.BANK_CD = M03.BANK_CD AND M04.SHITEN_CD = M03.SHITEN_CD AND M04.FINANCIAL_SECURITIES_KBN = M03.FINANCIAL_SECURITIES_KBN)
        LEFT OUTER JOIN MBANK M02 ON (M03.BANK_CD = M02.BANK_CD AND M03.FINANCIAL_SECURITIES_KBN = M02.FINANCIAL_SECURITIES_KBN)
        LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = 'S01') MCD2 ON (FS12.NYUSHUKIN_JOUKYOU = MCD2.CODE_VALUE)
        LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = 'S03') MCD3 ON (FS12.DATA_SHORI_KBN = MCD3.CODE_VALUE)
        WHERE   FS12.ITAKU_KAISHA_CD = l_inItakuKaishaCd
         AND    FS12.KESSAI_YMD BETWEEN gKessaiYmdF AND gKessaiYmdT
         AND    FS12.TOYO_STAT_KBN = '51'
         AND    FS12.TOYO_DEIRI_KBN = gTouyoOutIn
         AND    FS12.NYUSHUKIN_JOUKYOU = '0'
        ORDER BY KESSAI_YMD,NYUSHUKIN_JOUKYOU,KESSAI_NO,DATA_SHORI_KBN;
--==============================================================================
--  メイン処理                                                                     
--==============================================================================
BEGIN
--  制作時、ログを出力する。パッケージ使用  
    IF DEBUG = 1 THEN
    CALL pkLog.debug(l_inUserId, l_inChohyoId, 'IPF010K01R07 START');
    END IF;
    -- 入力パラメタ(帳票ＩＤ)のチェック
    IF coalesce(trim(both l_inChohyoId)::text, '') = '' THEN
        IF DEBUG = 1 THEN   CALL pkLog.debug(l_inUserId, l_inChohyoId, 'param error');END IF;
        l_outSqlCode := RTN_NG;
        l_outSqlErrM := '';
        CALL pkLog.error('ECM501', 'IPF010K01R07', '＜項目名称:帳票ＩＤ＞'||'＜項目値:'||l_inChohyoId||'＞');
        RETURN;
    END IF;
    -- 入力パラメタ(委託会社コード)のチェック
    IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' THEN
        IF DEBUG = 1 THEN   CALL pkLog.debug(l_inUserId, l_inChohyoId, 'param error');END IF;
        l_outSqlCode := RTN_NG;
        l_outSqlErrM := '';
        CALL pkLog.error('ECM501', 'IPF010K01R07', '＜項目名称:委託会社コード＞'||'＜項目値:'||l_inItakuKaishaCd||'＞');
        RETURN;
    END IF;
    -- 入力パラメタ(ユーザＩＤ)のチェック
    IF coalesce(trim(both l_inUserId)::text, '') = '' THEN
        IF DEBUG = 1 THEN   CALL pkLog.debug(l_inUserId, l_inChohyoId, 'param error');END IF;
        l_outSqlCode := RTN_NG;
        l_outSqlErrM := '';
        CALL pkLog.error('ECM501', 'IPF010K01R07', '＜項目名称:ユーザＩＤ＞'||'＜項目値:'||l_inUserId||'＞');
        RETURN;
    END IF;
    -- 入力パラメタ(帳票区分)のチェック
    IF coalesce(trim(both l_inChohyoKbn)::text, '') = '' THEN
        IF DEBUG = 1 THEN   CALL pkLog.debug(l_inUserId, l_inChohyoId, 'param error');END IF;
        l_outSqlCode := RTN_NG;
        l_outSqlErrM := '';
        CALL pkLog.error('ECM501', 'IPF010K01R07', '＜項目名称:帳票区分＞'||'＜項目値:'||l_inChohyoKbn||'＞');
        RETURN;
    END IF;
    -- 入力パラメタ(業務日付)のチェック
    IF coalesce(trim(both l_inGyomuYmd)::text, '') = '' THEN
        IF DEBUG = 1 THEN   CALL pkLog.debug(l_inUserId, l_inChohyoId, 'param error');END IF;
        l_outSqlCode := RTN_NG;
        l_outSqlErrM := '';
        CALL pkLog.error('ECM501', 'IPF010K01R07', '＜項目名称:業務日付＞'||'＜項目値:'||l_inGyomuYmd||'＞');
        RETURN;
    END IF;
    -- 入力パラメタ(決済日(FROMとTO))のチェック
    IF coalesce(trim(both l_inKessaiYmdF)::text, '') = '' AND coalesce(trim(both l_inKessaiYmdT)::text, '') = '' THEN
        IF DEBUG = 1 THEN   CALL pkLog.debug(l_inUserId, l_inChohyoId, 'param error');END IF;
        l_outSqlCode := RTN_NG;
        l_outSqlErrM := '';
        CALL pkLog.error('ECM501', 'IPF010K01R07', '＜決済日(FROM)＞'||'＜項目値:'||l_inKessaiYmdF||'＞'||'＜決済日(TO)＞'||'＜項目値:'||l_inKessaiYmdT||'＞');
        RETURN;
    END IF;
    -- 当預テーブル（受信用）は、当預テーブル（送信用）作成後に作成されるため、
    -- 当預テーブル（受信用）に格納されているデータは、必ず当預テーブル（送信用）にも存在する。
    -- よって、決済日（FROM）、決済日（TO）の最大値、最小値チェックは当預テーブル（送信用）.決済日を用いて行う。
    -- 入力パラメタ(決済日(FROM))のチェック
    -- 設定されていなければ、最小の決済日を取得する。
    IF coalesce(trim(both l_inKessaiYmdF)::text, '') = '' THEN
        SELECT MIN(FS11.KESSAI_YMD) INTO STRICT gKessaiYmdF FROM TOYOSEND FS11;
    ELSE
        gKessaiYmdF := l_inKessaiYmdF;
    END IF;
    -- 入力パラメタ(決済日(TO))のチェック
    -- 設定されていなければ、最大の決済日を取得する。
    IF coalesce(trim(both l_inKessaiYmdT)::text, '') = '' THEN
        SELECT MAX(FS11.KESSAI_YMD) INTO STRICT gKessaiYmdT FROM TOYOSEND FS11;
    ELSE
        gKessaiYmdT := l_inKessaiYmdT;
    END IF;
    -- 帳票IDを基に確認リスト区分変数・当預出入変数の設定処理
    IF l_inChohyoId = REPORT_ID1
    THEN
        gTouyoOutIn :=  '02';
         gKakuninListKbn    := '1';
    ELSE
       IF l_inChohyoId = REPORT_ID2
         THEN
               gTouyoOutIn  :=  '01';
               gKakuninListKbn  := '2';
         ELSE
              l_outSqlCode := RTN_NG;
            l_outSqlErrM := '';
              CALL pkLog.error('ECM501', 'IPF010K01R07', '＜項目名称:帳票ＩＤ＞'||'＜項目値:'||l_inChohyoId||'＞');
              RETURN;
       END IF;
    END IF;
    --確認リスト区分名称の取得
    SELECT  MCD1.CODE_NM
    INTO STRICT    gKakuninListNm                               -- 確認リスト区分名称
    FROM    SCODE MCD1
    WHERE   gKakuninListKbn = MCD1.CODE_VALUE
    AND     MCD1.CODE_SHUBETSU = 'S06';
    -- 帳票ワークの削除
    DELETE FROM SREPORT_WK
    WHERE   KEY_CD = l_inItakuKaishaCd
    AND     USER_ID = l_inUserId
    AND     CHOHYO_KBN = l_inChohyoKbn
    AND     SAKUSEI_YMD = l_inGyomuYmd
    AND     CHOHYO_ID = l_inChohyoId;
    -- ヘッダーレコードを追加
    CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, l_inChohyoId);
    -- デ−タ取得
    FOR recMeisai IN curMeisai LOOP
        gSeqNo := gSeqNo + 1;
        -- 決済日が変わったとき合計行を挿入する
        IF recMeisai.KESSAI_YMD != gWkKessaiYmd AND gSeqNo > 1
        THEN
            -- 帳票ワークへ合計データを追加
            		-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := l_inGyomuYmd;	-- 業務日付
		v_item.l_inItem004 := gKakuninListKbn;	-- 確認リスト区分
		v_item.l_inItem005 := gKakuninListNm;	-- 確認リスト区分名称
		v_item.l_inItem006 := gWkKessaiYmd;	-- 決済日
		v_item.l_inItem017 := gCount;	-- 決済日ごとの合計件数
		v_item.l_inItem018 := gKingaku;	-- 決算金額合計
		v_item.l_inItem019 := l_inChohyoId;	-- 帳票ＩＤ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> l_inChohyoId,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
            -- 決算金額合計 クリア
            gKingaku := 0;
            -- 決済日ごとの合計件数
            gCount := 0;
            -- 連番 加算
            gSeqNo := gSeqNo + 1;
        END IF;
        -- 決算金額合計 加算
        gKingaku := gKingaku + recMeisai.TOYO_KNGK;
        -- 決済日ごとの合計件数 加算
        gCount := gCount +1;
        -- 決済日 退避
        gWkKessaiYmd := recMeisai.KESSAI_YMD;
        -- 帳票ワークへデータ追加
        		-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := l_inGyomuYmd;	-- 業務日付
		v_item.l_inItem004 := gKakuninListKbn;	-- 確認リスト区分
		v_item.l_inItem005 := recMeisai.KLK_NM;	-- 確認リスト区分名称
		v_item.l_inItem006 := recMeisai.KESSAI_YMD;	-- 決済日
		v_item.l_inItem007 := recMeisai.NYUSHUKIN_JOUKYOU;	-- 入出金状況
		v_item.l_inItem008 := recMeisai.NJ_NM;	-- 入出金状況名称
		v_item.l_inItem009 := recMeisai.KESSAI_NO;	-- 決済番号
		v_item.l_inItem010 := recMeisai.DATA_SHORI_KBN;	-- データ処理区分
		v_item.l_inItem011 := recMeisai.DSK_NM;	-- データ処理区分名称
		v_item.l_inItem012 := recMeisai.SKK_CD;	-- 資金決済会社コード
		v_item.l_inItem013 := recMeisai.AITE_SHIKIN_KESSAI_KAISHA_NM;	-- 相手方資金決済会社略称
		v_item.l_inItem014 := recMeisai.TOYO_KNGK;	-- 決済金額(円)
		v_item.l_inItem015 := recMeisai.K_TM;	-- 決済時限
		v_item.l_inItem016 := recMeisai.DTTM;	-- データ作成日時
		v_item.l_inItem019 := l_inChohyoId;	-- 帳票ＩＤ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> l_inChohyoId,
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
            -- 帳票ワークへデータを追加
            		-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := l_inGyomuYmd;	-- 作成年月日
		v_item.l_inItem004 := gKakuninListKbn;	-- 確認リスト区分
		v_item.l_inItem005 := gKakuninListNm;	-- 確認リスト区分名称
		v_item.l_inItem019 := l_inChohyoId;	-- 帳票ＩＤ
		v_item.l_inItem020 := '対象データなし';
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> l_inChohyoId,
			l_inSeqNo		=> 1,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
      ELSE
           gSeqNo := gSeqNo +1;
            -- 帳票ワークへ合計データを追加
            		-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザID
		v_item.l_inItem002 := l_inGyomuYmd;	-- 業務日付
		v_item.l_inItem004 := gKakuninListKbn;	-- 確認リスト区分
		v_item.l_inItem005 := gKakuninListNm;	-- 確認リスト区分名称
		v_item.l_inItem006 := gWkKessaiYmd;	-- 決済日
		v_item.l_inItem017 := gCount;	-- 決済日ごとの合計件数
		v_item.l_inItem018 := gKingaku;	-- 決算金額合計
		v_item.l_inItem019 := l_inChohyoId;	-- 帳票ＩＤ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> l_inChohyoId,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
    END IF;
    -- カウンタ初期化
    gSeqNo := 0;
    -- 終了処理
    l_outSqlCode := gRtnCd;
    l_outSqlErrM := '';
    IF DEBUG = 1 THEN   CALL pkLog.debug(l_inUserId, l_inChohyoId, 'ROWCOUNT:'||gSeqNo);END IF;
    IF DEBUG = 1 THEN   CALL pkLog.debug(l_inUserId, l_inChohyoId, 'IPF010K01R07 END');END IF;
-- エラー処理
EXCEPTION
    WHEN    OTHERS THEN
            CALL pkLog.fatal('ECM701', 'IPF010K01R07', 'SQLERRM:'||SQLERRM||'('||SQLSTATE||')');
            l_outSqlCode := RTN_FATAL;
            l_outSqlErrM := SQLERRM;
--      RAISE;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipf010k01r07 ( l_inChohyoId TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_inKessaiYmdF TEXT, l_inKessaiYmdT TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;
