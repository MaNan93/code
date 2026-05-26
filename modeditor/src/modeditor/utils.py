"""Reusable utilities for Verilog/SystemVerilog parsing and module analysis."""


import importlib
import re
from pathlib import Path
from typing import Any, Callable, cast, Dict, List, Optional, Set, Tuple, Union

pyslang: Any = importlib.import_module("pyslang")


WIRE_DECL_LINE_RE = re.compile(
    r"^\s*(?:wire|logic|reg|bit|tri|integer|var|signed|unsigned)\b[^;\n]*;\s*$"
)


# ---------------------------------------------------------------------------
# 底层文本助手
# ---------------------------------------------------------------------------


def find_matching_paren(text: str, open_idx: int) -> int:
    """从 open_idx 处的 '(' 向右扫描，返回匹配的 ')' 下标；未找到返回 -1。"""
    stack: List[int] = []
    for idx in range(open_idx, len(text)):
        ch = text[idx]
        if ch == "(":
            stack.append(idx)
        elif ch == ")":
            if stack:
                stack.pop()
                if not stack:
                    return idx
    return -1


_STRIP_COMMENTS_RE = re.compile(r"//[^\n]*|/\*.*?\*/", re.DOTALL)


def strip_comments(text: str) -> str:
    """删除 Verilog 文本中的 // 行注释和 /* */ 块注释。

    单次扫描完成两种注释的匹配：
    - ``//[^\\n]*``  匹配行注释（到行尾，不跨行）
    - ``/\\*.*?\\*/``  非贪婪匹配块注释（DOTALL 支持跨行）
    """
    return _STRIP_COMMENTS_RE.sub("", text)


def split_csv(value: str) -> List[str]:
    """按顶层逗号拆分字符串；() [] {} 内的逗号不视为分隔符。

    用 re.finditer 定位括号与逗号，跳过其余字符；
    单一深度计数器支持三种括号任意深度嵌套，字符串切片避免逐字符拼接。
    """
    depth = 0
    parts: List[str] = []
    prev = 0
    for m in re.finditer(r"[()[\]{},]", value):
        ch = m.group()
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            if depth > 0:
                depth -= 1
        elif depth == 0:  # ch == ","
            token = value[prev:m.start()].strip()
            if token:
                parts.append(token)
            prev = m.end()
    tail = value[prev:].strip()
    if tail:
        parts.append(tail)
    return parts


_LEADING_WS_RE = re.compile(r"\s*")


def detect_indent(block_text: str, default_indent: str = "    ") -> str:
    """从文本块探测缩进：返回第一个非空行的前导空白；若全空则返回 default_indent。"""
    for ln in block_text.splitlines():
        if not ln.strip():
            continue
        m = _LEADING_WS_RE.match(ln)
        assert m is not None  # \s* always matches
        ind = m.group(0)
        return ind if ind else default_indent
    return default_indent


def detect_newline(text: str) -> str:
    """探测文本使用的换行符：优先检测 \\r\\n，否则返回 \\n。"""
    if "\r\n" in text:
        return "\r\n"
    return "\n"


def find_instance_conn_bounds(module_text: str, instname: str) -> Tuple[int, int]:
    """定位实例连接列表括号边界，返回 (open_idx, close_idx)。

    会跳过注释行中的实例名匹配；未找到实例或括号不平衡时抛 ValueError。
    """
    inst_m = None
    for m in re.finditer(rf"\b{re.escape(instname)}\b\s*\(", module_text):
        line_start = module_text.rfind("\n", 0, m.start()) + 1
        if re.match(r"^\s*//", module_text[line_start:m.start() + 1]):
            continue
        inst_m = m
        break

    if not inst_m:
        raise ValueError("Instance '{}' not found".format(instname))

    open_idx = module_text.find("(", inst_m.start())
    close_idx = find_matching_paren(module_text, open_idx)
    if close_idx < 0:
        raise ValueError("Instance connection list is unbalanced")
    return open_idx, close_idx


def parse_non_ansi_port_names(ports_block: str) -> List[str]:
    """Return an ordered, deduplicated list of port names from a non-ANSI port list block."""
    clean = strip_comments(ports_block).replace("\n", " ")
    names = [x.strip() for x in clean.split(",") if x.strip()]
    seen: Set[str] = set()
    result: List[str] = []
    for n in names:
        if n in seen:
            continue
        seen.add(n)
        result.append(n)
    return result


# ---------------------------------------------------------------------------
# 标准化器
# ---------------------------------------------------------------------------

def normalize_width(width: str) -> str:
    """将宽度字符串规范化为 [msb:lsb] 形式。

    若已有方括号则原样返回；空字符串返回空串；否则包裹在 [] 中。
    """
    width = width.strip()
    if not width:
        return ""
    if width.startswith("[") and width.endswith("]"):
        return width
    return f"[{width}]"


def normalize_dimension(dimension: str) -> str:
    """将数组维度字符串规范化为 [a:b][c:d][e:f] 形式。

    实现思路：
    1. 若已含方括号（如 [7:0] 或 [7:0][3:0]），逐组提取并拼接，规范化内部空白。
    2. 若无方括号，按顶层逗号拆分，每段独立包裹为一个 [...]。
    """
    dimension = dimension.strip()
    if not dimension:
        return ""

    bracket_groups = re.findall(r"\[\s*([^\]]+?)\s*\]", dimension)
    if bracket_groups:
        return "".join(f"[{grp.strip()}]" for grp in bracket_groups)

    parts = [p.strip() for p in split_csv(dimension) if p.strip()]
    if parts:
        return "".join(f"[{p}]" for p in parts)
    return f"[{dimension}]"


def normalize_trailing_commas(lines: List[str], item_indices: List[int]) -> List[str]:
    """对指定行列表按 Verilog 惯例处理末尾逗号。

    规则：item_indices 所指的"内容行"中，除最后一行外均加逗号；最后一行去逗号。
    先对全部 item 行去逗号，再对非最后项加回逗号，其余行不受影响。
    """
    if not item_indices:
        return lines

    for i in item_indices:
        lines[i] = re.sub(r",\s*$", "", lines[i])

    for i in item_indices[:-1]:
        lines[i] = lines[i].rstrip() + ","

    return lines


# ---------------------------------------------------------------------------
# 文本行编辑助手
# ---------------------------------------------------------------------------

