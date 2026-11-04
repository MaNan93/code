
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
// Description : DWC_pcie_ctl_bcm00_atpg_mx.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: 3bc5eba0
//
////////////////////////////////////////////////////////////////////////////////


module DWC_pcie_ctl_bcm00_atpg_mx(
        clk,
        scan_rst_n,
        rst_n,
        test,
        test_rst_n,
        mx_rst_n
        );

// spyglass disable_block W146
// SMD: Explicit named association is recommended in instance references
// SJ: Current release uses ordered list for parameters, the design is checked and verified without errors

  parameter     integer CLK_MUX_EN = 0;  // Select the type of Multiplexer
  parameter     integer ATPG_FF_EN = 0;  // Insert the Flip Flop at the input "rst_n" point for the ATPG coverage

// spyglass disable_block W240
// SMD: An input port is never read in the module
// SJ: The following port(s) are not used in certain configurations.
  input  clk;           // Clock used for the ATPG coverage flop
  input  scan_rst_n;    // Reset used for the ATPG coverage flop (active low)
// spyglass enable_block W240
  input  rst_n;         // Input reset (active low)
  input  test;          // Test mode enable
  input  test_rst_n;    // Reset to be used during test mode (active low)

  output mx_rst_n;      // Reset output after multiplexer (active low)


  generate
    if(CLK_MUX_EN==0) begin : GEN_CME_EQ0
      DWC_pcie_ctl_bcm00_mx
       U_MUX (
        .a0(rst_n),
        .a1(test_rst_n),
        .s(test),
        .z(mx_rst_n)
      );
    end else begin : GEN_CME_EQ1
      DWC_pcie_ctl_bcm00_ck_mx
       U_MUX (
        .clk0(rst_n),
        .clk1(test_rst_n),
        .s(test),
        .clk_out(mx_rst_n)
      );
    end
  endgenerate

  generate
    if(ATPG_FF_EN==1) begin : GEN_AFE_EQ1
      wire atpg_cov;
      DWC_pcie_ctl_bcm00_dff_clrn
       U_ATPG_COV (
        .clk(clk),
        .rst_n(scan_rst_n),
        .d(rst_n),
// spyglass disable_block UnloadedOutTerm-ML
// SMD: Detected unloaded(unconnected) output terminal
// SJ: The following signal(s) are emanating from instance output port(s) that are intentionally not used. So, disable SpyGlass from reporting this warning. This instance design in which the signal(s) are connected is shared by other module(s) that may use these port(s) and signal(s) emanating from them.
        .q(atpg_cov)
// spyglass enable_block UnloadedOutTerm-ML
      );

    end
  endgenerate


// spyglass enable_block W146
endmodule
