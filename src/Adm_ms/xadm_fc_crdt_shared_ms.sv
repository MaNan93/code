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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xadm_fc_crdt_shared_ms.sv#4 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/xadm_ms_pkg.svh"
`include "products/pcie_pkg.svh"

module xadm_fc_crdt_shared_ms
import DWC_pcie_ctl_pkg::TP;
import DWC_pcie_ctl_pkg::NVC;
import DWC_pcie_ctl_pkg::NVC_WD;
import DWC_pcie_ctl_pkg::N_XADM_IF;
import DWC_pcie_ctl_pkg::N_XADM_CUMULATIVE_PER_VC;
import DWC_pcie_ctl_pkg::N_XADM_P_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_NP_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_CPL_IF_VC;
import DWC_pcie_ctl_pkg::HCRD_WD;
import DWC_pcie_ctl_pkg::DCRD_WD;
import pcie_pkg::E_P;
import pcie_pkg::E_NP;
import pcie_pkg::E_CPL;
import pcie_pkg::fc_type_e;
#(
    parameter DCRD_SINGLE_WD = $clog2((1024/4)+1), 
    parameter HCRD_SINGLE_WD = $clog2(8+1) 
)
                             (
    input logic                                         clk,
    input logic                                         rst_n,
    
    input logic  [NVC-1:0]                              cfg_vc_enable,
    input logic                                         rdlh_link_down,
    input logic                                         in_flush,
    input logic                                         in_rtlh_fc_init_status,
    input logic                                         in_flit_mode_enable,
    input logic                                         in_p_cpl_merged,
    
    input logic  [N_XADM_IF-1:0]                        in_req,            //E_P are always higher prio than Cpl.
    input logic  [N_XADM_IF-1:0][DCRD_SINGLE_WD-1:0]    in_req_dcrd,
    input logic  [N_XADM_IF-1:0]                        in_halt,
    
    input  logic [NVC-1:0][2:0][1:0]                    in_init_infinite_h,
    input  logic [NVC-1:0][2:0][1:0]                    in_init_infinite_d,
    input  logic [2:0][1:0]                             in_shr_consolidated_init_scale_h,
    input  logic [2:0][1:0]                             in_shr_consolidated_init_scale_d,
    output logic                                        out_fc_prot_err,
    
    // From the Credit Banks
    input logic  [NVC-1:0][2:0][1:0]                    in_prev_remainder_h, 
    input logic  [NVC-1:0][2:0][1:0]                    in_prev_remainder_d, 
    input logic  [NVC-1:0][2:0][HCRD_WD-1:0]            in_shr_fc_h_cdts,
    input logic  [NVC-1:0][2:0][DCRD_WD-1:0]            in_shr_fc_d_cdts,
    
    // To the Credit Banks
    output logic [NVC-1:0][2:0][1:0]                    out_next_remainder_h, 
    output logic [NVC-1:0][2:0][1:0]                    out_next_remainder_d, 
    output logic [N_XADM_IF-1:0]                        out_shr_pass,
    output logic [NVC-1:0][2:0][HCRD_WD-1:0]            out_shr_consume_h, // double slot to account for P/NP
    output logic [NVC-1:0][2:0][DCRD_WD-1:0]            out_shr_consume_d, // double slot to account for P/NP
    output logic [2:0][HCRD_WD-1:0]                     out_shr_total_h,
    output logic [2:0][DCRD_WD-1:0]                     out_shr_total_d
    
    
);
localparam THIS_FC = 0;
localparam CPL_MRG_FC = 1;
localparam SHR = 1;

wire[NVC-1:0] vc_ready = {NVC{in_rtlh_fc_init_status}} & (cfg_vc_enable | (NVC)'(1));


// creates supports signals, in particular:
// - VCS[i]         is the VC of interface[i]
// - FCS_FIX[i]     is the "original" Flow Control type of interface[i], regardless of merged credits (a CPL is always a CPL)
// - FCS_DYN[i]     is the "dynamic" Flow Control type of interface[i], i.e., it is P for merged CPL.
// - G8[i]          indicates whether interface[i] uses a granularity of 8 (1) or 4 (0). Always 0 for NP, it can be 1 for P and CPL in case of merged
logic[N_XADM_IF-1:0][NVC_WD-1:0] VCS;
logic[N_XADM_IF-1:0][1:0]        FCS_FIX;
logic[N_XADM_IF-1:0][1:0]        FCS_DYN;
generate for(genvar gvc=0; gvc < NVC; gvc++)begin : g_vc
    for(genvar gfc=0 ; gfc < 3; gfc++)begin : g_fc
        localparam START = N_XADM_CUMULATIVE_PER_VC[gvc] + (fc_type_e'(gfc)==E_P ? 0 : fc_type_e'(gfc)==E_NP ? N_XADM_P_IF_VC[gvc] : N_XADM_P_IF_VC[gvc] + N_XADM_NP_IF_VC[gvc]);
        localparam N_IF = fc_type_e'(gfc)==E_P ? N_XADM_P_IF_VC[gvc] : fc_type_e'(gfc)==E_NP ? N_XADM_NP_IF_VC[gvc] : N_XADM_CPL_IF_VC[gvc];
        for(genvar gi = 0; gi < N_IF; gi++)begin : g_i
            assign VCS[START+gi]     = (NVC_WD)'(gvc);
            assign FCS_FIX[START+gi] = 2'(gfc); // This is fixed so also for CPL will always be E_CPL
            assign FCS_DYN[START+gi] = (fc_type_e'(gfc)==E_CPL && in_p_cpl_merged) ? 2'd0 : 2'(gfc);
        end
    end
end endgenerate


// Sum all the available shared credits from ALL VCs. 
logic[2:0][HCRD_WD-1:0] avail_h, t_avail_h, c_avail_h;
logic[2:0][DCRD_WD-1:0] avail_d, t_avail_d, c_avail_d;
logic[2:0][NVC-1:0][3:0] co_ok;
always_comb begin
    avail_h = '0;
    avail_d = '0;
    co_ok = '0;
    for(int fc=0; fc <3 ; fc++)begin
        for(int vc=0; vc < NVC; vc++)begin
            {co_ok[fc][vc][0],avail_h[fc]} = in_init_infinite_h[vc][fc][SHR] ? '1 : ({1'b0,avail_h[fc]} + {1'b0,in_shr_fc_h_cdts[vc][fc]});
            {co_ok[fc][vc][1],avail_d[fc]} = in_init_infinite_d[vc][fc][SHR] ? '1 : ({1'b0,avail_d[fc]} + {1'b0,in_shr_fc_d_cdts[vc][fc]});
            if(fc_type_e'(fc)==E_P && in_p_cpl_merged)begin
                {co_ok[fc][vc][2],avail_h[E_P]} = in_init_infinite_h[vc][fc][SHR] ? '1 : ({1'b0,avail_h[E_P]} + {1'b0,in_shr_fc_h_cdts[vc][E_CPL]});
                {co_ok[fc][vc][3],avail_d[E_P]} = in_init_infinite_d[vc][fc][SHR] ? '1 : ({1'b0,avail_d[E_P]} + {1'b0,in_shr_fc_d_cdts[vc][E_CPL]});
            end
            if(fc_type_e'(fc)==E_CPL && in_p_cpl_merged)begin
                avail_h[E_CPL] = '0;
                avail_d[E_CPL] = '0;
            end
        end
    end
end

// Propagate the total shared credits back to each xadm_fc_crdt_bank[vc][fc].
// This way each bank can know whether, overall, there are enough credits to transmit a TLP (for PM interaction) 
// Note that for CPLs, the total shared credits depend on whether it's merged or not
always_comb begin
    out_shr_total_h[E_P]    = avail_h[E_P];
    out_shr_total_h[E_NP]   = avail_h[E_NP];
    out_shr_total_h[E_CPL]  = in_p_cpl_merged ? avail_h[E_P] : avail_h[E_CPL];
    out_shr_total_d[E_P]    = avail_d[E_P];
    out_shr_total_d[E_NP]   = avail_d[E_NP];
    out_shr_total_d[E_CPL]  = in_p_cpl_merged ? avail_d[E_P] : avail_d[E_CPL];
end

logic[N_XADM_IF-1:0][HCRD_WD-1:0] req_h;
logic[N_XADM_IF-1:0][HCRD_WD-1:0] req_wo_rem_h;
logic[N_XADM_IF-1:0][HCRD_WD-1:0] req_wo_rem_roundup_h;
logic[N_XADM_IF-1:0][DCRD_WD-1:0] req_d;
logic[N_XADM_IF-1:0][DCRD_WD-1:0] req_wo_rem_d;
logic[N_XADM_IF-1:0][DCRD_WD-1:0] req_wo_rem_roundup_d;
always_comb begin
    for(int i = 0; i < N_XADM_IF; i++)begin
        req_h[i] = {{HCRD_WD-1{1'b0}}, in_req[i]};
        req_d[i] = {{DCRD_WD-DCRD_SINGLE_WD{1'b0}}, in_req_dcrd[i]};
    end
end

logic[N_XADM_IF-1:0] pass_h;
logic[N_XADM_IF-1:0] pass_d;
logic[N_XADM_IF-1:0] pass;
logic[NVC-1:0][2:0][1:0] t_remainder_h;
logic[NVC-1:0][2:0][1:0] t_remainder_d;
logic[N_XADM_IF-1:0][14:0] co_notok1;
logic[NVC-1:0][2:0] force_halt;
always_comb begin 
    force_halt              = '0;
    pass_h                  = '0;
    pass_d                  = '0;
    pass                    = '0;
    co_notok1               = '0;
    c_avail_h               = avail_h;
    c_avail_d               = avail_d;
    out_shr_consume_h       = '0;
    out_shr_consume_d       = '0;
    req_wo_rem_h            = '0;
    req_wo_rem_roundup_h    = '0;
    req_wo_rem_d            = '0;
    req_wo_rem_roundup_d    = '0;
    out_shr_pass            = '0;
    out_next_remainder_d    = in_prev_remainder_d;
    out_next_remainder_h    = in_prev_remainder_h;
    for(int i = 0; i < N_XADM_IF; i++)begin

        // Is interface[i] being forced to halt because it contains a TLP that
        // should go after another TLP that has already being halted?
        // Example: two parallel P interfaces for VC0.
        // P0 can't pass, then we must force P1 (same VC, same FC) to also not pass. 
        // The FC is "FIX" because a merged CPL (using P credits) does not care about P being halted.
        // Note that this relies on the reqs being ordered inside the <VC,FC> group
        if(!force_halt[VCS[i]][FCS_FIX[i]])begin

            // Use internal t_ structures so that:
            // - during the checks, we can modify them as we please
            // - only if ALL checks pass, and we grant the TLP, then we update the out_next_remainder/c_avail
            // In other words, if at the end we decide not to grant interface[i], the changes we have done to t_* structs are just discarded
            t_remainder_h = out_next_remainder_h;
            t_remainder_d = out_next_remainder_d;
            t_avail_h = c_avail_h;
            t_avail_d = c_avail_d;
            
            // Header check
            // If the request is lower than the remainder, then just use the remainder
            if(req_h[i] <= {{HCRD_WD-2{1'b0}},t_remainder_h[VCS[i]][FCS_FIX[i]]})begin                // Calculate new remainder as current remainder - request.
                // No need to worry about granularity, as the <= above already ensured that the bit[2] is 0 in case of granularity 4
                {co_notok1[i][0],t_remainder_h[VCS[i]][FCS_FIX[i]]} = {1'b0,t_remainder_h[VCS[i]][FCS_FIX[i]]} - {1'b0, req_h[i][1:0]};
                pass_h[i] = 1'b1;
            end 
            //... otherwise, we will consume all the remainder and a part of the real available credits
            else begin
                //.. calculate our many credits are requested after clearing them from the remainder
                req_wo_rem_h[i] = req_h[i] - {{HCRD_WD-2{1'b0}}, t_remainder_h[VCS[i]][FCS_FIX[i]]};

                // Now we need to calculate 1) the amount of requested credits rounded up to the granularity and 2) the new reminder.
                // ... if after having accounted for the reminder, the request is still not a multiple of the granularity,
                // then we will have a new reminder
                if(|req_wo_rem_h[i][1:0])begin
                    // round up the request up to the granularity (+Granularity and clearing last 2 or 3 bits)
                    {co_notok1[i][1],   req_wo_rem_roundup_h[i]}            = {1'b0, req_wo_rem_h[i][HCRD_WD-1:2], 2'b00} + {1'b0, (HCRD_WD-2)'(1), 2'b00};
                    {co_notok1[i][2],   t_remainder_h[VCS[i]][FCS_FIX[i]]}  = 3'b100 - {1'b0,req_wo_rem_h[i][1:0]};
                end
                // ...if the requested after clearing is a multiple of the granularity, the next reminder will be 0
                else begin
                    req_wo_rem_roundup_h[i]             = req_wo_rem_h[i];
                    t_remainder_h[VCS[i]][FCS_FIX[i]]   = 2'b00;
                end
                
                //Check availaibility, using dynamic FC, i.e., E_P in case of Merged Completions
                if(req_wo_rem_roundup_h[i] <= t_avail_h[FCS_DYN[i]])begin
                    pass_h[i]                                   = 1'b1;
                    {co_notok1[i][3], t_avail_h[FCS_DYN[i]]}    = {1'b0, t_avail_h[FCS_DYN[i]]} - {1'b0, req_wo_rem_roundup_h[i]};
                end
            end
            
            // Data check
            // If the request is lower than the remainder, then just use the remainder
            // For granularity 4, assume the MSb of the remainder is always 0, so max remainder is 3 even if specified on 3 bits
            if(req_d[i] <= {{DCRD_WD-2{1'b0}},t_remainder_d[VCS[i]][FCS_FIX[i]]})begin
                // Calculate new remainder as current remainder - request.
                {co_notok1[i][4], t_remainder_d[VCS[i]][FCS_FIX[i]]} = {1'b0,t_remainder_d[VCS[i]][FCS_FIX[i]]} - {1'b0, req_d[i][1:0]};
                pass_d[i] = 1'b1;
            end 
            //... otherwise, we will consume all the remainder and a part of the real available credits
            else begin
                //.. calculate our many credits are requested after clearing them from the remainder
                req_wo_rem_d[i] = req_d[i] - {{DCRD_WD-2{1'b0}}, t_remainder_d[VCS[i]][FCS_FIX[i]]};

                // Now we need to calculate 1) the amount of requested credits rounded up to the granularity and 2) the new reminder.
                // ... if after having accounted for the reminder, the request is still not a multiple of the granularity,
                // then we will have a new reminder
                if(|req_wo_rem_d[i][1:0])begin
                    // round up the request up to the granularity (+Granularity and clearing last 2 or 3 bits)
                    {co_notok1[i][5],   req_wo_rem_roundup_d[i]}            = {1'b0, req_wo_rem_d[i][DCRD_WD-1:2], 2'b00} + {1'b0, (DCRD_WD-2)'(1), 2'b00};
                    {co_notok1[i][6],  t_remainder_d[VCS[i]][FCS_FIX[i]]}   = 3'b100 - {1'b0,req_wo_rem_d[i][1:0]};
                end 
                // ...if the requested after clearing is a multiple of 4, the next reminder will be 0
                else begin
                    req_wo_rem_roundup_d[i]             = req_wo_rem_d[i];
                    t_remainder_d[VCS[i]][FCS_FIX[i]]   = 2'b00;
                end
                
                //Check availaibility, note that FCs[x] for Completions can be E_P in case of Merged
                if(req_wo_rem_roundup_d[i] <= t_avail_d[FCS_DYN[i]])begin
                    pass_d[i]                               = 1'b1;
                    {co_notok1[i][7], t_avail_d[FCS_DYN[i]]}   = {1'b0, t_avail_d[FCS_DYN[i]]} - {1'b0, req_wo_rem_roundup_d[i]};
                end
            end
            

            // Check if PASS/HALT and consume credit
            pass[i] = in_flit_mode_enable && (in_flush || (vc_ready[VCS[i]] && pass_h[i] && pass_d[i]));
            if(in_req[i])begin
                if(pass[i] && !in_flush && !in_halt[i])begin
                    // If we are passing, update the consume counter (dynamic! Completions will consume P credit if Merged)
                    {co_notok1[i][8],out_shr_consume_h[VCS[i]][FCS_FIX[i]]} = {1'b0,out_shr_consume_h[VCS[i]][FCS_FIX[i]]} + {1'b0,req_wo_rem_roundup_h[i]};
                    {co_notok1[i][9],out_shr_consume_d[VCS[i]][FCS_FIX[i]]} = {1'b0,out_shr_consume_d[VCS[i]][FCS_FIX[i]]} + {1'b0,req_wo_rem_roundup_d[i]};
                    c_avail_h = t_avail_h;
                    c_avail_d = t_avail_d;
                    out_next_remainder_h = t_remainder_h;
                    out_next_remainder_d = t_remainder_d;
                    out_shr_pass[i] = 1'b1;
                end else begin
                    // If there is a request but for some reason we can't let this packet pass (no credit or halt), then prevent
                    // any further TLP for the same VC/FC to pass (except in case of flush where we don't care)
                    if(!in_flush)begin
                        force_halt[VCS[i]][FCS_FIX[i]] = 1'b1;
                    end
                end
            end
        end
    end
end


// Avail can go negative for shr crd in case of multi-VC
logic[2:0] c_shr_unused_cr_err_h, c_shr_unused_cr_err_d, shr_unused_cr_err, r_shr_unused_cr_err;
always_comb begin
    for(int fc = 0; fc < 3; fc++)begin
        c_shr_unused_cr_err_h[fc] = (((in_shr_consolidated_init_scale_h[fc] == 2'b11)                                                       && (out_shr_total_h[fc] >= 12'h7f1)) || 
                                     ((in_shr_consolidated_init_scale_h[fc] == 2'b10)                                                       && (out_shr_total_h[fc] >= 12'h1fd)) || 
                                     (((in_shr_consolidated_init_scale_h[fc] == 2'b01) || (in_shr_consolidated_init_scale_h[fc] == 2'b00))  && (out_shr_total_h[fc] >= 12'h80)))
                                     && ((fc==E_CPL && in_p_cpl_merged) ? !in_init_infinite_h[0][E_P][SHR] : !in_init_infinite_h[0][fc][SHR]);
        c_shr_unused_cr_err_d[fc] = (((in_shr_consolidated_init_scale_d[fc] == 2'b11)                                                       && (out_shr_total_d[fc] >= 16'h7ff1)) || 
                                     ((in_shr_consolidated_init_scale_d[fc] == 2'b10)                                                       && (out_shr_total_d[fc] >= 16'h1ffd)) || 
                                     (((in_shr_consolidated_init_scale_d[fc] == 2'b01) || (in_shr_consolidated_init_scale_d[fc] == 2'b00))  && (out_shr_total_d[fc] >= 16'h800)))
                                     && ((fc==E_CPL && in_p_cpl_merged) ? !in_init_infinite_d[0][E_P][SHR] : !in_init_infinite_d[0][fc][SHR]);
    end
end
assign shr_unused_cr_err[E_P  ]         = (c_shr_unused_cr_err_h[E_P  ] || c_shr_unused_cr_err_d[E_P  ]) && !r_shr_unused_cr_err[E_P  ];
assign shr_unused_cr_err[E_NP ]         = (c_shr_unused_cr_err_h[E_NP ] || c_shr_unused_cr_err_d[E_NP ]) && !r_shr_unused_cr_err[E_NP ];
assign shr_unused_cr_err[E_CPL]         = (c_shr_unused_cr_err_h[E_CPL] || c_shr_unused_cr_err_d[E_CPL]) && !r_shr_unused_cr_err[E_CPL];
always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        r_shr_unused_cr_err <= #TP 3'b000;
        out_fc_prot_err     <= #TP 1'b0;
    end else begin
        for(int fc = 0; fc < 3; fc++)begin
            r_shr_unused_cr_err[fc] <= #TP (rdlh_link_down) ? 1'b0 : (c_shr_unused_cr_err_h[fc] || c_shr_unused_cr_err_d[fc]);
        end
        out_fc_prot_err     <= #TP |shr_unused_cr_err;
    end
end



endmodule

