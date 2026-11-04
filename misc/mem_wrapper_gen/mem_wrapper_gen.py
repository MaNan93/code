#!/usr/bin/env python3
"""从标准 wrapper/RF 文件生成单颗或拼接 RF 例化。

YAML: wrapper_dir、rf_dir、rf_instance（可选）、wrappers: {wrapper.sv: RF文件名或尺寸}。
路径相对于运行目录。DP/WD/PW 从文件名推导；RF 为上升沿同步读，下一拍出数。
//E 位于原有合法端口列表末尾，// instantiate 位于模块内部；仅生成一次。
"""
from __future__ import annotations

import argparse
import difflib
import logging
import re
import shutil
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional

try:
    import yaml
except ImportError:
    sys.exit("ERROR: 需要 PyYAML，pip install pyyaml")

log = logging.getLogger("mem_wrapper_gen")
INDENT = "    "
BEGIN_FMT = "// BEGIN mem_wrapper_gen {tag}"
END_FMT = "// END mem_wrapper_gen {tag}"
DEFAULT_RF_INSTANCE = "u_starsky_pcie_ram"


class GenError(Exception):
    pass


@dataclass
class PortInfo:
    name: str
    direction: str
    raw_range: Optional[str] = None
    width: Optional[int] = None


@dataclass
class ModuleInfo:
    name: str
    ports: dict[str, PortInfo]
    signals: set[str]
    text: str


_CLAUSE = re.compile(
    r"(input|output|inout)\s+"
    r"((?:(?:wire|reg|logic|bit|signed|unsigned|var)\s+)*)"
    r"(\[[^\]]+\])?\s*(.+)$", re.S,
)


def _strip_comments(t: str) -> str:
    t = re.sub(r"/\*.*?\*/", " ", t, flags=re.S)
    t = re.sub(r"//[^\n]*", "", t)
    return t


def _split_top_level(s: str, sep: str = ",") -> list[str]:
    out, buf, depth = [], [], 0
    for ch in s:
        if ch in "[{(":
            depth += 1
            buf.append(ch)
        elif ch in "]})":
            depth -= 1
            buf.append(ch)
        elif ch == sep and depth == 0:
            out.append("".join(buf))
            buf = []
        else:
            buf.append(ch)
    if buf:
        out.append("".join(buf))
    return out


def _safe_eval(expr: str, symbols: dict[str, int]) -> int:
    expr = re.sub(r"\$clog2", "_clog2", expr.strip())
    env = {"_clog2": lambda n: max(0, (int(n) - 1).bit_length())}
    env.update({k: v for k, v in symbols.items() if isinstance(v, int)})
    return int(eval(expr, {"__builtins__": {}}, env))  # noqa: S307


def _eval_range(rs: str, sym: dict[str, int]) -> Optional[int]:
    m = re.match(r"\[\s*(.+?)\s*:\s*(.+?)\s*\]", rs, re.S)
    if not m:
        return None
    try:
        a, b = _safe_eval(m.group(1), sym), _safe_eval(m.group(2), sym)
        return abs(a - b) + 1
    except Exception:
        return None


def _parse_params(src: str, seed: dict[str, int]) -> dict[str, int]:
    sym = dict(seed)
    for item in _split_top_level(src):
        item = item.strip()
        if not item:
            continue
        m = re.match(
            r"(?:parameter|localparam)\s+(?:type\s+)?"
            r"(?:(?:int|integer|bit|logic|signed|unsigned)\s+)*"
            r"(\w+)\s*=\s*(.+)$", item, re.S)
        if not m:
            continue
        name, expr = m.group(1), m.group(2).strip().rstrip(",").strip()
        try:
            val = _safe_eval(expr, sym)
        except Exception:
            continue
        # 文件名推出来的尺寸（seed）优先于文件里的参数默认值
        if name not in seed:
            sym[name] = val
    return sym


def _parse_ports(src: str, sym: dict[str, int]) -> dict[str, PortInfo]:
    ports: dict[str, PortInfo] = {}
    direction: Optional[str] = None
    rs: Optional[str] = None
    width: Optional[int] = None
    for item in _split_top_level(src):
        item = item.strip()
        if not item:
            continue
        m = _CLAUSE.match(item)
        if m:
            direction, rs, names_part = m.group(1), m.group(3), m.group(4)
            width = 1 if rs is None else _eval_range(rs, sym)
        elif direction is not None:
            # 逗号后的端口继承上一项的方向和位宽，如 input [3:0] A, B。
            names_part = item
        else:
            continue
        for raw in _split_top_level(names_part):
            name = re.sub(r"\[.*?\]", "", raw.strip()).strip()
            if re.fullmatch(r"[A-Za-z_]\w*", name):
                ports[name] = PortInfo(name=name, direction=direction,
                                       raw_range=rs, width=width)
    return ports


