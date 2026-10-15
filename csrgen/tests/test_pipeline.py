import csv
from pathlib import Path
import shutil

from openpyxl import Workbook
import pytest

from csrgen import CodeToolError, GenerationOptions, ReadOptions, TableLayout, run_pipeline
from csrgen.cli import main, write_template
from csrgen.diagnostics import TableError
from csrgen.formatter import format_rtl
from csrgen.generator import generate_rtl, read_xlsx
from csrgen.layout import DEFAULT_COLUMNS, column_number, map_rows
from csrgen.parser import parse_registers
from csrgen.quality import review_rtl
from csrgen.reader import RawRow, RawTable, read_table, read_xlsx_table


def workbook_path(tmp_path, rows):
    path = tmp_path / "layout_regs.xlsx"
    workbook = Workbook()
    workbook.active.title = "sheet1"
    for row in rows:
        workbook.active.append(row)
    workbook.save(path)
    workbook.close()
    return path


def test_default_output_matches_existing_example():
    root = Path(__file__).resolve().parents[1]
    source = root / "examples/registers.xlsx"
    expected = (root / "examples/apb_csr.sv").read_text(encoding="utf-8")
    assert run_pipeline(source, GenerationOptions(module="apb_csr")).rtl == expected
    assert run_pipeline(source).rtl == expected.replace("module apb_csr #(", "module registers #(", 1)
    assert generate_rtl(read_xlsx(source)) == expected


def test_no_header_and_reordered_columns_across_stages(tmp_path, capsys):
    source = workbook_path(tmp_path, [["rw", "8:4", "3", "data", "0x10", "metadata"]])
    columns = {"access": 1, "bit": 2, "reset": 3, "signal": 4, "offset": 5, "description": 6}
    raw = read_xlsx_table(source)
    assert raw.rows[0].number == 1 and raw.rows[0].cells[0] == "rw"
    rows = map_rows(raw, TableLayout(header_rows=0, columns=columns))
    registers = parse_registers(rows)
    assert registers[0].offset == 0x10
    item = registers[0].fields[0]
    assert (item.name, item.msb, item.lsb, item.reset, item.access, item.row) == ("data", 8, 4, 3, "rw", 1)
    assert item.description == "metadata"
    output = tmp_path / "out.sv"
    arguments = [str(source), "--header-rows", "0", "-o", str(output)]
    for name, column in columns.items():
        arguments.extend(["--column", f"{name}={chr(64 + column)}"])
    assert main(arguments) == 0
    assert output.read_text() == generate_rtl(registers, module=source.stem)
    assert "Generated" in capsys.readouterr().out


def test_multiple_headers_and_mapping_beyond_template(tmp_path):
    data = [None, "0x4", "status", "0", "31:0", "ro"] + [None] * 19 + ["far description"]
    source = workbook_path(tmp_path, [["title"], ["header"], data])
    columns = {**DEFAULT_COLUMNS, "description": 26}
    registers = read_xlsx(source, layout=TableLayout(header_rows=2, columns=columns))
    assert registers[0].fields[0].row == 3
    assert registers[0].fields[0].description == "far description"


@pytest.mark.parametrize("changes,message", [
    ({"header_rows": -1}, "header_rows"),
    ({"header_rows": True}, "header_rows"),
    ({"columns": {**DEFAULT_COLUMNS, "offset": 3}}, "duplicate column mapping"),
    ({"columns": {**DEFAULT_COLUMNS, "offset": 0}}, "positive"),
    ({"columns": {**DEFAULT_COLUMNS, "offset": None}}, "missing column mapping"),
    ({"columns": {**DEFAULT_COLUMNS, "unknown": 8}}, "unknown table fields"),
])
def test_invalid_layout_rejected(changes, message):
    with pytest.raises(TableError, match=message):
        TableLayout(**changes)


