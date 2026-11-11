module pcie_pipe_clock_gate #(
    parameter integer RESET_ENABLE = 0
)(
    input logic clk,
    input logic phy_rst_n,
    input logic request,
    output logic gate_enable
);
    (* async_reg = "true" *) logic request_meta, request_sync;
    always @(negedge clk or negedge phy_rst_n) begin
        if (!phy_rst_n) begin
            request_meta <= RESET_ENABLE;
            request_sync <= RESET_ENABLE;
            gate_enable <= RESET_ENABLE;
        end else begin
            request_meta <= request;
            request_sync <= request_meta;
            gate_enable <= request_sync;
        end
    end
endmodule
