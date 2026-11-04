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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xadm_rasdes_tlp_tracer_ms.sv#3 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "products/pcie_pkg.svh"
`include "Adm_ms/xadm_ms_pkg.svh"

module xadm_rasdes_tlp_tracer_ms
import DWC_pcie_ctl_pkg::N_XADM_P_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_NP_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_CPL_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_CUMULATIVE_PER_VC;
import DWC_pcie_ctl_pkg::N_XADM_P_CUMULATIVE_PER_VC;
import DWC_pcie_ctl_pkg::N_XADM_NP_CUMULATIVE_PER_VC;
import DWC_pcie_ctl_pkg::N_XADM_CPL_CUMULATIVE_PER_VC;
import DWC_pcie_core_pkg::xadm_rasdes_tlp_trace_t;
import DWC_pcie_core_pkg::xadm_pkt_t;
import pcie_pkg::tlp_hdr_pkt_s;
import pcie_pkg::tlp_hdr_decode_s;
import pcie_pkg::E_MRD;
import pcie_pkg::E_MWR;
import pcie_pkg::E_DMWR;
import pcie_pkg::E_IORD;
import pcie_pkg::E_IOWR;
import pcie_pkg::E_CFGRD;
import pcie_pkg::E_CFGWR;
import pcie_pkg::E_MSG;
import pcie_pkg::mode_e;
import pcie_pkg::f_tlp_hdr_decode;
import pcie_pkg::f_tlp_is_atomic;
import pcie_pkg::f_tlp_is_cpl;
import pcie_pkg::f_tlp_is_cpld;
import xadm_ms_pkg::f_xadm_tlp_hdr_pkt;

                                (
    input  logic                        clk,
    input  logic                        rst_n,
    
    input  logic                        in_flush,
    input  xadm_pkt_t [`N_XADM_IF-1:0]  in_pkt,
    input  logic      [`N_XADM_IF-1:0]  in_halt,
    input  logic                        flit_mode_enable,
    output xadm_rasdes_tlp_trace_t      xadm_rasdes_tlp_trace
);

xadm_pkt_t              [`N_XADM_P_IF-1:0]      pkt_p;
xadm_pkt_t              [`N_XADM_NP_IF-1:0]     pkt_np;
xadm_pkt_t              [`N_XADM_CPL_IF-1:0]    pkt_cpl;
logic                   [`N_XADM_P_IF-1:0]      halt_p;
logic                   [`N_XADM_NP_IF-1:0]     halt_np;
logic                   [`N_XADM_CPL_IF-1:0]    halt_cpl;
tlp_hdr_pkt_s           [`N_XADM_IF-1:0]        c_hdr_pkt, r_hdr_pkt;
tlp_hdr_decode_s        [`N_XADM_IF-1:0]        c_hdr_dec, r_hdr_dec;
logic                   [`N_XADM_IF-1:0]        c_has_prefix, r_has_prefix;
logic                   [`N_XADM_IF-1:0]        c_null_flag;
tlp_hdr_decode_s        [`N_XADM_P_IF-1:0]      c_hdr_dec_p;
logic                   [`N_XADM_P_IF-1:0]      c_null_flag_p;
tlp_hdr_pkt_s           [`N_XADM_NP_IF-1:0]     c_hdr_pkt_np;
tlp_hdr_decode_s        [`N_XADM_NP_IF-1:0]     c_hdr_dec_np;
logic                   [`N_XADM_NP_IF-1:0]     c_null_flag_np;
tlp_hdr_pkt_s           [`N_XADM_CPL_IF-1:0]    c_hdr_pkt_cpl;
logic                   [`N_XADM_CPL_IF-1:0]    c_null_flag_cpl;
xadm_rasdes_tlp_trace_t                         c_xadm_rasdes_tlp_trace_ide_on, c_xadm_rasdes_tlp_trace_ide_off, r_xadm_rasdes_tlp_trace;
mode_e                                          flit_mode; assign flit_mode = mode_e'(flit_mode_enable);

function automatic [10:0] tlp_length_base2bin(logic has_payload, logic [9:0] tlp_length);
    return (!has_payload) ? '0 : (|tlp_length ? {1'b0, tlp_length} : 11'd1024);
endfunction

