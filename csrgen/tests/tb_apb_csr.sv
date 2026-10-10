`timescale 1ns/1ps
module tb_apb_csr;
    logic pclk = 0;
    always #5 pclk = ~pclk;
    logic presetn = 0;
    logic psel = 0, penable = 0, pwrite = 0;
    logic [15:0] paddr = 0;
    logic [31:0] pwdata = 0;
    wire [31:0] prdata;
    wire pready, pslverr;
    wire a, a1;
    logic [1:0] b = 1, b1 = 1;
    wire [27:0] c, c1;
    logic [27:0] c_hwset = 0, c1_hwset = 0;
    logic [27:0] bit_mask;
    logic [31:0] idle_expected;
    apb_csr dut (.*);

    task automatic idle;
        @(negedge pclk);
        psel = 0;
        penable = 0;
        pwrite = 0;
        c_hwset = 0;
        c1_hwset = 0;
    endtask

    task automatic read_reg(input logic [15:0] addr,
                            input logic [31:0] expected,
                            input bit error_expected = 0);
        logic [31:0] previous;
        @(negedge pclk);
        previous = prdata;
        paddr = addr;
        psel = 1;
        pwrite = 0;
        penable = 0;
        #1;
        if (pslverr) $fatal(1, "PSLVERR in setup");
        if (prdata !== previous) $fatal(1, "Read data changed before clock edge");
        @(posedge pclk);
        #1;
        if (prdata !== expected) $fatal(1, "SETUP read capture addr=%h", addr);
        @(negedge pclk);
        penable = 1;
        #1;
        if (!pready || pslverr !== error_expected || prdata !== expected)
            $fatal(1, "Read addr=%h got=%h expected=%h error=%b", addr, prdata, expected, pslverr);
        @(posedge pclk);
        #1;
        if (prdata !== expected) $fatal(1, "Read data changed at ACCESS completion");
    endtask

    task automatic write_reg(input logic [15:0] addr,
                             input logic [31:0] data,
                             input bit error_expected = 0,
                             input logic [27:0] hwset = 0);
        logic [31:0] previous;
        @(negedge pclk);
        previous = prdata;
        paddr = addr;
        pwdata = data;
        psel = 1;
        penable = 0;
        pwrite = 1;
        #1;
        if (pslverr) $fatal(1, "PSLVERR in setup");
        @(negedge pclk);
        penable = 1;
        c_hwset = hwset;
        #1;
        if (!pready || pslverr !== error_expected || prdata !== previous)
            $fatal(1, "Write response addr=%h error=%b", addr, pslverr);
        @(posedge pclk);
        #1;
        if (prdata !== previous) $fatal(1, "Write changed registered read data");
        c_hwset = 0;
    endtask

    initial begin
        #1;
        presetn = 1;
        #1;
        presetn = 0;
        #1;
        if (a !== 1 || a1 !== 1 || c !== 0 || c1 !== 0 || prdata !== 0) $fatal(1, "Reset values");
        @(negedge pclk);
        presetn = 1;
        read_reg(8, 0, 1); // A miss after reset preserves the reset read value.
        read_reg(0, 32'h3);
        // An external RO change during ACCESS must not change the registered
        // SETUP snapshot, even at the ACCESS completion edge.
        @(negedge pclk);
        paddr = 0;
        penable = 0;
        @(posedge pclk);
        #1;
        if (prdata !== 32'h3) $fatal(1, "RO snapshot capture");
        @(negedge pclk);
        penable = 1;
        b = 2;
        #1;
        if (prdata !== 32'h3) $fatal(1, "RO changed read data during ACCESS");
        @(posedge pclk);
        #1;
        if (prdata !== 32'h3) $fatal(1, "RO snapshot not held at completion");
        b = 1;
        read_reg(4, 32'h3);
        // SETUP alone must not write.
        @(negedge pclk);
        paddr = 0;
        pwdata = 0;
        pwrite = 1;
        penable = 0;
        @(posedge pclk);
        #1;
        if (a !== 1) $fatal(1, "Write during setup");
        idle();
        // No select means no write, even with PENABLE high.
        penable = 1;
        pwrite = 1;
        @(posedge pclk);
        #1;
        if (a !== 1) $fatal(1, "Write without select");
        idle();
        write_reg(0, 32'h0);
        read_reg(0, 32'h2);
        read_reg(4, 32'h3);
        b = 2;
        read_reg(0, 32'h4);
        write_reg(0, 32'h7); // RO write ignored; W1C zero bits preserve state.
        read_reg(0, 32'h5);
        idle();
        c_hwset = 28'hA;
        c1_hwset = 28'h5;
        @(posedge pclk);
        #1;
        c_hwset = 0;
        c1_hwset = 0;
        read_reg(0, 32'h55);
        read_reg(4, 32'h2B);
        write_reg(0, 32'h0); // Writing 0 does not clear W1C bits.
        read_reg(0, 32'h54);
        write_reg(0, 32'h10); // Clear only bit 1 of c.
        read_reg(0, 32'h44);
        write_reg(0, 32'h40, 0, 28'h8); // Simultaneous clear and set: set wins.
        read_reg(0, 32'h44);
        write_reg(0, 32'hFFFFFFFF);
        read_reg(0, 32'h5);
        // Reserved bit cannot be written; W1C software cannot set a zero bit.
        write_reg(4, 32'hFFFFFFFF);
        read_reg(4, 32'h3);
        read_reg(8, 32'h3, 1); // A miss holds the previous registered response.
        read_reg(16'hFFFF, 32'h3, 1);
        read_reg(1, 32'h3, 1); // Misalignment must not alias address 0.
        write_reg(8, 32'hFFFFFFFF, 1);
        read_reg(1, 32'h3, 1); // Writes and subsequent read misses hold PRDATA.
        write_reg(1, 32'hFFFFFFFF, 1);
        read_reg(0, 32'h5);
        read_reg(8, 32'h5, 1); // Verify a different previous read value is held.
        read_reg(4, 32'h3);
        // Verify every bit of the multi-bit W1C field independently, including
        // both boundary bits: hardware set, zero-write hold, clear isolation,
        // software clear, and simultaneous hardware-set/software-clear.
        for (int i = 0; i < 28; i++) begin
            bit_mask = 28'h1 << i;
            idle();
            c_hwset = bit_mask;
            @(posedge pclk);
            #1;
            c_hwset = 0;
            if (c !== bit_mask || c1 !== 0) $fatal(1, "Hardware set bit %0d", i);
            write_reg(0, 0);
            if (c !== bit_mask) $fatal(1, "Zero write changed bit %0d", i);
            write_reg(0, {1'b0, (28'h1 << ((i + 1) % 28)), 3'b000});
            if (c !== bit_mask) $fatal(1, "Clear affected another bit %0d", i);
            write_reg(0, {1'b0, bit_mask, 3'b000});
            if (c !== 0) $fatal(1, "Software clear bit %0d", i);
            write_reg(0, {1'b0, bit_mask, 3'b000}, 0, bit_mask);
            if (c !== bit_mask) $fatal(1, "Hardware priority bit %0d", i);
            write_reg(0, {1'b0, bit_mask, 3'b000});
            if (c !== 0 || c1 !== 0) $fatal(1, "Clear/isolation bit %0d", i);
        end
        idle_expected = prdata;
        idle();
        @(posedge pclk);
        #1;
        if (prdata !== idle_expected || pslverr !== 0) $fatal(1, "Idle read data was not held");
        presetn = 0;
        #1;
        if (a !== 1 || a1 !== 1 || c !== 0 || c1 !== 0 || prdata !== 0) $fatal(1, "Second reset");
        $display("PASS: APB3 registered read snapshot, unmapped read hold, reset, setup/access, RW, RO, W1C, hardware priority, reserved, address errors");
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "Timeout");
    end
endmodule
