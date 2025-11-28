




CREATE OR REPLACE PROCEDURE spipp006k00r01 ( 
	l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE,     -- 委託会社コード
 l_inUserId SREPORT_WK.USER_ID%TYPE,    -- ユーザーＩＤ
 l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, -- 帳票区分
 l_inKjnYm text,                   -- 基準年月
 l_outSqlCode OUT integer,                    -- リターン値
 l_outSqlErrM OUT text                    -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2007
-- * 会社名:JIP
-- *
-- * 概要　:取引先別元利金振込一覧表作成
-- *
-- * 引数　:l_inItakuKaishaCd :委託会社コード
-- *        l_inUserId        :ユーザーＩＤ
-- *        l_inChohyoKbn     :帳票区分
-- *        l_inKjnYm         :基準年月
-- *        l_outSqlCode      :リターン値
-- *        l_outSqlErrM      :エラーコメント
-- *
-- * 返り値: 0:正常
-- *        99:異常
-- *
-- * @author ASK
-- * @version $Id: SPIPP006K00R01.sql,v 1.8 2007/09/19 09:40:06 nakamura Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2007.06.07 張          新規作成
-- *　2007.08.07 JIP         利払情報追加
-- *　2007.08.16 JIP         期日フラグについての記述を削除
-- *　2007.08.22 JIP         データ基準日がリアル出力でもバッチ出力でも和暦
-- *                         編集後に出力されるように修正
-- *　2007.08.31 JIP         バッチ出力時の基準年月の編集を修正
-- ***************************************************************************
--	/*==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_PROGRAM_ID CONSTANT varchar(50)              := 'SPIPP006K00R01'; -- プログラムＩＤ
	C_CHOHYO_ID  CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IPP30000611';    -- 帳票ＩＤ
	C_BLANK      CONSTANT char(1)                   := ' ';              -- ブランク
	C_NO_DATA    CONSTANT integer                   := 2;                -- 対象データなし
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gSeqNo                 numeric;                                       -- シーケンス
	gItakuKaishaRnm        MITAKU_KAISHA.ITAKU_KAISHA_RNM%TYPE;          -- 委託会社略称
	gGyomuYmd              SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;            -- 業務日付
	gSakuseiYmd            SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;            -- 作成年月日
	gRbrKjtFrom            MGR_RBRKIJ.RBR_KJT%TYPE;                      -- 元利払期日FROM（バッチ用）
	gRbrKjtTo              MGR_RBRKIJ.RBR_KJT%TYPE;                      -- 元利払期日TO（バッチ用）
	--  2007/08/31  ADD JIP
	gRbrYmdFrom            MGR_RBRKIJ.RBR_KJT%TYPE;                      -- 元利払期日FROM（リアル用）
	gRbrYmdTo              MGR_RBRKIJ.RBR_KJT%TYPE;                      -- 元利払期日TO  （リアル用）
	--  2007/08/31  ADD JIP-
	gBankCd                KBG_MTORISAKI.BANK_CD%TYPE;                   -- 金融機関コード
	gShitenCd              KBG_MTORISAKI.SHITEN_CD%TYPE;                 -- 支店コード
	gKozaKamokuNm          SCODE.CODE_RNM%TYPE;                          -- 口座科目
	gKozaNo                KBG_MTORISAKI.KBG_KOZA_NO%TYPE;               -- 口座番号
	gBankNm                MBANK.BANK_NM%TYPE;                           -- 金融機関名称
	gKbgKozaMeigininNm     KBG_MTORISAKI.KBG_KOZA_MEIGININ_NM%TYPE;      -- 記番号_口座名義人
	gShitenNm              MBANK_SHITEN.SHITEN_NM%TYPE;                  -- 支店略称
	gKbgKozaMeigininKanaNm KBG_MTORISAKI.KBG_KOZA_MEIGININ_KANA_NM%TYPE; -- 記番号_口座名義人（カナ）
	gFrkmKngk              numeric;                                       -- 振込金額
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	--  2007/08/31  EDIT JIP
	curMeisai CURSOR FOR
		SELECT      P05.GNRK_KESSAI_METHOD,                             --  元利金決済方法
					(   SELECT  CODE_RNM
						FROM    SCODE
						WHERE   CODE_SHUBETSU = '229'
						AND     CODE_VALUE    = P05.GNRK_KESSAI_METHOD
					)   AS      GNRK_KESSAI_METHOD_NM,                  --  元利金決済方法名称
					WT1.RBR_YMD,                                        --  利払日
					P05.TRHK_CD,                                        --  取引先コード
					P05.TRHK_RNM,                                       --  取引先略称
					P05.BANK_CD,                                        --  金融機関コード
					(   SELECT  BANK_NM
						FROM    MBANK
						WHERE   FINANCIAL_SECURITIES_KBN = '0'
						AND     BANK_CD = P05.BANK_CD
					)   AS      BANK_NM,                                --  金融機関名称
					P05.SHITEN_CD,                                      --  支店コード
					(   SELECT  SHITEN_NM
						FROM    MBANK_SHITEN
						WHERE   FINANCIAL_SECURITIES_KBN = '0'
						AND     BANK_CD   = P05.BANK_CD
						AND     SHITEN_CD = P05.SHITEN_CD
					)   AS      SHITEN_NM,                              --  支店名称
					(   SELECT  CODE_RNM
						FROM    SCODE
						WHERE   CODE_SHUBETSU = '707'
						AND     CODE_VALUE    = P05.KOZA_KAMOKU
					)   AS      KOZA_KAMOKU_NM,                         --  口座科目
					P05.KBG_KOZA_NO,                                    --  記番号口座番号
					P05.BOJ_TOYO_KOZA_NO,                               --  日銀当預金_口座番号
					SUBSTR(
						P05.KBG_KOZA_MEIGININ_NM, 1, 30
					)   AS  KBG_KOZA_MEIGININ_NM,                       --  記番号_口座名義人
					P05.KBG_KOZA_MEIGININ_KANA_NM,                      --  記番号_口座名義人（カナ）
					SUM(WT1.GANKINGAKU)         AS  GANKIN_TRHK,        --  取引先単位元金額合計
					SUM(WT1.ZEIBIKIGO_RIKIN)    AS  ZEIHIKI_AFT_KNGK,   --  取引先単位税引後利金額合計
					SUM(WT1.CLC_FLG)            AS  ZEIHIKI_AFT_FLG      --  税引後利金フラグ( 0:正常 / 1:不正 )
		FROM    	(
						SELECT      MG2.ITAKU_KAISHA_CD,
									P02.TRHK_CD,
								    MG2.MGR_CD,
								    MG2.RBR_YMD,
								    MG2.RBR_KJT,
									pkIpaKibango.getGankinTrhk(
										MG2.ITAKU_KAISHA_CD,
										MG2.MGR_CD,
										MG2.RBR_YMD,
										P02.TRHK_CD
									)  AS  GANKINGAKU,                  --  取引先単位銘柄ごとの元金額合計
									pkIpaKibango.getZeihikiAftKngk(
										MG2.ITAKU_KAISHA_CD,
										MG2.MGR_CD,
										MG2.RBR_KJT,
										pkDate.getMinusDate(MG2.RBR_YMD, 1),
										P02.TRHK_CD
									)  AS  ZEIBIKIGO_RIKIN,             --  取引先単位銘柄ごとの税引後利金額合計
									CASE WHEN 										pkIpaKibango.getZeihikiAftKngk(											MG2.ITAKU_KAISHA_CD,											MG2.MGR_CD,											MG2.RBR_KJT,											pkDate.getMinusDate(MG2.RBR_YMD, 1),											P02.TRHK_CD										)=0 THEN  1  ELSE 0 END   AS  CLC_FLG                       --  取引先単位銘柄ごとの税引後利金フラグ
						FROM	    MGR_RBRKIJ  MG2,
									KBG_SHOKBG  P02,
								    KBG_SHOKIJ  P01,
								    GENSAI_RIREKI Z01
						WHERE       MG2.ITAKU_KAISHA_CD = P01.ITAKU_KAISHA_CD
						AND         MG2.ITAKU_KAISHA_CD = P02.ITAKU_KAISHA_CD
						AND         MG2.ITAKU_KAISHA_CD = l_inItakuKaishaCd
						AND         MG2.MGR_CD          = P01.MGR_CD
						AND         MG2.MGR_CD          = P02.MGR_CD
						AND     (
									(   P02.SHOKAN_KJT      = P01.SHOKAN_KJT     AND
										P01.SHOKAN_YMD     >= MG2.RBR_YMD        AND
										P02.KBG_SHOKAN_KBN  = P01.KBG_SHOKAN_KBN
									)
 									OR (coalesce(trim(both P02.SHOKAN_KJT)::text, '') = '')
								)
						AND     (   --  出力区分（リアル／バッチ）により参照項目が異なる
									(l_inChohyoKbn = '0' AND (MG2.RBR_YMD BETWEEN gRbrYmdFrom AND gRbrYmdTo))  OR (l_inChohyoKbn = '1' AND (MG2.RBR_KJT BETWEEN gRbrKjtFrom AND gRbrKjtTo))
							    )
						AND MG2.ITAKU_KAISHA_CD = Z01.ITAKU_KAISHA_CD 	-- 減債履歴との結合条件は、「特例債のみ」「記番号は振替移行1回のみ」
						AND MG2.MGR_CD = Z01.MGR_CD 						-- という制約に基づくため、この4項目でOK。
						AND MG2.RBR_YMD > Z01.SHOKAN_YMD 	-- 利払日が振替移行日より前の利払情報は出力しない。
						AND Z01.SHOKAN_KBN = '01'			-- (振替移行より利払の処理が先になるので、振替移行日当日も出力しない)
						GROUP BY    MG2.ITAKU_KAISHA_CD,
								    MG2.RBR_YMD,
								    MG2.RBR_KJT,
								    MG2.MGR_CD,
									P02.TRHK_CD
					)   WT1,
					KBG_MTORISAKI   P05,
					MGR_KIHON_VIEW  VMG1
		WHERE       WT1.ITAKU_KAISHA_CD = P05.ITAKU_KAISHA_CD
		AND         WT1.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD
		AND         WT1.MGR_CD          = VMG1.MGR_CD
		AND         WT1.TRHK_CD         = P05.TRHK_CD
		AND         VMG1.MGR_STAT_KBN   = '1'
		AND         VMG1.KK_KANYO_FLG   = '2'
		AND         (trim(both VMG1.ISIN_CD) IS NOT NULL AND (trim(both VMG1.ISIN_CD))::text <> '')
		AND         P05.GNRK_KESSAI_METHOD IN ('1', '2') 
		GROUP BY    P05.GNRK_KESSAI_METHOD,
					WT1.RBR_YMD,
					P05.TRHK_CD,
					P05.BANK_CD,
					P05.SHITEN_CD,
					P05.KOZA_KAMOKU,
					P05.KBG_KOZA_NO,         
					P05.BOJ_TOYO_KOZA_NO,
					P05.TRHK_RNM,
					P05.KBG_KOZA_MEIGININ_NM,
					P05.KBG_KOZA_MEIGININ_KANA_NM
		ORDER BY    P05.GNRK_KESSAI_METHOD,
					WT1.RBR_YMD,
					P05.TRHK_CD;
	--  2007/08/31  EDIT JIP
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 入力パラメータチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inUserId)::text, '') = ''
	OR coalesce(trim(both l_inChohyoKbn)::text, '') = ''
	OR (l_inChohyoKbn = '0' AND coalesce(trim(both l_inKjnYm)::text, '') = '') THEN
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := 'パラメータエラー';
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, l_outSqlErrM);
		RETURN;
	END IF;
	-- 委託会社略称取得
	SELECT
		CASE WHEN JIKO_DAIKO_KBN='2' THEN  BANK_RNM  ELSE ' ' END
	INTO STRICT
		gItakuKaishaRnm
	FROM
		VJIKO_ITAKU
	WHERE
		KAIIN_ID = l_inItakuKaishaCd;
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
	--  2007/08/27  EDIT JIP
	-- 作成年月日
	gSakuseiYmd := gGyomuYmd;
	-- バッチの時
	IF l_inChohyoKbn = '1' THEN
		-- 元利払期日FROM
		gRbrKjtFrom := pkDate.getPlusDate(gGyomuYmd, 21);
		gRbrKjtFrom := pkDate.getPlusDate(gRbrKjtFrom, 1);
		-- 元利払期日TO
		gRbrKjtTo := pkDate.getPlusDateBusiness(gGyomuYmd, 1);
		gRbrKjtTo := pkDate.getPlusDate(gRbrKjtTo, 21);
	ELSE
		--  元利払日FROM
		gRbrYmdFrom := l_inKjnYm || '01';
		--  元利払日TO
		gRbrYmdTo := pkDate.getGetsumatsuYmd(gRbrYmdFrom, 0);
	END IF;
	--  2007/08/27  EDIT JIP
	-- 帳票ワーク削除
	DELETE FROM SREPORT_WK
	WHERE
		KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = gGyomuYmd
		AND CHOHYO_ID IN (C_CHOHYO_ID);
	-- シーケンス初期化
	gSeqNo := 1;
	-- データ読込
	FOR recMeisai IN curMeisai
	LOOP
		-- 元利金決済方法 = 「1:振込」の時
		IF recMeisai.GNRK_KESSAI_METHOD = '1' THEN
			gBankCd                := recMeisai.BANK_CD;                   -- 金融機関コード
			gShitenCd              := recMeisai.SHITEN_CD;                 -- 支店コード
			gKozaKamokuNm          := recMeisai.KOZA_KAMOKU_NM;            -- 口座科目
			gKozaNo                := recMeisai.KBG_KOZA_NO;               -- 口座番号
			gBankNm                := recMeisai.BANK_NM;                   -- 金融機関名称
			gKbgKozaMeigininNm     := recMeisai.KBG_KOZA_MEIGININ_NM;      -- 記番号_口座名義人
			gShitenNm              := recMeisai.SHITEN_NM;                 -- 支店略称
			gKbgKozaMeigininKanaNm := recMeisai.KBG_KOZA_MEIGININ_KANA_NM; -- 記番号_口座名義人（カナ）
		-- 元利金決済方法 = 「2:日銀ネット」の時
		ELSE
			gBankCd                := C_BLANK;                             -- 金融機関コード
			gShitenCd              := C_BLANK;                             -- 支店コード
			gKozaKamokuNm          := C_BLANK;                             -- 口座科目
			gKozaNo                := recMeisai.BOJ_TOYO_KOZA_NO;          -- 日銀当預金_口座番号
			gBankNm                := C_BLANK;                             -- 金融機関名称
			gKbgKozaMeigininNm     := C_BLANK;                             -- 記番号_口座名義人
			gShitenNm              := C_BLANK;                             -- 支店略称
			gKbgKozaMeigininKanaNm := C_BLANK;                             -- 記番号_口座名義人（カナ）
		END IF;
		--  振込金額編集
		--  2007/08/22  EDIT  JIP
		-- 「税引後利金フラグ = '1'」の時 （税引後利金額取得エラー）
		IF recMeisai.ZEIHIKI_AFT_FLG = '1' THEN
			-- 振込金額ゼロ
			gFrkmKngk := 0;
			CALL pkLog.error('EIP475', C_PROGRAM_ID, '委託会社:"' || l_inItakuKaishaCd || '" ' ||
												'取引先:"'   || recMeisai.TRHK_CD || '" ' || 
												'元利払日:"' || recMeisai.RBR_YMD || '"'  );
		ELSE
			-- 振込金額 = 取引先別元金 + 税引後利金額
			gFrkmKngk := recMeisai.GANKIN_TRHK + recMeisai.ZEIHIKI_AFT_KNGK;
		END IF;
		--  2007/08/22  EDIT  JIP
		-- 帳票ワーク追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem002 := SUBSTR(recMeisai.RBR_YMD, 1, 6);	-- 元利払年月
		v_item.l_inItem003 := recMeisai.GNRK_KESSAI_METHOD;	-- 元利金決済方法
		v_item.l_inItem004 := recMeisai.GNRK_KESSAI_METHOD_NM;	-- 元利金決済方法名称
		v_item.l_inItem005 := recMeisai.RBR_YMD;	-- 元利払日
		v_item.l_inItem006 := recMeisai.TRHK_CD;	-- 取引先コード
		v_item.l_inItem007 := gBankCd;	-- 金融機関コード
		v_item.l_inItem008 := gBankNm;	-- 金融機関名称
		v_item.l_inItem009 := gShitenCd;	-- 支店コード
		v_item.l_inItem010 := gShitenNm;	-- 支店略称
		v_item.l_inItem011 := gKozaKamokuNm;	-- 口座科目
		v_item.l_inItem012 := gKozaNo;	-- 口座番号
		v_item.l_inItem013 := gFrkmKngk;	-- 振込金額
		v_item.l_inItem014 := recMeisai.TRHK_RNM;	-- 取引先略称
		v_item.l_inItem015 := gKbgKozaMeigininNm;	-- 記番号_口座名義人
		v_item.l_inItem016 := gKbgKozaMeigininKanaNm;	-- 記番号_口座名義人（カナ）
		v_item.l_inItem017 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem018 := C_CHOHYO_ID;	-- 帳票ＩＤ
		v_item.l_inItem019 := gSakuseiYmd;	-- 作成年月日
		v_item.l_inItem020 := recMeisai.ZEIHIKI_AFT_FLG;	-- 税引後利金フラグ
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> gGyomuYmd,
			l_inChohyoId	=> C_CHOHYO_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> 1,
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		-- シーケンスのカウントアップ
		gSeqNo := gSeqNo + 1;
	END LOOP;
	-- 対象データなし時
	IF gSeqNo = 1 THEN
		-- リアルの時
		IF l_inChohyoKbn = '0' THEN
			-- ヘッダレコードを追加
			CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, gGyomuYmd, C_CHOHYO_ID);
			-- 「対象データなし」データ作成
					-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem017 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem018 := C_CHOHYO_ID;	-- 帳票ＩＤ
		v_item.l_inItem019 := gSakuseiYmd;	-- 作成年月日
		v_item.l_inItem021 := '対象データなし';	-- 対象データなし
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> gGyomuYmd,
			l_inChohyoId	=> C_CHOHYO_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> 1,
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
			-- 正常終了
			l_outSqlCode := pkconstant.success();
			l_outSqlErrM := '';
		ELSE
			-- 終了（対象データなし）
			l_outSqlCode :=C_NO_DATA;
			l_outSqlErrM := '';
		END IF;
	ELSE
		-- ヘッダレコードを追加
		CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, gGyomuYmd, C_CHOHYO_ID);
		-- バッチの時
		IF l_inChohyoKbn = '1' THEN
			-- バッチ帳票印刷データ作成
			CALL pkPrtOk.insertPrtOk(
								l_inUserId,
								l_inItakuKaishaCd,
								gGyomuYmd,
								pkPrtOk.LIST_SAKUSEI_KBN_DAY(),
								C_CHOHYO_ID
								);
		END IF;
		-- 正常終了
		l_outSqlCode := pkconstant.success();
		l_outSqlErrM := '';
	END IF;
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
-- REVOKE ALL ON PROCEDURE spipp006k00r01 ( l_inItakuKaishaCd SREPORT_WK.KEY_CD%TYPE, l_inUserId SREPORT_WK.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_inKjnYm text, l_outSqlCode OUT integer, l_outSqlErrM OUT text ) FROM PUBLIC;