"""Release checks must catch missing resources, stale builds and absent fixtures."""

import importlib.util
import os
from pathlib import Path
import tarfile
import tempfile
import unittest
from zipfile import ZipFile


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("plm_check_wheel", ROOT / "scripts/check_wheel.py")
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)


class PackagingTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="plm packaging test ")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        files = {
            "src/plm/__init__.py": "",
            "src/plm/cli/main.py": "def main(): return 0\n",
            "src/plm/core/common/example.sv": "module example; endmodule\n",
            "src/plm/core/config/pipe_signals.csv": "name,direction\n",
            "src/plm/docs/tool_usage.md": "# Usage\n",
            "src/plm/frontend/qt/styles/app.qss": "QWidget {}\n",
            "scripts/check_wheel.py": "# release check\n",
            "tests/qt_test_support.py": "# shared test helper\n",
            "tests/fixtures/samples/demo/config/controllers.csv": "ctrl_id,ctrl_name,max_width\n",
            "tests/fixtures/golden_hashes.json": "{}\n",
        }
        files.update({name: "# release metadata\n" for name in (
            "README.md", "CLAUDE.md", "MANIFEST.in", "pyproject.toml", "run.py", "uv.lock"
        )})
        for name, content in files.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")

    def wheel(self, replacements=None, omissions=()):
        files = {name: path.read_bytes() for name, path in release.package_files(self.root).items()}
        files["plm-1.0.dist-info/entry_points.txt"] = (
            b"[console_scripts]\nplm = plm.cli.main:main\nplm-gui = plm.frontend.qt.main:main\n"
        )
        files.update(replacements or {})
        path = self.root / "release.whl"
        with ZipFile(path, "w") as archive:
            for name, contents in files.items():
                if name not in omissions:
                    archive.writestr(name, contents)
        return path

    def sdist(self, omissions=(), additions=()):
        path = self.root / "release.tar.gz"
        sources = [source for source in self.root.rglob("*")
                   if source.is_file() and source != path and not source.name.endswith(".whl")]
        for name in additions:
            source = self.root / name
            source.parent.mkdir(parents=True, exist_ok=True)
            source.write_text("unwanted\n", encoding="utf-8")
            sources.append(source)
        with tarfile.open(path, "w:gz") as archive:
            for source in sources:
                name = source.relative_to(self.root).as_posix()
                if name not in omissions:
                    archive.add(source, arcname="plm-1.0/" + name)
        return path

    def test_wheel_checks_modules_and_runtime_resources(self):
        self.assertEqual(release.check_wheel_contents(self.wheel(), self.root), 6)

    def test_wheel_rejects_stale_module_and_resource_bytes(self):
        for name in ("plm/cli/main.py", "plm/core/common/example.sv"):
            with self.subTest(name=name), self.assertRaisesRegex(AssertionError, "stale"):
                release.check_wheel_contents(self.wheel({name: b"old build\n"}), self.root)

    def test_wheel_rejects_missing_runtime_resources(self):
        with self.assertRaisesRegex(AssertionError, "missing=.*example.sv"):
            release.check_wheel_contents(
                self.wheel(omissions=("plm/core/common/example.sv",)), self.root
            )

    def test_wheel_rejects_development_files(self):
        for name in ("tests/test_example.py", "tests/fake.dist-info/hidden.py"):
            with self.subTest(name=name), self.assertRaisesRegex(AssertionError, "extra=.*tests/"):
                release.check_wheel_contents(self.wheel({name: b""}), self.root)

    def test_wheel_rejects_wrong_console_entry_points(self):
        with self.assertRaisesRegex(AssertionError, "entry points"):
            release.check_wheel_contents(self.wheel({
                "plm-1.0.dist-info/entry_points.txt": b"[console_scripts]\nplm = old.main:main\n"
            }), self.root)

    def test_sdist_contains_shared_helpers_and_immutable_fixtures(self):
        release.check_sdist_contents(self.sdist(), self.root)
        for name in ("tests/qt_test_support.py", "tests/fixtures/golden_hashes.json",
                     "tests/fixtures/samples/demo/config/controllers.csv", "scripts/check_wheel.py"):
            with self.subTest(name=name), self.assertRaisesRegex(AssertionError, "missing="):
                release.check_sdist_contents(self.sdist(omissions=(name,)), self.root)

    def test_sdist_rejects_editable_workspaces_and_build_outputs(self):
        for name in ("examples/demo/config/controllers.csv", "test/demo/config/controllers.csv",
                     "build/old.py", "dist/old.whl"):
            with self.subTest(name=name), self.assertRaisesRegex(AssertionError, "unwanted="):
                release.check_sdist_contents(self.sdist(additions=(name,)), self.root)

    def test_sdist_rejects_stale_regression_inputs(self):
        archive = self.sdist()
        (self.root / "tests/fixtures/golden_hashes.json").write_text('{"changed": true}\n')
        with self.assertRaisesRegex(AssertionError, "stale.*golden_hashes.json"):
            release.check_sdist_contents(archive, self.root)

    def test_installed_smoke_isolates_host_tools_without_changing_installation_environment(self):
        scripts = self.root / "environment" / ("Scripts" if os.name == "nt" else "bin")
        installation_env = {"PATH": "host-formatter-directory", "SystemRoot": r"C:\Windows",
                            "QT_QPA_PLATFORM": "offscreen", "PYTHONNOUSERSITE": "1"}
        smoke_env = release.installed_smoke_environment(scripts, installation_env)
        expected_paths = [str(scripts)]
        if os.name == "nt":
            expected_paths.append(str(Path(installation_env["SystemRoot"]) / "System32"))
        self.assertEqual(smoke_env["PATH"].split(os.pathsep), expected_paths)
        self.assertEqual(installation_env["PATH"], "host-formatter-directory")
        self.assertEqual(smoke_env["QT_QPA_PLATFORM"], "offscreen")
        self.assertEqual(smoke_env["PYTHONNOUSERSITE"], "1")


if __name__ == "__main__":
    unittest.main()
