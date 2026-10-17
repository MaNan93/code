"""
从 Word (.docx) 中按固定模式提取表格并导出为 Excel (.xls)
模式：Offset ... -> Reset Value ... -> 表格名 -> 表格

每个表格输出为独立的 Sheet，包含：
  第1行：Offset     | <值>
  第2行：Reset Value| <值>
  第3行：（空行）
  第4行起：表格正文（保留合并单元格）

依赖：xlwt 1.3.0
用法：
  python docx_table_to_csv.py 文档.docx           # 导出全部，输出 文档.xls
  python docx_table_to_csv.py 文档.docx --list    # 仅列出识别到的表格名
  python docx_table_to_csv.py 文档.docx --debug   # 打印段落文本，用于诊断
  python docx_table_to_csv.py 文档.docx 输出.xls  # 指定输出文件名
"""

import sys
import zipfile
import xml.etree.ElementTree as ET
import os
import re

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"

# ── 状态机状态 ────────────────────────────────────────────
S_IDLE      = 0   # 等待 Offset
S_OFFSET    = 1   # 已找到 Offset，等待 Reset Value
S_RESET     = 2   # 已找到 Reset Value，等待表格名
S_NAME      = 3   # 已找到表格名，等待表格


def get_para_text(para_elem):
    return "".join(t.text for t in para_elem.iter(W + "t") if t.text)


def get_cell_text(cell_elem):
    """每个 w:p 段落独立一行，保留单元格内的换行格式。"""
    paras = []
    for p in cell_elem.findall(W + "p"):
        line = "".join(t.text for t in p.iter(W + "t") if t.text)
        paras.append(line)
    # 去除末尾空行，用 \n 连接
    return "\n".join(paras).rstrip("\n")


def read_table_raw(tbl_elem):
    """
    读取表格，每格返回 {text, colspan, vmerge}。
    colspan: w:gridSpan 值（水平合并列数）
    vmerge:  'restart'=垂直合并起始, 'cont'=续行, None=普通
    """
    rows = []
    for tr in tbl_elem.findall(W + "tr"):
        row = []
        for tc in tr.findall(W + "tc"):
            text   = get_cell_text(tc)
            tcPr   = tc.find(W + "tcPr")
            colspan = 1
            vmerge  = None
            if tcPr is not None:
                gs = tcPr.find(W + "gridSpan")
                if gs is not None:
                    try:
                        colspan = int(gs.get(W + "val", "1"))
                    except ValueError:
                        pass
                vm = tcPr.find(W + "vMerge")
                if vm is not None:
                    vmerge = "restart" if vm.get(W + "val", "") == "restart" else "cont"
            row.append({"text": text, "colspan": colspan, "vmerge": vmerge})
        if row:
            rows.append(row)
    return rows


# 输出列顺序
OUT_HEADER = ["Addr", "Type", "Field name", "Register Name", "Bit", "Default", "Description", "Status"]

# 源表格列的关键词匹配
_BITS_RE   = re.compile(r'\bbit',    re.IGNORECASE)
_NAME_RE   = re.compile(r'\bname\b', re.IGNORECASE)
_ACCESS_RE = re.compile(r'\baccess\b',re.IGNORECASE)
_DESC_RE   = re.compile(r'\bdesc',   re.IGNORECASE)


def detect_columns(header_row):
    """
    从表头行（read_table_raw 首行）中识别各列角色。
    返回 dict: {'bits': idx, 'name': idx, 'access': idx, 'description': idx}
    idx 为顺序单元格下标（不是逻辑列号）。
    """
    mapping = {}
    for i, cell in enumerate(header_row):
        t = cell['text'].strip()
        if _BITS_RE.search(t)   and 'bits'        not in mapping: mapping['bits']        = i
        if _NAME_RE.search(t)   and 'name'        not in mapping: mapping['name']        = i
        if _ACCESS_RE.search(t) and 'access'      not in mapping: mapping['access']      = i
        if _DESC_RE.search(t)   and 'description' not in mapping: mapping['description'] = i
    return mapping


