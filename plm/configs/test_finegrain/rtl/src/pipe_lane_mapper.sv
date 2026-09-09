// PIPE lane mapper top level.
//
// Pure instantiation layer:
//   pipe_lane_sel_gen  -- mode decoding + group pipe_lane_sel_sync, produces sel_tgt
//   pipe_lane_clk_mux  -- controller pclk generation + feedback clock mux
//   pipe_lane_rst_mux  -- reset mux
//   pipe_lane_data_m2p -- MAC->PHY data mux
//   pipe_lane_data_p2m -- PHY->MAC data mux
//
// Lane grouping: lanes with the same owner sequence are grouped automatically, sharing one NOV.
//
//   G0 lane0          CtrlAlpha / CtrlAlpha / CtrlAlpha direct
//   G1 lane1          CtrlAlpha / CtrlDelta / CtrlAlpha 2-way NOV
//   G2 lane2          CtrlAlpha / CtrlEpsilon / CtrlEpsilon 2-way NOV
//   G3 lane3          CtrlBeta / CtrlBeta / CtrlBeta direct
//   G4 lane4          CtrlBeta / CtrlZeta / CtrlBeta 2-way NOV
//   G5 lane5          CtrlGamma / CtrlGamma / CtrlGamma direct
import pipe_lane_signal_pkg::*;

module pipe_lane_mapper #(
    parameter int NL = 6,
    parameter int NC = 6,
    parameter bit SEL_SYNC = 1'b1   // pipe_lane_sel_gen's data-path pipe_lane_sel_sync SYNC, see there
) (
    input logic [NL-1:0] phy_pclk_out,
    input logic test_en,
    input logic [NC-1:0] ctrl_rst_n,   // one per controller, already synchronized externally
    input logic [1:0] mode,
    output logic [NC-1:0] ctrl_pclk,
    output logic [NL-1:0] phy_pclk_in,
    output logic [NL-1:0] phy_rst_n,
    // PHY-side PIPE data
    output mac2phy_lane_t [NL-1:0] phy_mac2phy,
    input phy2mac_lane_t [NL-1:0] phy_phy2mac,
    // Controller side. Each controller's ports are declared at its own real max_width.
    // CtrlAlpha x3
    input mac2phy_lane_t [2:0] ctrlalpha_mac2phy,
    output phy2mac_lane_t [2:0] ctrlalpha_phy2mac,
    // CtrlBeta x2
    input mac2phy_lane_t [1:0] ctrlbeta_mac2phy,
    output phy2mac_lane_t [1:0] ctrlbeta_phy2mac,
    // CtrlGamma x1
    input mac2phy_lane_t [0:0] ctrlgamma_mac2phy,
    output phy2mac_lane_t [0:0] ctrlgamma_phy2mac,
    // CtrlDelta x1
    input mac2phy_lane_t [0:0] ctrldelta_mac2phy,
    output phy2mac_lane_t [0:0] ctrldelta_phy2mac,
    // CtrlEpsilon x1
    input mac2phy_lane_t [0:0] ctrlepsilon_mac2phy,
    output phy2mac_lane_t [0:0] ctrlepsilon_phy2mac,
    // CtrlZeta x1
    input mac2phy_lane_t [0:0] ctrlzeta_mac2phy,
    output phy2mac_lane_t [0:0] ctrlzeta_phy2mac
);

    lane_sel_t sel_tgt;   // each group's currently effective owner selection (after pipe_lane_sel_sync)
    lane_sel_t dec_tgt;   // each group's raw decoder selection (unsynchronized), used by rst_mux

    //------------------------------------------------------------
    // Select-generation submodule: mode decoding + group pipe_lane_sel_sync, produces sel_tgt / dec_tgt
    //------------------------------------------------------------
    pipe_lane_sel_gen #(
        .NC (NC),
        .SEL_SYNC (SEL_SYNC)
    ) u_sel_gen (
        .mode       (mode),
        .ctrl_pclk  (ctrl_pclk),
        .ctrl_rst_n (ctrl_rst_n),
        .sel_tgt    (sel_tgt),
        .dec_tgt    (dec_tgt)
    );

    //------------------------------------------------------------
    // Clock-mux submodule: ctrl_pclk generation + feedback clock mux
    //------------------------------------------------------------
    pipe_lane_clk_mux #(
        .NL (NL),
        .NC   (NC)
    ) u_clk_mux (
        .phy_pclk_out (phy_pclk_out),
        .test_en      (test_en),
        .ctrl_rst_n   (ctrl_rst_n),
        .sel_tgt      (sel_tgt),
        .ctrl_pclk    (ctrl_pclk),
        .phy_pclk_in  (phy_pclk_in)
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
        .sel_tgt      (sel_tgt),
        .phy_mac2phy  (phy_mac2phy),
        .ctrlalpha_mac2phy (ctrlalpha_mac2phy),
        .ctrlbeta_mac2phy (ctrlbeta_mac2phy),
        .ctrlgamma_mac2phy (ctrlgamma_mac2phy),
        .ctrldelta_mac2phy (ctrldelta_mac2phy),
        .ctrlepsilon_mac2phy (ctrlepsilon_mac2phy),
        .ctrlzeta_mac2phy (ctrlzeta_mac2phy)
    );

    //------------------------------------------------------------
    // PHY->MAC data mux
    //------------------------------------------------------------
    pipe_lane_data_p2m #(
        .NL (NL)
    ) u_data_p2m (
        .sel_tgt      (sel_tgt),
        .phy_phy2mac  (phy_phy2mac),
        .ctrlalpha_phy2mac (ctrlalpha_phy2mac),
        .ctrlbeta_phy2mac (ctrlbeta_phy2mac),
        .ctrlgamma_phy2mac (ctrlgamma_phy2mac),
        .ctrldelta_phy2mac (ctrldelta_phy2mac),
        .ctrlepsilon_phy2mac (ctrlepsilon_phy2mac),
        .ctrlzeta_phy2mac (ctrlzeta_phy2mac)
    );

endmodule
