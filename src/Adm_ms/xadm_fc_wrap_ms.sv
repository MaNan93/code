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
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xadm_fc_wrap_ms.sv#6 $
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

module xadm_fc_wrap_ms
import DWC_pcie_ctl_pkg::HCRD_WD;
import DWC_pcie_ctl_pkg::DCRD_WD;
import DWC_pcie_ctl_pkg::NVC;
import DWC_pcie_ctl_pkg::N_XADM_IF;
import DWC_pcie_ctl_pkg::N_XADM_P_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_NP_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_CPL_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_CUMULATIVE_PER_VC;
import DWC_pcie_ctl_pkg::RX_NDLLP;
import DWC_pcie_core_pkg::xadm_pkt_t;
import DWC_pcie_core_pkg::rtlh_rfc_t;
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
import xadm_ms_pkg::xadm_restore_fc_crdt_t;
import xadm_ms_pkg::xadm_fc_update_t;
import pcie_pkg::E_P;
import pcie_pkg::E_NP;
import pcie_pkg::E_CPL;
import pcie_pkg::fc_type_e;
#(
    parameter RAS_DP_PROT_CHK_ID_BASE = 0
)

                      (
    
    input logic                                               clk,
    input logic                                               rst_n,
    
    input logic                       [NVC-1:0][2:0]          cfg_vc_id,
    input logic                       [NVC-1:0]               cfg_vc_enable,
    input logic                                               cfg_fc_scaled_en,
    input logic                       [2:0]                   cfg_max_payload_size,
    input logic                                               cfg_can_transmit_atomic,
    input logic                                               cfg_can_transmit_dmwr,
    
    input logic                                               rdlh_link_down,
    input logic                                               in_flush,
    input logic                                               smlh_flit_mode_enable,
    
    // Update packets from RTLH
    input logic                       [NVC-1:0]               in_rtlh_fc_init_status,
    input rtlh_rfc_t                                          in_rtlh_rfc,
    
    input xadm_restore_fc_crdt_t [NVC-1:0][2:0][1:0]          in_internal_restore,
    
    output logic                      [NVC-1:0][HCRD_WD-1:0]  out_fc_cnsmd_ph,
    output logic                      [NVC-1:0][DCRD_WD-1:0]  out_fc_cnsmd_pd,
    output logic                      [NVC-1:0][HCRD_WD-1:0]  out_fc_limit_ph,
    output logic                      [NVC-1:0][DCRD_WD-1:0]  out_fc_limit_pd,
    output logic                      [NVC-1:0][HCRD_WD-1:0]  out_fc_cnsmd_nph,
    output logic                      [NVC-1:0][DCRD_WD-1:0]  out_fc_cnsmd_npd,
    output logic                      [NVC-1:0][HCRD_WD-1:0]  out_fc_limit_nph,
    output logic                      [NVC-1:0][DCRD_WD-1:0]  out_fc_limit_npd,
    output logic                      [NVC-1:0][HCRD_WD-1:0]  out_fc_cnsmd_cplh,
    output logic                      [NVC-1:0][DCRD_WD-1:0]  out_fc_cnsmd_cpld,
    output logic                      [NVC-1:0][HCRD_WD-1:0]  out_fc_limit_cplh,
    output logic                      [NVC-1:0][DCRD_WD-1:0]  out_fc_limit_cpld,
    output logic                      [NVC-1:0][HCRD_WD-1:0]  out_fc_ph_cdts,
    output logic                      [NVC-1:0][DCRD_WD-1:0]  out_fc_pd_cdts,
    output logic                      [NVC-1:0][HCRD_WD-1:0]  out_fc_nph_cdts,
    output logic                      [NVC-1:0][DCRD_WD-1:0]  out_fc_npd_cdts,
    output logic                      [NVC-1:0][HCRD_WD-1:0]  out_fc_cplh_cdts,
    output logic                      [NVC-1:0][DCRD_WD-1:0]  out_fc_cpld_cdts,
    output logic                               [HCRD_WD-1:0]  out_fc_ph_shrd_cdts,  
    output logic                               [DCRD_WD-1:0]  out_fc_pd_shrd_cdts,  
    output logic                               [HCRD_WD-1:0]  out_fc_nph_shrd_cdts, 
    output logic                               [DCRD_WD-1:0]  out_fc_npd_shrd_cdts, 
    output logic                               [HCRD_WD-1:0]  out_fc_cplh_shrd_cdts,
    output logic                               [DCRD_WD-1:0]  out_fc_cpld_shrd_cdts,
    
    output logic                      [NVC-1:0]               out_pm_no_fc_credit,        // means there is 0 credit for P && NP && CPL. Can be ANded with shared, as to really have 0 credits means that you have 0 dedicated and 0 shared
    output logic                      [NVC-1:0]               out_pm_had_enough_credit,   // means there was enough P && NP && CPL or the VC was disabled. Can be ORed between shared and dedicated, as it is enough that a TLP can be transmitter using either dedicated or shared
    output logic                                              out_rtlh_all_type_infinite, // means all types are infinite, can be ORed between shared and dedicated as it is enough to have one infinite
    
    output logic                                              out_fc_prot_err,
    input xadm_pkt_t                  [N_XADM_IF-1:0]         in_pkt,
    output logic                      [N_XADM_IF-1:0]         out_halt,
    
    output xadm_pkt_t [N_XADM_IF-1:0]                         out_pkt,
    input logic       [N_XADM_IF-1:0]                         in_halt
    ,
    input  ras_dp_err_inj_t                                   ras_dp_err_inj
    ,
    output ras_dp_err_log_t [N_XADM_IF-1:0]                   ras_dp_err_log
);
localparam int FC_PIPE_FOR_P_CPL = 0 +1;
localparam int FC_PIPE_FOR_NP    = 0 +1;
localparam int DCRD_SINGLE_WD    = $clog2(1024/4+1);
localparam int DED               = 0;
localparam int SHR               = 1;
localparam RAS_CORRECTION_EN      = 0;
localparam CPLQ_MANAGEMENT_ENABLE = 0;
localparam LOCAL_FC_PRFX          = 0 +1;
localparam IDE_ENABLE             = 0;