def append_comma_to_port_line(line: str) -> str:
    """在单行文本的代码部分末尾追加逗号，保留行内注释和换行符。

    若代码部分已有逗号则原样返回。行内注释（//...）放在逗号之后。
    """
    newline = ""
    if line.endswith("\r\n"):
        newline = "\r\n"
        core = line[:-2]
    elif line.endswith("\n"):
        newline = "\n"
        core = line[:-1]
    else:
        core = line

    comment_idx = core.find("//")
    if comment_idx >= 0:
        code_part = core[:comment_idx].rstrip()
        comment_part = core[comment_idx:]
    else:
        code_part = core.rstrip()
        comment_part = ""

    if code_part.endswith(","):
        return core + newline

    updated = code_part + ","
    if comment_part:
        updated += " " + comment_part.lstrip()
    return updated + newline


def remove_trailing_comma_from_line(line: str) -> str:
    """删除单行文本代码部分末尾的逗号，保留行内注释和换行符。

    与 append_comma_to_port_line 对称：剥离换行符和注释，删除代码末尾逗号，再重新拼接。
    """
    newline = ""
    if line.endswith("\r\n"):
        newline = "\r\n"
        core = line[:-2]
    elif line.endswith("\n"):
        newline = "\n"
        core = line[:-1]
    else:
        core = line

    comment_idx = core.find("//")
    if comment_idx >= 0:
        code_part = core[:comment_idx].rstrip()
        comment_part = core[comment_idx:]
    else:
        code_part = core.rstrip()
        comment_part = ""

    code_part = re.sub(r",\s*$", "", code_part)
    updated = code_part
    if comment_part:
        updated += " " + comment_part.lstrip()
    return updated + newline


def _find_last_line_span(
    block_text: str, predicate: Callable[[str], bool]
) -> Optional[Tuple[int, int]]:
    """找到文本块中最后一个满足 predicate 的行，返回 (行起始偏移, 行末偏移不含换行符)。

    逐行遍历，记录满足条件的最后一行偏移对。
    若文本无换行符且满足条件则直接返回 (0, len)。
    """
    lines = block_text.splitlines(keepends=True)
    offset = 0
    last_span: Optional[Tuple[int, int]] = None
    for line in lines:
        raw = line.rstrip("\r\n")
        if predicate(raw):
            last_span = (offset, offset + len(raw))
        offset += len(line)
    if not lines and block_text:
        stripped = block_text.rstrip("\r\n")
        if predicate(stripped):
            return (0, len(stripped))
    return last_span


def find_last_matching_line_span(block_text: str, pattern: str) -> Optional[Tuple[int, int]]:
    """找到文本块中最后一行匹配正则 pattern 的行的偏移 span (start, end_no_eol)。

    委托给 _find_last_line_span，predicate 为 re.search(pattern, line)。
    """
    compiled = re.compile(pattern)
    return _find_last_line_span(block_text, lambda raw: bool(compiled.search(raw)))


def get_line_spans(block_text: str) -> List[Dict[str, Any]]:
    """将文本块拆分为行列表，每行记录五个偏移属性。

    返回列表元素：
    - start: 行起始偏移（含换行符前）
    - end_no_eol: 行末偏移（不含换行符）
    - end_full: 行末偏移（含换行符）
    - text: 行文本（不含换行符）
    - raw: 原始行文本（含换行符）
    """
    lines = block_text.splitlines(keepends=True)
    spans: List[Dict[str, Any]] = []
    offset = 0
    for line in lines:
        no_eol = line.rstrip("\r\n")
        end_no_eol = offset + len(no_eol)
        end_full = offset + len(line)
        spans.append(
            {
                "start": offset,
                "end_no_eol": end_no_eol,
                "end_full": end_full,
                "text": no_eol,
                "raw": line,
            }
        )
        offset = end_full
    if not lines and block_text:
        spans.append(
            {
                "start": 0,
                "end_no_eol": len(block_text),
                "end_full": len(block_text),
                "text": block_text,
                "raw": block_text,
            }
        )
    return spans


# ---------------------------------------------------------------------------
# 端口解析助手
# ---------------------------------------------------------------------------

def _extract_raw_port_width(source_text: str, port_name: str, location_offset: int) -> str:
    """从源文本中提取指定端口和位置所在行的原始位宽表达式。

    优先用 location_offset 定位行后提取方括号；若失败则全文搜索端口声明行。
    主要用于宏定义的位宽（如 [`DATA_W-1:0]`）， AST 这类宽度会解析为负数。
    """
    # 优先：用 offset 定位行
    if 0 <= location_offset < len(source_text):
        line_start = source_text.rfind("\n", 0, location_offset) + 1
        line_end = source_text.find("\n", location_offset)
        if line_end < 0:
            line_end = len(source_text)
        line = source_text[line_start:line_end]
        m = re.search(r"\[([^\]]+)\]", line)
        if m:
            return "[" + m.group(1).strip() + "]"
    # 备退：全文搜索包含端口名的声明行
    for line in source_text.splitlines():
        if port_name not in line:
            continue
        if not re.search(r"\b(?:input|output|inout|ref)\b", line, re.IGNORECASE):
            continue
        m = re.search(r"\[([^\]]+)\]", line)
        if m:
            return "[" + m.group(1).strip() + "]"
    return ""


# ---------------------------------------------------------------------------
# 端口解析
# ---------------------------------------------------------------------------

# 用于 ANSI 端口原始文本匹配的预编译常量正则表达式。
# 在类型部分使用贪婪的 `.*` 确保回溯找到最后一个标识符
# 在可选的尾随解包维度括号之前作为端口名称。
# 这避免了因将名称嵌入模式而导致的每个端口正则表达式编译。
_ANSI_PORT_RAW_RE = re.compile(
    r"^(?:input|output|inout|ref)\b(?P<type>.*)\b(?P<found_name>[A-Za-z_]\w*)(?P<dim>(?:\s*\[[^\]]+\])*)\s*$",
    re.IGNORECASE | re.DOTALL,
)


def parse_non_ansi_port_declarations(body_text: str) -> Dict[str, Dict[str, str]]:
    """从非ANSI模块 body 文本中提取 input/output/inout/ref 声明，返回 {name: {direction, type}}。"""
    decls: Dict[str, Dict[str, str]] = {}
    for match in re.finditer(
        r"\b(input|output|inout|ref)\b(?P<rest>[^;]*);",
        body_text,
        flags=re.IGNORECASE | re.DOTALL,
    ):
        direction = match.group(1).strip().lower()
        rest = strip_comments(match.group("rest")).strip()
        if not rest:
            continue

        # 从声明末尾提取名称
        name_match = re.search(r"\b([A-Za-z_]\w*)\s*$", rest)
        if not name_match:
            continue

        name = name_match.group(1)
        type_part = rest[:name_match.start()].strip()

        decls[name] = {"direction": direction, "type": type_part}

    return decls


