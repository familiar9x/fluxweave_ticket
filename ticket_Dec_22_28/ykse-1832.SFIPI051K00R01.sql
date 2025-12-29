


DROP TYPE IF EXISTS sfipi051k00r01_tesuryo_result CASCADE;
CREATE TYPE sfipi051k00r01_tesuryo_result AS (
	result_code			integer,
	gGnknShrTesuBunbo	numeric,
	gGnknShrTesuBunshi	decimal(17,14),
	gSzeiSeikyuKbn		char(1),
	gTesuShuruiCd		char(2)
	);

DROP TYPE IF EXISTS sfipi051k00r01_type_record;
CREATE TYPE sfipi051k00r01_type_record AS (
	gItakuKaishaCd		char(4)			-- 委託会社コード
	,
	gMgrCd				varchar(13)					-- 銘柄コード
	,
	gRbrYmd				char(8)					-- 支払日
	,
	gMunitSknShrKngk	decimal(16,2)		-- 銘柄単位償還支払額
	,
	gSaikenShurui		char(2)			-- 債券種類
	);
DROP TYPE IF EXISTS sfipi051k00r01_type_record_ko;
CREATE TYPE sfipi051k00r01_type_record_ko AS (
	gItakuKaishaCd		char(4)			-- 委託会社コード
	,
	gMgrCd				varchar(13)					-- 銘柄コード
	,
	gJikoTotalHkukKbn	char(1)			-- 自行総額引受区分
	,
	gKkKanyoFlg			char(1)					-- 機構関与方式採用フラグ
	,
	gHakkoTsukaCd		char(3)				-- 発行通貨コード
	,
	gShokanTsukaCd		char(3)				-- 償還通貨コード
	,
	gShokanKjt			char(8)					-- 償還期日
	,
	gShokanYmd			char(8)					-- 償還年月日
	,
	gChokyuYmd			char(8)				-- 手数料徴求日
	,
	gZndkKijunYmd		char(8)				-- 残高基準日
	,
	gGnknShrTesuBunbo	numeric(5)	-- 元金支払手数料分母
	,
	gGnknShrTesuBunshi	decimal(17,14)	-- 元金支払手数料分子
	,
	gGnknShrTesuCap		decimal(14,2)		-- 元金支払手数料ＣＡＰ
	,
	gSzeiSeikyuKbn		char(1)		--消費税請求区分
	,
	gKknNyukinKngk11	numeric 										-- 基金入金額(異動区分11)
	,
	gKknNyukinKngk12	numeric 										-- 基金入金額(異動区分12)
	,
	gKknNyukinKngk13	numeric 										-- 基金入金額(異動区分13)
	,
	gKyujitsuKbn		char(1)			-- 休日区分
	,
	gAreaCd				char(3) 					-- 地域コード
	,
	gTsukarishiKngk		decimal(14,13)				-- 1通貨あたりの利子金額
-- 2006/05 ASK START
	,
	gTesuShuruiCd		char(2)			--手数料種類コード
-- 2006/05 ASK END
	);


CREATE OR REPLACE FUNCTION sfipi051k00r01 (l_inItakuKaishaCd TEXT,	-- 委託会社コード
 l_inUserId TEXT,	-- ユーザーID
 l_inChohyoKbn TEXT,	-- 帳票区分
 l_inGyomuYmd TEXT 		-- 業務日付
 ) RETURNS integer AS $body$
DECLARE

	--
