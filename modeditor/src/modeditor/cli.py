#!/usr/bin/env python3
"""Command-line interface for Verilog/SystemVerilog module editing."""


import argparse
import re
from pathlib import Path
from typing import Any, Dict, List, Set, Tuple

from modeditor.utils import (
    ModuleEditor,
    normalize_dimension,
    normalize_width,
    split_csv,
)


# ---------------------------------------------------------------------------
# CLI spec parsers  (translate --flag CSV strings into keyword-argument dicts)
# ---------------------------------------------------------------------------

def looks_like_width_or_dimension(token: str) -> bool:
    token = token.strip()
    if not token:
        return False
    if token.startswith("[") and token.endswith("]"):
        return True
    return ":" in token


def looks_like_name(token: str) -> bool:
    token = token.strip()
    return bool(re.match(r"^`?[A-Za-z_][A-Za-z0-9_$]*$", token))


def parse_add_port_spec(port_csv: str) -> Dict[str, str]:
    parts = split_csv(port_csv)
    if len(parts) < 2:
        raise ValueError("--add-port needs at least 'direction, name'")

    direction = parts[0]
    rest = parts[1:]

    typ = ""
    width = ""
    name = ""
    dimension = ""

    # 常见的 Verilog/SystemVerilog 类型关键词
    common_types = {"wire", "reg", "logic", "bit", "tri", "supply0", "supply1", 
                    "triand", "trior", "trireg", "uwire", "real", "realtime", 
                    "integer", "time", "parameter", "localparam", "signed", "unsigned"}
    
    if len(rest) == 1:
        name = rest[0]
    elif len(rest) == 2:
        if looks_like_width_or_dimension(rest[0]) and looks_like_name(rest[1]):
            width, name = rest[0], rest[1]
        else:
            typ, name = rest[0], rest[1]
    elif len(rest) == 3:
        # 检查是否是 type, width, name 格式
        if rest[0] in common_types and looks_like_width_or_dimension(rest[1]) and looks_like_name(rest[2]):
            typ, width, name = rest[0], rest[1], rest[2]
        # 否则按原来的逻辑判断是否是 width, name, dimension 格式
        elif looks_like_width_or_dimension(rest[0]) and looks_like_name(rest[1]):
            width, name, dimension = rest[0], rest[1], rest[2]
        else:
            typ, width, name = rest[0], rest[1], rest[2]
    else:
        # 尝试判断是否是 type, width, name, dimension 格式
        if (len(rest) >= 3 and rest[0] in common_types and 
            looks_like_width_or_dimension(rest[1]) and looks_like_name(rest[2])):
            typ, width, name = rest[0], rest[1], rest[2]
            dimension = ",".join(rest[3:]).strip()
        # 否则按原来的逻辑
        elif looks_like_width_or_dimension(rest[0]) and looks_like_name(rest[1]):
            width = rest[0]
            name = rest[1]
            dimension = ",".join(rest[2:]).strip()
        else:
            typ, width, name = rest[0], rest[1], rest[2]
            dimension = ",".join(rest[3:]).strip()

    direction = direction.strip().lower()
    if direction not in {"input", "output", "inout", "ref"}:
        raise ValueError("--add-port direction must be input/output/inout/ref")
    if not name.strip():
        raise ValueError("--add-port name is required")

    return {
        "direction": direction,
        "type": typ.strip(),
        "width": normalize_width(width),
        "name": name.strip(),
        "dimension": normalize_dimension(dimension),
    }


def parse_add_wire_spec(wire_csv: str) -> Dict[str, str]:
    parts = split_csv(wire_csv)

    if len(parts) == 1:
        typ, width, name, dimension = "wire", "", parts[0], ""
    elif len(parts) == 2:
        if looks_like_width_or_dimension(parts[0]) and looks_like_name(parts[1]):
            typ, width, name, dimension = "wire", parts[0], parts[1], ""
        else:
            typ, width, name, dimension = parts[0], "", parts[1], ""
    elif len(parts) == 3:
        if looks_like_width_or_dimension(parts[0]) and looks_like_name(parts[1]):
            typ, width, name, dimension = "wire", parts[0], parts[1], parts[2]
        else:
            typ, width, name, dimension = parts[0], parts[1], parts[2], ""
    else:
        if looks_like_width_or_dimension(parts[0]) and looks_like_name(parts[1]):
            typ, width, name = "wire", parts[0], parts[1]
            dimension = ",".join(parts[2:]).strip()
        else:
            typ, width, name = parts[0], parts[1], parts[2]
            dimension = ",".join(parts[3:]).strip()

    typ = typ.strip() or "wire"
    name = name.strip()
    if not name:
        raise ValueError("--add-wire name is required")

    return {
        "type": typ,
        "width": normalize_width(width),
        "name": name,
        "dimension": normalize_dimension(dimension),
    }


