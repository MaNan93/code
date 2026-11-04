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
// ---    $DateTime: 2023/09/27 02:27:25 $ 
// ---    $Revision: #6 $ 
// ---    $Author: dnolan $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/svif/DWC_pcie_edmapf_ram2p_standard_if.svh#6 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_PCIE_EDMAPF_RAM2P_STANDARD_IF__SVH__
`define __GUARD__DWC_PCIE_EDMAPF_RAM2P_STANDARD_IF__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

interface DWC_pcie_edmapf_ram2p_standard_if #(
   parameter             DP = 4096
  ,parameter             PW = 12
  ,parameter P_ADDR_PROT_WD = 2
  ,parameter             WD = 8
  );

  logic             [PW-1:0] w_addra     ;
  logic             [PW-1:0] w_addrb     ;
  logic             [WD-1:0] w_dina      ;
  logic             [WD-1:0] w_doutb     ;
  logic                      w_ena       ;
  logic                      w_enb       ;


// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END


  modport master_mp (
    output w_addra
   ,output w_addrb
   ,output w_dina
   ,input  w_doutb
   ,output w_ena
   ,output w_enb
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


  modport slave_mp (
    input  w_addra
   ,input  w_addrb
   ,input  w_dina
   ,output w_doutb
   ,input  w_ena
   ,input  w_enb
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


endinterface

`endif // __GUARD__DWC_PCIE_EDMAPF_RAM2P_STANDARD_IF__SVH__

