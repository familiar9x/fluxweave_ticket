
/*==============================================================================*/

/*                  関数定義                                                    */

/*==============================================================================*/
drop function if exists sfinskikinido;
drop function if exists sfinskikinido_getEbSendYmd;
drop function if exists sfinskikinido_getTruncKngk;
drop function if exists sfinskikinido_getKknbillShurui;
drop PROCEDURE if exists sfinskikinido_getGensai;
drop function if exists sfinskikinido_getGnknKijunZndk;
drop PROCEDURE if exists sfinskikinido_insertData;
drop procedure if exists sfinskikinido_updateData;
drop function if exists sfinskikinido_checkNyukinZumi;
drop procedure if exists sfinskikinido_calcRikinTesuryo;
drop procedure if exists sfinskikinido_deleteData;
drop function if exists sfinskikinido_getZndkKijunYmd;
drop procedure if exists sfinskikinido_calcgankintesuryo(varchar, char, varchar, char, char, char, varchar, varchar, out integer);
drop procedure if exists sfinskikinido_calcgankintesuryo(varchar, char, varchar, char, char, char, varchar, varchar, char, char, out integer);
drop procedure if exists sfinskikinido_calcgankintesuryo(varchar, char, varchar, char, char, char, varchar, varchar, char, char, char, out integer);
drop procedure if exists sfinskikinido_calcgankintesuryo(varchar, char, varchar, char, char, char, varchar, varchar, char, char, char, varchar, out integer);
drop procedure if exists sfinskikinido_calcgankintesuryo(varchar, char, varchar, char, char, char, varchar, varchar, char, char, char, varchar, varchar, out integer);
drop procedure if exists sfinskikinido_calcgankintesuryo(varchar, char, varchar, char, char, char, varchar, varchar, char, char, char, varchar, varchar, varchar, out integer);

/**
	* 残高基準日取得
	*
	* @param  inRealBatchKbn      リアル・バッチ区分
	* @param  inDataSakuseiKbn    データ作成区分（0：予定表（一覧）、1：請求書）
	* @param  inKknZndkKakuteiKbn 基金残高確定区分
	* @param  inIdoYmd            異動年月日（支払期日）
	* @param  inHakkoYmd          発行日
	* @param  inKjnYmd            利払日（償還日）
	* @param  inKknZndkKjnYmdKbn  基金残高基準日区分
	* @param  inKknbillOutYmd     基金請求書出力日
	* @return varchar            残高基準日
	*/

CREATE OR REPLACE FUNCTION sfinskikinido_getZndkKijunYmd(
	inRealBatchKbn      IN text,
	inDataSakuseiKbn	IN TESURYO.DATA_SAKUSEI_KBN%TYPE,
	inKknZndkKakuteiKbn IN MGR_KIHON.KKN_ZNDK_KAKUTEI_KBN%TYPE,
	inIdoYmd            IN KIKIN_IDO.IDO_YMD%TYPE,
	inHakkoYmd          IN MGR_KIHON.HAKKO_YMD%TYPE,
	inKjnYmd            IN MGR_RBRKIJ.RBR_YMD%TYPE,
	inKknZndkKjnYmdKbn  IN text,
	inKknbillOutYmd		IN MGR_RBRKIJ.KKNBILL_OUT_YMD%TYPE,
	l_inItakuKaishaCd	IN KIKIN_IDO.ITAKU_KAISHA_CD%TYPE,
	l_inMgrCd			IN KIKIN_IDO.MGR_CD%TYPE
)
RETURNS text
LANGUAGE PLPGSQL
AS
$getZndkKijunYmd$
DECLARE
	pZndkKijunYmd varchar(8);    -- 残高基準日

BEGIN

	/* リアル かつ 請求書 の場合 */

	IF inRealBatchKbn = '0' AND inDataSakuseiKbn = '1' THEN
		-- 基金残高基準日区分によりセットする日付を変える
		CASE inKknZndkKjnYmdKbn
			-- 「基金残高確定区分を使用」の場合
			WHEN '1' THEN
				-- 残高確定区分でセットする日付を変える
				CASE inKknZndkKakuteiKbn
					-- 支払期日の1ヶ月前の末日
					WHEN '1' THEN
						pZndkKijunYmd := pkDate.getGetsumatsuYmd(inIdoYmd, -1);
					-- 支払期日の2ヶ月前の末日
					WHEN '2' THEN
						pZndkKijunYmd := pkDate.getGetsumatsuYmd(inIdoYmd, -2);
					-- 利払日前日時点
					WHEN '8' THEN
						pZndkKijunYmd := pkDate.getZenYmd(inKjnYmd);
					-- 請求書出力時点
					WHEN '9' THEN
						pZndkKijunYmd := pkDate.getZenBusinessYmd(
											pkIpaKknIdo.getSeikyushoBillOutYmd(
																	l_inItakuKaishaCd,
																	inIdoYmd,
																	inKknbillOutYmd));
					ELSE
						call pklog.error('ECM701', 'SFINSKIKINIDO', '基金残高確定区分が存在しません。'
								||	'委託会社：' || l_inItakuKaishaCd || '　銘柄：' || l_inMgrCd
								|| '　区分：' || inKknZndkKakuteiKbn );
						RAISE EXCEPTION 'zndk_kijun_error' USING ERRCODE = '50015';
				END CASE;
			-- 「利払日前日」の場合
			WHEN '2' THEN
				pZndkKijunYmd := pkDate.getZenYmd(inKjnYmd);
			-- 「業務日付」の場合
			WHEN '0' THEN
				pZndkKijunYmd := pkDate.getGyomuYmd();
			ELSE
				call pklog.error('ECM701', 'SFINSKIKINIDO', '基金残高基準日区分が存在しません。'
						||	'委託会社：' || l_inItakuKaishaCd || '　銘柄：' || l_inMgrCd
						|| '　区分：' || inKknZndkKjnYmdKbn );
				RAISE EXCEPTION 'zndk_kijun_error' USING ERRCODE = '50015';
		END CASE;

	/* リアル かつ 請求書一覧の場合 */

	ELSIF inRealBatchKbn = '0' AND inDataSakuseiKbn = '0' THEN
		--残高確定区分でセットする日付を変える
		CASE inKknZndkKakuteiKbn
			-- 支払期日の1ヶ月前の末日
			WHEN '1' THEN
				pZndkKijunYmd := pkDate.getGetsumatsuYmd(inIdoYmd, -1);
			-- 支払期日の2ヶ月前の末日
			WHEN '2' THEN
				pZndkKijunYmd := pkDate.getGetsumatsuYmd(inIdoYmd, -2);
			-- 利払日前日時点
			WHEN '8' THEN
				pZndkKijunYmd := pkDate.getZenYmd(inKjnYmd);
			-- 請求書出力時点
			WHEN '9' THEN
				pZndkKijunYmd := pkDate.getZenYmd(inKjnYmd);
			ELSE
				call pklog.error('ECM701', 'SFINSKIKINIDO', '基金残高確定区分が存在しません。'
						||	'委託会社：' || l_inItakuKaishaCd || '　銘柄：' || l_inMgrCd
						|| '　区分：' || inKknZndkKakuteiKbn );
				RAISE EXCEPTION 'zndk_kijun_error' USING ERRCODE = '50015';
		END CASE;
	/* バッチ の場合 */

	ELSE
		--残高確定区分でセットする日付を変える
		CASE inKknZndkKakuteiKbn
			-- 支払期日の1ヶ月前の末日
			WHEN '1' THEN
				pZndkKijunYmd := pkDate.getGetsumatsuYmd(inIdoYmd, -1);
			-- 支払期日の2ヶ月前の末日
			WHEN '2' THEN
				pZndkKijunYmd := pkDate.getGetsumatsuYmd(inIdoYmd, -2);
			-- 利払日前日時点
			WHEN '8' THEN
				pZndkKijunYmd := pkDate.getZenYmd(inKjnYmd);
			-- 請求書出力時点
			WHEN '9' THEN
				pZndkKijunYmd := pkDate.getGyomuYmd();
			ELSE
				call pklog.error('ECM701', 'SFINSKIKINIDO', '基金残高確定区分が存在しません。'
						||	'委託会社：' || l_inItakuKaishaCd || '　銘柄：' || l_inMgrCd
						|| '　区分：' || inKknZndkKakuteiKbn || ' 残高基準日：' || pZndkKijunYmd);
				RAISE EXCEPTION 'zndk_kijun_error' USING ERRCODE = '50015';
		END CASE;
	END IF;
	-- 基準日が発行日より前であれば、基準日に発行日をセットする。
	IF pZndkKijunYmd < inHakkoYmd THEN
		pZndkKijunYmd := inHakkoYmd;
	END IF;

	RETURN pZndkKijunYmd;
END $getZndkKijunYmd$;

/**
	* ＥＢ送信年月日取得
	*
	* @param  inItakuKaishaCd 委託会社コード
	* @param  inChokyuYmd     徴求日
	* @return varchar        ＥＢ送信年月日
	*/
CREATE OR REPLACE FUNCTION sfinskikinido_getEbSendYmd(
	inItakuKaishaCd IN KIKIN_IDO.ITAKU_KAISHA_CD%TYPE,
	inChokyuYmd     IN MGR_RBRKIJ.KKN_CHOKYU_YMD%TYPE
)
RETURNS VARCHAR
LANGUAGE PLPGSQL
AS
$getEbSendYmd$
DECLARE
	pEbFlg         VJIKO_ITAKU.EB_FLG%TYPE;
	pGabruEbSebdDd VJIKO_ITAKU.GANRI_EB_SEND_DD%TYPE;
	pEbSendYmd     KIKIN_IDO.EB_SEND_YMD%TYPE;
BEGIN
	SELECT
		EB_FLG,
		GANRI_EB_SEND_DD
	INTO STRICT
		pEbFlg,
		pGabruEbSebdDd
	FROM
		VJIKO_ITAKU
	WHERE KAIIN_ID = inItakuKaishaCd;

	IF pEbFlg = '1' THEN
		-- エリアコードは東京固定
		pEbSendYmd := pkDate.getMinusDateBusiness(inChokyuYmd, (pGabruEbSebdDd)::int , pkConstant.TOKYO_AREA_CD());
	ELSE
		pEbSendYmd := ' ';
	END IF;
	RETURN pEbSendYmd;
END $getEbSendYmd$;

/**
	* 通貨コードが「JPY」のときは小数点以下を切り捨て
	* それ以外の時は小数第3位を切り捨てる。
	*
	* @param  inTsukaCd 通貨コード
	* @param  inKngk    金額
	* @return numeric    切り捨てられた金額
	*/
CREATE OR REPLACE FUNCTION sfinskikinido_getTruncKngk(
	inTsukaCd IN MGR_KIHON.RBR_TSUKA_CD%TYPE,
	inKngk    IN DECIMAL
)
RETURNS DECIMAL
LANGUAGE PLPGSQL
AS
$getTruncKngk$
DECLARE
	pTruncKingk numeric DEFAULT 0;
BEGIN
	IF inTsukaCd = 'JPY' THEN
		pTruncKingk := trunc(inKngk);
	ELSE
		pTruncKingk := trunc(inKngk, 2);
	END IF;
	RETURN pTruncKingk;
END $getTruncKngk$;

/**
	* 基金請求種類を返します。
	*
	* @param  inFlg11  元金入金フラグ
	* @param  inFlg12  元金手数料入金フラグ
	* @param  inFlg21  利金入金フラグ
	* @param  inFlg22  利金手数料入金フラグ
	* @return varchar 基金請求種類
	*/
CREATE OR REPLACE FUNCTION sfinskikinido_getKknbillShurui(
	inFlg11 IN INTEGER,
	inFlg12 IN INTEGER,
	inFlg21 IN INTEGER,
	inFlg22 IN INTEGER
)
RETURNS CHAR(1)
LANGUAGE PLPGSQL
AS
$getKknbillShurui$
DECLARE
	pKknbillShurui KIKIN_IDO.KKNBILL_SHURUI%TYPE;    -- 基金請求種類
