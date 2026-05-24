`timescale 1ns / 1ps

module fifo_sync #(
    parameter DEPTH = 16,
    parameter WIDTH = 32
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             wr_en,
    input  logic             rd_en,
    input  logic [WIDTH-1:0] wdata,
    output logic [WIDTH-1:0] rdata,
    output logic             full,
    output logic             empty,
    output logic [$clog2(DEPTH):0] count
);
    localparam ADDR_BITS = $clog2(DEPTH);

    logic [WIDTH-1:0] mem [DEPTH-1:0];
    logic [ADDR_BITS-1:0] wr_ptr, rd_ptr;
    logic [ADDR_BITS:0] ptr_gap;

    assign full  = (ptr_gap == DEPTH);
    assign empty = (ptr_gap == 0);
    assign count = ptr_gap;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            ptr_gap <= '0;
        end else begin
            case ({wr_en, rd_en})
                2'b10: if (!full) begin
                    wr_ptr <= (wr_ptr == DEPTH-1) ? '0 : wr_ptr + 1;
                    ptr_gap <= ptr_gap + 1;
                end
                2'b01: if (!empty) begin
                    rd_ptr <= (rd_ptr == DEPTH-1) ? '0 : rd_ptr + 1;
                    ptr_gap <= ptr_gap - 1;
                end
                2'b11: begin
                    wr_ptr <= (wr_ptr == DEPTH-1) ? '0 : wr_ptr + 1;
                    rd_ptr <= (rd_ptr == DEPTH-1) ? '0 : rd_ptr + 1;
                end
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (wr_en && !full)
            mem[wr_ptr] <= wdata;
    end

    assign rdata = mem[rd_ptr];

    property p_no_overflow;
        @(posedge clk) disable iff (!rst_n)
        wr_en |-> !full;
    endproperty

    property p_no_underflow;
        @(posedge clk) disable iff (!rst_n)
        rd_en |-> !empty;
    endproperty

    assert property (p_no_overflow) else $warning("FIFO overflow");
    assert property (p_no_underflow) else $warning("FIFO underflow");

endmodule

module cdc_handshake #(
    parameter SYNC_STAGES = 2,
    parameter WIDTH = 8
)(
    input  logic             src_clk,
    input  logic             src_rst_n,
    input  logic             dst_clk,
    input  logic             dst_rst_n,
    input  logic [WIDTH-1:0] src_data,
    input  logic             src_valid,
    output logic             src_ready,
    output logic [WIDTH-1:0] dst_data,
    output logic             dst_valid
);
    logic             handshake_sync;
    logic             src_req_meta;
    (* ASYNC_REG = "true" *) logic [SYNC_STAGES-1:0] req_sync;
    (* ASYNC_REG = "true" *) logic [SYNC_STAGES-1:0] ack_sync;
    logic [WIDTH-1:0] data_hold;

    always_ff @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n) begin
            handshake_sync <= 1'b0;
            src_ready <= 1'b0;
            data_hold <= '0;
        end else begin
            src_ready <= handshake_sync;
            if (src_valid && src_ready) begin
                data_hold <= src_data;
                handshake_sync <= 1'b0;
            end else if (ack_sync[SYNC_STAGES-1] == handshake_sync) begin
                handshake_sync <= ~handshake_sync;
            end
        end
    end

    always_ff @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            req_sync <= '0;
            dst_valid <= 1'b0;
            dst_data <= '0;
        end else begin
            req_sync <= {req_sync[SYNC_STAGES-2:0], handshake_sync};
            if (req_sync[SYNC_STAGES-1] != req_sync[SYNC_STAGES-2]) begin
                dst_data <= data_hold;
                dst_valid <= 1'b1;
            end else begin
                dst_valid <= 1'b0;
            end
        end
    end

    always_ff @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            ack_sync <= '0;
            src_req_meta <= 1'b0;
        end else begin
            src_req_meta <= handshake_sync;
            ack_sync <= {ack_sync[SYNC_STAGES-2:0], src_req_meta};
        end
    end

endmodule
] reg_addr,
    input  logic              reg_wr,
    input  logic              reg_rd,
    input  logic [31:0]       reg_wdata,
    output logic [31:0]       reg_rdata,
    output logic              reg_ready,
    output logic [NUM_REGS-1:0] intr_out
);
    logic [31:0] regs [NUM_REGS];
    logic [31:0] reg_rdata_int;
    logic        reg_ready_int;`timescale 1ns / 1ps

module edge_detector #(
    parameter EDGE_TYPE = "RISING"
)(
    input  logic clk,
    input  logic rst_n,
    input  logic sig_in,
    output logic edge_pulse
);
    logic sig_d1, sig_d2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sig_d1 <= 1'b0;
            sig_d2 <= 1'b0;
        end else begin
            sig_d1 <= sig_in;
            sig_d2 <= sig_d1;
        end
    end

    generate
        if (EDGE_TYPE == "RISING") begin : rising_edge
            assign edge_pulse = sig_d1 & ~sig_d2;
        end else if (EDGE_TYPE == "FALLING") begin : falling_edge
            assign edge_pulse = ~sig_d1 & sig_d2;
        end else begin : both_edges
            assign edge_pulse = sig_d1 ^ sig_d2;
        end
    endgenerate
