"""Responsive file selector used by the artifact drawer toolbar."""

from html import escape

from PyQt5 import QtCore, QtGui, QtWidgets

from plm.frontend.qt.styles.tokens import get_theme_color
from plm.frontend.qt.styles.tokens import (
    ARTIFACTS_BORDER_WIDTH, ICON_TEXT_GAP, MENU_PADDING, MENU_SHADOW_MARGIN,
    RADIUS_CARD,
)
from plm.frontend.qt.widgets.common import ICON_SIZE, load_lucide_icon, paint_popup_surface, set_label_icon


class ArtifactContent(QtWidgets.QWidget):
    """Clip child surfaces inside the drawer's rounded border."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("ArtifactContent")

    def resizeEvent(self, event):
        super().resizeEvent(event)
        # QSS rounds the frame itself, but does not clip its child widgets.
        path = QtGui.QPainterPath()
        # Leave room for the frame's antialiased stroke at the curved edges.
        radius = max(0, RADIUS_CARD - ARTIFACTS_BORDER_WIDTH - 1)
        path.addRoundedRect(
            QtCore.QRectF(self.rect()).adjusted(1, 1, -1, -1), radius, radius,
        )
        self.setMask(QtGui.QRegion(path.toFillPolygon().toPolygon()))


class ArtifactPathLabel(QtWidgets.QLabel):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("ArtifactPath")
        self._full_path = ""
        self._directory = ""
        self._filename = ""
        self.display_path = ""
        self.setTextFormat(QtCore.Qt.RichText)
        self.setMinimumWidth(0)
        self.setSizePolicy(QtWidgets.QSizePolicy.Ignored, QtWidgets.QSizePolicy.Preferred)
        self.setAlignment(QtCore.Qt.AlignLeft | QtCore.Qt.AlignVCenter)
        self.setAttribute(QtCore.Qt.WA_TransparentForMouseEvents)

    def set_path(self, path, root=None):
        self._full_path = str(path or "")
        self._directory = ""
        self._filename = path.name if path is not None else ""
        if path is not None:
            try:
                relative = path.relative_to(root) if root is not None else path
                self._directory = " / ".join(relative.parts[:-1])
            except ValueError:
                self._directory = "…"
        self.setToolTip("")
        self.setAccessibleName(self._full_path)
        self._update_text()

    def _update_text(self):
        width = max(0, self.contentsRect().width() - 4)
        font = QtGui.QFont(self.font())
        font.setWeight(QtGui.QFont.Medium)
        filename_metrics = QtGui.QFontMetrics(font)
        # Generated files share a long prefix (pipe_lane_...); keep the tail,
        # which is the part that tells them apart.
        filename = filename_metrics.elidedText(self._filename, QtCore.Qt.ElideLeft, width)
        directory = ""
        if filename == self._filename and self._directory:
            available = width - filename_metrics.horizontalAdvance(filename)
            directory = self.fontMetrics().elidedText(
                self._directory + " / ", QtCore.Qt.ElideLeft, max(0, available)
            )
        self.display_path = directory + filename
        self.setText(
            f'<span style="color:{get_theme_color("accent_artifacts")}">{escape(directory)}</span>'
            f'<b style="color:{get_theme_color("text_artifacts")};font-weight:500">{escape(filename)}</b>'
            if self._filename else ""
        )

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self._update_text()

    def refresh_theme(self):
        self._update_text()

class ArtifactPathButton(QtWidgets.QPushButton):
    """One clickable, keyboard-accessible breadcrumb and arrow capsule."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("ArtifactPathButton")
        self.setCheckable(True)
        self.setMinimumWidth(36)
        self.setSizePolicy(QtWidgets.QSizePolicy.Ignored, QtWidgets.QSizePolicy.Fixed)
        self.setCursor(QtCore.Qt.PointingHandCursor)
        self.setToolTip("")
        self.setIcon(load_lucide_icon("chevron-down", 'text_artifacts_muted'))
        self.setIconSize(QtCore.QSize(ICON_SIZE, ICON_SIZE))
        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(6, 0, 6, 0)
        layout.setSpacing(ICON_TEXT_GAP)
        self.arrow = QtWidgets.QLabel()
        self.arrow.setFixedSize(ICON_SIZE, ICON_SIZE)
        set_label_icon(self.arrow, "chevron-down", "text_artifacts_muted")
        self.arrow.setAttribute(QtCore.Qt.WA_TransparentForMouseEvents)
        self.path_label = ArtifactPathLabel()
        layout.addWidget(self.arrow)
        layout.addWidget(self.path_label, 1)

    def paintEvent(self, event):
        # QStyle paints the button surface; child labels render the rich breadcrumb.
        option = QtWidgets.QStyleOptionButton()
        self.initStyleOption(option)
        option.icon = QtGui.QIcon()
        painter = QtWidgets.QStylePainter(self)
        painter.drawControl(QtWidgets.QStyle.CE_PushButton, option)


