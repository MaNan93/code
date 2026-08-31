//
// PIPE lane mapper MAC->PHY data mux.
// pipe_lane_data_mux performs polarity normalization internally; output is SAFE_M2P when sel is all-zero.
import pipe_lane_signal_pkg::*;

module pipe_lane_data_m2p #(
    parameter int NL = 12
) (
    input  lane_sel_t              sel_tgt,
    output mac2phy_lane_t [NL-1:0] phy_mac2phy,
    input  mac2phy_lane_t [11:0] ctrla_mac2phy,
    input  mac2phy_lane_t [11:0] ctrlb_mac2phy,
    input  mac2phy_lane_t [11:0] ctrlc_mac2phy,
    input  mac2phy_lane_t [11:0] ctrld_mac2phy
);

    assign phy_mac2phy[0] = ctrla_mac2phy[0];  // direct connection
    assign phy_mac2phy[1] = ctrla_mac2phy[1];  // direct connection
    assign phy_mac2phy[2] = ctrla_mac2phy[2];  // direct connection
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(2)) u_m2p_l3 (
        .sel  (sel_tgt.g1),
        .din  ({ctrlb_mac2phy[0], ctrla_mac2phy[3]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[3])
    );
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(2)) u_m2p_l4 (
        .sel  (sel_tgt.g1),
        .din  ({ctrlb_mac2phy[1], ctrla_mac2phy[4]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[4])
    );
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(2)) u_m2p_l5 (
        .sel  (sel_tgt.g1),
        .din  ({ctrlb_mac2phy[2], ctrla_mac2phy[5]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[5])
    );
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(2)) u_m2p_l6 (
        .sel  (sel_tgt.g2),
        .din  ({ctrlc_mac2phy[0], ctrla_mac2phy[6]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[6])
    );
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(2)) u_m2p_l7 (
        .sel  (sel_tgt.g2),
        .din  ({ctrlc_mac2phy[1], ctrla_mac2phy[7]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[7])
    );
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(2)) u_m2p_l8 (
        .sel  (sel_tgt.g2),
        .din  ({ctrlc_mac2phy[2], ctrla_mac2phy[8]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[8])
    );
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(4)) u_m2p_l9 (
        .sel  (sel_tgt.g3),
        .din  ({ctrld_mac2phy[0], ctrlc_mac2phy[3], ctrlb_mac2phy[3], ctrla_mac2phy[9]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[9])
    );
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(4)) u_m2p_l10 (
        .sel  (sel_tgt.g3),
        .din  ({ctrld_mac2phy[1], ctrlc_mac2phy[4], ctrlb_mac2phy[4], ctrla_mac2phy[10]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[10])
    );
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(4)) u_m2p_l11 (
        .sel  (sel_tgt.g3),
        .din  ({ctrld_mac2phy[2], ctrlc_mac2phy[5], ctrlb_mac2phy[5], ctrla_mac2phy[11]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[11])
    );

endmodule
