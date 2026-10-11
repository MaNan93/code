#!/usr/bin/env python3
"""Prepare a PCIe generation workspace and invoke ramgen."""

from __future__ import annotations

import os
import re
import csv
import shutil
import sys
import stat
import argparse
from pathlib import Path
from typing import Callable, Dict, List, Optional, Set, Tuple

# Support this monorepo's source checkout as well as installed packages.
for _package in ("ramgen", "vutils"):
    _source = Path(__file__).resolve().parent.parent / _package / "src"
    if _source.is_dir():
        sys.path.insert(0, str(_source))
from ramgen import ramgen
from ramgen.sv_scan import IDENTIFIER, instance_declarations, matching_delimiters, module_headers, tokenize
from vutils.vedit import read_interface_from_file, vedit
del _package, _source
ENCODING = "utf-8"


def _pciegen_config_dir() -> Optional[Path]:
    """Return $PCIEGEN directory if set and exists, otherwise None."""
    val = os.environ.get("PCIEGEN", "").strip()
    if not val:
        return None
    d = Path(val).expanduser().resolve()
    return d if d.is_dir() else None


def _find_config_file(filename: str) -> Path:
    """Look up *filename* under $PCIEGEN first, then fall back to script directory."""
    cdir = _pciegen_config_dir()
    if cdir is not None:
        candidate = cdir / filename
        if candidate.is_file():
            return candidate
    return (Path(__file__).resolve().parent / filename)


# Directory names
SRC_DIR = "src"
EXAMPLES_DIR = "examples"
SCRATCH_DIR = "scratch"
MEM_DIR = "mem"
TOP_DIR = "top"

# File names
DWC_PCIE_CTL_LST = "DWC_pcie_ctl.lst"
COMPILE_F = "compile.f"
PCIE_IIP_DEVICE_SV = "pcie_iip_device.sv"
PCIE_IIP_SUBSYSTEM_SV = "pcie_iip_subsystem.sv"
PCIE_IIP_RAMS_SV = "pcie_iip_rams.sv"
PCIE_CTRL_WRAPPER_SV = "pcie_ctrl_wrapper.sv"
FLIST_F = "flist.f"
DWC_PCIE_CTL_UNDEF_V = "DWC_pcie_ctl-undef.v"
RAMS_COMPILE_F = "rams/compile.f"
DWC_PCIE_CTL_UNDEF_SVH = "DWC_pcie_ctl_undef.svh"
DWC_PCIE_CTL_UNPREFIX_SVH = "DWC_pcie_ctl_unprefix.svh"
CDM_PL_REG_SV = "Cdm/cdm_pl_reg.sv"
CDM_SV = "Cdm/cdm.sv"
DWC_PCIE_CORE_SV = "products/DWC_pcie_core.sv"
DBI_MAP_SV = "dbi-map.sv"
REPORT_HTML = "report/IO.html"
RULE_CSV = "rule.csv"

# Module pattern
DWC_PCIE_CTL_PATTERN = "DWC_pcie_ctl"

# CDM signals to add across cdm_pl_reg.sv, cdm.sv, and DWC_pcie_core.sv
CDM_SIGNALS = [
    {"name": "sys_fast_link_mode", "direction": "input"},
    {"name": "sys_link_capable", "direction": "input", "width": "[5:0]"},
]
CDM_PINS = [
    ("sys_fast_link_mode", "sys_fast_link_mode"),
    ("sys_link_capable", "sys_link_capable"),
]

DEBUG_SIGNALS = [
    {"name": "ltssm_state", "direction": "output", "width": "[8:0]"},
    {"name": "sys_debug", "direction": "output", "width": "[8:0]"},
    {"name": "current_data_rate", "direction": "output", "width": "[2:0]"},
]


def _warn(message: str) -> None:
    print(f"warning: {message}", flush=True)


def _pick_target_module(modules: List[Dict[str, object]], path: Path,
                        inst_name: Optional[str] = None) -> Optional[Dict[str, object]]:
    """Pick target module info, preferring the module that owns *inst_name*."""
    if not modules:
        return None

    if inst_name:
        for module_info in modules:
            instances = module_info.get("instances", []) or []
            if any(str(inst.get("name", "")) == inst_name for inst in instances):
                return module_info

    if len(modules) == 1:
        return modules[0]

    for module_info in modules:
        if str(module_info.get("name", "")).strip() == path.stem:
            return module_info

    return modules[0]


def _load_editor(path: Path, inst_name: Optional[str] = None) -> vedit:
    """Create a vedit editor for the module that owns *inst_name*."""
    return vedit.from_file(path, auto_select=True, inst_name=inst_name)


def _append_to_file(
    path: Path,
    signals: Optional[List[Dict[str, str]]] = None,
    pins: Optional[List[Tuple[str, str]]] = None,
    inst_name: Optional[str] = None,
) -> bool:
    """使用 vedit 批量添加端口和实例端口连接。

    Args:
        path: 文件路径
        signals: 端口列表，每个端口是包含 direction/name/type/width/dimension 的字典
        pins: 引脚列表，每个引脚是 (port, wire) 元组
        inst_name: 实例名称

    Returns:
        如果文件被修改则返回 True，否则返回 False
    """
    editor = _load_editor(path, inst_name=inst_name)

    original_text = path.read_text(encoding=ENCODING)

    port_dict = {}
    if signals:
        port_dict = {
            s["name"]: {
                "direction": s.get("direction", ""),
                "type": s.get("type", ""),
                "width": s.get("width", ""),
                "dimension": s.get("dimension", ""),
            }
            for s in signals
        }
    inst_port_dict = {}
    if pins and inst_name:
        inst_port_dict = {inst_name: {port: {"wire": wire} for port, wire in pins}}
    editor.add_ports_and_inst_ports(port_dict, inst_port_dict)

    updated_text = editor.module_text
    if updated_text != original_text:
        path.write_text(updated_text, encoding=ENCODING)
        return True
    return False










def build_module_prefix(prefix: str) -> str:
    """Build module name prefix from detected prefix string."""
    return f"{prefix}_" if prefix else ""


def build_paths() -> dict:
    """Resolve all runtime paths from the current working directory."""
    project_root = Path.cwd()
    rtl_dir = project_root / "rtl"
    mem_dir = rtl_dir / "mem"
    default_sv_file = project_root / "examples" / "pcie_iip_rams.sv"
    return {
        "project_root": project_root,
        "rtl_dir": rtl_dir,
        "mem_dir": mem_dir,
        "default_sv_file": default_sv_file,
    }


def ensure_source_dirs(project_root: Path, required_dirs: Tuple[str, ...]):
    """Validate required source directories before copying."""
    missing = [name for name in required_dirs if not (project_root / name).is_dir()]
    if missing:
        raise FileNotFoundError(
            "missing required directories under {}: {}".format(
                project_root,
                ", ".join(missing),
            )
        )


def ensure_tree_user_writable(root_dir: Path) -> None:
    """Best-effort set user writable bits for an existing tree."""
    if not root_dir.exists():
        return

    for path in sorted(root_dir.rglob("*")):
        mode = path.stat().st_mode
        if path.is_dir():
            path.chmod(mode | stat.S_IRUSR | stat.S_IWUSR | stat.S_IXUSR)
        else:
            path.chmod(mode | stat.S_IRUSR | stat.S_IWUSR)

    root_mode = root_dir.stat().st_mode
    root_dir.chmod(root_mode | stat.S_IRUSR | stat.S_IWUSR | stat.S_IXUSR)


