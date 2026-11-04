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
// ---    $DateTime: 2024/01/10 14:23:51 $
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xadm_fc_crdt_bank_ms.sv#7 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/xadm_ms_pkg.svh"
`include "products/pcie_pkg.svh"

module xadm_fc_crdt_bank_ms
import DWC_pcie_ctl_pkg::TP;
import DWC_pcie_ctl_pkg::NVC;
import DWC_pcie_ctl_pkg::NF;
import DWC_pcie_ctl_pkg::HCRD_WD;
import DWC_pcie_ctl_pkg::DCRD_WD;
import xadm_ms_pkg::xadm_restore_fc_crdt_t;
import xadm_ms_pkg::xadm_fc_update_t;
import xadm_ms_pkg::SHR;
import xadm_ms_pkg::DED;
import DWC_pcie_core_pkg::xadm_pkt_t;
import pcie_pkg::E_P;
import pcie_pkg::E_NP;
import pcie_pkg::E_CPL;
import pcie_pkg::fc_type_e;
#(
    parameter           N              = 16,
    parameter           VC             = 0,
    parameter           DCRD_SINGLE_WD = $clog2((1024/4)+1),
    parameter           HCRD_SINGLE_WD = $clog2(8+1),
    parameter           DCRD_N_WD      = $clog2((N*(1024/4)) +1 ),
    parameter           HCRD_N_WD      = $clog2((N*8)+1 ),
    parameter fc_type_e FC_TYPE        = E_P
) 
                           (
    input logic                                                   clk,
    input logic                                                   rst_n,
    
    input logic                                                   cfg_vc_enable,
    input logic                       [2:0]                       cfg_max_payload_size,
    input logic                                                   cfg_can_transmit_atomic,
    input logic                                                   cfg_can_transmit_dmwr,
    
    input logic                                                   rdlh_link_down,
    input logic                                                   in_flush,
    input logic                                                   in_rtlh_fc_init_status,
    input logic                                                   in_flit_mode_enabled,
    
    input xadm_restore_fc_crdt_t [1:0]                            in_internal_restore, // 0 for dedicated, 1 for shared
    input xadm_fc_update_t                                        in_update,
    
    input logic                       [N-1:0]                     in_req,           //E_P are always higher prio than Cpl
    input logic                       [N-1:0][DCRD_SINGLE_WD-1:0] in_req_dcrd,
    input logic                       [N-1:0]                     in_halt,
    
    output logic                                                  out_p_cpl_merged,
    // From shared credit block
    input logic                       [N-1:0]                     in_shr_pass,
    input logic                       [HCRD_WD-1:0]               in_shr_consume_h, // double slot to account for P/NP
    input logic                       [DCRD_WD-1:0]               in_shr_consume_d, // double slot to account for P/NP
    input logic                       [HCRD_WD-1:0]               in_shr_total_h,
    input logic                       [DCRD_WD-1:0]               in_shr_total_d,
    input logic                       [1:0]                       in_shr_consolidated_init_scale_h, 
    input logic                       [1:0]                       in_shr_consolidated_init_scale_d, 
    input logic                       [1:0]                       in_next_remainder_h, 
    input logic                       [1:0]                       in_next_remainder_d, 
    input logic                                                   in_shr_p_is_infinite_h,
    input logic                                                   in_shr_p_is_infinite_d,
    
    // ----Outputs----
    output logic                      [N-1:0]                     out_pass,         // when not hv, always 1
    output logic                      [N-1:0]                     out_used_dedicated_credit,
    
    output logic                      [1:0][1:0]                  out_init_scale_h,
    output logic                      [1:0][1:0]                  out_init_scale_d,
    output logic                      [1:0]                       out_init_zero_h,
    output logic                      [1:0]                       out_init_zero_d,
    output logic                                                  out_fc_prot_err,        
    output logic                      [1:0]                       out_init_infinite_h,
    output logic                      [1:0]                       out_init_infinite_d,
    
    output logic                      [HCRD_WD-1:0]               out_ded_fc_cnsmd_h,
    output logic                      [DCRD_WD-1:0]               out_ded_fc_cnsmd_d,
    output logic                      [HCRD_WD-1:0]               out_ded_fc_limit_h,
    output logic                      [DCRD_WD-1:0]               out_ded_fc_limit_d,
    output logic                      [HCRD_WD-1:0]               out_shr_fc_cnsmd_h,
    output logic                      [DCRD_WD-1:0]               out_shr_fc_cnsmd_d,
    output logic                      [HCRD_WD-1:0]               out_shr_fc_limit_h,
    output logic                      [DCRD_WD-1:0]               out_shr_fc_limit_d,
    output logic                      [HCRD_WD-1:0]               out_ded_fc_h_cdts,
    output logic                      [DCRD_WD-1:0]               out_ded_fc_d_cdts,
    output logic                      [HCRD_WD-1:0]               out_shr_fc_h_cdts,
    output logic                      [DCRD_WD-1:0]               out_shr_fc_d_cdts,
    output logic                      [1:0]                       out_prev_remainder_h, 
    output logic                      [1:0]                       out_prev_remainder_d, 
    
    output logic                                                  out_pm_no_fc_credit,
    output logic                                                  out_pm_had_enough_credit,
    output logic                                                  out_rtlh_all_type_infinite
);

localparam THIS_FC = 0;
localparam CPL_MRG_FC = 1;

wire                vc_ready = in_rtlh_fc_init_status && (cfg_vc_enable || VC==0); // VC0 is never disabled

logic [1:0][DCRD_WD-1:0] int_consume_d;
logic [1:0][HCRD_WD-1:0] int_consume_h;


logic [1:0][DCRD_WD-1:0] c_limit_d,                         r_limit_d;
logic [1:0][HCRD_WD-1:0] c_limit_h,                         r_limit_h;
logic [1:0]              c_infinite_d,                      r_infinite_d;
logic [1:0]              c_infinite_h,                      r_infinite_h;
logic [1:0]              c_zero_d,                          r_zero_d;
logic [1:0]              c_zero_h,                          r_zero_h;
logic [1:0]              c_merged,                          r_merged;
logic [1:0][1:0]         c_scale_init_d,                    r_scale_init_d;
logic [1:0][1:0]         c_scale_init_h,                    r_scale_init_h;
logic [1:0][1:0]         c_scale_h,                         r_scale_h;
logic [1:0][1:0]         c_scale_d,                         r_scale_d;
logic [1:0][DCRD_WD-1:0] c_avail_d,                         r_avail_d;
logic [1:0][HCRD_WD-1:0] c_avail_h,                         r_avail_h;
logic [1:0][DCRD_WD-1:0] c_cnsmd_d,                         r_cnsmd_d;
logic [1:0][HCRD_WD-1:0] c_cnsmd_h,                         r_cnsmd_h;
logic [1:0][HCRD_WD-1:0] c_restore_h,                       r_restore_h;
logic [1:0][DCRD_WD-1:0] c_restore_d,                       r_restore_d;

logic [1:0][DCRD_WD-1:0] c_advert_delta_d,                  r_advert_delta_d;
logic [1:0][HCRD_WD-1:0] c_advert_delta_h,                  r_advert_delta_h;

logic [1:0][DCRD_WD-1:0] c_advert_delta_d_plus_restore_d,   r_advert_delta_d_plus_restore_d;
logic [1:0][HCRD_WD-1:0] c_advert_delta_h_plus_restore_h,   r_advert_delta_h_plus_restore_h;

logic [1:0]              c_ovfl_h,                          r_ovfl_h;
logic [1:0]              c_ovfl_d,                          r_ovfl_d;

logic[2:0]               next_remainder_h;
logic[2:0]               next_remainder_d;

/////////////////////////////////////////////////////////////////////////
// STEP1 :
// Update internal status (available credits, limits, restore, infinite...)
/////////////////////////////////////////////////////////////////////////
logic[1:0][13:0] co_notok;
logic[1:0][ 7:0] co_ok;
always_comb begin
    // Initialise;
    c_limit_d                       = r_limit_d;
    c_limit_h                       = r_limit_h;
    c_infinite_d                    = r_infinite_d;
    c_infinite_h                    = r_infinite_h;
    c_zero_d                        = r_zero_d;
    c_zero_h                        = r_zero_h;
    c_merged                        = r_merged;
    c_scale_init_d                  = r_scale_init_d;
    c_scale_init_h                  = r_scale_init_h;
    c_scale_h                       = r_scale_h;
    c_scale_d                       = r_scale_d;
    c_avail_d                       = r_avail_d;
    c_avail_h                       = r_avail_h;
    c_cnsmd_d                       = r_cnsmd_d;
    c_cnsmd_h                       = r_cnsmd_h;
    c_restore_h                     = '0;
    c_restore_d                     = '0;
    c_advert_delta_d                = '0;
    c_advert_delta_h                = '0;
    c_advert_delta_d_plus_restore_d = '0;
    c_advert_delta_h_plus_restore_h = '0;
    co_ok                           = '0;
    co_notok                        = '0;

    for(int u = 0; u < 2; u++)begin

        // RESTORE LOGIC FROM INTERNAL RESTORE.
        // Dedicated restore (u==0 --> DEDICATED)
        if(u==DED)begin
            {co_notok[u][0],c_restore_h[u]} = {1'b0, c_restore_h[u]} + {1'b0, in_internal_restore[u].hcrd};
            {co_notok[u][1],c_restore_d[u]} = {1'b0, c_restore_d[u]} + {1'b0, in_internal_restore[u].dcrd};
        end 
        // Shared restore (u==1 --> SHARED)
        else if(in_flit_mode_enabled)begin
            // Increase the shared credits if the combination of next_remainder (sum of the natural remainder and the remainder coming from restore credits) 
            // is reaching the granularity.
            // Note that next_remainder will never reach the granularity (and therefore we never increment the shared credit) without some
            // credits coming from the restore interface.
            {co_notok[u][2],c_restore_h[u]} = {1'b0, c_restore_h[u]} + {1'b0,               in_internal_restore[u].hcrd[HCRD_WD-1:2], 2'b00};
            {co_notok[u][3],c_restore_h[u]} = {1'b0, c_restore_h[u]} + {{HCRD_WD-2{1'b0}},  next_remainder_h[2],                      2'b00};
            {co_notok[u][5],c_restore_d[u]} = {1'b0, c_restore_d[u]} + {1'b0,               in_internal_restore[u].dcrd[DCRD_WD-1:2], 2'b00};
            {co_notok[u][6],c_restore_d[u]} = {1'b0, c_restore_d[u]} + {{DCRD_WD-2{1'b0}},  next_remainder_d[2],                      2'b00};
        end
        
        // UPDATE LOGIC FROM RTLH
        //
        // Update: scale_init/scale/infinite/zero/merged/limit with what has been received from RTLH
        // The update happens only for Shared or Dedicated, depending on what has been received
        // Note that Merged is sampled only for Data as - when merged - both Hdr and Data must be merged (so one is enough)
        if((in_update.is_for_shared && (u==SHR)) || (!in_update.is_for_shared && (u==DED)))begin
            c_scale_init_h[u]   = (in_update.is_fcinit12) ? in_update.h_scale_value : c_scale_init_h[u];
            c_scale_init_d[u]   = (in_update.is_fcinit12) ? in_update.d_scale_value : c_scale_init_d[u];
            // CPL updates are never in OptimisedUpdateFC, and normal UpdateFC
            // always have a scale factor, so:
            // - for shared updateFC_CPL, hd_scale=1 by definition (as we can't have scale=2'b00 in shared case)
            // - for dedicated updateFC_CPL, u==DED is always true
            // So the only (no scale+shared) is possible for OptimisedFC 
            c_scale_h[u]        = in_update.hd_scale ? in_update.h_scale_value : (u==DED || FC_TYPE == E_CPL) ? c_scale_h[u] : in_shr_consolidated_init_scale_h; 
            c_scale_d[u]        = in_update.hd_scale ? in_update.d_scale_value : (u==DED || FC_TYPE == E_CPL) ? c_scale_d[u] : in_shr_consolidated_init_scale_d;
            
            if(in_update.d_limit)begin
                c_infinite_d[u] = (in_update.is_fcinit12) ? (in_update.d_is_infinite) : c_infinite_d[u];    //sample infinite only at initialisation
                c_zero_d[u]     = (in_update.is_fcinit12) ? (in_update.d_is_zero)     : c_zero_d[u];        //sample zero only at initialisation
                c_merged[u]     = (in_update.is_fcinit12) ? (in_update.cpl_is_merged) : c_merged[u];        //sample merged only at initialisation
                c_limit_d[u]    = (c_scale_d[u]==2'b11)   ? {          in_update.d_limit_value, 4'b0000} : 
                                  (c_scale_d[u]==2'b10)   ? {   2'b00, in_update.d_limit_value, 2'b00  } : 
                                                            { 4'b0000, in_update.d_limit_value         };
            end
            if(in_update.h_limit)begin
                c_infinite_h[u] = (in_update.is_fcinit12) ? (in_update.h_is_infinite) : c_infinite_h[u];    //sample infinite only at initialisation
                c_zero_h[u]     = (in_update.is_fcinit12) ? (in_update.h_is_zero)     : c_zero_h[u];        //sample zero only at initialisation
                c_limit_h[u]    = (c_scale_h[u]==2'b11)   ? {          in_update.h_limit_value, 4'b0000} : 
                                  (c_scale_h[u]==2'b10)   ? {   2'b00, in_update.h_limit_value, 2'b00  } : 
                                                            { 4'b0000, in_update.h_limit_value         };
            end
        end 

        // Calculate the Adverised credits from the new Limit for D and H
        case(c_scale_d[u])
            2'b11:    {co_ok[u][0],c_advert_delta_d[u]} = {   1'b0, c_limit_d[u][15:0]} - {   1'b0, r_limit_d[u][15:0]};
            2'b10:    c_advert_delta_d[u]               = {  2'b00, c_limit_d[u][13:0]} - {  2'b00, r_limit_d[u][13:0]};
            default:  c_advert_delta_d[u]               = {4'b0000, c_limit_d[u][11:0]} - {4'b0000, r_limit_d[u][11:0]};
        endcase
        case(c_scale_h[u])
            2'b11:    {co_ok[u][1],c_advert_delta_h[u]} = {   1'b0, c_limit_h[u][11:0]} - {   1'b0, r_limit_h[u][11:0]};
            2'b10:    c_advert_delta_h[u]               = {  2'b00, c_limit_h[u][ 9:0]} - {  2'b00, r_limit_h[u][ 9:0]};
            default:  c_advert_delta_h[u]               = {4'b0000, c_limit_h[u][ 7:0]} - {4'b0000, r_limit_h[u][ 7:0]};
        endcase
        
        // From the registered Advertised credits from new Limit and the
        // restored credits, calculate the total number of credits to add
        case(c_scale_d[u])
            2'b11:   {co_notok[u][8],c_advert_delta_d_plus_restore_d[u]} = {1'b0,          r_advert_delta_d[u][15:0]} + {1'b0, r_restore_d[u]}; 
            2'b10:   {co_notok[u][8],c_advert_delta_d_plus_restore_d[u]} = {1'b0,   2'b00, r_advert_delta_d[u][13:0]} + {1'b0, r_restore_d[u]}; 
            default: {co_notok[u][8],c_advert_delta_d_plus_restore_d[u]} = {1'b0, 4'b0000, r_advert_delta_d[u][11:0]} + {1'b0, r_restore_d[u]}; 
        endcase
        
        case(c_scale_h[u])
            2'b11:   {co_notok[u][9],c_advert_delta_h_plus_restore_h[u]} = {1'b0,          r_advert_delta_h[u][11:0]} + {1'b0, r_restore_h[u]}; 
            2'b10:   {co_notok[u][9],c_advert_delta_h_plus_restore_h[u]} = {1'b0,   2'b00, r_advert_delta_h[u][ 9:0]} + {1'b0, r_restore_h[u]}; 
            default: {co_notok[u][9],c_advert_delta_h_plus_restore_h[u]} = {1'b0, 4'b0000, r_advert_delta_h[u][ 7:0]} + {1'b0, r_restore_h[u]}; 
        endcase
        
        // Update Avail D and H
        {c_ovfl_h[u],    c_avail_h[u]} = {1'b0, c_avail_h[u]} + {1'b0, r_advert_delta_h_plus_restore_h[u]};
        {c_ovfl_d[u],    c_avail_d[u]} = {1'b0, c_avail_d[u]} + {1'b0, r_advert_delta_d_plus_restore_d[u]};
        if(u==DED)begin
            {co_notok[u][11],c_avail_h[u]} = {1'b0, c_avail_h[u]} - {1'b0, int_consume_h[u]};
            {co_notok[u][13],c_avail_d[u]} = {1'b0, c_avail_d[u]} - {1'b0, int_consume_d[u]};
        end else begin
            {co_ok[u][6],c_avail_h[u]}     = {1'b0, c_avail_h[u]} - {1'b0, int_consume_h[u]};
            {co_ok[u][7],c_avail_d[u]}     = {1'b0, c_avail_d[u]} - {1'b0, int_consume_d[u]};
        end
        
        // Update Consumed D and H
        {co_ok[u][2],c_cnsmd_d[u]} = {1'b0, c_cnsmd_d[u]} + {1'b0, int_consume_d[u]};
        {co_ok[u][3],c_cnsmd_d[u]} = {1'b0, c_cnsmd_d[u]} - {1'b0, r_restore_d[u]  };
        {co_ok[u][4],c_cnsmd_h[u]} = {1'b0, c_cnsmd_h[u]} + {1'b0, int_consume_h[u]};
        {co_ok[u][5],c_cnsmd_h[u]} = {1'b0, c_cnsmd_h[u]} - {1'b0, r_restore_h[u]  };
    end
end

wire[1:0]   clear_counters;
assign      clear_counters[DED] = rdlh_link_down || !(cfg_vc_enable || VC==0);
assign      clear_counters[SHR] = rdlh_link_down; // Do not reset shr counters when a VC1-7 is disabled, and VC0 is never disabled 
always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        r_limit_d       <= #TP '0;
        r_limit_h       <= #TP '0;
        r_infinite_d    <= #TP '0;
        r_infinite_h    <= #TP '0;
        r_zero_d        <= #TP '0;
        r_zero_h        <= #TP '0;
        r_merged        <= #TP '0;
        r_scale_d       <= #TP '0;
        r_scale_h       <= #TP '0;
        r_scale_init_d  <= #TP '0;
        r_scale_init_h  <= #TP '0;
        r_avail_d       <= #TP '0;
        r_avail_h       <= #TP '0;
        r_cnsmd_h       <= #TP '0;
        r_cnsmd_d       <= #TP '0;
        r_restore_h     <= #TP '0;
        r_restore_d     <= #TP '0;
        r_advert_delta_h <= #TP '0;
        r_advert_delta_d <= #TP '0;
        r_advert_delta_h_plus_restore_h <= #TP '0;
        r_advert_delta_d_plus_restore_d <= #TP '0;
        r_ovfl_h                        <= #TP '0;
        r_ovfl_d                        <= #TP '0;
    end else begin
        for(int u = 0; u < 2; u++)begin
            // In case we are a Merged CPL Credit Bank, and we are analysing SHR credits, then consider ourselves infinite if we are merged to an infinite Posted credits pool
            r_infinite_d[u]                    <= #TP (clear_counters[u]) ? '0 : ((u==SHR && FC_TYPE==E_CPL && out_p_cpl_merged) ? in_shr_p_is_infinite_d : c_infinite_d[u]);
            r_infinite_h[u]                    <= #TP (clear_counters[u]) ? '0 : ((u==SHR && FC_TYPE==E_CPL && out_p_cpl_merged) ? in_shr_p_is_infinite_h : c_infinite_h[u]);
            r_zero_d[u]                        <= #TP (clear_counters[u]) ? '0 : c_zero_d[u];
            r_zero_h[u]                        <= #TP (clear_counters[u]) ? '0 : c_zero_h[u];
            r_merged[u]                        <= #TP (clear_counters[u]) ? '0 : c_merged[u];
            r_scale_d[u]                       <= #TP (clear_counters[u]) ? '0 : c_scale_d[u];
            r_scale_h[u]                       <= #TP (clear_counters[u]) ? '0 : c_scale_h[u];
            r_scale_init_d[u]                  <= #TP (clear_counters[u]) ? '0 : c_scale_init_d[u];
            r_scale_init_h[u]                  <= #TP (clear_counters[u]) ? '0 : c_scale_init_h[u];
            r_restore_h[u]                     <= #TP (clear_counters[u]) ? '0 : c_restore_h[u];
            r_restore_d[u]                     <= #TP (clear_counters[u]) ? '0 : c_restore_d[u];
            r_avail_h[u]                       <= #TP (clear_counters[u]) ? '0 : c_infinite_h[u] ? '1 : c_avail_h[u];
            r_avail_d[u]                       <= #TP (clear_counters[u]) ? '0 : c_infinite_d[u] ? '1 : c_avail_d[u];
            // All others (cnmd, limit, advert) are 0 Limit value must be ignored in those cases.
            r_cnsmd_h[u]                       <= #TP (clear_counters[u] || c_infinite_h[u]) ? '0 : c_cnsmd_h[u];
            r_cnsmd_d[u]                       <= #TP (clear_counters[u] || c_infinite_d[u]) ? '0 : c_cnsmd_d[u];
            r_limit_h[u]                       <= #TP (clear_counters[u] || c_infinite_h[u]) ? '0 : c_limit_h[u];
            r_limit_d[u]                       <= #TP (clear_counters[u] || c_infinite_d[u]) ? '0 : c_limit_d[u];
            r_advert_delta_h[u]                <= #TP (clear_counters[u] || c_infinite_h[u]) ? '0 : c_advert_delta_h[u];
            r_advert_delta_d[u]                <= #TP (clear_counters[u] || c_infinite_d[u]) ? '0 : c_advert_delta_d[u];
            r_advert_delta_h_plus_restore_h[u] <= #TP (clear_counters[u] || c_infinite_h[u]) ? '0 : c_advert_delta_h_plus_restore_h[u];
            r_advert_delta_d_plus_restore_d[u] <= #TP (clear_counters[u] || c_infinite_d[u]) ? '0 : c_advert_delta_d_plus_restore_d[u];
            r_ovfl_h[u]                        <= #TP (clear_counters[u] || c_infinite_h[u]) ? '0 : c_ovfl_h[u];
            r_ovfl_d[u]                        <= #TP (clear_counters[u] || c_infinite_d[u]) ? '0 : c_ovfl_d[u];
        end
    end
end



/////////////////////////////////////////////////////////////////////////
// STEP 2: Output of some status information for PM/top level/Optional checks.,,
/////////////////////////////////////////////////////////////////////////
wire [3:0]         max_np_payload_credits       = (cfg_can_transmit_dmwr) ? ((`CX_DEF_MEM_WR_LEN_SUPP == 2'b00)? 4'd4 : 4'd8) : cfg_can_transmit_atomic ? 4'd2 : 4'd1;
wire [DCRD_WD-1:0] max_p_cpl_payload_credits    = {{DCRD_WD-12{1'b0}},(12'h8 << cfg_max_payload_size) & 12'b0001_1111_1000};
wire [DCRD_WD-1:0] max_payload_credits          = (FC_TYPE==E_NP) ? {{DCRD_WD-4{1'b0}},max_np_payload_credits} : max_p_cpl_payload_credits;

// there is no credit when there is no Dedicated AND there is no shared
assign out_pm_no_fc_credit  = (r_avail_h[DED] == '0 && r_avail_d[DED] == '0) &&
                              (in_shr_total_h=='0 && in_shr_total_d == '0);

// Enough credit to enter L1?
wire enough_h = (                        r_zero_h[DED])                            ? in_shr_total_h != '0 :                         // FM with zero ded --> check shared for ALL VCs (note: when CPLs are merged, this total is from P credits)
                (in_flit_mode_enabled && (r_infinite_h[SHR] || r_infinite_h[DED])) ? 1'b1 :                                         // FM with infinite ded or infinite shr --> go on, no issue
                (in_flit_mode_enabled)                                             ? r_avail_h[DED] != '0 :                         // FM all other cases (non zero dedicated, non infinite, non merged), --> check dedicated 
                (r_infinite_h[DED])                                                ? 1'b1 :                                         // NFM with infinite dedicated --> go on
                                                                                     r_avail_h[DED] != '0;                          // NFM without infinite dedicated --> check dedicated

wire enough_d = (                        r_zero_d[DED])                            ? in_shr_total_d >= max_payload_credits :        // FM with zero ded --> check shared for ALL VCs (note: when CPLs are merged, this total is from P credits)
                (in_flit_mode_enabled && (r_infinite_d[SHR] || r_infinite_d[DED])) ? 1'b1 :                                         // FM with infinite ded or infinite shr --> go on, no issue
                (in_flit_mode_enabled)                                             ? r_avail_d[DED] >= max_payload_credits :        // FM all other cases (non zero dedicated, non infinite, non merged), --> check dedicated 
                (r_infinite_d[DED])                                                ? 1'b1 :                                         // NFM with infinite dedicated --> go on
                                                                                     r_avail_d[DED] >= max_payload_credits;         // NFM without infinite dedicated --> check dedicated

assign out_pm_had_enough_credit   = !(cfg_vc_enable || VC==0) || (enough_d && enough_h);

// I will never receive ded fc update if my dedicated credits are infinite 
// I will never receive shr fc update if my shared credits are infinite 
// I will never receive fc update if I will never receive ded upds && never receive shr upd
wire will_never_receive_ded_fc_upd = (r_infinite_h[DED] && r_infinite_d[DED]); 
wire will_never_receive_shr_fc_upd = !in_flit_mode_enabled  || (r_infinite_h[SHR] && r_infinite_d[SHR]);
assign out_rtlh_all_type_infinite = will_never_receive_shr_fc_upd && will_never_receive_ded_fc_upd;

assign out_init_scale_h    = r_scale_init_h;
assign out_init_scale_d    = r_scale_init_d;
assign out_init_infinite_h = r_infinite_h;
assign out_init_infinite_d = r_infinite_d;
assign out_init_zero_h     = r_zero_h;
assign out_init_zero_d     = r_zero_d;
// A Receiver must never cumulatively issue more outstanding unused data or header to the Transmitter than the Max Credits values
wire  c_ded_unused_cr_err_h =   (((r_scale_h[DED] == 2'b11)                                 && ({r_ovfl_h[DED],r_avail_h[DED]} >= 13'h7f1)) || 
                                 ((r_scale_h[DED] == 2'b10)                                 && ({r_ovfl_h[DED],r_avail_h[DED]} >= 13'h1fd)) || 
                                 (((r_scale_h[DED] == 2'b01) || (r_scale_h[DED]== 2'b00))   && ({r_ovfl_h[DED],r_avail_h[DED]} >= 13'h80)))
                                && !r_infinite_h[DED];
wire  c_ded_unused_cr_err_d =   (((r_scale_d[DED] == 2'b11)                                 && ({r_ovfl_d[DED],r_avail_d[DED]} >= 17'h7ff1)) || 
                                 ((r_scale_d[DED] == 2'b10)                                 && ({r_ovfl_d[DED],r_avail_d[DED]} >= 17'h1ffd)) || 
                                 (((r_scale_d[DED] == 2'b01) || (r_scale_d[DED] == 2'b00))  && ({r_ovfl_d[DED],r_avail_d[DED]} >= 17'h800))) 
                                && !r_infinite_d[DED];
logic r_ded_unused_cr_err;
wire ded_unused_cr_err         = (c_ded_unused_cr_err_h || c_ded_unused_cr_err_d) && !r_ded_unused_cr_err;
always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        r_ded_unused_cr_err <= #TP 1'b0;
        out_fc_prot_err     <= #TP 1'b0;
    end else begin
        r_ded_unused_cr_err <= #TP (!(cfg_vc_enable || VC==0) || rdlh_link_down) ? 1'b0 : (c_ded_unused_cr_err_h || c_ded_unused_cr_err_d);
         // only dedicated, for shared it's done in the xadm_fc_crd_shared.
         // However for shared, check that this SINGLE UpdateFC didn't advertise more than the max. 
         // For dedicated, this error is caught extending the check above on 13/17 bits.
         // For shared, since they can go "negative", this check needs to be done here separately.
         // Note that if the single UpdateFC is less than the max, but there is still an overflow, this would be detected by
         // xadm_fc_crdt_shared, as the result would still be on 12/16 bits.
         // The only case where 13/17 are needed is when a SINGLE UpdateFC adds more than the max
        out_fc_prot_err     <= #TP ded_unused_cr_err || 
            (r_scale_h[SHR]==2'b11 && r_advert_delta_h[SHR] >= 12'h7f1 ) || 
            (r_scale_d[SHR]==2'b11 && r_advert_delta_d[SHR] >= 16'h7ff1); 
    end
end

assign out_ded_fc_cnsmd_d = r_cnsmd_d[DED];
assign out_ded_fc_cnsmd_h = r_cnsmd_h[DED];
assign out_ded_fc_limit_d = r_limit_d[DED];
assign out_ded_fc_limit_h = r_limit_h[DED];
assign out_shr_fc_cnsmd_d = r_cnsmd_d[SHR];
assign out_shr_fc_cnsmd_h = r_cnsmd_h[SHR];
assign out_shr_fc_limit_d = r_limit_d[SHR];
assign out_shr_fc_limit_h = r_limit_h[SHR];
assign out_ded_fc_h_cdts = r_avail_h[DED];
assign out_ded_fc_d_cdts = r_avail_d[DED];
assign out_shr_fc_h_cdts = r_avail_h[SHR];
assign out_shr_fc_d_cdts = r_avail_d[SHR];

/////////////////////////////////////////////////////////////////////////
// GRANT LOGIC - using registered avail and producing int_consume_h/d
/////////////////////////////////////////////////////////////////////////
logic [N-1:0][DCRD_N_WD-1:0]    tot_requested_d;
logic [N-1:0][HCRD_N_WD-1:0]    tot_requested_h;
logic[N-1:0] ded_pass,r_ded_pass;
logic[N-1:0][1:0] co_notok2;
always_comb begin
    co_notok2 ='0;
    
    tot_requested_h    = '0;
    tot_requested_d    = '0;
    int_consume_h      = '0;
    int_consume_d      = '0;

    // How much shared to consume? Directly from input. These values are already qualified.
    int_consume_h[SHR] = in_shr_consume_h;
    int_consume_d[SHR] = in_shr_consume_d;
    
    for(int i = 0; i < N; i++)begin
        {co_notok2[i][1],tot_requested_h[i]} = {1'b0,tot_requested_h[i]} + (in_shr_pass[i]? '0 : {{1+HCRD_N_WD-HCRD_SINGLE_WD{1'b0}},3'b000,in_req[i]});
        {co_notok2[i][0],tot_requested_d[i]} = {1'b0,tot_requested_d[i]} + (in_shr_pass[i]? '0 : {{1+DCRD_N_WD-DCRD_SINGLE_WD{1'b0}},in_req_dcrd[i]});
        
        // if halt from pipeline, I don't care about pass, as long as I don't update consume counters
        ded_pass[i] = in_req[i] && !in_shr_pass[i] && (in_flush || (vc_ready && ({{DCRD_WD-DCRD_N_WD{1'b0}},tot_requested_d[i]} <= r_avail_d[DED]) && ({{HCRD_WD-HCRD_N_WD{1'b0}},tot_requested_h[i]} <= r_avail_h[DED])));
        if(ded_pass[i] && !in_flush && !in_halt[i])begin
            int_consume_d[DED] = {{DCRD_WD-DCRD_N_WD{1'b0}}, tot_requested_d[i]};
            int_consume_h[DED] = {{HCRD_WD-HCRD_N_WD{1'b0}}, tot_requested_h[i]};
        end
        
        out_pass[i] = ded_pass[i] || in_shr_pass[i];
    end
end



// Reminder counters for this FC Type
// The next remainder depends on: 1) the restored credits and 2) the previous remainder
// the chain is:
// - out_prev_remainder (flop) --> 
// - xadm_fc_crd_shrd calculating the new remainder based on requests (in_next_remainder) -->
// - the in_next_remainder is added to the remainder coming from restored credits (next_remainder) -->
// - use this "total" new_remainder to:
//      1) its lower bits (the real remainder) will be the next registered remainder
//      2) its upper bits (the carry) will cause the restore logic to restore credits
//      Note that the carry position depends on the granularity
assign next_remainder_h = (!in_flit_mode_enabled || r_infinite_h[SHR]) ? '0 : ({1'b0, in_internal_restore[SHR].hcrd[1:0]} + {1'b0, in_next_remainder_h});
assign next_remainder_d = (!in_flit_mode_enabled || r_infinite_d[SHR]) ? '0 : ({1'b0, in_internal_restore[SHR].dcrd[1:0]} + {1'b0, in_next_remainder_d});

always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        out_prev_remainder_h        <= #TP '0;
        out_prev_remainder_d        <= #TP '0;
        r_ded_pass                  <= #TP '0;
    end else begin
        // Do not pass uppermost bit to xadm_fc_crdt_shared. 
        // The uppermost bit might overflow due to the restore credit logic.
        // This is accounted for above, where it will increment the available credit.
        // If we both pass it to the xadm_fc_crdt_shared logic AND we use it
        // to increase available credit, we account for it twice 
        out_prev_remainder_h        <= #TP (rdlh_link_down) ? '0 : next_remainder_h[1:0];
        out_prev_remainder_d        <= #TP (rdlh_link_down) ? '0 : next_remainder_d[1:0];
        for(int i = 0; i < N; i++)begin
            r_ded_pass[i]           <= #TP in_req[i] ? ded_pass[i] : r_ded_pass[i];
        end
    end
end

always_comb begin
    for(int i = 0; i < N; i++)begin
        out_used_dedicated_credit[i] = in_flush ? 1'b0 : in_req[i] ? ded_pass[i] : r_ded_pass[i];
    end
end
assign out_p_cpl_merged = r_merged[SHR];


endmodule

