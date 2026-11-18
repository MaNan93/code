"""Build the configuration summary; capacity labels retain their resource scope."""

from .capabilities import parse_capability_chains
from .macros import INDEXED_BASES, NumericResolver


PCIE_GEN_RATE_GTPS = {1: 2.5, 2: 5.0, 3: 8.0, 4: 16.0, 5: 32.0, 6: 64.0, 7: 128.0}
UNKNOWN = "Unknown"
NA = "N/A"


def _and(*flags):
    if 0 in flags:
        return 0
    return 1 if all(flag == 1 for flag in flags) else None


def _status(flag):
    return {0: "Disabled", 1: "Enabled"}.get(flag, UNKNOWN)


def _fmt(value):
    return UNKNOWN if value is None else str(value)


def _hex(value):
    return UNKNOWN if value is None else "0x{:08X}".format(value)


class Summary:
    def __init__(self, values):
        self.values = values
        self.resolver = NumericResolver(values)
        self.sections = []
        self.notes = []
        self.trace = []

    def note(self, message):
        if message not in self.notes:
            self.notes.append(message)

    def num(self, *names, **options):
        minimum = options.get("minimum", 0)
        for name in names:
            # An alias is a fallback for an absent macro, never for an invalid one.
            if self.values.get(name) is not None:
                value = self.resolver.number(name)
                if value is not None and value < minimum:
                    self.note("{}: value must be >= {}".format(name, minimum))
                    return None
                return value
        return self.resolver.number(names[0])

    def flag(self, *names):
        value = self.num(*names)
        if value not in (None, 0, 1):
            self.note("{}: expected 0 or 1, got {}".format(names[0], value))
            return None
        return value

    def section(self, title, fields=(), headers=(), rows=()):
        self.sections.append((title, list(fields), tuple(headers), list(rows)))

    def gated(self, flag, value):
        return NA if flag == 0 else _fmt(value) if flag == 1 else UNKNOWN

    def indices(self, count):
        if count is not None and 1 <= count <= 1024:
            return list(range(count))
        indices = set()
        for name in self.values:
            for base in INDEXED_BASES:
                if name.startswith(base + "_"):
                    indices.add(int(name[len(base) + 1:]))
        return sorted(indices)

    def basic(self):
        mode = self.num("CC_DEVICE_TYPE")
        names = {0: "EP", 1: "RP", 2: "DM", 3: "SW", 99: "NOT_SET"}
        roles = {0: "EP", 1: "RP", 2: "EP, RP", 3: "Upstream / Downstream Switch Port"}
        gen = self.num("CX_MAX_PCIE_SPEED", minimum=1)
        rate = PCIE_GEN_RATE_GTPS.get(gen)
        speed = "Gen{} ({} GT/s)".format(gen, rate) if rate is not None else UNKNOWN
        if gen is not None and rate is None:
            self.note("CX_MAX_PCIE_SPEED: unsupported generation {}".format(gen))
        lanes = self.num("CX_NL", minimum=1)
        pf = self.num("CX_NFUNC", minimum=1) if mode not in (1, 3) else None
        sriov = self.flag("CX_SRIOV_ENABLE") if mode not in (1, 3) else 0
        vf = self.num("CX_NVFUNC") if sriov == 1 else None
        if mode in (1, 3):
            self.note("PF/VF counts describe the EP role; they are N/A for this controller type.")
        self.section("PCIE", [
            ("Controller Type", names.get(mode, UNKNOWN)),
            ("Supported Roles", roles.get(mode, UNKNOWN)),
            ("Max Link Width", "x{}".format(lanes) if lanes is not None else UNKNOWN),
            ("Max Link Speed", speed),
            ("Max Payload Supported", self.with_unit(self.num("CX_MAX_MTU", minimum=1), "bytes")),
            ("PF Count", NA if mode in (1, 3) else _fmt(pf)),
            ("SR-IOV", _status(sriov)),
            ("VF Count", "0" if sriov == 0 else self.gated(sriov, vf)),
        ])
        indices = self.indices(pf) if mode not in (1, 3) else []
        rows = []
        for index in indices:
            count = self.num("CX_MAX_VF_{}".format(index)) if sriov == 1 else None
            rows.append(("PF{}".format(index), "0" if sriov == 0 else self.gated(sriov, count)))
        self.section("FUNCTIONS", headers=("Function", "Supported VFs"), rows=rows)
        return indices, sriov

    @staticmethod
    def with_unit(value, unit):
        return UNKNOWN if value is None else "{} {}".format(value, unit)

    def axi(self):
        protocol = self.num("AMBA_INTERFACE")
        populated = self.flag("AXI_POPULATED") if self.values.get("AXI_POPULATED") is not None else 1
        axi = _and(1 if protocol in (2, 3, 4) else 0 if protocol == 0 else None, populated)
        manager = _and(axi, self.flag("MASTER_POPULATED"))
        subordinate = _and(axi, self.flag("SLAVE_POPULATED"))
        shared = self.flag("SHARED_DBI_ENABLED") if axi != 0 else 0
        dedicated = _and(axi, self.flag("DBI_4SLAVE_POPULATED"), 0 if shared == 1 else 1)
        rows = []
        for name, enabled, clk_key, addr_keys, data_keys, id_key, burst_key, diff_key in (
            ("AXI DMA", manager, "AXI_MSTR_CLK_FREQ", ("MASTER_BUS_ADDR_WIDTH",),
             ("MASTER_BUS_DATA_WIDTH",), "CC_MSTR_BUS_ID_WIDTH", "CC_MSTR_BURST_LEN", "MSTR_CLK_DIFF_ENABLE"),
            ("AXI Slave", subordinate, "AXI_SLV_CLK_FREQ", ("SLAVE_BUS_ADDR_WIDTH",),
             ("SLAVE_BUS_DATA_WIDTH",), "CC_SLV_BUS_ID_WIDTH", "CC_SLV_BURST_LEN", "SLV_CLK_DIFF_ENABLE"),
            ("AXI CFG", dedicated, "DBI_SLV_CLK_FREQ", ("CC_DBI_SLV_BUS_ADDR_WIDTH",),
             ("CC_DBI_SLV_BUS_DATA_WIDTH",), "CC_DBI_SLV_ID_WD", None, None),
        ):
            if enabled == 0:
                rows.append((name, "Disabled") + (NA,) * 7)
                continue
            diff = self.flag(diff_key) if diff_key else None
            clk = self.num(clk_key, minimum=1) if not diff_key or diff == 1 else None
            if diff_key and diff == 0:
                self.note("{} clock is synchronous to core; its operating MHz depends on core clock configuration.".format(name))
            addr, data = self.num(*addr_keys, minimum=1), self.num(*data_keys, minimum=1)
            if name == "AXI DMA" and (addr is None or data is None):
                # CC_* widths can include RAS protection bits. Only use them when RAS is explicitly off.
                if self.flag("CX_RAS_EN") == 0:
                    addr = addr if addr is not None else self.num("CC_MSTR_BUS_ADDR_WIDTH", minimum=1)
                    data = data if data is not None else self.num("CC_MSTR_BUS_DATA_WIDTH", minimum=1)
            burst = self.with_unit(self.num(burst_key, minimum=1), "beats") if burst_key else "Single"
            bandwidth = "{:.3f}".format(clk * data / 8000.0) if clk and data else UNKNOWN
            rows.append((name, _status(enabled), _fmt(clk), _fmt(addr), _fmt(data),
                         _fmt(self.num(id_key, minimum=1)), burst, bandwidth,
                         {0: "Sync", 1: "Async"}.get(diff, UNKNOWN)))
        self.section("AXI", [
            ("Protocol", {0: "None", 2: "AXI3", 3: "AXI4", 4: "AXI5"}.get(protocol, UNKNOWN)),
            ("AXI CFG Access", "Shared AXI Slave" if shared == 1 else "Dedicated" if dedicated == 1 else "Disabled" if dedicated == 0 and shared == 0 else UNKNOWN),
        ], ("Interface", "Status", "MHz", "Addr bits", "Data bits", "ID bits", "Max Burst", "Peak GB/s", "Clock Mode"), rows)
        if axi != 0:
            self.note("AXI Peak GB/s uses payload width and assumes one beat/cycle per read or write data channel.")
        return manager, subordinate, dedicated

    def outstanding(self, manager, subordinate, dedicated):
        rows = []
        capabilities = {
            name: (NA, NA) if enabled == 0 else (UNKNOWN, UNKNOWN)
            for name, enabled in (("AXI DMA", manager), ("AXI Slave", subordinate), ("AXI CFG", dedicated))
        }
        np_limit = self.num("CC_MAX_MSTR_TAGS_AXI", minimum=1) if manager != 0 else None
        dma_read = np_limit - 1 if np_limit is not None else None
        queue_name = "CC_WR_CH_P_REQ_QUEUE_DP" if self.values.get("CC_WR_CH_P_REQ_QUEUE_DP") is not None else "WR_CH_P_REQ_QUEUE_DP"
        dma_write = self.num("CC_WR_CH_P_REQ_QUEUE_DP", "WR_CH_P_REQ_QUEUE_DP") if manager != 0 else None
        slave_read = self.num("CC_MAX_SLV_TAG", minimum=1) if subordinate != 0 else None
        slave_write = self.num("CC_SLV_NUM_OUTSTND_WR_REQ") if subordinate != 0 else None
        estimates = (
            ("AXI DMA", manager, "Read", dma_read, "CC_MAX_MSTR_TAGS_AXI", "CC_MAX_MSTR_TAGS_AXI - 1"),
            ("AXI DMA", manager, "Write", dma_write, queue_name, queue_name),
            ("AXI Slave", subordinate, "Read", slave_read, "CC_MAX_SLV_TAG", "CC_MAX_SLV_TAG"),
            ("AXI Slave", subordinate, "Write", slave_write, "CC_SLV_NUM_OUTSTND_WR_REQ", "CC_SLV_NUM_OUTSTND_WR_REQ"),
        )
        for interface, enabled, direction, value, macro, formula in estimates:
            self.out_row(rows, enabled, interface, direction, "Empirical estimate", value, formula)
            self.trace.append((interface + " " + direction + " Outstanding", macro,
                               formula + " (project empirical formula)", self.gated(enabled, value)))
        capabilities["AXI DMA"] = (self.gated(manager, dma_read), self.gated(manager, dma_write))
        capabilities["AXI Slave"] = (self.gated(subordinate, slave_read), self.gated(subordinate, slave_write))
        if dedicated != 0:
            self.out_row(rows, dedicated, "AXI CFG", "Read", "Single", None, "No empirical formula; Single does not establish outstanding count")
            self.out_row(rows, dedicated, "AXI CFG", "Write", "Single", None, "No empirical formula; Single does not establish outstanding count")
        self.note("AXI Read/Write Outstanding values are project empirical estimates, not guaranteed independent protocol limits.")
        if manager != 0:
            self.note("AXI DMA NP reads/writes share the configured tracking pool ({}); the write estimate uses Posted queue depth.".format(_fmt(np_limit)))
            if self.values.get("RADM_MAX_OUTSTD_P_REQ") is not None:
                self.note("AXI DMA Posted tracking capacity: {}. Tracking capacity and queue depth are distinct resources.".format(_fmt(self.num("RADM_MAX_OUTSTD_P_REQ"))))
            if self.values.get("CC_HP_MASTER") is not None and self.flag("CC_HP_MASTER") == 1:
                high = self.num("CC_MAX_MSTRH_TAGS_AXI", minimum=1)
                low = np_limit - high if np_limit is not None and high is not None and np_limit > high else None
                self.note("AXI DMA NP pool partitions: HP={}, LP={}.".format(_fmt(high), _fmt(low)))
        if subordinate != 0:
            self.note("AXI Slave NP reads/writes share application tags ({}); the write estimate uses the configured NP write buffer. Posted-write total is not inferred.".format(_fmt(slave_read)))
        total = self.num("CX_MAX_TAG")
        total = total + 1 if total is not None else None
        dma = self.flag("CC_DMA_ENABLE")
        reserved = self.num("CC_NUM_DMA_RD_TAG") if dma == 1 else 0 if dma == 0 else None
        remaining = total - reserved if total is not None and reserved is not None and total >= reserved else None
        self.section("OUTSTANDING", [
            ("Basis", "Project empirical formulas"),
            ("PCIe Tag Pool", _fmt(total)), ("DMA Reserved Tags", _fmt(reserved)),
            ("Non-DMA Tags", _fmt(remaining)),
        ], ("Interface", "Direction", "Resource", "Limit", "Scope / Condition"), rows)
        return capabilities

    def out_row(self, rows, enabled, interface, direction, resource, value, scope):
        rows.append((interface, direction, resource, self.gated(enabled, value), scope))

    def dma(self):
        enabled = self.flag("CC_DMA_ENABLE")
        hdma = self.flag("CX_DMA_PF_ENABLE") if enabled != 0 or self.values.get("CX_DMA_PF_ENABLE") is not None else None
        invalid = enabled == 0 and hdma == 1
        if invalid:
            self.note("Invalid DMA configuration: CX_DMA_PF_ENABLE=1 requires CC_DMA_ENABLE=1.")
        engine = NA if enabled == 0 else "HDMA" if enabled == 1 and hdma == 1 else "Legacy DMA" if enabled == 1 and hdma == 0 else UNKNOWN
        legacy = self.flag("CC_LEGACY_DMA_MAP") if enabled == 1 and hdma == 1 else None
        fields = [("Status", "Invalid" if invalid else _status(enabled)), ("Engine", engine),
                  ("Legacy DMA Map", _status(legacy) if enabled == 1 and hdma == 1 else NA if enabled == 0 or hdma == 0 else UNKNOWN)]
        for label, macro, gate in (
            ("Read Channels", "CC_NUM_DMA_RD_CHAN", enabled),
            ("Write Channels", "CC_NUM_DMA_WR_CHAN", enabled),
            ("Read Tags", "CC_NUM_DMA_RD_TAG", enabled),
            ("Read Prefetch Depth", "CX_DMA_RD_LLQ", _and(enabled, hdma)),
            ("Write Prefetch Depth", "CX_DMA_WR_LLQ", _and(enabled, hdma)),
        ):
            fields.append((label, self.gated(gate, self.num(macro, minimum=1) if gate == 1 else None)))
        self.section("EMBEDDED_DMA", fields)
        return enabled

    def mapping(self, dma):
        atu = self.flag("CX_INTERNAL_ATU_ENABLE")
        self.section("IATU", [
            ("Status", _status(atu)),
            ("Inbound Regions", self.gated(atu, self.num("CX_ATU_NUM_INBOUND_REGIONS") if atu == 1 else None)),
            ("Outbound Regions", self.gated(atu, self.num("CX_ATU_NUM_OUTBOUND_REGIONS") if atu == 1 else None)),
        ])
        unroll = self.flag("CC_UNROLL_ENABLE", "CC_UNROLL_EN")
        rows = []
        for block, present, enable_key, offset_key in (
            ("DMA", dma, "ENABLE_MEM_MAP_UNROLL_DMA_REG", "UNROLL_DMA_OFFSET_BAR"),
            ("iATU", atu, "ENABLE_MEM_MAP_UNROLL_ATU_REG", "UNROLL_ATU_OFFSET_BAR"),
        ):
            mapped = self.flag(enable_key) if present != 0 else 0
            if mapped == 1 and unroll == 0:
                self.note("{}: BAR mapping enabled but unroll space is disabled.".format(block))
                mapped = None
            if present == 0:
                rows.append((block, "Disabled", NA, NA, NA))
            elif mapped == 0:
                rows.append((block, "Not mapped", NA, NA, NA))
            elif mapped == 1 and present == 1:
                pf = self.num("UNROLL_FUNC_NUM")
                bar = self.bar(self.num("UNROLL_BAR_NUM"))
                rows.append((block, "Enabled", "PF{}".format(pf) if pf is not None else UNKNOWN, bar, _hex(self.num(offset_key))))
            else:
                rows.append((block, UNKNOWN, UNKNOWN, UNKNOWN, UNKNOWN))
        # Legacy/PL memory mapping is separate from the unroll window.
        pl = self.flag("ENABLE_MEM_MAP_PL_REG") if self.values.get("ENABLE_MEM_MAP_PL_REG") is not None else None
        if pl == 1:
            pf = self.num("PL_FUNC_NUM")
            rows.append(("Port Logic", "Enabled", "PF{}".format(pf) if pf is not None else UNKNOWN,
                         self.bar(self.num("PL_BAR_NUM")), _hex(self.num("PL_OFFSET_BAR"))))
        self.section("REGISTER_MAPPING", [("Unroll Space", _status(unroll))],
                     ("Block", "BAR Mapping", "Function", "BAR", "Byte Offset"), rows)
        if unroll == 0:
            self.note("Unroll space disabled does not establish that a legacy viewport interface exists.")
        if unroll is None:
            self.note("Unroll layout is Unknown; CX_UNROLL_VIEW only selects documentation reports and is not used.")

    def bar(self, number):
        if number is None:
            return UNKNOWN
        if not 0 <= number <= 5:
            self.note("Invalid BAR indicator {}; expected 0..5.".format(number))
            return UNKNOWN
        return "BAR{}".format(number)

    def msix(self, indices, sriov):
        pf_enabled = self.flag("MSIX_CAP_ENABLE")
        vf_enabled = _and(sriov, self.flag("VF_MSIX_CAP_ENABLE")) if sriov != 0 else 0
        rows = []
        for index in indices:
            for prefix, enabled, label in (
                ("MSIX_", pf_enabled, "PF{}".format(index)),
                ("VF_MSIX_", vf_enabled, "VFs under PF{}".format(index)),
            ):
                if enabled == 0:
                    continue
                bar_values = []
                for part in ("TABLE", "PBA"):
                    bir_key = "{}{}_BIR_{}".format(prefix, part, index)
                    offset_key = "{}{}_OFFSET_{}".format(prefix, part, index)
                    bir = self.num(bir_key)
                    offset = self.num(offset_key)
                    if offset is not None and offset > 0x1fffffff:
                        self.note("{}: expected a 29-bit offset field.".format(offset_key))
                        offset = None
                    byte_offset = offset << 3 if offset is not None else None
                    bar_values.extend((self.bar(bir), _hex(byte_offset)))
                    self.trace.append((label + " " + part + " Byte Offset", offset_key, "raw << 3", _hex(byte_offset)))
                rows.append((label, _status(enabled)) + tuple(bar_values))
        self.section("MSIX", [
            ("MSI Capability", _status(self.flag("MSI_CAP_ENABLE"))),
            ("PF Capability", _status(pf_enabled)), ("VF Capability", _status(vf_enabled)),
        ], ("Scope", "Status", "Table BAR", "Table Byte Offset", "PBA BAR", "PBA Byte Offset"), rows)

    def pcie_capabilities(self, sriov):
        fields, rows, notes = parse_capability_chains(self.values, sriov_enabled=sriov)
        self.section("CAPABILITIES", fields,
                     headers=("Scope", "Type", "Base Address", "Next Offset", "Cap ID", "Capability", "Description", "Size"),
                     rows=rows)
        for note in notes:
            self.note(note)

    def build(self):
        indices, sriov = self.basic()
        manager, subordinate, dedicated = self.axi()
        axi_index = len(self.sections) - 1
        capabilities = self.outstanding(manager, subordinate, dedicated)
        title, fields, headers, rows = self.sections[axi_index]
        self.sections[axi_index] = (
            title, fields, headers + ("Read Outstanding", "Write Outstanding"),
            [row + capabilities[row[0]] for row in rows],
        )
        dma = self.dma()
        self.mapping(dma)
        self.msix(indices, sriov)
        self.pcie_capabilities(sriov)
        for name in sorted(self.resolver.errors):
            self.note("{}: {}".format(name, self.resolver.errors[name]))
        return {"sections": self.sections, "notes": self.notes, "trace": self.trace,
                "resolved": self.resolver.cache, "used": self.resolver.used}


def build_analysis(ordered):
    return Summary(ordered).build()


def print_analysis(analysis):
    for index, (title, fields, headers, rows) in enumerate(analysis["sections"]):
        if index:
            print()
        print("[{}]".format(title))
        if fields:
            width = max(len(label) for label, _ in fields)
            for label, value in fields:
                print("{}: {}".format(label.ljust(width + 1), value))
        if headers:
            if fields:
                print()
            if not rows:
                print("No applicable/configured rows.")
            else:
                widths = [max(len(str(row[i])) for row in [headers] + rows) for i in range(len(headers))]
                def line(row):
                    return " | ".join(str(value).ljust(widths[i]) for i, value in enumerate(row)).rstrip()
                print(line(headers))
                print("-+-".join("-" * width for width in widths))
                for row in rows:
                    print(line(row))
    if analysis["notes"]:
        print("\n[NOTES]")
        for note in analysis["notes"]:
            print("- " + note)
