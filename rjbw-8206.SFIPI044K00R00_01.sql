




CREATE OR REPLACE FUNCTION sfipi044k00r00_01 ( l_initakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE ) RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 社債原簿を作成する。（バッチ用）
-- * バッチ帳票出力ＯＮ処理
-- * SFIPI044K00R00から呼び出されるプログラム。
-- *
-- * @author 桑原　昭治
-- * @version $Revision: 1.11.2.2 $
-- *
-- * @param l_initakuKaishaCd 委託会社コード
-- * @return INTEGER 0:正常、99:異常、それ以外：エラー
-- 
--==============================================================================
--                  定数定義                                                    
--==============================================================================
	C_GENBO_ID		CONSTANT	varchar(11)	:= 'IP030004412';		-- 社債原簿
	C_SOFU_ID		CONSTANT	varchar(11)	:= 'IP030004411';		-- 原簿送付状
	C_BATCH			CONSTANT	char(1)			:= '1';					-- 帳票区分「バッチ」
	RTN_OK			CONSTANT	integer			:= 0;					-- 正常
	RTN_NODATA		CONSTANT 	integer			:= 2;					-- データなし
	-- IP-05483対応
	C_CTL_SHUBETSU	CONSTANT	MPROCESS_CTL.CTL_SHUBETSU%TYPE := 'SFIPI044K00R011';	-- 途中全額減債銘柄の満期償還日原簿出力
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	gGyomuYmd		SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;					-- 営業日格納用変数
	gYokuGyomuYmd	SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;					-- 翌営業日格納用変数
	gRtnCd			integer		:=	RTN_OK;							-- リターンコード
	gSeqNo			integer 	:= 	0;							-- シーケンス
	gGenboSofuFlg	char(1)		:= NULL;							--原簿送付状出力フラグ
	pOutSqlErrM		text;
	ymFrom			char(8);										
	ymTo			char(8);
