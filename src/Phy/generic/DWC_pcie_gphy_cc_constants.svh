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
// ---    $DateTime: 2023/04/29 12:35:01 $
// ---    $Revision: #13 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_cc_constants.svh#13 $
// -------------------------------------------------------------------------
// --- Description: configuration parameters for the SNPS PCIe generic PHY
// --- model
// -------------------------------------------------------------------------

`ifndef __GUARD__DWC_PCIE_GPHY_CC_CONSTANTS__SVH__
`define __GUARD__DWC_PCIE_GPHY_CC_CONSTANTS__SVH__

`define GPHY_NL `CX_NL
`define GPHY_NB `CX_PHY_NB

`define GPHY_WIDTH_WD `CX_PHY_WIDTH_WD
`define GPHY_RXSB_WD `CX_PHY_RXSB_WD
`define GPHY_TXEI_WD `CX_PHY_TXEI_WD

`define GPHY_PIPE_RETIMING_DEPTH `CX_PIPE_RETIMING_DEPTH

// parameter related to PIPE Spec version
`define GPHY_PIPE_VER `CX_PIPE_VER
`define GPHY_SEQCMD_ALLOWED (`GPHY_PIPE_VER>=2)

`ifdef CX_PIPE43_SUPPORT
  `define GPHY_PIPE43_SUPPORT
`endif // CX_PIPE43_SUPPORT

`ifdef CX_PIPE43_P0_P1CPM
  `define GPHY_PIPE43_P0_P1CPM
`endif //CX_PIPE43_P0_P1CPM

`ifdef CX_PIPE43_P1CPM_P1
  `define GPHY_PIPE43_P1CPM_P1
`endif //CX_PIPE43_P1CPM_P1

`ifdef CX_PIPE43_ASYNC_HS_BYPASS
  `define GPHY_PIPE43_ASYNC_HS_BYPASS
`endif // CX_PIPE43_ASYNC_HS_BYPASS

`ifdef CX_PIPE44_SUPPORT
  `define GPHY_PIPE44_SUPPORT
`endif // CX_PIPE44_SUPPORT

`ifdef CX_PIPE43_ASYNC_HS_BYPASS
  `define GPHY_PIPE43_ASYNC_HS_BYPASS
`endif //CX_PIPE43_ASYNC_HS_BYPASS

`ifdef CX_PIPE5_SUPPORT
  `define GPHY_PIPE51_SUPPORT
`endif // CX_PIPE5_SUPPORT

`ifdef CX_PIPE6_SUPPORT
  `define GPHY_PIPE6_SUPPORT
`endif // CX_PIPE6_SUPPORT

`ifdef CX_PIPE51_X_REG_MAP
  `define GPHY_PIPE51_X_REG_MAP
`endif // CX_PIPE51_X_REG_MAP

// encoding of additional PIPE43 states
`define GPHY_PDOWN_P1_1         `CX_PIPE43_P1_1_ENCODING
`define GPHY_PDOWN_P1_2         `CX_PIPE43_P1_2_ENCODING
`define GPHY_PDOWN_P1_CPM       `CX_PIPE43_P1CPM_ENCODING
`define GPHY_PDOWN_P2_NOBEACON  `CX_PIPE43_P2NOBEACON_ENCODING

`define GPHY_VIEWPORT_DATA      `CX_PHY_VIEWPORT_DATA
`define GPHY_NUM_MACROS         `CX_PHY_NUM_MACROS

`define GPHY_MAX_PCLK_FREQ_MHZ  `CX_PHY_MAX_PCLK_FREQ_MHZ

`ifdef CX_PIPE_PCLK_AS_PHY_INPUT
  `define GPHY_PIPE_PCLK_AS_PHY_INPUT
`endif // CX_PIPE_PCLK_AS_PHY_INPUT

`ifdef CX_PIPE_PCLK_MODE_1
   `define GPHY_PIPE_PCLK_MODE_1 
`endif //CX_PIPE_PCLK_MODE_1

`ifdef CX_PIPE_PCLK_MODE_2   
   `define GPHY_PIPE_PCLK_MODE_2 
`endif // CX_PIPE_PCLK_MODE_2   

`ifdef CX_PIPE_PCLK_MODE_3
   `define GPHY_PIPE_PCLK_MODE_3
`endif // CX_PIPE_PCLK_MODE_3

`define GPHY_PIPE_OPTIONAL_PCLKCHANGE_HS   `CX_PIPE_OPTIONAL_PCLKCHANGE_HS

`endif // __GUARD__DWC_PCIE_GPHY_CC_CONSTANTS__SVH__

