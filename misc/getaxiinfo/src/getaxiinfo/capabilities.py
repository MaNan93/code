"""Parse PCI and PCIe Extended Capability linked lists and base addresses."""

from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from .macros import NumericResolver, parse_defines


# Standard PCI Capabilities (0x00 - 0xFF, 8-bit ID)
PCI_STD_CAPS: Dict[int, Tuple[str, str]] = {
    0x01: ("PM", "Power Management"),
    0x02: ("AGP", "Accelerated Graphics Port"),
    0x03: ("VPD", "Vital Product Data"),
    0x04: ("SLOT", "Slot Identification"),
    0x05: ("MSI", "Message Signaled Interrupts"),
    0x06: ("CHSWP", "CompactPCI HotSwap"),
    0x07: ("PCIX", "PCI-X"),
    0x08: ("HT", "HyperTransport"),
    0x09: ("VNDR", "Vendor Specific"),
    0x0A: ("DBG", "Debug Port"),
    0x0B: ("CCRC", "CompactPCI Central Resource Control"),
    0x0C: ("HOTPLUG", "PCI Hot-Plug"),
    0x0D: ("SSVID", "Bridge Subsystem Vendor/Device ID"),
    0x0E: ("AGP8X", "AGP 8x"),
    0x0F: ("SECDEV", "Secure Device"),
    0x10: ("PCIE", "PCI Express"),
    0x11: ("MSIX", "MSI-X"),
    0x12: ("SATA", "SATA Configuration"),
    0x13: ("AF", "Advanced Features"),
    0x14: ("EA", "Enhanced Allocation"),
}

TAG_TO_STD_CAP: Dict[str, int] = {
    "PM": 0x01, "AGP": 0x02, "VPD": 0x03, "SLOT": 0x04, "MSI": 0x05,
    "PCIE": 0x10, "MSIX": 0x11, "SATA": 0x12, "AF": 0x13, "EA": 0x14,
}

# PCIe Extended Capabilities (0x100 - 0xFFF, 16-bit ID)
PCIE_EXT_CAPS: Dict[int, Tuple[str, str]] = {
    0x0001: ("AER", "Advanced Error Reporting"),
    0x0002: ("VC", "Virtual Channel"),
    0x0003: ("DSN", "Device Serial Number"),
    0x0004: ("PB", "Power Budgeting"),
    0x0005: ("RCLINK", "Root Complex Link Declaration"),
    0x0006: ("RCILC", "Root Complex Internal Link Control"),
    0x0007: ("RCEC", "Root Complex Event Collector Association"),
    0x0008: ("MFVC", "Multi-Function Virtual Channel"),
    0x0009: ("VC9", "Virtual Channel 9"),
    0x000A: ("RCRB", "RCRB Header"),
    0x000B: ("VSEC", "Vendor-Specific Extended Capability"),
    0x000C: ("CAC", "Configuration Access Correlation"),
    0x000D: ("ACS", "Access Control Services"),
    0x000E: ("ARI", "Alternative Routing-ID Interpretation"),
    0x000F: ("ATS", "Address Translation Services"),
    0x0010: ("SRIOV", "Single Root I/O Virtualization"),
    0x0011: ("MRIOV", "Multi-Root I/O Virtualization"),
    0x0012: ("MCAST", "Multicast"),
    0x0013: ("PRI", "Page Request Interface"),
    0x0015: ("RBAR", "Resizable BAR"),
    0x0016: ("DPA", "Dynamic Power Allocation"),
    0x0017: ("TPH", "TPH Requester"),
    0x0018: ("LTR", "Latency Tolerance Reporting"),
    0x0019: ("SPCIE", "Secondary PCI Express"),
    0x001A: ("PMUX", "Protocol Multiplexing"),
    0x001B: ("PASID", "Process Address Space ID"),
    0x001C: ("LN", "Lightweight Notification"),
    0x001D: ("DPC", "Downstream Port Containment"),
    0x001E: ("L1SUB", "L1 PM Substates"),
    0x001F: ("PTM", "Precision Time Measurement"),
    0x0020: ("MPCIE", "PCI Express over M-PHY"),
    0x0021: ("FRSQ", "FRS Queueing"),
    0x0022: ("RTR", "Readiness Time Reporting"),
    0x0023: ("DVSEC", "Designated Vendor-Specific"),
    0x0024: ("VF_RBAR", "VF Resizable BAR"),
    0x0025: ("DLINK", "Data Link Feature"),
    0x0026: ("PL16G", "Physical Layer 16.0 GT/s"),
    0x0027: ("MARGIN", "Lane Margining at Receiver"),
    0x0028: ("HIER", "Hierarchy ID"),
    0x0029: ("NPEM", "Native PCIe Enclosure Management"),
    0x002A: ("PL32G", "Physical Layer 32.0 GT/s"),
    0x002B: ("AP", "Alternate Protocol"),
    0x002C: ("SFI", "System Firmware Intermediary"),
    0x002D: ("SHADOW", "Shadow Functions"),
    0x002E: ("DOE", "Data Object Exchange"),
    0x002F: ("DEV3", "Device 3"),
    0x0030: ("IDE", "Integrity and Data Encryption"),
    0x0031: ("PL64G", "Physical Layer 64.0 GT/s"),
    0x0032: ("FLIT_LOGGING", "Flit Logging"),
    0x0033: ("FLIT_PERF", "Flit Performance Measurement"),
    0x0034: ("FLIT_ERR_INJ", "Flit Error Injection"),
    0x0035: ("PL128G", "Physical Layer 128.0 GT/s"),
}

