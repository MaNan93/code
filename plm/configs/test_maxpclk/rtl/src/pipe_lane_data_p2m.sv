// PIPE lane mapper PHY->MAC data mux (converges by controller port).
// sel_tgt's mutual exclusivity is guaranteed by pipe_lane_sel_sync. Undriven ports are tied to the safe state.
import pipe_lane_signal_pkg::*;

module pipe_lane_data_p2m #(
    parameter int NL = 12
) (
    input logic [1:0] seltgt_g1_l3,
    input logic [1:0] seltgt_g1_l4,
    input logic [1:0] seltgt_g1_l5,
    input logic [1:0] seltgt_g2_l6,
    input logic [1:0] seltgt_g2_l7,
    input logic [1:0] seltgt_g2_l8,
    input logic [3:0] seltgt_g3_l9,
    input logic [3:0] seltgt_g3_l10,
    input logic [3:0] seltgt_g3_l11,
    input phy2mac_lane_t [NL-1:0] phy_phy2mac,
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
        .sel  ({1'b0, seltgt_g1_l3[0]}),
        .din  ({ctrla_p2m_tie, phy_phy2mac[3]}),
        .safe (ctrla_p2m_tie),
        .dout (ctrla_phy2mac[3])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrla_4 (
        .sel  ({1'b0, seltgt_g1_l4[0]}),
        .din  ({ctrla_p2m_tie, phy_phy2mac[4]}),
        .safe (ctrla_p2m_tie),
        .dout (ctrla_phy2mac[4])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrla_5 (
        .sel  ({1'b0, seltgt_g1_l5[0]}),
        .din  ({ctrla_p2m_tie, phy_phy2mac[5]}),
        .safe (ctrla_p2m_tie),
        .dout (ctrla_phy2mac[5])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrla_6 (
        .sel  ({1'b0, seltgt_g2_l6[0]}),
        .din  ({ctrla_p2m_tie, phy_phy2mac[6]}),
        .safe (ctrla_p2m_tie),
        .dout (ctrla_phy2mac[6])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrla_7 (
        .sel  ({1'b0, seltgt_g2_l7[0]}),
        .din  ({ctrla_p2m_tie, phy_phy2mac[7]}),
        .safe (ctrla_p2m_tie),
        .dout (ctrla_phy2mac[7])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrla_8 (
        .sel  ({1'b0, seltgt_g2_l8[0]}),
        .din  ({ctrla_p2m_tie, phy_phy2mac[8]}),
        .safe (ctrla_p2m_tie),
        .dout (ctrla_phy2mac[8])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrla_9 (
        .sel  ({1'b0, 1'b0, 1'b0, seltgt_g3_l9[0]}),
        .din  ({ctrla_p2m_tie, ctrla_p2m_tie, ctrla_p2m_tie, phy_phy2mac[9]}),
        .safe (ctrla_p2m_tie),
        .dout (ctrla_phy2mac[9])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrla_10 (
        .sel  ({1'b0, 1'b0, 1'b0, seltgt_g3_l10[0]}),
        .din  ({ctrla_p2m_tie, ctrla_p2m_tie, ctrla_p2m_tie, phy_phy2mac[10]}),
        .safe (ctrla_p2m_tie),
        .dout (ctrla_phy2mac[10])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrla_11 (
        .sel  ({1'b0, 1'b0, 1'b0, seltgt_g3_l11[0]}),
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
        .sel  ({seltgt_g1_l3[1], 1'b0}),
        .din  ({phy_phy2mac[3], ctrlb_p2m_tie}),
        .safe (ctrlb_p2m_tie),
        .dout (ctrlb_phy2mac[0])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlb_1 (
        .sel  ({seltgt_g1_l4[1], 1'b0}),
        .din  ({phy_phy2mac[4], ctrlb_p2m_tie}),
        .safe (ctrlb_p2m_tie),
        .dout (ctrlb_phy2mac[1])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlb_2 (
        .sel  ({seltgt_g1_l5[1], 1'b0}),
        .din  ({phy_phy2mac[5], ctrlb_p2m_tie}),
        .safe (ctrlb_p2m_tie),
        .dout (ctrlb_phy2mac[2])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrlb_3 (
        .sel  ({1'b0, 1'b0, seltgt_g3_l9[1], 1'b0}),
        .din  ({ctrlb_p2m_tie, ctrlb_p2m_tie, phy_phy2mac[9], ctrlb_p2m_tie}),
        .safe (ctrlb_p2m_tie),
        .dout (ctrlb_phy2mac[3])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrlb_4 (
        .sel  ({1'b0, 1'b0, seltgt_g3_l10[1], 1'b0}),
        .din  ({ctrlb_p2m_tie, ctrlb_p2m_tie, phy_phy2mac[10], ctrlb_p2m_tie}),
        .safe (ctrlb_p2m_tie),
        .dout (ctrlb_phy2mac[4])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrlb_5 (
        .sel  ({1'b0, 1'b0, seltgt_g3_l11[1], 1'b0}),
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
        .sel  ({seltgt_g2_l6[1], 1'b0}),
        .din  ({phy_phy2mac[6], ctrlc_p2m_tie}),
        .safe (ctrlc_p2m_tie),
        .dout (ctrlc_phy2mac[0])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlc_1 (
        .sel  ({seltgt_g2_l7[1], 1'b0}),
        .din  ({phy_phy2mac[7], ctrlc_p2m_tie}),
        .safe (ctrlc_p2m_tie),
        .dout (ctrlc_phy2mac[1])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(2)) u_p2m_ctrlc_2 (
        .sel  ({seltgt_g2_l8[1], 1'b0}),
        .din  ({phy_phy2mac[8], ctrlc_p2m_tie}),
        .safe (ctrlc_p2m_tie),
        .dout (ctrlc_phy2mac[2])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrlc_3 (
        .sel  ({1'b0, seltgt_g3_l9[2], 1'b0, 1'b0}),
        .din  ({ctrlc_p2m_tie, phy_phy2mac[9], ctrlc_p2m_tie, ctrlc_p2m_tie}),
        .safe (ctrlc_p2m_tie),
        .dout (ctrlc_phy2mac[3])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrlc_4 (
        .sel  ({1'b0, seltgt_g3_l10[2], 1'b0, 1'b0}),
        .din  ({ctrlc_p2m_tie, phy_phy2mac[10], ctrlc_p2m_tie, ctrlc_p2m_tie}),
        .safe (ctrlc_p2m_tie),
        .dout (ctrlc_phy2mac[4])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrlc_5 (
        .sel  ({1'b0, seltgt_g3_l11[2], 1'b0, 1'b0}),
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
        .sel  ({seltgt_g3_l9[3], 1'b0, 1'b0, 1'b0}),
        .din  ({phy_phy2mac[9], ctrld_p2m_tie, ctrld_p2m_tie, ctrld_p2m_tie}),
        .safe (ctrld_p2m_tie),
        .dout (ctrld_phy2mac[0])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrld_1 (
        .sel  ({seltgt_g3_l10[3], 1'b0, 1'b0, 1'b0}),
        .din  ({phy_phy2mac[10], ctrld_p2m_tie, ctrld_p2m_tie, ctrld_p2m_tie}),
        .safe (ctrld_p2m_tie),
        .dout (ctrld_phy2mac[1])
    );
    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrld_2 (
        .sel  ({seltgt_g3_l11[3], 1'b0, 1'b0, 1'b0}),
        .din  ({phy_phy2mac[11], ctrld_p2m_tie, ctrld_p2m_tie, ctrld_p2m_tie}),
        .safe (ctrld_p2m_tie),
        .dout (ctrld_phy2mac[2])
    );

endmodule
