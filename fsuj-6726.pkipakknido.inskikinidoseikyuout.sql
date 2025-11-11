CREATE OR REPLACE FUNCTION pkipakknido.getkaikeianbuncount ( l_initakukaishacd MGR_KIHON.ITAKU_KAISHA_CD%TYPE, l_inmgrcd MGR_KIHON.MGR_CD%TYPE ) RETURNS numeric AS $body$
DECLARE

		gCnt              numeric  := 0;
	
BEGIN

		SELECT
			COUNT(1)  
		INTO STRICT
			gCnt
		FROM
			KAIKEI_ANBUN
		WHERE
			ITAKU_KAISHA_CD = l_initakukaishacd
		AND	MGR_CD = l_inmgrcd
		AND	SHORI_KBN = '1'
		;

		RETURN gCnt;

	END;
$body$
LANGUAGE PLPGSQL
;

CREATE OR REPLACE FUNCTION pkipakknido.inskikinidoseikyuout (
 l_inUserId TEXT ,      -- ユーザID
 l_inGyomuYmd TEXT ,             -- 業務日付
 l_inKjnFrom TEXT ,              -- 基準日From
 l_inKjnTo TEXT ,                -- 基準日To
 l_inItakuKaishaCd text ,    -- 委託会社CD
 l_inKknZndkKjnYmdKbn text,  -- 基金残高基準日区分
 l_inHktCd TEXT ,                -- 発行体CD
 l_inKozatenCd text ,        -- 口座店CD
 l_inKozatenCifCd text ,     -- 口座店CIFCD
 l_inMgrCd TEXT ,                -- 銘柄CD
 l_inIsinCd TEXT ,               -- ISINCDd
 l_inTsuchiYmd TEXT ,            -- 通知日
 l_inSeikyushoId text,       -- 請求書ID
 l_inRealBatchKbn TEXT,          -- リアルバッチ区分
 l_inDataSakuseiKbn KIKIN_IDO.DATA_SAKUSEI_KBN%TYPE,--データ作成区分
 l_inSeikyuIchiranKbn TEXT,      -- 請求書一覧区分
 l_inChikoFlg TEXT,				-- 地公体利用フラグ
 l_inFrontFlg text,			-- フロント照会画面判別フラグ
 l_OutSqlCode OUT INTEGER,         -- SQLエラーコード
 l_OutSqlErrM OUT text          -- SQLエラーメッセージ
 , OUT extra_param integer) RETURNS record AS $body$
DECLARE
		rec pkipakknido.recType[];   --システム設定分と個別設定分を取得するカーソルのレコード
						--システム設定分と個別設定分を取得するカーソルタイプ
		--pCur REFCURSOR;	--システム設定分と個別設定分を取得するカーソル
		pCurSql                     varchar(10000) := NULL;
		pCurRec		record;

		pReturnCode integer := 0;
		pRowCnt     integer := 0;
		intMax      integer := 0;

		WK_GNR_TESU_ID char(11) := NULL;    -- バッチの時、作票対象データのキーを帳票WKへ退避しておくための帳票ID
		--gWrkTsuchiYmd		VARCHAR(16) DEFAULT NULL;					-- 通知日(和暦)
		pRbrYmdFrom char(8) := '99999999';     -- 徴求日 From
		pRbrYmdTo   char(8) := '00000000';     -- 徴求日 To
		pHeizonSeikyuKbn	char(1) := '';		-- 自行委託ビュー.併存銘柄請求区分
		optionFlg   MOPTION_KANRI.OPTION_FLG%TYPE := '0';  -- オプションフラグ
		DEBUG smallint := 0;

		temp_rItakuKaishaCd char(4);
		temp_rMgrCd varchar(13);
		temp_rRbrKjt char(8);
		temp_rChokyuYmd char(8);

		l_inItem 	   		TYPE_SREPORT_WK_ITEM;
