import re
import os
import ast
import logging
from typing import Optional, Dict, List, Set, Tuple

class VerilogPreprocessor:
    # Verilog preprocessor - handles macro definitions and conditional compilation
    
    # Pre-compiled regular expressions
    DEFINE_PATTERN = re.compile(r'`define\s+(\w+)(?:\s+(.+?))?(?://.*)?$', re.MULTILINE)
    PARAM_PATTERN = re.compile(r'parameter\s+(?:\w+\s+)?(\w+)\s*=\s*([^,;]+)')
    IFDEF_PATTERN = re.compile(r'`ifdef\s+(\w+)')
    IFNDEF_PATTERN = re.compile(r'`ifndef\s+(\w+)')
    ELSIF_PATTERN = re.compile(r'`elsif\s+(\w+)')
    ELSE_PATTERN = re.compile(r'`else\b')
    ENDIF_PATTERN = re.compile(r'`endif\b')
    BLOCK_COMMENT_PATTERN = re.compile(r'/\*.*?\*/', re.DOTALL)
    LINE_COMMENT_PATTERN = re.compile(r'//.*')
    
    def __init__(self, content: str):
        self.content = content
        self.defined_flags = set()  # FLAG type defines
        self.macro_values = {}  # Macros with values
        self.parameters = {}  # Parameter definitions
    
    def preprocess(self) -> str:
        """Preprocess: extract defines and parameters, handle conditionals, remove comments"""
        # 先删除注释，避免注释中的`define或条件编译干扰解析
        cleaned = self._remove_comments(self.content)
        self.content = cleaned

        # 提取所有的`define定义
        self._extract_defines()

        # 处理条件编译（基于已去注释的内容和提取到的宏）
        content = self._process_conditionals()

        # 提取parameter定义
        self._extract_parameters(content)
        return content
    
    def _extract_defines(self) -> None:
        """Extract all `define definitions from file"""
        for match in self.DEFINE_PATTERN.finditer(self.content):
            name = match.group(1)
            value = match.group(2)
            
            if value:
                # Macros with values
                value = value.strip()
                # Remove possible comments
                value = re.sub(r'//.*', '', value).strip()
                self.macro_values[name] = value
            else:
                # FLAG type defines (no value)
                self.defined_flags.add(name)
    
    def _extract_parameters(self, content: str) -> None:
        """Extract module parameter definitions"""
        for match in self.PARAM_PATTERN.finditer(content):
            name = match.group(1)
            value = match.group(2).strip()
            # Remove comments
            value = re.sub(r'//.*', '', value).strip()
            self.parameters[name] = value
    
    def _process_conditionals(self) -> str:
        """Process conditional compilation directives"""
        lines = self.content.split('\n')
        result_lines = []
        
        condition_stack = []
        
        for line in lines:
            stripped = line.strip()
            
            # Check conditional compilation directives
            ifdef_match = self.IFDEF_PATTERN.match(stripped)
            ifndef_match = self.IFNDEF_PATTERN.match(stripped)
            elsif_match = self.ELSIF_PATTERN.match(stripped)
            else_match = self.ELSE_PATTERN.match(stripped)
            endif_match = self.ENDIF_PATTERN.match(stripped)
            
            if ifdef_match:
                flag = ifdef_match.group(1)
                is_defined = flag in self.defined_flags
                
                parent_active = len(condition_stack) == 0 or all(active for _, active in condition_stack)
                this_active = is_defined and parent_active
                
                condition_stack.append((is_defined, this_active))
                
            elif ifndef_match:
                flag = ifndef_match.group(1)
                is_not_defined = flag not in self.defined_flags
                
                parent_active = len(condition_stack) == 0 or all(active for _, active in condition_stack)
                this_active = is_not_defined and parent_active
                
                condition_stack.append((is_not_defined, this_active))
                
            elif elsif_match:
                flag = elsif_match.group(1)
                if condition_stack:
                    prev_condition, prev_active = condition_stack.pop()
                    
                    if not prev_condition:
                        is_defined = flag in self.defined_flags
                        parent_active = len(condition_stack) == 0 or all(active for _, active in condition_stack)
                        this_active = is_defined and parent_active
                        condition_stack.append((is_defined, this_active))
                    else:
                        condition_stack.append((True, False))  # 修复逻辑问题
                
            elif else_match:
                if condition_stack:
                    condition_met, was_active = condition_stack.pop()
                    
                    parent_active = len(condition_stack) == 0 or all(active for _, active in condition_stack)
                    this_active = (not condition_met) and parent_active
                    
                    condition_stack.append((not condition_met, this_active))
                
            elif endif_match:
                if condition_stack:
                    condition_stack.pop()
                
            else:
                # 普通代码行
                should_include = len(condition_stack) == 0 or all(active for _, active in condition_stack)
                
                if should_include:
                    result_lines.append(line)
        
        return '\n'.join(result_lines)
    
    def _remove_comments(self, content: str) -> str:
        """Remove comments (block and line comments)"""
        # Remove block comments
        content = self.BLOCK_COMMENT_PATTERN.sub('', content)
        # Remove line comments
        content = self.LINE_COMMENT_PATTERN.sub('', content)
        return content
    
    def replace_macros_and_params(self, text: str) -> str:
        """Replace macros and parameters in text"""
        if not text:
            return text
        
        result = text
        max_iterations = 10  # Prevent circular references
        iteration_count = 0
        
        for iteration_count in range(max_iterations):
            old_result = result
            
            # Replace macros (`MACRO_NAME)
            for name, value in self.macro_values.items():
                result = re.sub(rf'`{name}\b', value, result)
            
            # Replace parameters (PARAM_NAME)
            for name, value in self.parameters.items():
                result = re.sub(rf'\b{name}\b', value, result)
            
            # If no change, replacement is complete
            if result == old_result:
                break  # 添加缺失的break语句
        else:
            # Loop reached max_iterations without convergence - circular reference detected
            import warnings
            warnings.warn(
                f"Macro/parameter replacement reached max iterations ({max_iterations}). "
                f"Possible circular reference detected in: {text[:50]}... "
                f"Returning result after {max_iterations} iterations.",
                stacklevel=2
            )
        
        return result
    
    def evaluate_expression(self, expr: str) -> Tuple[str, int]:
        """
        Evaluate expression
        Returns: (expanded_expression, calculated_bits)
        """
        if not expr:
            return '0:0', 1
        
        try:
            # Replace all macros and parameters
            expanded = self.replace_macros_and_params(expr)
            
            # If expression still has identifiers (unresolved parameters), return 0
            if re.search(r'[a-zA-Z_]\w*', expanded):
                return expanded, 0
            
            # Try to evaluate expression
            if ':' in expanded:
                parts = expanded.split(':')
                if len(parts) != 2:
                    raise ValueError(f"Invalid bit range format: {expanded} (expected 'msb:lsb')")
                    
                msb_str = parts[0].strip()
                lsb_str = parts[1].strip()
                
                try:
                    msb = self._safe_eval(msb_str)
                    lsb = self._safe_eval(lsb_str)
                except ValueError as e:
                    raise ValueError(f"Cannot evaluate bit range '{expanded}': {str(e)}")
                
                bits = abs(msb - lsb) + 1
                return expanded, bits
            else:
                # Single number [N]
                try:
                    n = self._safe_eval(expanded)
                    return expanded, n + 1
                except ValueError as e:
                    raise ValueError(f"Cannot evaluate expression '{expanded}': {str(e)}")
        except ValueError as e:
            # Unable to calculate, but return what we have
            import warnings
            warnings.warn(f"Expression evaluation failed: {str(e)}", stacklevel=2)
            return expanded if 'expanded' in locals() else expr, 0
        except Exception as e:
            # Unexpected error
            import warnings
            warnings.warn(f"Unexpected error evaluating expression '{expr}': {type(e).__name__}: {str(e)}", stacklevel=2)
            return expr, 0
    
    def _safe_eval(self, expr: str) -> int:
        """Safely evaluate simple mathematical expressions using AST"""
        if not expr:
            raise ValueError("Empty expression")
        
        # Use ast to parse and only allow safe nodes
        try:
            node = ast.parse(expr, mode='eval')
        except SyntaxError as e:
            raise ValueError(f"Syntax error in expression '{expr}': {str(e)}")
        except Exception as e:
            raise ValueError(f"Failed to parse expression '{expr}': {type(e).__name__}: {str(e)}")

        def _eval(node):
            try:
                if isinstance(node, ast.Expression):
                    return _eval(node.body)
                if isinstance(node, ast.Constant):
                    return int(node.value)
                if isinstance(node, ast.Num):
                    return int(node.n)
                if isinstance(node, ast.BinOp):
                    left = _eval(node.left)
                    right = _eval(node.right)
                    if isinstance(node.op, ast.Add):
                        return left + right
                    if isinstance(node.op, ast.Sub):
                        return left - right
                    if isinstance(node.op, ast.Mult):
                        return left * right
                    if isinstance(node.op, ast.Div):
                        if right == 0:
                            raise ValueError("Division by zero")
                        return left // right
                    if isinstance(node.op, ast.Mod):
                        if right == 0:
                            raise ValueError("Modulo by zero")
                        return left % right
                    if isinstance(node.op, ast.LShift):
                        return left << right
                    if isinstance(node.op, ast.RShift):
                        return left >> right
                    if isinstance(node.op, ast.BitAnd):
                        return left & right
                    if isinstance(node.op, ast.BitOr):
                        return left | right
                    if isinstance(node.op, ast.BitXor):
                        return left ^ right
                    raise ValueError(f"Unsupported binary operator: {type(node.op).__name__}")
                if isinstance(node, ast.UnaryOp):
                    operand = _eval(node.operand)
                    if isinstance(node.op, ast.UAdd):
                        return +operand
                    if isinstance(node.op, ast.USub):
                        return -operand
                    if isinstance(node.op, ast.Invert):
                        return ~operand
                    raise ValueError(f"Unsupported unary operator: {type(node.op).__name__}")
                # 修复：添加更多异常处理
                if isinstance(node, ast.Name):
                    raise ValueError(f"Cannot evaluate identifier '{node.id}'")
                raise ValueError(f"Unsupported expression node type: {type(node).__name__}")
            except ValueError:
                raise
            except Exception as e:
                raise ValueError(f"Error during evaluation: {type(e).__name__}: {str(e)}")
        
        try:
            result = int(_eval(node))
            return result
        except ValueError as e:
            raise ValueError(f"Evaluation of '{expr}' failed: {str(e)}")
        except Exception as e:
            raise ValueError(f"Unexpected error evaluating '{expr}': {type(e).__name__}: {str(e)}")