TAG_TO_EXT_CAP: Dict[str, int] = {
    "AER": 0x0001, "VC": 0x0002, "SN": 0x0003, "DSN": 0x0003, "PB": 0x0004,
    "VSEC": 0x000B, "PTM_VSEC": 0x000B, "VSECDMA": 0x000B, "VSECRAS": 0x000B,
    "ACS": 0x000D, "ARI": 0x000E, "ATS": 0x000F, "SRIOV": 0x0010,
    "PRS": 0x0013, "PRI": 0x0013, "RBAR": 0x0015, "DPA": 0x0016, "TPH": 0x0017,
    "LTR": 0x0018, "SPCIE": 0x0019, "PASID": 0x001B, "LN": 0x001C,
    "DPC": 0x001D, "L1SUB": 0x001E, "PTM": 0x001F, "MPCIE": 0x0020,
    "FRSQ": 0x0021, "RTR": 0x0022, "DVSEC": 0x0023, "RAS_DES": 0x0023,
    "CCIX_TP": 0x0023, "CXS": 0x0023, "RMEDA_DVSEC": 0x0023, "UCIE_DVSEC": 0x0023,
    "VF_RBAR": 0x0024, "DLINK": 0x0025, "PL16G": 0x0026, "MARGIN": 0x0027,
    "NPEM": 0x0029, "PL32G": 0x002A, "DEV3": 0x002F, "IDE": 0x0030,
    "PL64G": 0x0031, "FLIT_LOGGING": 0x0032, "FLIT_PERFORMANCE_MEASUREMENT": 0x0033,
    "FLIT_ERROR_INJECTION": 0x0034, "PL128G": 0x0035, "IDE_DOE": 0x002E,
}

