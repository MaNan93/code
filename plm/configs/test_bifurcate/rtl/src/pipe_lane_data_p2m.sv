//
// PIPE lane mapper PHY->MAC data mux (converges by controller port).
// sel_tgt's mutual exclusivity is guaranteed by pipe_lane_sel_sync. Undriven ports are tied to the safe state.
import pipe_lane_signal_pkg::*;

module pipe_lane_data_p2m #(
    parameter int NL = 16
) (
    input  lane_sel_t              sel_tgt,
    input  phy2mac_lane_t [NL-1:0] phy_phy2mac,
    output phy2mac_lane_t [15:0] ctrlx16_phy2mac,
    output phy2mac_lane_t [15:0] ctrlx8_phy2mac,
    output phy2mac_lane_t [15:0] ctrlx4a_phy2mac,
    output phy2mac_lane_t [15:0] ctrlx4b_phy2mac
);

    // CtrlX16 x16
    phy2mac_lane_t ctrlx16_safe_p2m_align;
    assign ctrlx16_safe_p2m_align = '{
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[0].phy_mac_phystatus,
        default: '0
    };

    assign ctrlx16_phy2mac[0] = phy_phy2mac[0];  // direct connection to lane0
    assign ctrlx16_phy2mac[1] = phy_phy2mac[1];  // direct connection to lane1
    assign ctrlx16_phy2mac[2] = phy_phy2mac[2];  // direct connection to lane2
    assign ctrlx16_phy2mac[3] = phy_phy2mac[3];  // direct connection to lane3
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlx16_4 (
        .sel  (sel_tgt.g1),
        .din  ({ctrlx16_safe_p2m_align, phy_phy2mac[4]}),
        .safe (ctrlx16_safe_p2m_align),
        .dout (ctrlx16_phy2mac[4])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlx16_5 (
        .sel  (sel_tgt.g1),
        .din  ({ctrlx16_safe_p2m_align, phy_phy2mac[5]}),
        .safe (ctrlx16_safe_p2m_align),
        .dout (ctrlx16_phy2mac[5])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlx16_6 (
        .sel  (sel_tgt.g1),
        .din  ({ctrlx16_safe_p2m_align, phy_phy2mac[6]}),
        .safe (ctrlx16_safe_p2m_align),
        .dout (ctrlx16_phy2mac[6])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlx16_7 (
        .sel  (sel_tgt.g1),
        .din  ({ctrlx16_safe_p2m_align, phy_phy2mac[7]}),
        .safe (ctrlx16_safe_p2m_align),
        .dout (ctrlx16_phy2mac[7])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlx16_8 (
        .sel  (sel_tgt.g2),
        .din  ({ctrlx16_safe_p2m_align, phy_phy2mac[8]}),
        .safe (ctrlx16_safe_p2m_align),
        .dout (ctrlx16_phy2mac[8])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlx16_9 (
        .sel  (sel_tgt.g2),
        .din  ({ctrlx16_safe_p2m_align, phy_phy2mac[9]}),
        .safe (ctrlx16_safe_p2m_align),
        .dout (ctrlx16_phy2mac[9])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlx16_10 (
        .sel  (sel_tgt.g2),
        .din  ({ctrlx16_safe_p2m_align, phy_phy2mac[10]}),
        .safe (ctrlx16_safe_p2m_align),
        .dout (ctrlx16_phy2mac[10])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlx16_11 (
        .sel  (sel_tgt.g2),
        .din  ({ctrlx16_safe_p2m_align, phy_phy2mac[11]}),
        .safe (ctrlx16_safe_p2m_align),
        .dout (ctrlx16_phy2mac[11])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(3)) u_p2m_ctrlx16_12 (
        .sel  (sel_tgt.g3),
        .din  ({ctrlx16_safe_p2m_align, ctrlx16_safe_p2m_align, phy_phy2mac[12]}),
        .safe (ctrlx16_safe_p2m_align),
        .dout (ctrlx16_phy2mac[12])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(3)) u_p2m_ctrlx16_13 (
        .sel  (sel_tgt.g3),
        .din  ({ctrlx16_safe_p2m_align, ctrlx16_safe_p2m_align, phy_phy2mac[13]}),
        .safe (ctrlx16_safe_p2m_align),
        .dout (ctrlx16_phy2mac[13])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(3)) u_p2m_ctrlx16_14 (
        .sel  (sel_tgt.g3),
        .din  ({ctrlx16_safe_p2m_align, ctrlx16_safe_p2m_align, phy_phy2mac[14]}),
        .safe (ctrlx16_safe_p2m_align),
        .dout (ctrlx16_phy2mac[14])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(3)) u_p2m_ctrlx16_15 (
        .sel  (sel_tgt.g3),
        .din  ({ctrlx16_safe_p2m_align, ctrlx16_safe_p2m_align, phy_phy2mac[15]}),
        .safe (ctrlx16_safe_p2m_align),
        .dout (ctrlx16_phy2mac[15])
    );

    // CtrlX8 x8 (declared x16, ports 8..15 are fake lanes)
    phy2mac_lane_t ctrlx8_safe_p2m_align;
    assign ctrlx8_safe_p2m_align = '{
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[8].phy_mac_phystatus,
        default: '0
    };

    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlx8_0 (
        .sel  (sel_tgt.g2),
        .din  ({phy_phy2mac[8], ctrlx8_safe_p2m_align}),
        .safe (ctrlx8_safe_p2m_align),
        .dout (ctrlx8_phy2mac[0])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlx8_1 (
        .sel  (sel_tgt.g2),
        .din  ({phy_phy2mac[9], ctrlx8_safe_p2m_align}),
        .safe (ctrlx8_safe_p2m_align),
        .dout (ctrlx8_phy2mac[1])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlx8_2 (
        .sel  (sel_tgt.g2),
        .din  ({phy_phy2mac[10], ctrlx8_safe_p2m_align}),
        .safe (ctrlx8_safe_p2m_align),
        .dout (ctrlx8_phy2mac[2])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlx8_3 (
        .sel  (sel_tgt.g2),
        .din  ({phy_phy2mac[11], ctrlx8_safe_p2m_align}),
        .safe (ctrlx8_safe_p2m_align),
        .dout (ctrlx8_phy2mac[3])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(3)) u_p2m_ctrlx8_4 (
        .sel  (sel_tgt.g3),
        .din  ({ctrlx8_safe_p2m_align, phy_phy2mac[12], ctrlx8_safe_p2m_align}),
        .safe (ctrlx8_safe_p2m_align),
        .dout (ctrlx8_phy2mac[4])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(3)) u_p2m_ctrlx8_5 (
        .sel  (sel_tgt.g3),
        .din  ({ctrlx8_safe_p2m_align, phy_phy2mac[13], ctrlx8_safe_p2m_align}),
        .safe (ctrlx8_safe_p2m_align),
        .dout (ctrlx8_phy2mac[5])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(3)) u_p2m_ctrlx8_6 (
        .sel  (sel_tgt.g3),
        .din  ({ctrlx8_safe_p2m_align, phy_phy2mac[14], ctrlx8_safe_p2m_align}),
        .safe (ctrlx8_safe_p2m_align),
        .dout (ctrlx8_phy2mac[6])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(3)) u_p2m_ctrlx8_7 (
        .sel  (sel_tgt.g3),
        .din  ({ctrlx8_safe_p2m_align, phy_phy2mac[15], ctrlx8_safe_p2m_align}),
        .safe (ctrlx8_safe_p2m_align),
        .dout (ctrlx8_phy2mac[7])
    );
    assign ctrlx8_phy2mac[8] = '0;  // fake lane, port padding only
    assign ctrlx8_phy2mac[9] = '0;  // fake lane, port padding only
    assign ctrlx8_phy2mac[10] = '0;  // fake lane, port padding only
    assign ctrlx8_phy2mac[11] = '0;  // fake lane, port padding only
    assign ctrlx8_phy2mac[12] = '0;  // fake lane, port padding only
    assign ctrlx8_phy2mac[13] = '0;  // fake lane, port padding only
    assign ctrlx8_phy2mac[14] = '0;  // fake lane, port padding only
    assign ctrlx8_phy2mac[15] = '0;  // fake lane, port padding only

    // CtrlX4a x4 (declared x16, ports 4..15 are fake lanes)
    phy2mac_lane_t ctrlx4a_safe_p2m_align;
    assign ctrlx4a_safe_p2m_align = '{
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[12].phy_mac_phystatus,
        default: '0
    };

    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(3)) u_p2m_ctrlx4a_0 (
        .sel  (sel_tgt.g3),
        .din  ({phy_phy2mac[12], ctrlx4a_safe_p2m_align, ctrlx4a_safe_p2m_align}),
        .safe (ctrlx4a_safe_p2m_align),
        .dout (ctrlx4a_phy2mac[0])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(3)) u_p2m_ctrlx4a_1 (
        .sel  (sel_tgt.g3),
        .din  ({phy_phy2mac[13], ctrlx4a_safe_p2m_align, ctrlx4a_safe_p2m_align}),
        .safe (ctrlx4a_safe_p2m_align),
        .dout (ctrlx4a_phy2mac[1])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(3)) u_p2m_ctrlx4a_2 (
        .sel  (sel_tgt.g3),
        .din  ({phy_phy2mac[14], ctrlx4a_safe_p2m_align, ctrlx4a_safe_p2m_align}),
        .safe (ctrlx4a_safe_p2m_align),
        .dout (ctrlx4a_phy2mac[2])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(3)) u_p2m_ctrlx4a_3 (
        .sel  (sel_tgt.g3),
        .din  ({phy_phy2mac[15], ctrlx4a_safe_p2m_align, ctrlx4a_safe_p2m_align}),
        .safe (ctrlx4a_safe_p2m_align),
        .dout (ctrlx4a_phy2mac[3])
    );
    assign ctrlx4a_phy2mac[4] = '0;  // fake lane, port padding only
    assign ctrlx4a_phy2mac[5] = '0;  // fake lane, port padding only
    assign ctrlx4a_phy2mac[6] = '0;  // fake lane, port padding only
    assign ctrlx4a_phy2mac[7] = '0;  // fake lane, port padding only
    assign ctrlx4a_phy2mac[8] = '0;  // fake lane, port padding only
    assign ctrlx4a_phy2mac[9] = '0;  // fake lane, port padding only
    assign ctrlx4a_phy2mac[10] = '0;  // fake lane, port padding only
    assign ctrlx4a_phy2mac[11] = '0;  // fake lane, port padding only
    assign ctrlx4a_phy2mac[12] = '0;  // fake lane, port padding only
    assign ctrlx4a_phy2mac[13] = '0;  // fake lane, port padding only
    assign ctrlx4a_phy2mac[14] = '0;  // fake lane, port padding only
    assign ctrlx4a_phy2mac[15] = '0;  // fake lane, port padding only

    // CtrlX4b x4 (declared x16, ports 4..15 are fake lanes)
    phy2mac_lane_t ctrlx4b_safe_p2m_align;
    assign ctrlx4b_safe_p2m_align = '{
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[4].phy_mac_phystatus,
        default: '0
    };

    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlx4b_0 (
        .sel  (sel_tgt.g1),
        .din  ({phy_phy2mac[4], ctrlx4b_safe_p2m_align}),
        .safe (ctrlx4b_safe_p2m_align),
        .dout (ctrlx4b_phy2mac[0])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlx4b_1 (
        .sel  (sel_tgt.g1),
        .din  ({phy_phy2mac[5], ctrlx4b_safe_p2m_align}),
        .safe (ctrlx4b_safe_p2m_align),
        .dout (ctrlx4b_phy2mac[1])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlx4b_2 (
        .sel  (sel_tgt.g1),
        .din  ({phy_phy2mac[6], ctrlx4b_safe_p2m_align}),
        .safe (ctrlx4b_safe_p2m_align),
        .dout (ctrlx4b_phy2mac[2])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlx4b_3 (
        .sel  (sel_tgt.g1),
        .din  ({phy_phy2mac[7], ctrlx4b_safe_p2m_align}),
        .safe (ctrlx4b_safe_p2m_align),
        .dout (ctrlx4b_phy2mac[3])
    );
    assign ctrlx4b_phy2mac[4] = '0;  // fake lane, port padding only
    assign ctrlx4b_phy2mac[5] = '0;  // fake lane, port padding only
    assign ctrlx4b_phy2mac[6] = '0;  // fake lane, port padding only
    assign ctrlx4b_phy2mac[7] = '0;  // fake lane, port padding only
    assign ctrlx4b_phy2mac[8] = '0;  // fake lane, port padding only
    assign ctrlx4b_phy2mac[9] = '0;  // fake lane, port padding only
    assign ctrlx4b_phy2mac[10] = '0;  // fake lane, port padding only
    assign ctrlx4b_phy2mac[11] = '0;  // fake lane, port padding only
    assign ctrlx4b_phy2mac[12] = '0;  // fake lane, port padding only
    assign ctrlx4b_phy2mac[13] = '0;  // fake lane, port padding only
    assign ctrlx4b_phy2mac[14] = '0;  // fake lane, port padding only
    assign ctrlx4b_phy2mac[15] = '0;  // fake lane, port padding only

endmodule
