Converting: /home/ansible/jip-ipa/legacy/db/plsql/customize/btmu/batch/yakan/SFIPP015K01R00.sql
Basic conversion complete for: /home/ansible/jip-ipa/legacy/db/plsql/customize/btmu/batch/yakan/SFIPP015K01R00.sql
----------------------------------------
Oracle compatibility check for: /home/ansible/jip-ipa/legacy/db/plsql/customize/btmu/batch/yakan/SFIPP015K01R00.sql
Các hàm/cú pháp sau nếu xuất hiện thì cần xem lại/convert tay:
  - NVL (nếu còn sót), DECODE, TO_DATE, TO_CHAR, TO_TIMESTAMP
  - ADD_MONTHS, MONTHS_BETWEEN, LAST_DAY, NEXT_DAY, TRUNC(date)
  - ROWNUM, DBMS_*
  - TYPE ... IS TABLE OF ... INDEX BY ...
  - array.EXISTS(cnt)
  - FETCH cursor INTO array[index]
  - Outer join kiểu Oracle: ( + )
  - NULL() (dùng sai trong PostgreSQL)
  - IN OUT / INOUT parameter
  - Gọi typeArray() để init (varA := typeArray())
  - SQLCODE, SQLERRM(...)
  - OID (cần xem lại nếu đang dùng để tham chiếu row)
  - Gọi pkprint.insertdata(...) nhưng vẫn truyền từng item lẻ thay vì composite TYPE_SREPORT_WK_ITEM
  - l_outSqlCode OUT nên là integer, l_outSqlErrM OUT nên là text
  - Cú pháp Oracle array-style: aryXxx(0) → PostgreSQL: aryXxx[1]
  - Sub-procedure / sub-function lồng trong function/procedure/package (PostgreSQL không hỗ trợ nested)

>>> [TO_TIMESTAMP] tìm thấy các dòng sau (cần xem lại/convert tay):
63:    gTimeStamp TIMESTAMP := TO_TIMESTAMP(pkDate.getCurrentTime,'YYYY-MM-DD HH24:MI:SS.FF6');

>>> [TYPE_INIT_CALL] tìm thấy các dòng sau (cần xem lại/convert tay):
315:			errMessage := typeMessage();

>>> [SQLCODE_USAGE] tìm thấy các dòng sau (cần xem lại/convert tay):
471:		pkLog.fatal('ECM701', SP_ID, SQLCODE || SUBSTR(SQLERRM, 1, 100));

----------------------------------------

Conversion complete!