def get_col_val(row, seq_idx):
    """取顺序下标 seq_idx 处单元格的文本；越界或 None 返回空字符串。"""
    if seq_idx is None or seq_idx < 0 or seq_idx >= len(row):
        return ""
    return row[seq_idx]['text']


def extract_bits_range(bit_str):
    """
    解析位域字符串，返回 (high, low)。
    支持：[7:4]  7:4  [7]  7  7-4
    无法解析返回 (None, None)。
    """
    s = bit_str.strip().strip('[]')
    m = re.match(r'(\d+)\s*[:\-]\s*(\d+)', s)
    if m:
        hi, lo = int(m.group(1)), int(m.group(2))
        return (hi, lo) if hi >= lo else (lo, hi)
    m = re.match(r'(\d+)', s)
    if m:
        b = int(m.group(1))
        return b, b
    return None, None


def compute_default(reset_val_str, bit_str):
    """
    从 reset_val_str 中按 bit_str 指定的位域提取默认值。
    格式：width'hVALUE，例：reset_val="0xFF", bit_str="[7:4]" → "4'hF"
    """
    hi, lo = extract_bits_range(bit_str)
    if hi is None:
        return ""
    try:
        val = int(reset_val_str.strip().replace(" ", ""), 0)
    except (ValueError, AttributeError):
        return ""
    width = hi - lo + 1
    extracted = (val >> lo) & ((1 << width) - 1)
    return "{}'h{:X}".format(width, extracted)


def extract_value(text, keyword):
    """
    从段落文本中提取 keyword 后面的内容。
    支持 "Offset: 0x100"、"Offset 0x100"、"Offset：0x100" 等格式。
    若整行就是 keyword 本身，则返回空字符串。
    """
    pattern = re.compile(
        re.escape(keyword) + r'\s*[：:]\s*(.+)',
        re.IGNORECASE
    )
    m = pattern.search(text)
    if m:
        return m.group(1).strip()
    # 无冒号时取 keyword 后第一个非空 token
    pattern2 = re.compile(
        re.escape(keyword) + r'\s+(\S.*)',
        re.IGNORECASE
    )
    m2 = pattern2.search(text)
    if m2:
        return m2.group(1).strip()
    return ""


def sanitize_filename(name):
    name = name.strip()
    name = re.sub(r'[\\/:*?"<>|]', "_", name)
    if len(name.encode("utf-8")) > 180:
        name = name[:40].rstrip()
    return name or "unnamed"


# 循环注解匹配：(for i=0; i<=3) 或 (for i=0; i<4)
LOOP_RE = re.compile(
    r'\(?\s*for\s+i\s*=\s*(\d+)\s*;\s*i\s*(<=|<)\s*(\d+)\s*;?[^)]*\)?',
    re.IGNORECASE
)


def parse_loop(text):
    """检测文本中的循环注解，返回 (start, stop_inclusive) 或 None"""
    m = LOOP_RE.search(text)
    if not m:
        return None
    start = int(m.group(1))
    op    = m.group(2)
    bound = int(m.group(3))
    stop  = bound if op == '<=' else bound - 1
    return start, stop


def strip_loop(text):
    """删除循环注解后返回干净字符串"""
    return LOOP_RE.sub('', text).strip().rstrip(';,').strip()


def simplify_addr(addr_str):
    """
    对地址字符串进行化简：计算纯数字部分，保留符号基地。
    例："B + 0 * 0x4" → "B"
         "B + 2 * 0x4" → "B + 0x8"
         "0x100 + 0x10" → "0x110"
    """
    # 去除 hex 下划线: 0x0000_0100 -> 0x00000100
    s = re.sub(r'(0[xX])([0-9a-fA-F_]+)',
               lambda m: m.group(1) + m.group(2).replace('_', ''), addr_str.strip())
    # 维尝试纯数字求值
    try:
        return hex(int(eval(s, {"__builtins__": {}}, {})))
    except Exception:
        pass
    # 找出符号 token（非数字的标识符）
    bases, seen = [], set()
    for b in re.findall(r'\b[A-Za-z_][A-Za-z0-9_]*\b', s):
        if b not in seen:
            bases.append(b)
            seen.add(b)
    if not bases:
        return s
    # 抎掉符号，尝试计算数字偏移
    s_num = s
    for b in bases:
        s_num = re.sub(r'\b{}\b'.format(re.escape(b)), '0', s_num)
    try:
        offset = int(eval(s_num, {"__builtins__": {}}, {}))
    except Exception:
        return s
    base_str = " + ".join(bases)
    return "{} + {}".format(base_str, hex(offset))


