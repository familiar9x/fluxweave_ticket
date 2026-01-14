CREATE OR REPLACE FUNCTION sfadi002r28111 (
	l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE,
	l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE,
	l_inItakuKaishaCd MGR_STS.ITAKU_KAISHA_CD%TYPE
) RETURNS integer AS $body$
DECLARE

ora2pg_rowcount int;
--
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * 銘柄関連通知取込み（銘柄情報更新−ＩＳＩＮコード、銘柄突合）
-- *   銘柄情報提供突合処理
-- *
-- * @author  藤江
-- * @version $Revision: 1.10 $
-- * @param  	l_inKkSakuseiDt 	IN 	KK_RENKEI.KK_SAKUSEI_DT%TYPE	機構連携作成日時
-- * @param  	l_inDenbunMeisaiNo 	IN 	KK_RENKEI.DENBUN_MEISAI_NO%TYPE	電文明細Ｎｏ
-- * @param 	l_inItakuKaishaCd  	IN 	MGR_STS.ITAKU_KAISHA_CD%TYPE	委託会社コード
-- * @return 	リターンコード		INTEGER
-- *   		 pkconstant.success()				: 正常
-- *   		 pkconstant.NO_DATA_FIND()	 	: 突合相手なし
-- *   		 pkconstant.RECONCILE_ERROR()		: 突合エラー
-- *           pkconstant.FATAL() 			 	: 致命的エラー
-- 
--====================================================================
--					デバッグ機能										  
--====================================================================
	DEBUG	numeric(1)	:= 1;
--====================================================================*
--                  変数定義
-- *====================================================================
	curComp 		integer;			-- カーソルＩＤ
	gCompFlg 		integer;			-- 突合結果フラグ　0:一致  1:不一致
	gCompAllCnt		integer;			-- 検索結果の突合関連の項目数
	intCount		integer;
	gMsg			varchar(100);		-- 確認リストに出力するエラー内容
	gGyomuYmd		SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE;	-- 業務日付
	tMoto KK_RENKEI.ITEM001%type[];						-- 比較元
	tSaki KK_RENKEI.ITEM001%type[];						-- 比較先
	tempMoto		varchar(400);		-- 比較元の一時変数
	tempSaki		varchar(400);		-- 比較先の一時変数
 	result			integer;			-- 本ＳＰのリターンコード
	gMgrCd			MGR_KIHON.MGR_CD%TYPE;			-- 銘柄コード
	gMgrRnm			MGR_KIHON.MGR_RNM%TYPE;			-- 銘柄略称
	gIsinCd			MGR_KIHON.ISIN_CD%TYPE;			-- ISINコード
	gTktFlg			MGR_KIHON.TOKUTEI_KOUSHASAI_FLG%TYPE;	-- 特定公社債フラグ
	gItakuKaishaRnm	MITAKU_KAISHA.ITAKU_KAISHA_RNM%TYPE;	-- 委託会社略称
	-- 突合情報取得ＳＰパラメータ 
	gInTotsugoNo 	varchar(12);				-- 突合識別番号
	gInCondition 	varchar(4000);				-- 検索条件（突合条件マスタに登録している条件以外）
	gOutSql 		varchar(20000);			-- ＳＱＬ文字列
	gOutItemCnt 	numeric(3);					-- 突合項目数
	gOutItemAtt 	PkCompare.t_ItemAtt_type;	-- 突合項目属性（条件番号、表示項目名）
	gRtn			integer;					-- 突合情報取得ＳＰの戻り値
    gExecuteFlg     numeric := 0;           -- 突合実行フラグ(0:実行しない/1:実行する)
--====================================================================*
--					定数定義
-- *====================================================================
	-- 本SPのID
	SP_ID				CONSTANT varchar(20) := 'SFADI002R28111';
	-- ユーザID
	USER_ID				CONSTANT varchar(10) := pkconstant.BATCH_USER();
	-- 帳票ID
	REPORT_ID			CONSTANT varchar(10) := '';
	-- SELECT句 (突合条件マスタの登録値)の何番目の項目か
	-- (突合項目以外の項目の中での番号)
	POS_MGR_CD			CONSTANT numeric(2) := 1;		-- 銘柄_基本.銘柄コード
	POS_ISIN_CD			CONSTANT numeric(2) := 2;		-- 銘柄_基本.ＩＳＩＮコード
	POS_MGR_RNM			CONSTANT numeric(2) := 3;
