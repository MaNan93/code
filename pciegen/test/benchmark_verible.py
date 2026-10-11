"""Measure the local syntax tool separately from the PCIe editing call chain."""

from __future__ import annotations

import argparse
import contextlib
import io
import json
import os
import statistics
import subprocess
import tempfile
import time
from pathlib import Path
from unittest.mock import patch

from run_no_ramgen_scenario import _load_pciegen_module


def benchmark(lines: int, repeats: int, binary: str | None = None) -> dict:
    if binary:
        os.environ["VERIBLE_BIN"] = str(Path(binary).resolve())
    pciegen = _load_pciegen_module(Path(__file__).resolve().parents[2])
    from vutils.vparser import VERIBLE, VeribleParser

    source = (
        "module top(clk);\ninput clk;\n"
        + "".join(f"wire x{i} = clk;\n" for i in range(lines))
        + "sub u0 (.clk(clk));\nendmodule\n"
    )
    signals = [{"name": "rst_n", "direction": "input"},
               {"name": "mode", "direction": "input", "width": "[5:0]"}]
    results = {}
    with tempfile.TemporaryDirectory(prefix="pciegen_benchmark_") as temp:
        path = Path(temp) / "top.sv"
        path.write_text(source, encoding="utf-8")
        commands = {
            "syntax_only": [VERIBLE, "--export_json", str(path)],
            "syntax_and_json_tree": [VERIBLE, "--export_json", "--printtree", str(path)],
        }
        for label, args in commands.items():
            timings = []
            for _ in range(repeats):
                start = time.perf_counter()
                proc = subprocess.run(args, capture_output=True, check=True)
                timings.append(time.perf_counter() - start)
            results[label] = {"median_ms": round(statistics.median(timings) * 1000, 2),
                              "stdout_bytes": len(proc.stdout)}
        timings = []
        for _ in range(repeats):
            start = time.perf_counter()
            data = VeribleParser().parse_string(source, options={"skip_null": True})
            assert data.tree is not None and not data.errors
            timings.append(time.perf_counter() - start)
        results["python_tree_wrapper"] = {"median_ms": round(statistics.median(timings) * 1000, 2)}
        timings, counts, process_timings = [], [], []
        original_run = subprocess.run
        for _ in range(repeats):
            path.write_text(source, encoding="utf-8")
            calls = []

            def measured_run(*args, **kwargs):
                start = time.perf_counter()
                try:
                    return original_run(*args, **kwargs)
                finally:
                    calls.append(time.perf_counter() - start)

            start = time.perf_counter()
            with patch("vutils.vparser.subprocess.run", side_effect=measured_run):
                with contextlib.redirect_stdout(io.StringIO()):
                    pciegen._append_to_file(path, signals, [(s["name"], s["name"]) for s in signals], "u0")
            timings.append(time.perf_counter() - start)
            counts.append(len(calls))
            process_timings.append(sum(calls))
        results["pciegen_add_ports_and_pins"] = {
            "median_ms": round(statistics.median(timings) * 1000, 2),
            "subprocess_calls": counts,
            "subprocess_median_ms": round(statistics.median(process_timings) * 1000, 2),
        }
    version = subprocess.run([VERIBLE, "--version"], capture_output=True, text=True)
    return {"binary": VERIBLE, "version": (version.stdout + version.stderr).strip(),
            "body_lines": lines, "source_bytes": len(source.encode("utf-8")),
            "repeats": repeats, "measurements": results}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--lines", type=int, default=2000)
    parser.add_argument("--repeats", type=int, default=3)
    parser.add_argument("--binary", help="Explicit syntax executable; otherwise use vutils discovery")
    args = parser.parse_args()
    print(json.dumps(benchmark(args.lines, args.repeats, args.binary), indent=2))
