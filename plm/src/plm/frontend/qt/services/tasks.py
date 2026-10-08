"""Run non-UI operations and deliver callbacks on the GUI thread."""

from threading import Event
from PyQt5 import QtCore


class TaskCancelled(Exception):
    """A superseded read-only operation stopped at a cancellation boundary."""


class TaskProgress:
    def __init__(self, task_id, signals, cancelled):
        self.task_id = task_id
        self.signals = signals
        self._cancelled = cancelled

    @property
    def cancelled(self):
        return self._cancelled.is_set()

    def check_cancelled(self):
        if self.cancelled:
            raise TaskCancelled()

    def __call__(self, percent, message=""):
        self.check_cancelled()
        self.signals.progress.emit(
            self.task_id, max(0, min(100, percent)), message
        )


class WorkerSignals(QtCore.QObject):
    completed = QtCore.pyqtSignal(int, object)
    failed = QtCore.pyqtSignal(int, object)
    progress = QtCore.pyqtSignal(int, int, str)


class Worker(QtCore.QRunnable):
    def __init__(self, task_id, operation):
        super().__init__()
        self.task_id = task_id
        self.operation = operation
        self.signals = WorkerSignals()
        self.cancelled = Event()
        self.report = TaskProgress(task_id, self.signals, self.cancelled)

    def run(self):
        try:
            self.report.check_cancelled()
            result = self.operation(self.report)
        except BaseException as error:
            # Config readers may raise SystemExit. Every worker outcome must
            # reach the GUI-side cleanup, including superseded keyed jobs.
            self.signals.failed.emit(self.task_id, error)
        else:
            self.signals.completed.emit(self.task_id, result)


class TaskRunner(QtCore.QObject):
    """Keep workers alive; all completion/progress callbacks run on this thread."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self._next_id = 0
        self._tasks = {}
        self._latest = {}
        self._pending = {}
        self._task_keys = {}
        self._pool = QtCore.QThreadPool.globalInstance()

    def submit(self, operation, completed, failed, progress=None):
        task_id = self._prepare(operation, completed, failed, progress)
        self._pool.start(self._tasks[task_id][0])
        return task_id

    def _prepare(self, operation, completed, failed, progress):
        self._next_id += 1
        task_id = self._next_id
        worker = Worker(task_id, operation)
        self._tasks[task_id] = (worker, completed, failed, progress)
        worker.signals.completed.connect(self._complete, QtCore.Qt.QueuedConnection)
        worker.signals.failed.connect(self._fail, QtCore.Qt.QueuedConnection)
        worker.signals.progress.connect(self._progress, QtCore.Qt.QueuedConnection)
        return task_id

    def submit_latest(self, key, operation, completed, failed, progress=None):
        """Coalesce read-only requests to one running and one latest pending job."""
        self.cancel_latest(key)
        task_id = self._prepare(operation, completed, failed, progress)
        self._task_keys[task_id] = key
        if key in self._latest:
            self._pending[key] = task_id
        else:
            self._latest[key] = task_id
            self._pool.start(self._tasks[task_id][0])
        return task_id

    def cancel_latest(self, key):
        running = self._tasks.get(self._latest.get(key))
        if running:
            running[0].cancelled.set()
        pending_id = self._pending.pop(key, None)
        if pending_id is not None:
            self._tasks.pop(pending_id, None)
            self._task_keys.pop(pending_id, None)

    def _take_finished(self, task_id):
        task = self._tasks.pop(task_id, None)
        key = self._task_keys.pop(task_id, None)
        if key is not None and self._latest.get(key) == task_id:
            self._latest.pop(key)
            pending_id = self._pending.pop(key, None)
            if pending_id is not None:
                self._latest[key] = pending_id
                self._pool.start(self._tasks[pending_id][0])
        return task

    @QtCore.pyqtSlot(int, object)
    def _complete(self, task_id, result):
        task = self._take_finished(task_id)
        if task and not task[0].cancelled.is_set():
            task[1](result)

    @QtCore.pyqtSlot(int, object)
    def _fail(self, task_id, error):
        task = self._take_finished(task_id)
        if task and not task[0].cancelled.is_set():
            task[2](error)

    @QtCore.pyqtSlot(int, int, str)
    def _progress(self, task_id, percent, message):
        task = self._tasks.get(task_id)
        if task and not task[0].cancelled.is_set() and task[3]:
            task[3](percent, message)
