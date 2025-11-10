


DROP TYPE IF EXISTS sfiph007k00r01_type_rec_header;
CREATE TYPE sfiph007k00r01_type_rec_header AS (
		ITAKU_KAISHA_CD		char(4),
		HKT_CD				char(6),						-- 発行体コード
		KAIKEI_KBN			char(2),		-- 会計区分
		KAIKEI_KBN_RNM		varchar(70),	-- 会計区分略称
		KOUSAIHI_FLG		char(1)										-- 公債費フラグ
	);
DROP TYPE IF EXISTS sfiph007k00r01_type_rec_meisai;
CREATE TYPE sfiph007k00r01_type_rec_meisai AS (
		HKT_CD					char(6),	-- 発行体コード
		HKT_RNM					varchar(40),	-- 発行体略称
		GNR_YMD					char(8),
		CHOKYU_YMD				char(8),
		ISIN_CD					char(12),
		MGR_CD					varchar(13),
		MGR_RNM					varchar(44),
		KAIKEI_KBN				char(2),		-- 会計区分
		KAIKEI_KBN_RNM			varchar(20),	-- 会計区分略称
		GANKIN					varchar(100),	-- 元金
		RKN						varchar(100),	-- 利金
		GNKN_SHR_TESU_KNGK		varchar(100),	-- 元金支払手数料
		RKN_SHR_TESU_KNGK		varchar(100),	-- 利金支払手数料
		GNT_GNKN				varchar(100),	-- 現登債元金
		GNT_RKN					varchar(100),	-- 現登債利金
		GNT_GNKN_SHR_TESU_KNGK	varchar(100),	-- 現登債元金手数料
		GNT_RKN_SHR_TESU_KNGK	varchar(100),	-- 現登債利金手数料
		SEIKYU_KNGK				varchar(100),	-- 請求金額
		SZEI_KNGK				varchar(100),	-- 消費税金額
		KOUSAIHI_FLG			varchar(100)	-- 公社債フラグ
	);
DROP TYPE IF EXISTS sfiph007k00r01_type_rec_kbn_total;
CREATE TYPE sfiph007k00r01_type_rec_kbn_total AS (
		HKT_CD					char(6),	-- 発行体コード
		HKT_RNM					varchar(40),	-- 発行体略称
		KAIKEI_KBN				char(2),		-- 会計区分
		KAIKEI_KBN_RNM			varchar(20),	-- 会計区分略称
		GANKIN					varchar(100),	-- 元金
		RKN						varchar(100),	-- 利金
		GNKN_SHR_TESU_KNGK		varchar(100),	-- 元金支払手数料
		RKN_SHR_TESU_KNGK		varchar(100),	-- 利金支払手数料
		GNT_GNKN				varchar(100),	-- 現登債元金
		GNT_RKN					varchar(100),	-- 現登債利金
		GNT_GNKN_SHR_TESU_KNGK	varchar(100),	-- 現登債元金手数料
		GNT_RKN_SHR_TESU_KNGK	varchar(100),	-- 現登債利金手数料
		SEIKYU_KNGK				varchar(100),	-- 請求金額
		SZEI_KNGK				varchar(100),	-- 消費税金額
		KOUSAIHI_FLG			varchar(100)	-- 公社債フラグ
	);


CREATE OR REPLACE FUNCTION sfiph007k00r01 ( l_inItakuKaishaCd MGR_KIHON.ITAKU_KAISHA_CD%TYPE,	-- 委託会社コード
 l_inUserId MGR_KIHON.LAST_TEISEI_ID%TYPE,	-- ユーザーID
 l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE,		-- 帳票区分
 l_inGyomuYmd SREPORT_WK.SAKUSEI_YMD%TYPE,		-- 業務日付
 l_inKjnYmdFrom MGR_KIHON.HAKKO_YMD%TYPE,		-- 基準日From
 l_inKjnYmdTo MGR_KIHON.HAKKO_YMD%TYPE,		-- 基準日To
 l_inHktCd MGR_KIHON.HKT_CD%TYPE,			-- 発行体コード
 l_inMgrCd MGR_KIHON.MGR_CD%TYPE,			-- 銘柄コード
 l_inIsinCd MGR_KIHON.ISIN_CD%TYPE 			-- ISINコード
 ) RETURNS numeric AS $body$
DECLARE
	RTN_OK CONSTANT integer := 0;
	RTN_NG CONSTANT integer := 1;
	RTN_NODATA CONSTANT integer := 2;
	RTN_FATAL CONSTANT integer := 99;
	tmpRecHeader sfiph007k00r01_type_rec_header;
	tmpRecMeisai sfiph007k00r01_type_rec_meisai;

--
-- * 著作権: COPYRIGHT (C) 2005
-- * 会社名: JIP
-- *
-- * 公債会計別元利払基金・手数料（振替債・現登債）データの作成（CSV）
-- *
-- * @author 山下　健太(NOA)
-- * @version $Id: SFIPH007K00R01.SQL,v 1.18 2020/03/12 05:58:17 fujii Exp $
-- 
--****************************************************************************************************
--    定数定義                                                                                        
--****************************************************************************************************
	C_BLOCK_MAX		CONSTANT integer := 17;	-- 会計区分の最大ブロック数(の最大配列= C_BLOCK_MAX + 1)
--****************************************************************************************************
--    変数定義                                                                                        
--****************************************************************************************************
	errmsg			varchar(50) := NULL;		-- エラーメッセージ
	l_befKaikaiKbn	char(2) := '00';			-- 会計区分判定用
	flgkosaihi		varchar(1) := NULL;		-- 公債費フラグのマーク
	flgRowCng		integer := 0;				-- 行チェンジフラグ
	l_gyomuYmd		char(8) := NULL;			-- 業務日付
	-- 基準日From - To
	l_kjnYmdFrom	MGR_KIHON.HAKKO_YMD%TYPE := NULL;
	l_kjnYmdTo		MGR_KIHON.HAKKO_YMD%TYPE := NULL;
	-- レコードカウント
	recCntN			integer := 0;
	recCntH			integer := 0;	-- ヘッダ用
	recCntM			integer := 0;	-- 明細用
	recCntOut		integer := 0;	-- 出力用
	recCntMax		integer := 0;	-- 出力用最大値
	colCnt			integer := 0;	-- 列カウント
	colCntTmp		integer := 0;
	rowNo			integer := 0;	-- 行番号(発行体ごとにブレイク)
	-- 横罫金額の総合計（明細行 合計列用）
	l_allKngk			numeric := 0;	-- 総合計
	l_allGknKngk		numeric := 0;	-- 元金金額総合計
	l_allRknKngk		numeric := 0;	-- 利金額総合計
	l_allGnkTesuKngk	numeric := 0;	-- 元金支払手数料総合計
	l_allRknTesuKngk	numeric := 0;	-- 利金支払手数料総合計
	-- 横罫金額の振替債合計(合計行用)
	l_allFrkGknKngk		numeric := 0;	-- 元金金額振替債合計
	l_allFrkRknKngk		numeric := 0;	-- 利金額振替債合計
	l_allFrkGnkTesuKngk	numeric := 0;	-- 元金支払手数料振替債合計
	l_allFrkRknTesuKngk	numeric := 0;	-- 利金支払手数料振替債合計
	-- 横罫金額の現登債合計（合計行用）
	l_allGntGknKngk		numeric := 0;	-- 元金金額現登債合計
	l_allGntRknKngk		numeric := 0;	-- 利金額現登債合計
	l_allGntGnkTesuKngk	numeric := 0;	-- 元金支払手数料現登債合計
	l_allGntRknTesuKngk	numeric := 0;	-- 利金支払手数料現登債合計
	-- SQL編集
	l_sqlH			varchar(4000); -- ヘッダ用
	l_sqlM			varchar(4000); -- 明細用
	l_sqlKT			varchar(4000); -- 会計区分合計用（横罫合計）
	l_sqlMT			varchar(4000); -- 銘柄合計用（縦罫合計）
	l_sqlInsC		varchar(4000); -- Insert用固定部分
	-- 出力文字列(会計区分別)
	TYPE SFIPH007K00R01_VCR_ARRAY10K IS TABLE OF varchar(10000) INDEX BY integer;
	l_outstr SFIPH007K00R01_VCR_ARRAY10K;
	-- 合計行出力用一時文字列
	l_tmpstr		varchar(10000);
	-- 出力行のヘッダフラグ
	TYPE SFIPH007K00R01_CHR_ARRAY01 IS TABLE OF char(1) INDEX BY integer;
	l_outHeaderFlg SFIPH007K00R01_CHR_ARRAY01;
	-- 発行体ごとの会計区分列のコレクション
	TYPE SFIPH007K00R01_CHR_ARRAY2 IS TABLE OF char(2)        INDEX BY integer;
	l_kaikeiKbnArr SFIPH007K00R01_CHR_ARRAY2;
	l_kaikeiKbnIdx	integer;	-- Index
	-- カーソル
	TYPE SFIPH007K00R01_CURSOR_TYPE 	-- Index
	-- カーソル
	TYPE CURSOR_TYPE REFCURSOR;
	curRecH SFIPH007K00R01_CURSOR_TYPE; -- ヘッダ用
	curRecM SFIPH007K00R01_CURSOR_TYPE; -- 明細用
	curRecKT SFIPH007K00R01_CURSOR_TYPE; -- 会計区分合計用（横罫合計）
	curRecMT SFIPH007K00R01_CURSOR_TYPE; -- 銘柄合計用（縦罫合計）
	-- デバッグログ用
