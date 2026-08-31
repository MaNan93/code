//
// mode decoding: produces each lane group's target owner, and each
// controller's target pclk source. Purely combinational, no state.
//
// Output feeds directly into BBM's tgt port; BBM handles cross-domain
// synchronization and interlocking.
import pipe_lane_signal_pkg::*;

module pipe_lane_mode_dec #(
    parameter int NM = 4,
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
                sel_tgt.g1 = 2'b01;  // CtrlA
                sel_tgt.g2 = 2'b01;  // CtrlA
                sel_tgt.g3 = 4'b0001;  // CtrlA
            end
            1: begin
                sel_tgt.g1 = 2'b10;  // CtrlB
                sel_tgt.g2 = 2'b01;  // CtrlA
                sel_tgt.g3 = 4'b0010;  // CtrlB
            end
            2: begin
                sel_tgt.g1 = 2'b01;  // CtrlA
                sel_tgt.g2 = 2'b10;  // CtrlC
                sel_tgt.g3 = 4'b0100;  // CtrlC
            end
            3: begin
                sel_tgt.g1 = 2'b10;  // CtrlB
                sel_tgt.g2 = 2'b10;  // CtrlC
                sel_tgt.g3 = 4'b1000;  // CtrlD
            end
            default: begin
                sel_tgt = '0;
            end
        endcase
    end

endmodule
