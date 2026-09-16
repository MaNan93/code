// PIPE lane mapper top level.
//
// Pure instantiation layer:
//   pipe_lane_sel_gen  -- mode decoding + per-lane pipe_lane_sel_sync, produces
//                        seltgt_gN_lL / rxclk_en_gN_lL
//   pipe_lane_clk_mux  -- glitch-free phy_pclk feedback switching + rx_clk routing
//   pipe_lane_rst_mux  -- reset mux
//   pipe_lane_data_m2p -- MAC->PHY data mux
//   pipe_lane_data_p2m -- PHY->MAC data mux
//
// Lane grouping: lanes with the same owner sequence are grouped automatically, sharing one NOV.
//
//   G0 lane0~2        CtrlA / CtrlA / CtrlA / CtrlA direct
//   G1 lane3~5        CtrlA / CtrlB / CtrlA / CtrlB 2-way NOV
//   G2 lane6~8        CtrlA / CtrlA / CtrlC / CtrlC 2-way NOV
//   G3 lane9~11       CtrlA / CtrlB / CtrlC / CtrlD 4-way NOV
import pipe_lane_signal_pkg::*;

module pipe_lane_mapper #(
    parameter int NL = 12,
    parameter int NC = 4,
    parameter bit SEL_SYNC = 1'b1   // pipe_lane_sel_gen's data-path pipe_lane_sel_sync SYNC, see there
) (
    input logic test_en,
    input logic [1:0] mode,
    input logic [NL-1:0] rx_clk,     // PHY's per-lane recovered clock
    output logic [NL-1:0] phy_pclk,
    output logic [NL-1:0] phy_rst_n,
    // PHY-side PIPE data
    output mac2phy_lane_t [NL-1:0] phy_mac2phy,
    input phy2mac_lane_t [NL-1:0] phy_phy2mac,
    // Controller side. Each controller's ports are declared at its own real max_width.
    // CtrlA x12
    input logic ctrla_rst_n,   // already synchronized externally
    input mac2phy_lane_t [11:0] ctrla_mac2phy,
    output phy2mac_lane_t [11:0] ctrla_phy2mac,
    input logic [11:0] ctrla_pclk,
    output logic [11:0] ctrla_rx_clk,
    // CtrlB x6
    input logic ctrlb_rst_n,   // already synchronized externally
    input mac2phy_lane_t [5:0] ctrlb_mac2phy,
    output phy2mac_lane_t [5:0] ctrlb_phy2mac,
    input logic [5:0] ctrlb_pclk,
    output logic [5:0] ctrlb_rx_clk,
    // CtrlC x8
    input logic ctrlc_rst_n,   // already synchronized externally
    input mac2phy_lane_t [7:0] ctrlc_mac2phy,
    output phy2mac_lane_t [7:0] ctrlc_phy2mac,
    input logic [7:0] ctrlc_pclk,
    output logic [7:0] ctrlc_rx_clk,
    // CtrlD x3
    input logic ctrld_rst_n,   // already synchronized externally
    input mac2phy_lane_t [2:0] ctrld_mac2phy,
    output phy2mac_lane_t [2:0] ctrld_phy2mac,
    input logic [2:0] ctrld_pclk,
    output logic [2:0] ctrld_rx_clk
);

    logic [NC-1:0] ctrl_rst_n;   // reconstructed from each controller's own named port above
    assign ctrl_rst_n = {ctrld_rst_n, ctrlc_rst_n, ctrlb_rst_n, ctrla_rst_n};
    lane_sel_t dec_tgt;   // each group's raw decoder selection (unsynchronized), used by rst_mux
    logic [1:0] seltgt_g1_l3;   // dec_tgt.g1 synchronized into the clock of the ctrl lane this lane routes to
    logic [1:0] seltgt_g1_l4;   // dec_tgt.g1 synchronized into the clock of the ctrl lane this lane routes to
    logic [1:0] seltgt_g1_l5;   // dec_tgt.g1 synchronized into the clock of the ctrl lane this lane routes to
    logic [1:0] seltgt_g2_l6;   // dec_tgt.g2 synchronized into the clock of the ctrl lane this lane routes to
    logic [1:0] seltgt_g2_l7;   // dec_tgt.g2 synchronized into the clock of the ctrl lane this lane routes to
    logic [1:0] seltgt_g2_l8;   // dec_tgt.g2 synchronized into the clock of the ctrl lane this lane routes to
    logic [3:0] seltgt_g3_l9;   // dec_tgt.g3 synchronized into the clock of the ctrl lane this lane routes to
    logic [3:0] seltgt_g3_l10;   // dec_tgt.g3 synchronized into the clock of the ctrl lane this lane routes to
    logic [3:0] seltgt_g3_l11;   // dec_tgt.g3 synchronized into the clock of the ctrl lane this lane routes to
    logic [1:0] rxclk_en_g1_l3;   // dec_tgt.g1 synchronized into rx_clk[3]'s domain
    logic [1:0] rxclk_en_g1_l4;   // dec_tgt.g1 synchronized into rx_clk[4]'s domain
    logic [1:0] rxclk_en_g1_l5;   // dec_tgt.g1 synchronized into rx_clk[5]'s domain
    logic [1:0] rxclk_en_g2_l6;   // dec_tgt.g2 synchronized into rx_clk[6]'s domain
    logic [1:0] rxclk_en_g2_l7;   // dec_tgt.g2 synchronized into rx_clk[7]'s domain
    logic [1:0] rxclk_en_g2_l8;   // dec_tgt.g2 synchronized into rx_clk[8]'s domain
    logic [3:0] rxclk_en_g3_l9;   // dec_tgt.g3 synchronized into rx_clk[9]'s domain
    logic [3:0] rxclk_en_g3_l10;   // dec_tgt.g3 synchronized into rx_clk[10]'s domain
    logic [3:0] rxclk_en_g3_l11;   // dec_tgt.g3 synchronized into rx_clk[11]'s domain

    //------------------------------------------------------------
    // Select-generation submodule: mode decoding + group pipe_lane_sel_sync, produces sel_tgt / dec_tgt
    //------------------------------------------------------------
    pipe_lane_sel_gen #(
        .NC (NC),
        .NL (NL),
        .SEL_SYNC (SEL_SYNC)
    ) u_sel_gen (
        .mode       (mode),
        .ctrla_pclk (ctrla_pclk),
        .ctrlb_pclk (ctrlb_pclk),
        .ctrlc_pclk (ctrlc_pclk),
        .ctrld_pclk (ctrld_pclk),
        .ctrl_rst_n (ctrl_rst_n),
        .rx_clk     (rx_clk),
        .dec_tgt    (dec_tgt),
        .seltgt_g1_l3 (seltgt_g1_l3),
        .seltgt_g1_l4 (seltgt_g1_l4),
        .seltgt_g1_l5 (seltgt_g1_l5),
        .seltgt_g2_l6 (seltgt_g2_l6),
        .seltgt_g2_l7 (seltgt_g2_l7),
        .seltgt_g2_l8 (seltgt_g2_l8),
        .seltgt_g3_l9 (seltgt_g3_l9),
        .seltgt_g3_l10 (seltgt_g3_l10),
        .seltgt_g3_l11 (seltgt_g3_l11),
        .rxclk_en_g1_l3 (rxclk_en_g1_l3),
        .rxclk_en_g1_l4 (rxclk_en_g1_l4),
        .rxclk_en_g1_l5 (rxclk_en_g1_l5),
        .rxclk_en_g2_l6 (rxclk_en_g2_l6),
        .rxclk_en_g2_l7 (rxclk_en_g2_l7),
        .rxclk_en_g2_l8 (rxclk_en_g2_l8),
        .rxclk_en_g3_l9 (rxclk_en_g3_l9),
        .rxclk_en_g3_l10 (rxclk_en_g3_l10),
        .rxclk_en_g3_l11 (rxclk_en_g3_l11)
    );

    //------------------------------------------------------------
    // Clock-mux submodule: glitch-free phy_pclk feedback switching + rx_clk routing
    //------------------------------------------------------------
    pipe_lane_clk_mux #(
        .NL (NL),
        .NC   (NC)
    ) u_clk_mux (
        .test_en      (test_en),
        .ctrl_rst_n   (ctrl_rst_n),
        .rx_clk       (rx_clk),
        .ctrla_pclk (ctrla_pclk),
        .ctrlb_pclk (ctrlb_pclk),
        .ctrlc_pclk (ctrlc_pclk),
        .ctrld_pclk (ctrld_pclk),
        .seltgt_g1_l3 (seltgt_g1_l3),
        .seltgt_g1_l4 (seltgt_g1_l4),
        .seltgt_g1_l5 (seltgt_g1_l5),
        .seltgt_g2_l6 (seltgt_g2_l6),
        .seltgt_g2_l7 (seltgt_g2_l7),
        .seltgt_g2_l8 (seltgt_g2_l8),
        .seltgt_g3_l9 (seltgt_g3_l9),
        .seltgt_g3_l10 (seltgt_g3_l10),
        .seltgt_g3_l11 (seltgt_g3_l11),
        .rxclk_en_g1_l3 (rxclk_en_g1_l3),
        .rxclk_en_g1_l4 (rxclk_en_g1_l4),
        .rxclk_en_g1_l5 (rxclk_en_g1_l5),
        .rxclk_en_g2_l6 (rxclk_en_g2_l6),
        .rxclk_en_g2_l7 (rxclk_en_g2_l7),
        .rxclk_en_g2_l8 (rxclk_en_g2_l8),
        .rxclk_en_g3_l9 (rxclk_en_g3_l9),
        .rxclk_en_g3_l10 (rxclk_en_g3_l10),
        .rxclk_en_g3_l11 (rxclk_en_g3_l11),
        .phy_pclk     (phy_pclk),
        .ctrla_rx_clk (ctrla_rx_clk),
        .ctrlb_rx_clk (ctrlb_rx_clk),
        .ctrlc_rx_clk (ctrlc_rx_clk),
        .ctrld_rx_clk (ctrld_rx_clk)
    );

    //------------------------------------------------------------
    // Reset-mux submodule: phy_rst_n selects ctrl_rst_n by current owner
    // Uses dec_tgt (the decoder's raw output, not synchronized by pipe_lane_sel_sync), not sel_tgt
    //------------------------------------------------------------
    pipe_lane_rst_mux #(
        .NL (NL),
        .NC   (NC)
    ) u_rst_mux (
        .ctrl_rst_n (ctrl_rst_n),
        .sel_tgt    (dec_tgt),
        .phy_rst_n  (phy_rst_n)
    );

    //------------------------------------------------------------
    // MAC->PHY data mux
    //------------------------------------------------------------
    pipe_lane_data_m2p #(
        .NL (NL)
    ) u_data_m2p (
        .seltgt_g1_l3 (seltgt_g1_l3),
        .seltgt_g1_l4 (seltgt_g1_l4),
        .seltgt_g1_l5 (seltgt_g1_l5),
        .seltgt_g2_l6 (seltgt_g2_l6),
        .seltgt_g2_l7 (seltgt_g2_l7),
        .seltgt_g2_l8 (seltgt_g2_l8),
        .seltgt_g3_l9 (seltgt_g3_l9),
        .seltgt_g3_l10 (seltgt_g3_l10),
        .seltgt_g3_l11 (seltgt_g3_l11),
        .phy_mac2phy  (phy_mac2phy),
        .ctrla_mac2phy (ctrla_mac2phy),
        .ctrlb_mac2phy (ctrlb_mac2phy),
        .ctrlc_mac2phy (ctrlc_mac2phy),
        .ctrld_mac2phy (ctrld_mac2phy)
    );

    //------------------------------------------------------------
    // PHY->MAC data mux
    //------------------------------------------------------------
    pipe_lane_data_p2m #(
        .NL (NL)
    ) u_data_p2m (
        .seltgt_g1_l3 (seltgt_g1_l3),
        .seltgt_g1_l4 (seltgt_g1_l4),
        .seltgt_g1_l5 (seltgt_g1_l5),
        .seltgt_g2_l6 (seltgt_g2_l6),
        .seltgt_g2_l7 (seltgt_g2_l7),
        .seltgt_g2_l8 (seltgt_g2_l8),
        .seltgt_g3_l9 (seltgt_g3_l9),
        .seltgt_g3_l10 (seltgt_g3_l10),
        .seltgt_g3_l11 (seltgt_g3_l11),
        .phy_phy2mac  (phy_phy2mac),
        .ctrla_phy2mac (ctrla_phy2mac),
        .ctrlb_phy2mac (ctrlb_phy2mac),
        .ctrlc_phy2mac (ctrlc_phy2mac),
        .ctrld_phy2mac (ctrld_phy2mac)
    );

endmodule
