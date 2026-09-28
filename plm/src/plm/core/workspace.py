"""
CSV / workspace read-write for editor front ends.

Shared by the Qt front end that edits the three config CSVs:
standards-compliant CSV writing, existing-line-ending preservation, and the
same required-column checks, so every tool reads and writes the same files
safely. Each front end is responsible for translating its own widget state
into the plain rows shapes these functions take, and back.

A workspace holds those three CSVs plus gen_flags.txt, which remembers the
generation flags (arch, pclk-mode, sel-mode, dpr) the front end last used for
it. That file is read and written HERE ONLY, by and for the editor front end.
The CLI never looks at it: the front end passes the flags it holds on the
`plm generate ...` command line like any other caller, so there is exactly one
path by which a flag reaches the generator, and exactly one reader of the
file.

Not used by the generation pipeline (plm.core.generator / plm.core.exporter)
at all -- this is purely for the "open a workspace and edit it" use case,
confirmed by grep against the generator modules. It still lives under
plm.core rather than under plm.frontend because it's shared, non-UI-specific
logic used by more than one front end, same as the rest of plm.core.
"""

from pathlib import Path
import csv
import io
import os
import shutil
import tempfile

from plm.core.gen_flags import (
    ARCH_VALUES,
    PCLK_MODE_VALUES,
    SEL_MODE_VALUES,
    complete_arch_pclk,
)
from plm.core.model import _stripped
from plm.core.paths import BUILTIN_CFG, CONFIGS_ROOT, WORKSPACE_MARKER, has_csvs, list_configs


def existing_line_ending(path):
    """Detect the line ending already used by path, so writing back to it
    doesn't silently rewrite every single line just from an untouched
    load-then-save round trip. Falls back to plain "\n" for a file that
    doesn't exist yet -- these configs are meant to be Linux-readable
    regardless of which OS a given front end runs on, so a brand-new file
    shouldn't default to the local OS's convention (os.linesep is CRLF on
    Windows).

    Used to live in plm.core.gen_flags, back when that module also wrote
    gen_flags.txt; the CSV writers below are its only callers now.
    """
    path = Path(path)
    if path.is_file():
        with open(path, "rb") as f:
            head = f.read(65536)
        if b"\r\n" in head:
            return "\r\n"
        if b"\n" in head:
            return "\n"
    return "\n"


def read_csv_rows(path, required_cols=None):
    """required_cols, if given, is checked against the file's actual
    header before any row is accepted -- a header that's missing, blank,
    or just doesn't match must be treated as a load failure, not silently
    accepted as "0 useful columns, every field defaults to blank": the
    latter is how a garbled file on disk turns into a table full of blank
    rows that then look empty in the GUI with no error shown at all -- and
    the very next Save/Validate (which always writes the tables back out
    first) overwrites the original file with those blanks, destroying
    whatever was actually in it.

    Header and values are both whitespace-stripped (same _stripped()
    plm.core.model itself uses) -- a comma-aligned CSV padded with spaces
    for readability is a legitimate, common style, not a malformed file.
    """
    path = Path(path)
    if not path.is_file():
        return []
    with open(path, newline="", encoding="utf-8") as f:
        rd = csv.DictReader(f)
        rd.fieldnames = [c.strip() if c else c for c in (rd.fieldnames or [])]
        if len(rd.fieldnames) != len(set(rd.fieldnames)):
            raise ValueError(f"{path}: header contains duplicate column names")
        if required_cols and not set(required_cols) <= set(rd.fieldnames):
            missing = sorted(set(required_cols) - set(rd.fieldnames))
            raise ValueError(
                f"{path}: header is missing {', '.join(missing)} "
                f"(found: {', '.join(rd.fieldnames) or '(no header)'})"
            )
        rows = []
        for line, row in enumerate(_stripped(rd), start=2):
            if row.get(None):
                raise ValueError(f"{path} line {line}: row has more fields than the header")
            rows.append(dict(row))
        return rows


