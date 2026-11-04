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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xadm_xtlh_pkt_formation_ms.sv#6 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "products/pcie_pkg.svh"

module xadm_xtlh_pkt_formation_ms
import DWC_pcie_ctl_pkg::TP;
import DWC_pcie_ctl_pkg::NVC;
import DWC_pcie_ctl_pkg::NVC_WD;
import DWC_pcie_ctl_pkg::N_XADM_IF;
import DWC_pcie_ctl_pkg::N_XADM_P_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_NP_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_CPL_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_CUMULATIVE_PER_VC;
import DWC_pcie_ctl_pkg::E_TX_PORT_ID_MSG;
import DWC_pcie_ctl_pkg::E_TX_PORT_ID_LBC;
import DWC_pcie_ctl_pkg::E_TX_PORT_ID_DMA;
import DWC_pcie_ctl_pkg::NW;
import DWC_pcie_core_pkg::ADM_PRFX_NW;
import DWC_pcie_core_pkg::ADM_PRFX_HDR_NW;
import DWC_pcie_core_pkg::ADM_PRFX_HDR_DATA_NW;
import DWC_pcie_core_pkg::xtlh_pkt_t;
import DWC_pcie_core_pkg::xadm_pkt_t;
import pcie_pkg::decoded_tlp_type_s;
import pcie_pkg::f_decode_tlp_type;
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
    input logic                                       clk,
    input logic                                       rst_n,

    input logic                                       flit_mode_enable,
    
    input xadm_pkt_t        [N_XADM_IF-1:0]           in_pkt,
    output logic            [N_XADM_IF-1:0]           out_halt,
    
    output xtlh_pkt_t       [N_XADM_IF-1:0]           out_pkt,
    input logic             [N_XADM_IF-1:0]           in_halt

    ,
    input  logic                                      diag_ctrl,
    input  logic                                      einj0_enable,
    input  logic [7:0]                                einj0_count,
    input  logic [3:0]                                einj0_crc_type,
    input  logic [2:0]                                einj0_ecrc_vc_sel,
    input  fc_type_e                                  einj0_ecrc_fc_sel,
    input  logic                                      einj0_ecrc_intf_sel,
    output logic                                      einj0_ecrc_evt

    ,
    input  ras_dp_err_inj_t                           ras_dp_err_inj
    ,
    output ras_dp_err_log_t [N_XADM_IF-1:0]           ras_dp_err_log
);
localparam XADM_XTLH_PIPE = 0 +1;

localparam RAS_CORRECTION_EN      = 0;
// XADM XTLH Pkt Formation Checkers are present if:
//  - RAS Protection type is ECC with Correction enabled
localparam N_XADM_XTLH_PKT_FORMATION_CHK = (RAS_CORRECTION_EN == 1)? 1 : 0;

logic      [N_XADM_IF-1:0][ADM_PRFX_HDR_NW:0]                   hdr_dwen_ext;
logic      [N_XADM_IF-1:0][NW:0]                                data_dwen_ext;
xtlh_pkt_t [N_XADM_IF-1:0]                                      out_pkt_tmp;
logic      [N_XADM_IF-1:0]                                      must_add_ecrc_c, must_add_ecrc_r;
logic      [N_XADM_IF-1:0][$clog2(ADM_PRFX_HDR_NW+1)-1:0]       j_int;
logic      [N_XADM_IF-1:0][$clog2(ADM_PRFX_HDR_DATA_NW+1)-1:0]  k_int;
logic      [N_XADM_IF-1:0]                                      c_msg_is_ptm_on_eot, r_msg_is_ptm_on_eot;


logic      [N_XADM_IF-1:0]                                      corrupt_ecrc;

