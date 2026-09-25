"""
File-I/O orchestration for the RTL/testbench generators: this is the
"write the generated text to disk" layer, sitting between
plm.core.generator.{rtl,tb} (pure text generation) and plm.cli.main
(argparse/CLI concerns). No argparse, no sys.exit here -- callers (the
CLI, or anything else that wants to drive generation programmatically)
own error/exit-code handling.
"""

import os
from pathlib import Path
import shutil
import tempfile
import uuid

from plm.core.generator import rtl, tb
from plm.core.paths import COMMON_DIR, TB_MAKEFILE
from plm.core.verible import format_sv


OUTPUT_DIRS = ("rtl", "tb")


def _remove_path(path):
    path = Path(path)
    if path.is_dir():
        shutil.rmtree(path)
    elif path.exists():
        path.unlink()


def _stage_output_set(workspace):
    """Copy the current output set to a sibling staging directory."""
    workspace = Path(workspace)
    workspace.mkdir(parents=True, exist_ok=True)
    staged = Path(
        tempfile.mkdtemp(
            prefix=f".{workspace.name}-generate-",
            dir=workspace.parent,
        )
    )
    for name in OUTPUT_DIRS:
        source = workspace / name
        if source.is_dir():
            shutil.copytree(source, staged / name)
    return staged


def _commit_output_set(staged, workspace):
    """Install RTL and TB together, restoring both if either swap fails."""
    staged = Path(staged)
    workspace = Path(workspace)
    token = uuid.uuid4().hex
    backups = {}
    installed = []
    try:
        for name in OUTPUT_DIRS:
            destination = workspace / name
            if destination.exists():
                backup = workspace / f".{name}-backup-{token}"
                os.replace(destination, backup)
                backups[name] = backup
        for name in OUTPUT_DIRS:
            source = staged / name
            if not source.is_dir():
                raise RuntimeError(f"staged output is missing {name}/")
            destination = workspace / name
            os.replace(source, destination)
            installed.append(destination)
    except BaseException:
        for destination in reversed(installed):
            _remove_path(destination)
        for name, backup in backups.items():
            if backup.exists():
                os.replace(backup, workspace / name)
        raise
    else:
        for backup in backups.values():
            _remove_path(backup)


def _export_rtl_into(cfg, out_dir, *, pclk_mode="pclk_as_phy_output", sel_mode="sync", dpr=False,
                     verible_path=None, verible_flags=None, quiet=False, display_out=None):
    """Write the full RTL output for cfg into out_dir (a <set>/rtl/
    directory): a common/ snapshot, src/*.sv, flist.f."""
    src = out_dir / "src"
    common_dst = out_dir / "common"
    # Wipe and recreate both -- otherwise a file that gets renamed or
    # removed from either plm.core's own common/ or this generator's own
    # output (e.g. onehot_mux.sv becoming pipe_lane_data_mux.sv, or --dpr
    # no longer producing its own pipe_lane_dpr_mux.sv) leaves a stale
    # copy sitting in <set>/rtl/ forever, since writing only ever adds
    # files.
    for d in (src, common_dst):
        if d.exists():
            shutil.rmtree(d)
        d.mkdir(parents=True, exist_ok=True)

    # Copy the hand-written common modules into <set>/rtl/common/, so each
    # config set is self-contained and flist.f can just reference the
    # sibling common/ directory. .sv files go through format_sv() too,
    # same as generated files -- otherwise their formatting only ever
    # reflects whoever hand-edited them last, same problem format_sv()
    # exists to solve for the generated files.
    for f in COMMON_DIR.iterdir():
        if f.is_file():
            if f.suffix == ".sv":
                (common_dst / f.name).write_text(
                    format_sv(f.read_text(encoding="utf-8"), verible_path, verible_flags), encoding="utf-8"
                )
            else:
                shutil.copy2(f, common_dst / f.name)

    shown_out = Path(display_out) if display_out is not None else out_dir
    print(f"RTL   : {shown_out}")
    files = {
        src / "pipe_lane_signal_pkg.sv": rtl.gen_pkg(cfg, dpr),
        src / "pipe_lane_mode_dec.sv": rtl.gen_decoder(cfg, dpr),
        src / "pipe_lane_sel_gen.sv": rtl.gen_sel_gen(cfg, sel_mode, pclk_mode, dpr),
        src / "pipe_lane_clk_mux.sv": rtl.gen_clk_mux(cfg, pclk_mode, dpr),
        src / "pipe_lane_rst_mux.sv": rtl.gen_rst_mux(cfg, dpr),
        src / "pipe_lane_data_m2p.sv": rtl.gen_data_m2p(cfg, pclk_mode, dpr),
        src / "pipe_lane_data_p2m.sv": rtl.gen_data_p2m(cfg, pclk_mode, dpr),
        src / "pipe_lane_mapper.sv": rtl.gen_top(cfg, pclk_mode, sel_mode, dpr),
        src / "pipe_lane_mapper_connection.sv": rtl.gen_connection(cfg, pclk_mode, dpr),
        out_dir / "flist.f": rtl.gen_filelist(cfg),
    }
    for p, c in files.items():
        if p.suffix == ".sv":
            c = format_sv(c, verible_path, verible_flags)
        p.write_text(c, encoding="utf-8")
        print(f"  generated {shown_out / p.relative_to(out_dir)}")

    if not quiet:
        print()
        print(cfg.report())


