module pcie_pipe_clock_gate #(
    parameter integer RESET_ENABLE = 0
)(
    input logic clk,
    input logic phy_rst_n,
    input logic request,
    output logic gate_enable
);
    logic request_meta, request_sync;
    // Hold gate enable while the clock is high.
    always @(posedge clk or negedge phy_rst_n) begin
        if (!phy_rst_n) begin
            request_meta <= RESET_ENABLE;
            request_sync <= RESET_ENABLE;
        end else begin
            request_meta <= request;
            request_sync <= request_meta;
        end
    end
    always_latch begin
        if (!phy_rst_n) begin
            gate_enable = RESET_ENABLE;
        end else if (!clk) begin
            gate_enable = request_sync;
        end
    end
endmodule
