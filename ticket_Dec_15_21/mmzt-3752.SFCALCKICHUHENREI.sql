




CREATE OR REPLACE FUNCTION sfcalckichuhenrei ( l_initakukaishacd CHAR , l_inmgrcd CHAR , l_intesucd CHAR , l_indate CHAR, l_allinkngk numeric, l_zeinukiinkngk numeric, l_szeiinkngk numeric, l_outallhenreikngk OUT numeric, l_outzeinukihenreikngk OUT numeric, l_outszeihenreikngk OUT numeric , OUT extra_param numeric) RETURNS record AS $body$
DECLARE

  --*
--  * 期中手数料返戻計算処理
--  * 期中手数料の返戻金額を算出するファンクションです。
--  *
--  * @author
--  * @version $Id:$
--  
  --*
--  *
--  * @param l_initakukaishacd 　委託会社コード
--  * @param l_inmgrcd 　      銘柄コード
--  * @param l_intesucd 　手数料種類コード
--  * @param l_indate 　徴求日
--  * @param l_allinkngk 　元の期中手数料金額（全体）
--  * @param l_zeinukiinkngk 　元の期中手数料金額（税抜）
--  * @param l_inkngk 　元の期中手数料金額（消費税）
--  * @param l_outallhenreikngk 　期中手数料返戻金額（全体）
--  * @param l_outzeinukihenreikngk 　期中手数料返戻金額（税抜）
--  * @param l_outszeihenreikngk 　期中手数料返戻金額（消費税）
--  
	--==============================================================================
	--					変数定義													
	--==============================================================================
  	--	取得データ格納用変数リスト	
	p_itakukaishacd			char(4);										--	委託会社コード
	p_mgrcd					varchar(13);									--	銘柄コード
	p_jtkkbn				char(1);										--	受託区分
	p_tesushuruicd			char(2);										--	手数料種類コード
	p_hakkotsukacd			char(3);										--	発行通貨コード
	p_chokyukjt				char(8);										--	徴求期日
	p_chokyuymd				char(8);										--	徴求日
	p_distriymd				char(8);										--	分配日
	p_hakkoymd				char(8);										--	発行年月日
	p_fullshokanymd			char(8);										--	満期償還日
	p_ebmakeymd				char(8);										--	EB作成年月日	--	徴求日-EB作成日営業日前
	p_ebsendymd				char(8);										--	EB送信年月日	--	徴求日-EB送信日営業日前
	p_nyukinymd				char(8);										--	入金日
	p_tesusashihikikbn		char(1);										--	手数料差引区分
	p_eigyotencd			char(4);										--	営業店コード
	p_kozafurikbn			char(2);										--	口座振替区分
	p_kozatencd				char(4);										--	口座店コード
	p_firstlastkichukbn		char(1);										--	初期・終期・期中区分
	p_calcpatterncd			char(2);				--	計算パターンコード
	p_ssteigakutesukngk		numeric;											--	信託報酬・社管手数料定額手数料
	p_stcalcymd				char(8);										--	計算開始日
	p_edcalcymd				char(8);										--	計算終了日
	p_zndkkijunymd			char(8);										--	残高基準日
	p_billoutymd			char(8);										--	請求書出力日
	p_sstesubunbo			numeric;											--	信託報酬・社債管理手数料率（分母）
	p_sstesubunshi			numeric;											--	信託報酬・社債管理手数料率（分子）
	p_sstesudfbunbo			numeric;											--	信託報酬・社債管理手数料分配率（分母）
	p_ssnenchokyucnt		numeric;											--	信託報酬・社管手数料年徴求回数
	p_datasakuseikbn		char(1);					--	データ作成区分
	p_calcpatterncd2		char(2);			--	計算パターンコード(MG8)
	p_zndkkakuteikbn		char(1);			--	残高確定区分
	p_zengokbn				char(1);					--	前取後取区分
	p_daymonthkbn			char(1);				--	日割月割区分
	p_hasunissucalckbn		char(1);		--	端数日数計算区分（端数期間分母日数計算区分）
	p_calcymdkbn			char(1);				--	計算期間区分
	p_sscalcymd2			char(8);				--	信託報酬・社管手数料_計算期間２
	p_matsuFlg				char(1);	--	信託報酬・社管手数料_計算期間月末フラグ２
	--以下は取得データから計算してセットする項目
	p_outoudd				numeric	:=	0	;							--	応答日
	p_kjnzndk				numeric	:=	0	;							--	基準残高
	p_kikananbun			numeric	:=	0	;							--	期間按分
	p_zentaitesuryozeikomi	numeric	:=	0	;							--	全体手数料額（税込）
	p_zentaitesuryogaku		numeric	:=	0	;							--	全体手数料額（税抜）
	p_zentaitesuryogakuzei	numeric	:=	0	;							--	全体手数料額
	p_hasutsuki				char(6)	:=	'	';							--	端数月
	p_hankanenoutkbn		char(1)	:=	'	';							--	半か年外出し区分
	p_tsukiwarifrom			char(8)	:=	'	';							--	月割期間From
	p_tsukiwarito			char(8)	:=	'	';							--	月割期間To
	p_tsukisu				numeric	:=	0	;							--	月数
	p_hiwarifrom			char(8)	:=	'	';							--	日割期間From
	p_hiwarito				char(8)	:=	'	';							--	日割期間To
	p_nissu					numeric	:=	0	;							--	日数
	p_keisanbibunbo			numeric	:=	0;								--	計算式日（分母）
	p_keisanbibunshi		numeric	:=	0;								--	計算式日（分子）
	p_keisanyydd			pkIpaKichuTesuryo.CH6_ARRAY;										--	計算年月１〜１３
	p_tsukizndk				pkIpaKichuTesuryo.NUM_ARRAY;										--	月毎残高１〜１３
	p_tsukitesuryo			pkIpaKichuTesuryo.NUM_ARRAY;										--	月毎期中手数料１〜１３
	-- 分かち対応により以下の変数を追加 
	 p_wakachi					char(1) := ' ';						-- 分かち計算する(1)・しない(0)
	 p_tsukisu_mae    				numeric	:= 0;						-- 改定前の月数
	 p_tsukisu_ato    				numeric	:= 0;						-- 改定後の月数
	 p_tekiyost_ymd					char(8)	:=	'	';					-- 消費税適用日
	 p_keisanyymmdd					pkIpaKichuTesuryo.CHR_ARRAY;							--計算期間（年月日）※計算開始日〜終了日を月別に分解し、月の先頭日を設定する
	 p_shohizei_sai					char(1) := ' ';						-- 消費税の差異あり(0)・なし(1)
	--以下はデバッグ用
	p_hiwaribunbofrom		char(8)	;										--	分母期間From
	p_hiwaribunboto			char(8)	;										--	分母期間To
	l_return					numeric;
	-- SQL編集
	l_strSql varchar(5000)		:= NULL;
	l_szeiseikyukbn				char(1)	:= '0'; -- 消費税請求区分　0=請求しない 1=請求する
	l_ebymd								char(8)	:= ' '; -- 手数料計算結果テーブルに登録済みのEB作成年月日
	l_ebflg								char(1)	:= ' '; -- 自行・委託会社ビュー の EB送信FLG
	l_szeiprocess				char(1); -- 消費税算出方式（総額：0　従来：1）
	l_heizonseikyukbn			char(1) := 0;
	l_jissu						numeric(2) := 3;
	l_hasuFlg					char(1) := '0'; -- 端数判定フラグ（端数なし：0　端数あり：1）
	l_ssChokyuKyujitsuKbn		char(1);	-- 信託報酬・社管手数料_徴求日休日処理区分
	l_areaCd					varchar(100);									-- 地域コード
	l_ShzKijunYmd				varchar(8);						-- 消費税率適用基準日
	-- 分配手数料の分かち計算で使用するため追加
	l_tesuryo_mae      numeric := 0;     -- 改定前の手数料(税込)
	l_tesuryo_ato      numeric := 0;	 -- 改定後の手数料(税込)
	l_tesuryozei_mae   numeric := 0;	 -- 改定前の消費税
	l_tesuryozei_ato   numeric := 0;	 -- 改定後の消費税
	l_kikan_mae        numeric := 0;     -- 改定前の期間
	l_kikan_ato        numeric := 0;     -- 改定後の期間
	-- カーソル
	curTesuRec REFCURSOR;
	--==============================================================================
	--	メイン処理	
	--==============================================================================
	
