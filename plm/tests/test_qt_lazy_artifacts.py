"""Selected-file reads and bounded current/previous preview caching."""

import os
import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5 import QtWidgets
from plm.frontend.qt.views.artifacts_panel import ArtifactsPanel
from qt_test_support import dispose_new_widgets, wait_for_idle


class LazyArtifactTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.addCleanup(dispose_new_widgets, self.app, set(self.app.topLevelWidgets()))
        self.root = Path(self.temp.name).resolve()
        self.panel = ArtifactsPanel()
        self.reads = []
        original = self.panel._read_contents

        def read(files):
            self.reads.extend(files)
            return original(files)

        self.reader_patch = patch.object(self.panel, "_read_contents", read)
        self.reader_patch.start()
        self.addCleanup(self.reader_patch.stop)

    def file(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def select(self, path):
        self.assertTrue(self.panel.select_file(path))
        wait_for_idle(self.app)

    def test_only_selected_file_is_read_and_revisits_hit_cache(self):
        files = [self.file(f"rtl/{index}.sv", f"module m{index}; endmodule") for index in range(100)]
        self.panel.set_files(files, self.root)
        wait_for_idle(self.app)
        self.assertEqual(self.reads, [self.panel.current_path])
        first = self.panel.current_path
        second = next(path for path in files if path != first)
        self.select(second)
        self.select(first)
        self.assertEqual(self.reads, [first, second])
        self.assertEqual(self.panel.preview.toPlainText(), first.read_text(encoding="utf-8"))

    def test_lru_eviction_allows_small_files_after_budget_is_full(self):
        files = [self.file(f"rtl/{index}.txt", str(index) * 40) for index in range(3)]
        small = self.file("rtl/small.sv", "module small; endmodule")
        with patch("plm.frontend.qt.views.artifact_preview.MAX_PREVIEW_CACHE_BYTES", 85):
            self.panel.set_files([*files, small], self.root)
            wait_for_idle(self.app)
            self.select(files[1])
            self.select(files[0])  # Make file 0 more recently used than file 1.
            self.select(files[2])
            self.assertIn(str(files[0]), self.panel._current_contents)
            self.assertNotIn(str(files[1]), self.panel._current_contents)
            self.select(small)
            self.assertEqual(self.panel.preview.toPlainText(), "module small; endmodule")
            self.assertTrue(self.panel._readable)
            self.assertLessEqual(self.panel._content_cache_bytes, 85)
            self.select(files[1])
            self.assertEqual(self.reads.count(files[1]), 2)

    def test_refresh_retains_previous_selected_content_for_diff(self):
        path = self.file("rtl/demo.sv", "module before; endmodule\n")
        self.panel.set_files([path], self.root)
        wait_for_idle(self.app)
        path.write_text("module after; endmodule\n", encoding="utf-8")
        self.panel.set_files([path], self.root)
        wait_for_idle(self.app)
        self.assertTrue(self.panel.diff_button.isEnabled())
        self.panel.diff_button.setChecked(True)
        wait_for_idle(self.app)
        self.assertIn("-module before;", self.panel.preview.toPlainText())
        self.assertIn("+module after;", self.panel.preview.toPlainText())
        self.panel.diff_button.setChecked(False)
        wait_for_idle(self.app)
        self.assertEqual(self.panel.preview.toPlainText(), "module after; endmodule\n")
        self.panel.set_files([path], self.root / "other")
        wait_for_idle(self.app)
        self.assertFalse(self.panel.diff_button.isEnabled())

    def test_diff_stays_checked_across_regeneration_and_file_switch(self):
        path = self.file("rtl/demo.sv", "module before; endmodule\n")
        self.panel.set_files([path], self.root)
        wait_for_idle(self.app)
        path.write_text("module after; endmodule\n", encoding="utf-8")
        self.panel.set_files([path], self.root)
        wait_for_idle(self.app)
        self.panel.diff_button.setChecked(True)
        wait_for_idle(self.app)
        self.assertIn("+module after;", self.panel.preview.toPlainText())
        # Regenerating while the toggle is on must not silently drop it: the
        # refresh clears current contents before its worker read lands, and
        # that read window used to read as "no diff available".
        path.write_text("module final; endmodule\n", encoding="utf-8")
        self.panel.set_files([path], self.root, statuses={"rtl/demo.sv": "Modified"})
        wait_for_idle(self.app)
        self.assertTrue(self.panel.diff_button.isChecked())
        self.assertTrue(self.panel.diff_button.isEnabled())
        self.assertIn("+module final;", self.panel.preview.toPlainText())
        # The status line reports the file's own size, not the pending diff's.
        self.assertEqual(self.panel._file_status, "1/1 · 1 行")
        # A file with no previous preview has no baseline, so it turns off.
        other = self.file("rtl/fresh.sv", "module fresh; endmodule\n")
        self.panel.set_files([path, other], self.root, statuses={"rtl/fresh.sv": "New"})
        wait_for_idle(self.app)
        self.panel.select_file(other)
        wait_for_idle(self.app)
        self.assertFalse(self.panel.diff_button.isEnabled())
        self.assertFalse(self.panel.diff_button.isChecked())

    def test_generation_baselines_cover_files_that_were_never_previewed(self):
        first = self.file("rtl/first.sv", "module first; endmodule\n")
        second = self.file("rtl/second.sv", "module second; endmodule\n")
        self.panel.set_files([first, second], self.root)  # only first is read
        wait_for_idle(self.app)
        first.write_text("module first_v2; endmodule\n", encoding="utf-8")
        second.write_text("module second_v2; endmodule\n", encoding="utf-8")
        self.panel.set_files(
            [first, second], self.root,
            statuses={"rtl/first.sv": "Modified", "rtl/second.sv": "Modified"},
            baselines={
                "rtl/first.sv": "module first; endmodule\n",
                "rtl/second.sv": "module second; endmodule\n",
            },
        )
        wait_for_idle(self.app)
        self.assertEqual(len(self.panel._previous_contents), 2)
        self.select(second)  # never previewed before this generation
        self.assertTrue(self.panel.diff_button.isEnabled())
        self.panel.diff_button.setChecked(True)
        wait_for_idle(self.app)
        self.assertIn("-module second;", self.panel.preview.toPlainText())
        self.assertIn("+module second_v2;", self.panel.preview.toPlainText())

    def test_refresh_preserves_generation_diff_until_next_generation(self):
        path = self.file("rtl/demo.sv", "module after; endmodule\n")
        self.panel.set_files(
            [path], self.root, statuses={"rtl/demo.sv": "Modified"},
            baselines={"rtl/demo.sv": "module before; endmodule\n"},
        )
        wait_for_idle(self.app)
        self.panel.diff_button.click()
        wait_for_idle(self.app)
        original_diff = self.panel.preview.toPlainText()
        for _ in range(2):
            self.panel.set_files([path], self.root)
            wait_for_idle(self.app)
            self.assertTrue(self.panel.diff_button.isEnabled())
            self.assertTrue(self.panel.diff_button.isChecked())
            self.assertEqual(self.panel.preview.toPlainText(), original_diff)

        path.write_text("module final; endmodule\n", encoding="utf-8")
        self.panel.set_files(
            [path], self.root, statuses={"rtl/demo.sv": "Modified"},
            baselines={"rtl/demo.sv": "module after; endmodule\n"},
        )
        wait_for_idle(self.app)
        self.assertTrue(self.panel.diff_button.isChecked())
        self.assertIn("-module after;", self.panel.preview.toPlainText())
        self.assertIn("+module final;", self.panel.preview.toPlainText())
        self.assertNotIn("module before;", self.panel.preview.toPlainText())

        self.panel.set_files(
            [path], self.root, statuses={"rtl/demo.sv": "Unchanged"}, baselines={},
        )
        wait_for_idle(self.app)
        self.assertFalse(self.panel.diff_button.isEnabled())
        self.assertFalse(self.panel.diff_button.isChecked())
        self.assertEqual(self.panel.preview.toPlainText(), "module final; endmodule\n")

    def test_refresh_unchecks_diff_when_file_matches_baseline_again(self):
        original = "module before; endmodule\n"
        path = self.file("rtl/demo.sv", "module after; endmodule\n")
        self.panel.set_files([path], self.root, baselines={"rtl/demo.sv": original})
        wait_for_idle(self.app)
        self.panel.diff_button.click()
        wait_for_idle(self.app)
        path.write_bytes(original.encode("utf-8"))
        self.panel.set_files([path], self.root)
        wait_for_idle(self.app)
        self.assertFalse(self.panel.diff_button.isEnabled())
        self.assertFalse(self.panel.diff_button.isChecked())
        self.assertEqual(self.panel.preview.toPlainText(), original)

    def test_rapid_selection_skips_intermediate_pending_reads(self):
        files = [self.file(f"rtl/{index}.sv", f"module m{index}; endmodule") for index in range(10)]
        started, release = threading.Event(), threading.Event()
        original = self.panel._read_contents

        def blocked(paths):
            if paths == [files[0]]:
                started.set()
                release.wait(2)
            return original(paths)

        with patch.object(self.panel, "_read_contents", blocked):
            self.panel.set_files(files, self.root)
            try:
                self.assertTrue(started.wait(1))
                for path in files[1:]:
                    self.assertTrue(self.panel.select_file(path))
                self.assertLessEqual(len(self.panel.tasks._tasks), 2)
            finally:
                release.set()
            wait_for_idle(self.app)
        self.assertEqual(self.reads, [files[0], files[-1]])
        self.assertEqual(self.panel.preview.toPlainText(), "module m9; endmodule")

    def test_repeated_refresh_preserves_last_successful_diff_baseline(self):
        path = self.file("rtl/demo.sv", "module before; endmodule\n")
        self.panel.set_files([path], self.root)
        wait_for_idle(self.app)
        path.write_text("module after; endmodule\n", encoding="utf-8")
        started, release = threading.Event(), threading.Event()
        original = self.panel._read_contents

        def blocked(paths):
            started.set()
            release.wait(2)
            return original(paths)

        with patch.object(self.panel, "_read_contents", blocked):
            self.panel.set_files([path], self.root)
            try:
                self.assertTrue(started.wait(1))
                self.panel.set_files([path], self.root)
            finally:
                release.set()
            wait_for_idle(self.app)
        self.assertEqual(self.panel.preview.toPlainText(), "module after; endmodule\n")
        self.assertTrue(self.panel.diff_button.isEnabled())
        self.panel.diff_button.setChecked(True)
        wait_for_idle(self.app)
        self.assertIn("-module before;", self.panel.preview.toPlainText())
        self.assertIn("+module after;", self.panel.preview.toPlainText())


if __name__ == "__main__":
    unittest.main()
