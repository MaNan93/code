//=============================================================================
// clk_gate -- 时钟门控 wrapper
//
// 门控时钟时，使能必须在时钟低电平期间翻转，否则输出会产生窄脉冲（runt）。
// 保证这一点需要一个低电平透明的锁存器（负沿触发器等价，但本项目不允许
// 使用负沿寄存器）。
//
// 默认实现用推断 latch，供仿真与早期综合使用。
// 投片时定义 PIPE_USE_ICG_CELL，把内部替换成工艺库的 ICG 单元
// （单元名与端口按实际库调整），外部逻辑不受影响。
//
// en 必须已经在 clk_in 域内寄存过（由 bbm_sel_onehot 保证）。
//=============================================================================
module clk_gate (
    input  logic clk_in,
    input  logic en,        // 与 clk_in 同域，已寄存
    input  logic test_en,   // DFT：scan shift 期间强制打开
    output logic clk_out
);

`ifdef PIPE_USE_ICG_CELL
    // 替换成实际工艺库单元，例如：
    // CKLNQD1 u_icg (.CP(clk_in), .E(en), .TE(test_en), .Q(clk_out));
    `PIPE_ICG_CELL u_icg (.CP(clk_in), .E(en), .TE(test_en), .Q(clk_out));
`else
    logic en_latched;

    always_latch begin
        if (!clk_in) en_latched = en | test_en;   // clk 低电平时透明（锁存器用阻塞赋值）
    end

    assign clk_out = clk_in & en_latched;
`endif

endmodule
