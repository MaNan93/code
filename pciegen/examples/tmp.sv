module top 
#(parameter W=8) (
     clk,
     rst_n
     ,c
     ,b
);

    input clk；
    input rst_n；
    input c;
input b;

function a();
    input c;
    assign a = c;
endfunction

wire init_done;

DWC_pcie_core #(
    .W(W)
) u_DWC_pcie_core (
    .clk(clk),
    .rst_n(rst_n)
);

endmodule
