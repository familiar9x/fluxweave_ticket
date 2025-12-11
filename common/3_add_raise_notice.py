import re
import sys

CHUNK_LINES = 200  # muốn 100 dòng 1 lần thì đổi số này

def instrument_sql(sql_text: str, chunk_lines: int = CHUNK_LINES) -> str:
    lines = sql_text.splitlines()

    out_lines = []

    in_body = False        # đang ở trong $$ ... $$ (body PL/pgSQL)
    dollar_tag = None      # ví dụ: $$ hoặc $func$
    in_string = False      # đang trong '...'

    last_notice_line = 0   # dòng cuối cùng đã chèn RAISE
    notice_counter = 1     # đánh số checkpoint

    for lineno, line in enumerate(lines, start=1):
        text = line
        idx = 0
        stmt_ended_here = False  # có câu lệnh kết thúc ở dòng này không

        while idx < len(text):
            ch = text[idx]

            # --- xử lý dollar-quote: $$ hoặc $tag$ ---
            if not in_string and ch == '$':
                m = re.match(r"\$[A-Za-z0-9_]*\$", text[idx:])
                if m:
                    tag = m.group(0)
                    if not in_body:
                        # mở body
                        in_body = True
                        dollar_tag = tag
                    else:
                        # đang trong body, gặp lại đúng tag => đóng body
                        if tag == dollar_tag:
                            in_body = False
                            dollar_tag = None
                            in_string = False
                    idx += len(tag)
                    continue

            # --- nếu đang trong body PL/pgSQL thì track string + dấu ; ---
            if in_body:
                # toggle string '...'
                if ch == "'" and (idx == 0 or text[idx - 1] != "\\"):
                    in_string = not in_string
                # ; kết thúc câu lệnh nếu không nằm trong string
                elif ch == ";" and not in_string:
                    stmt_ended_here = True

            idx += 1

        # luôn ghi lại dòng hiện tại
        out_lines.append(line)

        # nếu có câu lệnh kết thúc ở dòng này và đủ xa checkpoint trước
        if in_body and stmt_ended_here and (lineno - last_notice_line) >= chunk_lines:
            indent = re.match(r"\s*", line).group(0)
            out_lines.append(
                f"{indent}RAISE NOTICE 'checkpoint {notice_counter} at line {lineno}';"
            )
            notice_counter += 1
            last_notice_line = lineno

    return "\n".join(out_lines)


if __name__ == "__main__":
    sql = sys.stdin.read()
    result = instrument_sql(sql)
    print(result)