BEGIN
	-- 元金入金 OR 利金入金のみ
	IF (inFlg11 <> 0 OR inFlg21 <> 0) AND inFlg12 = 0 AND inFlg22 = 0 THEN
		pKknbillShurui := '2';    -- 支払基金のみ
	-- 元金手数料入金 OR 利金手数料入金のみ
	ELSIF inFlg11 = 0 AND inFlg21 = 0 AND (inFlg12 <> 0 OR inFlg22 <> 0) THEN
		pKknbillShurui := '3';    -- 支払手数料のみ
	-- （元金入金 OR 利金入金）かつ（元金手数料入金 OR 利金手数料入金）
	ELSIF (inFlg11 <> 0 OR inFlg21 <> 0) AND (inFlg12 <> 0 OR inFlg22 <> 0) THEN
		pKknbillShurui := '1';    -- 支払基金・手数料
	END IF;

	-- RAISE NOTICE 'out sfinskikinido_getKknbillShurui pKknbillShurui: %', pKknbillShurui;

	RETURN pKknbillShurui;
END $getKknbillShurui$;

/**
	* 同一日当減債事由より以前に発生した償還の減債分名目金額とファクターを算出します。
	*/
CREATE OR REPLACE PROCEDURE sfinskikinido_getGensai(
	inItakuKaishaCd  IN MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE,
	inMgrCd          IN MGR_SHOKIJ.MGR_CD%TYPE,
	inKakushasaiKngk IN MGR_KIHON.KAKUSHASAI_KNGK%TYPE,
	inShokanKjt      IN MGR_SHOKIJ.SHOKAN_KJT%TYPE,
	inShokanKbn      IN MGR_SHOKIJ.SHOKAN_KBN%TYPE,
	outMeimokuKngk   OUT numeric,
	outFactor        OUT numeric(11,10)
)
LANGUAGE PLPGSQL
AS
$getGensai$
DECLARE
	CUR_SHOKIJ_DOUJITSU CURSOR FOR
		SELECT
			MG3.SHOKAN_KBN,
			MG3.FUNIT_GENSAI_KNGK,
			MG3.MUNIT_GENSAI_KNGK,
			MG3.FACTOR
		FROM
			MGR_SHOKIJ MG3,
			(SELECT CODE_VALUE, CODE_NM, CODE_SORT FROM SCODE WHERE CODE_SHUBETSU = '714') SC01
		WHERE
			MG3.ITAKU_KAISHA_CD = inItakuKaishaCd
		AND MG3.MGR_CD = inMgrCd
		AND MG3.SHOKAN_YMD = inShokanKjt
		AND MG3.SHOKAN_KBN = SC01.CODE_VALUE
		AND (SELECT CODE_SORT FROM SCODE WHERE CODE_SHUBETSU = '714' AND CODE_VALUE = inShokanKbn) > SC01.CODE_SORT;
BEGIN
	-- RAISE NOTICE 'in sfinskikinido_getGensai';

	-- OUT引数初期化
	outMeimokuKngk := 0;
	outFactor := 0;

	FOR rec IN CUR_SHOKIJ_DOUJITSU LOOP
		-- 償還区分：買入消却とプットは口数が減る事由のため名目金額を算出する
		IF rec.SHOKAN_KBN = pkIpaKknIdo.KAIIRE_SHOKYAKU() OR rec.SHOKAN_KBN = pkIpaKknIdo.PUT() THEN
			IF rec.FACTOR <> 0 THEN
				outMeimokuKngk := outMeimokuKngk + rec.MUNIT_GENSAI_KNGK / rec.FACTOR;
			END IF;
		-- その他の定時償還（定額・不定額）、コール（一部・全額）はファクターが減る事由のためファクターを算出する
		ELSE
			outFactor := outFactor + rec.FUNIT_GENSAI_KNGK / inKakushasaiKngk;
		END IF;
	END LOOP;

	-- RAISE NOTICE 'sfinskikinido_getGensai done';
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'sfInsKikinIdo.getGensai', '委託会社コード：' || inItakuKaishaCd || ' 銘柄コード：'|| inMgrCd);
		RAISE;
END $getGensai$;

/**
	* 元金計算のための残高基準日時点の名目残高（振替債分）を求めます。
	* 振替債分の名目残高を取得するため、償還区分つきの関数を仕様します。
	* 　（基準日の最終残を求めたいので、償還区分の償還順が一番最後のものをセットする。）
	*/
CREATE OR REPLACE FUNCTION sfinskikinido_getGnknKijunZndk(
				inItakuKaishaCd IN KIKIN_IDO.ITAKU_KAISHA_CD%TYPE,
				inMgrCd IN KIKIN_IDO.MGR_CD%TYPE,
				inZndkKijunYmd IN KIKIN_IDO.ZNDK_KIJUN_YMD%TYPE)
RETURNS DECIMAL
LANGUAGE PLPGSQL
AS
$getGnknKijunZndk$
DECLARE
	wMaxCodeValue SCODE.CODE_VALUE%TYPE;
	wKijunZndk numeric DEFAULT 0;
BEGIN
	-- 償還事由のうち償還順が一番最後の事由を取得する
	BEGIN
		SELECT CODE_VALUE INTO STRICT wMaxCodeValue
		FROM SCODE
		WHERE CODE_SHUBETSU = '714'
		AND CODE_SORT = (SELECT MAX(CODE_SORT) FROM SCODE WHERE CODE_SHUBETSU = '714');
	EXCEPTION
		WHEN OTHERS THEN
			CALL pkLog.fatal('ECM701', 'sfInsKikinIdo.getGnknKijunZndk', '償還事由のコードマスタの設定に誤りがあります！');
			RAISE;
	END;

	wKijunZndk := pkIpaZndk.getKjnZndk(inItakuKaishaCd, inMgrCd, inZndkKijunYmd, nullif(trim(both wMaxCodeValue), ''), 11)::numeric;
	RETURN wKijunZndk;
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'sfInsKikinIdo.getGnknKijunZndk', '委託会社コード：' || inItakuKaishaCd || ' 銘柄コード：'|| inMgrCd);
		RAISE;
END $getGnknKijunZndk$;

/**
	* 基金異動履歴テーブルにデータを登録します。
	*
	* @param inItakuKaishaCd    委託会社コード
	* @param inMgrCd            銘柄コード
	* @param inRbrKjt           利払期日
	* @param inRbrYmd           利払日
	* @param inTsukaCd          通貨コード
	* @param inIdoYmd           異動年月日
	* @param inKknIdoKbn        基金異動区分
	* @param inKknbillShurui    基金請求種類
	* @param inKknNyukinKngk    基金入金額
	* @param inKknShukinKngk    基金出金額
	* @param inKkmemberFsKbn    金融証券区分(機構加入者)
	* @param inKkmemberBcd      金融機関コード(機構加入者)
	* @param inKkmemberKkbn     口座区分(機構加入者)
	* @param inNyukinKakuninYmd 入金確認日
	* @param inNyukinStsKbn     入金状況区分
	* @param inDataSakuseiKbn   データ作成区分
	* @param inZndkKijunYmd     残高基準日
	* @param inKijunZndk        基準残高
	* @param inEbMakeYmd        ＥＢ作成年月日
	* @param inEbSendYmd        ＥＢ送信年月日
	* @param inGroupId          グループＩＤ
	* @param inShoriKbn         処理区分
	* @param inLastTeiseiDt     最終訂正日時
	* @param inLastTeiseiId     最終訂正者
	* @param inShoninDt         承認日時
	* @param inShoninId         承認者
	* @param inKousinId         更新者
	* @param inSakuseiId        作成者
	*/
CREATE OR REPLACE PROCEDURE sfinskikinido_insertData(
	inItakuKaishaCd    IN KIKIN_IDO.ITAKU_KAISHA_CD%TYPE,
	inMgrCd            IN KIKIN_IDO.MGR_CD%TYPE,
	inRbrKjt           IN KIKIN_IDO.RBR_KJT%TYPE,
	inIdoYmd           IN KIKIN_IDO.IDO_YMD%TYPE,
	inKknIdoKbn        IN KIKIN_IDO.KKN_IDO_KBN%TYPE,
	inLastTeiseiDt     IN KIKIN_IDO.LAST_TEISEI_DT%TYPE ,
	inShoninDt         IN KIKIN_IDO.SHONIN_DT%TYPE DEFAULT NULL,
	inRbrYmd           IN KIKIN_IDO.RBR_YMD%TYPE DEFAULT ' ',
	inTsukaCd          IN KIKIN_IDO.TSUKA_CD%TYPE DEFAULT ' ',
	inKknbillShurui    IN KIKIN_IDO.KKNBILL_SHURUI%TYPE DEFAULT ' ',
	inKknNyukinKngk    IN KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE DEFAULT 0,
	inKknShukinKngk    IN KIKIN_IDO.KKN_SHUKIN_KNGK%TYPE DEFAULT 0,
	inKkmemberFsKbn    IN KIKIN_IDO.KKMEMBER_FS_KBN%TYPE DEFAULT ' ',
	inKkmemberBcd      IN KIKIN_IDO.KKMEMBER_BCD%TYPE DEFAULT ' ',
	inKkmemberKkbn     IN KIKIN_IDO.KKMEMBER_KKBN%TYPE DEFAULT ' ',
	inNyukinKakuninYmd IN KIKIN_IDO.NYUKIN_KAKUNIN_YMD%TYPE DEFAULT ' ',
	inNyukinStsKbn     IN KIKIN_IDO.NYUKIN_STS_KBN%TYPE DEFAULT '0',
	inDataSakuseiKbn   IN KIKIN_IDO.DATA_SAKUSEI_KBN%TYPE DEFAULT ' ',
	inZndkKijunYmd     IN KIKIN_IDO.ZNDK_KIJUN_YMD%TYPE DEFAULT ' ',
	inKijunZndk        IN KIKIN_IDO.KIJUN_ZNDK%TYPE DEFAULT 0,
	inEbMakeYmd        IN KIKIN_IDO.EB_MAKE_YMD%TYPE DEFAULT ' ',
	inEbSendYmd        IN KIKIN_IDO.EB_SEND_YMD%TYPE DEFAULT ' ',
	inGroupId          IN KIKIN_IDO.GROUP_ID%TYPE DEFAULT ' ',
	inShoriKbn         IN KIKIN_IDO.SHORI_KBN%TYPE DEFAULT ' ',
	inLastTeiseiId     IN KIKIN_IDO.LAST_TEISEI_ID%TYPE DEFAULT ' ',
	inShoninId         IN KIKIN_IDO.SHONIN_ID%TYPE DEFAULT ' ',
	inKousinId         IN KIKIN_IDO.KOUSIN_ID%TYPE DEFAULT ' ',
	inSakuseiId        IN KIKIN_IDO.SAKUSEI_ID%TYPE DEFAULT ' '
)
LANGUAGE PLPGSQL
AS
$insertData$
DECLARE
	pCnt DECIMAL DEFAULT 0;
BEGIN
	SELECT
		COUNT(*) INTO STRICT pCnt
	FROM
		KIKIN_IDO
	WHERE ITAKU_KAISHA_CD = inItakuKaishaCd
	AND   MGR_CD          = inMgrCd
	AND   RBR_KJT         = inRbrKjt
	AND   IDO_YMD         = inIdoYmd
	AND   KKN_IDO_KBN     = inKknIdoKbn;

	IF pCnt = 0
		AND inRbrYmd > pkDate.getGyomuYmd() THEN	-- 利払日が業務日付より後の場合にINSERTする
		INSERT INTO KIKIN_IDO(
			ITAKU_KAISHA_CD,  MGR_CD,         RBR_KJT,        RBR_YMD,            TSUKA_CD,
			IDO_YMD,          KKN_IDO_KBN,    KKNBILL_SHURUI, KKN_NYUKIN_KNGK,    KKN_SHUKIN_KNGK,
			KKMEMBER_FS_KBN,  KKMEMBER_BCD,   KKMEMBER_KKBN,  NYUKIN_KAKUNIN_YMD, NYUKIN_STS_KBN,
			DATA_SAKUSEI_KBN, ZNDK_KIJUN_YMD, KIJUN_ZNDK,     EB_MAKE_YMD,        EB_SEND_YMD,
			GROUP_ID,         SHORI_KBN,      LAST_TEISEI_DT, LAST_TEISEI_ID,     SHONIN_DT,
			SHONIN_ID,        KOUSIN_ID,      SAKUSEI_ID
		)
		VALUES (
			inItakuKaishaCd,  inMgrCd,        inRbrKjt,        inRbrYmd,           inTsukaCd,
			inIdoYmd,         inKknIdoKbn,    inKknbillShurui, inKknNyukinKngk,    inKknShukinKngk,
			inKkmemberFsKbn,  inKkmemberBcd,  inKkmemberKkbn,  inNyukinKakuninYmd, inNyukinStsKbn,
			inDataSakuseiKbn, inZndkKijunYmd, inKijunZndk,     inEbMakeYmd,        inEbSendYmd,
			inGroupId,        inShoriKbn,     inLastTeiseiDt,  inLastTeiseiId,     inShoninDt,
			inShoninId,       inKousinId,     inSakuseiId
		);
	END IF;
