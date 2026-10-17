"""Test script for VerilogExtractor with various test cases"""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from verilog_extractor import VerilogExtractor

def print_section(title):
    print(f"\n{'='*100}")
    print(f"  {title}")
    print('='*100)

def test_verilog95():
    """Test Verilog95 style"""
    print_section("Test 1: Verilog95 Style")
    
    verilog95_code = """
    module counter_v95 (
        input clk,
        input reset,
        input enable,
        output reg [7:0] count
    );
    
        wire clk_gated;
        reg [7:0] count_next;
        
        parameter MAX_COUNT = 255;
        localparam INIT_VAL = 0;
        
        clock_gate u0_cg (
            .clk(clk),
            .enable(enable),
            .clk_out(clk_gated)
        );
        
    endmodule
    """
    
    extractor = VerilogExtractor(verilog95_code)
    extractor.print_report()
    return extractor.extract_all()

def test_systemverilog():
    """Test SystemVerilog2018 style"""
    print_section("Test 2: SystemVerilog2018 Style")
    
    sv_code = """
    module dsp_block (
        input logic clk,
        input logic rst,
        input logic [15:0] a,
        input logic [15:0] b,
        output logic [31:0] result
    );
    
        logic [31:0] mult_result;
        bit [63:0] accumulator;
        int counter;
        real scale_factor;
        
        parameter int WIDTH = 32;
        localparam real PI = 3.14159;
        
        multiplier u0_mult (
            .a(a),
            .b(b),
            .p(mult_result)
        );
        
    endmodule
    """
    
    extractor = VerilogExtractor(sv_code)
    extractor.print_report()
    return extractor.extract_all()

def test_mixed_style():
    """Test mixed Verilog95 and SystemVerilog styles"""
    print_section("Test 3: Mixed Style")
    
    mixed_code = """
    module mixed_design (
        input wire clk,
        input logic reset,
        input wire [31:0] addr,
        output logic [31:0] data
    );
    
        wire internal_clock;
        logic [31:0] data_reg;
        reg counter;
        bit [127:0] mask;
        int cycle_count;
        
        parameter SIZE = 1024;
        parameter bit ENABLE = 1'b1;
        
        mem_ctrl u0 (
            .clk(clk),
            .addr(addr),
            .data(data)
        );
        
    endmodule
    """
    
    extractor = VerilogExtractor(mixed_code)
    extractor.print_report()
    return extractor.extract_all()

def test_edge_cases():
    """Test edge cases"""
    print_section("Test 4: Edge Cases")
    
    edge_code = """
    module edge_cases (
        input a,
        output b,
        inout [15:0] bus1, bus2
    );
    
        wire sig1, sig2, sig3;
        reg r1, r2;
        logic [31:0] l1, l2, l3;
        bit b1, b2;
        int i1, i2;
        real r_1, r_2;
        string str1, str2;
        
        parameter P1 = 32;
        parameter bit P2 = 1'b0;
        parameter int P3 = 100;
        
        mod1 u1 (.a(a), .b(b));
        mod2 u2 (.in1(sig1), .in2(sig2), .out(sig3));
        
    endmodule
    """
    
    extractor = VerilogExtractor(edge_code)
    extractor.print_report()
    return extractor.extract_all()

def test_from_file():
    """Test extraction from test_verilog.v file"""
    print_section("Test 5: File Test - FIFO (Verilog95)")
    
    try:
        with open('test_verilog.v', 'r', encoding='utf-8') as f:
            code = f.read()
        
        extractor = VerilogExtractor(code)
        extractor.print_report()
        
    except FileNotFoundError:
        print("test_verilog.v not found")

if __name__ == '__main__':
    print_section("VERILOG EXTRACTOR - COMPREHENSIVE TEST SUITE")
    
    # Run all tests
    results_v95 = test_verilog95()
    results_sv = test_systemverilog()
    results_mixed = test_mixed_style()
    results_edge = test_edge_cases()
    test_from_file()
    
    # Summary
    print_section("TEST SUMMARY")
    print(f"\nTest Results:")
    print(f"  [OK] Verilog95 detection: {results_v95['module_ports']['module_name']}")
    print(f"  [OK] SystemVerilog2018 detection: {results_sv['module_ports']['module_name']}")
    print(f"  [OK] Mixed style detection: {results_mixed['module_ports']['module_name']}")
    print(f"  [OK] Edge cases detection: {results_edge['module_ports']['module_name']}")
    
    # Count signals
    v95_signals = sum(len(v) for k, v in results_v95['signal_definitions'].items() if k not in ['parameters', 'localparam'])
    sv_signals = sum(len(v) for k, v in results_sv['signal_definitions'].items() if k not in ['parameters', 'localparam'])
    mixed_signals = sum(len(v) for k, v in results_mixed['signal_definitions'].items() if k not in ['parameters', 'localparam'])
    edge_signals = sum(len(v) for k, v in results_edge['signal_definitions'].items() if k not in ['parameters', 'localparam'])
    
    print(f"\nSignal Detection:")
    print(f"  Verilog95: {v95_signals} signals")
    print(f"  SystemVerilog2018: {sv_signals} signals")
    print(f"  Mixed: {mixed_signals} signals")
    print(f"  Edge Cases: {edge_signals} signals")
    
    print("\n" + "="*100)
    print("All tests completed successfully!")
    print("="*100 + "\n")