--	debugStrLength	INTEGER DEFAULT 1;		-- テスト用に出力する時だけコメントを外してください。
--****************************************************************************************************
--    カーソル定義                                                                                    
--****************************************************************************************************
	------------------------------------------------------------------------------------
	-- レコードヘッダ用　タイプ宣言
	TYPE SFIPH007K00R01_TYPE_TBL_REC_HEADER IS TABLE OF TYPE_REC_HEADER INDEX BY integer;
	-- レコードヘッダ
	recHeader SFIPH007K00R01_TYPE_TBL_REC_HEADER;
	------------------------------------------------------------------------------------
	-- レコード明細用　タイプ宣言
	TYPE SFIPH007K00R01_TYPE_TBL_REC_MEISAI IS TABLE OF TYPE_REC_MEISAI INDEX BY integer;
	-- レコード明細
	recMeisai SFIPH007K00R01_TYPE_TBL_REC_MEISAI;
	------------------------------------------------------------------------------------
	-- レコード合計行用　タイプ宣言（縦罫合計用）
	-- 会計区分ごとの合計レコード
	recKbnTotal SFIPH007K00R01_TYPE_REC_KBN_TOTAL;
	------------------------------------------------------------------------------------
	-- レコード合計列用　タイプ宣言（横罫合計用）
	-- タイプ宣言は、明細と共用 
	-- 銘柄、徴求日単位ごとの合計レコード
	recMgrTotal SFIPH007K00R01_TYPE_REC_MEISAI
