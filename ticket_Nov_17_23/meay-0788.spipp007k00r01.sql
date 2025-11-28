




CREATE OR REPLACE PROCEDURE spipp007k00r01 ( 
	l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE,     -- 委託会社コード
 l_inUserId SREPORT_WK.USER_ID%TYPE,    -- ユーザーＩＤ
 l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, -- 帳票区分
 l_inMgrCd MGR_KIHON.MGR_CD%TYPE,      -- 銘柄コード
 l_inIsinCd MGR_KIHON.ISIN_CD%TYPE,     -- ＩＳＩＮコード
 l_inKjnYm text,                   -- 基準年月
 l_outSqlCode OUT integer,                    -- リターン値
 l_outSqlErrM OUT text                    -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2007
-- * 会社名:JIP
-- *
-- * 概要　:取引先別保有残高一覧表を作成
-- *
-- * 引数　:l_inItakuKaishaCd :委託会社コード
-- *        l_inUserId        :ユーザーＩＤ
-- *        l_inChohyoKbn     :帳票区分
-- *        l_inMgrCd         :銘柄コード
-- *        l_inIsinCd        :ＩＳＩＮコード
-- *        l_inKjnYm         :基準年月
-- *        l_outSqlErrM      :エラーコメント
-- *
-- * 返り値: 0:正常
-- *        99:異常
-- *
-- * @author ASK
-- * @version $Id: SPIPP007K00R01.sql,v 1.6 2012/11/21 12:30:07 kanayama Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2007.05.24 張(ASK)     新規作成
-- *　2007.09.13 大野(ASK)   IP-05636 仕様変更
-- *                           取引先属性「3:その他口座管理機関」の場合、税区分を"−"表示する
-- ***************************************************************************
--	/*==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_PROGRAM_ID CONSTANT varchar(50)              := 'SPIPP007K00R01'; -- プログラムＩＤ
	C_CHOHYO_ID  CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IPP30000711';    -- 帳票ＩＤ
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	gSeqNo          integer;                              -- シーケンス
	gItakuKaishaRnm MITAKU_KAISHA.ITAKU_KAISHA_RNM%TYPE; -- 委託会社略称
	gSeigyouProcess MPROCESS_CTL.CTL_VALUE%TYPE;         -- 処理制御マスタのフラグを格納する変数
	gGyomuYmd       SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;   -- 業務日付
	gKjnMatuYmd     SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;   -- 基準年月末日
	gWkc            varchar(4);                         -- 分かち
	gHoyuZndk       KBG_SHOKBG.FURI_GENSAI_KNGK%TYPE;    -- 保有残高
	gMaisu          KBG_KENSHU.MAISU%TYPE;               -- 枚数
	gKenshuCd       numeric;                              -- 券種コード
	gMgrKenshuKngk  numeric;                              -- 銘柄券種金額
	-- 読込データ
	gTaxRnm         MTAX.TAX_RNM%TYPE;                   -- 税区分略称
	gTrhkCd         KBG_MTORISAKI.TRHK_CD%TYPE;          -- 取引先コード
	gTrhkZokuseiNm  SCODE.CODE_RNM%TYPE;                 -- 取引先属性名称
	gTrhkRnm        KBG_MTORISAKI.TRHK_RNM%TYPE;         -- 取引先略称
	gMgrCd          KBG_SHOKIJ.MGR_CD%TYPE;              -- 銘柄コード
	gIsinCd         MGR_KIHON.ISIN_CD%TYPE;              -- ＩＳＩＮコード
	gWkcTaxDays     KBG_SHOKBG.WKC_TAX_DAYS%TYPE;        -- 分かち課税日数
	gKibangoFrom    KBG_SHOKBG.KIBANGO_FROM%TYPE;        -- 記番号FROM
	gKibangoTo      KBG_SHOKBG.KIBANGO_TO%TYPE;          -- 記番号TO
	gMgrNm          MGR_KIHON.MGR_NM%TYPE;               -- 銘柄の正式名称
	gRet			numeric := 0;
	wkTaxRnm         MTAX.TAX_RNM%TYPE;                   -- 税区分略称
	wkTaxNm          MTAX.TAX_NM%TYPE := NULL;			--税区分名称
	wkKokuZeiRate    MTAX.KOKU_ZEI_RATE%TYPE := NULL;	    --国税率
	wkChihoZeiRate   MTAX.CHIHO_ZEI_RATE%TYPE := NULL;	--地方税率
	v_item           type_sreport_wk_item;              -- Composite type for pkPrint.insertData
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	curHoyuZndk CURSOR FOR
		SELECT
			P02.TRHK_CD,                                          -- 取引先コード
			P05.TRHK_RNM,                                         -- 取引先略称
			P02.MGR_CD,                                           -- 銘柄コード
			VMG1.ISIN_CD,                                         -- ＩＳＩＮコード
			P02.WKC_TAX_DAYS,                                     -- 分かち課税日数
			CASE WHEN P02.WKC_TAX_DAYS='0' THEN  'なし'  ELSE 'あり' END  AS WKC, -- 分かち
			P02.KENSHU_CD,                                        -- 券種
			P02.KIBANGO_FROM,                                     -- 番号（自）
			P02.KIBANGO_TO,                                       -- 番号（至）
			CASE WHEN gSeigyouProcess='1' THEN  SUBSTR(VMG1.MGR_NM, 1, 50)  ELSE VMG1.MGR_RNM END  AS MGR_NM,                                          -- 銘柄名称
-- 復興増税対応 - 2012/06/12 JSFIT山下 開始
--			DECODE (P05.TRHK_ZOKUSEI, '3', '−',
--				(SELECT
--					TAX_RNM
--				 FROM					-- 取引先属性による判定
--					MTAX					-- 1:社債権者・2:社債権者(常任代理人)…税区分マスタより取得
--				 WHERE						-- 3:その他口座管理機関              …"−"
--					TAX_KBN = P05.TAX_KBN)
--			) AS TAX_RNM,                                         -- 税区分
			P05.TAX_KBN,										  -- 税区分	
			P05.TRHK_ZOKUSEI,									  -- 取引先属性
-- 復興増税対応 - 2012/06/12 JSFIT山下 終了
			(
				SELECT
					CODE_RNM
				FROM
					SCODE
				WHERE
					CODE_SHUBETSU = '228'
					AND CODE_VALUE = P05.TRHK_ZOKUSEI
			) AS TRHK_ZOKUSEI_NM                                   -- 取引先属性
		FROM mgr_kihon_view vmg1, kbg_mtorisaki p05, kbg_shokbg p02
LEFT OUTER JOIN kbg_shokij p01 ON (P02.ITAKU_KAISHA_CD = P01.ITAKU_KAISHA_CD AND P02.MGR_CD = P01.MGR_CD AND P02.SHOKAN_KJT = P01.SHOKAN_KJT AND P02.KBG_SHOKAN_KBN = P01.KBG_SHOKAN_KBN)
WHERE P02.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD AND P02.MGR_CD = VMG1.MGR_CD AND P02.ITAKU_KAISHA_CD = P05.ITAKU_KAISHA_CD AND P02.TRHK_CD = P05.TRHK_CD AND VMG1.JTK_KBN != '2' AND VMG1.JTK_KBN != '5' AND VMG1.MGR_STAT_KBN = '1' AND (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '') AND VMG1.KK_KANYO_FLG = '2' AND P02.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND (P01.SHOKAN_YMD > gKjnMatuYmd OR P02.SHOKAN_KJT = '        ') AND pkIpaKibango.getKjnZndkTrhk(
					P02.ITAKU_KAISHA_CD,
					P02.MGR_CD,
					gKjnMatuYmd,
					P02.TRHK_CD
				) > 0 AND (P02.MGR_CD = l_inMgrCd OR coalesce(trim(both l_inMgrCd)::text, '') = '') AND (VMG1.ISIN_CD = l_inIsinCd OR coalesce(trim(both l_inIsinCd)::text, '') = '') ORDER BY
			P02.TRHK_CD,
			P02.MGR_CD,
			P02.KENSHU_CD,
			P02.KIBANGO_FROM;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, C_PROGRAM_ID || ' START');
	-- 入力パラメータチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inUserId)::text, '') = ''
	OR coalesce(trim(both l_inKjnYm)::text, '') = ''
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = '' THEN
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := 'パラメータエラー';
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, l_outSqlErrM);
		RETURN;
	END IF;
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '引数');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '委託会社コード:"' || l_inItakuKaishaCd || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, 'ユーザーＩＤ:"' || l_inUserId || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '帳票区分:"' || l_inChohyoKbn || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '銘柄コード:"' || l_inMgrCd || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, 'ＩＳＩＮコード:"' || l_inIsinCd || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '基準年月:"' || l_inKjnYm || '"');
	-- 委託会社略称取得
	SELECT
		CASE WHEN JIKO_DAIKO_KBN='2' THEN  BANK_RNM  ELSE ' ' END
	INTO
		gItakuKaishaRnm
	FROM
		VJIKO_ITAKU
	WHERE
		KAIIN_ID = l_inItakuKaishaCd;
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '委託会社略名:"' || gItakuKaishaRnm || '"');
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '業務日付:"' || gGyomuYmd || '"');
	-- 基準年月末日取得
	gKjnMatuYmd := pkDate.getGetsumatsuYmd(l_inKjnYm || '01', 0);
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '基準年月末日:"' || gKjnMatuYmd || '"');
	-- 処理制御マスタからフラグを取得 (第３引数はデフォルト値)
	gSeigyouProcess := pkControl.getCtlValue(l_inItakuKaishaCd, 'getMgrNm01', '0');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '銘柄名称制御フラグ:"' || gSeigyouProcess || '"');
	-- 帳票ワーク削除
	DELETE FROM SREPORT_WK
	WHERE
		KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = gGyomuYmd
		AND CHOHYO_ID = C_CHOHYO_ID;
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '削除条件');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '識別コード:"' || l_inItakuKaishaCd || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, 'ユーザーＩＤ:"' || l_inUserId || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '帳票区分:"' || l_inChohyoKbn || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '作成日付:"' || gGyomuYmd || '"');
--	pkLog.debug(l_inUserId, C_PROGRAM_ID, '帳票ＩＤ:"' || C_CHOHYO_ID || '"');
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, gGyomuYmd, C_CHOHYO_ID);
	-- 変数初期化
	gSeqNo := 1;
	gTrhkCd := ' ';
	-- データ読込
	FOR recHoyuZndk IN curHoyuZndk
	LOOP
		IF recHoyuZndk.TRHK_ZOKUSEI = '3' THEN
			wkTaxNm := '−';
		ELSE
			--基準年月の月初に該当する適用開始日の税区分を取得する
			gRet := pkIpaZei.getMTax(recHoyuZndk.TAX_KBN,
									 l_inKjnYm || '01',
									 wkTaxNm,
									 wkTaxRnm,
									 wkKokuZeiRate,
									 wkChihoZeiRate
									);
		END IF;
		-- 初回時
		IF gTrhkCd = ' ' THEN
			gTaxRnm        := wkTaxNm;                     -- 税区分略称
			gTrhkCd        := recHoyuZndk.TRHK_CD;         -- 取引先コード
			gTrhkZokuseiNm := recHoyuZndk.TRHK_ZOKUSEI_NM; -- 取引先属性名称
			gTrhkRnm       := recHoyuZndk.TRHK_RNM;        -- 取引先略称
			gMgrCd         := recHoyuZndk.MGR_CD;          -- 銘柄コード
			gIsinCd        := recHoyuZndk.ISIN_CD;         -- ISINコード
			gMgrNm         := recHoyuZndk.MGR_NM;          -- 銘柄名称
			gWkc           := recHoyuZndk.WKC;             -- 分かち
			gKenshuCd      := recHoyuZndk.KENSHU_CD;       -- 券種コード
			gKibangoFrom   := recHoyuZndk.KIBANGO_FROM;    -- 記番号FROM
			gKibangoTo     := recHoyuZndk.KIBANGO_TO;      -- 記番号TO
			gWkcTaxDays    := recHoyuZndk.WKC_TAX_DAYS;    -- 分かち課税日数
		-- 初回でない時
		ELSE
			-- 「取引先コード」、「銘柄コード」、「分かち課税日数」、
			-- 「券種コード」がブレイクしなく、
			-- 「記番号FROM」が１データ前の「記番号TO」+ 1 の時
			IF recHoyuZndk.TRHK_CD           =  gTrhkCd
				AND recHoyuZndk.MGR_CD       = gMgrCd
				AND recHoyuZndk.WKC_TAX_DAYS = gWkcTaxDays
				AND recHoyuZndk.KENSHU_CD    = gKenshuCd
				AND recHoyuZndk.KIBANGO_FROM = (gKibangoTo + 1) THEN
				-- 変数再セット（記番号TO）
				gKibangoTo := recHoyuZndk.KIBANGO_TO;
			ELSE
				-- 登録前編集 ＋ 帳票ワーク登録処理
				-- Inlined: SPIPP007K00R01_insertData (BEGIN)
				gHoyuZndk := pkIpaKibango.getKjnZndkTrhk(l_inItakuKaishaCd, gMgrCd, gKjnMatuYmd, gTrhkCd);
				gMaisu := (gKibangoTo - gKibangoFrom) + 1;
				gMgrKenshuKngk := gMaisu * gKenshuCd;
				gKenshuCd := gKenshuCd / 1000;
				v_item.l_inItem001 := gItakuKaishaRnm;
				v_item.l_inItem002 := l_inUserId;
				v_item.l_inItem003 := l_inKjnYm;
				v_item.l_inItem004 := gTaxRnm;
				v_item.l_inItem005 := gTrhkCd;
				v_item.l_inItem006 := gTrhkZokuseiNm;
				v_item.l_inItem007 := gTrhkRnm;
				v_item.l_inItem008 := gMgrCd;
				v_item.l_inItem009 := gIsinCd;
				v_item.l_inItem010 := gMgrNm;
				v_item.l_inItem011 := gWkc;
				v_item.l_inItem012 := gHoyuZndk;
				v_item.l_inItem013 := gKenshuCd;
				v_item.l_inItem014 := gKibangoFrom;
				v_item.l_inItem015 := gKibangoTo;
				v_item.l_inItem016 := gMaisu;
				v_item.l_inItem017 := gMgrKenshuKngk;
				v_item.l_inItem018 := gWkcTaxDays;
				v_item.l_inItem019 := C_CHOHYO_ID;
				CALL pkPrint.insertData(
					l_inKeyCd      => l_inItakuKaishaCd,
					l_inUserId     => l_inUserId,
					l_inChohyoKbn  => l_inChohyoKbn,
					l_inSakuseiYmd => gGyomuYmd,
					l_inChohyoId   => C_CHOHYO_ID,
					l_inSeqNo      => gSeqNo::integer,
					l_inHeaderFlg  => '1',
					l_inItem       => v_item,
					l_inKousinId   => l_inUserId,
					l_inSakuseiId  => l_inUserId
				);
				gSeqNo := gSeqNo + 1;
				-- Inlined: SPIPP007K00R01_insertData (END)
				-- 変数セット
				gTaxRnm        := wkTaxNm;                     -- 税区分略称
				gTrhkCd        := recHoyuZndk.TRHK_CD;         -- 取引先コード
				gTrhkZokuseiNm := recHoyuZndk.TRHK_ZOKUSEI_NM; -- 取引先属性名称
				gTrhkRnm       := recHoyuZndk.TRHK_RNM;        -- 取引先略称
				gMgrCd         := recHoyuZndk.MGR_CD;          -- 銘柄コード
				gIsinCd        := recHoyuZndk.ISIN_CD;         -- ISINコード
				gMgrNm         := recHoyuZndk.MGR_NM;          -- 銘柄名称
				gWkc           := recHoyuZndk.WKC;             -- 分かち
				gKenshuCd      := recHoyuZndk.KENSHU_CD;       -- 券種コード
				gKibangoFrom   := recHoyuZndk.KIBANGO_FROM;    -- 記番号FROM
				gKibangoTo     := recHoyuZndk.KIBANGO_TO;      -- 記番号TO
				gWkcTaxDays    := recHoyuZndk.WKC_TAX_DAYS;    -- 分かち課税日数
			END IF;
		END IF;
	END LOOP;
	-- 対象データなし時
	IF gTrhkCd = ' ' THEN
		-- 「対象データなし」データ作成
		v_item.l_inItem001 := gItakuKaishaRnm;
		v_item.l_inItem002 := l_inUserId;
		v_item.l_inItem003 := l_inKjnYm;
		v_item.l_inItem019 := C_CHOHYO_ID;
		v_item.l_inItem020 := '対象データなし';
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd,
			l_inUserId     => l_inUserId,
			l_inChohyoKbn  => l_inChohyoKbn,
			l_inSakuseiYmd => gGyomuYmd,
			l_inChohyoId   => C_CHOHYO_ID,
			l_inSeqNo      => gSeqNo::integer,
			l_inHeaderFlg  => '1',
			l_inItem       => v_item,
			l_inKousinId   => l_inUserId,
			l_inSakuseiId  => l_inUserId
		);
	ELSE
		-- 登録前編集 ＋ 帳票ワーク登録処理
		-- Inlined: SPIPP007K00R01_insertData (BEGIN)
		gHoyuZndk := pkIpaKibango.getKjnZndkTrhk(l_inItakuKaishaCd, gMgrCd, gKjnMatuYmd, gTrhkCd);
		gMaisu := (gKibangoTo - gKibangoFrom) + 1;
		gMgrKenshuKngk := gMaisu * gKenshuCd;
		gKenshuCd := gKenshuCd / 1000;
		v_item.l_inItem001 := gItakuKaishaRnm;
		v_item.l_inItem002 := l_inUserId;
		v_item.l_inItem003 := l_inKjnYm;
		v_item.l_inItem004 := gTaxRnm;
		v_item.l_inItem005 := gTrhkCd;
		v_item.l_inItem006 := gTrhkZokuseiNm;
		v_item.l_inItem007 := gTrhkRnm;
		v_item.l_inItem008 := gMgrCd;
		v_item.l_inItem009 := gIsinCd;
		v_item.l_inItem010 := gMgrNm;
		v_item.l_inItem011 := gWkc;
		v_item.l_inItem012 := gHoyuZndk;
		v_item.l_inItem013 := gKenshuCd;
		v_item.l_inItem014 := gKibangoFrom;
		v_item.l_inItem015 := gKibangoTo;
		v_item.l_inItem016 := gMaisu;
		v_item.l_inItem017 := gMgrKenshuKngk;
		v_item.l_inItem018 := gWkcTaxDays;
		v_item.l_inItem019 := C_CHOHYO_ID;
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd,
			l_inUserId     => l_inUserId,
			l_inChohyoKbn  => l_inChohyoKbn,
			l_inSakuseiYmd => gGyomuYmd,
			l_inChohyoId   => C_CHOHYO_ID,
			l_inSeqNo      => gSeqNo::integer,
			l_inHeaderFlg  => '1',
			l_inItem       => v_item,
			l_inKousinId   => l_inUserId,
			l_inSakuseiId  => l_inUserId
		);
		gSeqNo := gSeqNo + 1;
		-- Inlined: SPIPP007K00R01_insertData (END)
	END IF;
	-- 正常終了
	l_outSqlCode := pkconstant.success();
	l_outSqlErrM := '';
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'SQLERRM:' || SQLERRM);
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLSTATE || SQLERRM;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipp007k00r01 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE, l_inUserId SREPORT_WK.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_inMgrCd MGR_KIHON.MGR_CD%TYPE, l_inIsinCd MGR_KIHON.ISIN_CD%TYPE, l_inKjnYm text, l_outSqlCode OUT integer, l_outSqlErrM OUT text ) FROM PUBLIC;
