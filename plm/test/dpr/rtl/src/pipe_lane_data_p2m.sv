// PIPE lane mapper PHY->MAC data mux (converges by controller lane).
// sel_tgt's mutual exclusivity is guaranteed by pipe_lane_sel_sync.
// Two distinct "nothing valid to show" values here, do not confuse them:
//   SAFE_P2M (from safe_state) -- this ctrl lane does have a driving PHY lane,
//                                 but no candidate owns it right now (NOV window).
//   {c}_p2m_tie (from tie_off)  -- this ctrl lane is never driven by any PHY lane.
import pipe_lane_signal_pkg::*;

module pipe_lane_data_p2m #(
    parameter int NL = 12
) (
    input lane_sel_t sel_tgt,
    input phy2mac_lane_t [NL-1:0] phy_phy2mac,
    output phy2mac_lane_t [NL-1:0] dpr_phy2mac,
    output phy2mac_lane_t [11:0] ctrla_phy2mac,
    output phy2mac_lane_t [5:0] ctrlb_phy2mac,
    output phy2mac_lane_t [7:0] ctrlc_phy2mac,
    output phy2mac_lane_t [2:0] ctrld_phy2mac
);

    // CtrlA x12
    phy2mac_lane_t ctrla_p2m_tie;
    assign ctrla_p2m_tie = '{
        phy_mac_messagebus: 8'h50,
        phy_mac_phystatus: phy_phy2mac[0].phy_mac_phystatus,
        default: '0
    };

    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(1)) u_p2m_ctrla_0 (
        .sel  (sel_tgt.g0[0:0]),
        .din  ({phy_phy2mac[0]}),
        .safe (SAFE_P2M),
        .dout (ctrla_phy2mac[0])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(1)) u_p2m_ctrla_1 (
        .sel  (sel_tgt.g0[0:0]),
        .din  ({phy_phy2mac[1]}),
        .safe (SAFE_P2M),
        .dout (ctrla_phy2mac[1])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(1)) u_p2m_ctrla_2 (
        .sel  (sel_tgt.g0[0:0]),
        .din  ({phy_phy2mac[2]}),
        .safe (SAFE_P2M),
        .dout (ctrla_phy2mac[2])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrla_3 (
        .sel  (sel_tgt.g1[1:0]),
        .din  ({ctrla_p2m_tie, phy_phy2mac[3]}),
        .safe (SAFE_P2M),
        .dout (ctrla_phy2mac[3])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrla_4 (
        .sel  (sel_tgt.g1[1:0]),
        .din  ({ctrla_p2m_tie, phy_phy2mac[4]}),
        .safe (SAFE_P2M),
        .dout (ctrla_phy2mac[4])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrla_5 (
        .sel  (sel_tgt.g1[1:0]),
        .din  ({ctrla_p2m_tie, phy_phy2mac[5]}),
        .safe (SAFE_P2M),
        .dout (ctrla_phy2mac[5])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrla_6 (
        .sel  (sel_tgt.g2[1:0]),
        .din  ({ctrla_p2m_tie, phy_phy2mac[6]}),
        .safe (SAFE_P2M),
        .dout (ctrla_phy2mac[6])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrla_7 (
        .sel  (sel_tgt.g2[1:0]),
        .din  ({ctrla_p2m_tie, phy_phy2mac[7]}),
        .safe (SAFE_P2M),
        .dout (ctrla_phy2mac[7])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrla_8 (
        .sel  (sel_tgt.g2[1:0]),
        .din  ({ctrla_p2m_tie, phy_phy2mac[8]}),
        .safe (SAFE_P2M),
        .dout (ctrla_phy2mac[8])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrla_9 (
        .sel  (sel_tgt.g3[3:0]),
        .din  ({ctrla_p2m_tie, ctrla_p2m_tie, ctrla_p2m_tie, phy_phy2mac[9]}),
        .safe (SAFE_P2M),
        .dout (ctrla_phy2mac[9])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrla_10 (
        .sel  (sel_tgt.g3[3:0]),
        .din  ({ctrla_p2m_tie, ctrla_p2m_tie, ctrla_p2m_tie, phy_phy2mac[10]}),
        .safe (SAFE_P2M),
        .dout (ctrla_phy2mac[10])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrla_11 (
        .sel  (sel_tgt.g3[3:0]),
        .din  ({ctrla_p2m_tie, ctrla_p2m_tie, ctrla_p2m_tie, phy_phy2mac[11]}),
        .safe (SAFE_P2M),
        .dout (ctrla_phy2mac[11])
    );

    // CtrlB x6
    phy2mac_lane_t ctrlb_p2m_tie;
    assign ctrlb_p2m_tie = '{
        phy_mac_messagebus: 8'h50,
        phy_mac_phystatus: phy_phy2mac[3].phy_mac_phystatus,
        default: '0
    };

    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlb_0 (
        .sel  (sel_tgt.g1[1:0]),
        .din  ({phy_phy2mac[3], ctrlb_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlb_phy2mac[0])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlb_1 (
        .sel  (sel_tgt.g1[1:0]),
        .din  ({phy_phy2mac[4], ctrlb_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlb_phy2mac[1])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlb_2 (
        .sel  (sel_tgt.g1[1:0]),
        .din  ({phy_phy2mac[5], ctrlb_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlb_phy2mac[2])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrlb_3 (
        .sel  (sel_tgt.g3[3:0]),
        .din  ({ctrlb_p2m_tie, ctrlb_p2m_tie, phy_phy2mac[9], ctrlb_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlb_phy2mac[3])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrlb_4 (
        .sel  (sel_tgt.g3[3:0]),
        .din  ({ctrlb_p2m_tie, ctrlb_p2m_tie, phy_phy2mac[10], ctrlb_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlb_phy2mac[4])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrlb_5 (
        .sel  (sel_tgt.g3[3:0]),
        .din  ({ctrlb_p2m_tie, ctrlb_p2m_tie, phy_phy2mac[11], ctrlb_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlb_phy2mac[5])
    );

    // CtrlC x8
    phy2mac_lane_t ctrlc_p2m_tie;
    assign ctrlc_p2m_tie = '{
        phy_mac_messagebus: 8'h50,
        phy_mac_phystatus: phy_phy2mac[6].phy_mac_phystatus,
        default: '0
    };

    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlc_0 (
        .sel  (sel_tgt.g2[1:0]),
        .din  ({phy_phy2mac[6], ctrlc_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlc_phy2mac[0])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlc_1 (
        .sel  (sel_tgt.g2[1:0]),
        .din  ({phy_phy2mac[7], ctrlc_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlc_phy2mac[1])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlc_2 (
        .sel  (sel_tgt.g2[1:0]),
        .din  ({phy_phy2mac[8], ctrlc_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlc_phy2mac[2])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrlc_3 (
        .sel  (sel_tgt.g3[3:0]),
        .din  ({ctrlc_p2m_tie, phy_phy2mac[9], ctrlc_p2m_tie, ctrlc_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlc_phy2mac[3])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrlc_4 (
        .sel  (sel_tgt.g3[3:0]),
        .din  ({ctrlc_p2m_tie, phy_phy2mac[10], ctrlc_p2m_tie, ctrlc_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlc_phy2mac[4])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrlc_5 (
        .sel  (sel_tgt.g3[3:0]),
        .din  ({ctrlc_p2m_tie, phy_phy2mac[11], ctrlc_p2m_tie, ctrlc_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrlc_phy2mac[5])
    );
    assign ctrlc_phy2mac[6] = ctrlc_p2m_tie;  // never driven in any mode
    assign ctrlc_phy2mac[7] = ctrlc_p2m_tie;  // never driven in any mode

    // CtrlD x3
    phy2mac_lane_t ctrld_p2m_tie;
    assign ctrld_p2m_tie = '{
        phy_mac_messagebus: 8'h50,
        phy_mac_phystatus: phy_phy2mac[9].phy_mac_phystatus,
        default: '0
    };

    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrld_0 (
        .sel  (sel_tgt.g3[3:0]),
        .din  ({phy_phy2mac[9], ctrld_p2m_tie, ctrld_p2m_tie, ctrld_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrld_phy2mac[0])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrld_1 (
        .sel  (sel_tgt.g3[3:0]),
        .din  ({phy_phy2mac[10], ctrld_p2m_tie, ctrld_p2m_tie, ctrld_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrld_phy2mac[1])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrld_2 (
        .sel  (sel_tgt.g3[3:0]),
        .din  ({phy_phy2mac[11], ctrld_p2m_tie, ctrld_p2m_tie, ctrld_p2m_tie}),
        .safe (SAFE_P2M),
        .dout (ctrld_phy2mac[2])
    );

    //------------------------------------------------------------
    // PHY -> DPR: read-only tap, no pipe_lane_data_mux needed (no driver
    // contention) -- but gated on the SAME synchronized "DPR owns this
    // lane" bit that already gates phy_mac2phy/phy_pclk_in for it, not raw
    // v_lane_mask, so this tap's view of ownership stays in lockstep with
    // what the write side is actually doing (see this module's docstring).
    // Not-owned reads back SAFE_P2M, the same "no owner right now" value
    // every real controller lane presents -- DPR has no fixed base lane of
    // its own (its owned set is a live runtime value), so tie_off has
    // nothing to resolve against here anyway.
    //------------------------------------------------------------
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(1)) u_p2m_dpr_0 (
        .sel  (sel_tgt.g0[1:1]),
        .din  ({phy_phy2mac[0]}),
        .safe (SAFE_P2M),
        .dout (dpr_phy2mac[0])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(1)) u_p2m_dpr_1 (
        .sel  (sel_tgt.g0[1:1]),
        .din  ({phy_phy2mac[1]}),
        .safe (SAFE_P2M),
        .dout (dpr_phy2mac[1])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(1)) u_p2m_dpr_2 (
        .sel  (sel_tgt.g0[1:1]),
        .din  ({phy_phy2mac[2]}),
        .safe (SAFE_P2M),
        .dout (dpr_phy2mac[2])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(1)) u_p2m_dpr_3 (
        .sel  (sel_tgt.g1[2:2]),
        .din  ({phy_phy2mac[3]}),
        .safe (SAFE_P2M),
        .dout (dpr_phy2mac[3])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(1)) u_p2m_dpr_4 (
        .sel  (sel_tgt.g1[2:2]),
        .din  ({phy_phy2mac[4]}),
        .safe (SAFE_P2M),
        .dout (dpr_phy2mac[4])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(1)) u_p2m_dpr_5 (
        .sel  (sel_tgt.g1[2:2]),
        .din  ({phy_phy2mac[5]}),
        .safe (SAFE_P2M),
        .dout (dpr_phy2mac[5])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(1)) u_p2m_dpr_6 (
        .sel  (sel_tgt.g2[2:2]),
        .din  ({phy_phy2mac[6]}),
        .safe (SAFE_P2M),
        .dout (dpr_phy2mac[6])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(1)) u_p2m_dpr_7 (
        .sel  (sel_tgt.g2[2:2]),
        .din  ({phy_phy2mac[7]}),
        .safe (SAFE_P2M),
        .dout (dpr_phy2mac[7])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(1)) u_p2m_dpr_8 (
        .sel  (sel_tgt.g2[2:2]),
        .din  ({phy_phy2mac[8]}),
        .safe (SAFE_P2M),
        .dout (dpr_phy2mac[8])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(1)) u_p2m_dpr_9 (
        .sel  (sel_tgt.g3[4:4]),
        .din  ({phy_phy2mac[9]}),
        .safe (SAFE_P2M),
        .dout (dpr_phy2mac[9])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(1)) u_p2m_dpr_10 (
        .sel  (sel_tgt.g3[4:4]),
        .din  ({phy_phy2mac[10]}),
        .safe (SAFE_P2M),
        .dout (dpr_phy2mac[10])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(1)) u_p2m_dpr_11 (
        .sel  (sel_tgt.g3[4:4]),
        .din  ({phy_phy2mac[11]}),
        .safe (SAFE_P2M),
        .dout (dpr_phy2mac[11])
    );

endmodule
