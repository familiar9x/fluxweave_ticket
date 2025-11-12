/**
 * 著作権: Copyright (c) 2005
 * 会社名: JIP
 *
 * @version $Id: pkIpaName.sql,v 1.26 2008/11/07 06:56:13 nishimura Exp $
 */
 
CREATE SCHEMA IF NOT EXISTS pkipaname;

drop procedure if exists pkipaname.getmadofutoatena;
drop procedure if exists pkipaname.getmadofutoatenayoko;
drop procedure if exists pkipaname.getmadofutoatena_journal;
drop function if exists pkipaname.getpaddingspace2;
drop function if exists pkipaname.getsknshrnincd;
drop function if exists pkipaname.getsknshrnincdtosknkessaicd;
drop function if exists pkipaname.getfundcdtosknkessaicd;
drop function if exists pkipaname.getsknkessaimethodcd;
drop function if exists pkipaname.getsknkessairnm;

--drop function if exists pkipaname.getbankrnm;
--drop function if exists pkipaname.getbankcd;
-- drop function if exists pkipaname.getbicnoshitencd;
-- drop function if exists pkipaname.getbicshitencd;
-- drop function if exists pkipaname.getsknkessaicd;
-- drop function if exists pkipaname.getkozatennm(text, text, out text, out integer);
-- drop function if exists pkipaname.getkozatennm(text, text, text, out text, out integer);
-- drop function if exists pkipaname.getkozatennm;
-- drop function if exists pkipaname.getsknkessairnm;
-- drop function if exists pkipaname.getsknkessainm;
-- drop function if exists pkipaname.gettesushuruinm;

-- set max length to 25 chars (each char has 3 bytes, 3 * 25 = 75), in Oracle this is 50 bytes (2 bytes per char)
-- 行の最大バイト数
create or replace function pkipaname.MAX_LINE_BYTE() returns integer as $$ select integer '75' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;

-- SVF上一行の最大バイト数 (28 chars * 3 bytes each = 84), as-is = 56 bytes = 28 * 2 bytes each
create or replace function pkipaname.SVF_MAX_LINE_BYTE() returns integer as $$ select integer '84' $$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;

/**
*
* @author 西村 仁志
*
* 窓空き封筒用宛名取得<br>
* パラメータで受けた会社名・部署名を窓空き封筒用宛名に編集する
* 文字数を1行50バイトずつに切り出す
*
* @param	l_inkaishanm	会社名称
* @param	l_inbushonm		担当部署名称
* @param	l_outflg		正常処理フラグ
* @return	l_atena			編集した宛名用名称
*/
CREATE OR REPLACE PROCEDURE pkipaname.getMadoFutoAtena(
	l_inkaishanm IN VARCHAR ,
	l_inbushonm IN VARCHAR,
	l_outflg OUT INT,
	l_outAtena OUT VARCHAR(4000)
)
AS $$
DECLARE
/***************************************************************************
	* ログ　:
	* 　　　日付	開発者名		目的
	* -------------------------------------------------------------------
	*　2005.04.11	西村（JIP）		新規作成
	*
	****************************************************************************/
/*==============================================================================*/
/*					デバッグ機能													*/
/*==============================================================================*/
	DEBUG	SMALLINT	DEFAULT 0;
/*==============================================================================*/
/*					定数定義													*/
/*==============================================================================*/
	RTN_OK				CONSTANT INTEGER		= 0;				-- 正常
	RTN_NG_KAISHANM		CONSTANT INTEGER		= 1;				-- 会社名称未入力エラー
	RTN_FATAL			CONSTANT INTEGER		= 99;				-- 予期せぬエラー
	l_inUserId			CONSTANT CHAR(10)		= pkConstant.BATCH_USER();   	-- ユーザID
	REPORT_ID			CONSTANT CHAR(27)		= 'pkIpaName(getMadoFutoAtena)';  -- 帳票ID
/*==============================================================================*/
/*					変数定義													*/
/*==============================================================================*/
	gLineString text[];
	gLineNumber INT;

    /*==============================================================================*/
    /*	メイン処理	*/
    /*==============================================================================*/
    BEGIN
    	IF DEBUG = 1 THEN	call pklog.debug(l_inUserId, REPORT_ID, 'getMadoFutoAtena START');	END IF;
    	-- 入力パラメータのチェック
    	IF nullif(Trim(l_inkaishanm), '') Is Null
    	THEN
    		-- パラメータエラー
    		IF DEBUG = 1 THEN	call pklog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
    		l_outflg := RTN_NG_KAISHANM;
    		call pklog.error(l_inUserId, REPORT_ID, 'SQLERRM:'||'');
    		RETURN;
    	END IF;

		/* IP-03137 縦も横も２５文字で折り返すように変更する */
		call pkipaname.getMadoFutoAtenaYoko(l_inkaishanm, l_inbushonm, l_outflg, l_outAtena);

    	IF DEBUG = 1 THEN	call pklog.debug(l_inUserId, REPORT_ID, 'getMadoFutoAtena END');	END IF;

    -- エラー処理
    EXCEPTION
    	WHEN	OTHERS	THEN
    		call pkLog.fatal('ECM701', REPORT_ID, 'SQLCODE:'||SQLSTATE);
    		call pkLog.fatal('ECM701', REPORT_ID, 'SQLERRM:'||SQLERRM);
    		l_outflg := RTN_FATAL;
            IF DEBUG = 1 THEN	call pklog.debug(l_inUserId, REPORT_ID, 'getMadoFutoAtena END');	END IF;
	END;
$$ LANGUAGE plpgsql;



/**
*
* @author 島添　耕規
*
* 窓空き封筒(横)用宛名取得<br>
* パラメータで受けた会社名・部署名を窓空き封筒用宛名に編集する
* 文字数を1行50バイトずつに切り出す
*
* @param l_inkaishanm  会社名称
* @param l_inbushonm   担当部署名称
* @param l_outflg    正常処理フラグ
* @return  l_atena     編集した宛名用名称
*/
CREATE OR REPLACE PROCEDURE pkipaname.getMadoFutoAtenaYoko(
	l_inkaishanm IN VARCHAR,
	l_inbushonm  IN VARCHAR,
	l_outflg     OUT integer,
	l_outAtena   OUT text
) AS $$
 DECLARE
    /*==============================================================================*/
    /*          デバッグ機能                         */
    /*==============================================================================*/
    DEBUG SMALLINT DEFAULT 0;
    /*==============================================================================*/
    /*          定数定義                          */
    /*==============================================================================*/
    RTN_OK            CONSTANT INTEGER = 0; -- 正常
    RTN_NG_KAISHANM   CONSTANT INTEGER = 1; -- 会社名称未入力エラー

    RTN_FATAL         CONSTANT INTEGER = 99; -- 予期せぬエラー
    l_inUserId       CONSTANT CHAR(10) = pkConstant.BATCH_USER(); -- ユーザID
    REPORT_ID        CONSTANT CHAR(27) = 'pkIpaName(getMadoFutoAtena)'; -- 帳票ID
    gOntyu               VARCHAR(50)     = '　御中';
    /*==============================================================================*/
    /*          変数定義                          */
    /*==============================================================================*/
    gLineString text[];
    gLineNumber INT;

   /*==============================================================================*/
   /*  メイン処理 */
   /*==============================================================================*/
  BEGIN
    IF DEBUG = 1 THEN
      call pklog.debug(l_inUserId, REPORT_ID, 'getMadoFutoAtena START');
    END IF;
    -- 入力パラメータのチェック
    IF nullif(Trim(l_inkaishanm), '') Is Null THEN
      -- パラメータエラー
      IF DEBUG = 1 THEN
        call pklog.debug(l_inUserId, REPORT_ID, 'param error');
      END IF;
      l_outflg := RTN_NG_KAISHANM;
      call pklog.error(l_inUserId, REPORT_ID, 'SQLERRM:' || '');
      RETURN;
    END IF;

    /** 「御中」の表示位置制御 */
    gLineNumber := 0;
    gLineString[gLineNumber] := '';

    -- 会社名称が50バイト以下の場合(１行で収まる場合)
    IF LENGTH(l_inkaishanm::bytea) <= pkipaname.MAX_LINE_BYTE() THEN
	 gLineString[gLineNumber] := l_inkaishanm;

     -- 部署名称がある場合
     IF nullif(Trim(l_inbushonm), '') IS NOT NULL THEN

	   -- full width is 3 bytes in Postgres, to get the number of spaces, we need to get the number of chars and then times 2 to get spaces
       -- １行目の残りに空白をセットする
    	gLineString[gLineNumber] :=  gLineString[gLineNumber] ||
                                   pkipaname.getPaddingSpace2( ( (pkipaname.MAX_LINE_BYTE() - LENGTH(l_inkaishanm::bytea)) / 3 ) * 2 );

       gLineNumber := gLineNumber + 1;

       -- 次の行に部署名をセットする
    	gLineString[gLineNumber] := Trim(l_inbushonm);
     END IF;

    ELSE
      -- 会社名称が51バイト以上(２行に渡る場合)

     -- １行目に会社名称の50バイトまでをセットする
      gLineString[gLineNumber] :=  SUBSTRING(l_inkaishanm, 1, pkipaname.MAX_LINE_BYTE());

     gLineNumber := gLineNumber + 1;

     -- ２行目に会社名称の残りをセットする
      gLineString[gLineNumber] :=  SUBSTRING(l_inkaishanm, pkipaname.MAX_LINE_BYTE() + 1);

     -- 部署名称がある場合
     IF nullif(Trim(l_inbushonm), '') IS NOT NULL THEN
       -- ２行目の残りに空白をセットする
        gLineString[gLineNumber] :=  gLineString[gLineNumber] ||
                                   pkipaname.getPaddingSpace2( ( (pkipaname.MAX_LINE_BYTE() + pkipaname.MAX_LINE_BYTE() -
                                                    LENGTH(l_inkaishanm::bytea)) / 3) * 2);

       gLineNumber := gLineNumber + 1;

       -- ３行目に部署名をセットする
        gLineString[gLineNumber] :=  Trim(l_inbushonm);
     END IF;

    END IF;

   -- 最終行が45バイト以上なら改行して右端に「御中」をつける。そうでない場合はその行に１マス空けてつける。
   -- Oracle(SJIS) IF oracle.LENGTHB(gLineString[gLineNumber]) >= 45 THEN
   IF LENGTH(gLineString[gLineNumber]::bytea) >= 67 THEN
      IF nullif(Trim(l_inbushonm), '') IS NULL THEN
       	gLineString[gLineNumber] :=  gLineString[gLineNumber] ||
                               pkipaname.getPaddingSpace2( ( (pkipaname.MAX_LINE_BYTE() - LENGTH(l_inkaishanm::bytea)) / 3 ) * 2);
      ELSE
       	gLineString[gLineNumber] :=  gLineString[gLineNumber] ||
                               pkipaname.getPaddingSpace2( ( (pkipaname.MAX_LINE_BYTE() - LENGTH(Trim(l_inbushonm)::bytea)) / 3 ) * 2);
      END IF;
      gLineNumber := gLineNumber + 1;
      gOntyu := pkipaname.getPaddingSpace2(44)  || gOntyu;
       gLineString[gLineNumber] :=  gOntyu;

   ELSE
       gLineString[gLineNumber] :=  gLineString[gLineNumber] || gOntyu;
   END IF;

    -- 返値のセット
    l_outAtena := '';
    FOR gNumber IN 0 .. gLineNumber LOOP
      l_outAtena := l_outAtena || gLineString[gNumber];
    END LOOP;

    l_outflg := RTN_OK;

    IF DEBUG = 1 THEN
       call pkLog.debug(l_inUserId, REPORT_ID, 'getMadoFutoAtena END');
    END IF;

    -- エラー処理
  EXCEPTION
    WHEN OTHERS THEN
      call pkLog.fatal('ECM701', REPORT_ID, 'SQLCODE:' || SQLSTATE);
      call pkLog.fatal('ECM701', REPORT_ID, 'SQLERRM:' || SQLERRM);
      l_outflg := RTN_FATAL;

      IF DEBUG = 1 THEN
        call pklog.debug(l_inUserId, REPORT_ID, 'getMadoFutoAtena END');
      END IF;
  END;
  $$ LANGUAGE plpgsql;

 /**
  *
  * @author 池田（幸）
  *
  * 窓空き封筒用宛名取得（ジャーナル用）<br>
  * パラメータで受けた会社名・部署名を窓空き封筒用宛名に編集する
  * 「御中」を適所に追加した、会社名と部署名を返す
  *
  * @param	l_inkaishanm	会社名称
  * @param	l_inbushonm		担当部署名称
  * @param	l_outflg		正常処理フラグ
  * @return	l_outAtena1		編集した宛名１
  * @return	l_outAtena2		編集した宛名２
  * @return	l_outAtena3		編集した宛名３
  */
