//
// PIPE lane mapper clock-mux submodule.
// Contains: controller pclk generation, feedback clock mux.
// Each group's final sel_tgt is produced by pipe_lane_sel_gen and passed in as an input.
// The feedback reset mux is in pipe_lane_rst_mux, the data muxes are in
// pipe_lane_data_m2p / pipe_lane_data_p2m.
import pipe_lane_signal_pkg::*;

module pipe_lane_clk_mux #(
    parameter int NL = 6,
    parameter int NC = 6
) (
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [NL-1:0] phy_pclk_out,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic                  test_en,
    input  logic [NC-1:0]   ctrl_rst_n,

    input  lane_sel_t              sel_tgt,   // each group's currently effective owner selection

    output logic [NC-1:0]   ctrl_pclk,
    output logic [NL-1:0] phy_pclk_in
);

    //------------------------------------------------------------
    // controller pclk: always taken from the lowest-numbered lane in its group.
    // Only needs a glitch-free switch when there's more than one candidate.
    //------------------------------------------------------------
    // CtrlAlpha: uses phy_pclk[0] in every mode, direct connection
    assign ctrl_pclk[0] = phy_pclk_out[0];

    // CtrlBeta: uses phy_pclk[3] in every mode, direct connection
    assign ctrl_pclk[1] = phy_pclk_out[3];

    // CtrlGamma: uses phy_pclk[5] in every mode, direct connection
    assign ctrl_pclk[2] = phy_pclk_out[5];

    // CtrlDelta: uses phy_pclk[1] in every mode, direct connection
    assign ctrl_pclk[3] = phy_pclk_out[1];

    // CtrlEpsilon: uses phy_pclk[2] in every mode, direct connection
    assign ctrl_pclk[4] = phy_pclk_out[2];

    // CtrlZeta: uses phy_pclk[4] in every mode, direct connection
    assign ctrl_pclk[5] = phy_pclk_out[4];

    //------------------------------------------------------------
    // Feedback clock: each lane's pclk_in connects to its current owner's ctrl_pclk.
    // Shares the same en group as the data path, so data and clock switch in lockstep.
    //------------------------------------------------------------
    assign phy_pclk_in[0] = ctrl_pclk[0];  // G0 direct to CtrlAlpha
    // G1 lane1~1: CtrlAlpha, CtrlDelta
    logic [1:0] pin_gated_g1;
    logic pclk_in_g1;
    pipe_lane_clk_gate u_pin_gate_g1_b0 (.clk_in(ctrl_pclk[0]), .en(sel_tgt.g1[0]), .test_en(test_en), .clk_out(pin_gated_g1[0]));
    pipe_lane_clk_gate u_pin_gate_g1_b1 (.clk_in(ctrl_pclk[3]), .en(sel_tgt.g1[1]), .test_en(test_en), .clk_out(pin_gated_g1[1]));
    assign pclk_in_g1 = |pin_gated_g1;
    assign phy_pclk_in[1] = pclk_in_g1;
    // G2 lane2~2: CtrlAlpha, CtrlEpsilon
    logic [1:0] pin_gated_g2;
    logic pclk_in_g2;
    pipe_lane_clk_gate u_pin_gate_g2_b0 (.clk_in(ctrl_pclk[0]), .en(sel_tgt.g2[0]), .test_en(test_en), .clk_out(pin_gated_g2[0]));
    pipe_lane_clk_gate u_pin_gate_g2_b1 (.clk_in(ctrl_pclk[4]), .en(sel_tgt.g2[1]), .test_en(test_en), .clk_out(pin_gated_g2[1]));
    assign pclk_in_g2 = |pin_gated_g2;
    assign phy_pclk_in[2] = pclk_in_g2;
    assign phy_pclk_in[3] = ctrl_pclk[1];  // G3 direct to CtrlBeta
    // G4 lane4~4: CtrlBeta, CtrlZeta
    logic [1:0] pin_gated_g4;
    logic pclk_in_g4;
    pipe_lane_clk_gate u_pin_gate_g4_b0 (.clk_in(ctrl_pclk[1]), .en(sel_tgt.g4[0]), .test_en(test_en), .clk_out(pin_gated_g4[0]));
    pipe_lane_clk_gate u_pin_gate_g4_b1 (.clk_in(ctrl_pclk[5]), .en(sel_tgt.g4[1]), .test_en(test_en), .clk_out(pin_gated_g4[1]));
    assign pclk_in_g4 = |pin_gated_g4;
    assign phy_pclk_in[4] = pclk_in_g4;
    assign phy_pclk_in[5] = ctrl_pclk[2];  // G5 direct to CtrlGamma

endmodule
