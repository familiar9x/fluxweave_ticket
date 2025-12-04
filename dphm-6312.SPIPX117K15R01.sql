




CREATE OR REPLACE PROCEDURE spipx117k15r01 ( l_ReportId text,                       --帳票ID
 l_inItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE, -- 委託会社コード
 l_inItakuKaishaRnm SOWN_INFO.BANK_RNM%TYPE,            -- 委託会社略称
 l_inJikodaikoKbn text,                           -- 自行代行区分
 l_inUserId SUSER.USER_ID%TYPE,                 -- ユーザーID
 l_inChohyoKbn text,                            -- 帳票区分
 l_inGyomuYmd TEXT,                               -- 業務日付
 l_outSqlCode OUT integer,                            -- リターン値
 l_outSqlErrM OUT text                           -- エラーコメント
 ) AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2016
-- * 会社名: JIP
-- *
-- * 警告連絡情報リスト、公社債関連管理リストを作成する。（バッチ用）
-- * １．警告ワーク検索処理
-- * ２．警告連絡情報リスト、公社債関連管理リスト作表処理
-- *
-- * @author Y.Yamada
-- * @version $Id: SFIPKEIKOKUINSERT.sql,v 1.0 2017/02/10 10:19:30 Y.Yamada Exp $
-- *
-- * @param l_ReportId 帳票ID
-- * @param l_inItakuKaishaCd 委託会社コード
-- * @param l_inItakuKaishaRnm 委託会社略称
-- * @param l_inJikodaikoKbn 自行代行区分
-- * @param l_inUserId ユーザーID
-- * @param l_inChohyoKbn 帳票区分
-- * @param l_inGyomuYmd 業務日付
-- * @param l_outSqlCode 銘柄略称
-- * @param l_inTaishoKomoku リターン値
-- * @param l_outSqlErrM エラーコメント
-- 
--==============================================================================
--                変数定義                                                      
--==============================================================================
	v_item type_sreport_wk_item;						-- Composite type for pkPrint.insertData
	gRtnCd integer := pkconstant.success();  	-- リターンコード
	gSeqNo		integer := 0;		-- カウンター
	gTytle varchar(50) := NULL;
	RTN_NODATA CONSTANT integer := 2; -- データなし
--==============================================================================
--                カーソル定義                                                  
--==============================================================================
	curMeisai CURSOR FOR
	SELECT
		CASE l_inJikodaikoKbn WHEN '1' THEN
			SC04.CODE_RNM
			ELSE
				CASE BT08.WARN_INFO_KBN WHEN '1' THEN
					'＊'
					ELSE
						''
					END
			END AS WARN_INFO_NM,
		BT08.WARN_INFO_ID,
		BT08.MESSAGE1,
		BT08.MESSAGE2,
		BT08.ISIN_CD,
		BT08.KOZA_TEN_CD,
		BT08.KOZA_TEN_CIFCD,
		BT08.MGR_RNM,
		BT08.KKMEMBER_CD,
		BT08.TAISHO_KOMOKU,
		BT08.TAISHO_YMD,
		BT08.BIKO1,
		BT08.BIKO2,
		BT08.BIKO3,
		BT08.SORT_KEY
	FROM
		WARNING_WK BT08,
		SCODE SC04
	WHERE
		BT08.ITAKU_KAISHA_CD = l_inItakuKaishaCd
		AND SC04.CODE_SHUBETSU ='B07'
		AND SC04.CODE_VALUE = BT08.WARN_INFO_KBN
	ORDER BY
		BT08.SORT_KEY,
		BT08.TAISHO_YMD,
		BT08.ISIN_CD;
