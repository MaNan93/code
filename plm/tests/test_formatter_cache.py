"""Successful common-module formatting is reused without masking failures."""

import contextlib
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

from plm.core import exporter, verible
from plm.core.gen_flags import GenerationOptions
from plm.core.model import Config
from plm.core.paths import COMMON_DIR
from plm.core.plan import GenerationPlan


from sample_data import sample_config


class FormatterCacheTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.binary = self.root / "formatter.exe"
        self.binary.write_bytes(b"formatter-v1")
        self.source = "module example;\nendmodule\n"
        self.flags = {"column_limit": "100"}
        with verible._FORMAT_CACHE_LOCK:
            verible._FORMAT_CACHE.clear()
            verible._FORMAT_CACHE_BYTES = 0
        self.addCleanup(self.clear_cache)

    @staticmethod
    def clear_cache():
        with verible._FORMAT_CACHE_LOCK:
            verible._FORMAT_CACHE.clear()
            verible._FORMAT_CACHE_BYTES = 0

    @staticmethod
    def success(args, **kwargs):
        return subprocess.CompletedProcess(
            args, 0, stdout=kwargs["input"].replace(b";\n", b";  \n"), stderr=b""
        )

    def format(self, text=None, *, cache=True, flags=None):
        return verible.format_sv(
            self.source if text is None else text,
            str(self.binary),
            self.flags if flags is None else flags,
            cache=cache,
        )

    def test_cache_is_opt_in_and_preserves_exact_formatted_text(self):
        with mock.patch.object(verible.subprocess, "run", side_effect=self.success) as run:
            first = self.format(cache=False)
            self.assertEqual(self.format(cache=False), first)
            self.assertEqual(run.call_count, 2)
            self.assertEqual(self.format(), first)
            self.assertEqual(self.format(), first)
            self.assertEqual(run.call_count, 3)
        self.assertNotEqual(first, self.source)

    def test_source_binary_and_effective_flags_invalidate_cached_output(self):
        with mock.patch.object(verible.subprocess, "run", side_effect=self.success) as run:
            self.format()
            self.format(flags={"unused": None, "column_limit": "100", "empty": ""})
            self.assertEqual(run.call_count, 1)
            self.format(text=self.source.replace("example", "another"))
            self.format(flags={"column_limit": "80"})
            self.binary.write_bytes(b"formatter-v2-upgraded")
            self.format()
            self.format()
            self.assertEqual(run.call_count, 4)

    def test_failing_corrupt_and_non_utf8_outputs_are_never_cached(self):
        failures = [
            subprocess.CompletedProcess([], 1, stdout=self.source.encode()),
            subprocess.CompletedProcess([], 0, stdout=b"module example;\n"),
            subprocess.CompletedProcess([], 0, stdout=b"module changed;\nendmodule\n"),
            subprocess.CompletedProcess([], 0, stdout=b"\xff"),
            subprocess.CompletedProcess([], 0, stdout=b""),
            OSError("formatter temporarily unavailable"),
            subprocess.TimeoutExpired("formatter", 10),
        ]
        for failure in failures:
            with self.subTest(failure=failure):
                self.clear_cache()
                with mock.patch.object(verible.subprocess, "run", side_effect=[failure, failure]) as run:
                    self.assertEqual(self.format(), self.source)
                    self.assertEqual(self.format(), self.source)
                    self.assertEqual(run.call_count, 2)
                with mock.patch.object(verible.subprocess, "run", side_effect=self.success) as run:
                    formatted = self.format()
                    self.assertEqual(self.format(), formatted)
                    self.assertEqual(run.call_count, 1)

    def test_unavailable_binary_is_retried_after_it_appears(self):
        self.binary.unlink()
        with mock.patch.object(verible.subprocess, "run", side_effect=OSError) as run:
            self.assertEqual(self.format(), self.source)
            self.assertEqual(self.format(), self.source)
            self.assertEqual(run.call_count, 2)
        self.binary.write_bytes(b"formatter-installed")
        with mock.patch.object(verible.subprocess, "run", side_effect=self.success) as run:
            formatted = self.format()
            self.assertEqual(self.format(), formatted)
            self.assertEqual(run.call_count, 1)

    def test_binary_replaced_during_format_is_not_cached_under_old_identity(self):
        def replace_binary(args, **kwargs):
            self.binary.write_bytes(b"formatter-v2-upgraded")
            return self.success(args, **kwargs)

        with mock.patch.object(verible.subprocess, "run", side_effect=replace_binary) as run:
            self.format()
            self.assertEqual(run.call_count, 1)
        self.assertFalse(verible._FORMAT_CACHE)
        with mock.patch.object(verible.subprocess, "run", side_effect=self.success) as run:
            self.format()
            self.format()
            self.assertEqual(run.call_count, 1)

    def test_wrapper_scripts_do_not_cache_their_underlying_program(self):
        for name, content in (("formatter.cmd", "@formatter.exe %*\n"),
                              ("shell-wrapper", "#!/bin/sh\nexec formatter-binary $@\n")):
            with self.subTest(name=name):
                wrapper = self.root / name
                wrapper.write_text(content, encoding="utf-8")
                with mock.patch.object(verible.subprocess, "run", side_effect=self.success) as run:
                    first = verible.format_sv(self.source, str(wrapper), self.flags, cache=True)
                    second = verible.format_sv(self.source, str(wrapper), self.flags, cache=True)
                    self.assertEqual(first, second)
                    self.assertEqual(run.call_count, 2)
                self.assertFalse(verible._FORMAT_CACHE)

    def test_cache_check_preserves_literals_comments_and_token_boundaries(self):
        cases = [
            ('initial $display("a b");\n', 'initial $display("ab");\n'),
            ('initial $display("a\\\" b");\n', 'initial $display("a\\\"b");\n'),
            ('wire a b;\n', 'wire ab;\n'),
            ('assign x = a + +b;\n', 'assign x = a ++b;\n'),
            ('wire \\first second;\n', 'wire \\firstsecond;\n'),
            ('// comment\nwire x;\n', '// comment wire x;\n'),
        ]
        for source, corrupt in cases:
            with self.subTest(source=source):
                self.clear_cache()
                result = subprocess.CompletedProcess([], 0, stdout=corrupt.encode())
                with mock.patch.object(verible.subprocess, "run", return_value=result) as run:
                    self.assertEqual(self.format(source), source)
                    self.assertEqual(self.format(source), source)
                    self.assertEqual(run.call_count, 2)
                self.assertFalse(verible._FORMAT_CACHE)
        source = '// spaced comment\n/* block comment */\nwire x;\n'
        spaced = '// spaced   comment\n/* block   comment */\n  wire x;\n'
        with mock.patch.object(
            verible.subprocess, "run",
            return_value=subprocess.CompletedProcess([], 0, stdout=spaced.encode()),
        ) as run:
            self.assertEqual(self.format(source), spaced)
            self.assertEqual(self.format(source), spaced)
            self.assertEqual(run.call_count, 1)

    def test_lru_evicts_the_least_recently_used_entry(self):
        texts = [self.source.replace("example", name) for name in ("first", "second", "third")]
        with mock.patch.object(verible, "_FORMAT_CACHE_MAX_ENTRIES", 2), mock.patch.object(
            verible.subprocess, "run", side_effect=self.success
        ) as run:
            self.format(texts[0])
            self.format(texts[1])
            self.format(texts[0])
            self.format(texts[2])
            self.format(texts[0])
            self.assertEqual(run.call_count, 3)
            self.format(texts[1])
            self.assertEqual(run.call_count, 4)
            self.assertEqual(len(verible._FORMAT_CACHE), 2)

    def test_byte_budget_evicts_entries_and_skips_oversized_results(self):
        text = self.source.replace("example", "small")
        with mock.patch.object(verible, "_FORMAT_CACHE_MAX_BYTES", 40), mock.patch.object(
            verible.subprocess, "run", side_effect=self.success
        ) as run:
            self.format()
            self.format(text)
            self.assertEqual(len(verible._FORMAT_CACHE), 1)
            self.assertLessEqual(verible._FORMAT_CACHE_BYTES, 40)
            oversized = self.source + "// " + "large" * 20 + "\n"
            self.format(oversized)
            self.format(oversized)
            self.assertEqual(run.call_count, 4)
            self.assertEqual(len(verible._FORMAT_CACHE), 1)

    def test_repeated_exports_skip_only_the_common_module_processes(self):
        options = GenerationOptions(
            verible_path=str(self.binary), verible_flags=self.flags, quiet=True
        )
        plan = GenerationPlan.build(Config(sample_config("bifurcate")), options)
        first, second = self.root / "first", self.root / "second"
        with contextlib.redirect_stdout(io.StringIO()), mock.patch.object(
            verible.subprocess, "run", side_effect=self.success
        ) as run:
            exporter.export_all(plan, first / "rtl")
            first_count = run.call_count
            exporter.export_all(plan, second / "rtl")
            second_count = run.call_count - first_count
        common_count = sum(path.is_file() for path in COMMON_DIR.glob("*.sv"))
        self.assertEqual(first_count, common_count + 10)
        self.assertEqual(second_count, 10)
        for path in first.rglob("*"):
            if path.is_file():
                output = path.read_bytes()
                self.assertEqual(output, (second / path.relative_to(first)).read_bytes())
                self.assertNotIn(b"\r", output)


if __name__ == "__main__":
    unittest.main()
