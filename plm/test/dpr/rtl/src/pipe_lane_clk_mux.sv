// PIPE lane mapper clock-mux submodule.
// Contains: controller pclk generation, feedback clock mux.
// Each group's final sel_tgt is produced by pipe_lane_sel_gen and passed in as an input.
// The reset mux is in pipe_lane_rst_mux, the data muxes are in
// pipe_lane_data_m2p / pipe_lane_data_p2m.
import pipe_lane_signal_pkg::*;

module pipe_lane_clk_mux #(
    parameter int NL = 12,
    parameter int NC = 4
) (
    input logic [NL-1:0] phy_pclk_out,
    input logic [NC-1:0] ctrl_rst_n,
    input lane_sel_t sel_tgt,   // each group's currently effective owner selection
    input logic [NL-1:0] v_lane_mask,
    input logic dpr_rst_n,
    output logic [NC-1:0] ctrl_pclk,
    output logic dpr_pclk,
    output logic [NL-1:0] phy_pclk_in
);

    //------------------------------------------------------------
    // controller pclk: always taken from the lowest-numbered lane in its group.
    // Only needs a glitch-free switch when there's more than one candidate.
    //------------------------------------------------------------
    // CtrlA: uses phy_pclk[0] in every mode, direct connection
    assign ctrl_pclk[0] = phy_pclk_out[0];

    // CtrlB: uses phy_pclk[3] in every mode, direct connection
    assign ctrl_pclk[1] = phy_pclk_out[3];

    // CtrlC: uses phy_pclk[6] in every mode, direct connection
    assign ctrl_pclk[2] = phy_pclk_out[6];

    // CtrlD: uses phy_pclk[9] in every mode, direct connection
    assign ctrl_pclk[3] = phy_pclk_out[9];

    //------------------------------------------------------------
    // DPR's own working clock: from the lowest-numbered currently-masked
    // lane (isolate v_lane_mask's lowest set bit), glitch-free multi-candidate
    // select -- architecturally the exact same circuit as a real multi-
    // candidate controller's ctrl_pclk above, just with all NL lanes as
    // candidates. Defaults to lane9 (last group's lowest lane) when
    // idle (v_lane_mask all-zero).
    //------------------------------------------------------------
    logic [NL-1:0] dpr_pclk_tgt;
    // isolate the lowest set bit: v_lane_mask & (-v_lane_mask)
    assign dpr_pclk_tgt = v_lane_mask & (~v_lane_mask + 1'b1);

    logic [11:0] dpr_pclk_tgt_hold;
    logic [11:0] dpr_pclk_pen;
    logic [11:0] dpr_pclk_pgated;
    always_ff @(posedge phy_pclk_out[9] or negedge dpr_rst_n)
        if (!dpr_rst_n) dpr_pclk_tgt_hold <= 12'b001000000000;
        else if (|dpr_pclk_tgt) dpr_pclk_tgt_hold <= dpr_pclk_tgt;
    pipe_lane_sel_sync #(.N(12), .SYNC(1'b1)) u_dpr_pclk_sel (
        .branch_clk   ({phy_pclk_out[11], phy_pclk_out[10], phy_pclk_out[9], phy_pclk_out[8], phy_pclk_out[7], phy_pclk_out[6], phy_pclk_out[5], phy_pclk_out[4], phy_pclk_out[3], phy_pclk_out[2], phy_pclk_out[1], phy_pclk_out[0]}),
        .branch_rst_n ({12{dpr_rst_n}}),
        .tgt          (dpr_pclk_tgt_hold),
        .en           (dpr_pclk_pen)
    );
    pipe_lane_clk_gate u_dpr_pclk_gate_b0 (.clk_in(phy_pclk_out[0]), .en(dpr_pclk_pen[0]), .clk_out(dpr_pclk_pgated[0]));
    pipe_lane_clk_gate u_dpr_pclk_gate_b1 (.clk_in(phy_pclk_out[1]), .en(dpr_pclk_pen[1]), .clk_out(dpr_pclk_pgated[1]));
    pipe_lane_clk_gate u_dpr_pclk_gate_b2 (.clk_in(phy_pclk_out[2]), .en(dpr_pclk_pen[2]), .clk_out(dpr_pclk_pgated[2]));
    pipe_lane_clk_gate u_dpr_pclk_gate_b3 (.clk_in(phy_pclk_out[3]), .en(dpr_pclk_pen[3]), .clk_out(dpr_pclk_pgated[3]));
    pipe_lane_clk_gate u_dpr_pclk_gate_b4 (.clk_in(phy_pclk_out[4]), .en(dpr_pclk_pen[4]), .clk_out(dpr_pclk_pgated[4]));
    pipe_lane_clk_gate u_dpr_pclk_gate_b5 (.clk_in(phy_pclk_out[5]), .en(dpr_pclk_pen[5]), .clk_out(dpr_pclk_pgated[5]));
    pipe_lane_clk_gate u_dpr_pclk_gate_b6 (.clk_in(phy_pclk_out[6]), .en(dpr_pclk_pen[6]), .clk_out(dpr_pclk_pgated[6]));
    pipe_lane_clk_gate u_dpr_pclk_gate_b7 (.clk_in(phy_pclk_out[7]), .en(dpr_pclk_pen[7]), .clk_out(dpr_pclk_pgated[7]));
    pipe_lane_clk_gate u_dpr_pclk_gate_b8 (.clk_in(phy_pclk_out[8]), .en(dpr_pclk_pen[8]), .clk_out(dpr_pclk_pgated[8]));
    pipe_lane_clk_gate u_dpr_pclk_gate_b9 (.clk_in(phy_pclk_out[9]), .en(dpr_pclk_pen[9]), .clk_out(dpr_pclk_pgated[9]));
    pipe_lane_clk_gate u_dpr_pclk_gate_b10 (.clk_in(phy_pclk_out[10]), .en(dpr_pclk_pen[10]), .clk_out(dpr_pclk_pgated[10]));
    pipe_lane_clk_gate u_dpr_pclk_gate_b11 (.clk_in(phy_pclk_out[11]), .en(dpr_pclk_pen[11]), .clk_out(dpr_pclk_pgated[11]));
    pipe_lane_clk_or #(.N(12)) u_dpr_pclk_or (.clk_in(dpr_pclk_pgated), .clk_out(dpr_pclk));

    //------------------------------------------------------------
    // Feedback clock: each lane's pclk_in connects to its current owner's ctrl_pclk (or dpr_pclk, when DPR owns it).
    // Shares the same en group as the data path, so data and clock switch in lockstep.
    //------------------------------------------------------------
    // G0 lane0~2: CtrlA, DPR
    logic [1:0] pin_gated_g0;
    logic pclk_in_g0;
    pipe_lane_clk_gate u_pin_gate_g0_b0 (.clk_in(ctrl_pclk[0]), .en(sel_tgt.g0[0]), .clk_out(pin_gated_g0[0]));
    pipe_lane_clk_gate u_pin_gate_g0_dpr (.clk_in(dpr_pclk), .en(sel_tgt.g0[1]), .clk_out(pin_gated_g0[1]));
    pipe_lane_clk_or #(.N(2)) u_pin_or_g0 (.clk_in(pin_gated_g0), .clk_out(pclk_in_g0));
    assign phy_pclk_in[0] = pclk_in_g0;
    assign phy_pclk_in[1] = pclk_in_g0;
    assign phy_pclk_in[2] = pclk_in_g0;
    // G1 lane3~5: CtrlA, CtrlB, DPR
    logic [2:0] pin_gated_g1;
    logic pclk_in_g1;
    pipe_lane_clk_gate u_pin_gate_g1_b0 (.clk_in(ctrl_pclk[0]), .en(sel_tgt.g1[0]), .clk_out(pin_gated_g1[0]));
    pipe_lane_clk_gate u_pin_gate_g1_b1 (.clk_in(ctrl_pclk[1]), .en(sel_tgt.g1[1]), .clk_out(pin_gated_g1[1]));
    pipe_lane_clk_gate u_pin_gate_g1_dpr (.clk_in(dpr_pclk), .en(sel_tgt.g1[2]), .clk_out(pin_gated_g1[2]));
    pipe_lane_clk_or #(.N(3)) u_pin_or_g1 (.clk_in(pin_gated_g1), .clk_out(pclk_in_g1));
    assign phy_pclk_in[3] = pclk_in_g1;
    assign phy_pclk_in[4] = pclk_in_g1;
    assign phy_pclk_in[5] = pclk_in_g1;
    // G2 lane6~8: CtrlA, CtrlC, DPR
    logic [2:0] pin_gated_g2;
    logic pclk_in_g2;
    pipe_lane_clk_gate u_pin_gate_g2_b0 (.clk_in(ctrl_pclk[0]), .en(sel_tgt.g2[0]), .clk_out(pin_gated_g2[0]));
    pipe_lane_clk_gate u_pin_gate_g2_b1 (.clk_in(ctrl_pclk[2]), .en(sel_tgt.g2[1]), .clk_out(pin_gated_g2[1]));
    pipe_lane_clk_gate u_pin_gate_g2_dpr (.clk_in(dpr_pclk), .en(sel_tgt.g2[2]), .clk_out(pin_gated_g2[2]));
    pipe_lane_clk_or #(.N(3)) u_pin_or_g2 (.clk_in(pin_gated_g2), .clk_out(pclk_in_g2));
    assign phy_pclk_in[6] = pclk_in_g2;
    assign phy_pclk_in[7] = pclk_in_g2;
    assign phy_pclk_in[8] = pclk_in_g2;
    // G3 lane9~11: CtrlA, CtrlB, CtrlC, CtrlD, DPR
    logic [4:0] pin_gated_g3;
    logic pclk_in_g3;
    pipe_lane_clk_gate u_pin_gate_g3_b0 (.clk_in(ctrl_pclk[0]), .en(sel_tgt.g3[0]), .clk_out(pin_gated_g3[0]));
    pipe_lane_clk_gate u_pin_gate_g3_b1 (.clk_in(ctrl_pclk[1]), .en(sel_tgt.g3[1]), .clk_out(pin_gated_g3[1]));
    pipe_lane_clk_gate u_pin_gate_g3_b2 (.clk_in(ctrl_pclk[2]), .en(sel_tgt.g3[2]), .clk_out(pin_gated_g3[2]));
    pipe_lane_clk_gate u_pin_gate_g3_b3 (.clk_in(ctrl_pclk[3]), .en(sel_tgt.g3[3]), .clk_out(pin_gated_g3[3]));
    pipe_lane_clk_gate u_pin_gate_g3_dpr (.clk_in(dpr_pclk), .en(sel_tgt.g3[4]), .clk_out(pin_gated_g3[4]));
    pipe_lane_clk_or #(.N(5)) u_pin_or_g3 (.clk_in(pin_gated_g3), .clk_out(pclk_in_g3));
    assign phy_pclk_in[9] = pclk_in_g3;
    assign phy_pclk_in[10] = pclk_in_g3;
    assign phy_pclk_in[11] = pclk_in_g3;

endmodule