def read_mapping_csv(path):
    path = Path(path)
    if not path.is_file():
        return [], 4
    with open(path, newline="", encoding="utf-8") as f:
        rd = csv.DictReader(f)
        fieldnames = [c.strip() if c else c for c in (rd.fieldnames or [])]
        if len(fieldnames) != len(set(fieldnames)):
            raise ValueError(f"{path}: header contains duplicate column names")
        rd.fieldnames = fieldnames
        if "mode" not in fieldnames:
            raise ValueError(
                f"{path}: header is missing 'mode' (found: {', '.join(fieldnames) or '(no header)'})"
            )
        lane_cols = [c for c in fieldnames if c != "mode"]
        if not lane_cols:
            raise ValueError(f"{path}: header has no lane columns besides mode")
        expected = [f"lane{i}" for i in range(len(lane_cols))]
        if lane_cols != expected:
            raise ValueError(
                f"{path}: lane columns must be exactly {', '.join(expected)}; "
                f"found {', '.join(lane_cols)}"
            )
        rows = []
        for line, row in enumerate(_stripped(rd), start=2):
            if row.get(None):
                raise ValueError(f"{path} line {line}: row has more fields than the header")
            rows.append(dict(row))
    return rows, len(lane_cols)


# gen_flags.txt value names were renamed (phy-output/phy-input-max-pclk ->
# pclk_as_phy_output/pclk_as_phy_input) for clearer, more consistent
# terminology. A file written before the rename still has the old value on
# disk -- translate it on read so an old config set keeps working without the
# user having to hand-edit it; new writes only ever use the new names.
_PCLK_MODE_MIGRATION = {
    "phy-output": "pclk_as_phy_output",
    "phy-input-max-pclk": "pclk_as_phy_input",
}

GEN_FLAGS_FILENAME = "gen_flags.txt"


def read_gen_flags(path):
    """Read a workspace's gen_flags.txt into the front ends' own shape.

    An unset or unrecognized arch/pclk-mode/sel-mode comes back as None (not a
    placeholder string -- each front end maps that to whatever its own "unset"
    widget value is), dpr is already a bool. A missing file reads as all-unset
    rather than raising: a workspace without one is normal, it just means
    nobody has picked anything for it yet.
    """
    path = Path(path)
    flags = {}
    if path.is_file():
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.split("#", 1)[0].strip()
            if not line or "=" not in line:
                continue
            k, _, v = line.partition("=")
            flags[k.strip()] = v.strip()
    raw_pclk_mode = flags.get("pclk-mode", "")
    pclk_mode_val = _PCLK_MODE_MIGRATION.get(raw_pclk_mode, raw_pclk_mode)
    arch_val, pclk_mode_val = complete_arch_pclk(flags.get("arch"), pclk_mode_val)
    sel_val = flags.get("sel-mode")
    return {
        "arch": arch_val,
        "pclk-mode": pclk_mode_val,
        "sel-mode": sel_val if sel_val in SEL_MODE_VALUES else None,
        "dpr": flags.get("dpr", "").strip().lower() in ("1", "true", "yes", "on"),
    }


def write_gen_flags(path, flags):
    """Write the front end's current choices back to gen_flags.txt.

    Anything that isn't a real arch/pclk-mode/sel-mode value is dropped, so a
    combo still showing its own "(default: ...)" placeholder can be passed
    straight through. A set of choices that pins nothing at all removes the
    file instead of leaving an empty one behind.
    """
    path = Path(path)
    lines = [
        "# Written by the PLM Qt front end; the CLI does not read this file.",
        "# arch      = original_pipe | serdes",
        "# pclk-mode = pclk_as_phy_output | pclk_as_phy_input",
        "# sel-mode  = sync | comb",
        "# dpr       = true | false (dpr=true requires sel-mode=sync)",
    ]
    header_lines = len(lines)
    arch = flags.get("arch")
    pclk = flags.get("pclk-mode")
    sel = flags.get("sel-mode")
    if arch in ARCH_VALUES:
        lines.append(f"arch = {arch}")
    if pclk in PCLK_MODE_VALUES:
        lines.append(f"pclk-mode = {pclk}")
    if sel in SEL_MODE_VALUES:
        lines.append(f"sel-mode = {sel}")
    if flags.get("dpr"):
        lines.append("dpr = true")
    if len(lines) == header_lines:
        # nothing but the header comments -- no point keeping a file that
        # pins no keys at all.
        if path.is_file():
            path.unlink()
        return
    eol = existing_line_ending(path)  # must read this *before* truncating the file
    # newline="" (like the CSV writers) so the endings joined in below are
    # written as-is; write_text()'s default would flip an existing LF file to
    # CRLF, or the reverse, on every save.
    with open(path, "w", newline="", encoding="utf-8") as f:
        f.write(eol.join(lines) + eol)


