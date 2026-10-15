"""Apply a theme to the existing widget tree without changing model state."""

from PyQt5 import QtGui, QtWidgets

from plm.frontend.qt.styles import get_app_qss
from plm.frontend.qt.styles.tokens import get_theme_color, set_active_theme
from plm.frontend.qt.widgets.common import (
    clear_icon_cache, icon_descriptor, load_lucide_icon, set_label_icon,
)


def apply_application_theme(theme):
    app = QtWidgets.QApplication.instance()
    # Save identities before clearing the raster cache. Include menus and
    # popups, which may be top-level widgets outside the main window tree.
    icons = []
    actions = set()
    for widget in app.allWidgets():
        actions.update(widget.actions())
        if isinstance(widget, QtWidgets.QAbstractButton):
            icons.append((widget.setIcon, icon_descriptor(widget.icon())))
        if isinstance(widget, QtWidgets.QComboBox):
            for index in range(widget.count()):
                descriptor = icon_descriptor(widget.itemIcon(index))
                icons.append((lambda icon, w=widget, i=index: w.setItemIcon(i, icon), descriptor))
        if isinstance(widget, QtWidgets.QTreeWidget):
            iterator = QtWidgets.QTreeWidgetItemIterator(widget)
            while iterator.value():
                item = iterator.value()
                for column in range(widget.columnCount()):
                    descriptor = icon_descriptor(item.icon(column))
                    icons.append((lambda icon, i=item, c=column: i.setIcon(c, icon), descriptor))
                iterator += 1
    for action in actions:
        icons.append((action.setIcon, icon_descriptor(action.icon())))
    set_active_theme(theme)
    clear_icon_cache()
    palette = QtGui.QPalette()
    roles = {
        QtGui.QPalette.Window: "bg_surface", QtGui.QPalette.WindowText: "text_main",
        QtGui.QPalette.Base: "bg_main", QtGui.QPalette.AlternateBase: "bg_alternate",
        QtGui.QPalette.Text: "text_main", QtGui.QPalette.Button: "bg_subtle",
        QtGui.QPalette.ButtonText: "text_main", QtGui.QPalette.Highlight: "primary_soft",
        QtGui.QPalette.HighlightedText: "text_main", QtGui.QPalette.Link: "text_primary",
        QtGui.QPalette.LinkVisited: "text_primary", QtGui.QPalette.ToolTipBase: "tooltip_bg",
        QtGui.QPalette.ToolTipText: "tooltip_text", QtGui.QPalette.PlaceholderText: "text_muted",
        QtGui.QPalette.Light: "border_hover", QtGui.QPalette.Midlight: "border",
        QtGui.QPalette.Dark: "border", QtGui.QPalette.Mid: "border",
        QtGui.QPalette.Shadow: "border_panel", QtGui.QPalette.BrightText: "text_on_primary",
    }
    for role, color in roles.items():
        palette.setColor(role, QtGui.QColor(get_theme_color(color)))
    for role in (QtGui.QPalette.Text, QtGui.QPalette.WindowText, QtGui.QPalette.ButtonText):
        palette.setColor(QtGui.QPalette.Disabled, role, QtGui.QColor(get_theme_color("text_muted")))
    app.setPalette(palette)
    app.setStyleSheet(get_app_qss(theme))
    for setter, descriptor in icons:
        if descriptor:
            name, role, color, size, aligned = descriptor
            setter(load_lucide_icon(name, role or color, size, aligned))
    for widget in app.allWidgets():
        if isinstance(widget, QtWidgets.QLabel) and widget.property("lucideName"):
            set_label_icon(widget, widget.property("lucideName"),
                           widget.property("lucideRole"), widget.property("lucideSize"))
        refresh = getattr(widget, "refresh_theme", None)
        if refresh is not None:
            refresh()
        widget.update()
