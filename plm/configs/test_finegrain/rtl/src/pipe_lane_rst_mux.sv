//
// PIPE lane mapper feedback reset-mux submodule.
// Each lane's phy_rst_n connects to its current owner's ctrl_rst_n.
// The input port is named sel_tgt, but at the top level it's actually wired to
// pipe_lane_sel_gen's dec_tgt (the decoder's raw output, not synchronized by pipe_lane_sel_sync),
// not sel_gen's final external sel_tgt -- reset follows mode directly, without waiting for pipe_lane_sel_sync.
// Reuses pipe_lane_data_mux's polarity normalization: when sel_tgt is all-zero (the handoff window,
// no owner), the safe state is to hold reset (0), not float or hold the previous owner.
import pipe_lane_signal_pkg::*;

module pipe_lane_rst_mux #(
    parameter int NL = 6,
    parameter int NC = 6
) (
    input  logic [NC-1:0]   ctrl_rst_n,
    input  lane_sel_t              sel_tgt,
    output logic [NL-1:0] phy_rst_n
);

    assign phy_rst_n[0] = ctrl_rst_n[0];  // G0 direct to CtrlAlpha
    // G1 lane1~1: CtrlAlpha, CtrlDelta
    logic rst_n_g1;
    pipe_lane_data_mux #(.WIDTH(1), .N(2)) u_rst_g1 (
        .sel  (sel_tgt.g1),
        .din  ({ctrl_rst_n[3], ctrl_rst_n[0]}),
        .safe (1'b0),
        .dout (rst_n_g1)
    );
    assign phy_rst_n[1] = rst_n_g1;
    // G2 lane2~2: CtrlAlpha, CtrlEpsilon
    logic rst_n_g2;
    pipe_lane_data_mux #(.WIDTH(1), .N(2)) u_rst_g2 (
        .sel  (sel_tgt.g2),
        .din  ({ctrl_rst_n[4], ctrl_rst_n[0]}),
        .safe (1'b0),
        .dout (rst_n_g2)
    );
    assign phy_rst_n[2] = rst_n_g2;
    assign phy_rst_n[3] = ctrl_rst_n[1];  // G3 direct to CtrlBeta
    // G4 lane4~4: CtrlBeta, CtrlZeta
    logic rst_n_g4;
    pipe_lane_data_mux #(.WIDTH(1), .N(2)) u_rst_g4 (
        .sel  (sel_tgt.g4),
        .din  ({ctrl_rst_n[5], ctrl_rst_n[1]}),
        .safe (1'b0),
        .dout (rst_n_g4)
    );
    assign phy_rst_n[4] = rst_n_g4;
    assign phy_rst_n[5] = ctrl_rst_n[2];  // G5 direct to CtrlGamma

endmodule
