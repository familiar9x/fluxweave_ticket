


-- Oracle package 'pkipi000k14r01' declaration, please edit to match PostgreSQL syntax.

-- DROP SCHEMA IF EXISTS pkipi000k14r01 CASCADE;
CREATE SCHEMA IF NOT EXISTS pkipi000k14r01;


--*
-- * @author
-- * @version $Id: PKIPI000K14R01.sql,v 1.4 2013/10/02 00:04:16 handa Exp $
-- 
	--*
--	 * 差額勘定科目取得
--	 * 取引区分・詳細区分より差額系の会計登録データに用いる
--	 * 勘定科目コードを求める共通関数。
--	 *
--	 * @param l_inTorihikiSKbnCd 取引区分（コード）
--	 * @param l_inTorihikiSKbnCd 取引詳細区分（コード）
--	 * @return CHAR 勘定科目コード
--	 
CREATE OR REPLACE FUNCTION pkipi000k14r01.getsagakukanjokamokucd (l_inTorihikiKbnCd CHAR, l_inTorihikiSKbnCd CHAR) RETURNS char AS $body$
BEGIN
		-- ①取引区分：32、取引詳細区分：55の場合
		IF (l_inTorihikiKbnCd = '32' and l_inTorihikiSKbnCd = '55') THEN
			RETURN '25';									-- 25：当社受入（差額分（元手））
		-- ②取引区分：32、取引詳細区分：56の場合
		ELSIF (l_inTorihikiKbnCd = '32' and l_inTorihikiSKbnCd = '56') THEN
			RETURN '26';									-- 26：当社受入（差額分（利手））
		-- ③取引区分：25、取引詳細区分：2Aの場合
		ELSIF (l_inTorihikiKbnCd = '25' and l_inTorihikiSKbnCd = '2A') THEN
			RETURN '31';									-- 31：雑益（差額分（元金））
		-- ④取引区分：25、取引詳細区分：2Bの場合
		ELSIF (l_inTorihikiKbnCd = '25' and l_inTorihikiSKbnCd = '2B') THEN
			RETURN '32';									-- 32：雑益（差額分（利金））
		-- ⑤取引区分：32、取引詳細区分：57の場合
		ELSIF (l_inTorihikiKbnCd = '32' and l_inTorihikiSKbnCd = '57') THEN
			RETURN '33';									-- 33：雑益（差額分（元手））
		-- ⑥取引区分：32、取引詳細区分：58の場合
		ELSIF (l_inTorihikiKbnCd = '32' and l_inTorihikiSKbnCd = '58') THEN
			RETURN '34';									-- 34：雑益（差額分（利手））
		-- ⑦取引区分：25、取引詳細区分：2Cの場合
		ELSIF (l_inTorihikiKbnCd = '25' and l_inTorihikiSKbnCd = '2C') THEN
			RETURN '35';									-- 35：雑益（時効分（元金））
		-- ⑧取引区分：25、取引詳細区分：2Dの場合
		ELSIF (l_inTorihikiKbnCd = '25' and l_inTorihikiSKbnCd = '2D') THEN
			RETURN '36';									-- 36：雑益（時効分（利金））
		-- ⑨取引区分：35、取引詳細区分：2Gの場合
		ELSIF (l_inTorihikiKbnCd = '35' and l_inTorihikiSKbnCd = '2G') THEN
			RETURN '37';									-- 37：雑益（時効分（元手））
		-- ⑩取引区分：35、取引詳細区分：2Hの場合
		ELSIF (l_inTorihikiKbnCd = '35' and l_inTorihikiSKbnCd = '2H') THEN
			RETURN '38';									-- 38：雑益（時効分（利手））
		-- ⑪取引区分：31、取引詳細区分：2Eの場合
		ELSIF (l_inTorihikiKbnCd = '31' and l_inTorihikiSKbnCd = '2E') THEN
			RETURN '61';									-- 61：雑損（差額分（元手））
		-- ⑫取引区分：31、取引詳細区分：2Fの場合
		ELSIF (l_inTorihikiKbnCd = '31' and l_inTorihikiSKbnCd = '2F') THEN
			RETURN '62';									-- 62：雑損（差額分（利手））
		-- ⑬取引区分：26、取引詳細区分：2Cの場合
		ELSIF (l_inTorihikiKbnCd = '26' and l_inTorihikiSKbnCd = '2C') THEN
			RETURN '63';									-- 63：雑損（時効分（元金））
		-- ⑭取引区分：26、取引詳細区分：2Dの場合
		ELSIF (l_inTorihikiKbnCd = '26' and l_inTorihikiSKbnCd = '2D') THEN
			RETURN '64';									-- 64：雑損（時効分（利金））
		-- ⑮取引区分：36、取引詳細区分：2Gの場合
		ELSIF (l_inTorihikiKbnCd = '36' and l_inTorihikiSKbnCd = '2G') THEN
			RETURN '65';									-- 65：雑損（時効分（元手））
		-- ⑯取引区分：36、取引詳細区分：2Hの場合
		ELSIF (l_inTorihikiKbnCd = '36' and l_inTorihikiSKbnCd = '2H') THEN
			RETURN '66';									-- 66：雑損（時効分（利手））
		-- ○それ以外（存在しない想定）
		ELSE
			RETURN '  ';
		END IF;

	END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipi000k14r01.getsagakukanjokamokucd (l_inTorihikiKbnCd CHAR, l_inTorihikiSKbnCd CHAR) FROM PUBLIC;
	
	--*
