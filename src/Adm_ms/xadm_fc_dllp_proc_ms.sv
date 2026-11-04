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
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xadm_fc_dllp_proc_ms.sv#5 $
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

module xadm_fc_dllp_proc_ms
import DWC_pcie_ctl_pkg::TP;
import DWC_pcie_ctl_pkg::HCRD_WD;
import DWC_pcie_ctl_pkg::DCRD_WD;
import pcie_pkg::E_P;
import pcie_pkg::E_NP;
import DWC_pcie_ctl_pkg::NVC;
import DWC_pcie_ctl_pkg::RX_NDLLP;
import xadm_ms_pkg::xadm_fc_update_t;
import xadm_ms_pkg::SHR;
import xadm_ms_pkg::DED;
import DWC_pcie_core_pkg::rtlh_rfc_t;

                           (
    input logic                                              clk,
    input logic                                              rst_n,
    input logic                                              rdlh_link_down, 
    input logic             [NVC-1:0][2:0]                   cfg_vc_id,
    input logic             [NVC-1:0]                        cfg_vc_enable,
    input logic                                              cfg_fc_scaled_en,
    input logic                                              in_flit_mode_enabled,
    
    input rtlh_rfc_t                                         in_rtlh_rfc,
    input  logic            [NVC-1:0][2:0][1:0]              in_init_infinite_h,
    input  logic            [NVC-1:0][2:0][1:0]              in_init_infinite_d,
    input  logic            [NVC-1:0][2:0][1:0][1:0]         in_init_scale_h,
    input  logic            [NVC-1:0][2:0][1:0][1:0]         in_init_scale_d,
    input  logic            [2:0][1:0]                       in_shr_consolidated_init_scale_h,
    input  logic            [2:0][1:0]                       in_shr_consolidated_init_scale_d,
    output logic                                             out_fc_prot_err,
    
    output xadm_fc_update_t [NVC-1:0][2:0]                   out_update
);
localparam int HDR = 0;
localparam int DATA = 1;
localparam int ERR0 = 0;
localparam int ERR1 = 1;

xadm_fc_update_t [NVC-1:0][2:0]                              c_update;
logic            [NVC-1:0][2:0][RX_NDLLP-1:0][1:0][1:0][1:0] c_fc_prot_err;
logic                                                        co;

