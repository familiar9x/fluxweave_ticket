




CREATE OR REPLACE PROCEDURE spip00501 ( l_inKessaiNo TEXT,		-- 決済番号
 l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inUserId TEXT,		-- ユーザーID
 l_inChohyoKbn TEXT,		-- 帳票区分
 l_inGyomuYmd TEXT,		-- 業務日付
 l_outSqlCode OUT integer,		-- リターン値
 l_outSqlErrM OUT text	-- エラーコメント
 ) AS $body$
DECLARE

--
--/* 著作権:Copyright(c)2004
--/* 会社名:JIP
--/* 概要　:機構からきた「新規記録情報通知」を受信時に、事前に登録済みの「新規記録情報」テーブル
--/* 　　　 データと突合せし、その結果をもとに新規記録情報突合結果リストを作成する。
--/* 引数　:l_inKessaiNo		IN	TEXT		決済番号
--/* 　　　 l_inItakuKaishaCd	IN	TEXT		委託会社コード
--/* 　　　 l_inUserId		IN	TEXT		ユーザーID
--/* 　　　 l_inChohyoKbn		IN	TEXT		帳票区分
--/* 　　　 l_inGyomuYmd		IN	TEXT		業務日付
--/* 　　　 l_outSqlCode		OUT	INTEGER		リターン値
--/* 　　　 l_outSqlErrM		OUT	VARCHAR	エラーコメント
--/* 返り値:なし
--/*
--***************************************************************************
--/* @version $Revision: 1.24 $
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*　2005.02.14	JIP				新規作成
--/*　2005.06.17	TOMITA			抽出条件を変更
--/*　2005.06.20	TOMITA			送信者RefNoを決済番号に変更
--/*　2005.07.04	KUWABARA		帳票ワークへINSERT時に新しいデータから出力させるように修正
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
	REPORT_ID			CONSTANT char(11)	:= 'IP030000511';			-- 帳票ID
	-- 書式フォーマット
	FMT_J	            CONSTANT varchar(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	-- 書式フォーマット（外資）
	FMT_F	            CONSTANT varchar(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 発行金額
	-- 対象データなし
	NO_DATA_STR			CONSTANT varchar(20) := '対象データなし';
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd				integer :=	RTN_OK;							-- リターンコード
	gSeqNo				integer := 0;								-- シーケンス(既存データ用)
	wk_SeqNo			integer := 0;								-- シーケンス(新しいデータ用)
	gUmuFlg				integer := 0;								-- データ有無フラグ
	-- 書式フォーマット
	gFmtHakkoKngk		    varchar(21) := NULL;						-- 発行金額
	gFmtRbrKngk			    varchar(21) := NULL;						-- 利払金額
	gFmtShokanKngk		    varchar(21) := NULL;						-- 償還金額
    gFmtKokunaiTesuKngk     varchar(21) := NULL;						-- 国内手数料金額
    gFmtKokunaiTesuSzeiKngk varchar(21) := NULL;						-- 国内手数料消費税
    gFmtKessaiKngk          varchar(21) := NULL;  					-- 決済金額
	gItakuKaishaRnm		VJIKO_ITAKU.BANK_RNM%TYPE;						-- 委託会社略称
--==============================================================================
--					カーソル定義													
--==============================================================================
	curMeisai CURSOR FOR
		SELECT	MCD1.CODE_NM AS TOTSUGO_KEKKA_NM,								-- 突合結果名称
				MG1.ISIN_CD,													-- ＩＳＩＮコード
				MG1.MGR_RNM,													-- 銘柄略称
				-- 発行代理人コードは、自行情報の金融機関コードより取得し設定する（突合時と表示項目を同じにするため）
				(SELECT BIC_CD_NOSHITEN
					from MBANK_ZOKUSEI
					where
						VJ1.KAIIN_ID = ITAKU_KAISHA_CD
						AND VJ1.OWN_FINANCIAL_SECURITIES_KBN = FINANCIAL_SECURITIES_KBN
						AND VJ1.OWN_BANK_CD = BANK_CD)AS HAKKO_DAIRI_BIC, 		-- 引受会社ＢＩＣ
				--VJ1.BIC_CD AS HAKKO_DAIRI_BIC,									-- 発行代理人ＢＩＣ
				VJ1.HAKKODAIRI_CD AS HAKKO_DAIRI_CD,							-- 発行代理人コード
				VJ1.BANK_RNM AS HAKKO_DAIRI_RNM,								-- 発行代理人略称
				(SELECT BIC_CD_NOSHITEN
					from MBANK_ZOKUSEI
					where
						B01.ITAKU_KAISHA_CD = ITAKU_KAISHA_CD
						AND B01.FINANCIAL_SECURITIES_KBN = FINANCIAL_SECURITIES_KBN
						AND B01.BANK_CD = BANK_CD)AS HKUK_KAISHA_BIC, 			-- 引受会社ＢＩＣ
				B01.FINANCIAL_SECURITIES_KBN || B01.BANK_CD AS HKUK_KAISHA_CD,	-- 引受会社コード
				(select BANK_RNM
					from MBANK
					where B01.FINANCIAL_SECURITIES_KBN = FINANCIAL_SECURITIES_KBN
						AND B01.BANK_CD = BANK_CD) AS HKUK_KAISHA_RNM, 			-- 引受会社略称
				MG1.HAKKO_YMD AS IPA_HAKKO_YMD,									-- 発行年月日
				(select CODE_NM from SCODE
					where B01.SSI_MUKO_FLG_CD = CODE_VALUE
					AND 	CODE_SHUBETSU = '535') AS IPA_SSI_MUKO_FLG_NM, 		-- ＩＰＡ_ＳＳＩ無効化フラグ名称
				B01.HKUK_KNGK AS IPA_HKUK_KNGK,									-- 引受金額
				MG1.HAKKO_KAGAKU AS IPA_HAKKO_KAGAKU,							-- 発行価格
				MG1.HAKKO_TSUKA_CD,												-- 発行通貨コード
				MG1.RBR_TSUKA_CD,												-- 利払通貨コード
				MG1.SHOKAN_TSUKA_CD,											-- 償還通貨コード
				(SELECT TSUKA_NM FROM MTSUKA M64
					WHERE M64.TSUKA_CD = MG1.HAKKO_TSUKA_CD) AS HAKKO_TSUKA_NM,	-- 発行通貨名称
				B01.YAKUJO_KNGK AS IPA_YAKUJO_KNGK,								-- 約定金額
				B01.KOKUNAI_TESU_KNGK AS IPA_KOKUNAI_TESU_KNGK,					-- 国内手数料金額
				B01.KOKUNAI_TESU_SZEI_KNGK AS IPA_KOKUNAI_TESU_SZEI_KNGK,		-- 国内手数料消費税金額
				B01.KESSAI_KNGK AS IPA_KESSAI_KNGK,								-- 決済金額
				B01.FUND_CD AS IPA_FUND_CD,										-- ファンドコード
--2006/06 ASK START/////////
				B04.SHORI_CD,                                                   -- 処理コード
--2006/06 ASK END///////////
				B04.ISIN_CD AS ISIN_MGR_CD,										-- ＩＳＩＮ銘柄コード
				B04.URI_BANKID_CD,												-- 売り手金融機関識別コード
				B04.KAI_BANKID_CD,												-- 買い手金融機関識別コード
				MCD3.CODE_NM AS KIKO_SSI_MUKO_FLG_NM,							-- 機構_ＳＳＩ無効化フラグ名称
				B04.KESSAI_YMD AS KIKO_KESSAI_YMD,								-- 決済年月日
				B04.HKUK_KNGK AS KIKO_HKUK_KNGK,								-- 引受金額
				B04.HAKKO_KAGAKU AS KIKO_HAKKO_KAGAKU,							-- 発行価額
				B04.YAKUJO_TSUKA_CD,										-- 約定通貨
				B04.YAKUJO_KNGK AS KIKO_YAKUJO_KNGK,							-- 約定金額
                CASE
                    WHEN COALESCE((SELECT TSUKA_NM FROM MTSUKA WHERE TSUKA_CD = B04.YAKUJO_TSUKA_CD), '') = '' THEN
                        B04.YAKUJO_TSUKA_CD
                    ELSE (SELECT TSUKA_NM FROM MTSUKA WHERE TSUKA_CD = B04.YAKUJO_TSUKA_CD)
                END AS YAKUJO_TSUKA_CD_NM,                                      -- 約定通貨名称
   				B04.KOKUNAI_TSUKA_CD,									-- 国内手数料通貨
				B04.KOKUNAI_TESU_KNGK AS KIKO_KOKUNAI_TESU_KNGK,				-- 国内手数料金額
                CASE
                    WHEN COALESCE((SELECT TSUKA_NM FROM MTSUKA WHERE TSUKA_CD = B04.KOKUNAI_TSUKA_CD), '') = '' THEN
                        B04.KOKUNAI_TSUKA_CD
                    ELSE (SELECT TSUKA_NM FROM MTSUKA WHERE TSUKA_CD = B04.KOKUNAI_TSUKA_CD)
                END AS KOKUNAI_TSUKA_CD_NM,                                     -- 国内手数料通貨名称
				B04.KOKUNAI_TESU_TSUKA_CD,										-- 国内手数料消費税通貨
				B04.KOKUNAI_TESU_SZEI_KNGK AS KIKO_KOKUNAI_TESU_SZEI_KNGK,		-- 国内手数料消費税金額
                CASE
                    WHEN COALESCE((SELECT TSUKA_NM FROM MTSUKA WHERE TSUKA_CD = B04.KOKUNAI_TESU_TSUKA_CD), '') = '' THEN
                        B04.KOKUNAI_TESU_TSUKA_CD
                    ELSE (SELECT TSUKA_NM FROM MTSUKA WHERE TSUKA_CD = B04.KOKUNAI_TESU_TSUKA_CD)
                END AS KOKUNAI_TESU_TSUKA_CD_NM,                                -- 国内手数料消費税通貨名称
				B04.KESSAI_TSUKA_CD,										-- 決済金額通貨
				B04.KESSAI_KNGK AS KIKO_KESSAI_KNGK,							-- 決済金額
                CASE
                    WHEN COALESCE((SELECT TSUKA_NM FROM MTSUKA WHERE TSUKA_CD = B04.KESSAI_TSUKA_CD), '') = '' THEN
                        B04.KESSAI_TSUKA_CD
                    ELSE (SELECT TSUKA_NM FROM MTSUKA WHERE TSUKA_CD = B04.KESSAI_TSUKA_CD)
                END AS KESSAI_TSUKA_CD_NM,                                      -- 決済金額通貨名称
				B04.RECEP_DT,													-- 受信日時
				B04.FUND_CD AS KIKO_FUND_CD,									-- ファンドコード
				B04.ISIF_SHONIN_REFNO,											-- 新規記録情報承認REF.NO
				VJ1.BANK_RNM,													-- 銀行略称
				VJ1.JIKO_DAIKO_KBN, 											-- 自行代行区分
        		B04.TOTSUGO_KEKKA_KBN AS totsugoKekkaKbn      -- 突合結果区分(コード)
		FROM vjiko_itaku vj1, scode mcd3, scode mcd1, shinkikiroku b04
LEFT OUTER JOIN mgr_kihon mg1 ON (B04.ISIN_CD = MG1.ISIN_CD AND B04.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD)
LEFT OUTER JOIN shinkiboshu b01 ON (B04.KESSAI_NO = B01.KESSAI_NO)
WHERE B04.KESSAI_NO = l_inKessaiNo AND B04.ITAKU_KAISHA_CD = l_inItakuKaishaCd    AND VJ1.KAIIN_ID = l_inItakuKaishaCd AND B04.TOTSUGO_KEKKA_KBN = MCD1.CODE_VALUE AND MCD1.CODE_SHUBETSU = '141' AND B04.SSI_MUKO_FLG_CD = MCD3.CODE_VALUE AND MCD3.CODE_SHUBETSU = '535' ORDER BY
              B01.TOTSUGO_KEKKA_KBN DESC,
              MG1.ISIN_CD ASC;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp00501 START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inKessaiNo)::text, '') = ''
	OR coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inUserId)::text, '') = ''
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''
	OR coalesce(trim(both l_inGyomuYmd)::text, '') = ''
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error(l_inUserId, REPORT_ID, 'SQLERRM:'||'');
		RETURN;
	END IF;
	-- 帳票ワークの削除 ('対象データなし'のレコードとヘッダデータ)
	DELETE FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID
	AND (ITEM049 = NO_DATA_STR
	OR		HEADER_FLG = '0');
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	-- データ取得
	FOR recMeisai IN curMeisai LOOP
-- IP-05753 START
		-- シーケンス番号の取得
		SELECT nextval('shinkikiroku_totsugo_seq') INTO STRICT wk_SeqNo;
-- IP-05753 END
		gUmuFlg := 1;
		-- 書式フォーマットの設定
        -- 引受金額、約定金額は常に整数なので、日本円フォーマットを使用する。
		gFmtHakkoKngk	        := spIp00501_getTsukaFmt(recMeisai.HAKKO_TSUKA_CD);
		gFmtRbrKngk		        := spIp00501_getTsukaFmt(recMeisai.RBR_TSUKA_CD);
		gFmtShokanKngk	        := spIp00501_getTsukaFmt(recMeisai.SHOKAN_TSUKA_CD);
		gFmtKokunaiTesuKngk	    := spIp00501_getTsukaFmt(recMeisai.KOKUNAI_TSUKA_CD);
		gFmtKokunaiTesuSzeiKngk	:= spIp00501_getTsukaFmt(recMeisai.KOKUNAI_TESU_TSUKA_CD);
		gFmtKessaiKngk	        := spIp00501_getTsukaFmt(recMeisai.KESSAI_TSUKA_CD);
		-- 委託会社略称
		gItakuKaishaRnm := NULL;
        -- 自行代行区分が代行のときは委託会社略称を出力する。
		IF recMeisai.JIKO_DAIKO_KBN = '2' THEN
			gItakuKaishaRnm := recMeisai.BANK_RNM;
		END IF;
    IF recMeisai.totsugoKekkaKbn = '3' THEN
       recMeisai.ISIN_CD                      := NULL;
       recMeisai.MGR_RNM						          := NULL;
       recMeisai.HAKKO_DAIRI_BIC		          := NULL;
       recMeisai.HAKKO_DAIRI_CD			          := NULL;
       recMeisai.HAKKO_DAIRI_RNM		          := NULL;
       recMeisai.HKUK_KAISHA_BIC 		          := NULL;
       recMeisai.HKUK_KAISHA_CD			          := NULL;
       recMeisai.HKUK_KAISHA_RNM		          := NULL;
       recMeisai.IPA_HAKKO_YMD			          := NULL;
       recMeisai.IPA_SSI_MUKO_FLG_NM			    := NULL;
       recMeisai.IPA_HKUK_KNGK					      := NULL;
       recMeisai.IPA_HAKKO_KAGAKU				      := NULL;
       recMeisai.HAKKO_TSUKA_NM				        := NULL;
       recMeisai.IPA_YAKUJO_KNGK				      := NULL;
       recMeisai.HAKKO_TSUKA_NM				        := NULL;
       recMeisai.IPA_KOKUNAI_TESU_KNGK			  := NULL;
       recMeisai.HAKKO_TSUKA_NM				        := NULL;
       recMeisai.IPA_KOKUNAI_TESU_SZEI_KNGK   := NULL;
       recMeisai.HAKKO_TSUKA_NM				        := NULL;
       recMeisai.IPA_KESSAI_KNGK			        := NULL;
       recMeisai.IPA_FUND_CD					        := NULL;
    END IF;
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID
	AND		ITEM002 = l_inKessaiNo;
		-- 帳票ワークへデータを追加
		-- 一番新しいデータが一番上にくるようにする
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := l_inKessaiNo;	-- 決済番号
		v_item.l_inItem003 := gSeqNo - 1;	-- 連番
		v_item.l_inItem004 := recMeisai.TOTSUGO_KEKKA_NM;	-- 突合結果名称
		v_item.l_inItem005 := recMeisai.ISIN_CD;	-- （ＩＰＡ）ＩＳＩＮコード
		v_item.l_inItem006 := recMeisai.MGR_RNM;	-- （ＩＰＡ）銘柄略称
		v_item.l_inItem007 := recMeisai.HAKKO_DAIRI_BIC;	-- （ＩＰＡ）発行代理人ＢＩＣ
		v_item.l_inItem008 := recMeisai.HAKKO_DAIRI_CD;	-- （ＩＰＡ）発行代理人コード
		v_item.l_inItem009 := recMeisai.HAKKO_DAIRI_RNM;	-- （ＩＰＡ）発行代理人略称
		v_item.l_inItem010 := recMeisai.HKUK_KAISHA_BIC;	-- （ＩＰＡ）引受会社ＢＩＣ
		v_item.l_inItem011 := recMeisai.HKUK_KAISHA_CD;	-- （ＩＰＡ）引受会社コード
		v_item.l_inItem012 := recMeisai.HKUK_KAISHA_RNM;	-- （ＩＰＡ）引受会社略称
		v_item.l_inItem013 := recMeisai.IPA_HAKKO_YMD;	-- （ＩＰＡ）発行年月日
		v_item.l_inItem014 := recMeisai.IPA_SSI_MUKO_FLG_NM;	-- （ＩＰＡ）ＩＰＡ_ＳＳＩ無効化フラグ名称
		v_item.l_inItem015 := recMeisai.IPA_HKUK_KNGK;	-- （ＩＰＡ）引受金額
		v_item.l_inItem016 := recMeisai.IPA_HAKKO_KAGAKU;	-- （ＩＰＡ）発行価格
		v_item.l_inItem017 := recMeisai.HAKKO_TSUKA_NM;	-- （ＩＰＡ）発行通貨名称
		v_item.l_inItem018 := recMeisai.IPA_YAKUJO_KNGK;	-- （ＩＰＡ）約定金額
		v_item.l_inItem019 := recMeisai.HAKKO_TSUKA_NM;	-- （ＩＰＡ）発行通貨名称
		v_item.l_inItem020 := recMeisai.IPA_KOKUNAI_TESU_KNGK;	-- （ＩＰＡ）国内手数料金額
		v_item.l_inItem021 := recMeisai.HAKKO_TSUKA_NM;	-- （ＩＰＡ）発行通貨名称
		v_item.l_inItem022 := recMeisai.IPA_KOKUNAI_TESU_SZEI_KNGK;	-- （ＩＰＡ）国内手数料消費税金額
		v_item.l_inItem023 := recMeisai.HAKKO_TSUKA_NM;	-- （ＩＰＡ）発行通貨名称
		v_item.l_inItem024 := recMeisai.IPA_KESSAI_KNGK;	-- （ＩＰＡ）決済金額
		v_item.l_inItem025 := recMeisai.IPA_FUND_CD;	-- （ＩＰＡ）ファンドコード
		v_item.l_inItem026 := recMeisai.ISIN_MGR_CD;	-- （機構）ＩＳＩＮ銘柄コード
		v_item.l_inItem027 := recMeisai.URI_BANKID_CD;	-- （機構）売り手金融機関識別コード
		v_item.l_inItem028 := recMeisai.KAI_BANKID_CD;	-- （機構）買い手金融機関識別コード
		v_item.l_inItem029 := recMeisai.KIKO_KESSAI_YMD;	-- （機構）決済年月日
		v_item.l_inItem030 := recMeisai.KIKO_SSI_MUKO_FLG_NM;	-- （機構）機構_ＳＳＩ無効化フラグ名称
		v_item.l_inItem031 := recMeisai.KIKO_HKUK_KNGK;	-- （機構）引受金額
		v_item.l_inItem032 := recMeisai.KIKO_HAKKO_KAGAKU;	-- （機構）発行価額
		v_item.l_inItem033 := recMeisai.YAKUJO_TSUKA_CD_NM;	-- （機構）約定通貨
		v_item.l_inItem034 := recMeisai.KIKO_YAKUJO_KNGK;	-- （機構）約定金額
		v_item.l_inItem035 := recMeisai.KOKUNAI_TSUKA_CD_NM;	-- （機構）国内手数料通貨
		v_item.l_inItem036 := recMeisai.KIKO_KOKUNAI_TESU_KNGK;	-- （機構）国内手数料金額
		v_item.l_inItem037 := recMeisai.KOKUNAI_TESU_TSUKA_CD_NM;	-- （機構）国内手数料消費税通貨
		v_item.l_inItem038 := recMeisai.KIKO_KOKUNAI_TESU_SZEI_KNGK;	-- （機構）国内手数料消費税金額
		v_item.l_inItem039 := recMeisai.KESSAI_TSUKA_CD_NM;	-- （機構）決済金額通貨
		v_item.l_inItem040 := recMeisai.KIKO_KESSAI_KNGK;	-- （機構）決済金額
		v_item.l_inItem041 := recMeisai.KIKO_FUND_CD;	-- （機構）ファンドコード
		v_item.l_inItem042 := recMeisai.RECEP_DT;	-- （機構）受信日時
		v_item.l_inItem043 := l_inKessaiNo;	-- 決済番号
		v_item.l_inItem044 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem045 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem046 := gFmtHakkoKngk;	-- 発行金額書式フォーマット
		v_item.l_inItem047 := gFmtRbrKngk;	-- 利払金額書式フォーマット
		v_item.l_inItem048 := gFmtShokanKngk;	-- 償還金額書式フォーマット
		v_item.l_inItem050 := l_inGyomuYmd;	-- データ基準日
		v_item.l_inItem051 := gFmtKokunaiTesuKngk;	-- 国内手数料金額書式フォーマット
		v_item.l_inItem052 := gFmtKokunaiTesuSzeiKngk;	-- 国内手数料消費税書式フォーマット
		v_item.l_inItem053 := gFmtKessaiKngk;	-- 決済金額書式フォーマット
		v_item.l_inItem054 := recMeisai.SHORI_CD;	-- 処理コード
		v_item.l_inItem055 := pkIpaName.getBankCd(l_inItakuKaishaCd, recMeisai.URI_BANKID_CD, 0);	-- （機構）売り手金融機関コード
		v_item.l_inItem056 := pkIpaName.getBankRnm(l_inItakuKaishaCd, recMeisai.URI_BANKID_CD, 0, 0);	-- （機構）売り手金融機関略称
		v_item.l_inItem057 := pkIpaName.getBankCd(l_inItakuKaishaCd, recMeisai.KAI_BANKID_CD, 0);	-- （機構）買い手金融機関コード
		v_item.l_inItem058 := pkIpaName.getBankRnm(l_inItakuKaishaCd, recMeisai.KAI_BANKID_CD, 0, 0);	-- （機構）買い手金融機関略称
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> wk_SeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	END LOOP;
	IF gUmuFlg = 0 THEN
	-- 対象データなし
		gRtnCd := RTN_NODATA;
		IF gSeqNo = 0 THEN
    		-- 帳票ワークにデータが存在しないとき、'対象データなし'レコードを追加
    				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem045 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem046 := FMT_J;	-- 発行金額書式フォーマット
		v_item.l_inItem047 := FMT_J;	-- 利払金額書式フォーマット
		v_item.l_inItem048 := FMT_J;	-- 償還金額書式フォーマット
		v_item.l_inItem049 := NO_DATA_STR;
		v_item.l_inItem050 := l_inGyomuYmd;	-- データ基準日
		
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
	END IF;
    -- バッチ帳票印刷管理テーブル登録
    CALL pkPrtOk.insertPrtOk(
            l_inUserId,
            l_inItakuKaishaCd,
            l_inGyomuYmd,
            pkPrtOk.LIST_SAKUSEI_KBN_ZUIJI(),
            REPORT_ID);
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp00501 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip00501 ( l_inKessaiNo TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spip00501_gettsukafmt (l_inTsukaCd text) RETURNS varchar AS $body$
DECLARE
	FMT_J	CONSTANT varchar(18) := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	FMT_F	CONSTANT varchar(21) := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 発行金額（外資）
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
-- REVOKE ALL ON FUNCTION spip00501_gettsukafmt (l_inTsukaCd text) FROM PUBLIC;