def copy_tree_into_rtl(project_root: Path, rtl_dir: Path, source_name: str) -> Path:
    """Copy one project directory into rtl/<source_name>."""
    source_dir = project_root / source_name
    destination_dir = rtl_dir / source_name
    
    # Ensure destination is writable before copying
    if destination_dir.exists():
        ensure_tree_user_writable(destination_dir)
    
    shutil.copytree(source_dir, destination_dir, dirs_exist_ok=True)
    
    # Ensure copied files are writable (source may have been read-only)
    ensure_tree_user_writable(destination_dir)
    
    return destination_dir


def copy_scratch_svh_into_rtl(project_root: Path, rtl_dir: Path) -> Path:
    """Copy only .svh and .vh files from scratch into rtl/scratch, preserving layout."""
    source_dir = project_root / "scratch"
    destination_dir = rtl_dir / "scratch"
    destination_dir.mkdir(parents=True, exist_ok=True)

    for pattern in ("*.svh", "*.vh"):
        for source_file in source_dir.rglob(pattern):
            relative_path = source_file.relative_to(source_dir)
            destination_file = destination_dir / relative_path
            destination_file.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source_file, destination_file)
    
    # Ensure copied files are writable
    ensure_tree_user_writable(destination_dir)

    return destination_dir


def rewrite_cdm_pl_reg_file(rtl_dir: Path) -> Optional[Path]:
    """Rewrite rtl/src/Cdm/cdm_pl_reg.sv with new signal definitions."""
    cdm_pl_reg_file = rtl_dir / SRC_DIR / CDM_PL_REG_SV
    if not cdm_pl_reg_file.is_file():
        return None

    editor = _load_editor(cdm_pl_reg_file)
    text = editor.module_text

    def replacement_rhs(match: re.Match) -> Optional[str]:
        rhs = match.group("rhs")
        for start, register, signal in (
            ("write_pulse", r"pl_reg_16\s*\[\s*7\s*\]", "sys_fast_link_mode"),
            ("phy_type", r"pl_reg_18\s*\[\s*5\s*:\s*0\s*\]", "sys_link_capable"),
        ):
            if re.match(rf"\s*\(\s*{start}\b", rhs) and re.search(register, rhs):
                return signal
        return None

    # Replace the complete assignment RHS, including closing parentheses and
    # multiline expressions. Do not write the file until editing has succeeded.
    masked_text = re.sub(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"',
                         lambda m: re.sub(r"[^\n]", " ", m.group(0)), text)
    replacements = []
    for match in re.finditer(
        r"(?P<head>\b[A-Za-z_][A-Za-z0-9_$]*(?:\s*\[[^\]]+\])?\s*=(?!=)\s*)"
        r"(?P<rhs>[^;]+);", masked_text,
    ):
        signal = replacement_rhs(match)
        if signal is not None:
            replacements.append((match.start("rhs"), match.end("rhs"), signal))
    for start, end, signal in reversed(replacements):
        text = text[:start] + signal + text[end:]
    if text != editor.module_text:
        editor = vedit(text, editor.module_name)

    editor.add_port({
        "sys_fast_link_mode": {"direction": "input"},
        "sys_link_capable": {"direction": "input", "width": "[5:0]"},
    })

    updated_text = editor.module_text
    if updated_text != cdm_pl_reg_file.read_text(encoding=ENCODING):
        cdm_pl_reg_file.write_text(updated_text, encoding=ENCODING)

    return cdm_pl_reg_file


def rewrite_cdm_file(rtl_dir: Path) -> Optional[Path]:
    """Rewrite rtl/src/Cdm/cdm.sv to add new port connections and signal declarations."""
    cdm_file = rtl_dir / SRC_DIR / CDM_SV
    if not cdm_file.is_file():
        return None

    _append_to_file(cdm_file, signals=CDM_SIGNALS, pins=CDM_PINS, inst_name="u_cdm_pl_reg")
    return cdm_file


def rewrite_dwc_pcie_core_file(rtl_dir: Path) -> Optional[Path]:
    """Rewrite rtl/src/products/DWC_pcie_core.sv to add new port connections."""
    dwc_pcie_core_file = rtl_dir / SRC_DIR / DWC_PCIE_CORE_SV
    if not dwc_pcie_core_file.is_file():
        return None

    _append_to_file(dwc_pcie_core_file, signals=CDM_SIGNALS, pins=CDM_PINS, inst_name="u_cdm")
    return dwc_pcie_core_file





def append_cdm_to_dwc_pcie_ctl_file(rtl_dir: Path) -> Optional[Path]:
    """Append CDM ports and u_DWC_pcie_core pins to DWC_pcie_ctl.sv."""
    candidates = sorted((rtl_dir / SRC_DIR).rglob(f"*{DWC_PCIE_CTL_PATTERN}.sv"))
    if not candidates:
        return None
    ctl_file = candidates[0]
    _append_to_file(ctl_file, signals=CDM_SIGNALS, pins=CDM_PINS, inst_name="u_DWC_pcie_core")
    return ctl_file





def append_cdm_to_subsystem_file(rtl_dir: Path) -> Optional[Path]:
    """Append CDM/debug ports and u_pcie_core pins to pcie_iip_subsystem.sv."""
    subsystem_file = rtl_dir / EXAMPLES_DIR / PCIE_IIP_SUBSYSTEM_SV
    if not subsystem_file.is_file():
        return None
    _append_to_file(subsystem_file, signals=CDM_SIGNALS + DEBUG_SIGNALS, pins=CDM_PINS, inst_name="u_pcie_core")
    return subsystem_file





def rewrite_dwc_pcie_ctl_list(rtl_dir: Path) -> Optional[Path]:
    """Normalize rtl/src/DWC_pcie_ctl.lst paths and comment out undef include."""
    list_file = rtl_dir / SRC_DIR / DWC_PCIE_CTL_LST
    if not list_file.is_file():
        return None

    text = list_file.read_text(encoding=ENCODING)
    lines = text.splitlines()
    rewritten = []
    for line in lines:
        stripped = line.strip()
        if stripped.endswith(DWC_PCIE_CTL_UNDEF_V):
            rewritten.append(f"// {DWC_PCIE_CTL_UNDEF_V}")
        else:
            rewritten.append(re.sub(r"^.*?src/", "", line))
    list_file.write_text("\n".join(rewritten), encoding=ENCODING)
    return list_file


def rewrite_examples_compile_file(rtl_dir: Path) -> Optional[Path]:
    """Normalize rtl/examples/compile.f paths and comment out RAM/device entries."""
    compile_file = rtl_dir / EXAMPLES_DIR / COMPILE_F
    if not compile_file.is_file():
        return None

    text = compile_file.read_text(encoding=ENCODING)
    comment_keywords = (RAMS_COMPILE_F, PCIE_IIP_RAMS_SV, PCIE_IIP_DEVICE_SV)
    rewritten = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("//") or not stripped:
            rewritten.append(line)
        elif any(kw in stripped for kw in comment_keywords):
            rewritten.append(f"// {stripped}")
        else:
            rewritten.append(re.sub(r"^.*?examples/", "", line))
    compile_file.write_text("\n".join(rewritten), encoding=ENCODING)
    return compile_file


