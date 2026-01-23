--*
--* 著作権：Copyright(c) 2005
--* 会社名：JIP
--*
--* 概要  ：受信データ自動作成
--*
--* @author 倉澤健史
--* @version $Revision: 1.5 $
--*
--* @param なし
--* @return number      0：正常，99：異常
--





CREATE OR REPLACE FUNCTION sfipf010k01r11 () RETURNS numeric AS $body$
DECLARE

	RETURN_VALUE          numeric(02)  := 0;
	WK_MAX_DATA_SEQ       numeric(10)  := 0;
	WK_MAKE_DT_FIRST_FLG  numeric(01)  := 0;
	WK_UPD_SEQ_NO         numeric(11)  := 0;
	WK_DATA_SECT_EQFLG    numeric(01)  := 0;
	WK_SND_DATA2          varchar(49);
	WK_SND_DATA4          varchar(152);
	WK_SND_DATA           varchar(1000);
	WK_RCV_DATA2          varchar(49);
	WK_RCV_DATA4          varchar(152);
	WK_RCV_DATA           varchar(1000);
--  当預リアル送信IFテーブルより対象データ抽出
	CUR_TOYO_SND CURSOR FOR
	   SELECT   DATA_ID,
	            MAKE_DT,
	            DATA_SECT
	   FROM     TOYOREALSNDIF
	   WHERE    DATA_ID             =   '13002';
--  当預リアル受信IFテーブルより対象データ抽出
	CUR_TOYO_RCV CURSOR FOR
	   SELECT   MAKE_DT,
	            DATA_SECT
	   FROM     TOYOREALRCVIF;
	
BEGIN
	   FOR   REC_TOYO_SND      IN   CUR_TOYO_SND     LOOP
	         SELECT  MAX(DATA_SEQ)  INTO STRICT   WK_MAX_DATA_SEQ    FROM     TOYOREALRCVIF
	                                WHERE  REC_TOYO_SND.MAKE_DT     =  MAKE_DT;
	         WK_MAKE_DT_FIRST_FLG   :=     0;
	         WK_DATA_SECT_EQFLG     :=     0;
	         WK_SND_DATA2           :=     substr(REC_TOYO_SND.DATA_SECT,4,49);
	         WK_SND_DATA4           :=     substr(REC_TOYO_SND.DATA_SECT,55,152);
	         WK_SND_DATA            :=     '  '|| WK_SND_DATA2 ||'  '|| WK_SND_DATA4;
--  当預リアル受信IFテーブルに同一作成日あり
	         IF  WK_MAX_DATA_SEQ    >  0   THEN
	             WK_UPD_SEQ_NO      :=     WK_MAX_DATA_SEQ     +    1;
                 FOR   REC_TOYO_RCV IN     CUR_TOYO_RCV              LOOP
                       IF  REC_TOYO_SND.MAKE_DT
                                     =     REC_TOYO_RCV.MAKE_DT      THEN
                           WK_RCV_DATA2    :=     substr(REC_TOYO_RCV.DATA_SECT,4,49);
	                       WK_RCV_DATA4    :=     substr(REC_TOYO_RCV.DATA_SECT,55,152);
	                       WK_RCV_DATA     :=     '  '|| WK_RCV_DATA2 ||'  '|| WK_RCV_DATA4;
	                       IF  WK_SND_DATA  =     WK_RCV_DATA        THEN
	                           WK_DATA_SECT_EQFLG     :=  1;
	                       END IF;
	                   END IF;
                 END   LOOP;
	         ELSE
--  当預リアル受信IFテーブルに同一作成日なし
	             WK_UPD_SEQ_NO             :=     1;
	             WK_MAKE_DT_FIRST_FLG      :=     1;
	         END IF;
--  当預リアル受信IFテーブル更新処理
             IF (WK_DATA_SECT_EQFLG        =  0)     OR (WK_MAKE_DT_FIRST_FLG      =  1)     THEN
	             WK_SND_DATA2       :=     substr(REC_TOYO_SND.DATA_SECT,4,49);
	             WK_SND_DATA4       :=     substr(REC_TOYO_SND.DATA_SECT,55,152);
                 WK_SND_DATA        :=     'NA,'|| WK_SND_DATA2 ||'51'|| WK_SND_DATA4;
	             INSERT INTO  TOYOREALRCVIF(DATA_ID,        -- データIＤ 
	                     MAKE_DT,        -- 作成日 
	                     DATA_SEQ,       -- データ内連番 
	                     DATA_SECT,      -- データ部 
	                     SR_STAT)        -- 送受信ステータス 
	                     VALUES ('31001',
	                     REC_TOYO_SND.MAKE_DT,
	                     WK_UPD_SEQ_NO,
	                     WK_SND_DATA,
	                     '0');
	         END IF;
	   END LOOP;
	   RETURN_VALUE             :=   0;
	   RETURN RETURN_VALUE;
	EXCEPTION
	   WHEN  OTHERS 	THEN
	      CALL pkLog.fatal('ECM701', 'IPF010K01R11', 'SQLERRM:' || SQLERRM || '(' || SQLSTATE || ')');
	      RETURN pkconstant.fatal();
    END;
$body$
LANGUAGE PLPGSQL
;
-- REVOKE ALL ON FUNCTION sfipf010k01r11 () FROM PUBLIC;