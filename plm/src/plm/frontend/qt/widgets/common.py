"""Shared low-level helpers for Qt widgets."""

import os
import subprocess
import sys
from functools import lru_cache
from pathlib import Path

from PyQt5 import QtCore, QtGui, QtSvg, QtWidgets

from plm.core.paths import PLM_ROOT
from plm.frontend.qt.styles.tokens import (
    BG_MAIN, BG_SUBTLE, BORDER, CONTROL_HEIGHT, CONTROL_PADDING_X, DANGER,
    ICON_BUTTON_SIZE, ICON_GLYPH_SIZE, ICON_SIZE, ICON_TEXT_GAP,
    LINE_HEIGHT, MENU_GAP, MENU_ICON_TEXT_GAP, MENU_ITEM_PADDING_X, MENU_PADDING, MENU_RADIUS,
    MENU_SHADOW_LAYER_ALPHA, MENU_SHADOW_MARGIN, MENU_SHADOW_OFFSET, MENU_SHADOW_SPREAD,
    MENU_MIN_WIDTH,
    RADIUS_CARD, SHADOW_SM, TEXT_MAIN, TEXT_MUTED, TEXT_SUB,
)

LUCIDE_ICON_DIR = Path(__file__).resolve().parents[1] / "assets" / "icons"
APP_ICON_PATH = Path(__file__).resolve().parents[1] / "assets" / "app_icon.svg"
PROJECT_ROOT = PLM_ROOT


def button_height(widget):
    """Shared total height; independent of native font metrics and Qt scaling."""
    return {"ProjectMoreBtn": 28, "ArtifactsToolButton": ICON_BUTTON_SIZE}.get(widget.objectName(), CONTROL_HEIGHT)


class FixedHeightItemDelegate(QtWidgets.QStyledItemDelegate):
    """Uniform popup/list rows, including native QComboBox candidates."""

    def sizeHint(self, option, index):
        size = super().sizeHint(option, index)
        size.setHeight(CONTROL_HEIGHT)
        return size


class ButtonSizingController(QtCore.QObject):
    """Apply the Medium control height throughout the application."""

    SIZING_EVENTS = frozenset((
        QtCore.QEvent.Polish, QtCore.QEvent.FontChange,
        QtCore.QEvent.StyleChange, QtCore.QEvent.Show,
    ))

    def __init__(self, app):
        super().__init__(app)
        self._applying = False
        app.installEventFilter(self)

    def eventFilter(self, watched, event):
        kind = event.type()
        if kind != QtCore.QEvent.Paint and kind not in self.SIZING_EVENTS:
            return False
        if kind == QtCore.QEvent.Paint and isinstance(watched, QtWidgets.QDialog):
            # Native framed dialogs must have an opaque client surface even
            # when their owner is the translucent, frameless main window.
            painter = QtGui.QPainter(watched)
            painter.fillRect(event.rect(), QtGui.QColor(BG_MAIN))
            painter.end()
        if (kind == QtCore.QEvent.Paint
                and isinstance(watched, QtWidgets.QPushButton)
                and not watched.icon().isNull()
                and (watched.text() or watched.objectName() in ("NavActionButton", "NavFooterButton")
                     or (watched.hasFocus() and watched.layout() is None))):
            paint_icon_text_button(watched)
            return True
        if self._applying or kind not in self.SIZING_EVENTS:
            return False
        self._applying = True
        try:
            if isinstance(watched, QtWidgets.QAbstractButton):
                watched.setFixedHeight(button_height(watched))
                if (isinstance(watched, QtWidgets.QPushButton) and watched.text()
                        and not watched.icon().isNull()
                        and watched.sizePolicy().horizontalPolicy() != QtWidgets.QSizePolicy.Ignored
                        and watched.maximumWidth() == QtWidgets.QWIDGETSIZE_MAX):
                    label_width = watched.fontMetrics().horizontalAdvance(watched.text())
                    watched.setMinimumWidth(label_width + ICON_SIZE + ICON_TEXT_GAP + 2 * CONTROL_PADDING_X)
            elif isinstance(watched, (QtWidgets.QLineEdit, QtWidgets.QComboBox, QtWidgets.QSpinBox)):
                watched.setFixedHeight(CONTROL_HEIGHT - 4 if watched.property("formatterRow") is not None else CONTROL_HEIGHT)
                if isinstance(watched, QtWidgets.QComboBox) and not isinstance(watched.itemDelegate(), FixedHeightItemDelegate):
                    watched.setItemDelegate(FixedHeightItemDelegate(watched))
        finally:
            self._applying = False
        return False


