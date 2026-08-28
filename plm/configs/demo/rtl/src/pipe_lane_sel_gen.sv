//
// PIPE lane mapper select-generation submodule.
// Decodes mode into each group's raw target dec_tgt (combinational, for rst_mux),
// then uses sel_sync for break-before-make + cross-clock-domain synchronization to
// produce the final effective sel_tgt (for clk_mux's feedback clock mux and the data muxes).
// pclk_tgt_cX is produced by the internal decoder and passed through to pipe_lane_clk_mux
// for glitch-free switching of controller pclk candidates.
// Group sel_sync mode: sync (SYNC=1, safe across clock domains)
import pipe_pkg::*;

module pipe_lane_sel_gen #(
    parameter int NM = 4,
    parameter int NC = 4
) (
    input  logic [$clog2(NM)-1:0] mode,
    input  logic [NC-1:0]   ctrl_pclk,
    input  logic [NC-1:0]   ctrl_rst_n,

    output lane_sel_t sel_tgt,   // final effective selection after sel_sync synchronization; used by clk_mux/data mux
    output lane_sel_t dec_tgt   // decoder's raw (unsynchronized) target; used by rst_mux
);

    pipe_lane_mode_dec #(
        .NM (NM),
        .NC  (NC)
    ) u_mode_dec (
        .mode     (mode),
        .sel_tgt  (dec_tgt)
    );

    //------------------------------------------------------------
    // One sel_sync per non-direct group (SYNC=1'b1).
    //------------------------------------------------------------
    // G1 lane4~7: Ctrl0, Ctrl1
    sel_sync #(.N(2), .SYNC(1'b1)) u_sel_sync_g1 (
        .branch_clk   ({ctrl_pclk[1], ctrl_pclk[0]}),
        .branch_rst_n ({ctrl_rst_n[1], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g1),
        .en           (sel_tgt.g1)
    );

    // G2 lane8~11: Ctrl0, Ctrl2
    sel_sync #(.N(2), .SYNC(1'b1)) u_sel_sync_g2 (
        .branch_clk   ({ctrl_pclk[2], ctrl_pclk[0]}),
        .branch_rst_n ({ctrl_rst_n[2], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g2),
        .en           (sel_tgt.g2)
    );

    // G3 lane12~15: Ctrl0, Ctrl2, Ctrl3
    sel_sync #(.N(3), .SYNC(1'b1)) u_sel_sync_g3 (
        .branch_clk   ({ctrl_pclk[3], ctrl_pclk[2], ctrl_pclk[0]}),
        .branch_rst_n ({ctrl_rst_n[3], ctrl_rst_n[2], ctrl_rst_n[0]}),
        .tgt          (dec_tgt.g3),
        .en           (sel_tgt.g3)
    );

endmodule