END $insertData$;

/**
	* 基金異動履歴テーブルの基金請求種類を更新します。
	*
	* @param inItakuKaishaCd 委託会社コード
	* @param inMgrCd         銘柄コード
	* @param inRbrKjt        利払期日
	* @param inIdoYmd        異動年月日
	* @param inKknIdoKbn     基金異動区分
	* @param inKknbillShurui 基金請求種類
	*/
CREATE OR REPLACE PROCEDURE sfinskikinido_updateData(
	inItakuKaishaCd IN KIKIN_IDO.ITAKU_KAISHA_CD%TYPE,
	inMgrCd         IN KIKIN_IDO.MGR_CD%TYPE,
	inRbrKjt        IN KIKIN_IDO.RBR_KJT%TYPE,
	inIdoYmd        IN KIKIN_IDO.IDO_YMD%TYPE,
	inKknIdoKbn     IN KIKIN_IDO.KKN_IDO_KBN%TYPE,
	inKknbillShurui IN KIKIN_IDO.KKNBILL_SHURUI%TYPE DEFAULT ' '
)
LANGUAGE PLPGSQL
AS
$updateData$
DECLARE
	gKknbillShurui KIKIN_IDO.KKNBILL_SHURUI%TYPE;
BEGIN
	BEGIN
		SELECT
			KKNBILL_SHURUI INTO gKknbillShurui
		FROM
			KIKIN_IDO
		WHERE ITAKU_KAISHA_CD = inItakuKaishaCd
		AND   MGR_CD          = inMgrCd
		AND   RBR_KJT         = inRbrKjt
		AND   IDO_YMD         = inIdoYmd
		AND   KKN_IDO_KBN     = inKknIdoKbn;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			gKknbillShurui := NULL;
	END;
	
	IF gKknbillShurui IS NOT NULL AND gKknbillShurui <> inKknbillShurui THEN
		UPDATE KIKIN_IDO SET
			KKNBILL_SHURUI = inKknbillShurui
		WHERE ITAKU_KAISHA_CD = inItakuKaishaCd
		AND   MGR_CD          = inMgrCd
		AND   RBR_KJT         = inRbrKjt
		AND   IDO_YMD         = inIdoYmd
		AND   KKN_IDO_KBN     = inKknIdoKbn;
	END IF;
END $updateData$;

/**
	* 更新前データ削除
	*
	* @param inItakuKaishaCd  委託会社コード
	* @param inMgrCd          銘柄コード
	* @param inRbrKjt         利払期日
	* @param inDataSakuseiKbn データ作成区分
	* @param inEbMakeYmd      ＥＢ作成年月日
	*/
CREATE OR REPLACE PROCEDURE sfinskikinido_deleteData(
	inItakuKaishaCd  IN KIKIN_IDO.ITAKU_KAISHA_CD%TYPE,
	inMgrCd          IN KIKIN_IDO.MGR_CD%TYPE,
	inRbrKjt         IN KIKIN_IDO.RBR_KJT%TYPE,
	inChokyuYmd      IN KIKIN_IDO.RBR_YMD%TYPE,
	inDataSakuseiKbn IN KIKIN_IDO.DATA_SAKUSEI_KBN%TYPE DEFAULT ' ',
	inEbMakeYmd      IN KIKIN_IDO.EB_MAKE_YMD%TYPE DEFAULT ' '
)
LANGUAGE PLPGSQL
AS
$deleteData$
--		pCnt numeric DEFAULT 0;
BEGIN
	DELETE FROM KIKIN_IDO
	WHERE ITAKU_KAISHA_CD  =  inItakuKaishaCd
	AND   MGR_CD           =  inMgrCd
	AND   RBR_KJT          =  inRbrKjt
	AND   IDO_YMD          =  inChokyuYmd
	AND   DATA_SAKUSEI_KBN <= inDataSakuseiKbn
	AND   EB_MAKE_YMD      =  inEbMakeYmd
	AND   KKN_IDO_KBN      IN ('11','12','13','21','22','23')
	AND   RBR_YMD > pkDate.getGyomuYmd()
	AND   NYUKIN_STS_KBN <> '1'  --入金確認済みは更新しないので削除対象外にする
	AND (ITAKU_KAISHA_CD, MGR_CD) NOT IN (SELECT MG1.ITAKU_KAISHA_CD, MG1.MGR_CD
													FROM MGR_KIHON MG1
													WHERE MG1.ITAKU_KAISHA_CD = ITAKU_KAISHA_CD
													AND MG1.MGR_CD = MGR_CD
													AND MG1.KK_KANYO_FLG = '2');   -- 実質記番号管理銘柄は別管理のためここでは削除しない。
END $deleteData$;

/**
	* 入金済み確認
	*
	* @param inItakuKaishaCd    委託会社コード
	* @param inMgrCd            銘柄コード
	* @param inRbrKjt           利払期日
	* @param inIdoYmd           異動年月日
	* @param inKknIdoKbn        基金異動区分
	* @param inKkmemberFsKbn    金融証券区分(機構加入者)
	* @param inKkmemberBcd      金融機関コード(機構加入者)
	* @param inKkmemberKkbn     口座区分(機構加入者)
	*/
CREATE OR REPLACE FUNCTION sfinskikinido_checkNyukinZumi(
	inItakuKaishaCd    IN KIKIN_IDO.ITAKU_KAISHA_CD%TYPE,
	inMgrCd            IN KIKIN_IDO.MGR_CD%TYPE,
	inRbrKjt           IN KIKIN_IDO.RBR_KJT%TYPE,
	inIdoYmd           IN KIKIN_IDO.IDO_YMD%TYPE,
	inKknIdoKbn        IN KIKIN_IDO.KKN_IDO_KBN%TYPE,
	inKkmemberFsKbn    IN KIKIN_IDO.KKMEMBER_FS_KBN%TYPE DEFAULT ' ',
	inKkmemberBcd      IN KIKIN_IDO.KKMEMBER_BCD%TYPE DEFAULT ' ',
	inKkmemberKkbn     IN KIKIN_IDO.KKMEMBER_KKBN%TYPE DEFAULT ' '
)
RETURNS CHAR
LANGUAGE PLPGSQL
AS
$checkNyukinZumi$
DECLARE
	pNyukinStsKbn CHAR(1) DEFAULT '0';
BEGIN

	-- 基金異動の入金ステータス区分を返す
	SELECT
		NYUKIN_STS_KBN
	INTO STRICT
		pNyukinStsKbn
	FROM
		KIKIN_IDO
	WHERE
		ITAKU_KAISHA_CD	= inItakuKaishaCd
	AND	MGR_CD			= inMgrCd
	AND	RBR_KJT			= inRbrKjt
	AND	IDO_YMD			= inIdoYmd
	AND	KKN_IDO_KBN		= inKknIdoKbn
	AND	KKMEMBER_FS_KBN	= inKkmemberFsKbn
	AND	KKMEMBER_BCD	= inKkmemberBcd
	AND	KKMEMBER_KKBN	= inKkmemberKkbn;

	RETURN pNyukinStsKbn;

EXCEPTION
	WHEN OTHERS THEN
		-- 承認済みの入金確認済みでない場合は、更新可能なので0を返す
		RETURN '0';

END $checkNyukinZumi$;

/**
	* 利金・支払手数料計算
	*
	* @param inUserId           ユーザID
	* @param inItakuKaishaCd    委託会社コード
	* @param inMgrCd            銘柄コード
	* @param inRbrKjt           利払期日
	* @param inChokyuYmd        徴求日
	* @param inDataSakuseiKbn   データ作成区分
	* @param inRealBatchKbn     リアル・バッチ区分
	* @param inKknZndkKjnYmdKbn 基金残高基準日区分
	*/
CREATE OR REPLACE PROCEDURE sfinskikinido_calcRikinTesuryo(
	inUserId           IN SUSER.USER_ID%TYPE,
	inItakuKaishaCd    IN KIKIN_IDO.ITAKU_KAISHA_CD%TYPE,
	inMgrCd            IN KIKIN_IDO.MGR_CD%TYPE,
	inRbrKjt           IN KIKIN_IDO.RBR_KJT%TYPE,
	inChokyuYmd        IN MGR_RBRKIJ.KKN_CHOKYU_YMD%TYPE,
	inDataSakuseiKbn   IN KIKIN_IDO.DATA_SAKUSEI_KBN%TYPE,
	inRealBatchKbn     IN VARCHAR,
	inKknZndkKjnYmdKbn IN VARCHAR,
	c_shonin		   IN MGR_STS.MGR_STAT_KBN%TYPE,
	c_NOT_MASSHO	   IN MGR_STS.MASSHO_FLG%TYPE,
	pHeizonSeikyuKbn   IN VJIKO_ITAKU.HEIZON_SEIKYU_KBN%TYPE,
	pShzKijunProcess   IN MPROCESS_CTL.CTL_VALUE%TYPE,
	pSzeiprocess	   IN MPROCESS_CTL.CTL_VALUE%TYPE,
	gRtnCd			   OUT INTEGER
)
LANGUAGE PLPGSQL
AS
$calcRikinTesuryo$
DECLARE
	pIdoYmd            KIKIN_IDO.IDO_YMD%TYPE;                   -- 異動年月日
	pKknIdoKbn         KIKIN_IDO.KKN_IDO_KBN%TYPE;               -- 基金異動区分
	pKknNyukinKngk     KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE;           -- 基金入金額
	pHakkoYmd          MGR_KIHON.HAKKO_YMD%TYPE;                 -- 発行日
	pKknZndkKakuteiKbn MGR_KIHON.KKN_ZNDK_KAKUTEI_KBN%TYPE;      -- 基金残高確定区分
	pRbrTsukaCd        MGR_KIHON.RBR_TSUKA_CD%TYPE;              -- 利払通貨
	pHakkoTsukaCd      MGR_KIHON.HAKKO_TSUKA_CD%TYPE;            -- 発行通貨(元金ベースで使用)
	pRbrYmd            MGR_RBRKIJ.RBR_YMD%TYPE;                  -- 利払日
	pKknChokyuYmd      MGR_RBRKIJ.KKN_CHOKYU_YMD%TYPE;           -- 基金徴求日
	pTesuChokyuYmd     MGR_RBRKIJ.TESU_CHOKYU_YMD%TYPE;          -- 手数料徴求日
	pTsukarishiKngk    MGR_RBRKIJ.TSUKARISHI_KNGK%TYPE;          -- １通貨あたりの利子金額
	pRknShrTesuBunshi  MGR_TESURYO_PRM.RKN_SHR_TESU_BUNSHI%TYPE; -- 利金支払手数料率（分子）
	pRknShrTesuBunbo   MGR_TESURYO_PRM.RKN_SHR_TESU_BUNBO%TYPE;  -- 利金支払手数料率（分母）
	pSzeiSeikyuKbn     MGR_TESURYO_PRM.SZEI_SEIKYU_KBN%TYPE;     -- 消費税請求区分
	pZndkKijunYmd      KIKIN_IDO.ZNDK_KIJUN_YMD%TYPE;            -- 残高基準日
	pKijunZndk         numeric DEFAULT 0;                         -- 基準残高
	pZeikomiTesuryo    numeric DEFAULT 0;                         -- 税込手数料
	pZeinukiTesuryo    numeric DEFAULT 0;                         -- 税抜手数料
	pZei               numeric DEFAULT 0;                         -- 消費税
	pLastTeiseiDt      KIKIN_IDO.LAST_TEISEI_DT%TYPE;            -- 最終更新日時
	pEbSendYmd         KIKIN_IDO.EB_SEND_YMD%TYPE;               -- ＥＢ送信年月日
	pTesuShuruiCd      MGR_TESURYO_CTL.TESU_SHURUI_CD%TYPE;      -- 手数料種類コード
	pKijunZndkGnt      numeric DEFAULT 0;                         -- 基準残高(現登債分)
	pWkCalcKngk        numeric DEFAULT 0;                         -- ワーク算出額
	pTsukaCd           KIKIN_IDO.TSUKA_CD%TYPE;                  -- 利払通貨or発行通貨
	pKknbillOutYmd     MGR_RBRKIJ.KKNBILL_OUT_YMD%TYPE;          -- 基金請求書出力日
	pShzKijunYmd       varchar(8);                              -- 消費税率適用基準日

	rec				   record;
