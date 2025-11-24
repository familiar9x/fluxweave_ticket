


DROP TYPE IF EXISTS spip07101_01_type_record;
CREATE TYPE spip07101_01_type_record AS (
		gJtkKbn					VMGR_LIST.JTK_KBN%TYPE 					-- 受託区分
		,gJtkKbnNm				VMGR_LIST.JTK_KBN_NM%TYPE 				-- 受託区分名称
		,gIsinCd				VMGR_LIST.ISIN_CD%TYPE 					-- ＩＳＩＮコード
		,gMgrCd					varchar(13)					-- 銘柄コード
		,gMgrRnm				VMGR_LIST.MGR_RNM%TYPE 					-- 銘柄略称
		,gHktCd					VMGR_LIST.HKT_CD%TYPE 					-- 発行体コード
		,gSaikenShuruiNm		varchar(20)						-- 債権種類名称
		,gKkKanyoFlgNm			varchar(20)						-- 機構関与方式採用フラグ名称
		,gShokanMethodNm		VMGR_LIST.SHOKAN_METHOD_NM%TYPE 			-- 償還方法名称
		,gTeijiShokanTsutiKbn	VMGR_LIST.TEIJI_SHOKAN_TSUTI_KBN%TYPE 	-- 定時償還期中通知区分
		,gFactor1				decimal(11,10)					-- ファクター(前)
		,gFactor2				decimal(11,10)					-- ファクター(後)
		,gCallallUmuFlg			VMGR_LIST.CALLALL_UMU_FLG%TYPE 			-- コールオプション有無フラグ（全額償還）
		,gCallitibuUmuFlg		VMGR_LIST.CALLITIBU_UMU_FLG%TYPE 		-- コールオプション有無フラグ（一部償還）
		,gPutumuFlg				VMGR_LIST.PUTUMU_FLG%TYPE 				-- プットオプション有無フラグ
		,gPutumuFlgNm			VMGR_LIST.PUTUMU_FLG_NM%TYPE 			-- プットオプション有無フラグ名称
		,gShokanYmd				char(8)				-- 償還年月日
		,gShokanKjt				char(8)				-- 償還期日
		,gJiyuuNm				varchar(40)						-- 事由名称
		,gHakkoTsukaNm			char(3)					-- 発行通貨名称
		,gHakkoTsukaCd			char(3)					-- 発行通貨コード
		,gGensaiKngk			numeric(14)								-- 減債額
		,gGensaiSum				numeric(14)								-- 減債後合計
		,gKaiji					numeric(3)					-- 回次
		,gBankRnm				VJIKO_ITAKU.BANK_RNM%TYPE 				-- 銀行略称
		,gJikoDaikoKbn			VJIKO_ITAKU.JIKO_DAIKO_KBN%TYPE 			-- 自行代行区分
		,gShokanKbn				char(2)				-- 償還区分
		,gItakuKaishaCd			char(4)			-- 委託会社コード
		,gShokanMethodCd		VMGR_LIST.SHOKAN_METHOD_CD%TYPE 			-- 償還方法コード
		,gShokanKbnSort			numeric(2)					-- 償還区分 ソート順
	);


CREATE OR REPLACE PROCEDURE spip07101_01 ( l_inGnrBaraiKjtF CHAR,		-- 元利払期日(FROM)
 l_inGnrBaraiKjtT CHAR,		-- 元利払期日(TO)
 l_inHktCd CHAR,		-- 発行体コード
 l_inKozaTenCd CHAR,		-- 口座店コード
 l_inKozaTenCifCd CHAR,		-- 口座店CIFコード
 l_inMgrCd CHAR,		-- 銘柄コード
 l_inIsinCd CHAR,		-- ISINコード
 l_inJtkKbn CHAR,		-- 受託区分
 l_inSaikenShurui CHAR,		-- 債券種類
 l_inKkKanyoFlg CHAR,		-- 機構関与方式採用フラグ
 l_inShokanMethodCd CHAR,		-- 償還方法
 l_inTeijiShokanTsutiKbn CHAR,		-- 定時償還通知区分
 l_inJiyuu CHAR,		-- 事由
 l_inItakuKaishaCd CHAR,		-- 委託会社コード
 l_inUserId CHAR,		-- ユーザーID
 l_inChohyoKbn CHAR,		-- 帳票区分
 l_inGyomuYmd CHAR,		-- 業務日付
 l_outSqlCode OUT numeric,		-- リターン値
 l_outSqlErrM OUT text	-- エラーコメント
 ) AS $body$
DECLARE

