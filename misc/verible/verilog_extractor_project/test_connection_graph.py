"""Test script for Signal Connection Graph functionality"""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from verilog_extractor import VerilogExtractor, SignalConnectionGraph

def test_simple_connection():
    """Test simple signal connections"""
    print("\n" + "="*100)
    print("Test 1: Simple Signal Connections")
    print("="*100)
    
    code = """
    module top_module (
        input clk,
        input reset,
        input [7:0] data_in,
        output [7:0] data_out
    );
    
        wire [7:0] stage1_out;
        wire [7:0] stage2_out;
        
        // Stage 1: input processing
        processing_stage u0 (
            .clk(clk),
            .reset(reset),
            .data_in(data_in),
            .data_out(stage1_out)
        );
        
        // Stage 2: data manipulation
        manipulator u1 (
            .clk(clk),
            .data_in(stage1_out),
            .data_out(stage2_out)
        );
        
        // Stage 3: output buffering
        buffer_stage u2 (
            .clk(clk),
            .data_in(stage2_out),
            .data_out(data_out)
        );
        
    endmodule
    """
    
    extractor = VerilogExtractor(code)
    extractor.print_connection_graph()

def test_complex_connections():
    """Test complex signal connections with multiple fanouts"""
    print("\n" + "="*100)
    print("Test 2: Complex Signal Connections (Multiple Fanouts)")
    print("="*100)
    
    code = """
    module complex_design (
        input clk,
        input reset,
        input [31:0] input_data,
        output [31:0] output_result
    );
    
        wire [31:0] shared_signal;
        wire [15:0] ctrl_signal;
        
        // Source: input controller
        input_ctrl u0 (
            .clk(clk),
            .data(input_data),
            .shared_sig(shared_signal),
            .ctrl_sig(ctrl_signal)
        );
        
        // Destination 1: Processing unit A
        proc_unit_a u1 (
            .clk(clk),
            .data_in(shared_signal),
            .ctrl(ctrl_signal),
            .data_out(proc_a_out)
        );
        
        // Destination 2: Processing unit B
        proc_unit_b u2 (
            .clk(clk),
            .data_in(shared_signal),
            .ctrl(ctrl_signal),
            .valid(valid_sig)
        );
        
        // Destination 3: Monitoring unit
        monitor u3 (
            .clk(clk),
            .data(shared_signal),
            .ctrl(ctrl_signal)
        );
        
        // Output driver
        output_mux u4 (
            .data_a(proc_a_out),
            .data_b(proc_b_out),
            .sel(sel_sig),
            .output_data(output_result)
        );
        
    endmodule
    """
    
    extractor = VerilogExtractor(code)
    extractor.print_connection_graph()

def test_trace_signal():
    """Test signal tracing functionality"""
    print("\n" + "="*100)
    print("Test 3: Signal Trace Analysis")
    print("="*100)
    
    code = """
    module trace_example (
        input clk,
        input [15:0] addr,
        output [31:0] data
    );
    
        wire [15:0] addr_decoded;
        wire [31:0] read_data;
        wire read_valid;
        
        address_decoder dec0 (
            .addr_in(addr),
            .addr_out(addr_decoded)
        );
        
        memory mem0 (
            .addr(addr_decoded),
            .data_out(read_data),
            .valid(read_valid)
        );
        
        output_reg out0 (
            .data_in(read_data),
            .valid(read_valid),
            .data_out(data)
        );
        
    endmodule
    """
    
    extractor = VerilogExtractor(code)
    graph = extractor.build_signal_connection_graph()
    
    print("\nSignal Instances and Module Types:")
    print("-"*100)
    for inst, module_type in sorted(graph.instances.items()):
        print(f"  {inst:<20} -> {module_type}")
    
    print("\nAll Signals in Design:")
    print("-"*100)
    all_signals = sorted(graph.get_all_signals())
    for sig in all_signals:
        trace = graph.trace_signal(sig)
        print(f"\n  Signal: {sig}")
        if trace['source']:
            print(f"    Source: {trace['source'][0]}.{trace['source'][1]}")
        else:
            print(f"    Source: <primary input or undriven>")
        print(f"    Fanout: {trace['fanout']}")
        for dest in trace['destinations']:
            print(f"      -> {dest[0]}.{dest[1]}")

def test_undriven_signals():
    """Test detection of undriven signals"""
    print("\n" + "="*100)
    print("Test 4: Undriven Signals Detection")
    print("="*100)
    
    code = """
    module design_with_issues (
        input clk,
        output result
    );
    
        wire internal_sig;
        wire external_sig;
        wire floating_sig;
        
        source_module src (
            .clk(clk),
            .out(internal_sig)
        );
        
        sink_module sink (
            .clk(clk),
            .data_a(internal_sig),
            .data_b(external_sig),
            .result(result)
        );
        
    endmodule
    """
    
    extractor = VerilogExtractor(code)
    graph = extractor.build_signal_connection_graph()
    graph.print_connection_graph()

if __name__ == '__main__':
    print("\n" + "="*100)
    print("SIGNAL CONNECTION GRAPH - COMPREHENSIVE TESTS")
    print("="*100)
    
    test_simple_connection()
    test_complex_connections()
    test_trace_signal()
    test_undriven_signals()
    
    print("\n" + "="*100)
    print("All connection graph tests completed!")
    print("="*100 + "\n")
