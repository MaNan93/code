import os
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from qt_test_support import dispose_new_widgets
from PyQt5 import QtTest, QtWidgets

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
        self.assertFalse(hasattr(editor, "sel_mode"))
        self.assertEqual(editor.bus_type.currentText(), "legacy_bus")
        self.assertEqual(
            editor.flags(),
            {
                "arch": "legacy_arch",
                "pclk-mode": "legacy_pclk",
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
        self.assertEqual(editor.generate_btn.text(), "生成 RTL / TB")

    def test_prefix_inputs_keep_stable_names_and_localized_labels(self):
        editor = GenerationEditor()
        for name, label in (("module_prefix", "模块名前缀"),
                            ("file_prefix", "文件名前缀"), ("macro_prefix", "宏名前缀")):
            with self.subTest(name=name):
                control = getattr(editor, name)
                self.assertIsInstance(control, QtWidgets.QLineEdit)
                self.assertEqual(control.text(), "")
                self.assertEqual(editor.naming_card.layout().labelForField(control).text(), label)
                self.assertEqual(control.accessibleName(), name)
                self.assertNotIn(name, editor.flags())

    def test_loading_prefixes_is_silent_and_old_projects_clear_previous_values(self):
        editor = GenerationEditor()
        changed = QtTest.QSignalSpy(editor.changed)
        prefixes = {"module_prefix": "soc_", "file_prefix": "rtl_", "macro_prefix": "SOC_"}
        editor.set_flags(prefixes)
        self.assertEqual(len(changed), 0)
        for name, value in prefixes.items():
            self.assertEqual(getattr(editor, name).text(), value)
            self.assertEqual(editor.flags()[name], value)
        editor.set_flags({})
        self.assertEqual(len(changed), 0)
        for name in prefixes:
            self.assertEqual(getattr(editor, name).text(), "")
            self.assertNotIn(name, editor.flags())

    def test_each_prefix_edit_emits_one_change(self):
        editor = GenerationEditor()
        changed = QtTest.QSignalSpy(editor.changed)
        for name in ("module_prefix", "file_prefix", "macro_prefix"):
            getattr(editor, name).setText("example_")
        self.assertEqual(len(changed), 3)


if __name__ == "__main__":
    unittest.main()