BEGIN

	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inUserId : ' || l_inUserId ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inGyomuYmd : ' || l_inGyomuYmd ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inKjnFrom : ' || l_inKjnFrom ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inKjnTo : ' || l_inKjnTo ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inItakuKaishaCd : ' || l_inItakuKaishaCd ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inKknZndkKjnYmdKbn : ' || l_inKknZndkKjnYmdKbn ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inHktCd : ' || l_inHktCd ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inKozatenCd : ' || l_inKozatenCd ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inKozatenCifCd : ' || l_inKozatenCifCd ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inMgrCd : ' || l_inMgrCd ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inIsinCd : ' || l_inIsinCd ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inTsuchiYmd : ' || l_inTsuchiYmd ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inSeikyushoId : ' || l_inSeikyushoId ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inRealBatchKbn : ' || l_inRealBatchKbn ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inDataSakuseiKbn : ' || l_inDataSakuseiKbn ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inSeikyuIchiranKbn : ' || l_inSeikyuIchiranKbn ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_inChikoFlg : ' || l_inChikoFlg ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_OutSqlCode : ' || l_OutSqlCode ); END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug( l_inUserId, 'insKikinIdoSeikyuOut', '引数 l_OutSqlErrM : ' || l_OutSqlErrM ); END IF;


	 -- RAISE NOTICE 'xxx引数 l_inUserId : %' ,l_inUserId;
	 -- RAISE NOTICE '引数 l_inGyomuYmd : %' ,l_inGyomuYmd;
	 -- RAISE NOTICE '引数 l_inKjnFrom : %' ,l_inKjnFrom;
	 -- RAISE NOTICE '引数 l_inKjnTo : %' ,l_inKjnTo;
	 -- RAISE NOTICE '引数 l_inItakuKaishaCd : %' ,l_inItakuKaishaCd;
	 -- RAISE NOTICE '引数 l_inKknZndkKjnYmdKbn : %' ,l_inKknZndkKjnYmdKbn;
	 -- RAISE NOTICE '引数 l_inHktCd : %' ,l_inHktCd;
	 -- RAISE NOTICE '引数 l_inKozatenCd : %' ,l_inKozatenCd;
	 -- RAISE NOTICE '引数 l_inKozatenCifCd : %' ,l_inKozatenCifCd;
	 -- RAISE NOTICE '引数 l_inMgrCd : %' ,l_inMgrCd;
	 -- RAISE NOTICE '引数 l_inIsinCd : %' ,l_inIsinCd;
	 -- RAISE NOTICE '引数 l_inTsuchiYmd : %' ,l_inTsuchiYmd;
	 -- RAISE NOTICE '引数 l_inSeikyushoId : %' ,l_inSeikyushoId;
	 -- RAISE NOTICE '引数 l_inRealBatchKbn : %' ,l_inRealBatchKbn;
	 -- RAISE NOTICE '引数 l_inDataSakuseiKbn : %' ,l_inDataSakuseiKbn;
	 -- RAISE NOTICE '引数 l_inSeikyuIchiranKbn : %' ,l_inSeikyuIchiranKbn;
	 -- RAISE NOTICE '引数 l_inChikoFlg : %' ,l_inChikoFlg;
	 -- RAISE NOTICE '引数 l_inFrontFlg : %', l_inFrontFlg;

		--カーソルの作成    抽出条件に該当するレコードを基金移動テーブルに更新する
		pCurSql := pkipakknido.createsql(l_ingyomuymd,l_inkjnfrom,l_inkjnto,l_initakukaishacd,l_inhktcd,l_inkozatencd,l_inkozatencifcd,l_inmgrcd,l_inisincd,l_inrealbatchkbn,l_inseikyuichirankbn,'0');

		-- 併存銘柄請求区分取得
		SELECT HEIZON_SEIKYU_KBN INTO STRICT pHeizonSeikyuKbn FROM VJIKO_ITAKU WHERE KAIIN_ID = l_inItakuKaishaCd;

		--TEST_DEBUG_LOG('TEST',pCurSql);
		FOR pCurRec IN EXECUTE pCurSql
		LOOP
			-- FETCH pCur INTO
			-- 	temp_rItakuKaishaCd,
			-- 	temp_rMgrCd,
			-- 	temp_rRbrKjt,
			-- 	temp_rChokyuYmd;

			-- EXIT WHEN NOT FOUND; /* apply on pCur */

			rec[pRowCnt].rItakuKaishaCd := pCurRec.ITAKU_KAISHA_CD;
			rec[pRowCnt].rMgrCd := pCurRec.MGR_CD;
			rec[pRowCnt].rRbrKjt := pCurRec.RBR_KJT;
			rec[pRowCnt].rChokyuYmd := pCurRec.CHOKYU_YMD;

			 -- RAISE NOTICE 'in loop, l_inFrontFlg: %, pCurRec.CHOKYU_YMD: %, pHeizonSeikyuKbn: %', l_inFrontFlg, pCurRec.CHOKYU_YMD, pHeizonSeikyuKbn;
			 -- RAISE NOTICE 'rec[pRowCnt].rItakuKaishaCd: %', rec[pRowCnt].rItakuKaishaCd;
			 -- RAISE NOTICE 'rec[pRowCnt].rMgrCd: %', rec[pRowCnt].rMgrCd;
			 -- RAISE NOTICE 'rec[pRowCnt].rChokyuYmd: %', rec[pRowCnt].rChokyuYmd;


			-- フロント照会帳票出力指示以外からcallされた場合、基金異動計算・更新処理を行う。
			IF l_inFrontFlg = '0' THEN

				-- 併存銘柄請求区分='0'(出力しない) かつ、併存銘柄(実質残高(現登債)と実質残高(振替債)が両方0円ではない)場合は
				-- 計算および基金異動テーブル更新処理を行わない
				IF NOT(pHeizonSeikyuKbn = '0'
					AND (PKIPAZNDK.getKjnZndk(rec[pRowCnt].rItakuKaishaCd,rec[pRowCnt].rMgrCd,rec[pRowCnt].rChokyuYmd,3))::numeric  > 0			-- 振替債実質残高
					AND (PKIPAZNDK.getKjnZndk(rec[pRowCnt].rItakuKaishaCd,rec[pRowCnt].rMgrCd,rec[pRowCnt].rChokyuYmd,83))::numeric  > 0) THEN	-- 現登債実質残高