def find_module_prefix(rtl_dir: Path) -> str:
    """Infer the module prefix from a module name containing DWC_pcie_ctl."""
    candidate_files = sorted(rtl_dir.rglob(f"*{DWC_PCIE_CTL_PATTERN}.sv"))
    if not candidate_files:
        candidate_files = sorted(rtl_dir.rglob("*.sv"))

    for candidate_file in candidate_files:
        try:
            editor = vedit.from_file(candidate_file)
            row = editor.get_hier()
            module_name = str(row.get("module", "")).strip()
            if DWC_PCIE_CTL_PATTERN in module_name:
                raw_prefix = module_name.replace(DWC_PCIE_CTL_PATTERN, "", 1)
                return raw_prefix.rstrip("_")
        except Exception as exc:
            _warn(f"skip parsing {candidate_file}: {exc}")
            continue

    raise FileNotFoundError(
        f"unable to locate a module declaration containing {DWC_PCIE_CTL_PATTERN} under {rtl_dir}"
    )


def rewrite_pcie_iip_subsystem_file(rtl_dir: Path, module_prefix: str) -> Optional[Path]:
    subsystem_file = rtl_dir / EXAMPLES_DIR / PCIE_IIP_SUBSYSTEM_SV
    if not subsystem_file.is_file():
        return None
    module_name_prefix = build_module_prefix(module_prefix)
    lines = subsystem_file.read_text(encoding=ENCODING).splitlines()
    result = []
    for line in lines:
        line = line.replace("`SNPS_PCIE_IIP_SUBSYS_MODULE", f"{module_name_prefix}pcie_ctrl")
        line = line.replace("SNPS_PCIE_CTL_MODULE", f"{module_name_prefix}SNPS_PCIE_CTL_MODULE")
        line = line.replace("(dbi_awaddr)", "(int_dbi_awaddr)")
        line = line.replace("(dbi_araddr)", "(int_dbi_araddr)")
        if "phy_tb_backdoor" in line or "phy_instance" in line:
            stripped = line.lstrip()
            if not stripped.startswith("//"):
                ws = line[:len(line) - len(stripped)]
                line = f"{ws}// {stripped}"
        result.append(line)
    subsystem_file.write_text("\n".join(result) + "\n", encoding=ENCODING)
    return subsystem_file


def _resolve_target_module_name(path: Path, inst_name: Optional[str] = None) -> str:
    """Resolve target module name in a source file with deterministic fallback."""
    available = [m.strip() for m in vedit.list_modules_in_file(path) if m.strip()]
    if not available:
        raise ValueError(f"No module found in {path}")

    if inst_name:
        for name in available:
            try:
                editor = vedit.from_file(path, module_name=name)
            except Exception as exc:
                _warn(f"skip module '{name}' in {path}: {exc}")
                continue
            instances = editor.instances or []
            if any(str(inst.get("name", "")).strip() == inst_name for inst in instances):
                return name

    if len(available) == 1:
        return available[0]

    for name in available:
        if name == path.stem:
            return name

    return available[0]


def analyze_pcie_iip_subsystem_interface(rtl_dir: Path) -> Optional[dict]:
    """Read subsystem ports and header parameters with complete syntax validation."""
    subsystem_file = rtl_dir / EXAMPLES_DIR / PCIE_IIP_SUBSYSTEM_SV
    try:
        interface = read_interface_from_file(subsystem_file, auto_select=True)
        return {"module_name": interface["module_name"], "ports": interface["ports"],
                "style": "ansi" if interface["is_ansi"] else "non-ansi",
                "parameter_declaration": interface["parameter_declaration"],
                "param_names": interface["param_names"]}
    except Exception as exc:
        _warn(f"failed to analyze subsystem interface ({subsystem_file}): {exc}")
        return None


_SUBSYSTEM_DELETED_SIGNALS = ("p_hdrq_depth", "p_dataq_depth", "pclkx2")


def delete_subsystem_param_lines(rtl_dir: Path) -> Optional[Path]:
    subsystem_file = rtl_dir / EXAMPLES_DIR / PCIE_IIP_SUBSYSTEM_SV
    if not subsystem_file.is_file():
        return None
    patterns = [re.compile(rf"\b{re.escape(s)}\b") for s in _SUBSYSTEM_DELETED_SIGNALS]
    patterns.append(re.compile(r"wire.*current_data_rate"))
    lines = subsystem_file.read_text(encoding=ENCODING).splitlines()
    kept = [l for l in lines if not any(p.search(l) for p in patterns)]
    if kept != lines:
        subsystem_file.write_text("\n".join(kept) + "\n", encoding=ENCODING)
    return subsystem_file


def extract_port_widths_from_report_html(report_path: Path) -> Dict[str, str]:
    """Extract signal widths from report.html by matching </a>SIGNAL and </a>SIGNAL[WIDTH]</p> patterns."""
    if not report_path.is_file():
        return {}

    raw_bytes = report_path.read_bytes()
    text = None
    for encoding in ("utf-8", "gb18030", "latin-1"):
        try:
            text = raw_bytes.decode(encoding)
            break
        except UnicodeDecodeError:
            continue
    if text is None:
        text = raw_bytes.decode("utf-8", errors="replace")

    width_map: Dict[str, str] = {}
    # 匹配两种模式：1) SIGNAL[WIDTH] 2) SIGNAL
    for match in re.finditer(r"</a>([A-Za-z_][A-Za-z0-9_$]*)(?:\[([^\]]+)\])?</p>", text):
        name = match.group(1)
        width = match.group(2)  # 可能是 None
        if width is not None:
            width_map[name] = f"[{width}]"
        else:
            # 单比特信号：记录为空字符串，避免后续查找时误报 warning
            width_map[name] = ""
    return width_map


def _normalize_signal_name(value: object) -> str:
    """Keep Verilog's case-sensitive identity while trimming CSV whitespace."""
    return str(value).strip()


def _casefold_index(names) -> dict:
    """Index only names with an unambiguous spelling under case folding."""
    index = {}
    for name in names:
        folded = name.casefold()
        if folded not in index:
            index[folded] = name
        elif index[folded] != name:
            index[folded] = None
    return index


def _matching_signal_key(name: str, values: dict, folded_values: dict, source_names: dict):
    if name in values:
        return name
    # Preserve tolerant matching only when both sides have one possible name.
    folded = name.casefold()
    return folded_values.get(folded) if source_names.get(folded) == name else None


def load_wrapper_rules(rule_path: Path) -> Dict[str, Dict[str, str]]:
    """Load wrapper mapping rules from CSV with headers: name,pin,port."""
    if not rule_path.is_file():
        return {}

    rows = list(csv.reader(rule_path.read_text(encoding=ENCODING).splitlines(), skipinitialspace=True))
    if not rows:
        return {}

    headers = [cell.strip().lower() for cell in rows[0]]
    header_index = {name: idx for idx, name in enumerate(headers)}
    if "name" not in header_index:
        return {}

    def get_cell(row: List[str], key: str) -> str:
        idx = header_index.get(key)
        if idx is None or idx >= len(row):
            return ""
        return row[idx].strip()

    rules: Dict[str, Dict[str, str]] = {}
    for row in rows[1:]:
        if not any(cell.strip() for cell in row):
            continue
        name = get_cell(row, "name")
        if not name:
            continue
        rules[_normalize_signal_name(name)] = {
            "pin": get_cell(row, "pin"),
            "port": get_cell(row, "port"),
        }
    return rules


