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
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xadm_generic_dual_arb_ms.sv#2 $
// -------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// --- Module Description:
// This module takes several dual inputs and arbitrates them
// Inputs are grouped in:
// - PR0 (priority0): only 1 input, always high-priority, wins the contention
// - PR1 (priority1): N_PR1 inputs, arbitrated in round-robin
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
module xadm_generic_dual_arb_ms
import DWC_pcie_ctl_pkg::TP;
import DWC_pcie_core_pkg::xadm_pkt_t;
#(
    parameter      N_PR1                 = 2,
    parameter type PKT_TYPE              = xadm_pkt_t,
    parameter      FORCE_STAY_ON_HALT    = 1,
    parameter      NO_PR0_PKT            = 0,   //no pkt at in_pr0_pkt input port (to disable all assertions related to starvation of in_pr1_pkt due to in_pr0_pkt
    parameter      N                     = 2
)
(
    input  logic                     clk,
    input  logic                     rst_n,
    // priority0 channel (priority0 is high priority)
    input  PKT_TYPE            [1:0] in_pr0_pkt,
    output logic               [1:0] out_pr0_halt,
    // priority1 channels (priority1 are low priority)
    input  PKT_TYPE [N_PR1-1:0][1:0] in_pr1_pkt,
    input  logic    [N_PR1-1:0]      in_pr1_mask,
    output logic    [N_PR1-1:0][1:0] out_pr1_halt,
    // output channels
    output PKT_TYPE            [1:0] out_pkt,
    input  logic               [1:0] in_halt
);
localparam REQ_WD = 1 + N_PR1;
logic [REQ_WD-1:0]      c_hv_not_masked_channel;
logic [REQ_WD-1:0]      c_other_channels_starving_because_me;
logic                   r_keep_same_arbitration;
logic [REQ_WD-1:0]      c_pkt_grant,r_pkt_grant;
logic [1:0]             r_multi_cycle_pkt;
logic [REQ_WD-1:0]      grant;

