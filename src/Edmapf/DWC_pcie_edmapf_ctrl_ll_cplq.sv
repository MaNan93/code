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
// ---    $DateTime: 2021/10/29 02:04:56 $
// ---    $Revision: #5 $
// ---    $Author: neira $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_ll_cplq.sv#5 $
// -------------------------------------------------------------------------
/*
 * The write interface defines the number of dwords to write
 *
 *
 */
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_ll_cplq

  import DWC_pcie_edmapf_pkg::*;
  #(

    parameter  P_WDATA_WD      = `CX_NW * 32        // Write data width
    ,parameter P_WEN_WD        = `CX_NW             // Write enable width   
    ,parameter P_CH_WD         = `CC_NUM_DMA_WR_CHAN_WIDTH
    ,parameter type P_HDR_TYPE = logic[P_CH_WD-1:0] // injects header relevant info
  ) (

     DWC_pcie_edmapf_aclks_if.slave_mp b_clk
    ,input logic                       b_wr
    ,input logic                       b_wr_last
    ,input logic                       b_wr_err
    ,input logic [P_WDATA_WD-1:0]      b_wr_data
    ,input logic [P_WEN_WD-1:0]        b_wr_en
    ,input P_HDR_TYPE                  b_wr_hdr
    // Write interface number of free dwords, can't write more than 
    // available words
    ,output logic[$clog2(2*P_WEN_WD):0]b_wr_dw_free  

    // read pop (fifo like)interface
    ,output logic                      b_pop_empty
    ,input  logic                      b_pop
    ,output logic [(6*32)-1:0]         b_pop_data
    ,output P_HDR_TYPE                 b_pop_hdr
    //On multiple LL CPL, remembers which one is the last
    ,output logic                      b_pop_last
    );

  localparam LP_HDR_TYPE_WD = $bits(b_wr_hdr);

  // Number of words to be written
  logic [$clog2(P_WEN_WD):0]    wr_nwords;

  // Write dword pointer
  logic [$clog2(2*P_WEN_WD):0]s_raw_wr_dowrd_ptr, r_raw_wr_dowrd_ptr;

  // This is where the data is stored
  logic [2*P_WDATA_WD-1:0]              r_raw_data,  s_raw_data;
  logic [2*P_WEN_WD*LP_HDR_TYPE_WD-1:0] r_raw_hdr,   s_raw_hdr;
  logic [2*P_WEN_WD-1:0]                r_raw_last,  s_raw_last;

  always_ff @ (posedge b_clk.w_main_clk or negedge b_clk.w_reset_n) begin : PROC_FF_data
    if (!b_clk.w_reset_n) begin
      r_raw_data  <= # `TP '0;
      r_raw_hdr   <= # `TP '0;
      r_raw_last  <= # `TP '0;
    end else begin
      r_raw_data  <= # `TP s_raw_data;
      r_raw_hdr   <= # `TP s_raw_hdr;
      r_raw_last  <= # `TP s_raw_last;
    end
  end 

  assign wr_nwords = TlpCountDWRD_f(b_wr_en[`CX_NW-1:0]);

  // **************************************************************************
  // Shifts data into the array
  // **************************************************************************
  always_comb begin : PROC_CB_data
    logic [2*P_WDATA_WD-1:0]              i_raw_data , i_raw_data_mask;
    logic [2*P_WEN_WD*LP_HDR_TYPE_WD-1:0] i_raw_hdr,   i_raw_hdr_mask;
    logic [2*P_WEN_WD-1:0]                i_raw_last,  i_raw_last_mask;
    logic [$clog2(P_WEN_WD):0]            wr_nwords_t;

    wr_nwords_t = wr_nwords - 1;
    i_raw_data      = '0;
    i_raw_data_mask = '1;

    i_raw_hdr     = '0;
    i_raw_hdr_mask= '1;

    i_raw_last       = '0;
    i_raw_last_mask  = '1;

    for (int i=0;i<P_WEN_WD;i++) begin
      if (b_wr_en[i]) begin
        i_raw_data[int'(32*i)+:32]            = b_wr_data[int'(32*i)+:32];
        i_raw_hdr[LP_HDR_TYPE_WD*i+:LP_HDR_TYPE_WD] = b_wr_hdr;
        i_raw_last[i]  = ((i == wr_nwords_t ) ? b_wr_last : '0) || (b_wr_err & b_wr_last);
      end else begin
        i_raw_data[32*i+:32] = '0;
        i_raw_hdr[LP_HDR_TYPE_WD*i+:LP_HDR_TYPE_WD] = '0;
        i_raw_last[i] = '0;
      end
    end

    for (int j=0;j<(int'(2) * P_WEN_WD);j++) begin
      if (j < r_raw_wr_dowrd_ptr) begin
        i_raw_data_mask[32*j+:32]            = '1;
        i_raw_hdr_mask[j*LP_HDR_TYPE_WD+:LP_HDR_TYPE_WD] = '1;
        i_raw_last_mask[j]                   = '1;
      end else begin
        i_raw_data_mask[32*j+:32]            = '0;
        i_raw_hdr_mask[j*LP_HDR_TYPE_WD+:LP_HDR_TYPE_WD] = '0;
        i_raw_last_mask[j]                   = '0;
      end
    end


    case ({b_wr, b_pop})
      2'b10: begin //Write only, or push into the fifo
        s_raw_data  =  (r_raw_data  & i_raw_data_mask)  | i_raw_data  << int'(r_raw_wr_dowrd_ptr * 32)     ;
        s_raw_hdr   =  (r_raw_hdr & i_raw_hdr_mask)     | i_raw_hdr   << int'(r_raw_wr_dowrd_ptr * LP_HDR_TYPE_WD);
        s_raw_last  =  (r_raw_last  & i_raw_last_mask)  | i_raw_last  << (r_raw_wr_dowrd_ptr);
      end
      2'b11: begin // Write and pop
        s_raw_data  = ((r_raw_data  & i_raw_data_mask)  | i_raw_data  << int'(r_raw_wr_dowrd_ptr * 32)     ) >> (6*32)     ;
        s_raw_hdr   = ((r_raw_hdr & i_raw_hdr_mask)     | i_raw_hdr   << int'(r_raw_wr_dowrd_ptr * LP_HDR_TYPE_WD)) >> (6*LP_HDR_TYPE_WD); 
        s_raw_last  = ((r_raw_last  & i_raw_last_mask)  | i_raw_last  << (r_raw_wr_dowrd_ptr)) >> 6 ;
      end
      2'b01: begin // Pop only
        s_raw_data  = r_raw_data  >> (6*32)     ;
        s_raw_hdr   = r_raw_hdr >> (6*LP_HDR_TYPE_WD);
        s_raw_last  = r_raw_last  >> 6          ;
      end
      default: begin
        s_raw_data  = r_raw_data;
        s_raw_hdr   = r_raw_hdr;
        s_raw_last  = r_raw_last;
      end
    endcase

  end

  // **************************************************************************
  // Manages the FIFO counter
  // **************************************************************************
  always_ff @ (posedge b_clk.w_main_clk or negedge b_clk.w_reset_n) begin : PROC_FF_wr_dw_ptr
    if (!b_clk.w_reset_n) begin
      r_raw_wr_dowrd_ptr <= # `TP '0;
    end else begin
      r_raw_wr_dowrd_ptr <= # `TP s_raw_wr_dowrd_ptr;
    end
  end        

  always_comb begin : PROC_CB_wr_dw_ptr
    logic [$clog2(2*P_WEN_WD):0] i_wr_nwords;
    logic [$clog2(2*P_WEN_WD):0] i_ll_len;

    i_ll_len    = 'sd6;

    i_wr_nwords = '0;
    if (b_wr && !b_wr_err)
      i_wr_nwords[$clog2(P_WEN_WD):0] =  wr_nwords;
    else if (b_wr && b_wr_err && b_wr_last)
      i_wr_nwords = i_ll_len;
    
    s_raw_wr_dowrd_ptr = b_pop ? ($clog2(2*P_WEN_WD)+1)'( r_raw_wr_dowrd_ptr + i_wr_nwords - i_ll_len ):
                                 ($clog2(2*P_WEN_WD)+1)'( r_raw_wr_dowrd_ptr + i_wr_nwords );

  end
  
  // **************************************************************************
  // Pops out data from the array
  // **************************************************************************
  assign b_pop_empty = (r_raw_wr_dowrd_ptr < 'd6);
  assign b_pop_data  = r_raw_data[(6*32)-1:0];
  assign b_pop_hdr   = r_raw_hdr[LP_HDR_TYPE_WD-1:0];
  assign b_pop_last  = |r_raw_last[6-1:0];
  assign b_wr_dw_free = ((2*P_WEN_WD) > r_raw_wr_dowrd_ptr) ? ((2*P_WEN_WD) - r_raw_wr_dowrd_ptr) : '0;



endmodule
