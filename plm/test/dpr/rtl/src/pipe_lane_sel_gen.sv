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
    input logic [NC-1:0] ctrl_pclk,
    input logic [NC-1:0] ctrl_rst_n,
    input logic [NL-1:0] v_lane_mask,
    input logic dpr_rst_n,
    input logic dpr_pclk,   // external in PHY-input mode; derived in PHY-output mode
    output lane_sel_t sel_tgt,   // final effective selection after pipe_lane_sel_sync synchronization; used by clk_mux/data mux
    output lane_sel_t dec_tgt   // decoder's raw (unsynchronized) target, DPR-combined; used by rst_mux
);

    mode_sel_t dec_tgt_mode;   // decoder's own raw output, real candidates only
    pipe_lane_mode_dec #(
        .NC (NC)
    ) u_mode_dec (
        .mode     (mode),
        .sel_tgt  (dec_tgt_mode)
    );

    //------------------------------------------------------------
    // Combine each group's raw mode-based target with v_lane_mask: DPR (the
    // last bit, index g.n) unconditionally overrides the real candidates when
    // its group's mask bit is set. v_lane_mask is asserted at group
    // granularity (every lane in a group masked together, a system-level
    // usage contract, not something this generator enforces), so one
    // representative lane per group -- its lowest-numbered lane -- decides
    // the whole group.
    //------------------------------------------------------------
    assign dec_tgt.g0 = v_lane_mask[0] ? 2'b10 : {1'b0, 1'b1};
    assign dec_tgt.g1 = v_lane_mask[3] ? 3'b100 : {1'b0, dec_tgt_mode.g1};
    assign dec_tgt.g2 = v_lane_mask[6] ? 3'b100 : {1'b0, dec_tgt_mode.g2};
    assign dec_tgt.g3 = v_lane_mask[9] ? 5'b10000 : {1'b0, dec_tgt_mode.g3};

    //------------------------------------------------------------
    // One pipe_lane_sel_sync per group (SYNC=SEL_SYNC), DPR included.
    //------------------------------------------------------------
    // G0 lane0~2: CtrlA, DPR
    pipe_lane_sel_sync #(.N(2), .SYNC(SEL_SYNC)) u_sel_sync_g0 (
        .branch_clk   ({dpr_pclk, ctrl_pclk[0]}),
        .branch_rst_n ({dpr_rst_n, ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g0),
        .en           (sel_tgt.g0)
    );

    // G1 lane3~5: CtrlA, CtrlB, DPR
    pipe_lane_sel_sync #(.N(3), .SYNC(SEL_SYNC)) u_sel_sync_g1 (
        .branch_clk   ({dpr_pclk, ctrl_pclk[1], ctrl_pclk[0]}),
        .branch_rst_n ({dpr_rst_n, ctrl_rst_n[1], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g1),
        .en           (sel_tgt.g1)
    );

    // G2 lane6~8: CtrlA, CtrlC, DPR
    pipe_lane_sel_sync #(.N(3), .SYNC(SEL_SYNC)) u_sel_sync_g2 (
        .branch_clk   ({dpr_pclk, ctrl_pclk[2], ctrl_pclk[0]}),
        .branch_rst_n ({dpr_rst_n, ctrl_rst_n[2], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g2),
        .en           (sel_tgt.g2)
    );

    // G3 lane9~11: CtrlA, CtrlB, CtrlC, CtrlD, DPR
    pipe_lane_sel_sync #(.N(5), .SYNC(SEL_SYNC)) u_sel_sync_g3 (
        .branch_clk   ({dpr_pclk, ctrl_pclk[3], ctrl_pclk[2], ctrl_pclk[1], ctrl_pclk[0]}),
        .branch_rst_n ({dpr_rst_n, ctrl_rst_n[3], ctrl_rst_n[2], ctrl_rst_n[1], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g3),
        .en           (sel_tgt.g3)
    );

endmodule