BEGIN
		-- 特例社債でかつ徴求日が償還日(振替移行時)より小さい場合は正常終了で処理を抜ける 
		IF SFCALCKICHUHENREI_isUpdate(l_initakukaishacd,l_inmgrcd,l_indate) = 1 THEN
			extra_param := pkconstant.success();
			RETURN;
		END IF;
		-- データ取得 
		l_strSql := pkIpaKichuTesuryo.createGetDataSql(l_initakukaishacd,l_inmgrcd,l_intesucd,l_indate,0);
		OPEN curTesuRec FOR EXECUTE l_strSql;
		LOOP
			FETCH curTesuRec INTO
				p_itakukaishacd,				-- 委託会社コード
				p_mgrcd,						-- 銘柄コード
				p_jtkkbn,						-- 受託区分
				p_tesushuruicd,					-- 手数料種類コード
				p_hakkotsukacd,					-- 発行通貨コード
				p_chokyukjt,					-- 徴求期日
				p_chokyuymd,					-- 徴求日
				p_distriymd,					-- 分配日
				p_hakkoymd,						-- 発行年月日
				p_fullshokanymd,				-- 満期償還日
				p_ebmakeymd,					-- EB作成年月日  -- 徴求日-EB作成日営業日前
				p_ebsendymd,					-- EB送信年月日  -- 徴求日-EB送信日営業日前
				p_nyukinymd,					-- 入金日
				p_tesusashihikikbn,				-- 手数料差引区分
				p_eigyotencd,					-- 営業店コード
				p_kozafurikbn,					-- 口座振替区分
				p_kozatencd,					-- 口座店コード
				p_firstlastkichukbn,			-- 初期・期中・終期区分
				p_calcpatterncd,				-- 計算パターンコード
				p_ssteigakutesukngk,			-- 信託報酬・社管手数料定額手数料
				p_stcalcymd,					-- 計算開始日
				p_edcalcymd,					-- 計算終了日
				p_zndkkijunymd,					-- 残高基準日
				p_billoutymd,					-- 請求書出力日
				p_sstesubunbo,					-- 信託報酬・社債管理手数料率（分母）
				p_sstesubunshi,					-- 信託報酬・社債管理手数料率（分子）
				p_sstesudfbunbo,				-- 信託報酬・社債管理手数料分配率（分母）
				p_ssnenchokyucnt,				-- 信託報酬・社管手数料年徴求回数
				p_datasakuseikbn,				-- データ作成区分
				p_calcpatterncd2,				-- 計算パターンコード
				p_zndkkakuteikbn,				-- 残高確定区分
				p_zengokbn,						-- 前取後取区分
				p_daymonthkbn,					-- 端数日数日割月割区分
				p_hasunissucalckbn,				-- 端数日数計算区分
				p_calcymdkbn,					-- 計算期間区分
				p_sscalcymd2,					-- 信託報酬・社管手数料_計算期間２
				p_matsuFlg,						-- 信託報酬・社管手数料_計算期間月末フラグ２
				l_szeiseikyukbn,				-- 消費税請求区分
				l_ebymd,						-- 手数料計算結果テーブルのEB作成年月日
				l_ebflg,						-- EB作成フラグ
				l_heizonseikyukbn;				-- 並存請求区分
				EXIT WHEN NOT FOUND;/* apply on curTesuRec */
			-- 半か年区分のデフォルト（2=外出しなし）
			p_hankanenoutkbn := '2';
			-- MPROCESS_CTLテーブルより、総額・従来判定フラグを取得する
			l_szeiprocess := pkControl.getCtlValue(l_initakukaishaCd, 'CALCTESUKNGK0', '0');
			-- -----取得データから値を計算および編集----- 
			-- 応答日 
			IF p_ssnenchokyucnt = 0 THEN
				p_ssnenchokyucnt := 1;
			END IF;
			p_outoudd := 12 / (p_ssnenchokyucnt)::numeric;
			-- 基準残高取得 
			--手数料計算の為の基準残高を取得する。(定額方式（4）以外の場合）
			-- 並存銘柄請求書出力区分が'1'の場合は、'3'ではなく'93'を渡す
			IF l_heizonseikyukbn = '1' THEN
				l_jissu := 93; -- 振替債+現登債…93
			ELSE l_jissu := 3; -- 実質残高…3
			END IF;
			-- 信託報酬・社管手数料_徴求日休日処理区分、地域コード 取得（カーソルで取得できない情報）
			SELECT	 MG8.SS_CHOKYU_KYUJITSU_KBN
					,pkDate.getAreaCd(MG1.Kyujitsu_Ld_Flg, MG1.Kyujitsu_Ny_Flg, MG1.Kyujitsu_Etc_Flg, 'N', MG1.ETCKAIGAI_AREA1, MG1.ETCKAIGAI_AREA2, MG1.ETCKAIGAI_AREA3)
			INTO STRICT	 l_ssChokyuKyujitsuKbn
					,l_areaCd
			FROM	 MGR_KIHON MG1
					,MGR_TESURYO_PRM MG8
			WHERE MG1.ITAKU_KAISHA_CD = l_initakukaishacd
			  AND MG1.MGR_CD = l_inmgrcd
			  AND MG1.ITAKU_KAISHA_CD = MG8.ITAKU_KAISHA_CD
			  AND MG1.MGR_CD = MG8.MGR_CD
			;
			l_return :=	pkIpaKichuTesuryo.getZndk(l_initakukaishacd,
							l_inmgrcd,
							pkDate.calcDateKyujitsuKbn(p_chokyukjt ,0  ,l_ssChokyuKyujitsuKbn, l_areaCd),	--銘柄_手数料回次.徴求期日の休日補正後時点
							p_stcalcymd,
							p_edcalcymd,
							p_hakkoymd,
							p_fullshokanymd,
							p_calcpatterncd,
							p_zndkkakuteikbn,
							l_jissu,
							p_kjnzndk,
							p_keisanyydd,
							p_tsukizndk);
			IF l_return <> pkconstant.success() THEN
				extra_param := pkconstant.FATAL();
				RETURN;
			END IF;
			-- 月割・日割期間From−Toの初期化
			p_tsukiwarifrom := ' ';
			p_tsukiwarito   := ' ';
			p_hiwarifrom    := ' ';
			p_hiwarito      := ' ';
			p_tsukisu       :=  0;
			p_hasutsuki     := ' ';
			--端数判定フラグの初期化
			l_hasuFlg := '0';
			-- 月数、月割部分From-To、端数月 
			--端数期間日割月割区分＝「月割日割」（1）、「月割」（3）、「日割（端数期間のみ）」（4）の場合のみ取得
			IF p_daymonthkbn IN ('1','3','4') THEN
				l_return := pkIpaKichuTesuryo.getMonthFromTo(p_stcalcymd,
									p_edcalcymd,
									p_daymonthkbn,
									p_calcymdkbn,
									p_matsuFlg,		-- 計算期間月末フラグ２
									p_firstlastkichukbn,
									p_outoudd,
									p_sscalcymd2,
									p_tsukiwarifrom,
									p_tsukiwarito,
									p_tsukisu,
									p_hasutsuki);
				IF l_return <> pkconstant.success() THEN
					extra_param := pkconstant.FATAL();
					RETURN;
				END IF;
				--端数期間日割月割区分＝「日割（端数期間のみ）」（4）の場合、端数判定を行う
				IF p_daymonthkbn = '4' THEN
					--端数判定
					IF coalesce(trim(both p_hasutsuki)::text, '') = '' THEN
						IF p_outoudd != p_tsukisu THEN
							--端数月が設定されていないかつ月数!=12/年徴求回数の場合は「端数あり」
							l_hasuFlg := '1';
						END IF;
					ELSE
						--端数月が設定されている場合は「端数あり」
						l_hasuFlg := '1';
					END IF;
				END IF;
				--「端数あり」の場合、月割・日割期間From−Toの初期化を初期化
				IF l_hasuFlg = '1' THEN
					p_tsukiwarifrom := ' ';
					p_tsukiwarito   := ' ';
					p_hiwarifrom    := ' ';
					p_hiwarito      := ' ';
					p_tsukisu       :=  0;
					p_hasutsuki     := ' ';
				END IF;
			END IF;
			-- 端数期間日割月割区分＝「月割日割」（1）、「日割」（2）、
			--「日割（端数期間のみ）」（4）かつ「端数あり」の場合のみ
			-- 日数取得 と 期間按分取得 を行う
			-- 変数初期化
			p_hiwarifrom      := ' ';			-- 分子期間From
			p_hiwarito        := ' ';			-- 分子期間To
			p_nissu           := 0;				-- 日数
			p_hankanenoutkbn  := '2';			-- 半か年区分
			p_keisanbibunshi  := 0;				-- 期間按分分子
			p_hiwaribunbofrom := ' ';			-- 分母期間From
			p_hiwaribunboto   := ' ';			-- 分母期間To
			p_keisanbibunbo   := 0;				-- 期間按分分母
			p_kikananbun      := 0;				-- 期間按分
			IF p_daymonthkbn IN ('1','2') OR (p_daymonthkbn = '4' AND l_hasuFlg = '1') THEN
				-- 日割部分From-To、日数 
				l_return := pkIpaKichuTesuryo.getDateFromTo(p_stcalcymd,
								p_edcalcymd,
								p_daymonthkbn,
								p_calcymdkbn,
								p_matsuFlg,		-- 計算期間月末フラグ２
								p_tsukiwarifrom,
								p_tsukiwarito,
								p_tsukisu,
								p_hasutsuki,
								p_firstlastkichukbn,
								p_hasunissucalckbn,
								p_outoudd,
								p_sscalcymd2,
								p_hiwarifrom,
								p_hiwarito,
								p_nissu,
								p_hankanenoutkbn);
				IF l_return <> pkconstant.success() THEN
					extra_param := pkconstant.FATAL();
					RETURN;
				END IF;
				-- 期間按分、期間按分分子、期間按分分母、日割部分From-To、半か年外出し区分 取得 
				l_return := pkIpaKichuTesuryo.getKikanAnbun(p_hiwarifrom,
														p_hiwarito,
														p_ssnenchokyucnt,
														p_hasunissucalckbn,
														p_matsuFlg,				-- 計算期間月末フラグ２
														p_firstlastkichukbn,
														p_hankanenoutkbn,
														p_sscalcymd2,
														p_kikananbun,			-- 期間按分
														p_hiwarifrom,			-- 分子期間From
														p_hiwarito,				-- 分子期間To
														p_keisanbibunshi,		-- 期間按分分子
														p_hiwaribunbofrom,		-- 分母期間From
														p_hiwaribunboto,		-- 分母期間To
														p_keisanbibunbo);		-- 期間按分分母
				IF l_return <> pkconstant.success() THEN
					extra_param := pkconstant.FATAL();
					RETURN;
				END IF;
			END IF;
			-- 手数料計算前の準備 
			-- 月割期間From-Toが無い場合は月数（月割期間分子）を初期化
			IF coalesce(trim(both p_tsukiwarifrom || p_tsukiwarito)::text, '') = '' THEN
				p_tsukisu := 0;
			END IF;
			--****************************
			-- 分かち計算を行う処理を追加 
			--****************************
			-- 月数取得(分かち計算用）を実行する。
			p_tsukisu_mae  := 0;
			p_tsukisu_ato  := 0;
			p_wakachi := '0';	--分かち計算しないを設定
			p_shohizei_sai := '0';  -- 消費税の差異　差異あり(初期値:0)を設定
			l_return := pkIpaKichuTesuryo.getMonthFromTo_Wakachi(
					l_initakukaishaCd,	--委託会社コード
					p_stcalcymd,	--計算開始日
					p_edcalcymd,	--計算終了日
					p_tsukisu,
					p_firstlastkichukbn,
					l_szeiseikyukbn,	-- 消費税を請求する(1)・しない(0)
					p_keisanyymmdd,
					p_tsukisu_mae,  --改定前の月数
					p_tsukisu_ato,  --改定後の月数
					p_wakachi,	--分かち計算する・しない
					p_tekiyost_ymd, --消費税適用日
					p_shohizei_sai  --消費税率の差異あり・なし ※差異なし=1 差異あり=0
					);
			IF l_return <> pkconstant.success() THEN
				extra_param := pkconstant.FATAL();
				RETURN;
			END IF;
			-- 分かち計算する場合 
			IF p_wakachi = '1' THEN
				-- 手数料計算(分かち計算用）を実行する。
				l_return := pkIpaKichuTesuryo.calcTesuryo_Wakachi(
								 l_szeiprocess,
								 p_stcalcymd,
								 p_tsukiwarifrom,
								 p_hiwarifrom,
								 p_calcpatterncd,
								 p_tsukisu,
								 p_kjnzndk,
								 p_ssteigakutesukngk,
								 p_sstesubunshi,
								 p_sstesubunbo,
								 p_chokyuymd,
								 p_hakkotsukacd,
								 p_keisanyydd,
								 p_tsukizndk,
								 p_keisanbibunshi,
								 p_keisanbibunbo,
								 p_hasunissucalckbn,
								 p_ssnenchokyucnt,
								 p_edcalcymd,   --計算終了日
								 p_tsukisu_mae, --改定前の月数
								 p_tsukisu_ato, --改定後の月数
								 p_tekiyost_ymd, --改定後の消費税適用日
								 p_keisanyymmdd,  -- 計算期間（年月日）※月別に設定
								 p_zentaitesuryozeikomi, --全体手数料額(税込)
								 p_zentaitesuryogakuzei, --消費税額
								 p_zentaitesuryogaku,	 --手数料額(税抜)
								 p_tsukitesuryo, --月毎手数料1〜13
								 l_tesuryo_mae,	-- 改定前の手数料(税込)
								 l_tesuryo_ato,	-- 改定後の手数料(税込)
								 l_tesuryozei_mae, -- 改定前の消費税
								 l_tesuryozei_ato, -- 改定後の消費税
								 l_kikan_mae,      -- 改定前の期間
								 l_kikan_ato        -- 改定後の期間
						);
			ELSE
				-- 発行時一括の場合
				IF coalesce(trim(both p_calcpatterncd)::text, '') = '' THEN
					-- 発行日を取得する
					l_ShzKijunYmd := pkIpacalctesuryo.getHakkoYmd(p_itakukaishacd,p_mgrcd);
				ELSE
					-- 分かち計算ありで消費税の差異がない場合
					IF p_shohizei_sai = '1' THEN
						-- 基準日に計算開始日を設定
						l_ShzKijunYmd := p_stcalcymd;
					-- 分かち計算なし場合
					ELSE
						-- 基準日に徴求日を設定
						l_ShzKijunYmd := p_chokyuymd;
					END IF;
				END IF;
				-- 期中手数料・月毎期中手数料(1〜13)を計算する 
				l_return := pkIpaKichuTesuryo.calcTesuryo(
								 l_szeiprocess,
								 p_stcalcymd,
								 p_tsukiwarifrom,
								 p_hiwarifrom,
								 p_calcpatterncd,
								 p_tsukisu,
								 p_kjnzndk,
								 p_ssteigakutesukngk,
								 p_sstesubunshi,
								 p_sstesubunbo,
								 l_ShzKijunYmd,
								 p_hakkotsukacd,
								 l_szeiseikyukbn,
								 p_keisanyydd,
								 p_tsukizndk,
								 p_keisanbibunshi,
								 p_keisanbibunbo,
								 p_hasunissucalckbn,
								 p_ssnenchokyucnt,
								 p_zentaitesuryozeikomi,		--手数料額(税込)
								 p_zentaitesuryogakuzei,		--消費税額
								 p_zentaitesuryogaku,			--手数料額(税抜)
								 p_tsukitesuryo);			--月毎手数料1〜13
			END IF;
		l_outallhenreikngk := l_allinkngk - p_zentaitesuryozeikomi;
		l_outzeinukihenreikngk := l_zeinukiinkngk - p_zentaitesuryogaku;
		l_outszeihenreikngk := l_szeiinkngk - p_zentaitesuryogakuzei;
		END LOOP;
		CLOSE curTesuRec;
		-- 正常戻り値
		extra_param := pkconstant.success();
		RETURN;
		EXCEPTION
			WHEN OTHERS THEN
				CALL PKLOG.ERROR('ECM701','PKIPAKICHUTESURYO',SQLSTATE);
				CALL PKLOG.ERROR('ECM701','PKIPAKICHUTESURYO',SQLERRM);
				extra_param := pkconstant.FATAL();
				RETURN;
	END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfcalckichuhenrei ( l_initakukaishacd CHAR , l_inmgrcd CHAR , l_intesucd CHAR , l_indate CHAR, l_allinkngk numeric, l_zeinukiinkngk numeric, l_szeiinkngk numeric, l_outallhenreikngk OUT numeric, l_outzeinukihenreikngk OUT numeric, l_outszeihenreikngk OUT numeric , OUT extra_param numeric) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfcalckichuhenrei_getcode (l_insyubetsu CHAR ,l_incdvalue CHAR) RETURNS varchar AS $body$
DECLARE

	l_tmpret varchar(20)	:= NULL;
	
BEGIN
		SELECT CODE_NM INTO STRICT l_tmpret
			FROM SCODE
		WHERE CODE_SHUBETSU = l_insyubetsu
		AND   CODE_VALUE    = l_incdvalue;
		RETURN l_tmpret;
	END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfcalckichuhenrei_getcode (l_insyubetsu CHAR ,l_incdvalue CHAR) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfcalckichuhenrei_isupdate (l_inItakuKaishaCd text ,l_inMgrCd text,l_inDate text) RETURNS integer AS $body$
DECLARE

wk_tokureiShasaiFlg			char(1);
wk_shokanYmd				char(8);

BEGIN
-- 特例社債フラグ取得 
SELECT	MG1.TOKUREI_SHASAI_FLG
INTO STRICT	wk_tokureiShasaiFlg
FROM	MGR_KIHON MG1
WHERE	MG1.ITAKU_KAISHA_CD = l_inItakuKaishaCd
AND		MG1.MGR_CD          = l_inMgrCd;
-- 償還日取得 
SELECT	coalesce(trim(both MIN(Z01.SHOKAN_YMD)),'99999999')
INTO STRICT	wk_shokanYmd
FROM	Gensai_Rireki Z01
WHERE	Z01.ITAKU_KAISHA_CD = l_inItakuKaishaCd
AND		Z01.MGR_CD          = l_inMgrCd
AND		Z01.SHOKAN_KBN = '01';
-- 特例社債でかつ徴求日が償還日(振替移行時)より小さい場合、更新処理をしない 
IF  wk_tokureiShasaiFlg = 'Y' AND wk_shokanYmd > l_inDate THEN
	RETURN 1;
ELSE
	RETURN 0;
END IF;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfcalckichuhenrei_isupdate (l_inItakuKaishaCd text ,l_inMgrCd text,l_inDate text) FROM PUBLIC;