def install_button_sizing(app):
    if not hasattr(app, "_button_sizing"):
        app._button_sizing = ButtonSizingController(app)
    return app._button_sizing


def make_button_group(buttons, parent=None):
    """Seamless horizontal buttons with corners only at the outer edges."""
    group = QtWidgets.QFrame(parent)
    group.setObjectName("ButtonGroup")
    group.setFixedHeight(CONTROL_HEIGHT)
    layout = QtWidgets.QHBoxLayout(group)
    layout.setContentsMargins(0, 0, 0, 0)
    layout.setSpacing(0)
    for index, button in enumerate(buttons):
        button.setProperty("groupFirst", index == 0)
        button.setProperty("groupLast", index == len(buttons) - 1)
        layout.addWidget(button)
    return group


class ContentIconStyle(QtWidgets.QProxyStyle):
    """Use uniform native icon slots and the shared icon/text spacing."""

    ICON_METRICS = {
        QtWidgets.QStyle.PM_SmallIconSize,
        QtWidgets.QStyle.PM_LargeIconSize,
        QtWidgets.QStyle.PM_ButtonIconSize,
        QtWidgets.QStyle.PM_TabBarIconSize,
        QtWidgets.QStyle.PM_ToolBarIconSize,
        QtWidgets.QStyle.PM_MessageBoxIconSize,
    }

    def pixelMetric(self, metric, option=None, widget=None):
        if metric == QtWidgets.QStyle.PM_SmallIconSize:
            return ICON_SIZE
        return ICON_SIZE if metric in self.ICON_METRICS else super().pixelMetric(metric, option, widget)

    def drawControl(self, element, option, painter, widget=None):
        if (element != QtWidgets.QStyle.CE_PushButtonLabel
                or not isinstance(option, QtWidgets.QStyleOptionButton)
                or option.icon.isNull() or not option.text):
            return super().drawControl(element, option, painter, widget)
        draw_icon_text_label(self, option, painter, widget)

    def sizeFromContents(self, kind, option, size, widget=None):
        result = super().sizeFromContents(kind, option, size, widget)
        if (kind == QtWidgets.QStyle.CT_PushButton
                and isinstance(option, QtWidgets.QStyleOptionButton)
                and option.text and not option.icon.isNull()):
            result.setWidth(result.width() + ICON_TEXT_GAP - 4)
        return result


