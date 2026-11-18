#!/usr/bin/env python3
"""Extract DWC controller specifications from generated HDL constants."""

import argparse
import sys
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional

from . import __version__
from .markdown import render_markdown
from .macros import (
    BOOLEAN_MACROS, CONTROLLER_ANCHORS, DEFINE_RE, TARGET_MACROS, MacroValues, parse_defines,
    parse_numeric_value, resolve_target_macro_name,
)
from .report import PCIE_GEN_RATE_GTPS, build_analysis, print_analysis


DEFAULT_TARGET_FILE_PATTERN = "*pcie_ctl_cc_constants.svh*"
DEFAULT_GLOBS = ("**/*.v", "**/*.vh", "**/*.sv", "**/*.svh", "**/*.h", "**/*.inc")
# Retain the former import name; link rates are printed in GT/s in the summary.
PCIE_GEN_RATE_GBPS = PCIE_GEN_RATE_GTPS


def discover_files(paths: Iterable[Path], globs: Iterable[str]) -> List[Path]:
    result = []
    seen = set()
    for path in paths:
        candidates = [path] if path.is_file() else (
            f for pattern in globs for f in path.glob(pattern)
        ) if path.is_dir() else []
        for candidate in candidates:
            if candidate.is_file() and candidate.resolve() not in seen:
                seen.add(candidate.resolve())
                result.append(candidate)
    return result


def discover_target_files(paths: Iterable[Path], pattern: str) -> List[Path]:
    return discover_files(paths, ("**/" + pattern,))


def discover_controller_files(paths: Iterable[Path]) -> List[Path]:
    """Match a filename substring, only for immediate children of src/."""
    return sorted(
        (path for path in discover_target_files(paths, DEFAULT_TARGET_FILE_PATTERN)
         if path.match(DEFAULT_TARGET_FILE_PATTERN) and path.parent.resolve().name == "src"),
        key=str,
    )


def extract_target_macros(files):
    """Extract fixed and per-PF macros, retaining referenced helper definitions."""
    values = MacroValues()
    sources, source_lines, source_text = {}, {}, {}
    target_set = set(TARGET_MACROS)
    candidates = {}
    flag_fallbacks = {}
    for file_path in files:
        values.files.append(str(file_path))
        defines = parse_defines(file_path)
        anchor_prefixes = {
            name[:-len(anchor)] for name in defines for anchor in CONTROLLER_ANCHORS
            if name == anchor or name.endswith("_" + anchor)
        }
        named_prefixes = anchor_prefixes - {""}
        if len(named_prefixes) > 1:
            raise ValueError("Multiple controller macro prefixes found: {}. Select one controller input.".format(
                ", ".join(sorted(named_prefixes))))
        controller_prefix = (next(iter(named_prefixes)) if named_prefixes else
                             "" if "" in anchor_prefixes else None)
        for name, (raw, line, text) in defines.items():
            values.definitions[name] = raw
            canonical = resolve_target_macro_name(name, target_set, controller_prefix)
            if canonical is not None:
                candidates.setdefault(canonical, []).append((name, raw, str(file_path), line, text))
            if name.endswith("_VALUE"):
                flag = resolve_target_macro_name(name[:-6], target_set, controller_prefix)
                if flag in BOOLEAN_MACROS:
                    flag_fallbacks.setdefault(flag, []).append(
                        (0, (name, raw, str(file_path), line, text), "Numeric *_VALUE configuration flag"))
        for name, (raw, line, text) in getattr(defines, "disabled", {}).items():
            flag = resolve_target_macro_name(name, target_set, controller_prefix)
            if flag in BOOLEAN_MACROS:
                flag_fallbacks.setdefault(flag, []).append(
                    (1, (name, raw, str(file_path), line, text), "Commented-out configuration flag means Disabled"))
    for flag, fallbacks in flag_fallbacks.items():
        if flag not in candidates:
            priority = min(item[0] for item in fallbacks)
            selected = [item for item in fallbacks if item[0] == priority]
            candidates[flag] = [item[1] for item in selected]
            values.rules[flag] = selected[0][2]
    for canonical, matches in candidates.items():
        prefixed = [match for match in matches if match[0] != canonical]
        exact = [match for match in matches if match[0] == canonical]
        choices = prefixed or exact or matches
        if len(choices) > 1:
            details = ", ".join("{} ({}:{})".format(match[0], match[2], match[3]) for match in choices)
            raise ValueError("Ambiguous macro {}: {}. Select one controller input.".format(canonical, details))
        name, raw, source, line, text = choices[0]
        values[canonical] = raw
        values.actual_names[canonical] = name
        sources[canonical], source_lines[canonical], source_text[canonical] = source, line, text
    prefixes = {
        (actual[:-6] if name in BOOLEAN_MACROS and actual.endswith("_VALUE") else actual)[:-len(name)]
        for name, actual in values.actual_names.items() if actual != name
    }
    if len(prefixes) > 1:
        raise ValueError("Multiple controller macro prefixes found: {}. Select one controller input.".format(
            ", ".join(sorted(prefixes))))
    ordered = MacroValues()
    ordered.update((name, values.get(name)) for name in TARGET_MACROS)
    ordered.update((name, values[name]) for name in sorted(values) if name not in target_set)
    ordered.definitions, ordered.actual_names, ordered.files = values.definitions, values.actual_names, values.files
    ordered.rules = values.rules
    return ordered, sources, source_lines, source_text


