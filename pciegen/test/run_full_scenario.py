"""Run all five stages with the real sibling ramgen in an isolated workspace."""

import contextlib
import io
import json
import os
import shutil
import tempfile
from pathlib import Path

from run_no_ramgen_scenario import _build_minimal_workspace, _load_pciegen_module


def run_scenario():
    pciegen = _load_pciegen_module(Path(__file__).resolve().parents[2], stub_ramgen=False)
    from vutils.vparser import VeribleParser

    with tempfile.TemporaryDirectory(prefix="pciegen_full_") as temp:
        root = Path(temp)
        initial_rtl = _build_minimal_workspace(root)
        for source in ("src", "examples"):
            shutil.copytree(initial_rtl / source, root / source)
        # Exercise real memory analysis/reference-module generation.
        rams = root / "examples/pcie_iip_rams.sv"
        rams.write_text("""module pcie_iip_rams(
    input clk,
    input [7:0] ram_in,
    output [7:0] ram_out
);
pcie_ram_wrapper #(.WD(8), .PW(4), .DP(16), .RD_LATENCY(1)) u_mem (
    .clk(clk), .en(1'b1), .we(1'b0), .addr(4'b0), .din(ram_in), .dout(ram_out)
);
endmodule
""", encoding="utf-8")
        scratch = root / "scratch"
        scratch.mkdir()
        for name in ("DWC_pcie_ctl_unprefix.svh", "DWC_pcie_ctl_undef.vh"):
            (scratch / name).write_text("", encoding="utf-8")
        previous_cwd = Path.cwd()
        try:
            os.chdir(root)
            with contextlib.redirect_stdout(io.StringIO()):
                result = pciegen.run(root / "rule.csv")
        finally:
            os.chdir(previous_cwd)
        assert result["module_prefix"] == "my"
        assert result["ramgen"]["report"]["instance_count"] == 1
        assert len(result["ramgen"]["wrapper_files"]) == 1
        for key in ("generated_wrapper_file", "rtl_flist_file"):
            assert Path(result[key]).is_file(), key
        sv_files = sorted((root / "rtl").rglob("*.sv"))
        parsed = VeribleParser().parse_files([str(path) for path in sv_files], {"gen_tree": False})
        errors = {path: data.errors for path, data in parsed.items() if data.errors}
        assert not errors, errors
        print(json.dumps({"passed": True, "real_ramgen": True, "generated_ram_wrappers": 1,
                          "rtl_files_syntax_checked": len(sv_files)}, indent=2))


if __name__ == "__main__":
    run_scenario()
