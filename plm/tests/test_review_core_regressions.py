"""Failure and input-consistency cases found in the October code review."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch

from plm.core import verible, workspace
from plm.core.gen_flags import GenerationOptions
from plm.core.locking import WorkspaceBusyError, workspace_lock
from plm.core.model import Config, _literal_int
from plm.core.validation import ValidationError, load_generation_plan_from_payload
from test_core import valid_payload


class ReviewCoreRegressionTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.payload = valid_payload()
        workspace.save_workspace_content(self.root, self.payload)

    def test_failed_install_and_restore_keep_a_recoverable_config_backup(self):
        original = os.replace
        before = {p.name: p.read_bytes() for p in (self.root / "config").iterdir()}

        def fail(source, target):
            source = Path(source)
            if source.parent.name.startswith(".plm-save-"):
                raise PermissionError("install and restore are temporarily blocked")
            return original(source, target)

        with patch.object(workspace.os, "replace", side_effect=fail):
            with self.assertRaisesRegex(OSError, "旧配置已保留"):
                workspace.save_workspace_content(self.root, self.payload)
        backups = list(self.root.glob(".plm-save-*/previous-config"))
        self.assertEqual(len(backups), 1)
        self.assertEqual({p.name: p.read_bytes() for p in backups[0].iterdir()}, before)
        # The error leaves a usable recovery source, not just an error message.
        original(backups[0], self.root / "config")
        self.assertEqual(workspace.workspace_content(self.root)["controllers"], self.payload["controllers"])

    def test_failed_install_with_successful_restore_removes_temporary_files(self):
        original = os.replace

        def fail(source, target):
            source = Path(source)
            if source.name == "config" and source.parent.name.startswith(".plm-save-"):
                raise PermissionError("install blocked")
            return original(source, target)

        with patch.object(workspace.os, "replace", side_effect=fail):
            with self.assertRaises(PermissionError):
                workspace.save_workspace_content(self.root, self.payload)
        self.assertEqual(workspace.workspace_content(self.root)["controllers"], self.payload["controllers"])
        self.assertEqual(list(self.root.glob(".plm-save-*")), [])

    def test_other_process_cannot_save_generate_or_commit_while_locked(self):
        script = """
import sys
from pathlib import Path
from plm.core.locking import WorkspaceBusyError
from plm.core.workspace import save_workspace_content
from plm.core.service import generate
from plm.core.gen_flags import GenerationOptions
from plm.core.exporter import _commit_output_set
root = Path(sys.argv[1])
for operation in (
    lambda: save_workspace_content(root, {}),
    lambda: generate(root / 'config', root / 'rtl', GenerationOptions()),
    lambda: _commit_output_set(root / 'missing-stage', root),
):
    try:
        operation()
    except WorkspaceBusyError:
        continue
    raise AssertionError('writer entered locked workspace')
print('ALL_WRITERS_EXCLUDED')
"""
        with workspace_lock(self.root):
            with workspace_lock(self.root / "."):
                # Nested save in the owner is permitted.
                workspace.save_workspace_content(self.root, self.payload)
            child = subprocess.run([sys.executable, "-B", "-c", script, str(self.root)],
                                   capture_output=True, text=True, timeout=15)
            self.assertEqual(child.returncode, 0, child.stdout + child.stderr)
            self.assertIn("ALL_WRITERS_EXCLUDED", child.stdout)
        workspace.save_workspace_content(self.root, self.payload)
        self.assertFalse((self.root / "rtl").exists())

    def test_another_thread_is_excluded_and_exceptions_release_the_lock(self):
        errors = []

        def write():
            try:
                workspace.save_workspace_content(self.root, self.payload)
            except WorkspaceBusyError as error:
                errors.append(error)

        with self.assertRaisesRegex(RuntimeError, "abort"):
            with workspace_lock(self.root):
                worker = threading.Thread(target=write)
                worker.start()
                worker.join(5)
                self.assertFalse(worker.is_alive())
                self.assertEqual(len(errors), 1)
                raise RuntimeError("abort")
        workspace.save_workspace_content(self.root, self.payload)

    def test_non_cached_generation_rejects_formatter_semantic_changes(self):
        for source, changed in (
            ('module m; string s="a b"; endmodule\n', 'module m; string s="ab"; endmodule\n'),
            ('module m; assign a = b + +c; endmodule\n', 'module m; assign a = b ++c; endmodule\n'),
        ):
            result = subprocess.CompletedProcess([], 0, changed.encode(), b"")
            with self.subTest(source=source), patch.object(verible.subprocess, "run", return_value=result):
                self.assertEqual(verible.format_sv(source, "formatter"), source)
                with self.assertRaises(ValueError):
                    verible.format_sv(source, "formatter", strict=True)

    def test_duplicate_headers_are_rejected_by_core_and_editor_readers(self):
        for filename, column in (("controllers.csv", "ctrl_name"), ("pipe_signals.csv", "signal_name"),
                                 ("lane_mapping.csv", "mode")):
            with self.subTest(filename=filename):
                path = self.root / "config" / filename
                before = path.read_bytes()
                lines = before.decode().splitlines()
                path.write_text("\n".join(line + "," + (column if index == 0 else "other")
                                          for index, line in enumerate(lines)) + "\n")
                with self.assertRaisesRegex(SystemExit, "duplicate column names"):
                    Config(path.parent)
                with self.assertRaisesRegex(ValueError, "duplicate column names"):
                    workspace.workspace_content(self.root)
                path.write_bytes(before)

    def test_invalid_bus_option_survives_draft_save_and_is_still_reported(self):
        self.payload["gen_flags"] = {"bus-type": "unfinished", "arch": "unfinished_arch",
                                     "pclk-mode": "unfinished_pclk"}
        workspace.save_workspace_content(self.root, self.payload)
        loaded = workspace.workspace_content(self.root)
        self.assertEqual(loaded["gen_flags"]["bus-type"], "unfinished")
        self.assertEqual(loaded["gen_flags"]["arch"], "unfinished_arch")
        self.assertEqual(loaded["gen_flags"]["pclk-mode"], "unfinished_pclk")
        with self.assertRaisesRegex(ValidationError, "bus_type"):
            load_generation_plan_from_payload(loaded, GenerationOptions(bus_type="unfinished"))

    def test_decimal_leading_zeros_do_not_enable_implicit_octal(self):
        for value, expected in (("01", 1), ("010", 10), ("-010", -10), ("0x10", 16),
                                ("0b010", 2), ("0o10", 8)):
            with self.subTest(value=value):
                self.assertEqual(_literal_int(value), expected)

    def test_mapping_error_coordinates_follow_source_order(self):
        self.payload["mapping"]["rows"] = [
            {"mode": "1", "lane0": "9-0", "lane1": "0-1"},
            {"mode": "0", "lane0": "0-0", "lane1": "0-1"},
        ]
        with self.assertRaises(ValidationError) as caught:
            load_generation_plan_from_payload(self.payload, GenerationOptions())
        issue = next(issue for issue in caught.exception.issues if "undefined ctrl_id" in issue.message)
        self.assertEqual((issue.table, issue.row, issue.column), ("mapping", 0, 1))
