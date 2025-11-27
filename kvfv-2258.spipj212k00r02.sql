





CREATE OR REPLACE PROCEDURE spipj212k00r02 ( 
    l_inUserId TEXT,		-- ユーザーID
    l_loginBankCd TEXT,		-- 委託会社コード
    l_inGnrBaraiKjtF TEXT,		-- ⑫左 元利払期日(FROM)
    l_inGnrBaraiKjtT TEXT,		-- ⑫右 元利払期日(TO)
    l_inHktCd TEXT,		-- ①   発行体コード
    l_inKozaTenCd TEXT,		-- ②   口座店店番   
    l_inKozaTenCifCd TEXT,		-- ③   口座店ＣIＦコード
    l_inMgrCd TEXT,		-- ④   銘柄コード  
    l_inIsinCd TEXT,		-- ⑤   ＩＳＩＮコード
    l_inJtkKbn TEXT,		-- ⑥   受託区分
    l_inSaikenShurui TEXT,		-- ⑦   債券種類
    l_inKkKanyoFlg TEXT,		-- ⑧   機構関与方式採用フラグ
    l_inShokanMethodCd TEXT,		-- ⑨   償還方法
    l_inTeijiShokanTsutiKbn TEXT,		-- ⑩   定時償還通知区分
    l_inJiyuu TEXT,		-- ⑪   事由
    l_outSqlCode OUT integer,		-- リターン値
    l_outSqlErrM OUT text, 	-- エラーコメント
    l_inItakuKaishaCd TEXT default NULL, -- 委託会社コード
    l_inSdFlg TEXT default NULL, -- ＳＤフラグ
    l_inSaikenDaikoUmu TEXT default NULL -- 債券決済代行利用有無
) AS $body$
DECLARE

-- 概要　:償還予定銘柄一覧表（事務代行横串一括出力）を作成する
--==============================================================================
--					  デバッグ機能												
--==============================================================================
	DEBUG	 numeric(1)	  := 1;
--==============================================================================
--					定数定義													
--==============================================================================
	SP_ID				CONSTANT varchar(20) 	:= 'SPIPJ212K00R02';		-- プロシージャＩＤ
	REPORT_ID			CONSTANT char(11)		:= 'IP030007111';	-- 帳票ID	
	RTN_NODATA			CONSTANT integer		:= 2;				-- データなし
--==============================================================================
--					変数定義													
--==============================================================================
	gSeqNo				integer := 0;							-- シーケンス
	gItakuKaishaRnm 	VJIKO_ITAKU.BANK_RNM%TYPE;				   -- 委託会社略称
	gJikoDaikoKbn		VJIKO_ITAKU.JIKO_DAIKO_KBN%TYPE;			   -- 自行代行区分
	v_item              type_sreport_wk_item;              -- Composite type for pkPrint.insertData
