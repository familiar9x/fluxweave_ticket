




CREATE OR REPLACE FUNCTION sfipf011k01r03 () RETURNS integer AS $body$
DECLARE

--==============================================================================
--  日銀当預支払依頼未作成リスト出力指示（夜間バッチ処理）                        
--==============================================================================
--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 「日銀当預支払依頼未作成リスト」を呼び出し、戻り値により「バッチ帳票印刷管理」の登録を行う。
-- *
-- * @author 渡邊　かよ
-- * @version $Revision: 1.3 $
-- *
-- * @return INTEGER
-- *                0:正常終了、データ無し
-- *                1:予期したエラー
-- *               99:予期せぬエラー
-- 
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	Ret       numeric;                                            -- 戻り値
 	cGyoumuDt ssystem_management.gyomu_ymd%type;                 -- 業務日付
	wk_kaiin  SOWN_INFO.KAIIN_ID%type;                           -- 会員ＩＤ 
	ncount    numeric;                                            -- レコード件数
	rtn1      integer;                                            -- 呼び出しＳＰリターン値
	rtn2      text;                                               -- 呼び出しＳＰエラーコメント
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN	
        -- 業務日付を取得
	cGyoumuDt := pkDate.getGyomuYmd();
        -- 会員ＩＤ取得
        SELECT KAIIN_ID INTO STRICT wk_kaiin FROM SOWN_INFO;
        -- 日銀当預支払依頼未作成リストの呼び出し
        CALL SPIPF011K01R02(wk_kaiin, 'BATCH', '1', cGyoumuDt, rtn1, rtn2);
        -- 戻り値が'０'の場合
        IF  rtn1  IN (0)  THEN
            --バッチ帳票印刷管理にデータが既に作成済みであるかチェック
            SELECT
                COUNT(*)
            INTO STRICT
                ncount
    FROM
                PRT_OK
            WHERE
                ITAKU_KAISHA_CD = wk_kaiin AND
                KIJUN_YMD = cGyoumuDt AND
                LIST_SAKUSEI_KBN = '1' AND
                CHOHYO_ID = 'IPF30001121';
            --存在しない場合、バッチ帳票印刷管理の登録を行う
            IF  ncount  =  0  THEN
                INSERT INTO PRT_OK(
                                    ITAKU_KAISHA_CD, 
                                    KIJUN_YMD, 
                                    LIST_SAKUSEI_KBN,  
                                    CHOHYO_ID, 
                                    SHORI_KBN,  
                                    LAST_TEISEI_DT,  
                                    LAST_TEISEI_ID,  
                                    SHONIN_DT,  
                                    SHONIN_ID,  
                                    KOUSIN_DT,  
                                    KOUSIN_ID,  
                                    SAKUSEI_DT,  
                                    SAKUSEI_ID
                             )
                             VALUES (
                                    wk_kaiin, 
                                    cGyoumuDt, 
                                    '1', 
                                    'IPF30001121',  
                                    '1', 
                                    current_timestamp, 
                                    'BATCH', 
                                    current_timestamp, 
                                    'BATCH', 
                                    current_timestamp, 
                                    'BATCH', 
                                    current_timestamp, 
                                    'BATCH' 
                             );
            --存在した場合、エラー処理を行う
            ELSE
                CALL pkLog.fatal(
                            'ECM507',
	    	            'IPF011K01R03',
                            'データが既に登録されています'
                           );
      	        RETURN pkconstant.error();
            END IF;
        -- 戻り値が'１'の場合
        ELSIF  rtn1  =  1  THEN
           CALL pkLog.fatal(
                	'ECM501',
	       		'IPF011K01R03',
        		'パラメータエラー'
                      );
      	   RETURN pkconstant.error();
        -- 戻り値が'９９'の場合
	ELSIF rtn1  =  99 THEN
           CALL pkLog.fatal(
        	       	'ECM701',
	      		'IPF011K01R03',
        		'帳票出力エラー'
                      );
      	   RETURN pkconstant.fatal();
        END IF;
	RETURN pkconstant.success();
--==============================================================================
--                  エラー処理                                                  
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		-- ログ出力
		CALL pkLog.fatal(
			'ECM701',
			'IPF011K01R03',
			'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')'
		);
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf011k01r03 () FROM PUBLIC;