// FC RAS Checkers are present only if :
//  - Local FC Prefix, CPL Queue Mgr and IDE are not present
//  - RAS Protection type is ECC with Correction enabled
localparam N_XADM_FC_CHK = (((LOCAL_FC_PRFX == 0) && (CPLQ_MANAGEMENT_ENABLE == 0) && (IDE_ENABLE == 0)) || (RAS_CORRECTION_EN == 1))? 1 : 0;

logic [N_XADM_IF-1:0]                       in_halt_int,ord_in_halt_int;
logic [N_XADM_IF-1:0]                       prev_stage_halt;

logic [N_XADM_IF-1:0]                       reqs;
logic [N_XADM_IF-1:0][DCRD_SINGLE_WD-1:0]   reqs_dcrd;
logic [N_XADM_IF-1:0]                       ord_reqs;
logic [N_XADM_IF-1:0][DCRD_SINGLE_WD-1:0]   ord_reqs_dcrd;


xadm_fc_update_t [NVC-1:0][2:0]             fc_update;
logic            [NVC-1:0][2:0]             pm_no_fc_credit;
logic            [NVC-1:0][2:0]             pm_had_enough_credit;
logic            [NVC-1:0][2:0]             rtlh_all_type_infinite;

logic [NVC-1:0][2:0][HCRD_WD-1:0]           shr_consume_h;
logic [NVC-1:0][2:0][DCRD_WD-1:0]           shr_consume_d;
logic [2:0][HCRD_WD-1:0]                    shr_total_h;
logic [2:0][DCRD_WD-1:0]                    shr_total_d;

