//
// PIPE lane mapper MAC->PHY data mux.
// pipe_lane_data_mux performs polarity normalization internally; output is SAFE_M2P when sel is all-zero.
import pipe_pkg::*;

module pipe_lane_data_m2p #(
    parameter int NL = 16
) (
    input  lane_sel_t              sel_tgt,
    output mac2phy_lane_t [NL-1:0] phy_mac2phy,
    input  mac2phy_lane_t [15:0] ctrl0_mac2phy,
    input  mac2phy_lane_t [15:0] ctrl1_mac2phy,
    input  mac2phy_lane_t [15:0] ctrl2_mac2phy,
    input  mac2phy_lane_t [15:0] ctrl3_mac2phy
);

    assign phy_mac2phy[0] = ctrl0_mac2phy[0];  // direct connection
    assign phy_mac2phy[1] = ctrl0_mac2phy[1];  // direct connection
    assign phy_mac2phy[2] = ctrl0_mac2phy[2];  // direct connection
    assign phy_mac2phy[3] = ctrl0_mac2phy[3];  // direct connection
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(2)) u_m2p_l4 (
        .sel  (sel_tgt.g1),
        .din  ({ctrl1_mac2phy[0], ctrl0_mac2phy[4]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[4])
    );
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(2)) u_m2p_l5 (
        .sel  (sel_tgt.g1),
        .din  ({ctrl1_mac2phy[1], ctrl0_mac2phy[5]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[5])
    );
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(2)) u_m2p_l6 (
        .sel  (sel_tgt.g1),
        .din  ({ctrl1_mac2phy[2], ctrl0_mac2phy[6]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[6])
    );
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(2)) u_m2p_l7 (
        .sel  (sel_tgt.g1),
        .din  ({ctrl1_mac2phy[3], ctrl0_mac2phy[7]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[7])
    );
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(2)) u_m2p_l8 (
        .sel  (sel_tgt.g2),
        .din  ({ctrl2_mac2phy[0], ctrl0_mac2phy[8]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[8])
    );
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(2)) u_m2p_l9 (
        .sel  (sel_tgt.g2),
        .din  ({ctrl2_mac2phy[1], ctrl0_mac2phy[9]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[9])
    );
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(2)) u_m2p_l10 (
        .sel  (sel_tgt.g2),
        .din  ({ctrl2_mac2phy[2], ctrl0_mac2phy[10]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[10])
    );
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(2)) u_m2p_l11 (
        .sel  (sel_tgt.g2),
        .din  ({ctrl2_mac2phy[3], ctrl0_mac2phy[11]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[11])
    );
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(3)) u_m2p_l12 (
        .sel  (sel_tgt.g3),
        .din  ({ctrl3_mac2phy[0], ctrl2_mac2phy[4], ctrl0_mac2phy[12]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[12])
    );
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(3)) u_m2p_l13 (
        .sel  (sel_tgt.g3),
        .din  ({ctrl3_mac2phy[1], ctrl2_mac2phy[5], ctrl0_mac2phy[13]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[13])
    );
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(3)) u_m2p_l14 (
        .sel  (sel_tgt.g3),
        .din  ({ctrl3_mac2phy[2], ctrl2_mac2phy[6], ctrl0_mac2phy[14]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[14])
    );
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(3)) u_m2p_l15 (
        .sel  (sel_tgt.g3),
        .din  ({ctrl3_mac2phy[3], ctrl2_mac2phy[7], ctrl0_mac2phy[15]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[15])
    );

endmodule
