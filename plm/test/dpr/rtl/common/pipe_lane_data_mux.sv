//=============================================================================
// pipe_lane_data_mux -- one-hot select + polarity normalization
//
// When sel is all-zero (the non-overlap handoff window, or this ctrl lane
// currently has no driving source), the output equals SAFE instead of
// all-zero.
//
// How: make every term feeding the OR-reduction be in "safe state == 0"
// form -- XOR with SAFE going in, XOR with SAFE coming out. That way
// sel == 0 naturally lands on the safe state.
//
// Why not just add an extra term "(SAFE & {W{~|sel}})": that term races the
// main term in the same combinational network -- there's a gate-delay gap
// between sel[i] falling and ~|sel rising, and in between there's a window
// where every term is 0. For a signal like TxElecIdle whose safe state is 1,
// that still produces a glitch spike. Polarity normalization has no
// parallel branch, so this window doesn't exist.
//
// Typical SAFE values (PIPE):
//   TxElecIdle / RxElecIdle  1      -- must be electrical idle during handoff
//   PowerDown                3'b010 -- P1
//   everything else (TxData / RxValid / RxStatus / PhyStatus ...)  0
//
// safe is an input port rather than a parameter. Every call site the
// generator currently emits passes a compile-time constant (SAFE_M2P,
// SAFE_P2M, or 1'b0 for the reset mux), so a parameter would work today --
// it did not always. It used to also carry pipe_lane_data_p2m's
// *_p2m_tie, whose tie_off=lane0 fields follow a base lane's live value
// and so cannot be a parameter. Keeping it a port costs nothing, keeps
// that option open, and avoids churning every instantiation.
//
// The demux direction (one controller lane receiving multiple phy lanes)
// uses the same module -- the only difference is that sel's bits come from
// different groups' NOV. The generator validates that a given ctrl lane's
// driving sources must all come from the same group, to guarantee sel's
// mutual exclusivity.
//=============================================================================
module pipe_lane_data_mux #(
    parameter int WIDTH = 1,
    parameter int N     = 2
) (
    input  logic [    N-1:0]            sel,   // one-hot, may be all-zero
    input  logic [    N-1:0][WIDTH-1:0] din,
    input  logic [WIDTH-1:0]            safe,
    output logic [WIDTH-1:0]            dout
);

  logic [WIDTH-1:0] acc;

  always_comb begin
    acc = '0;
    for (int i = 0; i < N; i++) acc |= (din[i] ^ safe) & {WIDTH{sel[i]}};
  end

  assign dout = acc ^ safe;

endmodule
