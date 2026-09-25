"""
File-I/O orchestration for the RTL/testbench generators: this is the
"write the generated text to disk" layer, sitting between
plm.core.generator.{rtl,tb} (pure text generation) and plm.cli.main
(argparse/CLI concerns). No argparse, no sys.exit here -- callers (the
CLI, or anything else that wants to drive generation programmatically)
own error/exit-code handling.
"""

import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import tempfile
import uuid

from plm.core.generator import rtl, tb
from plm.core.plan import GenerationPlan
from plm.core.paths import COMMON_DIR, TB_MAKEFILE
from plm.core.validation import ValidationError, ValidationIssue
from plm.core.verible import format_sv


OUTPUT_DIRS = ("rtl", "tb")
MANIFEST_NAME = "manifest.json"


def _file_hash(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _write_text(path, content):
    """Write generated text with stable LF endings on every platform."""
    with Path(path).open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(content)


def _output_files(directory):
    directory = Path(directory)
    return sorted(
        path for path in directory.rglob("*")
        if path.is_file() and path.name != MANIFEST_NAME
    )


def _write_manifest(plan, directory, kind):
    directory = Path(directory)
    manifest = plan.manifest_base()
    manifest["output"] = kind
    manifest["files"] = {
        path.relative_to(directory).as_posix(): _file_hash(path)
        for path in _output_files(directory)
    }
    _write_text(
        directory / MANIFEST_NAME,
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    )
    return manifest


def _self_check_output_set(plan, workspace):
    """Validate staged files before the transactional output swap."""
    workspace = Path(workspace)
    issues = []
    required = {
        "rtl": {
            "flist.f",
            "src/pipe_lane_signal_pkg.sv",
            "src/pipe_lane_mode_dec.sv",
            "src/pipe_lane_sel_gen.sv",
            "src/pipe_lane_clk_mux.sv",
            "src/pipe_lane_rst_mux.sv",
            "src/pipe_lane_data_m2p.sv",
            "src/pipe_lane_data_p2m.sv",
            "src/pipe_lane_mapper.sv",
            "src/pipe_lane_mapper_connection.sv",
        },
        "tb": {"tb_pipe_lane_mapper.sv"},
    }
    manifests = {}
    for kind in OUTPUT_DIRS:
        directory = workspace / kind
        manifest_path = directory / MANIFEST_NAME
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        except (OSError, ValueError) as error:
            issues.append(ValidationIssue("output", f"{kind}: unreadable manifest: {error}"))
            continue
        manifests[kind] = manifest
        if manifest.get("generation_key") != plan.generation_key:
            issues.append(ValidationIssue("output", f"{kind}: manifest generation_key mismatch"))
        listed = manifest.get("files", {})
        missing = required[kind] - set(listed)
        for name in sorted(missing):
            issues.append(ValidationIssue("output", f"{kind}: missing expected file {name}"))
        for name, expected_hash in sorted(listed.items()):
            path = directory / name
            if not path.is_file():
                issues.append(ValidationIssue("output", f"{kind}: manifest lists missing file {name}"))
            elif _file_hash(path) != expected_hash:
                issues.append(ValidationIssue("output", f"{kind}: hash mismatch for {name}"))

    if set(manifests) == set(OUTPUT_DIRS):
        rtl_manifest, tb_manifest = manifests["rtl"], manifests["tb"]
        for field in (
            "generation_key",
            "config_hash",
            "generator_fingerprint",
            "options",
            "design",
        ):
            if rtl_manifest.get(field) != tb_manifest.get(field):
                issues.append(ValidationIssue("output", f"RTL/TB manifest {field} mismatch"))

    top = workspace / "rtl" / "src" / "pipe_lane_mapper.sv"
    testbench = workspace / "tb" / "tb_pipe_lane_mapper.sv"
    if top.is_file():
        text = top.read_text(encoding="utf-8")
        for expected in (
            "module pipe_lane_mapper #(",
            f"parameter int NL = {plan.lane_count}",
            f"parameter int NC = {plan.num_ctrl}",
        ):
            if expected not in text:
                issues.append(ValidationIssue("output", f"top-level port/width check failed: {expected}"))
    if testbench.is_file() and "module tb_pipe_lane_mapper;" not in testbench.read_text(encoding="utf-8"):
        issues.append(ValidationIssue("output", "testbench module declaration is missing"))

    flist = workspace / "rtl" / "flist.f"
    if flist.is_file():
        entries = {
            line.strip()
            for line in flist.read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.lstrip().startswith(("//", "+"))
        }
        for name in sorted(entries):
            if not (workspace / "rtl" / name).is_file():
                issues.append(ValidationIssue("output", f"flist.f references missing file {name}"))
        generated_sv = {
            path.relative_to(workspace / "rtl").as_posix()
            for path in (workspace / "rtl").rglob("*.sv")
        }
        for name in sorted(generated_sv - entries):
            issues.append(ValidationIssue("output", f"flist.f omits SystemVerilog file {name}"))

    placeholder = re.compile(r"\{\{[^{}]+\}\}|@@[A-Za-z_][A-Za-z0-9_]*@@")
    for kind in OUTPUT_DIRS:
        for path in _output_files(workspace / kind):
            if path.suffix in (".sv", ".f", ".mk") or path.name == "makefile":
                match = placeholder.search(path.read_text(encoding="utf-8"))
                if match:
                    issues.append(
                        ValidationIssue(
                            "output",
                            f"{kind}/{path.relative_to(workspace / kind)} contains template token {match.group(0)}",
                        )
                    )
    if issues:
        raise ValidationError(issues)


def read_manifests(workspace):
    """Return both output manifests, or an empty mapping if either is invalid."""
    workspace = Path(workspace)
    manifests = {}
    try:
        for kind in OUTPUT_DIRS:
            manifests[kind] = json.loads(
                (workspace / kind / MANIFEST_NAME).read_text(encoding="utf-8")
            )
    except (OSError, ValueError):
        return {}
    return manifests


def output_set_matches_plan(plan, workspace, *, verify_files=False):
    """Tell callers whether the installed RTL/TB set belongs to ``plan``.

    UI freshness checks only need the matched generation keys. Generation uses
    ``verify_files=True`` so a missing or edited output is repaired rather than
    incorrectly treated as a no-op.
    """
    manifests = read_manifests(workspace)
    if set(manifests) != set(OUTPUT_DIRS) or any(
        manifest.get("generation_key") != plan.generation_key
        for manifest in manifests.values()
    ):
        return False
    if verify_files:
        try:
            _self_check_output_set(plan, workspace)
        except ValidationError:
            return False
    return True


def _remove_path(path):
    path = Path(path)
    if path.is_dir():
        shutil.rmtree(path)
    elif path.exists():
        path.unlink()


def _stage_output_set(workspace):
    """Create an empty sibling staging directory for a fresh output set."""
    workspace = Path(workspace)
    workspace.mkdir(parents=True, exist_ok=True)
    return Path(
        tempfile.mkdtemp(
            prefix=f".{workspace.name}-generate-",
            dir=workspace.parent,
        )
    )


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
                _write_text(
                    common_dst / f.name,
                    format_sv(f.read_text(encoding="utf-8"), verible_path, verible_flags),
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
        _write_text(p, c)
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
        _write_text(tb_dir / "makefile", TB_MAKEFILE.read_text(encoding="utf-8"))

    shown_tb = Path(display_tb) if display_tb is not None else tb_dir
    print(f"TB    : {shown_tb}")
    tb_file = tb_dir / "tb_pipe_lane_mapper.sv"
    _write_text(
        tb_file,
        format_sv(tb.gen_tb(cfg, pclk_mode, dpr), verible_path, verible_flags),
    )
    print(f"  generated {shown_tb / tb_file.name}")

    if not quiet:
        print()
        print(cfg.report())


def export_all(plan, out_rtl):
    """Generate, self-check and atomically install one matched RTL/TB set."""
    if not isinstance(plan, GenerationPlan):
        raise TypeError("plan must be a GenerationPlan")
    options = plan.options

    workspace = Path(out_rtl).parent
    staged = _stage_output_set(workspace)
    try:
        _export_rtl_into(
            plan, staged / "rtl",
            pclk_mode=options.pclk_mode,
            sel_mode=options.sel_mode,
            dpr=options.dpr,
            verible_path=options.verible_path,
            verible_flags=options.verible_flags,
            quiet=True, display_out=workspace / "rtl",
        )
        _export_tb_into(
            plan, staged / "rtl",
            pclk_mode=options.pclk_mode,
            dpr=options.dpr,
            verible_path=options.verible_path,
            verible_flags=options.verible_flags,
            quiet=True, display_tb=workspace / "tb",
        )
        rtl_manifest = _write_manifest(plan, staged / "rtl", "rtl")
        tb_manifest = _write_manifest(plan, staged / "tb", "tb")
        _self_check_output_set(plan, staged)
        if not options.quiet:
            print()
            print(plan.report())
        _commit_output_set(staged, workspace)
        return {"rtl": rtl_manifest, "tb": tb_manifest}
    finally:
        if staged.exists():
            shutil.rmtree(staged, ignore_errors=True)
