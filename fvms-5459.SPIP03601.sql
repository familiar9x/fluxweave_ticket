




CREATE OR REPLACE PROCEDURE spip03601 ( l_inKessaiYmdF TEXT,		-- 決済日(FROM)
 l_inKessaiYmdT TEXT,		-- 決済日(TO)
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
--/*
--/* 概要　:資金決済関連帳票出力指示画面の入力条件により、払込金交付管理表を作成する
--/*
--/* 引数　:l_inKessaiYmdF	IN	TEXT		決済日(FROM)
--/* 　　　 l_inKessaiYmdT	IN	TEXT		決済日(TO)
--/* 　　　 l_inItakuKaishaCd	IN	TEXT		委託会社コード
--/* 　　　 l_inUserId		IN	TEXT		ユーザーID
--/* 　　　 l_inChohyoKbn		IN	TEXT		帳票区分
--/* 　　　 l_inGyomuYmd		IN	TEXT		業務日付
--/* 　　　 l_outSqlCode		OUT	INTEGER		リターン値
--/* 　　　 l_outSqlErrM		OUT	VARCHAR	エラーコメント
--/*
--/* 返り値:なし
--/* @version $Id: SPIP03601.SQL,v 1.29 2008/10/31 01:51:25 morita Exp $
--/*
--***************************************************************************
--/* ログ　:
--/* 　　　日付	開発者名		目的
--/* -------------------------------------------------------------------
--/*	2005.05.25	JIP	川田愛		決済日FROMとTOが入力されていなくても
--/*					帳票が出力されるように訂正
--/*
--/*	2005.06.14	秋山 純一
--/*				決済日FROMとTOのどちらかが入力されていなくても、
--/*				決済日の最大・最小で検索されるように修正。
--/*
--/*	2017.01.10	JIP	周			口座店番追加対応。
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
	RTN_OK				CONSTANT integer		:= 0;					-- 正常
	RTN_NG				CONSTANT integer		:= 1;					-- 予期したエラー
	RTN_NODATA			CONSTANT integer		:= 2;					-- データなし
	RTN_FATAL			CONSTANT integer		:= 99;					-- 予期せぬエラー
	REPORT_ID			CONSTANT char(11)		:= 'IP030003611';		-- 帳票ID
	-- 書式フォーマット
	FMT_HAKKO_KNGK_J	CONSTANT char(21)	:= 'Z,ZZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	FMT_RBR_KNGK_J		CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 利払金額
	FMT_SHOKAN_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 償還金額
	-- 書式フォーマット（外資）
	FMT_HAKKO_KNGK_F	CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 発行金額
	FMT_RBR_KNGK_F		CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 利払金額
	FMT_SHOKAN_KNGK_F	CONSTANT char(21)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';	-- 償還金額
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd				integer :=	RTN_OK;							-- リターンコード
	gSeqNo				integer := 0;								-- シーケンス
	-- 決済日がNULLの時の処理用変数
	gKessaiYmdF varchar(8) := NULL; -- 決済日(始点)
	gKessaiYmdT varchar(8) := NULL; -- 決済日(終点)
	-- 書式フォーマット
	gFmtHakkoKngk		varchar(21)	:= NULL;					-- 発行金額
	gFmtRbrKngk			varchar(21)	:= NULL;					-- 利払金額
	gFmtShokanKngk		varchar(21)	:= NULL;					-- 償還金額
	gHrikmkozaTenNo		char(4)			:= NULL;					-- 口座店
	gKozaKamokuNm		varchar(6)		:= NULL;					-- 口座科目名称
	gKozaNo				char(7)			:= NULL;					-- 口座番号
	gKozaMeigininNm		MHAKKOTAI.HKT_KOZA_MEIGININ_NM%TYPE	:= NULL;-- 口座名義人
	gItakuKaishaRnm		VJIKO_ITAKU.BANK_RNM%TYPE;						-- 委託会社略称
	gChohyoSortFlg		MPROCESS_CTL.CTL_VALUE%TYPE;					-- 発行体宛帳票ソート順変更フラグ
--==============================================================================
--					カーソル定義													
--==============================================================================
	curMeisai CURSOR FOR
		SELECT	VMG0.HAKKO_YMD,									-- 発行年月日
				MG8.NYUKIN_KOZA_KBN,							-- 入金口座選択区分(資金決済方法)
				MCD1.CODE_NM AS SKN_KESSAI_METHOD_NM,			-- 資金決済方法名称
				VMG0.HAKKO_TSUKA_CD,								-- 発行通貨コード
				VMG0.RBR_TSUKA_CD,								-- 利払通貨コード
				VMG0.SHOKAN_TSUKA_CD,							-- 償還通貨コード
				M64.TSUKA_NM AS HAKKO_TSUKA_NM,					-- 発行通貨名称
				M01.HKT_CD,										-- 発行体コード
				M01.KOZA_TEN_CD,								-- 口座店店番
				M01.KOZA_TEN_CIFCD,								-- 口座店CIFコード
				M01.HKT_RNM,									-- 発行体略称
				VMG0.ISIN_CD,									-- ＩＳＩＮコード
				VMG0.MGR_CD,									-- 銘柄コード
				VMG0.MGR_RNM,									-- 銘柄略称
				VMG0.SHASAI_TOTAL,								-- 社債の総額
				VMG0.SHASAI_TOTAL * VMG0.HAKKO_KAGAKU
					/ 100 - coalesce(WK1.TESU_KNGK_GOKEI, 0) AS HRKM_KNGK,	-- 払込金額
				VMG0.SKN_CHG_YMD,								-- 資金振替日
				VMG0.SKN_KOFU_YMD,								-- 資金交付日
				M01.HKT_KOZA_KAMOKU_CD,							-- 発行体預金口座_口座科目コード
				MCD2.CODE_NM AS HKT_KOZA_KAMOKU_NM,				-- 発行体預金口座_口座科目名称
				M01.HKT_KOZA_NO,								-- 発行体預金口座_口座番号
				M01.HKT_KOZA_MEIGININ_NM,						-- 発行体預金口座_口座名義人
				M01.BD_KOZA_KAMOKU_CD,							-- 専用別段口座_口座科目コード
				MCD3.CODE_NM AS BD_KOZA_KAMOKU_NM,				-- 専用別段口座_口座科目名称
				M01.BD_KOZA_NO,									-- 専用別段口座_口座番号
				M01.BD_KOZA_MEIGININ_NM,						-- 専用別段口座_口座名義人
				VJ1.BANK_RNM,									-- 銀行略称
				VJ1.JIKO_DAIKO_KBN  								-- 自行代行区分
				----追加　2017/01/10　START
				,BT01.BD_KOZA_TEN_CD 							-- 専用別段口座_口座店コード
				,BT01.HKT_KOZA_TEN_CD 							-- 発行体預金口座_口座店コード
				----追加　2017/01/10　END
		FROM vjiko_itaku vj1, mgr_tesuryo_prm mg8, scode mcd1, mtsuka m64, mhakkotai2 bt01, mgr_kihon_view vmg0
LEFT OUTER JOIN (SELECT
						SUM(
							 -- 全体手数料額税込に補正額を反映させるか判断する関数を使用
							PKIPACALCTESURYO.getHoseiKasanKngk(
								(T01.ALL_TESU_KNGK + T01.ALL_TESU_SZEI),
								(T01.HOSEI_ALL_TESU_KNGK + T01.HOSEI_ALL_TESU_SZEI),
								T01.DATA_SAKUSEI_KBN,
								T01.SHORI_KBN
							)
						) AS TESU_KNGK_GOKEI,					-- 手数料合計
						T01.ITAKU_KAISHA_CD,					-- 委託会社コード
						T01.MGR_CD 								-- 銘柄コード
				 FROM	MGR_KIHON_VIEW VMG0,
						TESURYO T01,
						MGR_TESURYO_CTL MG7
				 WHERE	VMG0.HAKKO_YMD	BETWEEN gKessaiYmdF
											AND gKessaiYmdT
				 AND	VMG0.MGR_CD = MG7.MGR_CD
				 AND	VMG0.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD
				 AND	MG7.MGR_CD = T01.MGR_CD
				 AND	MG7.TESU_SHURUI_CD = T01.TESU_SHURUI_CD
				 AND	MG7.ITAKU_KAISHA_CD = T01.ITAKU_KAISHA_CD
				 AND	T01.TESU_SASHIHIKI_KBN = '1'
				 GROUP BY	T01.ITAKU_KAISHA_CD,
							T01.MGR_CD
				) wk1 ON (VMG0.MGR_CD = WK1.MGR_CD AND VMG0.ITAKU_KAISHA_CD = WK1.ITAKU_KAISHA_CD)
, mhakkotai m01
LEFT OUTER JOIN scode mcd2 ON (M01.HKT_KOZA_KAMOKU_CD = MCD2.CODE_VALUE AND '707' = MCD2.CODE_SHUBETSU)
LEFT OUTER JOIN scode mcd3 ON (M01.BD_KOZA_KAMOKU_CD = MCD3.CODE_VALUE AND '707' = MCD3.CODE_SHUBETSU)
WHERE VMG0.HAKKO_YMD BETWEEN gKessaiYmdF AND gKessaiYmdT AND VMG0.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND VMG0.HKT_CD = M01.HKT_CD AND VMG0.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD AND VJ1.KAIIN_ID = l_inItakuKaishaCd   AND VMG0.HAKKO_TSUKA_CD = M64.TSUKA_CD AND VMG0.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD AND VMG0.MGR_CD = MG8.MGR_CD AND VMG0.MGR_STAT_KBN = '1' AND (trim(both VMG0.ISIN_CD) IS NOT NULL AND (trim(both VMG0.ISIN_CD))::text <> '') AND MG8.NYUKIN_KOZA_KBN = MCD1.CODE_VALUE AND MCD1.CODE_SHUBETSU = '122'     AND VMG0.TOKUREI_SHASAI_FLG = 'N' AND VMG0.JTK_KBN NOT IN ('2','5') 	-- 副受託・自社発行は対象外
  AND NOT((VMG0.SAIKEN_SHURUI IN ('80','89')) AND (VMG0.HAKKO_KAGAKU = 0))   -- 振替ＣＢ銘柄で発行価額０は対象外
	----追加　2017/01/10　START
  AND M01.ITAKU_KAISHA_CD = BT01.ITAKU_KAISHA_CD AND M01.HKT_CD = BT01.HKT_CD ----追加　2017/01/10　END
 ORDER BY	VMG0.HAKKO_YMD,
					MCD1.CODE_SORT,
					VMG0.HAKKO_TSUKA_CD,
					CASE WHEN  gChohyoSortFlg ='1' THEN  M01.HKT_KANA_RNM   ELSE M01.HKT_CD END ,
					M01.HKT_CD,
					CASE WHEN  gChohyoSortFlg ='1' THEN  VMG0.MGR_CD   ELSE VMG0.ISIN_CD END;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp03601 START');	END IF;
	-- 入力パラメータのチェック
	-- 決済日(始点)が入力されなかった際の処理
	IF coalesce(l_inKessaiYmdF::text, '') = ''
	THEN
		SELECT trim(both MIN(MG1.HAKKO_YMD)) INTO STRICT gKessaiYmdF FROM MGR_KIHON MG1;
	ELSE
		gKessaiYmdF := l_inKessaiYmdF;
	END IF;
	-- 決済日(終点)が入力されなかった際の処理
	IF coalesce(l_inKessaiYmdT::text, '') = ''
	THEN
		SELECT trim(both MAX(MG1.HAKKO_YMD)) INTO STRICT gKessaiYmdT FROM MGR_KIHON MG1;
	ELSE
		gKessaiYmdT := l_inKessaiYmdT;
	END IF;
	-- その他の入力パラメータのチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inUserId)::text, '') = ''
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''
	OR coalesce(trim(both l_inGyomuYmd)::text, '') = ''
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM701', REPORT_ID, 'SQLERRM:'||'');
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
	-- 委託会社略称
	gItakuKaishaRnm := NULL;
	BEGIN
		SELECT BANK_RNM INTO STRICT gItakuKaishaRnm FROM VJIKO_ITAKU
		WHERE  KAIIN_ID = l_inItakuKaishaCd
		AND    JIKO_DAIKO_KBN = '2';
	EXCEPTION
		WHEN OTHERS THEN
		gItakuKaishaRnm := NULL;
	END;
	--発行体宛帳票ソート順変更フラグ取得
	gChohyoSortFlg := pkControl.getCtlValue(l_inItakuKaishaCd, 'SeikyusyoSort', '0');
	-- データ取得
	FOR recMeisai IN curMeisai LOOP
		gSeqNo := gSeqNo + 1;
		-- 書式フォーマットの設定
		-- 発行
		IF recMeisai.HAKKO_TSUKA_CD = 'JPY' THEN
			gFmtHakkoKngk := FMT_HAKKO_KNGK_J;
		ELSE
			gFmtHakkoKngk := FMT_HAKKO_KNGK_F;
		END IF;
		-- 利払
		IF recMeisai.RBR_TSUKA_CD = 'JPY' THEN
			gFmtRbrKngk := FMT_RBR_KNGK_J;
		ELSE
			gFmtRbrKngk := FMT_RBR_KNGK_F;
		END IF;
		-- 償還
		IF recMeisai.SHOKAN_TSUKA_CD = 'JPY' THEN
			gFmtShokanKngk := FMT_SHOKAN_KNGK_J;
		ELSE
			gFmtShokanKngk := FMT_SHOKAN_KNGK_F;
		END IF;
		-- 口座店、口座科目、番号、名義人の設定（入金口座選択区分が'3'その他のときはNULL)
		CASE recMeisai.NYUKIN_KOZA_KBN
			WHEN '1' THEN 	-- 支店別段送金
			----更新　2017/01/10　START
			----gHrikmkozaTenNo := recMeisai.KOZA_TEN_CD;
				gHrikmkozaTenNo := recMeisai.BD_KOZA_TEN_CD;
				gKozaKamokuNm	:= recMeisai.BD_KOZA_KAMOKU_NM;
			----更新　2017/01/10　END
				gKozaNo			:= recMeisai.BD_KOZA_NO;
				gKozaMeigininNm	:= recMeisai.BD_KOZA_MEIGININ_NM;
			WHEN '2' THEN 	-- 発行体口座振込
			----更新　2017/01/10　START
			----gHrikmkozaTenNo := recMeisai.KOZA_TEN_CD;
				gHrikmkozaTenNo := recMeisai.HKT_KOZA_TEN_CD;
				gKozaKamokuNm	:= recMeisai.HKT_KOZA_KAMOKU_NM;
			----更新　2017/01/10　END
				gKozaNo			:= recMeisai.HKT_KOZA_NO;
				gKozaMeigininNm	:= recMeisai.HKT_KOZA_MEIGININ_NM;
		----追加　2017/01/10　START
			WHEN 'D' THEN 	-- 総合振込
				gHrikmkozaTenNo := recMeisai.HKT_KOZA_TEN_CD;
				gKozaKamokuNm	:= recMeisai.HKT_KOZA_KAMOKU_NM;
				gKozaNo			:= recMeisai.HKT_KOZA_NO;
				gKozaMeigininNm	:= recMeisai.HKT_KOZA_MEIGININ_NM;
		----追加　2017/01/10　END
			ELSE
				gHrikmkozaTenNo := NULL;
				gKozaKamokuNm	:= NULL;
				gKozaNo			:= NULL;
				gKozaMeigininNm	:= NULL;
		END CASE;
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem002 := recMeisai.HAKKO_YMD;	-- 発行年月日
		v_item.l_inItem003 := recMeisai.SKN_KESSAI_METHOD_NM;	-- 資金決済方法名称
		v_item.l_inItem004 := recMeisai.HAKKO_TSUKA_NM;	-- 発行通貨名称
		v_item.l_inItem005 := recMeisai.HKT_CD;	-- 発行体コード
		v_item.l_inItem006 := recMeisai.KOZA_TEN_CD;	-- 口座店店番
		v_item.l_inItem007 := recMeisai.KOZA_TEN_CIFCD;	-- 口座店CIFコード
		v_item.l_inItem008 := recMeisai.HKT_RNM;	-- 発行体略称
		v_item.l_inItem009 := recMeisai.ISIN_CD;	-- ＩＳＩＮコード
		v_item.l_inItem010 := recMeisai.MGR_CD;	-- 銘柄コード
		v_item.l_inItem011 := recMeisai.MGR_RNM;	-- 銘柄略称
		v_item.l_inItem012 := recMeisai.SHASAI_TOTAL;	-- 社債の総額
		v_item.l_inItem013 := recMeisai.HRKM_KNGK;	-- 払込金額
		v_item.l_inItem014 := recMeisai.SKN_CHG_YMD;	-- 資金振替日
		v_item.l_inItem015 := recMeisai.SKN_KOFU_YMD;	-- 資金交付日
		v_item.l_inItem016 := gHrikmkozaTenNo;	-- 口座店店番
		v_item.l_inItem017 := gKozaKamokuNm;	-- 口座科目名称
		v_item.l_inItem018 := gKozaNo;	-- 口座番号
		v_item.l_inItem019 := gKozaMeigininNm;	-- 口座名義人
		v_item.l_inItem020 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem021 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem022 := gFmtHakkoKngk;	-- 発行金額書式フォーマット
		v_item.l_inItem023 := gFmtRbrKngk;	-- 利払金額書式フォーマット
		v_item.l_inItem024 := gFmtShokanKngk;	-- 償還金額書式フォーマット
		
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
	-- 対象データなし
		gRtnCd := RTN_NODATA;
		-- 帳票ワークへデータを追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inUserId;
		v_item.l_inItem020 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem021 := REPORT_ID;
		v_item.l_inItem022 := FMT_HAKKO_KNGK_J;
		v_item.l_inItem023 := FMT_RBR_KNGK_J;
		v_item.l_inItem024 := FMT_SHOKAN_KNGK_J;
		v_item.l_inItem025 := '対象データなし';
		
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
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp03601 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
--		RAISE;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip03601 ( l_inKessaiYmdF TEXT, l_inKessaiYmdT TEXT, l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT integer, l_outSqlErrM OUT text ) FROM PUBLIC;