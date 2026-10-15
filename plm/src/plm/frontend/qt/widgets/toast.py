"""Replaceable, non-interactive notifications owned by the main window."""

from PyQt5 import QtCore, QtWidgets

from plm.frontend.qt.styles.tokens import (
    SPACING_MD, SPACING_XL, TOAST_BOTTOM_MARGIN, TOAST_FADE_IN,
    TOAST_FADE_OUT, TOAST_HOLD,
)


class ToastNotification(QtWidgets.QFrame):
    def __init__(self, parent):
        super().__init__(parent)
        self.setObjectName("ToastNotification")
        self.setAttribute(QtCore.Qt.WA_TransparentForMouseEvents)
        self.setAttribute(QtCore.Qt.WA_ShowWithoutActivating)
        self.setFocusPolicy(QtCore.Qt.NoFocus)
        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(SPACING_XL, SPACING_MD, SPACING_XL, SPACING_MD)
        self.label = QtWidgets.QLabel()
        self.label.setTextFormat(QtCore.Qt.PlainText)
        self.label.setWordWrap(True)
        layout.addWidget(self.label)
        self.opacity = QtWidgets.QGraphicsOpacityEffect(self)
        self.setGraphicsEffect(self.opacity)
        self.animation = QtCore.QPropertyAnimation(self.opacity, b"opacity", self)
        self.animation.finished.connect(self._animation_finished)
        self.timer = QtCore.QTimer(self)
        self.timer.setSingleShot(True)
        self.timer.timeout.connect(self._fade_out)
        self._fading_out = False
        parent.installEventFilter(self)
        self.hide()

    def show_message(self, text, level="success"):
        self.timer.stop()
        self.animation.stop()
        self._fading_out = False
        self.label.setText(text)
        self.setProperty("level", level if level in ("success", "info") else "info")
        self.style().unpolish(self)
        self.style().polish(self)
        self.reposition()
        self.show()
        self.raise_()
        self.animation.setDuration(TOAST_FADE_IN)
        self.animation.setStartValue(0.0)
        self.animation.setEndValue(1.0)
        self.animation.start()

    def reposition(self):
        parent = self.parentWidget()
        self.setMaximumWidth(max(1, parent.width() - 2 * SPACING_XL))
        self.adjustSize()
        self.move((parent.width() - self.width()) // 2,
                  parent.height() - self.height() - TOAST_BOTTOM_MARGIN)

    def _animation_finished(self):
        if self._fading_out:
            self.hide()
        else:
            self.timer.start(TOAST_HOLD)

    def _fade_out(self):
        self._fading_out = True
        self.animation.setDuration(TOAST_FADE_OUT)
        self.animation.setStartValue(self.opacity.opacity())
        self.animation.setEndValue(0.0)
        self.animation.start()

    def hideEvent(self, event):
        self.timer.stop()
        self.animation.stop()
        super().hideEvent(event)

    def eventFilter(self, watched, event):
        if watched is self.parentWidget() and event.type() == QtCore.QEvent.Resize:
            if self.isVisible():
                self.reposition()
        return super().eventFilter(watched, event)