class VerilogPortAnalyzer:
    """Verilog port analyzer - automatically handles macros and parameters"""
    
    # Pre-compiled regular expressions
    MODULE_PATTERN = re.compile(r'module\s+(\w+)\s*(?:#\s*\(([^)]*)\))?\s*\((.*?)\);(.*?)endmodule', re.DOTALL)
    MODULE_SEARCH_PATTERN = re.compile(r'module\s+(\w+)\s*(?:#\s*\(([^)]*)\))?\s*\(')
    ANSI_PORT_PATTERN = re.compile(
        r'(input|output|inout)\s+(?:(wire|reg|logic)\s+)?(?:(signed)\s+)?(?:\[([^\]]+)\]\s+)?(\w+)'
    )
    PORT_SPLIT_PATTERN = re.compile(r',(?![^\[]*\])')
    DIRECTION_PATTERN = re.compile(r'(input|output|inout)')
    
    def __init__(self, filename: str, module_name: Optional[str] = None):
        self.filename = filename
        self.preprocessor = None
        self.is_ansi_style = False  # Record if ANSI style
        self._parsed_module_cache = None  # Cache for parse_target_module() result
        
        # Read file once
        if not os.path.isfile(filename):
            raise ValueError(f"File '{filename}' not found")
        
        with open(self.filename, 'r', encoding='utf-8') as f:
            self.raw_content = f.read()
        
        # Determine module name
        if module_name:
            self.module_name = module_name
        else:
            self.module_name = self._determine_module_name()
        
        # Preprocess content
        self.content = self._preprocess_content()

    def _determine_module_name(self) -> str:
        """
        Determine module name based on number of modules in file:
        - Only 1 module: use module name from file
        - Multiple modules: use filename as module name (must match one of them)
        """
        # Find all module definitions using already-read content
        matches = list(self.MODULE_SEARCH_PATTERN.finditer(self.raw_content))
        
        # If only 1 module, use module name from file
        if len(matches) == 1:
            return matches[0].group(1)
        
        # If multiple modules, use filename as module name
        if len(matches) > 1:
            file_module_name = self._get_module_name_from_filename()
            module_names = [m.group(1) for m in matches]
            
            # Check if filename matches one of the modules
            if file_module_name in module_names:
                return file_module_name
            else:
                raise ValueError(
                    f"File '{self.filename}' contains {len(module_names)} module(s): {', '.join(module_names)}\n"
                    f"Expected filename to match one of these modules.\n"
                    f"Provided filename '{file_module_name}' does not match any module.\n"
                    f"Please specify module_name parameter to select which module to analyze."
                )
        
        # If no module found
        raise ValueError(
            f"No module definitions found in file '{self.filename}'.\n"
            f"File must contain at least one Verilog module definition."
        )
    
    def _get_module_name_from_filename(self) -> str:
        """Extract module name from filename"""
        basename = os.path.basename(self.filename)
        module_name = os.path.splitext(basename)[0]
        return module_name
    
    def _preprocess_content(self) -> str:
        """Preprocess already-read file content"""
        # Use preprocessor on the raw content
        self.preprocessor = VerilogPreprocessor(self.raw_content)
        processed_content = self.preprocessor.preprocess()
        
        return processed_content
    
    def get_module(self) -> str:
        """返回分析的module名"""
        return self.module_name
    
    def parse_target_module(self) -> Optional[Dict]:
        """Parse only the module matching the filename or specified module_name"""
        
        # Return cached result if available
        if self._parsed_module_cache is not None:
            return self._parsed_module_cache
        
        # Find all module definitions
        modules = self.MODULE_PATTERN.finditer(self.content)
        
        # Find module matching module_name
        for match in modules:
            found_module_name = match.group(1)
            
            if found_module_name == self.module_name:
                param_list = match.group(2)
                port_list = match.group(3)
                module_body = match.group(4)
                # Parse ports
                try:
                    ports = self._parse_ports(port_list, module_body)
                except Exception as e:
                    raise ValueError(
                        f"Error parsing ports for module '{self.module_name}' in '{self.filename}': {str(e)}"
                    )
                
                # Calculate statistics
                statistics = self._calculate_statistics(ports)
                
                # Cache the result
                self._parsed_module_cache = {
                    'module_name': found_module_name,
                    'filename': self.filename,
                    'is_ansi_style': self.is_ansi_style,
                    'defined_flags': sorted(list(self.preprocessor.defined_flags)),
                    'macros': self.preprocessor.macro_values,
                    'parameters': self.preprocessor.parameters,
                    'ports': ports,
                    'statistics': statistics
                }
                
                return self._parsed_module_cache
        
        # Module not found - raise error instead of warning
        raise ValueError(
            f"Module '{self.module_name}' not found in file '{self.filename}'. "
            f"Check file content and module name."
        )
    
    def _parse_ports(self, port_list: str, module_body: str) -> List[Dict]:
        """Parse port list"""
        ports = []
        
        # Check if ANSI or non-ANSI style
        if self.DIRECTION_PATTERN.search(port_list):
            self.is_ansi_style = True
            ports = self._parse_ansi_ports(port_list)
        else:
            self.is_ansi_style = False
            ports = self._parse_non_ansi_ports(port_list, module_body)
        
        return ports
    
    def _parse_ansi_ports(self, port_list: str) -> List[Dict]:
        """Parse ANSI-style ports"""
        ports = []
