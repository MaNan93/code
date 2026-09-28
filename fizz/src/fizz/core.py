"""fizz core -- non-UI logic for parsing, merging, protecting, obfuscating
and packaging SV sources, plus post-sim log analysis.

Kept free of any GUI toolkit import so it can be driven by the Qt frontend,
a future CLI, or tests alike. Long-running pieces (obfuscate/vcs/rlskit) take
an `on_line(text)` callback instead of writing to a widget directly -- the
caller decides whether that callback marshals back to a UI thread.
"""

import configparser
import datetime
import fnmatch
import ftplib
import glob
import hashlib
import os
import re
import shutil
import subprocess
from urllib.parse import urlparse

DEFAULT_OBF_TOOL = "verible-verilog-obfuscate"
DEFAULT_VCS_OPTIONS = "-ipopt=partialprotect -ipopt=overwrite"
DEFAULT_FTP_URL = "ftp://share.srv/"
DEFAULT_TOP_FILE = "pcie_ctrl_wrapper.sv"
DEFAULT_VERSION = "V1P0"
# One whitelist shared by every project/source file -- alongside ~/.fizz.ini
# itself, not per-project -- so tokens like a standard clock/reset name only
# need to be listed once, ever.
DEFAULT_WHITELIST_FILE = os.path.join(os.path.expanduser("~"), ".fizz_whitelist.map")


# ---------------------------------------------------------------------------
# ~/.fizz.ini configuration
# ---------------------------------------------------------------------------