// Extended signals to carry 3 extra DWs (MAC+PCRC). Extra DWs are never read.
logic      [N_XADM_IF-1:0][ADM_PRFX_HDR_DATA_NW+2:0][31:0]      data_ext;
logic      [N_XADM_IF-1:0][ADM_PRFX_HDR_DATA_NW+2:0]            dwen_ext;
always_comb begin
    out_pkt_tmp   = '0;
    data_ext = '0;
    dwen_ext = '0;
    j_int = '0;
    k_int = '0;
    must_add_ecrc_c = must_add_ecrc_r;
    for(int i = 0; i < N_XADM_IF; i++)begin
        hdr_dwen_ext[i]       = {1'b0,in_pkt[i].hdr_dwen};
        data_dwen_ext[i]      = {1'b0,in_pkt[i].data_dwen};
        out_pkt_tmp[i].sot    = in_pkt[i].hv;
        out_pkt_tmp[i].eot    = in_pkt[i].eot;
        out_pkt_tmp[i].badeot = in_pkt[i].bad_eot;
        //out_pkt_tmp[i].soh    = in_pkt[i].hdr_start_oh;
        for(int j = 0; j <= ADM_PRFX_NW; j++)
            out_pkt_tmp[i].soh[j] = (out_pkt_tmp[i].soh=='0 && in_pkt[i].hdr_dwen[j]) ? in_pkt[i].hv : 1'b0;
        
        out_pkt_tmp[i].ep = in_pkt[i].support.ep;
        out_pkt_tmp[i].seqnum           = in_pkt[i].order_seqnum;
        out_pkt_tmp[i].is_from_msg_gen  = in_pkt[i].origin_port==E_TX_PORT_ID_MSG;
        out_pkt_tmp[i].is_from_lbc      = in_pkt[i].origin_port==E_TX_PORT_ID_LBC;
        out_pkt_tmp[i].is_from_dma      = in_pkt[i].origin_port==E_TX_PORT_ID_DMA;
        out_pkt_tmp[i].vc               = in_pkt[i].support.vc;
        // No P2P and no Switch, TD bit decides whether to add ECRC or not
        must_add_ecrc_c[i] = in_pkt[i].hv ? (in_pkt[i].support.td) : must_add_ecrc_r[i];

        out_pkt_tmp[i].pme_to_ack = in_pkt[i].support.msg_is_pme_to_ack;

        // Process the Header
        if(in_pkt[i].hv)begin
            data_ext[i][0+:ADM_PRFX_HDR_NW] = in_pkt[i].prfx_hdr;
            dwen_ext[i][0+:ADM_PRFX_HDR_NW] = {{ADM_PRFX_HDR_NW-(ADM_PRFX_NW){1'b0}},in_pkt[i].prfx_dwen} | in_pkt[i].hdr_dwen;
            //out_pkt_tmp[i].prfx_hdr_prot       = in_pkt[i].prfx_hdr_prot;
            //out_pkt_tmp[i].data_prot           = in_pkt[i].data_prot;
            out_pkt_tmp[i].tlp_prot              = '0;
            out_pkt_tmp[i].ras_dp_err_inband_kbd = in_pkt[i].ras_dp_err_inband_kbd;
            // j_int == where the Data starts
            for(int j = 1; j < ADM_PRFX_HDR_NW+1; j++)begin
                if(hdr_dwen_ext[i][j-1] && !hdr_dwen_ext[i][j])begin
                    out_pkt_tmp[i].sod[j] = in_pkt[i].dv;
                    j_int[i] = $clog2(ADM_PRFX_HDR_NW+1)'(j);
                    k_int[i] = $clog2(ADM_PRFX_HDR_DATA_NW+1)'(j);
                end
            end
        end

        // Process the Data
        if(in_pkt[i].dv)begin
            // k_int == where the {ECRC/PCRC/MAC} starts
            for(int k = 1; k < NW+1; k++)begin
                if(data_dwen_ext[i][k-1] && !data_dwen_ext[i][k])begin
                    k_int[i] = $clog2(ADM_PRFX_HDR_DATA_NW+1)'(k_int[i]+k);
                end
            end

            for(int j = 0; j < ADM_PRFX_HDR_NW+1; j++)begin
                if(j_int[i] == $clog2(ADM_PRFX_HDR_NW+1)'(j))begin
                    data_ext[i][j+:NW] = in_pkt[i].data;
                    dwen_ext[i][j+:NW] = in_pkt[i].data_dwen;
                end
            end
        end

        // Process the remaining {ECRC/PCRC/MAC} at eot
        if(in_pkt[i].eot)begin
            if(in_pkt[i].hv)begin
                out_pkt_tmp[i].ptm = in_pkt[i].support.msg_is_ptm;
            end else begin
                out_pkt_tmp[i].ptm = r_msg_is_ptm_on_eot[i];
            end

            
            // appending trailer
            for(int k = 0; k < ADM_PRFX_HDR_DATA_NW; k++)begin
                if(k_int[i] == $clog2(ADM_PRFX_HDR_DATA_NW+1)'(k))begin
                    if(must_add_ecrc_c[i])begin
                        data_ext[i][k+:1] = (corrupt_ecrc[i])? {in_pkt[i].ecrc[31:1], !in_pkt[i].ecrc[0]} : in_pkt[i].ecrc;
                        dwen_ext[i][k+:1] = 1'b1;
                    end

                end
            end
        end
        for (int dw=0; dw < ADM_PRFX_HDR_DATA_NW; dw++) begin
            out_pkt_tmp[i].data[dw] = dwen_ext[i][dw]? data_ext[i][dw] : 32'b0;
        end
        out_pkt_tmp[i].dwen = dwen_ext[i][0+:ADM_PRFX_HDR_DATA_NW];
        out_pkt_tmp[i].dv   = |out_pkt_tmp[i].dwen; // XTLH does not check _dv, but set it whenever dwen is set for robustness
    end
end



always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)  must_add_ecrc_r <= #TP '0;
    else        must_add_ecrc_r <= #TP must_add_ecrc_c;
end

logic diag_ctrl_dly;
always_ff@(posedge clk or negedge rst_n)begin
    if (!rst_n) begin
        diag_ctrl_dly <= #TP '0;
    end else begin
        diag_ctrl_dly <= #TP diag_ctrl;
    end
end

logic                 diag_ctrl_ecrc_err_inj_req;
logic [N_XADM_IF-1:0] diag_ctrl_ecrc_err_inj_clr;
always_ff@(posedge clk or negedge rst_n)begin
    if (!rst_n) begin
        diag_ctrl_ecrc_err_inj_req <= #TP '0;
    end else begin
        if (|diag_ctrl_ecrc_err_inj_clr) begin
            diag_ctrl_ecrc_err_inj_req <= #TP '0;
        end else if (diag_ctrl && (!diag_ctrl_dly)) begin
            diag_ctrl_ecrc_err_inj_req <= #TP '1;
        end
    end
end

// RAS DES ECRC Error Injection
decoded_tlp_type_s [N_XADM_IF-1:0] tlp_type;
fc_type_e          [N_XADM_IF-1:0] c_decoded_fc_type, r_decoded_fc_type;
generate
    for (genvar vc = 0; vc < NVC; vc++) begin : g_ecrc_err_inj_vc
        for(genvar fc = 0; fc < 3; fc++) begin : g_ecrc_err_inj_fc
            localparam fc_type_e FC = fc_type_e'(fc);
            localparam START        = N_XADM_CUMULATIVE_PER_VC[vc] + (FC==E_P ? 0 : FC==E_NP ? N_XADM_P_IF_VC[vc] : N_XADM_P_IF_VC[vc]+N_XADM_NP_IF_VC[vc]);
            localparam N_IF         = FC==E_P ? N_XADM_P_IF_VC[vc] : FC==E_NP ? N_XADM_NP_IF_VC[vc] : N_XADM_CPL_IF_VC[vc];
            for(genvar i = 0; i < N_IF; i++) begin : g_ecrc_err_inj_i
                always_ff@(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        r_decoded_fc_type[START+i] <= #TP fc_type_e'(0);
                    end else begin
                        if (out_pkt_tmp[START+i].sot) begin
                            r_decoded_fc_type[START+i] <= #TP c_decoded_fc_type[START+i];
                        end
                    end
                end
                always_comb begin
                    corrupt_ecrc[START+i]               = '0;
                    diag_ctrl_ecrc_err_inj_clr[START+i] = '0;
                    tlp_type[START+i]                   = '0;
                    // extract FC type for each channel
                    if (out_pkt_tmp[START+i].sot) begin
                        for (int index = 0; index <= ADM_PRFX_NW; index++) begin
                            if (out_pkt_tmp[START+i].soh[index]) begin
                                tlp_type[START+i] = f_decode_tlp_type(in_pkt[START+i].prfx_hdr[index][7:0], flit_mode_enable);
                            end
                        end
                        c_decoded_fc_type[START+i] = tlp_type[START+i].fc_type;
                    end else begin
                        c_decoded_fc_type[START+i] = r_decoded_fc_type[START+i];
                    end
                    if (must_add_ecrc_c[START+i] &&
                        (~out_halt[START+i]) &&
                        out_pkt_tmp[START+i].eot &&
                        ({{(3-NVC_WD){1'b0}}, out_pkt_tmp[START+i].vc} == einj0_ecrc_vc_sel) &&
                        (c_decoded_fc_type[START+i] == einj0_ecrc_fc_sel) &&
                        (i == einj0_ecrc_intf_sel)

                        ) begin    
                        // ecrc error injection is driven by CDM registers                                                                                                                        
                        if (einj0_enable && (einj0_crc_type == 4'b0011)) begin                                                                                                                    
                            corrupt_ecrc[START+i] = 1'b1;                                                                                                                                         
                        // ecrc error injection is driven by diagnostic control bus                                                                                                               
                        end else if(diag_ctrl_ecrc_err_inj_req) begin                                                                                                                             
                            corrupt_ecrc[START+i]               = 1'b1;                                                                                                                       
                            diag_ctrl_ecrc_err_inj_clr[START+i] = 1'b1;                                                                                                                       
                        end                                                                                                                                                                       
                    end                                                                                                                                                                           
                end
            end
        end
    end
endgenerate

assign einj0_ecrc_evt = |corrupt_ecrc;

always_comb begin
    for (int i = 0; i < N_XADM_IF; i++) begin
        if(in_pkt[i].hv && (!in_pkt[i].eot))begin
            c_msg_is_ptm_on_eot[i] = in_pkt[i].support.msg_is_ptm;
        end else begin
            c_msg_is_ptm_on_eot[i] = r_msg_is_ptm_on_eot[i];
        end
    end
end
always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        r_msg_is_ptm_on_eot <= #TP '0;
    end else begin
        r_msg_is_ptm_on_eot <= #TP c_msg_is_ptm_on_eot;
    end
end

        
generate
    for(genvar vc = 0; vc < NVC; vc++)begin : g_vc
        for(genvar fc = 0; fc < 3; fc++) begin : g_fc
            localparam fc_type_e FC    = fc_type_e'(fc);
            localparam           START = N_XADM_CUMULATIVE_PER_VC[vc] + (FC==E_P ? 0 : FC==E_NP ? N_XADM_P_IF_VC[vc] : (N_XADM_P_IF_VC[vc]+N_XADM_NP_IF_VC[vc]));
            localparam           N_IF  = FC==E_P ? N_XADM_P_IF_VC[vc] : FC==E_NP ? N_XADM_NP_IF_VC[vc] : N_XADM_CPL_IF_VC[vc];

            xtlh_pipe_w_order_ms
             #(
                .N                       (N_IF),
                .PIPE                    (XADM_XTLH_PIPE),
                .CAN_STALL               (XADM_XTLH_PIPE),
                .PREV_STAGE_CAN_HALT     (0)
                ,
                .BUS_PROTECT_GEN_EN      (1),
                .BUS_PROTECT_CHK_EN      (N_XADM_XTLH_PKT_FORMATION_CHK),
                .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+N_IF*START)
            ) u_xtlh_pipe_w_order_ms (
                .clk                (clk                        ),
                .rst_n              (rst_n                      ),
                .in_pkt             (out_pkt_tmp[START+:N_IF]   ),
                .out_halt           (out_halt[START+:N_IF]      ),
                .in_prev_stage_halt ('0                         ),
                .out_pkt            (out_pkt[START+:N_IF]       ),
                .in_halt            (in_halt[START+:N_IF]       )
                ,
                .ras_dp_err_inj     (ras_dp_err_inj             )
                ,
                .ras_dp_err_log     (ras_dp_err_log[START+:N_IF])
            );
        end
    end
endgenerate


endmodule