# Split port declarations
        port_decls = self.PORT_SPLIT_PATTERN.split(port_list)
        
        current_direction = None
        current_type = 'wire'
        current_signed = False
        
        for decl in port_decls:
            decl = decl.strip()
            if not decl:
                continue
            
            # Full declaration
            full_match = self.ANSI_PORT_PATTERN.match(decl)
            
            if full_match:
                current_direction = full_match.group(1)
                current_type = full_match.group(2) or 'wire'
                current_signed = full_match.group(3) is not None
                width = full_match.group(4)
                name = full_match.group(5)
            else:
                # 只有位宽和名字
                width_name_pattern = r'(?:\[([^\]]+)\]\s+)?(\w+)'
                width_name_match = re.match(width_name_pattern, decl)
                
                if width_name_match:
                    width = width_name_match.group(1)
                    name = width_name_match.group(2)
                else:
                    continue
            
            # 计算位宽（自动替换宏和参数）
            width_expanded, bits = self._evaluate_width(width)
            
            ports.append({
                'name': name,
                'direction': current_direction,
                'type': current_type,
                'signed': current_signed,
                'width': width_expanded,
                'bits': bits
            })
        
        return ports
    
    def _parse_non_ansi_ports(self, port_list: str, module_body: str) -> List[Dict]:
        """Parse non-ANSI style ports"""
        ports = []
        
        port_names = [p.strip() for p in port_list.split(',') if p.strip()]
        
        for name in port_names:
            decl_pattern = rf'(input|output|inout)\s+(?:(wire|reg|logic)\s+)?(?:(signed)\s+)?(?:\[([^\]]+)\]\s+)?{name}\b'
            match = re.search(decl_pattern, module_body)
            
            if match:
                width = match.group(4)
                width_expanded, bits = self._evaluate_width(width)
                
                ports.append({
                    'name': name,
                    'direction': match.group(1),
                    'type': match.group(2) or 'wire',
                    'signed': match.group(3) is not None,
                    'width': width_expanded,
                    'bits': bits
                })
            else:
                ports.append({
                    'name': name,
                    'direction': 'unknown',
                    'type': 'wire',
                    'signed': False,
                    'width': '0:0',
                    'bits': 1
                })
        
        return ports
    
    def _evaluate_width(self, width_str: Optional[str]) -> Tuple[str, int]:
        """Calculate width (using preprocessor)"""
        if not width_str:
            return '0:0', 1
        
        return self.preprocessor.evaluate_expression(width_str)
    
    def _calculate_statistics(self, ports: List[Dict]) -> Dict:
        """Calculate statistics from ports"""
        input_count = sum(1 for p in ports if p['direction'] == 'input')
        output_count = sum(1 for p in ports if p['direction'] == 'output')
        inout_count = sum(1 for p in ports if p['direction'] == 'inout')
        
        total_bits = sum(p['bits'] for p in ports if p['bits'] > 0)
        param_ports = sum(1 for p in ports if p['bits'] == 0)
        
        return {
            'total_ports': len(ports),
            'input_ports': input_count,
            'output_ports': output_count,
            'inout_ports': inout_count,
            'total_bits': total_bits,
            'parameterized_ports': param_ports
        }
    
    def get_port(self) -> List[List]:
        """
        返回端口信息的多维列表格式
        
        Returns:
            List[List]: 每个元素是 [端口名, 方向, 类型, 位宽, 位数]
            例如: [['clk', 'input', 'wire', '0:0', 1], ['data', 'output', 'reg', '31:0', 32]]
        """
        result = self.parse_target_module()
        if not result:
            return []
        
        ports_list = []
        for port in result['ports']:
            ports_list.append([
                port['name'],
                port['direction'],
                port['type'],
                port['width'],
                port['bits']
            ])
        
        return ports_list
    
    def get_inst(self, instance_name: str = None, indent: str = "    ") -> str:
        """
        生成Verilog实例化代码
        非ANSI风格不包含参数实例化
        
        Args:
            instance_name: 实例名称，默认为 u_{module_name}
            indent: 缩进字符串，默认4个空格
            
        Returns:
            实例化代码字符串
        """
        result = self.parse_target_module()
        if not result:
            return ""
        
        module_name = result['module_name']
        ports = result['ports']
        parameters = result['parameters']
        is_ansi = result['is_ansi_style']
        
        # 默认实例名
        if not instance_name:
            instance_name = f"u_{module_name}"
        
        # 开始生成代码
        lines = []
        
        # Module声明 - 只有ANSI风格才包含参数
        if is_ansi and parameters:
            lines.append(f"{module_name} #(")
            param_lines = []
            for i, (name, value) in enumerate(parameters.items()):
                comma = "," if i < len(parameters) - 1 else ""
                param_lines.append(f"{indent}.{name}({name}){comma}")
            lines.extend(param_lines)
            lines.append(f") {instance_name} (")
        else:
            lines.append(f"{module_name} {instance_name} (")
        
        # 端口连接
        port_lines = []
        max_name_len = max(len(p['name']) for p in ports) if ports else 0
        
        # 先生成所有端口行（不含注释）以计算最长长度
        temp_port_lines = []
        for i, port in enumerate(ports):
            name = port['name']
            comma = "," if i < len(ports) - 1 else ""
            temp_line = f"{indent}.{name:<{max_name_len}} ({name}){comma}"
            temp_port_lines.append((temp_line, port['direction']))
        
        # 计算最长的端口行长度
        max_line_len = max(len(line) for line, _ in temp_port_lines) if temp_port_lines else 0
        
        # 生成带对齐注释的端口行
        for line, direction in temp_port_lines:
            padding = max_line_len - len(line)
            port_lines.append(f"{line}{' ' * padding}  // {direction}")
        
        lines.extend(port_lines)
        lines.append(");")
        
        return '\n'.join(lines)
    
    def get_wire(self, prefix: str = "", indent: str = "") -> str:
        """
        生成wire/reg声明代码
        
        Args:
            prefix: 信号名前缀
            indent: 缩进字符串
            
        Returns:
            声明代码字符串
        """
        result = self.parse_target_module()
        if not result:
            return ""
        
        ports = result['ports']
        lines = []
        
        # 找出最长的类型和位宽，用于对齐
        max_type_len = max(len(p['type']) for p in ports) if ports else 0
        max_width_len = max(len(f"[{p['width']}]") if p['bits'] > 1 else 0 for p in ports)
        
        # 先生成所有信号声明行（不含注释）以计算最长长度
        temp_lines = []
        for port in ports:
            port_type = port['type']
            width = port['width']
            direction = port['direction']
            name = prefix + port['name']
            
            # 格式化位宽
            if port['bits'] > 1:
                width_str = f"[{width}]"
                temp_line = f"{indent}{port_type:<{max_type_len}} {width_str:<{max_width_len}} {name};"
            else:
                temp_line = f"{indent}{port_type:<{max_type_len}} {' ' * max_width_len} {name};"
            
            temp_lines.append((temp_line, direction))
        
        # 计算最长的信号声明行长度
        max_line_len = max(len(line) for line, _ in temp_lines) if temp_lines else 0
        
        # 生成带对齐注释的信号声明行
        for line, direction in temp_lines:
            padding = max_line_len - len(line)
            lines.append(f"{line}{' ' * padding}  // {direction}")
        
        return '\n'.join(lines)
    
    
    
    def print_report(self):
        """Print analysis report"""
        result = self.parse_target_module()
        
        if not result:
            return
        
        print("\n" + "=" * 80)
        print(f"File: {result['filename']}")
        print(f"Module: {result['module_name']}")
        print(f"Style: {'ANSI' if result['is_ansi_style'] else 'Non-ANSI'}")
        print("=" * 80)
        
        # 打印宏定义
        if result['macros']:
            print(f"\nMacro Definitions:")
            for name, value in result['macros'].items():
                print(f"  `{name:<20} = {value}")
        
        # 打印参数定义
        if result['parameters']:
            print(f"\nParameters:")
            for name, value in result['parameters'].items():
                print(f"  {name:<20} = {value}")
        
        # 打印FLAG
        if result['defined_flags']:
            print(f"\nDefined Flags: {', '.join(result['defined_flags'])}")
        
        stats = result['statistics']
        print(f"\nStatistics:")
        print(f"  Total Ports:        {stats['total_ports']}")
        print(f"  Input Ports:        {stats['input_ports']}")
        print(f"  Output Ports:       {stats['output_ports']}")
        print(f"  Inout Ports:        {stats['inout_ports']}")
        print(f"  Total Bits:         {stats['total_bits']}")
        if stats['parameterized_ports'] > 0:
            print(f"  Unresolved Params:  {stats['parameterized_ports']}")
        
        print(f"\nPort List:")
        print(f"{'Name':<20} {'Direction':<10} {'Type':<10} {'Signed':<8} {'Width':<20} {'Bits':<6}")
        print("-" * 80)
        
        for port in result['ports']:
            signed_str = 'Yes' if port['signed'] else 'No'
            bits_str = str(port['bits']) if port['bits'] > 0 else '?'
            
            print(f"{port['name']:<20} {port['direction']:<10} {port['type']:<10} "
                  f"{signed_str:<8} {port['width']:<20} {bits_str:<6}")
        
        return result


