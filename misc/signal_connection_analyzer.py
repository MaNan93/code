#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
信号与模块实例连接分析工具
Signal and Module Instance Connection Analyzer

分析 Verilog 设计中所有信号与模块实例之间的连接关系。
Analyzes all signal and module instance connections in a Verilog design.
"""

import re
from typing import Dict, List, Tuple, Optional, Set
from pathlib import Path
from collections import defaultdict
import json


class SignalModuleAnalyzer:
    """分析信号与模块实例的连接关系"""
    
    def __init__(self):
        """初始化分析器"""
        self.modules = {}  # module_name -> module_info
        self.instances = {}  # instance_name -> {module_type, ports}
        self.signals = {}  # signal_name -> signal_info
        self.connections = defaultdict(list)  # signal -> [(instance, port, direction)]
        self.hierarchies = defaultdict(list)  # parent_module -> [child_instances]
        
    def analyze_verilog(self, verilog_code: str):
        """从Verilog代码分析连接关系"""
        self._extract_modules(verilog_code)
        self._extract_instances(verilog_code)
        self._extract_signals(verilog_code)
        self._extract_connections(verilog_code)
    
    def analyze_file(self, file_path: str):
        """从Verilog文件分析连接关系"""
        with open(file_path, 'r', encoding='utf-8') as f:
            verilog_code = f.read()
        self.analyze_verilog(verilog_code)
    
    def _extract_modules(self, code: str):
        """提取所有模块定义"""
        # 匹配 module xxx (...) ... endmodule
        module_pattern = r'module\s+(\w+)\s*\((.*?)\)\s*;(.*?)endmodule'
        
        for match in re.finditer(module_pattern, code, re.DOTALL):
            module_name = match.group(1)
            port_list = match.group(2)
            module_body = match.group(3)
            
            self.modules[module_name] = {
                'ports': self._parse_ports(port_list),
                'body': module_body,
                'parameters': self._extract_parameters(module_body)
            }
    
    def _extract_instances(self, code: str):
        """提取所有模块实例"""
        # 匹配 module_type instance_name (...);
        instance_pattern = r'(\w+)\s+(\w+)\s*\((.*?)\)\s*;'
        
        # 排除 module 声明本身
        code_without_module_def = re.sub(r'module\s+\w+\s*\(.*?\);', '', code)
        
        for match in re.finditer(instance_pattern, code_without_module_def, re.DOTALL):
            module_type = match.group(1)
            instance_name = match.group(2)
            port_connections = match.group(3)
            
            if module_type not in ['input', 'output', 'inout', 'wire', 'reg', 'logic']:
                self.instances[instance_name] = {
                    'module_type': module_type,
                    'port_connections': self._parse_port_connections(port_connections)
                }
    
    def _extract_signals(self, code: str):
        """提取所有信号定义"""
        # 提取 input/output/inout 声明
        port_pattern = r'(input|output|inout)\s+(?:reg\s+)?(?:wire\s+)?(?:\[\s*\d+\s*:\s*\d+\s*\])?\s*(\w+)'
        
        for match in re.finditer(port_pattern, code):
            direction = match.group(1)
            signal_name = match.group(2)
            self.signals[signal_name] = {
                'direction': direction,
                'type': 'port'
            }
        
        # 提取 wire/reg 声明
        signal_pattern = r'(wire|reg|logic)\s+(?:\[\s*\d+\s*:\s*\d+\s*\])?\s*(\w+)'
        
        for match in re.finditer(signal_pattern, code):
            signal_type = match.group(1)
            signal_name = match.group(2)
            if signal_name not in self.signals:
                self.signals[signal_name] = {
                    'type': signal_type,
                    'direction': 'internal'
                }
    
    def _extract_connections(self, code: str):
        """提取信号与模块实例的连接关系"""
        for instance_name, instance_info in self.instances.items():
            module_type = instance_info['module_type']
            port_connections = instance_info['port_connections']
            
            for port_name, signal_name in port_connections.items():
                # 确定端口方向（需要查看模块定义）
                direction = self._get_port_direction(module_type, port_name)
                
                connection = {
                    'instance': instance_name,
                    'module_type': module_type,
                    'port': port_name,
                    'direction': direction
                }
                self.connections[signal_name].append(connection)
    
    def _parse_ports(self, port_list: str) -> Dict[str, str]:
        """解析端口列表"""
        ports = {}
        if not port_list.strip():
            return ports
        
        # 简单解析：port_name : direction
        port_pattern = r'(\w+)\s*:\s*(input|output|inout)'
        
        for match in re.finditer(port_pattern, port_list):
            port_name = match.group(1)
            direction = match.group(2)
            ports[port_name] = direction
        
        return ports
    
    def _parse_port_connections(self, connections_str: str) -> Dict[str, str]:
        """解析端口连接"""
        connections = {}
        if not connections_str.strip():
            return connections
        
        # 匹配 .port_name(signal_name) 或 .port_name(signal_name[bit])
        connection_pattern = r'\.(\w+)\s*\(\s*(\w+)\s*(?:\[.*?\])?\s*\)'
        
        for match in re.finditer(connection_pattern, connections_str):
            port_name = match.group(1)
            signal_name = match.group(2)
            connections[port_name] = signal_name
        
        return connections
    
    def _get_port_direction(self, module_type: str, port_name: str) -> str:
        """获取端口方向"""
        if module_type in self.modules:
            ports = self.modules[module_type].get('ports', {})
            return ports.get(port_name, 'unknown')
        return 'unknown'
    
    def _extract_parameters(self, module_body: str) -> Dict[str, str]:
        """提取参数定义"""
        parameters = {}
        param_pattern = r'parameter\s+(?:\w+\s+)?(\w+)\s*=\s*([^,;]+)'
        
        for match in re.finditer(param_pattern, module_body):
            param_name = match.group(1)
            param_value = match.group(2).strip()
            parameters[param_name] = param_value
        
        return parameters
    
    # ==================== 分析方法 ====================
    
    def get_signal_connections(self, signal_name: str) -> Dict:
        """获取信号的所有连接信息"""
        connections = self.connections.get(signal_name, [])
        return {
            'signal': signal_name,
            'signal_info': self.signals.get(signal_name, {}),
            'connections': connections,
            'fanout': len([c for c in connections if c['direction'] == 'input']),
            'fanin': len([c for c in connections if c['direction'] == 'output']),
            'total_connections': len(connections)
        }
    
    def get_instance_connections(self, instance_name: str) -> Dict:
        """获取模块实例的所有连接信息"""
        if instance_name not in self.instances:
            return {'error': f'Instance {instance_name} not found'}
        
        instance_info = self.instances[instance_name]
        port_connections = instance_info['port_connections']
        
        connections = []
        for port_name, signal_name in port_connections.items():
            direction = self._get_port_direction(instance_info['module_type'], port_name)
            connections.append({
                'port': port_name,
                'signal': signal_name,
                'direction': direction
            })
        
        return {
            'instance': instance_name,
            'module_type': instance_info['module_type'],
            'ports': connections,
            'total_ports': len(connections)
        }
    
    def get_high_fanout_signals(self, threshold: int = 2) -> List[Dict]:
        """获取高扇出信号（扇出数大于阈值）"""
        high_fanout = []
        
        for signal_name, connections in self.connections.items():
            fanout = len([c for c in connections if c['direction'] == 'input'])
            if fanout >= threshold:
                high_fanout.append({
                    'signal': signal_name,
                    'fanout': fanout,
                    'connections': connections
                })
        
        return sorted(high_fanout, key=lambda x: x['fanout'], reverse=True)
    
    def get_unconnected_signals(self) -> List[str]:
        """获取未连接的信号"""
        unconnected = []
        for signal_name in self.signals.keys():
            if signal_name not in self.connections:
                unconnected.append(signal_name)
        return unconnected
    
    def get_module_hierarchy(self) -> Dict:
        """获取模块层次结构"""
        hierarchy = {}
        
        # 构建实例与模块的映射
        for instance_name, instance_info in self.instances.items():
            module_type = instance_info['module_type']
            if module_type not in hierarchy:
                hierarchy[module_type] = {
                    'instances': [],
                    'port_count': len(self.modules.get(module_type, {}).get('ports', {}))
                }
            hierarchy[module_type]['instances'].append(instance_name)
        
        return hierarchy
    
    def get_signal_path(self, signal_name: str) -> Dict:
        """追踪信号的路径"""
        connections = self.connections.get(signal_name, [])
        
        sources = [c for c in connections if c['direction'] == 'output']
        sinks = [c for c in connections if c['direction'] == 'input']
        
        return {
            'signal': signal_name,
            'sources': sources,
            'sinks': sinks,
            'path_exists': len(sources) > 0 and len(sinks) > 0
        }
    
    def get_connectivity_summary(self) -> Dict:
        """获取连接性摘要"""
        return {
            'total_signals': len(self.signals),
            'total_instances': len(self.instances),
            'total_modules': len(self.modules),
            'total_connections': sum(len(c) for c in self.connections.values()),
            'unconnected_signals': len(self.get_unconnected_signals()),
            'high_fanout_signals': len(self.get_high_fanout_signals(threshold=3))
        }
    
    # ==================== 输出方法 ====================
    
    def print_connectivity_report(self):
        """打印连接性报告"""
        summary = self.get_connectivity_summary()
        
        print("\n" + "="*80)
        print("信号与模块实例连接分析报告")
        print("Signal and Module Instance Connection Analysis Report")
        print("="*80)
        
        print("\n【连接性摘要】 Connectivity Summary:")
        print("-"*80)
        print(f"  总信号数              : {summary['total_signals']}")
        print(f"  总模块实例数          : {summary['total_instances']}")
        print(f"  总模块定义数          : {summary['total_modules']}")
        print(f"  总连接数              : {summary['total_connections']}")
        print(f"  未连接信号数          : {summary['unconnected_signals']}")
        print(f"  高扇出信号数(>=3)     : {summary['high_fanout_signals']}")
        
        # 信号连接详情
        print("\n【信号连接详情】 Signal Connection Details:")
        print("-"*80)
        for signal_name in sorted(self.connections.keys()):
            signal_info = self.get_signal_connections(signal_name)
            print(f"\n  信号: {signal_name}")
            print(f"    扇入(源)  : {signal_info['fanin']}")
            print(f"    扇出(汇)  : {signal_info['fanout']}")
            
            for conn in signal_info['connections']:
                direction_str = f"[{conn['direction'].upper()}]"
                print(f"      {direction_str} {conn['instance']}.{conn['port']}")
        
        # 模块实例连接详情
        print("\n【模块实例连接详情】 Instance Connection Details:")
        print("-"*80)
        for instance_name in sorted(self.instances.keys()):
            instance_info = self.get_instance_connections(instance_name)
            print(f"\n  实例: {instance_name} (模块类型: {instance_info['module_type']})")
            for port_info in instance_info['ports']:
                direction_str = f"[{port_info['direction'].upper()}]"
                print(f"    {direction_str} {port_info['port']:20} <- {port_info['signal']}")
        
        # 高扇出信号
        high_fanout = self.get_high_fanout_signals(threshold=2)
        if high_fanout:
            print("\n【高扇出信号】 High Fanout Signals (扇出 >= 2):")
            print("-"*80)
            for item in high_fanout:
                print(f"\n  信号: {item['signal']} (扇出: {item['fanout']})")
                for conn in item['connections']:
                    if conn['direction'] == 'input':
                        print(f"    -> {conn['instance']}.{conn['port']}")
        
        # 未连接信号
        unconnected = self.get_unconnected_signals()
        if unconnected:
            print("\n【未连接信号】 Unconnected Signals:")
            print("-"*80)
            for signal in sorted(unconnected):
                print(f"  {signal}")
        
        print("\n" + "="*80 + "\n")
    
    def print_instance_detail(self, instance_name: str):
        """打印模块实例的详细信息"""
        instance_info = self.get_instance_connections(instance_name)
        
        if 'error' in instance_info:
            print(f"错误: {instance_info['error']}")
            return
        
        print("\n" + "="*80)
        print(f"模块实例详情 - {instance_name}")
        print("="*80)
        
        print(f"\n实例名称: {instance_name}")
        print(f"模块类型: {instance_info['module_type']}")
        print(f"端口数:   {instance_info['total_ports']}")
        
        print("\n端口连接:")
        print("-"*80)
        for port in instance_info['ports']:
            direction = port['direction'].upper()
            print(f"  [{direction:6}] {port['port']:20} <- {port['signal']}")
        
        print("\n" + "="*80 + "\n")
    
    def print_signal_detail(self, signal_name: str):
        """打印信号的详细信息"""
        signal_info = self.get_signal_connections(signal_name)
        path_info = self.get_signal_path(signal_name)
        
        print("\n" + "="*80)
        print(f"信号详情 - {signal_name}")
        print("="*80)
        
        print(f"\n信号名称: {signal_name}")
        print(f"信号类型: {signal_info['signal_info'].get('type', 'unknown')}")
        print(f"方向:    {signal_info['signal_info'].get('direction', 'unknown')}")
        print(f"扇入:    {signal_info['fanin']} (源)")
        print(f"扇出:    {signal_info['fanout']} (汇)")
        
        print("\n信号路径:")
        print("-"*80)
        if path_info['sources']:
            print("  源 (Source):")
            for source in path_info['sources']:
                print(f"    {source['module_type']}.{source['instance']}.{source['port']}")
        else:
            print("  源 (Source): [无]")
        
        if path_info['sinks']:
            print("  汇 (Sink):")
            for sink in path_info['sinks']:
                print(f"    {sink['module_type']}.{sink['instance']}.{sink['port']}")
        else:
            print("  汇 (Sink): [无]")
        
        print("\n" + "="*80 + "\n")
    
    def export_to_json(self, output_file: str):
        """导出连接分析结果为JSON"""
        export_data = {
            'connectivity_summary': self.get_connectivity_summary(),
            'modules': self.modules,
            'instances': self.instances,
            'signals': self.signals,
            'connections': dict(self.connections),
            'high_fanout_signals': self.get_high_fanout_signals(threshold=2),
            'unconnected_signals': self.get_unconnected_signals(),
            'module_hierarchy': self.get_module_hierarchy()
        }
        
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(export_data, f, indent=2, ensure_ascii=False)
        
        print(f"✓ 分析结果已导出到: {output_file}")


if __name__ == '__main__':
    # 示例用法
    sample_code = """
    module top (
        input clk,
        input reset,
        output done
    );
        wire counter_out;
        wire compare_result;
        
        counter counter_inst (
            .clk(clk),
            .reset(reset),
            .count_out(counter_out)
        );
        
        comparator compare_inst (
            .data_in(counter_out),
            .threshold(8'h10),
            .match(compare_result)
        );
        
        output_driver out_inst (
            .signal_in(compare_result),
            .data_out(done)
        );
    endmodule
    
    module counter (
        input clk,
        input reset,
        output reg [7:0] count_out
    );
    endmodule
    
    module comparator (
        input [7:0] data_in,
        input [7:0] threshold,
        output match
    );
    endmodule
    
    module output_driver (
        input signal_in,
        output data_out
    );
    endmodule
    """
    
    # 创建分析器并分析代码
    analyzer = SignalModuleAnalyzer()
    analyzer.analyze_verilog(sample_code)
    
    # 打印报告
    analyzer.print_connectivity_report()
    
    # 打印具体实例信息
    print("\n" + "="*80)
    print("模块实例详情示例")
    print("="*80)
    analyzer.print_instance_detail('counter_inst')
    analyzer.print_instance_detail('compare_inst')
    
    # 打印具体信号信息
    analyzer.print_signal_detail('counter_out')
    analyzer.print_signal_detail('compare_result')
    
    # 导出为JSON
    analyzer.export_to_json('connection_analysis.json')
