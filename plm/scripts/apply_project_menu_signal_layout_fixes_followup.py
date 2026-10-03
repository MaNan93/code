from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(relative, old, new):
    path = ROOT / relative
    text = path.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"anchor not found in {relative}: {old[:180]!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


# CsvTableEditor builds the menu used by the screenshot/right-click entry point.
replace_once(
    "src/plm/frontend/qt/widgets/config_editor.py",
    '''from plm.frontend.qt.widgets.lanegrid import LaneGrid\nfrom plm.frontend.qt.widgets.tables import EditableTable\n''',
    '''from plm.frontend.qt.widgets.common import StyledMenu\nfrom plm.frontend.qt.widgets.lanegrid import LaneGrid\nfrom plm.frontend.qt.widgets.tables import EditableTable\n''',
)
replace_once(
    "src/plm/frontend/qt/widgets/config_editor.py",
    "        menu = QtWidgets.QMenu(self.table)\n",
    "        menu = StyledMenu(self.table)\n",
)

# Functional tests should mock the menu class actually used after the fix.
replace_once(
    "tests/test_qt_controls.py",
    '"plm.frontend.qt.widgets.tables.QtWidgets.QMenu",\n            self._menu_class_selecting("在下方插入行"),',
    '"plm.frontend.qt.widgets.tables.StyledMenu",\n            self._menu_class_selecting("在下方插入行"),',
)
replace_once(
    "tests/test_qt_controls.py",
    '"plm.frontend.qt.widgets.tables.QtWidgets.QMenu",\n            self._menu_class_selecting("删除当前行"),',
    '"plm.frontend.qt.widgets.tables.StyledMenu",\n            self._menu_class_selecting("删除当前行"),',
)
replace_once(
    "tests/test_qt_controls.py",
    '"plm.frontend.qt.widgets.lanegrid.QtWidgets.QMenu",\n            self._menu_class_selecting("Insert row below"),',
    '"plm.frontend.qt.widgets.lanegrid.StyledMenu",\n            self._menu_class_selecting("Insert row below"),',
)
replace_once(
    "tests/test_qt_controls.py",
    '"plm.frontend.qt.widgets.lanegrid.QtWidgets.QMenu",\n            self._menu_class_selecting("Delete current row"),',
    '"plm.frontend.qt.widgets.lanegrid.StyledMenu",\n            self._menu_class_selecting("Delete current row"),',
)

print("follow-up menu patch applied")
