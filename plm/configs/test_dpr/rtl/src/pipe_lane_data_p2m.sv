// PIPE lane mapper PHY->MAC data mux (converges by controller port).
// sel_tgt's mutual exclusivity is guaranteed by pipe_lane_sel_sync. Undriven ports are tied to the safe state.
import pipe_lane_signal_pkg::*;

module pipe_lane_data_p2m #(
    parameter int NL = 12
) (
    input lane_sel_t sel_tgt,
    input phy2mac_lane_t [NL-1:0] phy_phy2mac,
    input logic [NL-1:0] v_lane_mask,
    output phy2mac_lane_t [NL-1:0] dpr_phy2mac,
    output phy2mac_lane_t [11:0] ctrla_phy2mac,
    output phy2mac_lane_t [5:0] ctrlb_phy2mac,
    output phy2mac_lane_t [7:0] ctrlc_phy2mac,
    output phy2mac_lane_t [2:0] ctrld_phy2mac
);

    // CtrlA x12
    phy2mac_lane_t ctrla_p2m_tie;
    assign ctrla_p2m_tie = '{
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[0].phy_mac_phystatus,
        default: '0
    };

    assign ctrla_phy2mac[0] = phy_phy2mac[0];  // direct connection to lane0
    assign ctrla_phy2mac[1] = phy_phy2mac[1];  // direct connection to lane1
    assign ctrla_phy2mac[2] = phy_phy2mac[2];  // direct connection to lane2
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrla_3 (
        .sel  (sel_tgt.g1[1:0]),
        .din  ({ctrla_p2m_tie, phy_phy2mac[3]}),
        .safe (ctrla_p2m_tie),
        .dout (ctrla_phy2mac[3])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrla_4 (
        .sel  (sel_tgt.g1[1:0]),
        .din  ({ctrla_p2m_tie, phy_phy2mac[4]}),
        .safe (ctrla_p2m_tie),
        .dout (ctrla_phy2mac[4])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrla_5 (
        .sel  (sel_tgt.g1[1:0]),
        .din  ({ctrla_p2m_tie, phy_phy2mac[5]}),
        .safe (ctrla_p2m_tie),
        .dout (ctrla_phy2mac[5])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrla_6 (
        .sel  (sel_tgt.g2[1:0]),
        .din  ({ctrla_p2m_tie, phy_phy2mac[6]}),
        .safe (ctrla_p2m_tie),
        .dout (ctrla_phy2mac[6])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrla_7 (
        .sel  (sel_tgt.g2[1:0]),
        .din  ({ctrla_p2m_tie, phy_phy2mac[7]}),
        .safe (ctrla_p2m_tie),
        .dout (ctrla_phy2mac[7])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrla_8 (
        .sel  (sel_tgt.g2[1:0]),
        .din  ({ctrla_p2m_tie, phy_phy2mac[8]}),
        .safe (ctrla_p2m_tie),
        .dout (ctrla_phy2mac[8])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrla_9 (
        .sel  (sel_tgt.g3[3:0]),
        .din  ({ctrla_p2m_tie, ctrla_p2m_tie, ctrla_p2m_tie, phy_phy2mac[9]}),
        .safe (ctrla_p2m_tie),
        .dout (ctrla_phy2mac[9])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrla_10 (
        .sel  (sel_tgt.g3[3:0]),
        .din  ({ctrla_p2m_tie, ctrla_p2m_tie, ctrla_p2m_tie, phy_phy2mac[10]}),
        .safe (ctrla_p2m_tie),
        .dout (ctrla_phy2mac[10])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrla_11 (
        .sel  (sel_tgt.g3[3:0]),
        .din  ({ctrla_p2m_tie, ctrla_p2m_tie, ctrla_p2m_tie, phy_phy2mac[11]}),
        .safe (ctrla_p2m_tie),
        .dout (ctrla_phy2mac[11])
    );

    // CtrlB x6
    phy2mac_lane_t ctrlb_p2m_tie;
    assign ctrlb_p2m_tie = '{
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[3].phy_mac_phystatus,
        default: '0
    };

    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlb_0 (
        .sel  (sel_tgt.g1[1:0]),
        .din  ({phy_phy2mac[3], ctrlb_p2m_tie}),
        .safe (ctrlb_p2m_tie),
        .dout (ctrlb_phy2mac[0])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlb_1 (
        .sel  (sel_tgt.g1[1:0]),
        .din  ({phy_phy2mac[4], ctrlb_p2m_tie}),
        .safe (ctrlb_p2m_tie),
        .dout (ctrlb_phy2mac[1])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlb_2 (
        .sel  (sel_tgt.g1[1:0]),
        .din  ({phy_phy2mac[5], ctrlb_p2m_tie}),
        .safe (ctrlb_p2m_tie),
        .dout (ctrlb_phy2mac[2])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrlb_3 (
        .sel  (sel_tgt.g3[3:0]),
        .din  ({ctrlb_p2m_tie, ctrlb_p2m_tie, phy_phy2mac[9], ctrlb_p2m_tie}),
        .safe (ctrlb_p2m_tie),
        .dout (ctrlb_phy2mac[3])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrlb_4 (
        .sel  (sel_tgt.g3[3:0]),
        .din  ({ctrlb_p2m_tie, ctrlb_p2m_tie, phy_phy2mac[10], ctrlb_p2m_tie}),
        .safe (ctrlb_p2m_tie),
        .dout (ctrlb_phy2mac[4])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrlb_5 (
        .sel  (sel_tgt.g3[3:0]),
        .din  ({ctrlb_p2m_tie, ctrlb_p2m_tie, phy_phy2mac[11], ctrlb_p2m_tie}),
        .safe (ctrlb_p2m_tie),
        .dout (ctrlb_phy2mac[5])
    );

    // CtrlC x8
    phy2mac_lane_t ctrlc_p2m_tie;
    assign ctrlc_p2m_tie = '{
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[6].phy_mac_phystatus,
        default: '0
    };

    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlc_0 (
        .sel  (sel_tgt.g2[1:0]),
        .din  ({phy_phy2mac[6], ctrlc_p2m_tie}),
        .safe (ctrlc_p2m_tie),
        .dout (ctrlc_phy2mac[0])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlc_1 (
        .sel  (sel_tgt.g2[1:0]),
        .din  ({phy_phy2mac[7], ctrlc_p2m_tie}),
        .safe (ctrlc_p2m_tie),
        .dout (ctrlc_phy2mac[1])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlc_2 (
        .sel  (sel_tgt.g2[1:0]),
        .din  ({phy_phy2mac[8], ctrlc_p2m_tie}),
        .safe (ctrlc_p2m_tie),
        .dout (ctrlc_phy2mac[2])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrlc_3 (
        .sel  (sel_tgt.g3[3:0]),
        .din  ({ctrlc_p2m_tie, phy_phy2mac[9], ctrlc_p2m_tie, ctrlc_p2m_tie}),
        .safe (ctrlc_p2m_tie),
        .dout (ctrlc_phy2mac[3])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrlc_4 (
        .sel  (sel_tgt.g3[3:0]),
        .din  ({ctrlc_p2m_tie, phy_phy2mac[10], ctrlc_p2m_tie, ctrlc_p2m_tie}),
        .safe (ctrlc_p2m_tie),
        .dout (ctrlc_phy2mac[4])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrlc_5 (
        .sel  (sel_tgt.g3[3:0]),
        .din  ({ctrlc_p2m_tie, phy_phy2mac[11], ctrlc_p2m_tie, ctrlc_p2m_tie}),
        .safe (ctrlc_p2m_tie),
        .dout (ctrlc_phy2mac[5])
    );
    assign ctrlc_phy2mac[6] = ctrlc_p2m_tie;  // never driven in any mode
    assign ctrlc_phy2mac[7] = ctrlc_p2m_tie;  // never driven in any mode

    // CtrlD x3
    phy2mac_lane_t ctrld_p2m_tie;
    assign ctrld_p2m_tie = '{
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[9].phy_mac_phystatus,
        default: '0
    };

    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrld_0 (
        .sel  (sel_tgt.g3[3:0]),
        .din  ({phy_phy2mac[9], ctrld_p2m_tie, ctrld_p2m_tie, ctrld_p2m_tie}),
        .safe (ctrld_p2m_tie),
        .dout (ctrld_phy2mac[0])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrld_1 (
        .sel  (sel_tgt.g3[3:0]),
        .din  ({phy_phy2mac[10], ctrld_p2m_tie, ctrld_p2m_tie, ctrld_p2m_tie}),
        .safe (ctrld_p2m_tie),
        .dout (ctrld_phy2mac[1])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrld_2 (
        .sel  (sel_tgt.g3[3:0]),
        .din  ({phy_phy2mac[11], ctrld_p2m_tie, ctrld_p2m_tie, ctrld_p2m_tie}),
        .safe (ctrld_p2m_tie),
        .dout (ctrld_phy2mac[2])
    );

    //------------------------------------------------------------
    // PHY -> DPR: mask-gated read-only tap. Not a driven/contended wire, so
    // no pipe_lane_sel_sync needed here -- just each signal's safe/tie value
    // (same tie_off convention as an unowned controller port) when unmasked.
    // tie_off=lane0 has no meaningful "DPR's own base lane" to fall back to
    // (DPR's masked set is a live runtime value, not fixed), so it resolves
    // to '0 for DPR specifically.
    //------------------------------------------------------------
    phy2mac_lane_t dpr_p2m_tie;
    assign dpr_p2m_tie = '{
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: '0,
        default: '0
    };
    assign dpr_phy2mac[0] = v_lane_mask[0] ? phy_phy2mac[0] : dpr_p2m_tie;
    assign dpr_phy2mac[1] = v_lane_mask[1] ? phy_phy2mac[1] : dpr_p2m_tie;
    assign dpr_phy2mac[2] = v_lane_mask[2] ? phy_phy2mac[2] : dpr_p2m_tie;
    assign dpr_phy2mac[3] = v_lane_mask[3] ? phy_phy2mac[3] : dpr_p2m_tie;
    assign dpr_phy2mac[4] = v_lane_mask[4] ? phy_phy2mac[4] : dpr_p2m_tie;
    assign dpr_phy2mac[5] = v_lane_mask[5] ? phy_phy2mac[5] : dpr_p2m_tie;
    assign dpr_phy2mac[6] = v_lane_mask[6] ? phy_phy2mac[6] : dpr_p2m_tie;
    assign dpr_phy2mac[7] = v_lane_mask[7] ? phy_phy2mac[7] : dpr_p2m_tie;
    assign dpr_phy2mac[8] = v_lane_mask[8] ? phy_phy2mac[8] : dpr_p2m_tie;
    assign dpr_phy2mac[9] = v_lane_mask[9] ? phy_phy2mac[9] : dpr_p2m_tie;
    assign dpr_phy2mac[10] = v_lane_mask[10] ? phy_phy2mac[10] : dpr_p2m_tie;
    assign dpr_phy2mac[11] = v_lane_mask[11] ? phy_phy2mac[11] : dpr_p2m_tie;

endmodule
