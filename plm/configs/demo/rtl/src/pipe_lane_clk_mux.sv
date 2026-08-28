//
// PIPE lane mapper clock-mux submodule.
// Contains: controller pclk generation, feedback clock mux.
// Each group's final sel_tgt is produced by pipe_lane_sel_gen and passed in as an input.
// The feedback reset mux is in pipe_lane_rst_mux, the data muxes are in
// pipe_lane_data_m2p / pipe_lane_data_p2m.
import pipe_lane_signal_pkg::*;

module pipe_lane_clk_mux #(
    parameter int NL = 16,
    parameter int NC = 4
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
    // Ctrl0: uses phy_pclk[0] in every mode, direct connection
    assign ctrl_pclk[0] = phy_pclk_out[0];

    // Ctrl1: uses phy_pclk[4] in every mode, direct connection
    assign ctrl_pclk[1] = phy_pclk_out[4];

    // Ctrl2: uses phy_pclk[8] in every mode, direct connection
    assign ctrl_pclk[2] = phy_pclk_out[8];

    // Ctrl3: uses phy_pclk[12] in every mode, direct connection
    assign ctrl_pclk[3] = phy_pclk_out[12];

    //------------------------------------------------------------
    // Feedback clock: each lane's pclk_in connects to its current owner's ctrl_pclk.
    // Shares the same en group as the data path, so data and clock switch in lockstep.
    //------------------------------------------------------------
    assign phy_pclk_in[0] = ctrl_pclk[0];  // G0 direct to Ctrl0
    assign phy_pclk_in[1] = ctrl_pclk[0];  // G0 direct to Ctrl0
    assign phy_pclk_in[2] = ctrl_pclk[0];  // G0 direct to Ctrl0
    assign phy_pclk_in[3] = ctrl_pclk[0];  // G0 direct to Ctrl0
    // G1 lane4~7: Ctrl0, Ctrl1
    logic [1:0] pin_gated_g1;
    logic pclk_in_g1;
    pipe_lane_clk_gate u_pin_gate_g1_b0 (.clk_in(ctrl_pclk[0]), .en(sel_tgt.g1[0]), .test_en(test_en), .clk_out(pin_gated_g1[0]));
    pipe_lane_clk_gate u_pin_gate_g1_b1 (.clk_in(ctrl_pclk[1]), .en(sel_tgt.g1[1]), .test_en(test_en), .clk_out(pin_gated_g1[1]));
    assign pclk_in_g1 = |pin_gated_g1;
    assign phy_pclk_in[4] = pclk_in_g1;
    assign phy_pclk_in[5] = pclk_in_g1;
    assign phy_pclk_in[6] = pclk_in_g1;
    assign phy_pclk_in[7] = pclk_in_g1;
    // G2 lane8~11: Ctrl0, Ctrl2
    logic [1:0] pin_gated_g2;
    logic pclk_in_g2;
    pipe_lane_clk_gate u_pin_gate_g2_b0 (.clk_in(ctrl_pclk[0]), .en(sel_tgt.g2[0]), .test_en(test_en), .clk_out(pin_gated_g2[0]));
    pipe_lane_clk_gate u_pin_gate_g2_b1 (.clk_in(ctrl_pclk[2]), .en(sel_tgt.g2[1]), .test_en(test_en), .clk_out(pin_gated_g2[1]));
    assign pclk_in_g2 = |pin_gated_g2;
    assign phy_pclk_in[8] = pclk_in_g2;
    assign phy_pclk_in[9] = pclk_in_g2;
    assign phy_pclk_in[10] = pclk_in_g2;
    assign phy_pclk_in[11] = pclk_in_g2;
    // G3 lane12~15: Ctrl0, Ctrl2, Ctrl3
    logic [2:0] pin_gated_g3;
    logic pclk_in_g3;
    pipe_lane_clk_gate u_pin_gate_g3_b0 (.clk_in(ctrl_pclk[0]), .en(sel_tgt.g3[0]), .test_en(test_en), .clk_out(pin_gated_g3[0]));
    pipe_lane_clk_gate u_pin_gate_g3_b1 (.clk_in(ctrl_pclk[2]), .en(sel_tgt.g3[1]), .test_en(test_en), .clk_out(pin_gated_g3[1]));
    pipe_lane_clk_gate u_pin_gate_g3_b2 (.clk_in(ctrl_pclk[3]), .en(sel_tgt.g3[2]), .test_en(test_en), .clk_out(pin_gated_g3[2]));
    assign pclk_in_g3 = |pin_gated_g3;
    assign phy_pclk_in[12] = pclk_in_g3;
    assign phy_pclk_in[13] = pclk_in_g3;
    assign phy_pclk_in[14] = pclk_in_g3;
    assign phy_pclk_in[15] = pclk_in_g3;

endmodule
