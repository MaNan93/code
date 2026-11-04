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

// --------------------------------------------------------------------------------------
// ---  RCS information:
// ---    $DateTime: 2024/01/12 13:55:57 $
// ---    $Revision: #1 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/DWC_pcie_axi_clkrst.sv#1 $
// --------------------------------------------------------------------------------------
// --- Module description: AMBA AXI/LTI clock gating
// --- The enable signal is asserted if any of the following blocks is active
// --- 1. AXI Manager
// --- 2. AXI Subordinate

`include "include/DWC_pcie_ctl_all_defs.svh"

module DWC_pcie_axi_clkrst
  (
    input  logic        test_clk_en,    // Select test clock as clock for the controller
    input  logic        test_rst_en,    // Select test reset as reset for the controller
    input  logic        core_rst_n,     // Resets the controller, except for the PMC module
    input  logic        mstr_aclk,      // Clock Ungated version for AXI Manager Interface
    input  logic        en_mstr_aclk_g, // Enable for mstr_aclk_gated
    output logic        mstr_aclk_g,    // Clock Gated version for AXI Manager Interface
    output logic        mstr_aresetn,   // AXI reset for AXI Manager Interface
    input  logic        slv_aclk,       // Clock Ungated version AXI Subordinate Interface
    input  logic        en_slv_aclk_g,  // Enable for slv_aclk_gated
    output logic        slv_aclk_g,     // Clock Gated version for AXI Subordinate Interface
    output logic        slv_aresetn     // AXI Reset for AXI Subordinate Interface
  );

  localparam DATA_DELAY_BCM36_NHS = 3;  // Type of random delay to be added to signal in simulation by bcm36_nhs
  
  // Output of bcm36_nhs
  logic qst_mstr_test_clk_en;
  logic qst_slv_test_clk_en;
  
  // Generate AXI Manager Reset
  DWC_pcie_ctl_sync_reset
   #(
    .SYNC_DEPTH (`CX_PCIE_SYNC_DEPTH)
  ) u_sync_reset_mstr_aresetn (
    .clk        (mstr_aclk          ),
    .rst_n      (core_rst_n         ),
    .test_mode  (test_rst_en        ),
    .sync_rst_n (mstr_aresetn       )
  );

  // For Synthesis, consider test_clk_en as false path in AXI Manager Domain
  DWC_pcie_ctl_bcm36_nhs
   #(
    .WIDTH      (1'b1                ),
    .DATA_DELAY (DATA_DELAY_BCM36_NHS)
  ) u_bcm36_nhs_mstr_test_clk_en(
  `ifndef SYNTHESIS
    .clk_d   (mstr_aclk              ),
    .rst_d_n (mstr_aresetn           ),
`endif // SYNTHESIS
    .data_s     (test_clk_en         ),
    .data_d     (qst_mstr_test_clk_en)
  );

  // Generate AXI Manager Clock Gated version
  DWC_pcie_ctl_bcm00_ck_gt_lat
   u_clk_gate_mstr_aclk(
    .clk_in  (mstr_aclk           ),
    .en      (en_mstr_aclk_g      ),
    .test    (qst_mstr_test_clk_en),
    .clk_out (mstr_aclk_g         )
  );
  
  // Generate AXI Subordinate Reset
  DWC_pcie_ctl_sync_reset
   #(
    .SYNC_DEPTH (`CX_PCIE_SYNC_DEPTH)
  ) u_sync_reset_slv_aresetn (
    .clk        (slv_aclk           ),
    .rst_n      (core_rst_n         ),
    .test_mode  (test_rst_en        ),
    .sync_rst_n (slv_aresetn        )
  );
  
  // For Synthesis, consider test_clk_en as false path in AXI Subordinate Domain
  DWC_pcie_ctl_bcm36_nhs
   #(
    .WIDTH      (1'b1                ),
    .DATA_DELAY (DATA_DELAY_BCM36_NHS)
  ) u_bcm36_nhs_slv_test_clk_en(
  `ifndef SYNTHESIS
    .clk_d   (slv_aclk               ),
    .rst_d_n (slv_aresetn            ),
`endif // SYNTHESIS
    .data_s     (test_clk_en         ),
    .data_d     (qst_slv_test_clk_en )
  );

  // Generate AXI Subordinate Clock Gated version
  DWC_pcie_ctl_bcm00_ck_gt_lat
   u_clk_gate_slv_aclk(
    .clk_in  (slv_aclk           ),
    .en      (en_slv_aclk_g      ),
    .test    (qst_slv_test_clk_en),
    .clk_out (slv_aclk_g         )
  );



endmodule 