TAG_SIZE_KEYS: Dict[str, Tuple[str, ...]] = {
    "PM": ("PM_CAP_SIZE",), "MSI": ("MSI_CAP_SIZE",), "PCIE": ("PCIE_CAP_SIZE",),
    "MSIX": ("MSIX_CAP_SIZE",), "SLOT": ("SLOT_CAP_SIZE",), "VPD": ("VPD_CAP_SIZE",),
    "SATA": ("SATA_CAP_SIZE",), "AER": ("AER_SIZE",), "VC": ("VC_SIZE",),
    "SN": ("SERIAL_CAP_SIZE",), "PB": ("PB_SIZE",), "ARI": ("ARI_SIZE",),
    "SPCIE": ("SPCIE_SIZE",), "PL16G": ("PL16G_SIZE",), "MARGIN": ("MARGIN_SIZE",),
    "PL32G": ("PL32G_SIZE",), "PL64G": ("PL64G_SIZE",), "SRIOV": ("SRIOV_SIZE",),
    "ATS": ("ATS_SIZE",), "PRS": ("PRS_SIZE",), "LTR": ("LTR_SIZE",),
    "L1SUB": ("L1SUB_SIZE",), "PASID": ("PASID_SIZE",), "DPA": ("DPA_SIZE",),
    "DPC": ("DPC_SIZE",), "LN": ("LN_SIZE",), "MPCIE": ("MPCIE_SIZE",),
    "RTR": ("RTR_SIZE",), "PTM": ("PTM_SIZE",), "PTM_VSEC": ("PTM_VSEC_SIZE",),
    "CCIX_TP": ("CCIX_TP_SIZE",), "CXS": ("CXS_CAP_SIZE",), "VSECDMA": ("VSECDMA_SIZE",),
    "FRSQ": ("FRSQ_SIZE",), "RAS_DES": ("RAS_DES_SIZE",), "VSECRAS": ("VSECRAS_SIZE",),
    "DLINK": ("DLINK_SIZE",), "RBAR": ("RBAR_SIZE",), "VF_RBAR": ("VF_RBAR_SIZE",),
    "FLIT_LOGGING": ("FLIT_LOGGING_SIZE",),
}

# Standard capability fallback mappings from cc_constants.svh
STD_CAP_FALLBACKS = (
    ("PM", "CFG_PM_CAP", "PM_CAP_SIZE"),
    ("MSI", "CFG_MSI_CAP", "MSI_CAP_SIZE"),
    ("PCIE", "CFG_PCIE_CAP", "PCIE_CAP_SIZE"),
    ("MSIX", "CFG_MSIX_CAP", "MSIX_CAP_SIZE"),
    ("SLOT", "CFG_SLOT_CAP", "SLOT_CAP_SIZE"),
    ("VPD", "CFG_VPD_CAP", "VPD_CAP_SIZE"),
    ("SATA", "CFG_SATA_CAP", "SATA_CAP_SIZE"),
)


def _detect_prefix(definitions: Dict[str, Any]) -> str:
    for k in definitions:
        if k.endswith("CFG_PTR") or k.endswith("CFG_NEXT_PTR_0"):
            cand = k[:-len("CFG_PTR")] if k.endswith("CFG_PTR") else k[:-len("CFG_NEXT_PTR_0")]
            if cand.endswith("CXL_") or cand.endswith("VF_") or cand.endswith("EXT_VF_"):
                continue
            return cand
    for k in definitions:
        if k.endswith("CFG_PM_CAP"):
            return k[:-len("CFG_PM_CAP")]
    return ""


