




CREATE OR REPLACE PROCEDURE spipf027k00r02 ( 
	l_inShoriCounter numeric,		-- 処理カウンタ
 l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inHktCd TEXT,		-- 発行体コード
 l_inUserId TEXT,		-- ユーザーID
 l_inChohyoKbn TEXT,		-- 帳票区分
 l_inGyomuYmd TEXT,		-- 業務日付
 l_inPageSum numeric,		-- ページ数
 l_outSqlCode OUT integer,		-- リターン値
 l_outSqlErrM OUT text	-- エラーコメント
 ) AS $body$
DECLARE

--
--/* 著作権:Copyright(c)2006
--/* 会社名:JIP
--/* 概要　:発行体マスタの内容を出力する。
--/* 引数　:l_inShoriCounter	IN	NUMERIC		処理カウンタ
--/* 　　　 l_inItakuKaishaCd	IN	TEXT		委託会社コード
--/* 　　　 l_inHktCd			IN	TEXT		発行体コード
--/* 　　　 l_inUserId		IN	TEXT		ユーザーID
--/* 　　　 l_inChohyoKbn		IN	TEXT		帳票区分
--/* 　　　 l_inGyomuYmd		IN	TEXT		業務日付
--/* 　　　 l_inPageSum		IN  NUMERIC		ページ数
--/* 　　　 l_outSqlCode		OUT	INTEGER		リターン値
--/* 　　　 l_outSqlErrM		OUT	VARCHAR	エラーコメント
--/* 返り値:なし
--/* @version $Revision: 1.2 $
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
	REPORT_ID			CONSTANT text	:= 'IPF30102721';			-- 帳票ID
	REPORT_ID_2			CONSTANT text	:= 'IPF30102722';			-- 帳票ID（2ページ目）
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd				integer :=	RTN_OK;							-- リターンコード
	gSeqNo				integer := 0;								-- シーケンス
	CTL_VALUE					MPROCESS_CTL.CTL_VALUE%TYPE;		-- 処理制御フラグ
    gTokijo						varchar(6);							-- 処理制御フラグ
--==============================================================================
--					カーソル定義													
--==============================================================================
	curMeisai CURSOR FOR
		SELECT	M01.SAKUSEI_DT,				--業務日付
		M01.HKT_CD,							--発行体コード
-- hyou start
		BT01.GNT_FLG,  --現登債フラグ
		(SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = 'B04'
			AND CODE_VALUE = BT01.GNT_FLG ) AS GNT_FLG_NM,                  -- 現登債フラグ名称
		BT01.CIF_HIRENDO_FLG,                                               -- ＣＩＦ非連動フラグ(BTMU用)
		(SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = 'B03'
			AND CODE_VALUE = BT01.CIF_HIRENDO_FLG ) AS CIF_HIRENDO_FLG_NM,  -- ＣＩＦ非連動フラグ(BTMU用)名称
		BT01.KYOTEN_KBN,                                                    -- 拠点区分
		(SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = 'B02'
			AND CODE_VALUE = BT01.KYOTEN_KBN ) AS KYOTEN_KBN_NM,            -- 拠点区分名称
-- hyou end
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
	--hyou start
		BT01.HKT_NM_GTAX,                   -- 発行体名称（国税帳票用）
	-- hyou end
		M01.EIGYOTEN_CD,					--営業店コード
	--hyou start
		(SELECT BUTEN_RNM FROM MBUTEN WHERE ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
			AND BUTEN_CD = M01.EIGYOTEN_CD ) AS EIGYOTEN_CD_RNM,  -- 営業店略称
	-- hyou end
		M01.GYOSHU_CD,						--業種コード
		MCD2.CODE_NM AS GC_NM,				--業種コード略称
		M01.COUNTRY_CD,						--国コード
	--hyou start
		(SELECT COUNTRY_RNM FROM MCOUNTRY WHERE COUNTRY_CD = M01.COUNTRY_CD
			) AS COUNTRY_CD_RNM,           -- 国名略称
	-- hyou end
		M01.BANK_RATING,					--行内格付
		M01.RYOSHU_OUT_KBN,					--領収書出力区分
		MCD3.CODE_NM AS ROK_NM,				--領収書出力区分名称
		M01.SHOKATSU_ZEIMUSHO_CD,			--所轄税務署コード
	--hyou start
		(SELECT ZEIMUSHO_NM FROM MZEIMUSHO WHERE ZEIMUSHO_CD = M01.SHOKATSU_ZEIMUSHO_CD
			) AS SHOKATSU_ZEIMUSHO_CD_NM,   -- 税務署名称
	-- hyou end
		M01.SEIRI_NO,						--整理番号
		M01.TOITSU_TEN_CIFCD,				--統一店CIFコード
		M01.KOZA_TEN_CD,					--口座店コード
	--hyou start
		(SELECT BUTEN_RNM FROM MBUTEN WHERE ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD
			AND BUTEN_CD = M01.KOZA_TEN_CD ) AS KOZA_TEN_CD_RNM,  -- 口座店略称
	-- hyou end
		M01.KOZA_TEN_CIFCD,					--口座店CIFコード
		M01.NYUKIN_KOZA_KBN,				--入金口座選択区分
		MCD4.CODE_NM AS NKK_NM,				--入金口座選択区分名称
	--hyou start
		BT01.BD_KOZA_TEN_CD,                -- 専用別段口座_口座店コード
		(SELECT BUTEN_RNM FROM MBUTEN WHERE ITAKU_KAISHA_CD = BT01.ITAKU_KAISHA_CD
			AND BUTEN_CD = BT01.BD_KOZA_TEN_CD ) AS BD_KOZA_TEN_CD_RNM,-- 専用別段口座_口座店略称
	-- hyou end
		M01.BD_KOZA_KAMOKU_CD,				--専用別段口座_口座科目コード
		MCD5.CODE_NM AS BKKC_NM,			--専用別段口座_口座科目名称
		M01.BD_KOZA_NO,						--専用別段口座_口座番号
		M01.BD_KOZA_MEIGININ_NM,			--専用別段口座_口座名義人
		M01.BD_KOZA_MEIGININ_KANA_NM,		--専用別段口座_口座名義人(カナ)
	--hyou start
		BT01.HKT_KOZA_TEN_CD,                -- 発行体預金口座_口座店コード
		(SELECT BUTEN_RNM FROM MBUTEN WHERE ITAKU_KAISHA_CD = BT01.ITAKU_KAISHA_CD
			AND BUTEN_CD = BT01.HKT_KOZA_TEN_CD ) AS HKT_KOZA_TEN_CD_RNM,-- 発行体預金口座_口座店略称
	-- hyou end
		M01.HKT_KOZA_KAMOKU_CD,				--発行体預金口座_口座科目コード
		MCD6.CODE_NM AS HKKC_NM,			--発行体預金口座_口座科目名称
		M01.HKT_KOZA_NO,					--発行体預金口座_口座番号
		M01.HKT_KOZA_MEIGININ_NM,			--発行体預金口座_口座名義人
		M01.HKT_KOZA_MEIGININ_KANA_NM,		--発行体預金口座_口座名義人(カナ)
		M01.HIKIOTOSHI_FLG,					--自動引落フラグ
		MCD7.CODE_NM AS HF_NM,				--自動引落フラグ内容
	--hyou start
		BT01.HKO_KOZA_TEN_CD1,              -- 自動引落口座_口座店コード１
		(SELECT BUTEN_RNM FROM MBUTEN WHERE ITAKU_KAISHA_CD = BT01.ITAKU_KAISHA_CD
			AND BUTEN_CD = BT01.HKO_KOZA_TEN_CD1 ) AS HKO_KOZA_TEN_CD1_RNM,  -- 自動引落口座_口座店略称１
	-- hyou end
		M01.HKO_KAMOKU_CD,					--自動引落口座_口座科目コード
		MCD8.CODE_NM AS HKC_NM,				--自動引落口座_口座科目名称
		M01.HKO_KOZA_NO,					--自動引落口座_口座番号
		M01.HKO_KOZA_MEIGININ_NM,			--自動引落口座_口座名義人
		M01.HKO_KOZA_MEIGININ_KANA_NM,		--自動引落口座_口座名義人(カナ)
	--hyou start
		BT01.HKO_KOZA_TEN_CD2,              -- 自動引落口座_口座店コード2
		(SELECT BUTEN_RNM FROM MBUTEN WHERE ITAKU_KAISHA_CD = BT01.ITAKU_KAISHA_CD
			AND BUTEN_CD = BT01.HKO_KOZA_TEN_CD2 ) AS HKO_KOZA_TEN_CD2_RNM,  -- 自動引落口座_口座店略称2
		BT01.HKO_KAMOKU_CD2,                                                 -- 自動引落口座_口座科目コード２
		(SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '707'
			AND CODE_VALUE = BT01.HKO_KAMOKU_CD2 ) AS HKO_KAMOKU_CD2_NM,     -- 自動引落口座_口座科目名称２
		BT01.HKO_KOZA_NO2,                -- 自動引落口座_口座番号２
		BT01.HKO_KOZA_MEIGININ_NM2,       -- 自動引落口座_口座名義人２
		BT01.HKO_KOZA_MEIGININ_KANA_NM2,  -- 自動引落口座_口座名義人（カナ）２
		BT01.HKO_KOZA_TEN_CD3,            -- 自動引落口座_口座店コード3
		(SELECT BUTEN_RNM FROM MBUTEN WHERE ITAKU_KAISHA_CD = BT01.ITAKU_KAISHA_CD
			AND BUTEN_CD = BT01.HKO_KOZA_TEN_CD3 ) AS HKO_KOZA_TEN_CD3_RNM,  -- 自動引落口座_口座店略称3
		BT01.HKO_KAMOKU_CD3,                                                 -- 自動引落口座_口座科目コード3
		(SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '707'
			AND CODE_VALUE = BT01.HKO_KAMOKU_CD3 ) AS HKO_KAMOKU_CD3_NM,     -- 自動引落口座_口座科目名称3
		BT01.HKO_KOZA_NO3,                                                   -- 自動引落口座_口座番号3
		BT01.HKO_KOZA_MEIGININ_NM3,                                          -- 自動引落口座_口座名義人3
		BT01.HKO_KOZA_MEIGININ_KANA_NM3,                                     -- 自動引落口座_口座名義人（カナ）3
		BT01.HKO_KOZA_TEN_CD4,                                               -- 自動引落口座_口座店コード4
		(SELECT BUTEN_RNM FROM MBUTEN WHERE ITAKU_KAISHA_CD = BT01.ITAKU_KAISHA_CD
			AND BUTEN_CD = BT01.HKO_KOZA_TEN_CD4 ) AS HKO_KOZA_TEN_CD4_RNM,  -- 自動引落口座_口座店略称4
		BT01.HKO_KAMOKU_CD4,                                                 -- 自動引落口座_口座科目コード4
		(SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '707'
			AND CODE_VALUE = BT01.HKO_KAMOKU_CD4 ) AS HKO_KAMOKU_CD4_NM,     -- 自動引落口座_口座科目名称4
		BT01.HKO_KOZA_NO4,                                                   -- 自動引落口座_口座番号4
		BT01.HKO_KOZA_MEIGININ_NM4,                                          -- 自動引落口座_口座名義人4
		BT01.HKO_KOZA_MEIGININ_KANA_NM4,                                     -- 自動引落口座_口座名義人（カナ）4
		BT01.HKO_KOZA_TEN_CD5,                                               -- 自動引落口座_口座店コード5
		(SELECT BUTEN_RNM FROM MBUTEN WHERE ITAKU_KAISHA_CD = BT01.ITAKU_KAISHA_CD
			AND BUTEN_CD = BT01.HKO_KOZA_TEN_CD5 ) AS HKO_KOZA_TEN_CD5_RNM,  -- 自動引落口座_口座店略称5
		BT01.HKO_KAMOKU_CD5,                                                 -- 自動引落口座_口座科目コード5
		(SELECT CODE_NM FROM SCODE WHERE CODE_SHUBETSU = '707'
			AND CODE_VALUE = BT01.HKO_KAMOKU_CD5 ) AS HKO_KAMOKU_CD5_NM,     -- 自動引落口座_口座科目名称5
		BT01.HKO_KOZA_NO5,                                                   -- 自動引落口座_口座番号5
		BT01.HKO_KOZA_MEIGININ_NM5,                                          -- 自動引落口座_口座名義人5
		BT01.HKO_KOZA_MEIGININ_KANA_NM5,                                     -- 自動引落口座_口座名義人（カナ）5
	-- hyou end
		M01.DEFAULT_YMD,					--デフォルト日
		M01.DEFAULT_BIKO,					--デフォルト備考
		M01.YOBI1,							--予備１
		M01.YOBI2,							--予備２
		M01.YOBI3							--予備３
		FROM mhakkotai2 bt01, mhakkotai m01
LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = '511') mcd1 ON (M01.KOBETSU_SHONIN_SAIYO_FLG = MCD1.CODE_VALUE)
LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = '705') mcd2 ON (M01.GYOSHU_CD = MCD2.CODE_VALUE)
LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = '717') mcd3 ON (M01.RYOSHU_OUT_KBN = MCD3.CODE_VALUE)
LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = '122') mcd4 ON (M01.NYUKIN_KOZA_KBN = MCD4.CODE_VALUE)
LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = '707') mcd5 ON (M01.BD_KOZA_KAMOKU_CD = MCD5.CODE_VALUE)
LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = '707') mcd6 ON (M01.HKT_KOZA_KAMOKU_CD = MCD6.CODE_VALUE)
LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = '711') mcd7 ON (M01.HIKIOTOSHI_FLG = MCD7.CODE_VALUE)
LEFT OUTER JOIN (SELECT * FROM SCODE WHERE CODE_SHUBETSU = '707') mcd8 ON (M01.HKO_KAMOKU_CD = MCD8.CODE_VALUE)
WHERE M01.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND M01.HKT_CD = l_inHktCd -- hyou start
  AND M01.ITAKU_KAISHA_CD = BT01.ITAKU_KAISHA_CD AND M01.HKT_CD = BT01.HKT_CD -- hyou end
         -- hyou start
 ORDER BY	M01.ITAKU_KAISHA_CD, M01.KOZA_TEN_CD, M01.KOZA_TEN_CIFCD;
-- hyou end
	
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
	-- 入力パラメタ(業務日付)のチェック
	IF coalesce(trim(both l_inGyomuYmd)::text, '') = '' THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', 'IPF001K00R02', '＜項目名称:業務日付＞'||'＜項目値:'||l_inGyomuYmd||'＞');
		RETURN;
	END IF;
	IF l_inShoriCounter = 1 THEN
		-- 帳票ワークの削除
		DELETE FROM SREPORT_WK
		WHERE	KEY_CD = l_inItakuKaishaCd
		AND		USER_ID = l_inUserId
		AND		CHOHYO_KBN = l_inChohyoKbn
		AND		SAKUSEI_YMD = l_inGyomuYmd
		AND (CHOHYO_ID = REPORT_ID OR CHOHYO_ID = REPORT_ID_2);
		-- ヘッダレコードを追加
		CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
		CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID_2);
	END IF;
	-- 処理制御マスタで登記上か納税上かの記述を制御する
	CTL_VALUE := pkControl.getCtlValue(l_inItakuKaishaCd, 'CM0100710102', '0');
	--登記上
	IF CTL_VALUE = '1' THEN
		gTokijo := '納税上';
	ELSE
		gTokijo := '登記上';
	END IF;
	--デ−タ取得
	FOR recMeisai IN curMeisai LOOP			
		--帳票ワークへデータ追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inGyomuYmd;	-- 業務日付
		v_item.l_inItem002 := recMeisai.HKT_CD;	-- 発行体コード
		v_item.l_inItem003 := recMeisai.HKT_NM;	-- 発行体名称
		v_item.l_inItem004 := recMeisai.HKT_RNM;	-- 発行体略称
		v_item.l_inItem005 := recMeisai.HKT_KANA_RNM;	-- 発行体略称（カナ）
		v_item.l_inItem006 := recMeisai.KK_HAKKO_CD;	-- 機構発行体コード
		v_item.l_inItem007 := recMeisai.KK_HAKKOSHA_RNM;	-- 機構発行体略称
		v_item.l_inItem008 := recMeisai.KOBETSU_SHONIN_SAIYO_FLG;	-- 個別承認採用フラグ
		v_item.l_inItem009 := recMeisai.KSSF_N;	-- 個別承認採用フラグ内容
		v_item.l_inItem010 := recMeisai.SFSK_POST_NO;	-- 送付先郵便番号
		v_item.l_inItem011 := recMeisai.ADD1;	-- 送付先住所１
		v_item.l_inItem012 := recMeisai.ADD2;	-- 送付先住所２
		v_item.l_inItem013 := recMeisai.ADD3;	-- 送付先住所３
		v_item.l_inItem014 := recMeisai.SFSK_BUSHO_NM;	-- 送付先担当部署名称
		v_item.l_inItem015 := recMeisai.SFSK_TANTO_NM;	-- 送付先担当者名称
		v_item.l_inItem016 := recMeisai.SFSK_TEL_NO;	-- 送付先電話番号
		v_item.l_inItem017 := recMeisai.SFSK_FAX_NO;	-- 送付先ＦＡＸ番号
		v_item.l_inItem018 := recMeisai.SFSK_MAIL_ADD;	-- 送付先メールアドレス
		v_item.l_inItem019 := recMeisai.TOKIJO_POST_NO;	-- 登記上郵便番号
		v_item.l_inItem020 := recMeisai.TOKIJO_ADD1;	-- 登記上住所１
		v_item.l_inItem021 := recMeisai.TOKIJO_ADD2;	-- 登記上住所２
		v_item.l_inItem022 := recMeisai.TOKIJO_ADD3;	-- 登記上住所３
		v_item.l_inItem023 := recMeisai.TOKIJO_YAKUSHOKU_NM;	-- 登記上役職名称
		v_item.l_inItem024 := recMeisai.TOKIJO_DELEGATE_NM;	-- 登記上代表者名称
		v_item.l_inItem025 := recMeisai.EIGYOTEN_CD;	-- 営業店コード
		v_item.l_inItem026 := recMeisai.GYOSHU_CD;	-- 業種コード
		v_item.l_inItem027 := recMeisai.GC_NM;	-- 業種コード略称
		v_item.l_inItem028 := recMeisai.COUNTRY_CD;	-- 国コード
		v_item.l_inItem029 := recMeisai.BANK_RATING;	-- 行内格付
		v_item.l_inItem030 := recMeisai.RYOSHU_OUT_KBN;	-- 領収書出力区分
		v_item.l_inItem031 := recMeisai.ROK_NM;	-- 領収書出力区分名称
		v_item.l_inItem032 := recMeisai.SHOKATSU_ZEIMUSHO_CD;	-- 所轄税務署コード
		v_item.l_inItem033 := recMeisai.SEIRI_NO;	-- 整理番号
		v_item.l_inItem034 := recMeisai.TOITSU_TEN_CIFCD;	-- 統一店CIFコード
		v_item.l_inItem035 := recMeisai.KOZA_TEN_CD;	-- 口座店コード
		v_item.l_inItem036 := recMeisai.KOZA_TEN_CIFCD;	-- 口座店CIFコード
		v_item.l_inItem037 := recMeisai.NYUKIN_KOZA_KBN;	-- 入金口座選択区分
		v_item.l_inItem038 := recMeisai.NKK_NM;	-- 入金口座選択区分名称
		v_item.l_inItem039 := recMeisai.BD_KOZA_KAMOKU_CD;	-- 専用別段口座_口座科目コード
		v_item.l_inItem040 := recMeisai.BKKC_NM;	-- 専用別段口座_口座科目名称
		v_item.l_inItem041 := recMeisai.BD_KOZA_NO;	-- 専用別段口座_口座番号
		v_item.l_inItem042 := recMeisai.BD_KOZA_MEIGININ_NM;	-- 専用別段口座_口座名義人
		v_item.l_inItem043 := recMeisai.BD_KOZA_MEIGININ_KANA_NM;	-- 専用別段口座_口座名義人(カナ)
		v_item.l_inItem044 := recMeisai.HKT_KOZA_KAMOKU_CD;	-- 発行体預金口座_口座科目コード
		v_item.l_inItem045 := recMeisai.HKKC_NM;	-- 発行体預金口座_口座科目名称
		v_item.l_inItem046 := recMeisai.HKT_KOZA_NO;	-- 発行体預金口座_口座番号
		v_item.l_inItem047 := recMeisai.HKT_KOZA_MEIGININ_NM;	-- 発行体預金口座_口座名義人
		v_item.l_inItem048 := recMeisai.HKT_KOZA_MEIGININ_KANA_NM;	-- 発行体預金口座_口座名義人(カナ)
		v_item.l_inItem049 := recMeisai.GNT_FLG_NM;	-- 現登債フラグ
		v_item.l_inItem050 := recMeisai.CIF_HIRENDO_FLG_NM;	-- ＣＩＦ非連動フラグ(BTMU用)名称
		v_item.l_inItem051 := recMeisai.KYOTEN_KBN_NM;	-- 拠点区分名称
		v_item.l_inItem052 := recMeisai.HKT_NM_GTAX;	-- 発行体名称（国税帳票用）
		v_item.l_inItem053 := recMeisai.EIGYOTEN_CD_RNM;	-- 営業店略称
		v_item.l_inItem054 := recMeisai.COUNTRY_CD_RNM;	-- 国名略称
		v_item.l_inItem055 := recMeisai.SHOKATSU_ZEIMUSHO_CD_NM;	-- 税務署名称
		v_item.l_inItem056 := recMeisai.KOZA_TEN_CD_RNM;	-- 口座店略称
		v_item.l_inItem057 := recMeisai.BD_KOZA_TEN_CD;	-- 専用別段口座_口座店コード
		v_item.l_inItem058 := recMeisai.BD_KOZA_TEN_CD_RNM;	-- 専用別段口座_口座店略称
		v_item.l_inItem059 := recMeisai.HKT_KOZA_TEN_CD;	-- 発行体預金口座_口座店コード
		v_item.l_inItem060 := recMeisai.HKT_KOZA_TEN_CD_RNM;	-- 発行体預金口座_口座店略称
		v_item.l_inItem061 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem062 := SPIPF027K00R02_getItakuKaishaRnm(l_inItakuKaishaCd);	-- 委託会社略称
		v_item.l_inItem063 := l_inGyomuYmd;	-- 作成日
		v_item.l_inItem064 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem065 := gTokijo;
	v_item.l_inItem066 := pkcharacter.numeric_to_char(l_inShoriCounter * 2 - 1);	-- ページ番号
	v_item.l_inItem067 := pkcharacter.numeric_to_char(l_inPageSum * 2);	-- 総ページ番号
	CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> 'BATCH',
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> l_inShoriCounter::integer,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		--帳票ワークへデータ追加（２ページ目）
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inGyomuYmd;	-- 業務日付
		v_item.l_inItem002 := recMeisai.HIKIOTOSHI_FLG;	-- 自動引落フラグ
		v_item.l_inItem003 := recMeisai.HF_NM;	-- 自動引落フラグ内容
		v_item.l_inItem004 := recMeisai.HKO_KOZA_TEN_CD1;	-- 自動引落口座_口座店コード１
		v_item.l_inItem005 := recMeisai.HKO_KOZA_TEN_CD1_RNM;	-- 自動引落口座_口座店略称１
		v_item.l_inItem006 := recMeisai.HKO_KAMOKU_CD;	-- 自動引落口座_口座科目コード
		v_item.l_inItem007 := recMeisai.HKC_NM;	-- 自動引落口座_口座科目名称
		v_item.l_inItem008 := recMeisai.HKO_KOZA_NO;	-- 自動引落口座_口座番号
		v_item.l_inItem009 := recMeisai.HKO_KOZA_MEIGININ_NM;	-- 自動引落口座_口座名義人
		v_item.l_inItem010 := recMeisai.HKO_KOZA_MEIGININ_KANA_NM;	-- 自動引落口座_口座名義人(カナ)
		v_item.l_inItem011 := recMeisai.HKO_KOZA_TEN_CD2;	-- 自動引落口座_口座店コード2
		v_item.l_inItem012 := recMeisai.HKO_KOZA_TEN_CD2_RNM;	-- 自動引落口座_口座店略称2
		v_item.l_inItem013 := recMeisai.HKO_KAMOKU_CD2;	-- 自動引落口座_口座科目コード２
		v_item.l_inItem014 := recMeisai.HKO_KAMOKU_CD2_NM;	-- 自動引落口座_口座科目名称２
		v_item.l_inItem015 := recMeisai.HKO_KOZA_NO2;	-- 自動引落口座_口座番号２
		v_item.l_inItem016 := recMeisai.HKO_KOZA_MEIGININ_NM2;	-- 自動引落口座_口座名義人２
		v_item.l_inItem017 := recMeisai.HKO_KOZA_MEIGININ_KANA_NM2;	-- 自動引落口座_口座名義人（カナ）２
		v_item.l_inItem018 := recMeisai.HKO_KOZA_TEN_CD3;	-- 自動引落口座_口座店コード3
		v_item.l_inItem019 := recMeisai.HKO_KOZA_TEN_CD3_RNM;	-- 自動引落口座_口座店略称3
		v_item.l_inItem020 := recMeisai.HKO_KAMOKU_CD3;	-- 自動引落口座_口座科目コード3
		v_item.l_inItem021 := recMeisai.HKO_KAMOKU_CD3_NM;	-- 自動引落口座_口座科目名称3
		v_item.l_inItem022 := recMeisai.HKO_KOZA_NO3;	-- 自動引落口座_口座番号3
		v_item.l_inItem023 := recMeisai.HKO_KOZA_MEIGININ_NM3;	-- 自動引落口座_口座名義人3
		v_item.l_inItem024 := recMeisai.HKO_KOZA_MEIGININ_KANA_NM3;	-- 自動引落口座_口座名義人（カナ）3
		v_item.l_inItem025 := recMeisai.HKO_KOZA_TEN_CD4;	-- 自動引落口座_口座店コード4
		v_item.l_inItem026 := recMeisai.HKO_KOZA_TEN_CD4_RNM;	-- 自動引落口座_口座店略称4
		v_item.l_inItem027 := recMeisai.HKO_KAMOKU_CD4;	-- 自動引落口座_口座科目コード4
		v_item.l_inItem028 := recMeisai.HKO_KAMOKU_CD4_NM;	-- 自動引落口座_口座科目名称4
		v_item.l_inItem029 := recMeisai.HKO_KOZA_NO4;	-- 自動引落口座_口座番号4
		v_item.l_inItem030 := recMeisai.HKO_KOZA_MEIGININ_NM4;	-- 自動引落口座_口座名義人4
		v_item.l_inItem031 := recMeisai.HKO_KOZA_MEIGININ_KANA_NM4;	-- 自動引落口座_口座名義人（カナ）4
		v_item.l_inItem032 := recMeisai.HKO_KOZA_TEN_CD5;	-- 自動引落口座_口座店コード5
		v_item.l_inItem033 := recMeisai.HKO_KOZA_TEN_CD5_RNM;	-- 自動引落口座_口座店略称5
		v_item.l_inItem034 := recMeisai.HKO_KAMOKU_CD5;	-- 自動引落口座_口座科目コード5
		v_item.l_inItem035 := recMeisai.HKO_KAMOKU_CD5_NM;	-- 自動引落口座_口座科目名称5
		v_item.l_inItem036 := recMeisai.HKO_KOZA_NO5;	-- 自動引落口座_口座番号5
		v_item.l_inItem037 := recMeisai.HKO_KOZA_MEIGININ_NM5;	-- 自動引落口座_口座名義人5
		v_item.l_inItem038 := recMeisai.HKO_KOZA_MEIGININ_KANA_NM5;	-- 自動引落口座_口座名義人（カナ）5
		v_item.l_inItem039 := recMeisai.DEFAULT_YMD;	-- デフォルト日
		v_item.l_inItem040 := recMeisai.DEFAULT_BIKO;	-- デフォルト備考
		v_item.l_inItem041 := recMeisai.YOBI1;	-- 予備１
		v_item.l_inItem042 := recMeisai.YOBI2;	-- 予備２
		v_item.l_inItem043 := recMeisai.YOBI3;	-- 予備３
		v_item.l_inItem044 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem045 := SPIPF027K00R02_getItakuKaishaRnm(l_inItakuKaishaCd);	-- 委託会社略称
		v_item.l_inItem046 := l_inGyomuYmd;	-- 作成日
		v_item.l_inItem047 := l_inUserId;	-- ユーザＩＤ
	v_item.l_inItem048 := pkcharacter.numeric_to_char(l_inShoriCounter * 2);	-- ページ番号
	v_item.l_inItem049 := pkcharacter.numeric_to_char(l_inPageSum * 2);	-- 総ページ番号
	CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> 'BATCH',
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID_2,
			l_inSeqNo		=> l_inShoriCounter::integer,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		gSeqNo := gSeqNo + 1;
	END LOOP;	
	IF gSeqNo = 0 THEN
		gRtnCd := RTN_NODATA;
	END IF;
	IF gRtnCd = RTN_OK THEN
		CALL pkPrtOk.insertPrtOk(
			l_inUserId,
			l_inItakuKaishaCd,
			l_inGyomuYmd,
			pkPrtOk.LIST_SAKUSEI_KBN_ZUIJI(),
			REPORT_ID
		);
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||l_inShoriCounter);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'IPF027K00R02 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS THEN
			CALL pkLog.fatal('ECM701', 'IPF027K00R02', 'SQLERRM:'||SQLERRM||'('||SQLSTATE||')');
			l_outSqlCode := RTN_FATAL;
			l_outSqlErrM := SQLERRM;
--		RAISE;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipf027k00r02 ( l_inShoriCounter numeric, l_inItakuKaishaCd TEXT, l_inHktCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_inPageSum numeric, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spipf027k00r02_getitakukaisharnm (l_inItakuKaishaCd text) RETURNS varchar AS $body$
DECLARE

	bankRnm		varchar(100) := NULL;

BEGIN
	-- 自行・委託会社情報から委託会社略称の取得
	SELECT	CASE WHEN JIKO_DAIKO_KBN='2' THEN  BANK_RNM  ELSE NULL END
	INTO STRICT	bankRnm
	FROM	VJIKO_ITAKU
	WHERE	KAIIN_ID = l_inItakuKaishaCd;
	RETURN bankRnm;
EXCEPTION
	WHEN OTHERS THEN
		RETURN bankRnm;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spipf027k00r02_getitakukaisharnm (l_inItakuKaishaCd text) FROM PUBLIC;