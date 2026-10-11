"""Alternate full/light interface reads in fresh processes and compare RTL."""

import argparse
import json
import statistics
import subprocess
import sys
from pathlib import Path


def compare(cases, repeats, output):
    script = Path(__file__).with_name("benchmark_pipeline.py")
    results = []
    for case in cases:
        runs = {"full": [], "current": []}
        for repeat in range(repeats):
            order = ("full", "current") if repeat % 2 == 0 else ("current", "full")
            for mode in order:
                proc = subprocess.run([sys.executable, str(script), "--case", case,
                                       "--interface-mode", mode], capture_output=True,
                                      text=True, timeout=90, check=True)
                runs[mode].append(json.loads(proc.stdout))
            assert runs["full"][-1]["output_sv_sha256"] == runs["current"][-1]["output_sv_sha256"]
            print(json.dumps({"case": case, "pair": repeat + 1,
                              "full_seconds": runs["full"][-1]["total_seconds"],
                              "current_seconds": runs["current"][-1]["total_seconds"]}), flush=True)
        assert len({run["output_sv_sha256"] for mode in runs.values() for run in mode}) == 1
        medians = {mode: {
            "total_seconds": statistics.median(r["total_seconds"] for r in mode_runs),
            "interface_seconds": statistics.median(
                r["timings_seconds"]["analyze_pcie_iip_subsystem_interface"]
                + r["timings_seconds"]["extract_pcie_ram_port_from_rams_file"] for r in mode_runs),
            "native_calls": statistics.median(
                sum(s["calls"] for s in r["parser_by_stage"].values()) for r in mode_runs),
            "tree_exports": statistics.median(
                sum(s["tree_calls"] for s in r["parser_by_stage"].values()) for r in mode_runs),
            "json_bytes": statistics.median(
                sum(s["stdout_bytes"] for s in r["parser_by_stage"].values()) for r in mode_runs),
        } for mode, mode_runs in runs.items()}
        results.append({"case": case, "medians": medians, "runs": runs})
        print(json.dumps({"case": case, "medians": medians}), flush=True)
        if output:
            output.write_text(json.dumps({"repeats": repeats, "paired_alternating_order": True,
                                          "results": results}, indent=2), encoding="utf-8")
    return results


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--cases", nargs="+", default=["user_scale_2000", "user_scale_3000"])
    parser.add_argument("--repeats", type=int, default=5)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.repeats < 1:
        parser.error("repeats must be positive")
    compare(args.cases, args.repeats, args.output)