--====================================================================*
--   メイン
-- *====================================================================
BEGIN
	result := pkconstant.FATAL();
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' START');	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inKkSakuseiDt::text), '') = ''
	  OR coalesce(trim(both l_inDenbunMeisaiNo::text), '') = ''
	  OR coalesce(trim(both l_inItakuKaishaCd::text), '') = '' THEN
		-- パラメータエラー
		CALL pkLog.error('ECM501', SP_ID, ' ');
		RETURN result;
	END IF;
    -- IP-01831 (2) 自行＋委託Viewに発行代理人または支払い代理人が存在する場合のみ
    --              この下の突合処理及びエラーリスト出力処理を行う(自システム内に存在するものだけ突合処理を行う)
    --              (それ以外は突合処理自体を無視させる ＝ エラーリストは出力させないということになる)
    --              ただし、エラーを出力しないだけで、SFADI002R28112でのMGR_TEIKYOUにはDelete_Insertする処理は実行する！
    SELECT CASE WHEN SUM(UNION_TABLE.COUNTER)=0 THEN  0  ELSE 1 END  AS EXECUTE_FLG
    INTO STRICT gExecuteFlg
      FROM (SELECT (SELECT COUNT(VJ01.KAIIN_ID)
                           FROM VJIKO_ITAKU VJ01
                          WHERE RT02.ITEM024 = VJ01.HAKKODAIRI_CD) AS COUNTER
              FROM KK_RENKEI RT02
             WHERE RT02.KK_SAKUSEI_DT = l_inKkSakuseiDt
               AND RT02.DENBUN_MEISAI_NO = l_inDenbunMeisaiNo

		UNION ALL

            SELECT (SELECT COUNT(VJ01.KAIIN_ID)
                           FROM VJIKO_ITAKU VJ01
                          WHERE RT02.ITEM025 = VJ01.SHRDAIRI_CD) AS COUNTER
              FROM KK_RENKEI RT02
             WHERE RT02.KK_SAKUSEI_DT = l_inKkSakuseiDt
               AND RT02.DENBUN_MEISAI_NO = l_inDenbunMeisaiNo) UNION_TABLE;
    -- 突合実行フラグが0の場合はここで正常終了する
    IF gExecuteFlg <= 0 THEN  -- 突合実行フラグ(0:実行しない/1:実行する)
        
        -- 実行しないで終了する
        IF DEBUG = 1 THEN CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' 自行委託Viewに発行代理人コード及び支払代理人コードが存在しないので突合処理を行いません。');END IF;
        -- 突合相手なし終了：突合はしてないが、結果的には必ず突合相手なしになる。
        RETURN(pkconstant.NO_DATA_FIND());
    END IF;
	-- IP-01831 (2) ここまで
    -- 実行しないで終了する
    IF DEBUG = 1 THEN CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' 自行委託Viewに発行代理人コード及び支払代理人コードが存在するので突合処理を開始します。');END IF;
	-- 業務日付取得  
	gGyomuYmd := pkDate.getGyomuYmd();
	-- 委託会社略称取得  
	gItakuKaishaRnm := pkKkNotice.getItakuKaishaRnm(l_inItakuKaishaCd);
	-- 突合情報取得ＳＰをＣＡＬＬ   
	-- ＳＱＬと突合項目数を取得する 
	-- 入力パラメータ設定
	gInTotsugoNo := pkKkNotice.DCD_MGR_TEIKYO();
	gInCondition := 'RT02.KK_SAKUSEI_DT = ''' || l_inKkSakuseiDT
				|| ''' AND RT02.DENBUN_MEISAI_NO = ' || l_inDenbunMeisaiNo
				|| ' AND VMG1.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || '''';
	IF DEBUG = 1 THEN CALL pkLog.debug(USER_ID, REPORT_ID, 'Calling getCompareInfo with: ' || gInTotsugoNo || ', ' || gInCondition); END IF;
	-- ＳＰ実行 - Use SELECT INTO for function returning record type
	SELECT * INTO gOutSql, gOutItemCnt, gOutItemAtt, gRtn
	FROM pkCompare.getCompareInfo(gInTotsugoNo, gInCondition);
	IF DEBUG = 1 THEN CALL pkLog.debug(USER_ID, REPORT_ID, 'getCompareInfo returned: gRtn=' || gRtn || ', ItemCnt=' || gOutItemCnt || ', SQL=' || COALESCE(SUBSTR(gOutSql, 1, 100), 'NULL')); END IF;
	IF gRtn != 0 THEN
		RETURN result;
	END IF;
	gCompAllCnt := gOutItemCnt * 2;
   -- 問い合わせ用のカーソルをオープンする 
   curComp := DBMS_SQL.OPEN_CURSOR();
   -- SELECT SQLを解析 
    CALL DBMS_SQL.PARSE(curComp,gOutSql);
	-- 配列初期化 
	FOR i IN 1 .. gOutItemCnt LOOP
		tMoto[i] := '';
		tSaki[i] := '';
	END LOOP;
   -- 出力変数を定義 
	-- 突合項目以外
    CALL DBMS_SQL.DEFINE_COLUMN(curComp, (gCompAllCnt + POS_MGR_CD)::int, gMgrCd, 20);
    CALL DBMS_SQL.DEFINE_COLUMN(curComp, (gCompAllCnt + POS_ISIN_CD)::int, gIsinCd, 20);
    CALL DBMS_SQL.DEFINE_COLUMN(curComp, (gCompAllCnt + POS_MGR_RNM)::int, gMgrRnm, 100);
	-- 突合項目
	FOR i IN 1 .. gOutItemCnt LOOP
	    CALL DBMS_SQL.DEFINE_COLUMN(curComp, (i * 2 - 1)::int, tMoto[i], 400);
	    CALL DBMS_SQL.DEFINE_COLUMN(curComp, (i * 2)::int, tSaki[i], 400);
	END LOOP;
	-- 検索実行 
	intCount := DBMS_SQL.EXECUTE(curComp);
	-- FETCH 
    IF DBMS_SQL.FETCH_ROWS(curComp) = 0 THEN
    	-- 該当データがない場合は終了
		CALL DBMS_SQL.CLOSE_CURSOR(curComp);
		CALL pkLog.error('ECM3A1', SP_ID, '銘柄_基本VIEW');
        -- 確認リスト出力内容を帳票ワークテーブルに登録
		CALL SFADI002R28111_noDataKakuninList(l_inKkSakuseiDt,
																					l_inDenbunMeisaiNo,
																					l_inItakuKaishaCd,
																					USER_ID,
																					gGyomuYmd,
																					gItakuKaishaRnm,
																					gMsg,
																					gIsinCd);
		result := pkconstant.NO_DATA_FIND();
		RETURN(result);
    END IF;
     -- 値を取り出す 
	-- 突合項目以外
	CALL DBMS_SQL.COLUMN_VALUE(curComp, (gCompAllCnt + POS_MGR_CD)::int, gMgrCd);
	CALL DBMS_SQL.COLUMN_VALUE(curComp, (gCompAllCnt + POS_ISIN_CD)::int, gIsinCd);
	CALL DBMS_SQL.COLUMN_VALUE(curComp, (gCompAllCnt + POS_MGR_RNM)::int, gMgrRnm);
	gCompFlg := 0;
	-- 突合項目
	-- 　比較元、比較先、条件番号の組を１組ずつ取り出し、突合
	-- 　突合項目数繰り返す
	FOR i IN 1 .. gOutItemCnt LOOP
		tempMoto := '';
		tempSaki := '';
     	CALL DBMS_SQL.COLUMN_VALUE(curComp, (i * 2 - 1)::int, tempMoto);
      	CALL DBMS_SQL.COLUMN_VALUE(curComp, (i * 2)::int, tempSaki);
		tMoto[i] := tempMoto;
		tSaki[i] := tempSaki;