def find_companion_cap_file(controller_file: Path) -> Optional[Path]:
    """Find companion cap_port_cfg.svh in include/ directories."""
    parent = controller_file.parent
    candidates = []
    for inc_dir in (parent / "include", parent.parent / "include", parent.parent / "src" / "include", parent):
        if inc_dir.is_dir():
            for f in sorted(inc_dir.glob("*cap_port_cfg*.svh"), key=str):
                candidates.append(f)
    if candidates:
        prefix = controller_file.stem.split("DWC_pcie_ctl")[0]
        if prefix:
            matching = [c for c in candidates if c.name.startswith(prefix)]
            if matching:
                return matching[0]
        return candidates[0]
    return None


def _collect_macro_data(file_inputs=None):
    if isinstance(file_inputs, str):
        file_inputs = [file_inputs]
    if file_inputs:
        files = []
        for item in file_inputs:
            path = Path(item)
            if not path.exists():
                raise FileNotFoundError("Input path does not exist: {}".format(path))
            files.extend([path] if path.is_file() else discover_controller_files([path]))
        files = sorted({path.resolve() for path in files}, key=str)
    else:
        files = discover_controller_files([Path(".")])
    if not files:
        raise FileNotFoundError(
            "No file matched {} directly inside a src directory under the search root. "
            "Use --file to specify an exact input file.".format(DEFAULT_TARGET_FILE_PATTERN))
    target_files = []
    if len(files) > 1:
        constants_files = [f for f in files if "cap_port_cfg" not in f.name]
        cap_files = [f for f in files if "cap_port_cfg" in f.name]
        if len(constants_files) == 1 and len(cap_files) == 1:
            target_files = [constants_files[0], cap_files[0]]
        else:
            raise ValueError("Multiple matched files found. Use --file to specify exactly one input.\n" +
                             "\n".join("  - {}".format(path) for path in files))
    else:
        primary = files[0]
        target_files = [primary]
        if "cap_port_cfg" not in primary.name:
            companion = find_companion_cap_file(primary)
            if companion and companion.resolve() != primary.resolve():
                target_files.append(companion)
    return extract_target_macros(target_files)


def getaxiinfo(file_inputs: Optional[Iterable[str]] = None, debug: bool = False) -> Dict[str, Optional[str]]:
    """Return raw target macro values, including per-PF values; never print logs.

    Discover one matching constants file directly inside src/, or read an explicit
    file. Missing fixed targets retain None. debug is accepted for API compatibility.
    """
    ordered, _, _, _ = _collect_macro_data(file_inputs)
    return ordered