def generate_pcie_ctrl_wrapper_file(rtl_dir: Path, module_prefix: str, rule_csv_path: Optional[Path] = None) -> Optional[Path]:
    """Generate rtl/top/pcie_ctrl_wrapper.sv from the analyzed subsystem interface."""
    subsystem_info = analyze_pcie_iip_subsystem_interface(rtl_dir)
    if not subsystem_info:
        return None

    subsystem_module_name = subsystem_info["module_name"]
    parameter_declaration = subsystem_info.get("parameter_declaration", "")
    param_names = subsystem_info.get("param_names", [])
    ports = subsystem_info.get("ports", [])
    wrapper_file = rtl_dir / TOP_DIR / PCIE_CTRL_WRAPPER_SV
    wrapper_file.parent.mkdir(parents=True, exist_ok=True)

    wrapper_module_name = f"{build_module_prefix(module_prefix)}pcie_ctrl_wrapper"

    # Load HTML width overrides
    report_path = rtl_dir.parent / REPORT_HTML
    html_widths = extract_port_widths_from_report_html(report_path)
    # Prefer exact SV identifiers; tolerate case differences only if unique.
    normalized_html_widths = {
        _normalize_signal_name(key): value
        for key, value in html_widths.items()
    }
    source_case_index = _casefold_index(_normalize_signal_name(p.get("name", "")) for p in ports)
    html_case_index = _casefold_index(normalized_html_widths)
    if not report_path.is_file():
        print(f"warning: {report_path} not found, using widths from ANSI port list", flush=True)

    # Step 2: merge widths from HTML (HTML width takes precedence)
    analyzed_ports = []
    for port in ports:
        raw_name = str(port.get("name", "")).strip()
        if not raw_name:
            continue
        name_key = _normalize_signal_name(raw_name)
        direction = port.get("direction", "")
        ansi_width = port.get("width", "")
        html_key = _matching_signal_key(name_key, normalized_html_widths, html_case_index, source_case_index)
        if html_key is not None:
            width = normalized_html_widths[html_key]
        else:
            if report_path.is_file():
                print(f"warning: port '{raw_name}' not found in {REPORT_HTML}, keeping ANSI width '{ansi_width}'", flush=True)
            width = ansi_width
        dimension = port.get("dimension", "")
        # Header parameters are copied below; unknown identifiers and macros
        # cannot silently become undeclared names in the generated wrapper.
        for bounds in (width, dimension):
            if "`" in bounds:
                raise ValueError(f"port '{raw_name}' needs a resolved width from {report_path}: {bounds}")
            bounds = re.sub(r"(?:\d+)?'[sS]?[bBoOdDhH][0-9a-fA-F_xXzZ?]+", "", bounds)
            identifiers = re.findall(r"(?<![\w$])[A-Za-z_][A-Za-z0-9_$]*", bounds)
            unknown = set(identifiers) - set(param_names)
            if unknown:
                raise ValueError(f"port '{raw_name}' has undefined width parameters {sorted(unknown)}; update {report_path}")
        analyzed_ports.append({"name": raw_name, "name_key": name_key, "direction": direction,
                               "width": width, "type": port.get("type", ""), "dimension": dimension})

    # Step 3: apply rule.csv to determine wrapper ports and u_pcie_ctrl connections
    rule_path = rule_csv_path if rule_csv_path else _find_config_file(RULE_CSV)
    rules = load_wrapper_rules(rule_path)
    if not rule_path.is_file():
        print(f"warning: {rule_path} not found, using default one-to-one wrapper mapping", flush=True)

    rule_case_index = _casefold_index(rules)
    matched_rules = {_matching_signal_key(port["name_key"], rules, rule_case_index, source_case_index)
                     for port in analyzed_ports}
    for rule_name in rules:
        if rule_name not in matched_rules:
            print(f"warning: rule name '{rule_name}' not found in analyzed subsystem ports", flush=True)

    wrapper_ports: List[Dict[str, str]] = []
    wrapper_port_seen: Set[str] = set()
    wrapper_ports_by_name: Dict[str, Dict[str, str]] = {}
    internal_logic_decls: List[Dict[str, str]] = []
    internal_logic_seen: Set[str] = set()
    instance_conns: List[Dict[str, str]] = []
    internal_signal_refs: Dict[str, List[str]] = {}  # Track which ports map to same internal signal
    internal_signal_widths: Dict[str, str] = {}
    aliases: List[str] = []
    signal_shapes: Dict[str, Tuple[str, str]] = {}

    def check_shape(signal: str, width: str, dimension: str) -> None:
        shape = (width, dimension)
        if signal in signal_shapes and signal_shapes[signal] != shape:
            raise ValueError(f"signal '{signal}' has conflicting widths/dimensions: {signal_shapes[signal]} vs {shape}")
        signal_shapes[signal] = shape

    def is_valid_identifier(s: str) -> bool:
        """Check if string is a valid Verilog identifier."""
        return bool(re.match(r"^[A-Za-z_][A-Za-z0-9_$]*$", s))

    for port in analyzed_ports:
        name = port.get("name", "")
        name_key = port.get("name_key", "")
        direction = port.get("direction", "")
        width = port.get("width", "")
        ptype = port.get("type", "")
        dimension = port.get("dimension", "")
        rule_key = _matching_signal_key(name_key, rules, rule_case_index, source_case_index)
        rule = rules.get(rule_key)
        if rule is None:
            pin_value = "-"
            port_value = "-"
        else:
            pin_value = rule.get("pin", "").strip()
            port_value = rule.get("port", "").strip()

        # Validation 1: pin must not be empty
        if not pin_value:
            raise ValueError(f"rule for '{name}' has empty pin (pin column is required)")

        pin_lower = pin_value.lower()
        port_lower = port_value.lower()
        is_pin_nc = pin_lower == "nc"
        is_port_nc = port_lower == "nc"
        is_pin_dash = pin_value == "-"
        is_pin_constant = pin_value.startswith("'") or pin_value[0].isdigit()

        # Validation 2: warn if pin=nc but port is not nc (conflict)
        if is_pin_nc and port_value and port_lower != "nc":
            print(f"warning: rule for '{name}' has pin=nc but port='{port_value}'; port ignored", flush=True)

        # Determine instance connection expression
        if is_pin_nc:
            conn_expr = ""  # Floating pin
        elif is_pin_dash:
            conn_expr = name  # Use port name
        else:
            conn_expr = pin_value  # Use pin value (constant, identifier, or expression)

        # Determine wrapper port exposure (ignored if pin=nc or pin=constant)
        if is_pin_nc or is_pin_constant:
            # When pin is nc or constant, port column is meaningless, always unexposed
            wrapper_port_name = ""
        else:
            # pin is "-" or an identifier: determine wrapper port from port column
            if port_value and port_lower != "nc":
                if port_value == "-":
                    # port="-" means use pin value as wrapper port name
                    if not is_valid_identifier(conn_expr):
                        raise ValueError(f"rule for '{name}' has port='-' but pin='{pin_value}' is not a valid Verilog identifier")
                    else:
                        wrapper_port_name = conn_expr
                else:
                    # port is a specific name
                    if not is_valid_identifier(port_value):
                        raise ValueError(f"rule for '{name}' has port='{port_value}' which is not a valid Verilog identifier")
                    else:
                        wrapper_port_name = port_value
            else:
                # port is empty, "-", or "nc": expose as name
                wrapper_port_name = name if not is_port_nc else ""

        # Add wrapper port (with deduplication)
        if wrapper_port_name:
            check_shape(wrapper_port_name, width, dimension)
            previous = wrapper_ports_by_name.get(wrapper_port_name)
            if previous and previous["direction"] != direction:
                raise ValueError(f"wrapper port '{wrapper_port_name}' has conflicting directions")
        if wrapper_port_name and wrapper_port_name not in wrapper_port_seen:
            wrapper_ports.append({"name": wrapper_port_name, "direction": direction, "width": width,
                                  "type": ptype, "dimension": dimension})
            wrapper_port_seen.add(wrapper_port_name)
            wrapper_ports_by_name[wrapper_port_name] = wrapper_ports[-1]

        if wrapper_port_name and conn_expr != wrapper_port_name:
            if not is_valid_identifier(conn_expr):
                raise ValueError(f"rule for '{name}' exposes an expression without a declared source signal: {conn_expr}")
            if direction == "input":
                aliases.append(f"    assign {conn_expr} = {wrapper_port_name};")
            elif direction == "output":
                aliases.append(f"    assign {wrapper_port_name} = {conn_expr};")
            elif direction == "inout":
                # Connect the bidirectional net directly, preserving its drivers
                # and high-impedance behavior without a directional assignment.
                conn_expr = wrapper_port_name
            else:
                raise ValueError(f"unsupported renamed port direction for '{name}': {direction}")

        # Track internal signal references for duplicate detection
        if conn_expr and is_valid_identifier(conn_expr):
            check_shape(conn_expr, width, dimension)
            if conn_expr not in internal_signal_refs:
                internal_signal_refs[conn_expr] = []
            internal_signal_refs[conn_expr].append(name)
            prev_width = internal_signal_widths.get(conn_expr)
            if prev_width is None:
                internal_signal_widths[conn_expr] = width
            elif prev_width != width:
                print(
                    f"warning: internal signal '{conn_expr}' width mismatch: '{prev_width}' vs '{width}' (source port '{name}')",
                    flush=True,
                )

        # Declare internal logic for non-port connections with valid identifiers
        if (
            conn_expr
            and is_valid_identifier(conn_expr)
            and conn_expr != wrapper_port_name
            and conn_expr not in internal_logic_seen
        ):
            internal_logic_decls.append({"name": conn_expr, "width": width,
                                         "type": ptype, "dimension": dimension})
            internal_logic_seen.add(conn_expr)

        instance_conns.append({
            "pin": name,
            "expr": conn_expr,
            "direction": direction,
        })

    # Validation 3: warn about duplicate internal signal mappings
    for signal_name, port_names in internal_signal_refs.items():
        if len(port_names) > 1:
            print(f"warning: multiple subsystem ports map to internal signal '{signal_name}': {', '.join(port_names)}", flush=True)

    if wrapper_ports:
        port_lines = []
        for index, port in enumerate(wrapper_ports):
            direction = port.get("direction", "")
            width = port.get("width", "")
            port_name = port.get("name", "")
            decl = " ".join(filter(None, (direction, port.get("type", ""), width,
                                          port_name, port.get("dimension", ""))))
            trailing = "," if index < len(wrapper_ports) - 1 else ""
            port_lines.append(f"    {decl}{trailing}")
        module_decl = f"module {wrapper_module_name}{parameter_declaration}(\n" + "\n".join(port_lines) + "\n);"
    else:
        module_decl = f"module {wrapper_module_name}{parameter_declaration}();"

    logic_decl_block = ""
    if internal_logic_decls:
        logic_lines = []
        emitted_logic_names: Set[str] = set()
        for decl in internal_logic_decls:
            width = decl.get("width", "")
            signal_name = decl.get("name", "")
            if not signal_name or signal_name in emitted_logic_names or signal_name in wrapper_port_seen:
                continue
            emitted_logic_names.add(signal_name)
            ptype = re.sub(r"\b(?:wire|reg|logic|tri)\b", "", decl.get("type", "")).strip()
            logic_lines.append("    " + " ".join(filter(None, ("wire", ptype, width,
                                signal_name, decl.get("dimension", "")))) + ";")
        logic_decl_block = "\n".join(logic_lines)

    param_connections = ""
    if param_names:
        param_connections = " #(\n" + ",\n".join(f"        .{name}({name})" for name in param_names) + "\n    )"
    if instance_conns:
        max_pin_len = max((len(conn["pin"]) for conn in instance_conns), default=0)
        max_expr_len = max((len(conn["expr"]) for conn in instance_conns), default=0)
        instance_lines = []
        for index, conn in enumerate(instance_conns):
            pin_name = conn["pin"].ljust(max_pin_len)
            expr = conn["expr"].ljust(max_expr_len)
            direction = conn["direction"]
            trailing = "," if index < len(instance_conns) - 1 else ""
            # Empty expr means floating pin: .pin()
            instance_lines.append(f"        .{pin_name} ({expr}){trailing} // {direction}")
        instance_block = (
            f"    {subsystem_module_name}{param_connections} u_pcie_ctrl (\n"
            + "\n".join(instance_lines)
            + "\n    );  // .pin() = floating/unconnected, .pin(expr) = connected"
        )
    else:
        instance_block = f"    {subsystem_module_name}{param_connections} u_pcie_ctrl ();"

    content_sections = [module_decl]
    if logic_decl_block:
        content_sections.append(logic_decl_block)
    if aliases:
        content_sections.append("\n".join(dict.fromkeys(aliases)))
    content_sections.append(instance_block)
    content = "\n\n".join(content_sections) + "\n\nendmodule"
    wrapper_file.write_text(content + "\n", encoding=ENCODING)
    return wrapper_file