def _match_paren(s: str, start: int) -> int:
    """s[start] == '('，返回配对的 ')' 下标；找不到返回 -1。"""
    depth = 0
    for i in range(start, len(s)):
        if s[i] == "(":
            depth += 1
        elif s[i] == ")":
            depth -= 1
            if depth == 0:
                return i
    return -1


def _split_module_header(text: str):
    """按括号配对切 module 头，返回 (name, param_src, port_src, body_start)。"""
    m = re.search(r"\bmodule\s+(\w+)", text)
    if not m:
        return None
    name, i, n = m.group(1), m.end(), len(text)

    def skip(i: int) -> int:
        while i < n and text[i].isspace():
            i += 1
        return i

    i = skip(i)
    params = ""
    if i < n and text[i] == "#":
        i = skip(i + 1)
        if i < n and text[i] == "(":
            j = _match_paren(text, i)
            if j < 0:
                return None
            params, i = text[i + 1:j], j + 1
            i = skip(i)
    ports = ""
    if i < n and text[i] == "(":
        j = _match_paren(text, i)
        if j < 0:
            return None
        ports, i = text[i + 1:j], j + 1
    semi = text.find(";", i)
    if semi < 0:
        return None
    return name, params, ports, semi + 1


_SUBPROGRAM = re.compile(r"\b(?:function|task)\b.*?\b(?:endfunction|endtask)\b", re.S)


_SIG_DECL = re.compile(r"^(?:wire|reg|logic|bit)\b")


def _parse_body_signals(body: str) -> set[str]:
    """body 里声明的内部信号（wire/reg/logic），用来判断同名连接是否可接。"""
    out: set[str] = set()
    for chunk in body.split(";"):
        s = chunk.strip()
        if not _SIG_DECL.match(s):
            continue
        s = re.sub(r"=.*$", "", s, flags=re.S)
        for part in _split_top_level(s):
            name = re.sub(r"\[.*?\]", "", part).strip().split()
            if name and re.fullmatch(r"[A-Za-z_]\w*", name[-1]):
                out.add(name[-1])
    return out


def parse_sv_module(path: Path, seed: Optional[dict[str, int]] = None) -> ModuleInfo:
    with path.open(encoding="utf-8-sig", newline="") as stream:
        raw = stream.read()
    text = _strip_comments(raw)
    hdr = _split_module_header(text)
    if hdr is None:
        raise GenError(f"{path}: 无法解析 module 声明")
    name, param_src, port_src, body_start = hdr
    body = _SUBPROGRAM.sub(" ", text[body_start:].split("endmodule", 1)[0])
    sym = _parse_params(param_src, seed or {})
    chunks = [chunk.strip() for chunk in body.split(";")]
    for chunk in chunks:
        if re.match(r"(?:parameter|localparam)\b", chunk):
            sym.update(_parse_params(chunk, sym))
    ports = _parse_ports(port_src, sym)
    if not ports:
        for chunk in chunks:
            if _CLAUSE.match(chunk):
                ports.update(_parse_ports(chunk, sym))
    if not ports:
        raise GenError(f"{path}: 无法解析端口表")
    return ModuleInfo(name, ports, _parse_body_signals(body), raw)


def _size_symbols(dp: int, wd: int) -> dict[str, int]:
    aw = _clog2(dp)
    return {"DP": dp, "DEPTH": dp, "WD": wd, "DW": wd, "WIDTH": wd,
            "PW": aw, "AW": aw}


def _clog2(n: int) -> int:
    return 0 if n <= 1 else (n - 1).bit_length()


def _is_pow2(n: int) -> bool:
    return n > 0 and (n & (n - 1)) == 0


@dataclass
class SpliceInfo:
    n_d: int
    n_w: int
    rf_dp: int
    rf_dw: int
    rf_aw: int
    aw: int
    dp: int
    dw: int
    dw_pad: int

    @property
    def mode(self) -> str:
        if self.n_d == 1 and self.n_w == 1:
            return "single"
        if self.n_d > 1 and self.n_w == 1:
            return "depth"
        if self.n_d == 1 and self.n_w > 1:
            return "width"
        return "2d"


