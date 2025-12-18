drop function if exists pkIpIF.gKanriRec;
drop function if exists pkIpIF.gCommonBodyRec;
drop type if exists pkIpIF.tKanriRec CASCADE;
drop type if exists pkIpIF.tCommonBodyRec CASCADE;



-- Oracle package 'pkipif' declaration, please edit to match PostgreSQL syntax.

-- DROP SCHEMA IF EXISTS pkipif CASCADE;
CREATE SCHEMA IF NOT EXISTS pkipif;


--*
-- * 著作権: Copyright (c) 2016
-- * 会社名: JIP
-- *
-- * 外部IF共通処理パッケージ
-- *
-- * @author 村木
-- 
	--*
--	 * 外部IF送受信管理レコードの新規作成
--	 *
--	 * @param l_inIfId		外部IFID
--	 * @param l_inGyomuDate	業務日付
--	 * @param l_outCnt		作成回数
--	 * @return INTEGER 0:正常、99:異常、それ以外：エラー
--	 
CREATE OR REPLACE FUNCTION pkipif.insgaibuifkanri ( l_inIfId char(6), l_inGyomuDate char(8), l_outCnt OUT numeric(5) , OUT extra_param integer) RETURNS record AS $body$
DECLARE

	--==============================================================================
	--					定数定義													
	--==============================================================================
		-- プログラムID
		PGM_ID			CONSTANT text			:= 'pkIpIF.insGaibuIFKanri()';
		-- タイムアウト
		C_RET_TIMEOUT	CONSTANT integer				:= 2;

	--==============================================================================
	--					変数定義													
	--==============================================================================
		pIfId			char(6)			:= '';			-- IF_ID
		pMakeCnt		numeric(5)		:= 0;			-- 作成回数
		pRenkeiFlg		char(1)	:= '';			-- 連携フラグ
		pParam			varchar(500)						:= '';			-- 引数
		pResult			integer				:= pkconstant.success();			-- 戻り値
	--==============================================================================
	--					メイン処理													
	--==============================================================================
	
BEGIN
		CALL pkLog.debug('BATCH', PGM_ID, '***** START *****');

		pParam := '引数(' || l_inIfId || ' : ' || l_inGyomuDate || ')';

		-- 入力パラメータのチェック
		-- 外部IFID の必須チェック
		IF coalesce(l_inIfId::text, '') = ''
		THEN
			-- パラメータエラー
			CALL pkLog.error('ECM501', PGM_ID, '外部IFID');
			extra_param := pkconstant.error();
			RETURN;
		END IF;

		-- 業務日付 の必須チェック
		IF coalesce(l_inGyomuDate::text, '') = ''
		THEN
			-- パラメータエラー
			CALL pkLog.error('ECM501', PGM_ID, '業務日付');
			extra_param := pkconstant.error();
			RETURN;
		END IF;

		-- 外部IF送受信管理のレコードロック
		IF l_inIfId = 'IF24-1' OR l_inIfId = 'IF26-1' THEN
			SELECT
				IF_ID
			INTO STRICT
				pIfId
			FROM
				GAIBU_IF_KANRI
			WHERE
				IF_ID = l_inIfId
				AND IF_MAKE_DT = '00000000'
			FOR UPDATE;					-- Row lock
		END IF;

	-- 最大作成回数取得SELECT --
	SELECT r.l_outcnt, r.l_outrenkeiflg, r.extra_param INTO pMakeCnt, pRenkeiFlg, pResult 
	FROM pkIpIF.getRenkeiFlg(l_inIfId, l_inGyomuDate) r;
		IF pResult <> pkconstant.success() THEN
			extra_param := pResult;
			RETURN;
		END IF;
		pMakeCnt := pMakeCnt + 1;

		-- 外部IF送受信管理INSERT --
		INSERT INTO GAIBU_IF_KANRI(
			IF_ID,
			IF_MAKE_DT,
			IF_MAKE_CNT,
			IF_RENKEI_FLG,
			KOUSIN_ID,
			SAKUSEI_ID
		)
		VALUES (
			l_inIfId,
			l_inGyomuDate,
			pMakeCnt,
			'0',
			pkconstant.BATCH_USER(),
			pkconstant.BATCH_USER()
		);

		l_outCnt := pMakeCnt;

	CALL pkLog.debug('BATCH', PGM_ID, '***** END *****');
	extra_param := pkconstant.success();
	RETURN;