def parse_capability_chain(
    definitions: Dict[str, Any],
    is_ext: bool = False,
    scope: str = "PF0",
    prefix: Optional[str] = None,
) -> List[Tuple[str, str, str, str, str, str, str, str]]:
    """Traverse a single capability linked list in configuration space."""
    resolver = NumericResolver(definitions)
    raw_defs = getattr(definitions, "definitions", definitions)
    if prefix is None:
        prefix = _detect_prefix(raw_defs)

    if not is_ext:
        start_macro = prefix + ("VF_CFG_NEXT_PTR" if scope == "VF" else "CFG_NEXT_PTR_0")
        fallback = prefix + "CFG_NEXT_PTR"
    else:
        start_macro = prefix + ("VF_BASE_NEXT_PTR" if scope == "VF" else "BASE_NEXT_PTR_0")
        fallback = prefix + "BASE_NEXT_PTR"

    curr_offset = resolver.number(start_macro)
    if curr_offset is None and fallback:
        curr_offset = resolver.number(fallback)

    table_rows = []
    visited = set()
    while curr_offset and curr_offset not in visited:
        visited.add(curr_offset)
        candidates = []
        for k, raw in raw_defs.items():
            if not k.startswith(prefix):
                continue
            rem = k[len(prefix):]
            if not rem.endswith("_PTR") or rem.endswith("_NEXT_PTR"):
                continue
            base_name = rem[:-4]
            if base_name in ("CFG", "BASE") or base_name.startswith("CXL_"):
                continue
            if scope == "VF":
                if not base_name.startswith("VF_"):
                    continue
                cap_tag = base_name[3:]
            else:
                if base_name.startswith("VF_") or base_name.startswith("EXT_VF_") or base_name.startswith("DM_RP_"):
                    continue
                cap_tag = base_name

            if cap_tag in ("BASE", "CFG"):
                continue

            val = resolver.number(k)
            if val == curr_offset:
                candidates.append((base_name, cap_tag))

        chosen_tag = None
        chosen_base = None
        next_ptr = None

        for base_name, cap_tag in candidates:
            nxt = resolver.number(prefix + base_name + "_NEXT_PTR_0")
            if nxt is None:
                nxt = resolver.number(prefix + base_name + "_NEXT_PTR")
            if nxt is not None:
                if chosen_tag is None or (next_ptr == 0 and nxt != 0):
                    chosen_tag = cap_tag
                    chosen_base = base_name
                    next_ptr = nxt

        if chosen_tag is None and candidates:
            chosen_tag = candidates[0][1]
            chosen_base = candidates[0][0]
            next_ptr = 0

        # Disambiguate shared terminal address (e.g. 0x2F8/0x2F0 in DWC)
        if len(candidates) > 1 and next_ptr == 0:
            tags = [c[1] for c in candidates]
            if "VSECDMA" in tags and (
                raw_defs.get(prefix + "CC_DMA_ENABLE") in ("1", "1'h1") or
                "CC_VSECDMA_MAP_VERSION" in raw_defs or "VSECDMA_SIZE" in raw_defs
            ):
                chosen_tag = "VSECDMA"

        if chosen_tag is None:
            break

        if not is_ext:
            cap_id_val = TAG_TO_STD_CAP.get(chosen_tag)
            cap_id_str = "0x{:02X}".format(cap_id_val) if cap_id_val is not None else "Unknown"
            desc = PCI_STD_CAPS.get(cap_id_val, (chosen_tag, chosen_tag))[1]
            offset_str = "0x{:02X}".format(curr_offset)
            next_str = "0x{:02X}".format(next_ptr) if next_ptr else "0x00"
        else:
            cap_id_val = TAG_TO_EXT_CAP.get(chosen_tag)
            cap_id_str = "0x{:04X}".format(cap_id_val) if cap_id_val is not None else "Unknown"
            desc = PCIE_EXT_CAPS.get(cap_id_val, (chosen_tag, chosen_tag))[1]
            offset_str = "0x{:03X}".format(curr_offset)
            next_str = "0x{:03X}".format(next_ptr) if next_ptr else "0x000"

        size_str = "N/A"
        size_keys = TAG_SIZE_KEYS.get(chosen_tag, ("{}_SIZE".format(chosen_tag), "{}_CAP_SIZE".format(chosen_tag)))
        for sk in size_keys:
            s_val = resolver.number(prefix + sk) or resolver.number(sk)
            if s_val is not None and s_val > 0:
                size_str = "{} B (0x{:X})".format(s_val, s_val)
                break

        table_rows.append((
            scope,
            "PCIe Extended" if is_ext else "PCI Standard",
            offset_str,
            next_str,
            cap_id_str,
            chosen_tag,
            desc,
            size_str
        ))
        curr_offset = next_ptr

    return table_rows


