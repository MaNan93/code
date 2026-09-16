// PIPE lane mapper PHY->MAC data mux (converges by controller lane).
// sel_tgt's mutual exclusivity is guaranteed by pipe_lane_sel_sync.
// Two distinct "nothing valid to show" values here, do not confuse them:
//   SAFE_P2M (from safe_state) -- this ctrl lane does have a driving PHY lane,
//                                 but no candidate owns it right now (NOV window).
//   {c}_p2m_tie (from tie_off)  -- this ctrl lane is never driven by any PHY lane.
import pipe_lane_signal_pkg::*;

module pipe_lane_data_p2m #(
    parameter int NL = 6
) (
    input lane_sel_t sel_tgt,
    input phy2mac_lane_t [NL-1:0] phy_phy2mac,
    output phy2mac_lane_t [2:0] ctrlalpha_phy2mac,
    output phy2mac_lane_t [1:0] ctrlbeta_phy2mac,
    output phy2mac_lane_t [0:0] ctrlgamma_phy2mac,
    output phy2mac_lane_t [0:0] ctrldelta_phy2mac,
    output phy2mac_lane_t [0:0] ctrlepsilon_phy2mac,
    output phy2mac_lane_t [0:0] ctrlzeta_phy2mac
);

    // CtrlAlpha x3
    phy2mac_lane_t ctrlalpha_p2m_tie;
    assign ctrlalpha_p2m_tie = '{
        phy_mac_messagebus: 8'h50,
        phy_mac_phystatus: phy_phy2mac[0].phy_mac_phystatus,
        default: '0
    };

    assign ctrlalpha_phy2mac[0] = phy_phy2mac[0];  // direct connection to lane0
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlalpha_1 (
        .sel  (sel_tgt.g1),
        .din  ({ctrlalpha_p2m_tie, phy_phy2mac[1]}),
        .safe (SAFE_P2M),
        .dout (ctrlalpha_phy2mac[1])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlalpha_2 (
        .sel  (sel_tgt.g2),
        .din  ({ctrlalpha_p2m_tie, phy_phy2mac[2]}),
        .safe (SAFE_P2M),
        .dout (ctrlalpha_phy2mac[2])
    );

    // CtrlBeta x2
    phy2mac_lane_t ctrlbeta_p2m_tie;
    assign ctrlbeta_p2m_tie = '{
        phy_mac_messagebus: 8'h50,
        phy_mac_phystatus: phy_phy2mac[3].phy_mac_phystatus,
        default: '0
    };

    assign ctrlbeta_phy2mac[0] = phy_phy2mac[3];  // direct connection to lane3
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlbeta_1 (
        .sel  (sel_tgt.g4),
        .din  ({ctrlbeta_p2m_tie, phy_phy2mac[4]}),
        .safe (SAFE_P2M),
        .dout (ctrlbeta_phy2mac[1])
    );

    // CtrlGamma x1
    phy2mac_lane_t ctrlgamma_p2m_tie;
    assign ctrlgamma_p2m_tie = '{
        phy_mac_messagebus: 8'h50,
        phy_mac_phystatus: phy_phy2mac[5].phy_mac_phystatus,
        default: '0
    };

    assign ctrlgamma_phy2mac[0] = phy_phy2mac[5];  // direct connection to lane5

    // CtrlDelta x1
    phy2mac_lane_t ctrldelta_p2m_tie;
    assign ctrldelta_p2m_tie = '{
        phy_mac_messagebus: 8'h50,
        phy_mac_phystatus: phy_phy2mac[1].phy_mac_phystatus,
        default: '0
    };

    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrldelta_0 (
        .sel  (sel_tgt.g1),
        .din  ({phy_phy2mac[1], ctrldelta_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrldelta_phy2mac[0])
    );

    // CtrlEpsilon x1
    phy2mac_lane_t ctrlepsilon_p2m_tie;
    assign ctrlepsilon_p2m_tie = '{
        phy_mac_messagebus: 8'h50,
        phy_mac_phystatus: phy_phy2mac[2].phy_mac_phystatus,
        default: '0
    };

    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlepsilon_0 (
        .sel  (sel_tgt.g2),
        .din  ({phy_phy2mac[2], ctrlepsilon_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlepsilon_phy2mac[0])
    );

    // CtrlZeta x1
    phy2mac_lane_t ctrlzeta_p2m_tie;
    assign ctrlzeta_p2m_tie = '{
        phy_mac_messagebus: 8'h50,
        phy_mac_phystatus: phy_phy2mac[4].phy_mac_phystatus,
        default: '0
    };

    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlzeta_0 (
        .sel  (sel_tgt.g4),
        .din  ({phy_phy2mac[4], ctrlzeta_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlzeta_phy2mac[0])
    );

endmodule
