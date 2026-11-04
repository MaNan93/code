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

// -------------------------------------------------------------------------
// ---  RCS information:
// ---    $DateTime: 2024/01/12 11:11:14 $
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/slave/DWC_pcie_axi_flush_ctl.sv#9 $
// -------------------------------------------------------------------------
// --- Module description: AXI Slave Flush Control
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_axi_flush_ctl
 #(
   parameter SYNC_DEPTH                             = 2,

   parameter TP                                     = `TP
 )
 (
  // -------------------------------------------------------------------------------------
  // Clocks and resets
  // -------------------------------------------------------------------------------------
  input                                              core_clk,    
  input                                              core_rst_n,
  input                                              slv_aclk_ug,    
  input                                              slv_aresetn,
  // -------------------------------------------------------------------------------------
  // Flush Request/Acknowledge interface
  // -------------------------------------------------------------------------------------
  input                                              rstctl_mstr_flush_req,
  input                                              rstctl_slv_flush_req,
  output reg                                         flshctl_slv_flush_ack,
  output wire                                        flshctl_sif_flush_req,
  // -------------------------------------------------------------------------------------
  // Slave Transfer Pending Info interface
  // -------------------------------------------------------------------------------------
  input                                              sif_flush_ack 
 );

  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  // -------------------------------------------------------------------------------------
  // Regs/Wires
  // -------------------------------------------------------------------------------------
  wire                                     s_s2c0_sif_flush_ack;      
  // -------------------------------------------------------------------------------------
  // Design
  // -------------------------------------------------------------------------------------

  // -------------------------------------------------------------------------------------
  // Sync the flush request to the AXI Slave clock domain
  DWC_pcie_src_reg_sync
   
  #(
   .WIDTH                            (1),
   .F_SYNC_TYPE                      (SYNC_DEPTH),
   .VERIF_EN                         (1)
  ) 
  u_c2a0
  (
  .clk_s                             (core_clk),
  .rst_s_n                           (core_rst_n),
  .clk_d                             (slv_aclk_ug), 
  .rst_d_n                           (slv_aresetn), 
  .data_s                            (rstctl_slv_flush_req),
  .data_d                            (flshctl_sif_flush_req)
  );

  // -------------------------------------------------------------------------------------
  // Synchronise AXI Slave Flush Ack
  DWC_pcie_src_reg_sync
   
  #(
   .WIDTH                            (1),
   .F_SYNC_TYPE                      (SYNC_DEPTH),
   .VERIF_EN                         (1)
  ) 
  u_s2c0
  (
  .clk_s                             (slv_aclk_ug),
  .rst_s_n                           (slv_aresetn),
  .clk_d                             (core_clk), 
  .rst_d_n                           (core_rst_n), 
  .data_s                            (sif_flush_ack),
  .data_d                            (s_s2c0_sif_flush_ack)
  );




  // -------------------------------------------------------------------------------------
  // Assign Outputs
  // -------------------------------------------------------------------------------------

  // Assert bridge flush ack when all flush requests have been acknowledged.
  // De-assert bridge flush ack when all flush requests have been de-asserted.
  // To handle all bridge/core clock ratio's when the flush sequence is rolled back the core
  // re-asserts its flush request only when the bridge flush ack is
  // de-asserted. If the AXI Slave, AXI DBI Slave and AXI Master are all running at
  // different clock frequencies relative to the core clock and relative to
  // each other then the bridge must wait for the de-assertion of all acks
  // from their respective clock domains before de-asserting its ack. 
  always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_flush_ack
    if (!core_rst_n) begin
      flshctl_slv_flush_ack <= # TP 1'b0;
    end else begin
      if (s_s2c0_sif_flush_ack) begin
        flshctl_slv_flush_ack <= # TP 1'b1;
      end else if (!(s_s2c0_sif_flush_ack)) begin
        flshctl_slv_flush_ack <= # TP 1'b0;
      end
    end  
  end



`ifndef SYNTHESIS

`endif // SYNTHESIS
   
endmodule