class ArtifactFilePopup(QtWidgets.QFrame):
    """Screen-bounded popup; its tree never participates in the editor layout."""

    dismissed = QtCore.pyqtSignal()
    GAP = 4
    MAX_HEIGHT = 480
    MAX_WIDTH = 720

    def __init__(self, tree, parent=None):
        super().__init__(parent, QtCore.Qt.Popup | QtCore.Qt.FramelessWindowHint
                         | QtCore.Qt.NoDropShadowWindowHint)
        self.setObjectName("ArtifactFilePopup")
        self.setAttribute(QtCore.Qt.WA_StyledBackground, True)
        self.setAttribute(QtCore.Qt.WA_TranslucentBackground, True)
        self.setAttribute(QtCore.Qt.WA_NoMouseReplay, True)
        self.tree = tree
        tree.installEventFilter(self)
        tree.viewport().installEventFilter(self)
        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(*([MENU_PADDING + MENU_SHADOW_MARGIN] * 4))
        layout.addWidget(tree)

    def show_below(self, anchor):
        self.ensurePolished()
        self.tree.ensurePolished()
        top = anchor.mapToGlobal(QtCore.QPoint())
        bottom = anchor.mapToGlobal(QtCore.QPoint(0, anchor.height()))
        screen = QtWidgets.QApplication.screenAt(bottom) or anchor.screen()
        available = screen.availableGeometry()
        width = min(max(anchor.width(), 360), self.MAX_WIDTH, available.width())
        height = min(max(self.tree.sizeHint().height() + 2 * (MENU_PADDING + MENU_SHADOW_MARGIN), 120),
                     self.MAX_HEIGHT, available.height())
        y = bottom.y() + self.GAP
        if y + height > available.bottom() + 1:
            above = top.y() - self.GAP - available.top()
            below = available.bottom() + 1 - y
            if above > below:
                height = min(height, max(1, above))
                y = top.y() - self.GAP - height
            else:
                height = min(height, max(1, below))
        x = max(available.left(), min(bottom.x(), available.right() + 1 - width))
        y = max(available.top(), min(y, available.bottom() + 1 - height))
        self.setGeometry(x, y, width, height)
        self.show()
        self.tree.setFocus(QtCore.Qt.PopupFocusReason)

    def paintEvent(self, event):
        painter = QtGui.QPainter(self)
        paint_popup_surface(painter, self.rect(), RADIUS_CARD)

    def keyPressEvent(self, event):
        if event.key() == QtCore.Qt.Key_Escape:
            self.hide()
            event.accept()
        else:
            super().keyPressEvent(event)

    def eventFilter(self, watched, event):
        if event.type() == QtCore.QEvent.KeyPress and event.key() == QtCore.Qt.Key_Escape:
            self.hide()
            return True
        return super().eventFilter(watched, event)

    def hideEvent(self, event):
        super().hideEvent(event)
        self.dismissed.emit()
