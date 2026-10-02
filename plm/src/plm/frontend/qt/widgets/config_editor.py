"""Editable CSV tables and generation controls used by ConfigPage."""

import weakref

from PyQt5 import QtCore, QtGui, QtWidgets, sip


class LaneSelector(QtWidgets.QWidget):
    """Choose a controller and one of its lanes without changing CSV syntax."""

    def __init__(self, controllers, parent=None):
        super().__init__(parent)
        self.controllers = controllers
        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(4)
        self.controller = QtWidgets.QComboBox()
        self.lane = QtWidgets.QComboBox()
        self.setFocusPolicy(QtCore.Qt.StrongFocus)
        self.setFocusProxy(self.controller)
        self.controller.addItem("选择控制器", None)
        for row in controllers:
            try:
                cid, width = int(row["ctrl_id"]), int(row["max_width"])
            except (KeyError, ValueError):
                continue
            if cid >= 0 and 0 < width <= 64:
                self.controller.addItem(f"{row.get('ctrl_name', '')} ({cid})", (cid, width))
        layout.addWidget(self.controller)
        layout.addWidget(self.lane)
        self.controller.currentIndexChanged.connect(self._controller_changed)
        self.lane.currentIndexChanged.connect(self._mark_changed)
        self._changed = False
        self._original = ""

    def _mark_changed(self):
        self._changed = True

    def _controller_changed(self):
        self.lane.clear()
        choice = self.controller.currentData()
        if choice:
            for lane in range(choice[1]):
                self.lane.addItem(str(lane), lane)
        self._changed = True

    def set_value(self, value):
        self._original = value
        try:
            cid, lane = map(int, value.split("-"))
        except ValueError:
            cid, lane = None, None
        for index in range(1, self.controller.count()):
            if self.controller.itemData(index)[0] == cid:
                self.controller.setCurrentIndex(index)
                self.lane.setCurrentIndex(self.lane.findData(lane))
                break
        self._changed = False

    def value(self):
        choice = self.controller.currentData()
        lane = self.lane.currentData()
        if not self._changed or choice is None or lane is None:
            return self._original
        return f"{choice[0]}-{lane}"


class ConfigDelegate(QtWidgets.QStyledItemDelegate):
    def __init__(self, owner):
        super().__init__(owner.table)
        self.owner = owner
        self._lane_editor = None

    def createEditor(self, parent, option, index):
        key = self.owner.columns()[index.column()]
        if self.owner.mapping and index.column() > 0:
            editor = LaneSelector(self.owner.controllers, parent)
            self._lane_editor = editor
            editor.controller.installEventFilter(self)
            editor.lane.installEventFilter(self)
            return editor
        enums = {"signal_type": ("perlane", "shared"), "direction": ("mac2phy", "phy2mac")}
        if key in enums:
            editor = QtWidgets.QComboBox(parent)
            choices = enums[key]
            if key == "signal_type" and index.sibling(index.row(), 2).data() == "phy2mac":
                choices = ("perlane",)
            editor.addItems(choices)
            return editor
        editor = QtWidgets.QLineEdit(parent)
        if key in ("ctrl_id", "mode", "max_width", "width"):
            editor.setValidator(QtGui.QIntValidator(1 if key in ("max_width", "width") else 0, 2147483647, editor))
        elif key in ("ctrl_name", "signal_name"):
            editor.setValidator(QtGui.QRegularExpressionValidator(QtCore.QRegularExpression(r"[a-zA-Z_][a-zA-Z0-9_$]*"), editor))
        elif key in ("safe_state", "tie_off"):
            pattern = r"(?:0[xX][0-9a-fA-F]+|0[bB][01]+|0[oO][0-7]+|[0-9]+)"
            if key == "tie_off":
                pattern = "(?:lane0|" + pattern + ")"
            editor.setValidator(QtGui.QRegularExpressionValidator(QtCore.QRegularExpression(pattern), editor))
        return editor

    @property
    def _lane_editor(self):
        editor = self._lane_editor_ref() if self._lane_editor_ref else None
        return editor if editor is not None and not sip.isdeleted(editor) else None

    @_lane_editor.setter
    def _lane_editor(self, editor):
        self._lane_editor_ref = weakref.ref(editor) if editor is not None else None

    def finish_editing(self):
        editor = self._lane_editor
        if editor is not None:
            self._lane_editor = None
            self.commitData.emit(editor)
            self.closeEditor.emit(editor, QtWidgets.QAbstractItemDelegate.NoHint)

    def _commit_if_unfocused(self):
        editor = self._lane_editor
        focus = QtWidgets.QApplication.focusWidget()
        if editor is not None and QtWidgets.QApplication.activePopupWidget() is None:
            if focus is not editor and not (focus and editor.isAncestorOf(focus)):
                self.finish_editing()

    def eventFilter(self, watched, event):
        editor = self._lane_editor
        if editor is not None and (watched is editor or editor.isAncestorOf(watched)):
            if event.type() == QtCore.QEvent.FocusOut:
                QtCore.QTimer.singleShot(0, self._commit_if_unfocused)
            elif event.type() == QtCore.QEvent.KeyPress:
                if event.key() == QtCore.Qt.Key_Escape:
                    self._lane_editor = None
                    self.closeEditor.emit(editor, QtWidgets.QAbstractItemDelegate.RevertModelCache)
                    return True
                if event.key() in (QtCore.Qt.Key_Return, QtCore.Qt.Key_Enter):
                    self.finish_editing()
                    return True
            return False
        return super().eventFilter(watched, event)

    def updateEditorGeometry(self, editor, option, index):
        if isinstance(editor, LaneSelector):
            rect = QtCore.QRect(option.rect)
            rect.setWidth(min(300, self.owner.table.viewport().width()))
            rect.moveLeft(min(rect.left(), self.owner.table.viewport().width() - rect.width()))
            editor.setGeometry(rect)
        else:
            super().updateEditorGeometry(editor, option, index)

    def setEditorData(self, editor, index):
        value = index.data(QtCore.Qt.EditRole) or ""
        if isinstance(editor, LaneSelector):
            editor.set_value(value)
        elif isinstance(editor, QtWidgets.QComboBox):
            if editor.findText(value) < 0:
                editor.addItem(value)
            editor.setCurrentText(value)
        else:
            editor.setText(value)

    def setModelData(self, editor, model, index):
        value = editor.value() if isinstance(editor, LaneSelector) else (
            editor.currentText() if isinstance(editor, QtWidgets.QComboBox) else editor.text()
        )
        model.setData(index, value, QtCore.Qt.EditRole)