/*					-- 地行体帳票を出力した場合は地行体銘柄のみ基金異動履歴にデータを作成するための対応
					-- 自行情報マスタ.地公体フラグがONかつ公社債元利金支払基金請求書or公債会計別元利金明細表かつ会計按分テーブルにデータがある場合、
					-- または、自行情報マスタ.地公体フラグがONかつ元利払基金・手数料請求書or元利払基金・手数料請求明細書かつ会計按分テーブルにデータがない場合、
					-- または、自行情報マスタ.地公体フラグがONかつ元利払基金・手数料請求一覧表の場合、
					-- または、自行情報マスタ.地公体フラグがOFFの場合に基金異動履歴更新処理を行う。
					IF (l_inChikoFlg = '1' AND (l_inSeikyushoId = pkipakknido.c_SEIKYU_KAIKEIKUBUN()
												OR l_inSeikyushoId = pkipakknido.c_ganri_meisai()
												OR l_inSeikyushoId = pkipakknido.c_GANRI_MEISAI_M())
						AND pkipakknido.getkaikeianbuncount(rec[pRowCnt].rItakuKaishaCd, rec[pRowCnt].rMgrCd) > 0)
					OR (l_inChikoFlg = '1' AND (l_inSeikyushoId = pkipakknido.c_seikyu() OR l_inSeikyushoId = pkipakknido.c_SEIKYU_MEISAI())
						AND pkipakknido.getkaikeianbuncount(rec[pRowCnt].rItakuKaishaCd, rec[pRowCnt].rMgrCd) = 0)
					OR (l_inChikoFlg = '1' AND l_inSeikyushoId = pkipakknido.c_SEIKYU_ICHIRAN())
					OR (l_inChikoFlg = '0') THEN
*/
					-- 自行情報マスタ.地公体フラグがOFFの場合に基金異動履歴更新処理を行う。
					 -- RAISE NOTICE 'IN IF NOT(pHeizonSeikyuKbn = 0';

					IF (l_inChikoFlg = '0') THEN 
						-- 基金異動計算・更新処理
						-- リアル・バッチ区分は「0」（リアル）「1」（バッチ）
						 -- RAISE NOTICE 'CALLING sfInsKikinIdo';
						pReturnCode := sfInsKikinIdo(
												pkConstant.BATCH_USER(),
												rec[pRowCnt].rItakuKaishaCd,
												rec[pRowCnt].rMgrCd,
												rec[pRowCnt].rRbrKjt,
												rec[pRowCnt].rChokyuYmd,
												l_indatasakuseikbn,
												l_inrealbatchkbn,
												l_inKknZndkKjnYmdKbn);
						 -- RAISE NOTICE 'sfInsKikinIdo return code: %', pReturnCode;
					END IF;

				END IF;

				IF pReturnCode <> 0 THEN
					l_OutSqlCode := pReturnCode;
					l_OutSqlErrM := '基金請求計算処理（データ作成区分'||l_indatasakuseikbn||'）が失敗しました。';
					CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlErrM);
					extra_param := pReturnCode;
					RETURN;
				END IF;

				-- 自行情報マスタ.地公体フラグがONかつ会計按分テーブルにデータがある場合
				-- 会計区分別基金請求計算SPを呼び出す。
