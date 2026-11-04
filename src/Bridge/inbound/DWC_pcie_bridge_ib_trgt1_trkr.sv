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

// ---------------------------------------------------------------------------------------
// ---  RCS information:
// ---    $DateTime: 2023/04/29 12:35:01 $
// ---    $Revision: #1 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/inbound/DWC_pcie_bridge_ib_trgt1_trkr.sv#1 $
// ---------------------------------------------------------------------------------------
// Module Description:
// Does muxing of the inbound traffic, depending on the configuration
// Stamps to the incoming TLP a sequence number
// ---------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"

 
module DWC_pcie_bridge_ib_trgt1_trkr

  #(
    // -------------------------------------------------------------------------------------
    // Parameters not modified by an instantiation parameter assignment
    // -------------------------------------------------------------------------------------
    parameter TP       = `TP
    )
   
                                      (
     input        clk
    ,input        rstn

    ,input        radm_trgt1_p_0_pending
    ,input        radm_trgt1_p_0_hv
    ,input        radm_trgt1_p_0_eot
    ,input        radm_trgt1_p_0_dllp_abort

    ,input        trgt1_radm_intf_p_0_halt
    ,input        brdg_radm_intf_p_0_halt

    ,input        trgt_cpl_lut_empty
    ,input        brdg_trgt1_p_xfer_done
    ,output wire  brdg_mstr_xfer_pending
    ,output wire  radm_edma_p_pending
   );

  reg         r_brdg_trgt1_p_xfer_done; 

  reg  [15:0] r_trgt1_p_cnt;
  wire        s_radm_trgt1_p_accepted;
  wire        s_radm_trgt1_p_dropped;
  wire        s_p_xfer_pend;

  assign s_radm_trgt1_p_accepted = radm_trgt1_p_0_hv                               && !trgt1_radm_intf_p_0_halt;
  assign s_radm_trgt1_p_dropped  = radm_trgt1_p_0_eot && radm_trgt1_p_0_dllp_abort && !brdg_radm_intf_p_0_halt;

  // Delaying brdg_trgt1_p_xfer_done by one clock cycle to prevent brdg_mstr_xfer_pending
  // from deasserting before MSI interrupt is signalled
  always@(posedge clk or negedge rstn)begin: SEQ_R_BRDG_TRGT1_P_XFER_DONE_PROC
    if(!rstn)begin
      r_brdg_trgt1_p_xfer_done <= #TP '0;
    end else begin
      r_brdg_trgt1_p_xfer_done <= #TP brdg_trgt1_p_xfer_done;
    end
  end
   
  always@(posedge clk or negedge rstn)begin: SEQ_R_TRGT1_P_CNT_PROC
    if(!rstn)begin
      r_trgt1_p_cnt <= #TP '0;
    end else begin
      // spyglass disable_block W164a
      // SMD: Identifies assignments in which the LHS width is less than the RHS width
      // SJ: r_trgt1_p_cnt can not overflow.
      r_trgt1_p_cnt <= #TP r_trgt1_p_cnt + s_radm_trgt1_p_accepted - r_brdg_trgt1_p_xfer_done - s_radm_trgt1_p_dropped;
     // spyglass enable_block W164a
    end
  end 

  assign s_p_xfer_pend = r_trgt1_p_cnt != '0;

  assign brdg_mstr_xfer_pending = s_p_xfer_pend || !trgt_cpl_lut_empty;
  assign radm_edma_p_pending    = s_p_xfer_pend || radm_trgt1_p_0_pending;

endmodule