class CsvTableEditor(QtWidgets.QWidget):
    changed = QtCore.pyqtSignal()

    def __init__(self, columns, mapping=False, parent=None):
        super().__init__(parent)
        self.mapping = mapping
        self.controllers = []
        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(12)
        toolbar = QtWidgets.QHBoxLayout()
        if mapping:
            toolbar.addWidget(QtWidgets.QLabel("Lane 数"))
            self.lane_count = QtWidgets.QSpinBox()
            self.lane_count.setObjectName("LaneCount")
            self.lane_count.setRange(1, 64)
            self.lane_count.setValue(max(1, len(columns) - 1))
            self.lane_count.valueChanged.connect(self._change_lane_count)
            toolbar.addWidget(self.lane_count)
        add_button = QtWidgets.QPushButton("添加行")
        add_button.setObjectName("ConfigRowButton")
        add_button.clicked.connect(self.add_row)
        delete_button = QtWidgets.QPushButton("删除选中行")
        delete_button.setObjectName("ConfigRowButton")
        delete_button.clicked.connect(self.delete_selected_rows)
        toolbar.addWidget(add_button)
        toolbar.addWidget(delete_button)
        toolbar.addStretch(1)
        layout.addLayout(toolbar)

        self.table = QtWidgets.QTableWidget(0, len(columns))
        self.table.setObjectName("ConfigDataTable")
        self.table.setHorizontalHeaderLabels(columns)
        self.table.horizontalHeader().setSectionResizeMode(
            QtWidgets.QHeaderView.ResizeToContents
        )
        self.table.horizontalHeader().setStretchLastSection(True)
        self.table.setAlternatingRowColors(True)
        self.table.setSelectionBehavior(QtWidgets.QAbstractItemView.SelectRows)
        self.table.itemChanged.connect(self.changed.emit)
        self.table.setItemDelegate(ConfigDelegate(self))
        layout.addWidget(self.table, 1)

    def _change_lane_count(self, count):
        columns = ["mode"] + [f"lane{index}" for index in range(count)]
        self.table.blockSignals(True)
        self.table.setColumnCount(len(columns))
        self.table.setHorizontalHeaderLabels(columns)
        self.table.blockSignals(False)
        self.changed.emit()

    def set_rows(self, rows, columns=None):
        self.table.blockSignals(True)
        if columns is not None:
            if self.mapping:
                self.lane_count.blockSignals(True)
                self.lane_count.setValue(len(columns) - 1)
                self.lane_count.blockSignals(False)
            self.table.setColumnCount(len(columns))
            self.table.setHorizontalHeaderLabels(columns)
        self.table.setRowCount(len(rows))
        keys = self.columns()
        for row_index, row in enumerate(rows):
            for col_index, key in enumerate(keys):
                self.table.setItem(row_index, col_index, QtWidgets.QTableWidgetItem(
                    str(row.get(key, ""))
                ))
        self.table.blockSignals(False)

    def columns(self):
        return [self.table.horizontalHeaderItem(i).text()
                for i in range(self.table.columnCount())]

    def set_cell_errors(self, errors):
        self.table.blockSignals(True)
        for row in range(self.table.rowCount()):
            for col in range(self.table.columnCount()):
                item = self.table.item(row, col)
                if item is None:
                    item = QtWidgets.QTableWidgetItem("")
                    self.table.setItem(row, col, item)
                message = errors.get((row, col), "")
                item.setToolTip(message)
                item.setData(QtCore.Qt.UserRole, message)
                item.setBackground(QtGui.QBrush(QtGui.QColor("#FFF1F0")) if message else QtGui.QBrush())
        self.table.blockSignals(False)

    def rows(self):
        keys = self.columns()
        return [
            {key: (self.table.item(row, col).text() if self.table.item(row, col) else "").strip()
             for col, key in enumerate(keys)}
            for row in range(self.table.rowCount())
        ]

    def add_row(self):
        self.table.blockSignals(True)
        index = self.table.rowCount()
        self.table.insertRow(index)
        for col in range(self.table.columnCount()):
            self.table.setItem(index, col, QtWidgets.QTableWidgetItem(""))
        self.table.setCurrentCell(index, 0)
        self.table.blockSignals(False)
        self.changed.emit()

    def delete_selected_rows(self):
        self.table.blockSignals(True)
        selected = {index.row() for index in self.table.selectedIndexes()}
        for row in sorted(selected, reverse=True):
            self.table.removeRow(row)
        self.table.blockSignals(False)
        if selected:
            self.changed.emit()


