


DROP TYPE IF EXISTS spipx046k15r03_type_record;
CREATE TYPE spipx046k15r03_type_record AS (
		ITAKU_KAISHA_CD		char(4),	 -- 委託会社コード
		MGR_CD			varchar(13),		 -- 銘柄コード
		RBR_KJT			char(8),	 -- 利払期日
		CHOKYU_YMD		char(8)	 -- 徴求日
	);


CREATE OR REPLACE PROCEDURE spipx046k15r03 (l_inUserId text, -- ユーザーID
 l_inItakuKaishaCd CHAR, -- 委託会社コード
 l_inKijunYmdFrom CHAR, -- 基準日From
 l_inKijunYmdTo CHAR, -- 基準日To
 l_inKknZndkKjnYmdKbn text, -- 基金残高基準日区分
 l_inHktCd CHAR, -- 発行体CD
 l_inKozatenCd text, -- 口座店CD
 l_inKozatenCifCd CHAR, -- 口座店CIFCD
 l_inMgrCd text, -- 銘柄CD
 l_inIsinCd CHAR, -- ISINCD
 l_inTsuchiYmd text, -- 通知日
 l_inCktOptFlg text, -- 地公体オプション判別フラグ
 l_inFrntPrtOutOptFlg text, -- フロント照会帳票出力指示のオプション判別フラグ
 l_outSqlCode OUT integer, -- リターン値
 l_outSqlErrM OUT text -- エラーコメント
 ) AS $body$
DECLARE

  --
--   * 著作権:Copyright(c)2016
--   * 会社名:JIP
--   * 概要　:元利払基金・手数料請求書【単票】を作成する。
--   *
--   * @param    l_inUserId              IN  CHAR        ユーザーID
--   * @param    l_inItakuKaishaCd       IN  CHAR        委託会社コード
--   * @param    l_inKijunYmdFrom	       IN  CHAR        基準日From
--   * @param    l_inKijunYmdTo          IN  CHAR	       基準日To
--   * @param    l_inKknZndkKjnYmdKbn    IN  VARCHAR2    基金残高基準日区分
--   * @param    l_inHktCd    	       IN  CHAR        発行体CD
--   * @param    l_inKozatenCd	       IN VARCHAR2     口座店CD
--   * @param    l_inKozatenCifCd	       IN VARCHAR2     口座店CIFCD
--   * @param    l_inMgrCd 	       IN CHAR	       銘柄CD
--   * @param    l_inIsinCd 	       IN CHAR	       ISINCD
--   * @param    l_inTsuchiYmd 	       IN CHAR	       通知日
--   * @param    l_inCktOptFlg 	       IN VARCHAR2     地公体オプション判別フラグ
--   * @param    l_inFrntPrtOutOptFlg    IN VARCHAR2     フロント照会帳票出力指示のオプション判別フラグ
--   * @param    l_outSqlCode            OUT INTEGER     リターン値
--   * @param    l_outSqlErrM            OUT VARCHAR2    エラーコメント
--   *
--   * @return なし
--   *
--   * @author Y.Nagano
--   * @version $Id: SPIPX046K15R03.sql,v 1.00 2016.12.21 11:09:18 Y.Nagano Exp $
--   *
--   
  --==============================================================================
  --                    変数定義                                                  
  --==============================================================================
	gReturnCode     integer := 0;				 -- リターンコード
 	gSQL		varchar(10000) := NULL;			 -- SQL格納用変数
	gSeqNo		integer := 0;				 -- カウンター
	gGyomuYmd	SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;		 -- 業務日付
	gKjtFrom	MGR_TESKIJ.CHOKYU_KJT%TYPE;		 	 -- 基準日Ｆｒｏｍ
	gKjtTo		MGR_TESKIJ.CHOKYU_KJT%TYPE;		 	 -- 基準日Ｔｏ
	gOptionFlg	MOPTION_KANRI.OPTION_FLG%TYPE;			 -- オプションフラグ
	gREPORT_ID	CONSTANT text := 'IP931504661';		 -- レポートＩＤ
	gCur refcursor;			 -- カーソル
	-- レコード
	rec spipx046k15r03_type_record[];
	temp_rec spipx046k15r03_type_record;
  --==============================================================================
  --    メイン処理    
  --==============================================================================