logic [NVC-1:0][2:0][HCRD_WD-1:0]           shr_fc_cnsmd_h;
logic [NVC-1:0][2:0][DCRD_WD-1:0]           shr_fc_cnsmd_d;
logic [NVC-1:0][2:0][HCRD_WD-1:0]           shr_fc_limit_h;
logic [NVC-1:0][2:0][DCRD_WD-1:0]           shr_fc_limit_d;
logic [NVC-1:0][2:0][HCRD_WD-1:0]           shr_fc_h_cdts;
logic [NVC-1:0][2:0][DCRD_WD-1:0]           shr_fc_d_cdts;
logic [NVC-1:0][2:0][HCRD_WD-1:0]           ded_fc_cnsmd_h;
logic [NVC-1:0][2:0][DCRD_WD-1:0]           ded_fc_cnsmd_d;
logic [NVC-1:0][2:0][HCRD_WD-1:0]           ded_fc_limit_h;
logic [NVC-1:0][2:0][DCRD_WD-1:0]           ded_fc_limit_d;
logic [NVC-1:0][2:0][HCRD_WD-1:0]           ded_fc_h_cdts;
logic [NVC-1:0][2:0][DCRD_WD-1:0]           ded_fc_d_cdts;


logic [2:0][1:0]                            shr_consolidated_init_scale_h;
logic [2:0][1:0]                            shr_consolidated_init_scale_d;
logic [NVC-1:0][2:0][1:0][1:0]              init_scale_h;
logic [NVC-1:0][2:0][1:0][1:0]              init_scale_d;
logic [NVC-1:0][2:0][1:0]                   init_zero_h;
logic [NVC-1:0][2:0][1:0]                   init_zero_d;
logic                                       fc_prot_err1;
logic [NVC-1:0][2:0]                        fc_prot_err2;
logic                                       fc_prot_err3;
logic [NVC-1:0][2:0][1:0]                   init_infinite_h;
logic [NVC-1:0][2:0][1:0]                   init_infinite_d;

logic [N_XADM_IF-1:0]                       ord_used_ded_credit,used_ded_credit;
logic [N_XADM_IF-1:0]                       pass,ord_pass;
logic [N_XADM_IF-1:0]                       ord_shr_pass;
logic [NVC-1:0][2:0][1:0]                   next_remainder_h;
logic [NVC-1:0][2:0][1:0]                   next_remainder_d;
logic [NVC-1:0][2:0][1:0]                   prev_remainder_h;
logic [NVC-1:0][2:0][1:0]                   prev_remainder_d;
logic [NVC-1:0][2:0]                        p_cpl_merged;

always_comb begin
    shr_consolidated_init_scale_h = '0;
    shr_consolidated_init_scale_d = '0;
    for(int vc = 0; vc < NVC; vc++)begin
        if(cfg_vc_enable[vc])begin
            // VC initialised with Zero (or Merged) are ignored, all others are assumed to have the same init_scale value
            shr_consolidated_init_scale_h[E_P  ] = (!init_zero_h[vc][E_P  ][SHR]) ? init_scale_h[vc][E_P  ][SHR] : shr_consolidated_init_scale_h[E_P  ];
            shr_consolidated_init_scale_h[E_NP ] = (!init_zero_h[vc][E_NP ][SHR]) ? init_scale_h[vc][E_NP ][SHR] : shr_consolidated_init_scale_h[E_NP ];
            shr_consolidated_init_scale_h[E_CPL] = (p_cpl_merged[0][E_CPL]) ? shr_consolidated_init_scale_h[E_P  ] : (!init_zero_h[vc][E_CPL][SHR]) ? init_scale_h[vc][E_CPL][SHR] : shr_consolidated_init_scale_h[E_CPL];
  
            shr_consolidated_init_scale_d[E_P  ] = (!init_zero_d[vc][E_P  ][SHR]) ? init_scale_d[vc][E_P  ][SHR] : shr_consolidated_init_scale_d[E_P  ];
            shr_consolidated_init_scale_d[E_NP ] = (!init_zero_d[vc][E_NP ][SHR]) ? init_scale_d[vc][E_NP ][SHR] : shr_consolidated_init_scale_d[E_NP ];
            shr_consolidated_init_scale_d[E_CPL] = (p_cpl_merged[0][E_CPL]) ? shr_consolidated_init_scale_d[E_P  ] : (!init_zero_d[vc][E_CPL][SHR]) ? init_scale_d[vc][E_CPL][SHR] : shr_consolidated_init_scale_d[E_CPL];
        end
    end