BEGIN
	BEGIN
		-- 利払回次データ検索
		SELECT
			MG1.HAKKO_YMD,
			CASE WHEN MG1.JTK_KBN='5' THEN '9'  ELSE MG1.KKN_ZNDK_KAKUTEI_KBN END  AS KKN_ZNDK_KAKUTEI_KBN,	-- 自社発行は強制で「請求書出力時点」をセット
			MG1.RBR_TSUKA_CD AS TSUKA_CD,
			MG1.HAKKO_TSUKA_CD AS HAKKO_TSUKA_CD,
			MG2.RBR_YMD,
			CASE WHEN MG1.JTK_KBN='5' THEN MG2.RBR_YMD  ELSE MG2.KKN_CHOKYU_YMD END  AS KKN_CHOKYU_YMD,		-- 自社発行は基金徴求日に利払日をセット
			CASE WHEN MG1.JTK_KBN='5' THEN MG2.RBR_YMD  ELSE MG2.TESU_CHOKYU_YMD END  AS TESU_CHOKYU_YMD,		-- 自社発行は手数料徴求日に利払日をセット
			MG2.TSUKARISHI_KNGK,
			MG8.RKN_SHR_TESU_BUNSHI,
			MG8.RKN_SHR_TESU_BUNBO,
			MG8.SZEI_SEIKYU_KBN,
			MG7.TESU_SHURUI_CD,
			MG2.KKNBILL_OUT_YMD
		INTO STRICT
			pHakkoYmd,
			pKknZndkKakuteiKbn,
			pRbrTsukaCd,
			pHakkoTsukaCd,
			pRbrYmd,
			pKknChokyuYmd,
			pTesuChokyuYmd,
			pTsukarishiKngk,
			pRknShrTesuBunshi,
			pRknShrTesuBunbo,
			pSzeiSeikyuKbn,
			pTesuShuruiCd,
			pKknbillOutYmd
		FROM
			MGR_STS         MG0,
			MGR_KIHON       MG1,
			MGR_RBRKIJ      MG2,
			MGR_TESURYO_PRM MG8,
			MGR_TESURYO_CTL MG7
		WHERE MG0.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
		AND   MG0.MGR_CD          = MG1.MGR_CD
		AND   MG0.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD
		AND   MG0.MGR_CD          = MG2.MGR_CD
		AND   MG0.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD
		AND   MG0.MGR_CD          = MG8.MGR_CD
		AND   MG0.ITAKU_KAISHA_CD = inItakuKaishaCd
		AND   MG0.MGR_CD          = inMgrCd
		AND   MG0.MGR_STAT_KBN    = c_SHONIN
		AND   MG0.MASSHO_FLG      = c_NOT_MASSHO
		AND   MG2.RBR_KJT         = inRbrKjt
		-- 自社発行以外は基金徴求日または手数料徴求日と、自社発行は利払日と比較
		AND   (((MG2.KKN_CHOKYU_YMD  = inChokyuYmd OR MG2.TESU_CHOKYU_YMD  = inChokyuYmd) AND MG1.JTK_KBN <> '5')
				OR (MG2.RBR_YMD = inChokyuYmd AND MG1.JTK_KBN = '5'))
		AND   MG0.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD
		AND   MG0.MGR_CD = MG7.MGR_CD
		-- 元金ベースも利金ベースも選択されていないときは利金ベースを決め打ちで取得する
		AND   MG7.TESU_SHURUI_CD = (SELECT CASE WHEN MG761.CHOOSE_FLG='1' THEN 														MG761.TESU_SHURUI_CD  ELSE MG782.TESU_SHURUI_CD END
									FROM MGR_TESURYO_CTL MG761, MGR_TESURYO_CTL MG782
									WHERE MG761.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
									AND MG782.ITAKU_KAISHA_CD = MG0.ITAKU_KAISHA_CD
									AND MG761.MGR_CD = MG0.MGR_CD
									AND MG782.MGR_CD = MG0.MGR_CD
									AND MG761.TESU_SHURUI_CD = '61'
									AND MG782.TESU_SHURUI_CD = '82')
		AND   MG1.KK_KANYO_FLG != '2';   -- 実質記番号管理方式は抽出対象外
	EXCEPTION
		WHEN no_data_found THEN
			pKknChokyuYmd  := ' ';
			pTesuChokyuYmd := ' ';
	END;

	BEGIN

	-- RAISE NOTICE '利金（MG2.基金徴求日 = パラメータ.徴求日）';

	-- 利金（MG2.基金徴求日 = パラメータ.徴求日）
	IF pKknChokyuYmd = inChokyuYmd AND nullif(trim(both pKknChokyuYmd), '') IS NOT NULL THEN
		-- 異動年月日 ← MG2.基金徴求日
		pIdoYmd        := pKknChokyuYmd;
		-- 基金異動区分 ← 入金（利金）
		pKknIdoKbn     := '21';
		-- RAISE NOTICE '利金（MG2.基金徴求日 = パラメータ.徴求日）1';
		pZndkKijunYmd  := sfinskikinido_getZndkKijunYmd(inRealBatchKbn, inDataSakuseiKbn, pKknZndkKakuteiKbn, inRbrKjt, pHakkoYmd, pRbrYmd, inKknZndkKjnYmdKbn, pKknbillOutYmd, inItakuKaishaCd, inMgrCd);
		-- RAISE NOTICE '利金（MG2.基金徴求日 = パラメータ.徴求日）2';
		pKijunZndk     := pkIpaZndk.getKjnZndk(inItakuKaishaCd, inMgrCd, pZndkKijunYmd, 3)::numeric;
		-- RAISE NOTICE '利金（MG2.基金徴求日 = パラメータ.徴求日）3';
		pKijunZndkGnt  := pkIpaZndk.getKjnZndk(inItakuKaishaCd, inMgrCd, pZndkKijunYmd, 83)::numeric;
		-- RAISE NOTICE '利金（MG2.基金徴求日 = パラメータ.徴求日）3';
		-- 基金入金額 = 基準残高 * MG2.１通貨あたりの利子金額
		pWkCalcKngk    := pKijunZndk * pTsukarishiKngk;
		-- RAISE NOTICE '利金（MG2.基金徴求日 = パラメータ.徴求日）4';
		pKknNyukinKngk := sfinskikinido_getTruncKngk(pRbrTsukaCd, pWkCalcKngk);
		-- RAISE NOTICE '利金（MG2.基金徴求日 = パラメータ.徴求日）5';
		pEbSendYmd     := sfinskikinido_getEbSendYmd(inItakuKaishaCd, pKknChokyuYmd);
		-- RAISE NOTICE '利金（MG2.基金徴求日 = パラメータ.徴求日）6';
		pLastTeiseiDt  := TO_TIMESTAMP(pkDate.getCurrentTime(), 'yyyy-mm-dd HH24:MI:SS.FF6');

		-- RAISE NOTICE '利金（MG2.基金徴求日 = パラメータ.徴求日）7';
		-- 基金入金額=0、実質残高(振替債分)=0 は対象外
		IF pKknNyukinKngk <> 0 AND pKijunZndk > 0 THEN
			-- 併存銘柄かつ併存銘柄請求書出力区分＝０は対象外
			IF pKijunZndkGnt <= 0 OR pHeizonSeikyuKbn != '0' THEN
				-- 入金確認済みの場合は、レコードを更新しない
				-- RAISE NOTICE '利金（MG2.基金徴求日 = パラメータ.徴求日）8';
				IF sfinskikinido_checkNyukinZumi(inItakuKaishaCd,inMgrCd,inRbrKjt,pIdoYmd,pKknIdoKbn,' ',' ',' ') <> '1' THEN
					-- RAISE NOTICE '利金（MG2.基金徴求日 = パラメータ.徴求日）9';
					CALL sfinskikinido_insertData(
						inItakuKaishaCd  => inItakuKaishaCd,
						inMgrCd          => inMgrCd,
						inRbrKjt         => inRbrKjt,
						inRbrYmd         => pRbrYmd,
						inTsukaCd        => pRbrTsukaCd,
						inIdoYmd         => pIdoYmd,
						inKknIdoKbn      => pKknIdoKbn,
						inKknNyukinKngk  => pKknNyukinKngk,
						inDataSakuseiKbn => inDataSakuseiKbn,
						inZndkKijunYmd   => pZndkKijunYmd,
						inKijunZndk      => pKijunZndk::bigint,
						inEbSendYmd      => pEbSendYmd,
						inShoriKbn       => '0'::char,
						inLastTeiseiDt   => pLastTeiseiDt,
						inLastTeiseiId   => inUserId,
						inKousinId       => inUserId,
						inSakuseiId      => inUserId
					);
				END IF;
			END IF;
		END IF;
	END IF;

	-- RAISE NOTICE 'end 利金支払手数料（MG2.手数料徴求日 = パラメータ.徴求日）';

	-- 利金支払手数料（MG2.手数料徴求日 = パラメータ.徴求日）
	IF pTesuChokyuYmd = inChokyuYmd AND nullif(trim(both pTesuChokyuYmd), '') IS NOT NULL THEN
		-- RAISE NOTICE '利金支払手数料の算出および基金異動履歴tblへの登録は、利金支払手数料が選択されていて、手数料率分母が登録されている銘柄のみ行う。';

		-- 利金支払手数料の算出および基金異動履歴tblへの登録は、利金支払手数料が選択されていて、手数料率分母が登録されている銘柄のみ行う。
		IF pRknShrTesuBunbo > 0 THEN

			-- 消費税率適用基準日切り替え
			IF pShzKijunProcess = '1' THEN
				pShzKijunYmd := pRbrYmd;
			ELSE
				pShzKijunYmd := inChokyuYmd;
			END IF;

			-- 異動年月日 ← MG2.手数料徴求日
			pIdoYmd        := pTesuChokyuYmd;
			-- 基金異動区分 ← 入金（利金支払手数料）
			pKknIdoKbn     := '22';
			/***********************************************************************************
			* IP-05813
			* 基金残高確定区分が請求書出力時点の場合、
			* 基金・利金支払手数料・元金支払手数料の請求書出力タイミングは同じであるべきなので
			* 便宜上、利金支払手数料に関しても基金請求書出力日を使用する。
			***********************************************************************************/

			pZndkKijunYmd  := sfinskikinido_getZndkKijunYmd(inRealBatchKbn, inDataSakuseiKbn, pKknZndkKakuteiKbn, inRbrKjt, pHakkoYmd, pRbrYmd, inKknZndkKjnYmdKbn, pKknbillOutYmd, inItakuKaishaCd, inMgrCd);

			pKijunZndk     := pkIpaZndk.getKjnZndk(inItakuKaishaCd, inMgrCd, pZndkKijunYmd, 3)::numeric;
			pKijunZndkGnt  := pkIpaZndk.getKjnZndk(inItakuKaishaCd, inMgrCd, pZndkKijunYmd, 83)::numeric;
			-- RAISE NOTICE '基金入金額 = 基準残高 * MG2.１通貨あたりの利子金額 1';
			-- 基金入金額 = 基準残高 * MG2.１通貨あたりの利子金額
			pWkCalcKngk    := pKijunZndk * pTsukarishiKngk;
			-- RAISE NOTICE '基金入金額 = 基準残高 * MG2.１通貨あたりの利子金額 2';
			pKknNyukinKngk := sfinskikinido_getTruncKngk(pRbrTsukaCd, pWkCalcKngk);
			-- RAISE NOTICE '基金入金額 = 基準残高 * MG2.１通貨あたりの利子金額 3';

			IF pTesuShuruiCd = '82' THEN
				-- 利金ベース（※計算根拠は基金入金金額）
				-- 手数料・消費税を計算
				-- RAISE NOTICE 'calling pkipacalctesukngk.gettesuzeicommon';
				select * into pZeinukiTesuryo, pZeikomiTesuryo, pZei, gRtnCd from PKIPACALCTESUKNGK.getTesuZeiCommon(	inItakuKaishaCd,	-- 委託会社コード
																inMgrCd,			-- 銘柄コード
																pKknNyukinKngk,		-- 手数料算出の基準となる額面
																pRknShrTesuBunshi,	-- 手数料率分子
																pRknShrTesuBunbo::numeric,	-- 手数料率分母
																pRbrTsukaCd,		-- 通貨コード（利払通貨）
																pShzKijunYmd,		-- 消費税の適用基準年月日
																pSzeiProcess --,		-- 消費税算出方法(1：従来方式、2：総額方式)
																--pZeinukiTesuryo,	-- (戻)税抜手数料金額
																--pZeikomiTesuryo,	-- (戻)税込手数料金額
																--pZei				-- (戻)消費税金額
																);

				pTsukaCd := pRbrTsukaCd;	--登録用通貨コード
				-- RAISE NOTICE 'pkipacalctesukngk.gettesuzeicommon complegted';
				IF gRtnCd <> PKCONSTANT.SUCCESS() THEN
					RAISE EXCEPTION 'tesu_calc_error' USING ERRCODE = '50008';
				END IF;
			ELSIF pKknNyukinKngk <> 0 OR (pKknNyukinKngk = 0 AND sfRkntesGb_CalcChk(inItakukaishaCd, inMgrCd, inRbrKjt) = 1) THEN
				-- 元金ベース（※計算根拠は基準残高）
				-- 手数料・消費税を計算
				select * into pZeinukiTesuryo, pZeikomiTesuryo, pZei, gRtnCd from PKIPACALCTESUKNGK.getTesuZeiCommon(	inItakuKaishaCd,	-- 委託会社コード
																inMgrCd,			-- 銘柄コード
																pKijunZndk,			-- 手数料算出の基準となる額面
																pRknShrTesuBunshi,	-- 手数料率分子
																pRknShrTesuBunbo::numeric,	-- 手数料率分母
																pHakkoTsukaCd,		-- 通貨コード（発行通貨）
																pShzKijunYmd,		-- 消費税の適用基準年月日
																pSzeiProcess --,		-- 消費税算出方法(1：従来方式、2：総額方式)
																--pZeinukiTesuryo,	-- (戻)税抜手数料金額
																--pZeikomiTesuryo,	-- (戻)税込手数料金額
																--pZei				-- (戻)消費税金額
																);

				pTsukaCd := pHakkoTsukaCd;	--登録用通貨コード
				IF gRtnCd <> PKCONSTANT.SUCCESS() THEN
					RAISE EXCEPTION 'tesu_calc_error' USING ERRCODE = '50008';
				END IF;
			END IF;

			-- RAISE NOTICE '基金入金額 = 税抜手数料 1';

			-- 基金入金額 = 税抜手数料
			pKknNyukinKngk := pZeinukiTesuryo;
			pEbSendYmd := sfinskikinido_getEbSendYmd(inItakuKaishaCd, pTesuChokyuYmd);

			-- RAISE NOTICE '基金入金額=0、実質残高(振替債分)=0 は対象外';

			-- 基金入金額=0、実質残高(振替債分)=0 は対象外
			IF pKknNyukinKngk <> 0 AND pKijunZndk > 0 THEN
				-- 併存銘柄かつ併存銘柄請求書出力区分＝０は対象外
				IF pKijunZndkGnt <= 0 OR pHeizonSeikyuKbn != '0' THEN
					-- 入金確認済みの場合は、レコードを更新しない
					IF sfinskikinido_checkNyukinZumi(inItakuKaishaCd,inMgrCd,inRbrKjt,pIdoYmd,pKknIdoKbn,' ',' ',' ') <> '1' THEN
						-- RAISE NOTICE 'calling sfinskikinido_insertData 1';

						CALL sfinskikinido_insertData(
							inItakuKaishaCd  => inItakuKaishaCd,
							inMgrCd          => inMgrCd,
							inRbrKjt         => inRbrKjt,
							inRbrYmd         => pRbrYmd,
							inTsukaCd        => pTsukaCd,
							inIdoYmd         => pIdoYmd,
							inKknIdoKbn      => pKknIdoKbn,
							inKknNyukinKngk  => pKknNyukinKngk,
							inDataSakuseiKbn => inDataSakuseiKbn,
							inZndkKijunYmd   => pZndkKijunYmd,
							inKijunZndk      => pKijunZndk::bigint,
							inEbSendYmd      => pEbSendYmd,
							inShoriKbn       => '0'::char,
							inLastTeiseiDt   => pLastTeiseiDt,
							inLastTeiseiId   => inUserId,
							inKousinId       => inUserId,
							inSakuseiId      => inUserId
						);
					END IF;

					-- 利金支払手数料消費税
					-- 異動年月日 ← MG2.手数料徴求日
					pIdoYmd        := pTesuChokyuYmd;
					-- 基金異動区分 ← 入金（利金支払手数料消費税）
					pKknIdoKbn     := '23';
					-- 基金入金額 = 手数料消費税
					pKknNyukinKngk := pZei;

					IF pKknNyukinKngk <> 0 THEN
						-- 入金確認済みの場合は、レコードを更新しない
						IF sfinskikinido_checkNyukinZumi(inItakuKaishaCd,inMgrCd,inRbrKjt,pIdoYmd,pKknIdoKbn,' ',' ',' ') <> '1' THEN
							-- RAISE NOTICE 'calling sfinskikinido_insertData 2';

							CALL sfinskikinido_insertData(
								inItakuKaishaCd  => inItakuKaishaCd,
								inMgrCd          => inMgrCd,
								inRbrKjt         => inRbrKjt,
								inRbrYmd         => pRbrYmd,
								inTsukaCd        => pTsukaCd,
								inIdoYmd         => pIdoYmd,
								inKknIdoKbn      => pKknIdoKbn,
								inKknNyukinKngk  => pKknNyukinKngk,
								inDataSakuseiKbn => inDataSakuseiKbn,
								inZndkKijunYmd   => pZndkKijunYmd,
								inKijunZndk      => pKijunZndk::bigint,
								inEbSendYmd      => pEbSendYmd,
								inShoriKbn       => '0'::char,
								inLastTeiseiDt   => pLastTeiseiDt,
								inLastTeiseiId   => inUserId,
								inKousinId       => inUserId,
								inSakuseiId      => inUserId
							);
						END IF;
					END IF;
				END IF;
			END IF;
		END IF;
	END IF;

	-- RAISE NOTICE 'sfinskikinido_calcRikinTesuryo completed';

	RETURN;

	EXCEPTION
		WHEN SQLSTATE '50015' THEN
		RAISE;
	END;
