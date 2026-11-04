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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/common/DWC_pcie_bridge_intf_demux.sv#3 $
// -------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_bridge_intf_demux
 #(
  parameter INTF_WD_A                                  = 5,
  parameter INTF_WD_B                                  = 5
  )
  (
  // -------------------------------------------------------------------------------------
  // Serial interface
  // -------------------------------------------------------------------------------------
  input       [INTF_WD_A-1:0]                        intf_a,
  input       [INTF_WD_B-1:0]                        intf_b,
  output wire                                        dmx_ready,
  // -------------------------------------------------------------------------------------
  // Interface A
  // -------------------------------------------------------------------------------------
  input                                              sel_a,
  output wire [INTF_WD_A-1:0]                        dmx_intf_a,
  input                                              ready_a,
  // -------------------------------------------------------------------------------------
  // Interface B
  // -------------------------------------------------------------------------------------
  output wire [INTF_WD_B-1:0]                        dmx_intf_b,
  input                                              ready_b
  );
  // -------------------------------------------------------------------------------------
  // Wire/Reg
  // -------------------------------------------------------------------------------------
  reg  [INTF_WD_A-1:0]                               s_intf_a;
  reg  [INTF_WD_B-1:0]                               s_intf_b;
  reg                                                s_ready;

  // -------------------------------------------------------------------------------------
  // Design 
  // -------------------------------------------------------------------------------------
  always @(*) begin : proc_comb_mux
    // Initialise
    s_ready   = ready_b;
    s_intf_b  = intf_b;
    s_intf_a  = {INTF_WD_A{1'b0}};
  
    if (sel_a) begin
      s_ready  = ready_a;
      s_intf_a = intf_a;
      s_intf_b = {INTF_WD_B{1'b0}};
    end
  end

  assign dmx_intf_a  = s_intf_a; 
  assign dmx_intf_b  = s_intf_b; 
  assign dmx_ready   = s_ready; 

endmodule
