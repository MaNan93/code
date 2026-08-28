//
// PIPE lane mapper top level.
//
// Pure instantiation layer:
//   pipe_lane_sel_gen  -- mode decoding + group sel_sync, produces sel_tgt
//   pipe_lane_clk_mux  -- controller pclk generation + feedback clock mux
//   pipe_lane_rst_mux  -- feedback reset mux
//   pipe_lane_data_m2p -- MAC->PHY data mux
//   pipe_lane_data_p2m -- PHY->MAC data mux
//
// Lane grouping: lanes with the same owner sequence are grouped automatically, sharing one BBM.
//
//   G0 lane0~3        Ctrl0 / Ctrl0 / Ctrl0 / Ctrl0 direct
//   G1 lane4~7        Ctrl0 / Ctrl0 / Ctrl0 / Ctrl1 2-way BBM
//   G2 lane8~11       Ctrl0 / Ctrl2 / Ctrl2 / Ctrl2 2-way BBM
//   G3 lane12~15      Ctrl0 / Ctrl2 / Ctrl3 / Ctrl3 3-way BBM
import pipe_pkg::*;

module pipe_lane_mapper_top #(
    parameter int NUM_MODES  = 4,
    parameter int LANE_COUNT = 16,
    parameter int NUM_CTRL   = 4
) (
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [LANE_COUNT-1:0] phy_pclk_out,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic                  test_en,
    input  logic [NUM_CTRL-1:0]   ctrl_rst_n,   // one per controller, already synchronized externally
    input  logic [$clog2(NUM_MODES)-1:0] mode,

    output logic [NUM_CTRL-1:0]   ctrl_pclk,
    output logic [LANE_COUNT-1:0] phy_pclk_in,
    output logic [LANE_COUNT-1:0] phy_rst_n,

    // PHY-side PIPE data
    output mac2phy_lane_t [LANE_COUNT-1:0] phy_mac2phy,
    input  phy2mac_lane_t [LANE_COUNT-1:0] phy_phy2mac,

    // Controller side, each at its real width
    // Ctrl0 x16
    input  mac2phy_lane_t [15:0] ctrl0_mac2phy,
    output phy2mac_lane_t [15:0] ctrl0_phy2mac,
    // Ctrl1 x4
    input  mac2phy_lane_t [3:0] ctrl1_mac2phy,
    output phy2mac_lane_t [3:0] ctrl1_phy2mac,
    // Ctrl2 x8
    input  mac2phy_lane_t [7:0] ctrl2_mac2phy,
    output phy2mac_lane_t [7:0] ctrl2_phy2mac,
    // Ctrl3 x4
    input  mac2phy_lane_t [3:0] ctrl3_mac2phy,
    output phy2mac_lane_t [3:0] ctrl3_phy2mac
);

    lane_sel_t sel_tgt;   // each group's currently effective owner selection (after sel_sync)
    lane_sel_t dec_tgt;   // each group's raw decoder selection (unsynchronized), used by rst_mux

    //------------------------------------------------------------
    // Select-generation submodule: mode decoding + group sel_sync, produces sel_tgt / dec_tgt
    //------------------------------------------------------------
    pipe_lane_sel_gen #(
        .NUM_MODES (NUM_MODES),
        .NUM_CTRL  (NUM_CTRL)
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
        .LANE_COUNT (LANE_COUNT),
        .NUM_CTRL   (NUM_CTRL)
    ) u_clk_mux (
        .phy_pclk_out (phy_pclk_out),
        .test_en      (test_en),
        .ctrl_rst_n   (ctrl_rst_n),
        .sel_tgt      (sel_tgt),
        .ctrl_pclk    (ctrl_pclk),
        .phy_pclk_in  (phy_pclk_in)
    );

    //------------------------------------------------------------
    // Feedback reset-mux submodule: phy_rst_n selects ctrl_rst_n by current owner
    // Uses dec_tgt (the decoder's raw output, not synchronized by sel_sync), not sel_tgt
    //------------------------------------------------------------
    pipe_lane_rst_mux #(
        .LANE_COUNT (LANE_COUNT),
        .NUM_CTRL   (NUM_CTRL)
    ) u_rst_mux (
        .ctrl_rst_n (ctrl_rst_n),
        .sel_tgt    (dec_tgt),
        .phy_rst_n  (phy_rst_n)
    );

    //------------------------------------------------------------
    // MAC->PHY data mux
    //------------------------------------------------------------
    pipe_lane_data_m2p #(
        .LANE_COUNT (LANE_COUNT)
    ) u_data_m2p (
        .sel_tgt      (sel_tgt),
        .phy_mac2phy  (phy_mac2phy),
        .ctrl0_mac2phy (ctrl0_mac2phy),
        .ctrl1_mac2phy (ctrl1_mac2phy),
        .ctrl2_mac2phy (ctrl2_mac2phy),
        .ctrl3_mac2phy (ctrl3_mac2phy)
    );

    //------------------------------------------------------------
    // PHY->MAC data mux
    //------------------------------------------------------------
    pipe_lane_data_p2m #(
        .LANE_COUNT (LANE_COUNT)
    ) u_data_p2m (
        .sel_tgt      (sel_tgt),
        .phy_phy2mac  (phy_phy2mac),
        .ctrl0_phy2mac (ctrl0_phy2mac),
        .ctrl1_phy2mac (ctrl1_phy2mac),
        .ctrl2_phy2mac (ctrl2_phy2mac),
        .ctrl3_phy2mac (ctrl3_phy2mac)
    );

endmodule
