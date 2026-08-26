//=============================================================================
// sync2 -- 两级同步器
//
// 跨时钟域采样。WIDTH > 1 时各 bit 独立同步，不保证多 bit 之间对齐，
// 因此只能用于「各 bit 相互独立」或「同一时刻最多一位变化」的场合。
// 不可用来传多 bit 编码值（例如 mode）。
//=============================================================================
module sync2 #(
    parameter int WIDTH = 1
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] d,      // 异步于 clk
    output logic [WIDTH-1:0] q       // 已同步到 clk 域
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