--==============================================================================
--                メイン処理                                                    
--==============================================================================
BEGIN
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_ReportId)::text, '') = '' OR coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' OR
	   coalesce(trim(both l_inUserId)::text, '') = '' OR coalesce(trim(both l_inChohyoKbn)::text, '') = '' OR coalesce(trim(both l_inGyomuYmd)::text, '') = '' THEN
		-- パラメータエラー
		CALL pkLog.fatal('ECM701', l_ReportId, 'パラメータエラー');
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := '';
		RETURN;
	END IF;
	IF l_inJikodaikoKbn = '1' THEN
		gTytle := '警告・連絡情報リスト';
	ELSE
		gTytle := '公社債関連管理リスト';
	END IF;
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
		WHERE KEY_CD =    l_inItakuKaishaCd
		AND USER_ID =     l_inUserId
		AND CHOHYO_KBN =  l_inChohyoKbn
		AND SAKUSEI_YMD = l_inGyomuYmd
		AND CHOHYO_ID =   l_ReportId;
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd,
			     l_inUserId,
			     l_inChohyoKbn,
			     l_inGyomuYmd,
			     l_ReportId);
	-- データ登録処理
	FOR recMeisai IN curMeisai LOOP
		-- シーケンスナンバーをカウントアップしておく
		gSeqNo := gSeqNo + 1;
		-- 帳票ワークへデータを追加
		     		-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem002 := l_inUserId;	-- ユーザID
		v_item.l_inItem003 := gTytle;	-- タイトル
		v_item.l_inItem004 := l_inItakuKaishaCd;	-- 委託会社コード(改ページキー)
		v_item.l_inItem005 := recMeisai.BIKO1;	-- 備考1
		v_item.l_inItem006 := recMeisai.WARN_INFO_NM;	-- 警告連絡名称
		v_item.l_inItem007 := recMeisai.MESSAGE1;	-- 警告連絡メッセージ1
		v_item.l_inItem008 := recMeisai.ISIN_CD;	-- ISINコード
		v_item.l_inItem009 := recMeisai.KOZA_TEN_CIFCD;	-- 口座店CIFコード
		v_item.l_inItem010 := recMeisai.KKMEMBER_CD;	-- 機構加入者コード
		v_item.l_inItem011 := recMeisai.TAISHO_KOMOKU;	-- 対象項目
		v_item.l_inItem012 := recMeisai.KOZA_TEN_CD;	-- 口座店コード
		v_item.l_inItem013 := recMeisai.BIKO2;	-- 備考2
		v_item.l_inItem014 := recMeisai.WARN_INFO_ID;	-- 警告連絡区分
		v_item.l_inItem015 := recMeisai.MESSAGE2;	-- 警告連絡メッセージ2
		v_item.l_inItem016 := recMeisai.MGR_RNM;	-- 銘柄略称
		v_item.l_inItem017 := recMeisai.TAISHO_YMD;	-- 対象期日
		v_item.l_inItem018 := recMeisai.BIKO3;	-- 備考3
		v_item.l_inItem019 := l_ReportId;	-- 帳票ＩＤ
		v_item.l_inItem020 := l_inGyomuYmd;
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> l_ReportId,
			l_inSeqNo		=> gSeqNo,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	END LOOP;
	IF gSeqNo = 0 THEN
		-- 対象データなし
		gRtnCd := RTN_NODATA;
		-- 帳票ワークへ「対象データなし」レコード追加
				-- Clear composite type
		v_item := ROW();
		
		v_item.l_inItem001 := l_inItakuKaishaRnm;	-- 委託会社略称
		v_item.l_inItem002 := l_inUserId;	-- ユーザID
		v_item.l_inItem003 := gTytle;	-- タイトル
		v_item.l_inItem004 := l_inItakuKaishaCd;	-- 委託会社コード(改ページキー)
		v_item.l_inItem007 := '対象データなし';	-- 警告連絡メッセージ1
		v_item.l_inItem019 := l_ReportId;	-- 帳票ＩＤ
		v_item.l_inItem020 := l_inGyomuYmd;
		
		-- Call pkPrint.insertData with composite type
		CALL pkPrint.insertData(
			l_inKeyCd		=> l_inItakuKaishaCd,
			l_inUserId		=> l_inUserId,
			l_inChohyoKbn	=> l_inChohyoKbn,
			l_inSakuseiYmd	=> l_inGyomuYmd,
			l_inChohyoId	=> l_ReportId,
			l_inSeqNo		=> 1,
			l_inHeaderFlg	=> '1',
			l_inItem		=> v_item,
			l_inKousinId	=> l_inUserId,
			l_inSakuseiId	=> l_inUserId
		);
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
		CALL pkLog.fatal('ECM701', l_ReportId, 'SQLCODE:' || SQLSTATE);
		CALL pkLog.fatal('ECM701', l_ReportId, 'SQLERRM:' || SQLERRM);
		l_outSqlCode := pkconstant.FATAL();
		l_outSqlErrM := SQLERRM;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spipx117k15r01 ( l_ReportId text, l_inItakuKaishaCd MITAKU_KAISHA.ITAKU_KAISHA_CD%TYPE, l_inItakuKaishaRnm SOWN_INFO.BANK_RNM%TYPE, l_inJikodaikoKbn text, l_inUserId SUSER.USER_ID%TYPE, l_inChohyoKbn text, l_inGyomuYmd TEXT, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;