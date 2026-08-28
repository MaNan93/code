//
// PIPE lane mapper PHY->MAC data mux (converges by controller port).
// sel_tgt's mutual exclusivity is guaranteed by sel_sync. Undriven ports are tied to the safe state.
import pipe_pkg::*;

module pipe_lane_data_p2m #(
    parameter int LANE_COUNT = 16
) (
    input  lane_sel_t              sel_tgt,
    input  phy2mac_lane_t [LANE_COUNT-1:0] phy_phy2mac,
    output phy2mac_lane_t [15:0] ctrl0_phy2mac,
    output phy2mac_lane_t [3:0] ctrl1_phy2mac,
    output phy2mac_lane_t [7:0] ctrl2_phy2mac,
    output phy2mac_lane_t [3:0] ctrl3_phy2mac
);

    // Ctrl0 x16
    phy2mac_lane_t ctrl0_safe_p2m_align;
    assign ctrl0_safe_p2m_align = '{
        phy_mac_rxelecidle: 1'b1,
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[0].phy_mac_phystatus,
        default: '0
    };

    assign ctrl0_phy2mac[0] = phy_phy2mac[0];  // direct connection to lane0
    assign ctrl0_phy2mac[1] = phy_phy2mac[1];  // direct connection to lane1
    assign ctrl0_phy2mac[2] = phy_phy2mac[2];  // direct connection to lane2
    assign ctrl0_phy2mac[3] = phy_phy2mac[3];  // direct connection to lane3
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrl0_4 (
        .sel  (sel_tgt.g1),
        .din  ({ctrl0_safe_p2m_align, phy_phy2mac[4]}),
        .safe (ctrl0_safe_p2m_align),
        .dout (ctrl0_phy2mac[4])
    );
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrl0_5 (
        .sel  (sel_tgt.g1),
        .din  ({ctrl0_safe_p2m_align, phy_phy2mac[5]}),
        .safe (ctrl0_safe_p2m_align),
        .dout (ctrl0_phy2mac[5])
    );
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrl0_6 (
        .sel  (sel_tgt.g1),
        .din  ({ctrl0_safe_p2m_align, phy_phy2mac[6]}),
        .safe (ctrl0_safe_p2m_align),
        .dout (ctrl0_phy2mac[6])
    );
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrl0_7 (
        .sel  (sel_tgt.g1),
        .din  ({ctrl0_safe_p2m_align, phy_phy2mac[7]}),
        .safe (ctrl0_safe_p2m_align),
        .dout (ctrl0_phy2mac[7])
    );
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrl0_8 (
        .sel  (sel_tgt.g2),
        .din  ({ctrl0_safe_p2m_align, phy_phy2mac[8]}),
        .safe (ctrl0_safe_p2m_align),
        .dout (ctrl0_phy2mac[8])
    );
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrl0_9 (
        .sel  (sel_tgt.g2),
        .din  ({ctrl0_safe_p2m_align, phy_phy2mac[9]}),
        .safe (ctrl0_safe_p2m_align),
        .dout (ctrl0_phy2mac[9])
    );
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrl0_10 (
        .sel  (sel_tgt.g2),
        .din  ({ctrl0_safe_p2m_align, phy_phy2mac[10]}),
        .safe (ctrl0_safe_p2m_align),
        .dout (ctrl0_phy2mac[10])
    );
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrl0_11 (
        .sel  (sel_tgt.g2),
        .din  ({ctrl0_safe_p2m_align, phy_phy2mac[11]}),
        .safe (ctrl0_safe_p2m_align),
        .dout (ctrl0_phy2mac[11])
    );
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(3)) u_p2m_ctrl0_12 (
        .sel  (sel_tgt.g3),
        .din  ({ctrl0_safe_p2m_align, ctrl0_safe_p2m_align, phy_phy2mac[12]}),
        .safe (ctrl0_safe_p2m_align),
        .dout (ctrl0_phy2mac[12])
    );
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(3)) u_p2m_ctrl0_13 (
        .sel  (sel_tgt.g3),
        .din  ({ctrl0_safe_p2m_align, ctrl0_safe_p2m_align, phy_phy2mac[13]}),
        .safe (ctrl0_safe_p2m_align),
        .dout (ctrl0_phy2mac[13])
    );
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(3)) u_p2m_ctrl0_14 (
        .sel  (sel_tgt.g3),
        .din  ({ctrl0_safe_p2m_align, ctrl0_safe_p2m_align, phy_phy2mac[14]}),
        .safe (ctrl0_safe_p2m_align),
        .dout (ctrl0_phy2mac[14])
    );
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(3)) u_p2m_ctrl0_15 (
        .sel  (sel_tgt.g3),
        .din  ({ctrl0_safe_p2m_align, ctrl0_safe_p2m_align, phy_phy2mac[15]}),
        .safe (ctrl0_safe_p2m_align),
        .dout (ctrl0_phy2mac[15])
    );

    // Ctrl1 x4
    phy2mac_lane_t ctrl1_safe_p2m_align;
    assign ctrl1_safe_p2m_align = '{
        phy_mac_rxelecidle: 1'b1,
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[4].phy_mac_phystatus,
        default: '0
    };

    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrl1_0 (
        .sel  (sel_tgt.g1),
        .din  ({phy_phy2mac[4], ctrl1_safe_p2m_align}),
        .safe (ctrl1_safe_p2m_align),
        .dout (ctrl1_phy2mac[0])
    );
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrl1_1 (
        .sel  (sel_tgt.g1),
        .din  ({phy_phy2mac[5], ctrl1_safe_p2m_align}),
        .safe (ctrl1_safe_p2m_align),
        .dout (ctrl1_phy2mac[1])
    );
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrl1_2 (
        .sel  (sel_tgt.g1),
        .din  ({phy_phy2mac[6], ctrl1_safe_p2m_align}),
        .safe (ctrl1_safe_p2m_align),
        .dout (ctrl1_phy2mac[2])
    );
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrl1_3 (
        .sel  (sel_tgt.g1),
        .din  ({phy_phy2mac[7], ctrl1_safe_p2m_align}),
        .safe (ctrl1_safe_p2m_align),
        .dout (ctrl1_phy2mac[3])
    );

    // Ctrl2 x8
    phy2mac_lane_t ctrl2_safe_p2m_align;
    assign ctrl2_safe_p2m_align = '{
        phy_mac_rxelecidle: 1'b1,
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[8].phy_mac_phystatus,
        default: '0
    };

    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrl2_0 (
        .sel  (sel_tgt.g2),
        .din  ({phy_phy2mac[8], ctrl2_safe_p2m_align}),
        .safe (ctrl2_safe_p2m_align),
        .dout (ctrl2_phy2mac[0])
    );
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrl2_1 (
        .sel  (sel_tgt.g2),
        .din  ({phy_phy2mac[9], ctrl2_safe_p2m_align}),
        .safe (ctrl2_safe_p2m_align),
        .dout (ctrl2_phy2mac[1])
    );
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrl2_2 (
        .sel  (sel_tgt.g2),
        .din  ({phy_phy2mac[10], ctrl2_safe_p2m_align}),
        .safe (ctrl2_safe_p2m_align),
        .dout (ctrl2_phy2mac[2])
    );
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrl2_3 (
        .sel  (sel_tgt.g2),
        .din  ({phy_phy2mac[11], ctrl2_safe_p2m_align}),
        .safe (ctrl2_safe_p2m_align),
        .dout (ctrl2_phy2mac[3])
    );
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(3)) u_p2m_ctrl2_4 (
        .sel  (sel_tgt.g3),
        .din  ({ctrl2_safe_p2m_align, phy_phy2mac[12], ctrl2_safe_p2m_align}),
        .safe (ctrl2_safe_p2m_align),
        .dout (ctrl2_phy2mac[4])
    );
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(3)) u_p2m_ctrl2_5 (
        .sel  (sel_tgt.g3),
        .din  ({ctrl2_safe_p2m_align, phy_phy2mac[13], ctrl2_safe_p2m_align}),
        .safe (ctrl2_safe_p2m_align),
        .dout (ctrl2_phy2mac[5])
    );
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(3)) u_p2m_ctrl2_6 (
        .sel  (sel_tgt.g3),
        .din  ({ctrl2_safe_p2m_align, phy_phy2mac[14], ctrl2_safe_p2m_align}),
        .safe (ctrl2_safe_p2m_align),
        .dout (ctrl2_phy2mac[6])
    );
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(3)) u_p2m_ctrl2_7 (
        .sel  (sel_tgt.g3),
        .din  ({ctrl2_safe_p2m_align, phy_phy2mac[15], ctrl2_safe_p2m_align}),
        .safe (ctrl2_safe_p2m_align),
        .dout (ctrl2_phy2mac[7])
    );

    // Ctrl3 x4
    phy2mac_lane_t ctrl3_safe_p2m_align;
    assign ctrl3_safe_p2m_align = '{
        phy_mac_rxelecidle: 1'b1,
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[12].phy_mac_phystatus,
        default: '0
    };

    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(3)) u_p2m_ctrl3_0 (
        .sel  (sel_tgt.g3),
        .din  ({phy_phy2mac[12], ctrl3_safe_p2m_align, ctrl3_safe_p2m_align}),
        .safe (ctrl3_safe_p2m_align),
        .dout (ctrl3_phy2mac[0])
    );
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(3)) u_p2m_ctrl3_1 (
        .sel  (sel_tgt.g3),
        .din  ({phy_phy2mac[13], ctrl3_safe_p2m_align, ctrl3_safe_p2m_align}),
        .safe (ctrl3_safe_p2m_align),
        .dout (ctrl3_phy2mac[1])
    );
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(3)) u_p2m_ctrl3_2 (
        .sel  (sel_tgt.g3),
        .din  ({phy_phy2mac[14], ctrl3_safe_p2m_align, ctrl3_safe_p2m_align}),
        .safe (ctrl3_safe_p2m_align),
        .dout (ctrl3_phy2mac[2])
    );
    onehot_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(3)) u_p2m_ctrl3_3 (
        .sel  (sel_tgt.g3),
        .din  ({phy_phy2mac[15], ctrl3_safe_p2m_align, ctrl3_safe_p2m_align}),
        .safe (ctrl3_safe_p2m_align),
        .dout (ctrl3_phy2mac[3])
    );

endmodule
