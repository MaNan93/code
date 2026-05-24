#!/usr/bin/env python3
"""xreg.py — RALF register description to structured output converter.

Sections:
  1. RALF Parser   — tokenise and parse .ralf source into an internal dict
  2. Transformers  — derive table rows and formatted values from parsed data
  3. Writers       — serialise data as JSON / YAML / CSV / XLS
  4. CLI           — argument parsing and entry point

Output rules:
  --json   [FILE]         full JSON;  no FILE → stdout
  --yaml   [FILE]         full YAML;  no FILE → stdout
  --yaml-simple [FILE]    compact YAML; no FILE → stdout
  --csv    [FILE]         register table CSV; no FILE → <cwd>/<stem>.csv
  --excel  [FILE]         register table XLS; no FILE → <cwd>/<stem>.xls  (default)
  (no flags)              same as --excel with default filename
"""

import argparse
import csv
import json
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

# ──────────────────────────────────────────────────────────────────────────────
# 1.  RALF PARSER
# ──────────────────────────────────────────────────────────────────────────────

_BLOCK_OPEN         = re.compile(r"^block\s+(\w+)\s*\{\s*$")
_REGISTER_OPEN      = re.compile(r"^register\s+(\w+)\s*@\s*([^\s\{;]+)\s*\{\s*$")
_FIELD_OPEN         = re.compile(r"^field\s+(\w+)(?:\s*\(([^)]+)\))?\s*@\s*([^\s\{;]+)\s*\{\s*$")
_SYSTEM_OPEN        = re.compile(r"^system\s+(\w+)\s*\{\s*$")
_BLOCK_INST_PATH    = re.compile(r"^block\s+(\w+)\s*\(([^)]+)\)\s*@\s*([^;]+)\s*;\s*$")
_BLOCK_INST_SIMPLE  = re.compile(r"^block\s+(\w+)\s*@\s*([^;]+)\s*;\s*$")
_ENDIAN             = re.compile(r"^endian\s+(\w+)\s*;\s*$")
_BYTES              = re.compile(r"^bytes\s+([^;]+)\s*;\s*$")
_BITS               = re.compile(r"^bits\s+([^;]+)\s*;\s*$")
_ACCESS             = re.compile(r"^access\s+(\w+)\s*;\s*$")
_RESET              = re.compile(r"^reset\s+([^;]+)\s*;\s*$")
_VOLATILE           = re.compile(r"^(volatile|voilatile)(?:\s+([^;；]+))?\s*[;；]\s*$", re.IGNORECASE)
_ATTRIBUTES         = re.compile(r"^attributes\b.*$", re.IGNORECASE)


class _Ctx:
    def __init__(self, kind: str, node: Dict[str, Any]) -> None:
        self.kind = kind
        self.node = node


def _strip_comments(line: str) -> str:
    for marker in ("//", "#"):
        idx = line.find(marker)
        if idx != -1:
            line = line[:idx]
    return line.strip()


def _parse_int(token: str) -> Optional[int]:
    """Parse integer literals: 5, 0x10, 'h0, 16'h16c3, 'd10, 8'b1010."""
    text = token.strip().lower().replace("_", "")
    if not text:
        return None
    if text.startswith("0x"):
        try:
            return int(text, 16)
        except ValueError:
            return None
    if text.isdigit():
        return int(text, 10)
    m = re.match(r"^(?:\d+)?'([hdb])([0-9a-fxz]+)$", text)
    if not m:
        return None
    base_ch, digits = m.groups()
    if "x" in digits or "z" in digits:
        return None
    try:
        return int(digits, {"h": 16, "d": 10, "b": 2}[base_ch])
    except ValueError:
        return None


