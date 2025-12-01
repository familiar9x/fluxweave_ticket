




CREATE OR REPLACE PROCEDURE spip00503 ( l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inKessaiNo TEXT,		-- 決済番号
 l_inUserId TEXT,		-- ユーザーID
 l_inChohyoKbn TEXT,		-- 帳票区分
 l_inGyomuYmd TEXT,		-- 業務日付
 l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE,   -- 機構連携作成日時
 l_outSqlCode OUT integer,		-- リターン値
 l_outSqlErrM OUT text	-- エラーコメント
 ) AS $body$
DECLARE

--
--/* 著作権:Copyright(c)2004
--/* 会社名:JIP
--/* 概要　:機構から電文を受信したタイミングで、新規記録情報内容リストを作成する。
--/* 引数　:l_inItakuKaishaCd	IN	TEXT		委託会社コード
--/*        l_inKessaiNo 		IN 	TEXT		決済番号
--/* 　　　 l_inUserId		IN	TEXT		ユーザーID
--/* 　　　 l_inChohyoKbn		IN	TEXT		帳票区分
--/* 　　　 l_inGyomuYmd		IN	TEXT		業務日付
--/* 　　　 l_inKkSakuseiDt		IN	KK_RENKEI.KK_SAKUSEI_DT%TYPE,   -- 機構連携作成日時
--/* 　　　 l_outSqlCode		OUT	INTEGER		リターン値
--/* 　　　 l_outSqlErrM		OUT	VARCHAR	エラーコメント
--/* 返り値:なし
--/*
--***************************************************************************
--/* @version $Id: SPIP00503.SQL,v 1.22 2007/12/19 10:02:03 harada Exp $
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.02.14	JIP				新規作成
--/*　2005.08.12	磯田			カーソル修正
--/*	2005.08.17	山田			新規記録情報承認REF.NO -> 決済番号へ修正(IP-1857)
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
	RTN_NODATA			CONSTANT integer	:= 2;						-- データなし
	RTN_FATAL			CONSTANT integer	:= 99;						-- 予期せぬエラー
--@s PENDING
	REPORT_ID			CONSTANT SREPORT_WK.CHOHYO_ID%TYPE	:= 'IP030000531';	-- 帳票ID
	-- 書式フォーマット
	FMT_J	            CONSTANT varchar(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';
	-- 書式フォーマット（外資）
	FMT_F	            CONSTANT varchar(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';
--@e PENDING
	SP_ID				CONSTANT char(20)	:= 'SPIP00503';				-- 本SPのID
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd				integer :=	RTN_OK;							-- リターンコード
	gSeqNo				integer := 0;								-- シーケンス
	gExistSeqNo			integer := 0;								-- シーケンス（既存レコード用）
	gInsSeqNo			integer := 0;								-- シーケンス（登録用）
	gHeaderSeqNo		integer := 0;								-- シーケンス（ヘッダー明細番号）
	gUmuFlg				integer := 0;								-- データ有無フラグ
	gItakuKaishaRnm		MITAKU_KAISHA.ITAKU_KAISHA_RNM%TYPE;			-- 委託会社略称
    gKkSaikuseiYmd      varchar(20);                                    -- 機構連携作成日
    gKkSaikuseiTm       varchar(20);                                    -- 機構連携作成時間
	-- 書式フォーマット
	gFmtHakkoKngk		    varchar(21) := NULL;						-- 発行金額
	gFmtRbrKngk			    varchar(21) := NULL;						-- 利払金額
	gFmtShokanKngk		    varchar(21) := NULL;						-- 償還金額
    gFmtKokunaiTesuKngk     varchar(21) := NULL;						-- 国内手数料金額
    gFmtKokunaiTesuSzeiKngk varchar(21) := NULL;						-- 国内手数料消費税
    gFmtKeikarishiKngk      varchar(21) := NULL;						-- 経過利子金額
    gFmtKessaiKngk          varchar(21) := NULL;  					-- 決済金額
--==============================================================================
--					カーソル定義													
--==============================================================================
	curMeisai CURSOR FOR
    SELECT 	B04W.KESSAI_NO,							-- 新規記録情報承認REF.NO -> 決済番号へ修正(IP-1857)
    --@s PENDING 新規記録情報.処理コード　項目無し
    --		B04W.SHORI_CD,									-- 処理コード
    --		MCD1.CODE_NM AS SHORI_NM,						-- 処理コード名称
    --		'X' AS SHORI_CD,
    --		'XXXXX' AS SHORI_NM,
    --@e PENDING 新規記録情報.処理コード　項目無し
    		B04W.SSI_MUKO_FLG_CD,							-- ＳＳＩ無効化フラグコード
			(SELECT CODE_NM
			   FROM SCODE
			  WHERE B04W.SSI_MUKO_FLG_CD = CODE_VALUE
				AND CODE_SHUBETSU = '535') AS SSI_MUKO_FLG_NM, -- ＳＳＩ利用フラグ名称
    		B04W.YAKUJO_YMD,								-- 約定年月日
    		B04W.KESSAI_YMD,								-- 決済年月日
    		B04W.HKUK_KNGK,									-- 引受金額
    		B04W.HAKKO_KAGAKU,								-- 発行価額
    		B04W.YAKUJO_KNGK,								-- 約定金額
    		B04W.YAKUJO_TSUKA_CD,							-- 約定通貨
            CASE
                WHEN coalesce((SELECT TSUKA_NM FROM MTSUKA WHERE TSUKA_CD = B04W.YAKUJO_TSUKA_CD)::text, '') = '' THEN
                    B04W.YAKUJO_TSUKA_CD
                ELSE (SELECT TSUKA_NM FROM MTSUKA WHERE TSUKA_CD = B04W.YAKUJO_TSUKA_CD)
            END AS YAKUJO_TSUKA_CD_NM,                      -- 約定通貨名称
    		B04W.KOKUNAI_TESU_KNGK,							-- 国内手数料金額
    		B04W.KOKUNAI_TSUKA_CD,							-- 国内手数料通貨
            CASE
                WHEN coalesce((SELECT TSUKA_NM FROM MTSUKA WHERE TSUKA_CD = B04W.KOKUNAI_TSUKA_CD)::text, '') = '' THEN
                    B04W.KOKUNAI_TSUKA_CD
                ELSE (SELECT TSUKA_NM FROM MTSUKA WHERE TSUKA_CD = B04W.KOKUNAI_TSUKA_CD)
            END AS KOKUNAI_TSUKA_CD_NM,                     -- 国内手数料通貨名称
    		B04W.KOKUNAI_TESU_SZEI_KNGK,					-- 国内手数料消費税金額
    		B04W.KOKUNAI_TESU_TSUKA_CD,						-- 国内手数料消費税通貨
            CASE
                WHEN coalesce((SELECT TSUKA_NM FROM MTSUKA WHERE TSUKA_CD = B04W.KOKUNAI_TESU_TSUKA_CD)::text, '') = '' THEN
                    B04W.KOKUNAI_TESU_TSUKA_CD
                ELSE (SELECT TSUKA_NM FROM MTSUKA WHERE TSUKA_CD = B04W.KOKUNAI_TESU_TSUKA_CD)
            END AS KOKUNAI_TESU_TSUKA_CD_NM,                -- 国内手数料消費税通貨名称
    		B04W.KEIKARISHI_KNGK,							-- 経過利子金額
    		B04W.KEIKARISHITSUKA_CD,						-- 経過利子金額通貨
            CASE
                WHEN coalesce((SELECT TSUKA_NM FROM MTSUKA WHERE TSUKA_CD = B04W.KEIKARISHITSUKA_CD)::text, '') = '' THEN
                    B04W.KEIKARISHITSUKA_CD
                ELSE (SELECT TSUKA_NM FROM MTSUKA WHERE TSUKA_CD = B04W.KEIKARISHITSUKA_CD)
            END AS KEIKARISHITSUKA_CD_NM,                   -- 経過利子金額通貨名称
    		B04W.KESSAI_KNGK,								-- 決済金額
    		B04W.KESSAI_TSUKA_CD,							-- 決済金額通貨
            CASE
                WHEN coalesce((SELECT TSUKA_NM FROM MTSUKA WHERE TSUKA_CD = B04W.KESSAI_TSUKA_CD)::text, '') = '' THEN
                    B04W.KESSAI_TSUKA_CD
                ELSE (SELECT TSUKA_NM FROM MTSUKA WHERE TSUKA_CD = B04W.KESSAI_TSUKA_CD)
            END AS KESSAI_TSUKA_CD_NM,                      -- 決済金額通貨名称
    		B04W.HAKKO_YMD,									-- 発行年月日
    		B04W.SHOKAN_YMD,								-- 償還年月日
    		B04W.RIRITSU,									-- 利率
    		B04W.ISIN_CD,									-- ＩＳＩＮコード
--2006/06 ASK START/////////
			B04W.SHORI_CD,                                  -- 処理コード
			(SELECT CODE_NM
			   FROM SCODE
			  WHERE B04W.SHORI_CD = CODE_VALUE
				AND CODE_SHUBETSU = '547') AS SHORI_NM,     -- 処理コード名称
--2006/06 ASK END///////////
    --@s PENDING 必要なし?(書式フォーマット判別用)
    		VMG1.HAKKO_TSUKA_CD,							-- 発行通貨コード
    --@e PENDING 必要なし?(書式フォーマット判別用)
    		VMG1.MGR_RNM,									-- 銘柄略称
    		B04W.URI_BANKID_CD,								-- 売り手金融機関識別コード
    		B04W.URI_BANKID_CDW,							-- 売り手  金融証券区分＋金融機関コード
    		coalesce((SELECT BANK_RNM FROM substrb04w
LEFT OUTER JOIN mbank m02 ON (SUBSTR(B04W.URI_BANKID_CDW,1,1) = M02.FINANCIAL_SECURITIES_KBN AND SUBSTR(B04W.URI_BANKID_CDW,2,4) = M02.BANK_CD)  ),' ')
                    AS URI_BANKID_RNM,				        -- 売り手略称
    		B04W.KAI_BANKID_CD,								-- 買い手金融機関識別コード
    		B04W.KAI_BANKID_CDW,							-- 買い手  金融証券区分＋金融機関コード
    		coalesce((SELECT BANK_RNM FROM substrb04w
LEFT OUTER JOIN mbank m02 ON (SUBSTR(B04W.KAI_BANKID_CDW,1,1) = M02.FINANCIAL_SECURITIES_KBN AND SUBSTR(B04W.KAI_BANKID_CDW,2,4) = M02.BANK_CD)  ),' ')
                    AS KAI_BANKID_RNM,      				-- 買い手略称
    		B04W.FUND_CD,									-- ファンドコード
    		B04W.WTS_KESSAIDAIRI_CD,						-- 渡方決済代理人コード
    		B04W.WTS_KESSAIDAIRI_CDW,						-- 渡方決済代理人  金融証券区分＋金融機関コード
    		coalesce((SELECT BANK_RNM FROM substrb04w
LEFT OUTER JOIN mbank m02 ON (SUBSTR(B04W.WTS_KESSAIDAIRI_CDW,1,1) = M02.FINANCIAL_SECURITIES_KBN AND SUBSTR(B04W.WTS_KESSAIDAIRI_CDW,2,4) = M02.BANK_CD)  ),' ')
                    AS WTS_KESSAIDAIRI_RNM,     			-- 渡方決済代理人略称
    		B04W.TANKATYPE_CD,								-- 単価タイプコード
			(SELECT CODE_NM
			   FROM SCODE
			  WHERE B04W.TANKATYPE_CD = CODE_VALUE
				AND CODE_SHUBETSU = '556') AS TANKATYPE_NM, -- 単価タイプコード名称
    		B04W.FACTOR,									-- ファクター
    		B04W.YAKUJO_RATE,								-- 約定利回り
    		B04W.OWN_ITAKU_CD,								-- 自己委託コード（買い手）
			(SELECT CODE_NM
			   FROM SCODE
			  WHERE B04W.OWN_ITAKU_CD = CODE_VALUE
				AND CODE_SHUBETSU = '593') AS OWN_ITAKU_NM, -- 自己委託コード名称
    		B04W.UKE_KESSAIDAIRI_CD,						-- 受方決済代理人コード
    		B04W.UKE_KESSAIDAIRI_CDW,						-- 受方決済代理人  金融証券区分＋金融機関コード
    		coalesce((SELECT BANK_RNM FROM substrb04w
LEFT OUTER JOIN mbank m02 ON (SUBSTR(B04W.UKE_KESSAIDAIRI_CDW,1,1) = M02.FINANCIAL_SECURITIES_KBN AND SUBSTR(B04W.UKE_KESSAIDAIRI_CDW,2,4) = M02.BANK_CD)  ),' ')
                    AS UKE_KESSAIDAIRI_RNM,     			-- 受方決済代理人略称
    		B04W.MSG_TS_BANKID_CD,							-- メッセージ当初送信者金融機関識別コード
    		B04W.MSG_TS_BANKID_CDW,							-- メッセージ当初送信者  金融証券区分＋金融機関コード
    		coalesce((SELECT BANK_RNM FROM substrb04w
LEFT OUTER JOIN mbank m02 ON (SUBSTR(B04W.MSG_TS_BANKID_CDW,1,1) = M02.FINANCIAL_SECURITIES_KBN AND SUBSTR(B04W.MSG_TS_BANKID_CDW,2,4) = M02.BANK_CD)  ),' ')
                    AS MSG_TS_BANKID_RNM,	    			-- メッセージ当初送信者略称
    		B04W.COPYSEND_BANKID_CD1,						-- コピー送信先金融機関コード１
    		B04W.COPYSEND_BANKID_CD1W,						-- コピー送信先 金融証券区分＋金融機関コード１
    		coalesce((SELECT BANK_RNM FROM substrb04w
LEFT OUTER JOIN mbank m02 ON (SUBSTR(B04W.COPYSEND_BANKID_CD1W,1,1) = M02.FINANCIAL_SECURITIES_KBN AND SUBSTR(B04W.COPYSEND_BANKID_CD1W,2,4) = M02.BANK_CD)  ),' ')
                    AS COPYSEND_BANKID_RNM1,    			-- コピー送信先金融機関略称１
    		B04W.COPYSEND_BANKID_CD2,						-- コピー送信先金融機関コード２
    		B04W.COPYSEND_BANKID_CD2W,						-- コピー送信先 金融証券区分＋金融機関コード２
    		coalesce((SELECT BANK_RNM FROM substrb04w
LEFT OUTER JOIN mbank m02 ON (SUBSTR(B04W.COPYSEND_BANKID_CD2W,1,1) = M02.FINANCIAL_SECURITIES_KBN AND SUBSTR(B04W.COPYSEND_BANKID_CD2W,2,4) = M02.BANK_CD)  ),' ')
                    AS COPYSEND_BANKID_RNM2,    			-- コピー送信先金融機関略称２
    		B04W.COPYSEND_BANKID_CD3,						-- コピー送信先金融機関コード３
    		B04W.COPYSEND_BANKID_CD3W,						-- コピー送信先 金融証券区分＋金融機関コード３
    		coalesce((SELECT BANK_RNM FROM substrb04w
LEFT OUTER JOIN mbank m02 ON (SUBSTR(B04W.COPYSEND_BANKID_CD3W,1,1) = M02.FINANCIAL_SECURITIES_KBN AND SUBSTR(B04W.COPYSEND_BANKID_CD3W,2,4) = M02.BANK_CD)  ),' ')
                    AS COPYSEND_BANKID_RNM3,     			-- コピー送信先金融機関略称３
            VJ1.JIKO_DAIKO_KBN
    FROM vjiko_itaku vj1, (
        SELECT 	B04.ITAKU_KAISHA_CD,                            -- 委託会社コード
                --B04.ISIF_SHONIN_REFNO,							-- 新規記録情報承認REF.NO
                B04.KESSAI_NO,                                      -- 承認REFNo->決済NOへ変更
        --@s PENDING 新規記録情報.処理コード　項目無し
        --		B04.SHORI_CD,									-- 処理コード
        --		MCD1.CODE_NM AS SHORI_NM,						-- 処理コード名称
        --		'X' AS SHORI_CD,
        --		'XXXXX' AS SHORI_NM,
        --@e PENDING 新規記録情報.処理コード　項目無し
        		B04.SSI_MUKO_FLG_CD,							-- ＳＳＩ無効化フラグコード
        		B04.YAKUJO_YMD,									-- 約定年月日
        		B04.KESSAI_YMD,									-- 決済年月日
        		B04.HKUK_KNGK,									-- 引受金額
        		B04.HAKKO_KAGAKU,								-- 発行価額
        		B04.YAKUJO_KNGK,								-- 約定金額
        		B04.YAKUJO_TSUKA_CD,							-- 約定通貨
        		B04.KOKUNAI_TESU_KNGK,							-- 国内手数料金額
        		B04.KOKUNAI_TSUKA_CD,							-- 国内手数料通貨
        		B04.KOKUNAI_TESU_SZEI_KNGK,						-- 国内手数料消費税金額
        		B04.KOKUNAI_TESU_TSUKA_CD,						-- 国内手数料消費税通貨
        		B04.KEIKARISHI_KNGK,							-- 経過利子金額
        		B04.KESSAI_KNGK,								-- 決済金額
        		B04.KEIKARISHITSUKA_CD,							-- 経過利子金額通貨
        		B04.KESSAI_TSUKA_CD,							-- 決済金額通貨
        		B04.HAKKO_YMD,									-- 発行年月日
        		B04.SHOKAN_YMD,									-- 償還年月日
        		B04.RIRITSU,									-- 利率
        		B04.ISIN_CD,									-- ＩＳＩＮコード
--2006/06 ASK START/////////
				B04.SHORI_CD,                                   -- 処理コード
--2006/06 ASK END///////////
                B04.URI_BANKID_CD,								-- 売り手金融機関識別コード
                coalesce(pkIpaName.getBankCd(B04.ITAKU_KAISHA_CD,B04.URI_BANKID_CD,0),' ') AS URI_BANKID_CDW, -- 売り手  金融証券区分＋金融機関コード
                B04.KAI_BANKID_CD,								-- 買い手金融機関識別コード
                coalesce(pkIpaName.getBankCd(B04.ITAKU_KAISHA_CD,B04.KAI_BANKID_CD,0),' ') AS KAI_BANKID_CDW,	-- 買い手  金融証券区分＋金融機関コード
        		B04.FUND_CD,									-- ファンドコード
         		B04.WTS_KESSAIDAIRI_CD,							-- 渡方決済代理人コード
         		coalesce(pkIpaName.getBankCd(B04.ITAKU_KAISHA_CD,B04.WTS_KESSAIDAIRI_CD,0),' ') AS WTS_KESSAIDAIRI_CDW, -- 渡方決済代理人コード  金融証券区分＋金融機関コード
        		B04.TANKATYPE_CD,								-- 単価タイプコード
        		B04.FACTOR,										-- ファクター
        		B04.YAKUJO_RATE,								-- 約定利回り
        		B04.OWN_ITAKU_CD,								-- 自己委託コード（買い手）
        		B04.UKE_KESSAIDAIRI_CD,							-- 受方決済代理人コード
        		coalesce(pkIpaName.getBankCd(B04.ITAKU_KAISHA_CD,B04.UKE_KESSAIDAIRI_CD,0),' ') AS UKE_KESSAIDAIRI_CDW, -- 受方決済代理人コード  金融証券区分＋金融機関コード
        		B04.MSG_TS_BANKID_CD,							-- メッセージ当初送信者金融機関識別コード
        		coalesce(pkIpaName.getBankCd(B04.ITAKU_KAISHA_CD,B04.MSG_TS_BANKID_CD,0),' ') AS MSG_TS_BANKID_CDW, -- メッセージ当初送信者  金融証券区分＋金融機関コード
        		B04.COPYSEND_BANKID_CD1,						-- コピー送信先金融機関コード１
        		coalesce(pkIpaName.getBankCd(B04.ITAKU_KAISHA_CD,B04.COPYSEND_BANKID_CD1,0),' ') AS COPYSEND_BANKID_CD1W, -- コピー送信先  金融証券区分＋金融機関コード１
        		B04.COPYSEND_BANKID_CD2,						-- コピー送信先金融機関コード２
        		coalesce(pkIpaName.getBankCd(B04.ITAKU_KAISHA_CD,B04.COPYSEND_BANKID_CD2,0),' ') AS COPYSEND_BANKID_CD2W, -- コピー送信先  金融証券区分＋金融機関コード２
        		B04.COPYSEND_BANKID_CD3,						-- コピー送信先金融機関コード３
        		coalesce(pkIpaName.getBankCd(B04.ITAKU_KAISHA_CD,B04.COPYSEND_BANKID_CD3,0),' ') AS COPYSEND_BANKID_CD3W  -- コピー送信先  金融証券区分＋金融機関コード３
        FROM    SHINKIKIROKU B04
        WHERE
        B04.ITAKU_KAISHA_CD = l_inItakuKaishaCd
          AND   B04.KESSAI_NO = l_inKessaiNo
        ) b04w
LEFT OUTER JOIN mgr_kihon_view vmg1 ON (B04W.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD AND B04W.ISIN_CD = VMG1.ISIN_CD)
WHERE   --@s PENDING 新規記録情報.処理コード　項目無し
    --		AND 	B04W.SHORI_CD) = MCD1.CODE_VALUE)
    --		AND 	MCD1.CODE_SHUBETSU) = '546'
    --@e PENDING 新規記録情報.処理コード　項目無し
   VJ1.KAIIN_ID = B04W.ITAKU_KAISHA_CD;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp00503 START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(l_inItakuKaishaCd::text, '') = ''
	OR coalesce(l_inUserId::text, '') = ''
	OR coalesce(l_inChohyoKbn::text, '') = ''
	OR coalesce(l_inGyomuYmd::text, '') = ''
	THEN
		-- パラメータエラー
		CALL pkLog.error('ECM501', SP_ID, ' ');
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
--		pkLog.error(l_inUserId, REPORT_ID, 'SQLERRM:'||'');
		RETURN;
	END IF;
--
--	-- 帳票ワークの削除
--	DELETE FROM SREPORT_WK
--	WHERE	KEY_CD = l_inItakuKaishaCd
--	AND		USER_ID = l_inUserId
--	AND		CHOHYO_KBN = l_inChohyoKbn
--	AND		SAKUSEI_YMD = l_inGyomuYmd
--	AND		CHOHYO_ID = REPORT_ID;
--
--IP-05753 2007/12/11 START
	-- ヘッダーレコード存在チェック
	gHeaderSeqNo := spip00503_chkheaderseqno();
    -- 該当キーのデータが存在しないとき、ヘッダレコード登録
    IF gHeaderSeqNo = 1 THEN
    	-- ヘッダレコードを追加
    	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	END IF;
--IP-05753 2007/12/11 END
    -- 機構連携の取込時間を編集する。
    IF (l_inKkSakuseiDt IS NOT NULL AND l_inKkSakuseiDt::text <> '') THEN
        gKkSaikuseiYmd  := SUBSTR(l_inKkSakuseiDt,1,8);
        gKkSaikuseiTm   := SUBSTR(l_inKkSakuseiDt,9,6);
    END IF;
	-- データ取得
	FOR recMeisai IN curMeisai LOOP
		-- 帳票ワークに、同一決済番号のレコードが存在するかチェックする。
		-- 存在しない場合は0, 存在する場合は該当レコードのSEQ_NOが返却される。
		gExistSeqNo := spIp00503_chkExistSreportWk;
		IF gExistSeqNo = 0 THEN 		-- 存在しない場合
--IP-05753 2007/12/11 START			
			SELECT nextval('shinkikiroku_totsugo_seq') INTO STRICT gSeqNo;
--IP-05753 2007/12/11 END
			-- 帳票ワーク登録用のシーケンスに、カウントアップしたシーケンスをセット
			gInsSeqNo := gSeqNo;
		ELSE 						-- 存在する場合
			-- 帳票ワークの既存レコードを削除する。
			CALL spIp00503_delSreportWk();
			-- 帳票ワーク登録用のシーケンスに、削除したレコードのシーケンスをセット
			gInsSeqNo := gExistSeqNo;
		END IF;
		gUmuFlg := 1;
    	-- 代行なら委託会社略称取得
        IF recMeisai.JIKO_DAIKO_KBN = '2' THEN
        	gItakuKaishaRnm := pkKkNotice.getItakuKaishaRnm(l_inItakuKaishaCd);
        END IF;
		-- 書式フォーマットの設定
        -- 引受金額、約定金額は常に整数なので、日本円フォーマットを使用する。
		gFmtHakkoKngk	        := FMT_J;
		gFmtRbrKngk		        := spIp00503_getTsukaFmt(recMeisai.HAKKO_TSUKA_CD);
		gFmtShokanKngk	        := spIp00503_getTsukaFmt(recMeisai.HAKKO_TSUKA_CD);
		gFmtKokunaiTesuKngk	    := spIp00503_getTsukaFmt(recMeisai.KOKUNAI_TSUKA_CD);
		gFmtKokunaiTesuSzeiKngk	:= spIp00503_getTsukaFmt(recMeisai.KOKUNAI_TESU_TSUKA_CD);
		gFmtKeikarishiKngk	    := spIp00503_getTsukaFmt(recMeisai.KEIKARISHITSUKA_CD);
		gFmtKessaiKngk	        := spIp00503_getTsukaFmt(recMeisai.KESSAI_TSUKA_CD);
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := l_inKessaiNo;	-- 決済番号
		v_item.l_inItem003 := recMeisai.KESSAI_NO;	-- 新規記録情報承認REF.NO->決済NOへ変更
		v_item.l_inItem004 := recMeisai.SHORI_CD;	-- 処理コード
		v_item.l_inItem005 := recMeisai.SHORI_NM;	-- 処理コード名称
		v_item.l_inItem006 := 'ISIF';	-- 取引種類コード="ＩＳＩＦ"
		v_item.l_inItem007 := '新規記録';	-- 取引種類コード名称="新規記録"
		v_item.l_inItem008 := recMeisai.YAKUJO_YMD;	-- 約定年月日
		v_item.l_inItem009 := recMeisai.KESSAI_YMD;	-- 決済年月日
		v_item.l_inItem010 := recMeisai.KAI_BANKID_CD;	-- 買い手金融機関識別コード
		v_item.l_inItem011 := recMeisai.KAI_BANKID_RNM;	-- 買い手略称
		v_item.l_inItem012 := recMeisai.UKE_KESSAIDAIRI_CD;	-- 受方決済代理人コード
		v_item.l_inItem013 := recMeisai.UKE_KESSAIDAIRI_RNM;	-- 受方決済代理人略称
		v_item.l_inItem014 := recMeisai.OWN_ITAKU_CD;	-- 自己委託コード（買い手）
		v_item.l_inItem015 := recMeisai.OWN_ITAKU_NM;	-- 自己委託コード略称
		v_item.l_inItem016 := recMeisai.URI_BANKID_CD;	-- 売り手金融機関識別コード
		v_item.l_inItem017 := recMeisai.URI_BANKID_RNM;	-- 売り手略称
		v_item.l_inItem018 := recMeisai.WTS_KESSAIDAIRI_CD;	-- 渡方決済代理人コード
		v_item.l_inItem019 := recMeisai.WTS_KESSAIDAIRI_RNM;	-- 渡方決済代理人略称
		v_item.l_inItem020 := recMeisai.ISIN_CD;	-- ＩＳＩＮコード
		v_item.l_inItem021 := recMeisai.MGR_RNM;	-- 銘柄略称
		v_item.l_inItem022 := recMeisai.HAKKO_YMD;	-- 発行年月日
		v_item.l_inItem023 := recMeisai.SHOKAN_YMD;	-- 償還年月日
		v_item.l_inItem024 := recMeisai.RIRITSU;	-- 利率
		v_item.l_inItem025 := recMeisai.FACTOR;	-- ファクター
		v_item.l_inItem026 := recMeisai.SSI_MUKO_FLG_CD;	-- ＳＳＩ利用フラグ
		v_item.l_inItem027 := recMeisai.SSI_MUKO_FLG_NM;	-- ＳＳＩ利用フラグ名称
		v_item.l_inItem028 := recMeisai.FUND_CD;	-- ファンドコード
		v_item.l_inItem029 := recMeisai.HKUK_KNGK;	-- 引受金額
		v_item.l_inItem030 := recMeisai.HAKKO_KAGAKU;	-- 発行価額
		v_item.l_inItem031 := recMeisai.TANKATYPE_CD;	-- 単価タイプコード
		v_item.l_inItem032 := recMeisai.TANKATYPE_NM;	-- 単価タイプ名称
		v_item.l_inItem033 := recMeisai.YAKUJO_RATE;	-- 約定利回り
		v_item.l_inItem034 := recMeisai.YAKUJO_TSUKA_CD_NM;	-- 約定通貨
		v_item.l_inItem035 := recMeisai.YAKUJO_KNGK;	-- 約定金額
		v_item.l_inItem036 := recMeisai.KEIKARISHITSUKA_CD_NM;	-- 経過利子金額通貨
		v_item.l_inItem037 := recMeisai.KEIKARISHI_KNGK;	-- 経過利子金額
		v_item.l_inItem038 := recMeisai.KOKUNAI_TSUKA_CD_NM;	-- 国内手数料通貨
		v_item.l_inItem039 := recMeisai.KOKUNAI_TESU_KNGK;	-- 国内手数料金額
		v_item.l_inItem040 := recMeisai.KOKUNAI_TESU_TSUKA_CD_NM;	-- 国内手数料消費税通貨
		v_item.l_inItem041 := recMeisai.KOKUNAI_TESU_SZEI_KNGK;	-- 国内手数料消費税金額
		v_item.l_inItem042 := recMeisai.KESSAI_TSUKA_CD_NM;	-- 決済金額通貨
		v_item.l_inItem043 := recMeisai.KESSAI_KNGK;	-- 決済金額
		v_item.l_inItem044 := recMeisai.MSG_TS_BANKID_CD;	-- メッセージ当初送信者金融機関識別コード
		v_item.l_inItem045 := recMeisai.MSG_TS_BANKID_RNM;	-- メッセージ当初送信者略称
		v_item.l_inItem046 := recMeisai.COPYSEND_BANKID_CD1;	-- コピー送信先金融機関コード１
		v_item.l_inItem047 := recMeisai.COPYSEND_BANKID_RNM1;	-- コピー送信先金融機関略称１
		v_item.l_inItem048 := recMeisai.COPYSEND_BANKID_CD2;	-- コピー送信先金融機関コード２
		v_item.l_inItem049 := recMeisai.COPYSEND_BANKID_RNM2;	-- コピー送信先金融機関略称２
		v_item.l_inItem050 := recMeisai.COPYSEND_BANKID_CD3;	-- コピー送信先金融機関コード３
		v_item.l_inItem051 := recMeisai.COPYSEND_BANKID_RNM3;	-- コピー送信先金融機関略称３
		v_item.l_inItem052 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem053 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem054 := gFmtHakkoKngk;	-- 発行金額書式フォーマット
		v_item.l_inItem055 := gFmtRbrKngk;	-- 利払金額書式フォーマット
		v_item.l_inItem056 := gFmtShokanKngk;	-- 償還金額書式フォーマット
		v_item.l_inItem057 := l_inGyomuYmd;	-- 作成年月日
		v_item.l_inItem058 := gFmtKokunaiTesuKngk;	-- 国内手数料金額書式フォーマット
		v_item.l_inItem059 := gFmtKokunaiTesuSzeiKngk;	-- 国内手数料消費税書式フォーマット
		v_item.l_inItem060 := gFmtKeikarishiKngk;	-- 経過利子金額書式フォーマット
		v_item.l_inItem061 := gFmtKessaiKngk;	-- 決済金額書式フォーマット
		v_item.l_inItem062 := gKkSaikuseiYmd;	-- 機構連携作成日
		v_item.l_inItem063 := gKkSaikuseiTm;	-- 機構連携作成時間
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> gInsSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	END LOOP;
	IF gUmuFlg = 0 THEN
	-- 対象データなし
		gRtnCd := RTN_NODATA;
	ELSE
		-- バッチ帳票印刷管理テーブル登録
		CALL pkPrtOk.insertPrtOk(
			l_inUserId,
			l_inItakuKaishaCd,
			l_inGyomuYmd,
			pkPrtOk.LIST_SAKUSEI_KBN_ZUIJI(1),
			REPORT_ID);
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp00503 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		CALL pkLog.fatal('ECM701', SP_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal('ECM701', SP_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
--		RAISE;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip00503 ( l_inItakuKaishaCd TEXT, l_inKessaiNo TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE, l_outSqlCode OUT integer, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spip00503_chkexistsreportwk () RETURNS integer AS $body$
DECLARE

	l_seqNo		integer;

BEGIN
	SELECT
		SEQ_NO
	INTO STRICT
		l_seqNo
	FROM
		SREPORT_WK
	WHERE
		KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId 	-- 実際は'BATCH'固定
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = l_inGyomuYmd
		AND CHOHYO_ID = REPORT_ID
		AND ITEM002 = l_inKessaiNo;
	RETURN l_seqNo;
EXCEPTION
	WHEN no_data_found THEN
		-- 帳票ワークに同一決済番号のデータが存在しない場合は0を返却。
		l_seqNo := 0;
		RETURN l_seqNo;
	WHEN OTHERS THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spip00503_chkexistsreportwk () FROM PUBLIC;





CREATE OR REPLACE FUNCTION spip00503_chkheaderseqno () RETURNS integer AS $body$
DECLARE

	l_headerSeqNo	integer;

BEGIN
	SELECT
		SEQ_NO
	INTO STRICT
		l_headerSeqNo
	FROM
		SREPORT_WK
	WHERE
		KEY_CD = l_inItakuKaishaCd
		AND	USER_ID = l_inUserId
		AND	CHOHYO_KBN = l_inChohyoKbn
		AND	SAKUSEI_YMD = l_inGyomuYmd
		AND	CHOHYO_ID = REPORT_ID
		AND	SEQ_NO = 0
		AND	HEADER_FLG = 0;
	RETURN l_headerSeqNo;
EXCEPTION
	WHEN no_data_found THEN
		RETURN 1;
	WHEN OTHERS THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spip00503_chkheaderseqno () FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spip00503_delsreportwk () AS $body$
BEGIN
	DELETE
		FROM SREPORT_WK
	WHERE
		KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId 	-- 実際は'BATCH'固定
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = l_inGyomuYmd
		AND CHOHYO_ID = REPORT_ID
		AND SEQ_NO = gExistSeqNo;
EXCEPTION
	WHEN OTHERS THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip00503_delsreportwk () FROM PUBLIC;





CREATE OR REPLACE FUNCTION spip00503_gettsukafmt (l_inTsukaCd text) RETURNS varchar AS $body$
BEGIN
        -- 日本円と外貨でフォーマットが異なる 
	IF l_inTsukaCd = 'JPY' THEN
            RETURN FMT_J;
	ELSE
            RETURN FMT_F;
	END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spip00503_gettsukafmt (l_inTsukaCd text) FROM PUBLIC;