end
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n) out_fc_prot_err <= #`TP 1'b0;
    else       out_fc_prot_err <= #`TP fc_prot_err1 || |fc_prot_err2 || fc_prot_err3;
end

xadm_pkt_t[N_XADM_IF-1:0]                   in_pkt_int;

// Parse inbound FC DLLP and generate information, for each <VC,FC> credit
// bank, on how to update credits
xadm_fc_dllp_proc_ms

u_xadm_fc_dllp_proc_ms (
    .clk                                (clk                          ),
    .rst_n                              (rst_n                        ),
    .rdlh_link_down                     (rdlh_link_down               ),
    .in_rtlh_rfc                        (in_rtlh_rfc                  ),
    .cfg_vc_id                          (cfg_vc_id                    ),
    .cfg_vc_enable                      (cfg_vc_enable                ),
    .cfg_fc_scaled_en                   (cfg_fc_scaled_en             ),
    .in_flit_mode_enabled               (smlh_flit_mode_enable        ),
    .in_init_infinite_h                 (init_infinite_h              ),
    .in_init_infinite_d                 (init_infinite_d              ),
    .in_init_scale_h                    (init_scale_h                 ),
    .in_init_scale_d                    (init_scale_d                 ),
    .in_shr_consolidated_init_scale_h   (shr_consolidated_init_scale_h),
    .in_shr_consolidated_init_scale_d   (shr_consolidated_init_scale_d),
    .out_fc_prot_err                    (fc_prot_err1                 ),
    .out_update                         (fc_update                    )
);