endmodule

module fifo_sync #(
    parameter DEPTH = 16,
    parameter WIDTH = 32
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             wr_en,
    input  logic             rd_en,
    input  logic [WIDTH-1:0] wdata,
    output logic [WIDTH-1:0] rdata,
    output logic             full,
    output logic             empty,
    output logic [$clog2(DEPTH):0] count
);
    localparam ADDR_BITS = $clog2(DEPTH);

    logic [WIDTH-1:0] mem [DEPTH-1:0];
    logic [ADDR_BITS-1:0] wr_ptr, rd_ptr;
    logic [ADDR_BITS:0] ptr_gap;

    assign full  = (ptr_gap == DEPTH);
    assign empty = (ptr_gap == 0);
    assign count = ptr_gap;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            ptr_gap <= '0;
        end else begin
            case ({wr_en, rd_en})
                2'b10: if (!full) begin
                    wr_ptr <= (wr_ptr == DEPTH-1) ? '0 : wr_ptr + 1;
                    ptr_gap <= ptr_gap + 1;
                end
                2'b01: if (!empty) begin
                    rd_ptr <= (rd_ptr == DEPTH-1) ? '0 : rd_ptr + 1;
                    ptr_gap <= ptr_gap - 1;
                end
                2'b11: begin
                    wr_ptr <= (wr_ptr == DEPTH-1) ? '0 : wr_ptr + 1;
                    rd_ptr <= (rd_ptr == DEPTH-1) ? '0 : rd_ptr + 1;
                end
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (wr_en && !full)
            mem[wr_ptr] <= wdata;
    end

    assign rdata = mem[rd_ptr];

    property p_no_overflow;
        @(posedge clk) disable iff (!rst_n)
        wr_en |-> !full;
    endproperty

    property p_no_underflow;
        @(posedge clk) disable iff (!rst_n)
        rd_en |-> !empty;
    endproperty

    assert property (p_no_overflow) else $warning("FIFO overflow");
    assert property (p_no_underflow) else $warning("FIFO underflow");

endmodule

modulecdc_handshake #(
    parameter SYNC_STAGES = 2,
    parameter WIDTH = 8
)(
    input  logic             src_clk,
    input  logic             src_rst_n,
    input  logic             dst_clk,
    input  logic             dst_rst_n,
    input  logic [WIDTH-1:0] src_data,
    input  logic             src_valid,
    output logic             src_ready,
    output logic [WIDTH-1:0] dst_data,
    output logic             dst_valid
);
    logic             handshake_sync;
    logic             src_req_meta;
    (* ASYNC_REG = "true" *) logic [SYNC_STAGES-1:0] req_sync;
    (* ASYNC_REG = "true" *) logic [SYNC_STAGES-1:0] ack_sync;
    logic [WIDTH-1:0] data_hold;

    always_ff @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n) begin
            handshake_sync <= 1'b0;
            src_ready <= 1'b0;
            data_hold <= '0;
        end else begin
            src_ready <= handshake_sync;
            if (src_valid && src_ready) begin
                data_hold <= src_data;
                handshake_sync <= 1'b0;
            end else if (ack_sync[SYNC_STAGES-1] == handshake_sync) begin
                handshake_sync <= ~handshake_sync;
            end
        end
    end

    always_ff @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            req_sync <= '0;
            dst_valid <= 1'b0;
            dst_data <= '0;
        end else begin
            req_sync <= {req_sync[SYNC_STAGES-2:0], handshake_sync};
            if (req_sync[SYNC_STAGES-1] != req_sync[SYNC_STAGES-2]) begin
                dst_data <= data_hold;
                dst_valid <= 1'b1;
            end else begin
                dst_valid <= 1'b0;
            end
        end
    end

    always_ff @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            ack_sync <= '0;
            src_req_meta <= 1'b0;
        end else begin
            src_req_meta <= handshake_sync;
            ack_sync <= {ack_sync[SYNC_STAGES-2:0], src_req_meta};
        end
    end

endmodule

    logic [ADDR_WIDTH-1:0] addr_align;

    assign addr_align = {reg_addr[$clog2(NUM_REGS)+1:2], 2'b00};
    assign reg_rdata = reg_rdata_int;
    assign reg_ready = reg_ready_int;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_rdata_int <= '0;
            reg_ready_int <= 1'b0;
        end else begin
            reg_ready_int <= 1'b0;
            if (reg_rd) begin
                if (addr_align < NUM_REGS*4) begin
                    reg_rdata_int <= regs[addr_align[ADDR_WIDTH-1:2]];
                    reg_ready_int <= 1'b1;
                end
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_REGS; i++)
                regs[i] <= '0;
        end else begin
            if (reg_wr && addr_align < NUM_REGS*4) begin
                regs[addr_align[ADDR_WIDTH-1:2]] <= reg_wdata;
            end
        end
    end

    generate
        for (genvar i = 0; i < NUM_REGS; i++) begin : gen_intr
            assign intr_out[i] = regs[i][31] & regs[i][0];
        end
    endgenerate

    wire [31:0] status_word = {28'b0, intr_out};
    wire ctrl_enable = regs[0][0];
    wire [7:0] threshold = regs[2][7:0];

endmodule
