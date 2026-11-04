#!/usr/bin/env python3
"""Extract selected SystemVerilog/Verilog `define macro values."""

import argparse
import ast
import operator
import re
import sys
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Set, Tuple

TARGET_MACROS: Tuple[str, ...] = (
    "CC_SLV_NUM_OUTSTND_WR_REQ",
    "CC_MAX_SLV_TAG",
    "WR_CH_P_REQ_QUEUE_DP",
    "CC_MAX_MSTR_TAGS_AXI",
    "AXI_MSTR_CLK_FREQ",
    "AXI_SLV_CLK_FREQ",
    "DBI_SLV_CLK_FREQ",
    "CC_MSTR_BUS_ID_WIDTH",
    "CC_SLV_BUS_ID_WIDTH",
    "CC_DBI_SLV_ID_WD",
    "CC_MSTR_BUS_ADDR_WIDTH",
    "SLAVE_BUS_ADDR_WIDTH",
    "CC_DBI_SLV_BUS_ADDR_WIDTH",
    "CC_MSTR_BUS_DATA_WIDTH",
    "SLAVE_BUS_DATA_WIDTH",
    "CC_DBI_SLV_BUS_DATA_WIDTH",
    "CC_MSTR_BURST_LEN",
    "CC_SLV_BURST_LEN",
    "CC_DBI_BURST_LEN",
    "CX_MAX_PCIE_SPEED",
    "CX_NL",
)

DEFAULT_GLOBS: Tuple[str, ...] = (
    "**/*.v",
    "**/*.vh",
    "**/*.sv",
    "**/*.svh",
    "**/*.h",
    "**/*.inc",
)

DEFAULT_TARGET_FILE_PATTERN = "*cc_constants.svh"

DEFINE_RE = re.compile(r"^\s*`define\s+([A-Za-z_][A-Za-z0-9_]*)\b(.*)$")

PCIE_GEN_RATE_GBPS: Dict[int, float] = {
    1: 2.5,
    2: 5.0,
    3: 8.0,
    4: 16.0,
    5: 32.0,
    6: 64.0,
    7: 128.0,
}


def resolve_target_macro_name(name: str, target_set: Set[str]) -> Optional[str]:
    """Resolve actual macro name to one target name.

    Supports exact names and prefixed names like PREFIX_<TARGET>.
    """
    if name in target_set:
        return name

    for target in target_set:
        if name.endswith("_" + target):
            return target

    return None


_VERILOG_LITERAL_RE = re.compile(r"(?<![\\w'])\\d*'[sS]?([dDhHbBoO])([0-9a-fA-F_xXzZ?_]+)")
_MACRO_REF_RE = re.compile(r"`([A-Za-z_][A-Za-z0-9_]*)")
_BINARY_OPS = {
    ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul,
    ast.FloorDiv: operator.floordiv, ast.Mod: operator.mod,
    ast.LShift: operator.lshift, ast.RShift: operator.rshift,
    ast.BitAnd: operator.and_, ast.BitOr: operator.or_, ast.BitXor: operator.xor,
}
_UNARY_OPS = {ast.UAdd: operator.pos, ast.USub: operator.neg, ast.Invert: operator.invert}