--	 * 取引詳細区分略称取得
--	 * 取引詳細区分略称を取得する共通関数。
--	 *
--	 * @param l_inTorihikiSKbnCd 取引詳細区分（コード）
--	 * @return VARCHAR2 取引詳細区分略称
--	 
CREATE OR REPLACE FUNCTION pkipi000k14r01.gettorihikiskbnrnm (l_inTorihikiSKbnCd CHAR) RETURNS varchar AS $body$
DECLARE

		vTorihikiSKbnRnm		SCODE.CODE_RNM%TYPE := NULL;
		cCodeShubetsu			CONSTANT text := 'U02';			-- 取引詳細区分（コード種別：U02）
	
BEGIN
		-- コード略称の取得
		SELECT
			CODE_RNM
		INTO STRICT
			vTorihikiSKbnRnm
		FROM
			SCODE
		WHERE
			CODE_SHUBETSU = cCodeShubetsu and
			CODE_VALUE = l_inTorihikiSKbnCd;
		
		RETURN vTorihikiSKbnRnm;
	-- エラー処理
	EXCEPTION
		WHEN OTHERS THEN
			RETURN NULL;
	END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipi000k14r01.gettorihikiskbnrnm (l_inTorihikiSKbnCd CHAR) FROM PUBLIC;

	--*
--	 * 手数料名称取得
--	 * 手数料名称を取得する共通関数。（ＭＵＴＢ用テーブルから取得）
--	 *
--	 * @param l_inItakuKaishaCd 委託会社コード
--	 * @param l_inTesShuruiCd 手数料種類コード
--	 * @return VARCHAR2 行内手数料名称
--	 
CREATE OR REPLACE FUNCTION pkipi000k14r01.getmttesunm (l_inItakuKaishaCd CHAR, l_inTesShuruiCd CHAR) RETURNS varchar AS $body$
DECLARE

		vKonaiTesuShuruiNm		MT_TESURYO_KANRI.KONAI_TESU_SHURUI_NM%TYPE;
	
BEGIN
		-- 行内手数料名称の取得
		SELECT
			KONAI_TESU_SHURUI_NM
		INTO STRICT
			vKonaiTesuShuruiNm
		FROM
			MT_TESURYO_KANRI
		WHERE
			ITAKU_KAISHA_CD = l_inItakuKaishaCd and
			TESU_SHURUI_CD = l_inTesShuruiCd;
		
		RETURN vKonaiTesuShuruiNm;
	-- エラー処理
	EXCEPTION
		WHEN OTHERS THEN
			RETURN NULL;
	END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipi000k14r01.getmttesunm (l_inItakuKaishaCd CHAR, l_inTesShuruiCd CHAR) FROM PUBLIC;

	--*