// UNR constraints
// in_pr0_pkt should be =0, in case of NO_PR0_PKT=1
`SNPS_UNR_CONSTANT("In single port mode, packet at second interface cannot be asserted as 2'nd port not exits", in_pr0_pkt[0], '0,NO_PR0_PKT)
`SNPS_UNR_CONSTANT("In single port mode, packet at second interface cannot be asserted as 2'nd port not exits", in_pr0_pkt[1], '0,N<2 || NO_PR0_PKT)
`SNPS_UNR_CONSTANT("In single port mode, halt at second interface cannot be asserted as 2'nd port not exits", in_halt[1], 1'b0,N<2)
`SNPS_UNR_CONSTANT("In single port mode, packet at second interface cannot be asserted as 2'nd port not exits", in_pr1_pkt[0][1], '0,N<2)
`SNPS_UNR_CONSTANT("In single port mode, packet at second interface cannot be asserted as 2'nd port not exits", in_pr1_pkt[1][1], '0,N_PR1>1 && N<2 )
`SNPS_UNR_CONSTANT("In single port mode, packet at second interface cannot be asserted as 2'nd port not exits", in_pr1_pkt[2][1], '0,N_PR1>2 && N<2)
`SNPS_UNR_CONSTANT("In single port mode, halt at second interface cannot be asserted as 2'nd port not exits", in_halt[1], 1'b0, N<2)  


// Retrieve per-channel hv, considering only the ones not masked from external
always_comb begin
    c_hv_not_masked_channel[0] = in_pr0_pkt[0].hv || in_pr0_pkt[1].hv;
    // if there is valid pkt at in_pr0_pkt port, mask all in_pr1_pkt to force bcm to grant in_pr0_pkt 
    for(int ch = 0; ch < N_PR1; ch++)begin
        c_hv_not_masked_channel[ch+1] = c_hv_not_masked_channel[0] ? 1'b0 : ((in_pr1_pkt[ch][0].hv || in_pr1_pkt[ch][1].hv) && !in_pr1_mask[ch]);
    end
end

// Calculate if a channel is starving others, i.e., if i'm the one transferring (c_pkt_grant) and there are others UNMASKED hv:
always_comb begin
    for(int ch = 0; ch < REQ_WD; ch++)begin
        c_other_channels_starving_because_me[ch] = c_pkt_grant[ch] && |(c_hv_not_masked_channel & ~((REQ_WD)'(1'b1 << ch)));
    end
end
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        r_keep_same_arbitration <= #TP 1'b0;
        r_pkt_grant             <= #TP '0;
        r_multi_cycle_pkt       <= #TP '0;
    end else begin
        r_keep_same_arbitration <= #TP  FORCE_STAY_ON_HALT==0            ? 1'b0                       :
                                        (out_pkt[0].hv && out_pkt[1].hv) ? (in_halt[0] && in_halt[1]) : // if both are going out, keep same arbitration only if both are halted
                                        (out_pkt[0].hv                 ) ? (in_halt[0])               : 
                                        (out_pkt[1].hv                 ) ? (in_halt[1])               :
                                        1'b0;
        r_pkt_grant             <= #TP  c_pkt_grant;
        r_multi_cycle_pkt[0]    <= #TP (out_pkt[0].hv && !out_pkt[0].eot && !in_halt[0]) ? 1'b1 : (out_pkt[0].eot && !in_halt[0]) ? 1'b0 : r_multi_cycle_pkt[0];
        r_multi_cycle_pkt[1]    <= #TP (out_pkt[1].hv && !out_pkt[1].eot && !in_halt[1]) ? 1'b1 : (out_pkt[1].eot && !in_halt[1]) ? 1'b0 : r_multi_cycle_pkt[1];
    end
end
// high priority packet(in_pr0_pkt) can mask low priority one (in_pr1_pkt)
// high priority packet(in_pr0_pkt) is masked if hv=0(not valid pkt) only  
wire    c_same_arbitration_is_now_masked = |(r_pkt_grant & ~c_hv_not_masked_channel);
// disable arbitration logic if
// Transferring packet is multicycle packet (to keep same granted pkt) or 
// There is an in_halt and the granted packet is still valid (not masked now).  
wire    c_enable_arbiter                 = (|r_multi_cycle_pkt) || (r_keep_same_arbitration && !c_same_arbitration_is_now_masked)? 1'b0 : 1'b1;
assign  c_pkt_grant                      = c_enable_arbiter ? grant : r_pkt_grant;
DWC_pcie_ctl_bcm55_c

#(
    .N           (REQ_WD),
    .OUTPUT_MODE (0),
    .INDEX_WIDTH ($clog2(REQ_WD))
) u_DWC_pcie_ctl_bcm55_c (
    .clk         (clk),
    .rst_n       (rst_n),
    .init_n      (1'b1),
    .enable      (c_enable_arbiter),
    .request     (c_hv_not_masked_channel),
    .mask        ('0),
    .granted     (/*UC*/),
    .grant       (grant),
    .grant_index (/*UC*/)
);
always_comb begin
    for(int i = 0; i < 2; i++)begin
        //Initialise out_pkt and out_halts
        out_pkt[i]      = '0;
        out_pr0_halt[i] = in_pr0_pkt[i].hv || in_pr0_pkt[i].dv; 
        for(int ch = 0; ch < N_PR1; ch++)begin
            out_pr1_halt[ch][i] = in_pr1_pkt[ch][i].hv || in_pr1_pkt[ch][i].dv;
        end
        // Connect out_pkt/out_halts based on c_pkt_grant
        if (c_pkt_grant[0]) begin
            out_pkt[i]      = in_pr0_pkt[i];
            out_pr0_halt[i] = in_halt[i];
        end else begin
            for (int ch=0; ch<N_PR1; ch++) begin
                if (c_pkt_grant[1+ch]) begin
                    out_pkt[i]          = (r_multi_cycle_pkt[(i+1)%2] && c_other_channels_starving_because_me[1+ch] && !r_multi_cycle_pkt[i]) ? '0 : in_pr1_pkt[ch][i];
                    out_pr1_halt[ch][i] = (r_multi_cycle_pkt[(i+1)%2] && c_other_channels_starving_because_me[1+ch] && !r_multi_cycle_pkt[i]) ? 1'b1 : in_halt[i];
                end
            end
        end
    end
end


endmodule
