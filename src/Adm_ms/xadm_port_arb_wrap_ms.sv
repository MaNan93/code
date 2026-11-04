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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xadm_port_arb_wrap_ms.sv#3 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "products/pcie_pkg.svh"

module xadm_port_arb_wrap_ms
import DWC_pcie_ctl_pkg::NVC;
import DWC_pcie_ctl_pkg::NVC_WD;
import pcie_pkg::E_P;
import pcie_pkg::E_NP;
import pcie_pkg::E_CPL;
import DWC_pcie_ctl_pkg::N_XALI_CUMULATIVE_PER_VC;
import DWC_pcie_ctl_pkg::N_XALI_P_IF_VC;
import DWC_pcie_ctl_pkg::N_XALI_NP_IF_VC;
import DWC_pcie_ctl_pkg::N_XALI_CPL_IF_VC;
import DWC_pcie_ctl_pkg::N_XALI_IF;
import DWC_pcie_ctl_pkg::N_DMA_P_IF_VC;
import DWC_pcie_ctl_pkg::N_DMA_NP_IF_VC;
import DWC_pcie_ctl_pkg::N_DMA_IF;
import DWC_pcie_ctl_pkg::N_CCIX_IF;
import DWC_pcie_ctl_pkg::N_XADM_CUMULATIVE_PER_VC;
import DWC_pcie_ctl_pkg::N_XADM_P_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_NP_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_CPL_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_IF;
import DWC_pcie_core_pkg::xadm_pkt_t;
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
#(
    parameter RAS_DP_PROT_CHK_ID_BASE = 0
)
(
    input logic                             clk,
    input logic                             rst_n,
    
    input xadm_pkt_t        [N_XALI_IF-1:0] in_xali_pkt,
    output logic            [N_XALI_IF-1:0] out_xali_halt,
    
    input xadm_pkt_t        [N_DMA_IF-1:0]  in_dma_pkt,
    output logic            [N_DMA_IF-1:0]  out_dma_halt,
    
    
    input xadm_pkt_t                        in_msg_pkt,
    output logic                            out_msg_halt,
    
    input xadm_pkt_t                        in_lbc_pkt,
    output logic                            out_lbc_halt,
    
    output xadm_pkt_t       [N_XADM_IF-1:0] out_pkt,
    input logic             [N_XADM_IF-1:0] in_halt
    ,
    input  ras_dp_err_inj_t                 ras_dp_err_inj
    ,
    output ras_dp_err_log_t [N_XADM_IF-1:0] ras_dp_err_log
);

localparam PORT_ARB_PIPE = 0 +1;
localparam RAS_CORRECTION_EN = 0;
localparam RAS_DP_CHK_EN     = (RAS_CORRECTION_EN == 1)? 1 : 0;

logic      [NVC-1:0]           msg_halt;
logic      [NVC-1:0]           lbc_halt;
xadm_pkt_t [NVC-1:0][2:0][1:0] xali_pkt;
logic      [NVC-1:0][2:0][1:0] xali_halt;
xadm_pkt_t [NVC-1:0]           msg_pkt;
xadm_pkt_t [NVC-1:0]           lbc_pkt;
xadm_pkt_t [NVC-1:0][1:0] dma_pkt;
logic      [NVC-1:0][1:0] dma_halt;
xadm_pkt_t [NVC-1:0][2:0][1:0] arbitrated_pkt_tmp;
logic      [NVC-1:0][2:0][1:0] arbitrated_halt_tmp;
xadm_pkt_t [NVC-1:0][2:0][1:0] arbitrated_pkt;
logic      [NVC-1:0][2:0][1:0] arbitrated_halt;

ras_dp_err_log_t [NVC-1:0][2:0][1:0] arbitrated_ras_dp_err_log;

assign out_lbc_halt = |lbc_halt;
assign out_msg_halt = |msg_halt;

