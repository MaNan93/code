//=============================================================================
// pipe_lane_data_mux -- one-hot select + polarity normalization
//
// When sel is all-zero (the non-overlap handoff window, or this port
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
// safe is a runtime input port, not a parameter: most call sites pass a
// compile-time constant, but for a tie_off=lane0 signal like
// phy_mac_phystatus, its "safe state" has to follow base_lane's current
// actual value (see *_safe_p2m_align in pipe_lane_data_p2m.sv) -- that's
// only known at runtime, and doesn't satisfy the compile-time-constant
// requirement of a parameter. To keep both call patterns legal on the same
// module, safe is uniformly made a port.
//
// The demux direction (one controller port receiving multiple phy lanes)
// uses the same module -- the only difference is that sel's bits come from
// different groups' NOV. The generator validates that a given port's
// driving sources must all come from the same group, to guarantee sel's
// mutual exclusivity.
//=============================================================================
module pipe_lane_data_mux #(
    parameter int WIDTH = 1,
    parameter int N     = 2
) (
    input  logic [N-1:0]            sel,    // one-hot, may be all-zero
    input  logic [N-1:0][WIDTH-1:0] din,
    input  logic [WIDTH-1:0]        safe,
    output logic [WIDTH-1:0]        dout
);

    logic [WIDTH-1:0] acc;

    always_comb begin
        acc = '0;
        for (int i = 0; i < N; i++)
            acc |= (din[i] ^ safe) & {WIDTH{sel[i]}};
    end

    assign dout = acc ^ safe;

endmodule
