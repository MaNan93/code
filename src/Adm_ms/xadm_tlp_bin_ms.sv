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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xadm_tlp_bin_ms.sv#6 $
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

module xadm_tlp_bin_ms
import DWC_pcie_ctl_pkg::TP;
import DWC_pcie_ctl_pkg::N_XADM_IF;
import DWC_pcie_ctl_pkg::DCRD_WD;
import DWC_pcie_ctl_pkg::HCRD_WD;
import DWC_pcie_ctl_pkg::NVC;
import DWC_pcie_ctl_pkg::NVC_WD;
import DWC_pcie_ctl_pkg::N_XADM_P_IF;
import DWC_pcie_ctl_pkg::N_XADM_P_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_P_CUMULATIVE_PER_VC;
import DWC_pcie_ctl_pkg::N_XADM_CUMULATIVE_PER_VC;
import DWC_pcie_core_pkg::ADM_PRFX_NW;
import DWC_pcie_core_pkg::xtlh_pkt_t;
import pcie_pkg::decoded_tlp_type_s;
import pcie_pkg::f_decode_tlp_type;
import xadm_ms_pkg::xadm_restore_fc_crdt_t;
import pcie_pkg::E_P;
import pcie_pkg::E_NP;
import pcie_pkg::E_CPL;
import pcie_pkg::fc_type_e;

                      (
    input  logic                                      clk,
    input  logic                                      rst_n,

    input  xtlh_pkt_t             [N_XADM_IF-1:0]     in_pkt,
    output logic                  [N_XADM_IF-1:0]     out_halt,
    
    output xtlh_pkt_t             [N_XADM_IF-1:0]     out_pkt,
    input  logic                  [N_XADM_IF-1:0]     in_halt,
    
    output xadm_restore_fc_crdt_t [NVC-1:0][2:0][1:0] out_restore // per <VC,FC,dedicated(0)/shared(1)>
    ,
    input  logic                                      flit_mode_enable
    ,
    input  logic                  [N_XADM_P_IF-1:0]   xtlh_xadm_posted_tlp_sent
    ,output logic                  [N_XADM_P_IF-1:0]   xali_posted_tlp_sent
);
localparam int CAN_BADEOT = 1 & 0; // no bad_eot for AMBA 

wire int_flit_mode_enable = 1'b0 || flit_mode_enable;