def read_subsystem_append_block() -> Optional[str]:
    append_file = _find_config_file(DBI_MAP_SV)
    if not append_file.is_file():
        return None
    text = append_file.read_text(encoding=ENCODING).rstrip()
    return text or None


def _source_module_bounds(text: str, path: Path) -> Tuple[int, int]:
    """Locate the selected module's header end and endmodule in source text."""
    tokens = tokenize(text)
    closing = matching_delimiters(tokens)
    headers = list(module_headers(tokens))
    if not headers:
        raise ValueError(f"No module found in {path}")
    _, name_idx = next((h for h in headers if tokens[h[1]].group() == path.stem), headers[0])
    cursor = name_idx + 1
    while cursor < len(tokens):
        if cursor in closing:
            cursor = closing[cursor] + 1
        elif tokens[cursor].group() == ";":
            break
        else:
            cursor += 1
    if cursor >= len(tokens):
        raise ValueError(f"Cannot locate module header end in {path}")
    body_start = tokens[cursor].end()
    depth = 1
    for token in tokens[cursor + 1:]:
        if token.group() == "module":
            depth += 1
        elif token.group() == "endmodule":
            depth -= 1
            if depth == 0:
                return body_start, token.start()
    raise ValueError(f"Cannot locate endmodule in {path}")


