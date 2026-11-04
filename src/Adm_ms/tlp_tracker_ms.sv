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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/tlp_tracker_ms.sv#3 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module tlp_tracker_ms
import DWC_pcie_ctl_pkg::TP;
#(
    parameter N_IN              = 1,
    parameter N_OUT             = 1,
    parameter MAX_PIPE_STAGES   = 5
)
(
    input  logic              clk,
    input  logic              rst_n,
    
    input  logic  [N_IN-1:0]  in_incoming_pkt_valid,
    input  logic  [N_IN-1:0]  in_incoming_pkt_halt,

    input  logic  [N_OUT-1:0] in_outgoing_pkt_valid,
    input  logic  [N_OUT-1:0] in_outgoing_pkt_halt,
    
    output logic              out_pkt_pending
    
);

// Counters' width is sized based on the number of input interfaces and maximum number of pipeline stage in the respective module because this is the worst case
logic [$clog2(N_IN*MAX_PIPE_STAGES+1)-1:0] r_cnt;
logic [$clog2(N_IN*MAX_PIPE_STAGES+1)-1:0] to_add, to_remove;

always_comb begin
    to_add    = '0;
    to_remove = '0;
    for(int i = 0; i < N_IN; i++)  to_add    = (in_incoming_pkt_valid[i] && !in_incoming_pkt_halt[i]) ? to_add    + $bits(r_cnt)'(1) : to_add;
    for(int i = 0; i < N_OUT; i++) to_remove = (in_outgoing_pkt_valid[i] && !in_outgoing_pkt_halt[i]) ? to_remove + $bits(r_cnt)'(1) : to_remove;
end

logic [1:0] coco;
always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        r_cnt <= #TP '0;
        coco  <= #TP 2'b00;
    end else begin
        {coco,r_cnt} <= #TP {2'b00,r_cnt} + {2'b00,to_add} - {2'b00,to_remove};
    end
end

assign out_pkt_pending = |r_cnt;

endmodule

