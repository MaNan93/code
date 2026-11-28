#!/usr/bin/env python3
"""Run standalone tests for pcie_pipe_link (VCS when available, else Verilator)."""

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def run_vcs(work: Path) -> None:
    cmd = [
        "vcs",
        "-full64",
        "-sverilog",
        "-timescale=1ps/1ps",
        f"-Mdir={work / 'csrc'}",
        "-o",
        str(work / "simv"),
        "-f",
        str(ROOT / "flist.f"),
        str(ROOT / "tests/tb_pcie_pipe_link_sv.sv"),
        "-R",
    ]
    subprocess.run(cmd, cwd=ROOT, check=True)


def run_verilator(work: Path) -> None:
    for top, cpp in (
        ("pcie_pipe_pclk_switch", ROOT / "tests/test_clock_switch.cpp"),
        ("pcie_pipe_link", ROOT / "tests/test_pipe_link.cpp"),
    ):
        mdir = work / f"obj_{top}"
        subprocess.run(
            [
                "verilator",
                "--cc",
                "--exe",
                "--build",
                "-j",
                "4",
                "-Wall",
                "--Mdir",
                str(mdir),
                "-top-module",
                top,
                "-f",
                str(ROOT / "flist.f"),
                str(cpp),
            ],
            cwd=ROOT,
            check=True,
        )
        subprocess.run([str(mdir / f"V{top}")], check=True)


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="pcie_pipe_link_test_") as tmp:
        work = Path(tmp)
        if shutil.which("vcs"):
            run_vcs(work)
        elif shutil.which("verilator"):
            run_verilator(work)
        else:
            print("Neither vcs nor verilator found in PATH", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