--	 * 会計登録備考欄用 文字列加工
--	 * 当社受入元利払手数料分の会計登録データ用に
--	 * 備考欄にセットする文字列を作成する共通関数。
--	 *
--	 * @param l_inTorihikiSKbnCd 取引詳細区分（コード）
--	 * @param l_inKessaiNo 決済番号
--	 * @return VARCHAR2 セットする文字列
--	 
CREATE OR REPLACE FUNCTION pkipi000k14r01.modgrtesktbikou (l_inTorihikiSKbnCd CHAR, l_inKessaiNo CHAR) RETURNS varchar AS $body$
DECLARE

		rtnString				KT_NYUSHUKIN.KT_BIKOU%TYPE := NULL;
	
BEGIN
		--=========================================================*
--		 * 文字列整形の方針
--		 * ・会計登録入出金．会計登録備考はVARCHAR2(60)の項目で、
--		 *   帳票では上下２段で出力する。
--		 *
--		 * ・当社受入元利払手数料の際は、帳票に以下の通り出力する
--		 *   上段：取引詳細区分の略称
--		 *   下段：決済番号△9999999999999999 （△：スペース、数字：決済番号）
--		 *
--		 * ⇒取引詳細区分名称を取得し、半角30桁を満たすまで全角スペース埋めを行い、
--		 *   その後に、下段の文字列を結合する
--		 *=========================================================
		
		-- 上段分の文字列を取得する
		rtnString := RPAD(pkipi000k14r01.gettorihikiskbnrnm(l_inTorihikiSKbnCd), 30, '　');
		
		-- 下段分の文字列を取得する
		rtnString := rtnString || '決済番号　' || l_inKessaiNo;
		
		-- 文字列を戻す
		RETURN rtnString;
	
	END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipi000k14r01.modgrtesktbikou (l_inTorihikiSKbnCd CHAR, l_inKessaiNo CHAR) FROM PUBLIC;

	--*
--	 * 決済番号取得
--	 * 決済番号を取得する共通関数。
--	 *
--	 * @param l_inItakuKaishaCd 委託会社コード
--	 * @param l_inSaibanShubetsu 採番種別
--	 * @return CHAR 決済番号（形式：XYYYYMMDD9999999）
--	 
CREATE OR REPLACE FUNCTION pkipi000k14r01.getkessaino (l_inItakuKaishaCd CHAR, l_inSaibanShubetsu CHAR) RETURNS char AS $body$
DECLARE

		-- ０．変数定義
		vSaibanValue		numeric := 0;
		vGyomuYmd			char(8) := NULL;
	
BEGIN
	-- １．番号取得
		-- １．１．採番管理SELECTを行う
		SELECT
			NO_MAX + 1
		INTO STRICT
			vSaibanValue
		FROM
			KESSAI_NO_SAIBAN
		WHERE
			ITAKU_KAISHA_CD = l_inItakuKaishaCd and
			SAIBAN_SHUBETSU = l_inSaibanShubetsu
		FOR UPDATE;
		
		-- １．２．決済番号UPDATEを行う
		UPDATE
			KESSAI_NO_SAIBAN
		SET
			NO_MAX = vSaibanValue
		WHERE
			ITAKU_KAISHA_CD = l_inItakuKaishaCd and
			SAIBAN_SHUBETSU = l_inSaibanShubetsu;
		
	-- ２．戻り値設定
		-- ２．１．業務日付を取得する
		vGyomuYmd := pkDate.getGyomuYmd();
		
		-- ２．２．戻り値を返す
		RETURN l_inSaibanShubetsu || vGyomuYmd || TO_CHAR(vSaibanValue,'FM0000000');
		
	-- エラー処理
	EXCEPTION
		WHEN OTHERS THEN
			ROLLBACK;
			CALL pkLog.fatal('ECM701', 'getKessaiNo', 'SQLCODE:' || SQLSTATE);
			CALL pkLog.fatal('ECM701', 'getKessaiNo', 'SQLERRM:' || SQLERRM);
			RETURN NULL;
	END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipi000k14r01.getkessaino (l_inItakuKaishaCd CHAR, l_inSaibanShubetsu CHAR) FROM PUBLIC;
			
	--*
