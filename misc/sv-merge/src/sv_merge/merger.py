"""Bundles ordered SystemVerilog/Verilog source files with include neutralization."""

import os
import re
from .colors import log_info, log_warn, log_error


class Merger:
    """Merges ordered files, neutralizes internal redundant `include directives, and guards boundaries."""

    def __init__(self, ordered_files, output_path, guard=True, neutralize=True, verbose=True, version="1.0.0"):
        self.ordered_files = ordered_files
        self.output_path = output_path
        self.guard = guard
        self.neutralize = neutralize
        self.verbose = verbose
        self.version = version

        # Build registry of all embedded files (both full relative/abs paths and basenames)
        self.embedded_registry = set()
        for f in ordered_files:
            self.embedded_registry.add(os.path.normpath(f))
            self.embedded_registry.add(os.path.basename(f))
            # Also relative without leading directories
            parts = os.path.normpath(f).split(os.sep)
            for i in range(1, len(parts)):
                self.embedded_registry.add(os.path.join(*parts[i:]))

    def run(self):
        os.makedirs(os.path.dirname(os.path.abspath(self.output_path)) or ".", exist_ok=True)

        neutralized_count = 0
        total_lines = 0
        valid_files_count = 0

        with open(self.output_path, "w", encoding="utf-8") as out:
            out.write("// =============================================================================\n")
            out.write("// Auto-generated single-file SystemVerilog package by sv-merge\n")
            out.write(f"// Version: {self.version}\n")
            out.write(f"// Total Source Files Bundled: {len(self.ordered_files)}\n")
            out.write("// =============================================================================\n\n")

            if self.guard:
                out.write("`default_nettype wire\n\n")

            for fpath in self.ordered_files:
                if not os.path.isfile(fpath):
                    log_warn(f"Skipping missing file: {fpath}")
                    continue

                valid_files_count += 1
                out.write(f"\n// >>>>>>>>>>>>>>> FILE: {fpath} <<<<<<<<<<<<<<<\n")

                try:
                    with open(fpath, "r", encoding="utf-8", errors="ignore") as src:
                        text = src.read()
                except Exception as e:
                    log_error(f"Cannot read {fpath}: {e}")
                    continue

                if self.neutralize:
                    def replace_inc(match):
                        nonlocal neutralized_count
                        inc_target = match.group(1).strip()
                        norm_target = os.path.normpath(inc_target)
                        if (
                            norm_target in self.embedded_registry
                            or os.path.basename(norm_target) in self.embedded_registry
                        ):
                            neutralized_count += 1
                            return f"// [Merged] `include \"{inc_target}\""
                        return match.group(0)

                    text = re.sub(r"^\s*`include\s+[\"<]([^\">]+)[\">]", replace_inc, text, flags=re.M)

                out.write(text)
                if text and not text.endswith("\n"):
                    out.write("\n")

                if self.guard:
                    out.write("\n`default_nettype wire\n")

                total_lines += text.count("\n") + 1

        file_size_mb = os.path.getsize(self.output_path) / (1024 * 1024)
        log_info(
            f"Successfully merged {valid_files_count} files ({total_lines:,} lines, "
            f"{file_size_mb:.2f} MB) into '{self.output_path}'",
            self.verbose,
        )
        if self.neutralize:
            log_info(
                f"Neutralized {neutralized_count} redundant `include statements (zero filesystem dependencies)",
                self.verbose,
            )