def apply_base_alias(addr_str, table_name):
    """
    按表格名前缀替换地址表达式中的基址符号 B：
    - DMA 开头 -> B = 0x300000
    - AT  开头 -> B = 0x200000
    仅替换独立标识符 B。
    """
    s = (addr_str or "").strip()
    name = (table_name or "").strip().lower()
    if name.startswith("dma"):
        return re.sub(r'\bB\b', '0x300000', s)
    if name.startswith("at"):
        return re.sub(r'\bB\b', '0x200000', s)
    return s


def eval_addr(addr_str, i_val, table_name=None):
    """i 替换并按表名前缀处理基址后，调用 simplify_addr"""
    s = re.sub(r'\bi\b', str(i_val), addr_str)
    s = apply_base_alias(s, table_name)
    return simplify_addr(s)


def addr_sort_key(addr_str):
    """
    地址排序键：
    1) 纯数值表达式：按数值排序
    2) 含符号基址表达式：按(基址字符串, 数字偏移)排序
    无法解析返回 None（由调用方保持原顺序）。
    """
    if not addr_str:
        return None
    s = addr_str.strip()

    # 统一去掉十六进制下划线
    s = re.sub(r'(0[xX])([0-9a-fA-F_]+)',
               lambda m: m.group(1) + m.group(2).replace('_', ''), s)

    # 1) 尝试纯数值表达式
    if re.match(r'^[0-9a-fA-FxX_+\-*/()\s]+$', s):
        try:
            return ("", int(eval(s, {"__builtins__": {}}, {})))
        except Exception:
            pass

    # 2) 尝试符号+数值偏移：将符号替换为0，再求偏移
    bases = []
    seen = set()
    for b in re.findall(r'\b[A-Za-z_][A-Za-z0-9_]*\b', s):
        if b not in seen:
            bases.append(b)
            seen.add(b)
    if not bases:
        return None

    s_num = s
    for b in bases:
        s_num = re.sub(r'\b{}\b'.format(re.escape(b)), '0', s_num)

    try:
        offset = int(eval(s_num, {"__builtins__": {}}, {}))
    except Exception:
        return None
    base_key = " + ".join(bases)
    return (base_key, offset)


def subst_i(text, i_val):
    """将文本中的 _i 替换为 _N"""
    return re.sub(r'_i\b', '_{}'.format(i_val), text)


def expand_results(results):
    """
    展开 table_name 或 offset_val 中含循环注解的结果。
    例：REG_i (for i=0; i<=3) 展开为 REG_0 / REG_1 / REG_2 / REG_3
    """
    expanded = []
    special_prefix = ("at inbound control", "at outbound control")
    target_slots = []

    def match_special_prefix(name):
        low = (name or "").strip().lower()
        for p in special_prefix:
            if low.startswith(p):
                return True
        return False

    for table_name, offset_val, reset_val, raw_rows in results:
        loop = parse_loop(table_name) or parse_loop(offset_val)
        if loop is None:
            resolved_offset = simplify_addr(apply_base_alias(offset_val, table_name))
            expanded.append((table_name, resolved_offset, reset_val, raw_rows))
            continue

        start, stop = loop
        clean_name   = strip_loop(table_name)
        clean_offset = strip_loop(offset_val)
        for i_val in range(start, stop + 1):
            new_name   = subst_i(clean_name, i_val)
            new_offset = eval_addr(subst_i(clean_offset, i_val), i_val, clean_name)

            # 深拷 raw_rows，将每个单元格文本中的 _i 也替换
            new_rows = []
            for row in raw_rows:
                new_row = []
                for cell in row:
                    nc = dict(cell)
                    nc['text'] = subst_i(cell['text'], i_val)
                    new_row.append(nc)
                new_rows.append(new_row)

            item = (new_name, new_offset, reset_val, new_rows)
            expanded.append(item)
            if match_special_prefix(clean_name):
                target_slots.append((len(expanded) - 1, item))
            print("  展开: {} -> {} (i={})".format(table_name, new_name, i_val))

    # 对目标表进行“全量收集后统一排序”：
    # AT Inbound control 与 AT Outbound control 一起排序并回写原槽位。
    if target_slots:
        sortable = []
        unsortable = []
        for local_idx, (slot_idx, item) in enumerate(target_slots):
            k = addr_sort_key(item[1])
            if k is None:
                unsortable.append((local_idx, item))
            else:
                sortable.append((k, local_idx, item))
        sortable.sort(key=lambda x: (x[0], x[1]))
        ordered_items = [x[2] for x in sortable] + [x[1] for x in unsortable]
        for (slot_idx, _), new_item in zip(target_slots, ordered_items):
            expanded[slot_idx] = new_item

    return expanded