--	 * 決済番号枝番取得
--	 * 別段入出金テーブルから重複する決済番号を検索し
--	 * 決済番号枝番の最大値+1を返す共通関数。
--	 *
--	 * @param l_inItakuKaishaCd 委託会社コード
--	 * @param l_inKessaiNo 決済番号
--	 * @return CHAR 決済番号枝番
--	 
CREATE OR REPLACE FUNCTION pkipi000k14r01.getkessainoeda (l_inItakuKaishaCd CHAR, l_inKessaiNo CHAR) RETURNS char AS $body$
DECLARE

		cKessaiNoEda		BD_NYUSHUKIN.KESSAI_NO_EDA%TYPE;
	
BEGIN
		-- 別段入出金テーブルから決済番号をキーにデータを取得し、枝番の最大値を取得する
		BEGIN
			SELECT
				coalesce(MAX(KESSAI_NO_EDA),0)
			INTO STRICT
				cKessaiNoEda
			FROM
				BD_NYUSHUKIN
			WHERE
				ITAKU_KAISHA_CD = l_inItakuKaishaCd and
				KESSAI_NO = l_inKessaiNo;
		EXCEPTION
			-- データが取得できないときは001を返す
			WHEN no_data_found THEN
				RETURN '001';
		END;
		
		-- 取得した値+1を求めて戻り値とする（999形式）
		cKessaiNoEda := TO_CHAR((cKessaiNoEda)::numeric +1,'FM000');
		
		RETURN cKessaiNoEda;
		
	-- エラー処理
	EXCEPTION
		WHEN OTHERS THEN
			RETURN NULL;
	END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipi000k14r01.getkessainoeda (l_inItakuKaishaCd CHAR, l_inKessaiNo CHAR) FROM PUBLIC;

	--*
--	 * 別段預金入出金テーブルINSERT
--	 * 別段預金入出金テーブルへのINSERTを行う。（個別入力無しでのINSERTを想定）
--	 *
--	 * @param	pKijunYmd		基準日
--	 * @param	pItakuKaishaCd	委託会社コード
--	 * @param	pMgrCd			銘柄コード
--	 * @param	pTorihikiYmd	取引日
--	 * @param	pTorihikiKbn	取引区分
--	 * @param	pTorihikiSKbn	取引詳細区分
--	 * @param	pNyushukkinKbn	別段_入出金区分
--	 * @param	pGnrKbn			元利区分
--	 * @param	pGentoKbn		現登区分
--	 * @param	pKngk			金額
--	 * @param	pSzei			消費税
--	 * @param	pKessaiNo		決済番号
--	 * @param	pKessaiNoEda	決済番号枝番
--	 * @param	pFSKbn			金融証券区分
--	 * @param	pBankCd			金融機関コード
--	 * @param	pKozaKbn		口座区分
--	 * @param	pTaxKbn			税区分
--	 * @param	pAiteSKBCd		相手方資金決済会社_金融機関コード
--	 * @param	pAiteSKSCd		相手方資金決済会社_支店コード
--	 * @param	pTesuShuruiCd	手数料種類コード
--	 * @param	pBunpaiFSKbn	分配先金融証券区分
--	 * @param	pBunpaiBankCd	分配先金融機関コード
--	 * @return	INTEGER
--	 *                0:正常終了、データ無し
--	 *                1:予期したエラー
--	 *               99:予期せぬエラー
--	 
CREATE OR REPLACE FUNCTION pkipi000k14r01.insertbd ( pKijunYmd CHAR, pItakuKaishaCd BD_NYUSHUKIN.ITAKU_KAISHA_CD%TYPE, pMgrCd BD_NYUSHUKIN.MGR_CD%TYPE, pTorihikiYmd BD_NYUSHUKIN.TORIHIKI_YMD%TYPE, pTorihikiKbn BD_NYUSHUKIN.TORIHIKI_KBN%TYPE, pTorihikiSKbn BD_NYUSHUKIN.TORIHIKI_S_KBN%TYPE, pNyushukkinKbn BD_NYUSHUKIN.BD_NYUSHUKIN_KBN%TYPE, pGnrKbn BD_NYUSHUKIN.GNR_KBN%TYPE, pGentoKbn BD_NYUSHUKIN.GENTO_KBN%TYPE, pKngk BD_NYUSHUKIN.KNGK%TYPE, pSzei BD_NYUSHUKIN.SZEI%TYPE, pKessaiNo BD_NYUSHUKIN.KESSAI_NO%TYPE, pKessaiNoEda BD_NYUSHUKIN.KESSAI_NO_EDA%TYPE, pFSKbn BD_NYUSHUKIN.FINANCIAL_SECURITIES_KBN%TYPE, pBankCd BD_NYUSHUKIN.BANK_CD%TYPE, pKozaKbn BD_NYUSHUKIN.KOZA_KBN%TYPE, pTaxKbn BD_NYUSHUKIN.TAX_KBN%TYPE, pAiteSKBCd BD_NYUSHUKIN.AITE_SKN_KESSAI_BCD%TYPE, pAiteSKSCd BD_NYUSHUKIN.AITE_SKN_KESSAI_SCD%TYPE, pTesuShuruiCd BD_NYUSHUKIN.TESU_SHURUI_CD%TYPE, pBunpaiFSKbn BD_NYUSHUKIN.FINANCIAL_SECURITIES_KBN2%TYPE, pBunpaiBankCd BD_NYUSHUKIN.BANK_CD2%TYPE ) RETURNS integer AS $body$
DECLARE

		cDuplicateChk	char(1) := NULL;							-- 重複チェックフラグ
		rRowId			tid;											-- 重複データROWID
		cYojitsuFlg		BD_NYUSHUKIN.YOJITSU_FLG%TYPE := NULL;		-- 予定実績フラグ
		
		C_BATCH_USER	CONSTANT text := 'BATCH';
	