CREATE OR REPLACE PROCEDURE pkipaname.getMadoFutoAtena_Journal(
	l_inkaishanm	IN VARCHAR,
	l_inbushonm	IN VARCHAR,
	l_outflg		OUT INT,
	l_outAtena1	OUT VARCHAR(4000),
	l_outAtena2	OUT VARCHAR(4000),
	l_outAtena3	OUT VARCHAR(4000)
) AS $$
 DECLARE
	/*==============================================================================*/
	/*			デバッグ機能							*/
	/*==============================================================================*/
	DEBUG SMALLINT DEFAULT 0;
	/*==============================================================================*/
	/*			定数定義						  */
	/*==============================================================================*/
	RTN_OK			CONSTANT INTEGER = 0; -- 正常
	RTN_NG_KAISHANM	CONSTANT INTEGER = 1; -- 会社名称未入力エラー

	RTN_FATAL		CONSTANT INTEGER = 99; -- 予期せぬエラー
	l_inUserId		CONSTANT CHAR(10) = pkConstant.BATCH_USER(); -- ユーザID
	REPORT_ID		CONSTANT CHAR(36) = 'pkIpaName(getMadoFutoAtena_Journal)'; -- 帳票ID
	gOntyu			VARCHAR(50)	 = '　御中';
	/*==============================================================================*/
	/*			変数定義						  */
	/*==============================================================================*/
	gLineString text[];
	gLineNumber INT;

   /*==============================================================================*/
   /*  メイン処理 */
   /*==============================================================================*/
  BEGIN
	IF DEBUG = 1 THEN
		call pklog.debug(l_inUserId, REPORT_ID, 'getMadoFutoAtena_Journal START');
	END IF;
	-- 入力パラメータのチェック
	IF nullif(Trim(l_inkaishanm), '') Is Null THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN
			call pklog.debug(l_inUserId, REPORT_ID, 'param error');
		END IF;
		l_outflg := RTN_NG_KAISHANM;
		call pklog.error(l_inUserId, REPORT_ID, 'SQLERRM:' || '');
		RETURN;
	END IF;

	/** 「御中」の表示位置制御 */
	gLineNumber := 0;
	gLineString[gLineNumber] := '';

	-- 会社名称が50バイト以下の場合(１行で収まる場合)
    IF LENGTH(l_inkaishanm::bytea) <= pkipaname.MAX_LINE_BYTE() THEN
		gLineString[gLineNumber] := l_inkaishanm;

		-- 部署名称がある場合
		IF nullif(Trim(l_inbushonm), '') IS NOT NULL THEN
			-- １行目の残りに空白をセットする

			gLineNumber := gLineNumber + 1;

			-- 次の行に部署名をセットする
			gLineString[gLineNumber] := Trim(l_inbushonm);
		END IF;
	ELSE
		-- 会社名称が51バイト以上(２行に渡る場合)
		-- １行目に会社名称の50バイトまでをセットする
		gLineString[gLineNumber] := SUBSTRING(l_inkaishanm, 1, pkipaname.MAX_LINE_BYTE());

		gLineNumber := gLineNumber + 1;

		-- ２行目に会社名称の残りをセットする
		gLineString[gLineNumber] := SUBSTRING(l_inkaishanm, pkipaname.MAX_LINE_BYTE() + 1);

		-- 部署名称がある場合
		IF nullif(Trim(l_inbushonm), '') IS NOT NULL THEN
			gLineNumber := gLineNumber + 1;

			-- ３行目に部署名をセットする
			gLineString[gLineNumber] := Trim(l_inbushonm);
		END IF;

	END IF;

	gLineString[gLineNumber] := gLineString[gLineNumber] || gOntyu;

	-- 返値のセット
	l_outAtena1 := '';
	l_outAtena2 := '';
	l_outAtena3 := '';

	FOR gNumber IN 0 .. gLineNumber LOOP
		CASE 
			WHEN gNumber = 0 THEN l_outAtena1 := l_outAtena1 || gLineString[gNumber];
			WHEN gNumber = 1 THEN l_outAtena2 := l_outAtena2 || gLineString[gNumber];
			WHEN gNumber = 2 THEN l_outAtena3 := l_outAtena3 || gLineString[gNumber];
		END CASE;
	END LOOP;

	l_outflg := RTN_OK;

	IF DEBUG = 1 THEN
		call pklog.debug(l_inUserId, REPORT_ID, 'getMadoFutoAtena_Journal END');
	END IF;

	-- エラー処理
	EXCEPTION
		WHEN OTHERS THEN
			call pklog.fatal('ECM701', REPORT_ID, 'SQLCODE:' || SQLSTATE);
			call pklog.fatal('ECM701', REPORT_ID, 'SQLERRM:' || SQLERRM);
			l_outflg := RTN_FATAL;

		IF DEBUG = 1 THEN
			call pklog.debug(l_inUserId, REPORT_ID, 'getMadoFutoAtena_Journal END');
		END IF;
  END ;
  $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pkipaname.getpaddingspace2 (
	l_inNumber int
) RETURNS varchar AS $body$
DECLARE
	gPaddingSpace2String varchar(4000) := '';
	gNumber int;

BEGIN
	FOR gNumber IN 1..l_inNumber/2 LOOP
		gPaddingSpace2String := gPaddingSpace2String || '　';
	END LOOP;
	return gPaddingSpace2String;
END;
$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;

/*
* 金融機関略称取得<br />
*
* BICコードより金融機関略称を取得します
*
* @author  山田　安紘
* @param  	l_inItakuKaishaCd IN CHAR     委託会社コード
* @param  	l_inBicCd IN CHAR             BICコード
* @param	l_inShitenRnmFlg IN CHAR      支店略称フラグ(1=表示させる/0=表示させない)
* @param   l_inExistFlg IN NUMBER        存在チェックフラグ(1=処理区分までチェック/0=データベース存在)
* @return 	VARCHAR2
*   		 BIC_CD      ：正常終了時
*           NULL      　：異常終了時
*/
CREATE OR REPLACE FUNCTION pkipaname.getbankrnm ( l_inItakuKaishaCd VARCHAR, l_inBicCd VARCHAR, l_inShitenRnmFlg bigint, l_inExistFlg bigint ) RETURNS varchar AS $body$
DECLARE

    /*==============================================================================*/

    /*					ﾃﾞﾊﾞｯｸﾞ機能													*/

    /*==============================================================================*/

    	DEBUG	smallint	:= 0;
    /*====================================================================*
                      変数定義
     *====================================================================*/
    	result				varchar(60) := NULL;     -- ファンクションデフォルト戻り値
        gTmpRnm             varchar(30) := NULL;     -- テンポラリ
        gBankCd             char(4) := NULL;          -- 銀行コード
        gFSKbn              char(1) := NULL;          -- 区分
        gBicCd              char(8) := NULL;          -- 検索用BICコード
        gBicCdShiten        char(3) := NULL;          -- 検索用BIC支店コード
    /*====================================================================*
       メイン
     *====================================================================*/
