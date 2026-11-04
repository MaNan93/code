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
// ---   $DateTime: 2021/10/29 02:04:56 $
// ---   $Revision: #2 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/svif/DWC_cxl_clk_rst_if.svh#2 $
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_CXL_CLK_RST_IF__SVH__
`define __GUARD__DWC_CXL_CLK_RST_IF__SVH__
interface DWC_cxl_clk_rst_if ();

  wire s_cxl_clk;
  wire s_cxl_rst_n;
  wire s_core_clk;
  wire s_core_rst_n;

  modport master_mp(
    output  s_cxl_clk,
    output  s_cxl_rst_n,
    output  s_core_clk,
    output  s_core_rst_n
  );

  modport slave_mp(
    input  s_cxl_clk,
    input  s_cxl_rst_n,
    input  s_core_clk,
    input  s_core_rst_n
  );

endinterface : DWC_cxl_clk_rst_if

`endif // __GUARD__DWC_CXL_CLK_RST_IF__SVH__