BEGIN
		-- 重複のチェック （キー項目すべてをWHERE句に入れてレコードの選択）
		BEGIN
			SELECT
				KOBETSU_INPUT_FLG,
				ctid
			INTO STRICT
				cDuplicateChk,
				rRowId
			FROM
				BD_NYUSHUKIN
			WHERE
				ITAKU_KAISHA_CD = pItakuKaishaCd and
				MGR_CD = pMgrCd and
				TORIHIKI_YMD = pTorihikiYmd and
				TORIHIKI_KBN = pTorihikiKbn and
				TORIHIKI_S_KBN = pTorihikiSKbn and
				FINANCIAL_SECURITIES_KBN = coalesce(pFSKbn,' ') and
				BANK_CD = coalesce(pBankCd,'    ') and
				KOZA_KBN = coalesce(pKozaKbn,'  ') and
				TAX_KBN = coalesce(pTaxKbn,'  ') and
				AITE_SKN_KESSAI_BCD = coalesce(pAiteSKBCd,'    ') and
				AITE_SKN_KESSAI_SCD = coalesce(pAiteSKSCd,'   ') and
				TESU_SHURUI_CD = coalesce(pTesuShuruiCd,'  ') and
				FINANCIAL_SECURITIES_KBN2 = coalesce(pBunpaiFSKbn,' ') and
				BANK_CD2 = coalesce(pBunpaiBankCd,'    ');
		
		EXCEPTION
			WHEN no_data_found THEN
				cDuplicateChk := NULL;
		END;
		
		-- 重複チェックフラグ:0の場合、重複データの削除
		IF (cDuplicateChk = '0') THEN
			CALL pkLog.debug(C_BATCH_USER,'PKIPI000K14R01.insertBD()',
				'別段預金入出金 重複データ削除 銘柄：'||pMgrCd||' 日付：'||pTorihikiYmd||' 区分：'||pTorihikiKbn||pTorihikiSKbn);
			DELETE FROM BD_NYUSHUKIN
			WHERE
				ctid = rRowId;
		END IF;
		
		-- 重複チェックフラグ:0またはNULLの場合、データのinsert
		IF (cDuplicateChk = '0' or coalesce(cDuplicateChk::text, '') = '') THEN
			-- 予定実績フラグの設定
			IF (pTorihikiYmd <= pKijunYmd) THEN
				cYojitsuFlg := '1';		-- 実績
			ELSE
				cYojitsuFlg := '0';		-- 予定
			END IF;
			
			-- 別段預金入出金テーブルへのINSERT
			INSERT INTO BD_NYUSHUKIN(
				ITAKU_KAISHA_CD,
				MGR_CD,
				TORIHIKI_YMD,
				TORIHIKI_KBN,
				TORIHIKI_S_KBN,
				BD_NYUSHUKIN_KBN,
				YOJITSU_FLG,
				KOBETSU_INPUT_FLG,
				GNR_KBN,
				GENTO_KBN,
				KNGK,
				SZEI,
				KESSAI_NO,
				KESSAI_NO_EDA,
				FINANCIAL_SECURITIES_KBN,
				BANK_CD,
				KOZA_KBN,
				TAX_KBN,
				AITE_SKN_KESSAI_BCD,
				AITE_SKN_KESSAI_SCD,
				TESU_SHURUI_CD,
				FINANCIAL_SECURITIES_KBN2,
				BANK_CD2,
				GROUP_ID,
				SHORI_KBN,
				LAST_TEISEI_DT,
				LAST_TEISEI_ID,
				SHONIN_DT,
				SHONIN_ID,
				KOUSIN_DT,
				KOUSIN_ID,
				SAKUSEI_DT,
				SAKUSEI_ID
			) VALUES (
				pItakuKaishaCd,
				pMgrCd,
				coalesce(pTorihikiYmd,' '),
				coalesce(pTorihikiKbn,' '),
				coalesce(pTorihikiSKbn,' '),
				coalesce(pNyushukkinKbn,' '),
				coalesce(cYojitsuFlg,' '),
				'0',
				coalesce(pGnrKbn,' '),
				coalesce(pGentoKbn,' '),
				coalesce(pKngk,0),
				coalesce(pSzei,0),
				coalesce(pKessaiNo,' '),
				coalesce(pKessaiNoEda,' '),
				coalesce(pFSKbn,' '),
				coalesce(pBankCd,' '),
				coalesce(pKozaKbn,' '),
				coalesce(pTaxKbn,' '),
				coalesce(pAiteSKBCd,' '),
				coalesce(pAiteSKSCd,' '),
				coalesce(pTesuShuruiCd,' '),
				coalesce(pBunpaiFSKbn,' '),
				coalesce(pBunpaiBankCd,' '),
				' ',
				'1',
				pkDate.getCurrentTime()::timestamp,
				C_BATCH_USER,
				pkDate.getCurrentTime()::timestamp,
				C_BATCH_USER,
				pkDate.getCurrentTime()::timestamp,
				C_BATCH_USER,
				pkDate.getCurrentTime()::timestamp,
				C_BATCH_USER
			);
		ELSE
			CALL pkLog.debug(C_BATCH_USER,'PKIPI000K14R01.insertBD()',
				'別段預金入出金 insertスキップ 銘柄：'||pMgrCd||' 日付：'||pTorihikiYmd||' 区分：'||pTorihikiKbn||pTorihikiSKbn);
		END IF;
		
		RETURN pkconstant.success();
	
	EXCEPTION
		WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701','PKIPI000K14R01.insertBD()','SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
			RETURN pkconstant.FATAL();
	END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipi000k14r01.insertbd ( pKijunYmd CHAR, pItakuKaishaCd BD_NYUSHUKIN.ITAKU_KAISHA_CD%TYPE, pMgrCd BD_NYUSHUKIN.MGR_CD%TYPE, pTorihikiYmd BD_NYUSHUKIN.TORIHIKI_YMD%TYPE, pTorihikiKbn BD_NYUSHUKIN.TORIHIKI_KBN%TYPE, pTorihikiSKbn BD_NYUSHUKIN.TORIHIKI_S_KBN%TYPE, pNyushukkinKbn BD_NYUSHUKIN.BD_NYUSHUKIN_KBN%TYPE, pGnrKbn BD_NYUSHUKIN.GNR_KBN%TYPE, pGentoKbn BD_NYUSHUKIN.GENTO_KBN%TYPE, pKngk BD_NYUSHUKIN.KNGK%TYPE, pSzei BD_NYUSHUKIN.SZEI%TYPE, pKessaiNo BD_NYUSHUKIN.KESSAI_NO%TYPE, pKessaiNoEda BD_NYUSHUKIN.KESSAI_NO_EDA%TYPE, pFSKbn BD_NYUSHUKIN.FINANCIAL_SECURITIES_KBN%TYPE, pBankCd BD_NYUSHUKIN.BANK_CD%TYPE, pKozaKbn BD_NYUSHUKIN.KOZA_KBN%TYPE, pTaxKbn BD_NYUSHUKIN.TAX_KBN%TYPE, pAiteSKBCd BD_NYUSHUKIN.AITE_SKN_KESSAI_BCD%TYPE, pAiteSKSCd BD_NYUSHUKIN.AITE_SKN_KESSAI_SCD%TYPE, pTesuShuruiCd BD_NYUSHUKIN.TESU_SHURUI_CD%TYPE, pBunpaiFSKbn BD_NYUSHUKIN.FINANCIAL_SECURITIES_KBN2%TYPE, pBunpaiBankCd BD_NYUSHUKIN.BANK_CD2%TYPE ) FROM PUBLIC;

	--*
