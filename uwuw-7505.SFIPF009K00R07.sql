




CREATE OR REPLACE FUNCTION sfipf009k00r07 () RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 「口座情報更新結果リスト」を呼び出し、戻り値により「バッチ帳票印刷管理」の登録を行う。
-- *
-- * @author 渡邊　かよ
-- * @version $Revision: 1.5 $
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
	ncount1   numeric;                                            -- レコード件数（帳票ワーク）
	ncount2   numeric;                                            -- レコード件数（バッチ印刷管理）
	rtn1      integer;                                            -- 呼び出しＳＰリターン値
	rtn2      text;                                      -- 呼び出しＳＰエラーコメント
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN	
        -- 業務日付を取得
	cGyoumuDt := pkDate.getGyomuYmd();
        -- 自行情報取得
        SELECT
              KAIIN_ID
        INTO STRICT  wk_kaiin
        FROM  SOWN_INFO;
	-- 口座情報更新結果リストの呼び出し
	   CALL SPIPF009K00R01('IPF30000911', wk_kaiin, 'BATCH', '1', cGyoumuDt, rtn1, rtn2);
        -- 戻り値が'１'の場合
	IF  rtn1  =  1  THEN
            CALL pkLog.fatal(
           	     'ECM501',
	   	     'IPF009K00R07',
                     'パラメータエラー'
            );
      	    RETURN pkconstant.error();
        -- 戻り値が'９９'の場合
        ELSIF rtn1  =  99 THEN
            CALL pkLog.fatal(
                     'ECM701',
	   	     'IPF009K00R07',
                     '帳票出力エラー'
            );
      	    RETURN pkconstant.fatal();
        -- 全ての戻り値が'０'の場合
        ELSIF  rtn1  IN (0)  THEN
            --帳票ワークにデータが既に作成済みであるかチェック
            SELECT
                COUNT(*)
            INTO STRICT
                ncount1
            FROM
                SREPORT_WK SC16
            WHERE
                    SC16.KEY_CD = wk_kaiin AND
                    SC16.USER_ID = 'BATCH' AND
                    SC16.CHOHYO_KBN = '1' AND
                    SC16.SAKUSEI_YMD = cGyoumuDt AND
                    SC16.CHOHYO_ID = 'IPF30000911' AND
                    SC16.HEADER_FLG = 1;
            IF  ncount1  =  0  THEN
                RETURN pkconstant.success();
            END IF;
            --バッチ帳票印刷管理のデータ削除
	DELETE FROM PRT_OK
	WHERE	ITAKU_KAISHA_CD = wk_kaiin
	AND	KIJUN_YMD = cGyoumuDt
	AND	LIST_SAKUSEI_KBN = '1'
	AND	CHOHYO_ID = 'IPF30000911';
            --バッチ帳票印刷管理にデータが既に作成済みであるかチェック
            SELECT
                COUNT(*)
            INTO STRICT
                ncount2
            FROM
                PRT_OK
            WHERE
                    ITAKU_KAISHA_CD = wk_kaiin AND
                    KIJUN_YMD = cGyoumuDt AND
                    LIST_SAKUSEI_KBN = '1' AND
                    CHOHYO_ID = 'IPF30000911';
            --存在しない場合、バッチ帳票印刷管理の登録を行う
            IF  ncount2  =  0  THEN
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
                                    'IPF30000911',  
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
	    		    'IPF009K00R07',
                            'データが既に登録されています'
                           );
      	        RETURN pkconstant.error();
            END IF;
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
			'IPF009K00R07',
			'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')'
		);
		RETURN pkconstant.fatal();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf009k00r07 () FROM PUBLIC;
