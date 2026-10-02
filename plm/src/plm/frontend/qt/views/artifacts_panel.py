import shutil
import subprocess
from pathlib import Path
from PyQt5 import QtCore, QtWidgets
from plm.frontend.qt.models.preferences import DEFAULT_EDITOR
from plm.frontend.qt.widgets.common import ICON_SIZE, apply_drop_shadow, make_icon_button

class DiffLine(QtWidgets.QWidget):
    def __init__(self, old_number, new_number, text, mode="ctx", parent=None):
        super().__init__(parent)
        self.setObjectName("DiffLine")
        self.setProperty("mode", mode)
        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        for number in (old_number, new_number):
            label = QtWidgets.QLabel("" if number is None else str(number))
            label.setObjectName("DiffLineNumber")
            label.setFixedWidth(32)
            label.setAlignment(QtCore.Qt.AlignRight | QtCore.Qt.AlignVCenter)
            layout.addWidget(label)
        prefix = "+" if mode == "add" else "-" if mode == "del" else " "
        code = QtWidgets.QLabel(f"{prefix} {text}")
        code.setObjectName("DiffCode")
        code.setTextInteractionFlags(QtCore.Qt.TextSelectableByMouse)
        layout.addWidget(code, 1)


class FileDiffCard(QtWidgets.QFrame):
    def __init__(self, file_path, lines, parent=None, editor_path_provider=None,
                 display_path=None, marker_text="M"):
        super().__init__(parent)
        self.editor_path_provider = editor_path_provider or (lambda: DEFAULT_EDITOR)
        self.file_path = Path(file_path)
        self.setObjectName("FileDiffCard")
        self.setSizePolicy(QtWidgets.QSizePolicy.Expanding, QtWidgets.QSizePolicy.Fixed)
        self.setMinimumHeight(52 + len(lines) * 24)
        apply_drop_shadow(self)
        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 8)
        root.setSpacing(0)
        header = QtWidgets.QWidget()
        header.setObjectName("FileCardHeader")
        header_layout = QtWidgets.QHBoxLayout(header)
        header_layout.setContentsMargins(16, 12, 16, 12)
        header_layout.setSpacing(8)
        marker = QtWidgets.QLabel(marker_text)
        marker.setObjectName("ModifiedMarker")
        marker.setAlignment(QtCore.Qt.AlignCenter)
        marker.setFixedSize(20, 18)
        header_layout.addWidget(marker)
        path_label = QtWidgets.QLabel(str(display_path or file_path))
        path_label.setObjectName("FilePathLabel")
        path_label.setTextInteractionFlags(QtCore.Qt.TextSelectableByMouse)
        header_layout.addWidget(path_label, 1)
        copy_btn = make_icon_button("link", "复制路径", "CardActionButton", 24, 16)
        open_btn = make_icon_button(
            "square-pen", "在编辑器中打开", "CardActionButton", 24, 16
        )
        copy_btn.clicked.connect(self.copy_path)
        open_btn.clicked.connect(self.open_in_editor)
        header_layout.addWidget(copy_btn)
        header_layout.addWidget(open_btn)
        root.addWidget(header)
        for old_number, new_number, text, mode in lines:
            root.addWidget(DiffLine(old_number, new_number, text, mode))

    def copy_path(self):
        QtWidgets.QApplication.clipboard().setText(str(self.file_path))

    def open_in_editor(self):
        editor = self.editor_path_provider()
        configured_path = Path(editor).expanduser()
        executable = str(configured_path) if configured_path.is_file() else shutil.which(editor)
        if executable is None:
            QtWidgets.QMessageBox.warning(
                self, "无法打开编辑器", f"未找到 {editor}，请先安装并加入 PATH。"
            )
            return
        try:
            subprocess.Popen([executable, str(self.file_path)])
        except OSError as error:
            QtWidgets.QMessageBox.warning(self, "无法打开编辑器", str(error))


class ArtifactsPanel(QtWidgets.QFrame):
    """Region 5: floating generated-file and diff viewer."""

    maximizeRequested = QtCore.pyqtSignal()
    refreshRequested = QtCore.pyqtSignal()

    def __init__(self, parent=None, editor_path_provider=None):
        super().__init__(parent)
        self.editor_path_provider = editor_path_provider
        self.setObjectName("ArtifactsPanel")
        apply_drop_shadow(self, offset=(0, 2), blur_radius=12, alpha=30)
        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(12, 0, 12, 12)
        root.setSpacing(12)
        toolbar = QtWidgets.QWidget()
        toolbar.setObjectName("ArtifactsToolbar")
        toolbar.setFixedHeight(40)
        toolbar_layout = QtWidgets.QHBoxLayout(toolbar)
        toolbar_layout.setContentsMargins(16, 0, 16, 0)
        toolbar_layout.setSpacing(8)
        self.toolbar_buttons = []
        for index, (icon_name, tooltip) in enumerate(
            (
                ("folder", "打开文件夹"),
                ("refresh-cw", "刷新"),
                ("square-pen", "编辑"),
                ("braces", "查看代码"),
                ("search", "搜索"),
                ("link", "复制链接"),
                ("file", "文件"),
                ("more-horizontal", "更多"),
                ("maximize", "展开"),
            )
        ):
            button = make_icon_button(
                icon_name, tooltip, "ArtifactsToolButton", 24, ICON_SIZE
            )
            toolbar_layout.addWidget(button)
            self.toolbar_buttons.append(button)
            if index == 0:
                toolbar_layout.addStretch(1)
        self.toolbar_buttons[-1].clicked.connect(self.maximizeRequested.emit)
        self.toolbar_buttons[1].clicked.connect(self.refreshRequested.emit)
        root.addWidget(toolbar)

        scroll = QtWidgets.QScrollArea()
        scroll.setObjectName("ArtifactsScroll")
        scroll.setWidgetResizable(True)
        scroll.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarAlwaysOff)
        content = QtWidgets.QWidget()
        content.setObjectName("ArtifactsContent")
        content_layout = QtWidgets.QVBoxLayout(content)
        content_layout.setContentsMargins(0, 0, 0, 0)
        content_layout.setSpacing(12)
        content_layout.setSizeConstraint(QtWidgets.QLayout.SetMinAndMaxSize)
        self.content_layout = content_layout
        self.empty_label = QtWidgets.QLabel("尚无生成文件")
        self.empty_label.setObjectName("ArtifactsEmptyLabel")
        content_layout.addWidget(self.empty_label)
        content_layout.addStretch(1)
        scroll.setWidget(content)
        root.addWidget(scroll, 1)

    def set_files(self, files, root=None):
        for card in self.findChildren(FileDiffCard):
            self.content_layout.removeWidget(card)
            card.deleteLater()
        self.empty_label.setVisible(not files)
        for path in files:
            path = Path(path)
            try:
                display = path.relative_to(root) if root else path.name
            except ValueError:
                display = path.name
            try:
                preview = path.read_text(encoding="utf-8").splitlines()[:4]
            except (OSError, UnicodeError):
                preview = ["无法预览该文件"]
            lines = [(index, index, line[:100], "ctx")
                     for index, line in enumerate(preview, start=1)]
            card = FileDiffCard(path, lines, editor_path_provider=self.editor_path_provider,
                                display_path=display, marker_text="F")
            self.content_layout.insertWidget(self.content_layout.count() - 1, card)