def write_aligned_csv(path, header, rows, eol):
    """Write standards-compliant CSV with correct quoting/escaping."""
    with open(path, "w", newline="", encoding="utf-8") as f:
        wr = csv.writer(f, lineterminator=eol)
        wr.writerow(header)
        wr.writerows(rows)


def _csv_bytes(header, rows):
    """Serialize editor rows exactly like the on-disk CSV writers, in memory."""
    stream = io.StringIO(newline="")
    writer = csv.writer(stream, lineterminator="\n")
    writer.writerow(header)
    writer.writerows(rows)
    return stream.getvalue().encode("utf-8")


def config_snapshot_from_payload(payload):
    """Return the three config CSVs for a front-end payload without file I/O."""
    controllers = payload.get("controllers") or []
    signals = payload.get("signals") or []
    mapping = payload.get("mapping") or {}
    if not controllers:
        raise ValueError("Controllers table is empty -- at least one controller is required.")
    if not signals:
        raise ValueError("Pipe Signals table is empty -- at least one signal is required.")
    mapping_rows = mapping.get("rows") or []
    if not mapping_rows:
        raise ValueError("Lane Mapping table is empty -- at least one mode row is required.")
    try:
        lane_count = int(mapping.get("lane_count") or 4)
    except (TypeError, ValueError) as error:
        raise ValueError("lane_count must be an integer") from error
    if lane_count < 1:
        raise ValueError("lane_count must be >= 1")

    controller_columns = ("ctrl_id", "ctrl_name", "max_width")
    signal_columns = (
        "signal_name", "signal_type", "direction", "width", "safe_state", "tie_off",
    )
    mapping_columns = ["mode"] + [f"lane{lane}" for lane in range(lane_count)]
    return {
        "controllers.csv": _csv_bytes(
            controller_columns,
            [[row.get(column, "") for column in controller_columns] for row in controllers],
        ),
        "pipe_signals.csv": _csv_bytes(
            signal_columns,
            [
                [
                    row.get("signal_name", ""),
                    row.get("signal_type", "") or "perlane",
                    row.get("direction", ""),
                    row.get("width", ""),
                    row.get("safe_state", ""),
                    row.get("tie_off", ""),
                ]
                for row in signals
            ],
        ),
        "lane_mapping.csv": _csv_bytes(
            mapping_columns,
            [[row.get(column, "") for column in mapping_columns] for row in mapping_rows],
        ),
    }


def write_controllers_csv(path, rows):
    if not rows:
        raise ValueError("Controllers table is empty -- at least one controller is required.")
    path = Path(path)
    eol = existing_line_ending(path)  # must read this *before* opening "w" truncates the file
    write_aligned_csv(
        path,
        ["ctrl_id", "ctrl_name", "max_width"],
        [[r.get("ctrl_id", ""), r.get("ctrl_name", ""), r.get("max_width", "")] for r in rows],
        eol,
    )


def write_signals_csv(path, rows):
    if not rows:
        raise ValueError("Pipe Signals table is empty -- at least one signal is required.")
    path = Path(path)
    eol = existing_line_ending(path)  # must read this *before* opening "w" truncates the file
    write_aligned_csv(
        path,
        ["signal_name", "signal_type", "direction", "width", "safe_state", "tie_off"],
        [
            [
                r.get("signal_name", ""),
                r.get("signal_type", "") or "perlane",
                r.get("direction", ""),
                r.get("width", ""),
                r.get("safe_state", ""),
                r.get("tie_off", ""),
            ]
            for r in rows
        ],
        eol,
    )


def write_mapping_csv(path, lane_count, rows):
    if not rows:
        raise ValueError("Lane Mapping table is empty -- at least one mode row is required.")
    path = Path(path)
    cols = ["mode"] + [f"lane{lane_idx}" for lane_idx in range(lane_count)]
    eol = existing_line_ending(path)  # must read this *before* opening "w" truncates the file
    write_aligned_csv(path, cols, [[r.get(c, "") for c in cols] for r in rows], eol)


