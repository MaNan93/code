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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xadm_cdm_error_signals_ms.sv#4 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "products/pcie_pkg.svh"

module xadm_cdm_error_signals_ms
import DWC_pcie_ctl_pkg::TP;
import DWC_pcie_ctl_pkg::TAG_SIZE;
import DWC_pcie_ctl_pkg::N_XADM_IF;
import DWC_pcie_ctl_pkg::N_XADM_CUMULATIVE_PER_VC;
import DWC_pcie_ctl_pkg::N_XADM_P_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_NP_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_CPL_IF_VC;
import DWC_pcie_ctl_pkg::NVC;
import DWC_pcie_ctl_pkg::NF;
import DWC_pcie_ctl_pkg::PF_WD;
import pcie_pkg::decoded_tlp_type_s;
import pcie_pkg::f_decode_tlp_type;
import DWC_pcie_ctl_pkg::E_NP_REQ_TX_MEMRD_NON_ATS;
import DWC_pcie_ctl_pkg::E_NP_REQ_TX_MEMRD_ATS;
import DWC_pcie_ctl_pkg::E_NP_REQ_TX_IO_RD;
import DWC_pcie_ctl_pkg::E_NP_REQ_TX_IO_WR;
import DWC_pcie_ctl_pkg::E_NP_REQ_TX_CFG_RD;
import DWC_pcie_ctl_pkg::E_NP_REQ_TX_CFG_WR;
import DWC_pcie_ctl_pkg::E_NP_REQ_TX_ATOMIC;
import DWC_pcie_ctl_pkg::E_NP_REQ_TX_DMWR;
import DWC_pcie_core_pkg::ADM_PRFX_NW;
import DWC_pcie_core_pkg::xadm_xmt_pci_errors_t;
import DWC_pcie_core_pkg::xadm_pkt_t;
import pcie_pkg::E_P;
import pcie_pkg::E_NP;
import pcie_pkg::E_CPL;
import pcie_pkg::fc_type_e;
(
    input logic                      clk,
    input logic                      rst_n,
    input logic                      cfg_flit_mode_en,
    input xadm_pkt_t [N_XADM_IF-1:0] in_pkt,
    input logic      [N_XADM_IF-1:0] in_halt,
    
    output xadm_xmt_pci_errors_t     out_tx_errors
);
localparam int SRIOV_EN         = 0;
localparam int FLIT_MODE_ENABLE = 0 +1;
localparam int CAN_BADEOT       = 1 -1; // no bad_eot for AMBA 
localparam int BASE_HDR_SIZE    = FLIT_MODE_ENABLE ? 5 : 4; // In FM, need to index OHC-A 

logic [N_XADM_IF-1:0]                               cpl_ur;
logic [N_XADM_IF-1:0]                               cpl_ca;
logic [N_XADM_IF-1:0]                               cpl_poisoned;
logic [N_XADM_IF-1:0]                               wreq_poisoned;
logic [N_XADM_IF-1:0][2:0]                          cpl_status;
logic [N_XADM_IF-1:0][BASE_HDR_SIZE-1:0][31:0]      base_hdr;

logic [N_XADM_IF-1:0]                               has_ohc_a;
logic [N_XADM_IF-1:0][2:0]                          ohc_a5_cpl_status;

logic[N_XADM_IF-1:0][ADM_PRFX_NW:0]                 hdr_start_oh;
decoded_tlp_type_s[N_XADM_IF-1:0]                   decoded_tlp_type;
logic[N_XADM_IF-1:0][2:0]                           ohc_a_pos; // can count up to position [7] for a base hdr of 7
logic[N_XADM_IF-1:0]                                ep;

xadm_xmt_pci_errors_t c_info, r_info;

