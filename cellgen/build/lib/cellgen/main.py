#!/usr/bin/env python3
"""
RAM Size Generator (ram_size_gen.py)
根据CSV配置自动生成满足深度和位宽需求的CELL配置

优化策略:
1. 优先选择拼接数量最少的方案
2. 在拼接数量相同的情况下，选择CELL最小的方案
"""

import csv
import argparse
import math
import re
from dataclasses import dataclass
from typing import List, Tuple, Optional


@dataclass
class RAMSpec:
    """单个RAM的规格"""
    no: int
    inst: str
    ram_type: str
    depth: int       # DP
    width: int       # WD
    cell_dp_raw: str  # 原始格式 "0:2:512"
    cell_wd_raw: str  # 原始格式 "0:2:128"
    cell_dp_start: int  # CELL_DP 起始值
    cell_dp_step: int   # CELL_DP 步长
    cell_dp_max: int     # CELL_DP 最大值
    cell_wd_start: int   # CELL_WD 起始值
    cell_wd_step: int    # CELL_WD 步长
    cell_wd_max: int     # CELL_WD 最大值
    row_idx: int


@dataclass
class CellConfig:
    """生成的CELL配置"""
    needed_dp: int
    needed_wd: int
    cell_dp: int
    cell_wd: int
    num_cells_depth: int   # 深度方向拼接数量
    num_cells_width: int    # 位宽方向拼接数量
    total_depth: int
    total_width: int
    is_valid: bool
    note: str


def is_power_of_2(n: int) -> bool:
    """判断是否为2的幂"""
    return n > 0 and (n & (n - 1)) == 0


def get_power_of_2_list(max_val: int) -> List[int]:
    """获取所有2的幂列表 (1, 2, 4, 8, ... <= max_val)"""
    result = []
    val = 1
    while val <= max_val:
        result.append(val)
        val *= 2
    return result


def parse_size_range(size_str: str) -> Tuple[int, int, int]:
    """解析 start:step:end 格式"""
    size_str = size_str.strip()
    parts = size_str.split(':')
    if len(parts) != 3:
        return (0, 1, 0)
    return int(parts[0]), int(parts[1]), int(parts[2])


def get_valid_size_list(start: int, step: int, end: int) -> List[int]:
    """获取范围内所有符合步长的值 (包含start本身)"""
    result = []
    val = start
    if val == 0:
        val = step  # 如果start=0，从step开始
    while val <= end:
        result.append(val)
        val += step
    return result


def find_best_config(needed_dp: int, needed_wd: int,
                     cell_dp_start: int, cell_dp_step: int, cell_dp_max: int,
                     cell_wd_start: int, cell_wd_step: int, cell_wd_max: int) -> CellConfig:
    """
    找最优CELL配置
    策略:
    1. CELL_DP/WD 必须在 [start:step:end] 范围内
    2. 优先选择CELL值最接近需求的
    3. 其次选择拼接数量最少的
    """
    # DP: 所有符合 [start:step:end] 的值
    dp_options = []
    for dp in get_valid_size_list(cell_dp_start, cell_dp_step, cell_dp_max):
        num_depth_slices = math.ceil(needed_dp / dp)
        total_dp = num_depth_slices * dp
        if total_dp >= needed_dp:
            dp_options.append((dp, num_depth_slices, total_dp))

    # WD: 符合(step, max)
    wd_options = []
    for wd in get_valid_size_list(cell_wd_start, cell_wd_step, cell_wd_max):
        num_width_slices = math.ceil(needed_wd / wd)
        total_wd = num_width_slices * wd
        if total_wd >= needed_wd:
            wd_options.append((wd, num_width_slices, total_wd))

    # 找最优DP选项
    # 规则: 优先选择拼接数量最少的，其次选CELL值最接近需求的
    best_dp = None
    best_dp_slices = float('inf')
    best_dp_diff = float('inf')

    for dp, num_slices, total in dp_options:
        diff = abs(dp - needed_dp)
        if num_slices < best_dp_slices:
            best_dp_slices = num_slices
            best_dp = dp
            best_dp_diff = diff
        elif num_slices == best_dp_slices and diff < best_dp_diff:
            best_dp = dp
            best_dp_diff = diff

    # 找最优WD选项 (同样策略: 优先拼接数最少，其次CELL更小)
    best_wd = None
    best_wd_slices = float('inf')

    for wd, num_slices, total in wd_options:
        if num_slices < best_wd_slices:
            best_wd_slices = num_slices
            best_wd = wd
        elif num_slices == best_wd_slices and wd < best_wd:
            best_wd = wd

    # 生成备注
    total_slices = best_dp_slices * best_wd_slices
    if best_dp_slices == 1 and best_wd_slices == 1:
        note = f"CELL={best_dp}x{best_wd}, no slice needed"
    elif best_dp_slices > 1 and best_wd_slices > 1:
        note = f"DP:{best_dp_slices}x, WD:{best_wd_slices}x (total {total_slices} cells)"
    elif best_dp_slices > 1:
        note = f"DP:{best_dp_slices}x slice (CELL={best_dp})"
    else:
        note = f"WD:{best_wd_slices}x slice (CELL={best_wd})"

    return CellConfig(
        needed_dp=needed_dp,
        needed_wd=needed_wd,
        cell_dp=best_dp or 0,
        cell_wd=best_wd or 0,
        num_cells_depth=best_dp_slices,
        num_cells_width=best_wd_slices,
        total_depth=best_dp_slices * (best_dp or 0),
        total_width=best_wd_slices * (best_wd or 0),
        is_valid=(best_dp is not None) and (best_wd is not None),
        note=note
    )