BEGIN

        --  戻り値初期化
        Result := NULL;
        gTmpRnm := NULL;

        --  pkLogに現在の情報を与える
        IF ( DEBUG = 1 )THEN CALL Pklog.debug('SYSTEM','getBankRnm','pkipaname.getbankrnm('|| l_inItakuKaishaCd ||', '|| l_inBicCd ||', '|| l_inShitenRnmFlg ||', '|| l_inExistFlg ||'); で開始されました'); END IF;

        --  最初に引数チェック
        --  委託会社コード
        IF ( nullif(trim(both l_inItakuKaishaCd), '') IS NULL ) THEN
            --  引数エラー！
            IF ( DEBUG = 1 )THEN CALL Pklog.fatal('ECM701','getBankRnm','委託会社が入力されていません'); END IF;
            RETURN( NULL );
        END IF;

        --  BICコード
        IF ( nullif(trim(both l_inBicCd), '') IS NULL ) THEN
            --  引数エラー！
            IF ( DEBUG = 1 )THEN CALL Pklog.fatal('ECM701','getBankRnm','BICコードが入力されていません'); END IF;
            RETURN( NULL );
        END IF;

        --  支店略称フラグ
        IF( (l_inShitenRnmFlg = '0' OR l_inShitenRnmFlg = '1' ) = FALSE ) THEN
            --  引数エラー！
            IF ( DEBUG = 1 )THEN CALL Pklog.fatal('ECM701','getBankRnm','支店略称フラグは０か１でないといけません'); END IF;
            RETURN( NULL );
        END IF;

        --  チェックフラグ
        IF( (l_inExistFlg = '0' OR l_inExistFlg = '1' ) = FALSE ) THEN
            --  引数エラー！
            IF ( DEBUG = 1 )THEN CALL Pklog.fatal('ECM701','getBankRnm','存在チェックフラグは０か１でないといけません'); END IF;
            RETURN( NULL );
        END IF;

        --  引数が正しかったので、早速処理に入る
        --  BICコードを支店切り！
        gBicCd       := pkipaname.getbicnoshitencd(l_inBicCd);
        gBicCdShiten := pkipaname.getbicshitencd(l_inBicCd);

        --  Select発行
        SELECT
            M02.BANK_RNM,
            M02.FINANCIAL_SECURITIES_KBN,
            M02.BANK_CD
        INTO STRICT
            gTmpRnm,
            gFSKbn,
            gBankCd
        FROM
            MBANK M02,
            MBANK_ZOKUSEI M08
        WHERE
            M02.FINANCIAL_SECURITIES_KBN = M08.FINANCIAL_SECURITIES_KBN
            AND M02.BANK_CD = M08.BANK_CD
            AND M08.ITAKU_KAISHA_CD = l_inItakuKaishaCd
            AND M08.BIC_CD_NOSHITEN = gBicCd
            AND ((l_inExistFlg = '1' AND M08.SHORI_KBN <> '0') OR l_inExistFlg = '0');

        --  正常に取得できました
        IF ( DEBUG = 1 )THEN CALL pkLog.debug('SYSTEM','getBankRnm','略称取得に成功(戻り値：'|| gTmpRnm ||')'); END IF;

        --  戻り値に入れておく
        Result := gTmpRnm;

        --  支店を取得する前に初期化しておく
        gTmpRnm := NULL;

        --  支店略称も結合しないといけないかどうか確かめる
        IF ( l_inShitenRnmFlg = 1 AND nullif(trim(both gBicCdShiten ), '') IS NOT NULL )THEN

            -- 支店略称を取得しにいく
            --  Select発行
            SELECT
                M03.SHITEN_RNM
            INTO STRICT
                gTmpRnm
            FROM
                MBANK_SHITEN M03,
                MBANK_SHITEN_ZOKUSEI M10
            WHERE
                M03.FINANCIAL_SECURITIES_KBN = M10.FINANCIAL_SECURITIES_KBN
                AND M03.BANK_CD = M10.BANK_CD
                AND M03.SHITEN_CD = M10.SHITEN_CD
                AND M10.FINANCIAL_SECURITIES_KBN = gFSKbn
                AND M10.ITAKU_KAISHA_CD = l_inItakuKaishaCd
                AND M10.BANK_CD = gBankCd
                AND M10.BIC_SHITEN_CD = gBicCdShiten
                AND ((l_inExistFlg = '1' AND M10.SHORI_KBN <> '0') OR l_inExistFlg = '0');

            --  正常に取得できました
            IF ( DEBUG = 1 )THEN CALL pkLog.debug('SYSTEM','getBankRnm','支店略称取得に成功(戻り値：'|| gTmpRnm ||')'); END IF;

            --  戻り値に代入する
            Result := Result || gTmpRnm;

        END IF;

        --  正常終了なので、戻り値で返す！
        RETURN( Result );

        EXCEPTION
        	--  データが存在しない場合
        	WHEN no_data_found THEN
        		IF ( DEBUG = 1 )THEN CALL pkLog.debug('SYSTEM','getBankRnm','金融機関マスタにデータが存在しませんでした'); END IF;
        		RETURN( NULL );

        	--  それ以外の予期しないエラーの場合
        	WHEN OTHERS THEN
        		CALL pkLog.fatal('ECM701','getBankRnm','予期しないエラーが発生しました');
        		RETURN( NULL );
    END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;
-- REVOKE ALL ON FUNCTION pkipaname.getbankrnm ( l_inItakuKaishaCd CHAR, l_inBicCd CHAR, l_inShitenRnmFlg bigint, l_inExistFlg bigint ) FROM PUBLIC;


    /*
     * 金融機関コード取得<br />
     *
     * BICコードより金融機関コードを取得します
     *
     * @author  山田　安紘
     * @param  	l_inItakuKaishaCd IN CHAR     委託会社コード
     * @param  	l_inBicCd IN CHAR             BICコード
     * @param   l_inExistFlg IN NUMBER        存在チェックフラグ(1=処理区分までチェック/0=データベース存在)
     * @return 	VARCHAR2
     *   		 BIC_CD      ：正常終了時
     *           NULL      　：異常終了時
     */
CREATE OR REPLACE FUNCTION pkipaname.getbankcd ( l_inItakuKaishaCd VARCHAR, l_inBicCd VARCHAR, l_inExistFlg bigint ) RETURNS varchar AS $body$
DECLARE

    /*==============================================================================*/

    /*					ﾃﾞﾊﾞｯｸﾞ機能													*/

    /*==============================================================================*/

    	DEBUG	smallint	:= 0;
    /*====================================================================*
                      変数定義
     *====================================================================*/
    	result				varchar(8) := NULL;     -- ファンクションデフォルト戻り値
        gBicCd              char(8) := NULL;         -- 検索用BICコード
    /*====================================================================*
       メイン
     *====================================================================*/
BEGIN

        --  戻り値初期化
        Result := NULL;

        --  pkLogに現在の情報を与える
        IF ( DEBUG = 1 )THEN CALL Pklog.debug('SYSTEM','getBankCd','pkipaname.getbankcd('|| l_inItakuKaishaCd ||', '|| l_inBicCd ||', '|| l_inExistFlg ||'); で開始されました'); END IF;

        --  最初に引数チェック
        --  委託会社コード
        IF ( nullif(trim(both l_inItakuKaishaCd), '') IS NULL ) THEN
            --  引数エラー！
            IF ( DEBUG = 1 )THEN CALL Pklog.fatal('ECM701','getBankCd','委託会社が入力されていません'); END IF;
            RETURN( NULL );
        END IF;

        --  BICコード
        IF ( nullif(trim(both l_inBicCd), '') IS NULL ) THEN
            --  引数エラー！
            IF ( DEBUG = 1 )THEN CALL Pklog.fatal('ECM701','getBankCd','BICコードが入力されていません'); END IF;
            RETURN( NULL );
        END IF;

        --  チェックフラグ
        IF( (l_inExistFlg = '0' OR l_inExistFlg = '1' ) = FALSE ) THEN
            --  引数エラー！
            IF ( DEBUG = 1 )THEN CALL Pklog.fatal('ECM701','getBankCd','存在チェックフラグは０か１でないといけません'); END IF;
            RETURN( NULL );
        END IF;

        --  引数が正しかったので、早速処理に入る
        --  BICコードを支店切り！
        gBicCd := pkipaname.getbicnoshitencd(l_inBicCd);

        --  Select発行
        SELECT
            M02.FINANCIAL_SECURITIES_KBN || M02.BANK_CD AS FS_KBN_BCD
        INTO STRICT
            result
        FROM
            MBANK M02,
            MBANK_ZOKUSEI M08
        WHERE
            M02.FINANCIAL_SECURITIES_KBN = M08.FINANCIAL_SECURITIES_KBN
            AND M02.BANK_CD = M08.BANK_CD
            AND M08.ITAKU_KAISHA_CD = l_inItakuKaishaCd
            AND M08.BIC_CD_NOSHITEN = gBicCd
            AND ((l_inExistFlg = '1' AND M08.SHORI_KBN <> '0') OR l_inExistFlg = '0');

        --  正常に取得できました
        IF ( DEBUG = 1 )THEN CALL Pklog.debug('SYSTEM','getBankCd','正常終了(戻り値：'|| result ||')'); END IF;

        --  正常終了ならそのままの値を返す
        RETURN( Result );

        EXCEPTION
        	--  データが存在しない場合
        	WHEN no_data_found THEN
        		IF ( DEBUG = 1 )THEN CALL pkLog.debug('SYSTEM','getBankCd','金融機関マスタにデータが存在しませんでした'); END IF;
        		RETURN( NULL );

        	--  それ以外の予期しないエラーの場合
        	WHEN OTHERS THEN
        		CALL pkLog.fatal('ECM701','getBankCd','予期しないエラーが発生しました');
        		RETURN( NULL );
    END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;
-- REVOKE ALL ON FUNCTION pkipaname.getbankcd ( l_inItakuKaishaCd CHAR, l_inBicCd CHAR, l_inExistFlg bigint ) FROM PUBLIC;


    /*
     * BICコード支店なしコード取得関数<br />
     *
     * BICコードより支店部分をTRIMしたBICコードを返します。<br />
     * 注意しなければいけないことは、必ず８桁で返すことです。<br />
     * ５桁の場合には３桁スペースが入っているので注意してください<br />
     *
     * @author  山田　安紘
     * @param  	l_inBicCd IN CHAR             BICコード
     * @return 	CHAR(8)
     *   		 BIC_CD      ：正常終了時
     *           NULL      　：異常終了時
     */
CREATE OR REPLACE FUNCTION pkipaname.getbicnoshitencd ( l_inBicCd VARCHAR ) RETURNS char AS $body$
DECLARE

    /*==============================================================================*/

    /*					ﾃﾞﾊﾞｯｸﾞ機能													*/

    /*==============================================================================*/

    	DEBUG	smallint	:= 0;
    /*====================================================================*
                      変数定義
     *====================================================================*/
    	result				char(8) := NULL;     -- ファンクションデフォルト戻り値
    /*====================================================================*
       メイン
     *====================================================================*/