def parse_numeric_value(
    raw_value: Optional[str],
    macros: Optional[Dict[str, str]] = None,
    _stack: Optional[Set[str]] = None,
) -> Optional[int]:
    """Evaluate a constant integer expression without executing arbitrary Python code.

    Supports macro references, Verilog integer literals and common arithmetic
    operators. Undefined/cyclic macros and unsupported expressions return None.
    """
    if raw_value is None:
        return None
    expr = raw_value.strip()
    if not expr:
        return None

    def _literal(match: re.Match[str]) -> str:
        digits = match.group(2).replace("_", "")
        if re.search(r"[xXzZ?]", digits):
            raise ValueError("Unknown Verilog literal")
        base = {"d": 10, "h": 16, "b": 2, "o": 8}[match.group(1).lower()]
        return str(int(digits, base))

    try:
        expr = _VERILOG_LITERAL_RE.sub(_literal, expr)
        expr = _MACRO_REF_RE.sub(lambda m: m.group(1), expr)
        # Verilog integer division truncates toward zero.
        expr = re.sub(r"(?<!/)/(?!/)", "//", expr)
        tree = ast.parse(expr, mode="eval")
        active = set() if _stack is None else _stack

        def _eval(node: ast.AST) -> int:
            if isinstance(node, ast.Constant) and type(node.value) is int:
                return node.value
            if isinstance(node, ast.Name):
                if macros is None or node.id not in macros or node.id in active:
                    raise ValueError("Undefined or recursive macro")
                value = parse_numeric_value(macros[node.id], macros, active | {node.id})
                if value is None:
                    raise ValueError("Unresolved macro")
                return value
            if isinstance(node, ast.UnaryOp) and type(node.op) in _UNARY_OPS:
                return _UNARY_OPS[type(node.op)](_eval(node.operand))
            if isinstance(node, ast.BinOp) and type(node.op) in _BINARY_OPS:
                left, right = _eval(node.left), _eval(node.right)
                if type(node.op) in (ast.LShift, ast.RShift) and not (0 <= right <= 4096):
                    raise ValueError("Invalid shift")
                if type(node.op) is ast.FloorDiv:
                    if right == 0:
                        raise ValueError("Division by zero")
                    return (abs(left) // abs(right)) * (-1 if (left < 0) != (right < 0) else 1)
                return _BINARY_OPS[type(node.op)](left, right)
            raise ValueError("Unsupported expression")

        return _eval(tree.body)
    except (SyntaxError, ValueError, TypeError, OverflowError, ZeroDivisionError, RecursionError):
        return None


def build_analysis(ordered: Dict[str, Optional[str]]) -> Dict[str, Any]:
    """Build interpreted interface information from extracted macro values."""
    def _bandwidth_gbps(clk_key: str, data_key: str) -> Optional[float]:
        clk = parse_numeric_value(ordered.get(clk_key))
        data_width = parse_numeric_value(ordered.get(data_key))
        if clk is None or data_width is None:
            return None
        return clk * data_width / 1000.0

    mstr_read_os = parse_numeric_value(ordered.get("CC_MAX_MSTR_TAGS_AXI"))
    slv_read_os = parse_numeric_value(ordered.get("CC_MAX_SLV_TAG"))

    axi_mstr = {
        "clk_freq": ordered.get("AXI_MSTR_CLK_FREQ"),
        "clk_unit": "MHz",
        "id_width": ordered.get("CC_MSTR_BUS_ID_WIDTH"),
        "addr_width": ordered.get("CC_MSTR_BUS_ADDR_WIDTH"),
        "data_width": ordered.get("CC_MSTR_BUS_DATA_WIDTH"),
        "bandwidth_Gbps": _bandwidth_gbps("AXI_MSTR_CLK_FREQ", "CC_MSTR_BUS_DATA_WIDTH"),
        "write_outstanding": None,  # Posted queue depth is not AXI write outstanding.
        "posted_request_queue_depth": parse_numeric_value(ordered.get("WR_CH_P_REQ_QUEUE_DP")),
        "read_outstanding": mstr_read_os,
    }
    axi_slv = {
        "clk_freq": ordered.get("AXI_SLV_CLK_FREQ"),
        "clk_unit": "MHz",
        "id_width": ordered.get("CC_SLV_BUS_ID_WIDTH"),
        "addr_width": ordered.get("SLAVE_BUS_ADDR_WIDTH"),
        "data_width": ordered.get("SLAVE_BUS_DATA_WIDTH"),
        "bandwidth_Gbps": _bandwidth_gbps("AXI_SLV_CLK_FREQ", "SLAVE_BUS_DATA_WIDTH"),
        "write_outstanding": parse_numeric_value(ordered.get("CC_SLV_NUM_OUTSTND_WR_REQ")),
        "read_outstanding": slv_read_os,
    }
    axi_dbi = {
        "clk_freq": ordered.get("DBI_SLV_CLK_FREQ"),
        "clk_unit": "MHz",
        "id_width": ordered.get("CC_DBI_SLV_ID_WD"),
        "addr_width": ordered.get("CC_DBI_SLV_BUS_ADDR_WIDTH"),
        "data_width": ordered.get("CC_DBI_SLV_BUS_DATA_WIDTH"),
        "bandwidth_Gbps": _bandwidth_gbps("DBI_SLV_CLK_FREQ", "CC_DBI_SLV_BUS_DATA_WIDTH"),
        "write_outstanding": 0,
        "read_outstanding": 0,
    }

    gen = parse_numeric_value(ordered.get("CX_MAX_PCIE_SPEED"))
    link_width = parse_numeric_value(ordered.get("CX_NL"))
    per_lane = PCIE_GEN_RATE_GBPS.get(gen) if gen is not None else None
    total = (per_lane * link_width) if (per_lane is not None and link_width is not None) else None

    pcie = {
        "gen": gen,
        "link_width": link_width,
        "per_lane_gbps": per_lane,
        "total_gbps": total,
    }

    return {
        "axi_mstr": axi_mstr,
        "axi_slv": axi_slv,
        "axi_dbi": axi_dbi,
        "pcie": pcie,
    }


def print_analysis(analysis: Dict[str, Any]) -> None:
    """Print interpreted interface summary in plain text."""
    axi_mstr = analysis["axi_mstr"]
    axi_slv = analysis["axi_slv"]
    axi_dbi = analysis["axi_dbi"]
    pcie = analysis["pcie"]

    def _fmt(val: Any) -> str:
        return "N/A" if val is None else str(val)

    headers = (
        "IFACE",
        "CLK(MHz)",
        "ID_WD",
        "ADDR_WD",
        "DATA_WD",
        "BW(Gbps)",
        "WR-Outstanding",
        "RD-Outstanding",
    )
    rows = [
        (
            "AXI_MSTR",
            _fmt(axi_mstr["clk_freq"]),
            _fmt(axi_mstr["id_width"]),
            _fmt(axi_mstr["addr_width"]),
            _fmt(axi_mstr["data_width"]),
            _fmt(axi_mstr["bandwidth_Gbps"]),
            _fmt(axi_mstr["write_outstanding"]),
            _fmt(axi_mstr["read_outstanding"]),
        ),
        (
            "AXI_SLV",
            _fmt(axi_slv["clk_freq"]),
            _fmt(axi_slv["id_width"]),
            _fmt(axi_slv["addr_width"]),
            _fmt(axi_slv["data_width"]),
            _fmt(axi_slv["bandwidth_Gbps"]),
            _fmt(axi_slv["write_outstanding"]),
            _fmt(axi_slv["read_outstanding"]),
        ),
        (
            "AXI_DBI",
            _fmt(axi_dbi["clk_freq"]),
            _fmt(axi_dbi["id_width"]),
            _fmt(axi_dbi["addr_width"]),
            _fmt(axi_dbi["data_width"]),
            _fmt(axi_dbi["bandwidth_Gbps"]),
            _fmt(axi_dbi["write_outstanding"]),
            _fmt(axi_dbi["read_outstanding"]),
        ),
    ]

    widths = [len(h) for h in headers]
    for row in rows:
        for idx, cell in enumerate(row):
            widths[idx] = max(widths[idx], len(cell))

    def _line(items: Tuple[str, ...]) -> str:
        return " | ".join(item.ljust(widths[i]) for i, item in enumerate(items))

    sep = "-+-".join("-" * w for w in widths)

    print("\n[INTERFACE_SUMMARY]")
    print(_line(headers))
    print(sep)
    for row in rows:
        print(_line(row))

    print(f"AXI_MSTR posted request queue depth: {_fmt(axi_mstr[\'posted_request_queue_depth\'])}")

    gen = pcie["gen"]
    link_width = pcie["link_width"]
    per_lane = pcie["per_lane_gbps"]
    total = pcie["total_gbps"]
    print(
        "PCIE    : "
        f"gen={gen}, link_width={link_width}, per_lane_gbps={per_lane}, total_gbps={total}"
    )


def discover_files(paths: Iterable[Path], globs: Iterable[str]) -> List[Path]:
    """Collect candidate files from files/directories passed by user."""
    result: List[Path] = []
    seen = set()

    for path in paths:
        if path.is_file():
            resolved = path.resolve()
            if resolved not in seen:
                seen.add(resolved)
                result.append(path)
            continue

        if path.is_dir():
            for pattern in globs:
                for f in path.glob(pattern):
                    if f.is_file():
                        resolved = f.resolve()
                        if resolved not in seen:
                            seen.add(resolved)
                            result.append(f)

    return result


def discover_target_files(paths: Iterable[Path], pattern: str) -> List[Path]:
    """Find files whose basename matches pattern under input files/directories."""
    result: List[Path] = []
    seen = set()

    for path in paths:
        if path.is_file():
            if path.match(pattern):
                resolved = path.resolve()
                if resolved not in seen:
                    seen.add(resolved)
                    result.append(path)
            continue

        if path.is_dir():
            for f in path.rglob(pattern):
                if f.is_file():
                    resolved = f.resolve()
                    if resolved not in seen:
                        seen.add(resolved)
                        result.append(f)

    return result


def parse_defines(file_path: Path) -> Dict[str, Tuple[str, int, str]]:
    """Parse `define lines in a single file and return name -> (value, line_no, line_text)."""
    found: Dict[str, Tuple[str, int, str]] = {}

    try:
        text = file_path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return found

    lines = text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        origin_line_no = i + 1
        origin_line_text = line.rstrip("\n")
        match = DEFINE_RE.match(line)
        if not match:
            i += 1
            continue

        name = match.group(1)
        rest = match.group(2).rstrip()

        # Merge line continuations ended by backslash.
        while rest.endswith("\\") and i + 1 < len(lines):
            rest = rest[:-1].rstrip() + " " + lines[i + 1].strip()
            i += 1

        # Function-like macros have no whitespace before their opening parenthesis.
        if rest.startswith("("):
            i += 1
            continue

        # Remove inline // comments for simpler output.
        value = rest
        if "//" in value:
            value = value.split("//", 1)[0]
        value = value.strip()

        # Macro without explicit value is treated as 1.
        found[name] = (value if value else "1", origin_line_no, origin_line_text)
        i += 1

    return found


def extract_target_macros(
    files: Iterable[Path],
) -> Tuple[Dict[str, str], Dict[str, str], Dict[str, int], Dict[str, str]]:
    """Return macro values and debug information for requested macros."""
    values: Dict[str, str] = {}
    sources: Dict[str, str] = {}
    source_lines: Dict[str, int] = {}
    source_text: Dict[str, str] = {}
    target_set = set(TARGET_MACROS)

    all_defines: Dict[str, str] = {}
    file_defines = []
    for file_path in files:
        defines = parse_defines(file_path)
        all_defines.update({name: item[0] for name, item in defines.items()})
        file_defines.append((file_path, defines))

    for file_path, defines in file_defines:
        for macro, (value, line_no, line_text) in defines.items():
            target_macro = resolve_target_macro_name(macro, target_set)
            if target_macro is None:
                continue

            # Keep exact match if it already exists.
            if target_macro in values and macro != target_macro:
                continue

            numeric = parse_numeric_value(value, all_defines, {macro})
            values[target_macro] = str(numeric) if numeric is not None else value
            sources[target_macro] = str(file_path)
            source_lines[target_macro] = line_no
            source_text[target_macro] = line_text

    return values, sources, source_lines, source_text


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Extract selected `define macro values from HDL files."
    )
    parser.add_argument(
        "--file",
        nargs="+",
        default=None,
        help=(
            "Explicit files/directories to read. If omitted, auto-discover exactly one "
            f"{DEFAULT_TARGET_FILE_PATTERN} under current directory."
        ),
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Show source file, line number and matched define line for each macro.",
    )
    return parser


def _collect_macro_data(
    file_inputs: Optional[Iterable[str]] = None,
) -> Tuple[Dict[str, Optional[str]], Dict[str, str], Dict[str, int], Dict[str, str]]:
    """Collect extracted macro data without printing."""
    if file_inputs:
        files = discover_target_files([Path(p) for p in file_inputs], "*")
    else:
        files = discover_target_files([Path(".")], DEFAULT_TARGET_FILE_PATTERN)
        if len(files) > 1:
            raise ValueError(
                "Multiple matched files found. Use --file to specify exactly one input."
            )

    if not files:
        if file_inputs:
            raise FileNotFoundError(
                "No input files found from --file. "
                "Please check the provided file/directory path."
            )
        raise FileNotFoundError(
            "No file matched {} in current directory.".format(DEFAULT_TARGET_FILE_PATTERN)
        )

    values, sources, source_lines, source_text = extract_target_macros(files)
    ordered = {macro: values.get(macro) for macro in TARGET_MACROS}
    return ordered, sources, source_lines, source_text


def getaxiinfo(
    file_inputs: Optional[Iterable[str]] = None,
    debug: bool = False,
) -> Dict[str, Optional[str]]:
    """Extract TARGET_MACROS values for API callers.

    Parameters:
        file_inputs:
            Explicit files/directories to read. If None, auto-discover exactly one
            DEFAULT_TARGET_FILE_PATTERN file under current directory.
        debug:
            Kept for backward compatibility. API path does not print logs.

    Returns:
        Dict[str, Optional[str]]: Macro name to extracted value (or None if not found).
    """
    ordered, _sources, _source_lines, _source_text = _collect_macro_data(file_inputs)
    _ = debug  # Keep signature stable for existing callers.
    return ordered


def _print_cli_output(
    ordered: Dict[str, Optional[str]],
    sources: Dict[str, str],
    source_lines: Dict[str, int],
    source_text: Dict[str, str],
    debug: bool,
) -> int:
    """Print CLI logs and summary from extracted macro data."""
    missing = [m for m, v in ordered.items() if v is None]
    analysis = build_analysis(ordered)

    for macro in TARGET_MACROS:
        value = ordered[macro]
        if value is None:
            print(f"{macro} = <NOT_FOUND>")
            continue

        if debug:
            src = sources.get(macro, "unknown")
            line_no = source_lines.get(macro)
            line_text = source_text.get(macro, "")
            print(f"{macro} = {value}    # {src}:{line_no}")
            print(f"  line: {line_text}")
        else:
            print(f"{macro} = {value}")

    print_analysis(analysis)
    if missing:
        print("Missing macros: " + ", ".join(missing))

    return 0


def getaxiinfo_cli(argv: Optional[List[str]] = None) -> int:
    """CLI entry: parse command line arguments and call getaxiinfo API."""
    parser = build_arg_parser()
    args = parser.parse_args(argv)
    try:
        ordered, sources, source_lines, source_text = _collect_macro_data(args.file)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        if not args.file:
            for f in discover_target_files([Path(".")], DEFAULT_TARGET_FILE_PATTERN):
                print("  - {}".format(f), file=sys.stderr)
        return 1
    except FileNotFoundError as exc:
        print(str(exc), file=sys.stderr)
        if not args.file:
            print("Use --file to specify an exact input file.", file=sys.stderr)
        return 1

    return _print_cli_output(
        ordered=ordered,
        sources=sources,
        source_lines=source_lines,
        source_text=source_text,
        debug=args.debug,
    )


if __name__ == "__main__":
    raise SystemExit(getaxiinfo_cli())