def append_text_after_first_port_close(rtl_dir: Path, text_to_append: Optional[str]) -> Optional[Path]:
    if not text_to_append:
        return None
    subsystem_file = rtl_dir / EXAMPLES_DIR / PCIE_IIP_SUBSYSTEM_SV
    if not subsystem_file.is_file():
        return None
    text = subsystem_file.read_text(encoding=ENCODING)
    pos, module_end = _source_module_bounds(text, subsystem_file)
    if text_to_append in text[pos:module_end]:
        return subsystem_file
    line_end = text.find("\n", pos)
    tail = text[pos:line_end if line_end >= 0 else len(text)]
    if not tail.strip() or tail.lstrip().startswith("//"):
        pos = line_end + 1 if line_end >= 0 else len(text)
    if text[pos:pos + 2] == "\r\n":
        pos += 2
    elif text[pos:pos + 1] == "\n":
        pos += 1
    separator = "" if text[:pos].endswith("\n") else "\n"
    new_text = text[:pos] + separator + text_to_append.rstrip("\n") + "\n" + text[pos:]
    subsystem_file.write_text(new_text.rstrip("\n") + "\n", encoding=ENCODING)
    return subsystem_file


def extract_pcie_ram_port_from_rams_file(rtl_dir: Path) -> Optional[str]:
    rams_file = rtl_dir / EXAMPLES_DIR / PCIE_IIP_RAMS_SV
    if not rams_file.is_file():
        return None
    result = []
    for port in read_interface_from_file(rams_file, auto_select=True)["ports"]:
        name = port["name"]
        if port["direction"] == "input" and "clk" in name:
            continue
        # Preserve signedness and both packed/unpacked dimensions, while
        # replacing the port direction/net type with exactly one wire keyword.
        signed = "signed" if re.search(r"\bsigned\b", port.get("type", "")) else ""
        decl = " ".join(filter(None, ("wire", signed, port.get("width", ""),
                                      name, port.get("dimension", ""))))
        result.append(decl + ";")
    return "\n".join(result) if result else None


def append_pcie_ram_port_to_subsystem_file(rtl_dir: Path, pcie_ram_port: Optional[str]) -> Optional[Path]:
    """Append extracted pcie_ram_port block after the first ');' in subsystem file."""
    return append_text_after_first_port_close(rtl_dir, pcie_ram_port)


def extract_signal_names_from_pcie_ram_port(pcie_ram_port: Optional[str]) -> List[str]:
    """Extract signal names from transformed pcie_ram_port declarations."""
    if not pcie_ram_port:
        return []

    signal_names: List[str] = []
    for line in pcie_ram_port.splitlines():
        match = re.match(r"^\s*wire\b(?:\s+(?:signed|unsigned))?(?:\s*\[[^\]]+\])*\s+"
                         r"([A-Za-z_][A-Za-z0-9_$]*)(?:\s*\[[^\]]+\])*\s*;", line)
        if match:
            signal_names.append(match.group(1))
    return signal_names


def delete_pcie_ram_signal_lines_from_subsystem_file(rtl_dir: Path, signal_names: List[str]) -> Optional[Path]:
    if not signal_names:
        return None
    subsystem_file = rtl_dir / EXAMPLES_DIR / PCIE_IIP_SUBSYSTEM_SV
    if not subsystem_file.is_file():
        return None
    patterns = [re.compile(rf"\b{re.escape(n)}\b") for n in signal_names]
    _DECL_KW = re.compile(r"^\s*(?:wire|input|output|inout|logic|reg|tri|wand|wor)\b")
    lines = subsystem_file.read_text(encoding=ENCODING).splitlines()
    kept = [
        l for l in lines
        if not (_DECL_KW.match(l) and any(p.search(l) for p in patterns))
    ]
    if kept != lines:
        subsystem_file.write_text("\n".join(kept) + "\n", encoding=ENCODING)
    return subsystem_file


def extract_pcie_ram_inst_from_device_file(rtl_dir: Path, module_prefix: str) -> Optional[str]:
    device_file = rtl_dir / EXAMPLES_DIR / PCIE_IIP_DEVICE_SV
    if not device_file.is_file():
        return None
    text = device_file.read_text(encoding=ENCODING)
    tokens = tokenize(text)
    closing = matching_delimiters(tokens)
    for declaration in instance_declarations(text, tokens, closing, IDENTIFIER.fullmatch):
        for instance in declaration["instances"]:
            if instance["name"] != "external_rams":
                continue
            name_start = instance["name_start"]
            prefix = text[declaration["type_end"]:declaration["instances"][0]["name_start"]]
            # Find this instance's connection end using the same token offsets.
            name_idx = next(i for i, token in enumerate(tokens) if token.start() == name_start)
            port_idx = name_idx + 1
            while port_idx in closing and tokens[port_idx].group() == "[":
                port_idx = closing[port_idx] + 1
            end = tokens[closing[port_idx]].end()
            suffix = text[name_start + len(instance["name"]):end]
            return f"{build_module_prefix(module_prefix)}pcie_ram{prefix}u_pcie_ram{suffix};"
    return None


def append_pcie_ram_inst_to_subsystem_file(rtl_dir: Path, pcie_ram_inst: Optional[str]) -> Optional[Path]:
    if not pcie_ram_inst:
        return None
    subsystem_file = rtl_dir / EXAMPLES_DIR / PCIE_IIP_SUBSYSTEM_SV
    if not subsystem_file.is_file():
        return None
    text = subsystem_file.read_text(encoding=ENCODING)
    body_start, pos = _source_module_bounds(text, subsystem_file)
    if pcie_ram_inst in text[body_start:pos]:
        return subsystem_file
    new_text = text[:pos].rstrip("\n") + f"\n{pcie_ram_inst}\n" + text[pos:]
    subsystem_file.write_text(new_text.rstrip("\n") + "\n", encoding=ENCODING)
    return subsystem_file


def _resolve_scratch_header_name(default_name: str, use_vh: bool) -> str:
    """Resolve scratch header path using either .svh or .vh suffix."""
    header_name = str(Path(default_name).with_suffix(".vh")) if use_vh else default_name
    return f"{SCRATCH_DIR}/{header_name}"


def write_rtl_flist(rtl_dir: Path, include_scratch: bool) -> Path:
    """Write rtl/flist.f using the required line-by-line layout."""
    flist_file = rtl_dir / FLIST_F
    lines = [
        f"+incdir+{SRC_DIR}",
        f"-F {SRC_DIR}/{DWC_PCIE_CTL_LST}",
        f"-F {MEM_DIR}/{FLIST_F}",
        f"-F {EXAMPLES_DIR}/{COMPILE_F}",
    ]
    if include_scratch:
        scratch_dir = rtl_dir / SCRATCH_DIR
        def resolve_header(name: str) -> str:
            for use_vh in (False, True):
                relative = _resolve_scratch_header_name(name, use_vh)
                if (rtl_dir / relative).is_file():
                    return relative
            raise FileNotFoundError(f"missing scratch header: {scratch_dir / name} (or .vh)")
        lines.insert(3, resolve_header(DWC_PCIE_CTL_UNPREFIX_SVH))
        lines.append(resolve_header(DWC_PCIE_CTL_UNDEF_SVH))
    lines.append(f"{TOP_DIR}/{PCIE_CTRL_WRAPPER_SV}")
    flist_file.write_text("\n".join(lines) + "\n", encoding=ENCODING)
    return flist_file


