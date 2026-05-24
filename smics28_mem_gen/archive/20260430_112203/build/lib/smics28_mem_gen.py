#!/usr/bin/env python3
"""Run MEM_COMPILER tasks for all .spec files in current directory tree root.

Behavior summary:
- Find all *.spec in script directory (non-recursive)
- Create same-name subdir for each spec, copy spec into it
- Run two commands in each subdir:
    1) MEM_COMPILER all -spec <spec>
    2) MEM_COMPILER liberty -spec <spec>
- Store outputs in <subdir>/job.log and <subdir>/run_all.log, <subdir>/run_corner.log
- Run tasks concurrently
"""

import argparse
import shutil
import subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Dict, List, Tuple


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Parallel MEM_COMPILER runner for .spec files",
        usage="%(prog)s --mem-compiler MEM_COMPILER [--max-job MAX_JOB] [--out-dir OUT_DIR]",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Behavior summary:\n"
            "- Find all *.spec in script directory (non-recursive)\n"
            "- Create same-name subdir for each spec, copy spec into it\n"
            "- Run two commands in each subdir:\n"
            "    1) MEM_COMPILER all -spec <spec>\n"
            "    2) MEM_COMPILER liberty -spec <spec>\n"
            "- Store outputs in <subdir>/job.log and <subdir>/run_all.log, <subdir>/run_corner.log\n"
            "- Run tasks concurrently"
        ),
    )
    parser.add_argument(
        "--mem-compiler",
        required=True,
        help="Memory compiler executable or full path (required)",
    )
    parser.add_argument(
        "--max-job",
        type=int,
        default=4,
        help="Maximum concurrent subdirectory tasks (default: 4)",
    )
    parser.add_argument(
        "--out-dir",
        default=None,
        help="Output root directory for generated subdirs and logs (default: current working directory)",
    )
    return parser.parse_args()


def run_cmd(cmd: List[str], cwd: Path, step_log: Path, job_log: Path) -> int:
    try:
        proc = subprocess.Popen(
            cmd,
            cwd=str(cwd),
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            universal_newlines=True,
        )
    except OSError as exc:
        err_msg = "[error] 无法启动命令: {}\n".format(exc)
        step_log.write_text(err_msg, encoding="utf-8")
        with job_log.open("a", encoding="utf-8") as f:
            f.write("$ {}\n".format(" ".join(cmd)))
            f.write(err_msg)
            f.write("[returncode] 127\n\n")
        return 127

    with step_log.open("w", encoding="utf-8") as sf, \
         job_log.open("a", encoding="utf-8") as jf:
        jf.write("$ {}\n".format(" ".join(cmd)))
        for line in proc.stdout:
            sf.write(line)
            jf.write(line)
        proc.wait()
        jf.write("[returncode] {}\n\n".format(proc.returncode))

    return proc.returncode


def run_task(subdir: Path, spec_name: str, mem_compiler: str) -> Tuple[int, int]:
    name = subdir.name
    job_log = subdir / "job.log"
    step1_log = subdir / "run_all.log"
    step2_log = subdir / "run_corner.log"
    job_log.write_text("", encoding="utf-8")

    print(f"[{name}] cd {subdir}")

    cmd1 = [mem_compiler, "all", "-spec", spec_name]
    print(f"[{name}] 执行: {' '.join(cmd1)}")
    rc1 = run_cmd(cmd1, subdir, step1_log, job_log)
    if rc1 == 0:
        print(f"[{name}] MEM_COMPILER all -> OK")
    else:
        print(f"[{name}] MEM_COMPILER all -> FAILED(rc={rc1})")

    cmd2 = [mem_compiler, "liberty", "-spec", spec_name]
    print(f"[{name}] 执行: {' '.join(cmd2)}")
    rc2 = run_cmd(cmd2, subdir, step2_log, job_log)
    if rc2 == 0:
        print(f"[{name}] MEM_COMPILER liberty -> OK")
    else:
        print(f"[{name}] MEM_COMPILER liberty -> FAILED(rc={rc2})")

    return rc1, rc2


def main() -> int:
    args = parse_args()

    if args.max_job <= 0:
        print("max-job 必须大于 0")
        return 2

    cwd = Path.cwd()
    out_dir = Path(args.out_dir).resolve() if args.out_dir else cwd
    out_dir.mkdir(parents=True, exist_ok=True)

    mem_compiler = args.mem_compiler
    if not (Path(mem_compiler).is_file() or shutil.which(mem_compiler)):
        print("错误: 找不到 mem-compiler 可执行文件: {}".format(mem_compiler))
        return 1

    print(f"工作目录: {cwd}")
    print(f"最大并发数: {args.max_job}")
    print(f"输出目录: {out_dir}")

    spec_files = sorted(f for f in cwd.iterdir() if f.is_file() and f.suffix == ".spec")
    if not spec_files:
        print("当前目录下未找到任何 *.spec 文件，退出。")
        return 0

    print()
    print(f"找到 {len(spec_files)} 个 spec 文件:")
    for spec in spec_files:
        print(f"  {spec.name}")

    tasks = []  # type: List[Tuple[Path, str]]
    for spec_path in spec_files:
        spec_name = spec_path.name
        dir_name = spec_path.stem
        subdir = out_dir / dir_name

        subdir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(spec_path, subdir / spec_name)

        print()
        print(f"[准备] 目录: {subdir}")
        print(f"[准备] 复制: {spec_name} -> {subdir}")

        tasks.append((subdir, spec_name))

    print()
    print("开始并发执行...")

    results = {}  # type: Dict[Path, Tuple[int, int]]
    with ThreadPoolExecutor(max_workers=args.max_job) as executor:
        future_to_subdir = {
            executor.submit(run_task, subdir, spec_name, mem_compiler): subdir
            for subdir, spec_name in tasks
        }
        for future in as_completed(future_to_subdir):
            subdir = future_to_subdir[future]
            try:
                rc1, rc2 = future.result()
            except Exception as exc:
                print("[{}] 任务异常: {}".format(subdir.name, exc))
                rc1, rc2 = 1, 1
            results[subdir] = (rc1, rc2)

    ok_count = sum(1 for rc1, rc2 in results.values() if rc1 == 0 and rc2 == 0)
    fail_count = len(tasks) - ok_count

    print()
    print("========================================")
    print("执行汇总（详细日志在每个子目录的 job.log / run_all.log / run_corner.log）")
    print("========================================")
    print("总计: {} 个任务，成功 {}，失败 {}".format(len(tasks), ok_count, fail_count))

    for subdir, _ in tasks:
        rc1, rc2 = results.get(subdir, (1, 1))
        all_status = "OK" if rc1 == 0 else "FAILED(rc={})".format(rc1)
        corner_status = "OK" if rc2 == 0 else "FAILED(rc={})".format(rc2)

        print()
        print(f"目录: {subdir}")
        print(f"  MEM_COMPILER all     : {all_status}")
        print(f"  MEM_COMPILER liberty : {corner_status}")

    print()
    if fail_count == 0:
        print("全部完成。")
    else:
        print("完成，但有 {} 个任务失败，请检查各子目录日志。".format(fail_count))
    return 0 if fail_count == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