--	 * 会計登録入出金テーブルINSERT
--	 * 会計登録入出金テーブルへのINSERTを行う。（個別入力無しでのINSERTを想定）
--	 *
--	 * @param	pItakuKaishaCd	委託会社コード
--	 * @param	pMgrCd			銘柄コード
--	 * @param	pTorihikiYmd	取引日
--	 * @param	pKanjoKamokuCd	勘定科目コード
--	 * @param	pTesuShuruiCd	手数料種類コード
--	 * @param	pFSKbn			金融証券区分
--	 * @param	pBankCd			金融機関コード
--	 * @param	pKozaKbn		口座区分
--	 * @param	pTaxKbn			税区分
--	 * @param	pNyushukkinKbn	入出金区分
--	 * @param	pKngk			金額
--	 * @param	pSzei			消費税
--	 * @param	pBikou			備考
--	 * @return	INTEGER
--	 *                0:正常終了、データ無し
--	 *                1:予期したエラー
--	 *               99:予期せぬエラー
--	 
CREATE OR REPLACE FUNCTION pkipi000k14r01.insertkt ( pItakuKaishaCd KT_NYUSHUKIN.ITAKU_KAISHA_CD%TYPE, pMgrCd KT_NYUSHUKIN.MGR_CD%TYPE, pTorihikiYmd KT_NYUSHUKIN.TORIHIKI_YMD%TYPE, pKanjoKamokuCd KT_NYUSHUKIN.KT_KANJO_KAMOKU_CD%TYPE, pTesuShuruiCd KT_NYUSHUKIN.TESU_SHURUI_CD%TYPE, pFSKbn KT_NYUSHUKIN.FINANCIAL_SECURITIES_KBN%TYPE, pBankCd KT_NYUSHUKIN.BANK_CD%TYPE, pKozaKbn KT_NYUSHUKIN.KOZA_KBN%TYPE, pTaxKbn KT_NYUSHUKIN.TAX_KBN%TYPE, pNyushukkinKbn KT_NYUSHUKIN.KT_NYUSHUKIN_KBN%TYPE, pKngk KT_NYUSHUKIN.KNGK%TYPE, pSzei KT_NYUSHUKIN.SZEI%TYPE, pBikou KT_NYUSHUKIN.KT_BIKOU%TYPE ) RETURNS integer AS $body$
DECLARE

		cDuplicateChk	char(1) := NULL;							-- 重複チェックフラグ
		rRowId			tid;									-- 重複データROWID
		
		C_BATCH_USER	CONSTANT text := 'BATCH';
	
