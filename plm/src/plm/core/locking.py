"""Reentrant workspace exclusion shared by CLI and GUI processes."""

from contextlib import contextmanager
import os
from pathlib import Path
from threading import local


_local = local()
LOCK_FILENAME = ".plm-lock"


class WorkspaceBusyError(OSError):
    """Another process or thread is writing this workspace."""


@contextmanager
def workspace_lock(root):
    root = Path(root).resolve()
    key = os.path.normcase(str(root))
    held = getattr(_local, "held", None)
    if held is None or getattr(_local, "pid", None) != os.getpid():
        held = _local.held = {}
        _local.pid = os.getpid()
    if key in held:
        yield
        return
    root.mkdir(parents=True, exist_ok=True)
    # Keep this file after unlocking: unlinking a lock file lets a second
    # process lock a different inode while the first one is still in use.
    with (root / LOCK_FILENAME).open("a+b") as stream:
        if os.fstat(stream.fileno()).st_size == 0:
            stream.write(b"\0")
            stream.flush()
        stream.seek(0)
        if os.name == "nt":
            import msvcrt

            acquire = lambda: msvcrt.locking(stream.fileno(), msvcrt.LK_NBLCK, 1)
            release = lambda: msvcrt.locking(stream.fileno(), msvcrt.LK_UNLCK, 1)
        else:
            import fcntl

            acquire = lambda: fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
            release = lambda: fcntl.flock(stream, fcntl.LOCK_UN)
        try:
            acquire()
        except OSError as error:
            raise WorkspaceBusyError(f"工作区正在被其他任务写入，请稍后重试：{root}") from error
        held[key] = stream
        try:
            yield
        finally:
            held.pop(key)
            release()
