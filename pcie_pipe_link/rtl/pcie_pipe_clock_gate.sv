module pcie_pipe_clock_gate #(
    parameter bit RESET_ENABLE = 1'b0
) (
    input  logic clk,
    input  logic phy_rst_n,
    input  logic request,
    output logic gate_enable,
    output logic gclk
);
    logic request_meta;
    logic request_sync;

    always_ff @(posedge clk or negedge phy_rst_n) begin
        if (!phy_rst_n) begin
            request_meta <= RESET_ENABLE;
            request_sync <= RESET_ENABLE;
        end else begin
            request_meta <= request;
            request_sync <= request_meta;
        end
    end

    // Latch-based integrated clock gate: transparent during low clock phase.
    always_latch begin
        if (!phy_rst_n) begin
            gate_enable = RESET_ENABLE;
        end else if (!clk) begin
            gate_enable = request_sync;
        end
    end

    assign gclk = clk & gate_enable;
endmodule
