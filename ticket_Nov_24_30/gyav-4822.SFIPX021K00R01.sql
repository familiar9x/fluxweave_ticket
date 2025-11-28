




CREATE OR REPLACE FUNCTION sfipx021k00r01 ( 
 l_inItakuKaishaCd TEXT,		-- 委託会社コード
 l_inMgrCd TEXT,		-- 銘柄コード
 l_inGnrYmd TEXT 		-- 元利払日
 ) RETURNS numeric AS $body$
DECLARE

--*
-- * 著作権:Copyright (c) 2013
-- * 会社名:JIP
-- * 概要　:資金支払データ変更バッチ
-- * 　　　 資金支払データ変更画面の指示により、元利払請求明細データ変更に伴う関連データの再作成を行う
-- * 引数　:l_inItakuKaishaCd		IN	TEXT		委託会社コード
-- * 　　　 l_inMgrCd				IN	TEXT		銘柄コード
-- * 　　　 l_inGnrYmd			IN	TEXT		元利払日
-- * 返り値:NUMERIC 0:正常、99:異常、それ以外：エラー
-- *
-- * @version $Id: SFIPX021K00R01.sql,v 1.1 2013/12/27 02:35:28 touma Exp $
-- 
--==============================================================================
--                  定数定義                                                    
--==============================================================================
	C_FUNCTION_ID	CONSTANT varchar(20) := 'SFIPX021K00R01';	-- ファンクションＩＤ
	RTN_NODATA		CONSTANT integer := 2;						-- データなし
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	gRtnCd			numeric;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	CALL pkLog.debug('BATCH', C_FUNCTION_ID, C_FUNCTION_ID || ' START');
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = ''
	OR coalesce(trim(both l_inMgrCd)::text, '') = ''
	OR coalesce(trim(both l_inGnrYmd)::text, '') = '' THEN
		-- パラメータエラー
		CALL pkLog.error('ECM501', C_FUNCTION_ID, 'SQLERRM:' || '');
		RETURN pkconstant.FATAL();
	END IF;
	-- 再作成対象データを基金異動履歴から削除する
	DELETE
	FROM	KIKIN_IDO K02
	WHERE	K02.ITAKU_KAISHA_CD = l_inItakuKaishaCd
	AND		K02.MGR_CD = l_inMgrCd
	AND		K02.RBR_YMD = l_inGnrYmd
	AND		K02.KKN_IDO_KBN IN ('31', '32', '33', '41', '42', '43', '51', '91', '92', '93', '94', '95', '96');
	-- 元利払基金出金データ再作成
	gRtnCd := SFIPX021K00R01_01(l_inItakuKaishaCd, l_inMgrCd, l_inGnrYmd);
	IF (gRtnCd not in (pkconstant.success(), RTN_NODATA)) THEN
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '元利払基金出金データ再作成エラー');
		RETURN gRtnCd;
	END IF;
	-- 会計処理／利金差額調整承認入力オプションが有効な場合
	IF pkControl.getOPTION_FLG(l_inItakuKaishaCd, 'IPH1005120050', '0') = '1' THEN
		-- 利金端数差額調整用データ再作成
		gRtnCd := SFIPX021K00R01_02(l_inItakuKaishaCd, l_inMgrCd, l_inGnrYmd);
		IF gRtnCd != pkconstant.success() THEN
			CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '利金端数差額調整用データ再作成エラー');
			RETURN gRtnCd;
		END IF;
	END IF;
	-- 会計処理／元利払手数料収益計上承認入力オプションが有効な場合
	IF pkControl.getOPTION_FLG(l_inItakuKaishaCd, 'IPH1005121050', '0') = '1' THEN
		-- 元利払手数料差額調整用データ再作成
		gRtnCd := SFIPX021K00R01_03(l_inItakuKaishaCd, l_inMgrCd, l_inGnrYmd);
		IF gRtnCd != pkconstant.success() THEN
			CALL pkLog.fatal('ECM701', C_FUNCTION_ID, '元利払手数料差額調整用データ再作成エラー');
			RETURN gRtnCd;
		END IF;
	END IF;
	CALL pkLog.debug('BATCH', C_FUNCTION_ID, C_FUNCTION_ID || ' END');
	gRtnCd := pkconstant.success();
	RETURN gRtnCd;
--=========< エラー処理 >==========================================================
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'エラーコード' || SQLSTATE);
		CALL pkLog.fatal('ECM701', C_FUNCTION_ID, 'エラー内容' || SQLERRM);
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipx021k00r01 ( l_inItakuKaishaCd TEXT, l_inMgrCd TEXT, l_inGnrYmd TEXT  ) FROM PUBLIC;