//
// PIPE lane mapper PHY->MAC data mux (converges by controller port).
// sel_tgt's mutual exclusivity is guaranteed by pipe_lane_sel_sync. Undriven ports are tied to the safe state.
import pipe_lane_signal_pkg::*;

module pipe_lane_data_p2m #(
    parameter int NL = 6
) (
    input  lane_sel_t              sel_tgt,
    input  phy2mac_lane_t [NL-1:0] phy_phy2mac,
    output phy2mac_lane_t [2:0] ctrlalpha_phy2mac,
    output phy2mac_lane_t [2:0] ctrlbeta_phy2mac,
    output phy2mac_lane_t [2:0] ctrlgamma_phy2mac,
    output phy2mac_lane_t [2:0] ctrldelta_phy2mac,
    output phy2mac_lane_t [2:0] ctrlepsilon_phy2mac,
    output phy2mac_lane_t [2:0] ctrlzeta_phy2mac
);

    // CtrlAlpha x3
    phy2mac_lane_t ctrlalpha_safe_p2m_align;
    assign ctrlalpha_safe_p2m_align = '{
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[0].phy_mac_phystatus,
        default: '0
    };

    assign ctrlalpha_phy2mac[0] = phy_phy2mac[0];  // direct connection to lane0
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlalpha_1 (
        .sel  (sel_tgt.g1),
        .din  ({ctrlalpha_safe_p2m_align, phy_phy2mac[1]}),
        .safe (ctrlalpha_safe_p2m_align),
        .dout (ctrlalpha_phy2mac[1])
    );
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlalpha_2 (
        .sel  (sel_tgt.g2),
        .din  ({ctrlalpha_safe_p2m_align, phy_phy2mac[2]}),
        .safe (ctrlalpha_safe_p2m_align),
        .dout (ctrlalpha_phy2mac[2])
    );

    // CtrlBeta x2 (declared x3, ports 2..2 are fake lanes)
    phy2mac_lane_t ctrlbeta_safe_p2m_align;
    assign ctrlbeta_safe_p2m_align = '{
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[3].phy_mac_phystatus,
        default: '0
    };

    assign ctrlbeta_phy2mac[0] = phy_phy2mac[3];  // direct connection to lane3
    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlbeta_1 (
        .sel  (sel_tgt.g4),
        .din  ({ctrlbeta_safe_p2m_align, phy_phy2mac[4]}),
        .safe (ctrlbeta_safe_p2m_align),
        .dout (ctrlbeta_phy2mac[1])
    );
    assign ctrlbeta_phy2mac[2] = '0;  // fake lane, port padding only

    // CtrlGamma x1 (declared x3, ports 1..2 are fake lanes)
    phy2mac_lane_t ctrlgamma_safe_p2m_align;
    assign ctrlgamma_safe_p2m_align = '{
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[5].phy_mac_phystatus,
        default: '0
    };

    assign ctrlgamma_phy2mac[0] = phy_phy2mac[5];  // direct connection to lane5
    assign ctrlgamma_phy2mac[1] = '0;  // fake lane, port padding only
    assign ctrlgamma_phy2mac[2] = '0;  // fake lane, port padding only

    // CtrlDelta x1 (declared x3, ports 1..2 are fake lanes)
    phy2mac_lane_t ctrldelta_safe_p2m_align;
    assign ctrldelta_safe_p2m_align = '{
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[1].phy_mac_phystatus,
        default: '0
    };

    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrldelta_0 (
        .sel  (sel_tgt.g1),
        .din  ({phy_phy2mac[1], ctrldelta_safe_p2m_align}),
        .safe (ctrldelta_safe_p2m_align),
        .dout (ctrldelta_phy2mac[0])
    );
    assign ctrldelta_phy2mac[1] = '0;  // fake lane, port padding only
    assign ctrldelta_phy2mac[2] = '0;  // fake lane, port padding only

    // CtrlEpsilon x1 (declared x3, ports 1..2 are fake lanes)
    phy2mac_lane_t ctrlepsilon_safe_p2m_align;
    assign ctrlepsilon_safe_p2m_align = '{
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[2].phy_mac_phystatus,
        default: '0
    };

    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlepsilon_0 (
        .sel  (sel_tgt.g2),
        .din  ({phy_phy2mac[2], ctrlepsilon_safe_p2m_align}),
        .safe (ctrlepsilon_safe_p2m_align),
        .dout (ctrlepsilon_phy2mac[0])
    );
    assign ctrlepsilon_phy2mac[1] = '0;  // fake lane, port padding only
    assign ctrlepsilon_phy2mac[2] = '0;  // fake lane, port padding only

    // CtrlZeta x1 (declared x3, ports 1..2 are fake lanes)
    phy2mac_lane_t ctrlzeta_safe_p2m_align;
    assign ctrlzeta_safe_p2m_align = '{
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[4].phy_mac_phystatus,
        default: '0
    };

    pipe_lane_data_mux #(.WIDTH($bits(phy2mac_lane_t)), .N(2)) u_p2m_ctrlzeta_0 (
        .sel  (sel_tgt.g4),
        .din  ({phy_phy2mac[4], ctrlzeta_safe_p2m_align}),
        .safe (ctrlzeta_safe_p2m_align),
        .dout (ctrlzeta_phy2mac[0])
    );
    assign ctrlzeta_phy2mac[1] = '0;  // fake lane, port padding only
    assign ctrlzeta_phy2mac[2] = '0;  // fake lane, port padding only

endmodule