--
--        DBMS_OUTPUT.PUT_LINE('項目' || i);
--        DBMS_OUTPUT.PUT_LINE('tMoto_' || [i] || ' = ' || tMoto[i]);
--        DBMS_OUTPUT.PUT_LINE('tSaki_' || [i] || ' = ' || tSaki[i]);
--
		-- 突合処理
		IF coalesce(trim(both tMoto[i]), ' ') != coalesce(trim(both tSaki[i]), ' ') THEN 		-- 不一致のとき
--			DBMS_OUTPUT.PUT_LINE('NG');
			gCompFlg := 1;
			-- 確認リストのエラー内容
			gMsg := gOutItemAtt[i].dispNm;		-- 表示項目名
			IF (gMsg IS NOT NULL AND gMsg::text <> '') THEN
				IF gMsg = '特定公社債フラグ' THEN
					gMsg := gMsg || 'が';
					gMsg := gMsg || '突合エラーです。機構の特定公社債フラグの更新を行いました。';
				ELSE
					gMsg := gMsg || 'が';
					gMsg := gMsg || '突合エラーです。';
        		END IF;
			END IF;
			-- 確認リスト出力内容を帳票ワークテーブルに登録
			CALL pkKakuninList.insertKakuninData(
					l_inItakuKaishaCd,
					USER_ID,
					pkKakuninList.CHOHYO_KBN_BATCH(),
					gGyomuYmd,
					gMsg,
					gIsinCd,
					gMgrCd,
					gMgrRnm,
					tSaki[i],
					tMoto[i],
					pkKkNotice.DCD_MGR_TEIKYO(),
					gItakuKaishaRnm
			);