--	/* 著作権:Copyright(c)2004
--	/* 会社名:JIP
--	/* 概要　:元利金支払基金返戻計算処理を行う。
--	/* 引数　:l_inItakuKaishaCd	IN	TEXT		委託会社コード
--	/* 　　　 l_inUserId			IN	TEXT		ユーザーID
--	/* 　　　 l_inChohyoKbn		IN	TEXT		帳票区分
--	/* 　　　 l_inGyomuYmd		IN	TEXT		業務日付
--	/* 　　　 l_outSqlCode		OUT	INTEGER		リターン値
--	/* 　　　 l_outSqlErrM		OUT	VARCHAR	エラーコメント
--	/* 返り値:なし
--	/* @version $Id: SFIPI051K00R01.sql,v 1.22 2015/07/13 02:32:23 hirokawa Exp $
--
--	/*==============================================================================
	--                デバッグ機能                                                   
	--==============================================================================
	DEBUG numeric(1) := 1;
	--==============================================================================
	--                定数定義                                                      
	--==============================================================================
	RTN_FATAL  CONSTANT integer := 99; -- 予期せぬエラー
	PROGRAM_ID CONSTANT text := 'SFIPI051K00R01'; -- プログラムID
	DB_NO_DATA_FOUND  CONSTANT numeric := 2;     -- ＤＢに該当データなし
	--==============================================================================
	--                変数定義                                                      
	--==============================================================================
	gSeqNo			integer := 0;				-- シーケンス
	gSeqNoHenrei	integer := 0;				-- 基金返戻用シーケンス
	gSeqNoIdo		integer := 0;				-- 基金異動履歴用シーケンス
	gSQL			varchar(10000) := NULL;	-- SQL編集
	gCnt			numeric := 0;				-- カウンタ
	gGnrIdx			numeric := 0;				-- 元利インデックス
	gKijunYmd		varchar(8) := NULL;		-- 基準日（元利払日の前日）
	gResultSub		integer := 0;				-- 子ＳＰのリターンコード
	-- 手数料通貨コード(元金手数料は償還通貨。利金手数料は元金ベースなら発行通貨、利金ベースなら利払通貨を使用する)
	gInsTesuTsukaCd	MGR_KIHON.HAKKO_TSUKA_CD%TYPE := '';
	-- 書式フォーマット
	gNextYmd10		KIKIN_IDO.IDO_YMD%TYPE := NULL;			-- 業務日付の翌月10日
	gHenreiJiyuuCd	KIKIN_HENREI.HENREI_JIYUU_CD%TYPE := NULL;	-- 返戻事由コード・基金異動区分
	gGnrKbn			KIKIN_HENREI.GNR_KBN%TYPE := NULL;			-- 元利区分
	gKijunZndk		KIKIN_IDO.KIJUN_ZNDK%TYPE := 0;			-- 基準残高
	gHnrKngk		KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE := 0;		-- 元利金の返戻金額
	gHnrKngkTesuZei	KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE := 0;		-- 元利支払手数料消費税の返戻金額
	gHnrKngkTesu	KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE := 0;		-- 元利支払手数料の返戻金額
	gHnrKngkGoukei	KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE := 0;		-- 元利金の返戻金額合計
	gKknbillShurui	KIKIN_IDO.KKNBILL_SHURUI%TYPE := NULL;		-- 基本請求種類
	gGnrKngk		KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE := 0;		-- 元利金
	-- 2006/06 ASK START
	gZandaka		KIKIN_IDO.KKN_NYUKIN_KNGK%TYPE := 0;		-- 残高
	-- 2006/06 ASK END
	gTaxRitsu		numeric := 0; -- 消費税率
	gZeikomiTesuryo	numeric := 0; -- 税込手数料
	gZeinukiTesuryo	numeric := 0; -- 税抜手数料
	gZei			numeric := 0; -- 消費税
	gTimeStamp		KIKIN_IDO.LAST_TEISEI_DT%TYPE := NULL;	-- タイムスタンプ
	gCapZeikomiGaku			numeric := 0;						-- ＣＡＰ税込金額
	gCapZeinukiGaku			numeric := 0;						-- ＣＡＰ税抜金額
	gCapZei					numeric := 0;						-- ＣＡＰ税金額
	gShzKijunYmd	varchar(8);									-- 消費税率適用基準日
	-- DB取得項目
	-- 元金、利金共通
	-- 配列定義
	recMeisai SFIPI051K00R01_TYPE_RECORD;										-- レコード
	recKo SFIPI051K00R01_TYPE_RECORD_KO;										-- 子レコード
	-- カーソル
	curMeisai REFCURSOR;
	curMeisaiKo REFCURSOR;
	gRtnCd				integer := pkconstant.success();			-- 手数料計算処理戻り値用
	pSzeiProcess		text;				-- 消費税算出方式(従来方式or総額方式)
	pTesuCapProcess		text;				-- 元金支払手数料ＣＡＰ対応
	pShzKijunProcess	text;
	--==============================================================================
	--                メイン処理                                                       
	--==============================================================================
BEGIN
	IF DEBUG = 1 THEN
	CALL pkLog.debug(l_inUserId, PROGRAM_ID, PROGRAM_ID || ' START');
	CALL pkLog.debug(l_inUserId,
				PROGRAM_ID,
				'-------------------- 引数一覧　開始-----------------');
	CALL pkLog.debug(l_inUserId,
				PROGRAM_ID,
				'l_inItakuKaishaCd = ' || l_inItakuKaishaCd);
	CALL pkLog.debug(l_inUserId, PROGRAM_ID, 'l_inUserId = ' || l_inUserId);
	CALL pkLog.debug(l_inUserId,
				PROGRAM_ID,
				'l_inChohyoKbn = ' || l_inChohyoKbn);
	CALL pkLog.debug(l_inUserId, PROGRAM_ID, 'l_inGyomuYmd = ' || l_inGyomuYmd);
	CALL pkLog.debug(l_inUserId,
				PROGRAM_ID,
				'-------------------- 引数一覧　終了-----------------');
	END IF;
	-- 入力パラメータのチェック
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' OR coalesce(trim(both l_inUserId)::text, '') = '' OR
	 coalesce(trim(both l_inChohyoKbn)::text, '') = '' OR coalesce(trim(both l_inGyomuYmd)::text, '') = '' THEN
	-- パラメータエラー
	IF DEBUG = 1 THEN
		CALL pkLog.debug(l_inUserId, PROGRAM_ID, 'param error');
	END IF;
	CALL pkLog.error('ECM501', PROGRAM_ID, 'SQLERRM:' || '');
	RETURN RTN_FATAL;
	END IF;
	-- 基金異動テーブルにある該当利払日レコードの削除
	DELETE FROM KIKIN_IDO
	WHERE		ITAKU_KAISHA_CD = l_inItakuKaishaCd
	AND			RBR_YMD = l_inGyomuYmd
	AND			KKN_IDO_KBN IN ('61','62','63','64','65','66','67','68','6A','6B',
				'71','72','73','74','75','76','77','78','7A','7B');
	-- 基金返戻テーブルにある該当利払日レコードの削除
	DELETE FROM KIKIN_HENREI
	WHERE		ITAKU_KAISHA_CD = l_inItakuKaishaCd
	AND			RBR_YMD = l_inGyomuYmd
	AND			HENREI_JIYUU_CD IN ('61','62','63','64','65','66','67','68','6A','6B',
				'71','72','73','74','75','76','77','78','7A','7B');
	-- SQL編集
	gSQL := SFIPI051K00R01_createSQL(l_inItakuKaishaCd, l_inGyomuYmd);
	-- カーソルオープン
	IF DEBUG = 1 THEN
	CALL pkLog.debug(l_inUserId, PROGRAM_ID, '親SQLの対象データを取得します');
	END IF;
	OPEN curMeisai FOR EXECUTE gSQL;
	-- データ取得
	LOOP
	FETCH curMeisai
		INTO recMeisai.gItakuKaishaCd, -- 委託会社コード
	recMeisai.gMgrCd, -- 銘柄コード
	recMeisai.gRbrYmd, -- 支払日
	recMeisai.gMunitSknShrKngk, -- 銘柄単位償還支払額
	recMeisai.gSaikenShurui  -- 債券種類
	;
	-- データが無くなったらループを抜ける
	EXIT WHEN NOT FOUND;/* apply on curMeisai */
	-- 取得データログ
	IF DEBUG = 1 THEN
		CALL pkLog.debug(l_inUserId,
					PROGRAM_ID,
					'データ' || (gSeqNo + 1) || '件目');
		CALL pkLog.debug(l_inUserId,
					PROGRAM_ID,
					'銘柄コード = ' || recMeisai.gMgrCd);
		CALL pkLog.debug(l_inUserId, PROGRAM_ID, '利払日 = ' || recMeisai.gRbrYmd);
	END IF;
	-- 消費税算出方式(従来方式or総額方式)取得
	pSzeiProcess := pkControl.getCtlValue(l_inItakuKaishaCd, 'CALCTESUKNGK0', '0');
	-- 処理制御マスタから元金支払手数料ＣＡＰ対応フラグ取得
	pTesuCapProcess := pkControl.getCtlValue(l_inItakuKaishaCd, 'TesuryoCap0', '0');
	-- 消費税率適用基準日フラグ(1:取引日ベース, 0:徴求日ベース(デフォルト))取得
	pShzKijunProcess := pkControl.getCtlValue(l_inItakuKaishaCd, 'ShzKijun', '0');
	-- 0:元金処理 1:利金処理
	FOR gGnrIdx IN 0 .. 1 LOOP
		-- カーソルオープン
		IF gGnrIdx = 0 THEN
		-- 元金SQLカーソル取得
			IF DEBUG = 1 THEN
				CALL pkLog.debug(l_inUserId,
							PROGRAM_ID,
							'元金用SQLの対象データを取得します');
			END IF;
			curMeisaiKo := SFIPI051K00R01_SQLRunGnkn(recMeisai.gItakuKaishaCd, recMeisai.gMgrCd, recMeisai.gRbrYmd);
		ELSE
			-- 利金SQL実行カーソル取得
			IF DEBUG = 1 THEN
				CALL pkLog.debug(l_inUserId,
							PROGRAM_ID,
							'利金用SQLの対象データを取得します');
			END IF;
			curMeisaiKo := SFIPI051K00R01_SQLRunRkn(recMeisai.gItakuKaishaCd, recMeisai.gMgrCd, recMeisai.gRbrYmd);
		END IF;
		LOOP
			FETCH curMeisaiKo
				INTO	recKo.gItakuKaishaCd, 		-- 委託会社コード
						recKo.gMgrCd, 				-- 銘柄コード
						recKo.gJikoTotalHkukKbn,	-- 自行総額引受区分
						recKo.gKkKanyoFlg,			-- 機構関与方式採用フラグ	
						recKo.gHakkoTsukaCd, 		-- 発行通貨コード
						recKo.gShokanTsukaCd, 		-- 償還通貨コード or 利払通貨コード
						recKo.gShokanKjt, 			-- 償還期日
						recKo.gShokanYmd, 			-- 償還年月日
						recKo.gChokyuYmd,			-- 手数料徴求日
						recKo.gZndkKijunYmd,		-- 残高基準日
						recKo.gGnknShrTesuBunbo,	-- 元金支払手数料分母
						recKo.gGnknShrTesuBunshi,	-- 元金支払手数料分子
						recKo.gGnknShrTesuCap,		-- 元金支払手数料ＣＡＰ
						recKo.gSzeiSeikyuKbn,		-- 消費税請求区分
						recKo.gKknNyukinKngk11,		-- 基金入金額(異動区分11)
						recKo.gKknNyukinKngk12,		-- 基金入金額(異動区分12)
						recKo.gKknNyukinKngk13,		-- 基金入金額(異動区分13)
						recKo.gKyujitsuKbn, 		-- 休日区分
						recKo.gAreaCd,				-- 地域コード
						recKo.gTsukarishiKngk,		-- 1通貨あたりの利子金額
						recKo.gTesuShuruiCd  		-- 手数料種類コード
						;
			-- データが無くなったらループを抜ける
			EXIT WHEN NOT FOUND;/* apply on curMeisaiKo */
			-- 基準日（元利払日の前日）の取得
			gKijunYmd := pkDate.getZenYmd(recMeisai.gRbrYmd);
			-- 基準残高
			gKijunZndk := pkIpaZndk.getKjnZndk(recMeisai.gItakuKaishaCd,
												recMeisai.gMgrCd,
												gKijunYmd,
												3);
			IF gGnrIdx = 0 THEN
				-- 元利区分
				gGnrKbn := '1';
				-- 返戻事由コード・基金異動区分コード種別：103
				gHenreiJiyuuCd := '6' || SFIPI051K00R01_getHenreiJiyuuCd(recMeisai.gItakuKaishaCd, recMeisai.gMgrCd, recKo.gShokanKjt, recKo.gZndkKijunYmd);
				-- 元金
				gGnrKngk := SFIPI051K00R01_getTruncKngk(recKo.gShokanTsukaCd, recMeisai.gMunitSknShrKngk);
			ELSE
				-- 元利区分
				gGnrKbn := '2';
				-- 返戻事由コード・基金異動区分
				gHenreiJiyuuCd := '7' || SFIPI051K00R01_getHenreiJiyuuCd(recMeisai.gItakuKaishaCd, recMeisai.gMgrCd, recKo.gShokanKjt, recKo.gZndkKijunYmd);
				-- 利金
				gGnrKngk := SFIPI051K00R01_getTruncKngk(recKo.gShokanTsukaCd, gKijunZndk * recKo.gTsukarishiKngk);
			END IF;
			-- 税込手数料 = 基金入金額 * 元金支払手数料率(分子) / 元金支払手数料率(分母) * (消費税率 + 1)
			gZeikomiTesuryo := 0;
			--ループ内用計算前初期化
			gZeinukiTesuryo:=0;
			gZei := 0;
			gInsTesuTsukaCd := recKo.gShokanTsukaCd;	-- 償還通貨コードをセット
			--徴求日がNULLの場合、以下の処理を飛ばす
			IF (trim(both recKo.gChokyuYmd) IS NOT NULL AND (trim(both recKo.gChokyuYmd))::text <> '') THEN
				-- 消費税率適用基準日切り替え
				IF pShzKijunProcess= '1' THEN
					gShzKijunYmd := recKo.gShokanYmd;
				ELSE
					gShzKijunYmd := recKo.gChokyuYmd;
				END IF;
				--gGnrIdx 0:元金処理 1:利金処理
				IF gGnrIdx = 0 THEN
					--手数料分母未設定対応
					IF recKo.gGnknShrTesuBunbo > 0 THEN
						-- 手数料・消費税を計算
						SELECT f.l_outtesukngknuki, f.l_outtesukngkkomi, f.l_outszeikngk, f.extra_param
					INTO gZeinukiTesuryo, gZeikomiTesuryo, gZei, gRtnCd
					FROM PKIPACALCTESUKNGK.getTesuZeiCommon(
						recKo.gItakuKaishaCd,
						recKo.gMgrCd,
						gGnrKngk,
						recKo.gGnknShrTesuBunshi,
						recKo.gGnknShrTesuBunbo,
						gInsTesuTsukaCd,
						gShzKijunYmd,
						pSzeiProcess::varchar
					) AS f;
						IF gRtnCd <> pkconstant.success() THEN
						-- 正常終了していなければ、異常終了("1"か"99")をリターンさせる。
