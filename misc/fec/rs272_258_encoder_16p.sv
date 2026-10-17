module rs272_258_encoder_16p #(
    parameter int SYM_W = 10,
    parameter int PARITY_SYMS = 14,
    parameter int MSG_SYMS = 258,
    parameter int PARALLEL = 16,
    // g(x) = x^14 + sum(G[i] * x^i), i=0..13
    parameter logic [SYM_W-1:0] G [0:PARITY_SYMS-1] = '{
        10'h1B0, 10'h122, 10'h3B1, 10'h109,
        10'h250, 10'h187, 10'h266, 10'h384,
        10'h39D, 10'h290, 10'h020, 10'h2BD,
        10'h006, 10'h388
    }
) (
    input  logic                           clk,
    input  logic                           rst_n,

    // Assert with the first beat of one RS message block.
    input  logic                           block_start,
    // Assert with the last beat of one RS message block.
    input  logic                           block_end,

    input  logic                           in_valid,
    input  logic [PARALLEL-1:0]            in_keep,
    input  logic [PARALLEL*SYM_W-1:0]      in_symbols,

    output logic                           ready,
    output logic                           parity_valid,
    output logic [PARITY_SYMS*SYM_W-1:0]   parity_symbols,
    // Pulses when a block is closed with symbol count != MSG_SYMS.
    output logic                           block_len_error
);

    logic [PARITY_SYMS*SYM_W-1:0] parity_reg;
    logic [$clog2(MSG_SYMS+PARALLEL+1)-1:0] sym_count_reg;

    function automatic logic [SYM_W-1:0] get_symbol(
        input logic [PARALLEL*SYM_W-1:0] symbols,
        input int unsigned idx
    );
        get_symbol = symbols[idx*SYM_W +: SYM_W];
    endfunction

    function automatic logic [SYM_W-1:0] gf_mul(
        input logic [SYM_W-1:0] a,
        input logic [SYM_W-1:0] b
    );
        logic [2*SYM_W-2:0] prod;
        // Primitive polynomial for GF(2^10): x^10 + x^3 + 1.
        logic [SYM_W:0] prim;
        int i;

        prod = '0;
        prim = 11'h409;

        for (i = 0; i < SYM_W; i++) begin
            if (b[i]) begin
                prod = prod ^ (a << i);
            end
        end

        for (i = 2*SYM_W-2; i >= SYM_W; i--) begin
            if (prod[i]) begin
                prod = prod ^ (prim << (i-SYM_W));
            end
        end

        gf_mul = prod[SYM_W-1:0];
    endfunction

    function automatic logic [PARITY_SYMS*SYM_W-1:0] lfsr_step(
        input logic [PARITY_SYMS*SYM_W-1:0] state_in,
        input logic [SYM_W-1:0] data_sym
    );
        logic [SYM_W-1:0] s [0:PARITY_SYMS-1];
        logic [SYM_W-1:0] n [0:PARITY_SYMS-1];
        logic [SYM_W-1:0] fb;
        logic [PARITY_SYMS*SYM_W-1:0] packed;
        int i;

        for (i = 0; i < PARITY_SYMS; i++) begin
            s[i] = state_in[i*SYM_W +: SYM_W];
        end

        fb = data_sym ^ s[PARITY_SYMS-1];

        n[0] = gf_mul(fb, G[0]);
        for (i = 1; i < PARITY_SYMS; i++) begin
            n[i] = s[i-1] ^ gf_mul(fb, G[i]);
        end

        packed = '0;
        for (i = 0; i < PARITY_SYMS; i++) begin
            packed[i*SYM_W +: SYM_W] = n[i];
        end

        lfsr_step = packed;
    endfunction

    function automatic int unsigned popcount(
        input logic [PARALLEL-1:0] v
    );
        int unsigned c;
        int i;

        c = 0;
        for (i = 0; i < PARALLEL; i++) begin
            if (v[i]) c++;
        end
        popcount = c;
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        logic [PARITY_SYMS*SYM_W-1:0] work_state;
        int unsigned lane;
        int unsigned consumed;
        logic [SYM_W-1:0] d;

        if (!rst_n) begin
            parity_reg       <= '0;
            sym_count_reg    <= '0;
            parity_symbols   <= '0;
            parity_valid     <= 1'b0;
            block_len_error  <= 1'b0;
        end else begin
            parity_valid    <= 1'b0;
            block_len_error <= 1'b0;

            work_state = block_start ? '0 : parity_reg;

            if (block_start) begin
                sym_count_reg <= '0;
            end

            consumed = 0;
            if (in_valid) begin
                for (lane = 0; lane < PARALLEL; lane++) begin
                    if (in_keep[lane]) begin
                        d = get_symbol(in_symbols, lane);
                        work_state = lfsr_step(work_state, d);
                        consumed++;
                    end
                end

                parity_reg <= work_state;
                sym_count_reg <= (block_start ? '0 : sym_count_reg) + consumed;
            end

            if (block_end) begin
                parity_symbols <= in_valid ? work_state : parity_reg;
                parity_valid   <= 1'b1;

                if (((in_valid ? (block_start ? 0 : sym_count_reg) + consumed
                               : (block_start ? 0 : sym_count_reg)) != MSG_SYMS)) begin
                    block_len_error <= 1'b1;
                end
            end
        end
    end

    assign ready = 1'b1;

endmodule
