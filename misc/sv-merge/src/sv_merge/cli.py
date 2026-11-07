"""Command-line interface entry point for sv-merge."""

import argparse
import os
import sys

from .version import __version__
from .colors import log_info, log_error
from .parser import FlistParser
from .analyzer import DependencyAnalyzer
from .merger import Merger


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="sv-merge",
        description="Dependency-aware SystemVerilog & Verilog Filelist Merger.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  sv-merge -f filelist.f -o bundle.sv
  sv-merge -f top.f -F sub_ip.f --top DWC_pcie_ctl -o DWC_pcie_ctl_all.sv
  sv-merge -f run.f --dry-run -v
        """,
    )

    parser.add_argument(
        "-f", "--filelist",
        dest="filelists",
        action="append",
        default=[],
        help="Path to filelist (-f / -file). Can be specified multiple times.",
    )
    parser.add_argument(
        "-F",
        dest="filelists_F",
        action="append",
        default=[],
        help="Path to filelist (-F, paths resolved relative to flist directory).",
    )
    parser.add_argument(
        "files",
        nargs="*",
        help="Explicit source files (.v, .sv, .svh, .vh).",
    )
    parser.add_argument(
        "-o", "--output",
        help="Output merged SystemVerilog file path.",
    )
    parser.add_argument(
        "--top",
        help="Top-level module name or filename (ensures it is placed near the end).",
    )
    parser.add_argument(
        "-I", "--incdir",
        dest="incdirs",
        action="append",
        default=[],
        help="Include directories (e.g. -I path1).",
    )
    parser.add_argument(
        "--no-guard",
        action="store_true",
        help="Disable inserting `default_nettype wire between files.",
    )
    parser.add_argument(
        "--no-neutralize-includes",
        action="store_true",
        help="Do not comment out redundant `include statements for embedded files.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Analyze and print ordered file list without writing output.",
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable verbose progress output.",
    )
    parser.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s {__version__}",
    )
    return parser


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)

    if not args.dry_run and not args.output:
        parser.error("the following arguments are required: -o/--output (unless --dry-run is specified)")

    # 1. Parse Filelists
    flist_parser = FlistParser(incdirs=args.incdirs)
    for flist in args.filelists:
        flist_parser.parse(flist, is_dash_F=False)
    for flist in args.filelists_F:
        flist_parser.parse(flist, is_dash_F=True)

    # Append any explicit files passed on CLI
    for f in args.files:
        norm_f = os.path.normpath(f)
        if norm_f not in flist_parser.files:
            flist_parser.files.append(norm_f)

    if not flist_parser.files:
        log_error("No source files found in the provided filelists or arguments.")
        sys.exit(1)

    log_info(f"Discovered {len(flist_parser.files)} raw source files from filelists.", args.verbose)

    # 2. Dependency Analysis & Topological DAG Sort
    analyzer = DependencyAnalyzer(flist_parser.files)
    analyzer.analyze()
    log_info(f"Identified {len(analyzer.pkg_to_file)} SystemVerilog package definitions.", args.verbose)

    ordered_files = analyzer.topological_sort(top_file=args.top)

    if args.dry_run:
        print("\n=== Ordered File Execution List (DAG Topological Sort) ===")
        for idx, fpath in enumerate(ordered_files, 1):
            pkgs = analyzer.file_pkgs.get(fpath, [])
            pkg_str = f" [Defines: {', '.join(pkgs)}]" if pkgs else ""
            print(f"{idx:4d}. {fpath}{pkg_str}")
        print("=== Dry-run completed ===")
        return 0

    # 3. Merge Files
    merger = Merger(
        ordered_files=ordered_files,
        output_path=args.output,
        guard=not args.no_guard,
        neutralize=not args.no_neutralize_includes,
        verbose=args.verbose,
        version=__version__,
    )
    merger.run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