--****************************************************************************************************
--    メイン処理                                                                                      
--****************************************************************************************************
BEGIN
	--** パラメータチェック ***********************************************
	-- 基準日From-Toをセット
	l_kjnYmdFrom	:= l_inKjnYmdFrom;
	l_kjnYmdTo		:= l_inKjnYmdTo;
	-- 入力チェック
	IF coalesce(trim(both l_kjnYmdFrom)::text, '') = '' THEN
		l_kjnYmdFrom := '00000000';
	END IF;
	IF coalesce(trim(both l_kjnYmdTo)::text, '') = '' THEN
		l_kjnYmdTo   := '99999999';
	END IF;
	IF coalesce(trim(both l_inItakuKaishaCd)::text, '') = '' THEN
		errmsg := '委託会社コードが未入力です。';
		-- CALL PKLOG.ERROR('ECM701','SFIPH007K00R01','エラーメッセージ：' || errmsg);
		RETURN RTN_NG;
	END IF;
	--** ヘッダ用カーソル作成 ***********************************************
	l_sqlH := SFIPH007K00R01_createSqlHeader(l_kjnYmdFrom,
							  l_kjnYmdTo,
							  l_inHktCd,
							  l_inMgrCd,
							  l_inIsinCd,
							  l_inItakuKaishaCd
							  );
	recCntH := 0;
	--** カーソルオープン ***************************************************
	OPEN curRecH FOR EXECUTE l_sqlH;
	LOOP
		-- ヘッダデータを格納
		FETCH curRecH INTO
			recHeader[recCntH);
		-- データが無くなったらループを抜ける
		EXIT WHEN NOT FOUND;/* apply on curRecH */
		IF recHeader[recCntH].KAIKEI_KBN = '00' THEN
			recHeader[recCntH].KAIKEI_KBN_RNM := '公債費特別会計';
		END IF;
		recCntH := recCntH + 1;
	END LOOP;
	-- 最終行の次行判定用ヘッダ配列の初期化
	recHeader[recCntH].ITAKU_KAISHA_CD := '';
	recHeader[recCntH].HKT_CD := '';
	recHeader[recCntH].KAIKEI_KBN := '';
	recHeader[recCntH].KAIKEI_KBN_RNM := '';
	recHeader[recCntH].KOUSAIHI_FLG := '';
	-- 出力カウンタ初期化
	recCntOut := -1;
	--** 取得レコードの編集 ************************************************
	FOR recCntN IN 0..recCntH - 1 LOOP
		-- タイトル列の名前をセットする
		IF flgRowCng = 0 THEN
			-- 会計区分配列の初期化(最大30までシステム上登録可能だが、DL可能は「C_BLOCK_MAX + 1 会計区分」まで)
			FOR l_kaikeiKbnIdx IN 0..30 LOOP
				l_kaikeiKbnArr[l_kaikeiKbnIdx) := '';
			END LOOP;
			l_kaikeiKbnIdx := 0;
			recCntOut := recCntOut + 1; -- 出力行カウント
			l_outstr[recCntOut) := '''No'',''発行体コード'',''発行体名称'',''徴求日'',''ISINコード'',''元利払日'',''銘柄名称'''
			-- 総合計列タイトル
								|| ',''元金合計'',''利金合計'',''元金手数料合計'',''利金手数料合計'',''総合計'''
			-- 振替債・現登債合計列タイトル
								|| ',''振替債元金合計'',''利金合計'',''元金手数料合計'',''利金手数料合計'',''現登債元金合計'',''利金合計'',''元金手数料合計'',''利金手数料合計''';
			flgRowCng := 1;	-- 行切替フラグ
			colCnt := 0;				-- 列カウント
			-- 行番号の初期化
			rowNo := 0;
		END IF;
		-- 会計区分が最大ブロック数以上(=C_BLOCK_MAX + 1 列)の場合は、DLしない為無視する
		IF colCnt <= C_BLOCK_MAX THEN
			-- 会計区分が存在する場合
			l_outstr[recCntOut) := l_outstr[recCntOut) || ',''' || recHeader[recCntN].KAIKEI_KBN_RNM || '元金''';
			l_outstr[recCntOut) := l_outstr[recCntOut) || ',''利金''';
			l_outstr[recCntOut) := l_outstr[recCntOut) || ',''元金支払手数料''';
			l_outstr[recCntOut) := l_outstr[recCntOut) || ',''利金支払手数料''';
			l_outstr[recCntOut) := l_outstr[recCntOut) || ',''現登債元金''';
			l_outstr[recCntOut) := l_outstr[recCntOut) || ',''現登債利金''';
			l_outstr[recCntOut) := l_outstr[recCntOut) || ',''現登債元金支払手数料''';
			l_outstr[recCntOut) := l_outstr[recCntOut) || ',''現登債利金支払手数料''';
			l_outstr[recCntOut) := l_outstr[recCntOut) || ',''請求額''';
			l_outstr[recCntOut) := l_outstr[recCntOut) || ',''消費税金額''';
			-- ヘッダフラグに「ヘッダ行(=1)」をセット
			l_outHeaderFlg[recCntOut) := '1';
			-- 会計区分をセット(明細レコードをセットする判定用)
			l_kaikeiKbnArr[l_kaikeiKbnIdx) := recHeader[recCntN].KAIKEI_KBN;
			l_kaikeiKbnIdx := l_kaikeiKbnIdx + 1;
		END IF;
		colCnt	  := colCnt + 1;	-- 列カウント
		--タイトル行が取得データの最終行だった場合
		IF recCntN = recCntH - 1 THEN
			recCntH := recCntN;
		END IF;
		-- 発行体が変わるか、公債費フラグが変わる場合(列名のセットが完了したので)、明細レコードを出力する
		IF (recCntN > 0
				AND ((recHeader[recCntN].HKT_CD <> recHeader[recCntN + 1].HKT_CD)
					OR (recHeader[recCntN].KOUSAIHI_FLG <> recHeader[recCntN + 1].KOUSAIHI_FLG))
			OR recCntN = recCntH
			) THEN
			-- データが存在しないタイトル列は空をセット（会計区分は最大C_BLOCK_MAX + 1ブロック）
			FOR colCntTmp IN colCnt..C_BLOCK_MAX LOOP
				-- 会計区分の有無により、列に０またはNULLをセット
				l_outstr[recCntOut) := l_outstr[recCntOut) || SFIPH007K00R01_setNodataKaikeiKbn(l_kaikeiKbnIdx,colCntTmp);
			END LOOP;
			colCnt := 0;				-- 列カウント
			flgRowCng := 0;				-- 行切替フラグ
			-- 明細行カウント初期化
			recCntM := 0;
			-- 明細用カーソル作成 
			l_sqlM := SFIPH007K00R01_createSqlMeisai(	l_kjnYmdFrom,
										l_kjnYmdTo,
										'',	-- 元利払日(明細取得時は不要)
										recHeader[recCntN].HKT_CD,
										l_inMgrCd,
										l_inIsinCd,
										l_inItakuKaishaCd,
										recHeader[recCntN].KOUSAIHI_FLG,	-- 公債費フラグ
										'0'	-- 明細行を取得
										);
			OPEN curRecM FOR EXECUTE l_sqlM;
			LOOP
				-- 明細データを格納
				FETCH curRecM INTO	recMeisai[recCntM);
				IF NOT FOUND THEN
					-- 対象銘柄の会計区分が無くなった場合、残りフィールドに空をセット（会計区分は最大C_BLOCK_MAX + 1 ブロック）
					FOR colCntTmp IN colCnt..C_BLOCK_MAX LOOP
						-- 会計区分の有無により、列に０またはNULLをセット
						l_outstr[recCntOut) := l_outstr[recCntOut) || SFIPH007K00R01_setNodataKaikeiKbn(l_kaikeiKbnIdx,colCntTmp);
					END LOOP;
					colCnt	  := 0;				-- 列カウント
				END IF;
				EXIT WHEN NOT FOUND;/* apply on curRecM */
				IF recCntM > 0 THEN
					-- 開始行以外でレコードが切り替わったら、改行
					IF     recMeisai[recCntM].CHOKYU_YMD <> recMeisai[recCntM - 1].CHOKYU_YMD
						OR recMeisai[recCntM].GNR_YMD    <> recMeisai[recCntM - 1].GNR_YMD
						OR recMeisai[recCntM].ISIN_CD    <> recMeisai[recCntM - 1].ISIN_CD
						OR recMeisai[recCntM].MGR_CD     <> recMeisai[recCntM - 1].MGR_CD THEN
						-- 改行する条件になったら、残りの空いている列に空をセットする（会計区分は最大C_BLOCK_MAX + 1 ブロック）
						FOR colCntTmp IN colCnt..C_BLOCK_MAX LOOP
							-- 会計区分の有無により、列に０またはNULLをセット
							l_outstr[recCntOut) := l_outstr[recCntOut) || SFIPH007K00R01_setNodataKaikeiKbn(l_kaikeiKbnIdx,colCntTmp);
						END LOOP;
						colCnt	  := 0;				-- 列カウント
						flgRowCng := 0;				-- 行切替フラグ
					END IF;
				END IF;
				-- 改行直後にセット
				IF flgRowCng = 0 THEN
					recCntOut := recCntOut + 1; -- 出力行カウント
					rowNo := rowNo + 1;			-- 行番号(発行体ごとにリセットする番号)
					-- ヘッダフラグに「明細行(=0)」をセット
					l_outHeaderFlg[recCntOut) := '0';
					l_outstr[recCntOut) := '''' ||	rowNo	|| ''','''||						-- 行番号
													recMeisai[recCntM].HKT_CD ||''','''||		-- 発行体コード
													recMeisai[recCntM].HKT_RNM ||''','''||		-- 発行体名称
													recMeisai[recCntM].CHOKYU_YMD ||''','''||	-- 徴求日
													recMeisai[recCntM].ISIN_CD ||''','''||		-- ISINコード
													recMeisai[recCntM].GNR_YMD ||''','''||		-- 元利払日
													recMeisai[recCntM].MGR_RNM ||'''';			-- 銘柄名称
					--************** 横罫の合計列を出力 **************
					-- 銘柄・徴求日単位合計列用カーソル作成 
					l_sqlMT := SFIPH007K00R01_createSqlMeisai(	recMeisai[recCntM].CHOKYU_YMD,
												recMeisai[recCntM].CHOKYU_YMD,
												recMeisai[recCntM].GNR_YMD,	-- 元利払日
												recMeisai[recCntM].HKT_CD,
												recMeisai[recCntM].MGR_CD ,
												'',	-- ISINコード（取得した銘柄コードを指定しているため不要）
												l_inItakuKaishaCd,
												recHeader[recCntN].KOUSAIHI_FLG,	-- 公債費フラグ
												'0'	-- 明細レコードを取得し、後のループで銘柄・徴求日合計列レコード(横罫合計)を集計
												);
					-- 合計金額初期化
					l_allFrkGknKngk		:=	0;
					l_allFrkRknKngk		:=	0;
					l_allFrkGnkTesuKngk	:=	0;
					l_allFrkRknTesuKngk	:=	0;
					l_allGntGknKngk		:=	0;
					l_allGntRknKngk		:=	0;
					l_allGntGnkTesuKngk	:=	0;
					l_allGntRknTesuKngk	:=	0;
					l_allKngk			:=	0;
					l_allGknKngk		:=	0;
					l_allRknKngk		:=	0;
					l_allGnkTesuKngk	:=	0;
					l_allRknTesuKngk	:=	0;
					OPEN curRecMT FOR EXECUTE l_sqlMT;
					LOOP
						-- 合計列データを格納
						FETCH curRecMT INTO	recMgrTotal;
						EXIT WHEN NOT FOUND;/* apply on curRecMT */
						-- 公債費特別会計は合計金額に加算しない(それ以外は非表示の列も含むためにタイトル列の会計区分に関係なく全て加算する)
						IF recMgrTotal.KAIKEI_KBN <> '00' THEN
							-- 振替債
							l_allFrkGknKngk		:=	l_allFrkGknKngk		+	recMgrTotal.GANKIN					;
							l_allFrkRknKngk		:=	l_allFrkRknKngk		+	recMgrTotal.RKN						;
							l_allFrkGnkTesuKngk	:=	l_allFrkGnkTesuKngk	+	recMgrTotal.GNKN_SHR_TESU_KNGK		;
							l_allFrkRknTesuKngk	:=	l_allFrkRknTesuKngk	+	recMgrTotal.RKN_SHR_TESU_KNGK		;
							-- 現登債
							l_allGntGknKngk		:=	l_allGntGknKngk		+	recMgrTotal.GNT_GNKN				;
							l_allGntRknKngk		:=	l_allGntRknKngk		+	recMgrTotal.GNT_RKN					;
							l_allGntGnkTesuKngk	:=	l_allGntGnkTesuKngk	+	recMgrTotal.GNT_GNKN_SHR_TESU_KNGK	;
							l_allGntRknTesuKngk	:=	l_allGntRknTesuKngk	+	recMgrTotal.GNT_RKN_SHR_TESU_KNGK	;
						END IF;
					END LOOP;
					-- 総合計
					l_allGknKngk		:=	l_allFrkGknKngk		+	l_allGntGknKngk;
					l_allRknKngk		:=	l_allFrkRknKngk		+	l_allGntRknKngk;
					l_allGnkTesuKngk	:=	l_allFrkGnkTesuKngk	+	l_allGntGnkTesuKngk;
					l_allRknTesuKngk	:=	l_allFrkRknTesuKngk	+	l_allGntRknTesuKngk;
					l_allKngk			:=	l_allGknKngk + l_allRknKngk + l_allGnkTesuKngk + l_allRknTesuKngk;
					l_outstr[recCntOut) :=	l_outstr[recCntOut)	|| ','''||
											-- 総合計のブロック
											l_allGknKngk		||''','''||	-- 元金総合計
											l_allRknKngk		||''','''||	-- 利金総合計
											l_allGnkTesuKngk	||''','''||	-- 元金手数料総合計
											l_allRknTesuKngk 	||''','''||	-- 利金手数料総合計
											l_allKngk			||''','''||	-- 請求金額総合計
											-- 振替債の合計
											l_allFrkGknKngk		||''','''||	-- 振替債元金
											l_allFrkRknKngk		||''','''||	-- 振替債利金
											l_allFrkGnkTesuKngk	||''','''||	-- 振替債元金支払手数料
											l_allFrkRknTesuKngk	||''','''||	-- 振替債利金支払手数料
											-- 現登債の合計
											l_allGntGknKngk		||''','''||	-- 現登債元金
											l_allGntRknKngk		||''','''||	-- 現登債利金
											l_allGntGnkTesuKngk	||''','''||	-- 現登債元金支払手数料
											l_allGntRknTesuKngk	||'''';		-- 現登債利金支払手数料
				 	flgRowCng := 1;	-- 行切替フラグ
				END IF;
				-- 会計区分がタイトル列と一致する列を検索
				LOOP
					-- 一致したらデータセットして列セット用のループを抜ける
					IF l_kaikeiKbnArr[colCnt) = recMeisai[recCntM].KAIKEI_KBN THEN
						-- 公債費フラグONの会計区分には、金額の先頭に「*」を付加する（…ように、すぐできるようにしておく）
--						SELECT DECODE(recMeisai[recCntM).KOUSAIHI_FLG,'0','','1','*') INTO flgkosaihi FROM DUAL;
						l_outstr[recCntOut) := l_outstr[recCntOut) || ',''' || flgkosaihi || recMeisai[recCntM].GANKIN                  || '''';
						l_outstr[recCntOut) := l_outstr[recCntOut) || ',''' || flgkosaihi ||  recMeisai[recCntM].RKN                     || '''';
						l_outstr[recCntOut) := l_outstr[recCntOut) || ',''' || flgkosaihi ||  recMeisai[recCntM].GNKN_SHR_TESU_KNGK      || '''';
						l_outstr[recCntOut) := l_outstr[recCntOut) || ',''' || flgkosaihi ||  recMeisai[recCntM].RKN_SHR_TESU_KNGK       || '''';
						l_outstr[recCntOut) := l_outstr[recCntOut) || ',''' || flgkosaihi ||  recMeisai[recCntM].GNT_GNKN                || '''';
						l_outstr[recCntOut) := l_outstr[recCntOut) || ',''' || flgkosaihi ||  recMeisai[recCntM].GNT_RKN                 || '''';
						l_outstr[recCntOut) := l_outstr[recCntOut) || ',''' || flgkosaihi ||  recMeisai[recCntM].GNT_GNKN_SHR_TESU_KNGK  || '''';
						l_outstr[recCntOut) := l_outstr[recCntOut) || ',''' || flgkosaihi ||  recMeisai[recCntM].GNT_RKN_SHR_TESU_KNGK   || '''';
						l_outstr[recCntOut) := l_outstr[recCntOut) || ',''' || flgkosaihi ||  recMeisai[recCntM].SEIKYU_KNGK             || '''';
						l_outstr[recCntOut) := l_outstr[recCntOut) || ',''' || flgkosaihi ||  recMeisai[recCntM].SZEI_KNGK               || '''';
						colCnt	:= colCnt  + 1;	-- 列カウント
						EXIT;
					END IF;
					-- または、最大列になったらループを抜ける（会計区分は最大C_BLOCK_MAX + 1 ブロック）
					EXIT WHEN colCnt >= C_BLOCK_MAX;
					colCnt := colCnt + 1; -- 列カウント
					-- 一致しない場合(その会計区分のレコードが無い場合)空の列をセットして次の列へ
					-- 会計区分の有無により、列に０またはNULLをセット
					l_outstr[recCntOut) := l_outstr[recCntOut) || SFIPH007K00R01_setNodataKaikeiKbn(l_kaikeiKbnIdx,colCnt);
				END LOOP;
				recCntM := recCntM + 1;
			END LOOP;
			--************** 縦罫の合計行を出力 **************
			-- 会計区分別合計列用カーソル作成 
			l_sqlKT := SFIPH007K00R01_createSqlMeisai(	l_kjnYmdFrom,
										l_kjnYmdTo,
										'',	-- 元利払日(縦罫合計取得時は不要)
										recHeader[recCntN].HKT_CD,
										l_inMgrCd,
										l_inIsinCd,
										l_inItakuKaishaCd,
										recHeader[recCntN].KOUSAIHI_FLG,	-- 公債費フラグ
										'1'	-- 会計区分別合計レコード(縦罫合計)を取得
										);
			-- 合計行用に 行カウントを + 1
			recCntOut := recCntOut + 1;
			l_outHeaderFlg[recCntOut) := '0';	-- ヘッダフラグに「明細行(=0)」をセット
			l_outstr[recCntOut) := '';			-- 合計行のレコードを初期化
			colCnt	  := 0;						-- 列カウント
			l_befKaikaiKbn	:= '00';
			-- 合計金額の初期化
			l_allFrkGknKngk		:=	0;
			l_allFrkRknKngk		:=	0;
			l_allFrkGnkTesuKngk	:=	0;
			l_allFrkRknTesuKngk	:=	0;
			l_allGntGknKngk		:=	0;
			l_allGntRknKngk		:=	0;
			l_allGntGnkTesuKngk	:=	0;
			l_allGntRknTesuKngk	:=	0;
			l_allGknKngk		:=	0;
			l_allRknKngk		:=	0;
			l_allGnkTesuKngk	:=	0;
			l_allRknTesuKngk	:=	0;
			l_allKngk			:=	0;
			OPEN curRecKT FOR EXECUTE l_sqlKT;
			LOOP
				-- 縦罫合計行データを格納
				FETCH curRecKT INTO	recKbnTotal;
				-- 合計金額の集計
				-- 公債費特別会計は合計金額に加算しない(それ以外は非表示の列も含むためにタイトル列の会計区分に関係なく全て加算する)
				IF recKbnTotal.KAIKEI_KBN <> '00' AND l_befKaikaiKbn <> recKbnTotal.KAIKEI_KBN THEN
					-- 振替債
					l_allFrkGknKngk		:=	l_allFrkGknKngk		+	recKbnTotal.GANKIN					;
					l_allFrkRknKngk		:=	l_allFrkRknKngk		+	recKbnTotal.RKN						;
					l_allFrkGnkTesuKngk	:=	l_allFrkGnkTesuKngk	+	recKbnTotal.GNKN_SHR_TESU_KNGK		;
					l_allFrkRknTesuKngk	:=	l_allFrkRknTesuKngk	+	recKbnTotal.RKN_SHR_TESU_KNGK		;
					-- 現登債
					l_allGntGknKngk		:=	l_allGntGknKngk		+	recKbnTotal.GNT_GNKN				;
					l_allGntRknKngk		:=	l_allGntRknKngk		+	recKbnTotal.GNT_RKN					;
					l_allGntGnkTesuKngk	:=	l_allGntGnkTesuKngk	+	recKbnTotal.GNT_GNKN_SHR_TESU_KNGK	;
					l_allGntRknTesuKngk	:=	l_allGntRknTesuKngk	+	recKbnTotal.GNT_RKN_SHR_TESU_KNGK	;
					l_befKaikaiKbn := recKbnTotal.KAIKEI_KBN;
				END IF;
				-- 会計区分がタイトル列と一致する列を検索
				LOOP
					-- 一致したらデータセットして列セット用のループを抜ける
					IF l_kaikeiKbnArr[colCnt) = recKbnTotal.KAIKEI_KBN THEN
						l_outstr[recCntOut) := l_outstr[recCntOut) || ',''' || recKbnTotal.GANKIN                  || '''';
						l_outstr[recCntOut) := l_outstr[recCntOut) || ',''' || recKbnTotal.RKN                     || '''';
						l_outstr[recCntOut) := l_outstr[recCntOut) || ',''' || recKbnTotal.GNKN_SHR_TESU_KNGK      || '''';
						l_outstr[recCntOut) := l_outstr[recCntOut) || ',''' || recKbnTotal.RKN_SHR_TESU_KNGK       || '''';
						l_outstr[recCntOut) := l_outstr[recCntOut) || ',''' || recKbnTotal.GNT_GNKN                || '''';
						l_outstr[recCntOut) := l_outstr[recCntOut) || ',''' || recKbnTotal.GNT_RKN                 || '''';
						l_outstr[recCntOut) := l_outstr[recCntOut) || ',''' || recKbnTotal.GNT_GNKN_SHR_TESU_KNGK  || '''';
						l_outstr[recCntOut) := l_outstr[recCntOut) || ',''' || recKbnTotal.GNT_RKN_SHR_TESU_KNGK   || '''';
						l_outstr[recCntOut) := l_outstr[recCntOut) || ',''' || recKbnTotal.SEIKYU_KNGK             || '''';
						l_outstr[recCntOut) := l_outstr[recCntOut) || ',''' || recKbnTotal.SZEI_KNGK               || '''';
						colCnt	:= colCnt  + 1;	-- 列カウント
						EXIT;
					END IF;
					-- または、最大列になったらループを抜ける（会計区分は最大C_BLOCK_MAX + 1 ブロック）
					EXIT WHEN colCnt >= C_BLOCK_MAX;
					-- 一致しない場合(その会計区分のレコードが無い場合)空の列をセットして次の列へ
					-- 会計区分の有無により、列に０またはNULLをセット
					l_outstr[recCntOut) := l_outstr[recCntOut) || SFIPH007K00R01_setNodataKaikeiKbn(l_kaikeiKbnIdx,colCnt);
					colCnt := colCnt + 1; -- 列カウント
				END LOOP;
				EXIT WHEN NOT FOUND;/* apply on curRecKT */
			END LOOP;
			-- 改行する条件になったら、残りの空いている列に空をセットする（会計区分は最大C_BLOCK_MAX + 1 ブロック）
			FOR colCntTmp IN colCnt..C_BLOCK_MAX LOOP
				-- 会計区分の有無により、列に０またはNULLをセット
				l_outstr[recCntOut) := l_outstr[recCntOut) || SFIPH007K00R01_setNodataKaikeiKbn(l_kaikeiKbnIdx,colCntTmp);
			END LOOP;
			-- 総合計
			l_allGknKngk		:=	l_allFrkGknKngk		+	l_allGntGknKngk;
			l_allRknKngk		:=	l_allFrkRknKngk		+	l_allGntRknKngk;
			l_allGnkTesuKngk	:=	l_allFrkGnkTesuKngk	+	l_allGntGnkTesuKngk;
			l_allRknTesuKngk	:=	l_allFrkRknTesuKngk	+	l_allGntRknTesuKngk;
			l_allKngk			:=	l_allGknKngk + l_allRknKngk + l_allGnkTesuKngk + l_allRknTesuKngk;
			l_tmpstr := 'NULL,NULL,NULL,NULL,NULL,NULL,''合計'''
					--			元金合計					利金合計					元金手数料合計					利金手数料合計					総合計
					|| ',''' ||	l_allGknKngk || ''','''	||	l_allRknKngk || ''',''' ||	l_allGnkTesuKngk || ''',''' ||	l_allRknTesuKngk || ''',''' ||	l_allKngk || ''''
					--			振替債元金合計					利金合計						元金手数料合計						利金手数料合計
					|| ',''' ||	l_allFrkGknKngk || ''',''' ||	l_allFrkRknKngk || ''',''' ||	l_allFrkGnkTesuKngk || ''',''' ||	l_allFrkRknTesuKngk || ''''
					--			現登債元金合計					利金合計						元金手数料合計						利金手数料合計
					|| ',''' ||	l_allGntGknKngk || ''',''' ||	l_allGntRknKngk || ''',''' ||	l_allGntGnkTesuKngk || ''',''' ||	l_allGntRknTesuKngk || '''';
			--「合計」と 総合計ブロック・振替債/現登債合計ブロックを、会計区分別のブロックの前にドッキング
			l_outstr[recCntOut) := l_tmpstr || l_outstr[recCntOut);
			-- 複数発行体がある場合、次の行でまた会計区分名称をセットする用 
			flgRowCng := 0;				-- 行切替フラグ
		END IF;
	END LOOP;
	--** 帳票ワークへ編集したレコードを登録 *********************************
	-- 出力最大行カウントを取得＆出力用行カウントを初期化
	recCntMax := recCntOut;
	recCntOut := 0;
	-- 業務日付取得(作成日にセットする用)
	IF coalesce(l_inGyomuYmd::text, '') = '' THEN
		l_gyomuYmd := pkDate.getGyomuYmd();
	ELSE
		l_gyomuYmd := l_inGyomuYmd;
	END IF;
	-- 帳票ワークのキーが重複するデータを削除後に登録する。まず削除。
	DELETE FROM SREPORT_WK
		WHERE KEY_CD    = l_inItakuKaishaCd
		AND USER_ID     = l_inUserId
		AND CHOHYO_KBN  = l_inChohyoKbn
		AND SAKUSEI_YMD = l_gyomuYmd
		AND CHOHYO_ID   = 'IPH30000711';
	-- Insert用SQLの共通部分を変数にセット
	l_sqlInsC := 'INSERT INTO SREPORT_WK ('
				 || 'KEY_CD, USER_ID, CHOHYO_KBN, SAKUSEI_YMD, CHOHYO_ID, SEQ_NO, HEADER_FLG,'
				 || 'ITEM001, ITEM002, ITEM003, ITEM004, ITEM005, ITEM006, ITEM007, ITEM008, ITEM009, ITEM010,'
				 || 'ITEM011, ITEM012, ITEM013, ITEM014, ITEM015, ITEM016, ITEM017, ITEM018, ITEM019, ITEM020,'
				 || 'ITEM021, ITEM022, ITEM023, ITEM024, ITEM025, ITEM026, ITEM027, ITEM028, ITEM029, ITEM030,'
				 || 'ITEM031, ITEM032, ITEM033, ITEM034, ITEM035, ITEM036, ITEM037, ITEM038, ITEM039, ITEM040,'
				 || 'ITEM041, ITEM042, ITEM043, ITEM044, ITEM045, ITEM046, ITEM047, ITEM048, ITEM049, ITEM050,'
				 || 'ITEM051, ITEM052, ITEM053, ITEM054, ITEM055, ITEM056, ITEM057, ITEM058, ITEM059, ITEM060,'
				 || 'ITEM061, ITEM062, ITEM063, ITEM064, ITEM065, ITEM066, ITEM067, ITEM068, ITEM069, ITEM070,'
				 || 'ITEM071, ITEM072, ITEM073, ITEM074, ITEM075, ITEM076, ITEM077, ITEM078, ITEM079, ITEM080,'
				 || 'ITEM081, ITEM082, ITEM083, ITEM084, ITEM085, ITEM086, ITEM087, ITEM088, ITEM089, ITEM090,'
				 || 'ITEM091, ITEM092, ITEM093, ITEM094, ITEM095, ITEM096, ITEM097, ITEM098, ITEM099, ITEM100,'
				 || 'ITEM101, ITEM102, ITEM103, ITEM104, ITEM105, ITEM106, ITEM107, ITEM108, ITEM109, ITEM110,'
				 || 'ITEM111, ITEM112, ITEM113, ITEM114, ITEM115, ITEM116, ITEM117, ITEM118, ITEM119, ITEM120,'
				 || 'ITEM121, ITEM122, ITEM123, ITEM124, ITEM125, ITEM126, ITEM127, ITEM128, ITEM129, ITEM130,'
				 || 'ITEM131, ITEM132, ITEM133, ITEM134, ITEM135, ITEM136, ITEM137, ITEM138, ITEM139, ITEM140,'
				 || 'ITEM141, ITEM142, ITEM143, ITEM144, ITEM145, ITEM146, ITEM147, ITEM148, ITEM149, ITEM150,'
				 || 'ITEM151, ITEM152, ITEM153, ITEM154, ITEM155, ITEM156, ITEM157, ITEM158, ITEM159, ITEM160,'
				 || 'ITEM161, ITEM162, ITEM163, ITEM164, ITEM165, ITEM166, ITEM167, ITEM168, ITEM169, ITEM170,'
				 || 'ITEM171, ITEM172, ITEM173, ITEM174, ITEM175, ITEM176, ITEM177, ITEM178, ITEM179, ITEM180,'
				 || 'ITEM181, ITEM182, ITEM183, ITEM184, ITEM185, ITEM186, ITEM187, ITEM188, ITEM189, ITEM190,'
				 || 'ITEM191, ITEM192, ITEM193, ITEM194, ITEM195, ITEM196, ITEM197, ITEM198, ITEM199, ITEM200,'
				 || 'KOUSIN_ID, SAKUSEI_ID'
				 || ') VALUES (';
	-- データの並びを編集したものを全件 帳票ワークへ登録する
	FOR recCntOut IN 0..recCntMax LOOP
		-- SQL文の共通部分と、各レコードごとの部分のSQLを結合して帳票ワークへInsertする。
		EXECUTE l_sqlInsC || ''''
							|| l_inItakuKaishaCd         || ''',''' -- KEY_CD(=委託会社CD)
							|| l_inUserId                || ''',''' -- ユーザID
							|| l_inChohyoKbn             || ''',''' -- 帳票区分
							|| l_gyomuYmd                || ''',''' -- 作成日(=業務日付)
							|| 'IPH30000711'             || ''',''' --
							|| recCntOut                 || ''',''' -- SeqNo(=ループカウンタ)
							|| l_outHeaderFlg[recCntOut) || ''',  ' -- ヘッダフラグ
							|| l_outstr[recCntOut)       || ','''   -- 明細行の追加データ部分SQL(会計区分別)
							|| l_inUserId                || ''',''' -- 更新者ID
							|| l_inUserId                || '''   ' -- 作成者ID
							|| ')';
	-- ↓ デバッグ用---------------------------------------------------
--
--		LOOP
--			DBMS_OUTPUT.put_line(SUBSTR(l_sqlInsC || ''''
--							|| l_inItakuKaishaCd         || ''',''' -- KEY_CD(=委託会社CD)
--							|| l_inUserId                || ''',''' -- ユーザID
--							|| l_inChohyoKbn             || ''',''' -- 帳票区分
--							|| l_gyomuYmd                || ''',''' -- 作成日(=業務日付)
--							|| 'IPH30000711'             || ''',''' --
--							|| recCntOut                 || ''',''' -- SeqNo(=ループカウンタ)
--							|| l_outHeaderFlg[recCntOut) || ''',  ' -- ヘッダフラグ
--							|| l_outstr[recCntOut)       || ','''   -- 明細行の追加データ部分SQL
--							|| l_inUserId                || ''',''' -- 更新者ID
--							|| l_inUserId                || '''   ' -- 作成者ID
--							|| ')',debugStrLength,100));
--			debugStrLength := debugStrLength + 100;
--			EXIT WHEN debugStrLength >= 5001;
--		END LOOP;
--		DBMS_OUTPUT.put_line('~'); 	-- レコード毎のデリミタ(正規表現置換用)
--		debugStrLength := 1;		-- 出力開始位置初期化
--
--		-- SQL出力用
--		LOOP
--			DBMS_OUTPUT.put_line(SUBSTR(l_sqlM,debugStrLength,100));
--			debugStrLength := debugStrLength + 100;
--			EXIT WHEN debugStrLength >= 5001;
--		END LOOP;
--		DBMS_OUTPUT.put_line('~'); 	-- レコード毎のデリミタ(正規表現置換用)
--		debugStrLength := 1;		-- 出力開始位置初期化
--
--
	-- ↑ デバッグ用---------------------------------------------------
	END LOOP;
	RETURN RTN_OK;
EXCEPTION
	WHEN OTHERS THEN
		-- CALL PKLOG.FATAL('ECM701','SFIPH007K00R01','エラーコード：'     || SQLSTATE);
		-- CALL PKLOG.FATAL('ECM701','SFIPH007K00R01','エラーメッセージ：' || SQLERRM);
		RETURN RTN_FATAL;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfiph007k00r01 ( l_inItakuKaishaCd MGR_KIHON.ITAKU_KAISHA_CD%TYPE, l_inUserId MGR_KIHON.LAST_TEISEI_ID%TYPE, l_inChohyoKbn SREPORT_WK.CHOHYO_KBN%TYPE, l_inGyomuYmd SREPORT_WK.SAKUSEI_YMD%TYPE, l_inKjnYmdFrom MGR_KIHON.HAKKO_YMD%TYPE, l_inKjnYmdTo MGR_KIHON.HAKKO_YMD%TYPE, l_inHktCd MGR_KIHON.HKT_CD%TYPE, l_inMgrCd MGR_KIHON.MGR_CD%TYPE, l_inIsinCd MGR_KIHON.ISIN_CD%TYPE  ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfiph007k00r01_createsqlheader ( l_inKjnYmdFrom MGR_KIHON.HAKKO_YMD%TYPE,		-- 基準日From
 l_inKjnYmdTo MGR_KIHON.HAKKO_YMD%TYPE,		-- 基準日To
 l_inHktCd MGR_KIHON.HKT_CD%TYPE,			-- 発行体コード
 l_inMgrCd MGR_KIHON.MGR_CD%TYPE,			-- 銘柄コード
 l_inIsinCd MGR_KIHON.ISIN_CD%TYPE,			-- ISINコード
 l_inItakuKaishaCd MGR_KIHON.ITAKU_KAISHA_CD%TYPE 	-- 委託会社コード
 ) RETURNS varchar AS $body$
DECLARE
	RTN_OK CONSTANT integer := 0;
	RTN_NG CONSTANT integer := 1;
	RTN_NODATA CONSTANT integer := 2;
	RTN_FATAL CONSTANT integer := 99;
	tmpRecHeader sfiph007k00r01_type_rec_header;
	tmpRecMeisai sfiph007k00r01_type_rec_meisai;

	l_sql	varchar(4000);

BEGIN
	l_sql :=			'SELECT DISTINCT'
					||	'	 ITAKU_KAISHA_CD'
					||	'	,HKT_CD'
					||	'	,KAIKEI_KBN'
					||	'	,KAIKEI_KBN_RNM'
					||	'	,KOSAI_TOKKAI'
					||	' FROM (SELECT'
					||	'	 WT01.ITAKU_KAISHA_CD'
					||	'	,WT01.HKT_CD'
					||	'	,WT01.KAIKEI_KBN'
					||	'	,WT01.KAIKEI_KBN_RNM'
					||	'	,CASE COALESCE((SELECT MAX(KOUSAIHI_FLG) FROM KAIKEI_KBN WHERE ITAKU_KAISHA_CD = WT01.ITAKU_KAISHA_CD AND HKT_CD = WT01.HKT_CD),''0'')'
					||	'		WHEN ''0'' THEN'
					||	'			''2'' '				-- 会計区分マスタで公債費フラグを使用していない発行体
					||	'		ELSE'
					||	'			WMG1.KOSAI_TOKKAI'	-- 公債費フラグを使用している場合は銘柄の属性により判定
					||	'	END AS KOSAI_TOKKAI'
					||	'	FROM'
					-- 会計区分を取得するサブクエリ
					-- 一般会計を取得'
					||	'	(SELECT DISTINCT'
					||	'		H05.ITAKU_KAISHA_CD,'
					||	'		H05.HKT_CD,'
					||	'		H05.KAIKEI_KBN,'
					||	'		H01.KAIKEI_KBN_RNM'
					||	'	FROM'
					||	'		KIKIN_SEIKYU_KAIKEI H05,'
					||	'		KAIKEI_KBN H01,'
					||	'		MGR_KIHON_VIEW VMG1'
					||	'	WHERE'
					||	'			H05.CHOKYU_YMD BETWEEN ''' || l_inKjnYmdFrom || ''' AND ''' || l_inKjnYmdTo ||	''' '
					||	'		AND H01.ITAKU_KAISHA_CD(+)	= H05.ITAKU_KAISHA_CD'
					||	'		AND H01.HKT_CD(+)			= H05.HKT_CD'
					||	'		AND H01.KAIKEI_KBN(+)		= H05.KAIKEI_KBN'
					||	'		AND H05.ITAKU_KAISHA_CD		= VMG1.ITAKU_KAISHA_CD'
					||	'		AND TRIM(VMG1.ISIN_CD) IS NOT NULL'
					||	'		AND VMG1.MGR_STAT_KBN = ''1'''
					   -- 会計按分テーブルの承認済み銘柄のみ抽出対象にする
					||	'		AND PKIPAKKNIDO.GETKAIKEIANBUNCOUNT(VMG1.ITAKU_KAISHA_CD , VMG1.MGR_CD) > 0 '
					||	'		AND H05.ISIN_CD				= VMG1.ISIN_CD';
