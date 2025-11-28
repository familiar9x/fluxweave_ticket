




CREATE OR REPLACE PROCEDURE spipx005k00r01 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE,        -- 委託会社コード
 l_inUserId SREPORT_WK.USER_ID%TYPE,       -- ユーザーＩＤ
 l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE,    -- 帳票区分
 l_inKijyunYm text,                      -- 基準年月
 l_inHktCd MHAKKOTAI.HKT_CD%TYPE,         -- 発行体コード
 l_inKozaTenCd MHAKKOTAI.KOZA_TEN_CD%TYPE,    -- 口座店店番
 l_inKozaTenCifcd MHAKKOTAI.KOZA_TEN_CIFCD%TYPE, -- 口座店ＣＩＦコード
 l_inMgrCd MGR_KIHON.MGR_CD%TYPE,         -- 銘柄コード
 l_inIsinCd MGR_KIHON.ISIN_CD%TYPE,        -- ＩＳＩＮコード
 l_inTuutiYmd text,                      -- 通知年月日
 l_outSqlCode OUT integer,                        -- リターン値
 l_outSqlErrM OUT text                       -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2006
-- * 会社名:JIP
-- *
-- * 概要　:顧客宛帳票出力指示画面より、印刷条件の指定を受けて、発行完了通知書を作成する
-- *
-- * 引数　:l_inItakuKaishaCd :委託会社コード
-- *        l_inUserId        :ユーザーＩＤ
-- *        l_inChohyoKbn     :帳票区分
-- *        l_inKijyunYm      :基準年月
-- *        l_inKozaTenCd     :口座店店番
-- *        l_inKozaTenCifcd  :口座店ＣＩＦコード
-- *        l_inMgrCd         :銘柄コード
-- *        l_inIsinCd        :ＩＳＩＮコード
-- *        l_inTuutiYmd      :通知年月日
-- *        l_outSqlCode      :リターン値
-- *        l_outSqlErrM      :エラーコメント
-- *
-- * 返り値: なし
-- *
-- * @author ASK
-- * @version $Id: SPIPX005K00R01.sql,v 1.9 2025/01/30 07:15:09 yoshida_r Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2006.12.05 安         新規作成
-- ***************************************************************************
--
--	/*==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_PROCEDURE_ID  CONSTANT varchar(50) := 'SPIPX005K00R01';           -- プロシージャＩＤ
	C_CHOHYO_ID     CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IPX30000511'; -- 帳票ＩＤ
	C_FORMAT_14     CONSTANT varchar(18) := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';       -- フォーマット14桁
	C_FORMAT_16_2   CONSTANT varchar(21) := 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';    -- フォーマット16_2桁
	C_FORMAT_16     CONSTANT varchar(21) := 'Z,ZZZ,ZZZ,ZZZ,ZZZ,ZZ9';     -- フォーマット16桁
	C_FORMAT_18_2   CONSTANT varchar(24) := 'Z,ZZZ,ZZZ,ZZZ,ZZZ,ZZ9.99';  -- フォーマット18_2桁
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	gSeqNo            integer;                           -- シーケンス
	gSeqNoSta         integer;                           -- シーケンス開始
	gSeqNoEnd         integer;                           -- シーケンス終了
	gGyomuYmd         SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE; -- 業務日付
	gSeikyuBunsho     varchar(200);                     -- 請求文章
	gMgrCd            SHINKIBOSHU.MGR_CD%TYPE;           -- 銘柄コード
	gTuutiYmdWareki   varchar(20);                      -- 通知日西暦
	gFm14             varchar(21);                      -- フォーマット14
	gFm16             varchar(24);                      -- フォーマット16
	gTotalKessaiKngk  numeric := 0;                  -- 決済金額合計
	gAtena            varchar(200) := NULL;        -- 宛名
	gOutflg           numeric := 0;                  -- 正常処理フラグ
	gChohyoSortFlg    MPROCESS_CTL.CTL_VALUE%TYPE;       --発行体宛帳票ソート順変更フラグ
	v_item            TYPE_SREPORT_WK_ITEM;              -- SREPORT_WK item for pkPrint.insertData
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	curMeisai CURSOR FOR
		SELECT
			B03.AITE_KKMEMBER_FS_KBN,            -- 金融証券区分(相手方機構加入者)
			B03.AITE_KKMEMBER_BCD,               -- 金融機関コード(相手方機構加入者)
			B03.AITE_KKMEMBER_KKBN,              -- 口座区分(相手方機構加入者)
			SUM(B01.YAKUJO_KNGK) AS YAKUJO_KNGK, -- 約定金額
			SUM(B01.KESSAI_KNGK) AS KESSAI_KNGK, -- 決済金額
			VMG1.ISIN_CD,                        -- ＩＳＩＮコード
			VMG1.MGR_CD,                         -- 銘柄コード
			VMG1.MGR_NM,                         -- 銘柄の正式名称
			VMG1.SHASAI_TOTAL,                   -- 社債の総額
			VMG1.KAKUSHASAI_KNGK,                -- 各社債の金額
			VMG1.HAKKO_YMD,                      -- 発行年月日
			VMG1.FULLSHOKAN_KJT,                 -- 満期償還期日
			VMG1.HAKKO_TSUKA_CD,                 -- 発行通貨
			M01.SFSK_POST_NO,                    -- 送付先_郵便番号
			M01.ADD1,                            -- 送付先_住所１
			M01.ADD2,                            -- 送付先_住所２
			M01.ADD3,                            -- 送付先_住所３
			M01.HKT_CD,                          -- 発行体コード
			M01.HKT_NM,                          -- 発行体名（漢字）
			M01.SFSK_BUSHO_NM,                   -- 送付先_担当部署名
			VJ1.BANK_NM,                         -- 銀行名称
			VJ1.BUSHO_NM1,                       -- 担当部署名称１
			M02.BANK_NM AS KK_MEMBER_NM,         -- 機構加入者名称
			M64.TSUKA_NM                          -- 通貨出力用名称
		FROM mgr_kihon_view vmg1, vjiko_itaku vj1, mtsuka m64, mhakkotai m01, (
				SELECT
					ITAKU_KAISHA_CD,
					MGR_CD,
					SUM(HKUK_KNGK) AS HKUK_KNGK
				FROM (
					SELECT  -- 代理人直接申請
						B01.ITAKU_KAISHA_CD,
						B01.HKUK_KNGK,
						B01.MGR_CD
					FROM
						SHINKIBOSHU B01
					WHERE
						B01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
						AND B01.DAIRI_MOTION_FLG = '1'
						AND B01.KK_PHASE = 'H6'
						AND B01.KK_STAT = '04'
					
UNION ALL

					SELECT  -- 機構加入者申請
						B04.ITAKU_KAISHA_CD,
						B04.HKUK_KNGK,
						VMG1.MGR_CD
					FROM
						SHINKIKIROKU B04,
						MGR_KIHON_VIEW VMG1
					WHERE
						B04.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
						AND B04.ISIN_CD = VMG1.ISIN_CD
						AND VMG1.MGR_STAT_KBN = '1'
						AND B04.ITAKU_KAISHA_CD = l_inItakuKaishaCd
						AND B04.KK_PHASE = 'H6'
						AND B04.KK_STAT = '04'
					
UNION ALL

                	SELECT  -- CB銘柄
                		B01.ITAKU_KAISHA_CD,
                		B01.HKUK_KNGK,
                		VMG1.MGR_CD
                	FROM
                		SHINKIBOSHU B01,
                		MGR_KIHON_VIEW VMG1
                	WHERE
                		B01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
                		AND B01.MGR_CD = VMG1.MGR_CD
                		AND VMG1.MGR_STAT_KBN = '1'
                		AND B01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
                        AND VMG1.SAIKEN_SHURUI IN ('80','89')
                		AND B01.KK_PHASE = 'C2'
						AND B01.KK_STAT = '02'
				) alias4 
				GROUP BY
					ITAKU_KAISHA_CD,
					MGR_CD
			) b0104, shinkiboshu b01, nyukin_yotei b03
LEFT OUTER JOIN mbank m02 ON (B03.AITE_KKMEMBER_FS_KBN = M02.FINANCIAL_SECURITIES_KBN AND B03.AITE_KKMEMBER_BCD = M02.BANK_CD)
WHERE B01.ITAKU_KAISHA_CD = B0104.ITAKU_KAISHA_CD AND B01.MGR_CD = B0104.MGR_CD AND B01.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD AND B01.MGR_CD = VMG1.MGR_CD AND B01.ITAKU_KAISHA_CD = B03.ITAKU_KAISHA_CD AND B01.KESSAI_NO = B03.KESSAI_NO   AND B01.ITAKU_KAISHA_CD = VJ1.KAIIN_ID AND VMG1.ITAKU_KAISHA_CD = M01.ITAKU_KAISHA_CD AND VMG1.HKT_CD = M01.HKT_CD AND VMG1.HAKKO_TSUKA_CD = M64.TSUKA_CD AND VMG1.SHASAI_TOTAL = B0104.HKUK_KNGK AND VMG1.MGR_STAT_KBN = '1' AND B01.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND VMG1.HAKKO_YMD LIKE l_inKijyunYm || '%' AND (coalesce(l_inHktCd::text, '') = '' OR M01.HKT_CD = l_inHktCd) AND (coalesce(l_inKozaTenCd::text, '') = '' OR M01.KOZA_TEN_CD = l_inKozaTenCd) AND (coalesce(l_inKozaTenCifcd::text, '') = '' OR M01.KOZA_TEN_CIFCD = l_inKozaTenCifcd) AND (coalesce(l_inMgrCd::text, '') = '' OR B01.MGR_CD = l_inMgrCd) AND (coalesce(l_inIsinCd::text, '') = '' OR VMG1.ISIN_CD = l_inIsinCd) GROUP BY 
			B03.AITE_KKMEMBER_FS_KBN,
			B03.AITE_KKMEMBER_BCD,
			B03.AITE_KKMEMBER_KKBN,
			VMG1.ISIN_CD,
			VMG1.MGR_CD,
			VMG1.MGR_NM,
			VMG1.SHASAI_TOTAL,
			VMG1.KAKUSHASAI_KNGK,
			VMG1.HAKKO_YMD,
			VMG1.FULLSHOKAN_KJT,
			VMG1.HAKKO_TSUKA_CD,
			M01.SFSK_POST_NO,
			M01.ADD1,
			M01.ADD2,
			M01.ADD3,
			M01.HKT_CD,
			M01.HKT_NM,
			M01.SFSK_BUSHO_NM,
			M01.HKT_KANA_RNM,
			VJ1.BANK_NM,
			VJ1.BUSHO_NM1,
			M02.BANK_NM,
			M64.TSUKA_NM
		ORDER BY
			CASE WHEN  gChohyoSortFlg ='1' THEN  M01.HKT_KANA_RNM   ELSE M01.HKT_CD END ,
			M01.HKT_CD,
			CASE WHEN  gChohyoSortFlg ='1' THEN  VMG1.MGR_CD   ELSE VMG1.ISIN_CD END ,
			VMG1.HAKKO_TSUKA_CD,
			B03.AITE_KKMEMBER_FS_KBN,
			B03.AITE_KKMEMBER_BCD,
			B03.AITE_KKMEMBER_KKBN;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, C_PROCEDURE_ID||' START');
	-- 入力パラメータチェック
	IF coalesce(l_inItakuKaishaCd::text, '') = '' -- 委託会社コード
	OR coalesce(l_inUserId::text, '') = ''        -- ユーザーID
	OR coalesce(l_inChohyoKbn::text, '') = ''     -- 帳票区分
	OR coalesce(l_inKijyunYm::text, '') = '' THEN  -- 基準年月
		-- ログ書込み
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID, 3, 12), 'パラメータエラー');
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := '';
		RETURN;
	END IF;
--
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '引数');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '委託会社コード:"' || l_inItakuKaishaCd ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'ユーザーＩＤ:"' || l_inUserId ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票区分:"' || l_inChohyoKbn ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '基準年月:"' || l_inKijyunYm ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '発行体コード:"' || l_inHktCd ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '口座店店番:"' || l_inKozaTenCd ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '口座店ＣＩＦコード:"' || l_inKozaTenCifcd ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '銘柄コード:"' || l_inMgrCd ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'ＩＳＩＮコード:"' || l_inIsinCd ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '通知年月日:"' || l_inTuutiYmd ||'"');
--
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
	-- 通知日西暦変換
	IF coalesce(l_inTuutiYmd::text, '') = '' THEN
		gTuutiYmdWareki := '年  月  日';
	ELSE
		gTuutiYmdWareki := pkDate.seirekiChangeSuppressNenGappi(l_inTuutiYmd);
	END iF;
	-- 文章マスタより請求文章取得
	gSeikyuBunsho := SPIPX005K00R01_createBun(C_CHOHYO_ID, '00');
	-- シーケンス初期化
	gSeqNo := 1;
	-- 帳票ワーク削除
	DELETE FROM SREPORT_WK
		WHERE KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = gGyomuYmd
		AND CHOHYO_ID = C_CHOHYO_ID;
--
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '削除条件');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '識別コード:"' || l_inItakuKaishaCd ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'ユーザーＩＤ:"' || l_inUserId ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票区分:"' || l_inChohyoKbn ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '作成日付:"' || gGyomuYmd ||'"');
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票ＩＤ:"' || C_CHOHYO_ID ||'"');
--
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, gGyomuYmd, C_CHOHYO_ID);
	--発行体宛帳票ソート順変更フラグ取得
	gChohyoSortFlg	:= pkControl.getCtlValue(l_inItakuKaishaCd,'SeikyusyoSort','0');
	-- データ取得
	FOR recMeisai IN curMeisai
	LOOP
		-- 通貨フォーマット設定
		IF recMeisai.HAKKO_TSUKA_CD = 'JPY' THEN
			gFm14 := C_FORMAT_14;   -- フォーマット14
			gFm16 := C_FORMAT_16;   -- フォーマット16
		ELSE
			gFm14 := C_FORMAT_16_2; -- フォーマット14
			gFm16 := C_FORMAT_18_2; -- フォーマット16
		END IF;
		-- 銘柄コードブレイク処理
		IF gSeqNo <> 1 THEN
			IF gMgrCd <> recMeisai.MGR_CD THEN
				-- 更新シーケンス設定
				gSeqNoSta := gSeqNoEnd + 1; -- シーケンス開始
				gSeqNoEnd := gSeqNo - 1;    -- シーケンス終了
				-- 合計金額更新処理
				UPDATE SREPORT_WK SET
					ITEM013 = gTotalKessaiKngk
				WHERE KEY_CD = l_inItakuKaishaCd
				AND USER_ID = l_inUserId
				AND CHOHYO_KBN = l_inChohyoKbn
				AND SAKUSEI_YMD = gGyomuYmd
				AND CHOHYO_ID = C_CHOHYO_ID
				AND (SEQ_NO >= gSeqNoSta AND SEQ_NO <= gSeqNoEnd);
--
--				pkLog.debug(l_inUserId, C_PROCEDURE_ID, '更新条件');
--				pkLog.debug(l_inUserId, C_PROCEDURE_ID, '識別コード:"' || l_inItakuKaishaCd ||'"');
--				pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'ユーザーＩＤ:"' || l_inUserId ||'"');
--				pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票区分:"' || l_inChohyoKbn ||'"');
--				pkLog.debug(l_inUserId, C_PROCEDURE_ID, '作成日付:"' || gGyomuYmd ||'"');
--				pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票ＩＤ:"' || C_CHOHYO_ID ||'"');
--				pkLog.debug(l_inUserId, C_PROCEDURE_ID, '連番開始:"' || TO_CHAR(gSeqNoSta) ||'"');
--				pkLog.debug(l_inUserId, C_PROCEDURE_ID, '連番終了:"' || TO_CHAR(gSeqNoEnd) ||'"');
--
				-- 合計金額集計処理
				gTotalKessaiKngk := 0;
			END IF;
		ELSE
			-- 更新シーケンス設定
			gSeqNoSta := 0; -- シーケンス開始
			gSeqNoEnd := 0; -- シーケンス終了
		END IF;
		-- 宛名編集
		CALL pkIpaName.getMadoFutoAtenaYoko(recMeisai.HKT_NM, recMeisai.SFSK_BUSHO_NM, gOutflg, gAtena);
		-- 明細レコード追加
		-- Clear toàn bộ item
		v_item := ROW();
		
		v_item.l_inItem001 := gTuutiYmdWareki;
		v_item.l_inItem002 := recMeisai.SFSK_POST_NO;
		v_item.l_inItem003 := recMeisai.ADD1;
		v_item.l_inItem004 := recMeisai.ADD2;
		v_item.l_inItem005 := recMeisai.ADD3;
		v_item.l_inItem006 := gAtena;
		v_item.l_inItem007 := recMeisai.BANK_NM;
		v_item.l_inItem008 := recMeisai.BUSHO_NM1;
		v_item.l_inItem009 := recMeisai.SHASAI_TOTAL;
		v_item.l_inItem010 := recMeisai.KAKUSHASAI_KNGK;
		v_item.l_inItem011 := recMeisai.KESSAI_KNGK;
		v_item.l_inItem012 := recMeisai.YAKUJO_KNGK;
		v_item.l_inItem014 := recMeisai.HAKKO_YMD;
		v_item.l_inItem015 := recMeisai.FULLSHOKAN_KJT;
		v_item.l_inItem016 := recMeisai.HAKKO_TSUKA_CD;
		v_item.l_inItem017 := gFm14;
		v_item.l_inItem018 := gFm16;
		v_item.l_inItem019 := recMeisai.AITE_KKMEMBER_FS_KBN || recMeisai.AITE_KKMEMBER_BCD || recMeisai.AITE_KKMEMBER_KKBN;
		v_item.l_inItem020 := recMeisai.MGR_CD;
		v_item.l_inItem021 := recMeisai.ISIN_CD;
		v_item.l_inItem022 := recMeisai.MGR_NM;
		v_item.l_inItem023 := recMeisai.KK_MEMBER_NM;
		v_item.l_inItem024 := recMeisai.TSUKA_NM;
		v_item.l_inItem025 := gSeikyuBunsho;
		
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd,
			l_inUserId     => l_inUserId,
			l_inChohyoKbn  => l_inChohyoKbn,
			l_inSakuseiYmd => gGyomuYmd,
			l_inChohyoId   => C_CHOHYO_ID,
			l_inSeqNo      => gSeqNo,
			l_inHeaderFlg  => 1,
			l_inItem       => v_item,
			l_inKousinId   => l_inUserId,
			l_inSakuseiId  => l_inUserId
		);
		-- シーケンスのカウント
		gSeqNo := gSeqNo + 1;
		-- ブレイクキー保存
		gMgrCd := recMeisai.MGR_CD; -- 銘柄コード
		-- 決済金額合計
		gTotalKessaiKngk := gTotalKessaiKngk + recMeisai.KESSAI_KNGK;
	END LOOP;
	-- 終了処理
	IF gSeqNo = 1 THEN
		-- 明細レコード追加（対象データなし）
		-- Clear toàn bộ item
		v_item := ROW();
		
		v_item.l_inItem026 := '対象データなし';
		
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd,
			l_inUserId     => l_inUserId,
			l_inChohyoKbn  => l_inChohyoKbn,
			l_inSakuseiYmd => gGyomuYmd,
			l_inChohyoId   => C_CHOHYO_ID,
			l_inSeqNo      => gSeqNo,
			l_inHeaderFlg  => 1,
			l_inItem       => v_item,
			l_inKousinId   => l_inUserId,
			l_inSakuseiId  => l_inUserId
		);
	ELSE
		-- 更新シーケンス設定
		gSeqNoSta := gSeqNoEnd + 1; -- シーケンス開始
		gSeqNoEnd := gSeqNo - 1;    -- シーケンス終了
		-- 合計金額更新処理
		UPDATE SREPORT_WK SET
			ITEM013 = gTotalKessaiKngk
		WHERE
			KEY_CD = l_inItakuKaishaCd
			AND USER_ID = l_inUserId
			AND CHOHYO_KBN = l_inChohyoKbn
			AND SAKUSEI_YMD = gGyomuYmd
			AND CHOHYO_ID = C_CHOHYO_ID
			AND (SEQ_NO >= gSeqNoSta AND SEQ_NO <= gSeqNoEnd);
--
--		pkLog.debug(l_inUserId, C_PROCEDURE_ID, '更新条件');
--		pkLog.debug(l_inUserId, C_PROCEDURE_ID, '識別コード:"' || l_inItakuKaishaCd ||'"');
--		pkLog.debug(l_inUserId, C_PROCEDURE_ID, 'ユーザーＩＤ:"' || l_inUserId ||'"');
--		pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票区分:"' || l_inChohyoKbn ||'"');
--		pkLog.debug(l_inUserId, C_PROCEDURE_ID, '作成日付:"' || gGyomuYmd ||'"');
--		pkLog.debug(l_inUserId, C_PROCEDURE_ID, '帳票ＩＤ:"' || C_CHOHYO_ID ||'"');
--		pkLog.debug(l_inUserId, C_PROCEDURE_ID, '連番開始:"' || TO_CHAR(gSeqNoSta) ||'"');
--		pkLog.debug(l_inUserId, C_PROCEDURE_ID, '連番終了:"' || TO_CHAR(gSeqNoEnd) ||'"');
--
	END IF;
	-- 終了処理
	l_outSqlCode := pkconstant.success();
	l_outSqlErrM := '';
--	pkLog.debug(l_inUserId, C_PROCEDURE_ID, C_PROCEDURE_ID ||' END');
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID,3,12), 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', SUBSTR(C_PROCEDURE_ID,3,12), 'SQLERRM:' || SQLERRM);
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLSTATE || SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipx005k00r01 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE, l_inUserId SREPORT_WK.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_inKijyunYm text, l_inHktCd MHAKKOTAI.HKT_CD%TYPE, l_inKozaTenCd MHAKKOTAI.KOZA_TEN_CD%TYPE, l_inKozaTenCifcd MHAKKOTAI.KOZA_TEN_CIFCD%TYPE, l_inMgrCd MGR_KIHON.MGR_CD%TYPE, l_inIsinCd MGR_KIHON.ISIN_CD%TYPE, l_inTuutiYmd text, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spipx005k00r01_createbun ( l_in_PatternCd BUN.BUN_PATTERN_CD%TYPE ) RETURNS varchar AS $body$
DECLARE

aryBun pkIpaBun.BUN_ARRAY;
wkBun  varchar(200) := NULL;
BEGIN
	aryBun := pkIpaBun.getBun(C_CHOHYO_ID, l_in_PatternCd);
	FOR i IN 0 .. coalesce(cardinality(aryBun), 0) - 1 LOOP
		wkBun := wkBun || RPAD(aryBun[i], 100, '　'); -- 100byteまで全角スペース埋めして、請求文章を連結
	END LOOP;
	RETURN wkBun;
EXCEPTION
	WHEN OTHERS THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spipx005k00r01_createbun ( l_in_PatternCd BUN.BUN_PATTERN_CD%TYPE ) FROM PUBLIC;