def get_pcie_capabilities(file_inputs: Optional[Iterable[str]] = None) -> List[Dict[str, Any]]:
    """Return parsed PCIe capability details (Standard & Extended) as structured dictionaries."""
    ordered, _, _, _ = _collect_macro_data(file_inputs)
    analysis = build_analysis(ordered)
    cap_section = next((sec for sec in analysis["sections"] if sec[0] == "CAPABILITIES"), None)
    if not cap_section or not cap_section[3]:
        return []
    result = []
    for row in cap_section[3]:
        scope, cap_type, base_str, next_str, cap_id_str, name, desc, size_str = row
        base_int = int(base_str, 16) if base_str.startswith("0x") else None
        next_int = int(next_str, 16) if next_str.startswith("0x") else None
        cap_id_int = int(cap_id_str, 16) if cap_id_str.startswith("0x") else None
        result.append({
            "scope": scope,
            "type": cap_type,
            "base_address": base_int,
            "base_address_hex": base_str,
            "next_offset": next_int,
            "next_offset_hex": next_str,
            "cap_id": cap_id_int,
            "cap_id_hex": cap_id_str,
            "name": name,
            "description": desc,
            "size": size_str,
        })
    return result


def _macro_details(analysis, ordered, sources, source_lines, source_text):
    details = []
    names = sorted(set(analysis["used"]) | {name for name, value in ordered.items() if value is not None})
    for name in names:
        raw = ordered.get(name)
        resolved = analysis["resolved"].get(name)
        actual = getattr(ordered, "actual_names", {}).get(name, name)
        details.append({
            "name": "{}{}".format(name, " ({})".format(actual) if actual != name else ""),
            "raw": raw if raw is not None else "<NOT_FOUND>",
            "resolved": resolved if resolved is not None else "Unknown / not evaluated",
            "rule": getattr(ordered, "rules", {}).get(name, ""),
            "source": "{}:{}".format(sources[name], source_lines[name]) if name in sources else "",
            "line": source_text.get(name, ""),
        })
    return details


def _print_cli_output(ordered, sources, source_lines, source_text, debug, analysis=None):
    if analysis is None:
        analysis = build_analysis(ordered)
    if debug:
        print("[SOURCE]")
        files = getattr(ordered, "files", sorted(set(sources.values())))
        for path in files:
            print("File: " + str(Path(path).resolve()))
        print()
    print_analysis(analysis)
    if debug:
        print("\n[MACRO_DETAILS]")
        for item in _macro_details(analysis, ordered, sources, source_lines, source_text):
            print(item["name"])
            print("  Raw     : {}".format(item["raw"]))
            print("  Resolved: {}".format(item["resolved"]))
            if item["rule"]:
                print("  Rule    : " + item["rule"])
            if item["source"]:
                print("  Source  : " + item["source"])
                print("  Line    : " + item["line"])
        for label, name, rule, result in analysis["trace"]:
            print("{} = {}\n  Macro: {}\n  Rule : {}".format(label, result, name, rule))
    return 0


def build_arg_parser():
    parser = argparse.ArgumentParser(description="Summarize DWC PCIe, AXI DMA/Slave/CFG, embedded DMA, Function and BAR specifications.")
    parser.add_argument("--version", action="version", version="%(prog)s " + __version__)
    parser.add_argument("--file", nargs="+", help=(
        "Read one explicit file, or find one *pcie_ctl_cc_constants.svh* directly "
        "inside src/ below the supplied directory. Default: search the current directory."))
    parser.add_argument("--debug", action="store_true", help="Show [SOURCE] and [MACRO_DETAILS] with raw values and line numbers.")
    parser.add_argument("-o", "--output", type=Path, metavar="REPORT.md",
                        help="Also write a UTF-8 Markdown report; --debug includes sources and macro details.")
    return parser


def getaxiinfo_cli(argv: Optional[List[str]] = None) -> int:
    args = build_arg_parser().parse_args(argv)
    try:
        ordered, sources, lines, text = _collect_macro_data(args.file)
        analysis = build_analysis(ordered)
        if args.output is not None:
            files = getattr(ordered, "files", sorted(set(sources.values())))
            if any(args.output.resolve() == Path(path).resolve() for path in files):
                raise ValueError("Output report must not overwrite the input constants file.")
            details = _macro_details(analysis, ordered, sources, lines, text) if args.debug else ()
            report = render_markdown(analysis, files=files, macro_details=details, debug=args.debug)
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(report, encoding="utf-8")
        return _print_cli_output(ordered, sources, lines, text, args.debug, analysis=analysis)
    except (OSError, UnicodeError, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(getaxiinfo_cli())
