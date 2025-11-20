

DROP TYPE IF EXISTS spipw010k00r02_type_record CASCADE;
CREATE TYPE spipw010k00r02_type_record AS (
		KK_MGR_CD				char(9)			-- 機構銘柄コード
		,SYSZANDAKA				numeric(14)		-- システム当日残高
		,ZENJITSU_SURYO			numeric(14)		-- 数量（前日）
		,TOUJITSU_SURYO			numeric(14)		-- 数量（当日）
		,GENZAI_ZNDK_SURYO		numeric(14)	-- 数量（現在高）
		,MGR_CD					varchar(13)					-- 銘柄コード
		,ISIN_CD         		char(12)       			-- ＩＳＩＮコード
		,MGR_RNM				varchar(44)					-- 銘柄略称
	);


CREATE OR REPLACE PROCEDURE spipw010k00r02 ( 
    l_inItakuKaishaCd TEXT,     -- 委託会社コード
 l_inUserId TEXT,     -- ユーザＩＤ
 l_inChohyoKbn TEXT,     -- 帳票区分
 l_inGyomuYmd TEXT,     -- 業務日付
 l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE,	-- 機構連携作成日時
 l_outSqlCode OUT integer,  -- リターンコード
 l_outSqlErrM OUT text  -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2008
-- * 会社名:JIP
-- *
-- * 概要　:残高照合結果リスト（ＣＢ）
-- *
-- * 引数　:l_inItakuKaishaCd :委託会社コード
-- *        l_inUserId        :ユーザＩＤ
-- *        l_inChohyoKbn     :帳票区分
-- *        l_inGyomuYmd      :業務日付
-- *        l_inDayNightFlg   :日中・夜間フラグ
-- *        l_inKkSakuseiDt   :機構連携作成日時
-- *        l_outSqlCode      :リターンコード
-- *        l_outSqlErrM      :エラーコメント
-- *
-- * 返り値: なし
-- *
-- * @author ASK
-- * @version $Id: SPIPW010K00R02.sql,v 1.8 2008/10/27 00:54:31 miura Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付  開発者名    目的
-- * -------------------------------------------------------------------------
-- *　2008.01.29 ASK        新規作成
-- ***************************************************************************
--	/*==============================================================================
	--                  定数定義                                                    
	--==============================================================================
	C_PROGRAM_ID    CONSTANT varchar(12)              := 'IPW010K00R02'; -- プログラムＩＤ
	C_DUMMY_ID      CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'WKW30001011';  -- ダミーＩＤ（ワークテーブル用）
	C_REPORT_ID     CONSTANT SREPORT_WK.CHOHYO_ID%TYPE := 'IPW30001011';  -- 帳票ID
	C_RCD_NOT_FOUND CONSTANT integer                   := 2;              -- 返値「2:対象データなし」
	--==============================================================================
	--                  変数定義                                                    
	--==============================================================================
	gZenBusinessYmd SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE; -- 業務日付の前営業日
	gBankRnm        VJIKO_ITAKU.BANK_RNM%TYPE;         -- 銀行略称
	gSeqNo          integer;                           -- 連番
	gTaisyoFlg      varchar(1);                       -- 対象データフラグ（'0':対象外データ、'1':対象データ）
	gIpaMgrCnt      numeric;                            -- IPAで出力対象としている銘柄か判定する件数
	gTouZandaka     numeric;                            -- 当日残高
	gMatchCnt       numeric;                            -- 一致件数
	gNoMatchCnt     numeric;                            -- 不一致件数
	gKozaSakuseiYmd SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE; -- 取込電文の作成日
	gMgrShoninCnt   numeric;                            -- IPAで承認済の銘柄かどうか判定する件数
	
	-- 突合データ退避用配列
	much spipw010k00r02_type_record[];
	nomuch spipw010k00r02_type_record[];
	
	-- Item composite type for pkPrint.insertData
	v_item type_sreport_wk_item;
	--==============================================================================
	--                  カーソル定義                                                
	--==============================================================================
	-- ＩＰＡ側データ
	curIpa CURSOR FOR
		SELECT
			VMG1.MGR_CD,                        -- 銘柄コード
			VMG1.FULLSHOKAN_KJT,                -- 満期償還期日
			WMG1.KK_MGR_CD,                     -- 機構銘柄コード
			VMG1.TOKUREI_SHASAI_FLG,            -- 特例社債フラグ
			trim(both MAX(MG3.SHOKAN_YMD)) AS SHOKAN_YMD  -- 償還年月日（最終）
		FROM cb_mgr_kihon wmg1, mgr_kihon_view vmg1
LEFT OUTER JOIN mgr_shokij mg3 ON (VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD AND VMG1.MGR_CD = MG3.MGR_CD)
LEFT OUTER JOIN (SELECT Z01.ITAKU_KAISHA_CD, Z01.MGR_CD, MIN(Z01.SHOKAN_YMD) AS SHOKAN_YMD
			   FROM GENSAI_RIREKI Z01
			  WHERE Z01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			    AND Z01.SHOKAN_KBN = '01'
			  GROUP BY Z01.ITAKU_KAISHA_CD, Z01.MGR_CD) wz01 ON (VMG1.ITAKU_KAISHA_CD = wZ01.ITAKU_KAISHA_CD AND VMG1.MGR_CD = wZ01.MGR_CD)
WHERE VMG1.ITAKU_KAISHA_CD = WMG1.ITAKU_KAISHA_CD AND VMG1.MGR_CD = WMG1.MGR_CD     AND VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND VMG1.MGR_STAT_KBN = '1' AND VMG1.JTK_KBN != '2' -- 新発債の場合発行日の翌営から、特例社債の場合１回目の振替債移行日の翌営から対象となる
  AND pkDate.getYokuBusinessYmd(CASE WHEN VMG1.TOKUREI_SHASAI_FLG='Y' THEN 													wZ01.SHOKAN_YMD  ELSE VMG1.HAKKO_YMD END ) <= l_inGyomuYmd GROUP BY
			VMG1.MGR_CD,
			VMG1.FULLSHOKAN_KJT,
			WMG1.KK_MGR_CD,
			VMG1.TOKUREI_SHASAI_FLG
		ORDER BY
			WMG1.KK_MGR_CD;
	-- 突合データ
	curMeisai CURSOR FOR
		SELECT
			T.KK_MGR_CD,         -- 機構銘柄コード
			T.ZENJITSU_SURYO,    -- 数量（前日）
			T.TOUJITSU_SURYO,    -- 数量（当日）
			T.GENZAI_ZNDK_SURYO, -- 数量（現在高）
			VWMG1.MGR_CD,        -- 銘柄コード
			VWMG1.ISIN_CD,       -- ＩＳＩＮコード
			VWMG1.MGR_RNM         -- 銘柄略称
		FROM (
				SELECT  -- 帳票ワークメイン・口座処理結果（ＣＢ）外部結合
					SC16.ITEM001 AS KK_MGR_CD, -- 機構銘柄コード
					W01.ZENJITSU_SURYO,        -- 数量（前日）
					W01.TOUJITSU_SURYO,        -- 数量（当日）
					W01.GENZAI_ZNDK_SURYO       -- 数量（現在高）
				FROM sreport_wk sc16
LEFT OUTER JOIN cb_koza_kekka w01 ON (SC16.KEY_CD = W01.ITAKU_KAISHA_CD AND SC16.ITEM001 = W01.KK_MGR_CD AND gKozaSakuseiYmd = W01.KK_SAKUSEI_YMD AND '010' = W01.RESULT_DATA_KBN)
WHERE SC16.KEY_CD = l_inItakuKaishaCd AND SC16.USER_ID = l_inUserId AND SC16.CHOHYO_KBN = l_inChohyoKbn AND SC16.SAKUSEI_YMD = l_inGyomuYmd AND SC16.CHOHYO_ID = C_DUMMY_ID
UNION

				SELECT  -- 口座処理結果（ＣＢ）メイン・帳票ワーク外部結合
					W01.KK_MGR_CD,        -- 機構銘柄コード
					W01.ZENJITSU_SURYO,   -- 数量（前日）
					W01.TOUJITSU_SURYO,   -- 数量（当日）
					W01.GENZAI_ZNDK_SURYO  -- 数量（現在高）
				FROM cb_koza_kekka w01
LEFT OUTER JOIN sreport_wk sc16 ON (W01.ITAKU_KAISHA_CD = SC16.KEY_CD AND W01.KK_MGR_CD = SC16.ITEM001 AND l_inUserId = SC16.USER_ID AND l_inChohyoKbn = SC16.CHOHYO_KBN AND l_inGyomuYmd = SC16.SAKUSEI_YMD AND C_DUMMY_ID = SC16.CHOHYO_ID)
WHERE W01.ITAKU_KAISHA_CD = l_inItakuKaishaCd AND W01.KK_SAKUSEI_YMD = gKozaSakuseiYmd AND W01.RESULT_DATA_KBN = '010'     ) t
LEFT OUTER JOIN (
				SELECT
					VMG1.MGR_CD,   -- 銘柄コード
					VMG1.ISIN_CD,  -- ＩＳＩＮコード
					VMG1.MGR_RNM,  -- 銘柄略称
					WMG1.KK_MGR_CD  -- 機構銘柄コード
				FROM
					MGR_KIHON_VIEW VMG1,
					CB_MGR_KIHON WMG1
				WHERE
					VMG1.ITAKU_KAISHA_CD = WMG1.ITAKU_KAISHA_CD
					AND VMG1.MGR_CD = WMG1.MGR_CD
					AND VMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
					AND VMG1.MGR_STAT_KBN = '1'
					AND VMG1.JTK_KBN != '2'
			) vwmg1 ON (T.KK_MGR_CD = VWMG1.KK_MGR_CD) ORDER BY
			T.KK_MGR_CD;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 引数（委託会社）NULLチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' THEN
		-- パラメータエラーとして出力
		CALL pkLog.error('ECM501', C_PROGRAM_ID, '委託会社コード');
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '委託会社・パラメータエラー';
		RETURN;
	END IF;
	-- 引数（ユーザＩＤ）NULLチェック
	IF coalesce(trim(both l_inUserId)::text, '') = '' THEN
		-- パラメータエラーとして出力
		CALL pkLog.error('ECM501', C_PROGRAM_ID, 'ユーザＩＤ');
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := 'ユーザＩＤ・パラメータエラー';
		RETURN;
	END IF;
	-- 引数（帳票区分）NULLチェック
	IF coalesce(trim(both l_inChohyoKbn)::text, '') = '' THEN
		-- パラメータエラーとして出力
		CALL pkLog.error('ECM501', C_PROGRAM_ID, '帳票区分');
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '帳票区分・パラメータエラー';
		RETURN;
	END IF;
	-- 引数（業務日付）NULLチェック
	IF coalesce(trim(both l_inGyomuYmd)::text, '') = '' THEN
		-- パラメータエラーとして出力
		CALL pkLog.error('ECM501', C_PROGRAM_ID, '業務日付');
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '業務日付・パラメータエラー';
		RETURN;
	END IF;
	IF coalesce(trim(both l_inKkSakuseiDt)::text, '') = '' THEN
		CALL pkLog.error('ECM501', C_PROGRAM_ID, '機構作成日時');
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '機構作成日時 パラメータエラー';
		RETURN;
	END IF;
	-- 業務日付の前営業日取得
	gZenBusinessYmd := pkDate.getZenBusinessYmd(l_inGyomuYmd);
	-- 取込電文の作成日取得
	SELECT RT02.ITEM006
	  INTO STRICT gKozaSakuseiYmd
	  FROM KK_RENKEI RT02
	 WHERE RT02.KK_SAKUSEI_DT = l_inKkSakuseiDt
	   AND RT02.DENBUN_MEISAI_NO = '1';
	-- 委託会社略称取得
	SELECT
		CASE WHEN JIKO_DAIKO_KBN='2' THEN  BANK_RNM  ELSE ' ' END
	INTO STRICT
		gBankRnm
	FROM
		VJIKO_ITAKU
	WHERE
		KAIIN_ID = l_inItakuKaishaCd;
	-- 帳票ワーク削除
	DELETE FROM SREPORT_WK
	WHERE
		KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = l_inGyomuYmd
		AND CHOHYO_ID IN (C_REPORT_ID, C_DUMMY_ID);
	-- 連番初期化
	gSeqNo := 1;
	-- ＩＰＡ側データ取得（EOFまでループ処理）
	FOR recIpa IN curIpa LOOP
		-- 対象銘柄か判別---------------------------------------------------------------------------
		-- 永久債の時
		IF recIpa.FULLSHOKAN_KJT = '99999999' THEN
			-- 償還年月日（最終）がNULLの時（償還回次存在しない）
			IF coalesce(recIpa.SHOKAN_YMD::text, '') = '' THEN
				-- 新発債・発行後で償還回次が存在しない場合は必ず残高があると判断できる
				IF recIpa.TOKUREI_SHASAI_FLG = 'N' THEN
					-- 対象データフラグ・オン
					gTaisyoFlg := '1';
				ELSE
				-- 特例債の場合は振替移行前なこともあるので、業務日付前営業日時点の残高を確認する
					IF pkIpaZndk.getKjnZndk(l_inItakuKaishaCd, recIpa.MGR_CD, gZenBusinessYmd, 3) = 0 THEN
						-- 対象データフラグ・オフ
						gTaisyoFlg := '0';
					ELSE
						-- 対象データフラグ・オン
						gTaisyoFlg := '1';
					END IF;
				END IF;
			-- 償還年月日（最終）がNULLでない時（償還回次存在する）
			ELSE
				-- 償還年月日（最終）時点の残高が０の時
				IF pkIpaZndk.getKjnZndk(l_inItakuKaishaCd, recIpa.MGR_CD, recIpa.SHOKAN_YMD, 3) = 0 THEN
					-- 業務日付　≦　最終償還日　＋１営業日の時
					IF l_inGyomuYmd <= pkDate.getYokuBusinessYmd(recIpa.SHOKAN_YMD) THEN
						-- 対象データフラグ・オン
						gTaisyoFlg := '1';
					-- その他の時
					ELSE
						-- 対象データフラグ・オフ
						gTaisyoFlg := '0';
					END IF;
				-- その他の時
				ELSE
					-- 対象データフラグ・オン
					gTaisyoFlg := '1';
				END IF;
			END IF;
		-- 永久債でない時
		ELSE
			-- 償還年月日（最終）がNULLの時（償還回次存在しない）
			IF coalesce(recIpa.SHOKAN_YMD::text, '') = '' THEN
				-- 対象データフラグ・オフ
				gTaisyoFlg := '0';
			-- 償還年月日（最終）がNULLでない時（償還回次存在する）
			ELSE
				-- 業務日付　≦　最終償還日　＋１営業日の時
				IF l_inGyomuYmd <= pkDate.getYokuBusinessYmd(recIpa.SHOKAN_YMD) THEN
					-- 対象データフラグ・オン
					gTaisyoFlg := '1';
				-- その他の時
				ELSE
					-- 対象データフラグ・オフ
					gTaisyoFlg := '0';
				END IF;
			END IF;
		END IF;
		--------------------------------------------------------------------------------------------
		-- 対象データフラグがオンの時
		IF gTaisyoFlg = '1' THEN
			-- 帳票ワーク登録（ＩＰＡ側の銘柄コードを保持・・・ダミーの帳票ＩＤを使用）
			v_item := NULL;  -- Initialize to NULL (all fields NULL)
			v_item.l_inItem001 := recIpa.KK_MGR_CD;  -- 機構銘柄コード
			CALL pkPrint.insertData(
				l_inKeyCd      => l_inItakuKaishaCd::varchar, -- 識別コード
				l_inUserId     => l_inUserId::varchar,        -- ユーザＩＤ
				l_inChohyoKbn  => l_inChohyoKbn::varchar,     -- 帳票区分
				l_inSakuseiYmd => l_inGyomuYmd::varchar,      -- 作成年月日
				l_inChohyoId   => C_DUMMY_ID,        -- 帳票ＩＤ
				l_inSeqNo      => gSeqNo,            -- 連番
				l_inHeaderFlg  => 1,                 -- ヘッダフラグ
				l_inItem       => v_item,            -- Item composite type
				l_inKousinId   => l_inUserId::varchar,        -- 更新者
				l_inSakuseiId  => l_inUserId::varchar          -- 作成者
			);
			-- 連番インクリメント
			gSeqNo := gSeqNo + 1;
		END IF;
	END LOOP;
	-- 変数初期化------------------
	-- 連番
	gSeqNo := 1;
	-- 一致件数
	gMatchCnt := 0;
	-- 不一致件数
	gNoMatchCnt := 0;
	-- 配列初期化
	much := ARRAY[]::spipw010k00r02_type_record[];
	nomuch := ARRAY[]::spipw010k00r02_type_record[];
	-------------------------------
	-- 突合データ取得（EOFまでループ処理）
	-- 配列に退避
	FOR recMeisai IN curMeisai LOOP
		-- IPA側の対象となっているか判定する（対象とならないときは残高はNULL）
		SELECT COUNT(KEY_CD)
		  INTO STRICT gIpaMgrCnt
		  FROM SREPORT_WK SC16
		 WHERE SC16.KEY_CD = l_inItakuKaishaCd
		   AND SC16.USER_ID = l_inUserId
		   AND SC16.CHOHYO_KBN = l_inChohyoKbn
		   AND SC16.SAKUSEI_YMD = l_inGyomuYmd
		   AND SC16.CHOHYO_ID = C_DUMMY_ID
		   AND SC16.ITEM001 = recMeisai.KK_MGR_CD;
		IF coalesce(recMeisai.MGR_CD::text, '') = '' OR gIpaMgrCnt = 0 THEN
			-- 当日残高設定
			gTouZandaka := NULL;
		ELSE
			-- 当日残高取得
			gTouZandaka := pkIpaZndk.getKjnZndk(
										l_inItakuKaishaCd, -- 委託会社コード
										recMeisai.MGR_CD,  -- 銘柄コード
										gZenBusinessYmd,   -- 基準日（業務日付の前営業日）
										3
										);
		END IF;
		-- 当日残高が一致の時
		IF gTouZandaka = recMeisai.TOUJITSU_SURYO THEN
			much := array_append(much, ROW(
				trim(both recMeisai.KK_MGR_CD),
				gTouZandaka,
				recMeisai.ZENJITSU_SURYO,
				recMeisai.TOUJITSU_SURYO,
				recMeisai.GENZAI_ZNDK_SURYO,
				recMeisai.MGR_CD,
				recMeisai.ISIN_CD,
				recMeisai.MGR_RNM
			)::spipw010k00r02_type_record);
			-- 一致件数インクリメント
			gMatchCnt := gMatchCnt + 1;
		-- 当日残高が不一致の時
		ELSE
			nomuch := array_append(nomuch, ROW(
				trim(both recMeisai.KK_MGR_CD),
				gTouZandaka,
				recMeisai.ZENJITSU_SURYO,
				recMeisai.TOUJITSU_SURYO,
				recMeisai.GENZAI_ZNDK_SURYO,
				recMeisai.MGR_CD,
				recMeisai.ISIN_CD,
				recMeisai.MGR_RNM
			)::spipw010k00r02_type_record);
			-- 不一致件数インクリメント
			gNoMatchCnt := gNoMatchCnt + 1;
			-- 当該銘柄が承認済かどうか判定するための件数を取得
			SELECT COUNT(WMG1.MGR_CD)
			  INTO STRICT gMgrShoninCnt
			  FROM CB_MGR_KIHON WMG1, MGR_STS MG0
			 WHERE WMG1.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
			   AND WMG1.MGR_CD = MG0.MGR_CD
			   AND WMG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			   AND WMG1.KK_MGR_CD = trim(both recMeisai.KK_MGR_CD)
			   AND MG0.MGR_STAT_KBN = '1'
			   AND MG0.MASSHO_FLG = '0';
			-- 銘柄が承認済、未抹消の場合
			IF gMgrShoninCnt = 1 THEN
				-- CB-00242対応
				-- 残高がマイナスになる場合、機構連携テーブル更新
				UPDATE
					KK_RENKEI
				SET
					SOUJU_ERR_CD = '30',              -- 送受信エラー事由コード（項目不一致あり）
					DENBUN_STAT = '22',               -- 電文明細ステータス（処理エラー）
					ERR_ZUMI_CD = '0',                -- エラー対応済みフラグ（通常終了）
					DENBUN_SHURUI_FLG = '0',          -- 電文種類フラグ（正常電文）
					KOUSIN_ID = pkconstant.BATCH_USER()  -- 更新者
				WHERE
					KK_SAKUSEI_DT = l_inKkSakuseiDt      -- 機構連携作成日時
				AND ITEM009       = recMeisai.KK_MGR_CD  -- 機構銘柄コード
				AND ITEM008       = '010';				-- 残高レコード
			-- それ以外の場合
			ELSE
				UPDATE
					KK_RENKEI
				SET
					SOUJU_ERR_CD = '41',              -- 送受信エラー事由コード（対象データなし）
					DENBUN_STAT = '22',               -- 電文明細ステータス（処理エラー）
					ERR_ZUMI_CD = '0',                -- エラー対応済みフラグ（通常終了）
					DENBUN_SHURUI_FLG = '0',          -- 電文種類フラグ（正常電文）
					KOUSIN_ID = pkconstant.BATCH_USER()  -- 更新者
				WHERE
					KK_SAKUSEI_DT = l_inKkSakuseiDt      -- 機構連携作成日時
				AND ITEM009       = recMeisai.KK_MGR_CD  -- 機構銘柄コード
				AND ITEM008       = '010';				-- 残高レコード
			END IF;
		END IF;
	END LOOP;
	-- 不一致件数を出力
	IF gNoMatchCnt >= 0 THEN
		-- 帳票ワーク登録（不一致件数）
		v_item := NULL;  -- Initialize to NULL (all fields NULL)
		v_item.l_inItem001 := l_inGyomuYmd;      -- データ基準日
		v_item.l_inItem002 := gBankRnm;          -- 委託会社略名
		v_item.l_inItem003 := l_inGyomuYmd;      -- 業務日付
		v_item.l_inItem004 := gKozaSakuseiYmd;   -- 口座処理結果作成日時
		v_item.l_inItem006 := '不一致';          -- 突合結果名称
		v_item.l_inItem007 := pkcharacter.numeric_to_char(gNoMatchCnt);       -- 件数
		v_item.l_inItem016 := l_inUserId;        -- ユーザーＩＤ
		v_item.l_inItem017 := C_REPORT_ID;         -- 帳票ＩＤ
		v_item.l_inItem018 := pkcharacter.numeric_to_char(gNoMatchCnt + gMatchCnt); -- 総件数
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd::varchar, -- 識別コード
			l_inUserId     => l_inUserId::varchar,        -- ユーザＩＤ
			l_inChohyoKbn  => l_inChohyoKbn::varchar,     -- 帳票区分
			l_inSakuseiYmd => l_inGyomuYmd::varchar,      -- 作成年月日
			l_inChohyoId   => C_REPORT_ID,         -- 帳票ＩＤ
			l_inSeqNo      => gSeqNo,                 -- 連番
			l_inHeaderFlg  => 1,                 -- ヘッダフラグ
			l_inItem       => v_item,            -- Item composite type
			l_inKousinId   => l_inUserId::varchar,        -- 更新者
			l_inSakuseiId  => l_inUserId::varchar          -- 作成者
		);
	END IF;
	-- 不一致
	FOR i IN 1..coalesce(array_length(nomuch, 1), 0) LOOP
		-- 連番インクリメント
		gSeqNo := gSeqNo + 1;
		-- 帳票ワーク登録
		v_item := NULL;  -- Initialize to NULL (all fields NULL)
		v_item.l_inItem001 := l_inGyomuYmd;                -- データ基準日
		v_item.l_inItem002 := gBankRnm;                    -- 委託会社略名
		v_item.l_inItem003 := l_inGyomuYmd;                -- 業務日付
		v_item.l_inItem004 := gKozaSakuseiYmd;             -- 口座処理結果作成日時
		v_item.l_inItem008 := nomuch[i].KK_MGR_CD;         -- 機構銘柄コード
		v_item.l_inItem009 := nomuch[i].ISIN_CD;           -- ＩＳＩＮコード
		v_item.l_inItem010 := nomuch[i].MGR_CD;            -- 銘柄コード
		v_item.l_inItem011 := nomuch[i].MGR_RNM;           -- 銘柄略称
		v_item.l_inItem012 := pkcharacter.numeric_to_char(nomuch[i].SYSZANDAKA);        -- 本システム・当日残高
		v_item.l_inItem013 := pkcharacter.numeric_to_char(nomuch[i].TOUJITSU_SURYO);    -- 機構・当日残高
		v_item.l_inItem014 := pkcharacter.numeric_to_char(nomuch[i].GENZAI_ZNDK_SURYO); -- 機構・現在残高
		v_item.l_inItem015 := pkcharacter.numeric_to_char(nomuch[i].ZENJITSU_SURYO);    -- 機構・前日残高
		v_item.l_inItem016 := l_inUserId;                  -- ユーザーＩＤ
		v_item.l_inItem017 := C_REPORT_ID;                   -- 帳票ＩＤ
		v_item.l_inItem018 := pkcharacter.numeric_to_char(gNoMatchCnt + gMatchCnt);     -- 総件数
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd::varchar,           -- 識別コード
			l_inUserId     => l_inUserId::varchar,                  -- ユーザＩＤ
			l_inChohyoKbn  => l_inChohyoKbn::varchar,               -- 帳票区分
			l_inSakuseiYmd => l_inGyomuYmd::varchar,                -- 作成年月日
			l_inChohyoId   => C_REPORT_ID,                   -- 帳票ＩＤ
			l_inSeqNo      => gSeqNo,                      -- 連番
			l_inHeaderFlg  => 1,                           -- ヘッダフラグ
			l_inItem       => v_item,                      -- Item composite type
			l_inKousinId   => l_inUserId::varchar,                  -- 更新者
			l_inSakuseiId  => l_inUserId::varchar                    -- 作成者
		);
	END LOOP;
	-- 一致件数を出力
	IF gMatchCnt >= 0 THEN
		-- 連番インクリメント
		gSeqNo := gSeqNo + 1;
		-- 帳票ワーク登録（空行）
		v_item := NULL;  -- Initialize to NULL (all fields NULL)
		v_item.l_inItem001 := l_inGyomuYmd;      -- データ基準日
		v_item.l_inItem002 := gBankRnm;          -- 委託会社略名
		v_item.l_inItem003 := l_inGyomuYmd;      -- 業務日付
		v_item.l_inItem004 := gKozaSakuseiYmd;   -- 口座処理結果作成日時
		v_item.l_inItem016 := l_inUserId;        -- ユーザーＩＤ
		v_item.l_inItem017 := C_REPORT_ID;         -- 帳票ＩＤ
		v_item.l_inItem018 := pkcharacter.numeric_to_char(gNoMatchCnt + gMatchCnt); -- 総件数
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd::varchar, -- 識別コード
			l_inUserId     => l_inUserId::varchar,        -- ユーザＩＤ
			l_inChohyoKbn  => l_inChohyoKbn::varchar,     -- 帳票区分
			l_inSakuseiYmd => l_inGyomuYmd::varchar,      -- 作成年月日
			l_inChohyoId   => C_REPORT_ID,         -- 帳票ＩＤ
			l_inSeqNo      => gSeqNo,            -- 連番
			l_inHeaderFlg  => 1,                 -- ヘッダフラグ
			l_inItem       => v_item,            -- Item composite type
			l_inKousinId   => l_inUserId::varchar,        -- 更新者
			l_inSakuseiId  => l_inUserId::varchar          -- 作成者
		);
		-- 連番インクリメント
		gSeqNo := gSeqNo + 1;
		-- 帳票ワーク登録（一致件数）
		v_item := NULL;  -- Initialize to NULL (all fields NULL)
		v_item.l_inItem001 := l_inGyomuYmd;      -- データ基準日
		v_item.l_inItem002 := gBankRnm;          -- 委託会社略名
		v_item.l_inItem003 := l_inGyomuYmd;      -- 業務日付
		v_item.l_inItem004 := gKozaSakuseiYmd;   -- 口座処理結果作成日時
		v_item.l_inItem006 := '一致';            -- 突合結果名称
		v_item.l_inItem007 := pkcharacter.numeric_to_char(gMatchCnt);         -- 件数
		v_item.l_inItem016 := l_inUserId;        -- ユーザーＩＤ
		v_item.l_inItem017 := C_REPORT_ID;         -- 帳票ＩＤ
		v_item.l_inItem018 := pkcharacter.numeric_to_char(gNoMatchCnt + gMatchCnt); -- 総件数
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd::varchar, -- 識別コード
			l_inUserId     => l_inUserId::varchar,        -- ユーザＩＤ
			l_inChohyoKbn  => l_inChohyoKbn::varchar,     -- 帳票区分
			l_inSakuseiYmd => l_inGyomuYmd::varchar,      -- 作成年月日
			l_inChohyoId   => C_REPORT_ID,         -- 帳票ＩＤ
			l_inSeqNo      => gSeqNo,            -- 連番
			l_inHeaderFlg  => 1,                 -- ヘッダフラグ
			l_inItem       => v_item,            -- Item composite type
			l_inKousinId   => l_inUserId::varchar,        -- 更新者
			l_inSakuseiId  => l_inUserId::varchar          -- 作成者
		);
	END IF;	
	-- 一致
	FOR i IN 1..coalesce(array_length(much, 1), 0) LOOP
		-- 連番インクリメント
		gSeqNo := gSeqNo + 1;
		-- 帳票ワーク登録
		v_item := NULL;  -- Initialize to NULL (all fields NULL)
		v_item.l_inItem001 := l_inGyomuYmd;                -- データ基準日
		v_item.l_inItem002 := gBankRnm;                    -- 委託会社略名
		v_item.l_inItem003 := l_inGyomuYmd;                -- 業務日付
		v_item.l_inItem004 := gKozaSakuseiYmd;             -- 口座処理結果作成日時
		v_item.l_inItem008 := much[i].KK_MGR_CD;         -- 機構銘柄コード
		v_item.l_inItem009 := much[i].ISIN_CD;           -- ＩＳＩＮコード
		v_item.l_inItem010 := much[i].MGR_CD;            -- 銘柄コード
		v_item.l_inItem011 := much[i].MGR_RNM;           -- 銘柄略称
		v_item.l_inItem012 := pkcharacter.numeric_to_char(much[i].SYSZANDAKA);        -- 本システム・当日残高
		v_item.l_inItem013 := pkcharacter.numeric_to_char(much[i].TOUJITSU_SURYO);    -- 機構・当日残高
		v_item.l_inItem014 := pkcharacter.numeric_to_char(much[i].GENZAI_ZNDK_SURYO); -- 機構・現在残高
		v_item.l_inItem015 := pkcharacter.numeric_to_char(much[i].ZENJITSU_SURYO);    -- 機構・前日残高
		v_item.l_inItem016 := l_inUserId;                  -- ユーザーＩＤ
		v_item.l_inItem017 := C_REPORT_ID;                   -- 帳票ＩＤ
		v_item.l_inItem018 := pkcharacter.numeric_to_char(gNoMatchCnt + gMatchCnt);     -- 総件数
		CALL pkPrint.insertData(
			l_inKeyCd      => l_inItakuKaishaCd::varchar,           -- 識別コード
			l_inUserId     => l_inUserId::varchar,                  -- ユーザＩＤ
			l_inChohyoKbn  => l_inChohyoKbn::varchar,               -- 帳票区分
			l_inSakuseiYmd => l_inGyomuYmd::varchar,                -- 作成年月日
			l_inChohyoId   => C_REPORT_ID,                   -- 帳票ＩＤ
			l_inSeqNo      => gSeqNo,                      -- 連番
			l_inHeaderFlg  => 1,                           -- ヘッダフラグ
			l_inItem       => v_item,                      -- Item composite type
			l_inKousinId   => l_inUserId::varchar,                  -- 更新者
			l_inSakuseiId  => l_inUserId::varchar                    -- 作成者
		);
	END LOOP;
	-- 対象データが存在しなかった場合
	IF gMatchCnt = 0
	AND gNoMatchCnt = 0 THEN
		l_outSqlCode := C_RCD_NOT_FOUND;
		l_outSqlErrM := '対象データなし';
		RETURN;
	END IF;
	-- 帳票ワーク削除（ＩＰＡ側の銘柄コード情報）
	DELETE FROM SREPORT_WK
	WHERE
		KEY_CD = l_inItakuKaishaCd
		AND USER_ID = l_inUserId
		AND CHOHYO_KBN = l_inChohyoKbn
		AND SAKUSEI_YMD = l_inGyomuYmd
		AND CHOHYO_ID = C_DUMMY_ID;
	-- ヘッダレコード作成
	CALL pkPrint.insertHeader(
		l_inItakuKaishaCd, -- 委託会社コード
		l_inUserId,        -- ユーザＩＤ
		l_inChohyoKbn,     -- 帳票区分
		l_inGyomuYmd,      -- 業務日付
		C_REPORT_ID           -- 帳票ＩＤ
	);
	-- バッチ帳票印刷管理登録
	CALL pkPrtOk.insertPrtOk(
		l_inUserId,        -- ユーザＩＤ
		l_inItakuKaishaCd, -- 委託会社コード
		l_inGyomuYmd,      -- 業務日付
		'3',               -- 帳票作成区分(随時)
		C_REPORT_ID           -- 帳票ＩＤ
	);
	-- 正常終了
	l_outSqlCode := pkconstant.success();
	l_outSqlErrM := '';
	RETURN;
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', C_PROGRAM_ID, 'SQLERRM:' || SQLERRM);
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLSTATE || SQLERRM;
		RETURN;
END;
$body$
LANGUAGE PLPGSQL
;
