"""
Enhanced test for Signal Connection Graph with better examples

This demonstrates the signal connection relationship extraction capabilities
"""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from verilog_extractor import VerilogExtractor

def test_pipeline_design():
    """Test a realistic pipeline design with signal flow"""
    print("\n" + "="*100)
    print("Test: Data Pipeline Design - Signal Flow Analysis")
    print("="*100)
    
    code = """
    module data_pipeline (
        input clk,
        input rst_n,
        input [15:0] input_data,
        output [31:0] output_data
    );
    
        // Internal signals
        wire [15:0] stage1_data;
        wire [15:0] stage1_valid;
        wire [23:0] stage2_data;
        wire stage2_valid;
        wire [31:0] stage3_data;
        wire stage3_valid;
        
        // Stage 1: Data preprocessing
        preprocessor u_stage1 (
            .clk(clk),
            .rst_n(rst_n),
            .data_in(input_data),
            .valid_in(input_valid),
            .data_out(stage1_data),
            .valid_out(stage1_valid)
        );
        
        // Stage 2: Main processing
        processor u_stage2 (
            .clk(clk),
            .rst_n(rst_n),
            .data_in(stage1_data),
            .valid_in(stage1_valid),
            .data_out(stage2_data),
            .valid_out(stage2_valid)
        );
        
        // Stage 3: Output formatting
        formatter u_stage3 (
            .clk(clk),
            .rst_n(rst_n),
            .data_in(stage2_data),
            .valid_in(stage2_valid),
            .data_out(stage3_data),
            .valid_out(stage3_valid)
        );
        
        // Output driver
        output_driver u_out (
            .clk(clk),
            .data_in(stage3_data),
            .valid(stage3_valid),
            .data_out(output_data)
        );
        
    endmodule
    """
    
    extractor = VerilogExtractor(code)
    extractor.print_connection_graph()

def test_control_fanout():
    """Test control signal with high fanout"""
    print("\n" + "="*100)
    print("Test: Control Signal with High Fanout")
    print("="*100)
    
    code = """
    module controller (
        input clk,
        input reset,
        input [3:0] select,
        output [31:0] result
    );
    
        wire [31:0] path_a, path_b, path_c, path_d;
        wire [15:0] status;
        
        // Multiple functional units using same control signal
        unit_a u_a (
            .clk(clk),
            .reset(reset),
            .control(select),
            .output_data(path_a)
        );
        
        unit_b u_b (
            .clk(clk),
            .reset(reset),
            .control(select),
            .output_data(path_b)
        );
        
        unit_c u_c (
            .clk(clk),
            .reset(reset),
            .control(select),
            .output_data(path_c)
        );
        
        unit_d u_d (
            .clk(clk),
            .reset(reset),
            .control(select),
            .output_data(path_d)
        );
        
        status_monitor u_status (
            .clk(clk),
            .control(select),
            .status_out(status)
        );
        
        mux_selector u_mux (
            .a(path_a),
            .b(path_b),
            .c(path_c),
            .d(path_d),
            .sel(select),
            .out(result)
        );
        
    endmodule
    """
    
    extractor = VerilogExtractor(code)
    graph = extractor.build_signal_connection_graph()
    
    print("\nSignal Fanout Analysis:")
    print("-"*100)
    
    all_signals = sorted(graph.get_all_signals())
    fanout_list = []
    
    for sig in all_signals:
        fanout = graph.get_signal_fanout(sig)
        fanout_list.append((sig, fanout))
    
    # Sort by fanout
    fanout_list.sort(key=lambda x: x[1], reverse=True)
    
    print(f"\n{'Signal':<20} {'Fanout':<10} {'Type':<15}")
    print("-"*100)
    for sig, fanout in fanout_list:
        if fanout == 0:
            sig_type = "Sink/Output"
        elif graph.get_signal_source(sig):
            sig_type = "Driven"
        else:
            sig_type = "Primary Input"
        print(f"{sig:<20} {fanout:<10} {sig_type:<15}")
    
    # Print connection details
    print("\n\nDetailed Connection Map:")
    print("-"*100)
    
    for sig, fanout in fanout_list:
        if fanout > 0:
            print(f"\n{sig} (fanout={fanout}):")
            destinations = graph.get_signal_destinations(sig)
            for dest_inst, dest_port in destinations:
                print(f"  └─ {dest_inst}.{dest_port}")

def test_signal_tracing():
    """Test signal tracing through design"""
    print("\n" + "="*100)
    print("Test: Signal Tracing Through Design Hierarchy")
    print("="*100)
    
    code = """
    module memory_controller (
        input clk,
        input we,
        input [10:0] addr,
        input [31:0] write_data,
        output [31:0] read_data
    );
    
        wire [10:0] addr_int;
        wire [31:0] wr_data_int;
        wire [31:0] rd_data_int;
        wire we_int;
        
        // Address decoder
        addr_decode addr_dec (
            .addr_in(addr),
            .addr_out(addr_int)
        );
        
        // Input buffer
        input_buf in_buf (
            .data_in(write_data),
            .we_in(we),
            .data_out(wr_data_int),
            .we_out(we_int)
        );
        
        // Memory instance
        memory_block mem (
            .clk(clk),
            .addr(addr_int),
            .write_data(wr_data_int),
            .write_enable(we_int),
            .read_data(rd_data_int)
        );
        
        // Output register
        output_reg out_reg (
            .clk(clk),
            .data_in(rd_data_int),
            .data_out(read_data)
        );
        
    endmodule
    """
    
    extractor = VerilogExtractor(code)
    graph = extractor.build_signal_connection_graph()
    
    print("\nModule Hierarchy:")
    print("-"*100)
    for inst, module_type in sorted(graph.instances.items()):
        print(f"  {inst:<15} : {module_type}")
    
    print("\n\nSignal Flow Analysis:")
    print("-"*100)
    
    # Trace key signals
    key_signals = ['addr', 'addr_int', 'write_data', 'wr_data_int', 'read_data', 'rd_data_int']
    
    for sig in key_signals:
        if sig in graph.get_all_signals():
            trace = graph.trace_signal(sig)
            print(f"\n{sig}:")
            if trace['source']:
                print(f"  Source: {trace['source'][0]}.{trace['source'][1]}")
            print(f"  Destinations: {len(trace['destinations'])}")
            for dest, port in trace['destinations']:
                print(f"    -> {dest}.{port}")

if __name__ == '__main__':
    print("\n" + "="*100)
    print("SIGNAL CONNECTION GRAPH - PRACTICAL EXAMPLES")
    print("="*100)
    
    test_pipeline_design()
    test_control_fanout()
    test_signal_tracing()
    
    print("\n" + "="*100)
    print("All practical examples completed!")
    print("="*100 + "\n")
