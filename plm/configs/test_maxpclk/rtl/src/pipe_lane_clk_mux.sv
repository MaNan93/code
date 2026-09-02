// PIPE lane mapper clock-mux submodule (PCLK as PHY input, max_pclk scheme).
// Contains: ctrl_pclk passthrough, glitch-free phy_pclk_in switch, plain rx_clk routing.
// The reset mux is in pipe_lane_rst_mux, the data muxes are in
// pipe_lane_data_m2p / pipe_lane_data_p2m.
import pipe_lane_signal_pkg::*;

module pipe_lane_clk_mux #(
    parameter int NL = 12,
    parameter int NC = 4
) (
    input  logic [NC-1:0]   max_pclk,   // one external PLL clock per controller
    input  logic             test_en,
    input  logic [NC-1:0]   ctrl_rst_n,
    input  lane_sel_t        dec_tgt,    // raw per-group decode target, for the per-lane pclk sync trees
    input  lane_sel_t        sel_tgt,    // each group's currently effective owner selection, for rx_clk routing
    input  logic [NL-1:0]   rx_clk,     // PHY's per-lane recovered clock
    input  logic [11:0] ctrla_pclk,   // CtrlA's own already-divided pclk, one bit per its own port
    input  logic [5:0] ctrlb_pclk,   // CtrlB's own already-divided pclk, one bit per its own port
    input  logic [7:0] ctrlc_pclk,   // CtrlC's own already-divided pclk, one bit per its own port
    input  logic [2:0] ctrld_pclk,   // CtrlD's own already-divided pclk, one bit per its own port

    output logic [NC-1:0]   ctrl_pclk,
    output logic [NL-1:0]   phy_pclk_in,
    output logic [11:0] ctrla_rx_clk,
    output logic [5:0] ctrlb_rx_clk,
    output logic [7:0] ctrlc_rx_clk,
    output logic [2:0] ctrld_rx_clk
);

    //------------------------------------------------------------
    // ctrl_pclk: each controller's own PLL clock, passed straight through --
    // there's no lane-derived candidate to select between here.
    //------------------------------------------------------------
    assign ctrl_pclk = max_pclk;

    //------------------------------------------------------------
    // phy_pclk_in: glitch-free per-lane select among the owning group's
    // candidate controllers' own port-level pclk.
    //------------------------------------------------------------
    assign phy_pclk_in[0] = ctrla_pclk[0];  // G0 direct to CtrlA
    assign phy_pclk_in[1] = ctrla_pclk[1];  // G0 direct to CtrlA
    assign phy_pclk_in[2] = ctrla_pclk[2];  // G0 direct to CtrlA

    // G1 lane3~5: CtrlA, CtrlB, per-lane glitch-free select
    logic [1:0] pclk_en_g1_l3;
    logic [1:0] pclk_gated_g1_l3;
    pipe_lane_sel_sync #(.N(2), .SYNC(1'b1)) u_pclk_sel_sync_g1_l3 (
        .branch_clk   ({ctrlb_pclk[0], ctrla_pclk[3]}),
        .branch_rst_n ({ctrl_rst_n[1], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g1),
        .en           (pclk_en_g1_l3)
    );
    pipe_lane_clk_gate u_pclk_gate_g1_l3_b0 (.clk_in(ctrla_pclk[3]), .en(pclk_en_g1_l3[0]), .test_en(test_en), .clk_out(pclk_gated_g1_l3[0]));
    pipe_lane_clk_gate u_pclk_gate_g1_l3_b1 (.clk_in(ctrlb_pclk[0]), .en(pclk_en_g1_l3[1]), .test_en(test_en), .clk_out(pclk_gated_g1_l3[1]));
    assign phy_pclk_in[3] = |pclk_gated_g1_l3;
    logic [1:0] pclk_en_g1_l4;
    logic [1:0] pclk_gated_g1_l4;
    pipe_lane_sel_sync #(.N(2), .SYNC(1'b1)) u_pclk_sel_sync_g1_l4 (
        .branch_clk   ({ctrlb_pclk[1], ctrla_pclk[4]}),
        .branch_rst_n ({ctrl_rst_n[1], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g1),
        .en           (pclk_en_g1_l4)
    );
    pipe_lane_clk_gate u_pclk_gate_g1_l4_b0 (.clk_in(ctrla_pclk[4]), .en(pclk_en_g1_l4[0]), .test_en(test_en), .clk_out(pclk_gated_g1_l4[0]));
    pipe_lane_clk_gate u_pclk_gate_g1_l4_b1 (.clk_in(ctrlb_pclk[1]), .en(pclk_en_g1_l4[1]), .test_en(test_en), .clk_out(pclk_gated_g1_l4[1]));
    assign phy_pclk_in[4] = |pclk_gated_g1_l4;
    logic [1:0] pclk_en_g1_l5;
    logic [1:0] pclk_gated_g1_l5;
    pipe_lane_sel_sync #(.N(2), .SYNC(1'b1)) u_pclk_sel_sync_g1_l5 (
        .branch_clk   ({ctrlb_pclk[2], ctrla_pclk[5]}),
        .branch_rst_n ({ctrl_rst_n[1], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g1),
        .en           (pclk_en_g1_l5)
    );
    pipe_lane_clk_gate u_pclk_gate_g1_l5_b0 (.clk_in(ctrla_pclk[5]), .en(pclk_en_g1_l5[0]), .test_en(test_en), .clk_out(pclk_gated_g1_l5[0]));
    pipe_lane_clk_gate u_pclk_gate_g1_l5_b1 (.clk_in(ctrlb_pclk[2]), .en(pclk_en_g1_l5[1]), .test_en(test_en), .clk_out(pclk_gated_g1_l5[1]));
    assign phy_pclk_in[5] = |pclk_gated_g1_l5;

    // G2 lane6~8: CtrlA, CtrlC, per-lane glitch-free select
    logic [1:0] pclk_en_g2_l6;
    logic [1:0] pclk_gated_g2_l6;
    pipe_lane_sel_sync #(.N(2), .SYNC(1'b1)) u_pclk_sel_sync_g2_l6 (
        .branch_clk   ({ctrlc_pclk[0], ctrla_pclk[6]}),
        .branch_rst_n ({ctrl_rst_n[2], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g2),
        .en           (pclk_en_g2_l6)
    );
    pipe_lane_clk_gate u_pclk_gate_g2_l6_b0 (.clk_in(ctrla_pclk[6]), .en(pclk_en_g2_l6[0]), .test_en(test_en), .clk_out(pclk_gated_g2_l6[0]));
    pipe_lane_clk_gate u_pclk_gate_g2_l6_b1 (.clk_in(ctrlc_pclk[0]), .en(pclk_en_g2_l6[1]), .test_en(test_en), .clk_out(pclk_gated_g2_l6[1]));
    assign phy_pclk_in[6] = |pclk_gated_g2_l6;
    logic [1:0] pclk_en_g2_l7;
    logic [1:0] pclk_gated_g2_l7;
    pipe_lane_sel_sync #(.N(2), .SYNC(1'b1)) u_pclk_sel_sync_g2_l7 (
        .branch_clk   ({ctrlc_pclk[1], ctrla_pclk[7]}),
        .branch_rst_n ({ctrl_rst_n[2], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g2),
        .en           (pclk_en_g2_l7)
    );
    pipe_lane_clk_gate u_pclk_gate_g2_l7_b0 (.clk_in(ctrla_pclk[7]), .en(pclk_en_g2_l7[0]), .test_en(test_en), .clk_out(pclk_gated_g2_l7[0]));
    pipe_lane_clk_gate u_pclk_gate_g2_l7_b1 (.clk_in(ctrlc_pclk[1]), .en(pclk_en_g2_l7[1]), .test_en(test_en), .clk_out(pclk_gated_g2_l7[1]));
    assign phy_pclk_in[7] = |pclk_gated_g2_l7;
    logic [1:0] pclk_en_g2_l8;
    logic [1:0] pclk_gated_g2_l8;
    pipe_lane_sel_sync #(.N(2), .SYNC(1'b1)) u_pclk_sel_sync_g2_l8 (
        .branch_clk   ({ctrlc_pclk[2], ctrla_pclk[8]}),
        .branch_rst_n ({ctrl_rst_n[2], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g2),
        .en           (pclk_en_g2_l8)
    );
    pipe_lane_clk_gate u_pclk_gate_g2_l8_b0 (.clk_in(ctrla_pclk[8]), .en(pclk_en_g2_l8[0]), .test_en(test_en), .clk_out(pclk_gated_g2_l8[0]));
    pipe_lane_clk_gate u_pclk_gate_g2_l8_b1 (.clk_in(ctrlc_pclk[2]), .en(pclk_en_g2_l8[1]), .test_en(test_en), .clk_out(pclk_gated_g2_l8[1]));
    assign phy_pclk_in[8] = |pclk_gated_g2_l8;

    // G3 lane9~11: CtrlA, CtrlB, CtrlC, CtrlD, per-lane glitch-free select
    logic [3:0] pclk_en_g3_l9;
    logic [3:0] pclk_gated_g3_l9;
    pipe_lane_sel_sync #(.N(4), .SYNC(1'b1)) u_pclk_sel_sync_g3_l9 (
        .branch_clk   ({ctrld_pclk[0], ctrlc_pclk[3], ctrlb_pclk[3], ctrla_pclk[9]}),
        .branch_rst_n ({ctrl_rst_n[3], ctrl_rst_n[2], ctrl_rst_n[1], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g3),
        .en           (pclk_en_g3_l9)
    );
    pipe_lane_clk_gate u_pclk_gate_g3_l9_b0 (.clk_in(ctrla_pclk[9]), .en(pclk_en_g3_l9[0]), .test_en(test_en), .clk_out(pclk_gated_g3_l9[0]));
    pipe_lane_clk_gate u_pclk_gate_g3_l9_b1 (.clk_in(ctrlb_pclk[3]), .en(pclk_en_g3_l9[1]), .test_en(test_en), .clk_out(pclk_gated_g3_l9[1]));
    pipe_lane_clk_gate u_pclk_gate_g3_l9_b2 (.clk_in(ctrlc_pclk[3]), .en(pclk_en_g3_l9[2]), .test_en(test_en), .clk_out(pclk_gated_g3_l9[2]));
    pipe_lane_clk_gate u_pclk_gate_g3_l9_b3 (.clk_in(ctrld_pclk[0]), .en(pclk_en_g3_l9[3]), .test_en(test_en), .clk_out(pclk_gated_g3_l9[3]));
    assign phy_pclk_in[9] = |pclk_gated_g3_l9;
    logic [3:0] pclk_en_g3_l10;
    logic [3:0] pclk_gated_g3_l10;
    pipe_lane_sel_sync #(.N(4), .SYNC(1'b1)) u_pclk_sel_sync_g3_l10 (
        .branch_clk   ({ctrld_pclk[1], ctrlc_pclk[4], ctrlb_pclk[4], ctrla_pclk[10]}),
        .branch_rst_n ({ctrl_rst_n[3], ctrl_rst_n[2], ctrl_rst_n[1], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g3),
        .en           (pclk_en_g3_l10)
    );
    pipe_lane_clk_gate u_pclk_gate_g3_l10_b0 (.clk_in(ctrla_pclk[10]), .en(pclk_en_g3_l10[0]), .test_en(test_en), .clk_out(pclk_gated_g3_l10[0]));
    pipe_lane_clk_gate u_pclk_gate_g3_l10_b1 (.clk_in(ctrlb_pclk[4]), .en(pclk_en_g3_l10[1]), .test_en(test_en), .clk_out(pclk_gated_g3_l10[1]));
    pipe_lane_clk_gate u_pclk_gate_g3_l10_b2 (.clk_in(ctrlc_pclk[4]), .en(pclk_en_g3_l10[2]), .test_en(test_en), .clk_out(pclk_gated_g3_l10[2]));
    pipe_lane_clk_gate u_pclk_gate_g3_l10_b3 (.clk_in(ctrld_pclk[1]), .en(pclk_en_g3_l10[3]), .test_en(test_en), .clk_out(pclk_gated_g3_l10[3]));
    assign phy_pclk_in[10] = |pclk_gated_g3_l10;
    logic [3:0] pclk_en_g3_l11;
    logic [3:0] pclk_gated_g3_l11;
    pipe_lane_sel_sync #(.N(4), .SYNC(1'b1)) u_pclk_sel_sync_g3_l11 (
        .branch_clk   ({ctrld_pclk[2], ctrlc_pclk[5], ctrlb_pclk[5], ctrla_pclk[11]}),
        .branch_rst_n ({ctrl_rst_n[3], ctrl_rst_n[2], ctrl_rst_n[1], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g3),
        .en           (pclk_en_g3_l11)
    );
    pipe_lane_clk_gate u_pclk_gate_g3_l11_b0 (.clk_in(ctrla_pclk[11]), .en(pclk_en_g3_l11[0]), .test_en(test_en), .clk_out(pclk_gated_g3_l11[0]));
    pipe_lane_clk_gate u_pclk_gate_g3_l11_b1 (.clk_in(ctrlb_pclk[5]), .en(pclk_en_g3_l11[1]), .test_en(test_en), .clk_out(pclk_gated_g3_l11[1]));
    pipe_lane_clk_gate u_pclk_gate_g3_l11_b2 (.clk_in(ctrlc_pclk[5]), .en(pclk_en_g3_l11[2]), .test_en(test_en), .clk_out(pclk_gated_g3_l11[2]));
    pipe_lane_clk_gate u_pclk_gate_g3_l11_b3 (.clk_in(ctrld_pclk[2]), .en(pclk_en_g3_l11[3]), .test_en(test_en), .clk_out(pclk_gated_g3_l11[3]));
    assign phy_pclk_in[11] = |pclk_gated_g3_l11;

    //------------------------------------------------------------
    // rx_clk: plain per-mode selection into each controller port's rx_clk bit --
    // no glitch-free treatment needed (see docs/design_notes.md).
    //------------------------------------------------------------
    assign ctrla_rx_clk[0] = rx_clk[0];  // direct connection to lane0
    assign ctrla_rx_clk[1] = rx_clk[1];  // direct connection to lane1
    assign ctrla_rx_clk[2] = rx_clk[2];  // direct connection to lane2
    assign ctrla_rx_clk[3] = (rx_clk[3] & sel_tgt.g1[0]);
    assign ctrla_rx_clk[4] = (rx_clk[4] & sel_tgt.g1[0]);
    assign ctrla_rx_clk[5] = (rx_clk[5] & sel_tgt.g1[0]);
    assign ctrla_rx_clk[6] = (rx_clk[6] & sel_tgt.g2[0]);
    assign ctrla_rx_clk[7] = (rx_clk[7] & sel_tgt.g2[0]);
    assign ctrla_rx_clk[8] = (rx_clk[8] & sel_tgt.g2[0]);
    assign ctrla_rx_clk[9] = (rx_clk[9] & sel_tgt.g3[0]);
    assign ctrla_rx_clk[10] = (rx_clk[10] & sel_tgt.g3[0]);
    assign ctrla_rx_clk[11] = (rx_clk[11] & sel_tgt.g3[0]);
    assign ctrlb_rx_clk[0] = (rx_clk[3] & sel_tgt.g1[1]);
    assign ctrlb_rx_clk[1] = (rx_clk[4] & sel_tgt.g1[1]);
    assign ctrlb_rx_clk[2] = (rx_clk[5] & sel_tgt.g1[1]);
    assign ctrlb_rx_clk[3] = (rx_clk[9] & sel_tgt.g3[1]);
    assign ctrlb_rx_clk[4] = (rx_clk[10] & sel_tgt.g3[1]);
    assign ctrlb_rx_clk[5] = (rx_clk[11] & sel_tgt.g3[1]);
    assign ctrlc_rx_clk[0] = (rx_clk[6] & sel_tgt.g2[1]);
    assign ctrlc_rx_clk[1] = (rx_clk[7] & sel_tgt.g2[1]);
    assign ctrlc_rx_clk[2] = (rx_clk[8] & sel_tgt.g2[1]);
    assign ctrlc_rx_clk[3] = (rx_clk[9] & sel_tgt.g3[2]);
    assign ctrlc_rx_clk[4] = (rx_clk[10] & sel_tgt.g3[2]);
    assign ctrlc_rx_clk[5] = (rx_clk[11] & sel_tgt.g3[2]);
    assign ctrlc_rx_clk[6] = 1'b0;  // never driven in any mode
    assign ctrlc_rx_clk[7] = 1'b0;  // never driven in any mode
    assign ctrld_rx_clk[0] = (rx_clk[9] & sel_tgt.g3[3]);
    assign ctrld_rx_clk[1] = (rx_clk[10] & sel_tgt.g3[3]);
    assign ctrld_rx_clk[2] = (rx_clk[11] & sel_tgt.g3[3]);

endmodule
