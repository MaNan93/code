"""Register constraints and reserved-field normalization."""
from dataclasses import replace
import re
import warnings

from .diagnostics import ReservedFieldWarning, TableError
from .values import _integer


KEYWORDS = set("""
accept_on alias always always_comb always_ff always_latch and assert assign assume
automatic before begin bind bins binsof bit break buf bufif0 bufif1 byte case casex
casez cell chandle checker class clocking cmos config const constraint context
continue cover covergroup coverpoint cross deassign default defparam design disable
dist do edge else end endcase endchecker endclass endclocking endconfig endfunction
endgenerate endgroup endinterface endmodule endpackage endprimitive endprogram
endproperty endsequence endspecify endtable endtask enum event eventually expect
export extends extern final first_match for force foreach forever fork forkjoin
function generate genvar global highz0 highz1 if iff ifnone ignore_bins illegal_bins
implements implies import incdir include initial inout input inside instance int
integer interconnect interface intersect join join_any join_none large let liblist
library local localparam logic longint macromodule matches medium modport module
nand negedge nettype new nexttime nmos nor noshowcancelled not notif0 notif1 null or
output package packed parameter pmos posedge primitive priority program property
protected pull0 pull1 pulldown pullup pulsestyle_ondetect pulsestyle_onevent pure
rand randc randcase randsequence rcmos real realtime ref reg reject_on release
repeat restrict return rnmos rpmos rtran rtranif0 rtranif1 s_always s_eventually
s_nexttime s_until s_until_with scalared sequence shortint shortreal showcancelled
signed small soft solve specify specparam static string strong strong0 strong1
struct super supply0 supply1 sync_accept_on sync_reject_on table tagged task this
throughout time timeprecision timeunit tran tranif0 tranif1 tri tri0 tri1 triand
trior trireg type typedef union unique unique0 unsigned until until_with untyped use
uwire var vectored virtual void wait wait_order wand weak weak0 weak1 while wildcard
wire with within wor xnor xor
""".split())



INTERNAL_NAMES = {"pclk", "presetn", "psel", "penable", "pwrite", "paddr",
                  "pwdata", "prdata", "pready", "pslverr", "AW",
                  "csr_addr_hit", "csr_write", "csr_read", "csr_data"}



def validate_identifier(name, label="signal"):
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_$]*", name) or name in KEYWORDS:
        raise TableError(f"{label}: invalid Verilog identifier {name!r}")



def validate_aw(aw):
    if isinstance(aw, bool) or not isinstance(aw, int) or not 2 <= aw <= 32:
        raise TableError("aw must be an integer between 2 and 32")



def _normalize_reserved(item, offset):
    if not item.reserved:
        return item
    label = f"row {item.row}, offset 0x{offset:X}, signal {item.name!r}"
    try:
        reset_ok = _integer(item.reset, 16, label + " reset") == 0
    except TableError:
        reset_ok = False
    if not reset_ok or item.access != "ro":
        warnings.warn(
            f"{label}: reserved metadata reset={item.reset!r}, access={item.access!r}; "
            "using reset=0, access=ro (tie0, writes ignored)",
            ReservedFieldWarning, stacklevel=2,
        )
    return replace(item, reset=0, access="ro")



def validate_registers(registers, aw):
    validate_aw(aw)
    if not registers:
        raise TableError("no register fields found")
    offsets = set()
    names = set(INTERNAL_NAMES)
    names.update(f"OFFSET_0x{reg.offset:x}" for reg in registers)
    names.update(f"csr_reg_data_0x{reg.offset:x}" for reg in registers)
    for reg in registers:
        if reg.offset < 0 or reg.offset % 4:
            raise TableError(f"offset 0x{reg.offset:X}: expected a nonnegative, 4-byte aligned address")
        if reg.offset + 3 >= 1 << aw:
            raise TableError(f"offset 0x{reg.offset:X}: exceeds aw={aw}")
        if reg.offset in offsets:
            raise TableError(f"duplicate register offset 0x{reg.offset:X}")
        offsets.add(reg.offset)
        if not reg.fields:
            raise TableError(f"offset 0x{reg.offset:X}: no fields")
        used = 0
        for item in reg.fields:
            item = _normalize_reserved(item, reg.offset)
            label = f"row {item.row}, offset 0x{reg.offset:X}, signal {item.name!r}"
            if not 0 <= item.lsb <= item.msb <= 31:
                raise TableError(f"{label}: bits must satisfy 0 <= lsb <= msb <= 31")
            if item.access not in {"rw", "ro", "rw1c", "rwsc"}:
                raise TableError(f"{label}: unsupported access {item.access!r}; use rw, ro, rw1c, rwsc")
            if not 0 <= item.reset < 1 << item.width:
                raise TableError(f"{label}: reset value 0x{item.reset:X} does not fit {item.width} bits")
            mask = ((1 << item.width) - 1) << item.lsb
            if used & mask:
                raise TableError(f"{label}: overlapping bit fields")
            used |= mask
            if item.reserved:
                continue
            validate_identifier(item.name, label)
            ports = [item.name]
            if item.access == "rw1c":
                ports.append(item.name + "_hwset")
            for name in ports:
                if name in names:
                    raise TableError(f"{label}: duplicate or conflicting port name {name!r}")
                names.add(name)
