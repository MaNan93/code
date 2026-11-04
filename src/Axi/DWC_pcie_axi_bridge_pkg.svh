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
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/DWC_pcie_axi_bridge_pkg.svh#2 $
// -------------------------------------------------------------------------
// --- Description: AXI Bridge Package
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_PCIE_AXI_BRIDGE_PKG__SVH__
`define __GUARD__DWC_PCIE_AXI_BRIDGE_PKG__SVH__


package DWC_pcie_axi_bridge_pkg;


localparam TX_TLP_PREFIX_WD   = (32*`CX_NPRFX)+ `CX_PRFX_PAR_WD;
localparam PRFX_WIDTH         = (`CX_AXI_IF_ECC_PAR_PROT_EN_VALUE) ? 32*`CX_NPRFX : 32*`CX_NPRFX + `CX_PRFX_PAR_WD;
localparam TPH_ST_WD         = 8;
localparam TPH_PH_WD         = 2;
localparam TPH_TH_WD         = 1;
localparam MISC_INFO_TPH_WD  = TPH_ST_WD + TPH_PH_WD + TPH_TH_WD;
// ECAM base Address width
// Message Manipulation (iATU assisted Message handling)
localparam HDR_UPPR_BYTES_WD  = 64;


endpackage : DWC_pcie_axi_bridge_pkg

`endif //__GUARD__DWC_PCIE_AXI_BRIDGE_PKG__SVH__