def draw_icon_text_label(style, option, painter, widget):
    """Draw a centered icon slot and the shared text line with a uniform gap."""
    rect = QtCore.QRect(option.rect)
    text_width = option.fontMetrics.horizontalAdvance(option.text)
    total = ICON_SIZE + (ICON_TEXT_GAP + text_width if option.text else 0)
    left_aligned = option.text and widget and widget.objectName() in ("NavActionButton", "NavFooterButton")
    x = rect.left() if left_aligned else rect.left() + max(0, (rect.width() - total) // 2)
    enabled = bool(option.state & QtWidgets.QStyle.State_Enabled)
    if option.state & QtWidgets.QStyle.State_HasFocus and not option.state & QtWidgets.QStyle.State_Sunken:
        option.palette.setColor(QtGui.QPalette.ButtonText, QtGui.QColor(TEXT_MAIN))
        focused_icon = option.icon.pixmap(ICON_SIZE, ICON_SIZE)
        tint = QtGui.QPainter(focused_icon)
        tint.setCompositionMode(QtGui.QPainter.CompositionMode_SourceIn)
        tint.fillRect(focused_icon.rect(), QtGui.QColor(TEXT_MAIN))
        tint.end()
        option.icon = QtGui.QIcon(focused_icon)
    mode = QtGui.QIcon.Normal if enabled else QtGui.QIcon.Disabled
    icon_rect = QtCore.QRect(x, rect.top() + (rect.height() - ICON_SIZE) // 2, ICON_SIZE, ICON_SIZE)
    option.icon.paint(painter, icon_rect, QtCore.Qt.AlignCenter, mode,
                      QtGui.QIcon.On if option.state & QtWidgets.QStyle.State_On else QtGui.QIcon.Off)
    text_rect = QtCore.QRect(icon_rect.right() + 1 + ICON_TEXT_GAP,
                            rect.top() + (rect.height() - LINE_HEIGHT) // 2,
                            max(0, rect.right() - icon_rect.right() - ICON_TEXT_GAP), LINE_HEIGHT)
    style.drawItemText(painter, text_rect, QtCore.Qt.AlignLeft | QtCore.Qt.AlignVCenter
                       | QtCore.Qt.TextShowMnemonic, option.palette, enabled,
                       option.text, QtGui.QPalette.ButtonText)


def paint_icon_text_button(button):
    # QStyleSheetStyle bypasses proxy label painting. Handle the paint event so
    # this also covers buttons created in C++ by QDialogButtonBox.
    option = QtWidgets.QStyleOptionButton()
    option.initFrom(button)
    option.text = button.text()
    option.icon = button.icon()
    option.iconSize = QtCore.QSize(ICON_SIZE, ICON_SIZE)
    if button.isFlat():
        option.features |= QtWidgets.QStyleOptionButton.Flat
    if button.isDefault():
        option.features |= QtWidgets.QStyleOptionButton.DefaultButton
    if button.autoDefault():
        option.features |= QtWidgets.QStyleOptionButton.AutoDefaultButton
    if button.menu() is not None:
        option.features |= QtWidgets.QStyleOptionButton.HasMenu
    if button.isDown():
        option.state |= QtWidgets.QStyle.State_Sunken
    elif not button.isFlat():
        option.state |= QtWidgets.QStyle.State_Raised
    if button.isChecked():
        option.state |= QtWidgets.QStyle.State_On
    face = QtWidgets.QStyleOptionButton(option)
    face.text = ""
    face.icon = QtGui.QIcon()
    painter = QtWidgets.QStylePainter(button)
    painter.setFont(button.font())
    painter.drawControl(QtWidgets.QStyle.CE_PushButton, face)
    option.rect = (button.style().subElementRect(QtWidgets.QStyle.SE_PushButtonContents, option, button)
                   if option.text else button.rect())
    draw_icon_text_label(button.style(), option, painter, button)
    painter.end()


def rounded_widget_path(rect, radii):
    """Build a vector outline with independent corner radii."""
    area = QtCore.QRectF(rect)
    limit = min(area.width(), area.height()) / 2
    tl, tr, br, bl = (min(radius, limit) for radius in radii)
    left, top, right, bottom = area.left(), area.top(), area.right(), area.bottom()
    path = QtGui.QPainterPath()
    path.moveTo(left + tl, top)
    path.lineTo(right - tr, top)
    if tr:
        path.arcTo(right - 2 * tr, top, 2 * tr, 2 * tr, 90, -90)
    path.lineTo(right, bottom - br)
    if br:
        path.arcTo(right - 2 * br, bottom - 2 * br, 2 * br, 2 * br, 0, -90)
    path.lineTo(left + bl, bottom)
    if bl:
        path.arcTo(left, bottom - 2 * bl, 2 * bl, 2 * bl, 270, -90)
    path.lineTo(left, top + tl)
    if tl:
        path.arcTo(left, top, 2 * tl, 2 * tl, 180, -90)
    path.closeSubpath()
    return path


def paint_popup_surface(painter, rect, radius=MENU_RADIUS):
    """White rounded popup and soft shadow inside transparent window gutters."""
    painter.setRenderHint(QtGui.QPainter.Antialiasing)
    painter.setCompositionMode(QtGui.QPainter.CompositionMode_Source)
    painter.fillRect(rect, QtCore.Qt.transparent)
    painter.setCompositionMode(QtGui.QPainter.CompositionMode_SourceOver)
    margin = MENU_SHADOW_MARGIN
    surface = QtCore.QRectF(rect).adjusted(margin, margin, -margin, -margin)
    for spread in range(MENU_SHADOW_SPREAD, 0, -1):
        shadow = surface.translated(*MENU_SHADOW_OFFSET).adjusted(-spread, -spread, spread, spread)
        path = QtGui.QPainterPath()
        path.addRoundedRect(shadow, radius + spread, radius + spread)
        painter.fillPath(path, QtGui.QColor(0, 0, 0, MENU_SHADOW_LAYER_ALPHA))
    path = QtGui.QPainterPath()
    path.addRoundedRect(surface, radius, radius)
    painter.fillPath(path, QtGui.QColor("white"))


class RoundedCanvasFrame(QtWidgets.QFrame):
    """Antialiased white canvas with an optional light border."""

    CORNER_RADII = (RADIUS_CARD,) * 4
    BORDER_WIDTH = 0.0

    def paintEvent(self, event):
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.Antialiasing)
        inset = self.BORDER_WIDTH / 2
        path = rounded_widget_path(
            QtCore.QRectF(self.rect()).adjusted(inset, inset, -inset, -inset),
            self.CORNER_RADII,
        )
        painter.fillPath(path, QtGui.QColor(BG_MAIN))
        if self.BORDER_WIDTH:
            painter.setPen(QtGui.QPen(QtGui.QColor(BORDER), self.BORDER_WIDTH))
            painter.drawPath(path)
        painter.end()


@lru_cache(maxsize=256)
def load_lucide_icon(name, color=TEXT_SUB, size=ICON_SIZE, align_visible_left=False):
    path = LUCIDE_ICON_DIR / f"{name}.svg"
    source = QtGui.QPixmap(size, size)
    source.fill(QtCore.Qt.transparent)
    renderer = QtSvg.QSvgRenderer(str(path))
    if not renderer.isValid():
        return QtGui.QIcon(source)
    painter = QtGui.QPainter(source)
    painter.setRenderHint(QtGui.QPainter.Antialiasing, True)
    glyph_size = min(size, ICON_GLYPH_SIZE)
    inset = (size - glyph_size) / 2
    renderer.render(painter, QtCore.QRectF(inset, inset, glyph_size, glyph_size))
    painter.end()
    colored = QtGui.QPixmap(size, size)
    colored.fill(QtCore.Qt.transparent)
    painter = QtGui.QPainter(colored)
    painter.drawPixmap(0, 0, source)
    painter.setCompositionMode(QtGui.QPainter.CompositionMode_SourceIn)
    painter.fillRect(colored.rect(), QtGui.QColor(color))
    painter.end()
    # Keep the compatibility argument, but all glyphs now stay centered in
    # their fixed slot instead of aligning their different path bounds.
    return QtGui.QIcon(colored)


def make_icon_button(icon_name, tooltip, object_name="IconButton", button_size=28,
                     icon_size=ICON_SIZE, color=TEXT_SUB):
    button = QtWidgets.QPushButton()
    button.setObjectName(object_name)
    button.setIcon(load_lucide_icon(icon_name, color, icon_size))
    button.setIconSize(QtCore.QSize(icon_size, icon_size))
    button.setFixedWidth(button_size)
    button.setSizePolicy(QtWidgets.QSizePolicy.Fixed, QtWidgets.QSizePolicy.Fixed)
    button.setToolTip(tooltip)
    button.setCursor(QtCore.Qt.PointingHandCursor)
    return button


class StatusBadge(QtWidgets.QLabel):
    """Compact status label with a palette-colored indicator dot."""

    def __init__(self, text="", parent=None):
        super().__init__(text, parent)
        self.setContentsMargins(10, 0, 0, 0)

    def paintEvent(self, event):
        super().paintEvent(event)
        if not self.text():
            return
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.Antialiasing, True)
        painter.setPen(QtCore.Qt.NoPen)
        painter.setBrush(self.palette().color(QtGui.QPalette.WindowText))
        painter.drawEllipse(QtCore.QPointF(8.0, self.height() / 2.0), 2.5, 2.5)
        painter.end()


