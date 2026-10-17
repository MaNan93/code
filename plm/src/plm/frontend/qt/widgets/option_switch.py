"""Lightweight table switches with a fading hover/focus indicator."""

from PyQt5 import QtCore, QtGui, QtWidgets

from plm.frontend.qt.styles.tokens import get_theme_color
from plm.frontend.qt.styles.tokens import CONTROL_HEIGHT
from plm.frontend.qt.widgets.common import load_lucide_icon


class OptionSwitch(QtWidgets.QAbstractButton):
    """Cycle fixed options without a popup or per-option child widgets."""

    currentTextChanged = QtCore.pyqtSignal(str)
    HORIZONTAL_PADDING = 10
    INDICATOR_SIZE = 12
    INDICATOR_GAP = 8
    HOVER_DURATION = 150

    def __init__(self, options, parent=None):
        super().__init__(parent)
        self._options = list(options)
        self._choices = tuple(options)
        self._keyboard_focus = False
        self._hover_progress = 0.0
        self._hover_animation = None
        self._icon = load_lucide_icon("chevron-down", color="text_sub", size=self.INDICATOR_SIZE)
        self.setFocusPolicy(QtCore.Qt.StrongFocus)
        self.setCursor(QtCore.Qt.PointingHandCursor)
        self.setFixedHeight(CONTROL_HEIGHT)
        self.setSizePolicy(QtWidgets.QSizePolicy.Expanding, QtWidgets.QSizePolicy.Fixed)
        self.setText(self._options[0] if self._options else "")
        self.setAccessibleDescription("点击或按空格切换；也可使用左右方向键")
        self.clicked.connect(self._cycle)

    def sizeHint(self):
        width = max((self.fontMetrics().horizontalAdvance(text) for text in self._options), default=0)
        return QtCore.QSize(width + self.INDICATOR_SIZE + self.INDICATOR_GAP
                           + 2 * self.HORIZONTAL_PADDING, CONTROL_HEIGHT)

    def refresh_theme(self):
        self._icon = load_lucide_icon("chevron-down", color="text_sub", size=self.INDICATOR_SIZE)
        self.update()

    def setOptions(self, options):
        options = list(options)
        if options != self._options:
            self._options = options
            self.updateGeometry()
            self.update()

    def options(self):
        return tuple(self._options)

    def currentText(self):
        return self.text()

    def setCurrentText(self, text):
        if text != self.text():
            self.setText(text)
            self.currentTextChanged.emit(text)

    def _cycle(self):
        if self._choices:
            index = self._choices.index(self.text()) if self.text() in self._choices else -1
            self.setCurrentText(self._choices[(index + 1) % len(self._choices)])

    def keyPressEvent(self, event):
        if not self._choices:
            return super().keyPressEvent(event)
        index = self._choices.index(self.text()) if self.text() in self._choices else 0
        if event.key() in (QtCore.Qt.Key_Left, QtCore.Qt.Key_Up):
            index = max(0, index - 1)
        elif event.key() in (QtCore.Qt.Key_Right, QtCore.Qt.Key_Down):
            index = min(len(self._choices) - 1, index + 1)
        elif event.key() == QtCore.Qt.Key_Home:
            index = 0
        elif event.key() == QtCore.Qt.Key_End:
            index = len(self._choices) - 1
        else:
            return super().keyPressEvent(event)
        self._keyboard_focus = True
        self.setCurrentText(self._choices[index])
        self.update()
        event.accept()

    def enterEvent(self, event):
        self._animate_hover(1.0)
        super().enterEvent(event)

    def leaveEvent(self, event):
        self._animate_hover(0.0)
        super().leaveEvent(event)

    def _animate_hover(self, target):
        # Allocate only on first interaction; hidden rows need no animation.
        if self._hover_animation is None:
            self._hover_animation = QtCore.QVariantAnimation(self)
            self._hover_animation.setDuration(self.HOVER_DURATION)
            self._hover_animation.setEasingCurve(QtCore.QEasingCurve.InOutQuad)
            self._hover_animation.valueChanged.connect(self._set_hover_progress)
        self._hover_animation.stop()
        self._hover_animation.setStartValue(self._hover_progress)
        self._hover_animation.setEndValue(target)
        self._hover_animation.start()

    def _set_hover_progress(self, progress):
        self._hover_progress = float(progress)
        self.update()

    def hideEvent(self, event):
        if self._hover_animation is not None:
            self._hover_animation.stop()
        self._hover_progress = 0.0
        super().hideEvent(event)

    def focusInEvent(self, event):
        self._keyboard_focus = event.reason() in (
            QtCore.Qt.TabFocusReason, QtCore.Qt.BacktabFocusReason, QtCore.Qt.ShortcutFocusReason,
        )
        self.update()
        super().focusInEvent(event)

    def focusOutEvent(self, event):
        self.update()
        super().focusOutEvent(event)

    def paintEvent(self, event):
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.Antialiasing)
        if not self.isEnabled():
            painter.setOpacity(.55)
        rect = QtCore.QRectF(self.rect()).adjusted(.5, 4.5, -.5, -4.5)
        invalid = bool(self.property("validationError"))
        focused = self.hasFocus() and self._keyboard_focus
        painter.setPen(QtGui.QPen(QtGui.QColor(get_theme_color("danger") if invalid else get_theme_color("primary")), 1)
                       if invalid or focused else QtCore.Qt.NoPen)
        background = QtGui.QColor(get_theme_color("bg_switch_hover"))
        background.setAlphaF(1.0 if self.isDown() or focused else self._hover_progress)
        painter.setBrush(background)
        painter.drawRoundedRect(rect, rect.height() / 2, rect.height() / 2)
        icon_opacity = 1.0 if focused else self._hover_progress
        if icon_opacity > 0.01:
            icon_rect = QtCore.QRect(self.width() - self.INDICATOR_SIZE - self.HORIZONTAL_PADDING,
                                    (self.height() - self.INDICATOR_SIZE) // 2,
                                    self.INDICATOR_SIZE, self.INDICATOR_SIZE)
            painter.save()
            painter.setOpacity(painter.opacity() * icon_opacity)
            self._icon.paint(painter, icon_rect)
            painter.restore()
        # Keep the same text bounds throughout the animation to avoid shifting.
        text_rect = self.rect().adjusted(self.HORIZONTAL_PADDING, 0,
                                        -(self.INDICATOR_SIZE + self.INDICATOR_GAP + self.HORIZONTAL_PADDING), 0)
        label = self.fontMetrics().elidedText(self.text(), QtCore.Qt.ElideRight, max(0, text_rect.width()))
        painter.setPen(QtGui.QColor(get_theme_color("danger_text") if invalid else get_theme_color("text_main")))
        painter.drawText(text_rect, QtCore.Qt.AlignLeft | QtCore.Qt.AlignVCenter, label)
