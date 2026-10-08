from PyQt5 import QtCore, QtGui, QtWidgets
from plm.frontend.qt.widgets.common import ICON_SIZE, make_icon_button
from plm.frontend.qt.styles.tokens import SPACING_LG, SPACING_SM, SPACING_XL, TEXT_MAIN


class SecondaryMenuButton(QtWidgets.QPushButton):
    """Reserve enough space for the selected label before it becomes bold."""

    def sizeHint(self):
        self.ensurePolished()
        font = QtGui.QFont(self.font())
        font.setBold(True)
        metrics = QtGui.QFontMetrics(font)
        text_width = max(metrics.horizontalAdvance(self.text()),
                         metrics.boundingRect(self.text()).width())
        option = QtWidgets.QStyleOptionButton()
        self.initStyleOption(option)
        size = self.style().sizeFromContents(
            QtWidgets.QStyle.CT_PushButton, option,
            QtCore.QSize(text_width + 2, metrics.height()), self,
        )
        return super().sizeHint().expandedTo(size)

    def minimumSizeHint(self):
        return self.sizeHint()


class SecondaryPage(QtWidgets.QFrame):
    """Full-window Settings or documentation page."""

    closeRequested = QtCore.pyqtSignal()
    preferencesSaved = QtCore.pyqtSignal(dict)

    def __init__(self, page, parent=None):
        super().__init__(parent)
        self.page = page
        self.setObjectName("SecondaryPage")
        self.setAttribute(QtCore.Qt.WA_StyledBackground, True)
        self.setFocusPolicy(QtCore.Qt.StrongFocus)

        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        header = QtWidgets.QFrame()
        header.setObjectName("SecondaryPageHeader")
        header.setFixedHeight(48)
        header_layout = QtWidgets.QHBoxLayout(header)
        header_layout.setContentsMargins(SPACING_LG, 0, SPACING_LG, 0)
        header_layout.setSpacing(SPACING_SM)
        self.back_btn = make_icon_button(
            "arrow-left", "返回", "SecondaryBackButton", 32, ICON_SIZE, TEXT_MAIN
        )
        self.back_btn.clicked.connect(self.closeRequested.emit)
        header_layout.addWidget(self.back_btn)
        self.title_label = QtWidgets.QLabel(
            "Settings" if page == "settings" else "Documentation"
        )
        self.title_label.setObjectName("SecondaryPageTitle")
        header_layout.addWidget(self.title_label)
        header_layout.addStretch(1)
        root.addWidget(header)

        page_area = QtWidgets.QWidget()
        page_area.setObjectName("SecondaryPageArea")
        page_area_layout = QtWidgets.QHBoxLayout(page_area)
        page_area_layout.setContentsMargins(SPACING_XL, SPACING_XL, SPACING_XL, SPACING_XL)
        page_area_layout.setSpacing(0)
        page_area_layout.addStretch(1)

        self.page_panel = QtWidgets.QWidget()
        self.page_panel.setObjectName("SecondaryPagePanel")
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
        divider.setObjectName("SecondaryTabDivider")
        divider.setFixedHeight(1)
        panel_layout.addWidget(divider)
        self.content_top_spacing = QtWidgets.QSpacerItem(
            0, 24, QtWidgets.QSizePolicy.Minimum, QtWidgets.QSizePolicy.Fixed
        )
        panel_layout.addItem(self.content_top_spacing)
        panel_layout.addWidget(self.content, 1)
        page_area_layout.addWidget(self.page_panel, 0)
        page_area_layout.addStretch(1)
        root.addWidget(page_area, 1)
        self._select_section(0)

    def _build_menu(self, page):
        menu = QtWidgets.QWidget()
        menu.setObjectName("SecondaryTabs")
        layout = QtWidgets.QHBoxLayout(menu)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(8)
        self.menu_buttons = []
        entries = (
            ("General", "Formatter")
            if page == "settings"
            else ("Getting Started", "Configuration", "Generation")
        )
        for index, text in enumerate(entries):
            button = SecondaryMenuButton(text)
            button.setObjectName("SecondaryMenuButton")
            button.setCursor(QtCore.Qt.PointingHandCursor)
            button.clicked.connect(
                lambda _checked=False, selected=index: self._select_section(selected)
            )
            layout.addWidget(button)
            self.menu_buttons.append(button)
        layout.addStretch(1)
        return menu

    def _select_section(self, index):
        for button_index, button in enumerate(self.menu_buttons):
            button.setProperty("selected", button_index == index)
            button.style().unpolish(button)
            button.style().polish(button)
            button.updateGeometry()
            button.update()

        self._show_section(index)

    def keyPressEvent(self, event):
        if event.key() == QtCore.Qt.Key_Escape:
            self.closeRequested.emit()
            event.accept()
            return
        super().keyPressEvent(event)