@pytest.mark.parametrize("options", [
    ["--header-rows", "-1"],
    ["--column", "unknown=A"],
    ["--column", "offset=C"],
    ["--column", "offset=0"],
    ["--column", "offset=B", "--column", "offset=A"],
])
def test_invalid_cli_layout_preserves_existing_output(tmp_path, options, capsys):
    source = tmp_path / "csr_table.xlsx"
    write_template(source)
    output = tmp_path / "out.sv"
    output.write_text("existing RTL")
    assert main([str(source), *options, "-o", str(output)]) == 2
    assert output.read_text() == "existing RTL"
    assert "csrgen: error:" in capsys.readouterr().err


def test_column_letters_and_disabled_description(tmp_path):
    assert column_number("aa") == 27
    assert column_number("27") == 27
    with pytest.raises(TableError):
        column_number("A1")
    source = tmp_path / "csr_table.xlsx"
    write_template(source)
    output = tmp_path / "out.sv"
    assert main([str(source), "--column", "description=none", "-o", str(output)]) == 0
    assert output.read_text() == generate_rtl(read_xlsx(source), module=source.stem)


def test_injected_csv_adapter_uses_same_parser_and_encoding(tmp_path):
    source = tmp_path / "csr_table.csv"
    source.write_text("0x10,data,FF,7:0,rw\n", encoding="utf-16")

    def csv_reader(path, options):
        with path.open(encoding=options.encoding, newline="") as stream:
            rows = tuple(RawRow(number, tuple(cells))
                         for number, cells in enumerate(csv.reader(stream), 1))
        return RawTable(path, rows)

    columns = {"offset": 1, "signal": 2, "reset": 3, "bit": 4, "access": 5}
    options = GenerationOptions(read=ReadOptions(encoding="utf-16"),
                                layout=TableLayout(header_rows=0, columns=columns))
    result = run_pipeline(source, options, readers={".csv": csv_reader})
    assert result.registers[0].offset == 0x10
    assert result.registers[0].fields[0].reset == 0xFF
    assert "data <= 8'hFF;" in result.rtl
    with pytest.raises(TableError, match="unsupported input format"):
        read_table(source)


@pytest.mark.parametrize("flag,tool_flag", [("--lint", "--lint-tool"), ("--format", "--format-tool")])
def test_missing_quality_tool_preserves_existing_output(tmp_path, flag, tool_flag, capsys):
    source = tmp_path / "csr_table.xlsx"
    write_template(source)
    output = tmp_path / "out.sv"
    output.write_text("existing RTL")
    assert main([str(source), flag, tool_flag, "csrgen-tool-does-not-exist", "-o", str(output)]) == 2
    assert output.read_text() == "existing RTL"
    assert "RTL tool not found" in capsys.readouterr().err


@pytest.mark.skipif(not shutil.which("verilator"), reason="Verilator is not installed")
def test_reviewer_rejects_invalid_rtl():
    with pytest.raises(CodeToolError, match="failed"):
        review_rtl("module apb_csr; this is invalid RTL")


@pytest.mark.skipif(not shutil.which("verible-verilog-format"), reason="Verible is not installed")
def test_formatter_rejects_invalid_rtl():
    with pytest.raises(CodeToolError, match="failed"):
        format_rtl("module apb_csr; this is invalid RTL")


@pytest.mark.skipif(not (shutil.which("verilator") and shutil.which("verible-verilog-format")),
                   reason="Verilator and Verible are required")
def test_real_review_and_format_pipeline(tmp_path):
    source = tmp_path / "csr_table.xlsx"
    write_template(source)
    result = run_pipeline(source, GenerationOptions(lint=True, format=True))
    assert len(result.reviews) == 2
    assert f"module {source.stem}" in result.rtl
    assert result.rtl != generate_rtl(result.registers, module=source.stem)


@pytest.mark.skipif(not shutil.which("verilator"), reason="Verilator is not installed")
def test_post_format_review_rejects_broken_formatter_output(tmp_path, monkeypatch):
    from csrgen import pipeline

    source = tmp_path / "csr_table.xlsx"
    write_template(source)
    monkeypatch.setattr(pipeline, "format_rtl", lambda *_: "module apb_csr; invalid code")
    with pytest.raises(CodeToolError, match="failed"):
        run_pipeline(source, GenerationOptions(lint=True, format=True))
