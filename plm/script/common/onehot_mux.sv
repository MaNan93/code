//=============================================================================
// onehot_mux -- one-hot 选择 + 极性归一化
//
// sel 全 0 时（break-before-make 的交接窗口，或该端口当前无驱动源）
// 输出等于 SAFE，而不是全 0。
//
// 做法：让参与与或运算的都是「安全态为 0」的形式 ——
// 进门前 ^SAFE，出门后 ^SAFE。这样 sel=0 天然落到安全态。
//
// 为什么不用「额外加一项 (SAFE & {W{~|sel}})」：
// 那一项与主项在同一个组合网络里并行赛跑，sel[i] 落下去和 ~|sel 起来
// 之间有门延迟差，中间会出现所有项都为 0 的窗口，
// 对 TxElecIdle 这类安全态为 1 的信号仍会产生毛刺尖峰。
// 极性归一化没有并行分支，不存在这个窗口。
//
// 典型 SAFE 取值（PIPE）：
//   TxElecIdle / RxElecIdle  1     —— 交接期间必须是电气空闲
//   PowerDown                3'b010 —— P1
//   其余（TxData / RxValid / RxStatus / PhyStatus ...）0
//
// demux 方向（一个 controller 端口收多条 phy lane）用同一个模块，
// 区别只是 sel 各位来自不同 group 的 BBM。生成器会校验
// 同一端口的驱动源必须来自同一个 group，以保证 sel 的互斥性。
//=============================================================================
module onehot_mux #(
    parameter int               WIDTH = 1,
    parameter int               N     = 2,
    parameter logic [WIDTH-1:0] SAFE  = '0
) (
    input  logic [N-1:0]            sel,    // one-hot，可能全 0
    input  logic [N-1:0][WIDTH-1:0] din,
    output logic [WIDTH-1:0]        dout
);

    logic [WIDTH-1:0] acc;

    always_comb begin
        acc = '0;
        for (int i = 0; i < N; i++)
            acc |= (din[i] ^ SAFE) & {WIDTH{sel[i]}};
    end

    assign dout = acc ^ SAFE;

endmodule