END $calcRikinTesuryo$;

/**
	* 元金・支払手数料計算
	*
	* @param inUserId           ユーザID
	* @param inItakuKaishaCd    委託会社コード
	* @param inMgrCd            銘柄コード
	* @param inRbrKjt           利払期日（償還期日）
	* @param inChokyuYmd        徴求日
	* @param inDataSakuseiKbn   データ作成区分
	* @param inRealBatchKbn     リアル・バッチ区分
	* @param inKknZndkKjnYmdKbn 基金残高基準日区分
	*/
CREATE OR REPLACE PROCEDURE sfinskikinido_calcGankinTesuryo(
	inUserId           IN SUSER.USER_ID%TYPE,
	inItakuKaishaCd    IN KIKIN_IDO.ITAKU_KAISHA_CD%TYPE,
	inMgrCd            IN KIKIN_IDO.MGR_CD%TYPE,
	inRbrKjt           IN KIKIN_IDO.RBR_KJT%TYPE,
	inChokyuYmd        IN MGR_SHOKIJ.KKN_CHOKYU_YMD%TYPE,
	inDataSakuseiKbn   IN KIKIN_IDO.DATA_SAKUSEI_KBN%TYPE,
	inRealBatchKbn     IN varchar,
	inKknZndkKjnYmdKbn IN varchar,
	c_shonin		   IN MGR_STS.MGR_STAT_KBN%TYPE,
	c_NOT_MASSHO	   IN MGR_STS.MASSHO_FLG%TYPE,
	pHeizonSeikyuKbn   IN VJIKO_ITAKU.HEIZON_SEIKYU_KBN%TYPE,
	pShzKijunProcess   IN MPROCESS_CTL.CTL_VALUE%TYPE,
	pSzeiprocess	   IN MPROCESS_CTL.CTL_VALUE%TYPE,
	pTesuCapProcess	   IN MPROCESS_CTL.CTL_VALUE%TYPE,
	gRtnCd			   OUT INTEGER
)
LANGUAGE PLPGSQL
AS
$calcGankinTesuryo$
DECLARE
	pIdoYmd            KIKIN_IDO.IDO_YMD%TYPE;                    -- 異動年月日
	pKknIdoKbn         KIKIN_IDO.KKN_IDO_KBN%TYPE;                -- 基金異動区分
	pKknNyukinKngk     KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE;            -- 基金入金額
	pHakkoYmd          MGR_KIHON.HAKKO_YMD%TYPE;                  -- 発行日
	pJikoTotalHkukKbn  MGR_KIHON.JIKO_TOTAL_HKUK_KBN%TYPE;		  -- 自行総額引受区分
	pKkKanyoFlg		   MGR_KIHON.KK_KANYO_FLG%TYPE;				  -- 機構関与方式採用フラグ
	pKknZndkKakuteiKbn MGR_KIHON.KKN_ZNDK_KAKUTEI_KBN%TYPE;       -- 基金残高確定区分
	pShokanTsukaCd     MGR_KIHON.SHOKAN_TSUKA_CD%TYPE;            -- 償還通貨
	pShokanYmd         MGR_SHOKIJ.SHOKAN_YMD%TYPE;                -- 償還年月日
	pMunitSknShrKngk   MGR_SHOKIJ.MUNIT_SKN_SHR_KNGK%TYPE default 0;        -- 銘柄単位償還支払金額（銘柄単位合計）
	wMunitSknShrKngk   MGR_SHOKIJ.MUNIT_SKN_SHR_KNGK%TYPE default 0;        -- 銘柄単位償還支払金額
	pMunitSknPremium   MGR_SHOKIJ.MUNIT_SKN_PREMIUM%TYPE default 0;         -- 銘柄単位償還プレミアム
	pFactor            MGR_SHOKIJ.FACTOR%TYPE;                    -- ファクター（残高基準日時点）
	wFactor            MGR_SHOKIJ.FACTOR%TYPE;                    -- ファクター（残高基準日時点算出用ワーク）
	pMeimokuKngk       MGR_SHOKIJ.MUNIT_GENSAI_KNGK%TYPE;         -- プット減債名目金額
	wMeimokuKngk       MGR_SHOKIJ.MUNIT_GENSAI_KNGK%TYPE;         -- 減債名目金額（ワーク）
	pKknChokyuYmd      MGR_SHOKIJ.KKN_CHOKYU_YMD%TYPE;            -- 基金徴求日
	pTesuChokyuYmd     MGR_SHOKIJ.TESU_CHOKYU_YMD%TYPE;           -- 手数料徴求日
	pGnknShrTesuBunshi MGR_TESURYO_PRM.GNKN_SHR_TESU_BUNSHI%TYPE; -- 元金支払手数料率（分子）
	pGnknShrTesuBunbo  MGR_TESURYO_PRM.GNKN_SHR_TESU_BUNBO%TYPE;  -- 元金支払手数料率（分母）
	pGnknShrTesuCap	   MGR_TESURYO_PRM.GNKN_SHR_TESU_CAP%TYPE;	  -- 元金支払手数料ＣＡＰ
	pSzeiSeikyuKbn     MGR_TESURYO_PRM.SZEI_SEIKYU_KBN%TYPE;      -- 消費税請求区分
	pZndkKijunYmd      varchar(8);                               -- 残高基準日
	pKijunZndk         numeric DEFAULT 0;                          -- 基準残高
	pKijunZndkGnt      numeric DEFAULT 0;                          -- 基準残高(現登債分)
	pZeikomiTesuryo    numeric DEFAULT 0;                          -- 税込手数料
	pZeinukiTesuryo    numeric DEFAULT 0;                          -- 税抜手数料
	pZei               numeric DEFAULT 0;                          -- 消費税
	pLastTeiseiDt      KIKIN_IDO.LAST_TEISEI_DT%TYPE;             -- 最終更新日時
	pEbSendYmd         KIKIN_IDO.EB_SEND_YMD%TYPE;                -- ＥＢ送信年月日
	pGnknTesuChooseFlg MGR_TESURYO_CTL.CHOOSE_FLG%TYPE;            -- 元金支払手数料選択フラグ（0:非選択／1:選択）
	pCapZeinukiGaku		numeric DEFAULT 0;							-- ＣＡＰ税抜金額
	pCapZeikomiGaku		numeric DEFAULT 0;							-- ＣＡＰ税込金額
	pCapZei				numeric DEFAULT 0;							-- ＣＡＰ税金額
	pTesuryoCapFlg		varchar(2);								-- 元金支払手数料ＣＡＰ採用フラグ
																	-- ("X":CAP 採用, " ":CAP 未採用)
	pKknBillOutYmd		MGR_SHOKIJ.KKNBILL_OUT_YMD%TYPE;			-- 基金請求書出力日
	pShzKijunYmd		varchar(8);								-- 消費税率適用基準日

	rec					record;

	CUR_SHOKIJ CURSOR FOR
		-- 償還回次データ検索
		SELECT
			MG1.HAKKO_YMD,
			MG1.KAKUSHASAI_KNGK,
			MG1.JIKO_TOTAL_HKUK_KBN,
			MG1.KK_KANYO_FLG,
			CASE WHEN MG1.JTK_KBN='5' THEN '9'  ELSE MG1.KKN_ZNDK_KAKUTEI_KBN END  AS KKN_ZNDK_KAKUTEI_KBN,	-- 自社発行は強制で「請求書出力時点」をセット
			MG1.HAKKO_TSUKA_CD,
			MG1.SHOKAN_TSUKA_CD,
			MG1.KAWASE_RATE,
			MG1.SHOKAN_METHOD_CD,
			MG3.SHOKAN_YMD,
			MG3.SHOKAN_KBN,
			CASE WHEN MG1.JTK_KBN='5' THEN MG3.SHOKAN_YMD  ELSE MG3.KKN_CHOKYU_YMD END  AS KKN_CHOKYU_YMD,	-- 自社発行は基金徴求日に償還日をセット
			CASE WHEN MG1.JTK_KBN='5' THEN MG3.SHOKAN_YMD  ELSE MG3.TESU_CHOKYU_YMD END  AS TESU_CHOKYU_YMD,	-- 自社発行は手数料徴求日に償還日をセット
			MG3.MUNIT_GENSAI_KNGK,
			MG3.FUNIT_GENSAI_KNGK,
			MG3.FUNIT_SKN_PREMIUM,
			MG3.FACTOR,
			MG8.GNKN_SHR_TESU_BUNSHI,
			MG8.GNKN_SHR_TESU_BUNBO,
			MG8.GNKN_SHR_TESU_CAP,
			MG8.SZEI_SEIKYU_KBN,
			MG7.CHOOSE_FLG,
			MG3.KKNBILL_OUT_YMD
		FROM
			MGR_STS         MG0,
			MGR_KIHON       MG1,
			MGR_SHOKIJ      MG3,
			MGR_TESURYO_PRM MG8,
			MGR_TESURYO_CTL MG7,
			(SELECT CODE_VALUE, CODE_NM, CODE_SORT FROM SCODE WHERE CODE_SHUBETSU = '714') SC01
		WHERE MG0.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
		AND   MG0.MGR_CD          = MG1.MGR_CD
		AND   MG0.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD
		AND   MG0.MGR_CD          = MG3.MGR_CD
		AND   MG0.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD
		AND   MG0.MGR_CD          = MG8.MGR_CD
		AND   MG3.SHOKAN_KBN      = SC01.CODE_VALUE
		AND   MG0.ITAKU_KAISHA_CD = inItakuKaishaCd
		AND   MG0.MGR_CD          = inMgrCd
		AND   MG0.MGR_STAT_KBN    = c_SHONIN
		AND   MG0.MASSHO_FLG      = c_NOT_MASSHO
		AND   MG3.SHOKAN_KJT      = inRbrKjt
		-- 自社発行以外は基金徴求日または手数料徴求日と、自社発行は償還日と比較
		AND   (((MG3.KKN_CHOKYU_YMD = inChokyuYmd OR MG3.TESU_CHOKYU_YMD = inChokyuYmd) AND MG1.JTK_KBN <> '5')
				OR (MG3.SHOKAN_YMD = inChokyuYmd AND MG1.JTK_KBN = '5'))
		AND   MG3.SHOKAN_KBN  <> '30'
		AND   MG0.ITAKU_KAISHA_CD = MG7.ITAKU_KAISHA_CD
		AND   MG0.MGR_CD = MG7.MGR_CD
		AND   MG7.TESU_SHURUI_CD = '81'
		AND	  MG1.KK_KANYO_FLG != '2'		-- 実質記番号管理方式は抽出対象外
		ORDER BY
			MG0.ITAKU_KAISHA_CD,
			MG0.MGR_CD,
			SC01.CODE_SORT;
