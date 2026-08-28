//
// PIPE lane mapper feedback reset-mux submodule.
// Each lane's phy_rst_n connects to its current owner's ctrl_rst_n.
// The input port is named sel_tgt, but at the top level it's actually wired to
// pipe_lane_sel_gen's dec_tgt (the decoder's raw output, not synchronized by sel_sync),
// not sel_gen's final external sel_tgt -- reset follows mode directly, without waiting for sel_sync.
// Reuses pipe_lane_data_mux's polarity normalization: when sel_tgt is all-zero (the handoff window,
// no owner), the safe state is to hold reset (0), not float or hold the previous owner.
import pipe_pkg::*;

module pipe_lane_rst_mux #(
    parameter int LANE_COUNT = 16,
    parameter int NUM_CTRL   = 4
) (
    input  logic [NUM_CTRL-1:0]   ctrl_rst_n,
    input  lane_sel_t              sel_tgt,
    output logic [LANE_COUNT-1:0] phy_rst_n
);

    assign phy_rst_n[0] = ctrl_rst_n[0];  // G0 direct to Ctrl0
    assign phy_rst_n[1] = ctrl_rst_n[0];  // G0 direct to Ctrl0
    assign phy_rst_n[2] = ctrl_rst_n[0];  // G0 direct to Ctrl0
    assign phy_rst_n[3] = ctrl_rst_n[0];  // G0 direct to Ctrl0
    // G1 lane4~7: Ctrl0, Ctrl1
    logic rst_n_g1;
    pipe_lane_data_mux #(.WIDTH(1), .N(2)) u_rst_g1 (
        .sel  (sel_tgt.g1),
        .din  ({ctrl_rst_n[1], ctrl_rst_n[0]}),
        .safe (1'b0),
        .dout (rst_n_g1)
    );
    assign phy_rst_n[4] = rst_n_g1;
    assign phy_rst_n[5] = rst_n_g1;
    assign phy_rst_n[6] = rst_n_g1;
    assign phy_rst_n[7] = rst_n_g1;
    // G2 lane8~11: Ctrl0, Ctrl2
    logic rst_n_g2;
    pipe_lane_data_mux #(.WIDTH(1), .N(2)) u_rst_g2 (
        .sel  (sel_tgt.g2),
        .din  ({ctrl_rst_n[2], ctrl_rst_n[0]}),
        .safe (1'b0),
        .dout (rst_n_g2)
    );
    assign phy_rst_n[8] = rst_n_g2;
    assign phy_rst_n[9] = rst_n_g2;
    assign phy_rst_n[10] = rst_n_g2;
    assign phy_rst_n[11] = rst_n_g2;
    // G3 lane12~15: Ctrl0, Ctrl2, Ctrl3
    logic rst_n_g3;
    pipe_lane_data_mux #(.WIDTH(1), .N(3)) u_rst_g3 (
        .sel  (sel_tgt.g3),
        .din  ({ctrl_rst_n[3], ctrl_rst_n[2], ctrl_rst_n[0]}),
        .safe (1'b0),
        .dout (rst_n_g3)
    );
    assign phy_rst_n[12] = rst_n_g3;
    assign phy_rst_n[13] = rst_n_g3;
    assign phy_rst_n[14] = rst_n_g3;
    assign phy_rst_n[15] = rst_n_g3;

endmodule