@dataclass
class Job:
    file: Path
    type: str
    rf_file: Path
    rf_module: str
    rf_instance: str
    connections: dict[str, Optional[str]]
    splice: SpliceInfo
    wrapper: ModuleInfo
    rf: ModuleInfo
    auto_ports: list[tuple[str, int]] = field(default_factory=list)

    @property
    def dp(self) -> int:
        return self.splice.dp

    @property
    def wd(self) -> int:
        return self.splice.dw

    @property
    def rf_size(self) -> str:
        return f"{self.splice.rf_dp}x{self.splice.rf_dw}"

    @property
    def mode(self) -> str:
        return self.splice.mode


DEFAULT_TEMPLATES: dict[str, dict[str, str]] = {
    "2p_2c": {"CLKA": "clka", "MEA": "ena", "WEA": "wea", "ADRA": "addra",
              "DA": "dina", "CLKB": "clkb", "MEB": "enb", "ADRB": "addrb",
              "QB": "doutb"},
    "2p_1c": {"CLKA": "clk", "MEA": "ena", "WEA": "wea", "ADRA": "addra",
              "DA": "dina", "CLKB": "clk", "MEB": "enb", "ADRB": "addrb",
              "QB": "doutb"},
    "1p": {"CLKA": "clk", "MEA": "en", "WEA": "we", "ADRA": "addr",
           "DA": "din", "CLKB": "clk", "MEB": "en & ~we", "ADRB": "addr",
           "QB": "dout"},
}


DEFAULT_SHARED_INPUTS = ("RMEA", "RMA", "RMEB", "RMB")


@dataclass
class PortCheckResult:
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


_BARE_IDENT = re.compile(r"^[A-Za-z_]\w*$")


_ROLE = {
    "ADRA": "addr", "ADRB": "addr",
    "DA": "din", "QB": "dout",
    "MEA": "en", "MEB": "en", "WEA": "en", "WEB": "en",
}


def _expected_width(job: Job, port: str, side: str) -> Optional[int]:
    """side: 'rf' -> RF 侧期望位宽, 'wrap' -> wrapper 侧期望位宽。"""
    m = job.splice
    role = _ROLE.get(port)
    if role is None:
        return None
    if role == "addr":
        return m.rf_aw if side == "rf" else m.aw
    if role in ("din", "dout"):
        return m.rf_dw if side == "rf" else m.dw
    return 1


def load_config(path: Path) -> dict[str, Any]:
    cfg = yaml.safe_load(path.read_text(encoding="utf-8-sig"))
    if not isinstance(cfg, dict):
        raise GenError(f"{path}: 配置应为映射")
    return cfg


