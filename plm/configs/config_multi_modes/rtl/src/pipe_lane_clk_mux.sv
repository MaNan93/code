//
// PIPE lane mapper clock-mux submodule.
// Contains: controller pclk generation, feedback clock mux.
// Each group's final sel_tgt is produced by pipe_lane_sel_gen and passed in as an input.
// The feedback reset mux is in pipe_lane_rst_mux, the data muxes are in
// pipe_lane_data_m2p / pipe_lane_data_p2m.
import pipe_pkg::*;

module pipe_lane_clk_mux #(
    parameter int LANE_COUNT = 4,
    parameter int NUM_CTRL   = 2
) (
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [LANE_COUNT-1:0] phy_pclk_out,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic                  test_en,
    input  logic [NUM_CTRL-1:0]   ctrl_rst_n,

    input  lane_sel_t              sel_tgt,   // each group's currently effective owner selection

    output logic [NUM_CTRL-1:0]   ctrl_pclk,
    output logic [LANE_COUNT-1:0] phy_pclk_in
);

    //------------------------------------------------------------
    // controller pclk: always taken from the lowest-numbered lane in its group.
    // Only needs a glitch-free switch when there's more than one candidate.
    //------------------------------------------------------------
    // PCIe_x4: uses phy_pclk[0] in every mode, direct connection
    assign ctrl_pclk[0] = phy_pclk_out[0];

    // USB_x2: uses phy_pclk[2] in every mode, direct connection
    assign ctrl_pclk[1] = phy_pclk_out[2];

    //------------------------------------------------------------
    // Feedback clock: each lane's pclk_in connects to its current owner's ctrl_pclk.
    // Shares the same en group as the data path, so data and clock switch in lockstep.
    //------------------------------------------------------------
    assign phy_pclk_in[0] = ctrl_pclk[0];  // G0 direct to PCIe_x4
    assign phy_pclk_in[1] = ctrl_pclk[0];  // G0 direct to PCIe_x4
    // G1 lane2~3: PCIe_x4, USB_x2
    logic [1:0] pin_gated_g1;
    logic pclk_in_g1;
    clk_gate u_pin_gate_g1_b0 (.clk_in(ctrl_pclk[0]), .en(sel_tgt.g1[0]), .test_en(test_en), .clk_out(pin_gated_g1[0]));
    clk_gate u_pin_gate_g1_b1 (.clk_in(ctrl_pclk[1]), .en(sel_tgt.g1[1]), .test_en(test_en), .clk_out(pin_gated_g1[1]));
    assign pclk_in_g1 = |pin_gated_g1;
    assign phy_pclk_in[2] = pclk_in_g1;
    assign phy_pclk_in[3] = pclk_in_g1;

endmodule