def parse_capability_chains(
    definitions: Dict[str, Any],
    sriov_enabled: Optional[int] = None,
) -> Tuple[List[Tuple[str, str]], List[Tuple[str, ...]], List[str]]:
    """Parse all applicable capability chains (PF0, VF) from definitions.

    Returns (fields, rows, notes).
    """
    raw_defs = getattr(definitions, "definitions", definitions)
    prefix = _detect_prefix(raw_defs)
    resolver = NumericResolver(raw_defs)

    has_linked_list = any(
        (k.startswith(prefix) and ("_NEXT_PTR" in k or k.endswith("CFG_PTR")))
        for k in raw_defs
    )

    rows: List[Tuple[str, ...]] = []
    notes: List[str] = []

    if sriov_enabled is None:
        sriov_val = resolver.number(prefix + "CX_SRIOV_ENABLE")
        if sriov_val is None:
            sriov_val = resolver.number("CX_SRIOV_ENABLE")
        mode_val = resolver.number(prefix + "CC_DEVICE_TYPE")
        if mode_val is None:
            mode_val = resolver.number("CC_DEVICE_TYPE")
        sriov_enabled = 1 if (sriov_val == 1 and mode_val not in (1, 3)) else 0

    nvfunc = resolver.number(prefix + "CX_NVFUNC")
    if nvfunc is None:
        nvfunc = resolver.number("CX_NVFUNC")
    vf_active = (sriov_enabled == 1) and (nvfunc is None or nvfunc > 0)

    if has_linked_list:
        rows.extend(parse_capability_chain(raw_defs, is_ext=False, scope="PF0", prefix=prefix))
        rows.extend(parse_capability_chain(raw_defs, is_ext=True, scope="PF0", prefix=prefix))

        if vf_active:
            vf_cfg_start = resolver.number(prefix + "VF_CFG_NEXT_PTR")
            if vf_cfg_start is not None:
                rows.extend(parse_capability_chain(raw_defs, is_ext=False, scope="VF", prefix=prefix))
            vf_base_start = resolver.number(prefix + "VF_BASE_NEXT_PTR")
            if vf_base_start is not None:
                rows.extend(parse_capability_chain(raw_defs, is_ext=True, scope="VF", prefix=prefix))
    else:
        # Fallback: check cc_constants.svh direct CFG_*_CAP macros
        found_std = []
        for tag, cap_key, size_key in STD_CAP_FALLBACKS:
            offset = resolver.number(prefix + cap_key) or resolver.number(cap_key)
            if offset is not None and offset > 0:
                size_val = resolver.number(prefix + size_key) or resolver.number(size_key)
                size_str = "{} B (0x{:X})".format(size_val, size_val) if size_val else "N/A"
                cap_id_val = TAG_TO_STD_CAP.get(tag)
                cap_id_str = "0x{:02X}".format(cap_id_val) if cap_id_val is not None else "Unknown"
                desc = PCI_STD_CAPS.get(cap_id_val, (tag, tag))[1]
                found_std.append((offset, tag, desc, cap_id_str, size_str))

        found_std.sort(key=lambda item: item[0])
        for i, (offset, tag, desc, cap_id_str, size_str) in enumerate(found_std):
            next_str = "0x{:02X}".format(found_std[i + 1][0]) if i + 1 < len(found_std) else "0x00"
            rows.append((
                "PF0",
                "PCI Standard",
                "0x{:02X}".format(offset),
                next_str,
                cap_id_str,
                tag,
                desc,
                size_str,
            ))

        if not has_linked_list and not rows:
            notes.append("Capability linked list configuration file (cap_port_cfg.svh) not found.")
        elif not has_linked_list:
            notes.append("Standard capabilities derived from constants; PCIe extended capability linked list requires cap_port_cfg.svh.")

    pf_std_cnt = sum(1 for r in rows if r[0] == "PF0" and r[1] == "PCI Standard")
    pf_ext_cnt = sum(1 for r in rows if r[0] == "PF0" and r[1] == "PCIe Extended")
    vf_std_cnt = sum(1 for r in rows if r[0] == "VF" and r[1] == "PCI Standard")
    vf_ext_cnt = sum(1 for r in rows if r[0] == "VF" and r[1] == "PCIe Extended")

    std_summary = "{} (PF0)".format(pf_std_cnt) + (", {} (VF)".format(vf_std_cnt) if vf_std_cnt else "")
    ext_summary = "{} (PF0)".format(pf_ext_cnt) + (", {} (VF)".format(vf_ext_cnt) if vf_ext_cnt else "")

    fields = [
        ("Standard Capabilities", std_summary if pf_std_cnt or vf_std_cnt else "0"),
        ("Extended Capabilities", ext_summary if pf_ext_cnt or vf_ext_cnt else "0"),
    ]
    return fields, rows, notes
