// mode decoding: produces each lane group's target owner, and each
// controller's target pclk source. Purely combinational, no state.
//
// Output feeds directly into NOV's tgt port; NOV handles cross-domain
// synchronization and interlocking.
import pipe_lane_signal_pkg::*;

module pipe_lane_mode_dec #(
    parameter int NC = 6   // only used by controllers with more than one candidate
) (
    input logic [1:0] mode,
    output lane_sel_t sel_tgt
);

    always_comb begin
        sel_tgt = '0;

        unique case (mode)
            0: begin
                sel_tgt.g1 = 2'b01;  // CtrlAlpha
                sel_tgt.g2 = 2'b01;  // CtrlAlpha
                sel_tgt.g4 = 2'b01;  // CtrlBeta
            end
            1: begin
                sel_tgt.g1 = 2'b10;  // CtrlDelta
                sel_tgt.g2 = 2'b10;  // CtrlEpsilon
                sel_tgt.g4 = 2'b10;  // CtrlZeta
            end
            2: begin
                sel_tgt.g1 = 2'b01;  // CtrlAlpha
                sel_tgt.g2 = 2'b10;  // CtrlEpsilon
                sel_tgt.g4 = 2'b01;  // CtrlBeta
            end
            default: begin
                sel_tgt = '0;
            end
        endcase
    end

endmodule
