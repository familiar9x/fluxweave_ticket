

-- ==================================================================
-- SPIP07821
-- 当日送受信件数一覧作成のため帳票ワークテーブルにINSERTする。
--
--
-- 作成：2005/04/26		I.Noshita
-- @version $Id: spIp07821.sql,v 1.12 2006/10/18 07:58:47 yoshimoto Exp $
--
-- ==================================================================
CREATE OR REPLACE PROCEDURE spip07821 ( l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inUserId TEXT,		-- ユーザーID
 l_inChohyoKbn TEXT,		-- 帳票区分
 l_inGyomuYmd TEXT,		-- 業務日付
 l_outSqlCode OUT integer,		-- リターン値
 l_outSqlErrM OUT text	-- エラーコメント
 ) AS $body$
DECLARE

--==============================================================================
--					デバッグ機能													
--==============================================================================
	DEBUG	numeric(1)	:= 0;
--==============================================================================
--					定数定義													
--==============================================================================
	RTN_OK				CONSTANT integer		:= 0;				-- 正常
	RTN_NG				CONSTANT integer		:= 1;				-- 予期したエラー
	RTN_NODATA			CONSTANT integer		:= 2;				-- データなし
	RTN_FATAL			CONSTANT integer		:= 99;				-- 予期せぬエラー
	REPORT_ID			CONSTANT text		:= 'IP030007821';	-- 帳票ID
--==============================================================================
--					変数定義													
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	wk_kk_online_flg		char(1)			:= NULL;		-- 機構オンライン接続フラグ
	wk_jiko_daiko_kbn		char(1)			:= NULL;		-- 自行代行区分
	wk_bank_rnm				varchar(20)	:= NULL;		-- 委託会社略称
    wk_bic_cd               SOWN_INFO.BIC_CD%TYPE := NULL;  -- ＢＩＣコード
	gRtnCd					integer :=	RTN_OK;			-- リターンコード
	gSeqNo					integer := 1;				-- シーケンス
	gSoujuKbn				varchar(1)		:= NULL;
    gSakuseiYmd             varchar(8);
	getDebun CURSOR FOR
		SELECT
			b.JIP_DENBUN_CD,
			b.DENBUN_NM,
			coalesce(a.COUNT,0) AS soujuCount,
			a.SOUJU_KBN,
			(SELECT CODE_NM
				FROM SCODE
				WHERE CODE_SHUBETSU = '737'
				AND CODE_VALUE = a.SOUJU_METHOD_CD) AS soujuNm
		FROM (SELECT
				MD01.JIP_DENBUN_CD,
				MD01.DENBUN_NM,
				RT02.SOUJU_METHOD_CD,
				COUNT(RT02.JIP_DENBUN_CD) AS count,
				RT02.SOUJU_KBN
			FROM mdenbun_jip md01
LEFT OUTER JOIN kk_renkei rt02 ON (MD01.JIP_DENBUN_CD = RT02.JIP_DENBUN_CD)
WHERE MD01.shiyo_flg = '1' AND RT02.SR_BIC_CD = wk_bic_cd AND SUBSTR(RT02.SOUJU_DT, 1, 8) = pkDate.getGyomuYmd() AND SUBSTR(RT02.KK_SAKUSEI_DT, 20, 1) <> 'H'  GROUP BY
				MD01.JIP_DENBUN_CD,
				MD01.DENBUN_NM,
				RT02.SOUJU_METHOD_CD,
				RT02.SOUJU_KBN
			) a,
			(SELECT
				MD01.JIP_DENBUN_CD,
				MD01.DENBUN_NM
			FROM
				MDENBUN_JIP MD01
			WHERE
				MD01.SHIYO_FLG = '1'
			)b
		WHERE
			a.JIP_DENBUN_CD = b.JIP_DENBUN_CD
		ORDER BY
			a.SOUJU_METHOD_CD,
			b.JIP_DENBUN_CD;
	getJikouInfo CURSOR FOR
		SELECT
			kk_online_connection_flg,	-- 機構オンライン接続フラグ
			jiko_daiko_kbn,             -- 自行代行区分
			bank_rnm,                   -- 委託会社略称
            		bic_cd                       -- BICコード
		FROM
			VJIKO_ITAKU
		WHERE
			kaiin_id = l_inItakuKaishaCd
			OR (l_inItakuKaishaCd = pkconstant.DAIKO_KEY_CD() AND JIKO_DAIKO_KBN = '2')
		ORDER BY kaiin_id;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp07821 START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
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
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;
    -- ヘッダレコードを追加
    CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
    -- 夜間バッチで作成する場合にはデータ基準日を出力する。
    IF l_inChohyoKbn = pkKakuninList.CHOHYO_KBN_BATCH() THEN
        gSakuseiYmd := l_inGyomuYmd;
    ELSE
        gSakuseiYmd := NULL;
    END IF;
	FOR recJ in getJikouInfo LOOP
		wk_bic_cd := recJ.bic_cd;
		gSoujuKbn := NULL;
		-- 自行代行区分が'2'出ない場合、委託会社略称を表示しない
		IF recJ.jiko_daiko_kbn != '2' THEN
			wk_bank_rnm := NULL;
		ELSE
			wk_bank_rnm := recJ.bank_rnm;
		END IF;
	        FOR recb in getDebun LOOP
			IF gSoujuKbn <> recb.souju_kbn THEN
						-- 帳票ワークへデータを追加
						-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := wk_bank_rnm;	-- 委託会社略称
		v_item.l_inItem002 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem003 := ' ';	-- JIP電文コード
		v_item.l_inItem004 := ' ';	-- 電文名称L
		v_item.l_inItem005 := ' ';	-- 件数
		v_item.l_inItem006 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem007 := recb.soujuNm;	-- 送受信方法名称
		v_item.l_inItem009 := gSakuseiYmd;	-- データ基準日
		
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
				gSeqNo := gSeqNo + 1;
			END IF;
			-- 帳票ワークへデータを追加
					-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := wk_bank_rnm;	-- 委託会社略称
		v_item.l_inItem002 := l_inUserId;	-- ユーザＩＤ
		v_item.l_inItem003 := recb.jip_denbun_cd;	-- JIP電文コード
		v_item.l_inItem004 := recb.denbun_nm;	-- 電文名称L
		v_item.l_inItem005 := recb.soujuCount;	-- 件数
		v_item.l_inItem006 := REPORT_ID;	-- 帳票ＩＤ
		v_item.l_inItem007 := recb.soujuNm;	-- 送受信方法名称
		v_item.l_inItem009 := gSakuseiYmd;	-- データ基準日
		
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
			gSeqNo := gSeqNo + 1;
			gSoujuKbn := recb.souju_kbn;
	        end loop;
	end loop;
		IF gSeqNo = 1 THEN
			-- 対象データなし
			gRtnCd := RTN_NODATA;
			-- 代行オプションの場合、データなし時は名称を表示しない
			IF l_inItakuKaishaCd = pkconstant.DAIKO_KEY_CD() THEN
				wk_bank_rnm := NULL;
			END IF;
			-- 帳票ワークへデータを追加
					-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := wk_bank_rnm;	-- 委託会社略称
		v_item.l_inItem002 := l_inUserId;
		v_item.l_inItem008 := '対象データなし';
		v_item.l_inItem006 := REPORT_ID;
		v_item.l_inItem009 := gSakuseiYmd;	-- データ基準日
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> REPORT_ID,
			l_inSeqNo		=> '1',
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
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp07821 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip07821 ( l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;