--						   共通関数の方でログに出力させているので、ここでは特にログに出力は行わない 
							RETURN gRtnCd;
						END IF;
					END IF;
					-- 元金支払手数料ＣＡＰを上限にして元金支払手数料を算出
					IF ((pTesuCapProcess = '1') AND (recKo.gGnknShrTesuCap > 0) AND (recKo.gJikoTotalHkukKbn = '1') AND (recKo.gKkKanyoFlg = '0')) THEN
						-- 元金支払手数料ＣＡＰを基に、手数料・消費税を計算
						gRtnCd := PKIPACALCTESUKNGK.getTesuZeiTeigakuCommon(	
																		recKo.gItakuKaishaCd,			-- 委託会社コード
																		recKo.gMgrCd,					-- 銘柄コード
																		recKo.gGnknShrTesuCap,			-- 手数料算出の基準となる額面
																		gInsTesuTsukaCd,				-- 通貨コード
																		gShzKijunYmd,					-- 消費税の適用基準年月日
																		gCapZeinukiGaku,				-- (戻)税抜手数料金額
																		gCapZeikomiGaku,				-- (戻)税込手数料金額(値は使用しない)
																		gCapZei 							-- (戻)消費税金額
																		);
						IF gRtnCd <> pkconstant.success() THEN
						-- 正常終了していなければ、異常終了("1"か"99")をリターンさせる。
--						   共通関数の方でログに出力させているので、ここでは特にログに出力は行わない 
							RETURN gRtnCd;
						END IF;
						IF (gZeikomiTesuryo > gCapZeinukiGaku) THEN																
									gZeikomiTesuryo := gCapZeikomiGaku;
									gZeinukiTesuryo := gCapZeinukiGaku;
									gZei := gCapZei;
						END IF;
					END IF;
					ELSE
						--利金処理
						--手数料計算情報を設定
						DECLARE
							v_tesuryo_result sfipi051k00r01_tesuryo_result;
						BEGIN
							v_tesuryo_result := SFIPI051K00R01_setRknTesuryo(recMeisai.gItakuKaishaCd,recMeisai.gMgrCd);
							gResultSub := v_tesuryo_result.result_code;
							recKo.gGnknShrTesuBunbo := v_tesuryo_result.gGnknShrTesuBunbo;
							recKo.gGnknShrTesuBunshi := v_tesuryo_result.gGnknShrTesuBunshi;
							recKo.gSzeiSeikyuKbn := v_tesuryo_result.gSzeiSeikyuKbn;
							recKo.gTesuShuruiCd := v_tesuryo_result.gTesuShuruiCd;
						END;
						--手数料をとる場合の消費税の計算処理
						IF gResultSub = pkconstant.success() THEN
							--元利金残高設定
							IF recKo.gTesuShuruiCd = '82' THEN
								gInsTesuTsukaCd := recKo.gShokanTsukaCd;	-- (変数名は償還通貨になっているが)利払通貨コードをセット
								gZandaka := SFIPI051K00R01_getTruncKngk(gInsTesuTsukaCd, gKijunZndk * recKo.gTsukarishiKngk);
							ELSE
								gInsTesuTsukaCd := recKo.gHakkoTsukaCd;		-- 利金手数料元金ベースの場合は発行通貨コードにセットしなおす 
								gZandaka := SFIPI051K00R01_getTruncKngk(gInsTesuTsukaCd, gKijunZndk);
							END IF;
							--手数料分母未設定対応
							IF  recKo.gGnknShrTesuBunbo > 0 THEN
								-- 手数料・消費税を計算
								SELECT f.l_outtesukngknuki, f.l_outtesukngkkomi, f.l_outszeikngk, f.extra_param
							INTO gZeinukiTesuryo, gZeikomiTesuryo, gZei, gRtnCd
							FROM PKIPACALCTESUKNGK.getTesuZeiCommon(
								recKo.gItakuKaishaCd,
								recKo.gMgrCd,
								gZandaka,
								recKo.gGnknShrTesuBunshi,
								recKo.gGnknShrTesuBunbo,
								gInsTesuTsukaCd,
								gShzKijunYmd,
								pSzeiProcess::varchar
							) AS f;
								IF gRtnCd <> pkconstant.success() THEN
								-- 正常終了していなければ、異常終了("1"か"99")をリターンさせる。