--		ELSE
--			DBMS_OUTPUT.PUT_LINE('OK');
		END IF;
	END LOOP;
     -- カーソル　クローズ 
	CALL DBMS_SQL.CLOSE_CURSOR(curComp);
	-- 不一致の項目がある場合
	IF gCompFlg = 1 THEN
		-- 銘柄ステータス管理テーブル更新（銘柄機構エラーコード）
		UPDATE 	MGR_STS
		SET		MGR_KK_ERR_CD = pkKkNotice.MGR_KKERR_UNMATCH(),
    			LAST_TEISEI_DT = to_timestamp(pkDate.getCurrentTime(), 'YYYY-MM-DD HH24:MI:SS.US'),
    			KOUSIN_ID = USER_ID
		WHERE	ITAKU_KAISHA_CD = l_inItakuKaishaCd
		  AND	MGR_CD = gMgrCd;
		GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;
IF ora2pg_rowcount = 0 THEN
			CALL pkLog.error('ECM3A3', SP_ID, '銘柄ステータス管理');
			result := pkconstant.NO_DATA_FIND();
		ELSE
			CALL pkLog.error('ECM3A2', SP_ID, ' ');
			-- 新コード対応
			result := pkconstant.NOMATCH_ERROR();
		END IF;
		-- 銘柄基本テーブル、銘柄機構基本テーブルの更新（特定公社債フラグ）
		CALL SFADI002R28111_updateTokuteiKoshasai(l_inItakuKaishaCd,
																							gMgrCd,
																							SP_ID,
																							gTktFlg,
																							result);
	ELSE
		result := pkconstant.success();
	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(USER_ID, REPORT_ID, SP_ID || ' END');	END IF;
	RETURN(result);