--	委託会社コードの指定有り	
IF	(trim(both l_inItakuKaishaCd) IS NOT NULL AND (trim(both l_inItakuKaishaCd))::text <> '') THEN
	l_sql := l_sql	|| ' AND H05.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' ';
END IF;
--	発行体コードの指定有り	
IF	(trim(both l_inHktCd) IS NOT NULL AND (trim(both l_inHktCd))::text <> '') THEN
	l_sql := l_sql	|| ' AND H05.HKT_CD = ''' || l_inHktCd || ''' ';
END IF;
--	銘柄コードの指定有り	
IF	(trim(both l_inMgrCd) IS NOT NULL AND (trim(both l_inMgrCd))::text <> '') THEN
	l_sql := l_sql	|| ' AND VMG1.MGR_CD = ''' || l_inMgrCd || ''' ';
END IF;
--	ISINコードの指定有り	
IF	(trim(both l_inIsinCd) IS NOT NULL AND (trim(both l_inIsinCd))::text <> '') THEN
	l_sql := l_sql	|| ' AND H05.ISIN_CD = ''' || l_inIsinCd || ''' ';
END IF;
	l_sql := l_sql	||	'	UNION'
					-- 公債費特別会計を取得'
					||	'	 SELECT DISTINCT'
					||	'		H05.ITAKU_KAISHA_CD,'
					||	'		H05.HKT_CD,'
					||	'		MAX(''00'') AS KAIKEI_KBN,'
					||	'		MAX(''公債費特別会計'') AS KAIKEI_KBN_NM'
					||	'	FROM'
					||	'		KIKIN_SEIKYU_KAIKEI H05,'
					||	'		KAIKEI_KBN H01,'
					||	'		MGR_KIHON_VIEW VMG1'
					||	'	WHERE'
					||	'			H05.CHOKYU_YMD BETWEEN ''' || l_inKjnYmdFrom || ''' AND ''' || l_inKjnYmdTo ||	''' '
					||	'		AND H05.KOUSAIHI_FLG = ''1'' '
					||	'		AND H01.ITAKU_KAISHA_CD(+)	= H05.ITAKU_KAISHA_CD'
					||	'		AND H01.HKT_CD(+)			= H05.HKT_CD'
					||	'		AND H01.KAIKEI_KBN(+)		= H05.KAIKEI_KBN'
					||	'		AND H05.ITAKU_KAISHA_CD		= VMG1.ITAKU_KAISHA_CD'
					||	'		AND TRIM(VMG1.ISIN_CD) IS NOT NULL'
					||	'		AND VMG1.MGR_STAT_KBN = ''1'''
					   -- 会計按分テーブルの承認済み銘柄のみ抽出対象にする
					||	'		AND PKIPAKKNIDO.GETKAIKEIANBUNCOUNT(VMG1.ITAKU_KAISHA_CD , VMG1.MGR_CD) > 0 '
					||	'		AND H05.ISIN_CD				= VMG1.ISIN_CD';
