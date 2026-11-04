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
// --- RCS information:
// ---   $DateTime: 2023/09/27 02:27:25 $
// ---   $Revision: #4 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_rx_tl_credit_control.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// credit control
//  DWC_cxl_rx_tl_credit_control - manages the corresponding Application layer credits calculation internally      
//                   - output of this module s_ch_crd_rxmapper reflects a non zero value incase AL credits are available, an optimized logic and doesn't reflect actual available AL credits.
//                   - r_ch_crd_cnt refers to cummulative credits available for corresponding channel.
//                   - paramter "CRD_OVERFLOW_PROTECTION" allows the r_ch_crd_cnt not to be overflown incase more credits are accomodated by AL than supported by it.
//                      - assumption that credits would in return available based on the data made available on the AL interface running at cxl_clk
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

`include "CXL/svif/DWC_cxl_clk_rst_if.svh"

module DWC_cxl_rx_tl_credit_control
#(
  parameter TP = `TP,
  parameter CH_CRD_WD = 0
) (
DWC_cxl_clk_rst_if.slave_mp         b_clk               ,// defines the clock and reset for core and cxl
input                               toggle_flag         ,
input                               ch_crd              ,//Credit Input from Application Layer 
input                               nullify_crd_cnt     ,//signal for clearing credit count
input                               run_crd_cnt         ,//signal for running credit count
input                               n_data_valid        ,//signal to indicate a valid transfter in current cycle
output                              s_ch_crd_rxmapper_min1,//signal to indicate there are minimume 1 credit 
output                              s_ch_crd_rxmapper_min2 //signal to indicate there are minimume 2 credit 
);
logic                               ch_crd_q           ; //Delayed version of credit input from application layer
logic [(CH_CRD_WD-1) : 0]           r_ch_crd_cnt       ; //current credit count
logic [(CH_CRD_WD-1) : 0]           n_r_ch_crd_cnt     ; //next credit count
logic [(CH_CRD_WD-1) : 0]           r_ch_crd_cnt_2     ; //current credit counter 2 
logic [(CH_CRD_WD-1) : 0]           n_r_ch_crd_cnt_2   ; //next credit counter 2

assign s_ch_crd_rxmapper_min1 = (r_ch_crd_cnt_2 > 'h0); 
assign n_r_ch_crd_cnt_2 = n_r_ch_crd_cnt;
assign s_ch_crd_rxmapper_min2 = 0;      //As only credit should be used per core_clk

always_ff @(posedge b_clk.s_core_clk or negedge b_clk.s_core_rst_n) begin
  if (!b_clk.s_core_rst_n) begin
    r_ch_crd_cnt_2 <= # TP 'h0; 
  end else begin
    r_ch_crd_cnt_2 <= # TP n_r_ch_crd_cnt_2; 
  end 
end

always_ff @(posedge b_clk.s_cxl_clk or negedge b_clk.s_cxl_rst_n) begin
  if (!b_clk.s_cxl_rst_n) begin
    ch_crd_q <= # TP 'h0;
  end else begin
    ch_crd_q <= # TP ch_crd;
  end 
end

//CXL CLK domain period//
always_comb begin
    n_r_ch_crd_cnt =  r_ch_crd_cnt;
  if(nullify_crd_cnt)begin
    n_r_ch_crd_cnt =  'h0;
  end else if(run_crd_cnt)begin
   if(n_data_valid)begin
        if(ch_crd_q==1'b0)begin
            n_r_ch_crd_cnt = (r_ch_crd_cnt-1'b1);
        end 
   end else begin
        if(ch_crd_q==1'b1)begin
            if(r_ch_crd_cnt!=({1'b1,{(CH_CRD_WD-1){1'b0}}}))begin
            n_r_ch_crd_cnt = (r_ch_crd_cnt+1'b1);
            end 
        end 
   end 
  end 
end

always_ff @(posedge b_clk.s_cxl_clk or negedge b_clk.s_cxl_rst_n) begin
  if (!b_clk.s_cxl_rst_n) begin
    r_ch_crd_cnt <= # TP 'h0;
  end else begin
    r_ch_crd_cnt <= # TP n_r_ch_crd_cnt;
  end 
end
endmodule