def build_jobs(cfg: dict[str, Any], only: Optional[set[str]] = None) -> list[Job]:
    for key in ("wrapper_dir", "rf_dir", "wrappers"):
        if not cfg.get(key):
            raise GenError(f"缺少 {key}")
    entries = cfg["wrappers"]
    if not isinstance(entries, dict):
        raise GenError("wrappers 应为 {wrapper.sv: RF文件名或尺寸} 映射")
    if only:
        entries = {name: size for name, size in entries.items() if name in only}
        if not entries:
            raise GenError(f"--only 无匹配: {sorted(only)}")
    jobs: list[Job] = []
    rf_cache: dict[Path, ModuleInfo] = {}
    for filename, size in entries.items():
        path = Path(cfg["wrapper_dir"]) / filename
        match = re.fullmatch(r"(?:\w+_)?ram_(1p|2p_1c|2p_2c)_(\d+)wx(\d+)", path.stem)
        if not match:
            raise GenError(f"{filename}: wrapper 名应为 ram_TYPE_DPwxWD.sv 或带前缀的同类名称")
        rf_file = Path(cfg["rf_dir"]) / str(size)
        if rf_file.suffix not in (".v", ".sv"):
            rf_file = rf_file.with_name(rf_file.name + ".v")
        rf_match = re.search(r"(\d+)x(\d+)", rf_file.stem)
        if not rf_match:
            raise GenError(f"{filename}: RF 文件名 {rf_file.name!r} 中找不到 DPxWD 尺寸")
        kind, dp, wd = match[1], int(match[2]), int(match[3])
        rf_dp, rf_dw = int(rf_match[1]), int(rf_match[2])
        if min(dp, wd, rf_dp, rf_dw) < 1:
            raise GenError(f"{filename}: 深度和位宽必须为正数")
        n_d, n_w = (dp + rf_dp - 1) // rf_dp, (wd + rf_dw - 1) // rf_dw
        aw, rf_aw = _clog2(dp), _clog2(rf_dp)
        if n_d > 1 and not _is_pow2(rf_dp):
            raise GenError(f"{filename}: 深度拼接要求 RF 深度为 2 的幂")
        splice = SpliceInfo(n_d, n_w, rf_dp, rf_dw, rf_aw, aw, dp, wd, n_w * rf_dw)
        wrapper = parse_sv_module(path, _size_symbols(dp, wd))
        if re.search(r"^\s*// BEGIN mem_wrapper_gen\b", wrapper.text, re.M):
            raise GenError(f"{path}: 已生成过，请使用原始 wrapper 或恢复 .bak 后生成")
        if rf_file not in rf_cache:
            rf_cache[rf_file] = parse_sv_module(rf_file, _size_symbols(rf_dp, rf_dw))
        rf = rf_cache[rf_file]
        connections = dict(DEFAULT_TEMPLATES[kind])
        auto_ports = []
        known = set(wrapper.ports) | wrapper.signals
        for name, port in rf.ports.items():
            if name == "RSCOUT" and port.direction == "output":
                connections[name] = ""  # 显式 .RSCOUT()，不连接同名信号。
            elif name in connections:
                continue
            elif name in known:
                connections[name] = name
            elif port.direction == "output":
                connections[name] = None
            elif name in DEFAULT_SHARED_INPUTS:
                if port.width is None:
                    raise GenError(f"{rf_file}: 无法确定 {name} 的位宽")
                connections[name] = name
                auto_ports.append((name, port.width))
            else:
                connections[name] = "1'b0"
        jobs.append(Job(path, kind, rf_file, rf.name,
                        str(cfg.get("rf_instance") or DEFAULT_RF_INSTANCE),
                        connections, splice, wrapper, rf, auto_ports))
    return jobs


def check_jobs(jobs: list[Job]) -> PortCheckResult:
    """统一校验已解析的端口；不重新读取文件。"""
    result = PortCheckResult()
    for job in jobs:
        where = job.file.name
        unknown = set(job.connections) - set(job.rf.ports)
        if unknown:
            result.errors.append(f"{where}: RF 缺少端口 {sorted(unknown)}")
        auto = {name for name, _ in job.auto_ports}
        for name, expr in job.connections.items():
            port = job.rf.ports.get(name)
            if port is None or expr is None:
                continue
            want = _expected_width(job, name, "rf")
            if want is not None and port.width != want:
                result.errors.append(f"{where}: RF {name} 位宽 {port.width}，期望 {want}")
            if not _BARE_IDENT.fullmatch(expr):
                continue
            wp = job.wrapper.ports.get(expr)
            if wp is None:
                if expr not in job.wrapper.signals and expr not in auto:
                    result.errors.append(f"{where}: wrapper 缺少信号 {expr}（RF {name}）")
                continue
            if port.direction != "inout" and port.direction != wp.direction:
                result.errors.append(f"{where}: {name} 与 {expr} 方向不匹配")
            want = _expected_width(job, name, "wrap")
            if want is not None:
                if wp.width is None or wp.width < want:
                    result.errors.append(f"{where}: wrapper {expr} 位宽 {wp.width}，至少需要 {want}")
                elif wp.width > want:
                    result.warnings.append(f"{where}: wrapper {expr} 位宽 {wp.width}，期望 {want}")
    return result


def _render_single(job: Job, indent: str) -> list[str]:
    conns = [(p, e) for p, e in job.connections.items() if e is not None]
    if not conns:
        raise GenError(f"{job.file.name}: 无有效连接")
    m = job.splice
    data_pad = m.rf_dw - m.dw
    addr_pad = m.rf_aw - m.aw
    qb = job.connections.get("QB")
    out: list[str] = []
    if data_pad and qb is not None:
        out.append(f"{indent}wire [{m.rf_dw-1}:0] doutb_pad;")
    out.append(f"{indent}{job.rf_module} {job.rf_instance} (")
    for i, (p, e) in enumerate(conns):
        if p == "DA" and data_pad:
            e = f"{{{data_pad}'b0, {e}}}"
        elif p == "QB" and data_pad:
            e = "doutb_pad"
        elif p in ("ADRA", "ADRB") and addr_pad:
            e = f"{{{addr_pad}'b0, {e}}}"
        comma = "," if i < len(conns) - 1 else ""
        out.append(f"{indent}{indent}.{p}({e}){comma}")
    out.append(f"{indent});")
    if data_pad and qb is not None:
        out.append(f"{indent}assign {qb} = {_slice('doutb_pad', m.dw - 1)};")
    return out