def load_default_signals():
    """Copy an existing bundled sample workspace's pipe_signals.csv as a
    ready-made starting point for a brand-new, still-empty workspace --
    this project's own bundled sample workspaces (test/quad, etc.)
    always exist regardless of which workspace is currently open, so
    they're a reliable template source."""
    packaged = BUILTIN_CFG / "pipe_signals.csv"
    if packaged.is_file():
        return read_csv_rows(packaged)
    for name in list_configs():
        src = CONFIGS_ROOT / name / "config" / "pipe_signals.csv"
        if src.is_file():
            return read_csv_rows(src)
    return []


def workspace_content(ws_root):
    """Load a workspace's config into a plain JSON-serializable dict shape:
    {"controllers", "signals", "mapping": {...}, "gen_flags": {...}, "empty"}.
    Raises ValueError on a genuine parse failure; a workspace with no config
    yet returns an empty-but-valid shape instead of raising."""
    ws_root = Path(ws_root)
    cfg_dir = ws_root / "config"
    if not has_csvs(cfg_dir):
        return {
            "controllers": [],
            "signals": [],
            "mapping": {"lane_count": 4, "rows": []},
            "gen_flags": {"arch": None, "pclk-mode": None, "sel-mode": None, "dpr": False},
            "empty": True,
        }
    ctrls = read_csv_rows(cfg_dir / "controllers.csv", ("ctrl_id", "ctrl_name", "max_width"))
    sigs = read_csv_rows(
        cfg_dir / "pipe_signals.csv",
        ("signal_name", "signal_type", "direction", "width", "safe_state", "tie_off"),
    )
    mapping_rows, lane_count = read_mapping_csv(cfg_dir / "lane_mapping.csv")
    return {
        "controllers": ctrls,
        "signals": sigs,
        "mapping": {"lane_count": lane_count, "rows": mapping_rows},
        "gen_flags": read_gen_flags(cfg_dir / GEN_FLAGS_FILENAME),
        "empty": False,
    }


def save_workspace_content(ws_root, payload):
    ws_root = Path(ws_root)
    cfg_dir = ws_root / "config"
    ws_root.mkdir(parents=True, exist_ok=True)
    mapping = payload.get("mapping") or {}
    try:
        lane_count = int(mapping.get("lane_count") or 4)
    except (TypeError, ValueError) as e:
        raise ValueError("lane_count must be an integer") from e
    if lane_count < 1:
        raise ValueError("lane_count must be >= 1")

    staging_root = Path(tempfile.mkdtemp(prefix=".plm-save-", dir=ws_root))
    staged_cfg = staging_root / "config"
    backup_cfg = staging_root / "previous-config"
    try:
        if cfg_dir.is_dir():
            shutil.copytree(cfg_dir, staged_cfg)
        else:
            staged_cfg.mkdir()
        write_controllers_csv(staged_cfg / "controllers.csv", payload.get("controllers") or [])
        write_signals_csv(staged_cfg / "pipe_signals.csv", payload.get("signals") or [])
        write_mapping_csv(staged_cfg / "lane_mapping.csv", lane_count, mapping.get("rows") or [])
        write_gen_flags(staged_cfg / GEN_FLAGS_FILENAME, payload.get("gen_flags") or {})

        if cfg_dir.exists():
            os.replace(cfg_dir, backup_cfg)
        try:
            os.replace(staged_cfg, cfg_dir)
        except BaseException:
            if backup_cfg.exists() and not cfg_dir.exists():
                os.replace(backup_cfg, cfg_dir)
            raise
        if backup_cfg.exists():
            shutil.rmtree(backup_cfg, ignore_errors=True)
        (ws_root / WORKSPACE_MARKER).write_text("PLM workspace\n", encoding="utf-8")
    finally:
        shutil.rmtree(staging_root, ignore_errors=True)


def scaffold_default_content(ws_root):
    """Seed sensible starting content for a brand-new, empty workspace."""
    payload = {
        "controllers": [{"ctrl_id": "0", "ctrl_name": "CtrlA", "max_width": "4"}],
        "signals": load_default_signals(),
        "mapping": {"lane_count": 4, "rows": [{"mode": "0", "lane0": "0-0", "lane1": "0-1",
                                                "lane2": "0-2", "lane3": "0-3"}]},
        "gen_flags": {"arch": None, "pclk-mode": None, "sel-mode": None, "dpr": False},
    }
    save_workspace_content(ws_root, payload)
    return payload
