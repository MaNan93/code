"""Build the XLSX/RTL fixture for tb_reserved_csr.sv from the installed tool."""
from pathlib import Path

from openpyxl import Workbook

from csrgen.cli import main


def make_fixture():
    folder = Path("build/reserved_check")
    folder.mkdir(parents=True, exist_ok=True)
    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "sheet1"
    sheet.append([])  # Header text is irrelevant.
    sheet.append([None, "0x0", "data", "12", "15:8", "rw"])
    # Deliberately wrong: reserved must still be tie0/RO with only a warning.
    sheet.append([None, None, "reserved", "FF", "3:0", "rw1c"])
    table = folder / "sparse.xlsx"
    workbook.save(table)
    workbook.close()
    return main([str(table), "--module", "sparse_apb_csr", "-o", str(folder / "sparse_apb_csr.sv")])


if __name__ == "__main__":
    raise SystemExit(make_fixture())