--
-- **** * 著作権:Copyright(c)2004
-- * 会社名:JIP
-- * 概要　:業務帳票出力指示画面の入力条件により、償還予定銘柄一覧表を作成する。
-- * 引数　:l_inGnrBaraiKjtF			IN	CHAR		元利払期日(FROM)
-- * 　　　 l_inGnrBaraiKjtT			IN	CHAR		元利払期日(TO)
-- * 　　　 l_inHktCd					IN	CHAR		発行体コード
-- * 　　　 l_inKozaTenCd				IN	CHAR		口座店コード
-- * 　　　 l_inKozaTenCifCd			IN	CHAR		口座店CIFコード
-- * 　　　 l_inMgrCd					IN	CHAR		銘柄コード
-- * 　　　 l_inIsinCd				IN	CHAR		ISINコード
-- * 　　　 l_inJtkKbn				IN	CHAR		受託区分
-- * 　　　 l_inSaikenShurui			IN	CHAR		債券種類
-- * 　　　 l_inKkKanyoFlg			IN	CHAR		機構関与方式採用フラグ
-- * 　　　 l_inShokanMethodCd		IN	CHAR		償還方法
-- * 　　　 l_inTeijiShokanTsutiKbn	IN	CHAR		定時償還通知区分
-- * 　　　 l_inJiyuu					IN	CHAR		事由
-- * 　　　 l_inItakuKaishaCd			IN	CHAR		委託会社コード
-- * 　　　 l_inUserId				IN	CHAR		ユーザーID
-- * 　　　 l_inChohyoKbn				IN	CHAR		帳票区分
-- * 　　　 l_inGyomuYmd				IN	CHAR		業務日付
-- * 　　　 l_outSqlCode				OUT	INTEGER		リターン値
-- * 　　　 l_outSqlErrM				OUT	VARCHAR2	エラーコメント
-- * 返り値:なし
-- * @version $Id: SPIP07101_01.SQL,v 1.24 2008/10/04 08:12:13 fujimoto Exp $
-- *
-- ***************************************************************************
-- * ログ　:
-- * 　　　日付	開発者名		目的
-- * -------------------------------------------------------------------
-- *　2005.05.25	JIP	川田愛		元利払期日FROMとTOが入力されていなくても
-- *					帳票が出力されるように訂正
-- *
-- ***********************************************************************
--
--==============================================================================
--					デバッグ機能													
--==============================================================================
	DEBUG	numeric(1)	:= 0;
--==============================================================================
--					定数定義													
--==============================================================================
	RTN_OK				CONSTANT integer		:= 0;				-- 正常
	RTN_NG				CONSTANT integer		:= 1;				-- 予期したエラー
	RTN_NODATA			CONSTANT integer		:= 2;				-- データなし
	RTN_FATAL			CONSTANT integer		:= 99;				-- 予期せぬエラー
	REPORT_ID			CONSTANT char(11)		:= 'IP030007111';	-- 帳票ID
	-- 書式フォーマット
	FMT_HAKKO_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 発行金額
	FMT_RBR_KNGK_J		CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 利払金額
	FMT_SHOKAN_KNGK_J	CONSTANT char(18)	:= 'ZZ,ZZZ,ZZZ,ZZZ,ZZ9';	-- 償還金額
	-- 償還区分
	KAIIRE				CONSTANT varchar(2) := '30';					-- 買入消却
	PUT					CONSTANT varchar(2) := '50';					-- プットオプション
	-- 償還方法
	TEIJI				CONSTANT varchar(1) := '2';					-- 定時償還
	-- 処理区分
	SHONIN				CONSTANT varchar(1) := '1';					-- 承認済
--==============================================================================
--					変数定義													
--==============================================================================
	gRtnCd				integer :=	RTN_OK;						-- リターンコード
	gSeqNo				integer := 0;							-- シーケンス
	gRet				numeric  := 0;							-- 戻り値格納用変数
	gSQL				varchar(5000) := NULL;				-- SQL編集
	-- DB取得項目
	recMeisai spIp07101_01_TYPE_RECORD;						-- レコード
	gJtkKbnNm					SCODE.CODE_NM%TYPE;					-- 受託区分名
	gTeijiShokanTsutiKbnNm		char(4) := NULL;				-- 定時償還期中通知区分名
	gCallUmuFlgNm				char(10) := NULL;				-- コールオプション有無フラグ名称
	gItakuKaishaRnm				VJIKO_ITAKU.BANK_RNM%TYPE;			-- 委託会社略称
   	gNyuryokuYmd				UPD_MGR_SHN.SHR_KJT%TYPE;   		-- 入力日（期中銘柄情報変更（償還） 最終訂正日時)
   	gMasshoYmd					GENSAI_RIREKI.MASSHO_YMD%TYPE;		-- 抹消日
	gLastShokanFlg				integer := 0;					-- 最終償還有無フラグ
	-- カーソル
	TYPE spIp07101_01_CURSOR_TYPE 					-- 最終償還有無フラグ
	-- カーソル
	TYPE CURSOR_TYPE REFCURSOR;
	curMeisai spIp07101_01_CURSOR_TYPE
--==============================================================================
--	メイン処理	
--==============================================================================
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp07101_01 START');	END IF;
	-- 入力パラメータのチェック（委託会社コード、ユーザID、帳票区分、業務日付）
	IF coalesce(l_inItakuKaishaCd::text, '') = ''
	OR coalesce(l_inUserId::text, '') = ''
	OR coalesce(l_inChohyoKbn::text, '') = ''
	OR coalesce(l_inGyomuYmd::text, '') = ''
	THEN
		-- パラメータエラー
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'param error');	END IF;
		l_outSqlCode := RTN_NG;
		l_outSqlErrM := '';
		CALL pkLog.error('ECM501', REPORT_ID, 'SQLERRM:'||'');
		RETURN;
	END IF;
	-- 帳票ワークの削除
	DELETE FROM SREPORT_WK
	WHERE	KEY_CD = l_inItakuKaishaCd
	AND		USER_ID = l_inUserId
	AND		CHOHYO_KBN = l_inChohyoKbn
	AND		SAKUSEI_YMD = l_inGyomuYmd
	AND		CHOHYO_ID = REPORT_ID;
	-- 入力受託区分名を取得
