"""Generated-file listing avoids simulator trees and external manifest targets."""

import json
import os
import tempfile
import unittest
from contextlib import ExitStack
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from plm.core.plan import MANIFEST_SCHEMA_VERSION
from plm.frontend.qt.services.workspaces import WorkspaceService


class WorkspaceArtifactListingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        self.root = self.base / "workspace"
        (self.root / "config").mkdir(parents=True)
        self.project = SimpleNamespace(config_dir=self.root / "config")
        self.service = WorkspaceService()

    def file(self, name, content="module artifact; endmodule\n"):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        return path.resolve()

    def manifests(self, rtl_files, tb_files):
        for kind, files in (("rtl", rtl_files), ("tb", tb_files)):
            manifest = {
                "schema_version": MANIFEST_SCHEMA_VERSION,
                "output": kind,
                "generation_key": "0" * 64,
                "config_hash": "1" * 64,
                "generator_fingerprint": "2" * 64,
                "formatter": {},
                "options": {},
                "design": {},
                "files": {name: "3" * 64 for name in files},
            }
            self.file(f"{kind}/manifest.json", json.dumps(manifest))

    def safe_reads(self):
        read_text = Path.read_text

        def guarded_read(path, *args, **kwargs):
            self.assertTrue(
                path.resolve().is_relative_to(self.root),
                f"Read escaped the workspace: {path}",
            )
            return read_text(path, *args, **kwargs)

        return patch.object(Path, "read_text", guarded_read)

    def external_link(self, source, target):
        # Simulate link resolution so this regression also runs on Windows hosts
        # without the privilege required by Path.symlink_to().
        resolve = Path.resolve
        is_symlink = Path.is_symlink

        def linked_resolve(path, *args, **kwargs):
            try:
                relative = path.relative_to(source)
            except ValueError:
                return resolve(path, *args, **kwargs)
            return resolve(target / relative, *args, **kwargs)

        def linked_is_symlink(path):
            return path == source or is_symlink(path)

        stack = ExitStack()
        stack.enter_context(patch.object(Path, "resolve", linked_resolve))
        stack.enter_context(patch.object(Path, "is_symlink", linked_is_symlink))
        return stack

    def test_valid_manifests_list_only_managed_files_and_skip_missing_entries(self):
        generated = self.file("rtl/src/generated.sv")
        bench = self.file("tb/bench.sv")
        self.file("rtl/src/unmanaged.sv")
        self.file("tb/csrc/huge_generated_source.sv")
        self.file("tb/simv.daidir/large_database")
        self.file("tb/waves.fsdb")
        self.manifests(["src/generated.sv", "missing.sv"], ["bench.sv"])
        with patch(
            "plm.frontend.qt.services.workspaces.os.walk",
            side_effect=AssertionError("Valid manifests must avoid recursive scanning"),
        ):
            files = self.service.output_files(self.project)
        self.assertEqual(files, sorted([
            generated, bench,
            self.root / "rtl/manifest.json", self.root / "tb/manifest.json",
        ]))

    def test_legacy_scan_prunes_simulator_directories_and_ignores_waveforms(self):
        generated = self.file("rtl/src/generated.sv")
        bench = self.file("tb/bench.sv")
        makefile = self.file("tb/makefile", "all:\n")
        for directory in ("csrc", "simv.daidir", "obj_dir", "DVEfiles", "verdiLog"):
            self.file(f"tb/{directory}/should_not_be_visited.sv")
        for name in ("waves.VCD", "waves.fsdb", "waves.vpd", "simv", "simv.exe", "unit.o"):
            self.file(f"tb/{name}")
        walk = os.walk
        visited = []

        def observed_walk(*args, **kwargs):
            for entry in walk(*args, **kwargs):
                visited.append(Path(entry[0]))
                yield entry

        with patch("plm.frontend.qt.services.workspaces.os.walk", observed_walk):
            files = self.service.output_files(self.project)
        self.assertEqual(files, sorted([generated, bench, makefile]))
        self.assertTrue(all(
            not any(
                part in {"csrc", "obj_dir", "DVEfiles", "verdiLog"}
                or part.endswith(".daidir")
                for part in path.relative_to(self.root).parts
            )
            for path in visited
        ))

    def test_unsafe_manifest_names_cannot_escape_during_fallback(self):
        generated = self.file("rtl/src/generated.sv")
        bench = self.file("tb/bench.sv")
        outside = self.base / "outside.sv"
        outside.write_text("external", encoding="utf-8")
        self.manifests(["src/generated.sv", "../../outside.sv"], ["bench.sv"])
        with self.safe_reads():
            files = self.service.output_files(self.project)
        self.assertNotIn(outside, files)
        self.assertEqual(files, sorted([
            generated, bench,
            self.root / "rtl/manifest.json", self.root / "tb/manifest.json",
        ]))

    def test_external_file_link_is_not_returned_from_a_valid_manifest(self):
        generated = self.file("rtl/src/generated.sv")
        self.file("rtl/src/link.sv")
        bench = self.file("tb/bench.sv")
        outside = self.base / "outside.sv"
        outside.write_text("external", encoding="utf-8")
        self.manifests(["src/generated.sv", "src/link.sv"], ["bench.sv"])
        with self.external_link(self.root / "rtl/src/link.sv", outside), self.safe_reads():
            files = self.service.output_files(self.project)
        self.assertEqual(files, sorted([
            generated, bench,
            self.root / "rtl/manifest.json", self.root / "tb/manifest.json",
        ]))

    def test_external_manifest_link_is_not_read(self):
        generated = self.file("rtl/src/generated.sv")
        bench = self.file("tb/bench.sv")
        self.manifests(["src/generated.sv"], ["bench.sv"])
        source = self.root / "rtl/manifest.json"
        outside = self.base / "outside-manifest.json"
        outside.write_text(source.read_text(encoding="utf-8"), encoding="utf-8")
        with self.external_link(source, outside), self.safe_reads():
            files = self.service.output_files(self.project)
        self.assertNotIn(outside, files)
        self.assertIn(generated, files)
        self.assertIn(bench, files)

    def test_external_output_directory_is_not_read_or_listed(self):
        self.file("rtl/src/generated.sv")
        bench = self.file("tb/bench.sv")
        self.manifests(["src/generated.sv"], ["bench.sv"])
        outside = self.base / "external-rtl"
        outside.mkdir()
        (outside / "leak.sv").write_text("external", encoding="utf-8")
        with self.external_link(self.root / "rtl", outside), self.safe_reads():
            files = self.service.output_files(self.project)
        self.assertTrue(all(path.is_relative_to(self.root) for path in files))
        self.assertIn(bench, files)


if __name__ == "__main__":
    unittest.main()