--	委託会社コードの指定有り	
IF	(trim(both l_inItakuKaishaCd) IS NOT NULL AND (trim(both l_inItakuKaishaCd))::text <> '') THEN
	l_sql := l_sql	|| ' AND H05.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' ';
END IF;
--	発行体コードの指定有り	
IF	(trim(both l_inHktCd) IS NOT NULL AND (trim(both l_inHktCd))::text <> '') THEN
	l_sql := l_sql	|| ' AND H05.HKT_CD = ''' || l_inHktCd || ''' ';
END IF;
--	銘柄コードの指定有り	
IF	(trim(both l_inMgrCd) IS NOT NULL AND (trim(both l_inMgrCd))::text <> '') THEN
	l_sql := l_sql	|| ' AND VMG1.MGR_CD = ''' || l_inMgrCd || ''' ';
END IF;
--	ISINコードの指定有り	
IF	(trim(both l_inIsinCd) IS NOT NULL AND (trim(both l_inIsinCd))::text <> '') THEN
	l_sql := l_sql	|| ' AND H05.ISIN_CD = ''' || l_inIsinCd || ''' ';
END IF;
	l_sql := l_sql	||	'	GROUP BY H05.ITAKU_KAISHA_CD,H05.HKT_CD) WT01,'
					-- その発行体に、公債費特別会計の対象になる銘柄が存在するかどうかを取得するサブクエリ
					||	'		(SELECT DISTINCT T.ITAKU_KAISHA_CD, T.HKT_CD, ''0'' AS KOSAI_TOKKAI'
					||	'			FROM MGR_KIHON_VIEW T, '
										-- 基金請求会計テーブルで、有効な銘柄の公債費フラグを取得する
					||	'				(SELECT '
					||	'	            	T.ITAKU_KAISHA_CD, T.HKT_CD, T.ISIN_CD, T.CHOKYU_YMD, MAX(T.KOUSAIHI_FLG) AS KOUSAIHI_FLG '
					||	'	            	FROM  '
					||	'	            	KIKIN_SEIKYU_KAIKEI T '
 						||	'	           		GROUP BY '
					||	'          			T.ITAKU_KAISHA_CD, T.HKT_CD, T.ISIN_CD, T.CHOKYU_YMD '
					||	'	            ) TH05 '
					||	'		WHERE TH05.ITAKU_KAISHA_CD = T.ITAKU_KAISHA_CD'
					||	'			AND TH05.HKT_CD = T.HKT_CD'
					||	'			AND TH05.ISIN_CD = T.ISIN_CD'
					||	'			AND TH05.CHOKYU_YMD BETWEEN ''' || l_inKjnYmdFrom || ''' AND ''' || l_inKjnYmdTo ||	''' '
					||	'			AND TRIM(T.ISIN_CD) IS NOT NULL'
					||	'			AND T.MGR_STAT_KBN = ''1'''
					||	'			AND TH05.KOUSAIHI_FLG = ''0''';
