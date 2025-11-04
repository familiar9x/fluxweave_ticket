CREATE OR REPLACE FUNCTION sfIph999_TESYURYO_KAIKEI
(
	l_inItakuKaisyaCode IN TESURYO.ITAKU_KAISHA_CD%TYPE,
	l_inMeigaraCode IN TESURYO.MGR_CD%TYPE,
	l_inTesuShuruiCd IN TESURYO_KAIKEI.TESU_SHURUI_CD%TYPE,
	l_inUserId IN TESURYO_KAIKEI.SAKUSEI_ID%TYPE,
	l_inGroupId IN TESURYO_KAIKEI.GROUP_ID%TYPE
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $body$
/**
 * 著作権: Copyright (c) 2005
 * 会社名: JIP
 *
 * 手数料計算結果、銘柄_基本、会計区分マスタ、会計区分別按分額をもとに
 * データを作成する
 *
 * @author 大田　英子
 * @version $Revision: 1.6 $
 */
/**
 *
 * 手数料計算結果、銘柄_基本、会計区分マスタ、会計区分別按分額をもとに
 * 手数料計算結果(会計区分別)データを作成する
 *
 * @param  l_inItakuKaisyaCode IN 委託会社コード
 * @param  l_inMeigaraCode IN 銘柄コード
 * @param  l_inTesuShuruiCd IN 手数種類コード
 * @param  l_inUserId IN ユーザーID
 * @param  l_inGroupId IN グループID
 * @return INTEGER 0:正常、99:異常
 */
DECLARE
/*====================================================================*/
/*					デバッグ機能										  */
/*====================================================================*/
	DEBUG	NUMERIC(1)	DEFAULT 0;

/*====================================================================*
            変数定義
 *====================================================================*/
/*端数処理をする会計区分*/
	gKaikeiKubun TESURYO_KAIKEI.KAIKEI_KBN%TYPE DEFAULT ' ';
/*最小端数調整順位*/
	gMinHasuChoseiJuni KAIKEI_KBN.HASU_CHOSEI_JUNI%TYPE DEFAULT 0;
/*会計区分カウント用(会計区分マスタ)*/
	gCountKaikeiKubunM NUMERIC(9) DEFAULT 0;
/*会計区分カウント用(会計区分別按分額)*/
	gCountKaikeiKubunA NUMERIC(9) DEFAULT 0;
/*端数調整順位カウント用*/
	gCountHasuChoseiJuni NUMERIC(9) DEFAULT 0;
/*最大会計区分別按分額*/
	gMaxKaikeiKbnAnbunKngk KAIKEI_ANBUN.KAIKEI_KBN_ANBUN_KNGK%TYPE DEFAULT 0;
/*更新前手数料額取得用*/
	gTesuKngk TESURYO_KAIKEI.ANBUN_TESU_KNGK_KOMI%TYPE DEFAULT 0;
/*更新前消費税額取得用*/
	gSzei TESURYO_KAIKEI.ANBUN_TESU_SZEI%TYPE DEFAULT 0;
/*取得レコード数*/
	gRecT01_H02 NUMERIC(9) DEFAULT 0;
/*ログ出力用メッセージパラメータ*/
	message VARCHAR(200);
/*プログラムID*/
	program_id CONSTANT CHAR(24)	:= 'sfIph999_TESYURYO_KAIKEI';

/*====================================================================*
		レコード定義
 *====================================================================*/
	recTesyuryo RECORD;
	recTesyuryoHasu RECORD;

/*====================================================================*
   		メイン
 *====================================================================*/
BEGIN

	IF DEBUG = 1 THEN
		CALL pkLog.debug(l_inUserId, program_id, program_id || ' START');
	END IF;

	/*手数料計算結果(会計区分別)テーブルに既にデータが存在する場合DELETE*/
	DELETE
	FROM
		TESURYO_KAIKEI H03
	WHERE
		H03.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
	AND	H03.MGR_CD = l_inMeigaraCode
	AND (H03.TESU_SHURUI_CD = l_inTesuShuruiCd
	OR H03.TESU_SHURUI_CD = '00');
      
	/*手数料計算結果(会計区分別)テーブル登録処理*/
	FOR recTesyuryo IN (
	SELECT
		T01.TESU_SHURUI_CD AS TESU_SHURUI_CD,
		T01.JTK_KBN AS JTK_KBN,
		T01.CHOKYU_KJT AS CHOKYU_KJT,
		T01.CHOKYU_YMD AS CHOKYU_YMD,
		MG1.SHASAI_TOTAL AS KIJUN_ZNDK,
		T01.TESU_RITSU_BUNBO AS TESU_RITSU_BUNBO,
		T01.TESU_RITSU_BUNSHI AS TESU_RITSU_BUNSHI,
		T01.ALL_TESU_KNGK AS ALL_TESU_KNGK,
		T01.ALL_TESU_SZEI AS ALL_TESU_SZEI,
		H01.KOUSAIHI_FLG AS KOUSAIHI_FLG,
		H02.KAIKEI_KBN AS KAIKEI_KBN,
		H02.KAIKEI_KBN_ANBUN_KNGK AS KAIKEI_KBN_ANBUN_KNGK
	FROM
		TESURYO T01,
		KAIKEI_KBN H01,
		KAIKEI_ANBUN H02,
		MGR_KIHON MG1
	WHERE
			T01.ITAKU_KAISHA_CD = H02.ITAKU_KAISHA_CD
		AND	T01.MGR_CD = H02.MGR_CD
		AND	T01.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
		AND	T01.MGR_CD = MG1.MGR_CD
		AND	MG1.ITAKU_KAISHA_CD = H01.ITAKU_KAISHA_CD
		AND	MG1.HKT_CD = H01.HKT_CD
		AND	H01.ITAKU_KAISHA_CD = H02.ITAKU_KAISHA_CD
		AND	H01.KAIKEI_KBN = H02.KAIKEI_KBN
		AND	H02.ITAKU_KAISHA_CD = MG1.ITAKU_KAISHA_CD
		AND	H02.MGR_CD = MG1.MGR_CD
		AND	T01.ITAKU_KAISHA_CD = H01.ITAKU_KAISHA_CD
		AND	T01.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
		AND	T01.MGR_CD = l_inMeigaraCode
    	AND T01.TESU_SHURUI_CD = l_inTesuShuruiCd
	ORDER BY
		T01.TESU_SHURUI_CD,
		H02.KAIKEI_KBN
	) LOOP
		gRecT01_H02 := gRecT01_H02 + 1;
		INSERT INTO TESURYO_KAIKEI(
					ITAKU_KAISHA_CD,		--委託会社コード
					MGR_CD,				--銘柄コード
					TESU_SHURUI_CD,			--手数料種類コード
					CHOKYU_KJT,			--徴求期日
					KAIKEI_KBN,			--会計区分
					JTK_KBN,			--受託区分
					CHOKYU_YMD,			--徴求日
					RATE_BUNSHI,			--手数料率(分子)
					RATE_BUNBO,			--手数料率(分母)
					ANBUN_TESU_KNGK_KOMI,		--按分額手数料(税込)
					ANBUN_TESU_SZEI,		--按分額手数料消費税
					ANBUN_HOSEI_TESU_KNGK_KOMI,	--補正額_按分額手数料(税込)
					ANBUN_HOSEI_TESU_SZEI,		--補正額_按分額手数料消費税
					KOUSAIHI_FLG,			--公債費フラグ
					GROUP_ID,			--グループID
					SAKUSEI_ID)			--作成者
				--	KOUSIN_DT,			--更新日時
				--	KOUSIN_ID,  			--更新者
				--	SAKUSEI_DT,			--作成日時
			VALUES(
					l_inItakuKaisyaCode,
					l_inMeigaraCode,
					l_inTesuShuruiCd,
					recTesyuryo.CHOKYU_KJT,
					recTesyuryo.KAIKEI_KBN,
					recTesyuryo.JTK_KBN,
					recTesyuryo.CHOKYU_YMD,
					recTesyuryo.TESU_RITSU_BUNSHI,
					recTesyuryo.TESU_RITSU_BUNBO,
					TRUNC((recTesyuryo.ALL_TESU_KNGK
						* recTesyuryo.KAIKEI_KBN_ANBUN_KNGK / recTesyuryo.KIJUN_ZNDK)
						+
						(recTesyuryo.ALL_TESU_SZEI
						* recTesyuryo.KAIKEI_KBN_ANBUN_KNGK / recTesyuryo.KIJUN_ZNDK)),
					TRUNC(recTesyuryo.ALL_TESU_SZEI
						* recTesyuryo.KAIKEI_KBN_ANBUN_KNGK / recTesyuryo.KIJUN_ZNDK),
					0,
					0,
					recTesyuryo.KOUSAIHI_FLG,
					l_inGroupId,
					l_inUserId);
	END LOOP;
	
	/*該当データが存在した場合*/
	IF
		gRecT01_H02 > 1
	THEN
	/*手数料計算結果(会計区分別)テーブルが複数登録された場合端数処理を行なう*/
	/*最小の端数調整順位抽出*/
		SELECT
			MIN(H01.HASU_CHOSEI_JUNI)
		INTO
			gMinHasuChoseiJuni
		FROM
			KAIKEI_KBN H01,
			KAIKEI_ANBUN H02,
			MGR_KIHON MG1
		WHERE
				MG1.HKT_CD = H01.HKT_CD
			AND	MG1.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
			AND	MG1.MGR_CD = l_inMeigaraCode
			AND	H01.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
			AND H01.ITAKU_KAISHA_CD = H02.ITAKU_KAISHA_CD 
			AND H01.KAIKEI_KBN = H02.KAIKEI_KBN
			AND H02.MGR_CD = l_inMeigaraCode
			AND	H01.KAIKEI_KBN <> '00';
		/*最小の端数調整順位がゼロの場合、ゼロ以外のアイテムをカウントする*/
		IF
			gMinHasuChoseiJuni = 0
		THEN
			SELECT
				COUNT(H01.HASU_CHOSEI_JUNI)
			INTO
				gCountHasuChoseiJuni
			FROM
				KAIKEI_KBN H01,
				KAIKEI_ANBUN H02,
				MGR_KIHON MG1
			WHERE
					MG1.HKT_CD = H01.HKT_CD
				AND	MG1.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
				AND	MG1.MGR_CD = l_inMeigaraCode
				AND	H01.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
				AND	H01.KAIKEI_KBN <> '00'
				AND H01.ITAKU_KAISHA_CD = H02.ITAKU_KAISHA_CD 
				AND H01.KAIKEI_KBN = H02.KAIKEI_KBN
				AND H02.MGR_CD = l_inMeigaraCode
				AND	H01.HASU_CHOSEI_JUNI <> 0;
			/*端数調整順位にゼロ以外のアイテムが存在する場合
		 	*そのなかから最小の端数調整順位を取得する
			*/
			IF
				gCountHasuChoseiJuni > 0
			THEN
				SELECT
					MIN(H01.HASU_CHOSEI_JUNI)
				INTO
					gMinHasuChoseiJuni
				FROM
					KAIKEI_KBN H01,
					KAIKEI_ANBUN H02,
					MGR_KIHON MG1
				WHERE
						MG1.HKT_CD = H01.HKT_CD
					AND	MG1.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
					AND	MG1.MGR_CD = l_inMeigaraCode
					AND	H01.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
					AND	H01.KAIKEI_KBN <> '00'
					AND H01.ITAKU_KAISHA_CD = H02.ITAKU_KAISHA_CD 
					AND H01.KAIKEI_KBN = H02.KAIKEI_KBN
					AND H02.MGR_CD = l_inMeigaraCode
					AND	H01.HASU_CHOSEI_JUNI <> 0;
			END IF;
		END IF;

		/*最小の端数調整順位を持つ会計区分をカウントする*/
		SELECT
			COUNT(H01.KAIKEI_KBN)
		INTO
			gCountKaikeiKubunM
		FROM
			KAIKEI_KBN H01,
			KAIKEI_ANBUN H02,
			MGR_KIHON MG1
		WHERE
				MG1.HKT_CD = H01.HKT_CD
			AND	MG1.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
			AND	MG1.MGR_CD = l_inMeigaraCode
			AND	H01.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
			AND	H01.KAIKEI_KBN <> '00'
			AND H01.ITAKU_KAISHA_CD = H02.ITAKU_KAISHA_CD 
			AND H01.KAIKEI_KBN = H02.KAIKEI_KBN
			AND H02.MGR_CD = l_inMeigaraCode
			AND	H01.HASU_CHOSEI_JUNI = gMinHasuChoseiJuni;
		/*
		 *最小の端数調整順位がゼロ以外でかつ最小の端数調整順位を持つ会計区分がユニークな場合
		 *その会計区分を端数処理をする会計区分とする
		 */
		IF
				gMinHasuChoseiJuni <> 0
			AND	gCountKaikeiKubunM = 1
		THEN
			SELECT
				H01.KAIKEI_KBN
			INTO
				gKaikeiKubun
			FROM
				KAIKEI_KBN H01,
				KAIKEI_ANBUN H02,
				MGR_KIHON MG1
			WHERE
					MG1.HKT_CD = H01.HKT_CD
				AND	MG1.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
				AND	MG1.MGR_CD = l_inMeigaraCode
				AND	H01.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
				AND	H01.KAIKEI_KBN <> '00'
				AND H01.ITAKU_KAISHA_CD = H02.ITAKU_KAISHA_CD 
				AND H01.KAIKEI_KBN = H02.KAIKEI_KBN
				AND H02.MGR_CD = l_inMeigaraCode
				AND	H01.HASU_CHOSEI_JUNI = gMinHasuChoseiJuni;
		ELSE
		/*会計区分別按分額テーブルより会計区分別按分額が最大の会計区分を求める
		 */
			SELECT
				MAX(KAIKEI_KBN_ANBUN_KNGK)
			INTO
				gMaxKaikeiKbnAnbunKngk
			FROM
				KAIKEI_ANBUN
			WHERE
					ITAKU_KAISHA_CD = l_inItakuKaisyaCode
				AND	MGR_CD = l_inMeigaraCode
				AND	KAIKEI_KBN <> '00';
		/*最大の会計区分別按分額を持つ会計区分をカウントする
		 */
			SELECT
				COUNT(KAIKEI_KBN)
			INTO
				gCountKaikeiKubunA
			FROM
				KAIKEI_ANBUN
			WHERE
					ITAKU_KAISHA_CD = l_inItakuKaisyaCode
				AND	MGR_CD = l_inMeigaraCode
				AND	KAIKEI_KBN <> '00'
				AND	KAIKEI_KBN_ANBUN_KNGK = gMaxKaikeiKbnAnbunKngk;
			/*
			 *最大の会計区分別按分額を持つ会計区分がユニークな場合
			 *その会計区分を端数処理をする会計区分とする*/
			IF
				gCountKaikeiKubunA = 1
			THEN
				SELECT
					KAIKEI_KBN
				INTO
					gKaikeiKubun
				FROM
					KAIKEI_ANBUN
				WHERE
						ITAKU_KAISHA_CD = l_inItakuKaisyaCode
					AND	MGR_CD = l_inMeigaraCode
					AND	KAIKEI_KBN <> '00'
					AND	KAIKEI_KBN_ANBUN_KNGK = gMaxKaikeiKbnAnbunKngk;
			ELSE
			/*
			 *最大の会計区分別按分額を持つ会計区分のなかから最小の会計区分を求め
			 *その会計区分を端数処理をする会計区分とする
			 */
				SELECT
					MIN(KAIKEI_KBN)
				INTO
					gKaikeiKubun
				FROM
					KAIKEI_ANBUN
				WHERE
						ITAKU_KAISHA_CD = l_inItakuKaisyaCode
					AND	MGR_CD = l_inMeigaraCode
					AND	KAIKEI_KBN <> '00'
					AND	KAIKEI_KBN_ANBUN_KNGK = gMaxKaikeiKbnAnbunKngk;
			END IF;
		END IF;
		/*手数料計算結果(会計区分別)テーブル端数処理*/
		FOR recTesyuryoHasu IN (
		SELECT
			VH03.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD,
			VH03.MGR_CD AS MGR_CD,
			VH03.CHOKYU_KJT AS CHOKYU_KJT,
			VH03.TESU_SHURUI_CD AS TESU_SHURUI_CD,
			T01.ALL_TESU_KNGK + T01.ALL_TESU_SZEI - VH03.SUM_ANBUN_TESU_KNGK_KOMI AS HASU_CHOSEI_TESU_KNGK,
			T01.ALL_TESU_SZEI - VH03.SUM_ANBUN_TESU_SZEI AS HASU_CHOSEI_SZEI
		FROM
			(SELECT
				H03.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD,
				H03.MGR_CD AS MGR_CD,
				H03.CHOKYU_KJT AS CHOKYU_KJT,
				H03.TESU_SHURUI_CD AS TESU_SHURUI_CD,
				SUM(H03.ANBUN_TESU_KNGK_KOMI) AS SUM_ANBUN_TESU_KNGK_KOMI,
				SUM(H03.ANBUN_TESU_SZEI) AS SUM_ANBUN_TESU_SZEI
			FROM
				TESURYO_KAIKEI H03
			WHERE
					H03.ITAKU_KAISHA_CD = l_inItakuKaisyaCode
				AND	H03.MGR_CD = l_inMeigaraCode
			GROUP BY
				H03.ITAKU_KAISHA_CD,
				H03.MGR_CD,
				H03.CHOKYU_KJT,
				H03.TESU_SHURUI_CD) VH03,
			TESURYO T01
		WHERE
				VH03.ITAKU_KAISHA_CD = T01.ITAKU_KAISHA_CD
			AND	VH03.MGR_CD = T01.MGR_CD
			AND	VH03.CHOKYU_KJT = T01.CHOKYU_KJT
			AND	VH03.TESU_SHURUI_CD = T01.TESU_SHURUI_CD
		) LOOP
			IF
				recTesyuryoHasu.HASU_CHOSEI_TESU_KNGK > 0
			THEN
			/*更新前手数料額取得*/
				SELECT
					ANBUN_TESU_KNGK_KOMI
				INTO
					gTesuKngk
				FROM
					TESURYO_KAIKEI
				WHERE
						ITAKU_KAISHA_CD = recTesyuryoHasu.ITAKU_KAISHA_CD
					AND	MGR_CD = recTesyuryoHasu.MGR_CD
					AND	TESU_SHURUI_CD = recTesyuryoHasu.TESU_SHURUI_CD
					AND	CHOKYU_KJT = recTesyuryoHasu.CHOKYU_KJT
					AND	KAIKEI_KBN = gKaikeiKubun;
			/*手数料計算結果(会計区分別)テーブル更新　手数料*/
				UPDATE
					TESURYO_KAIKEI
				SET
					ANBUN_TESU_KNGK_KOMI = gTesuKngk + recTesyuryoHasu.HASU_CHOSEI_TESU_KNGK
				WHERE
						ITAKU_KAISHA_CD = recTesyuryoHasu.ITAKU_KAISHA_CD
					AND	MGR_CD = recTesyuryoHasu.MGR_CD
					AND	TESU_SHURUI_CD = recTesyuryoHasu.TESU_SHURUI_CD
					AND	CHOKYU_KJT = recTesyuryoHasu.CHOKYU_KJT
					AND	KAIKEI_KBN = gKaikeiKubun;
			END IF;
			IF
				recTesyuryoHasu.HASU_CHOSEI_SZEI > 0
			THEN
			/*更新前消費税額取得*/
				SELECT
					ANBUN_TESU_SZEI
				INTO
					gSzei
				FROM
					TESURYO_KAIKEI
				WHERE
						ITAKU_KAISHA_CD = recTesyuryoHasu.ITAKU_KAISHA_CD
					AND	MGR_CD = recTesyuryoHasu.MGR_CD
					AND	TESU_SHURUI_CD = recTesyuryoHasu.TESU_SHURUI_CD
					AND	CHOKYU_KJT = recTesyuryoHasu.CHOKYU_KJT
					AND	KAIKEI_KBN = gKaikeiKubun;
			/*手数料計算結果(会計区分別)テーブル更新　消費税*/
				UPDATE
					TESURYO_KAIKEI
				SET
					ANBUN_TESU_SZEI = gSzei + recTesyuryoHasu.HASU_CHOSEI_SZEI
				WHERE
						ITAKU_KAISHA_CD = recTesyuryoHasu.ITAKU_KAISHA_CD
					AND	MGR_CD = recTesyuryoHasu.MGR_CD
					AND	TESU_SHURUI_CD = recTesyuryoHasu.TESU_SHURUI_CD
					AND	CHOKYU_KJT = recTesyuryoHasu.CHOKYU_KJT
					AND	KAIKEI_KBN = gKaikeiKubun;
			END IF;
		END LOOP;
	ELSE
		IF gRecT01_H02 = 0 THEN
		/*該当データが存在しない場合エラーメッセージ出力*/
		CALL pkLog.error( l_inUserId
					,program_id
					,'手数料計算結果(会計区分別)データ作成 対象データが存在しませんでした。');
		END IF;
	END IF;


	IF DEBUG = 1 THEN
		CALL pkLog.debug(l_inUserId, program_id, program_id || ' END');
	END IF;

	RETURN pkconstant.success();

/*====================================================================*
    異常終了 出口
 *====================================================================*/
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', program_id, 'SQLSTATE:'||SQLSTATE);
		CALL pkLog.fatal('ECM701', program_id, 'SQLERRM:'||SQLERRM);
		
		RETURN pkconstant.fatal();
--	RAISE;
END;
$body$;
