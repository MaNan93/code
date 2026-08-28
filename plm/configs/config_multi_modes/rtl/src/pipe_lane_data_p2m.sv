//
// PIPE lane mapper PHY->MAC data mux (converges by controller port).
// sel_tgt's mutual exclusivity is guaranteed by sel_sync. Undriven ports are tied to the safe state.
import pipe_pkg::*;

module pipe_lane_data_p2m #(
    parameter int LANE_COUNT = 4
) (
    input  lane_sel_t              sel_tgt,
    input  phy2mac_lane_t [LANE_COUNT-1:0] phy_phy2mac,
    output phy2mac_lane_t [3:0] pcie_x4_phy2mac,
    output phy2mac_lane_t [3:0] usb_x2_phy2mac
);

    // PCIe_x4 x4
    phy2mac_lane_t pcie_x4_safe_p2m_align;
    assign pcie_x4_safe_p2m_align = '{
        phy_mac_rxelecidle: 1'b1,
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[0].phy_mac_phystatus,
        default: '0
    };

    assign pcie_x4_phy2mac[0] = phy_phy2mac[0];  // direct connection to lane0
    assign pcie_x4_phy2mac[1] = phy_phy2mac[1];  // direct connection to lane1
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_pcie_x4_2 (
        .sel  (sel_tgt.g1),
        .din  ({pcie_x4_safe_p2m_align, phy_phy2mac[2]}),
        .safe (pcie_x4_safe_p2m_align),
        .dout (pcie_x4_phy2mac[2])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_pcie_x4_3 (
        .sel  (sel_tgt.g1),
        .din  ({pcie_x4_safe_p2m_align, phy_phy2mac[3]}),
        .safe (pcie_x4_safe_p2m_align),
        .dout (pcie_x4_phy2mac[3])
    );

    // USB_x2 x2 (declared x4, ports 2..3 are fake lanes)
    phy2mac_lane_t usb_x2_safe_p2m_align;
    assign usb_x2_safe_p2m_align = '{
        phy_mac_rxelecidle: 1'b1,
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[2].phy_mac_phystatus,
        default: '0
    };

    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_usb_x2_0 (
        .sel  (sel_tgt.g1),
        .din  ({phy_phy2mac[2], usb_x2_safe_p2m_align}),
        .safe (usb_x2_safe_p2m_align),
        .dout (usb_x2_phy2mac[0])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_usb_x2_1 (
        .sel  (sel_tgt.g1),
        .din  ({phy_phy2mac[3], usb_x2_safe_p2m_align}),
        .safe (usb_x2_safe_p2m_align),
        .dout (usb_x2_phy2mac[1])
    );
    assign usb_x2_phy2mac[2] = '0;  // fake lane, port padding only
    assign usb_x2_phy2mac[3] = '0;  // fake lane, port padding only

endmodule