// Unroll signals into their specific per-FC version
generate for(genvar vc = 0; vc < `CX_NVC; vc++)begin : g_evt_vc
    for(genvar i = 0; i < N_XADM_P_IF_VC[vc]; i++)begin : g_pi
        assign pkt_p          [N_XADM_P_CUMULATIVE_PER_VC[vc]+i]   = in_pkt     [N_XADM_CUMULATIVE_PER_VC[vc]+i];
        assign halt_p         [N_XADM_P_CUMULATIVE_PER_VC[vc]+i]   = in_halt    [N_XADM_CUMULATIVE_PER_VC[vc]+i];
        assign c_hdr_dec_p    [N_XADM_P_CUMULATIVE_PER_VC[vc]+i]   = c_hdr_dec  [N_XADM_CUMULATIVE_PER_VC[vc]+i];
        assign c_null_flag_p  [N_XADM_P_CUMULATIVE_PER_VC[vc]+i]   = c_null_flag[N_XADM_CUMULATIVE_PER_VC[vc]+i];
    end
    for(genvar i = 0; i < N_XADM_NP_IF_VC[vc]; i++)begin : g_npi
        assign pkt_np         [N_XADM_NP_CUMULATIVE_PER_VC[vc]+i]  = in_pkt     [N_XADM_CUMULATIVE_PER_VC[vc]+N_XADM_P_IF_VC[vc]+i];
        assign halt_np        [N_XADM_NP_CUMULATIVE_PER_VC[vc]+i]  = in_halt    [N_XADM_CUMULATIVE_PER_VC[vc]+N_XADM_P_IF_VC[vc]+i];
        assign c_hdr_pkt_np   [N_XADM_NP_CUMULATIVE_PER_VC[vc]+i]  = c_hdr_pkt  [N_XADM_CUMULATIVE_PER_VC[vc]+N_XADM_P_IF_VC[vc]+i];
        assign c_hdr_dec_np   [N_XADM_NP_CUMULATIVE_PER_VC[vc]+i]  = c_hdr_dec  [N_XADM_CUMULATIVE_PER_VC[vc]+N_XADM_P_IF_VC[vc]+i];
        assign c_null_flag_np [N_XADM_NP_CUMULATIVE_PER_VC[vc]+i]  = c_null_flag[N_XADM_CUMULATIVE_PER_VC[vc]+N_XADM_P_IF_VC[vc]+i];
    end
    for(genvar i = 0; i < N_XADM_CPL_IF_VC[vc]; i++)begin : g_cpli
        assign pkt_cpl        [N_XADM_CPL_CUMULATIVE_PER_VC[vc]+i] = in_pkt     [N_XADM_CUMULATIVE_PER_VC[vc]+N_XADM_P_IF_VC[vc]+N_XADM_NP_IF_VC[vc]+i];
        assign halt_cpl       [N_XADM_CPL_CUMULATIVE_PER_VC[vc]+i] = in_halt    [N_XADM_CUMULATIVE_PER_VC[vc]+N_XADM_P_IF_VC[vc]+N_XADM_NP_IF_VC[vc]+i];
        assign c_hdr_pkt_cpl  [N_XADM_CPL_CUMULATIVE_PER_VC[vc]+i] = c_hdr_pkt  [N_XADM_CUMULATIVE_PER_VC[vc]+N_XADM_P_IF_VC[vc]+N_XADM_NP_IF_VC[vc]+i];
        assign c_null_flag_cpl[N_XADM_CPL_CUMULATIVE_PER_VC[vc]+i] = c_null_flag[N_XADM_CUMULATIVE_PER_VC[vc]+N_XADM_P_IF_VC[vc]+N_XADM_NP_IF_VC[vc]+i];
    end
end endgenerate

// Non-IDE Proc, loop through P,NP,CPL interfaces
always_comb begin
    c_xadm_rasdes_tlp_trace_ide_off = '0;

    // FC-agnostic signals
    for(int i = 0; i < `N_XADM_IF; i++)begin
        c_hdr_pkt[i]    = in_pkt[i].hv ? f_xadm_tlp_hdr_pkt(flit_mode, in_pkt[i])   : r_hdr_pkt[i];
        c_hdr_dec[i]    = in_pkt[i].hv ? f_tlp_hdr_decode(flit_mode, c_hdr_pkt[i])  : r_hdr_dec[i];
        c_has_prefix[i] = in_pkt[i].hv ? (|in_pkt[i].prfx_dwen)                     : r_has_prefix[i];
        c_null_flag[i]  = in_pkt[i].bad_eot  || in_flush || in_pkt[i].ras_dp_err_inband_kbd;
        if(in_pkt[i].eot && !in_halt[i])begin
            c_xadm_rasdes_tlp_trace_ide_off.xadm_tx_null_evt[i]         = c_null_flag[i];
            c_xadm_rasdes_tlp_trace_ide_off.xadm_tx_tlp_dpsize[i*11+:11]= c_null_flag[i] ? '0 : tlp_length_base2bin(c_hdr_dec[i].payload, c_hdr_pkt[i].tlp_len);
            c_xadm_rasdes_tlp_trace_ide_off.xadm_tx_tlpwprefix_evt[i]   = c_null_flag[i] ? 1'b0 : c_has_prefix[i];
        end
    end

    // Posted events
    for(int i = 0; i < `N_XADM_P_IF; i++)begin
        if(pkt_p[i].eot && !halt_p[i] && !c_null_flag_p[i])begin
            c_xadm_rasdes_tlp_trace_ide_off.xadm_tx_memwr_evt[i]        = c_hdr_dec_p[i].trans_type == E_MWR;
            c_xadm_rasdes_tlp_trace_ide_off.xadm_tx_msg_evt[i]          = c_hdr_dec_p[i].trans_type == E_MSG;
        end
    end

    // Non-Posted events
    for(int i = 0; i < `N_XADM_NP_IF; i++)begin
        if(pkt_np[i].eot && !halt_np[i] && !c_null_flag_np[i])begin
            c_xadm_rasdes_tlp_trace_ide_off.xadm_tx_memrd_evt[i]        = c_hdr_dec_np[i].trans_type == E_MRD;
            c_xadm_rasdes_tlp_trace_ide_off.xadm_tx_defmemwr_evt[i]     = c_hdr_dec_np[i].trans_type == E_DMWR;
            c_xadm_rasdes_tlp_trace_ide_off.xadm_tx_cfgwr_evt[i]        = c_hdr_dec_np[i].trans_type == E_CFGWR;
            c_xadm_rasdes_tlp_trace_ide_off.xadm_tx_cfgrd_evt[i]        = c_hdr_dec_np[i].trans_type == E_CFGRD;
            c_xadm_rasdes_tlp_trace_ide_off.xadm_tx_iowr_evt[i]         = c_hdr_dec_np[i].trans_type == E_IOWR;
            c_xadm_rasdes_tlp_trace_ide_off.xadm_tx_iord_evt[i]         = c_hdr_dec_np[i].trans_type == E_IORD;
            c_xadm_rasdes_tlp_trace_ide_off.xadm_tx_atmcop_evt[i]       = f_tlp_is_atomic(flit_mode, c_hdr_pkt_np[i]);
        end
    end

    // Completion events
    for(int i = 0; i < `N_XADM_CPL_IF; i++)begin
        if(pkt_cpl[i].eot && !halt_cpl[i] && !c_null_flag_cpl[i])begin
            c_xadm_rasdes_tlp_trace_ide_off.xadm_tx_cplwod_evt[i]       = f_tlp_is_cpl(flit_mode, c_hdr_pkt_cpl[i]) && !f_tlp_is_cpld(flit_mode, c_hdr_pkt_cpl[i]);
            c_xadm_rasdes_tlp_trace_ide_off.xadm_tx_cplwd_evt[i]        = f_tlp_is_cpld(flit_mode, c_hdr_pkt_cpl[i]);
        end
    end

end


always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        r_hdr_pkt               <= #`TP '0;
        r_hdr_dec               <= #`TP '0;
        r_has_prefix            <= #`TP '0;
        r_xadm_rasdes_tlp_trace <= #`TP '0;
    end else begin
        r_hdr_pkt               <= #`TP c_hdr_pkt;
        r_hdr_dec               <= #`TP c_hdr_dec;
        r_has_prefix            <= #`TP c_has_prefix;
        r_xadm_rasdes_tlp_trace <= #`TP c_xadm_rasdes_tlp_trace_ide_off;
    end
end
assign xadm_rasdes_tlp_trace = r_xadm_rasdes_tlp_trace;

endmodule
