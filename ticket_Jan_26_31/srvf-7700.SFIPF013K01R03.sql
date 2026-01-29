




CREATE OR REPLACE FUNCTION sfipf013k01r03 () RETURNS integer AS $body$
DECLARE

--*
-- * 著作権: Copyright (c) 2005
-- * 会社名: JIP
-- *
-- * ①勘定系リアル受信IFを読み込み、勘定系代り金IF、勘定系元利金・手数料IFと照合する。
-- * ②元利金・手数料の受信データの場合、基金異動履歴の入金状況区分を更新する。
-- * ③受信データは、勘定系リアル受信保存IFへコピーする。
-- * ④完了後、勘定計系リアル受信IFの送信ステータスを'1'(送信済)に更新する。
-- * ⑤勘定系接続ステータス.受信接続フラグを'2'にして処理し、処理後'1'に更新する。
-- *
-- * @author 小林　弘幸
-- * @version $Revision: 1.8 $
-- * $Id: SFIPF013K01R03.sql,v 1.8 2005/11/04 10:12:04 kubo Exp $
-- * @return INTEGER
-- *                0:正常終了、データ無し
-- *                1:予期したエラー
-- *               99:予期せぬエラー
-- 
--==============================================================================
--                  変数定義                                                    
--==============================================================================
	iRet					integer;							 -- リターン値
	nCount					numeric;								 -- 対象データの件数
	nCnt_hakko				numeric;								 -- 勘定系発行代り金IF.件数
	nCnt_ganri				numeric;								 -- 勘定系元利金・手数料IF.件数
	nSqlCode				numeric;								 -- リターン値
	cGyoumuDt				ssystem_management.gyomu_ymd%type;	 -- 業務日付
	cItaku_kaisha_cd		sown_info.kaiin_id%type;			 -- 委託会社コード
	cHkt_cd					knjganrikichuif.hkt_cd%type;		 -- 勘定系元利金・手数料IF.発行体コード
	cKnj_shori_kbn			knjganrikichuif.knj_shori_kbn%type;	 -- 勘定系元利金・手数料IF.処理区分（勘定系）
	cKnj_shori_ymd			knjganrikichuif.knj_shori_ymd%type;	 -- 勘定系元利金・手数料IF.処理日
	cKnj_inout_kbn_ganri	knjganrikichuif.knj_inout_kbn%type;	 -- 勘定系元利金・手数料IF.入出金区分(勘定系)
	cKnj_inout_kbn_hakko	knjhakkouif.knj_inout_kbn%type;		 -- 勘定系発行代り金IF.入出金区分(勘定系)
	vSql					varchar(1000);						 -- ＳＱＬ格納用
	vSqlErrM				varchar(200);						 -- エラーメッセージ
	vMsgLog					varchar(300);						 -- ログ出力用メッセージ
	vMsgTsuchi				varchar(300);						 -- メッセージ通知用メッセージ
	vTableName				varchar(300);						 -- テーブル名称
	vMsg_Err_list			varchar(300);						 -- エラーリスト用メッセージ
--==============================================================================
--                  カーソル定義                                                
--==============================================================================
	-- 勘定系リアル受信IFから対象データを抽出する
	curRcv CURSOR FOR
		SELECT data_id,
			   make_dt,
			   data_seq,
			   knj4tr_uke_id,
			   knj4tr_uke_tsuban,
			   knj4tr3,
			   knj4tr_err,
			   knj4tr5,
			   sr_stat
		FROM knjrealrcvif
		WHERE sr_stat = '0'
		ORDER BY knj4tr_uke_tsuban;