--	getJtkKbnNm();
	-- SQL編集
	CALL spIp07101_01_createSQL();
	-- ヘッダレコードを追加
	CALL pkPrint.insertHeader(l_inItakuKaishaCd, l_inUserId, l_inChohyoKbn, l_inGyomuYmd, REPORT_ID);
	-- カーソルオープン
	OPEN curMeisai FOR EXECUTE gSQL;
	-- データ取得
	LOOP
		FETCH curMeisai INTO	recMeisai.gJtkKbn 					-- 受託区分
								,recMeisai.gJtkKbnNm 				-- 受託区分名称
								,recMeisai.gIsinCd 					-- ＩＳＩＮコード
								,recMeisai.gMgrCd 					-- 銘柄コード
								,recMeisai.gMgrRnm 					-- 銘柄略称
								,recMeisai.gHktCd 					-- 発行体コード
								,recMeisai.gSaikenShuruiNm 			-- 債権種類略称
								,recMeisai.gKkKanyoFlgNm 			-- 機構関与方式採用フラグ略称
								,recMeisai.gShokanMethodNm 			-- 償還方法名称
								,recMeisai.gTeijiShokanTsutiKbn 		-- 定時償還期中通知区分
								,recMeisai.gFactor2					-- ファクター(後)
								,recMeisai.gCallallUmuFlg 			-- コールオプション有無フラグ（全額償還）
								,recMeisai.gCallitibuUmuFlg 			-- コールオプション有無フラグ（一部償還）
								,recMeisai.gPutumuFlg 				-- プットオプション有無フラグ
								,recMeisai.gPutumuFlgNm 				-- プットオプション有無フラグ名称
								,recMeisai.gShokanYmd 				-- 償還年月日
								,recMeisai.gShokanKjt 				-- 償還期日
								,recMeisai.gJiyuuNm 					-- 事由名称
								,recMeisai.gHakkoTsukaNm 			-- 発行通貨名称
								,recMeisai.gHakkoTsukaCd 			-- 発行通貨コード
								,recMeisai.gGensaiKngk 				-- 減債額
								,recMeisai.gGensaiSum 				-- 減債後合計
								,recMeisai.gKaiji 					-- 回次
								,recMeisai.gBankRnm 					-- 銀行略称
								,recMeisai.gJikoDaikoKbn 			-- 自行代行区分
								,recMeisai.gShokanKbn 			    -- 償還区分
								,recMeisai.gItakuKaishaCd 			-- 委託会社コード
								,recMeisai.gShokanMethodCd 			-- 償還方法コード
								,recMeisai.gShokanKbnSort 			-- 償還区分 ソート順
								;
		EXIT WHEN NOT FOUND;/* apply on curMeisai */
		gSeqNo := gSeqNo + 1;
		-- 定時償還の時のみ、ファクターを出力。（定時償還以外はスペース）
		IF recMeisai.gShokanMethodCd = TEIJI THEN
			-- 前回償還回次レコードの検索(ファクター(前)の取得)
			CALL spIp07101_01_getFactor(recMeisai.gMgrCd, l_inItakuKaishaCd, recMeisai.gShokanYmd, recMeisai.gShokanKbn);
		ELSE
			recMeisai.gFactor1 := NULL;
			recMeisai.gFactor2 := NULL;
		END IF;
		-- 定時償還期中通知区分名
		CASE recMeisai.gTeijiShokanTsutiKbn
			WHEN 'V' THEN	gTeijiShokanTsutiKbnNm := 'する';
			ELSE			gTeijiShokanTsutiKbnNm := '−'; --全角マイナス
		END CASE;
		-- コールオプション有無フラグ名称
		CASE 'Y'
			WHEN recMeisai.gCallallUmuFlg THEN
				IF recMeisai.gCallitibuUmuFlg = 'Y' THEN
					gCallUmuFlgNm := '全額・一部';
				ELSE
					gCallUmuFlgNm := '全額';
				END IF;
			WHEN recMeisai.gCallitibuUmuFlg THEN	gCallUmuFlgNm := '一部';
			ELSE									gCallUmuFlgNm := 'なし';
		END CASE;
		-- 入力日
		gNyuryokuYmd := spIp07101_01_getNyuryokuYmd(recMeisai.gItakuKaishaCd,recMeisai.gMgrCd,recMeisai.gShokanKjt,recMeisai.gShokanKbn);
		IF recMeisai.gShokanKbn = '20' THEN
			gNyuryokuYmd := '−';
		END IF;
		IF recMeisai.gShokanKbn = '21' AND recMeisai.gKaiji = '1' AND trim(both recMeisai.gGensaiKngk) != 0 THEN
			-- 入力日(訂正)が入っていないとき
			IF coalesce(trim(both gNyuryokuYmd)::text, '') = '' THEN
				gNyuryokuYmd := '−';
			END IF;
		END IF;
		IF recMeisai.gShokanKbn = '60' THEN
			gNyuryokuYmd := '−';
		END IF;
		IF spIp07101_01_checkLastMgrShokij(l_inItakuKaishaCd, recMeisai.gMgrCd, recMeisai.gShokanYmd, recMeisai.gShokanKbnSort) = 0 THEN
			IF coalesce(trim(both gNyuryokuYmd)::text, '') = '' THEN
				gNyuryokuYmd := '−';
			END IF;
		END IF;
		-- 抹消日
		-- プットオプション・買入消却の場合は、ブランクを表示
		IF recMeisai.gShokanKbn = '50' OR recMeisai.gShokanKbn = '30'THEN
				gMasshoYmd := ' ';
		ELSE
				gMasshoYmd := '−';
		END IF;
		IF recMeisai.gShokanKbn = '50' OR recMeisai.gShokanKbn = '30'THEN
			 gMasshoYmd := spIp07101_01_getMasshoYmd(recMeisai.gItakuKaishaCd,recMeisai.gMgrCd,recMeisai.gShokanYmd,recMeisai.gShokanKbn);
		ELSIF recMeisai.gShokanKbn = '60' THEN
				gMasshoYmd := '−';
		ELSE
			IF spIp07101_01_checkLastMgrShokij(l_inItakuKaishaCd, recMeisai.gMgrCd, recMeisai.gShokanYmd, recMeisai.gShokanKbnSort) = 0 THEN
				gMasshoYmd := spIp07101_01_getMasshoYmd(recMeisai.gItakuKaishaCd,recMeisai.gMgrCd,recMeisai.gShokanYmd,recMeisai.gShokanKbn);
			END IF;	
		END IF;
		-- 委託会社略称
		gItakuKaishaRnm := NULL;
		IF recMeisai.gJikoDaikoKbn = '2' THEN
			gItakuKaishaRnm := recMeisai.gBankRnm;
		END IF;
		-- 帳票ワークへデータを追加
		CALL pkPrint.insertData(
			l_inKeyCd			=>	l_inItakuKaishaCd 					-- 識別コード
			,l_inUserId			=>	l_inUserId 							-- ユーザＩＤ
			,l_inChohyoKbn		=>	l_inChohyoKbn 						-- 帳票区分
			,l_inSakuseiYmd		=>	l_inGyomuYmd 						-- 作成年月日
			,l_inChohyoId		=>	REPORT_ID 							-- 帳票ＩＤ
			,l_inSeqNo			=>	gSeqNo 								-- 連番
			,l_inHeaderFlg		=>	'1'									-- ヘッダフラグ
			,l_inItem001		=>	l_inUserId 							-- ユーザＩＤ
			,l_inItem002		=>	l_inGnrBaraiKjtF 					-- 入力元利払期日(FROM)
			,l_inItem003		=>	l_inGnrBaraiKjtT 					-- 入力元利払期日(TO)
--			,l_inItem004		=>	gJtkKbnNm							-- 受託区分名称
			,l_inItem004		=>	recMeisai.gJtkKbnNm 					-- 受託区分名称
			,l_inItem005		=>	gSeqNo 								-- ＮＯ（1からの通し番号）
			,l_inItem006		=>	recMeisai.gIsinCd 					-- ＩＳＩＮコード
			,l_inItem007		=>	recMeisai.gMgrCd 					-- 銘柄コード
			,l_inItem008		=>	recMeisai.gMgrRnm 					-- 銘柄略称
			,l_inItem009		=>	recMeisai.gHktCd 					-- 発行体コード
			,l_inItem010		=>	recMeisai.gSaikenShuruiNm 			-- 債権種類略称
			,l_inItem011		=>	recMeisai.gKkKanyoFlgNm 				-- 機構関与方式採用フラグ略称
			,l_inItem012		=>	recMeisai.gShokanMethodNm 			-- 償還方法名称
			,l_inItem013		=>	gTeijiShokanTsutiKbnNm 				-- 定時償還期中通知区分名称
			,l_inItem014		=>	TO_CHAR(recMeisai.gFactor1, '0.0000000000')		-- ファクター(前)
			,l_inItem015		=>	TO_CHAR(recMeisai.gFactor2, '0.0000000000')		-- ファクター(後)
			,l_inItem016		=>	gCallUmuFlgNm 						-- コールオプション有無フラグ名称
			,l_inItem017		=>	recMeisai.gPutumuFlgNm 				-- プットオプション有無フラグ名称
			,l_inItem018		=>	recMeisai.gShokanYmd 				-- 償還年月日
			,l_inItem019		=>	recMeisai.gJiyuuNm 					-- 事由名称
			,l_inItem020		=>	recMeisai.gGensaiKngk 				-- 減債額
			,l_inItem021		=>	recMeisai.gHakkoTsukaNm 				-- 発行通貨名称
			,l_inItem022		=>	recMeisai.gGensaiSum 				-- 減債後合計
			,l_inItem023		=>	recMeisai.gHakkoTsukaNm 				-- 発行通貨名称
			,l_inItem024		=>	gItakuKaishaRnm 						-- 委託会社略称
			,l_inItem025		=>	REPORT_ID 							-- 帳票ＩＤ
			,l_inItem026		=>	FMT_HAKKO_KNGK_J 					-- 発行金額書式フォーマット
			,l_inItem027		=>	FMT_RBR_KNGK_J 						-- 利払金額書式フォーマット
			,l_inItem028		=>	FMT_SHOKAN_KNGK_J 					-- 償還金額書式フォーマット
			,l_inItem031		=>	gMasshoYmd 							-- 抹消日
			,l_inItem032		=>	gNyuryokuYmd 						-- 入力日
			,l_inKousinId		=>	l_inUserId 							-- 更新者ID
			,l_inSakuseiId		=>	l_inUserId 							-- 作成者ID
			,l_inItem030		=>	recMeisai.gJtkKbn 					-- 受託区分
			,l_inItem033		=>	recMeisai.gShokanKbnSort 			-- 償還区分ソート順
			,l_inItem034		=>	recMeisai.gShokanKjt 				-- 償還期日
		);
	END LOOP;
	CLOSE curMeisai;
	IF gSeqNo = 0 THEN
	-- 対象データなし
		gRtnCd := RTN_NODATA;
		-- データ無し帳票出力
		gRet := PKIPACALCTESURYO.setNoDataPrint(l_inItakuKaishaCd,	-- 委託会社コード
												l_inUserId,			-- ユーザID
												l_inGyomuYmd,		-- 業務日付
												REPORT_ID,			-- 帳票ID
												l_inChohyoKbn,		-- 帳票区分
												29,					-- 対象データなし の出力位置
												l_inGnrBaraiKjtF,	-- セットするアイテムその１
												2,					-- セットするアイテムその１のItem番号
												l_inGnrBaraiKjtT,	-- セットするアイテムその２
												3,					-- セットするアイテムその２のItem番号
												REPORT_ID,			-- セットするアイテムその３
												25,					-- セットするアイテムその３のItem番号
												l_inUserId,			-- 徴求年月　セットするアイテムその４
												1,					-- セットするアイテムその４のItem番号
												'',					-- セットするアイテムその５
												0					-- セットするアイテムその５のItem番号
												);
		-- 帳票が正しく出力されたかどうか確認
		IF gRet <> pkconstant.success() THEN
			IF DEBUG = 1 THEN CALL PkLog.debug(l_inUserId, REPORT_ID, '対象データ無し用のデータの出力が失敗。' );END IF;
			-- エラーの場合はエラーログを出力し、エラーで返す
			CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLCODE:'||SQLSTATE);
			CALL pkLog.fatal(l_inUserId, REPORT_ID, 'SQLERRM:'||SQLERRM);
			-- Out引数にエラー内容を設定
			l_outSqlCode := pkconstant.FATAL();
			l_outSqlErrM := SQLERRM;
			RETURN;
		END IF;
	END IF;
	-- 終了処理
	l_outSqlCode := gRtnCd;
	l_outSqlErrM := '';
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ROWCOUNT:'||gSeqNo);	END IF;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'spIp07101_01 END');	END IF;
-- エラー処理
EXCEPTION
	WHEN	OTHERS	THEN
		IF curMeisai%ISOPEN THEN
			CLOSE curMeisai;
		END IF;
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLCODE:'||SQLSTATE);
		CALL pkLog.fatal('ECM701', REPORT_ID, 'SQLERRM:'||SQLERRM);
		l_outSqlCode := RTN_FATAL;
		l_outSqlErrM := SQLERRM;
