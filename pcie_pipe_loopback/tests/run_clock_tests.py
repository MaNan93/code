"""Build the clock-switch regression with an explicit Verilator/GCC toolchain."""
import argparse
import os
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verilator', required=True)
    parser.add_argument('--verilator-root', required=True)
    parser.add_argument('--cxx', required=True)
    parser.add_argument('--make', required=True)
    args = parser.parse_args()
    base = Path(__file__).resolve().parents[1]
    dest = base / 'build' / 'clock_tests'
    dest.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env['VERILATOR_ROOT'] = Path(args.verilator_root).as_posix()
    env['PATH'] = str(Path(args.cxx).parent) + os.pathsep + env['PATH']
    commands = [
        [args.verilator, '--cc', '--exe', '--top-module', 'pcie_pipe_pclk_switch',
         '--prefix', 'Vclock', '--Mdir', dest.as_posix(), '-Wall', '-Wno-fatal',
         '-CFLAGS', '-std=c++17', '-LDFLAGS', '-static',
         (base / 'pcie_pipe_clock_gate.sv').as_posix(),
         (base / 'pcie_pipe_pclk_switch.sv').as_posix(),
         (base / 'tests' / 'test_clock_switch.cpp').as_posix()],
        [args.make, '-C', dest.as_posix(), '-f', 'Vclock.mk', '-j2',
         'CXX=' + Path(args.cxx).as_posix(), 'LINK=' + Path(args.cxx).as_posix(),
         'AR=' + (Path(args.cxx).parent / 'gcc-ar.exe').as_posix(),
         'PYTHON3=' + Path(sys.executable).as_posix(),
         'UNAME_S=Windows_NT', 'VM_PARALLEL_BUILDS=0'],
    ]
    log = dest / 'build.log'
    with log.open('w', encoding='utf-8') as output:
        for command in commands:
            result = subprocess.run(command, env=env, stdout=output, stderr=subprocess.STDOUT)
            if result.returncode:
                print(log.read_text(encoding='utf-8')[-6000:])
                raise SystemExit(result.returncode)
    subprocess.run([str(dest / 'Vclock.exe')], env=env, check=True)


if __name__ == '__main__':
    main()