generate
    assign out_rtlh_all_type_infinite = &(rtlh_all_type_infinite);
    //For each VC...
    for(genvar vc = 0; vc < NVC; vc++)begin : g_vc
        assign out_pm_no_fc_credit[vc]        = pm_no_fc_credit[vc][E_P] && pm_no_fc_credit[vc][E_NP] && pm_no_fc_credit[vc][E_CPL];
        assign out_pm_had_enough_credit[vc]   = pm_had_enough_credit[vc][E_P] && pm_had_enough_credit[vc][E_NP] && pm_had_enough_credit[vc][E_CPL];
        
        //For each FC...
        for(genvar fc = 0; fc < 3; fc++)begin : g_fc
            localparam fc_type_e FC    = fc_type_e'(fc);
            localparam           START = N_XADM_CUMULATIVE_PER_VC[vc] + (FC==E_P ? 0 : FC==E_NP ? N_XADM_P_IF_VC[vc] : N_XADM_P_IF_VC[vc]+N_XADM_NP_IF_VC[vc]);
            localparam           N_IF  = FC==E_P ? N_XADM_P_IF_VC[vc] : FC==E_NP ? N_XADM_NP_IF_VC[vc] : N_XADM_CPL_IF_VC[vc];
            localparam           PIPE  = (FC==E_P || FC==E_CPL) ? FC_PIPE_FOR_P_CPL : FC_PIPE_FOR_NP;
            for(genvar i = 0; i < N_IF; i++)begin : g_i
                
                assign reqs[START+i]      = in_pkt[START+i].hv;
                assign reqs_dcrd[START+i] = !in_pkt[START+i].support.has_payload ? '0 :
                        ((in_pkt[START+i].support.len_dw=='0 && `CX_MAX_MTU==4096) ? DCRD_SINGLE_WD'(1024/4) :
                        ({1'b0,in_pkt[START+i].support.len_dw[9:2]} + {8'd0, |in_pkt[START+i].support.len_dw[1:0]}));
                assign out_halt[START+i]  = in_halt_int[START+i] || prev_stage_halt[START+i];
                assign prev_stage_halt[START+i]           = reqs[START+i] && !pass[START+i];
            end
            
            if(N_IF==2) begin : g_order_2ifs
                logic [NVC-1:0][2:0] prio;
                assign prio[vc][fc]           = (in_pkt[START+0].order_seqnum==3'(in_pkt[START+1].order_seqnum+3'd1)) ? 1'b1 : 1'b0;
                assign ord_reqs[START+0]        = !prio[vc][fc] ? reqs[START+0] : reqs[START+1];
                assign ord_reqs[START+1]        = prio[vc][fc]  ? reqs[START+0] : reqs[START+1];
                assign ord_reqs_dcrd[START+0]   = !prio[vc][fc] ? reqs_dcrd[START+0] : reqs_dcrd[START+1];
                assign ord_reqs_dcrd[START+1]   = prio[vc][fc]  ? reqs_dcrd[START+0] : reqs_dcrd[START+1];
                assign ord_in_halt_int[START+0] = !prio[vc][fc] ? in_halt_int[START+0] : in_halt_int[START+1];
                assign ord_in_halt_int[START+1] = prio[vc][fc]  ? in_halt_int[START+0] : in_halt_int[START+1];
                assign pass[START+0]            = !prio[vc][fc] ? ord_pass[START+0] : ord_pass[START+1];
                assign pass[START+1]            = prio[vc][fc]  ? ord_pass[START+0] : ord_pass[START+1];
                assign used_ded_credit[START+0] = !prio[vc][fc] ? ord_used_ded_credit[START+0] : ord_used_ded_credit[START+1]; 
                assign used_ded_credit[START+1] = prio[vc][fc]  ? ord_used_ded_credit[START+0] : ord_used_ded_credit[START+1]; 
            end else if (N_IF==1)begin : g_order_1if
                assign ord_reqs[START+0]        = reqs[START+0];
                assign ord_reqs_dcrd[START+0]   = reqs_dcrd[START+0];
                assign ord_in_halt_int[START+0] = in_halt_int[START+0];
                assign pass[START+0]            = ord_pass[START+0];
                assign used_ded_credit[START+0] = ord_used_ded_credit[START+0];
            end
            
            if(N_IF > 0)begin : g_ifgt0
                xadm_fc_crdt_bank_ms
                 #(.N(N_IF), .VC(vc), .FC_TYPE(FC)) u_xadm_fc_crdt_bank_ms (
                    .clk                                (clk                               ),
                    .rst_n                              (rst_n                             ),
                    .cfg_vc_enable                      (cfg_vc_enable[vc]                 ),
                    .cfg_max_payload_size               (cfg_max_payload_size              ),
                    .cfg_can_transmit_atomic            (cfg_can_transmit_atomic           ),
                    .cfg_can_transmit_dmwr              (cfg_can_transmit_dmwr             ),
                    .rdlh_link_down                     (rdlh_link_down                    ),
                    .in_flush                           (in_flush                          ),
                    .in_rtlh_fc_init_status             (in_rtlh_fc_init_status            ),
                    .in_flit_mode_enabled               (smlh_flit_mode_enable             ),
                    .in_internal_restore                (in_internal_restore[vc][fc]       ),
                    .in_update                          (fc_update[vc][fc]                 ),
                    .in_req                             (ord_reqs[START+:N_IF]             ),
                    .in_req_dcrd                        (ord_reqs_dcrd[START+:N_IF]        ),
                    .in_halt                            (ord_in_halt_int[START+:N_IF]      ),
                    .out_p_cpl_merged                   (p_cpl_merged[vc][fc]              ),
                    .in_shr_pass                        (ord_shr_pass[START+:N_IF]         ),
                    .in_shr_consume_h                   (shr_consume_h[vc][fc]             ),
                    .in_shr_consume_d                   (shr_consume_d[vc][fc]             ),
                    .in_next_remainder_h                (next_remainder_h[vc][fc]          ),
                    .in_next_remainder_d                (next_remainder_d[vc][fc]          ),
                    .in_shr_p_is_infinite_h             (init_infinite_h[vc][E_P][SHR]     ),
                    .in_shr_p_is_infinite_d             (init_infinite_d[vc][E_P][SHR]     ),
                    .in_shr_total_h                     (shr_total_h[fc]                   ),
                    .in_shr_total_d                     (shr_total_d[fc]                   ),
                    .in_shr_consolidated_init_scale_h   (shr_consolidated_init_scale_h[fc] ),
                    .in_shr_consolidated_init_scale_d   (shr_consolidated_init_scale_d[fc] ),
                    .out_pass                           (ord_pass[START+:N_IF]             ),
                    .out_init_scale_h                   (init_scale_h[vc][fc]              ),
                    .out_init_scale_d                   (init_scale_d[vc][fc]              ),
                    .out_init_zero_h                    (init_zero_h[vc][fc]               ),
                    .out_init_zero_d                    (init_zero_d[vc][fc]               ),
                    .out_fc_prot_err                    (fc_prot_err2[vc][fc]              ),
                    .out_init_infinite_h                (init_infinite_h[vc][fc]           ),
                    .out_init_infinite_d                (init_infinite_d[vc][fc]           ),
                    .out_ded_fc_cnsmd_h                 (ded_fc_cnsmd_h[vc][fc]            ),
                    .out_ded_fc_cnsmd_d                 (ded_fc_cnsmd_d[vc][fc]            ),
                    .out_ded_fc_limit_h                 (ded_fc_limit_h[vc][fc]            ),
                    .out_ded_fc_limit_d                 (ded_fc_limit_d[vc][fc]            ),
                    .out_shr_fc_cnsmd_h                 (shr_fc_cnsmd_h[vc][fc]            ),
                    .out_shr_fc_cnsmd_d                 (shr_fc_cnsmd_d[vc][fc]            ),
                    .out_shr_fc_limit_h                 (shr_fc_limit_h[vc][fc]            ),
                    .out_shr_fc_limit_d                 (shr_fc_limit_d[vc][fc]            ),
                    .out_ded_fc_h_cdts                  (ded_fc_h_cdts[vc][fc]             ),
                    .out_ded_fc_d_cdts                  (ded_fc_d_cdts[vc][fc]             ),
                    .out_shr_fc_h_cdts                  (shr_fc_h_cdts[vc][fc]             ),
                    .out_shr_fc_d_cdts                  (shr_fc_d_cdts[vc][fc]             ),
                    .out_prev_remainder_d               (prev_remainder_d[vc][fc]          ),
                    .out_prev_remainder_h               (prev_remainder_h[vc][fc]          ),
                    .out_pm_no_fc_credit                (pm_no_fc_credit[vc][fc]           ),
                    .out_pm_had_enough_credit           (pm_had_enough_credit[vc][fc]      ),
                    .out_rtlh_all_type_infinite         (rtlh_all_type_infinite[vc][fc]    ),
                    .out_used_dedicated_credit          (ord_used_ded_credit[START+:N_IF]  )
                );

                for(genvar i = 0; i < N_IF; i++)begin : g_used_ded_credit_i
                    always_comb  begin
                        in_pkt_int[START+i] = in_pkt[START+i];
                        in_pkt_int[START+i].support.used_ded_credit = smlh_flit_mode_enable && used_ded_credit[START+i];
                    end
                end
    
                xadm_pipe_w_order_ms
                 #(
                    .N(N_IF),
                    .PIPE(PIPE),
                    .CAN_STALL(PIPE),
                    .PREV_STAGE_CAN_HALT(1)
                    ,
                    .BUS_PROTECT_GEN_EN      (0),
                    .BUS_PROTECT_CHK_EN      (N_XADM_FC_CHK),
                    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+N_IF*START)
                ) u_xadm_pipe_w_order_ms (
                    .clk               (clk                         ),
                    .rst_n             (rst_n                       ),
                    .in_pkt            (in_pkt_int[START+:N_IF]     ),
                    .out_halt          (in_halt_int[START+:N_IF]    ),
                    .in_prev_stage_halt(prev_stage_halt[START+:N_IF]),
                    .out_pkt           (out_pkt[START+:N_IF]        ),
                    .in_halt           (in_halt[START+:N_IF]        )
                    ,
                    .ras_dp_err_inj    (ras_dp_err_inj              )
                    ,
                    .ras_dp_err_log    (ras_dp_err_log[START+:N_IF] )
                    );
            end else begin : g_pe0
                assign shr_fc_cnsmd_h[vc][fc] = '0;
                assign shr_fc_cnsmd_d[vc][fc] = '0;
                assign shr_fc_limit_h[vc][fc] = '0;
                assign shr_fc_limit_d[vc][fc] = '0;
                assign ded_fc_cnsmd_h[vc][fc] = '0;
                assign ded_fc_cnsmd_d[vc][fc] = '0;
                assign ded_fc_limit_h[vc][fc] = '0;
                assign ded_fc_limit_d[vc][fc] = '0;
                assign pm_no_fc_credit[vc][fc]        = 1'b0;
                assign pm_had_enough_credit[vc][fc]   = 1'b1;
                assign rtlh_all_type_infinite[vc][fc] = 1'b0;
            end
        end // g_fc
        
        assign out_fc_cnsmd_ph[vc]   = smlh_flit_mode_enable ? shr_fc_cnsmd_h[vc][E_P] : ded_fc_cnsmd_h[vc][E_P];
        assign out_fc_cnsmd_pd[vc]   = smlh_flit_mode_enable ? shr_fc_cnsmd_d[vc][E_P] : ded_fc_cnsmd_d[vc][E_P];
        assign out_fc_limit_ph[vc]   = smlh_flit_mode_enable ? shr_fc_limit_h[vc][E_P] : ded_fc_limit_h[vc][E_P];
        assign out_fc_limit_pd[vc]   = smlh_flit_mode_enable ? shr_fc_limit_d[vc][E_P] : ded_fc_limit_d[vc][E_P];
        assign out_fc_cnsmd_nph[vc]  = smlh_flit_mode_enable ? shr_fc_cnsmd_h[vc][E_NP] : ded_fc_cnsmd_h[vc][E_NP];
        assign out_fc_cnsmd_npd[vc]  = smlh_flit_mode_enable ? shr_fc_cnsmd_d[vc][E_NP] : ded_fc_cnsmd_d[vc][E_NP];
        assign out_fc_limit_nph[vc]  = smlh_flit_mode_enable ? shr_fc_limit_h[vc][E_NP] : ded_fc_limit_h[vc][E_NP];
        assign out_fc_limit_npd[vc]  = smlh_flit_mode_enable ? shr_fc_limit_d[vc][E_NP] : ded_fc_limit_d[vc][E_NP];
        assign out_fc_cnsmd_cplh[vc] = smlh_flit_mode_enable ? shr_fc_cnsmd_h[vc][E_CPL] : ded_fc_cnsmd_h[vc][E_CPL];
        assign out_fc_cnsmd_cpld[vc] = smlh_flit_mode_enable ? shr_fc_cnsmd_d[vc][E_CPL] : ded_fc_cnsmd_d[vc][E_CPL];
        assign out_fc_limit_cplh[vc] = smlh_flit_mode_enable ? shr_fc_limit_h[vc][E_CPL] : ded_fc_limit_h[vc][E_CPL];
        assign out_fc_limit_cpld[vc] = smlh_flit_mode_enable ? shr_fc_limit_d[vc][E_CPL] : ded_fc_limit_d[vc][E_CPL];
        assign out_fc_ph_cdts[vc]   = ded_fc_h_cdts[vc][E_P];
        assign out_fc_pd_cdts[vc]   = ded_fc_d_cdts[vc][E_P];
        assign out_fc_nph_cdts[vc]  = ded_fc_h_cdts[vc][E_NP];
        assign out_fc_npd_cdts[vc]  = ded_fc_d_cdts[vc][E_NP];
        assign out_fc_cplh_cdts[vc] = ded_fc_h_cdts[vc][E_CPL];
        assign out_fc_cpld_cdts[vc] = ded_fc_d_cdts[vc][E_CPL];
        logic [2:0][HCRD_WD-1:0] out_shr_total_h;
        logic [2:0][DCRD_WD-1:0] out_shr_total_d;
        if(vc == 0)begin : g_shrd_cdts
            delay_n
             #(
                .N(1),
                .WD(3*(HCRD_WD+DCRD_WD))
            ) u_delay_n (
                .clk     (clk),
                .rst_n   (rst_n),
                .clear   (1'b0),
                .din     ({    shr_total_d,     shr_total_h}),
                .dout    ({out_shr_total_d, out_shr_total_h})
            );
        
            assign out_fc_ph_shrd_cdts   = out_shr_total_h[E_P];
            assign out_fc_pd_shrd_cdts   = out_shr_total_d[E_P];
            assign out_fc_nph_shrd_cdts  = out_shr_total_h[E_NP];
            assign out_fc_npd_shrd_cdts  = out_shr_total_d[E_NP];
            assign out_fc_cplh_shrd_cdts = out_shr_total_h[E_CPL];
            assign out_fc_cpld_shrd_cdts = out_shr_total_d[E_CPL];
        end // g_shrd_cdts
    end // for each vc
    
endgenerate


xadm_fc_crdt_shared_ms
 u_xadm_fc_crdt_shared_ms (
    .clk                                (clk                            ),
    .rst_n                              (rst_n                          ),
    .in_flit_mode_enable                (smlh_flit_mode_enable          ),
    .in_p_cpl_merged                    (p_cpl_merged[0][E_CPL]         ),
    .cfg_vc_enable                      (cfg_vc_enable                  ),
    .rdlh_link_down                     (rdlh_link_down                 ),
    .in_flush                           (in_flush                       ),
    .in_rtlh_fc_init_status             (in_rtlh_fc_init_status         ),
    .in_req                             (ord_reqs                       ),
    .in_req_dcrd                        (ord_reqs_dcrd                  ),
    .in_halt                            (ord_in_halt_int                ),
    .in_init_infinite_h                 (init_infinite_h                ),
    .in_init_infinite_d                 (init_infinite_d                ),
    .in_shr_consolidated_init_scale_h   (shr_consolidated_init_scale_h  ),
    .in_shr_consolidated_init_scale_d   (shr_consolidated_init_scale_d  ),
    .out_fc_prot_err                    (fc_prot_err3                   ),
    .in_prev_remainder_d                (prev_remainder_d               ),
    .in_prev_remainder_h                (prev_remainder_h               ),
    .in_shr_fc_h_cdts                   (shr_fc_h_cdts                  ),
    .in_shr_fc_d_cdts                   (shr_fc_d_cdts                  ),
    .out_next_remainder_d               (next_remainder_d               ),
    .out_next_remainder_h               (next_remainder_h               ),
    .out_shr_pass                       (ord_shr_pass                   ),
    .out_shr_consume_h                  (shr_consume_h                  ),
    .out_shr_consume_d                  (shr_consume_d                  ),
    .out_shr_total_h                    (shr_total_h                    ),
    .out_shr_total_d                    (shr_total_d                    )
);


endmodule

