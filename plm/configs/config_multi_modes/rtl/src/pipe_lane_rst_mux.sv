//
// PIPE lane mapper feedback reset-mux submodule.
// Each lane's phy_rst_n connects to its current owner's ctrl_rst_n.
// The input port is named sel_tgt, but at the top level it's actually wired to
// pipe_lane_sel_gen's dec_tgt (the decoder's raw output, not synchronized by sel_sync),
// not sel_gen's final external sel_tgt -- reset follows mode directly, without waiting for sel_sync.
// Reuses onehot_mux's polarity normalization: when sel_tgt is all-zero (the handoff window,
// no owner), the safe state is to hold reset (0), not float or hold the previous owner.
import pipe_pkg::*;

module pipe_lane_rst_mux #(
    parameter int LANE_COUNT = 4,
    parameter int NUM_CTRL   = 2
) (
    input  logic [NUM_CTRL-1:0]   ctrl_rst_n,
    input  lane_sel_t              sel_tgt,
    output logic [LANE_COUNT-1:0] phy_rst_n
);

    assign phy_rst_n[0] = ctrl_rst_n[0];  // G0 direct to PCIe_x4
    assign phy_rst_n[1] = ctrl_rst_n[0];  // G0 direct to PCIe_x4
    // G1 lane2~3: PCIe_x4, USB_x2
    logic rst_n_g1;
    onehot_mux #(.WIDTH(1), .N(2)) u_rst_g1 (
        .sel  (sel_tgt.g1),
        .din  ({ctrl_rst_n[1], ctrl_rst_n[0]}),
        .safe (1'b0),
        .dout (rst_n_g1)
    );
    assign phy_rst_n[2] = rst_n_g1;
    assign phy_rst_n[3] = rst_n_g1;

endmodule
