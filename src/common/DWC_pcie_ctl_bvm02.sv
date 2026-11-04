
// ------------------------------------------------------------------------------
// 
// Copyright 2002 - 2024 Synopsys, INC.
// 
// This Synopsys IP and all associated documentation are proprietary to
// Synopsys, Inc. and may only be used pursuant to the terms and conditions of a
// written license agreement with Synopsys, Inc. All other use, reproduction,
// modification, or distribution of the Synopsys IP or the associated
// documentation is strictly prohibited.
// Inclusivity & Diversity - Visit SolvNetPlus to read the "Synopsys Statement on
//            Inclusivity and Diversity" (Refer to article 000036315 at
//                        https://solvnetplus.synopsys.com)
// 
// Component Name   : DWC_pcie_ctl_cxl
// Component Version: 6.14a-lca02
// Release Type     : LCA
// Build ID         : 69.19.33.11.PCIeParseConfig_1.PCIeSimulate_24.PCIeTbCommon_85.SNPSPHYSetup_21
// ------------------------------------------------------------------------------

//
// Description : DWC_pcie_ctl_bvm02.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: 3e5477f2
//
////////////////////////////////////////////////////////////////////////////////


`ifndef SYNTHESIS
  `ifdef DWC_ENABLE_CELLDEFINE
    //type: DWC_pcie_ctl_bvm02
    `celldefine
  `endif
module DWC_pcie_ctl_bvm02
(
  input      clk,
  input      rst_n,
  output reg clk_stopped,
  output     [63:0] clk_period
);

  real          clk_period_int;
  real          time_start;
  reg   [2:0]   cnt;
  reg   [2:0]   cnt_previous;
  reg           clk_stable;
  reg           clk_stopped_nxt;
`ifdef DWC_BVM02_QUICK_CALC_CLK_PERIOD
  reg           clk_stable_reg;
`endif

  assign clk_period = $realtobits(clk_period_int);

`ifdef VCS
`ifdef UPF_POWER_AWARE
  (* vcs_reinit *)
`endif
`endif
  initial begin : signal_initialization_PROC
    cnt             = 3'b000;
    cnt_previous    = 3'b000;
    clk_period_int  = 0.0;
    time_start      = 0.0;
    clk_stopped_nxt = 1'b1;
    clk_stopped     = 1'b1;
    clk_stable      = 1'b0;
`ifdef DWC_BVM02_QUICK_CALC_CLK_PERIOD
    clk_stable_reg  = 1'b0;
`endif
  end

  ///////////////////////
  // get period of clk //
  ///////////////////////

`ifdef DWC_BVM02_QUICK_CALC_CLK_PERIOD
  always @(posedge clk) begin : clk_stable_reg_PROC
    clk_stable_reg <= clk_stable;
  end

  always @(posedge clk) begin : clk_period_sched_counter_PROC
    if (clk_stable & (!clk_stable_reg)) begin
      clk_period_int <= $realtime - time_start;
    end
    if (!clk_stable_reg) begin
      time_start <= $realtime;
    end
  end
`else
  always @(posedge clk) begin : clk_period_sched_counter_PROC
    if (clk_stable) begin
      clk_period_int <= $realtime - time_start;
    end
    time_start <= $realtime;
  end
`endif

  ////////////////////////////
  // detect stoppage of clk //
  ////////////////////////////

  always @(clk_stopped_nxt) begin : clk_stopped_PROC
    if ($time > 0) begin
      if($sampled(clk_stopped_nxt)) begin
        @(posedge clk);
        clk_stopped = clk_stopped_nxt;
      end else begin
        clk_stopped = clk_stopped_nxt;
      end
    end
  end

  always @(*) begin : clk_stopped_nxt_PROC

    fork

    begin
      @(negedge clk_stable);
    end


    begin
      wait (clk_stable==1);
      clk_stopped_nxt = 1'b0;

`ifdef DWC_BVM02_SHORT_CLK_BURSTS
      @(posedge clk);
      @(negedge clk);
`else
      repeat(2)
        @(posedge clk);
`endif

      while (!clk_stopped_nxt) begin
        cnt_previous = cnt;

        #(clk_period_int*1.5);
        if (cnt==cnt_previous) begin
          clk_stopped_nxt = 1'b1;
          #(clk_period_int/2);
        end
      end
    end

    join_any
    disable fork;

  end

  always @(posedge clk or posedge clk_stopped_nxt or negedge rst_n) begin : posedg_count_PROC
    if (!rst_n || (clk_stopped_nxt && clk_stable)) begin
      cnt <= 3'b0;
      clk_stable <= 1'b0;
      clk_stopped_nxt <= 1'b1;
    end
    else if ($time > 0) begin
      if (cnt == 3'd1) begin
        clk_stable <= 1'b1;
      end
      cnt <= cnt+3'd1;
    end
  end

endmodule
  `ifdef DWC_ENABLE_CELLDEFINE
    `endcelldefine
  `endif
`endif // SYNTHESIS
