//
// PIPE lane mapper MAC->PHY data mux.
// pipe_lane_data_mux performs polarity normalization internally; output is SAFE_M2P when sel is all-zero.
import pipe_lane_signal_pkg::*;

module pipe_lane_data_m2p #(
    parameter int NL = 6
) (
    input  lane_sel_t              sel_tgt,
    output mac2phy_lane_t [NL-1:0] phy_mac2phy,
    input  mac2phy_lane_t [2:0] ctrlalpha_mac2phy,
    input  mac2phy_lane_t [2:0] ctrlbeta_mac2phy,
    input  mac2phy_lane_t [2:0] ctrlgamma_mac2phy,
    input  mac2phy_lane_t [2:0] ctrldelta_mac2phy,
    input  mac2phy_lane_t [2:0] ctrlepsilon_mac2phy,
    input  mac2phy_lane_t [2:0] ctrlzeta_mac2phy
);

    assign phy_mac2phy[0] = ctrlalpha_mac2phy[0];  // direct connection
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(2)) u_m2p_l1 (
        .sel  (sel_tgt.g1),
        .din  ({ctrldelta_mac2phy[0], ctrlalpha_mac2phy[1]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[1])
    );
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(2)) u_m2p_l2 (
        .sel  (sel_tgt.g2),
        .din  ({ctrlepsilon_mac2phy[0], ctrlalpha_mac2phy[2]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[2])
    );
    assign phy_mac2phy[3] = ctrlbeta_mac2phy[0];  // direct connection
    pipe_lane_data_mux #(.WIDTH($bits(mac2phy_lane_t)), .N(2)) u_m2p_l4 (
        .sel  (sel_tgt.g4),
        .din  ({ctrlzeta_mac2phy[0], ctrlbeta_mac2phy[1]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[4])
    );
    assign phy_mac2phy[5] = ctrlgamma_mac2phy[0];  // direct connection

endmodule