/*
				IF l_inChikoFlg = '1' THEN
					IF pkipakknido.getkaikeianbuncount(rec[pRowCnt].rItakuKaishaCd, rec[pRowCnt].rMgrCd) > 0 THEN
						pReturnCode := sfIph999_KIKIN_IDO_KAIKEI(rec[pRowCnt].rItakuKaishaCd,
																rec[pRowCnt].rMgrCd,
																rec[pRowCnt].rRbrKjt,
																rec[pRowCnt].rChokyuYmd,
																l_inuserid,
																pkipakknido.getgroupid(l_inuserid));
						IF pReturnCode <> 0 THEN
							l_OutSqlCode := pReturnCode;
							l_OutSqlErrM := '会計区分別基金請求計算処理（データ作成区分'||l_indatasakuseikbn||'）が失敗しました。';
							CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlErrM);
							extra_param := pReturnCode;
							RETURN;
						END IF;
					END IF;
				END IF;
*/
			END IF;


			pRowCnt := pRowCnt + 1;

		END LOOP;
		-- CLOSE pCur;
		 -- RAISE NOTICE 'end loop pCur:=, l_inRealBatchKbn: %', l_inRealBatchKbn;

		-- バッチの場合、作票SPに渡す条件の加工を行う
		-- （ここで抽出したデータを、キーとして帳票WKに退避）
		IF l_inRealBatchKbn = '1' then
			 -- RAISE NOTICE 'IF l_inRealBatchKbn = 1 then';

			WK_GNR_TESU_ID := 'WK' || SUBSTR(l_inSeikyushoId, 3, 9);    -- 作票対象データを仮登録しておく帳票WKの帳票ID
			-- 帳票WKに残っているかもしれない仮データをDELETE
			DELETE FROM SREPORT_WK
				WHERE CHOHYO_ID = WK_GNR_TESU_ID;

	intMax := pRowCnt - 1;
	pRowCnt := 0;
	FOR pRowCnt IN 0..intMax LOOP
		-- Initialize record (PostgreSQL doesn't need ROW() for custom types)
		l_inItem.l_inItem001 := rec[pRowCnt].rMgrCd;					-- 銘柄コード
		l_inItem.l_inItem002 := rec[pRowCnt].rRbrKjt;					-- 利払期日
		l_inItem.l_inItem003 := rec[pRowCnt].rChokyuYmd;				-- 徴求日

		CALL pkPrint.insertData(
			 l_inkeyCd         =>    rec[pRowCnt].rItakuKaishaCd     -- 識別コード
			,l_inUserId        =>    l_inUserId                      -- ユーザID
			,l_inChohyoKbn     =>    l_inRealBatchKbn                -- 帳票区分
			,l_inSakuseiYmd    =>    l_inGyomuYmd                    -- 作成年月日
			,l_inChohyoId      =>    WK_GNR_TESU_ID                  -- WK帳票ID
			,l_inSeqNo         =>    pRowCnt                         -- SEQNO
			,l_inHeaderFlg     =>    '1'                             -- ヘッダフラグ
			,l_inItem		   =>	 l_inItem
			,l_inKousinId      =>    l_inUserId                      -- 更新者ID
			,l_inSakuseiId     =>    l_inUserId                      -- 作成者ID
		);			END LOOP;

		END IF;

		 -- RAISE NOTICE '実質記番号オプション用処理 START';

		----- 実質記番号オプション用処理 START
		BEGIN
			SELECT OPTION_FLG
			INTO STRICT  optionFlg
			FROM  MOPTION_KANRI
			WHERE KEY_CD = l_inItakuKaishaCd
			AND   OPTION_CD = 'IPP1003302010';
		EXCEPTION
			WHEN no_data_found THEN
				optionFlg := 0;
		END;

		-- フロント照会帳票出力指示以外からcallされた場合、基金異動計算・更新処理を行う。
/*
		IF l_inFrontFlg = '0' THEN
			IF optionFlg = 1 THEN
				-- 実質記番号管理オプション　基金異動計算・更新処理
				pReturnCode := pkIpaKibango.insKknIdo(  l_inUserId,
														l_inKjnFrom,
														l_inKjnTo,
														l_inItakuKaishaCd,
														l_inHktCd,
														l_inKozatenCd,
														l_inKozatenCifCd,
														l_inMgrCd,
														l_inIsinCd,
														l_inSeikyushoId,
														l_inRealBatchKbn,
														l_inDataSakuseiKbn,
														l_inKknZndkKjnYmdKbn,
														l_OutSqlErrM);
				IF pReturnCode <> 0 THEN
					l_OutSqlCode := pReturnCode;
					CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlErrM);
					extra_param := pReturnCode;
					RETURN;
				END IF;
			END IF;
			----- 実質記番号オプション用処理 END
		END IF;
*/
		-- バッチの場合は、基準日From、Toに、MIN値、MAX値をセット
		IF l_inRealBatchKbn = '1' THEN
			pRbrYmdFrom := '00000000';
			pRbrYmdTo   := '99999999';
		ELSE
			pRbrYmdFrom	:= l_inKjnFrom;
			pRbrYmdTo	:= l_inKjnTo;
		END IF;

		 -- RAISE NOTICE 'IP030004511　帳票　元利払基金・手数料請求一覧表';

		-- IP030004511　帳票　元利払基金・手数料請求一覧表
		IF l_inseikyushoid = pkipakknido.c_SEIKYU_ICHIRAN() THEN
			 -- RAISE NOTICE 'in 元利払基金・手数料請求一覧表を作成する';

			-- 元利払基金・手数料請求一覧表を作成する
			IF pkControl.getCtlValue(l_inItakuKaishaCd, 'pkIpaKknIdo1', '0') = '1' THEN
				 -- RAISE NOTICE 'calling spIp04501_02';

				 CALL spIp04501_02(
					l_inSeikyushoId,   -- 帳票ID
					l_inItakuKaishaCd, -- 委託会社コード
					pRbrYmdFrom,       -- 基準日(From)
					pRbrYmdTo,         -- 基準日(To)
					l_inGyomuYmd,      -- 業務日付
					'1',                 -- 初回レコード区分
					l_inUserId ,       -- ユーザーID
					l_inRealBatchKbn,  -- 帳票区分
					l_OutSqlCode,      -- リターン値
					l_OutSqlErrM       -- エラーコメント
				);
			ELSE
				 -- RAISE NOTICE 'calling spIp04501_01';
				 CALL spIp04501_01(
					l_inSeikyushoId,   -- 帳票ID
					l_inItakuKaishaCd, -- 委託会社コード
					pRbrYmdFrom,       -- 基準日(From)
					pRbrYmdTo,         -- 基準日(To)
					l_inGyomuYmd,      -- 業務日付
					'1',                 -- 初回レコード区分
					l_inUserId ,       -- ユーザーID
					l_inRealBatchKbn,  -- 帳票区分
					l_OutSqlCode,      -- リターン値
					l_OutSqlErrM       -- エラーコメント
				);
			END IF;

			 -- RAISE NOTICE 'calling spIp04501_01 or spIp04502_01 completed';

			-- 戻り値が２の場合は0にする
			IF coalesce(l_OutSqlCode,0) = 2 THEN
				-- ２：帳票データなしだけど、正常終了
				l_OutSqlCode := 0;
			END IF;

			-- 戻り値チェック(エラーの場合はすぐに戻る)
			IF coalesce(l_OutSqlCode,0) <> 0 THEN
				CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlCode);
				CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlErrM);
				extra_param := l_OutSqlCode;

				 -- RAISE NOTICE '戻り値チェック(エラーの場合はすぐに戻る) l_OutSqlErrM: %', l_OutSqlErrM;
				RETURN;
			END IF;

		END IF;


		-- IP030004631　帳票　元利払基金・手数料請求書(領収書)
		IF l_inseikyushoid = pkipakknido.c_seikyu() THEN

			-- 元利払基金・手数料請求書(領収書)を作成する
			IF pkControl.getCtlValue(l_inItakuKaishaCd, 'pkIpaKknIdo1', '0') = '1' THEN
				 -- RAISE NOTICE 'calling spipi046k00r02';

				 CALL spipi046k00r02(
					l_inSeikyushoId,   -- 帳票ID
					l_inItakuKaishaCd, -- 委託会社コード
					pRbrYmdFrom,       -- 基準日(From)
					pRbrYmdTo,         -- 基準日(To)
					l_inGyomuYmd,      -- 業務日付
					'1',                 -- 初回レコード区分
					l_inUserId,        -- ユーザーID
					l_inRealBatchKbn,  -- 帳票区分
					l_inHktCd,         -- 発行体コード
					l_inKozatenCd,     -- 口座店コード
					l_inKozatenCifCd,  -- 口座店CIFコード
					l_inMgrCd,         -- 銘柄コード
					l_inIsinCd,        -- ISINコード
					l_inTsuchiYmd,     -- 通知日
					l_outSqlCode,      -- リターン値
					l_outSqlErrM       -- エラーコメント
				);
			ELSE
				 -- RAISE NOTICE 'calling spipi046k00r01';

				 CALL spipi046k00r01(
					l_inSeikyushoId,   -- 帳票ID
					l_inItakuKaishaCd, -- 委託会社コード
					pRbrYmdFrom,       -- 基準日(From)
					pRbrYmdTo,         -- 基準日(To)
					l_inGyomuYmd,      -- 業務日付
					'1',                 -- 初回レコード区分
					l_inUserId,        -- ユーザーID
					l_inRealBatchKbn,  -- 帳票区分
					l_inHktCd,         -- 発行体コード
					l_inKozatenCd,     -- 口座店コード
					l_inKozatenCifCd,  -- 口座店CIFコード
					l_inMgrCd,         -- 銘柄コード
					l_inIsinCd,        -- ISINコード
					l_inTsuchiYmd,     -- 通知日
					l_outSqlCode,      -- リターン値
					l_outSqlErrM       -- エラーコメント
				);
			END IF;

			-- 戻り値が２の場合は0にする
			IF coalesce(l_OutSqlCode,0) = 2 THEN
				-- ２：帳票データなしだけど、正常終了
				l_OutSqlCode := 0;

			END IF;

			-- 戻り値チェック(エラーの場合はすぐに戻る)
			IF coalesce(l_OutSqlCode,0) <> 0 THEN

				CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlCode);
				CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlErrM);
				extra_param := l_OutSqlCode;

				 -- RAISE NOTICE 'calling spipi046k00r01 completed with errors: %', l_OutSqlErrM;

				RETURN;

			END IF;

		END IF;

		-- IP030010211　帳票　元利払基金・手数料請求明細書
		IF l_inseikyushoid = pkipakknido.c_SEIKYU_MEISAI() THEN
			 -- RAISE NOTICE 'calling SPIPI046K00R03';

			-- 元利払基金・手数料請求明細書を作成する
			 CALL SPIPI046K00R03(
				l_inSeikyushoId,   -- 帳票ID
				l_inItakuKaishaCd, -- 委託会社コード
				pRbrYmdFrom,       -- 基準日(From)
				pRbrYmdTo,         -- 基準日(To)
				l_inGyomuYmd,      -- 業務日付
				'1',                 -- 初回レコード区分
				l_inUserId,        -- ユーザーID
				l_inRealBatchKbn,  -- 帳票区分
				l_inHktCd,         -- 発行体コード
				l_inKozatenCd,     -- 口座店コード
				l_inKozatenCifCd,  -- 口座店CIFコード
				l_inMgrCd,         -- 銘柄コード
				l_inIsinCd,        -- ISINコード
				l_inTsuchiYmd,     -- 通知日
				l_outSqlCode,      -- リターン値
				l_outSqlErrM       -- エラーコメント
			);

			-- 戻り値が２の場合は0にする
			IF coalesce(l_OutSqlCode,0) = 2 THEN
				-- ２：帳票データなしだけど、正常終了
				l_OutSqlCode := 0;

			END IF;

			-- 戻り値チェック(エラーの場合はすぐに戻る)
			IF coalesce(l_OutSqlCode,0) <> 0 THEN

				CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlCode);
				CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlErrM);
				extra_param := l_OutSqlCode;
				RETURN;

			END IF;

		END IF;

		-- 地公体オプション帳票出力
		-- 地公体帳票は画面の入力条件により１回だけ呼び出す
		-- 元利払基金・手数料請求書(会計区分別)の場合
