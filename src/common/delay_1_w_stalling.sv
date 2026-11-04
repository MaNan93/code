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
// ---    $DateTime: 2023/06/26 08:32:07 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/delay_1_w_stalling.sv#5 $
// -------------------------------------------------------------------------
// ---
// --- This block can throttled an input stream, with a pipeline delay of 1
// ---
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module delay_1_w_stalling
(
     clk,
     rst_n,
     stall,
     clear,
     din,

     stallout,
     dout
);
parameter DELAY_EN  = 0;            // Add delay if 1
parameter WD        = 1;            // Width of datapath
parameter CAN_STALL = 0;            // Extra output stage enables stalling
parameter RESETVAL  = {WD{1'b0}};   // Allow for non-zero reset value
parameter RESET_STALL = 1'b0;       // Allow for non-zero reset value

input               clk;
input               rst_n;
input               stall; // Stall if not enabled
input               clear; // Synchronus reset
input   [WD-1:0]    din;

output              stallout;
output  [WD-1:0]    dout;
reg     [WD-1:0]    dout_r;
reg     [WD-1:0]    latched_dout;

reg  stall_d;
wire stallin_rising;
wire stallin_falling;

assign dout     = (DELAY_EN>0) ? dout_r  :   din;
assign stallout = (DELAY_EN>0) ? stall_d : stall;

assign stallin_rising  =  stall && !stall_d;
assign stallin_falling = !stall && stall_d;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    dout_r       <= #(`TP) RESETVAL;
    latched_dout <= #(`TP) RESETVAL;
    stall_d      <= #(`TP) RESET_STALL;
  end else 
   if (clear) begin
     dout_r       <= #(`TP) RESETVAL;
     latched_dout <= #(`TP) RESETVAL;
     stall_d      <= #(`TP) RESET_STALL;
  end else

   if (CAN_STALL) begin

     if (stallin_rising)
       latched_dout <= #(`TP) din; // ccx_line: u_axi_bridge.u_ob.u_nprf.u1_delay; REDUNDANT: downstream module (NP decomposer) is sized to take all NP requests the slave accepts so stall is never asserted

     stall_d <= #(`TP) stall;

     if (stallin_falling)
       dout_r <= #(`TP) latched_dout; // ccx_line: u_axi_bridge.u_ob.u_nprf.u1_delay; REDUNDANT: downstream module (NP decomposer) is sized to take all NP requests the slave accepts so stall is never asserted
     else if (!stall && !stall_d)
       dout_r <= #(`TP) din;

   end
end

endmodule
