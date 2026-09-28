// PIPE lane mapper select-generation submodule.
// Decodes mode into each group's raw target dec_tgt (combinational, for rst_mux),
// then uses pipe_lane_sel_sync for non-overlap + cross-clock-domain synchronization to
// produce the final effective sel_tgt (for clk_mux's feedback clock mux and the data muxes).
// pclk_tgt_cX is produced by the internal decoder and passed through to pipe_lane_clk_mux
// for glitch-free switching of controller pclk candidates.
// SEL_SYNC default: sync (1'b1, safe across clock domains)
import pipe_lane_signal_pkg::*;

module pipe_lane_sel_gen #(
    parameter int NC = 4,
    parameter int NL = 12,
    parameter bit SEL_SYNC = 1'b1   // pipe_lane_sel_sync's SYNC for every data-path select in this module
) (
    input logic [1:0] mode,
    input logic [11:0] ctrla_pclk,   // CtrlA's own already-divided pclk; bit 0 is this controller's working-clock reference
    input logic [5:0] ctrlb_pclk,   // CtrlB's own already-divided pclk; bit 0 is this controller's working-clock reference
    input logic [7:0] ctrlc_pclk,   // CtrlC's own already-divided pclk; bit 0 is this controller's working-clock reference
    input logic [2:0] ctrld_pclk,   // CtrlD's own already-divided pclk; bit 0 is this controller's working-clock reference
    input logic [NC-1:0] ctrl_rst_n,
    input logic [NL-1:0] rx_clk,   // PHY's per-lane recovered clock
    output lane_sel_t dec_tgt,   // decoder's raw (unsynchronized) target; used by rst_mux
    output logic [1:0] seltgt_g1_l3,   // dec_tgt.g1 synchronized into this lane's owning candidate's own ctrl lane's clock; used by data_m2p/data_p2m
    output logic [1:0] seltgt_g1_l4,   // dec_tgt.g1 synchronized into this lane's owning candidate's own ctrl lane's clock; used by data_m2p/data_p2m
    output logic [1:0] seltgt_g1_l5,   // dec_tgt.g1 synchronized into this lane's owning candidate's own ctrl lane's clock; used by data_m2p/data_p2m
    output logic [1:0] seltgt_g2_l6,   // dec_tgt.g2 synchronized into this lane's owning candidate's own ctrl lane's clock; used by data_m2p/data_p2m
    output logic [1:0] seltgt_g2_l7,   // dec_tgt.g2 synchronized into this lane's owning candidate's own ctrl lane's clock; used by data_m2p/data_p2m
    output logic [1:0] seltgt_g2_l8,   // dec_tgt.g2 synchronized into this lane's owning candidate's own ctrl lane's clock; used by data_m2p/data_p2m
    output logic [3:0] seltgt_g3_l9,   // dec_tgt.g3 synchronized into this lane's owning candidate's own ctrl lane's clock; used by data_m2p/data_p2m
    output logic [3:0] seltgt_g3_l10,   // dec_tgt.g3 synchronized into this lane's owning candidate's own ctrl lane's clock; used by data_m2p/data_p2m
    output logic [3:0] seltgt_g3_l11,   // dec_tgt.g3 synchronized into this lane's owning candidate's own ctrl lane's clock; used by data_m2p/data_p2m
    output logic [1:0] rxclk_en_g1_l3,   // dec_tgt.g1 synchronized into rx_clk[3]'s own domain, for clk_mux's rx_clk gating
    output logic [1:0] rxclk_en_g1_l4,   // dec_tgt.g1 synchronized into rx_clk[4]'s own domain, for clk_mux's rx_clk gating
    output logic [1:0] rxclk_en_g1_l5,   // dec_tgt.g1 synchronized into rx_clk[5]'s own domain, for clk_mux's rx_clk gating
    output logic [1:0] rxclk_en_g2_l6,   // dec_tgt.g2 synchronized into rx_clk[6]'s own domain, for clk_mux's rx_clk gating
    output logic [1:0] rxclk_en_g2_l7,   // dec_tgt.g2 synchronized into rx_clk[7]'s own domain, for clk_mux's rx_clk gating
    output logic [1:0] rxclk_en_g2_l8,   // dec_tgt.g2 synchronized into rx_clk[8]'s own domain, for clk_mux's rx_clk gating
    output logic [3:0] rxclk_en_g3_l9,   // dec_tgt.g3 synchronized into rx_clk[9]'s own domain, for clk_mux's rx_clk gating
    output logic [3:0] rxclk_en_g3_l10,   // dec_tgt.g3 synchronized into rx_clk[10]'s own domain, for clk_mux's rx_clk gating
    output logic [3:0] rxclk_en_g3_l11   // dec_tgt.g3 synchronized into rx_clk[11]'s own domain, for clk_mux's rx_clk gating
);

    pipe_lane_mode_dec #(
        .NC (NC)
    ) u_mode_dec (
        .mode     (mode),
        .sel_tgt  (dec_tgt)
    );

    //------------------------------------------------------------
    // Data-path select: one pipe_lane_sel_sync per BBM LANE (not per group),
    // synchronizing dec_tgt.gN into the clock of the ctrl lane that lane
    // routes to -- {c}_pclk is per ctrl lane, so a group-shared sel_tgt
    // synchronized against only one candidate's ctrl lane would be the wrong
    // domain for whichever other one that lane actually routes to.
    //------------------------------------------------------------
    // G1 lane3~5: CtrlA, CtrlB, per-lane select
    pipe_lane_sel_sync #(.N(2), .SYNC(SEL_SYNC)) u_seltgt_sel_sync_g1_l3 (
        .branch_clk   ({ctrlb_pclk[0], ctrla_pclk[3]}),
        .branch_rst_n ({ctrl_rst_n[1], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g1),
        .en           (seltgt_g1_l3)
    );

    pipe_lane_sel_sync #(.N(2), .SYNC(SEL_SYNC)) u_seltgt_sel_sync_g1_l4 (
        .branch_clk   ({ctrlb_pclk[1], ctrla_pclk[4]}),
        .branch_rst_n ({ctrl_rst_n[1], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g1),
        .en           (seltgt_g1_l4)
    );

    pipe_lane_sel_sync #(.N(2), .SYNC(SEL_SYNC)) u_seltgt_sel_sync_g1_l5 (
        .branch_clk   ({ctrlb_pclk[2], ctrla_pclk[5]}),
        .branch_rst_n ({ctrl_rst_n[1], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g1),
        .en           (seltgt_g1_l5)
    );

    // G2 lane6~8: CtrlA, CtrlC, per-lane select
    pipe_lane_sel_sync #(.N(2), .SYNC(SEL_SYNC)) u_seltgt_sel_sync_g2_l6 (
        .branch_clk   ({ctrlc_pclk[0], ctrla_pclk[6]}),
        .branch_rst_n ({ctrl_rst_n[2], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g2),
        .en           (seltgt_g2_l6)
    );

    pipe_lane_sel_sync #(.N(2), .SYNC(SEL_SYNC)) u_seltgt_sel_sync_g2_l7 (
        .branch_clk   ({ctrlc_pclk[1], ctrla_pclk[7]}),
        .branch_rst_n ({ctrl_rst_n[2], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g2),
        .en           (seltgt_g2_l7)
    );

    pipe_lane_sel_sync #(.N(2), .SYNC(SEL_SYNC)) u_seltgt_sel_sync_g2_l8 (
        .branch_clk   ({ctrlc_pclk[2], ctrla_pclk[8]}),
        .branch_rst_n ({ctrl_rst_n[2], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g2),
        .en           (seltgt_g2_l8)
    );

    // G3 lane9~11: CtrlA, CtrlB, CtrlC, CtrlD, per-lane select
    pipe_lane_sel_sync #(.N(4), .SYNC(SEL_SYNC)) u_seltgt_sel_sync_g3_l9 (
        .branch_clk   ({ctrld_pclk[0], ctrlc_pclk[3], ctrlb_pclk[3], ctrla_pclk[9]}),
        .branch_rst_n ({ctrl_rst_n[3], ctrl_rst_n[2], ctrl_rst_n[1], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g3),
        .en           (seltgt_g3_l9)
    );

    pipe_lane_sel_sync #(.N(4), .SYNC(SEL_SYNC)) u_seltgt_sel_sync_g3_l10 (
        .branch_clk   ({ctrld_pclk[1], ctrlc_pclk[4], ctrlb_pclk[4], ctrla_pclk[10]}),
        .branch_rst_n ({ctrl_rst_n[3], ctrl_rst_n[2], ctrl_rst_n[1], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g3),
        .en           (seltgt_g3_l10)
    );

    pipe_lane_sel_sync #(.N(4), .SYNC(SEL_SYNC)) u_seltgt_sel_sync_g3_l11 (
        .branch_clk   ({ctrld_pclk[2], ctrlc_pclk[5], ctrlb_pclk[5], ctrla_pclk[11]}),
        .branch_rst_n ({ctrl_rst_n[3], ctrl_rst_n[2], ctrl_rst_n[1], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g3),
        .en           (seltgt_g3_l11)
    );

    //------------------------------------------------------------
    // rx_clk routing (PHY->controller, not feedback): one pipe_lane_sel_sync per BBM lane, synchronizing
    // dec_tgt.gN into that lane's own rx_clk[lane_idx] domain (rx_clk has no fixed phase
    // relation to {c}_pclk, unlike the rest of the PIPE-level signals).
    // clk_mux does the final pipe_lane_clk_gate + assign with this enable.
    //------------------------------------------------------------
    pipe_lane_sel_sync #(.N(2), .SYNC(1'b1)) u_rxclk_sel_sync_g1_l3 (
        .branch_clk   ({2{rx_clk[3]}}),
        .branch_rst_n ({ctrl_rst_n[1], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g1),
        .en           (rxclk_en_g1_l3)
    );

    pipe_lane_sel_sync #(.N(2), .SYNC(1'b1)) u_rxclk_sel_sync_g1_l4 (
        .branch_clk   ({2{rx_clk[4]}}),
        .branch_rst_n ({ctrl_rst_n[1], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g1),
        .en           (rxclk_en_g1_l4)
    );

    pipe_lane_sel_sync #(.N(2), .SYNC(1'b1)) u_rxclk_sel_sync_g1_l5 (
        .branch_clk   ({2{rx_clk[5]}}),
        .branch_rst_n ({ctrl_rst_n[1], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g1),
        .en           (rxclk_en_g1_l5)
    );

    pipe_lane_sel_sync #(.N(2), .SYNC(1'b1)) u_rxclk_sel_sync_g2_l6 (
        .branch_clk   ({2{rx_clk[6]}}),
        .branch_rst_n ({ctrl_rst_n[2], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g2),
        .en           (rxclk_en_g2_l6)
    );

    pipe_lane_sel_sync #(.N(2), .SYNC(1'b1)) u_rxclk_sel_sync_g2_l7 (
        .branch_clk   ({2{rx_clk[7]}}),
        .branch_rst_n ({ctrl_rst_n[2], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g2),
        .en           (rxclk_en_g2_l7)
    );

    pipe_lane_sel_sync #(.N(2), .SYNC(1'b1)) u_rxclk_sel_sync_g2_l8 (
        .branch_clk   ({2{rx_clk[8]}}),
        .branch_rst_n ({ctrl_rst_n[2], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g2),
        .en           (rxclk_en_g2_l8)
    );

    pipe_lane_sel_sync #(.N(4), .SYNC(1'b1)) u_rxclk_sel_sync_g3_l9 (
        .branch_clk   ({4{rx_clk[9]}}),
        .branch_rst_n ({ctrl_rst_n[3], ctrl_rst_n[2], ctrl_rst_n[1], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g3),
        .en           (rxclk_en_g3_l9)
    );

    pipe_lane_sel_sync #(.N(4), .SYNC(1'b1)) u_rxclk_sel_sync_g3_l10 (
        .branch_clk   ({4{rx_clk[10]}}),
        .branch_rst_n ({ctrl_rst_n[3], ctrl_rst_n[2], ctrl_rst_n[1], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g3),
        .en           (rxclk_en_g3_l10)
    );

    pipe_lane_sel_sync #(.N(4), .SYNC(1'b1)) u_rxclk_sel_sync_g3_l11 (
        .branch_clk   ({4{rx_clk[11]}}),
        .branch_rst_n ({ctrl_rst_n[3], ctrl_rst_n[2], ctrl_rst_n[1], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g3),
        .en           (rxclk_en_g3_l11)
    );

endmodule
