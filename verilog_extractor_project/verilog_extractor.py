import re
from typing import Dict, List, Tuple, Optional, Set
from pathlib import Path
from collections import defaultdict


class SignalConnectionGraph:
    """Analyze and visualize signal connections between module instances"""
    
    def __init__(self):
        """Initialize the signal connection graph"""
        self.connections = defaultdict(list)  # signal -> list of (instance, port) connections
        self.signal_sources = {}  # signal -> (instance, port) that drives it
        self.signal_sinks = defaultdict(list)  # signal -> list of (instance, port) that use it
        self.instances = {}  # instance_name -> module_type
    
    def add_instance(self, instance_name: str, module_type: str):
        """Add a module instance to the graph"""
        self.instances[instance_name] = module_type
    
    def add_connection(self, signal: str, instance: str, port: str, direction: str):
        """
        Add a signal connection
        
        Args:
            signal: Signal name
            instance: Instance name
            port: Port name
            direction: 'input', 'output', or 'inout'
        """
        if direction == 'output':
            self.signal_sources[signal] = (instance, port)
        elif direction == 'input':
            if signal not in self.signal_sinks:
                self.signal_sinks[signal] = []
            self.signal_sinks[signal].append((instance, port))
        
        self.connections[signal].append({
            'instance': instance,
            'port': port,
            'direction': direction
        })
    
    def get_signal_fanout(self, signal: str) -> int:
        """Get the number of inputs driven by a signal (fanout)"""
        return len(self.signal_sinks.get(signal, []))
    
    def get_signal_source(self, signal: str) -> Optional[Tuple[str, str]]:
        """Get the source (instance, port) of a signal"""
        return self.signal_sources.get(signal)
    
    def get_signal_destinations(self, signal: str) -> List[Tuple[str, str]]:
        """Get all destinations (instance, port) of a signal"""
        return self.signal_sinks.get(signal, [])
    
    def trace_signal(self, signal: str, max_depth: int = 5) -> Dict:
        """
        Trace a signal from source to destinations
        
        Args:
            signal: Signal name to trace
            max_depth: Maximum trace depth
            
        Returns:
            Dictionary containing signal path information
        """
        result = {
            'signal': signal,
            'source': self.get_signal_source(signal),
            'destinations': self.get_signal_destinations(signal),
            'fanout': self.get_signal_fanout(signal),
            'connections': self.connections.get(signal, [])
        }
        return result
    
    def get_all_signals(self) -> Set[str]:
        """Get all signals in the design"""
        return set(self.connections.keys())
    
    def print_connection_graph(self):
        """Print the signal connection graph in a formatted way"""
        print("\n" + "="*100)
        print("SIGNAL CONNECTION GRAPH")
        print("="*100)
        
        if not self.connections:
            print("No signal connections found")
            return
        
        # Print instances
        print(f"\nInstances ({len(self.instances)} total):")
        print("-"*100)
        for inst_name, module_type in sorted(self.instances.items()):
            print(f"  {inst_name:<20} : {module_type}")
        
        # Print signal connections
        print(f"\nSignal Connections ({len(self.connections)} total):")
        print("-"*100)
        
        for signal in sorted(self.connections.keys()):
            source = self.get_signal_source(signal)
            destinations = self.get_signal_destinations(signal)
            fanout = self.get_signal_fanout(signal)
            
            print(f"\n  Signal: {signal}")
            
            if source:
                src_inst, src_port = source
                print(f"    Source: {src_inst}.{src_port}")
            else:
                print(f"    Source: <undriven> or <primary input>")
            
            if destinations:
                print(f"    Fanout: {fanout} destinations")
                for dest_inst, dest_port in destinations:
                    print(f"      -> {dest_inst}.{dest_port}")
            else:
                print(f"    Fanout: 0 (unconnected or <primary output>)")
        
        print("\n" + "="*100)
    
    def generate_connection_report(self) -> str:
        """Generate a detailed connection report"""
        lines = []
        lines.append("\n" + "="*100)
        lines.append("SIGNAL CONNECTION REPORT")
        lines.append("="*100)
        
        # Summary statistics
        num_signals = len(self.connections)
        num_driven = len(self.signal_sources)
        max_fanout = max([self.get_signal_fanout(sig) for sig in self.connections], default=0)
        
        lines.append(f"\nSummary:")
        lines.append(f"  Total Signals: {num_signals}")
        lines.append(f"  Driven Signals: {num_driven}")
        lines.append(f"  Undriven Signals: {num_signals - num_driven}")
        lines.append(f"  Max Fanout: {max_fanout}")
        
        # High fanout signals
        lines.append(f"\nHigh Fanout Signals (fanout >= 3):")
        lines.append("-"*100)
        high_fanout = [(sig, self.get_signal_fanout(sig)) for sig in self.connections]
        high_fanout = sorted(high_fanout, key=lambda x: x[1], reverse=True)
        high_fanout = [x for x in high_fanout if x[1] >= 3]
        
        if high_fanout:
            for signal, fanout in high_fanout:
                print(f"  {signal:<30} : fanout = {fanout}")
                lines.append(f"  {signal:<30} : fanout = {fanout}")
        else:
            lines.append("  None")
        
        # Undriven signals
        lines.append(f"\nUndriven Signals:")
        lines.append("-"*100)
        undriven = [sig for sig in self.connections if sig not in self.signal_sources]
        if undriven:
            for signal in sorted(undriven):
                dests = self.get_signal_destinations(signal)
                lines.append(f"  {signal:<30} used by {len(dests)} instance(s)")
        else:
            lines.append("  None")
        
        lines.append("\n" + "="*100)
        return "\n".join(lines)


