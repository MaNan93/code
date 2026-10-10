"""Apply output naming without changing user ports, fields or instance names."""

from dataclasses import dataclass
from pathlib import PurePosixPath
import re


_DESIGN_NAMES = frozenset({
    "pipe_lane_signal_pkg", "pipe_lane_mode_dec", "pipe_lane_sel_gen",
    "pipe_lane_clk_mux", "pipe_lane_rst_mux", "pipe_lane_data_m2p",
    "pipe_lane_data_p2m", "pipe_lane_mapper", "pipe_lane_mapper_connection",
    "pipe_lane_sync2", "pipe_lane_sel_sync", "pipe_lane_clk_gate",
    "pipe_lane_clk_or", "pipe_lane_data_mux", "tb_pipe_lane_mapper",
})
_MACROS = frozenset({
    "PIPE_USE_ICG_CELL", "PIPE_ICG_CELL", "PIPE_USE_CLKOR_CELL",
    "PIPE_CLKOR_CELL", "DUMP_FSDB",
})
# Keep comments and quoted strings intact; retain source spans for replacements.
_TOKENS = re.compile(
    r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"|'
    r'`?[A-Za-z_$][A-Za-z0-9_$]*|::|[^\s]',
    re.DOTALL,
)
_IDENTIFIER = re.compile(r"[A-Za-z_$][A-Za-z0-9_$]*\Z")


@dataclass(frozen=True)
class GenerationNames:
    module_prefix: str = ""
    file_prefix: str = ""
    macro_prefix: str = ""

    @classmethod
    def from_options(cls, options):
        return cls(options.module_prefix, options.file_prefix, options.macro_prefix)

    def identifier(self, name):
        return self.module_prefix + name

    def file(self, name):
        return self.file_prefix + name

    def sv_source(self, source):
        """Rename PLM declarations/types/macros in their syntactic contexts.

        A plain word replacement would also rename a user signal whose name
        happens to equal a module name. Only declarations, imports, scope
        qualifiers, instance types and waveform root scopes are rewritten.
        """
        if not self.module_prefix and not self.macro_prefix:
            return source
        matches = [match for match in _TOKENS.finditer(source)
                   if not match.group().startswith(('//', '/*', '"'))]
        tokens = [match.group() for match in matches]
        replacements = []
        for index, (match, token) in enumerate(zip(matches, tokens)):
            previous = tokens[index - 1] if index else ""
            following = tokens[index + 1:index + 3]
            replacement = None
            if self.macro_prefix:
                if token.startswith("`") and token[1:] in _MACROS:
                    replacement = "`" + self.macro_prefix + token[1:]
                elif token in _MACROS and previous in {
                    "`ifdef", "`ifndef", "`elsif", "`define", "`undef",
                }:
                    replacement = self.macro_prefix + token
            if self.module_prefix and token in _DESIGN_NAMES:
                declaration = previous in {"module", "package", "import"}
                scope = following[:1] == ["::"]
                instance_type = previous != "." and (
                    following == ["#", "("] or (
                        len(following) == 2 and _IDENTIFIER.fullmatch(following[0])
                        and following[1] == "("
                    )
                )
                dump_scope = token == "tb_pipe_lane_mapper" and tokens[max(0, index - 4):index] in (
                    ["$dumpvars", "(", "0", ","],
                    ["$fsdbDumpvars", "(", "0", ","],
                )
                if declaration or scope or instance_type or dump_scope:
                    replacement = self.identifier(token)
            if replacement is not None:
                replacements.append((match.start(), match.end(), replacement))
        for start, end, replacement in reversed(replacements):
            source = source[:start] + replacement + source[end:]
        return source

    def filelist(self, source):
        if not self.file_prefix:
            return source
        lines = []
        for line in source.splitlines(keepends=True):
            path = PurePosixPath(line.strip())
            if path.suffix == ".sv":
                line = line.replace(path.as_posix(), path.with_name(self.file(path.name)).as_posix())
            lines.append(line)
        return "".join(lines)

    def makefile(self, source):
        return source.replace(
            "../tb/tb_pipe_lane_mapper.sv", "../tb/" + self.file("tb_pipe_lane_mapper.sv")
        ).replace("+define+DUMP_FSDB", "+define+" + self.macro_prefix + "DUMP_FSDB")