--==============================================================================
--					関数定義													
--==============================================================================
	CUR_DATA CURSOR FOR
	SELECT
		JM01.ITAKU_KAISHA_CD
	FROM
		 MITAKU_KAISHA JM01
		,MITAKU_KAISHA2 BT02
	WHERE
		JM01.SHORI_KBN = '1' --VJIKO_ITAKUの抽出条件
		AND	JM01.DAIKO_FLG = '1'	--事務代行利用ありのユーザーのみを取得（「他金融機関」を除外する）
		AND JM01.ITAKU_KAISHA_CD = BT02.ITAKU_KAISHA_CD
		AND JM01.ITAKU_KAISHA_CD = coalesce(l_inItakuKaishaCd, JM01.ITAKU_KAISHA_CD)
		AND BT02.SD_FLG = coalesce(l_inSdFlg, BT02.SD_FLG)
		AND BT02.SAIKEN_DAIKO_UMU = coalesce(l_inSaikenDaikoUmu, BT02.SAIKEN_DAIKO_UMU)
	;
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	 CALL pkLog.debug(l_inUserId, REPORT_ID, 'SPIPJ212K00R02 START');	END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, REPORT_ID, '入力引数は以下の通りです。');	END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, REPORT_ID, 'ログイン：' || l_loginBankCd);	END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, REPORT_ID, 'ユーザＩＤ：' || l_inUserId);	END IF;
	IF DEBUG = 1 THEN CALL pkLog.debug(l_inUserId, REPORT_ID, '委託会社コード：' || l_inItakuKaishaCd);	END IF;
	-- 戻り値初期化
	l_outSqlCode := pkconstant.success();
	l_outSqlErrM := '';
	-- 入力パラメータのチェック
	IF  coalesce(l_inGnrBaraiKjtF::text, '') = ''
	AND coalesce(l_inGnrBaraiKjtT::text, '') = ''
	THEN
		CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error　項目未設定');
		l_outSqlCode := pkconstant.error();
		l_outSqlErrM := '';
		RETURN;
	END IF;	
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE	USER_ID = l_inUserId
	AND		CHOHYO_KBN = PKIPACALCTESURYO.C_DATA_KBN_YOTEI()
	AND		SAKUSEI_YMD = PKDATE.getGyomuYmd()
	AND		CHOHYO_ID = REPORT_ID;
	FOR rec IN CUR_DATA LOOP
		CALL pkLog.debug(l_inUserId, SP_ID, '委託会社　' || rec.ITAKU_KAISHA_CD);
		gSeqNo := gSeqNo + 1;
		CALL SPIP07101(l_inUserId
			,rec.ITAKU_KAISHA_CD
			,l_inGnrBaraiKjtF
			,l_inGnrBaraiKjtT
			,l_inHktCd
			,l_inKozaTenCd
			,l_inKozaTenCifCd
			,l_inMgrCd
			,l_inIsinCd
			,l_inJtkKbn
			,l_inSaikenShurui
			,l_inKkKanyoFlg
			,l_inShokanMethodCd
			,l_inTeijiShokanTsutiKbn
			,l_inJiyuu
			,l_outSqlCode
			,l_outSqlErrM
		);
	END LOOP;
	IF gSeqNo = 0 THEN
		-- 対象データなし
		gItakuKaishaRnm := NULL;
		SELECT BANK_RNM, JIKO_DAIKO_KBN
		INTO gItakuKaishaRnm, gJikoDaikoKbn 
		FROM VJIKO_ITAKU VJ1
		WHERE  VJ1.KAIIN_ID = l_inItakuKaishaCd;
		IF gJikoDaikoKbn <> '2' THEN
			gItakuKaishaRnm := NULL;
		END IF;
		-- ヘッダレコードを追加
		CALL pkPrint.insertHeader(l_loginBankCd, l_inUserId, PKIPACALCTESURYO.C_DATA_KBN_YOTEI(), PKDATE.getGyomuYmd(), REPORT_ID);
		-- 帳票ワークへデータを追加
		v_item := ROW();
		v_item.l_inItem001 := l_inUserId::varchar;
		v_item.l_inItem002 := l_inGnrBaraiKjtF::varchar;
		v_item.l_inItem003 := l_inGnrBaraiKjtT::varchar;
		v_item.l_inItem025 := REPORT_ID::varchar;
		v_item.l_inItem029 := '対象データなし'::varchar;
		CALL pkPrint.insertData(
			l_inKeyCd      => l_loginBankCd,
			l_inUserId     => l_inUserId,
			l_inChohyoKbn  => PKIPACALCTESURYO.C_DATA_KBN_YOTEI(),
			l_inSakuseiYmd => PKDATE.getGyomuYmd(),
			l_inChohyoId   => REPORT_ID,
			l_inSeqNo      => 1,
			l_inHeaderFlg  => '1',
			l_inItem       => v_item,
			l_inKousinId   => l_inUserId,
			l_inSakuseiId  => l_inUserId
		);
		-- 終了処理
		l_outSqlCode := RTN_NODATA;
		l_outSqlErrM := '';
	END IF;
	CALL pkLog.debug(l_inUserId, SP_ID, 'SPIPJ212K00R02 END  l_outSqlCode = ' || l_outSqlCode);
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', SP_ID, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', SP_ID, 'SQLERRM:' || SQLERRM);
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLERRM;
END;

$body$
LANGUAGE PLPGSQL
;
