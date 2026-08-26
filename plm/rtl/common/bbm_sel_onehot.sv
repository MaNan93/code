//=============================================================================
// bbm_sel_onehot -- N-way break-before-make one-hot enable.
// Classic glitch-free clock-mux enable structure, extended from 2 to N
// branches. Per branch: 1 register + 1 two-stage synchronizer (3 flops,
// 3N total):
//
//   tgt[i] ---> REG --.
//                       AND ---> [ FF FF ] ---> en[i]
//   other_idle[i] -----'          sync2
//
//   other_idle[i] = NOR(en[j], j != i)   -- raw wire, no separate
//                                           synchronizer of its own.
//
// Caller must guarantee: tgt is legal one-hot with an all-zero gap on every
// switch, covering the slowest branch's sync delay. N-way form is a derived
// extension of the verified 2-clock circuit, not itself published -- run
// CDC formal (e.g. SpyGlass CDC) before tapeout.
//=============================================================================
module bbm_sel_onehot #(
    parameter int N = 2
) (
    input  logic [N-1:0] branch_clk,
    input  logic [N-1:0] branch_rst_n,
    input  logic [N-1:0] tgt,
    output logic [N-1:0] en
);

    for (genvar i = 0; i < N; i++) begin : g_branch

        logic [N-1:0] self_mask;
        logic         other_idle;
        logic         tgt_r;   // register: tgt[i] into branch_clk[i]
        logic         d_in;

        assign self_mask  = ~(N'(1) << i);
        assign other_idle = ~|(en & self_mask);
        assign d_in       = tgt_r & other_idle;

        always_ff @(posedge branch_clk[i] or negedge branch_rst_n[i])
            if (!branch_rst_n[i]) tgt_r <= 1'b0;
            else                  tgt_r <= tgt[i];

        // two-stage synchronizer: d_in -> en[i]
        sync2 #(.WIDTH(1)) u_sync_en (
            .clk   (branch_clk  [i]),
            .rst_n (branch_rst_n[i]),
            .d     (d_in),
            .q     (en[i])
        );

    end

endmodule