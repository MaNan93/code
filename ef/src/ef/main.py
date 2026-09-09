#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
文件列表展开脚本
支持 Verilog/SystemVerilog 编译选项的递归解析
-f: 直接解析文件内容，编译选项保持原样
-F: 解析文件内容，相对路径加上当前文件的目录路径

可作为模块导入使用:
    from script import ef
    result = ef('main.f', mode='F', verbose=False)
    if result['success']:
        for item in result['items']:
            print(item)
    else:
        print(f"解析失败: {result['error']}")
"""

import os
import sys
import re
import argparse


class FileListExpander:
    def __init__(self, verbose=False):
        self.expanded_items = []
        self.active_files = []
        self.active_file_set = set()
        self.verbose_level = self._normalize_verbose_level(verbose)
        self.verbose = self.verbose_level > 0
        self.indent_level = 0
        self.errors = []
        self.warnings = []
        self.output_buffer = []
        self.has_critical_error = False

    def _normalize_verbose_level(self, verbose):
        """将 verbose 参数标准化为详细级别。"""
        if isinstance(verbose, bool):
            return 1 if verbose else 0

        try:
            return max(0, int(verbose))
        except (TypeError, ValueError):
            return 0
    
    def expand_env_vars(self, text):
        """展开环境变量，支持 $VAR 和 ${VAR} 两种格式"""
        text = re.sub(r'\$\{([^}]+)\}', lambda m: os.environ.get(m.group(1), m.group(0)), text)
        text = re.sub(r'\$([A-Za-z_][A-Za-z0-9_]*)', lambda m: os.environ.get(m.group(1), m.group(0)), text)
        return text
    
    def log(self, message, level=1):
        """输出调试信息"""
        if self.verbose_level >= level:
            indent = "    " * self.indent_level
            output = f"// {indent}{message}"
            self.output_buffer.append(output)
    
    def add_result(self, item):
        """添加结果项"""
        self.expanded_items.append(item)
        if self.verbose:
            indent = "    " * self.indent_level
            self.output_buffer.append(indent + item)

    def remove_comments(self, line, in_block_comment):
        """移除 # / // 行注释以及 /* ... */ 块注释（块注释可跨行）。

        引号内的内容不受影响。返回 (清理后的文本, 新的块注释状态)，
        调用方需要把返回的状态原样传给下一行，这样块注释才能正确跨行。
        """
        result = []
        quote = ''
        i = 0
        n = len(line)

        while i < n:
            ch = line[i]

            # 处于块注释内：只找 "*/" 结束标记
            if in_block_comment:
                if ch == '*' and i + 1 < n and line[i + 1] == '/':
                    in_block_comment = False
                    i += 2
                    continue
                i += 1
                continue

            # 引号内：原样保留，直到遇到匹配的引号
            if quote:
                result.append(ch)
                if ch == quote:
                    quote = ''
                i += 1
                continue

            if ch in ('"', "'"):
                quote = ch
                result.append(ch)
                i += 1
                continue

            # 单行注释：'#' 或 '//'，且前面是行首或空白，避免误删文件名里的字符
            if ch == '#' and (i == 0 or line[i - 1].isspace()):
                break

            if ch == '/' and i + 1 < n and line[i + 1] == '/' \
                    and (i == 0 or line[i - 1].isspace()):
                break

            # 块注释起始 '/*'
            if ch == '/' and i + 1 < n and line[i + 1] == '*' \
                    and (i == 0 or line[i - 1].isspace()):
                in_block_comment = True
                i += 2
                continue

            result.append(ch)
            i += 1

        return ''.join(result), in_block_comment

    def tokenize(self, line):
        """把一行拆分成多个 token，支持带空格的引号内容和反斜杠转义。

        这样一行里出现多个选项（"-v a.v -v b.v"）或者带空格的引号路径
        （+incdir+"my dir"）才能被正确地拆分/还原，而不是被当成一个
        不可分割的字符串整体处理。
        """
        tokens = []
        current = []
        quote = ''
        escape = False

        for ch in line:
            if escape:
                current.append(ch)
                escape = False
                continue

            if ch == '\\':
                escape = True
                continue

            if quote:
                if ch == quote:
                    quote = ''
                else:
                    current.append(ch)
                continue

            if ch in ('"', "'"):
                quote = ch
                continue

            if ch.isspace():
                if current:
                    tokens.append(''.join(current))
                    current = []
                continue

            current.append(ch)

        if escape:
            current.append('\\')

        if quote:
            raise ValueError(f"filelist 中有未闭合的引号: {line}")

        if current:
            tokens.append(''.join(current))

        return tokens

    def _resolve_relative(self, value, base_dir, use_file_dir):
        """把 value 解析成绝对路径。

        - 已经是绝对路径：直接折叠成绝对路径。
        - 相对路径 + -F 语义（use_file_dir 且有 base_dir）：相对于所在
          filelist 的目录解析。
        - 相对路径 + -f 语义（或没有可用的 base_dir）：VCS 的 -f 不建立
          filelist 目录 context，退化为相对当前工作目录解析。

        注意：这里总是返回一个绝对路径，不会返回"原始未解析文本"。
        之前的实现在这种情况下直接把 flag/token 的原始相对文本透传出去，
        导致同一次 -f 解析里，普通源文件路径已经被展开成绝对路径，
        而 -v/-y/+incdir+ 却还是相对路径——同一份最终参数流里绝对路径和
        相对路径混杂，对下游（尤其是不在原分析目录下再次使用这份参数流的
        场景）是不一致、容易出错的，所以统一在这里做 cwd 兜底解析。
        """
        if os.path.isabs(value):
            return os.path.abspath(value)
        if use_file_dir and base_dir:
            return os.path.abspath(os.path.join(base_dir, value))
        return os.path.abspath(value)

    def parse_token(self, token, base_dir=None, use_file_dir=False, source_file=None, line_num=0):
        """解析一个已经从行里拆分出来的 token（+incdir+.../+define+.../普通文件路径等）。"""
        token = self.expand_env_vars(token)

        # 处理 +incdir+path[+path2+path3...]
        # VCS 允许一个 +incdir+ 里用 '+' 接多个目录，需要先按 '+' 拆开，
        # 再逐个解析，不能把整段当成一个目录名。
        if token.startswith('+incdir+'):
            raw_dirs = token[8:].split('+')
            resolved_dirs = []
            for raw_dir in raw_dirs:
                # 前导/尾随/连续的 '+'（比如 "+incdir+dir1+" 或
                # "+incdir++dir1"）会拆出空字符串，它不是一个真实目录，
                # 必须跳过——否则会被当成"当前目录"误加进 include 路径。
                if raw_dir == '':
                    continue
                resolved = self._resolve_relative(raw_dir, base_dir, use_file_dir)
                if not os.path.exists(resolved):
                    self.warnings.append({
                        'type': 'missing_directory',
                        'message': f"include目录不存在: '{resolved}'",
                        'source_file': source_file,
                        'line_number': line_num,
                        'original_line': token
                    })
                resolved_dirs.append(resolved)
            return '+incdir+' + '+'.join(resolved_dirs)

        # 处理 +libext+ / +define+：保留参数，不做路径解析
        if token.startswith('+libext+') or token.startswith('+define+'):
            return token

        # 处理其他以 +/- 开头的编译选项：原样透传
        if token.startswith('+') or token.startswith('-'):
            return token

        # 普通文件路径
        resolved = self._resolve_relative(token, base_dir, use_file_dir)

        if not os.path.exists(resolved):
            self.warnings.append({
                'type': 'missing_file',
                'message': f"文件不存在: '{resolved}'",
                'source_file': source_file,
                'line_number': line_num,
                'original_line': token
            })

        return resolved

    def parse_flag_path(self, flag, value, base_dir=None, use_file_dir=False, source_file=None, line_num=0):
        """解析 -v/-y 这类"标志 + 独立路径 token"的选项。"""
        value = self.expand_env_vars(value)
        resolved = self._resolve_relative(value, base_dir, use_file_dir)

        if flag == '-v':
            kind, label = 'missing_file', '库文件'
        else:
            kind, label = 'missing_directory', 'library目录'

        if not os.path.exists(resolved):
            self.warnings.append({
                'type': kind,
                'message': f"{label}不存在: '{resolved}'",
                'source_file': source_file,
                'line_number': line_num,
                'original_line': f'{flag} {value}'
            })

        return f'{flag} {resolved}'
    
    def expand(self, file_path, base_dir=None, use_file_dir=False, mode_str=None):
        """递归展开文件列表"""
        file_path = self.expand_env_vars(file_path)
        
        if base_dir and not os.path.isabs(file_path):
            file_path = os.path.join(base_dir, file_path)
        
        abs_path = os.path.abspath(file_path)
        
        if mode_str:
            self.log(f"{mode_str} 解析 {abs_path}")
        else:
            self.log(f"解析 {abs_path}")
        
        if abs_path in self.active_file_set:
            chain = " -> ".join(self.active_files + [abs_path])
            error_msg = f"检测到循环引用: {chain}"
            self.errors.append({
                'type': 'circular_reference',
                'message': error_msg,
                'source_file': abs_path,
                'suggestion': '请检查文件列表中是否存在相互引用或自引用'
            })
            self.log(error_msg + " (已跳过)")
            self.has_critical_error = True
            return

        if not os.path.exists(abs_path):
            error_msg = f"文件列表不存在: {abs_path}"
            self.errors.append({
                'type': 'file_not_found',
                'message': error_msg,
                'source_file': abs_path,
                'suggestion': f'请检查文件路径是否正确，或文件是否已被删除'
            })
            self.log(error_msg)
            self.has_critical_error = True
            return

        self.active_files.append(abs_path)
        self.active_file_set.add(abs_path)
        
        current_base_dir = os.path.dirname(abs_path) if use_file_dir else None

        self.indent_level += 1

        try:
            with open(abs_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()

            # 块注释状态按文件独立起算，不会从父 filelist 带进来，
            # 也不会带出到父 filelist（和每个文件独立解析的语义一致）。
            in_block_comment = False

            for line_num, raw_line in enumerate(lines, 1):
                raw_line = raw_line.rstrip('\r\n')

                # 跳过空行（提前判断，避免不必要的处理）
                if not raw_line.strip():
                    continue

                cleaned, in_block_comment = self.remove_comments(raw_line, in_block_comment)

                # 整行都是注释 / 处理后为空，跳过
                if not cleaned.strip():
                    continue

                try:
                    tokens = self.tokenize(cleaned)
                except ValueError as exc:
                    self.errors.append({
                        'type': 'syntax_error',
                        'message': str(exc),
                        'source_file': abs_path,
                        'line_number': line_num,
                        'suggestion': '请检查该行的引号是否成对出现'
                    })
                    self.log(f"{abs_path}:{line_num}: {exc}")
                    self.has_critical_error = True
                    continue

                if not tokens:
                    continue

                if self.verbose_level >= 2:
                    self.log(f"[{abs_path}:{line_num}] {cleaned.strip()}", level=2)

                idx = 0
                while idx < len(tokens):
                    token = tokens[idx]

                    if token == '-f':
                        if idx + 1 >= len(tokens):
                            self.errors.append({
                                'type': 'syntax_error',
                                'message': '-f 缺少参数',
                                'source_file': abs_path,
                                'line_number': line_num,
                                'suggestion': '请在 -f 后面指定要展开的文件列表'
                            })
                            self.has_critical_error = True
                            break
                        nested_file = tokens[idx + 1]
                        self.expand(nested_file, base_dir=None, use_file_dir=False, mode_str="-f")
                        idx += 2
                        continue

                    if token == '-F':
                        if idx + 1 >= len(tokens):
                            self.errors.append({
                                'type': 'syntax_error',
                                'message': '-F 缺少参数',
                                'source_file': abs_path,
                                'line_number': line_num,
                                'suggestion': '请在 -F 后面指定要展开的文件列表'
                            })
                            self.has_critical_error = True
                            break
                        nested_file = tokens[idx + 1]
                        nested_base_dir = os.path.dirname(abs_path)
                        self.expand(nested_file, base_dir=nested_base_dir, use_file_dir=True, mode_str="-F")
                        idx += 2
                        continue

                    if token in ('-v', '-y'):
                        if idx + 1 >= len(tokens):
                            self.errors.append({
                                'type': 'syntax_error',
                                'message': f'{token} 缺少参数',
                                'source_file': abs_path,
                                'line_number': line_num,
                                'suggestion': f'请在 {token} 后面指定路径'
                            })
                            self.has_critical_error = True
                            break
                        value = tokens[idx + 1]
                        result = self.parse_flag_path(token, value, base_dir=current_base_dir,
                                                       use_file_dir=use_file_dir,
                                                       source_file=abs_path,
                                                       line_num=line_num)
                        self.add_result(result)
                        idx += 2
                        continue

                    result = self.parse_token(token, base_dir=current_base_dir,
                                               use_file_dir=use_file_dir,
                                               source_file=abs_path,
                                               line_num=line_num)
                    self.add_result(result)
                    idx += 1

        except PermissionError:
            error_msg = f"没有权限读取文件: {abs_path}"
            self.errors.append({
                'type': 'permission_denied',
                'message': error_msg,
                'source_file': abs_path,
                'suggestion': '请检查文件权限，确保当前用户有读取权限'
            })
            self.log(error_msg)
            self.has_critical_error = True
        except UnicodeDecodeError:
            error_msg = f"文件编码错误: {abs_path}"
            self.errors.append({
                'type': 'encoding_error',
                'message': error_msg,
                'source_file': abs_path,
                'suggestion': '文件可能不是UTF-8编码，请检查文件编码格式'
            })
            self.log(error_msg)
            self.has_critical_error = True
        except Exception as e:
            error_msg = f"处理文件时发生异常: {abs_path}"
            self.errors.append({
                'type': 'unknown_error',
                'message': f"{error_msg}: {str(e)}",
                'source_file': abs_path,
                'suggestion': '请检查文件格式是否正确'
            })
            self.log(error_msg)
            self.has_critical_error = True
        finally:
            self.indent_level -= 1
            self.active_file_set.remove(abs_path)
            self.active_files.pop()
    
    def get_items(self):
        """返回展开后的项列表"""
        return self.expanded_items
    
    def get_output(self):
        """返回输出内容（verbose模式下包含注释）"""
        return self.output_buffer if self.verbose else None
    
    def get_errors(self):
        """返回错误列表"""
        return self.errors
    
    def get_warnings(self):
        """返回警告列表"""
        return self.warnings
    
    def is_success(self):
        """判断是否成功解析（没有严重错误）"""
        return not self.has_critical_error
    
    def get_result(self):
        """返回完整的结果字典，方便其他工具调用"""
        return {
            'success': self.is_success(),
            'items': self.get_items(),
            'errors': self.get_errors(),
            'warnings': self.get_warnings(),
            'output': self.get_output()
        }
    
    def format_error_message(self, error):
        """格式化错误信息为友好的输出"""
        if isinstance(error, dict):
            msg = f"错误: {error['message']}"
            if 'source_file' in error:
                msg += f"\n  文件: {error['source_file']}"
            if 'line_number' in error:
                msg += f"\n  行号: {error['line_number']}"
            if 'suggestion' in error:
                msg += f"\n  建议: {error['suggestion']}"
            return msg
        return str(error)
    
    def format_warning_message(self, warning):
        """格式化警告信息为友好的输出"""
        if isinstance(warning, dict):
            msg = f"警告: {warning['message']}"
            if 'source_file' in warning:
                msg += f"\n  文件: {warning['source_file']}"
            if 'line_number' in warning:
                msg += f"\n  行号: {warning['line_number']}"
            if 'original_line' in warning:
                msg += f"\n  原始行: {warning['original_line']}"
            return msg
        return str(warning)


def ef(input_file, mode='f', base_dir=None, verbose=False):
    """
    展开文件列表的便捷函数，供其他工具调用
    
    参数:
        input_file: 输入文件路径
        mode: 解析模式，'f' 或 'F'
        base_dir: 基础目录（仅对 'F' 模式有效，默认为当前工作目录）
        verbose: 详细级别，False/0 为普通模式，True/1 为 verbose，2 为 very verbose
    
    返回:
        字典包含以下键:
        - success (bool): 是否成功解析（无严重错误）
        - items (list): 展开后的文件和选项列表
        - errors (list): 错误列表（严重错误，如文件不存在、循环引用）
        - warnings (list): 警告列表（非致命问题，如文件不存在）
        - output (list or None): verbose/vv 模式下的输出行
    
    示例:
        result = ef('main.f', mode='F', verbose=2)
        if result['success']:
            for item in result['items']:
                print(item)
        else:
            print("解析失败:")
            for error in result['errors']:
                print(f"  {error}")
    """
    expander = FileListExpander(verbose=verbose)
    
    if mode == 'F':
        if base_dir is None:
            base_dir = os.getcwd()
        expander.expand(input_file, base_dir=base_dir, use_file_dir=True, mode_str="-F")
    else:
        expander.expand(input_file, base_dir=None, use_file_dir=False, mode_str="-f")
    
    return expander.get_result()


class _CollectFileSpecAction(argparse.Action):
    """记录 -f/-F 在命令行里出现的先后顺序。

    -f 和 -F 共用同一个 dest，都用这个 action，这样可以重复指定、也可以
    互相穿插（比如 "-f a.f -F b.f -f c.f"），并且严格按命令行里出现的
    顺序保存下来，交给 main() 依次展开、拼接结果——和 Perl 那个工具的
    命令行语义保持一致。
    """

    def __call__(self, parser, namespace, values, option_string=None):
        specs = getattr(namespace, self.dest, None)
        if specs is None:
            specs = []
        mode = 'F' if option_string == '-F' else 'f'
        specs.append((mode, values))
        setattr(namespace, self.dest, specs)


def main():
    """主函数"""
    parser = argparse.ArgumentParser(
        description="文件列表展开工具（支持 -f/-F 递归解析，-f/-F 可以重复出现多次，"
                     "按命令行顺序依次展开并拼接成一份结果）"
    )
    parser.add_argument('-f', metavar='FILE', dest='file_specs', action=_CollectFileSpecAction,
                         help='直接解析，编译选项保持原样；可重复指定')
    parser.add_argument('-F', metavar='FILE', dest='file_specs', action=_CollectFileSpecAction,
                         help='解析，相对路径加上文件目录；可重复指定')
    parser.add_argument('input_file', nargs='?', help='输入文件（等价于单个 -f FILE），不能和 -f/-F 同时使用')
    parser.add_argument('-o', '--output', metavar='FILE', help='输出文件路径')
    parser.add_argument('-v', '--verbose', action='count', default=0, help='显示详细调试信息（可重复，如 -vv）')
    parser.add_argument('--very-verbose', action='store_true', help='very verbose（等价于 -vv）')

    args = parser.parse_args()

    file_specs = args.file_specs or []

    if file_specs and args.input_file:
        parser.error('请仅指定一种输入文件来源：位置参数，或者一个/多个 -f、-F')
    if not file_specs and not args.input_file:
        parser.error('未指定输入文件')

    if not file_specs:
        file_specs = [('f', args.input_file)]

    output_file = args.output
    verbose = 2 if args.very_verbose else min(args.verbose, 2)

    # 依次展开命令行上出现过的每一个 -f/-F，按出现顺序把结果拼接起来
    combined_success = True
    combined_items = []
    combined_errors = []
    combined_warnings = []
    combined_output = []

    for mode, input_file in file_specs:
        one_result = ef(input_file, mode=mode, verbose=verbose)
        combined_success = combined_success and one_result['success']
        combined_items.extend(one_result['items'])
        combined_errors.extend(one_result['errors'])
        combined_warnings.extend(one_result['warnings'])
        if verbose and one_result['output']:
            combined_output.extend(one_result['output'])

    result = {
        'success': combined_success,
        'items': combined_items,
        'errors': combined_errors,
        'warnings': combined_warnings,
        'output': combined_output if verbose else None,
    }

    # 输出结果
    if verbose and result['output']:
        for line in result['output']:
            print(line)
    else:
        for item in result['items']:
            print(item)
    
    # 输出错误和警告
    if result['errors'] or result['warnings']:
        print("\n" + "=" * 80, file=sys.stderr)
        if result['errors']:
            print("发现以下错误:", file=sys.stderr)
            print("-" * 80, file=sys.stderr)
            expander = FileListExpander()
            for error in result['errors']:
                print(expander.format_error_message(error), file=sys.stderr)
                print("-" * 80, file=sys.stderr)
        if result['warnings']:
            print("\n发现以下警告:", file=sys.stderr)
            print("-" * 80, file=sys.stderr)
            expander = FileListExpander()
            for warning in result['warnings']:
                print(expander.format_warning_message(warning), file=sys.stderr)
                print("-" * 80, file=sys.stderr)
        print("=" * 80, file=sys.stderr)
        print(f"\n总计: {len(result['errors'])} 个错误, {len(result['warnings'])} 个警告", file=sys.stderr)
    
    # 输出到文件
    if output_file:
        with open(output_file, 'w', encoding='utf-8') as f:
            for item in result['items']:
                f.write(item + '\n')
        print(f"\n结果已保存到: {os.path.abspath(output_file)}", file=sys.stderr)
    
    # 返回退出码
    sys.exit(0 if result['success'] else 1)


if __name__ == "__main__":
    main()