def parse_ralf(content: str) -> Dict[str, Any]:
    """Parse RALF source text and return structured dict."""
    root: Dict[str, Any] = {"blocks": [], "systems": []}
    stack: List[_Ctx] = []

    for line_no, raw in enumerate(content.splitlines(), start=1):
        line = _strip_comments(raw)
        if not line:
            continue

        # ── closing brace ──────────────────────────────────────────────────
        if line in ("}", "};"):
            if not stack:
                raise ValueError(f"Line {line_no}: unexpected }}")
            stack.pop()
            continue

        # ── ignored lines ──────────────────────────────────────────────────
        if _ATTRIBUTES.match(line):
            continue

        # ── block definition ───────────────────────────────────────────────
        m = _BLOCK_OPEN.match(line)
        if m:
            if stack and stack[-1].kind == "system":
                raise ValueError(f"Line {line_no}: block definition inside system")
            node: Dict[str, Any] = {"name": m.group(1), "registers": []}
            root["blocks"].append(node)
            stack.append(_Ctx("block", node))
            continue

        # ── system definition ──────────────────────────────────────────────
        m = _SYSTEM_OPEN.match(line)
        if m:
            if stack:
                raise ValueError(f"Line {line_no}: system cannot be nested")
            node = {"name": m.group(1), "block_instances": []}
            root["systems"].append(node)
            stack.append(_Ctx("system", node))
            continue

        # ── register ───────────────────────────────────────────────────────
        m = _REGISTER_OPEN.match(line)
        if m:
            if not stack or stack[-1].kind != "block":
                raise ValueError(f"Line {line_no}: register must be inside block")
            name, off_raw = m.groups()
            node = {"name": name, "offset": {"raw": off_raw, "value": _parse_int(off_raw)}, "fields": []}
            stack[-1].node["registers"].append(node)
            stack.append(_Ctx("register", node))
            continue

        # ── field ──────────────────────────────────────────────────────────
        m = _FIELD_OPEN.match(line)
        if m:
            if not stack or stack[-1].kind != "register":
                raise ValueError(f"Line {line_no}: field must be inside register")
            name, alias, lsb_raw = m.groups()
            node = {"name": name, "alias": alias,
                    "lsb": {"raw": lsb_raw, "value": _parse_int(lsb_raw)}}
            stack[-1].node["fields"].append(node)
            stack.append(_Ctx("field", node))
            continue

        # ── block instance with path ───────────────────────────────────────
        m = _BLOCK_INST_PATH.match(line)
        if m:
            if not stack or stack[-1].kind != "system":
                raise ValueError(f"Line {line_no}: block instance must be inside system")
            bname, path, off_raw = m.groups()
            stack[-1].node["block_instances"].append(
                {"block": bname, "path": path,
                 "offset": {"raw": off_raw, "value": _parse_int(off_raw)}}
            )
            continue

        # ── block instance without path ────────────────────────────────────
        m = _BLOCK_INST_SIMPLE.match(line)
        if m:
            if not stack or stack[-1].kind != "system":
                raise ValueError(f"Line {line_no}: block instance must be inside system")
            bname, off_raw = m.groups()
            stack[-1].node["block_instances"].append(
                {"block": bname, "path": None,
                 "offset": {"raw": off_raw, "value": _parse_int(off_raw)}}
            )
            continue

        # ── scalar properties ──────────────────────────────────────────────
        m = _ENDIAN.match(line)
        if m:
            if not stack or stack[-1].kind != "block":
                raise ValueError(f"Line {line_no}: endian must be inside block")
            stack[-1].node["endian"] = m.group(1)
            continue

        m = _BYTES.match(line)
        if m:
            if not stack or stack[-1].kind not in {"block", "system"}:
                raise ValueError(f"Line {line_no}: bytes must be inside block/system")
            raw_val = m.group(1)
            stack[-1].node["bytes"] = {"raw": raw_val, "value": _parse_int(raw_val)}
            continue

        m = _BITS.match(line)
        if m:
            if not stack or stack[-1].kind != "field":
                raise ValueError(f"Line {line_no}: bits must be inside field")
            raw_val = m.group(1)
            stack[-1].node["bits"] = {"raw": raw_val, "value": _parse_int(raw_val)}
            continue

        m = _ACCESS.match(line)
        if m:
            if not stack or stack[-1].kind != "field":
                raise ValueError(f"Line {line_no}: access must be inside field")
            stack[-1].node["access"] = m.group(1)
            continue

        m = _RESET.match(line)
        if m:
            if not stack or stack[-1].kind != "field":
                raise ValueError(f"Line {line_no}: reset must be inside field")
            raw_val = m.group(1)
            stack[-1].node["reset"] = {"raw": raw_val, "value": _parse_int(raw_val)}
            continue

        m = _VOLATILE.match(line)
        if m:
            if not stack or stack[-1].kind != "field":
                raise ValueError(f"Line {line_no}: volatile must be inside field")
            raw_val = m.group(2)
            if raw_val is None:
                stack[-1].node["volatile"] = True
            else:
                norm = raw_val.strip().lower()
                if norm in {"1", "true", "yes", "on"}:
                    vval = True  # type: Any
                elif norm in {"0", "false", "no", "off"}:
                    vval = False
                else:
                    vval = raw_val.strip()
                stack[-1].node["volatile"] = {"raw": raw_val.strip(), "value": vval}
            continue

        raise ValueError(f"Line {line_no}: unsupported syntax: {raw.strip()!r}")

    if stack:
        raise ValueError(f"Unclosed scopes: {', '.join(c.kind for c in stack)}")

    return root


