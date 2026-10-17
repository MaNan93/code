#!/usr/bin/env python3

"""runall.py
在 xfce4-terminal 新窗口中，为每个含 Makefile 的子目录打开一个 tab 并执行 make。

用法:
  python runall.py              -> make vcs
  python runall.py clean        -> make clean
  python runall.py vcs xrun     -> make vcs && make xrun
"""

import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import List


def collect_make_dirs(base: Path) -> List[Path]:
    dirs = []  # type: List[Path]
    for p in sorted(base.iterdir(), key=lambda x: x.name):
        if not p.is_dir():
            continue
        if (p / "Makefile").is_file() or (p / "makefile").is_file():
            dirs.append(p)
    return dirs


def build_make_command(targets: List[str]) -> str:
    if not targets:
        return "make vcs"
    return " && ".join(f"make {t}" for t in targets)


def create_tab_script(tmpdir: Path, tab_name: str, workdir: Path, make_cmd: str) -> Path:
    script = tmpdir / f"{tab_name}.sh"
    content = (
        "#!/bin/bash\n"
        f'cd "{workdir}"\n'
        f"{make_cmd}\n"
        "exec bash\n"
    )
    script.write_text(content, encoding="utf-8")
    script.chmod(script.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    return script


def main() -> int:
    if shutil.which("xfce4-terminal") is None:
        print("错误: 未找到 xfce4-terminal，请先安装。", file=sys.stderr)
        return 1

    base = Path.cwd()
    targets = sys.argv[1:]
    dirs = collect_make_dirs(base)

    if not dirs:
        print("未找到包含 Makefile 的子目录")
        return 1

    print(f"找到 {len(dirs)} 个目录")

    make_cmd = build_make_command(targets)
    tmpdir = Path(tempfile.mkdtemp(prefix="runall_"))

    args = ["xfce4-terminal", "--disable-server"]  # type: List[str]
    for d in dirs:
        tab_name = d.name.rstrip("/")
        script = create_tab_script(tmpdir, tab_name, d.resolve(), make_cmd)
        args.extend(["--tab", f"--title={tab_name}", f"--command={script}"])

    try:
        # 启动后保持临时脚本目录存在，供各 tab 执行。
        subprocess.Popen(args)
    except OSError as exc:
        print(f"启动 xfce4-terminal 失败: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