def parse_doc(docx_path):
    """
    状态机遍历文档，识别 Offset -> Reset Value -> 表格名 -> 表格 的模式。
    返回列表：[(table_name, offset_val, reset_val, rows), ...]
    """
    with zipfile.ZipFile(docx_path, "r") as z:
        with z.open("word/document.xml") as f:
            root = ET.parse(f).getroot()

    body = root.find(".//" + W + "body")
    if body is None:
        print("未找到文档正文。")
        return []

    results = []
    state = S_IDLE
    offset_val = ""
    reset_val  = ""
    table_name = ""

    for child in body:
        tag = child.tag

        if tag == W + "p":
            text = get_para_text(child).strip()
            if not text:
                continue

            # 检测 Offset（不区分大小写）
            if re.search(r'\bOffset\b', text, re.IGNORECASE):
                offset_val = extract_value(text, "Offset")
                state = S_OFFSET
                # 同一行也可能含 Reset Value
                if re.search(r'\bReset\s+Value\b', text, re.IGNORECASE):
                    reset_val = extract_value(text, "Reset Value")
                    state = S_RESET

            elif state == S_OFFSET and re.search(r'\bReset\s+Value\b', text, re.IGNORECASE):
                reset_val = extract_value(text, "Reset Value")
                state = S_RESET

            elif state == S_OFFSET:
                # 缺少 Reset Value，直接把此段落当表格名，Reset Value 默认 0x0
                reset_val = "0x0"
                table_name = text
                state = S_NAME

            elif state == S_RESET:
                # 下一个非空段落就是表格名
                table_name = text
                state = S_NAME

            # 如果段落中又出现了新的 Offset，重置（处理连续模式）
            # 已在最前面处理，这里不重复

        elif tag == W + "tbl":
            if state == S_NAME:
                rows = read_table_raw(child)
                if rows:
                    results.append((table_name, offset_val, reset_val, rows))
                # 无论是否有行，都重置状态
                state = S_IDLE
                offset_val = reset_val = table_name = ""
            # state != S_NAME 时忽略表格

    return results