class GenerationEditor(QtWidgets.QWidget):
    changed = QtCore.pyqtSignal()
    generateRequested = QtCore.pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        layout = QtWidgets.QFormLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(12)
        self.arch = QtWidgets.QComboBox()
        self.arch.addItems(("original_pipe", "serdes"))
        self.pclk_mode = QtWidgets.QComboBox()
        self.pclk_mode.addItems(("pclk_as_phy_output", "pclk_as_phy_input"))
        self.sel_mode = QtWidgets.QComboBox()
        self.sel_mode.addItems(("sync", "comb"))
        self.dpr = QtWidgets.QCheckBox("启用 DPR")
        layout.addRow("PHY 架构", self.arch)
        layout.addRow("PCLK 模式", self.pclk_mode)
        layout.addRow("选择方式", self.sel_mode)
        layout.addRow("DPR", self.dpr)
        self.generate_btn = QtWidgets.QPushButton("Generate RTL + TB")
        self.generate_btn.setObjectName("ConfigGenerateButton")
        self.generate_btn.clicked.connect(self.generateRequested.emit)
        actions = QtWidgets.QHBoxLayout()
        self.status_label = QtWidgets.QLabel("请选择项目")
        self.status_label.setObjectName("GenerationStatus")
        actions.addWidget(self.status_label, 1)
        actions.addWidget(self.generate_btn)
        layout.addRow("", actions)
        self.arch.currentIndexChanged.connect(self._sync_pclk)
        self.pclk_mode.currentIndexChanged.connect(self._sync_arch)
        for control in (self.arch, self.pclk_mode, self.sel_mode):
            control.currentIndexChanged.connect(self.changed.emit)
        self.dpr.toggled.connect(self.changed.emit)

    def set_output_state(self, state, text, detail=""):
        self.status_label.setText(text)
        self.status_label.setToolTip(detail)
        self.status_label.setProperty("state", state)
        self.status_label.style().unpolish(self.status_label)
        self.status_label.style().polish(self.status_label)
        self.generate_btn.setEnabled(state not in ("no_project", "generating"))

    def _sync_pclk(self, index):
        self.pclk_mode.blockSignals(True)
        self.pclk_mode.setCurrentIndex(index)
        self.pclk_mode.blockSignals(False)

    def _sync_arch(self, index):
        self.arch.blockSignals(True)
        self.arch.setCurrentIndex(index)
        self.arch.blockSignals(False)

    def set_flags(self, flags):
        for widget in (self.arch, self.pclk_mode, self.sel_mode, self.dpr):
            widget.blockSignals(True)
        arch = flags.get("arch") or (
            "serdes" if flags.get("pclk-mode") == "pclk_as_phy_input" else "original_pipe"
        )
        self.arch.setCurrentText(arch)
        self.pclk_mode.setCurrentText(flags.get("pclk-mode") or (
            "pclk_as_phy_input" if arch == "serdes" else "pclk_as_phy_output"
        ))
        self.sel_mode.setCurrentText(flags.get("sel-mode") or "sync")
        self.dpr.setChecked(bool(flags.get("dpr")))
        for widget in (self.arch, self.pclk_mode, self.sel_mode, self.dpr):
            widget.blockSignals(False)

    def flags(self):
        return {
            "arch": self.arch.currentText(),
            "pclk-mode": self.pclk_mode.currentText(),
            "sel-mode": self.sel_mode.currentText(),
            "dpr": self.dpr.isChecked(),
        }
