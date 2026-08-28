//=============================================================================
// sync2 -- two-stage synchronizer
//
// Cross-clock-domain sampling. When WIDTH > 1, each bit is synchronized
// independently -- no alignment across bits is guaranteed. Only safe for
// "bits are mutually independent" or "at most one bit changes at a time"
// cases. Do not use this to pass a multi-bit encoded value (e.g. mode).
//=============================================================================
module sync2 #(
    parameter int WIDTH = 1
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] d,      // asynchronous to clk
    output logic [WIDTH-1:0] q       // synchronized into the clk domain
);

    logic [WIDTH-1:0] meta;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            meta <= '0;
            q    <= '0;
        end else begin
            meta <= d;
            q    <= meta;
        end
    end

endmodule
