import argparse
from pathlib import Path
import sys
import warnings
from zipfile import BadZipFile

from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill
from openpyxl.utils.exceptions import InvalidFileException

from .generator import NumericCellWarning, ReservedFieldWarning, TableError, generate_rtl, read_xlsx


def write_template(path):
    """Produce the screenshot's B:G layout, including its blank separator row."""
    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "sheet1"
    rows = [
        [None, "Offset(hex)", "signal", "Rst Value(hexadecimal)", "bit", "access", "description"],
        [None, "0x0", "a", "1", "0", "rw", "Control enable"],
        [None, None, "b", "1", "2:1", "ro", "External status"],
        [None, None, "c", "0", "30:3", "rw1c", "Sticky status, write one to clear"],
        [],
        [None, "0x4", "a1", "1", "0", "rw", "Control enable"],
        [None, None, "b1", "1", "2:1", "ro", "External status"],
        [None, None, "c1", "0", "30:3", "rw1c", "Sticky status, write one to clear"],
        [None, None, "reserved", "0", "31", "ro", "Reads zero"],
    ]
    for row in rows:
        sheet.append(row)
    for cell in sheet[1][1:]:
        cell.font = Font(bold=True)
        cell.fill = PatternFill("solid", fgColor="DDEBF7")
    for column, width in {"A": 3, "B": 16, "C": 20, "D": 28, "E": 12, "F": 12, "G": 44}.items():
        sheet.column_dimensions[column].width = width
    sheet.freeze_panes = "B2"
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        workbook.save(path)
    finally:
        workbook.close()


def main(argv=None):
    parser = argparse.ArgumentParser(description="Generate APB3 register SystemVerilog from XLSX (32-bit data, no strb).")
    parser.add_argument("xlsx", nargs="?", type=Path, help="input register table")
    parser.add_argument("--sheet", "-s", default="sheet1", help="worksheet name (default: sheet1, case insensitive fallback)")
    parser.add_argument("--aw", "-aw", type=int, default=16, help="address width, 2..32 (default: 16)")
    module_group = parser.add_mutually_exclusive_group()
    module_group.add_argument("--module", "-m", help="explicit RTL module name (default: apb_csr)")
    module_group.add_argument("--module-prefix", help="module name: <prefix>_apb_csr; does not change the filename")
    output_group = parser.add_mutually_exclusive_group()
    output_group.add_argument("--output", "-o", type=Path, help="explicit output file (default: ./apb_csr.sv)")
    output_group.add_argument("--file-prefix", help="filename: <prefix>_apb_csr.sv; does not change the module name")
    parser.add_argument("--template", type=Path, metavar="XLSX", help="create an example XLSX table and exit")
    args = parser.parse_args(argv)
    if args.template and args.xlsx:
        parser.error("--template cannot be combined with an input XLSX")
    if not args.template and args.xlsx is None:
        parser.error("input XLSX is required (or use --template example.xlsx)")
    try:
        if args.template:
            write_template(args.template)
            print(f"Created template: {args.template.resolve()}")
            return 0
        module = args.module or "apb_csr"
        if args.module_prefix is not None:
            if not args.module_prefix:
                raise TableError("module prefix must not be empty")
            module = f"{args.module_prefix}_apb_csr"
        filename = f"{args.module or 'apb_csr'}.sv"
        if args.file_prefix is not None:
            if not args.file_prefix or any(ord(ch) < 32 or ch in '<>:"/\\|?*' for ch in args.file_prefix):
                raise TableError("file prefix must be nonempty and contain no path separators or invalid filename characters")
            filename = f"{args.file_prefix}_apb_csr.sv"
        with warnings.catch_warnings(record=True) as notices:
            warnings.simplefilter("always", ReservedFieldWarning)
            warnings.simplefilter("always", NumericCellWarning)
            registers = read_xlsx(args.xlsx, sheet=args.sheet, aw=args.aw)
            rtl = generate_rtl(registers, module=module, aw=args.aw)
        for notice in notices:
            print(f"csrgen: warning: {notice.message}", file=sys.stderr)
        output = args.output or Path(filename)
        if output.resolve() == args.xlsx.resolve():
            raise TableError("output must not overwrite the input XLSX")
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(rtl, encoding="utf-8")
        count = sum(not item.reserved for reg in registers for item in reg.fields)
        print(f"Generated {output.resolve()} ({len(registers)} registers, {count} fields, aw={args.aw})")
        return 0
    except (TableError, OSError, ValueError, BadZipFile, InvalidFileException) as exc:
        print(f"csrgen: error: {exc}", file=sys.stderr)
        return 2