# ──────────────────────────────────────────────────────────────────────────────
# 2.  TRANSFORMERS
# ──────────────────────────────────────────────────────────────────────────────

def _fmt_bit(lsb: Optional[int], width: Optional[int]) -> str:
    if lsb is None or width is None:
        return ""
    return f"[{lsb}]" if width <= 1 else f"[{lsb + width - 1}:{lsb}]"


def _fmt_reset(reset_node: Any, width: Optional[int]) -> str:
    """Format reset value as {width}'h{hex_value}, masked to field width."""
    if width is None or width <= 0:
        return "0"
    value = 0
    if isinstance(reset_node, dict):
        parsed = reset_node.get("value")
        if isinstance(parsed, int):
            value = parsed
        else:
            raw = reset_node.get("raw")
            if isinstance(raw, str):
                p = _parse_int(raw)
                if isinstance(p, int):
                    value = p
    value &= (1 << width) - 1
    return f"{width}'h{value:x}"


def _fmt_volatile(volatile_node: Any) -> str:
    if volatile_node is None:
        return "0"
    if isinstance(volatile_node, bool):
        return "1" if volatile_node else "0"
    if isinstance(volatile_node, dict):
        raw = volatile_node.get("raw")
        if raw is not None:
            return str(raw)
        val = volatile_node.get("value")
        if isinstance(val, bool):
            return "1" if val else "0"
        if val is not None:
            return str(val)
    return str(volatile_node)


def build_table_rows(data: Dict[str, Any]) -> List[Dict[str, str]]:
    """Build register table rows sorted by absolute address."""
    rows: List[Dict[str, str]] = []

    for block in data.get("blocks", []):
        block_name = str(block.get("name", ""))

        # Collect all system-level base addresses for this block.
        block_bases: List[int] = []
        for system in data.get("systems", []):
            for inst in system.get("block_instances", []):
                if inst.get("block") == block_name:
                    ov = (inst.get("offset") or {}).get("value")
                    if isinstance(ov, int):
                        block_bases.append(ov)

        for reg in block.get("registers", []):
            reg_name  = str(reg.get("name", ""))
            reg_off_v = (reg.get("offset") or {}).get("value")

            addr_items: List[Tuple[str, int]] = []
            if isinstance(reg_off_v, int) and block_bases:
                for base in block_bases:
                    abs_v = base + reg_off_v
                    addr_items.append((f"0x{abs_v:X}", abs_v))
            else:
                addr_items.append(("", 1 << 60))

            for field in reg.get("fields", []):
                lsb   = (field.get("lsb")  or {}).get("value")
                width = (field.get("bits") or {}).get("value")
                lsb_i   = lsb   if isinstance(lsb,   int) else None
                width_i = width if isinstance(width, int) else None

                for addr_text, addr_sort in addr_items:
                    rows.append({
                        "Addr":          addr_text,
                        "Type":          str(field.get("access", "")) or "field",
                        "Field name":    reg_name,
                        "Register Name": str(field.get("name", "")),
                        "Bit":           _fmt_bit(lsb_i, width_i),
                        "Default":       _fmt_reset(field.get("reset"), width_i),
                        "Description":   "",
                        "Status":        _fmt_volatile(field.get("volatile")),
                        # Internal sort keys (stripped before writing)
                        "__addr_sort":   str(addr_sort),
                        "__lsb_sort":    str(lsb_i if lsb_i is not None else 1 << 30),
                    })

    rows.sort(key=lambda r: (
        int(r["__addr_sort"]),
        r["Field name"],
        int(r["__lsb_sort"]),
        r["Register Name"],
    ))
    return rows


# ──────────────────────────────────────────────────────────────────────────────
# 3.  WRITERS
# ──────────────────────────────────────────────────────────────────────────────

_TABLE_HEADERS = [
    "Addr", "Type", "Field name", "Register Name",
    "Bit", "Default", "Description", "Status",
]


# ── JSON ──────────────────────────────────────────────────────────────────────

def render_json(data: Dict[str, Any], indent: int = 2) -> str:
    return json.dumps(data, ensure_ascii=False, indent=indent)


def write_json(data: Dict[str, Any], path: Path, indent: int = 2) -> None:
    path.write_text(render_json(data, indent) + "\n", encoding="utf-8")


# ── YAML ──────────────────────────────────────────────────────────────────────