def validate_ramgen_outputs(result: dict) -> None:
    """Ensure ramgen returned the expected output files."""
    expected_paths = [
        result.get("excel_path"),
        result.get("raminfo_csv_path"),
        result.get("output_sv_path"),
        result.get("flist_path"),
        result.get("tb_flist_path"),
        result.get("makefile_path"),
    ]
    missing = [path for path in expected_paths if not path or not Path(path).exists()]
    if missing:
        raise RuntimeError("ramgen completed but expected outputs are missing: {}".format(", ".join(missing)))


def validate_required_inputs(project_root: Path, rule_path: Path) -> None:
    """Validate all required input files/directories before any copy or generation."""
    ensure_source_dirs(project_root, ("examples", "src"))

    required_files = [
        project_root / EXAMPLES_DIR / PCIE_IIP_RAMS_SV,
        project_root / EXAMPLES_DIR / PCIE_IIP_SUBSYSTEM_SV,
        project_root / EXAMPLES_DIR / PCIE_IIP_DEVICE_SV,
        project_root / EXAMPLES_DIR / COMPILE_F,
        project_root / SRC_DIR / DWC_PCIE_CTL_LST,
        project_root / SRC_DIR / CDM_PL_REG_SV,
        project_root / SRC_DIR / CDM_SV,
        project_root / SRC_DIR / DWC_PCIE_CORE_SV,
        project_root / REPORT_HTML,
        rule_path,
    ]

    missing = [str(path) for path in required_files if not path.is_file()]

    ctl_candidates = sorted((project_root / SRC_DIR).rglob(f"*{DWC_PCIE_CTL_PATTERN}.sv"))
    if not ctl_candidates:
        missing.append(f"{project_root / SRC_DIR}/**/*{DWC_PCIE_CTL_PATTERN}.sv")

    if missing:
        raise FileNotFoundError("missing required input files:\n  - " + "\n  - ".join(missing))


def resolve_rule_path(rule_csv_path: Optional[Path]) -> Path:
    """Resolve rule path from CLI argument or default script-local rule.csv."""
    return rule_csv_path if rule_csv_path else _find_config_file(RULE_CSV)


def step_validate_inputs(project_root: Path, rule_path: Path) -> None:
    """Step 1: validate required inputs before any generation starts."""
    validate_required_inputs(project_root, rule_path)


def step_prepare_workspace_and_prefix(
    project_root: Path,
    rtl_dir: Path,
    mem_dir: Path,
    log_detail: Callable[[str], None],
) -> Dict[str, Dict[str, object]]:
    """Step 2: copy sources into rtl workspace and detect module_prefix."""
    rtl_sv_file = rtl_dir / EXAMPLES_DIR / PCIE_IIP_RAMS_SV
    rtl_dir.mkdir(parents=True, exist_ok=True)
    mem_dir.mkdir(parents=True, exist_ok=True)

    copied_dirs: Dict[str, str] = {}
    log_detail("copy examples -> rtl/examples")
    log_detail("copy src -> rtl/src")
    for source_name in ("examples", "src"):
        copied_dirs[source_name] = str(copy_tree_into_rtl(project_root, rtl_dir, source_name))

    if not rtl_sv_file.is_file():
        raise FileNotFoundError("missing copied input SV file: {}".format(rtl_sv_file))

    module_prefix = find_module_prefix(rtl_dir)
    log_detail("detected module_prefix: {}".format(module_prefix if module_prefix else "(none)"))
    print("module_prefix={}".format(module_prefix if module_prefix else "(none)"), flush=True)

    copied_scratch = False
    if module_prefix:
        ensure_source_dirs(project_root, ("scratch",))
        log_detail("module_prefix is non-empty, copy scratch headers -> rtl/scratch")
        copied_dirs["scratch"] = str(copy_scratch_svh_into_rtl(project_root, rtl_dir))
        copied_scratch = True

    return {
        "inputs": {
            "rtl_sv_file": rtl_sv_file,
        },
        "meta": {
            "module_prefix": module_prefix,
            "copied_scratch": copied_scratch,
        },
        "artifacts": {
            "copied_dirs": copied_dirs,
        },
    }


def step_run_ramgen(rtl_sv_file: Path, mem_dir: Path, module_prefix: str) -> dict:
    """Step 3: execute ramgen and validate generated outputs."""
    ramgen_result = ramgen(
        sv_file=str(rtl_sv_file),
        output_dir=str(mem_dir),
        module_prefix=module_prefix,
        verbose=False,
    )
    validate_ramgen_outputs(ramgen_result)
    return ramgen_result


def step_process_text_files(
    rtl_dir: Path,
    module_prefix: str,
    copied_scratch: bool,
    log_detail: Callable[[str], None],
) -> Dict[str, Dict[str, Optional[Path]]]:
    """Step 4: perform all text rewrites and append operations, then regenerate flist."""
    log_detail("rewrite rtl/src/DWC_pcie_ctl.lst: normalize src paths and comment undef include")
    rewritten_list_file = rewrite_dwc_pcie_ctl_list(rtl_dir)
    log_detail("rewrite rtl/examples/compile.f: normalize example paths and comment ram/device entries")
    rewritten_compile_file = rewrite_examples_compile_file(rtl_dir)

    log_detail("rewrite rtl/examples/pcie_iip_subsystem.sv: macro replacement, DBI rename, and PHY line comments")
    rewritten_subsystem_file = rewrite_pcie_iip_subsystem_file(rtl_dir, module_prefix)
    log_detail("edit rtl/examples/pcie_iip_subsystem.sv: remove p_hdrq_depth/p_dataq_depth/pclkx2 lines")
    delete_subsystem_param_lines(rtl_dir)

    log_detail("extract rtl/examples/pcie_iip_rams.sv ports and append transformed wire declarations to subsystem")
    pcie_ram_port = extract_pcie_ram_port_from_rams_file(rtl_dir)
    pcie_ram_signal_names = extract_signal_names_from_pcie_ram_port(pcie_ram_port)
    deleted_pcie_ram_signal_lines_file = delete_pcie_ram_signal_lines_from_subsystem_file(rtl_dir, pcie_ram_signal_names)
    appended_pcie_ram_port_file = append_pcie_ram_port_to_subsystem_file(rtl_dir, pcie_ram_port)

    log_detail("append local dbi-map.sv text block after subsystem module port close")
    dbi_map_text = read_subsystem_append_block()
    if dbi_map_text:
        if module_prefix:
            dbi_map_text = dbi_map_text.replace("PREFIX", module_prefix)
        else:
            dbi_map_text = dbi_map_text.replace("PREFIX_", "")
    appended_dbi_map_file = append_text_after_first_port_close(rtl_dir, dbi_map_text)

    log_detail("extract pcie_ram instance from rtl/examples/pcie_iip_device.sv and append into subsystem")
    pcie_ram_inst = extract_pcie_ram_inst_from_device_file(rtl_dir, module_prefix)
    appended_pcie_ram_inst_file = append_pcie_ram_inst_to_subsystem_file(rtl_dir, pcie_ram_inst)

    log_detail("rewrite rtl/src/Cdm/cdm_pl_reg.sv: replace key expressions and append CDM ports")
    rewritten_cdm_pl_reg_file = rewrite_cdm_pl_reg_file(rtl_dir)
    log_detail("rewrite rtl/src/Cdm/cdm.sv: append CDM ports and u_cdm_pl_reg pins")
    rewritten_cdm_file = rewrite_cdm_file(rtl_dir)
    log_detail("rewrite rtl/src/products/DWC_pcie_core.sv: append CDM ports and u_cdm pins")
    rewritten_dwc_pcie_core_file = rewrite_dwc_pcie_core_file(rtl_dir)
    log_detail("rewrite DWC_pcie_ctl and subsystem instances: append CDM ports/pins")
    append_cdm_to_dwc_pcie_ctl_file(rtl_dir)
    append_cdm_to_subsystem_file(rtl_dir)

    log_detail("generate rtl/flist.f")
    rtl_flist_file = write_rtl_flist(rtl_dir, include_scratch=copied_scratch)

    return {
        "artifacts": {
            "rewritten_list_file": rewritten_list_file,
            "rewritten_compile_file": rewritten_compile_file,
            "rewritten_subsystem_file": rewritten_subsystem_file,
            "deleted_pcie_ram_signal_lines_file": deleted_pcie_ram_signal_lines_file,
            "appended_pcie_ram_port_file": appended_pcie_ram_port_file,
            "appended_dbi_map_file": appended_dbi_map_file,
            "appended_pcie_ram_inst_file": appended_pcie_ram_inst_file,
            "rewritten_cdm_pl_reg_file": rewritten_cdm_pl_reg_file,
            "rewritten_cdm_file": rewritten_cdm_file,
            "rewritten_dwc_pcie_core_file": rewritten_dwc_pcie_core_file,
            "rtl_flist_file": rtl_flist_file,
        },
    }


