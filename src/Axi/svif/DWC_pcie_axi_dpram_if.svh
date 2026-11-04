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

// -------------------------------------------------------------------------------------
// ---  RCS information:
// ---    $DateTime: 2021/10/29 02:04:56 $
// ---    $Revision: #1 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/svif/DWC_pcie_axi_dpram_if.svh#1 $
// -------------------------------------------------------------------------------------
// Module description:
// -------------------------------------------------------------------------------------

`ifndef __GUARD__DWC_PCIE_AXI_DPRAM_IF__SVH__
`define __GUARD__DWC_PCIE_AXI_DPRAM_IF__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

interface DWC_pcie_axi_dpram_if #(
   parameter RAM_ADDR_WD     = 4,
   parameter RAM_ADDR_PAR_WD = 1,
   parameter RAM_DATA_WD     = 32
  );

  logic [RAM_ADDR_WD-1:0]     addra;
  logic [RAM_ADDR_PAR_WD-1:0] addra_par;
  logic                       wea;
  logic [RAM_DATA_WD-1:0]     dina;
  logic [RAM_ADDR_WD-1:0]     addrb;
  logic [RAM_ADDR_PAR_WD-1:0] addrb_par;
  logic                       enb;
  logic [RAM_DATA_WD-1:0]     doutb;
  
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

  modport mstr_mp (
    output addra
   ,output addra_par
   ,output wea
   ,output dina
   ,output addrb
   ,output addrb_par
   ,output enb
   ,input  doutb
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );
    
  modport slv_mp (
    input  addra
   ,input  addra_par
   ,input  wea
   ,input  dina
   ,input  addrb
   ,input  addrb_par
   ,input  enb
   ,output doutb
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );
    
endinterface

`endif // __GUARD__DWC_PCIE_AXI_DPRAM_IF__SVH__

