"""Profile the real PCIe pipeline on isolated, scalable synthetic workspaces.

All source generation and cleanup occur outside the measured interval. Every
case runs in a fresh Python process; reported stage times exclude interpreter
startup, fixture creation and post-run correctness checks.
"""

from __future__ import annotations

import argparse
import contextlib
import ctypes
import hashlib
import importlib
import io
import json
import os
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
from collections import defaultdict
from pathlib import Path
from unittest.mock import patch

from run_no_ramgen_scenario import _build_minimal_workspace, _load_pciegen_module


CASES = {
    "baseline": dict(body_lines=100, ports=32, rams=1, extra_files=0, modules=1),
    "body_2000": dict(body_lines=2000, ports=32, rams=1, extra_files=0, modules=1),
    "body_10000": dict(body_lines=10000, ports=32, rams=1, extra_files=0, modules=1),
    "ports_1000": dict(body_lines=100, ports=1000, rams=1, extra_files=0, modules=1),
    "ram_15": dict(body_lines=100, ports=32, rams=15, extra_files=0, modules=1),
    "ram_15_body_2000": dict(body_lines=2000, ports=32, rams=15, extra_files=0, modules=1),
    "ram_15_body_10000": dict(body_lines=10000, ports=32, rams=15, extra_files=0, modules=1),
    "ram_15_files_2000": dict(body_lines=100, ports=32, rams=15, extra_files=2000, modules=1),
    "user_scale_2000": dict(body_lines=2000, ports=32, rams=15, extra_files=0, modules=1, all_sv=True),
    "user_scale_3000": dict(body_lines=3000, ports=32, rams=15, extra_files=0, modules=1, all_sv=True),
    "ram_100": dict(body_lines=100, ports=32, rams=100, extra_files=0, modules=1),
    "ram_500": dict(body_lines=100, ports=32, rams=500, extra_files=0, modules=1),
    "ram_1000": dict(body_lines=100, ports=32, rams=1000, extra_files=0, modules=1),
    "files_2000": dict(body_lines=100, ports=32, rams=1, extra_files=2000, modules=1),
    "files_2000_warm": dict(body_lines=100, ports=32, rams=1, extra_files=2000, modules=1, warm=True),
    "modules_16": dict(body_lines=100, ports=32, rams=1, extra_files=0, modules=16),
    "modules_64": dict(body_lines=100, ports=32, rams=1, extra_files=0, modules=64),
}


def build_workspace(root: Path, options: dict) -> None:
    initial_rtl = _build_minimal_workspace(root)
    for name in ("src", "examples"):
        shutil.copytree(initial_rtl / name, root / name)
    scratch = root / "scratch"
    scratch.mkdir()
    for name in ("DWC_pcie_ctl_unprefix.svh", "DWC_pcie_ctl_undef.vh"):
        (scratch / name).write_text("", encoding="utf-8")
    padding = "".join(f"wire perf_dummy_{i} = 1'b0;\n" for i in range(options["body_lines"]))
    targets = [root / "examples/pcie_iip_subsystem.sv", root / "src/my_DWC_pcie_ctl.sv",
               root / "src/Cdm/cdm_pl_reg.sv", root / "src/Cdm/cdm.sv",
               root / "src/products/DWC_pcie_core.sv"]
    for target in targets:
        text = target.read_text(encoding="utf-8").replace("endmodule", padding + "endmodule")
        if target.name == "pcie_iip_subsystem.sv":
            more_ports = "".join(f"    input wire [7:0] perf_port_{i},\n" for i in range(options["ports"]))
            text = text.replace("    input wire b,", more_ports + "    input wire b,")
        target.write_text(text, encoding="utf-8")
    # A minimal destination already exists; the warm case prepopulates it fully.
    extra = root / "src/perf_extra"
    extra.mkdir()
    for i in range(options["extra_files"]):
        (extra / f"extra_{i}.sv").write_text(f"module extra_{i}; wire a=1'b0; endmodule\n", encoding="utf-8")
    cdm = root / "src/Cdm/cdm.sv"
    if options["modules"] > 1:
        cdm.write_text("".join(
            f"module helper_{i}; wire unused=1'b0; endmodule\n" for i in range(options["modules"] - 1))
            + cdm.read_text(), encoding="utf-8")
    rams = root / "examples/pcie_iip_rams.sv"
    memories = "".join(
        f"pcie_ram_wrapper #(.WD(8), .PW(4), .DP(16), .RD_LATENCY(1)) u_mem_{i} (\n"
        "    .clk(clk), .en(1'b1), .we(1'b0), .addr(4'b0), .din(ram_in), .dout()\n);\n"
        for i in range(options["rams"])
    )
    rams.write_text("module pcie_iip_rams(\ninput clk,\ninput [7:0] ram_in,\noutput [7:0] ram_out\n);\n"
                    + memories + "endmodule\n", encoding="utf-8")
    if options.get("all_sv"):
        # The other five targets already have padding; extend the remaining
        # RAM and device files to match the user's small-file-count workload.
        for target in (rams, root / "examples/pcie_iip_device.sv"):
            target.write_text(target.read_text(encoding="utf-8").replace("endmodule", padding + "endmodule"),
                              encoding="utf-8")
    if options.get("warm"):
        for name in ("src", "examples"):
            shutil.copytree(root / name, root / "rtl" / name, dirs_exist_ok=True)


