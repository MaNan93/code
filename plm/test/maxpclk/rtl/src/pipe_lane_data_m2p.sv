// PIPE lane mapper MAC->PHY data mux.
// pipe_lane_data_mux performs polarity normalization internally; output is SAFE_M2P when sel is all-zero.
import pipe_lane_signal_pkg::*;

module pipe_lane_data_m2p #(
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
    output mac2phy_lane_t [NL-1:0] phy_mac2phy,
    input mac2phy_lane_t [11:0] ctrla_mac2phy,
    input mac2phy_lane_t [5:0] ctrlb_mac2phy,
    input mac2phy_lane_t [7:0] ctrlc_mac2phy,
    input mac2phy_lane_t [2:0] ctrld_mac2phy
);

    assign phy_mac2phy[0] = ctrla_mac2phy[0];  // direct connection
    assign phy_mac2phy[1] = ctrla_mac2phy[1];  // direct connection
    assign phy_mac2phy[2] = ctrla_mac2phy[2];  // direct connection
    pipe_lane_data_mux #(.WIDTH(MAC2PHY_W), .N(2)) u_m2p_l3 (
        .sel  (seltgt_g1_l3),
        .din  ({ctrlb_mac2phy[0], ctrla_mac2phy[3]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[3])
    );
    pipe_lane_data_mux #(.WIDTH(MAC2PHY_W), .N(2)) u_m2p_l4 (
        .sel  (seltgt_g1_l4),
        .din  ({ctrlb_mac2phy[1], ctrla_mac2phy[4]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[4])
    );
    pipe_lane_data_mux #(.WIDTH(MAC2PHY_W), .N(2)) u_m2p_l5 (
        .sel  (seltgt_g1_l5),
        .din  ({ctrlb_mac2phy[2], ctrla_mac2phy[5]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[5])
    );
    pipe_lane_data_mux #(.WIDTH(MAC2PHY_W), .N(2)) u_m2p_l6 (
        .sel  (seltgt_g2_l6),
        .din  ({ctrlc_mac2phy[0], ctrla_mac2phy[6]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[6])
    );
    pipe_lane_data_mux #(.WIDTH(MAC2PHY_W), .N(2)) u_m2p_l7 (
        .sel  (seltgt_g2_l7),
        .din  ({ctrlc_mac2phy[1], ctrla_mac2phy[7]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[7])
    );
    pipe_lane_data_mux #(.WIDTH(MAC2PHY_W), .N(2)) u_m2p_l8 (
        .sel  (seltgt_g2_l8),
        .din  ({ctrlc_mac2phy[2], ctrla_mac2phy[8]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[8])
    );
    pipe_lane_data_mux #(.WIDTH(MAC2PHY_W), .N(4)) u_m2p_l9 (
        .sel  (seltgt_g3_l9),
        .din  ({ctrld_mac2phy[0], ctrlc_mac2phy[3], ctrlb_mac2phy[3], ctrla_mac2phy[9]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[9])
    );
    pipe_lane_data_mux #(.WIDTH(MAC2PHY_W), .N(4)) u_m2p_l10 (
        .sel  (seltgt_g3_l10),
        .din  ({ctrld_mac2phy[1], ctrlc_mac2phy[4], ctrlb_mac2phy[4], ctrla_mac2phy[10]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[10])
    );
    pipe_lane_data_mux #(.WIDTH(MAC2PHY_W), .N(4)) u_m2p_l11 (
        .sel  (seltgt_g3_l11),
        .din  ({ctrld_mac2phy[2], ctrlc_mac2phy[5], ctrlb_mac2phy[5], ctrla_mac2phy[11]}),
        .safe (SAFE_M2P),
        .dout (phy_mac2phy[11])
    );

endmodule
