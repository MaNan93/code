`timescale 1ns / 1ps

module tb_STARSKY_apb_mux_1m9s;
  reg apb_pclk;
  initial begin
    apb_pclk = 0;
    forever #5 apb_pclk = ~apb_pclk;
  end

  reg apb_presetn = 0;
  reg [18:0] apb_paddr = 0;
  reg apb_psel = 0;
  reg apb_penable = 0;
  reg apb_pwrite = 0;
  reg [31:0] apb_pwdata = 0;
  wire [31:0] apb_prdata;
  wire apb_pready;
  wire [8:0] slave_clk, slave_resetn, slave_sel, slave_enable, slave_write;
  wire [15:0] slave_addr[0:8];
  wire [31:0] slave_wdata[0:8];
  reg [31:0] slave_rdata[0:8];
  reg [8:0] slave_ready = 0;
  integer accepted[0:8];
  integer writes[0:8];
  integer transactions = 0;
  integer checks = 0;
  reg [18:0] first_addr[0:8];
  reg [18:0] last_addr[0:8];

  STARSKY_apb_mux_1m9s dut (
      .apb_pclk(apb_pclk),
      .apb_presetn(apb_presetn),
      .apb_paddr(apb_paddr),
      .apb_psel(apb_psel),
      .apb_penable(apb_penable),
      .apb_pwrite(apb_pwrite),
      .apb_pwdata(apb_pwdata),
      .apb_prdata(apb_prdata),
      .apb_pready(apb_pready),
      .phy0_apb_pclk(slave_clk[0]),
      .phy0_apb_presetn(slave_resetn[0]),
      .phy0_apb_paddr(slave_addr[0]),
      .phy0_apb_psel(slave_sel[0]),
      .phy0_apb_penable(slave_enable[0]),
      .phy0_apb_pwrite(slave_write[0]),
      .phy0_apb_pwdata(slave_wdata[0]),
      .phy0_apb_prdata(slave_rdata[0]),
      .phy0_apb_pready(slave_ready[0]),
      .phy1_apb_pclk(slave_clk[1]),
      .phy1_apb_presetn(slave_resetn[1]),
      .phy1_apb_paddr(slave_addr[1]),
      .phy1_apb_psel(slave_sel[1]),
      .phy1_apb_penable(slave_enable[1]),
      .phy1_apb_pwrite(slave_write[1]),
      .phy1_apb_pwdata(slave_wdata[1]),
      .phy1_apb_prdata(slave_rdata[1]),
      .phy1_apb_pready(slave_ready[1]),
      .phy2_apb_pclk(slave_clk[2]),
      .phy2_apb_presetn(slave_resetn[2]),
      .phy2_apb_paddr(slave_addr[2]),
      .phy2_apb_psel(slave_sel[2]),
      .phy2_apb_penable(slave_enable[2]),
      .phy2_apb_pwrite(slave_write[2]),
      .phy2_apb_pwdata(slave_wdata[2]),
      .phy2_apb_prdata(slave_rdata[2]),
      .phy2_apb_pready(slave_ready[2]),
      .phy3_apb_pclk(slave_clk[3]),
      .phy3_apb_presetn(slave_resetn[3]),
      .phy3_apb_paddr(slave_addr[3]),
      .phy3_apb_psel(slave_sel[3]),
      .phy3_apb_penable(slave_enable[3]),
      .phy3_apb_pwrite(slave_write[3]),
      .phy3_apb_pwdata(slave_wdata[3]),
      .phy3_apb_prdata(slave_rdata[3]),
      .phy3_apb_pready(slave_ready[3]),
      .pcie0_apb_pclk(slave_clk[4]),
      .pcie0_apb_presetn(slave_resetn[4]),
      .pcie0_apb_paddr(slave_addr[4][11:0]),
      .pcie0_apb_psel(slave_sel[4]),
      .pcie0_apb_penable(slave_enable[4]),
      .pcie0_apb_pwrite(slave_write[4]),
      .pcie0_apb_pwdata(slave_wdata[4]),
      .pcie0_apb_prdata(slave_rdata[4]),
      .pcie0_apb_pready(slave_ready[4]),
      .pcie1_apb_pclk(slave_clk[5]),
      .pcie1_apb_presetn(slave_resetn[5]),
      .pcie1_apb_paddr(slave_addr[5][11:0]),
      .pcie1_apb_psel(slave_sel[5]),
      .pcie1_apb_penable(slave_enable[5]),
      .pcie1_apb_pwrite(slave_write[5]),
      .pcie1_apb_pwdata(slave_wdata[5]),
      .pcie1_apb_prdata(slave_rdata[5]),
      .pcie1_apb_pready(slave_ready[5]),
      .pcie2_apb_pclk(slave_clk[6]),
      .pcie2_apb_presetn(slave_resetn[6]),
      .pcie2_apb_paddr(slave_addr[6][11:0]),
      .pcie2_apb_psel(slave_sel[6]),
      .pcie2_apb_penable(slave_enable[6]),
      .pcie2_apb_pwrite(slave_write[6]),
      .pcie2_apb_pwdata(slave_wdata[6]),
      .pcie2_apb_prdata(slave_rdata[6]),
      .pcie2_apb_pready(slave_ready[6]),
      .pcie3_apb_pclk(slave_clk[7]),
      .pcie3_apb_presetn(slave_resetn[7]),
      .pcie3_apb_paddr(slave_addr[7][11:0]),
      .pcie3_apb_psel(slave_sel[7]),
      .pcie3_apb_penable(slave_enable[7]),
      .pcie3_apb_pwrite(slave_write[7]),
      .pcie3_apb_pwdata(slave_wdata[7]),
      .pcie3_apb_prdata(slave_rdata[7]),
      .pcie3_apb_pready(slave_ready[7]),
      .top_apb_pclk(slave_clk[8]),
      .top_apb_presetn(slave_resetn[8]),
      .top_apb_paddr(slave_addr[8][9:0]),
      .top_apb_psel(slave_sel[8]),
      .top_apb_penable(slave_enable[8]),
      .top_apb_pwrite(slave_write[8]),
      .top_apb_pwdata(slave_wdata[8]),
      .top_apb_prdata(slave_rdata[8]),
      .top_apb_pready(slave_ready[8])
  );

  for (genvar g = 4; g < 9; g = g + 1) begin : addr_padding
    if (g < 8) begin : pcie
      assign slave_addr[g][15:12] = 0;
    end else begin : top
      assign slave_addr[g][15:10] = 0;
    end
  end

  // Nine independent slave models. A write changes only the selected slave's
  // response register, and only on an accepted Access clock edge.
  always @(posedge apb_pclk or negedge apb_presetn) begin
    if (!apb_presetn) begin
      for (integer k = 0; k < 9; k = k + 1) begin
        slave_rdata[k] <= 32'('hA5C30010 + k);
        accepted[k] <= 0;
        writes[k] <= 0;
      end
    end else begin
      for (integer k = 0; k < 9; k = k + 1) begin
        if (slave_sel[k] && slave_enable[k] && slave_ready[k]) begin
          accepted[k] <= accepted[k] + 1;
          if (slave_write[k]) begin
            slave_rdata[k] <= slave_wdata[k];
            writes[k] <= writes[k] + 1;
          end
        end
      end
    end
  end

  // Independent oracle: full address ranges, not DUT bit-slice comparisons.
  function automatic integer expected_slave(input reg [18:0] addr);
    if (addr <= 19'h0FFFF) expected_slave = 0;
    else if (addr <= 19'h1FFFF) expected_slave = 1;
    else if (addr <= 19'h2FFFF) expected_slave = 2;
    else if (addr <= 19'h3FFFF) expected_slave = 3;
    else if (addr <= 19'h40FFF) expected_slave = 4;
    else if (addr <= 19'h41FFF) expected_slave = 5;
    else if (addr <= 19'h42FFF) expected_slave = 6;
    else if (addr <= 19'h43FFF) expected_slave = 7;
    else if (addr <= 19'h443FF) expected_slave = 8;
    else expected_slave = -1;
  endfunction

  task automatic check_bus(input integer target);
    reg [8:0] expected_sel;
    reg [31:0] expected_data;
    reg expected_ready;
    reg [15:0] expected_addr;
    begin
      expected_sel   = 0;
      expected_data  = 0;
      expected_ready = 1;
      if (apb_psel && target >= 0) begin
        expected_sel[target] = 1;
        expected_data = slave_rdata[target];
        expected_ready = slave_ready[target];
      end
      if (!$onehot0(slave_sel) || slave_sel !== expected_sel)
        $fatal(1, "PSEL addr=%h got=%b expected=%b", apb_paddr, slave_sel, expected_sel);
      if (slave_enable !== (expected_sel & {9{apb_penable}}))
        $fatal(1, "PENABLE addr=%h got=%b", apb_paddr, slave_enable);
      if (apb_prdata !== expected_data || apb_pready !== expected_ready)
        $fatal(
            1,
            "Response addr=%h setup=%b data=%h/%h ready=%b/%b",
            apb_paddr,
            !apb_penable,
            apb_prdata,
            expected_data,
            apb_pready,
            expected_ready
        );
      for (integer k = 0; k < 9; k = k + 1) begin
        if (k < 4) expected_addr = apb_paddr[15:0];
        else if (k < 8) expected_addr = {4'b0, apb_paddr[11:0]};
        else expected_addr = {6'b0, apb_paddr[9:0]};
        if (slave_addr[k] !== expected_addr ||
            slave_clk[k] !== apb_pclk || slave_resetn[k] !== apb_presetn ||
            slave_write[k] !== apb_pwrite || slave_wdata[k] !== apb_pwdata)
          $fatal(1, "Forwarding slave=%0d addr=%h", k, apb_paddr);
      end
      checks = checks + 1;
    end
  endtask

  // PSEL remains high between calls: every transaction has its own Setup
  // phase, including consecutive accesses to different slaves.
  task automatic transfer(input reg [18:0] addr, input reg write_access, input integer wait_cycles);
    integer target;
    integer before_count[0:8];
    integer before_writes[0:8];
    reg [31:0] write_data;
    begin
      target = expected_slave(addr);
      write_data = 32'('h5A000001) ^ 32'(addr);
      write_data = write_data ^ (32'(addr + 19'h15555) << 16);
      @(negedge apb_pclk);
      apb_paddr = addr;
      apb_psel = 1;
      apb_penable = 0;
      apb_pwrite = write_access;
      apb_pwdata = write_data;
      slave_ready = '1;
      if (target >= 0) slave_ready[target] = (wait_cycles == 0);
      for (integer k = 0; k < 9; k = k + 1) begin
        before_count[k]  = accepted[k];
        before_writes[k] = writes[k];
      end
      #1;
      check_bus(target);
      @(posedge apb_pclk);
      #1;
      for (integer k = 0; k < 9; k = k + 1)
      if (accepted[k] != before_count[k]) $fatal(1, "Accepted during Setup");

      @(negedge apb_pclk);
      apb_penable = 1;
      for (integer w = 0; w < wait_cycles; w = w + 1) begin
        // All unselected slaves change ready while the selected slave waits.
        slave_ready = w[0] ? '0 : '1;
        if (target >= 0) slave_ready[target] = 0;
        #1;
        check_bus(target);
        if (apb_pready !== 1'b0) $fatal(1, "Wait state lost");
        @(posedge apb_pclk);
        #1;
        for (integer k = 0; k < 9; k = k + 1)
        if (accepted[k] != before_count[k]) $fatal(1, "Accepted during wait");
        @(negedge apb_pclk);
      end
      // Opposite ready values also detect an unselected slave blocking progress.
      slave_ready = '0;
      if (target >= 0) slave_ready[target] = 1;
      #1;
      check_bus(target);
      if (apb_pready !== 1'b1) $fatal(1, "Transfer did not complete");
      @(posedge apb_pclk);
      #1;
      for (integer k = 0; k < 9; k = k + 1) begin
        if (accepted[k] != before_count[k] + int'(k == target))
          $fatal(1, "Incorrect acceptance count slave=%0d", k);
        if (writes[k] != before_writes[k] + int'((k == target) && write_access))
          $fatal(1, "Incorrect write count slave=%0d", k);
      end
      if (write_access && target >= 0 && slave_rdata[target] !== write_data)
        $fatal(1, "Write data mismatch");
      check_bus(target);
      transactions = transactions + 1;
    end
  endtask

  task automatic idle_check(input reg [18:0] addr);
    begin
      @(negedge apb_pclk);
      apb_psel = 0;
      apb_penable = 0;
      apb_paddr = addr;
      slave_ready = '0;
      #1;
      check_bus(expected_slave(addr));
      // Even with PENABLE high and PSEL low no slave may be enabled.
      apb_penable = 1;
      #1;
      check_bus(expected_slave(addr));
      @(posedge apb_pclk);
      #1;
      check_bus(expected_slave(addr));
    end
  endtask

  initial begin
    first_addr[0] = 19'h00000;
    last_addr[0]  = 19'h0FFFF;
    first_addr[1] = 19'h10000;
    last_addr[1]  = 19'h1FFFF;
    first_addr[2] = 19'h20000;
    last_addr[2]  = 19'h2FFFF;
    first_addr[3] = 19'h30000;
    last_addr[3]  = 19'h3FFFF;
    first_addr[4] = 19'h40000;
    last_addr[4]  = 19'h40FFF;
    first_addr[5] = 19'h41000;
    last_addr[5]  = 19'h41FFF;
    first_addr[6] = 19'h42000;
    last_addr[6]  = 19'h42FFF;
    first_addr[7] = 19'h43000;
    last_addr[7]  = 19'h43FFF;
    first_addr[8] = 19'h44000;
    last_addr[8]  = 19'h443FF;
    repeat (2) @(negedge apb_pclk);
    #1;
    check_bus(-1);
    apb_presetn = 1;
    #1;
    check_bus(-1);

    // All start/end addresses: read initial distinct data, write with wait
    // states, then read back. End addresses deliberately cover every byte.
    for (integer k = 0; k < 9; k = k + 1) begin
      transfer(first_addr[k], 0, 0);
      transfer(last_addr[k], 0, 1);
      transfer(first_addr[k], 1, 3);
      transfer(first_addr[k], 0, 0);
      transfer(last_addr[k], 1, 1);
      transfer(last_addr[k], 0, 3);
    end

    // Cross every adjacent boundary with PSEL continuously asserted.
    for (integer k = 0; k < 8; k = k + 1) begin
      transfer(last_addr[k], 0, 0);
      transfer(first_addr[k+1], 1, 1);
    end
    transfer(19'h443FF, 0, 0);
    transfer(19'h44400, 0, 0);
    transfer(19'h44400, 1, 0);
    transfer(19'h447FF, 0, 0);
    transfer(19'h44800, 1, 0);
    transfer(19'h4FFFF, 0, 0);
    transfer(19'h50000, 1, 0);
    transfer(19'h7FFFF, 0, 0);
    transfer(19'h7FFFF, 1, 0);
    transfer(19'h00000, 0, 3);
    transfer(19'h44000, 0, 1);
    transfer(19'h20000, 1, 0);
    transfer(19'h42000, 0, 1);
    idle_check(19'h00000);
    idle_check(19'h44000);
    idle_check(19'h7FFFF);

    // Exhaustively verify combinational decode over all 524288 byte addresses.
    // No Access phase occurs in this sweep; timed APB transfers are above.
    @(negedge apb_pclk);
    apb_psel = 1;
    apb_penable = 0;
    for (integer addr = 0; addr < 524288; addr = addr + 1) begin
      apb_paddr   = 19'(addr);
      slave_ready = addr[0] ? 9'b101010101 : 9'b010101010;
      #1;
      check_bus(expected_slave(apb_paddr));
    end
    idle_check(19'h443FF);
    $display("PASS data_bits=32 transactions=%0d addresses=524288 checks=%0d", transactions,
             checks);
    $finish;
  end

  initial begin
    #1000000;
    $fatal(1, "Testbench timeout");
  end
endmodule
