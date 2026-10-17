"""
Comprehensive example demonstrating Signal Connection Graph usage
"""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from verilog_extractor import VerilogExtractor

# Example: Complex system with multiple signal types and fanouts
SYSTEM_CODE = """
module image_processor (
    input clk,
    input rst_n,
    input [7:0] pixel_in,
    input pixel_valid,
    output [7:0] pixel_out,
    output output_valid
);

    // Control and timing signals
    wire pixel_clk;
    wire pixel_rst;
    wire frame_sync;
    wire line_sync;
    
    // Data pipeline signals
    wire [7:0] gamma_out;
    wire gamma_valid;
    wire [7:0] filter_out;
    wire filter_valid;
    wire [7:0] enhance_out;
    wire enhance_valid;
    wire [7:0] format_out;
    
    // Status signals
    wire [15:0] status;
    wire [15:0] error_flags;
    
    // Clock generation
    clock_gen u_clkgen (
        .sys_clk(clk),
        .rst(rst_n),
        .pixel_clk(pixel_clk),
        .frame_sync(frame_sync),
        .line_sync(line_sync)
    );
    
    // Pixel input stage
    input_stage u_input (
        .clk(pixel_clk),
        .rst_n(pixel_rst),
        .pixel_in(pixel_in),
        .pixel_valid(pixel_valid),
        .frame_sync(frame_sync),
        .line_sync(line_sync)
    );
    
    // Gamma correction
    gamma_corrector u_gamma (
        .clk(pixel_clk),
        .rst_n(pixel_rst),
        .pixel_in(pixel_in),
        .valid_in(pixel_valid),
        .pixel_out(gamma_out),
        .valid_out(gamma_valid),
        .status(status)
    );
    
    // Spatial filtering
    spatial_filter u_filter (
        .clk(pixel_clk),
        .rst_n(pixel_rst),
        .pixel_in(gamma_out),
        .valid_in(gamma_valid),
        .pixel_out(filter_out),
        .valid_out(filter_valid),
        .status(status),
        .errors(error_flags)
    );
    
    // Image enhancement
    enhancer u_enhance (
        .clk(pixel_clk),
        .rst_n(pixel_rst),
        .pixel_in(filter_out),
        .valid_in(filter_valid),
        .pixel_out(enhance_out),
        .valid_out(enhance_valid)
    );
    
    // Output formatter
    output_formatter u_format (
        .clk(pixel_clk),
        .rst_n(pixel_rst),
        .pixel_in(enhance_out),
        .valid_in(enhance_valid),
        .pixel_out(format_out),
        .status(status)
    );
    
    // Output driver
    output_driver u_output (
        .clk(pixel_clk),
        .rst_n(pixel_rst),
        .pixel_in(format_out),
        .pixel_out(pixel_out),
        .valid_out(output_valid)
    );
    
    // Status monitor
    monitor u_monitor (
        .clk(clk),
        .rst_n(rst_n),
        .status(status),
        .error_flags(error_flags)
    );
    
endmodule
"""

def main():
    print("\n" + "="*100)
    print("COMPREHENSIVE SIGNAL CONNECTION GRAPH EXAMPLE")
    print("Complex Image Processor System Analysis")
    print("="*100)
    
    # Create extractor
    extractor = VerilogExtractor(SYSTEM_CODE)
    
    # Get basic information
    ports = extractor.extract_module_ports()
    insts = extractor.extract_module_instantiations()
    signals = extractor.extract_signal_definitions()
    
    # Print basic module information
    print(f"\n1. MODULE OVERVIEW")
    print("-"*100)
    print(f"Module: {ports['module_name']}")
    print(f"Ports: {len(ports['ports'])}")
    print(f"Instantiations: {len(insts)}")
    print(f"Internal Signals: {sum(len(v) for k, v in signals.items() if k not in ['parameters', 'localparam'])}")
    
    # Print port details
    print(f"\n2. MODULE PORTS")
    print("-"*100)
    for port in ports['ports']:
        print(f"  {port['type']:<7} {port['data_type']:<6} {port['width']:<12} {port['name']}")
    
    # Build and print connection graph
    print(f"\n3. SIGNAL CONNECTION GRAPH")
    print("-"*100)
    extractor.print_connection_graph()
    
    # Detailed analysis
    print(f"\n4. DETAILED ANALYSIS")
    print("-"*100)
    
    graph = extractor.build_signal_connection_graph()
    
    # List all instances
    print(f"\nInstances in design ({len(graph.instances)}):")
    for inst, module_type in sorted(graph.instances.items()):
        print(f"  {inst:<15} -> {module_type}")
    
    # Analyze signal types
    print(f"\nSignal Analysis:")
    all_signals = sorted(graph.get_all_signals())
    driven = sum(1 for sig in all_signals if graph.get_signal_source(sig))
    undriven = len(all_signals) - driven
    
    print(f"  Total Signals: {len(all_signals)}")
    print(f"  Driven Signals: {driven}")
    print(f"  Undriven Signals: {undriven}")
    
    # High fanout signals
    print(f"\nHigh Fanout Signals (fanout >= 2):")
    high_fanout = [(sig, graph.get_signal_fanout(sig)) for sig in all_signals]
    high_fanout = sorted(high_fanout, key=lambda x: x[1], reverse=True)
    high_fanout = [x for x in high_fanout if x[1] >= 2]
    
    if high_fanout:
        print(f"  {'Signal':<20} {'Fanout':<10} {'Connected To':<70}")
        print(f"  {'-'*20} {'-'*10} {'-'*70}")
        for signal, fanout in high_fanout:
            dests = graph.get_signal_destinations(signal)
            dest_str = ", ".join([f"{inst}.{port}" for inst, port in dests[:3]])
            if len(dests) > 3:
                dest_str += f", ... (+{len(dests)-3} more)"
            print(f"  {signal:<20} {fanout:<10} {dest_str:<70}")
    
    # Data path analysis
    print(f"\n5. DATA PATH ANALYSIS")
    print("-"*100)
    
    data_signals = [
        'pixel_in', 'gamma_out', 'filter_out', 'enhance_out', 'format_out', 'pixel_out'
    ]
    
    print("Main Data Pipeline:")
    for sig in data_signals:
        if sig in all_signals:
            dests = graph.get_signal_destinations(sig)
            if dests:
                print(f"  {sig:<20} -> {dests[0][0]}")
    
    # Control signal analysis
    print(f"\nControl Signals:")
    control_signals = [
        ('pixel_clk', 'Pixel Clock Distribution'),
        ('pixel_rst', 'Reset Signal'),
        ('frame_sync', 'Frame Synchronization'),
        ('line_sync', 'Line Synchronization')
    ]
    
    for sig_name, description in control_signals:
        if sig_name in all_signals:
            fanout = graph.get_signal_fanout(sig_name)
            print(f"  {sig_name:<15} : {fanout:>2} modules  ({description})")
    
    print("\n" + "="*100)
    print("Analysis Complete!")
    print("="*100 + "\n")

if __name__ == '__main__':
    main()
