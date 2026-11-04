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
// ---    $Revision: #3 $
// ---    $Author: lnicola $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Ordrb/DWC_pcie_ordrb_rasdp_pkg.svh#3 $
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_PCIE_ORDRB_RASDP_PKG__SVH__
`define __GUARD__DWC_PCIE_ORDRB_RASDP_PKG__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
`include "DWC_pcie_ctl_pkg.svh"

package DWC_pcie_ordrb_rasdp_pkg;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::RAS_DP_PROT_CHK_ID_BASE_ORDRB;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;

// SNPS_SysML_CODE_START
    localparam K_RAS_PROT_RANGE = `CX_RAS_PROT_RANGE;
    localparam K_RAS_RAM_PROT_RANGE = `CX_RAS_RAM_PROT_RANGE;
    localparam K_RAS_PARITY_MODE = `CX_RAS_PARITY_MODE;
    localparam K_RAS_MAXADDRWD  = 32;
// SNPS_SysML_CODE_END

`define RAS_DP_CHK_ID_ORDRB_P_OHRAM                     RAS_DP_PROT_CHK_ID_BASE_ORDRB + 0
`define RAS_DP_CHK_ID_ORDRB_P_AHRAM                     RAS_DP_PROT_CHK_ID_BASE_ORDRB + 1
`define RAS_DP_CHK_ID_ORDRB_P_DRAM                      RAS_DP_PROT_CHK_ID_BASE_ORDRB + 2
`define RAS_DP_CHK_ID_ORDRB_P_TLP_PRFX                  RAS_DP_PROT_CHK_ID_BASE_ORDRB + 3
`define RAS_DP_CHK_ID_ORDRB_P_RAM_PUSH_HDR              RAS_DP_PROT_CHK_ID_BASE_ORDRB + 4
`define RAS_DP_CHK_ID_ORDRB_P_RAM_PUSH_DATA             RAS_DP_PROT_CHK_ID_BASE_ORDRB + 5
`define RAS_DP_CHK_ID_ORDRB_P_FREE_FIFO_RAM_DOUTB       RAS_DP_PROT_CHK_ID_BASE_ORDRB + 6
`define RAS_DP_CHK_ID_ORDRB_P_SBC_RAM_DOUTB             RAS_DP_PROT_CHK_ID_BASE_ORDRB + 7
`define RAS_DP_CHK_ID_ORDRB_P_LTIM_LR_DIN               RAS_DP_PROT_CHK_ID_BASE_ORDRB + 8
`define RAS_DP_CHK_ID_ORDRB_P_REG_TLPI_HEADER           RAS_DP_PROT_CHK_ID_BASE_ORDRB + 9
`define RAS_DP_CHK_ID_ORDRB_P_REG_TLPI_DATA             RAS_DP_PROT_CHK_ID_BASE_ORDRB + 10
`define RAS_DP_CHK_ID_ORDRB_P_APP_WR_DATA               RAS_DP_PROT_CHK_ID_BASE_ORDRB + 11
`define RAS_DP_CHK_ID_ORDRB_P_LOCAL_MSI_HEADER          RAS_DP_PROT_CHK_ID_BASE_ORDRB + 12
`define RAS_DP_CHK_ID_ORDRB_P_TRGT_HEADER               RAS_DP_PROT_CHK_ID_BASE_ORDRB + 13
`define RAS_DP_CHK_ID_LTIM_P_LTIM_LA                    RAS_DP_PROT_CHK_ID_BASE_ORDRB + 14
`define RAS_DP_CHK_ID_MICGIC_REQID                      RAS_DP_PROT_CHK_ID_BASE_ORDRB + 15


`define RAS_DP_CHK_ID_ORDRB_NP_OHRAM                    RAS_DP_PROT_CHK_ID_BASE_ORDRB + 128 + 0 //Rnge for posted ordrb is (0 -> 127) + RAS_DP_PROT_CHK_ID_BASE_ORDRB
`define RAS_DP_CHK_ID_ORDRB_NP_AHRAM                    RAS_DP_PROT_CHK_ID_BASE_ORDRB + 128 + 1
`define RAS_DP_CHK_ID_ORDRB_NP_DRAM                     RAS_DP_PROT_CHK_ID_BASE_ORDRB + 128 + 2
`define RAS_DP_CHK_ID_ORDRB_NP_TLP_PRFX                 RAS_DP_PROT_CHK_ID_BASE_ORDRB + 128 + 3
`define RAS_DP_CHK_ID_ORDRB_NP_RAM_PUSH_HDR             RAS_DP_PROT_CHK_ID_BASE_ORDRB + 128 + 4
`define RAS_DP_CHK_ID_ORDRB_NP_RAM_PUSH_DATA            RAS_DP_PROT_CHK_ID_BASE_ORDRB + 128 + 5
`define RAS_DP_CHK_ID_ORDRB_NP_FREE_FIFO_RAM_DOUTB      RAS_DP_PROT_CHK_ID_BASE_ORDRB + 128 + 6
`define RAS_DP_CHK_ID_ORDRB_NP_SBC_RAM_DOUTB            RAS_DP_PROT_CHK_ID_BASE_ORDRB + 128 + 7
`define RAS_DP_CHK_ID_ORDRB_NP_LTIM_LR_DIN              RAS_DP_PROT_CHK_ID_BASE_ORDRB + 128 + 8
`define RAS_DP_CHK_ID_ORDRB_NP_REG_TLPI_HEADER          RAS_DP_PROT_CHK_ID_BASE_ORDRB + 128 + 9
`define RAS_DP_CHK_ID_ORDRB_NP_REG_TLPI_DATA            RAS_DP_PROT_CHK_ID_BASE_ORDRB + 128 + 10
`define RAS_DP_CHK_ID_ORDRB_NP_APP_WR_DATA              RAS_DP_PROT_CHK_ID_BASE_ORDRB + 128 + 11
`define RAS_DP_CHK_ID_ORDRB_NP_LOCAL_MSI_HEADER         RAS_DP_PROT_CHK_ID_BASE_ORDRB + 128 + 12
`define RAS_DP_CHK_ID_ORDRB_NP_TRGT_HEADER              RAS_DP_PROT_CHK_ID_BASE_ORDRB + 128 + 13
`define RAS_DP_CHK_ID_LTIM_NP_LTIM_LA                   RAS_DP_PROT_CHK_ID_BASE_ORDRB + 128 + 14
`define RAS_DP_CHK_ID_MICGIC_MSIDATA                    RAS_DP_PROT_CHK_ID_BASE_ORDRB + 128 + 15
  // ##########################################################################
  //                                Enumerations
  // ##########################################################################


  // ##########################################################################
  //                          Data Structures/Unions
  // ##########################################################################


// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

endpackage

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

`endif // __GUARD__DWC_PCIE_ORDRB_RASDP_PKG__SVH__