BEGIN
	-- RAISE NOTICE 'in sfinskikinido_calcGankinTesuryo';

	-- 銘柄単位償還支払金額を求める
	FOR rec IN CUR_SHOKIJ LOOP
		pHakkoYmd := rec.HAKKO_YMD;
		pJikoTotalHkukKbn := rec.JIKO_TOTAL_HKUK_KBN;
		pKkKanyoFlg := rec.KK_KANYO_FLG;
		pKknZndkKakuteiKbn := rec.KKN_ZNDK_KAKUTEI_KBN;
		pShokanTsukaCd := rec.SHOKAN_TSUKA_CD;
		pShokanYmd := rec.SHOKAN_YMD;
		pKknChokyuYmd := rec.KKN_CHOKYU_YMD;
		pTesuChokyuYmd := rec.TESU_CHOKYU_YMD;
		pGnknShrTesuBunshi := rec.GNKN_SHR_TESU_BUNSHI;
		pGnknShrTesuBunbo := rec.GNKN_SHR_TESU_BUNBO;
		pGnknShrTesuCap := rec.GNKN_SHR_TESU_CAP;
		pSzeiSeikyuKbn := rec.SZEI_SEIKYU_KBN;
		pGnknTesuChooseFlg := rec.CHOOSE_FLG;
		pKknBillOutYmd := rec.KKNBILL_OUT_YMD;

		/***********************************************************************************
		* IP-05813
		* 基金残高確定区分が請求書出力時点の場合、
		* 基金・利金支払手数料・元金支払手数料の請求書出力タイミングは同じであるべきなので
		* 便宜上、元金支払手数料に関しても基金請求書出力日を使用する。
		***********************************************************************************/

		pZndkKijunYmd  := sfinskikinido_getZndkKijunYmd(inRealBatchKbn, inDataSakuseiKbn, pKknZndkKakuteiKbn, inRbrKjt, pHakkoYmd, pShokanYmd, inKknZndkKjnYmdKbn, pKknBillOutYmd, inItakuKaishaCd, inMgrCd);
		-- 残高基準日時点の名目残高 (振替債分のみ)
		pKijunZndk := sfinskikinido_getGnknKijunZndk(inItakuKaishaCd, inMgrCd, pZndkKijunYmd);
		-- 残高基準日時点のファクター
		-- RAISE NOTICE 'calling pkIpaZndk.getKjnZndk 残高基準日時点のファクター';

		pFactor    := pkIpaZndk.getKjnZndk(inItakuKaishaCd, inMgrCd, pZndkKijunYmd, 5)::numeric;

		-- RAISE NOTICE 'calling pkIpaZndk.getKjnZndk 残高基準日時点のファクター completed';
		-- RAISE NOTICE 'calling sfinskikinido_getGensai';

		call sfinskikinido_getGensai(inItakuKaishaCd, inMgrCd, rec.KAKUSHASAI_KNGK, rec.SHOKAN_YMD, rec.SHOKAN_KBN, wMeimokuKngk, wFactor);

		-- RAISE NOTICE 'calling sfinskikinido_getGensai com,pleted';

		-- 同一日分だけ基準日時点から減債する
		pKijunZndk := pKijunZndk - wMeimokuKngk;
		pFactor := pFactor - wFactor;

		-- プットとプット以外で計算基準となる項目が異なる
		IF rec.SHOKAN_KBN <> '50' THEN
			pMunitSknPremium := pkIpaKknIdo.getMunitSknPremium( pkIpaKknIdo.sfCheckLastKaiji(inItakuKaishaCd, inMgrCd, inRbrKjt, rec.SHOKAN_KBN),
																rec.KAKUSHASAI_KNGK,
																rec.SHOKAN_KBN,
																pFactor,
																pKijunZndk,
																rec.MUNIT_GENSAI_KNGK,
																rec.FUNIT_SKN_PREMIUM);
			wMunitSknShrKngk := pkIpaKknIdo.getMunitSknShrKngk( inItakuKaishaCd,
																inMgrCd,
																rec.KAKUSHASAI_KNGK,
																rec.HAKKO_TSUKA_CD,
																rec.SHOKAN_TSUKA_CD,
																rec.KAWASE_RATE,
																inRbrKjt,
																rec.SHOKAN_KBN,
																pFactor,
																pKijunZndk::bigint,
																rec.MUNIT_GENSAI_KNGK,
																rec.FUNIT_GENSAI_KNGK,
																pMunitSknPremium);
		ELSE
			-- 実質金額から名目金額を算出
			IF rec.Factor > 0 THEN
				-- 償還日時点でファクターがある場合
				pMeimokuKngk := rec.MUNIT_GENSAI_KNGK / rec.Factor;
			ELSE
				-- 償還日時点で全額償還の場合、直近の償還事由のファクターを使用する。
				pMeimokuKngk :=rec.MUNIT_GENSAI_KNGK /  (PKIPAZNDK.GETKJNZNDK(	inItakuKaishaCd,
																						inMgrCd,
																						rec.SHOKAN_YMD,
																						rec.SHOKAN_KBN,
																						5))::numeric;
			END IF;

			pMunitSknPremium := pkIpaKknIdo.getMunitSknPremium(
				pkIpaKknIdo.KAIJI_NOT_LAST(),  -- 償還事由プットだけで十分なので、最終回次ではないを固定で渡す
				rec.KAKUSHASAI_KNGK,
				pkIpaKknIdo.PUT(),
				pFactor,
				pMeimokuKngk,
				0,                          -- 計算に不要のため0を固定で渡す
				rec.FUNIT_SKN_PREMIUM
			);

			wMunitSknShrKngk := pkIpaKknIdo.getPutMunitSknShrKngk(
				rec.KAKUSHASAI_KNGK,
				rec.HAKKO_TSUKA_CD,
				rec.SHOKAN_TSUKA_CD,
				rec.KAWASE_RATE,
				pFactor,
				pMeimokuKngk,
				pMunitSknPremium
			);
		END IF;
		-- 同一日の償還額を合算する
		pMunitSknShrKngk := pMunitSknShrKngk + wMunitSknShrKngk;
	END LOOP;

	BEGIN
	-- RAISE NOTICE 'begin 元金（MG3.基金徴求日 = パラメータ.徴求日）';

	-- 元金（MG3.基金徴求日 = パラメータ.徴求日）
	IF pKknChokyuYmd = inChokyuYmd AND nullif(trim(both pKknChokyuYmd), '') IS NOT NULL THEN
		-- 異動年月日 ← MG3.基金徴求日
		pIdoYmd        := pKknChokyuYmd;
		-- 基金異動区分 ← 入金（元金）
		pKknIdoKbn     := '11';

		-- RAISE NOTICE 'calling 基金異動区分 ← 入金（元金）1';

		pKijunZndk     := pkIpaZndk.getKjnZndk(inItakuKaishaCd, inMgrCd, pZndkKijunYmd, 3)::numeric;
		pKijunZndkGnt  := pkIpaZndk.getKjnZndk(inItakuKaishaCd, inMgrCd, pZndkKijunYmd, 83)::numeric;
		-- 基金入金額 = MG3.銘柄単位償還支払金額
		pKknNyukinKngk := pMunitSknShrKngk;

		-- RAISE NOTICE 'after pKknNyukinKngk := pMunitSknShrKngk done';

		pEbSendYmd := sfinskikinido_getEbSendYmd(inItakuKaishaCd, pKknChokyuYmd);
		pLastTeiseiDt  := TO_TIMESTAMP(pkDate.getCurrentTime(), 'yyyy-mm-dd HH24:MI:SS.FF6');

		-- 実質残高(振替債分) = 0 の銘柄は対象外
		IF pKknNyukinKngk <> 0 AND pKijunZndk > 0 THEN
			-- 併存銘柄かつ併存銘柄請求書出力区分＝０は対象外
			IF pKijunZndkGnt <= 0 OR pHeizonSeikyuKbn != '0' THEN
				-- 入金確認済みの場合は、レコードを更新しない
				IF sfinskikinido_checkNyukinZumi(inItakuKaishaCd,inMgrCd,inRbrKjt,pIdoYmd,pKknIdoKbn,' ',' ',' ') <> '1' THEN
					CALL sfinskikinido_insertData(
						inItakuKaishaCd  => inItakuKaishaCd,
						inMgrCd          => inMgrCd,
						inRbrKjt         => inRbrKjt,
						inRbrYmd         => pShokanYmd,
						inTsukaCd        => pShokanTsukaCd,
						inIdoYmd         => pIdoYmd,
						inKknIdoKbn      => pKknIdoKbn,
						inKknNyukinKngk  => pKknNyukinKngk,
						inDataSakuseiKbn => inDataSakuseiKbn,
						inZndkKijunYmd   => pZndkKijunYmd,
						inKijunZndk      => pKijunZndk::bigint,
						inEbSendYmd      => pEbSendYmd,
						inShoriKbn       => '0'::CHAR,
						inLastTeiseiDt   => pLastTeiseiDt,
						inLastTeiseiId   => inUserId,
						inKousinId       => inUserId,
						inSakuseiId      => inUserId
					);
				END IF;
			END IF;
		END IF;
	END IF;

	pTesuryoCapFlg := ' ';

	-- RAISE NOTICE 'begin 元金支払手数料（MG3.手数料徴求日 = パラメータ.徴求日）';

	-- 元金支払手数料（MG3.手数料徴求日 = パラメータ.徴求日）
	IF pTesuChokyuYmd = inChokyuYmd AND nullif(trim(both pTesuChokyuYmd), '') IS NOT NULL THEN

		-- 元金支払手数料の算出および基金異動履歴tblへの登録は、元金支払手数料が選択されていて、元金支払手数料率（分母）が登録されている銘柄のみ行う。
		IF pGnknTesuChooseFlg = '1' AND pGnknShrTesuBunbo > 0 THEN

			-- 消費税率適用基準日切り替え
			IF pShzKijunProcess= '1' THEN
				pShzKijunYmd := pShokanYmd;
			ELSE
				pShzKijunYmd := inChokyuYmd;
			END IF;

			-- 異動年月日 ← MG3.手数料徴求日
			pIdoYmd        := pTesuChokyuYmd;
			-- 基金異動区分 ← 入金（元金支払手数料）
			pKknIdoKbn := '12';
			-- RAISE NOTICE '基金異動区分 ← 入金（元金支払手数料） 2';
			pKijunZndk     := pkIpaZndk.getKjnZndk(inItakuKaishaCd, inMgrCd, pZndkKijunYmd, 3)::numeric;
			pKijunZndkGnt  := pkIpaZndk.getKjnZndk(inItakuKaishaCd, inMgrCd, pZndkKijunYmd, 83)::numeric;
			-- 基金入金額 = MG3.銘柄単位償還支払金額
			pKknNyukinKngk := pMunitSknShrKngk;
			-- RAISE NOTICE 'after pKknNyukinKngk := pMunitSknShrKngk;';

			-- 手数料・消費税を計算
			select * into pZeinukiTesuryo, pZeikomiTesuryo, pZei, gRtnCd from PKIPACALCTESUKNGK.getTesuZeiCommon(	inItakuKaishaCd,	-- 委託会社コード
															inMgrCd,			-- 銘柄コード
															pKknNyukinKngk,		-- 手数料算出の基準となる額面
															pGnknShrTesuBunshi,	-- 手数料率分子
															pGnknShrTesuBunbo::numeric,	-- 手数料率分母
															pShokanTsukaCd,		-- 通貨コード
															pShzKijunYmd,		-- 消費税の適用基準年月日
															pSzeiProcess --,		-- 消費税算出方法(1：従来方式、2：総額方式)
															--pZeinukiTesuryo,	-- (戻)税抜手数料金額
															--pZeikomiTesuryo,	-- (戻)税込手数料金額
															--pZei				-- (戻)消費税金額
															);

			IF gRtnCd <> PKCONSTANT.SUCCESS() THEN
				RAISE EXCEPTION 'tesu_calc_error' USING ERRCODE = '50008';
			END IF;

			-- 基金入金額 = 税抜手数料
			pKknNyukinKngk := pZeinukiTesuryo;
			pEbSendYmd     := sfinskikinido_getEbSendYmd(inItakuKaishaCd, pTesuChokyuYmd);

			-- 基金入金額=0、実質残高(振替債分)=0 は対象外
			IF pKknNyukinKngk <> 0 AND pKijunZndk > 0 THEN
				-- 併存銘柄かつ併存銘柄請求書出力区分＝０は対象外
				IF pKijunZndkGnt <= 0 OR pHeizonSeikyuKbn != '0' THEN

					-- 元金支払手数料ＣＡＰを上限にして元金支払手数料を算出
					IF ((pTesuCapProcess = '1') AND (pGnknShrTesuCap > 0) AND (pJikoTotalHkukKbn = '1') AND (pKkKanyoFlg = '0')) THEN

						-- 元金支払手数料ＣＡＰを基に、手数料・消費税を計算
						select *
						into
							pCapZeinukiGaku,	-- (戻)ＣＡＰ税抜金額
							pCapZeikomiGaku,	-- (戻)ＣＡＰ税込金額
							pCapZei,				-- (戻)ＣＡＰ税金額
							gRtnCd
						from PKIPACALCTESUKNGK.getTesuZeiTeigakuCommon(	inItakuKaishaCd,	-- 委託会社コード
																				inMgrCd,			-- 銘柄コード
																				pGnknShrTesuCap,	-- 手数料ＣＡＰ
																				pShokanTsukaCd,		-- 通貨コード
																				pShzKijunYmd		-- 消費税の適用基準年月日
																			);
						IF gRtnCd <> PKCONSTANT.SUCCESS() THEN
							RAISE EXCEPTION 'tesu_calc_error' USING ERRCODE = '50008';
						END IF;

						IF (pZeikomiTesuryo > pCapZeikomiGaku) THEN
							-- 基金入金額 =　税抜手数料
							pKknNyukinKngk := pCapZeinukiGaku;
							pZei := pCapZei;
							-- 元金支払手数料ＣＡＰを採用
							pTesuryoCapFlg := 'X';
						END IF;
					END IF;

					-- 入金確認済みの場合は、レコードを更新しない
					IF sfinskikinido_checkNyukinZumi(inItakuKaishaCd,inMgrCd,inRbrKjt,pIdoYmd,pKknIdoKbn,pTesuryoCapFlg,' ',' ') <> '1' THEN
						CALL sfinskikinido_insertData(
							inItakuKaishaCd  => inItakuKaishaCd,
							inMgrCd          => inMgrCd,
							inRbrKjt         => inRbrKjt,
							inRbrYmd         => pShokanYmd,
							inTsukaCd        => pShokanTsukaCd,
							inIdoYmd         => pIdoYmd,
							inKknIdoKbn      => pKknIdoKbn,
							inKknNyukinKngk  => pKknNyukinKngk,
							inKkmemberFsKbn	 => pTesuryoCapFlg,
							inDataSakuseiKbn => inDataSakuseiKbn,
							inZndkKijunYmd   => pZndkKijunYmd,
							inKijunZndk      => pKijunZndk::bigint,
							inEbSendYmd      => pEbSendYmd,
							inShoriKbn       => '0'::char,
							inLastTeiseiDt   => pLastTeiseiDt,
							inLastTeiseiId   => inUserId,
							inKousinId       => inUserId,
							inSakuseiId      => inUserId
						);
					END IF;

					-- 元金支払手数料消費税
					-- 異動年月日 ← MG3.手数料徴求日
					pIdoYmd        := pTesuChokyuYmd;
					-- 基金異動区分 ← 入金（元金支払手数料消費税）
					pKknIdoKbn     := '13';
					-- 基金入金額 = 手数料消費税
					pKknNyukinKngk := pZei;
					IF pKknNyukinKngk <> 0 THEN
						-- 入金確認済みの場合は、レコードを更新しない
						IF sfinskikinido_checkNyukinZumi(inItakuKaishaCd,inMgrCd,inRbrKjt,pIdoYmd,pKknIdoKbn,pTesuryoCapFlg,' ',' ') <> '1' THEN
							CALL sfinskikinido_insertData(
								inItakuKaishaCd  => inItakuKaishaCd,
								inMgrCd          => inMgrCd,
								inRbrKjt         => inRbrKjt,
								inRbrYmd         => pShokanYmd,
								inTsukaCd        => pShokanTsukaCd,
								inIdoYmd         => pIdoYmd,
								inKknIdoKbn      => pKknIdoKbn,
								inKknNyukinKngk  => pKknNyukinKngk,
								inKkmemberFsKbn	 => pTesuryoCapFlg,
								inDataSakuseiKbn => inDataSakuseiKbn,
								inZndkKijunYmd   => pZndkKijunYmd,
								inKijunZndk      => pKijunZndk::bigint,
								inEbSendYmd      => pEbSendYmd,
								inShoriKbn       => '0'::char,
								inLastTeiseiDt   => pLastTeiseiDt,
								inLastTeiseiId   => inUserId,
								inKousinId       => inUserId,
								inSakuseiId      => inUserId
							);
						END IF;
					END IF;
				END IF;
			END IF;
		END IF;
	END IF;
	RETURN;

	EXCEPTION
		WHEN SQLSTATE '50015' THEN
			CALL pkLog.fatal('ECM701','sfInsKikinIdo.calcGankinTesuryo','委託会社コード：' || inItakuKaishaCd || ' 銘柄コード：' || inMgrCd || ' 支払期日：' || inRbrKjt);
		RAISE;
	END;
