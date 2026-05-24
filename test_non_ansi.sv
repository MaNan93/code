module test_module (
    input clk,
    input rst_n
);

    output [7:0] data_out;

    // 实例化其他模块
    sub_module u_sub (
        .clk(clk),
        .data_i(data_out)
    );

endmodule