// Search for flit_mode_local_tlp_prefix.
// Assumption: if present, it is the first local prefix
logic[N_XADM_IF-1:0] c_fm_local_tlp_pref_using_ded, r_fm_local_tlp_pref_using_ded;
always_comb begin
    c_fm_local_tlp_pref_using_ded = r_fm_local_tlp_pref_using_ded;
    for(int i = 0; i < N_XADM_IF; i++)begin
        if(in_pkt[i].sot && !out_halt[i])begin
            if(in_pkt[i].data[0][0+:8]==8'b10001101)begin
                c_fm_local_tlp_pref_using_ded[i] = in_pkt[i].data[0][15];
            end
        end
    end
end
logic [N_XADM_IF-1:0][DCRD_WD-1:0] c_dcrd, r_dcrd;
logic [N_XADM_IF-1:0][NVC_WD-1:0] c_vc, r_vc;
logic [N_XADM_IF-1:0][1:0] c_fc_credit, r_fc_credit;
always_comb begin
    c_dcrd              = r_dcrd;
    c_vc                = r_vc;
    c_fc_credit         = r_fc_credit;
    for(int i = 0; i < N_XADM_IF; i++)begin
        if(in_pkt[i].sot)begin
            c_vc[i] = in_pkt[i].vc;
            {c_fc_credit[i],c_dcrd[i]} = calc_fc_type_restore_dcredit(in_pkt[i],  int_flit_mode_enable);
        end
    end
end

always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        r_dcrd                          <= #TP '0;
        r_fc_credit                     <= #TP '0;
        r_vc                            <= #TP '0;
        r_fm_local_tlp_pref_using_ded   <= #TP '0;
    end else begin
        for(int i = 0; i < N_XADM_IF; i++)begin
            if(!out_halt[i])begin
                if(in_pkt[i].eot)begin
                    r_dcrd[i]                           <= #TP '0;
                    r_fc_credit[i]                      <= #TP '0;
                    r_vc[i]                             <= #TP '0;
                    r_fm_local_tlp_pref_using_ded[i]    <= #TP '0;
                end else begin
                    r_dcrd[i]                           <= #TP c_dcrd[i];
                    r_fc_credit[i]                      <= #TP c_fc_credit[i];
                    r_vc[i]                             <= #TP c_vc[i];
                    r_fm_local_tlp_pref_using_ded[i]    <= #TP c_fm_local_tlp_pref_using_ded[i];
                end
            end
        end
    end
end



function automatic logic [2+DCRD_WD-1:0] calc_fc_type_restore_dcredit (
    input xtlh_pkt_t in_pkt,
    input flit_mode_enable
);
    begin
        logic              [DCRD_WD-1:0] data_credit;
        logic              [7:0]         first_hdr_byte;
        logic              [9:0]         length;
        decoded_tlp_type_s               tlp_type;
        first_hdr_byte = '0;
        length         = '0;
        for (int index = 0; index <= ADM_PRFX_NW; index++) begin
            if (in_pkt.soh[index]) begin
                first_hdr_byte = in_pkt.data[index][7:0];
                length         = {in_pkt.data[index][17:16], in_pkt.data[index][31:24]};
            end
        end
        tlp_type = f_decode_tlp_type(first_hdr_byte, flit_mode_enable); 
        if (tlp_type.payload) begin
            if (length == '0 && `CX_MAX_MTU==4096) begin
                data_credit = DCRD_WD'(1024/4);
            end else begin
                data_credit = {{DCRD_WD-8{1'b0}}, length[9:2]} + {{DCRD_WD-1{1'b0}}, |length[1:0]};
            end
        end else begin
            data_credit = '0;
        end
        return {tlp_type.fc_type, data_credit};
    end
endfunction


logic[N_XADM_IF-1:0] u;
logic co;
always_comb begin
    out_restore = '0;
    co          = 1'b0;
    u           = '0;
    for(int vc = 0; vc < NVC; vc++)begin
        for(int fc = 0; fc < 3; fc++)begin
            out_restore[vc][fc] = '0;
            for(int i = 0; i < N_XADM_IF; i++)begin
                u[i] = !flit_mode_enable ? 1'b0 : c_fm_local_tlp_pref_using_ded[i] ? 1'b0 : 1'b1;
                if(in_pkt[i].eot && !out_halt[i])begin
                    // When in Flit Mode, do NOT restore credits for Nullified.
                    if((c_vc[i]==NVC_WD'(vc) || NVC==1) && c_fc_credit[i]==2'(fc) && ( (in_pkt[i].badeot && CAN_BADEOT==1 && !flit_mode_enable)))begin
                        {co,out_restore[vc][fc][u[i]].hcrd} = {1'b0,out_restore[vc][fc][u[i]].hcrd} + (HCRD_WD+1)'(1);
                        {co,out_restore[vc][fc][u[i]].dcrd} = {1'b0,out_restore[vc][fc][u[i]].dcrd} + {1'b0,c_dcrd[i]};
                    end
                end
            end
        end
    end
end

always_comb begin
    for (int i = 0; i < N_XADM_IF; i++) begin
        out_pkt[i]     = in_pkt[i];
        out_halt[i]    = in_halt[i];
    end
end

// xali_posted_tlp_sent/xali_posted_tlp_sent_error driving logic
logic [N_XADM_P_IF-1:0] tlp_sent_xadm;
generate
    for(genvar vc = 0; vc < NVC; vc ++)begin : g_tlp_sent_vc
        if(N_XADM_P_IF_VC[vc] > 0) begin : g_tlp_sent_p_gt0
            localparam START = N_XADM_CUMULATIVE_PER_VC[vc];
            for(genvar i = 0; i < N_XADM_P_IF_VC[vc]; i++)begin : g_fc

                assign tlp_sent_xadm[N_XADM_P_CUMULATIVE_PER_VC[vc]+i] = in_pkt[START+i].sot && !out_halt[START+i] && 
                                                                        !in_pkt[START+i].is_from_msg_gen &&
                                                                        !in_pkt[START+i].is_from_dma &&
                                                                        c_fc_credit[START+i] == E_P;  
                always_ff@(posedge clk or negedge rst_n)begin
                    if(!rst_n)begin
                        xali_posted_tlp_sent[N_XADM_P_CUMULATIVE_PER_VC[vc]+i]       <= #TP 1'b0;
                    end else begin
                        begin
                            xali_posted_tlp_sent[N_XADM_P_CUMULATIVE_PER_VC[vc]+i]       <= #TP xtlh_xadm_posted_tlp_sent[N_XADM_P_CUMULATIVE_PER_VC[vc]+i];
                        end
                    end
                end
            end
        end
    end
endgenerate


endmodule


