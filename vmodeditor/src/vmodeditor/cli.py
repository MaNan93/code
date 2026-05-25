#!/usr/bin/env python3
"""Command-line interface for Verilog/SystemVerilog module editing.

Uses verible-verilog-syntax CST for precise source code navigation and editing.
CLI interface compatible with modeditor.
"""

import argparse
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

from vmodeditor.utils import (
    VeribleParser,
    cmd_add_inst_port,
    cmd_add_port,
    cmd_add_wire,
    cmd_gen_inst,
    cmd_rm_inst_port,
    cmd_rm_port,
    cmd_rm_wire,
)


# ---------------------------------------------------------------------------
# Output Helpers
# ---------------------------------------------------------------------------

def print_port_list(module_info: Dict, direction: str = "all") -> None:
    """Print port list, optionally filtered by direction."""
    ports = module_info.get("ports", [])
    entries = []
    for p in ports:
        d = p.get("direction", "").strip().lower()
        if direction != "all" and d != direction:
            continue
        width = p.get("width", "").strip()
        signal = f"{p['name']} {width}" if width else p["name"]
        entries.append((signal, p.get("direction", "")))

    if not entries:
        return

    col_w = max(len(s) for s, _ in entries)
    for signal, dir_ in entries:
        print(f"{signal:<{col_w}}, {dir_}")


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
        branch = "\u2514\u2500 " if idx == len(instances) - 1 else "\u251c\u2500 "
        print(f"{prefix}{branch}{inst['name']} ({inst['type']})")
        next_prefix = prefix + ("   " if idx == len(instances) - 1 else "\u2502  ")
        if inst["type"] in seen:
            continue
        seen.add(inst["type"])
        print_instance_tree(inst["type"], module_index, next_prefix, seen)
        seen.remove(inst["type"])


def print_hierarchy(all_modules: List[Dict]) -> None:
    """Print hierarchy for all modules."""
    if not all_modules:
        print("No module declaration found.")
        return

    module_index: Dict[str, Dict[str, Any]] = {}
    for mod in all_modules:
        module_index[mod["name"]] = mod

    for mod in all_modules:
        name = mod["name"]
        print(f". {name}")
        print_instance_tree(name, module_index, "", set())
        print()


# ---------------------------------------------------------------------------
# Edit Dispatcher
# ---------------------------------------------------------------------------

def apply_edit_actions(source_text: str, args: argparse.Namespace,
                       vparser: VeribleParser) -> Tuple[str, bool]:
    """Apply all edit flags to source text. Returns (new_text, changed)."""
    original = source_text
    module_info = vparser.get_module(args.module_name)

    if args.add_port:
        source_text = cmd_add_port(source_text, module_info, args.add_port)
    if args.add_wire:
        source_text = cmd_add_wire(source_text, module_info, args.add_wire)
    if args.add_inst_port:
        source_text = cmd_add_inst_port(source_text, module_info, args.add_inst_port)
    if args.rm_port:
        source_text = cmd_rm_port(source_text, module_info, args.rm_port)
    if args.rm_wire:
        source_text = cmd_rm_wire(source_text, module_info, args.rm_wire)
    if args.rm_inst_port:
        source_text = cmd_rm_inst_port(source_text, module_info, args.rm_inst_port)

    return source_text, source_text != original


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


def _preprocess_argv(argv: List[str]) -> List[str]:
    """Fix argparse nargs='?' issue: --list-port <file> should be --list-port all <file>.

    When --list-port (nargs='?') is followed by a value that is not a valid
    filter choice, argparse still tries to consume it. This preprocess inserts
    'all' between --list-port and the next argument in that case.
    """
    _LIST_PORT_CHOICES = {"all", "input", "output", "inout", "ref"}
    result: List[str] = []
    i = 0
    while i < len(argv):
        a = argv[i]
        result.append(a)
        if a == "--list-port":
            if i + 1 < len(argv) and argv[i + 1] not in _LIST_PORT_CHOICES:
                result.append("all")
        i += 1
    return result


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Parse / edit Verilog module ports with verible-verilog-syntax",
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
    parser.add_argument("--hier", "--hierarchy", action="store_true", dest="hierarchy",
                        help="Print module hierarchy")
    parser.add_argument("--module", dest="module_name",
                        help="Specify module name if file contains multiple modules")
    parser.add_argument("--inst-module", action="store_true", dest="inst_module",
                        help="Print instantiation template for the module in the file")
    parser.add_argument("--inst-name", dest="inst_name",
                        help="Instance name used with --inst-module")
    parser.add_argument(
        "--inst-no-param",
        action="store_true",
        dest="inst_no_param",
        help="With --inst-module, instantiate ports only (skip parameter block)",
    )

    parser.add_argument("--add-port", dest="add_port",
                        help="Add port: 'direction, type, width, name, dimension'")
    parser.add_argument("--add-wire", dest="add_wire",
                        help="Add wire: 'type, width, name, dimension'")
    parser.add_argument("--add-inst-port", dest="add_inst_port",
                        help="Add instance port: 'instname, port, wire'")

    parser.add_argument("--rm-port", dest="rm_port",
                        help="Remove port from module header by name")
    parser.add_argument("--rm-wire", dest="rm_wire",
                        help="Remove wire definition by name")
    parser.add_argument("--rm-inst-port", dest="rm_inst_port",
                        help="Remove instance port: 'instname, name'")

    out_group = parser.add_mutually_exclusive_group()
    out_group.add_argument("--inplace", action="store_true", dest="inplace",
                           help="Write edits back to input file")
    out_group.add_argument("--output", dest="output_file", type=Path,
                           help="Write edited output to another file")

    return parser


def main() -> int:
    parser = build_arg_parser()
    args = parser.parse_args(_preprocess_argv(sys.argv[1:]))

    if not args.sv_file.exists():
        print(f"Error: file not found: {args.sv_file}")
        return 1

    has_edit_action = any(
        [args.add_port, args.add_wire, args.add_inst_port,
         args.rm_port, args.rm_wire, args.rm_inst_port]
    )

    try:
        vparser = VeribleParser(str(args.sv_file))
    except Exception as exc:
        print(f"Parse failed: {exc}")
        return 2

    if has_edit_action:
        source_text = args.sv_file.read_bytes().decode("utf-8")
        try:
            new_text, changed = apply_edit_actions(source_text, args, vparser)
        except Exception as exc:
            print(f"Edit failed: {exc}")
            return 3

        if args.inplace:
            args.sv_file.write_bytes(new_text.encode("utf-8"))
            print("Edit applied in-place.")
            return 0

        if args.output_file:
            args.output_file.write_bytes(new_text.encode("utf-8"))
            print(f"Edited file written to: {args.output_file}")
            return 0

        if changed:
            print(new_text)
        else:
            print("No changes needed.")
        return 0

    if args.inst_module:
        try:
            module_info = vparser.get_module(args.module_name or None)
            snippet = cmd_gen_inst(
                module_info,
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
                module_info = vparser.get_module(args.module_name)
                all_mods = [module_info]
            else:
                all_mods = vparser.get_modules()
        except ValueError as e:
            print(f"Error: {e}")
            return 2
        except Exception as exc:
            print(f"Parse failed: {exc}")
            return 2
        print_hierarchy(all_mods)
        return 0

    if args.list_port is None:
        parser.print_help()
        return 0

    try:
        module_info = vparser.get_module(args.module_name or None)
    except Exception as exc:
        print(f"Parse failed: {exc}")
        return 2

    print_port_list(module_info, args.list_port)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
