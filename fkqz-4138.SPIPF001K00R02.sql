




CREATE OR REPLACE PROCEDURE spipf001k00r02 ( l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inUserId TEXT,		-- ユーザーID
 l_inChohyoKbn TEXT,		-- 帳票区分
 l_inChohyoSakuKbn TEXT,		-- 帳票作成区分
 l_inGyomuYmd TEXT,		-- 業務日付
 l_outSqlCode OUT integer,		-- リターン値
 l_outSqlErrM OUT text	-- エラーコメント
 ) AS $body$
DECLARE

--
--/* 著作権:Copyright(c)2004
--/* 会社名:JIP
--/* 概要　:発行体マスタの内容を出力する。
--/* 引数　:l_inItakuKaishaCd	IN	TEXT		委託会社コード
--/* 　　　 l_inUserId		IN	TEXT		ユーザーID
--/* 　　　 l_inChohyoKbn		IN	TEXT		帳票区分
--/*	　    l_inChohyoSakuKbn	IN	TEXT,		帳票作成区分
--/* 　　　 l_inGyomuYmd		IN	TEXT		業務日付
--/* 　　　 l_outSqlCode		OUT	INTEGER		リターン値
--/* 　　　 l_outSqlErrM		OUT	VARCHAR	エラーコメント
--/* 返り値:なし
--/* @version $Revision: 1.4 $
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.05.09	JIP				新規作成
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
	RTN_OK				CONSTANT integer	:= 0;						-- 正常
	RTN_NG				CONSTANT integer	:= 1;						-- 予期したエラー
	RTN_NODATA			CONSTANT integer	:= 40;						-- データなし
	RTN_FATAL			CONSTANT integer	:= 99;						-- 予期せぬエラー
	REPORT_ID			CONSTANT char(11)	:= 'IPF30000121';			-- 帳票ID
--==============================================================================
--					変数定義													
--==============================================================================
	gRtnCd				integer :=	RTN_OK;							-- リターンコード
	gSeqNo				integer := 0;								-- シーケンス
	l_inItem			TYPE_SREPORT_WK_ITEM;						-- 帳票ワークアイテム
--==============================================================================
--					カーソル定義													
--==============================================================================
	curMeisai CURSOR FOR
		SELECT	M01.SAKUSEI_DT,				--業務日付
		M01.HKT_CD,							--発行体コード
		M01.HKT_NM,							--発行体名称
		M01.HKT_RNM,						--発行体略称
		M01.HKT_KANA_RNM,					--発行体略称（カナ）
		M01.KK_HAKKO_CD,					--機構発行体コード
		M01.KK_HAKKOSHA_RNM,				--機構発行体略称
		M01.KOBETSU_SHONIN_SAIYO_FLG,		--個別承認採用フラグ
		MCD1.CODE_NM AS KSSF_N,				--個別承認採用フラグ内容
		M01.SFSK_POST_NO,					--送付先郵便番号
		M01.ADD1,							--送付先住所１
		M01.ADD2,							--送付先住所２
		M01.ADD3,							--送付先住所３
		M01.SFSK_BUSHO_NM,					--送付先担当部署名称
		M01.SFSK_TANTO_NM,					--送付先担当者名称
		M01.SFSK_TEL_NO,					--送付先電話番号
		M01.SFSK_FAX_NO,					--送付先ＦＡＸ番号
		M01.SFSK_MAIL_ADD,					--送付先メールアドレス
		M01.TOKIJO_POST_NO,					--登記上郵便番号
		M01.TOKIJO_ADD1,					--登記上住所１
		M01.TOKIJO_ADD2,					--登記上住所２
		M01.TOKIJO_ADD3,					--登記上住所３
		M01.TOKIJO_YAKUSHOKU_NM,			--登記上役職名称
		M01.TOKIJO_DELEGATE_NM,				--登記上代表者名称
		M01.EIGYOTEN_CD,					--営業店コード
		M01.GYOSHU_CD,						--業種コード
		MCD2.CODE_NM AS GC_NM,				--業種コード略称
		M01.COUNTRY_CD,						--国コード
		M01.BANK_RATING,					--行内格付
		M01.RYOSHU_OUT_KBN,					--領収書出力区分
		MCD3.CODE_NM AS ROK_NM,				--領収書出力区分名称
		M01.SHOKATSU_ZEIMUSHO_CD,			--所轄税務署コード
		M01.SEIRI_NO,						--整理番号
		M01.TOITSU_TEN_CIFCD,				--統一店CIFコード
		M01.KOZA_TEN_CD,					--口座店コード
		M01.KOZA_TEN_CIFCD,					--口座店CIFコード
		M01.NYUKIN_KOZA_KBN,				--入金口座選択区分
		MCD4.CODE_NM AS NKK_NM,				--入金口座選択区分名称
		M01.BD_KOZA_KAMOKU_CD,				--専用別段口座_口座科目コード
		MCD5.CODE_NM AS BKKC_NM,			--専用別段口座_口座科目名称
		M01.BD_KOZA_NO,						--専用別段口座_口座番号
		M01.BD_KOZA_MEIGININ_NM,			--専用別段口座_口座名義人
		M01.BD_KOZA_MEIGININ_KANA_NM,		--専用別段口座_口座名義人(カナ)
		M01.HKT_KOZA_KAMOKU_CD,				--発行体預金口座_口座科目コード
		MCD6.CODE_NM AS HKKC_NM,			--発行体預金口座_口座科目名称
		M01.HKT_KOZA_NO,					--発行体預金口座_口座番号
		M01.HKT_KOZA_MEIGININ_NM,			--発行体預金口座_口座名義人
		M01.HKT_KOZA_MEIGININ_KANA_NM,		--発行体預金口座_口座名義人(カナ)
		M01.HIKIOTOSHI_FLG,					--自動引落フラグ
		MCD7.CODE_NM AS HF_NM,				--自動引落フラグ内容
		M01.HKO_KAMOKU_CD,					--自動引落口座_口座科目コード
		MCD8.CODE_NM AS HKC_NM,				--自動引落口座_口座科目名称
		M01.HKO_KOZA_NO,					--自動引落口座_口座番号
		M01.HKO_KOZA_MEIGININ_NM,			--自動引落口座_口座名義人
		M01.HKO_KOZA_MEIGININ_KANA_NM,		--自動引落口座_口座名義人(カナ)
		M01.DEFAULT_YMD,					--デフォルト日
		M01.DEFAULT_BIKO,					--デフォルト備考
		M01.YOBI1,							--予備１
		M01.YOBI2,							--予備２
		M01.YOBI3							--予備３
		FROM mhakkotai m01
LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = '511') mcd1 ON (M01.KOBETSU_SHONIN_SAIYO_FLG = MCD1.CODE_VALUE)
LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = '705') mcd2 ON (M01.GYOSHU_CD = MCD2.CODE_VALUE)
LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = '717') mcd3 ON (M01.RYOSHU_OUT_KBN = MCD3.CODE_VALUE)
LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = '122') mcd4 ON (M01.NYUKIN_KOZA_KBN = MCD4.CODE_VALUE)
LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = '707') mcd5 ON (M01.BD_KOZA_KAMOKU_CD = MCD5.CODE_VALUE)
LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = '707') mcd6 ON (M01.HKT_KOZA_KAMOKU_CD = MCD6.CODE_VALUE)
LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = '711') mcd7 ON (M01.HIKIOTOSHI_FLG = MCD7.CODE_VALUE)
LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = '707') mcd8 ON (M01.HKO_KAMOKU_CD = MCD8.CODE_VALUE)
WHERE M01.ITAKU_KAISHA_CD = l_inItakuKaishaCd         AND TO_CHAR(M01.SAKUSEI_DT, 'yyyymmdd') = l_inGyomuYmd AND M01.SAKUSEI_ID = l_inUserId ORDER BY M01.HKT_CD;
	curCount CURSOR FOR
		SELECT 	COUNT(*) AS CNT
		FROM	PRT_OK	S05
		WHERE	S05.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND		S05.KIJUN_YMD = l_inGyomuYmd
		AND		S05.LIST_SAKUSEI_KBN = l_inChohyoSakuKbn
		AND		S05.CHOHYO_ID = REPORT_ID;
	
--==============================================================================
--	メイン処理																	    
--==============================================================================
BEGIN
--	制作時、ログを出力する。パッケージ使用		
	IF DEBUG = 1 THEN	
	CALL pkLog.debug(l_inUserId, REPORT_ID, 'IPF001K00R02 START');	
	END IF;
	-- 入力パラメタ(委託会社コード)のチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF001K00R02', '＜項目名称:委託会社コード＞'||'＜項目値:'||l_inItakuKaishaCd||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(ユーザＩＤ)のチェック
	IF coalesce(trim(both l_inUserId)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF001K00R02', '＜項目名称:ユーザＩＤ＞'||'＜項目値:'||l_inUserId||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(帳票区分)のチェック
	IF coalesce(trim(both l_inChohyoKbn)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF001K00R02', '＜項目名称:帳票区分＞'||'＜項目値:'||l_inChohyoKbn||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(帳票作成区分)のチェック
	IF coalesce(trim(both l_inChohyoKbn)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF001K00R02', '＜項目名称:帳票作成区分＞'||'＜項目値:'||l_inChohyoSakuKbn||'＞');
		RETURN;
	END IF;
	-- 入力パラメタ(業務日付)のチェック
	IF coalesce(trim(both l_inGyomuYmd)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF001K00R02', '＜項目名称:業務日付＞'||'＜項目値:'||l_inGyomuYmd||'＞');
		RETURN;
	END IF;
	--帳票ワークの削除
	DELETE FROM	SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = 'BATCH'
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;
	--ヘッダーレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, 'BATCH', l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	--デ−タ取得
	FOR recMeisai IN curMeisai LOOP
		gSeqNo := gSeqNo + 1;
		--帳票ワークへデータ追加
		l_inItem.l_inItem001 := l_inGyomuYmd;                           -- 業務日付
		l_inItem.l_inItem002 := recMeisai.HKT_CD;                       -- 発行体コード
		l_inItem.l_inItem003 := recMeisai.HKT_NM;                       -- 発行体名称
		l_inItem.l_inItem004 := recMeisai.HKT_RNM;                      -- 発行体略称
		l_inItem.l_inItem005 := recMeisai.HKT_KANA_RNM;                 -- 発行体略称（カナ）
		l_inItem.l_inItem006 := recMeisai.KK_HAKKO_CD;                  -- 機構発行体コード
		l_inItem.l_inItem007 := recMeisai.KK_HAKKOSHA_RNM;              -- 機構発行体略称
		l_inItem.l_inItem008 := recMeisai.KOBETSU_SHONIN_SAIYO_FLG;     -- 個別承認採用フラグ
		l_inItem.l_inItem009 := recMeisai.KSSF_N;                       -- 個別承認採用フラグ内容
		l_inItem.l_inItem010 := recMeisai.SFSK_POST_NO;                 -- 送付先郵便番号
		l_inItem.l_inItem011 := recMeisai.ADD1;                         -- 送付先住所１
		l_inItem.l_inItem012 := recMeisai.ADD2;                         -- 送付先住所２
		l_inItem.l_inItem013 := recMeisai.ADD3;                         -- 送付先住所３
		l_inItem.l_inItem014 := recMeisai.SFSK_BUSHO_NM;                -- 送付先担当部署名称
		l_inItem.l_inItem015 := recMeisai.SFSK_TANTO_NM;                -- 送付先担当者名称
		l_inItem.l_inItem016 := recMeisai.SFSK_TEL_NO;                  -- 送付先電話番号
		l_inItem.l_inItem017 := recMeisai.SFSK_FAX_NO;                  -- 送付先ＦＡＸ番号
		l_inItem.l_inItem018 := recMeisai.SFSK_MAIL_ADD;                -- 送付先メールアドレス
		l_inItem.l_inItem019 := recMeisai.TOKIJO_POST_NO;               -- 登記上郵便番号
		l_inItem.l_inItem020 := recMeisai.TOKIJO_ADD1;                  -- 登記上住所１
		l_inItem.l_inItem021 := recMeisai.TOKIJO_ADD2;                  -- 登記上住所２
		l_inItem.l_inItem022 := recMeisai.TOKIJO_ADD3;                  -- 登記上住所３
		l_inItem.l_inItem023 := recMeisai.TOKIJO_YAKUSHOKU_NM;          -- 登記上役職名称
		l_inItem.l_inItem024 := recMeisai.TOKIJO_DELEGATE_NM;           -- 登記上代表者名称
		l_inItem.l_inItem025 := recMeisai.EIGYOTEN_CD;                  -- 営業店コード
		l_inItem.l_inItem026 := recMeisai.GYOSHU_CD;                    -- 業種コード
		l_inItem.l_inItem027 := recMeisai.GC_NM;                        -- 業種コード略称
		l_inItem.l_inItem028 := recMeisai.COUNTRY_CD;                   -- 国コード
		l_inItem.l_inItem029 := recMeisai.BANK_RATING;                  -- 行内格付
		l_inItem.l_inItem030 := recMeisai.RYOSHU_OUT_KBN;               -- 領収書出力区分
		l_inItem.l_inItem031 := recMeisai.ROK_NM;                       -- 領収書出力区分名称
		l_inItem.l_inItem032 := recMeisai.SHOKATSU_ZEIMUSHO_CD;         -- 所轄税務署コード
		l_inItem.l_inItem033 := recMeisai.SEIRI_NO;                     -- 整理番号
		l_inItem.l_inItem034 := recMeisai.TOITSU_TEN_CIFCD;             -- 統一店CIFコード
		l_inItem.l_inItem035 := recMeisai.KOZA_TEN_CD;                  -- 口座店コード
		l_inItem.l_inItem036 := recMeisai.KOZA_TEN_CIFCD;               -- 口座店CIFコード
		l_inItem.l_inItem037 := recMeisai.NYUKIN_KOZA_KBN;              -- 入金口座選択区分
		l_inItem.l_inItem038 := recMeisai.NKK_NM;                       -- 入金口座選択区分名称
		l_inItem.l_inItem039 := recMeisai.BD_KOZA_KAMOKU_CD;            -- 専用別段口座_口座科目コード
		l_inItem.l_inItem040 := recMeisai.BKKC_NM;                      -- 専用別段口座_口座科目名称
		l_inItem.l_inItem041 := recMeisai.BD_KOZA_NO;                   -- 専用別段口座_口座番号
		l_inItem.l_inItem042 := recMeisai.BD_KOZA_MEIGININ_NM;          -- 専用別段口座_口座名義人
		l_inItem.l_inItem043 := recMeisai.BD_KOZA_MEIGININ_KANA_NM;     -- 専用別段口座_口座名義人(カナ)
		l_inItem.l_inItem044 := recMeisai.HKT_KOZA_KAMOKU_CD;           -- 発行体預金口座_口座科目コード
		l_inItem.l_inItem045 := recMeisai.HKKC_NM;                      -- 発行体預金口座_口座科目名称
		l_inItem.l_inItem046 := recMeisai.HKT_KOZA_NO;                  -- 発行体預金口座_口座番号
		l_inItem.l_inItem047 := recMeisai.HKT_KOZA_MEIGININ_NM;         -- 発行体預金口座_口座名義人
		l_inItem.l_inItem048 := recMeisai.HKT_KOZA_MEIGININ_KANA_NM;    -- 発行体預金口座_口座名義人(カナ)
		l_inItem.l_inItem049 := recMeisai.HIKIOTOSHI_FLG;               -- 自動引落フラグ
		l_inItem.l_inItem050 := recMeisai.HF_NM;                        -- 自動引落フラグ内容
		l_inItem.l_inItem051 := recMeisai.HKO_KAMOKU_CD;                -- 自動引落口座_口座科目コード
		l_inItem.l_inItem052 := recMeisai.HKC_NM;                       -- 自動引落口座_口座科目名称
		l_inItem.l_inItem053 := recMeisai.HKO_KOZA_NO;                  -- 自動引落口座_口座番号
		l_inItem.l_inItem054 := recMeisai.HKO_KOZA_MEIGININ_NM;         -- 自動引落口座_口座名義人
		l_inItem.l_inItem055 := recMeisai.HKO_KOZA_MEIGININ_KANA_NM;    -- 自動引落口座_口座名義人(カナ)
		l_inItem.l_inItem056 := recMeisai.DEFAULT_YMD;                  -- デフォルト日
		l_inItem.l_inItem057 := recMeisai.DEFAULT_BIKO;                 -- デフォルト備考
		l_inItem.l_inItem058 := recMeisai.YOBI1;                        -- 予備１
		l_inItem.l_inItem059 := recMeisai.YOBI2;                        -- 予備２
		l_inItem.l_inItem060 := recMeisai.YOBI3;                        -- 予備３
		l_inItem.l_inItem061 := REPORT_ID;                              -- 帳票ＩＤ
		
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd,
			l_inUserId     => 'BATCH',
			l_inChohyoKbn  => l_inChohyoKbn,
			l_inSakuseiYmd => l_inGyomuYmd,
			l_inChohyoId   => REPORT_ID,
			l_inSeqNo      => gSeqNo,
			l_inHeaderFlg  => '1',
			l_inItem       => l_inItem,
			l_inKousinId   => l_inUserId,
			l_inSakuseiId  => l_inUserId
		);
	END LOOP;	
	IF gSeqNo = 0 THEN
		gRtnCd := RTN_NODATA;
	END IF;
	FOR recCount IN curCount LOOP
		IF recCount.CNT = 0 THEN
			INSERT INTO PRT_OK(ITAKU_KAISHA_CD,				-- 委託会社コード
				KIJUN_YMD,						-- 基準日
				LIST_SAKUSEI_KBN,				-- 帳票作成区分
				CHOHYO_ID,						-- 帳票ＩＤ
				SHORI_KBN,						-- 処理区分
				LAST_TEISEI_DT,					-- 最終訂正日時
				LAST_TEISEI_ID,					-- 最終訂正者
				SHONIN_DT,						-- 承認日時
				SHONIN_ID,						-- 承認者
				KOUSIN_DT,						-- 更新日時
				KOUSIN_ID,						-- 更新者
				SAKUSEI_DT,						-- 作成日時
				SAKUSEI_ID 						-- 作成者
				)
				VALUES (l_inItakuKaishaCd,
				l_inGyomuYmd,
				l_inChohyoSakuKbn,
				REPORT_ID,
				'1',							-- （承認）
				clock_timestamp(),
				l_inUserId,
				clock_timestamp(),
				l_inUserId,
				clock_timestamp(),
				l_inUserId,
				clock_timestamp(),
				l_inUserId
			);
		END IF;
	END LOOP;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'IPF001K00R02 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS THEN
			CALL pkLog.fatal('ECM701', 'IPF001K00R02', 'SQLERRM:'||SQLERRM||'('||SQLSTATE||')');
			l_outSqlCode := RTN_FATAL;
			l_outSqlErrM := SQLERRM;
--		RAISE;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipf001k00r02 ( l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inChohyoSakuKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;