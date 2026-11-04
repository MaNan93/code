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
// ---    $Revision: #7 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/svif/DWC_pcie_edmapf_cdmregs_if.svh#7 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_PCIE_EDMAPF_CDMREGS_IF__SVH__
`define __GUARD__DWC_PCIE_EDMAPF_CDMREGS_IF__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

interface DWC_pcie_edmapf_cdmregs_if #(
   parameter                CX_NFUNC = `CX_NFUNC
  ,parameter CX_REMOTE_LUT_PTR_WIDTH = `CX_REMOTE_LUT_PTR_WIDTH
  );

  logic                               w_cfg_10b_tag_en                ;
  logic                               w_cfg_bridge_sb_init_i          ;
  logic                               w_cfg_ext_tag_en                ;
  logic            [(3*CX_NFUNC)-1:0] w_cfg_max_payload_size          ;
  logic            [(3*CX_NFUNC)-1:0] w_cfg_max_rd_req_size           ;
  logic [CX_REMOTE_LUT_PTR_WIDTH-1:0] w_cfg_remote_max_bridge_tag     ;
  logic                         [2:0] w_cfg_remote_rd_req_bridge_size ;


// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END


  modport master_mp (
    output w_cfg_10b_tag_en
   ,output w_cfg_bridge_sb_init_i
   ,output w_cfg_ext_tag_en
   ,output w_cfg_max_payload_size
   ,output w_cfg_max_rd_req_size
   ,output w_cfg_remote_max_bridge_tag
   ,output w_cfg_remote_rd_req_bridge_size
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


  modport slave_mp (
    input  w_cfg_10b_tag_en
   ,input  w_cfg_bridge_sb_init_i
   ,input  w_cfg_ext_tag_en
   ,input  w_cfg_max_payload_size
   ,input  w_cfg_max_rd_req_size
   ,input  w_cfg_remote_max_bridge_tag
   ,input  w_cfg_remote_rd_req_bridge_size
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


endinterface

`endif // __GUARD__DWC_PCIE_EDMAPF_CDMREGS_IF__SVH__

