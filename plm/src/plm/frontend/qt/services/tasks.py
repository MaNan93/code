"""Run non-UI operations and deliver callbacks on the GUI thread."""

from PyQt5 import QtCore


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

    def run(self):
        try:
            result = self.operation(self.report)
        except Exception as error:
            self.signals.failed.emit(self.task_id, error)
        else:
            self.signals.completed.emit(self.task_id, result)

    def report(self, percent, message=""):
        self.signals.progress.emit(self.task_id, max(0, min(100, percent)), message)


class TaskRunner(QtCore.QObject):
    """Keep workers alive; all completion/progress callbacks run on this thread."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self._next_id = 0
        self._tasks = {}
        self._pool = QtCore.QThreadPool.globalInstance()

    def submit(self, operation, completed, failed, progress=None):
        self._next_id += 1
        task_id = self._next_id
        worker = Worker(task_id, operation)
        self._tasks[task_id] = (worker, completed, failed, progress)
        worker.signals.completed.connect(self._complete, QtCore.Qt.QueuedConnection)
        worker.signals.failed.connect(self._fail, QtCore.Qt.QueuedConnection)
        worker.signals.progress.connect(self._progress, QtCore.Qt.QueuedConnection)
        self._pool.start(worker)
        return task_id

    @QtCore.pyqtSlot(int, object)
    def _complete(self, task_id, result):
        task = self._tasks.pop(task_id, None)
        if task:
            task[1](result)

    @QtCore.pyqtSlot(int, object)
    def _fail(self, task_id, error):
        task = self._tasks.pop(task_id, None)
        if task:
            task[2](error)

    @QtCore.pyqtSlot(int, int, str)
    def _progress(self, task_id, percent, message):
        task = self._tasks.get(task_id)
        if task and task[3]:
            task[3](percent, message)