def parse_module_ports(module_text: str, ports_block: str, body_text: str, is_ansi: bool = False) -> List[Dict[str, str]]:
    """解析模块端口列表：从 ports_block 提取端口信息。"""
    ports_block_clean = strip_comments(ports_block)
    
    if is_ansi:
        port_decls = [x.strip() for x in ports_block_clean.split(",") if x.strip()]
        ports: List[Dict[str, str]] = []
        for decl in port_decls:
            match = _ANSI_PORT_RAW_RE.match(decl)
            if match:
                name = match.group("found_name")
                direction = re.match(r"^(input|output|inout|ref)\b", decl, re.IGNORECASE)
                direction = direction.group(1).lower() if direction else "unknown"
                type_part = match.group("type").strip()
                _ = match.group("dim")  # captured but not used

                width_match = re.search(r"\[[^\]]+\]", type_part)
                width = width_match.group(0) if width_match else ""
                type_without_width = type_part[:width_match.start()] + type_part[width_match.end():].strip() if width_match else type_part
                
                ports.append({
                    "name": name,
                    "direction": direction,
                    "type": type_without_width,
                    "width": width,
                })
        return ports
    else:
        names = parse_non_ansi_port_names(ports_block_clean)
        decl_map = parse_non_ansi_port_declarations(body_text)
        
        result: List[Dict[str, str]] = []
        for name in names:
            name_clean = re.sub(r"\s+", "", name)
            port_info = decl_map.get(name_clean, {"direction": "unknown", "type": ""})
            raw_type = port_info["type"]
            wm = re.search(r"\[[^\]]+\]", raw_type)
            result.append({
                "name": name_clean,
                "direction": port_info["direction"],
                "type": raw_type[:wm.start()] + raw_type[wm.end():].strip() if wm else raw_type,
                "width": wm.group(0) if wm else "",
            })
        
        return result


# ---------------------------------------------------------------------------
# 参数解析
# ---------------------------------------------------------------------------

def _param_names_from_node(module: Any) -> List[str]:
    """Extract parameter names (including localparam) from a module CST node."""
    header = getattr(module, "header", None)
    params_node = getattr(header, "parameters", None) if header else None
    if params_node is None:
        return []

    names: List[str] = []
    seen: Set[str] = set()
    for item in params_node.declarations:
        if not isinstance(item, pyslang.syntax.ParameterDeclarationSyntax):
            continue
        for d in item.declarators:
            if not isinstance(d, pyslang.syntax.DeclaratorSyntax):
                continue
            name = d.name.value
            if name and name not in seen:
                seen.add(name)
                names.append(name)
    return names


# ---------------------------------------------------------------------------
# 模块级解析
# ---------------------------------------------------------------------------

_AST_DIRECTION_MAP: Dict[str, str] = {
    "ArgumentDirection.In": "input",
    "ArgumentDirection.Out": "output",
    "ArgumentDirection.InOut": "inout",
    "ArgumentDirection.Ref": "ref",
}


def _ast_info_from_tree(tree: Any, source_text: str, module_name: str) -> Optional[Dict[str, Any]]:
    """用 pyslang AST 语义层提取端口/参数/实例信息。

    - 方向、参数名、实例名/类型：直接从 AST 符号读取，准确。
    - 端口类型/位宽：使用 AST 编译后类型（如 logic[31:0]）；若宽度为负数（宏未展开
      导致的误判，如 logic[-1:0]），则用 _extract_raw_port_width 从原始源文本提取。
    - 仅当找不到目标模块时返回 None（由调用方全量 CST fallback）。
    """
    try:
        comp = pyslang.ast.Compilation()
        comp.addSyntaxTree(tree)

        root = comp.getRoot()
        body = None
        for top in root.topInstances:
            if top.body.name == module_name:
                body = top.body
                break
        if body is None:
            tops = list(root.topInstances)
            if len(tops) == 1:
                body = tops[0].body
        if body is None:
            return None

        # 端口
        ports: List[Dict[str, str]] = []
        for p in body.portList:
            dir_str = _AST_DIRECTION_MAP.get(str(p.direction), "unknown")
            type_str = str(p.type)

            if p.type.isError or re.search(r"\[\s*-\d+\s*:\s*\d+\s*\]", type_str):
                # 宏未定义导致宽度解析错误 → 从原始源文本提取括号表达式
                width = _extract_raw_port_width(source_text, p.name, p.location.offset)
                base_type = re.sub(r"\[.*\]", "", type_str).strip() or "logic"
            else:
                bracket_idx = type_str.find("[")
                if bracket_idx >= 0:
                    base_type = type_str[:bracket_idx].strip()
                    width = type_str[bracket_idx:]
                else:
                    base_type = type_str
                    width = ""

            ports.append({"name": p.name, "direction": dir_str,
                          "type": base_type, "width": width})

        # 参数（含 localparam）
        param_names = [param.name for param in body.parameters]

        # 实例（nextSibling 链，UninstantiatedDefSymbol = 后续未实例化的子模块引用）
        instances: List[Dict[str, Any]] = []
        if body.portList:
            n = body.portList[0]
            while n is not None:
                if type(n).__name__ == "UninstantiatedDefSymbol":
                    inst_offset = getattr(n, 'location', None)
                    instances.append({
                        "name": n.name,
                        "type": n.definitionName,
                        "offset": inst_offset.offset if inst_offset is not None else -1,
                    })
                n = n.nextSibling

        return {"ports": ports, "param_names": param_names, "instances": instances}
    except Exception:
        return None


# ---------------------------------------------------------------------------
# 实例化片段构建器
# ---------------------------------------------------------------------------

