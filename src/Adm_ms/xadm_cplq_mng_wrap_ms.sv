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
// ---    $DateTime: 2023/09/27 02:27:25 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xadm_cplq_mng_wrap_ms.sv#4 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module xadm_cplq_mng_wrap_ms
import DWC_pcie_ctl_pkg::NVC;
import DWC_pcie_ctl_pkg::N_XADM_IF;
import DWC_pcie_ctl_pkg::N_XADM_P_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_NP_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_CPL_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_CUMULATIVE_PER_VC;
import DWC_pcie_ctl_pkg::N_XADM_NP_CUMULATIVE_PER_VC;
import DWC_pcie_ctl_pkg::N_XADM_NP_IF;
import DWC_pcie_ctl_pkg::N_TRGT_CPL_IF;
import DWC_pcie_core_pkg::radm_xadm_rcvd_cpl_t;
import DWC_pcie_core_pkg::radm_xadm_timeout_npr_t;
import DWC_pcie_core_pkg::xadm_pkt_t;
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
#(
    parameter RAS_DP_PROT_CHK_ID_BASE = 0
)

                            (
    
    input logic                                      clk,
    input logic                                      rst_n,
    input xadm_pkt_t              [N_XADM_IF-1:0]    in_pkt,
    output logic                  [N_XADM_IF-1:0]    out_halt,
    output xadm_pkt_t             [N_XADM_IF-1:0]    out_pkt,
    input logic                   [N_XADM_IF-1:0]    in_halt
    ,
    input  ras_dp_err_inj_t                          ras_dp_err_inj
    ,
    output ras_dp_err_log_t       [N_XADM_IF-1:0]    ras_dp_err_log
);

localparam int PIPE_FOR_P_CPL = 0 +1;
localparam int PIPE_FOR_NP    = 0 +1;

localparam RAS_CORRECTION_EN      = 0;
localparam IDE_ENABLE             = 0;

localparam RAS_DP_CHK_EN = ((IDE_ENABLE == 0) || (RAS_CORRECTION_EN == 1))? 1 : 0;

logic      [NVC-1:0][7:0]     cplq_mng_restore_hdr;
logic      [NVC-1:0][9:0]     cplq_mng_restore_data;
xadm_pkt_t [N_XADM_IF-1:0]    out_pkt_tmp;
logic      [N_XADM_IF-1:0]    in_halt_tmp;
logic      [N_XADM_IF-1:0]    blocking;


generate
    for(genvar vc = 0; vc < NVC; vc ++)begin : g_cplq_mng_vc
        if(N_XADM_P_IF_VC[vc] > 0) begin : g_cplq_mng_p_gt0
            localparam START = N_XADM_CUMULATIVE_PER_VC [vc];
            localparam N_IF  = N_XADM_P_IF_VC           [vc];
            assign out_pkt_tmp[START+:N_IF] = in_pkt[START+:N_IF];
            assign out_halt[START+:N_IF]    = in_halt_tmp[START+:N_IF];
            assign blocking[START+:N_IF]    = '0;
            xadm_pipe_w_order_ms
             #(
                .N        (N_IF),
                .PIPE     (PIPE_FOR_P_CPL),
                .CAN_STALL(1),
                .PREV_STAGE_CAN_HALT(0)
                ,
                .BUS_PROTECT_GEN_EN      (0),
                .BUS_PROTECT_CHK_EN      (RAS_DP_CHK_EN),
                .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+N_IF*START)
            ) u_xadm_pipe_w_order_p (
                .clk               (clk                     ),
                .rst_n             (rst_n                   ),
                .in_pkt            (out_pkt_tmp[START+:N_IF]),
                .out_halt          (in_halt_tmp[START+:N_IF]),
                .in_prev_stage_halt('0                      ),
                .out_pkt           (out_pkt[START+:N_IF]    ),
                .in_halt           (in_halt[START+:N_IF]    )
                ,
                .ras_dp_err_inj    (ras_dp_err_inj              )
                ,
                .ras_dp_err_log    (ras_dp_err_log[START+:N_IF] )
            );
        end
        if(N_XADM_CPL_IF_VC[vc] > 0) begin : g_cplq_mng_cpl_gt0
            localparam START = N_XADM_CUMULATIVE_PER_VC[vc]+N_XADM_P_IF_VC[vc]+N_XADM_NP_IF_VC[vc];
            localparam N_IF  = N_XADM_CPL_IF_VC [vc];
            assign out_pkt_tmp[START+:N_IF] = in_pkt[START+:N_IF];
            assign out_halt[START+:N_IF]    = in_halt_tmp[START+:N_IF];
            assign blocking[START+:N_IF]    = '0;
            xadm_pipe_w_order_ms
             #(
                .N        (N_IF),
                .PIPE     (PIPE_FOR_P_CPL),
                .CAN_STALL(1),
                .PREV_STAGE_CAN_HALT(0)
                ,
                .BUS_PROTECT_GEN_EN      (0),
                .BUS_PROTECT_CHK_EN      (RAS_DP_CHK_EN),
                .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+N_IF*START)
            ) u_xadm_pipe_w_order_cpl (
                .clk               (clk                     ),
                .rst_n             (rst_n                   ),
                .in_pkt            (out_pkt_tmp[START+:N_IF]),
                .out_halt          (in_halt_tmp[START+:N_IF]),
                .in_prev_stage_halt('0                      ),
                .out_pkt           (out_pkt[START+:N_IF]    ),
                .in_halt           (in_halt[START+:N_IF]    )
                ,
                .ras_dp_err_inj    (ras_dp_err_inj              )
                ,
                .ras_dp_err_log    (ras_dp_err_log[START+:N_IF] )
                );
        end
        if(N_XADM_NP_IF_VC[vc] > 0)begin : g_cplq_mng_np_gt0
            localparam START    = N_XADM_CUMULATIVE_PER_VC[vc]+N_XADM_P_IF_VC[vc];
            localparam N_IF     = N_XADM_NP_IF_VC [vc];
            localparam START_NP = N_XADM_NP_CUMULATIVE_PER_VC[vc];
            assign out_pkt_tmp[START+:N_IF] = in_pkt[START+:N_IF];
            assign out_halt[START+:N_IF]    = in_halt_tmp[START+:N_IF];
            assign blocking[START+:N_IF]    = '0;
            xadm_pipe_w_order_ms
             #(
                .N        (N_IF),
                .PIPE     (PIPE_FOR_NP),
                .CAN_STALL(1),
                .PREV_STAGE_CAN_HALT(1)
                ,
                .BUS_PROTECT_GEN_EN      (0),
                .BUS_PROTECT_CHK_EN      (RAS_DP_CHK_EN),
                .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+N_IF*START)
            ) u_xadm_pipe_w_order_np (
                .clk               (clk                     ),
                .rst_n             (rst_n                   ),
                .in_pkt            (out_pkt_tmp[START+:N_IF]),
                .out_halt          (in_halt_tmp[START+:N_IF]),
                .in_prev_stage_halt(blocking[START+:N_IF]   ),
                .out_pkt           (out_pkt[START+:N_IF]    ),
                .in_halt           (in_halt[START+:N_IF]    )
                ,
                .ras_dp_err_inj    (ras_dp_err_inj              )
                ,
                .ras_dp_err_log    (ras_dp_err_log[START+:N_IF] )
                );
        end
    end
    
endgenerate

endmodule