BEGIN
        IF ( DEBUG = 1 )THEN CALL Pklog.debug('SYSTEM','getBicNoShiten','処理を開始します(引数：'|| l_inBicCd ||')'); END IF;
        --  戻り値初期化
        Result := NULL;

        IF ( nullif(trim(both l_inBicCd), '') IS NULL ) THEN
            --  なにも入っていなかったのでNULLで返す
            IF ( DEBUG = 1 )THEN CALL Pklog.debug('SYSTEM','getBicNoShiten','終了 - 何も入っていなかったのでNULLで返します'); END IF;
            RETURN( Result );
        END IF;

        --  処理開始
        --  先頭1桁を判定する
        IF substr(UPPER(l_inBicCd), 1, 1) >= 'A' AND substr(UPPER(l_inBicCd), 1, 1) <= 'Z' THEN

            --  A 〜 Z のときは８桁で返す
            result := substr(l_inBicCd, 1, 8);
            IF ( DEBUG = 1 )THEN CALL Pklog.debug('SYSTEM','getBicNoShiten','正常終了 - ８桁で返します - (戻り値：'|| result ||')'); END IF;
            RETURN( result );

        --  5桁目を判定する (before > 5)
        ELSIF length(trim(both l_inBicCd)::bytea) >= 10
            AND substr(UPPER(l_inBicCd), 5, 1) >= 'A' AND substr(UPPER(l_inBicCd), 5, 1) <= 'Z' THEN

            --  A 〜 Z のときは８桁で返す
            result := substr(l_inBicCd, 1, 8);
            IF ( DEBUG = 1 )THEN CALL Pklog.debug('SYSTEM','getBicNoShiten','正常終了 - ８桁で返します - (戻り値：'|| result ||')'); END IF;
            RETURN( result );

        END IF;

        --  それ以外は５桁で返す
        result := substr(l_inBicCd, 1, 5);
        IF ( DEBUG = 1 )THEN CALL Pklog.debug('SYSTEM','getBicNoShiten','正常終了 - ５桁で返します - (戻り値：'|| result ||')'); END IF;
        RETURN( result );

    EXCEPTION
        --  それ以外の予期しないエラーの場合
        WHEN OTHERS THEN
        CALL pkLog.fatal('ECM701','getBicNoShiten','予期しないエラーが発生しました');
        RETURN( NULL );
    END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;

    /*
     * Bicコード支店コード取得関数<br />
     *
     * BICコードより支店部分だけのBICコードを返します。<br />
     *
     * @author  山田　安紘
     * @param  	l_inBicCd IN CHAR             BICコード
     * @return 	CHAR(3)
     *   		 BIC_CD      ：正常終了時
     *           NULL      　：値が取得できないとき
     */
CREATE OR REPLACE FUNCTION pkipaname.getbicshitencd ( l_inBicCd VARCHAR ) RETURNS char AS $body$
DECLARE

    /*==============================================================================*/

    /*					ﾃﾞﾊﾞｯｸﾞ機能													*/

    /*==============================================================================*/

    	DEBUG	smallint	:= 0;
    /*====================================================================*
                      変数定義
     *====================================================================*/
    	result				char(3) := NULL;     -- ファンクションデフォルト戻り値
    /*====================================================================*
       メイン
     *====================================================================*/
BEGIN
        IF ( DEBUG = 1 )THEN CALL Pklog.debug('SYSTEM','getBicNoShiten','処理を開始します(引数：'|| l_inBicCd ||')'); END IF;
        --  戻り値初期化
        Result := NULL;

        IF ( nullif(trim(both l_inBicCd), '') IS NULL ) THEN
            --  なにも入っていなかったのでNULLで返す
            IF ( DEBUG = 1 )THEN CALL Pklog.debug('SYSTEM','getBicNoShiten','終了 - 何も入っていなかったのでNULLで返します'); END IF;
            RETURN( Result );
        END IF;

        --  処理開始
        --  先頭1桁を判定する
        IF substr(UPPER(l_inBicCd), 1, 1) >= 'A' AND substr(UPPER(l_inBicCd), 1, 1) <= 'Z' THEN

            --  A 〜 Z のときは３桁で返す
            result := substr(l_inBicCd, 9, 3);
            IF ( DEBUG = 1 )THEN CALL Pklog.debug('SYSTEM','getBicNoShiten','正常終了 - ９桁から返します - (戻り値：'|| result ||')'); END IF;
            RETURN( result );

        --  5桁目を判定する before >= 5
        ELSIF length(trim(both l_inBicCd)::bytea) >= 10
            AND substr(UPPER(l_inBicCd), 5, 1) >= 'A' AND substr(UPPER(l_inBicCd), 5, 1) <= 'Z' THEN

            --  A 〜 Z のときは３桁で返す
            result := substr(l_inBicCd, 9, 3);
            IF ( DEBUG = 1 )THEN CALL Pklog.debug('SYSTEM','getBicNoShiten','正常終了 - ９桁から返します - (戻り値：'|| result ||')'); END IF;
            RETURN( result );

        END IF;

        --  それ以外は３桁で返す
        result := substr(l_inBicCd, 6, 3);
        IF ( DEBUG = 1 )THEN CALL Pklog.debug('SYSTEM','getBicNoShiten','正常終了 - ６桁目から返します - (戻り値：'|| result ||')'); END IF;
        RETURN( result );

    EXCEPTION
        --  それ以外の予期しないエラーの場合
        WHEN OTHERS THEN
        CALL pkLog.fatal('ECM701','getBicNoShiten','予期しないエラーが発生しました');
        RETURN( NULL );
    END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;


    /*
     * 資金決済会社コード取得<br />
     *
     * 金融機関コードより、資金決済会社コードを取得します。
     *
     * @author  山田　安紘
     * @param  	l_inItakuKaishaCd          IN CHAR     委託会社コード
     * @param   l_inFinancialSecuritiesKbn IN CHAR     金融機関区分
     * @param   l_inBankCd                 IN CHAR     金融機関コード
     * @param   l_inShitenCd               IN CHAR     金融機関支店コード
     * @param   l_inExistFlg               IN CHAR     存在チェックフラグ
     *
     * このメソッドは有無を言わずエラーかデータがない時にはnullで返します。
     *
     * @return 	CHAR
     *   		資金決済会社コード      ：正常終了時
     *          NULL      　            ：異常終了時
     */
CREATE OR REPLACE FUNCTION pkipaname.getsknkessaicd ( l_inItakuKaishaCd VARCHAR, l_inFinancialSecuritiesKbn VARCHAR, l_inBankCd VARCHAR, l_inShitenCd VARCHAR, l_inExistFlg VARCHAR ) RETURNS char AS $body$
DECLARE

    /*==============================================================================*/

    /*					ﾃﾞﾊﾞｯｸﾞ機能													*/

    /*==============================================================================*/

    	DEBUG	smallint	:= 0;
    /*==============================================================================*
                      変数定義
     *==============================================================================*/
    	result				char(7)     := NULL;     -- ファンクションデフォルト戻り値
    /*==============================================================================*
       メイン
     *==============================================================================*/
