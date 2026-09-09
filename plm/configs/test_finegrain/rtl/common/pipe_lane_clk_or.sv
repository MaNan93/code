//=============================================================================
// pipe_lane_clk_or -- N-way gated-clock combiner
//
// Combines N mutually-exclusive, already-gated clock candidates (each
// already glitch-free via pipe_lane_clk_gate, so at most one is ever
// toggling at a time) into a single output. A plain OR reduction works
// functionally in simulation, but on real silicon a generic OR standard
// cell isn't characterized for clock-tree use the same way a proper
// clock-OR/clock-mux cell is -- same category of concern as using a raw
// AND for clock gating instead of an ICG cell.
//
// The default implementation is a plain OR reduction, for simulation and
// early synthesis. For tapeout, define PIPE_USE_CLKOR_CELL to swap in the
// process library's clock-OR/clock-mux cell (adjust the cell name/ports to
// match the actual library) -- the external logic is unaffected.
//=============================================================================
module pipe_lane_clk_or #(
    parameter int N = 2
) (
    input  logic [N-1:0] clk_in,
    output logic         clk_out
);

`ifdef PIPE_USE_CLKOR_CELL
  // Swap in the actual process library cell/tree, e.g. a chain of
  // 2-input clock-OR cells: CKOR2Q1 u_clkor (.A(...), .B(...), .Q(...));
  `PIPE_CLKOR_CELL u_clkor (
      .A(clk_in),
      .Q(clk_out)
  );
`else
  assign clk_out = |clk_in;
`endif

endmodule
