#!/usr/bin/env python3
"""Run a no-ramgen integration scenario for pciegen.

This builds a temporary rtl tree, runs step4/step5 directly, and asserts
that rtl edits + wrapper generation behave as expected.
"""

from __future__ import annotations

import importlib.util
import json
import shutil
import sys
import tempfile
import types
from pathlib import Path


def _load_pciegen_module(repo_root: Path):
    if "ramgen" not in sys.modules:
        ramgen_stub = types.ModuleType("ramgen")
        ramgen_stub.ramgen = lambda **_: {}
        sys.modules["ramgen"] = ramgen_stub

    pciegen_path = repo_root / "pciegen" / "pciegen.py"
    spec = importlib.util.spec_from_file_location("pciegen_module", pciegen_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load module from {pciegen_path}")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def _build_minimal_workspace(work_root: Path) -> Path:
    rtl_dir = work_root / "rtl"

    _write(
        rtl_dir / "examples" / "pcie_iip_subsystem.sv",
        """module pcie_iip_subsystem #(
    parameter PW = 4
) (
    input wire [PW-1:0] a,
    input wire b,
    output wire [`W-1:0] c
);
parameter p_hdrq_depth = 8;
parameter p_dataq_depth = 8;
parameter pclkx2 = 1;
my_DWC_pcie_ctl u_pcie_core (
    .a(a),
    .b(b),
    .c(c)
);
endmodule
""",
    )

    _write(
        rtl_dir / "examples" / "pcie_iip_rams.sv",
        """module pcie_iip_rams(
    input clk,
    input [7:0] ram_in,
    output [7:0] ram_out
);
endmodule
""",
    )

    _write(
        rtl_dir / "examples" / "pcie_iip_device.sv",
        """module pcie_iip_device();
foo external_rams (
    .a(sig_a),
    .b(sig_b)
);
endmodule
""",
    )

    _write(
        rtl_dir / "examples" / "compile.f",
        """../examples/pcie_iip_subsystem.sv
../examples/pcie_iip_rams.sv
../examples/pcie_iip_device.sv
../examples/rams/compile.f
""",
    )

    _write(
        rtl_dir / "src" / "DWC_pcie_ctl.lst",
        """../src/my_DWC_pcie_ctl.sv
../src/DWC_pcie_ctl-undef.v
""",
    )

    _write(
        rtl_dir / "src" / "my_DWC_pcie_ctl.sv",
        """module my_DWC_pcie_ctl(
    a,
    b,
    c
);
input [3:0] a;
input b;
output [7:0] c;
DWC_pcie_core u_DWC_pcie_core (
    .a(a),
    .b(b),
    .c(c)
);
endmodule
""",
    )

    _write(
        rtl_dir / "src" / "Cdm" / "cdm_pl_reg.sv",
        """module cdm_pl_reg(
    clk
);
input clk;
wire x = (write_pulse && pl_reg_16[7]);
wire y = (phy_type && pl_reg_18[5:0]);
endmodule
""",
    )

    _write(
        rtl_dir / "src" / "Cdm" / "cdm.sv",
        """module cdm(
    clk
);
input clk;
cdm_pl_reg u_cdm_pl_reg (
    .clk(clk)
);
endmodule
""",
    )

    _write(
        rtl_dir / "src" / "products" / "DWC_pcie_core.sv",
        """module DWC_pcie_core(
    a,
    b,
    c
);
input [3:0] a;
input b;
output [7:0] c;
cdm u_cdm (
    .clk(b)
);
endmodule
""",
    )

    _write(
        work_root / "report" / "IO.html",
        """<p></a>a[1:0]</p>
<p></a>b</p>
<p></a>c[3:0]</p>
""",
    )

    _write(
        work_root / "rule.csv",
        """name,pin,port
a,a_bus,a_wrap
b,1'b0,nc
c,-,-
""",
    )

    return rtl_dir


def _assert_contains(text: str, expected: str, label: str, failures: list[str]) -> None:
    if expected not in text:
        failures.append(f"{label}: missing '{expected}'")


def run_scenario() -> int:
    script_path = Path(__file__).resolve()
    repo_root = script_path.parents[2]
    pciegen = _load_pciegen_module(repo_root)

    temp_root = Path(tempfile.mkdtemp(prefix="pciegen_no_ramgen_"))
    try:
        rtl_dir = _build_minimal_workspace(temp_root)
        module_prefix = "my"
        rule_path = temp_root / "rule.csv"

        result: dict[str, object] = {
            "workspace": str(temp_root),
            "errors": [],
            "warnings": [],
            "checks": {},
        }

        failures: list[str] = []

        step4 = pciegen.step_process_text_files(
            rtl_dir,
            module_prefix,
            copied_scratch=False,
            log_detail=lambda _: None,
        )
        result["step4_ok"] = True
        result["step4_artifacts"] = {
            k: (str(v) if v else None) for k, v in step4.get("artifacts", {}).items()
        }

        cdm_pl_reg_text = (rtl_dir / "src" / "Cdm" / "cdm_pl_reg.sv").read_text(encoding="utf-8")
        _assert_contains(cdm_pl_reg_text, "sys_fast_link_mode", "cdm_pl_reg replacement", failures)
        _assert_contains(cdm_pl_reg_text, "sys_link_capable", "cdm_pl_reg replacement", failures)

        cdm_text = (rtl_dir / "src" / "Cdm" / "cdm.sv").read_text(encoding="utf-8")
        _assert_contains(cdm_text, ".sys_fast_link_mode(sys_fast_link_mode)", "cdm add_inst_port", failures)
        _assert_contains(cdm_text, "input sys_fast_link_mode", "cdm add_port", failures)

        core_text = (rtl_dir / "src" / "products" / "DWC_pcie_core.sv").read_text(encoding="utf-8")
        _assert_contains(core_text, ".sys_link_capable(sys_link_capable)", "core add_inst_port", failures)

        analyzed = pciegen.analyze_pcie_iip_subsystem_interface(rtl_dir)
        result["analyze_subsystem"] = analyzed
        if analyzed is None:
            failures.append("analyze_pcie_iip_subsystem_interface returned None")

        wrapper_path = pciegen.step_generate_wrapper(rtl_dir, module_prefix, rule_path)
        result["wrapper_file"] = str(wrapper_path) if wrapper_path else None
        if wrapper_path is None:
            failures.append("wrapper generation returned None")
        else:
            wrapper_text = wrapper_path.read_text(encoding="utf-8")
            # Width override from IO.html should replace parameter/macro widths.
            _assert_contains(wrapper_text, "input [1:0] a_wrap", "wrapper width override for a", failures)
            _assert_contains(wrapper_text, "output [3:0] c", "wrapper width override for c", failures)
            # Rule mapping: pin value replacement in instance connection.
            _assert_contains(wrapper_text, ".a", "rule pin remap for a", failures)
            _assert_contains(wrapper_text, "(a_bus", "rule pin remap for a", failures)
            _assert_contains(wrapper_text, ".b", "rule constant mapping for b", failures)
            _assert_contains(wrapper_text, "(1'b0", "rule constant mapping for b", failures)

        result["checks"]["passed"] = len(failures) == 0
        result["checks"]["failures"] = failures
        if failures:
            result["errors"].extend(failures)

        print(json.dumps(result, indent=2, ensure_ascii=False))
        return 0 if not failures else 2
    except Exception as exc:
        payload = {"workspace": str(temp_root), "errors": [f"scenario crashed: {exc}"]}
        print(json.dumps(payload, indent=2, ensure_ascii=False))
        return 3
    finally:
        shutil.rmtree(temp_root, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(run_scenario())
