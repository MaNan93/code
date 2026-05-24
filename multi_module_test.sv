module top_module (
    input clk,
    input rst_n,
    output [7:0] data_out
);

    // 实例化其他模块
    sub_module u_sub (
        .clk(clk),
        .data_i(data_out)
    );

endmodule

module sub_module (
    input clk,
    input [7:0] data_i,
    output reg [7:0] data_o
);

    always @(posedge clk) begin
        data_o <= data_i;
    end

endmodule