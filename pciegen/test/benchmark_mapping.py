"""Isolate mapping and batch-edit costs from initial CST parsing."""

import contextlib
import io
import json
import statistics
import subprocess
import tempfile
import time
from pathlib import Path
from unittest.mock import patch

from run_no_ramgen_scenario import _load_pciegen_module


def benchmark():
    g = _load_pciegen_module(Path(__file__).resolve().parents[2], stub_ramgen=False)
    results = {}
    with tempfile.TemporaryDirectory(prefix="pciegen_mapping_") as temp:
        root = Path(temp)
        rtl = root / "rtl"
        rtl.mkdir()
        (root / "report").mkdir()
        (root / "report/IO.html").write_text("")
        rule = root / "rule.csv"
        rule.write_text("name,pin,port\n")
        for count in (500, 2000, 8000):
            info = {"module_name": "sub", "ports": [
                {"name": f"p{i}", "direction": "input", "width": "[7:0]", "type": "wire", "dimension": ""}
                for i in range(count)]}
            timings = []
            with patch.object(g, "analyze_pcie_iip_subsystem_interface", return_value=info):
                for _ in range(3):
                    with contextlib.redirect_stdout(io.StringIO()):
                        start = time.perf_counter()
                        g.generate_pcie_ctrl_wrapper_file(rtl, "my", rule)
                        timings.append(time.perf_counter() - start)
            results[f"wrapper_mapping_{count}_ports"] = {"median_seconds": round(statistics.median(timings), 4),
                                                          "excludes_cst_parsing": True}
        source = "module top;\n" + "".join(f"sub u{i}(.a(a));\n" for i in range(400)) + "endmodule\n"
        for count in (1, 20, 100):
            timings, calls = [], []
            for _ in range(3):
                editor = g.vedit(source, "top")
                _ = editor.instances  # Initial CST/metadata preparation outside the timer.
                mappings = {f"u{i}": {"b": {"wire": "b"}, "c": {"wire": "c"}} for i in range(count)}
                with patch("vutils.vparser.subprocess.run", wraps=subprocess.run) as run:
                    start = time.perf_counter()
                    editor.add_inst_port(mappings)
                    timings.append(time.perf_counter() - start)
                    calls.append(run.call_count)
            results[f"vedit_edit_{count}_of_400_instances"] = {"median_seconds": round(statistics.median(timings), 4),
                                                               "parser_calls": calls}
    return results


if __name__ == "__main__":
    print(json.dumps(benchmark(), indent=2))
