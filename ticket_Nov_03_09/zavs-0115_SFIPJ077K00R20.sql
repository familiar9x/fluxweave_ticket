CREATE OR REPLACE FUNCTION sfipj077k00r20 () RETURNS integer AS $body$
DECLARE

/**
 * 著作権:Copyright(c)2007
 * 会社名:JIP
 *
 * 概要　:カレンダー訂正履歴コピー（事務代行専用）
 *
 * 引数　:なし
 *
 * 返り値: 0:正常
 *        99:異常
 *
 * @author ASK
 * @version $Id: SFIPJ077K00R20.sql,v 1.1 2007/02/15 00:45:24 miura Exp $
 *
 ***************************************************************************
 * ログ　:
 * 　　　日付  開発者名    目的
 * -------------------------------------------------------------------------
 *　2007.02.13 中村        新規作成
 ***************************************************************************
 */
--==============================================================================
--                  定数定義                                                    
--==============================================================================
	C_FUNCTION_ID CONSTANT varchar(50) := 'SFIPJ077K00R20'; -- ファンクションＩＤ
--==============================================================================
--                  カーソル定義                                                
--==============================================================================
	curItakuKaisha CURSOR FOR
		SELECT
			KAIIN_ID  -- 会員ＩＤ（委託会社コード）
		FROM
			VJIKO_ITAKU
		WHERE
			JIKO_DAIKO_KBN = '2';
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- pkLog.debug(pkconstant.BATCH_USER(), C_FUNCTION_ID, C_FUNCTION_ID || ' START');
	
	FOR recItakuKaisha IN curItakuKaisha
	LOOP
		-- 事務代行のカレンダー訂正履歴削除（自行の「1:未承認」「2:リスト出力」かつ同じキー[地域コード、カレンダー日付]のデータ）
		DELETE FROM MCALENDAR_TEISEI
		WHERE
			ITAKU_KAISHA_CD = recItakuKaisha.KAIIN_ID
			AND EXISTS (
				SELECT
					M61.ITAKU_KAISHA_CD
				FROM
					MCALENDAR_TEISEI_JIKO M61
				WHERE
					M61.AREA_CD = MCALENDAR_TEISEI.AREA_CD
					AND M61.CALENDAR_YMD = MCALENDAR_TEISEI.CALENDAR_YMD
					AND M61.MGR_KJT_CHOSEI_KBN IN ('1', '2')
			);
			
		-- 事務代行のカレンダー訂正履歴登録（自行の「1:未承認」「2:リスト出力」かつ同じキー[地域コード、カレンダー日付]のデータ）
		INSERT INTO MCALENDAR_TEISEI(
			ITAKU_KAISHA_CD,    -- 委託会社コード
			AREA_CD,            -- 地域コード
			CALENDAR_YMD,       -- カレンダー日付
			CALENDAR_HENKO_KBN, -- カレンダー変更区分
			MGR_KJT_CHOSEI_KBN, -- 銘柄期日調整処理区分
			LAST_TEISEI_DT,     -- 最終訂正日時
			LAST_TEISEI_ID,     -- 最終訂正者
			SHONIN_DT,          -- 承認日時
			SHONIN_ID,          -- 承認者
			KOUSIN_ID,          -- 更新者
			SAKUSEI_ID          -- 作成者
		)
		SELECT
			recItakuKaisha.KAIIN_ID,
			AREA_CD,
			CALENDAR_YMD,
			CALENDAR_HENKO_KBN,
			'1',
			to_timestamp(pkDate.getCurrentTime(), 'YYYY-MM-DD HH24:MI:SS.US'),
			pkconstant.BATCH_USER(),
			to_timestamp(pkDate.getCurrentTime(), 'YYYY-MM-DD HH24:MI:SS.US'),
			pkconstant.BATCH_USER(),
			pkconstant.BATCH_USER(),
			pkconstant.BATCH_USER()
		FROM
			MCALENDAR_TEISEI_JIKO M61
		WHERE
			M61.MGR_KJT_CHOSEI_KBN IN ('1', '2');
	END LOOP;
	
	-- pkLog.debug(pkconstant.BATCH_USER(), C_FUNCTION_ID, C_FUNCTION_ID || ' END');
	
	-- 終了処理
	RETURN pkconstant.success();
	
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SUBSTR(C_FUNCTION_ID, 1, 12), 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', SUBSTR(C_FUNCTION_ID, 1, 12), 'SQLERRM:' || SQLERRM);
		RETURN pkconstant.FATAL();
END;
$body$
LANGUAGE PLPGSQL;
