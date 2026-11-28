module pcie_pipe_cdc_fifo #(
    parameter int WIDTH = 80,
    parameter int DEPTH = 8
) (
    input  logic             wr_clk,
    input  logic             wr_rst_n,
    input  logic             wr_en,
    input  logic [WIDTH-1:0] wr_data,
    output logic             wr_full,

    input  logic             rd_clk,
    input  logic             rd_rst_n,
    input  logic             rd_en,
    output logic [WIDTH-1:0] rd_data,
    output logic             rd_empty
);
    localparam int ADDR_W = $clog2(DEPTH);

    logic [WIDTH-1:0] mem [0:DEPTH-1];

    logic [ADDR_W:0] wr_bin, wr_bin_next;
    logic [ADDR_W:0] wr_gray, wr_gray_next;
    logic [ADDR_W:0] rd_gray_meta, rd_gray_sync;

    logic [ADDR_W:0] rd_bin, rd_bin_next;
    logic [ADDR_W:0] rd_gray, rd_gray_next;
    logic [ADDR_W:0] wr_gray_meta, wr_gray_sync;

    function automatic logic [ADDR_W:0] bin2gray(input logic [ADDR_W:0] bin);
        return (bin >> 1) ^ bin;
    endfunction

    assign wr_bin_next  = wr_bin + {{ADDR_W{1'b0}}, (wr_en && !wr_full)};
    assign wr_gray_next = bin2gray(wr_bin_next);

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_bin       <= '0;
            wr_gray      <= '0;
            rd_gray_meta <= '0;
            rd_gray_sync <= '0;
        end else begin
            wr_bin       <= wr_bin_next;
            wr_gray      <= wr_gray_next;
            rd_gray_meta <= rd_gray;
            rd_gray_sync <= rd_gray_meta;
            if (wr_en && !wr_full) begin
                mem[wr_bin[ADDR_W-1:0]] <= wr_data;
            end
        end
    end

    assign wr_full = (wr_gray == {~rd_gray_sync[ADDR_W:ADDR_W-1], rd_gray_sync[ADDR_W-2:0]});

    assign rd_bin_next  = rd_bin + {{ADDR_W{1'b0}}, (rd_en && !rd_empty)};
    assign rd_gray_next = bin2gray(rd_bin_next);

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_bin       <= '0;
            rd_gray      <= '0;
            wr_gray_meta <= '0;
            wr_gray_sync <= '0;
        end else begin
            rd_bin       <= rd_bin_next;
            rd_gray      <= rd_gray_next;
            wr_gray_meta <= wr_gray;
            wr_gray_sync <= wr_gray_meta;
        end
    end

    assign rd_empty = (rd_gray == wr_gray_sync);
    assign rd_data  = mem[rd_bin[ADDR_W-1:0]];
endmodule