--====================================================================*
--    異常終了 出口
-- *====================================================================
EXCEPTION
	-- その他・例外エラー 
	WHEN OTHERS THEN
		IF DBMS_SQL.IS_OPEN(curComp) THEN
			CALL DBMS_SQL.CLOSE_CURSOR(curComp);
		END IF;
		CALL pkLog.fatal('ECM701', SP_ID, SQLSTATE || SUBSTR(SQLERRM, 1, 100));
		RETURN result;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfadi002r28111 ( l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE, l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE, l_inItakuKaishaCd MGR_STS.ITAKU_KAISHA_CD%TYPE ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfadi002r28111_nodatakakuninlist (
	l_inKkSakuseiDt KK_RENKEI.KK_SAKUSEI_DT%TYPE,
	l_inDenbunMeisaiNo KK_RENKEI.DENBUN_MEISAI_NO%TYPE,
	l_inItakuKaishaCd MGR_STS.ITAKU_KAISHA_CD%TYPE,
	USER_ID varchar(10),
	gGyomuYmd SSYSTEM_MANAGEMENT.GYOMU_YMD%TYPE,
	gItakuKaishaRnm MITAKU_KAISHA.ITAKU_KAISHA_RNM%TYPE,
	gMsg IN OUT varchar(100),
	gIsinCd IN OUT MGR_KIHON.ISIN_CD%TYPE
) AS $body$
BEGIN
	-- 機構連携検索
	SELECT 	ITEM004		-- ISINコード
	INTO STRICT 	gIsinCd
	FROM 	KK_RENKEI
	WHERE 	KK_SAKUSEI_DT = l_inKkSakuseiDt
	  AND 	DENBUN_MEISAI_NO = l_inDenbunMeisaiNo;
	-- 確認リスト出力内容を帳票ワークテーブルに登録
	gMsg := '突合相手がありません。';
        CALL pkKakuninList.insertKakuninData(
            	l_inItakuKaishaCd,
            	USER_ID,
            	pkKakuninList.CHOHYO_KBN_BATCH(),
            	gGyomuYmd,
            	gMsg,
            	gIsinCd,
            	NULL,
            	NULL,
							NULL,
							NULL,
            	pkKkNotice.DCD_MGR_TEIKYO(),
            	gItakuKaishaRnm
        );
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfadi002r28111_nodatakakuninlist () FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfadi002r28111_updatetokuteikoshasai (
	l_inItakuKaishaCd MGR_STS.ITAKU_KAISHA_CD%TYPE,
	gMgrCd MGR_KIHON.MGR_CD%TYPE,
	SP_ID varchar(20),
	gTktFlg IN OUT MGR_KIHON.TOKUTEI_KOUSHASAI_FLG%TYPE,
	result IN OUT integer
) AS $body$
DECLARE
ora2pg_rowcount int;
BEGIN
	-------------------------------------------------------
	-- 機構連携検索
	-------------------------------------------------------
	SELECT 	ITEM100		-- 特定公社債フラグ
	INTO STRICT 	gTktFlg
	FROM 	KK_RENKEI
	WHERE 	KK_SAKUSEI_DT = l_inKkSakuseiDt
	  AND 	DENBUN_MEISAI_NO = l_inDenbunMeisaiNo;
	-------------------------------------------------------
	-- 銘柄基本テーブルの更新（特定公社債フラグ）
	-------------------------------------------------------
	UPDATE 	MGR_KIHON
	SET		TOKUTEI_KOUSHASAI_FLG = gTktFlg,
    			LAST_TEISEI_DT = to_timestamp(pkDate.getCurrentTime(), 'YYYY-MM-DD HH24:MI:SS.US'),
    			KOUSIN_ID = USER_ID
	WHERE	ITAKU_KAISHA_CD = l_inItakuKaishaCd
	  AND	MGR_CD = gMgrCd;
	GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;
IF ora2pg_rowcount = 0 THEN
		CALL pkLog.error('ECM3A3', SP_ID, '銘柄基本テーブル');
		result := pkconstant.NO_DATA_FIND();
	ELSE
		CALL pkLog.error('ECM3A2', SP_ID, ' ');
		-- 新コード対応
		result := pkconstant.NOMATCH_ERROR();
	END IF;
	-------------------------------------------------------
	-- 銘柄機構基本テーブルの更新（特定公社債フラグ）
	-------------------------------------------------------
	UPDATE 	MGR_KIKO_KIHON
	SET		TOKUTEI_KOUSHASAI_FLG = gTktFlg,
    			LAST_TEISEI_DT = to_timestamp(pkDate.getCurrentTime(), 'YYYY-MM-DD HH24:MI:SS.US'),
    			KOUSIN_ID = USER_ID
	WHERE	ITAKU_KAISHA_CD = l_inItakuKaishaCd
	  AND	MGR_CD = gMgrCd;
	GET DIAGNOSTICS ora2pg_rowcount = ROW_COUNT;
IF ora2pg_rowcount = 0 THEN
		CALL pkLog.error('ECM3A3', SP_ID, '銘柄機構基本テーブル');
		result := pkconstant.NO_DATA_FIND();
	ELSE
		CALL pkLog.error('ECM3A2', SP_ID, ' ');
		-- 新コード対応
		result := pkconstant.NOMATCH_ERROR();
	END IF;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfadi002r28111_updatetokuteikoshasai () FROM PUBLIC;
