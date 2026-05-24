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

    def strip_inline_comment(self, line):
        """移除行尾注释，尽量避免误删引号内内容。"""
        in_single_quote = False
        in_double_quote = False
        escaped = False
        i = 0

        while i < len(line):
            ch = line[i]

            if escaped:
                escaped = False
                i += 1
                continue

            if ch == '\\':
                escaped = True
                i += 1
                continue

            if not in_double_quote and ch == "'":
                in_single_quote = not in_single_quote
                i += 1
                continue

            if not in_single_quote and ch == '"':
                in_double_quote = not in_double_quote
                i += 1
                continue

            if in_single_quote or in_double_quote:
                i += 1
                continue

            if ch == '#' and (i == 0 or line[i - 1].isspace()):
                return line[:i].rstrip()

            if line.startswith('//', i) and (i == 0 or line[i - 1].isspace()):
                return line[:i].rstrip()

            i += 1

        return line
    
    def parse_line(self, line, base_dir=None, use_file_dir=False, source_file=None, line_num=0):
        """解析单行内容"""
        line = self.expand_env_vars(line)
        
        # 处理 +incdir+path
        if line.startswith('+incdir+'):
            path = line[8:]
            if use_file_dir and base_dir and not os.path.isabs(path):
                abs_path = os.path.abspath(os.path.join(base_dir, path))
                if not os.path.exists(abs_path):
                    self.warnings.append({
                        'type': 'missing_directory',
                        'message': f"include目录不存在: '{abs_path}'",
                        'source_file': source_file,
                        'line_number': line_num,
                        'original_line': line
                    })
                return f'+incdir+{abs_path}'
            else:
                if not os.path.isabs(path):
                    return line
                else:
                    abs_path = os.path.abspath(path)
                    if not os.path.exists(abs_path):
                        self.warnings.append({
                            'type': 'missing_directory',
                            'message': f"include目录不存在: '{abs_path}'",
                            'source_file': source_file,
                            'line_number': line_num,
                            'original_line': line
                        })
                    return f'+incdir+{abs_path}'
        
        # 处理 -y path
        elif line.startswith('-y '):
            path = line[3:].strip()
            if use_file_dir and base_dir and not os.path.isabs(path):
                abs_path = os.path.abspath(os.path.join(base_dir, path))
                if not os.path.exists(abs_path):
                    self.warnings.append({
                        'type': 'missing_directory',
                        'message': f"library目录不存在: '{abs_path}'",
                        'source_file': source_file,
                        'line_number': line_num,
                        'original_line': line
                    })
                return f'-y {abs_path}'
            else:
                if not os.path.isabs(path):
                    return line
                else:
                    abs_path = os.path.abspath(path)
                    if not os.path.exists(abs_path):
                        self.warnings.append({
                            'type': 'missing_directory',
                            'message': f"library目录不存在: '{abs_path}'",
                            'source_file': source_file,
                            'line_number': line_num,
                            'original_line': line
                        })
                    return f'-y {abs_path}'
        
        # 处理 -v path（库文件）
        elif line.startswith('-v '):
            path = line[3:].strip()
            if use_file_dir and base_dir and not os.path.isabs(path):
                abs_path = os.path.abspath(os.path.join(base_dir, path))
                if not os.path.exists(abs_path):
                    self.warnings.append({
                        'type': 'missing_file',
                        'message': f"库文件不存在: '{abs_path}'",
                        'source_file': source_file,
                        'line_number': line_num,
                        'original_line': line
                    })
                return f'-v {abs_path}'
            else:
                if not os.path.isabs(path):
                    return line
                else:
                    abs_path = os.path.abspath(path)
                    if not os.path.exists(abs_path):
                        self.warnings.append({
                            'type': 'missing_file',
                            'message': f"库文件不存在: '{abs_path}'",
                            'source_file': source_file,
                            'line_number': line_num,
                            'original_line': line
                        })
                    return f'-v {abs_path}'
        
        # 处理 +libext+
        elif line.startswith('+libext+'):
            return line
        
        # 处理 +define+
        elif line.startswith('+define+'):
            return line
        
        # 处理其他编译选项
        elif line.startswith('+') or (line.startswith('-') and not line.startswith('-f ') and not line.startswith('-F ')):
            return line
        
        # 普通文件路径
        else:
            if base_dir and not os.path.isabs(line):
                full_path = os.path.join(base_dir, line)
            else:
                full_path = line
            
            abs_path = os.path.abspath(full_path)
            
            if not os.path.exists(abs_path):
                self.warnings.append({
                    'type': 'missing_file',
                    'message': f"文件不存在: '{abs_path}'",
                    'source_file': source_file,
                    'line_number': line_num,
                    'original_line': line
                })
            
            return abs_path
    
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

            for line_num, line in enumerate(lines, 1):
                line = line.strip()
                
                # 跳过空行
                if not line:
                    continue
                
                # 跳过完整的注释行
                if line.startswith('#') or line.startswith('//'):
                    continue

                line = self.strip_inline_comment(line)
                
                # 再次检查处理后的行是否为空
                if not line:
                    continue

                if self.verbose_level >= 2:
                    self.log(f"[{abs_path}:{line_num}] {line}", level=2)
                
                if line.startswith('-f '):
                    nested_file = line[3:].strip()
                    self.expand(nested_file, base_dir=None, use_file_dir=False, mode_str="-f")
                
                elif line.startswith('-F '):
                    nested_file = line[3:].strip()
                    nested_base_dir = os.path.dirname(abs_path)
                    self.expand(nested_file, base_dir=nested_base_dir, use_file_dir=True, mode_str="-F")
                
                else:
                    result = self.parse_line(line, base_dir=current_base_dir, 
                                            use_file_dir=use_file_dir, 
                                            source_file=abs_path,
                                            line_num=line_num)
                    self.add_result(result)
        
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


def main():
    """主函数"""
    parser = argparse.ArgumentParser(
        description="文件列表展开工具（支持 -f/-F 递归解析）"
    )
    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument('-f', dest='file_f', metavar='FILE', help='直接解析，编译选项保持原样')
    mode_group.add_argument('-F', dest='file_F', metavar='FILE', help='解析，相对路径加上文件目录')
    parser.add_argument('input_file', nargs='?', help='输入文件（等价于 -f FILE）')
    parser.add_argument('-o', '--output', metavar='FILE', help='输出文件路径')
    parser.add_argument('-v', '--verbose', action='count', default=0, help='显示详细调试信息（可重复，如 -vv）')
    parser.add_argument('--very-verbose', action='store_true', help='very verbose（等价于 -vv）')

    args = parser.parse_args()

    specified_inputs = [args.file_f, args.file_F, args.input_file]
    input_count = sum(1 for item in specified_inputs if item)
    if input_count == 0:
        parser.error('未指定输入文件')
    if input_count > 1:
        parser.error('请仅指定一个输入文件来源：位置参数、-f 或 -F')

    if args.file_F:
        mode = 'F'
        input_file = args.file_F
    elif args.file_f:
        mode = 'f'
        input_file = args.file_f
    else:
        mode = 'f'
        input_file = args.input_file

    output_file = args.output
    verbose = 2 if args.very_verbose else min(args.verbose, 2)
    
    # 使用便捷函数
    result = ef(input_file, mode=mode, verbose=verbose)
    
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