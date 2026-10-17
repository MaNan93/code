// Test file with mixed Verilog95 and SystemVerilog2018 styles

// ============================================================================
// Test Case 1: Verilog95 Style
// ============================================================================
module fifo_v95 (
    input clk,
    input reset,
    input wr_en,
    input rd_en,
    input [7:0] data_in,
    output [7:0] data_out,
    output empty,
    output full
);

    // Verilog95 style signal definitions
    wire [7:0] fifo_data;
    reg [4:0] wr_ptr, rd_ptr;
    wire [4:0] wr_ptr_next, rd_ptr_next;
    
    parameter DEPTH = 32;
    parameter WIDTH = 8;
    localparam ADDR_WIDTH = 5;
    
    // FIFO memory instance
    fifo_mem u0_fifo (
        .clk(clk),
        .wr_addr(wr_ptr),
        .rd_addr(rd_ptr),
        .wr_data(data_in),
        .rd_data(data_out)
    );
    
endmodule

// ============================================================================
// Test Case 2: SystemVerilog2018 Style
// ============================================================================
module uart_sv (
    input logic clk,
    input logic rst_n,
    input logic [7:0] tx_data,
    input logic tx_valid,
    output logic tx_ready,
    output logic [7:0] rx_data,
    output logic rx_valid,
    input logic rx_ready
);

    // SystemVerilog style signal definitions
    logic [7:0] tx_shift_reg;
    logic [3:0] bit_counter;
    logic tx_busy;
    bit [15:0] status;
    int baud_rate;
    real timing_offset;
    string uart_version;
    
    parameter int BAUD_RATE = 9600;
    parameter int DATA_BITS = 8;
    localparam int STOP_BITS = 1;
    
    // TX module instance
    uart_tx u0_tx (
        .clk(clk),
        .rst_n(rst_n),
        .data(tx_data),
        .valid(tx_valid),
        .ready(tx_ready),
        .tx_out(tx_serial)
    );
    
    // RX module instance
    uart_rx u0_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rx_in(rx_serial),
        .data(rx_data),
        .valid(rx_valid),
        .ready(rx_ready)
    );
    
endmodule

// ============================================================================
// Test Case 3: Mixed Style and Edge Cases
// ============================================================================
module cache_controller (
    // Mixed port style
    input wire clk,
    input logic reset,
    input wire [31:0] addr,
    input logic [31:0] data_in,
    output logic [31:0] data_out,
    output wire valid,
    inout wire [31:0] shared_bus
);

    // Mixed signal declarations
    wire [7:0] tag_bits;
    logic [31:0] cache_line;
    reg [63:0] cache_array, cache_array_2;
    bit [127:0] dirty_mask;
    int miss_count, hit_count;
    real cache_hitrate;
    
    parameter WIDTH = 32;
    parameter SIZE = 1024;
    localparam TAG_BITS = 16;
    
    // Multiple instantiations
    cache_mem u0_mem (
        .clk(clk),
        .addr(addr[15:8]),
        .data_in(data_in),
        .data_out(data_out)
    );
    
    cache_ctrl u1_ctrl (
        .clk(clk),
        .valid(valid),
        .reset(reset)
    );
    
endmodule

// ============================================================================
// Test Case 4: Compact Format
// ============================================================================
module simple (input a, input b, output c, output d);
    wire temp1, temp2;
    reg counter;
    parameter N = 16;
    
    and_gate u0 (.in1(a), .in2(b), .out(temp1));
    
endmodule