END $calcGankinTesuryo$;

/**
	* 基金請求種類の更新
	*
	* @param inItakuKaishaCd 委託会社コード
	* @param inMgrCd         銘柄コード
	* @param inRbrKjt        利払期日fsfinskikinido_updateKknbillShuri
	* @param inChokyuYmd     徴求日
	*/
CREATE OR REPLACE PROCEDURE sfinskikinido_updateKknbillShuri(
	inItakuKaishaCd IN KIKIN_IDO.ITAKU_KAISHA_CD%TYPE,
	inMgrCd         IN KIKIN_IDO.MGR_CD%TYPE,
	inRbrKjt        IN KIKIN_IDO.RBR_KJT%TYPE,
	inChokyuYmd     IN MGR_RBRKIJ.KKN_CHOKYU_YMD%TYPE
)
LANGUAGE PLPGSQL
AS
$updateKknbillShuri$
DECLARE
	pOldKozaFuriKbn   VKIKIN_NYUKIN_KAKUNIN.KOZA_FURI_KBN%TYPE;
	pCnt              numeric DEFAULT 0;               -- 件数
	pFlg11            numeric DEFAULT 0;               -- 元金入金フラグ
	pFlg12            numeric DEFAULT 0;               -- 元金手数料入金フラグ
	pFlg21            numeric DEFAULT 0;               -- 利金入金フラグ
	pFlg22            numeric DEFAULT 0;               -- 利金手数料入金フラグ
	pKknbillShurui    KIKIN_IDO.KKNBILL_SHURUI%TYPE;  -- 基金請求種類
	CUR_DATA CURSOR FOR
		SELECT
			ITAKU_KAISHA_CD,
			MGR_CD,
			RBR_KJT,
			IDO_YMD,
			TSUKA_CD,
			KKN_IDO_KBN,
			KOZA_FURI_KBN
		FROM
			VKIKIN_NYUKIN_KAKUNIN
		WHERE ITAKU_KAISHA_CD =  inItakuKaishaCd
		AND   MGR_CD          =  inMgrCd
		AND   RBR_KJT         =  inRbrKjt
		AND   IDO_YMD         =  inChokyuYmd
		AND   KKN_IDO_KBN     IN ('11','12','13','21','22','23')
		ORDER BY
			ITAKU_KAISHA_CD,
			MGR_CD,
			RBR_KJT,
			IDO_YMD,
			KKN_IDO_KBN,
			KKMEMBER_FS_KBN,
			KKMEMBER_BCD,
			KKMEMBER_KKBN;

	CUR_DATA2 CURSOR(inTsukaCd  VARCHAR) FOR
		SELECT
			ITAKU_KAISHA_CD,
			MGR_CD,
			RBR_KJT,
			IDO_YMD,
			KKN_IDO_KBN,
			KOZA_FURI_KBN
		FROM
			VKIKIN_NYUKIN_KAKUNIN
		WHERE ITAKU_KAISHA_CD =  inItakuKaishaCd
		AND   MGR_CD          =  inMgrCd
		AND   RBR_KJT         =  inRbrKjt
		AND   IDO_YMD         =  inChokyuYmd
		AND   TSUKA_CD        =  inTsukaCd
		AND   KKN_IDO_KBN     IN ('11','12','13','21','22','23')
		ORDER BY
			ITAKU_KAISHA_CD,
			MGR_CD,
			RBR_KJT,
			IDO_YMD,
			KKN_IDO_KBN,
			KKMEMBER_FS_KBN,
			KKMEMBER_BCD,
			KKMEMBER_KKBN;