--	委託会社コードの指定有り	
IF	(trim(both l_inItakuKaishaCd) IS NOT NULL AND (trim(both l_inItakuKaishaCd))::text <> '') THEN
	l_sql := l_sql	|| 			'	AND T.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' ';
END IF;
--	発行体コードの指定有り	
IF	(trim(both l_inHktCd) IS NOT NULL AND (trim(both l_inHktCd))::text <> '') THEN
	l_sql := l_sql	||			'	AND T.HKT_CD = ''' || l_inHktCd || ''' ';
END IF;
--	銘柄コードの指定有り	
IF	(trim(both l_inMgrCd) IS NOT NULL AND (trim(both l_inMgrCd))::text <> '') THEN
	l_sql := l_sql	||			'	AND T.MGR_CD = ''' || l_inMgrCd || ''' ';
END IF;
--	ISINコードの指定有り	
IF	(trim(both l_inIsinCd) IS NOT NULL AND (trim(both l_inIsinCd))::text <> '') THEN
	l_sql := l_sql	||			'	AND T.ISIN_CD = ''' || l_inIsinCd || ''' ';
END IF;
	l_sql := l_sql	||	'		UNION'
					||	'		SELECT DISTINCT T.ITAKU_KAISHA_CD, T.HKT_CD, ''1'' AS KOSAI_TOKKAI'
					||	'			FROM MGR_KIHON_VIEW T, '
										-- 基金請求会計テーブルで、有効な銘柄の公債費フラグを取得する
					||	'				(SELECT '
					||	'	            	T.ITAKU_KAISHA_CD, T.HKT_CD, T.ISIN_CD, T.CHOKYU_YMD, MAX(T.KOUSAIHI_FLG) AS KOUSAIHI_FLG '
					||	'	            	FROM  '
					||	'	            	KIKIN_SEIKYU_KAIKEI T '
 						||	'	           		GROUP BY '
					||	'          			T.ITAKU_KAISHA_CD, T.HKT_CD, T.ISIN_CD, T.CHOKYU_YMD '
					||	'	            ) TH05 '
					||	'		WHERE TH05.ITAKU_KAISHA_CD = T.ITAKU_KAISHA_CD'
					||	'			AND TH05.HKT_CD = T.HKT_CD'
					||	'			AND TH05.ISIN_CD = T.ISIN_CD'
					||	'			AND TH05.CHOKYU_YMD BETWEEN ''' || l_inKjnYmdFrom || ''' AND ''' || l_inKjnYmdTo ||	''' '
					||	'			AND TRIM(T.ISIN_CD) IS NOT NULL'
					||	'			AND T.MGR_STAT_KBN = ''1'''
					||	'			AND TH05.KOUSAIHI_FLG = ''1''';
