//=============================================================================
// pipe_lane_clk_gate -- clock-gating wrapper
//
// When gating a clock, the enable must only toggle while the clock is low,
// otherwise the output can produce a narrow runt pulse. Guaranteeing that
// requires a latch that's transparent while the clock is low (equivalent to
// a negedge flop, but this project doesn't allow negedge registers).
//
// The default implementation uses an inferred latch, for simulation and
// early synthesis. For tapeout, define PIPE_USE_ICG_CELL to swap in the
// process library's ICG cell (adjust the cell name/ports to match the
// actual library) -- the external logic is unaffected.
//
// en must already be registered in the clk_in domain (guaranteed by
// nov_sel_onehot).
//=============================================================================
module pipe_lane_clk_gate (
    input  logic clk_in,
    input  logic en,        // same domain as clk_in, already registered
    input  logic test_en,   // DFT: force on during scan shift
    output logic clk_out
);

`ifdef PIPE_USE_ICG_CELL
    // Swap in the actual process library cell, e.g.:
    // CKLNQD1 u_icg (.CP(clk_in), .E(en), .TE(test_en), .Q(clk_out));
    `PIPE_ICG_CELL u_icg (.CP(clk_in), .E(en), .TE(test_en), .Q(clk_out));
`else
    logic en_latched;

    always_latch begin
        if (!clk_in) en_latched = en | test_en;   // transparent while clk is low (latch uses blocking assign)
    end

    assign clk_out = clk_in & en_latched;
`endif

endmodule
