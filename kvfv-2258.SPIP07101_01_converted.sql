-- Converted SPIP07101_01 for PostgreSQL
-- This procedure creates redemption schedule bond list report

CREATE OR REPLACE PROCEDURE spIp07101_01
(
	l_inGnrBaraiKjtF		IN	TEXT,
	l_inGnrBaraiKjtT		IN	TEXT,
	l_inHktCd				IN	TEXT,
	l_inKozaTenCd			IN	TEXT,
	l_inKozaTenCifCd		IN	TEXT,
	l_inMgrCd				IN	TEXT,
	l_inIsinCd				IN	TEXT,
	l_inJtkKbn				IN	TEXT,
	l_inSaikenShurui		IN	TEXT,
	l_inKkKanyoFlg			IN	TEXT,
	l_inShokanMethodCd		IN	TEXT,
	l_inTeijiShokanTsutiKbn	IN	TEXT,
	l_inJiyuu				IN	TEXT,
	l_inItakuKaishaCd		IN	TEXT,
	l_inUserId				IN	TEXT,
	l_inChohyoKbn			IN	TEXT,
	l_inGyomuYmd			IN	TEXT,
	l_outSqlCode			OUT	integer,
	l_outSqlErrM			OUT	TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
	DEBUG	numeric(1)	DEFAULT 0;
	RTN_OK				CONSTANT INTEGER		:= 0;
	RTN_NG				CONSTANT INTEGER		:= 1;
	RTN_NODATA			CONSTANT INTEGER		:= 2;
	RTN_FATAL			CONSTANT INTEGER		:= 99;
	REPORT_ID			CONSTANT CHAR(11)		:= 'IP030007111';

	FMT_HAKKO_KNGK_J	CONSTANT CHAR(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';
	FMT_RBR_KNGK_J		CONSTANT CHAR(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';
	FMT_SHOKAN_KNGK_J	CONSTANT CHAR(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';
	
	TEIJI				CONSTANT VARCHAR(1) := '2';
	SHONIN				CONSTANT VARCHAR(1) := '1';

	gRtnCd				INTEGER DEFAULT	RTN_OK;
	gSeqNo				INTEGER DEFAULT 0;
	gRet				NUMERIC  DEFAULT 0;
	gSQL				TEXT DEFAULT NULL;

	recMeisai 			spip07101_01_type_record;
	v_item					type_sreport_wk_item;

	gJtkKbnNm					TEXT;
	gTeijiShokanTsutiKbnNm		TEXT DEFAULT NULL;
	gCallUmuFlgNm				TEXT DEFAULT NULL;
	gItakuKaishaRnm				TEXT;
   	gNyuryokuYmd				TEXT;
   	gMasshoYmd					TEXT;
	gLastShokanFlg				INTEGER DEFAULT 0;

	curMeisai REFCURSOR;

BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp07101_01 START');	END IF;

	-- Parameter check
	IF l_inItakuKaishaCd Is Null
	OR l_inUserId Is Null
	OR l_inChohyoKbn Is Null
	OR l_inGyomuYmd Is Null
	THEN
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', REPORT_ID, 'SQLERRM:'||'');
		RETURN;
	END IF;

	-- Delete work table
	DELETE FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;

    -- getJtkKbnNm logic inline
	gJtkKbnNm := NULL;
	IF l_inJtkKbn IS NOT NULL THEN
        BEGIN
            SELECT 	MCD1.CODE_NM
            INTO	gJtkKbnNm
            FROM	SCODE MCD1
            WHERE	MCD1.CODE_VALUE = l_inJtkKbn
            AND		MCD1.CODE_SHUBETSU = '112';
        EXCEPTION WHEN NO_DATA_FOUND THEN
             IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, '受託区分名:no data found');	END IF;
        END;
	END IF;

	gSQL := 'SELECT	VMG1.JTK_KBN,'
         || '		MCD4.CODE_RNM AS JTK_KBN_NM,'
         || '		VMG1.ISIN_CD,'
         || '		VMG1.MGR_CD,'
         || '		VMG1.MGR_RNM,'
         || '		VMG1.HKT_CD,'
         || '		MCD1.CODE_RNM AS SAIKEN_SHURUI_NM,'
         || '		MCD2.CODE_RNM AS KK_KANYO_FLG_NM,'
         || '		VMG1.SHOKAN_METHOD_NM,'
         || '		VMG1.TEIJI_SHOKAN_TSUTI_KBN,'
         || '		MG3.FACTOR,'
         || '		VMG1.CALLALL_UMU_FLG,'
         || '		VMG1.CALLITIBU_UMU_FLG,'
         || '		VMG1.PUTUMU_FLG,'
         || '		VMG1.PUTUMU_FLG_NM,'
         || '		MG3.SHOKAN_YMD,'
         || '		MG3.SHOKAN_KJT,'
         || '		MCD3.CODE_NM AS JIYUU_NM,'
         || '		M64.TSUKA_NM AS HAKKO_TSUKA_NM,'
         || '		VMG1.HAKKO_TSUKA_CD,'
         || '		MG3.MUNIT_GENSAI_KNGK,'
         || '		PkIpaZndk.getKjnZndk(VMG1.ITAKU_KAISHA_CD,VMG1.MGR_CD,MG3.SHOKAN_YMD,MG3.SHOKAN_KBN,''13''),'
         || '		MG3.KAIJI,'
         || '		VJ1.BANK_RNM,'
         || '		VJ1.JIKO_DAIKO_KBN, '
         || '		MG3.SHOKAN_KBN, '
         || '		MG3.ITAKU_KAISHA_CD, '
         || '		VMG1.SHOKAN_METHOD_CD, '
         || '		SC04.CODE_SORT AS SHOKAN_KBN_SORT '
         || 'FROM 	MGR_SHOKIJ MG3 '
         || 'JOIN VMGR_LIST VMG1 ON VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD AND VMG1.MGR_CD = MG3.MGR_CD '
         || 'JOIN MGR_KIHON_VIEW VMG0 ON VMG1.ITAKU_KAISHA_CD = VMG0.ITAKU_KAISHA_CD AND VMG1.MGR_CD = VMG0.MGR_CD '
         || 'JOIN MTSUKA M64 ON VMG1.HAKKO_TSUKA_CD = M64.TSUKA_CD '
         || 'JOIN VJIKO_ITAKU VJ1 ON VJ1.KAIIN_ID = ''' || l_inItakuKaishaCd || ''' '
         || 'LEFT JOIN SCODE MCD1 ON MCD1.CODE_SHUBETSU = ''514'' AND VMG1.SAIKEN_SHURUI = TRIM(MCD1.CODE_VALUE) '
         || 'LEFT JOIN SCODE MCD2 ON MCD2.CODE_SHUBETSU = ''505'' AND MG3.KK_KANYO_FLG = MCD2.CODE_VALUE '
         || 'LEFT JOIN SCODE MCD3 ON MCD3.CODE_SHUBETSU = ''109'' AND MG3.SHOKAN_KBN = TRIM(MCD3.CODE_VALUE) '
         || 'LEFT JOIN SCODE MCD4 ON MCD4.CODE_SHUBETSU = ''112'' AND VMG1.JTK_KBN = MCD4.CODE_VALUE '
         || 'LEFT JOIN SCODE SC04 ON SC04.CODE_SHUBETSU = ''714'' AND MG3.SHOKAN_KBN = TRIM(SC04.CODE_VALUE) '
         || 'WHERE 	MG3.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' '
         || 'AND 	MG3.SHOKAN_KJT >= ''' || l_inGnrBaraiKjtF || ''' '
         || 'AND 	MG3.SHOKAN_KJT <= ''' || l_inGnrBaraiKjtT || ''' '
         || 'AND 	VMG1.MGR_STAT_KBN = ''1'' '
         || 'AND 	TRIM(VMG1.ISIN_CD) IS NOT NULL ';

	IF l_inHktCd IS NOT NULL THEN
		gSQL := gSQL || 'AND 	VMG1.HKT_CD = ''' || l_inHktCd || ''' ';
	END IF;
	IF l_inKozaTenCd IS NOT NULL THEN
		gSQL := gSQL || 'AND 	VMG1.KOZA_TEN_CD = ''' || l_inKozaTenCd || ''' ';
	END IF;
	IF l_inKozaTenCifCd IS NOT NULL THEN
		gSQL := gSQL || 'AND 	VMG1.KOZA_TEN_CIFCD = ''' || l_inKozaTenCifCd || ''' ';
	END IF;
	IF l_inMgrCd IS NOT NULL THEN
		gSQL := gSQL || 'AND 	VMG1.MGR_CD = ''' || l_inMgrCd || ''' ';
	END IF;
	IF l_inIsinCd IS NOT NULL THEN
		gSQL := gSQL || 'AND 	VMG1.ISIN_CD = ''' || l_inIsinCd || ''' ';
	END IF;
	IF l_inJtkKbn IS NOT NULL THEN
		gSQL := gSQL || 'AND 	VMG1.JTK_KBN = ''' || l_inJtkKbn || ''' ';
	END IF;
	IF l_inSaikenShurui IS NOT NULL THEN
		gSQL := gSQL || 'AND 	VMG1.SAIKEN_SHURUI = ''' || l_inSaikenShurui || ''' ';
	END IF;
	IF l_inKkKanyoFlg IS NOT NULL THEN
		gSQL := gSQL || 'AND 	VMG1.KK_KANYO_FLG = ''' || l_inKkKanyoFlg || ''' ';
	END IF;
	IF l_inShokanMethodCd IS NOT NULL THEN
		gSQL := gSQL || 'AND 	VMG1.SHOKAN_METHOD_CD = ''' || l_inShokanMethodCd || ''' ';
	END IF;
	IF l_inTeijiShokanTsutiKbn IS NOT NULL THEN
		gSQL := gSQL || 'AND 	VMG1.TEIJI_SHOKAN_TSUTI_KBN = ''' || l_inTeijiShokanTsutiKbn || ''' ';
	END IF;
	IF l_inJiyuu IS NOT NULL THEN
		gSQL := gSQL || 'AND 	MG3.SHOKAN_KBN = ''' || l_inJiyuu || ''' ';
	END IF;
	gSQL := gSQL || 'ORDER BY 	VMG1.JTK_KBN,'
				 || '			VMG1.HKT_CD,'
				 || '			VMG1.ISIN_CD,'
				 || '			VMG1.MGR_CD,'
				 || '			MG3.SHOKAN_YMD, '
				 || '			SC04.CODE_SORT ';

	-- Header
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);

	-- Cursor Open
	OPEN curMeisai FOR EXECUTE gSQL;

	-- Data Loop
	LOOP
		FETCH curMeisai INTO	recMeisai.gJtkKbn
								,recMeisai.gJtkKbnNm
								,recMeisai.gIsinCd
								,recMeisai.gMgrCd
								,recMeisai.gMgrRnm
								,recMeisai.gHktCd
								,recMeisai.gSaikenShuruiNm
								,recMeisai.gKkKanyoFlgNm
								,recMeisai.gShokanMethodNm
								,recMeisai.gTeijiShokanTsutiKbn
								,recMeisai.gFactor2
								,recMeisai.gCallallUmuFlg
								,recMeisai.gCallitibuUmuFlg
								,recMeisai.gPutumuFlg
								,recMeisai.gPutumuFlgNm
								,recMeisai.gShokanYmd
								,recMeisai.gShokanKjt
								,recMeisai.gJiyuuNm
								,recMeisai.gHakkoTsukaNm
								,recMeisai.gHakkoTsukaCd
								,recMeisai.gGensaiKngk
								,recMeisai.gGensaiSum
								,recMeisai.gKaiji
								,recMeisai.gBankRnm
								,recMeisai.gJikoDaikoKbn
								,recMeisai.gShokanKbn
								,recMeisai.gItakuKaishaCd
								,recMeisai.gShokanMethodCd
								,recMeisai.gShokanKbnSort
								;

		EXIT WHEN NOT FOUND;

		gSeqNo := gSeqNo + 1;

		-- Factor logic (getFactor inline)
		IF recMeisai.gShokanMethodCd = TEIJI THEN
            BEGIN
				recMeisai.gFactor1 := pkIpaZndk.getKjnZndk(l_inItakuKaishaCd, recMeisai.gMgrCd, recMeisai.gShokanYmd, recMeisai.gShokanKbn, '5')::numeric;
            EXCEPTION WHEN NO_DATA_FOUND THEN
				recMeisai.gFactor1 := 1.0000000000;
            END;
		ELSE
			recMeisai.gFactor1 := NULL;
			recMeisai.gFactor2 := NULL;
		END IF;

		-- TeijiShokanTsutiKbnNm
		CASE recMeisai.gTeijiShokanTsutiKbn
			WHEN 'V' THEN	gTeijiShokanTsutiKbnNm := 'する';
			ELSE			gTeijiShokanTsutiKbnNm := '−';
		END CASE;

		-- CallUmuFlgNm
		CASE 'Y'
			WHEN recMeisai.gCallallUmuFlg THEN
				IF recMeisai.gCallitibuUmuFlg = 'Y' THEN
					gCallUmuFlgNm := '全額・一部';
				ELSE
					gCallUmuFlgNm := '全額';
				END IF;
			WHEN recMeisai.gCallitibuUmuFlg THEN	gCallUmuFlgNm := '一部';
			ELSE									gCallUmuFlgNm := 'なし';
		END CASE;

		-- NyuryokuYmd
		gNyuryokuYmd := spip07101_01_getNyuryokuYmd(recMeisai.gItakuKaishaCd,recMeisai.gMgrCd,recMeisai.gShokanKjt,recMeisai.gShokanKbn);
		IF recMeisai.gShokanKbn = '20' THEN
			gNyuryokuYmd := '−'; 
		END IF;
		IF recMeisai.gShokanKbn = '21' AND recMeisai.gKaiji = '1' AND recMeisai.gGensaiKngk != 0 THEN
			IF TRIM(gNyuryokuYmd) IS NULL THEN
				gNyuryokuYmd := '−';
			END IF;
		END IF;
		IF recMeisai.gShokanKbn = '60' THEN
			gNyuryokuYmd := '−'; 
		END IF;
		IF spip07101_01_checkLastMgrShokij(l_inItakuKaishaCd, recMeisai.gMgrCd, recMeisai.gShokanYmd, recMeisai.gShokanKbnSort) = 0 THEN
			IF TRIM(gNyuryokuYmd) IS NULL THEN
				gNyuryokuYmd := '−';
			END IF;
		END IF;
		
		-- MasshoYmd
		IF recMeisai.gShokanKbn = '50' OR recMeisai.gShokanKbn = '30' THEN
				gMasshoYmd := ' ';
		ELSE
				gMasshoYmd := '−';
		END IF;
		
		IF recMeisai.gShokanKbn = '50' OR recMeisai.gShokanKbn = '30' THEN
			 gMasshoYmd := spip07101_01_getMasshoYmd(recMeisai.gItakuKaishaCd,recMeisai.gMgrCd,recMeisai.gShokanYmd,recMeisai.gShokanKbn);
		ELSIF recMeisai.gShokanKbn = '60' THEN
				gMasshoYmd := '−';
		ELSE
			IF spip07101_01_checkLastMgrShokij(l_inItakuKaishaCd, recMeisai.gMgrCd, recMeisai.gShokanYmd, recMeisai.gShokanKbnSort) = 0 THEN
				gMasshoYmd := spip07101_01_getMasshoYmd(recMeisai.gItakuKaishaCd,recMeisai.gMgrCd,recMeisai.gShokanYmd,recMeisai.gShokanKbn); 
			END IF;	 
		END IF;

		-- ItakuKaishaRnm
		gItakuKaishaRnm := NULL;
		IF recMeisai.gJikoDaikoKbn = '2' THEN
			gItakuKaishaRnm := recMeisai.gBankRnm;
		END IF;

		-- Insert Data with composite type
		v_item := ROW();
		v_item.l_inItem001 := l_inUserId;
		v_item.l_inItem002 := l_inGnrBaraiKjtF;
		v_item.l_inItem003 := l_inGnrBaraiKjtT;
		v_item.l_inItem004 := recMeisai.gJtkKbnNm;
		v_item.l_inItem005 := gSeqNo::text;
		v_item.l_inItem006 := recMeisai.gIsinCd;
		v_item.l_inItem007 := recMeisai.gMgrCd;
		v_item.l_inItem008 := recMeisai.gMgrRnm;
		v_item.l_inItem009 := recMeisai.gHktCd;
		v_item.l_inItem010 := recMeisai.gSaikenShuruiNm;
		v_item.l_inItem011 := recMeisai.gKkKanyoFlgNm;
		v_item.l_inItem012 := recMeisai.gShokanMethodNm;
		v_item.l_inItem013 := gTeijiShokanTsutiKbnNm;
		v_item.l_inItem014 := TO_CHAR(recMeisai.gFactor1, '0.0000000000');
		v_item.l_inItem015 := TO_CHAR(recMeisai.gFactor2, '0.0000000000');
		v_item.l_inItem016 := gCallUmuFlgNm;
		v_item.l_inItem017 := recMeisai.gPutumuFlgNm;
		v_item.l_inItem018 := recMeisai.gShokanYmd;
		v_item.l_inItem019 := recMeisai.gJiyuuNm;
		v_item.l_inItem020 := recMeisai.gGensaiKngk::text;
		v_item.l_inItem021 := recMeisai.gHakkoTsukaNm;
		v_item.l_inItem022 := recMeisai.gGensaiSum::text;
		v_item.l_inItem023 := recMeisai.gHakkoTsukaNm;
		v_item.l_inItem024 := gItakuKaishaRnm;
		v_item.l_inItem025 := REPORT_ID;
		v_item.l_inItem026 := FMT_HAKKO_KNGK_J;
		v_item.l_inItem027 := FMT_RBR_KNGK_J;
		v_item.l_inItem028 := FMT_SHOKAN_KNGK_J;
		v_item.l_inItem030 := recMeisai.gJtkKbn;
		v_item.l_inItem031 := gMasshoYmd;
		v_item.l_inItem032 := gNyuryokuYmd;
		v_item.l_inItem033 := recMeisai.gShokanKbnSort;
		v_item.l_inItem034 := recMeisai.gShokanKjt;
		
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

	CLOSE curMeisai;

	IF gSeqNo = 0 THEN
		-- No Data
		gRtnCd := RTN_NODATA;

		gRet := PKIPACALCTESURYO.setNoDataPrint(
			l_inItakuKaishaCd,
			l_inUserId,
			l_inGyomuYmd,
			REPORT_ID,
			l_inChohyoKbn,
			29,
			l_inGnrBaraiKjtF,
			2,
			l_inGnrBaraiKjtT,
			3,
			REPORT_ID,
			25,
			l_inUserId,
			1,
			'',
			0
		);

		IF gRet <> 0 THEN 
			IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, REPORT_ID, '対象データ無し用のデータの出力が失敗。' ); END IF;
			CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLCODE:'||SQLSTATE);
			CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLERRM:'||SQLERRM);
			l_outSqlCode := RTN_FATAL;
			l_outSqlErrM := SQLERRM;
			RETURN;
		END IF;
	END IF;

	-- End
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';

	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp07101_01 END');	END IF;

EXCEPTION
	WHEN OTHERS THEN
		BEGIN
			CLOSE curMeisai;
		EXCEPTION WHEN OTHERS THEN
			NULL;
		END;
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
END;
$$;