--==============================================================================
--                  メイン処理                                                  
--==============================================================================
BEGIN
	-- 業務日付を取得
	cGyoumuDt := pkDate.getGyomuYmd();
	-- 委託会社コードを取得
	SELECT kaiin_id
	INTO STRICT cItaku_kaisha_cd
	FROM sown_info;
	-- 勘定系接続ステータスの勘定IF受信接続フラグを'2'に更新
	UPDATE knjsetuzokustatus
	SET knjif_recv = '2', kousin_dt = CURRENT_TIMESTAMP, kousin_id = 'BATCH';
	-- COMMIT; -- PostgreSQL does not allow COMMIT in functions
	-- 対象データ件数チェック
	nCount := 0;
	SELECT count(*)
	INTO STRICT nCount
	FROM knjrealrcvif
	WHERE sr_stat = '0';
	-- 対象データがある場合のみ、以下の処理を行う
	IF nCount != 0 THEN
		FOR recRcv IN curRcv LOOP
			-- 変数初期化
			iRet := 0;
			nCnt_hakko := 0;
			nCnt_ganri := 0;
			nSqlCode := 0;
			cHkt_cd := '';
			cKnj_shori_kbn := '';
			cKnj_shori_ymd := '';
			cKnj_inout_kbn_hakko := '';
			cKnj_inout_kbn_ganri := '';
			vSqlErrM := '';
			vMsgLog := '';
			vMsgTsuchi := '';
			vTableName := '';
			vMsg_Err_list := '';
			-- 勘定系リアル受信保存IFへ追加
			INSERT INTO knjrealrcvsaveif(
				data_id,
				make_dt,
				data_seq,
				knj4tr_uke_id,
				knj4tr_uke_tsuban,
				knj4tr3,
				knj4tr_err,
				knj4tr5
			)
			VALUES (
				recRcv.data_id,
				recRcv.make_dt,
				recRcv.data_seq,
				recRcv.knj4tr_uke_id,
				recRcv.knj4tr_uke_tsuban,
				recRcv.knj4tr3,
				recRcv.knj4tr_err,
				recRcv.knj4tr5
			);
			-- 対象データを勘定系発行代り金IFと照合する
			nCnt_hakko := 0;
			SELECT count(*)
			INTO STRICT nCnt_hakko
			FROM knjhakkouif
			WHERE itaku_kaisha_cd = cItaku_kaisha_cd
			AND trim(both TO_CHAR(knj_uke_tsuban, '0000000009')) = recRcv.knj4tr_uke_tsuban;
			IF nCnt_hakko != 0 THEN
				-- 入出金区分を取得する
				SELECT knj_inout_kbn
				INTO STRICT cKnj_inout_kbn_hakko
				FROM knjhakkouif
				WHERE itaku_kaisha_cd = cItaku_kaisha_cd
				AND trim(both TO_CHAR(knj_uke_tsuban, '0000000009')) = recRcv.knj4tr_uke_tsuban;
				-- 受信エラーがない('0000')場合、入出金区分を取得する
				IF recRcv.knj4tr_err = '0000' THEN
					-- 入出金区分(勘定系)の値をチェック
					-- '1'(未入金)の場合、'4'（入金済）に更新する
					IF cKnj_inout_kbn_hakko = '1' THEN
						UPDATE knjhakkouif
						SET knj_inout_kbn = '4',
							kousin_dt = CURRENT_TIMESTAMP,
							kousin_id = 'BATCH'
						WHERE itaku_kaisha_cd = cItaku_kaisha_cd
						AND trim(both TO_CHAR(knj_uke_tsuban, '0000000009')) = recRcv.knj4tr_uke_tsuban;
					-- '3'（未取消）の場合、'6'（取消済）に更新する
					ELSIF cKnj_inout_kbn_hakko = '3' THEN
						UPDATE knjhakkouif
						SET knj_inout_kbn = '6',
							kousin_dt = CURRENT_TIMESTAMP,
							kousin_id = 'BATCH'
						WHERE itaku_kaisha_cd = cItaku_kaisha_cd
						AND trim(both TO_CHAR(knj_uke_tsuban, '0000000009')) = recRcv.knj4tr_uke_tsuban;
					-- '4'（入金済）の場合、再処理フラグを'1'に、取消フラグを'1'にする
					ELSIF cKnj_inout_kbn_hakko = '4' THEN
						iRet := SFIPF013K01R03_COMMON_ERROR(
									'4',
									'knjhakkouif',
									recRcv.knj4tr_err,
									recRcv.knj4tr_uke_tsuban,
									cKnj_inout_kbn_hakko,
									'勘定系発行代り金ＩＦ',
									'EIP517'
								,
            cItaku_kaisha_cd,
            cGyoumuDt
        );
						IF iRet = pkconstant.fatal() THEN
							RETURN pkconstant.fatal();
						END IF;
					END IF;
				ELSE
					-- エラーコード='D001'の場合、
					IF recRcv.knj4tr_err = 'D001' THEN
						-- 入出金区分(勘定系)='1'の場合
						IF cKnj_inout_kbn_hakko = '1' THEN
							-- 勘定系発行代り金IFの再処理フラグを'1'にする
							iRet := SFIPF013K01R03_COMMON_ERROR(
										'1',
										'knjhakkouif',
										recRcv.knj4tr_err,
										recRcv.knj4tr_uke_tsuban,
										cKnj_inout_kbn_hakko,
										'勘定系発行代り金ＩＦ'
									,
             cItaku_kaisha_cd,
             cGyoumuDt
         );
							IF iRet = pkconstant.fatal() THEN
								RETURN pkconstant.fatal();
							END IF;
						-- 入出金区分(勘定系)='3'の場合
						ELSIF cKnj_inout_kbn_hakko = '3' THEN
							-- 勘定系発行代り金IFのエラーコード(勘定系）へセット
							iRet := SFIPF013K01R03_COMMON_ERROR(
										'2',
										'knjhakkouif',
										recRcv.knj4tr_err,
										recRcv.knj4tr_uke_tsuban,
										cKnj_inout_kbn_hakko,
										'勘定系発行代り金ＩＦ'
									,
             cItaku_kaisha_cd,
             cGyoumuDt
         );
							IF iRet = pkconstant.fatal() THEN
								RETURN pkconstant.fatal();
							END IF;
						-- 入出金区分(勘定系)='4'又は'6'の場合
						ELSIF cKnj_inout_kbn_hakko = '4' OR cKnj_inout_kbn_hakko = '6' THEN
							-- 勘定系発行代り金IFのエラーコード(勘定系）へセット、エラー処理
							iRet := SFIPF013K01R03_COMMON_ERROR(
										'3',
										'knjhakkouif',
										recRcv.knj4tr_err,
										recRcv.knj4tr_uke_tsuban,
										cKnj_inout_kbn_hakko,
										'勘定系発行代り金ＩＦ',
										'EIP518'
									,
             cItaku_kaisha_cd,
             cGyoumuDt
         );
							IF iRet = pkconstant.fatal() THEN
								RETURN pkconstant.fatal();
							END IF;
						END IF;
					-- エラーコードが上記以外の場合、
					ELSE
						-- 入出金区分(勘定系)='1'又は'3'の場合
						IF cKnj_inout_kbn_hakko = '1' OR cKnj_inout_kbn_hakko = '3' THEN
							-- 勘定系発行代り金IFのエラーコード(勘定系）へセット
							iRet := SFIPF013K01R03_COMMON_ERROR(
										'2',
										'knjhakkouif',
										recRcv.knj4tr_err,
										recRcv.knj4tr_uke_tsuban,
										cKnj_inout_kbn_hakko,
										'勘定系発行代り金ＩＦ'
									,
             cItaku_kaisha_cd,
             cGyoumuDt
         );
							IF iRet = pkconstant.fatal() THEN
								RETURN pkconstant.fatal();
							END IF;
						-- 入出金区分(勘定系)='4'又は'6'の場合
						ELSIF cKnj_inout_kbn_hakko = '4' OR cKnj_inout_kbn_hakko = '6' THEN
							-- 勘定系発行代り金IFのエラーコード(勘定系）へセット、エラー処理
							iRet := SFIPF013K01R03_COMMON_ERROR(
										'3',
										'knjhakkouif',
										recRcv.knj4tr_err,
										recRcv.knj4tr_uke_tsuban,
										cKnj_inout_kbn_hakko,
										'勘定系発行代り金ＩＦ',
										'EIP518'
									,
             cItaku_kaisha_cd,
             cGyoumuDt
         );
							IF iRet = pkconstant.fatal() THEN
								RETURN pkconstant.fatal();
							END IF;
						END IF;
					END IF;
				END IF;
			END IF;
			-- 対象データを勘定系元利金・手数料IFと照合する
			nCnt_ganri := 0;
			SELECT count(*)
			INTO STRICT nCnt_ganri
			FROM knjganrikichuif
			WHERE itaku_kaisha_cd = cItaku_kaisha_cd
			AND trim(both TO_CHAR(knj_uke_tsuban, '0000000009')) = recRcv.knj4tr_uke_tsuban;
			-- 照合エラー時の処理
			IF nCnt_hakko = 0 AND nCnt_ganri = 0 THEN
				-- エラー処理
				-- ログ出力用メッセージ
				vMsgLog := '＜受付通番:' || recRcv.knj4tr_uke_tsuban || '＞';
				-- メッセージ通知用メッセージ
				vMsgTsuchi := '該当の受付通番は存在しません。＜受付通番:' || recRcv.knj4tr_uke_tsuban || '＞';
				-- エラーリスト用テーブル名称
				vTableName := '勘定系(発行代り金、元利金・手数料)ＩＦ';
				-- エラーリスト用メッセージ
				vMsg_Err_list := '＜受付通番:' || recRcv.knj4tr_uke_tsuban || '＞';
				iRet := SFIPF013K01R03_COMMON_FUNC(
							'ECM503',
							vMsgLog,
							vMsgTsuchi,
							vTableName,
							vMsg_Err_list,
							recRcv.knj4tr_uke_tsuban
						,
          cItaku_kaisha_cd,
          cGyoumuDt
      );
				IF iRet = pkconstant.fatal() THEN
					RETURN pkconstant.fatal();
				END IF;
			END IF;
			-- 対象データが勘定系元利金・手数料IFに存在した場合
			IF nCnt_ganri != 0 THEN
				SELECT knj_inout_kbn,
					   knj_shori_kbn,
					   knj_shori_ymd,
					   hkt_cd
				INTO STRICT cKnj_inout_kbn_ganri,
					 cKnj_shori_kbn,
					 cKnj_shori_ymd,
					 cHkt_cd
				FROM knjganrikichuif
				WHERE itaku_kaisha_cd = cItaku_kaisha_cd
				AND trim(both TO_CHAR(knj_uke_tsuban, '0000000009')) = recRcv.knj4tr_uke_tsuban;
				-- 受信エラーがない('0000')場合、データを取得する
				IF recRcv.knj4tr_err = '0000' THEN
					-- 入出金区分(勘定系)の値をチェック
					-- '2'の場合、'5'に更新する
					IF cKnj_inout_kbn_ganri = '2' THEN
						-- 処理区分（勘定系）のチェック
						IF cKnj_shori_kbn = '2' THEN
							-- 基金異動履歴更新ＳＰをＣａｌｌする
							iRet := SFIPF014K01R02(cItaku_kaisha_cd, cKnj_shori_ymd, cHkt_cd);
							-- 戻り値が'0'の場合
							IF iRet = pkconstant.success() THEN
								UPDATE knjganrikichuif
								SET knj_inout_kbn = '5',
									kousin_dt = CURRENT_TIMESTAMP,
									kousin_id = 'BATCH'
								WHERE itaku_kaisha_cd = cItaku_kaisha_cd
								AND trim(both TO_CHAR(knj_uke_tsuban, '0000000009')) = recRcv.knj4tr_uke_tsuban;
							-- 戻り値が'1'の場合
							ELSIF iRet = pkconstant.error() THEN
								-- エラー処理
								-- ログ出力用メッセージ
								vMsgLog := '＜受付通番:' || recRcv.knj4tr_uke_tsuban || '＞' ||
										   '＜処理日:' || cKnj_shori_ymd ||
										   ',発行体コード:' || cHkt_cd || '＞';
								-- メッセージ通知用メッセージ
								vMsgTsuchi := 'パラメータエラーです。' ||
											  '＜受付通番:' || recRcv.knj4tr_uke_tsuban || '＞' ||
											  '＜処理日:' || cKnj_shori_ymd ||
											  '、発行体:' || cHkt_cd || '＞';
								-- エラーリスト用テーブル名称
								vTableName := ' ';
								-- エラーリスト用メッセージ
								vMsg_Err_list := '＜受付通番:' || recRcv.knj4tr_uke_tsuban || '＞' ||
												 '＜処理日:' || cKnj_shori_ymd ||
												 ',発行体コード:' || cHkt_cd || '＞';
								iRet := SFIPF013K01R03_COMMON_FUNC(
											'ECM501',
											vMsgLog,
											vMsgTsuchi,
											vTableName,
											vMsg_Err_list,
											recRcv.knj4tr_uke_tsuban
										,
              cItaku_kaisha_cd,
              cGyoumuDt
          );
								IF iRet = pkconstant.fatal() THEN
									RETURN pkconstant.fatal();
								END IF;
							-- 戻り値が'99'の場合
							ELSIF iRet = pkconstant.fatal() THEN
								-- ログ出力
								CALL pkLog.fatal(
									'ECM701',
									'IPF013K01R03',
									'基金異動履歴更新エラー'
								);
								RETURN pkconstant.fatal();
							END IF;
						ELSE
							UPDATE knjganrikichuif
							SET knj_inout_kbn = '5',
								kousin_dt = CURRENT_TIMESTAMP,
								kousin_id = 'BATCH'
							WHERE itaku_kaisha_cd = cItaku_kaisha_cd
							AND trim(both TO_CHAR(knj_uke_tsuban, '0000000009')) = recRcv.knj4tr_uke_tsuban;
						END IF;
					-- '3'の場合、'6'に更新する
					ELSIF cKnj_inout_kbn_ganri = '3' THEN
						UPDATE knjganrikichuif
						SET knj_inout_kbn = '6',
							kousin_dt = CURRENT_TIMESTAMP,
							kousin_id = 'BATCH'
						WHERE itaku_kaisha_cd = cItaku_kaisha_cd
						AND trim(both TO_CHAR(knj_uke_tsuban, '0000000009')) = recRcv.knj4tr_uke_tsuban;
					-- '5'の場合、再処理フラグを'1'、取消フラグを'1'にし、エラー処理
					ELSIF cKnj_inout_kbn_ganri = '5' THEN
						iRet := SFIPF013K01R03_COMMON_ERROR(
									'4',
									'knjganrikichuif',
									recRcv.knj4tr_err,
									recRcv.knj4tr_uke_tsuban,
									cKnj_inout_kbn_ganri,
									'勘定系元利金・手数料ＩＦ',
									'EIP517'
								,
            cItaku_kaisha_cd,
            cGyoumuDt
        );
						IF iRet = pkconstant.fatal() THEN
							RETURN pkconstant.fatal();
						END IF;
					END IF;
				-- エラーコード='0906' OR '0907' OR '0974' OR 'D001' の場合
				ELSIF recRcv.knj4tr_err = '0906' OR recRcv.knj4tr_err = '0907'
				   OR recRcv.knj4tr_err = '0974' OR recRcv.knj4tr_err = 'D001' THEN
					-- 入出金区分(勘定系)='2'の場合
					IF cKnj_inout_kbn_ganri = '2' THEN
						-- 勘定系元利金・手数料IFの再処理フラグを'1'にする
						iRet := SFIPF013K01R03_COMMON_ERROR(
									'1',
									'knjganrikichuif',
									recRcv.knj4tr_err,
									recRcv.knj4tr_uke_tsuban,
									cKnj_inout_kbn_ganri,
									'勘定系元利金・手数料ＩＦ'
								,
            cItaku_kaisha_cd,
            cGyoumuDt
        );
						IF iRet = pkconstant.fatal() THEN
							RETURN pkconstant.fatal();
						END IF;
					-- 入出金区分(勘定系)='3'の場合
					ELSIF cKnj_inout_kbn_ganri = '3' THEN
						-- 勘定系元利金・手数料IFのエラーコード(勘定系）へセット
						iRet := SFIPF013K01R03_COMMON_ERROR(
									'2',
									'knjganrikichuif',
									recRcv.knj4tr_err,
									recRcv.knj4tr_uke_tsuban,
									cKnj_inout_kbn_ganri,
									'勘定系元利金・手数料ＩＦ'
								,
            cItaku_kaisha_cd,
            cGyoumuDt
        );
						IF iRet = pkconstant.fatal() THEN
							RETURN pkconstant.fatal();
						END IF;
					-- 入出金区分(勘定系)='5'又は'6'の場合
					ELSIF cKnj_inout_kbn_ganri = '5' OR cKnj_inout_kbn_ganri = '6' THEN
						-- 勘定系元利金・手数料IFのエラーコード(勘定系）へセット、エラー処理
						iRet := SFIPF013K01R03_COMMON_ERROR(
									'3',
									'knjganrikichuif',
									recRcv.knj4tr_err,
									recRcv.knj4tr_uke_tsuban,
									cKnj_inout_kbn_ganri,
									'勘定系元利金・手数料ＩＦ',
									'EIP518'
								,
            cItaku_kaisha_cd,
            cGyoumuDt
        );
						IF iRet = pkconstant.fatal() THEN
							RETURN pkconstant.fatal();
						END IF;
					END IF;
				-- エラーコードが上記以外の場合、
				ELSE
					-- 入出金区分(勘定系)='2'又は'3'の場合
					IF cKnj_inout_kbn_ganri = '2' OR cKnj_inout_kbn_ganri = '3' THEN
						-- 勘定系元利金・手数料IFのエラーコード(勘定系）へセット
						iRet := SFIPF013K01R03_COMMON_ERROR(
									'2',
									'knjganrikichuif',
									recRcv.knj4tr_err,
									recRcv.knj4tr_uke_tsuban,
									cKnj_inout_kbn_ganri,
									'勘定系元利金・手数料ＩＦ'
								,
            cItaku_kaisha_cd,
            cGyoumuDt
        );
						IF iRet = pkconstant.fatal() THEN
							RETURN pkconstant.fatal();
						END IF;
					-- 入出金区分(勘定系)='5'又は'6'の場合
					ELSIF cKnj_inout_kbn_ganri = '5' OR cKnj_inout_kbn_ganri = '6' THEN
						-- 勘定系元利金・手数料IFのエラーコード(勘定系）へセット、エラー処理
						iRet := SFIPF013K01R03_COMMON_ERROR(
									'3',
									'knjganrikichuif',
									recRcv.knj4tr_err,
									recRcv.knj4tr_uke_tsuban,
									cKnj_inout_kbn_ganri,
									'勘定系元利金・手数料ＩＦ',
									'EIP518'
								,
            cItaku_kaisha_cd,
            cGyoumuDt
        );
						IF iRet = pkconstant.fatal() THEN
							RETURN pkconstant.fatal();
						END IF;
					END IF;
				END IF;
			END IF;
			-- 勘定系リアル受信IFの送受信ステータスを更新する
			UPDATE knjrealrcvif
			SET sr_stat = '1'
			WHERE knj4tr_uke_tsuban = recRcv.knj4tr_uke_tsuban;
		END LOOP;
	END IF;
	-- 勘定系接続ステータスの勘定IF受信接続フラグを'1'にする
	UPDATE knjsetuzokustatus
	SET knjif_recv = '1', kousin_dt = CURRENT_TIMESTAMP, kousin_id = 'BATCH';
	RETURN pkconstant.success();
--==============================================================================
--                  エラー処理                                                  
--==============================================================================
EXCEPTION
	WHEN OTHERS THEN
		-- ログ出力
		CALL pkLog.fatal(
			'ECM701',
			'IPF013K01R03',
			'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')'
		);
		RETURN pkconstant.fatal();
--		RAISE;
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf013k01r03 () FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipf013k01r03_common_error (
	l_inShoriKbn TEXT,				-- 処理区分
	l_inTableName TEXT,				-- テーブル名
	l_inErrCode TEXT,				-- エラーコード
	l_inUkeTuban TEXT,				-- 受付通番
	l_inInoutKbn TEXT,				-- 入出金区分
	l_inMeisyou TEXT,				-- テーブル名称
	l_inCItaku_kaisha_cd TEXT,		-- 委託会社コード
	l_inCGyoumuDt char(8),			-- 業務日付
	l_inMsgId TEXT DEFAULT NULL		-- メッセージID
) RETURNS integer AS $body$
DECLARE
	vSql text;
	vMsgLog text;
	vMsgTsuchi text;
	vTableName text;
	vMsg_Err_list text;
	iRet integer;
BEGIN
	-- 処理区分が'1'の場合、エラーコードを設定し再処理フラグを'1'に更新
	IF l_inShoriKbn = '1' THEN
		vSql := '';
		vSql := 'UPDATE ' || l_inTableName || ' ';
		vSql := vSql || ' SET knj_err_code = ' || '''' || l_inErrCode || '''';
		vSql := vSql || ', knj_saishori_flg = ' || '''1''';
		vSql := vSql || ', kousin_dt = CURRENT_TIMESTAMP';
		vSql := vSql || ', kousin_id = ' || '''' || 'BATCH' || '''';
		vSql := vSql || ' WHERE itaku_kaisha_cd = ' || '''' || l_inCItaku_kaisha_cd || '''';
		vSql := vSql || ' AND TRIM(TO_CHAR(knj_uke_tsuban, ''0000000009'')) = ' ||
				'''' || l_inUkeTuban || '''';
		EXECUTE vSql;
	-- 処理区分が'2'又は'3'又は'4'の場合
	ELSE
		-- 処理区分が'2'又は'3'の場合、エラーコードを設定
		IF l_inShoriKbn = '2' OR l_inShoriKbn = '3' THEN
			vSql := '';
			vSql := 'UPDATE ' || l_inTableName || ' ';
			vSql := vSql || ' SET knj_err_code = ' || '''' || l_inErrCode || '''';
			vSql := vSql || ', kousin_dt = CURRENT_TIMESTAMP';
			vSql := vSql || ', kousin_id = ' || '''BATCH''';
			vSql := vSql || ' WHERE itaku_kaisha_cd = ' || '''' || l_inCItaku_kaisha_cd || '''';
			vSql := vSql || ' AND TRIM(TO_CHAR(knj_uke_tsuban, ''0000000009'')) = ' ||
					'''' || l_inUkeTuban || '''';
		-- 処理区分が'4'の場合、再処理フラグを'1'に、取消フラグを'1'に更新
		ELSIF l_inShoriKbn = '4' THEN
			vSql := '';
			vSql := 'UPDATE ' || l_inTableName || ' ';
			vSql := vSql || ' SET knj_saishori_flg = ' || '''1''';
			vSql := vSql || ' ,knj_torikeshi_flg = ' || '''1''';
			vSql := vSql || ' ,kousin_dt = CURRENT_TIMESTAMP';
			vSql := vSql || ' ,kousin_id = ' || '''BATCH''';
			vSql := vSql || ' WHERE itaku_kaisha_cd = ' || '''' || l_inCItaku_kaisha_cd || '''';
			vSql := vSql || ' AND TRIM(TO_CHAR(knj_uke_tsuban, ''0000000009'')) = ' ||
					'''' || l_inUkeTuban || '''';
		END IF;
		EXECUTE vSql;
		-- 処理区分が'3'又は'4'の場合は、エラー処理を行う
		IF l_inShoriKbn = '3' OR l_inShoriKbn = '4' THEN
			-- ログ出力用メッセージ
			vMsgLog := '＜受付通番:' || l_inUkeTuban || '、ERR:' || l_inErrCode ||
					   '、入出金区分:' || l_inInoutKbn || '＞';
			-- メッセージ通知用メッセージ
			vMsgTsuchi := '受付通番が重複しています。＜受付通番:' || l_inUkeTuban ||
						  '、ERR:' || l_inErrCode ||
						  '、入出金区分:' || l_inInoutKbn || '＞';
			-- エラーリスト用テーブル名称
			vTableName := l_inMeisyou;
			-- エラーリスト用メッセージ
			vMsg_Err_list := '＜受付通番:' || l_inUkeTuban ||
							 '、ERR:' || l_inErrCode ||
							 '、入出金区分:' || l_inInoutKbn || '＞';
			iRet := SFIPF013K01R03_COMMON_FUNC(
						l_inMsgId,
						vMsgLog,
						vMsgTsuchi,
						vTableName,
						vMsg_Err_list,
						l_inUkeTuban
					,
         cItaku_kaisha_cd,
         cGyoumuDt
     );
			IF iRet = pkconstant.fatal() THEN
				RETURN pkconstant.fatal();
			END IF;
		END IF;
	END IF;
	RETURN pkconstant.success();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf013k01r03_common_error ( l_inShoriKbn TEXT, l_inTableName TEXT, l_inErrCode TEXT, l_inUkeTuban TEXT, l_inInoutKbn TEXT, l_inMeisyou TEXT, l_inMsgId TEXT DEFAULT NULL  ) FROM PUBLIC;





CREATE OR REPLACE FUNCTION sfipf013k01r03_common_func (
	l_inMessage_id text,			-- メッセージＩＤ
	l_inMsgLog text,			-- ログ出力用メッセージ
	l_inMsgTsuchi text,			-- メッセージ通知用メッセージ
	l_inTableName text,			-- テーブル名称
	l_inMsg_Err_list text,			-- エラーリスト用メッセージ
	l_inUke_tuban text,				-- 受付通番
	l_inCItaku_kaisha_cd TEXT,		-- 委託会社コード
	l_inCGyoumuDt char(8)			-- 業務日付
) RETURNS integer AS $body$
DECLARE
	nSqlCode integer;
	vSqlErrM text;
	iRet integer;
BEGIN
	-- ログ出力
	CALL pkLog.error(
		l_inMessage_id,
		'IPF013K01R03',
		l_inMsgLog
	);
	-- エラーリスト出力
	CALL SPIPF001K00R01(
		l_inCItaku_kaisha_cd,
		'BATCH', 
		'1', 
		'3', 
		l_inCGyoumuDt, 
		'60', 
		'9999999999', 
		l_inTableName, 
		l_inMsg_Err_list,
		l_inMessage_id, 
		nSqlCode, 
		vSqlErrM
	);
	-- メッセージ通知テーブルへ書き込み
	iRet := SfIpMsgTsuchiUpdate(
			cItaku_kaisha_cd,
			'勘定系',
			'警告',
			'1',
			'0',
			l_inMsgTsuchi,
			'BATCH',
			'BATCH'
	);
	IF iRet != 0 THEN
		CALL pkLog.fatal(
			'ECM701',
			'IPF013K01R03',
			'メッセージ通知登録エラー'
		);
		RETURN iRet;
	END IF;
	RETURN pkconstant.success();
END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf013k01r03_common_func ( l_inMessage_id text, l_inMsgLog text, l_inMsgTsuchi text, l_inTableName text, l_inMsg_Err_list text, l_inUke_tuban text  ) FROM PUBLIC;