def _yaml_scalar(value: Any) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    text = str(value)
    if not text:
        return "''"
    return "'" + text.replace("'", "''") + "'"


def _to_yaml_lines(value: Any, indent: int = 0) -> List[str]:
    sp = " " * indent
    if isinstance(value, dict):
        if not value:
            return [sp + "{}"]
        lines: List[str] = []
        for k, v in value.items():
            if isinstance(v, (dict, list)):
                lines.append(f"{sp}{k}:")
                lines.extend(_to_yaml_lines(v, indent + 2))
            else:
                lines.append(f"{sp}{k}: {_yaml_scalar(v)}")
        return lines
    if isinstance(value, list):
        if not value:
            return [sp + "[]"]
        lines = []
        for item in value:
            if isinstance(item, (dict, list)):
                child = _to_yaml_lines(item, indent + 2)
                if child:
                    lines.append(f"{sp}- {child[0].lstrip()}")
                    lines.extend(child[1:])
                else:
                    lines.append(f"{sp}- {{}}")
            else:
                lines.append(f"{sp}- {_yaml_scalar(item)}")
        return lines
    return [sp + _yaml_scalar(value)]


def render_yaml(data: Dict[str, Any]) -> str:
    return "\n".join(_to_yaml_lines(data)) + "\n"


def write_yaml(data: Dict[str, Any], path: Path) -> None:
    path.write_text(render_yaml(data), encoding="utf-8")


# ── YAML-SIMPLE ───────────────────────────────────────────────────────────────

def render_yaml_simple(data: Dict[str, Any]) -> str:
    lines: List[str] = []
    for block in data.get("blocks", []):
        lines.append(f"- block: {_yaml_scalar(block.get('name', ''))}")
        for reg in block.get("registers", []):
            off_raw = (reg.get("offset") or {}).get("raw", "")
            lines.append(f"  - register: {_yaml_scalar(reg.get('name', ''))}")
            lines.append(f"    offset: {_yaml_scalar(off_raw)}")
            lines.append(f"    fields:")
            for field in reg.get("fields", []):
                width = (field.get("bits") or {}).get("value")
                lsb   = (field.get("lsb")  or {}).get("value")
                w_i   = width if isinstance(width, int) else None
                l_i   = lsb   if isinstance(lsb,   int) else None
                lines.append(f"      - name: {_yaml_scalar(field.get('name', ''))}")
                if field.get("alias"):
                    lines.append(f"        alias: {_yaml_scalar(field['alias'])}")
                lines.append(f"        bit: {_yaml_scalar(_fmt_bit(l_i, w_i))}")
                lines.append(f"        access: {_yaml_scalar(field.get('access', ''))}")
                lines.append(f"        reset: {_yaml_scalar(_fmt_reset(field.get('reset'), w_i))}")
                vstatus = _fmt_volatile(field.get("volatile"))
                if vstatus != "0":
                    lines.append(f"        volatile: {_yaml_scalar(vstatus)}")
    return "\n".join(lines) + "\n"


def write_yaml_simple(data: Dict[str, Any], path: Path) -> None:
    path.write_text(render_yaml_simple(data), encoding="utf-8")


# ── CSV ───────────────────────────────────────────────────────────────────────

def write_csv(rows: List[Dict[str, str]], path: Path) -> None:
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=_TABLE_HEADERS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


# ── XLS ───────────────────────────────────────────────────────────────────────

def _xls_merge_runs(rows: List[Dict[str, str]], key: str,
                    extra_key: Optional[str] = None) -> List[Tuple[int, int]]:
    if not rows:
        return []
    runs: List[Tuple[int, int]] = []
    start = 0
    for i in range(1, len(rows) + 1):
        end_of_list = i == len(rows)
        if end_of_list:
            runs.append((start, i - 1))
        else:
            same = rows[i].get(key) == rows[start].get(key)
            if extra_key:
                same = same and (rows[i].get(extra_key) == rows[start].get(extra_key))
            if not same:
                runs.append((start, i - 1))
                start = i
    return runs


