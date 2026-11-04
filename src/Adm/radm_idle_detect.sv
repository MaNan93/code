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
// ---    $DateTime: 2022/04/14 09:36:50 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/radm_idle_detect.sv#4 $
// -------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// RADM Idle detection: This module implements a shift register, the depth
// of which has been determined based on the number of pipeline stages in the design.
// The shift register is loaded either when a request is presented at the interface
// or when there is data in one of the pipeline stages. The shift register is unloaded
// when there is nothing pending in the RADM or no request is active. When the shift
// register has been fully unloaded the idle indication is asserted.
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
 
module radm_idle_detect
  #(
    parameter TP  = `TP,
    parameter DEPTH = 3
  ) 
                         (
  input         clk,
  input         rst_n,
  input         req,
  input         pending,
  output logic  radm_idle
);

logic [(DEPTH - 1) : 0] idle_r;
logic [(DEPTH - 1) : 0] shift_in_s;
logic                   not_idle_s;

assign not_idle_s = req || pending;

assign shift_in_s = {not_idle_s, idle_r[(DEPTH - 1) : 1]};

always_ff @(posedge clk or negedge rst_n) begin : idle_PROC
  if(!rst_n) begin
    idle_r <= #TP {DEPTH{1'b0}};
  end
  else begin
    idle_r <= #TP shift_in_s;
  end
end : idle_PROC

assign radm_idle = !(|shift_in_s);

endmodule

