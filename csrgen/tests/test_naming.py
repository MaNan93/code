from pathlib import Path
import shutil

import pytest

from csrgen import GenerationOptions, run_pipeline
from csrgen.cli import main, write_template


@pytest.mark.parametrize("options,expected", [
    ([], "apb_csr_common"),
    (["--module-prefix", "AAA"], "AAA_apb_csr_common"),
    (["--module", "ccc"], "ccc"),
    (["--module", "ccc", "--module-prefix", "AAA"], "AAA_ccc"),
])
def test_relative_output_path_is_independent_of_module(tmp_path, monkeypatch, options, expected):
    working = tmp_path / "working folder"
    working.mkdir()
    monkeypatch.chdir(working)
    write_template("apb_csr_common.xlsx")
    assert main(["apb_csr_common.xlsx", *options, "-o", "../abc.sv"]) == 0
    assert f"module {expected} #(" in (tmp_path / "abc.sv").read_text()
    assert not list(working.glob("*.sv"))


def test_input_directory_does_not_change_default_output_directory(tmp_path, monkeypatch):
    source = tmp_path / "input folder" / "apb_csr_common.xlsx"
    write_template(source)
    destination = tmp_path / "output folder"
    destination.mkdir()
    monkeypatch.chdir(destination)
    assert main([str(source), "--module", "ccc", "--module-prefix", "AAA"]) == 0
    assert "module AAA_ccc #(" in Path("apb_csr_common.sv").read_text()
    assert not list(source.parent.glob("*.sv"))


@pytest.mark.parametrize("stem", ["bad-name", "module", "123"])
def test_invalid_inferred_name_can_be_overridden(tmp_path, stem, capsys):
    source = tmp_path / f"{stem}.xlsx"
    write_template(source)
    output = tmp_path / "out.sv"
    output.write_text("existing output")
    assert main([str(source), "-o", str(output)]) == 2
    assert "use --module" in capsys.readouterr().err
    assert output.read_text() == "existing output"
    assert main([str(source), "--module", "ccc", "--module-prefix", "AAA", "-o", str(output)]) == 0
    assert "module AAA_ccc #(" in output.read_text()


def test_empty_explicit_module_does_not_fall_back_to_input_stem(tmp_path, capsys):
    source = tmp_path / "apb_csr_common.xlsx"
    write_template(source)
    output = tmp_path / "out.sv"
    assert main([str(source), "--module", "", "-o", str(output)]) == 2
    assert "invalid Verilog identifier" in capsys.readouterr().err
    assert not output.exists()


@pytest.mark.parametrize("options,expected", [
    (GenerationOptions(), "apb_csr_common"),
    (GenerationOptions(module_prefix="AAA"), "AAA_apb_csr_common"),
    (GenerationOptions(module="ccc"), "ccc"),
    (GenerationOptions(module="ccc", module_prefix="AAA"), "AAA_ccc"),
])
def test_python_pipeline_follows_same_naming_rules(tmp_path, options, expected):
    source = tmp_path / "apb_csr_common.xlsx"
    write_template(source)
    assert f"module {expected} #(" in run_pipeline(source, options).rtl


@pytest.mark.skipif(not (shutil.which("verilator") and shutil.which("verible-verilog-format")),
                   reason="Verilator and Verible are required")
def test_review_and_formatter_use_resolved_module_name(tmp_path):
    source = tmp_path / "apb_csr_common.xlsx"
    write_template(source)
    options = GenerationOptions(module="ccc", module_prefix="AAA", lint=True, format=True)
    result = run_pipeline(source, options)
    assert "module AAA_ccc" in result.rtl
    assert len(result.reviews) == 2
    for review in result.reviews:
        top = review.command.index("--top-module")
        assert review.command[top + 1] == "AAA_ccc"
