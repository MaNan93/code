"""
Config-set / repo path resolution for the PIPE lane mapper generators.

Locating a config set on disk (resolve_set) is identical for every
generator and every front end, so it's defined once here.
"""

from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent  # .../plm/src/plm/core
PACKAGE_ROOT = SCRIPT_DIR.parent
_SOURCE_ROOT = SCRIPT_DIR.parent.parent.parent
# Source checkout: the repository root. Installed wheel: the importable
# package directory. Code must never infer that site-packages/../.. is a
# project checkout.
PLM_ROOT = _SOURCE_ROOT if (_SOURCE_ROOT / "pyproject.toml").is_file() else PACKAGE_ROOT
CONFIGS_ROOT = PLM_ROOT / "test"  # .../plm/test
BUILTIN_CFG = SCRIPT_DIR / "config"  # built-in default CSVs (if shipped alongside the package)
DOCS_DIR = PACKAGE_ROOT / "docs"
COMMON_DIR = (
    SCRIPT_DIR / "common"
)  # hand-written common modules (config-independent, shipped with the package)
TB_MAKEFILE = (
    SCRIPT_DIR / "tb_makefile.mk"
)  # hand-written VCS/Verdi Makefile (config-independent), copied to <set>/tb/Makefile
CSV_NAMES = ("controllers.csv", "lane_mapping.csv", "pipe_signals.csv")
WORKSPACE_MARKER = ".plm-workspace"


def has_csvs(d):
    d = Path(d)
    return d.is_dir() and all((d / n).is_file() for n in CSV_NAMES)


def is_workspace_root(path):
    """True only for a complete PLM workspace, never an arbitrary folder."""
    path = Path(path)
    return path.is_dir() and has_csvs(path / "config")


def is_deletable_workspace(path):
    """Deletion requires both a valid workspace and an explicit marker.

    The marker is created by current PLM versions on New/Save. Legacy
    workspaces become deletable after one successful Save; merely browsing or
    opening a directory can therefore never authorize recursive deletion.
    """
    path = Path(path)
    return is_workspace_root(path) and (path / WORKSPACE_MARKER).is_file()


def clog2(n):
    """Python equivalent of SystemVerilog's $clog2 -- the generator always
    knows the mode count at generation time, so the mode port's width can
    be computed once here and emitted as a literal, instead of carrying an
    NM parameter through every module just to recompute $clog2(NM) at
    elaboration time."""
    if n <= 1:
        return 0
    return (n - 1).bit_length()


def mode_width(n):
    """Bit width of the `mode` select port, for n modes. At least 1, even
    for a single-mode config: true $clog2 semantics give clog2(1) == 0,
    which would emit an invalid `[-1:0]` port range -- the mode port still
    has to exist and be connectable even when there's nothing to select
    between."""
    return max(1, clog2(n))


def list_configs():
    """List every subdirectory of test/ that looks like a config set, for
    use in error messages."""
    if not CONFIGS_ROOT.is_dir():
        return []
    return sorted(p.name for p in CONFIGS_ROOT.iterdir() if p.is_dir() and has_csvs(p / "config"))


def resolve_set(arg):
    """Resolve the --config argument into (csv_dir, out_rtl).

    Convention: a config set is a directory; its generated RTL always goes
    to <set>/rtl/ and its testbench to <set>/tb/ (derived by the exporter
    as out_rtl.parent / "tb"); CSVs are looked up in <set>/config/
    first, then <set>/ itself.

    The --config value is first tried as a set name under test/:
      --config demo               -> test/demo/config/, output to test/demo/rtl/
      --config config_multi_modes -> test/config_multi_modes/config/
    If not found there, it's tried as a path given directly (absolute or
    relative, so directories outside test/ also work):
      --config ../other/my_set    -> my_set/config/ (or my_set/ itself)
      --config config-1/config    -> same as above; passing the config
                                      subdirectory is attributed to its
                                      parent set
    With no --config, there's no default guess -- with multiple configs
    coexisting, guessing wrong is more trouble than just erroring out, so
    it lists the available set names under test/ instead.
    """
    if arg is None:
        avail = list_configs()
        raise SystemExit(
            "A config set must be given via --config."
            + (
                f" Available: {', '.join(avail)}"
                if avail
                else f" There are no config sets under {CONFIGS_ROOT} yet."
            )
        )

    named = CONFIGS_ROOT / arg
    if has_csvs(named / "config"):
        return named / "config", named / "rtl"

    set_dir = Path(arg).resolve()
    if has_csvs(set_dir / "config"):
        return set_dir / "config", set_dir / "rtl"
    if has_csvs(set_dir):
        # What was passed in is some set's config subdirectory (e.g.
        # config-1/config): attribute it to the parent set, output still
        # goes to config-1/rtl
        if set_dir.name == "config" and set_dir.parent != SCRIPT_DIR:
            return set_dir, set_dir.parent / "rtl"
        return set_dir, set_dir / "rtl"
    if has_csvs(BUILTIN_CFG):
        return BUILTIN_CFG, set_dir / "rtl"

    avail = list_configs()
    raise SystemExit(
        f"Config set '{arg}' not found: no CSVs "
        f"({', '.join(CSV_NAMES)}) under any of "
        f"{named}/config, {set_dir}/config, {set_dir}."
        + (f" Available sets under {CONFIGS_ROOT}: {', '.join(avail)}" if avail else "")
    )
