


DROP TYPE IF EXISTS sfipxb09k15r01_mic_tmicheader;
CREATE TYPE sfipxb09k15r01_mic_tmicheader AS (
		codeKbn				TEXT     ,			-- 共通情報_コード区分（0x30）
		denbunKbn			char(2)  ,			-- 共通情報_電文区分
		cmnTimestamp		char(14) ,			-- 共通情報_日時
		mnYoyaku			char(3)  ,			-- 共通情報_予約領域
		motoSystemId		char(4)  ,		-- データ供給元情報_システムＩＤ
		motoGyomuId			char(8)  ,			-- データ供給元情報_業務ID
		gyomuDt				char(8)  ,			-- データ供給元情報_業務日付
		gyomuNo				char(2)  ,			-- データ供給元情報_業務通番
		denbunNo			char(8)  ,			-- データ供給元情報_電文通番
		recCnt				char(8)  ,	-- データ供給元付加情報_レコード件数
		sakiSystemId		char(4)  ,			-- データ供給先情報_システムID
		blank1				char(8)  ,			-- ブランク（データ供給先情報_業務ID）
		zero1				char(4)  ,		-- ゼロ（交換データ制御情報_再送区分 〜 交換データ制御情報_ペーシング応答要否フラグ）
		blank2				char(98)  				-- ブランク（交換データ制御情報_予約領域 〜 業務固有情報）
	);


CREATE OR REPLACE FUNCTION sfipxb09k15r01_mic ( l_inMotoGyomuId TEXT, 	-- データ供給元情報_業務ID
 l_inSakiSystemId TEXT, 	-- データ供給先情報_システムID
 l_inGyomuYmd TEXT, 		-- 業務日付
 l_inDenbunNo integer  	-- 電文通番
 ) RETURNS text AS $body$
DECLARE

--*
-- * 著作権:Copyright(c)2016
-- * 会社名:JIP
-- *
-- * 概  要:MIC電文ヘッダを作成する。
-- *
-- * @author 村木 明広
-- * @version $Id:$
-- *
-- * @param l_inGyomuId 				-- データ供給元情報_業務ID
-- * @param l_inSakiSystemId, 		-- データ供給先情報_システムID
-- * @param l_inGyomuYmd				-- 業務日付
-- * @param l_inDenbunNo 				-- 電文通番
-- * @return TEXT MIC電文ヘッダ
-- *
-- ***************************************************************************
-- * ログ:
-- *    日付    開発者名		目的
-- * -------------------------------------------------------------------------
-- * 2016.10.21 村木			新規作成
-- ***************************************************************************
--
	--==============================================================================
	--					定数定義													
	--==============================================================================
	-- ファンクションＩＤ
	C_FUNCTION_ID CONSTANT		varchar(50)	;
	--==============================================================================
	--					変数定義													
	--==============================================================================
	pMicHeader SFIPXB09K15R01_MIC_tMicHeader;	-- MIC電文（ヘッダ）
	pOutMicHdr				text;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	CALL pkLog.debug('BATCH', C_FUNCTION_ID, '***** ' || C_FUNCTION_ID || ' START *****');
	-- Initialize pMicHeader with default values
	pMicHeader.codeKbn := '0';
	pMicHeader.denbunKbn := '00';
	pMicHeader.cmnTimestamp := REPEAT(' ', 14);
	pMicHeader.mnYoyaku := REPEAT(' ', 3);
	pMicHeader.motoSystemId := 'IPA ';
	pMicHeader.gyomuNo := '00';
	pMicHeader.recCnt := '00000000';
	pMicHeader.blank1 := REPEAT(' ', 8);
	pMicHeader.zero1 := '0000';
	pMicHeader.blank2 := REPEAT(' ', 98);
	-- Build MIC header directly - each field with exact width
	pOutMicHdr := '0'  -- codeKbn (1)
				 || '00'  -- denbunKbn (2)
				 || REPEAT(' ', 14)  -- cmnTimestamp (14)
				 || '   '  -- mnYoyaku (3)
				 || 'IPA '  -- motoSystemId (4)
				 || RPAD(l_inMotoGyomuId, 8, ' ')  -- motoGyomuId (8)
				 || RPAD(l_inGyomuYmd, 8, ' ')  -- gyomuDt (8)
				 || '00'  -- gyomuNo (2)
				 || LPAD(l_inDenbunNo::text, 8, '0')  -- denbunNo (8)
				 || '00000000'  -- recCnt (8)
				 || RPAD(l_inSakiSystemId, 4, ' ')  -- sakiSystemId (4)
				 || '        '  -- blank1 (8)
				 || '0000';  -- zero1 (4)
	-- Add blank2 separately to ensure it's included
	pOutMicHdr := pOutMicHdr || REPEAT(' ', 98);  -- blank2 (98)
	CALL pkLog.debug('BATCH', C_FUNCTION_ID, '***** ' || C_FUNCTION_ID || ' END *****');
	RETURN pOutMicHdr;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipxb09k15r01_mic ( l_inMotoGyomuId TEXT, l_inSakiSystemId TEXT, l_inGyomuYmd TEXT, l_inDenbunNo integer  ) FROM PUBLIC;