--								   共通関数の方でログに出力させているので、ここでは特にログに出力は行わない 
									RETURN gRtnCd;
								END IF;
							END IF;
						END IF;
					END IF;
				END IF;
			-- 元利金の返戻金額
			gHnrKngk := recKo.gKknNyukinKngk11 - gGnrKngk;
			-- 元利金支払手数料消費税の返戻金額
			gHnrKngkTesuZei := recKo.gKknNyukinKngk13 - gZei;
			-- 元利金支払手数料の返戻金額
			gHnrKngkTesu := recKo.gKknNyukinKngk12 - gZeinukiTesuryo;
			-- 元利金の返戻金額合計
			gHnrKngkGoukei := gHnrKngk + gHnrKngkTesuZei + gHnrKngkTesu;
			-- 取得データログ
			IF DEBUG = 1 THEN
				CALL pkLog.debug(l_inUserId,
							PROGRAM_ID,
							'基準日（元利払日の前日） = ' || gKijunYmd);
				CALL pkLog.debug(l_inUserId, PROGRAM_ID, '元利金 = ' || gGnrKngk);
				CALL pkLog.debug(l_inUserId, PROGRAM_ID, '消費税率 = ' || gTaxRitsu);
				CALL pkLog.debug(l_inUserId,
							PROGRAM_ID,
							'税込手数料 = ' || gZeikomiTesuryo);
				CALL pkLog.debug(l_inUserId, PROGRAM_ID, '基準残高 = ' || gKijunZndk);
				CALL pkLog.debug(l_inUserId, PROGRAM_ID, '手数料消費税 = ' || gZei);
				--元利金残高(gZandaka)は、利金処理・手数料消費税計算のみで使用
				IF gGnrIdx = 1 and gResultSub = 0 THEN  --
						CALL pkLog.debug(l_inUserId, PROGRAM_ID, '元利金残高 = ' || gZandaka);
				END IF;
				CALL pkLog.debug(l_inUserId,
							PROGRAM_ID,
							'税抜手数料 = ' || gZeinukiTesuryo);
				CALL pkLog.debug(l_inUserId,
							PROGRAM_ID,
							'元利金の返戻金額 = ' || gHnrKngk);
				CALL pkLog.debug(l_inUserId,
							PROGRAM_ID,
							'元利金支払手数料消費税の返戻金額 = ' ||
							gHnrKngkTesuZei);
				CALL pkLog.debug(l_inUserId,
							PROGRAM_ID,
							'元利金支払手数料の返戻金額 = ' || gHnrKngkTesu);
				CALL pkLog.debug(l_inUserId,
							PROGRAM_ID,
							'元利金の返戻金額合計 = ' || gHnrKngkGoukei);
			END IF;
			-- 各返戻金額が存在した場合のみ登録
			IF gHnrKngk > 0 OR gHnrKngkTesuZei > 0 OR gHnrKngkTesu > 0 THEN
				-- タイムスタンプ取得
				gTimeStamp := to_timestamp(pkDate.getCurrentTime(),
										 'yyyy-mm-dd HH24:MI:SS.US');
				-- 基金返戻テーブルキーの重複防止
				gCnt := 0;
				SELECT COUNT(*)
					INTO STRICT gCnt
				FROM KIKIN_HENREI
				WHERE ITAKU_KAISHA_CD = recKo.gItakuKaishaCd
					AND MGR_CD = recKo.gMgrCd
					AND TSUKA_CD = recKo.gShokanTsukaCd
					AND HENREI_JIYUU_CD = gHenreiJiyuuCd
					AND RBR_KJT = recKo.gShokanKjt
					AND GNR_KBN = gGnrKbn;
				IF DEBUG = 1 THEN
				CALL pkLog.debug(l_inUserId,
							PROGRAM_ID,
							'基金返戻テーブルキーの重複防止：重複カウント = ' || gCnt);
			END IF;
			-- 基金返戻テーブル挿入処理
			IF gCnt = 0 THEN
				IF DEBUG = 1 THEN
					CALL pkLog.debug(l_inUserId,
								PROGRAM_ID,
								'基金返戻テーブルINSERT処理を行います');
				END IF;
				-- 利金支払手数料(元金ベース)かつ、発行通貨と利払通貨が異なる場合は分割して登録する
				IF recKo.gTesuShuruiCd = '61' AND recKo.gHakkoTsukaCd <> recKo.gShokanTsukaCd THEN
					-- 元利金の返戻金額がある場合のみ登録
					IF (gHnrKngk > 0) THEN
						CALL SFIPI051K00R01_insertDataKknHenrei(
											recKo.gItakuKaishaCd,		-- 委託会社コード
											recKo.gMgrCd,				-- 銘柄コード
											recKo.gShokanTsukaCd,		-- 利払通貨コード
											gHenreiJiyuuCd,				-- 返戻事由コード
											recKo.gShokanKjt,			-- 利払期日
											recKo.gShokanYmd,			-- 利払日
											gGnrKbn,					-- 元利区分
											gHnrKngk,					-- 返戻金額合計（元金のみ）
											recKo.gGnknShrTesuBunbo,	-- 支払手数料率(分母)
											recKo.gGnknShrTesuBunshi,	-- 支払手数料率(分子)
											0,							-- 支払手数料
											0,							-- 支払手数料消費税
											l_inUserId 					-- ユーザID
											);
						-- 基金返戻シーケンスアップ
						gSeqNoHenrei := gSeqNoHenrei + 1;
					END IF;
					-- 手数料の返戻金額がある場合のみ登録(手数料を選択していない銘柄は0円で登録をしないようにする為)
					IF gHnrKngkTesu > 0 THEN
						CALL SFIPI051K00R01_insertDataKknHenrei(
											recKo.gItakuKaishaCd,			-- 委託会社コード
											recKo.gMgrCd,					-- 銘柄コード
											recKo.gHakkoTsukaCd,			-- 利金手数料用通貨コード(発行通貨コード)
											gHenreiJiyuuCd,					-- 返戻事由コード
											recKo.gShokanKjt,				-- 利払期日
											recKo.gShokanYmd,				-- 利払日
											gGnrKbn,						-- 元利区分
											gHnrKngkTesuZei + gHnrKngkTesu,	-- 返戻金額合計（手数料＋消費税）
											recKo.gGnknShrTesuBunbo,		-- 支払手数料率(分母)
											recKo.gGnknShrTesuBunshi,		-- 支払手数料率(分子)
											gHnrKngkTesu,					-- 支払手数料
											gHnrKngkTesuZei,				-- 支払手数料消費税
											l_inUserId 						-- ユーザID
											);
						-- 基金返戻シーケンスアップ
						gSeqNoHenrei := gSeqNoHenrei + 1;
					END IF;
				ELSE
				-- 利金支払手数料(元金ベース)で発行通貨=利払通貨、利金支払手数料(利金ベース)、元金支払手数料は
				-- 通常どおり登録する
					CALL SFIPI051K00R01_insertDataKknHenrei(
										recKo.gItakuKaishaCd,		-- 委託会社コード
										recKo.gMgrCd,				-- 銘柄コード
										gInsTesuTsukaCd,			-- 通貨コード
										gHenreiJiyuuCd,				-- 返戻事由コード
										recKo.gShokanKjt,			-- 利払期日
										recKo.gShokanYmd,			-- 利払日
										gGnrKbn,					-- 元利区分
										gHnrKngkGoukei,				-- 返戻金額合計
										recKo.gGnknShrTesuBunbo,	-- 支払手数料率(分母)
										recKo.gGnknShrTesuBunshi,	-- 支払手数料率(分子)
										gHnrKngkTesu,				-- 支払手数料
										gHnrKngkTesuZei,			-- 支払手数料消費税
										l_inUserId 					-- ユーザID
										);
					-- 基金返戻シーケンスアップ
					gSeqNoHenrei := gSeqNoHenrei + 1;
				END IF;
			END IF;
			-- SB銘柄は基金異動日を業務日付の翌月１０日に変換
			IF recMeisai.gSaikenShurui NOT IN ( '80', '89') THEN
				gNextYmd10 := SUBSTR(l_inGyomuYmd, 1, 6) || '10';
				gNextYmd10 := pkdate.calcMonthKyujitsuKbn(gNextYmd10,
														1,
														recKo.gKyujitsuKbn,
														recKo.gAreaCd);
			-- CB銘柄は基金異動日を業務日付とする
			ELSE
				gNextYmd10 := l_inGyomuYmd;
			END IF;
			-- 基本請求種類
			gKknbillShurui := '0';
			IF gHnrKngk > 0 AND gHnrKngkTesu > 0 THEN
			gKknbillShurui := '1';
			ELSIF gHnrKngk > 0 AND gHnrKngkTesu = 0 THEN
			gKknbillShurui := '2';
			ELSIF gHnrKngk = 0 AND gHnrKngkTesu > 0 THEN
			gKknbillShurui := '3';
			END IF;
			-- 取得データログ
			IF DEBUG = 1 THEN
			CALL pkLog.debug(l_inUserId,
						PROGRAM_ID,
						'業務日付翌月１０日 = ' || gNextYmd10);
			CALL pkLog.debug(l_inUserId,
						PROGRAM_ID,
						'基本請求種類 = ' || gKknbillShurui);
			END IF;
			-- 基金異動履歴テーブルキーの重複防止
			gCnt := 0;
			SELECT COUNT(*)
			INTO STRICT gCnt
			FROM KIKIN_IDO
			WHERE ITAKU_KAISHA_CD = recKo.gItakuKaishaCd
			 AND MGR_CD = recKo.gMgrCd
			 AND RBR_KJT = recKo.gShokanKjt
			 AND IDO_YMD = gNextYmd10
			 AND KKN_IDO_KBN = gHenreiJiyuuCd;
			IF DEBUG = 1 THEN
			CALL pkLog.debug(l_inUserId,
						PROGRAM_ID,
						'基金異動履歴テーブルキーの重複防止：重複カウント = ' || gCnt);
			END IF;
			-- 基金異動履歴テーブル挿入処理
			IF gCnt = 0 THEN
				IF DEBUG = 1 THEN
					CALL pkLog.debug(l_inUserId,
								PROGRAM_ID,
								'基金異動履歴テーブルINSERT処理を行います');
				END IF;
				-- 元利金の返戻金額がある場合のみ登録
				IF (gHnrKngk > 0) THEN
					-- 利金支払手数料(元金ベース)かつ、発行通貨と利払通貨が異なる場合は分割して登録する
					-- 返戻金額元金の登録
					CALL SFIPI051K00R01_insertDataKknIdo(
									recKo.gItakuKaishaCd,		-- 委託会社コード
					 				recKo.gMgrCd,				-- 銘柄コード
									recKo.gShokanKjt,			-- 利払期日
									recKo.gShokanYmd,			-- 利払日
									recKo.gShokanTsukaCd,		-- 利払通貨コード
									gNextYmd10,					-- 異動年月日
									gHenreiJiyuuCd,				-- 基金異動区分
									gKknbillShurui,				-- 基金請求種類
									gHnrKngk,					-- 基金出金額（返戻金額合計）
									gKijunZndk,					-- 基準残高
									l_inUserId 					-- ユーザID
									);
					-- 基金異動履歴シーケンスアップ
					gSeqNoIdo := gSeqNoIdo + 1;
				END IF;
				-- 返戻金額手数料・消費税の登録(金額がある場合のみ)
				IF (gHnrKngkTesuZei + gHnrKngkTesu) > 0 THEN
					CALL SFIPI051K00R01_insertDataKknIdo(
									recKo.gItakuKaishaCd,			-- 委託会社コード
									recKo.gMgrCd,					-- 銘柄コード
									recKo.gShokanKjt,				-- 利払期日
									recKo.gShokanYmd,				-- 利払日
									gInsTesuTsukaCd,				-- 利金手数料用通貨コード(発行通貨コード)
									gNextYmd10,						-- 異動年月日
									substring(gHenreiJiyuuCd, 1, 1)||'8',-- 基金異動区分（返戻事由：68=元金返戻手数料：78=利金返戻手数料）
									gKknbillShurui,					-- 基金請求種類
									gHnrKngkTesuZei + gHnrKngkTesu,	-- 基金出金額（返戻金額合計）
									gKijunZndk,						-- 基準残高
									l_inUserId 						-- ユーザID
									);
					-- 基金異動履歴シーケンスアップ
					gSeqNoIdo := gSeqNoIdo + 1;
				END IF;
			END IF;
		END IF;
		END LOOP;
		-- カーソル子クローズ
		CLOSE curMeisaiKo;
	END LOOP;
	-- シーケンスアップ
	gSeqNo := gSeqNo + 1;
	END LOOP;
	-- カーソル親クローズ
	CLOSE curMeisai;
	IF DEBUG = 1 THEN
	CALL pkLog.debug(l_inUserId,
				PROGRAM_ID,
				'　☆合計データ(2テーブル)　' || gSeqNo || ' 件');
	CALL pkLog.debug(l_inUserId,
				PROGRAM_ID,
				'　☆基金返戻テーブル　' || gSeqNoHenrei ||
				' 件登録しました');
	CALL pkLog.debug(l_inUserId,
				PROGRAM_ID,
				'　☆基金異動履歴テーブル　' || gSeqNoIdo ||
				' 件登録しました');
	END IF;
	IF DEBUG = 1 THEN
	CALL pkLog.debug(l_inUserId, PROGRAM_ID, PROGRAM_ID || ' END');
	END IF;
	-- 終了処理
	RETURN pkconstant.success();
	-- エラー処理
