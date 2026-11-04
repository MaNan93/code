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
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/slave/DWC_pcie_axi_wakeup_ctl.sv#6 $
// -------------------------------------------------------------------------
// --- Module description: Auxilliary clock wakeup control logic
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_axi_wakeup_ctl
 #(
   parameter SYNC_DEPTH                             = 2,
   parameter TP                                     = `TP
 )
 (
  // -------------------------------------------------------------------------------------
  // Clocks and resets
  // -------------------------------------------------------------------------------------
  input                                              aux_clk,
  input                                              core_rst_n,
  input                                              mstr_aclk_ug,
  input                                              mstr_aresetn,
  input                                              slv_aclk_ug,
  input                                              slv_aresetn,
  // -------------------------------------------------------------------------------------
  // Slave Transfer Pending Info interface
  // -------------------------------------------------------------------------------------
  input                                              sif_xfer_pending,
  input                                              sif_xfer_pending_db,
  // -------------------------------------------------------------------------------------
  // Bridge transfer pending interface
  // -------------------------------------------------------------------------------------
  output wire                                        wkctl_slv_xfer_pending_db,
  output wire                                        wkctl_slv_xfer_pending
 );
  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  // -------------------------------------------------------------------------------------
  // Regs/Wires
  // -------------------------------------------------------------------------------------

  wire                                               s2a0_sif_xfer_pending;
  wire                                               s2a1_sifdb_xfer_pending_shared;

  // -------------------------------------------------------------------------------------
  // Instantiate synchronisers
  // DWC_pcie_src_reg_sync is used in place of DWC_pcie_ctl_bcm21 to comply with requirement
  // SNPS_MARCH_3 of Synopsys CDC checklist; this instantiates DWC_pcie_ctl_bcm21 and adds a
  // register on the input operating on the source clock domain to ensure there is no
  // feedback logic on the signal feeding into the DWC_pcie_ctl_bcm21 synchronizer
  // -------------------------------------------------------------------------------------

  DWC_pcie_src_reg_sync
  
  #(
   .WIDTH                            (1),
   .F_SYNC_TYPE                      (SYNC_DEPTH),
   .VERIF_EN                         (1)
  )
  u_s2a0
  (
  .clk_s                             (slv_aclk_ug),
  .rst_s_n                           (slv_aresetn),
  .clk_d                             (aux_clk),
  .rst_d_n                           (core_rst_n),
  .data_s                            (sif_xfer_pending),
  .data_d                            (s2a0_sif_xfer_pending)
  );



  DWC_pcie_src_reg_sync
  
  #(
   .WIDTH                            (1),
   .F_SYNC_TYPE                      (SYNC_DEPTH),
   .VERIF_EN                         (1)
  )
  u_s2a2
  (
  .clk_s                             (slv_aclk_ug),
  .rst_s_n                           (slv_aresetn),
  .clk_d                             (aux_clk),
  .rst_d_n                           (core_rst_n),
  .data_s                            (sif_xfer_pending_db),
  .data_d                            (s2a1_sifdb_xfer_pending_shared)
  );



  // Synchronised application transfer pending signal
  assign wkctl_slv_xfer_pending = s2a0_sif_xfer_pending
                                 ;

  // depending on if there is shared DBI/ Dedicated DBI slave the DBIxfer pending is defined
  assign wkctl_slv_xfer_pending_db =s2a1_sifdb_xfer_pending_shared;

`ifndef SYNTHESIS

`endif // SYNTHESIS

endmodule