def _slice(expr: str, hi: int, lo: int = 0) -> str:
    base = expr if _BARE_IDENT.match(expr) else f"({expr})"
    return f"{base}[{hi}:{lo}]"


def _render_spliced(job: Job) -> list[str]:
    indent = INDENT
    m = job.splice

    if m.mode == "single":
        return _render_single(job, indent)

    conns = job.connections
    mea, meb = conns["MEA"], conns["MEB"]
    adra, adrb = conns["ADRA"], conns["ADRB"]
    da, qb = conns["DA"], conns["QB"]
    clkb = conns["CLKB"]

    pad = m.dw_pad != m.dw

    out: list[str] = []
    if pad:
        out.append(f"{indent}wire [{m.dw_pad-1}:0] dina_pad;")
        out.append(f"{indent}assign dina_pad = {m.dw_pad}'({da});")
    out.append(f"{indent}logic [{m.dw_pad-1}:0] doutb_pad;")
    if m.n_d > 1:
        out.append(f"{indent}wire [{m.dw_pad-1}:0] rdata_banks [0:{m.n_d-1}];")
    out.append("")

    out.append(f"{indent}generate")
    row = indent + "    "
    if m.n_d > 1:
        out.append(f"{row}for (genvar gd = 0; gd < {m.n_d}; gd++) begin : g_row")
        row += "    "
        out.append(f"{row}wire cs_a = ({mea}) & ({_slice(adra, m.aw-1, m.rf_aw)} == gd);")
        out.append(f"{row}wire cs_b = ({meb}) & ({_slice(adrb, m.aw-1, m.rf_aw)} == gd);")
    col = row
    if m.n_w > 1:
        out.append(f"{row}for (genvar gw = 0; gw < {m.n_w}; gw++) begin : g_col")
        col = row + "    "
    out.append(f"{col}wire [{m.rf_dw-1}:0] qb_i;")
    out.append(f"{col}{job.rf_module} {job.rf_instance} (")

    port_lines: list[tuple[str, str]] = []
    for port, expr in job.connections.items():
        if expr is None:
            continue
        if port == "MEA" and m.n_d > 1:
            port_lines.append((port, "cs_a"))
        elif port == "MEB" and m.n_d > 1:
            port_lines.append((port, "cs_b"))
        elif port in ("ADRA", "ADRB") and m.n_d > 1:
            port_lines.append((port, _slice(expr, m.rf_aw - 1)))
        elif port in ("ADRA", "ADRB") and m.aw < m.rf_aw:
            port_lines.append((port, f"{{{m.rf_aw - m.aw}'b0, {expr}}}"))
        elif port == "DA" and m.n_w > 1:
            src = "dina_pad" if pad else da
            port_lines.append((port, f"{src}[gw*{m.rf_dw} +: {m.rf_dw}]"))
        elif port == "DA" and m.n_w == 1 and pad:
            port_lines.append((port, "dina_pad"))
        elif port == "QB":
            port_lines.append((port, "qb_i"))
        else:
            port_lines.append((port, expr))

    for i, (p, e) in enumerate(port_lines):
        comma = "," if i < len(port_lines) - 1 else ""
        out.append(f"{col}    .{p}({e}){comma}")
    out.append(f"{col});")

    if m.n_d > 1 and m.n_w > 1:
        out.append(f"{col}assign rdata_banks[gd][gw*{m.rf_dw} +: {m.rf_dw}] = qb_i;")
    elif m.n_d > 1:
        out.append(f"{col}assign rdata_banks[gd] = qb_i;")
    elif m.n_w > 1:
        out.append(f"{col}assign doutb_pad[gw*{m.rf_dw} +: {m.rf_dw}] = qb_i;")

    if m.n_w > 1:
        out.append(f"{row}end")
    if m.n_d > 1:
        out.append(f"{indent}    end")
    out.append(f"{indent}endgenerate")

    if m.n_d > 1:
        bw = m.aw - m.rf_aw
        out.append("")
        out.append(f"{indent}logic [{bw-1}:0] bank_sel_q;")
        out.append(f"{indent}always_ff @(posedge {clkb}) begin")
        out.append(f"{indent}    if ({meb}) bank_sel_q <= {_slice(adrb, m.aw-1, m.rf_aw)};")
        out.append(f"{indent}end")
        out.append(f"{indent}always_comb begin")
        out.append(f"{indent}    case (bank_sel_q)")
        for gd in range(m.n_d):
            out.append(f"{indent}        {bw}'d{gd}: doutb_pad = rdata_banks[{gd}];")
        out.append(f"{indent}        default: doutb_pad = '0;")
        out.append(f"{indent}    endcase")
        out.append(f"{indent}end")

    out.append("")
    if m.dw_pad == m.dw:
        out.append(f"{indent}assign {qb} = doutb_pad;")
    else:
        out.append(f"{indent}assign {qb} = {_slice('doutb_pad', m.dw - 1)};")

    return out


