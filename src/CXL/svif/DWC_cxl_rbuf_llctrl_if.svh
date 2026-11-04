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
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #4 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/svif/DWC_cxl_rbuf_llctrl_if.svh#4 $
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_CXL_RBUF_LLCTRL_IF__SVH__
`define __GUARD__DWC_CXL_RBUF_LLCTRL_IF__SVH__
interface DWC_cxl_rbuf_llctrl_if

  import DWC_cxl_pkg::*;
  #();

  // Retry Buffer
  logic [(RBUF_DATA_WD - 1) : 0]  s_rbuf_ram_rdata;             // Data Read Back from Retry Buffer
  logic [(RBUF_ADD_WD - 1) : 0]   s_cxl_rbuf_addr;              // Retry Buffer Address
  logic                           s_cxl_rbuf_addr_par;          // Retry Buffer Address Parity
  logic                           s_cxl_rbuf_en;                // Retry Buffer Enable
  logic                           s_cxl_rbuf_wen;               // Retry Buffer Write Enable
  logic [(RBUF_DATA_WD - 1) : 0]  s_cxl_rbuf_wdata;             // Retry Buffer Write Data

  modport master_mp(
    input   s_rbuf_ram_rdata,
    output  s_cxl_rbuf_addr,
    output  s_cxl_rbuf_addr_par,
    output  s_cxl_rbuf_en,
    output  s_cxl_rbuf_wen,
    output  s_cxl_rbuf_wdata
  );

  modport slave_mp(
    output  s_rbuf_ram_rdata,
    input   s_cxl_rbuf_addr,
    input   s_cxl_rbuf_addr_par,
    input   s_cxl_rbuf_en,
    input   s_cxl_rbuf_wen,
    input   s_cxl_rbuf_wdata
  );

endinterface : DWC_cxl_rbuf_llctrl_if

`endif // __GUARD__DWC_CXL_RBUF_LLCTRL_IF__SVH__
