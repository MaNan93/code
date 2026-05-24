#!/usr/bin/env python3
"""
replace_tokens.py

读取 token 映射文件，将每行第二列（加扰名）替换为随机字符串（不重复）。
文件格式：每行 "TOKEN SCRAMBLED_NAME"

用法：
  python replace_tokens.py <输入文件> [输出文件] [--length N]
  输出文件可选，省略时结果打印到标准输出。
  --length N  指定替换字符串的固定长度（10~20），不指定则保持原始加扰名长度。
"""

import sys
import random
import string
import argparse

# 模块级常量，避免每次调用重建
_CHARS = string.ascii_uppercase + string.ascii_lowercase + string.digits

_LENGTH_MIN = 10
_LENGTH_MAX = 20


# ── 核心功能 ────────────────────────────────────────────────────────────────

def generate_unique_random(length, used):
    # type: (int, set) -> str
    """
    生成指定长度、不在 used 中的随机字符串（大小写字母 + 数字），并加入 used。

    当该长度的可能组合已全部用尽时抛出 ValueError。
    """
    max_possible = len(_CHARS) ** length
    if len(used) >= max_possible:
        raise ValueError(
            "长度 %d 的随机字符串已耗尽（上限 %d）" % (length, max_possible)
        )
    while True:
        candidate = ''.join(random.choices(_CHARS, k=length))
        if candidate not in used:
            used.add(candidate)
            return candidate


def replace_scrambled_names(lines, fixed_length=None):
    # type: (list, int) -> tuple
    """
    处理输入行，将每行第二列（加扰名）替换为随机字符串。

    参数：
        lines:        原始行列表（含换行符）
        fixed_length: 指定替换字符串的固定长度；为 None 时保持原始加扰名长度
    返回：
        (output_lines, warnings)
        - output_lines: 替换后的行列表
        - warnings:     格式不符的警告信息列表
    """
    used_names = set()
    # 缓存：相同 token 使用同一替换名
    token_map = {}
    output_lines = []
    warnings = []

    for lineno, line in enumerate(lines, 1):
        stripped = line.rstrip('\r\n')

        # 空行和注释行原样保留
        if not stripped or stripped.startswith('#'):
            output_lines.append(line)
            continue

        parts = stripped.split()
        if len(parts) < 2:
            warnings.append("警告：第 %d 行格式不符，已原样保留：%r" % (lineno, stripped))
            output_lines.append(line)
            continue

        token     = parts[0]
        scrambled = parts[1]
        tail      = ' '.join(parts[2:])  # 保留行尾多余字段（如有）

        length = fixed_length if fixed_length is not None else len(scrambled)

        if token not in token_map:
            token_map[token] = generate_unique_random(length, used_names)
        new_name = token_map[token]

        new_line = "%s %s" % (token, new_name)
        if tail:
            new_line += " " + tail
        new_line += '\n'
        output_lines.append(new_line)

    return output_lines, warnings


# ── 命令行 ──────────────────────────────────────────────────────────────────

def read_input(path):
    # type: (str) -> list
    """读取输入文件，返回行列表。"""
    with open(path, 'r', encoding='utf-8') as f:
        return f.readlines()


def write_output(path, lines):
    # type: (str, list) -> None
    """将行列表写入输出文件。"""
    with open(path, 'w', encoding='utf-8') as f:
        f.writelines(lines)


def parse_args():
    """解析命令行参数。"""
    parser = argparse.ArgumentParser(
        description='将 token 映射文件中的加扰名替换为随机字符串'
    )
    parser.add_argument('input',           help='输入文件路径')
    parser.add_argument('output', nargs='?', default=None, help='输出文件路径（可选，默认打印到标准输出）')
    parser.add_argument(
        '--length', type=int, default=None,
        metavar='N',
        help='替换字符串的固定长度（%d~%d），不指定则保持原始加扰名长度' % (_LENGTH_MIN, _LENGTH_MAX)
    )
    args = parser.parse_args()

    if args.length is not None and not (_LENGTH_MIN <= args.length <= _LENGTH_MAX):
        parser.error("--length 必须在 %d~%d 之间" % (_LENGTH_MIN, _LENGTH_MAX))

    return args.input, args.output, args.length


def main():
    input_path, output_path, fixed_length = parse_args()

    try:
        lines = read_input(input_path)
    except FileNotFoundError:
        print("错误：文件 '%s' 不存在" % input_path, file=sys.stderr)
        sys.exit(1)
    except IOError as e:
        print("错误：无法读取文件：%s" % e, file=sys.stderr)
        sys.exit(1)

    try:
        output_lines, warnings = replace_scrambled_names(lines, fixed_length)
    except ValueError as e:
        print("错误：%s" % e, file=sys.stderr)
        sys.exit(1)

    for w in warnings:
        print(w, file=sys.stderr)

    if output_path:
        write_output(output_path, output_lines)
        print("完成：已写入 '%s'，共处理 %d 行" % (output_path, len(lines)))
    else:
        sys.stdout.writelines(output_lines)


if __name__ == '__main__':
    main()
