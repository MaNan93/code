`timescale 1ns/1ps
module tb_rwsc_csr;
    logic pclk = 0;
    always #5 pclk = ~pclk;
    logic presetn = 0;
    logic psel = 0, penable = 0, pwrite = 0;
    logic [15:0] paddr = 0;
    logic [31:0] pwdata = 0;
    wire [31:0] prdata;
    wire pready, pslverr;
    wire pulse;
    wire [3:0] command;
    wire [7:0] control;
    wire [1:0] boot;
    wire [31:0] wordpulse;
    rwsc_apb_csr dut (.*);

    task automatic assert_cleared;
        if (pulse !== 0 || command !== 0 || boot !== 0 || wordpulse !== 0)
            $fatal(1, "RWSC did not self-clear, pulse=%b command=%h boot=%h word=%h", pulse, command, boot, wordpulse);
    endtask

    task automatic next_idle;
        @(negedge pclk);
        psel = 0;
        penable = 0;
        pwrite = 0;
        @(posedge pclk);
        #1;
        assert_cleared();
    endtask

    task automatic write_word(input logic [15:0] addr, input logic [31:0] value,
                              input bit expected_error = 0);
        @(negedge pclk);
        psel = 1;
        penable = 0;
        pwrite = 1;
        paddr = addr;
        pwdata = value;
        @(posedge pclk);
        #1;
        assert_cleared(); // SETUP does not set; it clears any previous pulse.
        @(negedge pclk);
        penable = 1;
        #1;
        if (!pready || pslverr !== expected_error) $fatal(1, "Write response");
        @(posedge pclk);
        #1;
    endtask

    task automatic read_word(input logic [15:0] addr, input logic [31:0] expected);
        @(negedge pclk);
        psel = 1;
        penable = 0;
        pwrite = 0;
        paddr = addr;
        @(posedge pclk);
        #1;
        assert_cleared();
        @(negedge pclk);
        penable = 1;
        #1;
        if (!pready || pslverr || prdata !== expected) $fatal(1, "Read got=%h expected=%h", prdata, expected);
        @(posedge pclk);
        #1;
        if (prdata !== expected) $fatal(1, "Registered snapshot changed");
    endtask

    initial begin
        #1;
        presetn = 1;
        #1;
        presetn = 0;
        #1;
        if (boot !== 1 || pulse !== 0 || command !== 0 || wordpulse !== 0 || control !== 8'h5A)
            $fatal(1, "Reset values");
        @(negedge pclk);
        presetn = 1;
        next_idle();

        write_word(0, 1);
        if (pulse !== 1) $fatal(1, "Single-bit write one");
        read_word(0, 1); // Capture pre-clear pulse; output itself clears this edge.
        read_word(0, 0);
        write_word(0, 0);
        assert_cleared();
        write_word(4, 32'hA0);
        if (command !== 4'hA || pulse !== 0 || control !== 8'h5A) $fatal(1, "Multi-bit pattern A");
        next_idle();
        write_word(4, 32'h50);
        if (command !== 4'h5) $fatal(1, "Multi-bit pattern 5");
        // Back-to-back legal APB writes: one zero cycle between the two pulses.
        write_word(4, 32'hF0);
        if (command !== 4'hF) $fatal(1, "Consecutive write");
        write_word(8, 32'h3C);
        if (control !== 8'h3C) $fatal(1, "RW control");
        assert_cleared();
        write_word(16, 32'h80000001);
        if (wordpulse !== 32'h80000001) $fatal(1, "32-bit boundary pulse");
        next_idle();
        write_word(16, 32'hFFFFFFFF);
        if (wordpulse !== 32'hFFFFFFFF) $fatal(1, "32-bit all-one pulse");
        next_idle();
        write_word(2, 32'hFFFFFFFF, 1);
        assert_cleared();
        write_word(20, 32'hFFFFFFFF, 1);
        assert_cleared();
        read_word(8, 32'h3C);
        presetn = 0;
        #1;
        if (boot !== 1 || pulse !== 0 || command !== 0 || wordpulse !== 0 || control !== 8'h5A)
            $fatal(1, "Second reset");
        $display("PASS: RWSC single/multi/full-width pulses, automatic clear, write zero, SETUP, consecutive writes, read snapshot, reset, address errors");
        $finish;
    end
    initial begin
        #2000;
        $fatal(1, "Timeout");
    end
endmodule