def peak_working_set_mib():
    if os.name != "nt":
        return None

    class MemoryCounters(ctypes.Structure):
        _fields_ = [("cb", ctypes.c_ulong), ("PageFaultCount", ctypes.c_ulong),
                    ("PeakWorkingSetSize", ctypes.c_size_t), ("WorkingSetSize", ctypes.c_size_t),
                    ("QuotaPeakPagedPoolUsage", ctypes.c_size_t), ("QuotaPagedPoolUsage", ctypes.c_size_t),
                    ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t), ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
                    ("PagefileUsage", ctypes.c_size_t), ("PeakPagefileUsage", ctypes.c_size_t)]

    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.GetCurrentProcess.restype = ctypes.c_void_p
    psapi = ctypes.WinDLL("psapi", use_last_error=True)
    psapi.GetProcessMemoryInfo.argtypes = [ctypes.c_void_p, ctypes.POINTER(MemoryCounters), ctypes.c_ulong]
    info = MemoryCounters()
    info.cb = ctypes.sizeof(info)
    if not psapi.GetProcessMemoryInfo(kernel.GetCurrentProcess(), ctypes.byref(info), info.cb):
        raise ctypes.WinError(ctypes.get_last_error())
    return round(info.PeakWorkingSetSize / 1024**2, 2)


def _read_full_interface_from_file(path, module_name=None, *, auto_select=False):
    """Reference the complete-CST interface reads used before API integration."""
    from vutils.vedit import vedit
    editor = vedit.from_file(path, module_name, auto_select=auto_select)
    return {"module_name": editor.module_name, "name": editor.module_name,
            "ports": editor.ports, "is_ansi": editor.is_ansi,
            "parameter_declaration": editor.parameter_declaration,
            "param_names": editor.param_names}