def _export_tb_into(cfg, out_rtl, *, pclk_mode="pclk_as_phy_output", dpr=False,
                    verible_path=None, verible_flags=None, quiet=False, display_tb=None):
    """Write the testbench for cfg into out_rtl.parent / "tb" (out_rtl is
    the RTL output dir a set's resolve_set() gives back -- the testbench
    always lives alongside it, not inside it)."""
    tb_dir = out_rtl.parent / "tb"
    tb_dir.mkdir(parents=True, exist_ok=True)

    # Config-independent (no config-specific content, just relative
    # paths), so every config set gets an identical copy instead of it
    # being hand-maintained per set and silently missing wherever nobody
    # remembered to add it.
    if TB_MAKEFILE.is_file():
        shutil.copy2(TB_MAKEFILE, tb_dir / "makefile")

    shown_tb = Path(display_tb) if display_tb is not None else tb_dir
    print(f"TB    : {shown_tb}")
    tb_file = tb_dir / "tb_pipe_lane_mapper.sv"
    tb_file.write_text(
        format_sv(tb.gen_tb(cfg, pclk_mode, dpr), verible_path, verible_flags), encoding="utf-8"
    )
    print(f"  generated {shown_tb / tb_file.name}")

    if not quiet:
        print()
        print(cfg.report())


def export_all(cfg, out_rtl, *, pclk_mode="pclk_as_phy_output", sel_mode="sync",
               dpr=False, verible_path=None, verible_flags=None, quiet=False):
    """Generate a matched RTL/TB set and install it only after both succeed."""
    workspace = Path(out_rtl).parent
    staged = _stage_output_set(workspace)
    try:
        _export_rtl_into(
            cfg, staged / "rtl",
            pclk_mode=pclk_mode, sel_mode=sel_mode, dpr=dpr,
            verible_path=verible_path, verible_flags=verible_flags,
            quiet=True, display_out=workspace / "rtl",
        )
        _export_tb_into(
            cfg, staged / "rtl",
            pclk_mode=pclk_mode, dpr=dpr,
            verible_path=verible_path, verible_flags=verible_flags,
            quiet=True, display_tb=workspace / "tb",
        )
        if not quiet:
            print()
            print(cfg.report())
        _commit_output_set(staged, workspace)
    finally:
        if staged.exists():
            shutil.rmtree(staged, ignore_errors=True)
