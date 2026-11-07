"""SystemVerilog dependency analyzer and topological DAG sorter."""

import os
import re
from collections import defaultdict, deque
from .colors import log_warn


class DependencyAnalyzer:
    """Analyzes package declarations, imports, and include relationships to form a DAG."""

    def __init__(self, file_paths):
        self.file_paths = file_paths
        self.pkg_to_file = {}
        self.file_imports = defaultdict(set)
        self.file_pkgs = defaultdict(list)
        self.file_includes = defaultdict(list)
        self.is_header = {}
        self.is_undef = {}

    def analyze(self):
        for fpath in self.file_paths:
            fname = os.path.basename(fpath).lower()
            self.is_undef[fpath] = "undef" in fname

            if not os.path.isfile(fpath):
                continue

            try:
                with open(fpath, "r", encoding="utf-8", errors="ignore") as fp:
                    content = fp.read()

                # Find package declarations
                for pkg in re.findall(r"^\s*package\s+(\w+)\s*;", content, re.M):
                    self.pkg_to_file[pkg] = fpath
                    self.file_pkgs[fpath].append(pkg)

                # Find imported packages
                for imp in re.findall(r"^\s*import\s+(\w+)::", content, re.M):
                    self.file_imports[fpath].add(imp)

                # Find `include directives
                for inc in re.findall(r"^\s*`include\s+[\"<]([^\">]+)[\">]", content, re.M):
                    self.file_includes[fpath].append(inc.strip())

                # Detect if file defines modules or interfaces
                has_mod_or_if = bool(re.search(r"^\s*(module|interface|macromodule)\s+\w+", content, re.M))
                has_imports = bool(self.file_imports[fpath])
                has_packages = bool(self.file_pkgs[fpath])

                # A pure header file defines constants/macros without modules/interfaces or imports
                self.is_header[fpath] = (
                    fname.endswith((".vh", ".svh"))
                    and not has_mod_or_if
                    and not has_imports
                    and not has_packages
                )
            except Exception as e:
                log_warn(f"Failed to inspect {fpath}: {e}")

    def topological_sort(self, top_file=None):
        """Returns the files sorted in DAG dependency order."""
        # 1. Separate files into categories
        headers_and_defs = []
        pkg_files = []
        regular_files = []
        undef_files = []

        all_pkg_files_set = set(self.pkg_to_file.values())

        for fpath in self.file_paths:
            if self.is_undef.get(fpath, False):
                undef_files.append(fpath)
            elif fpath in all_pkg_files_set:
                if fpath not in pkg_files:
                    pkg_files.append(fpath)
            elif self.is_header.get(fpath, False) and not self.file_pkgs.get(fpath):
                headers_and_defs.append(fpath)
            else:
                regular_files.append(fpath)

        # 2. Topologically sort package files
        pkg_deps = defaultdict(set)
        for pkg, fpath in self.pkg_to_file.items():
            for imp in self.file_imports[fpath]:
                if imp in self.pkg_to_file and self.pkg_to_file[imp] != fpath:
                    # fpath depends on dependency_file
                    pkg_deps[fpath].add(self.pkg_to_file[imp])

        # Kahn's Algorithm on package files
        in_degree = {f: 0 for f in pkg_files}
        dependents = defaultdict(set)
        for f, deps in pkg_deps.items():
            in_degree[f] = len(deps)
            for d in deps:
                dependents[d].add(f)

        queue = deque([f for f in pkg_files if in_degree[f] == 0])
        sorted_pkgs = []

        while queue:
            curr = queue.popleft()
            sorted_pkgs.append(curr)
            for dep in dependents[curr]:
                in_degree[dep] -= 1
                if in_degree[dep] == 0:
                    queue.append(dep)

        # If cycles were detected, append any remaining packages in original order
        if len(sorted_pkgs) < len(pkg_files):
            log_warn("Cycle detected in package imports! Retaining flist order for cyclic nodes.")
            for f in pkg_files:
                if f not in sorted_pkgs:
                    sorted_pkgs.append(f)

        # 3. Assemble final ordered list
        ordered = headers_and_defs + sorted_pkgs + regular_files

        # Handle top file placement (top should be near the end, just before undef)
        if top_file:
            norm_top = os.path.normpath(top_file)
            matched = [f for f in ordered if os.path.normpath(f) == norm_top or os.path.basename(f) == top_file]
            for m in matched:
                ordered.remove(m)
                ordered.append(m)

        ordered += undef_files
        return ordered