--		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip07101_01 ( l_inGnrBaraiKjtF CHAR, l_inGnrBaraiKjtT CHAR, l_inHktCd CHAR, l_inKozaTenCd CHAR, l_inKozaTenCifCd CHAR, l_inMgrCd CHAR, l_inIsinCd CHAR, l_inJtkKbn CHAR, l_inSaikenShurui CHAR, l_inKkKanyoFlg CHAR, l_inShokanMethodCd CHAR, l_inTeijiShokanTsutiKbn CHAR, l_inJiyuu CHAR, l_inItakuKaishaCd CHAR, l_inUserId CHAR, l_inChohyoKbn CHAR, l_inGyomuYmd CHAR, l_outSqlCode OUT numeric, l_outSqlErrM OUT text ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spip07101_01_checklastmgrshokij ( l_inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE,	-- 委託会社コード
 gMgrCd MGR_SHOKIJ.MGR_CD%TYPE,			-- 銘柄コード
 gShokanYmd MGR_SHOKIJ.SHOKAN_YMD%TYPE,		-- 償還日
 gShokanKbnSort SCODE.CODE_SORT%TYPE 				-- 償還区分ソート順
 ) RETURNS integer AS $body$
BEGIN
    	--対象銘柄が"最後の償還"かの判定
        SELECT
		CASE WHEN MAX(SHOKAN_YMD || LPAD(CODE_SORT, 2, 0))=(gShokanYmd || LPAD(gShokanKbnSort, 2, 0)) THEN  0  ELSE 1 END 
	INTO STRICT gLastShokanFlg
	FROM MGR_SHOKIJ, SCODE
	WHERE
		MGR_SHOKIJ.SHOKAN_KBN = SCODE.CODE_VALUE
	AND SCODE.CODE_SHUBETSU = '714'
	AND ITAKU_KAISHA_CD = l_inItakuKaishaCd
	AND MGR_CD = gMgrCd;	
	RETURN gLastShokanFlg;
    EXCEPTION
        WHEN OTHERS THEN
        	CALL pkLog.fatal(l_inUserId, '', SQLSTATE||SUBSTR(SQLERRM,1,100));
            CALL pkLog.DEBUG(l_inUserId, 'spIp07101_01','償還予定銘柄一覧表作成_最終償還判定エラー');
            RAISE;
    END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spip07101_01_checklastmgrshokij ( l_inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE, gMgrCd MGR_SHOKIJ.MGR_CD%TYPE, gShokanYmd MGR_SHOKIJ.SHOKAN_YMD%TYPE, gShokanKbnSort SCODE.CODE_SORT%TYPE  ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spip07101_01_createsql () AS $body$
BEGIN
	gSQL := '';
	gSQL := gSQL || 'SELECT	VMG1.JTK_KBN,'														-- 受託区分
				 || '		MCD4.CODE_RNM AS JTK_KBN_NM,'										-- 受託区分名称
				 || '		VMG1.ISIN_CD,'														-- ＩＳＩＮコード
				 || '		VMG1.MGR_CD,'														-- 銘柄コード
				 || '		VMG1.MGR_RNM,'														-- 銘柄略称
				 || '		VMG1.HKT_CD,'														-- 発行体コード
				 || '		MCD1.CODE_RNM AS SAIKEN_SHURUI_NM,'									-- 債権種類略称
				 || '		MCD2.CODE_RNM AS KK_KANYO_FLG_NM,'									-- 機構関与方式採用フラグ略称
				 || '		VMG1.SHOKAN_METHOD_NM,'												-- 償還方法名称
				 || '		VMG1.TEIJI_SHOKAN_TSUTI_KBN,'										-- 定時償還期中通知区分
				 || '		MG3.FACTOR,'														-- ファクター
				 || '		VMG1.CALLALL_UMU_FLG,'												-- コールオプション有無フラグ（全額償還）
				 || '		VMG1.CALLITIBU_UMU_FLG,'											-- コールオプション有無フラグ（一部償還）
				 || '		VMG1.PUTUMU_FLG,'													-- プットオプション有無フラグ
				 || '		VMG1.PUTUMU_FLG_NM,'												-- プットオプション有無フラグ名称
				 || '		MG3.SHOKAN_YMD,'													-- 償還年月日
				 || '		MG3.SHOKAN_KJT,'													-- 償還期日
				 || '		MCD3.CODE_NM AS JIYUU_NM,'											-- 事由名称
				 || '		M64.TSUKA_NM AS HAKKO_TSUKA_NM,'									-- 発行通貨名称
				 || '		VMG1.HAKKO_TSUKA_CD,'												-- 発行通貨コード
				 || '		MG3.MUNIT_GENSAI_KNGK,'												-- 減債額
				 || '		PkIpaZndk.getKjnZndk(VMG1.ITAKU_KAISHA_CD,VMG1.MGR_CD,MG3.SHOKAN_YMD,MG3.SHOKAN_KBN,''13''),'	-- 今回を含んだ実質残高
				 || '		MG3.KAIJI,'															-- 回次
				 || '		VJ1.BANK_RNM,'														-- 銀行略称
				 || '		VJ1.JIKO_DAIKO_KBN, '												-- 自行代行区分
				 || '		MG3.SHOKAN_KBN, '												    -- 償還区分
				 || '		MG3.ITAKU_KAISHA_CD, '											    -- 委託会社コード
				 || '		VMG1.SHOKAN_METHOD_CD, '											-- 償還方法コード
				 || '		SC04.CODE_SORT AS SHOKAN_KBN_SORT '									-- 償還区分 ソート順（コードマスタ）
				 || 'FROM 	MGR_SHOKIJ MG3,'													-- 銘柄_償還回次VIEW
				 || '		VMGR_LIST VMG1,'													-- 銘柄情報一覧VIEW
				 || '		MGR_KIHON_VIEW VMG0,'												-- 銘柄 基本VIEW
				 || '		SCODE MCD1,'														-- コードマスタ
				 || '		SCODE MCD2,'														-- コードマスタ
				 || '		SCODE MCD3,'														-- コードマスタ
				 || '		SCODE MCD4,'														-- コードマスタ
				 || '		VJIKO_ITAKU VJ1,'			 										-- 自行・委託会社VIEW
				 || '		MTSUKA M64, '														-- 通貨マスタ
				 || '		SCODE SC04 '														-- コードマスタ（償還区分）
				 || 'WHERE 	MG3.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' '
				 || 'AND 	MG3.SHOKAN_KJT >= ''' || l_inGnrBaraiKjtF || ''' '
				 || 'AND 	MG3.SHOKAN_KJT <= ''' || l_inGnrBaraiKjtT || ''' '
				 || 'AND 	VMG1.ITAKU_KAISHA_CD = MG3.ITAKU_KAISHA_CD '
				 || 'AND 	VMG1.MGR_CD = MG3.MGR_CD '
				 || 'AND 	VMG1.MGR_STAT_KBN = ''1'' '
				 || 'AND 	TRIM(VMG1.ISIN_CD) IS NOT NULL '
				 || 'AND 	VMG1.ITAKU_KAISHA_CD = VMG0.ITAKU_KAISHA_CD '
				 || 'AND 	VMG1.MGR_CD = VMG0.MGR_CD '
				 || 'AND 	VMG1.HAKKO_TSUKA_CD = M64.TSUKA_CD '
				 || 'AND 	VJ1.KAIIN_ID = ''' || l_inItakuKaishaCd || ''' '
				 || 'AND 	MCD1.CODE_SHUBETSU(+) = ''514'' '
				 || 'AND 	VMG1.SAIKEN_SHURUI = TRIM(MCD1.CODE_VALUE(+)) '
				 || 'AND 	MCD2.CODE_SHUBETSU(+) = ''505'' '
				 || 'AND 	MG3.KK_KANYO_FLG = MCD2.CODE_VALUE(+) '
				 || 'AND 	MCD3.CODE_SHUBETSU(+) = ''109'' '
				 || 'AND 	MG3.SHOKAN_KBN = TRIM(MCD3.CODE_VALUE(+)) '
				 || 'AND 	MCD4.CODE_SHUBETSU(+) = ''112'' '
				 || 'AND 	VMG1.JTK_KBN = MCD4.CODE_VALUE(+) '
				 || 'AND 	SC04.CODE_SHUBETSU(+) = ''714'' '
				 || 'AND 	MG3.SHOKAN_KBN = TRIM(SC04.CODE_VALUE(+)) ';
				 -- IP-4067対応　事由が指定されていたときにSHOKAN_KBN_SORTが取得されていなかったため、TRIM追加
				 -- （ソートはcheckLastMgrShokijにて使用）
				 -- ※「'21' 」などの(シングルクォートつきでの）値が結合の際に用いられるため。
	IF (l_inHktCd IS NOT NULL AND l_inHktCd::text <> '') THEN
		gSQL := gSQL || 'AND 	VMG1.HKT_CD = ''' || l_inHktCd || ''' ';
	END IF;
	IF (l_inKozaTenCd IS NOT NULL AND l_inKozaTenCd::text <> '') THEN
		gSQL := gSQL || 'AND 	VMG1.KOZA_TEN_CD = ''' || l_inKozaTenCd || ''' ';
	END IF;
	IF (l_inKozaTenCifCd IS NOT NULL AND l_inKozaTenCifCd::text <> '') THEN
		gSQL := gSQL || 'AND 	VMG1.KOZA_TEN_CIFCD = ''' || l_inKozaTenCifCd || ''' ';
	END IF;
	IF (l_inMgrCd IS NOT NULL AND l_inMgrCd::text <> '') THEN
		gSQL := gSQL || 'AND 	VMG1.MGR_CD = ''' || l_inMgrCd || ''' ';
	END IF;
	IF (l_inIsinCd IS NOT NULL AND l_inIsinCd::text <> '') THEN
		gSQL := gSQL || 'AND 	VMG1.ISIN_CD = ''' || l_inIsinCd || ''' ';
	END IF;
	IF (l_inJtkKbn IS NOT NULL AND l_inJtkKbn::text <> '') THEN
		gSQL := gSQL || 'AND 	VMG1.JTK_KBN = ''' || l_inJtkKbn || ''' ';
	END IF;
	IF (l_inSaikenShurui IS NOT NULL AND l_inSaikenShurui::text <> '') THEN
		gSQL := gSQL || 'AND 	VMG1.SAIKEN_SHURUI = ''' || l_inSaikenShurui || ''' ';
	END IF;
	IF (l_inKkKanyoFlg IS NOT NULL AND l_inKkKanyoFlg::text <> '') THEN
		gSQL := gSQL || 'AND 	VMG1.KK_KANYO_FLG = ''' || l_inKkKanyoFlg || ''' ';
	END IF;
	IF (l_inShokanMethodCd IS NOT NULL AND l_inShokanMethodCd::text <> '') THEN
		gSQL := gSQL || 'AND 	VMG1.SHOKAN_METHOD_CD = ''' || l_inShokanMethodCd || ''' ';
	END IF;
	IF (l_inTeijiShokanTsutiKbn IS NOT NULL AND l_inTeijiShokanTsutiKbn::text <> '') THEN
		gSQL := gSQL || 'AND 	VMG1.TEIJI_SHOKAN_TSUTI_KBN = ''' || l_inTeijiShokanTsutiKbn || ''' ';
	END IF;
	IF (l_inJiyuu IS NOT NULL AND l_inJiyuu::text <> '') THEN
		gSQL := gSQL || 'AND 	MG3.SHOKAN_KBN = ''' || l_inJiyuu || ''' ';
	END IF;
	gSQL := gSQL || 'ORDER BY 	VMG1.JTK_KBN,'
				 || '			VMG1.HKT_CD,'
				 || '			VMG1.ISIN_CD,'
				 || '			VMG1.MGR_CD,'
				 || '			MG3.SHOKAN_YMD, '
				 || '			SC04.CODE_SORT ';
--		TEST_DEBUG_LOG('SPIP0701_01',gSQL);
EXCEPTION
	WHEN	OTHERS	THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip07101_01_createsql () FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spip07101_01_getfactor (l_inMgrCd MGR_SHOKIJ.MGR_CD%TYPE ,l_inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE ,l_inShokanYmd MGR_SHOKIJ.SHOKAN_YMD%TYPE ,l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE) AS $body$
BEGIN
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, '銘柄コード:'||l_inMgrCd);	END IF;
        -- 現在の回次の直前ファクターを取得する 
        recMeisai.gFactor1 := (pkIpaZndk.getKjnZndk(l_inItakuKaishaCd, l_inMgrCd, l_inShokanYmd,l_inShokanKbn,5))::numeric;
	IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ファクター:'||recMeisai.gFactor1);	END IF;
EXCEPTION
	WHEN no_data_found THEN
	-- データなし
		recMeisai.gFactor1 := 1.0000000000;
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, 'ファクター:no data found');	END IF;
	WHEN OTHERS THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip07101_01_getfactor (l_inMgrCd MGR_SHOKIJ.MGR_CD%TYPE ,l_inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE ,l_inShokanYmd MGR_SHOKIJ.SHOKAN_YMD%TYPE ,l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE spip07101_01_getjtkkbnnm () AS $body$
BEGIN
	gJtkKbnNm := NULL;
	IF (l_inJtkKbn IS NOT NULL AND l_inJtkKbn::text <> '') THEN
		SELECT 	MCD1.CODE_NM
		INTO STRICT	gJtkKbnNm
		FROM	SCODE MCD1
		WHERE	MCD1.CODE_VALUE = l_inJtkKbn
		AND		MCD1.CODE_SHUBETSU = '112';
	END IF;
EXCEPTION
	WHEN no_data_found THEN
	-- データなし
		IF DEBUG = 1 THEN	CALL pkLog.debug(l_inUserId, REPORT_ID, '受託区分名:no data found');	END IF;
	WHEN OTHERS THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE spip07101_01_getjtkkbnnm () FROM PUBLIC;





CREATE OR REPLACE FUNCTION spip07101_01_getmasshoymd (l_inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE ,l_inMgrCd MGR_SHOKIJ.MGR_CD%TYPE ,l_inShokanYmd MGR_SHOKIJ.SHOKAN_YMD%TYPE ,l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE) RETURNS varchar AS $body$
DECLARE

        masshoYmd GENSAI_RIREKI.MASSHO_YMD%TYPE;

BEGIN
	masshoYmd := NULL;
        BEGIN
    		SELECT
                Z01.MASSHO_YMD
    		INTO STRICT
                masshoYmd
    		FROM
                GENSAI_RIREKI Z01
            WHERE
        		Z01.ITAKU_KAISHA_CD = l_inItakuKaishaCd  	-- 委託会社コード
    		AND Z01.MGR_CD = l_inMgrCd   					-- 銘柄コード
    		AND Z01.SHOKAN_YMD = l_inShokanYmd   			-- 償還年月日
    		AND Z01.SHOKAN_KBN = l_inShokanKbn;  		    -- 償還区分
    	EXCEPTION
    		WHEN no_data_found THEN
    		    -- 減債履歴にデータがない場合は、NULLをセット
                masshoYmd := NULL;
        END;
        RETURN masshoYmd;
EXCEPTION
	WHEN OTHERS THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spip07101_01_getmasshoymd (l_inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE ,l_inMgrCd MGR_SHOKIJ.MGR_CD%TYPE ,l_inShokanYmd MGR_SHOKIJ.SHOKAN_YMD%TYPE ,l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE) FROM PUBLIC;





CREATE OR REPLACE FUNCTION spip07101_01_getnyuryokuymd (l_inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE ,l_inMgrCd MGR_SHOKIJ.MGR_CD%TYPE ,l_inShokanKjt MGR_SHOKIJ.SHOKAN_YMD%TYPE ,l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE) RETURNS varchar AS $body$
DECLARE

        nyuryokuYmd UPD_MGR_SHN.SHR_KJT%TYPE;

BEGIN
	nyuryokuYmd := NULL;
        BEGIN
    		SELECT
                TO_CHAR(MG23.LAST_TEISEI_DT,'YYYYMMDD')
    		INTO STRICT
                nyuryokuYmd
    		FROM
                UPD_MGR_SHN MG23
            WHERE
        		MG23.ITAKU_KAISHA_CD = l_inItakuKaishaCd  	-- 委託会社コード
    		AND MG23.MGR_CD = l_inMgrCd   					-- 銘柄コード
    		AND MG23.SHR_KJT = l_inShokanKjt         		-- 償還年月日
    		AND MG23.MGR_HENKO_KBN = l_inShokanKbn  	    	-- 償還区分
    		AND MG23.SHORI_KBN = SHONIN; 	    			-- 処理区分 承認済
    	EXCEPTION
    		WHEN no_data_found THEN
    		    -- 期中銘柄情報変更（償還）にデータがない場合は、NULLをセット
                nyuryokuYmd := NULL;
        END;
        RETURN nyuryokuYmd;
EXCEPTION
	WHEN OTHERS THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION spip07101_01_getnyuryokuymd (l_inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE ,l_inMgrCd MGR_SHOKIJ.MGR_CD%TYPE ,l_inShokanKjt MGR_SHOKIJ.SHOKAN_YMD%TYPE ,l_inShokanKbn MGR_SHOKIJ.SHOKAN_KBN%TYPE) FROM PUBLIC;