def build_instantiation_snippet(
    row: Dict[str, Any],
    include_params: bool = True,
    instance_name: Optional[str] = None,
    port_map: Optional[Dict[str, str]] = None,
    indent: str = "    ",
) -> str:
    """根据模块 row 生成例化模板字符串，包含参数块（可选）和端口连接列表。

    端口行 '(' 列对齐，行尾附注端口方向及类型注释。
    """
    module_name = row.get("module", "")
    if not module_name:
        return ""

    inst_name = (instance_name or "u_{}".format(module_name)).strip()
    if not inst_name:
        inst_name = "u_{}".format(module_name)

    ports = cast(List[Dict[str, Any]], row.get("ports", []) or [])
    valid_ports = [p for p in ports if str(p.get("name", "")).strip()]
    port_names = [str(p.get("name", "")).strip() for p in valid_ports]
    mapped_names = [
        str((port_map or {}).get(pname, pname)).strip()
        for pname in port_names
    ]
    param_names = list(row.get("param_names") or []) if include_params else []

    lines: List[str] = []

    if param_names:
        lines.append("{} #(".format(module_name))
        for idx, pname in enumerate(param_names):
            comma = "," if idx < len(param_names) - 1 else ""
            lines.append("{}.{}({}){}".format(indent, pname, pname, comma))
        lines.append(") {} (".format(inst_name))
    else:
        lines.append("{} {} (".format(module_name, inst_name))

    max_port_len = max((len(pname) for pname in port_names), default=0)
    max_wire_len = max((len(wname) for wname in mapped_names), default=0)

    cores: List[str] = []
    comments: List[str] = []

    for idx, p in enumerate(valid_ports):
        pname = port_names[idx]
        wire_name = mapped_names[idx]
        comma = "," if idx < len(valid_ports) - 1 else ""
        direction = str(p.get("direction", "")).strip()
        ptype = str(p.get("type", "")).strip()
        comment_parts = [direction] if direction else []
        if ptype:
            comment_parts.append(ptype)
        comment = "// " + " ".join(comment_parts) if comment_parts else ""
        core = "{}.{:<{pw}}({:<{ww}}){}".format(
            indent,
            pname,
            wire_name,
            comma,
            pw=max_port_len,
            ww=max_wire_len,
        )
        cores.append(core)
        comments.append(comment)

    line_width = max((len(core) for core in cores), default=0)
    for idx, core in enumerate(cores):
        comment = comments[idx]
        if comment:
            lines.append("{:<{lw}} {}".format(core, comment, lw=line_width))
        else:
            lines.append(core)

    lines.append(");")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# 编辑操作
# ---------------------------------------------------------------------------

def build_non_ansi_ports_block(names: List[str], indent: str) -> str:
    if not names:
        return ""
    lines = [indent + n for n in names]
    idxs = list(range(len(lines)))
    lines = normalize_trailing_commas(lines, idxs)
    return "\n".join(lines)



# 匹配模块体中任何信号声明行（在 add_wire 中使用）。
_ANY_DECL_LINE_RE = re.compile(
    r"^\s*(?:input|output|inout|ref|wire|logic|reg|bit|tri|integer|var|signed|unsigned)\b[^;\n]*;",
    re.MULTILINE,
)


def compose_port_decl(info: Dict[str, str]) -> str:
    parts = [info["direction"]]
    if info["type"]:
        parts.append(info["type"])
    if info["width"]:
        parts.append(info["width"])
    parts.append(info["name"])
    if info["dimension"]:
        parts.append(info["dimension"])
    return " ".join(p for p in parts if p)


def compose_wire_decl(info: Dict[str, str]) -> str:
    parts = [info["type"]]
    if info["width"]:
        parts.append(info["width"])
    parts.append(info["name"])
    if info["dimension"]:
        parts.append(info["dimension"])
    return " ".join(p for p in parts if p)


# ---------------------------------------------------------------------------
# 内部编辑操作（使用预解析的部分）
# ---------------------------------------------------------------------------



# ---------------------------------------------------------------------------
# 模块编辑器
# ---------------------------------------------------------------------------

