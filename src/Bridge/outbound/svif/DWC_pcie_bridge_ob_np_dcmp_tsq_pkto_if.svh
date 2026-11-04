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
// ---    $Revision: #3 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/svif/DWC_pcie_bridge_ob_np_dcmp_tsq_pkto_if.svh#3 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_PCIE_BRIDGE_OB_NP_DCMP_TSQ_PKTO_IF__SVH__
`define __GUARD__DWC_PCIE_BRIDGE_OB_NP_DCMP_TSQ_PKTO_IF__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

interface DWC_pcie_bridge_ob_np_dcmp_tsq_pkto_if #(
  parameter type P_PKT_TYPE = logic
) ();

  P_PKT_TYPE w_pkt      ;
  logic      w_pkt_halt ;


// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END


  modport master_mp (
    output w_pkt
   ,input  w_pkt_halt
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


  modport slave_mp (
    input  w_pkt
   ,output w_pkt_halt
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END
    );


endinterface

`endif // __GUARD__DWC_PCIE_BRIDGE_OB_NP_DCMP_TSQ_PKTO_IF__SVH__

