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
// ---    $Revision: #1 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xadm_fm_local_prefix_ms.sv#1 $
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

module xadm_fm_local_prefix_ms
import DWC_pcie_ctl_pkg::NVC;
import DWC_pcie_ctl_pkg::N_XADM_IF;
import DWC_pcie_ctl_pkg::N_XADM_P_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_NP_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_CPL_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_CUMULATIVE_PER_VC;
import DWC_pcie_core_pkg::ADM_PRFX_HDR_NW;
import DWC_pcie_core_pkg::xadm_pkt_t;
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
import pcie_pkg::E_P;
import pcie_pkg::E_NP;
import pcie_pkg::E_CPL;
import pcie_pkg::fc_type_e;
#(
    parameter RAS_DP_PROT_CHK_ID_BASE = 0
)
( 
    input logic                             clk,
    input logic                             rst_n,
    
    input xadm_pkt_t        [N_XADM_IF-1:0] in_pkt,
    output logic            [N_XADM_IF-1:0] out_halt,
    
    output xadm_pkt_t       [N_XADM_IF-1:0] out_pkt,
    input logic             [N_XADM_IF-1:0] in_halt
    ,
    input  ras_dp_err_inj_t                 ras_dp_err_inj
    ,
    output ras_dp_err_log_t [N_XADM_IF-1:0] ras_dp_err_log
);
xadm_pkt_t[N_XADM_IF-1:0] chk_pkt;
xadm_pkt_t[N_XADM_IF-1:0] tmp_pkt;
logic[N_XADM_IF-1:0]      co1;
logic[N_XADM_IF-1:0]      co2;
logic[N_XADM_IF-1:0]      chk_halt;
parameter logic[31:0] FM_LOCAL_TLP_PRFX = {16'd0, 8'b1000_0000,8'b1000_1101};

generate
    for(genvar vc = 0; vc < NVC; vc ++)begin : g_vc_in
        for(genvar fc = 0; fc < 3; fc ++)begin : g_fc_in
            localparam FC = fc_type_e'(fc);
            localparam START = N_XADM_CUMULATIVE_PER_VC[vc] + (FC==E_P ? 0 : FC==E_NP ? N_XADM_P_IF_VC[vc] : N_XADM_P_IF_VC[vc] + N_XADM_NP_IF_VC[vc]);
            localparam N_IF =  FC==E_P ? N_XADM_P_IF_VC[vc] : FC==E_NP ? N_XADM_NP_IF_VC[vc] : N_XADM_CPL_IF_VC[vc];
            if(N_IF > 0)begin : g_gt0_in
                xadm_pipe_w_order_ms
                 #(
                    .N(N_IF),
                    .PIPE(0),
                    .CAN_STALL(0),
                    .PREV_STAGE_CAN_HALT(0)
                    ,
                    .BUS_PROTECT_GEN_EN      (0),
                    .BUS_PROTECT_CHK_EN      (1),
                    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+START)
                ) u_xadm_pipe_w_order_ms (
                    .clk               (clk                         ),
                    .rst_n             (rst_n                       ),
                    .in_pkt            (in_pkt[START+:N_IF]         ),
                    .out_halt          (out_halt[START+:N_IF]       ),
                    .in_prev_stage_halt('0),
                    .out_pkt           (chk_pkt[START+:N_IF]        ),
                    .in_halt           (chk_halt[START+:N_IF]        )
                    ,
                    .ras_dp_err_inj    (ras_dp_err_inj              )
                    ,
                    .ras_dp_err_log    (ras_dp_err_log[START+:N_IF] )
                    );
            end
        end
    end
endgenerate

always_comb begin
    tmp_pkt = chk_pkt;
    co1 = '0;
    co2 = '0;
    for(int i = 0; i < N_XADM_IF; i++)begin
        if(chk_pkt[i].support.used_ded_credit)begin
           tmp_pkt[i].prfx_hdr  = {tmp_pkt[i].prfx_hdr[ADM_PRFX_HDR_NW-2:0], FM_LOCAL_TLP_PRFX};
           {co1[i],tmp_pkt[i].prfx_dwen} = {tmp_pkt[i].prfx_dwen, 1'b1};
           {co2[i],tmp_pkt[i].hdr_dwen}  = {tmp_pkt[i].hdr_dwen, 1'b0};
        end
    end
end

generate
    for(genvar vc = 0; vc < NVC; vc ++)begin : g_vc_out
        for(genvar fc = 0; fc < 3; fc ++)begin : g_fc_out
            localparam FC = fc_type_e'(fc);
            localparam START = N_XADM_CUMULATIVE_PER_VC[vc] + (FC==E_P ? 0 : FC==E_NP ? N_XADM_P_IF_VC[vc] : N_XADM_P_IF_VC[vc] + N_XADM_NP_IF_VC[vc]);
            localparam N_IF =  FC==E_P ? N_XADM_P_IF_VC[vc] : FC==E_NP ? N_XADM_NP_IF_VC[vc] : N_XADM_CPL_IF_VC[vc];
            if(N_IF > 0)begin : g_gt0_out
                xadm_pipe_w_order_ms
                 #(
                    .N(N_IF),
                    .PIPE(0),
                    .CAN_STALL(0),
                    .PREV_STAGE_CAN_HALT(0)
                    ,
                    .BUS_PROTECT_GEN_EN      (1),
                    .BUS_PROTECT_CHK_EN      (0),
                    .RAS_DP_PROT_CHK_ID_BASE (0)
                ) u_xadm_pipe_w_order_ms (
                    .clk               (clk                         ),
                    .rst_n             (rst_n                       ),
                    .in_pkt            (tmp_pkt[START+:N_IF]        ),
                    .out_halt          (chk_halt[START+:N_IF]       ),
                    .in_prev_stage_halt('0),
                    .out_pkt           (out_pkt[START+:N_IF]        ),
                    .in_halt           (in_halt[START+:N_IF]        )
                    ,
                    .ras_dp_err_inj    ('0                          )
                    ,
                    .ras_dp_err_log    (                            )
                    );
            end
        end
    end
endgenerate


endmodule

