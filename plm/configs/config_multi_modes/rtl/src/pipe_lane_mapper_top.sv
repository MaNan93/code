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
//   G0 lane0~1        PCIe_x4 / PCIe_x4        direct
//   G1 lane2~3        PCIe_x4 / USB_x2         2-way BBM
import pipe_pkg::*;

module pipe_lane_mapper_top #(
    parameter int NM = 2,
    parameter int NL = 4,
    parameter int NC = 2
) (
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [NL-1:0] phy_pclk_out,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic                  test_en,
    input  logic [NC-1:0]   ctrl_rst_n,   // one per controller, already synchronized externally
    input  logic [$clog2(NM)-1:0] mode,

    output logic [NC-1:0]   ctrl_pclk,
    output logic [NL-1:0] phy_pclk_in,
    output logic [NL-1:0] phy_rst_n,

    // PHY-side PIPE data
    output mac2phy_lane_t [NL-1:0] phy_mac2phy,
    input  phy2mac_lane_t [NL-1:0] phy_phy2mac,

    // Controller side. Every controller's ports are declared at a uniform
    // width x4 (the widest controller in this config) for ease of
    // connection; a controller whose real width is narrower has fake lanes
    // at its high-numbered ports -- see each controller's comment below.
    // PCIe_x4 x4
    input  mac2phy_lane_t [3:0] pcie_x4_mac2phy,
    output phy2mac_lane_t [3:0] pcie_x4_phy2mac,
    // USB_x2 x2 (declared x4, ports 2..3 are fake lanes)
    input  mac2phy_lane_t [3:0] usb_x2_mac2phy,
    output phy2mac_lane_t [3:0] usb_x2_phy2mac
);

    lane_sel_t sel_tgt;   // each group's currently effective owner selection (after sel_sync)
    lane_sel_t dec_tgt;   // each group's raw decoder selection (unsynchronized), used by rst_mux

    //------------------------------------------------------------
    // Select-generation submodule: mode decoding + group sel_sync, produces sel_tgt / dec_tgt
    //------------------------------------------------------------
    pipe_lane_sel_gen #(
        .NM (NM),
        .NC  (NC)
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
    // Feedback reset-mux submodule: phy_rst_n selects ctrl_rst_n by current owner
    // Uses dec_tgt (the decoder's raw output, not synchronized by sel_sync), not sel_tgt
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
        .pcie_x4_mac2phy (pcie_x4_mac2phy),
        .usb_x2_mac2phy (usb_x2_mac2phy)
    );

    //------------------------------------------------------------
    // PHY->MAC data mux
    //------------------------------------------------------------
    pipe_lane_data_p2m #(
        .NL (NL)
    ) u_data_p2m (
        .sel_tgt      (sel_tgt),
        .phy_phy2mac  (phy_phy2mac),
        .pcie_x4_phy2mac (pcie_x4_phy2mac),
        .usb_x2_phy2mac (usb_x2_phy2mac)
    );

endmodule
