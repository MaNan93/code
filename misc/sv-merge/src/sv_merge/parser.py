"""EDA filelist parser with recursive expansion and variable resolution."""

import os
import re
from .colors import log_warn


class FlistParser:
    """Recursively parses EDA filelists (-f, -F) with environment variable expansion."""

    def __init__(self, incdirs=None, defines=None):
        self.incdirs = list(incdirs or [])
        self.defines = list(defines or [])
        self.files = []
        self._visited_flists = set()

    def parse(self, flist_path, is_dash_F=False, base_dir=None):
        flist_path = os.path.expandvars(flist_path)
        if base_dir and not os.path.isabs(flist_path):
            abs_flist = os.path.normpath(os.path.join(base_dir, flist_path))
        else:
            abs_flist = os.path.normpath(os.path.abspath(flist_path))

        if abs_flist in self._visited_flists:
            return
        if not os.path.isfile(abs_flist):
            log_warn(f"Filelist not found: {abs_flist}")
            return

        self._visited_flists.add(abs_flist)
        flist_dir = os.path.dirname(abs_flist)
        effective_base = flist_dir if is_dash_F else (base_dir or os.getcwd())

        with open(abs_flist, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()

        # Remove multi-line comments /* ... */
        content = re.sub(r"/\*.*?\*/", "", content, flags=re.DOTALL)

        for raw_line in content.splitlines():
            line = raw_line.strip()
            # Remove single-line comment
            if "//" in line:
                line = line.split("//")[0].strip()
            if "#" in line and not line.startswith("`"):
                line = line.split("#")[0].strip()
            if not line:
                continue

            # Expand environment variables ($VAR or ${VAR})
            line = os.path.expandvars(line)

            tokens = line.split()
            idx = 0
            while idx < len(tokens):
                token = tokens[idx]

                if token in ("-f", "-file") and idx + 1 < len(tokens):
                    nested = tokens[idx + 1]
                    self.parse(nested, is_dash_F=False, base_dir=effective_base)
                    idx += 2
                elif token == "-F" and idx + 1 < len(tokens):
                    nested = tokens[idx + 1]
                    self.parse(nested, is_dash_F=True, base_dir=flist_dir)
                    idx += 2
                elif token.startswith("+incdir+"):
                    dirs = token[len("+incdir+"):].split("+")
                    for d in dirs:
                        norm_d = os.path.normpath(os.path.join(effective_base, d) if not os.path.isabs(d) else d)
                        if norm_d not in self.incdirs:
                            self.incdirs.append(norm_d)
                    idx += 1
                elif token.startswith("+define+"):
                    defs = token[len("+define+"):].split("+")
                    self.defines.extend(defs)
                    idx += 1
                elif token.startswith("-") or token.startswith("+"):
                    # EDA flags like -sverilog, -2012, -y, +libext+, etc.
                    # If flag expects an argument (like -y <dir>, -v <file>)
                    if token in ("-y", "-v", "-libext") and idx + 1 < len(tokens):
                        idx += 2
                    else:
                        idx += 1
                else:
                    # Source file path
                    clean_path = token.strip("\"'")
                    if not os.path.isabs(clean_path):
                        cand = os.path.normpath(os.path.join(effective_base, clean_path))
                    else:
                        cand = os.path.normpath(clean_path)

                    if cand not in self.files:
                        self.files.append(cand)
                    idx += 1