def read_csv_specs(csv_path: str) -> List[RAMSpec]:
    """读取CSV文件"""
    specs = []

    with open(csv_path, 'r', encoding='utf-8-sig') as f:
        lines = f.readlines()

    # 解析数据行
    for i, line in enumerate(lines):
        line = line.strip()
        if not line:
            continue
        if re.match(r'^NO\.\s', line):
            continue
        if re.match(r'^-+$', line):
            continue
        if re.match(r'^\d+\s', line):
            parts = line.split()
            if len(parts) < 9:
                continue

            try:
                no = int(parts[0])
                inst = parts[1]
                ram_type = parts[2]
                dp = int(parts[3])
                wd = int(parts[4])
                cell_dp_raw = parts[7]
                cell_wd_raw = parts[8]

                dp_start, dp_step, dp_max = parse_size_range(cell_dp_raw)
                wd_start, wd_step, wd_max = parse_size_range(cell_wd_raw)

                specs.append(RAMSpec(
                    no=no, inst=inst, ram_type=ram_type,
                    depth=dp, width=wd,
                    cell_dp_raw=cell_dp_raw,
                    cell_wd_raw=cell_wd_raw,
                    cell_dp_start=dp_start,
                    cell_dp_step=dp_step,
                    cell_dp_max=dp_max,
                    cell_wd_start=wd_start,
                    cell_wd_step=wd_step,
                    cell_wd_max=wd_max,
                    row_idx=i + 1
                ))
            except (ValueError, IndexError) as e:
                print(f"Warning: Row {i+1} parse error: {e}")

    return specs


def print_results(specs: List[RAMSpec], configs: List[CellConfig]):
    """打印结果"""
    print("\n" + "=" * 150)
    print("RAM CELL Configuration Generator (Optimized: Min Slices > Min Cell)")
    print("=" * 150)
    print(f"{'NO.':<4} {'INST':<5} {'TYPE':<12} {'DP':<6} {'WD':<5} {'CELL':<12} {'DP_Slice':<10} {'WD_Slice':<10} {'Total_Bits':<12} {'Redundant':<10} {'OK':<4} Note")
    print("-" * 160)

    for spec, cfg in zip(specs, configs):
        status = "OK" if cfg.is_valid else "NG"
        cell_str = f"{cfg.cell_dp}x{cfg.cell_wd}"
        total_bits = cfg.cell_dp * cfg.cell_wd * cfg.num_cells_depth * cfg.num_cells_width
        needed_bits = cfg.needed_dp * cfg.needed_wd
        redundant = total_bits - needed_bits
        print(f"{spec.no:<4} {spec.inst:<5} {spec.ram_type:<12} {cfg.needed_dp:<6} {cfg.needed_wd:<5} "
              f"{cell_str:<12} {cfg.num_cells_depth:<10} {cfg.num_cells_width:<10} "
              f"{total_bits:<12} {redundant:<10} {status:<4} {cfg.note}")

    print("-" * 150)

    # 统计
    total = len(configs)
    valid = sum(1 for c in configs if c.is_valid)
    total_cells = sum(c.num_cells_depth * c.num_cells_width for c in configs)

    print(f"\nSummary:")
    print(f"  Total RAMs: {total}")
    print(f"  Valid configs: {valid}/{total}")
    print(f"  Total CELLs needed: {total_cells}")
    print()