def step_generate_wrapper(rtl_dir: Path, module_prefix: str, rule_path: Path) -> Optional[Path]:
    """Step 5: generate wrapper according to rule file."""
    return generate_pcie_ctrl_wrapper_file(rtl_dir, module_prefix, rule_csv_path=rule_path)


def to_optional_path_string(path_value: Optional[Path]) -> Optional[str]:
    """Convert Optional[Path] to Optional[str] for stable JSON-like output."""
    return str(path_value) if path_value else None


def build_run_result(
    project_root: Path,
    rtl_dir: Path,
    mem_dir: Path,
    copied_dirs: Dict[str, str],
    module_prefix: str,
    step4_artifacts: Dict[str, Optional[Path]],
    generated_wrapper_file: Optional[Path],
    ramgen_result: dict,
) -> dict:
    """Build final run() return payload in one place."""
    optional_path_fields = [
        "rewritten_list_file",
        "rewritten_compile_file",
        "deleted_pcie_ram_signal_lines_file",
        "appended_pcie_ram_port_file",
        "appended_dbi_map_file",
        "appended_pcie_ram_inst_file",
        "rewritten_subsystem_file",
        "rewritten_cdm_pl_reg_file",
        "rewritten_cdm_file",
        "rewritten_dwc_pcie_core_file",
    ]

    result = {
        "project_root": str(project_root),
        "rtl_dir": str(rtl_dir),
        "mem_dir": str(mem_dir),
        "copied_dirs": copied_dirs,
        "module_prefix": module_prefix,
        "generated_wrapper_file": to_optional_path_string(generated_wrapper_file),
        "rtl_flist_file": str(step4_artifacts["rtl_flist_file"]),
        "ramgen": ramgen_result,
    }

    for field_name in optional_path_fields:
        result[field_name] = to_optional_path_string(step4_artifacts.get(field_name))
    return result


def run(rule_csv_path: Optional[Path] = None) -> dict:
    """Create rtl workspace content and run ramgen."""
    total_steps = 5

    def log_step(step_no: int, message: str) -> None:
        print("[{}/{}] {} ... ".format(step_no, total_steps, message), end="", flush=True)

    def log_ok() -> None:
        print("OK", flush=True)

    def log_detail(message: str) -> None:
        print("    - {}".format(message), flush=True)

    log_step(1, "validate required input files")
    paths = build_paths()
    project_root = paths["project_root"]
    rtl_dir = paths["rtl_dir"]
    mem_dir = paths["mem_dir"]
    rule_path = resolve_rule_path(rule_csv_path).resolve()

    step_validate_inputs(project_root, rule_path)
    log_ok()

    log_step(2, "copy sources, build rtl workspace, and detect module prefix")
    step2_result = step_prepare_workspace_and_prefix(project_root, rtl_dir, mem_dir, log_detail)
    step2_inputs = step2_result["inputs"]
    step2_meta = step2_result["meta"]
    step2_artifacts = step2_result["artifacts"]
    rtl_sv_file = step2_inputs["rtl_sv_file"]
    copied_dirs = step2_artifacts["copied_dirs"]
    module_prefix = step2_meta["module_prefix"]
    copied_scratch = bool(step2_meta["copied_scratch"])
    log_ok()

    log_step(3, "run ramgen")
    ramgen_result = step_run_ramgen(rtl_sv_file, mem_dir, module_prefix)
    log_ok()

    log_step(4, "text processing: keyword replacements and port/pin append")
    step4_result = step_process_text_files(rtl_dir, module_prefix, copied_scratch, log_detail)
    step4_artifacts = step4_result["artifacts"]
    log_ok()

    log_step(5, "generate wrapper from rule.csv")
    generated_wrapper_file = step_generate_wrapper(rtl_dir, module_prefix, rule_path)
    if generated_wrapper_file is None:
        raise RuntimeError("failed to generate PCIe wrapper; subsystem interface could not be analyzed")
    log_ok()

    return build_run_result(
        project_root=project_root,
        rtl_dir=rtl_dir,
        mem_dir=mem_dir,
        copied_dirs=copied_dirs,
        module_prefix=module_prefix,
        step4_artifacts=step4_artifacts,
        generated_wrapper_file=generated_wrapper_file,
        ramgen_result=ramgen_result,
    )


def main() -> int:
    """CLI entry point."""
    parser = argparse.ArgumentParser(description="Prepare PCIe generation workspace and invoke ramgen.")
    parser.add_argument(
        "--rule",
        type=str,
        default=None,
        help="Path to wrapper rule file (default: pciegen/rule.csv beside this script)",
    )
    args = parser.parse_args()

    rule_csv_path = Path(args.rule).expanduser().resolve() if args.rule else None

    try:
        result = run(rule_csv_path=rule_csv_path)
    except PermissionError as exc:
        print(f"Error: permission denied: {exc}\ntip: work in a directory you own with write permission", file=sys.stderr)
        return 1
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    print(f"✓ Prepared RTL workspace: {result['rtl_dir']}")
    print(f"✓ Generated RAM outputs: {result['mem_dir']}")
    module_prefix = result["module_prefix"] if result["module_prefix"] else "(none)"
    print(f"✓ Detected module prefix: {module_prefix}")
    print(f"✓ Generated flist: {result['rtl_flist_file']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
