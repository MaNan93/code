//
// mode decoding: produces each lane group's target owner, and each
// controller's target pclk source. Purely combinational, no state.
//
// Output feeds directly into NOV's tgt port; NOV handles cross-domain
// synchronization and interlocking.
import pipe_lane_signal_pkg::*;

module pipe_lane_mode_dec #(
    parameter int NM = 3,
    /* verilator lint_off UNUSEDPARAM */
    parameter int NC = 4   // only used by controllers with more than one candidate
    /* verilator lint_on UNUSEDPARAM */
) (
    input  logic [$clog2(NM)-1:0] mode,
    output lane_sel_t sel_tgt
);

    always_comb begin
        sel_tgt = '0;

        unique case (mode)
            0: begin
                sel_tgt.g1 = 2'b01;  // CtrlX16
                sel_tgt.g2 = 2'b01;  // CtrlX16
                sel_tgt.g3 = 3'b001;  // CtrlX16
            end
            1: begin
                sel_tgt.g1 = 2'b01;  // CtrlX16
                sel_tgt.g2 = 2'b10;  // CtrlX8
                sel_tgt.g3 = 3'b010;  // CtrlX8
            end
            2: begin
                sel_tgt.g1 = 2'b10;  // CtrlX4b
                sel_tgt.g2 = 2'b10;  // CtrlX8
                sel_tgt.g3 = 3'b100;  // CtrlX4a
            end
            default: begin
                sel_tgt = '0;
            end
        endcase
    end

endmodule