def write_csv(specs: List[RAMSpec], configs: List[CellConfig], output_path: str):
    """输出CSV"""
    with open(output_path, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['NO.', 'INST', 'TYPE', 'DP', 'WD',
                        'CELL_DP', 'CELL_WD', 'DP_Slice', 'WD_Slice',
                        'Total_DP', 'Total_WD', 'Valid', 'Note'])

        for spec, cfg in zip(specs, configs):
            writer.writerow([spec.no, spec.inst, spec.ram_type,
                           cfg.needed_dp, cfg.needed_wd,
                           cfg.cell_dp, cfg.cell_wd,
                           cfg.num_cells_depth, cfg.num_cells_width,
                           cfg.total_depth, cfg.total_width,
                           'YES' if cfg.is_valid else 'NO', cfg.note])
    print(f"Result saved to: {output_path}")


def write_csv_merged(specs: List[RAMSpec], configs: List[CellConfig], input_path: str, out_dir: str = None):
    """输出CSV（合并原始数据+结果）"""
    import os
    input_dir = os.path.dirname(os.path.abspath(input_path))
    if out_dir is None:
        out_dir = input_dir
    os.makedirs(out_dir, exist_ok=True)
    basename = os.path.basename(input_path).rsplit('.csv', 1)[0]
    output_path = os.path.join(out_dir, f'{basename}_result.csv')

    with open(output_path, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.writer(f)

        # 表头：原始列 + 新增列
        writer.writerow(['NO.', 'INST', 'TYPE', 'DP', 'WD', 'BE', 'BITS',
                        'CELL_DP', 'CELL_WD',  # 原始输入格式
                        'NEW_CELL_DP', 'NEW_CELL_WD', 'DP_Slice', 'WD_Slice',  # 计算结果
                        'Total_Bits', 'Redundant', 'Valid', 'Note'])

        # 数据行
        for spec, cfg in zip(specs, configs):
            total_bits = cfg.cell_dp * cfg.cell_wd * cfg.num_cells_depth * cfg.num_cells_width
            needed_bits = cfg.needed_dp * cfg.needed_wd
            redundant = total_bits - needed_bits
            writer.writerow([
                spec.no, spec.inst, spec.ram_type,
                cfg.needed_dp, cfg.needed_wd,
                '', '',  # BE, BITS列
                spec.cell_dp_raw, spec.cell_wd_raw,  # 原始输入格式 (如 "0:2:512")
                cfg.cell_dp, cfg.cell_wd,  # 新计算的CELL
                cfg.num_cells_depth, cfg.num_cells_width,
                total_bits, redundant,
                'YES' if cfg.is_valid else 'NO',
                cfg.note
            ])

    print(f"Result saved to: {output_path}")


def main():
    parser = argparse.ArgumentParser(description='RAM CELL Generator')
    parser.add_argument('csv_file', help='Input CSV')
    parser.add_argument('--out-dir', default=None,
                       help='Output directory (default: same as input file)')

    args = parser.parse_args()
    print(f"Reading: {args.csv_file}")

    specs = read_csv_specs(args.csv_file)
    if not specs:
        print("Error: No valid data found")
        return 1

    print(f"Read {len(specs)} RAM specs")

    configs = [find_best_config(
        s.depth, s.width,
        s.cell_dp_start, s.cell_dp_step, s.cell_dp_max,
        s.cell_wd_start, s.cell_wd_step, s.cell_wd_max
    ) for s in specs]

    print_results(specs, configs)
    write_csv_merged(specs, configs, args.csv_file, args.out_dir)

    return 0


if __name__ == '__main__':
    exit(main())