--==============================================================================
--                  カーソル定義                                                
--==============================================================================
	--当月が元利払日、または振替債移行日である全ての銘柄を求めるカーソル
	CUR_GAITO_MGR CURSOR FOR
	SELECT
			VMG.ITAKU_KAISHA_CD,VMG.MGR_CD,MG1.SHASAI_GENBO_OUT_KBN
	FROM(
			--償還回次に元利払日が当月である銘柄の件数を調べる
			SELECT MG3.ITAKU_KAISHA_CD,MG3.MGR_CD MGR_CD
			FROM MGR_SHOKIJ MG3, MGR_KIHON MG1
			WHERE MG3.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND MG3.SHOKAN_YMD BETWEEN ymFrom AND ymTo
			AND MG3.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
            AND MG3.MGR_CD          = MG1.MGR_CD
            AND ( (MG1.SHASAI_GENBO_OUT_KBN <> '9')
               OR (MG1.SHASAI_GENBO_OUT_KBN = '9' AND MG3.MUNIT_GENSAI_KNGK>0) -- 9 減債のみは銘柄単位元本減債金額>0を対象とする
            )
			
UNION

			--利払回次に元利払日が当月である銘柄の件数を調べる
			SELECT MG2.ITAKU_KAISHA_CD,MG2.MGR_CD MGR_CD
			FROM MGR_RBRKIJ MG2, MGR_KIHON MG1
			WHERE MG2.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND MG2.RBR_YMD BETWEEN ymFrom AND ymTo
			AND MG2.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD 
			AND MG2.MGR_CD          = MG1.MGR_CD
			AND MG1.SHASAI_GENBO_OUT_KBN <> '9' -- 減債のみは利払回次対象としない
			
UNION

			-- IP-05483
			-- 当初予定の満期償還日が当月である銘柄の件数を調べる
			-- （処理制御マスタで「出力する」設定の場合のみ）
			SELECT MG1S1.ITAKU_KAISHA_CD, MG1S1.MGR_CD
			FROM MGR_KIHON MG1S1
			WHERE MG1S1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND pkDate.calcDateKyujitsuKbn(
						MG1S1.FULLSHOKAN_KJT, 
						0, 
						MG1S1.KYUJITSU_KBN, 
						pkDate.getAreaCd(MG1S1.KYUJITSU_LD_FLG, MG1S1.KYUJITSU_NY_FLG, MG1S1.KYUJITSU_ETC_FLG, 'N', MG1S1.ETCKAIGAI_AREA1, MG1S1.ETCKAIGAI_AREA2, MG1S1.ETCKAIGAI_AREA3)
			) BETWEEN ymFrom AND ymTo
			AND EXISTS (
					SELECT M93.ctid FROM MPROCESS_CTL M93
					WHERE M93.CTL_SHUBETSU = C_CTL_SHUBETSU
					AND M93.CTL_VALUE = '1'
			) 
		) VMG,MGR_KIHON MG1, MGR_STS MG0
	WHERE	VMG.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
	AND		VMG.MGR_CD = MG1.MGR_CD
	AND		MG1.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
	AND		MG1.MGR_CD = MG0.MGR_CD
	AND		MG1.SHASAI_GENBO_OUT_KBN IN ('1','2','9')
	AND		MG0.MGR_STAT_KBN = '1'
	AND		MG0.MASSHO_FLG = '0'
	AND		MG1.PARTMGR_KBN in ('0','2')										--親銘柄を対象外
	AND (MG1.PARTMGR_KBN in ('0','1') or SUBSTR(MG1.YOBI3, 14, 1) = '0')	--子銘柄（残高なし）を対象外
	AND		MG1.ISIN_CD <> ' '
	AND		MG1.KK_KANYO_FLG IN ('0','1')
	AND		MG1.JTK_KBN <> '2'
	AND		MG1.JTK_KBN <> '5';
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	CALL pkLog.debug('BATCH', 'sfIpi044K00R00_01', '--------------------------------------------------Start--------------------------------------------------');
	CALL pkLog.debug('BATCH', 'sfIpi044K00R00_01', '引数（委託会社コードD）：'||l_initakuKaishaCd);
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
	-- 翌営業日付取得				
	gYokuGyomuYmd := pkDate.getYokuBusinessYmd(gGyomuYmd);
	-- 業務日付の年月に固定文字を連結させ、一ヶ月間のデータを抽出するための条件を作成して変数に格納
	ymFrom			:=	SUBSTR(gGyomuYmd, 1 ,6) || '01';
	ymTo			:=	SUBSTR(gGyomuYmd, 1 ,6) || '99';
	-- 原簿ワークの削除
	DELETE			FROM GENBO_WORK
	WHERE			ITAKU_KAISHA_CD = l_inItakuKaishaCd;
	--　当月が元利払日である全ての銘柄の分だけループ
	FOR GAITO_MGR IN CUR_GAITO_MGR LOOP
		--原簿出力区分が最終償還日のみ('2')でも、残高が０になった場合は原簿ワークに書き込みに行く。
		IF GAITO_MGR.SHASAI_GENBO_OUT_KBN = '2'
		AND pkIpaZndk.getKjnZndk(l_inItakuKaishaCd,GAITO_MGR.MGR_CD,gGyomuYmd,3)::numeric != 0 THEN
			-- 何もしない
			gSeqNo := gSeqNo + 0;
		ELSE
			-- 社債原簿作表処理をCALL
			CALL SPIPI044K00R01(	l_inItakuKaishaCd,
							'BATCH',
							C_BATCH,
							gGyomuYmd,
							GAITO_MGR.MGR_CD,
							gRtnCd,
							pOutSqlErrM);
			CALL pkLog.debug('BATCH', 'リターンコード:', gRtnCd);
			IF gRtnCd <> pkconstant.success() THEN
				-- 作表ＳＰのリターンが正常でなく,対象データ無しでもない場合はログを出力する。
				IF gRtnCd <> '2' THEN
					CALL pkLog.error('ECM701', 'SPIPI044K00R00', 'エラーメッセージ：'||'社債原簿出力処理に失敗しました。');
				END IF;
				RETURN gRtnCd;
			END IF;
		END IF;
	END LOOP;
	-- 原簿ワークのデータ数をカウント
	SELECT	COUNT(ITAKU_KAISHA_CD)
	INTO	gSeqNo
	FROM	GENBO_WORK
	WHERE	ITAKU_KAISHA_CD = l_inItakuKaishaCd;
	-- データが存在した場合のみ帳票ワークに書き込む処理を行う
	IF gSeqNo > 0 THEN
		--自行・委託会社マスタVIEWより原簿送付状出力フラグを取得する
		SELECT
			GENBO_SOFU_FLG
		INTO
			gGenboSofuFlg
		FROM
			VJIKO_ITAKU
		WHERE
			KAIIN_ID = l_inItakuKaishaCd
		LIMIT 1;
		--原簿ワークに書き込む処理が終わったら、帳票ワーク作成SP(SPIPI044K00R02)をコールする
		CALL SPIPI044K00R02(	gYokuGyomuYmd,										-- バッチの場合、翌業務日付をもとに和暦変換をさせる。
						l_inItakuKaishaCd,
						'BATCH',
						C_BATCH,
						gGenboSofuFlg,										-- 送付状出力するための判断フラグ
						gGyomuYmd,
						gRtnCd,
						pOutSqlErrM);
		-- 原簿送付状を出力する場合は帳票IDに'IP030004411'を、
		-- 原簿送付状を出力しない場合は帳票IDに'IP030004412'をPRT_OKテーブルに書き込む処理を行う
		IF gGenboSofuFlg ='1' THEN
			-- バッチ帳票出力ＯＮ処理
			IF gRtnCd = pkconstant.success() THEN
				CALL SFIPI044K00R00_01_insertData(
					inItakuKaishaCd				=>		l_inItakuKaishaCd,
					inKijunYmd					=>		gGyomuYmd,
					inListSakuseiKbn			=>		'2',										--月次帳票なので'２'をセットさせる
					inChohyoId					=>		C_SOFU_ID
				);
				CALL pkLog.debug('BATCH', C_SOFU_ID, 'PRT_OKに書き込む処理を行いました');
			END IF;
		ELSE
			-- バッチ帳票出力ＯＮ処理
			IF gRtnCd = pkconstant.success() THEN
				CALL SFIPI044K00R00_01_insertData(
					inItakuKaishaCd				=>		l_inItakuKaishaCd,
					inKijunYmd					=>		gGyomuYmd,
					inListSakuseiKbn			=>		'2',										--月次帳票なので'２'をセットさせる
					inChohyoId					=>		C_GENBO_ID
				);
				CALL pkLog.debug('BATCH', C_GENBO_ID, 'PRT_OKに書き込む処理を行いました');
			END IF;
		END IF;
	ELSE
		-- 対象データがない場合,リターンコードに”対象データなし”のコードを格納する
		gRtnCd := RTN_NODATA;
	END IF;
	CALL pkLog.debug('BATCH', 'SFIPI044K00R00_01', '返値（正常）');
	CALL pkLog.debug('BATCH', 'SFIPI044K00R00_01', '-------------------------End-------------------------');
	RETURN gRtnCd;