def _find_anchor(lines: list[str], marker: str, where: str) -> int:
    indices = [i for i, line in enumerate(lines)
               if line.strip() == marker or line.strip().startswith(marker + " ")]
    if len(indices) != 1:
        raise GenError(f"{where}: 标记 {marker!r} 应出现一次，实际 {len(indices)} 次")
    return indices[0]


def process_file(job: Job, dry_run: bool = False, backup: bool = True) -> bool:
    text = job.wrapper.text
    crlf = text.count("\r\n")
    nl = "\r\n" if crlf > text.count("\n") - crlf else "\n"
    lines = text.splitlines()
    if re.search(rf"\b{re.escape(job.rf_instance)}\b", _strip_comments(text)):
        raise GenError(f"{job.file}: 已有 {job.rf_instance} 例化")
    blocks = [("inst", "// instantiate", _render_spliced(job))]
    if job.auto_ports:
        extra = [f"{INDENT},input {'' if width == 1 else f'[{width-1}:0] '}{name}"
                 for name, width in job.auto_ports]
        blocks.append(("extra", "//E", extra))
    for tag, marker, block in blocks:
        index = _find_anchor(lines, marker, job.file.name)
        lines[index + 1:index + 1] = [f"{INDENT}{BEGIN_FMT.format(tag=tag)}",
                                     *block, f"{INDENT}{END_FMT.format(tag=tag)}"]
    new_text = nl.join(lines) + (nl if text.endswith(("\n", "\r")) else "")
    if dry_run:
        sys.stdout.writelines(difflib.unified_diff(
            text.splitlines(keepends=True), new_text.splitlines(keepends=True),
            fromfile=str(job.file), tofile=f"{job.file} (gen)"))
    else:
        if backup:
            shutil.copy2(job.file, job.file.with_suffix(job.file.suffix + ".bak"))
        job.file.write_text(new_text, encoding="utf-8", newline="")
        log.info("已更新: %s", job.file)
    return True


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("-c", "--config", required=True)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--no-backup", action="store_true")
    parser.add_argument("--only", action="append", default=[])
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--dump-ports", action="store_true")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args(argv)
    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO,
                        format="%(levelname)-5s %(message)s")
    try:
        jobs = build_jobs(load_config(Path(args.config)), set(args.only))
        if args.list:
            for j in jobs:
                s = j.splice
                print(f"{j.file.name} type={j.type} dp={j.dp} wd={j.wd} "
                      f"rf={j.rf_module}[{j.rf_size}] mode={j.mode} n_d={s.n_d} n_w={s.n_w}")
            return 0
        if args.dump_ports:
            for j in jobs:
                print(f"\n{j.file.name}")
                for title, mod in (("RF", j.rf), ("wrapper", j.wrapper)):
                    print(f"  {title} ({mod.name}):")
                    for p in mod.ports.values():
                        print(f"    {p.name:10s} {p.direction:6s} width={p.width} {p.raw_range or '-'}")
            return 0
        checks = check_jobs(jobs)
        for warning in checks.warnings:
            log.warning(warning)
        for error in checks.errors:
            log.error(error)
        if checks.errors:
            return 2
        changed = sum(process_file(j, args.dry_run, not args.no_backup) for j in jobs)
        log.info("完成：%d 个文件%s", changed, "（dry-run）" if args.dry_run else "")
        return 0
    except (GenError, OSError, yaml.YAMLError) as error:
        log.error("%s", error)
        return 1


if __name__ == "__main__":
    sys.exit(main())