BEGIN
	-- 業務日付取得
	gGyomuYmd := pkDate.getGyomuYmd();
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inKijunYmdFrom)::text, '') = '' OR coalesce(trim(both l_inKijunYmdTo)::text, '') = '' THEN
	  	-- ログ書込み
	      CALL pkLog.error('ECM501', 'SPIPX046K15R03', '');
	      l_outSqlCode := pkconstant.error();
	      l_outSqlErrM := '';
	      RETURN;
	END IF;
	-- 基準日の設定
	gKjtFrom := l_inKijunYmdFrom;
	gKjtTo := l_inKijunYmdTo;
	-- カーソルの取得
	gSQL := pkIpaKknIdo.createSQL(gGyomuYmd, l_inKijunYmdFrom, l_inKijunYmdTo, l_inItakuKaishaCd, l_inHktCd, l_inKozatenCd, l_inKozatenCifCd, l_inMgrCd, l_inIsinCd, '0', '', '');
	-- カーソルオープン
	OPEN gCur FOR EXECUTE gSQL;
	LOOP
		-- Fetch into temp record
		FETCH gCur INTO
			temp_rec.ITAKU_KAISHA_CD,
			temp_rec.MGR_CD,
			temp_rec.RBR_KJT,
			temp_rec.CHOKYU_YMD;
		-- データが無くなったらループを抜ける
		EXIT WHEN NOT FOUND;/* apply on gCur */
		-- Append to array
		rec := array_append(rec, temp_rec);
		gSeqNo := gSeqNo + 1;
		-- 基金請求計算処理
		gReturnCode := sfInsKikinIdo(l_inUserId,
					     temp_rec.ITAKU_KAISHA_CD,
					     temp_rec.MGR_CD,
					     temp_rec.RBR_KJT,
					     temp_rec.CHOKYU_YMD,
					     '1',
					     '0',
					     l_inKknZndkKjnYmdKbn
					    );
		-- 処理結果が正常でない場合
		IF gReturnCode <> pkconstant.success() THEN
			l_outSqlCode := gReturnCode;
			l_outSqlErrM := '基金請求計算処理（データ作成区分1）が失敗しました。';
			CALL pkLog.fatal('ECM701', 'SPIPX046K15R03', l_outSqlCode || l_outSqlErrM);
			RETURN;
		END IF;
	-- レコード数分ループの終了
	END LOOP;
	-- カーソルクローズ
	CLOSE gCur;
	-- 実質記番号オプション判定
	BEGIN
		SELECT
			OPTION_FLG
		INTO STRICT
			gOptionFlg
		FROM
			MOPTION_KANRI
		WHERE
			KEY_CD = l_inItakuKaishaCd
		  AND   OPTION_CD = 'IPP1003302010';
	EXCEPTION
		WHEN no_data_found THEN
			gOptionFlg := '0';
	END;
	IF gOptionFlg = '1' THEN
		-- 実質記番号管理オプション　基金異動計算・更新処理
		gReturnCode := pkIpaKibango.insKknIdo(
							l_inUserId,
							l_inKijunYmdFrom,
							l_inKijunYmdTo,
							l_inItakuKaishaCd,
							l_inHktCd,
							l_inKozatenCd,
							l_inKozatenCifCd,
							l_inMgrCd,
							l_inIsinCd,
							gREPORT_ID,
							'0',
							'1',
							l_inKknZndkKjnYmdKbn,
							l_outSqlErrM
						     );
	END IF;
	-- 処理結果が正常でない場合
	IF gReturnCode <> pkconstant.success() THEN
		l_outSqlCode := gReturnCode;
		CALL pkLog.fatal('ECM701', 'SPIPX046K15R03', l_outSqlCode || l_outSqlErrM);
		RETURN;
	END IF;
	-- 元利払基金・手数料請求書（領収書）【単票】の作成
	CALL SPIPX046K15R02(l_inUserId, gGyomuYmd, l_inKijunYmdFrom, l_inKijunYmdTo, l_inItakuKaishaCd, l_inHktCd, l_inKozatenCd, l_inKozatenCifCd, l_inMgrCd, l_inIsinCd, l_inTsuchiYmd, gREPORT_ID, '0', gReturnCode, l_outSqlErrM);
	-- 終了処理
	l_outSqlCode := gReturnCode;
	l_outSqlErrM := '';
-- エラー処理
EXCEPTION
  WHEN OTHERS THEN
    CALL pkLog.fatal('ECM701', 'SPIPX046K15R03', 'SQLCODE:' || SQLSTATE);
    CALL pkLog.fatal('ECM701', 'SPIPX046K15R03', 'SQLERRM:' || SQLERRM);
    l_outSqlCode := pkconstant.FATAL();
    l_outSqlErrM := SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipx046k15r03 (l_inUserId text, l_inItakuKaishaCd CHAR, l_inKijunYmdFrom CHAR, l_inKijunYmdTo CHAR, l_inKknZndkKjnYmdKbn text, l_inHktCd CHAR, l_inKozatenCd text, l_inKozatenCifCd CHAR, l_inMgrCd text, l_inIsinCd CHAR, l_inTsuchiYmd text, l_inCktOptFlg text, l_inFrntPrtOutOptFlg text, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;