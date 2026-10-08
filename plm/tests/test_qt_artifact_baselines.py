"""Pre-generation diff baselines captured before the generator overwrites."""

import os
import tempfile
import unittest
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from plm.frontend.qt.controllers.workspace_actions import (
    MAX_BASELINE_BYTES, WorkspaceActions,
)


class ArtifactBaselineTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()

    def write(self, relative, text):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        # Bytes, so the host cannot translate newlines behind the snapshot.
        path.write_bytes(text.encode("utf-8"))
        return path

    def test_snapshot_captures_digests_and_text(self):
        one = self.write("rtl/one.sv", "module one;\nendmodule\n")
        two = self.write("rtl/two.sv", "module two;\nendmodule\n")
        signature, texts = WorkspaceActions._artifact_snapshot([one, two], self.root)
        self.assertEqual(sorted(signature), ["rtl/one.sv", "rtl/two.sv"])
        self.assertEqual(sorted(texts), ["rtl/one.sv", "rtl/two.sv"])
        # Compared against the file itself: the host may translate newlines.
        self.assertEqual(texts["rtl/one.sv"], one.read_text(encoding="utf-8"))

    def test_second_pass_can_skip_the_text_capture(self):
        one = self.write("rtl/one.sv", "module one;\nendmodule\n")
        signature, texts = WorkspaceActions._artifact_snapshot([one], self.root, texts=False)
        self.assertIn("rtl/one.sv", signature)
        self.assertEqual(texts, {})

    def test_snapshot_keeps_the_digest_of_files_above_the_cap(self):
        huge = self.write("rtl/huge.sv", "x" * (MAX_BASELINE_BYTES + 8))
        signature, texts = WorkspaceActions._artifact_snapshot([huge], self.root)
        self.assertIn("rtl/huge.sv", signature)
        self.assertNotIn("rtl/huge.sv", texts)

    def test_statuses_carry_the_pre_generation_text_only_for_changes(self):
        before = {"rtl/one.sv": "old-one", "rtl/two.sv": "old-two"}
        texts = {"rtl/one.sv": "old-one", "rtl/two.sv": "old-two"}
        statuses, baselines = WorkspaceActions._artifact_statuses(
            before,
            {"rtl/one.sv": "new-one", "rtl/two.sv": "old-two", "rtl/three.sv": "new-three"},
            texts,
        )
        self.assertEqual(statuses["rtl/one.sv"], "Modified")
        self.assertEqual(statuses["rtl/two.sv"], "Unchanged")
        self.assertEqual(statuses["rtl/three.sv"], "New")
        self.assertEqual(baselines, {"rtl/one.sv": "old-one", "rtl/three.sv": ""})


if __name__ == "__main__":
    unittest.main()