def parse_add_inst_port_spec(inst_port_csv: str) -> Dict[str, str]:
    parts = split_csv(inst_port_csv)
    if len(parts) < 2:
        raise ValueError("--add-inst-port needs 'instname, port[, wire]'")

    instname = parts[0].strip()
    port = parts[1].strip()
    wire = parts[2].strip() if len(parts) >= 3 else ""

    if not instname or not port:
        raise ValueError("--add-inst-port needs non-empty instname and port")

    return {"instname": instname, "port": port, "wire": wire}


def parse_rm_inst_port_spec(inst_port_csv: str) -> Dict[str, str]:
    parts = split_csv(inst_port_csv)
    if len(parts) != 2:
        raise ValueError("--rm-inst-port needs 'instname, name'")
    instname = parts[0].strip()
    name = parts[1].strip()
    if not instname or not name:
        raise ValueError("--rm-inst-port needs non-empty instname and name")
    return {"instname": instname, "name": name}


def apply_edit_actions(source_text: str, args: argparse.Namespace) -> Tuple[str, bool]:
    original = source_text
    
    # Extract module text from source file
    module_text, offset_info = ModuleEditor.extract_module_text(source_text, args.module_name)
    
    # Edit module text using ModuleEditor
    editor = ModuleEditor(module_text)

    if args.add_port:
        # 解析端口规格并转换为字典格式
        port_info = parse_add_port_spec(args.add_port)
        port_name = port_info.pop('name')  # 从信息中提取端口名，但保留其他字段
        port_dict = {port_name: port_info}
        editor.add_port(port_dict)
    if args.add_wire:
        # 解析线网规格并转换为字典格式
        wire_info = parse_add_wire_spec(args.add_wire)
        wire_name = wire_info.pop('name')  # 从信息中提取线网名，但保留其他字段
        wire_dict = {wire_name: wire_info}
        editor.add_wire(wire_dict)
    if args.add_inst_port:
        # 解析实例端口规格并转换为字典格式
        inst_port_info = parse_add_inst_port_spec(args.add_inst_port)
        inst_name = inst_port_info.pop('instname')  # 从信息中提取实例名
        port_name = inst_port_info.pop('port')  # 从信息中提取端口名
        inst_port_dict = {
            inst_name: {
                port_name: inst_port_info
            }
        }
        editor.add_inst_port(inst_port_dict)

    if args.rm_port:
        editor.rm_port(args.rm_port)
    if args.rm_wire:
        editor.rm_wire(args.rm_wire)
    if args.rm_inst_port:
        editor.rm_inst_port(**parse_rm_inst_port_spec(args.rm_inst_port))

    # Replace edited module text back to source file
    result = ModuleEditor.replace_module_text(source_text, offset_info, editor.module_text)
    return result, result != original


# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

def print_port_list(rows: List[Dict[str, Any]], direction: str = "all") -> None:
    entries = []
    for mod in rows:
        for p in mod.get("ports", []) or []:
            if direction != "all" and p.get("direction", "").lower() != direction:
                continue
            width = p.get("width", "").strip()
            signal = "{} {}".format(p["name"], width) if width else p["name"]
            entries.append((signal, p.get("direction", "")))
    if not entries:
        return
    col_w = max(len(s) for s, _ in entries)
    for signal, dir_ in entries:
        print("{:<{w}}, {}".format(signal, dir_, w=col_w))


def print_instance_tree(
    module_name: str,
    module_index: Dict[str, Dict[str, Any]],
    prefix: str,
    seen: Set[str],
) -> None:
    row = module_index.get(module_name)
    if row is None:
        return

    instances = row.get("instances", [])
    for idx, inst in enumerate(instances):
        branch = "└─ " if idx == len(instances) - 1 else "├─ "
        print(f"{prefix}{branch}{inst['name']} ({inst['type']})")
        next_prefix = prefix + ("   " if idx == len(instances) - 1 else "│  ")
        if inst["type"] in seen:
            continue
        seen.add(inst["type"])
        print_instance_tree(inst["type"], module_index, next_prefix, seen)
        seen.remove(inst["type"])


def print_hierarchy(rows: List[Dict[str, Any]]) -> None:
    if not rows:
        print("No module declaration found.")
        return

    module_index = {row["module"]: row for row in rows}

    for mod in rows:
        name = mod["module"]
        print(f". {name}")
        print_instance_tree(name, module_index, "", set())
        print()


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