def measure(case: str, profile_path: str | None = None, interface_mode: str = "current") -> dict:
    if profile_path:
        profile_path = str(Path(profile_path).resolve())
    pciegen = _load_pciegen_module(Path(__file__).resolve().parents[2], stub_ramgen=False)
    ram_main = importlib.import_module("ramgen.main")
    options = CASES[case]
    times, counts = defaultdict(float), defaultdict(int)
    stages = []
    process_stats = defaultdict(lambda: dict(calls=0, tree_calls=0, seconds=0.0, stdout_bytes=0))
    module_calls = defaultdict(int)
    real_run = subprocess.run

    def timed(name, function, stage=False):
        def run(*args, **kwargs):
            if stage:
                stages.append(name)
            start = time.perf_counter()
            try:
                return function(*args, **kwargs)
            finally:
                times[name] += time.perf_counter() - start
                counts[name] += 1
                if stage:
                    stages.pop()
        return run

    def measured_process(*args, **kwargs):
        start = time.perf_counter()
        proc = real_run(*args, **kwargs)
        elapsed = time.perf_counter() - start
        stage = stages[-1] if stages else "outside_stage"
        stat = process_stats[stage]
        command = args[0]
        stat["calls"] += 1
        stat["tree_calls"] += int("--printtree" in command)
        stat["seconds"] += elapsed
        stat["stdout_bytes"] += len(proc.stdout or b"")
        source = kwargs.get("input", b"")
        if isinstance(source, bytes):
            match = re.search(rb"\bmodule\s+(\w+)", source)
            if match:
                module_calls[match.group(1).decode()] += 1
        return proc

    with tempfile.TemporaryDirectory(prefix="pciegen_pipeline_") as temp:
        root = Path(temp)
        build_workspace(root, options)
        source_files = list((root / "src").rglob("*")) + list((root / "examples").rglob("*"))
        source_bytes = sum(p.stat().st_size for p in source_files if p.is_file())
        source_file_count = sum(p.is_file() for p in source_files)
        sv_sources = [p for p in source_files if p.is_file() and p.suffix == ".sv"]
        source_sv_lines = {str(p.relative_to(root)): len(p.read_text(encoding="utf-8").splitlines())
                           for p in sv_sources}
        with contextlib.ExitStack() as stack:
            if interface_mode == "full":
                stack.enter_context(patch.object(pciegen, "read_interface_from_file",
                                                new=_read_full_interface_from_file))
            stack.enter_context(patch("vutils.vparser.subprocess.run", new=measured_process))
            for name in ("step_validate_inputs", "step_prepare_workspace_and_prefix", "step_run_ramgen",
                         "step_process_text_files", "step_generate_wrapper"):
                stack.enter_context(patch.object(pciegen, name, timed(name, getattr(pciegen, name), True)))
            for name in ("copy_tree_into_rtl", "ensure_tree_user_writable", "find_module_prefix",
                         "_resolve_target_module_name", "_load_editor", "rewrite_cdm_pl_reg_file",
                         "rewrite_cdm_file", "rewrite_dwc_pcie_core_file", "append_cdm_to_dwc_pcie_ctl_file",
                         "append_cdm_to_subsystem_file", "extract_pcie_ram_port_from_rams_file",
                         "analyze_pcie_iip_subsystem_interface"):
                stack.enter_context(patch.object(pciegen, name, timed(name, getattr(pciegen, name))))
            for name in ("analyze_sv_file", "export_excel", "export_raminfo_csv", "generate_output_sv",
                         "generate_reference_modules", "generate_testbenches", "generate_flist",
                         "generate_tb_flist", "generate_makefile"):
                stack.enter_context(patch.object(ram_main, name, timed("ramgen." + name, getattr(ram_main, name))))
            old_cwd = Path.cwd()
            profiler = None
            if profile_path:
                import cProfile
                profiler = cProfile.Profile()
            try:
                os.chdir(root)
                if profiler:
                    profiler.enable()
                start = time.perf_counter()
                with contextlib.redirect_stdout(io.StringIO()):
                    result = pciegen.run(root / "rule.csv")
                elapsed = time.perf_counter() - start
                peak_mib = peak_working_set_mib()
            finally:
                os.chdir(old_cwd)
                if profiler:
                    profiler.disable()
                    profiler.dump_stats(profile_path)
        assert result["ramgen"]["report"]["instance_count"] == options["rams"]
        assert Path(result["generated_wrapper_file"]).is_file()
        output_files = [p for p in (root / "rtl").rglob("*") if p.is_file()]
        # Outside timing: check RTL equality across fresh temporary workspaces.
        digest = hashlib.sha256()
        output_sv_files = sorted(p for p in output_files if p.suffix == ".sv")
        for path in output_sv_files:
            name = path.relative_to(root / "rtl").as_posix().encode("utf-8")
            content = path.read_bytes()
            content = content.replace(str(root).encode("utf-8"), b"<workspace>")
            content = content.replace(root.as_posix().encode("utf-8"), b"<workspace>")
            for value in (name, content):
                digest.update(len(value).to_bytes(8, "big"))
                digest.update(value)
        return {"case": case, "interface_mode": interface_mode,
                "output_sv_sha256": digest.hexdigest(), "output_sv_files": len(output_sv_files),
                "input": options, "source_files": source_file_count,
                "source_sv_files": len(sv_sources), "source_sv_lines": source_sv_lines,
                "source_bytes": source_bytes, "output_files": len(output_files),
                "total_seconds": round(elapsed, 4), "peak_working_set_mib": peak_mib,
                "timings_seconds": {k: round(v, 4) for k, v in times.items()},
                "function_calls": dict(counts), "parser_calls_by_module": dict(module_calls),
                "parser_by_stage": {k: {**v, "seconds": round(v["seconds"], 4)}
                                    for k, v in process_stats.items()},
                "profile_instrumented": bool(profile_path)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=list(CASES))
    parser.add_argument("--cases", nargs="+", choices=list(CASES), default=list(CASES))
    parser.add_argument("--repeats", type=int, default=1)
    parser.add_argument("--timeout", type=int, default=90)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--profile", help="cProfile output path, for one --case only")
    parser.add_argument("--interface-mode", choices=["current", "full"], default="current",
                        help="full restores complete-CST interface reads for comparison")
    args = parser.parse_args()
    if args.case:
        result = measure(args.case, args.profile, args.interface_mode)
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(result, indent=2), encoding="utf-8")
            print(json.dumps({"case": args.case, "total_seconds": result["total_seconds"],
                              "output": str(args.output)}, ensure_ascii=False))
        else:
            print(json.dumps(result, indent=2))
        return
    results = []
    for case in args.cases:
        runs = []
        for _ in range(args.repeats):
            command = [sys.executable, str(Path(__file__).resolve()), "--case", case,
                       "--interface-mode", args.interface_mode]
            try:
                proc = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
            except subprocess.TimeoutExpired:
                runs.append({"case": case, "timeout_seconds": args.timeout})
                break
            if proc.returncode:
                runs.append({"case": case, "error": proc.stderr.strip()})
                break
            runs.append(json.loads(proc.stdout))
        results.append({"case": case, "runs": runs})
        successful = [r["total_seconds"] for r in runs if "total_seconds" in r]
        print(json.dumps({"case": case, "median_seconds": round(statistics.median(successful), 4)
                          if successful else None, "runs": len(runs)}, ensure_ascii=False), flush=True)
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps({"results": results}, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