--	委託会社コードの指定有り	
IF	(trim(both l_inItakuKaishaCd) IS NOT NULL AND (trim(both l_inItakuKaishaCd))::text <> '') THEN
	l_sql := l_sql	|| 			'	AND T.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' ';
END IF;
--	発行体コードの指定有り	
IF	(trim(both l_inHktCd) IS NOT NULL AND (trim(both l_inHktCd))::text <> '') THEN
	l_sql := l_sql	||			'	AND T.HKT_CD = ''' || l_inHktCd || ''' ';
END IF;
--	銘柄コードの指定有り	
IF	(trim(both l_inMgrCd) IS NOT NULL AND (trim(both l_inMgrCd))::text <> '') THEN
	l_sql := l_sql	||			'	AND T.MGR_CD = ''' || l_inMgrCd || ''' ';
END IF;
--	ISINコードの指定有り	
IF	(trim(both l_inIsinCd) IS NOT NULL AND (trim(both l_inIsinCd))::text <> '') THEN
	l_sql := l_sql	||			'	AND T.ISIN_CD = ''' || l_inIsinCd || ''' ';
END IF;
	l_sql := l_sql	||	'			) WMG1'
					||	'	WHERE	WT01.ITAKU_KAISHA_CD	= WMG1.ITAKU_KAISHA_CD'
					||	'	AND		WT01.HKT_CD				= WMG1.HKT_CD)'
					||	'	WHERE'
					||	'		NOT(KOSAI_TOKKAI = ''2'' AND KAIKEI_KBN = ''00'')'	-- 公債費を使用していない発行体には交際費特別会計列は不要
					||	'	ORDER BY'
					||	'	ITAKU_KAISHA_CD,HKT_CD ASC ,KOSAI_TOKKAI DESC ,KAIKEI_KBN ASC';
	RETURN l_sql;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfiph007k00r01_createsqlheader ( l_inKjnYmdFrom MGR_KIHON.HAKKO_YMD%TYPE, l_inKjnYmdTo MGR_KIHON.HAKKO_YMD%TYPE, l_inHktCd MGR_KIHON.HKT_CD%TYPE, l_inMgrCd MGR_KIHON.MGR_CD%TYPE, l_inIsinCd MGR_KIHON.ISIN_CD%TYPE, l_inItakuKaishaCd MGR_KIHON.ITAKU_KAISHA_CD%TYPE  ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfiph007k00r01_createsqlmeisai ( l_inKjnYmdFrom MGR_KIHON.HAKKO_YMD%TYPE,		-- 基準日From
 l_inKjnYmdTo MGR_KIHON.HAKKO_YMD%TYPE,		-- 基準日To
 l_inGnrYmd MGR_KIHON.HAKKO_YMD%TYPE,		-- 元利払日
 l_inHktCd MGR_KIHON.HKT_CD%TYPE,			-- 発行体コード
 l_inMgrCd MGR_KIHON.MGR_CD%TYPE,			-- 銘柄コード
 l_inIsinCd MGR_KIHON.ISIN_CD%TYPE,			-- ISINコード
 l_inItakuKaishaCd MGR_KIHON.ITAKU_KAISHA_CD%TYPE,	-- 委託会社コード
 l_inKousaihiFlg CHAR,							-- 公債費フラグ（0：一般会計　1：公債費特別会計　2：公債費特会は使用しない）
 l_inTotalFlg CHAR 								-- 合計行取得フラグ(０：明細行　１：縦罫合計行)
 ) RETURNS varchar AS $body$
DECLARE
	RTN_OK CONSTANT integer := 0;
	RTN_NG CONSTANT integer := 1;
	RTN_NODATA CONSTANT integer := 2;
	RTN_FATAL CONSTANT integer := 99;
	tmpRecHeader sfiph007k00r01_type_rec_header;
	tmpRecMeisai sfiph007k00r01_type_rec_meisai;

	l_sql	varchar(4000);

BEGIN
	--	SELECT文	
	l_sql :=		'SELECT '
					||	' WT01.HKT_CD,'
					||	' WT01.HKT_RNM,';
	IF	l_inTotalFlg <> '1' THEN
	-- 明細行/横罫合計列レコードを取得する場合
	l_sql := l_sql	||	' WT01.GNR_YMD,'
					||	' WT01.CHOKYU_YMD,'
					||	' WT01.ISIN_CD,'
					||	' WT01.MGR_CD,'
					||	' WT01.MGR_RNM,';
	END IF;
	l_sql := l_sql	||	' WT01.KAIKEI_KBN AS KAIKEI_KBN,'
					||	' WT01.KAIKEI_KBN_RNM AS KAIKEI_KBN_RNM,'
					||	' WT01.GANKIN,'
					||	' WT01.RKN,'
					||	' WT01.GNKN_SHR_TESU_KNGK,'
					||	' WT01.RKN_SHR_TESU_KNGK,'
					||	' WT01.GNT_GNKN,'
					||	' WT01.GNT_RKN,'
					||	' WT01.GNT_GNKN_SHR_TESU_KNGK,'
					||	' WT01.GNT_RKN_SHR_TESU_KNGK,'
					||	' WT01.SEIKYU_KNGK,'
					||	' WT01.SZEI_KNGK,'
					||	' WT01.KOUSAIHI_FLG'
					||	' FROM'
					||	' (SELECT '
					||	' H05.HKT_CD,'
					||	' H05.HKT_RNM,';
	IF	l_inTotalFlg <> '1' THEN
	-- 明細行/横罫合計列レコードを取得する場合
	l_sql := l_sql	||	' H05.GNR_YMD,'
					||	' H05.CHOKYU_YMD,'
					||	' H05.ISIN_CD,'
					||	' VMG1.MGR_CD,'
					||	' VMG1.MGR_RNM,';
	END IF;
	l_sql := l_sql	||	' SUM(H05.GANKIN) AS GANKIN,'
					||	' SUM(H05.RKN) AS RKN,'
					||	' SUM(H05.GNKN_SHR_TESU_KNGK) AS GNKN_SHR_TESU_KNGK,'
					||	' SUM(H05.RKN_SHR_TESU_KNGK) AS RKN_SHR_TESU_KNGK,'
					||	' SUM(H05.GNT_GNKN) AS GNT_GNKN,'
					||	' SUM(H05.GNT_RKN) AS GNT_RKN,'
					||	' SUM(H05.GNT_GNKN_SHR_TESU_KNGK) AS GNT_GNKN_SHR_TESU_KNGK,'
					||	' SUM(H05.GNT_RKN_SHR_TESU_KNGK) AS GNT_RKN_SHR_TESU_KNGK,'
					||	' SUM(H05.SEIKYU_KNGK) AS SEIKYU_KNGK,'
					||	' SUM(H05.SZEI_KNGK) AS SZEI_KNGK,'
					||	' MAX(H05.KOUSAIHI_FLG) AS KOUSAIHI_FLG'
					||	',H05.KAIKEI_KBN,'
					||	' H01.KAIKEI_KBN_RNM'
					||	' FROM'
					||	'  KIKIN_SEIKYU_KAIKEI H05,'
					||	'  KAIKEI_KBN H01,'
					||	'  MGR_KIHON_VIEW VMG1';
	--	WHERH文	
	l_sql := l_sql	||	' WHERE'
					||	'      H05.CHOKYU_YMD BETWEEN ''' || l_inKjnYmdFrom || ''' AND ''' || l_inKjnYmdTo ||	''' '
					||	'  AND H01.ITAKU_KAISHA_CD(+) = H05.ITAKU_KAISHA_CD'
					||	'  AND H01.HKT_CD(+)          = H05.HKT_CD'
					||	'  AND H01.KAIKEI_KBN(+)      = H05.KAIKEI_KBN'
					||	'  AND H05.ITAKU_KAISHA_CD    = VMG1.ITAKU_KAISHA_CD'
					||	'  AND H05.ISIN_CD            = VMG1.ISIN_CD'
					||	'  AND TRIM(VMG1.ISIN_CD) IS NOT NULL'
					||	'  AND VMG1.MGR_STAT_KBN = ''1'''
					   -- 会計按分テーブルの承認済み銘柄のみ抽出対象にする
					||	'  AND PKIPAKKNIDO.GETKAIKEIANBUNCOUNT(VMG1.ITAKU_KAISHA_CD , VMG1.MGR_CD) > 0 '
					||	'  AND H05.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' '
					||	'  AND H05.HKT_CD = ''' || l_inHktCd || ''' ';
	-- 公債費特別会計を取得する場合 
	IF	l_inKousaihiFlg = '1' THEN
		-- 銘柄、徴求日単位で　公債費フラグを使用している会計区分がある
		l_sql := l_sql || ' 	AND (SELECT MAX(KOUSAIHI_FLG) FROM KIKIN_SEIKYU_KAIKEI'
					   || ' 	WHERE H05.ITAKU_KAISHA_CD = ITAKU_KAISHA_CD AND H05.ISIN_CD = ISIN_CD AND H05.CHOKYU_YMD = CHOKYU_YMD) = ''1'' ';
	-- 公債費特別会計対象外の会計を取得する場合 
	ELSE
		-- 銘柄、徴求日単位で　公債費フラグを使用している会計区分がない
		l_sql := l_sql || ' 	AND (SELECT MAX(KOUSAIHI_FLG) FROM KIKIN_SEIKYU_KAIKEI'
					   || ' 	WHERE H05.ITAKU_KAISHA_CD = ITAKU_KAISHA_CD AND H05.ISIN_CD = ISIN_CD AND H05.CHOKYU_YMD = CHOKYU_YMD) = ''0'' ';
	END IF;
	--	銘柄コードの指定有り	
	IF	(trim(both l_inMgrCd) IS NOT NULL AND (trim(both l_inMgrCd))::text <> '') THEN
		l_sql := l_sql || ' AND VMG1.MGR_CD = ''' || l_inMgrCd || ''' ';
	END IF;
	--	ISINコードの指定有り	
	IF	(trim(both l_inIsinCd) IS NOT NULL AND (trim(both l_inIsinCd))::text <> '') THEN
		l_sql := l_sql || ' AND H05.ISIN_CD = ''' || l_inIsinCd || ''' ';
	END IF;
	--	元利払日の指定有り	
	IF	(trim(both l_inGnrYmd) IS NOT NULL AND (trim(both l_inGnrYmd))::text <> '') THEN
		l_sql := l_sql || ' AND H05.GNR_YMD = ''' || l_inGnrYmd || ''' ';
	END IF;
	IF	l_inTotalFlg = '0' THEN
	-- 明細行レコードを取得する場合
	--	GROUP BY句	※該当レコードの口座振替区分をまとめるため　
	l_sql := l_sql	||	' GROUP BY H05.HKT_CD, H05.HKT_RNM, H05.GNR_YMD, H05.CHOKYU_YMD, H05.ISIN_CD, VMG1.MGR_CD, VMG1.MGR_RNM, H05.KAIKEI_KBN, H01.KAIKEI_KBN_RNM';
	ELSIF 	l_inTotalFlg = '1' THEN
	-- 縦罫合計行レコードを取得する場合
	--	GROUP BY句	※該当レコードの発行体をまとめるため　
	l_sql := l_sql	||	' GROUP BY H05.HKT_CD, H05.HKT_RNM, H05.KAIKEI_KBN, H01.KAIKEI_KBN_RNM';
	END IF;
	-- 公債費特別会計を取得する場合のみ（公債費特別会計対象外の会計取得時不要） 
	IF	l_inKousaihiFlg = '1' THEN
		l_sql := l_sql	||	' UNION SELECT '
						||	' H05.HKT_CD,'
						||	' H05.HKT_RNM,';
		IF	l_inTotalFlg <> '1' THEN
		-- 明細行/横罫合計列レコードを取得する場合
		l_sql := l_sql	||	' H05.GNR_YMD,'
						||	' H05.CHOKYU_YMD,'
						||	' H05.ISIN_CD,'
						||	' VMG1.MGR_CD,'
						||	' VMG1.MGR_RNM,';
		END IF;
		l_sql := l_sql	||	' SUM(H05.GANKIN) AS GANKIN,'
						||	' SUM(H05.RKN) AS RKN,'
						||	' SUM(H05.GNKN_SHR_TESU_KNGK) AS GNKN_SHR_TESU_KNGK,'
						||	' SUM(H05.RKN_SHR_TESU_KNGK) AS RKN_SHR_TESU_KNGK,'
						||	' SUM(H05.GNT_GNKN) AS GNT_GNKN,'
						||	' SUM(H05.GNT_RKN) AS GNT_RKN,'
						||	' SUM(H05.GNT_GNKN_SHR_TESU_KNGK) AS GNT_GNKN_SHR_TESU_KNGK,'
						||	' SUM(H05.GNT_RKN_SHR_TESU_KNGK) AS GNT_RKN_SHR_TESU_KNGK,'
						||	' SUM(H05.SEIKYU_KNGK) AS SEIKYU_KNGK,'
						||	' SUM(H05.SZEI_KNGK) AS SZEI_KNGK,'
						||	' ''0'' AS KOUSAIHI_FLG,'
						||	' ''00'' AS KAIKEI_KBN,'
						||	' ''公債費特別会計'' AS KAIKEI_KBN_NM'
						||	' FROM'
						||	'  KIKIN_SEIKYU_KAIKEI H05,'
						||	'  KAIKEI_KBN H01,'
						||	'  MGR_KIHON_VIEW VMG1';
		--	WHERH文	
		l_sql := l_sql	||	' WHERE'
						||	'      H05.CHOKYU_YMD BETWEEN ''' || l_inKjnYmdFrom || ''' AND ''' || l_inKjnYmdTo ||	''' '
						||	'  AND H05.KOUSAIHI_FLG = ''1'' '
						||	'  AND H01.ITAKU_KAISHA_CD(+) = H05.ITAKU_KAISHA_CD'
						||	'  AND H01.HKT_CD(+)          = H05.HKT_CD'
						||	'  AND H01.KAIKEI_KBN(+)      = H05.KAIKEI_KBN'
						||	'  AND H05.ITAKU_KAISHA_CD    = VMG1.ITAKU_KAISHA_CD'
						||	'  AND H05.ISIN_CD            = VMG1.ISIN_CD'
						||	'  AND TRIM(VMG1.ISIN_CD) IS NOT NULL'
						||	'  AND VMG1.MGR_STAT_KBN = ''1'''
						   -- 会計按分テーブルの承認済み銘柄のみ抽出対象にする
						||	'  AND PKIPAKKNIDO.GETKAIKEIANBUNCOUNT(VMG1.ITAKU_KAISHA_CD , VMG1.MGR_CD) > 0 '
						||	'  AND H05.ITAKU_KAISHA_CD = ''' || l_inItakuKaishaCd || ''' '
						||	'  AND H05.HKT_CD = ''' || l_inHktCd || ''' ';
		--	銘柄コードの指定有り	
		IF	(trim(both l_inMgrCd) IS NOT NULL AND (trim(both l_inMgrCd))::text <> '') THEN
			l_sql := l_sql || ' AND VMG1.MGR_CD = ''' || l_inMgrCd || ''' ';
		END IF;
		--	ISINコードの指定有り	
		IF	(trim(both l_inIsinCd) IS NOT NULL AND (trim(both l_inIsinCd))::text <> '') THEN
			l_sql := l_sql || ' AND H05.ISIN_CD = ''' || l_inIsinCd || ''' ';
		END IF;
		--	元利払日の指定有り	
		IF	(trim(both l_inGnrYmd) IS NOT NULL AND (trim(both l_inGnrYmd))::text <> '') THEN
			l_sql := l_sql || ' AND H05.GNR_YMD = ''' || l_inGnrYmd || ''' ';
		END IF;
		-- 明細行レコードを取得する場合
		IF	l_inTotalFlg = '0' THEN
		--	GROUP BY句	※該当レコードの口座振替区分をまとめるため　
		l_sql := l_sql	||	' GROUP BY H05.HKT_CD, H05.HKT_RNM, H05.GNR_YMD, H05.CHOKYU_YMD, H05.ISIN_CD, VMG1.MGR_CD, VMG1.MGR_RNM';
		-- 縦罫合計行レコードを取得する場合
		ELSIF 	l_inTotalFlg = '1' THEN
		--	GROUP BY句	※該当レコードの発行体をまとめるため　
		l_sql := l_sql	||	' GROUP BY H05.HKT_CD, H05.HKT_RNM';
		END IF;
	END IF;
	l_sql := l_sql	||	' )WT01 ';
	IF	l_inTotalFlg = '0' THEN
	--	ORDER BY句	
	l_sql := l_sql	||	' ORDER BY WT01.HKT_CD, WT01.CHOKYU_YMD, WT01.ISIN_CD, WT01.GNR_YMD, WT01.KAIKEI_KBN';
	-- 縦罫合計行レコードを取得する場合
	ELSIF 	l_inTotalFlg = '1' THEN
	--	ORDER BY句	
	l_sql := l_sql	||	' ORDER BY WT01.HKT_CD, WT01.KAIKEI_KBN';
	END IF;
	RETURN l_sql;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfiph007k00r01_createsqlmeisai ( l_inKjnYmdFrom MGR_KIHON.HAKKO_YMD%TYPE, l_inKjnYmdTo MGR_KIHON.HAKKO_YMD%TYPE, l_inGnrYmd MGR_KIHON.HAKKO_YMD%TYPE, l_inHktCd MGR_KIHON.HKT_CD%TYPE, l_inMgrCd MGR_KIHON.MGR_CD%TYPE, l_inIsinCd MGR_KIHON.ISIN_CD%TYPE, l_inItakuKaishaCd MGR_KIHON.ITAKU_KAISHA_CD%TYPE, l_inKousaihiFlg CHAR, l_inTotalFlg CHAR  ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfiph007k00r01_setnodatakaikeikbn ( l_inMaxKaikeiKbnIdx integer,	-- 発行体単位で存在する会計区分の最大INDEX
 l_inTmpKaikeiKbnIdx integer 	-- 現在参照中の会計区分INDEX
 ) RETURNS varchar AS $body$
DECLARE
	RTN_OK CONSTANT integer := 0;
	RTN_NG CONSTANT integer := 1;
	RTN_NODATA CONSTANT integer := 2;
	RTN_FATAL CONSTANT integer := 99;
	tmpRecHeader sfiph007k00r01_type_rec_header;
	tmpRecMeisai sfiph007k00r01_type_rec_meisai;

	l_ret	varchar(100);

BEGIN
	IF l_inTmpKaikeiKbnIdx < l_inMaxKaikeiKbnIdx THEN
		-- 会計区分は存在するがデータの無い列は０をセット
		l_ret := ',''0'',''0'',''0'',''0'',''0'',''0'',''0'',''0'',''0'',''0''';
	ELSE
		-- 存在しない分は空の列をセット
		l_ret := ',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL';
	END IF;
	RETURN l_ret;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfiph007k00r01_setnodatakaikeikbn ( l_inMaxKaikeiKbnIdx integer, l_inTmpKaikeiKbnIdx integer  ) FROM PUBLIC;