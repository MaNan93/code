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
    input logic [NL-1:0] phy_pclk_out,
    input logic [1:0] mode,
    output logic [NL-1:0] phy_pclk_in,
    output logic [NL-1:0] phy_rst_n,
    // PHY-side PIPE data
    output mac2phy_lane_t [NL-1:0] phy_mac2phy,
    input phy2mac_lane_t [NL-1:0] phy_phy2mac,
    // DPR (diagnostic probe): a virtual controller with link width NL,
    // connected 1:1 to every PHY lane -- v_lane_mask[l]=1 overrides lane l.
    input logic [NL-1:0] v_lane_mask,
    input logic dpr_rst_n,
    input mac2phy_lane_t [NL-1:0] dpr_mac2phy,
    output phy2mac_lane_t [NL-1:0] dpr_phy2mac,
    output logic dpr_pclk,   // derived from PHY output clocks
    // Controller side. Each controller's ports are declared at its own real max_width.
    // CtrlA x12
    input logic ctrla_rst_n,   // already synchronized externally
    input mac2phy_lane_t [11:0] ctrla_mac2phy,
    output phy2mac_lane_t [11:0] ctrla_phy2mac,
    output logic ctrla_pclk,
    // CtrlB x6
    input logic ctrlb_rst_n,   // already synchronized externally
    input mac2phy_lane_t [5:0] ctrlb_mac2phy,
    output phy2mac_lane_t [5:0] ctrlb_phy2mac,
    output logic ctrlb_pclk,
    // CtrlC x8
    input logic ctrlc_rst_n,   // already synchronized externally
    input mac2phy_lane_t [7:0] ctrlc_mac2phy,
    output phy2mac_lane_t [7:0] ctrlc_phy2mac,
    output logic ctrlc_pclk,
    // CtrlD x3
    input logic ctrld_rst_n,   // already synchronized externally
    input mac2phy_lane_t [2:0] ctrld_mac2phy,
    output phy2mac_lane_t [2:0] ctrld_phy2mac,
    output logic ctrld_pclk
);

    logic [NC-1:0] ctrl_rst_n;   // reconstructed from each controller's own named port above
    assign ctrl_rst_n = {ctrld_rst_n, ctrlc_rst_n, ctrlb_rst_n, ctrla_rst_n};
    logic [NC-1:0] ctrl_pclk;   // driven by u_clk_mux below, flattened out to each controller's own named port
    lane_sel_t sel_tgt;   // each group's currently effective owner selection (after pipe_lane_sel_sync)
    lane_sel_t dec_tgt;   // each group's raw decoder selection (unsynchronized, DPR-combined), used by rst_mux

    //------------------------------------------------------------
    // Select-generation submodule: mode decoding + group pipe_lane_sel_sync, produces sel_tgt / dec_tgt
    //------------------------------------------------------------
    pipe_lane_sel_gen #(
        .NC (NC),
        .NL (NL),
        .SEL_SYNC (SEL_SYNC)
    ) u_sel_gen (
        .mode       (mode),
        .ctrl_pclk  (ctrl_pclk),
        .ctrl_rst_n (ctrl_rst_n),
        .sel_tgt    (sel_tgt),
        .v_lane_mask (v_lane_mask),
        .dpr_rst_n   (dpr_rst_n),
        .dpr_pclk    (dpr_pclk),
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
        .ctrl_rst_n   (ctrl_rst_n),
        .sel_tgt      (sel_tgt),
        .v_lane_mask  (v_lane_mask),
        .dpr_rst_n    (dpr_rst_n),
        .ctrl_pclk    (ctrl_pclk),
        .dpr_pclk     (dpr_pclk),
        .phy_pclk_in  (phy_pclk_in)
    );

    assign ctrla_pclk = ctrl_pclk[0];
    assign ctrlb_pclk = ctrl_pclk[1];
    assign ctrlc_pclk = ctrl_pclk[2];
    assign ctrld_pclk = ctrl_pclk[3];

    //------------------------------------------------------------
    // Reset-mux submodule: phy_rst_n selects ctrl_rst_n by current owner
    // Uses dec_tgt (the decoder's raw output, not synchronized by pipe_lane_sel_sync), not sel_tgt
    //------------------------------------------------------------
    pipe_lane_rst_mux #(
        .NL (NL),
        .NC   (NC)
    ) u_rst_mux (
        .ctrl_rst_n (ctrl_rst_n),
        .dpr_rst_n  (dpr_rst_n),
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
        .dpr_mac2phy  (dpr_mac2phy),
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
        .sel_tgt      (sel_tgt),
        .phy_phy2mac  (phy_phy2mac),
        .dpr_phy2mac  (dpr_phy2mac),
        .ctrla_phy2mac (ctrla_phy2mac),
        .ctrlb_phy2mac (ctrlb_phy2mac),
        .ctrlc_phy2mac (ctrlc_phy2mac),
        .ctrld_phy2mac (ctrld_phy2mac)
    );

endmodule