class VerilogExtractor:
    """Extract port declarations, module instantiations, and signal definitions from Verilog code"""
    
    def __init__(self, verilog_code: str):
        """
        Initialize VerilogExtractor
        
        Args:
            verilog_code: Verilog source code as string
        """
        self.code = verilog_code
        self.clean_code = self._remove_comments(verilog_code)
    
    def _remove_comments(self, code: str) -> str:
        """Remove single-line and multi-line comments from Verilog code"""
        # Remove multi-line comments /* ... */
        code = re.sub(r'/\*.*?\*/', '', code, flags=re.DOTALL)
        # Remove single-line comments //
        code = re.sub(r'//.*?$', '', code, flags=re.MULTILINE)
        return code
    
    def extract_module_ports(self) -> Dict[str, List[Dict]]:
        """
        Extract module port declarations
        
        Supports both Verilog95 and SystemVerilog2018 styles
        
        Returns:
            Dictionary with module name and list of ports with their types
            Example: {
                'module_name': 'ram_controller',
                'ports': [
                    {'name': 'clk', 'type': 'input', 'data_type': 'logic', 'width': '1'},
                    {'name': 'addr', 'type': 'input', 'data_type': 'wire', 'width': '[15:0]'},
                    {'name': 'data_out', 'type': 'output', 'data_type': 'logic', 'width': '[31:0]'}
                ]
            }
        """
        result = {'module_name': '', 'ports': []}
        
        # Find module declaration
        module_match = re.search(r'module\s+(\w+)\s*\((.*?)\);', self.clean_code, re.DOTALL)
        if not module_match:
            return result
        
        result['module_name'] = module_match.group(1)
        ports_str = module_match.group(2)
        
        # Parse port declarations
        # Supports Verilog95 and SystemVerilog2018 formats:
        # - input clk                          (V95: no type, implicit wire)
        # - input wire [7:0] data              (V95: explicit wire)
        # - input logic [7:0] data             (SV: logic type)
        # - output reg [31:0] data_out         (V95/SV: reg type)
        # - inout bit [15:0] bus               (SV: bit type)
        port_pattern = r'(input|output|inout)\s+(wire|reg|logic|bit|int|real|string)?\s*(\[[^\]]+\])?\s*(\w+)\s*(?:,|;)'
        
        for match in re.finditer(port_pattern, ports_str):
            port_type = match.group(1)
            data_type = match.group(2)
            width = match.group(3) or '1'
            port_name = match.group(4)
            
            # Determine default data type based on Verilog95 rules if not specified
            if not data_type:
                if port_type == 'input':
                    data_type = 'wire'
                elif port_type == 'output':
                    data_type = 'wire'
                else:  # inout
                    data_type = 'wire'
            
            result['ports'].append({
                'name': port_name,
                'type': port_type,
                'data_type': data_type,
                'width': width
            })
        
        return result
    
    def extract_module_instantiations(self) -> List[Dict]:
        """
        Extract all module instantiations
        
        Returns:
            List of instantiated modules with their connection information
            Example: [
                {
                    'module_type': 'ram_controller',
                    'instance_name': 'u0_ram',
                    'port_connections': {
                        'clk': 'sys_clk',
                        'addr': 'address[15:0]',
                        'data_out': 'data_bus'
                    }
                }
            ]
        """
        instantiations = []
        
        # Pattern to match module instantiation: module_name instance_name ( ... );
        # This is more permissive to handle various coding styles
        inst_pattern = r'(\w+)\s+(\w+)\s*\((.*?)\)\s*;'
        
        for match in re.finditer(inst_pattern, self.clean_code, re.DOTALL):
            module_type = match.group(1)
            instance_name = match.group(2)
            connections_str = match.group(3)
            
            # Skip if this looks like a module or endmodule declaration
            if module_type in ['module', 'endmodule', 'if', 'for', 'while', 'case']:
                continue
            
            # Parse port connections
            port_connections = {}
            
            # Handle both named (.port(signal)) and positional connections
            named_conn_pattern = r'\.(\w+)\s*\(\s*([^)]+)\s*\)'
            for conn_match in re.finditer(named_conn_pattern, connections_str):
                port_name = conn_match.group(1)
                signal_name = conn_match.group(2).strip()
                port_connections[port_name] = signal_name
            
            instantiations.append({
                'module_type': module_type,
                'instance_name': instance_name,
                'port_connections': port_connections
            })
        
        return instantiations
    
    def extract_signal_definitions(self) -> Dict[str, List[Dict]]:
        """
        Extract signal definitions (wire, reg, logic, etc.)
        
        Supports both Verilog95 and SystemVerilog2018 signal types
        
        Returns:
            Dictionary with signal categories and their properties
            Example: {
                'wires': [
                    {'name': 'clk', 'width': '[31:0]', 'data_type': 'wire'},
                    {'name': 'reset', 'width': '1', 'data_type': 'wire'}
                ],
                'regs': [
                    {'name': 'counter', 'width': '[7:0]', 'data_type': 'reg'}
                ],
                'logic': [
                    {'name': 'data_bus', 'width': '[31:0]', 'data_type': 'logic'}
                ],
                'parameters': [
                    {'name': 'DATA_WIDTH', 'value': '32'}
                ]
            }
        """
        signals = {
            'wires': [],
            'regs': [],
            'logic': [],
            'bit': [],
            'int': [],
            'real': [],
            'string': [],
            'parameters': [],
            'localparam': []
        }
        
        # Extract wire declarations (Verilog95/SV)
        wire_pattern = r'wire\s*(\[[^\]]+\])?\s*(\w+(?:\s*,\s*\w+)*)\s*;'
        for match in re.finditer(wire_pattern, self.clean_code):
            width = match.group(1) or '1'
            names = match.group(2)
            for name in [n.strip() for n in names.split(',')]:
                signals['wires'].append({
                    'name': name,
                    'width': width,
                    'data_type': 'wire'
                })
        
        # Extract reg declarations (Verilog95/SV)
        reg_pattern = r'reg\s*(\[[^\]]+\])?\s*(\w+(?:\s*,\s*\w+)*)\s*;'
        for match in re.finditer(reg_pattern, self.clean_code):
            width = match.group(1) or '1'
            names = match.group(2)
            for name in [n.strip() for n in names.split(',')]:
                signals['regs'].append({
                    'name': name,
                    'width': width,
                    'data_type': 'reg'
                })
        
        # Extract logic declarations (SystemVerilog)
        logic_pattern = r'logic\s*(\[[^\]]+\])?\s*(\w+(?:\s*,\s*\w+)*)\s*;'
        for match in re.finditer(logic_pattern, self.clean_code):
            width = match.group(1) or '1'
            names = match.group(2)
            for name in [n.strip() for n in names.split(',')]:
                signals['logic'].append({
                    'name': name,
                    'width': width,
                    'data_type': 'logic'
                })
        
        # Extract bit declarations (SystemVerilog)
        bit_pattern = r'bit\s*(\[[^\]]+\])?\s*(\w+(?:\s*,\s*\w+)*)\s*;'
        for match in re.finditer(bit_pattern, self.clean_code):
            width = match.group(1) or '1'
            names = match.group(2)
            for name in [n.strip() for n in names.split(',')]:
                signals['bit'].append({
                    'name': name,
                    'width': width,
                    'data_type': 'bit'
                })
        
        # Extract int declarations (SystemVerilog)
        int_pattern = r'int\s*(\[[^\]]+\])?\s*(\w+(?:\s*,\s*\w+)*)\s*;'
        for match in re.finditer(int_pattern, self.clean_code):
            width = match.group(1) or '32'
            names = match.group(2)
            for name in [n.strip() for n in names.split(',')]:
                signals['int'].append({
                    'name': name,
                    'width': width,
                    'data_type': 'int'
                })
        
        # Extract real declarations (SystemVerilog)
        real_pattern = r'real\s+(\w+(?:\s*,\s*\w+)*)\s*;'
        for match in re.finditer(real_pattern, self.clean_code):
            names = match.group(1)
            for name in [n.strip() for n in names.split(',')]:
                signals['real'].append({
                    'name': name,
                    'width': 'real',
                    'data_type': 'real'
                })
        
        # Extract string declarations (SystemVerilog)
        string_pattern = r'string\s+(\w+(?:\s*,\s*\w+)*)\s*;'
        for match in re.finditer(string_pattern, self.clean_code):
            names = match.group(1)
            for name in [n.strip() for n in names.split(',')]:
                signals['string'].append({
                    'name': name,
                    'width': 'string',
                    'data_type': 'string'
                })
        
        # Extract parameter declarations (Verilog95/SV)
        param_pattern = r'parameter\s+(\w+)\s*=\s*([^;]+)\s*;'
        for match in re.finditer(param_pattern, self.clean_code):
            name = match.group(1)
            value = match.group(2).strip()
            signals['parameters'].append({
                'name': name,
                'value': value
            })
        
        # Extract localparam declarations (Verilog95/SV)
        localparam_pattern = r'localparam\s+(\w+)\s*=\s*([^;]+)\s*;'
        for match in re.finditer(localparam_pattern, self.clean_code):
            name = match.group(1)
            value = match.group(2).strip()
            signals['localparam'].append({
                'name': name,
                'value': value
            })
        
        # Filter out empty categories
        return {k: v for k, v in signals.items() if v}
    
    def build_signal_connection_graph(self) -> SignalConnectionGraph:
        """
        Build a signal connection graph from module instantiations
        
        Returns:
            SignalConnectionGraph object with all signal connections
        """
        graph = SignalConnectionGraph()
        
        # Get module ports to understand port directions
        module_ports = self.extract_module_ports()
        port_directions = {}
        for port in module_ports.get('ports', []):
            port_directions[port['name']] = port['type']
        
        # Get instantiations
        instantiations = self.extract_module_instantiations()
        
        for inst in instantiations:
            instance_name = inst['instance_name']
            module_type = inst['module_type']
            port_connections = inst['port_connections']
            
            # Add instance to graph
            graph.add_instance(instance_name, module_type)
            
            # Add connections
            for port, signal in port_connections.items():
                # Determine direction (input/output/inout)
                # For now, we'll mark them, but ideally we'd look up the module definition
                direction = 'unknown'
                if port in port_directions:
                    direction = port_directions[port]
                
                graph.add_connection(signal, instance_name, port, direction)
        
        return graph
    
    def extract_all(self) -> Dict:
        """Extract all information at once"""
        return {
            'module_ports': self.extract_module_ports(),
            'instantiations': self.extract_module_instantiations(),
            'signal_definitions': self.extract_signal_definitions()
        }
    
    def print_report(self):
        """Print formatted extraction report"""
        print("\n" + "="*80)
        print("VERILOG MODULE EXTRACTION REPORT")
        print("="*80)
        
        # Module Ports
        print("\n[1] MODULE PORTS")
        print("-"*80)
        module_ports = self.extract_module_ports()
        if module_ports['module_name']:
            print(f"Module Name: {module_ports['module_name']}")
            print(f"\nPorts ({len(module_ports['ports'])} total):")
            for port in module_ports['ports']:
                print(f"  {port['type']:<7} {port['data_type']:<6} {port['width']:<12} {port['name']}")
        else:
            print("No module declarations found")
        
        # Instantiations
        print("\n[2] MODULE INSTANTIATIONS")
        print("-"*80)
        instantiations = self.extract_module_instantiations()
        if instantiations:
            print(f"Total Instantiations: {len(instantiations)}\n")
            for inst in instantiations:
                print(f"  Module Type: {inst['module_type']}")
                print(f"  Instance Name: {inst['instance_name']}")
                print(f"  Port Connections:")
                for port, signal in inst['port_connections'].items():
                    print(f"    .{port}({signal})")
                print()
        else:
            print("No module instantiations found")
        
        # Signal Definitions
        print("\n[3] SIGNAL DEFINITIONS")
        print("-"*80)
        signals = self.extract_signal_definitions()
        
        # Verilog95 signals
        if 'wires' in signals and signals['wires']:
            print(f"Wires ({len(signals['wires'])} total):")
            for wire in signals['wires']:
                print(f"  wire {wire['width']:<12} {wire['name']}")
        
        if 'regs' in signals and signals['regs']:
            print(f"\nRegs ({len(signals['regs'])} total):")
            for reg in signals['regs']:
                print(f"  reg  {reg['width']:<12} {reg['name']}")
        
        # SystemVerilog signals
        if 'logic' in signals and signals['logic']:
            print(f"\nLogic ({len(signals['logic'])} total):")
            for sig in signals['logic']:
                print(f"  logic {sig['width']:<12} {sig['name']}")
        
        if 'bit' in signals and signals['bit']:
            print(f"\nBit ({len(signals['bit'])} total):")
            for sig in signals['bit']:
                print(f"  bit  {sig['width']:<12} {sig['name']}")
        
        if 'int' in signals and signals['int']:
            print(f"\nInt ({len(signals['int'])} total):")
            for sig in signals['int']:
                print(f"  int  {sig['width']:<12} {sig['name']}")
        
        if 'real' in signals and signals['real']:
            print(f"\nReal ({len(signals['real'])} total):")
            for sig in signals['real']:
                print(f"  real {sig['width']:<12} {sig['name']}")
        
        if 'string' in signals and signals['string']:
            print(f"\nString ({len(signals['string'])} total):")
            for sig in signals['string']:
                print(f"  string {sig['width']:<12} {sig['name']}")
        
        if 'parameters' in signals and signals['parameters']:
            print(f"\nParameters ({len(signals['parameters'])} total):")
            for param in signals['parameters']:
                print(f"  parameter {param['name']:<20} = {param['value']}")
        
        if 'localparam' in signals and signals['localparam']:
            print(f"\nLocalparams ({len(signals['localparam'])} total):")
            for lp in signals['localparam']:
                print(f"  localparam {lp['name']:<20} = {lp['value']}")
        
        print("\n" + "="*80)
    
    def print_connection_graph(self):
        """Print signal connection graph"""
        graph = self.build_signal_connection_graph()
        graph.print_connection_graph()
        print(graph.generate_connection_report())


