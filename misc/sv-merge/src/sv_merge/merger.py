"""Bundle sources, expanding literal includes at their original locations."""
import os
import re
import tempfile

from .colors import log_info
from .source import mask_comments, read_source


class Merger:
    def __init__(self, ordered_files, output_path, guard=False, neutralize=True,
                 verbose=True, version="1.0.0", incdirs=None, defines=None,
                 line_directives=False):
        self.ordered_files = ordered_files
        self.output_path = output_path
        self.guard = guard
        self.neutralize = neutralize
        self.verbose = verbose
        self.version = version
        self.incdirs = list(incdirs or [])
        self.defines = list(defines or [])
        self.line_directives = line_directives
        self._cache = {}
        self._lexed = {}
        self._guards = {}
        self._invalidations = {}
        self._clear_count = 0
        self._defined = set()
        self.include_count = 0

    def _read(self, path):
        path = os.path.realpath(path)
        if path == os.path.realpath(self.output_path) or (
                os.path.exists(self.output_path) and os.path.samefile(path, self.output_path)):
            raise ValueError("Output aliases an input source: {}".format(path))
        if path not in self._cache:
            self._cache[path] = read_source(path)
        return self._cache[path]

    def _resolve(self, target, parent):
        for directory in [os.path.dirname(parent)] + self.incdirs:
            path = os.path.realpath(os.path.join(directory, target))
            if os.path.isfile(path):
                return path
        raise ValueError('Include {!r} not found from {}'.format(target, parent))

    def _location(self, out, line, path, level=0):
        if self.line_directives:
            escaped = path.replace('\\', '\\\\').replace('"', '\\"')
            out.write('`line {} "{}" {}\n'.format(line, escaped, level))

    def _expand(self, path, out, stack, unconditional=True):
        path = os.path.realpath(path)
        text = self._read(path)
        if path not in self._lexed:
            self._lexed[path] = mask_comments(text).splitlines(keepends=True)
        masked = self._lexed[path]
        if path not in self._guards:
            self._guards[path] = self._guard(masked)
        guard = self._guards[path] if self.neutralize else None
        invalidations = (self._invalidations.get(guard, 0), self._clear_count)
        if guard and guard in self._defined:
            out.write('// Include guard already defined: {}\n'.format(guard))
            return
        if path in stack:
            raise ValueError('Recursive include (guarded cycles are also unsupported): ' +
                             ' -> '.join(stack + [path]))
        self._location(out, 1, path, 1 if stack else 0)
        if not self.neutralize:
            out.write(text)
        else:
            original = text.splitlines(keepends=True)
            continuation = False
            depth = 0
            for number, (line, visible) in enumerate(zip(original, masked), 1):
                active_line = not continuation
                directive = re.match(r'^\s*`include\b', visible) if active_line else None
                state = re.match(r'^\s*`(ifdef|ifndef|endif|define|undef|undefineall)\b\s*(\w+)?', visible) if active_line else None
                if state:
                    kind, name = state.groups()
                    if kind in ('ifdef', 'ifndef'):
                        depth += 1
                    elif kind == 'endif':
                        depth -= 1
                    elif kind == 'undef':
                        self._defined.discard(name)
                        self._invalidations[name] = self._invalidations.get(name, 0) + 1
                    elif kind == 'undefineall':
                        self._defined.clear()
                        self._clear_count += 1
                    elif kind == 'define' and depth == 0 and unconditional:
                        self._defined.add(name)
                continuation = visible.rstrip('\r\n').endswith('\\')
                if not directive:
                    out.write(line)
                    continue
                match = re.fullmatch(r'\s*`include\s+"([^"\n]+)"\s*', visible)
                if not match:
                    raise ValueError('{}:{}: only standalone literal includes are supported; '
                                     'use --keep-includes to retain macro includes'.format(path, number))
                target = self._resolve(match.group(1), path)
                self.include_count += 1
                start = visible.index('`include')
                end = visible.index('"', visible.index('"') + 1) + 1
                prefix, suffix = line[:start], line[end:]
                if prefix.strip():
                    out.write(prefix + '\n')
                self._expand(target, out, stack + [path], unconditional and depth == 0)
                self._location(out, number, path, 2)
                out.write(suffix if suffix.endswith('\n') else suffix + '\n')
        if guard and unconditional and invalidations == (self._invalidations.get(guard, 0), self._clear_count):
            self._defined.add(guard)
        if text and not text.endswith('\n'):
            out.write('\n')

    @staticmethod
    def _guard(lines):
        """Recognize a whole-file guard, with no outer else or guard mutations."""
        text = ''.join(lines).strip()
        first = re.match(r'`ifndef\s+(\w+)\s*\n\s*`define\s+\1\s*\n', text)
        if not first:
            return None
        guard = first.group(1)
        depth = 0
        rows = text.splitlines()
        for index, line in enumerate(rows):
            directive = re.match(r'^\s*`(ifdef|ifndef|endif|else|elsif|undef|undefineall)\b\s*(\w+)?', line)
            if not directive:
                continue
            kind, name = directive.groups()
            if kind in ('ifdef', 'ifndef'):
                depth += 1
            elif kind == 'endif':
                depth -= 1
                if depth == 0 and index != len(rows) - 1:
                    return None
            elif kind in ('else', 'elsif') and depth == 1:
                return None
            elif kind == 'undefineall' or (kind == 'undef' and name == guard):
                return None
        return guard if depth == 0 and re.search(r'`endif\s*$', text) else None

    def run(self):
        self._cache.clear()
        self._lexed.clear()
        self._guards.clear()
        self._invalidations.clear()
        self._clear_count = 0
        for path in self.ordered_files:
            self._read(path)
        output = os.path.abspath(self.output_path)
        if os.path.islink(output):
            output = os.path.realpath(output)
        os.makedirs(os.path.dirname(output), exist_ok=True)
        fd, temporary = tempfile.mkstemp(prefix='.sv-merge-', suffix='.sv',
                                         dir=os.path.dirname(output))
        self.include_count = 0
        self._defined = set(d.partition("=")[0] for d in self.defines)
        try:
            with os.fdopen(fd, 'w', encoding='utf-8') as out:
                out.write('// Generated by sv-merge {}\n'.format(self.version))
                for definition in self.defines:
                    name, sep, value = definition.partition('=')
                    if not re.fullmatch(r'[a-zA-Z_][a-zA-Z0-9_$]*', name) or '\n' in value or '\r' in value:
                        raise ValueError('Invalid filelist define: {!r}'.format(definition))
                    out.write('`define {} {}\n'.format(name, value if sep else ''))
                for path in self.ordered_files:
                    out.write('\n// FILE: {}\n'.format(path))
                    if self.guard:
                        out.write('`default_nettype wire\n')
                    self._expand(path, out, [])
                    if self.guard:
                        out.write('\n`default_nettype wire\n')
            os.replace(temporary, output)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
        log_info('Merged {} sources; expanded {} include occurrences into {!r}'.format(
            len(self.ordered_files), self.include_count, self.output_path), self.verbose)
