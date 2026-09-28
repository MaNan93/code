// PIPE lane mapper clock-mux submodule (PCLK as PHY input scheme).
// Contains: glitch-free phy_pclk switch, glitch-free rx_clk switch.
// No ctrl_pclk here -- see pipe_lane_sel_gen, which uses {c}_pclk[] directly.
// The reset mux is in pipe_lane_rst_mux, the data muxes are in
// pipe_lane_data_m2p / pipe_lane_data_p2m.
import pipe_lane_signal_pkg::*;

module pipe_lane_clk_mux #(
    parameter int NL = 12,
    parameter int NC = 4
) (
    input logic [NC-1:0] ctrl_rst_n,
    input logic [NL-1:0] rx_clk,     // PHY's per-lane recovered clock
    input logic [11:0] ctrla_pclk,   // CtrlA's own already-divided pclk, one bit per its own lane
    input logic [5:0] ctrlb_pclk,   // CtrlB's own already-divided pclk, one bit per its own lane
    input logic [7:0] ctrlc_pclk,   // CtrlC's own already-divided pclk, one bit per its own lane
    input logic [2:0] ctrld_pclk,   // CtrlD's own already-divided pclk, one bit per its own lane
    input logic [1:0] seltgt_g1_l3,   // dec_tgt.g1 already synchronized into this lane's owning candidate's own ctrl lane's clock, from sel_gen -- also gates phy_pclk
    input logic [1:0] seltgt_g1_l4,   // dec_tgt.g1 already synchronized into this lane's owning candidate's own ctrl lane's clock, from sel_gen -- also gates phy_pclk
    input logic [1:0] seltgt_g1_l5,   // dec_tgt.g1 already synchronized into this lane's owning candidate's own ctrl lane's clock, from sel_gen -- also gates phy_pclk
    input logic [1:0] seltgt_g2_l6,   // dec_tgt.g2 already synchronized into this lane's owning candidate's own ctrl lane's clock, from sel_gen -- also gates phy_pclk
    input logic [1:0] seltgt_g2_l7,   // dec_tgt.g2 already synchronized into this lane's owning candidate's own ctrl lane's clock, from sel_gen -- also gates phy_pclk
    input logic [1:0] seltgt_g2_l8,   // dec_tgt.g2 already synchronized into this lane's owning candidate's own ctrl lane's clock, from sel_gen -- also gates phy_pclk
    input logic [3:0] seltgt_g3_l9,   // dec_tgt.g3 already synchronized into this lane's owning candidate's own ctrl lane's clock, from sel_gen -- also gates phy_pclk
    input logic [3:0] seltgt_g3_l10,   // dec_tgt.g3 already synchronized into this lane's owning candidate's own ctrl lane's clock, from sel_gen -- also gates phy_pclk
    input logic [3:0] seltgt_g3_l11,   // dec_tgt.g3 already synchronized into this lane's owning candidate's own ctrl lane's clock, from sel_gen -- also gates phy_pclk
    input logic [1:0] rxclk_en_g1_l3,
    input logic [1:0] rxclk_en_g1_l4,
    input logic [1:0] rxclk_en_g1_l5,
    input logic [1:0] rxclk_en_g2_l6,
    input logic [1:0] rxclk_en_g2_l7,
    input logic [1:0] rxclk_en_g2_l8,
    input logic [3:0] rxclk_en_g3_l9,
    input logic [3:0] rxclk_en_g3_l10,
    input logic [3:0] rxclk_en_g3_l11,
    output logic [NL-1:0] phy_pclk,
    output logic [11:0] ctrla_rx_clk,
    output logic [5:0] ctrlb_rx_clk,
    output logic [7:0] ctrlc_rx_clk,
    output logic [2:0] ctrld_rx_clk
);

    assign phy_pclk[0] = ctrla_pclk[0];
    assign phy_pclk[1] = ctrla_pclk[1];
    assign phy_pclk[2] = ctrla_pclk[2];
    logic [1:0] pclk_gated_g1_l3;
    pipe_lane_clk_gate u_pclk_gate_g1_l3_b0 (.clk_in(ctrla_pclk[3]), .en(seltgt_g1_l3[0]), .clk_out(pclk_gated_g1_l3[0]));
    pipe_lane_clk_gate u_pclk_gate_g1_l3_b1 (.clk_in(ctrlb_pclk[0]), .en(seltgt_g1_l3[1]), .clk_out(pclk_gated_g1_l3[1]));
    pipe_lane_clk_or #(.N(2)) u_pclk_or_g1_l3 (.clk_in(pclk_gated_g1_l3), .clk_out(phy_pclk[3]));

    logic [1:0] pclk_gated_g1_l4;
    pipe_lane_clk_gate u_pclk_gate_g1_l4_b0 (.clk_in(ctrla_pclk[4]), .en(seltgt_g1_l4[0]), .clk_out(pclk_gated_g1_l4[0]));
    pipe_lane_clk_gate u_pclk_gate_g1_l4_b1 (.clk_in(ctrlb_pclk[1]), .en(seltgt_g1_l4[1]), .clk_out(pclk_gated_g1_l4[1]));
    pipe_lane_clk_or #(.N(2)) u_pclk_or_g1_l4 (.clk_in(pclk_gated_g1_l4), .clk_out(phy_pclk[4]));

    logic [1:0] pclk_gated_g1_l5;
    pipe_lane_clk_gate u_pclk_gate_g1_l5_b0 (.clk_in(ctrla_pclk[5]), .en(seltgt_g1_l5[0]), .clk_out(pclk_gated_g1_l5[0]));
    pipe_lane_clk_gate u_pclk_gate_g1_l5_b1 (.clk_in(ctrlb_pclk[2]), .en(seltgt_g1_l5[1]), .clk_out(pclk_gated_g1_l5[1]));
    pipe_lane_clk_or #(.N(2)) u_pclk_or_g1_l5 (.clk_in(pclk_gated_g1_l5), .clk_out(phy_pclk[5]));

    logic [1:0] pclk_gated_g2_l6;
    pipe_lane_clk_gate u_pclk_gate_g2_l6_b0 (.clk_in(ctrla_pclk[6]), .en(seltgt_g2_l6[0]), .clk_out(pclk_gated_g2_l6[0]));
    pipe_lane_clk_gate u_pclk_gate_g2_l6_b1 (.clk_in(ctrlc_pclk[0]), .en(seltgt_g2_l6[1]), .clk_out(pclk_gated_g2_l6[1]));
    pipe_lane_clk_or #(.N(2)) u_pclk_or_g2_l6 (.clk_in(pclk_gated_g2_l6), .clk_out(phy_pclk[6]));

    logic [1:0] pclk_gated_g2_l7;
    pipe_lane_clk_gate u_pclk_gate_g2_l7_b0 (.clk_in(ctrla_pclk[7]), .en(seltgt_g2_l7[0]), .clk_out(pclk_gated_g2_l7[0]));
    pipe_lane_clk_gate u_pclk_gate_g2_l7_b1 (.clk_in(ctrlc_pclk[1]), .en(seltgt_g2_l7[1]), .clk_out(pclk_gated_g2_l7[1]));
    pipe_lane_clk_or #(.N(2)) u_pclk_or_g2_l7 (.clk_in(pclk_gated_g2_l7), .clk_out(phy_pclk[7]));

    logic [1:0] pclk_gated_g2_l8;
    pipe_lane_clk_gate u_pclk_gate_g2_l8_b0 (.clk_in(ctrla_pclk[8]), .en(seltgt_g2_l8[0]), .clk_out(pclk_gated_g2_l8[0]));
    pipe_lane_clk_gate u_pclk_gate_g2_l8_b1 (.clk_in(ctrlc_pclk[2]), .en(seltgt_g2_l8[1]), .clk_out(pclk_gated_g2_l8[1]));
    pipe_lane_clk_or #(.N(2)) u_pclk_or_g2_l8 (.clk_in(pclk_gated_g2_l8), .clk_out(phy_pclk[8]));

    logic [3:0] pclk_gated_g3_l9;
    pipe_lane_clk_gate u_pclk_gate_g3_l9_b0 (.clk_in(ctrla_pclk[9]), .en(seltgt_g3_l9[0]), .clk_out(pclk_gated_g3_l9[0]));
    pipe_lane_clk_gate u_pclk_gate_g3_l9_b1 (.clk_in(ctrlb_pclk[3]), .en(seltgt_g3_l9[1]), .clk_out(pclk_gated_g3_l9[1]));
    pipe_lane_clk_gate u_pclk_gate_g3_l9_b2 (.clk_in(ctrlc_pclk[3]), .en(seltgt_g3_l9[2]), .clk_out(pclk_gated_g3_l9[2]));
    pipe_lane_clk_gate u_pclk_gate_g3_l9_b3 (.clk_in(ctrld_pclk[0]), .en(seltgt_g3_l9[3]), .clk_out(pclk_gated_g3_l9[3]));
    pipe_lane_clk_or #(.N(4)) u_pclk_or_g3_l9 (.clk_in(pclk_gated_g3_l9), .clk_out(phy_pclk[9]));

    logic [3:0] pclk_gated_g3_l10;
    pipe_lane_clk_gate u_pclk_gate_g3_l10_b0 (.clk_in(ctrla_pclk[10]), .en(seltgt_g3_l10[0]), .clk_out(pclk_gated_g3_l10[0]));
    pipe_lane_clk_gate u_pclk_gate_g3_l10_b1 (.clk_in(ctrlb_pclk[4]), .en(seltgt_g3_l10[1]), .clk_out(pclk_gated_g3_l10[1]));
    pipe_lane_clk_gate u_pclk_gate_g3_l10_b2 (.clk_in(ctrlc_pclk[4]), .en(seltgt_g3_l10[2]), .clk_out(pclk_gated_g3_l10[2]));
    pipe_lane_clk_gate u_pclk_gate_g3_l10_b3 (.clk_in(ctrld_pclk[1]), .en(seltgt_g3_l10[3]), .clk_out(pclk_gated_g3_l10[3]));
    pipe_lane_clk_or #(.N(4)) u_pclk_or_g3_l10 (.clk_in(pclk_gated_g3_l10), .clk_out(phy_pclk[10]));

    logic [3:0] pclk_gated_g3_l11;
    pipe_lane_clk_gate u_pclk_gate_g3_l11_b0 (.clk_in(ctrla_pclk[11]), .en(seltgt_g3_l11[0]), .clk_out(pclk_gated_g3_l11[0]));
    pipe_lane_clk_gate u_pclk_gate_g3_l11_b1 (.clk_in(ctrlb_pclk[5]), .en(seltgt_g3_l11[1]), .clk_out(pclk_gated_g3_l11[1]));
    pipe_lane_clk_gate u_pclk_gate_g3_l11_b2 (.clk_in(ctrlc_pclk[5]), .en(seltgt_g3_l11[2]), .clk_out(pclk_gated_g3_l11[2]));
    pipe_lane_clk_gate u_pclk_gate_g3_l11_b3 (.clk_in(ctrld_pclk[2]), .en(seltgt_g3_l11[3]), .clk_out(pclk_gated_g3_l11[3]));
    pipe_lane_clk_or #(.N(4)) u_pclk_or_g3_l11 (.clk_in(pclk_gated_g3_l11), .clk_out(phy_pclk[11]));

    //------------------------------------------------------------
    // rx_clk: glitch-free per-lane select, using rxclk_en_g{gid}_l{lane_idx} from
    // sel_gen (already synchronized into rx_clk[lane_idx]'s own domain).
    //------------------------------------------------------------
    assign ctrla_rx_clk[0] = rx_clk[0];  // G0 direct to CtrlA
    assign ctrla_rx_clk[1] = rx_clk[1];  // G0 direct to CtrlA
    assign ctrla_rx_clk[2] = rx_clk[2];  // G0 direct to CtrlA

    // G1 lane3~5: CtrlA, CtrlB, per-lane glitch-free select
    pipe_lane_clk_gate u_rxclk_gate_g1_l3_b0 (.clk_in(rx_clk[3]), .en(rxclk_en_g1_l3[0]), .clk_out(ctrla_rx_clk[3]));
    pipe_lane_clk_gate u_rxclk_gate_g1_l3_b1 (.clk_in(rx_clk[3]), .en(rxclk_en_g1_l3[1]), .clk_out(ctrlb_rx_clk[0]));

    pipe_lane_clk_gate u_rxclk_gate_g1_l4_b0 (.clk_in(rx_clk[4]), .en(rxclk_en_g1_l4[0]), .clk_out(ctrla_rx_clk[4]));
    pipe_lane_clk_gate u_rxclk_gate_g1_l4_b1 (.clk_in(rx_clk[4]), .en(rxclk_en_g1_l4[1]), .clk_out(ctrlb_rx_clk[1]));

    pipe_lane_clk_gate u_rxclk_gate_g1_l5_b0 (.clk_in(rx_clk[5]), .en(rxclk_en_g1_l5[0]), .clk_out(ctrla_rx_clk[5]));
    pipe_lane_clk_gate u_rxclk_gate_g1_l5_b1 (.clk_in(rx_clk[5]), .en(rxclk_en_g1_l5[1]), .clk_out(ctrlb_rx_clk[2]));

    // G2 lane6~8: CtrlA, CtrlC, per-lane glitch-free select
    pipe_lane_clk_gate u_rxclk_gate_g2_l6_b0 (.clk_in(rx_clk[6]), .en(rxclk_en_g2_l6[0]), .clk_out(ctrla_rx_clk[6]));
    pipe_lane_clk_gate u_rxclk_gate_g2_l6_b1 (.clk_in(rx_clk[6]), .en(rxclk_en_g2_l6[1]), .clk_out(ctrlc_rx_clk[0]));

    pipe_lane_clk_gate u_rxclk_gate_g2_l7_b0 (.clk_in(rx_clk[7]), .en(rxclk_en_g2_l7[0]), .clk_out(ctrla_rx_clk[7]));
    pipe_lane_clk_gate u_rxclk_gate_g2_l7_b1 (.clk_in(rx_clk[7]), .en(rxclk_en_g2_l7[1]), .clk_out(ctrlc_rx_clk[1]));

    pipe_lane_clk_gate u_rxclk_gate_g2_l8_b0 (.clk_in(rx_clk[8]), .en(rxclk_en_g2_l8[0]), .clk_out(ctrla_rx_clk[8]));
    pipe_lane_clk_gate u_rxclk_gate_g2_l8_b1 (.clk_in(rx_clk[8]), .en(rxclk_en_g2_l8[1]), .clk_out(ctrlc_rx_clk[2]));

    // G3 lane9~11: CtrlA, CtrlB, CtrlC, CtrlD, per-lane glitch-free select
    pipe_lane_clk_gate u_rxclk_gate_g3_l9_b0 (.clk_in(rx_clk[9]), .en(rxclk_en_g3_l9[0]), .clk_out(ctrla_rx_clk[9]));
    pipe_lane_clk_gate u_rxclk_gate_g3_l9_b1 (.clk_in(rx_clk[9]), .en(rxclk_en_g3_l9[1]), .clk_out(ctrlb_rx_clk[3]));
    pipe_lane_clk_gate u_rxclk_gate_g3_l9_b2 (.clk_in(rx_clk[9]), .en(rxclk_en_g3_l9[2]), .clk_out(ctrlc_rx_clk[3]));
    pipe_lane_clk_gate u_rxclk_gate_g3_l9_b3 (.clk_in(rx_clk[9]), .en(rxclk_en_g3_l9[3]), .clk_out(ctrld_rx_clk[0]));

    pipe_lane_clk_gate u_rxclk_gate_g3_l10_b0 (.clk_in(rx_clk[10]), .en(rxclk_en_g3_l10[0]), .clk_out(ctrla_rx_clk[10]));
    pipe_lane_clk_gate u_rxclk_gate_g3_l10_b1 (.clk_in(rx_clk[10]), .en(rxclk_en_g3_l10[1]), .clk_out(ctrlb_rx_clk[4]));
    pipe_lane_clk_gate u_rxclk_gate_g3_l10_b2 (.clk_in(rx_clk[10]), .en(rxclk_en_g3_l10[2]), .clk_out(ctrlc_rx_clk[4]));
    pipe_lane_clk_gate u_rxclk_gate_g3_l10_b3 (.clk_in(rx_clk[10]), .en(rxclk_en_g3_l10[3]), .clk_out(ctrld_rx_clk[1]));

    pipe_lane_clk_gate u_rxclk_gate_g3_l11_b0 (.clk_in(rx_clk[11]), .en(rxclk_en_g3_l11[0]), .clk_out(ctrla_rx_clk[11]));
    pipe_lane_clk_gate u_rxclk_gate_g3_l11_b1 (.clk_in(rx_clk[11]), .en(rxclk_en_g3_l11[1]), .clk_out(ctrlb_rx_clk[5]));
    pipe_lane_clk_gate u_rxclk_gate_g3_l11_b2 (.clk_in(rx_clk[11]), .en(rxclk_en_g3_l11[2]), .clk_out(ctrlc_rx_clk[5]));
    pipe_lane_clk_gate u_rxclk_gate_g3_l11_b3 (.clk_in(rx_clk[11]), .en(rxclk_en_g3_l11[3]), .clk_out(ctrld_rx_clk[2]));

    assign ctrlc_rx_clk[6] = 1'b0;  // never driven in any mode
    assign ctrlc_rx_clk[7] = 1'b0;  // never driven in any mode

endmodule