def apply_drop_shadow(widget, offset=None, blur_radius=None, alpha=None, shadow=SHADOW_SM):
    preset = shadow or SHADOW_SM
    final_offset = preset["offset"] if offset is None else offset
    final_blur = preset["blur_radius"] if blur_radius is None else blur_radius
    final_rgba = preset["rgba"]
    final_alpha = final_rgba[3] if alpha is None else alpha
    effect = QtWidgets.QGraphicsDropShadowEffect(widget)
    effect.setOffset(*final_offset)
    effect.setBlurRadius(final_blur)
    effect.setColor(QtGui.QColor(final_rgba[0], final_rgba[1], final_rgba[2], final_alpha))
    widget.setGraphicsEffect(effect)
    return effect


def open_in_file_manager(path):
    resolved_path = Path(path).resolve()
    if not resolved_path.exists():
        return False
    try:
        if sys.platform == "win32":
            os.startfile(str(resolved_path))
        elif sys.platform == "darwin":
            subprocess.Popen(["open", str(resolved_path)])
        else:
            subprocess.Popen(["xdg-open", str(resolved_path)])
    except OSError:
        return False
    return True


class StyledMenu(QtWidgets.QMenu):
    """Native menu navigation with capsule rows and a translucent soft shadow."""
    RADIUS = float(MENU_RADIUS)
    SHADOW_MARGIN = MENU_SHADOW_MARGIN

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.setAttribute(QtCore.Qt.WA_TranslucentBackground)
        self.setWindowFlags(self.windowFlags() | QtCore.Qt.FramelessWindowHint | QtCore.Qt.NoDropShadowWindowHint)
        self.setMouseTracking(True)
        self.aboutToShow.connect(self._fit_action_labels)

    def _fit_action_labels(self):
        # QMenu computes action hit rectangles separately from sizeHint().
        # Give its stylesheet the same text/slot width used by our painter.
        self.ensurePolished()
        # The minimum applies to the white surface, including its inner
        # padding. Qt's menu-level minimum otherwise adds unused width that
        # the native action rectangles do not occupy.
        content_width = max(0, MENU_MIN_WIDTH - 2 * MENU_PADDING - 2 * MENU_ITEM_PADDING_X)
        for action in self.actions():
            if not action.isVisible() or action.isSeparator():
                continue
            option = QtWidgets.QStyleOptionMenuItem()
            self.initStyleOption(option, action)
            metrics = QtGui.QFontMetrics(option.font)
            label, _, shortcut = option.text.partition("\t")
            width = metrics.horizontalAdvance(label.replace("&", "")) + ICON_SIZE + MENU_ICON_TEXT_GAP
            if shortcut:
                width += metrics.horizontalAdvance(shortcut) + 16
            if action.menu():
                width += ICON_SIZE + MENU_ICON_TEXT_GAP
            content_width = max(content_width, width)
        self.setStyleSheet(
            f"QMenu {{ min-width: 0; }} QMenu::item {{ min-width: {content_width}px; }}"
        )

    def addSeparator(self):
        action = super().addSeparator()
        action.setVisible(False)
        return action

    def addMenu(self, *args):
        if len(args) == 1 and isinstance(args[0], QtWidgets.QMenu):
            return super().addMenu(args[0])
        submenu = StyledMenu(str(args[-1]), self)
        if len(args) == 2:
            submenu.setIcon(args[0])
        super().addMenu(submenu)
        return submenu

    def actionEvent(self, event):
        super().actionEvent(event)
        action = event.action()
        if (event.type() == QtCore.QEvent.ActionAdded and action.icon().isNull()
                and ("删除" in action.text() or action.text().lower().startswith("delete"))):
            action.setIcon(load_lucide_icon("trash-2", DANGER, ICON_SIZE))

    def sizeHint(self):
        result = super().sizeHint()
        actions = [action for action in self.actions() if action.isVisible() and not action.isSeparator()]
        icon_width = ICON_SIZE + MENU_ICON_TEXT_GAP
        for action in actions:
            option = QtWidgets.QStyleOptionMenuItem()
            self.initStyleOption(option, action)
            metrics = QtGui.QFontMetrics(option.font)
            label, _, shortcut = option.text.partition("\t")
            width = metrics.horizontalAdvance(label.replace("&", "")) + icon_width + 2 * MENU_ITEM_PADDING_X
            if shortcut:
                width += metrics.horizontalAdvance(shortcut) + 16
            if action.menu():
                width += ICON_SIZE + MENU_ICON_TEXT_GAP
            result.setWidth(max(result.width(), width + 2 * (self.SHADOW_MARGIN + MENU_PADDING)))
        return result

    def paintEvent(self, event):
        # Paint inside reserved transparent gutters: a top-level menu cannot
        # reliably display a QWidget graphics effect outside its window bounds.
        painter = QtGui.QPainter(self)
        paint_popup_surface(painter, self.rect(), self.RADIUS)

        visible = [action for action in self.actions() if action.isVisible() and not action.isSeparator()]
        for action in visible:
            rect = self.actionGeometry(action).adjusted(0, 0, 0, -MENU_GAP)
            if not rect.intersects(event.rect()):
                continue
            selected = action is self.activeAction() and action.isEnabled()
            if selected:
                painter.setPen(QtCore.Qt.NoPen)
                painter.setBrush(QtGui.QColor(BG_SUBTLE))
                painter.drawRoundedRect(QtCore.QRectF(rect), rect.height() / 2, rect.height() / 2)
            text_rect = rect.adjusted(MENU_ITEM_PADDING_X, 0, -MENU_ITEM_PADDING_X, 0)
            # Reserve the same 20 px icon slot even for rows without an icon.
            icon_rect = QtCore.QRect(text_rect.left(), rect.top() + (rect.height() - ICON_SIZE) // 2,
                                    ICON_SIZE, ICON_SIZE)
            if not action.icon().isNull():
                action.icon().paint(painter, icon_rect, QtCore.Qt.AlignCenter,
                                    QtGui.QIcon.Normal if action.isEnabled() else QtGui.QIcon.Disabled)
            elif action.isChecked():
                painter.setPen(QtGui.QColor(TEXT_MAIN))
                painter.drawText(icon_rect, QtCore.Qt.AlignCenter, "✓")
            text_rect.setLeft(icon_rect.right() + 1 + MENU_ICON_TEXT_GAP)
            option = QtWidgets.QStyleOptionMenuItem()
            self.initStyleOption(option, action)
            label, _, shortcut = option.text.partition("\t")
            dangerous = "删除" in action.text() or action.text().lower().startswith("delete")
            color = (DANGER if dangerous else TEXT_MAIN) if action.isEnabled() else TEXT_MUTED
            painter.setPen(QtGui.QColor(color))
            painter.setFont(option.font)
            if action.menu():
                arrow_rect = QtCore.QRect(text_rect.right() - ICON_SIZE + 1,
                                         rect.top() + (rect.height() - ICON_SIZE) // 2, ICON_SIZE, ICON_SIZE)
                load_lucide_icon("chevron-right", color).paint(painter, arrow_rect)
                text_rect.adjust(0, 0, -ICON_SIZE - MENU_ICON_TEXT_GAP, 0)
            elif shortcut:
                width = painter.fontMetrics().horizontalAdvance(shortcut)
                painter.drawText(text_rect, QtCore.Qt.AlignRight | QtCore.Qt.AlignVCenter, shortcut)
                text_rect.adjust(0, 0, -width - 16, 0)
            label = painter.fontMetrics().elidedText(label, QtCore.Qt.ElideRight, text_rect.width())
            painter.drawText(text_rect, QtCore.Qt.AlignLeft | QtCore.Qt.AlignVCenter
                             | QtCore.Qt.TextShowMnemonic, label)


class StyledComboBox(QtWidgets.QComboBox):
    """Use the shared capsule menu while retaining native combo value APIs."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.popup_menu = StyledMenu(self)

    def showPopup(self):
        if not self.count():
            return
        self.popup_menu.clear()
        for index in range(self.count()):
            action = self.popup_menu.addAction(self.itemIcon(index), self.itemText(index))
            action.setEnabled(bool(self.model().flags(self.model().index(index, self.modelColumn())) & QtCore.Qt.ItemIsEnabled))
            action.setCheckable(True)
            action.setChecked(index == self.currentIndex())
            action.triggered.connect(lambda _checked=False, selected=index: self._activate_item(selected))
            action.hovered.connect(lambda selected=index: self.highlighted[int].emit(selected))
        self.popup_menu.popup(self.mapToGlobal(QtCore.QPoint(0, self.height() + 4)))
        if self.currentIndex() >= 0:
            self.popup_menu.setActiveAction(self.popup_menu.actions()[self.currentIndex()])

    def _activate_item(self, index):
        self.setCurrentIndex(index)
        self.activated[int].emit(index)
        self.activated[str].emit(self.itemText(index))

    def hidePopup(self):
        self.popup_menu.hide()
        super().hidePopup()