EXCEPTION
	WHEN OTHERS THEN
	RAISE NOTICE 'EXCEPTION in SFIPI051K00R01: SQLSTATE=%, SQLERRM=%', SQLSTATE, SQLERRM;
	CALL pkLog.fatal('ECM701', PROGRAM_ID, 'SQLCODE:' || SQLSTATE);
	CALL pkLog.fatal('ECM701', PROGRAM_ID, 'SQLERRM:' || SQLERRM);
	RETURN RTN_FATAL;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi051k00r01 (l_inItakuKaishaCd TEXT, l_inUserId TEXT, l_inChohyoKbn TEXT, l_inGyomuYmd TEXT  ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipi051k00r01_sqlrungnkn (p_itaku_kaisha_cd text, p_mgr_cd text, p_rbr_ymd text) RETURNS REFCURSOR AS $body$
DECLARE
	curMeisaiKo REFCURSOR;
BEGIN
-- 元金SQLカーソル取得
OPEN curMeisaiKo FOR
	SELECT VMG1.ITAKU_KAISHA_CD,
		 VMG1.MGR_CD,
		 VMG1.JIKO_TOTAL_HKUK_KBN,
		 VMG1.KK_KANYO_FLG,
		 VMG1.HAKKO_TSUKA_CD,
		 VMG1.SHOKAN_TSUKA_CD,
		 VMG3.SHOKAN_KJT,
		 VMG3.SHOKAN_YMD,
		 VMG3.TESU_CHOKYU_YMD,
		 K02.ZNDK_KIJUN_YMD,
		 coalesce(MG8.GNKN_SHR_TESU_BUNBO, 0),
		 coalesce(MG8.GNKN_SHR_TESU_BUNSHI, 0),
		 coalesce(MG8.GNKN_SHR_TESU_CAP, 0),
		 coalesce(trim(both MG8.SZEI_SEIKYU_KBN), '0'),
		 SUM(coalesce(VK11.KKN_NYUKIN_KNGK, 0)),
		 SUM(coalesce(VK12.KKN_NYUKIN_KNGK, 0)),
		 SUM(coalesce(VK13.KKN_NYUKIN_KNGK, 0)),
		 VMG1.KYUJITSU_KBN,
		 VMG1.AREACD,
-- 2006/05 ASK START
		 0,
-- 2006/05 ASK END
		 0
	FROM (SELECT *
			FROM MGR_KIHON_VIEW VMG12
			WHERE (trim(both VMG12.ISIN_CD) IS NOT NULL AND (trim(both VMG12.ISIN_CD))::text <> '')
			 AND VMG12.SHORI_KBN = '1' ) vmg1, kikin_ido k02
LEFT OUTER JOIN (SELECT MG3.ITAKU_KAISHA_CD,
				 MG3.MGR_CD,
				 MG3.SHOKAN_KJT,
				 MG3.SHOKAN_YMD,
				 MG3.TESU_CHOKYU_YMD
			FROM MGR_SHOKIJ MG3
			WHERE MG3.SHOKAN_KBN <> '30'
			 AND MG3.ITAKU_KAISHA_CD = p_itaku_kaisha_cd
			 AND MG3.MGR_CD = p_mgr_cd
			 AND MG3.SHOKAN_YMD = p_rbr_ymd
			GROUP BY MG3.ITAKU_KAISHA_CD,
					MG3.MGR_CD,
					MG3.SHOKAN_KJT,
					MG3.SHOKAN_YMD,
					MG3.TESU_CHOKYU_YMD) vmg3 ON (K02.ITAKU_KAISHA_CD = VMG3.ITAKU_KAISHA_CD AND K02.MGR_CD = VMG3.MGR_CD AND K02.RBR_YMD = VMG3.SHOKAN_YMD)
LEFT OUTER JOIN mgr_tesuryo_prm mg8 ON (K02.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD AND K02.MGR_CD = MG8.MGR_CD)
LEFT OUTER JOIN (SELECT *
			FROM KIKIN_IDO K11
			WHERE K11.KKN_IDO_KBN IN ('11')
			 AND K11.ITAKU_KAISHA_CD = p_itaku_kaisha_cd
			 AND K11.MGR_CD = p_mgr_cd
			 AND K11.RBR_YMD = p_rbr_ymd ) vk11 ON (K02.ITAKU_KAISHA_CD = VK11.ITAKU_KAISHA_CD AND K02.MGR_CD = VK11.MGR_CD AND K02.RBR_KJT = VK11.RBR_KJT AND K02.IDO_YMD = VK11.IDO_YMD AND K02.KKN_IDO_KBN = VK11.KKN_IDO_KBN)
LEFT OUTER JOIN (SELECT *
			FROM KIKIN_IDO K12
			WHERE K12.KKN_IDO_KBN IN ('12')
			 AND K12.ITAKU_KAISHA_CD = p_itaku_kaisha_cd
			 AND K12.MGR_CD = p_mgr_cd
			 AND K12.RBR_YMD = p_rbr_ymd ) vk12 ON (K02.ITAKU_KAISHA_CD = VK12.ITAKU_KAISHA_CD AND K02.MGR_CD = VK12.MGR_CD AND K02.RBR_KJT = VK12.RBR_KJT AND K02.IDO_YMD = VK12.IDO_YMD AND K02.KKN_IDO_KBN = VK12.KKN_IDO_KBN)
LEFT OUTER JOIN (SELECT *
			FROM KIKIN_IDO K13
			WHERE K13.KKN_IDO_KBN IN ('13')
			 AND K13.ITAKU_KAISHA_CD = p_itaku_kaisha_cd
			 AND K13.MGR_CD = p_mgr_cd
			 AND K13.RBR_YMD = p_rbr_ymd ) vk13 ON (K02.ITAKU_KAISHA_CD = VK13.ITAKU_KAISHA_CD AND K02.MGR_CD = VK13.MGR_CD AND K02.RBR_KJT = VK13.RBR_KJT AND K02.IDO_YMD = VK13.IDO_YMD AND K02.KKN_IDO_KBN = VK13.KKN_IDO_KBN)
WHERE K02.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD AND K02.MGR_CD = VMG1.MGR_CD                     AND K02.KKN_IDO_KBN IN ('11', '12', '13') AND K02.ITAKU_KAISHA_CD = p_itaku_kaisha_cd AND K02.MGR_CD = p_mgr_cd AND K02.RBR_YMD = p_rbr_ymd AND K02.DATA_SAKUSEI_KBN >= '1' GROUP BY VMG1.ITAKU_KAISHA_CD,
			VMG1.MGR_CD,
			VMG1.JIKO_TOTAL_HKUK_KBN,
			VMG1.KK_KANYO_FLG,
			K02.RBR_YMD,
			VMG1.HAKKO_TSUKA_CD,
			VMG1.SHOKAN_TSUKA_CD,
			VMG3.SHOKAN_KJT,
			VMG3.SHOKAN_YMD,
			VMG3.TESU_CHOKYU_YMD,
			K02.ZNDK_KIJUN_YMD,
			MG8.GNKN_SHR_TESU_BUNBO,
			MG8.GNKN_SHR_TESU_BUNSHI,
			MG8.GNKN_SHR_TESU_CAP,
			MG8.SZEI_SEIKYU_KBN,
			VMG1.KYUJITSU_KBN,
			VMG1.AREACD;
	RETURN curMeisaiKo;
EXCEPTION
WHEN OTHERS THEN
	RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi051k00r01_sqlrungnkn () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipi051k00r01_sqlrunrkn (p_itaku_kaisha_cd text, p_mgr_cd text, p_rbr_ymd text) RETURNS REFCURSOR AS $body$
DECLARE
	curMeisaiKo REFCURSOR;
BEGIN
-- 利金SQLカーソル取得
OPEN curMeisaiKo FOR
	SELECT VMG1.ITAKU_KAISHA_CD,
		 VMG1.MGR_CD,
		 VMG1.JIKO_TOTAL_HKUK_KBN,
		 VMG1.KK_KANYO_FLG,
		 VMG1.HAKKO_TSUKA_CD,
		 VMG1.RBR_TSUKA_CD,
		 MG2.RBR_KJT,
		 MG2.RBR_YMD,
		 MG2.TESU_CHOKYU_YMD,
		 K02.ZNDK_KIJUN_YMD,
		 0,
		 0,
		 0,
		 0,
		 SUM(coalesce(VK11.KKN_NYUKIN_KNGK, 0)),
		 SUM(coalesce(VK12.KKN_NYUKIN_KNGK, 0)),
		 SUM(coalesce(VK13.KKN_NYUKIN_KNGK, 0)),
		 VMG1.KYUJITSU_KBN,
		 VMG1.AREACD,
		 coalesce(MG2.TSUKARISHI_KNGK, 0),
		 0
	FROM (SELECT *
			FROM MGR_KIHON_VIEW VMG12
			WHERE (trim(both VMG12.ISIN_CD) IS NOT NULL AND (trim(both VMG12.ISIN_CD))::text <> '')
			 AND VMG12.SHORI_KBN = '1' ) vmg1, kikin_ido k02
LEFT OUTER JOIN mgr_rbrkij mg2 ON (K02.ITAKU_KAISHA_CD = MG2.ITAKU_KAISHA_CD AND K02.MGR_CD = MG2.MGR_CD AND K02.RBR_YMD = MG2.RBR_YMD)
LEFT OUTER JOIN (SELECT *
			FROM KIKIN_IDO K11
			WHERE K11.KKN_IDO_KBN IN ('21')
			 AND K11.ITAKU_KAISHA_CD = p_itaku_kaisha_cd
			 AND K11.MGR_CD = p_mgr_cd
			 AND K11.RBR_YMD = p_rbr_ymd ) vk11 ON (K02.ITAKU_KAISHA_CD = VK11.ITAKU_KAISHA_CD AND K02.MGR_CD = VK11.MGR_CD AND K02.RBR_KJT = VK11.RBR_KJT AND K02.IDO_YMD = VK11.IDO_YMD AND K02.KKN_IDO_KBN = VK11.KKN_IDO_KBN)
LEFT OUTER JOIN (SELECT *
			FROM KIKIN_IDO K12
			WHERE K12.KKN_IDO_KBN IN ('22')
			 AND K12.ITAKU_KAISHA_CD = p_itaku_kaisha_cd
			 AND K12.MGR_CD = p_mgr_cd
			 AND K12.RBR_YMD = p_rbr_ymd ) vk12 ON (K02.ITAKU_KAISHA_CD = VK12.ITAKU_KAISHA_CD AND K02.MGR_CD = VK12.MGR_CD AND K02.RBR_KJT = VK12.RBR_KJT AND K02.IDO_YMD = VK12.IDO_YMD AND K02.KKN_IDO_KBN = VK12.KKN_IDO_KBN)
LEFT OUTER JOIN (SELECT *
			FROM KIKIN_IDO K13
			WHERE K13.KKN_IDO_KBN IN ('23')
			 AND K13.ITAKU_KAISHA_CD = p_itaku_kaisha_cd
			 AND K13.MGR_CD = p_mgr_cd
			 AND K13.RBR_YMD = p_rbr_ymd ) vk13 ON (K02.ITAKU_KAISHA_CD = VK13.ITAKU_KAISHA_CD AND K02.MGR_CD = VK13.MGR_CD AND K02.RBR_KJT = VK13.RBR_KJT AND K02.IDO_YMD = VK13.IDO_YMD AND K02.KKN_IDO_KBN = VK13.KKN_IDO_KBN)
WHERE K02.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD AND K02.MGR_CD = VMG1.MGR_CD                   AND K02.KKN_IDO_KBN IN ('21', '22', '23') AND K02.ITAKU_KAISHA_CD = p_itaku_kaisha_cd AND K02.MGR_CD = p_mgr_cd AND K02.RBR_YMD = p_rbr_ymd AND K02.DATA_SAKUSEI_KBN >= '1' GROUP BY VMG1.ITAKU_KAISHA_CD,
			VMG1.MGR_CD,
			VMG1.JIKO_TOTAL_HKUK_KBN,
			VMG1.KK_KANYO_FLG,
			K02.RBR_YMD,
			VMG1.HAKKO_TSUKA_CD,
			VMG1.RBR_TSUKA_CD,
			MG2.RBR_KJT,
			MG2.RBR_YMD,
			MG2.TESU_CHOKYU_YMD,
			K02.ZNDK_KIJUN_YMD,
			VMG1.KYUJITSU_KBN,
			VMG1.AREACD,
			MG2.TSUKARISHI_KNGK;
	RETURN curMeisaiKo;
EXCEPTION
WHEN OTHERS THEN
	RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi051k00r01_sqlrunrkn () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipi051k00r01_createsql (l_inItakuKaishaCd text, l_inGyomuYmd text) RETURNS text AS $body$
DECLARE
	gSql text := '';
BEGIN
-- 変数を初期化
gSql := '';
-- 変数にSQLクエリ文を代入
gSql := 'SELECT '
		||'	WK1.ITAKU_KAISHA_CD, '
		||'	WK1.MGR_CD, '
		||'	WK1.SHR_YMD, '
		||'	SUM(COALESCE(WK1.GNKN_KNGK, 0)), '
		||'	WK1.SAIKEN_SHURUI '
		||'FROM '
		||'( '
		||'	SELECT '
		||'		MG2.ITAKU_KAISHA_CD AS ITAKU_KAISHA_CD, '
		||'		MG2.MGR_CD AS MGR_CD, '
		||'		MG2.RBR_YMD AS SHR_YMD, '
		||'		VMG1.SAIKEN_SHURUI, '
		||'		0 AS GNKN_KNGK '
		||'	FROM '
		||'		MGR_RBRKIJ MG2, '
		||'		( '
		||'			SELECT * '
		||'			FROM MGR_KIHON_VIEW VMG12 '
		||'			WHERE TRIM(VMG12.ISIN_CD) IS NOT NULL '
		||'			AND VMG12.SHORI_KBN = ''1'' '
		||'			AND VMG12.KK_KANYO_FLG <> ''2'' '
		||'			AND VMG12.JTK_KBN <> ''5'' '
		||'		) VMG1 '
		||'	WHERE '
		||'		MG2.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD '
		||'		AND MG2.MGR_CD = VMG1.MGR_CD ';
-- 入力パラメータ条件 委託会社コード
IF (trim(both l_inItakuKaishaCd) IS NOT NULL AND (trim(both l_inItakuKaishaCd))::text <> '') THEN
	gSql := gSql	||'		AND MG2.ITAKU_KAISHA_CD = ''' ||l_inItakuKaishaCd || ''' ';
END IF;
-- 業務年月日
IF (trim(both l_inGyomuYmd) IS NOT NULL AND (trim(both l_inGyomuYmd))::text <> '') THEN
	gSql := gSql	||'		AND MG2.RBR_YMD = ''' ||l_inGyomuYmd ||''' ';
END IF;
-- GROUP BY句
gSql := gSql
		||'	GROUP BY '
		||'		MG2.ITAKU_KAISHA_CD, '
		||'		MG2.MGR_CD, '
		||'		VMG1.SAIKEN_SHURUI, '
		||'		MG2.RBR_YMD ';
-- UNION句
gSql := gSql
		||'	UNION '
		||'	SELECT '
		||'		MG3.ITAKU_KAISHA_CD, '
		||'		MG3.MGR_CD, '
		||'		MG3.SHOKAN_YMD, '
		||'		VMG1.SAIKEN_SHURUI, '
		||'		SUM(MG3.MUNIT_SKN_SHR_KNGK) '
		||'	FROM '
		||'		MGR_SHOKIJ MG3, '
		||'		( '
		||'			SELECT * '
		||'			FROM MGR_KIHON_VIEW VMG12 '
		||'			WHERE TRIM(VMG12.ISIN_CD) IS NOT NULL '
		||'			AND VMG12.SHORI_KBN = ''1'' '
		||'			AND VMG12.KK_KANYO_FLG <> ''2'' '
		||'			AND VMG12.JTK_KBN <> ''5'' '
		||'		) VMG1 '
		||'	WHERE '
		||'		MG3.ITAKU_KAISHA_CD = VMG1.ITAKU_KAISHA_CD '
		||'		AND MG3.MGR_CD = VMG1.MGR_CD '
		||'		AND MG3.SHOKAN_KBN NOT IN  (''30'', ''60'') ';
-- 入力パラメータ条件 委託会社コード
IF (trim(both l_inItakuKaishaCd) IS NOT NULL AND (trim(both l_inItakuKaishaCd))::text <> '') THEN
	gSql := gSql	||'		AND MG3.ITAKU_KAISHA_CD = ''' ||l_inItakuKaishaCd || ''' ';
END IF;
-- 業務年月日
IF (trim(both l_inGyomuYmd) IS NOT NULL AND (trim(both l_inGyomuYmd))::text <> '') THEN
	gSql := gSql	||'		AND MG3.SHOKAN_YMD = ''' ||l_inGyomuYmd ||''' ';
END IF;
-- GROUP BY句
gSql := gSql
		||'	GROUP BY '
		||'		MG3.ITAKU_KAISHA_CD, '
		||'		MG3.MGR_CD, '
		||'		VMG1.SAIKEN_SHURUI, '
		||'		MG3.SHOKAN_YMD ';
-- SQL終端部
gSql := gSql
		||') WK1 '
		||'GROUP BY '
		||'	WK1.ITAKU_KAISHA_CD, '
		||'	WK1.MGR_CD, '
		||'	WK1.SHR_YMD, '
		||' WK1.SAIKEN_SHURUI ';
RETURN gSql;
EXCEPTION
WHEN OTHERS THEN
	RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfipi051k00r01_createsql () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipi051k00r01_gethenreijiyuucd (inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE, inMgrCd MGR_SHOKIJ.MGR_CD%TYPE, inShokanKjt MGR_SHOKIJ.SHOKAN_KJT%TYPE, inZndkKijunYmd KIKIN_IDO.ZNDK_KIJUN_YMD%TYPE) RETURNS char AS $body$
DECLARE

	result char(1) := '5';
	CUR_MGR_SHOKIJ CURSOR FOR
		SELECT
			wCNT.NUM,
			MG3.SHOKAN_KBN
		FROM
			MGR_SHOKIJ MG3,
			(SELECT ITAKU_KAISHA_CD, MGR_CD, COUNT(*) AS NUM
				FROM MGR_SHOKIJ
				WHERE SHOKAN_KJT > inZndkKijunYmd
				AND SHOKAN_KJT < inShokanKjt
				AND ITAKU_KAISHA_CD = inItakuKaishaCd
				AND MGR_CD = inMgrCd
				GROUP BY ITAKU_KAISHA_CD, MGR_CD) wCNT
		WHERE MG3.MUNIT_GENSAI_KNGK = (SELECT MAX(MUNIT_GENSAI_KNGK)
										FROM MGR_SHOKIJ
										WHERE SHOKAN_KJT > inZndkKijunYmd
										AND SHOKAN_KJT < inShokanKjt
										AND ITAKU_KAISHA_CD = inItakuKaishaCd
										AND MGR_CD = inMgrCd)
		AND MG3.SHOKAN_KJT > inZndkKijunYmd
		AND MG3.SHOKAN_KJT < inShokanKjt
		AND MG3.ITAKU_KAISHA_CD = inItakuKaishaCd
		AND MG3.MGR_CD = inMgrCd
		AND MG3.ITAKU_KAISHA_CD = wCNT.ITAKU_KAISHA_CD
		AND MG3.MGR_CD = wCNT.MGR_CD
		-- 新株予約、コール、プット、買入、それ以外の順で並べる
 
		ORDER BY CASE WHEN MG3.SHOKAN_KBN=pkIpaKknIdo.CB_KOUSHI() THEN  '1' WHEN MG3.SHOKAN_KBN=pkIpaKknIdo.CALL_ITIBU() THEN  '2' WHEN MG3.SHOKAN_KBN=pkIpaKknIdo.PUT() THEN  '3' WHEN MG3.SHOKAN_KBN=pkIpaKknIdo.KAIIRE_SHOKYAKU() THEN  '4'  ELSE '9' END;
BEGIN
	FOR rec IN CUR_MGR_SHOKIJ LOOP
		IF rec.NUM = 1 THEN
			IF rec.SHOKAN_KBN = pkIpaKknIdo.KAIIRE_SHOKYAKU() THEN
				result := '1';
			ELSIF rec.SHOKAN_KBN = pkIpaKknIdo.CALL_ITIBU() THEN
				result := '3';
			ELSIF rec.SHOKAN_KBN = pkIpaKknIdo.PUT() THEN
				result := '4';
			ELSIF rec.SHOKAN_KBN = pkIpaKknIdo.CB_KOUSHI() THEN
				result := 'A';
			ELSE
				result := '5';
			END IF;
		ELSE
			IF rec.SHOKAN_KBN = pkIpaKknIdo.KAIIRE_SHOKYAKU() THEN
				result := '5';
			ELSIF rec.SHOKAN_KBN = pkIpaKknIdo.CALL_ITIBU() THEN
				result := '6';
			ELSIF rec.SHOKAN_KBN = pkIpaKknIdo.PUT() THEN
				result := '7';
			ELSIF rec.SHOKAN_KBN = pkIpaKknIdo.CB_KOUSHI() THEN
				result := 'B';
			ELSE
				result := '5';
			END IF;
		END IF;
		-- 1件目を呼んだ時点で事由がわかるので、LOOPを抜ける
		RETURN result;
	END LOOP;
	RETURN result;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi051k00r01_gethenreijiyuucd (inItakuKaishaCd MGR_SHOKIJ.ITAKU_KAISHA_CD%TYPE, inMgrCd MGR_SHOKIJ.MGR_CD%TYPE, inShokanKjt MGR_SHOKIJ.SHOKAN_KJT%TYPE, inZndkKijunYmd KIKIN_IDO.ZNDK_KIJUN_YMD%TYPE) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipi051k00r01_gettrunckngk ( inTsukaCd MGR_KIHON.RBR_TSUKA_CD%TYPE, inKngk numeric) RETURNS numeric AS $body$
DECLARE

pTruncKingk numeric := 0;

BEGIN
IF inTsukaCd = 'JPY' THEN
	pTruncKingk := TRUNC(inKngk);
ELSE
	pTruncKingk := TRUNC(inKngk::numeric, 2);
END IF;
RETURN pTruncKingk;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi051k00r01_gettrunckngk ( inTsukaCd MGR_KIHON.RBR_TSUKA_CD%TYPE, inKngk numeric) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfipi051k00r01_insertdatakknhenrei ( l_ItakuKaishaCd KIKIN_HENREI.ITAKU_KAISHA_CD%TYPE,		-- 委託会社コード
 l_MgrCd KIKIN_HENREI.MGR_CD%TYPE,				-- 銘柄コード
 l_TsukaCd KIKIN_HENREI.TSUKA_CD%TYPE,				-- 通貨コード
 l_HenreiJiyuuCd KIKIN_HENREI.HENREI_JIYUU_CD%TYPE,		-- 返戻事由コード
 l_ShokanKjt KIKIN_HENREI.RBR_KJT%TYPE,				-- 利払期日
 l_ShokanYmd KIKIN_HENREI.RBR_YMD%TYPE,				-- 利払日
 l_GnrKbn KIKIN_HENREI.GNR_KBN%TYPE,				-- 元利区分
 l_HnrKngkGoukei KIKIN_HENREI.HENREI_KNGK%TYPE,			-- 返戻金額
 l_TesuBunbo KIKIN_HENREI.SHR_TESU_BUNBO%TYPE,		-- 支払手数料率(分母)
 l_TesuBunshi KIKIN_HENREI.SHR_TESU_BUNSHI%TYPE,		-- 支払手数料率(分子)
 l_HnrKngkTesu KIKIN_HENREI.SHR_TESU_KNGK%TYPE,		-- 支払手数料
 l_HnrKngkTesuZei KIKIN_HENREI.SHR_TESU_SZEI%TYPE,		-- 支払手数料消費税
 l_inUserId KIKIN_HENREI.SAKUSEI_ID%TYPE 			-- ユーザID
 ) AS $body$
BEGIN
	INSERT INTO KIKIN_HENREI(ITAKU_KAISHA_CD,			-- 委託会社コード
		 MGR_CD,					-- 銘柄コード
		 TSUKA_CD,					-- 通貨コード
		 HENREI_JIYUU_CD,			-- 返戻事由コード
		 RBR_KJT,					-- 利払期日
		 RBR_YMD,					-- 利払日
		 GNR_KBN,					-- 元利区分
		 HENREI_KNGK,				-- 返戻金額
		 SHR_TESU_BUNBO,			-- 支払手数料率(分母)
		 SHR_TESU_BUNSHI,			-- 支払手数料率(分子)
		 SHR_TESU_KNGK,				-- 支払手数料
		 SHR_TESU_SZEI,				-- 支払手数料消費税
		 GROUP_ID,					-- グループID
		 SHORI_KBN,					-- 処理区分
		 LAST_TEISEI_ID,			-- 最終訂正者
		 SHONIN_ID,					-- 承認者
		 KOUSIN_ID,					-- 更新者
		 SAKUSEI_ID)				-- 作成者
	VALUES (l_ItakuKaishaCd,			-- 委託会社コード
		 l_MgrCd,					-- 銘柄コード
		 l_TsukaCd,					-- 通貨コード
		 l_HenreiJiyuuCd,			-- 返戻事由コード
		 l_ShokanKjt,				-- 利払期日
		 l_ShokanYmd,				-- 利払日
		 l_GnrKbn,					-- 元利区分
		 l_HnrKngkGoukei,			-- 返戻金額
		 l_TesuBunbo,				-- 支払手数料率(分母)
		 l_TesuBunshi,				-- 支払手数料率(分子)
		 l_HnrKngkTesu,				-- 支払手数料
		 l_HnrKngkTesuZei,			-- 支払手数料消費税
		 ' ',						-- グループID.
		 '0',						-- 処理区分.
		 l_inUserId,				-- 最終訂正者
		 ' ',						-- 承認者
		 l_inUserId,				-- 更新者
		 l_inUserId 					-- 作成者
		);
	RETURN;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfipi051k00r01_insertdatakknhenrei ( l_ItakuKaishaCd KIKIN_HENREI.ITAKU_KAISHA_CD%TYPE, l_MgrCd KIKIN_HENREI.MGR_CD%TYPE, l_TsukaCd KIKIN_HENREI.TSUKA_CD%TYPE, l_HenreiJiyuuCd KIKIN_HENREI.HENREI_JIYUU_CD%TYPE, l_ShokanKjt KIKIN_HENREI.RBR_KJT%TYPE, l_ShokanYmd KIKIN_HENREI.RBR_YMD%TYPE, l_GnrKbn KIKIN_HENREI.GNR_KBN%TYPE, l_HnrKngkGoukei KIKIN_HENREI.HENREI_KNGK%TYPE, l_TesuBunbo KIKIN_HENREI.SHR_TESU_BUNBO%TYPE, l_TesuBunshi KIKIN_HENREI.SHR_TESU_BUNSHI%TYPE, l_HnrKngkTesu KIKIN_HENREI.SHR_TESU_KNGK%TYPE, l_HnrKngkTesuZei KIKIN_HENREI.SHR_TESU_SZEI%TYPE, l_inUserId KIKIN_HENREI.SAKUSEI_ID%TYPE  ) FROM PUBLIC;





CREATE OR REPLACE PROCEDURE sfipi051k00r01_insertdatakknido ( l_ItakuKaishaCd KIKIN_IDO.ITAKU_KAISHA_CD%TYPE,			-- 委託会社コード
 l_MgrCd KIKIN_IDO.MGR_CD%TYPE,					-- 銘柄コード
 l_ShokanKjt KIKIN_IDO.RBR_KJT%TYPE,					-- 利払期日
 l_ShokanYmd KIKIN_IDO.RBR_YMD%TYPE,					-- 利払日
 l_InsTesuTsukaCd KIKIN_IDO.TSUKA_CD%TYPE,				-- 通貨コード
 l_NextYmd10 KIKIN_IDO.IDO_YMD%TYPE,					-- 異動年月日
 l_HenreiJiyuuCd KIKIN_IDO.KKN_IDO_KBN%TYPE,				-- 基金異動区分
 l_KknbillShurui KIKIN_IDO.KKNBILL_SHURUI%TYPE,			-- 基金請求種類
 l_HnrKngkGoukei KIKIN_IDO.KKN_SHUKIN_KNGK%TYPE,			-- 基金出金額
 l_KijunZndk KIKIN_IDO.KIJUN_ZNDK%TYPE,				-- 基準残高
 l_inUserId KIKIN_IDO.SAKUSEI_ID%TYPE 				-- ユーザID
 ) AS $body$
BEGIN
		INSERT INTO KIKIN_IDO(ITAKU_KAISHA_CD,			-- 委託会社コード
			 MGR_CD,					-- 銘柄コード
			 RBR_KJT,					-- 利払期日
			 RBR_YMD,					-- 利払日
			 TSUKA_CD,					-- 通貨コード
			 IDO_YMD,					-- 異動年月日
			 KKN_IDO_KBN,				-- 基金異動区分
			 KKNBILL_SHURUI,			-- 基金請求種類
			 KKN_NYUKIN_KNGK,			-- 基金入金額
			 KKN_SHUKIN_KNGK,			-- 基金出金額
			 KKMEMBER_FS_KBN,			-- 金融証券区分(機構加入者)
			 KKMEMBER_BCD,				-- 金融機関コード(機構加入者)
			 KKMEMBER_KKBN,				-- 口座区分(機構加入者)
			 NYUKIN_KAKUNIN_YMD,		-- 入金確認日
			 NYUKIN_STS_KBN,			-- 入金状況区分
			 DATA_SAKUSEI_KBN,			-- データ作成区分
			 ZNDK_KIJUN_YMD,			-- 残高基準日
			 KIJUN_ZNDK,				-- 基準残高
			 EB_MAKE_YMD,				-- EB作成年月日
			 EB_SEND_YMD,				-- EB送信年月日
			 GROUP_ID,					-- グループID
			 SHORI_KBN,					-- 処理区分
			 LAST_TEISEI_ID,			-- 最終訂正者
			 SHONIN_ID,					-- 承認者
			 KOUSIN_ID,					-- 更新者
			 SAKUSEI_ID)				-- 作成者
		VALUES (l_ItakuKaishaCd,			-- 委託会社コード
			 l_MgrCd,					-- 銘柄コード
			 l_ShokanKjt,				-- 利払期日
			 l_ShokanYmd,				-- 利払日
			 l_InsTesuTsukaCd,			-- 通貨コード
			 l_NextYmd10,				-- 異動年月日
			 l_HenreiJiyuuCd,			-- 基金異動区分
			 l_KknbillShurui,			-- 基金請求種類
			 0,							-- 基金入金額.
			 l_HnrKngkGoukei,			-- 基金出金額
			 ' ',						-- 金融証券区分(機構加入者).
			 ' ',						-- 金融機関コード(機構加入者).
			 ' ',						-- 口座区分(機構加入者).
			 ' ',						-- 入金確認日.
			 ' ',						-- 入金状況区分.
			 '1',						-- データ作成区分.
			 ' ',						-- 残高基準日.
			 l_KijunZndk,				-- 基準残高
			 ' ',						-- EB作成年月日.
			 ' ',						-- EB送信年月日.
			 ' ',						-- グループID.
			 '0',						-- 処理区分.
			 l_inUserId,				-- 最終訂正者
			 ' ',						-- 承認者
			 l_inUserId,				-- 更新者
			 l_inUserId 					-- 作成者
			);
	RETURN;
END;

$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON PROCEDURE sfipi051k00r01_insertdatakknido ( l_ItakuKaishaCd KIKIN_IDO.ITAKU_KAISHA_CD%TYPE, l_MgrCd KIKIN_IDO.MGR_CD%TYPE, l_ShokanKjt KIKIN_IDO.RBR_KJT%TYPE, l_ShokanYmd KIKIN_IDO.RBR_YMD%TYPE, l_InsTesuTsukaCd KIKIN_IDO.TSUKA_CD%TYPE, l_NextYmd10 KIKIN_IDO.IDO_YMD%TYPE, l_HenreiJiyuuCd KIKIN_IDO.KKN_IDO_KBN%TYPE, l_KknbillShurui KIKIN_IDO.KKNBILL_SHURUI%TYPE, l_HnrKngkGoukei KIKIN_IDO.KKN_SHUKIN_KNGK%TYPE, l_KijunZndk KIKIN_IDO.KIJUN_ZNDK%TYPE, l_inUserId KIKIN_IDO.SAKUSEI_ID%TYPE  ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipi051k00r01_setrkntesuryo ( gItakuKaishaCd text, -- 委託会社コード
 gMgrCd text  -- 銘柄コード
 ) RETURNS sfipi051k00r01_tesuryo_result AS $body$
DECLARE
	v_result sfipi051k00r01_tesuryo_result;
	v_bunbo numeric;
	v_bunshi decimal(17,14);
	v_szei char(1);
	v_tesu char(2);
BEGIN
SELECT
	coalesce(MG8.RKN_SHR_TESU_BUNBO, 0),
	coalesce(MG8.RKN_SHR_TESU_BUNSHI, 0),
	coalesce(trim(both MG8.SZEI_SEIKYU_KBN), '0'),
	trim(both MG7.TESU_SHURUI_CD)
INTO STRICT
	v_bunbo, -- 支払手数料分母
	v_bunshi, -- 支払手数料分子
	v_szei,	 -- 消費税請求区分
	v_tesu  --手数料種類コード
FROM
	MGR_TESURYO_PRM MG8,
	MGR_TESURYO_CTL MG7
WHERE
	MG8.ITAKU_KAISHA_CD = gItakuKaishaCd
	AND MG8.MGR_CD = gMgrCd
	AND MG7.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD
	AND MG7.MGR_CD = MG8.MGR_CD
	AND MG7.TESU_SHURUI_CD IN ('61','82')
	AND MG7.CHOOSE_FLG = '1';
	
v_result.result_code := pkconstant.success();
v_result.gGnknShrTesuBunbo := v_bunbo;
v_result.gGnknShrTesuBunshi := v_bunshi;
v_result.gSzeiSeikyuKbn := v_szei;
v_result.gTesuShuruiCd := v_tesu;
RETURN v_result;

EXCEPTION
	WHEN no_data_found THEN
		v_result.result_code := 2; -- DB_NO_DATA_FOUND
		RETURN v_result;
	WHEN OTHERS THEN
		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipi051k00r01_setrkntesuryo ( gItakuKaishaCd MGR_RBRKIJ.ITAKU_KAISHA_CD%TYPE, gMgrCd MGR_RBRKIJ.MGR_CD%TYPE  ) FROM PUBLIC;