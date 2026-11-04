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
// ---    $DateTime: 2021/10/29 02:04:56 $ 
// ---    $Revision: #6 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_lutMngr_hub.sv#6 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ctxPush_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tagMngr_cfg_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_crPop_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram2p_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tagPop_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tagPush_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_lutMngr_hub
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter       P_ADDRESS_WD = 0
  ,parameter           P_MINTAG = 0
  ,parameter       P_MINTAG_LOW = 0
  ,parameter      P_MINTAG_VLOW = 0
  ,parameter bool_e P_MULTIMODE = E_FALSE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_tagMngr_cfg_if.slave_mp b_cfg
  ,DWC_pcie_edmapf_ram2p_if.master_mp      b_memAccess
  ,DWC_pcie_edmapf_crPop_if.master_mp      b_pop
  ,DWC_pcie_edmapf_ctxPush_if.slave_mp     b_push
  ,DWC_pcie_edmapf_tagPop_if.slave_mp      b_ticketPop
  ,DWC_pcie_edmapf_tagPush_if.master_mp    b_ticketPush
  );


// SNPS_SysML_CODE_START

  /*
    Wiring between the different interfaces
  */
  always_comb begin : c_rackWiring_PROC
    b_push.w_tag        = b_ticketPop.w_tag;
    b_push.w_tagBase    = b_ticketPop.w_tagBase;
    b_push.w_full       = b_ticketPop.w_empty;
    b_ticketPop.w_pop   = b_push.w_push;

    b_memAccess.w_dina  = b_push.w_data;
    b_memAccess.w_ena   = b_push.w_push;
    b_memAccess.w_wea   = b_push.w_push;
    b_memAccess.w_addra = b_ticketPop.w_tagBase[P_ADDRESS_WD-1:0];

    b_ticketPush.w_push = b_pop.w_pop;
    b_ticketPush.w_tag  = b_pop.w_tag;

    b_pop.w_data        = b_memAccess.w_doutb;
    b_pop.w_valid       = b_memAccess.w_validb;
    b_memAccess.w_enb   = b_pop.w_pop || b_pop.w_peek;

    if (P_MULTIMODE) begin
      case (b_cfg.w_mode)
        E_TAGMNGR_VLOW : b_memAccess.w_addrb = b_pop.w_tag - P_MINTAG_VLOW ;
        E_TAGMNGR_LOW  : b_memAccess.w_addrb = b_pop.w_tag - P_MINTAG_LOW  ;
        default        : b_memAccess.w_addrb = b_pop.w_tag - P_MINTAG      ;
      endcase
    end else begin
      b_memAccess.w_addrb = b_pop.w_tag - P_MINTAG;
    end
  end : c_rackWiring_PROC
  
// SNPS_SysML_CODE_END

endmodule