BEGIN
	
		-- 重複のチェック （キー項目すべてをWHERE句に入れてレコードの選択）
		BEGIN
			SELECT
				KOBETSU_INPUT_FLG,
				ctid
			INTO STRICT
				cDuplicateChk,
				rRowId
			FROM
				KT_NYUSHUKIN
			WHERE
				ITAKU_KAISHA_CD = pItakuKaishaCd and
				MGR_CD = pMgrCd and
				TORIHIKI_YMD = pTorihikiYmd and
				KT_KANJO_KAMOKU_CD = pKanjoKamokuCd and
				TESU_SHURUI_CD = coalesce(pTesuShuruiCd,'  ') and
				FINANCIAL_SECURITIES_KBN = coalesce(pFSKbn,' ') and
				BANK_CD = coalesce(pBankCd,'    ') and
				KOZA_KBN = coalesce(pKozaKbn,'  ') and
				TAX_KBN = coalesce(pTaxKbn,'  ');
		
		EXCEPTION
			WHEN no_data_found THEN
				cDuplicateChk := NULL;
		END;
		
		-- 重複チェックフラグ:0の場合、重複データの削除
		IF (cDuplicateChk = '0') THEN
			
			CALL pkLog.debug(C_BATCH_USER,'PKIPI000K14R01.insertKT()',
				'会計登録入出金 重複データ削除 銘柄：'||pMgrCd||' 日付：'||pTorihikiYmd||' 科目：'||pKanjoKamokuCd);
			DELETE FROM KT_NYUSHUKIN
			WHERE
				ctid = rRowId;
		END IF;
		
		-- 重複チェックフラグ:0またはNULLの場合、データのinsert
		IF (cDuplicateChk = '0' or coalesce(cDuplicateChk::text, '') = '') THEN
			-- 会計登録入出金テーブルへのINSERT
			INSERT INTO KT_NYUSHUKIN(
				ITAKU_KAISHA_CD,
				MGR_CD,
				TORIHIKI_YMD,
				KT_KANJO_KAMOKU_CD,
				TESU_SHURUI_CD,
				FINANCIAL_SECURITIES_KBN,
				BANK_CD,
				KOZA_KBN,
				TAX_KBN,
				KT_NYUSHUKIN_KBN,
				KOBETSU_INPUT_FLG,
				KNGK,
				SZEI,
				KT_BIKOU,
				GROUP_ID,
				SHORI_KBN,
				LAST_TEISEI_DT,
				LAST_TEISEI_ID,
				SHONIN_DT,
				SHONIN_ID,
				KOUSIN_DT,
				KOUSIN_ID,
				SAKUSEI_DT,
				SAKUSEI_ID
			) VALUES (
				pItakuKaishaCd,
				pMgrCd,
				coalesce(pTorihikiYmd,' '),
				coalesce(pKanjoKamokuCd,' '),
				coalesce(pTesuShuruiCd,' '),
				coalesce(pFSKbn,' '),
				coalesce(pBankCd,'    '),
				coalesce(pKozaKbn,'  '),
				coalesce(pTaxKbn,'  '),
				coalesce(pNyushukkinKbn,' '),
				'0',
				coalesce(pKngk,0),
				coalesce(pSzei,0),
				coalesce(pBikou,' '),
				' ',
				'1',
				pkDate.getCurrentTime()::timestamp,
				C_BATCH_USER,
				pkDate.getCurrentTime()::timestamp,
				C_BATCH_USER,
				pkDate.getCurrentTime()::timestamp,
				C_BATCH_USER,
				pkDate.getCurrentTime()::timestamp,
				C_BATCH_USER
			);
		ELSE
			CALL pkLog.debug(C_BATCH_USER,'PKIPI000K14R01.insertKT()',
				'会計登録入出金 insertスキップ 銘柄：'||pMgrCd||' 日付：'||pTorihikiYmd||' 科目：'||pKanjoKamokuCd);
		END IF;
		
		RETURN pkconstant.success();
		
	EXCEPTION
		WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701','PKIPI000K14R01.insertKT()','SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
			RETURN pkconstant.FATAL();
	END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipi000k14r01.insertkt ( pItakuKaishaCd KT_NYUSHUKIN.ITAKU_KAISHA_CD%TYPE, pMgrCd KT_NYUSHUKIN.MGR_CD%TYPE, pTorihikiYmd KT_NYUSHUKIN.TORIHIKI_YMD%TYPE, pKanjoKamokuCd KT_NYUSHUKIN.KT_KANJO_KAMOKU_CD%TYPE, pTesuShuruiCd KT_NYUSHUKIN.TESU_SHURUI_CD%TYPE, pFSKbn KT_NYUSHUKIN.FINANCIAL_SECURITIES_KBN%TYPE, pBankCd KT_NYUSHUKIN.BANK_CD%TYPE, pKozaKbn KT_NYUSHUKIN.KOZA_KBN%TYPE, pTaxKbn KT_NYUSHUKIN.TAX_KBN%TYPE, pNyushukkinKbn KT_NYUSHUKIN.KT_NYUSHUKIN_KBN%TYPE, pKngk KT_NYUSHUKIN.KNGK%TYPE, pSzei KT_NYUSHUKIN.SZEI%TYPE, pBikou KT_NYUSHUKIN.KT_BIKOU%TYPE ) FROM PUBLIC;
-- End of Oracle package 'pkipi000k14r01' declaration
