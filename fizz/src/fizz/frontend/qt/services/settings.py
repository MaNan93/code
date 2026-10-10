"""Persist desktop layout separately from Fizz's existing workflow config."""

from PyQt5 import QtCore


class SettingsService:
    def __init__(self, settings=None):
        self.settings = (
            settings if settings is not None else QtCore.QSettings("Fizz", "Desktop")
        )

    def restore(self, window):
        geometry = self.settings.value("geometry")
        if geometry:
            window.restoreGeometry(geometry)
        if not any(
            screen.availableGeometry().intersects(window.frameGeometry())
            for screen in QtCore.QCoreApplication.instance().screens()
        ):
            screen = QtCore.QCoreApplication.instance().primaryScreen()
            window.move(screen.availableGeometry().center() - window.rect().center())
        page = self.settings.value("workflow", "merge")
        window.select_workflow(page if page in window.pages else "merge")
        collapsed = self.settings.value("sidebar_collapsed", False, type=bool)
        window.nav_panel.set_collapsed(collapsed, animate=False)
        for key, view in window.pages.items():
            state = self.settings.value(f"splitters/{key}")
            if state:
                view.splitter.restoreState(state)

    def save(self, window):
        self.settings.setValue("geometry", window.saveGeometry())
        self.settings.setValue("workflow", window.current_workflow)
        self.settings.setValue("sidebar_collapsed", window.nav_panel.is_collapsed)
        for key, view in window.pages.items():
            self.settings.setValue(f"splitters/{key}", view.splitter.saveState())
        self.settings.sync()
