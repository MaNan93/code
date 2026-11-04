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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_msg_req.sv#3 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module handles one MSG request logic
// --- It takes a request pulse and assert a request until granted
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_msg_req (
    // Inputs
    core_rst_n,
    core_clk,
    msg_event_pulse,
    msg_grt,
    // Outputs
    msg_req
);
// -----------------------------------------------------------------------------
// --- Parameters
// -----------------------------------------------------------------------------
parameter INST  = 0;            // The uniquifying parameter for each port logic instance.
parameter TP    = `TP;          // Clock to Q delay (simulator insurance)

input       core_rst_n;
input       core_clk;
input       msg_event_pulse;    // MSG event pulse
input       msg_grt;            // MSG request has been granted

output      msg_req;            // Message Request

reg         msg_req;

// -----------------------------------------------------------------------------
// set and clear
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        msg_req     <= #TP 0;
    end else begin
        msg_req     <= #TP msg_grt ? 0 : msg_event_pulse ? 1'b1 : msg_req;
    end

endmodule