always_comb begin : DECODE_FC_UPDATES
    c_update = '0;
    c_fc_prot_err = '0;
    co                = 1'b0;
    for(int vc = 0; vc < NVC; vc++)begin
        for(int fc = 0; fc < 3; fc++)begin
            for(int i = 0; i < RX_NDLLP; i = i + 1) begin
                logic shr;
                shr = in_flit_mode_enabled && !in_rtlh_rfc.data[i][3];
                
                // This is for FC1,FC2 and InitFC
                if((cfg_vc_enable[vc] || NVC==1) && in_rtlh_rfc.data[i][2:0]==cfg_vc_id[vc] && in_rtlh_rfc.upd[i] && !in_rtlh_rfc.upd_is_optimized && in_rtlh_rfc.data[i][5:4]==2'(fc))begin
                    c_update[vc][fc] = '0;
                    c_update[vc][fc].h_limit       = 1'b1;
                    c_update[vc][fc].d_limit       = 1'b1;
                    c_update[vc][fc].hd_scale      = cfg_fc_scaled_en;
                    c_update[vc][fc].h_scale_value = in_rtlh_rfc.data[i][15:14];
                    c_update[vc][fc].d_scale_value = in_rtlh_rfc.data[i][21:20];

                    if (in_rtlh_rfc.data[i][7:6] == 2'b10) begin
                    
                        //////////////////////////////////////////////////////////////////////////////////////
                        // CHECK 0: Keep same scale as Init, or FCPE
                        //////////////////////////////////////////////////////////////////////////////////////
                        if(!shr)begin
                            c_fc_prot_err[vc][fc][i][DED][ERR0][HDR ] = (in_rtlh_rfc.data[i][15:14] != in_init_scale_h[vc][fc][DED]) ? 1'b1 : 1'b0;
                            c_fc_prot_err[vc][fc][i][DED][ERR0][DATA] = (in_rtlh_rfc.data[i][21:20] != in_init_scale_d[vc][fc][DED]) ? 1'b1 : 1'b0;
                        end else begin
                            c_fc_prot_err[vc][fc][i][SHR][ERR0][HDR ] = (in_rtlh_rfc.data[i][15:14] != in_shr_consolidated_init_scale_h[fc]) ? 1'b1 : 1'b0;
                            c_fc_prot_err[vc][fc][i][SHR][ERR0][DATA] = (in_rtlh_rfc.data[i][21:20] != in_shr_consolidated_init_scale_d[fc]) ? 1'b1 : 1'b0;
                        end

                        //////////////////////////////////////////////////////////////////////////////////////
                        // CHECK 1: If Infinite, always 0
                        //////////////////////////////////////////////////////////////////////////////////////
                        c_fc_prot_err[vc][fc][i][shr][ERR1][HDR ] = (({in_rtlh_rfc.data[i][13: 8], in_rtlh_rfc.data[i][23:22]} !=       8'b0000_0000) && (in_init_infinite_h[vc][fc][shr])) ? 1'b1 : 1'b0;
                        c_fc_prot_err[vc][fc][i][shr][ERR1][DATA] = (({in_rtlh_rfc.data[i][19:16], in_rtlh_rfc.data[i][31:24]} != 12'b0000_0000_0000) && (in_init_infinite_d[vc][fc][shr])) ? 1'b1 : 1'b0;
                    end
                    
                    c_update[vc][fc].is_fcinit12   = (in_rtlh_rfc.data[i][7:6] == 2'b01) || (in_rtlh_rfc.data[i][7:6] == 2'b11);
                    c_update[vc][fc].h_limit_value = in_init_infinite_h[vc][fc][shr] ? '0 : {in_rtlh_rfc.data[i][13:8],in_rtlh_rfc.data[i][23:22]};
                    c_update[vc][fc].d_limit_value = in_init_infinite_d[vc][fc][shr] ? '0 : {in_rtlh_rfc.data[i][19:16],in_rtlh_rfc.data[i][31:24]};
                    c_update[vc][fc].h_is_infinite = (c_update[vc][fc].h_limit_value=='0) && (!in_flit_mode_enabled || (in_flit_mode_enabled && (c_update[vc][fc].h_scale_value==2'b00)));
                    c_update[vc][fc].d_is_infinite = (c_update[vc][fc].d_limit_value=='0) && (!in_flit_mode_enabled || (in_flit_mode_enabled && (c_update[vc][fc].d_scale_value==2'b00)));
                    c_update[vc][fc].h_is_zero     = (c_update[vc][fc].h_limit_value=='0) && (in_flit_mode_enabled && (c_update[vc][fc].h_scale_value==2'b01));
                    c_update[vc][fc].d_is_zero     = (c_update[vc][fc].d_limit_value=='0) && (in_flit_mode_enabled && (c_update[vc][fc].d_scale_value==2'b01));
                    if(!shr)begin
                        c_update[vc][fc].is_for_shared = 1'b0;
                    end else begin
                        c_update[vc][fc].is_for_shared = 1'b1;
                        c_update[vc][fc].cpl_is_merged = (fc==2) &&
                                (((c_update[vc][fc].h_scale_value==2'b10) && (c_update[vc][fc].h_limit_value=='0)) ||
                                (((c_update[vc][fc].d_scale_value==2'b10) && (c_update[vc][fc].d_limit_value=='0))))
                                ;
                    end
                end
            end
        end
    end
    
    
    for(int vc = 0; vc < NVC; vc++)begin
        if((cfg_vc_enable[vc] || NVC==1) && in_rtlh_rfc.data[0][6:4]==cfg_vc_id[vc] && in_rtlh_rfc.upd[0] && in_rtlh_rfc.upd_is_optimized)begin // is_optimized implicitly requires flit mode enabled
            // Posted - update H and D limits
            c_update[vc][E_P].h_limit        = 1'b1;
            c_update[vc][E_P].d_limit        = 1'b1;
            c_update[vc][E_P].h_limit_value  = {in_rtlh_rfc.data[0][11:8] , in_rtlh_rfc.data[0][23:20]};
            c_update[vc][E_P].d_limit_value  = {in_rtlh_rfc.data[0][19:16], in_rtlh_rfc.data[0][31:24]};
            
            // NPosted - update H limit
            c_update[vc][E_NP].h_limit       = 1'b1;
            c_update[vc][E_NP].h_limit_value = {in_rtlh_rfc.data[0][3:0], in_rtlh_rfc.data[0][15:12]};
            
            c_update[vc][E_P].is_for_shared  = 1'b1;
            c_update[vc][E_NP].is_for_shared = 1'b1;

            //////////////////////////////////////////////////////////////////////////////////////
            // CHECK 1: If Infinite, always 0
            //////////////////////////////////////////////////////////////////////////////////////
            c_fc_prot_err[vc][E_P ][0][SHR][ERR1][HDR ] = (({in_rtlh_rfc.data[0][11:8] , in_rtlh_rfc.data[0][23:20]} !=       8'b0000_0000) && (in_init_infinite_h[vc][E_P ][SHR])) ? 1'b1 : 1'b0;
            c_fc_prot_err[vc][E_P ][0][SHR][ERR1][DATA] = (({in_rtlh_rfc.data[0][19:16], in_rtlh_rfc.data[0][31:24]} != 12'b0000_0000_0000) && (in_init_infinite_d[vc][E_P ][SHR])) ? 1'b1 : 1'b0; 
            c_fc_prot_err[vc][E_NP][0][SHR][ERR1][HDR ] = (({in_rtlh_rfc.data[0][ 3: 0], in_rtlh_rfc.data[0][15:12]} !=       8'b0000_0000) && (in_init_infinite_h[vc][E_NP][SHR])) ? 1'b1 : 1'b0;

        end
    end
end


always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)  out_update <= #TP '0;
    else        out_update <= #TP rdlh_link_down ? '0 : c_update;
end

assign out_fc_prot_err = |c_fc_prot_err;

endmodule