class ModuleEditor:
    """对单个 SV/Verilog 模块文本片段进行链式编辑。

    注意：此编辑器只处理 module 文本片段，不处理整个源文件。
    提取和替换 module 的逻辑由调用方（如 cli.py）负责。

    初始化时自动分析 module 的所有信息（名称、端口、实例等），
    后续编辑操作基于这些信息进行，避免重复解析。

    用法::

        # 从源文件提取 module
        module_text, offset_info = extract_module_text(source_text, module_name="my_mod")

        # 编辑 module
        editor = ModuleEditor(module_text)
        print(editor.module_name)  # 访问模块名称
        print(editor.ports)        # 访问端口列表

        # 添加端口 - 使用新的字典格式
        port_dict = {
            "clk": {
                "direction": "input",
                "type": "logic",
                "width": "",
                "dimension": ""
            }
        }
        editor = editor.add_port(port_dict)
        
        # 添加线网 - 使用新的字典格式
        wire_dict = {
            "int_sig": {
                "type": "wire",
                "width": "[7:0]",
                "dimension": ""
            }
        }
        editor = editor.add_wire(wire_dict)
        
        editor = editor.rm_port("obsolete")
        edited_module_text = editor.module_text

        # 替换回源文件
        result = replace_module_text(source_text, offset_info, edited_module_text)

        # 从文件创建编辑器
        editor = ModuleEditor.from_file(path="test.sv", module_name="my_mod")
        print(editor.ports)

        # 生成例化模板
        snippet = editor.gen_inst(include_params=True, instance_name="u_mod")
    """

    def __init__(self, module_text: str) -> None:
        self._module_text = module_text
        self._cached_parts: Optional[Dict[str, Any]] = None
        self._cache_valid = False
        self._tree: Any = None
        self._source_manager: Any = None
        self._analyze_module()

    @staticmethod
    def _apply_text_edits(text: str, edits: List[Tuple[int, int, str]]) -> str:
        """Apply a list of (start, end, replacement) edits to text, back-to-front."""
        if not edits:
            return text
        for start, end, replacement in sorted(edits, key=lambda e: (e[0], e[1]), reverse=True):
            if start < 0 or end < start or end > len(text):
                raise ValueError("Invalid edit range")
            text = text[:start] + replacement + text[end:]
        return text

    @staticmethod
    def _module_list(root: Any) -> List[Any]:
        """从 pyslang 语法树根节点中收集所有 ModuleDeclarationSyntax 节点。"""
        if isinstance(root, pyslang.syntax.ModuleDeclarationSyntax):
            return [root]
        members = getattr(root, "members", None)
        if members is None:
            return []
        return [m for m in members if isinstance(m, pyslang.syntax.ModuleDeclarationSyntax)]

    @staticmethod
    def _extract_module_instances(module: Any, mod_start: int = 0) -> List[Dict[str, Any]]:
        """从模块 CST 节点收集所有实例化（HierarchyInstantiationSyntax），返回 [{name, type, offset}] 列表。"""
        members = getattr(module, "members", None)
        if members is None:
            return []
        instances: List[Dict[str, Any]] = []
        for member in members:
            if not isinstance(member, pyslang.syntax.HierarchyInstantiationSyntax):
                continue
            inst_type = member.type.value
            inst_range = getattr(member, "sourceRange", None)
            inst_offset = (inst_range.start.offset - mod_start) if inst_range is not None else -1
            for inst in member.instances:
                decl = getattr(inst, "decl", None)
                inst_name = decl.name.value if decl is not None else ""
                if inst_name and inst_type:
                    instances.append({"name": inst_name, "type": inst_type, "offset": inst_offset})
        return instances

    @staticmethod
    def _build_module_row(module: Any, source_text: str, source_manager: Any, tree: Any = None) -> Dict[str, Any]:
        """构建模块完整信息字典，包含语义内容和编辑偏移量。

        返回：{module, line, ports, instances, module_text, param_names,
              mod_start, mod_end, open_idx, close_idx, semicolon_idx,
              port_insert_idx, decl_insert_idx, is_ansi}

        - port_insert_idx: 端口列表中插入新端口的偏移（module_text 内，即 close_idx 位置）
        - decl_insert_idx: body 中声明信号的插入偏移（module_text 内，最后一个声明行之后）
        - instances 每项含 {name, type, offset}，offset 为 module_text 内的起始偏移
        """
        header = getattr(module, "header", None)
        name = (header.name.value if header is not None else None) or "<unknown>"

        line = 0
        module_range = getattr(module, "sourceRange", None)
        start = getattr(module_range, "start", None) if module_range else None
        if start is not None:
            line = int(source_manager.getLineNumber(start) or 0)

        mod_start = getattr(start, "offset", None) if start else None
        mod_end = getattr(getattr(module_range, "end", None), "offset", None) if module_range else None
        module_text = source_text[mod_start:mod_end] if mod_start is not None and mod_end is not None else ""

        ports_node = getattr(header, "ports", None) if header else None
        open_idx = close_idx = semicolon_idx = -1
        is_ansi = False
        if ports_node is not None:
            ports_range = getattr(ports_node, "sourceRange", None)
            if ports_range is not None:
                open_idx = ports_range.start.offset - mod_start
                close_idx = ports_range.end.offset - 1 - mod_start
                is_ansi = isinstance(ports_node, pyslang.syntax.AnsiPortListSyntax)
        if close_idx > 0:
            semicolon_idx = module_text.find(";", close_idx)

        # --- 双层策略：优先 AST 语义层，回退 CST 文本层 ---
        ast_info = _ast_info_from_tree(tree, source_text, name) if tree is not None else None

        # 用于 CST fallback 的端口/body 文本
        ports_text = module_text[open_idx + 1:close_idx] if close_idx > 0 else ""
        body_text = module_text[semicolon_idx + 1:] if semicolon_idx >= 0 else ""

        if ast_info is not None:
            ports_result = ast_info["ports"]
            param_names_result: List[str] = ast_info["param_names"]
            instances_result: List[Dict[str, Any]] = ast_info["instances"]
            # AST 层 offset 为源文件绝对偏移，转为 module_text 内相对偏移
            if mod_start is not None:
                for inst in instances_result:
                    if inst.get("offset", -1) >= 0:
                        inst["offset"] -= mod_start
        else:
            # CST fallback（tree 为 None 或 AST 找不到目标模块）
            ports_result = parse_module_ports(module_text, ports_text, body_text, is_ansi=is_ansi)
            param_names_result = _param_names_from_node(module)
            instances_result = ModuleEditor._extract_module_instances(module, mod_start or 0)

        # port_insert_idx: 在 close_idx 处（")" 之前）插入新端口
        port_insert_idx = close_idx

        # decl_insert_idx: body 中最后一个声明行之后的偏移
        decl_insert_idx = semicolon_idx + 1 if semicolon_idx >= 0 else -1
        if semicolon_idx >= 0:
            body = module_text[semicolon_idx + 1:]
            matches = list(_ANY_DECL_LINE_RE.finditer(body))
            if matches:
                last_decl = matches[-1]
                decl_insert_idx = semicolon_idx + 1 + last_decl.end()

        return {
            "module": name,
            "line": line,
            "ports": ports_result,
            "instances": instances_result,
            "module_text": module_text,
            "param_names": param_names_result,
            "mod_start": mod_start,
            "mod_end": mod_end,
            "open_idx": open_idx,
            "close_idx": close_idx,
            "semicolon_idx": semicolon_idx,
            "port_insert_idx": port_insert_idx,
            "decl_insert_idx": decl_insert_idx,
            "is_ansi": is_ansi,
        }





    @classmethod
    def extract_module_text(cls, source_text: str, module_name: Optional[str] = None) -> Tuple[str, Dict[str, int]]:
        """从源文件中提取指定 module 的文本片段，返回 (module_text, offset_info)。

        offset_info 包含 module 在源文件中的位置信息，用于后续替换。
        """
        tree = pyslang.syntax.SyntaxTree.fromText(source_text)
        root = tree.root
        modules = cls._module_list(root)
        if not modules:
            raise ValueError("Module not found")

        # 选择模块
        picked_module = None
        if module_name:
            for mod in modules:
                header = getattr(mod, "header", None)
                try:
                    if header is not None and header.name.value == module_name:
                        picked_module = mod
                        break
                except Exception:
                    continue
            if picked_module is None:
                raise ValueError(f"Module '{module_name}' not found")
        elif len(modules) == 1:
            picked_module = modules[0]
        else:
            # 如果文件包含多个模块且没有指定模块名称，选择第一个模块
            picked_module = modules[0]
        
        source_manager = tree.sourceManager
        row = cls._build_module_row(picked_module, source_text, source_manager, tree=tree)
        
        if row["mod_start"] is None or row["mod_end"] is None:
            raise ValueError("Unable to determine module boundaries")
        
        module_text = source_text[row["mod_start"]:row["mod_end"]]
        offset_info = {
            "mod_start": row["mod_start"],
            "mod_end": row["mod_end"],
        }
        return module_text, offset_info

    @classmethod
    def replace_module_text(cls, source_text: str, offset_info: Dict[str, int], new_module_text: str) -> str:
        """将编辑后的 module 文本替换回源文件。"""
        mod_start = offset_info["mod_start"]
        mod_end = offset_info["mod_end"]
        return source_text[:mod_start] + new_module_text + source_text[mod_end:]

    @classmethod
    def from_file(
        cls,
        path: Union[Path, str],
        module_name: Optional[str] = None,
    ) -> "ModuleEditor":
        """从文件创建 ModuleEditor 实例。

        Args:
            path: 文件路径
            module_name: 模块名称（文件含多个模块时必须指定）

        Returns:
            ModuleEditor 实例
        """
        file_path = Path(path)
        if not file_path.exists():
            raise FileNotFoundError(f"file not found: {file_path}")

        source_text = file_path.read_text(encoding="utf-8", errors="ignore")
        tree = pyslang.syntax.SyntaxTree.fromText(source_text, str(file_path))
        root = tree.root
        modules = cls._module_list(root)
        if not modules:
            raise ValueError("no module found in file")
        
        # 如果没有指定模块名，检查是否只有一个模块
        if module_name is None:
            if len(modules) > 1:
                # 获取所有模块名
                module_names: List[str] = []
                for module in modules:
                    header = getattr(module, "header", None)
                    name = (header.name.value if header is not None else None) or "<unknown>"
                    module_names.append(name)
                
                # 格式化模块名为每行一个的格式
                formatted_names = "\n  - ".join(module_names)
                raise ValueError(f"file contains multiple modules:\n  - {formatted_names}\nPlease specify a module name with --module option.")
            else:
                picked_module = modules[0]
        else:
            # 如果指定了模块名，查找匹配的模块
            picked_module = None
            for mod in modules:
                header = getattr(mod, "header", None)
                if header is not None and header.name.value == module_name:
                    picked_module = mod
                    break
            if picked_module is None:
                available_modules: List[str] = []
                for mod in modules:
                    header = getattr(mod, "header", None)
                    name = (header.name.value if header is not None else None) or "<unknown>"
                    available_modules.append(name)
                raise ValueError(f"Module '{module_name}' not found. Available modules: {', '.join(available_modules)}")
        
        source_manager = tree.sourceManager
        row = cls._build_module_row(picked_module, source_text, source_manager, tree=tree)
        
        if row["mod_start"] is None or row["mod_end"] is None:
            raise ValueError("Unable to determine module boundaries")
        
        module_text = source_text[row["mod_start"]:row["mod_end"]]
        
        # _build_module_row 内部已将偏移量调整为相对于 module_text，无需再次减去 mod_start
        row["module_text"] = module_text
        row["module_name"] = row.pop("module")
        
        # 直接创建实例并缓存
        instance = cls.__new__(cls)
        instance._module_text = module_text
        instance._cached_parts = row
        instance._cache_valid = True
        instance._tree = None
        instance._source_manager = None
        return instance

    def _analyze_module(self) -> None:
        """分析 module 的所有信息"""
        if self._cache_valid:
            return
        
        if self._cached_parts is not None:
            if "module_name" in self._cached_parts:
                self._cache_valid = True
                return
            else:
                self._cached_parts = None
        
        tree = pyslang.syntax.SyntaxTree.fromText(self._module_text)
        root = tree.root
        modules = self._module_list(root)
        if not modules:
            raise ValueError("Module not found")
        picked_module = modules[0]
        self._cached_parts = self._build_module_row(picked_module, self._module_text, tree.sourceManager, tree=tree)
        self._cached_parts["module_name"] = self._cached_parts.pop("module")
        self._cache_valid = True

    def _get_cached_analysis(self) -> Dict[str, Any]:
        """获取模块分析结果（带缓存）"""
        if not self._cache_valid or self._cached_parts is None:
            self._analyze_module()
        assert self._cached_parts is not None
        return self._cached_parts

    def _invalidate_cache(self) -> None:
        """使缓存失效（编辑后需要重新分析）"""
        self._cache_valid = False

    @property
    def module_text(self) -> str:
        """当前（已编辑的）module 文本。"""
        return self._module_text

    @property
    def module_name(self) -> str:
        """模块名称"""
        return self._get_cached_analysis().get("module_name", "")

    @property
    def ports(self) -> List[Dict[str, Any]]:
        """端口列表"""
        return self._get_cached_analysis().get("ports", [])

    @property
    def instances(self) -> List[Dict[str, Any]]:
        """实例列表"""
        return self._get_cached_analysis().get("instances", [])

    @property
    def param_names(self) -> List[str]:
        """参数名称列表"""
        return self._get_cached_analysis().get("param_names", [])

    @property
    def ports_text(self) -> str:
        """端口文本（动态从 module_text 提取）"""
        parts = self._get_cached_analysis()
        open_idx = parts.get("open_idx", -1)
        close_idx = parts.get("close_idx", -1)
        if open_idx >= 0 and close_idx > open_idx:
            return self._module_text[open_idx + 1:close_idx]
        return ""

    @property
    def body_text(self) -> str:
        """body 文本（动态从 module_text 提取）"""
        parts = self._get_cached_analysis()
        semicolon_idx = parts.get("semicolon_idx", -1)
        if semicolon_idx >= 0:
            return self._module_text[semicolon_idx + 1:]
        return ""

    @property
    def is_ansi(self) -> bool:
        """是否为 ANSI 风格端口声明"""
        return self._get_cached_analysis().get("is_ansi", True)

    # ------------------------------------------------------------------
    # 端口编辑
    # ------------------------------------------------------------------

    def add_port(
        self,
        port_dict: Dict[str, Dict[str, str]]
    ) -> "ModuleEditor":
        """向模块添加端口（幂等）。接收一个字典，键为端口名，值为包含 direction/type/width/dimension 属性的字典"""
        
        # 获取模块结构信息一次
        initial_parts = self._get_cached_analysis()
        is_ansi = initial_parts.get("is_ansi", True)
        newline = detect_newline(self._module_text)
        
        # 首先收集所有需要添加的端口，检查哪些是新的
        ports_to_add: List[Dict[str, str]] = []
        for name, attrs in port_dict.items():
            direction = attrs.get("direction", "")
            type_val = attrs.get("type", "")
            width = attrs.get("width", "")
            dimension = attrs.get("dimension", "")
            
            if direction and direction not in {"input", "output", "inout", "ref"}:
                raise ValueError("direction must be input/output/inout/ref")
            if not name:
                raise ValueError("name is required")
                
            info = {
                "direction": direction.lower(),
                "type": type_val.strip(),
                "width": normalize_width(width),
                "name": name,
                "dimension": normalize_dimension(dimension),
            }

            ports_text = self.ports_text
            port_name = info["name"]
            
            ports_text_clean = strip_comments(ports_text)
            if not re.search(rf"\b{re.escape(port_name)}\b", ports_text_clean):
                ports_to_add.append(info)

        # 如果没有任何新端口需要添加，直接返回
        if not ports_to_add:
            self._invalidate_cache()
            return self

        # 处理端口列表的修改
        indent = detect_indent(self.ports_text)
        current_ports_text = self.ports_text
        
        for info in ports_to_add:
            if is_ansi:
                port_decl = compose_port_decl(info)
                new_ports_text = current_ports_text + newline + indent + ", " + port_decl
            else:
                new_ports_text = current_ports_text + newline + indent + ", " + info["name"]
            current_ports_text = new_ports_text

        # 更新模块文本中的端口部分
        old_ports_text = self.ports_text
        self._module_text = self._module_text.replace(old_ports_text, current_ports_text, 1)

        # 如果是非 ANSI 模式，还需要在模块体中添加端口声明
        if not is_ansi:
            # 重新获取分析结果，因为端口列表已被修改
            self._invalidate_cache()
            body_text = self.body_text
            
            # 为所有新端口生成声明（在非 ANSI 模式下，模块体中应使用带方向的声明）
            decl_texts: List[str] = []
            for info in ports_to_add:
                port_decl = compose_port_decl(info)  # 生成带方向的声明，如 "input [7:0] name"
                decl = port_decl + ";"
                body_indent = detect_indent(body_text)
                decl_text = newline + body_indent + decl
                decl_texts.append(decl_text)

            # 只查找一次插入位置，将所有声明添加到该位置
            lines = body_text.splitlines()
            new_lines: List[str] = []
            inserted = False
            
            for line in lines:
                new_lines.append(line)
                stripped_line = line.strip()
                # 查找模块体中的第一个端口/信号声明行
                if re.match(r'^\s*(input|output|inout|ref|wire|logic|reg|bit|tri|integer|var|signed|unsigned)\s+', stripped_line):
                    if not inserted:
                        # 在第一个匹配行后插入所有新声明
                        for decl_text in decl_texts:
                            new_lines.append(decl_text.lstrip())
                        inserted = True
            
            # 如果没有找到匹配项，则在模块体开头添加所有声明
            if not inserted:
                all_decls_text = "".join(decl_texts)
                new_body_text = all_decls_text + body_text
            else:
                new_body_text = newline.join(new_lines)
            
            self._module_text = self._module_text.replace(body_text, new_body_text, 1)
        
        self._invalidate_cache()
        return self

    def rm_port(self, name: str) -> "ModuleEditor":
        """从模块中删除指定端口（幂等）。"""
        name = name.strip()
        if not name:
            raise ValueError("name is required")
        
        # 获取模块结构信息
        parts = self._get_cached_analysis()
        ports_text = self.ports_text
        is_ansi = parts.get("is_ansi", True)

        if is_ansi:
            port_spans = get_line_spans(ports_text)
            item_idxs = [
                i
                for i, row in enumerate(port_spans)
                if (s := row["text"].strip())
                and not s.startswith("//")
                and not s.startswith("/*")
                and not s.startswith("*")
            ]
            target_idx = None
            for i in item_idxs:
                if re.search(rf"\b{re.escape(name)}\b", port_spans[i]["text"]):
                    target_idx = i
                    break

            if target_idx is None:
                self._invalidate_cache()
                return self

            edits: List[Tuple[int, int, str]] = []
            base = parts["open_idx"] + 1

            target = port_spans[target_idx]
            edits.append((base + target["start"], base + target["end_full"], ""))

            prev_items = [i for i in item_idxs if i < target_idx]
            next_items = [i for i in item_idxs if i > target_idx]
            if prev_items and not next_items:
                prev_idx = prev_items[-1]
                prev = port_spans[prev_idx]
                prev_abs_start = base + prev["start"]
                prev_abs_end = base + prev["end_no_eol"]
                prev_text = self._module_text[prev_abs_start:prev_abs_end]
                updated_prev = remove_trailing_comma_from_line(prev_text)
                if updated_prev != prev_text:
                    edits.append((prev_abs_start, prev_abs_end, updated_prev))

            self._module_text = ModuleEditor._apply_text_edits(self._module_text, edits)

        else:
            indent = detect_indent(ports_text)
            names = parse_non_ansi_port_names(ports_text)
            new_names = [n for n in names if n != name]
            if len(new_names) == len(names):  # 没有找到要删除的端口
                self._invalidate_cache()
                return self
            new_ports_text = build_non_ansi_ports_block(new_names, indent)

            edits = [
                (
                    parts["open_idx"] + 1,
                    parts["close_idx"],
                    new_ports_text,
                )
            ]

            body = self._module_text[parts["semicolon_idx"] + 1 :]
            body_spans = get_line_spans(body)
            body_base = parts["semicolon_idx"] + 1
            for row in body_spans:
                if re.search(
                    rf"^\s*(input|output|inout|ref|wire|logic|reg|bit|tri|integer|var|signed|unsigned)\b[^;\n]*\b{re.escape(name)}\b[^;\n]*;\s*$",
                    row["text"],
                ):
                    edits.append((body_base + row["start"], body_base + row["end_full"], ""))

            self._module_text = ModuleEditor._apply_text_edits(self._module_text, edits)

        self._invalidate_cache()
        return self

    # ------------------------------------------------------------------
    # 线网编辑
    # ------------------------------------------------------------------

    def add_wire(
        self,
        wire_dict: Dict[str, Dict[str, str]]
    ) -> "ModuleEditor":
        """向模块 body 添加 wire/logic 声明（幂等）。接收一个字典，键为信号名，值为包含 type/width/dimension 属性的字典"""
        for name, attrs in wire_dict.items():
            type_val = attrs.get("type", "wire")
            width = attrs.get("width", "")
            dimension = attrs.get("dimension", "")
            
            name = name.strip()
            if not name:
                raise ValueError("name is required")
            info = {
                "type": type_val.strip() or "wire",
                "width": normalize_width(width),
                "name": name,
                "dimension": normalize_dimension(dimension),
            }

            parts = self._get_cached_analysis()
            body = self._module_text[parts["semicolon_idx"] + 1 :]
            if re.search(
                rf"^\s*(?:input|output|inout|ref|wire|logic|reg|bit|tri|integer|var|signed|unsigned)\b[^;\n]*\b{re.escape(info['name'])}\b[^;\n]*;",
                body,
                flags=re.MULTILINE,
            ):
                continue  # wire 已存在，跳过

            decl = compose_wire_decl(info) + ";"
            newline = detect_newline(self._module_text)

            matches = list(_ANY_DECL_LINE_RE.finditer(body))
            if matches:
                last_decl = matches[-1]
                abs_insert = parts["semicolon_idx"] + 1 + last_decl.end()
                line_indent = re.match(r"\s*", last_decl.group(0))
                indent = line_indent.group(0) if line_indent and line_indent.group(0) else detect_indent(body)
                insert_text = newline + indent + decl
            else:
                abs_insert = parts["semicolon_idx"] + 1
                indent = detect_indent(body)
                insert_text = newline + indent + decl

            self._module_text = ModuleEditor._apply_text_edits(self._module_text, [(abs_insert, abs_insert, insert_text)])
        
        self._invalidate_cache()
        return self

    def rm_wire(self, name: str) -> "ModuleEditor":
        """从模块 body 中删除指定 wire/logic 声明行（幂等）。"""
        name = name.strip()
        if not name:
            raise ValueError("name is required")
        
        parts = self._get_cached_analysis()
        body = self.body_text
        body_spans = get_line_spans(body)
        body_base = parts["semicolon_idx"] + 1

        name_re = re.compile(r"\b{}\b".format(re.escape(name)))
        edits: List[Tuple[int, int, str]] = []
        for row in body_spans:
            line = row["text"]
            if WIRE_DECL_LINE_RE.search(line) and name_re.search(line):
                edits.append((body_base + row["start"], body_base + row["end_full"], ""))

        if not edits:
            self._invalidate_cache()
            return self

        self._module_text = ModuleEditor._apply_text_edits(self._module_text, edits)
        self._invalidate_cache()
        return self

    # ------------------------------------------------------------------
    # 实例端口编辑
    # ------------------------------------------------------------------

    def add_inst_port(
        self,
        inst_port_dict: Dict[str, Dict[str, Dict[str, str]]]
    ) -> "ModuleEditor":
        """向指定实例的连接列表末尾添加 .port(wire) 条目（幂等）。接收一个字典，键为实例名，值为包含端口名和对应wire信息的嵌套字典"""
        for instname, ports in inst_port_dict.items():
            for port_name, wire_info in ports.items():
                wire = wire_info.get("wire", "")
                
                instname = instname.strip()
                port_name = port_name.strip()
                wire = wire.strip()
                if not instname or not port_name:
                    raise ValueError("instname and port_name are required")

                open_idx, close_idx = find_instance_conn_bounds(self._module_text, instname)

                conn_block = self._module_text[open_idx + 1 : close_idx]
                if re.search(rf"\.\s*{re.escape(port_name)}\s*\(", conn_block):
                    continue  # 端口连接已存在，跳过

                indent = detect_indent(conn_block)
                newline = detect_newline(self._module_text)
                new_conn = f".{port_name}({wire})" if wire else f".{port_name}()"
                edits: List[Tuple[int, int, str]] = []

                last_span = find_last_matching_line_span(conn_block, r"\.\s*[A-Za-z_][A-Za-z0-9_$]*\s*\(")
                if last_span is not None:
                    rel_start, rel_end = last_span
                    abs_start = open_idx + 1 + rel_start
                    abs_end = open_idx + 1 + rel_end
                    line = self._module_text[abs_start:abs_end]
                    updated = append_comma_to_port_line(line)
                    if updated != line:
                        edits.append((abs_start, abs_end, updated))

                _stripped_cb = conn_block.rstrip(" \t")
                trailing_ws = len(conn_block) - len(_stripped_cb)
                _has_nl = _stripped_cb.endswith("\n") or _stripped_cb.endswith("\r")
                
                prefix = "" if (conn_block and _has_nl) else newline
                insert_text = prefix + indent + new_conn + newline
                
                abs_close = close_idx - trailing_ws
                edits.append((abs_close, abs_close + trailing_ws, insert_text))

                self._module_text = ModuleEditor._apply_text_edits(self._module_text, edits)
        
        self._invalidate_cache()
        return self

    def rm_inst_port(self, *, instname: str, name: str) -> "ModuleEditor":
        """从指定实例的连接列表中删除指定 .port() 条目（幂等）。"""
        instname = instname.strip()
        name = name.strip()
        if not instname or not name:
            raise ValueError("instname and name are required")

        open_idx, close_idx = find_instance_conn_bounds(self._module_text, instname)

        conn_block = self._module_text[open_idx + 1 : close_idx]
        conn_spans = get_line_spans(conn_block)
        conn_item_idxs = [
            i
            for i, row in enumerate(conn_spans)
            if re.search(r"\.\s*[A-Za-z_][A-Za-z0-9_$]*\s*\(", row["text"])
        ]

        target_idx = None
        for i in conn_item_idxs:
            if re.search(rf"\.\s*{re.escape(name)}\s*\(", conn_spans[i]["text"]):
                target_idx = i
                break

        if target_idx is None:
            self._invalidate_cache()
            return self

        edits: List[Tuple[int, int, str]] = []
        base = open_idx + 1

        target = conn_spans[target_idx]
        edits.append((base + target["start"], base + target["end_full"], ""))

        prev_items = [i for i in conn_item_idxs if i < target_idx]
        next_items = [i for i in conn_item_idxs if i > target_idx]
        if prev_items and not next_items:
            prev_idx = prev_items[-1]
            prev = conn_spans[prev_idx]
            prev_abs_start = base + prev["start"]
            prev_abs_end = base + prev["end_no_eol"]
            prev_text = self._module_text[prev_abs_start:prev_abs_end]
            updated_prev = remove_trailing_comma_from_line(prev_text)
            if updated_prev != prev_text:
                edits.append((prev_abs_start, prev_abs_end, updated_prev))

        self._module_text = ModuleEditor._apply_text_edits(self._module_text, edits)
        self._invalidate_cache()
        return self

    # ------------------------------------------------------------------
    # 分析方法
    # ------------------------------------------------------------------

    def gen_inst(
        self,
        include_params: bool = True,
        instance_name: Optional[str] = None,
        port_map: Optional[Dict[str, str]] = None,
        indent: str = "    ",
    ) -> str:
        """生成模块例化模板。

        Args:
            include_params: 是否包含参数块
            instance_name: 自定义实例名称（默认：u_<module_name>）
            port_map: 可选的端口到信号的映射
            indent: 端口/参数行的缩进字符串

        Returns:
            例化模板字符串
        """
        row = self._get_cached_analysis()
        # build_instantiation_snippet 期望 "module" 键，而缓存中使用 "module_name"
        if "module" not in row and "module_name" in row:
            row = dict(row)
            row["module"] = row["module_name"]
        return build_instantiation_snippet(row, include_params, instance_name, port_map, indent)

    def analyze(self) -> Dict[str, Any]:
        """返回模块的完整分析信息。

        Returns:
            包含以下键的字典：
            - module_name: 模块名称
            - line: 声明行号
            - ports: 端口列表
            - instances: 实例列表
            - module_text: 模块源文本
            - param_names: 参数名称列表
        """
        return self._get_cached_analysis()


    @classmethod
    def list_modules_in_file(cls, path: Union[Path, str]) -> List[str]:
        """获取文件中所有模块的名称列表。
        
        Args:
            path: 文件路径
            
        Returns:
            模块名称列表
        """
        file_path = Path(path)
        if not file_path.exists():
            raise FileNotFoundError(f"file not found: {file_path}")
        
        source_text = file_path.read_text(encoding="utf-8", errors="ignore")
        tree = pyslang.syntax.SyntaxTree.fromText(source_text, str(file_path))
        modules = cls._module_list(tree.root)
        
        module_names: List[str] = []
        for module in modules:
            header = getattr(module, "header", None)
            name = (header.name.value if header is not None else None) or "<unknown>"
            module_names.append(name)
        
        return module_names

    def get_hier(self) -> Dict[str, Any]:
        """从缓存中获取层次信息（仅实例列表）。
        
        Returns:
            包含模块名和实例列表的字典
        """
        cached = self._get_cached_analysis()
        return {
            "module": cached.get("module_name", ""),
            "instances": cached.get("instances", [])
        }