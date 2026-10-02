from PyQt5 import QtCore, QtWidgets
from plm.frontend.qt.widgets.common import make_icon_button

class SecondaryPage(QtWidgets.QFrame):
    """Full-window Settings or documentation page."""

    closeRequested = QtCore.pyqtSignal()
    preferencesSaved = QtCore.pyqtSignal(dict)

    def __init__(self, page, parent=None):
        super().__init__(parent)
        self.page = page
        self.setObjectName("PlaceholderOverlay")
        self.setAttribute(QtCore.Qt.WA_StyledBackground, True)
        self.setFocusPolicy(QtCore.Qt.StrongFocus)

        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        header = QtWidgets.QFrame()
        header.setObjectName("PlaceholderDialogHeader")
        header.setFixedHeight(56)
        header_layout = QtWidgets.QHBoxLayout(header)
        header_layout.setContentsMargins(20, 0, 20, 0)
        header_layout.setSpacing(12)
        self.back_btn = make_icon_button(
            "arrow-left", "返回", "PlaceholderBackButton", 32, 20, "#333333"
        )
        self.back_btn.clicked.connect(self.closeRequested.emit)
        header_layout.addWidget(self.back_btn)
        self.title_label = QtWidgets.QLabel(
            "Settings" if page == "settings" else "Documentation"
        )
        self.title_label.setObjectName("PlaceholderDialogTitle")
        header_layout.addWidget(self.title_label)
        header_layout.addStretch(1)
        root.addWidget(header)

        page_area = QtWidgets.QWidget()
        page_area.setObjectName("PlaceholderPageArea")
        page_area_layout = QtWidgets.QHBoxLayout(page_area)
        page_area_layout.setContentsMargins(32, 40, 32, 40)
        page_area_layout.setSpacing(0)
        page_area_layout.addStretch(1)

        self.page_panel = QtWidgets.QWidget()
        self.page_panel.setObjectName("PlaceholderPagePanel")
        self.page_panel.setFixedWidth(800)
        self.page_panel.setSizePolicy(
            QtWidgets.QSizePolicy.Expanding, QtWidgets.QSizePolicy.Expanding
        )
        panel_layout = QtWidgets.QVBoxLayout(self.page_panel)
        panel_layout.setContentsMargins(0, 0, 0, 0)
        panel_layout.setSpacing(0)
        self.content = self._build_content()
        panel_layout.addWidget(self._build_menu(page))
        divider = QtWidgets.QFrame()
        divider.setObjectName("PlaceholderTabDivider")
        divider.setFixedHeight(1)
        panel_layout.addWidget(divider)
        panel_layout.addSpacing(24)
        panel_layout.addWidget(self.content, 1)
        page_area_layout.addWidget(self.page_panel, 0)
        page_area_layout.addStretch(1)
        root.addWidget(page_area, 1)
        self._select_section(0)

    def _build_menu(self, page):
        menu = QtWidgets.QWidget()
        menu.setObjectName("PlaceholderTabs")
        layout = QtWidgets.QHBoxLayout(menu)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(8)
        self.menu_buttons = []
        entries = (
            ("General", "Appearance", "Tools")
            if page == "settings"
            else ("Getting Started", "Configuration", "Generation")
        )
        for index, text in enumerate(entries):
            button = QtWidgets.QPushButton(text)
            button.setObjectName("PlaceholderMenuButton")
            button.setCursor(QtCore.Qt.PointingHandCursor)
            button.clicked.connect(
                lambda _checked=False, selected=index: self._select_section(selected)
            )
            layout.addWidget(button)
            self.menu_buttons.append(button)
        layout.addStretch(1)
        return menu

    def _content_shell(self, heading, description):
        content = QtWidgets.QWidget()
        content.setObjectName("PlaceholderContent")
        layout = QtWidgets.QVBoxLayout(content)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        self.heading_label = QtWidgets.QLabel(heading)
        self.heading_label.setObjectName("PlaceholderHeading")
        layout.addWidget(self.heading_label)
        layout.addSpacing(4)
        self.description_label = QtWidgets.QLabel(description)
        self.description_label.setObjectName("PlaceholderDescription")
        self.description_label.setWordWrap(True)
        layout.addWidget(self.description_label)
        layout.addSpacing(24)
        return content, layout


    def _select_section(self, index):
        for button_index, button in enumerate(self.menu_buttons):
            button.setProperty("selected", button_index == index)
            button.style().unpolish(button)
            button.style().polish(button)

        self._show_section(index)

    def keyPressEvent(self, event):
        if event.key() == QtCore.Qt.Key_Escape:
            self.closeRequested.emit()
            event.accept()
            return
        super().keyPressEvent(event)

    def resizeEvent(self, event):
        super().resizeEvent(event)
