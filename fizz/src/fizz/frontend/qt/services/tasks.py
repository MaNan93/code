"""QThread workers wrapping fizz.core's blocking calls.

Qt only allows the GUI thread to touch widgets, so every long-running core
call (merge/obfuscate/vcs/rlskit/ftp) runs here and reports back through
signals -- Qt auto-queues a signal emitted from a worker thread onto the
receiving (GUI-thread) slot, so connected slots can update widgets directly
without their own locking.
"""

from PyQt5 import QtCore

from fizz import core


class MergeWorker(QtCore.QThread):
    progress = QtCore.pyqtSignal(int, int)
    finished_ok = QtCore.pyqtSignal(object)
    failed = QtCore.pyqtSignal(str)

    def __init__(
        self,
        all_files,
        out_path,
        msg_dir,
        script_dir,
        protect,
        top_name,
        strip_comments,
        parent=None,
    ):
        super().__init__(parent)
        self._args = (
            all_files,
            out_path,
            msg_dir,
            script_dir,
            protect,
            top_name,
            strip_comments,
        )

    def run(self):
        try:
            result = core.merge_files(
                *self._args, on_progress=lambda i, t: self.progress.emit(i, t)
            )
        except Exception as e:  # noqa: BLE001 - report failures at the Qt boundary
            self.failed.emit(str(e))
            return
        self.finished_ok.emit(result)


class LineStreamWorker(QtCore.QThread):
    """Runs a core function of the form func(*args, on_line) -> result,
    streaming each on_line(text) call out as the `line` signal."""

    line = QtCore.pyqtSignal(str)
    finished_ok = QtCore.pyqtSignal(object)
    failed = QtCore.pyqtSignal(str)

    def __init__(self, func, *args, not_found_message=None, parent=None):
        super().__init__(parent)
        self._func = func
        self._args = args
        self._not_found_message = not_found_message

    def run(self):
        try:
            result = self._func(*self._args, on_line=lambda text: self.line.emit(text))
        except FileNotFoundError as e:
            self.failed.emit(self._not_found_message or str(e))
            return
        except Exception as e:  # noqa: BLE001 - report failures at the Qt boundary
            self.failed.emit(str(e))
            return
        self.finished_ok.emit(result)


class RLskitWorker(QtCore.QThread):
    """Runs RLskit and reports upload byte progress separately from logs."""

    line = QtCore.pyqtSignal(str)
    # Python objects avoid Qt's signed 32-bit int limit for archives >2 GiB.
    upload_progress = QtCore.pyqtSignal(object, object)
    finished_ok = QtCore.pyqtSignal(object)
    failed = QtCore.pyqtSignal(str)
    cancelled = QtCore.pyqtSignal()

    def __init__(self, src, suffix, ftp_url, ftp_user, ftp_pass, parent=None):
        super().__init__(parent)
        self._args = (src, suffix, ftp_url, ftp_user, ftp_pass)

    def run(self):
        try:
            result = core.run_rlskit_package(
                *self._args,
                on_line=lambda text: self.line.emit(text),
                on_progress=lambda current, total: self.upload_progress.emit(
                    current, total
                ),
                should_cancel=self.isInterruptionRequested,
            )
        except core.UploadCancelled:
            self.cancelled.emit()
            return
        except Exception as e:  # noqa: BLE001 - report failures at the Qt boundary
            self.failed.emit(str(e))
            return
        self.finished_ok.emit(result)


class RLskitUploadWorker(QtCore.QThread):
    """Uploads an already-built RLskit archive, used for overwrite retry."""

    line = QtCore.pyqtSignal(str)
    upload_progress = QtCore.pyqtSignal(object, object)
    finished_ok = QtCore.pyqtSignal(object)
    failed = QtCore.pyqtSignal(str)
    cancelled = QtCore.pyqtSignal()

    def __init__(self, tar_file, target_url, ftp_user, ftp_pass, parent=None):
        super().__init__(parent)
        self._args = (tar_file, target_url, ftp_user, ftp_pass, True)

    def run(self):
        try:
            result = core.run_rlskit_ftp_upload(
                *self._args,
                on_line=lambda text: self.line.emit(text),
                on_progress=lambda current, total: self.upload_progress.emit(
                    current, total
                ),
                should_cancel=self.isInterruptionRequested,
            )
        except core.UploadCancelled:
            self.cancelled.emit()
            return
        except Exception as e:  # noqa: BLE001 - report failures at the Qt boundary
            self.failed.emit(str(e))
            return
        self.finished_ok.emit(result)


class FtpConnectWorker(QtCore.QThread):
    """Connects, then cwd's into `initial_path` and lists it."""

    listed = QtCore.pyqtSignal(str, list)
    failed = QtCore.pyqtSignal(str)

    def __init__(self, host, user, passwd, initial_path, parent=None):
        super().__init__(parent)
        self.host = host
        self.user = user
        self.passwd = passwd
        self.initial_path = initial_path
        self.ftp = None

    def run(self):
        try:
            self.ftp = core.connect_ftp(self.host, self.user, self.passwd)
            pwd, entries = core.list_ftp_dir(self.ftp, self.initial_path)
        except Exception as e:  # noqa: BLE001 - report failures at the Qt boundary
            self.failed.emit(str(e))
            return
        self.listed.emit(pwd, entries)


class FtpListWorker(QtCore.QThread):
    """Lists `path` on an already-connected ftp handle."""

    listed = QtCore.pyqtSignal(str, list)
    failed = QtCore.pyqtSignal(str)

    def __init__(self, ftp, path, parent=None):
        super().__init__(parent)
        self.ftp = ftp
        self.path = path

    def run(self):
        try:
            pwd, entries = core.list_ftp_dir(self.ftp, self.path)
        except Exception as e:  # noqa: BLE001 - report failures at the Qt boundary
            self.failed.emit(str(e))
            return
        self.listed.emit(pwd, entries)
