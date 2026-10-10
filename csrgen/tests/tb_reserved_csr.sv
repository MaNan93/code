`timescale 1ns/1ps
module tb_reserved_csr;
    logic pclk = 0;
    always #5 pclk = ~pclk;
    logic presetn = 0;
    logic psel = 0, penable = 0, pwrite = 0;
    logic [15:0] paddr = 0;
    logic [31:0] pwdata = 0;
    wire [31:0] prdata;
    wire pready, pslverr;
    wire [7:0] data;
    sparse_apb_csr dut (.*);

    task automatic read_word(input logic [31:0] expected);
        @(negedge pclk);
        psel = 1;
        penable = 0;
        pwrite = 0;
        @(negedge pclk);
        penable = 1;
        #1;
        if (!pready || pslverr || prdata !== expected || (prdata & 32'hFFFF00FF) !== 0)
            $fatal(1, "Reserved read got=%h expected=%h", prdata, expected);
        @(posedge pclk);
        #1;
    endtask

    task automatic write_word(input logic [31:0] value);
        @(negedge pclk);
        psel = 1;
        penable = 0;
        pwrite = 1;
        pwdata = value;
        @(negedge pclk);
        penable = 1;
        #1;
        if (!pready || pslverr) $fatal(1, "Reserved write response");
        @(posedge pclk);
        #1;
    endtask

    initial begin
        #1;
        presetn = 1;
        #1;
        presetn = 0;
        #1;
        if (data !== 8'h12 || prdata !== 0) $fatal(1, "Reset");
        @(negedge pclk);
        presetn = 1;
        read_word(32'h00001200);
        write_word(32'hFFFFFFFF);
        read_word(32'h0000FF00);
        write_word(32'h80405AF0);
        read_word(32'h00005A00);
        write_word(32'hFFFF00FF);
        read_word(0);
        $display("PASS: explicit reserved overrides wrong metadata; missing upper/lower/gap bits are RO/tie0");
        $finish;
    end
    initial begin
        #1000;
        $fatal(1, "Timeout");
    end
endmodule
