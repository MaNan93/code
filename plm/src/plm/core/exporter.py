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


def _stage_output_dir(destination):
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    staged = Path(tempfile.mkdtemp(prefix=f".{destination.name}-generate-", dir=destination.parent))
    if destination.is_dir():
        shutil.copytree(destination, staged, dirs_exist_ok=True)
    return staged


def _commit_output_dir(staged, destination):
    """Swap a complete staged directory into place, rolling back on error."""
    destination = Path(destination)
    backup = destination.parent / f".{destination.name}-backup-{uuid.uuid4().hex}"
    if destination.exists():
        os.replace(destination, backup)
    try:
        os.replace(staged, destination)
    except BaseException:
        if backup.exists() and not destination.exists():
            os.replace(backup, destination)
        raise
    if backup.exists():
        shutil.rmtree(backup, ignore_errors=True)


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


def export_rtl(cfg, out_dir, *, pclk_mode="pclk_as_phy_output", sel_mode="sync", dpr=False,
               verible_path=None, verible_flags=None, quiet=False):
    """Generate in staging and replace the previous RTL only on success."""
    destination = Path(out_dir)
    staged = _stage_output_dir(destination)
    try:
        _export_rtl_into(
            cfg, staged, pclk_mode=pclk_mode, sel_mode=sel_mode, dpr=dpr,
            verible_path=verible_path, verible_flags=verible_flags, quiet=quiet,
            display_out=destination,
        )
        _commit_output_dir(staged, destination)
    finally:
        if staged.exists():
            shutil.rmtree(staged, ignore_errors=True)


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


def export_tb(cfg, out_rtl, *, pclk_mode="pclk_as_phy_output", dpr=False,
              verible_path=None, verible_flags=None, quiet=False):
    """Generate in staging and replace the previous testbench only on success."""
    final_rtl = Path(out_rtl)
    destination = final_rtl.parent / "tb"
    destination.parent.mkdir(parents=True, exist_ok=True)
    temp_parent = Path(tempfile.mkdtemp(prefix=".plm-tb-generate-", dir=destination.parent))
    temp_rtl = temp_parent / "rtl"
    try:
        if destination.is_dir():
            shutil.copytree(destination, temp_parent / "tb")
        _export_tb_into(
            cfg, temp_rtl, pclk_mode=pclk_mode, dpr=dpr,
            verible_path=verible_path, verible_flags=verible_flags, quiet=quiet,
            display_tb=destination,
        )
        _commit_output_dir(temp_parent / "tb", destination)
    finally:
        shutil.rmtree(temp_parent, ignore_errors=True)