generate
    for(genvar vc = 0; vc < NVC; vc++)begin : g_port_arb_vc
        
        ////////////////////////////////
        // POSTED
        ///////////////////////////////
        if(N_XADM_P_IF_VC[vc] > 0)begin : g_p_gt0
            localparam START_XADM = N_XADM_CUMULATIVE_PER_VC [vc];
            localparam START_XALI = N_XALI_CUMULATIVE_PER_VC [vc];
            
            assign out_pkt[START_XADM +: N_XADM_P_IF_VC[vc]]        = arbitrated_pkt[vc][E_P][0+:N_XADM_P_IF_VC[vc]];
            assign ras_dp_err_log[START_XADM +: N_XADM_P_IF_VC[vc]] = arbitrated_ras_dp_err_log[vc][E_P][0+:N_XADM_P_IF_VC[vc]];
            always_comb begin
                arbitrated_halt[vc][E_P]                        = '0;
                arbitrated_halt[vc][E_P][0+:N_XADM_P_IF_VC[vc]] = in_halt[START_XADM+:N_XADM_P_IF_VC[vc]];
            end
            
            if(N_XALI_P_IF_VC[vc] == 0)begin : g_p_xali_eq0
                assign xali_pkt[vc][E_P][0] = '0;
                assign xali_pkt[vc][E_P][1] = '0;
            end
            if(N_XALI_P_IF_VC[vc] == 1)begin : g_p_xali_eq1
                assign xali_pkt[vc][E_P][0]             = in_xali_pkt[START_XALI+0 +: 1];
                assign xali_pkt[vc][E_P][1]             = '0;
                assign out_xali_halt[START_XALI+0 +: 1] = xali_halt[vc][E_P][0];
            end
            if(N_XALI_P_IF_VC[vc] == 2)begin : g_p_xali_eq2
                assign xali_pkt[vc][E_P][0]             = in_xali_pkt[START_XALI+0 +: 1];
                assign xali_pkt[vc][E_P][1]             = in_xali_pkt[START_XALI+1 +: 1];
                assign out_xali_halt[START_XALI+0 +: 1] = xali_halt[vc][E_P][0];
                assign out_xali_halt[START_XALI+1 +: 1] = xali_halt[vc][E_P][1];
            end
            if(N_DMA_P_IF_VC[vc] == 0)begin : g_p_dma_eq0
                assign dma_pkt[vc][E_P] = '0;
            end
            if(N_DMA_P_IF_VC[vc] == 1)begin : g_p_dma_eq1
                assign dma_pkt[vc][E_P]       = in_dma_pkt[vc*3+E_P];
                assign out_dma_halt[vc*3+E_P] = dma_halt[vc][E_P];
            end
            
            if (N_XADM_P_IF_VC[vc] == 1) begin : g_p_tie_port1_halt
                assign arbitrated_halt_tmp[vc][E_P][1] = 1'b0;
            end
            
            assign msg_pkt[vc] = NVC==1 ? in_msg_pkt : in_msg_pkt.support.vc==(NVC_WD)'(vc) ? in_msg_pkt : '0;
            xadm_port_arb_ms
             #(.VC((NVC_WD)'(vc)), .N_HP(1), .N_XALI(N_XALI_P_IF_VC[vc]), .N_DMA(0 +1)) u_xadm_port_arb_ms_p
            (
                .clk          (clk                         ),
                .rst_n        (rst_n                       ),
                .in_hp_pkt    (msg_pkt[vc]                 ),
                .out_hp_halt  (msg_halt[vc]                ),
                .in_xali_pkt  (xali_pkt[vc][E_P]           ),
                .out_xali_halt(xali_halt[vc][E_P]          ),
                .in_dma_pkt   (dma_pkt[vc][E_P]            ),
                .out_dma_halt (dma_halt[vc][E_P]           ),
                .out_pkt      (arbitrated_pkt_tmp[vc][E_P] ),
                .in_halt      (arbitrated_halt_tmp[vc][E_P]));
            
            xadm_pipe_w_order_ms
             #(
                .N                       (N_XADM_P_IF_VC[vc]),
                .PIPE                    (PORT_ARB_PIPE),
                .CAN_STALL               (PORT_ARB_PIPE),
                .PREV_STAGE_CAN_HALT     (0),
                .CAN_CHANGE_ON_HALT      (1)
                ,
                .BUS_PROTECT_GEN_EN      (0),
                .BUS_PROTECT_CHK_EN      (RAS_DP_CHK_EN),
                .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+N_XADM_P_IF_VC[vc]*START_XADM)
            ) u_xadm_pipe_w_order_ms_p (
                .clk                 (clk                                                       ),
                .rst_n               (rst_n                                                     ),
                .in_pkt              (arbitrated_pkt_tmp[vc][E_P][0+:N_XADM_P_IF_VC[vc]]        ),
                .in_prev_stage_halt  ('0                                                        ),
                .out_halt            (arbitrated_halt_tmp[vc][E_P][0+:N_XADM_P_IF_VC[vc]]       ),
                .out_pkt             (arbitrated_pkt[vc][E_P][0+:N_XADM_P_IF_VC[vc]]            ),
                .in_halt             (arbitrated_halt[vc][E_P][0+:N_XADM_P_IF_VC[vc]]           )
                ,
                .ras_dp_err_inj      (ras_dp_err_inj                                            )
                ,
                .ras_dp_err_log      (arbitrated_ras_dp_err_log[vc][E_P][0+:N_XADM_P_IF_VC[vc]] )
                );
        end
        
        ////////////////////////////////
        // NON POSTED
        ///////////////////////////////
        if(N_XADM_NP_IF_VC[vc] > 0)begin : g_np_gt0
            localparam START_XADM = N_XADM_CUMULATIVE_PER_VC[vc]+N_XADM_P_IF_VC[vc];
            localparam START_XALI = N_XALI_CUMULATIVE_PER_VC[vc]+N_XALI_P_IF_VC[vc];
            
            assign out_pkt[START_XADM +: N_XADM_NP_IF_VC[vc]]        = arbitrated_pkt[vc][E_NP][0+:N_XADM_NP_IF_VC[vc]];
            assign ras_dp_err_log[START_XADM +: N_XADM_NP_IF_VC[vc]] = arbitrated_ras_dp_err_log[vc][E_NP][0+:N_XADM_NP_IF_VC[vc]];
            always_comb begin
                arbitrated_halt[vc][E_NP]                         = '0;
                arbitrated_halt[vc][E_NP][0+:N_XADM_NP_IF_VC[vc]] = in_halt[START_XADM+:N_XADM_NP_IF_VC[vc]];
            end
            
            if(N_XALI_NP_IF_VC[vc] == 0)begin : g_np_xali_eq0
                assign xali_pkt[vc][E_NP][0] = '0;
                assign xali_pkt[vc][E_NP][1] = '0;
            end
            if(N_XALI_NP_IF_VC[vc] == 1)begin : g_np_xali_eq1
                assign xali_pkt[vc][E_NP][0]            = in_xali_pkt[START_XALI+0 +: 1];
                assign xali_pkt[vc][E_NP][1]            = '0;
                assign out_xali_halt[START_XALI+0 +: 1] = xali_halt[vc][E_NP][0];
            end
            if(N_XALI_NP_IF_VC[vc] == 2)begin : g_np_xali_eq2
                assign xali_pkt[vc][E_NP][0]            = in_xali_pkt[START_XALI+0 +: 1];
                assign xali_pkt[vc][E_NP][1]            = in_xali_pkt[START_XALI+1 +: 1];
                assign out_xali_halt[START_XALI+0 +: 1] = xali_halt[vc][E_NP][0];
                assign out_xali_halt[START_XALI+1 +: 1] = xali_halt[vc][E_NP][1];
            end
            if(N_DMA_NP_IF_VC[vc] == 0)begin : g_p_dma_eq0
                assign dma_pkt[vc][E_NP] = '0;
            end
            if(N_DMA_NP_IF_VC[vc] == 1)begin : g_p_dma_eq1
                assign dma_pkt[vc][E_NP]       = in_dma_pkt[vc*3+E_NP];
                assign out_dma_halt[vc*3+E_NP] = dma_halt[vc][E_NP];
            end
            
            if (N_XADM_NP_IF_VC[vc] == 1) begin : g_np_tie_port1_halt
                assign arbitrated_halt_tmp[vc][E_NP][1] = 1'b0;
            end
            
            xadm_port_arb_ms
             #(.VC((NVC_WD)'(vc)), .N_HP(0), .N_XALI(N_XALI_NP_IF_VC[vc]), .N_DMA(0 +1)) u_xadm_port_arb_ms_np
            (
                .clk          (clk                          ),
                .rst_n        (rst_n                        ),
                .in_hp_pkt    ('0                           ),
                .out_hp_halt  (                             ),
                .in_xali_pkt  (xali_pkt[vc][E_NP]           ),
                .out_xali_halt(xali_halt[vc][E_NP]          ),
                .in_dma_pkt   (dma_pkt[vc][E_NP]            ),
                .out_dma_halt (dma_halt[vc][E_NP]           ),
                .out_pkt      (arbitrated_pkt_tmp[vc][E_NP] ),
                .in_halt      (arbitrated_halt_tmp[vc][E_NP]));
            xadm_pipe_w_order_ms
             #(
                .N                       (N_XADM_NP_IF_VC[vc]),
                .PIPE                    (PORT_ARB_PIPE),
                .CAN_STALL               (PORT_ARB_PIPE),
                .PREV_STAGE_CAN_HALT     (0)
                ,
                .BUS_PROTECT_GEN_EN      (0),
                .BUS_PROTECT_CHK_EN      (RAS_DP_CHK_EN),
                .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+N_XADM_NP_IF_VC[vc]*START_XADM)
            ) u_xadm_pipe_w_order_ms_np (
                .clk                (clk                                                         ),
                .rst_n              (rst_n                                                       ),
                .in_pkt             (arbitrated_pkt_tmp[vc][E_NP][0+:N_XADM_NP_IF_VC[vc]]        ),
                .in_prev_stage_halt ('0                                                          ),
                .out_halt           (arbitrated_halt_tmp[vc][E_NP][0+:N_XADM_NP_IF_VC[vc]]       ),
                .out_pkt            (arbitrated_pkt[vc][E_NP][0+:N_XADM_NP_IF_VC[vc]]            ),
                .in_halt            (arbitrated_halt[vc][E_NP][0+:N_XADM_NP_IF_VC[vc]]           )
                ,
                .ras_dp_err_inj      (ras_dp_err_inj                                             )
                ,
                .ras_dp_err_log      (arbitrated_ras_dp_err_log[vc][E_NP][0+:N_XADM_NP_IF_VC[vc]])
                );
        end
        
        ////////////////////////////////
        // COMPLETIONS
        ///////////////////////////////
        if(N_XADM_CPL_IF_VC[vc] > 0)begin : g_cpl_gt0
            localparam START_XADM = N_XADM_CUMULATIVE_PER_VC[vc]+N_XADM_P_IF_VC[vc]+N_XADM_NP_IF_VC[vc];
            localparam START_XALI = N_XALI_CUMULATIVE_PER_VC[vc]+N_XALI_P_IF_VC[vc]+N_XALI_NP_IF_VC[vc];
            
            assign out_pkt[START_XADM +: N_XADM_CPL_IF_VC[vc]]        = arbitrated_pkt[vc][E_CPL][0+:N_XADM_CPL_IF_VC[vc]];
            assign ras_dp_err_log[START_XADM +: N_XADM_CPL_IF_VC[vc]] = arbitrated_ras_dp_err_log[vc][E_CPL][0+:N_XADM_CPL_IF_VC[vc]];
            always_comb begin
                arbitrated_halt[vc][E_CPL]                          = '0;
                arbitrated_halt[vc][E_CPL][0+:N_XADM_CPL_IF_VC[vc]] = in_halt[START_XADM+:N_XADM_CPL_IF_VC[vc]];
            end
            
            if(N_XALI_CPL_IF_VC[vc] == 0)begin : g_cpl_xali_eq0
                assign xali_pkt[vc][E_CPL][0] = '0;
                assign xali_pkt[vc][E_CPL][1] = '0;
            end
            if(N_XALI_CPL_IF_VC[vc] == 1)begin : g_cpl_xali_eq1
                assign xali_pkt[vc][E_CPL][0]           = in_xali_pkt[START_XALI+0 +: 1];
                assign xali_pkt[vc][E_CPL][1]           = '0;
                assign out_xali_halt[START_XALI+0 +: 1] = xali_halt[vc][E_CPL][0];
            end
            if(N_XALI_CPL_IF_VC[vc] == 2)begin : g_cpl_xali_eq2
                assign xali_pkt[vc][E_CPL][0]           = in_xali_pkt[START_XALI+0 +: 1];
                assign xali_pkt[vc][E_CPL][1]           = in_xali_pkt[START_XALI+1 +: 1];
                assign out_xali_halt[START_XALI+1 +: 1] = xali_halt[vc][E_CPL][1];
                assign out_xali_halt[START_XALI+0 +: 1] = xali_halt[vc][E_CPL][0];
            end
            
            if (N_XADM_CPL_IF_VC[vc] == 1) begin : g_cpl_tie_port1_halt
                assign arbitrated_halt_tmp[vc][E_CPL][1] = 1'b0;
            end
            
            assign lbc_pkt[vc] = NVC==1 ? in_lbc_pkt : in_lbc_pkt.support.vc==(NVC_WD)'(vc) ? in_lbc_pkt : '0;
            xadm_port_arb_ms
             #(.VC((NVC_WD)'(vc)), .N_HP(1), .N_XALI(N_XALI_CPL_IF_VC[vc]), .N_DMA(0)) u_xadm_port_arb_ms_cpl
            (
                .clk          (clk                           ),
                .rst_n        (rst_n                         ),
                .in_hp_pkt    (lbc_pkt[vc]                   ),
                .out_hp_halt  (lbc_halt[vc]                  ),
                .in_xali_pkt  (xali_pkt[vc][E_CPL]           ),
                .out_xali_halt(xali_halt[vc][E_CPL]          ),
                .in_dma_pkt   ('0                            ),
                .out_dma_halt (                              ),
                .out_pkt      (arbitrated_pkt_tmp[vc][E_CPL] ),
                .in_halt      (arbitrated_halt_tmp[vc][E_CPL]));
            xadm_pipe_w_order_ms
             #(
                .N                       (N_XADM_CPL_IF_VC[vc]),
                .PIPE                    (PORT_ARB_PIPE),
                .CAN_STALL               (PORT_ARB_PIPE),
                .PREV_STAGE_CAN_HALT     (0),
                .CAN_CHANGE_ON_HALT      (1)
                ,
                .BUS_PROTECT_GEN_EN      (0),
                .BUS_PROTECT_CHK_EN      (RAS_DP_CHK_EN),
                .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+N_XADM_CPL_IF_VC[vc]*START_XADM)
            ) u_xadm_pipe_w_order_ms_cpl (
                .clk                (clk                                                           ),
                .rst_n              (rst_n                                                         ),
                .in_pkt             (arbitrated_pkt_tmp[vc][E_CPL][0+:N_XADM_CPL_IF_VC[vc]]        ),
                .in_prev_stage_halt ('0                                                            ),
                .out_halt           (arbitrated_halt_tmp[vc][E_CPL][0+:N_XADM_CPL_IF_VC[vc]]       ),
                .out_pkt            (arbitrated_pkt[vc][E_CPL][0+:N_XADM_CPL_IF_VC[vc]]            ),
                .in_halt            (arbitrated_halt[vc][E_CPL][0+:N_XADM_CPL_IF_VC[vc]]           )
                ,
                .ras_dp_err_inj      (ras_dp_err_inj                                               )
                ,
                .ras_dp_err_log      (arbitrated_ras_dp_err_log[vc][E_CPL][0+:N_XADM_CPL_IF_VC[vc]])
                );
        end
    end
endgenerate
endmodule