BEGIN

        --  戻り値初期化
        Result := NULL;

        --  pkLogに現在の情報を与える
        IF ( DEBUG = 1 )THEN CALL Pklog.debug('SYSTEM','getSknKessaiCd','pkipaname.getsknkessaicd('|| l_inItakuKaishaCd ||', '|| l_inFinancialSecuritiesKbn ||', '|| l_inBankCd || ', ' || l_inShitenCd || ', ' || l_inExistFlg || '); で開始されました'); END IF;

        --  最初に引数チェック
        --  委託会社コード
        IF ( nullif(trim(both l_inItakuKaishaCd), '') IS NULL ) THEN
            --  引数エラー！
            IF ( DEBUG = 1 )THEN CALL Pklog.fatal('ECM701','getSknKessaiCd','委託会社が入力されていません'); END IF;
            RETURN( NULL );
        END IF;

        --  金融機関区分
        IF ( nullif(trim(both l_inFinancialSecuritiesKbn), '') IS NULL ) THEN
            --  引数エラー！
            IF ( DEBUG = 1 )THEN CALL Pklog.fatal('ECM701','getSknKessaiCd','金融機関区分が入力されていません'); END IF;
            RETURN( NULL );
        END IF;

        --  金融機関コード
        IF ( nullif(trim(both l_inBankCd), '') IS NULL ) THEN
            --  引数エラー！
            IF ( DEBUG = 1 )THEN CALL Pklog.fatal('ECM701','getSknKessaiCd','金融機関コードが入力されていません'); END IF;
            RETURN( NULL );
        END IF;

        --  チェックフラグ
        IF( (l_inExistFlg = '0' OR l_inExistFlg = '1' ) = FALSE ) THEN
            --  引数エラー！
            IF ( DEBUG = 1 )THEN CALL Pklog.fatal('ECM701','getSknKessaiCd','存在チェックフラグは０か１でないといけません'); END IF;
            RETURN( NULL );
        END IF;

        --  引数が正しかったので、早速処理に入る
        --  Select発行
        IF ( nullif(trim(both l_inShitenCd), '') IS NULL ) THEN

			--  支店コードが指定されていない場合
			IF ( DEBUG = 1 )THEN CALL Pklog.debug('SYSTEM','getSknKessaiCd','支店コードなしで検索'); END IF;

			SELECT
				trim(both MIN(M10.SKN_KESSAI_CD))
			INTO STRICT
				result
			FROM
				MBANK M02,
				MBANK_ZOKUSEI M08,
				MBANK_SHITEN M03,
				MBANK_SHITEN_ZOKUSEI M10
			WHERE
				M02.FINANCIAL_SECURITIES_KBN = M03.FINANCIAL_SECURITIES_KBN
				AND M02.FINANCIAL_SECURITIES_KBN = M08.FINANCIAL_SECURITIES_KBN
				AND M02.FINANCIAL_SECURITIES_KBN = M10.FINANCIAL_SECURITIES_KBN
				AND M02.BANK_CD = M03.BANK_CD
				AND M02.BANK_CD = M08.BANK_CD
				AND M02.BANK_CD = M10.BANK_CD
				AND M03.SHITEN_CD = M10.SHITEN_CD
				AND M08.ITAKU_KAISHA_CD = M10.ITAKU_KAISHA_CD
				AND M08.ITAKU_KAISHA_CD = l_inItakuKaishaCd
				AND M08.FINANCIAL_SECURITIES_KBN = l_inFinancialSecuritiesKbn
				AND M02.BANK_CD = l_inBankCd
				AND ((l_inExistFlg = '1' AND M02.SHORI_KBN <> '0') OR l_inExistFlg = '0')
				AND ((l_inExistFlg = '1' AND M08.SHORI_KBN <> '0') OR l_inExistFlg = '0')
				AND ((l_inExistFlg = '1' AND M03.SHORI_KBN <> '0') OR l_inExistFlg = '0')
				AND ((l_inExistFlg = '1' AND M10.SHORI_KBN <> '0') OR l_inExistFlg = '0')
				AND nullif(trim(both M10.SKN_KESSAI_CD), '') IS NOT NULL;

		ELSE

			-- 支店コードが指定されている場合
			IF ( DEBUG = 1 )THEN CALL Pklog.debug('SYSTEM','getSknKessaiCd','支店コードありで検索'); END IF;

			SELECT
				CASE WHEN  COUNT( M02.BANK_CD )=1 THEN  trim(both MAX( M10.SKN_KESSAI_CD ) )  ELSE NULL END
			INTO STRICT
				result
			FROM
				MBANK M02,
				MBANK_ZOKUSEI M08,
				MBANK_SHITEN M03,
				MBANK_SHITEN_ZOKUSEI M10
			WHERE
				M02.FINANCIAL_SECURITIES_KBN = M03.FINANCIAL_SECURITIES_KBN
				AND M02.FINANCIAL_SECURITIES_KBN = M08.FINANCIAL_SECURITIES_KBN
				AND M02.FINANCIAL_SECURITIES_KBN = M10.FINANCIAL_SECURITIES_KBN
				AND M02.BANK_CD = M03.BANK_CD
				AND M02.BANK_CD = M08.BANK_CD
				AND M02.BANK_CD = M10.BANK_CD
				AND M03.SHITEN_CD = M10.SHITEN_CD
				AND M08.ITAKU_KAISHA_CD = M10.ITAKU_KAISHA_CD
				AND M08.ITAKU_KAISHA_CD = l_inItakuKaishaCd
				AND M08.FINANCIAL_SECURITIES_KBN = l_inFinancialSecuritiesKbn
				AND M08.BANK_CD = l_inBankCd
				AND M10.SHITEN_CD = l_inShitenCd
				AND ((l_inExistFlg = '1' AND M02.SHORI_KBN <> '0') OR l_inExistFlg = '0')
				AND ((l_inExistFlg = '1' AND M08.SHORI_KBN <> '0') OR l_inExistFlg = '0')
				AND ((l_inExistFlg = '1' AND M03.SHORI_KBN <> '0') OR l_inExistFlg = '0')
				AND ((l_inExistFlg = '1' AND M10.SHORI_KBN <> '0') OR l_inExistFlg = '0');

		END IF;

        --  正常に取得できました
        IF ( DEBUG = 1 )THEN CALL Pklog.debug('SYSTEM','getSknKessaiCd','正常終了(戻り値：'|| result ||')'); END IF;

        --  正常終了ならそのままの値を返す
        RETURN( Result );

        EXCEPTION
        	--  データが存在しない場合
        	WHEN no_data_found THEN
        		IF ( DEBUG = 1 )THEN CALL pkLog.debug('SYSTEM','getSknKessaiCd','金融機関,支店マスタにデータが存在しませんでした'); END IF;
        		RETURN( NULL );

        	--  それ以外の予期しないエラーの場合
        	WHEN OTHERS THEN
        		CALL pkLog.fatal('ECM701','getSknKessaiCd','予期しないエラーが発生しました');
        		RETURN( NULL );
    END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;

    /*
     * 口座店名称取得処理
     * 金融機関名称、部店名称を元にして口座店名称を取得します。
     * 取得した、文字列の長さによって文字列を編集します。
     * 想定される帳票は請求書です。
     * 入金口座区分が'3'（その他）時は、請求書上には出力しないため、'　'を返します。
     * （社債払込金計算書兼通知書のみ入金口座区分が必要）
     *
     * 銀行名称について、'株式会社'が含まれていれば取り除き、
     * 銀行名称 + '　' + 部店名称　の文字列の合計文字数が
     * 1. 25文字以下のとき
     *      銀行名称 + '　' + 部店名称を返す
     * 2. 26文字以上のとき
     *      部店名称のみを返す
     *
     * @author  磯田　浩靖
     * @param   l_inBankNm              金融機関名称
     * @param   l_inButenNm             部店名称
     * @param   l_inNyukinKozaKbn       入金口座区分
     * @param   l_outKozaTenNm          口座店名称
     * @return  リターンコード          INTEGER
     *          pkConstant.SUCCESS()      : 正常終了
     *          pkConstant.ERROR()        : 異常終了
     */
CREATE OR REPLACE FUNCTION pkipaname.getkozatennm ( l_inBankNm text, l_inButenNm text, l_outKozaTenNm OUT text , OUT extra_param integer) RETURNS record AS $body$
DECLARE

    /*====================================================================*/

    /*					ﾃﾞﾊﾞｯｸﾞ機能										  */

    /*====================================================================*/

	    DEBUG	smallint	:= 0;
    /*====================================================================*
    					定数定義
     *====================================================================*/
    	-- ユーザID
    	USER_ID				CONSTANT varchar(20) := pkConstant.BATCH_USER();
    	-- 帳票ID
    	REPORT_ID			CONSTANT varchar(20) := '';
    	-- 本SPのID
    	SP_ID				CONSTANT varchar(30) := 'pkIpaName.getKozaTenNm()';
        -- 取り除く文字列
        REPLACE_STR         CONSTANT varchar(20) := '株式会社';
        -- セパレータ
        SEP                 CONSTANT varchar(2)  := '　';
        -- データ無しエラーコード
        ERR_CD_NODATA       CONSTANT varchar(6) := 'ECM305';

        -- 入金口座区分　その他
        NYUKIN_KOZA_KBN_OTHER CONSTANT varchar(1) := '3';

    /*====================================================================*
                      変数定義
     *====================================================================*/
        rtn                 integer;

    	gBankNm			    VJIKO_ITAKU.BANK_NM%TYPE;       		-- 銀行名称
    	gButenNm 			MBUTEN.BUTEN_NM%TYPE;  			        -- 部店名称
        gKozaTenNm          varchar(100);                          -- 口座店名称
    /*====================================================================*
            メイン
     *====================================================================*/
