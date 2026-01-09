




CREATE OR REPLACE PROCEDURE spip07811 ( l_inItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE, -- 委託会社コード
 l_inUserId SREPORT_WK.USER_ID%TYPE,            -- ユーザーID
 l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE,         -- 帳票区分
 l_inGyomuYmd SREPORT_WK.SAKUSEI_YMD%TYPE,        -- 業務日付
 l_outSqlCode OUT integer,                             -- リターン値
 l_outSqlErrM OUT text                            -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2006
-- * 会社名: JIP
-- *
-- * 当日オペ件数一覧作成のため帳票ワークテーブルを作成する。
-- *
-- * @author 三浦　秀吾(ASK)
-- * @version $Id: spIp07811.sql,v 1.20 2006/03/03 21:54:48 miura Exp $
-- *
-- * @param l_inItakuKaishaCd 委託会社コード
-- * @param l_inUserId        ユーザーID
-- * @param l_inChohyoKbn     帳票区分
-- * @param l_inGyomuYmd      業務日付
-- * @param l_outSqlCode      リターン値
-- * @param l_outSqlErrM      エラーコメント
-- 
--==============================================================================
--                  定数定義                                                    
--==============================================================================
	C_OK                    CONSTANT integer      := 0;                    -- 正常
	C_NG                    CONSTANT integer      := 1;                    -- 予期したエラー
	C_NO_DATA               CONSTANT integer      := 2;                    -- 対象データ無し
	C_FATAL                 CONSTANT integer      := 99;                   -- 予期せぬエラー
	C_REPORT_ID             CONSTANT text     := 'IP030007811';        -- 帳票ID
	C_JIKO                  CONSTANT text      := '1';                  -- 自行代行区分（自行）
	C_NO_DATA_STRING        CONSTANT text     := '対象データ無し';     -- 自行代行区分（自行）
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gBankDebentureFlg                SOWN_INFO.BANK_DEBENTURE_FLG%TYPE;
	gDaikoFlg                        SOWN_INFO.DAIKO_FLG%TYPE;
	gJikoDaikoKbn                    SOWN_INFO.JIKO_DAIKO_KBN%TYPE;
	gSakuseiYmd                      SREPORT_WK.SAKUSEI_YMD%TYPE;
	gGamenId                         MREPORT.ID%TYPE := NULL;              -- 画面ID
	gGamenNm1                        varchar(40) := NULL;                 -- 画面名称1
	gShoriModeNm1                    SCODE.CODE_NM%TYPE := NULL;           -- 処理モード名称1
	gCount1                          varchar(30) := NULL;                 -- 件数1
	gGamenNm2                        varchar(40) := NULL;                 -- 画面名称2
	gShoriModeNm2                    SCODE.CODE_NM%TYPE := NULL;           -- 処理モード名称2
	gCount2                          varchar(30) := NULL;                 -- 件数2
	gLoopCount                       numeric := 0;                          -- 1レコードに3件挿入するためのcount
	gDaikomokuCd                     char(1) := NULL;                      -- 大項目
	gDaikomokuNM                     SCODE.CODE_NM%TYPE := NULL;           -- 大項目名称
	gSeqNo                           integer := 1;                    -- シーケンス
	gBankRnm                         VJIKO_ITAKU.BANK_RNM%TYPE := NULL;    -- 委託会社名称
	gKaiinId			VJIKO_ITAKU.KAIIN_ID%TYPE := NULL;    -- 会員ＩＤ
	CUR_DATA CURSOR FOR
		SELECT
			VJK1.JIKO_DAIKO_KBN,
			M91.KEY_CD AS KEY_CD,
			SUBSTR(M91.ID,7,1)  AS DAIKOUMOKU_CD,
			MAX(SC04_1.CODE_NM) AS DAIKOUMOKU_NM,
			M91.ID,
			MAX(VSC13.GAMEN_NM) AS GAMEN_NM,
			MAX(SC04_2.CODE_NM) AS SHORI_MODE_NM,
			COUNT(M91.KEY_CD) AS COUNT
		FROM
			MREPORT  M91,
			VSSCREEN VSC13,
			SCODE    SC04_1,
			SCODE    SC04_2,
			VJIKO_ITAKU VJK1
		WHERE M91.ID = VSC13.GAMEN_ID
		AND SC04_1.CODE_SHUBETSU = '184'
		AND SUBSTR(M91.ID,7,1) = SC04_1.CODE_VALUE
		AND SC04_2.CODE_SHUBETSU = '881'
		AND SUBSTR(M91.ID,12,1) = SC04_2.CODE_VALUE
		AND M91.KEY_CD = VJK1.KAIIN_ID
		AND M91.KEY_CD = CASE WHEN l_inItakuKaishaCd=pkconstant.DAIKO_KEY_CD() THEN  M91.KEY_CD  ELSE l_inItakuKaishaCd END
		AND M91.SAKUSEI_YMD = l_inGyomuYmd
		GROUP BY
			VJK1.JIKO_DAIKO_KBN,
			M91.KEY_CD,
			M91.ID
		ORDER BY
			VJK1.JIKO_DAIKO_KBN,
			M91.KEY_CD,
			SUBSTR(M91.ID,7,1),
			M91.ID;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	CALL pkLog.debug(l_inUserId, C_REPORT_ID, 'SPIP07811 START');
	CALL pkLog.debug(l_inUserId, C_REPORT_ID, '委託会社：' || l_inItakuKaishaCd);
	CALL pkLog.debug(l_inUserId, C_REPORT_ID, 'ユーザID：' || l_inUserId);
	CALL pkLog.debug(l_inUserId, C_REPORT_ID, '帳票区分：' || l_inChohyoKbn);
	CALL pkLog.debug(l_inUserId, C_REPORT_ID, '業務日付：' || l_inGyomuYmd);
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' OR coalesce(trim(both l_inUserId)::text, '') = '' OR coalesce(trim(both l_inChohyoKbn)::text, '') = '' OR coalesce(trim(both l_inGyomuYmd)::text, '') = '' THEN
		-- パラメータエラー
		CALL pkLog.error('ECM001', 'SPIP07811', 'パラメータエラー(NULL)');
		l_outSqlCode := C_NG;
		l_outSqlErrM := 'パラメータエラー(NULL)';
		RETURN;
	END IF;
	CALL pkLog.debug(l_inUserId, C_REPORT_ID, '金融債利用フラグ：' || gBankDebentureFlg);
	CALL pkLog.debug(l_inUserId, C_REPORT_ID, '事務代行利用フラグ：' || gDaikoFlg);
	-- 帳票ワークの削除
	DELETE
	FROM
		SREPORT_WK
	WHERE KEY_CD = l_inItakuKaishaCd
	AND USER_ID = l_inUserId
	AND CHOHYO_KBN = l_inChohyoKbn
	AND SAKUSEI_YMD = l_inGyomuYmd
	AND CHOHYO_ID = C_REPORT_ID;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, C_REPORT_ID);
	-- 夜間バッチで作成する場合にはデータ基準日を出力する。
	IF l_inChohyoKbn = pkKakuninList.CHOHYO_KBN_BATCH() THEN
		gSakuseiYmd := l_inGyomuYmd;
	ELSE
		gSakuseiYmd := NULL;
	END IF;
	--=======================================================================================
	--    帳票ワークテーブルへの挿入処理                                                     
	--    画面ID大項目または小項目が同一の場合は最大3件まで同一レコードに挿入する。          
	--    画面ID大項目または小項目が変わった場合は3件に満たなくても次レコードに挿入する。    
	--=======================================================================================
	FOR curDataRecType IN CUR_DATA LOOP
		-- 自行情報の金融債利用フラグが'1'の場合のみ、金融債を表示
		-- 画面IDの頭3桁が「IPN」を金融債画面と見なしている。
		-- 自行情報の代行フラグが'1'の場合のみ、事務代行業務を表示
		IF (SUBSTR(curDataRecType.ID,1,3) <> 'IPN' OR gBankDebentureFlg = '1')
			AND (curDataRecType.DAIKOUMOKU_CD <> '0' OR gDaikoFlg = '1') THEN
			IF coalesce(gGamenId::text, '') = '' THEN
				-- 1セット目の変数に代入
				gGamenId      := curDataRecType.ID;
				gGamenNm1     := SUBSTR(curDataRecType.GAMEN_NM,1,20);
				gShoriModeNm1 := curDataRecType.SHORI_MODE_NM;
				gCount1       := pkcharacter.numeric_to_char(curDataRecType.COUNT);
				gDaikomokuCd  := curDataRecType.DAIKOUMOKU_CD;
				gDaikomokuNM  := curDataRecType.DAIKOUMOKU_NM;
				gLoopCount    := 1;
				gKaiinId      := curDataRecType.KEY_CD;
			ELSE
				-- 前レコードと画面ID大項目・中項目・小項目が同じとき
				IF SUBSTR(curDataRecType.ID,10,2) = SUBSTR(gGamenId,10,2)
					AND SUBSTR(curDataRecType.ID,8,1) = SUBSTR(gGamenId,8,1)
					AND curDataRecType.DAIKOUMOKU_CD = SUBSTR(gGamenId,7,1)
					AND curDataRecType.KEY_CD = gKaiinId THEN
					IF gLoopCount = 1 THEN
						-- 1セット目まで作成済みなので2セット目の変数に代入
						gGamenNm2     := SUBSTR(curDataRecType.GAMEN_NM,1,20);
						gShoriModeNm2 := curDataRecType.SHORI_MODE_NM;
						gCount2       := pkcharacter.numeric_to_char(curDataRecType.COUNT);
						gLoopCount    := 2;
					ELSE
						-- 自行情報の取得
						CALL SPIP07811_getJikouInfo(gKaiinId, gJikoDaikoKbn, gBankRnm);
						-- 2セット目まで作成済みなので、取得値を3セット目として
						-- 帳票ワークに現在の変数をINSERTする
								-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gBankRnm;	-- 委託会社略称
		v_item.l_inItem002 := l_inUserId;	-- ユーザID
		v_item.l_inItem003 := gDaikomokuCd;	-- 大項目ID
		v_item.l_inItem004 := gDaikomokuNM;	-- 大項目名称
		v_item.l_inItem005 := gGamenNm1;	-- 画面名称1
		v_item.l_inItem006 := gShoriModeNm1;	-- 処理モード名称1
		v_item.l_inItem007 := gCount1;	-- 件数1
		v_item.l_inItem008 := gGamenNm2;	-- 画面名称2
		v_item.l_inItem009 := gShoriModeNm2;	-- 処理モード名称2
		v_item.l_inItem010 := gCount2;	-- 件数2
		v_item.l_inItem011 := SUBSTR(curDataRecType.GAMEN_NM,1,20);	-- 画面名称3
		v_item.l_inItem012 := curDataRecType.SHORI_MODE_NM;	-- 処理モード名称3
		v_item.l_inItem013 := pkcharacter.numeric_to_char(curDataRecType.COUNT);	-- 件数3
		v_item.l_inItem014 := C_REPORT_ID;	-- 帳票ID
		v_item.l_inItem015 := gSakuseiYmd;	-- データ基準日
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> C_REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
						gSeqNo := gSeqNo + 1;
						-- 変数をクリア
						gGamenId      := NULL;
						gGamenNm2     := NULL;
						gShoriModeNm2 := NULL;
						gCount2       := NULL;
					END IF;
				-- 前レコードと画面ID小項目が異なるとき
				ELSE
					-- 自行情報の取得
					CALL SPIP07811_getJikouInfo(gKaiinId, gJikoDaikoKbn, gBankRnm);
					-- 帳票ワークに現在の変数をINSERTし(3セット目は無し)
							-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gBankRnm;	-- 委託会社略称
		v_item.l_inItem002 := l_inUserId;	-- ユーザID
		v_item.l_inItem003 := gDaikomokuCd;	-- 大項目ID
		v_item.l_inItem004 := gDaikomokuNM;	-- 大項目名称
		v_item.l_inItem005 := gGamenNm1;	-- 画面名称1
		v_item.l_inItem006 := gShoriModeNm1;	-- 処理モード名称1
		v_item.l_inItem007 := gCount1;	-- 件数1
		v_item.l_inItem008 := gGamenNm2;	-- 画面名称2
		v_item.l_inItem009 := gShoriModeNm2;	-- 処理モード名称2
		v_item.l_inItem010 := gCount2;	-- 件数2
		v_item.l_inItem011 := NULL;	-- 画面名称3
		v_item.l_inItem012 := NULL;	-- 処理モード名称3
		v_item.l_inItem013 := NULL;	-- 件数3
		v_item.l_inItem014 := C_REPORT_ID;	-- 帳票ID
		v_item.l_inItem015 := gSakuseiYmd;	-- データ基準日
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> C_REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
					gSeqNo := gSeqNo + 1;
					-- 変数をクリア
					gGamenNm2     := NULL;
					gShoriModeNm2 := NULL;
					gCount2       := NULL;
					-- 1セット目の変数に取得値を代入
					gGamenId      := curDataRecType.ID;
					gGamenNm1     := SUBSTR(curDataRecType.GAMEN_NM,1,20);
					gShoriModeNm1 := curDataRecType.SHORI_MODE_NM;
					gCount1       := pkcharacter.numeric_to_char(curDataRecType.COUNT);
					gDaikomokuCd  := curDataRecType.DAIKOUMOKU_CD;
					gDaikomokuNM  := curDataRecType.DAIKOUMOKU_NM;
					gLoopCount    := 1;
					gKaiinId      := curDataRecType.KEY_CD;
				END IF;
			END IF;
		END IF;
	END LOOP;
	-- 最後のレコードをinsertする
	IF (gGamenId IS NOT NULL AND gGamenId::text <> '') THEN
		-- 帳票ワークに現在の変数をINSERTし(3セット目は無し)
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gBankRnm;	-- 委託会社略称
		v_item.l_inItem002 := l_inUserId;	-- ユーザID
		v_item.l_inItem003 := gDaikomokuCd;	-- 大項目ID
		v_item.l_inItem004 := gDaikomokuNM;	-- 大項目名称
		v_item.l_inItem005 := gGamenNm1;	-- 画面名称1
		v_item.l_inItem006 := gShoriModeNm1;	-- 処理モード名称1
		v_item.l_inItem007 := gCount1;	-- 件数1
		v_item.l_inItem008 := gGamenNm2;	-- 画面名称2
		v_item.l_inItem009 := gShoriModeNm2;	-- 処理モード名称2
		v_item.l_inItem010 := gCount2;	-- 件数2
		v_item.l_inItem011 := NULL;	-- 画面名称3
		v_item.l_inItem012 := NULL;	-- 処理モード名称3
		v_item.l_inItem013 := NULL;	-- 件数3
		v_item.l_inItem014 := C_REPORT_ID;	-- 帳票ID
		v_item.l_inItem015 := gSakuseiYmd;	-- データ基準日
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> C_REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
		gSeqNo := gSeqNo + 1;
	END IF;
	-- 対象データ無し
	IF gSeqNo = 1 THEN
		-- 自行情報の取得
		CALL SPIP07811_getJikouInfo(l_inItakuKaishaCd, gJikoDaikoKbn, gBankRnm);
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := gBankRnm;	-- 委託会社略称
		v_item.l_inItem002 := l_inUserId;	-- ユーザID
		v_item.l_inItem003 := '2';	-- 大項目ID
		v_item.l_inItem014 := C_REPORT_ID;	-- 帳票ID
		v_item.l_inItem015 := gSakuseiYmd;	-- データ基準日
		v_item.l_inItem016 := C_NO_DATA_STRING;	-- 対象データ無し
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> C_REPORT_ID,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	END IF;
	l_outSqlCode := C_OK;
	l_outSqlErrM := '';
	CALL pkLog.debug(l_inUserId, C_REPORT_ID, 'ROWCOUNT:' || gSeqNo);
	CALL pkLog.debug(l_inUserId, C_REPORT_ID, 'SPIP07811 END');
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'SPIP07811', 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal('ECM701', 'SPIP07811', 'SQLERRM:'||SQLERRM);
		l_outSqlCode := C_FATAL;
		l_outSqlErrM := SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip07811 ( l_inItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE, l_inUserId SREPORT_WK.USER_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_inGyomuYmd SREPORT_WK.SAKUSEI_YMD%TYPE, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spip07811_getjikouinfo ( 
	l_inItakuKaishaCd TEXT,
	OUT p_outJikoDaikoKbn CHAR,
	OUT p_outBankRnm VARCHAR
) AS $body$
DECLARE
	C_JIKO CONSTANT text := '1';  -- 自行代行区分（自行）
BEGIN
	SELECT
		jiko_daiko_kbn,				-- 自行代行区分
		bank_rnm 				-- 委託会社略称
	INTO STRICT
		p_outJikoDaikoKbn,
		p_outBankRnm
	FROM
		VJIKO_ITAKU
	WHERE
		kaiin_id = l_inItakuKaishaCd;
	-- 自行代行区分が'1'のときに委託会社略称は表示しない
	IF p_outJikoDaikoKbn = C_JIKO THEN
		p_outBankRnm := NULL;
	END IF;
EXCEPTION
	WHEN no_data_found THEN
		p_outBankRnm := NULL;
		p_outJikoDaikoKbn := NULL;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip07811_getjikouinfo ( l_inItakuKaishaCd TEXT, OUT p_outJikoDaikoKbn CHAR, OUT p_outBankRnm VARCHAR ) FROM PUBLIC;