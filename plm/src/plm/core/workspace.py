"""
CSV / workspace read-write for editor front ends.

Shared by the Qt front end that edits the three config CSVs +
gen_flags.txt: standards-compliant CSV writing, existing-line-ending
preservation, and the same required-column checks, so both tools read and
write the same files safely. Each front end is responsible for translating
its own widget/request state into the plain rows/flags shapes these
functions take, and back.

Not used by the generation pipeline (plm.core.generator / plm.core.exporter)
at all -- this is purely for the "open a workspace and edit it" use case,
confirmed by grep against the generator modules. It still lives under
plm.core rather than under plm.frontend because it's shared, non-UI-specific
logic used by more than one front end, same as the rest of plm.core.
"""

from pathlib import Path
import csv
import os
import shutil
import tempfile

from plm.core.gen_flags import existing_line_ending, read_gen_flags, write_gen_flags
from plm.core.model import _stripped
from plm.core.paths import BUILTIN_CFG, CONFIGS_ROOT, WORKSPACE_MARKER, has_csvs, list_configs
from plm.core.verible import find_verible


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


def write_aligned_csv(path, header, rows, eol):
    """Write standards-compliant CSV with correct quoting/escaping."""
    with open(path, "w", newline="", encoding="utf-8") as f:
        wr = csv.writer(f, lineterminator=eol)
        wr.writerow(header)
        wr.writerows(rows)


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
    cols = ["mode"] + [f"lane{l}" for l in range(lane_count)]
    eol = existing_line_ending(path)  # must read this *before* opening "w" truncates the file
    write_aligned_csv(path, cols, [[r.get(c, "") for c in cols] for r in rows], eol)


def default_verible_path(explicit=""):
    """explicit (e.g. from gen_flags.txt) always wins; otherwise fall back
    to whatever find_verible() locates on PATH, if anything."""
    return explicit or find_verible() or ""


def load_default_signals():
    """Copy an existing bundled sample workspace's pipe_signals.csv as a
    ready-made starting point for a brand-new, still-empty workspace --
    this project's own bundled sample workspaces (test/test_quad, etc.)
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
    """Load the four config files under ws_root/config into a plain JSON-
    serializable dict shape: {"controllers", "signals", "mapping": {...},
    "gen_flags": {...}, "empty"}. Raises ValueError on a genuine parse
    failure; a workspace with no config yet returns an empty-but-valid
    shape instead of raising."""
    ws_root = Path(ws_root)
    cfg_dir = ws_root / "config"
    if not has_csvs(cfg_dir):
        return {
            "controllers": [],
            "signals": [],
            "mapping": {"lane_count": 4, "rows": []},
            "gen_flags": {"arch": None, "pclk-mode": None, "sel-mode": None,
                          "dpr": False, "verible-path": default_verible_path()},
            "empty": True,
        }
    ctrls = read_csv_rows(cfg_dir / "controllers.csv", ("ctrl_id", "ctrl_name", "max_width"))
    sigs = read_csv_rows(
        cfg_dir / "pipe_signals.csv",
        ("signal_name", "signal_type", "direction", "width", "safe_state", "tie_off"),
    )
    mapping_rows, lane_count = read_mapping_csv(cfg_dir / "lane_mapping.csv")
    flags = read_gen_flags(cfg_dir / "gen_flags.txt")
    flags["verible-path"] = default_verible_path(flags.get("verible-path", ""))
    return {
        "controllers": ctrls,
        "signals": sigs,
        "mapping": {"lane_count": lane_count, "rows": mapping_rows},
        "gen_flags": flags,
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
        write_gen_flags(staged_cfg / "gen_flags.txt", payload.get("gen_flags") or {})

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
        "gen_flags": {"arch": None, "pclk-mode": None, "sel-mode": None,
                      "dpr": False, "verible-path": default_verible_path()},
    }
    save_workspace_content(ws_root, payload)
    return payload
