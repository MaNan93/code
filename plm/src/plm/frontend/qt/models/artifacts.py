"""File selection state independent of the artifact preview widgets."""

from pathlib import Path


class ArtifactSelection:
    def __init__(self):
        self.files = ()
        self.current_index = -1

    @property
    def current_path(self):
        return self.files[self.current_index] if self.current_index >= 0 else None

    def set_files(self, files, keep_current=True):
        previous = self.current_path if keep_current else None
        self.files = tuple(dict.fromkeys(Path(path).resolve() for path in files))
        self.current_index = self.files.index(previous) if previous in self.files else (0 if self.files else -1)

    def select(self, path):
        path = Path(path).resolve()
        if path not in self.files:
            return False
        self.current_index = self.files.index(path)
        return True
