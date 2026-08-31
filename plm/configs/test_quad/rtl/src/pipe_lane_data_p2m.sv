//
// PIPE lane mapper PHY->MAC data mux (converges by controller port).
// sel_tgt's mutual exclusivity is guaranteed by pipe_lane_sel_sync. Undriven ports are tied to the safe state.
import pipe_lane_signal_pkg::*;

module pipe_lane_data_p2m #(
    parameter int NL = 12
) (
    input  lane_sel_t              sel_tgt,
    input  phy2mac_lane_t [NL-1:0] phy_phy2mac,
    output phy2mac_lane_t [11:0] ctrla_phy2mac,
    output phy2mac_lane_t [11:0] ctrlb_phy2mac,
    output phy2mac_lane_t [11:0] ctrlc_phy2mac,
    output phy2mac_lane_t [11:0] ctrld_phy2mac
);

    // CtrlA x12
    phy2mac_lane_t ctrla_safe_p2m_align;
    assign ctrla_safe_p2m_align = '{
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[0].phy_mac_phystatus,
        default: '0
    };

    assign ctrla_phy2mac[0] = phy_phy2mac[0];  // direct connection to lane0
    assign ctrla_phy2mac[1] = phy_phy2mac[1];  // direct connection to lane1
    assign ctrla_phy2mac[2] = phy_phy2mac[2];  // direct connection to lane2
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrla_3 (
        .sel  (sel_tgt.g1),
        .din  ({ctrla_safe_p2m_align, phy_phy2mac[3]}),
        .safe (ctrla_safe_p2m_align),
        .dout (ctrla_phy2mac[3])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrla_4 (
        .sel  (sel_tgt.g1),
        .din  ({ctrla_safe_p2m_align, phy_phy2mac[4]}),
        .safe (ctrla_safe_p2m_align),
        .dout (ctrla_phy2mac[4])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrla_5 (
        .sel  (sel_tgt.g1),
        .din  ({ctrla_safe_p2m_align, phy_phy2mac[5]}),
        .safe (ctrla_safe_p2m_align),
        .dout (ctrla_phy2mac[5])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrla_6 (
        .sel  (sel_tgt.g2),
        .din  ({ctrla_safe_p2m_align, phy_phy2mac[6]}),
        .safe (ctrla_safe_p2m_align),
        .dout (ctrla_phy2mac[6])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrla_7 (
        .sel  (sel_tgt.g2),
        .din  ({ctrla_safe_p2m_align, phy_phy2mac[7]}),
        .safe (ctrla_safe_p2m_align),
        .dout (ctrla_phy2mac[7])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrla_8 (
        .sel  (sel_tgt.g2),
        .din  ({ctrla_safe_p2m_align, phy_phy2mac[8]}),
        .safe (ctrla_safe_p2m_align),
        .dout (ctrla_phy2mac[8])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(4)) u_p2m_ctrla_9 (
        .sel  (sel_tgt.g3),
        .din  ({ctrla_safe_p2m_align, ctrla_safe_p2m_align, ctrla_safe_p2m_align, phy_phy2mac[9]}),
        .safe (ctrla_safe_p2m_align),
        .dout (ctrla_phy2mac[9])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(4)) u_p2m_ctrla_10 (
        .sel  (sel_tgt.g3),
        .din  ({ctrla_safe_p2m_align, ctrla_safe_p2m_align, ctrla_safe_p2m_align, phy_phy2mac[10]}),
        .safe (ctrla_safe_p2m_align),
        .dout (ctrla_phy2mac[10])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(4)) u_p2m_ctrla_11 (
        .sel  (sel_tgt.g3),
        .din  ({ctrla_safe_p2m_align, ctrla_safe_p2m_align, ctrla_safe_p2m_align, phy_phy2mac[11]}),
        .safe (ctrla_safe_p2m_align),
        .dout (ctrla_phy2mac[11])
    );

    // CtrlB x6 (declared x12, ports 6..11 are fake lanes)
    phy2mac_lane_t ctrlb_safe_p2m_align;
    assign ctrlb_safe_p2m_align = '{
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[3].phy_mac_phystatus,
        default: '0
    };

    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlb_0 (
        .sel  (sel_tgt.g1),
        .din  ({phy_phy2mac[3], ctrlb_safe_p2m_align}),
        .safe (ctrlb_safe_p2m_align),
        .dout (ctrlb_phy2mac[0])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlb_1 (
        .sel  (sel_tgt.g1),
        .din  ({phy_phy2mac[4], ctrlb_safe_p2m_align}),
        .safe (ctrlb_safe_p2m_align),
        .dout (ctrlb_phy2mac[1])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlb_2 (
        .sel  (sel_tgt.g1),
        .din  ({phy_phy2mac[5], ctrlb_safe_p2m_align}),
        .safe (ctrlb_safe_p2m_align),
        .dout (ctrlb_phy2mac[2])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(4)) u_p2m_ctrlb_3 (
        .sel  (sel_tgt.g3),
        .din  ({ctrlb_safe_p2m_align, ctrlb_safe_p2m_align, phy_phy2mac[9], ctrlb_safe_p2m_align}),
        .safe (ctrlb_safe_p2m_align),
        .dout (ctrlb_phy2mac[3])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(4)) u_p2m_ctrlb_4 (
        .sel  (sel_tgt.g3),
        .din  ({ctrlb_safe_p2m_align, ctrlb_safe_p2m_align, phy_phy2mac[10], ctrlb_safe_p2m_align}),
        .safe (ctrlb_safe_p2m_align),
        .dout (ctrlb_phy2mac[4])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(4)) u_p2m_ctrlb_5 (
        .sel  (sel_tgt.g3),
        .din  ({ctrlb_safe_p2m_align, ctrlb_safe_p2m_align, phy_phy2mac[11], ctrlb_safe_p2m_align}),
        .safe (ctrlb_safe_p2m_align),
        .dout (ctrlb_phy2mac[5])
    );
    assign ctrlb_phy2mac[6] = '0;  // fake lane, port padding only
    assign ctrlb_phy2mac[7] = '0;  // fake lane, port padding only
    assign ctrlb_phy2mac[8] = '0;  // fake lane, port padding only
    assign ctrlb_phy2mac[9] = '0;  // fake lane, port padding only
    assign ctrlb_phy2mac[10] = '0;  // fake lane, port padding only
    assign ctrlb_phy2mac[11] = '0;  // fake lane, port padding only

    // CtrlC x8 (declared x12, ports 8..11 are fake lanes)
    phy2mac_lane_t ctrlc_safe_p2m_align;
    assign ctrlc_safe_p2m_align = '{
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[6].phy_mac_phystatus,
        default: '0
    };

    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlc_0 (
        .sel  (sel_tgt.g2),
        .din  ({phy_phy2mac[6], ctrlc_safe_p2m_align}),
        .safe (ctrlc_safe_p2m_align),
        .dout (ctrlc_phy2mac[0])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlc_1 (
        .sel  (sel_tgt.g2),
        .din  ({phy_phy2mac[7], ctrlc_safe_p2m_align}),
        .safe (ctrlc_safe_p2m_align),
        .dout (ctrlc_phy2mac[1])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlc_2 (
        .sel  (sel_tgt.g2),
        .din  ({phy_phy2mac[8], ctrlc_safe_p2m_align}),
        .safe (ctrlc_safe_p2m_align),
        .dout (ctrlc_phy2mac[2])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(4)) u_p2m_ctrlc_3 (
        .sel  (sel_tgt.g3),
        .din  ({ctrlc_safe_p2m_align, phy_phy2mac[9], ctrlc_safe_p2m_align, ctrlc_safe_p2m_align}),
        .safe (ctrlc_safe_p2m_align),
        .dout (ctrlc_phy2mac[3])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(4)) u_p2m_ctrlc_4 (
        .sel  (sel_tgt.g3),
        .din  ({ctrlc_safe_p2m_align, phy_phy2mac[10], ctrlc_safe_p2m_align, ctrlc_safe_p2m_align}),
        .safe (ctrlc_safe_p2m_align),
        .dout (ctrlc_phy2mac[4])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(4)) u_p2m_ctrlc_5 (
        .sel  (sel_tgt.g3),
        .din  ({ctrlc_safe_p2m_align, phy_phy2mac[11], ctrlc_safe_p2m_align, ctrlc_safe_p2m_align}),
        .safe (ctrlc_safe_p2m_align),
        .dout (ctrlc_phy2mac[5])
    );
    assign ctrlc_phy2mac[6] = ctrlc_safe_p2m_align;  // never driven in any mode
    assign ctrlc_phy2mac[7] = ctrlc_safe_p2m_align;  // never driven in any mode
    assign ctrlc_phy2mac[8] = '0;  // fake lane, port padding only
    assign ctrlc_phy2mac[9] = '0;  // fake lane, port padding only
    assign ctrlc_phy2mac[10] = '0;  // fake lane, port padding only
    assign ctrlc_phy2mac[11] = '0;  // fake lane, port padding only

    // CtrlD x3 (declared x12, ports 3..11 are fake lanes)
    phy2mac_lane_t ctrld_safe_p2m_align;
    assign ctrld_safe_p2m_align = '{
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[9].phy_mac_phystatus,
        default: '0
    };

    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(4)) u_p2m_ctrld_0 (
        .sel  (sel_tgt.g3),
        .din  ({phy_phy2mac[9], ctrld_safe_p2m_align, ctrld_safe_p2m_align, ctrld_safe_p2m_align}),
        .safe (ctrld_safe_p2m_align),
        .dout (ctrld_phy2mac[0])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(4)) u_p2m_ctrld_1 (
        .sel  (sel_tgt.g3),
        .din  ({phy_phy2mac[10], ctrld_safe_p2m_align, ctrld_safe_p2m_align, ctrld_safe_p2m_align}),
        .safe (ctrld_safe_p2m_align),
        .dout (ctrld_phy2mac[1])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(4)) u_p2m_ctrld_2 (
        .sel  (sel_tgt.g3),
        .din  ({phy_phy2mac[11], ctrld_safe_p2m_align, ctrld_safe_p2m_align, ctrld_safe_p2m_align}),
        .safe (ctrld_safe_p2m_align),
        .dout (ctrld_phy2mac[2])
    );
    assign ctrld_phy2mac[3] = '0;  // fake lane, port padding only
    assign ctrld_phy2mac[4] = '0;  // fake lane, port padding only
    assign ctrld_phy2mac[5] = '0;  // fake lane, port padding only
    assign ctrld_phy2mac[6] = '0;  // fake lane, port padding only
    assign ctrld_phy2mac[7] = '0;  // fake lane, port padding only
    assign ctrld_phy2mac[8] = '0;  // fake lane, port padding only
    assign ctrld_phy2mac[9] = '0;  // fake lane, port padding only
    assign ctrld_phy2mac[10] = '0;  // fake lane, port padding only
    assign ctrld_phy2mac[11] = '0;  // fake lane, port padding only

endmodule