# 便捷函数
def analyze_verilog_file(filename: str) -> Optional[Dict]:
    # 分析Verilog文件
    analyzer = VerilogPortAnalyzer(filename)
    return analyzer.parse_target_module()

def analyze_and_print(filename: str):
    """分析并打印报告"""
    analyzer = VerilogPortAnalyzer(filename)
    return analyzer.print_report()


# Usage example
if __name__ == '__main__':
    import sys
    
    # Example: analyze a Verilog file
    # Usage: python VerilogParser.py [filename] [module_name]
    
    if len(sys.argv) < 2:
        print("Usage: python VerilogParser.py <verilog_file> [module_name]")
        print("\nExample:")
        print("  python VerilogParser.py cpu.v")
        print("  python VerilogParser.py memory.v SRAM1024x32")
        sys.exit(1)
    
    filename = sys.argv[1]
    module_name = sys.argv[2] if len(sys.argv) > 2 else None
    
    # Check if file exists
    if not os.path.isfile(filename):
        print(f"Error: File '{filename}' not found")
        sys.exit(1)
    
    try:
        # Create analyzer
        analyzer = VerilogPortAnalyzer(filename, module_name)
        
        # Print analysis report
        analyzer.print_report()
        
        print("\n" + "=" * 80)
        print("Ports as List (Multi-dimensional list format):")
        print("=" * 80)
        
        # Get ports as multi-dimensional list
        ports_list = analyzer.get_port()
        print(f"Format: [port_name, direction, type, width, bits]\n")
        for port in ports_list:
            print(port)
        
        print("\n" + "=" * 80)
        print("Instance Code:")
        print("=" * 80)
        
        # Generate instance code
        instance_code = analyzer.get_inst()
        print(instance_code)
        
        print("\n" + "=" * 80)
        print("Wire Declarations:")
        print("=" * 80)
        
        # Generate wire declarations
        wire_decls = analyzer.get_wire()
        print(wire_decls)
        
    except Exception as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        sys.exit(1)