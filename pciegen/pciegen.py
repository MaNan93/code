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

from ramgen import ramgen
import sys as _sys, pathlib as _pathlib
_sys.path.insert(0, str(_pathlib.Path(__file__).parent.parent / "vutils" / "src"))
from vutils.vedit import vedit
del _sys, _pathlib
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
    module_name = _resolve_target_module_name(path, inst_name=inst_name)
    return vedit.from_file(path, module_name=module_name)


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
    try:
        editor = _load_editor(path, inst_name=inst_name)
    except Exception as exc:
        _warn(f"skip editing {path}: {exc}")
        return False

    original_text = path.read_text(encoding=ENCODING)

    # Add ports
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
        editor.add_port(port_dict)

    # Add instance-port connections
    if pins and inst_name:
        inst_port_dict = {inst_name: {port: {"wire": wire} for port, wire in pins}}
        editor.add_inst_port(inst_port_dict)

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

    # Pre-apply regex replacements to the file text
    text = cdm_pl_reg_file.read_text(encoding=ENCODING)
    text = re.sub(r"\(write_pulse.*?pl_reg_16\[7\];", "sys_fast_link_mode;", text)
    text = re.sub(r"\(phy_type.*?pl_reg_18\[5:0\];", "sys_link_capable;", text)
    cdm_pl_reg_file.write_text(text, encoding=ENCODING)

    # Add CDM ports via vedit
    try:
        editor = _load_editor(cdm_pl_reg_file)
    except Exception:
        return cdm_pl_reg_file

    editor.add_port({
        "sys_fast_link_mode": {"direction": "input"},
        "sys_link_capable": {"direction": "input", "width": "[5:0]"},
    })

    updated_text = editor.module_text
    if updated_text != text:
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
    """Return module name and ANSI port metadata for rtl/examples/pcie_iip_subsystem.sv."""
    subsystem_file = rtl_dir / EXAMPLES_DIR / PCIE_IIP_SUBSYSTEM_SV
    try:
        target_module_name = _resolve_target_module_name(subsystem_file)
        editor = vedit.from_file(subsystem_file, module_name=target_module_name)
        return {"module_name": editor.module_name, "ports": editor.ports, "style": "ansi"}
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
    """Normalize signal name for dictionary lookup (strip whitespace and lowercase)."""
    return str(value).strip().lower()


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
    ports = subsystem_info.get("ports", [])
    wrapper_file = rtl_dir / TOP_DIR / PCIE_CTRL_WRAPPER_SV
    wrapper_file.parent.mkdir(parents=True, exist_ok=True)

    wrapper_module_name = f"{build_module_prefix(module_prefix)}pcie_ctrl_wrapper"

    # Load HTML width overrides
    report_path = rtl_dir.parent / REPORT_HTML
    html_widths = extract_port_widths_from_report_html(report_path)
    # 统一用归一化后的 key（小写+strip）构建查找表，避免大小写/空白不一致导致匹配失败
    normalized_html_widths = {
        _normalize_signal_name(key): value
        for key, value in html_widths.items()
    }
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
        if name_key in normalized_html_widths:
            width = normalized_html_widths[name_key]
        else:
            if report_path.is_file():
                print(f"warning: port '{raw_name}' not found in {REPORT_HTML}, keeping ANSI width '{ansi_width}'", flush=True)
            width = ansi_width
        analyzed_ports.append({"name": raw_name, "name_key": name_key, "direction": direction, "width": width})

    # Step 3: apply rule.csv to determine wrapper ports and u_pcie_ctrl connections
    rule_path = rule_csv_path if rule_csv_path else _find_config_file(RULE_CSV)
    rules = load_wrapper_rules(rule_path)
    if not rule_path.is_file():
        print(f"warning: {rule_path} not found, using default one-to-one wrapper mapping", flush=True)

    analyzed_names = {port.get("name_key", "") for port in analyzed_ports}
    for rule_name in rules:
        if rule_name not in analyzed_names:
            print(f"warning: rule name '{rule_name}' not found in analyzed subsystem ports", flush=True)

    wrapper_ports: List[Dict[str, str]] = []
    wrapper_port_seen: Set[str] = set()
    internal_logic_decls: List[Dict[str, str]] = []
    internal_logic_seen: Set[str] = set()
    instance_conns: List[Dict[str, str]] = []
    internal_signal_refs: Dict[str, List[str]] = {}  # Track which ports map to same internal signal
    internal_signal_widths: Dict[str, str] = {}

    def is_valid_identifier(s: str) -> bool:
        """Check if string is a valid Verilog identifier."""
        return bool(re.match(r"^[A-Za-z_][A-Za-z0-9_$]*$", s))

    for port in analyzed_ports:
        name = port.get("name", "")
        name_key = port.get("name_key", "")
        direction = port.get("direction", "")
        width = port.get("width", "")
        rule = rules.get(name_key)
        if rule is None:
            pin_value = "-"
            port_value = "-"
        else:
            pin_value = rule.get("pin", "").strip()
            port_value = rule.get("port", "").strip()

        # Validation 1: pin must not be empty
        if not pin_value:
            print(f"error: rule for '{name}' has empty pin (pin column is required)", flush=True)
            continue

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
                        print(f"error: rule for '{name}' has port='-' but pin='{pin_value}' is not a valid Verilog identifier", flush=True)
                        wrapper_port_name = ""
                    else:
                        wrapper_port_name = conn_expr
                else:
                    # port is a specific name
                    if not is_valid_identifier(port_value):
                        print(f"error: rule for '{name}' has port='{port_value}' which is not a valid Verilog identifier", flush=True)
                        wrapper_port_name = ""
                    else:
                        wrapper_port_name = port_value
            else:
                # port is empty, "-", or "nc": expose as name
                wrapper_port_name = name if not is_port_nc else ""

        # Add wrapper port (with deduplication)
        if wrapper_port_name and wrapper_port_name not in wrapper_port_seen:
            wrapper_ports.append({"name": wrapper_port_name, "direction": direction, "width": width})
            wrapper_port_seen.add(wrapper_port_name)

        # Track internal signal references for duplicate detection
        if not wrapper_port_name and conn_expr and is_valid_identifier(conn_expr):
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
            and not wrapper_port_name
            and is_valid_identifier(conn_expr)
            and conn_expr not in wrapper_port_seen
            and conn_expr not in internal_logic_seen
        ):
            internal_logic_decls.append({"name": conn_expr, "width": width})
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
            decl = f"{direction} {width} {port_name}".rstrip() if width else f"{direction} {port_name}"
            trailing = "," if index < len(wrapper_ports) - 1 else ""
            port_lines.append(f"    {decl}{trailing}")
        module_decl = f"module {wrapper_module_name}(\n" + "\n".join(port_lines) + "\n);"
    else:
        module_decl = f"module {wrapper_module_name}();"

    logic_decl_block = ""
    if internal_logic_decls:
        logic_lines = []
        emitted_logic_names: Set[str] = set()
        for decl in internal_logic_decls:
            width = decl.get("width", "")
            signal_name = decl.get("name", "")
            if not signal_name or signal_name in emitted_logic_names:
                continue
            emitted_logic_names.add(signal_name)
            if width:
                logic_lines.append(f"    logic {width} {signal_name};")
            else:
                logic_lines.append(f"    logic {signal_name};")
        logic_decl_block = "\n".join(logic_lines)

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
            f"    {subsystem_module_name} u_pcie_ctrl (\n"
            + "\n".join(instance_lines)
            + "\n    );  // .pin() = floating/unconnected, .pin(expr) = connected"
        )
    else:
        instance_block = f"    {subsystem_module_name} u_pcie_ctrl ();"

    content_sections = [module_decl]
    if logic_decl_block:
        content_sections.append(logic_decl_block)
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