/*
		IF l_inseikyushoid = pkipakknido.c_SEIKYU_KAIKEIKUBUN() THEN
			 CALL SPIPH005K00R01(	 '0'							-- 帳票作成区分には0を指定
							,l_inhktcd						-- 発行体コード
							,l_inkozatencd					-- 口座店コード
							,l_inkozatencifcd				-- 口座店CIFコード
							,l_inmgrcd						-- 銘柄コード
							,l_inisincd						-- ISINコード
							,l_inkjnfrom					-- 基準日(FROM)
							,l_inkjnto						-- 基準日(TO)
							,l_inTsuchiYmd					-- 通知日
							,l_initakukaishacd				-- 委託会社コード
							,l_inuserid						-- ユーザーID
							,l_inrealbatchkbn				-- 帳票区分
							,l_ingyomuymd					-- 業務日付
							,l_OutSqlCode					-- リターン値
							,l_OutSqlErrM					-- エラーコメント
						);
		-- 公債会計別元利金明細表の場合
		ELSIF l_inseikyushoid = pkipakknido.c_ganri_meisai() THEN
			 CALL SPIPH006K00R01(	 l_inhktcd						-- 発行体コード
							,l_inkozatencd					-- 口座店コード
							,l_inkozatencifcd				-- 口座店ＣＩＦコード
							,l_inmgrcd						-- 銘柄コード
							,l_inisincd						-- ISINコード
							,l_inkjnfrom					-- 基準日From
							,l_inkjnto						-- 基準日To
							,l_inTsuchiYmd					-- 通知日
							,l_initakukaishacd				-- 委託会社コード
							,l_inuserid						-- ユーザーID
							,l_inrealbatchkbn				-- 帳票区分
							,l_ingyomuymd					-- 業務日付
							,l_OutSqlCode					-- リターン値
							,l_OutSqlErrM					-- エラーコメント
						);
		END IF;
*/
        -- 戻り値が２の場合は0にする
        IF coalesce(l_OutSqlCode,0) = 2 THEN
            -- ２：帳票データなしだけど、正常終了
            l_OutSqlCode := 0;

        END IF;

		IF coalesce(l_OutSqlCode,0) <> 0 THEN
			CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlCode);
			CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlErrM);

			 -- RAISE NOTICE '戻り値が２の場合は0にする terminated 1: %', l_OutSqlErrM;

			extra_param := l_OutSqlCode;
			RETURN;
		END IF;

		-- 請求書の場合
        IF l_inseikyushoid = pkipakknido.c_seikyu() THEN
        	-- 帳票ワークテーブルの手数料額合計、消費税額合計を更新する。
            SELECT *
            INTO
				l_OutSqlCode, 			-- リターン値
				l_OutSqlErrM			-- エラーコメント
			FROM pkipakknido.updategnrseikyusho(
				l_inItakuKaishaCd, 		-- 委託会社コード
				l_inUserId, 				-- ユーザーID
				l_inrealbatchkbn, 		-- 帳票区分
				l_ingyomuymd, 			-- 業務日付
				pkipakknido.c_seikyu(), -- 請求書帳票ID
				pkipakknido.c_ryoshu()  -- 領収書帳票ID
			);
		END IF;

            -- 戻り値が２の場合は0にする
            IF coalesce(l_OutSqlCode,0) = 2 THEN
                -- ２：帳票データなしだけど、正常終了
                l_OutSqlCode := 0;

            END IF;

            -- 戻り値チェック(エラーの場合はすぐに戻る)
    		IF coalesce(l_OutSqlCode,0) <> 0 THEN
	   		CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlCode);
			CALL pkLog.error('ECM701', 'PKIPAKNIDO', 'エラーメッセージ：'||l_OutSqlErrM);

			 -- RAISE NOTICE '戻り値チェック(エラーの場合はすぐに戻る) terminate: %', l_OutSqlErrM;

			extra_param := pReturnCode;
			RETURN;
		END IF;

        -- 作票処理（子SPで）が終了したため、帳票WKの仮データDELETE
        IF l_inRealBatchKbn = '1' then
            DELETE FROM SREPORT_WK
            WHERE CHOHYO_ID = WK_GNR_TESU_ID;
        END IF;

    extra_param := PKCONSTANT.SUCCESS();

     -- RAISE NOTICE 'end of insKikinIdoSeikyuOut';

    RETURN;

    -- エラー処理
    EXCEPTION
	WHEN	OTHERS	THEN
        l_OutSqlCode := 99;  -- PostgreSQL: Use numeric error code instead of SQLSTATE
        l_OutSqlErrM := 'SQLSTATE: ' || SQLSTATE || ' - ' || SQLERRM;
		CALL pkLog.fatal('ECM701', 'PKIPAKKNIDO', 'SQLSTATE:'||SQLSTATE);
		CALL pkLog.fatal('ECM701', 'PKIPAKKNIDO', 'SQLERRM:'||l_OutSqlErrM);
		 -- RAISE NOTICE 'ERR: %', SQLERRM;

		-- IF pCur IS NOT NULL THEN
		-- 	CLOSE pCur;
		-- END IF;

        extra_param := PKCONSTANT.FATAL();

        RETURN;

	END;

$body$
LANGUAGE PLPGSQL
SECURITY DEFINER
;