def extract_from_file(file_path: str) -> Dict:
    """Convenience function to extract from a Verilog file"""
    with open(file_path, 'r', encoding='utf-8') as f:
        code = f.read()
    
    extractor = VerilogExtractor(code)
    return extractor.extract_all()


# Example usage
if __name__ == '__main__':
    # Example Verilog code - Verilog95 style
    example_verilog = """
    // RAM Controller Module - Verilog95 Style
    module ram_controller_v95 (
        input clk,
        input reset,
        input [15:0] addr,
        input [31:0] data_in,
        output reg [31:0] data_out,
        output ready
    );
    
    // Verilog95 signal definitions
    wire sys_clk;
    reg [7:0] counter;
    wire [15:0] addr_aligned;
    
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 16;
    localparam MAX_DEPTH = 65536;
    
    // Module instantiations
    memory_bank u0_mem (
        .clk(sys_clk),
        .addr(addr_aligned),
        .data_in(data_in),
        .data_out(data_out),
        .we(write_enable)
    );
    
    endmodule
    
    // RAM Controller Module - SystemVerilog2018 Style
    module ram_controller_sv (
        input logic clk,
        input logic reset,
        input logic [15:0] addr,
        input logic [31:0] data_in,
        output logic [31:0] data_out,
        output logic ready
    );
    
    // SystemVerilog2018 signal definitions
    logic sys_clk;
    logic [7:0] counter;
    logic [15:0] addr_aligned;
    bit [31:0] status_bits;
    int cycle_count;
    real delay_time;
    string error_msg;
    
    parameter int DATA_WIDTH = 32;
    parameter int ADDR_WIDTH = 16;
    localparam int MAX_DEPTH = 65536;
    
    // Module instantiations
    memory_bank u0_mem (
        .clk(sys_clk),
        .addr(addr_aligned),
        .data_in(data_in),
        .data_out(data_out),
        .we(write_enable)
    );
    
    endmodule
    """
    
    # Test extraction
    extractor = VerilogExtractor(example_verilog)
    extractor.print_report()
    
    # Get data in dictionary format
    results = extractor.extract_all()
    print("\nJSON-like results:")
    module_info = results['module_ports']
    if module_info['module_name']:
        print(f"Module: {module_info['module_name']}")
        print(f"Ports found: {len(module_info['ports'])}")
    signals_info = results['signal_definitions']
    print(f"Instantiations: {len(results['instantiations'])}")
    total_signals = sum(len(v) for k, v in signals_info.items() if k not in ['parameters', 'localparam'])
    print(f"Total Signals: {total_signals}")
    print(f"Parameters: {len(signals_info.get('parameters', []))}")
    print(f"Localparams: {len(signals_info.get('localparam', []))}")
