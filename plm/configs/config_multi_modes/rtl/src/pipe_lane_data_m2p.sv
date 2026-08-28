//
// PIPE lane mapper MAC->PHY data mux.
// pipe_lane_data_mux performs polarity normalization internally; output is SAFE_M2P when sel is all-zero.
import pipe_pkg::*;

module pipe_lane_data_m2p #(
    parameter int NL = 4
) (
    input  lane_sel_t              sel_tgt,
    output mac2phy_lane_t [NL-1:0] phy_mac2phy,
    input  mac2phy_lane_t [3:0] pcie_x4_mac2phy,
    input  mac2phy_lane_t [3:0] usb_x2_mac2phy
);

    assign phy_mac2phy[0] = pcie_x4_mac2phy[0];  // direct connection
    assign phy_mac2phy[1] = pcie_x4_mac2phy[1];  // direct connection
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(2)) u_m2p_l2 (
        .sel  (sel_tgt.g1),
        .din  ({usb_x2_mac2phy[0], pcie_x4_mac2phy[2]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[2])
    );
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(2)) u_m2p_l3 (
        .sel  (sel_tgt.g1),
        .din  ({usb_x2_mac2phy[1], pcie_x4_mac2phy[3]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[3])
    );

endmodule
