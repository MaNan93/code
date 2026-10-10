// PIPE lane mapper reset-mux submodule.
// Each lane's phy_rst_n connects to its current owner's ctrl_rst_n.
// Independent phy_perst_n follows the same owner using ctrl_perst_n.
// The input port is named sel_tgt, but at the top level it's actually wired to
// pipe_lane_sel_gen's dec_tgt (the decoder's raw output, not synchronized by pipe_lane_sel_sync),
// not sel_gen's final external sel_tgt -- reset follows mode directly, without waiting for pipe_lane_sel_sync.
// Reuses pipe_lane_data_mux's polarity normalization: when sel_tgt is all-zero (the handoff window,
// no owner), the safe state is to hold reset (0), not float or hold the previous owner.
import pipe_lane_signal_pkg::*;

module pipe_lane_rst_mux #(
    parameter int NL = 12,
    parameter int NC = 4
) (
    input logic [NC-1:0] ctrl_rst_n,
    input logic [NC-1:0] ctrl_perst_n,
    input lane_sel_t sel_tgt,
    output logic [NL-1:0] phy_rst_n,
    output logic [NL-1:0] phy_perst_n
);

    assign phy_rst_n[0] = ctrl_rst_n[0];  // G0 direct to CtrlA
    assign phy_rst_n[1] = ctrl_rst_n[0];  // G0 direct to CtrlA
    assign phy_rst_n[2] = ctrl_rst_n[0];  // G0 direct to CtrlA
    assign phy_perst_n[0] = ctrl_perst_n[0];  // G0 direct to CtrlA
    assign phy_perst_n[1] = ctrl_perst_n[0];  // G0 direct to CtrlA
    assign phy_perst_n[2] = ctrl_perst_n[0];  // G0 direct to CtrlA
    // G1 lane3~5: CtrlA, CtrlB
    logic rst_n_g1;
    pipe_lane_data_mux #(.WIDTH(1), .N(2)) u_rst_g1 (
        .sel  (sel_tgt.g1),
        .din  ({ctrl_rst_n[1], ctrl_rst_n[0]}),
        .safe (1'b0),
        .dout (rst_n_g1)
    );
    assign phy_rst_n[3] = rst_n_g1;
    assign phy_rst_n[4] = rst_n_g1;
    assign phy_rst_n[5] = rst_n_g1;
    logic perst_n_g1;
    pipe_lane_data_mux #(.WIDTH(1), .N(2)) u_perst_g1 (
        .sel  (sel_tgt.g1),
        .din  ({ctrl_perst_n[1], ctrl_perst_n[0]}),
        .safe (1'b0),
        .dout (perst_n_g1)
    );
    assign phy_perst_n[3] = perst_n_g1;
    assign phy_perst_n[4] = perst_n_g1;
    assign phy_perst_n[5] = perst_n_g1;
    // G2 lane6~8: CtrlA, CtrlC
    logic rst_n_g2;
    pipe_lane_data_mux #(.WIDTH(1), .N(2)) u_rst_g2 (
        .sel  (sel_tgt.g2),
        .din  ({ctrl_rst_n[2], ctrl_rst_n[0]}),
        .safe (1'b0),
        .dout (rst_n_g2)
    );
    assign phy_rst_n[6] = rst_n_g2;
    assign phy_rst_n[7] = rst_n_g2;
    assign phy_rst_n[8] = rst_n_g2;
    logic perst_n_g2;
    pipe_lane_data_mux #(.WIDTH(1), .N(2)) u_perst_g2 (
        .sel  (sel_tgt.g2),
        .din  ({ctrl_perst_n[2], ctrl_perst_n[0]}),
        .safe (1'b0),
        .dout (perst_n_g2)
    );
    assign phy_perst_n[6] = perst_n_g2;
    assign phy_perst_n[7] = perst_n_g2;
    assign phy_perst_n[8] = perst_n_g2;
    // G3 lane9~11: CtrlA, CtrlB, CtrlC, CtrlD
    logic rst_n_g3;
    pipe_lane_data_mux #(.WIDTH(1), .N(4)) u_rst_g3 (
        .sel  (sel_tgt.g3),
        .din  ({ctrl_rst_n[3], ctrl_rst_n[2], ctrl_rst_n[1], ctrl_rst_n[0]}),
        .safe (1'b0),
        .dout (rst_n_g3)
    );
    assign phy_rst_n[9] = rst_n_g3;
    assign phy_rst_n[10] = rst_n_g3;
    assign phy_rst_n[11] = rst_n_g3;
    logic perst_n_g3;
    pipe_lane_data_mux #(.WIDTH(1), .N(4)) u_perst_g3 (
        .sel  (sel_tgt.g3),
        .din  ({ctrl_perst_n[3], ctrl_perst_n[2], ctrl_perst_n[1], ctrl_perst_n[0]}),
        .safe (1'b0),
        .dout (perst_n_g3)
    );
    assign phy_perst_n[9] = perst_n_g3;
    assign phy_perst_n[10] = perst_n_g3;
    assign phy_perst_n[11] = perst_n_g3;

endmodule
