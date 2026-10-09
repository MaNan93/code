import os
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from qt_test_support import dispose_new_widgets
from PyQt5 import QtWidgets

from plm.frontend.qt.widgets.config_editor import GenerationEditor


class GenerationEditorRestoreTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])

    def setUp(self):
        self.addCleanup(dispose_new_widgets, self.app, set(self.app.topLevelWidgets()))

    def test_unknown_loaded_values_are_preserved_until_user_corrects_them(self):
        editor = GenerationEditor()
        editor.set_flags({
            "arch": "legacy_arch",
            "pclk-mode": "legacy_pclk",
            "sel-mode": "legacy_sel",
            "bus-type": "legacy_bus",
            "dpr": False,
        })

        self.assertEqual(editor.arch.currentText(), "legacy_arch")
        self.assertEqual(editor.pclk_mode.currentText(), "legacy_pclk")
        self.assertEqual(editor.sel_mode.currentText(), "legacy_sel")
        self.assertEqual(editor.bus_type.currentText(), "legacy_bus")
        self.assertEqual(
            editor.flags(),
            {
                "arch": "legacy_arch",
                "pclk-mode": "legacy_pclk",
                "sel-mode": "legacy_sel",
                "bus-type": "legacy_bus",
                "dpr": False,
            },
        )

        # Once the user selects a known architecture, PCLK becomes derived
        # again instead of keeping the stale invalid loaded value.
        editor.arch.setCurrentText("serdes")
        self.assertEqual(editor.pclk_mode.currentText(), "pclk_as_phy_input")

    def test_generation_action_uses_the_single_generate_label(self):
        editor = GenerationEditor()
        self.assertEqual(editor.generate_btn.text(), "Generate")


if __name__ == "__main__":
    unittest.main()