--=========< エラー処理 >==========================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'SFIPI044K00R00_01', 'エラーコード'||SQLSTATE);
		CALL pkLog.fatal('ECM701', 'SFIPI044K00R00_01', 'エラー内容'||SQLERRM);
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi044k00r00_01 ( l_initakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfipi044k00r00_01_insertdata ( inItakuKaishaCd PRT_OK.ITAKU_KAISHA_CD%TYPE, inKijunYmd PRT_OK.KIJUN_YMD%TYPE, inListSakuseiKbn PRT_OK.LIST_SAKUSEI_KBN%TYPE, inChohyoId PRT_OK.CHOHYO_ID%TYPE, inGroupId PRT_OK.GROUP_ID%TYPE DEFAULT ' ', inShoriKbn PRT_OK.SHORI_KBN%TYPE DEFAULT ' ', inLastTeiseiDt PRT_OK.LAST_TEISEI_DT%TYPE DEFAULT NULL, inLastTeiseiId PRT_OK.LAST_TEISEI_ID%TYPE DEFAULT ' ', inShoninDt PRT_OK.SHONIN_DT%TYPE DEFAULT NULL, inShoninId PRT_OK.SHONIN_ID%TYPE DEFAULT ' ', inKousinId PRT_OK.KOUSIN_ID%TYPE DEFAULT ' ', inSakuseiId PRT_OK.SAKUSEI_ID%TYPE DEFAULT ' ') AS $body$
BEGIN
	INSERT INTO PRT_OK(
		ITAKU_KAISHA_CD, KIJUN_YMD,      LIST_SAKUSEI_KBN,   CHOHYO_ID, GROUP_ID,
		SHORI_KBN,       LAST_TEISEI_DT, LAST_TEISEI_ID,     SHONIN_DT, SHONIN_ID,
		KOUSIN_ID,       SAKUSEI_ID
	)
	VALUES (
		inItakuKaishaCd,  inKijunYmd,     inListSakuseiKbn, inChohyoId, inGroupId,
		inShoriKbn,       inLastTeiseiDt, inLastTeiseiId,   inShoninDt, inShoninId,
		inKousinId,       inSakuseiId
	);
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfipi044k00r00_01_insertdata ( inItakuKaishaCd PRT_OK.ITAKU_KAISHA_CD%TYPE, inKijunYmd PRT_OK.KIJUN_YMD%TYPE, inListSakuseiKbn PRT_OK.LIST_SAKUSEI_KBN%TYPE, inChohyoId PRT_OK.CHOHYO_ID%TYPE, inGroupId PRT_OK.GROUP_ID%TYPE DEFAULT ' ', inShoriKbn PRT_OK.SHORI_KBN%TYPE DEFAULT ' ', inLastTeiseiDt PRT_OK.LAST_TEISEI_DT%TYPE DEFAULT NULL, inLastTeiseiId PRT_OK.LAST_TEISEI_ID%TYPE DEFAULT ' ', inShoninDt PRT_OK.SHONIN_DT%TYPE DEFAULT NULL, inShoninId PRT_OK.SHONIN_ID%TYPE DEFAULT ' ', inKousinId PRT_OK.KOUSIN_ID%TYPE DEFAULT ' ', inSakuseiId PRT_OK.SAKUSEI_ID%TYPE DEFAULT ' ') FROM PUBLIC;