BEGIN
	-- RAISE NOTICE 'in sfinskikinido_updateKknbillShuri';
	-- RAISE NOTICE 'inItakuKaishaCd: %', inItakuKaishaCd;
	-- RAISE NOTICE 'inMgrCd: %', inMgrCd;
	-- RAISE NOTICE 'inRbrKjt: %', inRbrKjt;
	-- RAISE NOTICE 'inChokyuYmd: %', inChokyuYmd;

	FOR rec IN CUR_DATA LOOP
		-- RAISE NOTICE 'sfinskikinido_updateKknbillShuri: in loop 1';

		-- 基金異動区分によってフラグをセット
		IF rec.KKN_IDO_KBN = '11' THEN
			pFlg11 := 1;
		ELSIF rec.KKN_IDO_KBN = '12' THEN
			pFlg12 := 1;
		ELSIF rec.KKN_IDO_KBN = '21' THEN
			pFlg21 := 1;
		ELSIF rec.KKN_IDO_KBN = '22' THEN
			pFlg22 := 1;
		END IF;

		-- RAISE NOTICE 'sfinskikinido_updateKknbillShuri: in loop 2';

		pOldKozaFuriKbn    := rec.KOZA_FURI_KBN;

		-- RAISE NOTICE 'sfinskikinido_updateKknbillShuri: in loop 3';

		/* 同じ口座振替区分を持つデータの基金異動区分を調べる*/

		-- RAISE NOTICE 'calling FOR rec2 IN CUR_DATA2(rec.TSUKA_CD) LOOP. rec.TSUKA_CD: %', rec.TSUKA_CD;

		FOR rec2 IN CUR_DATA2(rec.TSUKA_CD) LOOP
			-- RAISE NOTICE 'sfinskikinido_updateKknbillShuri: in loop(2) 1, rec2.KOZA_FURI_KBN: %', rec2.KOZA_FURI_KBN;

			IF rec2.KOZA_FURI_KBN = pOldKozaFuriKbn THEN
				IF rec2.KKN_IDO_KBN = '11' THEN
					pFlg11 := 1;
				ELSIF rec2.KKN_IDO_KBN = '12' THEN
					pFlg12 := 1;
				ELSIF rec2.KKN_IDO_KBN = '21' THEN
					pFlg21 := 1;
				ELSIF rec2.KKN_IDO_KBN = '22' THEN
					pFlg22 := 1;
				END IF;
			END IF;

		END LOOP;

		-- RAISE NOTICE 'AFTER FOR rec2 IN CUR_DATA2(rec.TSUKA_CD) LOOP';

		-- 基金請求種類
		IF pFlg11 <> 0 OR pFlg12 <> 0 OR pFlg21 <> 0 OR pFlg22 <> 0 THEN
			-- RAISE NOTICE 'calling sfinskikinido_getKknbillShurui';
			pKknbillShurui := sfinskikinido_getKknbillShurui(pFlg11::int, pFlg12::int, pFlg21::int, pFlg22::int);
			-- RAISE NOTICE 'calling sfinskikinido_getKknbillShurui completed';
		END IF;

		-- RAISE NOTICE 'calling sfinskikinido_updateData';

		-- 更新
		call sfinskikinido_updateData(	rec.ITAKU_KAISHA_CD,
					rec.MGR_CD,
					rec.RBR_KJT,
					rec.IDO_YMD,
					rec.KKN_IDO_KBN,
					pKknbillShurui);

		-- RAISE NOTICE 'calling sfinskikinido_updateData completed';

		-- フラグを初期化
		pFlg11 := 0;
		pFlg12 := 0;
		pFlg21 := 0;
		pFlg22 := 0;

		pCnt := pCnt + 1;
	END LOOP;

	-- RAISE NOTICE 'sfinskikinido_updateKknbillShuri completed';

END $updateKknbillShuri$;

-- end private --
CREATE OR REPLACE FUNCTION sfinskikinido (
	l_inUserId SUSER.USER_ID%TYPE,
	l_inItakuKaishaCd KIKIN_IDO.ITAKU_KAISHA_CD%TYPE,
	l_inMgrCd KIKIN_IDO.MGR_CD%TYPE,
	l_inRbrKjt KIKIN_IDO.RBR_KJT%TYPE,
	l_inChokyuYmd MGR_RBRKIJ.KKN_CHOKYU_YMD%TYPE,
	l_inDataSakuseiKbn KIKIN_IDO.DATA_SAKUSEI_KBN%TYPE,
	l_inRealBatchKbn text,
	l_inKknZndkKjnYmdKbn text
) RETURNS integer AS $body$
DECLARE

/**
 * 著作権: Copyright (c) 2005
 * 会社名: JIP
 *
 * 入力パラメータを基に基金異動履歴テーブルを更新する
 *
 * @author 三浦　秀吾(ASK)
 * @author 山下　健太(NOA)
 * @version $Id: sfInsKikinIdo.sql,v 1.44 2013/10/21 06:55:08 touma Exp $
 * @version $Revision: 1.44 $
 *
 * @param l_inUserId           ユーザID
 * @param l_inItakuKaishaCd    委託会社コード
 * @param l_inMgrCd            銘柄コード
 * @param l_inRbrKjt           利払期日
 * @param l_inChokyuYmd        徴求日
 * @param l_inDataSakuseiKbn   データ作成区分
 * @param l_inRealBatchKbn     リアル・バッチ区分
 * @param l_inKknZndkKjnYmdKbn 基金残高基準日区分 ※リアルかつ請求書出力の場合必須、他は未使用。
 * @return INTEGER 0:正常、99:異常
 */
/*==============================================================================*/

/*                  変数定義                                                    */

/*==============================================================================*/

	c_SHONIN				CONSTANT MGR_STS.MGR_STAT_KBN%TYPE := '1';	-- 処理区分（承認）
	c_NOT_MASSHO			CONSTANT MGR_STS.MASSHO_FLG%TYPE   := '0';	-- 抹消フラグ（未抹消）
	pHeizonSeikyuKbn		VJIKO_ITAKU.HEIZON_SEIKYU_KBN%TYPE;			-- 併存銘柄請求書出力区分
	pSzeiProcess			MPROCESS_CTL.CTL_VALUE%TYPE;				-- 消費税算出方式(従来方式or総額方式)
	pTesuCapProcess			MPROCESS_CTL.CTL_VALUE%TYPE;				-- 元金支払手数料ＣＡＰ対応
	pShzKijunProcess		MPROCESS_CTL.CTL_VALUE%TYPE;				-- 消費税率適用基準日対応
	gRtnCd					integer := PKCONSTANT.SUCCESS();			-- 手数料計算処理戻り値用

/*==============================================================================*/

/*                  メイン処理                                                  */

/*==============================================================================*/

BEGIN
	-- RAISE NOTICE '!!!!!!!!!!!!in sfInsKikinIdo';

	-- RAISE NOTICE 'l_inUserId: % ', l_inUserId;
	-- RAISE NOTICE 'l_inItakuKaishaCd: % ', l_inItakuKaishaCd;
	-- RAISE NOTICE 'l_inMgrCd: % ', l_inMgrCd;
	-- RAISE NOTICE 'l_inRbrKjt: % ', l_inRbrKjt;
	-- RAISE NOTICE 'l_inChokyuYmd: % ', l_inChokyuYmd;
	-- RAISE NOTICE 'l_inDataSakuseiKbn: % ', l_inDataSakuseiKbn;
	-- RAISE NOTICE 'l_inRealBatchKbn: % ', l_inRealBatchKbn;
	-- RAISE NOTICE 'l_inKknZndkKjnYmdKbn: % ', l_inKknZndkKjnYmdKbn;

	-- 併存銘柄請求書出力区分取得
	SELECT	HEIZON_SEIKYU_KBN
	INTO STRICT	pHeizonSeikyuKbn
	FROM	VJIKO_ITAKU
	WHERE	KAIIN_ID = l_inItakuKaishaCd;

	-- RAISE NOTICE '消費税算出方式(従来方式or総額方式)取得';

	-- 消費税算出方式(従来方式or総額方式)取得
	pSzeiProcess := pkControl.getCtlValue(l_inItakuKaishaCd, 'CALCTESUKNGK0', '0');

	-- RAISE NOTICE '消費税率適用基準日フラグ(1:取引日ベース, 0:徴求日ベース(デフォルト))取得';
	-- 消費税率適用基準日フラグ(1:取引日ベース, 0:徴求日ベース(デフォルト))取得
	pShzKijunProcess := pkControl.getCtlValue(l_inItakuKaishaCd, 'ShzKijun', '0');

	-- RAISE NOTICE '処理制御マスタから元金支払手数料ＣＡＰ対応フラグ取得';
	-- 処理制御マスタから元金支払手数料ＣＡＰ対応フラグ取得
	pTesuCapProcess := pkControl.getCtlValue(l_inItakuKaishaCd, 'TesuryoCap0', '0');

	-- RAISE NOTICE 'sfinskikinido_deleteData';
	-- 更新前データ削除
	CALL sfinskikinido_deleteData(l_inItakuKaishaCd, l_inMgrCd, l_inRbrKjt, l_inChokyuYmd, l_inDataSakuseiKbn, ' ');

	-- RAISE NOTICE 'sfinskikinido_calcRikinTesuryo';
	-- 利金・支払手数料計算
	call sfinskikinido_calcRikinTesuryo(l_inUserId, l_inItakuKaishaCd, l_inMgrCd, l_inRbrKjt, l_inChokyuYmd, l_inDataSakuseiKbn, l_inRealBatchKbn, l_inKknZndkKjnYmdKbn, c_SHONIN, c_NOT_MASSHO, pHeizonSeikyuKbn, pShzKijunProcess, pSzeiprocess, gRtnCd);

	-- RAISE NOTICE 'calling sfinskikinido_calcGankinTesuryo';
	-- 元金・手数料計算
	call sfinskikinido_calcGankinTesuryo(l_inUserId, l_inItakuKaishaCd, l_inMgrCd, l_inRbrKjt, l_inChokyuYmd, l_inDataSakuseiKbn, l_inRealBatchKbn, l_inKknZndkKjnYmdKbn, c_SHONIN, c_NOT_MASSHO, pHeizonSeikyuKbn, pShzKijunProcess, pSzeiprocess, pTesuCapProcess, gRtnCd);

	-- RAISE NOTICE 'calling sfinskikinido_updateKknbillShuri';
	-- 基金請求種類の更新
	call sfinskikinido_updateKknbillShuri(l_inItakuKaishaCd, l_inMgrCd, l_inRbrKjt, l_inChokyuYmd);
	-- RAISE NOTICE 'calling sfinskikinido_updateKknbillShuri completed';

	RETURN pkConstant.SUCCESS();

/*=========< ｴﾗｰ処理 >==========================================================*/

EXCEPTION
	WHEN SQLSTATE '50008' THEN
		/* 共通関数の方でログに出力させているので、ここでは特にログに出力は行わない */

		-- RAISE NOTICE 'SQLERRM 1: %', SQLERRM;

		RETURN gRtnCd;
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', 'sfInsKikinIdo', 'エラーコード'||SQLSTATE);
		CALL pkLog.fatal('ECM701', 'sfInsKikinIdo', 'エラー内容'||SQLERRM);
		-- RAISE NOTICE 'SQLERRM 2: %', SQLERRM;

		RETURN pkConstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;