CLI_USAGE = (
    "%(prog)s [-h] [--list-port [all|input|output|inout|ref]] [--hier] "
    "[--inst-module] [--inst-name INST_NAME] [--inst-no-param] "
    "[--add-port ADD_PORT] [--add-wire ADD_WIRE] [--add-inst-port ADD_INST_PORT] "
    "[--rm-port RM_PORT] [--rm-wire RM_WIRE] [--rm-inst-port RM_INST_PORT] "
    "[--module MODULE_NAME] [--inplace | --output OUTPUT_FILE] sv_file"
)

def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Parse / edit Verilog module ports with pyslang",
        usage=CLI_USAGE,
    )
    parser.add_argument("sv_file", type=Path, help="Path to .v/.sv file")

    parser.add_argument(
        "--list-port",
        nargs="?",
        const="all",
        choices=["all", "input", "output", "inout", "ref"],
        dest="list_port",
        metavar="FILTER",
        help="Filter ports by direction: all, input, output, inout, ref (default: all)",
    )
    parser.add_argument("--hier", "--hierarchy", action="store_true", dest="hierarchy", help="Print module hierarchy")
    parser.add_argument("--module", dest="module_name", help="Specify module name if file contains multiple modules")
    parser.add_argument("--inst-module", action="store_true", dest="inst_module", help="Print instantiation template for the module in the file")
    parser.add_argument("--inst-name", dest="inst_name", help="Instance name used with --inst-module")
    parser.add_argument(
        "--inst-no-param",
        action="store_true",
        dest="inst_no_param",
        help="With --inst-module, instantiate ports only (skip parameter block)",
    )

    parser.add_argument("--add-port", dest="add_port", help="Add port: 'direction, type, width, name, dimension'")
    parser.add_argument("--add-wire", dest="add_wire", help="Add wire: 'type, width, name, dimension'")
    parser.add_argument("--add-inst-port", dest="add_inst_port", help="Add instance port: 'instname, port, wire'")

    parser.add_argument("--rm-port", dest="rm_port", help="Remove port from module header by name")
    parser.add_argument("--rm-wire", dest="rm_wire", help="Remove wire definition by name")
    parser.add_argument("--rm-inst-port", dest="rm_inst_port", help="Remove instance port: 'instname, name'")

    out_group = parser.add_mutually_exclusive_group()
    out_group.add_argument("--inplace", action="store_true", dest="inplace", help="Write edits back to input file")
    out_group.add_argument("--output", dest="output_file", type=Path, help="Write edited output to another file")

    return parser


def main() -> int:
    parser = build_arg_parser()
    args = parser.parse_args()

    if not args.sv_file.exists():
        print(f"Error: file not found: {args.sv_file}")
        return 1

    has_edit_action = any(
        [args.add_port, args.add_wire, args.add_inst_port, args.rm_port, args.rm_wire, args.rm_inst_port]
    )

    if has_edit_action:
        source_text = args.sv_file.read_text(encoding="utf-8", errors="ignore")
        try:
            new_text, changed = apply_edit_actions(source_text, args)
        except Exception as exc:
            print(f"Edit failed: {exc}")
            return 3

        if args.inplace:
            args.sv_file.write_text(new_text, encoding="utf-8")
            print("Edit applied in-place.")
            return 0

        if args.output_file:
            args.output_file.write_text(new_text, encoding="utf-8")
            print(f"Edited file written to: {args.output_file}")
            return 0

        if changed:
            print(new_text)
        else:
            print("No changes needed.")
        return 0

    if args.inst_module:
        try:
            editor = ModuleEditor.from_file(args.sv_file, args.module_name)
            snippet = editor.gen_inst(
                include_params=not args.inst_no_param,
                instance_name=args.inst_name,
            )
            print(snippet)
        except Exception as exc:
            print(f"Error generating instantiation: {exc}")
            return 4
        return 0

    if args.hierarchy:
        try:
            if args.module_name:
                # 用户指定了模块名，只处理该模块
                editor = ModuleEditor.from_file(args.sv_file, args.module_name)
                data = [editor.get_hier()]
            else:
                # 用户未指定模块名，尝试使用 from_file（如果文件有多个模块会抛出异常）
                editor = ModuleEditor.from_file(args.sv_file)
                data = [editor.get_hier()]
        except ValueError as e:
            if "file contains multiple modules" in str(e):
                # 如果是多模块错误，提示用户使用 --module 参数
                print(f"Error: {e}")
                return 2
            else:
                raise  # 重新抛出其他 ValueError
        except Exception as exc:
            print(f"Parse failed: {exc}")
            return 2
        print_hierarchy(data)
        return 0

    if args.list_port is None:
        parser.print_help()
        return 0

    try:
        editor = ModuleEditor.from_file(args.sv_file, args.module_name)
        data = [editor.analyze()]
    except Exception as exc:
        print(f"Parse failed: {exc}")
        return 2

    if args.list_port is not None:
        print_port_list(data, args.list_port)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())