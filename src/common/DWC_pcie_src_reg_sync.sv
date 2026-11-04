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

//-------------------------------------------------------------------------
//---  RCS information:
//---    $DateTime: 2024/01/12 11:11:14 $
//---    $Revision: #6 $
//---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DWC_pcie_src_reg_sync.sv#6 $
//-------------------------------------------------------------------------

// -------------------------------------------------------------------------
// ---  RCS information:
// ---    $DateTime: 2024/01/12 11:11:14 $
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DWC_pcie_src_reg_sync.sv#6 $
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_src_reg_sync (
    clk_s,
    rst_s_n,
    clk_d,
    rst_d_n,
    data_s,
    data_d
    );

parameter WIDTH        = 1;  // RANGE 1 to 1024
parameter F_SYNC_TYPE  = 2;  // RANGE 0 to 4
parameter VERIF_EN     = 1;  // RANGE 0 to 5
parameter SVA_TYPE     = 1;

parameter TP           = `TP;

input                   clk_s;      // clock input from source domain
input                   rst_s_n;    // active low asynchronous reset from source domain
input                   clk_d;      // clock input from destination domain
input                   rst_d_n;    // active low asynchronous reset from destination domain
input  [WIDTH-1:0]      data_s;     // data to be synchronized from source domain
output [WIDTH-1:0]      data_d;     // data synchronized to destination domain


wire   [WIDTH-1:0]      data_i;
reg    [WIDTH-1:0]      data_d;

reg    [WIDTH-1:0]      r_data_s_SNPS_MARCH_3;

  // -------------------------------------------------------------------------------------
  // Register input signals on original clock to avoid feedback logic on the synchronizer
  // inputs
  // This is a mandatory requirement in Synopsys CDC Checklist (SNPS_MARCH_3)
  // -------------------------------------------------------------------------------------

  always @(posedge clk_s or negedge rst_s_n) begin : proc_seq_r_data_s_SNPS_MARCH_3
    if (!rst_s_n) begin
      r_data_s_SNPS_MARCH_3 <= # TP 0;
    end else begin
      r_data_s_SNPS_MARCH_3 <= # TP data_s;
    end
  end

  // -------------------------------------------------------------------------------------
  // Instantiate synchronizer
  // -------------------------------------------------------------------------------------

  DWC_pcie_ctl_bcm21
  
  #(
   .WIDTH                            (WIDTH),
   .F_SYNC_TYPE                      (F_SYNC_TYPE),
   .VERIF_EN                         (VERIF_EN),
   .SVA_TYPE                         (SVA_TYPE)
  )
  u_DWC_pcie_ctl_bcm21
  (
  .clk_d                             (clk_d),
  .rst_d_n                           (rst_d_n),
  .data_s                            (r_data_s_SNPS_MARCH_3),
  .data_d                            (data_i)
  );

// SMD: Non-blocking assignment used in combinational always block.
// SJ:  The correct way to model a transport delay is to use a non-blocking assignment
// spyglass disable_block STARC05-2.2.3.1
always@(data_i)
  data_d <= #TP data_i;
// spyglass enable_block STARC05-2.2.3.1

endmodule

