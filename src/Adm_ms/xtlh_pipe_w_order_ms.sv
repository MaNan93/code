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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xtlh_pipe_w_order_ms.sv#3 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module xtlh_pipe_w_order_ms
import DWC_pcie_core_pkg::xtlh_pkt_t;
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
#(
    parameter N                       = 2,
    parameter PIPE                    = 1,
    parameter CAN_STALL               = 1,
    parameter PREV_STAGE_CAN_HALT     = 1
    ,
    // Bus protection generator inclusion
    parameter BUS_PROTECT_GEN_EN      = 1,
    // Bus protection checker inclusion
    parameter BUS_PROTECT_CHK_EN      = 1,
    parameter RAS_DP_PROT_CHK_ID_BASE = 0
)
(
    input logic                     clk,
    input logic                     rst_n,
    
    input xtlh_pkt_t        [N-1:0] in_pkt,
    output logic            [N-1:0] out_halt,
    input logic             [N-1:0] in_prev_stage_halt, // asserted only when the combo logic is blocking, independently from us.
    
    output xtlh_pkt_t       [N-1:0] out_pkt,
    input logic             [N-1:0] in_halt
    ,
    output ras_dp_err_log_t [N-1:0] ras_dp_err_log
    ,
    input  ras_dp_err_inj_t         ras_dp_err_inj
);
localparam CAN_MASK = (N>1 && PIPE==1); // masking is possible if we have 2 interfaces and the pipe is really a pipe

xtlh_pkt_t [N-1:0] ordered_in_pkt;
logic      [N-1:0] ordered_out_halt;
logic      [N-1:0] mask_input;
xtlh_pkt_t [N-1:0] ordered_out_pkt;
logic      [N-1:0] ordered_in_halt;
logic      [N-1:0] mask_output;

// Re-order input packet if required

generate
    // Only one packet or two pkts but without delay, nothing to worry about
    if(CAN_MASK==0)begin : g_n_1_or_pipe0_input
        assign mask_input  = '0;
    end else begin : g_n_2_or_pipe_in
        assign mask_input[0]  = in_pkt[0].sot && (in_pkt[1].sot || in_pkt[1].dv) && (in_pkt[0].seqnum==(in_pkt[1].seqnum + 3'd1)) && (ordered_out_halt[1] || !in_pkt[1].eot);
        assign mask_input[1]  = in_pkt[1].sot && (in_pkt[0].sot || in_pkt[0].dv) && (in_pkt[1].seqnum==(in_pkt[0].seqnum + 3'd1)) && (ordered_out_halt[0] || !in_pkt[0].eot);
    end
endgenerate

always_comb begin
    for(int i = 0; i < N; i++)begin
        ordered_in_pkt[i]         = in_pkt[i];
        ordered_in_pkt[i].sot     = in_pkt[i].sot    && (CAN_MASK==0 || !mask_input[i]) && (PREV_STAGE_CAN_HALT==0 || !in_prev_stage_halt[i]);
        ordered_in_pkt[i].dv      = in_pkt[i].dv     && (CAN_MASK==0 || !mask_input[i]) && (PREV_STAGE_CAN_HALT==0 || !in_prev_stage_halt[i]);
        ordered_in_pkt[i].eot     = in_pkt[i].eot    && (CAN_MASK==0 || !mask_input[i]) && (PREV_STAGE_CAN_HALT==0 || !in_prev_stage_halt[i]);
        ordered_in_pkt[i].badeot  = in_pkt[i].badeot && (CAN_MASK==0 || !mask_input[i]) && (PREV_STAGE_CAN_HALT==0 || !in_prev_stage_halt[i]);
        out_halt[i]               = ordered_out_halt[i] || mask_input[i];
    end
end

// Instantiate xtlh pipe
xtlh_pipe_ms
 #(
    .N                       (N),
    .PIPE                    (PIPE),
    .CAN_STALL               (CAN_STALL)
    ,
    .BUS_PROTECT_GEN_EN      (BUS_PROTECT_GEN_EN),
    .BUS_PROTECT_CHK_EN      (BUS_PROTECT_CHK_EN),
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE)
) u_xtlh_pipe_ms (
    .clk(clk),
    .rst_n(rst_n),

    .in_pkt(ordered_in_pkt),
    .out_halt(ordered_out_halt),

    .out_pkt(ordered_out_pkt),
    .in_halt(ordered_in_halt)
    ,
    .ras_dp_err_inj     (ras_dp_err_inj),
    .ras_dp_err_log     (ras_dp_err_log)
    );

// Re-order output packet if required
generate
    // Only one packet or two pkts but without delay, nothing to worry about
    if(CAN_MASK==0)begin : g_n_1_or_pipe0_output
        assign mask_output = '0;
    end else begin : g_n_2_or_pipe_out
        assign mask_output[0] = ordered_out_pkt[0].sot && (ordered_out_pkt[1].sot || ordered_out_pkt[1].dv) && ((ordered_out_pkt[0].seqnum==(ordered_out_pkt[1].seqnum + 3'd2)) || ((ordered_out_pkt[0].seqnum==(ordered_out_pkt[1].seqnum + 3'd1)) && !ordered_out_pkt[1].eot));
        assign mask_output[1] = ordered_out_pkt[1].sot && (ordered_out_pkt[0].sot || ordered_out_pkt[0].dv) && ((ordered_out_pkt[1].seqnum==(ordered_out_pkt[0].seqnum + 3'd2)) || ((ordered_out_pkt[1].seqnum==(ordered_out_pkt[0].seqnum + 3'd1)) && !ordered_out_pkt[0].eot));
    end
endgenerate

always_comb begin
    for(int i = 0; i < N; i++)begin
        out_pkt[i]         = ordered_out_pkt[i];
        out_pkt[i].sot     = ordered_out_pkt[i].sot    && (CAN_MASK==0 || !mask_output[i]);
        out_pkt[i].dv      = ordered_out_pkt[i].dv     && (CAN_MASK==0 || !mask_output[i]);
        out_pkt[i].eot     = ordered_out_pkt[i].eot    && (CAN_MASK==0 || !mask_output[i]);
        out_pkt[i].badeot  = ordered_out_pkt[i].badeot && (CAN_MASK==0 || !mask_output[i]);
        ordered_in_halt[i] = (in_halt[i] || (CAN_MASK==1 && mask_output[i]));//  && (ordered_out_pkt[i].sot || ordered_out_pkt[i].dv); // removed because xtlh_pipe_ms uses a pipeline=pipe_w_hs where the halt is not just the registered version of the halt_in, but is validated by the pipeline containing stuff
    end
end


endmodule

