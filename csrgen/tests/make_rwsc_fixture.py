"""Build the XLSX/RTL fixture for tb_rwsc_csr.sv from the installed tool."""
from pathlib import Path

from openpyxl import Workbook

from csrgen.cli import main


def make_fixture():
    folder = Path("build/rwsc_check")
    folder.mkdir(parents=True, exist_ok=True)
    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "sheet1"
    sheet.append([])
    sheet.append([None, "0x0", "pulse", "0", "0", "rwsc"])
    sheet.append([None, "0x4", "command", "0", "7:4", "RWSC"])
    sheet.append([None, "0x8", "control", "5A", "7:0", "rw"])
    sheet.append([None, "0xC", "boot", "1", "1:0", "rwsc"])
    sheet.append([None, "0x10", "wordpulse", "0", "31:0", "rwsc"])
    table = folder / "rwsc.xlsx"
    workbook.save(table)
    workbook.close()
    return main([str(table), "--module", "rwsc_apb_csr", "-o", str(folder / "rwsc_apb_csr.sv")])


if __name__ == "__main__":
    raise SystemExit(make_fixture())
