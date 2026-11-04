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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/common/DWC_pcie_bridge_par_decode.sv#3 $
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_bridge_par_decode
  #(
    // -------------------------------------------------------------------------------------
    // Global
    parameter CX_RAS_PROT_RANGE = 8,
    parameter DBUS_WD_NP         = 32,  //Data bus without parity
    parameter DBUS_WD_P          = DBUS_WD_NP + (DBUS_WD_NP / CX_RAS_PROT_RANGE), //Data bus with parity
    parameter WD_P               = DBUS_WD_P - DBUS_WD_NP
  )
  (
    input [DBUS_WD_P-1:0]        datap_in,
    output wire [DBUS_WD_NP-1:0] data_out,
    output wire [WD_P-1:0]       par_out
  );

  logic [WD_P-1:0]                                                    par_in;
  logic [(DBUS_WD_NP/CX_RAS_PROT_RANGE)-1:0]  [CX_RAS_PROT_RANGE  :0] datap_in_sliced;
  logic [(DBUS_WD_NP/CX_RAS_PROT_RANGE)-1:0]  [CX_RAS_PROT_RANGE-1:0] datap_in_no_par_sliced;

  assign datap_in_sliced = datap_in;

  always_comb begin : proc_comb_no_par
    foreach (datap_in_sliced[i]) begin
      datap_in_no_par_sliced[i] = datap_in_sliced[i][CX_RAS_PROT_RANGE-1:0];
      par_in[i] = datap_in_sliced[i][CX_RAS_PROT_RANGE];
    end
  end

  assign data_out = datap_in_no_par_sliced;
  assign par_out = par_in;

endmodule