class FizzConfig:
    """Reads/writes ~/.fizz.ini: Preference, RLskitDefault, History and the
    per-directory RLskitHistoryTable."""

    def __init__(self, path=None):
        self.path = path or os.path.join(os.path.expanduser("~"), ".fizz.ini")

    def ensure_exists(self):
        if not os.path.isfile(self.path):
            self.create_default()

    def create_default(self):
        cfg = configparser.ConfigParser()
        cfg["Preference"] = {
            "exclude_dirs": "",
            "exclude_files": "",
            "vcs_key_file": "",
            "vcs_options": DEFAULT_VCS_OPTIONS,
            "obfuscator_path": DEFAULT_OBF_TOOL,
            "whitelist_file": DEFAULT_WHITELIST_FILE,
        }
        cfg["RLskitDefault"] = {
            "ftp_url": DEFAULT_FTP_URL,
            "ftp_username": "",
            "ftp_password": "",
        }
        cfg["History"] = {
            "last_version": DEFAULT_VERSION,
            "last_timestamp": "",
        }
        with open(self.path, "w", encoding="utf-8") as f:
            cfg.write(f)

    def load(self):
        """Return a flat dict of preference/rlskit-default/history values."""
        self.ensure_exists()
        cfg = configparser.ConfigParser()
        cfg.read(self.path, encoding="utf-8")
        data = {
            "exclude_dirs": "",
            "exclude_files": "",
            "vcs_key_file": "",
            "vcs_options": DEFAULT_VCS_OPTIONS,
            "obfuscator_path": DEFAULT_OBF_TOOL,
            "whitelist_file": DEFAULT_WHITELIST_FILE,
            "ftp_url": "",
            "ftp_username": "",
            "ftp_password": "",
            "last_version": "",
        }
        if cfg.has_section("Preference"):
            sec = cfg["Preference"]
            data["exclude_dirs"] = sec.get("exclude_dirs", "")
            data["exclude_files"] = sec.get("exclude_files", "")
            data["vcs_key_file"] = sec.get("vcs_key_file", "")
            data["vcs_options"] = sec.get("vcs_options", DEFAULT_VCS_OPTIONS)
            data["obfuscator_path"] = sec.get("obfuscator_path", DEFAULT_OBF_TOOL)
            data["whitelist_file"] = sec.get("whitelist_file", "").strip() or DEFAULT_WHITELIST_FILE
        if cfg.has_section("RLskitDefault"):
            sec = cfg["RLskitDefault"]
            data["ftp_url"] = sec.get("ftp_url", "")
            data["ftp_username"] = sec.get("ftp_username", "")
            data["ftp_password"] = sec.get("ftp_password", "")
        if cfg.has_section("History"):
            data["last_version"] = cfg.get("History", "last_version", fallback="")
        return data

    def save(self, values):
        """values must provide: exclude_dirs, exclude_files, vcs_key_file,
        vcs_options, obfuscator_path, whitelist_file, ftp_url, ftp_username,
        ftp_password, last_version."""
        cfg = configparser.ConfigParser()
        if os.path.isfile(self.path):
            cfg.read(self.path, encoding="utf-8")

        if not cfg.has_section("Preference"):
            cfg.add_section("Preference")
        cfg.set("Preference", "exclude_dirs", values.get("exclude_dirs", "").strip())
        cfg.set("Preference", "exclude_files", values.get("exclude_files", "").strip())
        cfg.set("Preference", "vcs_key_file", values.get("vcs_key_file", "").strip())
        cfg.set("Preference", "vcs_options", values.get("vcs_options", "").strip())
        cfg.set("Preference", "obfuscator_path", values.get("obfuscator_path", "").strip() or DEFAULT_OBF_TOOL)
        cfg.set("Preference", "whitelist_file", values.get("whitelist_file", "").strip())

        if not cfg.has_section("RLskitDefault"):
            cfg.add_section("RLskitDefault")
        cfg.set("RLskitDefault", "ftp_url", values.get("ftp_url", "").strip())
        cfg.set("RLskitDefault", "ftp_username", values.get("ftp_username", "").strip())
        cfg.set("RLskitDefault", "ftp_password", values.get("ftp_password", ""))

        if not cfg.has_section("History"):
            cfg.add_section("History")
        cfg.set("History", "last_version", values.get("last_version", "").strip())
        cfg.set("History", "last_timestamp", datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))

        with open(self.path, "w", encoding="utf-8") as f:
            cfg.write(f)

    @staticmethod
    def canonical_path(path):
        return os.path.normcase(os.path.normpath(os.path.abspath(path)))

    @classmethod
    def history_row_prefix(cls, src_path):
        abs_path = cls.canonical_path(src_path)
        key = hashlib.sha1(abs_path.encode("utf-8", errors="replace")).hexdigest()
        return f"row.{key}"

    def load_rlskit_for_dir(self, src_path):
        """Return dict(ftp_url, ftp_username, ftp_password, last_version) for
        this directory's history row, falling back to RLskitDefault, or None
        if there is no matching history row."""
        self.ensure_exists()
        cfg = configparser.ConfigParser()
        cfg.read(self.path, encoding="utf-8")

        result = {}
        if cfg.has_section("RLskitDefault"):
            sec = cfg["RLskitDefault"]
            result["ftp_url"] = sec.get("ftp_url", "")
            result["ftp_username"] = sec.get("ftp_username", "")
            result["ftp_password"] = sec.get("ftp_password", "")

        if cfg.has_section("RLskitHistoryTable"):
            prefix = self.history_row_prefix(src_path)
            row_path = cfg.get("RLskitHistoryTable", f"{prefix}.path", fallback="")
            if row_path and self.canonical_path(row_path) == self.canonical_path(src_path):
                result["ftp_url"] = cfg.get("RLskitHistoryTable", f"{prefix}.ftp_url", fallback=result.get("ftp_url", ""))
                result["ftp_username"] = cfg.get("RLskitHistoryTable", f"{prefix}.ftp_username", fallback=result.get("ftp_username", ""))
                result["ftp_password"] = cfg.get("RLskitHistoryTable", f"{prefix}.ftp_password", fallback=result.get("ftp_password", ""))
                last_ver = cfg.get("RLskitHistoryTable", f"{prefix}.last_version", fallback="")
                if last_ver:
                    result["last_version"] = last_ver
                return result
        return result or None

    def save_rlskit_upload_history(self, src_path, upload_file, ftp_target, version):
        if not src_path:
            return
        cfg = configparser.ConfigParser()
        if os.path.isfile(self.path):
            cfg.read(self.path, encoding="utf-8")
        if not cfg.has_section("RLskitHistoryTable"):
            cfg.add_section("RLskitHistoryTable")

        prefix = self.history_row_prefix(src_path)
        sec = "RLskitHistoryTable"
        cfg.set(sec, f"{prefix}.path", src_path)
        cfg.set(sec, f"{prefix}.last_version", version)
        cfg.set(sec, f"{prefix}.last_ftp_path", ftp_target)
        cfg.set(sec, f"{prefix}.last_upload_time", datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        cfg.set(sec, f"{prefix}.last_upload_file", upload_file)

        with open(self.path, "w", encoding="utf-8") as f:
            cfg.write(f)

    def rlskit_history_rows(self):
        self.ensure_exists()
        cfg = configparser.ConfigParser()
        cfg.read(self.path, encoding="utf-8")

        rows = []
        if cfg.has_section("RLskitHistoryTable"):
            sec = cfg["RLskitHistoryTable"]
            prefixes = set()
            for key in sec.keys():
                if key.startswith("row.") and "." in key[4:]:
                    prefixes.add(key.rsplit(".", 1)[0])
            for prefix in sorted(prefixes):
                path = sec.get(f"{prefix}.path", "")
                if not path:
                    continue
                rows.append({
                    "prefix": prefix,
                    "path": path,
                    "version": sec.get(f"{prefix}.last_version", ""),
                    "ftp_path": sec.get(f"{prefix}.last_ftp_path", ""),
                    "upload_time": sec.get(f"{prefix}.last_upload_time", ""),
                    "upload_file": sec.get(f"{prefix}.last_upload_file", ""),
                })
        rows.sort(key=lambda r: r.get("upload_time", ""), reverse=True)
        return rows

    def delete_rlskit_history_rows(self, prefixes):
        if not prefixes:
            return
        self.ensure_exists()
        cfg = configparser.ConfigParser()
        cfg.read(self.path, encoding="utf-8")
        if not cfg.has_section("RLskitHistoryTable"):
            return

        all_keys = list(cfg["RLskitHistoryTable"].keys())
        for prefix in prefixes:
            for key in all_keys:
                if key.startswith(f"{prefix}."):
                    cfg.remove_option("RLskitHistoryTable", key)

        if cfg.has_section("RLskitHistoryTable") and not cfg.items("RLskitHistoryTable"):
            cfg.remove_section("RLskitHistoryTable")

        with open(self.path, "w", encoding="utf-8") as f:
            cfg.write(f)


# ---------------------------------------------------------------------------
# generalMessage.txt parsing + filtering
# ---------------------------------------------------------------------------

def read_text_with_fallback(path, encodings=("utf-8", "gbk")):
    last_err = None
    for enc in encodings:
        try:
            with open(path, "r", encoding=enc) as f:
                return f.read()
        except (UnicodeDecodeError, UnicodeError) as e:
            last_err = e
            continue
    raise last_err


def parse_general_message(msg_path):
    """Return (included_files, source_files), each de-duplicated in order."""
    content = read_text_with_fallback(msg_path)

    inc, src = [], []
    for line in content.splitlines():
        lower = line.lower()
        if "included file" in lower:
            m = re.search(r'"([^"]*)"', line)
            if m:
                inc.append(m.group(1))
        elif "source file" in lower:
            m = re.search(r'"([^"]*)"', line)
            if m:
                src.append(m.group(1))

    return list(dict.fromkeys(inc)), list(dict.fromkeys(src))


def split_patterns(text):
    return [p.strip() for p in re.split(r'[,;，；]+', text) if p.strip()]


def match_filter(path, dir_patterns, file_patterns):
    """True = keep, False = excluded by a dir/file pattern."""
    basename = os.path.basename(path)
    dirname = os.path.dirname(path)

    for pat in file_patterns:
        if fnmatch.fnmatch(basename, pat):
            return False

    for pat in dir_patterns:
        if fnmatch.fnmatch(dirname, pat) or fnmatch.fnmatch(dirname, f"*{os.sep}{pat}*"):
            return False
        parts = dirname.replace("\\", "/").split("/")
        if any(fnmatch.fnmatch(p, pat) for p in parts if p):
            return False

    return True


def filter_files(paths, dir_filter_text, file_filter_text):
    dir_patterns = split_patterns(dir_filter_text)
    file_patterns = split_patterns(file_filter_text)
    if not dir_patterns and not file_patterns:
        return list(paths)
    return [p for p in paths if match_filter(p, dir_patterns, file_patterns)]


def resolve_path(rel_path, base_dir, script_dir):
    """Resolve an absolute/relative/bare-filename path against base_dir,
    then script_dir, then a shallow (depth<=3) walk under base_dir."""
    rel_path = os.path.expanduser(rel_path)
    if os.path.isabs(rel_path):
        return rel_path if os.path.isfile(rel_path) else None

    cand = os.path.normpath(os.path.join(base_dir, rel_path))
    if os.path.isfile(cand):
        return cand

    cand = os.path.normpath(os.path.join(script_dir, rel_path))
    if os.path.isfile(cand):
        return cand

    fname = os.path.basename(rel_path)
    for root, dirs, files in os.walk(base_dir):
        if fname in files:
            return os.path.join(root, fname)
        if root.count(os.sep) - base_dir.count(os.sep) > 3:
            dirs.clear()

    return None


def insert_protect_pragmas(data):
    """Insert `pragma protect end before the module line and `pragma protect
    begin after the first ); that follows it."""
    lines = data.splitlines(keepends=True)

    module_idx = None
    for i, line in enumerate(lines):
        if re.search(r'\bmodule\b', line):
            module_idx = i
            break

    paren_idx = None
    if module_idx is not None:
        for i in range(module_idx, len(lines)):
            if ');' in lines[i]:
                paren_idx = i
                break

    result = []
    for i, line in enumerate(lines):
        if i == module_idx:
            result.append("`pragma protect end\n")
        result.append(line)
        if i == paren_idx:
            result.append("`pragma protect begin\n")

    return "".join(result)


class MergeResult:
    def __init__(self):
        self.missing = []
        self.merged_lines = 0
        self.written_count = 0


def merge_files(all_files, out_path, msg_dir, script_dir, protect, top_name,
                 strip_comments, on_progress=None):
    """Merge `all_files` (paths as they appeared in generalMessage.txt) into
    out_path. on_progress(index, total) is called after each file, whether
    or not it was found. Returns a MergeResult."""
    result = MergeResult()
    total = len(all_files)

    os.makedirs(os.path.dirname(os.path.abspath(out_path)) or ".", exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as out:
        if protect:
            out.write("`pragma protect begin\n\n")

        for idx, rel_path in enumerate(all_files):
            abs_path = resolve_path(rel_path, msg_dir, script_dir)
            if not abs_path or not os.path.isfile(abs_path):
                result.missing.append(rel_path)
                if on_progress:
                    on_progress(idx + 1, total)
                continue

            try:
                data = read_text_with_fallback(abs_path)
            except Exception as e:
                result.missing.append(f"{rel_path} (编码错误: {e})")
                if on_progress:
                    on_progress(idx + 1, total)
                continue

            lines = data.splitlines(keepends=True)
            filtered = []
            for line in lines:
                if line.lstrip().startswith("`include"):
                    filtered.append("// " + line)
                else:
                    filtered.append(line)
            data = "".join(filtered)

            if strip_comments:
                proc = subprocess.run(
                    ["verible-verilog-preprocessor", "strip-comments", "-"],
                    input=data, capture_output=True, text=True,
                )
                if proc.returncode != 0:
                    result.missing.append(f"{rel_path} (verible错误: {proc.stderr.strip()})")
                    if on_progress:
                        on_progress(idx + 1, total)
                    continue
                data = proc.stdout

            is_top = protect and top_name and os.path.basename(rel_path) == top_name
            if is_top:
                data = insert_protect_pragmas(data)

            if result.written_count > 0:
                out.write("\n// ==============================================\n\n")
            out.write(data)
            if data and not data.endswith("\n"):
                out.write("\n")
            result.merged_lines += data.count("\n") + (0 if data.endswith("\n") else 1)
            result.written_count += 1

            if on_progress:
                on_progress(idx + 1, total)

        if protect:
            out.write("\n`pragma protect end\n")

    # Strip lines that are only leading whitespace + a trailing backslash.
    try:
        with open(out_path, "r", encoding="utf-8") as f:
            pp_lines = f.readlines()
        pp_lines = [re.sub(r'^\s+\\', '', line) for line in pp_lines]
        with open(out_path, "w", encoding="utf-8") as f:
            f.writelines(pp_lines)
    except OSError:
        pass

    return result


# ---------------------------------------------------------------------------
# Obfuscator: token whitelist
#
# verible-verilog-obfuscate's own --load_map/--save_map file is a plain
# translation map: one entry per line, each line a space-separated
# "<original> <obfuscated>" pair (verible/common/strings/obfuscator.h). An
# explicit map entry wins over --preserve_* options, and a *identity* entry
# (original == obfuscated) is exactly how --preserve_interface/
# --preserve_builtin_functions protect a name internally -- so a whitelist
# of arbitrary tokens is just an identity-mapped file in that same format,
# handed to the first obfuscation run as --load_map. Because --save_map
# writes out every entry it loaded plus every new one it generated, the
# whitelist's identity entries flow forward automatically once that run's
# --save_map output becomes the --load_map for the next run -- no need to
# re-load the original whitelist file after the first run.
# ---------------------------------------------------------------------------

def read_whitelist_tokens(path):
    """Read a whitelist file (verible map format) and return its preserved
    identifiers -- the first column of each line, de-duplicated in order.
    Missing file -> []. Blank lines and '#' comments are tolerated on read
    (write_whitelist_tokens never emits them, but a hand-edited file may)."""
    if not path or not os.path.isfile(path):
        return []
    tokens = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if parts:
                tokens.append(parts[0])
    return list(dict.fromkeys(tokens))


def write_whitelist_tokens(path, tokens):
    """Write `tokens` as a verible obfuscator map file with an identity
    mapping (original == obfuscated) for each one, so the file can be
    passed directly as --load_map to seed those tokens as untouched."""
    os.makedirs(os.path.dirname(os.path.abspath(path)) or ".", exist_ok=True)
    seen = dict.fromkeys(t.strip() for t in tokens if t.strip())
    with open(path, "w", encoding="utf-8") as f:
        for token in seen:
            f.write(f"{token} {token}\n")


# ---------------------------------------------------------------------------
# Obfuscator / VCS Protect (streamed subprocess helpers)
# ---------------------------------------------------------------------------

def run_obfuscate(src_path, out_path, save_map, load_map, tool_bin, on_line):
    """Pipe src_path through `tool_bin` into out_path, streaming stderr lines
    to on_line(text). Returns the process return code, or raises
    FileNotFoundError if tool_bin cannot be run.

    Runs with the tool's own defaults for --preserve_interface (false) and
    --preserve_builtin_functions (true) -- fizz doesn't override either;
    protecting specific tokens is the token whitelist's job (see
    docs/obfuscate_workflow.md)."""
    cmd_args = [tool_bin]
    if save_map:
        cmd_args += ["--save_map", save_map]
    if load_map:
        cmd_args += ["--load_map", load_map]

    os.makedirs(os.path.dirname(os.path.abspath(out_path)) or ".", exist_ok=True)
    with open(src_path, "rb") as fin, open(out_path, "wb") as fout:
        proc = subprocess.Popen(
            cmd_args, stdin=fin, stdout=fout, stderr=subprocess.PIPE,
            cwd=os.path.dirname(src_path) or ".",
        )
        if proc.stderr is not None:
            for line in proc.stderr:
                on_line(line.decode(errors="replace"))
        proc.wait()
    return proc.returncode


def run_vcs_protect(src_path, key_path, opts, on_line):
    """Run `vcs -ipprotect key_path <opts> src_path`, streaming combined
    stdout+stderr to on_line(text) line by line. Returns the return code."""
    cmd = ["vcs", "-ipprotect", key_path] + opts.split() + [src_path]
    proc = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
        cwd=os.path.dirname(src_path) or ".",
    )
    if proc.stdout is not None:
        for line in proc.stdout:
            on_line(line)
    proc.wait()
    return proc.returncode


# ---------------------------------------------------------------------------
# RLskit: package, checksum, optional FTP upload
# ---------------------------------------------------------------------------

def full_suffix(version):
    """'V1P0' -> '_V1P0_R20260924' (today's date)."""
    version = (version or "").strip()
    if not version:
        return ""
    date_str = datetime.date.today().strftime("%Y%m%d")
    return f"_{version}_R{date_str}"


class RLskitResult:
    def __init__(self):
        self.dst_dir = ""
        self.tar_file = ""
        self.cksum = ""
        self.upload_ok = False
        self.target_url = ""


def run_rlskit_package(src_dir, suffix, ftp_url, ftp_user, ftp_pass, on_line):
    """Copy src_dir -> src_dir+suffix, tar.gz it, cksum it, and optionally
    curl-upload it over FTP/HTTP if ftp_url+ftp_user are set and the remote
    file doesn't already exist. Returns an RLskitResult."""
    result = RLskitResult()
    parent = os.path.dirname(src_dir)
    src_name = os.path.basename(src_dir)
    dst_dir = os.path.join(parent, src_name + suffix)
    tar_file = dst_dir + ".tar.gz"
    result.dst_dir = dst_dir
    result.tar_file = tar_file

    on_line(f"> 复制目录: {src_dir}\n   -> {dst_dir}\n")
    if os.path.exists(dst_dir):
        on_line("  [清理] 已存在的目标目录\n")
        shutil.rmtree(dst_dir)
    shutil.copytree(src_dir, dst_dir)
    on_line("  复制完成\n\n")

    on_line(f"> 压缩: {os.path.basename(dst_dir)} -> {os.path.basename(tar_file)}\n")
    proc = subprocess.Popen(
        ["tar", "-czf", tar_file, "-C", parent, os.path.basename(dst_dir)],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
    )
    if proc.stdout is not None:
        for line in proc.stdout:
            on_line(line)
    proc.wait()
    if proc.returncode != 0:
        on_line(f"\n[错误] tar 退出码: {proc.returncode}\n")
        return result
    file_size = os.path.getsize(tar_file)
    on_line(f"  压缩完成: {file_size:,} bytes\n\n")

    on_line(f"> 计算 cksum: {os.path.basename(tar_file)}\n")
    proc = subprocess.Popen(
        ["cksum", tar_file], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
    )
    out, _ = proc.communicate()
    result.cksum = (out or "").strip()
    on_line(f"  {result.cksum}\n\n")

    if ftp_url and ftp_user:
        target_url = ftp_url.rstrip("/") + "/" + os.path.basename(tar_file)
        result.target_url = target_url
        on_line(f"> 检查远端文件: {os.path.basename(tar_file)}\n")

        chk = subprocess.run(
            ["curl", "-sI", "--fail", target_url, "-u", f"{ftp_user}:{ftp_pass}"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        if chk.returncode == 0:
            on_line(f"=== 未上传: 远端文件已存在 ===\n   {target_url}\n本地文件: {tar_file}\n\n")
        else:
            on_line("  远端文件不存在，开始上传。\n")
            on_line(f"> FTP 上传: {os.path.basename(tar_file)}\n   -> {target_url}\n")

            proc = subprocess.Popen(
                ["curl", "-sS", "-T", tar_file, "-u", f"{ftp_user}:{ftp_pass}", target_url],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            )
            if proc.stderr is not None:
                for line in proc.stderr:
                    decoded = line.decode(errors="replace").rstrip("\r\n")
                    if decoded:
                        on_line(f"  {decoded}\n")
            proc.wait()
            on_line(f"\n--- curl 退出码: {proc.returncode} ---\n")
            if proc.returncode == 0:
                result.upload_ok = True
    else:
        on_line("=== 未上传: 未填写 FTP URL/用户 ===\n\n")

    on_line(f"\n=== 完成 ===\n最终文件: {tar_file}\n")
    return result


def release_note_path(rlskit_src_dir):
    if rlskit_src_dir and os.path.isdir(rlskit_src_dir):
        return os.path.join(rlskit_src_dir, "Release_Note.txt")
    return ""


def load_release_note(path):
    if path and os.path.isfile(path):
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    return None


def save_release_note(path, content):
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


# ---------------------------------------------------------------------------
# FTP directory browsing
# ---------------------------------------------------------------------------

def parse_ftp_target(url):
    parsed = urlparse(url if url else DEFAULT_FTP_URL)
    host = parsed.hostname or "share.srv"
    path = parsed.path or "/"
    return host, path


def connect_ftp(host, user, passwd, timeout=10):
    ftp = ftplib.FTP()
    ftp.connect(host, timeout=timeout)
    ftp.login(user or "anonymous", passwd or "")
    return ftp


def list_ftp_dir(ftp, path):
    """cwd into path and return (pwd, sorted subdirectory names)."""
    ftp.cwd(path)
    pwd = ftp.pwd()
    entries = []

    def _parse_line(line):
        parts = line.split(None, 8)
        if line.startswith("d") and len(parts) >= 9:
            name = parts[8]
            if name not in (".", ".."):
                entries.append(name)

    ftp.retrlines("LIST", _parse_line)
    entries.sort()
    return pwd, entries


# ---------------------------------------------------------------------------
# Post-sim log analysis
# ---------------------------------------------------------------------------

def search_postsim_files(dir_path, pattern):
    search_path = os.path.join(dir_path, "**", pattern)
    return sorted(f for f in glob.iglob(search_path, recursive=True) if os.path.isfile(f))


class EmptyFileError(Exception):
    pass


class UnknownEncodingError(Exception):
    pass


def analyze_timing_violations(file_path):
    """Return a list of dict(instance, info, path, line_number) for each
    "Timing violation" line found in file_path."""
    if not os.path.isfile(file_path) or os.path.getsize(file_path) == 0:
        raise EmptyFileError(file_path)

    lines = None
    for enc in ("utf-8", "gbk", "latin-1"):
        try:
            with open(file_path, "r", encoding=enc) as f:
                lines = f.readlines()
            break
        except (UnicodeDecodeError, UnicodeError):
            continue
    if lines is None:
        raise UnknownEncodingError(file_path)

    results = []
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if "Timing violation" in line:
            path_m = re.search(r'["\']([^"\']+)["\']', line)
            path_val = path_m.group(1) if path_m else "未提取到"
            line_m = re.search(r'(\d+):', line)
            line_num = line_m.group(1) if line_m else ""
            inst_m = re.search(r'Timing violation in\s+(\w+(\.\w+)+)\b', line, re.IGNORECASE)
            inst = inst_m.group(1) if inst_m else "未提取到"
            info = lines[i + 1].strip() if i + 1 < len(lines) else "无后续内容"
            results.append({
                "instance": inst, "info": info,
                "path": path_val, "line_number": line_num,
            })
            i += 1
        i += 1

    return results


def write_waive_instances(instances, lst_path="notimingcheck.lst"):
    with open(lst_path, "a", encoding="utf-8") as f:
        for inst in instances:
            f.write(f"instance {{{inst}}} {{noTiming}}\n")
