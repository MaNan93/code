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

module pipe_lane_mapper_top #(
    parameter int NL = 12,
    parameter int NC = 4
) (
    input  logic [NC-1:0]   max_pclk,   // one external PLL clock per controller
    input  logic             test_en,
    input  logic [NC-1:0]   ctrl_rst_n,   // one per controller, already synchronized externally
    input  logic [1:0] mode,
    input  logic [NL-1:0]   rx_clk,     // PHY's per-lane recovered clock

    output logic [NC-1:0]   ctrl_pclk,
    output logic [NL-1:0]   phy_pclk_in,
    output logic [NL-1:0]   phy_rst_n,

    // PHY-side PIPE data
    output mac2phy_lane_t [NL-1:0] phy_mac2phy,
    input  phy2mac_lane_t [NL-1:0] phy_phy2mac,

    // Controller side. Each controller's ports are declared at its own real max_width.
    // CtrlA x12
    input  mac2phy_lane_t [11:0] ctrla_mac2phy,
    output phy2mac_lane_t [11:0] ctrla_phy2mac,
    input  logic [11:0] ctrla_pclk,
    output logic [11:0] ctrla_rx_clk,
    // CtrlB x6
    input  mac2phy_lane_t [5:0] ctrlb_mac2phy,
    output phy2mac_lane_t [5:0] ctrlb_phy2mac,
    input  logic [5:0] ctrlb_pclk,
    output logic [5:0] ctrlb_rx_clk,
    // CtrlC x8
    input  mac2phy_lane_t [7:0] ctrlc_mac2phy,
    output phy2mac_lane_t [7:0] ctrlc_phy2mac,
    input  logic [7:0] ctrlc_pclk,
    output logic [7:0] ctrlc_rx_clk,
    // CtrlD x3
    input  mac2phy_lane_t [2:0] ctrld_mac2phy,
    output phy2mac_lane_t [2:0] ctrld_phy2mac,
    input  logic [2:0] ctrld_pclk,
    output logic [2:0] ctrld_rx_clk
);

    lane_sel_t sel_tgt;   // each group's currently effective owner selection (after pipe_lane_sel_sync)
    lane_sel_t dec_tgt;   // each group's raw decoder selection (unsynchronized), used by rst_mux

    //------------------------------------------------------------
    // Select-generation submodule: mode decoding + group pipe_lane_sel_sync, produces sel_tgt / dec_tgt
    //------------------------------------------------------------
    pipe_lane_sel_gen #(
        .NC (NC)
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
        .max_pclk     (max_pclk),
        .test_en      (test_en),
        .ctrl_rst_n   (ctrl_rst_n),
        .dec_tgt      (dec_tgt),
        .sel_tgt      (sel_tgt),
        .rx_clk       (rx_clk),
        .ctrla_pclk (ctrla_pclk),
        .ctrlb_pclk (ctrlb_pclk),
        .ctrlc_pclk (ctrlc_pclk),
        .ctrld_pclk (ctrld_pclk),
        .ctrl_pclk    (ctrl_pclk),
        .phy_pclk_in  (phy_pclk_in),
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
        .sel_tgt      (sel_tgt),
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
        .sel_tgt      (sel_tgt),
        .phy_phy2mac  (phy_phy2mac),
        .ctrla_phy2mac (ctrla_phy2mac),
        .ctrlb_phy2mac (ctrlb_phy2mac),
        .ctrlc_phy2mac (ctrlc_phy2mac),
        .ctrld_phy2mac (ctrld_phy2mac)
    );

endmodule