def append_text_after_first_port_close(rtl_dir: Path, text_to_append: Optional[str]) -> Optional[Path]:
    if not text_to_append:
        return None
    subsystem_file = rtl_dir / EXAMPLES_DIR / PCIE_IIP_SUBSYSTEM_SV
    if not subsystem_file.is_file():
        return None
    text = subsystem_file.read_text(encoding=ENCODING)
    if text_to_append in text:
        return subsystem_file
    m = re.search(r"^\s*\);\s*$", text, re.MULTILINE)
    if not m:
        return None
    pos = m.end()
    if text[pos:pos + 2] == "\r\n":
        pos += 2
    elif text[pos:pos + 1] == "\n":
        pos += 1
    new_text = text[:pos] + text_to_append.rstrip("\n") + "\n" + text[pos:]
    subsystem_file.write_text(new_text.rstrip("\n") + "\n", encoding=ENCODING)
    return subsystem_file


def extract_pcie_ram_port_from_rams_file(rtl_dir: Path) -> Optional[str]:
    rams_file = rtl_dir / EXAMPLES_DIR / PCIE_IIP_RAMS_SV
    if not rams_file.is_file():
        return None
    lines = rams_file.read_text(encoding=ENCODING).splitlines()
    result = []
    for line in lines:
        if re.match(r"^\s*(input|output)\b", line) and not re.match(r"^\s*input\b.*clk", line):
            line = re.sub(r"^(\s*)(input|output)\b", r"\1wire", line)
            line = re.sub(r",\s*$", "", line.rstrip())
            if not line.endswith(";"):
                line += ";"
            result.append(line)
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
        match = re.match(r"^\s*(?:wire|input|output)\b(?:\s+\[[^\]]+\])?\s+([A-Za-z_][A-Za-z0-9_$]*)\s*;", line)
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
    m = re.search(
        r"(^\s*[`A-Za-z_][A-Za-z0-9_$`]*\s*(?:#\s*\([\s\S]*?\)\s*)?)(external_rams)(\s*\([\s\S]*?\)\s*;)",
        text, re.MULTILINE,
    )
    return f"{build_module_prefix(module_prefix)}pcie_ram u_pcie_ram{m.group(3)}".rstrip() if m else None


def append_pcie_ram_inst_to_subsystem_file(rtl_dir: Path, pcie_ram_inst: Optional[str]) -> Optional[Path]:
    if not pcie_ram_inst:
        return None
    subsystem_file = rtl_dir / EXAMPLES_DIR / PCIE_IIP_SUBSYSTEM_SV
    if not subsystem_file.is_file():
        return None
    text = subsystem_file.read_text(encoding=ENCODING)
    if pcie_ram_inst in text:
        return subsystem_file
    m = re.search(r"^\s*endmodule\b", text, re.MULTILINE)
    if not m:
        return None
    pos = m.start()
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
        use_vh = scratch_dir.is_dir() and any(scratch_dir.rglob("*.vh"))
        lines.insert(3, _resolve_scratch_header_name(DWC_PCIE_CTL_UNPREFIX_SVH, use_vh))
        lines.append(_resolve_scratch_header_name(DWC_PCIE_CTL_UNDEF_SVH, use_vh))
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