generate
    for(genvar vc = 0; vc < NVC; vc++)begin : g_vc
        for(genvar fc = 0; fc < 3; fc++) begin : g_fc
            localparam fc_type_e FC   = fc_type_e'(fc);
            localparam           N_IF = (FC==E_P) ? N_XADM_P_IF_VC[vc] : (FC==E_NP) ? N_XADM_NP_IF_VC[vc] : N_XADM_CPL_IF_VC[vc];
            for(genvar i = 0; i < N_IF; i++)begin : g_i
                
                localparam START = i+ N_XADM_CUMULATIVE_PER_VC[vc]+ ((FC==E_P) ? 0 : (FC==E_NP) ? N_XADM_P_IF_VC[vc] : (N_XADM_P_IF_VC[vc]+N_XADM_NP_IF_VC[vc]));
                
                always_comb begin
                    base_hdr[START]     = '0;
                    hdr_start_oh[START] = '0;

                    // Find the start of the Header
                    for(int j = 0; j <= ADM_PRFX_NW; j++) 
                        hdr_start_oh[START][j] = j==0 ? (in_pkt[START].hdr_dwen[0] ? 1'b1 : 1'b0) : (in_pkt[START].hdr_dwen[j] && !in_pkt[START].hdr_dwen[j-1]) ? 1'b1 : 1'b0;
                    for(int j = 0; j <= ADM_PRFX_NW; j++)begin
                        base_hdr[START] = (hdr_start_oh[START][j]) ? in_pkt[START].prfx_hdr[j+:BASE_HDR_SIZE] : base_hdr[START];
                    end
                    decoded_tlp_type[START]  = f_decode_tlp_type(base_hdr[START][0][7:0], cfg_flit_mode_en);
                    ohc_a_pos[START]         = decoded_tlp_type[START].hdr_base_len; // hdr_base_len is expected to be always 3 or 4 when hv 
                    ohc_a5_cpl_status[START] = ohc_a_pos[START] <= 3'd4 ? base_hdr[START][ohc_a_pos[START]][26:24] : '0;
                    has_ohc_a[START]         = base_hdr[START][0][8];
                    cpl_status[START]   = cfg_flit_mode_en ? (has_ohc_a[START] ?  ohc_a5_cpl_status[START] : 3'b000) : base_hdr[START][1][23:21];
                    ep[START]           = cfg_flit_mode_en ? base_hdr[START][1][23] : base_hdr[START][0][22];
                    cpl_ur[START]       = (FC==E_P || FC==E_NP) ? 1'b0 : cpl_status[START]==3'b001;
                    cpl_ca[START]       = (FC==E_P || FC==E_NP) ? 1'b0 : cpl_status[START]==3'b100;
                    cpl_poisoned[START] = (FC==E_P || FC==E_NP) ? 1'b0 : ep[START]==1'b1;
                    wreq_poisoned[START]= (FC==E_CPL) ? 1'b0 : (ep[START] && in_pkt[START].support.has_payload); // MSG without Data have EP bit Reserved
                end
            end
        end
    end
endgenerate

logic [N_XADM_IF-1:0] c_valid,r_valid;
logic [N_XADM_IF-1:0] c_vf_active, r_vf_active;
always_comb begin
    c_valid     = '0;
    c_info      = r_info;
    c_vf_active = r_vf_active;
    for(int i = 0; i < N_XADM_IF; i++)begin
        c_valid[i] = in_pkt[i].eot && (!in_pkt[i].bad_eot || CAN_BADEOT==0) && !in_halt[i];
        if(in_pkt[i].hv)begin
            c_vf_active[i] = 1'b0;
            for(int f = 0; f < NF; f++)begin
                c_info.cpl_ca[f][i]        = (SRIOV_EN==0 || !c_vf_active[i]) && cpl_ca[i] && in_pkt[i].support.func_num==(PF_WD)'(f);
                c_info.cpl_ur[f][i]        = (SRIOV_EN==0 || !c_vf_active[i]) && cpl_ur[i] && in_pkt[i].support.func_num==(PF_WD)'(f);
                c_info.cpl_poisoned[f][i]  = (SRIOV_EN==0 || !c_vf_active[i]) && cpl_poisoned[i] && in_pkt[i].support.func_num==(PF_WD)'(f);
                c_info.wreq_poisoned[f][i] = (SRIOV_EN==0 || !c_vf_active[i]) && wreq_poisoned[i] && in_pkt[i].support.func_num==(PF_WD)'(f);
            end
        end
    end
end

always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        r_vf_active <= #TP '0;
        r_info      <= #TP '0;
        r_valid     <= #TP '0;
    end else begin
        r_vf_active <= #TP c_vf_active;
        r_info      <= #TP c_info;
        r_valid     <= #TP c_valid;
    end
end
always_comb begin
    for(int i = 0; i < N_XADM_IF; i++)begin
        for(int f = 0; f < NF; f++)begin
            out_tx_errors.cpl_ca[f][i]        = r_valid[i] ? r_info.cpl_ca[f][i] : '0;
            out_tx_errors.cpl_ur[f][i]        = r_valid[i] ? r_info.cpl_ur[f][i] : '0;
            out_tx_errors.cpl_poisoned[f][i]  = r_valid[i] ? r_info.cpl_poisoned[f][i] : '0;
            out_tx_errors.wreq_poisoned[f][i] = r_valid[i] ? r_info.wreq_poisoned[f][i] : '0;
        end
    end
end


endmodule