BEGIN

    	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' START');	END IF;

        rtn := pkConstant.FATAL();

        gBankNm := l_inBankNm;
        gButenNm := l_inButenNm;

        /*
         * 銀行名称に'株式会社'が含まれている場合、取り除き、スペースを詰める
         *
         * 例
         * '株式会社　ｘｘｘ銀行'であれば'ｘｘｘ銀行'となる。
         */
        gBankNm := RTRIM(LTRIM(REPLACE(gBankNm,REPLACE_STR,''), '　'), '　');

        /* 部店名称の全角スペースを取り除く */

        gButenNm := RTRIM(LTRIM(gButenNm, '　'), '　');

        /*
         * 口座店名称を以下の条件によってセットする
         *
         * 銀行名称 + '　' + 部店名称　の文字列の合計文字数が
         * 1. 25文字以下のとき
         *      銀行名称 + '　' + 部店名称をセットする
         * 2. 26文字以上のとき
         *      部店名称のみをセットする
         */
        /* バイト単位でチェックするので50バイト以下なら上記の1. */
		-- before <= 50
        IF length((gBankNm || SEP || gButenNm)::bytea) <= 75 THEN
            gKozaTenNm := gBankNm || SEP || gButenNm;
        ELSE
            gKozaTenNm := gButenNm;
        END IF;

        l_outKozaTenNm := gKozaTenNm;

        rtn := pkConstant.SUCCESS();

    	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' END');	END IF;

        extra_param := rtn;

        RETURN;

    /*====================================================================*
        異常終了 出口
     *====================================================================*/
    EXCEPTION
    	WHEN no_data_found THEN
    		CALL pkLog.ERROR('ECM501', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
            extra_param := pkConstant.ERROR();
            RETURN;
    	/* その他・例外エラー */

    	WHEN OTHERS THEN
    		CALL pkLog.fatal('ECM701', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
            extra_param := pkConstant.ERROR();
            RETURN;
    END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;

    /*
     * 口座店名称取得処理
     * 金融機関名称、部店名称を元にして口座店名称を取得します。
     * 取得した、文字列の長さによって文字列を編集します。
     * 想定される帳票は請求書です。
     * 入金口座区分が'3'（その他）時は、請求書上には出力しないため、'　'を返します。
     * （社債払込金計算書兼通知書のみ入金口座区分が必要）
     *
     * 銀行名称について、'株式会社'が含まれていれば取り除き、
     * 銀行名称 + '　' + 部店名称　の文字列の合計文字数が
     * 1. 25文字以下のとき
     *      銀行名称 + '　' + 部店名称を返す
     * 2. 26文字以上のとき
     *      部店名称のみを返す
     *
     * @author  磯田　浩靖
     * @param   l_inBankNm              金融機関名称
     * @param   l_inButenNm             部店名称
     * @param   l_inNyukinKozaKbn       入金口座区分
     * @param   l_outKozaTenNm          口座店名称
     * @return  リターンコード          INTEGER
     *          pkConstant.SUCCESS()      : 正常終了
     *          pkConstant.ERROR()        : 異常終了
     */
CREATE OR REPLACE FUNCTION pkipaname.getkozatennm ( l_inBankNm text, l_inButenNm text, l_inNyukinKozaKbn text, l_outKozaTenNm OUT text , OUT extra_param integer) RETURNS record AS $body$
DECLARE

    /*====================================================================*/

    /*					ﾃﾞﾊﾞｯｸﾞ機能										  */

    /*====================================================================*/

	    DEBUG	smallint	:= 0;
    /*====================================================================*
    					定数定義
     *====================================================================*/
    	-- ユーザID
    	USER_ID				CONSTANT varchar(20) := pkConstant.BATCH_USER();
    	-- 帳票ID
    	REPORT_ID			CONSTANT varchar(20) := '';
    	-- 本SPのID
    	SP_ID				CONSTANT varchar(30) := 'pkIpaName.getKozaTenNm()';
        -- 取り除く文字列
        REPLACE_STR         CONSTANT varchar(20) := '株式会社';
        -- セパレータ
        SEP                 CONSTANT varchar(2)  := '　';
        -- データ無しエラーコード
        ERR_CD_NODATA       CONSTANT varchar(6) := 'ECM305';

        -- 入金口座区分　支店別段口座
        NYUKIN_KOZA_KBN_SHITEN CONSTANT varchar(1) := '1';

        -- 入金口座区分　発行体口座振込
        NYUKIN_KOZA_KBN_KOUZA CONSTANT varchar(1) := '2';

		-- 入金口座区分　総合振込
        NYUKIN_KOZA_KBN_FRKM CONSTANT VARCHAR(1) := 'D';

    /*====================================================================*
                      変数定義
     *====================================================================*/
        rtn                 integer;

    	gBankNm			    VJIKO_ITAKU.BANK_NM%TYPE;       		-- 銀行名称
    	gButenNm 			MBUTEN.BUTEN_NM%TYPE;  			        -- 部店名称
        gKozaTenNm          varchar(100);                          -- 口座店名称
    /*====================================================================*
            メイン
     *====================================================================*/
BEGIN

    	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' START');	END IF;

        rtn := pkConstant.FATAL();

        /* 入金口座区分がその他の場合は'　'を返す */

        IF trim(both l_inNyukinKozaKbn) <> NYUKIN_KOZA_KBN_SHITEN AND trim(both l_inNyukinKozaKbn) <> NYUKIN_KOZA_KBN_KOUZA AND TRIM(both l_inNyukinKozaKbn) <> NYUKIN_KOZA_KBN_FRKM THEN
            l_outKozaTenNm := '　';
            extra_param := pkConstant.SUCCESS();
            RETURN;
        END IF;

        gBankNm := l_inBankNm;
        gButenNm := l_inButenNm;

        select * into gKozaTenNm, rtn from pkipaname.getkozatennm(gBankNm, gButenNm);

        IF rtn <> pkConstant.SUCCESS() THEN
            rtn := pkConstant.ERROR();
        ELSE
            rtn := pkConstant.SUCCESS();
        END IF;

        l_outKozaTenNm := gKozaTenNm;

    	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' END');	END IF;

        extra_param := rtn;

        RETURN;

    /*====================================================================*
        異常終了 出口
     *====================================================================*/
    EXCEPTION
    	WHEN no_data_found THEN
    		CALL pkLog.ERROR('ECM501', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
            extra_param := pkConstant.ERROR();
            RETURN;
    	/* その他・例外エラー */

    	WHEN OTHERS THEN
    		CALL pkLog.fatal('ECM701', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
            extra_param := pkConstant.ERROR();
            RETURN;
    END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;

/*
* 資金決済会社略称取得処理
*
* @author  山下　健太
* @param   l_inItakuKaichaCd           委託会社コード
* @param   l_inSknKessaiCd             資金決済会社コード
* @return  資金決済会社略称         VARCHAR2
*/
CREATE OR REPLACE FUNCTION pkipaname.getsknkessairnm ( l_inItakuKaichaCd text, l_inSknKessaiCd text ) RETURNS varchar AS $body$
DECLARE

	/*====================================================================*
	                  変数定義
	 *====================================================================*/
		cnt					integer := 0;
		ret					varchar(100) := ' ';
	/*====================================================================*
	        メイン
	 *====================================================================*/
	
BEGIN

		-- 金融機関支店属性から、件数を取得
		SELECT COUNT(M10.SKN_KESSAI_CD) INTO STRICT cnt FROM MBANK_SHITEN_ZOKUSEI M10
									WHERE M10.ITAKU_KAISHA_CD = l_inItakuKaichaCd
									AND   M10.SKN_KESSAI_CD = l_inSknKessaiCd;

		-- 存在する場合、金融機関マスタと金融機関支店マスタから略称を取得
		IF cnt = 1 THEN

			SELECT (M02.BANK_RNM || M03.SHITEN_RNM) INTO STRICT ret
			FROM
				MBANK M02,MBANK_SHITEN M03,MBANK_SHITEN_ZOKUSEI M10
			WHERE   M10.ITAKU_KAISHA_CD = l_inItakuKaichaCd
				AND M10.SKN_KESSAI_CD = l_inSknKessaiCd
				AND M10.BANK_CD = M03.BANK_CD
				AND M10.SHITEN_CD = M03.SHITEN_CD
				AND M10.FINANCIAL_SECURITIES_KBN = M03.FINANCIAL_SECURITIES_KBN
				AND M03.BANK_CD = M02.BANK_CD
				AND M03.FINANCIAL_SECURITIES_KBN = M02.FINANCIAL_SECURITIES_KBN;

		END IF;

		RETURN ret;

	EXCEPTION
		WHEN OTHERS THEN
			CALL pkLog.fatal('ECM701','pkIpaName',SQLSTATE || SUBSTR(SQLERRM,1,100));
			RETURN NULL;
	END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;

/*
* 資金決済会社名称取得処理
*
* @author  小久保　瞳
* @param   l_inItakuKaichaCd           委託会社コード
* @param   l_inSknKessaiCd             資金決済会社コード
* @return  資金決済会社名称         VARCHAR2
*/
CREATE OR REPLACE FUNCTION pkipaname.getSknKessaiNm
(
	l_inItakuKaichaCd IN VARCHAR(4000),
	l_inSknKessaiCd IN VARCHAR(4000)
)
RETURNS VARCHAR(4000)
AS $$
DECLARE
	result		VARCHAR(140) DEFAULT ' ';
BEGIN

	IF nullif(Trim(l_inSknKessaiCd), '') IS NOT NULL THEN
	
	-- 金融機関マスタと金融機関支店マスタから名称を取得
	SELECT (M02.BANK_NM || M03.SHITEN_NM)
	INTO result
	FROM
		MBANK M02,MBANK_SHITEN M03,MBANK_SHITEN_ZOKUSEI M10
	WHERE   M10.ITAKU_KAISHA_CD = l_inItakuKaichaCd
		AND M10.SKN_KESSAI_CD = l_inSknKessaiCd
		AND M10.BANK_CD = M03.BANK_CD
		AND M10.SHITEN_CD = M03.SHITEN_CD
		AND M10.FINANCIAL_SECURITIES_KBN = M03.FINANCIAL_SECURITIES_KBN
		AND M03.BANK_CD = M02.BANK_CD
		AND M03.FINANCIAL_SECURITIES_KBN = M02.FINANCIAL_SECURITIES_KBN;
		
	END IF;

	RETURN result;

EXCEPTION
	WHEN NO_DATA_FOUND THEN
		RETURN result;
	
	WHEN OTHERS THEN
		call pkLog.fatal('ECM701','pkIpaName',SQLSTATE || SUBSTR(SQLERRM,1,100));
		RETURN NULL;
END ;
$$ LANGUAGE plpgsql;

/*
* 手数料算出ベース取得処理。
* 銘柄手数料（制御情報）より手数料種類コードが「61：利金支払手数料（元金）」・「82：利金支払手数料（利金）」
* のデータを取得し、手数料算出ベース文字列を返す。
*
* @param  l_inItakuKaichaCd 委託会社コード
* @param  l_inMgrCd         銘柄コード
* @return VARCHAR2 「61：利金支払手数料（元金）」：「元」、「82：利金支払手数料（利金）」：「利」、それ以外：ブランク
*/
CREATE OR REPLACE FUNCTION pkipaname.gettesushuruinm ( l_inItakuKaichaCd MGR_TESURYO_CTL.ITAKU_KAISHA_CD%TYPE, l_inMgrCd MGR_TESURYO_CTL.MGR_CD%TYPE ) RETURNS varchar AS $body$
DECLARE

		/*==============================================================================*/

		/*                  変数定義                                                    */

		/*==============================================================================*/

		gTesuShuruiCd MGR_TESURYO_CTL.TESU_SHURUI_CD%TYPE; -- 手数料種類コード
	
BEGIN
		SELECT
			TESU_SHURUI_CD
		INTO STRICT
			gTesuShuruiCd
		FROM
			MGR_TESURYO_CTL
		WHERE ITAKU_KAISHA_CD =  l_inItakuKaichaCd
		AND   MGR_CD          =  l_inMgrCd
		AND   TESU_SHURUI_CD  IN ('61', '82')
		AND   CHOOSE_FLG      =  '1';

		IF gTesuShuruiCd = '61' THEN
			RETURN '元';
		ELSE
			RETURN '利';
		END IF;
	EXCEPTION
		WHEN OTHERS THEN
			RETURN ' ';
	END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;

CREATE OR REPLACE FUNCTION pkipaname.getsknshrnincd (
	l_inItakuKaishaCd MSSI.ITAKU_KAISHA_CD%TYPE,
	l_inMgrCd SHINKIBOSHU.MGR_CD%TYPE,
	l_inHkukCd text,
	l_inFundCd MSSI.FUND_CD%TYPE
) RETURNS MSSI.SKN_SHRNIN_CD%TYPE AS $body$
DECLARE

		pHkukBicCdNoshiten MBANK_ZOKUSEI.BIC_CD_NOSHITEN%TYPE;
		pHakkoYmd          MGR_KIHON.HAKKO_YMD%TYPE;
		pResult            MSSI.SKN_SHRNIN_CD%TYPE;

BEGIN
		CALL pkLog.debug('pkIpaName','getSknShrninCd','開始');
		CALL pkLog.debug('pkIpaName','getSknShrninCd','引数：委託会社コード：' || l_inItakuKaishaCd);
		CALL pkLog.debug('pkIpaName','getSknShrninCd','引数：銘柄コード：' || l_inMgrCd);
		CALL pkLog.debug('pkIpaName','getSknShrninCd','引数：引受会社コード：' || l_inHkukCd);
		CALL pkLog.debug('pkIpaName','getSknShrninCd','引数：ファンドコード：' || l_inFundCd);

		-- 引数チェック
		-- 委託会社コード
		IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' THEN
			CALL pkLog.info('pkIpaName','getSknShrninCd','委託会社コード未入力');
			RETURN NULL;
		END IF;

		-- 銘柄コード
		IF coalesce(trim(both l_inMgrCd)::text, '') = '' THEN
			CALL pkLog.info('pkIpaName','getSknShrninCd','銘柄コード未入力');
			RETURN NULL;
		END IF;

		-- 引受会社コード
		IF coalesce(trim(both l_inHkukCd)::text, '') = '' THEN
			CALL pkLog.info('pkIpaName','getSknShrninCd','引受会社コード未入力');
			RETURN NULL;
		END IF;

		-- ファンドコード
		IF coalesce(trim(both l_inFundCd)::text, '') = '' THEN
			CALL pkLog.info('pkIpaName','getSknShrninCd','ファンドコード未入力');
			RETURN NULL;
		END IF;

		-- 委託会社・引受会社より金融機関属性マスタ.ＢＩＣコード（支店コードなし）を取得
		BEGIN
			SELECT
				BIC_CD_NOSHITEN
			INTO STRICT
				pHkukBicCdNoshiten
			FROM
				MBANK_ZOKUSEI
			WHERE ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND FINANCIAL_SECURITIES_KBN = SUBSTR(l_inHkukCd,1,1)
			AND BANK_CD = SUBSTR(l_inHkukCd,2,4);
		EXCEPTION
			WHEN no_data_found THEN
				CALL pkLog.info('pkIpaName','getSknShrninCd','金融機関属性マスタにデータが存在しない。');
				RETURN NULL;
		END;

		IF coalesce(trim(both pHkukBicCdNoshiten)::text, '') = '' THEN
			CALL pkLog.info('pkIpaName','getSknShrninCd','金融機関属性マスタにＢＩＣコード（支店コードなし）が設定されていない。');
			RETURN NULL;
		ELSE
			CALL pkLog.debug('pkIpaName','getSknShrninCd','引受会社コードの金融機関属性マスタ.ＢＩＣコード（支店コードなし）：' || pHkukBicCdNoshiten);
		END IF;

		-- 委託会社・銘柄より銘柄基本.発行年月日を取得
		BEGIN
			SELECT
				HAKKO_YMD
			INTO STRICT
				pHakkoYmd
			FROM
				MGR_KIHON
			WHERE ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND MGR_CD = l_inMgrCd;
		EXCEPTION
			WHEN no_data_found THEN
				CALL pkLog.info('pkIpaName','getSknShrninCd','銘柄基本にデータが存在しない。');
				RETURN NULL;
		END;

		IF coalesce(trim(both pHakkoYmd)::text, '') = '' THEN
			CALL pkLog.info('pkIpaName','getSknShrninCd','銘柄基本に発行年月日が設定されていない。');
			RETURN NULL;
		ELSE
			CALL pkLog.debug('pkIpaName','getSknShrninCd','銘柄基本.発行年月日：' || pHakkoYmd);
		END IF;

		-- 委託会社・ファンド・ＢＩＣコード（支店コードなし）・発行年月日よりSSIマスタ.資金支払人コード（金融機関識別コード）を取得
		BEGIN
			SELECT
				SKN_SHRNIN_CD
			INTO STRICT
				pResult
			FROM
				MSSI
			WHERE ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND FUND_CD = l_inFundCd
			AND KESSAI_PARTY_CD = pHkukBicCdNoshiten
			AND YUKO_KESSAI_YMD =
									(
										SELECT
											trim(both MAX(YUKO_KESSAI_YMD))
										FROM
											MSSI
											WHERE ITAKU_KAISHA_CD = l_inItakuKaishaCd
											AND FUND_CD = l_inFundCd
											AND KESSAI_PARTY_CD = pHkukBicCdNoshiten
											AND YUKO_KESSAI_YMD <= pHakkoYmd
									);
		EXCEPTION
			WHEN no_data_found THEN
				CALL pkLog.info('pkIpaName','getSknShrninCd','SSIマスタにデータが存在しない。');
				RETURN NULL;
		END;

		IF coalesce(trim(both pResult)::text, '') = '' THEN
			CALL pkLog.info('pkIpaName','getSknShrninCd','SSIマスタに資金支払人コードが設定されていない。');
			RETURN NULL;
		END IF;

		CALL pkLog.debug('pkIpaName','getSknShrninCd','資金支払人コード（金融機関識別コード）：' || pResult);
		CALL pkLog.debug('pkIpaName','getSknShrninCd','終了');
		RETURN pResult;

	EXCEPTION
		WHEN OTHERS THEN
			CALL pkLog.fatal('ECM701','pkIpaName',SQLSTATE || SUBSTR(SQLERRM,1,100));
			RETURN NULL;
	END;
$body$
LANGUAGE PLPGSQL
;

CREATE OR REPLACE FUNCTION pkipaname.getsknshrnincdtosknkessaicd (
	l_inItakuKaishaCd MSSI.ITAKU_KAISHA_CD%TYPE,
	l_inSknShrninCd MSSI.SKN_SHRNIN_CD%TYPE
) RETURNS MBANK_SHITEN_ZOKUSEI.SKN_KESSAI_CD%TYPE AS $body$
DECLARE

		pBicCdNoshiten MBANK_ZOKUSEI.BIC_CD_NOSHITEN%TYPE;
		pBankCd        varchar(8);
		pBicShitenCd   MBANK_SHITEN_ZOKUSEI.BIC_SHITEN_CD%TYPE;
		pResult        MBANK_SHITEN_ZOKUSEI.SKN_KESSAI_CD%TYPE;

BEGIN
		CALL pkLog.debug('pkIpaName','getSknShrninCdToSknKessaiCd','引数：委託会社コード：' || l_inItakuKaishaCd);
		CALL pkLog.debug('pkIpaName','getSknShrninCdToSknKessaiCd','引数：資金支払人コード：' || l_inSknShrninCd);

		-- 引数チェック
		-- 委託会社コード
		IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' THEN
			CALL pkLog.info('pkIpaName','getSknShrninCdToSknKessaiCd','委託会社コード未入力');
			RETURN NULL;
		END IF;

		-- 資金支払人コード
		IF coalesce(trim(both l_inSknShrninCd)::text, '') = '' THEN
			CALL pkLog.info('pkIpaName','getSknShrninCdToSknKessaiCd','資金支払人コード未入力');
			RETURN NULL;
		END IF;

		-- 資金支払人コードから金融機関属性マスタ.ＢＩＣコード（支店コードなし）を取得
		pBicCdNoshiten := pkipaname.getbicnoshitencd(l_inSknShrninCd);
		IF coalesce(trim(both pBicCdNoshiten)::text, '') = '' THEN
			CALL pkLog.info('pkIpaName','getSknShrninCdToSknKessaiCd','金融機関属性マスタにＢＩＣコード（支店コードなし）が設定されていない。');
			RETURN NULL;
		ELSE
			CALL pkLog.debug('pkIpaName','getSknShrninCdToSknKessaiCd','金融機関属性マスタ.ＢＩＣコード（支店コードなし）：' || pBicCdNoshiten);
		END IF;

		-- 金融機関マスタ.ＢＩＣコード（支店コードなし）より金融機関コードを取得
		pBankCd :=  pkipaname.getbankcd(l_inItakuKaishaCd,pBicCdNoshiten,'1');
		IF coalesce(trim(both pBankCd)::text, '') = '' THEN
			CALL pkLog.info('pkIpaName','getSknShrninCdToSknKessaiCd','金融機関属性マスタ.ＢＩＣコード（支店コードなし）から金融機関コードを特定できない。');
			RETURN NULL;
		ELSE
			CALL pkLog.debug('pkIpaName','getSknShrninCdToSknKessaiCd','金融機関コード：' || pBankCd);
		END IF;

		-- 資金支払人コードから金融機関支店属性マスタ.ＢＩＣ支店コードを取得
		pBicShitenCd := pkipaname.getbicshitencd(l_inSknShrninCd);
		CALL pkLog.debug('pkIpaName','getSknShrninCdToSknKessaiCd','金融機関支店属性マスタ.ＢＩＣ支店コード：' || pBicShitenCd);
		-- Trimした金融機関支店属性マスタ.ＢＩＣ支店コードが「NULL」または「XXX」
		IF coalesce(trim(both pBicShitenCd)::text, '') = '' OR trim(both pBicShitenCd) = 'XXX' THEN
			pBicShitenCd := '   ';
		END IF;

		-- 委託会社・金融機関コード・ＢＩＣ支店コードより金融機関支店属性マスタ.資金決済会社コードを取得
		SELECT
			trim(both MIN(SKN_KESSAI_CD))
		INTO STRICT
			pResult
		FROM
			MBANK_SHITEN_ZOKUSEI
		WHERE ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND FINANCIAL_SECURITIES_KBN = SUBSTR(pBankCd,1,1)
		AND BANK_CD = SUBSTR(pBankCd,2,4)
		AND (BIC_SHITEN_CD = pBicShitenCd OR coalesce(trim(both pBicShitenCd)::text, '') = '')
		AND (trim(both SKN_KESSAI_CD) IS NOT NULL AND (trim(both SKN_KESSAI_CD))::text <> '');

		CALL pkLog.debug('pkIpaName','getSknShrninCdToSknKessaiCd','金融機関支店属性マスタ.資金決済会社コード：' || pResult);
		CALL pkLog.debug('pkIpaName','getSknShrninCdToSknKessaiCd','終了');
		RETURN pResult;

	EXCEPTION
		WHEN OTHERS THEN
			CALL pkLog.fatal('ECM701','pkIpaName',SQLSTATE || SUBSTR(SQLERRM,1,100));
			RETURN NULL;
	END;
$body$
LANGUAGE PLPGSQL
;

CREATE OR REPLACE FUNCTION pkipaname.getfundcdtosknkessaicd (
	l_inItakuKaishaCd MSSI.ITAKU_KAISHA_CD%TYPE,
	l_inMgrCd SHINKIBOSHU.MGR_CD%TYPE,
	l_inHkukCd text,
	l_inFundCd MSSI.FUND_CD%TYPE
) RETURNS MBANK_SHITEN_ZOKUSEI.SKN_KESSAI_CD%TYPE AS $body$
DECLARE

		pSknShrninCd MSSI.SKN_SHRNIN_CD%TYPE;

BEGIN
		CALL pkLog.debug('pkIpaName','getFundCdToSknKessaiCd','開始');
		CALL pkLog.debug('pkIpaName','getFundCdToSknKessaiCd','引数：委託会社コード：' || l_inItakuKaishaCd);
		CALL pkLog.debug('pkIpaName','getFundCdToSknKessaiCd','引数：銘柄コード：' || l_inMgrCd);
		CALL pkLog.debug('pkIpaName','getFundCdToSknKessaiCd','引数：引受会社コード：' || l_inHkukCd);
		CALL pkLog.debug('pkIpaName','getFundCdToSknKessaiCd','引数：ファンドコード：' || l_inFundCd);

		-- 引数チェック
		-- 委託会社コード
		IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' THEN
			CALL pkLog.info('pkIpaName','getFundCdToSknKessaiCd','委託会社コード未入力');
			RETURN NULL;
		END IF;

		-- 銘柄コード
		IF coalesce(trim(both l_inMgrCd)::text, '') = '' THEN
			CALL pkLog.info('pkIpaName','getFundCdToSknKessaiCd','銘柄コード未入力');
			RETURN NULL;
		END IF;

		-- 引受会社コード
		IF coalesce(trim(both l_inHkukCd)::text, '') = '' THEN
			CALL pkLog.info('pkIpaName','getFundCdToSknKessaiCd','引受会社コード未入力');
			RETURN NULL;
		END IF;

		-- ファンドコード
		IF coalesce(trim(both l_inFundCd)::text, '') = '' THEN
			CALL pkLog.info('pkIpaName','getFundCdToSknKessaiCd','ファンドコード未入力');
			RETURN NULL;
		END IF;

		-- 委託会社・銘柄・引受会社・ファンドよりSSIマスタ.資金支払人コード（金融機関識別コード）を取得
		pSknShrninCd := pkipaname.getsknshrnincd(l_inItakuKaishaCd,l_inMgrCd,l_inHkukCd,l_inFundCd);
		IF coalesce(trim(both pSknShrninCd)::text, '') = '' THEN
			RETURN NULL;
		END IF;

		-- 委託会社・資金支払人コードより金融機関支店属性マスタ.資金決済会社コードを取得
		RETURN pkipaname.getsknshrnincdtosknkessaicd(l_inItakuKaishaCd,pSknShrninCd);

	EXCEPTION
		WHEN OTHERS THEN
			CALL pkLog.fatal('ECM701','pkIpaName',SQLSTATE || SUBSTR(SQLERRM,1,100));
			RETURN NULL;
	END;
$body$
LANGUAGE PLPGSQL
;

--	 * 対象となるSSIマスタの資金決済方法コードを返します。
--	 * また、対象となるSSIマスタの受方資金決済口座番号(2桁目から7桁)と
--	 * 金融機関属性マスタの資金決済会社コードが等しい場合、
--	 * その受方資金決済口座番号もout引数として値を保持します。
--	 * out引数の「l_outUkeSknKsskznoSsi」は、呼び出した側で使う場合は
--	 * trimをかけることを忘れずに。
--	 *
--	 * @author  桑原　昭治
--	 * @param   l_inItakuKaichaCd			委託会社コード
--	 * @param   l_inMgrCd					銘柄コード
--	 * @param   l_inHkukCd					引受会社コード
--	 * @param   l_inFundCd					ファンドコード
--	 * @param	l_outUkeSknKsskznoSsi		受方資金決済口座番号
--	 * @return  資金決済方法コード
--
CREATE OR REPLACE FUNCTION pkipaname.getsknkessaimethodcd (
	l_inItakuKaishaCd MSSI.ITAKU_KAISHA_CD%TYPE,
	l_inMgrCd SHINKIBOSHU.MGR_CD%TYPE,
	l_inHkukCd text,
	l_inFundCd MSSI.FUND_CD%TYPE,
	l_outUkeSknKsskznoSsi OUT text ,
	OUT extra_param MSSI.SKN_KESSAI_METHOD_CD%TYPE
) RETURNS record AS $body$
DECLARE

		sknKessaiMethodCd	MSSI.SKN_KESSAI_METHOD_CD%TYPE;
		ukeSknKsskznoSsi	MSSI.UKE_SKN_KSSKZNO_SSI%TYPE;
		pBicCdNoshiten		MBANK_ZOKUSEI.BIC_CD_NOSHITEN%TYPE;
		pHakkoYmd			MGR_KIHON.HAKKO_YMD%TYPE;
		cnt					numeric;

BEGIN
		-- 引数チェック
		IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' THEN
			CALL pkLog.info('pkIpaName','getSknKessaiMethodCd','委託会社コード未入力');
			extra_param := NULL;
			RETURN;
		END IF;
		IF coalesce(trim(both l_inMgrCd)::text, '') = '' THEN
			CALL pkLog.info('pkIpaName','getSknKessaiMethodCd','銘柄コード未入力');
			extra_param := NULL;
			RETURN;
		END IF;
		IF coalesce(trim(both l_inHkukCd)::text, '') = '' THEN
			CALL pkLog.info('pkIpaName','getSknKessaiMethodCd','引受会社コード未入力');
			extra_param := NULL;
			RETURN;
		END IF;
		IF coalesce(trim(both l_inFundCd)::text, '') = '' THEN
			CALL pkLog.info('pkIpaName','getSknKessaiMethodCd','ファンドコード未入力');
			extra_param := NULL;
			RETURN;
		END IF;

		-- 初期化
		l_outUkeSknKsskznoSsi := NULL;
		sknKessaiMethodCd := NULL;
		ukeSknKsskznoSsi := NULL;
		pBicCdNoshiten := NULL;
		pHakkoYmd := NULL;
		cnt := 0;

		-- 委託会社・引受会社より金融機関属性マスタ.ＢＩＣコード（支店コードなし）を取得
		BEGIN
			SELECT
				M08.BIC_CD_NOSHITEN
			INTO STRICT
				pBicCdNoshiten
			FROM
				MBANK_ZOKUSEI M08
			WHERE M08.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND M08.FINANCIAL_SECURITIES_KBN = SUBSTR(l_inHkukCd,1,1)
			AND M08.BANK_CD = SUBSTR(l_inHkukCd,2,4);
		EXCEPTION
			WHEN no_data_found THEN
				CALL pkLog.info('pkIpaName','getSknKessaiMethodCd','金融機関属性マスタにデータが存在しない。');
				extra_param := NULL;
				RETURN;
		END;

		-- 委託会社・銘柄より銘柄基本.発行年月日を取得
		BEGIN
			SELECT
				MG1.HAKKO_YMD
			INTO STRICT
				pHakkoYmd
			FROM
				MGR_KIHON MG1
			WHERE MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND MG1.MGR_CD = l_inMgrCd;
		EXCEPTION
			WHEN no_data_found THEN
				CALL pkLog.info('pkIpaName','getSknKessaiMethodCd','銘柄基本にデータが存在しない。');
				extra_param := NULL;
				RETURN;
		END;

		-- 対象となるSSI情報の資金決済方法コードと
		-- 受方資金決済口座番号を取得する。
		BEGIN
			SELECT
				M112.SKN_KESSAI_METHOD_CD,
				M112.UKE_SKN_KSSKZNO_SSI
			INTO STRICT
				sknKessaiMethodCd,
				ukeSknKsskznoSsi
			FROM
				MSSI M112
			WHERE M112.ITAKU_KAISHA_CD = l_inItakuKaishaCd
			AND M112.FUND_CD = l_inFundCd
			AND M112.KESSAI_PARTY_CD = pBicCdNoshiten
			AND M112.YUKO_KESSAI_YMD =	(	SELECT
												trim(both MAX(M111.YUKO_KESSAI_YMD))
											FROM
												MSSI M111
											WHERE M111.ITAKU_KAISHA_CD = l_inItakuKaishaCd
											AND M111.FUND_CD = l_inFundCd
											AND M111.KESSAI_PARTY_CD = pBicCdNoshiten
											AND M111.YUKO_KESSAI_YMD <= pHakkoYmd
										);
		EXCEPTION
			WHEN no_data_found THEN
				extra_param := NULL;
				RETURN;
		END;

		-- 対象となるSSI情報の受方資金決済口座番号(2桁目から7桁)と金融機関支店属性マスタの
		-- 資金決済会社コードが等しければ受方資金決済口座番号を変数に格納
		SELECT
			COUNT(*)
		INTO STRICT
			cnt
		FROM
			MBANK_SHITEN_ZOKUSEI M10
		WHERE
			M10.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND	M10.SKN_KESSAI_CD =	SUBSTR(ukeSknKsskznoSsi,2,7);

		--金融機関支店属性に対象データがある場合のみ、out引数にセット。
		--０件や２件以上あった場合はNULLをセットする。
		IF cnt = 1 THEN
			l_outUkeSknKsskznoSsi := ukeSknKsskznoSsi;
		ELSE
			l_outUkeSknKsskznoSsi := NULL;
		END IF;

		extra_param := sknKessaiMethodCd;

		RETURN;

	EXCEPTION
		WHEN OTHERS THEN
			CALL pkLog.fatal('ECM701','pkIpaName',SQLSTATE || SUBSTR(SQLERRM,1,100));
			extra_param := NULL;
			RETURN;
	END;
$body$
LANGUAGE PLPGSQL
;

	--
--	 * 資金決済会社略称取得処理
--	 *
--	 * @author  山下　健太
--	 * @param   l_inItakuKaichaCd           委託会社コード
--	 * @param   l_inSknKessaiCd             資金決済会社コード
--	 * @return  資金決済会社略称         VARCHAR2
--
CREATE OR REPLACE FUNCTION pkipaname.getsknkessairnm (
	l_inItakuKaichaCd text,
	l_inSknKessaiCd text
) RETURNS varchar AS $body$
DECLARE

	--====================================================================*
--	                  変数定義
--	 *====================================================================
		cnt					integer := 0;
		ret					varchar(100) := ' ';
	--====================================================================*
--	        メイン
--	 *====================================================================

BEGIN

		-- 金融機関支店属性から、件数を取得
		SELECT COUNT(M10.SKN_KESSAI_CD) INTO STRICT cnt FROM MBANK_SHITEN_ZOKUSEI M10
									WHERE M10.ITAKU_KAISHA_CD = l_inItakuKaichaCd
									AND   M10.SKN_KESSAI_CD = l_inSknKessaiCd;

		-- 存在する場合、金融機関マスタと金融機関支店マスタから略称を取得
		IF cnt = 1 THEN

			SELECT (M02.BANK_RNM || M03.SHITEN_RNM) INTO STRICT ret
			FROM
				MBANK M02,MBANK_SHITEN M03,MBANK_SHITEN_ZOKUSEI M10
			WHERE   M10.ITAKU_KAISHA_CD = l_inItakuKaichaCd
				AND M10.SKN_KESSAI_CD = l_inSknKessaiCd
				AND M10.BANK_CD = M03.BANK_CD
				AND M10.SHITEN_CD = M03.SHITEN_CD
				AND M10.FINANCIAL_SECURITIES_KBN = M03.FINANCIAL_SECURITIES_KBN
				AND M03.BANK_CD = M02.BANK_CD
				AND M03.FINANCIAL_SECURITIES_KBN = M02.FINANCIAL_SECURITIES_KBN;

		END IF;

		RETURN ret;

	EXCEPTION
		WHEN OTHERS THEN
			CALL pkLog.fatal('ECM701','pkIpaName',SQLSTATE || SUBSTR(SQLERRM,1,100));
			RETURN NULL;
	END;
$body$
LANGUAGE PLPGSQL
;