def save_to_xls(results, xls_path):
    import xlwt

    wb  = xlwt.Workbook(encoding="utf-8")
    ws  = wb.add_sheet("Sheet1")

    fmt_header = xlwt.easyxf(
        "font: bold true, height 220;"
        "borders: left thin, right thin, top thin, bottom thin;"
        "alignment: horiz centre, vert centre;"
        "pattern: pattern solid, fore_colour grey25;"
    )
    fmt_cell = xlwt.easyxf(
        "borders: left thin, right thin, top thin, bottom thin;"
        "alignment: wrap true, vert centre;"
    )
    fmt_merge = xlwt.easyxf(
        "borders: left thin, right thin, top thin, bottom thin;"
        "alignment: wrap true, vert centre, horiz centre;"
    )

    # 第 0 行：列头
    for ci, h in enumerate(OUT_HEADER):
        ws.write(0, ci, h, fmt_header)

    cur_row = 1

    for table_name, offset_val, reset_val, raw_rows in results:
        if not raw_rows:
            continue

        # 首行为表头，检测列映射
        col_map   = detect_columns(raw_rows[0])
        data_rows = raw_rows[1:]
        if not data_rows:
            continue

        start_row = cur_row

        for row in data_rows:
            bits_raw    = get_col_val(row, col_map.get('bits'))
            name_val    = get_col_val(row, col_map.get('name'))
            access_val  = get_col_val(row, col_map.get('access'))
            desc_val    = get_col_val(row, col_map.get('description'))
            # Bit: 确保用 [] 包裹
            bits_stripped = bits_raw.strip().strip('[]')
            bits_val  = '[{}]'.format(bits_stripped) if bits_stripped else ''
            default_val = compute_default(reset_val, bits_raw) if bits_raw else ""

            # col 0 (Addr) 和 col 2 (Field name) 后面统一写合并
            ws.write(cur_row, 1, access_val,  fmt_cell)   # Type
            ws.write(cur_row, 3, name_val,    fmt_cell)   # Register Name
            ws.write(cur_row, 4, bits_val,    fmt_cell)   # Bit
            ws.write(cur_row, 5, default_val, fmt_cell)   # Default
            ws.write(cur_row, 6, desc_val,    fmt_cell)   # Description
            ws.write(cur_row, 7, "Static",    fmt_cell)   # Status
            cur_row += 1

        end_row = cur_row - 1
        n = end_row - start_row + 1

        # Addr (col 0) 和 Field name (col 2)：多行时合并
        if n == 1:
            ws.write(start_row, 0, offset_val,  fmt_merge)
            ws.write(start_row, 2, table_name,  fmt_merge)
        else:
            ws.write_merge(start_row, end_row, 0, 0, offset_val, fmt_merge)
            ws.write_merge(start_row, end_row, 2, 2, table_name, fmt_merge)

        print("  [{}] {}条记录  Addr={}  ResetValue={}".format(
            table_name, n, offset_val, reset_val))

    wb.save(xls_path)
    print("已保存：{}".format(xls_path))


def main():
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        sys.exit(0)

    docx_path = args[0]
    if not os.path.isfile(docx_path):
        print("文件不存在：{}".format(docx_path))
        sys.exit(1)

    list_mode  = "--list"  in args
    debug_mode = "--debug" in args
    xls_path = None
    for a in args[1:]:
        if not a.startswith("--"):
            xls_path = a
    if xls_path is None:
        xls_path = os.path.join(os.path.dirname(docx_path), "Nebula.xls")

    print("正在读取：{}".format(docx_path))

    # --debug：打印所有段落文本，帮助确认关键词格式
    if debug_mode:
        with zipfile.ZipFile(docx_path, "r") as z:
            with z.open("word/document.xml") as f:
                root = ET.parse(f).getroot()
        body = root.find(".//" + W + "body")
        print("\n{:<6} {}".format("类型", "文本"))
        print("-" * 80)
        for child in body:
            if child.tag == W + "p":
                text = get_para_text(child).strip()
                if text:
                    print("{:<6} {}".format("[P]", text[:100]))
            elif child.tag == W + "tbl":
                raw = read_table_raw(child)
                preview = " | ".join(c["text"] for c in raw[0]) if raw else ""
                print("{:<6} {}".format("[TBL]", preview[:80]))
        sys.exit(0)

    results = parse_doc(docx_path)
    results = expand_results(results)

    if not results:
        print("未找到任何 Offset->Reset Value->表格名->表格 模式。")
        print("请先用 --debug 查看文档中的段落文本，确认关键词拼写。")
        sys.exit(0)

    if list_mode:
        print("\n共识别到 {} 个表格：".format(len(results)))
        for name, ov, rv, rows in results:
            print("  [{}行] Offset={} ResetValue={} 表格名={}".format(len(rows), ov, rv, name))
        sys.exit(0)

    print("共识别到 {} 个表格，导出到：{}".format(len(results), xls_path))
    save_to_xls(results, xls_path)
    print("完成。")


if __name__ == "__main__":
    main()