def write_xls(rows: List[Dict[str, str]], path: Path) -> None:
    try:
        import xlwt  # type: ignore
    except ImportError as exc:
        raise RuntimeError(
            "xlwt is required for Excel output. Install with: pip install xlwt"
        ) from exc

    wb = xlwt.Workbook()
    ws = wb.add_sheet("Registers")

    hdr_style  = xlwt.easyxf(
        "font: bold on; align: horiz center, vert center; "
        "borders: left thin, right thin, top thin, bottom thin"
    )
    cell_style = xlwt.easyxf(
        "align: horiz left, vert center; "
        "borders: left thin, right thin, top thin, bottom thin"
    )

    col_widths = [12, 10, 16, 20, 12, 14, 24, 10]
    for col, (h, w) in enumerate(zip(_TABLE_HEADERS, col_widths)):
        ws.write(0, col, h, hdr_style)
        ws.col(col).width = 256 * w

    # Write all non-merged columns.
    for i, row in enumerate(rows, start=1):
        for col, key in enumerate(_TABLE_HEADERS):
            if key not in ("Addr", "Field name"):
                ws.write(i, col, row.get(key, ""), cell_style)

    # Merge Addr (col 0) for consecutive rows with the same address.
    for s, e in _xls_merge_runs(rows, "Addr"):
        r1, r2 = s + 1, e + 1
        v = rows[s].get("Addr", "")
        if r1 == r2:
            ws.write(r1, 0, v, cell_style)
        else:
            ws.write_merge(r1, r2, 0, 0, v, cell_style)

    # Merge Field name (col 2) only when Addr AND Field name are the same.
    for s, e in _xls_merge_runs(rows, "Field name", extra_key="Addr"):
        r1, r2 = s + 1, e + 1
        v = rows[s].get("Field name", "")
        if r1 == r2:
            ws.write(r1, 2, v, cell_style)
        else:
            ws.write_merge(r1, r2, 2, 2, v, cell_style)

    wb.save(str(path))


# ──────────────────────────────────────────────────────────────────────────────
# 4.  CLI
# ──────────────────────────────────────────────────────────────────────────────

def _default_path(input_path: Path, suffix: str) -> Path:
    return Path.cwd() / (input_path.stem + suffix)


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("input", type=Path, help="Input .ralf file")

    # nargs='?' means:
    #   not present  → None (format not requested)
    #   present, no value → const  (use default path / stdout)
    #   present with value → the given path
    parser.add_argument(
        "--json", nargs="?", const="", metavar="FILE", dest="json_out",
        help="Output full JSON; omit FILE to print to stdout",
    )
    parser.add_argument(
        "--yaml", nargs="?", const="", metavar="FILE", dest="yaml_out",
        help="Output full YAML; omit FILE to print to stdout",
    )
    parser.add_argument(
        "--yaml-simple", nargs="?", const="", metavar="FILE", dest="yaml_simple_out",
        help="Output compact YAML; omit FILE to print to stdout",
    )
    parser.add_argument(
        "--csv", nargs="?", const="", metavar="FILE", dest="csv_out",
        help="Output register table CSV; omit FILE for <stem>.csv",
    )
    parser.add_argument(
        "--excel", nargs="?", const="", metavar="FILE", dest="excel_out",
        help="Output register table XLS; omit FILE for <stem>.xls  [default]",
    )
    parser.add_argument(
        "--indent", type=int, default=2, metavar="N",
        help="JSON indent spaces (default: 2)",
    )
    args = parser.parse_args()

    # If no output flag is given at all, default to excel.
    any_requested = any(
        v is not None for v in
        [args.json_out, args.yaml_out, args.yaml_simple_out, args.csv_out, args.excel_out]
    )
    if not any_requested:
        args.excel_out = ""  # trigger default-path logic below

    inp: Path = args.input
    content = inp.read_text(encoding="utf-8")
    data = parse_ralf(content)

    # ── text outputs (stdout when no FILE given) ──────────────────────────
    if args.json_out is not None:
        text = render_json(data, args.indent)
        if args.json_out == "":
            print(text)
        else:
            Path(args.json_out).write_text(text + "\n", encoding="utf-8")

    if args.yaml_out is not None:
        text = render_yaml(data)
        if args.yaml_out == "":
            print(text, end="")
        else:
            Path(args.yaml_out).write_text(text, encoding="utf-8")

    if args.yaml_simple_out is not None:
        text = render_yaml_simple(data)
        if args.yaml_simple_out == "":
            print(text, end="")
        else:
            Path(args.yaml_simple_out).write_text(text, encoding="utf-8")

    # ── table outputs (default filename when no FILE given) ───────────────
    if args.csv_out is not None or args.excel_out is not None:
        rows = build_table_rows(data)

    if args.csv_out is not None:
        dest = Path(args.csv_out) if args.csv_out else _default_path(inp, ".csv")
        write_csv(rows, dest)

    if args.excel_out is not None:
        dest = Path(args.excel_out) if args.excel_out else _default_path(inp, ".xls")
        write_xls(rows, dest)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
