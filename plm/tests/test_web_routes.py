from pathlib import Path
import tempfile
import unittest
from unittest import mock

from plm.core.paths import WORKSPACE_MARKER
from plm.core.workspace import save_workspace_content
from plm.frontend.web.workspace_state import ApiError

try:
    from plm.frontend.web import routes
except ModuleNotFoundError as exc:
    if exc.name != "flask":
        raise
    routes = None

from test_core import valid_payload


@unittest.skipIf(routes is None, "Flask optional dependency is not installed")
class WebWorkspaceSafetyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def workspace(self, name):
        path = self.root / name
        save_workspace_content(path, valid_payload())
        return path

    def test_open_rejects_an_arbitrary_directory(self):
        ordinary = self.root / "ordinary"
        ordinary.mkdir()
        with self.assertRaises(ApiError):
            routes.api_workspace_open({}, {"path": str(ordinary)})

    def test_delete_rejects_unmarked_legacy_workspace(self):
        ws = self.workspace("legacy")
        (ws / WORKSPACE_MARKER).unlink()
        with self.assertRaises(ApiError):
            routes.api_workspace_delete({}, {"path": str(ws)})
        self.assertTrue(ws.is_dir())

    def test_delete_removes_a_marked_workspace(self):
        ws = self.workspace("marked")
        routes.api_workspace_delete({}, {"path": str(ws)})
        self.assertFalse(ws.exists())

    def test_save_uses_explicit_workspace_not_global_state(self):
        intended = self.workspace("intended")
        wrong = self.workspace("wrong")
        routes.current_workspace = wrong
        payload = valid_payload()
        payload["workspace"] = str(intended)
        payload["controllers"][0]["ctrl_name"] = "IntendedOnly"
        routes.api_workspace_save({}, payload)
        self.assertIn("IntendedOnly", (intended / "config" / "controllers.csv").read_text())
        self.assertNotIn("IntendedOnly", (wrong / "config" / "controllers.csv").read_text())

    def test_generate_snapshots_workspace_for_all_targets(self):
        intended = self.workspace("intended")
        wrong = self.workspace("wrong")
        commands = []

        class FakeProcess:
            def __init__(self, command, **_kwargs):
                commands.append(command)
                self.stdout = []
                self.returncode = 0

            def wait(self):
                return 0

        stream = routes.stream_generate(["rtl", "tb"], workspace=str(intended))
        next(stream)  # first command log
        routes.current_workspace = wrong
        with mock.patch.object(routes.subprocess, "Popen", FakeProcess):
            list(stream)
        self.assertEqual(len(commands), 2)
        self.assertTrue(all(str(intended.resolve()) in command for command in commands))
        self.assertTrue(all(str(wrong.resolve()) not in command for command in commands))


if __name__ == "__main__":
    unittest.main()
