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
// ---    $Revision: #5 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_fetchQ_crgb_ramInterconnector.sv#5 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram1p_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llq_crgbWr_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_llq_crgbRd_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_fetchQ_crgb_ramInterconnector
  import DWC_pcie_edmapf_pkg::*;
  (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_ram1p_if.slave_mp       crgbOvrl
  ,DWC_pcie_edmapf_llq_crgbRd_if.master_mp crgbRd
  ,DWC_pcie_edmapf_llq_crgbWr_if.master_mp crgbWr
  );


// SNPS_SysML_CODE_START
  
  /*
    Connecting the interface signals from CRGB generic modules to the Wr and Rd interfaces which will connect with fetchQ core
  */
  always_comb begin : c_connectingCrgbInterfaceToTheFetchQInterfaces_PROC
    crgbWr.w_reqCh         = crgbOvrl.w_addr;
    crgbWr.w_ovrl          = crgbOvrl.w_din;
    crgbWr.w_ovrlReq       = crgbOvrl.w_wren;
    crgbWr.w_opMode        = '{target: E_TRGT_HEAD, counter: E_CNT_RESET, errors: E_ERR_RESET, token: E_TOKEN_RESET, stop: E_STOP_RESET};
    crgbRd.w_reqCh         = crgbOvrl.w_addr;
    crgbRd.w_en            = crgbOvrl.w_rden;
    crgbOvrl.w_wdone       = crgbWr.w_ackOvrl;
    crgbOvrl.w_dout        = crgbRd.w_ovrl;
    crgbOvrl.w_rdone       = crgbRd.w_ack;
  end : c_connectingCrgbInterfaceToTheFetchQInterfaces_PROC
  
// SNPS_SysML_CODE_END

endmodule
