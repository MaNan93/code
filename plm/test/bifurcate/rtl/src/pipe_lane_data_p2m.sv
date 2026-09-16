// PIPE lane mapper PHY->MAC data mux (converges by controller lane).
// sel_tgt's mutual exclusivity is guaranteed by pipe_lane_sel_sync.
// Two distinct "nothing valid to show" values here, do not confuse them:
//   SAFE_P2M (from safe_state) -- this ctrl lane does have a driving PHY lane,
//                                 but no candidate owns it right now (NOV window).
//   {c}_p2m_tie (from tie_off)  -- this ctrl lane is never driven by any PHY lane.
import pipe_lane_signal_pkg::*;

module pipe_lane_data_p2m #(
    parameter int NL = 16
) (
    input lane_sel_t sel_tgt,
    input phy2mac_lane_t [NL-1:0] phy_phy2mac,
    output phy2mac_lane_t [15:0] ctrlx16_phy2mac,
    output phy2mac_lane_t [7:0] ctrlx8asdfadssssss_phy2mac,
    output phy2mac_lane_t [3:0] ctrlx4a_phy2mac,
    output phy2mac_lane_t [3:0] ctrlx4b_phy2mac
);

    // CtrlX16 x16
    phy2mac_lane_t ctrlx16_p2m_tie;
    assign ctrlx16_p2m_tie = '{
        phy_mac_messagebus: 8'h50,
        phy_mac_phystatus: phy_phy2mac[0].phy_mac_phystatus,
        default: '0
    };

    assign ctrlx16_phy2mac[0] = phy_phy2mac[0];  // direct connection to lane0
    assign ctrlx16_phy2mac[1] = phy_phy2mac[1];  // direct connection to lane1
    assign ctrlx16_phy2mac[2] = phy_phy2mac[2];  // direct connection to lane2
    assign ctrlx16_phy2mac[3] = phy_phy2mac[3];  // direct connection to lane3
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlx16_4 (
        .sel  (sel_tgt.g1),
        .din  ({ctrlx16_p2m_tie, phy_phy2mac[4]}),
        .safe (SAFE_P2M),
        .dout (ctrlx16_phy2mac[4])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlx16_5 (
        .sel  (sel_tgt.g1),
        .din  ({ctrlx16_p2m_tie, phy_phy2mac[5]}),
        .safe (SAFE_P2M),
        .dout (ctrlx16_phy2mac[5])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlx16_6 (
        .sel  (sel_tgt.g1),
        .din  ({ctrlx16_p2m_tie, phy_phy2mac[6]}),
        .safe (SAFE_P2M),
        .dout (ctrlx16_phy2mac[6])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlx16_7 (
        .sel  (sel_tgt.g1),
        .din  ({ctrlx16_p2m_tie, phy_phy2mac[7]}),
        .safe (SAFE_P2M),
        .dout (ctrlx16_phy2mac[7])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlx16_8 (
        .sel  (sel_tgt.g2),
        .din  ({ctrlx16_p2m_tie, phy_phy2mac[8]}),
        .safe (SAFE_P2M),
        .dout (ctrlx16_phy2mac[8])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlx16_9 (
        .sel  (sel_tgt.g2),
        .din  ({ctrlx16_p2m_tie, phy_phy2mac[9]}),
        .safe (SAFE_P2M),
        .dout (ctrlx16_phy2mac[9])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlx16_10 (
        .sel  (sel_tgt.g2),
        .din  ({ctrlx16_p2m_tie, phy_phy2mac[10]}),
        .safe (SAFE_P2M),
        .dout (ctrlx16_phy2mac[10])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlx16_11 (
        .sel  (sel_tgt.g2),
        .din  ({ctrlx16_p2m_tie, phy_phy2mac[11]}),
        .safe (SAFE_P2M),
        .dout (ctrlx16_phy2mac[11])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(3)) u_p2m_ctrlx16_12 (
        .sel  (sel_tgt.g3),
        .din  ({ctrlx16_p2m_tie, ctrlx16_p2m_tie, phy_phy2mac[12]}),
        .safe (SAFE_P2M),
        .dout (ctrlx16_phy2mac[12])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(3)) u_p2m_ctrlx16_13 (
        .sel  (sel_tgt.g3),
        .din  ({ctrlx16_p2m_tie, ctrlx16_p2m_tie, phy_phy2mac[13]}),
        .safe (SAFE_P2M),
        .dout (ctrlx16_phy2mac[13])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(3)) u_p2m_ctrlx16_14 (
        .sel  (sel_tgt.g3),
        .din  ({ctrlx16_p2m_tie, ctrlx16_p2m_tie, phy_phy2mac[14]}),
        .safe (SAFE_P2M),
        .dout (ctrlx16_phy2mac[14])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(3)) u_p2m_ctrlx16_15 (
        .sel  (sel_tgt.g3),
        .din  ({ctrlx16_p2m_tie, ctrlx16_p2m_tie, phy_phy2mac[15]}),
        .safe (SAFE_P2M),
        .dout (ctrlx16_phy2mac[15])
    );

    // CtrlX8asdfadssssss x8
    phy2mac_lane_t ctrlx8asdfadssssss_p2m_tie;
    assign ctrlx8asdfadssssss_p2m_tie = '{
        phy_mac_messagebus: 8'h50,
        phy_mac_phystatus: phy_phy2mac[8].phy_mac_phystatus,
        default: '0
    };

    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlx8asdfadssssss_0 (
        .sel  (sel_tgt.g2),
        .din  ({phy_phy2mac[8], ctrlx8asdfadssssss_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlx8asdfadssssss_phy2mac[0])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlx8asdfadssssss_1 (
        .sel  (sel_tgt.g2),
        .din  ({phy_phy2mac[9], ctrlx8asdfadssssss_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlx8asdfadssssss_phy2mac[1])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlx8asdfadssssss_2 (
        .sel  (sel_tgt.g2),
        .din  ({phy_phy2mac[10], ctrlx8asdfadssssss_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlx8asdfadssssss_phy2mac[2])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlx8asdfadssssss_3 (
        .sel  (sel_tgt.g2),
        .din  ({phy_phy2mac[11], ctrlx8asdfadssssss_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlx8asdfadssssss_phy2mac[3])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(3)) u_p2m_ctrlx8asdfadssssss_4 (
        .sel  (sel_tgt.g3),
        .din  ({ctrlx8asdfadssssss_p2m_tie, phy_phy2mac[12], ctrlx8asdfadssssss_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlx8asdfadssssss_phy2mac[4])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(3)) u_p2m_ctrlx8asdfadssssss_5 (
        .sel  (sel_tgt.g3),
        .din  ({ctrlx8asdfadssssss_p2m_tie, phy_phy2mac[13], ctrlx8asdfadssssss_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlx8asdfadssssss_phy2mac[5])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(3)) u_p2m_ctrlx8asdfadssssss_6 (
        .sel  (sel_tgt.g3),
        .din  ({ctrlx8asdfadssssss_p2m_tie, phy_phy2mac[14], ctrlx8asdfadssssss_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlx8asdfadssssss_phy2mac[6])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(3)) u_p2m_ctrlx8asdfadssssss_7 (
        .sel  (sel_tgt.g3),
        .din  ({ctrlx8asdfadssssss_p2m_tie, phy_phy2mac[15], ctrlx8asdfadssssss_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlx8asdfadssssss_phy2mac[7])
    );

    // CtrlX4a x4
    phy2mac_lane_t ctrlx4a_p2m_tie;
    assign ctrlx4a_p2m_tie = '{
        phy_mac_messagebus: 8'h50,
        phy_mac_phystatus: phy_phy2mac[4].phy_mac_phystatus,
        default: '0
    };

    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlx4a_0 (
        .sel  (sel_tgt.g1),
        .din  ({phy_phy2mac[4], ctrlx4a_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlx4a_phy2mac[0])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlx4a_1 (
        .sel  (sel_tgt.g1),
        .din  ({phy_phy2mac[5], ctrlx4a_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlx4a_phy2mac[1])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlx4a_2 (
        .sel  (sel_tgt.g1),
        .din  ({phy_phy2mac[6], ctrlx4a_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlx4a_phy2mac[2])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlx4a_3 (
        .sel  (sel_tgt.g1),
        .din  ({phy_phy2mac[7], ctrlx4a_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlx4a_phy2mac[3])
    );

    // CtrlX4b x4
    phy2mac_lane_t ctrlx4b_p2m_tie;
    assign ctrlx4b_p2m_tie = '{
        phy_mac_messagebus: 8'h50,
        phy_mac_phystatus: phy_phy2mac[12].phy_mac_phystatus,
        default: '0
    };

    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(3)) u_p2m_ctrlx4b_0 (
        .sel  (sel_tgt.g3),
        .din  ({phy_phy2mac[12], ctrlx4b_p2m_tie, ctrlx4b_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlx4b_phy2mac[0])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(3)) u_p2m_ctrlx4b_1 (
        .sel  (sel_tgt.g3),
        .din  ({phy_phy2mac[13], ctrlx4b_p2m_tie, ctrlx4b_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlx4b_phy2mac[1])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(3)) u_p2m_ctrlx4b_2 (
        .sel  (sel_tgt.g3),
        .din  ({phy_phy2mac[14], ctrlx4b_p2m_tie, ctrlx4b_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlx4b_phy2mac[2])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(3)) u_p2m_ctrlx4b_3 (
        .sel  (sel_tgt.g3),
        .din  ({phy_phy2mac[15], ctrlx4b_p2m_tie, ctrlx4b_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlx4b_phy2mac[3])
    );

endmodule
