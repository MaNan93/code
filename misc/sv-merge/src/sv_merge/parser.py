"""EDA filelist parser with recursive expansion and variable resolution."""

import os
import re
from .colors import log_warn
from .source import mask_comments, read_source


class FlistParser:
    """Recursively parses EDA filelists (-f, -F) with environment variable expansion."""

    def __init__(self, incdirs=None, defines=None):
        self.incdirs = list(incdirs or [])
        self.defines = list(defines or [])
        self.files = []
        self._active_flists = []
        self.filelist_paths = []

    def parse(self, flist_path, is_dash_F=False, base_dir=None):
        flist_path = os.path.expandvars(flist_path.strip("\"'"))
        if base_dir and not os.path.isabs(flist_path):
            abs_flist = os.path.realpath(os.path.join(base_dir, flist_path))
        else:
            abs_flist = os.path.realpath(flist_path)

        if abs_flist in self._active_flists:
            raise ValueError("Recursive filelist: " + " -> ".join(self._active_flists + [abs_flist]))
        if not os.path.isfile(abs_flist):
            raise ValueError(f"Filelist not found: {abs_flist}")

        self._active_flists.append(abs_flist)
        self.filelist_paths.append(abs_flist)
        flist_dir = os.path.dirname(abs_flist)
        effective_base = flist_dir if is_dash_F else os.getcwd()

        content = mask_comments(read_source(abs_flist)).replace('\\\n', ' ')

        for raw_line in content.splitlines():
            line = raw_line.strip()
            if line.startswith("#"):
                continue
            if not line:
                continue

            # Expand environment variables ($VAR or ${VAR})
            line = os.path.expandvars(line)

            # Keep quotes in define values, including embedded spaces and plus signs.
            tokens = re.findall(r"'[^'\n]*'|(?:[^\s\"]+|\"[^\"\n]*\")+", line)
            if '#' in tokens:
                tokens = tokens[:tokens.index('#')]
            idx = 0
            while idx < len(tokens):
                token = tokens[idx]
                if token in ('-f', '-file', '-F', '-v', '-y', '-libext') and idx + 1 >= len(tokens):
                    raise ValueError('{}: missing argument for {}'.format(abs_flist, token))

                if token in ("-f", "-file") and idx + 1 < len(tokens):
                    nested = tokens[idx + 1]
                    self.parse(nested, is_dash_F=False, base_dir=effective_base)
                    idx += 2
                elif token == "-F" and idx + 1 < len(tokens):
                    nested = tokens[idx + 1]
                    self.parse(nested, is_dash_F=True, base_dir=effective_base)
                    idx += 2
                elif token.startswith("+incdir+"):
                    dirs = self._split_plus(token[len("+incdir+"):])
                    for d in dirs:
                        d = d.strip("\"'")
                        norm_d = os.path.normpath(os.path.join(effective_base, d) if not os.path.isabs(d) else d)
                        if norm_d not in self.incdirs:
                            self.incdirs.append(norm_d)
                    idx += 1
                elif token.startswith("+define+"):
                    defs = self._split_plus(token[len("+define+"):])
                    self.defines.extend(defs)
                    idx += 1
                elif token.startswith("-") or token.startswith("+"):
                    # EDA flags like -sverilog, -2012, -y, +libext+, etc.
                    # If flag expects an argument (like -y <dir>, -v <file>)
                    if token == "-v" and idx + 1 < len(tokens):
                        library = tokens[idx + 1].strip("\"'")
                        self.files.append(os.path.normpath(os.path.join(effective_base, library)))
                        idx += 2
                    elif token in ("-y", "-libext") and idx + 1 < len(tokens):
                        log_warn("Library option {} {} is not bundled; resolve library cells separately".format(token, tokens[idx + 1]))
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

                    self.files.append(cand)
                    idx += 1

        self._active_flists.pop()

    @staticmethod
    def _split_plus(value):
        return re.split(r'\+(?=(?:[^"\n]*"[^"\n]*")*[^"\n]*$)', value)