-- エラー処理
EXCEPTION
	WHEN lock_not_available THEN
		CALL pkLog.error('EIP555', PGM_ID, pParam);
		extra_param := C_RET_TIMEOUT;
		RETURN;

	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', PGM_ID, pParam);
		CALL pkLog.fatal('ECM701', PGM_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', PGM_ID, 'SQLERRM:' || SQLERRM);
		extra_param := pkconstant.FATAL();
		RETURN;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipif.insgaibuifkanri ( l_inIfId char(6), l_inGyomuDate char(8), l_outCnt OUT numeric(5) , OUT extra_param integer) FROM PUBLIC;

	--*
--	 * 外部IF送受信管理レコードの連携フラグを更新する
--	 *
--	 * @param l_inIfId			外部IFID
--	 * @param l_inGyomuDate		業務日付
--	 * @param l_inCnt			作成回数
--	 * @param l_inRenkeiFlg		連携フラグ
--	 * @return INTEGER 0:正常、99:異常、それ以外：エラー
--	 
CREATE OR REPLACE FUNCTION pkipif.updrenkeiflg ( l_inIfId char(6), l_inGyomuDate char(8), l_inCnt numeric(5), l_inRenkeiFlg char(1) ) RETURNS integer AS $body$
DECLARE

	--==============================================================================
	--					定数定義													
	--==============================================================================
		-- プログラムID
		PGM_ID			CONSTANT text		:= 'pkIpIF.updRenkeiFlg()';

	--==============================================================================
	--					変数定義													
	--==============================================================================
		pParam			varchar(500)				:= '';			-- 引数
	--==============================================================================
	--					メイン処理													
	--==============================================================================
	
BEGIN
		CALL pkLog.debug('BATCH', PGM_ID, '***** START *****');

		pParam := '引数(' || l_inIfId || ' : '
							|| l_inGyomuDate || ' : '
							|| l_inCnt::text || ' : '
							|| l_inRenkeiFlg || ')';

		-- 入力パラメータのチェック
		-- 外部IFID の必須チェック
		IF coalesce(l_inIfId::text, '') = ''
		THEN
			-- パラメータエラー
			CALL pkLog.error('ECM501', PGM_ID, '外部IFID');
			RETURN pkconstant.error();
		END IF;

		-- 業務日付 の必須チェック
		IF coalesce(l_inGyomuDate::text, '') = ''
		THEN
			-- パラメータエラー
			CALL pkLog.error('ECM501', PGM_ID, '業務日付');
			RETURN pkconstant.error();
		END IF;

		-- 作成回数 の必須チェック
		IF coalesce(l_inCnt::text, '') = ''
		THEN
			-- パラメータエラー
			CALL pkLog.error('ECM501', PGM_ID, '作成回数');
			RETURN pkconstant.error();
		END IF;

		-- 連携フラグ の必須チェック
		IF coalesce(l_inRenkeiFlg::text, '') = ''
		THEN
			-- パラメータエラー
			CALL pkLog.error('ECM501', PGM_ID, '連携フラグ');
			RETURN pkconstant.error();
		END IF;

		-- 連携フラグ の妥当性チェック
		IF (l_inRenkeiFlg != '0') and (l_inRenkeiFlg != '1') and (l_inRenkeiFlg != '9')
		THEN
			-- パラメータエラー
			CALL pkLog.error('ECM501', PGM_ID, '連携フラグ='||l_inRenkeiFlg);
			RETURN pkconstant.error();
		END IF;

		IF l_inCnt > 0
		THEN
			-- 連携フラグ更新UPDATE1 --
			UPDATE
				GAIBU_IF_KANRI
			SET
				IF_RENKEI_FLG = l_inRenkeiFlg,
				KOUSIN_ID = pkconstant.BATCH_USER()
			WHERE
				IF_ID = l_inIfId
				AND IF_MAKE_DT = l_inGyomuDate
				AND IF_MAKE_CNT = l_inCnt;
		ELSE
			-- 連携フラグ更新UPDATE2 --
			UPDATE
				GAIBU_IF_KANRI
			SET
				IF_RENKEI_FLG = l_inRenkeiFlg,
				KOUSIN_ID = pkconstant.BATCH_USER()
			WHERE
				IF_ID = l_inIfId
				AND IF_MAKE_DT = l_inGyomuDate;
		END IF;

	 	CALL pkLog.debug('BATCH', PGM_ID, '***** END *****');
	 	RETURN pkconstant.success();

	-- エラー処理
	EXCEPTION
		WHEN OTHERS THEN
			CALL pkLog.fatal('ECM701', PGM_ID, pParam);
			CALL pkLog.fatal('ECM701', PGM_ID, 'SQLCODE:' || SQLSTATE);
			CALL pkLog.fatal('ECM701', PGM_ID, 'SQLERRM:' || SQLERRM);
			RETURN pkconstant.FATAL();
	END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipif.updrenkeiflg ( l_inIfId char(6), l_inGyomuDate char(8), l_inCnt numeric(5), l_inRenkeiFlg char(1) ) FROM PUBLIC;

	--*
--	 * 外部IF送受信管理レコードの連携フラグと作成回数を取得する
--	 *
--	 * @param l_inIfId			外部IFID
--	 * @param l_inGyomuDate		業務日付
--	 * @param l_outCnt			作成回数
--	 * @param l_outRenkeiFlg	連携フラグ
--	 * @return INTEGER 0:正常、99:異常、それ以外：エラー
--	 
CREATE OR REPLACE FUNCTION pkipif.getrenkeiflg ( l_inIfId char(6), l_inGyomuDate char(8), l_outCnt OUT numeric(5), l_outRenkeiFlg OUT char(1) , OUT extra_param integer) RETURNS record AS $body$
DECLARE

	--==============================================================================
	--					定数定義													
	--==============================================================================
		-- プログラムID
		PGM_ID			CONSTANT text				:= 'pkIpIF.getRenkeiFlg()';

	--==============================================================================
	--					変数定義													
	--==============================================================================
		pMakeCnt		numeric(5)		:= 0;			-- 作成回数
		pRenkeiFlg		char(1)	:= '';			-- 連携フラグ
		pParam			varchar(500)						:= '';			-- 引数
	--==============================================================================
	--					メイン処理													
	--==============================================================================
	
BEGIN
		CALL pkLog.debug('BATCH', PGM_ID, '***** START *****');

		pParam := '引数(' || l_inIfId || ' : ' || l_inGyomuDate || ')';

		-- 入力パラメータのチェック
		-- 外部IFID の必須チェック
		IF coalesce(l_inIfId::text, '') = ''
		THEN
			-- パラメータエラー
			CALL pkLog.error('ECM501', PGM_ID, '外部IFID');
			extra_param := pkconstant.error();
			RETURN;
		END IF;

		-- 業務日付 の必須チェック
		IF coalesce(l_inGyomuDate::text, '') = ''
		THEN
			-- パラメータエラー
			CALL pkLog.error('ECM501', PGM_ID, '業務日付');
			extra_param := pkconstant.error();
			RETURN;
		END IF;

		-- 連携フラグ取得SELECT --
		SELECT
			IF_MAKE_CNT,
			IF_RENKEI_FLG
		INTO STRICT
			pMakeCnt,
			pRenkeiFlg
		FROM (
			SELECT
				IF_MAKE_CNT,
				IF_RENKEI_FLG
			FROM
				GAIBU_IF_KANRI
			WHERE
				IF_ID = l_inIfId
				AND IF_MAKE_DT = l_inGyomuDate
			ORDER BY
				IF_MAKE_CNT DESC
			) alias0 LIMIT 1;

		l_outCnt := pMakeCnt;
		l_outRenkeiFlg := pRenkeiFlg;

		CALL pkLog.debug('BATCH', PGM_ID, '***** END *****');
		extra_param := pkconstant.success();
		RETURN;

	-- エラー処理
	EXCEPTION
		WHEN no_data_found THEN
			--データが存在しない場合は正常終了する。
			l_outCnt := 0;
			l_outRenkeiFlg := '0';
			CALL pkLog.debug('BATCH', PGM_ID, '***** END *****');
			extra_param := pkconstant.success();
			RETURN;
		WHEN OTHERS THEN
			CALL pkLog.fatal('ECM701', PGM_ID, pParam);
			CALL pkLog.fatal('ECM701', PGM_ID, 'SQLCODE:' || SQLSTATE);
			CALL pkLog.fatal('ECM701', PGM_ID, 'SQLERRM:' || SQLERRM);
			extra_param := pkconstant.FATAL();
			RETURN;
	END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipif.getrenkeiflg ( l_inIfId char(6), l_inGyomuDate char(8), l_outCnt OUT numeric(5), l_outRenkeiFlg OUT char(1) , OUT extra_param integer) FROM PUBLIC;

	--*
--	 * データ連携通番管理テーブルより通番を取得し、通番に1加算して更新する
--	 *
--	 * @param l_inNoKbn		ＩＦ通番種別
--	 * @param l_outNo		ＩＦデータ通番
--	 * @return INTEGER 0:正常、99:異常、それ以外：エラー
--	 
CREATE OR REPLACE FUNCTION pkipif.getifnum ( l_inNoKbn char(2), l_outNo OUT numeric(10) , OUT extra_param integer) RETURNS record AS $body$
DECLARE

	--==============================================================================
	--					定数定義													
	--==============================================================================
		-- プログラムID
		PGM_ID		CONSTANT text		:= 'pkIpIF.getIFNum()';
		-- タイムアウト
		C_RET_TIMEOUT	CONSTANT integer				:= 2;

	--==============================================================================
	--					変数定義													
	--==============================================================================
		pNo			numeric(10)		:= 0;			-- ＩＦデータ通番
		pParam		varchar(500)				:= '';			-- 引数
	--==============================================================================
	--					メイン処理													
	--==============================================================================
	
BEGIN
		CALL pkLog.debug('BATCH', PGM_ID, '***** START *****');

		pParam := '引数(' || l_inNoKbn || ')';

		-- 入力パラメータのチェック
		-- ＩＦ通番種別 の必須チェック
		IF coalesce(l_inNoKbn::text, '') = ''
		THEN
			-- パラメータエラー
			CALL pkLog.error('ECM501', PGM_ID, 'ＩＦ通番種別');
			extra_param := pkconstant.error();
			RETURN;
		END IF;

		-- データ通番取得SELECT --
		SELECT
			IF_NO
		INTO STRICT
			pNo
		FROM
			NO_RENKEI
		WHERE
			IF_NO_KBN = l_inNoKbn
		FOR UPDATE;					-- Row lock
		pNo := pNo + 1;

		-- データ通番更新UPDATE --
		UPDATE
			NO_RENKEI
		SET
			IF_NO = pNo,
			KOUSIN_ID = pkconstant.BATCH_USER()
		WHERE
			IF_NO_KBN = l_inNoKbn;

		l_outNo := pNo;

		CALL pkLog.debug('BATCH', PGM_ID, '***** END *****');
		extra_param := pkconstant.success();
		RETURN;

	-- エラー処理
	EXCEPTION
		WHEN lock_not_available THEN
			CALL pkLog.error('EIP555', PGM_ID, pParam);
			extra_param := C_RET_TIMEOUT;
			RETURN;

		WHEN OTHERS THEN
			CALL pkLog.fatal('ECM701', PGM_ID, pParam);
			CALL pkLog.fatal('ECM701', PGM_ID, 'SQLCODE:' || SQLSTATE);
			CALL pkLog.fatal('ECM701', PGM_ID, 'SQLERRM:' || SQLERRM);
			extra_param := pkconstant.FATAL();
			RETURN;
	END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION pkipif.getifnum ( l_inNoKbn char(2), l_outNo OUT numeric(10) , OUT extra_param integer) FROM PUBLIC;

	--*
--	 * 外部IF送受信テーブルを以下のソート順で並べ替えを行い、正しい外部IFデータ番号でINSERTする
--	 * 業務任意キー
--	 * 外部IFデータ番号
--	 *
--	 * 並べ替えした後、外部IFデータ番号が連番にならないので、ROW_NUMBER()を使用する
--	 *
--	 * @param l_inIfId			外部IFID
--	 * @param l_inDataNo		外部IFデータ番号
--	 * @param l_inDummyIfId		ダミー外部IFID
--	 * @param l_inGyomuDate		業務日付
--	 * @param l_inCnt			作成回数
--	 
CREATE OR REPLACE PROCEDURE pkipif.sortgaibuifdata ( l_inIfId char(6), l_inDataNo numeric(10), l_inDummyIfId text, l_inGyomuDate char(8), l_inCnt numeric(5) ) AS $body$
BEGIN
		INSERT INTO GAIBU_IF_DATA(
			IF_ID,
			IF_MAKE_DT,
			IF_MAKE_CNT,
			IF_DATA_NO,
			IF_DATA,
			KOUSIN_ID,
			SAKUSEI_ID
		)
		SELECT
			l_inIfId,
			IF_MAKE_DT,
			IF_MAKE_CNT,
			ROW_NUMBER() OVER (
				ORDER BY
					CASE WHEN (regexp_instr(IF_DATA, pkIpIF.C_DELIMITER(), 1, 11) - regexp_instr(IF_DATA, pkIpIF.C_DELIMITER(), 1, 10)) > 0
						THEN substr(
							IF_DATA,
							regexp_instr(IF_DATA, pkIpIF.C_DELIMITER(), 1, 10) + 1,
							regexp_instr(IF_DATA, pkIpIF.C_DELIMITER(), 1, 11) - regexp_instr(IF_DATA, pkIpIF.C_DELIMITER(), 1, 10) -1)
						END,	-- 業務任意キー
					IF_DATA_NO
				) + 0 AS row_no,																	-- 外部IFデータ番号
			IF_DATA,
			KOUSIN_ID,
			SAKUSEI_ID
		FROM
			GAIBU_IF_DATA
		WHERE
			IF_ID = l_inDummyIfId
		AND	IF_MAKE_DT = l_inGyomuDate
		AND	IF_MAKE_CNT = l_inCnt;
	END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE pkipif.sortgaibuifdata ( l_inIfId char(6), l_inDataNo numeric(10), l_inDummyIfId text, l_inGyomuDate char(8), l_inCnt numeric(5) ) FROM PUBLIC;
-- End of Oracle package 'pkipif' declaration

create or replace function pkIpIF.C_MOTO_GYOMU_ID() returns char(8) as $$ select char(8) 'IPARXG01' $$ language sql immutable parallel safe;-- データ供給先情報_システムID　RTGS-XG
create or replace function pkIpIF.C_SAKI_SYSTEM_ID() returns char(4) as $$ select char(4) 'XRTS' $$ language sql immutable parallel safe;-- 決済時刻ＦＲＯＭ
create or replace function pkIpIF.C_KESSAI_TM_FROM() returns char(4) as $$ select char(4) '0900' $$ language sql immutable parallel safe;-- 決済時刻ＴＯ
create or replace function pkIpIF.C_KESSAI_TM_TO() returns char(4) as $$ select char(4) '1500' $$ language sql immutable parallel safe;-- データ供給元情報_業務ID（MIC電文ヘッダ）　決済代行・銘柄情報
create or replace function pkIpIF.C_MOTO_GYOMU_ID_DAIKOU_MGR() returns char(8) as $$ select char(8) 'KKD00004' $$ language sql immutable parallel safe;-- データ供給元情報_業務ID（MIC電文ヘッダ）　決済代行・資金決済予定データ
create or replace function pkIpIF.C_MOTO_GYOMU_ID_DAIKOU_SKNKSI() returns char(8) as $$ select char(8) 'KTYZFI11' $$ language sql immutable parallel safe;-- データ供給先情報_システムID　決済代行
create or replace function pkIpIF.C_SAKI_SYSTEM_ID_DAIKOU() returns char(4) as $$ select char(4) 'XKKD' $$ language sql immutable parallel safe;-- 採番種別（資金決済予定データ_業務通番）
create or replace function pkIpIF.C_NUMBERING_GYOMU_NO() returns char(2) as $$ select char(2) '01' $$ language sql immutable parallel safe;-- 採番種別（MICヘッダ_データ供給元情報_電文通番）
create or replace function pkIpIF.C_NUMBERING_DENBUN_NO() returns char(2) as $$ select char(2) '02' $$ language sql immutable parallel safe;-- 採番種別（銘柄情報データ_通番）
create or replace function pkIpIF.C_NUMBERING_MGRDAT_NO() returns char(2) as $$ select char(2) '03' $$ language sql immutable parallel safe;-- 採番種別（資金決済予定データ_リファレンスＮＯ）
create or replace function pkIpIF.C_NUMBERING_REF_NO() returns char(2) as $$ select char(2) '04' $$ language sql immutable parallel safe;-- 採番種別（資金決済予定データ_業務通番（新規記録））
create or replace function pkIpIF.C_NUMBERING_GYOMU_NO_SHINKI() returns char(2) as $$ select char(2) '05' $$ language sql immutable parallel safe;-- 採番種別（MICヘッダ_データ供給元情報_電文通番（RTGS-XG））
create or replace function pkIpIF.C_NUMBERING_DENBUN_NO_RTGS_XG() returns char(2) as $$ select char(2) '06' $$ language sql immutable parallel safe;-- 連携フラグ（'9'：連携不要）
create or replace function pkIpIF.C_RENKEI_FLG_FUYO() returns char as $$ select char '9' $$ language sql immutable parallel safe;-- 区切り文字
create or replace function pkIpIF.C_DELIMITER() returns char(1) as $$ select chr(9)::char(1) $$ language sql immutable parallel safe;-- タブ
-- 顧客直送
create or replace function pkIpIF.C_CUSTOMER_DIRECT_DELIVERY() returns char(1) as $$ select char(1) '5' $$ language sql immutable parallel safe;-- 営業店還元
create or replace function pkIpIF.C_EIGYOTEN_KANGEN() returns char(1) as $$ select char(1) '4' $$ language sql immutable parallel safe;-- DMセンタ発送(郵便番号順)
create or replace function pkIpIF.C_DMCENTER_DELIVERY() returns char(1) as $$ select char(1) '5' $$ language sql immutable parallel safe;-- 本部還元１(東京)
create or replace function pkIpIF.C_FINANCIAL_TOKYO() returns char(4) as $$ select char(4) '1TKY' $$ language sql immutable parallel safe;-- 本部還元１(大阪)
create or replace function pkIpIF.C_FINANCIAL_OSAKA() returns char(4) as $$ select char(4) '1OSK' $$ language sql immutable parallel safe;-- 本部還元２(東京)
create or replace function pkIpIF.C_ADMINISTRATION_TOKYO() returns char(4) as $$ select char(4) '2TKY' $$ language sql immutable parallel safe;-- 本部還元２(大阪)
create or replace function pkIpIF.C_ADMINISTRATION_OSAKA() returns char(4) as $$ select char(4) '2OSK' $$ language sql immutable parallel safe;-- DM送付店番(ZEUS・ERS用)
create or replace function pkIpIF.C_ADMINISTRATION_TOKYO_ZEUS() returns char(4) as $$ select char(4) '6878' $$ language sql immutable parallel safe;-- ダミー総頁数
create or replace function pkIpIF.C_DUMMY_SUM_PAGE() returns char(12) as $$ select char(12) 'ダミー総頁数' $$ language sql immutable parallel safe;-- 帳票ID
create or replace function pkIpIF.C_GANRI_SEIKYU_CHOHYO_ID() returns char(11) as $$ select char(11) 'IP030004631' $$ language sql immutable parallel safe;-- 元利払請求書（請求書）の連票
create or replace function pkIpIF.C_GANRI_RYOSYU_CHOHYO_ID() returns char(11) as $$ select char(11) 'IP030004641' $$ language sql immutable parallel safe;-- 元利払請求書（領収書）の連票
create or replace function pkIpIF.C_KITYU_SEIKYU_CHOHYO_ID() returns char(11) as $$ select char(11) 'IP030005511' $$ language sql immutable parallel safe;-- 期中管理手数料請求書
create or replace function pkIpIF.C_KITYU_RYOSYU_CHOHYO_ID() returns char(11) as $$ select char(11) 'IP030005521' $$ language sql immutable parallel safe;-- 期中管理手数料領収書
create or replace function pkIpIF.C_HENDO_RIRITSU_CHOHYO_ID() returns char(11) as $$ select char(11) 'IP030001911' $$ language sql immutable parallel safe;-- 変動利率決定通知
create or replace function pkIpIF.C_GANRI_HOKOKU_CHOHYO_ID() returns char(11) as $$ select char(11) 'IP030004711' $$ language sql immutable parallel safe;-- 元利金支払報告書
create or replace function pkIpIF.C_KOSYA_GENBO_CHOHYO_ID() returns char(11) as $$ select char(11) 'IP030004411' $$ language sql immutable parallel safe;-- 公社債原簿整理簿
create or replace function pkIpIF.C_KAIIRE_SEIKYU_CHOHYO_ID() returns char(11) as $$ select char(11) 'IP030006111' $$ language sql immutable parallel safe;-- 買入消却手数料請求書
create or replace function pkIpIF.C_KAIIRE_RYOSYU_CHOHYO_ID() returns char(11) as $$ select char(11) 'IP030006121' $$ language sql immutable parallel safe;-- 買入消却手数料領収書
create or replace function pkIpIF.C_SYOKAN_SCHEDULE_CHOHYO_ID() returns char(11) as $$ select char(11) 'IP030003711' $$ language sql immutable parallel safe;-- 償還スケジュール表
create or replace function pkIpIF.C_GANRI_HENREI_CHOHYO_ID() returns char(11) as $$ select char(11) 'IP030005111' $$ language sql immutable parallel safe;-- 元利金支払基金返戻通知書
--* 例外：ORA-30006: リソース・ビジー; WAITタイムアウトの期限に達しました。
CREATE TYPE pkIpIF.tKanriRec AS (
	recKbn		varchar(1), 
	sakuseiYmd		varchar(8), 
	systemId		varchar(2), 
	recDistinction		varchar(1), 
	chohyoNo		varchar(5), 
	programId		varchar(8) 
);

CREATE OR REPLACE FUNCTION pkIpIF.gKanriRec()
RETURNS pkIpIF.tKanriRec
AS $body$
DECLARE
	gKanriRec pkIpIF.tKanriRec;
BEGIN
	gKanriRec.recKbn := '2';
	gKanriRec.sakuseiYmd := '';
	gKanriRec.systemId := '10';
	gKanriRec.recDistinction := '0';
	gKanriRec.chohyoNo := '';
	gKanriRec.programId := '';

	RETURN gKanriRec;
END;
$body$
LANGUAGE PLPGSQL
;

CREATE TYPE pkIpIF.tCommonBodyRec AS (
	kangenKozatenCd		varchar(4), 
	tantoCd		varchar(1), 
	recKbn		varchar(1), 
	kozatenCifCd		varchar(8), 
	mailComment		varchar(18), 
	customerAddress		varchar(150), 
	recDistinction		varchar(1), 
	sendKbn		varchar(1), 
	chohyoNo		varchar(5), 
	gyomutsushinKbn		varchar(1), 
	sakuseiYmd		varchar(8), 
	gyomuKey		varchar(20), 
	postNo		varchar(7), 
	dispatchKbn		varchar(1), 
	customerKbn		varchar(1), 
	kaipageSign		varchar(1), 
	customerName		varchar(100), 
	kozatenCd		varchar(4), 
	maruSign		varchar(1) 
);

CREATE OR REPLACE FUNCTION pkIpIF.gCommonBodyRec()
RETURNS pkIpIF.tCommonBodyRec
AS $body$
DECLARE
	gCommonBodyRec pkIpIF.tCommonBodyRec;
BEGIN
	gCommonBodyRec.kangenKozatenCd := '';
	gCommonBodyRec.tantoCd := '';
	gCommonBodyRec.recKbn := '2';
	gCommonBodyRec.kozatenCifCd := '';
	gCommonBodyRec.mailComment := '6878アドミニストレーション室';
	gCommonBodyRec.customerAddress := '';
	gCommonBodyRec.recDistinction := '1';
	gCommonBodyRec.sendKbn := '';
	gCommonBodyRec.chohyoNo := '';
	gCommonBodyRec.gyomutsushinKbn := '';
	gCommonBodyRec.sakuseiYmd := '';
	gCommonBodyRec.gyomuKey := '';
	gCommonBodyRec.postNo := '';
	gCommonBodyRec.dispatchKbn := '';
	gCommonBodyRec.customerKbn := '1';
	gCommonBodyRec.kaipageSign := '';
	gCommonBodyRec.customerName := '';
	gCommonBodyRec.kozatenCd := '';
	gCommonBodyRec.maruSign := '';

	RETURN gCommonBodyRec;
END;
$body$
LANGUAGE PLPGSQL
;


