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
// --- RCS information:
// ---   $DateTime: 2023/06/26 08:32:07 $
// ---   $Revision: #3 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/svif/DWC_cxl_app_ch_init_if.svh#3 $
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_CXL_APP_CH_INIT_IF__SVH__
`define __GUARD__DWC_CXL_APP_CH_INIT_IF__SVH__
interface DWC_cxl_app_ch_init_if
  import DWC_cxl_pkg::*;
  #();

  // -------------------------------------------------------------------------------------
  // CXL.cache/CXL.mem Protocol Link Initialization Interface
  // -------------------------------------------------------------------------------------
  wire                                      s_cxl_init_req;       // CXL.cache/mem Protocol Link Initialization Request
  wire                                      s_cxl_init_ack;       // CXL.cache/mem Protocol Link Initialization Acknowledge
  wire                                      s_cxl_app_pending;    // CXL.cache/mem Protocol Traffic Pending

modport slave_mp(
    input    s_cxl_init_req,
    input    s_cxl_app_pending,
    output   s_cxl_init_ack
);

modport master_mp(
    output   s_cxl_init_req,
    input    s_cxl_init_ack
);
         
endinterface : DWC_cxl_app_ch_init_if
`endif // __GUARD__DWC_CXL_APP_CH_INIT_IF__SVH__
