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
// ---    $Revision: #1 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DWC_pcie_bus_latch.sv#1 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

// Module description:
// For a bus with VALID and DATA signals, entire bus is passthrough when a BUS_VALID event occurs.
// When there is no BUS_VALID event this cycle, the output VALID signals are idle
//   and output DATA is latched to the last BUS_VALID event.
// Uses i_mask and i_mask_level to control what is considered a BUS_VALID event:
//   A BUS_VALID event triggers when (i_mask[i] == 1) && (i_bus[i] == i_mask_level[i]), foreach i_bus[i]

module DWC_pcie_bus_latch
  #(
    parameter type    P_BUS_T    = struct packed { logic valid; }
   ,parameter P_BUS_T P_IDLE_BUS = P_BUS_T'{default:'0}
  ) (
    input  logic   i_clk
   ,input  logic   i_rst_n

   ,input  P_BUS_T i_mask
   ,input  P_BUS_T i_mask_level

   ,input  P_BUS_T i_bus
   ,output P_BUS_T o_bus
  );

  P_BUS_T r_bus, s_bus;
  logic   s_update_bus;

  // Update bus if (i_bus[i] == i_mask_level[i]) && (i_mask[i] == 1'b1)
  assign s_update_bus = |(i_mask & ~(i_bus ^ i_mask_level));
  // next_r_bus[i] = (s_update_bus & i_mask[i]) ? P_IDLE_BUS[i] : i_bus[i]
  assign s_bus = (P_IDLE_BUS & i_mask) | (i_bus & ~i_mask);

  always_ff @(posedge i_clk, negedge i_rst_n)
         if(!i_rst_n)     r_bus <= #`TP P_IDLE_BUS;
    else if(s_update_bus) r_bus <= #`TP s_bus;

  assign o_bus = s_update_bus ? i_bus : r_bus;

`ifndef SYNTHESIS
`endif // SYNTHESIS

endmodule : DWC_pcie_bus_latch
